--!strict
local Index = require("../../../src/shared/Data/Index")
local PreySim = require("../../../src/shared/Sim/PreySim")
local PreySpawnMath = require("../../../src/shared/Logic/PreySpawnMath")
local PreySpawner = require("../../../src/shared/Logic/PreySpawner")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local NONE: { number } = {}

-- The CI arena's reef: one 512 × 512 block, areaScale 512² ÷ the reef's plan area.
local function reefSpawner(): (PreySpawner.Spawner, PreySim.Sim)
	local sim = PreySim.new(3)
	local sp = PreySpawner.new(sim, 4)
	PreySpawner.addArea(sp, "reef", 0, -50, 0, 256, 50, nil)
	PreySpawner.setZoneScale(sp, "reef", 512 * 512 / 502655)
	PreySpawner.setPlayers(sp, 1, nil)
	PreySpawner.build(sp)
	return sp, sim
end

local function rowOf(sp: PreySpawner.Spawner, prey: string): PreySpawner.Row
	for _, row in sp.rows do
		if row.prey == prey then
			return row
		end
	end
	error(`no row {prey}`)
end

describe("PreySpawner", function()
	it("fills each row of a zone to PreySpawnMath's target, trait prey included", function()
		local sp, sim = reefSpawner()
		PreySpawner.fill(sp, 0, NONE, NONE, NONE, 0)
		for _, def in Index.PreySpawns.byZone.reef do
			local want =
				PreySpawnMath.target(def, { players = 1, area = 512 * 512 / 502655 * def.zoneArea })
			expect(rowOf(sp, def.prey).count).toBe(want)
		end
		expect(rowOf(sp, "dotted_goby").count).toBe(math.floor(10 * 512 * 512 / 502655 + 0.5))
		local _, groups = PreySpawner.liveMembers(sp)
		local rowsTotal = 0
		for _, row in sp.rows do
			rowsTotal += row.count
		end
		expect(groups).toBe(rowsTotal)
		expect(sim.liveGroups).toBe(groups)
	end)

	it(
		"respawns one group per row per pass after the respawn delay, divided in a Frenzy",
		function()
			local sp, sim = reefSpawner()
			PreySpawner.fill(sp, 0, NONE, NONE, NONE, 0)
			local removed = {}
			sp.onRemoved = function(g: number, _gen: number)
				table.insert(removed, g)
			end
			local krill = rowOf(sp, "krill")
			local before = krill.count
			-- Eat a whole krill swarm.
			local b = sim.buffers
			local target = -1
			for g = 0, PreySim.MAX_GROUPS - 1 do
				if buffer.readu8(b.kind, g) == krill.kind then
					target = g
					break
				end
			end
			for i = 0, buffer.readu8(b.count, target) - 1 do
				PreySim.clearMember(sim, target, i)
				if PreySpawner.onEaten(sp, target, 10) then
					break
				end
			end
			expect(removed).toEqual({ target })
			expect(krill.count).toBe(before - 1)
			expect(krill.readyAt).toBe(10 + 12)
			PreySpawner.pass(sp, 15, NONE, NONE, NONE, 0)
			expect(krill.count).toBe(before - 1)
			PreySpawner.pass(sp, 22, NONE, NONE, NONE, 0)
			expect(krill.count).toBe(before)
			-- Frenzy: targets double (up to the doubled cap) and delays are a third.
			PreySpawner.setRate(sp, 3)
			expect(krill.target >= before).toBe(true)
		end
	)

	it("spawns three groups of a normal row per pass in a Frenzy, one of a trait row", function()
		local sp = reefSpawner()
		PreySpawner.fill(sp, 0, NONE, NONE, NONE, 0)
		PreySpawner.setRate(sp, 3)
		local shrimp = rowOf(sp, "shrimp")
		local goby = rowOf(sp, "dotted_goby")
		expect(shrimp.target - shrimp.count >= 3).toBe(true)
		local before = shrimp.count
		goby.count -= 2 -- two trait slots free, as if eaten with no delay left
		local gobyBefore = goby.count
		PreySpawner.pass(sp, 1, NONE, NONE, NONE, 0)
		expect(shrimp.count).toBe(before + 3)
		expect(goby.count).toBe(gobyBefore + 1)
		PreySpawner.setRate(sp, 1)
		PreySpawner.pass(sp, 2, NONE, NONE, NONE, 0)
		expect(shrimp.count <= before + 3).toBe(true)
	end)

	it("turns a swarm down to two members into stragglers that leave after 10 s alone", function()
		local sp, sim = reefSpawner()
		PreySpawner.fill(sp, 0, NONE, NONE, NONE, 0)
		local krill = rowOf(sp, "krill")
		local b = sim.buffers
		local g = -1
		for k = 0, PreySim.MAX_GROUPS - 1 do
			if buffer.readu8(b.kind, k) == krill.kind then
				g = k
				break
			end
		end
		local count = buffer.readu8(b.count, g)
		local before = krill.count
		for i = 0, count - 3 do
			PreySim.clearMember(sim, g, i)
			PreySpawner.onEaten(sp, g, 5)
		end
		expect(PreySim.aliveCount(sim, g)).toBe(2)
		expect(krill.count).toBe(before - 1)
		PreySpawner.pass(sp, 10, NONE, NONE, NONE, 0)
		expect(PreySim.isLive(sim, g)).toBe(true)
		PreySpawner.pass(sp, 16, NONE, NONE, NONE, 0)
		expect(
			PreySim.isLive(sim, g)
				and buffer.readu8(b.kind, g) == krill.kind
				and PreySim.aliveCount(sim, g) == 2
		).toBe(false)
	end)

	it(
		"keeps a new group 60 studs from players when it can, and makes it inedible for 0.5 s",
		function()
			local sp, sim = reefSpawner()
			local px, py, pz = { 0 }, { -50 }, { 0 }
			PreySpawner.fill(sp, 0, px, py, pz, 1)
			local b = sim.buffers
			local close = 0
			for g = 0, PreySim.MAX_GROUPS - 1 do
				if buffer.readu8(b.kind, g) ~= 0 then
					local x, y, z =
						buffer.readf32(b.posX, g * 4),
						buffer.readf32(b.posY, g * 4),
						buffer.readf32(b.posZ, g * 4)
					if x * x + (y + 50) ^ 2 + z * z < 60 * 60 then
						close += 1
					end
					expect(PreySpawner.edibleAt(sp, g, 0.4)).toBe(false)
					expect(PreySpawner.edibleAt(sp, g, 0.5)).toBe(true)
				end
			end
			expect(close).toBe(0)
		end
	)

	it("spawns and clears event prey, and runs the crystal_jelly drift", function()
		local sp, sim = reefSpawner()
		PreySpawner.fill(sp, 0, NONE, NONE, NONE, 0)
		local base = sim.liveGroups
		expect(PreySpawner.spawnEvent(sp, "lunar_fry", 4, 0, NONE, NONE, NONE, 0)).toBe(4)
		expect(PreySpawner.clearEvents(sp, 1)).toBe(4)
		expect(sim.liveGroups).toBe(base)
		PreySpawner.pass(sp, 1, NONE, NONE, NONE, 0)
		expect(sp.jellyGroup >= 0).toBe(true)
		local jelly = sp.jellyGroup
		expect(PreySim.aliveCount(sim, jelly)).toBe(5)
		PreySpawner.pass(sp, 1 + 240, NONE, NONE, NONE, 0)
		expect(PreySim.isLive(sim, jelly, sp.jellyGen) and sp.jellyGroup == jelly).toBe(false)
	end)
end)
