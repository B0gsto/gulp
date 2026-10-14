--!strict
-- TierMath: tier and body scale are pure functions of mass (docs/09, section 6.8; canon 5.1;
-- docs/02, sections 0.2, 0.3 and 5.1; docs/08, section 3.4 mass bar). Numbers only, so it runs in
-- Lune. Every number is a row of Data/Generated/Tiers (canon 5.1 data:Tiers).
--
--   tier(mass)      = the highest tier whose massNeeded ≤ mass (it falls when mass is lost)
--   bodyScale(mass) = a straight-line blend by mass between the tier's canon scale and the next
--                     tier's, for tiers 1 to 6; the tier 7 scale whatever the mass
--   swim speed and turn rate change only at a tier step (canon 5.1)
local Index = require("../Data/Index")
local Types = require("../Types")

local TierMath = {}

local tiers = Index.Tiers.list -- canon order: tier 1 first, massNeeded rising
local TOP = #tiers

TierMath.TOP = TOP -- the top tier (7, Leviathan)

--- The data row of `tier`, clamped to 1..TOP so a stray number never reads nil.
function TierMath.def(tier: number): Types.TierDef
	return tiers[math.clamp(math.floor(tier), 1, TOP)]
end

--- The highest tier whose `massNeeded` is at most `mass`. Mass below 0 (never expected) is tier 1.
function TierMath.tier(mass: number): number
	for t = TOP, 2, -1 do
		if mass >= tiers[t].massNeeded then
			return t
		end
	end
	return 1
end

--- The body scale at `mass`: smooth inside a tier, the tier 7 scale from Leviathan up. Mass below
--- 0 reads as 0, so the scale never shrinks under the Fry's.
function TierMath.bodyScale(mass: number): number
	local t = TierMath.tier(mass)
	if t >= TOP then
		return tiers[TOP].bodyScale
	end
	local here, nextTier = tiers[t], tiers[t + 1]
	local m = math.max(mass, here.massNeeded)
	local f = (m - here.massNeeded) / (nextTier.massNeeded - here.massNeeded)
	return here.bodyScale + (nextTier.bodyScale - here.bodyScale) * f
end

--- Top swim speed of `tier` in studs/s (canon 5.1), before species and trait multipliers.
function TierMath.swimSpeed(tier: number): number
	return TierMath.def(tier).swimSpeed
end

--- Turn rate of `tier` in degrees per second (canon 5.1).
function TierMath.turnRate(tier: number): number
	return TierMath.def(tier).turnRate
end

--- The mass that reaches the next tier, or nil at the top tier (02 §5.1 tier-up trigger).
function TierMath.nextThreshold(mass: number): number?
	local t = TierMath.tier(mass)
	return if t >= TOP then nil else tiers[t + 1].massNeeded
end

--- The mass bar (08 §3.4): 0 at the current tier's threshold, 1 at the next tier's; 1 at the top.
function TierMath.progress(mass: number): number
	local t = TierMath.tier(mass)
	if t >= TOP then
		return 1
	end
	local from, to = tiers[t].massNeeded, tiers[t + 1].massNeeded
	return math.clamp((mass - from) / (to - from), 0, 1)
end

--- Every tier passed going from `fromTier` to `toTier` (02 §5.1: several tiers at once give one
--- sequence, and the Codex gets every tier passed). Empty for a fall or no change.
function TierMath.tiersGained(fromTier: number, toTier: number): { number }
	local list = {}
	for t = math.max(fromTier, 0) + 1, math.min(toTier, TOP) do
		table.insert(list, t)
	end
	return list
end

return table.freeze(TierMath)
