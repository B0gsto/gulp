--!strict
-- Dev/HudHarness (Studio only; task S4-C5): poses the stage 1 HUD for screenshots. The loader
-- calls `bind`, which puts a BindableFunction named `HudHarness` next to the client scripts.
-- An `execute_luau` snippet on the client invokes it:
--   HudHarness:Invoke("device", "phone" | "desktop" | "real")  lays out for a simulated device
--   HudHarness:Invoke("pose")       drag ring, a dash cooldown, mass pops and an off-screen home
--   HudHarness:Invoke("open", "S11" | "S12")   and   HudHarness:Invoke("close", "S11" | "S12")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CreatureRig = require("../Render/CreatureRig")
local Outlines = require("../Render/Outlines")
local Screen = require("../UI/Kit/Screen")
local UIController = require("../Controllers/UIController")

local HudHarness = {}

-- docs/15 section 3.1's small-ish modern phone (844 x 390 px, 47 px notch insets) and the
-- spike F11 top bar; a 1920 x 1080 desktop.
local DEVICES: { [string]: Screen.Simulated } = {
	phone = {
		reading = {
			displaySize = "Small",
			viewportWidth = 750,
			viewportHeight = 390,
			touch = true,
			keyboard = false,
			mouse = false,
			gamepad = false,
		},
		screen = { width = 844, height = 390 },
		safeArea = { x = 47, y = 0, width = 750, height = 390 },
		topbar = { x = 120, y = 0, width = 724, height = 58 },
	},
	desktop = {
		reading = {
			displaySize = "Medium",
			viewportWidth = 1920,
			viewportHeight = 1080,
			touch = false,
			keyboard = true,
			mouse = true,
			gamepad = false,
		},
		screen = { width = 1920, height = 1080 },
		safeArea = { x = 0, y = 0, width = 1920, height = 1080 },
		topbar = { x = 120, y = 0, width = 1800, height = 58 },
	},
}

-- Two stand-in creatures in front of the camera so `HUD.Outlines` shows in the shots: one the
-- player can eat (lime), one that can eat the player (red, 1.5 x thicker; 08 §3.11).
local demo: { CreatureRig.Rig } = {}
local function outlineDemo(on: boolean)
	for _, rig in demo do
		CreatureRig.destroy(rig)
	end
	table.clear(demo)
	local camera = workspace.CurrentCamera
	if not on or camera == nil then
		return
	end
	for i = 1, 2 do
		local kind: CreatureRig.Kind = if i == 1 then "edible" else "dangerous"
		local rig = CreatureRig.new("minnow", 1)
		for _, part in rig.model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
			end
		end
		local at = camera.CFrame * CFrame.new(if i == 1 then 9 else -10, -3, -30)
		rig.model:PivotTo(
			CFrame.lookAt(at.Position, camera.CFrame.Position) * CFrame.Angles(0, math.rad(80), 0)
		)
		rig.model.Parent = workspace
		CreatureRig.applyScale(rig, if i == 1 then 1.2 else 2.4)
		CreatureRig.setOutline(rig, kind, Outlines.colour(kind))
		CreatureRig.refitOutline(rig)
		table.insert(demo, rig)
	end
end

-- Measures each stage 1 element in rpx (AbsoluteSize ÷ the interface scale; text by TextSize,
-- which the layer's UIScale multiplies), so screenshots can be checked against docs/08.
local function measure(): string
	local scale = Screen.layout().scale
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local out: { string } = { `scale {string.format("%.3f", scale)}` }
	local function find(layer: string, name: string): GuiObject?
		local g = gui:FindFirstChild(layer)
		local o = g and g:FindFirstChild(name, true)
		return if o and o:IsA("GuiObject") and o.Visible then o else nil
	end
	local function size(label: string, layer: string, name: string)
		local o = find(layer, name)
		if o then
			table.insert(
				out,
				`{label} {math.round(o.AbsoluteSize.X / scale)}x{math.round(
					o.AbsoluteSize.Y / scale
				)}`
			)
		end
	end
	local function text(label: string, layer: string, name: string)
		local found = find(layer, name)
		if found and found:IsA("TextLabel") then
			local o = found :: TextLabel
			local stroke = o:FindFirstChildOfClass("UIStroke")
			table.insert(
				out,
				`{label} text {o.TextSize}{if stroke then ` stroke {stroke.Thickness}` else ""} drawn {math.round(
					o.TextBounds.Y / scale
				)}`
			)
		end
	end
	local function bottomGap(label: string, layer: string, name: string)
		local o = find(layer, name)
		local root = gui:FindFirstChild(layer) and (gui :: any)[layer]:FindFirstChild("Root")
		if o and root then
			local face = o:FindFirstChild("Face") :: GuiObject?
			local f = face or o
			local gap = (
				root.AbsolutePosition.Y
				+ root.AbsoluteSize.Y
				- (f.AbsolutePosition.Y + f.AbsoluteSize.Y)
			) / scale
			table.insert(
				out,
				`{label} face {math.round(f.AbsoluteSize.X / scale)}x{math.round(
					f.AbsoluteSize.Y / scale
				)} bottom gap {math.round(gap)}`
			)
		end
	end
	size("MassBar", "GulpHUD", "HUD.MassBar")
	text("mass", "GulpHUD", "Mass")
	text("goal", "GulpHUD", "ToGo")
	size("Dash", "GulpHUD", "Face")
	size("DashTile", "GulpHUD", "Tile")
	size("Ring", "GulpWorld", "UI_HUD_DragRing")
	size("Knob", "GulpWorld", "UI_HUD_DragKnob")
	local face = find("GulpHUD", "Face")
	if face then
		-- Not clipped: the face lies inside the screen (08 §1 safe area is checked by eye).
		local view = workspace.CurrentCamera.ViewportSize
		local a, b = face.AbsolutePosition, face.AbsolutePosition + face.AbsoluteSize
		local inside = a.X >= 0 and a.Y >= -60 and b.X <= view.X and b.Y <= view.Y
		table.insert(out, `Dash on screen {if inside then "yes" else "no"}`)
	end
	size("Home", "GulpWorld", "Disc")
	text("homeDist", "GulpWorld", "Distance")
	text("pop", "GulpWorld", "Pop")
	bottomGap("SwimAgain", "GulpMoments", "SwimAgain")
	bottomGap("Continue", "GulpMoments", "Continue")
	for _, n in { "Name", "Value", "Amount" } do
		text("bank " .. n, "GulpMoments", n)
	end
	local best = find("GulpMoments", "Best")
	if best then
		text("best", "GulpMoments", "Best")
		local t = best:FindFirstChildOfClass("TextLabel")
		if t then
			table.insert(out, `best text {t.TextSize}`)
		end
	end
	-- 08 §3.3: the knob sits on the ring centre at rest (touch at the origin).
	local ring, knob = find("GulpWorld", "UI_HUD_DragRing"), find("GulpWorld", "UI_HUD_DragKnob")
	if ring and knob then
		local d = (ring.AbsolutePosition + ring.AbsoluteSize / 2)
			- (knob.AbsolutePosition + knob.AbsoluteSize / 2)
		table.insert(out, `knob offset {math.round(d.Magnitude / scale)}`)
	end
	return table.concat(out, "; ")
end

local function pose(): string
	local layout = Screen.layout()
	local full = layout.fullSize
	local camera = workspace.CurrentCamera
	local home = if camera then (camera.CFrame * CFrame.new(-400, -20, 120)).Position else nil
	outlineDemo(true)
	UIController.setPreview({
		drag = if layout.screenClass ~= "Desktop"
			then {
				active = true,
				ox = 230,
				oy = full.height - 210,
				tx = 290,
				ty = full.height - 250,
			}
			else nil,
		dashLeft = 0.35,
		home = home,
	})
	local player = Players.LocalPlayer
	local mass = player:GetAttribute("Mass")
	local base = if type(mass) == "number" then mass else 30
	player:SetAttribute("Mass", base + 4)
	task.delay(0.25, function()
		player:SetAttribute("Mass", base + 11)
	end)
	return `posed {layout.screenClass} at scale {layout.scale}`
end

function HudHarness.bind(parent: Instance)
	if not RunService:IsStudio() then
		return
	end
	local f = Instance.new("BindableFunction")
	f.Name = "HudHarness"
	f.OnInvoke = function(command: string, arg: string?): string
		if command == "device" then
			Screen.simulate(if arg then DEVICES[arg] else nil)
			local l = Screen.layout()
			return `{l.screenClass} scale {l.scale} content {l.contentSize.width} x {l.contentSize.height}`
		elseif command == "pose" then
			return pose()
		elseif command == "rest" then
			-- The drag ring at rest: the thumb on the origin.
			local full = Screen.layout().fullSize
			UIController.setPreview({
				drag = {
					active = true,
					ox = 230,
					oy = full.height - 210,
					tx = 230,
					ty = full.height - 210,
				},
			})
			return "rest"
		elseif command == "measure" then
			return measure()
		elseif command == "open" and arg == "S11" then
			UIController.open("S11")
			return "S11"
		elseif command == "open" and arg == "S12" then
			UIController.open("S12", {
				mass = 86,
				multipliers = {
					{ nameKey = "trait.crystal", value = 1.5, icon = "trait" },
					{ nameKey = "pass.deep_pockets", value = 2, icon = "pass" },
				},
				total = 774,
				best = true,
			})
			return "S12"
		elseif command == "close" and (arg == "S11" or arg == "S12") then
			UIController.close(arg)
			return "closed"
		end
		UIController.setPreview(nil)
		outlineDemo(false)
		return "reset"
	end
	f.Parent = parent
end

return HudHarness
