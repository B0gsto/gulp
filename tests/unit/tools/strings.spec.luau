--!strict
local fs = require("@lune/fs")

local Files = require("../../../tools/lib/files")
local LocFormat = require("../../../src/shared/Logic/LocFormat")
local Strings = require("../../../tools/lib/strings")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local CSV = "assets/loc/strings.csv"

local function csvRows(): { Strings.Row }
	local rows, why = Strings.rowsOfCsv(fs.readFile(CSV))
	if not rows then
		error(`{CSV}: {why}`, 0)
	end
	return rows
end

describe("Strings CSV format", function()
	it("parses quoted fields, doubled quotes, commas and line breaks", function()
		local records = Strings.parseCsv('a,"b, c","say ""hi"""\r\nd,"two\nlines",\n')
		expect(records).toEqual({ { "a", "b, c", 'say "hi"' }, { "d", "two\nlines", "" } })
	end)

	it("refuses an unclosed quote and a stray quote", function()
		expect(Strings.parseCsv('a,"b\n')).toBe(nil)
		expect(Strings.parseCsv('a,b"c\n')).toBe(nil)
	end)

	it("writes what it reads", function()
		local rows = {
			{ key = "common.ok", context = "Button", en = "OK" },
			{
				key = "common.per_hour",
				context = 'For example "120 an hour", plain',
				en = "{Amount} an hour",
			},
		}
		expect(Strings.rowsOfCsv(Strings.toCsv(rows))).toEqual(rows)
	end)

	it("refuses a wrong header, a short record and a repeated key", function()
		expect(Strings.rowsOfCsv("key,context,en\na.b,c,d\n")).toBe(nil)
		expect(Strings.rowsOfCsv("Key,Context,Example,Source\na.b,c,d\n")).toBe(nil)
		expect(Strings.rowsOfCsv("Key,Context,Example,Source\na.b,c,,d\na.b,e,,f\n")).toBe(nil)
	end)
end)

describe("assets/loc/strings.csv", function()
	it("is chapter 08's text list, sections 14.1 to 14.12, word for word", function()
		local docs = Strings.rowsOfDocs(fs.readFile("docs/08-ui-ux.md"))
		expect(#docs).toBe(426) -- 08 §14.13: "426 strings in sections 14.1 to 14.12"
		expect(csvRows()).toEqual(docs)
	end)

	it("has well-formed keys and only documented parameter forms", function()
		for _, row in csvRows() do
			expect(LocFormat.isKey(row.key)).toBe(true)
			for _, name in LocFormat.params(row.en) do
				local ok = string.match(name, "^%u[%w_]*$") ~= nil
					or string.match(name, "^%d+$") ~= nil
				expect(ok).toBe(true)
			end
		end
	end)

	it("holds every key the client UI asks Loc for", function()
		local known: { [string]: true } = {}
		local rows = csvRows()
		for _, row in rows do
			known[row.key] = true
		end
		local missing: { string } = {}
		local files = Files.walk("src/client", ".luau")
		for _, path in files do
			for _, use in Strings.usedKeys(fs.readFile(path)) do
				local found = known[use.key] == true
				if use.prefix then
					for _, row in rows do
						if string.sub(row.key, 1, #use.key) == use.key then
							found = true
							break
						end
					end
				end
				if not found then
					table.insert(missing, `{path}: {use.key}`)
				end
			end
		end
		expect(missing).toEqual({})
	end)
end)
