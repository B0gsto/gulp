--!strict
-- WorldIndex: the gameplay volumes, the 12 revive points and the floor height field (docs/09,
-- sections 5.1 and 9.1). `init` registers the collision groups, puts the shell in `World` and
-- reads (then destroys) the tagged volume parts, so every other service can query volumes from
-- its own `start`. `start` builds the height field over the first 2 s; until it is ready,
-- `floorY` casts one ray instead. The arithmetic is Shared/Logic/VolumeMath and HeightFieldMath.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeightFieldMath = require(ReplicatedStorage.Shared.Logic.HeightFieldMath)
local Index = require(ReplicatedStorage.Shared.Data.Index)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Types = require(ReplicatedStorage.Shared.Types)
local VolumeMath = require(ReplicatedStorage.Shared.Logic.VolumeMath)

local CollisionGroups = require("../World/CollisionGroups")
local HeightField = require("../World/HeightField")
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
local points: { RevivePoint } = {}
local field: HeightField.Field
local rayParams: RaycastParams
local fallbackZone: ZoneId = Index.Zones.list[1].id

function WorldIndex.init()
	byKind, safeVolumes, zones, points = {}, {}, {}, {} -- a second init starts clean
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
	for kind, list in byKind do
		byKind[kind] = table.freeze(list)
	end
	points = table.freeze(result.revivePoints)
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

--- The revive points found in the place, in wire order (rp_01 first). Twelve in a complete map.
function WorldIndex.revivePoints(): { RevivePoint }
	return points
end

return WorldIndex
