--!strict
-- Invariants on the committed (full) build of src/shared/Data/Generated and on Data/Index.
local fs = require("@lune/fs")

local Index = require("../../../src/shared/Data/Index")
local MarkdownTables = require("../../../tools/lib/markdown_tables")
local RevivePoints = require("../../../src/shared/Data/Generated/RevivePoints")
local TestKit = require("../../../src/shared/Util/TestKit")
local Tiers = require("../../../src/shared/Data/Generated/Tiers")
local Traits = require("../../../src/shared/Data/Generated/Traits")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type Keyed = { id: string, wire: number }

-- Problems with the ID and wire columns: duplicates, and wires that are not 1..n in order.
local function keyProblems(rows: { Keyed }): { string }
	local problems = {}
	local seen: { [string]: boolean } = {}
	for position, row in rows do
		if seen[row.id] then
			table.insert(problems, `{row.id} twice`)
		end
		seen[row.id] = true
		if row.wire ~= position then
			table.insert(problems, `{row.id} has wire {row.wire} at position {position}`)
		end
	end
	return problems
end

describe("Generated content", function()
	it("has seven tiers, numbered 1 to 7, with increasing thresholds, scales and speeds", function()
		expect(#Tiers).toBe(7)
		expect(Tiers[1].massNeeded).toBe(0)
		for i, def in Tiers do
			expect(def.tier).toBe(i)
			if i > 1 then
				local before = Tiers[i - 1]
				expect(def.massNeeded > before.massNeeded).toBe(true)
				expect(def.bodyScale > before.bodyScale).toBe(true)
				expect(def.swimSpeed > before.swimSpeed).toBe(true)
				expect(def.turnRate < before.turnRate).toBe(true)
			end
		end
	end)

	it("gives every keyed table unique IDs and dense wire indices", function()
		expect(keyProblems(Traits)).toEqual({})
		expect(keyProblems(RevivePoints)).toEqual({})
		expect(#Traits).toBe(13)
		expect(#RevivePoints).toBe(12)
	end)

	it("pays the trait income bonus of canon 9 by rarity", function()
		local expected = { Common = 0.10, Uncommon = 0.20, Rare = 0.35, Epic = 0.60, Mythic = 1.00 }
		for _, def in Traits do
			expect(def.incomeBonus).toBe(expected[def.rarity])
		end
	end)

	it("puts every revive point in a canon zone, in open water inside the map", function()
		local zones = MarkdownTables.parse(fs.readFile("docs/01-game-canon.md")).Zones
		local known: { [string]: boolean } = {}
		for _, row in zones.rows do
			known[row.key] = true
		end
		for _, def in RevivePoints do
			expect(known[def.zone]).toBe(true)
			expect(def.depth > 0 and def.depth <= 600).toBe(true)
			expect(math.sqrt(def.x * def.x + def.z * def.z) <= 1000).toBe(true)
		end
	end)
end)

describe("Data/Index", function()
	it("finds rows by ID and by wire index", function()
		expect(Index.Traits.byId.crystal.rarity).toBe("Epic")
		expect(Index.Traits.byWire[1].id).toBe("glow")
		expect(Index.RevivePoints.byId.rp_12.wire).toBe(12)
		expect(Index.RevivePoints.byWire[5].zone).toBe("kelp")
		expect(Index.Traits.byId.nothing).toBe(nil)
	end)

	it("finds tiers by number", function()
		expect(Index.Tiers.byTier[7].name).toBe("Leviathan")
		expect(Index.Tiers.list).toBe(Tiers)
	end)
end)
