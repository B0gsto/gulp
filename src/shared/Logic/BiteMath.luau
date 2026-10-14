--!strict
-- BiteMath: the arithmetic of a prey bite claim (docs/09, section 8.9; docs/02, section 4.4).
-- Numbers only, so it runs in Lune; BiteService feeds it server-held poses and prey positions.
--
--   tc     = clamp(claimTime, now − 0.4 s, now)                    the lag-compensation clamp
--   mouth  = eaterPos + look × (1.5 × bodyScale)                    front of a 3.0 × bodyScale body
--   reach  = 0.9 × bodyScale × assist + PreyDef.radius + PreyDef.wobble + 3.0
--          + 0.15 × (eaterSpeed + preySpeed)
--   accept when |mouth − prey| ≤ reach; a miss beyond 3 × reach is "far" (8.9: +2 suspicion)
--   gain   = PreyDef.mass × massMult × nurseryMult                  (02 §4.4)
-- Who may eat what (canon 5.2) is BiteRules' job, not this module's.

local BiteMath = {}

BiteMath.WINDOW = 0.4 -- s: the oldest claim time honoured (8.9, step 5)
BiteMath.MOUTH_FORWARD = 1.5 -- × bodyScale: half a body 3.0 × bodyScale long (tune)
BiteMath.MOUTH_RADIUS = 0.9 -- × bodyScale (tune)
BiteMath.ASSIST = 2.5 -- the widest gulp assist, the touch column of 15 §4.3 (8.9)
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

--- The mouth point of an eater at (ex, ey, ez) facing (lx, ly, lz), with body scale `bodyScale`.
--- The look vector need not be a unit vector; a zero one puts the mouth at the body's centre.
function BiteMath.mouth(
	ex: number,
	ey: number,
	ez: number,
	lx: number,
	ly: number,
	lz: number,
	bodyScale: number
): (number, number, number)
	local len = math.sqrt(lx * lx + ly * ly + lz * lz)
	if len < 1e-6 then
		return ex, ey, ez
	end
	local k = BiteMath.MOUTH_FORWARD * bodyScale / len
	return ex + lx * k, ey + ly * k, ez + lz * k
end

--- The largest mouth-to-prey distance that is accepted. `assistMult` multiplies the widest gulp
--- assist (1 normally; the newcomer's first-run mouth factor, see `firstRunMouth`).
function BiteMath.reach(
	bodyScale: number,
	assistMult: number,
	preyRadius: number,
	preyWobble: number,
	eaterSpeed: number,
	preySpeed: number
): number
	return BiteMath.MOUTH_RADIUS * bodyScale * BiteMath.ASSIST * assistMult
		+ preyRadius
		+ preyWobble
		+ BiteMath.BASE_TOLERANCE
		+ BiteMath.MOTION_WINDOW * (math.abs(eaterSpeed) + math.abs(preySpeed))
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
