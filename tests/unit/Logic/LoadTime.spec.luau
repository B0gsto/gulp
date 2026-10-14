--!strict
local AnalyticsRules = require("../../../src/shared/Logic/AnalyticsRules")
local LoadTime = require("../../../src/shared/Logic/LoadTime")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("LoadTime", function()
	it("buckets J at control as 10 §4.2 does, edges included in the lower bucket", function()
		expect(LoadTime.bucket(0)).toBe("le5")
		expect(LoadTime.bucket(5)).toBe("le5")
		expect(LoadTime.bucket(5.01)).toBe("le10")
		expect(LoadTime.bucket(10)).toBe("le10")
		expect(LoadTime.bucket(19.9)).toBe("le20")
		expect(LoadTime.bucket(20)).toBe("le20")
		expect(LoadTime.bucket(20.1)).toBe("gt20")
		expect(LoadTime.bucket(300)).toBe("gt20")
	end)

	it("rounds the value to a tenth and never reports a negative time", function()
		expect(LoadTime.value(4.26)).toBe(4.3)
		expect(LoadTime.value(4.24)).toBe(4.2)
		expect(LoadTime.value(-1)).toBe(0)
	end)

	it("every bucket and value passes the event dictionary", function()
		for _, j in { 0, 3.5, 7, 15, 45 } do
			local ok, why =
				AnalyticsRules.checkEvent("sys_load_time", LoadTime.value(j), LoadTime.bucket(j))
			expect(ok).toBe(true)
			expect(why).toBe(nil)
		end
	end)

	it("codes the loading screen's mode for ClientReady and names its fail-safe", function()
		expect(LoadTime.modeCode("full")).toBe(1)
		expect(LoadTime.modeCode("partial")).toBe(2)
		expect(LoadTime.modeCode("minimal")).toBe(3)
		expect(LoadTime.modeCode(nil)).toBe(1) -- no loading screen: nothing was cut
		expect(LoadTime.modeCode("odd")).toBe(1)
		expect(LoadTime.failsafe(1)).toBe(nil)
		expect(LoadTime.failsafe(2)).toBe("load_partial")
		expect(LoadTime.failsafe(3)).toBe("load_minimal")
		for code = LoadTime.MODE_MIN, LoadTime.MODE_MAX do
			local ctx = LoadTime.failsafe(code)
			if ctx then
				expect((AnalyticsRules.checkEvent("ftue_failsafe", 8, ctx))).toBe(true)
			end
		end
	end)
end)
