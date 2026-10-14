--!strict
local Index = require("../../../src/shared/Data/Index")
local PreySpawnMath = require("../../../src/shared/Logic/PreySpawnMath")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function row(zone: string, prey: string)
	for _, def in Index.PreySpawns.byZone[zone] do
		if def.prey == prey then
			return def
		end
	end
	error(`no spawn row {zone}/{prey}`)
end

describe("PreySpawnMath", function()
	it("scales by players between 0.6 and 1 (02 §9.6)", function()
		expect(PreySpawnMath.playerScale(0)).toBeCloseTo(0.6)
		expect(PreySpawnMath.playerScale(12)).toBeCloseTo(0.8)
		expect(PreySpawnMath.playerScale(24)).toBeCloseTo(1)
		expect(PreySpawnMath.playerScale(40)).toBeCloseTo(1)
	end)

	it("turns motes into patches at the mean patch size and keeps the cap", function()
		local reefPlankton = row("reef", "plankton") -- 300 motes, patches of 6 to 10, cap 40
		expect(select(1, PreySpawnMath.target(reefPlankton, { players = 24 }))).toBe(38)
		expect(select(1, PreySpawnMath.target(reefPlankton, { players = 0 }))).toBe(23)
		local groups, cap = PreySpawnMath.target(reefPlankton, { players = 24, frenzy = true })
		expect(groups).toBe(75)
		expect(cap).toBe(80)
		expect(select(1, PreySpawnMath.target(row("reef", "shrimp"), { players = 24 }))).toBe(30)
	end)

	it("grows the Nursery per player inside, up to its cap, whatever the server size", function()
		local plankton = row("nursery", "plankton") -- 6 + 2 per player inside, cap 12
		expect(select(1, PreySpawnMath.target(plankton, { players = 1 }))).toBe(6)
		expect(select(1, PreySpawnMath.target(plankton, { players = 24, playersInside = 2 }))).toBe(
			10
		)
		expect(select(1, PreySpawnMath.target(plankton, { players = 24, playersInside = 9 }))).toBe(
			12
		)
	end)

	it("scales a smaller spawn area by plan area, keeping at least one group", function()
		local reef = row("reef", "darter") -- 14 groups over the whole reef
		local half = reef.zoneArea / 2
		local groups, cap = PreySpawnMath.target(reef, { players = 24, area = half })
		expect(groups).toBe(7)
		expect(cap).toBe(7)
		local tuna = row("dropoff", "tuna")
		expect(select(1, PreySpawnMath.target(tuna, { players = 24, area = 100 }))).toBe(1)
		expect(PreySpawnMath.planArea("Block", 512, 512)).toBe(262144)
		expect(PreySpawnMath.planArea("Ball", 80, 80)).toBeCloseTo(math.pi * 1600)
	end)

	it("lists a zone's targets in table order and nothing for the coves", function()
		local targets = PreySpawnMath.zoneTargets("nursery", { players = 24 })
		expect(#targets).toBe(2)
		expect(targets[1].prey).toBe("plankton")
		expect(targets[2].weight).toBe(30)
		expect(#PreySpawnMath.zoneTargets("cove", { players = 24 })).toBe(0)
	end)
end)
