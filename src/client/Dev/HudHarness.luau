--!strict
-- Dev/HudHarness (Studio only; task S4-C5): poses the stage 1 HUD for screenshots. The loader
-- calls `bind`, which puts a BindableFunction named `HudHarness` next to the client scripts.
-- An `execute_luau` snippet on the client invokes it:
--   HudHarness:Invoke("device", "phone" | "desktop" | "real")  lays out for a simulated device
--   HudHarness:Invoke("pose")       drag ring, a dash cooldown, mass pops and an off-screen home
--   HudHarness:Invoke("open", "S11" | "S12")   and   HudHarness:Invoke("close", "S11" | "S12")
--   HudHarness:Invoke("open", "S12card" | "S12small")   S12 with a specimen card, or a tier 1 run
--   HudHarness:Invoke("cove")       S14 with fixed values and a Pearl pile in front of the camera
--   HudHarness:Invoke("tierup", "2".."7")   S07 for a rise to that tier (7: rays, 2.2 s)
--   HudHarness:Invoke("trait", traitId)     S08 for that trait in slot 1 ("crystal": Epic, rays)
--   HudHarness:Invoke("hold", "on" | "off") holds the moment card on screen for screenshots
--   HudHarness:Invoke("device", "tablet")   a simulated 1024 x 768 tablet (task S6-C4)
--   HudHarness:Invoke("mode", "Touch" | "Keys" | "Pad")   the guide's input pictures
--   HudHarness:Invoke("guide", "point" | "tap" | "hold" | "ghost" | "off")   the guide kit S33
--     (docs/08 section 7): "point" G1 arrow, G4 trail, G5 ring, G7 bubble, G8 picture, the home
--     ring and HOME, the danger edge; "tap" G3 tap, G6 cut-out, G7, the dash pulse and DASH!;
--     "hold" G3 hold, G7 in the moment slot, G2 curved arrow, G9 tick; "ghost" the ghost thumb
--     and the creature's bubble. All nine parts and chapter 04's four prompts over four poses.
--   HudHarness:Invoke("guidecheck") every shown guide part's rect in rpx, and whether it
--     enters the keep-clear box or the HUD (08 §1.4, §7)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)

local CoveHud = require("../UI/Hud/CoveHud")
local CreatureRig = require("../Render/CreatureRig")
local Guide = require("../UI/Kit/Guide")
local Hud = require("../UI/Hud/Hud")
local InputController = require("../Controllers/InputController")
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
	-- docs/15 section 3.2: a 1024 x 768 tablet, touch only, no insets.
	tablet = {
		reading = {
			displaySize = "Medium",
			viewportWidth = 1024,
			viewportHeight = 768,
			touch = true,
			keyboard = false,
			mouse = false,
			gamepad = false,
		},
		screen = { width = 1024, height = 768 },
		safeArea = { x = 0, y = 0, width = 1024, height = 768 },
		topbar = { x = 120, y = 0, width = 904, height = 58 },
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
	-- The shots show the standard palette (06 §13.2: lime edible, red danger), whatever the
	-- colour-blind setting of the Studio profile says.
	Outlines.setColourBlind(false)
	for i = 1, 2 do
		local kind: CreatureRig.Kind = if i == 1 then "edible" else "dangerous"
		local rig = CreatureRig.new("minnow", 1)
		for _, part in rig.model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
			end
		end
		-- Placed through the (simulated) screen, which sits at the top left of the real viewport,
		-- so both stay whole inside the shot: the edible one right of the keep-clear box and near
		-- enough that its lime outline (06 §13.2) reads, the dangerous one upper left.
		local layout = Screen.layout()
		local w, h = layout.fullSize.width * layout.scale, layout.fullSize.height * layout.scale
		local ray = if i == 1
			then camera:ViewportPointToRay(w * 0.8, h * 0.5)
			else camera:ViewportPointToRay(w * 0.2, h * 0.4)
		local at = ray.Origin + ray.Direction * (if i == 1 then 20 else 32)
		rig.model:PivotTo(
			CFrame.lookAt(at, camera.CFrame.Position) * CFrame.Angles(0, math.rad(80), 0)
		)
		rig.model.Parent = workspace
		CreatureRig.applyScale(rig, if i == 1 then 2 else 2.4)
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
				`{label} text {o:GetAttribute("TextRpx") or o.TextSize}->{o.TextSize}{if stroke
					then ` stroke {string.format("%.2f", stroke.Thickness)}`
					else ""} drawn {math.round(o.TextBounds.Y)}px={string.format(
					"%.1f",
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
	-- 08 §3.12 keep-out: the gap between the home marker's rect and the drag ring, in rpx.
	local marker, dragRing = find("GulpWorld", "Marker"), find("GulpWorld", "UI_HUD_DragRing")
	if marker and dragRing then
		local c = (marker.AbsolutePosition + marker.AbsoluteSize / 2) / scale
		local rc = (dragRing.AbsolutePosition + dragRing.AbsoluteSize / 2) / scale
		local mr = HudLayout.homeRect(c.X, c.Y)
		local rr = HudLayout.ringRect(rc.X, rc.Y)
		local gx = math.max(rr.x - (mr.x + mr.width), mr.x - (rr.x + rr.width))
		local gy = math.max(rr.y - (mr.y + mr.height), mr.y - (rr.y + rr.height))
		table.insert(out, `home-ring gap {math.round(math.max(gx, gy))}`)
	end
	text("homeDist", "GulpWorld", "Distance")
	-- S14 (08 §5.1) and the S12 specimen card (08 §4.5).
	size("Cove.Pearls", "GulpHUD", "Cove.Pearls")
	size("Cove.Income", "GulpHUD", "Cove.Income")
	size("Cove.Slots", "GulpHUD", "Cove.Slots")
	size("PlusHit", "GulpHUD", "PlusHit")
	size("Dock", "GulpHUD", "Dock.species")
	for _, n in { "Balance", "PerHour", "Count" } do
		text("cove " .. n, "GulpHUD", n)
	end
	local claim = find("GulpHUD", "Cove.ClaimAll")
	if claim then
		bottomGap("ClaimAll", "GulpHUD", "Cove.ClaimAll")
		for _, d in claim:GetDescendants() do
			if d:IsA("TextLabel") then
				table.insert(
					out,
					`claim {d.Name} text {d:GetAttribute("TextRpx")}->{d.TextSize} bounds {math.round(
						d.TextBounds.X / scale
					)}/{math.round(d.AbsoluteSize.X / scale)}`
				)
			end
		end
	end
	local dock = find("GulpHUD", "Dock.species")
	local dockLabel = dock and dock:FindFirstChild("Label")
	if dockLabel and dockLabel:IsA("TextLabel") then
		table.insert(
			out,
			`dock label text {dockLabel:GetAttribute("TextRpx")}->{dockLabel.TextSize} drawn {string.format(
				"%.1f",
				dockLabel.TextBounds.Y / scale
			)}`
		)
	end
	-- Claim all and Dash: the gap between their hit areas (08 §1.5), in rpx.
	local claimRoot = find("GulpHUD", "Cove.ClaimAll")
	local claimHit = claimRoot and claimRoot:FindFirstChild("Hit")
	local dashRoot = find("GulpHUD", "HUD.Dash")
	local dashHit = dashRoot and dashRoot:FindFirstChild("Hit", true)
	if claimHit and claimHit:IsA("GuiObject") and dashHit and dashHit:IsA("GuiObject") then
		local bottom = claimHit.AbsolutePosition.Y + claimHit.AbsoluteSize.Y
		table.insert(
			out,
			`claim-dash hit gap {math.round((dashHit.AbsolutePosition.Y - bottom) / scale)}`
		)
	end
	local perHour = find("GulpHUD", "PerHour")
	if perHour and perHour:IsA("TextLabel") then
		table.insert(
			out,
			`income fit {math.round(perHour.TextBounds.X / scale)}/{math.round(
				perHour.AbsoluteSize.X / scale
			)}`
		)
	end
	local pile = gui:FindFirstChild("Cove.PearlPile")
	if pile and pile:IsA("BillboardGui") then
		local adornee = pile.Adornee
		if adornee and adornee:IsA("BasePart") then
			local v, on = workspace.CurrentCamera:WorldToViewportPoint(adornee.Position)
			table.insert(
				out,
				`pile world {math.round(v.X)},{math.round(v.Y)} z {math.round(v.Z)} on {on} parent {pile.Parent and pile.Parent.Name} kids {#pile:GetDescendants()}`
			)
		end
		table.insert(
			out,
			`pile enabled {pile.Enabled} adornee {if adornee then adornee.Name else "none"} size {math.round(
				pile.AbsoluteSize.X / scale
			)}x{math.round(pile.AbsoluteSize.Y / scale)} at {math.round(pile.AbsolutePosition.X)},{math.round(
				pile.AbsolutePosition.Y
			)}`
		)
	end
	-- S07 and S08 (08 §4.2, §4.3).
	size("Slot", "GulpMoments", "HUD.MomentSlot")
	size("TierUp", "GulpMoments", "S07.TierUp")
	size("TraitGained", "GulpMoments", "S08.TraitGained")
	for _, n in { "Header", "TierName", "FoodLabel", "TraitName", "Effect" } do
		text("moment " .. n, "GulpMoments", n)
	end
	size("Card", "GulpMoments", "Specimen")
	text("card tier", "GulpMoments", "TierName")
	text("card perHour", "GulpMoments", "PerHour")
	text("card tooSmall", "GulpMoments", "TooSmall")
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

-- S14 (08 §5.1 wireframe values): 12,480 Pearls, 340 an hour, 7 of 12 slots, 412 in the pile;
-- the pile bubble floats over a stand-in clam in front of the camera.
local clam: BasePart? = nil
local function cove(on: boolean): string
	if clam then
		clam:Destroy()
		clam = nil
	end
	if not on then
		CoveHud.setPileAnchor(nil)
		UIController.setCovePreview(nil)
		return "cove off"
	end
	local camera = workspace.CurrentCamera
	if camera then
		local layout = Screen.layout()
		local w, h = layout.fullSize.width * layout.scale, layout.fullSize.height * layout.scale
		local ray = camera:ViewportPointToRay(w * 0.42, h * 0.62)
		local part = Instance.new("Part")
		part.Name = "PearlClamDemo"
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 1
		part.Size = Vector3.new(1, 1, 1)
		part.Position = ray.Origin + ray.Direction * 30
		part.Parent = workspace
		clam = part
		CoveHud.setPileAnchor(part)
	end
	UIController.setCovePreview({
		pearls = 12480,
		rate = 340,
		used = 7,
		capacity = 12,
		pile = 412,
		pileFull = false,
	})
	return "cove on"
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

-- "hold": the next moment cards stay up for an hour, for screenshots.
local holding = false

-- The guide kit (task S6-C4): world points in front of the camera, on the simulated screen.
local function ahead(sx: number, sy: number, depth: number): Vector3?
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local layout = Screen.layout()
	local w, h = layout.fullSize.width * layout.scale, layout.fullSize.height * layout.scale
	local ray = camera:ViewportPointToRay(w * sx, h * sy)
	return ray.Origin + ray.Direction * depth
end

local DASH_TEXT = { Touch = "guide.dash", Keys = "guide.dash_press", Pad = "guide.dash_press" }
local SWIM_TEXT = { Touch = "guide.drag", Keys = "guide.mouse", Pad = "guide.stick" }

local function guide(name: string?): string
	if not Guide.isMounted() then
		Guide.mount({
			inputMode = InputController.mode,
			modeChanged = InputController.onModeChanged,
		})
	end
	Guide.reset()
	local camera = workspace.CurrentCamera
	-- Home up and to the left, so its marker rides the top of the ellipse, well off the danger
	-- edge on the left (which would leave a gap round it anyway, 04 §3.2).
	local home = if camera then (camera.CFrame * CFrame.new(-200, 350, -100)).Position else nil
	UIController.setPreview({ dashLeft = 0, home = if name == "point" then home else nil })
	if name == "point" then
		Guide.point(Guide.hud("HUD.Dash"), {
			pointer = "arrow",
			textKey = DASH_TEXT,
			hint = "dash",
			ring = true,
		})
		-- A trail from just in front of the creature to a point up and to the left.
		local from = ahead(0.5, 0.58, 14)
		local to = ahead(0.22, 0.36, 90)
		if from and to then
			Guide.setCreature(function()
				return from
			end)
			Guide.trail(to)
		end
		Guide.home(true)
		Guide.danger(ahead(0.02, 0.5, 40))
	elseif name == "tap" then
		Guide.point(
			Guide.hud("HUD.MassBar"),
			{ pointer = "tap", textKey = "guide.grow", cutout = true }
		)
		Guide.dashPulse(true)
	elseif name == "hold" then
		Guide.point(Guide.hud("HUD.Dash"), {
			pointer = "hold",
			textKey = DASH_TEXT,
			hint = "dash",
			slot = true,
			hold = 1.2,
		})
		Guide.tick(true)
	elseif name == "ghost" then
		local target = ahead(0.66, 0.42, 40)
		if target then
			Guide.ghost(Guide.world(target))
		end
		Guide.bubble(SWIM_TEXT, Guide.CREATURE, { hint = "swim" })
	else
		Guide.setCreature(nil)
		UIController.setPreview(nil)
		return "guide off"
	end
	return `guide {name} {Guide.inputMode()} on {Screen.layout().screenClass}`
end

-- Every shown guide part's rect in rpx of the content box, and any overlap with the keep-clear
-- box or the HUD (the target's own element excepted).
local function guideCheck(): string
	local layout = Screen.layout()
	local scale = layout.scale
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local layer = gui:FindFirstChild("GulpGuide")
	local canvas = layer and layer:FindFirstChild("Guide", true)
	if canvas == nil or not canvas:IsA("GuiObject") then
		return "guide not mounted"
	end
	local origin = canvas.AbsolutePosition
	local rects = HudLayout.compute(layout.screenClass, layout.contentSize, layout.keepOut)
	local out: { string } = { `scale {string.format("%.3f", scale)}` }
	local names = {
		"UI_Guide_Arrow",
		"UI_Guide_ArrowCurved",
		"Hand",
		"UI_Guide_Ring",
		"Guide.HomeRing",
		"Guide.DashPulse",
		"Hole",
		"UI_Guide_Bubble",
		"UI_Common_Check",
		"Thumbprint",
		"GhostKeys",
		"Chip",
		"UI_HUD_DangerEdge",
		"CueArrow",
		"HoldRing",
		"Rim",
	}
	for _, d in canvas:GetDescendants() do
		if d:IsA("GuiObject") and table.find(names, d.Name) then
			local o = d :: GuiObject
			local node: Instance? = o
			local visible = true
			while node and node ~= canvas do
				if node:IsA("GuiObject") and not (node :: GuiObject).Visible then
					visible = false
				end
				node = node.Parent
			end
			if visible then
				local p = (o.AbsolutePosition - origin) / scale
				local sz = o.AbsoluteSize / scale
				local r = { x = p.X, y = p.Y, width = sz.X, height = sz.Y }
				local flags = {}
				if HudLayout.overlaps(r, rects.keepClear) then
					table.insert(flags, "KEEPCLEAR")
				end
				if HudLayout.overlaps(r, rects.massBar) then
					table.insert(flags, "massbar")
				end
				if HudLayout.overlaps(r, rects.dashHit) then
					table.insert(flags, "dash")
				end
				local label = if o.Name == "Chip" then (o.Parent :: Instance).Name else o.Name
				table.insert(
					out,
					`{label} {math.round(r.x)},{math.round(r.y)} {math.round(r.width)}x{math.round(
						r.height
					)}{if #flags > 0 then " " .. table.concat(flags, ",") else ""}`
				)
			end
		end
		if d:IsA("TextLabel") and d.Text ~= "" then
			local node: Instance? = d
			local visible = true
			while node and node ~= canvas do
				if node:IsA("GuiObject") and not (node :: GuiObject).Visible then
					visible = false
				end
				node = node.Parent
			end
			if visible and d.TextTransparency < 0.9 then
				table.insert(
					out,
					`text "{d.Text}" {d:GetAttribute("TextRpx") or "?"}->{d.TextSize} drawn {string.format(
						"%.1f",
						d.TextBounds.Y / scale
					)}`
				)
			end
		end
	end
	return table.concat(out, "; ")
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
		elseif command == "open" and (arg == "S12card" or arg == "S12small") then
			local small = arg == "S12small"
			UIController.open("S12", {
				mass = if small then 9 else 86,
				multipliers = if small
					then {}
					else {
						{ nameKey = "trait.crystal", value = 1.5, icon = "trait" },
						{ nameKey = "pass.deep_pockets", value = 2, icon = "pass" },
					},
				total = if small then 27 else 774,
				best = not small,
				specimen = if small
					then nil
					else {
						sp = "minnow",
						tier = 4,
						traits = { "crystal", "glow", "stripes" },
						perHour = 32,
					},
				tooSmall = small,
			})
			return arg
		elseif command == "cove" then
			return cove(arg ~= "off")
		elseif command == "tierup" then
			local tier = tonumber(arg) or 2
			Hud.clearMoments()
			Hud.tierUp(tier, tier - 1, if holding then 3600 else nil)
			return `S07 tier {tier}`
		elseif command == "trait" then
			Hud.clearMoments()
			Hud.traitGained(arg or "glow", 1, if holding then 3600 else nil)
			return `S08 {arg or "glow"}`
		elseif command == "hold" then
			holding = arg ~= "off"
			return `hold {holding}`
		elseif command == "mode" and (arg == "Touch" or arg == "Keys" or arg == "Pad") then
			if not Guide.isMounted() then
				Guide.mount()
			end
			Guide.setInputMode(arg)
			return `mode {arg}`
		elseif command == "guide" then
			return guide(arg)
		elseif command == "guidecheck" then
			return guideCheck()
		elseif command == "close" and (arg == "S11" or arg == "S12") then
			UIController.close(arg)
			return "closed"
		end
		UIController.setPreview(nil)
		Hud.clearMoments()
		holding = false
		outlineDemo(false)
		cove(false)
		if Guide.isMounted() then
			guide("off")
		end
		return "reset"
	end
	f.Parent = parent
end

return HudHarness
