--!strict
local Formation = require("../../../src/shared/Sim/Formation")
local Index = require("../../../src/shared/Data/Index")
local Rng = require("../../../src/shared/Util/Rng")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Sim/Formation (09 §8.1)", function()
	it("maps every prey and trait prey to its own kind code and back", function()
		for _, def in Index.Prey.list do
			expect(Formation.kindOf(def.id)).toBe(def.wire)
			expect(Formation.defOf(def.wire)).toBe(def)
		end
		for _, def in Index.TraitPrey.list do
			local kind = Formation.kindOf(def.id)
			expect(kind).toBe(Formation.TRAIT_BASE + def.wire)
			expect(Formation.defOf(kind :: number)).toBe(def)
		end
		expect(Formation.defOf(0)).toBe(nil)
		expect(Formation.kindOf("no_such_prey")).toBe(nil)
	end)

	it("is deterministic in (kind, seed, member) and varies with the seed", function()
		local rng = Rng.new(8101)
		local kinds = Formation.kinds()
		local differs = 0
		for _ = 1, 500 do
			local kind = kinds[Rng.int(rng, 1, #kinds)]
			local seed = Rng.int(rng, 0, 65535)
			local member = Rng.int(rng, 1, 23)
			local ax, ay, az = Formation.offset(kind, seed, member)
			local bx, by, bz = Formation.offset(kind, seed, member)
			expect(ax == bx and ay == by and az == bz).toBe(true)
			local cx, _, cz = Formation.offset(kind, (seed + 1) % 65536, member)
			if cx ~= ax or cz ~= az then
				differs += 1
			end
		end
		expect(differs >= 495).toBe(true)
	end)

	it(
		"pins one offset, so a change to the hash (which moves every member) is deliberate",
		function()
			-- Server and client must agree; this value is the contract (krill, seed 12345, member 7).
			local x, y, z = Formation.offset(2, 12345, 7)
			expect(x).toBeCloseTo(2.885810095534, 1e-9)
			expect(y).toBeCloseTo(1.098184131832, 1e-9)
			expect(z).toBeCloseTo(2.875793014140, 1e-9)
		end
	)

	it("puts member 0 on the group point and every member inside the formation radius", function()
		local rng = Rng.new(8102)
		for _, kind in Formation.kinds() do
			local radius = Formation.radius(kind)
			expect(radius > 0).toBe(true)
			for _ = 1, 40 do
				local seed = Rng.int(rng, 0, 65535)
				local x0, y0, z0 = Formation.offset(kind, seed, 0)
				expect(x0 == 0 and y0 == 0 and z0 == 0).toBe(true)
				for member = 1, 23 do
					local x, y, z = Formation.offset(kind, seed, member)
					local flat = y / Formation.FLATTEN
					expect(math.sqrt(x * x + flat * flat + z * z) <= radius + 1e-9).toBe(true)
				end
			end
		end
	end)

	it("rotates by heading and spreads by scatter × scatterGain", function()
		local kind = Formation.kindOf("krill") :: number
		local ox, oy, oz = Formation.offset(kind, 99, 5)
		local x, y, z = Formation.memberPos(kind, 99, 5, 10, -20, 30, 0, 0)
		expect(x).toBeCloseTo(10 + ox, 1e-9)
		expect(y).toBeCloseTo(-20 + oy, 1e-9)
		expect(z).toBeCloseTo(30 + oz, 1e-9)
		-- Heading π/2 faces +X: local +Z becomes world +X.
		local rx, _, rz = Formation.memberPos(kind, 99, 5, 0, 0, 0, math.pi / 2, 0)
		expect(rx).toBeCloseTo(oz, 1e-9)
		expect(rz).toBeCloseTo(-ox, 1e-9)
		-- Full scatter doubles the offset for a gain of 1; a gain of 0 ignores scatter.
		local gain = Formation.scatterGain(kind)
		local sx, sy, sz = Formation.memberPos(kind, 99, 5, 0, 0, 0, 0, 1)
		expect(sx).toBeCloseTo(ox * (1 + gain), 1e-9)
		expect(sy).toBeCloseTo(oy * (1 + gain), 1e-9)
		expect(sz).toBeCloseTo(oz * (1 + gain), 1e-9)
		local darter = Formation.kindOf("darter") :: number
		local dx = Formation.offset(darter, 99, 1)
		expect((Formation.memberPos(darter, 99, 1, 0, 0, 0, 0, 1))).toBeCloseTo(dx, 1e-9)
	end)

	it("keeps the cosmetic wobble within wobble[kind], which is at most 1.5 studs", function()
		local rng = Rng.new(8103)
		for _, kind in Formation.kinds() do
			local cap = Formation.wobbleCap(kind)
			expect(cap <= Formation.WOBBLE_CAP).toBe(true)
			for _ = 1, 60 do
				local x, y, z = Formation.wobble(
					kind,
					Rng.int(rng, 0, 65535),
					Rng.int(rng, 0, 23),
					Rng.range(rng, 0, 1e4)
				)
				expect(math.sqrt(x * x + y * y + z * z) <= cap + 1e-9).toBe(true)
			end
		end
	end)
end)
