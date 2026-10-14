--!strict
local Quantize = require("../../../src/shared/Sim/Quantize")
local Rng = require("../../../src/shared/Util/Rng")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local STEP = 1 / 32 -- section 16.1: the round trip is off by at most 1/32 stud

describe("Sim/Quantize (09 §8.7)", function()
	it("round-trips positions inside their ranges within 1/32 stud", function()
		local rng = Rng.new(8701)
		for _ = 1, 5000 do
			local x = Rng.range(rng, -1024, 1024)
			local y = Rng.range(rng, -640, 96)
			local z = Rng.range(rng, -1024, 1024)
			expect(math.abs(Quantize.fromX(Quantize.x(x)) - x) <= STEP).toBe(true)
			expect(math.abs(Quantize.fromY(Quantize.y(y)) - y) <= STEP).toBe(true)
			expect(math.abs(Quantize.fromZ(Quantize.z(z)) - z) <= STEP).toBe(true)
		end
	end)

	it("maps the range edges to 0 and the maxima, which fit a u16", function()
		expect(Quantize.x(-1024)).toBe(0)
		expect(Quantize.x(1024)).toBe(Quantize.QX_MAX)
		expect(Quantize.y(-640)).toBe(0)
		expect(Quantize.y(96)).toBe(Quantize.QY_MAX)
		expect(Quantize.z(-1024)).toBe(0)
		expect(Quantize.z(1024)).toBe(Quantize.QZ_MAX)
		expect(Quantize.QX_MAX <= 65535 and Quantize.QY_MAX <= 65535).toBe(true)
		expect(Quantize.fromX(Quantize.x(0))).toBe(0)
		expect(Quantize.fromY(Quantize.y(0))).toBe(0)
		expect(Quantize.x(1 / 32 - 1024)).toBe(1) -- halves round away from zero
	end)

	it("clamps out-of-range and NaN positions to the range", function()
		expect(Quantize.x(-5000)).toBe(0)
		expect(Quantize.x(5000)).toBe(Quantize.QX_MAX)
		expect(Quantize.y(-700)).toBe(0)
		expect(Quantize.y(200)).toBe(Quantize.QY_MAX)
		expect(Quantize.z(math.huge)).toBe(Quantize.QZ_MAX)
		expect(Quantize.z(-math.huge)).toBe(0)
		expect(Quantize.x(0 / 0)).toBe(0)
	end)

	it("quantises velocity to 0.5 studs/s, clamped to ±127", function()
		local rng = Rng.new(8702)
		for _ = 1, 2000 do
			local v = Rng.range(rng, -63.5, 63.5)
			local q = Quantize.vel(v)
			expect(q >= -127 and q <= 127).toBe(true)
			expect(math.abs(Quantize.fromVel(q) - v) <= 0.25).toBe(true)
		end
		expect(Quantize.vel(63.5)).toBe(127)
		expect(Quantize.vel(1000)).toBe(127)
		expect(Quantize.vel(-1000)).toBe(-127)
		expect(Quantize.vel(0 / 0)).toBe(0)
		expect(Quantize.fromVel(-127)).toBe(-63.5)
	end)

	it("quantises scatter 0 to 1 into 0 to 255", function()
		expect(Quantize.scatter(0)).toBe(0)
		expect(Quantize.scatter(1)).toBe(255)
		expect(Quantize.scatter(2)).toBe(255)
		expect(Quantize.scatter(-1)).toBe(0)
		expect(Quantize.scatter(0 / 0)).toBe(0)
		for q = 0, 255 do
			expect(Quantize.scatter(Quantize.fromScatter(q))).toBe(q)
		end
	end)

	it("counts timeMs in whole milliseconds since the epoch, clamped to a u32", function()
		local epoch = 1_700_000_000.25
		expect(Quantize.timeMs(epoch + 12.3456, epoch)).toBe(12345)
		expect(Quantize.timeMs(epoch - 1, epoch)).toBe(0)
		expect(Quantize.timeMs(epoch + 1e7, epoch)).toBe(Quantize.U32_MAX)
		expect(Quantize.timeMs(0 / 0, epoch)).toBe(0)
		expect(Quantize.fromTimeMs(12345, epoch)).toBeCloseTo(epoch + 12.345, 1e-6)
	end)
end)
