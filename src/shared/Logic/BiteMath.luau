--!strict
-- BiteMath: the mouth of 02 §4.1 and the arithmetic of a prey bite claim (docs/09, section 8.9;
-- docs/02, sections 4.1, 4.4 and 4.7). Numbers only, so it runs in Lune. The one source of the
-- mouth: the client's bite test (BiteDetect, via RigMath.mouth) and BiteService both read it.
--
--   r      = 1.2 × bodyScale × mouthMult × (1.25 while Dashing) × firstRun     02 §4.1, 04 §4
--   nose   = centre + facing × (1.5 × bodyScale × lengthMult)                 02 §0.2: half the body
--   mouth  = nose + facing × (0.5 × r)                                       02 §4.1 mouthCentre
-- The server (09 §8.9) takes r with the dash factor always on and the widest assist:
--   tc     = clamp(claimTime, now − 0.4 s, now)                              the lag-compensation clamp
--   reach  = 2.5 × r + PreyDef.radius + PreyDef.wobble + 3.0 + 0.15 × (eaterSpeed + preySpeed)
--   accept when |mouth − prey| ≤ reach; a miss beyond 3 × reach is "far" (8.9: +2 suspicion)
--   gain   = PreyDef.mass × massMult × nurseryMult                            (02 §4.4)
-- A client claims at most max(r_c + preyRadius, 2.5 × r_c) from its own centre (02 §4.1,
-- `claimLimit`); with r_c ≤ r that is always inside the reach (09 §8.9, "Every honest claim").
-- Who may eat what (canon 5.2) is BiteRules' job, not this module's.

local BiteMath = {}

BiteMath.WINDOW = 0.4 -- s: the oldest claim time honoured (8.9, step 5)
BiteMath.BODY_LENGTH = 3.0 -- × bodyScale × lengthMult (02 §0.2)
BiteMath.MOUTH_RADIUS = 1.2 -- × bodyScale × mouthMult (02 §4.1)
BiteMath.DASH_MOUTH = 1.25 -- the mouth while Dashing (02 §4.1)
BiteMath.CENTRE_AHEAD = 0.5 -- × r: the mouth centre ahead of the nose (02 §4.1)
BiteMath.ASSIST = 2.5 -- the widest gulp assist range, × r: the touch column of 15 §4.3 (8.9)
BiteMath.BASE_TOLERANCE = 3.0 -- studs (tune)
BiteMath.MOTION_WINDOW = 0.15 -- s of relative motion (tune)
BiteMath.FAR_FACTOR = 3 -- a miss beyond this many reaches adds suspicion (8.9)

--- The claim time the server uses: the client's estimate clamped to [now − 0.4 s, now]. Also
--- whether it had to be clamped. A non-finite claim reads as `now`.
function BiteMath.claimTime(claim: number, now: number): (number, boolean)
	if claim ~= claim or claim == math.huge or claim == -math.huge then
		return now, true
	end
	local tc = math.clamp(claim, now - BiteMath.WINDOW, now)
	return tc, tc ~= claim
end

--- 02 §4.1 `mouthRadius`: 1.2 × bodyScale × species.mouthMult, × 1.25 while Dashing, × the
--- newcomer's first-run factor (04 §4, `firstRunMouth`).
function BiteMath.mouthRadius(
	bodyScale: number,
	mouthMult: number,
	dashing: boolean,
	firstRun: number
): number
	return BiteMath.MOUTH_RADIUS
		* bodyScale
		* mouthMult
		* (if dashing then BiteMath.DASH_MOUTH else 1)
		* firstRun
end

--- The server's mouth radius (09 §8.9): 02 §4.1's with the dash factor always on, since a claim
--- can arrive after a dash ended and the client's rig lags the root.
function BiteMath.serverRadius(bodyScale: number, mouthMult: number, firstRun: number): number
	return BiteMath.mouthRadius(bodyScale, mouthMult, true, firstRun)
end

--- How far ahead of the body centre the mouth centre of radius `radius` sits, in studs: half the
--- body length to the nose (02 §0.2), then half a mouth radius (02 §4.1).
function BiteMath.mouthAhead(bodyScale: number, lengthMult: number, radius: number): number
	return 0.5 * BiteMath.BODY_LENGTH * bodyScale * lengthMult + BiteMath.CENTRE_AHEAD * radius
end

--- The mouth centre (02 §4.1) of an eater at (ex, ey, ez) facing (lx, ly, lz), with body scale
--- `bodyScale`, species `lengthMult` and mouth radius `radius`. The look vector need not be a
--- unit vector; a zero one puts the mouth at the body's centre.
function BiteMath.mouth(
	ex: number,
	ey: number,
	ez: number,
	lx: number,
	ly: number,
	lz: number,
	bodyScale: number,
	lengthMult: number,
	radius: number
): (number, number, number)
	local len = math.sqrt(lx * lx + ly * ly + lz * lz)
	if len < 1e-6 then
		return ex, ey, ez
	end
	local k = BiteMath.mouthAhead(bodyScale, lengthMult, radius) / len
	return ex + lx * k, ey + ly * k, ez + lz * k
end

--- The largest mouth-centre-to-prey distance the server accepts (09 §8.9), for the server's
--- mouth radius `radius` (`serverRadius`).
function BiteMath.reach(
	radius: number,
	preyRadius: number,
	preyWobble: number,
	eaterSpeed: number,
	preySpeed: number
): number
	return BiteMath.ASSIST * radius
		+ preyRadius
		+ preyWobble
		+ BiteMath.BASE_TOLERANCE
		+ BiteMath.MOTION_WINDOW * (math.abs(eaterSpeed) + math.abs(preySpeed))
end

--- The furthest from its own mouth centre a client may claim a prey (02 §4.1, "What a client may
--- claim"): `range × r` with the assist (`range` 0 without), else `r + preyRadius`.
function BiteMath.claimLimit(radius: number, preyRadius: number, range: number): number
	return math.max(radius + preyRadius, range * radius)
end

--- The distance from the mouth to the prey, and whether it is within `reach`.
function BiteMath.within(
	mx: number,
	my: number,
	mz: number,
	px: number,
	py: number,
	pz: number,
	reach: number
): (boolean, number)
	local dx, dy, dz = px - mx, py - my, pz - mz
	local d = math.sqrt(dx * dx + dy * dy + dz * dz)
	return d <= reach, d
end

--- True when a rejected claim missed by more than three reaches (8.9: +2 suspicion).
function BiteMath.isFar(distance: number, reach: number): boolean
	return distance > BiteMath.FAR_FACTOR * reach
end

--- The newcomer's first-run mouth factor (04 §4, via 09 §8.9): ×1.6 in run 1, ×1.3 in run 2,
--- else 1. `run` counts the account's runs from 1.
function BiteMath.firstRunMouth(run: number): number
	if run == 1 then
		return 1.6
	elseif run == 2 then
		return 1.3
	end
	return 1
end

--- The share of a prey's mass given for prey eaten inside the Nursery (02 §4.4): all of it to a
--- tier 1 creature, half to tier 2, none from tier 3.
function BiteMath.nurseryMult(eaterTier: number): number
	if eaterTier <= 1 then
		return 1
	elseif eaterTier == 2 then
		return 0.5
	end
	return 0
end

--- Mass gained for prey of mass `preyMass` (02 §4.4): × the trait multiplier (Spots, Bonefed)
--- × the Nursery share. Never negative.
function BiteMath.gain(preyMass: number, massMult: number, nurseryMult: number): number
	return math.max(0, preyMass * massMult * nurseryMult)
end

return table.freeze(BiteMath)
