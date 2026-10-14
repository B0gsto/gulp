--!strict
-- GENERATED, do not edit. Change the source table in the bible, then run
-- `lune run tools/gen/content` (docs/09, section 3.2).
-- Source: docs/01-game-canon.md data:Tides.
-- Build: full.
local Types = require("../../Types")

local Tides: { Types.TideDef } = {
	{ id = "frenzy", wire = 1, scope = "MVP", spawnRateMult = 3, eventPrey = {} },
	{ id = "moon_tide", wire = 2, scope = "MVP", spawnRateMult = 1, eventPrey = { "lunar_fry" } },
	{
		id = "whale_fall",
		wire = 3,
		scope = "L",
		fallback = "moon_tide",
		spawnRateMult = 1,
		eventPrey = { "marrow" },
	},
}

return table.freeze(Tides)
