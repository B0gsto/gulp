--!strict
local BankMath = require("../../../src/shared/Logic/BankMath")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("BankMath (canon 5.4, 5.5; 05 §3.1, §3.2; 09 §13.4)", function()
	it("matches every row of 05 §3.1's table", function()
		-- mass, base, crystal, deep pockets, both
		local rows = {
			{ 10, 30, 45, 60, 90 },
			{ 30, 90, 135, 180, 270 },
			{ 80, 240, 360, 480, 720 },
			{ 200, 600, 900, 1200, 1800 },
			{ 500, 1500, 2250, 3000, 4500 },
			{ 1200, 3600, 5400, 7200, 10800 },
			{ 2000, 4400, 6600, 8800, 13200 },
			{ 3000, 5400, 8100, 10800, 16200 },
			{ 9999, 5400, 8100, 10800, 16200 },
		}
		for _, r in rows do
			expect(BankMath.base(r[1])).toBe(r[2])
			expect(BankMath.bank(r[1], false, false)).toBe(r[2])
			expect(BankMath.bank(r[1], true, false)).toBe(r[3])
			expect(BankMath.bank(r[1], false, true)).toBe(r[4])
			expect(BankMath.bank(r[1], true, true)).toBe(r[5])
		end
	end)

	it("rounds down decimal mass and pays nothing for no mass", function()
		expect(BankMath.base(10.5)).toBe(31.5)
		expect(BankMath.bank(10.5, true, false)).toBe(47) -- 47.25
		expect(BankMath.base(0)).toBe(0)
		expect(BankMath.base(-4)).toBe(0)
	end)

	it(
		"pays scraps at 50% for the first three deaths, then 10% (05 §3.2 worked example)",
		function()
			expect(BankMath.scrapsRate(0)).toBe(0.5)
			expect(BankMath.scrapsRate(2)).toBe(0.5)
			expect(BankMath.scrapsRate(3)).toBe(0.1)
			expect(BankMath.scraps(88, false, false, 5)).toBe(26) -- would have banked 264
			expect(BankMath.scraps(88, false, false, 0)).toBe(132)
			expect(BankMath.scraps(200, true, true, 3)).toBe(180) -- Crystal and Deep Pockets count
		end
	)

	it("counts rank points without Deep Pockets (canon 11)", function()
		expect(BankMath.bankRankPoints(200, false)).toBe(600)
		expect(BankMath.bankRankPoints(200, true)).toBe(900)
		expect(BankMath.scrapsRankPoints(88, false, 5)).toBe(26)
		expect(BankMath.scrapsRankPoints(200, true, 0)).toBe(450)
	end)

	it("arms a run at mass 1 and keeps a specimen from tier 2", function()
		expect(BankMath.armed(0.9)).toBe(false)
		expect(BankMath.armed(1)).toBe(true)
		expect(BankMath.keepsSpecimen(1)).toBe(false)
		expect(BankMath.keepsSpecimen(2)).toBe(true)
		expect(BankMath.keepsSpecimen(7)).toBe(true)
	end)
	it("splits a bank by its 10 §5.1 SKUs, adding up to the bank", function()
		for _, mass in { 1, 12.3, 200, 1200, 2000.7, 3000, 9999 } do
			for _, crystal in { false, true } do
				for _, deep in { false, true } do
					local p = BankMath.parts(mass, crystal, deep)
					expect(p.base + p.crystal + p.deepPockets).toBe(
						BankMath.bank(mass, crystal, deep)
					)
					expect(p.base).toBe(math.floor(BankMath.base(mass)))
					if not crystal then
						expect(p.crystal).toBe(0)
					end
					if not deep then
						expect(p.deepPockets).toBe(0)
					end
				end
			end
		end
		-- The Sprint 5 acceptance: a tier 2 Minnow of 12 mass banks 12 × 3 Pearls.
		expect(BankMath.parts(12, false, false).base).toBe(36)
		expect(BankMath.bankSku(2)).toBe("bank_t2")
		expect(BankMath.bankSku(9)).toBe("bank_t7")
		expect(BankMath.scrapsSku(0)).toBe("scraps_50")
		expect(BankMath.scrapsSku(2)).toBe("scraps_50")
		expect(BankMath.scrapsSku(3)).toBe("scraps_10")
	end)
end)
