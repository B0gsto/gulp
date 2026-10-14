--!strict
-- Asset manifest generator (docs/07, sections 1.3 and 16; docs/13, task S1-C7).
--   lune run tools/gen/manifest              assets/manifest.csv → src/shared/Config/AssetManifest.luau
--   lune run tools/gen/manifest -- rows      also rebuild the CSV's rows from docs/07 (the slice
--                                            rows of docs/13, section 3.2), keeping the status,
--                                            asset ID, placeholder flag and note of every name
--                                            already in it; new rows start as `not started`,
--                                            placeholder `yes`
--   add `skipped` to list every 07 row or name left out, with the reason
--   lune run tools/gen/manifest -- set <Name> asset_id=<n> status=<s> placeholder=yes|no note=<text>
--                                            change one row (the upload routine's write), then
--                                            regenerate as above; any subset of the fields
local fs = require("@lune/fs")
local process = require("@lune/process")

local AssetList = require("../lib/asset_list")
local Files = require("../lib/files")
local Manifest = require("../../src/shared/Data/Manifest")
local ManifestFiles = require("../lib/manifest_files")

Files.requireRepoRoot()

local wantRows, wantSkipped = false, false
local setName: string? = nil
local setFields: { [string]: string } = {}
local SETTABLE = { asset_id = true, status = true, placeholder = true, note = true }
local setAt = table.find(process.args, "set")
for index, arg in process.args do
	if setAt and index > setAt then
		if index == setAt + 1 then
			setName = arg
			continue
		end
		local key, value = string.match(arg, "^([%w_]+)=(.*)$")
		if not key or not SETTABLE[key] then
			error(`set: expected asset_id=, status=, placeholder= or note=, found {arg}`, 0)
		end
		setFields[key :: string] = value :: string
	elseif arg == "set" then
		continue
	elseif arg == "rows" then
		wantRows = true
	elseif arg == "skipped" then
		wantSkipped = true
	elseif arg ~= "--" then
		error(`unknown argument {arg}; usage: lune run tools/gen/manifest [-- rows] [skipped]`, 0)
	end
end

-- The 07 category of a section: its top-level number and heading word.
local CATEGORIES: { [string]: string } = {
	["2"] = "Species",
	["3"] = "Traits",
	["4"] = "Prey",
	["5"] = "Predators and hazards",
	["6"] = "Environment",
	["7"] = "Water and sky",
	["8"] = "Tide events",
	["9"] = "Visual effects",
	["10"] = "Lighting",
	["11"] = "Sound effects",
	["12"] = "Music",
	["13"] = "Store-page source art",
}

local function readExisting(): { [string]: Manifest.Entry }
	if not fs.isFile(ManifestFiles.CSV) then
		return {}
	end
	return Manifest.parse(fs.readFile(ManifestFiles.CSV)).byName
end

if wantRows then
	local result = AssetList.slice(AssetList.rows(fs.readFile(ManifestFiles.ASSET_LIST)))
	local existing = readExisting()
	local entries: { Manifest.Entry } = {}
	local counts: { [string]: number } = {}
	local kept: { [string]: boolean } = {}
	for index, item in result.names do
		local old = existing[item.name]
		kept[item.name] = true
		table.insert(entries, {
			name = item.name,
			tag = if old then old.tag else "MVP",
			status = if old then old.status else "not started",
			id = if old then old.id else nil,
			placeholder = if old then old.placeholder else true,
			note = if old then old.note else "",
			line = index + 1,
		})
		local category = CATEGORIES[string.match(item.section, "^(%d+)") or ""] or "?"
		counts[category] = (counts[category] or 0) + 1
	end
	for name in existing do
		if not kept[name] then
			print(`dropped {name}: no longer a slice row of docs/07`)
		end
	end
	fs.writeFile(ManifestFiles.CSV, Manifest.encode(entries))
	local order: { string } = {}
	for category in counts do
		table.insert(order, category)
	end
	table.sort(order)
	for _, category in order do
		print(`  {category}: {counts[category]}`)
	end
	print(`rows: wrote {#entries} names to {ManifestFiles.CSV} ({#result.skipped} left out)`)
	if wantSkipped then
		for _, skip in result.skipped do
			print(`  skipped 07 §{skip.section} {skip.asset}: {skip.reason}`)
		end
	end
end

if setName then
	-- One row, through the same parser and encoder, so the CSV keeps its exact format and every
	-- rule of Data/Manifest (a done row has no placeholder, IDs only for uploaded kinds) holds.
	if setAt and not setName then
		error("set: name the row", 0)
	end
	local current = Manifest.parse(fs.readFile(ManifestFiles.CSV))
	local old = current.byName[setName]
		or error(`set: {setName} is not a row of {ManifestFiles.CSV}`, 0)
	local entries: { Manifest.Entry } = {}
	for _, entry in current.entries do
		table.insert(entries, entry)
	end
	local fields = {
		old.name,
		old.tag,
		setFields.status or old.status,
		setFields.asset_id or (if old.id then string.format("%d", old.id) else ""),
		setFields.placeholder or (if old.placeholder then "yes" else "no"),
		setFields.note or old.note,
	}
	local line = {}
	for _, value in fields do
		table.insert(
			line,
			if string.find(value, '[",]')
				then '"' .. string.gsub(value, '"', '""') .. '"'
				else value
		)
	end
	-- Parse the changed row on its own, so every rule of Data/Manifest applies to it.
	local text = table.concat(Manifest.COLUMNS, ",") .. "\n" .. table.concat(line, ",") .. "\n"
	local changed = Manifest.parse(text).entries[1]
	entries[old.line - 1] = changed
	fs.writeFile(ManifestFiles.CSV, Manifest.encode(entries))
	print(
		`set: {setName} → status {changed.status}, asset_id {changed.id or "-"}, placeholder {if changed.placeholder
			then "yes"
			else "no"}`
	)
end

local csv = fs.readFile(ManifestFiles.CSV)
local manifest = Manifest.parse(csv) -- refuse to ship a manifest that does not parse
fs.writeFile(ManifestFiles.MODULE, ManifestFiles.moduleSource(csv))
print(`gen: {#manifest.entries} manifest rows → {ManifestFiles.MODULE}`)
