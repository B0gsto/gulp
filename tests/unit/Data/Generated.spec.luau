--!strict
-- Invariants on the committed (full) build of src/shared/Data/Generated and on Data/Index.
local fs = require("@lune/fs")

local Codex = require("../../../src/shared/Data/Generated/Codex")
local Goals = require("../../../src/shared/Data/Generated/Goals")
local Hazards = require("../../../src/shared/Data/Generated/Hazards")
local Index = require("../../../src/shared/Data/Index")
local MarkdownTables = require("../../../tools/lib/markdown_tables")
local Predators = require("../../../src/shared/Data/Generated/Predators")
local Prey = require("../../../src/shared/Data/Generated/Prey")
local Products = require("../../../src/shared/Data/Generated/Products")
local RevivePoints = require("../../../src/shared/Data/Generated/RevivePoints")
local Species = require("../../../src/shared/Data/Generated/Species")
local TestKit = require("../../../src/shared/Util/TestKit")
local Tides = require("../../../src/shared/Data/Generated/Tides")
local Tiers = require("../../../src/shared/Data/Generated/Tiers")
local TraitPrey = require("../../../src/shared/Data/Generated/TraitPrey")
local Traits = require("../../../src/shared/Data/Generated/Traits")
local Zones = require("../../../src/shared/Data/Generated/Zones")

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
		local tables: { [string]: { Keyed } } = {
			Codex = Codex,
			Goals = Goals,
			Hazards = Hazards,
			Predators = Predators,
			Prey = Prey,
			RevivePoints = RevivePoints,
			Species = Species,
			Tides = Tides,
			TraitPrey = TraitPrey,
			Traits = Traits,
			Zones = Zones,
		}
		for name, rows in tables do
			expect(`{name}: {table.concat(keyProblems(rows), ", ")}`).toBe(`{name}: `)
		end
		local counts = {
			Codex = 8,
			Goals = 42,
			Hazards = 5,
			Predators = 5,
			Prey = 8,
			RevivePoints = 12,
			Species = 6,
			Tides = 3,
			TraitPrey = 13,
			Traits = 13,
			Zones = 6,
		}
		for name, count in counts do
			expect(`{name} {#tables[name]}`).toBe(`{name} {count}`)
		end
		local productIds: { [string]: boolean } = {}
		for _, def in Products do
			expect(productIds[def.id]).toBe(nil)
			productIds[def.id] = true
		end
		expect(#Products).toBe(15)
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

describe("Cross-references", function()
	local zoneIds: { [string]: boolean } = {}
	for _, def in Zones do
		zoneIds[def.id] = true
	end

	it("puts every prey and trait prey in zones that exist, with a sane group and size", function()
		for _, rows in { Prey, TraitPrey } do
			for _, def in rows do
				expect(#def.zones > 0).toBe(true)
				for _, zone in def.zones do
					expect(`{def.id} in {zone}: {zoneIds[zone] == true}`).toBe(
						`{def.id} in {zone}: true`
					)
				end
				expect(def.groupMin >= 1 and def.groupMin <= def.groupMax).toBe(true)
				expect(def.groupMax <= 24).toBe(true) -- MAX_MEMBERS (chapter 09, section 8.1)
				expect(def.radius > 0 and def.wobble >= 0 and def.wobble <= 1.5).toBe(true)
				expect(def.cruiseSpeed <= def.fleeSpeed).toBe(true)
			end
		end
	end)

	it("gives every trait prey a trait that exists, and every trait one trait prey", function()
		local given: { [string]: number } = {}
		for _, def in TraitPrey do
			local trait = def.givesTrait :: string
			expect(Index.Traits.byId[trait] ~= nil).toBe(true)
			given[trait] = (given[trait] or 0) + 1
		end
		for _, def in Traits do
			expect(`{def.id} {given[def.id]}`).toBe(`{def.id} 1`)
		end
	end)

	it("keeps predators to tiers that make sense and hazards to the effects of 09", function()
		for _, def in Predators do
			expect(def.eatsMaxTier < def.tier).toBe(true)
			expect(def.strikeRadius > 0 and def.telegraph > 0 and def.rest > 0).toBe(true)
		end
		for _, def in Hazards do
			expect(def.cycle == nil or def.id == "vent").toBe(true)
		end
	end)

	it("names only existing tides, prey and decorations", function()
		for _, def in Tides do
			expect(def.fallback == nil or Index.Tides.byId[def.fallback :: string] ~= nil).toBe(
				true
			)
			for _, id in def.eventPrey do
				expect(Index.TraitPrey.byId[id].eventOnly).toBe(def.id)
			end
		end
		for _, def in Codex do
			if def.rewardDecoration ~= nil then
				expect(string.sub(def.rewardDecoration :: string, 1, 9)).toBe("deco_cdx_")
			end
		end
		for _, def in Species do
			expect(def.passId == nil or Index.Products.byId[def.passId :: string] ~= nil).toBe(true)
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
