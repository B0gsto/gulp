--!strict
local Index = require("../../../src/shared/Data/Index")
local TestKit = require("../../../src/shared/Util/TestKit")
local TraitRules = require("../../../src/shared/Logic/TraitRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("TraitRules: effects (canon 9, 02 §8.4, §8.5)", function()
	it("has", function()
		expect(TraitRules.has({ "glow", "spiny" }, "spiny")).toBe(true)
		expect(TraitRules.has({ "glow" }, "spiny")).toBe(false)
		expect(TraitRules.has({}, "glow")).toBe(false)
	end)

	it("sums rarity income bonuses exactly, from the data", function()
		for _, def in Index.Traits.list do
			expect(TraitRules.incomeBonus({ def.id })).toBe(def.incomeBonus)
		end
		expect(TraitRules.incomeBonus({ "spots", "plated" })).toBe(0.3)
		expect(TraitRules.incomeBonus({ "stripes", "spiny", "ink" })).toBe(0.65)
		expect(TraitRules.incomeBonus({ "moonlit", "bonefed", "crystal" })).toBe(2.6)
		expect(TraitRules.incomeBonus({ "nothing" })).toBe(0)
		expect(TraitRules.incomeBonus({})).toBe(0)
	end)

	it("Stripes: swim speed ×1.08", function()
		expect(TraitRules.speedMult({ "stripes" })).toBe(1.08)
		expect(TraitRules.speedMult({ "spots" })).toBe(1)
	end)

	it("Spots on prey only, Bonefed on everything, and they add", function()
		expect(TraitRules.massMult({}, "prey")).toBe(1)
		expect(TraitRules.massMult({ "spots" }, "prey")).toBeCloseTo(1.10, 1e-9)
		expect(TraitRules.massMult({ "spots" }, "player")).toBe(1)
		expect(TraitRules.massMult({ "spots" }, "predator")).toBe(1)
		expect(TraitRules.massMult({ "bonefed" }, "player")).toBe(1.25)
		expect(TraitRules.massMult({ "bonefed" }, "predator")).toBe(1.25)
		expect(TraitRules.massMult({ "spots", "bonefed" }, "prey")).toBeCloseTo(1.35, 1e-9)
		expect(TraitRules.massMult({ "spots", "bonefed" }, "player")).toBe(1.25)
	end)

	it("Spiny: +1 defence tier; Longfin: +30% dash; Crystal: ×1.5 bank", function()
		expect(TraitRules.defenceTierBonus({ "spiny" })).toBe(1)
		expect(TraitRules.defenceTierBonus({ "plated" })).toBe(0)
		expect(TraitRules.dashLengthAdd({ "longfin" })).toBe(0.3)
		expect(TraitRules.dashLengthAdd({})).toBe(0)
		expect(TraitRules.bankMult({ "crystal" })).toBe(1.5)
		expect(TraitRules.bankMult({ "glow" })).toBe(1)
	end)

	it("Plated saves once per run", function()
		expect(TraitRules.platedAvailable({ "plated" }, false)).toBe(true)
		expect(TraitRules.platedAvailable({ "plated" }, true)).toBe(false)
		expect(TraitRules.platedAvailable({ "spiny" }, false)).toBe(false)
	end)
end)

describe("TraitRules: pips, slots and shedding (02 §8.1 to §8.3)", function()
	it("needs 5 pips, 4 with Keen Nose", function()
		expect(TraitRules.pipsNeeded(false)).toBe(5)
		expect(TraitRules.pipsNeeded(true)).toBe(4)
	end)

	it("gains a trait on the fifth pip and clears its pips", function()
		local traits, pips = {}, {}
		for n = 1, 4 do
			expect((TraitRules.eatTraitPrey(traits, pips, "glow", false))).toBe("pip")
			expect(pips.glow).toBe(n)
		end
		local result, slot = TraitRules.eatTraitPrey(traits, pips, "glow", false)
		expect(result).toBe("gained")
		expect(slot).toBe(1)
		expect(traits).toEqual({ "glow" })
		expect(pips.glow).toBe(nil)
		expect((TraitRules.eatTraitPrey(traits, pips, "glow", false))).toBe("held")
	end)

	it("gains on the fourth pip with Keen Nose", function()
		local traits, pips = { "glow" }, { spots = 3 }
		local result, slot = TraitRules.eatTraitPrey(traits, pips, "spots", true)
		expect(result).toBe("gained")
		expect(slot).toBe(2)
	end)

	it("gives no pips while all three slots are full, and keeps the frozen pips", function()
		local traits, pips = { "glow", "spots", "spiny" }, { ink = 2 }
		expect((TraitRules.eatTraitPrey(traits, pips, "ink", false))).toBe("full")
		expect(pips.ink).toBe(2)
		expect((TraitRules.eatTraitPrey(traits, pips, "nothing", false))).toBe("unknown")
	end)

	it("sheds at once, resets the pips, and the trait can be regained from 0", function()
		local traits, pips = { "glow", "spots", "spiny" }, { ink = 4 }
		local ok, reason = TraitRules.shed(traits, pips, 2, "Swimming")
		expect(ok).toBe(true)
		expect(reason).toBe(nil)
		expect(traits).toEqual({ "glow", "spiny" })
		-- Frozen pips continue after the shed.
		expect((TraitRules.eatTraitPrey(traits, pips, "ink", false))).toBe("gained")
		expect(traits).toEqual({ "glow", "spiny", "ink" })
		TraitRules.shed(traits, pips, 3, "Swimming")
		expect((TraitRules.eatTraitPrey(traits, pips, "ink", false))).toBe("pip")
		expect(pips.ink).toBe(1)
	end)

	it("refuses a shed in a blocked state or on an empty slot", function()
		for _, state in { "Stunned", "Hooked", "Transit", "Banking", "Gulped" } do
			expect(TraitRules.canShed(state)).toBe(false)
			local traits = { "glow" }
			local ok, reason = TraitRules.shed(traits, {}, 1, state)
			expect(ok).toBe(false)
			expect(reason).toBe("state")
			expect(#traits).toBe(1)
		end
		for _, state in { "Swimming", "Airborne", "InCove" } do
			expect(TraitRules.canShed(state)).toBe(true)
		end
		local ok, reason = TraitRules.shed({ "glow" }, {}, 2, "Swimming")
		expect(ok).toBe(false)
		expect(reason).toBe("empty")
	end)

	it("grants traits at 4 pips when Keen Nose is bought mid-run, while slots are free", function()
		local traits, pips = { "glow" }, { spots = 4, ink = 4, plated = 3, moonlit = 4 }
		local granted = TraitRules.grantReady(traits, pips)
		expect(granted).toEqual({ "spots", "ink" })
		expect(traits).toEqual({ "glow", "spots", "ink" })
		expect(pips.moonlit).toBe(4) -- no slot left: kept
		expect(pips.plated).toBe(3)
		expect(TraitRules.grantReady({}, {})).toEqual({})
	end)
end)

describe("TraitRules: progress from the first pip to the slot (02 §8.1, §8.2)", function()
	it("takes five trait prey, or four with Keen Nose, and fills the next slot", function()
		local traits, pips = {}, {}
		for n = 1, 4 do
			expect((TraitRules.eatTraitPrey(traits, pips, "glow", false))).toBe("pip")
			expect(pips.glow).toBe(n)
		end
		local result, index = TraitRules.eatTraitPrey(traits, pips, "glow", false)
		expect(result).toBe("gained")
		expect(index).toBe(1)
		expect(pips.glow).toBe(nil)
		expect((TraitRules.eatTraitPrey(traits, pips, "glow", false))).toBe("held")
		local keen = {}
		for _ = 1, 3 do
			TraitRules.eatTraitPrey(traits, keen, "spots", true)
		end
		local r2, i2 = TraitRules.eatTraitPrey(traits, keen, "spots", true)
		expect(r2).toBe("gained")
		expect(i2).toBe(2)
	end)

	it("activates the effect 0.5 s after the last pip", function()
		expect(TraitRules.ACTIVATE_DELAY).toBe(0.5)
		expect(TraitRules.isActive(10, 10.49)).toBe(false)
		expect(TraitRules.isActive(10, 10.5)).toBe(true)
	end)
end)

describe("TraitRules: the Traits attribute (09 §5.3)", function()
	it("joins and splits comma-joined IDs", function()
		expect(TraitRules.joinIds({})).toBe("")
		expect(TraitRules.joinIds({ "glow", "spiny" })).toBe("glow,spiny")
		expect(TraitRules.splitIds("glow,spiny")).toEqual({ "glow", "spiny" })
		expect(TraitRules.splitIds("")).toEqual({})
		expect(TraitRules.splitIds(nil)).toEqual({})
		expect(TraitRules.splitIds(7)).toEqual({})
	end)

	it("keeps known IDs only, no duplicates, three at most", function()
		expect(TraitRules.splitIds("glow,,nothing,glow,spots")).toEqual({ "glow", "spots" })
		expect(TraitRules.splitIds("glow,spots,spiny,ink")).toEqual({ "glow", "spots", "spiny" })
	end)
end)

describe("TraitRules.slotView (08 §3.6)", function()
	it("shows three empty slots with no traits and no pips", function()
		local views = TraitRules.slotView({}, {}, {}, false)
		expect(#views).toBe(3)
		for _, v in views do
			expect(v.state).toBe("empty")
			expect(v.needed).toBe(5)
		end
	end)

	it("fills owned slots first, then the most-pipped in-progress traits", function()
		local views = TraitRules.slotView(
			{ "glow" },
			{ spots = 2, ink = 3, plated = 1 },
			{ spots = 4, ink = 2, plated = 9 },
			false
		)
		expect(views[1].state).toBe("owned")
		expect(views[1].traitId).toBe("glow")
		expect(views[1].pips).toBe(0)
		expect(views[2].state).toBe("progress")
		expect(views[2].traitId).toBe("ink")
		expect(views[2].pips).toBe(3)
		expect(views[3].traitId).toBe("spots")
	end)

	it("breaks pip ties by the most recent pip, then canon order", function()
		local recent = TraitRules.slotView(
			{},
			{ spots = 2, stripes = 2 },
			{ spots = 5, stripes = 3 },
			false
		)
		expect(recent[1].traitId).toBe("spots")
		expect(recent[2].traitId).toBe("stripes")
		expect(recent[3].state).toBe("empty")
		local canon = TraitRules.slotView({}, { spots = 2, stripes = 2 }, {}, false)
		expect(canon[1].traitId).toBe("stripes") -- wire 2 before wire 3
	end)

	it("hides progress on held traits, caps pips, and shows four pips with Keen Nose", function()
		local views = TraitRules.slotView({ "glow" }, { glow = 2, spots = 9 }, {}, true)
		expect(views[2].traitId).toBe("spots")
		expect(views[2].pips).toBe(4)
		expect(views[2].needed).toBe(4)
		expect(views[3].state).toBe("empty")
	end)

	it("shows only owned slots when all three are full", function()
		local held = { "glow", "spots", "spiny" }
		local views = TraitRules.slotView(held, { ink = 3 }, {}, false)
		for i, v in views do
			expect(v.state).toBe("owned")
			expect(v.traitId).toBe(held[i])
		end
	end)
end)

describe("TraitRules.pickMarkers (02 §8.4 Glow)", function()
	it("sorts nearest first and draws six at most", function()
		expect(TraitRules.GLOW_RADIUS).toBe(60)
		expect(TraitRules.GLOW_MARKERS).toBe(6)
		expect(TraitRules.GLOW_LIGHT).toBe(20)
		local list: { TraitRules.MarkerCandidate } = {}
		for _, d in { 50, 10, 40, 20, 30, 5, 59, 1 } do
			table.insert(list, { traitId = "glow", distance = d })
		end
		local n = TraitRules.pickMarkers(list)
		expect(n).toBe(6)
		local seen = {}
		for i = 1, n do
			table.insert(seen, list[i].distance)
		end
		expect(seen).toEqual({ 1, 5, 10, 20, 30, 40 })
		expect(TraitRules.pickMarkers({}, 6)).toBe(0)
		expect(TraitRules.pickMarkers({ { traitId = "ink", distance = 3 } }, 4)).toBe(1)
	end)
end)

describe("TraitRules: the activation delay on a reader's clock (02 §8.2)", function()
	local D = TraitRules.ACTIVATE_DELAY

	it(
		"activeOf keeps the traits past the delay, in order; a trait with no time is active",
		function()
			local at = { glow = 10, stripes = 9.75 }
			expect(TraitRules.activeOf({ "stripes", "glow" }, at, 10)).toEqual({})
			expect(TraitRules.activeOf({ "stripes", "glow" }, at, 9.75 + D)).toEqual({ "stripes" })
			expect(TraitRules.activeOf({ "stripes", "glow" }, at, 10 + D)).toEqual({
				"stripes",
				"glow",
			})
			expect(TraitRules.activeOf({ "spiny" }, at, 0)).toEqual({ "spiny" })
		end
	)

	it("noteHeld: a trait held at the first read is active at once", function()
		local seen = {}
		expect(TraitRules.noteHeld(seen, { "glow", "stripes" }, 100, true)).toBe(nil)
		expect(TraitRules.activeOf({ "glow", "stripes" }, seen, 100)).toEqual({ "glow", "stripes" })
	end)

	it("noteHeld: a gain heard later waits the delay, and says how long", function()
		local seen = {}
		expect(TraitRules.noteHeld(seen, {}, 100, true)).toBe(nil)
		expect(TraitRules.noteHeld(seen, { "stripes" }, 101, false)).toBe(D)
		expect(TraitRules.speedMult(TraitRules.activeOf({ "stripes" }, seen, 101))).toBe(1)
		-- A later read keeps the first time and counts down from it.
		expect(TraitRules.noteHeld(seen, { "stripes" }, 101 + D / 2, false)).toBeCloseTo(
			D / 2,
			1e-9
		)
		expect(TraitRules.noteHeld(seen, { "stripes" }, 101 + D, false)).toBe(nil)
		expect(TraitRules.speedMult(TraitRules.activeOf({ "stripes" }, seen, 101 + D))).toBe(
			TraitRules.STRIPES_SPEED
		)
	end)

	it("noteHeld: a shed drops at once, and a regain starts the delay again", function()
		local seen = {}
		TraitRules.noteHeld(seen, { "glow" }, 0, true)
		TraitRules.noteHeld(seen, {}, 5, false)
		expect(seen.glow).toBe(nil)
		expect(TraitRules.noteHeld(seen, { "glow" }, 6, false)).toBe(D)
		expect(TraitRules.has(TraitRules.activeOf({ "glow" }, seen, 6), "glow")).toBe(false)
	end)

	it("noteHeld returns the soonest of several pending traits", function()
		local seen = {}
		TraitRules.noteHeld(seen, {}, 0, true)
		TraitRules.noteHeld(seen, { "glow" }, 10, false)
		expect(TraitRules.noteHeld(seen, { "glow", "spiny" }, 10 + D / 4, false)).toBeCloseTo(
			D * 3 / 4,
			1e-9
		)
	end)
end)
