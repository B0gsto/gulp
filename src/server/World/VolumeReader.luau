--!strict
-- VolumeReader: turns the parts tagged `Volume` (authored in Studio under `Workspace.Volumes`)
-- into data and destroys them (docs/09, section 9.1). A volume keeps its shape, inverse frame,
-- half size and attributes; a `RevivePoint` keeps only its centre. A `NurseryPath` volume must
-- name a data:NurseryPath row (docs/03, section 6.2). A part with an unknown `Kind`
-- or a missing attribute WorldIndex needs is skipped and reported, never half-read.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Index = require(ReplicatedStorage.Shared.Data.Index)
local Types = require(ReplicatedStorage.Shared.Types)
local VolumeMath = require(ReplicatedStorage.Shared.Logic.VolumeMath)

type Volume = Types.Volume
type RevivePoint = Types.RevivePoint
type VolumeAttribute = Types.VolumeAttribute

local VolumeReader = {}

VolumeReader.TAG = "Volume"

export type Result = {
	volumes: { Volume },
	revivePoints: { RevivePoint }, -- in wire order (rp_01 first)
	problems: { string }, -- one line per skipped part or missing revive point
}

local function shapeOf(part: BasePart): Types.VolumeShape?
	if not part:IsA("Part") then
		return nil -- a MeshPart, wedge or union has no shape the arithmetic knows
	end
	return VolumeMath.shapeOf((part :: Part).Shape.Name) -- safe: IsA("Part") just above
end

local function attributesOf(part: BasePart): { [string]: VolumeAttribute }
	local attrs: { [string]: VolumeAttribute } = {}
	for name, value in part:GetAttributes() do
		local t = type(value)
		if t == "string" or t == "number" or t == "boolean" then
			attrs[name] = value :: VolumeAttribute -- safe: type checked just above
		end
	end
	return attrs
end

--- Reads every tagged part, destroys it, and returns the data. Call once, at server start.
function VolumeReader.read(): Result
	local zones: { [string]: boolean } = {}
	for _, def in Index.Zones.list do
		zones[def.id] = true
	end

	local volumes: { Volume } = {}
	local points: { [string]: RevivePoint } = {}
	local problems: { string } = {}
	for _, instance in CollectionService:GetTagged(VolumeReader.TAG) do
		if not instance:IsA("BasePart") then
			table.insert(problems, `{instance:GetFullName()}: tagged Volume but not a part`)
			continue
		end
		local part = instance :: BasePart -- safe: IsA just above
		local attrs = attributesOf(part)
		local shape = shapeOf(part)
		local ok, reason = VolumeMath.validate(attrs, zones)
		if not ok or shape == nil then
			table.insert(
				problems,
				`{part:GetFullName()}: {reason or "not a Block, Ball or Cylinder"}`
			)
			part:Destroy()
			continue
		end
		local kind = VolumeMath.kindOf(attrs.Kind)
		if kind == nil then
			continue -- unreachable: validate() accepted the Kind
		elseif kind == "RevivePoint" then
			local id = attrs.PointId :: string -- safe: validate() checked the type
			local def = Index.RevivePoints.byId[id]
			if def == nil then
				table.insert(problems, `{part:GetFullName()}: unknown PointId {id}`)
			elseif points[id] ~= nil then
				table.insert(problems, `{part:GetFullName()}: PointId {id} twice`)
			else
				local p = part.Position
				points[id] = { id = id, wire = def.wire, x = p.X, y = p.Y, z = p.Z }
			end
		elseif kind == "NurseryPath" and Index.NurseryPath.byId[attrs.PointId :: string] == nil then
			-- safe: validate() checked that PointId is a string
			table.insert(problems, `{part:GetFullName()}: unknown PointId {attrs.PointId}`)
		else
			local size = part.Size
			table.insert(
				volumes,
				VolumeMath.new(
					kind,
					shape,
					{ part.CFrame:GetComponents() },
					size.X,
					size.Y,
					size.Z,
					attrs
				)
			)
		end
		part:Destroy()
	end

	local revivePoints: { RevivePoint } = {}
	for _, def in Index.RevivePoints.list do
		local point = points[def.id]
		if point then
			table.insert(revivePoints, table.freeze(point))
		else
			table.insert(problems, `RevivePoint {def.id} missing`)
		end
	end
	return { volumes = volumes, revivePoints = revivePoints, problems = problems }
end

return VolumeReader
