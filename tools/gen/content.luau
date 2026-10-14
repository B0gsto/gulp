--!strict
-- Content generator: docs tables -> src/shared/Data/Generated (docs/09, section 3.2).
--   lune run tools/gen/content                full build: every row (this is what is committed)
--   lune run tools/gen/content -- --slice     soft-launch build: only the slice rows of 13 §3.2
-- Reads the tables between `<!-- data:NAME -->` markers (tools/lib/markdown_tables.luau) and
-- writes one typed module per table. `wire` is the row's 1-based position in its canon table and
-- is the same in both builds. A number the bible does not give is never invented here: a table
-- whose type needs a value no marked table holds is not generated (see BLOCKED below).
local fs = require("@lune/fs")
local process = require("@lune/process")

local Files = require("../lib/files")
local MarkdownTables = require("../lib/markdown_tables")

type Table = MarkdownTables.Table
type Row = MarkdownTables.Row

local OUTPUT_ROOT = "src/shared/Data/Generated"
local COLUMN_WIDTH = 100 -- stylua.toml
local CANON = "docs/01-game-canon.md"
local CATALOG = "docs/03-content-catalog.md"
local ECONOMY = "docs/05-economy-and-monetization.md"

-- Marked tables not generated yet, and the required field of 09 §3.2 no marked table gives.
local BLOCKED = {
	Species = "SpeciesDef.radiusMult (03 §1.1 has mouth size only; 02 §0.2 calls it hitboxMult)",
	Prey = "PreyDef.radius, wobble and scatterGain",
	TraitPrey = "PreyDef.radius, wobble, scatterGain, groupMin and groupMax",
	Predators = "PredatorDef.strikeRadius and telegraph; HazardDef.magnitude and duration per hazard",
	Zones = "ZoneDef.lightingPreset (06 §11 names presets, the Drop-off has two)",
	Tides = "TideDef.spawnRateMult for moon_tide and whale_fall; a scope column",
	Products = "ProductDef.robloxId, which 09 §3.2 keeps out of generated files",
	Goals = "a GoalDef type in 09 §3.2",
	Codex = "CodexCategoryDef.rewardDecoration IDs (03 §8.1 gives display names)",
}

type Field = { name: string, value: string }
type Module = { name: string, typeName: string, sources: { string }, rows: { { Field } } }

local function fail(message: string): never
	error(`gen: {message}`, 0)
end

local function cell(t: Table, row: Row, column: string): string
	local value = row.cells[column]
	if value == nil then
		fail(`data:{t.name} has no column "{column}"`)
	end
	return value :: string
end

local function num(t: Table, row: Row, column: string): number
	local value = MarkdownTables.number(cell(t, row, column))
	if value == nil then
		fail(`data:{t.name}, row {row.key}: "{column}" is not a number: {cell(t, row, column)}`)
	end
	return value :: number
end

local function scope(t: Table, row: Row): string
	local tag = string.match(cell(t, row, "Tag"), "^%[(%w+)%]$")
	if tag ~= "MVP" and tag ~= "L" and tag ~= "P1" and tag ~= "P2" then
		fail(`data:{t.name}, row {row.key}: unknown scope tag {cell(t, row, "Tag")}`)
	end
	return tag :: string
end

local function numberText(n: number): string
	if n == math.floor(n) and math.abs(n) < 2 ^ 53 then
		return string.format("%d", n)
	end
	return tostring(n)
end

local function field(name: string, value: string | number | boolean): Field
	if type(value) == "string" then
		return { name = name, value = string.format("%q", value) }
	elseif type(value) == "number" then
		return { name = name, value = numberText(value) }
	end
	return { name = name, value = tostring(value) }
end

local function load(path: string): { [string]: Table }
	return MarkdownTables.parse(fs.readFile(path))
end

local function get(tables: { [string]: Table }, path: string, name: string): Table
	local t = tables[name]
	if t == nil then
		fail(`{path} has no data:{name} table`)
	end
	return t :: Table
end

local function rowsFor(t: Table, slice: boolean): { Row }
	local rows = {}
	for _, row in t.rows do
		if row.inSlice or not slice then
			table.insert(rows, row)
		end
	end
	return rows
end

local function buildTiers(canon: { [string]: Table }, slice: boolean): Module
	local t = get(canon, CANON, "Tiers")
	local rows = {}
	for _, row in rowsFor(t, slice) do
		table.insert(rows, {
			field("tier", num(t, row, "Tier")),
			field("name", MarkdownTables.plain(cell(t, row, "Name"))),
			field("massNeeded", num(t, row, "Mass needed")),
			field("bodyScale", num(t, row, "Body scale")),
			field("swimSpeed", num(t, row, "Swim speed (studs/s)")),
			field("turnRate", num(t, row, "Turn rate (°/s)")),
		})
	end
	return { name = "Tiers", typeName = "TierDef", sources = { `{CANON} data:Tiers` }, rows = rows }
end

local function buildTraits(
	catalog: { [string]: Table },
	economy: { [string]: Table },
	slice: boolean
): Module
	local t = get(catalog, CATALOG, "Traits")
	local income = get(economy, ECONOMY, "TraitIncome")
	local bonus: { [string]: number } = {}
	for _, row in income.rows do
		bonus[row.key] = num(income, row, "Bonus per trait") / 100
	end
	local rows = {}
	for _, row in rowsFor(t, slice) do
		local rarity = MarkdownTables.plain(cell(t, row, "Rarity"))
		local incomeBonus = bonus[rarity]
		if incomeBonus == nil then
			fail(`data:Traits, row {row.key}: rarity {rarity} is not in data:TraitIncome`)
		end
		table.insert(rows, {
			field("id", row.key),
			field("wire", row.position),
			field("scope", scope(t, row)),
			field("rarity", rarity),
			field("incomeBonus", incomeBonus :: number),
		})
	end
	return {
		name = "Traits",
		typeName = "TraitDef",
		sources = { `{CATALOG} data:Traits`, `{ECONOMY} data:TraitIncome` },
		rows = rows,
	}
end

local function buildRevivePoints(
	canon: { [string]: Table },
	catalog: { [string]: Table },
	slice: boolean
): Module
	local zones = get(canon, CANON, "Zones")
	local zoneByName: { [string]: string } = {}
	for _, row in zones.rows do
		zoneByName[MarkdownTables.plain(cell(zones, row, "Zone"))] = row.key
	end
	local t = get(catalog, CATALOG, "RevivePoints")
	local rows = {}
	for _, row in rowsFor(t, slice) do
		local zoneName = MarkdownTables.plain(cell(t, row, "Zone"))
		local zone = zoneByName[zoneName]
		if zone == nil then
			fail(`data:RevivePoints, row {row.key}: zone "{zoneName}" is not in data:Zones`)
		end
		local position = string.gsub(cell(t, row, "Position (X, Z) · depth"), "\u{2212}", "-")
		local x, z, depth =
			string.match(position, "^%(%s*(%-?[%d%.]+)%s*,%s*(%-?[%d%.]+)%s*%)%s*·%s*([%d%.]+)$")
		if x == nil or z == nil or depth == nil then
			fail(`data:RevivePoints, row {row.key}: cannot read the position {position}`)
		end
		table.insert(rows, {
			field("id", row.key),
			field("wire", row.position),
			field("zone", zone :: string),
			field("x", tonumber(x) :: number),
			field("z", tonumber(z) :: number),
			field("depth", tonumber(depth) :: number),
		})
	end
	return {
		name = "RevivePoints",
		typeName = "RevivePointDef",
		sources = { `{CATALOG} data:RevivePoints`, `{CANON} data:Zones` },
		rows = rows,
	}
end

local function render(m: Module, slice: boolean): string
	local out = {
		"--!strict",
		"-- GENERATED, do not edit. Change the source table in the bible, then run",
		"-- `lune run tools/gen/content` (docs/09, section 3.2).",
		`-- Source: {table.concat(m.sources, "; ")}.`,
		`-- Build: {if slice then "soft-launch slice (chapter 13, section 3.2)" else "full"}.`,
		'local Types = require("../../Types")',
		"",
		`local {m.name}: \{ Types.{m.typeName} \} = \{`,
	}
	for _, row in m.rows do
		local parts = {}
		for _, f in row do
			table.insert(parts, `{f.name} = {f.value}`)
		end
		-- Laid out as StyLua would (column 100, a tab counts 4), so the gate's format check passes.
		local line = `\{ {table.concat(parts, ", ")} \},`
		if 4 + utf8.len(line) :: number <= COLUMN_WIDTH then
			table.insert(out, `\t{line}`)
		else
			table.insert(out, "\t{")
			for _, part in parts do
				table.insert(out, `\t\t{part},`)
			end
			table.insert(out, "\t},")
		end
	end
	table.insert(out, "}")
	table.insert(out, "")
	table.insert(out, `return table.freeze({m.name})`)
	table.insert(out, "")
	return table.concat(out, "\n")
end

Files.requireRepoRoot()

local slice = table.find(process.args, "--slice") ~= nil
local canon = load(CANON)
local catalog = load(CATALOG)
local economy = load(ECONOMY)
for name in BLOCKED do
	if canon[name] == nil and catalog[name] == nil and economy[name] == nil then
		fail(`blocked table data:{name} is not marked in the bible`)
	end
end

local modules = {
	buildTiers(canon, slice),
	buildTraits(catalog, economy, slice),
	buildRevivePoints(canon, catalog, slice),
}

if not fs.isDir(OUTPUT_ROOT) then
	fs.writeDir(OUTPUT_ROOT)
end
local total = 0
for _, m in modules do
	fs.writeFile(`{OUTPUT_ROOT}/{m.name}.luau`, render(m, slice))
	total += #m.rows
end
print(
	`gen: wrote {#modules} modules ({total} rows, {if slice then "slice" else "full"} build) to {OUTPUT_ROOT}`
)
