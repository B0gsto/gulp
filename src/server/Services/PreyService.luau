--!strict
-- PreyService: spawns, simulates and replicates the prey groups (docs/09, sections 5.1 and 8.1 to
-- 8.9). Prey are data only on the server: no Instance is ever created for them (9.2).
--
-- The work is pure modules driven from Heartbeat in a 6-frame cycle (8.4):
--   frame 0      threats (every creature's root and tier) into the sim, then PreySim.step (10 Hz)
--   frame k      interest and send for the slots with slot % 6 == k (Logic/PreyInterest), one
--                PreyState packet of at most 900 bytes per player per tick, unreliable
--   frame 3      the spawner's pass, on the first tick at or after each whole second since the
--                last one, so every 10th tick (Logic/PreySpawner)
--   every frame  queued PreyEvent records go, reliable, to every player who knows the group
-- Spawn areas: each PreySpawn volume (attributes PreyIds, a comma list, and MaxGroups, read but not
-- used yet); a zone without one spawns in its Zone volumes instead (the CI arena). An area is the
-- volume's upright cylinder (radius = the smaller horizontal half size, the volume's rotation is
-- ignored). areaScale of a zone is the plan area of its Zone volumes ÷ its data:ZoneAreas area.
-- Times given to `tryEat` and `memberPosAt` are on the `GetServerTimeNow` clock.
-- Scripted prey (docs/04 §3.5, §12 C8): `spawnScripted(slot, spec)` makes groups that belong to one
-- slot's creature (PreySpawner.spawnOwned); a slot with no creature is refused. Only that slot's
-- interest set and packets carry them, only its creature scares them (a `calm` spec: nothing does,
-- 04 §4), Spark's `stunNear` skips them, `peek` and `tryEat` treat them as gone for every other
-- slot, and `onScriptedEaten` fires, deferred, on each bite. `steerScripted` slides a group's leash
-- toward a point (04 §3.6 B2, B3: the FTUE krill drift toward the player at 6 studs/s). They go
-- when `clearScripted` is called, and when the slot's player or creature changes or goes (the
-- player left, a new player took the slot, or CreatureService.remove), seen on the next tick. A
-- gap with no creature ends them too: a run ended by a gulp is over, the scripted intro offers no
-- revive (02 §12.3) and nothing can eat a newcomer in run 1 (04 §4), and a resumed run replays
-- its script from the last completed beat (04 §9), which spawns that beat's prey again.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Formation = require(ReplicatedStorage.Shared.Sim.Formation)
local Index = require(ReplicatedStorage.Shared.Data.Index)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local PreyEvent = require(ReplicatedStorage.Shared.Net.Codec.PreyEvent)
local PreyInterest = require(ReplicatedStorage.Shared.Logic.PreyInterest)
local PreySim = require(ReplicatedStorage.Shared.Sim.PreySim)
local PreySpawnMath = require(ReplicatedStorage.Shared.Logic.PreySpawnMath)
local PreySpawner = require(ReplicatedStorage.Shared.Logic.PreySpawner)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local VolumeMath = require(ReplicatedStorage.Shared.Logic.VolumeMath)

local CreatureService = require("./CreatureService")
local Server = require("../Net/Server")
local WorldIndex = require("./WorldIndex")

type CreatureState = CreatureService.CreatureState
type PreyDef = Types.PreyDef
type Slot = Types.Slot
type Volume = Types.Volume

local TAG = "Prey"
local MAX_SLOTS = 24
local FRAMES = 6
local TICK = 0.1
local SEED = 0x5EED

export type Stats = {
	groups: number,
	members: number,
	targetMembers: number,
	ticks: number,
	simMs: number, -- average PreySim.step, ms per tick
	simMsMax: number,
	interestCalls: number,
	interestMs: number, -- average interest and send, ms per player per tick
	interestMsMax: number,
	packets: number,
	bytes: number,
	maxPacket: number,
	seconds: number, -- since the last reset
	eventBytes: number,
	scriptedGroups: number, -- live groups of scripted prey (not in `groups`)
	scriptedMembers: number, -- their live members (not in `members`)
}

--- Scripted prey for `spawnScripted`: a ball of `count` members (1 to 24) around `centre` with
--- radius `spread`, or one member at each of `positions` (the plankton trail's motes). Each group
--- is leashed to its own spawn point (radius `spread`, at least PreySpawner.OWNED_LEASH_MIN), so it
--- needs no PreySpawn volume. `respawns`: a group eaten out comes back after its PreyDef.respawn s.
--- `calm`: it reacts to no threat, so it never flees or scatters (04 §4's FTUE krill).
export type ScriptedSpec = {
	preyId: string,
	count: number?,
	centre: Vector3?,
	spread: number?,
	positions: { Vector3 }?,
	respawns: boolean?,
	calm: boolean?,
}

local PreyService = {}
PreyService.name = "PreyService"

--- (slot, scripted ID, prey ID): a member of a scripted group was eaten by its owner.
PreyService.onScriptedEaten = Signal.new() :: Types.Signal<Slot, number, string>
--- (slot, prey ID): a member of a wild (not scripted) group was eaten, deferred like
--- `onScriptedEaten`. TutorialService's first bite (04 §3.1: any first prey).
PreyService.onWildEaten = Signal.new() :: Types.Signal<Slot, string>

local sim: PreySim.Sim
local interest: PreyInterest.State
local spawner: PreySpawner.Spawner
local running = false
local frame = 0
local lastStep = -1
local playerOf: { Player? } = table.create(MAX_SLOTS)
-- Player positions for the spawner, parallel arrays.
local px, py, pz =
	table.create(MAX_SLOTS, 0), table.create(MAX_SLOTS, 0), table.create(MAX_SLOTS, 0)
local playerCount = 0
-- Per slot with scripted prey: the creature it was spawned for.
local scriptedFor: { [number]: CreatureState } = {}
-- Where the service reads creatures; the engine spec may stand in a creature of its own.
local creatureOf: (Slot) -> CreatureState? = CreatureService.get
-- PreyEvent queue: one record per entry, with the slots (bit slot − 1) that know the group.
local evOp, evGroup, evGen, evMember, evEater, evMask = {}, {}, {}, {}, {}, {}
local evCount = 0
local stats: Stats

local function freshStats(): Stats
	return {
		groups = 0,
		members = 0,
		targetMembers = 0,
		ticks = 0,
		simMs = 0,
		simMsMax = 0,
		interestCalls = 0,
		interestMs = 0,
		interestMsMax = 0,
		packets = 0,
		bytes = 0,
		maxPacket = 0,
		seconds = os.clock(),
		eventBytes = 0,
		scriptedGroups = 0,
		scriptedMembers = 0,
	}
end

local function serverNow(): number
	return workspace:GetServerTimeNow() - Server.EPOCH
end

-- The slots that know group g at generation gen, as a bit mask.
local function knowers(g: number, gen: number): number
	local mask = 0
	for slot = 1, MAX_SLOTS do
		if playerOf[slot] and PreyInterest.knows(interest, slot, g, gen, sim.tick) then
			mask = bit32.bor(mask, bit32.lshift(1, slot - 1))
		end
	end
	return mask
end

local function queueEvent(
	op: number,
	g: number,
	gen: number,
	member: number,
	eater: number,
	mask: number
)
	if mask == 0 then
		return
	end
	evCount += 1
	evOp[evCount], evGroup[evCount], evGen[evCount] = op, g, gen
	evMember[evCount], evEater[evCount], evMask[evCount] = member, eater, mask
end

local function flushEvents()
	if evCount == 0 then
		return
	end
	for slot = 1, MAX_SLOTS do
		local player = playerOf[slot]
		if player == nil then
			continue
		end
		local bit = bit32.lshift(1, slot - 1)
		local n = 0
		for k = 1, evCount do
			if bit32.btest(evMask[k], bit) then
				n += 1
			end
		end
		local k = 1
		while n > 0 do
			local batch = math.min(n, PreyEvent.MAX_RECORDS)
			local payload = PreyEvent.create(batch)
			local written = 0
			while written < batch do
				if bit32.btest(evMask[k], bit) then
					PreyEvent.write(
						payload,
						written,
						evOp[k],
						evGroup[k],
						evGen[k],
						evMember[k],
						evEater[k]
					)
					written += 1
				end
				k += 1
			end
			Server.send(player, "PreyEvent", payload)
			stats.eventBytes += buffer.len(payload)
			n -= batch
		end
	end
	evCount = 0
end

-- A removed group: tell whoever knows it, then forget it everywhere.
local function onRemoved(g: number, gen: number)
	queueEvent(PreyEvent.OP_REMOVED, g, gen, 0, 0, knowers(g, gen))
	PreyInterest.forget(interest, g)
end

local function fireScriptedEaten(slot: Slot, id: number, preyId: string)
	PreyService.onScriptedEaten:fire(slot, id, preyId)
end

local function fireWildEaten(slot: Slot, preyId: string)
	PreyService.onWildEaten:fire(slot, preyId)
end

--- Removes every scripted group of `slot`; each one's knowers get a PreyEvent. Also run for a slot
--- whose player or creature changed or went.
function PreyService.clearScripted(slot: Slot)
	scriptedFor[slot] = nil
	PreySpawner.clearOwned(spawner, slot, serverNow())
end

-- Reads every creature: threats for the sim, positions for the spawner, slot changes for interest
-- and scripted prey.
local function gatherPlayers()
	local n = 0
	for slot = 1, MAX_SLOTS do
		local state = creatureOf(slot)
		local player = if state then state.player else nil
		if player ~= playerOf[slot] then
			PreyInterest.reset(interest, slot)
			playerOf[slot] = player
		end
		-- Scripted prey belongs to the creature it was spawned for: a new player or creature in the
		-- slot, or none, ends it.
		local held = scriptedFor[slot]
		if held and (held ~= state or held.player ~= player) then
			PreyService.clearScripted(slot)
		end
		if state then
			local p = state.root.Position
			PreySim.setThreat(sim, n, p.X, p.Y, p.Z, state.tier, PreySim.THREAT_PLAYER, slot)
			n += 1
			px[n], py[n], pz[n] = p.X, p.Y, p.Z
		end
	end
	PreySim.setThreatCount(sim, n)
	playerCount = n
end

local function step(now: number)
	gatherPlayers()
	local dt = if lastStep < 0 then TICK else math.clamp(now - lastStep, 0.05, 0.25)
	lastStep = now
	debug.profilebegin("PreyService.step")
	local t0 = os.clock()
	PreySpawner.stepOwned(spawner, dt)
	PreySim.step(sim, now, dt)
	local ms = (os.clock() - t0) * 1000
	debug.profileend()
	stats.ticks += 1
	stats.simMs += ms
	stats.simMsMax = math.max(stats.simMsMax, ms)
end

local function sendInterest(k: number)
	debug.profilebegin("PreyService.interest")
	for slot = if k == 0 then FRAMES else k, MAX_SLOTS, FRAMES do
		local player = playerOf[slot]
		local state = creatureOf(slot)
		if player == nil or state == nil then
			continue
		end
		local p = state.root.Position
		local t0 = os.clock()
		local payload = PreyInterest.updatePlayer(interest, sim, slot, p.X, p.Y, p.Z)
		if payload then
			Server.send(player, "PreyState", payload)
		end
		local ms = (os.clock() - t0) * 1000
		stats.interestCalls += 1
		stats.interestMs += ms
		stats.interestMsMax = math.max(stats.interestMsMax, ms)
		if payload then
			local size = buffer.len(payload)
			stats.packets += 1
			stats.bytes += size
			stats.maxPacket = math.max(stats.maxPacket, size)
		end
	end
	debug.profileend()
end

--- One server frame of the 6-frame cycle (8.4). Heartbeat calls it; tests may call it by hand.
function PreyService.frame(now: number?)
	local t = now or serverNow()
	if frame == 0 then
		step(t)
	end
	sendInterest(frame)
	if frame == 3 then
		debug.profilebegin("PreyService.spawn")
		if t >= spawner.nextPass then
			-- Players on the server and inside each zone (the Nursery's rule), once a second.
			local inside: { [string]: number } = {}
			for k = 1, playerCount do
				local zone = WorldIndex.zoneAt(px[k], py[k], pz[k])
				inside[zone] = (inside[zone] or 0) + 1
			end
			PreySpawner.setPlayers(spawner, math.max(playerCount, 1), inside)
		end
		PreySpawner.pass(spawner, t, px, py, pz, playerCount)
		debug.profileend()
	end
	flushEvents()
	frame = (frame + 1) % FRAMES
end

-- Builds the spawn areas from the volumes (see the header).
local function buildAreas()
	local zoneArea: { [string]: number } = {}
	for _, def in Index.PreySpawns.list do
		zoneArea[def.zone] = def.zoneArea
	end
	local covered: { [string]: boolean } = {}
	for _, v in WorldIndex.volumesOf("PreySpawn") do
		local cx, cy, cz = VolumeMath.centre(v)
		local zone = WorldIndex.zoneAt(cx, cy, cz)
		local ids: { string }? = nil
		local attr = v.attrs.PreyIds
		if type(attr) == "string" and attr ~= "" then
			local list = {}
			for id in string.gmatch(attr, "[%w_]+") do
				table.insert(list, id)
			end
			ids = list
		end
		PreySpawner.addArea(spawner, zone, cx, cy, cz, math.min(v.hx, v.hz), v.hy, ids)
		covered[zone] = true
	end
	local planArea: { [string]: number } = {}
	for _, v in WorldIndex.volumesOf("Zone") do
		local zone = v.attrs.ZoneId
		if type(zone) ~= "string" then
			continue
		end
		local radius = if v.shape == "Ball"
			then math.min(v.hx, v.hy, v.hz)
			else math.min(v.hx, v.hz)
		local halfHeight = if v.shape == "Ball" then radius else v.hy
		planArea[zone] = (planArea[zone] or 0) + PreySpawnMath.planArea(v.shape, v.hx * 2, v.hz * 2)
		if not covered[zone] and zoneArea[zone] then
			local cx, cy, cz = VolumeMath.centre(v)
			PreySpawner.addArea(spawner, zone, cx, cy, cz, radius, halfHeight, nil)
		end
	end
	for zone, area in planArea do
		local full = zoneArea[zone]
		if full and full > 0 then
			PreySpawner.setZoneScale(spawner, zone, area / full)
		end
	end
	PreySpawner.build(spawner)
end

function PreyService.init()
	sim = PreySim.new(SEED)
	interest = PreyInterest.new(MAX_SLOTS)
	spawner = PreySpawner.new(sim, SEED + 1)
	stats = freshStats()
end

function PreyService.start()
	spawner.onRemoved = onRemoved
	spawner.zoneAt = WorldIndex.zoneAt
	PreySim.setFloor(sim, WorldIndex.floorY)
	buildAreas()
	gatherPlayers()
	PreySpawner.setPlayers(spawner, math.max(playerCount, 1), nil)
	PreySpawner.fill(spawner, serverNow(), px, py, pz, playerCount)
	local members, groups = PreySpawner.liveMembers(spawner)
	Log.info(TAG, `{groups} groups, {members} members in {#spawner.areas} spawn areas`)
	running = true
	RunService.Heartbeat:Connect(function()
		PreyService.frame()
	end)
end

--- True once `start` has run (the engine specs use it).
function PreyService.isRunning(): boolean
	return running
end

--- The bite's target checks that PreyService owns (8.9, checks 3 and 4, then step 7's "clear
--- bit"): group `groupId` is live at `gen`, member `member` is alive, the group has faded in by
--- `t`, and its tier is at most the eater's. On success the member is gone, every player who knows
--- the group gets a PreyEvent, and the PreyDef is returned so BiteService can add the mass.
function PreyService.tryEat(
	slot: Slot,
	groupId: number,
	member: number,
	gen: number,
	t: number
): (boolean, PreyDef?)
	if not PreySim.memberAlive(sim, groupId, member) or not PreySim.isLive(sim, groupId, gen) then
		return false, nil
	end
	local creature = creatureOf(slot)
	local def = Formation.defOf(buffer.readu8(sim.buffers.kind, groupId))
	if creature == nil or def == nil or def.tier > creature.tier then
		return false, nil
	end
	-- Scripted prey: only its owner's creature, the one it was spawned for (04 §3.5).
	local owner = PreySim.ownerOf(sim, groupId)
	if owner ~= 0 and (owner ~= slot or scriptedFor[slot] ~= creature) then
		return false, nil
	end
	local now = t - Server.EPOCH
	if not PreySpawner.edibleAt(spawner, groupId, now) then
		return false, nil
	end
	local mask = bit32.bor(knowers(groupId, gen), bit32.lshift(1, slot - 1))
	PreySim.clearMember(sim, groupId, member)
	queueEvent(PreyEvent.OP_EATEN, groupId, gen, member, slot, mask)
	local run = if owner ~= 0 then PreySpawner.ownedRun(spawner, groupId) else nil
	PreySpawner.onEaten(spawner, groupId, serverNow())
	if run then
		-- Deferred: a listener runs after the bite claim, so one that throws or calls back into
		-- PreyService cannot break BiteService's loop over the claim's targets.
		task.defer(fireScriptedEaten, slot, run.id, run.prey)
	elseif owner == 0 then
		task.defer(fireWildEaten, slot, def.id)
	end
	return true, def
end

--- Spawns scripted prey that belongs to `slot` alone (04 §3.5; see the header and ScriptedSpec).
--- Returns its scripted ID (the one `onScriptedEaten` reports), or nil when the slot has no
--- creature, the prey is unknown, the spec is malformed, or it does not fit whole in the budgets
--- (PreySpawner.OWNED_MAX_GROUPS and OWNED_MAX_MEMBERS on the server, OWNED_MAX_PER_SLOT and
--- OWNED_MAX_MEMBERS_PER_SLOT per slot) or the free group slots. Addition to 5.1's API.
function PreyService.spawnScripted(slot: Slot, spec: ScriptedSpec): number?
	local creature = creatureOf(slot)
	if creature == nil then
		Log.warn(TAG, `spawnScripted: {spec.preyId} for slot {slot} refused: no creature`)
		return nil
	end
	local held = scriptedFor[slot]
	if held and held ~= creature then
		PreyService.clearScripted(slot) -- left from the slot's last creature
	end
	local points: { { number } }? = nil
	if spec.positions then
		local list = {}
		for _, p in spec.positions :: { Vector3 } do
			table.insert(list, { p.X, p.Y, p.Z })
		end
		points = list
	end
	local c = spec.centre
	local id = PreySpawner.spawnOwned(spawner, slot, {
		prey = spec.preyId,
		count = spec.count,
		x = if c then c.X else nil,
		y = if c then c.Y else nil,
		z = if c then c.Z else nil,
		spread = spec.spread,
		points = points,
		respawn = spec.respawns,
		calm = spec.calm,
	}, serverNow())
	if id == nil then
		Log.warn(TAG, `spawnScripted: {spec.preyId} for slot {slot} refused`)
		return nil
	end
	scriptedFor[slot] = creature
	return id
end

--- Steers scripted group `scriptedId` of `slot`: its leash centre slides toward `target` at `speed`
--- studs/s, one step per tick, and stops there; its members follow inside their leash. Call it again
--- to move the target (the tutorial: the player's position, 6 studs/s inside 25 studs, 04 §3.6 B2,
--- B3 and §4); nil `target` stops it where it is. False when the slot has no such scripted group or
--- the speed is not positive. Addition to 5.1's API.
function PreyService.steerScripted(
	slot: Slot,
	scriptedId: number,
	target: Vector3?,
	speed: number?
): boolean
	if target == nil then
		return PreySpawner.steerOwned(spawner, slot, scriptedId, nil)
	end
	return PreySpawner.steerOwned(spawner, slot, scriptedId, target.X, target.Y, target.Z, speed)
end

--- Members alive in scripted group `scriptedId` of `slot`, and its centre (where its leash is,
--- steered or not); 0 and nil when the slot has no such group or it is gone. Addition to 5.1's
--- API, for TutorialService (04 §3.6 B3: krill kept near the player; homing on the nearest).
function PreyService.scriptedAlive(slot: Slot, scriptedId: number): (number, Vector3?)
	local run = spawner.owned[scriptedId]
	if run == nil or run.owner ~= slot then
		return 0, nil
	end
	local alive = 0
	for _, part in run.parts do
		if part.g >= 0 then
			alive += PreySim.aliveCount(sim, part.g)
		end
	end
	return alive, Vector3.new(PreySpawner.ownedCentre(spawner, scriptedId))
end

--- The PreyDef of member `member` of group `groupId` when the group is live at `gen` and the
--- member is alive (8.9, check 3), and the group's speed in studs/s; nil and 0 when it is gone,
--- and for `slot` when the group is scripted prey of another slot (04 §3.5: to that slot it does
--- not exist). Reads only: `tryEat` still decides. Addition to 5.1's API, for BiteService's
--- reject reasons.
function PreyService.peek(
	slot: Slot,
	groupId: number,
	member: number,
	gen: number
): (PreyDef?, number)
	if not PreySim.memberAlive(sim, groupId, member) or not PreySim.isLive(sim, groupId, gen) then
		return nil, 0
	end
	local owner = PreySim.ownerOf(sim, groupId)
	if owner ~= 0 and owner ~= slot then
		return nil, 0
	end
	local b, o4 = sim.buffers, groupId * 4
	local vx, vy, vz =
		buffer.readf32(b.velX, o4), buffer.readf32(b.velY, o4), buffer.readf32(b.velZ, o4)
	return Formation.defOf(buffer.readu8(b.kind, groupId)), math.sqrt(vx * vx + vy * vy + vz * vz)
end

--- Where member `member` of group `groupId` was at server time `t` (8.9's distance check), from
--- the group's 0.8 s history. The caller has checked with `peek` that the group is live at its gen
--- and that the claiming slot may see it.
function PreyService.memberPosAt(
	groupId: number,
	member: number,
	t: number
): (number, number, number)
	return PreySim.memberPosAt(sim, groupId, member, t - Server.EPOCH)
end

--- The running tide, nil for none (09 §5.1). The tide's spawnRateMult (canon data:Tides) divides
--- the respawn delays of normal prey and sets the spawns per row per pass; only `frenzy` doubles
--- the targets and caps of normal prey (02 §14.4).
function PreyService.setTide(tideId: string?)
	if tideId and Index.Tides.byId[tideId] == nil then
		Log.warn(TAG, `setTide: unknown tide {tideId}`)
		return
	end
	PreySpawner.setTide(spawner, tideId)
end

--- Spawns the event prey of tide `tideId` (Moon Tide: lunar_fry) with the event flag: the prey's
--- `alive` groups at once, topped up by the spawn pass until its `eventTotal` is released (03 §3.1).
function PreyService.spawnEventPrey(tideId: string)
	local tide = Index.Tides.byId[tideId]
	if tide == nil then
		Log.warn(TAG, `spawnEventPrey: unknown tide {tideId}`)
		return
	end
	for _, id in tide.eventPrey do
		local def = Index.TraitPrey.byId[id] or Index.Prey.byId[id]
		if def and def.scope == "MVP" then
			PreySpawner.startEvent(spawner, id, serverNow(), px, py, pz, playerCount)
		end
	end
end

--- Removes every event prey group (the tide ended). Addition to 5.1's API, for TideService.
function PreyService.clearEventPrey()
	PreySpawner.clearEvents(spawner, serverNow())
end

--- Stuns prey of tier ≤ maxTier within r of (x, y, z) for `seconds` (Spark). Returns the count.
function PreyService.stunNear(
	x: number,
	y: number,
	z: number,
	r: number,
	maxTier: number,
	seconds: number
): number
	return PreySim.stunNear(sim, x, y, z, r, maxTier, seconds, serverNow())
end

--- Measurements since the last reset (Studio runs and the engine spec).
function PreyService.stats(): Stats
	local s = table.clone(stats)
	s.members, s.groups = PreySpawner.liveMembers(spawner)
	s.scriptedMembers, s.scriptedGroups = PreySpawner.ownedLive(spawner)
	s.targetMembers = PreySpawner.targetMembers(spawner)
	s.simMs = if stats.ticks > 0 then stats.simMs / stats.ticks else 0
	s.interestMs = if stats.interestCalls > 0 then stats.interestMs / stats.interestCalls else 0
	s.seconds = os.clock() - stats.seconds
	return s
end

function PreyService.resetStats()
	stats = freshStats()
end

--- Where the service reads each slot's creature: CreatureService.get, or for the engine spec only,
--- a stand-in (nil puts CreatureService.get back). A stand-in creature with no `player` gets no
--- packets or PreyEvents.
function PreyService.setCreatureLookup(lookup: ((Slot) -> CreatureState?)?)
	creatureOf = lookup or CreatureService.get
end

--- The internals, for the engine spec only.
function PreyService.internals(): (PreySim.Sim, PreyInterest.State, PreySpawner.Spawner)
	return sim, interest, spawner
end

return PreyService
