--!strict
-- AnalyticsRules: the pure half of the Analytics wrapper (docs/09, sections 5.1 and 20 R13;
-- docs/10, sections 2.3, 2.4, 3, 4 and 5). The one enum module of R13: every custom event name,
-- every Roblox funnel and its step names, with the context values each may carry, and the checks
-- that keep the server inside chapter 10's limits. The server module (server/Services/Analytics)
-- calls these before anything reaches `AnalyticsService` or the Studio buffer.
--
-- Scope: the [MVP] rows only. Of the 61 events of 10 §4.2 the nine [L] ones are left out
-- (`sess_private_server`, `ret_streak`, `tide_call_used`, `rv_unavailable`, `rv_failed`,
-- `cove_bubble_received`, `cove_deco_placed`, `pvp_pair`, `input_switch`), and so are the [L]
-- context values of [MVP] events; of the ten funnels of 10 §3, numbers 1 to 7. The task that
-- builds an [L] feature adds its rows here.
-- Tables only, so it runs in Lune.

local EconomyRules = require("./EconomyRules")
local Goals = require("../Data/Generated/Goals")
local Species = require("../Data/Generated/Species")
local Tides = require("../Data/Generated/Tides")
local Traits = require("../Data/Generated/Traits")

export type Priority = "P0" | "P1" | "P2"
export type Cohort = "s1" | "d0" | "d1_6" | "d7p"
-- A context rule: a fixed list of values, "none" (the dictionary's "—"), or an ID family.
export type CtxRule = { string } | "none" | "species" | "trait" | "goal" | "tide" | "experiment"
export type EventDef = { priority: Priority, ctx: CtxRule }
export type FunnelDef = {
	name: string, -- the Roblox funnel name; "onboarding" uses the onboarding call (10 §2.4)
	oneTime: boolean,
	priority: Priority,
	steps: { string },
	ctx: { CtxRule }, -- per step
}
-- Highest step sent per funnel session, for the 10 most recent sessions per funnel (10 §2.3).
export type StepMemory = { [string]: { order: { string }, highest: { [string]: number } } }

local AnalyticsRules = {}

--- 10 §2.3 and §2.4.
AnalyticsRules.LIMITS = table.freeze({
	customEventNames = 100,
	funnels = 10,
	stepsPerFunnel = 100,
	recentSessions = 10, -- funnel sessions Roblox tracks per user per funnel
	transactionTypes = 20,
	skus = 100,
	customFieldCombinations = 8000,
	eventsPerPlayerPerMinute = 16, -- the module's own budget
	bufferSize = 2000, -- the Studio buffer
})

-- How many tokens P2 events leave for P1 and P0 ones: "drops P2 first" (10 §2.4) needs P2 to stop
-- before the bucket is empty. Not set by chapter 10. (tune)
AnalyticsRules.P2_RESERVE = 4

--- 10 §2.4: the `exp` field when no experiment arm is attached; the `ctx` field for "—".
AnalyticsRules.NONE = "none"

local function ids(rows: { { id: string } }): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for _, row in rows do
		out[row.id] = true
	end
	return table.freeze(out)
end

local ID_FAMILIES: { [string]: { [string]: boolean } } = {
	species = ids(Species :: any),
	trait = ids(Traits :: any),
	goal = ids(Goals :: any),
	tide = ids(Tides :: any),
}

local function cross(parts: { { string } }): { string }
	local out: { string } = { "" }
	for i, part in parts do
		local nextOut: { string } = {}
		for _, head in out do
			for _, tail in part do
				table.insert(nextOut, if i == 1 then tail else `{head}_{tail}`)
			end
		end
		out = nextOut
	end
	return out
end

local function prefixed(prefix: string, list: { string }): { string }
	local out: { string } = {}
	for _, item in list do
		table.insert(out, prefix .. item)
	end
	return out
end

local TIERS = { "t1", "t2", "t3", "t4", "t5", "t6", "t7" }
local TIERS_2 = { "t2", "t3", "t4", "t5", "t6", "t7" }
local TIERS_3 = { "t3", "t4", "t5", "t6", "t7" }
local LEFT_STAGES = prefixed("left_s", { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" })
-- 10 §4.2 device and input events: the [MVP] classes and inputs (handheld, tv, gamepad are [L]).
local MVP_CLASSES = { "phone", "tablet", "desktop" }
local ALL_CLASSES = { "phone", "tablet", "desktop", "handheld", "tv" }
local MVP_INPUTS = { "touch", "kbm" }
-- 10 §4.2 `shop_purchased`, [MVP] SKUs.
local SHOP_SKUS = {
	"pass_deep_pockets",
	"pass_bigger_cove",
	"prod_pearls_s",
	"prod_pearls_m",
	"prod_pearls_l",
	"prod_pearls_xl",
	"prod_revive",
}
-- 10 §9.2 rule IDs, plus the module's own drop report.
local GUARD_RULES = {
	"bite_rate",
	"speed",
	"mass_rate",
	"run_pearls",
	"hour_pearls",
	"bank_teleport",
	"wallet_mismatch",
	"income_clock",
	"analytics_drop",
}

local function event(priority: Priority, ctx: CtxRule): EventDef
	return table.freeze({
		priority = priority,
		ctx = if type(ctx) == "table" then table.freeze(table.clone(ctx)) else ctx,
	})
end

-- 10 §2.4 priorities: P2 is settings, Codex, hazard hits, `sess_device`, `perf_tier`; P1 is the
-- run events with `run_end_input`; everything else is P0 (onboarding, purchases, economy and the
-- rest, which the chapter does not rank).
--- 10 §4.2, the 52 [MVP] custom events.
AnalyticsRules.EVENTS = table.freeze({
	-- First-time experience
	ftue_milestone = event("P0", {
		"bite_le5",
		"bite_le10",
		"bite_le20",
		"bite_gt20",
		"tier2_le30",
		"tier2_le45",
		"tier2_le60",
		"tier2_gt60",
		"trait_le45",
		"trait_le60",
		"trait_le90",
		"trait_gt90",
		"bank_le90",
		"bank_le120",
		"bank_le180",
		"bank_gt180",
	}),
	ftue_bite_assist = event("P0", "none"),
	ftue_first_dash = event("P0", { "manual", "auto" }),
	ftue_failsafe = event("P0", {
		"load_partial",
		"load_minimal",
		"grow_homing",
		"grow_burst",
		"trait_homing",
		"afk_hold",
		"run2_homing",
		"home_lure",
		"home_push",
	}),
	ftue_chase_result = event("P0", { "clean", "assisted", "retreated", "skipped" }),
	ftue_shield_end = event("P0", { "banked", "timeout" }),
	ftue_end = event("P0", { "completed", table.unpack(LEFT_STAGES) }),
	-- System and session
	sys_load_time = event("P0", { "le5", "le10", "le20", "gt20" }),
	sys_profile_fail = event("P0", { "timeout", "locked", "error" }),
	sys_session_end = event(
		"P0",
		{ "ftue", "cove", "nursery", "run_safe", "run_open", "gulped_screen", "shop" }
	),
	sess_start = event("P0", { "1", "2", "3", "4_9", "10p" }),
	sess_input = event("P0", MVP_INPUTS),
	sess_day_mark = event("P0", { "m10", "m30", "m60" }),
	social_friend_join = event("P0", "none"),
	-- First session and return
	fs_time_mark = event("P0", { "s60", "s180", "m5", "m10", "m15", "m25" }),
	fs_milestone = event("P0", {
		"run2_start",
		"goal_first",
		"gulped_first",
		"tide_first",
		"bank2",
		"run3_start",
		"player_scare_first",
		"species_first",
		"codex_open",
	}),
	fs_end = event("P0", { "r1", "r2", "r3", "r4p" }),
	ret_day = event("P0", { "d1", "d2", "d3", "d4_6", "d7", "d8_13", "d14", "d15_29", "d30p" }),
	ret_welcome = event("P0", { "shown", "claimed" }),
	-- Run
	run_banked = event("P1", TIERS),
	run_gulped = event("P1", TIERS),
	run_gulped_by = event("P1", { "player", "gull", "moray", "barracuda", "grouper", "old_scar" }),
	run_abandoned = event("P1", TIERS),
	run_duration = event("P1", { "banked", "gulped", "abandoned" }),
	run_species = event("P1", "species"),
	run_zone_enter = event("P1", { "reef", "kelp", "dropoff" }),
	run_pvp_eat = event("P1", TIERS_2),
	run_hazard_hit = event("P2", { "jelly_bloom", "hook", "plated_break" }),
	-- Species, traits
	species_ability_use = event("P0", "species"),
	trait_shed = event("P0", "trait"),
	trait_lost = event("P0", "trait"),
	trait_slots_full = event("P0", "none"),
	-- Shop, revive
	shop_open = event("P0", { "hud", "gulped_screen", "cove", "offer" }),
	shop_purchased = event("P0", SHOP_SKUS),
	shop_prompt_cancelled = event("P0", { "pass", "pearl_pack", "prod_revive" }),
	shop_grant_failed = event("P0", SHOP_SKUS),
	revive_declined = event("P0", TIERS_3),
	-- Cove, goals, Codex, settings
	cove_time = event("P0", { "after_bank", "after_gulp", "login" }),
	cove_specimen_released = event("P0", TIERS_2),
	cove_full_choice = event("P0", { "released_old", "released_new" }),
	goal_completed = event("P0", "goal"),
	goal_all3 = event("P0", "none"),
	goal_rerolled = event("P0", { "free" }),
	codex_entry = event("P2", { "species", "tier", "trait", "prey" }),
	codex_opened = event("P2", "none"),
	settings_changed = event(
		"P2",
		{ "music_off", "sfx_off", "low_graphics_on", "invert_y_on", "haptics_off" }
	),
	-- Device and input
	sess_device = event("P2", cross({ MVP_CLASSES, { "s", "m", "l" }, MVP_INPUTS })),
	run_end_input = event(
		"P1",
		cross({ MVP_INPUTS, { "bank", "gulp_player", "gulp_npc", "quit" } })
	),
	perf_tier = event("P2", cross({ ALL_CLASSES, { "smooth", "balanced", "pretty", "cut" } })),
	-- Guards and experiments
	guard_flag = event("P0", GUARD_RULES),
	guard_action = event("P0", { "clamp", "rollback", "kick" }),
	ab_exposed = event("P0", "experiment"),
} :: { [string]: EventDef })

local function funnel(
	name: string,
	oneTime: boolean,
	priority: Priority,
	steps: { string },
	ctx: { CtxRule }
): FunnelDef
	return table.freeze({
		name = name,
		oneTime = oneTime,
		priority = priority,
		steps = table.freeze(steps),
		ctx = table.freeze(ctx),
	})
end

local function same(rule: CtxRule, count: number): { CtxRule }
	return table.create(count, rule)
end

-- Funnel steps of the purchase funnels are P0 (purchases, 10 §2.4); the other recurring funnels
-- carry run and progression steps and rank with the run events (P1).
--- 10 §3, Roblox funnels 1 to 7 ([MVP]). The step number is the position in `steps`.
AnalyticsRules.FUNNELS = table.freeze({
	onboarding = funnel("onboarding", true, "P0", {
		"01_joined",
		"02_loading_screen",
		"03_control",
		"04_first_input",
		"05_first_bite",
		"06_mass_5",
		"07_tier2",
		"08_glowfry_1",
		"09_trait_gained",
		"10_left_nursery",
		"11_channel_cleared",
		"12_cove_in_sight",
		"13_banked",
		"14_specimen_placed",
		"15_first_tick",
		"16_cliffhanger_seen",
		"17_run2_started",
		"18_run2_tier2",
		"19_run2_ended",
		"20_run3_started",
	}, same("none", 20)),
	run = funnel("run", false, "P1", {
		"01_hatched",
		"02_left_safe",
		"03_first_bite",
		"04_tier2",
		"05_tier3",
		"06_tier4",
		"07_tier5",
		"08_tier6",
		"09_tier7",
	}, same("none", 9)),
	species_unlock = funnel("species_unlock", false, "P1", {
		"01_silhouette_seen",
		"02_affordable",
		"03_card_opened",
		"04_bought",
		"05_hatched_as",
		"06_banked_as",
	}, same("species", 6)),
	trait = funnel("trait", false, "P1", {
		"01_prey_seen",
		"02_first_eaten",
		"03_third_eaten",
		"04_gained",
		"05_banked_with",
	}, same("trait", 5)),
	tide_event = funnel("tide_event", false, "P1", {
		"01_warned",
		"02_present_at_start",
		"03_in_open_water",
		"04_engaged",
		"05_reward",
		"06_banked_after",
	}, same("tide", 6)),
	shop_purchase = funnel("shop_purchase", false, "P0", {
		"01_surface_seen",
		"02_item_viewed",
		"03_prompt_shown",
		"04_purchased",
		"05_granted",
	}, same({ "pass", "pearl_pack" }, 5)),
	revive_offer = funnel("revive_offer", false, "P0", {
		"01_gulped_eligible",
		"02_offer_shown",
		"03_option_tapped",
		"04_started",
		"05_revived",
		"06_banked_after",
	}, { TIERS_3, TIERS_3, { "paid" }, { "paid" }, { "paid" }, { "paid" } }),
} :: { [string]: FunnelDef })

local function fits(rule: CtxRule, ctx: unknown): boolean
	if rule == "none" then
		return ctx == nil or ctx == AnalyticsRules.NONE
	end
	if type(ctx) ~= "string" then
		return false
	end
	if type(rule) == "table" then
		return table.find(rule, ctx) ~= nil
	elseif rule == "experiment" then
		-- 10 §4.2 `ab_exposed`: `<key>=<variant>`, live-config keys and variant names only.
		return string.match(ctx, "^[%w_%.]+=[%w_]+$") ~= nil
	end
	local family = ID_FAMILIES[rule :: string]
	return family ~= nil and family[ctx] == true
end

local function finite(n: unknown): boolean
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end

--- A custom event: `(true)` or `(false, why)`. `ctx` is nil or "none" for an event without one.
function AnalyticsRules.checkEvent(name: unknown, value: unknown, ctx: unknown): (boolean, string?)
	local def = if type(name) == "string" then AnalyticsRules.EVENTS[name] else nil
	if not def then
		return false, `{name} is not in the event dictionary`
	end
	if not finite(value) then
		return false, `{name}: value must be a finite number, got {value}`
	end
	if not fits(def.ctx, ctx) then
		return false, `{name}: {ctx} is not one of its ctx values`
	end
	return true, nil
end

--- A funnel step: the step's name, or nil and why it is refused. A recurring funnel needs a
--- session ID; the one-time onboarding funnel takes none.
function AnalyticsRules.checkStep(
	funnelName: unknown,
	sessionId: unknown,
	step: unknown,
	ctx: unknown
): (string?, string?)
	local def = if type(funnelName) == "string" then AnalyticsRules.FUNNELS[funnelName] else nil
	if not def then
		return nil, `{funnelName} is not a funnel`
	end
	if def.oneTime then
		if sessionId ~= nil then
			return nil, `{funnelName} is one-time and takes no session ID`
		end
	elseif type(sessionId) ~= "string" or sessionId == "" or #sessionId > 100 then
		return nil, `{funnelName}: a recurring funnel needs a session ID, got {sessionId}`
	end
	if type(step) ~= "number" or step ~= math.floor(step) or step < 1 or step > #def.steps then
		return nil, `{funnelName}: no step {step}`
	end
	if not fits(def.ctx[step], ctx) then
		return nil, `{funnelName} step {step}: {ctx} is not one of its ctx values`
	end
	return def.steps[step], nil
end

--- An economy event: `(true)` or `(false, why)`. 10 §2.3: the amount is always positive; 09 §12.2:
--- the balance is a whole number and never negative.
function AnalyticsRules.checkPearls(
	flow: unknown,
	amount: unknown,
	balance: unknown,
	transactionType: unknown,
	sku: unknown
): (boolean, string?)
	if flow ~= "Source" and flow ~= "Sink" then
		return false, `flow must be Source or Sink, got {flow}`
	end
	local ok, why = EconomyRules.checkAmount(amount)
	if not ok then
		return false, why
	end
	if type(balance) ~= "number" or balance < 0 or balance ~= math.floor(balance) then
		return false, `balance must be a whole number of 0 or more, got {balance}`
	end
	return EconomyRules.checkKind(flow :: EconomyRules.Flow, transactionType, sku)
end

--- 10 §2.4 rate budget: whether an event of `priority` may go when the bucket holds `available`
--- tokens. P0 always goes; P1 needs a token; P2 also leaves `P2_RESERVE` tokens for the others.
function AnalyticsRules.admits(priority: Priority, available: number): boolean
	if priority == "P0" then
		return true
	elseif priority == "P1" then
		return available >= 1
	end
	return available >= 1 + AnalyticsRules.P2_RESERVE
end

local DAY = 86400

--- 10 §2.4 `cohort` from the profile: `sessions` (this one included), `createdAt` (the first play
--- day) and the time now, in Unix seconds. Days are UTC days.
function AnalyticsRules.cohort(sessions: number, createdAt: number, now: number): Cohort
	if sessions <= 1 then
		return "s1"
	end
	local days = math.floor(now / DAY) - math.floor(createdAt / DAY)
	if days <= 0 then
		return "d0"
	elseif days <= 6 then
		return "d1_6"
	end
	return "d7p"
end

--- An empty memory of funnel steps for one player.
function AnalyticsRules.newStepMemory(): StepMemory
	return {}
end

--- Whether `step` is higher than any step already sent in this funnel session (nothing recorded).
function AnalyticsRules.isNewStep(
	memory: StepMemory,
	funnelName: string,
	sessionId: string?,
	step: number
): boolean
	local slot = memory[funnelName]
	local highest = if slot then slot.highest[sessionId or ""] else nil
	return highest == nil or step > highest
end

--- 10 §2.3: only the first instance of a step counts, and a later step completes the earlier ones.
--- Records `step` and returns true when it is higher than any step already sent in this funnel
--- session; false for a repeat, which is dropped. Keeps the 10 most recent sessions per funnel, as
--- Roblox does.
function AnalyticsRules.firstTime(
	memory: StepMemory,
	funnelName: string,
	sessionId: string?,
	step: number
): boolean
	local key = sessionId or ""
	local slot = memory[funnelName]
	if not slot then
		slot = { order = {}, highest = {} }
		memory[funnelName] = slot
	end
	local highest = slot.highest[key]
	if highest and step <= highest then
		return false
	end
	if not highest then
		table.insert(slot.order, key)
		if #slot.order > AnalyticsRules.LIMITS.recentSessions then
			slot.highest[table.remove(slot.order, 1) :: string] = nil
		end
	end
	slot.highest[key] = step
	return true
end

--- 10 §3 session IDs that are built, not drawn (run, shop and revive sessions use a GUID or the
--- run ID). `species_unlock`: `<userId>-<speciesId>`.
function AnalyticsRules.speciesSession(userId: number, speciesId: string): string
	return `{userId}-{speciesId}`
end

--- `trait`: `<runId>-<traitId>`.
function AnalyticsRules.traitSession(runId: string, traitId: string): string
	return `{runId}-{traitId}`
end

--- `tide_event`: `<userId>-<eventStartUnix>`.
function AnalyticsRules.tideSession(userId: number, eventStartUnix: number): string
	return `{userId}-{math.floor(eventStartUnix)}`
end

--- How many custom-field combinations the events can make: `ctx` values × 4 cohorts × the
--- experiment arms (10 §2.4: device and input events never carry an arm). ID families count
--- their table's rows; `ab_exposed` counts `experimentValues`.
function AnalyticsRules.combinations(arms: number, experimentValues: number): number
	local DEVICE = { sess_device = true, run_end_input = true, perf_tier = true }
	local total = 0
	for name, def in AnalyticsRules.EVENTS do
		local rule = def.ctx
		local values = 1
		if type(rule) == "table" then
			values = #rule
		elseif rule == "experiment" then
			values = experimentValues
		elseif rule ~= "none" then
			local count = 0
			for _ in ID_FAMILIES[rule :: string] do
				count += 1
			end
			values = count
		end
		total += values * 4 * (if DEVICE[name] then 1 else arms)
	end
	return total
end

return table.freeze(AnalyticsRules)
