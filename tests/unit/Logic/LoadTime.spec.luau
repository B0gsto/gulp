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
end)
