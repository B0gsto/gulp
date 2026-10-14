--!strict
-- Tier and body scale as pure functions of mass (09 section 6.8). Relative string requires only (S11).
local Tiers = require("../Data/Tiers")

local TierMath = {}

function TierMath.tier(mass: number): number
	local t = 1
	for i, row in Tiers do
		if mass >= row.massNeeded then
			t = i
		end
	end
	return t
end

function TierMath.bodyScale(mass: number): number
	local t = TierMath.tier(mass)
	if t >= #Tiers then
		return Tiers[#Tiers].scale
	end
	local a, b = Tiers[t], Tiers[t + 1]
	return a.scale + (b.scale - a.scale) * (mass - a.massNeeded) / (b.massNeeded - a.massNeeded)
end

return TierMath
