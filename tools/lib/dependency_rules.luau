--!strict
-- The dependency rule of docs/09, section 4.4: shared/Logic, shared/Sim, shared/Net/Codec and
-- shared/Data must run in Lune, so they use numbers, tables, buffers and the standard library
-- only. A file there fails the gate when its code (comments and string text are ignored)
-- mentions `game`, `workspace`, `Instance.new`, `Vector3`, `CFrame` or `task.wait`.
-- Pure text in, findings out: tools/check.luau reads the files.

export type Violation = { line: number, token: string }

local DependencyRules = {}

DependencyRules.PURE_ROOTS = {
	"src/shared/Logic",
	"src/shared/Sim",
	"src/shared/Net/Codec",
	"src/shared/Data",
}

-- Globals that are banned wherever they appear as a name of their own.
local BANNED_NAMES = { game = true, workspace = true, Vector3 = true, CFrame = true }
-- Globals that are banned only with one member: Instance.new and task.wait.
local BANNED_MEMBERS = { Instance = "new", task = "wait" }

local function blank(text: string): string
	return (string.gsub(text, "[^\n]", " "))
end

-- The source with every comment and all string text replaced by spaces. Line breaks stay, so
-- line numbers still match. Code inside the braces of an interpolated string is kept.
local function codeOnly(source: string): string
	local out: { string } = {}
	local length = #source
	local braces: { number } = {} -- open-brace depth per interpolated string being read
	local at = 1

	local function skipTo(last: number)
		table.insert(out, blank(string.sub(source, at, last)))
		at = last + 1
	end

	-- Reads interpolated string text from `at` up to its closing backtick or the next `{`.
	local function template()
		local cursor = at
		while cursor <= length do
			local char = string.sub(source, cursor, cursor)
			if char == "\\" then
				cursor += 2
			elseif char == "`" then
				return skipTo(cursor)
			elseif char == "{" then
				table.insert(braces, 0)
				return skipTo(cursor)
			else
				cursor += 1
			end
		end
		skipTo(length)
	end

	while at <= length do
		local char = string.sub(source, at, at)
		local longOpen = string.match(source, "^%[(=*)%[", at)
		if string.sub(source, at, at + 1) == "--" then
			local level = string.match(source, "^%-%-%[(=*)%[", at)
			local stop: number?
			if level then
				_, stop = string.find(source, `]{level}]`, at, true)
			else
				local newline = string.find(source, "\n", at, true)
				stop = if newline then newline - 1 else nil
			end
			skipTo(stop or length)
		elseif longOpen then
			local _, stop = string.find(source, `]{longOpen}]`, at, true)
			skipTo(stop or length)
		elseif char == '"' or char == "'" then
			local cursor = at + 1
			while cursor <= length do
				local inside = string.sub(source, cursor, cursor)
				if inside == "\\" then
					cursor += 2
				elseif inside == char or inside == "\n" then
					break
				else
					cursor += 1
				end
			end
			skipTo(math.min(cursor, length))
		elseif char == "`" then
			skipTo(at)
			template()
		elseif char == "}" and #braces > 0 and braces[#braces] == 0 then
			table.remove(braces)
			skipTo(at)
			template()
		else
			if #braces > 0 and (char == "{" or char == "}") then
				braces[#braces] += if char == "{" then 1 else -1
			end
			table.insert(out, char)
			at += 1
		end
	end
	return table.concat(out)
end

--- Every banned use in one file's source, in reading order.
function DependencyRules.check(source: string): { Violation }
	local violations: { Violation } = {}
	local lineNumber = 0
	for line in string.gmatch(codeOnly(source) .. "\n", "(.-)\n") do
		lineNumber += 1
		for start, name, after in string.gmatch(line, "()([%a_][%w_]*)()") do
			-- `a.game` is a field of our own table, not the global; `a .. game` is the global.
			local before = string.match(string.sub(line, 1, start - 1), "(%.*)%s*$")
			local isField = before == "."
			local member = BANNED_MEMBERS[name]
			if isField then
				continue
			elseif BANNED_NAMES[name] then
				table.insert(violations, { line = lineNumber, token = name })
			elseif member and string.match(line, "^%s*%.%s*([%a_][%w_]*)", after) == member then
				table.insert(violations, { line = lineNumber, token = `{name}.{member}` })
			end
		end
	end
	return violations
end

--- Whether `path` (relative to the repository root) is under one of the pure roots.
function DependencyRules.applies(path: string): boolean
	for _, root in DependencyRules.PURE_ROOTS do
		if string.sub(path, 1, #root + 1) == root .. "/" then
			return true
		end
	end
	return false
end

return DependencyRules
