--!strict
-- RunLoopService: the run lifecycle (task S4-C4, module B19, first part; docs/09, sections 5.1,
-- 5.3, 6.3 and 6.8; docs/02, sections 0.7, 5.1 and 12; canon 5.5). It owns one `RunState` per
-- slot and the `Phase` attribute (`cove`, `run`, `dead`) after CreatureService's first write.
-- The pure rules (phase transitions, respawn timing, the return rule) are Logic/RunRules.
--
-- Join     PlayerLifecycle asks `join(player, slot)` where the creature appears: the `HatchBed`
--          volume (09 §9.1) for an account that has never banked (its first run; the Nursery
--          centre, with a log, on a map without one), else the own cove. `Phase = cove`.
-- Start    ten times a second the centre of every creature in `cove` is tested against its home
--          volume; leaving it calls `startRun(player)` (`Phase = run`). Re-entering home with
--          mass < 1 cancels the run silently (02 §0.7 item 3). Re-entering the own cove armed
--          banks (below).
-- Bank     the centre inside the own `CoveMouth` or `CoveInterior` in a run with mass ≥ 1 (02
--          §0.7, §11.2; task S5-C3). One synchronous block (09 §13.4): Pearls through
--          EconomyService by the SKUs of 10 §5.1, Reef Rank points without Deep Pockets, a
--          specimen at tier 2 or higher (`pendingSpecimen` when the cove is full), stats, the
--          profile's run cleared, `run_banked`. Then `Phase = cove`, `CreatureEvent` "banked", and
--          the creature starts again as its species' start tier at the cove spawn (02 §11.3).
-- Settle   `settleExpired` at join, before the first spawn (09 §12.5): a saved run that expired
--          pays its `onExpiry` (scraps, or the full bank in Pearls), no specimen.
-- Gulped   `gulp(slot, by)`: `Phase = dead`, owner nil, anchored, `CreatureEvent` "gulped". The
--          server then waits, with no timeout, for "Swim again" (`RunAction` op 1, 09 §5.3),
--          accepted from 1.2 s after the gulp (the card, 02 §12.1). From the tap: moved to the
--          cove spawn and reset to the species' start mass at 0.3 s (the client's fade out),
--          released to its owner with `Phase = cove` at 0.6 s (02 §12.4: within 0.8 s).
-- Tier     every `CreatureService.onTierChanged` sends `CreatureEvent` "tier" to everyone (the
--          tier-up clip, pop and FX play on every client, 02 §5.1); a rise also gives 1.0 s of
--          `Protected(tierUp)`.
--
-- CreatureEvent payloads (plain arguments, 09 §5.3), first argument the kind:
--   "gulped", slot, by       by: who or what ate it ("player:<slot>", a predator ID, ...)
--   "tier",   slot, tier, previousTier
--   "banked", slot, mass, pearls, crystal, deepPockets, best, specimen
--             mass the banked mass; pearls what the bank paid; crystal and deepPockets the
--             multipliers applied; best a new best mass; specimen "added", "full" (kept as
--             `pendingSpecimen`) or "none" (tier 1, or refused)
-- Later parts by sprint (docs/13): the bank sequence (S7-C3); scraps on a gulp and the gulp's
-- settlement (S12-C3); mid-run disconnect, suspend and resume (S12-C4); the revive offer and
-- Revive (S14-C1).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BankMath = require(ReplicatedStorage.Shared.Logic.BankMath)
local Index = require(ReplicatedStorage.Shared.Data.Index)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local RunRules = require(ReplicatedStorage.Shared.Logic.RunRules)
local TraitRules = require(ReplicatedStorage.Shared.Logic.TraitRules)
local Types = require(ReplicatedStorage.Shared.Types)
local VolumeMath = require(ReplicatedStorage.Shared.Logic.VolumeMath)

local Analytics = require("./Analytics")
local CoveService = require("./CoveService")
local CreatureService = require("./CreatureService")
local DataService = require("./DataService")
local EconomyService = require("./EconomyService")
local Server = require("../Net/Server")
local WorldIndex = require("./WorldIndex")

type Slot = Types.Slot
type Volume = Types.Volume
export type RunPhase = RunRules.Phase
type Home = RunRules.Home
type ProfileData = Types.ProfileData

--- What one bank paid and kept (the "banked" event; the engine spec reads the last one).
export type Banked = {
	slot: Slot,
	mass: number,
	tier: number,
	pearls: number,
	crystal: boolean,
	deepPockets: boolean,
	best: boolean,
	specimen: "added" | "full" | "none",
}

--- One slot's run (09 §5.1: "RunState per slot"). Mass, traits and progress live in
--- CreatureService's CreatureState; the profile's `run` record is S12-C4's.
export type RunState = {
	slot: Slot,
	player: Player,
	phase: RunPhase,
	home: Home, -- where the current run starts and may be cancelled
	startedAt: number?, -- server time of `start`; nil outside a run
	gulpedAt: number?, -- server time of the last gulp while dead
	respawning: boolean, -- "Swim again" was accepted; the respawn timers are running
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
local lastBanked: Banked? = nil

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

local hatchBeds: { Volume } = {}
local payBank: (run: RunState) -> ()

local function runOf(player: Player): RunState?
	local slot = player:GetAttribute("Slot")
	local run = if type(slot) == "number" then runs[slot] else nil
	return if run and run.player == player then run else nil
end

-- The first-run spawn (09 §9.1, 04 §3.5): the `HatchBed` volume's centre, facing along its look
-- vector; on a map without one, the first SafeNursery volume's, with a log.
local function nurseryCFrame(): CFrame?
	local v = hatchBeds[1]
	if v == nil then
		v = nurseries[1]
		if v == nil then
			return nil
		end
		Log.once(
			"warn",
			TAG,
			"no HatchBed volume (09 §9.1): first runs start at the Nursery centre"
		)
	end
	local at = Vector3.new(VolumeMath.centre(v))
	local look = Vector3.new(VolumeMath.lookVector(v))
	return CFrame.lookAlong(at, look)
end

-- Deep Pockets (05 §3.1). TODO(B23, S10-C2): ShopService.owns(player, "pass_deep_pockets"); until
-- then the profile's last answer from Roblox (`passes`, 09 §12.2).
local function deepPockets(profile: ProfileData): boolean
	return profile.passes.pass_deep_pockets == true
end

-- Pays a bank of `mass` at `tier` by 10 §5.1's SKUs (base, then the Crystal and Deep Pockets
-- extras) and adds its Reef Rank points (09 §13.4 steps 2 and 3). Returns the Pearls paid.
local function grantBank(
	player: Player,
	profile: ProfileData,
	mass: number,
	tier: number,
	crystal: boolean,
	deep: boolean
): number
	local parts = BankMath.parts(mass, crystal, deep)
	local amounts = { parts.base, parts.crystal, parts.deepPockets }
	local skus = { BankMath.bankSku(tier), "bank_crystal", "bank_deep_pockets" }
	local paid = 0
	for k, amount in amounts do
		if amount > 0 and EconomyService.grant(player, amount, "Bank", skus[k]) then
			paid += amount
		end
	end
	DataService.patch(
		player,
		"rank.points",
		profile.rank.points + BankMath.bankRankPoints(mass, crystal)
	)
	return paid
end

-- Ends the run and adds it to `newcomer.runsCompleted` (09 §12.2), clearing the saved `run`.
local function endRun(player: Player, profile: ProfileData)
	DataService.patch(player, "newcomer.runsCompleted", profile.newcomer.runsCompleted + 1)
	if profile.run ~= nil then
		DataService.patch(player, "run", nil)
	end
end

-- The bank of 09 §13.4, one synchronous block (no yield, so a disconnect cannot split it), then
-- the start again at the cove (02 §11.3). `run.phase` is already `cove`.
function payBank(run: RunState)
	local player, slot = run.player, run.slot
	local state = CreatureService.get(slot)
	local profile = DataService.get(player)
	if state == nil or profile == nil then
		Log.warn(TAG, `bank: no creature or profile for {player.UserId}; nothing paid`)
		return
	end
	-- 1. Final mass, tier and traits. TODO(B19, S6-C3): the run's traits from CreatureState.
	local mass, tier, species = state.mass, state.tier, state.species
	local traits: { string } = {}
	local crystal = TraitRules.has(traits, "crystal")
	local deep = deepPockets(profile)
	-- 2 and 3. Pearls through EconomyService; rank points without Deep Pockets.
	local paid = grantBank(player, profile, mass, tier, crystal, deep)
	-- 4. The specimen (02 §11.4): tier 2 or higher; a full cove keeps it as `pendingSpecimen`.
	-- TODO(B19, S12-C4): a run flagged `untrusted` gets no specimen (09 §7.3).
	local specimen: "added" | "full" | "none" = "none"
	if BankMath.keepsSpecimen(tier) then
		local result = CoveService.addSpecimen(player, {
			id = "",
			sp = species,
			tier = tier,
			mass = mass,
			traits = traits,
			at = 0,
			pat = profile.species.equipped[species],
		})
		if result == "added" or result == "full" then
			specimen = result
		end
	end
	-- 5. Stats. TODO(B29, S9): Codex; TODO(B25, S9): goals; TODO(B19, S6-C1): the first bank
	-- also ends the first-run shield (09 §10.2).
	local stats = profile.stats
	local best = mass > stats.bestMass
	DataService.patch(player, "stats.banks", stats.banks + 1)
	if best then
		DataService.patch(player, "stats.bestMass", mass)
	end
	if tier > stats.bestTier then
		DataService.patch(player, "stats.bestTier", tier)
	end
	-- 6. TODO(B28, S9): LeaderboardService.submitBank(player, mass). Clear the run; log it.
	endRun(player, profile)
	Analytics.event(player, "run_banked", 1, `t{tier}`)
	if run.startedAt then
		Analytics.event(player, "run_duration", math.max(0, now() - run.startedAt), "banked")
	end
	lastBanked = {
		slot = slot,
		mass = mass,
		tier = tier,
		pearls = paid,
		crystal = crystal,
		deepPockets = deep,
		best = best,
		specimen = specimen,
	}
	sendEvent("banked", slot, mass, paid, crystal, deep, best, specimen)
	-- The new Fry at the cove spawn point (02 §11.3), its run starting from the cove from now on.
	-- TODO(B19, S7-C3): the bank sequence (controls locked, the swim to the bank spot, BankCam)
	-- and the new Fry only once the results card closes.
	run.home, run.startedAt = "cove", nil
	CreatureService.teleport(slot, CreatureService.coveSpawnCFrame(slot))
	local startMass = Index.Tiers.byTier[Index.Species.byId[species].startTier].massNeeded
	CreatureService.addMass(slot, startMass - state.mass)
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
		payBank(run)
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

-- Op 1, "Swim again" (09 §5.3, §6.3 Gulped row): pay scraps, then respawn at the own cove. The
-- budget runs from the tap: moved once the client's fade out has blacked the screen, released
-- when its fade in ends.
local function swimAgain(player: Player): boolean
	local run = runOf(player)
	if
		run == nil
		or run.respawning
		or not RunRules.canSwimAgain(run.phase, run.gulpedAt, now())
	then
		return false
	end
	local slot = run.slot
	local state = CreatureService.get(slot)
	if state == nil then
		return false
	end
	run.respawning = true
	local generation, root = run.generation, state.root
	-- TODO(B19, S12-C3): pay the scraps (BankMath.scraps, 02 §12.2) here, at the tap; TODO(B19,
	-- S14-C1): tapping Swim again declines an open revive offer.
	local releaseAt, moveAt = RunRules.respawnTimes(now())
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
			run.gulpedAt, run.gulpedBy, run.respawning = nil, nil, false
			apply(run, "respawned")
			-- TODO(B14, S8-C2): MovementValidator.grace(slot, RunRules.RESPAWN_GRACE_SECONDS).
		end)
	end)
	return true
end

local function onRunAction(player: Player, op: number)
	if op == RunRules.Op.swimAgain then
		swimAgain(player)
	end
end

function RunLoopService.init()
	runs, coveVolumes, nurseries, hatchBeds, sinceScan = {}, {}, {}, {}, 0
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
	hatchBeds = WorldIndex.volumesOf("HatchBed")
	-- 09 §5.3: op, then up to 2 numbers; op 1 takes none. Later ops widen the specs.
	Server.on(
		"RunAction",
		{ Server.Validate.int(RunRules.Op.swimAgain, RunRules.Op.swimAgain) },
		onRunAction
	)
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
	-- 09 §12.5: an expired saved run is settled before the first spawn.
	RunLoopService.settleExpired(player)
	-- Canon 5.5: an account that has never banked (`stats.banks == 0`, 09 §12.2) hatches in the
	-- Nursery; any other starts at its cove. PlayerLifecycle loads the profile before the slot.
	local profile = DataService.get(player)
	if profile == nil then
		Log.warn(TAG, `join: no profile for {player.UserId}; treated as never banked`)
	end
	local hasBanked = profile ~= nil and profile.stats.banks > 0
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
		respawning = false,
		gulpedBy = nil,
		tier = nil,
		generation = if old then old.generation + 1 else 1,
	}
	-- TODO(B19, S12-C4): a suspended run that has not expired resumes here instead (`resume`).
	return at :: CFrame
end

--- Run start (09 §5.1, §6.3): the player swam out of the run's home. `Phase = run`. Does nothing
--- outside the `cove` phase.
function RunLoopService.startRun(player: Player)
	local run = runOf(player)
	if run then
		apply(run, "leftHome")
	end
end

--- Banks the run (02 §0.7, §11; canon 5.4; 09 §13.4): what entering the own cove does in a run.
--- An armed run (mass ≥ 1) is paid and ends; an unarmed one is cancelled silently (02 §0.7 item
--- 3). The scan calls it for the centre inside the own `CoveMouth` or `CoveInterior`. Returns
--- whether a bank was paid.
--- TODO(B14, S8-C2): MovementValidator's continuous-path test of the last 0.5 s (09 §13.1).
function RunLoopService.bank(player: Player): boolean
	local run = runOf(player)
	return run ~= nil and run.phase == "run" and apply(run, "enteredCove") == "bank"
end

--- The creature of `slot` was gulped by `by` ("player:<slot>", a predator ID, a hazard).
--- Returns false when the creature is not in a run. Runs 09 §6.3's Gulped row up to the tap:
--- the creature stays anchored and `dead` until "Swim again".
function RunLoopService.gulp(slot: Slot, by: string): boolean
	local run = runs[slot]
	local state = CreatureService.get(slot)
	if run == nil or state == nil or apply(run, "gulped") ~= "gulp" then
		return false
	end
	local root = state.root
	run.generation += 1
	run.gulpedAt, run.gulpedBy, run.startedAt, run.respawning = now(), by, nil, false
	root:SetNetworkOwner(nil)
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	sendEvent("gulped", slot, by)
	-- The respawn waits for "Swim again" (`RunAction` op 1, `swimAgain` above), with no timeout;
	-- a player who leaves first is settled at leave. TODO(B19, S12-C3): scraps (BankMath.scraps)
	-- and run-end settlement; TODO(B19, S6-C3): unbanked traits are lost; TODO(B19, S14-C1):
	-- `offerRevive` adds Revive to the same card (09 §6.3).
	return true
end

--- Offers the one revive of the run (canon 5.5; 09 §6.3: not on the first death, 30 mass or
--- more, no countdown). TODO(B19, S14-C1): the offer, `Protected` 3 s, mass × 0.7 and placement
--- by the return rule (RunRules.returnPoint).
function RunLoopService.offerRevive(_player: Player) end

--- Leave settlement for a mid-run disconnect (canon 5.5; 02 §16.4). TODO(B19, S12-C4): 10 s in
--- the water, then the run saved as suspended for 5 minutes; a dead player who never tapped
--- Swim again is settled here (scraps paid, 09 §6.3; S12-C3). For now the run is forgotten.
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

--- Settles the player's saved run when it has expired (09 §12.5, 13.4): `RunRules.atJoin` reads
--- it (a run with no `suspendedAt` is a crash, read as a shutdown at `lastSeenAt`). "scraps" pays
--- `BankMath.scraps`, "bank_pearls" the full bank; no specimen either way. Counts the run in
--- `newcomer.runsCompleted`, logs `run_abandoned` and clears `run`. Called at join before the
--- first spawn; returns whether a run was settled. A run still inside its window is left for
--- `resume` (S12-C4).
function RunLoopService.settleExpired(player: Player): boolean
	local profile = DataService.get(player)
	local saved = if profile then profile.run else nil
	if profile == nil or saved == nil then
		return false
	end
	local verdict, pays = RunRules.atJoin(saved, os.time(), profile.lastSeenAt)
	if verdict ~= "settle" then
		Log.once("info", TAG, "a saved run inside its window waits for resume (S12-C4)")
		return false
	end
	local crystal = TraitRules.has(saved.traits, "crystal")
	local deep = deepPockets(profile)
	if pays == "bank_pearls" then
		grantBank(player, profile, saved.mass, saved.tier, crystal, deep)
	else
		local deaths = profile.stats.deaths
		local amount = BankMath.scraps(saved.mass, crystal, deep, deaths)
		if amount > 0 then
			EconomyService.grant(player, amount, "Scraps", BankMath.scrapsSku(deaths))
		end
		DataService.patch(
			player,
			"rank.points",
			profile.rank.points + BankMath.scrapsRankPoints(saved.mass, crystal, deaths)
		)
	end
	endRun(player, profile)
	Analytics.event(player, "run_abandoned", 1, `t{math.clamp(saved.tier, 1, 7)}`)
	return true
end

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
	hatchBeds = function(): { Volume }
		return hatchBeds
	end,
	swimAgain = swimAgain,
	lastBanked = function(): Banked?
		return lastBanked
	end,
})

return RunLoopService
