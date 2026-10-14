--!strict
-- StarterPlayerScripts.Client.Main: the ordered loader (docs/09, section 4.5). No framework.
-- Controllers are required one per line, in the order of section 4.5, so the type checker sees
-- them. `init` sets up private state and must not yield or call another controller; `start`
-- connects events and begins loops.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

-- Controllers have the shape of services (section 4.2), so the two loaders treat them alike.
type Controller = Types.Service

local loaded: { Controller } = {
	-- No controllers yet: each one is added here by the task that writes it.
}

for _, controller in loaded do
	controller.init()
end
for _, controller in loaded do
	controller.start()
end
