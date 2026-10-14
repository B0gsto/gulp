--!strict
local PreyEvent = require("../../../../src/shared/Net/Codec/PreyEvent")
local Remotes = require("../../../../src/shared/Net/Remotes")
local Rng = require("../../../../src/shared/Util/Rng")
local TestKit = require("../../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Codec/PreyEvent (09 §8.7)", function()
	it("round-trips random batches of records", function()
		local rng = Rng.new(8705)
		for _ = 1, 200 do
			local n = Rng.int(rng, 1, 255)
			local records = {}
			local b = PreyEvent.create(n)
			for k = 0, n - 1 do
				local r = {
					Rng.int(rng, 1, 3),
					Rng.int(rng, 0, 511),
					Rng.int(rng, 0, 255),
					Rng.int(rng, 0, 23),
					Rng.int(rng, 0, 24),
				}
				records[k + 1] = r
				PreyEvent.write(b, k, r[1], r[2], r[3], r[4], r[5])
			end
			expect(buffer.len(b)).toBe(1 + 6 * n)
			expect(PreyEvent.valid(b)).toBe(true)
			expect(PreyEvent.count(b)).toBe(n)
			for k = 0, n - 1 do
				expect({ PreyEvent.read(b, k) }).toEqual(records[k + 1])
			end
		end
	end)

	it("round-trips the edge values and spans 7 to 1531 bytes", function()
		local b = PreyEvent.create(2)
		PreyEvent.write(b, 0, PreyEvent.OP_EATEN, 0, 0, 0, 0)
		PreyEvent.write(b, 1, PreyEvent.OP_RESTORED, 511, 255, 23, 24)
		expect(PreyEvent.valid(b)).toBe(true)
		expect({ PreyEvent.read(b, 0) }).toEqual({ 1, 0, 0, 0, 0 })
		expect({ PreyEvent.read(b, 1) }).toEqual({ 3, 511, 255, 23, 24 })
		expect(Remotes.byName.PreyEvent.minBytes).toBe(7)
		expect(PreyEvent.accepts(7)).toBe(true)
		expect(buffer.len(PreyEvent.create(1))).toBe(7)
		expect(buffer.len(PreyEvent.create(255))).toBe(PreyEvent.MAX_BYTES)
		expect(function()
			PreyEvent.create(0)
		end).toThrow()
		expect(function()
			PreyEvent.create(256)
		end).toThrow()
	end)

	it("rejects bad lengths and a count that does not match, without throwing", function()
		for _, length in { 0, 1, 6, 8, 12, 14, 1 + 6 * 256 } do
			expect(PreyEvent.accepts(length)).toBe(false)
			expect(PreyEvent.valid(buffer.create(length))).toBe(false)
		end
		local b = PreyEvent.create(3)
		for k = 0, 2 do
			PreyEvent.write(b, k, 2, k, 0, 0, 0)
		end
		expect(PreyEvent.valid(b)).toBe(true)
		buffer.writeu8(b, 0, 2) -- says two records, carries three
		expect(PreyEvent.valid(b)).toBe(false)
		local short = buffer.create(13)
		buffer.copy(short, 0, b, 0, 13)
		buffer.writeu8(short, 0, 3) -- says three, carries two
		expect(PreyEvent.valid(short)).toBe(false)
	end)

	it("rejects out-of-range fields", function()
		local cases = {
			{ 0, 0, 0, 0, 0 },
			{ 4, 0, 0, 0, 0 },
			{ 1, 512, 0, 0, 0 },
			{ 1, 0, 0, 24, 0 },
			{ 1, 0, 0, 0, 25 },
		}
		for _, r in cases do
			local b = PreyEvent.create(1)
			PreyEvent.write(b, 0, r[1], r[2], r[3], r[4], r[5])
			expect(PreyEvent.valid(b)).toBe(false)
		end
	end)
end)
