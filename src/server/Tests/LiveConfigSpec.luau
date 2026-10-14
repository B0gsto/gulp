--!strict
-- Engine-side spec of LiveConfig (docs/09, section 17.4; task S5-C5, module B33): a failing
-- ConfigService leaves every key on its default, a fetched snapshot is read and re-read on
-- UpdateAvailable, and the client keys travel through `State` under `config.*`. The value typing
-- and fallback rules are checked in Lune (tests/unit/Config/Flags.spec). Every case puts the
-- server back on the real snapshot (or the defaults) when it ends.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Defaults = require(ReplicatedStorage.Shared.Config.Defaults)
local Flags = require(ReplicatedStorage.Shared.Config.Flags)
local TestKit = require(ReplicatedStorage.Shared.Util.TestKit)

local LiveConfig = require("../Services/LiveConfig")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- Runs `body`, then restores the real snapshot and stops recording sends, even on failure.
local function restoring(body: () -> ())
	local ok, problem = pcall(function()
		body()
	end)
	LiveConfig._test.onSend(nil)
	LiveConfig._test.restore()
	if not ok then
		error(problem, 0)
	end
end

local function allDefaults(): boolean
	for key, value in Defaults.live do
		if Flags.get(key) ~= value then
			return false
		end
	end
	return true
end

return function()
	describe("LiveConfig", function()
		it("falls back to Config/Defaults when ConfigService fails", function()
			restoring(function()
				LiveConfig._test.apply({ ["flag.tideEvents"] = false, ["kill.pvp"] = true })
				expect(Flags.bool("flag.tideEvents")).toBe(false)
				local fetched = LiveConfig._test.connect(function(): any
					error("ConfigService is down")
				end)
				expect(fetched).toBe(false)
				expect(allDefaults()).toBe(true)
			end)
		end)

		it("puts a missing or wrongly typed value on its default", function()
			restoring(function()
				LiveConfig._test.apply({ ["kill.pvp"] = "yes", ["tune.bite.baseTolerance"] = 4 })
				expect(Flags.bool("kill.pvp")).toBe(Defaults.live["kill.pvp"])
				expect(Flags.number("tune.bite.baseTolerance")).toBe(4)
				expect(Flags.bool("flag.reviveOffer")).toBe(Defaults.live["flag.reviveOffer"])
			end)
		end)

		it("reads a fetched snapshot and reads it again on UpdateAvailable", function()
			restoring(function()
				local values: { [string]: any } = { ["live.shopDelaySeconds"] = 90 }
				local update = Instance.new("BindableEvent")
				local refreshed = 0
				local fake = {
					GetValue = function(_self: any, key: string): any
						return values[key]
					end,
					Refresh = function(_self: any)
						refreshed += 1
					end,
					UpdateAvailable = update.Event,
				}
				expect(LiveConfig._test.connect(function(): any
					return fake
				end)).toBe(true)
				expect(Flags.number("live.shopDelaySeconds")).toBe(90)
				values["live.shopDelaySeconds"] = 60
				update:Fire()
				task.wait() -- deferred signals
				expect(refreshed).toBe(1)
				expect(Flags.number("live.shopDelaySeconds")).toBe(60)
				update:Destroy()
			end)
		end)

		local player = Players:GetPlayers()[1]
		if not player then
			it(
				"(no player in this session: run it in a play test for the State cases)",
				function() end
			)
			return
		end

		it("forwards a changed client key to the player as State config.*", function()
			restoring(function()
				local sent: { [string]: any } = {}
				LiveConfig._test.onSend(function(to: Player, path: string, value: any)
					if to == player then
						sent[path] = value
					end
				end)
				LiveConfig.pushAll(player) -- as PlayerLifecycle does at join
				LiveConfig._test.apply({
					["flag.tideEvents"] = not Defaults.live["flag.tideEvents"],
					["tune.bite.baseTolerance"] = 5,
				})
				expect(sent["config.flag.tideEvents"]).toBe(not Defaults.live["flag.tideEvents"])
				-- A server tolerance stays on the server.
				expect(sent["config.tune.bite.baseTolerance"]).toBe(nil)
				-- Going back sends the default again.
				table.clear(sent)
				LiveConfig._test.apply({})
				expect(sent["config.flag.tideEvents"]).toBe(Defaults.live["flag.tideEvents"])
			end)
		end)
	end)
end
