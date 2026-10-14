--!strict
local Bite = require("../../../../src/shared/Net/Codec/Bite")
local Remotes = require("../../../../src/shared/Net/Remotes")
local Rng = require("../../../../src/shared/Util/Rng")
local TestKit = require("../../../../src/shared/Util/TestKit")
local Validate = require("../../../../src/shared/Net/Validate")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Codec/Bite (09 §8.7, §8.9)", function()
	it("round-trips random prey bites of 1 to 8 targets", function()
		local rng = Rng.new(8706)
		for _ = 1, 300 do
			local n = Rng.int(rng, 1, 8)
			local seq, timeMs = Rng.int(rng, 0, 65535), Rng.nextU32(rng)
			local b = Bite.encodePrey(seq, timeMs, n)
			local targets = {}
			for k = 0, n - 1 do
				local t = { Rng.int(rng, 0, 639), Rng.int(rng, 0, 23), Rng.int(rng, 0, 255) }
				targets[k + 1] = t
				Bite.writePrey(b, k, t[1], t[2], t[3])
			end
			expect(buffer.len(b)).toBe(8 + 4 * n)
			expect(Bite.valid(b)).toBe(true)
			expect({ Bite.header(b) }).toEqual({ Bite.OP_PREY, n, seq, timeMs })
			for k = 0, n - 1 do
				expect({ Bite.readPrey(b, k) }).toEqual(targets[k + 1])
			end
		end
	end)

	it(
		"round-trips player and predator bites in 8 bytes, wrapping seq and clamping time",
		function()
			local b = Bite.encodePlayer(65537, 99.9, 24)
			expect(buffer.len(b)).toBe(8)
			expect(Bite.valid(b)).toBe(true)
			expect({ Bite.header(b) }).toEqual({ Bite.OP_PLAYER, 24, 1, 99 })
			b = Bite.encodePredator(0, 2 ^ 40, 0)
			expect(Bite.valid(b)).toBe(true)
			expect({ Bite.header(b) }).toEqual({ Bite.OP_PREDATOR, 0, 0, 4294967295 })
			expect({ Bite.header(Bite.encodePlayer(0, -3, 1)) }).toEqual({ 2, 1, 0, 0 })
			expect({ Bite.header(Bite.encodePlayer(0, 0 / 0, 1)) }).toEqual({ 2, 1, 0, 0 })
			expect(function()
				Bite.encodePrey(0, 0, 9)
			end).toThrow()
		end
	)

	it("matches the remote table and accepts only 8 or 12 to 40 bytes in steps of 4", function()
		local def = Remotes.byName.Bite
		expect(def.minBytes).toBe(Bite.MIN_BYTES)
		expect(def.maxBytes).toBe(Bite.MAX_BYTES)
		for length = 0, 48 do
			local expected = length == 8 or (length >= 12 and length <= 40 and length % 4 == 0)
			expect(Bite.accepts(length)).toBe(expected)
		end
		local spec = Validate.buffer(Bite.MIN_BYTES, Bite.MAX_BYTES, Bite.accepts, Bite.valid)
		expect(Validate.value(spec, Bite.encodePlayer(0, 0, 3))).toBe(true)
		local ok, reason = Validate.value(spec, buffer.create(41))
		expect(ok).toBe(false)
		expect(reason).toBe("size")
	end)

	it("rejects truncated, padded and malformed bites without throwing", function()
		local b = Bite.encodePrey(5, 6, 3)
		for k = 0, 2 do
			Bite.writePrey(b, k, k, k, k)
		end
		for cut = 0, buffer.len(b) - 1 do
			local short = buffer.create(cut)
			buffer.copy(short, 0, b, 0, cut)
			expect(Bite.valid(short)).toBe(false)
		end
		local long = buffer.create(24)
		buffer.copy(long, 0, b, 0, 20)
		expect(Bite.valid(long)).toBe(false) -- count 3 but 4 targets of room
		local function edited(offset: number, value: number, source: buffer?): buffer
			local copy = buffer.create(buffer.len(source or b))
			buffer.copy(copy, 0, source or b)
			buffer.writeu8(copy, offset, value)
			return copy
		end
		expect(Bite.valid(edited(0, 0))).toBe(false) -- op 0
		expect(Bite.valid(edited(0, 4))).toBe(false) -- op 4
		expect(Bite.valid(edited(1, 0))).toBe(false) -- count 0
		expect(Bite.valid(edited(1, 9))).toBe(false) -- count 9
		expect(Bite.valid(edited(9, 3))).toBe(false) -- groupId 768 or more (high byte of target 0)
		expect(Bite.valid(edited(10, 24))).toBe(false) -- member 24
		expect(Bite.valid(edited(0, 2))).toBe(false) -- a player bite of 20 bytes
		local player = Bite.encodePlayer(0, 0, 1)
		expect(Bite.valid(edited(1, 0, player))).toBe(false) -- slot 0
		expect(Bite.valid(edited(1, 25, player))).toBe(false) -- slot 25
		expect(Bite.valid(edited(0, 1, player))).toBe(false) -- a prey bite with no targets
	end)
end)
