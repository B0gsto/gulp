--!strict
-- 09 §16.1: every minute of an hour, slot edges, MVP fallback.
local Index = require("../../../src/shared/Data/Index")
local TestKit = require("../../../src/shared/Util/TestKit")
local TideClock = require("../../../src/shared/Logic/TideClock")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local HOUR0 = 1_760_000_400 - (1_760_000_400 % 3600) -- some UTC hour start
local FULL = { MVP = true, L = true }

-- 02 §14.1, written out independently: c = t mod 900, slot = floor(t / 900) mod 4.
local function expected(t: number, mvp: boolean): (string, string, number)
	local c = t % 900
	local slot = (t // 900) % 4
	local names = {
		[0] = "frenzy",
		[1] = "moon_tide",
		[2] = "frenzy",
		[3] = if mvp then "moon_tide" else "whale_fall",
	}
	if c < 240 then
		return "active", names[slot], t - c
	end
	return if c >= 840 then "warning" else "calm", names[(slot + 1) % 4], t - c + 900
end

describe("TideClock.at (canon 10, 02 §14.1, 09 §11.1)", function()
	it("is right at every minute of an hour, in the MVP and the full build", function()
		for minute = 0, 59 do
			local t = HOUR0 + minute * 60
			for _, mvp in { true, false } do
				local state = TideClock.at(t, if mvp then nil else { shipped = FULL })
				local phase, id, startsAt = expected(t, mvp)
				expect(state.phase).toBe(phase)
				expect(state.id).toBe(id)
				expect(state.startsAt).toBe(startsAt)
				expect(state.endsAt).toBe(startsAt + 240)
			end
		end
	end)

	it(
		"follows the fixed rotation :00 frenzy, :15 moon_tide, :30 frenzy, :45 whale_fall",
		function()
			local ids = {}
			for q = 0, 3 do
				table.insert(ids, TideClock.at(HOUR0 + q * 900, { shipped = FULL }).id)
			end
			expect(ids).toEqual({ "frenzy", "moon_tide", "frenzy", "whale_fall" })
		end
	)

	it("switches phase exactly on the slot edges", function()
		local s = HOUR0 + 900 -- the :15 slot
		local function at(dt: number)
			local state = TideClock.at(s + dt)
			return state.phase, state.id, state.startsAt
		end
		expect(select(1, at(0))).toBe("active")
		expect(select(1, at(239))).toBe("active")
		expect(select(1, at(239.999))).toBe("active")
		local phase, id, startsAt = at(240)
		expect(phase).toBe("calm")
		expect(id).toBe("frenzy") -- the :30 slot is next
		expect(startsAt).toBe(s + 900)
		expect(select(1, at(839.999))).toBe("calm")
		expect(select(1, at(840))).toBe("warning")
		expect(select(1, at(899.999))).toBe("warning")
		phase, id, startsAt = at(900)
		expect(phase).toBe("active")
		expect(id).toBe("frenzy")
		expect(startsAt).toBe(s + 900)
		-- Just before an hour: the warning names the :00 Frenzy.
		local state = TideClock.at(HOUR0 + 3600 - 1, { shipped = FULL })
		expect(state.phase).toBe("warning")
		expect(state.id).toBe("frenzy")
		expect(state.startsAt).toBe(HOUR0 + 3600)
		-- Before the :45 slot.
		state = TideClock.at(HOUR0 + 2700 - 30, { shipped = FULL })
		expect(state.phase).toBe("warning")
		expect(state.id).toBe("whale_fall")
	end)
end)

describe("TideClock fallback (09 §11.1, canon 10)", function()
	it("runs a second Moon Tide at :45 in the MVP build", function()
		expect(TideClock.at(HOUR0 + 2700).id).toBe("moon_tide")
		expect(TideClock.at(HOUR0 + 2700, { shipped = TideClock.MVP }).id).toBe("moon_tide")
		expect(TideClock.at(HOUR0 + 2700, { shipped = FULL }).id).toBe("whale_fall")
		expect(TideClock.resolve("whale_fall")).toBe("moon_tide")
		expect(TideClock.resolve("whale_fall", FULL)).toBe("whale_fall")
		expect(TideClock.resolve("moon_tide")).toBe("moon_tide")
	end)

	it("falls to Frenzy when the chain ends with nothing playable", function()
		local none = {}
		for q = 0, 3 do
			expect(TideClock.at(HOUR0 + q * 900, { shipped = none }).id).toBe("frenzy")
		end
		expect(TideClock.resolve("no_such_tide")).toBe("frenzy")
	end)

	it("follows the chain past tides the slice build leaves out (outOfBuild)", function()
		-- The slice build (tools/gen/content -- --slice) keeps every row and marks the ones
		-- outside the slice; the generated rows are not frozen, so mark them here and restore.
		local moon = Index.Tides.byId.moon_tide :: any
		local whale = Index.Tides.byId.whale_fall :: any
		expect(moon.fallback).toBe("frenzy")
		moon.outOfBuild, whale.outOfBuild = true, true
		local ok, err = pcall(function()
			for q = 0, 3 do
				expect(TideClock.at(HOUR0 + q * 900).id).toBe("frenzy")
				expect(TideClock.at(HOUR0 + q * 900, { shipped = FULL }).id).toBe("frenzy")
			end
			expect(TideClock.resolve("whale_fall")).toBe("frenzy") -- whale_fall → moon_tide → frenzy
			expect(TideClock.resolve("moon_tide", FULL)).toBe("frenzy")
			-- A limited tide the build leaves out is not offered either.
			expect(TideClock.slotTide(HOUR0 + 1800, {
				shipped = FULL,
				limitedId = "moon_tide",
				limitedStart = HOUR0,
				limitedEnd = HOUR0 + 3600,
			})).toBe("frenzy")
		end)
		moon.outOfBuild, whale.outOfBuild = nil, nil
		if not ok then
			error(err, 0)
		end
	end)
end)

describe("TideClock limited tide at :30 (09 §11.1, §17.4)", function()
	it("replaces only the :30 Frenzy, and only inside its window", function()
		local from, to = HOUR0, HOUR0 + 3600
		local opts =
			{ shipped = FULL, limitedId = "whale_fall", limitedStart = from, limitedEnd = to }
		expect(TideClock.slotTide(HOUR0 + 1800, opts)).toBe("whale_fall")
		expect(TideClock.slotTide(HOUR0, opts)).toBe("frenzy")
		expect(TideClock.slotTide(HOUR0 + 900, opts)).toBe("moon_tide")
		expect(TideClock.slotTide(HOUR0 + 3600 + 1800, opts)).toBe("frenzy") -- past the window
		expect(TideClock.at(HOUR0 + 1800 - 10, opts).id).toBe("whale_fall") -- its warning too
	end)

	it("ignores an empty, unknown or unshipped limited tide", function()
		local window = { limitedStart = HOUR0, limitedEnd = HOUR0 + 3600 }
		expect(TideClock.slotTide(HOUR0 + 1800, {
			limitedId = "",
			limitedStart = window.limitedStart,
			limitedEnd = window.limitedEnd,
		})).toBe("frenzy")
		expect(TideClock.slotTide(HOUR0 + 1800, {
			limitedId = "storm",
			limitedStart = window.limitedStart,
			limitedEnd = window.limitedEnd,
		})).toBe("frenzy")
		expect(TideClock.slotTide(HOUR0 + 1800, {
			limitedId = "whale_fall",
			limitedStart = window.limitedStart,
			limitedEnd = window.limitedEnd,
		})).toBe("frenzy") -- whale_fall is [L]; the MVP build does not ship it
		expect(TideClock.slotTide(HOUR0 + 1800)).toBe("frenzy")
	end)
end)
