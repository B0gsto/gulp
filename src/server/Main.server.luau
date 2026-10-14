--!strict
-- ServerScriptService.Server.Main: the ordered loader (docs/09, section 4.5). No framework.
-- Services are required one per line, in the order of section 4.5, so the type checker sees
-- them. `init` sets up private state and must not yield or call another service; `start`
-- connects events and begins loops. PlayerLifecycle is always last.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

type Service = Types.Service

-- Creates every remote of docs/09, section 5.3 before any service runs, so clients waiting in
-- Net/Client find them even while no service has registered a handler yet.
require(script.Parent.Net.Server)

local loaded: { Service } = {
	-- No services yet: each one is added here by the task that writes it.
}

for _, service in loaded do
	service.init()
end
for _, service in loaded do
	service.start()
end
