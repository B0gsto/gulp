--!strict
-- WorldIndex: the gameplay volumes, the 12 revive points and the floor height field (docs/09,
-- sections 5.1 and 9.1). `init` registers the collision groups, puts the shell in `World` and
-- reads (then destroys) the tagged volume parts, so every other service can query volumes from
-- its own `start`. `start` builds the height field over the first 2 s; until it is ready,
-- `floorY` casts one ray instead. The arithmetic is Shared/Logic/VolumeMath and HeightFieldMath.
-- It also sends each client the volume table once, in `WorldInfo` after ClientReady (sections 5.3
-- and 9.1; Shared/Net/Codec/WorldInfo), with NET_VERSION and ServerEpoch (8.7, 17.3).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeightFieldMath = require(ReplicatedStorage.Shared.Logic.HeightFieldMath)
local Index = require(ReplicatedStorage.Shared.Data.Index)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Types = require(ReplicatedStorage.Shared.Types)
local VolumeMath = require(ReplicatedStorage.Shared.Logic.VolumeMath)
local WorldInfo = require(ReplicatedStorage.Shared.Net.Codec.WorldInfo)

local CollisionGroups = require("../World/CollisionGroups")
local HeightField = require("../World/HeightField")
local Server = require("../Net/Server")
local VolumeReader = require("../World/VolumeReader")

type Volume = Types.Volume
type VolumeKind = Types.VolumeKind
type RevivePoint = Types.RevivePoint
type Slot = Types.Slot
type ZoneId = Types.ZoneId

local TAG = "WorldIndex"

local WorldIndex = {}
WorldIndex.name = "WorldIndex"

local byKind: { [string]: { Volume } } = {} -- keyed by VolumeKind
local safeVolumes: { Volume } = {}
local zones: { Volume } = {} -- smallest first (VolumeMath.sortZones)
local nursery: { Volume } = {} -- NurseryPath volumes, smallest first (VolumeMath.sortBySize)
local points: { RevivePoint } = {}
local field: HeightField.Field
local rayParams: RaycastParams
local fallbackZone: ZoneId = Index.Zones.list[1].id
-- The WorldInfo arguments (Codec/WorldInfo.encode), built on the first send.
local infoVersion, infoEpoch, infoVolumes = 0, 0, nil :: { Volume }?

function WorldIndex.init()
	byKind, safeVolumes, zones, nursery, points = {}, {}, {}, {}, {} -- a second init starts clean
	CollisionGroups.register()
	local shell = workspace:FindFirstChild("Collision")
	if shell then
		CollisionGroups.assignShell(shell)
	else
		Log.warn(TAG, "Workspace.Collision is missing: no walls, floor at the map bottom")
	end
	rayParams = CollisionGroups.worldRayParams(shell)
	field = HeightField.new(rayParams)

	local result = VolumeReader.read()
	for _, problem in result.problems do
		Log.warn(TAG, problem)
	end
	for _, kind in VolumeMath.KINDS do
		byKind[kind] = {}
	end
	for _, v in result.volumes do
		table.insert(byKind[v.kind], v)
	end
	for _, kind in VolumeMath.SAFE_KINDS do
		table.move(byKind[kind], 1, #byKind[kind], #safeVolumes + 1, safeVolumes)
	end
	zones = table.clone(byKind.Zone)
	VolumeMath.sortZones(zones)
	nursery = table.clone(byKind.NurseryPath)
	VolumeMath.sortBySize(nursery, "PointId")
	for kind, list in byKind do
		byKind[kind] = table.freeze(list)
	end
	points = table.freeze(result.revivePoints)
	if #byKind.HatchBed > 1 then
		Log.warn(TAG, `{#byKind.HatchBed} HatchBed volumes; the first is used (9.1: exactly one)`)
	end
	infoVolumes = nil
	if #zones == 0 then
		Log.warn(TAG, `no Zone volumes: every point reads as {fallbackZone}`)
	end
	Log.info(TAG, `{#result.volumes} volumes, {#points} revive points`)
end

function WorldIndex.start()
	HeightField.buildOverTime(field, function()
		Log.info(TAG, "height field built")
	end)
end

--- Sends `player` the WorldInfo remote: NET_VERSION, ServerEpoch and every volume but the revive
--- points, which clients never get (9.1). PlayerLifecycle calls it once per player after
--- ClientReady, before the creature spawns. (PlayerLifecycle calls in rather than WorldIndex
--- listening to `onReady`, because PlayerLifecycle requires CreatureService, which requires
--- WorldIndex.)
function WorldIndex.sendWorldInfo(player: Player)
	if infoVolumes == nil then
		local sent: { Volume } = {}
		for _, kind in VolumeMath.KINDS do
			if kind ~= "RevivePoint" then
				local list = WorldIndex.volumesOf(kind)
				table.move(list, 1, #list, #sent + 1, sent)
			end
		end
		infoVersion, infoEpoch, infoVolumes = WorldInfo.encode(Server.EPOCH, sent)
	end
	Server.send(player, "WorldInfo", infoVersion, infoEpoch, infoVolumes)
end

--- The zone at a point: the smallest zone volume holding it, else the nearest zone volume.
function WorldIndex.zoneAt(x: number, y: number, z: number): ZoneId
	return VolumeMath.zoneAt(zones, x, y, z) or fallbackZone
end

--- True inside a `SafeNursery`, `CoveMouth` or `CoveInterior` volume (section 10.2, rule 3).
function WorldIndex.isSafe(x: number, y: number, z: number): boolean
	return VolumeMath.firstContaining(safeVolumes, x, y, z) ~= nil
end

--- The cove whose mouth holds the point, or nil.
function WorldIndex.coveMouthAt(x: number, y: number, z: number): Slot?
	local v = VolumeMath.firstContaining(byKind.CoveMouth, x, y, z)
	return if v then v.attrs.CoveIndex :: number else nil -- safe: validate() checked CoveIndex
end

--- The first-run route place that holds the point (9.1 `NurseryPath`; 03 §6.2 data:NurseryPath;
--- 04 §3.5): the `PointId` of the smallest route volume holding it (the kelp curtain before
--- Little Arch, the Elbow's bend before its legs), or nil off the route volumes. Crossing the Gap
--- is leaving `little_arch` into `elbow_leg_1`.
function WorldIndex.nurseryPathAt(x: number, y: number, z: number): string?
	local v = VolumeMath.firstContaining(nursery, x, y, z)
	return if v then v.attrs.PointId :: string else nil -- safe: validate() checked PointId
end

--- Every volume of a kind (frozen; do not change). Revive points are kept apart: see
--- `revivePoints`.
function WorldIndex.volumesOf(kind: VolumeKind): { Volume }
	return byKind[kind] or {}
end

--- The floor height at X and Z (the highest `World` surface), or -600 where there is none.
function WorldIndex.floorY(x: number, z: number): number
	return HeightField.floorY(field, x, z)
end

--- True when the straight segment from `a` to `b` passes through a `World` part, ignoring a hit
--- in its last 2% (section 7.2, "Inside solid").
function WorldIndex.segmentBlocked(a: Vector3, b: Vector3): boolean
	local delta = b - a
	local length = delta.Magnitude
	if length == 0 then
		return false
	end
	local result = workspace:Raycast(a, delta, rayParams)
	return result ~= nil and HeightFieldMath.segmentHitBlocks(result.Distance, length)
end

--- Where an account that has never banked hatches for its first run (9.1 `HatchBed`; 04 §3.5):
--- the centre of the first HatchBed volume and its look vector, or nil on a place without one
--- (the CI arena, a place with no Nursery). RunLoopService.join reads it.
function WorldIndex.hatchBed(): (Vector3?, Vector3?)
	local v = (byKind.HatchBed or {})[1]
	if v == nil then
		return nil, nil
	end
	local x, y, z = VolumeMath.centre(v)
	local lx, ly, lz = VolumeMath.lookVector(v)
	return Vector3.new(x, y, z), Vector3.new(lx, ly, lz)
end

--- The revive points found in the place, in wire order (rp_01 first). Twelve in a complete map.
function WorldIndex.revivePoints(): { RevivePoint }
	return points
end

return WorldIndex
