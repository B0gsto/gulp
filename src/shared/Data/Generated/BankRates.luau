--!strict
-- GENERATED, do not edit. Change the source table in the bible, then run
-- `lune run tools/gen/content` (docs/09, section 3.2).
-- Source: docs/01-game-canon.md data:BankRates.
-- Build: full.
local Types = require("../../Types")

local BankRates: { Types.BankRateDef } = {
	{ from = 0, upTo = 1200, pearlsPerMass = 3 },
	{ from = 1200, upTo = 3000, pearlsPerMass = 1 },
	{ from = 3000, pearlsPerMass = 0 },
}

return table.freeze(BankRates)
