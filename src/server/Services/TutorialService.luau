--!strict
-- TutorialService: the server half of the first-time script (task S6-C2, module B31; docs/04,
-- sections 3, 4 and 9; docs/09, sections 5.1, 5.3 and 12.2; docs/10, section 3.1). It owns
-- `ftue.stage` (04 §3.1: the server owns the stage and saves it); the client's TutorialDirector
-- plays the presentation. The stage machine is the pure Logic/FtueRules, the route and the
-- `TutorialStep` values are Logic/FtuePlan, and every number is Config/FtueConfig's.
--
-- Join     on PlayerLifecycle.onReady, FtueRules.new from the profile's `ftue` and `stats.banks`.
--          An account with `ftue.completed` (or a bank) never gets a session. A saved stage past
--          S0 with no run to resume restarts the script in the fast or short form (04 §9).
--          TODO(B19, S12-C4): pass the resumed run (`RunLoopService.resume`) so a rejoin carries on
--          from the saved stage instead.
-- Feeding  FtueRules hears: the client's `TutorialStep` reports (FtuePlan.Code: loading done, tap,
--          steering, background; 2 is onboarding step 02 and goes to `onStep`), held until the
--          session exists; `controlGained` right after its own `giveControl`; PreyService's
--          `onScriptedEaten` (the group's FtueRules name) and, for wild prey, a rise in the
--          creature's mass; `massChanged`; CreatureService.onTierChanged; TraitService.onGained;
--          from S5, `moved` (towards the Gap, once a second) and `crossedGap` (a `NurseryPath`
--          place past the Gap); and a `tick` ten times a second with whether any input came.
-- Prey     every scripted group is PreyService.spawnScripted for the player's slot alone, `calm`
--          (04 §4: FTUE krill never scatter), at FtueConfig's distances along the route (FtuePlan).
--          Each tick it is steered (PreyService.steerScripted) toward the player's root:
--            homing    a `homePrey`, `feedNearest` or `spawnBurst` group, at that speed;
--            glowfry   at the trait speed, its leash the circle radius (04 §3.6 B5);
--            swarmA    toward the player held within the follow limit of the hatch point (B2);
--            krill     any other krill within the drift radius, at the drift speed (B3, §4);
--            plankton  never.
--          A hold (04 §3.7) stops all of it where it is. `keepKrill` tops the scripted krill within
--          its radius up to its count once a second, with a ball at the drift radius ahead.
-- Saves    `ftue.stage` on every stage change, `ftue.completed` and `ftue.attempts` when the rules
--          say, through DataService.patch, which also sends them to the owner as `State`.
-- Client   one `State` per batch of actions, path `ftue.cue` (not saved, as TraitService sends
--          `run.traits`), value { seq = n, actions = { Action, ... } }: the presentation actions
--          of FtueRules (its header lists their fields), in order, seq rising by one per batch.
--          Kinds: hatch, giveControl, hold, prompt, hud, pulse, music, openFog, openCurtain,
--          predatorShadow, startChase, autoDash, startCurrent, reformCurrent, pull, bankSequence,
--          coveItem, exitTrail, feedNearest.
-- Hooks    `onStep(player, step, ctx)` and `onFailsafe(player, kind)` for every onboarding step
--          and `ftue_failsafe` the rules emit. TODO(S6-C6): Analytics (10 §3.1, §4.2), with
--          `ftue_milestone`, `ftue_bite_assist` and `ftue_chase_result`.
-- Later    TODO(S7-C1): the chase (`startChase`, `autoDash`, `dashed`, `retreated`, `chaseEnded`).
--          TODO(S7-C2): the Home Current (`startCurrent`, `reformCurrent`, `moved` inCurrent and
--          coveDistance). TODO(S7-C3): the bank (`enteredCoveMouth`, `bankSequence`, `fryHatched`,
--          `leftCoveMouth`, `runEnded`, the cove's `spawnLure` and `denseKrill`). TODO(S7-C6): the
--          kelp curtain gate, B6's `spawnLure` home and `pull` gap.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FtueConfig = require(ReplicatedStorage.Shared.Config.FtueConfig)
local FtuePlan = require(ReplicatedStorage.Shared.Logic.FtuePlan)
local FtueRules = require(ReplicatedStorage.Shared.Logic.FtueRules)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Types = require(ReplicatedStorage.Shared.Types)

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

local TAG = "Tutorial"
local TICK = 0.1 -- s: the stage machine's tick (its timers are 0.4 s and longer)
local EVERY = 1.0 -- s: the `keepKrill` check and the `moved` report
local MAX_BALL = 24 -- members in one scripted ball (PreySim.MAX_MEMBERS)

local S = FtueRules.Stage
local C = FtuePlan.Code

-- The actions the client presents (see the header); the rest are the server's.
local PRESENT: { [string]: boolean } = table.freeze({
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
}

type Session = {
	slot: Slot,
	player: Player?, -- nil for the engine spec's stand-in
	state: State,
	saved: number, -- the stage last saved
	groups: { [number]: Group }, -- by scripted ID
	keep: { count: number, radius: number }?,
	every: number, -- seconds since the last keep check and moved report
	input: boolean, -- a tap or steering report since the last tick
	scripted: boolean, -- a scripted bite since the last tick
	mass: number, -- the creature's mass at the last tick
	gapDistance: number?, -- at the last moved report
	seq: number,
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
local running = false
local acc = 0
-- Where creatures come from and where the stand-in's saves and cues go (`_test.stub`).
local lookup: (Slot) -> CreatureState? = CreatureService.get
local sink: ((kind: string, path: string, value: any) -> ())? = nil
-- The hooks' record, for the engine spec: { kind = "step" | "failsafe", value = ... }.
local hookLog: { { kind: string, value: any } } = {}

local hx, hy, hz = FtuePlan.routePoint(0)
local HATCH = Vector3.new(hx, hy, hz)
local GLOWFRY = FtuePlan.traitPreyFor(cfg.arms.firstTrait)

local function routeVector(s: number): Vector3
	local x, y, z = FtuePlan.routePoint(s)
	return Vector3.new(x, y, z)
end

-- Hooks ---------------------------------------------------------------------------------------

--- An onboarding funnel step (10 §3.1) the script reached. TODO(S6-C6): Analytics.step.
function TutorialService.onStep(player: Player?, step: number, ctx: string?)
	table.insert(hookLog, { kind = "step", value = step })
	if player then
		Log.info(TAG, `onboarding step {step} for {player.UserId}{if ctx then " " .. ctx else ""}`)
	end
end

--- An `ftue_failsafe` (04 §3.6, §3.7; 10 §4.2). TODO(S6-C6): Analytics.event.
function TutorialService.onFailsafe(player: Player?, kind: string)
	table.insert(hookLog, { kind = "failsafe", value = kind })
	if player then
		Log.info(TAG, `ftue_failsafe {kind} for {player.UserId}`)
	end
end

-- Control comes at the end of the hatch (04 §2.1 phase E): `sys_load_time`.
-- TODO(S6-C1, PR #164): call PlayerLifecycle.controlGranted(player) here once it is on main.
local function grantControl(_session: Session) end

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
	session.seq += 1
	local value = { seq = session.seq, actions = cues }
	local player = session.player
	if player then
		Server.send(player, "State", "ftue.cue", value)
	elseif sink then
		sink("cue", "ftue.cue", value)
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
		spawn(
			session,
			"swarmA",
			ball(FtuePlan.KRILL, a.count or 1, routeVector(a.distance or 0), (a.width or 0) / 2),
			{
				name = "swarmA",
				krill = true,
				followSpeed = a.speed,
				followLimit = a.limit,
			}
		)
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
	elseif kind == "step" then
		TutorialService.onStep(session.player, a.step :: number, nil)
	elseif kind == "failsafe" then
		TutorialService.onFailsafe(session.player, a.ctx :: string)
	end
	-- TODO(S6-C6): milestone, biteAssist and chaseResult to Analytics.
	-- TODO(S7-C3, S7-C6): spawnLure and denseKrill (see the header).
end

-- Runs the actions, then every event they queued (`controlGained`), then saves the stage and sends
-- the batch.
local function run(session: Session, actions: { Action }, queue: { Event })
	local cues: { Action } = {}
	for _, a in actions do
		perform(session, a, queue, cues)
	end
	while #queue > 0 do
		local event = table.remove(queue, 1) :: Event
		local state, more = FtueRules.handle(cfg, session.state, event)
		session.state = state
		for _, a in more do
			perform(session, a, queue, cues)
		end
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

-- Starts the script for `slot` from `join`; nil when the account never enters it.
local function begin(slot: Slot, player: Player?, join: FtueRules.Join, manual: boolean): Session?
	local old = bySlot[slot]
	if old then
		endSession(old)
	end
	local state, actions = FtueRules.new(cfg, join)
	local creature = lookup(slot)
	local session: Session = {
		slot = slot,
		player = player,
		state = state,
		saved = join.stage,
		groups = {},
		keep = nil,
		every = 0,
		input = false,
		scripted = false,
		mass = if creature then creature.mass else 0,
		gapDistance = nil,
		seq = 0,
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
		local rose = mass > session.mass
		session.mass = mass
		if rose and not session.scripted then
			feed(session, { kind = "preyEaten" }) -- a wild bite (04 §3.1: any first prey)
		end
		feed(session, { kind = "massChanged", mass = mass })
	end
	session.scripted = false
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
	local everySecond = session.every >= EVERY
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
		elseif group.followSpeed and group.followLimit then
			local x, y, z = FtuePlan.followTarget(p.X, p.Y, p.Z, hx, hy, hz, group.followLimit)
			target, speed = Vector3.new(x, y, z), group.followSpeed
		elseif group.krill and (centre - p).Magnitude <= cfg.feed.driftRadius then
			target, speed = p, cfg.feed.driftSpeed
		end
		PreyService.steerScripted(session.slot, id, target, speed)
	end
end

local function onHeartbeat(dt: number)
	acc += dt
	if acc < TICK then
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
			TutorialService.onStep(session.player, 2, nil)
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
	}, false)
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
	session.scripted = true
	feed(session, { kind = "preyEaten", group = if group then group.name else nil })
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

--- Developer reset (04 §9, `/ftue reset`; Dev/Cheats calls it, dev places only): clears the
--- player's `ftue` fields, puts the creature back on the Hatch Bed as a new Fry with no traits, and
--- starts the script again from the hatch, as for a new account (a bank on the account does not
--- skip it). False when the player has no profile or creature.
function TutorialService.reset(player: Player): boolean
	local data = DataService.get(player)
	local slot = PlayerLifecycle.getSlot(player)
	local creature = if slot then lookup(slot) else nil
	if data == nil or slot == nil or creature == nil then
		return false
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
	}, false)
	if session then
		signal(session, C.LOADED) -- the loading screen is long gone
	end
	return session ~= nil
end

--- Whether `start` has run (the engine spec starts the service itself on Open Cloud).
function TutorialService.isRunning(): boolean
	return running
end

function TutorialService.init()
	sessionOf, bySlot, early, acc = {}, {}, {}, 0
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
	CreatureService.onTierChanged:connect(function(slot: Slot, tier: number)
		later(slot, { kind = "tierReached", tier = tier })
	end)
	TraitService.onGained:connect(function(slot: Slot, traitId: string, _index: number)
		later(slot, { kind = "traitGained", trait = traitId })
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		early[player] = nil
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
	begin = function(slot: Slot, join: FtueRules.Join): boolean
		return begin(slot, nil, join, true) ~= nil
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
