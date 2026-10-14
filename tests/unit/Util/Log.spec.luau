--!strict
local Log = require("../../../src/shared/Util/Log")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- Runs `body` with the lines and the counts captured, then restores the defaults.
local function captured(body: (lines: { string }, counts: { string }) -> ())
	local lines: { string }, counts: { string } = {}, {}
	Log.resetOnce()
	Log.setSink(function(level, tag, message)
		table.insert(lines, `{level}|{tag}|{message}`)
	end)
	Log.setCounter(function(level, tag)
		table.insert(counts, `{level}|{tag}`)
	end)
	local ok, problem = pcall(body, lines, counts)
	Log.setSink(nil)
	Log.setCounter(nil)
	Log.resetOnce()
	if not ok then
		error(problem, 0)
	end
end

describe("Log", function()
	it("info, warn and error send level, tag and message to the sink", function()
		captured(function(lines)
			Log.info("DataService", "profile loaded")
			Log.warn("ShopService", "pass check failed; using the saved answer")
			Log.error("DataService", "profile over 200 kB")
			expect(lines).toEqual({
				"info|DataService|profile loaded",
				"warn|ShopService|pass check failed; using the saved answer",
				"error|DataService|profile over 200 kB",
			})
		end)
	end)

	it("warn and error are counted, info is not", function()
		captured(function(_, counts)
			Log.info("A", "one")
			Log.warn("B", "two")
			Log.error("C", "three")
			expect(counts).toEqual({ "warn|B", "error|C" })
		end)
	end)

	it("error does not throw", function()
		captured(function()
			Log.error("A", "broken")
		end)
	end)

	it("once writes a level, tag and message only the first time", function()
		captured(function(lines, counts)
			expect(Log.once("warn", "Flags", "bad value")).toBe(true)
			expect(Log.once("warn", "Flags", "bad value")).toBe(false)
			expect(Log.once("warn", "Flags", "another bad value")).toBe(true)
			expect(Log.once("warn", "Other", "bad value")).toBe(true)
			expect(Log.once("info", "Flags", "bad value")).toBe(true)
			expect(#lines).toBe(4)
			expect(counts).toEqual({ "warn|Flags", "warn|Flags", "warn|Other" })
		end)
	end)

	it("resetOnce lets once write again", function()
		captured(function(lines)
			Log.once("info", "A", "hello")
			Log.resetOnce()
			expect(Log.once("info", "A", "hello")).toBe(true)
			expect(#lines).toBe(2)
		end)
	end)

	it("setCounter(nil) stops counting", function()
		captured(function(lines, counts)
			Log.setCounter(nil)
			Log.warn("A", "uncounted")
			expect(counts).toEqual({})
			expect(#lines).toBe(1)
		end)
	end)

	it("a counter that logs is not counted again", function()
		captured(function(lines)
			local calls = 0
			Log.setCounter(function()
				calls += 1
				Log.warn("Analytics", "counter could not send")
			end)
			Log.warn("A", "first")
			expect(calls).toBe(1)
			expect(lines).toEqual({ "warn|A|first", "warn|Analytics|counter could not send" })
		end)
	end)

	it("a counter that throws is logged and does not reach the caller", function()
		captured(function(lines)
			Log.setCounter(function()
				error("no analytics", 0)
			end)
			Log.error("A", "first")
			Log.warn("A", "second")
			expect(lines).toEqual({
				"error|A|first",
				"warn|Log|the counter failed: no analytics",
				"warn|A|second",
				"warn|Log|the counter failed: no analytics",
			})
		end)
	end)

	it("setSink(nil) restores the default sink, which prints without throwing", function()
		Log.setSink(function() end)
		Log.setSink(nil)
		Log.info("Log.spec", "one line from the default sink (expected in the test output)")
	end)
end)
