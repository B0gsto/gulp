--!strict
local PolicyRules = require("../../../src/shared/Logic/PolicyRules")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("PolicyRules (09 §18.2)", function()
	it("reads a failed call as the most restrictive value of every field", function()
		local p = PolicyRules.from(false, "HTTP 500")
		expect(p).toBe(PolicyRules.MOST_RESTRICTIVE)
		expect(p.ArePaidRandomItemsRestricted).toBe(true)
		expect(p.IsPaidItemTradingAllowed).toBe(false)
		expect(p.AreAdsAllowed).toBe(false)
		expect(p.IsEligibleToPurchaseSubscription).toBe(false)
		expect(p.IsSubjectToChinaPolicies).toBe(true)
		expect(p.IsContentSharingAllowed).toBe(false)
		expect(p.AllowedExternalLinkReferences).toEqual({})
		expect(PolicyRules.from(true, nil)).toBe(PolicyRules.MOST_RESTRICTIVE)
	end)

	it("keeps an answer's fields", function()
		local p = PolicyRules.from(true, {
			ArePaidRandomItemsRestricted = false,
			IsPaidItemTradingAllowed = true,
			AreAdsAllowed = true,
			IsEligibleToPurchaseSubscription = true,
			IsSubjectToChinaPolicies = false,
			IsContentSharingAllowed = true,
			AllowedExternalLinkReferences = { "Discord", "YouTube" },
		})
		expect(p.ArePaidRandomItemsRestricted).toBe(false)
		expect(p.IsPaidItemTradingAllowed).toBe(true)
		expect(p.AreAdsAllowed).toBe(true)
		expect(p.IsEligibleToPurchaseSubscription).toBe(true)
		expect(p.IsSubjectToChinaPolicies).toBe(false)
		expect(p.IsContentSharingAllowed).toBe(true)
		expect(p.AllowedExternalLinkReferences).toEqual({ "Discord", "YouTube" })
	end)

	it("falls back per field when one is missing or of the wrong type", function()
		local p = PolicyRules.from(true, {
			AreAdsAllowed = true,
			IsSubjectToChinaPolicies = "no",
			AllowedExternalLinkReferences = { "Discord", 7 },
		})
		expect(p.AreAdsAllowed).toBe(true)
		expect(p.IsSubjectToChinaPolicies).toBe(true)
		expect(p.ArePaidRandomItemsRestricted).toBe(true)
		expect(p.IsContentSharingAllowed).toBe(false)
		expect(p.AllowedExternalLinkReferences).toEqual({ "Discord" })
	end)
end)
