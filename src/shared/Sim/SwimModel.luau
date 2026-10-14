--!strict
--!native
--!optimize 2
-- SwimModel: the creature's movement as a pure step function (docs/09, section 3 and 6.5; module
-- B08). Chapter 02 owns the rules: section 1.2 speed, 1.3 thrust, drag and coasting, 1.4 turning
-- and pitch, 1.5 no buoyancy, 1.7 surface and breaching, 2.5 input buffering, 7.1 the dash.
--
-- Numbers only (09 §4.4): positions and velocities are x, y, z fields of one state table that
-- the caller creates once and `step` mutates in place, so a step allocates nothing (09 §4.7).
-- A step depends only on the state, the input and dt, so a trace is deterministic, and every
-- rate is integrated in closed form so 30 fps and 60 fps traces agree.
--
-- Not here, by design: terrain collision, stuck recovery and the world-edge wall (02 §1.6) are
-- the engine's, against the collision shell; statuses are set by MovementController through
-- `state.mods`; the validator (B14) reuses the pure speed rules at the bottom of this file.
--
-- Frame: Roblox world axes, Y up, the surface is Y = 0 (02 §0.1). Yaw and pitch in degrees as in
-- `CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)`: yaw 0 faces −Z, positive yaw turns left, positive
-- pitch raises the nose. The look vector is (−sin yaw × cos pitch, sin pitch, −cos yaw × cos pitch).
local Defaults = require("../Config/Defaults")
local Index = require("../Data/Index")
local Types = require("../Types")

local SWIM = Defaults.swim
local BY_TIER = SWIM.byTier
local STRAFE_MULT = SWIM.strafeMult
local STOP_SPEED = SWIM.stopSpeed
local TURN_GAIN = SWIM.turnGain
local PITCH_LIMIT = SWIM.pitchLimit
local DASH_DURATION = SWIM.dashDuration
local DASH_LONGFIN_ADD = SWIM.dashLongfinAdd
local DASH_ACCEL = SWIM.dashAccel
local DASH_TURN_MULT = SWIM.dashTurnMult
local INPUT_BUFFER = SWIM.inputBuffer
local CURRENT_MULT = SWIM.currentMult
local BREACH_SPEED = SWIM.breachSpeed
local SKIM_DEPTH = SWIM.skimDepth
local COLLISION_RADIUS = SWIM.collisionRadius
local GRAVITY = SWIM.gravity
local AIR_TURN_MULT = SWIM.airTurnMult
local MIN_AIR_TIME = SWIM.minAirTime
local REENTRY_MULT = SWIM.reentryMult

-- 09 §7.1: √(1 + 0.6²) rounded up, full forward speed plus a full strafe (02 §1.3). (tune)
local SLIDE_MULT = 1.17
-- 09 §7.1: the dash window opens this long before the accepted dash start and closes this long
-- after the dash ends; the cooldown is checked with this slack.
local DASH_WINDOW_BEFORE = 0.10
local DASH_WINDOW_AFTER = 0.25
local DASH_COOLDOWN_SLACK = 0.15
-- 09 §7.2 and 7.4: ping counts up to this much (s) when a claimed press time is checked.
local PING_CAP = 0.3

-- The longest dt one step simulates. A longer frame (a hitch, a debugger pause) is treated as
-- this long, so the creature slows down rather than jumping, and never outruns the validator.
-- NOT FROM THE BIBLE: chapter 02 gives no value. (tune)
local MAX_DT = 0.1

local exp, abs, sin, cos, rad, sqrt = math.exp, math.abs, math.sin, math.cos, math.rad, math.sqrt

-- MicroProfiler labels (09 §4.7). Lune has no MicroProfiler, so fall back to doing nothing.
local profileBegin: (string) -> () = debug.profilebegin or function(_label: string) end
local profileEnd: () -> () = debug.profileend or function() end

--- Statuses, traits and volumes that change movement, set by MovementController (09 §5.2,
--- `setStatus`). The model applies Dashing and Airborne itself.
export type SwimMods = {
	-- Product of the active multipliers of 02 §1.2: Stripes 1.08, Rampaging 1.25, Puffed 0.40,
	-- Slowed 0.50, Swallowing 0.60. 1 when none is active.
	speedMult: number,
	-- 02 §1.4: 0 while Stunned, Tucked or Hooked, 0.3 while Jetting, else 1.
	turnMult: number,
	-- false while the creature has no thrust (Stunned, Tucked, Hooked, ...): it coasts.
	canThrust: boolean,
	-- 02 §7.1: true while Stunned, Hooked, Transit, Banking, Gulped, Puffed, Tucked or Bumped.
	-- Airborne is checked by the model.
	dashBlocked: boolean,
	-- Number of Longfin traits: each adds 0.3 to the dash length multiplier (02 §7.1).
	longfins: number,
	-- Unit direction of the current the centre is in, or 0, 0, 0 (02 §1.2: + 0.6 × tierSpeed).
	currentX: number,
	currentY: number,
	currentZ: number,
}

export type SwimState = {
	-- Who is swimming. Change with `setTier`, `setBodyScale`; never write these directly.
	speciesId: string,
	tier: number,
	tierSpeed: number, -- Tiers[tier].swimSpeed
	speedMult: number, -- species.speedMult
	turnRate: number, -- Tiers[tier].turnRate × species.turnMult, °/s
	radiusMult: number, -- species.radiusMult
	dashCooldown: number, -- species.dashCooldown, s from the start of a dash
	dashDurationMult: number, -- species.dashDurationMult
	dashMult: number, -- species.dashMult: dash speed = top speed × this (02 §1.2, 03 §1.1)
	accelMult: number, -- species.accelMult: multiplies the four rates below (02 §1.3, 03 §1.1)
	accel: number, -- 02 §1.3 × species.accelMult, 1/s
	coast: number,
	brake: number,
	grip: number,
	radius: number, -- collision radius, studs (02 §0.2)

	-- Pose. Write with `place`.
	x: number,
	y: number,
	z: number,
	vx: number, -- the model's own velocity, without the current
	vy: number,
	vz: number,
	yaw: number, -- degrees, (−180, 180]
	pitch: number, -- degrees, −70 to 70
	lookX: number, -- unit facing, kept in step with yaw and pitch
	lookY: number,
	lookZ: number,

	-- Motion state.
	airborne: boolean, -- 02 §0.6 base state Airborne: above the surface after a breach
	airTime: number, -- seconds since the breach while airborne
	dashing: boolean, -- 02 §0.6 overlay Dashing
	dashAge: number, -- seconds since the last dash started (math.huge before the first)
	dashLength: number, -- length of the current or last dash, s
	dashBuffer: number, -- seconds a blocked dash press stays buffered (02 §2.5)

	-- What happened during the last step, for effects and messages. Reset by every step.
	dashStarted: boolean, -- MovementController sends `Ability` (09 §7.1)
	breached: boolean, -- crossed Y = 0 going up
	splashed: boolean, -- re-entered the water (FX_Splash, 02 §1.7)

	mods: SwimMods,
}

local SwimModel = {}

SwimModel.MAX_DT = MAX_DT

local function tierDef(tier: number): Types.TierDef
	local def = Index.Tiers.byTier[tier]
	if def == nil or BY_TIER[tier] == nil then
		error(`SwimModel: no tier {tier}`, 2)
	end
	return def
end

local function speciesDef(speciesId: string): Types.SpeciesDef
	local def = Index.Species.byId[speciesId]
	if def == nil then
		error(`SwimModel: no species {speciesId}`, 2)
	end
	return def
end

-- Angle in degrees wrapped to [−180, 180).
local function wrap(angle: number): number
	return (angle + 180) % 360 - 180
end

-- How far an angle moves toward a target `err` degrees away in `h` seconds when its angular
-- speed is clamp(error × TURN_GAIN, ±rate) (02 §1.4), solved exactly: a constant-rate part
-- down to the knee rate / TURN_GAIN, then an exponential ease.
local function approach(err: number, rate: number, h: number): number
	if rate <= 0 or err == 0 then
		return 0
	end
	local size = abs(err)
	local remaining = size
	local knee = rate / TURN_GAIN
	if size > knee then
		local toKnee = (size - knee) / rate
		if h <= toKnee then
			return if err > 0 then rate * h else -rate * h
		end
		h -= toKnee
		remaining = knee
	end
	local moved = size - remaining * exp(-TURN_GAIN * h)
	return if err > 0 then moved else -moved
end

-- A number from an input field, NaN and infinities made safe.
local function clampInput(value: number, low: number, high: number): number
	if value > high then
		return high
	elseif value >= low then
		return value
	elseif value < low then
		return low
	end
	return 0 -- NaN
end

-- The ballistic arc above the surface (02 §1.7): no thrust, no drag, gravity only, solved
-- exactly. A current does not reach the air. Re-entry scales the velocity by 0.8.
local function fly(s: SwimState, h: number)
	local vy = s.vy
	s.x += s.vx * h
	s.y += vy * h - 0.5 * GRAVITY * h * h
	s.z += s.vz * h
	s.vy = vy - GRAVITY * h
	s.airTime += h
	if s.y < 0 and s.airTime >= MIN_AIR_TIME then
		s.airborne = false
		s.splashed = true
		s.vx *= REENTRY_MULT
		s.vy *= REENTRY_MULT
		s.vz *= REENTRY_MULT
	end
end

-- Turn, then move, for `h` seconds with the dash on or off. `step` calls it once, or twice when
-- the dash ends inside the frame.
local function integrate(
	s: SwimState,
	h: number,
	throttle: number,
	strafe: number,
	brake: boolean,
	dashing: boolean,
	yawTarget: number?,
	yawRate: number,
	pitchTarget: number
)
	if h <= 0 then
		return
	end
	local mods = s.mods

	-- Turning (02 §1.4): one rate for yaw and pitch, and it works at zero speed.
	local rate = s.turnRate * mods.turnMult
	if dashing then
		rate *= DASH_TURN_MULT
	end
	if s.airborne then
		rate *= AIR_TURN_MULT
	end
	local yaw0, pitch0 = s.yaw, s.pitch
	local turned
	if yawTarget ~= nil then
		turned = approach(wrap(yawTarget - yaw0), rate, h)
	else
		turned = -(if yawRate > rate then rate elseif yawRate < -rate then -rate else yawRate) * h
	end
	local pitch = pitch0 + approach(pitchTarget - pitch0, rate, h)
	pitch = if pitch > PITCH_LIMIT
		then PITCH_LIMIT
		elseif pitch < -PITCH_LIMIT then -PITCH_LIMIT
		else pitch
	s.yaw = wrap(yaw0 + turned)
	s.pitch = pitch
	local yawR, pitchR = rad(s.yaw), rad(pitch)
	local cp = cos(pitchR)
	s.lookX, s.lookY, s.lookZ = -sin(yawR) * cp, sin(pitchR), -cos(yawR) * cp

	-- Thrust acts along the facing halfway through the turn, which keeps a turning trace the same
	-- at any frame rate (the error is second order in dt).
	yawR, pitchR = rad(yaw0 + 0.5 * turned), rad(0.5 * (pitch0 + pitch))
	cp = cos(pitchR)
	local sy, cy = sin(yawR), cos(yawR)
	local lx, ly, lz = -sy * cp, sin(pitchR), -cy * cp

	if s.airborne then
		fly(s, h)
		return
	end

	-- Thrust, drag and coasting (02 §1.3, §7.1): split the velocity along the new facing.
	local top = s.tierSpeed * s.speedMult * mods.speedMult
	local target, k
	if dashing then
		target, k = top * s.dashMult, DASH_ACCEL
	elseif brake then
		target, k = 0, s.brake
	elseif throttle > 0 then
		target, k = top * throttle, s.accel
	else
		target, k = 0, s.coast
	end

	local ox, oy, oz = s.vx, s.vy, s.vz
	local forward = ox * lx + oy * ly + oz * lz
	local latX, latY, latZ = ox - forward * lx, oy - forward * ly, oz - forward * lz
	forward += (target - forward) * (1 - exp(-k * h))
	local side = top * STRAFE_MULT * strafe
	local g = 1 - exp(-s.grip * h)
	-- The right vector is (cos yaw, 0, −sin yaw), square to the facing at any pitch.
	latX += (side * cy - latX) * g
	latY -= latY * g
	latZ += (-side * sy - latZ) * g
	local vx, vy, vz = forward * lx + latX, forward * ly + latY, forward * lz + latZ
	if
		not dashing
		and throttle == 0
		and strafe == 0
		and vx * vx + vy * vy + vz * vz < STOP_SPEED * STOP_SPEED
	then
		vx, vy, vz = 0, 0, 0
	end
	s.vx, s.vy, s.vz = vx, vy, vz

	-- Move by the mean of the old and new velocity, plus the current (02 §1.2, after everything).
	local drift = CURRENT_MULT * s.tierSpeed * h
	local ax, ay, az = (ox + vx) * 0.5, (oy + vy) * 0.5, (oz + vz) * 0.5
	local y0 = s.y
	s.x += ax * h + mods.currentX * drift
	s.y += ay * h + mods.currentY * drift
	s.z += az * h + mods.currentZ * drift

	-- Surface (02 §1.7).
	if s.y > 0 then
		-- Breach. Go back to the crossing and fly the part of the step spent above Y = 0.
		local over = if ay > 0 then s.y / ay else 0
		if over > h then
			over = h
		end
		s.x -= ax * over
		s.y = 0
		s.z -= az * over
		s.airborne = true
		s.airTime = 0
		s.breached = true
		s.vy = if vy > 0 then vy else 0
		fly(s, over)
	else
		local skim = -SKIM_DEPTH * s.radius
		if s.y > skim and vy > 0 and vy < BREACH_SPEED then
			-- Skim: upward speed below the breach speed rides with the back out of the water.
			s.vy = 0
			local ceiling = if y0 > skim then y0 else skim
			if s.y > ceiling then
				s.y = ceiling
			end
		end
	end
end

--- A fresh set of mods: no status, no trait, no current.
function SwimModel.newMods(): SwimMods
	return {
		speedMult = 1,
		turnMult = 1,
		canThrust = true,
		dashBlocked = false,
		longfins = 0,
		currentX = 0,
		currentY = 0,
		currentZ = 0,
	}
end

--- A swim state for `speciesId` at `tier`, at rest at the origin facing −Z. Errors on an unknown
--- species or tier (a programmer mistake).
function SwimModel.new(speciesId: string, tier: number): SwimState
	local species = speciesDef(speciesId)
	local state: SwimState = {
		speciesId = speciesId,
		tier = 0,
		tierSpeed = 0,
		speedMult = species.speedMult,
		turnRate = 0,
		radiusMult = species.radiusMult,
		dashCooldown = species.dashCooldown,
		dashDurationMult = species.dashDurationMult,
		dashMult = species.dashMult,
		accelMult = species.accelMult,
		accel = 0,
		coast = 0,
		brake = 0,
		grip = 0,
		radius = 0,
		x = 0,
		y = 0,
		z = 0,
		vx = 0,
		vy = 0,
		vz = 0,
		yaw = 0,
		pitch = 0,
		lookX = 0,
		lookY = 0,
		lookZ = -1,
		airborne = false,
		airTime = 0,
		dashing = false,
		dashAge = math.huge,
		dashLength = 0,
		dashBuffer = 0,
		dashStarted = false,
		breached = false,
		splashed = false,
		mods = SwimModel.newMods(),
	}
	SwimModel.setTier(state, tier)
	SwimModel.setBodyScale(state, tierDef(tier).bodyScale)
	return state
end

--- Switches speed, turn rate and the thrust constants to `tier` at once (02 §1.8: tier-up and
--- tier-down alike). Body size is separate: see `setBodyScale`.
function SwimModel.setTier(state: SwimState, tier: number)
	local def = tierDef(tier)
	local species = speciesDef(state.speciesId)
	local tuning = BY_TIER[tier]
	state.tier = tier
	state.tierSpeed = def.swimSpeed
	state.turnRate = def.turnRate * species.turnMult
	-- 02 §1.3: all four rates are multiplied by species.accelMult (03 §1.1, Acceleration). The
	-- dash's own constant (02 §7.1, 30/s) is not.
	local accelMult = state.accelMult
	state.accel = tuning.accel * accelMult
	state.coast = tuning.coast * accelMult
	state.brake = tuning.brake * accelMult
	state.grip = tuning.grip * accelMult
end

--- Sets the collision radius from the body scale (02 §0.2; scale follows mass, Logic/TierMath).
function SwimModel.setBodyScale(state: SwimState, bodyScale: number)
	state.radius = COLLISION_RADIUS * bodyScale * state.radiusMult
end

--- Puts the creature at a pose, at rest, under water or in the air by its height. For spawns and
--- server corrections.
function SwimModel.place(
	state: SwimState,
	x: number,
	y: number,
	z: number,
	yaw: number,
	pitch: number
)
	state.x, state.y, state.z = x, y, z
	state.vx, state.vy, state.vz = 0, 0, 0
	state.yaw = wrap(yaw)
	state.pitch = if pitch > PITCH_LIMIT
		then PITCH_LIMIT
		elseif pitch < -PITCH_LIMIT then -PITCH_LIMIT
		else pitch
	local yawR, pitchR = rad(state.yaw), rad(state.pitch)
	local cp = cos(pitchR)
	state.lookX, state.lookY, state.lookZ = -sin(yawR) * cp, sin(pitchR), -cos(yawR) * cp
	state.airborne = y > 0
	state.airTime = 0
end

--- Ends a dash early (02 §7.1: stun, bump, gulp, banking, hook, Puff, Shell). The cooldown
--- still runs from the dash start.
function SwimModel.endDash(state: SwimState)
	state.dashing = false
	state.dashBuffer = 0
end

--- True when a dash press would start a dash now (02 §7.1).
function SwimModel.canDash(state: SwimState): boolean
	return not state.airborne and not state.mods.dashBlocked and state.dashAge >= state.dashCooldown
end

--- Effective turn rate right now, °/s: what a rate input is clamped to (02 §1.4, §2.1).
function SwimModel.currentTurnRate(state: SwimState): number
	local rate = state.turnRate * state.mods.turnMult
	if state.dashing then
		rate *= DASH_TURN_MULT
	end
	if state.airborne then
		rate *= AIR_TURN_MULT
	end
	return rate
end

--- Total velocity, the current included: what MovementController writes to `Move.VectorVelocity`.
function SwimModel.velocity(state: SwimState): (number, number, number)
	if state.airborne then
		return state.vx, state.vy, state.vz
	end
	local mods = state.mods
	local drift = CURRENT_MULT * state.tierSpeed
	return state.vx + mods.currentX * drift,
		state.vy + mods.currentY * drift,
		state.vz + mods.currentZ * drift
end

--- Advances the state by `dt` seconds of `input`. Allocates nothing. dt is clamped to
--- [0, MAX_DT]; NaN input fields count as 0.
function SwimModel.step(state: SwimState, input: Types.SwimInput, dt: number)
	profileBegin("SwimModel")
	if not (dt > 0) then
		dt = 0
	elseif dt > MAX_DT then
		dt = MAX_DT
	end
	state.dashStarted = false
	state.breached = false
	state.splashed = false

	local mods = state.mods
	local throttle, strafe, brake = 0, 0, false
	if mods.canThrust then
		throttle = clampInput(input.throttle, 0, 1)
		strafe = clampInput(input.strafe, -1, 1)
		brake = input.brake
	end
	local yawTarget = input.yawTarget
	if yawTarget ~= nil and yawTarget ~= yawTarget then
		yawTarget = nil -- NaN target: hold the heading
	end
	local yawRate = clampInput(input.yawRate, -math.huge, math.huge)
	local pitchTarget = clampInput(input.pitchTarget, -PITCH_LIMIT, PITCH_LIMIT)

	-- Dash (02 §7.1) with a 0.25 s buffer for a blocked press (02 §2.5). A dash starts at the
	-- beginning of the frame and goes along the facing, with or without throttle.
	if input.dash then
		state.dashBuffer = INPUT_BUFFER
	end
	if state.dashBuffer > 0 and SwimModel.canDash(state) then
		state.dashing = true
		state.dashAge = 0
		state.dashLength = DASH_DURATION
			* (state.dashDurationMult + DASH_LONGFIN_ADD * mods.longfins)
		state.dashBuffer = 0
		state.dashStarted = true
	end

	if state.dashing then
		local left = state.dashLength - state.dashAge
		if left >= dt then
			integrate(state, dt, throttle, strafe, brake, true, yawTarget, yawRate, pitchTarget)
		else
			-- The dash ends inside this frame: split the step at the end.
			integrate(state, left, throttle, strafe, brake, true, yawTarget, yawRate, pitchTarget)
			state.dashing = false
			integrate(
				state,
				dt - left,
				throttle,
				strafe,
				brake,
				false,
				yawTarget,
				yawRate,
				pitchTarget
			)
		end
		if state.dashAge + dt >= state.dashLength then
			state.dashing = false
		end
	else
		integrate(state, dt, throttle, strafe, brake, false, yawTarget, yawRate, pitchTarget)
	end

	state.dashAge += dt
	if state.dashBuffer > 0 then
		state.dashBuffer -= dt
	end
	profileEnd()
end

--- Current speed, studs/s, the current included.
function SwimModel.speed(state: SwimState): number
	local vx, vy, vz = SwimModel.velocity(state)
	return sqrt(vx * vx + vy * vy + vz * vz)
end

-- Pure rules shared with MovementValidator (09 §7.1). They take data rows, not a swim state.

--- Tiers[tier].swimSpeed, studs/s (canon 5.1).
function SwimModel.tierSpeed(tier: number): number
	return tierDef(tier).swimSpeed
end

--- Turn rate for a tier and species, °/s, before statuses (02 §1.4).
function SwimModel.turnRate(tier: number, species: Types.SpeciesDef): number
	return tierDef(tier).turnRate * species.turnMult
end

--- Top swim speed, studs/s (02 §1.2): tierSpeed × species.speedMult × `mult`, where `mult` is
--- the product of the active trait and status multipliers (1 when none).
function SwimModel.topSpeed(tier: number, species: Types.SpeciesDef, mult: number): number
	return tierDef(tier).swimSpeed * species.speedMult * mult
end

--- Forward speed target while Dashing, studs/s (02 §1.2, §7.1): topSpeed × species.dashMult.
function SwimModel.dashSpeed(tier: number, species: Types.SpeciesDef, mult: number): number
	return SwimModel.topSpeed(tier, species, mult) * species.dashMult
end

--- The dash speed multiplier (03 §1.1 Dash speed: 2.2; Sea Turtle 2.0, Squid 2.6).
function SwimModel.dashMult(species: Types.SpeciesDef): number
	return species.dashMult
end

--- Forward relaxation constant after thrust, 1/s (02 §1.3): the tier's accel × species.accelMult.
function SwimModel.accel(tier: number, species: Types.SpeciesDef): number
	tierDef(tier)
	return BY_TIER[tier].accel * species.accelMult
end

--- Dash length, s (02 §7.1): 0.35 × (species.dashDurationMult + 0.3 per Longfin).
function SwimModel.dashDuration(species: Types.SpeciesDef, longfins: number): number
	return DASH_DURATION * (species.dashDurationMult + DASH_LONGFIN_ADD * longfins)
end

--- Dash cooldown, s from the start of a dash (02 §7.1; Minnow 2.0 through Dart).
function SwimModel.dashCooldown(species: Types.SpeciesDef): number
	return species.dashCooldown
end

--- `dashFactor` once the dash window has closed (09 §7.1, dash tail): 1 + (dashMult − 1) ×
--- e^(−accel × accelMult × t), `t` the seconds since the window closed. The relaxation `step`
--- itself uses after a dash, so the validator expects exactly an honest creature's slow-down.
function SwimModel.dashTail(tier: number, species: Types.SpeciesDef, t: number): number
	if not (t > 0) then
		t = 0
	end
	return 1 + (species.dashMult - 1) * exp(-SwimModel.accel(tier, species) * t)
end

--- 09 §7.1's `dashFactor` `sinceStart` seconds after an accepted dash start (negative before it):
--- species.dashMult from 0.10 s before the start to 0.25 s after the dash ends, then the dash
--- tail; 1 before the window.
function SwimModel.dashFactor(
	tier: number,
	species: Types.SpeciesDef,
	longfins: number,
	sinceStart: number
): number
	if not (sinceStart >= -DASH_WINDOW_BEFORE) then
		return 1
	end
	local closes = SwimModel.dashDuration(species, longfins) + DASH_WINDOW_AFTER
	if sinceStart <= closes then
		return species.dashMult
	end
	return SwimModel.dashTail(tier, species, sinceStart - closes)
end

--- The server's check of an `Ability` dash (op 1; 09 §5.3, §7.1). `claimed` is the client's
--- press time and `now` the server time, both in seconds on the same clock; `lastStart` the last
--- accepted start (−math.huge for none); `ping` the round trip, s. The claim is held to between
--- `now − min(ping, 0.3)` and `now`. Returns the accepted start time, or nil when the cooldown
--- (with 0.15 s slack) has not elapsed. Alive and not stunned are the caller's checks.
function SwimModel.acceptDash(
	species: Types.SpeciesDef,
	lastStart: number,
	claimed: number,
	now: number,
	ping: number
): number?
	local lag = if ping > 0 then (if ping < PING_CAP then ping else PING_CAP) else 0
	local start = claimed
	if not (start <= now) then
		start = now -- also NaN
	elseif start < now - lag then
		start = now - lag
	end
	if start - lastStart < species.dashCooldown - DASH_COOLDOWN_SLACK then
		return nil
	end
	return start
end

--- A current's speed along the stream, studs/s (02 §1.2, 09 §7.1): 0.6 × tierSpeed, added after
--- everything else, so neither species, statuses nor a dash scale it.
function SwimModel.currentSpeed(tier: number): number
	return CURRENT_MULT * tierDef(tier).swimSpeed
end

--- Allowed speeds of 09 §7.1 for a creature whose swim speed (statuses and dash factor already
--- applied) is `vSwim`: `vForward` along its look vector and `vAllowed` in any direction.
--- `inCurrent` adds the current; `slideMult` (1.17) covers a full strafe.
function SwimModel.allowedSpeed(tier: number, vSwim: number, inCurrent: boolean): (number, number)
	local vCurrent = if inCurrent then SwimModel.currentSpeed(tier) else 0
	return vSwim + vCurrent, vSwim * SLIDE_MULT + vCurrent
end

return SwimModel
