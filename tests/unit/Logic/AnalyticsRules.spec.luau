--!strict
local AnalyticsRules = require("../../../src/shared/Logic/AnalyticsRules")
local EconomyRules = require("../../../src/shared/Logic/EconomyRules")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function count(map: { [string]: any }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

describe("AnalyticsRules: the enum (10 §3, §4.1, §4.2; 09 R13)", function()
	it("lists the 52 [MVP] custom events, all named <domain>_<what>", function()
		expect(count(AnalyticsRules.EVENTS)).toBe(52)
		local domains = {
			"ftue",
			"fs",
			"sess",
			"ret",
			"run",
			"species",
			"trait",
			"tide",
			"shop",
			"revive",
			"rv",
			"cove",
			"goal",
			"codex",
			"settings",
			"social",
			"guard",
			"ab",
			"sys",
			"pvp",
			"perf",
			"input",
		}
		for name in AnalyticsRules.EVENTS do
			local domain = string.match(name, "^([a-z]+)_[a-z0-9_]+$")
			expect(domain ~= nil and table.find(domains, domain) ~= nil).toBe(true)
		end
		expect(AnalyticsRules.EVENTS.sess_private_server).toBe(nil) -- [L]
		expect(AnalyticsRules.EVENTS.pvp_pair).toBe(nil) -- [L]
	end)

	it("lists funnels 1 to 7 with step names numbered from 01", function()
		expect(count(AnalyticsRules.FUNNELS)).toBe(7)
		local lengths = {
			onboarding = 20,
			run = 9,
			species_unlock = 6,
			trait = 5,
			tide_event = 6,
			shop_purchase = 5,
			revive_offer = 6,
		}
		for name, def in AnalyticsRules.FUNNELS do
			expect(def.name).toBe(name)
			expect(#def.steps).toBe(lengths[name])
			expect(#def.ctx).toBe(#def.steps)
			for i, step in def.steps do
				expect(string.sub(step, 1, 3)).toBe(string.format("%02d_", i))
			end
		end
	end)

	it("stays inside 10 §2.3's limits", function()
		local L = AnalyticsRules.LIMITS
		expect(count(AnalyticsRules.EVENTS) <= L.customEventNames).toBe(true)
		expect(count(AnalyticsRules.FUNNELS) <= L.funnels).toBe(true)
		for _, def in AnalyticsRules.FUNNELS do
			expect(#def.steps <= L.stepsPerFunnel).toBe(true)
		end
		expect(
			count(EconomyRules.SOURCE_SKUS) + count(EconomyRules.SINK_SKUS) - 1
				<= L.transactionTypes
		).toBe(true)
		expect(#EconomyRules.allSkus() + 18 <= L.skus).toBe(true)
		-- Five arms at once and 20 experiment values: still under 8,000 combinations.
		expect(AnalyticsRules.combinations(5, 20) <= L.customFieldCombinations).toBe(true)
	end)
end)

describe("AnalyticsRules: checks", function()
	it("accepts dictionary events with their own ctx values", function()
		expect(AnalyticsRules.checkEvent("run_banked", 42, "t2")).toBe(true)
		expect(AnalyticsRules.checkEvent("goal_all3", 1, nil)).toBe(true)
		expect(AnalyticsRules.checkEvent("goal_all3", 1, "none")).toBe(true)
		expect(AnalyticsRules.checkEvent("run_species", 90, "minnow")).toBe(true)
		expect(AnalyticsRules.checkEvent("trait_shed", 30, "glow")).toBe(true)
		expect(AnalyticsRules.checkEvent("goal_completed", 300, "dg_eat_50")).toBe(true)
		expect(AnalyticsRules.checkEvent("ab_exposed", 1, "chase=escort")).toBe(true)
		expect(AnalyticsRules.checkEvent("sess_device", 1, "phone_s_touch")).toBe(true)
		expect(AnalyticsRules.checkEvent("run_end_input", 120, "kbm_gulp_npc")).toBe(true)
		expect(AnalyticsRules.checkEvent("guard_flag", 7, "analytics_drop")).toBe(true)
		expect(AnalyticsRules.checkEvent("ftue_end", 300, "left_s10")).toBe(true)
	end)

	it("refuses unknown names, [L] values, free text and bad values", function()
		expect(AnalyticsRules.checkEvent("run_bankd", 1, "t2")).toBe(false)
		expect(AnalyticsRules.checkEvent("run_banked", 1, "t8")).toBe(false)
		expect(AnalyticsRules.checkEvent("run_banked", 1, nil)).toBe(false)
		expect(AnalyticsRules.checkEvent("goal_all3", 1, "t2")).toBe(false)
		expect(AnalyticsRules.checkEvent("sess_device", 1, "tv_l_gamepad")).toBe(false) -- [L]
		expect(AnalyticsRules.checkEvent("run_species", 1, "Bob")).toBe(false)
		expect(AnalyticsRules.checkEvent("ab_exposed", 1, "free text")).toBe(false)
		expect(AnalyticsRules.checkEvent("run_banked", 0 / 0, "t2")).toBe(false)
		expect(AnalyticsRules.checkEvent("run_banked", math.huge, "t2")).toBe(false)
	end)

	it("names funnel steps and checks session IDs and ctx", function()
		expect(AnalyticsRules.checkStep("onboarding", nil, 13, nil)).toBe("13_banked")
		expect(AnalyticsRules.checkStep("onboarding", "abc", 13, nil)).toBe(nil)
		expect(AnalyticsRules.checkStep("onboarding", nil, 21, nil)).toBe(nil)
		expect(AnalyticsRules.checkStep("run", "guid", 4, nil)).toBe("04_tier2")
		expect(AnalyticsRules.checkStep("run", nil, 4, nil)).toBe(nil)
		expect(AnalyticsRules.checkStep("run", "", 4, nil)).toBe(nil)
		local session = AnalyticsRules.speciesSession(12, "puffer")
		expect(session).toBe("12-puffer")
		expect(AnalyticsRules.checkStep("species_unlock", session, 4, "puffer")).toBe("04_bought")
		expect(AnalyticsRules.checkStep("species_unlock", session, 4, "glow")).toBe(nil)
		expect(AnalyticsRules.checkStep("revive_offer", "run1", 1, "t3")).toBe("01_gulped_eligible")
		expect(AnalyticsRules.checkStep("revive_offer", "run1", 3, "paid")).toBe("03_option_tapped")
		expect(AnalyticsRules.checkStep("revive_offer", "run1", 3, "video")).toBe(nil) -- [L]
		expect(AnalyticsRules.checkStep("shop_purchase", "g", 5, "pearl_pack")).toBe("05_granted")
		expect(
			AnalyticsRules.checkStep(
				"tide_event",
				AnalyticsRules.tideSession(1, 900.5),
				1,
				"frenzy"
			)
		).toBe("01_warned")
		expect(AnalyticsRules.checkStep("rewarded_video", "g", 1, nil)).toBe(nil) -- [L]
	end)

	it("checks economy events against 10 §5", function()
		expect(AnalyticsRules.checkPearls("Source", 30, 130, "Bank", "bank_t2")).toBe(true)
		expect(AnalyticsRules.checkPearls("Sink", 500, 0, "Species", "puffer")).toBe(true)
		expect(AnalyticsRules.checkPearls("Sink", -500, 0, "Species", "puffer")).toBe(false)
		expect(AnalyticsRules.checkPearls("Sink", 500, -1, "Species", "puffer")).toBe(false)
		expect(AnalyticsRules.checkPearls("Source", 500, 0, "Species", "puffer")).toBe(false)
		expect(AnalyticsRules.checkPearls("Gift", 5, 5, "Bank", "bank_t1")).toBe(false)
	end)
end)

describe("AnalyticsRules: budget, repeats and cohorts (10 §2.3, §2.4)", function()
	it("drops P2 first, then P1, never P0", function()
		local reserve = AnalyticsRules.P2_RESERVE
		expect(AnalyticsRules.admits("P2", reserve + 1)).toBe(true)
		expect(AnalyticsRules.admits("P2", reserve + 0.5)).toBe(false)
		expect(AnalyticsRules.admits("P1", reserve)).toBe(true)
		expect(AnalyticsRules.admits("P1", 0.5)).toBe(false)
		expect(AnalyticsRules.admits("P0", 0)).toBe(true)
		expect(AnalyticsRules.EVENTS.settings_changed.priority).toBe("P2")
		expect(AnalyticsRules.EVENTS.run_end_input.priority).toBe("P1")
		expect(AnalyticsRules.EVENTS.shop_purchased.priority).toBe("P0")
		expect(AnalyticsRules.FUNNELS.onboarding.priority).toBe("P0")
	end)

	it("sends a funnel step once, completes earlier steps, and forgets old sessions", function()
		local memory = AnalyticsRules.newStepMemory()
		expect(AnalyticsRules.firstTime(memory, "run", "a", 3)).toBe(true)
		expect(AnalyticsRules.isNewStep(memory, "run", "a", 3)).toBe(false)
		expect(AnalyticsRules.firstTime(memory, "run", "a", 3)).toBe(false)
		expect(AnalyticsRules.firstTime(memory, "run", "a", 2)).toBe(false)
		expect(AnalyticsRules.firstTime(memory, "run", "a", 5)).toBe(true)
		expect(AnalyticsRules.firstTime(memory, "trait", "a", 1)).toBe(true)
		for i = 1, AnalyticsRules.LIMITS.recentSessions do
			expect(AnalyticsRules.firstTime(memory, "run", `s{i}`, 1)).toBe(true)
		end
		expect(#memory.run.order).toBe(AnalyticsRules.LIMITS.recentSessions)
		expect(AnalyticsRules.isNewStep(memory, "run", "a", 1)).toBe(true) -- pushed out
		expect(AnalyticsRules.firstTime(memory, "onboarding", nil, 1)).toBe(true)
		expect(AnalyticsRules.firstTime(memory, "onboarding", nil, 1)).toBe(false)
	end)

	it("reads the cohort from the session count and the first play day (UTC)", function()
		local day = 86400
		local created = 100 * day + 3600
		expect(AnalyticsRules.cohort(1, created, created + 10 * day)).toBe("s1")
		expect(AnalyticsRules.cohort(2, created, created + 600)).toBe("d0")
		expect(AnalyticsRules.cohort(2, created, 101 * day)).toBe("d1_6")
		expect(AnalyticsRules.cohort(5, created, 106 * day + 5)).toBe("d1_6")
		expect(AnalyticsRules.cohort(5, created, 107 * day)).toBe("d7p")
	end)
end)
