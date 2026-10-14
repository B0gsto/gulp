--!strict
local Defaults = require("../../../src/shared/Config/Defaults")
local LiveConfigRules = require("../../../src/shared/Logic/LiveConfigRules")
local StatePatch = require("../../../src/shared/Logic/StatePatch")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("LiveConfigRules", function()
	it("forwards flag, kill, live, assist and tune.quality keys, not server tolerances", function()
		expect(LiveConfigRules.isClientKey("flag.tideEvents")).toBe(true)
		expect(LiveConfigRules.isClientKey("kill.purchases")).toBe(true)
		expect(LiveConfigRules.isClientKey("live.noticeTextKey")).toBe(true)
		expect(LiveConfigRules.isClientKey("assist.nudge")).toBe(true)
		expect(LiveConfigRules.isClientKey("tune.quality.preyMeshes")).toBe(true)
		expect(LiveConfigRules.isClientKey("tune.bite.baseTolerance")).toBe(false)
		expect(LiveConfigRules.isClientKey("tune.move.slack")).toBe(false)
		expect(LiveConfigRules.isClientKey("flagged")).toBe(false)
	end)

	it("uses StatePatch's config root", function()
		expect(LiveConfigRules.ROOT).toBe(StatePatch.CONFIG_ROOT)
	end)

	it("maps keys to config paths and back", function()
		expect(LiveConfigRules.pathOf("flag.tideEvents")).toBe("config.flag.tideEvents")
		expect(LiveConfigRules.keyOf("config.flag.tideEvents")).toBe("flag.tideEvents")
		expect(LiveConfigRules.keyOf("config.")).toBe(nil)
		expect(LiveConfigRules.keyOf("config")).toBe(nil)
		expect(LiveConfigRules.keyOf("configs.flag.x")).toBe(nil)
		expect(LiveConfigRules.keyOf("pearls")).toBe(nil)
	end)

	it("gives every known key a valid State path", function()
		for key in Defaults.live do
			local path = LiveConfigRules.pathOf(key)
			expect(StatePatch.split(path) ~= nil).toBe(true)
			expect(LiveConfigRules.keyOf(path)).toBe(key)
		end
	end)

	it("lists the client keys whose value changed, sorted", function()
		local keys = { "kill.pvp", "flag.tideEvents", "tune.bite.baseTolerance", "live.x" }
		local before = {
			["kill.pvp"] = false,
			["flag.tideEvents"] = true,
			["tune.bite.baseTolerance"] = 3,
			["live.x"] = "a",
		}
		local after = {
			["kill.pvp"] = true,
			["flag.tideEvents"] = false,
			["tune.bite.baseTolerance"] = 4,
			["live.x"] = "a",
		}
		expect(LiveConfigRules.changedClientKeys(keys, before, after)).toEqual({
			"flag.tideEvents",
			"kill.pvp",
		})
	end)
end)
