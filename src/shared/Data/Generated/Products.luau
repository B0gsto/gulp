--!strict
-- GENERATED, do not edit. Change the source table in the bible, then run
-- `lune run tools/gen/content` (docs/09, section 3.2).
-- Source: docs/05-economy-and-monetization.md data:Passes, data:Products, data:PearlPacks.
-- Build: full.
local Types = require("../../Types")

local Products: { Types.ProductDef } = {
	{ id = "pass_deep_pockets", kind = "pass", scope = "MVP", grant = "flag" },
	{ id = "pass_bigger_cove", kind = "pass", scope = "MVP", grant = "flag" },
	{ id = "pass_tide_watcher", kind = "pass", scope = "L", grant = "flag" },
	{ id = "pass_keen_nose", kind = "pass", scope = "L", grant = "flag" },
	{ id = "pass_shark_pup", kind = "pass", scope = "L", grant = "flag" },
	{ id = "prod_revive", kind = "product", scope = "MVP", grant = "token" },
	{ id = "prod_trait_lock", kind = "product", scope = "L", grant = "token" },
	{ id = "prod_call_tide", kind = "product", scope = "L", grant = "token" },
	{
		id = "prod_starter_pack",
		kind = "product",
		scope = "L",
		grant = "bundle",
		amount = 5000,
		items = { "pat_minnow_sunrise", "deco_buy_gold_chest" },
	},
	{ id = "prod_cove_boost", kind = "product", scope = "L", grant = "pearls" },
	{ id = "prod_goal_reroll", kind = "product", scope = "L", grant = "token" },
	{ id = "prod_pearls_s", kind = "product", scope = "MVP", grant = "pearls", amount = 2000 },
	{ id = "prod_pearls_m", kind = "product", scope = "MVP", grant = "pearls", amount = 7000 },
	{ id = "prod_pearls_l", kind = "product", scope = "MVP", grant = "pearls", amount = 22000 },
	{ id = "prod_pearls_xl", kind = "product", scope = "MVP", grant = "pearls", amount = 65000 },
}

return table.freeze(Products)
