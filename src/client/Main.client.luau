--!strict
-- StarterPlayerScripts.Client.Main: the ordered loader (docs/09, section 4.5). No framework.
-- Controllers are required one per line, in the order of section 4.5, so the type checker sees
-- them. `init` sets up private state and must not yield or call another controller; `start`
-- connects events and begins loops.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ClientReady (docs/09, sections 5.3 and 6.3): the server builds and hands over the creature only
-- after it. Persistent models (the collision shell) are not there yet when StarterPlayerScripts
-- start, so wait for `workspace.PersistentLoaded` first (spike F4: 3 to 341 ms). The event has
-- no "already fired" property and can fire before this script runs (seen with the small CI
-- arena), so the wait also ends when the shell itself is present: a Persistent model arrives
-- as one atomic unit (Roblox ModelStreamingMode docs; unverified here). A timeout guards a
-- place with no shell.
local PERSISTENT_TIMEOUT = 10 -- seconds
local persistentLoaded = false
local persistentConnection = workspace.PersistentLoaded:Once(function()
	persistentLoaded = true
end)

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Types = require(ReplicatedStorage.Shared.Types)

local CameraController = require(script.Parent.Controllers.CameraController)
local Client = require(script.Parent.Net.Client)
local CreatureController = require(script.Parent.Controllers.CreatureController)
local InputController = require(script.Parent.Controllers.InputController)
local MovementController = require(script.Parent.Controllers.MovementController)

-- Controllers have the shape of services (section 4.2), so the two loaders treat them alike.
type Controller = Types.Service

-- Section 4.5's order; each task adds its controller here: StateStore, QualityController,
-- InputController, CameraController, CreatureController, MovementController, PreyRenderer,
-- PredatorController, TideController, AudioController, UIController, TutorialDirector.
local loaded: { Controller } = {
	-- Section 4.5 order: StateStore, QualityController, InputController, CameraController,
	-- CreatureController, MovementController, ... Each is added here by the task that writes it.
	InputController,
	CameraController,
	CreatureController,
	MovementController,
}

for _, controller in loaded do
	controller.init()
end
for _, controller in loaded do
	controller.start()
end

do
	local waitedFrom = os.clock()
	local function ready(): boolean
		return persistentLoaded or workspace:FindFirstChild("Collision") ~= nil
	end
	while not ready() and os.clock() - waitedFrom < PERSISTENT_TIMEOUT do
		task.wait()
	end
	persistentConnection:Disconnect()
	if ready() then
		local ms = math.round((os.clock() - waitedFrom) * 1000)
		Log.info("Client", `ClientReady after {ms} ms (PersistentLoaded: {persistentLoaded})`)
	else
		Log.warn(
			"Client",
			`no PersistentLoaded after {PERSISTENT_TIMEOUT} s; sending ClientReady anyway`
		)
	end
	Client.send("ClientReady")
end
