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
local Types = require(ReplicatedStorage.Shared.Types)
local VolumeMath = require(ReplicatedStorage.Shared.Logic.VolumeMath)

local CreatureService = require("./CreatureService")
local Server = require("../Net/Server")
local WorldIndex = require("./WorldIndex")

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
}

local PreyService = {}
PreyService.name = "PreyService"

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

-- Reads every creature: threats for the sim, positions for the spawner, slot changes for interest.
local function gatherPlayers()
	local n = 0
	for slot = 1, MAX_SLOTS do
		local state = CreatureService.get(slot)
		local player = if state then state.player else nil
		if player ~= playerOf[slot] then
			PreyInterest.reset(interest, slot)
			playerOf[slot] = player
		end
		if state then
			local p = state.root.Position
			PreySim.setThreat(sim, n, p.X, p.Y, p.Z, state.tier, PreySim.THREAT_PLAYER)
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
		local state = CreatureService.get(slot)
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
	local creature = CreatureService.get(slot)
	local def = Formation.defOf(buffer.readu8(sim.buffers.kind, groupId))
	if creature == nil or def == nil or def.tier > creature.tier then
		return false, nil
	end
	local now = t - Server.EPOCH
	if not PreySpawner.edibleAt(spawner, groupId, now) then
		return false, nil
	end
	local mask = bit32.bor(knowers(groupId, gen), bit32.lshift(1, slot - 1))
	PreySim.clearMember(sim, groupId, member)
	queueEvent(PreyEvent.OP_EATEN, groupId, gen, member, slot, mask)
	PreySpawner.onEaten(spawner, groupId, serverNow())
	return true, def
end

--- Where member `member` of group `groupId` was at server time `t` (8.9's distance check), from
--- the group's 0.8 s history. The caller has checked the group is live at its gen.
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
	s.targetMembers = PreySpawner.targetMembers(spawner)
	s.simMs = if stats.ticks > 0 then stats.simMs / stats.ticks else 0
	s.interestMs = if stats.interestCalls > 0 then stats.interestMs / stats.interestCalls else 0
	s.seconds = os.clock() - stats.seconds
	return s
end

function PreyService.resetStats()
	stats = freshStats()
end

--- The internals, for the engine spec only.
function PreyService.internals(): (PreySim.Sim, PreyInterest.State, PreySpawner.Spawner)
	return sim, interest, spawner
end

return PreyService
