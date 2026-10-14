--!strict
-- Engine-side spec of WorldIndex on the CI place's test arena (docs/09, sections 5.1, 6.5 and
-- 9.1; the arena is in ci.project.json). The arithmetic is covered in Lune by tests/unit/Logic;
-- this checks what needs the engine: the collision groups, reading and destroying the tagged
-- parts, the rays of the height field and the segment test. Main.server has already run
-- WorldIndex.init and start, so the queries see the arena's volumes.
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeightFieldMath = require(ReplicatedStorage.Shared.Logic.HeightFieldMath)
local Index = require(ReplicatedStorage.Shared.Data.Index)
local TestKit = require(ReplicatedStorage.Shared.Util.TestKit)

local CollisionGroups = require("../World/CollisionGroups")
local HeightField = require("../World/HeightField")
local WorldIndex = require("../Services/WorldIndex")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local FLOOR_TOP = -100 -- the arena floor's top face
local ROCK_TOP = -40 -- the rock spans X 40 to 80, Z -80 to -40, from the floor to here

return function()
	describe("WorldIndex (engine, test arena)", function()
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
			expect(#WorldIndex.volumesOf("CoveMouth")).toBe(1)
			expect(#WorldIndex.volumesOf("CoveInterior")).toBe(1)
			expect(#WorldIndex.volumesOf("Hazard")).toBe(1)
			expect(WorldIndex.volumesOf("Hazard")[1].attrs.HazardId).toBe("jelly_bloom")
			expect(#WorldIndex.volumesOf("Current")).toBe(0)
			expect(#WorldIndex.volumesOf("RevivePoint")).toBe(0) -- kept apart, never sent
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
