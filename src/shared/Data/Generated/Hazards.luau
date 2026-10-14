--!strict
-- GENERATED, do not edit. Change the source table in the bible, then run
-- `lune run tools/gen/content` (docs/09, section 3.2).
-- Source: docs/03-content-catalog.md data:Predators, data:VentCycle.
-- Build: full.
local Types = require("../../Types")

local Hazards: { Types.HazardDef } = {
	{ id = "jelly_bloom", wire = 1, scope = "MVP", effect = "stun", magnitude = 1, duration = 1.5 },
	{ id = "anemone", wire = 2, scope = "L", effect = "slow", magnitude = 0.5, duration = 2 },
	{
		id = "vent",
		wire = 3,
		scope = "L",
		effect = "burn",
		magnitude = 0.05,
		duration = 0,
		cycle = { dormant = 4, rumble = 1, erupting = 3 },
	},
	{ id = "hook", wire = 4, scope = "MVP", effect = "yank", magnitude = 0.2, duration = 0.6 },
	{ id = "current", wire = 5, scope = "MVP", effect = "push", magnitude = 0.6, duration = 0 },
}

return table.freeze(Hazards)
