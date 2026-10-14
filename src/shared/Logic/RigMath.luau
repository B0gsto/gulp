--!strict
-- RigMath: the pure numbers behind every creature rig a client draws (task S3-C6; docs/09,
-- sections 6.7 and 6.8; docs/06, sections 7.3 and 8.4; docs/07, section 2.1 clip lengths).
-- Numbers only, so it runs in Lune. State tables are made once per rig and mutated in place, so
-- the per-frame steps allocate nothing (09 §4.7).
--
--   lead        = target + clamp(velocity, 1.2 × dash speed) × 2τ          09 §6.7, spike F1
--   rig.pos     = critically damped spring toward lead  (τ 0.03 s own, 0.08 s others)
--   rig.heading = spring toward the look direction       (τ 0.10 s), renormalised
--   bank        = roll into the turn, from the heading's yaw rate (tune)
--   scale       = eased to TierMath.bodyScale(Mass) over 0.15 s                09 §6.8
--   sway        = RIG_Fish's reference swim wave (rigs.py `_swim_body`) when no clip is uploaded
local BiteMath = require("./BiteMath")
local CameraMath = require("./CameraMath")

local RigMath = {}

RigMath.TAU_OWN = CameraMath.TAU_OWN_RIG -- 0.03 s, 09 §6.7 (tune)
RigMath.TAU_OTHER = 0.08 -- 09 §6.7 (tune)
RigMath.TAU_HEADING = 0.10 -- 09 §6.7 (tune)
RigMath.TAU_BANK = 0.10 -- (tune)
RigMath.LEAD_CLAMP = 1.2 -- velocity clamp, × the creature's dash speed (09 §6.7, tune)
RigMath.HEADING_MIN_SPEED = 2 -- studs/s: below it the rig faces the root's look vector (09 §6.7)
RigMath.BANK_GAIN = 0.22 -- radians of roll per rad/s of yaw rate (tune)
RigMath.BANK_MAX = math.rad(35) -- (tune)
RigMath.SNAP_DISTANCE = 64 -- a jump this far (respawn, teleport) re-primes the spring (tune)
RigMath.SCALE_TIME = 0.15 -- 09 §6.8, 02 §5: the eased scale change, seconds

RigMath.BODY_LENGTH = BiteMath.BODY_LENGTH -- 02 §0.2: body length = 3.0 × bodyScale
RigMath.MOUTH_RADIUS = BiteMath.MOUTH_RADIUS -- 02 §4.1 (the formula lives in BiteMath)
RigMath.DASH_MOUTH = BiteMath.DASH_MOUTH

--------------------------------------------------------------------------------------------------
-- Follow state (position, heading, bank)

export type Follow = {
	primed: boolean,
	x: number,
	y: number,
	z: number,
	vx: number,
	vy: number,
	vz: number,
	-- unit heading (read this), the raw spring state behind it and the spring's velocity
	hx: number,
	hy: number,
	hz: number,
	rx: number,
	ry: number,
	rz: number,
	hvx: number,
	hvy: number,
	hvz: number,
	yaw: number,
	yawRate: number,
	bank: number,
}

function RigMath.newFollow(): Follow
	return {
		primed = false,
		x = 0,
		y = 0,
		z = 0,
		vx = 0,
		vy = 0,
		vz = 0,
		hx = 0,
		hy = 0,
		hz = -1,
		rx = 0,
		ry = 0,
		rz = -1,
		hvx = 0,
		hvy = 0,
		hvz = 0,
		yaw = 0,
		yawRate = 0,
		bank = 0,
	}
end

-- Roblox yaw of a look vector: look = (−sin yaw, ·, −cos yaw).
local function yawOf(x: number, z: number): number
	return math.atan2(-x, -z)
end

local function wrap(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

--- Places the rig on the target with no motion: first frame, respawn or teleport.
function RigMath.reset(
	f: Follow,
	px: number,
	py: number,
	pz: number,
	lx: number,
	ly: number,
	lz: number
)
	f.primed = true
	f.x, f.y, f.z = px, py, pz
	f.vx, f.vy, f.vz = 0, 0, 0
	local m = math.sqrt(lx * lx + ly * ly + lz * lz)
	if m > 1e-6 then
		f.hx, f.hy, f.hz = lx / m, ly / m, lz / m
	end
	f.rx, f.ry, f.rz = f.hx, f.hy, f.hz
	f.hvx, f.hvy, f.hvz = 0, 0, 0
	f.yaw, f.yawRate, f.bank = yawOf(f.hx, f.hz), 0, 0
end

--- `velocity` scaled down to at most `maxSpeed` (a replication overshoot must not throw the
--- lead point, 09 §6.7).
function RigMath.clampSpeed(
	vx: number,
	vy: number,
	vz: number,
	maxSpeed: number
): (number, number, number)
	local s2 = vx * vx + vy * vy + vz * vz
	if s2 > maxSpeed * maxSpeed and s2 > 0 then
		local k = maxSpeed / math.sqrt(s2)
		return vx * k, vy * k, vz * k
	end
	return vx, vy, vz
end

--- One frame of `rig.pos`: a critically damped spring toward `target + clamp(velocity) × 2τ`.
--- Steady speed leaves no trail (spike F1). Re-primes on the first frame or a jump past
--- SNAP_DISTANCE. Returns true when it snapped.
function RigMath.stepPosition(
	f: Follow,
	tx: number,
	ty: number,
	tz: number,
	vx: number,
	vy: number,
	vz: number,
	maxSpeed: number,
	dt: number,
	tau: number
): boolean
	local ex, ey, ez = tx - f.x, ty - f.y, tz - f.z
	if
		not f.primed
		or ex * ex + ey * ey + ez * ez > RigMath.SNAP_DISTANCE * RigMath.SNAP_DISTANCE
	then
		f.primed = true
		f.x, f.y, f.z = tx, ty, tz
		f.vx, f.vy, f.vz = vx, vy, vz
		return true
	end
	local cx, cy, cz = RigMath.clampSpeed(vx, vy, vz, maxSpeed)
	-- 2τ cancels the continuous spring's trail. The exact step holds the target still over `dt`
	-- while a target sampled at the frame's end has already moved v·dt, which leads by v·dt/2;
	-- taking that half frame off keeps the rig on the root at any frame rate.
	local lag = math.max(0, 2 * tau - 0.5 * dt)
	f.x, f.vx = CameraMath.spring(f.x, f.vx, tx + cx * lag, dt, tau)
	f.y, f.vy = CameraMath.spring(f.y, f.vy, ty + cy * lag, dt, tau)
	f.z, f.vz = CameraMath.spring(f.z, f.vz, tz + cz * lag, dt, tau)
	return false
end

--- The direction the rig should face: the velocity above HEADING_MIN_SPEED, else the root's look
--- vector `(fx, fy, fz)` (09 §6.7). Unit length.
function RigMath.lookDirection(
	vx: number,
	vy: number,
	vz: number,
	fx: number,
	fy: number,
	fz: number
): (number, number, number)
	local s = math.sqrt(vx * vx + vy * vy + vz * vz)
	if s > RigMath.HEADING_MIN_SPEED then
		return vx / s, vy / s, vz / s
	end
	local m = math.sqrt(fx * fx + fy * fy + fz * fz)
	if m < 1e-6 then
		return 0, 0, -1
	end
	return fx / m, fy / m, fz / m
end

--- One frame of `rig.heading` toward the unit look direction `(lx, ly, lz)`, plus the yaw rate
--- and the bank it gives: the rig rolls into a turn (positive yaw rate, turning left, rolls left),
--- clamped to BANK_MAX and smoothed.
function RigMath.stepHeading(f: Follow, lx: number, ly: number, lz: number, dt: number)
	local tau = RigMath.TAU_HEADING
	-- The spring runs on a raw vector and the heading is that vector normalised, so a turn
	-- progresses at the spring's pace (renormalising the state itself would stall a reversal).
	f.rx, f.hvx = CameraMath.spring(f.rx, f.hvx, lx, dt, tau)
	f.ry, f.hvy = CameraMath.spring(f.ry, f.hvy, ly, dt, tau)
	f.rz, f.hvz = CameraMath.spring(f.rz, f.hvz, lz, dt, tau)
	local m = math.sqrt(f.rx * f.rx + f.ry * f.ry + f.rz * f.rz)
	if m > 1e-4 then -- at the zero crossing of a reversal, keep last frame's heading
		f.hx, f.hy, f.hz = f.rx / m, f.ry / m, f.rz / m
	end
	local yaw = yawOf(f.hx, f.hz)
	-- A near-vertical heading has no meaningful yaw: hold the rate at zero there.
	local flat = f.hx * f.hx + f.hz * f.hz
	f.yawRate = if dt > 0 and flat > 0.01 then wrap(yaw - f.yaw) / dt else 0
	f.yaw = yaw
	local target = math.clamp(f.yawRate * RigMath.BANK_GAIN, -RigMath.BANK_MAX, RigMath.BANK_MAX)
	f.bank = CameraMath.smooth(f.bank, target, dt, RigMath.TAU_BANK)
end

--------------------------------------------------------------------------------------------------
-- Scale easing (09 §6.8)

export type ScaleEase = { from: number, to: number, t: number, value: number }

function RigMath.newScale(scale: number): ScaleEase
	return { from = scale, to = scale, t = RigMath.SCALE_TIME, value = scale }
end

--- Starts an ease from the current value toward `target`. A target equal to the running one
--- changes nothing, so repeated attribute writes do not restart the ease.
function RigMath.retargetScale(e: ScaleEase, target: number)
	if target == e.to then
		return
	end
	e.from, e.to, e.t = e.value, target, 0
end

--- Advances the ease by `dt`; returns the new value and whether it moved this frame. Smoothstep
--- over SCALE_TIME: soft at both ends, so a stream of bites reads as steady growth.
function RigMath.stepScale(e: ScaleEase, dt: number): (number, boolean)
	if e.t >= RigMath.SCALE_TIME then
		return e.value, false
	end
	e.t = math.min(e.t + dt, RigMath.SCALE_TIME)
	local u = e.t / RigMath.SCALE_TIME
	u = u * u * (3 - 2 * u)
	e.value = e.from + (e.to - e.from) * u
	return e.value, true
end

--------------------------------------------------------------------------------------------------
-- Clips and the code sway (docs/07 §2.1 rows A_Fish_*, 30 fps; rigs.py fish_swim_pose)

export type Clip = "Swim" | "SwimFast" | "Idle" | "Dash" | "Bite" | "TierUp"

RigMath.FPS = 30
--- Clip lengths in seconds at 07 §2.1's frame counts (Bite: the middle of 7 to 9 frames).
RigMath.CLIP_SECONDS = table.freeze({
	Swim = 16 / 30,
	SwimFast = 8 / 30,
	Idle = 60 / 30,
	Dash = 14 / 30,
	Bite = 8 / 30,
	TierUp = 18 / 30,
} :: { [string]: number })
RigMath.CLIPS = table.freeze({ "Swim", "SwimFast", "Idle", "Dash", "Bite", "TierUp" } :: { Clip })

--- The code tier-up pop when `A_Fish_TierUp` is not uploaded (02 §1.8): a 0.6 s pulse on the
--- mesh only that overshoots to 112% of the current scale and settles back on it.
RigMath.POP_SECONDS = 0.6
RigMath.POP_PEAK = 1.12
local POP_RISE = 0.6 -- the exponent that puts the peak near 30% of the pulse: a quick rise (tune)

--- The scale multiplier `t` seconds into the tier-up pop: 1 before and after, POP_PEAK at its top.
function RigMath.popMult(t: number): number
	if t <= 0 or t >= RigMath.POP_SECONDS then
		return 1
	end
	local u = (t / RigMath.POP_SECONDS) ^ POP_RISE
	return 1 + (RigMath.POP_PEAK - 1) * math.sin(math.pi * u)
end
--- Wave amplitude per loop: SwimFast is the dash sweep (rigs.py amp 1.3); Idle is a slow hover.
RigMath.SWAY_AMP = table.freeze({ Swim = 1.0, SwimFast = 1.3, Idle = 0.3 } :: { [string]: number })
RigMath.FAST_RATIO = 1.15 -- speed over topSpeed × this reads as a dash (tune)
RigMath.TAU_SWAY = 0.15 -- amplitude and period blend between loops (tune)

--- The loop a creature at `speed` plays: Idle under HEADING_MIN_SPEED, SwimFast above
--- FAST_RATIO × `topSpeed`, else Swim.
function RigMath.loopFor(speed: number, topSpeed: number): Clip
	if speed < RigMath.HEADING_MIN_SPEED then
		return "Idle"
	elseif speed > topSpeed * RigMath.FAST_RATIO then
		return "SwimFast"
	end
	return "Swim"
end

--- One bone of the reference swim wave (rigs.py `_swim_body`): Blender degrees about up (yaw,
--- Roblox Y) and about the body axis (roll, Roblox Z), each with its phase lag in radians.
export type SwayBone = { name: string, yaw: number, yawLag: number, roll: number, rollLag: number }

RigMath.SWAY = table.freeze({
	table.freeze({ name = "Spine2", yaw = 1.3, yawLag = -0.6, roll = 0, rollLag = 0 }),
	table.freeze({ name = "Spine1", yaw = -0.7, yawLag = -0.6, roll = 0, rollLag = 0 }),
	table.freeze({ name = "Spine3", yaw = 10, yawLag = 0.9, roll = 0, rollLag = 0 }),
	table.freeze({ name = "Spine4", yaw = 17, yawLag = 1.8, roll = 0, rollLag = 0 }),
	table.freeze({ name = "TailFin", yaw = 25, yawLag = 2.7, roll = 7, rollLag = 3.5 }),
	table.freeze({ name = "Dorsal", yaw = 0, yawLag = 0, roll = 6, rollLag = 1.7 }),
} :: { SwayBone })

--- The bone's (yaw, roll) in radians at loop phase 0..1 and amplitude `amp`.
function RigMath.sway(bone: SwayBone, phase: number, amp: number): (number, number)
	local a = 2 * math.pi * phase
	return math.rad(amp * bone.yaw * math.sin(a - bone.yawLag)),
		math.rad(amp * bone.roll * math.sin(a - bone.rollLag))
end

--- Pectoral beat (rigs.py: three beats a loop, a skewed sine, ±14°) in radians at phase 0..1.
function RigMath.pecFlap(phase: number, amp: number): number
	local s = 3 * 2 * math.pi * phase
	return math.rad(amp * 14 * math.sin(s + 0.35 * math.sin(s)))
end

--------------------------------------------------------------------------------------------------
-- Mouth (02 §4.1)

--- Mouth radius and how far ahead of the body centre the mouth centre sits, in studs: 02 §4.1
--- as BiteMath computes it (one source for the client's bite test and the server's check).
--- nose = centre + facing × half the body length; mouthCentre = nose + facing × 0.5 × radius.
--- `lengthMult` and `firstRun` (04 §4) default to 1.
function RigMath.mouth(
	bodyScale: number,
	mouthMult: number,
	dashing: boolean,
	lengthMult: number?,
	firstRun: number?
): (number, number)
	local radius = BiteMath.mouthRadius(bodyScale, mouthMult, dashing, firstRun or 1)
	return radius, BiteMath.mouthAhead(bodyScale, lengthMult or 1, radius)
end

return table.freeze(RigMath)
