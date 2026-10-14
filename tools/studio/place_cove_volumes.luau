--!strict
-- Places the 24 cove volumes in the world place (task S5-C3; docs/09, sections 3.1 and 9.1; docs/03,
-- sections 6.7 and 6.10). Volumes are Studio-authored (09 §3.1), so the owner runs this once in
-- Edit mode on the world place (MCP `execute_luau`, or the command bar), checks the result with
-- tools/studio/check_place.luau, and saves. It reads the synced code: the mouths from
-- ReplicatedStorage.Shared.Data.Generated.CoveMouths (data:CoveMouths) and the boxes from
-- Logic/CoveRules.volumes (the throat from the mouth plane in as `CoveMouth`, the chamber behind
-- it as `CoveInterior`, `CoveIndex` = the cove number, the look vector toward the Reef).
--
-- Idempotent: every tagged `Volume` part under Workspace.Volumes whose Kind is CoveMouth or
-- CoveInterior is replaced. Nothing else is touched. Returns one summary line.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CoveMouths = (require :: any)(Shared.Data.Generated.CoveMouths)
local CoveRules = (require :: any)(Shared.Logic.CoveRules)

local folder = workspace:FindFirstChild("Volumes")
if folder == nil then
	folder = Instance.new("Folder")
	folder.Name = "Volumes"
	folder.Parent = workspace
end

local removed = 0
for _, part in folder:GetDescendants() do
	local kind = part:GetAttribute("Kind")
	if part:IsA("BasePart") and (kind == "CoveMouth" or kind == "CoveInterior") then
		part:Destroy()
		removed += 1
	end
end

local placed = 0
for _, def in CoveMouths do
	local mouth, room = CoveRules.volumes(def.x, def.z)
	for _, pair in { { "CoveMouth", mouth }, { "CoveInterior", room } } do
		local kind, box = pair[1], pair[2]
		local part = Instance.new("Part")
		part.Name = `{kind}_{def.id}`
		part.Shape = Enum.PartType.Block
		part.Size = Vector3.new(box.size[1], box.size[2], box.size[3])
		part.CFrame =
			CFrame.lookAlong(Vector3.new(box.x, box.y, box.z), Vector3.new(box.lookX, 0, box.lookZ))
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		part.Transparency = 1
		part:SetAttribute("Kind", kind)
		part:SetAttribute("CoveIndex", def.wire)
		CollectionService:AddTag(part, "Volume")
		part.Parent = folder
		placed += 1
	end
end

return `cove volumes: {placed} placed ({#CoveMouths} coves), {removed} replaced`
