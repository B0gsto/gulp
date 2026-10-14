--!strict
local CoveIncome = require("../../../src/shared/Logic/CoveIncome")
local CoveRules = require("../../../src/shared/Logic/CoveRules")
local TestKit = require("../../../src/shared/Util/TestKit")
local Types = require("../../../src/shared/Types")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local HOUR = 3600
local T0 = 1_800_000_000
local CAP = CoveIncome.CAP_HOURS

local function cove(): CoveRules.Cove
	return { slots = 6, specimens = {}, pending = 0, accruedAt = 0, bubbles = 0 }
end

local function specimen(id: string, tier: number, traits: { string }?): Types.SpecimenRecord
	return { id = id, sp = "minnow", tier = tier, mass = 120.5, traits = traits or {}, at = T0 }
end

describe("CoveRules specimens", function()
	it("fills the free slots, then keeps the new one waiting, then refuses", function()
		local c = cove()
		for i = 1, 6 do
			expect(CoveRules.add(c, specimen(`s{i}`, 2), T0, 6, CAP)).toBe("added")
		end
		expect(#c.specimens).toBe(6)
		expect(CoveRules.add(c, specimen("new", 3), T0, 6, CAP)).toBe("full")
		expect((c.pendingSpecimen :: Types.SpecimenRecord).id).toBe("new")
		expect(CoveRules.add(c, specimen("again", 3), T0, 6, CAP)).toBe("refused")
		expect(#c.specimens).toBe(6)
	end)

	it("refuses tier 1, a duplicate ID and four traits", function()
		local c = cove()
		expect(CoveRules.add(c, specimen("a", 1), T0, 6, CAP)).toBe("refused")
		expect(CoveRules.add(c, specimen("a", 2), T0, 6, CAP)).toBe("added")
		expect(CoveRules.add(c, specimen("a", 2), T0, 6, CAP)).toBe("refused")
		local traits = { "glow", "spots", "stripes", "plated" }
		expect(CoveRules.add(c, specimen("b", 2, traits), T0, 6, CAP)).toBe("refused")
	end)

	it("writes lastClaim when the first specimen arrives, and earns nothing before it", function()
		local c = cove()
		expect(c.lastClaim).toBe(nil)
		CoveRules.add(c, specimen("a", 3), T0, 6, CAP)
		expect((c.lastClaim :: any).at).toBe(T0)
		expect((c.lastClaim :: any).amount).toBe(0)
		expect(c.pending).toBe(0)
		expect(c.accruedAt).toBe(T0)
	end)

	it("releases the new one or an old one; the waiting one takes the freed slot", function()
		local c = cove()
		for i = 1, 6 do
			CoveRules.add(c, specimen(`s{i}`, 2), T0, 6, CAP)
		end
		CoveRules.add(c, specimen("new", 5, { "spots", "plated" }), T0, 6, CAP)
		-- Releasing an old tier 2 pays max(5, floor(6)) = 6; the new one moves into slot 3.
		expect(CoveRules.release(c, "s3", T0 + 60, CAP)).toBe(6)
		expect(c.specimens[3].id).toBe("new")
		expect(c.pendingSpecimen).toBe(nil)
		-- 05 §3.10: a tier 5 with Spots and Plated refunds 39.
		expect(CoveRules.release(c, "new", T0 + 60, CAP)).toBe(39)
		expect(#c.specimens).toBe(5)
		expect(CoveRules.release(c, "nope", T0 + 60, CAP)).toBe(nil)
		-- The waiting one itself can be released.
		CoveRules.add(c, specimen("x", 2), T0, 6, CAP)
		CoveRules.add(c, specimen("y", 2), T0, 6, CAP)
		expect(CoveRules.release(c, "y", T0, CAP)).toBe(6)
		expect(c.pendingSpecimen).toBe(nil)
		expect(#c.specimens).toBe(6)
	end)

	it("makes 8-character IDs unique within the cove", function()
		local c = cove()
		CoveRules.add(c, specimen("aaaaaaaa", 2), T0, 6, CAP)
		local picks = { 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2 }
		local n = 0
		local id = CoveRules.newId(c, function(_: number): number
			n += 1
			return picks[n]
		end)
		expect(id).toBe("bbbbbbbb")
	end)
end)

describe("CoveRules income", function()
	it("after 10 minutes away the specimen's income matches CoveIncome to the Pearl", function()
		local c = cove()
		local rec = specimen("a", 5, { "spots", "plated" })
		CoveRules.add(c, rec, T0, 6, CAP)
		local expected = math.floor(CoveIncome.specimenRate(5, rec.traits) * 600 / HOUR)
		expect(expected).toBe(6) -- 39 Pearls/h × 1/6 h = 6.5
		expect(CoveRules.claim(c, T0 + 600, CAP)).toBe(expected)
		expect(c.pending).toBeCloseTo(0.5, 1e-9)
		expect((c.lastClaim :: any).at).toBe(T0 + 600)
		expect((c.lastClaim :: any).amount).toBe(6)
	end)

	it("stops the pile at 8 hours after the last claim, and a claim restarts the window", function()
		local c = cove()
		CoveRules.add(c, specimen("a", 3), T0, 6, CAP) -- 10 Pearls/h
		expect(CoveRules.pileAt(c, T0 + 8 * HOUR, CAP)).toBe(80)
		expect(CoveRules.pileAt(c, T0 + 30 * HOUR, CAP)).toBe(80)
		expect(CoveRules.claim(c, T0 + 30 * HOUR, CAP)).toBe(80)
		expect(CoveRules.claim(c, T0 + 31 * HOUR, CAP)).toBe(10)
		-- A clock behind the last accrual adds nothing and does not move accruedAt back.
		expect(CoveRules.claim(c, T0, CAP)).toBe(0)
		expect(c.accruedAt).toBe(T0 + 31 * HOUR)
	end)

	it("settles at the old rate before a specimen arrives or leaves", function()
		local c = cove()
		CoveRules.add(c, specimen("a", 3), T0, 6, CAP) -- 10/h
		CoveRules.add(c, specimen("b", 4), T0 + HOUR, 6, CAP) -- +18/h from now on
		expect(c.pending).toBe(10)
		CoveRules.release(c, "a", T0 + 2 * HOUR, CAP)
		expect(c.pending).toBe(38)
		expect(CoveRules.pileAt(c, T0 + 3 * HOUR, CAP)).toBe(56)
	end)
end)

describe("CoveRules slots", function()
	it("prices slots 7 to 30 from 05 §4.2 and stops at 30", function()
		local slot, price, sku = CoveRules.nextSlot(6)
		expect(slot).toBe(7)
		expect(price).toBe(1200)
		expect(sku).toBe("slots_07_12")
		expect(select(3, CoveRules.nextSlot(12))).toBe("slots_13_20")
		expect(select(3, CoveRules.nextSlot(20))).toBe("slots_21_30")
		local total = 0
		for s = 6, 29 do
			total += select(2, CoveRules.nextSlot(s)) :: number
		end
		expect(total).toBe(1019250)
		expect(CoveRules.nextSlot(30)).toBe(nil)
		expect(CoveRules.capacity(30, true)).toBe(40)
	end)

	it("a bought slot takes the waiting specimen", function()
		local c = cove()
		for i = 1, 6 do
			CoveRules.add(c, specimen(`s{i}`, 2), T0, 6, CAP)
		end
		CoveRules.add(c, specimen("new", 2), T0, 6, CAP)
		expect(CoveRules.addSlot(c, T0, CAP)).toBe(true)
		expect(c.slots).toBe(7)
		expect(#c.specimens).toBe(7)
		expect(c.pendingSpecimen).toBe(nil)
		c.slots = 30
		expect(CoveRules.addSlot(c, T0, CAP)).toBe(false)
	end)
end)

describe("CoveRules view and assignment", function()
	it("builds the CoveView table", function()
		local c = cove()
		CoveRules.add(c, specimen("a", 4, { "glow" }), T0, 6, CAP)
		local v = CoveRules.view(16, "Bob", c, 6)
		expect(v.slot).toBe(16)
		expect(v.owner).toBe("Bob")
		expect(v.slots).toBe(6)
		expect(#v.specimens).toBe(1)
		expect(v.specimens[1].tier).toBe(4)
		expect(v.specimens[1].traits[1]).toBe("glow")
	end)

	it("gives a newcomer the cove nearest the Gap: C16, C17, C15, C18", function()
		local order = CoveRules.preference(0)
		expect(#order).toBe(24)
		expect(order[1]).toBe(16)
		expect(order[2]).toBe(17)
		expect(order[3]).toBe(15)
		expect(order[4]).toBe(18)
	end)

	it(
		"gives a returning player the farthest of the 20 nearest; the closest four come last of those",
		function()
			local near = CoveRules.preference(0)
			local order = CoveRules.preference(3)
			expect(#order).toBe(24)
			expect(order[1]).toBe(near[20])
			expect(order[17]).toBe(18)
			expect(order[20]).toBe(16)
			expect(order[21]).toBe(near[21])
		end
	)
end)
