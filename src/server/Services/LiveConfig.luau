--!strict
-- LiveConfig: Roblox experience configs through `ConfigService` (docs/09, section 17.4, V22;
-- task S5-C5, module B33). Values are edited in the Creator Dashboard and reach running servers
-- in about 15 s to 1 minute.
--
--   * `GetConfigAsync` runs inside `pcall`; on failure every key stays on its default
--     (Config/Defaults) and the call is retried every RETRY_SECONDS, so a server that started
--     during an outage still picks up a kill switch later.
--   * `UpdateAvailable` → `Refresh` → every key is read again.
--   * `GetValue` returning nil, or a value of the wrong type, puts the key on its default and
--     logs once (Config/Flags.set). Game code reads values through Config/Flags only.
--   * `ConfigService` is server-only, so the keys the client needs (Logic/LiveConfigRules) are
--     forwarded through `State` under `config.*` (section 5.3): DataService owns the profile
--     roots of `State` and refuses `config.*`; LiveConfig is the only sender of the `config`
--     root. PlayerLifecycle calls `pushAll(player)` right after DataService's first state push,
--     and every later change goes to each player who has had that push.
--
-- Experiments (`GetConfigForPlayerAsync`, `ab.<key>`, `ab_exposed`) are task S13-C3.
local ConfigService = game:GetService("ConfigService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Defaults = require(ReplicatedStorage.Shared.Config.Defaults)
local Flags = require(ReplicatedStorage.Shared.Config.Flags)
local LiveConfigRules = require(ReplicatedStorage.Shared.Logic.LiveConfigRules)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local Server = require("../Net/Server")

-- What LiveConfig uses of a `ConfigSnapshot`; the engine spec passes plain tables shaped alike.
type Snapshot = {
	GetValue: (self: any, key: string) -> any,
	Refresh: (self: any) -> (),
	UpdateAvailable: RBXScriptSignal?,
}

local TAG = "LiveConfig"
local RETRY_SECONDS = 60

local LiveConfig = {}
LiveConfig.name = "LiveConfig"

local snapshot: Snapshot? = nil -- the ConfigService snapshot once fetched
local pushed: { [Player]: true } = {} -- players who have had `pushAll`
local sendHook: ((Player, string, any) -> ())? = nil -- engine spec only

local function send(player: Player, key: string)
	local path, value = LiveConfigRules.pathOf(key), Flags.get(key)
	if sendHook then
		sendHook(player, path, value)
	end
	Server.send(player, "State", path, value)
end

local function currentValues(): { [string]: Defaults.LiveValue }
	local values: { [string]: Defaults.LiveValue } = {}
	for _, key in Flags.keys() do
		values[key] = Flags.get(key)
	end
	return values
end

-- Reads every key from `source` (nil: ConfigService is unavailable, so every key goes back to
-- its default), then sends the client keys that changed to every player already pushed.
local function apply(source: Snapshot?)
	local keys = Flags.keys()
	local before = currentValues()
	if source then
		for _, key in keys do
			local ok, raw = pcall(source.GetValue, source, key)
			if not ok then
				Log.once("warn", TAG, `GetValue failed ({raw}); using the defaults for such keys`)
				raw = nil
			end
			Flags.set(key, raw)
		end
	else
		Flags.reset()
	end
	for _, key in LiveConfigRules.changedClientKeys(keys, before, currentValues()) do
		for player in pushed do
			send(player, key)
		end
	end
end

-- Fetches a snapshot with `fetch` in pcall and applies it; on failure applies the defaults.
-- Returns the snapshot, or nil when the fetch failed.
local function connect(fetch: () -> any): Snapshot?
	local ok, result = pcall(fetch)
	if not ok or type(result) ~= "table" and typeof(result) ~= "Instance" then
		Log.warn(TAG, `GetConfigAsync failed ({tostring(result)}); using Config/Defaults`)
		apply(nil)
		return nil
	end
	local source = result :: Snapshot
	if source.UpdateAvailable then
		source.UpdateAvailable:Connect(function()
			local refreshed, why = pcall(function()
				source:Refresh()
			end)
			if refreshed then
				apply(source)
			else
				Log.warn(TAG, `Refresh failed ({why}); keeping the current values`)
			end
		end)
	end
	apply(source)
	return source
end

local function fetchReal(): any
	return ConfigService:GetConfigAsync()
end

local function connectWithRetry()
	snapshot = connect(fetchReal)
	while snapshot == nil do
		task.wait(RETRY_SECONDS)
		snapshot = connect(fetchReal)
	end
end

--- Sends the client keys whose value is not the default (the client starts on the same
--- defaults) and marks `player` for later changes. PlayerLifecycle calls it once per join,
--- right after DataService.pushAll.
function LiveConfig.pushAll(player: Player)
	pushed[player] = true
	for _, key in Flags.keys() do
		if LiveConfigRules.isClientKey(key) and Flags.get(key) ~= Defaults.live[key] then
			send(player, key)
		end
	end
end

function LiveConfig.init() end

function LiveConfig.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		pushed[player] = nil
	end)
	task.spawn(connectWithRetry)
end

-- Engine-spec and Studio hooks (src/server/Tests/LiveConfigSpec, Main's LiveConfigSet). Not for
-- game code.
LiveConfig._test = table.freeze({
	--- Runs the fetch-and-apply step with `fetch` in place of `ConfigService:GetConfigAsync`.
	--- True when the fetch worked. Does not replace the real snapshot.
	connect = function(fetch: () -> any): boolean
		return connect(fetch) ~= nil
	end,
	--- Applies `values` (key → raw value) as if it were the snapshot; nil applies the defaults.
	apply = function(values: { [string]: any }?)
		if values == nil then
			apply(nil)
			return
		end
		apply({
			GetValue = function(_self: any, key: string): any
				return values[key]
			end,
			Refresh = function(_self: any) end,
		})
	end,
	--- Applies the real snapshot again (the defaults when there is none).
	restore = function()
		apply(snapshot)
	end,
	--- Records every State this service sends (nil to stop).
	onSend = function(hook: ((Player, string, any) -> ())?)
		sendHook = hook
	end,
	--- Whether the real ConfigService snapshot was fetched.
	connected = function(): boolean
		return snapshot ~= nil
	end,
})

return LiveConfig
