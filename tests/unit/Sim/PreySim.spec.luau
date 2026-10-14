--!strict
local Formation = require("../../../src/shared/Sim/Formation")
local PreySim = require("../../../src/shared/Sim/PreySim")
local Rng = require("../../../src/shared/Util/Rng")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local DT = 0.1
local KRILL = Formation.kindOf("krill") :: number
local PLANKTON = Formation.kindOf("plankton") :: number
local SHRIMP = Formation.kindOf("shrimp") :: number
local SARDINE = Formation.kindOf("sardine") :: number
local TUNA = Formation.kindOf("tuna") :: number
local PLAYER = PreySim.THREAT_PLAYER

-- A sim with one home at the origin (radius 60, half height 20) and the clock at 0.
local function newSim(seed: number?): PreySim.Sim
	local sim = PreySim.new(seed or 1)
	PreySim.setHome(sim, 0, 0, -50, 0, 60, 20)
	return sim
end

local function pos(sim: PreySim.Sim, g: number): (number, number, number)
	local b = sim.buffers
	return buffer.readf32(b.posX, g * 4),
		buffer.readf32(b.posY, g * 4),
		buffer.readf32(b.posZ, g * 4)
end

local function flags(sim: PreySim.Sim, g: number): number
	return buffer.readu8(sim.buffers.flags, g)
end

local function scatter(sim: PreySim.Sim, g: number): number
	return buffer.readf32(sim.buffers.scatter, g * 4)
end

-- Steps `ticks` ticks from `now`, calling `threats(now)` before each; returns the new time.
local function run(sim: PreySim.Sim, now: number, ticks: number, threats: ((number) -> ())?): number
	for _ = 1, ticks do
		now += DT
		if threats then
			threats(now)
		end
		PreySim.step(sim, now, DT)
	end
	return now
end

describe("Sim/PreySim (09 §8.1 to 8.4)", function()
	it("spawns into free slots, bumps gen on reuse and wraps it below 255", function()
		local sim = newSim()
		local g, gen = PreySim.spawn(sim, KRILL, 0, 0, -50, 0, 16)
		expect(g).toBe(0)
		expect(gen).toBe(1)
		expect(PreySim.isLive(sim, 0, 1)).toBe(true)
		expect(PreySim.isLive(sim, 0, 2)).toBe(false)
		expect(PreySim.aliveCount(sim, 0)).toBe(16)
		expect(PreySim.clearMember(sim, 0, 3)).toBe(15)
		expect(PreySim.memberAlive(sim, 0, 3)).toBe(false)
		expect(PreySim.memberAlive(sim, 0, 4)).toBe(true)
		PreySim.remove(sim, 0)
		expect(PreySim.isLive(sim, 0)).toBe(false)
		buffer.writeu8(sim.buffers.gen, 0, PreySim.MAX_GEN)
		local g2, gen2 = PreySim.spawn(sim, KRILL, 0, 0, -50, 0, 12, false, 0)
		expect(g2).toBe(0)
		expect(gen2).toBe(0)
		for _ = 2, PreySim.MAX_GROUPS do
			expect(PreySim.spawn(sim, TUNA, 0, 0, -50, 0, 1) ~= nil).toBe(true)
		end
		expect(sim.liveGroups).toBe(PreySim.MAX_GROUPS)
		expect((PreySim.spawn(sim, TUNA, 0, 0, -50, 0, 1))).toBe(nil)
	end)

	it("flees straight away from a threat that can eat it, within fleeRadius only", function()
		local sim = newSim()
		local g = PreySim.spawn(sim, KRILL, 0, 0, -50, 0, 16) :: number
		PreySim.setThreatCount(sim, 1)
		-- Too small to eat krill (tier 1): ignored.
		PreySim.setThreat(sim, 0, -8, -50, 0, 0, PLAYER)
		local now = run(sim, 0, 1)
		expect(bit32.btest(flags(sim, g), PreySim.FLAG_FLEEING)).toBe(false)
		-- Big enough but hidden (Camo, ink): ignored.
		PreySim.setThreat(sim, 0, -8, -50, 0, 1, PLAYER + PreySim.THREAT_HIDDEN)
		now = run(sim, now, 1)
		expect(bit32.btest(flags(sim, g), PreySim.FLAG_FLEEING)).toBe(false)
		-- Outside fleeRadius (10): ignored.
		local x = pos(sim, g)
		PreySim.setThreat(sim, 0, x - 12, -50, 0, 1, PLAYER)
		now = run(sim, now, 1)
		expect(bit32.btest(flags(sim, g), PreySim.FLAG_FLEEING)).toBe(false)
		-- Inside: flees along +X, away from the threat, toward flee speed.
		x = pos(sim, g)
		PreySim.setThreat(sim, 0, x - 6, -50, 0, 1, PLAYER)
		now = run(sim, now, 3)
		expect(bit32.btest(flags(sim, g), PreySim.FLAG_FLEEING)).toBe(true)
		local vx = buffer.readf32(sim.buffers.velX, g * 4)
		local vz = buffer.readf32(sim.buffers.velZ, g * 4)
		expect(vx > 8).toBe(true)
		expect(math.abs(vz) < 0.5 * vx).toBe(true)
		expect(math.sqrt(vx * vx + vz * vz) <= 14 + 1e-3).toBe(true)
	end)

	it("never makes drifting plankton flee", function()
		local sim = newSim()
		local g = PreySim.spawn(sim, PLANKTON, 0, 0, -50, 0, 8) :: number
		PreySim.setThreatCount(sim, 1)
		PreySim.setThreat(sim, 0, 1, -50, 0, 9, PLAYER)
		run(sim, 0, 20)
		expect(bit32.btest(flags(sim, g), PreySim.FLAG_FLEEING)).toBe(false)
		local vx, vz =
			buffer.readf32(sim.buffers.velX, g * 4), buffer.readf32(sim.buffers.velZ, g * 4)
		expect(math.sqrt(vx * vx + vz * vz) <= 2 + 1e-3).toBe(true)
	end)

	it("scatters a fleeing swarm, then regroups it after the flee", function()
		local sim = newSim()
		local g = PreySim.spawn(sim, KRILL, 0, 0, -50, 0, 16) :: number
		PreySim.setThreatCount(sim, 1)
		local now = run(sim, 0, 5, function()
			local x, y, z = pos(sim, g)
			PreySim.setThreat(sim, 0, x - 5, y, z, 1, PLAYER)
		end)
		expect(scatter(sim, g)).toBeCloseTo(1, 1e-6) -- 2 per second up: full after 0.5 s
		PreySim.setThreat(sim, 0, 0, -50, 40, -1, PLAYER) -- a player that cannot eat krill
		now = run(sim, now, 13) -- the flee hold (1.2 s) runs out
		expect(bit32.btest(flags(sim, g), PreySim.FLAG_FLEEING)).toBe(false)
		expect(scatter(sim, g) < 1).toBe(true)
		now = run(sim, now, 20) -- 1/3 per second down: still regrouping after 2 s
		expect(scatter(sim, g) > 0).toBe(true)
		run(sim, now, 12) -- regrouped within 3 s of the flee's end (02 §9.2)
		expect(scatter(sim, g)).toBe(0)
	end)

	it("scatters a school only for the first second of a flee", function()
		local sim = newSim()
		local g = PreySim.spawn(sim, SARDINE, 0, 0, -50, 0, 10) :: number
		PreySim.setThreatCount(sim, 1)
		local peak = 0
		run(sim, 0, 35, function()
			local x, y, z = pos(sim, g)
			PreySim.setThreat(sim, 0, x - 10, y, z, 2, PLAYER)
			peak = math.max(peak, scatter(sim, g))
		end)
		expect(peak > 0.9).toBe(true)
		expect(scatter(sim, g) < 0.5).toBe(true)
	end)

	it("ends a flee after the burst, then stays tired for 2 s even with the threat near", function()
		local sim = newSim()
		local g = PreySim.spawn(sim, KRILL, 0, 0, -50, 0, 16) :: number
		PreySim.setThreatCount(sim, 1)
		local chase = function()
			local x, y, z = pos(sim, g)
			PreySim.setThreat(sim, 0, x - 5, y, z, 1, PLAYER)
		end
		local now = run(sim, 0, 19, chase) -- krill burst 2 s
		expect(bit32.btest(flags(sim, g), PreySim.FLAG_FLEEING)).toBe(true)
		now = run(sim, now, 2, chase)
		expect(bit32.btest(flags(sim, g), PreySim.FLAG_FLEEING)).toBe(false)
		now = run(sim, now, 18, chase)
		expect(bit32.btest(flags(sim, g), PreySim.FLAG_FLEEING)).toBe(false)
		local vx, vz =
			buffer.readf32(sim.buffers.velX, g * 4), buffer.readf32(sim.buffers.velZ, g * 4)
		expect(math.sqrt(vx * vx + vz * vz) <= 5.6 + 1e-3).toBe(true) -- cruise speed while tired
		run(sim, now, 3, chase)
		expect(bit32.btest(flags(sim, g), PreySim.FLAG_FLEEING)).toBe(true)
	end)

	it(
		"keeps groups on the leash: never past 1.5 × the home radius, back inside afterwards",
		function()
			local sim = newSim()
			local groups = {}
			for i = 0, 7 do
				local angle = i / 8 * 2 * math.pi
				table.insert(
					groups,
					PreySim.spawn(sim, TUNA, 0, 50 * math.cos(angle), -50, 50 * math.sin(angle), 1) :: number
				)
			end
			PreySim.setThreatCount(sim, 8)
			local worst = 0
			local function measure()
				for _, g in groups do
					local x, y, z = pos(sim, g)
					worst = math.max(worst, math.sqrt(x * x + z * z))
					expect(y >= -50 - 30 - 1e-3 and y <= -50 + 30 + 1e-3).toBe(true)
				end
			end
			-- A threat just inside each tuna for 30 s, chasing it outward.
			local now = run(sim, 0, 300, function()
				for i, g in groups do
					local x, y, z = pos(sim, g)
					local d = math.max(math.sqrt(x * x + z * z), 1e-3)
					PreySim.setThreat(sim, i - 1, x - x / d * 20, y, z - z / d * 20, 6, PLAYER)
				end
				measure()
			end)
			expect(worst <= 90 + 1e-3).toBe(true)
			expect(worst > 60).toBe(true) -- the chase did push them out
			PreySim.setThreatCount(sim, 1)
			PreySim.setThreat(sim, 0, 0, -50, 0, -1, PLAYER) -- a player nearby, no threat
			run(sim, now, 100)
			for _, g in groups do
				local x, _, z = pos(sim, g)
				expect(math.sqrt(x * x + z * z) <= 62).toBe(true)
			end
		end
	)

	it("freezes stunned prey in place whatever its state, by tier", function()
		local sim = newSim()
		local krill = PreySim.spawn(sim, KRILL, 0, 5, -50, 0, 16) :: number
		local tuna = PreySim.spawn(sim, TUNA, 0, -5, -50, 0, 1) :: number
		PreySim.setThreatCount(sim, 1)
		PreySim.setThreat(sim, 0, 0, -50, 0, 6, PLAYER)
		local now = run(sim, 0, 3)
		expect(PreySim.stunNear(sim, 0, -50, 0, 30, 3, 1.5, now)).toBe(1)
		expect(bit32.btest(flags(sim, krill), PreySim.FLAG_STUNNED)).toBe(true)
		expect(bit32.btest(flags(sim, tuna), PreySim.FLAG_STUNNED)).toBe(false)
		local x, y, z = pos(sim, krill)
		now = run(sim, now, 14)
		local x2, y2, z2 = pos(sim, krill)
		expect(x2 == x and y2 == y and z2 == z).toBe(true)
		run(sim, now, 3)
		expect(bit32.btest(flags(sim, krill), PreySim.FLAG_STUNNED)).toBe(false)
	end)

	it("lures prey toward a Moonlit player within 40 studs instead of fleeing", function()
		local sim = newSim()
		local g = PreySim.spawn(sim, SARDINE, 0, 0, -50, 0, 10) :: number
		PreySim.setThreatCount(sim, 1)
		PreySim.setThreat(sim, 0, 30, -50, 0, 2, PLAYER + PreySim.THREAT_MOONLIT)
		run(sim, 0, 20)
		expect(bit32.btest(flags(sim, g), PreySim.FLAG_FLEEING)).toBe(false)
		local x = pos(sim, g)
		expect(x > 3).toBe(true)
		local vx = buffer.readf32(sim.buffers.velX, g * 4)
		expect(vx > 0 and vx <= 4 + 1e-3).toBe(true)
	end)

	it(
		"puts groups with no player within 700 studs to sleep and steps them once a second",
		function()
			local sim = newSim()
			local g = PreySim.spawn(sim, TUNA, 0, 0, -50, 0, 1) :: number
			PreySim.setThreatCount(sim, 1)
			PreySim.setThreat(sim, 0, 900, -50, 0, 6, PLAYER)
			local moves = 0
			local lastX, _, lastZ = pos(sim, g)
			run(sim, 0, 30, function()
				local x, _, z = pos(sim, g)
				if x ~= lastX or z ~= lastZ then
					moves += 1
				end
				lastX, lastZ = x, z
			end)
			expect(bit32.btest(flags(sim, g), PreySim.FLAG_DORMANT)).toBe(true)
			expect(moves >= 2 and moves <= 3).toBe(true)
			PreySim.setThreat(sim, 0, 600, -50, 0, 6, PLAYER)
			run(sim, 3, 1)
			expect(bit32.btest(flags(sim, g), PreySim.FLAG_DORMANT)).toBe(false)
		end
	)

	it("hops shrimp along the floor, at most 2 studs above it", function()
		local sim = newSim()
		PreySim.setFloor(sim, function(x: number, _z: number): number
			return -60 + x * 0.05
		end)
		local g = PreySim.spawn(sim, SHRIMP, 0, 0, -60, 0, 2) :: number
		PreySim.setThreatCount(sim, 1)
		PreySim.setThreat(sim, 0, 0, -50, 0, -1, PLAYER)
		local highest = 0
		run(sim, 0, 40, function()
			local x, y = pos(sim, g)
			local above = y - (-60 + x * 0.05)
			expect(above >= -0.1 and above <= 2 + 0.1).toBe(true)
			highest = math.max(highest, above)
		end)
		expect(highest > 1).toBe(true)
	end)

	it("rebuilds member positions at past times from the history ring", function()
		local sim = newSim()
		local g = PreySim.spawn(sim, KRILL, 0, 0, -50, 0, 16) :: number
		PreySim.setThreatCount(sim, 1)
		local times, xs, ys, zs, hs, ss = {}, {}, {}, {}, {}, {}
		local now = 0
		for tick = 1, 40 do
			now += DT
			local x, y, z = pos(sim, g)
			PreySim.setThreat(sim, 0, x - 6, y, z + (tick % 3), 1, PLAYER)
			PreySim.step(sim, now, DT)
			times[tick] = now
			xs[tick], ys[tick], zs[tick] = pos(sim, g)
			hs[tick] = PreySim.heading(sim, g)
			ss[tick] = scatter(sim, g)
		end
		-- The last eight ticks are in the ring: member 0 is the group point, others follow Formation.
		local quant = 1 / 32 + 1e-4
		for tick = 33, 40 do
			local x, y, z = PreySim.memberPosAt(sim, g, 0, times[tick])
			expect(math.abs(x - xs[tick]) <= quant and math.abs(y - ys[tick]) <= quant).toBe(true)
			expect(math.abs(z - zs[tick]) <= quant).toBe(true)
			local mx, my, mz = PreySim.memberPosAt(sim, g, 9, times[tick])
			local ex, ey, ez = Formation.memberPos(
				KRILL,
				buffer.readu16(sim.buffers.seed, g * 2),
				9,
				xs[tick],
				ys[tick],
				zs[tick],
				hs[tick],
				ss[tick]
			)
			local err = math.sqrt((mx - ex) ^ 2 + (my - ey) ^ 2 + (mz - ez) ^ 2)
			expect(err < 0.25).toBe(true) -- quantised position, scatter and heading
		end
		-- Halfway between two samples it interpolates.
		local mid = (times[38] + times[39]) / 2
		local x = PreySim.memberPosAt(sim, g, 0, mid)
		expect(math.abs(x - (xs[38] + xs[39]) / 2) <= quant).toBe(true)
		-- Older than the ring: the oldest sample.
		local ox = PreySim.memberPosAt(sim, g, 0, times[10])
		expect(math.abs(ox - xs[33]) <= quant).toBe(true)
	end)

	it("is deterministic given a seed and the same inputs", function()
		local function play(seed: number): PreySim.Sim
			local sim = PreySim.new(seed)
			local rng = Rng.new(55)
			for h = 0, 7 do
				PreySim.setHome(
					sim,
					h,
					Rng.range(rng, -500, 500),
					-60,
					Rng.range(rng, -500, 500),
					70,
					20
				)
			end
			for _ = 1, 120 do
				local kinds = Formation.kinds()
				local kind = kinds[Rng.int(rng, 1, #kinds)]
				local def = Formation.defOf(kind) :: any
				local h = Rng.int(rng, 0, 7)
				local o = h * 20
				PreySim.spawn(
					sim,
					kind,
					h,
					buffer.readf32(sim.homes, o),
					-60,
					buffer.readf32(sim.homes, o + 8),
					Rng.int(rng, def.groupMin, def.groupMax)
				)
			end
			PreySim.setThreatCount(sim, 4)
			run(sim, 0, 200, function(now: number)
				for i = 0, 3 do
					local o = i * 20
					PreySim.setThreat(
						sim,
						i,
						buffer.readf32(sim.homes, o) + 30 * math.sin(now + i),
						-60,
						buffer.readf32(sim.homes, o + 8) + 30 * math.cos(now),
						4,
						PLAYER
					)
				end
			end)
			return sim
		end
		local a, b, c = play(9), play(9), play(10)
		local same, differs = true, false
		for name, buf in a.buffers :: any do
			if buffer.tostring(buf) ~= buffer.tostring((b.buffers :: any)[name]) then
				same = false
			end
			if buffer.tostring(buf) ~= buffer.tostring((c.buffers :: any)[name]) then
				differs = true
			end
		end
		expect(same).toBe(true)
		expect(differs).toBe(true)
	end)

	it(
		"owns a group: its own home at its spawn point, owner cleared when the slot is reused",
		function()
			local sim = newSim()
			-- Far outside home 0 (the Nursery path is in no spawn volume).
			local g = PreySim.spawn(sim, KRILL, 0, 400, -20, 300, 6) :: number
			PreySim.own(sim, g, 3, 3, 3)
			expect(PreySim.ownerOf(sim, g)).toBe(3)
			local home = buffer.readu16(sim.buffers.home, g * 2)
			expect(home).toBe(PreySim.OWNED_HOME + g)
			expect(buffer.readf32(sim.homes, home * 20)).toBe(400)
			expect(buffer.readf32(sim.homes, home * 20 + 12)).toBe(3)
			PreySim.remove(sim, g)
			expect(PreySim.ownerOf(sim, g)).toBe(0)
			local again = PreySim.spawn(sim, KRILL, 0, 0, -50, 0, 6, nil, g) :: number
			expect(again).toBe(g)
			expect(PreySim.ownerOf(sim, again)).toBe(0)
		end
	)

	it(
		"lets an owned group flee only from its owner's creature, and keeps it on its leash",
		function()
			local sim = newSim()
			local g = PreySim.spawn(sim, KRILL, 0, 400, -20, 300, 6) :: number
			PreySim.own(sim, g, 3, 3, 3)
			local shared = PreySim.spawn(sim, KRILL, 0, 420, -20, 300, 6) :: number
			-- Slot 5 sits on both groups: only the shared one flees.
			local now = run(sim, 0, 3, function()
				PreySim.setThreat(sim, 0, 405, -20, 300, 3, PLAYER, 5)
				PreySim.setThreat(sim, 1, 415, -20, 300, 3, PLAYER, 5)
				PreySim.setThreatCount(sim, 2)
			end)
			expect(bit32.btest(flags(sim, g), PreySim.FLAG_FLEEING)).toBe(false)
			expect(bit32.btest(flags(sim, shared), PreySim.FLAG_FLEEING)).toBe(true)
			-- Its owner, slot 3: it flees, then wanders, never past 1.5 × its 3-stud home.
			local fled = false
			local worst = 0
			run(sim, now, 200, function(t)
				PreySim.setThreat(sim, 0, 400 + 4 * math.sin(t), -20, 302, 3, PLAYER, 3)
				PreySim.setThreatCount(sim, 1)
				fled = fled or bit32.btest(flags(sim, g), PreySim.FLAG_FLEEING)
				local x, y, z = pos(sim, g)
				worst = math.max(worst, math.sqrt((x - 400) ^ 2 + (z - 300) ^ 2), math.abs(y + 20))
			end)
			expect(fled).toBe(true)
			expect(worst > 0.5).toBe(true)
			expect(worst <= 4.5 + 1e-3).toBe(true)
		end
	)
end)
