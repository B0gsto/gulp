--!strict
local Signal = require("../../../src/shared/Util/Signal")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Signal", function()
	it("fire with no handlers does nothing", function()
		local signal: Signal.Signal<number> = Signal.new()
		signal:fire(1)
	end)

	it("connect calls the handler with every fired value, in connection order", function()
		local signal: Signal.Signal<number, string> = Signal.new()
		local calls: { string } = {}
		signal:connect(function(amount, name)
			table.insert(calls, `first {amount} {name}`)
		end)
		signal:connect(function(amount, name)
			table.insert(calls, `second {amount} {name}`)
		end)
		signal:fire(3, "krill")
		signal:fire(5, "sardine")
		expect(calls).toEqual({
			"first 3 krill",
			"second 3 krill",
			"first 5 sardine",
			"second 5 sardine",
		})
	end)

	it("passes nil values through", function()
		local signal: Signal.Signal<string?, number?> = Signal.new()
		local count, first, second = 0, "unset" :: string?, -1 :: number?
		signal:connect(function(...)
			count = select("#", ...)
			first, second = ...
		end)
		signal:fire(nil, nil)
		expect(count).toBe(2)
		expect(first).toBe(nil)
		expect(second).toBe(nil)
	end)

	it("disconnect stops one handler and is safe to repeat", function()
		local signal: Signal.Signal<> = Signal.new()
		local kept, dropped = 0, 0
		signal:connect(function()
			kept += 1
		end)
		local connection = signal:connect(function()
			dropped += 1
		end)
		expect(connection.connected).toBe(true)
		signal:fire()
		connection:disconnect()
		connection:disconnect()
		expect(connection.connected).toBe(false)
		signal:fire()
		expect(kept).toBe(2)
		expect(dropped).toBe(1)
	end)

	it("once calls the handler for the next fire only", function()
		local signal: Signal.Signal<number> = Signal.new()
		local seen: { number } = {}
		local connection = signal:once(function(value)
			table.insert(seen, value)
		end)
		signal:fire(1)
		signal:fire(2)
		expect(seen).toEqual({ 1 })
		expect(connection.connected).toBe(false)
	end)

	it("once can be disconnected before it fires", function()
		local signal: Signal.Signal<> = Signal.new()
		local calls = 0
		signal
			:once(function()
				calls += 1
			end)
			:disconnect()
		signal:fire()
		expect(calls).toBe(0)
	end)

	it("a once handler that fires the signal again is not called twice", function()
		local signal: Signal.Signal<> = Signal.new()
		local calls = 0
		signal:once(function()
			calls += 1
			signal:fire()
		end)
		signal:fire()
		expect(calls).toBe(1)
	end)

	it("a handler connected during a fire is first called by the next fire", function()
		local signal: Signal.Signal<> = Signal.new()
		local late = 0
		signal:once(function()
			signal:connect(function()
				late += 1
			end)
		end)
		signal:fire()
		expect(late).toBe(0)
		signal:fire()
		expect(late).toBe(1)
	end)

	it("a handler disconnected during a fire is not called by it", function()
		local signal: Signal.Signal<> = Signal.new()
		local second = 0
		local connection
		signal:connect(function()
			connection:disconnect()
		end)
		connection = signal:connect(function()
			second += 1
		end)
		signal:fire()
		expect(second).toBe(0)
	end)

	it("a handler may disconnect itself", function()
		local signal: Signal.Signal<> = Signal.new()
		local calls, after = 0, 0
		local connection
		connection = signal:connect(function()
			calls += 1
			connection:disconnect()
		end)
		signal:connect(function()
			after += 1
		end)
		signal:fire()
		signal:fire()
		expect(calls).toBe(1)
		expect(after).toBe(2)
	end)

	it("disconnectAll drops every handler and marks its connection", function()
		local signal: Signal.Signal<> = Signal.new()
		local calls = 0
		local first = signal:connect(function()
			calls += 1
		end)
		local second = signal:once(function()
			calls += 1
		end)
		signal:disconnectAll()
		signal:fire()
		expect(calls).toBe(0)
		expect(first.connected).toBe(false)
		expect(second.connected).toBe(false)
		signal:connect(function()
			calls += 1
		end)
		signal:fire()
		expect(calls).toBe(1)
	end)

	it("an error in a handler reaches the caller of fire", function()
		local signal: Signal.Signal<> = Signal.new()
		signal:connect(function()
			error("the handler broke")
		end)
		expect(function()
			signal:fire()
		end).toThrow("the handler broke")
	end)

	it("signals do not share handlers", function()
		local a: Signal.Signal<> = Signal.new()
		local b: Signal.Signal<> = Signal.new()
		local calls = 0
		a:connect(function()
			calls += 1
		end)
		b:fire()
		expect(calls).toBe(0)
	end)
end)
