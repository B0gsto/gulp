--!strict
local OutlineRules = require("../../../src/shared/Logic/OutlineRules")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("OutlineRules.creature (canon 5.2, 02 §0.1)", function()
	it("is green one full tier up, red one full tier down, none at the same tier", function()
		expect(OutlineRules.creature(3, false, 2, false)).toBe("edible")
		expect(OutlineRules.creature(5, false, 2, false)).toBe("edible")
		expect(OutlineRules.creature(2, false, 3, false)).toBe("dangerous")
		expect(OutlineRules.creature(4, false, 4, false)).toBe("none")
	end)

	it(
		"never outlines a tier 1 player as edible, and never paints red for a tier 1 viewer",
		function()
			expect(OutlineRules.creature(7, false, 1, false)).toBe("none")
			expect(OutlineRules.creature(1, false, 7, false)).toBe("none")
		end
	)

	it("gives a shielded creature no shell and a shielded viewer no red (09 §8.8)", function()
		expect(OutlineRules.creature(5, false, 2, true)).toBe("none")
		expect(OutlineRules.creature(2, false, 5, true)).toBe("none")
		expect(OutlineRules.creature(2, true, 5, false)).toBe("none")
		expect(OutlineRules.creature(5, true, 2, false)).toBe("edible")
	end)
end)

describe("OutlineRules.prey", function()
	it("is green at the viewer's tier or lower; plankton and bait get none", function()
		expect(OutlineRules.prey(2, 2, false)).toBe("edible")
		expect(OutlineRules.prey(2, 1, false)).toBe("edible")
		expect(OutlineRules.prey(2, 3, false)).toBe("none")
		expect(OutlineRules.prey(7, 0, false)).toBe("none")
		expect(OutlineRules.prey(7, 1, true)).toBe("none")
	end)
end)

describe("OutlineRules shell look (06 §13.2)", function()
	it("uses the bible's colours", function()
		expect(OutlineRules.COLOURS.edible).toBe("#A6FF3D")
		expect(OutlineRules.COLOURS.dangerous).toBe("#FF3B4E")
		expect(OutlineRules.COLOURS_COLOURBLIND.edible).toBe("#FFF23D")
		expect(OutlineRules.COLOURS_COLOURBLIND.dangerous).toBe("#FF3DC8")
	end)

	it(
		"is 6% of body height for creatures, 10% for prey, at least 0.12, and 1.5× when red",
		function()
			expect(OutlineRules.thickness(10, "edible", false)).toBeCloseTo(0.6, 1e-9)
			expect(OutlineRules.thickness(10, "dangerous", false)).toBeCloseTo(0.9, 1e-9)
			expect(OutlineRules.thickness(10, "edible", true)).toBeCloseTo(1.0, 1e-9)
			expect(OutlineRules.thickness(0.5, "edible", false)).toBeCloseTo(0.12, 1e-9)
			-- Prey: 10% of body height, no minimum (a 0.36-stud krill gets 0.036).
			expect(OutlineRules.thickness(0.36, "edible", true)).toBeCloseTo(0.036, 1e-9)
			expect(OutlineRules.thickness(0.5, "dangerous", true)).toBeCloseTo(0.075, 1e-9)
		end
	)

	it("pulses to white twice a second", function()
		expect(OutlineRules.pulse(0)).toBeCloseTo(0, 1e-9)
		expect(OutlineRules.pulse(0.25)).toBeCloseTo(1, 1e-9)
		expect(OutlineRules.pulse(0.5)).toBeCloseTo(0, 1e-9)
	end)
end)

describe("OutlineRules.select (09 §8.8 caps)", function()
	it("keeps the nearest of each colour up to its cap", function()
		local kinds: { OutlineRules.Kind } =
			{ "edible", "edible", "dangerous", "none", "edible", "dangerous" }
		local distances = { 50, 10, 30, 1, 20, 5 }
		local order, shown = {}, {}
		OutlineRules.select(kinds, distances, #kinds, 2, 1, order, shown)
		expect(shown).toEqual({ false, true, false, false, true, true })
		-- Fewer candidates next time: stale scratch entries are dropped.
		OutlineRules.select(kinds, distances, 3, 5, 5, order, shown)
		expect(#order).toBe(3)
		expect(shown[1] and shown[2] and shown[3]).toBe(true)
	end)
end)
