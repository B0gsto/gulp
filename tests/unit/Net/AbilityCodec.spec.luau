--!strict
local Ability = require("../../../src/shared/Net/Codec/Ability")
local Remotes = require("../../../src/shared/Net/Remotes")
local TestKit = require("../../../src/shared/Util/TestKit")
local Validate = require("../../../src/shared/Net/Validate")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Codec/Ability (09 §5.3)", function()
	it("round-trips op, seq and timeMs in 6 bytes", function()
		local b = Ability.encode(Ability.OP_DASH, 7, 123456789)
		expect(buffer.len(b)).toBe(6)
		local op, seq, timeMs = Ability.decode(b)
		expect(op).toBe(1)
		expect(seq).toBe(7)
		expect(timeMs).toBe(123456789)
	end)

	it("wraps seq at 256 and floors and clamps timeMs to a u32", function()
		local _, seq, timeMs = Ability.decode(Ability.encode(Ability.OP_PRESS, 257, 99.9))
		expect(seq).toBe(1)
		expect(timeMs).toBe(99)
		_, _, timeMs = Ability.decode(Ability.encode(Ability.OP_RELEASE, 0, -5))
		expect(timeMs).toBe(0)
		_, _, timeMs = Ability.decode(Ability.encode(Ability.OP_RELEASE, 0, 2 ^ 40))
		expect(timeMs).toBe(4294967295)
		_, _, timeMs = Ability.decode(Ability.encode(Ability.OP_RELEASE, 0, 0 / 0))
		expect(timeMs).toBe(0)
	end)

	it("matches the remote table and rejects bad sizes and unknown ops", function()
		local def = Remotes.byName.Ability
		expect(def.minBytes).toBe(Ability.SIZE)
		expect(def.maxBytes).toBe(Ability.SIZE)
		local spec = Validate.buffer(Ability.SIZE, Ability.SIZE, Ability.accepts, Ability.valid)
		expect(Validate.value(spec, Ability.encode(1, 0, 0))).toBe(true)
		local ok, reason = Validate.value(spec, buffer.create(5))
		expect(ok).toBe(false)
		expect(reason).toBe("size")
		for _, op in { 0, 4, 255 } do
			ok, reason = Validate.value(spec, Ability.encode(op, 0, 0))
			expect(ok).toBe(false)
			expect(reason).toBe("range")
		end
		expect(Ability.valid(buffer.create(7))).toBe(false)
	end)
end)
