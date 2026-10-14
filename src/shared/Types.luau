--!strict
-- Types: every exported type used across modules (docs/09, sections 3 and 4.1). Import it with
-- `local Types = require("./Types")`. Each block below is copied from the section named above
-- it; change the bible first, then this file. No fields are invented here: a type the bible names
-- without defining (SwimInput, CreatureState, RunPhase, ...) is added by the module that owns it.
local ScreenScale = require("./Logic/ScreenScale")
local Signal = require("./Util/Signal")

-- Section 5.1: a number 1 to 24 assigned at join. It is the player's index in every buffer and
-- their cove number.
export type Slot = number

-- Section 4.2: services and controllers share one shape so the loaders can treat them alike.
-- `init` sets up private state and must not yield or call another service; `start` connects
-- events and begins loops.
export type Service = { name: string, init: () -> (), start: () -> () }

-- Section 5.1 writes events as `Signal<Player, Slot>`.
export type Connection = Signal.Connection
export type Signal<T...> = Signal.Signal<T...>

-- Section 5.2: `UserInputService.PreferredInput`, re-read on every change.
export type InputMode = "Touch" | "Keys" | "Pad"

-- Section 5.2: InputController turns raw input into one SwimInput; Sim/SwimModel consumes it.
-- Fields from chapter 02: section 1.1 (the four model values), 2.3 and 2.4 (brake), 2.1 and 2.5
-- (dash). Angles in degrees. The caller owns the table and may reuse it every frame.
export type SwimInput = {
	throttle: number, -- 0 to 1, forward thrust
	strafe: number, -- −1 to 1, sideways thrust, positive to the right (Keys and two-thumb only)
	brake: boolean, -- S or LT: forward speed relaxes to 0 at the tier's brake constant
	-- Heading: a target yaw (Keys: the camera look direction), or nil to steer by rate.
	-- Yaw uses the Roblox convention (CFrame.fromEulerAnglesYXZ): 0 faces −Z, positive turns left.
	yawTarget: number?,
	yawRate: number, -- °/s, positive turns right (02 §2.1: screen right is positive); used when yawTarget is nil
	pitchTarget: number, -- −70 to +70, positive points the nose up
	dash: boolean, -- a dash press this frame; true every frame while a held dash is held (02 §2.1)
}

-- Section 5.2: `QualityController.screenClass()`; the classes and their tests are chapter 15,
-- section 2.2, worked out in `Logic/ScreenScale`.
export type ScreenClass = ScreenScale.ScreenClass

-- Section 3.2: content data. `wire` is the row's 1-based position in the canon table.
export type Scope = "MVP" | "L" | "P1" | "P2"
export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Mythic"

export type TierDef = {
	tier: number,
	name: string,
	massNeeded: number,
	bodyScale: number,
	swimSpeed: number,
	turnRate: number,
	coveIncome: number?, -- 05 §3.3 data:CoveIncome: a specimen's base Pearls per hour; nil at tier 1
}

export type RewardBandDef = {
	id: string, -- R1 to R5 (05 §3.12)
	pearls: number,
}

-- A banking mass band (01 §5.4): `pearlsPerMass` for the mass from `from` to `upTo` (nil: no limit).
export type BankRateDef = {
	from: number,
	upTo: number?,
	pearlsPerMass: number,
}

-- A scraps share (01 §5.5): from the `fromDeath`-th death on the account (1-based) onward.
export type ScrapsDef = {
	fromDeath: number,
	share: number,
}

-- A Reef Rank (05 §7): reached at `threshold` lifetime banked Pearls; pays `reward` Pearls [L].
export type ReefRankDef = {
	rank: number,
	threshold: number,
	reward: number,
}

-- The Pearl price of a cove slot (05 §4.2); slots below the first row are free.
export type SlotPriceDef = {
	slot: number,
	price: number,
}

export type SpeciesDef = {
	id: string,
	wire: number,
	scope: Scope,
	unlockPearls: number,
	passId: string?,
	speedMult: number,
	turnMult: number,
	accelMult: number, -- 03 §1.1 Acceleration: multiplies 02 §1.3's accel, coast, brake and grip
	dashMult: number, -- 03 §1.1 Dash speed: dashSpeed = topSpeed × dashMult (02 §1.2)
	radiusMult: number,
	dashCooldown: number,
	dashDurationMult: number,
	startTier: number,
	ability: string,
}

export type PreyDef = {
	id: string,
	wire: number,
	scope: Scope,
	tier: number,
	mass: number,
	givesTrait: string?, -- trait prey only
	zones: { string },
	groupMin: number,
	groupMax: number,
	behaviour: "drift" | "swarm" | "hop" | "school" | "solo" | "run" | "pack",
	cruiseSpeed: number,
	fleeSpeed: number,
	turnRate: number, -- °/s; 0 = turns in any direction (03 §2.1, §3.1)
	fleeBurst: number, -- s; 0 = does not flee (03 §2.1, §3.1)
	fleeRadius: number,
	scatterGain: number,
	radius: number,
	wobble: number,
	eventOnly: string?,
	respawn: number?, -- s from eaten to a new group (03 §2.1, §3.1); nil for event prey
	lifetime: number?, -- trait prey: s a Crystal Jelly drift stays before it leaves (03 §3.1)
	alive: number?, -- trait prey: most alive per server at once (03 §3.1)
	eventTotal: number?, -- event prey: released in one tide event (03 §3.1)
}

export type TraitDef = {
	id: string,
	wire: number,
	scope: Scope,
	rarity: Rarity,
	incomeBonus: number, -- 0.10, 0.20, 0.35, 0.60, 1.00 (Common to Mythic, canon 9)
}

export type PredatorDef = {
	id: string,
	wire: number,
	scope: Scope,
	tier: number,
	eatsMaxTier: number,
	speed: number,
	senseRadius: number,
	strikeRadius: number,
	telegraph: number,
	giveUpAfter: number,
	rest: number,
	eatenMass: number?, -- barracuda 25, grouper 60 (canon 5.2); nil for every other predator
}

export type HazardDef = {
	id: string,
	wire: number,
	scope: Scope,
	effect: "stun" | "slow" | "burn" | "yank" | "push",
	magnitude: number,
	duration: number,
	cycle: { dormant: number, rumble: number, erupting: number }?, -- vent only (section 9.4)
}

export type ZoneDef = {
	id: string,
	wire: number,
	scope: Scope,
	preyTierMin: number,
	preyTierMax: number,
	safe: boolean,
	lightingPreset: string, -- chapter 06, section 10.2; the Drop-off's "upper" blends to "deep" by depth (10.3)
}

-- One prey in one zone (docs/09, section 3.2): 03 §2.3's weight and cap, 02 §9.6's base count
-- at 24 players on the real map, and the zone's plan area for scaling to a smaller spawn area.
-- Logic/PreySpawnMath turns these into live targets.
export type PreySpawnDef = {
	zone: string, -- data:Zones ID
	prey: string, -- data:Prey ID
	weight: number, -- share of the zone's spawn rolls; each zone's weights add to 100
	cap: number, -- most groups alive in the zone at once; doubled in a Frenzy
	base: number, -- target at 24 players on the real map, in baseUnit
	baseUnit: "groups" | "members", -- plankton motes and tuna are counted as individuals
	perPlayerInside: number?, -- Nursery only: groups added per player inside (no playerScale)
	zoneArea: number, -- the zone's plan area in studs² (03 §6.1, data:ZoneAreas)
}

-- Trait prey alive per zone (02 §9.6, data:PreyTargets): no playerScale or eventScale; areaScale
-- applies (Logic/PreySpawnMath).
export type TraitPreySpawnDef = {
	zone: string, -- data:Zones ID
	prey: string, -- data:TraitPrey ID
	alive: number, -- animals alive in the zone on the real map
	zoneArea: number, -- the zone's plan area in studs² (03 §6.1, data:ZoneAreas)
}

-- The prey motion table (06 §7.6, data:PreyMotion): client looks only. Every number is (tune).
export type PreyMotionDef = {
	id: string, -- data:Prey or data:TraitPrey ID
	scope: Scope,
	draw: string, -- "billboard", "rigid", or the rig (chapter 07, section 4.0)
	wobble: { hz: number, yawDeg: number, rollDeg: number, bobStuds: number }?,
	sway: { hz: number, ampDeg: number, hzPerStudPerS: number, tailLagS: number? }?,
	hop: { height: number, length: number, timeS: number, restS: number, count: number? }?,
	pulse: { kind: "twinkle" | "glow" | "shimmer" | "squash" | "crawl", hz: number, amount: number? }?,
	driftSpeed: number?, -- studs/s
	flee: {
		style: string,
		burstWobbleMult: number?,
		burstSwayMult: number?,
		hopMult: number?,
		regroupS: number?,
		bankDeg: number?,
		turns: number?,
		pauseS: number?,
		rollStuds: number?,
		uncurlS: number?,
		deeperStuds: number?,
		jetStuds: number?,
		inkS: number?,
	},
}

export type TideDef = {
	id: string,
	wire: number,
	scope: Scope,
	fallback: string?,
	outOfBuild: boolean?, -- slice build only: the rotation names it, the build leaves it out (09 §11.1)
	spawnRateMult: number,
	eventPrey: { string },
}

export type ProductDef = {
	id: string, -- chapter 05 purchase ID: pass_<name>, prod_<name>, pat_<species>_<name>, deco_buy_<name>
	kind: "pass" | "product", -- the Roblox ID is Config/Defaults' (per environment), never generated
	scope: Scope,
	grant: string, -- "pearls", "token", "pattern", "decoration", "flag" or "bundle"
	amount: number?,
	items: { string }?, -- pattern and decoration IDs granted; a bundle lists several
}

export type AdPlacementDef = {
	id: string, -- chapter 05 placement ID: ad_<name>
	scope: Scope,
	productId: string, -- the prod_ product it grants (section 18.3)
	perDay: number,
}

export type CodexCategoryDef = {
	id: string, -- cdx_species, cdx_tiers, cdx_traits, cdx_prey [MVP]; cdx_dangers, cdx_places, cdx_tides, cdx_all [L]
	wire: number,
	scope: Scope,
	entryPearls: { number }, -- Pearls per entry, by tier or rarity; empty when entries pay nothing
	rewardPearls: number,
	rewardDecoration: string?,
	rewardTitle: string?,
}

export type RevivePointDef = {
	id: string, -- rp_01 to rp_12 (chapter 03, section 6.11)
	wire: number,
	zone: string,
	x: number, -- world position (x, -depth, z)
	z: number,
	depth: number,
}

export type CoveMouthDef = {
	id: string, -- C01 to C24 (chapter 03, section 6.7)
	wire: number, -- the cove number, which is the slot (section 5.1)
	x: number, -- mouth centre (x, z) on the Rim's inner face
	z: number,
}

-- Chapter 03, section 6.2 data:NurseryPath: one place on the first-run route (chapter 04,
-- section 3.5). Y is up and the surface is Y 0, so depth d is Y −d.
export type NurseryPointDef = {
	id: string, -- hatch_bed, swarm_a ... home_current_mouth
	wire: number,
	at: number, -- distance along the route from the Hatch Bed; a stretch starts here
	to: number, -- where a stretch ends; `at` for a point
	x: number, -- the place (x, z); a stretch's start
	z: number,
	toX: number, -- a stretch's end; `x`, `z` for a point
	toZ: number,
	top: number, -- depth band: from `top` down to `bottom` (one depth: top = bottom)
	bottom: number,
	toBottom: number, -- the band's bottom at a stretch's end ("floor 30 down to 56")
	floor: boolean, -- `bottom` is the sea floor and the band runs up from it to the surface
	markX: number?, -- the landmark a point serves (the Glow Grotto's mouth), when it has one
	markZ: number?,
}

-- Section 9.1: gameplay volumes, read from tagged Studio parts by WorldIndex at server start and
-- kept as data. `inv` is the part's inverse frame as 12 numbers (position, then the rotation by
-- rows), so a world point turns into the part's local space with plain arithmetic.
export type ZoneId = string
-- One of the 14 `Kind` values of the section 9.1 table (VolumeMath.KINDS). A plain string: luau-lsp
-- 1.70.1 widens these singleton unions to `string` through loops and refinements.
export type VolumeKind = string
export type VolumeShape = string -- "Block", "Ball" or "Cylinder"; a Cylinder's axis is its local X
export type VolumeAttribute = string | number | boolean
export type Volume = {
	kind: VolumeKind,
	shape: VolumeShape,
	inv: { number },
	hx: number, -- half size along local X, Y, Z
	hy: number,
	hz: number,
	attrs: { [string]: VolumeAttribute }, -- the part's attributes, `Kind` included
}

-- Section 9.1: only the centre of a RevivePoint ball is kept; it is never sent to clients.
export type RevivePoint = { id: string, wire: number, x: number, y: number, z: number }

export type PatternDef = {
	id: string, -- pat_<species>_<name>, 18 at launch
	wire: number,
	scope: Scope,
	species: string,
	source: "robux" | "codex" | "starter_pack", -- chapter 03, section 1.3
}

export type DecorationDef = {
	id: string, -- 50 rows (chapter 03, section 13)
	wire: number, -- sent in CoveView
	scope: Scope,
	size: "S" | "M" | "L",
	mount: "floor" | "wall" | "ceiling",
	source: "pearls" | "rank" | "codex" | "goals" | "event" | "starter_pack" | "robux",
	price: number?, -- Pearl items: chapter 05 price
	shelf: number?, -- Pearl items: shop shelf 1 to 8
	need: number?, -- rank to reach, goals.fullDays to reach, or event count to reach
	counter: string?, -- event items: the stats.events key that is counted (section 12.2)
}

export type EmoteDef = {
	id: string, -- em_<name>
	wire: number, -- 1 to 6 is the index in EmoteAction
	scope: Scope,
}

export type RankRewardDef = { rank: number, title: string?, decoration: string?, shelf: number? } -- chapter 03, section 11

export type GoalDef = {
	id: string, -- dg_<name> (chapter 03, section 9)
	wire: number,
	scope: Scope,
	text: string,
	target: number,
	difficulty: "Easy" | "Medium" | "Hard",
	reward: string, -- R1 to R5: chapter 05's Pearl reward step
	needs: string?, -- the condition for offering it; nil when it needs nothing
	kind: string, -- the event counted (chapter 03, section 9: eat_prey, reach_tier, bank_mass …)
	subject: string?, -- prey, zone, tide or predator ID, tier, rarity or trait count; nil when none
	pool: "eat" | "grow" | "world", -- chapter 02's goal pool (section 15.3)
}

export type LandmarkDef = {
	id: string, -- lm_<name>: chapter 03's landmark IDs (sections 6.2 to 6.6)
	wire: number,
	scope: Scope,
	zone: string,
	x: number, -- found within 40 studs (cdx_places)
	z: number,
	depth: number,
	codexPlace: boolean, -- true for the 30 Places of chapter 03, section 8.2
}

-- Section 11.1: the tide phase, a pure function of Unix time (Logic/TideClock).
export type TideState = {
	phase: "calm" | "warning" | "active",
	id: string,
	startsAt: number,
	endsAt: number,
}

-- Section 12.2: save schema, version 1. Dictionary keys are always strings; arrays have no
-- holes; no NaN or infinity; no Instances or buffers. `day` fields are floor(unix / 86400).
export type SpecimenRecord = {
	id: string, -- 8-character random ID, unique within the cove
	sp: string, -- species ID
	tier: number, -- 2..7
	mass: number, -- final mass, rounded to 1 decimal
	traits: { string }, -- up to 3 trait IDs
	at: number, -- Unix seconds when banked
	pat: string?, -- pattern ID
}

export type RunSnapshot = {
	sp: string,
	pat: string?,
	mass: number,
	tier: number,
	traits: { string },
	progress: { [string]: number }, -- trait ID → trait prey eaten (0..5)
	startedAt: number,
	runSeconds: number,
	platedUsed: boolean,
	reviveUsed: boolean,
	untrusted: boolean,
	x: number, -- last accepted position, for resuming
	y: number,
	z: number,
	feedGuard: { [string]: number }, -- victim userId → times eaten in the last 10 minutes (chapter 02)
	suspendedAt: number?, -- Unix seconds; nil while the run is live on a server
	expiresAt: number?, -- suspendedAt + 300 after a disconnect, + 900 after a server shutdown (section 12.5)
	onExpiry: ("scraps" | "bank_pearls")?, -- what an expired run pays (section 12.5)
}

-- Device-shaped settings are saved once per input mode, so a phone setting never lands on a PC.
export type InputSettings = {
	scheme: string, -- 15 §2.2: "drag" or "two_thumb" [L] on touch, "keys" on keys, "pad" [L] on pad
	lookSpeed: number, -- sensitivity; on touch the drag sensitivity of "drag" (0.5 to 1.5)
	twoThumbLookSpeed: number, -- [L] touch only (0.5 to 2.0, default 1.0); unused on keys and pad
	flipY: boolean,
	graphics: "auto" | "smooth" | "balanced" | "pretty",
}

export type ProfileData = {
	v: number, -- schema version, 1
	createdAt: number,
	lastSeenAt: number,
	sessions: number,
	playSeconds: number,
	pearls: number, -- whole number, never negative
	rank: {
		points: number, -- the only Reef Rank input (section 13.4)
		claimed: number, -- [L] highest rank whose reward has been paid
		title: string?, -- [L] chosen title
	},
	species: {
		owned: { [string]: boolean },
		selected: string,
		patterns: { [string]: { string } }, -- species ID → pattern IDs owned
		equipped: { [string]: string }, -- species ID → pattern ID equipped
	},
	cove: {
		slots: number, -- 6..30 bought with Pearls; Bigger Cove adds 10 at read time
		specimens: { SpecimenRecord },
		pendingSpecimen: SpecimenRecord?, -- banked into a full cove; waits for the release choice
		pending: number, -- income pile (section 13.2)
		accruedAt: number,
		lastClaim: { amount: number, at: number }?,
		boostDay: number, -- [L] UTC day of the last Cove Boost (once a day)
		bubbles: number, -- [L] Bubbles received
		decorOwned: { [string]: boolean }, -- [L] decoration IDs owned, however they were obtained
		decor: { [string]: string }, -- [L] decorations placed: anchor ID → decoration ID
	},
	codex: {
		species: { [string]: number }, -- species ID → highest tier reached
		traits: { [string]: boolean },
		prey: { [string]: number },
		dangers: { [string]: boolean }, -- [L]
		places: { [string]: boolean }, -- [L] keyed by landmark ID (lm_<name>)
		tides: { [string]: boolean }, -- [L]
		rewards: { [string]: boolean }, -- category ID, or "cdx_tiers:<species>"
	},
	goals: {
		day: number, -- UTC day the list belongs to
		list: { { id: string, progress: number, target: number, claimed: boolean } },
		rerolls: number, -- free rerolls used today
		paidRerolls: number, -- [L] Goal Reroll products used today
		bonusClaimed: boolean, -- the all-three bonus
		fullDays: number, -- [L] lifetime days with all three goals done (at most +1 a day)
	},
	streak: { day: number, count: number }, -- [L] count is never reset
	stats: {
		runs: number,
		banks: number,
		deaths: number,
		bites: number,
		playersEaten: number,
		bestMass: number,
		bestTier: number,
		gullDodges: number, -- lifetime Gull dives dodged
		breaches: number, -- lifetime breaches (entries into Airborne)
		bubblesGiven: number, -- [L] lifetime Bubbles left on other coves
		events: { [string]: number }, -- [L] lifetime event-task counters; a missing key reads as 0
	},
	newcomer: {
		firstDeath: boolean, -- true once the account has died
		biteAbsorbed: boolean, -- the one absorbed player bite has been used (section 10.2)
		runsCompleted: number, -- runs ended by a bank, a gulp or an expiry
		shieldUsed: number, -- seconds of the first-run shield already used
	},
	passes: { [string]: boolean }, -- pass_<name> → last answer from Roblox
	tokens: { revive: number, trait_lock: number, call_tide: number, goal_reroll: number },
	traitLock: { traits: { string } }?, -- [L] applied and cleared at the next run start
	purchases: {
		receipts: { string }, -- last 100 PurchaseIds, oldest dropped first
		starterPack: boolean,
		robuxSpent: number,
		packDay: number,
		packsToday: number, -- Pearl packs bought today (chapter 05 owns the cap)
	},
	ads: { day: number, counts: { [string]: number } }, -- [L] rewarded videos watched today, by ad_<name>
	offers: { [string]: number }, -- offer ID → UTC day last dismissed (chapter 05, section 9)
	social: { bubbleDay: number, bubbledUserIds: { number } }, -- [L] coves given a Bubble today
	board: { week: number, weekBest: number }, -- [L] avoids reads before writes
	ftue: {
		stage: number, -- tutorial state (chapter 04)
		completed: boolean,
		version: number, -- tutorial version the account saw, currently 1
		attempts: number, -- +1 each time the tutorial restarts before the first bank
	},
	ab: { [string]: string }, -- experiment key → arm, copied at first exposure
	settings: {
		sfx: number, -- 0..10
		music: number, -- 0..10
		colourBlind: boolean,
		reduceMotion: boolean?, -- nil = follow the device
		vibration: boolean,
		tapNotHold: boolean,
		leftHanded: boolean, -- [L]
		biggerText: boolean, -- [L]
		language: string, -- [L]; "" = same as Roblox
		interfaceSize: number, -- [L]
		swapSticks: boolean, -- [L]
		hideEmotes: boolean, -- [L]
		input: { touch: InputSettings, keys: InputSettings, pad: InputSettings },
		lastGoodTier: { [string]: string }, -- [L] screen class → graphics tier (chapter 15, section 6)
	},
	moderation: { kicks: number, flags: number },
	run: RunSnapshot?, -- present only while a run is unsettled: live on a server, or suspended
}

local Types = {}

return Types
