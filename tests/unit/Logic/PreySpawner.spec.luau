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
			PreySpawner.setTide(sp, "frenzy")
			expect(krill.target >= before).toBe(true)
		end
	)

	it("spawns three groups of a normal row per pass in a Frenzy, one of a trait row", function()
		local sp = reefSpawner()
		PreySpawner.fill(sp, 0, NONE, NONE, NONE, 0)
		PreySpawner.setTide(sp, "frenzy")
		local shrimp = rowOf(sp, "shrimp")
		local goby = rowOf(sp, "dotted_goby")
		expect(shrimp.target - shrimp.count >= 3).toBe(true)
		local before = shrimp.count
		goby.count -= 2 -- two trait slots free, as if eaten with no delay left
		local gobyBefore = goby.count
		PreySpawner.pass(sp, 1, NONE, NONE, NONE, 0)
		expect(shrimp.count).toBe(before + 3)
		expect(goby.count).toBe(gobyBefore + 1)
		PreySpawner.setTide(sp, nil)
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

	it("releases event prey in animals: alive at once in whole groups, up to its total", function()
		local sp, sim = reefSpawner()
		PreySpawner.fill(sp, 0, NONE, NONE, NONE, 0)
		local fry = Index.TraitPrey.byId.lunar_fry
		local alive, total, size = fry.alive :: number, fry.eventTotal :: number, fry.groupMax
		expect(fry.groupMin).toBe(size)
		local b = sim.buffers
		local function eventAnimals(): (number, number)
			local animals, groups = 0, 0
			for g = 0, PreySim.MAX_GROUPS - 1 do
				if
					buffer.readu8(b.kind, g) ~= 0
					and bit32.btest(buffer.readu8(b.flags, g), PreySim.FLAG_EVENT)
				then
					animals += PreySim.aliveCount(sim, g)
					groups += 1
				end
			end
			return animals, groups
		end
		-- 03 §3.1: 12 at once in groups of 4 is 3 groups.
		expect(PreySpawner.startEvent(sp, "lunar_fry", 0, NONE, NONE, NONE, 0)).toBe(alive // size)
		expect((eventAnimals())).toBe(alive)
		-- Eat every event group each second; each pass tops up until the total is out.
		local released = alive
		for second = 1, 10 do
			for g = 0, PreySim.MAX_GROUPS - 1 do
				if
					buffer.readu8(b.kind, g) ~= 0
					and bit32.btest(buffer.readu8(b.flags, g), PreySim.FLAG_EVENT)
				then
					PreySim.remove(sim, g)
				end
			end
			PreySpawner.pass(sp, second, NONE, NONE, NONE, 0)
			local animals = eventAnimals()
			expect(animals <= alive).toBe(true)
			released += animals
		end
		expect(released).toBe(total)
		PreySpawner.startEvent(sp, "lunar_fry", 11, NONE, NONE, NONE, 0)
		PreySpawner.clearEvents(sp, 11)
		PreySpawner.pass(sp, 12, NONE, NONE, NONE, 0)
		local _, groups = eventAnimals()
		expect(groups).toBe(0)
	end)

	it("runs the crystal_jelly drift on the data's timing and size", function()
		local sp, sim = reefSpawner()
		PreySpawner.fill(sp, 0, NONE, NONE, NONE, 0)
		local def = Index.TraitPrey.byId.crystal_jelly
		PreySpawner.pass(sp, 1, NONE, NONE, NONE, 0)
		expect(sp.jellyGroup >= 0).toBe(true)
		local jelly = sp.jellyGroup
		expect(PreySim.aliveCount(sim, jelly)).toBe(def.alive :: number)
		PreySpawner.pass(sp, 1 + (def.lifetime :: number) - 1, NONE, NONE, NONE, 0)
		expect(PreySim.isLive(sim, jelly, sp.jellyGen) and sp.jellyGroup == jelly).toBe(true)
		PreySpawner.pass(sp, 1 + (def.lifetime :: number), NONE, NONE, NONE, 0)
		expect(PreySim.isLive(sim, jelly, sp.jellyGen) and sp.jellyGroup == jelly).toBe(false)
		PreySpawner.pass(sp, 1 + (def.respawn :: number) - 1, NONE, NONE, NONE, 0)
		expect(sp.jellyGroup).toBe(-1)
		PreySpawner.pass(sp, 1 + (def.respawn :: number), NONE, NONE, NONE, 0)
		expect(sp.jellyGroup >= 0).toBe(true)
	end)

	it("doubles targets only for the frenzy tide, and runs a pass every 10th tick", function()
		local sp = reefSpawner()
		PreySpawner.fill(sp, 0, NONE, NONE, NONE, 0)
		local shrimp = rowOf(sp, "shrimp")
		local normal = shrimp.target
		PreySpawner.setTide(sp, "moon_tide")
		expect(shrimp.target).toBe(normal)
		expect(sp.rate).toBe(Index.Tides.byId.moon_tide.spawnRateMult)
		PreySpawner.setTide(sp, "frenzy")
		expect(shrimp.target > normal).toBe(true)
		PreySpawner.setTide(sp, nil)
		-- Ticks of 0.1 s summed in floating point: a pass on every 10th tick.
		local passes, now = {}, 0
		local fresh = reefSpawner()
		PreySpawner.fill(fresh, 0, NONE, NONE, NONE, 0)
		for tick = 1, 100 do
			now += 0.1
			local next = fresh.nextPass
			PreySpawner.pass(fresh, now, NONE, NONE, NONE, 0)
			if fresh.nextPass ~= next then
				table.insert(passes, tick)
			end
		end
		expect(passes).toEqual({ 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 })
	end)

	it(
		"keeps owned groups out of rows, targets, culls and liveMembers, wherever they are placed",
		function()
			local sp, sim = reefSpawner()
			PreySpawner.fill(sp, 0, NONE, NONE, NONE, 0)
			local counts, targets = {}, {}
			for i, row in sp.rows do
				counts[i], targets[i] = row.count, row.target
			end
			local _, groups = PreySpawner.liveMembers(sp)
			expect(groups).toBe(sim.liveGroups)
			local targetMembers = PreySpawner.targetMembers(sp)
			-- A ball and a 10-mote trail, both outside the reef's only spawn area.
			local ball = PreySpawner.spawnOwned(
				sp,
				2,
				{ prey = "krill", count = 6, x = 900, y = 10, z = 900, spread = 3 },
				0
			)
			local points = {}
			for k = 0, 9 do
				table.insert(points, { 700 + 4 * k, 10, 700 })
			end
			local trail = PreySpawner.spawnOwned(sp, 2, { prey = "plankton", points = points }, 0)
			expect(ball ~= nil and trail ~= nil and ball ~= trail).toBe(true)
			local ownedMembers, ownedGroups = PreySpawner.ownedLive(sp)
			expect(ownedMembers).toBe(16)
			expect(ownedGroups).toBe(11)
			expect(select(2, PreySpawner.liveMembers(sp))).toBe(groups)
			for _, part in sp.owned[trail :: number].parts do
				expect(PreySim.ownerOf(sim, part.g)).toBe(2)
				expect(PreySim.aliveCount(sim, part.g)).toBe(1)
				-- A group of one sits on its group point (Formation: member 0).
				local x = PreySim.memberPosAt(sim, part.g, 0, 0)
				expect(x).toBeCloseTo(part.x, 0.05)
			end
			-- Thirty passes with a player next to the trail: nothing culls, straggles or recounts them.
			local px, py, pz = { 710 }, { 10 }, { 700 }
			for t = 1, 30 do
				PreySim.step(sim, t, 1)
				PreySpawner.pass(sp, t, px, py, pz, 1)
			end
			for i, row in sp.rows do
				expect(row.count).toBe(counts[i])
				expect(row.target).toBe(targets[i])
			end
			-- (A crystal_jelly drift may have joined the shared groups meanwhile.)
			expect(select(2, PreySpawner.liveMembers(sp))).toBe(sim.liveGroups - 11)
			expect(PreySpawner.targetMembers(sp)).toBe(targetMembers)
			expect(select(2, PreySpawner.ownedLive(sp))).toBe(11)
		end
	)

	it("refuses unknown prey, malformed specs and specs over the owned budgets", function()
		local sp = reefSpawner()
		local function motes(n: number): { { number } }
			local list = {}
			for k = 1, n do
				table.insert(list, { 4 * k, -50, 0 })
			end
			return list
		end
		expect(PreySpawner.spawnOwned(sp, 1, { prey = "nope", x = 0, y = 0, z = 0 }, 0)).toBe(nil)
		expect(
			PreySpawner.spawnOwned(sp, 1, { prey = "krill", count = 25, x = 0, y = 0, z = 0 }, 0)
		).toBe(nil)
		expect(PreySpawner.spawnOwned(sp, 1, { prey = "krill", count = 6 }, 0)).toBe(nil)
		expect(
			PreySpawner.spawnOwned(sp, 1, { prey = "plankton", count = 3, points = motes(2) }, 0)
		).toBe(nil)
		local perSlot = PreySpawner.OWNED_MAX_PER_SLOT
		expect(
			PreySpawner.spawnOwned(sp, 1, { prey = "plankton", points = motes(perSlot) }, 0) ~= nil
		).toBe(true)
		expect(PreySpawner.spawnOwned(sp, 1, { prey = "glowfry", x = 0, y = -50, z = 0 }, 0)).toBe(
			nil
		)
		-- The server budget: whole slots until it is reached, then nothing more for anyone.
		local slot = 1
		while sp.ownedTotal + perSlot <= PreySpawner.OWNED_MAX_GROUPS do
			slot += 1
			PreySpawner.spawnOwned(sp, slot, { prey = "plankton", points = motes(perSlot) }, 0)
		end
		local left = PreySpawner.OWNED_MAX_GROUPS - sp.ownedTotal
		expect(
			PreySpawner.spawnOwned(sp, slot + 1, { prey = "plankton", points = motes(left + 1) }, 0)
		).toBe(nil)
		expect(
			PreySpawner.spawnOwned(sp, slot + 1, { prey = "plankton", points = motes(left) }, 0)
				~= nil
		).toBe(true)
		expect(sp.ownedTotal).toBe(PreySpawner.OWNED_MAX_GROUPS)
		expect(select(2, PreySpawner.ownedLive(sp))).toBe(PreySpawner.OWNED_MAX_GROUPS)
	end)

	it(
		"respawns a respawning owned group after PreyDef.respawn, and clears a slot's groups",
		function()
			local sp, sim = reefSpawner()
			local removed: { number } = {}
			sp.onRemoved = function(g: number, _gen: number)
				table.insert(removed, g)
			end
			local delay = Index.Prey.byId.krill.respawn :: number
			local id = PreySpawner.spawnOwned(
				sp,
				4,
				{ prey = "krill", count = 3, x = 0, y = -50, z = 0, spread = 3, respawn = true },
				0
			) :: number
			local once = PreySpawner.spawnOwned(
				sp,
				4,
				{ prey = "glowfry", x = 5, y = -50, z = 0 },
				0
			) :: number
			local run, single = sp.owned[id], sp.owned[once]
			local g, gen = run.parts[1].g, run.parts[1].gen
			local fry = single.parts[1].g
			expect(PreySpawner.ownedRun(sp, g)).toBe(run)
			-- Eat the ball out at t = 10, and the glowfry.
			for m = 0, 2 do
				PreySim.clearMember(sim, g, m)
				PreySpawner.onEaten(sp, g, 10)
			end
			PreySim.clearMember(sim, fry, 0)
			PreySpawner.onEaten(sp, fry, 10)
			expect(#removed).toBe(2)
			expect(sp.owned[once]).toBe(nil) -- gone for good, its budget back
			expect(sp.ownedBySlot[4]).toBe(1)
			expect(run.parts[1].g).toBe(-1)
			for t = 11, 10 + delay do
				PreySpawner.pass(sp, t, NONE, NONE, NONE, 0)
				expect(run.parts[1].g >= 0).toBe(t >= 10 + delay)
			end
			local back = run.parts[1].g
			expect(PreySim.isLive(sim, back)).toBe(true)
			expect(PreySim.aliveCount(sim, back)).toBe(3)
			expect(back ~= g or run.parts[1].gen ~= gen).toBe(true)
			expect(PreySim.ownerOf(sim, back)).toBe(4)
			expect(PreySpawner.edibleAt(sp, back, 10 + delay)).toBe(false)
			-- Clearing the slot removes it through onRemoved and frees every budget.
			expect(PreySpawner.clearOwned(sp, 4, 30)).toBe(1)
			expect(removed[#removed]).toBe(back)
			expect(next(sp.owned)).toBe(nil)
			expect(sp.ownedTotal).toBe(0)
			expect(sp.ownedBySlot[4]).toBe(0)
			expect(PreySpawner.clearOwned(sp, 4, 31)).toBe(0)
		end
	)
end)
