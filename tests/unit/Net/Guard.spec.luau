--!strict
local Guard = require("../../../src/shared/Net/Guard")
local Log = require("../../../src/shared/Util/Log")
local TestKit = require("../../../src/shared/Util/TestKit")
local Validate = require("../../../src/shared/Net/Validate")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type Line = { level: string, message: string }

-- Runs `body` with the log captured, then restores it.
local function quietly(body: (lines: { Line }) -> ())
	local lines: { Line } = {}
	Log.resetOnce()
	Log.setSink(function(level, _tag, message)
		table.insert(lines, { level = level, message = message })
	end)
	local ok, problem = pcall(body, lines)
	Log.setSink(nil)
	Log.resetOnce()
	if not ok then
		error(problem, 0)
	end
end

local function goalSpecs(): { Validate.Spec }
	return { Validate.int(1, 3), Validate.int(1, 10) }
end

describe("Net/Guard", function()
	it("route refuses unknown remotes, server-to-client remotes and a second handler", function()
		local guard: Guard.Guard<string> = Guard.new()
		local noop = function(_key: string, ...: unknown) end
		expect(function()
			Guard.route(guard, "Nope", {}, noop)
		end).toThrow("unknown remote")
		expect(function()
			Guard.route(guard, "PreyState", { Validate.buffer(0, 900) }, noop)
		end).toThrow("server to client")
		Guard.route(guard, "GoalAction", goalSpecs(), noop)
		expect(Guard.isRouted(guard, "GoalAction")).toBe(true)
		expect(function()
			Guard.route(guard, "GoalAction", goalSpecs(), noop)
		end).toThrow("already has a handler")
	end)

	it("route refuses a spec that does not fit the remote table", function()
		local guard: Guard.Guard<string> = Guard.new()
		local noop = function(_key: string, ...: unknown) end
		local cases: { { string | { Validate.Spec } } } = {
			{ "ClientReady", { Validate.boolean() }, "no payload" },
			{ "Bite", { Validate.string(8) }, "one buffer" },
			{ "Bite", { Validate.buffer(8, 44) }, "maximum is 40" },
			{ "Bite", { Validate.buffer(4, 40) }, "minimum is 8" },
			{ "RunAction", { Validate.buffer(1, 4) }, "scalars" },
			{ "RunAction", {}, "scalars" },
			{ "ShopAction", { Validate.int(1, 2), Validate.string(40) }, "maximum is 32" },
		}
		for _, case in cases do
			expect(function()
				-- Safe casts: the rows above are written as name, specs, message.
				Guard.route(guard, case[1] :: string, case[2] :: { Validate.Spec }, noop)
			end).toThrow(case[3] :: string)
		end
	end)

	it("a valid message reaches the handler with the sender and arguments", function()
		quietly(function()
			local guard: Guard.Guard<string> = Guard.new()
			local got: { unknown } = {}
			Guard.route(guard, "GoalAction", goalSpecs(), function(key: string, ...: unknown)
				got = { key, ... }
			end)
			expect(Guard.handle(guard, "p1", "GoalAction", 0, 2, 7)).toBe(true)
			expect(got).toEqual({ "p1", 2, 7 })
			expect(Guard.counters(guard).GoalAction).toEqual({ passed = 1, rejects = {} })
		end)
	end)

	it(
		"malformed messages are rejected by reason, counted and fired, before the handler",
		function()
			quietly(function(lines)
				local guard: Guard.Guard<string> = Guard.new()
				local calls = 0
				Guard.route(guard, "GoalAction", goalSpecs(), function()
					calls += 1
				end)
				local fired: { string } = {}
				guard.rejected:connect(function(key: string, name: string, reason: Guard.Reason)
					table.insert(fired, `{key}:{name}:{reason}`)
				end)
				expect(select(2, Guard.handle(guard, "p1", "GoalAction", 0, 2))).toBe("count")
				expect(select(2, Guard.handle(guard, "p1", "GoalAction", 0, "2", 1))).toBe("type")
				expect(select(2, Guard.handle(guard, "p1", "GoalAction", 0, 9, 1))).toBe("range")
				expect(select(2, Guard.handle(guard, "p1", "GoalAction", 0, 0 / 0, 1))).toBe(
					"range"
				)
				expect(calls).toBe(0)
				expect(fired).toEqual({
					"p1:GoalAction:count",
					"p1:GoalAction:type",
					"p1:GoalAction:range",
					"p1:GoalAction:range",
				})
				expect(Guard.counters(guard).GoalAction.rejects).toEqual({
					count = 1,
					type = 1,
					range = 2,
				})
				-- One info line per remote and reason, so a flood does not flood the log.
				expect(#lines).toBe(3)
				expect(lines[1].level).toBe("info")
			end)
		end
	)

	it("a flood is dropped with reason rate; malformed messages spend no tokens", function()
		quietly(function()
			local guard: Guard.Guard<string> = Guard.new()
			local calls = 0
			Guard.route(guard, "GoalAction", goalSpecs(), function()
				calls += 1
			end)
			for _ = 1, 10 do
				Guard.handle(guard, "p1", "GoalAction", 0, "bad", 1)
			end
			for _ = 1, 10 do
				Guard.handle(guard, "p1", "GoalAction", 0, 1, 1)
			end
			-- GoalAction: 2 a second, bucket of 4 (section 5.3).
			expect(calls).toBe(4)
			expect(Guard.counters(guard).GoalAction.rejects.rate).toBe(6)
			-- Another player has a bucket of their own.
			expect(Guard.handle(guard, "p2", "GoalAction", 0, 1, 1)).toBe(true)
			expect(Guard.handle(guard, "p1", "GoalAction", 0.5, 1, 1)).toBe(true)
		end)
	end)

	it(
		"a handler that throws is isolated, logged and counted, and not blamed on the sender",
		function()
			quietly(function(lines)
				local guard: Guard.Guard<string> = Guard.new()
				local fired = 0
				guard.rejected:connect(function()
					fired += 1
				end)
				Guard.route(guard, "GoalAction", goalSpecs(), function(_key: string, op: unknown)
					if op == 1 then
						error("boom")
					end
				end)
				expect(select(2, Guard.handle(guard, "p1", "GoalAction", 0, 1, 1))).toBe("error")
				expect(Guard.handle(guard, "p1", "GoalAction", 0, 2, 1)).toBe(true)
				expect(fired).toBe(0)
				expect(Guard.counters(guard).GoalAction).toEqual({
					passed = 1,
					rejects = { error = 1 },
				})
				expect(lines[1].level).toBe("warn")
				expect(string.find(lines[1].message, "GoalAction handler failed", 1, true) ~= nil).toBe(
					true
				)
			end)
		end
	)

	it("a rejected listener that throws does not escape", function()
		quietly(function(lines)
			local guard: Guard.Guard<string> = Guard.new()
			Guard.route(guard, "ClientReady", {}, function() end)
			guard.rejected:connect(function()
				error("listener broke")
			end)
			expect(select(2, Guard.handle(guard, "p1", "ClientReady", 0, 1))).toBe("count")
			expect(lines[#lines].level).toBe("warn")
		end)
	end)

	it("ClientReady passes once per session", function()
		quietly(function()
			local guard: Guard.Guard<string> = Guard.new()
			Guard.route(guard, "ClientReady", {}, function() end)
			expect(Guard.handle(guard, "p1", "ClientReady", 0)).toBe(true)
			expect(select(2, Guard.handle(guard, "p1", "ClientReady", 60))).toBe("rate")
		end)
	end)

	it("a message on a remote with no handler is refused without counting", function()
		quietly(function()
			local guard: Guard.Guard<string> = Guard.new()
			expect(select(2, Guard.handle(guard, "p1", "Bite", 0, buffer.create(8)))).toBe("error")
			expect(Guard.counters(guard)).toEqual({})
		end)
	end)
end)
