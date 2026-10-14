--!strict
-- RunLoopService: the run lifecycle (task S4-C4, module B19, first part; docs/09, sections 5.1,
-- 5.3, 6.3 and 6.8; docs/02, sections 0.7, 5.1 and 12; canon 5.5). It owns one `RunState` per
-- slot and the `Phase` attribute (`cove`, `run`, `dead`) after CreatureService's first write.
-- The pure rules (phase transitions, respawn timing, the return rule) are Logic/RunRules.
--
-- Join     PlayerLifecycle asks `join` where the creature appears: the Nursery for an account that
--          has never banked (its first run), else the own cove. `Phase = cove`.
-- Start    ten times a second the centre of every creature in `cove` is tested against its home
--          volume; leaving it calls `startRun` (`Phase = run`; 09 §5.1 names it `start(player)`,
--          which would clash with the service's own `start()` of section 4.5). Re-entering home with mass < 1
--          cancels the run silently (02 §0.7 item 3).
-- Gulped   `gulp(slot, by)`: `Phase = dead`, owner nil, anchored, `CreatureEvent` "gulped"; after
--          the client's 0.8 s gulp effect the creature is moved to its cove spawn and reset to the
--          species' start mass; at 2.0 s it is released to its owner with `Phase = cove`.
-- Tier     every `CreatureService.onTierChanged` sends `CreatureEvent` "tier" to everyone (the
--          tier-up clip, pop and FX play on every client, 02 §5.1); a rise also gives 1.0 s of
--          `Protected(tierUp)`.
--
-- CreatureEvent payloads (plain arguments, 09 §5.3), first argument the kind:
--   "gulped", slot, by       by: who or what ate it ("player:<slot>", a predator ID, ...)
--   "tier",   slot, tier, previousTier
-- Later parts by sprint (docs/13): bank and settle with BankMath, scraps (S5-C3); mid-run
-- disconnect, suspend and resume (S12-C4); the revive offer and Revive (S14-C1).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Index = require(ReplicatedStorage.Shared.Data.Index)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local RunRules = require(ReplicatedStorage.Shared.Logic.RunRules)
local Types = require(ReplicatedStorage.Shared.Types)
local VolumeMath = require(ReplicatedStorage.Shared.Logic.VolumeMath)

local CreatureService = require("./CreatureService")
local Server = require("../Net/Server")
local WorldIndex = require("./WorldIndex")

type Slot = Types.Slot
type Volume = Types.Volume
export type RunPhase = RunRules.Phase
type Home = RunRules.Home

--- One slot's run (09 §5.1: "RunState per slot"). Mass, traits and progress live in
--- CreatureService's CreatureState; the profile's `run` record is S12-C4's.
export type RunState = {
	slot: Slot,
	player: Player,
	phase: RunPhase,
	home: Home, -- where the current run starts and may be cancelled
	startedAt: number?, -- server time of `start`; nil outside a run
	gulpedAt: number?, -- server time of the last gulp while dead
	gulpedBy: string?,
	tier: number?, -- the tier last announced, for the "tier" event's previous tier
	generation: number, -- bumped on every gulp and on leave, so stale timers do nothing
}

local TAG = "RunLoop"
local SCAN_INTERVAL = 0.1 -- seconds between home-volume tests (tune)
local MAX_SLOT = 24 -- 09 §5.1: slots 1 to 24

local RunLoopService = {}
RunLoopService.name = "RunLoopService"

local runs: { [Slot]: RunState } = {}
local coveVolumes: { [Slot]: { Volume } } = {}
local nurseries: { Volume } = {}
local sinceScan = 0
local NONE: { Volume } = table.freeze({})
local lastSent: { any }? = nil -- the last CreatureEvent, for the engine spec

-- CreatureEvent to everyone (others play the same burst and pop, 02 §5.1; the gulp camera, 3.6).
local function sendEvent(...: any)
	lastSent = { ... }
	Server.sendAll("CreatureEvent", ...)
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function setPhase(run: RunState, phase: RunPhase)
	run.phase = phase
	run.player:SetAttribute("Phase", phase)
end

local function inside(list: { Volume }, p: Vector3): boolean
	return VolumeMath.firstContaining(list, p.X, p.Y, p.Z) ~= nil
end

local function inOwnCove(slot: Slot, p: Vector3): boolean
	local list = coveVolumes[slot]
	return list ~= nil and inside(list, p)
end

local function runOf(player: Player): RunState?
	local slot = player:GetAttribute("Slot")
	local run = if type(slot) == "number" then runs[slot] else nil
	return if run and run.player == player then run else nil
end

-- The Nursery spawn: the first SafeNursery volume's centre, facing along its look vector.
-- TODO(B31, S6-C2): the Hatch Bed point of 04 §3.5 once the map marks it; 09 §9.1 has no volume
-- kind for it yet.
local function nurseryCFrame(): CFrame?
	local v = nurseries[1]
	if v == nil then
		return nil
	end
	local at = Vector3.new(VolumeMath.centre(v))
	local look = Vector3.new(VolumeMath.lookVector(v))
	return CFrame.lookAlong(at, look)
end

-- Applies one RunRules event to `run`; returns the outcome.
local function apply(run: RunState, event: RunRules.Event): RunRules.Outcome?
	local state = CreatureService.get(run.slot)
	local mass = if state then state.mass else 0
	local phase: RunPhase, outcome: RunRules.Outcome? = RunRules.transition(run.phase, event, mass)
	if outcome == nil then
		return nil
	end
	if phase ~= run.phase then
		setPhase(run, phase)
	end
	if outcome == "start" then
		run.startedAt = now()
		-- TODO(B21, S5-C1): `run_start` analytics; TODO(B20, S12-C4): the profile's run record.
	elseif outcome == "cancel" then
		run.startedAt = nil
	elseif outcome == "bank" then
		RunLoopService.bank(run.player)
	end
	return outcome
end

-- Ten times a second: start runs that left home, cancel or bank runs that came back.
local function scan()
	for slot = 1, MAX_SLOT do
		local run = runs[slot]
		local state = if run then CreatureService.get(slot) else nil
		if run and state then
			local p = state.root.Position
			if run.phase == "cove" then
				local home = if run.home == "nursery" then nurseries else coveVolumes[slot] or NONE
				if not inside(home, p) then
					RunLoopService.startRun(run.player)
				end
			elseif run.phase == "run" then
				if inOwnCove(slot, p) then
					apply(run, "enteredCove")
				elseif run.home == "nursery" and inside(nurseries, p) then
					apply(run, "enteredNursery")
				end
			end
		end
	end
end

local function onTierChanged(slot: Slot, tier: number)
	local run = runs[slot]
	local state = CreatureService.get(slot)
	if run == nil or state == nil then
		return
	end
	-- Before the first change the creature is at its species' start tier (CreatureService.spawn).
	local before = run.tier or Index.Species.byId[state.species].startTier
	run.tier = tier
	if run.phase == "dead" then
		return -- the respawn reset: the attributes carry it, no celebration
	end
	sendEvent("tier", slot, tier, before)
	if tier > before then
		-- 02 §5.1: Protected(tierUp) for 1.0 s on a rise; no protection on a fall.
		CreatureService.protect(slot, "tierUp", RunRules.TIER_UP_PROTECT_SECONDS)
		-- TODO(B29, S9): CodexService.discover(player, "tier", ...) for every tier passed.
	end
	-- TODO(B14, S8-C2): MovementValidator.grace(slot, RunRules.TIER_GRACE_SECONDS) (09 §6.8);
	-- CreatureService.addMass carries the same TODO.
end

function RunLoopService.init()
	runs, coveVolumes, nurseries, sinceScan = {}, {}, {}, 0
end

function RunLoopService.start()
	for _, kind in { "CoveInterior", "CoveMouth" } do
		for _, v in WorldIndex.volumesOf(kind) do
			local index = v.attrs.CoveIndex
			if type(index) == "number" then
				local list = coveVolumes[index] or {}
				table.insert(list, v)
				coveVolumes[index] = list
			end
		end
	end
	nurseries = WorldIndex.volumesOf("SafeNursery")
	CreatureService.onTierChanged:connect(onTierChanged)
	RunService.Heartbeat:Connect(function(dt: number)
		sinceScan += dt
		if sinceScan >= SCAN_INTERVAL then
			sinceScan = 0
			scan()
		end
	end)
end

--- Called by PlayerLifecycle just before `CreatureService.spawn`: creates the slot's RunState
--- (`Phase = cove`) and returns where the creature appears (09 §6.3 Join row).
function RunLoopService.join(player: Player, slot: Slot): CFrame
	-- TODO(B20, S4-C6): `hasBanked` from the profile (DataService); until it lands every account
	-- is treated as never banked, so every join starts in the Nursery.
	local hasBanked = false
	local home: Home = RunRules.joinHome(hasBanked)
	local at = if home == "nursery" then nurseryCFrame() else nil
	if at == nil then
		home = "cove" -- a map with no Nursery (none yet in some test places)
		at = CreatureService.coveSpawnCFrame(slot)
	end
	local old = runs[slot]
	runs[slot] = {
		slot = slot,
		player = player,
		phase = "cove",
		home = home,
		startedAt = nil,
		gulpedAt = nil,
		gulpedBy = nil,
		tier = nil,
		generation = if old then old.generation + 1 else 1,
	}
	-- TODO(B19, S12-C4): a suspended run resumes here instead (`resume`, 12.5).
	return at :: CFrame
end

--- Run start (09 §6.3; 09 §5.1's `start(player)`, renamed so it does not clash with the service
--- `start()` of section 4.5): the player swam out of the run's home. `Phase = run`. Does nothing
--- outside the `cove` phase.
function RunLoopService.startRun(player: Player)
	local run = runOf(player)
	if run then
		apply(run, "leftHome")
	end
end

--- Banks the run when the player enters their own cove armed (02 §11; canon 5.4).
--- TODO(B19, S5-C3): BankMath, Pearls through EconomyService, the specimen, the reset to a Fry
--- and `Phase = cove`. Until then an armed run stays a run inside the cove.
function RunLoopService.bank(player: Player)
	local run = runOf(player)
	if run then
		Log.once("info", TAG, "bank is not written yet (S5-C3): the run goes on")
	end
end

--- The creature of `slot` was gulped by `by` ("player:<slot>", a predator ID, a hazard).
--- Returns false when the creature is not in a run. Runs 09 §6.3's Gulped row: released at its
--- cove after 2.0 s.
function RunLoopService.gulp(slot: Slot, by: string): boolean
	local run = runs[slot]
	local state = CreatureService.get(slot)
	if run == nil or state == nil or apply(run, "gulped") ~= "gulp" then
		return false
	end
	local player, root = run.player, state.root
	run.generation += 1
	local generation = run.generation
	run.gulpedAt, run.gulpedBy, run.startedAt = now(), by, nil
	root:SetNetworkOwner(nil)
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	sendEvent("gulped", slot, by)
	-- TODO(B19, S5-C3): scraps (BankMath.scraps) and run-end settlement; TODO(B19, S6-C3):
	-- unbanked traits are lost; TODO(B19, S14-C1): `offerRevive` holds `dead` until the choice
	-- (09 §6.3); TODO(B23, S4-C5): 02 §12.1 respawns on the gulp card's "Swim again" tap (a
	-- `RunAction` op not yet in 09 §5.3); until both exist the respawn runs on the 2.0 s budget.
	local releaseAt, moveAt = RunRules.respawnTimes(run.gulpedAt :: number)
	local function current(): boolean
		return runs[slot] == run
			and run.generation == generation
			and CreatureService.get(slot) == state
	end
	task.delay(math.max(0, moveAt - now()), function()
		if not current() then
			return
		end
		CreatureService.teleport(slot, CreatureService.coveSpawnCFrame(slot))
		local def = Index.Species.byId[state.species]
		local startMass = Index.Tiers.byTier[def.startTier].massNeeded
		CreatureService.addMass(slot, startMass - state.mass) -- tier 1, or 2 for the Shark Pup
		task.delay(math.max(0, releaseAt - now()), function()
			if not current() or player.Parent ~= Players then
				return
			end
			root.Anchored = false
			root:SetNetworkOwner(player)
			run.home = RunRules.respawnHome()
			run.gulpedAt, run.gulpedBy = nil, nil
			apply(run, "respawned")
			-- TODO(B14, S8-C2): MovementValidator.grace(slot, RunRules.RESPAWN_GRACE_SECONDS).
		end)
	end)
	return true
end

--- Offers the one revive of the run (canon 5.5; 09 §6.3: not on the first death, 30 mass or
--- more, no countdown). TODO(B19, S14-C1): the offer, `Protected` 3 s, mass × 0.7 and placement
--- by the return rule (RunRules.returnPoint).
function RunLoopService.offerRevive(_player: Player) end

--- Leave settlement for a mid-run disconnect (canon 5.5; 02 §16.4). TODO(B19, S12-C4): 10 s in
--- the water, then the run saved as suspended for 5 minutes. For now the run is forgotten.
function RunLoopService.suspendOnLeave(player: Player)
	local run = runOf(player)
	if run then
		run.generation += 1
		runs[run.slot] = nil
	end
end

--- Resumes a suspended run on rejoin (09 §6.3, 12.5): the return rule, mass, traits and progress,
--- `Phase = run`, `Protected` 3 s. TODO(B19, S12-C4). Returns whether a run was resumed.
function RunLoopService.resume(_player: Player): boolean
	return false
end

--- Settles a suspended run that expired (scraps paid; 02 §16.5). TODO(B19, S5-C3 and S12-C4).
function RunLoopService.settleExpired(_player: Player) end

--- The phase of `slot`'s run; `cove` for a slot with no run.
function RunLoopService.state(slot: Slot): RunPhase
	local run = runs[slot]
	return if run then run.phase else "cove"
end

-- Engine-spec hook (src/server/Tests/RunLoopSpec). Not for game code.
RunLoopService._test = table.freeze({
	run = function(slot: Slot): RunState?
		return runs[slot]
	end,
	scan = scan,
	lastSent = function(): { any }?
		return lastSent
	end,
	coveVolumes = function(slot: Slot): { Volume }
		return coveVolumes[slot] or {}
	end,
	nurseries = function(): { Volume }
		return nurseries
	end,
})

return RunLoopService
