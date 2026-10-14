--!strict
-- Content generator: docs tables -> src/shared/Data/Generated (docs/09, section 3.2).
--   lune run tools/gen/content                full build: every row (this is what is committed)
--   lune run tools/gen/content -- --slice     soft-launch build: only the slice rows of 13 §3.2
-- Reads the tables between `<!-- data:NAME -->` markers (tools/lib/markdown_tables.luau) and
-- writes one typed module per table. `wire` is the row's 1-based position in its canon table and
-- is the same in both builds (for a table split into two modules, the position among its kind).
-- A number the bible does not give is never invented here: every value is a cell, or arithmetic
-- the bible states (cited where it is done).
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

type Field = { name: string, value: string }
type Tables = { [string]: Table }
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

local function literal(value: string | number | boolean): string
	if type(value) == "string" then
		return string.format("%q", value)
	elseif type(value) == "number" then
		return numberText(value)
	end
	return tostring(value)
end

local function field(name: string, value: string | number | boolean): Field
	return { name = name, value = literal(value) }
end

local function list(name: string, values: { string | number }): Field
	if #values == 0 then
		return { name = name, value = "{}" }
	end
	local parts = {}
	for _, v in values do
		table.insert(parts, literal(v))
	end
	return { name = name, value = `\{ {table.concat(parts, ", ")} \}` }
end

-- Appends an optional field: nil leaves it out, as the type allows.
local function optional(fields: { Field }, name: string, value: (string | number)?)
	if value ~= nil then
		table.insert(fields, field(name, value))
	end
end

local function round(n: number, places: number): number
	local scale = 10 ^ places
	return math.floor(n * scale + 0.5) / scale
end

-- Every number in a cell, in order ("1,500" is 1500; a Unicode minus is a minus).
local function numbers(text: string): { number }
	local out = {}
	text = string.gsub(string.gsub(text, "`[^`]*`", ""), "\u{2212}", "-")
	text = string.gsub(text, "(%d),(%d%d%d)", "%1%2")
	for digits in string.gmatch(text, "%-?%d+%.?%d*") do
		table.insert(out, tonumber(digits) :: number)
	end
	return out
end

local function firstNumber(t: Table, row: Row, column: string): number
	local found = numbers(cell(t, row, column))[1]
	if found == nil then
		fail(`data:{t.name}, row {row.key}: "{column}" has no number: {cell(t, row, column)}`)
	end
	return found :: number
end

-- The first number, or nil when the cell says None, "Does not flee" and the like.
local function maybeNumber(t: Table, row: Row, column: string): number?
	return numbers(cell(t, row, column))[1]
end

local function ids(t: Table, row: Row, column: string): { string }
	local out = {}
	for id in string.gmatch(cell(t, row, column), "`([^`]+)`") do
		table.insert(out, id)
	end
	return out
end

local function oneId(t: Table, row: Row, column: string): string
	local found = ids(t, row, column)[1]
	if found == nil then
		fail(`data:{t.name}, row {row.key}: "{column}" names no ID: {cell(t, row, column)}`)
	end
	return found :: string
end

local function keySet(t: Table): { [string]: boolean }
	local set = {}
	for _, row in t.rows do
		set[row.key] = true
	end
	return set
end

local function checkIds(
	t: Table,
	row: Row,
	column: string,
	known: { [string]: boolean },
	what: string
)
	for _, id in ids(t, row, column) do
		if not known[id] then
			fail(`data:{t.name}, row {row.key}: {id} is not in {what}`)
		end
	end
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

local function buildTiers(canon: Tables, slice: boolean): Module
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

local function buildTraits(catalog: Tables, economy: Tables, slice: boolean): Module
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

local function buildRevivePoints(canon: Tables, catalog: Tables, slice: boolean): Module
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

local BASE_DASH_TIME = 0.35 -- seconds; chapter 02, Dashing state: `0.35 × (1 + ...)`
local CRUISE_SHARE = 0.4 -- chapter 03, section 2.1 notes: cruise speed is 40% of flee speed

local function buildSpecies(catalog: Tables, economy: Tables, slice: boolean): Module
	local t = get(catalog, CATALOG, "Species")
	local prices = get(economy, ECONOMY, "SpeciesPrices")
	local passes = get(economy, ECONOMY, "Passes")
	local rows = {}
	for _, row in rowsFor(t, slice) do
		local price: Row? = nil
		for _, p in prices.rows do
			if p.key == row.key then
				price = p
			end
		end
		if price == nil then
			fail(`data:Species, row {row.key}: no price in data:SpeciesPrices`)
		end
		local priceRow = price :: Row
		local priceText = cell(prices, priceRow, "Price (Pearls)")
		local passId: string? = nil
		if string.find(priceText, "game pass", 1, true) then
			for _, pass in passes.rows do
				if
					string.find(
						cell(passes, pass, "Exact effect"),
						`\`{row.key}\` species`,
						1,
						true
					)
				then
					passId = pass.key
				end
			end
			if passId == nil then
				fail(`data:Species, row {row.key}: no pass in data:Passes unlocks it`)
			end
		end
		local fields = {
			field("id", row.key),
			field("wire", row.position),
			field("scope", scope(t, row)),
			field(
				"unlockPearls",
				if priceText == "Free" then 0 else firstNumber(prices, priceRow, "Price (Pearls)")
			),
		}
		optional(fields, "passId", passId)
		for _, f in
			{
				field("speedMult", firstNumber(t, row, "Swim speed") / 100),
				field("turnMult", firstNumber(t, row, "Turn rate") / 100),
				field("accelMult", firstNumber(t, row, "Acceleration") / 100),
				field("dashMult", firstNumber(t, row, "Dash speed")),
				field("radiusMult", firstNumber(t, row, "Collision radius") / 100),
				field("dashCooldown", firstNumber(t, row, "Dash cooldown")),
				field(
					"dashDurationMult",
					round(firstNumber(t, row, "Dash time") / BASE_DASH_TIME, 3)
				),
				field("startTier", firstNumber(t, row, "Start tier")),
				field("ability", oneId(t, row, "Ability")),
			}
		do
			table.insert(fields, f)
		end
		table.insert(rows, fields)
	end
	return {
		name = "Species",
		typeName = "SpeciesDef",
		sources = { `{CATALOG} data:Species`, `{ECONOMY} data:SpeciesPrices, data:Passes` },
		rows = rows,
	}
end

-- Ordinary prey (data:Prey) and trait prey (data:TraitPrey) share PreyDef; each is its own module.
local function buildPrey(canon: Tables, catalog: Tables, name: string, slice: boolean): Module
	local t = get(catalog, CATALOG, name)
	local zones = keySet(get(canon, CANON, "Zones"))
	local tierSpeed: { [number]: number } = {}
	local tiers = get(canon, CANON, "Tiers")
	for _, row in tiers.rows do
		tierSpeed[num(tiers, row, "Tier")] = num(tiers, row, "Swim speed (studs/s)")
	end
	local traitByName: { [string]: string } = {}
	local traits = get(catalog, CATALOG, "Traits")
	for _, row in traits.rows do
		traitByName[MarkdownTables.plain(cell(traits, row, "Trait"))] = row.key
	end
	local eventOf: { [string]: string } = {}
	local tides = get(canon, CANON, "Tides")
	for _, row in tides.rows do
		for _, id in ids(tides, row, "Event prey") do
			eventOf[id] = row.key
		end
	end
	local isTrait = name == "TraitPrey"
	local rows = {}
	for _, row in rowsFor(t, slice) do
		checkIds(
			t,
			row,
			if isTrait then "Zones (section 3.2)" else "Zones (section 2.3)",
			zones,
			"data:Zones"
		)
		local tier = num(t, row, "Tier")
		local fleeCell =
			cell(t, row, if isTrait then "Flee speed" else "Flee speed (% of same-tier player)")
		local fleeSpeed
		if isTrait and not string.find(fleeCell, "studs/s", 1, true) then
			-- Chapter 02, section 9.1: a percentage of the swim speed of a player of the prey's tier.
			fleeSpeed =
				round(firstNumber(t, row, "Flee speed") / 100 * tierSpeed[math.max(tier, 1)], 1)
		elseif isTrait then
			fleeSpeed = firstNumber(t, row, "Flee speed")
		else
			fleeSpeed = num(t, row, "Flee speed (studs/s)")
		end
		local drifts = string.find(fleeCell, "drift", 1, true) ~= nil
		local group = numbers(cell(t, row, "Group size"))
		local fields = {
			field("id", row.key),
			field("wire", row.position),
			field("scope", scope(t, row)),
			field("tier", tier),
			field("mass", num(t, row, "Mass")),
		}
		if isTrait then
			local trait = traitByName[MarkdownTables.plain(cell(t, row, "Gives"))]
			if trait == nil then
				fail(
					`data:TraitPrey, row {row.key}: "{cell(t, row, "Gives")}" is not in data:Traits`
				)
			end
			table.insert(fields, field("givesTrait", trait :: string))
		end
		local behaviourColumn = if isTrait
			then "Behaviour (chapter 02, section 9.3)"
			else "Behaviour (chapter 02, section 9.2)"
		for _, f in
			{
				list(
					"zones",
					ids(t, row, if isTrait then "Zones (section 3.2)" else "Zones (section 2.3)")
				),
				field("groupMin", group[1]),
				field("groupMax", group[#group]),
				field("behaviour", oneId(t, row, behaviourColumn)),
				field(
					"cruiseSpeed",
					if drifts then fleeSpeed else round(fleeSpeed * CRUISE_SHARE, 1)
				),
				field("fleeSpeed", fleeSpeed),
				field("fleeRadius", maybeNumber(t, row, "Flee distance (studs)") or 0),
				field("scatterGain", firstNumber(t, row, "Scatter gain")),
				field("radius", firstNumber(t, row, "Radius (studs)")),
				field("wobble", firstNumber(t, row, "Wobble (studs)")),
			}
		do
			table.insert(fields, f)
		end
		optional(fields, "eventOnly", eventOf[row.key])
		table.insert(rows, fields)
	end
	return {
		name = name,
		typeName = "PreyDef",
		sources = { `{CATALOG} data:{name}`, `{CANON} data:Tiers, data:Zones, data:Tides` },
		rows = rows,
	}
end

-- data:Predators holds predators (a tier number) and hazards ("Hazard" or "Helper").
local function buildPredators(catalog: Tables, hazards: boolean, slice: boolean): Module
	local t = get(catalog, CATALOG, "Predators")
	local cycle = get(catalog, CATALOG, "VentCycle")
	local length: { [string]: number } = {}
	for _, row in cycle.rows do
		length[row.key] = firstNumber(cycle, row, "Length")
	end
	local rows = {}
	local wire = 0
	for _, row in t.rows do
		local tierCell = cell(t, row, "Tier · eats")
		local isHazard = tierCell == "Hazard" or tierCell == "Helper"
		if isHazard ~= hazards then
			continue
		end
		wire += 1
		if slice and not row.inSlice then
			continue
		end
		local fields = { field("id", row.key), field("wire", wire), field("scope", scope(t, row)) }
		if hazards then
			table.insert(fields, field("effect", oneId(t, row, "Effect")))
			table.insert(fields, field("magnitude", firstNumber(t, row, "Magnitude")))
			table.insert(fields, field("duration", firstNumber(t, row, "Effect time (s)")))
			if row.key == "vent" then -- chapter 09, section 3.2: the vent alone has a cycle
				table.insert(fields, {
					name = "cycle",
					value = `\{ dormant = {numberText(length.Dormant)}, rumble = {numberText(
						length.Rumble
					)}, erupting = {numberText(length.Erupting)} \}`,
				})
			end
		else
			local tiers = numbers(tierCell)
			local speeds = numbers(cell(t, row, "Cruise / attack speed (studs/s)"))
			local detect = cell(t, row, "Detect (studs)")
			local sense = tonumber(string.match(detect, "within (%d+) studs"))
				or firstNumber(t, row, "Detect (studs)")
			for _, f in
				{
					field("tier", tiers[1]),
					field("eatsMaxTier", tiers[#tiers]), -- "eats tier 3 and lower", "eats tiers 1 to 2"
					field("speed", speeds[#speeds]), -- the attack speed: the cell's last number
					field("senseRadius", sense),
					field("strikeRadius", firstNumber(t, row, "Strike radius (studs)")),
					field("telegraph", firstNumber(t, row, "Telegraph (s)")),
					field("giveUpAfter", firstNumber(t, row, "Give up after (s)")),
					field("rest", firstNumber(t, row, "Rest after attack (s)")),
				}
			do
				table.insert(fields, f)
			end
			optional(fields, "eatenMass", maybeNumber(t, row, "Mass when eaten"))
		end
		table.insert(rows, fields)
	end
	return {
		name = if hazards then "Hazards" else "Predators",
		typeName = if hazards then "HazardDef" else "PredatorDef",
		sources = { `{CATALOG} data:Predators{if hazards then ", data:VentCycle" else ""}` },
		rows = rows,
	}
end

-- The zone's base preset comes first; the Drop-off's cell adds 06 §10.3's blend to "Drop-off, deep".
local PRESET = "Lighting preset (chapter 06, section 10.2)"

local function buildZones(canon: Tables, slice: boolean): Module
	local t = get(canon, CANON, "Zones")
	local rows = {}
	for _, row in rowsFor(t, slice) do
		local tiers = numbers(cell(t, row, "Prey tiers"))
		table.insert(rows, {
			field("id", row.key),
			field("wire", row.position),
			field("scope", scope(t, row)),
			-- A zone with no prey (the coves) gets the empty range 0 to -1.
			field("preyTierMin", tiers[1] or 0),
			field("preyTierMax", tiers[2] or -1),
			field("safe", string.match(cell(t, row, "Danger"), "^None") ~= nil),
			field(
				"lightingPreset",
				string.match(MarkdownTables.plain(cell(t, row, PRESET)), "^[^;]+") :: string
			),
		})
	end
	return { name = "Zones", typeName = "ZoneDef", sources = { `{CANON} data:Zones` }, rows = rows }
end

local function buildTides(canon: Tables, catalog: Tables, slice: boolean): Module
	local t = get(canon, CANON, "Tides")
	local known = keySet(t)
	for _, name in { "Prey", "TraitPrey" } do
		for key in keySet(get(catalog, CATALOG, name)) do
			known[key] = true
		end
	end
	local rows = {}
	for _, row in rowsFor(t, slice) do
		checkIds(t, row, "Fallback", known, "data:Tides")
		checkIds(t, row, "Event prey", known, "data:Prey or data:TraitPrey")
		local fields =
			{ field("id", row.key), field("wire", row.position), field("scope", scope(t, row)) }
		optional(fields, "fallback", ids(t, row, "Fallback")[1])
		table.insert(fields, field("spawnRateMult", firstNumber(t, row, "Prey spawn rate")))
		table.insert(fields, list("eventPrey", ids(t, row, "Event prey")))
		table.insert(rows, fields)
	end
	return { name = "Tides", typeName = "TideDef", sources = { `{CANON} data:Tides` }, rows = rows }
end

local function buildProducts(economy: Tables, slice: boolean): Module
	local rows = {}
	for _, name in { "Passes", "Products", "PearlPacks" } do
		local t = get(economy, ECONOMY, name)
		for _, row in rowsFor(t, slice) do
			local grants = ids(t, row, "Grant")
			local fields = {
				field("id", row.key),
				field("kind", if name == "Passes" then "pass" else "product"),
				field("scope", scope(t, row)),
				field("grant", grants[1]),
			}
			if name == "PearlPacks" then
				table.insert(fields, field("amount", num(t, row, "Pearls")))
			else
				optional(fields, "amount", maybeNumber(t, row, "Grant"))
			end
			if #grants > 1 then
				table.insert(fields, list("items", { table.unpack(grants, 2) }))
			end
			table.insert(rows, fields)
		end
	end
	return {
		name = "Products",
		typeName = "ProductDef",
		sources = { `{ECONOMY} data:Passes, data:Products, data:PearlPacks` },
		rows = rows,
	}
end

local function buildGoals(catalog: Tables, slice: boolean): Module
	local t = get(catalog, CATALOG, "Goals")
	local rows = {}
	for _, row in rowsFor(t, slice) do
		local fields = {
			field("id", row.key),
			field("wire", row.position),
			field("scope", scope(t, row)),
			field("text", MarkdownTables.plain(cell(t, row, "Text"))),
			field("target", firstNumber(t, row, "Target")),
			field("difficulty", MarkdownTables.plain(cell(t, row, "Difficulty"))),
			field("reward", MarkdownTables.plain(cell(t, row, "Reward"))),
		}
		local needs = MarkdownTables.plain(cell(t, row, "Needs"))
		optional(fields, "needs", if needs == "Nothing" then nil else needs)
		table.insert(rows, fields)
	end
	return {
		name = "Goals",
		typeName = "GoalDef",
		sources = { `{CATALOG} data:Goals` },
		rows = rows,
	}
end

local function buildCodex(catalog: Tables, slice: boolean): Module
	local t = get(catalog, CATALOG, "Codex")
	local rows = {}
	for _, row in rowsFor(t, slice) do
		local entry = cell(t, row, "Pearls per entry (chapter 05)")
		entry = string.match(entry, ":(.*)$") or entry
		local reward = cell(t, row, "Reward for completing the category")
		local pearls = nil
		for amount in string.gmatch(reward, "%(([%d,]+)%)") do
			pearls = numbers(amount)[1]
		end
		local fields = {
			field("id", row.key),
			field("wire", row.position),
			field("scope", scope(t, row)),
			list("entryPearls", numbers(entry)),
			field("rewardPearls", pearls or 0),
		}
		optional(fields, "rewardDecoration", ids(t, row, "Reward decoration (section 13)")[1])
		optional(fields, "rewardTitle", string.match(reward, 'title "([^"]+)"'))
		table.insert(rows, fields)
	end
	return {
		name = "Codex",
		typeName = "CodexCategoryDef",
		sources = { `{CATALOG} data:Codex` },
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
local modules = {
	buildTiers(canon, slice),
	buildSpecies(catalog, economy, slice),
	buildPrey(canon, catalog, "Prey", slice),
	buildPrey(canon, catalog, "TraitPrey", slice),
	buildTraits(catalog, economy, slice),
	buildPredators(catalog, false, slice),
	buildPredators(catalog, true, slice),
	buildZones(canon, slice),
	buildTides(canon, catalog, slice),
	buildProducts(economy, slice),
	buildCodex(catalog, slice),
	buildGoals(catalog, slice),
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
