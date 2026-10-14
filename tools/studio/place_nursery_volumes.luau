--!strict
-- Places the first-run route volumes in the world place (task S6-D1; docs/03, section 6.2
-- data:NurseryPath; docs/04, section 3.5; docs/09, sections 3.1 and 9.1). Volumes are
-- Studio-authored (09 §3.1), so the owner runs this once in Edit mode on the world place (MCP
-- `execute_luau`, or the command bar), checks the result with tools/studio/check_place.luau, and
-- saves. It reads the synced code: the places from ReplicatedStorage.Shared.Data.Generated
-- .NurseryPath and the parts from Logic/NurseryRoute.volumes: the `HatchBed` Ball on the egg, then
-- one `NurseryPath` volume per route row (`PointId` = the row ID): Balls at Swarm A, Swarm B, the
-- Glow Grotto's mouth and the Home Current mouth; Blocks along the plankton trail, Little Arch
-- (the Gap) and both legs of the Elbow; a thin Block for the kelp curtain; an upright Cylinder at
-- the Elbow's bend. Last, the Lagoon's `SafeNursery` Block (NurseryRoute.lagoon, task S6-C2), so
-- the half-mass rule of 05 §2.1 holds along the route.
--
-- Idempotent: every part under Workspace.Volumes whose Kind is HatchBed or NurseryPath, and the
-- `SafeNursery_Lagoon` part, is replaced. Nothing else is touched (other SafeNursery volumes stay). Returns one summary line.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NurseryRoute = (require :: any)(Shared.Logic.NurseryRoute)

local folder = workspace:FindFirstChild("Volumes")
if folder == nil then
	folder = Instance.new("Folder")
	folder.Name = "Volumes"
	folder.Parent = workspace
end

local removed = 0
for _, part in folder:GetDescendants() do
	local kind = part:GetAttribute("Kind")
	local ours = kind == "HatchBed"
		or kind == NurseryRoute.KIND
		or part.Name == "SafeNursery_Lagoon"
	if part:IsA("BasePart") and ours then
		part:Destroy()
		removed += 1
	end
end

local placed = 0
local volumes = NurseryRoute.volumes()
table.insert(volumes, NurseryRoute.lagoon())
for _, v in volumes do
	local part = Instance.new("Part")
	part.Name = v.name
	part.Shape = (Enum.PartType :: any)[v.shape]
	part.Size = Vector3.new(v.size[1], v.size[2], v.size[3])
	part.CFrame = CFrame.new(table.unpack(v.frame))
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Transparency = 1
	part:SetAttribute("Kind", v.kind)
	if v.pointId then
		part:SetAttribute("PointId", v.pointId)
	end
	CollectionService:AddTag(part, "Volume")
	part.Parent = folder
	placed += 1
end

return `nursery volumes: {placed} placed, {removed} replaced`
