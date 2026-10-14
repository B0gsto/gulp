--!strict
-- TierMath: tier and body scale are pure functions of mass (docs/09, section 6.8; canon 5.1;
-- docs/02, sections 0.2 and 0.3). Numbers only, so it runs in Lune. Task B07 extends this module.
--
--   tier(mass)      = the highest tier whose massNeeded ≤ mass (it falls when mass is lost)
--   bodyScale(mass) = a straight-line blend by mass between the tier's canon scale and the next
--                     tier's, for tiers 1 to 6; the tier 7 scale whatever the mass
local Index = require("../Data/Index")

local TierMath = {}

local tiers = Index.Tiers.list -- canon order: tier 1 first, massNeeded rising
local TOP = #tiers

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

return table.freeze(TierMath)
