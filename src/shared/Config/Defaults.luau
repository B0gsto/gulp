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
	mockData: boolean, -- true: DataService runs on ProfileStore.Mock, never the real store
	analytics: boolean, -- false: Analytics writes to its memory buffer only
	devCheats: boolean, -- true: server/Dev (BotPlayers, Cheats) may load
	productIds: { [string]: number }, -- prod_<name> → Roblox developer product ID
	passIds: { [string]: number }, -- pass_<name> → Roblox game pass ID
	assetIds: { [string]: number }, -- asset name → Roblox asset ID
}

export type LiveValue = boolean | number | string

local Manifest = require("../Data/Manifest")

local Defaults = {}

-- Asset IDs come from the asset manifest (docs/07, sections 1.3 and 16): `assets/manifest.csv`,
-- copied into Config/AssetManifest by `lune run tools/gen/manifest`. An uploaded asset belongs
-- to the creator, not to one experience, so every environment starts from the same IDs; an
-- environment that ever needs a different file for a name overrides it in its own table.
local MANIFEST_ASSET_IDS = table.freeze(Manifest.assetIds(Manifest.load()))

local function environment(
	name: EnvironmentName,
	purchases: boolean,
	mockData: boolean,
	analytics: boolean,
	devCheats: boolean
): Environment
	return table.freeze({
		name = name,
		purchases = purchases,
		mockData = mockData,
		analytics = analytics,
		devCheats = devCheats,
		-- Product and pass IDs are empty until they exist in each experience; the task that
		-- creates them fills its environment's tables.
		productIds = table.freeze({}),
		passIds = table.freeze({}),
		assetIds = MANIFEST_ASSET_IDS,
	})
end

-- Section 17.1: four experiences, so data stores never mix. The section names the switches but
-- not every value per environment; these follow from its table and the rest of the bible:
-- development and CI use Mock data and the real store is only staging's and production's,
-- Studio sends no analytics (chapter 10, section 2.4), nobody can join CI, server/Dev is for dev
-- places only (section 3), and purchases are tested in Staging before Production sells them.
-- Columns: purchases, mockData, analytics, devCheats.
Defaults.environments = table.freeze({
	development = environment("development", true, true, false, true), -- GULP Dev: owner, in Studio
	ci = environment("ci", false, true, false, false), -- GULP CI: nobody can join
	staging = environment("staging", true, false, true, false), -- GULP Staging: owner and testers
	production = environment("production", true, false, true, false), -- GULP: public
})

-- The development table with all purchases disabled: what an unknown GameId gets (a place file
-- opened in Studio has GameId 0, so Studio runs as development).
Defaults.unknown = environment("development", false, true, false, true)

-- `game.GameId` of each experience → its environment. An experience that is not listed yet runs
-- on `Defaults.unknown`. GULP CI is tools/cloud/target.json's universe.
local GAME_IDS: { [number]: EnvironmentName } = {
	[10770882807] = "development", -- GULP Dev (place 93549306834616)
	[10770882319] = "ci", -- GULP CI (place 86401799950889)
	[10770883054] = "staging", -- GULP Staging (place 104247046146910)
	-- GULP (production): its universe ID goes here as `"production"` at launch.
}
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

	-- tune.quality.*: JSON `{ Smooth, Balanced, Pretty }` per key (09 §17.4), the per-tier
	-- numbers of 09 §15.1. Read with Flags.tiers.
	["tune.quality.preyMeshes"] = '{"Smooth":80,"Balanced":150,"Pretty":250}', -- 09 §8.8, §15.1
	["tune.quality.preyMeshDistance"] = '{"Smooth":150,"Balanced":250,"Pretty":350}', -- studs
	["tune.quality.preyVisible"] = '{"Smooth":250,"Balanced":400,"Pretty":800}',
	["tune.quality.farPreyEmitters"] = '{"Smooth":30,"Balanced":60,"Pretty":60}',
	["tune.quality.particleEmitters"] = '{"Smooth":40,"Balanced":80,"Pretty":150}',
	["tune.quality.outlinesEdible"] = '{"Smooth":8,"Balanced":20,"Pretty":20}', -- 09 §8.8
	["tune.quality.outlinesDangerous"] = '{"Smooth":4,"Balanced":10,"Pretty":10}',
}
Defaults.live = table.freeze(live)

-- The swim model's numbers that are not in the generated data tables (Sim/SwimModel). Every
-- value is chapter 02's or the canon's, marked (tune) there; the section is on the line. Tier
-- speed and turn rate come from Data/Generated/Tiers, species multipliers from Species.
export type SwimTierTuning = { accel: number, coast: number, brake: number, grip: number }

Defaults.swim = table.freeze({
	-- 02 §1.3: forward and lateral relaxation constants (1/s) by tier, index = tier.
	byTier = table.freeze({
		table.freeze({ accel = 9.0, coast = 2.6, brake = 7.8, grip = 12 }),
		table.freeze({ accel = 8.5, coast = 2.5, brake = 7.5, grip = 11 }),
		table.freeze({ accel = 8.0, coast = 2.4, brake = 7.2, grip = 10 }),
		table.freeze({ accel = 7.0, coast = 2.2, brake = 6.6, grip = 9 }),
		table.freeze({ accel = 6.0, coast = 2.0, brake = 6.0, grip = 8 }),
		table.freeze({ accel = 5.0, coast = 1.8, brake = 5.4, grip = 7 }),
		table.freeze({ accel = 4.0, coast = 1.6, brake = 4.8, grip = 6 }),
	} :: { SwimTierTuning }),
	strafeMult = 0.6, -- 02 §1.3: strafeTarget = topSpeed × 0.6 × strafe
	stopSpeed = 0.5, -- 02 §1.3: below this with no thrust input, speed = 0
	turnGain = 10, -- 02 §1.4: angular speed = clamp(error × 10, ±turnRate)
	pitchLimit = 70, -- 02 §1.4: degrees, every control scheme
	dashDuration = 0.35, -- canon 5.3; 02 §7.1: 0.35 × (dashDurationMult + 0.3 per Longfin)
	dashLongfinAdd = 0.3, -- 02 §7.1
	dashAccel = 30, -- 02 §7.1: forward relaxation constant (1/s) while Dashing
	dashTurnMult = 0.5, -- 02 §1.4 and §7.1
	inputBuffer = 0.25, -- 02 §2.5: a blocked dash press fires if the block ends within this
	currentMult = 0.6, -- 02 §1.2: a current adds 0.6 × tierSpeed along the stream
	breachSpeed = 8, -- 02 §1.7: upward speed needed to breach; below it the creature skims
	skimDepth = 0.5, -- 02 §1.7: skim at Y = −0.5 × collision radius
	collisionRadius = 0.9, -- 02 §0.2: collision radius = 0.9 × bodyScale × radiusMult
	gravity = 80, -- 02 §1.7: studs/s² in the air; the project files set Workspace.Gravity to the same 80 (09 §6.5)
	airTurnMult = 0.3, -- 02 §1.4 and §1.7
	minAirTime = 0.2, -- 02 §1.7
	reentryMult = 0.8, -- 02 §1.7: velocity × 0.8 on re-entry
})

-- The control schemes' numbers (Logic/InputMath, client InputController). Chapter 02 section 2
-- and chapter 15 sections 3.1, 3.3 and 5.1. Drag lengths are rpx (02 §2, 08 §1.2): reference-canvas
-- pixels, converted from device px with the interface scale; mouse look is in device px (02 §2.3).
Defaults.input = table.freeze({
	dragDeadZone = 14, -- 02 §2.1: rpx radius; inside it throttle 0 and no turn
	dragFull = 80, -- 02 §2.1: rpx from the origin for full deflection, at sensitivity 1
	dragClamp = 100, -- 02 §2.1: rpx; past it the origin trails the finger
	dragSensitivity = 1.0, -- 02 §2.1, 08 §6.7: default; divides dragFull
	dragSensitivityMin = 0.5,
	dragSensitivityMax = 1.5,
	curveExponent = 1.4, -- 02 §2.1: curve(v) = sign(v) × |v|^1.4
	autoLevelBand = 0.15, -- 02 §2.1: a drag with |y| < 0.15 levels the creature
	autoLevelRate = 90, -- 02 §2.1: °/s back to level with no touch
	autoLevelDelay = 0.4, -- 02 §2.1: s after the touch lifts
	mouseDegPerPx = 0.20, -- 02 §2.3, 15 §3.3: look, ° per px × look speed
	mouseLookSpeed = 1.0, -- 15 §3.3: default; range 0.2 to 3.0
	mouseLookSpeedMin = 0.2,
	mouseLookSpeedMax = 3.0,
})

-- The rule numbers of shared/Logic (task S4-C3) that the bible gives in prose or formulas, not in
-- a data table. Table values are generated instead: cove base income per tier (05 §3.3
-- data:CoveIncome, in Tiers), reward bands (05 §3.12 data:RewardBands), banking bands (canon 5.4
-- data:BankRates), scraps shares (canon 5.5 data:Scraps) and slot prices (05 §4.2
-- data:SlotPrices). All (tune).

-- Logic/BiteRules: canon 5.2; 02 §4.2, §4.4, §6.1, §6.6.
Defaults.bite = table.freeze({
	playerGain = 0.30, -- canon 5.2: eating a player gives 30% of the victim's mass
	repeatGuardSeconds = 90, -- 02 §4.2 check 7, §6.1 rule 7
	feedGuardSeconds = 600, -- 02 §6.6: repeats of the same victim within 10 minutes
	feedGuard = table.freeze({ 1, 0.5, 0.25 }), -- 02 §4.4: by eats before; 0 from the fourth
	nurseryMaxTier = 2, -- canon 5.2, 02 §0.5: tier 3 or higher cannot enter the Nursery
	nurseryShare = table.freeze({ 1, 0.5 }), -- 02 §4.4: Nursery prey to tier 1, tier 2; else 0
})

-- Logic/TraitRules: canon 9; 02 §8.1, §8.4.
Defaults.traits = table.freeze({
	slots = 3, -- canon 9
	pips = 5, -- 02 §8.1
	pipsKeenNose = 4, -- 02 §8.1: with the Keen Nose pass [L]
	stripesSpeed = 1.08, -- canon 9, 02 §8.4: topSpeed ×1.08
	spotsMass = 0.10, -- canon 9, 02 §8.4: +10% mass from prey and trait prey
	bonefedMass = 0.25, -- canon 9, 02 §8.4: +25% mass from every source
	crystalBank = 1.5, -- canon 9, 02 §8.4, 05 §3.1: bank Pearls ×1.5
	longfinDash = 0.30, -- canon 9, 02 §8.4: dash length +30%
	spinyDefence = 1, -- canon 9, 02 §0.4: the eat gap is 2 instead of 1
})

-- Logic/BankMath: 02 §0.7, §11.4; 05 §3.1. The mass bands and rates (canon 5.4 data:BankRates)
-- and the scraps shares (canon 5.5 data:Scraps) are generated, not here.
Defaults.bank = table.freeze({
	deepPockets = 2, -- 05 §3.1: ×2 with the Deep Pockets pass
	armedMass = 1, -- 02 §0.7: a run is armed for banking once mass ≥ 1
	specimenTier = 2, -- canon 5.4, 02 §11.4
})

-- Logic/CoveIncome: canon 11; 02 §11.5, §13.3; 05 §3.4, §3.10.
Defaults.cove = table.freeze({
	capHours = 8, -- canon 11, 05 §3.4
	capHoursTideWatcher = 24, -- 05 §3.4: with the Tide Watcher pass [L]
	boostHours = 2, -- 05 §3.4: Cove Boost [L]
	refundMin = 5, -- 05 §3.10: release refund floor
	awayMinSeconds = 600, -- 02 §13.3: "While you were away" card after 10 minutes away
	awayMinPearls = 10, -- 02 §13.3: and 10 Pearls earned
	biggerCoveSlots = 10, -- 05 §4.2: Bigger Cove adds 10 on top, at read time (09 §12.2)
	gap = table.freeze({ -290, 290 }), -- 03 §6.2: Little Arch, "the Gap" (X, Z); 04 §5.5 measures from it
	returningPool = 20, -- 04 §5.5, 09 §13.1: a returning player's cove is among the 20 nearest the Gap
})

-- Logic/NurseryRoute: the first-run route and its volumes (03 §6.2 data:NurseryPath; 04 §3.5).
Defaults.nursery = table.freeze({
	arcRadius = 140, -- 03 §6.2: inside the Nursery the route is one arc of radius 140
	arcTurn = 45, -- 03 §6.2: turning 45° to the left (degrees), from facing east at the Hatch Bed
	archWidth = 50, -- 03 §6.2: Little Arch's opening is 50 wide (the Gap and its kelp curtain)
	channelWidth = 36, -- 04 §3.5: the channel (the Elbow) is 36 wide
	curtainThickness = 2, -- 03 §6.2 (tune): the kelp curtain volume, across the arch's Nursery end
	markerSize = 4, -- 03 §6.2 (tune): a point's Ball, and the trail's cross-section
})

-- Logic/TideClock: canon 10; 02 §14.1; 09 §11.1.
Defaults.tides = table.freeze({
	slot = 900, -- canon 10: an event every 15 minutes on the UTC quarter hour
	active = 240, -- canon 10: each lasts 4 minutes
	warn = 60, -- canon 10: with a 60-second warning
	rotation = table.freeze({ "frenzy", "moon_tide", "frenzy", "whale_fall" }), -- canon 10: :00 :15 :30 :45
	flexSlot = 3, -- canon 10: after launch the :30 slot is the flexible one
})

-- Logic/GoalRules: 02 §15.3; 05 §3.5, §3.7.
Defaults.goals = table.freeze({
	rankStep = 0.1, -- 05 §3.7: rankMultiplier = 1 + 0.1 × (rank − 1)
	maxRank = 50, -- 05 §3.7: the multiplier stops at rank 50
	allDoneBand = "R1", -- 05 §3.5: the bonus for finishing all three
	rerolls = table.freeze({ free = 1, video = 1, product = 3 }), -- 02 §15.3, 05 §3.5: per day
})

-- Logic/RunRules and RunLoopService: canon 5.5; 02 §0.7, §5.1, §12; 09 §6.3, §6.8.
Defaults.run = table.freeze({
	gulpCardSeconds = 1.2, -- 02 §12.1: the gulp card, and so "Swim again", comes up at T+1.20
	respawnFadeOutSeconds = 0.3, -- 02 §12.4: the client's fade out after the tap; moved while black
	respawnFadeInSeconds = 0.3, -- 02 §12.4: then the fade in; released when it ends
	respawnTargetSeconds = 0.8, -- 02 §12.4: control again within 0.8 s of the tap
	respawnSeconds = 2.0, -- 09 §6.3 Gulped row: the budget from the tap (canon limit 3 s)
	respawnGraceSeconds = 2, -- 09 §6.3: MovementValidator.grace(slot, 2) after a respawn or a return
	tierGraceSeconds = 0.5, -- 09 §6.8: MovementValidator.grace(slot, 0.5) on a tier change
	tierUpProtectSeconds = 1.0, -- 02 §5.1: Protected(tierUp), T+0.00 to T+1.00
	returnProtectSeconds = 3, -- 09 §6.3, canon 5.5: Protected for 3 s after a revive or a resume
	returnClearRadius = 60, -- 09 §6.3 return rule: nothing that can eat it within 60 studs
	suspendSeconds = 300, -- canon 5.5, 09 §12.5: a run suspended by a disconnect waits 5 minutes
	shutdownSuspendSeconds = 900, -- 09 §12.5: a run suspended by a shutdown (or a crash) waits 15
})

-- Logic/SaveSchema and DataService: the starting values of a new save (09 §12.2) and the save
-- limits of 09 §12.2 and §12.4. Values the bible does not state are marked "ours".
Defaults.save = table.freeze({
	maxBytes = 200000, -- 09 §12.2: DataService refuses to save, and logs an error, above 200 kB
	forcedSaveGap = 30, -- 09 §12.4: at most one forced save per player per 30 s
	joinTimeout = 20, -- 09 §12.4: kick after 20 s without a profile
	starterSpecies = "minnow", -- canon §7: the free starter species
	coveSlots = 6, -- 05 §4.2: slots 1 to 6 are free
	sfx = 8, -- 08 §6.7 settings table: Sounds 8
	music = 6, -- 08 §6.7: Music 6
	interfaceSize = 1.0, -- 08 §6.7 [L]
	lookSpeed = 1.0, -- 15 §3.1, §3.3: drag sensitivity, mouse and pad look speed all start at 1.0
	twoThumbLookSpeed = 1.0, -- 09 §12.2, 15 §3.1 [L]
	ftueVersion = 1, -- 09 §12.2: the tutorial version, currently 1
})

return Defaults
