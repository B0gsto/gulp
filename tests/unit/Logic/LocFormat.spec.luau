--!strict
local LocFormat = require("../../../src/shared/Logic/LocFormat")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("LocFormat.isKey", function()
	it("takes dot-separated lowercase keys with a prefix", function()
		expect(LocFormat.isKey("common.ok")).toBe(true)
		expect(LocFormat.isKey("tier.1")).toBe(true)
		expect(LocFormat.isKey("pass.deep_pockets.desc")).toBe(true)
	end)

	it("refuses keys with no prefix, capitals, spaces or empty segments", function()
		expect(LocFormat.isKey("ok")).toBe(false)
		expect(LocFormat.isKey("Common.ok")).toBe(false)
		expect(LocFormat.isKey("common.Ok")).toBe(false)
		expect(LocFormat.isKey("common. ok")).toBe(false)
		expect(LocFormat.isKey("common..ok")).toBe(false)
		expect(LocFormat.isKey("common.ok.")).toBe(false)
		expect(LocFormat.isKey("1tier.x")).toBe(false)
	end)
end)

describe("LocFormat.params", function()
	it("lists named and numbered parameters once, in order", function()
		expect(LocFormat.params("{Mass} to {Tier}, {Mass}")).toEqual({ "Mass", "Tier" })
		expect(LocFormat.params("{1:int} of {2}")).toEqual({ "1", "2" })
		expect(LocFormat.params("No parameters")).toEqual({})
	end)
end)

describe("LocFormat.format", function()
	it("fills {Name} parameters from a dictionary", function()
		expect(LocFormat.format("{Mass} to {Tier}", { Mass = 12, Tier = "Snapper" })).toBe(
			"12 to Snapper"
		)
	end)

	it("fills {1} and {1:int} from an array, rounding int", function()
		expect(LocFormat.format("{1:int} of {2}", { 2.6, "five" })).toBe("3 of five")
		expect(LocFormat.format("{1:int}", { -2.5 })).toBe("-3")
	end)

	it("leaves a parameter with no argument as written", function()
		expect(LocFormat.format("{Mass} to {Tier}", { Mass = 4 })).toBe("4 to {Tier}")
		expect(LocFormat.format("{Mass}", nil)).toBe("{Mass}")
	end)

	it("does not treat argument text as a pattern", function()
		expect(LocFormat.format("{Name}!", { Name = "50% {x}" })).toBe("50% {x}!")
	end)
end)
