--!strict
local Defaults = require("../../../src/shared/Config/Defaults")
local Flags = require("../../../src/shared/Config/Flags")
local Log = require("../../../src/shared/Util/Log")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- Runs `body` with Flags on its defaults and the log captured, then restores both.
local function isolated(body: (lines: { string }) -> ())
	local lines: { string } = {}
	Flags.reset()
	Log.resetOnce()
	Log.setSink(function(level, tag, message)
		table.insert(lines, `{level} {tag} {message}`)
	end)
	local ok, problem = pcall(body, lines)
	Log.setSink(nil)
	Log.resetOnce()
	Flags.reset()
	if not ok then
		error(problem, 0)
	end
end

describe("Flags", function()
	it("keys lists every key of Defaults.live, sorted", function()
		local keys = Flags.keys()
		local count = 0
		for key in Defaults.live do
			count += 1
			expect(Flags.isKnown(key)).toBe(true)
		end
		expect(#keys).toBe(count)
		for index = 2, #keys do
			expect(keys[index - 1] < keys[index]).toBe(true)
		end
	end)

	it("isKnown is false for a key that has no default", function()
		expect(Flags.isKnown("flag.noSuchThing")).toBe(false)
		expect(Flags.isKnown("")).toBe(false)
	end)

	it("get returns the default until a value is set", function()
		isolated(function()
			for key, default in Defaults.live do
				expect(Flags.get(key)).toBe(default)
			end
		end)
	end)

	it("bool, number and string read a key of their type", function()
		isolated(function()
			expect(Flags.bool("kill.purchases")).toBe(false)
			expect(Flags.number("live.shopDelaySeconds")).toBe(120)
			expect(Flags.string("live.limitedTideId")).toBe("")
		end)
	end)

	it("reading an unknown key or the wrong type throws", function()
		isolated(function()
			expect(function()
				Flags.get("flag.noSuchThing")
			end).toThrow('unknown key "flag.noSuchThing"')
			expect(function()
				Flags.bool("live.shopDelaySeconds")
			end).toThrow("is a number")
			expect(function()
				Flags.number("kill.purchases")
			end).toThrow("is a boolean")
			expect(function()
				Flags.string("kill.purchases")
			end).toThrow("is a boolean")
		end)
	end)

	it("set takes a value of the right type", function()
		isolated(function(lines)
			expect(Flags.set("kill.purchases", true)).toBe(true)
			expect(Flags.set("live.shopDelaySeconds", 90)).toBe(true)
			expect(Flags.set("live.limitedTideId", "red_tide")).toBe(true)
			expect(Flags.set("flag.reviveOffer", false)).toBe(true)
			expect(Flags.bool("kill.purchases")).toBe(true)
			expect(Flags.number("live.shopDelaySeconds")).toBe(90)
			expect(Flags.string("live.limitedTideId")).toBe("red_tide")
			expect(Flags.bool("flag.reviveOffer")).toBe(false)
			expect(lines).toEqual({})
		end)
	end)

	it("a wrongly typed value falls back to the default and logs once", function()
		isolated(function(lines)
			expect(Flags.set("live.shopDelaySeconds", 90)).toBe(true)
			expect(Flags.set("live.shopDelaySeconds", "90")).toBe(false)
			expect(Flags.set("live.shopDelaySeconds", "90")).toBe(false)
			expect(Flags.number("live.shopDelaySeconds")).toBe(120)
			expect(lines).toEqual({
				'warn Flags "live.shopDelaySeconds" needs a number, got string; using the default 120',
			})
		end)
	end)

	it("a number that is not finite is wrongly typed", function()
		isolated(function(lines)
			expect(Flags.set("tune.bite.baseTolerance", 0 / 0)).toBe(false)
			expect(Flags.set("tune.bite.baseTolerance", math.huge)).toBe(false)
			expect(Flags.number("tune.bite.baseTolerance")).toBe(3)
			expect(#lines).toBe(1)
		end)
	end)

	it("a missing value falls back to the default and logs once, without a warning", function()
		isolated(function(lines)
			expect(Flags.set("kill.pvp", true)).toBe(true)
			expect(Flags.set("kill.pvp", nil)).toBe(false)
			expect(Flags.set("kill.pvp", nil)).toBe(false)
			expect(Flags.bool("kill.pvp")).toBe(false)
			expect(lines).toEqual({ 'info Flags "kill.pvp" is not set; using the default false' })
		end)
	end)

	it("set ignores a key this build does not know, and logs once", function()
		isolated(function(lines)
			expect(Flags.set("flag.fromTheFuture", true)).toBe(false)
			expect(Flags.set("flag.fromTheFuture", true)).toBe(false)
			expect(Flags.isKnown("flag.fromTheFuture")).toBe(false)
			expect(lines).toEqual({ 'warn Flags ignored unknown key "flag.fromTheFuture"' })
		end)
	end)

	it("reset puts every key back on its default", function()
		isolated(function()
			Flags.set("kill.saves", true)
			Flags.set("live.noticeTextKey", "notice.storm")
			Flags.reset()
			expect(Flags.bool("kill.saves")).toBe(false)
			expect(Flags.string("live.noticeTextKey")).toBe("")
		end)
	end)
end)
