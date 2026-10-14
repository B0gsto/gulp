--!strict
-- Types: every exported type used across modules (docs/09, sections 3 and 4.1). Import it with
-- `local Types = require("./Types")`. Each block below is copied from the section named above
-- it; change the bible first, then this file. No fields are invented here: a type the bible names
-- without defining (SwimInput, CreatureState, RunPhase, ...) is added by the module that owns it.
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
}

export type SpeciesDef = {
	id: string,
	wire: number,
	scope: Scope,
	unlockPearls: number,
	passId: string?,
	speedMult: number,
	turnMult: number,
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
	fleeRadius: number,
	scatterGain: number,
	radius: number,
	wobble: number,
	eventOnly: string?,
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

export type TideDef = {
	id: string,
	wire: number,
	scope: Scope,
	fallback: string?,
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
	scheme: string, -- "drag" or "two_thumb" [L] on touch; one scheme on keys and pad
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
