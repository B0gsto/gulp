--!strict
local HudMath = require("../../../src/shared/Logic/HudMath")
local Index = require("../../../src/shared/Data/Index")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("HudMath.short (docs/08 section 3.4)", function()
	it("shows whole numbers up to 9,999", function()
		expect(select(1, HudMath.short(86.7))).toBe("86")
		expect(select(1, HudMath.short(9999))).toBe("9999")
		expect(select(2, HudMath.short(9999))).toBe("plain")
	end)
	it("shows 12.4K above 9,999 and never rounds up", function()
		local text, kind = HudMath.short(12_499)
		expect(text).toBe("12.4")
		expect(kind).toBe("thousand")
		expect(select(1, HudMath.short(10_000))).toBe("10")
		expect(select(1, HudMath.short(999_999))).toBe("999.9")
		local m, mk = HudMath.short(1_250_000)
		expect(m).toBe("1.2")
		expect(mk).toBe("million")
	end)
end)

describe("HudMath.massBar (docs/08 section 3.4)", function()
	local tiers = Index.Tiers.list
	it("fills from this tier's threshold to the next", function()
		local from, to = tiers[2].massNeeded, tiers[3].massNeeded
		local bar = HudMath.massBar((from + to) / 2)
		expect(bar.tier).toBe(2)
		expect(bar.nextTier).toBe(3)
		expect(bar.fill).toBeCloseTo(0.5, 1e-9)
		expect(bar.toGo).toBe(math.ceil(to - (from + to) / 2))
		expect(bar.near).toBe(false)
	end)
	it("is near at 85%", function()
		local from, to = tiers[1].massNeeded, tiers[2].massNeeded
		expect(HudMath.massBar(from + 0.85 * (to - from)).near).toBe(true)
	end)
	it("is full and max at the top tier", function()
		local bar = HudMath.massBar(tiers[#tiers].massNeeded + 500)
		expect(bar.max).toBe(true)
		expect(bar.fill).toBe(1)
		expect(bar.nextTier).toBe(nil)
	end)
end)

describe("HudMath.homeDistance (docs/08 section 3.12)", function()
	it("rounds to 5", function()
		expect(HudMath.homeDistance(122)).toBe(120)
		expect(HudMath.homeDistance(122.5)).toBe(125)
		expect(HudMath.homeDistance(2)).toBe(0)
	end)
end)

describe("HudMath.pushPop (docs/08 section 3.16)", function()
	it("merges fast bites into one number", function()
		local pops = {}
		HudMath.pushPop(pops, 0, 4)
		HudMath.pushPop(pops, 0.1, 3)
		expect(#pops).toBe(1)
		expect(pops[1].amount).toBe(7)
	end)
	it("keeps at most 4 and drops expired ones", function()
		local pops = {}
		for i = 0, 5 do
			HudMath.pushPop(pops, i * 0.2, 1)
		end
		expect(#pops <= 4).toBe(true)
		HudMath.pushPop(pops, 10, 2)
		expect(#pops).toBe(1)
	end)
	it("stacks live pops so none overlaps the next", function()
		local gap = HudMath.POP_GAP
		-- a bite just after another: the older pop is pushed up, the newest stays at the mouth
		local ys = HudMath.popStack({ 100, 110 })
		expect(ys[2]).toBe(110)
		expect(ys[1]).toBe(110 - gap)
		-- already far enough apart: unchanged
		local apart = HudMath.popStack({ 40, 100 })
		expect(apart[1]).toBe(40)
		-- a chain of four keeps every neighbour `gap` apart
		local four = HudMath.popStack({ 100, 100, 100, 100 })
		for i = 1, 3 do
			expect(four[i + 1] - four[i] >= gap).toBe(true)
		end
		expect(#HudMath.popStack({})).toBe(0)
	end)
	it("rises 48 rpx and fades out over its life", function()
		local rise, fade = HudMath.popPose(0.5)
		expect(rise).toBeCloseTo(48, 1e-9)
		expect(fade).toBeCloseTo(1, 1e-9)
		local r0, f0 = HudMath.popPose(0)
		expect(r0).toBe(0)
		expect(f0).toBe(0)
	end)
end)

describe("HudMath.grouped (docs/08 section 5.1)", function()
	it("groups thousands and rounds down", function()
		expect(HudMath.grouped(0)).toBe("0")
		expect(HudMath.grouped(999.9)).toBe("999")
		expect(HudMath.grouped(1000)).toBe("1,000")
		expect(HudMath.grouped(12_480)).toBe("12,480")
		expect(HudMath.grouped(123_456)).toBe("123,456")
		expect(HudMath.grouped(1_234_567)).toBe("1,234,567")
		expect(HudMath.grouped(-5)).toBe("0")
	end)
end)

describe("HudMath.newFood (docs/08 section 4.2)", function()
	it("lists the prey that became edible, regular prey first, at most three", function()
		local food = HudMath.newFood(1, 2)
		expect(#food).toBe(3)
		expect(food[1]).toBe("sardine")
		for _, id in food do
			local def = Index.Prey.byId[id] or Index.TraitPrey.byId[id]
			expect(def ~= nil and def.tier == 2).toBe(true)
		end
	end)
	it("covers every tier passed on a jump of two", function()
		local food = HudMath.newFood(2, 4)
		expect(food[1]).toBe("darter")
		expect(food[2]).toBe("mackerel")
	end)
	it("leaves out [L] and event-only prey, and is empty when nothing new is edible", function()
		for from = 0, 6 do
			for _, id in HudMath.newFood(from, from + 1) do
				local def = Index.Prey.byId[id] or Index.TraitPrey.byId[id]
				expect(def.scope).toBe("MVP")
				expect(def.eventOnly).toBe(nil)
			end
		end
		expect(#HudMath.newFood(6, 7)).toBe(0)
		expect(#HudMath.newFood(3, 3)).toBe(0)
	end)
end)
