--!strict
local Rng = require("../../../src/shared/Util/Rng")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function firstFive(seed: number): { number }
	local rng = Rng.new(seed)
	local values = {}
	for index = 1, 5 do
		values[index] = Rng.nextU32(rng)
	end
	return values
end

describe("Rng", function()
	-- Reference values from an independent implementation of splitmix32 seeding and
	-- xoshiro128++. If one of these changes, every simulation result changes with it.
	it("new and nextU32 give the pinned sequence for a seed", function()
		expect(Rng.new(0)).toEqual({
			a = 2462723854,
			b = 1020716019,
			c = 454327756,
			d = 1275600319,
		})
		expect(firstFive(0)).toEqual({ 4226848253, 3853465007, 1657604656, 2135928087, 1643513283 })
		expect(firstFive(1)).toEqual({ 3187778163, 3899520863, 270678034, 2950105546, 3415064141 })
		expect(firstFive(20261013)).toEqual({
			3754037393,
			1192233424,
			2804659876,
			3086814127,
			3456306537,
		})
		expect(firstFive(-7)).toEqual({ 1408726667, 1089590687, 3637118302, 3733922418, 248704711 })
	end)

	it("the same seed gives the same sequence, a different seed another", function()
		expect(firstFive(42)).toEqual(firstFive(42))
		expect(firstFive(42)[1] ~= firstFive(43)[1]).toBe(true)
	end)

	it("new floors the seed and wraps it to 32 bits", function()
		expect(firstFive(7.9)).toEqual(firstFive(7))
		expect(firstFive(7 + 2 ^ 32)).toEqual(firstFive(7))
	end)

	it("new refuses a seed that is not finite", function()
		for _, seed in { 0 / 0, math.huge, -math.huge } do
			expect(function()
				Rng.new(seed)
			end).toThrow("finite")
		end
	end)

	it("two generators do not share state", function()
		local a, b = Rng.new(5), Rng.new(5)
		Rng.nextU32(a)
		Rng.nextU32(a)
		expect(Rng.nextU32(b)).toBe(firstFive(5)[1])
	end)

	it("nextU32 stays a whole number from 0 to 2^32 - 1", function()
		local rng = Rng.new(99)
		for _ = 1, 20000 do
			local value = Rng.nextU32(rng)
			if value % 1 ~= 0 or value < 0 or value > 4294967295 then
				error(`out of range: {value}`)
			end
		end
	end)

	it("next stays in [0, 1) and averages near one half", function()
		local rng = Rng.new(2026)
		local sum = 0
		for _ = 1, 20000 do
			local value = Rng.next(rng)
			if value < 0 or value >= 1 then
				error(`out of range: {value}`)
			end
			sum += value
		end
		expect(sum / 20000).toBeCloseTo(0.5, 0.01)
	end)

	it("next is nextU32 scaled by 2^32", function()
		expect(Rng.next(Rng.new(0))).toBe(4226848253 / 2 ^ 32)
	end)

	it("range stays in [min, max)", function()
		local rng = Rng.new(3)
		for _ = 1, 5000 do
			local value = Rng.range(rng, -2.5, 4)
			if value < -2.5 or value >= 4 then
				error(`out of range: {value}`)
			end
		end
		expect(Rng.range(rng, 6, 6)).toBe(6)
	end)

	it("int covers both ends and every value between about evenly", function()
		local rng = Rng.new(11)
		local counts = { 0, 0, 0, 0, 0, 0 }
		for _ = 1, 12000 do
			local value = Rng.int(rng, 1, 6)
			counts[value] += 1
		end
		for face = 1, 6 do
			expect(counts[face]).toBeCloseTo(2000, 200)
		end
		expect(Rng.int(rng, 4, 4)).toBe(4)
		local negative = Rng.int(rng, -3, -1)
		expect(negative >= -3 and negative <= -1 and negative % 1 == 0).toBe(true)
	end)

	it("int refuses a reversed range and fractions", function()
		local rng = Rng.new(1)
		expect(function()
			Rng.int(rng, 5, 1)
		end).toThrow("min <= max")
		expect(function()
			Rng.int(rng, 1.5, 3)
		end).toThrow("whole numbers")
	end)

	it("chance is never true at 0, always at 1, and near the probability between", function()
		local rng = Rng.new(8)
		local hits = 0
		for _ = 1, 10000 do
			expect(Rng.chance(rng, 0)).toBe(false)
			expect(Rng.chance(rng, 1)).toBe(true)
			if Rng.chance(rng, 0.25) then
				hits += 1
			end
		end
		expect(hits).toBeCloseTo(2500, 200)
	end)

	it("pick returns a member of the list, and nil for an empty list", function()
		local rng = Rng.new(21)
		local seen: { [string]: boolean } = {}
		for _ = 1, 200 do
			local value = Rng.pick(rng, { "krill", "sardine", "shrimp" })
			seen[value :: string] = true
		end
		expect(seen).toEqual({ krill = true, sardine = true, shrimp = true })
		expect(Rng.pick(rng, {})).toBe(nil)
		expect(Rng.pick(rng, { "only" })).toBe("only")
	end)

	it("shuffle keeps every value, works in place and is repeatable", function()
		local list = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
		local returned = Rng.shuffle(Rng.new(4), list)
		expect(returned).toBe(list)
		local again = Rng.shuffle(Rng.new(4), { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 })
		expect(again).toEqual(list)
		local sorted = table.clone(list)
		table.sort(sorted)
		expect(sorted).toEqual({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 })
		expect(table.concat(list, ",") ~= "1,2,3,4,5,6,7,8,9,10").toBe(true)
		expect(Rng.shuffle(Rng.new(4), {})).toEqual({})
	end)
end)
