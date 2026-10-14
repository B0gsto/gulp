--!strict
-- GENERATED, do not edit. Change the source table in the bible, then run
-- `lune run tools/gen/content` (docs/09, section 3.2).
-- Source: docs/03-content-catalog.md data:RevivePoints; docs/01-game-canon.md data:Zones.
-- Build: full.
local Types = require("../../Types")

local RevivePoints: { Types.RevivePointDef } = {
	{ id = "rp_01", wire = 1, zone = "reef", x = -60, z = 0, depth = 30 },
	{ id = "rp_02", wire = 2, zone = "reef", x = 0, z = -280, depth = 30 },
	{ id = "rp_03", wire = 3, zone = "reef", x = -100, z = 100, depth = 30 },
	{ id = "rp_04", wire = 4, zone = "reef", x = 120, z = 40, depth = 30 },
	{ id = "rp_05", wire = 5, zone = "kelp", x = -867, z = 76, depth = 100 },
	{ id = "rp_06", wire = 6, zone = "kelp", x = 0, z = -800, depth = 45 },
	{ id = "rp_07", wire = 7, zone = "kelp", x = -676, z = -390, depth = 70 },
	{ id = "rp_08", wire = 8, zone = "kelp", x = 120, z = -760, depth = 45 },
	{ id = "rp_09", wire = 9, zone = "dropoff", x = 600, z = -60, depth = 75 },
	{ id = "rp_10", wire = 10, zone = "dropoff", x = -70, z = 610, depth = 75 },
	{ id = "rp_11", wire = 11, zone = "dropoff", x = 438, z = 438, depth = 80 },
	{ id = "rp_12", wire = 12, zone = "dropoff", x = -212, z = 583, depth = 80 },
}

return table.freeze(RevivePoints)
