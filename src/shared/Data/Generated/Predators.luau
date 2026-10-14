--!strict
-- GENERATED, do not edit. Change the source table in the bible, then run
-- `lune run tools/gen/content` (docs/09, section 3.2).
-- Source: docs/03-content-catalog.md data:Predators.
-- Build: full.
local Types = require("../../Types")

local Predators: { Types.PredatorDef } = {
	{
		id = "gull",
		wire = 1,
		scope = "MVP",
		tier = 3,
		eatsMaxTier = 2,
		speed = 90,
		senseRadius = 6,
		strikeRadius = 5,
		telegraph = 1.5,
		giveUpAfter = 0,
		rest = 8,
	},
	{
		id = "moray",
		wire = 2,
		scope = "MVP",
		tier = 4,
		eatsMaxTier = 3,
		speed = 70,
		senseRadius = 14,
		strikeRadius = 2.76,
		telegraph = 0.6,
		giveUpAfter = 1.2,
		rest = 6,
	},
	{
		id = "barracuda",
		wire = 3,
		scope = "MVP",
		tier = 4,
		eatsMaxTier = 3,
		speed = 36,
		senseRadius = 45,
		strikeRadius = 2.76,
		telegraph = 0.8,
		giveUpAfter = 6,
		rest = 5,
		eatenMass = 25,
	},
	{
		id = "grouper",
		wire = 4,
		scope = "L",
		tier = 5,
		eatsMaxTier = 4,
		speed = 12,
		senseRadius = 32,
		strikeRadius = 3.84,
		telegraph = 1,
		giveUpAfter = 2.5,
		rest = 6,
		eatenMass = 60,
	},
	{
		id = "old_scar",
		wire = 5,
		scope = "MVP",
		tier = 7,
		eatsMaxTier = 6,
		speed = 40,
		senseRadius = 90,
		strikeRadius = 7.8,
		telegraph = 1,
		giveUpAfter = 8,
		rest = 10,
	},
}

return table.freeze(Predators)
