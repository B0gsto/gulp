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
local MECHANICS = "docs/02-mechanics.md"
local CATALOG = "docs/03-content-catalog.md"
local ECONOMY = "docs/05-economy-and-monetization.md"
local ART = "docs/06-art-bible.md"

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
	local grouped = 1
	while grouped > 0 do -- one pass joins every other group of "1,078,195"
		text, grouped = string.gsub(text, "(%d),(%d%d%d)", "%1%2")
	end
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

local function buildTiers(canon: Tables, economy: Tables, slice: boolean): Module
	local t = get(canon, CANON, "Tiers")
	-- 05 §3.3 data:CoveIncome: a specimen's base Pearls per hour by tier. A cell that is not a
	-- plain number ("Not applicable", tier 1) means the tier keeps no specimen.
	local income = get(economy, ECONOMY, "CoveIncome")
	local base: { [number]: number } = {}
	for _, row in income.rows do
		local value = MarkdownTables.number(cell(income, row, "Base Pearls/h"))
		if value ~= nil then
			base[firstNumber(income, row, "Tier")] = value
		end
	end
	local rows = {}
	for _, row in rowsFor(t, slice) do
		local fields = {
			field("tier", num(t, row, "Tier")),
			field("name", MarkdownTables.plain(cell(t, row, "Name"))),
			field("massNeeded", num(t, row, "Mass needed")),
			field("bodyScale", num(t, row, "Body scale")),
			field("swimSpeed", num(t, row, "Swim speed (studs/s)")),
			field("turnRate", num(t, row, "Turn rate (°/s)")),
		}
		optional(fields, "coveIncome", base[num(t, row, "Tier")])
		table.insert(rows, fields)
	end
	return {
		name = "Tiers",
		typeName = "TierDef",
		sources = { `{CANON} data:Tiers`, `{ECONOMY} data:CoveIncome` },
		rows = rows,
	}
end

-- 05 §3.12 data:RewardBands: the Pearl amount of each reward band R1 to R5.
local function buildRewardBands(economy: Tables, slice: boolean): Module
	local t = get(economy, ECONOMY, "RewardBands")
	local rows = {}
	for _, row in rowsFor(t, slice) do
		table.insert(rows, { field("id", row.key), field("pearls", num(t, row, "Pearls")) })
	end
	return {
		name = "RewardBands",
		typeName = "RewardBandDef",
		sources = { `{ECONOMY} data:RewardBands` },
		rows = rows,
	}
end

-- 01 §5.4 data:BankRates: the banking mass bands. Each band pays its rate per mass inside it; the
-- last band has no upper limit ("No limit") and the bands must follow on from each other.
local function buildBankRates(canon: Tables, slice: boolean): Module
	local t = get(canon, CANON, "BankRates")
	local rows = {}
	local expectFrom = 0
	for _, row in t.rows do
		local from = num(t, row, "Mass from")
		if from ~= expectFrom then
			fail(`data:BankRates, row {row.key}: starts at {from}, not at {expectFrom}`)
		end
		local upTo = MarkdownTables.number(cell(t, row, "Mass up to"))
		if upTo == nil and row.position ~= #t.rows then
			fail(`data:BankRates, row {row.key}: only the last band can have no limit`)
		end
		expectFrom = upTo or expectFrom
		if row.inSlice or not slice then
			local fields = { field("from", from) }
			optional(fields, "upTo", upTo)
			table.insert(fields, field("pearlsPerMass", num(t, row, "Pearls per mass")))
			table.insert(rows, fields)
		end
	end
	return {
		name = "BankRates",
		typeName = "BankRateDef",
		sources = { `{CANON} data:BankRates` },
		rows = rows,
	}
end

-- 01 §5.5 data:Scraps: the scraps share by death number on the account ("1st to 3rd" starts at
-- death 1). The share column is a percentage.
local function buildScraps(canon: Tables, slice: boolean): Module
	local t = get(canon, CANON, "Scraps")
	local rows = {}
	for _, row in rowsFor(t, slice) do
		table.insert(rows, {
			field("fromDeath", firstNumber(t, row, "Death on the account")),
			field(
				"share",
				num(t, row, "Scraps (share of the Pearls the run would have banked)") / 100
			),
		})
	end
	return {
		name = "Scraps",
		typeName = "ScrapsDef",
		sources = { `{CANON} data:Scraps` },
		rows = rows,
	}
end

-- 05 §4.2 data:SlotPrices: the Pearl price of each cove slot beyond the free ones. The slots must
-- be consecutive and the running total must add up (the column is checked, not generated).
local function buildSlotPrices(economy: Tables, slice: boolean): Module
	local t = get(economy, ECONOMY, "SlotPrices")
	local rows = {}
	local total = 0
	local previous: number? = nil
	for _, row in t.rows do
		local slot = num(t, row, "Slot")
		if previous ~= nil and slot ~= previous + 1 then
			fail(`data:SlotPrices, row {row.key}: slot {slot} does not follow slot {previous}`)
		end
		previous = slot
		local price = num(t, row, "Price (Pearls)")
		total += price
		if num(t, row, "Running total") ~= total then
			fail(`data:SlotPrices, row {row.key}: the running total should be {total}`)
		end
		if row.inSlice or not slice then
			table.insert(rows, { field("slot", slot), field("price", price) })
		end
	end
	return {
		name = "SlotPrices",
		typeName = "SlotPriceDef",
		sources = { `{ECONOMY} data:SlotPrices` },
		rows = rows,
	}
end

-- 05 §7 data:ReefRanks: the lifetime banked Pearls each Reef Rank needs and the Pearls it pays
-- ("—" for rank 1: nothing). Ranks must be consecutive from 1 with rising thresholds.
local function buildReefRanks(economy: Tables, slice: boolean): Module
	local t = get(economy, ECONOMY, "ReefRanks")
	local rows = {}
	local last = -1
	for _, row in t.rows do
		local rank = num(t, row, "Rank")
		local threshold = num(t, row, "Lifetime banked Pearls")
		if rank ~= row.position or threshold <= last then
			fail(`data:ReefRanks, row {row.key}: ranks must count up from 1 with rising thresholds`)
		end
		last = threshold
		if row.inSlice or not slice then
			table.insert(rows, {
				field("rank", rank),
				field("threshold", threshold),
				field("reward", maybeNumber(t, row, "Reward (Pearls)") or 0),
			})
		end
	end
	return {
		name = "ReefRanks",
		typeName = "ReefRankDef",
		sources = { `{ECONOMY} data:ReefRanks` },
		rows = rows,
	}
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

-- Chapter 03, section 6.7: the 24 cove mouths; the row's position is the cove number (= slot).
local function buildCoveMouths(catalog: Tables, slice: boolean): Module
	local t = get(catalog, CATALOG, "CoveMouths")
	local rows = {}
	for _, row in rowsFor(t, slice) do
		if row.key ~= string.format("C%02d", row.position) then
			fail(
				`data:CoveMouths, row {row.key}: cove {row.position} must be C{string.format(
					"%02d",
					row.position
				)}`
			)
		end
		local mouth = string.gsub(cell(t, row, "Mouth (X, Z)"), "\u{2212}", "-")
		local x, z = string.match(mouth, "^%(%s*(%-?[%d%.]+)%s*,%s*(%-?[%d%.]+)%s*%)$")
		if x == nil or z == nil then
			fail(`data:CoveMouths, row {row.key}: cannot read the mouth {mouth}`)
		end
		table.insert(rows, {
			field("id", row.key),
			field("wire", row.position),
			field("x", tonumber(x) :: number),
			field("z", tonumber(z) :: number),
		})
	end
	return {
		name = "CoveMouths",
		typeName = "CoveMouthDef",
		sources = { `{CATALOG} data:CoveMouths` },
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
				-- 0 when the cell names no number: turns in any direction, or never flees.
				field("turnRate", maybeNumber(t, row, "Turn rate (°/s)") or 0),
				field("fleeBurst", maybeNumber(t, row, "Flee burst (s)") or 0),
				field("fleeRadius", maybeNumber(t, row, "Flee distance (studs)") or 0),
				field("scatterGain", firstNumber(t, row, "Scatter gain")),
				field("radius", firstNumber(t, row, "Radius (studs)")),
				field("wobble", firstNumber(t, row, "Wobble (studs)")),
			}
		do
			table.insert(fields, f)
		end
		optional(fields, "eventOnly", eventOf[row.key])
		-- "Respawn (s)": nil for event prey ("Event only"). The Crystal Jelly's cell gives the drift
		-- interval first and the time a drift stays second (03 §3.1).
		local respawn = numbers(cell(t, row, "Respawn (s)"))
		optional(fields, "respawn", respawn[1])
		if isTrait then
			optional(fields, "lifetime", respawn[2])
			-- "Alive per server": the most alive at once; event prey also give the total released in
			-- one event ("N in total per event"). A cell that is only that total has no alive count.
			local alive = cell(t, row, "Alive per server")
			local total = string.match(alive, "(%d+) in total per event")
			local onlyTotal = total ~= nil and string.match(alive, "^%s*%d+ in total") ~= nil
			optional(fields, "alive", if onlyTotal then nil else numbers(alive)[1])
			optional(fields, "eventTotal", if total then tonumber(total) else nil)
		end
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
	-- Every tide row in both builds: the rotation names them all (canon 10). In the slice build a
	-- tide outside the slice is marked `outOfBuild` and runs its fallback (09 §11.1).
	for _, row in t.rows do
		checkIds(t, row, "Fallback", known, "data:Tides")
		checkIds(t, row, "Event prey", known, "data:Prey or data:TraitPrey")
		local fields =
			{ field("id", row.key), field("wire", row.position), field("scope", scope(t, row)) }
		optional(fields, "fallback", ids(t, row, "Fallback")[1])
		if slice and not row.inSlice then
			table.insert(fields, field("outOfBuild", true))
		end
		table.insert(fields, field("spawnRateMult", firstNumber(t, row, "Prey spawn rate")))
		table.insert(fields, list("eventPrey", ids(t, row, "Event prey")))
		table.insert(rows, fields)
	end
	return { name = "Tides", typeName = "TideDef", sources = { `{CANON} data:Tides` }, rows = rows }
end

-- A table's column for a zone: headers name zones as 01's data:Zones does, give or take a
-- leading "The", a trailing tag, and the Nursery's short name ("Nursery" for "Nursery Lagoon").
local function zoneColumn(t: Table, zoneName: string): string?
	local function norm(text: string): string
		local plainText = string.gsub(MarkdownTables.plain(text), "%s*%[%w+%]$", "")
		return (string.gsub(plainText, "^The ", ""))
	end
	local want = norm(zoneName)
	for _, header in t.header do
		local have = norm(header)
		if have ~= "" and string.sub(want, 1, #have) == have then
			return header
		end
	end
	return nil
end

-- One row per prey and zone where 03 §2.3 gives a weight and 02 §9.6 a base count (the Trench
-- [P2] has weights and caps but no base counts yet, so it has no rows). Zones in canon order,
-- prey in 03's order within each zone.
local function buildPreySpawns(
	canon: Tables,
	mechanics: Tables,
	catalog: Tables,
	slice: boolean
): Module
	local spawns = get(catalog, CATALOG, "PreySpawns")
	local targets = get(mechanics, MECHANICS, "PreyTargets")
	local areas = get(catalog, CATALOG, "ZoneAreas")
	local zones = get(canon, CANON, "Zones")
	local prey = get(catalog, CATALOG, "Prey")
	local preyRow: { [string]: Row } = {}
	for _, row in prey.rows do
		preyRow[row.key] = row
	end
	local targetRow: { [string]: Row } = {}
	for _, row in targets.rows do
		targetRow[row.key] = row
	end
	local areaOf: { [string]: number } = {}
	for _, row in areas.rows do
		areaOf[row.key] = firstNumber(areas, row, "Plan area (studs²)")
	end
	for _, row in spawns.rows do
		if preyRow[row.key] == nil then
			fail(`data:PreySpawns, row {row.key}: not in data:Prey`)
		end
	end
	local rows = {}
	for _, zone in zones.rows do
		local zoneName = MarkdownTables.plain(cell(zones, zone, "Zone"))
		local spawnColumn = zoneColumn(spawns, zoneName)
		local targetColumn = zoneColumn(targets, zoneName)
		if spawnColumn == nil or targetColumn == nil or (slice and not zone.inSlice) then
			continue
		end
		local area = areaOf[zone.key]
		if area == nil then
			fail(`data:ZoneAreas has no row {zone.key}`)
		end
		for _, row in spawns.rows do
			local weightCap = numbers(cell(spawns, row, spawnColumn :: string))
			if #weightCap == 0 or (slice and not row.inSlice) then
				continue -- "None": the prey does not spawn in this zone
			end
			local allowed = ids(prey, preyRow[row.key], "Zones (section 2.3)")
			if not table.find(allowed, zone.key) then
				fail(`data:PreySpawns, row {row.key}: {zone.key} is not in its data:Prey zones`)
			end
			local target = targetRow[row.key]
			if target == nil then
				fail(`data:PreyTargets has no row {row.key}`)
			end
			local text = cell(targets, target, targetColumn :: string)
			local counts = numbers(text)
			if #counts == 0 then
				fail(`data:PreyTargets, row {row.key}: no base count for {zone.key}`)
			end
			local counted = cell(targets, target, "Counted as")
			local members = (
				string.match(counted, "^Motes") ~= nil
				or string.match(counted, "^Animals") ~= nil
			) and string.find(text, "patches", 1, true) == nil
			local fields = {
				field("zone", zone.key),
				field("prey", row.key),
				field("weight", weightCap[1]),
				field("cap", weightCap[2]),
				field("base", counts[1]),
				field("baseUnit", if members then "members" else "groups"),
			}
			optional(fields, "perPlayerInside", counts[2])
			table.insert(fields, field("zoneArea", area :: number))
			table.insert(rows, fields)
		end
	end
	return {
		name = "PreySpawns",
		typeName = "PreySpawnDef",
		sources = {
			`{CATALOG} data:PreySpawns, data:ZoneAreas, data:Prey`,
			`{MECHANICS} data:PreyTargets`,
			`{CANON} data:Zones`,
		},
		rows = rows,
	}
end

-- Trait prey alive per zone: the trait prey rows of 02 §9.6 data:PreyTargets ("Animals"), one row
-- per zone with a count. No playerScale or eventScale (02 §9.6); areaScale applies, so each row
-- carries its zone's plan area. Event prey and the Crystal Jelly have no row there.
local function buildTraitPreySpawns(
	canon: Tables,
	mechanics: Tables,
	catalog: Tables,
	slice: boolean
): Module
	local targets = get(mechanics, MECHANICS, "PreyTargets")
	local traitPrey = keySet(get(catalog, CATALOG, "TraitPrey"))
	local areas = get(catalog, CATALOG, "ZoneAreas")
	local zones = get(canon, CANON, "Zones")
	local areaOf: { [string]: number } = {}
	for _, row in areas.rows do
		areaOf[row.key] = firstNumber(areas, row, "Plan area (studs²)")
	end
	local rows = {}
	for _, zone in zones.rows do
		local column = zoneColumn(targets, MarkdownTables.plain(cell(zones, zone, "Zone")))
		if column == nil or (slice and not zone.inSlice) then
			continue
		end
		for _, row in targets.rows do
			if not traitPrey[row.key] or (slice and not row.inSlice) then
				continue
			end
			local alive = numbers(cell(targets, row, column :: string))[1]
			if alive == nil then
				continue -- "—": not in this zone
			end
			local area = areaOf[zone.key]
			if area == nil then
				fail(`data:ZoneAreas has no row {zone.key}`)
			end
			table.insert(rows, {
				field("zone", zone.key),
				field("prey", row.key),
				field("alive", alive :: number),
				field("zoneArea", area :: number),
			})
		end
	end
	return {
		name = "TraitPreySpawns",
		typeName = "TraitPreySpawnDef",
		sources = {
			`{MECHANICS} data:PreyTargets`,
			`{CATALOG} data:TraitPrey, data:ZoneAreas`,
			`{CANON} data:Zones`,
		},
		rows = rows,
	}
end

-- A record literal from names and the numbers of a cell, in order; nil when the cell has none.
-- Names past the numbers given are left out (optional in the type).
local function record(text: string, names: { string }, required: number, where: string): string?
	local values = numbers(text)
	if #values == 0 then
		return nil
	end
	if #values < required or #values > #names then
		fail(`{where}: expected {required} to {#names} numbers, got {#values}: {text}`)
	end
	local parts = {}
	for i, value in values do
		table.insert(parts, `{names[i]} = {numberText(value)}`)
	end
	return `\{ {table.concat(parts, ", ")} \}`
end

-- Flee look settings (06 §7.6): "label number unit" parts after the style, joined by "·".
local FLEE_KEYS: { [string]: string } = {
	["wobble"] = "burstWobbleMult",
	["sway"] = "burstSwayMult",
	["hop"] = "hopMult",
	["regroup"] = "regroupS",
	["bank"] = "bankDeg",
	["turns"] = "turns",
	["pause"] = "pauseS",
	["roll"] = "rollStuds",
	["uncurl"] = "uncurlS",
	["deeper"] = "deeperStuds",
	["jet"] = "jetStuds",
	["ink"] = "inkS",
}

-- The prey motion table (06 §7.6, data:PreyMotion): how each prey and trait prey moves on the
-- client. Every ID must be in data:Prey or data:TraitPrey and every prey must have a row.
local function buildPreyMotion(art: Tables, catalog: Tables, slice: boolean): Module
	local t = get(art, ART, "PreyMotion")
	local known: { [string]: boolean } = {}
	for _, name in { "Prey", "TraitPrey" } do
		for key in keySet(get(catalog, CATALOG, name)) do
			known[key] = true
		end
	end
	local seen = keySet(t)
	for key in known do
		if not seen[key] then
			fail(`data:PreyMotion has no row {key}`)
		end
	end
	local rows = {}
	for _, row in rowsFor(t, slice) do
		if not known[row.key] then
			fail(`data:PreyMotion, row {row.key}: not in data:Prey or data:TraitPrey`)
		end
		local where = `data:PreyMotion, row {row.key}`
		local drawn = cell(t, row, "Drawn as")
		local fields = {
			field("id", row.key),
			field("scope", scope(t, row)),
			field("draw", ids(t, row, "Drawn as")[1] or MarkdownTables.plain(drawn)),
		}
		local function add(name: string, value: string?)
			if value ~= nil then
				table.insert(fields, { name = name, value = value })
			end
		end
		add(
			"wobble",
			record(
				cell(t, row, "Wobble (Hz, yaw °, roll °, bob studs)"),
				{ "hz", "yawDeg", "rollDeg", "bobStuds" },
				4,
				where
			)
		)
		add(
			"sway",
			record(
				cell(t, row, "Sway (Hz, swing °, Hz per stud/s; tail lag s)"),
				{ "hz", "ampDeg", "hzPerStudPerS", "tailLagS" },
				3,
				where
			)
		)
		add(
			"hop",
			record(
				cell(t, row, "Hop (height, length studs; time, rest s; hops in a row)"),
				{ "height", "length", "timeS", "restS", "count" },
				4,
				where
			)
		)
		local pulseCell = cell(t, row, "Pulse (Hz, size)")
		local pulseKind = ids(t, row, "Pulse (Hz, size)")[1]
		if pulseKind ~= nil then
			local values = numbers(pulseCell)
			local parts = { `kind = {literal(pulseKind)}`, `hz = {numberText(values[1])}` }
			if values[2] ~= nil then
				table.insert(parts, `amount = {numberText(values[2])}`)
			end
			add("pulse", `\{ {table.concat(parts, ", ")} \}`)
		end
		optional(fields, "driftSpeed", maybeNumber(t, row, "Drift (studs/s)"))
		local fleeCell = cell(t, row, "Flee look")
		local flee = { `style = {literal(oneId(t, row, "Flee look"))}` }
		local first = true
		for part in string.gmatch((string.gsub(fleeCell, "·", "|")), "[^|]+") do -- "·" is two bytes
			if first then
				first = false
				continue
			end
			local label = string.match(part, "^%s*(%a+)")
			local key = if label then FLEE_KEYS[label] else nil
			local value = numbers(part)[1]
			if key == nil or value == nil then
				fail(`{where}: unknown flee setting "{part}"`)
			end
			table.insert(flee, `{key} = {numberText(value :: number)}`)
		end
		add("flee", `\{ {table.concat(flee, ", ")} \}`)
		table.insert(rows, fields)
	end
	return {
		name = "PreyMotion",
		typeName = "PreyMotionDef",
		sources = { `{ART} data:PreyMotion`, `{CATALOG} data:Prey, data:TraitPrey` },
		rows = rows,
	}
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
		table.insert(fields, field("kind", MarkdownTables.plain(cell(t, row, "Kind"))))
		local subject = MarkdownTables.plain(cell(t, row, "Subject"))
		optional(fields, "subject", if subject == "None" then nil else subject)
		local pool = MarkdownTables.plain(cell(t, row, "Pool"))
		if pool ~= "eat" and pool ~= "grow" and pool ~= "world" then
			fail(`data:Goals, row {row.key}: unknown pool {pool}`)
		end
		table.insert(fields, field("pool", pool))
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
local mechanics = load(MECHANICS)
local economy = load(ECONOMY)
local art = load(ART)
local modules = {
	buildTiers(canon, economy, slice),
	buildRewardBands(economy, slice),
	buildBankRates(canon, slice),
	buildScraps(canon, slice),
	buildSlotPrices(economy, slice),
	buildReefRanks(economy, slice),
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
	buildCoveMouths(catalog, slice),
	buildPreySpawns(canon, mechanics, catalog, slice),
	buildTraitPreySpawns(canon, mechanics, catalog, slice),
	buildPreyMotion(art, catalog, slice),
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
