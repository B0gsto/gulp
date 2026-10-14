--!strict
-- Canon tier table (docs/01-game-canon.md, section 5.1). Spike copy.
export type Tier = {
	name: string,
	massNeeded: number,
	scale: number,
	swimSpeed: number,
	turnRate: number,
}

local Tiers: { Tier } = {
	{ name = "Fry", massNeeded = 0, scale = 1.0, swimSpeed = 26, turnRate = 360 },
	{ name = "Nibbler", massNeeded = 10, scale = 1.3, swimSpeed = 28, turnRate = 320 },
	{ name = "Snapper", massNeeded = 30, scale = 1.7, swimSpeed = 30, turnRate = 280 },
	{ name = "Hunter", massNeeded = 80, scale = 2.3, swimSpeed = 32, turnRate = 240 },
	{ name = "Brute", massNeeded = 200, scale = 3.2, swimSpeed = 34, turnRate = 200 },
	{ name = "Titan", massNeeded = 500, scale = 4.5, swimSpeed = 36, turnRate = 170 },
	{ name = "Leviathan", massNeeded = 1200, scale = 6.5, swimSpeed = 38, turnRate = 140 },
}

return Tiers
