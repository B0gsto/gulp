--!strict
local TestKit = require("../../../src/shared/Util/TestKit")
local TokenBucket = require("../../../src/shared/Util/TokenBucket")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("TokenBucket", function()
	it("new starts full", function()
		local bucket = TokenBucket.new(12, 20, 100)
		expect(TokenBucket.available(bucket, 100)).toBe(20)
	end)

	it("new refuses a negative rate and a size of 0 or less", function()
		expect(function()
			TokenBucket.new(-1, 5, 0)
		end).toThrow("rate >= 0")
		expect(function()
			TokenBucket.new(1, 0, 0)
		end).toThrow("size > 0")
		expect(function()
			TokenBucket.new(0 / 0, 5, 0)
		end).toThrow()
	end)

	it("take allows a burst of `size`, then refuses", function()
		-- The Bite remote: 12 a second, bucket of 20 (docs/09, section 5.3).
		local bucket = TokenBucket.new(12, 20, 0)
		for _ = 1, 20 do
			expect(TokenBucket.take(bucket, 0)).toBe(true)
		end
		expect(TokenBucket.take(bucket, 0)).toBe(false)
		expect(TokenBucket.available(bucket, 0)).toBe(0)
	end)

	it("refills at `rate` a second and never above `size`", function()
		local bucket = TokenBucket.new(12, 20, 0)
		for _ = 1, 20 do
			TokenBucket.take(bucket, 0)
		end
		expect(TokenBucket.available(bucket, 0.5)).toBeCloseTo(6)
		expect(TokenBucket.available(bucket, 1)).toBeCloseTo(12)
		expect(TokenBucket.available(bucket, 60)).toBe(20)
	end)

	it("holds a steady sender to the rate", function()
		-- 30 claims a second for 10 seconds against 12 a second with a burst of 20.
		local bucket = TokenBucket.new(12, 20, 0)
		local accepted = 0
		for step = 0, 299 do
			if TokenBucket.take(bucket, step / 30) then
				accepted += 1
			end
		end
		expect(accepted >= 20 + 12 * 9 and accepted <= 20 + 12 * 10).toBe(true)
	end)

	it("take with a cost takes that many, or none", function()
		local bucket = TokenBucket.new(1, 5, 0)
		expect(TokenBucket.take(bucket, 0, 3)).toBe(true)
		expect(TokenBucket.take(bucket, 0, 3)).toBe(false)
		expect(TokenBucket.available(bucket, 0)).toBe(2)
		expect(TokenBucket.take(bucket, 0, 2)).toBe(true)
	end)

	it("a slow bucket gives exactly one token per period", function()
		-- EmoteAction: 1 per 3 s, bucket of 1. Refilled in 30 steps of 0.1 s.
		local bucket = TokenBucket.new(1 / 3, 1, 0)
		expect(TokenBucket.take(bucket, 0)).toBe(true)
		for step = 1, 29 do
			expect(TokenBucket.take(bucket, step * 0.1)).toBe(false)
		end
		expect(TokenBucket.take(bucket, 3)).toBe(true)
		expect(TokenBucket.take(bucket, 3)).toBe(false)
	end)

	it("a rate of 0 never refills", function()
		-- ClientReady: 1 per session.
		local bucket = TokenBucket.new(0, 1, 0)
		expect(TokenBucket.take(bucket, 0)).toBe(true)
		expect(TokenBucket.take(bucket, 86400)).toBe(false)
	end)

	it("a clock that steps back gives no tokens and loses none", function()
		local bucket = TokenBucket.new(1, 10, 100)
		for _ = 1, 10 do
			TokenBucket.take(bucket, 100)
		end
		expect(TokenBucket.available(bucket, 50)).toBe(0)
		expect(TokenBucket.available(bucket, 102)).toBeCloseTo(2)
		expect(TokenBucket.available(bucket, 101)).toBeCloseTo(2)
	end)

	it("available does not take", function()
		local bucket = TokenBucket.new(1, 3, 0)
		expect(TokenBucket.available(bucket, 0)).toBe(3)
		expect(TokenBucket.available(bucket, 0)).toBe(3)
	end)

	it("reset fills the bucket as of the given time", function()
		local bucket = TokenBucket.new(1, 4, 0)
		for _ = 1, 4 do
			TokenBucket.take(bucket, 0)
		end
		TokenBucket.reset(bucket, 10)
		expect(TokenBucket.available(bucket, 10)).toBe(4)
		expect(bucket.at).toBe(10)
	end)
end)
