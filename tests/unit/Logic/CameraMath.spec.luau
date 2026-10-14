--!strict
local CameraMath = require("../../../src/shared/Logic/CameraMath")
local Index = require("../../../src/shared/Data/Index")
local TestKit = require("../../../src/shared/Util/TestKit")
local TierMath = require("../../../src/shared/Logic/TierMath")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("CameraMath distance (02 §3.1)", function()
	it("matches the tier table at each threshold mass", function()
		-- Distance and height columns of 02 §3.1 (one decimal there).
		local want = {
			{ 14, 3.5 },
			{ 17, 4.3 },
			{ 21, 5.3 },
			{ 27, 6.8 },
			{ 36, 9.0 },
			{ 49, 12.3 },
			{ 69, 17.3 },
		}
		for tier, row in want do
			local scale = TierMath.bodyScale(Index.Tiers.byTier[tier].massNeeded)
			local d = CameraMath.distance(scale)
			expect(d).toBeCloseTo(row[1], 1e-9)
			expect(CameraMath.height(d, false)).toBeCloseTo(row[2], 0.051)
		end
	end)

	it("follows body scale continuously between thresholds", function()
		-- A Fry at mass 8 has scale 1.24 (02 §0.2).
		expect(CameraMath.distance(TierMath.bodyScale(8))).toBeCloseTo(16.4, 1e-9)
	end)

	it("drops the height to 5% of the distance in tight-space mode", function()
		expect(CameraMath.height(20, true)).toBeCloseTo(1, 1e-9)
	end)

	it("looks half a body length ahead and keeps the minimum distance", function()
		expect(CameraMath.lookAhead(1)).toBeCloseTo(1.5, 1e-9)
		expect(CameraMath.minDistance(1, 1)).toBeCloseTo(1.2 * 0.9 + 2, 1e-9)
		expect(CameraMath.minDistance(6.5, 1)).toBeCloseTo(1.2 * 5.85 + 2, 1e-9)
	end)
end)

describe("CameraMath field of view (15 §3.2)", function()
	it("matches the table by aspect", function()
		-- Aspect, vertical, horizontal: the table of 15 §3.2 (whole degrees).
		local rows = {
			{ 4 / 3, 79, 95 },
			{ 1180 / 820, 74, 95 },
			{ 16 / 10, 70, 97 },
			{ 16 / 9, 70, 102 },
			{ 19.5 / 9, 70, 113 },
			{ 21 / 9, 70, 117 },
			{ 32 / 9, 49, 117 },
		}
		for _, row in rows do
			local v = CameraMath.baseVFov(row[1])
			expect(math.round(v)).toBe(row[2])
			-- 16:10 at 70° is 96.5° across; the table rounds it to 97.
			expect(CameraMath.hFov(v, row[1])).toBeCloseTo(row[3], 0.51)
		end
	end)

	it("caps the vertical field of view at 90 degrees", function()
		expect(CameraMath.baseVFov(0.5)).toBe(90)
		expect(CameraMath.baseVFov(1)).toBeCloseTo(90, 1e-9)
	end)

	it("adds up to 6 degrees with forward speed", function()
		expect(CameraMath.speedFov(13, 26)).toBeCloseTo(3, 1e-9)
		expect(CameraMath.speedFov(60, 26)).toBe(6)
		expect(CameraMath.speedFov(-10, 26)).toBe(0)
		expect(CameraMath.speedFov(10, 0)).toBe(0)
	end)

	it("kicks 10 degrees on a dash: 0.08 s in, held, 0.35 s out", function()
		expect(CameraMath.dashFov(0.04, 0.3)).toBeCloseTo(5, 1e-9)
		expect(CameraMath.dashFov(0.2, 0.3)).toBe(10)
		expect(CameraMath.dashFov(0.3 + 0.175, 0.3)).toBeCloseTo(5, 1e-9)
		expect(CameraMath.dashFov(1, 0.3)).toBe(0)
	end)
end)

describe("CameraMath smoothing (02 §3.2, 09 §6.7)", function()
	it("takes one exponential step and snaps at tau 0", function()
		expect(CameraMath.smooth(0, 1, 0.25, 0.25)).toBeCloseTo(1 - math.exp(-1), 1e-12)
		expect(CameraMath.smooth(0, 1, 0.016, 0)).toBe(1)
	end)

	it("is frame-rate independent", function()
		local a, b = 0, 0
		for _ = 1, 25 do
			a = CameraMath.smooth(a, 10, 1 / 25, 0.12)
		end
		for _ = 1, 240 do
			b = CameraMath.smooth(b, 10, 1 / 240, 0.12)
		end
		expect(a).toBeCloseTo(b, 1e-9)
	end)

	it("smooths angles the short way round", function()
		expect(CameraMath.angleDelta(350, 10)).toBeCloseTo(20, 1e-9)
		expect(CameraMath.angleDelta(10, 350)).toBeCloseTo(-20, 1e-9)
		local a = CameraMath.smoothAngle(350, 10, 1, 0)
		expect(a).toBeCloseTo(10, 1e-9)
		local half = CameraMath.smoothAngle(350, 10, 0.18 * math.log(2), 0.18)
		expect(half).toBeCloseTo(0, 1e-9)
	end)

	it("springs critically damped with no overshoot", function()
		local x, v = 0, 0
		local peak = 0
		for _ = 1, 120 do
			x, v = CameraMath.spring(x, v, 10, 1 / 60, 0.03)
			peak = math.max(peak, x)
		end
		expect(x).toBeCloseTo(10, 1e-6)
		expect(peak <= 10 + 1e-9).toBe(true)
	end)

	it("trails a moving target by 2 tau v, which the lead removes (spike F1)", function()
		local tau, speed, dt = 0.03, 38, 1 / 2000 -- small dt: a frame-stepped target adds v·dt/2
		local function run(lead: number): number
			local x, v, target = 0, speed, 0
			for _ = 1, 2000 do
				target += speed * dt
				x, v = CameraMath.spring(x, v, CameraMath.leadTarget(target, speed, lead), dt, tau)
			end
			return target - x
		end
		expect(run(0)).toBeCloseTo(2 * tau * speed, 0.05)
		expect(math.abs(run(2 * tau)) < 0.05).toBe(true)
	end)
end)

describe("CameraMath tier changes (02 §3.3)", function()
	it("pulls back to 115% by T+0.70 and settles by T+1.20", function()
		expect(CameraMath.pullBack(0)).toBe(1)
		expect(CameraMath.pullBack(0.1)).toBe(1)
		expect(CameraMath.pullBack(0.4)).toBeCloseTo(1.075, 1e-9)
		expect(CameraMath.pullBack(0.7)).toBeCloseTo(1.15, 1e-9)
		expect(CameraMath.pullBack(0.95)).toBeCloseTo(1.075, 1e-9)
		expect(CameraMath.pullBack(1.2)).toBe(1)
	end)

	it("eases straight to the new distance over 0.4 s on a tier-down", function()
		expect(CameraMath.tierDown(27, 21, 0)).toBe(27)
		expect(CameraMath.tierDown(27, 21, 0.2)).toBeCloseTo(24, 1e-9)
		expect(CameraMath.tierDown(27, 21, 0.4)).toBe(21)
		expect(CameraMath.tierDown(27, 21, 9)).toBe(21)
	end)
end)

describe("CameraMath obstacles (02 §3.5)", function()
	it("places the camera 0.5 studs in front of a hit, within the minimum and desired", function()
		expect(CameraMath.clearDistance(nil, 14, 3)).toBe(14)
		expect(CameraMath.clearDistance(10, 14, 3)).toBe(9.5)
		expect(CameraMath.clearDistance(1, 14, 3)).toBe(3)
		expect(CameraMath.clearDistance(30, 14, 3)).toBe(14)
	end)

	it("moves in at once and back out with tau 0.40", function()
		expect(CameraMath.stepOcclusion(14, 6, 0.016)).toBe(6)
		expect(CameraMath.stepOcclusion(6, 14, 0.4)).toBeCloseTo(6 + 8 * (1 - math.exp(-1)), 1e-9)
	end)

	it("enters tight-space mode after 0.3 s under 60% and leaves after 0.5 s over 85%", function()
		local s = CameraMath.newTight()
		expect(CameraMath.stepTight(s, 5, 10, 0.2)).toBe(false)
		expect(CameraMath.stepTight(s, 7, 10, 0.2)).toBe(false) -- timer resets
		expect(CameraMath.stepTight(s, 5, 10, 0.2)).toBe(false)
		expect(CameraMath.stepTight(s, 5, 10, 0.1)).toBe(true)
		expect(CameraMath.stepTight(s, 8, 10, 1)).toBe(true) -- between: stays
		expect(CameraMath.stepTight(s, 9, 10, 0.4)).toBe(true)
		expect(CameraMath.stepTight(s, 9, 10, 0.1)).toBe(false)
	end)
end)

describe("CameraMath shake (02 §3.4)", function()
	it("decays linearly over its duration", function()
		expect(CameraMath.shakeAmplitude(0.5, 0.25, 0)).toBe(0.5)
		expect(CameraMath.shakeAmplitude(0.5, 0.25, 0.125)).toBeCloseTo(0.25, 1e-9)
		expect(CameraMath.shakeAmplitude(0.5, 0.25, 0.25)).toBe(0)
	end)
end)
