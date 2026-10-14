--!strict
-- Engine-side spec of WorldIndex on the CI place's test arena (docs/09, sections 5.1, 6.5 and
-- 9.1; the arena is in ci.project.json). The arithmetic is covered in Lune by tests/unit/Logic;
-- this checks what needs the engine: the collision groups, reading and destroying the tagged
-- parts, the rays of the height field and the segment test.
--
-- RunAll runs through MCP or Open Cloud in its own Luau VM, so its `require` of WorldIndex is not
-- the instance Main.server started, and Main has already destroyed the arena's tagged parts. The
-- spec therefore re-authors the arena's volumes from VOLUMES (a copy of the Volumes folder in
-- ci.project.json; keep the two equal) and runs WorldIndex.init in this VM. The collision shell is
-- never destroyed, so the floor and segment checks use the arena itself.
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoveMouths = require(ReplicatedStorage.Shared.Data.Generated.CoveMouths)
local CoveRules = require(ReplicatedStorage.Shared.Logic.CoveRules)
local HeightFieldMath = require(ReplicatedStorage.Shared.Logic.HeightFieldMath)
local Index = require(ReplicatedStorage.Shared.Data.Index)
local NurseryRoute = require(ReplicatedStorage.Shared.Logic.NurseryRoute)
local TestKit = require(ReplicatedStorage.Shared.Util.TestKit)

local CollisionGroups = require("../World/CollisionGroups")
local HeightField = require("../World/HeightField")
local WorldIndex = require("../Services/WorldIndex")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local FLOOR_TOP = -100 -- the arena floor's top face
local ROCK_TOP = -40 -- the rock spans X 40 to 80, Z -80 to -40, from the floor to here

local IDENTITY = CFrame.identity
local UPRIGHT = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, -Vector3.xAxis, Vector3.zAxis)

-- ci.project.json's Workspace.Volumes, one part per row.
type Attrs = { [string]: string | number }
type Row = { name: string, shape: Enum.PartType, cf: CFrame, size: Vector3, attrs: Attrs }

local function row(
	name: string,
	shape: Enum.PartType,
	at: Vector3,
	size: Vector3,
	rotation: CFrame,
	attrs: Attrs
): Row
	return { name = name, shape = shape, cf = CFrame.new(at) * rotation, size = size, attrs = attrs }
end

local VOLUMES: { Row } = {
	row(
		"ZoneReef",
		Enum.PartType.Block,
		Vector3.new(0, -50, 0),
		Vector3.new(512, 100, 512),
		IDENTITY,
		{ Kind = "Zone", ZoneId = "reef" }
	),
	row(
		"ZoneNursery",
		Enum.PartType.Ball,
		Vector3.new(-150, -50, -150),
		Vector3.new(80, 80, 80),
		IDENTITY,
		{ Kind = "Zone", ZoneId = "nursery" }
	),
	row(
		"SafeNursery",
		Enum.PartType.Ball,
		Vector3.new(-150, -50, -150),
		Vector3.new(80, 80, 80),
		IDENTITY,
		{ Kind = "SafeNursery" }
	),
	row(
		"ZoneKelp",
		Enum.PartType.Block,
		Vector3.new(420, -50, 0),
		Vector3.new(200, 100, 200),
		IDENTITY,
		{ Kind = "Zone", ZoneId = "kelp" }
	),
	row(
		"CoveMouth3",
		Enum.PartType.Cylinder,
		Vector3.new(150, -50, 150),
		Vector3.new(20, 30, 30),
		UPRIGHT,
		{ Kind = "CoveMouth", CoveIndex = 3 }
	),
	row(
		"CoveInterior3",
		Enum.PartType.Block,
		Vector3.new(150, -50, 180),
		Vector3.new(20, 20, 20),
		IDENTITY,
		{ Kind = "CoveInterior", CoveIndex = 3 }
	),
	row(
		"HazardJelly",
		Enum.PartType.Ball,
		Vector3.new(-150, -50, 150),
		Vector3.new(30, 30, 30),
		IDENTITY,
		{ Kind = "Hazard", HazardId = "jelly_bloom" }
	),
	row(
		"HatchBed",
		Enum.PartType.Ball,
		Vector3.new(-160, -60, -150),
		Vector3.new(4, 4, 4),
		CFrame.lookAt(Vector3.zero, Vector3.xAxis), -- facing east (03 §6.2)
		{ Kind = "HatchBed" }
	),
}

-- The other 23 coves of ci.project.json at their data:CoveMouths mouths (cove 3 keeps the test
-- shapes above).
for _, def in CoveMouths do
	if def.wire ~= 3 then
		local mouth, room = CoveRules.volumes(def.x, def.z)
		local boxes: { [string]: CoveRules.BoxVolume } = { CoveMouth = mouth, CoveInterior = room }
		for _, kind in { "CoveMouth", "CoveInterior" } do
			local box = boxes[kind]
			table.insert(
				VOLUMES,
				row(
					`{kind}{def.wire}`,
					Enum.PartType.Block,
					Vector3.new(box.x, box.y, box.z),
					Vector3.new(box.size[1], box.size[2], box.size[3]),
					CFrame.lookAlong(Vector3.zero, Vector3.new(box.lookX, 0, box.lookZ)),
					{ Kind = kind, CoveIndex = def.wire }
				)
			)
		end
	end
end

-- The first-run route of ci.project.json at its data:NurseryPath places (03 §6.2), as
-- NurseryRoute.volumes lays it out; the arena keeps its own test HatchBed above.
local SHAPES: { [string]: Enum.PartType } =
	{ Block = Enum.PartType.Block, Ball = Enum.PartType.Ball, Cylinder = Enum.PartType.Cylinder }
for _, v in NurseryRoute.volumes() do
	if v.kind == NurseryRoute.KIND then
		table.insert(VOLUMES, {
			name = v.name,
			shape = SHAPES[v.shape],
			cf = CFrame.new(table.unpack(v.frame)),
			size = Vector3.new(v.size[1], v.size[2], v.size[3]),
			attrs = { Kind = v.kind, PointId = v.pointId :: string },
		})
	end
end

-- Authors the arena's volumes and revive points again when Main has already read them, then
-- initialises this VM's WorldIndex from them.
local function initArena()
	if #CollectionService:GetTagged("Volume") == 0 then
		local folder = Instance.new("Folder")
		folder.Name = "SpecVolumes"
		local rows = table.clone(VOLUMES)
		for _, def in Index.RevivePoints.list do
			local at = Vector3.new(def.x, -def.depth, def.z)
			local attrs: Attrs = { Kind = "RevivePoint", PointId = def.id }
			table.insert(
				rows,
				row(def.id, Enum.PartType.Ball, at, Vector3.new(4, 4, 4), IDENTITY, attrs)
			)
		end
		for _, r in rows do
			local part = Instance.new("Part")
			part.Name, part.Shape, part.Size, part.CFrame = r.name, r.shape, r.size, r.cf
			part.Anchored, part.CanCollide, part.CanQuery, part.Transparency = true, false, false, 1
			for key, value in r.attrs do
				part:SetAttribute(key, value)
			end
			part:AddTag("Volume")
			part.Parent = folder
		end
		folder.Parent = workspace
	end
	WorldIndex.init()
end

return function()
	describe("WorldIndex (engine, test arena)", function()
		initArena()

		it("registered the five groups of 6.5 with its collision matrix", function()
			for _, name in CollisionGroups.NAMES do
				expect(PhysicsService:IsCollisionGroupRegistered(name)).toBe(true)
			end
			local function can(a: string, b: string): boolean
				return PhysicsService:CollisionGroupsAreCollidable(a, b)
			end
			expect(can("World", "Creature")).toBe(true)
			expect(can("World", "CreatureEel")).toBe(true)
			expect(can("Creature", "Creature")).toBe(true)
			expect(can("Creature", "EelGate")).toBe(true)
			expect(can("CreatureEel", "EelGate")).toBe(false)
			expect(can("World", "World")).toBe(false)
			expect(can("Visual", "Creature")).toBe(false)
			expect(can("Visual", "World")).toBe(false)
			expect(can("World", "Default")).toBe(false)
		end)

		it("put the collision shell in World", function()
			local shell = workspace:FindFirstChild("Collision")
			expect(shell ~= nil).toBe(true)
			for _, part in (shell :: Instance):GetDescendants() do -- safe: checked just above
				if part:IsA("BasePart") then
					expect(part.CollisionGroup).toBe("World")
				end
			end
		end)

		it("read the tagged parts and destroyed them", function()
			expect(#CollectionService:GetTagged("Volume")).toBe(0)
			expect(#WorldIndex.volumesOf("Zone")).toBe(3)
			expect(#WorldIndex.volumesOf("SafeNursery")).toBe(1)
			expect(#WorldIndex.volumesOf("CoveMouth")).toBe(24)
			expect(#WorldIndex.volumesOf("CoveInterior")).toBe(24)
			expect(#WorldIndex.volumesOf("Hazard")).toBe(1)
			expect(WorldIndex.volumesOf("Hazard")[1].attrs.HazardId).toBe("jelly_bloom")
			expect(#WorldIndex.volumesOf("Current")).toBe(0)
			expect(#WorldIndex.volumesOf("RevivePoint")).toBe(0) -- kept apart, never sent
			expect(#WorldIndex.volumesOf("HatchBed")).toBe(1)
			expect(#WorldIndex.volumesOf("NurseryPath")).toBe(#Index.NurseryPath.list - 1)
		end)

		it("answers hatchBed with the centre and the look vector (9.1)", function()
			local at, look = WorldIndex.hatchBed()
			expect(at ~= nil and look ~= nil).toBe(true)
			expect(((at :: Vector3) - Vector3.new(-160, -60, -150)).Magnitude < 1e-3).toBe(true)
			expect(((look :: Vector3) - Vector3.xAxis).Magnitude < 1e-3).toBe(true)
		end)

		it("answers zoneAt: nested zone first, else the nearest zone", function()
			expect(WorldIndex.zoneAt(0, -50, 0)).toBe("reef")
			expect(WorldIndex.zoneAt(-150, -50, -150)).toBe("nursery")
			expect(WorldIndex.zoneAt(-150, -50, -115)).toBe("nursery") -- 35 from a 40 radius
			expect(WorldIndex.zoneAt(-150, -50, -105)).toBe("reef")
			expect(WorldIndex.zoneAt(420, -50, 0)).toBe("kelp")
			expect(WorldIndex.zoneAt(300, -50, 0)).toBe("kelp") -- outside both, nearer kelp
			expect(WorldIndex.zoneAt(270, -50, 0)).toBe("reef")
		end)

		it("answers isSafe and coveMouthAt", function()
			expect(WorldIndex.isSafe(-150, -50, -150)).toBe(true) -- SafeNursery
			expect(WorldIndex.isSafe(150, -50, 160)).toBe(true) -- CoveMouth 3
			expect(WorldIndex.isSafe(150, -50, 185)).toBe(true) -- CoveInterior 3
			expect(WorldIndex.isSafe(0, -50, 0)).toBe(false)
			expect(WorldIndex.isSafe(-150, -50, 150)).toBe(false) -- a Hazard is not safe
			expect(WorldIndex.coveMouthAt(150, -50, 160)).toBe(3) -- 10 out of a radius of 15
			expect(WorldIndex.coveMouthAt(150, -41, 150)).toBe(3) -- the cylinder stands upright
			expect(WorldIndex.coveMouthAt(150, -38, 150)).toBe(nil)
			expect(WorldIndex.coveMouthAt(150, -50, 166)).toBe(nil)
			expect(WorldIndex.coveMouthAt(0, -50, 0)).toBe(nil)
			-- A real cove (C16, data:CoveMouths): just inside the mouth plane, then just outside.
			local c16 = CoveMouths[16]
			local r = math.sqrt(c16.x * c16.x + c16.z * c16.z)
			local ox, oz = c16.x / r, c16.z / r
			expect(WorldIndex.coveMouthAt(c16.x + ox, -30, c16.z + oz)).toBe(16)
			expect(WorldIndex.coveMouthAt(c16.x - ox, -30, c16.z - oz)).toBe(nil)
			expect(WorldIndex.isSafe(c16.x + ox * 80, -30, c16.z + oz * 80)).toBe(true) -- chamber
		end)

		it("answers nurseryPathAt along the first-run route (03 §6.2, 04 §3.5)", function()
			local gx, gz = NurseryRoute.pointAt(122)
			expect(WorldIndex.nurseryPathAt(gx, -17, gz)).toBe("little_arch") -- the Gap
			expect(WorldIndex.nurseryPathAt(-299, -17, 299)).toBe("kelp_curtain")
			local ax, az = NurseryRoute.pointAt(185)
			expect(WorldIndex.nurseryPathAt(ax, -40, az)).toBe("elbow_leg_1") -- across the Gap
			expect(WorldIndex.nurseryPathAt(-210, -28, 210)).toBe("elbow_bend")
			local bx, bz = NurseryRoute.pointAt(300)
			expect(WorldIndex.nurseryPathAt(bx, -40, bz)).toBe("elbow_leg_2")
			expect(WorldIndex.nurseryPathAt(-384, -18, 339)).toBe("swarm_a")
			expect(WorldIndex.nurseryPathAt(-322, -18, 301)).toBe("glow_grotto")
			expect(WorldIndex.nurseryPathAt(gx, -4, gz)).toBe(nil) -- above the arch's opening
			expect(WorldIndex.nurseryPathAt(0, -50, 0)).toBe(nil)
		end)

		it("answers floorY over the floor, the rock and open map", function()
			expect(WorldIndex.floorY(0, 0)).toBeCloseTo(FLOOR_TOP, 0.02)
			expect(WorldIndex.floorY(60, -60)).toBeCloseTo(ROCK_TOP, 0.02)
			expect(WorldIndex.floorY(800, 800)).toBe(HeightFieldMath.Y_MIN) -- no shell there
		end)

		it("builds a height field that matches single rays", function()
			local field = HeightField.new(
				CollisionGroups.worldRayParams(workspace:FindFirstChild("Collision"))
			)
			local t0 = os.clock()
			HeightField.buildRows(field, HeightFieldMath.SIZE)
			local seconds = os.clock() - t0
			expect(field.ready).toBe(true)
			for _, p in { { 0, 0 }, { 60, -60 }, { -200, 200 }, { 800, 800 }, { 4, 4 } } do
				local x, z = p[1], p[2]
				expect(HeightField.floorY(field, x, z)).toBeCloseTo(
					HeightField.cast(field.params, x, z),
					0.02
				)
			end
			-- The whole field in one go is the worst case; it is spread over 2 s at start.
			print(`[WorldIndexSpec] 65,536 floor rays in {math.floor(seconds * 1000)} ms`)
		end)

		it("answers segmentBlocked against the shell", function()
			local blocked = WorldIndex.segmentBlocked
			expect(blocked(Vector3.new(0, -50, -60), Vector3.new(100, -50, -60))).toBe(true) -- through the rock
			expect(blocked(Vector3.new(0, -50, 60), Vector3.new(100, -50, 60))).toBe(false) -- open water
			expect(blocked(Vector3.new(0, -90, 0), Vector3.new(0, -110, 0))).toBe(true) -- into the floor
			-- Touching the rock face in the last 2% of the segment is not a block (section 7.2).
			expect(blocked(Vector3.new(-60, -50, -60), Vector3.new(40.5, -50, -60))).toBe(false)
			expect(blocked(Vector3.new(5, -50, 5), Vector3.new(5, -50, 5))).toBe(false)
		end)

		it("keeps the 12 revive points at their generated rows, in order", function()
			local points = WorldIndex.revivePoints()
			expect(#points).toBe(12)
			for i, def in Index.RevivePoints.list do
				local p = points[i]
				expect(p.id).toBe(def.id)
				expect(p.wire).toBe(def.wire)
				expect(p.x).toBeCloseTo(def.x, 0.01)
				expect(p.y).toBeCloseTo(-def.depth, 0.01)
				expect(p.z).toBeCloseTo(def.z, 0.01)
			end
		end)
	end)
end
