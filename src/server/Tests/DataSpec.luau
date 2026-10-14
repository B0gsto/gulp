--!strict
-- Engine-side spec of DataService on ProfileStore.Mock (docs/09, sections 12.2 to 12.4; docs/13,
-- Sprint 4 acceptance: "A fixture profile of schema version 1 loads and saves; a second session
-- on the same key is refused"). The JSON fixtures are checked in Lune (tests/unit/Logic/
-- Migrations.spec); here a version 1 profile goes through the real library: opened, patched,
-- saved, closed and opened again. Spec sessions use keys no player has (`spec_*`), and Mock never
-- touches real data. The player cases need a play test and leave the profile as they found it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Flags = require(ReplicatedStorage.Shared.Config.Flags)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Migrations = require(ReplicatedStorage.Shared.Logic.Migrations)
local TestKit = require(ReplicatedStorage.Shared.Util.TestKit)

local DataService = require("../Services/DataService")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local WAIT = 10 -- seconds a Mock session may take to start or a final save to land

local function waitFor(done: () -> boolean): boolean
	local deadline = os.clock() + WAIT
	while not done() do
		if os.clock() > deadline then
			return false
		end
		task.wait(0.1)
	end
	return true
end

return function()
	describe("DataService (engine, ProfileStore.Mock)", function()
		it("uses the Mock store in development and CI", function()
			expect(DataService._test.isMock()).toBe(true)
		end)

		it("opens a version 1 profile, saves it, and loads it again with the change", function()
			local key = `spec_{math.random(1, 1e9)}`
			local profile = assert(DataService._test.open(key), "no Mock session")
			expect(profile.Data.v).toBe(Migrations.SCHEMA_VERSION)
			expect(profile.Data.species.selected).toBe("minnow")
			profile.Data.pearls = 4321
			profile.Data.codex.prey.krill = 7
			DataService._test.close(profile)
			local again
			expect(waitFor(function()
				again = DataService._test.open(key)
				return again ~= nil
			end)).toBe(true)
			local loaded = assert(again, "no second load")
			expect(loaded.Data.pearls).toBe(4321)
			expect(loaded.Data.codex.prey.krill).toBe(7)
			expect(loaded.Data.createdAt).toBe(profile.Data.createdAt)
			DataService._test.close(loaded)
		end)

		it("refuses a second session on a key this server holds", function()
			local key = `spec_{math.random(1, 1e9)}`
			local first = assert(DataService._test.open(key), "no Mock session")
			local second, why = DataService._test.open(key)
			expect(second).toBe(nil)
			expect(why).toBe("a session on this key is already open on this server")
			expect(first:IsActive()).toBe(true) -- the first session is untouched
			DataService._test.close(first)
			expect(first:IsActive()).toBe(false)
		end)

		it("writes the last accepted data while kill.saves is on", function()
			local key = `spec_{math.random(1, 1e9)}`
			local profile = assert(DataService._test.open(key), "no Mock session")
			local live = profile.Data
			live.pearls = 10
			DataService._test.beforeSave(profile)
			expect(profile.Data.pearls).toBe(10)
			Flags.set("kill.saves", true)
			live.pearls = 99
			DataService._test.beforeSave(profile)
			Flags.set("kill.saves", false)
			expect(profile.Data ~= live).toBe(true)
			expect(profile.Data.pearls).toBe(10)
			DataService._test.beforeSave(profile)
			expect(profile.Data).toBe(live)
			-- Data that breaks the save rules is refused the same way. The refusal is logged at
			-- error level; the line is captured here so it never reaches the console (the smoke's
			-- step 6 fails on any error line).
			live.pearls = 0 / 0
			local lines: { string } = {}
			Log.setSink(function(level, tag, message)
				table.insert(lines, `{level} {tag} {message}`)
			end)
			local saved, problem = pcall(function()
				DataService._test.beforeSave(profile)
			end)
			Log.setSink(nil)
			assert(saved, problem)
			expect(profile.Data.pearls).toBe(99)
			local logged = false
			for _, line in lines do
				if
					string.find(
						line,
						`error Data save of {key} refused: data.pearls: not a finite number`,
						1,
						true
					)
				then
					logged = true
				end
			end
			expect(logged).toBe(true)
			live.pearls = 99
			DataService._test.close(profile)
		end)

		local player = Players:GetPlayers()[1]
		if not player then
			it(
				"(no player in this session: run it in a play test for the join cases)",
				function() end
			)
			return
		end

		it("loaded the player's profile on join", function()
			expect(waitFor(function()
				return DataService.get(player) ~= nil
			end)).toBe(true)
			local data = assert(DataService.get(player), "no profile")
			expect(data.v).toBe(Migrations.SCHEMA_VERSION)
			expect(data.sessions >= 1).toBe(true)
			-- The player's own key is held, so a second session on it is refused.
			local second, why = DataService._test.open(`u_{player.UserId}`)
			expect(second).toBe(nil)
			expect(why).toBe("a session on this key is already open on this server")
		end)

		it("patches a path and pushes what changed to the owner as State", function()
			local data = assert(DataService.get(player), "no profile")
			local sent: { { path: string, value: any } } = {}
			DataService._test.onSend(function(to: Player, path: string, value: any)
				if to == player then
					table.insert(sent, { path = path, value = value })
				end
			end)
			local music = data.settings.music
			local ok = DataService.patch(player, "settings.music", if music == 5 then 4 else 5)
			local refused = DataService.patch(player, "settings.music", "loud")
			local restored = DataService.patch(player, "settings.music", music)
			DataService._test.onSend(nil)
			expect(ok).toBe(true)
			expect(refused).toBe(false)
			expect(restored).toBe(true)
			expect(data.settings.music).toBe(music)
			expect(#sent).toBe(2)
			expect(sent[1].path).toBe("settings.music")
			expect(sent[1].value).toBe(if music == 5 then 4 else 5)
			expect(sent[2]).toEqual({ path = "settings.music", value = music })
		end)

		it("sends only the keys that changed when a table is patched", function()
			local data = assert(DataService.get(player), "no profile")
			local before = table.clone(data.tokens)
			local after = table.clone(before)
			after.goal_reroll += 1
			local sent: { string } = {}
			DataService._test.onSend(function(_to: Player, path: string)
				table.insert(sent, path)
			end)
			expect(DataService.patch(player, "tokens", after)).toBe(true)
			expect(DataService.patch(player, "tokens", before)).toBe(true)
			DataService._test.onSend(nil)
			expect(sent).toEqual({ "tokens.goal_reroll", "tokens.goal_reroll" })
			expect(data.tokens).toEqual(before)
		end)

		it("refuses a scheme its input mode does not have, and any config path", function()
			local data = assert(DataService.get(player), "no profile")
			local touch = data.settings.input.touch.scheme
			local sent: { string } = {}
			DataService._test.onSend(function(_to: Player, path: string)
				table.insert(sent, path)
			end)
			local ok1 = DataService.patch(player, "settings.input.touch.scheme", "two_thumb")
			local bad = DataService.patch(player, "settings.input.keys.scheme", "drag")
			local badTable = DataService.patch(player, "settings.input.pad", {
				scheme = "gamepad",
				lookSpeed = 1,
				twoThumbLookSpeed = 1,
				flipY = false,
				graphics = "auto",
			})
			local config = DataService.patch(player, "config.flag.tideEvents", true)
			local ok2 = DataService.patch(player, "settings.input.touch.scheme", touch)
			DataService._test.onSend(nil)
			expect(ok1).toBe(true)
			expect(bad).toBe(false)
			expect(badTable).toBe(false)
			expect(config).toBe(false)
			expect(ok2).toBe(true)
			expect(data.settings.input.keys.scheme).toBe("keys")
			expect(data.settings.input.pad.scheme).toBe("pad")
			expect(data.settings.input.touch.scheme).toBe(touch)
			expect((data :: any).config).toBe(nil)
			expect(#sent).toBe(if touch == "two_thumb" then 0 else 2)
		end)

		it("saves now on request, and queues a second request inside 30 s", function()
			expect(DataService.saveNow(player)).toBe(true)
			expect(DataService.saveNow(player)).toBe(true)
		end)
	end)
end
