--!strict
-- TutorialService: the server half of the first-time script (task S6-C2, module B31; docs/04,
-- sections 3, 4 and 9; docs/09, sections 5.1, 5.3 and 12.2; docs/10, section 3.1). It owns
-- `ftue.stage` (04 §3.1: the server owns the stage and saves it); the client's TutorialDirector
-- plays the presentation. The stage machine is the pure Logic/FtueRules, the route and the
-- `TutorialStep` values are Logic/FtuePlan, and every number is Config/FtueConfig's.
--
-- Join     on PlayerLifecycle.onReady, FtueRules.new from the profile's `ftue` and `stats.banks`.
--          An account with `ftue.completed` (or a bank) gets no session and no stage save, unless
--          its saved stage is S9 or S10: it keeps that stage (04 §4: the run 2 assists read it)
--          in a session that replays nothing. A saved stage past S0 with no run to resume restarts
--          the script in the fast or short form (04 §9).
--          TODO(B19, S12-C4): pass the resumed run (`RunLoopService.resume`) so a rejoin carries on
--          from the saved stage instead.
-- Control  `giveControl` (the end of the hatch, T = 0) calls PlayerLifecycle.controlGranted, which
--          sends `sys_load_time` (PlayerLifecycle does it itself for a finished account).
-- Feeding  FtueRules hears: the client's `TutorialStep` reports (FtuePlan.Code: loading done, tap,
--          steering, background; 2 is onboarding step 02 and goes to `onStep`), held until the
--          session exists; `controlGained` right after its own `giveControl`; PreyService's
--          `onScriptedEaten` (the group's FtueRules name) and `onWildEaten` (group nil): only bites
--          BiteService accepted; `massChanged`; CreatureService.onTierChanged;
--          TraitService.onGained for `arms.firstTrait` only (04 §3.6 B5); from S5, `moved`
--          (towards the Gap, every `director.every`) and `crossedGap` (a `NurseryPath` place past
--          the Gap); and a `tick` every `director.tick` with whether any input came.
-- Trait    the session's `arms.traitCount` is TraitService.pipsNeeded for the slot (5, or 4 with
--          Keen Nose), so the Glowfry spawned always gain the trait. TODO(S6-C6): the 3-Glowfry
--          arm of `ftue_trait_count` needs TraitService to gain the FTUE's trait at 3 pips.
-- Prey     every scripted group is PreyService.spawnScripted for the player's slot alone, `calm`
--          (04 §4: FTUE krill never scatter), at FtueConfig's distances along the route (FtuePlan).
--          Each tick it is steered (PreyService.steerScripted) toward the player's root:
--            homing    a `homePrey`, `feedNearest` or `spawnBurst` group, at that speed;
--            glowfry   at the trait speed, its leash the circle radius (04 §3.6 B5);
--            swarmA    in S1 and S2 still until it homes (B2: the T = 2.5 assist), except that once
--                      the player is farther from it than the Hatch Bed is, by more than its
--                      radius (swimming away), it follows,
--                      held within the follow limit of the hatch point; from S3 as any krill;
--            krill     any other krill within the drift radius, at the drift speed (B3, §4);
--            plankton  never.
--          A hold (04 §3.7) stops all of it where it is. `keepKrill` tops the scripted krill within
--          its radius up to its count once a second, with a ball at the drift radius ahead.
-- Saves    `ftue.stage` on every stage change, `ftue.completed` and `ftue.attempts` when the rules
--          say, through DataService.patch, which also sends them to the owner as `State`.
-- Client   one `State` per batch of actions, path `ftue.cue` (not saved, as TraitService sends
--          `run.traits`), value { seq = n, actions = { Action, ... } }: the presentation actions
--          of FtueRules (its header lists their fields), in order. `seq` rises by one per batch
--          for as long as the player is on the server, across sessions (a `/ftue reset` does not
--          start it again), so the client drops any batch whose seq is not above the last one it
--          played. Kinds: reset (first in the batch after `/ftue reset`: drop every prompt, HUD
--          reveal and effect being presented, then play the rest), hatch, giveControl, hold,
--          prompt, hud, pulse, music, openFog, openCurtain, predatorShadow, startChase, autoDash,
--          startCurrent, reformCurrent, pull, bankSequence, coveItem, exitTrail, feedNearest.
-- Analytics (task S6-C6; 10 §3.1, §4.2) every analytics action of the rules goes to Analytics:
--          `step` through the `onStep(player, step, ctx)` hook (`Analytics.step`, the onboarding
--          funnel: no session ID); `failsafe` through `onFailsafe(player, kind, value)`
--          (`ftue_failsafe`, value T); `milestone` as `ftue_milestone` (value T, ctx bucketed by
--          AnalyticsRules.milestoneCtx), `biteAssist` as `ftue_bite_assist` (T), `chaseResult` as
--          `ftue_chase_result` (manual dashes). Once per account: FtueRules fires each of these once
--          a session; the profile's `ftue.logged` (AnalyticsRules.ONCE bits, saved like the stage)
--          keeps a fail-safe, a milestone or the bite assist from being sent again after a rejoin
--          or a restart. The load fail-safes come from `ClientReady`'s load mode
--          (PlayerLifecycle.loadMode): `load_partial` or `load_minimal` at the session's start,
--          for an account in the FTUE, with value J at `ClientReady` (T is not running yet; 10
--          §4.2). Step 02 is the client's `TutorialStep` 2 (Client/Main, from the loading screen's
--          `LoadShown`), counted on the account's first start only. Steps 14 and 15 (specimen
--          placed, first tick paid) are CoveService's and EconomyService's: TODO(S7-C3).
-- Later    TODO(S7-C1, S7-C2) CHASE_PASS_THROUGH: until the chase exists, S6 ends at once with
--          `chaseSkipped` into S7 (a warn each time; the batch carries no `startChase`), so a
--          player past the Gap is never left in it. S7 needs none: the player swims freely, and
--          its exit is the bank (S7-C3).
--          TODO(S7-C1): the chase (`startChase`, `autoDash`, `dashed`, `retreated`, `chaseEnded`).
--          TODO(S7-C2): the Home Current (`startCurrent`, `reformCurrent`, `moved` inCurrent and
--          coveDistance). TODO(S7-C3): the bank (`enteredCoveMouth`, `bankSequence`, `fryHatched`,
--          `leftCoveMouth`, `runEnded`, the cove's `spawnLure` and `denseKrill`). TODO(S7-C6): the
--          kelp curtain gate, B6's `spawnLure` home and `pull` gap.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnalyticsRules = require(ReplicatedStorage.Shared.Logic.AnalyticsRules)
local Defaults = require(ReplicatedStorage.Shared.Config.Defaults)
local FtueConfig = require(ReplicatedStorage.Shared.Config.FtueConfig)
local FtuePlan = require(ReplicatedStorage.Shared.Logic.FtuePlan)
local FtueRules = require(ReplicatedStorage.Shared.Logic.FtueRules)
local LoadTime = require(ReplicatedStorage.Shared.Logic.LoadTime)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local PreySim = require(ReplicatedStorage.Shared.Sim.PreySim)
local Types = require(ReplicatedStorage.Shared.Types)

local Analytics = require("./Analytics")
local CreatureService = require("./CreatureService")
local DataService = require("./DataService")
local PlayerLifecycle = require("./PlayerLifecycle")
local PreyService = require("./PreyService")
local Server = require("../Net/Server")
local TraitService = require("./TraitService")
local WorldIndex = require("./WorldIndex")

type Slot = Types.Slot
type CreatureState = CreatureService.CreatureState
type Action = FtueRules.Action
type Event = FtueRules.Event
type State = FtueRules.State
type Config = FtueRules.Config

local TAG = "Tutorial"
local MAX_BALL = PreySim.MAX_MEMBERS -- members in one scripted ball

local S = FtueRules.Stage
local C = FtuePlan.Code

-- The actions the client presents (see the header); the rest are the server's.
local PRESENT: { [string]: boolean } = table.freeze({
	reset = true,
	hatch = true,
	giveControl = true,
	hold = true,
	prompt = true,
	hud = true,
	pulse = true,
	music = true,
	openFog = true,
	openCurtain = true,
	predatorShadow = true,
	startChase = true,
	autoDash = true,
	startCurrent = true,
	reformCurrent = true,
	pull = true,
	bankSequence = true,
	coveItem = true,
	exitTrail = true,
	feedNearest = true,
})

-- One scripted group of a session.
type Group = {
	name: string, -- the FtueRules group: "swarmA", "trail", "swarmB", "glowfry", "burst", "keep"
	krill: boolean,
	homing: number?, -- studs/s toward the mouth while set
	followSpeed: number?, -- Swarm A only
	followLimit: number?,
	awayBeyond: number?, -- Swarm A: studs from it past which the player is swimming away
}

type Session = {
	slot: Slot,
	player: Player?, -- nil for the engine spec's stand-in
	reporter: Player?, -- who Analytics hears about: the player, or the spec's stand-in
	logged: number, -- the profile's `ftue.logged` (AnalyticsRules.ONCE bits)
	cfg: Config, -- FtueConfig with the slot's `arms.traitCount` (see the header)
	state: State,
	saved: number, -- the stage last saved
	groups: { [number]: Group }, -- by scripted ID
	keep: { count: number, radius: number }?,
	every: number, -- seconds since the last keep check and moved report
	input: boolean, -- a tap or steering report since the last tick
	mass: number, -- the creature's mass at the last tick
	gapDistance: number?, -- at the last moved report
	shown: boolean, -- onboarding step 02 sent
	fresh: boolean, -- the account's first start (attempts 0): steps 01 and 02 count
	manual: boolean, -- the engine spec ticks it by hand
}

-- What a client reported before its session existed (09 §5.3 `TutorialStep` arrives early: the
-- loading screen is up before the creature).
type Early = { shown: boolean, loaded: boolean }

local TutorialService = {}
TutorialService.name = "TutorialService"

local cfg = FtueConfig
local sessionOf: { [Player]: Session } = {}
local bySlot: { [Slot]: Session } = {}
local early: { [Player]: Early } = {}
-- The last `ftue.cue` seq sent, by player (the stand-in: by slot); kept across sessions.
local seqOf: { [any]: number } = {}
local running = false
local acc = 0
-- Where creatures come from and where the stand-in's saves and cues go (`_test.stub`).
local lookup: (Slot) -> CreatureState? = CreatureService.get
local sink: ((kind: string, path: string, value: any) -> ())? = nil
-- The hooks' record, for the engine spec: { kind = "step" | "failsafe", value = ... }.
local hookLog: { { kind: string, value: any } } = {}
-- The engine spec's stand-in player, which its stand-in sessions report to Analytics as.
local standIn: Player? = nil

local hx, hy, hz = FtuePlan.routePoint(0)
local HATCH = Vector3.new(hx, hy, hz)
local GLOWFRY = FtuePlan.traitPreyFor(cfg.arms.firstTrait)

local function routeVector(s: number): Vector3
	local x, y, z = FtuePlan.routePoint(s)
	return Vector3.new(x, y, z)
end

-- Hooks ---------------------------------------------------------------------------------------

--- An onboarding funnel step (10 §3.1) the script reached: `Analytics.step` on the one-time
--- onboarding funnel (no session ID; Analytics drops a step at or below the highest sent).
function TutorialService.onStep(player: Player?, step: number, ctx: string?)
	table.insert(hookLog, { kind = "step", value = step })
	if player then
		Analytics.step(player, "onboarding", nil, step, ctx)
	end
end

--- An `ftue_failsafe` (04 §2.4, §3.6, §3.7; 10 §4.2) that starts for the first time on the
--- account: `value` is T (J for the load fail-safes).
function TutorialService.onFailsafe(player: Player?, kind: string, value: number)
	table.insert(hookLog, { kind = "failsafe", value = kind })
	if player then
		Analytics.event(player, "ftue_failsafe", value, kind)
	end
end

-- Control comes at the end of the hatch (04 §2.1 phase E, T = 0): `sys_load_time`.
local function grantControl(session: Session)
	local player = session.player
	if player then
		PlayerLifecycle.controlGranted(player)
	end
end

-- Dev cheats here (Config/Defaults; 09 §3: server/Dev is for dev places only).
local function devCheats(): boolean
	return Defaults.forGame(game.GameId, RunService:IsStudio()).devCheats
end

-- The config the slot's session runs on: FtueConfig with `arms.traitCount` set to the pips
-- TraitService needs (see the header).
local function configFor(slot: Slot): Config
	local pips = TraitService.pipsNeeded(slot)
	if pips == cfg.arms.traitCount then
		return cfg
	end
	Log.once(
		"info",
		TAG,
		`arms.traitCount {cfg.arms.traitCount} is not TraitService's {pips} pips: the script spawns {pips}`
	)
	local arms = table.clone(cfg.arms)
	arms.traitCount = pips
	local c = table.clone(cfg)
	c.arms = arms
	return c
end

-- Saves and cues -----------------------------------------------------------------------------

local function save(session: Session, path: string, value: any)
	local player = session.player
	if player then
		DataService.patch(player, path, value)
	elseif sink then
		sink("save", path, value)
	end
end

local function sendCues(session: Session, cues: { Action })
	if #cues == 0 then
		return
	end
	local key: any = session.player or session.slot
	local seq = (seqOf[key] or 0) + 1
	seqOf[key] = seq
	local value = { seq = seq, actions = cues }
	local player = session.player
	if player then
		Server.send(player, "State", "ftue.cue", value)
	elseif sink then
		sink("cue", "ftue.cue", value)
	end
end

-- Analytics ----------------------------------------------------------------------------------

-- 10 §4.2 "once per account": false when the profile already holds `key` (an AnalyticsRules.ONCE
-- entry); otherwise it is marked and saved, and true.
local function firstOnAccount(session: Session, key: string): boolean
	if AnalyticsRules.isLogged(session.logged, key) then
		return false
	end
	session.logged = AnalyticsRules.withLogged(session.logged, key)
	save(session, "ftue.logged", session.logged)
	return true
end

local function failsafe(session: Session, ctx: string, value: number)
	if firstOnAccount(session, "failsafe_" .. ctx) then
		TutorialService.onFailsafe(session.reporter, ctx, value)
	end
end

local function sendEvent(session: Session, name: string, value: number, ctx: string?)
	local reporter = session.reporter
	if reporter then
		Analytics.event(reporter, name, value, ctx)
	end
end

-- The rules' analytics actions (see the header); any other action is ignored.
local function report(session: Session, a: Action)
	local kind = a.kind
	local t = AnalyticsRules.seconds(session.state.t)
	if kind == "step" then
		TutorialService.onStep(session.reporter, a.step :: number, nil)
	elseif kind == "failsafe" then
		failsafe(session, a.ctx :: string, t)
	elseif kind == "milestone" then
		local id = a.id :: string
		if firstOnAccount(session, "milestone_" .. id) then
			local at = a.t or session.state.t
			sendEvent(
				session,
				"ftue_milestone",
				AnalyticsRules.seconds(at),
				AnalyticsRules.milestoneCtx(id, at)
			)
		end
	elseif kind == "biteAssist" then
		if firstOnAccount(session, "bite_assist") then
			sendEvent(
				session,
				"ftue_bite_assist",
				AnalyticsRules.seconds(a.t or session.state.t),
				nil
			)
		end
	elseif kind == "chaseResult" then
		sendEvent(session, "ftue_chase_result", a.value or 0, a.result)
	end
end

-- Scripted prey ---------------------------------------------------------------------------------

local function spawn(
	session: Session,
	name: string,
	spec: PreyService.ScriptedSpec,
	group: Group?
): number?
	local id = PreyService.spawnScripted(session.slot, spec)
	if id == nil then
		Log.once("warn", TAG, `scripted {name} refused for slot {session.slot}`)
		return nil
	end
	session.groups[id] = group or { name = name, krill = spec.preyId == FtuePlan.KRILL }
	return id
end

local function ball(
	preyId: string,
	count: number,
	centre: Vector3,
	spread: number
): PreyService.ScriptedSpec
	return {
		preyId = preyId,
		count = math.clamp(count, 1, MAX_BALL),
		centre = centre,
		spread = spread,
		calm = true,
	}
end

local function matches(group: Group, id: string?): boolean
	if id == FtuePlan.KRILL then
		return group.krill
	end
	return group.name == id
end

local function stopAll(session: Session)
	for id in session.groups do
		PreyService.steerScripted(session.slot, id, nil)
	end
end

-- Members of the scripted krill whose centre is within `radius` of `at`.
local function krillNear(session: Session, at: Vector3, radius: number): number
	local n = 0
	for id, group in session.groups do
		if group.krill then
			local alive, centre = PreyService.scriptedAlive(session.slot, id)
			if centre and (centre - at).Magnitude <= radius then
				n += alive
			end
		end
	end
	return n
end

local function keepUp(session: Session, creature: CreatureState)
	local keep = session.keep
	if keep == nil then
		return
	end
	local p = creature.root.Position
	local short = keep.count - krillNear(session, p, keep.radius)
	if short > 0 then
		local at = p + creature.root.CFrame.LookVector * cfg.feed.driftRadius
		spawn(session, "keep", ball(FtuePlan.KRILL, short, at, cfg.layout.swarmAWidth / 2))
	end
end

-- Actions ------------------------------------------------------------------------------------

local function perform(session: Session, a: Action, queue: { Event }, cues: { Action })
	local kind = a.kind
	if PRESENT[kind] then
		table.insert(cues, a)
	end
	local slot = session.slot
	local creature = lookup(slot)
	if kind == "giveControl" then
		grantControl(session)
		table.insert(queue, { kind = "controlGained" })
	elseif kind == "completeFtue" then
		save(session, "ftue.completed", true)
	elseif kind == "restart" then
		save(session, "ftue.attempts", a.value)
		save(session, "ftue.stage", S.S0_LOADING)
		session.saved = S.S0_LOADING
	elseif kind == "hold" then
		if a.on then
			stopAll(session)
		end
	elseif kind == "spawnSwarmA" then
		local at = routeVector(a.distance or 0)
		local spread = (a.width or 0) / 2
		spawn(session, "swarmA", ball(FtuePlan.KRILL, a.count or 1, at, spread), {
			name = "swarmA",
			krill = true,
			followSpeed = a.speed,
			followLimit = a.limit,
			-- B2 "swimming away": farther from it than the Hatch Bed is, by more than its radius.
			awayBeyond = (at - HATCH).Magnitude + spread,
		})
	elseif kind == "spawnTrail" then
		local positions = {}
		for _, p in FtuePlan.trailPoints(a.distance or 0, a.count or 0, a.spacing or 0) do
			table.insert(positions, Vector3.new(p[1], p[2], p[3]))
		end
		if #positions > 0 then
			spawn(
				session,
				"trail",
				{ preyId = FtuePlan.PLANKTON, positions = positions, calm = true }
			)
		end
	elseif kind == "spawnSwarmB" then
		-- 04 §3.5 gives Swarm B no width: Swarm A's.
		local spread = cfg.layout.swarmAWidth / 2
		spawn(
			session,
			"swarmB",
			ball(FtuePlan.KRILL, a.count or 1, routeVector(a.distance or 0), spread)
		)
	elseif kind == "keepKrill" then
		session.keep = if (a.count or 0) > 0
			then { count = a.count :: number, radius = a.radius or 0 }
			else nil
		if creature then
			keepUp(session, creature)
		end
	elseif kind == "spawnGlowfry" then
		local preyId = if a.trait then FtuePlan.traitPreyFor(a.trait) else GLOWFRY
		if preyId == nil then
			Log.once("error", TAG, `no trait prey gives {a.trait}`)
			return
		end
		-- 04 §3.6 B5: they leave the Glow Grotto together, each one a group of its own, and
		-- circle within the circle radius of their leash.
		local at = routeVector(a.distance or 0)
		local positions = table.create(a.count or 0, at)
		local spec: PreyService.ScriptedSpec =
			{ preyId = preyId, positions = positions, spread = a.radius, calm = true }
		if #positions > 0 and spawn(session, "glowfry", spec) == nil then
			-- The slot's scripted budget is spent (half-eaten krill and motes): the first trait
			-- comes first, so the rest of the feed goes and keepKrill tops the krill up again.
			Log.warn(TAG, `glowfry for slot {slot}: budget full, clearing the feed first`)
			PreyService.clearScripted(slot)
			table.clear(session.groups)
			spawn(session, "glowfry", spec)
		end
	elseif kind == "spawnBurst" then
		if creature then
			local at = creature.root.Position + creature.root.CFrame.LookVector * (a.distance or 0)
			spawn(
				session,
				"burst",
				ball(FtuePlan.KRILL, a.count or 1, at, cfg.layout.swarmAWidth / 2),
				{ name = "burst", krill = true, homing = cfg.grow.homingSpeed }
			)
		end
	elseif kind == "homePrey" then
		local p = if creature then creature.root.Position else nil
		for id, group in session.groups do
			if not matches(group, a.id) then
				continue
			end
			local radius = a.radius
			if radius and p then
				local _, centre = PreyService.scriptedAlive(slot, id)
				if centre == nil or (centre - p).Magnitude > radius then
					continue
				end
			end
			group.homing = math.max(group.homing or 0, a.speed or 0)
		end
	elseif kind == "feedNearest" then
		if creature then
			local p = creature.root.Position
			local best, bestD = nil, math.huge
			for id, group in session.groups do
				if group.krill then
					local alive, centre = PreyService.scriptedAlive(slot, id)
					if alive > 0 and centre and (centre - p).Magnitude < bestD then
						best, bestD = group, (centre - p).Magnitude
					end
				end
			end
			if best then
				best.homing = math.max(best.homing or 0, cfg.feed.driftSpeed)
			end
		end
	elseif kind == "stopHoming" then
		for _, group in session.groups do
			if matches(group, a.id) then
				group.homing = nil
			end
		end
	elseif kind == "clearScripted" then
		PreyService.clearScripted(slot)
		table.clear(session.groups)
		session.keep = nil
	else
		report(session, a)
	end
	-- TODO(S7-C3, S7-C6): spawnLure and denseKrill (see the header).
end

local function drain(session: Session, queue: { Event }, cues: { Action })
	while #queue > 0 do
		local event = table.remove(queue, 1) :: Event
		local state, more = FtueRules.handle(session.cfg, session.state, event)
		session.state = state
		for _, a in more do
			perform(session, a, queue, cues)
		end
	end
end

-- Runs the actions, then every event they queued (`controlGained`), then saves the stage and sends
-- the batch.
local function run(session: Session, actions: { Action }, queue: { Event })
	local cues: { Action } = {}
	for _, a in actions do
		perform(session, a, queue, cues)
	end
	drain(session, queue, cues)
	if session.state.stage == S.S6_CHASE then
		-- TODO(S7-C1, S7-C2) CHASE_PASS_THROUGH: no chase to run yet (see the header). Remove this
		-- block when S7-C1 feeds `chaseEnded` and `retreated`.
		local who = if session.player then session.player.UserId else `slot {session.slot}`
		Log.warn(TAG, `S6 has no chase yet (S7-C1): {who} passes straight into S7`)
		for k = #cues, 1, -1 do
			local kind = cues[k].kind
			if kind == "startChase" or kind == "autoDash" then
				table.remove(cues, k)
			end
		end
		table.insert(queue, { kind = "chaseSkipped" })
		drain(session, queue, cues)
	end
	if session.state.stage ~= session.saved then
		session.saved = session.state.stage
		save(session, "ftue.stage", session.saved)
	end
	sendCues(session, cues)
end

local function feed(session: Session, event: Event)
	if bySlot[session.slot] ~= session then
		return -- ended while an event was on its way
	end
	run(session, {}, { event })
end

local function endSession(session: Session)
	if bySlot[session.slot] == session then
		bySlot[session.slot] = nil
	end
	local player = session.player
	if player and sessionOf[player] == session then
		sessionOf[player] = nil
	end
	PreyService.clearScripted(session.slot)
end

-- Starts the script for `slot` from `join`; nil when the account never enters it. `again`: a
-- developer reset, whose first cue is `reset`.
local function begin(
	slot: Slot,
	player: Player?,
	join: FtueRules.Join,
	manual: boolean,
	again: boolean?,
	logged: number?
): Session?
	local old = bySlot[slot]
	if old then
		endSession(old)
	end
	local sessionCfg = configFor(slot)
	local state, actions = FtueRules.new(sessionCfg, join)
	if again then
		local first: Action = { kind = "reset" }
		table.insert(actions, 1, first)
	end
	local creature = lookup(slot)
	local session: Session = {
		slot = slot,
		player = player,
		reporter = player or (if manual then standIn else nil),
		logged = logged or 0,
		cfg = sessionCfg,
		state = state,
		-- A DONE at join saves no stage (the profile keeps what it has).
		saved = if state.stage == S.DONE then S.DONE else join.stage,
		groups = {},
		keep = nil,
		every = 0,
		input = false,
		mass = if creature then creature.mass else 0,
		gapDistance = nil,
		shown = false,
		fresh = join.attempts == 0 and join.stage == S.S0_LOADING,
		manual = manual,
	}
	if state.stage == S.DONE then
		-- 04 §9: complete (or banked): no script. The rules may still mark it complete.
		run(session, actions, {})
		return nil
	end
	bySlot[slot] = session
	if player then
		sessionOf[player] = session
	end
	run(session, actions, {})
	return session
end

-- Events from the game -------------------------------------------------------------------------

local function tickSession(session: Session, dt: number)
	local creature = lookup(session.slot)
	if creature == nil then
		return -- between creatures (a gulp's respawn); the prey went with the last one
	end
	local mass = creature.mass
	if mass ~= session.mass then
		session.mass = mass
		feed(session, { kind = "massChanged", mass = mass })
	end
	local hadInput = session.input
	session.input = false
	feed(session, { kind = "tick", dt = dt, hadInput = hadInput })
	if bySlot[session.slot] ~= session then
		return
	end

	local p = creature.root.Position
	local stage = session.state.stage
	if stage >= S.S5_CALL_HOME and stage <= S.S6_CHASE then
		if stage == S.S5_CALL_HOME then
			local at = WorldIndex.nurseryPathAt(p.X, p.Y, p.Z)
			if FtuePlan.crossedGap(cfg, at) then
				feed(session, { kind = "crossedGap" })
			end
		end
		-- TODO(S7-C1): `retreated`, back in the Nursery during the chase.
	end

	session.every += dt
	local everySecond = session.every >= cfg.director.every
	if everySecond then
		session.every = 0
		if session.state.stage == S.S5_CALL_HOME then
			local d = FtuePlan.gapDistance(cfg, p.X, p.Z)
			local last = session.gapDistance
			session.gapDistance = d
			-- TODO(S7-C2): inCurrent and coveDistance.
			feed(session, { kind = "moved", towardGap = last ~= nil and d < last })
		end
	end

	if FtueRules.isHeld(session.state) then
		return -- 04 §3.7: scripted prey idles where it is
	end
	if everySecond then
		keepUp(session, creature)
	end
	-- Steering (see the header).
	local state = session.state
	for id, group in session.groups do
		local alive, centre = PreyService.scriptedAlive(session.slot, id)
		if alive == 0 or centre == nil then
			session.groups[id] = nil
			continue
		end
		local target: Vector3?, speed: number? = nil, nil
		if group.homing then
			target, speed = p, group.homing
		elseif group.name == "glowfry" then
			target, speed = p, cfg.trait.speed
		elseif group.name == "swarmA" and state.stage <= S.S2_FIRST_BITE then
			-- 04 §3.6 B2: still until the T = 2.5 assist homes it (or the player swims away).
			-- 04 §4's drift inside 25 studs is B3's, from S3 (14 §4 row 34).
			local away = (centre - p).Magnitude > (group.awayBeyond or math.huge)
			local limit = group.followLimit
			if
				state.stage == S.S2_FIRST_BITE
				and group.followSpeed
				and limit
				and (state.fired.biteAssist or away)
			then
				local x, y, z = FtuePlan.followTarget(p.X, p.Y, p.Z, hx, hy, hz, limit)
				target, speed = Vector3.new(x, y, z), group.followSpeed
			end
		elseif group.krill and (centre - p).Magnitude <= cfg.feed.driftRadius then
			target, speed = p, cfg.feed.driftSpeed
		end
		PreyService.steerScripted(session.slot, id, target, speed)
	end
end

local function onHeartbeat(dt: number)
	acc += dt
	if acc < cfg.director.tick then
		return
	end
	local step = acc
	acc = 0
	for _, session in table.clone(bySlot) do
		if not session.manual then
			tickSession(session, step)
		end
	end
end

-- A `TutorialStep` value (09 §5.3; FtuePlan.Code) for `session`.
local function signal(session: Session, code: number)
	if code == C.LOADING_SHOWN then
		if session.fresh and not session.shown then
			session.shown = true
			TutorialService.onStep(session.reporter, 2, nil)
		end
		return
	end
	if FtuePlan.isInput(code) then
		session.input = true
	end
	local event = FtuePlan.eventOf(code)
	if event then
		feed(session, event)
	end
end

local function onTutorialStep(player: Player, code: number)
	local session = sessionOf[player]
	if session then
		signal(session, code)
		return
	end
	-- Before the session (or with none, for a finished account): keep what a session needs to
	-- catch up. onReady and leaving clear it.
	local e: Early = early[player] or { shown = false, loaded = false }
	early[player] = e
	e.shown = e.shown or code == C.LOADING_SHOWN
	e.loaded = e.loaded or code == C.LOADED
end

local function onReady(player: Player, slot: Slot)
	local data = DataService.get(player)
	local e = early[player]
	early[player] = nil
	if data == nil or sessionOf[player] then
		return
	end
	local session = begin(slot, player, {
		stage = data.ftue.stage,
		completed = data.ftue.completed,
		attempts = data.ftue.attempts,
		banked = data.stats.banks > 0,
		run = nil, -- TODO(B19, S12-C4): the resumed run (see the header)
	}, false, nil, data.ftue.logged)
	-- 04 §2.4's load fail-safes, for an account in the FTUE (see the header).
	local code, j = PlayerLifecycle.loadMode(player)
	local loadCtx = if code then LoadTime.failsafe(code) else nil
	if session and loadCtx and not data.ftue.completed then
		failsafe(session, loadCtx, AnalyticsRules.seconds(j or 0))
	end
	if session and e then
		if e.shown then
			signal(session, C.LOADING_SHOWN)
		end
		if e.loaded then
			signal(session, C.LOADED)
		end
	end
end

local function onLeaving(player: Player, _slot: Slot)
	early[player] = nil
	local session = sessionOf[player]
	if session then
		endSession(session)
	end
end

local function onScriptedEaten(slot: Slot, scriptedId: number, _preyId: string)
	local session = bySlot[slot]
	if session == nil then
		return
	end
	local group = session.groups[scriptedId]
	feed(session, { kind = "preyEaten", group = if group then group.name else nil })
end

-- A wild bite BiteService accepted (04 §3.1: S2 ends on any first prey).
local function onWildEaten(slot: Slot, _preyId: string)
	local session = bySlot[slot]
	if session then
		feed(session, { kind = "preyEaten" })
	end
end

-- Signals reach the session deferred, so a caller (a bite, a mass change) is never broken by the
-- script.
local function later(slot: Slot, event: Event)
	task.defer(function()
		local session = bySlot[slot]
		if session then
			feed(session, event)
		end
	end)
end

-- API -------------------------------------------------------------------------------------------

--- The saved stage of the player's running script (04 §3.1), nil when they have none.
function TutorialService.stage(player: Player): number?
	local session = sessionOf[player]
	return if session then session.state.stage else nil
end

--- Developer reset (04 §9, `/ftue reset`; Dev/Cheats calls it): clears the player's `ftue`
--- fields, puts the creature back on the Hatch Bed as a new Fry with no traits, and starts the
--- script again from the hatch, as for a new account (a bank on the account does not skip it).
--- The first cue is `reset`. Refused, with the reason "devCheats", where Config/Defaults has dev
--- cheats off (checked here too, whoever calls it); "noCreature" when the player has no profile
--- or creature.
function TutorialService.reset(player: Player): (boolean, string?)
	if not devCheats() then
		Log.warn(TAG, `/ftue reset refused for {player.UserId}: dev cheats are off here`)
		return false, "devCheats"
	end
	local data = DataService.get(player)
	local slot = PlayerLifecycle.getSlot(player)
	local creature = if slot then lookup(slot) else nil
	if data == nil or slot == nil or creature == nil then
		return false, "noCreature"
	end
	local old = sessionOf[player]
	if old then
		endSession(old)
	end
	DataService.patch(player, "ftue", {
		stage = S.S0_LOADING,
		completed = false,
		version = data.ftue.version,
		attempts = 0,
		logged = 0, -- the once-per-account events count again, as for a new account
	})
	TraitService.reset(slot)
	CreatureService.addMass(slot, -creature.mass)
	CreatureService.teleport(slot, CFrame.lookAt(HATCH, routeVector(cfg.layout.swarmA)))
	local session = begin(slot, player, {
		stage = S.S0_LOADING,
		completed = false,
		attempts = 0,
		banked = false,
		run = nil,
	}, false, true, 0)
	if session then
		signal(session, C.LOADED) -- the loading screen is long gone
	end
	return session ~= nil, if session then nil else "noCreature"
end

--- Whether `start` has run (the engine spec starts the service itself on Open Cloud).
function TutorialService.isRunning(): boolean
	return running
end

function TutorialService.init()
	sessionOf, bySlot, early, seqOf, acc = {}, {}, {}, {}, 0
end

function TutorialService.start()
	running = true
	Server.on(
		"TutorialStep",
		{ Server.Validate.int(FtuePlan.CODE_MIN, FtuePlan.CODE_MAX) },
		onTutorialStep
	)
	PlayerLifecycle.onReady:connect(onReady)
	PlayerLifecycle.onLeaving:connect(onLeaving)
	PreyService.onScriptedEaten:connect(onScriptedEaten)
	PreyService.onWildEaten:connect(onWildEaten)
	CreatureService.onTierChanged:connect(function(slot: Slot, tier: number)
		later(slot, { kind = "tierReached", tier = tier })
	end)
	TraitService.onGained:connect(function(slot: Slot, traitId: string, _index: number)
		-- 04 §3.6 B5: only the FTUE's first trait ends S4.
		local session = bySlot[slot]
		if session and traitId == session.cfg.arms.firstTrait then
			later(slot, { kind = "traitGained", trait = traitId })
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		early[player] = nil
		seqOf[player] = nil
	end)
	RunService.Heartbeat:Connect(onHeartbeat)
end

-- Engine-spec hooks (src/server/Tests/TutorialSpec). Not for game code. Sessions begun here have
-- no player, are ticked only by `tick`, and send their saves and cues to the stub's sink.
TutorialService._test = table.freeze({
	--- Reads creatures from `find` and hands the stand-in's saves and cues to `out(kind, path,
	--- value)`, kind "save" or "cue" (nil for both: the real ones).
	stub = function(find: ((Slot) -> CreatureState?)?, out: ((string, string, any) -> ())?)
		lookup = find or CreatureService.get
		sink = out
	end,
	--- Starts a stand-in session in `slot` from `join`; false when the account never enters it.
	--- `again`: as after `/ftue reset` (the first cue is `reset`); `logged`: the profile's
	--- `ftue.logged` (0 when nil).
	begin = function(slot: Slot, join: FtueRules.Join, again: boolean?, logged: number?): boolean
		return begin(slot, nil, join, true, again, logged) ~= nil
	end,
	--- The stand-in player the sessions begun here report to Analytics as (nil: none, so
	--- nothing reaches Analytics). A table with `UserId` is enough.
	reporter = function(player: any?)
		standIn = player
	end,
	--- Feeds one FtueRules event to the stand-in in `slot` (events the spec cannot cause).
	feed = function(slot: Slot, event: Event)
		local session = bySlot[slot]
		if session then
			feed(session, event)
		end
	end,
	--- The session config of `slot` (its `arms.traitCount`), nil for none.
	config = function(slot: Slot): Config?
		local session = bySlot[slot]
		return if session then session.cfg else nil
	end,
	--- A `TutorialStep` value for the stand-in in `slot`.
	signal = function(slot: Slot, code: number)
		local session = bySlot[slot]
		if session then
			signal(session, code)
		end
	end,
	--- One tick of `dt` seconds for the session in `slot`.
	tick = function(slot: Slot, dt: number)
		local session = bySlot[slot]
		if session then
			tickSession(session, dt)
		end
	end,
	--- The FtueRules state of `slot`'s session, nil for none.
	state = function(slot: Slot): State?
		local session = bySlot[slot]
		return if session then session.state else nil
	end,
	--- Scripted ID → FtueRules group name of `slot`'s session.
	groups = function(slot: Slot): { [number]: string }
		local out = {}
		local session = bySlot[slot]
		if session then
			for id, group in session.groups do
				out[id] = group.name
			end
		end
		return out
	end,
	--- Ends `slot`'s session and its scripted prey.
	finish = function(slot: Slot)
		local session = bySlot[slot]
		if session then
			endSession(session)
		end
	end,
	--- Every onStep and onFailsafe call since the last `clearLog`.
	log = function(): { { kind: string, value: any } }
		return hookLog
	end,
	clearLog = function()
		table.clear(hookLog)
	end,
})

return TutorialService
