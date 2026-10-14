--!strict
-- GENERATED, do not edit. Change the source table in the bible, then run
-- `lune run tools/gen/content` (docs/09, section 3.2).
-- Source: docs/01-game-canon.md data:Scraps.
-- Build: full.
local Types = require("../../Types")

local Scraps: { Types.ScrapsDef } = {
	{ fromDeath = 1, share = 0.5 },
	{ fromDeath = 4, share = 0.1 },
}

return table.freeze(Scraps)
