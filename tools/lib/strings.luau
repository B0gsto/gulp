--!strict
-- The string table's text formats (docs/09, section 18.1; docs/08, section 14; task S5-C5):
--   * `assets/loc/strings.csv`, columns `key, context, en` (RFC 4180 quoting), the source of
--     `Data/Generated/Strings.luau` and the file uploaded as the cloud localisation table;
--   * chapter 08's text list (sections 14.1 to 14.12), whose rows the CSV copies: the key, the
--     English and the note for translators (the CSV's context);
--   * the keys client code asks `Loc.t` for.
-- Pure text in, values out: the generator and the specs read the files.

export type Row = { key: string, context: string, en: string }

local Strings = {}

Strings.HEADER = { "key", "context", "en" }

--- The records of a CSV text: a field may be quoted ("a, b"), with "" for a quote inside and line
--- breaks allowed inside quotes. Returns nil and why on a malformed text.
function Strings.parseCsv(text: string): ({ { string } }?, string?)
	local records: { { string } } = {}
	local record: { string } = {}
	local at, length, line = 1, #text, 1
	if string.sub(text, 1, 3) == "\239\187\191" then
		at = 4 -- a byte order mark
	end
	while at <= length do
		local field: string
		if string.sub(text, at, at) == '"' then
			local parts: { string } = {}
			local i = at + 1
			while true do
				local quote = string.find(text, '"', i, true)
				if quote == nil then
					return nil, `line {line}: unclosed quote`
				end
				table.insert(parts, string.sub(text, i, quote - 1))
				if string.sub(text, quote + 1, quote + 1) == '"' then
					table.insert(parts, '"')
					i = quote + 2
				else
					at = quote + 1
					break
				end
			end
			field = table.concat(parts)
			local _, breaks = string.gsub(field, "\n", "")
			line += breaks
		else
			local stop = string.find(text, "[,\r\n]", at) or length + 1
			field = string.sub(text, at, stop - 1)
			if string.find(field, '"', 1, true) then
				return nil, `line {line}: a quote inside an unquoted field`
			end
			at = stop
		end
		table.insert(record, field)
		local nextChar = string.sub(text, at, at)
		if nextChar == "," then
			at += 1
			if at > length then
				table.insert(record, "")
			end
		elseif nextChar == "\r" or nextChar == "\n" or nextChar == "" then
			at += if string.sub(text, at, at + 1) == "\r\n" then 2 else 1
			table.insert(records, record)
			record = {}
			line += 1
		else
			return nil, `line {line}: text after a closing quote`
		end
	end
	if #record > 0 then
		table.insert(records, record)
	end
	return records
end

local function quoted(field: string): string
	if
		string.find(field, '[,"\r\n]')
		or string.match(field, "^%s")
		or string.match(field, "%s$")
	then
		return `"{string.gsub(field, '"', '""')}"`
	end
	return field
end

--- The CSV text of `rows`, with the header line; LF line ends and a final line break.
function Strings.toCsv(rows: { Row }): string
	local lines = { table.concat(Strings.HEADER, ",") }
	for _, row in rows do
		table.insert(lines, `{quoted(row.key)},{quoted(row.context)},{quoted(row.en)}`)
	end
	return table.concat(lines, "\n") .. "\n"
end

--- The rows of a strings CSV text, checked: the header is `key,context,en`, every record has
--- three fields, and no key is empty or repeated. Returns nil and why on any problem.
function Strings.rowsOfCsv(text: string): ({ Row }?, string?)
	local records, why = Strings.parseCsv(text)
	if not records then
		return nil, why
	end
	local header = records[1]
	if header == nil or table.concat(header, ",") ~= table.concat(Strings.HEADER, ",") then
		return nil, `the header must be {table.concat(Strings.HEADER, ",")}`
	end
	local rows: { Row } = {}
	local seen: { [string]: number } = {}
	for i = 2, #records do
		local record = records[i]
		if #record ~= 3 then
			return nil, `record {i}: {#record} fields, not 3`
		end
		local key = record[1]
		if key == "" then
			return nil, `record {i}: empty key`
		end
		if seen[key] then
			return nil, `record {i}: "{key}" repeats record {seen[key]}`
		end
		seen[key] = i
		table.insert(rows, { key = key, context = record[2], en = record[3] })
	end
	return rows
end

--- The rows of chapter 08's text list, in document order: every `| \`key\` | English | Note |`
--- row of sections 14.1 to 14.12. Section 14.13's key patterns are not strings.
function Strings.rowsOfDocs(markdown: string): { Row }
	local rows: { Row } = {}
	local inList = false
	for line in string.gmatch(markdown, "([^\n]*)\n?") do
		local section = string.match(line, "^###? (%d+[%.%d]*)")
		if section then
			local major, minor = string.match(section, "^(%d+)%.?(%d*)")
			local m = tonumber(minor)
			inList = major == "14" and m ~= nil and m >= 1 and m <= 12
		elseif inList then
			local key, en, note = string.match(line, "^| `([^`]+)` | (.-) | (.-) |%s*$")
			if key then
				table.insert(rows, { key = key, context = note :: string, en = en :: string })
			end
		end
	end
	return rows
end

export type Use = { key: string, prefix: boolean }

--- The keys `source` asks `Loc.t` for: a quoted key (`Loc.t("bank.title")`) as itself, and an
--- interpolated one (`` Loc.t(`tier.{n}`) ``) as its literal start (`tier.`, `prefix` true).
--- Also every `nameKey = "..."` value, the keys passed to Loc.t through a row table.
function Strings.usedKeys(source: string): { Use }
	local uses: { Use } = {}
	for key in string.gmatch(source, 'Loc%.t%(%s*"([^"]+)"') do
		table.insert(uses, { key = key, prefix = false })
	end
	for key in string.gmatch(source, "Loc%.t%(%s*`([^`{]*){") do
		table.insert(uses, { key = key, prefix = true })
	end
	for key in string.gmatch(source, "Loc%.t%(%s*`([^`{]*)`") do
		table.insert(uses, { key = key, prefix = false })
	end
	for key in string.gmatch(source, 'nameKey%s*=%s*"([^"]+)"') do
		table.insert(uses, { key = key, prefix = false })
	end
	return uses
end

return Strings
