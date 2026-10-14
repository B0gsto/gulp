--!strict
-- LocFormat: the pure half of text by key (docs/09, section 18.1; docs/08, section 14.0; task
-- S5-C5, module B33). Key validation and parameter substitution for the English fallback, so
-- the client's Loc fills a string the same way Roblox's `Translator:FormatByKey` does. Pure, so
-- it runs in Lune.
--
-- Parameters take the documented forms (V30): `{Name}` filled from a dictionary of arguments,
-- and `{1}` or `{1:int}` filled from an array. Text is never built by concatenation.

export type Args = { [string]: any } | { any }

local LocFormat = {}

--- Whether `key` is a well-formed string key: two or more dot-separated segments of lowercase
--- letters, digits and underscores, starting with a prefix of 08 §14 (`common.ok`,
--- `species.minnow`, `tier.1`, `spec.mass`).
function LocFormat.isKey(key: string): boolean
	if #key > 100 or not string.match(key, "^[a-z][a-z0-9_]*%.") then
		return false
	end
	for segment in string.gmatch(key .. ".", "([^.]*)%.") do
		if not string.match(segment, "^[a-z0-9_]+$") then
			return false
		end
	end
	return true
end

--- The parameter names of `template`, in order of first appearance: `Name` for `{Name}`, `1`
--- for `{1}` and `{1:int}`. A new array each call.
function LocFormat.params(template: string): { string }
	local names: { string } = {}
	for inside in string.gmatch(template, "{([^{}]*)}") do
		local name = string.match(inside, "^([%w_]+)") or inside
		if not table.find(names, name) then
			table.insert(names, name)
		end
	end
	return names
end

-- One argument as text. `int` rounds a number to a whole one, as FormatByKey's `{1:int}` does.
local function render(value: any, format: string?): string
	if format == "int" and type(value) == "number" then
		return string.format(
			"%d",
			if value >= 0 then math.floor(value + 0.5) else -math.floor(-value + 0.5)
		)
	end
	return tostring(value)
end

--- `template` with its parameters filled from `args`. A parameter with no argument stays as
--- written (`{Name}`), so a missing argument is visible but never breaks the screen.
function LocFormat.format(template: string, args: Args?): string
	if args == nil then
		return template
	end
	local given = args :: { [any]: any }
	return (
		string.gsub(template, "{([^{}]*)}", function(inside: string): string
			local name, format = string.match(inside, "^([%w_]+):(%a+)$")
			name = name or inside
			local index = if string.match(name :: string, "^%d+$") then tonumber(name) else nil
			local value = if index then given[index] else given[name]
			if value == nil then
				return `\{{inside}\}` -- kept as written
			end
			return render(value, format)
		end)
	)
end

return LocFormat
