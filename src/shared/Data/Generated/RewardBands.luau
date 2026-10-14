--!strict
-- GENERATED, do not edit. Change the source table in the bible, then run
-- `lune run tools/gen/content` (docs/09, section 3.2).
-- Source: docs/05-economy-and-monetization.md data:RewardBands.
-- Build: full.
local Types = require("../../Types")

local RewardBands: { Types.RewardBandDef } = {
	{ id = "R1", pearls = 100 },
	{ id = "R2", pearls = 125 },
	{ id = "R3", pearls = 175 },
	{ id = "R4", pearls = 2500 },
	{ id = "R5", pearls = 5000 },
}

return table.freeze(RewardBands)
