--!strict
-- StarterPlayerScripts.Client.Main: the ordered loader (docs/09, section 4.5). No framework.
-- Controllers are required one per line, in the order of section 4.5, so the type checker sees
-- them. `init` sets up private state and must not yield or call another controller; `start`
-- connects events and begins loops.

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ClientReady (docs/09, sections 5.3, 6.3 and 6.6): the server builds and hands over the creature
-- only after it, and the tutorial leaves S0_LOADING on it (04 §3.1). The loading screen
-- (ReplicatedFirst.Boot.Loading) decides when: it sets its `LoadMode` attribute once the minimum
-- set of 04 §2.3 is in, collision shell included, or once the slow-load rule of 04 §2.4 starts
-- anyway. A timeout guards a place without the screen.
local LOADING_TIMEOUT = 20 -- seconds

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Types = require(ReplicatedStorage.Shared.Types)

local CameraController = require(script.Parent.Controllers.CameraController)
local Client = require(script.Parent.Net.Client)
local CreatureController = require(script.Parent.Controllers.CreatureController)
local InputController = require(script.Parent.Controllers.InputController)
local MovementController = require(script.Parent.Controllers.MovementController)
local PreyRenderer = require(script.Parent.Render.PreyRenderer)
local StateStore = require(script.Parent.Controllers.StateStore)
local TideController = require(script.Parent.Controllers.TideController)
local UIController = require(script.Parent.Controllers.UIController)

-- Controllers have the shape of services (section 4.2), so the two loaders treat them alike.
type Controller = Types.Service

-- Section 4.5's order; each task adds its controller here: StateStore, QualityController,
-- InputController, CameraController, CreatureController, MovementController, PreyRenderer,
-- PredatorController, TideController, AudioController, UIController, TutorialDirector.
local loaded: { Controller } = {
	-- Section 4.5 order: StateStore, QualityController, InputController, CameraController,
	-- CreatureController, MovementController, ... Each is added here by the task that writes it.
	StateStore,
	InputController,
	CameraController,
	CreatureController,
	MovementController,
	PreyRenderer,
	TideController,
	UIController,
}

for _, controller in loaded do
	controller.init()
end
for _, controller in loaded do
	controller.start()
end

-- Studio only: the PreyRenderer bench (tools/studio/prey_bench.py; task S3-C4).
if game:GetService("RunService"):IsStudio() then
	require(script.Parent.Dev.PreyHarness).bind(script.Parent)
	require(script.Parent.Dev.HudHarness).bind(script.Parent)
end

do
	local waitedFrom = os.clock()
	local boot = ReplicatedFirst:FindFirstChild("Boot")
	local loading = if boot then boot:FindFirstChild("Loading") else nil
	local function mode(): unknown
		return if loading then loading:GetAttribute("LoadMode") else nil
	end
	while loading and mode() == nil and os.clock() - waitedFrom < LOADING_TIMEOUT do
		task.wait()
	end
	local ms = math.round((os.clock() - waitedFrom) * 1000)
	if mode() ~= nil then
		Log.info("Client", `ClientReady after {ms} ms (load: {mode()})`)
	else
		Log.warn("Client", `no LoadMode from the loading screen after {ms} ms; ClientReady anyway`)
	end
	Client.send("ClientReady")
end
