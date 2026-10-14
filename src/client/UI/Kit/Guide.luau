--!strict
-- Kit/Guide: the first-time prompt kit, screen S33 (docs/08 section 7; docs/04 section 3.2), on
-- the `GulpGuide` layer. A tutorial director (chapter 04's script) drives it; it owns no script.
-- Parts are drawn by Kit/GuideParts and Kit/GuideHints, placed by Shared.Logic.HudLayout.
--
-- TARGETS. Every part points at a target, resolved again each frame:
--   Guide.hud("HUD.Dash")          a HUD element by its 08 §3.3 ID (any GuiObject of that name;
--                                  `HUD.Home` means its marker); hidden while the element is
--   Guide.world(position)          a world position (Vector3); off screen, parts lead to it
--   Guide.screen(x, y)             a point in content-box rpx (the HudLayout space)
--   Guide.gui(guiObject)           any GuiObject
--   Guide.CREATURE                 the player's creature (a bubble for it uses the moment slot)
--
-- THE CALLS OF 08 §7 (a step is one pointer, one bubble, a ring and a cut-out):
--   Guide.point(target, opts)      opts: pointer = "arrow" | "tap" | "hold" | "drag" (nil: none),
--                                  textKey = "guide.dash" or { Touch = .., Keys = .., Pad = .. },
--                                  args = Loc args ({Button} is filled from `hint` if absent),
--                                  hint = "swim" | "dash" | "ability" | "tap" (the G8 picture),
--                                  ring = bool, cutout = bool, hold = seconds (default 1),
--                                  from = target (where a drag starts; default the ghost point),
--                                  slot = bool (bubble in the moment slot, the curved arrow joins)
--   Guide.trail(worldPosition?)    G4 from the creature to there; nil clears it
--   Guide.done()                   G9 tick on the bubble with SFX_UI_GuideStep, then clear()
--   Guide.clear()                  clears the step (pointer, bubble, ring, cut-out, ghost, trail)
-- CHAPTER 04's PROMPTS (04 §3.2; they stay until turned off, clear() leaves them):
--   Guide.ghost(target?, { long = bool })   the ghost thumb toward target; nil hides it
--   Guide.home(on)                 ring and the HOME chip on `HUD.Home`'s marker
--   Guide.dashPulse(on)            the white pulse and DASH! on `HUD.Dash`
--   Guide.danger(worldPosition?)   the red edge on the predator's side; nil fades it (0.5 s)
-- ONE PART AT A TIME (what point() is made of; each nil or false hides its part):
--   Guide.arrow(target?)           G1; off screen it rides the edge toward the target
--   Guide.hand(target?, gesture?, opts?)   G3 "tap" | "hold" | "drag"; opts.hold, opts.from
--   Guide.ring(target?)            G5
--   Guide.cutout(target?)          G6 (catches taps outside the hole; never in open water)
--   Guide.bubble(textKey?, target?, opts?)  G7; opts.args, opts.hint (G8 inside it), opts.slot;
--                                  the curved arrow (G2) appears by itself when it is needed
--   Guide.hint(action?)            G8: the picture in the bubble
--   Guide.tick(stay?)              G9 alone; `stay` keeps it after the pop
-- STATE:
--   Guide.mount(opts?)             builds the layer once; opts.inputMode () -> InputMode and
--                                  opts.modeChanged Signal<InputMode> (InputController's)
--   Guide.setInputMode(mode)       swaps every picture and text at once (G8: within 200 ms)
--   Guide.setLessMotion(on)        bobbing and pulsing become a 0.5 Hz fade
--   Guide.setSuppressed(on)        an unrelated menu is open: everything hides, state is kept
--   Guide.setCreature(fn?)         where the creature is (default: the local character)
--   Guide.reset()                  clears everything, the chapter 04 prompts too
--
-- RULES (08 §7) kept here: at most one pointer (arrow, hand or ghost thumb) and one bubble; parts
-- fade in within 200 ms and out within 100 ms; 6 s without input replays the pointer with a
-- bounce; nothing blocks steering except the cut-out; nothing covers the keep-clear box or the
-- HUD (HudLayout's rules; the ghost thumb's drag is the one exception); text only by key.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)
local Types = require(ReplicatedStorage.Shared.Types)

local GuideHints = require("./GuideHints")
local GuideParts = require("./GuideParts")
local Loc = require("../Loc")
local Screen = require("./Screen")
local Theme = require("./Theme")

local G = HudLayout.GUIDE

type Rect = HudLayout.Rect
type Size = HudLayout.Size
export type InputMode = Types.InputMode
export type Action = GuideHints.Action
export type Gesture = GuideParts.Gesture
export type TextKey = string | { [string]: string }

export type Target = {
	kind: "hud" | "world" | "screen" | "gui" | "creature",
	id: string?,
	position: Vector3?,
	x: number?,
	y: number?,
	gui: GuiObject?,
}

export type PointOptions = {
	pointer: ("arrow" | Gesture)?,
	textKey: TextKey?,
	args: { [any]: any }?,
	hint: Action?,
	ring: boolean?,
	cutout: boolean?,
	hold: number?,
	from: Target?,
	slot: boolean?,
}

local Guide = {}

--- A HUD element by its 08 §3.3 ID.
function Guide.hud(id: string): Target
	return { kind = "hud", id = id }
end

--- A world position.
function Guide.world(position: Vector3): Target
	return { kind = "world", position = position }
end

--- A point in content-box rpx.
function Guide.screen(x: number, y: number): Target
	return { kind = "screen", x = x, y = y }
end

--- Any GuiObject.
function Guide.gui(object: GuiObject): Target
	return { kind = "gui", gui = object }
end

local CREATURE: Target = { kind = "creature" }
Guide.CREATURE = table.freeze(CREATURE)

-- The part of a HUD element a guide points at, when it is not the element's root.
local FOCUS: { [string]: string } = { ["HUD.Home"] = "Marker" }

type Resolved = { rect: Rect, onScreen: boolean, angle: number, creature: boolean }
type Fade = { alpha: number, want: boolean }

type Built = {
	gui: ScreenGui,
	canvas: Frame,
	arrow: GuideParts.Arrow,
	curved: GuideParts.Curved,
	hand: GuideParts.Hand,
	trail: GuideParts.Trail,
	ring: GuideParts.Ring,
	homeRing: GuideParts.Ring,
	dashRing: GuideParts.Ring,
	cutout: GuideParts.Cutout,
	bubble: GuideParts.Bubble,
	tick: GuideParts.Tick,
	ghost: GuideParts.Ghost,
	homeTag: GuideParts.Tag,
	dashTag: GuideParts.Tag,
	danger: GuideParts.Danger,
}

local built: Built? = nil
local playerGui: PlayerGui? = nil
local mode: InputMode = "Touch"
local lessMotion = false
local suppressed = false
local creatureOf: (() -> Vector3?)? = nil
local lastInput = os.clock()

-- What the director asked for.
local pointer: {
	kind: ("arrow" | "hand")?,
	target: Target?,
	gesture: Gesture,
	hold: number,
	from: Target?,
	started: number,
	bounceAt: number,
} =
	{ kind = nil, target = nil, gesture = "tap", hold = 1, from = nil, started = 0, bounceAt = -1 }
local ringTarget: Target? = nil
local cutoutTarget: Target? = nil
local bubble: { key: TextKey?, args: { [any]: any }?, target: Target?, hint: Action?, slot: boolean } =
	{ key = nil, args = nil, target = nil, hint = nil, slot = false }
local tickState: { started: number, stay: boolean }? = nil
local trailState: { origin: Vector3, target: Vector3 }? = nil
local ghostState: { target: Target, long: boolean, started: number }? = nil
local homeOn = false
local dashOn = false
local dangerAt: Vector3? = nil
local dangerSide: HudLayout.Side = "left"

local fades: { [string]: Fade } = {}
local function fade(name: string): Fade
	local f = fades[name]
	if not f then
		f = { alpha = 0, want = false }
		fades[name] = f
	end
	return f
end

-- Builds the bubble's and chips' text and pictures for the current input mode.
local refreshText: () -> () = function() end

local function now(): number
	return os.clock()
end

-- Target resolution -----------------------------------------------------------------------------

local found: { [string]: GuiObject } = {}

local function shown(object: GuiObject): boolean
	local node: Instance? = object
	while node do
		if node:IsA("GuiObject") then
			if not (node :: GuiObject).Visible then
				return false
			end
		elseif node:IsA("ScreenGui") then
			return (node :: ScreenGui).Enabled
		end
		node = node.Parent
	end
	return false
end

local function findHud(id: string): GuiObject?
	local pg = playerGui
	if pg == nil then
		return nil
	end
	local cached = found[id]
	if cached and cached:IsDescendantOf(pg) then
		return cached
	end
	local b = built
	local object: Instance? = nil
	for _, layer in pg:GetChildren() do
		if layer:IsA("ScreenGui") and (b == nil or layer ~= b.gui) then
			object = layer:FindFirstChild(id, true)
			if object then
				break
			end
		end
	end
	local focus = FOCUS[id]
	if object and focus then
		object = object:FindFirstChild(focus, true)
	end
	if object and object:IsA("GuiObject") then
		found[id] = object
		return object
	end
	return nil
end

local function creaturePosition(): Vector3?
	local fn = creatureOf
	if fn then
		return fn()
	end
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local root = character and character.PrimaryPart
	return if root then root.Position else nil
end

local function resolve(target: Target?): Resolved?
	local b = built
	if target == nil or b == nil then
		return nil
	end
	local layout = Screen.layout()
	local scale = layout.scale
	local content = layout.contentSize
	local origin = b.canvas.AbsolutePosition
	local function fromGui(object: GuiObject): Resolved?
		if not shown(object) then
			return nil
		end
		local p = (object.AbsolutePosition - origin) / scale
		local s = object.AbsoluteSize / scale
		local rect = { x = p.X, y = p.Y, width = s.X, height = s.Y }
		local cx, cy = p.X + s.X / 2, p.Y + s.Y / 2
		return {
			rect = rect,
			onScreen = true,
			angle = math.atan2(cy - content.height / 2, cx - content.width / 2),
			creature = false,
		}
	end
	if target.kind == "hud" then
		local object = findHud(target.id or "")
		return if object then fromGui(object) else nil
	elseif target.kind == "gui" then
		local object = target.gui
		return if object and object.Parent then fromGui(object) else nil
	elseif target.kind == "screen" then
		local x, y = target.x or 0, target.y or 0
		return {
			rect = { x = x, y = y, width = 0, height = 0 },
			onScreen = true,
			angle = math.atan2(y - content.height / 2, x - content.width / 2),
			creature = false,
		}
	end
	local position = if target.kind == "creature" then creaturePosition() else target.position
	local camera = workspace.CurrentCamera
	if position == nil or camera == nil then
		return nil
	end
	local v = camera:WorldToViewportPoint(position)
	local x = (v.X - origin.X) / scale
	local y = (v.Y - origin.Y) / scale
	local dx, dy = x - content.width / 2, y - content.height / 2
	local front = v.Z > 0
	if not front then
		dx, dy = -dx, -dy
	end
	local on = front and x >= 0 and y >= 0 and x <= content.width and y <= content.height
	return {
		rect = { x = x, y = y, width = 0, height = 0 },
		onScreen = on,
		angle = math.atan2(dy, dx),
		creature = target.kind == "creature",
	}
end

local function centre(r: Rect): (number, number)
	return r.x + r.width / 2, r.y + r.height / 2
end

-- Text -------------------------------------------------------------------------------------------

local function keyFor(key: TextKey): string
	if type(key) == "string" then
		return key
	end
	return key[mode] or key.Touch or key.Keys or ""
end

local function textOf(key: TextKey, args: { [any]: any }?, action: Action?): string
	local a = args
	if a == nil and action then
		a = { Button = GuideHints.buttonText(action, mode) }
	end
	return Loc.t(keyFor(key), a)
end

-- Building ----------------------------------------------------------------------------------------

local function build()
	local gui, root = Screen.createLayer("GulpGuide")
	local canvas = Instance.new("Frame")
	canvas.Name = "Guide"
	canvas.BackgroundTransparency = 1
	canvas.BorderSizePixel = 0
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.Parent = root
	local b: Built = {
		gui = gui,
		canvas = canvas,
		cutout = GuideParts.cutout(canvas, 1),
		danger = GuideParts.danger(canvas, 2),
		trail = GuideParts.trail(canvas, 4),
		ring = GuideParts.ring(canvas, 10),
		homeRing = GuideParts.ring(canvas, 10, "Guide.HomeRing"),
		dashRing = GuideParts.ring(
			canvas,
			10,
			"Guide.DashPulse",
			Theme.WHITE,
			"UI_Common_RingPulse"
		),
		ghost = GuideParts.ghost(canvas, 20),
		hand = GuideParts.hand(canvas, 30),
		arrow = GuideParts.arrow(canvas, 30),
		curved = GuideParts.curved(canvas, 30),
		bubble = GuideParts.bubble(canvas, 40),
		homeTag = GuideParts.tag(canvas, 40, "Guide.HomeTag", Theme.HOME, G.tagHeight, G.tagText),
		dashTag = GuideParts.tag(
			canvas,
			40,
			"Guide.DashTag",
			Theme.PRIMARY,
			G.dashTagHeight,
			G.dashTagText
		),
		tick = GuideParts.tick(canvas, 50),
	}
	built = b
	for _, part in
		{
			b.cutout,
			b.danger,
			b.trail,
			b.ring,
			b.homeRing,
			b.dashRing,
			b.ghost,
			b.hand,
			b.arrow,
			b.curved,
			b.bubble,
			b.homeTag,
			b.dashTag,
			b.tick,
		} :: { any }
	do
		part.fade(0)
	end
end

refreshText = function()
	local b = built
	if not b then
		return
	end
	if bubble.key then
		b.bubble.setText(textOf(bubble.key :: TextKey, bubble.args, bubble.hint))
	end
	b.bubble.setHint(
		if bubble.hint then GuideHints.picture(b.bubble.hintHolder, bubble.hint, mode, 44) else nil
	)
	b.ghost.setMode(mode)
	b.homeTag.setText(Loc.t("guide.home_tag"))
	b.dashTag.setText(Loc.t("guide.dash_now"))
	-- 04 §3.2: with keys the DASH! chip carries the Space cap; on a pad the A button.
	b.dashTag.setHint(
		if mode == "Touch" then nil else GuideHints.picture(b.dashTag.chip, "dash", mode, 41)
	)
end

-- The frame ---------------------------------------------------------------------------------------

local function approach(f: Fade, dt: number, slow: number?)
	local want = f.want and not suppressed
	if want then
		f.alpha = math.min(1, f.alpha + dt / G.appear)
	else
		f.alpha = math.max(0, f.alpha - dt / (slow or G.clear))
	end
end

-- 08 §7 Less motion: bobbing and pulsing become a slow fade.
local function breathe(t: number): number
	return if lessMotion then 0.7 + 0.3 * math.cos(2 * math.pi * G.lessMotionHz * t) else 1
end

local function bounce(t: number): number
	local u = (t - pointer.bounceAt) / G.bounce
	return if u >= 0 and u <= 1 then 1 + 0.3 * math.sin(math.pi * u) else 1
end

local function hudAvoid(layout: Screen.Layout): ({ Rect }, HudLayout.HudRects)
	local rects = HudLayout.compute(layout.screenClass, layout.contentSize, layout.keepOut)
	local avoid = {
		rects.massBar,
		rects.dashHit,
		HudLayout.hitRect(rects.ability, HudLayout.minTarget(layout.screenClass)),
	}
	for _, k in layout.keepOut do
		table.insert(avoid, k)
	end
	return avoid, rects
end

local function step(dt: number)
	local b = built
	if not b then
		return
	end
	local t = now()
	local layout = Screen.layout()
	local scale = layout.scale
	local content = layout.contentSize
	local avoid, rects = hudAvoid(layout)
	local glow = breathe(t)

	-- 08 §7: six seconds with no input replays the pointer with a bounce.
	if (pointer.kind or ghostState) and t - lastInput > G.idle then
		lastInput = t
		pointer.started = t
		pointer.bounceAt = t
		local gs = ghostState
		if gs then
			gs.started = t
		end
	end

	-- Danger edge (04 §3.2): the side the predator is on, fading out over 0.5 s.
	local fd = fade("danger")
	if dangerAt then
		local camera = workspace.CurrentCamera
		if camera then
			local v = camera:WorldToViewportPoint(dangerAt)
			local full = layout.fullSize
			local x, y = v.X / scale - full.width / 2, v.Y / scale - full.height / 2
			if v.Z < 0 then
				x, y = -x, -y
			end
			dangerSide = HudLayout.dangerSide(math.atan2(y, x), full)
		end
	end
	fd.want = dangerAt ~= nil
	approach(fd, dt, G.dangerFade)
	do
		local edge = HudLayout.dangerEdge(dangerSide, layout.fullSize)
		local o = layout.contentOrigin
		b.danger.set(
			{ x = edge.x - o.x, y = edge.y - o.y, width = edge.width, height = edge.height },
			dangerSide
		)
		b.danger.fade(fd.alpha)
	end

	-- Home marker (04 §3.2): the ring and the HOME chip on HUD.Home's marker.
	local home = if homeOn then resolve(Guide.hud("HUD.Home")) else nil
	local fh = fade("home")
	fh.want = home ~= nil
	approach(fh, dt)
	if home then
		local hx, hy = centre(home.rect)
		local pulse = if lessMotion
			then 1
			else 1 + (G.ringPulse - 1) * (0.5 - 0.5 * math.cos(2 * math.pi * G.ringHz * t))
		b.homeRing.set(HudLayout.guideRing(home.rect), pulse)
		local w = math.max(b.homeTag.size(scale), 48)
		local homeAvoid = HudLayout.homeAvoid(layout.screenClass, rects, nil)
		b.homeTag.set(HudLayout.homeTag(hx, hy, w, content, homeAvoid))
	end
	b.homeRing.fade(fh.alpha * glow)
	b.homeTag.fade(fh.alpha)

	-- Dash pulse (04 §3.2): swells to 1.3x and back twice a second; DASH! above.
	local dash = if dashOn then resolve(Guide.hud("HUD.Dash")) else nil
	local fp = fade("dash")
	fp.want = dash ~= nil
	approach(fp, dt)
	if dash then
		local swell = if lessMotion
			then 1
			else 1 + (G.dashPulse - 1) * (0.5 - 0.5 * math.cos(2 * math.pi * G.dashPulseHz * t))
		b.dashRing.set(HudLayout.dashRing(dash.rect), swell)
		local w = math.max(b.dashTag.size(scale), 48)
		b.dashTag.set(HudLayout.dashTag(dash.rect, w, content))
	end
	-- The ring thins as it swells, like `UI_Common_RingPulse`.
	b.dashRing.fade(fp.alpha * glow)
	b.dashTag.fade(fp.alpha)

	-- G5 ring.
	local ringAt = resolve(ringTarget)
	local fr = fade("ring")
	fr.want = ringAt ~= nil and ringAt.onScreen
	approach(fr, dt)
	if ringAt and ringAt.onScreen then
		local pulse = if lessMotion
			then 1
			else 1 + (G.ringPulse - 1) * (0.5 - 0.5 * math.cos(2 * math.pi * G.ringHz * t))
		b.ring.set(HudLayout.guideRing(ringAt.rect), pulse)
	end
	b.ring.fade(fr.alpha * glow)

	-- G6 cut-out.
	local cut = resolve(cutoutTarget)
	local fc = fade("cutout")
	fc.want = cut ~= nil and cut.onScreen
	approach(fc, dt)
	if cut and cut.onScreen then
		b.cutout.set(HudLayout.guideCutout(cut.rect, layout.screenClass))
	end
	b.cutout.block(fc.want and not suppressed)
	b.cutout.fade(fc.alpha)

	-- The pointer: G1 arrow or G3 hand (the hand only on touch; with keys or a pad its gesture
	-- shows as the arrow and the G8 picture in the bubble).
	local pointerRect: Rect? = nil
	local aim = resolve(pointer.target)
	local kind = pointer.kind
	if kind == "hand" and (mode ~= "Touch" or (aim and not aim.onScreen)) then
		kind = "arrow"
	end
	local trailTarget: Resolved? = nil
	local ts = trailState
	if ts then
		trailTarget = resolve(Guide.world(ts.target))
	end
	-- G4: an off-screen trail target gets the edge arrow when no other pointer shows.
	local arrowAim = if kind == "arrow"
		then aim
		elseif
			kind == nil
			and ghostState == nil
			and trailTarget
			and not trailTarget.onScreen
		then trailTarget
		else nil
	local fa = fade("arrow")
	fa.want = arrowAim ~= nil
	approach(fa, dt)
	if arrowAim then
		local x, y, angle
		if arrowAim.onScreen then
			x, y, angle = HudLayout.guideArrow(arrowAim.rect, content, avoid)
		else
			x, y, angle = HudLayout.guideEdgeArrow(content, arrowAim.angle, avoid)
		end
		local bob = if lessMotion
			then 0
			else G.bob * (0.5 - 0.5 * math.cos(2 * math.pi * G.bobHz * (t - pointer.started)))
		b.arrow.set(x, y, angle, bob, bounce(t))
		pointerRect = HudLayout.arrowRect(x, y)
	end
	b.arrow.fade(fa.alpha * glow)

	local fhand = fade("hand")
	fhand.want = kind == "hand" and aim ~= nil
	approach(fhand, dt)
	if kind == "hand" and aim then
		local tx, ty = centre(aim.rect)
		local p = t - pointer.started
		local gesture = pointer.gesture
		if gesture == "tap" then
			local cycle = G.tapDown + G.tapUp + G.tapPause
			local u = p % cycle
			local lift = if u < G.tapDown
				then 0
				elseif u < G.tapDown + G.tapUp then 14 * (u - G.tapDown) / G.tapUp
				else 14
			b.hand.set(tx, ty - lift, u < G.tapDown, nil, nil)
		elseif gesture == "hold" then
			local hold = pointer.hold
			local cycle = hold + G.tapUp + G.tapPause
			local u = p % cycle
			if u < hold then
				b.hand.set(tx, ty, true, u / hold, nil)
			else
				local lift = 14 * math.min(1, (u - hold) / G.tapUp)
				b.hand.set(tx, ty - lift, false, nil, nil)
			end
		else
			local from = resolve(pointer.from)
			local sx, sy
			if from then
				sx, sy = centre(from.rect)
			else
				sx, sy = HudLayout.ghostThumb(content)
			end
			local cycle = G.tapDown + G.dragTime + G.tapUp + G.tapPause
			local u = p % cycle
			local m = math.clamp((u - G.tapDown) / G.dragTime, 0, 1)
			local e = m * m * (3 - 2 * m)
			local x, y = sx + (tx - sx) * e, sy + (ty - sy) * e
			local path: { Vector2 } = {}
			if u >= G.tapDown and u < G.tapDown + G.dragTime then
				for i = 7, 0, -1 do
					local k = math.max(0, m - i * 0.05)
					local ek = k * k * (3 - 2 * k)
					table.insert(path, Vector2.new(sx + (tx - sx) * ek, sy + (ty - sy) * ek))
				end
			end
			b.hand.set(x, y, u < G.tapDown + G.dragTime, nil, path)
		end
		pointerRect =
			{ x = tx - G.hand * 0.3, y = ty - G.hand * 0.06, width = G.hand, height = G.hand }
	end
	b.hand.fade(fhand.alpha)

	-- The ghost thumb (04 §3.2), a pointer of its own.
	local gs = ghostState
	local fg = fade("ghost")
	fg.want = gs ~= nil
	approach(fg, dt)
	local ghostAlpha = 1
	if gs then
		local sx, sy = HudLayout.ghostThumb(content)
		local toward = resolve(gs.target)
		local angle = -math.pi / 2
		if toward then
			if toward.onScreen and not toward.creature then
				local tx, ty = centre(toward.rect)
				angle = math.atan2(ty - sy, tx - sx)
			else
				angle = toward.angle
			end
		end
		local u = ((t - gs.started) % G.ghostLoop) / G.ghostLoop
		local nx, ny = math.cos(angle), math.sin(angle)
		if mode == "Touch" then
			local ex, ey = HudLayout.ghostDrag(content, sx, sy, angle, gs.long)
			local m = math.clamp((u - 0.1) / 0.5, 0, 1)
			local e = m * m * (3 - 2 * m)
			local press = if u < 0.1
				then u / 0.1
				elseif u < 0.7 then 1
				else math.max(0, 1 - (u - 0.7) / 0.1)
			ghostAlpha = G.ghostOpacity * (if u < 0.8 then 1 else math.max(0, 1 - (u - 0.8) / 0.12))
			b.ghost.set(sx + (ex - sx) * e, sy + (ey - sy) * e, press, nx, ny)
			pointerRect = HudLayout.ghostRect(sx, sy)
		else
			local press = if u < 0.12
				then u / 0.12
				elseif u < 0.75 then 1
				else math.max(0, 1 - (u - 0.75) / 0.1)
			local lean = math.sin(math.clamp(u / 0.75, 0, 1) * math.pi)
			b.ghost.set(sx, sy, press, nx * lean, ny * lean)
			pointerRect = HudLayout.ghostRect(sx, sy, 216)
		end
	end
	b.ghost.fade(fg.alpha * ghostAlpha)

	-- G4 trail.
	local ft = fade("trail")
	ft.want = ts ~= nil
	approach(ft, dt)
	if ts then
		local camera = workspace.CurrentCamera
		local here = creaturePosition() or ts.origin
		local line = ts.target - ts.origin
		local length = line.Magnitude
		local dir = if length > 1e-3 then line / length else Vector3.zero
		local progress = math.max(0, (here - ts.origin):Dot(dir))
		local first, last = HudLayout.trailWindow(length, progress)
		local origin = b.canvas.AbsolutePosition
		local dots: { GuideParts.TrailPoint } = {}
		local function project(d: number): (number?, number?, number?)
			if camera == nil then
				return nil, nil, nil
			end
			local v = camera:WorldToViewportPoint(ts.origin + dir * d)
			if v.Z <= 0 then
				return nil, nil, nil
			end
			return (v.X - origin.X) / scale, (v.Y - origin.Y) / scale, v.Z
		end
		for k = math.max(1, first - 1), last do
			local d = HudLayout.trailDot(k, length)
			local x, y, z = project(d)
			if x and y and z then
				local passed = progress - d
				local a = if passed > 0 then math.max(0, 1 - passed / G.trailFade) else 1
				if a > 0 then
					table.insert(dots, {
						x = x,
						y = y,
						alpha = a * glow,
						size = math.clamp(G.trailNear / z, 0.45, 1),
					})
				end
			end
		end
		while #dots > G.trailMax do
			table.remove(dots, 1)
		end
		local flow: { GuideParts.Chevron } = {}
		if first <= last then
			local offset = (t * G.chevronRate) % G.chevronEvery
			local k = first - 1 + offset
			while k <= last and #flow < math.ceil(G.trailMax / G.chevronEvery) + 1 do
				local d = math.min(k * G.trailSpacing, length)
				if d > progress then
					local x, y = project(d)
					local x2, y2 = project(math.min(d + 1, length + 1))
					if x and y and x2 and y2 then
						table.insert(
							flow,
							{ x = x, y = y, angle = math.atan2(y2 - y, x2 - x), alpha = glow }
						)
					end
				end
				k += G.chevronEvery
			end
		end
		b.trail.set(dots, flow)
	end
	b.trail.fade(ft.alpha)

	-- G7 bubble (G8 inside), G2 when it cannot sit by its target, G9 on it.
	local fb = fade("bubble")
	fb.want = bubble.key ~= nil
	approach(fb, dt)
	local bubbleRect: Rect? = nil
	local fcv = fade("curved")
	local curvedAt: { number }? = nil
	if bubble.key then
		local w, h = b.bubble.size(scale)
		local size = { width = math.max(w, 1), height = math.max(h, 1) }
		local at = resolve(bubble.target)
		local targetRect = if at and at.onScreen and not at.creature then at.rect else nil
		local more = table.clone(avoid)
		if pointerRect then
			table.insert(more, pointerRect)
		end
		local place: HudLayout.BubblePlace
		if bubble.slot and targetRect then
			local slot = HudLayout.momentSlot(content, size)
			place = { rect = slot, side = "slot", tailX = 0, tailY = 0, curved = true }
		else
			place = HudLayout.guideBubble(size, targetRect, content, more)
		end
		b.bubble.set(place.rect, place.side, place.tailX, place.tailY)
		bubbleRect = place.rect
		if place.curved and targetRect then
			local cx, cy, ca = HudLayout.guideCurved(place.rect, targetRect, content)
			curvedAt = { cx, cy, ca }
		end
	end
	b.bubble.fade(fb.alpha)
	fcv.want = curvedAt ~= nil
	approach(fcv, dt)
	if curvedAt then
		b.curved.set(curvedAt[1], curvedAt[2], curvedAt[3])
	end
	b.curved.fade(fcv.alpha * glow)

	local tk = tickState
	local fk = fade("tick")
	fk.want = tk ~= nil
	approach(fk, dt)
	if tk then
		local u = math.clamp((t - tk.started) / G.tickTime, 0, 1)
		local on = bubbleRect
			or HudLayout.momentSlot(content, { width = G.tick * 2, height = G.tick })
		b.tick.set(HudLayout.guideTick(on), u)
		if u >= 1 and not tk.stay then
			tickState = nil
			Guide.clear()
		end
	end
	b.tick.fade(fk.alpha)
end

-- Public API --------------------------------------------------------------------------------------

export type MountOptions = {
	inputMode: (() -> InputMode)?,
	modeChanged: Types.Signal<InputMode>?,
}

--- Builds the `GulpGuide` layer and starts the frame loop. Needs `Screen.start()` first. Later
--- calls only update the options.
function Guide.mount(options: MountOptions?)
	local o: MountOptions = options or {}
	local current = o.inputMode
	if current then
		mode = current()
	elseif not built then
		mode = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
			then "Touch"
			else "Keys"
	end
	if o.modeChanged then
		(o.modeChanged :: Types.Signal<InputMode>):connect(function(m: InputMode)
			Guide.setInputMode(m)
		end)
	end
	if built then
		refreshText()
		return
	end
	local player = Players.LocalPlayer
	playerGui = player:FindFirstChildOfClass("PlayerGui")
		-- safe: the PlayerGui child of a Player is always a PlayerGui
		or player:WaitForChild("PlayerGui") :: PlayerGui
	build()
	refreshText()
	local function seen()
		lastInput = now()
	end
	UserInputService.InputBegan:Connect(seen)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		local k = input.UserInputType
		if
			k == Enum.UserInputType.MouseMovement
			or k == Enum.UserInputType.Touch
			or k == Enum.UserInputType.Gamepad1
		then
			seen()
		end
	end)
	local last = now()
	-- After the camera, so world targets are projected with this frame's camera.
	RunService:BindToRenderStep("GulpGuide", Enum.RenderPriority.Camera.Value + 2, function()
		local t = now()
		local dt = math.min(0.1, t - last)
		last = t
		step(dt)
	end)
end

function Guide.isMounted(): boolean
	return built ~= nil
end

--- G1: the arrow at `target`; nil hides it. Replaces the hand and the ghost thumb (one pointer).
function Guide.arrow(target: Target?)
	ghostState = nil
	pointer.kind = if target then "arrow" else nil
	pointer.target = target
	pointer.started = now()
	pointer.bounceAt = -1
end

export type HandOptions = { hold: number?, from: Target? }

--- G3: the hand doing `gesture` (default "tap") at `target`; nil hides it. Replaces the arrow
--- and the ghost thumb. `opts.hold` is the hold length in seconds; `opts.from` where a drag starts.
function Guide.hand(target: Target?, gesture: Gesture?, opts: HandOptions?)
	ghostState = nil
	pointer.kind = if target then "hand" else nil
	pointer.target = target
	pointer.gesture = gesture or "tap"
	pointer.hold = if opts and opts.hold then opts.hold else 1
	pointer.from = if opts then opts.from else nil
	pointer.started = now()
	pointer.bounceAt = -1
end

--- G4: the trail from where the creature is now to `position`; nil clears it.
function Guide.trail(position: Vector3?)
	if position == nil then
		trailState = nil
		return
	end
	local from = creaturePosition()
	trailState = { origin = from or position, target = position }
end

--- G5: the highlight ring round `target`; nil hides it.
function Guide.ring(target: Target?)
	ringTarget = target
end

--- G6: the cut-out scrim with its hole round `target`; nil hides it. Only for safe water.
function Guide.cutout(target: Target?)
	cutoutTarget = target
end

export type BubbleOptions = { args: { [any]: any }?, hint: Action?, slot: boolean? }

--- G7: the bubble with `textKey` (a `guide.*` key, or one per input mode) by `target` (nil or
--- the creature: the moment slot); nil textKey hides it. `opts.hint` puts the G8 picture in it.
function Guide.bubble(textKey: TextKey?, target: Target?, opts: BubbleOptions?)
	bubble.key = textKey
	bubble.target = target
	bubble.args = if opts then opts.args else nil
	bubble.hint = if opts then opts.hint else nil
	bubble.slot = opts ~= nil and opts.slot == true
	refreshText()
end

--- G8: the picture in the bubble for `action`; nil removes it.
function Guide.hint(action: Action?)
	bubble.hint = action
	refreshText()
end

--- G9: the step tick pops on the bubble. With `stay` it stays after the pop (until clear()).
function Guide.tick(stay: boolean?)
	tickState = { started = now(), stay = stay == true }
	-- TODO(B32 AudioController): `SFX_UI_GuideStep` plays here (08 §7, G9).
end

--- 08 §7: one step: a pointer, a bubble, and optionally the ring and the cut-out, at `target`.
function Guide.point(target: Target, opts: PointOptions?)
	local o: PointOptions = opts or {}
	local p = o.pointer
	if p == "arrow" then
		Guide.arrow(target)
	elseif p == "tap" or p == "hold" or p == "drag" then
		Guide.hand(target, p, { hold = o.hold, from = o.from })
	else
		Guide.arrow(nil)
	end
	Guide.ring(if o.ring then target else nil)
	Guide.cutout(if o.cutout then target else nil)
	Guide.bubble(o.textKey, target, { args = o.args, hint = o.hint, slot = o.slot })
	lastInput = now()
end

--- 08 §7: the step is done: the tick pops on the bubble for 400 ms, then the step clears.
function Guide.done()
	Guide.tick(false)
end

--- Clears the step: pointer, ghost thumb, bubble, ring, cut-out and trail (not the home marker,
--- the dash pulse or the danger edge, which chapter 04 turns off itself).
function Guide.clear()
	Guide.arrow(nil)
	ghostState = nil
	ringTarget = nil
	cutoutTarget = nil
	trailState = nil
	bubble.key = nil
	bubble.target = nil
	bubble.hint = nil
	if tickState and tickState.stay then
		tickState = nil
	end
end

export type GhostOptions = { long: boolean? }

--- 04 §3.2: the ghost thumb toward `target` (the longer drag with `opts.long`); nil hides it.
--- Replaces the arrow and the hand.
function Guide.ghost(target: Target?, opts: GhostOptions?)
	if target == nil then
		ghostState = nil
		return
	end
	pointer.kind = nil
	pointer.target = nil
	ghostState = { target = target, long = opts ~= nil and opts.long == true, started = now() }
	lastInput = now()
end

--- 04 §3.2 and §3.3: the ring and HOME on the home marker (shown while `HUD.Home` is).
function Guide.home(on: boolean)
	homeOn = on
end

--- 04 §3.2 and §3.3: the dash pulse and DASH! on `HUD.Dash`.
function Guide.dashPulse(on: boolean)
	dashOn = on
end

--- 04 §3.2: the red edge glow on the side of the predator at `position`; nil fades it out.
function Guide.danger(position: Vector3?)
	dangerAt = position
end

--- The input in use. Pictures and texts swap at once (G8: within 200 ms).
function Guide.setInputMode(m: InputMode)
	if m == mode then
		return
	end
	mode = m
	refreshText()
end

function Guide.inputMode(): InputMode
	return mode
end

--- 08 §7 and §6.7: with Less motion on, bobbing and pulsing become a 0.5 Hz fade.
function Guide.setLessMotion(on: boolean)
	lessMotion = on
end

--- 08 §7: hides every prompt while an unrelated menu is open, and brings them back after.
function Guide.setSuppressed(on: boolean)
	suppressed = on
end

--- Where the creature is, for the trail and the CREATURE target (default: the local character).
function Guide.setCreature(fn: (() -> Vector3?)?)
	creatureOf = fn
end

--- Clears everything, chapter 04's prompts too.
function Guide.reset()
	Guide.clear()
	tickState = nil
	homeOn = false
	dashOn = false
	dangerAt = nil
end

return Guide
