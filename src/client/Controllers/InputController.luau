--!strict
-- InputController: turns raw input into one `SwimInput` (docs/09, section 5.2; module B11).
-- Drag to swim on touch (docs/02 §2.1, docs/15 §3.1), and on keys the free cursor (scheme "keys",
-- the default) or locked mouse look ("keys_locked") (02 §2.3, 15 §3.3) at MVP; the gamepad, the
-- two-thumb scheme and the left-handed layout are [L]. The mappings,
-- dead zones and curves are `Shared.Logic.InputMath`; this module only reads `UserInputService`.
--
-- The input mode is `UserInputService.PreferredInput`, re-read on every change (15 §5.1, PF18),
-- with `LastInputTypeChanged` as the fallback the chapter names. The server never trusts it.
-- No default controls exist: the stub `PlayerModule` stops them loading (09 §6.10).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Defaults = require(ReplicatedStorage.Shared.Config.Defaults)
local Index = require(ReplicatedStorage.Shared.Data.Index)
local InputMath = require(ReplicatedStorage.Shared.Logic.InputMath)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local SwimModel = require(ReplicatedStorage.Shared.Sim.SwimModel)
local Types = require(ReplicatedStorage.Shared.Types)

local Screen = require("../UI/Kit/Screen")

type InputMode = Types.InputMode
type SwimInput = Types.SwimInput

local TAG = "Input"
local MAX_DT = SwimModel.MAX_DT
-- The schemes each mode offers at MVP (02 §2; 08 §6.7: one scheme, Drag to swim, on touch).
local SCHEMES: { [InputMode]: { string } } = {
	Touch = { "drag" }, -- "twoThumb" is [L]
	Keys = { "keys", "keys_locked" }, -- free cursor (default), locked mouse look (02 §2.3)
	Pad = { "pad" }, -- [L]: no pad scheme yet, so Pad mode gives no input
}

local InputController = {}
InputController.name = "InputController"

--- Fires the new mode when the input mode changes (15 §5.1).
InputController.onModeChanged = Signal.new() :: Types.Signal<InputMode>
--- Fires on every dash press: Q, left mouse, or the HUD dash button (02 §2.1, §2.3).
InputController.onDash = Signal.new() :: Types.Signal<>
--- Fires on every ability press: E, right mouse, or the HUD ability button.
InputController.onAbility = Signal.new() :: Types.Signal<>

local player = Players.LocalPlayer
local input: SwimInput = InputMath.newInput()
local currentMode: InputMode = "Keys"
local schemeOf: { [InputMode]: string } = { Touch = "drag", Keys = "keys", Pad = "pad" }
local sensitivity = Defaults.input.dragSensitivity -- TODO(B23): from the saved settings
local lookSpeed = Defaults.input.mouseLookSpeed -- TODO(B23): from the saved settings
-- TODO(B23): the saved `InputSettings.scheme` per mode calls setScheme; until then Keys is "keys".
local turnRate = 0 -- the tier's turn rate, °/s, from the Tier and Species attributes
local lastRead = os.clock()

-- Touch: the swim touch is the first touch that does not start on a button (02 §2.1).
local swimTouch: InputObject? = nil
-- The swim drag, in rpx (02 §2, 08 §1.2): device px ÷ Kit/Screen's interface scale.
local originX, originY, touchX, touchY = 0, 0, 0, 0

local function toRpx(position: Vector3): (number, number)
	local scale = Screen.scale()
	return InputMath.toRpx(position.X, scale), InputMath.toRpx(position.Y, scale)
end
local releasedAt = -math.huge

-- Keys.
local keys: InputMath.Keys =
	{ forward = false, brake = false, left = false, right = false, autoSwim = false }
local arrowLeft, arrowRight, arrowUp, arrowDown, altHeld = false, false, false, false, false
-- Swim up, swim down (02 §2.3): either Shift, each tracked so releasing one keeps the other.
local spaceHeld, leftShift, rightShift = false, false, false
local lookYaw, lookPitch = 0, 0 -- locked mouse look
local pilot: ((SwimInput) -> ())? = nil -- setPilot (Studio only)
local mouseDX, mouseDY = 0, 0
-- Free cursor: no steering while the window is unfocused or the cursor is over GUI that sinks
-- input (02 §2.3). `overGui` is the gameProcessed flag of the last mouse movement; a release or
-- a mode switch clears it, so a still cursor never keeps steering off.
local focused, overGui = true, false

-- Dash: a press is true for one read; a held HUD button is true every read (held dash).
local dashPressed, dashHeld = false, false

local function refreshTurnRate()
	local tier = player:GetAttribute("Tier")
	local species = player:GetAttribute("Species")
	local def = if type(species) == "string" then Index.Species.byId[species] else nil
	if type(tier) == "number" and Index.Tiers.byTier[tier] and def then
		turnRate = SwimModel.turnRate(tier, def)
	end
end

-- The creature's heading, so Keys mode starts looking where the creature faces.
local function syncLook()
	local character = player.Character
	local root = character and character.PrimaryPart
	if root then
		local pitch, yaw = root.CFrame:ToEulerAnglesYXZ()
		lookYaw, lookPitch = math.deg(yaw), math.deg(pitch)
	end
end

-- 15 §5.1, Held inputs: everything held in the old mode is released on a switch.
local function releaseHeld()
	if swimTouch then
		swimTouch = nil
		releasedAt = os.clock()
	end
	keys.forward, keys.brake, keys.left, keys.right, keys.autoSwim =
		false, false, false, false, false
	arrowLeft, arrowRight, arrowUp, arrowDown, altHeld = false, false, false, false, false
	spaceHeld, leftShift, rightShift, overGui = false, false, false, false
	mouseDX, mouseDY = 0, 0
	dashPressed, dashHeld = false, false
end

local function locked(): boolean
	return currentMode == "Keys" and schemeOf[currentMode] == "keys_locked"
end

-- Locked mouse look only (02 §2.3): the cursor is locked to screen centre while swimming and freed
-- by holding Left Alt. The free cursor (the default) is never locked. Roblox's own Shift Lock is
-- off (StarterPlayer.EnableMouseLockOption in the project file).
-- TODO(B23, S8-C4): also free it while a panel is open.
local function updateMouseLock()
	local want = if locked()
			and not altHeld
			and player.Character ~= nil
		then Enum.MouseBehavior.LockCenter
		else Enum.MouseBehavior.Default
	if UserInputService.MouseBehavior ~= want then
		UserInputService.MouseBehavior = want
	end
end

local function setMode(mode: InputMode)
	if mode == currentMode then
		return
	end
	currentMode = mode
	releaseHeld()
	if mode == "Keys" then
		syncLook()
	end
	updateMouseLock()
	InputController.onModeChanged:fire(mode)
end

local function pressDash()
	dashPressed = true
	InputController.onDash:fire()
end

local function onInputBegan(object: InputObject, gameProcessed: boolean)
	local kind = object.UserInputType
	if kind == Enum.UserInputType.Touch then
		if not gameProcessed and swimTouch == nil then
			swimTouch = object
			originX, originY = toRpx(object.Position)
			touchX, touchY = originX, originY
		end
		return
	end
	if gameProcessed then
		return -- typing in a text box, or a click on a button
	end
	if kind == Enum.UserInputType.MouseButton1 then
		pressDash()
	elseif kind == Enum.UserInputType.MouseButton2 then
		InputController.onAbility:fire()
	elseif kind == Enum.UserInputType.Keyboard then
		local key = object.KeyCode
		if key == Enum.KeyCode.W then
			keys.forward = true
			keys.autoSwim = InputMath.autoSwim(keys.autoSwim, "W")
		elseif key == Enum.KeyCode.S then
			keys.brake = true
			keys.autoSwim = InputMath.autoSwim(keys.autoSwim, "S")
		elseif key == Enum.KeyCode.R then
			keys.autoSwim = InputMath.autoSwim(keys.autoSwim, "R")
		elseif key == Enum.KeyCode.A then
			keys.left = true
		elseif key == Enum.KeyCode.D then
			keys.right = true
		elseif key == Enum.KeyCode.Q then
			pressDash()
		elseif key == Enum.KeyCode.Space then
			spaceHeld = true
		elseif key == Enum.KeyCode.LeftShift then
			leftShift = true
		elseif key == Enum.KeyCode.RightShift then
			rightShift = true
		elseif key == Enum.KeyCode.E then
			InputController.onAbility:fire()
		elseif key == Enum.KeyCode.Left then
			arrowLeft = true
		elseif key == Enum.KeyCode.Right then
			arrowRight = true
		elseif key == Enum.KeyCode.Up then
			arrowUp = true
		elseif key == Enum.KeyCode.Down then
			arrowDown = true
		elseif key == Enum.KeyCode.LeftAlt then
			altHeld = true
		end
	end
end

local function onInputChanged(object: InputObject, gameProcessed: boolean)
	local kind = object.UserInputType
	if kind == Enum.UserInputType.MouseMovement then
		overGui = gameProcessed
		mouseDX += object.Delta.X
		mouseDY += object.Delta.Y
	elseif kind == Enum.UserInputType.Touch and object == swimTouch then
		touchX, touchY = toRpx(object.Position)
		originX, originY = InputMath.trailOrigin(originX, originY, touchX, touchY, sensitivity)
	end
end

local function onInputEnded(object: InputObject, _gameProcessed: boolean)
	local kind = object.UserInputType
	if kind == Enum.UserInputType.Touch then
		if object == swimTouch then
			swimTouch = nil
			releasedAt = os.clock()
		end
	elseif kind == Enum.UserInputType.Keyboard then
		local key = object.KeyCode
		if key == Enum.KeyCode.W then
			keys.forward = false
		elseif key == Enum.KeyCode.S then
			keys.brake = false
		elseif key == Enum.KeyCode.A then
			keys.left = false
		elseif key == Enum.KeyCode.D then
			keys.right = false
		elseif key == Enum.KeyCode.Space then
			spaceHeld = false
		elseif key == Enum.KeyCode.LeftShift then
			leftShift = false
		elseif key == Enum.KeyCode.RightShift then
			rightShift = false
		elseif key == Enum.KeyCode.Left then
			arrowLeft = false
		elseif key == Enum.KeyCode.Right then
			arrowRight = false
		elseif key == Enum.KeyCode.Up then
			arrowUp = false
		elseif key == Enum.KeyCode.Down then
			arrowDown = false
		elseif key == Enum.KeyCode.LeftAlt then
			altHeld = false
		end
	end
end

-- Free cursor steering (02 §2.3): the yaw rate from the cursor's horizontal offset from the
-- viewport centre, device px. `GetMouseLocation` and `ViewportSize` share the viewport's origin.
-- TODO(B23, S8-C4): no steering while a panel is open.
local function cursorSteer(): number
	local camera = workspace.CurrentCamera
	if not focused or overGui or camera == nil then
		return 0
	end
	local width = camera.ViewportSize.X
	local offset = UserInputService:GetMouseLocation().X - width / 2
	return InputMath.cursorSteer(offset, width, turnRate)
end

--- The SwimInput for this frame. MovementController calls it once per frame; the returned table
--- is reused, so read it before the next call.
function InputController.read(): SwimInput
	local now = os.clock()
	local dt = math.min(now - lastRead, MAX_DT)
	lastRead = now
	if currentMode == "Touch" then
		if swimTouch then
			InputMath.fromDrag(input, touchX - originX, touchY - originY, sensitivity, turnRate)
		else
			InputMath.fromRelease(input, now - releasedAt, dt)
		end
	elseif currentMode == "Keys" then
		updateMouseLock()
		local right = InputMath.axis(arrowRight, arrowLeft)
		-- Space or Arrow Up swims up, Shift or Arrow Down swims down; both cancel (02 §2.3).
		local up = InputMath.axis(spaceHeld or arrowUp, leftShift or rightShift or arrowDown)
		if locked() then
			if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
				lookYaw, lookPitch =
					InputMath.mouseLook(lookYaw, lookPitch, mouseDX, mouseDY, lookSpeed)
			end
			if right ~= 0 or up ~= 0 then
				lookYaw, lookPitch =
					InputMath.arrowLook(lookYaw, lookPitch, right, up, turnRate, dt)
			end
			InputMath.fromKeys(input, keys, lookYaw, lookPitch)
		else
			InputMath.fromCursorKeys(input, keys, cursorSteer(), right, up, turnRate)
		end
		mouseDX, mouseDY = 0, 0
	else
		-- Pad: the scheme is [L]. The creature coasts and levels, as with no touch.
		InputMath.fromRelease(input, math.huge, dt)
	end
	input.dash = dashPressed or dashHeld
	dashPressed = false
	if pilot then
		pilot(input)
	end
	return input
end

--- Studio only: `fn` rewrites each frame's SwimInput (the tutorial play check's autopilot,
--- TutorialDirector); nil gives the controls back. Ignored outside Studio.
function InputController.setPilot(fn: ((SwimInput) -> ())?)
	if RunService:IsStudio() then
		pilot = fn
	end
end

--- The current input mode (15 §5.1).
function InputController.mode(): InputMode
	return currentMode
end

--- Chooses the control scheme for the current input mode: drag to swim on touch; "keys" (free
--- cursor, the default) or "keys_locked" (locked mouse look) on desktop (02 §2.3, 15 §3.3). The
--- two-thumb scheme and the pad are [L].
function InputController.setScheme(id: string)
	if table.find(SCHEMES[currentMode], id) == nil then
		Log.warn(TAG, `scheme "{id}" is not available in {currentMode} mode`)
		return
	end
	schemeOf[currentMode] = id
	if currentMode == "Keys" then
		syncLook() -- locked mouse look starts where the creature faces
		updateMouseLock()
	end
end

--- For the HUD buttons (08 §3.7; not in 09 §5.2's API, which names no route for them): a dash
--- press, and the held dash that re-fires on each cooldown end while `down` stays true; or an
--- ability press. Touches on the buttons are game-processed, so they never start a swim drag.
function InputController.press(action: "Dash" | "Ability", down: boolean)
	if action == "Dash" then
		if down and not dashHeld then
			pressDash()
		end
		dashHeld = down -- TODO(B23): the "held dash" setting, on by default (02 §2.1)
	elseif down then
		InputController.onAbility:fire()
	end
end

--- The swim touch for `HUD.DragRing` (08 §3.16): whether one is down, its floating origin and the
--- thumb, in rpx of the device-independent screen (`InputObject.Position` ÷ the interface scale,
--- so below the GUI inset, like the touch positions). Display only.
function InputController.drag(): (boolean, number, number, number, number)
	return swimTouch ~= nil, originX, originY, touchX, touchY
end

function InputController.init() end

function InputController.start()
	Screen.start() -- the interface scale the drag reads (idempotent)
	refreshTurnRate()
	player:GetAttributeChangedSignal("Tier"):Connect(refreshTurnRate)
	player:GetAttributeChangedSignal("Species"):Connect(refreshTurnRate)
	player.CharacterAdded:Connect(function()
		syncLook()
		refreshTurnRate()
	end)

	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputEnded:Connect(onInputEnded)
	-- A key held while the window loses focus never sends its end.
	UserInputService.WindowFocusReleased:Connect(function()
		focused = false
		releaseHeld()
	end)
	UserInputService.WindowFocused:Connect(function()
		focused = true
	end)

	-- 15 §5.2: turning the phone ends the swim touch so a drag cannot stick.
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if swimTouch then
				swimTouch = nil
				releasedAt = os.clock()
			end
		end)
	end

	local ok, preferred = pcall(function()
		return UserInputService.PreferredInput
	end)
	if ok then
		local function read()
			setMode(InputMath.mode(UserInputService.PreferredInput.Name, currentMode))
		end
		currentMode = InputMath.mode(preferred.Name, currentMode)
		UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(read)
	else
		Log.warn(TAG, "PreferredInput is unavailable; following LastInputTypeChanged (15 §5.1)")
		currentMode =
			InputMath.modeOfInputType(UserInputService:GetLastInputType().Name, currentMode)
		UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
			setMode(InputMath.modeOfInputType(inputType.Name, currentMode))
		end)
	end
	syncLook()
	Log.info(TAG, `input mode {currentMode}`)
end

return InputController
