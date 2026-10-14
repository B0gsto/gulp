--!strict
-- CameraMath: the pure half of the follow camera (docs/02, section 3; docs/15, section 3.2 and
-- section 10 item 14; docs/09, sections 6.7 and spike finding F1). Numbers only, so it runs in
-- Lune. The engine half is `client/Controllers/CameraController`.
--
-- Angles are in degrees unless a name ends in `Rad`. Distances in studs, time in seconds.

local CameraMath = {}

-- 02 §3.1: follow distance and height.
CameraMath.DISTANCE_BASE = 4
CameraMath.DISTANCE_PER_SCALE = 10
CameraMath.HEIGHT_RATIO = 0.25
CameraMath.TIGHT_HEIGHT_RATIO = 0.05 -- 02 §3.5 tight-space mode
CameraMath.BODY_LENGTH_PER_SCALE = 3.0 -- 02 §0.2
CameraMath.COLLISION_RADIUS_PER_SCALE = 0.9 -- 02 §0.2
CameraMath.LOOK_AHEAD_LENGTHS = 0.5 -- lookAt = centre + facing × (0.5 × body length)

-- 02 §3.1 and 15 §3.2: field of view (vertical, as `Camera.FieldOfView` is, PF35).
CameraMath.BASE_VFOV = 70
CameraMath.MIN_HFOV = 95
CameraMath.MAX_HFOV = 117
CameraMath.MAX_VFOV = 90
CameraMath.SPEED_FOV = 6 -- + 6° × forward speed / top speed, capped
CameraMath.DASH_FOV = 10 -- 02 §3.4
CameraMath.DASH_FOV_IN = 0.08
CameraMath.DASH_FOV_OUT = 0.35
CameraMath.TIGHT_FOV = 5 -- 02 §3.5

-- 02 §3.2: exponential smoothing time constants.
CameraMath.TAU_POSITION = 0.12
CameraMath.TAU_YAW = 0.18
CameraMath.TAU_PITCH = 0.25
CameraMath.PITCH_FOLLOW = 0.6 -- camera pitch = 0.6 × creature pitch
CameraMath.TAU_DISTANCE = 0.25
CameraMath.TAU_OCCLUSION_OUT = 0.40 -- 02 §3.5
CameraMath.TAU_SURFACE = 0.30 -- 02 §3.5, Airborne

-- 09 §6.7: the own creature's rig spring.
CameraMath.TAU_OWN_RIG = 0.03

-- 02 §3.3: tier-up pull-back and tier-down ease.
CameraMath.PULL_START = 0.10
CameraMath.PULL_PEAK_AT = 0.70
CameraMath.PULL_END = 1.20
CameraMath.PULL_PEAK = 1.15
CameraMath.TIER_DOWN_SECONDS = 0.4

-- 02 §3.4: shakes (amplitude in studs, seconds).
CameraMath.SHAKE_BITE = 0.15
CameraMath.SHAKE_BITE_SECONDS = 0.10
CameraMath.SHAKE_TIER_UP = 0.5
CameraMath.SHAKE_TIER_UP_SECONDS = 0.25

-- 02 §3.5: obstacles.
CameraMath.OCCLUSION_RADIUS = 1.0
CameraMath.OCCLUSION_GAP = 0.5
CameraMath.MIN_DISTANCE_RADII = 1.2
CameraMath.MIN_DISTANCE_PLUS = 2
CameraMath.TIGHT_ENTER_RATIO = 0.6
CameraMath.TIGHT_ENTER_SECONDS = 0.3
CameraMath.TIGHT_EXIT_RATIO = 0.85
CameraMath.TIGHT_EXIT_SECONDS = 0.5
CameraMath.FADE_RATIO = 0.6 -- own creature fades to 40% opacity under this (CreatureController)
CameraMath.SURFACE_Y = 0

--------------------------------------------------------------------------------------------------
-- Distance and framing (02 §3.1)

--- Follow distance behind the creature: `4 + 10 × bodyScale`.
function CameraMath.distance(bodyScale: number): number
	return CameraMath.DISTANCE_BASE + CameraMath.DISTANCE_PER_SCALE * bodyScale
end

--- Height above the creature centre: `0.25 × distance`, or `0.05 × distance` in tight-space mode.
function CameraMath.height(distance: number, tight: boolean): number
	return (if tight then CameraMath.TIGHT_HEIGHT_RATIO else CameraMath.HEIGHT_RATIO) * distance
end

--- How far ahead of the centre the camera looks: half the body length (`3.0 × bodyScale`).
function CameraMath.lookAhead(bodyScale: number): number
	return CameraMath.LOOK_AHEAD_LENGTHS * CameraMath.BODY_LENGTH_PER_SCALE * bodyScale
end

--- The closest the camera may come: `1.2 × collision radius + 2` (02 §3.5), where the collision
--- radius is `0.9 × bodyScale × species.radiusMult` (02 §0.2).
function CameraMath.minDistance(bodyScale: number, radiusMult: number): number
	local radius = CameraMath.COLLISION_RADIUS_PER_SCALE * bodyScale * radiusMult
	return CameraMath.MIN_DISTANCE_RADII * radius + CameraMath.MIN_DISTANCE_PLUS
end

--------------------------------------------------------------------------------------------------
-- Field of view (02 §3.1, 15 §3.2)

--- Horizontal field of view for a vertical one on a screen of `aspect` = width / height.
function CameraMath.hFov(vFov: number, aspect: number): number
	return 2 * math.deg(math.atan(math.tan(math.rad(vFov / 2)) * aspect))
end

--- The base vertical field of view for an aspect: 70°, raised (cap 90°) or lowered so the
--- horizontal one stays between 95° and 117°. It replaces `baseFOV`; offsets are added after it.
function CameraMath.baseVFov(aspect: number): number
	local v = CameraMath.BASE_VFOV
	if aspect <= 0 then
		return v
	end
	local h = CameraMath.hFov(v, aspect)
	if h < CameraMath.MIN_HFOV then
		v = math.min(
			CameraMath.MAX_VFOV,
			2 * math.deg(math.atan(math.tan(math.rad(CameraMath.MIN_HFOV / 2)) / aspect))
		)
	elseif h > CameraMath.MAX_HFOV then
		v = 2 * math.deg(math.atan(math.tan(math.rad(CameraMath.MAX_HFOV / 2)) / aspect))
	end
	return v
end

--- The speed offset: `+6° × forward speed / top speed`, between 0 and 6°.
function CameraMath.speedFov(forwardSpeed: number, topSpeed: number): number
	if topSpeed <= 0 then
		return 0
	end
	return CameraMath.SPEED_FOV * math.clamp(forwardSpeed / topSpeed, 0, 1)
end

--- The dash offset `elapsed` seconds after a dash began, for a dash lasting `duration`: +10°
--- over 0.08 s, held, back over 0.35 s (02 §3.4). Linear ramps.
function CameraMath.dashFov(elapsed: number, duration: number): number
	if elapsed < 0 then
		return 0
	elseif elapsed < CameraMath.DASH_FOV_IN then
		return CameraMath.DASH_FOV * elapsed / CameraMath.DASH_FOV_IN
	elseif elapsed < duration then
		return CameraMath.DASH_FOV
	end
	local out = elapsed - math.max(duration, CameraMath.DASH_FOV_IN)
	return CameraMath.DASH_FOV * math.max(0, 1 - out / CameraMath.DASH_FOV_OUT)
end

--------------------------------------------------------------------------------------------------
-- Smoothing (02 §3.2, 09 §6.7)

--- One exponential step: `value += (target − value) × (1 − e^(−dt / τ))`. τ = 0 snaps.
function CameraMath.smooth(value: number, target: number, dt: number, tau: number): number
	if tau <= 0 then
		return target
	end
	return value + (target - value) * (1 - math.exp(-dt / tau))
end

--- The signed shortest difference `to − from` between two angles in degrees, in (−180, 180].
function CameraMath.angleDelta(from: number, to: number): number
	local d = (to - from) % 360
	if d > 180 then
		d -= 360
	end
	return d
end

--- `smooth` for an angle in degrees, taking the short way round. The result is in [0, 360).
function CameraMath.smoothAngle(value: number, target: number, dt: number, tau: number): number
	local d = CameraMath.angleDelta(value, target)
	return (CameraMath.smooth(value, value + d, dt, tau)) % 360
end

--- One step of a critically damped spring on one axis (ω = 1/τ), integrated exactly for a target
--- that holds still over `dt`. A target moving at speed v is trailed by 2τv (spike F1), which is
--- why `leadTarget` adds that back. Returns the new position and velocity.
function CameraMath.spring(
	x: number,
	v: number,
	target: number,
	dt: number,
	tau: number
): (number, number)
	if tau <= 0 then
		return target, 0
	end
	local w = 1 / tau
	local e = x - target
	local c = v + w * e
	local decay = math.exp(-w * dt)
	return target + (e + c * dt) * decay, (v - w * c * dt) * decay
end

--- The target a lagging follower should chase so it trails a body at velocity `velocity` by
--- nothing at steady speed: `target + velocity × lag` (spike F1: lag = 2τ for the spring).
function CameraMath.leadTarget(target: number, velocity: number, lag: number): number
	return target + velocity * lag
end

--------------------------------------------------------------------------------------------------
-- Tier changes (02 §3.3)

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
CameraMath.ease = smoothstep

--- The tier-up distance factor `t` seconds after the tier-up sequence's T+0: 1 until T+0.10,
--- eases to 1.15 by T+0.70, settles back to 1 by T+1.20.
function CameraMath.pullBack(t: number): number
	if t <= CameraMath.PULL_START or t >= CameraMath.PULL_END then
		return 1
	elseif t <= CameraMath.PULL_PEAK_AT then
		local f = (t - CameraMath.PULL_START) / (CameraMath.PULL_PEAK_AT - CameraMath.PULL_START)
		return 1 + (CameraMath.PULL_PEAK - 1) * smoothstep(f)
	end
	local f = (t - CameraMath.PULL_PEAK_AT) / (CameraMath.PULL_END - CameraMath.PULL_PEAK_AT)
	return CameraMath.PULL_PEAK + (1 - CameraMath.PULL_PEAK) * smoothstep(f)
end

--- The distance `t` seconds into a tier-down: straight from `from` to `to` over 0.4 s.
function CameraMath.tierDown(from: number, to: number, t: number): number
	return from + (to - from) * smoothstep(t / CameraMath.TIER_DOWN_SECONDS)
end

--------------------------------------------------------------------------------------------------
-- Obstacles (02 §3.5)

--- The clear distance after a cast from `lookAt` towards the desired camera position hit at
--- `hitDistance` (nil: no hit): 0.5 studs in front of the hit, never under the minimum distance,
--- never past the desired one.
function CameraMath.clearDistance(hitDistance: number?, desired: number, minimum: number): number
	if hitDistance == nil then
		return desired
	end
	return math.clamp(hitDistance - CameraMath.OCCLUSION_GAP, math.min(minimum, desired), desired)
end

--- One step of the occluded distance: moving in is instant, moving back out uses τ = 0.40 s.
function CameraMath.stepOcclusion(current: number, clear: number, dt: number): number
	if clear <= current then
		return clear
	end
	return CameraMath.smooth(current, clear, dt, CameraMath.TAU_OCCLUSION_OUT)
end

export type TightState = { tight: boolean, timer: number }

function CameraMath.newTight(): TightState
	return { tight = false, timer = 0 }
end

--- Tight-space mode with hysteresis: enter when the clear distance is under 60% of the desired one
--- for 0.3 s, leave when it is above 85% for 0.5 s. Mutates and returns `state.tight`.
function CameraMath.stepTight(
	state: TightState,
	clear: number,
	desired: number,
	dt: number
): boolean
	local ratio = if desired > 0 then clear / desired else 1
	local leaving = state.tight and ratio > CameraMath.TIGHT_EXIT_RATIO
	local entering = not state.tight and ratio < CameraMath.TIGHT_ENTER_RATIO
	if leaving or entering then
		state.timer += dt
		local need = if state.tight
			then CameraMath.TIGHT_EXIT_SECONDS
			else CameraMath.TIGHT_ENTER_SECONDS
		if state.timer >= need then
			state.tight = not state.tight
			state.timer = 0
		end
	else
		state.timer = 0
	end
	return state.tight
end

--------------------------------------------------------------------------------------------------
-- Shake (02 §3.4)

--- The shake amplitude `t` seconds into a shake of `amount` studs lasting `seconds`: linear decay.
function CameraMath.shakeAmplitude(amount: number, seconds: number, t: number): number
	if t < 0 or t >= seconds or seconds <= 0 then
		return 0
	end
	return amount * (1 - t / seconds)
end

return table.freeze(CameraMath)
