--!strict
local Bite = require("../../../src/shared/Net/Codec/Bite")
local BiteClaims = require("../../../src/shared/Logic/BiteClaims")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("BiteClaims (09 §8.9, 02 §4.3)", function()
	it("hides each member it claims and packs one valid Bite payload per frame", function()
		local c = BiteClaims.new(0)
		expect(BiteClaims.add(c, 12, 3, 7, 0)).toBe(true)
		expect(BiteClaims.add(c, 12, 3, 7, 0)).toBe(false) -- already hidden
		expect(BiteClaims.add(c, 40, 0, 1, 0)).toBe(true)
		expect(BiteClaims.isHidden(c, 12, 3, 7)).toBe(true)
		expect(BiteClaims.isHidden(c, 12, 3, 8)).toBe(false) -- another gen
		local b, seq = BiteClaims.flush(c, 123456, 0)
		expect(seq).toBe(0)
		assert(b, "a payload")
		expect(Bite.valid(b)).toBe(true)
		local op, count, s, t = Bite.header(b)
		expect(op).toBe(Bite.OP_PREY)
		expect(count).toBe(2)
		expect(s).toBe(0)
		expect(t).toBe(123456)
		local g, i, gen = Bite.readPrey(b, 1)
		expect(g).toBe(40)
		expect(i).toBe(0)
		expect(gen).toBe(1)
		expect(BiteClaims.pendingCount(c)).toBe(1)
		expect((BiteClaims.flush(c, 0, 0))).toBe(nil)
	end)

	it("holds at most 8 targets a claim and keeps to the Bite bucket (12/s, 20)", function()
		local c = BiteClaims.new(0)
		local n = 0
		for m = 0, 9 do
			if BiteClaims.add(c, 1, m, 1, 0) then
				n += 1
			end
		end
		expect(n).toBe(8)
		BiteClaims.flush(c, 0, 0)
		n = 0
		for m = 0, 23 do
			if BiteClaims.add(c, 2, m % 8, m // 8, 0) then
				n += 1
			end
			if m % 8 == 7 then
				BiteClaims.flush(c, 0, 0)
			end
		end
		expect(n).toBe(12) -- 20 tokens, 8 used
		expect(BiteClaims.add(c, 3, 0, 1, 0)).toBe(false)
		expect(BiteClaims.add(c, 3, 0, 1, 0.1)).toBe(true) -- 1.2 tokens back
		expect(BiteClaims.add(c, 3, 1, 1, 0.1)).toBe(false)
	end)

	it("reconciles a BiteResult: accepted stay gone, rejected show again and fade in", function()
		local c = BiteClaims.new(0)
		BiteClaims.add(c, 5, 0, 2, 0)
		BiteClaims.add(c, 5, 1, 2, 0)
		BiteClaims.add(c, 6, 4, 9, 0)
		local _, seq = BiteClaims.flush(c, 0, 0)
		local accepted, rejected, gone = {}, {}, {}
		expect(BiteClaims.result(c, seq, 0b101, 2, 0.2, accepted, rejected, gone)).toBe(true)
		expect(#gone).toBe(0)
		expect(#accepted).toBe(2)
		expect(accepted[2].groupId).toBe(6)
		expect(#rejected).toBe(1)
		expect(rejected[1].member).toBe(1)
		expect(BiteClaims.isHidden(c, 5, 1, 2)).toBe(false)
		expect(BiteClaims.isHidden(c, 5, 0, 2)).toBe(false) -- the mirror clears its alive bit
		expect(BiteClaims.fadeIn(c, 5, 1, 0.2)).toBe(0)
		expect(BiteClaims.fadeIn(c, 5, 1, 0.275)).toBeCloseTo(0.5, 1e-9)
		expect(BiteClaims.fadeIn(c, 5, 0, 0.2)).toBe(1)
		expect(BiteClaims.result(c, seq, 0, 2, 0.3, accepted, rejected, gone)).toBe(false) -- duplicate
		BiteClaims.expire(c, 1, rejected)
		expect(BiteClaims.fading(c)).toBe(false)
	end)

	it("treats rejects for `gone` as eaten elsewhere: no fade, nothing shown again", function()
		for _, reason in { 2, 3, 4, 5, 6, 7, 8 } do
			local c = BiteClaims.new(0)
			BiteClaims.add(c, 5, 0, 2, 0)
			local _, seq = BiteClaims.flush(c, 0, 0)
			local accepted, rejected, gone = {}, {}, {}
			BiteClaims.result(c, seq, 0, reason, 0.1, accepted, rejected, gone)
			expect(#rejected).toBe(1) -- range, tier, time, rate, state, safe zone, protected
			expect(BiteClaims.fadeIn(c, 5, 0, 0.1)).toBe(0)
		end
		local c = BiteClaims.new(0)
		BiteClaims.add(c, 5, 0, 2, 0)
		BiteClaims.add(c, 5, 1, 2, 0)
		local _, seq = BiteClaims.flush(c, 0, 0)
		local accepted, rejected, gone = {}, {}, {}
		BiteClaims.result(c, seq, 0b10, BiteClaims.REASON_GONE, 0.1, accepted, rejected, gone)
		expect(#accepted).toBe(1)
		expect(#rejected).toBe(0)
		expect(#gone).toBe(1)
		expect(gone[1].member).toBe(0)
		expect(BiteClaims.isHidden(c, 5, 0, 2)).toBe(false)
		expect(BiteClaims.fading(c)).toBe(false)
	end)

	it("times a claim out at clamp(2 × rtt + 0.25 s, 0.5 s, 2 s) (tune)", function()
		expect(BiteClaims.timeout(nil)).toBe(2)
		expect(BiteClaims.timeout(0)).toBe(0.5)
		expect(BiteClaims.timeout(0.2)).toBeCloseTo(0.65, 1e-9)
		expect(BiteClaims.timeout(5)).toBe(2)
		local c = BiteClaims.new(0)
		BiteClaims.add(c, 1, 1, 1, 0)
		local _, seq = BiteClaims.flush(c, 0, 0, BiteClaims.timeout(0.2))
		local rejected = {}
		expect(BiteClaims.expire(c, 0.6, rejected)).toBe(0)
		expect(BiteClaims.expire(c, 0.7, rejected)).toBe(1)
		expect(BiteClaims.isHidden(c, 1, 1, 1)).toBe(false)
		expect(BiteClaims.fadeIn(c, 1, 1, 0.7)).toBe(0) -- shown again with the fade
		-- A result after the time-out is ignored.
		expect(BiteClaims.result(c, seq, 1, 0, 0.8, {}, {}, {})).toBe(false)
	end)

	it(
		"treats a claim with no answer after 2 s as rejected; an unsent one shows again at once",
		function()
			local c = BiteClaims.new(0)
			BiteClaims.add(c, 1, 1, 1, 0)
			local _, first = BiteClaims.flush(c, 0, 0)
			BiteClaims.add(c, 1, 2, 1, 1)
			local _, second = BiteClaims.flush(c, 0, 1)
			expect(second).toBe((first + 1) % 65536)
			local rejected = {}
			expect(BiteClaims.expire(c, 2.5, rejected)).toBe(1)
			expect(#rejected).toBe(1)
			expect(BiteClaims.isHidden(c, 1, 1, 1)).toBe(false)
			expect(BiteClaims.isHidden(c, 1, 2, 1)).toBe(true)
			BiteClaims.unsent(c, second)
			expect(BiteClaims.isHidden(c, 1, 2, 1)).toBe(false)
			expect(BiteClaims.fadeIn(c, 1, 2, 2.5)).toBe(1)
			expect(BiteClaims.pendingCount(c)).toBe(0)
			expect(BiteClaims.hiddenCount(c)).toBe(0)
		end
	)

	it("wraps seq at 65536", function()
		local c = BiteClaims.new(0)
		c.seq = 65535
		BiteClaims.add(c, 1, 0, 1, 0)
		local _, seq = BiteClaims.flush(c, 0, 0)
		expect(seq).toBe(65535)
		expect(c.seq).toBe(0)
	end)
end)
