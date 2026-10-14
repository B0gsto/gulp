--!strict
-- Kit/Screen: the engine half of the screen class, the landscape lock and the interface scale
-- (docs/15, sections 1, 2.2 and 5.2; docs/08, sections 1.2, 1.3 and 1.6). The pure half, the
-- class tests and the scale formula, is `Shared.Logic.ScreenScale`.
--
-- `start()` locks the phone to landscape, measures the screen once (join) and then again 250 ms
-- after the last change of the viewport, the display size, the safe insets, `TopbarInset` or the
-- orientation. Every recompute updates each layer made by `createLayer` and fires `changed`.
-- QualityController (docs/09, section 5.2) owns `screenClass()` and `onScreenClassChanged` and
-- builds them on this module; UIController builds every ScreenGui through `createLayer`.
--
-- A layer is one ScreenGui of docs/08 section 1.6 with one root frame holding one `UIScale`
-- (section 1.2). Children of the root are sized and placed in rpx. A `DeviceSafeInsets` root
-- covers the safe frame and pads it by the safe frame margins; a `None` root covers the screen.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ScreenScale = require(ReplicatedStorage.Shared.Logic.ScreenScale)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

export type Layout = ScreenScale.Layout
export type Reading = ScreenScale.Reading
export type LayerName =
	"GulpWorld"
	| "GulpHUD"
	| "GulpMoments"
	| "GulpMenus"
	| "GulpGuide"
	| "GulpToasts"
	| "GulpSystem"
export type LayerSpec = { displayOrder: number, safe: boolean }

type Layer = { gui: ScreenGui, root: Frame, uiScale: UIScale, safe: boolean }
type Rect = ScreenScale.Rect
type Size = ScreenScale.Size

-- docs/08 section 1.6 (display orders) and 1.3 (`safe`: `ScreenInsets = DeviceSafeInsets`;
-- otherwise `None`). GulpWorld's insets are not stated in the bible: it is full screen so markers
-- can reach the edges, like the scrims.
local LAYERS: { [LayerName]: LayerSpec } = table.freeze({
	GulpWorld = { displayOrder = 5, safe = false },
	GulpHUD = { displayOrder = 10, safe = true },
	GulpMoments = { displayOrder = 20, safe = true },
	GulpMenus = { displayOrder = 30, safe = true },
	GulpGuide = { displayOrder = 40, safe = true },
	GulpToasts = { displayOrder = 50, safe = true },
	GulpSystem = { displayOrder = 100, safe = false },
})

local Screen = {}

Screen.LAYERS = LAYERS

--- Fired after every recompute with the new layout.
local changed: Types.Signal<Layout> = Signal.new()
Screen.changed = changed
--- Fired at once when the phone turns from one landscape side to the other, before the
--- debounced recompute, so InputController can end the current swim touch (docs/15, 5.2).
local orientationChanged: Types.Signal<()> = Signal.new()
Screen.orientationChanged = orientationChanged

local started = false
local playerGui: PlayerGui? = nil
local fullProbe: Frame? = nil
local safeProbe: Frame? = nil
local currentLayout: Layout? = nil
local currentReading: Reading? = nil
local interfaceSize = ScreenScale.INTERFACE_SIZE_DEFAULT
local layers: { [LayerName]: Layer } = {}
local pending = 0
local cameraConnection: RBXScriptConnection? = nil

local function displaySize(): ScreenScale.DisplaySize
	local value = GuiService.ViewportDisplaySize
	if value == Enum.DisplaySize.Large then
		return "Large"
	elseif value == Enum.DisplaySize.Small then
		return "Small"
	end
	return "Medium"
end

local function rectOf(position: Vector2, size: Vector2): Rect
	return { x = position.X, y = position.Y, width = size.X, height = size.Y }
end

-- Reads the device. Before the first frame is drawn the probes can still be zero sized; the
-- camera viewport (or, before even that, the reference canvas) stands in until they are measured.
local function measure(): (Reading, Size, Rect, Rect)
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.zero
	if viewport.X <= 1 or viewport.Y <= 1 then
		viewport = Vector2.new(ScreenScale.REFERENCE_WIDTH, ScreenScale.REFERENCE_HEIGHT)
	end

	local reading: Reading = {
		displaySize = displaySize(),
		viewportWidth = viewport.X,
		viewportHeight = viewport.Y,
		touch = UserInputService.TouchEnabled,
		keyboard = UserInputService.KeyboardEnabled,
		mouse = UserInputService.MouseEnabled,
		gamepad = UserInputService.GamepadEnabled,
	}

	local full = fullProbe
	local safe = safeProbe
	local screen: Size = { width = viewport.X, height = viewport.Y }
	local safeArea: Rect = { x = 0, y = 0, width = viewport.X, height = viewport.Y }
	if full and safe and full.AbsoluteSize.X > 0 and safe.AbsoluteSize.X > 0 then
		screen = { width = full.AbsoluteSize.X, height = full.AbsoluteSize.Y }
		-- Both probes report in the same interface space, so the difference is the safe inset.
		safeArea = rectOf(safe.AbsolutePosition - full.AbsolutePosition, safe.AbsoluteSize)
	end

	local inset = GuiService.TopbarInset
	local topbar = rectOf(inset.Min, inset.Max - inset.Min)
	return reading, screen, safeArea, topbar
end

local function applyLayer(layer: Layer, layout: Layout)
	layer.uiScale.Scale = layout.scale
	if layer.safe then
		local frame = layout.safeFrame
		layer.root.Position =
			UDim2.fromOffset(frame.x + frame.width / 2, frame.y + frame.height / 2)
		layer.root.Size = UDim2.fromOffset(layout.safeSize.width, layout.safeSize.height)
	else
		layer.root.Position = UDim2.fromScale(0.5, 0.5)
		layer.root.Size = UDim2.fromOffset(layout.fullSize.width, layout.fullSize.height)
	end
end

--- Measures the screen and applies the result now, without waiting for the debounce.
function Screen.recompute()
	local reading, screen, safeArea, topbar = measure()
	local layout = ScreenScale.compute(reading, screen, safeArea, topbar, interfaceSize)
	currentReading = reading
	currentLayout = layout
	for _, layer in layers do
		applyLayer(layer, layout)
	end
	Screen.changed:fire(layout)
end

local function schedule()
	pending += 1
	local token = pending
	task.delay(ScreenScale.RECOMPUTE_DEBOUNCE, function()
		if token == pending then
			Screen.recompute()
		end
	end)
end

local function makeProbe(parent: PlayerGui, name: string, insets: Enum.ScreenInsets): Frame
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	-- `IgnoreGuiInset` first: setting it can rewrite `ScreenInsets`, so the insets are set last.
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = insets
	local frame = Instance.new("Frame")
	frame.Name = "Probe"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	gui.Parent = parent
	return frame
end

local function watchCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(schedule)
	end
end

local function onOrientation()
	Screen.orientationChanged:fire()
	schedule()
end

--- Locks landscape, measures the screen and starts listening for changes. Call once from the
--- client's start phase; later calls do nothing.
function Screen.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local gui = player:FindFirstChildOfClass("PlayerGui")
		-- safe: the PlayerGui child of a Player is always a PlayerGui
		or player:WaitForChild("PlayerGui") :: PlayerGui
	playerGui = gui

	-- docs/15 section 1: the place sets `StarterGui.ScreenOrientation` by hand; the client sets it
	-- again on PlayerGui because the documented default conflicts (PF21).
	gui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor

	local full = makeProbe(gui, "GulpScreenProbeFull", Enum.ScreenInsets.None)
	local safe = makeProbe(gui, "GulpScreenProbeSafe", Enum.ScreenInsets.DeviceSafeInsets)
	fullProbe = full
	safeProbe = safe

	watchCamera()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watchCamera()
		schedule()
	end)
	GuiService:GetPropertyChangedSignal("ViewportDisplaySize"):Connect(schedule)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(schedule)
	full:GetPropertyChangedSignal("AbsoluteSize"):Connect(schedule)
	safe:GetPropertyChangedSignal("AbsoluteSize"):Connect(schedule)
	safe:GetPropertyChangedSignal("AbsolutePosition"):Connect(schedule)
	-- docs/15 section 5.2: listen to both names of the orientation (PF21).
	gui:GetPropertyChangedSignal("ScreenOrientation"):Connect(onOrientation)
	gui:GetPropertyChangedSignal("CurrentScreenOrientation"):Connect(onOrientation)

	Screen.recompute()
end

local function requireLayout(): Layout
	local layout = currentLayout
	if not layout then
		error("Kit/Screen: call Screen.start() first")
	end
	return layout
end

--- The current layout: class, scale, safe frame, keep-out rects.
function Screen.layout(): Layout
	return requireLayout()
end

--- The current screen class (docs/15, section 2.2).
function Screen.screenClass(): Types.ScreenClass
	return requireLayout().screenClass
end

--- The current interface scale (rpx to px).
function Screen.scale(): number
	return requireLayout().scale
end

--- The raw device values of the last recompute, for the `sess_device` log (docs/15, 2.2).
function Screen.reading(): Reading
	requireLayout()
	return currentReading :: Reading -- safe: set together with currentLayout
end

--- The Interface size setting [L]: 0.8 to 1.3. Applies at once (docs/15, section 5.2).
function Screen.setInterfaceSize(value: number)
	interfaceSize = ScreenScale.clampInterfaceSize(value)
	if started then
		Screen.recompute()
	end
end

--- The ScreenGui of a layer of docs/08 section 1.6 and its scaled root frame, made on first call
--- and parented to PlayerGui. All ScreenGuis: `ResetOnSpawn = false`, `ZIndexBehavior = Sibling`.
function Screen.createLayer(name: LayerName): (ScreenGui, Frame)
	local existing = layers[name]
	if existing then
		return existing.gui, existing.root
	end
	local layout = requireLayout()
	local spec = LAYERS[name]

	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = spec.displayOrder
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = if spec.safe
		then Enum.ScreenInsets.DeviceSafeInsets
		else Enum.ScreenInsets.None

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = root

	if spec.safe then
		-- docs/08 section 1.3: the safe frame margins, in rpx (the UIScale scales them).
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, ScreenScale.MARGIN_TOP)
		padding.PaddingLeft = UDim.new(0, ScreenScale.MARGIN_SIDE)
		padding.PaddingRight = UDim.new(0, ScreenScale.MARGIN_SIDE)
		padding.PaddingBottom = UDim.new(0, ScreenScale.MARGIN_BOTTOM)
		padding.Parent = root
	end

	local layer: Layer = { gui = gui, root = root, uiScale = uiScale, safe = spec.safe }
	applyLayer(layer, layout)
	root.Parent = gui
	gui.Parent = playerGui
	layers[name] = layer
	return gui, root
end

return Screen
