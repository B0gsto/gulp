--!strict
-- GENERATED, do not edit. Change the source table in the bible, then run
-- `lune run tools/gen/content` (docs/09, section 3.2).
-- Source: docs/02-mechanics.md data:PreyTargets; docs/03-content-catalog.md data:TraitPrey, data:ZoneAreas; docs/01-game-canon.md data:Zones.
-- Build: full.
local Types = require("../../Types")

local TraitPreySpawns: { Types.TraitPreySpawnDef } = {
	{ zone = "reef", prey = "glowfry", alive = 6, zoneArea = 502655 },
	{ zone = "reef", prey = "dotted_goby", alive = 10, zoneArea = 502655 },
	{ zone = "reef", prey = "zebra_darter", alive = 8, zoneArea = 502655 },
	{ zone = "reef", prey = "urchin_puff", alive = 6, zoneArea = 502655 },
	{ zone = "kelp", prey = "glowfry", alive = 4, zoneArea = 1078195 },
	{ zone = "kelp", prey = "armor_shrimp", alive = 6, zoneArea = 1078195 },
	{ zone = "kelp", prey = "ribbonfish", alive = 6, zoneArea = 1078195 },
	{ zone = "kelp", prey = "leaf_drifter", alive = 5, zoneArea = 1078195 },
	{ zone = "dropoff", prey = "inklet", alive = 5, zoneArea = 1078195 },
	{ zone = "dropoff", prey = "spark_eel", alive = 5, zoneArea = 1078195 },
	{ zone = "dropoff", prey = "vent_snail", alive = 4, zoneArea = 1078195 },
}

return table.freeze(TraitPreySpawns)
