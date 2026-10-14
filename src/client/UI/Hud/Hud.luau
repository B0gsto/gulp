--!strict
-- Hud: the run HUD (S03), build stage 1 of docs/08 section 15: `HUD.MassBar` and `HUD.Dash` on
-- the `GulpHUD` layer; `HUD.DragRing`, `HUD.MassPops` and `HUD.Home` on the full-screen
-- `GulpWorld` layer; `HUD.Outlines` switches the world's outline shells (08 §3.11). `HUD.Traits`
-- (08 §3.6) on `GulpHUD` and `HUD.TraitMarkers` (08 §3.10, while Glow is held) on `GulpWorld`
-- (task S6-C3). `HUD.MomentSlot` (08 §4.1) on the `GulpMoments` layer plays S07 tier-up and S08
-- trait gained. Rects come from `Shared.Logic.HudLayout`; UIController builds it and feeds it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)
local HudMath = require(ReplicatedStorage.Shared.Logic.HudMath)
local MomentQueue = require(ReplicatedStorage.Shared.Logic.MomentQueue)
local Outlines = require("../../Render/Outlines")
local PreyRenderer = require("../../Render/PreyRenderer")
local Screen = require("../Kit/Screen")
local TraitRules = require(ReplicatedStorage.Shared.Logic.TraitRules)
local Types = require(ReplicatedStorage.Shared.Types)

local Dash = require("./Dash")
local DragRing = require("./DragRing")
local Home = require("./Home")
local MassBar = require("./MassBar")
local MassPops = require("./MassPops")
local MomentSlot = require("./MomentSlot")
local TierUp = require("./TierUp")
local TraitGained = require("./TraitGained")
local TraitMarkers = require("./TraitMarkers")
local Traits = require("./Traits")

local Hud = {}

export type Id =
	"HUD.MassBar"
	| "HUD.Dash"
	| "HUD.DragRing"
	| "HUD.MassPops"
	| "HUD.Outlines"
	| "HUD.Home"
	| "HUD.MomentSlot"
	| "HUD.Traits"
	| "HUD.TraitMarkers"

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
	moments: MomentSlot.Slot,
	traits: Traits.Traits,
	markers: TraitMarkers.TraitMarkers,
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
	["HUD.MomentSlot"] = true,
	["HUD.Traits"] = true,
	["HUD.TraitMarkers"] = true,
}
local shown = true -- false while a post-run screen covers the HUD
local inCove = false -- 08 §5.1: in the cove the mass bar and its pops are hidden
-- `Phase = dead`: the traits and their pips are hidden until the respawn clears them (02 §8.1;
-- TraitService resets them only when Swim again moves the creature) or a revive brings them back.
local gulped = false
-- HUD.Traits and HUD.TraitMarkers (S6-C3): the held traits, a pip recency counter per trait for
-- TraitRules.slotView's ties, the trait rects, and scratch for the per-frame marker pick.
local heldTraits: { string } = {}
local heldSeen: { [string]: number } = {} -- TraitRules.noteHeld: Glow's markers start 0.5 s late
local heldRead = false
local lastPips: { [string]: number } = {}
local pipRecency: { [string]: number } = {}
local pipClock = 0
local traitRects: HudLayout.TraitRects? = nil
local nearTraitPrey: { PreyRenderer.TraitPreyNear } = {}
local markerPick: { PreyRenderer.TraitPreyNear } = {}

local function apply()
	local b = built
	if not b then
		return
	end
	b.massBar.root.Visible = shown and visible["HUD.MassBar"] and not inCove
	b.dash.root.Visible = shown and visible["HUD.Dash"]
	b.dragRing.root.Visible = shown and visible["HUD.DragRing"]
	b.pops.root.Visible = shown and visible["HUD.MassPops"] and not inCove
	b.home.root.Visible = shown and visible["HUD.Home"]
	b.moments.root.Visible = shown and visible["HUD.MomentSlot"]
	b.traits.root.Visible = shown and visible["HUD.Traits"] and not inCove and not gulped
	b.markers.root.Visible = shown and visible["HUD.TraitMarkers"] and not inCove and not gulped
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
	local m = HudLayout.momentCardSlot(layout.contentSize)
	b.moments.layout(m.x, m.y, m.width, m.height)
	traitRects = HudLayout.traits(layout.screenClass, layout.contentSize)
	b.traits.layout(traitRects :: HudLayout.TraitRects) -- safe: assigned on the line above
end

--- Builds the stage 1 HUD. `press` is `InputController.press` for the dash button.
function Hud.build(press: (action: "Dash" | "Ability", down: boolean) -> ())
	if built then
		return
	end
	local _, hudRoot = Screen.createLayer("GulpHUD")
	local _, worldRoot = Screen.createLayer("GulpWorld")
	local _, momentRoot = Screen.createLayer("GulpMoments")
	built = {
		massBar = MassBar.new(hudRoot),
		dash = Dash.new(hudRoot, function(down: boolean)
			press("Dash", down)
		end),
		dragRing = DragRing.new(worldRoot),
		pops = MassPops.new(worldRoot),
		home = Home.new(worldRoot),
		moments = MomentSlot.new(momentRoot),
		traits = Traits.new(hudRoot),
		markers = TraitMarkers.new(worldRoot),
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

--- In the cove (08 §5.1) the run HUD keeps only the dash button and the drag ring; the cove HUD
--- (S14) takes the top of the screen.
function Hud.setCove(on: boolean)
	inCove = on
	apply()
end

--- While gulped (`Phase = dead`) HUD.Traits and HUD.TraitMarkers are hidden.
function Hud.setGulped(on: boolean)
	gulped = on
	apply()
end

--- The GulpHUD layer's root, for the cove HUD (S14); nil before `build`.
function Hud.root(): Frame?
	local b = built
	return if b then b.hudRoot else nil
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

--- S07 (08 §4.2) for the local creature's tier change; only a rise shows. `hold` replaces the
--- 08 §4.1 hold (chapter 04's banners: 1.5 s, docs/14 section 4 row 35).
function Hud.tierUp(tier: number, previous: number, hold: number?)
	local b = built
	if not b or tier <= previous then
		return
	end
	local data: TierUp.Data = {
		tier = tier,
		previous = previous,
		food = HudMath.newFood(previous, tier),
	}
	b.moments.push("tierUp", hold or TierUp.hold(data), function(parent, slot)
		return TierUp.build(parent, slot, data)
	end, data)
end

--- S08 (08 §4.3) for a trait the local creature gained in trait slot `slotIndex`, with the slot's
--- Just gained flash (08 §3.6). `hold` as for `tierUp`.
function Hud.traitGained(traitId: string, slotIndex: number, hold: number?)
	local b = built
	if not b then
		return
	end
	b.traits.gained(slotIndex)
	local data: TraitGained.Data = { traitId = traitId, slotIndex = slotIndex }
	b.moments.push("trait", hold or TraitGained.hold(data), function(parent, slot)
		return TraitGained.build(parent, slot, data)
	end, data)
end

--- Fires as a moment card begins to enter and after it has gone, with its kind ("tierUp",
--- "trait") and data (`TierUp.Data`, `TraitGained.Data`); nil before `build`.
function Hud.moments(): (Types.Signal<MomentQueue.Kind, any>?, Types.Signal<MomentQueue.Kind, any>?)
	local b = built
	if b then
		return b.moments.shown, b.moments.ended
	end
	return nil, nil
end

--- Drops every moment card and the queue (Studio harness).
function Hud.clearMoments()
	local b = built
	if b then
		b.moments.clear()
	end
end

function Hud.setHomeBest(best: boolean)
	local b = built
	if b then
		b.home.setBest(best)
	end
end

--- The held traits and pips of the run (`run.traits`, `run.progress`, 09 §5.3) for HUD.Traits
--- (08 §3.6), and whether Keen Nose cuts the pips to four.
function Hud.setTraits(traits: { string }, progress: { [string]: number }, keenNose: boolean)
	heldTraits = traits
	TraitRules.noteHeld(heldSeen, traits, os.clock(), not heldRead)
	heldRead = true
	for id, count in progress do
		if count > (lastPips[id] or 0) then
			pipClock += 1
			pipRecency[id] = pipClock
		end
	end
	lastPips = table.clone(progress)
	local b = built
	if b then
		b.traits.set(TraitRules.slotView(traits, progress, pipRecency, keenNose))
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
	if b then
		b.moments.update(f.now) -- moments keep time under S11 and S12 (tier-up and trait always play)
	end
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

	-- 02 §8.4 Glow: the six nearest trait prey within 60 studs, ring on screen, edge off screen,
	-- from 0.5 s after the gain (02 §8.2).
	local markers = 0
	local glowAt = heldSeen.glow
	if
		camera
		and visible["HUD.TraitMarkers"]
		and not inCove
		and not gulped
		and glowAt ~= nil
		and TraitRules.isActive(glowAt, f.now)
	then
		local n = PreyRenderer.traitPreyNear(TraitRules.GLOW_RADIUS, nearTraitPrey)
		table.clear(markerPick)
		for i = 1, n do
			markerPick[i] = nearTraitPrey[i]
		end
		markers = TraitRules.pickMarkers(markerPick :: { any }) -- safe: records carry the fields
		local origin, content = layout.contentOrigin, layout.contentSize
		for i = 1, markers do
			local prey = markerPick[i]
			local x, y, front = project(camera, prey.position, scale)
			local cx, cy = x - origin.x, y - origin.y
			local onScreen = front
				and cx >= 0
				and cy >= 0
				and cx <= content.width
				and cy <= content.height
			local angle = 0
			if not onScreen then
				local dx, dy = cx - content.width / 2, cy - content.height / 2
				if not front then
					dx, dy = -dx, -dy
				end
				angle = math.atan2(dy, dx)
				local ex, ey = HudLayout.traitMarkerEdge(content, angle)
				x, y = ex + origin.x, ey + origin.y
			end
			b.markers.place(i, {
				x = x,
				y = y,
				onScreen = onScreen,
				angle = angle,
				traitId = prey.traitId,
				dimmed = TraitRules.has(heldTraits, prey.traitId),
			})
		end
	end
	b.markers.hideFrom(markers + 1)

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
			-- The drag ring in content-box rpx, while a touch steers (08 §3.12 keep-out).
			local ring: HudLayout.Rect? = nil
			if f.inputMode == "Touch" and d.active then
				local pose = HudLayout.dragRing(d.ox, d.oy, d.tx, d.ty, layout.fullSize)
				ring = HudLayout.ringRect(pose.ringX - origin.x, pose.ringY - origin.y)
			end
			local avoid = HudLayout.homeAvoid(layout.screenClass, r, ring)
			if traitRects then
				table.insert(avoid, traitRects.row) -- the home marker slides around the slots too
			end
			local hx, hy, used = HudLayout.homeMarker(content, angle, avoid)
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
