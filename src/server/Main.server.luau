--!strict
-- ServerScriptService.Server.Main: the ordered loader (docs/09, section 4.5). No framework.
-- Services are required one per line, in the order of section 4.5, so the type checker sees
-- them. `init` sets up private state and must not yield or call another service; `start`
-- connects events and begins loops. PlayerLifecycle is always last.

-- Moves to shared/Types with task S1-C4.
type Service = { name: string, init: () -> (), start: () -> () }

local loaded: { Service } = {
	-- No services yet: each one is added here by the task that writes it.
}

for _, service in loaded do
	service.init()
end
for _, service in loaded do
	service.start()
end
