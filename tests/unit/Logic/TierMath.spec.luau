--!strict
local Index = require("../../../src/shared/Data/Index")
local TestKit = require("../../../src/shared/Util/TestKit")
local TierMath = require("../../../src/shared/Logic/TierMath")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("TierMath", function()
	it("gives the highest tier whose massNeeded ≤ mass (02 §0.3)", function()
		expect(TierMath.tier(0)).toBe(1)
		expect(TierMath.tier(9.99)).toBe(1)
		expect(TierMath.tier(10)).toBe(2)
		expect(TierMath.tier(29.9)).toBe(2)
		expect(TierMath.tier(30)).toBe(3)
		expect(TierMath.tier(250)).toBe(5) -- spike S11
		expect(TierMath.tier(1199.9)).toBe(6)
		expect(TierMath.tier(1200)).toBe(7)
		expect(TierMath.tier(1e9)).toBe(7)
		expect(TierMath.tier(-5)).toBe(1)
	end)

	it("lets the tier fall when mass is lost", function()
		expect(TierMath.tier(80)).toBe(4)
		expect(TierMath.tier(80 - 0.1)).toBe(3)
	end)

	it("gives each tier's canon scale at its threshold", function()
		for _, def in Index.Tiers.list do
			expect(TierMath.bodyScale(def.massNeeded)).toBeCloseTo(def.bodyScale, 1e-9)
		end
	end)

	it("blends by mass between thresholds (02 §0.2 worked example)", function()
		expect(TierMath.bodyScale(8)).toBeCloseTo(1.24, 1e-9) -- a Fry at mass 8
		expect(TierMath.bodyScale(20)).toBeCloseTo(1.5, 1e-9) -- halfway from 1.3 to 1.7
		expect(TierMath.bodyScale(850)).toBeCloseTo(5.5, 1e-9) -- halfway from 4.5 to 6.5
	end)

	it("is 6.5 from tier 7 up, whatever the mass", function()
		expect(TierMath.bodyScale(1200)).toBe(6.5)
		expect(TierMath.bodyScale(50000)).toBe(6.5)
	end)

	it("never shrinks under the Fry and never decreases as mass grows", function()
		expect(TierMath.bodyScale(-3)).toBe(1)
		local last = TierMath.bodyScale(0)
		for m = 0, 1500, 0.5 do
			local s = TierMath.bodyScale(m)
			expect(s >= last).toBe(true)
			last = s
		end
	end)
end)

describe("TierMath: tier steps (canon 5.1, 02 §5.1, 08 §3.4)", function()
	it("reads each tier's row, clamping stray tier numbers", function()
		for _, def in Index.Tiers.list do
			expect(TierMath.def(def.tier)).toBe(def)
			expect(TierMath.swimSpeed(def.tier)).toBe(def.swimSpeed)
			expect(TierMath.turnRate(def.tier)).toBe(def.turnRate)
		end
		expect(TierMath.TOP).toBe(7)
		expect(TierMath.def(0).tier).toBe(1)
		expect(TierMath.def(9).tier).toBe(7)
		expect(TierMath.swimSpeed(4)).toBe(32)
		expect(TierMath.turnRate(7)).toBe(140)
	end)

	it("gives the next tier's threshold, nil at the top", function()
		expect(TierMath.nextThreshold(0)).toBe(10)
		expect(TierMath.nextThreshold(86)).toBe(200)
		expect(TierMath.nextThreshold(1199)).toBe(1200)
		expect(TierMath.nextThreshold(1200)).toBe(nil)
	end)

	it("fills the mass bar from this tier's threshold to the next", function()
		expect(TierMath.progress(0)).toBe(0)
		expect(TierMath.progress(5)).toBe(0.5)
		expect(TierMath.progress(30)).toBe(0)
		expect(TierMath.progress(55)).toBe(0.5)
		expect(TierMath.progress(1200)).toBe(1)
		expect(TierMath.progress(-1)).toBe(0)
	end)

	it("lists every tier passed in one jump, and none on a fall", function()
		expect(TierMath.tiersGained(2, 5)).toEqual({ 3, 4, 5 })
		expect(TierMath.tiersGained(3, 4)).toEqual({ 4 })
		expect(TierMath.tiersGained(4, 4)).toEqual({})
		expect(TierMath.tiersGained(5, 3)).toEqual({})
		expect(TierMath.tiersGained(6, 9)).toEqual({ 7 })
	end)
end)
