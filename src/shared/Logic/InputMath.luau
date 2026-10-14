--!strict
-- InputMath: the pure half of InputController (docs/09, sections 4.4 and 5.2; module B11). Every
-- control scheme reduces to one `SwimInput` (docs/02, section 1.1); this module holds the
-- mappings, dead zones and curves, and `client/Controllers/InputController` feeds it the raw
-- engine input. Numbers and tables only, so it runs in Lune.
--
-- Schemes at MVP: drag to swim on touch (02 §2.1, 15 §3.1), and on keys the free cursor (the
-- default) or locked mouse look (02 §2.3, 15 §3.3). The gamepad, the two-thumb scheme and the
-- left-handed layout are [L].
--
-- Angles in degrees. Yaw follows SwimModel: 0 faces −Z, positive yaw turns left. `yawRate` in a
-- SwimInput is positive to the right (02 §2.1: screen right is positive). Screen coordinates grow
-- to the right and down, as in `InputObject.Position`.
--
-- Units: the drag numbers are rpx (02 §2, 08 §1.2: a pixel of the 1280 × 720 reference canvas,
-- scaled with the interface). InputController converts touch positions with `toRpx` and the
-- interface scale of Kit/Screen before calling the drag functions. Mouse look and the free
-- cursor stay in device px (02 §2.3).
local Defaults = require("../Config/Defaults")
local Types = require("../Types")

type SwimInput = Types.SwimInput
type InputMode = Types.InputMode

local INPUT = Defaults.input
local PITCH_LIMIT = Defaults.swim.pitchLimit
local DEAD_ZONE = INPUT.dragDeadZone
local FULL = INPUT.dragFull
local CLAMP = INPUT.dragClamp
local EXPONENT = INPUT.curveExponent
local LEVEL_BAND = INPUT.autoLevelBand
local LEVEL_RATE = INPUT.autoLevelRate
local LEVEL_DELAY = INPUT.autoLevelDelay
local DEG_PER_PX = INPUT.mouseDegPerPx
local CURSOR_DEAD_ZONE = INPUT.cursorDeadZone
local CURSOR_FULL = INPUT.cursorFull

local abs, sqrt, sign = math.abs, math.sqrt, math.sign

--- The keys that feed the model in Keys mode (02 §2.3, 15 §3.3). `autoSwim` is the R toggle.
export type Keys = {
	forward: boolean, -- W
	brake: boolean, -- S
	left: boolean, -- A
	right: boolean, -- D
	autoSwim: boolean,
}

local InputMath = {}

local function clamp(v: number, low: number, high: number): number
	return if v < low then low elseif v > high then high else v
end

local function wrap(angle: number): number
	angle %= 360
	return if angle > 180 then angle - 360 else angle
end

--- A neutral SwimInput: no thrust, no turn, level. The caller keeps it and refills it per frame.
function InputMath.newInput(): SwimInput
	return {
		throttle = 0,
		strafe = 0,
		brake = false,
		yawTarget = nil,
		yawRate = 0,
		pitchTarget = 0,
		dash = false,
	}
end

--- The drag sensitivity setting, kept inside its range (02 §2.1: 0.5 to 1.5).
function InputMath.sensitivity(value: number): number
	if value ~= value then
		return INPUT.dragSensitivity
	end
	return clamp(value, INPUT.dragSensitivityMin, INPUT.dragSensitivityMax)
end

--- A screen length or position in device px as rpx, the drag scheme's unit (02 §2, 08 §1.2):
--- px ÷ the interface scale (Kit/Screen `scale()`, rpx to px). A scale that is not positive or
--- not finite counts as 1.
function InputMath.toRpx(px: number, scale: number): number
	if not (scale > 0 and scale < math.huge) then
		return px
	end
	return px / scale
end

--- Full deflection, rpx: 80 divided by the sensitivity (02 §2.1).
function InputMath.dragFull(sensitivity: number): number
	return FULL / InputMath.sensitivity(sensitivity)
end

--- The trailing clamp, rpx. 02 §2.1 gives 100 rpx for the default 80 rpx full deflection, but a
--- sensitivity under 0.8 puts full deflection past 100 rpx, where the drag could never reach it.
--- NOT FROM THE BIBLE: the clamp keeps the 100 : 80 ratio to full deflection when that happens.
function InputMath.dragClamp(sensitivity: number): number
	return math.max(CLAMP, InputMath.dragFull(sensitivity) * CLAMP / FULL)
end

--- Moves the floating origin so the finger is never more than the clamp from it: past the clamp
--- the origin trails the finger, so reversing direction is instant (02 §2.1).
function InputMath.trailOrigin(
	originX: number,
	originY: number,
	touchX: number,
	touchY: number,
	sensitivity: number
): (number, number)
	local dx, dy = touchX - originX, touchY - originY
	local length = sqrt(dx * dx + dy * dy)
	local limit = InputMath.dragClamp(sensitivity)
	if length <= limit then
		return originX, originY
	end
	local k = limit / length
	return touchX - dx * k, touchY - dy * k
end

--- 02 §2.1: curve(v) = sign(v) × |v|^1.4.
function InputMath.curve(v: number): number
	return sign(v) * abs(v) ^ EXPONENT
end

--- The drag vector (finger minus origin, rpx) as magnitude m (0 to 1, dead zone and full
--- deflection applied) and the unit axes x (right +) and y (up +) scaled by m (02 §2.1).
function InputMath.dragAxes(dx: number, dy: number, sensitivity: number): (number, number, number)
	local length = sqrt(dx * dx + dy * dy)
	if not (length > DEAD_ZONE) then
		return 0, 0, 0
	end
	local m = clamp((length - DEAD_ZONE) / (InputMath.dragFull(sensitivity) - DEAD_ZONE), 0, 1)
	return m, dx / length * m, -dy / length * m
end

--- Drag to swim (02 §2.1): throttle = m, yawRate = turnRate × curve(x) (rate control),
--- pitchTarget = 70° × curve(y) (position control), and a drag with |y| < 0.15 levels.
--- `turnRate` is the tier's turn rate in °/s; the model clamps to the effective rate.
function InputMath.fromDrag(
	out: SwimInput,
	dx: number,
	dy: number,
	sensitivity: number,
	turnRate: number
)
	local m, x, y = InputMath.dragAxes(dx, dy, sensitivity)
	out.throttle = m
	out.strafe = 0
	out.brake = false
	out.yawTarget = nil
	out.yawRate = turnRate * InputMath.curve(x)
	out.pitchTarget = if abs(y) < LEVEL_BAND then 0 else PITCH_LIMIT * InputMath.curve(y)
end

--- No swim touch (02 §2.1, Release and Auto-level): throttle 0 and yaw rate 0, so the creature
--- coasts; the pitch target holds for 0.4 s after the lift, then returns to 0° at 90°/s.
--- `sinceRelease` is the time from the lift to the end of this frame.
function InputMath.fromRelease(out: SwimInput, sinceRelease: number, dt: number)
	out.throttle = 0
	out.strafe = 0
	out.brake = false
	out.yawTarget = nil
	out.yawRate = 0
	local relaxing = math.min(dt, sinceRelease - LEVEL_DELAY)
	if relaxing > 0 then
		local pitch = out.pitchTarget
		local step = LEVEL_RATE * relaxing
		out.pitchTarget = if abs(pitch) <= step then 0 else pitch - sign(pitch) * step
	end
end

--- Mouse look (02 §2.3): 0.20° per px × look speed, pitch clamped ±70°. Moving right turns
--- right (yaw falls); moving up (dy < 0) raises the nose. Returns the new look yaw and pitch.
function InputMath.mouseLook(
	yaw: number,
	pitch: number,
	dx: number,
	dy: number,
	lookSpeed: number
): (number, number)
	local k = DEG_PER_PX * clamp(lookSpeed, INPUT.mouseLookSpeedMin, INPUT.mouseLookSpeedMax)
	return wrap(yaw - dx * k), clamp(pitch - dy * k, -PITCH_LIMIT, PITCH_LIMIT)
end

--- Arrow keys (02 §2.3): turn the look direction left and right at the turn rate, and pitch up
--- and down at the same rate, clamped ±70°. `right` and `up` are −1, 0 or 1.
function InputMath.arrowLook(
	yaw: number,
	pitch: number,
	right: number,
	up: number,
	turnRate: number,
	dt: number
): (number, number)
	local step = turnRate * dt
	return wrap(yaw - right * step), clamp(pitch + up * step, -PITCH_LIMIT, PITCH_LIMIT)
end

--- A pair of held keys as one axis: 1, −1, or 0 when both or neither are held. Vertical on keys
--- (02 §2.3, 15 §3.3): Space or Arrow Up is `positive`, Shift or Arrow Down `negative`; turning:
--- Arrow Right is `positive`.
function InputMath.axis(positive: boolean, negative: boolean): number
	return (if positive then 1 else 0) - (if negative then 1 else 0)
end

--- Free cursor (02 §2.3, 15 §3.3): the cursor's horizontal offset from the viewport centre (device
--- px, right +) as an axis −1 to 1. Inside the dead zone (3 % of the viewport width) it is 0; it
--- rises linearly from the dead zone edge to 1 at full deflection (30 % of the width). A viewport
--- width that is not positive or not finite gives 0.
function InputMath.cursorAxis(offsetX: number, viewportWidth: number): number
	if not (viewportWidth > 0 and viewportWidth < math.huge) then
		return 0
	end
	local dead = CURSOR_DEAD_ZONE * viewportWidth
	local length = abs(offsetX)
	if not (length > dead) then
		return 0
	end
	return sign(offsetX) * clamp((length - dead) / (CURSOR_FULL * viewportWidth - dead), 0, 1)
end

--- Free cursor steering (02 §2.3, 15 §3.3): yawRate = turnRate × curve(x), the phone's curve
--- (02 §2.1), positive to the right. Rate control: the cursor back at the centre swims straight.
--- The cursor's vertical position is ignored.
function InputMath.cursorSteer(offsetX: number, viewportWidth: number, turnRate: number): number
	return turnRate * InputMath.curve(InputMath.cursorAxis(offsetX, viewportWidth))
end

--- Keys, both schemes (02 §2.3): W throttle 1 (or auto-swim), S brake, A and D strafe −1 and +1.
local function fromKeyThrust(out: SwimInput, keys: Keys)
	out.throttle = if keys.forward or keys.autoSwim then 1 else 0
	out.brake = keys.brake
	out.strafe = (if keys.right then 1 else 0) - (if keys.left then 1 else 0)
end

--- Locked mouse look (02 §2.3, 15 §3.3, the `keys_locked` scheme): the facing target is the look
--- direction. No auto-level.
function InputMath.fromKeys(out: SwimInput, keys: Keys, lookYaw: number, lookPitch: number)
	fromKeyThrust(out, keys)
	out.yawTarget = lookYaw
	out.yawRate = 0
	out.pitchTarget = clamp(lookPitch, -PITCH_LIMIT, PITCH_LIMIT)
end

--- Free cursor (02 §2.3, 15 §3.3, the `keys` scheme, the default): `steer` is the cursor's yaw
--- rate (`cursorSteer`, °/s, right +); Arrow Left and Right (`right`, −1, 0 or 1) add the tier's
--- full turn rate, and the model clamps the sum. `up` (`axis` of Space or Arrow Up against Shift or
--- Arrow Down) sets the pitch target to ±70°; 0, both or neither held, levels the creature at the
--- model's pitch rate (position control, as on the phone).
function InputMath.fromCursorKeys(
	out: SwimInput,
	keys: Keys,
	steer: number,
	right: number,
	up: number,
	turnRate: number
)
	fromKeyThrust(out, keys)
	out.yawTarget = nil
	out.yawRate = steer + right * turnRate
	out.pitchTarget = PITCH_LIMIT * clamp(up, -1, 1)
end

--- Auto-swim after a key press (02 §2.3): R toggles it; W or S ends it.
function InputMath.autoSwim(on: boolean, key: "W" | "S" | "R"): boolean
	if key == "R" then
		return not on
	end
	return false
end

--- The input mode for a `UserInputService.PreferredInput` value, by its enum item name (15 §2.2,
--- §5.1, PF18). An unknown name keeps `current`.
function InputMath.mode(preferredInput: string, current: InputMode): InputMode
	if preferredInput == "Touch" then
		return "Touch"
	elseif preferredInput == "KeyboardAndMouse" then
		return "Keys"
	elseif preferredInput == "Gamepad" or preferredInput == "MicroGamepad" then
		return "Pad"
	end
	return current
end

--- The fallback of 15 §5.1 when `PreferredInput` is unreliable: the mode for a
--- `UserInputService:GetLastInputType()` value, by its enum item name. Unknown keeps `current`.
function InputMath.modeOfInputType(inputType: string, current: InputMode): InputMode
	if inputType == "Touch" then
		return "Touch"
	elseif inputType == "Keyboard" or string.sub(inputType, 1, 5) == "Mouse" then
		return "Keys"
	elseif string.sub(inputType, 1, 7) == "Gamepad" then
		return "Pad"
	end
	return current
end

return table.freeze(InputMath)
