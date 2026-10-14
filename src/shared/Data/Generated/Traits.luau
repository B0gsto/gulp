--!strict
-- GENERATED, do not edit. Change the source table in the bible, then run
-- `lune run tools/gen/content` (docs/09, section 3.2).
-- Source: docs/03-content-catalog.md data:Traits; docs/05-economy-and-monetization.md data:TraitIncome.
-- Build: full.
local Types = require("../../Types")

local Traits: { Types.TraitDef } = {
	{ id = "glow", wire = 1, scope = "MVP", rarity = "Common", incomeBonus = 0.1 },
	{ id = "stripes", wire = 2, scope = "MVP", rarity = "Common", incomeBonus = 0.1 },
	{ id = "spots", wire = 3, scope = "MVP", rarity = "Common", incomeBonus = 0.1 },
	{ id = "plated", wire = 4, scope = "MVP", rarity = "Uncommon", incomeBonus = 0.2 },
	{ id = "spiny", wire = 5, scope = "MVP", rarity = "Uncommon", incomeBonus = 0.2 },
	{ id = "longfin", wire = 6, scope = "MVP", rarity = "Uncommon", incomeBonus = 0.2 },
	{ id = "ink", wire = 7, scope = "MVP", rarity = "Rare", incomeBonus = 0.35 },
	{ id = "spark", wire = 8, scope = "L", rarity = "Rare", incomeBonus = 0.35 },
	{ id = "camo", wire = 9, scope = "L", rarity = "Rare", incomeBonus = 0.35 },
	{ id = "crystal", wire = 10, scope = "MVP", rarity = "Epic", incomeBonus = 0.6 },
	{ id = "ember", wire = 11, scope = "L", rarity = "Epic", incomeBonus = 0.6 },
	{ id = "moonlit", wire = 12, scope = "MVP", rarity = "Mythic", incomeBonus = 1 },
	{ id = "bonefed", wire = 13, scope = "L", rarity = "Mythic", incomeBonus = 1 },
}

return table.freeze(Traits)
