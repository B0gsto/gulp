--!strict
local Assert = require("../../../src/shared/Util/Assert")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- Runs `body` with the checks off, then turns them back on.
local function disabled(body: () -> ())
	Assert.setEnabled(false)
	local ok, problem = pcall(body)
	Assert.setEnabled(true)
	if not ok then
		error(problem, 0)
	end
end

describe("Assert", function()
	it("is enabled by default, and setEnabled switches it", function()
		expect(Assert.isEnabled()).toBe(true)
		disabled(function()
			expect(Assert.isEnabled()).toBe(false)
		end)
		expect(Assert.isEnabled()).toBe(true)
	end)

	it("that passes on true and throws the message on false", function()
		Assert.that(true, "never shown")
		expect(function()
			Assert.that(false, "slot out of range")
		end).toThrow("slot out of range")
	end)

	it("finite accepts numbers and refuses NaN and infinity", function()
		Assert.finite(0, "x")
		Assert.finite(-12.5, "x")
		for _, value in { 0 / 0, math.huge, -math.huge } do
			expect(function()
				Assert.finite(value, "posX")
			end).toThrow("posX must be a finite number")
		end
	end)

	it("intInRange accepts whole numbers inside the range, ends included", function()
		Assert.intInRange(1, 1, 24, "slot")
		Assert.intInRange(24, 1, 24, "slot")
		for _, value in { 0, 25, 3.5, 0 / 0, math.huge } do
			expect(function()
				Assert.intInRange(value, 1, 24, "slot")
			end).toThrow("slot must be a whole number from 1 to 24")
		end
	end)

	it("checks blame the caller, not Assert", function()
		local ok, problem = pcall(function()
			Assert.that(false, "blame me")
		end)
		expect(ok).toBe(false)
		expect(string.find(tostring(problem), "Assert.spec", 1, true) ~= nil).toBe(true)
	end)

	it("that, finite and intInRange do nothing while disabled", function()
		disabled(function()
			Assert.that(false, "skipped")
			Assert.finite(0 / 0, "x")
			Assert.intInRange(99, 1, 24, "slot")
		end)
	end)

	it("fail always throws, even while disabled", function()
		expect(function()
			Assert.fail("unreachable branch")
		end).toThrow("unreachable branch")
		disabled(function()
			expect(function()
				Assert.fail("unreachable branch")
			end).toThrow("unreachable branch")
		end)
	end)
end)
