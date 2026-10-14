--!strict
local Ring = require("../../../src/shared/Util/Ring")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Ring", function()
	it("new makes an empty ring of the given capacity", function()
		local ring: Ring.Ring<number> = Ring.new(4)
		expect(ring.capacity).toBe(4)
		expect(Ring.size(ring)).toBe(0)
		expect(Ring.get(ring, 1)).toBe(nil)
		expect(Ring.newest(ring)).toBe(nil)
		expect(Ring.toArray(ring)).toEqual({})
	end)

	it("new refuses a capacity that is not a whole number of 1 or more", function()
		for _, capacity in { 0, -1, 2.5, 0 / 0 } do
			expect(function()
				Ring.new(capacity)
			end).toThrow("capacity")
		end
	end)

	it("push keeps values oldest first while there is room", function()
		local ring: Ring.Ring<string> = Ring.new(3)
		expect(Ring.push(ring, "a")).toBe(nil)
		expect(Ring.push(ring, "b")).toBe(nil)
		expect(Ring.size(ring)).toBe(2)
		expect(Ring.get(ring, 1)).toBe("a")
		expect(Ring.get(ring, 2)).toBe("b")
		expect(Ring.get(ring, 3)).toBe(nil)
		expect(Ring.toArray(ring)).toEqual({ "a", "b" })
	end)

	it("push into a full ring drops and returns the oldest", function()
		local ring: Ring.Ring<number> = Ring.new(3)
		for value = 1, 3 do
			expect(Ring.push(ring, value)).toBe(nil)
		end
		expect(Ring.push(ring, 4)).toBe(1)
		expect(Ring.push(ring, 5)).toBe(2)
		expect(Ring.size(ring)).toBe(3)
		expect(Ring.toArray(ring)).toEqual({ 3, 4, 5 })
		expect(Ring.get(ring, 1)).toBe(3)
		expect(Ring.get(ring, 3)).toBe(5)
	end)

	it("keeps order through many wraps", function()
		local ring: Ring.Ring<number> = Ring.new(5)
		for value = 1, 1003 do
			Ring.push(ring, value)
		end
		expect(Ring.toArray(ring)).toEqual({ 999, 1000, 1001, 1002, 1003 })
	end)

	it("get returns nil outside 1..size", function()
		local ring: Ring.Ring<number> = Ring.new(2)
		Ring.push(ring, 7)
		expect(Ring.get(ring, 0)).toBe(nil)
		expect(Ring.get(ring, -1)).toBe(nil)
		expect(Ring.get(ring, 2)).toBe(nil)
	end)

	it("newest counts back from the last push", function()
		local ring: Ring.Ring<number> = Ring.new(3)
		for value = 1, 5 do
			Ring.push(ring, value)
		end
		expect(Ring.newest(ring)).toBe(5)
		expect(Ring.newest(ring, 0)).toBe(5)
		expect(Ring.newest(ring, 1)).toBe(4)
		expect(Ring.newest(ring, 2)).toBe(3)
		expect(Ring.newest(ring, 3)).toBe(nil)
	end)

	it("a ring of capacity 1 holds only the newest", function()
		local ring: Ring.Ring<string> = Ring.new(1)
		expect(Ring.push(ring, "a")).toBe(nil)
		expect(Ring.push(ring, "b")).toBe("a")
		expect(Ring.toArray(ring)).toEqual({ "b" })
	end)

	it("clear empties the ring and it fills again from the start", function()
		local ring: Ring.Ring<number> = Ring.new(3)
		for value = 1, 5 do
			Ring.push(ring, value)
		end
		Ring.clear(ring)
		expect(Ring.size(ring)).toBe(0)
		expect(Ring.newest(ring)).toBe(nil)
		expect(Ring.push(ring, 9)).toBe(nil)
		expect(Ring.toArray(ring)).toEqual({ 9 })
		expect(ring.capacity).toBe(3)
	end)

	it("toArray returns a copy", function()
		local ring: Ring.Ring<number> = Ring.new(2)
		Ring.push(ring, 1)
		local values = Ring.toArray(ring)
		values[1] = 99
		expect(Ring.get(ring, 1)).toBe(1)
	end)
end)
