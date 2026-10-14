--!strict
-- Reads the asset tables of docs/07-asset-list.md and picks the rows of the soft-launch slice
-- (docs/13, sections 3.2 and 3.3), one manifest name per file. Pure text in, names out:
-- tools/gen/manifest.luau reads and writes the files.
--
-- Steps, each with its source:
--   1. Every table row of 07 sections 2 to 13 with an Asset and a Tag column.
--   2. Only [MVP] rows (07 §16: the release check covers [MVP] rows; the slice is cut from them).
--   3. Rows the build does not load are left out (see NOT_LOADED).
--   4. Rows the slice defers are left out (see the SLICE_* tables, 13 §3.2 and §3.3).
--   5. A grouped name becomes one name per file (`A, _B`, `_01–06`, and the `*` rows in EXPAND).
--   6. Kit pieces keep two thirds of their variants (13 §3.2, "about a third fewer").

export type Row = {
	section: string, -- 07 section, "2.2"
	asset: string, -- the Asset cell without backticks
	tag: string, -- "MVP", "L", "P1" or "P2"
	description: string,
}

export type Name = { name: string, section: string }

export type Skip = { asset: string, section: string, reason: string }

export type Result = { names: { Name }, skipped: { Skip } }

local AssetList = {}

local function trim(text: string): string
	return (string.match(text, "^%s*(.-)%s*$") or "")
end

local function cells(line: string): { string }
	local found: { string } = {}
	local inner = string.match(line, "^%s*|(.*)|%s*$") or ""
	for cell in string.gmatch(inner .. "|", "([^|]*)|") do
		table.insert(found, trim(cell))
	end
	return found
end

--- Step 1: every row of every asset table in sections 2 to 13 of chapter 07, in file order.
function AssetList.rows(markdown: string): { Row }
	local rows: { Row } = {}
	local lines: { string } = {}
	for line in string.gmatch(markdown, "([^\n]*)\n?") do
		table.insert(lines, (string.gsub(line, "\r$", "")))
	end
	local section = ""
	local assetColumn, tagColumn, descriptionColumn = 0, 0, 0
	local i = 1
	while i <= #lines do
		local line = lines[i]
		local number = string.match(line, "^##+%s+(%d+[%.%d]*)")
		if number then
			section = (string.gsub(number, "%.$", ""))
			assetColumn = 0
		elseif string.sub(line, 1, 1) == "|" then
			local next = lines[i + 1] or ""
			if string.match(next, "^|%s*:?%-%-%-") then
				-- A header line: find the columns, then skip the separator.
				assetColumn, tagColumn, descriptionColumn = 0, 0, 0
				for index, cell in cells(line) do
					local heading = string.gsub(cell, "%*", "")
					if heading == "Asset" then
						assetColumn = index
					elseif heading == "Tag" then
						tagColumn = index
					elseif heading == "Description" then
						descriptionColumn = index
					end
				end
				if tagColumn == 0 then
					assetColumn = 0
				end
				i += 1
			elseif assetColumn > 0 then
				local major = tonumber(string.match(section, "^(%d+)")) or 0
				local row = cells(line)
				local tag = string.match(row[tagColumn] or "", "^%[(%w+)%]$")
				if major >= 2 and major <= 13 and tag then
					table.insert(rows, {
						section = section,
						asset = (string.gsub(row[assetColumn], "`", "")),
						tag = tag,
						description = row[descriptionColumn] or "",
					})
				end
			end
		else
			assetColumn = 0
		end
		i += 1
	end
	return rows
end

-- PascalCase words of one name part: "OldScarNear" → Old, Scar, Near; "T1T2" → T1, T2.
local function words(part: string): { string }
	local found: { string } = {}
	for word in string.gmatch(part, "%u?[%l%d]*") do
		if word ~= "" then
			table.insert(found, word)
		end
	end
	return found
end

-- True when some part of `name` holds `sequence` as consecutive whole words.
local function hasWords(name: string, sequence: { string }): boolean
	for part in string.gmatch(name, "[^_]+") do
		local list = words(part)
		for start = 1, #list - #sequence + 1 do
			local match = true
			for offset, word in sequence do
				if list[start + offset - 1] ~= word then
					match = false
					break
				end
			end
			if match then
				return true
			end
		end
	end
	return false
end

-- Step 3. Rows with no file the game loads, so nothing to look up and nothing to check.
local function notLoaded(row: Row): string?
	if string.sub(row.asset, 1, 1) == "(" then
		return "a task, not a file (07 §1.1)"
	elseif string.find(row.description, "Source only, not uploaded", 1, true) then
		return "source only, not uploaded (07 §2.0)"
	elseif string.match(row.asset, "^RIG_") then
		return "a skeleton travels inside its mesh file (07 §1.3)"
	elseif string.match(row.asset, "^SCN_") then
		return "store-page source art, not loaded by the game (07 §13, document 11)"
	end
	return nil
end

-- Step 4. Whole 07 sections the slice defers (13 §3.2, §3.3).
local SLICE_SECTIONS: { [string]: string } = {
	["5.1"] = "Gull deferred (13 §3.2)",
	["5.2"] = "Moray deferred (13 §3.2)",
	["5.5"] = "Old Scar deferred (13 §3.2)",
	["6.5"] = "The Drop-off deferred (13 §3.2)",
	["8.2"] = "Moon Tide deferred (13 §3.2, §3.3 Tide events)",
}

-- Step 4. Words that mark deferred content wherever they appear in a name (13 §3.2, §3.3).
local SLICE_WORDS: { { words: { string }, reason: string } } = {
	{
		words = { "Eel" },
		reason = "the Eel and eel holes deferred (13 §3.3 Species, Environment)",
	},
	{ words = { "Slip" }, reason = "Slip is the Eel's ability (13 §3.3 Species)" },
	{ words = { "Crest" }, reason = "the three Leviathan crests deferred (13 §3.3 Species)" },
	{ words = { "Longfin" }, reason = "Longfin deferred (13 §3.2 Traits)" },
	{ words = { "Ink" }, reason = "Ink deferred (13 §3.2 Traits)" },
	{ words = { "Crystal" }, reason = "Crystal deferred (13 §3.2 Traits)" },
	{ words = { "Moonlit" }, reason = "Moonlit deferred (13 §3.2 Traits)" },
	{ words = { "Moon" }, reason = "Moon Tide deferred (13 §3.2 Tide events)" },
	{ words = { "Moonbeam" }, reason = "Moon Tide deferred (13 §3.2 Tide events)" },
	{ words = { "Lunar" }, reason = "Lunar Fry deferred (13 §3.2 Trait prey)" },
	{ words = { "Bonito" }, reason = "Bonito deferred (13 §3.2 Prey)" },
	{ words = { "Tuna" }, reason = "Tuna deferred (13 §3.2 Prey)" },
	{ words = { "Ribbonfish" }, reason = "Ribbonfish deferred (13 §3.2 Trait prey)" },
	{ words = { "Inklet" }, reason = "Inklet deferred (13 §3.2 Trait prey)" },
	{ words = { "Gull" }, reason = "Gull deferred (13 §3.2 Predators)" },
	{ words = { "Feather" }, reason = "Gull feathers: Gull deferred (13 §3.2)" },
	{ words = { "Moray" }, reason = "Moray deferred (13 §3.2 Predators)" },
	{ words = { "Old", "Scar" }, reason = "Old Scar deferred (13 §3.2 Predators)" },
	{ words = { "Hook" }, reason = "hook deferred (13 §3.2 Hazards)" },
	{ words = { "Bait" }, reason = "hook set deferred (13 §3.3 Predators and hazards)" },
	{ words = { "Bobber" }, reason = "hook set deferred (13 §3.3 Predators and hazards)" },
	{ words = { "Fishing" }, reason = "hook set deferred (13 §3.3 Predators and hazards)" },
	{ words = { "Vent" }, reason = "cold vents deferred (13 §3.2 Hazards)" },
	{ words = { "Drop", "Off" }, reason = "The Drop-off deferred (13 §3.2 Zones)" },
}

-- Step 4. Single names the slice defers that no word above catches.
local SLICE_NAMES: { [string]: string } = {
	T_TraitPrey_02_Alb = "deferred by name in 13 §3.3 Prey",
	T_TraitPrey_03_Alb = "deferred by name in 13 §3.3 Prey",
	A_SleepyClam_Snore = "Sleepy Clam landmark deferred (13 §3.3 choice 4)",
	M_Cove_CodexStone = "Codex stone deferred (13 §3.2 Cove)",
	M_Cove_PerchNet = "perch net deferred (13 §3.2 Cove)",
	M_Cove_TrophyRock = "trophy rock deferred (13 §3.2 Cove)",
	MUS_Danger = "not one of the ten licensed tracks (13 §3.2 Audio)",
	MUS_Theme = "not one of the ten licensed tracks (13 §3.2 Audio)",
	FX_Coldline = "lies across The Crack, a Drop-off landmark (13 §3.2 Zones)",
	SFX_Amb_WhaleFar = "Drop-off ambience (07 §11.6; 13 §3.3 choice 1)",
	SFX_Amb_WreckGroan = "Tin Pickle ambience, Drop-off (07 §11.6; 13 §3.3 choice 1)",
}

-- Step 4. The five landmarks in the slice (13 §3.2); every other `_LM_` piece is deferred.
local SLICE_LANDMARKS: { [string]: boolean } = {
	LittleArch = true,
	NogginRock = true,
	Hoop = true,
	OldAnchor = true,
	PeekabooRidge = true,
}

local function deferred(name: string, section: string): string?
	local whole = SLICE_SECTIONS[section]
	if whole then
		return whole
	end
	local single = SLICE_NAMES[name]
	if single then
		return single
	end
	local landmark = string.match(name, "_LM_(%w+)")
	if landmark and not SLICE_LANDMARKS[landmark] then
		return `landmark {landmark} deferred (13 §3.3 choice 4)`
	end
	for _, rule in SLICE_WORDS do
		if hasWords(name, rule.words) then
			return rule.reason
		end
	end
	return nil
end

-- Step 5. Rows whose Asset cell uses `*` or `<…>`: the files each covers, from the row's own
-- description and the tables it points to. Suffix order follows 07 §1.2 (age, form, LOD, shell).
local function crossed(bases: { string }, lods: { string }, shells: { string }): { string }
	local found: { string } = {}
	for _, base in bases do
		for _, lod in lods do
			for _, shell in shells do
				table.insert(found, base .. lod .. shell)
			end
		end
	end
	return found
end

local MINNOW = { "M_Species_Minnow_Juv", "M_Species_Minnow_Adult" }
local PUFFER = {
	"M_Species_Puffer_Juv",
	"M_Species_Puffer_Adult",
	"M_Species_Puffer_Juv_Puffed",
	"M_Species_Puffer_Adult_Puffed",
}
local NO_LOD = { "", "_LOD1", "_LOD2" }

local function join(first: { string }, second: { string }): { string }
	local found = table.clone(first)
	table.move(second, 1, #second, #found + 1, found)
	return found
end
local BOTH_SHELLS = { "_Shell", "_ShellThick" }

local EXPAND: { [string]: { string } } = {
	-- 07 §2.2: "half and quarter triangle versions of each mesh"; shells "for the juvenile and
	-- the adult, each with its two distance versions".
	["M_Species_Minnow_*_LOD1, _LOD2"] = crossed(MINNOW, { "_LOD1", "_LOD2" }, { "" }),
	["M_Species_Minnow_*_Shell, _ShellThick"] = crossed(MINNOW, NO_LOD, BOTH_SHELLS),
	-- 07 §2.3: the same for the juvenile, the adult and the two puffed meshes.
	["M_Species_Puffer_*_LOD1, _LOD2"] = crossed(PUFFER, { "_LOD1", "_LOD2" }, { "" }),
	["M_Species_Puffer_*_Shell, _ShellThick"] = crossed(PUFFER, NO_LOD, BOTH_SHELLS),
	-- 07 §4.0: "the seven prey of tier 1 or more" (07 §4.1 names them).
	["M_Prey_*_Shell"] = crossed({
		"M_Prey_Krill",
		"M_Prey_Shrimp",
		"M_Prey_Sardine",
		"M_Prey_Darter",
		"M_Prey_Mackerel",
		"M_Prey_Bonito",
		"M_Prey_Tuna",
	}, { "" }, { "_Shell" }),
	-- 07 §4.0: "Reef Darter, Mackerel, Bonito and Tuna".
	["M_Prey_*_LOD2"] = crossed({
		"M_Prey_Darter",
		"M_Prey_Mackerel",
		"M_Prey_Bonito",
		"M_Prey_Tuna",
	}, { "_LOD2" }, { "" }),
	-- 07 §4.0: shells for the nine soft-launch trait prey of 07 §4.2, distance versions for
	-- the three of tier 3 (Ribbonfish, Inklet, Crystal Jelly).
	["M_Prey_<trait prey>_Shell, _LOD2 (soft launch)"] = join(
		crossed({
			"M_Prey_Glowfry",
			"M_Prey_ZebraDarter",
			"M_Prey_DottedGoby",
			"M_Prey_LunarFry",
			"M_Prey_ArmorShrimp",
			"M_Prey_UrchinPuff",
			"M_Prey_Ribbonfish",
			"M_Prey_Inklet",
			"M_Prey_CrystalJelly",
		}, { "" }, { "_Shell" }),
		crossed(
			{ "M_Prey_Ribbonfish", "M_Prey_Inklet", "M_Prey_CrystalJelly" },
			{ "_LOD2" },
			{ "" }
		)
	),
	-- 07 §5.3: "distance versions, and two outline shells with their own distance versions".
	["M_Pred_Barracuda_LOD1, _LOD2, _Shell, _ShellThick"] = join(
		{ "M_Pred_Barracuda_LOD1", "M_Pred_Barracuda_LOD2" },
		crossed({ "M_Pred_Barracuda" }, NO_LOD, BOTH_SHELLS)
	),
}

-- Rows 07 lists without naming their files; they need names in 07 before they can be tracked.
local UNNAMED: { [string]: string } = {
	["M_Env_CausticShell_*"] = "07 §7 does not name the files (one per Nursery and Reef floor chunk)",
}

-- Step 5, the generic part: `A, B` and `A, _X` (the suffix replaces as many trailing parts of
-- the first name), and a numbered range `_01–06` anywhere in a name.
local function expandRange(name: string): { string }
	local before, first, last, after = string.match(name, "^(.-_)(%d+)–(%d+)(.*)$")
	if not before then
		before, first, last, after = string.match(name, "^(.-_)(%d+)%-(%d+)(.*)$")
	end
	if not before then
		local single = string.match(name, "^(.-)%s*$") or name
		return { single }
	end
	local found: { string } = {}
	local width = #first
	for number = tonumber(first) :: number, tonumber(last) :: number do
		table.insert(found, before .. string.format(`%0{width}d`, number) .. after)
	end
	return found
end

local function expand(asset: string): { string }
	local listed = EXPAND[asset]
	if listed then
		return table.clone(listed)
	end
	local parts = string.split(asset, ", ")
	local base = parts[1]
	local baseParts = string.split(base, "_")
	local names: { string } = {}
	for _, part in parts do
		local full = part
		if string.sub(part, 1, 1) == "_" then
			local suffix = string.split(string.sub(part, 2), "_")
			local kept = table.move(baseParts, 1, #baseParts - #suffix, 1, {})
			full = table.concat(kept, "_") .. "_" .. table.concat(suffix, "_")
		end
		for _, name in expandRange(full) do
			table.insert(names, name)
		end
	end
	return names
end

-- Step 6. Kit pieces in 07 §6.1 to §6.4 that 13 §3.2 thins: "about a third fewer variants of
-- floor, rock, coral and kelp pieces". A range of n variants keeps n − floor(n / 3), the
-- lowest numbers first. Landmark pieces are not kit pieces and keep every part.
local THINNED_SECTIONS = { ["6.1"] = true, ["6.2"] = true, ["6.3"] = true, ["6.4"] = true }

local function thinned(name: string, section: string): boolean
	if not THINNED_SECTIONS[section] or string.find(name, "_LM_", 1, true) then
		return false
	end
	return hasWords(name, { "Floor" })
		or hasWords(name, { "Rock" })
		or hasWords(name, { "Coral" })
		or string.match(name, "^M_Env_Kelp_") ~= nil
end

--- Steps 2 to 6: the manifest names of the soft-launch slice, in 07 order, and every row or
--- name left out with the reason. Errors on a `*` row that EXPAND does not cover.
function AssetList.slice(rows: { Row }): Result
	local names: { Name } = {}
	local skipped: { Skip } = {}
	local seen: { [string]: boolean } = {}
	for _, row in rows do
		if row.tag ~= "MVP" then
			continue
		end
		local reason = notLoaded(row)
			or UNNAMED[row.asset]
			or deferred(string.gsub(row.asset, "%s*%(.*%)$", ""), row.section)
		if reason then
			table.insert(skipped, { asset = row.asset, section = row.section, reason = reason })
			continue
		end
		if string.find(row.asset, "[%*<]") and EXPAND[row.asset] == nil then
			error(`07 §{row.section}: {row.asset} covers several files; add it to EXPAND`, 0)
		end
		local expanded = expand(row.asset)
		local keep = #expanded
		local ranged = string.find(row.asset, "%d–%d") or string.find(row.asset, "%d%-%d")
		if ranged and thinned(expanded[1], row.section) then
			keep = #expanded - math.floor(#expanded / 3)
		end
		for index, name in expanded do
			local why = deferred(name, row.section)
			if why == nil and index > keep then
				why = "a third fewer kit variants (13 §3.2, 07 §17.1)"
			end
			if why then
				table.insert(skipped, { asset = name, section = row.section, reason = why })
			elseif seen[name] then
				error(`07 §{row.section}: {name} is listed twice`, 0)
			else
				seen[name] = true
				table.insert(names, { name = name, section = row.section })
			end
		end
	end
	return { names = names, skipped = skipped }
end

AssetList.expand = expand
AssetList.hasWords = hasWords

return AssetList
