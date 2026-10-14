--!strict
-- GENERATED, do not edit. Change the source table in the bible, then run
-- `lune run tools/gen/content` (docs/09, section 3.2).
-- Source: docs/01-game-canon.md data:Tiers; docs/05-economy-and-monetization.md data:CoveIncome.
-- Build: full.
local Types = require("../../Types")

local Tiers: { Types.TierDef } = {
	{ tier = 1, name = "Fry", massNeeded = 0, bodyScale = 1, swimSpeed = 26, turnRate = 360 },
	{
		tier = 2,
		name = "Nibbler",
		massNeeded = 10,
		bodyScale = 1.3,
		swimSpeed = 28,
		turnRate = 320,
		coveIncome = 6,
	},
	{
		tier = 3,
		name = "Snapper",
		massNeeded = 30,
		bodyScale = 1.7,
		swimSpeed = 30,
		turnRate = 280,
		coveIncome = 10,
	},
	{
		tier = 4,
		name = "Hunter",
		massNeeded = 80,
		bodyScale = 2.3,
		swimSpeed = 32,
		turnRate = 240,
		coveIncome = 18,
	},
	{
		tier = 5,
		name = "Brute",
		massNeeded = 200,
		bodyScale = 3.2,
		swimSpeed = 34,
		turnRate = 200,
		coveIncome = 30,
	},
	{
		tier = 6,
		name = "Titan",
		massNeeded = 500,
		bodyScale = 4.5,
		swimSpeed = 36,
		turnRate = 170,
		coveIncome = 50,
	},
	{
		tier = 7,
		name = "Leviathan",
		massNeeded = 1200,
		bodyScale = 6.5,
		swimSpeed = 38,
		turnRate = 140,
		coveIncome = 80,
	},
}

return table.freeze(Tiers)
