--!strict
-- ServerScriptService.Server.Main: the ordered loader (docs/09, section 4.5). No framework.
-- Services are required one per line, in the order of section 4.5, so the type checker sees
-- them. `init` sets up private state and must not yield or call another service; `start`
-- connects events and begins loops. PlayerLifecycle is always last.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Defaults = require(ReplicatedStorage.Shared.Config.Defaults)
local Types = require(ReplicatedStorage.Shared.Types)

type Service = Types.Service

-- Creates every remote of docs/09, section 5.3 before any service runs, so clients waiting in
-- Net/Client find them even while no service has registered a handler yet.
require(script.Parent.Net.Server)

-- Section 4.5's order, listing only the services written so far; each task adds its own.
local loaded: { Service } = {
	require(script.Parent.Services.LiveConfig),
	require(script.Parent.Services.DataService),
	require(script.Parent.Services.WorldIndex),
	require(script.Parent.Services.CreatureService),
	require(script.Parent.Services.PreyService),
	require(script.Parent.Services.BiteService),
	require(script.Parent.Services.RunLoopService),
	require(script.Parent.Services.PlayerLifecycle), -- always last
}

for _, service in loaded do
	service.init()
end
for _, service in loaded do
	service.start()
end

-- Engine-test hook (docs/09, section 16.3). Studio's MCP `execute_luau` and Open Cloud Luau
-- execution run in their own VM, where requiring Tests/RunAll would load fresh copies of every
-- module instead of the running services. This BindableFunction runs RunAll inside this VM:
--   return game.ServerScriptService.Server.RunTests:Invoke()
-- Only in development places (dev cheats on) and the CI place; ServerScriptService never
-- replicates, so no client can reach it.
local environment = Defaults.forGame(game.GameId)
if environment.devCheats or environment.name == "ci" then
	local hook = Instance.new("BindableFunction")
	hook.Name = "RunTests"
	hook.OnInvoke = function(): string
		local runAll = require(script.Parent.Tests.RunAll) :: () -> string
		return runAll()
	end
	hook.Parent = script.Parent
	-- PreyService's measurements for Studio runs (section 15.2): `PreyStats:Invoke(true)` returns
	-- them as JSON and, with true, starts a new measuring window.
	local HttpService = game:GetService("HttpService")
	local PreyService = require(script.Parent.Services.PreyService)
	local stats = Instance.new("BindableFunction")
	stats.Name = "PreyStats"
	stats.OnInvoke = function(reset: boolean?): string
		local text = HttpService:JSONEncode(PreyService.stats())
		if reset then
			PreyService.resetStats()
		end
		return text
	end
	stats.Parent = script.Parent
	-- The running DataService for Studio checks (the smoke's profile step; a server patch read
	-- back through the client's StateStoreGet hook): `DataGet:Invoke(userId)` is the player's
	-- profile as JSON ("null" when none is loaded); `DataPatch:Invoke(userId, path, value)`.
	local DataService = require(script.Parent.Services.DataService)
	local get = Instance.new("BindableFunction")
	get.Name = "DataGet"
	get.OnInvoke = function(userId: number): string
		local player = Players:GetPlayerByUserId(userId)
		return HttpService:JSONEncode(if player then DataService.get(player) else nil)
	end
	get.Parent = script.Parent
	local patch = Instance.new("BindableFunction")
	patch.Name = "DataPatch"
	patch.OnInvoke = function(userId: number, path: string, value: any): boolean
		local player = Players:GetPlayerByUserId(userId)
		return player ~= nil and DataService.patch(player, path, value)
	end
	patch.Parent = script.Parent
	-- Live config for Studio checks (the smoke's `config.*` step): `LiveConfigSet:Invoke(values)`
	-- applies a key → value table as if ConfigService had sent it and forwards the client keys
	-- that changed; `LiveConfigSet:Invoke(nil)` goes back to the real snapshot.
	local LiveConfig = require(script.Parent.Services.LiveConfig)
	local liveSet = Instance.new("BindableFunction")
	liveSet.Name = "LiveConfigSet"
	liveSet.OnInvoke = function(values: { [string]: any }?): boolean
		if values == nil then
			LiveConfig._test.restore()
		else
			LiveConfig._test.apply(values)
		end
		return true
	end
	liveSet.Parent = script.Parent
end
