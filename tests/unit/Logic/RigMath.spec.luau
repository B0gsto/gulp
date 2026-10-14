--!strict
local BiteMath = require("../../../src/shared/Logic/BiteMath")
local RigMath = require("../../../src/shared/Logic/RigMath")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local DT = 1 / 60

-- Runs a follow against a target moving along -Z at `speed` for `seconds`; returns the follow
-- and the target's final z.
local function chase(
	speed: number,
	seconds: number,
	tau: number,
	maxSpeed: number
): (RigMath.Follow, number)
	local f = RigMath.newFollow()
	local z = 0
	RigMath.stepPosition(f, 0, 0, z, 0, 0, -speed, maxSpeed, DT, tau)
	for _ = 1, math.round(seconds / DT) do
		z -= speed * DT
		RigMath.stepPosition(f, 0, 0, z, 0, 0, -speed, maxSpeed, DT, tau)
	end
	return f, z
end

describe("RigMath.stepPosition", function()
	it("sits within 0.5 studs of a constant-velocity target after 0.5 s (09 §6.7)", function()
		for _, tau in { RigMath.TAU_OWN, RigMath.TAU_OTHER } do
			for _, speed in { 38, 90 } do
				local f, z = chase(speed, 0.5, tau, 1000)
				expect(math.abs(f.z - z) < 0.5).toBe(true)
				-- and at 30 fps (a low phone)
				local f30 = RigMath.newFollow()
				local z30 = 0
				for _ = 1, 15 do
					z30 -= speed / 30
					RigMath.stepPosition(f30, 0, 0, z30, 0, 0, -speed, 1000, 1 / 30, tau)
				end
				expect(math.abs(f30.z - z30) < 0.5).toBe(true)
				expect(math.abs(f.x) + math.abs(f.y)).toBeCloseTo(0, 1e-9)
			end
		end
	end)

	it("trails by about 2τv without the lead (why the lead exists, spike F1)", function()
		-- maxSpeed 0 clamps the lead velocity to zero: a plain spring. The frame-end target makes
		-- the discrete step trail half a frame less (v·dt/2).
		local f, z = chase(38, 1.0, RigMath.TAU_OTHER, 0)
		expect(f.z - z).toBeCloseTo(2 * RigMath.TAU_OTHER * 38 - 38 * DT / 2, 0.05)
	end)

	it("clamps the lead velocity so an overshoot cannot throw the lead point", function()
		local vx, vy, vz = RigMath.clampSpeed(300, 0, 400, 50)
		expect(math.sqrt(vx * vx + vy * vy + vz * vz)).toBeCloseTo(50, 1e-9)
		expect(vx / vz).toBeCloseTo(0.75, 1e-9)
		local a, b, c = RigMath.clampSpeed(3, 4, 0, 50)
		expect(a).toBe(3)
		expect(b).toBe(4)
		expect(c).toBe(0)
	end)

	it("snaps on the first frame and on a teleport, and smooths otherwise", function()
		local f = RigMath.newFollow()
		expect(RigMath.stepPosition(f, 5, 6, 7, 0, 0, 0, 10, DT, 0.08)).toBe(true)
		expect(f.x).toBe(5)
		expect(RigMath.stepPosition(f, 6, 6, 7, 0, 0, 0, 10, DT, 0.08)).toBe(false)
		expect(f.x > 5 and f.x < 6).toBe(true)
		expect(RigMath.stepPosition(f, 500, 6, 7, 0, 0, 0, 10, DT, 0.08)).toBe(true)
		expect(f.x).toBe(500)
	end)
end)

describe("RigMath heading and bank", function()
	it("faces the velocity above 2 studs/s, else the root's look vector", function()
		local x, y, z = RigMath.lookDirection(0, 0, 10, 1, 0, 0)
		expect(z).toBeCloseTo(1, 1e-9)
		x, y, z = RigMath.lookDirection(0, 1, 0, 2, 0, 0)
		expect(x).toBeCloseTo(1, 1e-9)
		expect(y + z).toBeCloseTo(0, 1e-9)
	end)

	it("turns toward the look direction, stays unit, and banks into the turn", function()
		local f = RigMath.newFollow()
		RigMath.reset(f, 0, 0, 0, 0, 0, -1)
		-- Turn left: from facing -Z toward -X (positive yaw in Roblox).
		local maxBank = 0
		for _ = 1, 30 do
			RigMath.stepHeading(f, -1, 0, 0, DT)
			expect(math.sqrt(f.hx * f.hx + f.hy * f.hy + f.hz * f.hz)).toBeCloseTo(1, 1e-6)
			maxBank = math.max(maxBank, f.bank)
		end
		expect(f.hx < -0.9).toBe(true)
		expect(maxBank > 0).toBe(true)
		expect(maxBank <= RigMath.BANK_MAX).toBe(true)
		-- Holding the heading lets the bank settle back to level.
		for _ = 1, 120 do
			RigMath.stepHeading(f, -1, 0, 0, DT)
		end
		expect(math.abs(f.bank) < 0.01).toBe(true)
	end)

	it("survives a full reversal", function()
		local f = RigMath.newFollow()
		RigMath.reset(f, 0, 0, 0, 0, 0, -1)
		for _ = 1, 60 do
			RigMath.stepHeading(f, 0, 0, 1, DT)
		end
		expect(f.hz > 0.99).toBe(true)
		expect(f.bank == f.bank).toBe(true) -- not NaN
	end)
end)

describe("RigMath scale ease (09 §6.8)", function()
	it("eases to the new scale over 0.15 s with no jump", function()
		local e = RigMath.newScale(1)
		local _, moving = RigMath.stepScale(e, DT)
		expect(moving).toBe(false)
		RigMath.retargetScale(e, 2)
		local last, steps = 1, 0
		while true do
			local v, changed = RigMath.stepScale(e, DT)
			if not changed then
				break
			end
			steps += 1
			expect(v >= last).toBe(true)
			expect(v - last < 0.2).toBe(true) -- smooth: no step bigger than a sixth of the change
			last = v
		end
		expect(last).toBeCloseTo(2, 1e-9)
		expect(steps).toBe(math.ceil(RigMath.SCALE_TIME / DT - 1e-9))
	end)

	it("restarts from the current value when retargeted mid-ease, and ignores repeats", function()
		local e = RigMath.newScale(1)
		RigMath.retargetScale(e, 3)
		RigMath.stepScale(e, 0.075)
		local mid = e.value
		expect(mid > 1 and mid < 3).toBe(true)
		RigMath.retargetScale(e, 3)
		expect(e.from).toBe(1)
		RigMath.retargetScale(e, 1)
		expect(e.from).toBe(mid)
		local v = RigMath.stepScale(e, 0.001)
		expect(math.abs(v - mid) < 0.01).toBe(true)
	end)
end)

describe("RigMath clips and sway", function()
	it("uses 07 §2.1's clip lengths at 30 fps", function()
		expect(RigMath.CLIP_SECONDS.Swim).toBeCloseTo(16 / 30, 1e-9)
		expect(RigMath.CLIP_SECONDS.SwimFast).toBeCloseTo(8 / 30, 1e-9)
		expect(RigMath.CLIP_SECONDS.Idle).toBeCloseTo(2, 1e-9)
		expect(RigMath.CLIP_SECONDS.Dash).toBeCloseTo(14 / 30, 1e-9)
		expect(RigMath.CLIP_SECONDS.TierUp).toBeCloseTo(18 / 30, 1e-9)
		expect(#RigMath.CLIPS).toBe(6)
	end)

	it("pops 0.6 s to 112% and settles back on the scale (02 §1.8)", function()
		expect(RigMath.popMult(-0.1)).toBe(1)
		expect(RigMath.popMult(0)).toBe(1)
		expect(RigMath.popMult(0.6)).toBe(1)
		expect(RigMath.popMult(1)).toBe(1)
		local peak, at = 0, 0
		for i = 1, 599 do
			local t = i / 1000
			local m = RigMath.popMult(t)
			expect(m >= 1).toBe(true)
			if m > peak then
				peak, at = m, t
			end
		end
		expect(peak).toBeCloseTo(1.12, 1e-4)
		expect(at < 0.3).toBe(true) -- a quick rise, a longer settle
		expect(RigMath.popMult(0.59) < 1.01).toBe(true)
	end)

	it("picks the loop by speed", function()
		expect(RigMath.loopFor(0, 20)).toBe("Idle")
		expect(RigMath.loopFor(15, 20)).toBe("Swim")
		expect(RigMath.loopFor(40, 20)).toBe("SwimFast")
	end)

	it("sways as a loop that grows toward the tail", function()
		local tail, spine1
		for _, bone in RigMath.SWAY do
			local a0 = RigMath.sway(bone, 0, 1)
			local a1 = RigMath.sway(bone, 1, 1)
			expect(a0).toBeCloseTo(a1, 1e-9)
			if bone.name == "TailFin" then
				tail = bone
			elseif bone.name == "Spine1" then
				spine1 = bone
			end
		end
		assert(tail and spine1, "TailFin and Spine1 are in the wave")
		local peakTail, peakHead = 0, 0
		for i = 0, 15 do
			peakTail = math.max(peakTail, math.abs((RigMath.sway(tail, i / 16, 1))))
			peakHead = math.max(peakHead, math.abs((RigMath.sway(spine1, i / 16, 1))))
		end
		expect(peakTail > 10 * peakHead).toBe(true)
		expect(math.abs(RigMath.pecFlap(0.1, 1)) <= math.rad(14) + 1e-9).toBe(true)
	end)
end)

describe("RigMath.mouth (02 §4.1)", function()
	it("scales with bodyScale and grows 25% in a dash", function()
		local r, ahead = RigMath.mouth(1, 1, false)
		expect(r).toBeCloseTo(1.2, 1e-9)
		expect(ahead).toBeCloseTo(1.5 + 0.6, 1e-9)
		local rd = RigMath.mouth(2, 1, true)
		expect(rd).toBeCloseTo(1.2 * 2 * 1.25, 1e-9)
		-- lengthMult moves the nose, firstRun (04 §4) widens the mouth: BiteMath's numbers.
		local rf, aheadF = RigMath.mouth(2, 1.1, false, 1.2, 1.6)
		expect(rf).toBeCloseTo(BiteMath.mouthRadius(2, 1.1, false, 1.6), 1e-9)
		expect(aheadF).toBeCloseTo(BiteMath.mouthAhead(2, 1.2, rf), 1e-9)
		expect(aheadF).toBeCloseTo(1.5 * 2 * 1.2 + 0.5 * rf, 1e-9)
	end)
end)
