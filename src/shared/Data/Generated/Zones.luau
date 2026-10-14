--!strict
-- GENERATED, do not edit. Change the source table in the bible, then run
-- `lune run tools/gen/content` (docs/09, section 3.2).
-- Source: docs/01-game-canon.md data:Zones.
-- Build: full.
local Types = require("../../Types")

local Zones: { Types.ZoneDef } = {
	{
		id = "nursery",
		wire = 1,
		scope = "MVP",
		preyTierMin = 0,
		preyTierMax = 1,
		safe = true,
		lightingPreset = "Nursery Lagoon",
	},
	{
		id = "reef",
		wire = 2,
		scope = "MVP",
		preyTierMin = 0,
		preyTierMax = 3,
		safe = false,
		lightingPreset = "Sunlit Reef",
	},
	{
		id = "kelp",
		wire = 3,
		scope = "MVP",
		preyTierMin = 1,
		preyTierMax = 4,
		safe = false,
		lightingPreset = "Kelp Forest",
	},
	{
		id = "dropoff",
		wire = 4,
		scope = "MVP",
		preyTierMin = 3,
		preyTierMax = 6,
		safe = false,
		lightingPreset = "Drop-off, upper",
	},
	{
		id = "trench",
		wire = 5,
		scope = "P2",
		preyTierMin = 5,
		preyTierMax = 6,
		safe = false,
		lightingPreset = "The Trench",
	},
	{
		id = "cove",
		wire = 6,
		scope = "MVP",
		preyTierMin = 0,
		preyTierMax = -1,
		safe = true,
		lightingPreset = "Cove interior",
	},
}

return table.freeze(Zones)
