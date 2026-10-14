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
