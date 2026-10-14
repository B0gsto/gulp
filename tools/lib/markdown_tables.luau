--!strict
-- Reads the marked content tables of the bible (docs/09, section 3.2). A table sits between
-- `<!-- data:NAME -->` and `<!-- /data -->`. The first line after the opening marker may name
-- the soft-launch slice (chapter 13, section 3.2):
--   Soft-launch slice (chapter 13, section 3.2): `id`, `id`.    the rows whose first cell is listed
--   Soft-launch slice (chapter 13, section 3.2): every row.
--   Soft-launch slice (chapter 13, section 3.2): no rows (...).
-- Pure text in, tables out: the generator reads the files. Errors are thrown with the table name
-- so a broken document stops the generator with a clear message.

export type Row = {
	cells: { [string]: string }, -- header text -> cell text, trimmed
	key: string, -- the first cell without backticks or bold marks
	position: number, -- 1-based among the table's data rows: the wire index
	inSlice: boolean,
}

export type Table = {
	name: string,
	header: { string },
	rows: { Row },
}

local MarkdownTables = {}

local SLICE_PREFIX = "Soft-launch slice"

local function trim(text: string): string
	return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

--- A cell without surrounding backticks or bold marks: "`glow`" and "**Glow**" read as the bare text.
function MarkdownTables.plain(cell: string): string
	local text = trim(cell)
	text = string.gsub(text, "^%*%*(.-)%*%*$", "%1")
	text = string.gsub(text, "^`(.-)`$", "%1")
	return text
end

local function splitRow(line: string): { string }
	local body = trim(line)
	body = string.gsub(body, "^|", "")
	body = string.gsub(body, "|$", "")
	local cells = {}
	for cell in string.gmatch(body .. "|", "([^|]*)|") do
		table.insert(cells, trim(cell))
	end
	return cells
end

local function isSeparator(line: string): boolean
	return string.match(line, "^%s*|[%s%-:|]+|%s*$") ~= nil
end

type Slice = { all: boolean, ids: { [string]: boolean } }

local function parseSlice(name: string, line: string): Slice
	local colon = string.find(line, ":", #SLICE_PREFIX + 1, true)
	local rest = if colon then trim(string.sub(line, colon + 1)) else nil
	if rest == nil or string.sub(line, 1, #SLICE_PREFIX) ~= SLICE_PREFIX then
		error(`data:{name}: malformed slice line: {line}`, 0)
	end
	if string.match(rest, "^every row") then
		return { all = true, ids = {} }
	end
	local ids: { [string]: boolean } = {}
	for id in string.gmatch(rest, "`([^`]+)`") do
		ids[id] = true
	end
	if next(ids) == nil and not string.match(rest, "^no rows") then
		error(`data:{name}: the slice line names no rows: {line}`, 0)
	end
	return { all = false, ids = ids }
end

local function parseBlock(name: string, lines: { string }): Table
	local slice: Slice? = nil
	local header: { string }? = nil
	local rows: { Row } = {}
	local tableEnded = false
	for _, line in lines do
		if string.match(line, "^%s*$") then
			if header ~= nil then
				tableEnded = true
			end
		elseif string.sub(line, 1, #SLICE_PREFIX) == SLICE_PREFIX then
			if header ~= nil or slice ~= nil then
				error(`data:{name}: the slice line must come before the table, once`, 0)
			end
			slice = parseSlice(name, line)
		elseif string.sub(trim(line), 1, 1) == "|" then
			if tableEnded then
				error(`data:{name}: more than one table between the markers`, 0)
			end
			if header == nil then
				header = splitRow(line)
			elseif not isSeparator(line) then
				local cells = splitRow(line)
				local names = header :: { string }
				if #cells ~= #names then
					error(
						`data:{name}: a row has {#cells} cells, the header has {#names}: {line}`,
						0
					)
				end
				local key = MarkdownTables.plain(cells[1])
				if key ~= "" then -- a total row ("| | **All five** | ...") is not data
					local byName: { [string]: string } = {}
					for i, column in names do
						byName[column] = cells[i]
					end
					table.insert(
						rows,
						{ cells = byName, key = key, position = #rows + 1, inSlice = false }
					)
				end
			end
		else
			error(`data:{name}: unexpected text between the markers: {line}`, 0)
		end
	end
	if header == nil then
		error(`data:{name}: no table between the markers`, 0)
	end
	if slice == nil then
		error(`data:{name}: no "{SLICE_PREFIX}" line after the opening marker`, 0)
	end
	local s = slice :: Slice
	local seen: { [string]: boolean } = {}
	for _, row in rows do
		row.inSlice = s.all or s.ids[row.key] == true
		seen[row.key] = true
	end
	for id in s.ids do
		if not seen[id] then
			error(`data:{name}: the slice names "{id}", which is not a row`, 0)
		end
	end
	return { name = name, header = header :: { string }, rows = rows }
end

--- Every marked table in `text`, by name. Nested or unclosed markers and duplicate names throw.
function MarkdownTables.parse(text: string): { [string]: Table }
	local found: { [string]: Table } = {}
	local current: string? = nil
	local block: { string } = {}
	for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
		local line = string.gsub(line, "\r$", "")
		local opened = string.match(line, "^%s*<!%-%- data:([%w_]+) %-%->%s*$")
		if opened ~= nil then
			if current ~= nil then
				error(`data:{opened} opens inside data:{current}`, 0)
			end
			if found[opened] ~= nil then
				error(`data:{opened} is marked twice`, 0)
			end
			current = opened
			block = {}
		elseif string.match(line, "^%s*<!%-%- /data %-%->%s*$") then
			if current == nil then
				error("<!-- /data --> without an opening marker", 0)
			end
			local name = current :: string
			found[name] = parseBlock(name, block)
			current = nil
		elseif current ~= nil then
			table.insert(block, line)
		end
	end
	if current ~= nil then
		error(`data:{current} is never closed`, 0)
	end
	return found
end

--- A number cell: thousands commas, a Unicode minus and a trailing unit or percent sign are
--- accepted ("1,200", "−60", "+10%"). Returns nil when the cell holds no single number.
function MarkdownTables.number(cell: string): number?
	local text = MarkdownTables.plain(cell)
	text = string.gsub(text, "\u{2212}", "-")
	text = string.gsub(text, ",", "")
	local digits = string.match(text, "^([%+%-]?%d+%.?%d*)%%?$")
	if digits == nil then
		return nil
	end
	return tonumber(digits)
end

return MarkdownTables
