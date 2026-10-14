--!nocheck
-- check_place: execute_luau snippet for the Studio MCP server, Edit data model, on the world place
-- (docs/09-technical-architecture.md, sections 3.1, 9.1, 15.4 and 17.2 step 4; task S1-C8).
-- It returns a text report. The first line is the verdict: "check_place: PASS" or "check_place: FAIL".
--
-- What it checks (17.2 step 4):
--   * place settings of 15.4 that Studio code can read; the ones it cannot read (the streaming
--     properties, AuthorityMode; spike tech-a surprise 2, tech-b surprise 4) are listed as
--     UNREADABLE and checked in the saved file by `lune run tools/check_place_file`
--   * the Studio-owned containers of 3.1 and the complete set of ReplicatedStorage.Assets folders
--   * the required tagged volumes (a Zone volume per zone, the SafeNursery), the 24 cove mouths and
--     the 12 revive points of 9.1
--
-- Items authored in a later sprint (docs/13-sprint-plan.md) are reported as "PENDING (Sprint N)"
-- while CURRENT_SPRINT is below N and nothing has been authored yet; they do not fail the run. Once
-- any instance of an item exists, or CURRENT_SPRINT reaches N, the item is checked in full.
-- Raise CURRENT_SPRINT as sprints close (the release tooling, S19-C2, sets it).

local CURRENT_SPRINT = 1

-- Sprint that authors each item in the world place (docs/13-sprint-plan.md).
local DUE = {
	-- S6-D1, Sprint 16 (the Reef), S17-C4, S35-C1, S5 (the cove in grey-box). Zones whose scope is
	-- not MVP (the Trench, P2) are not part of the place yet and are skipped.
	zone = { nursery = 6, reef = 16, kelp = 17, dropoff = 35, cove = 5 },
	safeNursery = 6, -- S6-D1, the Nursery path as tagged volumes
	coveMouth = 5, -- S5-C3, cove mouth volumes for 24 coves
	revivePoint = 14, -- S14-C1 Revive; no earlier task places them, and none sits before its zone
}

local ASSET_FOLDERS = {
	"Species",
	"Prey",
	"Pred",
	"Hazard",
	"Env",
	"Cove",
	"Prop",
	"Trait",
	"Fx",
	"Ui",
	"Audio",
}

local KINDS = {
	Zone = true,
	SafeNursery = true,
	CoveMouth = true,
	CoveInterior = true,
	PreySpawn = true,
	Current = true,
	EelHole = true,
	Hazard = true,
	GullSky = true,
	MorayHole = true,
	PredatorNode = true,
	RevivePoint = true,
}

local COVES = 24
local REVIVE_TOLERANCE = 8 -- studs from the generated row (one height-field cell)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lines = {}
local counts = { PASS = 0, FAIL = 0, PENDING = 0, UNREADABLE = 0 }

local function report(status: string, name: string, detail: string?)
	counts[status] += 1
	table.insert(lines, `{status} {name}{if detail then ": " .. detail else ""}`)
end

local function check(ok: boolean, name: string, detail: string?)
	report(if ok then "PASS" else "FAIL", name, detail)
end

-- An item that has nothing authored yet and is due in a later sprint is pending. Items that share a
-- group (the revive points) are reported on one line per sprint.
local pendingGroups: { [string]: { string } } = {}
local pendingOrder: { string } = {}
local function pending(due: number, authored: number, name: string, group: string?): boolean
	if authored > 0 or CURRENT_SPRINT >= due then
		return false
	end
	if not group then
		report("PENDING", name, `Sprint {due}`)
		return true
	end
	local key = `{group} (Sprint {due})`
	if not pendingGroups[key] then
		pendingGroups[key] = {}
		table.insert(pendingOrder, key)
	end
	table.insert(pendingGroups[key], name)
	return true
end

local function flushPending()
	for _, key in pendingOrder do
		report("PENDING", key, table.concat(pendingGroups[key], " "))
	end
	table.clear(pendingGroups)
	table.clear(pendingOrder)
end

--------------------------------------------------------------------------------------------------
-- Place settings (15.4, 6.5, 6.10; spike tech-a surprise 1 for ChatVersion)

local function service(name: string): Instance?
	local ok, found = pcall(function()
		return game:GetService(name)
	end)
	return if ok then found else nil
end

local SETTINGS = {
	{ "Workspace", "StreamingEnabled", true },
	{ "Workspace", "ModelStreamingBehavior", Enum.ModelStreamingBehavior.Improved },
	{ "Workspace", "StreamingIntegrityMode", Enum.StreamingIntegrityMode.PauseOutsideLoadedArea },
	{ "Workspace", "StreamingMinRadius", 128 },
	{ "Workspace", "StreamingTargetRadius", 512 },
	{ "Workspace", "StreamOutBehavior", Enum.StreamOutBehavior.Opportunistic },
	{ "Workspace", "AuthorityMode", "Automatic" }, -- compared by name: the enum may be hidden
	{ "Workspace", "SignalBehavior", Enum.SignalBehavior.Deferred },
	{ "Workspace", "PhysicsSteppingMethod", Enum.PhysicsSteppingMethod.Adaptive },
	{ "Workspace", "FallenPartsDestroyHeight", -5000 },
	{ "Workspace", "Gravity", 80 },
	{ "Players", "CharacterAutoLoads", false },
	{ "VoiceChatService", "EnableDefaultVoice", false },
	{ "StarterGui", "ScreenOrientation", Enum.ScreenOrientation.LandscapeSensor },
	{ "TextChatService", "ChatVersion", Enum.ChatVersion.TextChatService },
}

local function same(actual: any, expected: any): boolean
	if type(expected) == "number" and type(actual) == "number" then
		return math.abs(actual - expected) < 1e-3
	end
	if type(expected) == "string" and typeof(actual) == "EnumItem" then
		return actual.Name == expected
	end
	return actual == expected
end

for _, row in SETTINGS do
	local serviceName, property, expected = row[1], row[2], row[3]
	local name = `{serviceName}.{property}`
	local owner = service(serviceName)
	if not owner then
		report("FAIL", name, "service missing")
		continue
	end
	local ok, actual = pcall(function()
		return (owner :: any)[property]
	end)
	if not ok then
		report(
			"UNREADABLE",
			name,
			"not readable from Studio code; checked by tools/check_place_file"
		)
	else
		check(same(actual, expected), name, `{actual} (want {expected})`)
	end
end

--------------------------------------------------------------------------------------------------
-- Studio-owned containers and asset folders (3.1)

local World = workspace:FindFirstChild("World")
check(World ~= nil and (World:IsA("Folder") or World:IsA("Model")), "Workspace.World", "container")

local Collision = workspace:FindFirstChild("Collision")
if Collision and Collision:IsA("Model") then
	local mode = Collision.ModelStreamingMode
	check(mode == Enum.ModelStreamingMode.Persistent, "Workspace.Collision", `Model, {mode.Name}`)
else
	report("FAIL", "Workspace.Collision", "missing or not a Model")
end

local Volumes = workspace:FindFirstChild("Volumes")
check(Volumes ~= nil and Volumes:IsA("Folder"), "Workspace.Volumes", "container")

local Assets = ReplicatedStorage:FindFirstChild("Assets")
if Assets and Assets:IsA("Folder") then
	local missing, extra, known = {}, {}, {}
	for _, folder in ASSET_FOLDERS do
		known[folder] = true
		local child = Assets:FindFirstChild(folder)
		if not (child and child:IsA("Folder")) then
			table.insert(missing, folder)
		end
	end
	for _, child in Assets:GetChildren() do
		if not known[child.Name] then
			table.insert(extra, child.Name)
		end
	end
	check(
		#missing == 0 and #extra == 0,
		"ReplicatedStorage.Assets",
		`{#ASSET_FOLDERS - #missing}/{#ASSET_FOLDERS} folders`
			.. (if #missing > 0 then `, missing {table.concat(missing, " ")}` else "")
			.. (if #extra > 0 then `, unexpected {table.concat(extra, " ")}` else "")
	)
else
	report("FAIL", "ReplicatedStorage.Assets", "missing or not a Folder")
end

for _, name in { "Lighting", "SoundService", "MaterialService" } do
	check(service(name) ~= nil, name, "service present")
end

--------------------------------------------------------------------------------------------------
-- Tagged volumes (9.1)

local byKind = {} -- Kind -> { BasePart }
local untagged, unknown, total = 0, 0, 0
if Volumes then
	for _, part in Volumes:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		total += 1
		local kind = part:GetAttribute("Kind")
		if not CollectionService:HasTag(part, "Volume") then
			untagged += 1
		elseif not KINDS[kind] then
			unknown += 1
		else
			byKind[kind] = byKind[kind] or {}
			table.insert(byKind[kind], part)
		end
	end
end
check(
	untagged == 0 and unknown == 0,
	"Volumes tagged",
	`{total} parts, {untagged} without the Volume tag, {unknown} with an unknown Kind`
)

local function ofKind(kind: string): { BasePart }
	return byKind[kind] or {}
end

local function loadData(name: string): any
	local Shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = Shared and Shared:FindFirstChild("Data")
	module = module and module:FindFirstChild("Generated")
	module = module and module:FindFirstChild(name)
	if not module then
		return nil
	end
	local ok, data = pcall(require, module)
	return if ok then data else nil
end

-- Zones: one Zone volume per zone, plus the SafeNursery.
local Zones = loadData("Zones")
if not Zones then
	report("FAIL", "Zone volumes", "ReplicatedStorage.Shared.Data.Generated.Zones not loadable")
else
	for _, zone in Zones do
		if zone.scope ~= "MVP" then
			continue
		end
		local found = 0
		for _, part in ofKind("Zone") do
			if part:GetAttribute("ZoneId") == zone.id then
				found += 1
			end
		end
		local name = `Zone volume {zone.id}`
		if not pending(DUE.zone[zone.id] or CURRENT_SPRINT, found, name) then
			check(found > 0, name, `{found} volume(s)`)
		end
	end
end

local nursery = #ofKind("SafeNursery")
if not pending(DUE.safeNursery, nursery, "SafeNursery volume") then
	check(nursery > 0, "SafeNursery volume", `{nursery} volume(s)`)
end

-- Cove mouths: CoveIndex 1 to 24, each exactly once.
local mouths = ofKind("CoveMouth")
if not pending(DUE.coveMouth, #mouths, "24 cove mouths") then
	local seen, problems = {}, {}
	for _, part in mouths do
		local index = part:GetAttribute("CoveIndex")
		if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > COVES then
			table.insert(problems, `{part:GetFullName()} has CoveIndex {index}`)
		elseif seen[index] then
			table.insert(problems, `CoveIndex {index} twice`)
		else
			seen[index] = true
		end
	end
	for index = 1, COVES do
		if not seen[index] then
			table.insert(problems, `CoveIndex {index} missing`)
		end
	end
	check(
		#problems == 0,
		"24 cove mouths",
		if #problems > 0 then table.concat(problems, "; ") else "1 to 24"
	)
end

-- Revive points: rp_01 to rp_12 at their generated rows, outside the shell and every Hazard volume.
local function inside(part: BasePart, point: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	local shape = if part:IsA("Part") then part.Shape else Enum.PartType.Block
	if shape == Enum.PartType.Ball then
		return p.Magnitude <= math.min(half.X, half.Y, half.Z)
	elseif shape == Enum.PartType.Cylinder then
		return math.abs(p.X) <= half.X
			and math.sqrt(p.Y * p.Y + p.Z * p.Z) <= math.min(half.Y, half.Z)
	end
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

local RevivePoints = loadData("RevivePoints")
if not RevivePoints then
	report(
		"FAIL",
		"12 revive points",
		"ReplicatedStorage.Shared.Data.Generated.RevivePoints not loadable"
	)
else
	local points = {}
	for _, part in ofKind("RevivePoint") do
		local id = part:GetAttribute("PointId")
		points[id] = points[id] or {}
		table.insert(points[id], part)
	end
	local shellParams = OverlapParams.new()
	shellParams.FilterType = Enum.RaycastFilterType.Include
	shellParams.FilterDescendantsInstances = if Collision then { Collision } else {}
	for _, row in RevivePoints do
		local found = points[row.id] or {}
		local name = `Revive point {row.id}`
		local due = math.max(DUE.revivePoint, DUE.zone[row.zone] or 0)
		if pending(due, #found, row.id, "Revive points") then
			continue
		end
		local part = found[1]
		if #found ~= 1 then
			report("FAIL", name, `{#found} parts with this PointId`)
			continue
		end
		local want = Vector3.new(row.x, -row.depth, row.z)
		local centre = part.Position
		local problems = {}
		if not (part:IsA("Part") and part.Shape == Enum.PartType.Ball) then
			table.insert(problems, "not a Ball part")
		end
		if (centre - want).Magnitude > REVIVE_TOLERANCE then
			table.insert(problems, `at {centre}, row says {want}`)
		end
		if Collision and #workspace:GetPartBoundsInRadius(centre, 0.5, shellParams) > 0 then
			table.insert(problems, "inside the collision shell")
		end
		for _, hazard in ofKind("Hazard") do
			if inside(hazard, centre) then
				table.insert(problems, `inside Hazard volume {hazard:GetFullName()}`)
			end
		end
		check(
			#problems == 0,
			name,
			if #problems > 0 then table.concat(problems, "; ") else "placed"
		)
	end
	flushPending()
	local unknownIds = {}
	local ids = {}
	for _, row in RevivePoints do
		ids[row.id] = true
	end
	for id in points do
		if not ids[id] then
			table.insert(unknownIds, tostring(id))
		end
	end
	if #unknownIds > 0 then
		report("FAIL", "Revive point ids", `unknown PointId {table.concat(unknownIds, " ")}`)
	end
end

--------------------------------------------------------------------------------------------------

local verdict = if counts.FAIL == 0 then "PASS" else "FAIL"
table.insert(
	lines,
	1,
	`check_place: {verdict} (sprint {CURRENT_SPRINT}; {counts.PASS} pass, {counts.FAIL} fail, `
		.. `{counts.PENDING} pending, {counts.UNREADABLE} unreadable)`
)
return table.concat(lines, "\n")
