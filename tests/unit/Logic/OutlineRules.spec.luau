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
		expect(#shown).toBe(3)
		expect(shown[1] and shown[2] and shown[3]).toBe(true)
	end)

	-- Many candidates at shuffled distances: candidate i is i studs away, kinds alternate in
	-- runs so both colours compete for the nearest places.
	local function crowd(n: number): ({ OutlineRules.Kind }, { number })
		local kinds: { OutlineRules.Kind } = {}
		local distances: { number } = {}
		for i = 1, n do
			local slot = (i * 37) % n + 1 -- a permutation of 1..n for n = 60
			kinds[i] = if slot % 3 == 0
				then "dangerous"
				elseif slot % 7 == 0 then "none"
				else "edible"
			distances[i] = slot
		end
		return kinds, distances
	end

	local function tally(kinds: { OutlineRules.Kind }, shown: { boolean }): (number, number, number)
		local edible, dangerous, none = 0, 0, 0
		for i, on in shown do
			if on then
				if kinds[i] == "edible" then
					edible += 1
				elseif kinds[i] == "dangerous" then
					dangerous += 1
				else
					none += 1
				end
			end
		end
		return edible, dangerous, none
	end

	it("never shows more than 20 edible and 10 dangerous, nor any 'none'", function()
		local kinds, distances = crowd(60)
		local order, shown = {}, {}
		local capE, capD = OutlineRules.CAP.edible, OutlineRules.CAP.dangerous
		OutlineRules.select(kinds, distances, 60, capE, capD, order, shown)
		local edible, dangerous, none = tally(kinds, shown)
		expect(edible).toBe(20)
		expect(dangerous).toBe(10)
		expect(none).toBe(0)
	end)

	it("uses the Smooth caps, 8 and 4 (15 §3.0)", function()
		local kinds, distances = crowd(60)
		local order, shown = {}, {}
		local capE, capD = OutlineRules.CAP_SMOOTH.edible, OutlineRules.CAP_SMOOTH.dangerous
		OutlineRules.select(kinds, distances, 60, capE, capD, order, shown)
		local edible, dangerous = tally(kinds, shown)
		expect(edible).toBe(8)
		expect(dangerous).toBe(4)
	end)

	it(
		"keeps the nearest: every shown one is closer than every hidden one of its colour",
		function()
			local kinds, distances = crowd(60)
			local order, shown = {}, {}
			OutlineRules.select(kinds, distances, 60, 20, 10, order, shown)
			for _, kind in { "edible", "dangerous" } do
				local farthestShown, nearestHidden = -math.huge, math.huge
				for i = 1, 60 do
					if kinds[i] == kind then
						if shown[i] then
							farthestShown = math.max(farthestShown, distances[i])
						else
							nearestHidden = math.min(nearestHidden, distances[i])
						end
					end
				end
				expect(farthestShown < nearestHidden).toBe(true)
			end
		end
	)

	it("keeps each colour's cap its own: a full edible cap never blocks red", function()
		local kinds: { OutlineRules.Kind } = { "edible", "edible", "edible", "dangerous" }
		local distances = { 1, 2, 3, 100 }
		local order, shown = {}, {}
		OutlineRules.select(kinds, distances, 4, 2, 1, order, shown)
		expect(shown).toEqual({ true, true, false, true })
	end)

	it("shows nothing with zero caps or no candidates", function()
		local kinds, distances = crowd(60)
		local order, shown = {}, {}
		OutlineRules.select(kinds, distances, 60, 0, 0, order, shown)
		local edible, dangerous = tally(kinds, shown)
		expect(edible + dangerous).toBe(0)
		OutlineRules.select(kinds, distances, 0, 20, 10, order, shown)
		expect(#order).toBe(0)
		expect(#shown).toBe(0)
	end)
end)
