--!strict
-- Engine-side spec of EconomyService and the Analytics wrapper (docs/09, section 5.1; docs/10,
-- sections 2.3, 2.4 and 5; task S5-C1). In Studio, development and CI nothing reaches
-- AnalyticsService: every call lands in the wrapper's memory buffer, which these cases read. Stand-in players (plain tables
-- with a UserId) run anywhere, CI included, through a fake profile store; the player case needs a
-- play test, goes through DataService on ProfileStore.Mock, and leaves the balance as it found it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnalyticsRules = require(ReplicatedStorage.Shared.Logic.AnalyticsRules)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local TestKit = require(ReplicatedStorage.Shared.Util.TestKit)

local Analytics = require("../Services/Analytics")
local DataService = require("../Services/DataService")
local EconomyService = require("../Services/EconomyService")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local nextId = -9000

-- A stand-in player and its profile, read and written through EconomyService's test store.
local function standIn(pearls: number): (Player, { pearls: number })
	nextId -= 1
	local player = ({ UserId = nextId, Name = `spec{-nextId}` } :: any) :: Player
	local data = { pearls = pearls }
	local profiles: { [Player]: any } = { [player] = data }
	EconomyService._test.useStore({
		get = function(who: Player)
			return profiles[who]
		end,
		patch = function(who: Player, path: string, value: any): boolean
			local profile = profiles[who]
			if not profile or path ~= "pearls" then
				return false
			end
			profile.pearls = value
			return true
		end,
	})
	return player, data
end

-- The buffered records of one player since `from` (a buffer length taken earlier).
local function recordsOf(player: Player, from: number): { Analytics.Record }
	local out = {}
	for i, r in Analytics.buffer() do
		if i > from and r.userId == player.UserId then
			table.insert(out, r)
		end
	end
	return out
end

-- Quiet logs for cases that are refused on purpose.
local function quietly(body: () -> ())
	Log.setSink(function() end)
	local ok, problem = pcall(body :: () -> unknown)
	Log.setSink(nil)
	if not ok then
		error(problem, 0)
	end
end

return function()
	-- Luau execution (CI) does not run Main, so nothing has started these services there.
	Analytics._test.ensureInit()
	DataService._test.ensureInit()
	describe("Analytics (engine, memory buffer)", function()
		it("buffers instead of sending in Studio, development and CI", function()
			expect(Analytics.isSending()).toBe(false)
		end)

		it("records a custom event with the three custom fields", function()
			local player = standIn(0)
			Analytics.clearBuffer()
			expect(Analytics.event(player, "run_banked", 42, "t2")).toBe(true)
			local records = recordsOf(player, 0)
			expect(#records).toBe(1)
			local r = records[1]
			expect(r.kind).toBe("event")
			expect(r.name).toBe("run_banked")
			expect(r.value).toBe(42)
			expect(r.ctx).toBe("t2")
			expect(r.exp).toBe("none")
			expect(r.cohort).toBe("s1")
			Analytics.forget(player)
		end)

		it("refuses names and ctx values outside the dictionary, and counts the warning", function()
			local player = standIn(0)
			local before = Analytics.logCounts()["warn:Analytics"] or 0
			local length = #Analytics.buffer()
			quietly(function()
				expect(Analytics.event(player, "run_bankd", 1, "t2")).toBe(false)
				expect(Analytics.event(player, "run_banked", 1, "Bob")).toBe(false)
			end)
			expect(#recordsOf(player, length)).toBe(0)
			expect(Analytics.logCounts()["warn:Analytics"]).toBe(before + 2)
			Analytics.forget(player)
		end)

		it("sends each funnel step once per session", function()
			local player = standIn(0)
			local length = #Analytics.buffer()
			expect(Analytics.step(player, "onboarding", nil, 1)).toBe(true)
			expect(Analytics.step(player, "onboarding", nil, 1)).toBe(false)
			expect(Analytics.step(player, "run", "run-a", 4)).toBe(true)
			expect(Analytics.step(player, "run", "run-a", 2)).toBe(false)
			expect(Analytics.step(player, "run", "run-b", 2)).toBe(true)
			local records = recordsOf(player, length)
			expect(#records).toBe(3)
			expect(records[1].stepName).toBe("01_joined")
			expect(records[2].stepName).toBe("04_tier2")
			expect(records[2].sessionId).toBe("run-a")
			Analytics.forget(player)
		end)

		it("drops P2 first, then P1, never P0, and reports the drops as guard_flag", function()
			local player = standIn(0)
			local length = #Analytics.buffer()
			local budget = AnalyticsRules.LIMITS.eventsPerPlayerPerMinute
			local sentP2 = 0
			for _ = 1, budget do
				if Analytics.event(player, "codex_opened", 1, nil) then
					sentP2 += 1
				end
			end
			expect(sentP2).toBe(budget - AnalyticsRules.P2_RESERVE)
			local sentP1 = 0
			for _ = 1, budget do
				if Analytics.event(player, "run_banked", 10, "t1") then
					sentP1 += 1
				end
			end
			expect(sentP1).toBe(AnalyticsRules.P2_RESERVE)
			expect(Analytics.event(player, "shop_open", 1, "hud")).toBe(true)
			expect(Analytics.pearls(player, "Source", 5, 5, "Admin", "admin_grant")).toBe(true)
			local drops = Analytics._test.drops(player)
			expect(drops).toBe(2 * budget - sentP2 - sentP1)
			Analytics._test.reportDrops()
			local records = recordsOf(player, length)
			local last = records[#records]
			expect(last.name).toBe("guard_flag")
			expect(last.ctx).toBe("analytics_drop")
			expect(last.value).toBe(drops)
			expect(Analytics._test.drops(player)).toBe(0)
			Analytics.forget(player)
		end)
	end)

	describe("EconomyService (engine)", function()
		it("grants, spends and logs one economy event per change", function()
			local player, data = standIn(100)
			local length = #Analytics.buffer()
			expect(EconomyService.balance(player)).toBe(100)
			expect(EconomyService.grant(player, 30, "Bank", "bank_t2")).toBe(true)
			expect(data.pearls).toBe(130)
			expect(EconomyService.spend(player, 120, "Species", "puffer")).toBe(true)
			expect(EconomyService.balance(player)).toBe(10)
			local records = recordsOf(player, length)
			expect(#records).toBe(2)
			expect(records[1].kind).toBe("pearls")
			expect(records[1].flow).toBe("Source")
			expect(records[1].name).toBe("Bank")
			expect(records[1].value).toBe(30)
			expect(records[1].balance).toBe(130)
			expect(records[1].sku).toBe("bank_t2")
			expect(records[2].flow).toBe("Sink")
			expect(records[2].value).toBe(120)
			expect(records[2].balance).toBe(10)
			EconomyService._test.useStore(nil)
			Analytics.forget(player)
		end)

		it(
			"refuses a short balance, bad amounts and unknown sources without changing anything",
			function()
				local player, data = standIn(50)
				local length = #Analytics.buffer()
				quietly(function()
					expect(EconomyService.spend(player, 51, "Species", "puffer")).toBe(false)
					expect(EconomyService.grant(player, -5, "Bank", "bank_t1")).toBe(false)
					expect(EconomyService.grant(player, 2.5, "Bank", "bank_t1")).toBe(false)
					expect(EconomyService.grant(player, 5, "Gift" :: any, nil)).toBe(false)
					expect(EconomyService.spend(player, 5, "CoveSlot", "puffer")).toBe(false)
				end)
				expect(data.pearls).toBe(50)
				expect(#recordsOf(player, length)).toBe(0)
				EconomyService._test.useStore(nil)
				Analytics.forget(player)
			end
		)

		local player = Players:GetPlayers()[1]
		if not player then
			it(
				"(no player in this session: run it in a play test for the profile case)",
				function() end
			)
			return
		end

		it("changes the player's saved Pearls through DataService and sends State", function()
			EconomyService._test.useStore(nil)
			local data = assert(DataService.get(player), "no profile")
			local before = data.pearls
			local sent: { any } = {}
			DataService._test.onSend(function(to: Player, path: string, value: any)
				if to == player and path == "pearls" then
					table.insert(sent, value)
				end
			end)
			local length = #Analytics.buffer()
			local granted = EconomyService.grant(player, 7, "Admin", "admin_grant")
			local spent = EconomyService.spend(player, 7, "Admin", "admin_remove")
			DataService._test.onSend(nil)
			expect(granted).toBe(true)
			expect(spent).toBe(true)
			expect(data.pearls).toBe(before)
			expect(sent).toEqual({ before + 7, before })
			local records = recordsOf(player, length)
			expect(#records).toBe(2)
			expect(records[1].balance).toBe(before + 7)
			expect(records[2].balance).toBe(before)
		end)
	end)
end
