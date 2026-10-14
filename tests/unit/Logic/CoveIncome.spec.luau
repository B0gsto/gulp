--!strict
-- 09 §16.1: cap, backwards clock, rate change; plus every other function of the module.
local CoveIncome = require("../../../src/shared/Logic/CoveIncome")
local TestKit = require("../../../src/shared/Util/TestKit")
local Types = require("../../../src/shared/Types")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local HOUR = 3600
local T0 = 1_760_000_000

local function specimen(tier: number, traits: { string }): Types.SpecimenRecord
	return { id = "abcdefgh", sp = "minnow", tier = tier, mass = 10, traits = traits, at = T0 }
end

describe("CoveIncome.rate (05 §3.3)", function()
	it("pays the base table by tier and nothing for tier 1", function()
		local base = { [2] = 6, [3] = 10, [4] = 18, [5] = 30, [6] = 50, [7] = 80 }
		for tier = 2, 7 do
			expect(CoveIncome.specimenRate(tier, {})).toBe(base[tier])
		end
		expect(CoveIncome.specimenRate(1, {})).toBe(0)
		expect(CoveIncome.specimenRate(8, {})).toBe(0)
	end)

	it("matches 05 §3.3's worked examples exactly", function()
		expect(CoveIncome.specimenRate(3, {})).toBe(10)
		expect(CoveIncome.specimenRate(4, { "stripes" })).toBe(19.8)
		expect(CoveIncome.specimenRate(5, { "spots", "plated" })).toBe(39)
		expect(CoveIncome.specimenRate(6, { "stripes", "spiny", "ink" })).toBe(82.5)
		expect(CoveIncome.specimenRate(7, { "ink", "longfin", "glow" })).toBe(132)
		expect(CoveIncome.specimenRate(7, { "moonlit", "ink", "plated" })).toBe(204)
		expect(CoveIncome.specimenRate(7, { "moonlit", "bonefed", "crystal" })).toBe(288)
	end)

	it("sums every specimen", function()
		expect(CoveIncome.rate({})).toBe(0)
		expect(
			CoveIncome.rate({ specimen(3, {}), specimen(5, { "spots", "plated" }), specimen(1, {}) })
		).toBe(49)
	end)
end)

describe("CoveIncome.accrue (02 §13.2, 09 §13.2, §13.3)", function()
	it("fills at the rate", function()
		local pending, at = CoveIncome.accrue(0, T0, T0 + 2 * HOUR, 10, 8)
		expect(pending).toBeCloseTo(20, 1e-9)
		expect(at).toBe(T0 + 2 * HOUR)
		pending, at = CoveIncome.accrue(pending, at, at + 30 * 60, 10, 8)
		expect(pending).toBeCloseTo(25, 1e-9)
	end)

	it("stops at the cap: 8 hours, or 24 with Tide Watcher", function()
		expect(CoveIncome.capHours(false)).toBe(8)
		expect(CoveIncome.capHours(true)).toBe(24)
		expect((CoveIncome.accrue(0, T0, T0 + 30 * HOUR, 10, 8))).toBe(80)
		expect((CoveIncome.accrue(0, T0, T0 + 30 * HOUR, 10, 24))).toBe(240)
		-- Accrued in steps, the pile still stops at 8 hours of income.
		local pending, at = 0, T0
		for _ = 1, 20 do
			pending, at = CoveIncome.accrue(pending, at, at + HOUR, 10, 8)
		end
		expect(pending).toBe(80)
		-- A fast clock over-pays at most one cap.
		expect((CoveIncome.accrue(0, T0, T0 + 1e9, 10, 8))).toBe(80)
	end)

	it("adds nothing and never moves back on a backwards clock", function()
		local pending, at = CoveIncome.accrue(12.5, T0, T0 - 5 * HOUR, 10, 8)
		expect(pending).toBe(12.5)
		expect(at).toBe(T0)
		-- Moving forward again pays only from the old accruedAt: no period is paid twice.
		pending, at = CoveIncome.accrue(pending, at, T0 + HOUR, 10, 8)
		expect(pending).toBeCloseTo(22.5, 1e-9)
		expect(at).toBe(T0 + HOUR)
	end)

	it("applies the old rate to the old period and the new rate after a change", function()
		local old, new = 10, 40
		local pending, at = CoveIncome.accrue(0, T0, T0 + 2 * HOUR, old, 8) -- before the bank
		pending, at = CoveIncome.accrue(pending, at, at + HOUR, new, 8)
		expect(pending).toBeCloseTo(60, 1e-9) -- 2 h × 10 + 1 h × 40
	end)

	it("never shrinks the pile when the rate falls under it", function()
		local pending = CoveIncome.accrue(0, T0, T0 + 8 * HOUR, 50, 8) -- 400, full
		local after = CoveIncome.accrue(pending, T0 + 8 * HOUR, T0 + 9 * HOUR, 10, 8) -- cap now 80
		expect(after).toBe(400)
	end)
end)

describe("CoveIncome: claim and payments", function()
	it("claims whole Pearls and keeps the fraction", function()
		local pearls, rest = CoveIncome.claim(39.75)
		expect(pearls).toBe(39)
		expect(rest).toBeCloseTo(0.75, 1e-9)
		pearls, rest = CoveIncome.claim(0.4)
		expect(pearls).toBe(0)
		expect(rest).toBe(0.4)
	end)

	it("boosts two hours of the current rate, rounded down", function()
		expect(CoveIncome.boost(39)).toBe(78)
		expect(CoveIncome.boost(19.8)).toBe(39)
	end)

	it("refunds one hour of income, at least 5 (05 §3.10)", function()
		expect(CoveIncome.refund(CoveIncome.specimenRate(5, { "spots", "plated" }))).toBe(39)
		expect(CoveIncome.refund(CoveIncome.specimenRate(2, {}))).toBe(6)
		expect(CoveIncome.refund(3.3)).toBe(5)
	end)

	it("pays the first-bank reward: 6 for a tier 2 Minnow with Glow", function()
		expect(CoveIncome.firstBankReward(2, { "glow" })).toBe(6)
		expect(CoveIncome.firstBankReward(4, { "stripes" })).toBe(19)
	end)

	it("shows the away card after 10 minutes away and 10 Pearls earned", function()
		expect(CoveIncome.showAwayCard(600, 10)).toBe(true)
		expect(CoveIncome.showAwayCard(599, 50)).toBe(false)
		expect(CoveIncome.showAwayCard(3600, 9.9)).toBe(false)
	end)
end)
