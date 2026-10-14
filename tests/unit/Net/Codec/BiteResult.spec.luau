--!strict
local BiteResult = require("../../../../src/shared/Net/Codec/BiteResult")
local Index = require("../../../../src/shared/Data/Index")
local Remotes = require("../../../../src/shared/Net/Remotes")
local Rng = require("../../../../src/shared/Util/Rng")
local TestKit = require("../../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- The value an f32 stores for `x`.
local function f32(x: number): number
	local b = buffer.create(4)
	buffer.writef32(b, 0, x)
	return buffer.readf32(b, 0)
end

describe("Codec/BiteResult (09 §8.7)", function()
	local maxTier = #Index.Tiers.list

	it("round-trips random results in 9 bytes, mass as an f32", function()
		local rng = Rng.new(8707)
		for _ = 1, 500 do
			local seq, mask = Rng.int(rng, 0, 65535), Rng.int(rng, 0, 255)
			local reason, tier = Rng.int(rng, 0, 8), Rng.int(rng, 1, maxTier)
			local mass = Rng.range(rng, 0, 1e6)
			local b = BiteResult.encode(seq, mask, reason, mass, tier)
			expect(buffer.len(b)).toBe(BiteResult.SIZE)
			expect(BiteResult.valid(b)).toBe(true)
			expect({ BiteResult.decode(b) }).toEqual({ seq, mask, reason, f32(mass), tier })
			expect(math.abs(f32(mass) - mass) <= mass * 2 ^ -23).toBe(true)
		end
	end)

	it("round-trips the edge values", function()
		local b = BiteResult.encode(65535, 255, BiteResult.REASON_PROTECTED, 0, maxTier)
		expect({ BiteResult.decode(b) }).toEqual({ 65535, 255, 8, 0, maxTier })
		expect(BiteResult.valid(b)).toBe(true)
		local seq = BiteResult.decode(BiteResult.encode(65536 + 7, 0, 0, 1.5, 1))
		expect(seq).toBe(7)
	end)

	it("matches the remote table and rejects bad sizes and out-of-range fields", function()
		expect(Remotes.byName.BiteResult.minBytes).toBe(9)
		expect(Remotes.byName.BiteResult.maxBytes).toBe(9)
		for _, length in { 0, 8, 10 } do
			expect(BiteResult.accepts(length)).toBe(false)
			expect(BiteResult.valid(buffer.create(length))).toBe(false)
		end
		expect(BiteResult.valid(BiteResult.encode(0, 0, 9, 1, 1))).toBe(false)
		expect(BiteResult.valid(BiteResult.encode(0, 0, 0, -1, 1))).toBe(false)
		expect(BiteResult.valid(BiteResult.encode(0, 0, 0, 0 / 0, 1))).toBe(false)
		expect(BiteResult.valid(BiteResult.encode(0, 0, 0, math.huge, 1))).toBe(false)
		expect(BiteResult.valid(BiteResult.encode(0, 0, 0, 1, 0))).toBe(false)
		expect(BiteResult.valid(BiteResult.encode(0, 0, 0, 1, maxTier + 1))).toBe(false)
	end)
end)
