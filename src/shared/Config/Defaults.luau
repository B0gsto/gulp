--!strict
-- Defaults: the values the game runs on when nothing overrides them (docs/09, sections 17.1 and
-- 17.4). Two things live here:
--   1. One table per environment, chosen by `game.GameId`: product IDs, pass IDs, asset IDs
--      (section 3.2), analytics on or off, dev cheats on or off.
--   2. The default of every live-config key. Config/Flags reads them; LiveConfig lays the
--      Creator Dashboard values over them.
-- Every table is frozen. The module never touches `game`, so it runs in Lune: the caller passes
-- the GameId in.

export type EnvironmentName = "development" | "ci" | "staging" | "production"

export type Environment = {
	name: EnvironmentName,
	purchases: boolean, -- false: no Robux prompt is ever shown
	analytics: boolean, -- false: Analytics writes to its memory buffer only
	devCheats: boolean, -- true: server/Dev (BotPlayers, Cheats) may load
	productIds: { [string]: number }, -- prod_<name> → Roblox developer product ID
	passIds: { [string]: number }, -- pass_<name> → Roblox game pass ID
	assetIds: { [string]: number }, -- asset name → Roblox asset ID
}

export type LiveValue = boolean | number | string

local Defaults = {}

local function environment(
	name: EnvironmentName,
	purchases: boolean,
	analytics: boolean,
	devCheats: boolean
): Environment
	return table.freeze({
		name = name,
		purchases = purchases,
		analytics = analytics,
		devCheats = devCheats,
		-- Empty until the passes and products exist in each experience; the task that creates
		-- them fills its environment's tables.
		productIds = table.freeze({}),
		passIds = table.freeze({}),
		assetIds = table.freeze({}),
	})
end

-- Section 17.1: four experiences, so data stores never mix. The section names the four switches
-- but not their value per environment; these follow from its table and the rest of the bible:
-- Studio sends no analytics (chapter 10, section 2.4), nobody can join CI, server/Dev is for dev
-- places only (section 3), and purchases are tested in Staging before Production sells them.
Defaults.environments = table.freeze({
	development = environment("development", true, false, true), -- GULP Dev: owner, in Studio
	ci = environment("ci", false, false, false), -- GULP CI: nobody can join
	staging = environment("staging", true, true, false), -- GULP Staging: owner and testers
	production = environment("production", true, true, false), -- GULP: public
})

-- The development table with all purchases disabled: what an unknown GameId gets.
Defaults.unknown = environment("development", false, false, true)

-- `game.GameId` of each experience → its environment. Empty until the four experiences exist;
-- until an ID is listed here its place runs on `Defaults.unknown`.
local GAME_IDS: { [number]: EnvironmentName } = {}
Defaults.GAME_IDS = table.freeze(GAME_IDS)

--- The environment table for `gameId` (pass `game.GameId`). An unknown ID selects the
--- development table with all purchases disabled.
function Defaults.forGame(gameId: number): Environment
	local name = Defaults.GAME_IDS[gameId]
	if name then
		return Defaults.environments[name]
	end
	return Defaults.unknown
end

-- Section 17.4: the default of every live-config key, under its final name. A key that is not
-- in this table does not exist. Sources: chapter 12, section 2.6 (the "safe value" column, under
-- the proposed names section 17.4 maps), and the chapter 09 section named on the line.
-- Later modules add their own `tune.*` keys here, with the bible's starting value.
local live: { [string]: LiveValue } = {
	-- flag.*: a feature is on or off.
	["flag.rewardedVideo"] = false, -- 12 §2.6 rewarded_video_enabled; 09 §18.3
	["flag.globalBoards"] = true, -- 12 §2.6 leaderboards_enabled
	["flag.coveVisits"] = true, -- 12 §2.6 cove_visits_enabled
	["flag.reviveOffer"] = true, -- 12 §2.6 revive_offer_enabled
	["flag.tideEvents"] = true, -- 12 §2.6 tide_events_enabled
	["flag.textChat"] = false, -- 09 §17.4 and §6.10: off

	-- kill.*: true stops the thing.
	["kill.purchases"] = false, -- 12 §2.6 purchases_enabled (true), inverted
	["kill.saves"] = false, -- 12 §2.6 saves_read_only
	-- 09 §17.4 names the next three without a value. Off is the resting state of a kill switch
	-- (the two above; 09 §20 R6 turns kill.banking on only as a fallback).
	["kill.pvp"] = false,
	["kill.callTide"] = false,
	["kill.banking"] = false,

	-- live.*: values the live team sets.
	["live.limitedTideId"] = "", -- 12 §2.6 limited_tide_id
	["live.limitedTideStart"] = "", -- 12 §2.6 limited_tide_start (a UTC time)
	["live.limitedTideEnd"] = "", -- 12 §2.6 limited_tide_end (a UTC time)
	["live.noticeTextKey"] = "", -- 12 §2.6 notice_text_key
	["live.minPlaceVersion"] = 0, -- 12 §2.6 min_place_version
	["live.shopDelaySeconds"] = 120, -- 09 §17.4; 12 §2.6 new_player_shop_delay_s

	-- tune.*: tolerances that can be widened without a release.
	["tune.bite.baseTolerance"] = 3.0, -- studs; 09 §8.9
}
Defaults.live = table.freeze(live)

return Defaults
