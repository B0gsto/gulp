--!strict
-- ServerScriptService.Server.Main: the ordered loader (docs/09, section 4.5). No framework.
-- Services are required one per line, in the order of section 4.5, so the type checker sees
-- them. `init` sets up private state and must not yield or call another service; `start`
-- connects events and begins loops. PlayerLifecycle is always last.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Defaults = require(ReplicatedStorage.Shared.Config.Defaults)
local Types = require(ReplicatedStorage.Shared.Types)

type Service = Types.Service

-- Creates every remote of docs/09, section 5.3 before any service runs, so clients waiting in
-- Net/Client find them even while no service has registered a handler yet.
require(script.Parent.Net.Server)

-- Section 4.5's order, listing only the services written so far; each task adds its own.
local loaded: { Service } = {
	require(script.Parent.Services.WorldIndex),
	require(script.Parent.Services.CreatureService),
	require(script.Parent.Services.PreyService),
	require(script.Parent.Services.BiteService),
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
end
