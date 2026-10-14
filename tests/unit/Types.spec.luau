--!strict
local TestKit = require("../../src/shared/Util/TestKit")
local Types = require("../../src/shared/Types")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Types", function()
	it("loads headless and carries no runtime values", function()
		expect(Types).toEqual({})
	end)

	it("types check against values shaped like the bible's", function()
		local slot: Types.Slot = 24
		local tide: Types.TideState =
			{ phase = "active", id = "frenzy", startsAt = 0, endsAt = 240 }
		local specimen: Types.SpecimenRecord =
			{ id = "a1b2c3d4", sp = "minnow", tier = 2, mass = 12.5, traits = { "glow" }, at = 0 }
		local service: Types.Service =
			{ name = "Example", init = function() end, start = function() end }
		expect(slot).toBe(24)
		expect(tide.endsAt - tide.startsAt).toBe(240)
		expect(specimen.pat).toBe(nil)
		expect(service.name).toBe("Example")
	end)
end)
