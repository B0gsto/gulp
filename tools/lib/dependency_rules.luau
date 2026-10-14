--!strict
-- The dependency rule of docs/09, section 4.4: shared/Logic, shared/Sim, shared/Net/Codec and
-- shared/Data must run in Lune, so they use numbers, tables, buffers and the standard library
-- only. A file there fails the gate when its code (comments and string text are ignored)
-- mentions `game`, `workspace`, `Instance.new`, `Vector3`, `CFrame` or `task.wait`.
--
-- The same section's "Only EconomyService changes Pearls" (docs/13, Sprint 5 acceptance): a file
-- under src/server other than Services/EconomyService.luau fails the gate when its code (comments
-- ignored) does any of these to the profile's `pearls` key:
--   1. assigns a field named `pearls`: `.pearls` then `=` or a compound `+= -= *= /= //= %= ^= ..=`
--      (`==` is a comparison and passes; `pearlsPaid` is another name and passes);
--   2. assigns an index of the literal string `pearls`: `["pearls"] =` (any quote, same operators);
--   3. passes the literal string `pearls` as an argument of a call named `patch` or `rawset`
--      (`DataService.patch(player, "pearls", n)`, `rawset(data, "pearls", n)`).
-- Engine specs (src/server/Tests) are exempt: they write spec-only Mock sessions. The schema and
-- migrations that create the key live in shared/Logic, outside the rule. A path held in a variable
-- (`patch(player, path, n)`) is not seen.
-- Pure text in, findings out: tools/check.luau reads the files.

export type Violation = { line: number, token: string }

local DependencyRules = {}

--- Where the Pearl rule looks, who may write Pearls, and what is exempt.
DependencyRules.PEARL_ROOT = "src/server"
DependencyRules.PEARL_OWNER = "src/server/Services/EconomyService.luau"
DependencyRules.PEARL_EXEMPT_ROOTS = { "src/server/Tests" }

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
-- With `keepStrings`, string text stays and only comments are blanked.
local function codeOnly(source: string, keepStrings: boolean?): string
	local out: { string } = {}
	local length = #source
	local braces: { number } = {} -- open-brace depth per interpolated string being read
	local at = 1

	local function skipTo(last: number, isString: boolean?)
		local text = string.sub(source, at, last)
		table.insert(out, if isString and keepStrings then text else blank(text))
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
				return skipTo(cursor, true)
			elseif char == "{" then
				table.insert(braces, 0)
				return skipTo(cursor, true)
			else
				cursor += 1
			end
		end
		skipTo(length, true)
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
			skipTo(stop or length, true)
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
			skipTo(math.min(cursor, length), true)
		elseif char == "`" then
			skipTo(at, true)
			template()
		elseif char == "}" and #braces > 0 and braces[#braces] == 0 then
			table.remove(braces)
			skipTo(at, true)
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

local ASSIGN = "%s*[%+%-%*/%%%^%.]*=()"
local PEARLS_STRING = { '"pearls"', "'pearls'", "`pearls`" }

local function lineAt(text: string, position: number): number
	local _, breaks = string.gsub(string.sub(text, 1, position - 1), "\n", "")
	return breaks + 1
end

-- True when the `=` that ended at `after - 1` is an assignment, not the first half of `==`.
local function assigns(text: string, after: number): boolean
	return string.sub(text, after, after) ~= "="
end

--- Every write of the `pearls` key in one server file's source (rules 1 to 3 above), in order.
function DependencyRules.pearlWrites(source: string): { Violation }
	local found: { { at: number, token: string } } = {}
	-- 1: on code with strings blanked, so text inside a string never matches.
	local code = codeOnly(source)
	for at, after in string.gmatch(code, "()%.%s*pearls%f[^%w_]" .. ASSIGN) do
		if assigns(code, after :: number) then
			table.insert(found, { at = at :: number, token = ".pearls =" })
		end
	end
	-- 2 and 3: on code with comments blanked and strings kept.
	local text = codeOnly(source, true)
	for at, after in string.gmatch(text, "()%[%s*[\"'`]pearls[\"'`]%s*%]" .. ASSIGN) do
		if assigns(text, after :: number) then
			table.insert(found, { at = at :: number, token = '["pearls"] =' })
		end
	end
	for _, name in { "patch", "rawset" } do
		for open in string.gmatch(text, `%f[%w_]{name}%s*()%(`) do
			local args = string.match(text, "^%b()", open :: number) or ""
			local inner = string.sub(args, 2, -2)
			local offset = (open :: number) + 1
			for piece in string.gmatch(inner .. ",", "([^,]*),") do
				if table.find(PEARLS_STRING, string.match(piece, "^%s*(.-)%s*$") :: string) then
					local lead = #(string.match(piece, "^%s*") :: string)
					table.insert(
						found,
						{ at = offset + lead, token = `{name}(..., "pearls", ...)` }
					)
				end
				offset += #piece + 1
			end
		end
	end
	table.sort(found, function(a, b)
		return a.at < b.at
	end)
	local violations: { Violation } = {}
	for _, hit in found do
		table.insert(violations, { line = lineAt(source, hit.at), token = hit.token })
	end
	return violations
end

--- Whether the Pearl rule checks `path` (relative to the repository root).
function DependencyRules.pearlRuleApplies(path: string): boolean
	local root = DependencyRules.PEARL_ROOT .. "/"
	if string.sub(path, 1, #root) ~= root or path == DependencyRules.PEARL_OWNER then
		return false
	end
	for _, exempt in DependencyRules.PEARL_EXEMPT_ROOTS do
		if string.sub(path, 1, #exempt + 1) == exempt .. "/" then
			return false
		end
	end
	return true
end

return DependencyRules
