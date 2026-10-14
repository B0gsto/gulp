--!strict
-- Hud: the run HUD (S03), build stage 1 of docs/08 section 15: `HUD.MassBar` and `HUD.Dash` on
-- the `GulpHUD` layer; `HUD.DragRing`, `HUD.MassPops` and `HUD.Home` on the full-screen
-- `GulpWorld` layer; `HUD.Outlines` switches the world's outline shells (08 §3.11). Rects come
-- from `Shared.Logic.HudLayout`; UIController builds it and feeds it each frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)
local Outlines = require("../../Render/Outlines")
local Screen = require("../Kit/Screen")

local Dash = require("./Dash")
local DragRing = require("./DragRing")
local Home = require("./Home")
local MassBar = require("./MassBar")
local MassPops = require("./MassPops")

local Hud = {}

export type Id =
	"HUD.MassBar"
	| "HUD.Dash"
	| "HUD.DragRing"
	| "HUD.MassPops"
	| "HUD.Outlines"
	| "HUD.Home"

export type Tick = {
	now: number,
	inputMode: "Touch" | "Keys" | "Pad",
	dashLeft: number,
	dashBlocked: boolean,
	drag: { active: boolean, ox: number, oy: number, tx: number, ty: number },
	mouth: Vector3?,
	home: Vector3?,
	camera: Camera?,
}

type Built = {
	massBar: MassBar.MassBar,
	dash: Dash.Dash,
	dragRing: DragRing.DragRing,
	pops: MassPops.MassPops,
	home: Home.Home,
	hudRoot: Frame,
	worldRoot: Frame,
}

local built: Built? = nil
local rects: HudLayout.HudRects? = nil
local visible: { [string]: boolean } = {
	["HUD.MassBar"] = true,
	["HUD.Dash"] = true,
	["HUD.DragRing"] = true,
	["HUD.MassPops"] = true,
	["HUD.Outlines"] = true,
	["HUD.Home"] = true,
}
local shown = true -- false while a post-run screen covers the HUD

local function apply()
	local b = built
	if not b then
		return
	end
	b.massBar.root.Visible = shown and visible["HUD.MassBar"]
	b.dash.root.Visible = shown and visible["HUD.Dash"]
	b.dragRing.root.Visible = shown and visible["HUD.DragRing"]
	b.pops.root.Visible = shown and visible["HUD.MassPops"]
	b.home.root.Visible = shown and visible["HUD.Home"]
	Outlines.setVisible(visible["HUD.Outlines"])
end

local function relayout(layout: Screen.Layout)
	local b = built
	if not b then
		return
	end
	local r = HudLayout.compute(layout.screenClass, layout.contentSize, layout.keepOut)
	rects = r
	b.massBar.layout(r.massBar.x, r.massBar.y, r.massBar.width)
	local tile = HudLayout.minTarget(layout.screenClass) == HudLayout.MOUSE_MIN
	b.dash.layout(r.dash.x, r.dash.y, r.dash.width, r.dash.height, r.dashHit.width, tile)
end

--- Builds the stage 1 HUD. `press` is `InputController.press` for the dash button.
function Hud.build(press: (action: "Dash" | "Ability", down: boolean) -> ())
	if built then
		return
	end
	local _, hudRoot = Screen.createLayer("GulpHUD")
	local _, worldRoot = Screen.createLayer("GulpWorld")
	built = {
		massBar = MassBar.new(hudRoot),
		dash = Dash.new(hudRoot, function(down: boolean)
			press("Dash", down)
		end),
		dragRing = DragRing.new(worldRoot),
		pops = MassPops.new(worldRoot),
		home = Home.new(worldRoot),
		hudRoot = hudRoot,
		worldRoot = worldRoot,
	}
	relayout(Screen.layout())
	Screen.changed:connect(relayout)
	apply()
end

--- `HUD.setVisible(id, bool)` (08 §3.3): chapter 04 shows and hides elements by ID.
function Hud.setVisible(id: Id, on: boolean)
	visible[id] = on
	apply()
end

function Hud.isVisible(id: Id): boolean
	return visible[id]
end

--- Hides the whole run HUD while the gulped panel or bank summary is up (08 §4.4, §4.5).
function Hud.setShown(on: boolean)
	shown = on
	apply()
end

--- The mass to show (the `Mass` attribute). Rises add a pop at the mouth.
function Hud.setMass(mass: number, previous: number?, instant: boolean?)
	local b = built
	if not b then
		return
	end
	b.massBar.set(mass, instant)
	if previous and mass > previous and not instant then
		b.pops.push(mass - previous, os.clock())
	end
end

function Hud.setHomeBest(best: boolean)
	local b = built
	if b then
		b.home.setBest(best)
	end
end

-- World point to full-screen rpx; `front` false when it is behind the camera.
local function project(camera: Camera, point: Vector3, scale: number): (number, number, boolean)
	local v = camera:WorldToViewportPoint(point)
	return v.X / scale, v.Y / scale, v.Z > 0
end

--- One frame of the HUD.
function Hud.update(f: Tick)
	local b = built
	local r = rects
	if not b or not r or not shown then
		return
	end
	local layout = Screen.layout()
	local scale = layout.scale
	b.massBar.update(f.now)
	b.dash.update(f.dashLeft, f.dashBlocked)

	local d = f.drag
	b.dragRing.update(f.inputMode == "Touch" and d.active, d.ox, d.oy, d.tx, d.ty, layout.fullSize)

	local camera = f.camera
	local mx, my: number? = nil, nil
	if camera and f.mouth then
		local x, y, front = project(camera, f.mouth, scale)
		if front then
			mx, my = x, y
		end
	end
	b.pops.update(f.now, mx, my)

	if camera and f.home and visible["HUD.Home"] then
		local origin = layout.contentOrigin
		local content = layout.contentSize
		local x, y, front = project(camera, f.home, scale)
		local cx, cy = x - origin.x, y - origin.y
		local studs = (f.home - camera.Focus.Position).Magnitude
		if front and cx >= 0 and cy >= 0 and cx <= content.width and cy <= content.height then
			b.home.place({ x = x, y = y, onScreen = true, angle = 0, studs = studs })
		else
			local dx, dy = cx - content.width / 2, cy - content.height / 2
			if not front then
				dx, dy = -dx, -dy
			end
			local angle = math.atan2(dy, dx)
			local hx, hy, used = HudLayout.homeMarker(content, angle, { r.dash, r.ability })
			local _ = used
			b.home.place({
				x = hx + origin.x,
				y = hy + origin.y,
				onScreen = false,
				angle = angle,
				studs = studs,
			})
		end
	else
		b.home.place(nil)
	end
end

return Hud
