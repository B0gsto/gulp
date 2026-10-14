--!strict
local BiteMath = require("../../../src/shared/Logic/BiteMath")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("BiteMath", function()
	it("clamps the claim time to [now − 0.4 s, now] (09 §8.9, step 5)", function()
		local tc, clamped = BiteMath.claimTime(99.9, 100)
		expect(tc).toBe(99.9)
		expect(clamped).toBe(false)
		tc, clamped = BiteMath.claimTime(99.6, 100)
		expect(tc).toBe(99.6)
		expect(clamped).toBe(false)
		tc, clamped = BiteMath.claimTime(90, 100)
		expect(tc).toBeCloseTo(99.6, 1e-9)
		expect(clamped).toBe(true)
		tc, clamped = BiteMath.claimTime(105, 100)
		expect(tc).toBe(100)
		expect(clamped).toBe(true)
		tc = BiteMath.claimTime(0 / 0, 100)
		expect(tc).toBe(100)
		tc = BiteMath.claimTime(math.huge, 100)
		expect(tc).toBe(100)
	end)

	it("puts the mouth 1.5 × bodyScale along the look vector", function()
		local x, y, z = BiteMath.mouth(10, 20, 30, 0, 0, -1, 2)
		expect(x).toBe(10)
		expect(y).toBe(20)
		expect(z).toBeCloseTo(27, 1e-9)
		-- A look vector that is not a unit vector is normalised.
		x, y, z = BiteMath.mouth(0, 0, 0, 3, 0, 4, 1)
		expect(x).toBeCloseTo(0.9, 1e-9)
		expect(z).toBeCloseTo(1.2, 1e-9)
		-- A zero look vector leaves the mouth at the centre.
		x, y, z = BiteMath.mouth(1, 2, 3, 0, 0, 0, 5)
		expect(x + y + z).toBe(6)
	end)

	it("computes reach from bodyScale, the widest assist, the prey and the motion", function()
		-- 0.9 × 1 × 2.5 + 0.3 + 0.2 + 3 + 0.15 × (10 + 4) = 2.25 + 0.5 + 3 + 2.1 = 7.85
		expect(BiteMath.reach(1, 1, 0.3, 0.2, 10, 4)).toBeCloseTo(7.85, 1e-9)
		-- Reach grows with body scale at once (09 §6.8).
		expect(BiteMath.reach(2, 1, 0.3, 0.2, 10, 4)).toBeCloseTo(10.1, 1e-9)
		-- The newcomer's first-run factor widens only the assisted mouth.
		expect(BiteMath.reach(1, 1.6, 0, 0, 0, 0)).toBeCloseTo(0.9 * 2.5 * 1.6 + 3, 1e-9)
		-- A negative speed (never expected) counts as its size.
		expect(BiteMath.reach(1, 1, 0, 0, -10, 0)).toBeCloseTo(2.25 + 3 + 1.5, 1e-9)
	end)

	it("accepts a prey within reach and rejects one past it, with the distance", function()
		local ok, d = BiteMath.within(0, 0, 0, 3, 4, 0, 5)
		expect(ok).toBe(true)
		expect(d).toBeCloseTo(5, 1e-9)
		ok, d = BiteMath.within(0, 0, 0, 3, 4, 0.01, 5)
		expect(ok).toBe(false)
		expect(d > 5).toBe(true)
	end)

	it("calls a miss far beyond three reaches", function()
		expect(BiteMath.isFar(15, 5)).toBe(false)
		expect(BiteMath.isFar(15.01, 5)).toBe(true)
	end)

	it("gives the first-run mouth factor and the Nursery share (04 §4, 02 §4.4)", function()
		expect(BiteMath.firstRunMouth(1)).toBe(1.6)
		expect(BiteMath.firstRunMouth(2)).toBe(1.3)
		expect(BiteMath.firstRunMouth(3)).toBe(1)
		expect(BiteMath.nurseryMult(1)).toBe(1)
		expect(BiteMath.nurseryMult(2)).toBe(0.5)
		expect(BiteMath.nurseryMult(3)).toBe(0)
		expect(BiteMath.nurseryMult(7)).toBe(0)
	end)

	it("gains prey mass × trait multiplier × Nursery share, never below 0", function()
		expect(BiteMath.gain(2, 1, 1)).toBe(2)
		expect(BiteMath.gain(2, 1.1, 0.5)).toBeCloseTo(1.1, 1e-9)
		expect(BiteMath.gain(2, 1, 0)).toBe(0)
		expect(BiteMath.gain(-1, 1, 1)).toBe(0)
	end)
end)
