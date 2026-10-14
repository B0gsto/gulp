--!strict
-- GENERATED, do not edit. Change the source table in the bible, then run
-- `lune run tools/gen/content` (docs/09, section 3.2).
-- Source: docs/03-content-catalog.md data:Codex.
-- Build: full.
local Types = require("../../Types")

local Codex: { Types.CodexCategoryDef } = {
	{
		id = "cdx_species",
		wire = 1,
		scope = "MVP",
		entryPearls = {},
		rewardPearls = 175,
		rewardDecoration = "deco_cdx_family_portrait",
	},
	{
		id = "cdx_tiers",
		wire = 2,
		scope = "MVP",
		entryPearls = { 25, 50, 100, 200, 400, 800 },
		rewardPearls = 5000,
		rewardTitle = "Leviathan Maker",
	},
	{
		id = "cdx_traits",
		wire = 3,
		scope = "MVP",
		entryPearls = { 100, 200, 400, 800, 1500 },
		rewardPearls = 2500,
		rewardDecoration = "deco_cdx_trait_totem",
	},
	{
		id = "cdx_prey",
		wire = 4,
		scope = "MVP",
		entryPearls = { 20, 30 },
		rewardPearls = 175,
		rewardDecoration = "deco_cdx_prey_mobile",
	},
	{
		id = "cdx_dangers",
		wire = 5,
		scope = "L",
		entryPearls = {},
		rewardPearls = 175,
		rewardDecoration = "deco_cdx_danger_board",
	},
	{
		id = "cdx_places",
		wire = 6,
		scope = "L",
		entryPearls = {},
		rewardPearls = 175,
		rewardDecoration = "deco_cdx_sea_globe",
	},
	{
		id = "cdx_tides",
		wire = 7,
		scope = "L",
		entryPearls = {},
		rewardPearls = 125,
		rewardDecoration = "deco_cdx_tide_chart",
	},
	{
		id = "cdx_all",
		wire = 8,
		scope = "L",
		entryPearls = {},
		rewardPearls = 5000,
		rewardTitle = "Reef Scholar",
	},
}

return table.freeze(Codex)
