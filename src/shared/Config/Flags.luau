--!strict
-- Flags: the one place code reads a live-config key from (docs/09, section 17.4): `flag.*`,
-- `kill.*`, `live.*`, `assist.*` and `tune.*`. The key names and their defaults are in
-- Config/Defaults; a key that is not there does not exist, and reading one is a programmer
-- mistake that throws.
--
-- The module holds the current values and never touches the engine, so it runs in Lune.
-- LiveConfig feeds it: on the server from the ConfigService snapshot, on the client from the
-- `config.*` paths of `State`. A missing or wrongly typed value falls back to the default and
-- logs once.
local Defaults = require("./Defaults")
local Log = require("../Util/Log")

export type LiveValue = Defaults.LiveValue

local TAG = "Flags"

local Flags = {}

local current: { [string]: LiveValue } = {}

local function defaultOf(key: string): LiveValue
	local value = Defaults.live[key]
	if value == nil then
		error(`Flags: unknown key "{key}". Add it to Config/Defaults first.`, 3)
	end
	return value
end

local function usable(raw: unknown, default: LiveValue): boolean
	if type(raw) ~= type(default) then
		return false
	end
	-- A number must be finite: NaN and infinity are never valid settings.
	return type(raw) ~= "number" or math.abs(raw :: number) < math.huge -- safe: checked to be a number
end

--- Whether `key` is a live-config key this build knows.
function Flags.isKnown(key: string): boolean
	return Defaults.live[key] ~= nil
end

--- Every known key, sorted. A new array each call.
function Flags.keys(): { string }
	local keys: { string } = {}
	for key in Defaults.live do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

--- The current value of `key`: the one last given to `set`, else the default.
function Flags.get(key: string): LiveValue
	local value = current[key]
	if value == nil then
		return defaultOf(key)
	end
	return value
end

--- The current value of a boolean key (`flag.*`, `kill.*`, `assist.*`).
function Flags.bool(key: string): boolean
	local value = Flags.get(key)
	if type(value) ~= "boolean" then
		error(`Flags.bool: "{key}" is a {type(value)}`, 2)
	end
	return value
end

--- The current value of a number key.
function Flags.number(key: string): number
	local value = Flags.get(key)
	if type(value) ~= "number" then
		error(`Flags.number: "{key}" is a {type(value)}`, 2)
	end
	return value
end

--- The current value of a string key.
function Flags.string(key: string): string
	local value = Flags.get(key)
	if type(value) ~= "string" then
		error(`Flags.string: "{key}" is a {type(value)}`, 2)
	end
	return value
end

export type TierValues = { Smooth: number, Balanced: number, Pretty: number }

-- `{"Smooth":a,"Balanced":b,"Pretty":c}` (any order, any spacing) → the three finite numbers.
local function parseTiers(raw: string): TierValues?
	local function field(name: string): number?
		local text = string.match(raw, `"{name}"%s*:%s*(%-?[%d%.]+)`)
		local n = if text then tonumber(text) else nil
		return if n and math.abs(n) < math.huge then n else nil
	end
	local smooth, balanced, pretty = field("Smooth"), field("Balanced"), field("Pretty")
	if smooth == nil or balanced == nil or pretty == nil then
		return nil
	end
	return { Smooth = smooth, Balanced = balanced, Pretty = pretty }
end

--- The current value of a per-graphics-tier JSON key (`tune.quality.*`, 09 §17.4): a JSON object
--- with a number for each of Smooth, Balanced and Pretty. A value that does not parse falls back
--- to the default and logs once. A new table each call: read it when the tier changes, not per
--- frame.
function Flags.tiers(key: string): TierValues
	local parsed = parseTiers(Flags.string(key))
	if parsed then
		return parsed
	end
	Log.once(
		"warn",
		TAG,
		`"{key}" is not a \{ Smooth, Balanced, Pretty \} object; using the default`
	)
	return parseTiers(defaultOf(key) :: string) :: TierValues -- safe: the defaults are checked by spec
end

--- Takes the value live config holds for `key`. Returns true when it was used. A missing (nil)
--- or wrongly typed value puts the key back on its default and logs once; a key this build does
--- not know is ignored and logged once, because the dashboard may be ahead of the code.
function Flags.set(key: string, raw: unknown): boolean
	local default = Defaults.live[key]
	if default == nil then
		Log.once("warn", TAG, `ignored unknown key "{key}"`)
		return false
	end
	if raw == nil then
		current[key] = nil
		Log.once("info", TAG, `"{key}" is not set; using the default {default}`)
		return false
	end
	if not usable(raw, default) then
		current[key] = nil
		local got = if type(raw) == "number" then "a number that is not finite" else type(raw)
		Log.once(
			"warn",
			TAG,
			`"{key}" needs a {type(default)}, got {got}; using the default {default}`
		)
		return false
	end
	current[key] = raw :: LiveValue -- safe: `usable` checked it has the default's type
	return true
end

--- Puts every key back on its default.
function Flags.reset()
	table.clear(current)
end

return Flags
