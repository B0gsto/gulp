--!strict
local EconomyRules = require("../../../src/shared/Logic/EconomyRules")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("EconomyRules (09 §5.1, 10 §5)", function()
	it("lists the 16 transaction types of 10 §5 (Admin on both sides)", function()
		local names: { [string]: boolean } = {}
		for name in EconomyRules.SOURCE_SKUS do
			names[name] = true
		end
		for name in EconomyRules.SINK_SKUS do
			names[name] = true
		end
		local count = 0
		for _ in names do
			count += 1
		end
		expect(count).toBe(16)
	end)

	it(
		"stays under 100 SKUs with the 18 Pearl decorations added (10 §2.3, §5.2: 70 at launch)",
		function()
			local listed = #EconomyRules.allSkus()
			expect(listed + 18).toBe(70)
		end
	)

	it("grants a whole positive amount from a known source and SKU", function()
		expect(EconomyRules.afterGrant(100, 30, "Bank", "bank_t2")).toBe(130)
		expect(EconomyRules.afterGrant(0, 5, "CoveIncome", nil)).toBe(5)
		expect(EconomyRules.afterGrant(0, 5000, "IAP", "prod_pearls_m")).toBe(5000)
	end)

	it("refuses bad amounts, sources and SKUs", function()
		for _, amount in { 0, -5, 1.5, 0 / 0, math.huge, "5" :: any } do
			local after, why = EconomyRules.afterGrant(10, amount, "Bank", "bank_t1")
			expect(after).toBe(nil)
			expect(type(why)).toBe("string")
		end
		expect(EconomyRules.afterGrant(10, 5, "Species", "puffer")).toBe(nil) -- a sink, not a source
		expect(EconomyRules.afterGrant(10, 5, "Bank", "claim_pile")).toBe(nil)
		expect(EconomyRules.afterGrant(10, 5, "Gift", nil)).toBe(nil)
		expect(EconomyRules.afterGrant(EconomyRules.MAX_BALANCE, 1, "Admin", "admin_grant")).toBe(
			nil
		)
	end)

	it("spends only what the balance holds, on a named sink and SKU", function()
		expect(EconomyRules.afterSpend(500, 500, "Species", "puffer")).toBe(0)
		expect(EconomyRules.afterSpend(499, 500, "Species", "puffer")).toBe(nil)
		expect(EconomyRules.afterSpend(5000, 100, "CoveSlot", "slots_07_12")).toBe(4900)
		expect(EconomyRules.afterSpend(5000, 100, "Species", "minnow")).toBe(nil) -- free, never sold
		expect(EconomyRules.afterSpend(5000, 100, "CoveSlot", nil)).toBe(nil)
		expect(EconomyRules.afterSpend(5000, 100, "Bank", "bank_t1")).toBe(nil)
		expect(EconomyRules.afterSpend(5000, 0, "Admin", "admin_remove")).toBe(nil)
	end)

	it("sells only Pearl decorations under Decoration", function()
		expect(EconomyRules.afterSpend(900, 400, "Decoration", "deco_coral_arch")).toBe(500)
		expect(EconomyRules.afterSpend(900, 400, "Decoration", "deco_buy_jelly_lamp")).toBe(nil)
		expect(EconomyRules.afterSpend(900, 400, "Decoration", "deco_rank_crown")).toBe(nil)
		expect(EconomyRules.afterSpend(900, 400, "Decoration", "lamp")).toBe(nil)
	end)
end)
