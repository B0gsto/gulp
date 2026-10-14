--!strict
local TestKit = require("../../../src/shared/Util/TestKit")
local Validate = require("../../../src/shared/Net/Validate")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- `Bite`: 8 bytes, or 8 + 4n with n from 1 to 8 (docs/09, sections 8.9 and 14.2).
local function biteLength(length: number): boolean
	return length == 8 or (length > 8 and length <= 40 and (length - 8) % 4 == 0)
end

local function reasonOf(spec: Validate.Spec, value: unknown): string?
	local ok, reason = Validate.value(spec, value)
	expect(ok).toBe(reason == nil)
	return reason
end

describe("Net/Validate", function()
	it("buffer: checks the type, the length range and the codec's own rule", function()
		local bite = Validate.buffer(8, 40, biteLength)
		expect(reasonOf(bite, buffer.create(8))).toBe(nil)
		expect(reasonOf(bite, buffer.create(12))).toBe(nil)
		expect(reasonOf(bite, buffer.create(40))).toBe(nil)
		expect(reasonOf(bite, buffer.create(10))).toBe("size")
		expect(reasonOf(bite, buffer.create(44))).toBe("size")
		expect(reasonOf(bite, buffer.create(4))).toBe("size")
		expect(reasonOf(bite, "12345678")).toBe("type")
		expect(reasonOf(bite, nil)).toBe("type")
	end)

	it("string: length is a size check, the ID table a range check", function()
		local sku = Validate.string(32, { gulp_pack = true })
		expect(reasonOf(sku, "gulp_pack")).toBe(nil)
		expect(reasonOf(sku, "free_pearls")).toBe("range")
		expect(reasonOf(sku, string.rep("a", 33))).toBe("size")
		expect(reasonOf(sku, 5)).toBe("type")
		expect(reasonOf(Validate.string(4), "abcd")).toBe(nil)
	end)

	it("number and int: finite, whole when asked, within range", function()
		local slot = Validate.int(1, 24)
		expect(reasonOf(slot, 1)).toBe(nil)
		expect(reasonOf(slot, 24)).toBe(nil)
		expect(reasonOf(slot, 0)).toBe("range")
		expect(reasonOf(slot, 25)).toBe("range")
		expect(reasonOf(slot, 2.5)).toBe("range")
		expect(reasonOf(slot, 0 / 0)).toBe("range")
		expect(reasonOf(slot, "1")).toBe("type")
		local amount = Validate.number(-1, 1)
		expect(reasonOf(amount, 0.25)).toBe(nil)
		expect(reasonOf(amount, math.huge)).toBe("range")
		expect(reasonOf(amount, -math.huge)).toBe("range")
		expect(reasonOf(amount, 0 / 0)).toBe("range")
		expect(reasonOf(Validate.number(-math.huge, math.huge), math.huge)).toBe("range")
	end)

	it("boolean accepts only booleans", function()
		expect(reasonOf(Validate.boolean(), false)).toBe(nil)
		expect(reasonOf(Validate.boolean(), 0)).toBe("type")
	end)

	it("either passes on any option and reports the least severe failure", function()
		local value =
			Validate.either({ Validate.boolean(), Validate.int(0, 10), Validate.string(8) })
		expect(reasonOf(value, true)).toBe(nil)
		expect(reasonOf(value, 3)).toBe(nil)
		expect(reasonOf(value, "loud")).toBe(nil)
		expect(reasonOf(value, 11)).toBe("range")
		expect(reasonOf(value, "much too long")).toBe("size")
		expect(reasonOf(value, buffer.create(1))).toBe("type")
	end)

	it("args: exact count, then each argument in order", function()
		local specs = { Validate.int(1, 4), Validate.number(0, 100) }
		expect(Validate.args(specs, 2, 50)).toBe(true)
		expect(select(2, Validate.args(specs, 2))).toBe("count")
		expect(select(2, Validate.args(specs, 2, 50, 1))).toBe("count")
		-- A trailing nil still counts as an argument.
		expect(select(2, Validate.args(specs, 2, 50, nil))).toBe("count")
		expect(select(2, Validate.args(specs, 9, "x"))).toBe("range")
		expect(select(2, Validate.args(specs, 2, "x"))).toBe("type")
		expect(Validate.args({})).toBe(true)
		expect(select(2, Validate.args({}, 1))).toBe("count")
	end)

	it("builders refuse impossible specs", function()
		expect(function()
			Validate.buffer(10, 5)
		end).toThrow("min <= max")
		expect(function()
			Validate.int(3, 1)
		end).toThrow("min <= max")
		expect(function()
			Validate.string(-1)
		end).toThrow("maxLength")
		expect(function()
			Validate.either({})
		end).toThrow("at least one")
	end)

	it("largestBuffer and longestString look inside either", function()
		local specs =
			{ Validate.either({ Validate.string(8), Validate.string(20) }), Validate.buffer(1, 9) }
		expect(Validate.largestBuffer(specs)).toBe(9)
		expect(Validate.longestString(specs)).toBe(20)
		expect(Validate.largestBuffer({ Validate.boolean() })).toBe(nil)
	end)
end)
