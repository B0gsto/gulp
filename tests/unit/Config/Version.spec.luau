--!strict
local TestKit = require("../../../src/shared/Util/TestKit")
local Version = require("../../../src/shared/Config/Version")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Version", function()
	it("has three whole, non-negative parts", function()
		for _, part in { Version.MAJOR, Version.MINOR, Version.PATCH } do
			expect(part % 1).toBe(0)
			expect(part >= 0).toBe(true)
		end
	end)

	it("STRING is MAJOR.MINOR.PATCH", function()
		expect(Version.STRING).toBe(`{Version.MAJOR}.{Version.MINOR}.{Version.PATCH}`)
		expect(string.match(Version.STRING, "^%d+%.%d+%.%d+$")).toBe(Version.STRING)
	end)
end)
