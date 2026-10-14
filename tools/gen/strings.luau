--!strict
-- Strings generator: assets/loc/strings.csv -> src/shared/Data/Generated/Strings.luau (docs/09,
-- section 18.1; task S5-C5, module B33).
--   lune run tools/gen/strings                   the English table from the CSV (committed)
--   lune run tools/gen/strings -- --from-docs    first rewrites the CSV from chapter 08's text
--                                                list (sections 14.1 to 14.12), then as above
-- The CSV (`key, context, en`) is also the file uploaded as the cloud localisation table, so it
-- is the source; tests/unit/tools/strings.spec checks it still matches chapter 08 word for word.
-- Every key must be well formed (Logic/LocFormat.isKey) and every parameter must take a
-- documented form, `{Name}` or `{1:int}` (V30).
local fs = require("@lune/fs")
local process = require("@lune/process")

local Files = require("../lib/files")
local LocFormat = require("../../src/shared/Logic/LocFormat")
local Strings = require("../lib/strings")

local CSV = "assets/loc/strings.csv"
local DOCS = "docs/08-ui-ux.md"
local OUTPUT = "src/shared/Data/Generated/Strings.luau"

local function fail(message: string): never
	error(`gen strings: {message}`, 0)
end

local function escaped(text: string): string
	local out = string.gsub(text, "\\", "\\\\")
	out = string.gsub(out, '"', '\\"')
	out = string.gsub(out, "\n", "\\n")
	return out
end

local function check(rows: { Strings.Row })
	for _, row in rows do
		if not LocFormat.isKey(row.key) then
			fail(`"{row.key}" is not a well-formed key`)
		end
		if row.en == "" then
			fail(`"{row.key}" has no English`)
		end
		for inside in string.gmatch(row.en, "{([^{}]*)}") do
			local named = string.match(inside, "^%u[%w_]*$")
			local numbered = string.match(inside, "^%d+$") or string.match(inside, "^%d+:%a+$")
			if not named and not numbered then
				fail(`"{row.key}": "\{{inside}\}" is not a documented parameter form`)
			end
		end
	end
end

local function render(rows: { Strings.Row }): string
	local sorted = table.clone(rows)
	table.sort(sorted, function(a, b)
		return a.key < b.key
	end)
	local lines = {
		"--!strict",
		"-- GENERATED, do not edit. Change assets/loc/strings.csv, then run",
		"-- `lune run tools/gen/strings` (docs/09, section 18.1).",
		"-- Source: assets/loc/strings.csv (the text list of docs/08-ui-ux.md, section 14).",
		"-- The English of every string key: Loc's fallback when the translator has no answer.",
		"local Strings: { [string]: string } = {",
	}
	for _, row in sorted do
		table.insert(lines, `\t["{row.key}"] = "{escaped(row.en)}",`)
	end
	table.insert(lines, "}")
	table.insert(lines, "")
	table.insert(lines, "return table.freeze(Strings)")
	return table.concat(lines, "\n") .. "\n"
end

Files.requireRepoRoot()
local args = table.clone(process.args)
if args[1] == "--" then
	table.remove(args, 1)
end
if args[1] == "--from-docs" then
	local rows = Strings.rowsOfDocs(fs.readFile(DOCS))
	if #rows == 0 then
		fail(`no rows found in {DOCS} section 14`)
	end
	fs.writeFile(CSV, Strings.toCsv(rows))
	print(`gen strings: wrote {#rows} rows from {DOCS} to {CSV}`)
elseif args[1] ~= nil then
	fail("usage: lune run tools/gen/strings [-- --from-docs]")
end

local rows, why = Strings.rowsOfCsv(fs.readFile(CSV))
if not rows then
	fail(`{CSV}: {why}`)
end
check(rows)
fs.writeFile(OUTPUT, render(rows))
print(`gen strings: wrote {#rows} strings to {OUTPUT}`)
