--!strict
-- The asset manifest (docs/07, sections 1.3, 1.5 and 16): every asset the build loads, by its
-- chapter 07 name, with its scope tag, its live status, its Roblox asset ID once uploaded, and
-- whether the file in the game is still a placeholder. Code refers to assets by name through
-- this module, never by a pasted asset ID.
--
-- The source is `assets/manifest.csv`. `lune run tools/gen/manifest` copies it into
-- `Config/AssetManifest.luau` (the CSV text as a string), so the game reads the same rows at
-- run time; `Manifest.load()` parses that copy. Pure: no `game`, no Instances (docs/09, 4.4).

export type Tag = "MVP" | "L" | "P1" | "P2"
export type Status = "not started" | "blocked" | "in progress" | "in review" | "done"

export type Entry = {
	name: string,
	tag: Tag,
	status: Status,
	id: number?, -- Roblox asset ID; nil until uploaded
	placeholder: boolean, -- true while the game loads the stand-in (07 §16)
	note: string, -- what a blocked row waits for (07 §1.5), or anything else worth saying
	line: number, -- line in the CSV, for messages
}

export type Manifest = {
	entries: { Entry }, -- in file order
	byName: { [string]: Entry },
}

export type Problem = { name: string, line: number, reason: string }

local Manifest = {}

-- docs/07, section 1.3: "name, tag, status, Roblox asset ID, placeholder yes/no", plus the note
-- section 1.5 asks for on a blocked row.
Manifest.COLUMNS = table.freeze({ "name", "tag", "status", "asset_id", "placeholder", "note" })

local TAGS: { [string]: Tag } = { MVP = "MVP", L = "L", P1 = "P1", P2 = "P2" }
local STATUSES: { [string]: Status } = {
	["not started"] = "not started",
	["blocked"] = "blocked",
	["in progress"] = "in progress",
	["in review"] = "in review",
	["done"] = "done",
}

-- Name prefixes of docs/07, section 1.2 that a build loads. `true`: the file is uploaded and
-- gets one Roblox asset ID. `false`: settings the game reads by name (an emitter's JSON, a
-- lighting preset, a six-face sky folder), so there is no single asset ID to record.
local PREFIXES: { [string]: boolean } = {
	M = true,
	T = true,
	A = true,
	SFX = true,
	MUS = true,
	FX = false,
	LGT = false,
	SKY = false,
}

--- True when the asset named `name` is uploaded as one file with one Roblox asset ID.
function Manifest.needsAssetId(name: string): boolean
	local prefix = string.match(name, "^(%u+)_")
	return prefix ~= nil and PREFIXES[prefix] == true
end

--- A chapter 07 name: a known prefix, then words of letters and digits joined by underscores.
function Manifest.isValidName(name: string): boolean
	local prefix = string.match(name, "^(%u+)_")
	if prefix == nil or PREFIXES[prefix] == nil then
		return false
	end
	for part in string.gmatch(string.sub(name, #prefix + 2) .. "_", "([^_]*)_") do
		if part == "" or string.find(part, "[^%w]") then
			return false
		end
	end
	return true
end

-- One CSV line into fields. Quoted fields may hold commas and doubled quotes ("").
local function splitLine(text: string, line: number): { string }
	local fields: { string } = {}
	local i, n = 1, #text
	while true do
		if string.sub(text, i, i) == '"' then
			local value = ""
			local j = i + 1
			while true do
				local quote = string.find(text, '"', j, true)
				if quote == nil then
					error(`manifest line {line}: unclosed quote`, 0)
				end
				value ..= string.sub(text, j, quote - 1)
				if string.sub(text, quote + 1, quote + 1) == '"' then
					value ..= '"'
					j = quote + 2
				else
					i = quote + 1
					break
				end
			end
			table.insert(fields, value)
			local after = string.sub(text, i, i)
			if after == "" then
				return fields
			elseif after ~= "," then
				error(`manifest line {line}: text after a closing quote`, 0)
			end
			i += 1
		else
			local comma = string.find(text, ",", i, true)
			if comma == nil then
				table.insert(fields, string.sub(text, i, n))
				return fields
			end
			table.insert(fields, string.sub(text, i, comma - 1))
			i = comma + 1
		end
	end
end

local function field(value: string): string
	if string.find(value, '[",]') then
		return '"' .. string.gsub(value, '"', '""') .. '"'
	end
	return value
end

local function parseRow(fields: { string }, line: number): Entry
	local function fail(message: string): never
		error(`manifest line {line}: {message}`, 0)
	end
	if #fields ~= #Manifest.COLUMNS then
		fail(`expected {#Manifest.COLUMNS} fields, found {#fields}`)
	end
	local name, tagText, statusText, idText, placeholderText, note =
		fields[1], fields[2], fields[3], fields[4], fields[5], fields[6]
	if not Manifest.isValidName(name) then
		fail(`"{name}" is not an asset name of docs/07, section 1.2`)
	end
	local tag = TAGS[tagText] or fail(`{name}: unknown tag "{tagText}" (MVP, L, P1 or P2)`)
	local status = STATUSES[statusText]
		or fail(`{name}: unknown status "{statusText}" (docs/07, section 1.5)`)
	local id: number? = nil
	if idText ~= "" then
		if not string.match(idText, "^[1-9]%d*$") then
			fail(`{name}: asset_id "{idText}" is not a positive whole number`)
		end
		if not Manifest.needsAssetId(name) then
			fail(`{name}: this kind of asset has no Roblox asset ID; leave asset_id empty`)
		end
		id = tonumber(idText)
	end
	local placeholder: boolean
	if placeholderText == "yes" then
		placeholder = true
	elseif placeholderText == "no" then
		placeholder = false
	else
		return fail(`{name}: placeholder must be yes or no, found "{placeholderText}"`)
	end
	if status == "done" and placeholder then
		fail(`{name}: a done row has its placeholder removed (docs/07, section 1.5)`)
	end
	local entry: Entry = {
		name = name,
		tag = tag :: Tag,
		status = status :: Status,
		id = id,
		placeholder = placeholder,
		note = note,
		line = line,
	}
	return table.freeze(entry)
end

--- Parses manifest CSV text. Errors with the line number on the first bad line, a wrong
--- header or a repeated name.
function Manifest.parse(text: string): Manifest
	local entries: { Entry } = {}
	local byName: { [string]: Entry } = {}
	local line = 0
	local sawHeader = false
	for raw in string.gmatch(text, "([^\n]*)\n?") do
		line += 1
		local content = string.gsub(raw, "\r$", "")
		if content == "" then
			continue
		end
		local fields = splitLine(content, line)
		if not sawHeader then
			if table.concat(fields, ",") ~= table.concat(Manifest.COLUMNS, ",") then
				error(
					`manifest line {line}: header must be {table.concat(Manifest.COLUMNS, ",")}`,
					0
				)
			end
			sawHeader = true
			continue
		end
		local entry = parseRow(fields, line)
		local earlier = byName[entry.name]
		if earlier then
			error(`manifest line {line}: {entry.name} is already on line {earlier.line}`, 0)
		end
		byName[entry.name] = entry
		table.insert(entries, entry)
	end
	if not sawHeader then
		error("manifest is empty: it needs at least the header line", 0)
	end
	return table.freeze({ entries = table.freeze(entries), byName = table.freeze(byName) })
end

--- The CSV text for `entries`, header first, one line per entry, ending in a newline.
function Manifest.encode(entries: { Entry }): string
	local lines = { table.concat(Manifest.COLUMNS, ",") }
	for _, entry in entries do
		table.insert(
			lines,
			table.concat({
				field(entry.name),
				entry.tag,
				entry.status,
				if entry.id then string.format("%d", entry.id) else "",
				if entry.placeholder then "yes" else "no",
				field(entry.note),
			}, ",")
		)
	end
	return table.concat(lines, "\n") .. "\n"
end

--- The row for `name`, or nil when the build does not load an asset of that name.
function Manifest.get(manifest: Manifest, name: string): Entry?
	return manifest.byName[name]
end

--- name → Roblox asset ID for every row that has one.
function Manifest.assetIds(manifest: Manifest): { [string]: number }
	local ids: { [string]: number } = {}
	for _, entry in manifest.entries do
		if entry.id then
			ids[entry.name] = entry.id
		end
	end
	return ids
end

--- The release check of docs/07, section 16: every row the build loads must be final. A row
--- fails while it is still a placeholder, or when it is final but has no asset ID although its
--- kind is uploaded (section 1.5: done means uploaded with the ID in the manifest).
function Manifest.releaseProblems(manifest: Manifest): { Problem }
	local problems: { Problem } = {}
	for _, entry in manifest.entries do
		if entry.placeholder then
			table.insert(problems, { name = entry.name, line = entry.line, reason = "placeholder" })
		elseif entry.id == nil and Manifest.needsAssetId(entry.name) then
			table.insert(
				problems,
				{ name = entry.name, line = entry.line, reason = "final but no asset ID" }
			)
		end
	end
	return problems
end

local loaded: Manifest? = nil

--- The manifest the build ships with (Config/AssetManifest), parsed once.
function Manifest.load(): Manifest
	if loaded == nil then
		loaded = Manifest.parse(require("../Config/AssetManifest"))
	end
	return loaded :: Manifest
end

return table.freeze(Manifest)
