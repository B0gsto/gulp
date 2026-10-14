--!strict
-- FtueRules: the pure stage machine of the first-time script (task S6-C2, module B31; docs/04,
-- sections 3.1, 3.6, 3.7, 4, 5.4, 6.1 and 9; docs/09, sections 12.2 and 12.5; docs/10, section 3.1).
-- The tutorial director feeds it events and performs the actions it returns. Every number comes
-- from the config table passed in (Config/FtueConfig's shape), never from this file.
--
--   FtueRules.new(cfg, join)          → state, actions   at join (fresh, restart or resume)
--   FtueRules.handle(cfg, state, ev)  → state, actions   for every event; `state` is not changed,
--                                                        the returned one is a new table
--
-- Stages (04 §3.1), saved as `ftue.stage` (09 §12.2):
--   0 S0_LOADING ─loadingDone─▶ 1 S1_HATCH ─controlGained─▶ 2 S2_FIRST_BITE ─preyEaten─▶
--   3 S3_GROW ─tierReached ≥ 2─▶ 4 S4_TRAIT ─traitGained, or T = 70 with input in the last 10 s─▶
--   5 S5_CALL_HOME ─crossedGap─▶ 6 S6_CHASE ─chaseEnded─▶ 7 S7_CURRENT ─enteredCoveMouth─▶
--   8 S8_BANK ─fryHatched─▶ 9 S9_COVE ─leftCoveMouth─▶ 10 S10_RUN2 ─runEnded─▶ 11 DONE
--   `retreated` in S6 goes back to S5 (04 §5.4). `enteredCoveMouth` banks from S5, S6 or S7
--   (04 §9: after S5 a bank by any route completes the FTUE). `completeFtue` is returned at the
--   end of S8 (04 §3.1).
--
-- Events (`Event.kind`, with the fields each carries):
--   loadingDone                the minimum set is ready and the loading screen exits
--   touch { drag }             one discrete input: drag = true is a steering input (a drag of
--                              0.2 s or more, a movement key, a stick), drag = false a tap
--   controlGained              the first frame where input moves the creature (T = 0)
--   preyEaten { group }        a bite landed; `group` is the scripted group the prey came from
--                              (the `id` of a spawn action, e.g. "swarmA", "glowfry"), nil if wild
--   massChanged { mass }       tierReached { tier }       traitGained { trait }
--   moved { towardGap, inCurrent, coveDistance }   the director's sensor report, any rate:
--                              moved closer to the Gap since the last report, inside the Home
--                              Current, studs from the own cove mouth. Missing fields keep the
--                              last value.
--   crossedGap                 left the Nursery through the Gap
--   dashed { auto }            a dash; auto = true for the one `autoDash` asked for
--   retreated                  swam back into the Nursery during the chase
--   chaseEnded { assisted }    the chase is over (the Barracuda gave up, or the Home Current was
--                              reached; in the `escort` arm, the end of the channel); assisted =
--                              any 04 §5.4 help besides the auto-dash (shove, fling)
--   enteredCoveMouth           the server confirmed the first bank at the own cove
--   fryHatched                 the new Fry has control in the cove
--   leftCoveMouth              the new Fry left the cove mouth (run 2 starts)
--   runEnded                   run 2 ended, by bank or gulp
--   backgrounded               the app went to the background (04 §3.7: hold at once)
--   tick { dt, hadInput }      time passes; hadInput = any input (tap or steering) during dt
--
-- Actions (`Action.kind`, with the fields each carries):
--   Flow
--     hatch { seconds }        play the hatch (S1)
--     giveControl              end the hatch and give control; the director answers controlGained
--     completeFtue             save `ftue.completed = true` (end of S8)
--     restart { value }        save `ftue.attempts = value` and `ftue.stage = 0` (04 §9)
--     hold { on }              04 §3.7 hold: freeze, scripted prey idles nearby, music low-pass
--   Scripted prey (the director maps these to PreyService.spawnScripted / clearScripted)
--     spawnSwarmA { id, count, distance, radius = drift radius, speed = drift speed,
--                   limit = follow limit, width }
--     spawnTrail { id, count, distance = first mote, spacing }
--     spawnSwarmB { id, count, distance }
--     keepKrill { count, radius }        keep at least `count` scripted krill within `radius`
--     spawnGlowfry { id, count, speed, radius = circle radius, distance = the Grotto, trait }
--     spawnBurst { id, count, distance = ahead }   krill that swim into the mouth
--     spawnLure { id }                    a krill swarm drifting along the home trail ("home") or
--                                         past the cove mouth ("cove")
--     homePrey { id, speed, radius? }     scripted prey of group `id` ("swarmA", "krill",
--                                         "glowfry") homes on the mouth; radius nil = the group
--     feedNearest                         the nearest scripted krill pulses and swims into the mouth
--     stopHoming { id }                   end a homing fail-safe
--     denseKrill { count, radius, seconds }   run 2's dense krill at the cove mouth
--     clearScripted                       remove every scripted prey of this player
--   Presentation
--     prompt { id, show, mode? }          id: "ghostThumb" (mode "long" for the replay), "pips",
--                                         "homeTrail", "dashPulse"
--     hud { id }                          first appearance: "massBar", "dashButton", "traitSlot",
--                                         "homeMarker", "goalsChip"
--     pulse { id }                        "target" (the beat's target), "homeMarker" (also
--                                         brightens the trail), "trail", "coveMouth"
--     music { id }                        "pluck", "percussion", "pad", "dropPercussion"
--     openFog                             openCurtain             predatorShadow
--     startChase { mode }                 autoDash                startCurrent { mode }
--     reformCurrent                       a Home Current branch re-forms at the player
--     pull { id, speed }                  a current toward "gap" (home_push) or "cove" (B9)
--     bankSequence                        play 04 §6.1 from 0.0 to the new Fry
--     coveItem { id, ping }               "firstTick", "species", "tide", "mouth"; ping = shown as a
--                                         HUD ping in open water because the player left early
--     exitTrail { distance }              a bubble trail out of the cove mouth
--   Analytics (the director passes these to Analytics; chapter 10 owns the events)
--     step { step }                       onboarding funnel step number (10 §3.1). Steps 1, 3 to 13,
--                                         16 to 19 come from here; 2 (loading screen) is the
--                                         loading script's, 14 and 15 are CoveService's and
--                                         EconomyService's (specimen placed, first tick paid), 20
--                                         is run 3's
--     failsafe { ctx }                    `ftue_failsafe` (once each per state)
--     milestone { id, t }                 `ftue_milestone` raw: id "bite", "tier2", "trait", "bank"
--                                         at T = t; Analytics buckets it into ctx
--     biteAssist { t }                    `ftue_bite_assist`: the first bite came before any input
--     chaseResult { result, value }       `ftue_chase_result`, value = manual dashes
--
-- Clocks: `t` is T (seconds since control, 04 short names) and never stops; `clock` is the beat
-- clock, which freezes during a hold (04 §3.7). Every "T = n" fail-safe reads the beat clock.
-- Pure: no `game`, no Instances, so it runs in Lune.

local FtueConfig = require("../Config/FtueConfig")

export type Config = FtueConfig.Config
export type Form = "full" | "fast" | "short"

export type EventKind =
	"loadingDone"
	| "touch"
	| "controlGained"
	| "preyEaten"
	| "massChanged"
	| "tierReached"
	| "traitGained"
	| "moved"
	| "crossedGap"
	| "dashed"
	| "retreated"
	| "chaseEnded"
	| "enteredCoveMouth"
	| "fryHatched"
	| "leftCoveMouth"
	| "runEnded"
	| "backgrounded"
	| "tick"

export type Event = {
	kind: EventKind,
	dt: number?,
	hadInput: boolean?,
	drag: boolean?,
	group: string?,
	mass: number?,
	tier: number?,
	trait: string?,
	towardGap: boolean?,
	inCurrent: boolean?,
	coveDistance: number?,
	auto: boolean?,
	assisted: boolean?,
}

export type ActionKind =
	"hatch"
	| "giveControl"
	| "completeFtue"
	| "restart"
	| "hold"
	| "spawnSwarmA"
	| "spawnTrail"
	| "spawnSwarmB"
	| "keepKrill"
	| "spawnGlowfry"
	| "spawnBurst"
	| "spawnLure"
	| "homePrey"
	| "feedNearest"
	| "stopHoming"
	| "denseKrill"
	| "clearScripted"
	| "prompt"
	| "hud"
	| "pulse"
	| "music"
	| "openFog"
	| "openCurtain"
	| "predatorShadow"
	| "startChase"
	| "autoDash"
	| "startCurrent"
	| "reformCurrent"
	| "pull"
	| "bankSequence"
	| "coveItem"
	| "exitTrail"
	| "step"
	| "failsafe"
	| "milestone"
	| "biteAssist"
	| "chaseResult"

export type Action = {
	kind: ActionKind,
	id: string?,
	show: boolean?,
	on: boolean?,
	mode: string?,
	ping: boolean?,
	step: number?,
	ctx: string?,
	result: string?,
	trait: string?,
	t: number?,
	value: number?,
	count: number?,
	distance: number?,
	spacing: number?,
	speed: number?,
	radius: number?,
	width: number?,
	limit: number?,
	seconds: number?,
}

--- The suspended run being resumed (09 §12.5): from `RunSnapshot` `runSeconds`, `mass`, `tier`
--- and the first trait's entry in `progress`.
export type Run = { seconds: number, mass: number, tier: number, traitProgress: number }

--- What the server knows at join (09 §12.2 `ftue`, §12.5 `run`).
export type Join = {
	stage: number, -- saved `ftue.stage`
	completed: boolean, -- saved `ftue.completed`
	attempts: number, -- saved `ftue.attempts`
	banked: boolean, -- `stats.banks > 0`
	run: Run?, -- the suspended run being resumed (09 §12.5, never-banked row), nil if none
}

export type State = {
	stage: number,
	form: Form,
	completed: boolean,
	t: number, -- T: seconds since control
	clock: number, -- the beat clock: T less the time held
	stageTime: number, -- beat seconds since the stage was entered (real seconds in S1)
	idle: number, -- seconds since the last input
	held: boolean,
	dragged: boolean, -- a steering input has been seen (onboarding step 04)
	ghost: string, -- "none", "intro" (S2 from T = 0) or "idle" (04 §3.7)
	pulsed: boolean, -- the 8 s idle pulse fired in this idle spell
	fed: boolean, -- S3: the 8 s feed fired in this idle spell (04 §3.6 B3)
	taps: number, -- taps since the last drag (04 §3.6 B2)
	pendingBite: boolean, -- step 05 held until the first input (10 §3.1)
	mass: number,
	tier: number,
	glowfry: number, -- scripted trait prey eaten
	noProgress: number, -- S5: seconds without moving toward the Gap since the curtain opened
	nudged: boolean, -- S5: the 8 s nudge fired in this stall
	retreatAt: number?, -- S5 after a retreat: stageTime of the return
	chaseRuns: number,
	manualDashes: number,
	autoDashed: boolean,
	inCurrent: boolean,
	coveDistance: number,
	outside: number, -- S7: seconds outside the Home Current
	nearCove: number, -- S7: seconds within the pull radius without entering
	bankTime: number, -- seconds since the bank (S8 onward)
	leftCove: boolean,
	coveItem: number, -- cove items fired so far
	lastPingAt: number?, -- bankTime of the last cove item shown as a ping
	run2Homing: boolean,
	fired: { [string]: boolean },
}

local FtueRules = {}

--- The stages of 04 §3.1 as saved in `ftue.stage` (09 §12.2).
FtueRules.Stage = table.freeze({
	S0_LOADING = 0,
	S1_HATCH = 1,
	S2_FIRST_BITE = 2,
	S3_GROW = 3,
	S4_TRAIT = 4,
	S5_CALL_HOME = 5,
	S6_CHASE = 6,
	S7_CURRENT = 7,
	S8_BANK = 8,
	S9_COVE = 9,
	S10_RUN2 = 10,
	DONE = 11,
})
local S = FtueRules.Stage

-- Stage n is at index n + 1.
local NAMES = table.freeze({
	"S0_LOADING",
	"S1_HATCH",
	"S2_FIRST_BITE",
	"S3_GROW",
	"S4_TRAIT",
	"S5_CALL_HOME",
	"S6_CHASE",
	"S7_CURRENT",
	"S8_BANK",
	"S9_COVE",
	"S10_RUN2",
	"DONE",
})

-- 04 §3.7: the stages the idle hold applies in. Not S1 (the hatch ends by itself), S6 (the chase
-- has its own rules, 04 §5.4) or S8 (control is suspended at the bank).
local HOLDABLE: { [number]: boolean } = table.freeze({
	[S.S2_FIRST_BITE] = true,
	[S.S3_GROW] = true,
	[S.S4_TRAIT] = true,
	[S.S5_CALL_HOME] = true,
	[S.S7_CURRENT] = true,
	[S.S9_COVE] = true,
	[S.S10_RUN2] = true,
})

-- The cove items of 04 §6.1, in order.
local COVE_ITEMS = table.freeze({ "firstTick", "species", "tide", "mouth" })

function FtueRules.stageName(stage: number): string
	return NAMES[stage + 1] or "?"
end

local function emit(out: { Action }, action: Action)
	table.insert(out, action)
end

local function copy(s: State): State
	local c = table.clone(s)
	c.fired = table.clone(s.fired)
	return c
end

-- True the first time `key` is asked for; false after.
local function once(s: State, key: string): boolean
	if s.fired[key] then
		return false
	end
	s.fired[key] = true
	return true
end

local function step(s: State, out: { Action }, n: number)
	if once(s, "step" .. n) then
		emit(out, { kind = "step", step = n })
	end
end

local function failsafe(s: State, out: { Action }, ctx: string)
	if once(s, "failsafe_" .. ctx) then
		emit(out, { kind = "failsafe", ctx = ctx })
	end
end

local function milestone(s: State, out: { Action }, id: string)
	if once(s, "milestone_" .. id) then
		emit(out, { kind = "milestone", id = id, t = s.t })
	end
end

-- 04 §9: the fast form halves every idle timer.
local function idleScale(cfg: Config, s: State): number
	return if s.form == "fast" then cfg.idle.fastScale else 1
end

local function formOf(cfg: Config, attempts: number): Form
	if attempts >= cfg.returning.shortFromAttempt then
		return "short"
	elseif attempts >= cfg.returning.fastFromAttempt then
		return "fast"
	end
	return "full"
end

local function hatchSeconds(cfg: Config, s: State): number
	if cfg.arms.hatchIntro == "instant" then
		return 0
	end
	return if s.form == "full" then cfg.hatch.seconds else cfg.hatch.fastSeconds
end

-- How many times S6 may run its chase (04 §5.4, §9). The `escort` arm runs S6 once with no
-- predator; the short form never does.
local function maxChaseRuns(cfg: Config, s: State): number
	if s.form == "short" then
		return 0
	elseif cfg.arms.chaseMode == "escort" then
		return 1
	end
	return if s.form == "fast" then cfg.chase.fastMaxRuns else cfg.chase.maxRuns
end

local function blank(form: Form): State
	return {
		stage = S.S0_LOADING,
		form = form,
		completed = false,
		t = 0,
		clock = 0,
		stageTime = 0,
		idle = 0,
		held = false,
		dragged = false,
		ghost = "none",
		pulsed = false,
		fed = false,
		taps = 0,
		pendingBite = false,
		mass = 0,
		tier = 1,
		glowfry = 0,
		noProgress = 0,
		nudged = false,
		retreatAt = nil,
		chaseRuns = 0,
		manualDashes = 0,
		autoDashed = false,
		inCurrent = false,
		coveDistance = math.huge,
		outside = 0,
		nearCove = 0,
		bankTime = 0,
		leftCove = false,
		coveItem = 0,
		lastPingAt = nil,
		run2Homing = false,
		fired = {},
	}
end

local function giveControl(s: State, out: { Action })
	if once(s, "giveControl") then
		emit(out, { kind = "giveControl" })
	end
end

local function spawnSwarmA(cfg: Config, out: { Action })
	emit(out, {
		kind = "spawnSwarmA",
		id = "swarmA",
		count = cfg.feed.swarmACount,
		distance = cfg.layout.swarmA,
		width = cfg.layout.swarmAWidth,
		radius = cfg.feed.driftRadius,
		speed = cfg.firstBite.followSpeed,
		limit = cfg.firstBite.followLimit,
	})
end

local function spawnGlowfry(cfg: Config, s: State, out: { Action })
	local left = cfg.arms.traitCount - s.glowfry
	if left > 0 then
		emit(out, {
			kind = "spawnGlowfry",
			id = "glowfry",
			count = left,
			speed = cfg.trait.speed,
			radius = cfg.trait.circleRadius,
			distance = cfg.layout.grotto,
			trait = cfg.arms.firstTrait,
		})
	end
	emit(out, { kind = "hud", id = "traitSlot" })
	emit(out, { kind = "prompt", id = "pips", show = true })
end

local function openGap(s: State, out: { Action })
	if once(s, "curtain") then
		emit(out, { kind = "openCurtain" })
		emit(out, { kind = "hud", id = "homeMarker" })
		emit(out, { kind = "prompt", id = "homeTrail", show = true })
		s.noProgress = 0
		s.nudged = false
	end
end

local enter: (cfg: Config, s: State, out: { Action }, stage: number) -> ()

local function startS7(cfg: Config, s: State, out: { Action })
	enter(cfg, s, out, S.S7_CURRENT)
end

local function chaseResult(s: State, out: { Action }, result: string)
	emit(out, { kind = "chaseResult", result = result, value = s.manualDashes })
	emit(out, { kind = "prompt", id = "dashPulse", show = false })
end

enter = function(cfg: Config, s: State, out: { Action }, stage: number)
	s.stage = stage
	s.stageTime = 0
	if stage == S.S1_HATCH then
		local seconds = hatchSeconds(cfg, s)
		emit(out, { kind = "hatch", seconds = seconds })
		if s.form ~= "short" then
			spawnSwarmA(cfg, out)
		end
		if seconds <= 0 then
			giveControl(s, out)
		end
	elseif stage == S.S2_FIRST_BITE then
		s.t, s.clock, s.idle = 0, 0, 0
		step(s, out, 3)
		if not s.dragged then
			s.ghost = "intro"
			emit(out, { kind = "prompt", id = "ghostThumb", show = true })
		end
	elseif stage == S.S3_GROW then
		local f = cfg.feed
		emit(out, {
			kind = "spawnTrail",
			id = "trail",
			count = f.trailMotes,
			distance = cfg.layout.trailFrom,
			spacing = f.trailSpacing,
		})
		emit(out, {
			kind = "spawnSwarmB",
			id = "swarmB",
			count = f.swarmBCount,
			distance = cfg.layout.swarmB,
		})
		emit(out, { kind = "keepKrill", count = f.keepCount, radius = f.keepRadius })
	elseif stage == S.S4_TRAIT then
		emit(out, { kind = "music", id = "percussion" })
	elseif stage == S.S5_CALL_HOME then
		emit(out, { kind = "keepKrill", count = 0, radius = 0 }) -- 04 §3.6 B3: "until S5"
		if s.form == "short" then
			openGap(s, out)
		end
	elseif stage == S.S6_CHASE then
		step(s, out, 10)
		emit(out, { kind = "clearScripted" }) -- 04 §4: prey assists end at the Gap
		if s.chaseRuns < maxChaseRuns(cfg, s) then
			s.chaseRuns += 1
			s.manualDashes, s.autoDashed = 0, false
			if cfg.arms.chaseMode ~= "escort" then
				emit(out, { kind = "startChase", mode = cfg.arms.chaseMode })
			end
		else
			-- 04 §5.4: no predator on a later exit (or in the short form, 04 §9).
			if once(s, "chaseLogged") then
				emit(out, { kind = "chaseResult", result = "skipped", value = 0 })
			end
			startS7(cfg, s, out)
		end
	elseif stage == S.S7_CURRENT then
		step(s, out, 11)
		s.outside, s.nearCove = 0, 0
		emit(out, { kind = "startCurrent", mode = cfg.arms.homeMode })
	elseif stage == S.S8_BANK then
		step(s, out, 13)
		milestone(s, out, "bank")
		s.bankTime = 0
		emit(out, { kind = "prompt", id = "homeTrail", show = false })
		emit(out, { kind = "bankSequence" })
	elseif stage == S.S9_COVE then
		s.completed = true
		s.idle = 0 -- control returns (04 §6.1)
		s.mass, s.tier = 0, 1
		emit(out, { kind = "completeFtue" })
	elseif stage == S.S10_RUN2 then
		step(s, out, 17)
		local r = cfg.run2
		emit(out, {
			kind = "denseKrill",
			count = r.denseCount,
			radius = r.denseRadius,
			seconds = r.denseSeconds,
		})
		emit(out, { kind = "exitTrail", distance = r.exitTrail })
	elseif stage == S.DONE then
		step(s, out, 19)
	end
end

local function setHold(s: State, out: { Action }, on: boolean)
	if s.held == on then
		return
	end
	s.held = on
	emit(out, { kind = "hold", on = on })
	if on then
		failsafe(s, out, "afk_hold")
	end
end

-- Any input: the idle clock restarts, a hold ends, an idle ghost thumb hides (04 §3.7).
local function onInput(s: State, out: { Action })
	s.idle = 0
	s.pulsed = false
	s.fed = false
	setHold(s, out, false)
	if s.ghost == "idle" then
		s.ghost = "none"
		emit(out, { kind = "prompt", id = "ghostThumb", show = false })
	end
end

local function onDrag(s: State, out: { Action })
	s.taps = 0
	if s.stage < S.S2_FIRST_BITE then
		return
	end
	if not s.dragged then
		s.dragged = true
		step(s, out, 4)
		if s.pendingBite then
			s.pendingBite = false
			step(s, out, 5)
		end
	end
	if s.ghost ~= "none" then
		s.ghost = "none"
		emit(out, { kind = "prompt", id = "ghostThumb", show = false })
	end
end

-- 04 §3.7, 8 s without input: the beat's target pulses and its fail-safe starts early.
local function idlePulse(cfg: Config, s: State, out: { Action })
	emit(out, { kind = "pulse", id = "target" })
	if s.stage == S.S2_FIRST_BITE then
		if once(s, "biteAssist") then
			emit(out, { kind = "homePrey", id = "swarmA", speed = cfg.firstBite.assistSpeed })
		end
	elseif s.stage == S.S4_TRAIT then
		if s.fired.glowfry and once(s, "glowfryHoming") then
			emit(out, { kind = "homePrey", id = "glowfry", speed = cfg.trait.homingSpeed })
		end
	elseif s.stage == S.S5_CALL_HOME then
		if s.fired.curtain and not s.nudged then
			s.nudged = true
			emit(out, { kind = "pulse", id = "homeMarker" })
		end
	end
end

local function coveItemAt(cfg: Config, id: string): number
	local b = cfg.bank
	if id == "firstTick" then
		return b.firstTickAt
	elseif id == "species" then
		return b.speciesAt
	elseif id == "tide" then
		return b.tideAt
	end
	return b.mouthAt
end

-- 04 §6.1: the cove items on the bank clock; once the player has left, the rest follow in order
-- at least 4 s apart, as HUD pings.
local function coveItems(cfg: Config, s: State, out: { Action })
	while s.coveItem < #COVE_ITEMS do
		local id = COVE_ITEMS[s.coveItem + 1]
		local skip = (id == "firstTick" and cfg.arms.firstTick == "none")
			or (id == "tide" and cfg.arms.cliffhanger == "species_only")
		if skip then
			s.coveItem += 1
			continue
		end
		local due = coveItemAt(cfg, id)
		local lastPing = s.lastPingAt
		if lastPing then
			due = math.max(due, lastPing + cfg.bank.pingGap)
		end
		if s.bankTime < due then
			return
		end
		s.coveItem += 1
		if s.leftCove then
			s.lastPingAt = s.bankTime
		end
		emit(out, { kind = "coveItem", id = id, ping = s.leftCove })
		if id == "species" then
			step(s, out, 16)
		end
	end
end

local function tickStage(cfg: Config, s: State, out: { Action }, dt: number)
	local stage = s.stage
	local scale = idleScale(cfg, s)
	if stage >= S.S2_FIRST_BITE and s.t >= cfg.streaming.fogOpenAt and once(s, "fog") then
		emit(out, { kind = "openFog" })
	end

	-- 04 §3.7: idle prompts in S2 to S5.
	if stage >= S.S2_FIRST_BITE and stage <= S.S5_CALL_HOME then
		if s.ghost == "none" and s.idle >= cfg.idle.ghostAfter * scale then
			s.ghost = "idle"
			emit(out, { kind = "prompt", id = "ghostThumb", show = true })
		end
		if not s.pulsed and s.idle >= cfg.idle.pulseAfter * scale then
			s.pulsed = true
			idlePulse(cfg, s, out)
		end
	end

	if stage == S.S2_FIRST_BITE then
		-- 04 §3.6 B2: T = 2.5 with no bite, Swarm A drifts into the mouth by T = 5.
		if s.clock >= cfg.firstBite.assistAt and once(s, "biteAssist") then
			emit(out, { kind = "homePrey", id = "swarmA", speed = cfg.firstBite.assistSpeed })
		end
	elseif stage == S.S3_GROW then
		-- 04 §3.6 B3: no input for 8 s, the nearest krill swims into the mouth (once per spell).
		if not s.fed and s.idle >= cfg.feed.feedAfterIdle * scale then
			s.fed = true
			emit(out, { kind = "feedNearest" })
		end
		-- 04 §3.6 B4: both grow fail-safes need input in the last 10 s.
		local g = cfg.grow
		local active = s.idle < g.needInputWithin
		if active and s.tier < 2 and s.clock >= g.homingAt and once(s, "growHoming") then
			emit(
				out,
				{ kind = "homePrey", id = "krill", radius = g.homingRadius, speed = g.homingSpeed }
			)
			failsafe(s, out, "grow_homing")
		end
		if active and s.tier < 2 and s.clock >= g.burstAt and once(s, "growBurst") then
			emit(
				out,
				{ kind = "spawnBurst", id = "burst", count = g.burstCount, distance = g.burstAhead }
			)
			failsafe(s, out, "grow_burst")
		end
	elseif stage == S.S4_TRAIT then
		local tr = cfg.trait
		if s.stageTime >= cfg.grow.dashButtonDelay and once(s, "dashButton") then
			emit(out, { kind = "hud", id = "dashButton" })
		end
		if s.stageTime >= tr.glowfryDelay and once(s, "glowfry") then
			spawnGlowfry(cfg, s, out)
		end
		local missing = s.glowfry < cfg.arms.traitCount
		if
			s.fired.glowfry
			and missing
			and s.stageTime >= tr.homingAfter
			and once(s, "glowfryHoming")
		then
			emit(out, { kind = "homePrey", id = "glowfry", speed = tr.homingSpeed })
		end
		if
			s.fired.glowfry
			and missing
			and s.clock >= tr.fastHomingAt
			and once(s, "glowfryFast")
		then
			emit(out, { kind = "homePrey", id = "glowfry", speed = tr.fastHomingSpeed })
			failsafe(s, out, "trait_homing")
		end
		-- 04 §3.1: T = 70 with input in the last 10 s moves on without the trait.
		if s.clock >= tr.moveOnAt and s.idle < tr.moveOnNeedInputWithin then
			enter(cfg, s, out, S.S5_CALL_HOME)
		end
	elseif stage == S.S5_CALL_HOME then
		local h = cfg.callHome
		if s.stageTime >= h.curtainDelay then
			openGap(s, out)
		end
		if
			s.form ~= "short"
			and s.stageTime >= h.curtainDelay + h.shadowDelay
			and once(s, "shadow")
		then
			emit(out, { kind = "predatorShadow" })
			emit(out, { kind = "music", id = "dropPercussion" })
		end
		if s.retreatAt and s.stageTime - s.retreatAt >= cfg.chase.retreatPulseAfter then
			s.retreatAt = nil
			emit(out, { kind = "pulse", id = "trail" })
		end
		if s.fired.curtain then
			s.noProgress += dt
			if not s.nudged and s.noProgress >= h.nudgeAfter * scale then
				s.nudged = true
				emit(out, { kind = "pulse", id = "homeMarker" })
			end
			if
				s.form ~= "short"
				and s.noProgress >= h.lureAfter * scale
				and once(s, "homeLure")
			then
				emit(out, { kind = "spawnLure", id = "home" })
				failsafe(s, out, "home_lure")
			end
			if s.noProgress >= h.pushAfter * scale and once(s, "homePush") then
				emit(out, { kind = "pull", id = "gap", speed = h.pushSpeed })
				failsafe(s, out, "home_push")
			end
		end
	elseif stage == S.S6_CHASE then
		local c = cfg.chase
		if cfg.arms.chaseMode ~= "escort" then
			if s.stageTime >= c.promptAt and once(s, "dashPrompt" .. s.chaseRuns) then
				emit(out, { kind = "prompt", id = "dashPulse", show = true })
			end
			local late = s.stageTime >= c.promptAt + c.autoDashAfter
			if late and s.manualDashes == 0 and not s.autoDashed and once(s, "autoDash") then
				s.autoDashed = true
				emit(out, { kind = "autoDash" })
			end
		end
	elseif stage == S.S7_CURRENT then
		local cu, b = cfg.current, cfg.bank
		if cfg.arms.homeMode == "current" and not s.inCurrent then
			s.outside += dt
			if s.outside >= cu.reformAfter and s.coveDistance > cu.reformBeyond then
				s.outside = 0
				s.inCurrent = true -- the branch forms where the player is
				emit(out, { kind = "reformCurrent" })
			end
		else
			s.outside = 0
		end
		if s.coveDistance <= b.pullRadius then
			s.nearCove += dt
			if s.nearCove >= b.pullAfter and once(s, "covePull") then
				emit(out, { kind = "pull", id = "cove", speed = b.pullSpeed })
			end
		else
			s.nearCove = 0
		end
	end

	if stage >= S.S8_BANK and stage <= S.S10_RUN2 then
		s.bankTime += dt
		coveItems(cfg, s, out)
	end
	if stage == S.S9_COVE then
		-- 04 §3.6 B12: counted from the last cliffhanger item.
		local after = s.bankTime - cfg.bank.tideAt
		if after >= cfg.cove.exitNudgeAfter and once(s, "coveNudge") then
			emit(out, { kind = "pulse", id = "coveMouth" })
			emit(out, { kind = "exitTrail", distance = cfg.run2.exitTrail })
		end
		if after >= cfg.cove.exitLureAfter and once(s, "coveLure") then
			emit(out, { kind = "spawnLure", id = "cove" })
		end
	elseif stage == S.S10_RUN2 then
		local r = cfg.run2
		if s.stageTime >= r.goalsChipDelay and once(s, "goalsChip") then
			emit(out, { kind = "hud", id = "goalsChip" })
		end
		if s.stageTime >= r.homingAt and s.mass < r.homingBelow and once(s, "run2Homing") then
			s.run2Homing = true
			emit(
				out,
				{ kind = "homePrey", id = "krill", radius = r.homingRadius, speed = r.homingSpeed }
			)
			failsafe(s, out, "run2_homing")
		end
	end
end

local function onTick(cfg: Config, s: State, out: { Action }, dt: number, hadInput: boolean)
	if s.stage == S.S0_LOADING then
		return
	elseif s.stage == S.S1_HATCH then
		s.stageTime += dt
		if s.stageTime >= hatchSeconds(cfg, s) then
			giveControl(s, out)
		end
		return
	end
	s.t += dt
	if hadInput then
		onInput(s, out)
	else
		s.idle += dt
		if s.idle >= cfg.idle.holdAfter * idleScale(cfg, s) and HOLDABLE[s.stage] then
			setHold(s, out, true)
		end
	end
	if s.held then
		return -- 04 §3.7: beat timers freeze
	end
	s.clock += dt
	s.stageTime += dt
	tickStage(cfg, s, out, dt)
end

local function onEvent(cfg: Config, s: State, out: { Action }, e: Event)
	local k, stage = e.kind, s.stage
	if k == "tick" then
		onTick(cfg, s, out, e.dt or 0, e.hadInput == true)
	elseif k == "loadingDone" then
		if stage == S.S0_LOADING then
			enter(cfg, s, out, S.S1_HATCH)
		end
	elseif k == "touch" then
		if stage == S.S1_HATCH then
			if s.stageTime >= cfg.hatch.skipAfter then
				giveControl(s, out)
			end
			return
		end
		if stage < S.S2_FIRST_BITE then
			return
		end
		onInput(s, out)
		if e.drag then
			onDrag(s, out)
		elseif stage == S.S2_FIRST_BITE then
			s.taps += 1
			if s.taps >= cfg.firstBite.tapsForReplay then
				s.taps = 0
				s.ghost = "intro"
				emit(out, { kind = "prompt", id = "ghostThumb", show = true, mode = "long" })
			end
		end
	elseif k == "controlGained" then
		if stage == S.S1_HATCH then
			s.fired.giveControl = true
			enter(cfg, s, out, S.S2_FIRST_BITE)
			if s.form == "short" then
				-- 04 §9 short form: curtain open, home marker on, no scripted prey or chase.
				enter(cfg, s, out, S.S5_CALL_HOME)
			end
		end
	elseif k == "preyEaten" then
		if stage == S.S2_FIRST_BITE then
			milestone(s, out, "bite")
			if s.dragged then
				step(s, out, 5)
			else
				s.pendingBite = true -- 10 §3.1: step 05 waits for the first input
				emit(out, { kind = "biteAssist", t = s.t })
			end
			emit(out, { kind = "hud", id = "massBar" })
			enter(cfg, s, out, S.S3_GROW)
		end
		if e.group == "glowfry" and stage <= S.S7_CURRENT then
			s.glowfry += 1
			step(s, out, 8)
		end
	elseif k == "massChanged" then
		s.mass = e.mass or s.mass
		if stage >= S.S2_FIRST_BITE and stage <= S.S7_CURRENT and s.mass >= cfg.feed.massStep then
			if once(s, "mass5") then
				step(s, out, 6)
				emit(out, { kind = "music", id = "pluck" })
			end
		end
		if stage == S.S10_RUN2 and s.run2Homing and s.mass >= cfg.run2.homingUntil then
			s.run2Homing = false
			emit(out, { kind = "stopHoming", id = "krill" })
		end
	elseif k == "tierReached" then
		s.tier = e.tier or s.tier
		if stage == S.S3_GROW and s.tier >= 2 then
			milestone(s, out, "tier2")
			step(s, out, 7)
			enter(cfg, s, out, S.S4_TRAIT)
		elseif stage == S.S10_RUN2 and s.tier >= 2 then
			step(s, out, 18)
		end
	elseif k == "traitGained" then
		if stage == S.S4_TRAIT or stage == S.S5_CALL_HOME then
			milestone(s, out, "trait")
			step(s, out, 9)
			emit(out, { kind = "prompt", id = "pips", show = false })
			if stage == S.S4_TRAIT then
				emit(out, { kind = "music", id = "pad" })
				enter(cfg, s, out, S.S5_CALL_HOME)
			end
		end
	elseif k == "moved" then
		if e.inCurrent ~= nil then
			s.inCurrent = e.inCurrent
		end
		if e.coveDistance ~= nil then
			s.coveDistance = e.coveDistance
		end
		if stage == S.S5_CALL_HOME and e.towardGap then
			s.noProgress = 0
			s.nudged = false
		end
		local inSight = s.coveDistance <= cfg.current.coveInSight
		if inSight and stage >= S.S5_CALL_HOME and stage <= S.S7_CURRENT then
			step(s, out, 12)
		end
	elseif k == "crossedGap" then
		if stage == S.S5_CALL_HOME and s.fired.curtain then
			enter(cfg, s, out, S.S6_CHASE)
		end
	elseif k == "dashed" then
		if stage == S.S6_CHASE and not e.auto then
			s.manualDashes += 1
			if s.manualDashes == 1 then
				emit(out, { kind = "prompt", id = "dashPulse", show = false })
			end
		end
	elseif k == "retreated" then
		if stage == S.S6_CHASE then
			chaseResult(s, out, "retreated")
			enter(cfg, s, out, S.S5_CALL_HOME)
			s.retreatAt = 0
			s.noProgress = 0
			s.nudged = false
		end
	elseif k == "chaseEnded" then
		if stage == S.S6_CHASE then
			s.fired.chaseLogged = true
			chaseResult(s, out, if e.assisted or s.autoDashed then "assisted" else "clean")
			startS7(cfg, s, out)
		end
	elseif k == "enteredCoveMouth" then
		if stage >= S.S5_CALL_HOME and stage <= S.S7_CURRENT then
			if stage == S.S6_CHASE then
				chaseResult(s, out, "skipped")
			end
			enter(cfg, s, out, S.S8_BANK)
		end
	elseif k == "fryHatched" then
		if stage == S.S8_BANK then
			enter(cfg, s, out, S.S9_COVE)
		end
	elseif k == "leftCoveMouth" then
		if stage == S.S9_COVE then
			s.leftCove = true
			enter(cfg, s, out, S.S10_RUN2)
		end
	elseif k == "runEnded" then
		if stage == S.S10_RUN2 then
			enter(cfg, s, out, S.DONE)
		end
	elseif k == "backgrounded" then
		if HOLDABLE[stage] then
			setHold(s, out, true) -- 04 §3.7: the same as the 20 s hold, at once
		end
	end
end

--- Handles one event. Returns a new state and the actions to perform, in order.
function FtueRules.handle(cfg: Config, state: State, event: Event): (State, { Action })
	local s = copy(state)
	local out: { Action } = {}
	if s.stage ~= S.DONE then
		onEvent(cfg, s, out, event)
	end
	return s, out
end

-- 04 §9 and 09 §12.5: a rejoin before the first bank, with the run resumed, carries on from the
-- last completed beat. The beats already done are marked fired and not replayed; the current
-- beat's own scripted prey and the HUD it had are put back.
local function resume(cfg: Config, s: State, out: { Action }, stage: number, run: Run)
	s.t, s.clock = run.seconds, run.seconds
	s.mass, s.tier, s.glowfry = run.mass, run.tier, run.traitProgress
	s.dragged = true
	local done = s.fired
	done.giveControl, done.step1, done.step3, done.step4 = true, true, true, true
	if stage >= S.S3_GROW then
		done.step5, done.milestone_bite = true, true
	end
	if stage >= S.S4_TRAIT then
		done.step7, done.milestone_tier2 = true, true
	end
	if stage >= S.S5_CALL_HOME and s.glowfry >= cfg.arms.traitCount then
		done.step9, done.milestone_trait = true, true
	end
	if s.glowfry > 0 then
		done.step8 = true
	end
	if s.mass >= cfg.feed.massStep then
		done.mass5, done.step6 = true, true
	end
	if s.t >= cfg.streaming.fogOpenAt then
		done.fog = true
		emit(out, { kind = "openFog" })
	end
	s.stage = stage
	if stage >= S.S3_GROW then
		emit(out, { kind = "hud", id = "massBar" })
	end
	if stage == S.S2_FIRST_BITE then
		spawnSwarmA(cfg, out)
	elseif stage == S.S3_GROW then
		enter(cfg, s, out, S.S3_GROW)
	elseif stage >= S.S4_TRAIT then
		done.dashButton, done.glowfry = true, true
		emit(out, { kind = "hud", id = "dashButton" })
		if stage == S.S4_TRAIT then
			spawnGlowfry(cfg, s, out)
		else
			emit(out, { kind = "hud", id = "traitSlot" })
		end
	end
	if stage >= S.S5_CALL_HOME then
		done.shadow = true
		openGap(s, out)
	end
	if stage == S.S6_CHASE then
		-- The chase starts on the crossing, which cannot be replayed: it counts as never completed.
		done.step10, done.chaseLogged = true, true
		emit(out, { kind = "chaseResult", result = "skipped", value = 0 })
		enter(cfg, s, out, S.S7_CURRENT)
	elseif stage == S.S7_CURRENT then
		done.step10, done.step11 = true, true
		emit(out, { kind = "startCurrent", mode = cfg.arms.homeMode })
	end
	s.stageTime = 0
end

--- The state at join, and the actions to start with (04 §9; 09 §12.2, §12.5).
function FtueRules.new(cfg: Config, join: Join): (State, { Action })
	local out: { Action } = {}
	if join.completed or join.banked or join.stage >= S.DONE then
		local s = blank("full")
		s.stage, s.completed = S.DONE, true
		if not join.completed then
			emit(out, { kind = "completeFtue" }) -- 04 §9: the FTUE is complete after the first bank
		end
		return s, out
	end
	local run = join.run
	if run and join.stage >= S.S2_FIRST_BITE and join.stage <= S.S7_CURRENT then
		local s = blank(formOf(cfg, join.attempts))
		resume(cfg, s, out, join.stage, run)
		return s, out
	end
	local attempts = join.attempts
	if join.stage > S.S0_LOADING then
		-- 04 §9: no run to resume, so the FTUE restarts from the hatch; attempts goes up by one.
		attempts += 1
		emit(out, { kind = "restart", value = attempts })
	elseif attempts == 0 then
		emit(out, { kind = "step", step = 1 })
	end
	local s = blank(formOf(cfg, attempts))
	if attempts == 0 then
		s.fired.step1 = true
	end
	return s, out
end

--- True while the 04 §3.7 hold is on.
function FtueRules.isHeld(state: State): boolean
	return state.held
end

return FtueRules
