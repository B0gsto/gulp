--!strict
local SlotPool = require("../../../src/shared/Logic/SlotPool")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("SlotPool", function()
	it("hands out 1 to 24, lowest free first, then reports full", function()
		local pool = SlotPool.new()
		for want = 1, 24 do
			expect(SlotPool.take(pool)).toBe(want)
		end
		expect(SlotPool.count(pool)).toBe(24)
		expect(SlotPool.take(pool)).toBe(nil)
	end)

	it("reuses a freed slot, and only a held slot can be freed", function()
		local pool = SlotPool.new(3)
		expect(SlotPool.take(pool)).toBe(1)
		expect(SlotPool.take(pool)).toBe(2)
		expect(SlotPool.take(pool)).toBe(3)
		expect(SlotPool.free(pool, 2)).toBe(true)
		expect(SlotPool.free(pool, 2)).toBe(false)
		expect(SlotPool.free(pool, 9)).toBe(false)
		expect(SlotPool.count(pool)).toBe(2)
		expect(SlotPool.take(pool)).toBe(2)
		expect(SlotPool.take(pool)).toBe(nil)
	end)

	it("takes the first free slot of a preference list", function()
		local pool = SlotPool.new()
		expect(SlotPool.take(pool, { 16, 17, 15, 18 })).toBe(16)
		expect(SlotPool.take(pool, { 16, 17, 15, 18 })).toBe(17)
		-- Slots outside the pool and fractions are skipped; an empty list means lowest free.
		expect(SlotPool.take(pool, { 0, 25, 2.5, 15 })).toBe(15)
		expect(SlotPool.take(pool, {})).toBe(1)
		-- A list with nothing free falls back to the lowest free slot.
		expect(SlotPool.take(pool, { 16, 17 })).toBe(2)
	end)

	it("never gives one slot to two players", function()
		local pool = SlotPool.new()
		local held: { [number]: boolean } = {}
		local order = { 5, 3, 24, 1, 12 }
		for round = 1, 200 do
			local slot = SlotPool.take(pool, if round % 3 == 0 then order else nil)
			if slot then
				expect(held[slot]).toBe(nil)
				held[slot] = true
			end
			if round % 2 == 0 then
				local drop = (round * 7) % 24 + 1
				if held[drop] then
					SlotPool.free(pool, drop)
					held[drop] = nil
				end
			end
		end
	end)

	it("refuses a bad size", function()
		expect(function()
			SlotPool.new(0)
		end).toThrow("size")
	end)
end)
