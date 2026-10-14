--!strict
-- GoalRules: daily goal selection, fit, rerolls, progress and rewards (task S4-C3, module B07;
-- canon 11; docs/02, section 15.3; docs/03, section 9; docs/05, sections 3.5, 3.7 and 3.12;
-- docs/09, section 5.1 GoalsService). Pure: the same user and UTC day always give the same
-- goals, in Roblox and in Lune (Util/Rng, not math.random).
--
-- The goal list, targets, difficulties, reward bands and "Needs" come from Data/Generated/Goals.
-- The data has no column for a goal's kind, so two rules read the canon goal text: a tier goal
-- is "Grow into a <tier name>", and a goal that needs eating players says "other player". Band
-- amounts come from Data/Generated/RewardBands (05 §3.12); the rank multiplier and the reroll
-- limits from Config/Defaults.goals.
local Defaults = require("../Config/Defaults")
local Index = require("../Data/Index")
local Rng = require("../Util/Rng")

local GoalRules = {}

GoalRules.DAY = 86400 -- goals reset at 00:00 UTC (02 §15.3)
GoalRules.FIRST_DAY = table.freeze({ "dg_eat_50", "dg_tier3", "dg_bank_snapper" }) -- canon 11
GoalRules.DIFFICULTIES = table.freeze({ "Easy", "Medium", "Hard" }) -- canon 11: one of each
GoalRules.ALL_DONE_BAND = Defaults.goals.allDoneBand
GoalRules.RANK_STEP = Defaults.goals.rankStep
GoalRules.MAX_RANK = Defaults.goals.maxRank
GoalRules.REROLLS = Defaults.goals.rerolls :: { [string]: number }

export type RerollHow = "free" | "video" | "product"

--- What the picker knows about the player and the server (02 §15.3 "Fit to the player").
export type Context = {
	bestTier: number, -- the account's best tier ever (Codex)
	speciesOwned: number,
	players: number, -- players on this server
	shipped: { [string]: boolean }?, -- scope tags in this build; default { MVP = true }
}

local MVP: { [string]: boolean } = table.freeze({ MVP = true })

local tierByName: { [string]: number } = {}
for _, def in Index.Tiers.list do
	tierByName[def.name] = def.tier
end

--- The UTC day number of Unix time `unix` (09 §12.2: `day` fields are floor(unix / 86400)).
function GoalRules.day(unix: number): number
	return unix // GoalRules.DAY
end

--- 05 §3.7: 1 + 0.1 × (rank − 1), for ranks 1 to 50.
function GoalRules.rankMultiplier(rank: number): number
	return 1 + GoalRules.RANK_STEP * (math.clamp(math.floor(rank), 1, GoalRules.MAX_RANK) - 1)
end

--- Pearls a goal pays at Reef Rank `rank` (05 §3.5): its band × the rank multiplier, rounded
--- down. 0 for an unknown goal.
function GoalRules.reward(goalId: string, rank: number): number
	local def = Index.Goals.byId[goalId]
	local band = if def then Index.RewardBands.byId[def.reward] else nil
	if band == nil then
		return 0
	end
	return math.floor(band.pearls * GoalRules.rankMultiplier(rank) + 1e-9)
end

--- The bonus for finishing all three goals (05 §3.5), × the rank multiplier, rounded down.
function GoalRules.allDoneBonus(rank: number): number
	local band = Index.RewardBands.byId[GoalRules.ALL_DONE_BAND]
	return if band then math.floor(band.pearls * GoalRules.rankMultiplier(rank) + 1e-9) else 0
end

--- The tier a "Grow into a <tier>" goal asks for; nil for any other goal.
function GoalRules.goalTier(goalId: string): number?
	local def = Index.Goals.byId[goalId]
	local name = if def then string.match(def.text, "^Grow into an? (%a+)$") else nil
	return if name then tierByName[name] else nil
end

--- True for a goal that needs eating players (02 §15.3: at most one a day).
function GoalRules.eatsPlayers(goalId: string): boolean
	local def = Index.Goals.byId[goalId]
	return def ~= nil and string.find(def.text, "other player", 1, true) ~= nil
end

-- The data's "Needs" text, read against the context. Unknown wording is not met, so a new kind of
-- need is never offered by mistake.
local function needsMet(needs: string, ctx: Context): boolean
	local species = string.match(needs, "^Owns (%d+) or more species$")
	if species then
		return ctx.speciesOwned >= (tonumber(species) :: number)
	end
	local players = string.match(needs, "^(%d+) or more players on the server$")
	if players then
		return ctx.players >= (tonumber(players) :: number)
	end
	local tierName = string.match(needs, "^Has reached (%a+) before$")
	if tierName and tierByName[tierName] then
		return ctx.bestTier >= tierByName[tierName]
	end
	return false
end

--- Whether a goal may be offered (02 §15.3, 03 §9): shipped in this build, its "Needs" met, and
--- a tier goal no higher than the best tier + 1.
function GoalRules.eligible(goalId: string, ctx: Context): (boolean, string?)
	local def = Index.Goals.byId[goalId]
	if def == nil then
		return false, "unknown"
	end
	if not (ctx.shipped or MVP)[def.scope] then
		return false, "scope"
	end
	if def.needs and not needsMet(def.needs, ctx) then
		return false, "needs"
	end
	local tier = GoalRules.goalTier(goalId)
	if tier and tier > ctx.bestTier + 1 then
		return false, "tier"
	end
	return true, nil
end

local function seed(userId: number, day: number, salt: number): Rng.Rng
	local low, high = userId % 0x100000000, userId // 0x100000000
	return Rng.new((low + high * 0x9E3779B9 + day * 0x85EBCA6B + salt * 0xC2B2AE35) % 0x100000000)
end

-- Eligible goals of `difficulty` in canon order, minus `exclude`, minus player-eating goals when
-- `noPlayers` is set.
local function candidates(
	difficulty: string,
	ctx: Context,
	exclude: { [string]: boolean },
	noPlayers: boolean
): { string }
	local list = {}
	for _, def in Index.Goals.list do
		if
			def.difficulty == difficulty
			and not exclude[def.id]
			and not (noPlayers and GoalRules.eatsPlayers(def.id))
			and GoalRules.eligible(def.id, ctx)
		then
			table.insert(list, def.id)
		end
	end
	return list
end

--- The day's three goals (02 §15.3, 03 §9), Easy, Medium, Hard in that order, seeded by user ID
--- and UTC day. An account's first day is the fixed set. Never one of `yesterday`'s goals while
--- another fits; never two that need eating players. A difficulty with no fitting goal is left
--- out, so the list can be shorter than three.
function GoalRules.pick(
	userId: number,
	day: number,
	ctx: Context,
	firstDay: boolean,
	yesterday: { string }?
): { string }
	if firstDay then
		return table.clone(GoalRules.FIRST_DAY)
	end
	local rng = seed(userId, day, 0)
	local before: { [string]: boolean } = {}
	if yesterday then
		for _, id in yesterday do
			before[id] = true
		end
	end
	local chosen = {}
	local hasPlayers = false
	for _, difficulty in GoalRules.DIFFICULTIES do
		local list = candidates(difficulty, ctx, before, hasPlayers)
		if #list == 0 then
			list = candidates(difficulty, ctx, {}, hasPlayers)
		end
		local id = Rng.pick(rng, list)
		if id then
			table.insert(chosen, id)
			hasPlayers = hasPlayers or GoalRules.eatsPlayers(id)
		end
	end
	return chosen
end

--- A replacement for `current[index]` (02 §15.3): the same difficulty, none of the current goals,
--- fitting the player, and no second player-eating goal. `rerollsUsed` (this day's rerolls so
--- far) varies the seed. Nil when nothing else fits.
function GoalRules.reroll(
	userId: number,
	day: number,
	current: { string },
	index: number,
	ctx: Context,
	rerollsUsed: number
): string?
	local def = Index.Goals.byId[current[index] or ""]
	if def == nil then
		return nil
	end
	local exclude: { [string]: boolean } = {}
	local otherPlayers = false
	for i, id in current do
		exclude[id] = true
		if i ~= index and GoalRules.eatsPlayers(id) then
			otherPlayers = true
		end
	end
	local list = candidates(def.difficulty, ctx, exclude, otherPlayers)
	return Rng.pick(seed(userId, day, 1 + rerollsUsed), list)
end

--- Whether one more reroll of kind `how` is allowed today (02 §15.3, 05 §3.5): one free, one by
--- video [L], three bought [L]. `used` counts today's rerolls of each kind.
function GoalRules.canReroll(used: { [string]: number }, how: RerollHow): boolean
	return (used[how] or 0) < GoalRules.REROLLS[how]
end

--- Adds `amount` to a goal's progress, stopping at its target (02 §15.3). Returns the new progress
--- and whether this call completed the goal (the moment its reward is paid).
function GoalRules.advance(goalId: string, progress: number, amount: number): (number, boolean)
	local def = Index.Goals.byId[goalId]
	if def == nil or progress >= def.target or amount <= 0 then
		return progress, false
	end
	local new = math.min(def.target, progress + amount)
	return new, new >= def.target
end

--- Whether goals stored for day `storedDay` must be replaced at Unix time `now` (00:00 UTC reset).
function GoalRules.needsReset(storedDay: number, now: number): boolean
	return GoalRules.day(now) ~= storedDay
end

return table.freeze(GoalRules)
