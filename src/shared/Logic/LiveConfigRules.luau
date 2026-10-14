--!strict
-- LiveConfigRules: the pure half of LiveConfig (docs/09, section 17.4; task S5-C5, module B33).
-- Which live-config keys the client needs and the `State` paths they travel on. Values are typed
-- and fall back to their defaults in Config/Flags. Pure, so it runs in Lune.
--
-- `ConfigService` is server-only, so LiveConfig forwards the keys the client needs through
-- `State` under `config.*` (09 §5.3: `config.flag.tideEvents`). The server's tolerances
-- (`tune.move.*`, `tune.bite.*`, `tune.prey.*`, `tune.econ.*`) stay on the server: the client
-- has no use for them, and an exploiter learns nothing from them.

local LiveConfigRules = {}

--- The key prefixes forwarded to clients: switches the interface follows (`flag.*`, `kill.*`),
--- live team values (`live.*`), client assists (`assist.*`) and the per-graphics-tier numbers
--- the client's renderers read (`tune.quality.*`).
LiveConfigRules.CLIENT_PREFIXES =
	table.freeze({ "flag.", "kill.", "live.", "assist.", "tune.quality." })

--- The root segment of every live-config `State` path (09 §5.3; Logic/StatePatch.CONFIG_ROOT).
LiveConfigRules.ROOT = "config"

--- Whether the client needs `key` (09 §17.4).
function LiveConfigRules.isClientKey(key: string): boolean
	for _, prefix in LiveConfigRules.CLIENT_PREFIXES do
		if string.sub(key, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

--- The `State` path that carries `key`: `config.<key>`.
function LiveConfigRules.pathOf(key: string): string
	return `{LiveConfigRules.ROOT}.{key}`
end

--- The live-config key a `State` path carries, or nil when the path is not under `config.`.
function LiveConfigRules.keyOf(path: string): string?
	local prefix = `{LiveConfigRules.ROOT}.`
	if #path > #prefix and string.sub(path, 1, #prefix) == prefix then
		return string.sub(path, #prefix + 1)
	end
	return nil
end

--- The client keys among `keys` whose value differs between `before` and `after` (the current
--- values of every key before and after a refresh): what a refresh must send. Sorted.
function LiveConfigRules.changedClientKeys(
	keys: { string },
	before: { [string]: any },
	after: { [string]: any }
): { string }
	local changed: { string } = {}
	for _, key in keys do
		if LiveConfigRules.isClientKey(key) and before[key] ~= after[key] then
			table.insert(changed, key)
		end
	end
	table.sort(changed)
	return changed
end

return LiveConfigRules
