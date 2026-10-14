--!strict
local InputMath = require("../../../src/shared/Logic/InputMath")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function keys(overrides: { [string]: boolean }?): InputMath.Keys
	local k: InputMath.Keys =
		{ forward = false, brake = false, left = false, right = false, autoSwim = false }
	for name, value in overrides or {} do
		(k :: any)[name] = value
	end
	return k
end

describe("InputMath drag to swim (02 §2.1)", function()
	it("converts device px to rpx with the interface scale (08 §1.2)", function()
		-- A phone at scale 0.52: a 14 rpx dead zone is 7.28 device px.
		expect(InputMath.toRpx(7.28, 0.52)).toBeCloseTo(14, 1e-9)
		expect(InputMath.toRpx(160, 2)).toBe(80)
		expect(InputMath.toRpx(30, 0)).toBe(30)
		expect(InputMath.toRpx(30, 0 / 0)).toBe(30)
		local m = InputMath.dragAxes(InputMath.toRpx(41.6, 0.52), 0, 1)
		expect(m).toBeCloseTo(1, 1e-9) -- 41.6 px at 0.52 is the 80 rpx full deflection
	end)

	it("gives nothing inside the 14 rpx dead zone", function()
		local m, x, y = InputMath.dragAxes(10, -9, 1)
		expect(m).toBe(0)
		expect(x).toBe(0)
		expect(y).toBe(0)
		expect((InputMath.dragAxes(0, 0, 1))).toBe(0)
	end)

	it("reaches full deflection at 80 rpx and stays there", function()
		expect((InputMath.dragAxes(80, 0, 1))).toBeCloseTo(1, 1e-9)
		expect((InputMath.dragAxes(0, 95, 1))).toBe(1)
		-- halfway between the dead zone and full: m = (47 − 14) / 66
		expect((InputMath.dragAxes(47, 0, 1))).toBeCloseTo(0.5, 1e-9)
	end)

	it("divides the full-deflection distance by the sensitivity", function()
		expect(InputMath.dragFull(1)).toBe(80)
		expect(InputMath.dragFull(2)).toBeCloseTo(80 / 1.5, 1e-9) -- clamped to 1.5
		expect(InputMath.dragFull(0.5)).toBe(160)
		expect((InputMath.dragAxes(80 / 1.5, 0, 1.5))).toBeCloseTo(1, 1e-9)
		expect(InputMath.sensitivity(0 / 0)).toBe(1)
	end)

	it("maps screen right to a right turn and screen up to nose up", function()
		local input = InputMath.newInput()
		InputMath.fromDrag(input, 80, 0, 1, 360)
		expect(input.throttle).toBeCloseTo(1, 1e-9)
		expect(input.yawRate).toBeCloseTo(360, 1e-9)
		expect(input.pitchTarget).toBe(0)
		expect(input.yawTarget).toBe(nil)
		InputMath.fromDrag(input, 0, -80, 1, 360)
		expect(input.yawRate).toBeCloseTo(0, 1e-9)
		expect(input.pitchTarget).toBeCloseTo(70, 1e-9)
		InputMath.fromDrag(input, -47, 0, 1, 360)
		expect(input.yawRate).toBeCloseTo(-360 * 0.5 ^ 1.4, 1e-9)
	end)

	it("applies the 1.4 curve to both axes", function()
		expect(InputMath.curve(0.5)).toBeCloseTo(0.5 ^ 1.4, 1e-12)
		expect(InputMath.curve(-0.5)).toBeCloseTo(-(0.5 ^ 1.4), 1e-12)
		expect(InputMath.curve(0)).toBe(0)
		local input = InputMath.newInput()
		-- 45° down at full deflection: y = −√½, pitch = −70 × (√½)^1.4
		InputMath.fromDrag(input, 80, 80, 1, 300)
		expect(input.pitchTarget).toBeCloseTo(-70 * math.sqrt(0.5) ^ 1.4, 1e-9)
	end)

	it("levels any drag with |y| < 0.15", function()
		local input = InputMath.newInput()
		-- full deflection, 8° above the horizontal: y = sin 8° ≈ 0.139
		local a = math.rad(8)
		InputMath.fromDrag(input, 80 * math.cos(a), -80 * math.sin(a), 1, 360)
		expect(input.pitchTarget).toBe(0)
		local b = math.rad(10) -- y ≈ 0.174
		InputMath.fromDrag(input, 80 * math.cos(b), -80 * math.sin(b), 1, 360)
		expect(input.pitchTarget > 0).toBe(true)
	end)

	it("trails the origin behind a finger past the 100 rpx clamp", function()
		local ox, oy = InputMath.trailOrigin(0, 0, 60, 0, 1)
		expect(ox).toBe(0)
		expect(oy).toBe(0)
		ox, oy = InputMath.trailOrigin(0, 0, 130, 0, 1)
		expect(ox).toBeCloseTo(30, 1e-9)
		expect(oy).toBeCloseTo(0, 1e-9)
		-- reversing from the clamp is instant: 2 × 100 rpx back passes through the origin
		ox, oy = InputMath.trailOrigin(ox, oy, 0, 300, 1)
		local dx, dy = 0 - ox, 300 - oy
		expect(math.sqrt(dx * dx + dy * dy)).toBeCloseTo(100, 1e-9)
	end)

	it("never clamps inside full deflection at a low sensitivity", function()
		expect(InputMath.dragClamp(1)).toBe(100)
		expect(InputMath.dragClamp(1.5)).toBe(100)
		expect(InputMath.dragClamp(0.5)).toBe(200)
	end)

	it("coasts on release and levels at 90°/s after 0.4 s", function()
		local input = InputMath.newInput()
		InputMath.fromDrag(input, 0, -80, 1, 360)
		InputMath.fromRelease(input, 0.3, 0.1)
		expect(input.throttle).toBe(0)
		expect(input.yawRate).toBe(0)
		expect(input.pitchTarget).toBeCloseTo(70, 1e-9) -- still holding
		InputMath.fromRelease(input, 0.5, 0.2) -- 0.1 s of it is past the delay
		expect(input.pitchTarget).toBeCloseTo(61, 1e-9)
		InputMath.fromRelease(input, 2, 1)
		expect(input.pitchTarget).toBe(0)
	end)
end)

describe("InputMath keys and mouse (02 §2.3)", function()
	it("maps W, S, A and D", function()
		local input = InputMath.newInput()
		InputMath.fromKeys(input, keys({ forward = true, left = true }), 30, -10)
		expect(input.throttle).toBe(1)
		expect(input.strafe).toBe(-1)
		expect(input.brake).toBe(false)
		expect(input.yawTarget).toBe(30)
		expect(input.pitchTarget).toBe(-10)
		InputMath.fromKeys(input, keys({ brake = true, right = true }), 0, 0)
		expect(input.throttle).toBe(0)
		expect(input.brake).toBe(true)
		expect(input.strafe).toBe(1)
		InputMath.fromKeys(input, keys({ autoSwim = true }), 0, 0)
		expect(input.throttle).toBe(1)
	end)

	it("toggles auto-swim with R and ends it with W or S", function()
		expect(InputMath.autoSwim(false, "R")).toBe(true)
		expect(InputMath.autoSwim(true, "R")).toBe(false)
		expect(InputMath.autoSwim(true, "W")).toBe(false)
		expect(InputMath.autoSwim(true, "S")).toBe(false)
	end)

	it("turns the look 0.20° per px, right is a right turn, pitch clamped ±70°", function()
		local yaw, pitch = InputMath.mouseLook(0, 0, 100, -50, 1)
		expect(yaw).toBeCloseTo(-20, 1e-9)
		expect(pitch).toBeCloseTo(10, 1e-9)
		yaw, pitch = InputMath.mouseLook(170, 60, -100, -500, 2)
		expect(yaw).toBeCloseTo(-150, 1e-9) -- 170 + 40 wraps
		expect(pitch).toBe(70)
	end)

	it("turns the look with arrow keys at the turn rate", function()
		local yaw, pitch = InputMath.arrowLook(0, 0, 1, 1, 360, 0.1)
		expect(yaw).toBeCloseTo(-36, 1e-9)
		expect(pitch).toBeCloseTo(36, 1e-9)
		yaw, pitch = InputMath.arrowLook(0, 60, -1, 1, 360, 0.1)
		expect(yaw).toBeCloseTo(36, 1e-9)
		expect(pitch).toBe(70)
	end)
end)

describe("InputMath input mode (15 §5.1)", function()
	it("follows PreferredInput", function()
		expect(InputMath.mode("Touch", "Keys")).toBe("Touch")
		expect(InputMath.mode("KeyboardAndMouse", "Touch")).toBe("Keys")
		expect(InputMath.mode("Gamepad", "Keys")).toBe("Pad")
		expect(InputMath.mode("Something", "Touch")).toBe("Touch")
	end)

	it("falls back on the last input type", function()
		expect(InputMath.modeOfInputType("MouseMovement", "Touch")).toBe("Keys")
		expect(InputMath.modeOfInputType("Keyboard", "Pad")).toBe("Keys")
		expect(InputMath.modeOfInputType("Gamepad1", "Keys")).toBe("Pad")
		expect(InputMath.modeOfInputType("Touch", "Keys")).toBe("Touch")
		expect(InputMath.modeOfInputType("Focus", "Keys")).toBe("Keys")
	end)
end)
