--!strict
-- StateStore: the client's mirror of its own saved and run state, fed by `State` patches (docs/09,
-- sections 5.2 and 5.3; task S4-C6, module B20). The server sends (path, value) pairs:
-- DataService one per top-level profile key at join, then what each patch changed; LiveConfig
-- uses `config.*` (section 17.4). Paths follow Logic/StatePatch. Read-only for the rest of the
-- client: nothing here is trusted by the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Flags = require(ReplicatedStorage.Shared.Config.Flags)
local LiveConfigRules = require(ReplicatedStorage.Shared.Logic.LiveConfigRules)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local StatePatch = require(ReplicatedStorage.Shared.Logic.StatePatch)

local Client = require("../Net/Client")

export type Observer = { Disconnect: (self: Observer) -> () }

type Watch = { path: string, fn: (any) -> (), live: boolean }

local TAG = "StateStore"

local StateStore = {}
StateStore.name = "StateStore"

local mirror: { [any]: any } = {}
local watches: { Watch } = {}

--- The current value at `path`, or nil when the server has not sent it. Tables are the mirror's
--- own: read them, do not change them.
function StateStore.get(path: string): any
	return StatePatch.get(mirror, path)
end

--- Calls `fn(value)` now with the current value at `path` and again after every patch that can
--- change it (the path itself, one inside it, or one above it). Disconnect to stop.
function StateStore.observe(path: string, fn: (any) -> ()): Observer
	local watch: Watch = { path = path, fn = fn, live = true }
	table.insert(watches, watch)
	task.spawn(fn, StatePatch.get(mirror, path))
	local observer = {}
	function observer.Disconnect(_self: Observer)
		watch.live = false
		local index = table.find(watches, watch)
		if index then
			table.remove(watches, index)
		end
	end
	return observer :: Observer
end

local function onState(path: unknown, value: unknown)
	if type(path) ~= "string" or not StatePatch.apply(mirror, path, value) then
		Log.warn(TAG, `bad State path {tostring(path)}`)
		return
	end
	-- `config.<key>`: a live-config value LiveConfig forwarded (09 §17.4). Client code reads it
	-- through Config/Flags, which types it and falls back to the default like the server.
	local liveKey = LiveConfigRules.keyOf(path)
	if liveKey then
		Flags.set(liveKey, value)
	end
	for _, watch in table.clone(watches) do
		if watch.live and StatePatch.touches(path, watch.path) then
			task.spawn(watch.fn, StatePatch.get(mirror, watch.path))
		end
	end
end

function StateStore.init() end

function StateStore.start()
	Client.on("State", onState)
	-- Studio only: lets an MCP Client `execute_luau` read the mirror, which runs in its own VM:
	--   return game.Players.LocalPlayer.PlayerScripts.Client.StateStoreGet:Invoke("pearls")
	if RunService:IsStudio() then
		local hook = Instance.new("BindableFunction")
		hook.Name = "StateStoreGet"
		hook.OnInvoke = function(path: string): string
			local ok, text = pcall(function()
				return game:GetService("HttpService"):JSONEncode(StateStore.get(path))
			end)
			return if ok then text else "unencodable"
		end
		hook.Parent = script.Parent.Parent
	end
end

return StateStore
