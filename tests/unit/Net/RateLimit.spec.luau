--!strict
local RateLimit = require("../../../src/shared/Net/RateLimit")
local Remotes = require("../../../src/shared/Net/Remotes")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- Sends `count` messages at time `now`; returns how many passed.
local function burst(
	limiter: RateLimit.RateLimit<string>,
	key: string,
	remote: string,
	now: number,
	count: number
)
	local passed = 0
	for _ = 1, count do
		if RateLimit.allow(limiter, key, remote, now) then
			passed += 1
		end
	end
	return passed
end

describe("Net/RateLimit", function()
	it("takes its limits from every client-to-server row of the remote table", function()
		local limits = RateLimit.limitsFromRemotes()
		for _, def in Remotes.list do
			local limit = limits[def.name]
			if def.direction == "ClientToServer" then
				expect(limit).toEqual({ rate = def.rate, size = def.bucket })
			else
				expect(limit).toBe(nil)
			end
		end
	end)

	it("Bite: a burst of 20, then 12 a second", function()
		local limiter: RateLimit.RateLimit<string> = RateLimit.new()
		expect(burst(limiter, "a", "Bite", 0, 30)).toBe(20)
		expect(burst(limiter, "a", "Bite", 1, 30)).toBe(12)
		expect(burst(limiter, "a", "Bite", 1.5, 30)).toBe(6)
	end)

	it("ClientReady: once per session, never refilled", function()
		local limiter: RateLimit.RateLimit<string> = RateLimit.new()
		expect(RateLimit.allow(limiter, "a", "ClientReady", 0)).toBe(true)
		expect(RateLimit.allow(limiter, "a", "ClientReady", 3600)).toBe(false)
	end)

	it("Telemetry: a bucket of 2, then 1 per 20 s", function()
		local limiter: RateLimit.RateLimit<string> = RateLimit.new()
		expect(burst(limiter, "a", "Telemetry", 0, 5)).toBe(2)
		expect(burst(limiter, "a", "Telemetry", 19, 5)).toBe(0)
		expect(burst(limiter, "a", "Telemetry", 20, 5)).toBe(1)
	end)

	it("keys and remotes have separate buckets", function()
		local limiter: RateLimit.RateLimit<string> = RateLimit.new()
		expect(burst(limiter, "a", "GoalAction", 0, 10)).toBe(4)
		expect(burst(limiter, "b", "GoalAction", 0, 10)).toBe(4)
		expect(burst(limiter, "a", "SettingsSet", 0, 10)).toBe(4)
	end)

	it("forget drops a key's buckets; it comes back full", function()
		local limiter: RateLimit.RateLimit<string> = RateLimit.new()
		burst(limiter, "a", "ClientReady", 0, 1)
		burst(limiter, "b", "Bite", 0, 1)
		expect(RateLimit.keyCount(limiter)).toBe(2)
		RateLimit.forget(limiter, "a")
		expect(RateLimit.keyCount(limiter)).toBe(1)
		expect(RateLimit.allow(limiter, "a", "ClientReady", 1)).toBe(true)
	end)

	it("custom limits replace the table, and an unlimited remote throws", function()
		local limiter: RateLimit.RateLimit<string> =
			RateLimit.new({ Ping = { rate = 1, size = 1 } })
		expect(burst(limiter, "a", "Ping", 0, 3)).toBe(1)
		expect(function()
			RateLimit.allow(limiter, "a", "Bite", 0)
		end).toThrow("no limit")
	end)
end)
