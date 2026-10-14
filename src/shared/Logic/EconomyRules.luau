--!strict
-- EconomyRules: the pure half of EconomyService (docs/09, sections 4.4 and 5.1; docs/10, section 5).
-- Pearls are one whole-number balance that is never negative (09 §12.2). Every change is a source
-- (`grant`) or a sink (`spend`) with a transaction type and an item SKU from chapter 10's tables;
-- the same names go to `Analytics.pearls`, so a balance change and its economy event always agree.
--
-- `PearlSource` and `PearlSink` are the transaction types of 10 §5.1 and §5.2 (16 names: `Admin`
-- is both). The SKU lists are those tables' `itemSku` column, [L] rows included, so a later task
-- that grants Pearls needs no change here. Not listed: the [P1] `tide_limited`.
-- Tables only, so it runs in Lune.

local Species = require("../Data/Generated/Species")

export type PearlSource =
	"Bank"
	| "Scraps"
	| "CoveIncome"
	| "Onboarding"
	| "IAP"
	| "AdReward"
	| "Goal"
	| "Streak"
	| "Codex"
	| "Rank"
	| "Tide"
	| "Refund"
	| "Admin"
export type PearlSink = "Species" | "CoveSlot" | "Decoration" | "Admin"
export type Flow = "Source" | "Sink"

local EconomyRules = {}

--- 10 §2.3: one currency.
EconomyRules.CURRENCY = "Pearls"
--- The largest balance kept exact by a double; a change past it is refused.
EconomyRules.MAX_BALANCE = 2 ^ 53 - 1

local function set(list: { string }): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for _, item in list do
		out[item] = true
	end
	return table.freeze(out)
end

local function range(prefix: string, first: number, last: number): { string }
	local out: { string } = {}
	for n = first, last do
		table.insert(out, `{prefix}{n}`)
	end
	return out
end

local function concat(...: { string }): { string }
	local out: { string } = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #out + 1, out)
	end
	return out
end

-- Species sold for Pearls (10 §5.2: the species ID is the SKU): every species with a price.
local speciesSkus: { string } = {}
for _, def in Species do
	if def.unlockPearls > 0 then
		table.insert(speciesSkus, def.id)
	end
end

--- 10 §5.1: source transaction type → its item SKUs.
EconomyRules.SOURCE_SKUS = table.freeze({
	Bank = set(concat(range("bank_t", 1, 7), { "bank_crystal", "bank_deep_pockets" })),
	Scraps = set({ "scraps_50", "scraps_10" }),
	CoveIncome = set({ "claim_pile", "claim_welcome" }),
	Onboarding = set({ "income_first_tick" }),
	IAP = set({
		"prod_pearls_s",
		"prod_pearls_m",
		"prod_pearls_l",
		"prod_pearls_xl",
		"prod_starter_pack", -- [L]
		"prod_cove_boost", -- [L]
	}),
	AdReward = set({ "ad_cove_boost" }), -- [L]
	Goal = set(concat(range("goal_slot", 1, 3), { "goal_all3" })),
	Streak = set(range("streak_d", 1, 7)), -- [L]
	Codex = set({
		"cdx_entry_prey",
		"cdx_entry_trait",
		"cdx_entry_tier",
		"cdx_page",
		"cdx_category",
	}),
	Rank = set({ "rank_up" }), -- [L]
	Tide = set({ "tide_bonus_frenzy", "tide_bonus_moon_tide", "tide_bonus_whale_fall" }), -- [L]
	Refund = set({ "release_refund" }),
	Admin = set({ "admin_grant" }),
} :: { [string]: { [string]: boolean } })

--- 10 §5.2: sink transaction type → its item SKUs. `Decoration` SKUs are checked by shape instead.
EconomyRules.SINK_SKUS = table.freeze({
	Species = set(speciesSkus),
	CoveSlot = set({ "slots_07_12", "slots_13_20", "slots_21_30" }),
	Decoration = set({}), -- [L] see isPearlDecoration
	Admin = set({ "admin_remove" }),
} :: { [string]: { [string]: boolean } })

-- Decoration families that are never bought with Pearls (09 §3 decoration IDs; 10 §5.2).
local NOT_PEARL_DECORATIONS = { "deco_buy_", "deco_rank_", "deco_cdx_", "deco_goals_", "deco_evt_" }

--- 10 §5.2: a Pearl decoration's SKU is its chapter 03 ID, `deco_<name>`, outside the families
--- earned or bought another way.
function EconomyRules.isPearlDecoration(sku: string): boolean
	if not string.match(sku, "^deco_[a-z0-9_]+$") then
		return false
	end
	for _, prefix in NOT_PEARL_DECORATIONS do
		if string.sub(sku, 1, #prefix) == prefix then
			return false
		end
	end
	return true
end

--- Whether `sku` belongs to transaction type `kind` on side `flow`.
function EconomyRules.skuFits(flow: Flow, kind: string, sku: string): boolean
	if flow == "Sink" and kind == "Decoration" then
		return EconomyRules.isPearlDecoration(sku)
	end
	local table_ = if flow == "Source" then EconomyRules.SOURCE_SKUS else EconomyRules.SINK_SKUS
	local skus = table_[kind]
	return skus ~= nil and skus[sku] == true
end

--- Every SKU in the fixed lists, sources then sinks (Decoration's 18 are not listed by name).
function EconomyRules.allSkus(): { string }
	local out: { string } = {}
	for _, side in { EconomyRules.SOURCE_SKUS, EconomyRules.SINK_SKUS } do
		for _, skus in side do
			for sku in skus do
				table.insert(out, sku)
			end
		end
	end
	table.sort(out)
	return out
end

local function wholeNumber(n: unknown): boolean
	return type(n) == "number" and n == n and n == math.floor(n) and math.abs(n) < math.huge
end

--- 10 §2.3: an economy amount is always positive, and Pearls are whole numbers.
function EconomyRules.checkAmount(amount: unknown): (boolean, string?)
	if not wholeNumber(amount) then
		return false, `amount must be a whole number, got {amount}`
	end
	if (amount :: number) <= 0 then
		return false, `amount must be positive, got {amount}`
	end
	if (amount :: number) > EconomyRules.MAX_BALANCE then
		return false, `amount {amount} is too large`
	end
	return true, nil
end

--- A transaction type and optional SKU on one side: `(true)` or `(false, why)`. A source may have
--- no SKU (the dashboard shows "N/A", 10 §2.2); a sink always names what was bought (09 §5.1).
function EconomyRules.checkKind(flow: Flow, kind: unknown, sku: unknown): (boolean, string?)
	local side = if flow == "Source" then EconomyRules.SOURCE_SKUS else EconomyRules.SINK_SKUS
	if type(kind) ~= "string" or side[kind] == nil then
		return false, `{kind} is not a Pearl {string.lower(flow)}`
	end
	if sku == nil and flow == "Source" then
		return true, nil
	end
	if type(sku) ~= "string" or not EconomyRules.skuFits(flow, kind, sku) then
		return false, `{sku} is not a {kind} SKU`
	end
	return true, nil
end

--- The balance after granting `amount` from `source`, or nil and why it is refused.
function EconomyRules.afterGrant(
	balance: number,
	amount: unknown,
	source: unknown,
	sku: unknown
): (number?, string?)
	local ok, why = EconomyRules.checkAmount(amount)
	if ok then
		ok, why = EconomyRules.checkKind("Source", source, sku)
	end
	if not ok then
		return nil, why
	end
	local after = balance + (amount :: number)
	if after > EconomyRules.MAX_BALANCE then
		return nil, `the balance would pass {EconomyRules.MAX_BALANCE}`
	end
	return after, nil
end

--- The balance after spending `amount` on `sink`, or nil and why it is refused (09 §14: the balance
--- is checked before anything changes).
function EconomyRules.afterSpend(
	balance: number,
	amount: unknown,
	sink: unknown,
	sku: unknown
): (number?, string?)
	local ok, why = EconomyRules.checkAmount(amount)
	if ok then
		ok, why = EconomyRules.checkKind("Sink", sink, sku)
	end
	if not ok then
		return nil, why
	end
	if (amount :: number) > balance then
		return nil, `balance {balance} is under {amount}`
	end
	return balance - (amount :: number), nil
end

return table.freeze(EconomyRules)
