--!strict
-- Kit/GuideParts: the drawn parts of the guide kit (docs/08 section 7, G1 to G9, and chapter
-- 04's prompts built from them, 04 §3.2). Each part is built once on the guide canvas and is
-- told each frame where to be (content-box rpx) and how far it is through its loop; Kit/Guide
-- decides what shows, where (Shared.Logic.HudLayout) and when. Every part carries the empty slot
-- of its 08 §13 image, so the art swaps in without layout changes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)

local Draw = require("./Draw")
local GuideHints = require("./GuideHints")
local Screen = require("./Screen")
local Theme = require("./Theme")

local G = HudLayout.GUIDE

local GuideParts = {}

type Rect = HudLayout.Rect

-- Fading ----------------------------------------------------------------------------------------

type Entry = { object: Instance, property: string, base: number }

--- Fades everything under `root` together: `set(alpha)` scales every transparency the part was
--- drawn with (0 hides it, 1 is as drawn). Images set later (the real art) are picked up on the
--- next call. `extra` (0 to 1) fades a part further, for the Less motion pulse.
function GuideParts.fader(root: GuiObject): (alpha: number) -> ()
	local entries: { Entry } = {}
	local dirty = true
	root.DescendantAdded:Connect(function()
		dirty = true
	end)
	root.DescendantRemoving:Connect(function()
		dirty = true
	end)
	local function collect()
		table.clear(entries)
		local function add(object: Instance, property: string, value: number)
			table.insert(entries, { object = object, property = property, base = value })
		end
		for _, d in root:GetDescendants() do
			if d:IsA("ImageLabel") or d:IsA("ImageButton") then
				if (d :: ImageLabel).Image ~= "" then
					add(d, "ImageTransparency", (d :: ImageLabel).ImageTransparency)
				end
			elseif d:IsA("TextLabel") then
				add(d, "TextTransparency", (d :: TextLabel).TextTransparency)
			elseif d:IsA("Frame") then
				if (d :: Frame).BackgroundTransparency < 1 then
					add(d, "BackgroundTransparency", (d :: Frame).BackgroundTransparency)
				end
			elseif d:IsA("UIStroke") then
				add(d, "Transparency", (d :: UIStroke).Transparency)
			end
		end
		dirty = false
	end
	local last = -1
	return function(alpha: number)
		local a = math.clamp(alpha, 0, 1)
		if dirty then
			-- Restore before re-reading, so a half-faded value is never taken as the drawn one.
			for _, e in entries do
				(e.object :: any)[e.property] = e.base
			end
			collect()
			last = -1
		end
		if a == last then
			return
		end
		last = a
		root.Visible = a > 0.001
		for _, e in entries do
			(e.object :: any)[e.property] = 1 - (1 - e.base) * a
		end
	end
end

local function place(object: GuiObject, x: number, y: number)
	object.Position = UDim2.fromOffset(x, y)
end

local function holder(parent: Instance, name: string, size: number, z: number): Frame
	return Draw.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		Visible = false,
		ZIndex = z,
		Parent = parent,
	}) :: Frame
end

-- G1 arrow ----------------------------------------------------------------------------------------

export type Arrow = {
	root: Frame,
	fade: (alpha: number) -> (),
	-- Centre (x, y), the angle it points along, and how far it has bobbed toward its tip.
	set: (x: number, y: number, angle: number, bob: number, scale: number) -> (),
}

--- G1 `UI_Guide_Arrow`: a sun-yellow arrow, 96 rpx, drawn pointing right and turned to `angle`.
function GuideParts.arrow(parent: Instance, z: number): Arrow
	local root = holder(parent, "UI_Guide_Arrow", G.arrow, z)
	local scale = Draw.new("UIScale", { Parent = root }) :: UIScale
	local s = G.arrow
	Draw.new("Frame", {
		Name = "Shaft",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, s * 0.06, 0.5, 0),
		Size = UDim2.fromOffset(s * 0.56, s * 0.3),
		BackgroundColor3 = Theme.PRIMARY,
		BackgroundTransparency = 0,
		ZIndex = z,
		Parent = root,
	}, { Draw.corner(s * 0.08), Draw.stroke(Theme.STROKE_PANEL) })
	GuideHints.triangle(
		root,
		s * 0.44,
		Theme.PRIMARY,
		UDim2.new(0, s * 0.72, 0.5, 0),
		z + 1,
		Theme.STROKE_PANEL
	)
	-- One white highlight along the shaft (06 §12.4).
	Draw.new("Frame", {
		Name = "Shine",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, s * 0.12, 0.5, -s * 0.06),
		Size = UDim2.fromOffset(s * 0.36, s * 0.06),
		BackgroundColor3 = Theme.WHITE,
		BackgroundTransparency = 0.35,
		ZIndex = z + 2,
		Parent = root,
	}, { Draw.corner() })
	Draw.slot("UI_Guide_Arrow", root, z + 3)
	return {
		root = root,
		fade = GuideParts.fader(root),
		set = function(x: number, y: number, angle: number, bob: number, k: number)
			place(root, x + math.cos(angle) * bob, y + math.sin(angle) * bob)
			root.Rotation = math.deg(angle)
			scale.Scale = k
		end,
	}
end

-- G2 curved arrow -------------------------------------------------------------------------------

export type Curved = {
	root: Frame,
	fade: (alpha: number) -> (),
	set: (x: number, y: number, angle: number) -> (),
}

--- G2 `UI_Guide_ArrowCurved`: a dotted arc ending in a head, 128 rpx, turned to `angle`.
function GuideParts.curved(parent: Instance, z: number): Curved
	local root = holder(parent, "UI_Guide_ArrowCurved", G.curved, z)
	local s = G.curved
	-- Five dots on an arc bowing up, growing toward the head.
	for i = 0, 4 do
		local t = i / 5
		local x = s * (0.08 + 0.7 * t)
		local y = s * (0.5 - 0.22 * math.sin(t * math.pi))
		local d = Draw.disc(
			s * (0.08 + 0.03 * i),
			Theme.PRIMARY,
			UDim2.fromOffset(x, y),
			{ ZIndex = z, Parent = root }
		)
		Draw.stroke(Theme.STROKE_CHIP).Parent = d
	end
	local head = Draw.new("Frame", {
		Position = UDim2.fromOffset(s * 0.86, s * 0.5),
		Size = UDim2.fromOffset(0, 0),
		Rotation = 18,
		ZIndex = z + 1,
		Parent = root,
	})
	GuideHints.triangle(
		head,
		s * 0.16,
		Theme.PRIMARY,
		UDim2.fromOffset(0, 0),
		z + 1,
		Theme.STROKE_PANEL
	)
	Draw.slot("UI_Guide_ArrowCurved", root, z + 3)
	return {
		root = root,
		fade = GuideParts.fader(root),
		set = function(x: number, y: number, angle: number)
			place(root, x, y)
			root.Rotation = math.deg(angle)
		end,
	}
end

-- G3 hand ----------------------------------------------------------------------------------------

export type Gesture = "tap" | "hold" | "drag"
export type Hand = {
	root: Frame,
	fade: (alpha: number) -> (),
	-- Fingertip at (x, y); `down` presses it; `hold` (0 to 1) fills the ring; `trail` is the
	-- drag's recent path, newest last.
	set: (x: number, y: number, down: boolean, hold: number?, trail: { Vector2 }?) -> (),
}

local TRAIL_DOTS = 8

--- G3 `UI_Guide_Hand` with its up and down states, the hold ring and the drag trail.
function GuideParts.hand(parent: Instance, z: number): Hand
	local root = Draw.new("Frame", {
		Name = "G3.Hand",
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = z,
		Parent = parent,
	}) :: Frame
	local trail: { Frame } = {}
	for i = 1, TRAIL_DOTS do
		trail[i] = Draw.disc(14 + i, Theme.WHITE, nil, {
			Name = "Trail",
			BackgroundTransparency = 0.3,
			ZIndex = z,
			Visible = false,
			Parent = root,
		})
	end
	local ring = Draw.new("Frame", {
		Name = "HoldRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(G.holdRing, G.holdRing),
		ZIndex = z + 1,
		Parent = root,
	}) :: Frame
	local ringBack = Draw.disc(
		G.holdRing,
		Theme.INK,
		nil,
		{ BackgroundTransparency = 0.7, ZIndex = z + 1, Parent = ring }
	)
	local fill = Draw.wedge(ring, G.holdRing, Theme.PRIMARY, 0.15, z + 2)
	local ripple = Draw.disc(
		G.holdRing * 0.6,
		Theme.WHITE,
		nil,
		{ Name = "Press", BackgroundTransparency = 0.45, ZIndex = z + 1, Parent = root }
	)
	Draw.stroke(Theme.STROKE_CHIP, Theme.WHITE).Parent = ripple
	local hand = GuideHints.hand(root, G.hand, z + 3)
	local handScale = Draw.new("UIScale", { Parent = hand }) :: UIScale
	return {
		root = root,
		fade = GuideParts.fader(root),
		set = function(x: number, y: number, down: boolean, hold: number?, path: { Vector2 }?)
			-- The down sprite: pressed in and 4 rpx lower.
			place(hand, x, y + (if down then 4 else 0))
			handScale.Scale = if down then 0.9 else 1
			place(ripple, x, y)
			ripple.Visible = down and hold == nil
			ring.Visible = hold ~= nil
			ringBack.Visible = hold ~= nil
			if hold then
				place(ring, x, y)
				fill(hold)
			end
			local p = path or {}
			for i, dot in trail do
				local point = p[#p - TRAIL_DOTS + i]
				dot.Visible = point ~= nil
				if point then
					place(dot, point.X, point.Y)
					dot.BackgroundTransparency = 1 - 0.7 * (i / TRAIL_DOTS)
				end
			end
		end,
	}
end

-- G4 trail ---------------------------------------------------------------------------------------

export type TrailPoint = { x: number, y: number, alpha: number, size: number }
export type Chevron = { x: number, y: number, angle: number, alpha: number }
export type Trail = {
	root: Frame,
	fade: (alpha: number) -> (),
	set: (dots: { TrailPoint }, chevrons: { Chevron }) -> (),
}

--- G4 `UI_Guide_TrailDot` (48) and `UI_Guide_TrailChevron` (64): up to 12 glowing dots and the
--- chevrons flowing along them, placed each frame from their world points.
function GuideParts.trail(parent: Instance, z: number): Trail
	local root = Draw.new("Frame", {
		Name = "G4.Trail",
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = z,
		Parent = parent,
	}) :: Frame
	local dots: { { root: Frame, scale: UIScale, glow: Frame, core: Frame } } = {}
	for i = 1, G.trailMax do
		local d = holder(root, "UI_Guide_TrailDot", G.trailDot, z)
		local glow = Draw.disc(
			G.trailDot,
			Theme.PRIMARY,
			nil,
			{ Name = "Glow", BackgroundTransparency = 0.55, ZIndex = z, Parent = d }
		)
		local core = Draw.disc(
			G.trailDot * 0.46,
			Theme.WHITE,
			nil,
			{ Name = "Core", ZIndex = z + 1, Parent = d }
		)
		Draw.stroke(Theme.STROKE_CHIP, Theme.PRIMARY_SHADE).Parent = core
		Draw.slot("UI_Guide_TrailDot", d, z + 2)
		dots[i] =
			{ root = d, scale = Draw.new("UIScale", { Parent = d }), glow = glow, core = core }
	end
	local chevrons: { Frame } = {}
	for i = 1, math.ceil(G.trailMax / G.chevronEvery) + 1 do
		local c = holder(root, "UI_Guide_TrailChevron", G.trailChevron, z + 3)
		GuideHints.triangle(
			c,
			G.trailChevron * 0.3,
			Theme.WHITE,
			UDim2.fromScale(0.5, 0.5),
			z + 3,
			Theme.STROKE_CHIP
		)
		Draw.slot("UI_Guide_TrailChevron", c, z + 4)
		chevrons[i] = c
	end
	local fades: { [Frame]: (number) -> () } = {}
	local function fadeOf(f: Frame): (number) -> ()
		local fn = fades[f]
		if not fn then
			fn = GuideParts.fader(f)
			fades[f] = fn
		end
		return fn
	end
	local part = {
		root = root,
		fade = function(alpha: number)
			root.Visible = alpha > 0.001
			root:SetAttribute("Alpha", alpha)
		end,
		set = function(points: { TrailPoint }, flow: { Chevron })
			local whole = root:GetAttribute("Alpha")
			local a = if type(whole) == "number" then whole else 1
			for i, d in dots do
				local p = points[i]
				if p then
					place(d.root, p.x, p.y)
					d.scale.Scale = p.size
				end
				fadeOf(d.root)(if p then p.alpha * a else 0)
			end
			for i, c in chevrons do
				local f = flow[i]
				if f then
					place(c, f.x, f.y)
					c.Rotation = math.deg(f.angle)
				end
				fadeOf(c)(if f then f.alpha * a else 0)
			end
		end,
	}
	return part
end

-- G5 ring ----------------------------------------------------------------------------------------

export type Ring = {
	root: Frame,
	fade: (alpha: number) -> (),
	set: (rect: Rect, scale: number) -> (),
}

--- G5 `UI_Guide_Ring` (9-slice): a sun-yellow ring with a navy edge round its rect; `colour`
--- white and `slotName` `UI_Common_RingPulse` for the dash pulse.
function GuideParts.ring(
	parent: Instance,
	z: number,
	name: string?,
	colour: Color3?,
	slotName: string?
): Ring
	local root = Draw.new("Frame", {
		Name = name or "UI_Guide_Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = z,
		Parent = parent,
	}) :: Frame
	local scale = Draw.new("UIScale", { Parent = root }) :: UIScale
	local corner = Draw.corner() :: UICorner
	corner.Parent = root
	Draw.new("Frame", {
		Name = "Edge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 12, 1, 12),
		ZIndex = z,
		Parent = root,
	}, { Draw.corner(), Draw.stroke(Theme.STROKE_CHIP) })
	local band = Draw.stroke(6, colour or Theme.PRIMARY)
	band.Parent = root
	Draw.new("Frame", {
		Name = "Inner",
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Parent = root,
	}, { Draw.corner(), Draw.stroke(Theme.STROKE_CHIP) })
	local slot = Draw.slot(slotName or "UI_Guide_Ring", root, z + 1)
	slot.ScaleType = Enum.ScaleType.Slice
	slot.SliceCenter = Rect.new(48, 48, 144, 144) -- the 96 rpx source at 2x (08 §1.2)
	return {
		root = root,
		fade = GuideParts.fader(root),
		set = function(rect: Rect, k: number)
			place(root, rect.x + rect.width / 2, rect.y + rect.height / 2)
			root.Size = UDim2.fromOffset(rect.width, rect.height)
			scale.Scale = k
		end,
	}
end

-- G6 cut-out ---------------------------------------------------------------------------------

export type Cutout = {
	root: Frame,
	fade: (alpha: number) -> (),
	set: (hole: Rect) -> (),
	-- Called with true while it shows: taps outside the hole are caught.
	block: (on: boolean) -> (),
}

-- The dim reaches past the screen's edges from anywhere on it (rpx; any screen is smaller).
local FAR = 4000

--- G6 `UI_Guide_Cutout`: dims the screen by 50% outside a rounded hole. The dim is the hole's own
--- stroke, so the corners stay round; four clear buttons outside the hole catch every tap that
--- would miss the target.
function GuideParts.cutout(parent: Instance, z: number): Cutout
	local root = Draw.new("Frame", {
		Name = "G6.Cutout",
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = z,
		Parent = parent,
	}) :: Frame
	local hole = Draw.new("Frame", {
		Name = "Hole",
		ZIndex = z,
		Parent = root,
	}, { Draw.corner(G.cutoutRadius) }) :: Frame
	Draw.new("UIStroke", {
		Thickness = FAR,
		Color = Theme.DIM,
		Transparency = G.cutoutDim,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = hole,
	})
	local slot = Draw.slot("UI_Guide_Cutout", hole, z + 1)
	slot.ScaleType = Enum.ScaleType.Slice
	slot.SliceCenter = Rect.new(48, 48, 144, 144)
	local blockers: { TextButton } = {}
	for i = 1, 4 do
		blockers[i] = Draw.new("TextButton", {
			Name = "Block",
			Text = "",
			AutoButtonColor = false,
			Active = true,
			Visible = false,
			ZIndex = z,
			Parent = root,
		}) :: TextButton
	end
	local blocking = false
	local last: Rect? = nil
	local function layoutBlockers(r: Rect)
		local spots = {
			{ r.x - FAR, r.y - FAR, 2 * FAR + r.width, FAR }, -- above
			{ r.x - FAR, r.y + r.height, 2 * FAR + r.width, FAR }, -- below
			{ r.x - FAR, r.y, FAR, r.height }, -- left
			{ r.x + r.width, r.y, FAR, r.height }, -- right
		}
		for i, b in blockers do
			local s = spots[i]
			b.Position = UDim2.fromOffset(s[1], s[2])
			b.Size = UDim2.fromOffset(s[3], s[4])
			b.Visible = blocking
		end
	end
	return {
		root = root,
		fade = GuideParts.fader(root),
		set = function(r: Rect)
			place(hole, r.x, r.y)
			hole.Size = UDim2.fromOffset(r.width, r.height)
			last = r
			layoutBlockers(r)
		end,
		block = function(on: boolean)
			blocking = on
			for _, b in blockers do
				b.Visible = on and last ~= nil
			end
		end,
	}
end

-- G7 bubble (with G8 inside) ------------------------------------------------------------------

export type Bubble = {
	root: Frame,
	fade: (alpha: number) -> (),
	setText: (text: string) -> (),
	-- The G8 picture's holder at the bubble's left end; `setHint(nil)` empties it.
	hintHolder: Frame,
	setHint: (picture: GuideHints.Picture?) -> (),
	-- The bubble's size in rpx at the last layout (0 until it has been drawn).
	size: (scale: number) -> (number, number),
	set: (rect: Rect, side: HudLayout.BubbleSide, tailX: number, tailY: number) -> (),
}

--- G7 `UI_Guide_Bubble` (9-slice) and its tail `UI_Common_BubbleTail`: a cream panel up to 420
--- wide holding the G8 picture and at most two lines of Body 24 (Nunito ExtraBold), wrapping at
--- 420 and shrinking to 22 when a translation still does not fit (08 §1.5).
function GuideParts.bubble(parent: Instance, z: number): Bubble
	local root = Draw.new("Frame", {
		Name = "G7.Bubble",
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = z,
		Parent = parent,
	}) :: Frame
	local panel = Draw.new("Frame", {
		Name = "UI_Guide_Bubble",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Theme.PANEL,
		BackgroundTransparency = 0,
		ZIndex = z + 1,
		Parent = root,
	}, {
		Draw.corner(Theme.PANEL_RADIUS),
		Draw.stroke(Theme.STROKE_PANEL),
		Draw.new("UIPadding", {
			PaddingLeft = UDim.new(0, G.bubblePad),
			PaddingRight = UDim.new(0, G.bubblePad),
			PaddingTop = UDim.new(0, G.bubblePad / 2),
			PaddingBottom = UDim.new(0, G.bubblePad / 2),
		}),
		Draw.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, G.hintGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Draw.new("UISizeConstraint", { MinSize = Vector2.new(0, G.hint + G.bubblePad) }),
	}) :: Frame
	local shadow = Draw.new("Frame", {
		Name = "Shadow",
		BackgroundColor3 = Theme.DIM,
		BackgroundTransparency = Theme.SHADOW_TRANSPARENCY,
		ZIndex = z,
		Parent = root,
	}, { Draw.corner(Theme.PANEL_RADIUS) }) :: Frame
	local hintHolder = Draw.new("Frame", {
		Name = "Hint",
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, G.hint),
		Visible = false,
		ZIndex = z + 2,
		Parent = panel,
	}) :: Frame
	local textMax = G.bubbleMaxWidth - 2 * G.bubblePad
	local label = Draw.text({
		Name = "Text",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.INK,
		ZIndex = z + 2,
		Parent = panel,
	}, G.bubbleText, "body")
	label.TextWrapped = true
	local limit = Draw.new(
		"UISizeConstraint",
		{ MaxSize = Vector2.new(textMax, 2000), Parent = label }
	) :: UISizeConstraint
	Draw.slot("UI_Guide_Bubble", panel, z + 1).ScaleType = Enum.ScaleType.Slice
	-- The tail: a square turned 45 degrees under the panel, so only its lower point shows.
	local tail = Draw.new("Frame", {
		Name = "Tail",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(G.tailWidth * 0.72, G.tailWidth * 0.72),
		Rotation = 45,
		BackgroundColor3 = Theme.PANEL,
		BackgroundTransparency = 0,
		ZIndex = z,
		Parent = root,
	}, { Draw.corner(3), Draw.stroke(Theme.STROKE_PANEL) }) :: Frame
	Draw.slot("UI_Common_BubbleTail", tail, z)
	local hasHint = false
	local function relimit()
		limit.MaxSize = Vector2.new(textMax - (if hasHint then G.hint + G.hintGap else 0), 2000)
	end
	return {
		root = root,
		fade = GuideParts.fader(root),
		hintHolder = hintHolder,
		setText = function(text: string)
			label:SetAttribute(Screen.TEXT_RPX, G.bubbleText)
			label.TextSize = Screen.textSize(G.bubbleText)
			label.Text = text
		end,
		setHint = function(picture: GuideHints.Picture?)
			for _, c in hintHolder:GetChildren() do
				if c:IsA("GuiObject") and (picture == nil or c ~= picture.root) then
					c:Destroy()
				end
			end
			hasHint = picture ~= nil
			hintHolder.Visible = hasHint
			if picture then
				picture.root.Parent = hintHolder
				picture.root.Position = UDim2.fromOffset(0, 0)
			end
			relimit()
		end,
		size = function(scale: number): (number, number)
			local s = panel.AbsoluteSize
			-- 08 §1.5: past two lines, the text drops to 22 before it wraps further.
			local lines = label.TextBounds.Y / math.max(1e-3, label.TextSize)
			local rpx = label:GetAttribute(Screen.TEXT_RPX)
			if lines > G.bubbleLines + 0.5 and rpx == G.bubbleText then
				label:SetAttribute(Screen.TEXT_RPX, HudLayout.TEXT_FLOOR)
				label.TextSize = Screen.textSize(HudLayout.TEXT_FLOOR)
			end
			return s.X / scale, s.Y / scale
		end,
		set = function(rect: Rect, side: HudLayout.BubbleSide, tailX: number, tailY: number)
			place(panel, rect.x, rect.y)
			place(shadow, rect.x, rect.y + Theme.SHADOW_OFFSET)
			shadow.Size = UDim2.fromOffset(rect.width, rect.height)
			tail.Visible = side ~= "slot"
			local inset = G.tailHeight * 0.25
			if side == "above" then
				place(tail, tailX, tailY - inset)
			elseif side == "below" then
				place(tail, tailX, tailY + inset)
			elseif side == "left" then
				place(tail, tailX - inset, tailY)
			else
				place(tail, tailX + inset, tailY)
			end
		end,
	}
end

-- G9 step tick -------------------------------------------------------------------------------

export type Tick = { root: Frame, fade: (alpha: number) -> (), set: (rect: Rect, t: number) -> () }

--- G9 `UI_Common_Check`: an aqua disc with a white tick that pops (0 to 1.25 to 1) over 400 ms.
function GuideParts.tick(parent: Instance, z: number): Tick
	local root = holder(parent, "UI_Common_Check", G.tick, z)
	local scale = Draw.new("UIScale", { Parent = root }) :: UIScale
	local disc = Draw.disc(G.tick, Theme.SECONDARY, nil, { ZIndex = z, Parent = root })
	Draw.stroke(Theme.STROKE_ICON).Parent = disc
	local s = G.tick
	for _, b in { { 0.4, 0.58, 0.3, 45 }, { 0.6, 0.48, 0.5, -50 } } do
		Draw.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(b[1], b[2]),
			Size = UDim2.fromOffset(s * b[3], s * 0.13),
			Rotation = b[4],
			BackgroundColor3 = Theme.WHITE,
			BackgroundTransparency = 0,
			ZIndex = z + 1,
			Parent = disc,
		}, { Draw.corner(), Draw.stroke(Theme.STROKE_CHIP) })
	end
	Draw.slot("UI_Common_Check", root, z + 2)
	return {
		root = root,
		fade = GuideParts.fader(root),
		set = function(rect: Rect, t: number)
			place(root, rect.x + rect.width / 2, rect.y + rect.height / 2)
			-- Back-out pop: up to 1.25 in the first 40%, settling to 1.
			local k = if t < 0.4
				then 1.25 * math.sin(t / 0.4 * math.pi / 2)
				else 1 + 0.25 * (1 - (t - 0.4) / 0.6) ^ 2
			scale.Scale = math.max(0, k)
		end,
	}
end

-- Chapter 04 prompts -------------------------------------------------------------------------

export type Ghost = {
	root: Frame,
	fade: (alpha: number) -> (),
	-- Rebuilds the picture for `mode`.
	setMode: (mode: GuideHints.InputMode) -> (),
	-- The thumb (or key row) at (x, y); `press` 0 to 1 how far the press is in; `nudge` the
	-- direction the mouse or stick leans.
	set: (x: number, y: number, press: number, nudgeX: number, nudgeY: number) -> (),
}

--- 04 §3.2 ghost thumb: the thumbprint on touch, the mouse, W and arrow keys row with keys, the
--- left stick on a pad.
function GuideParts.ghost(parent: Instance, z: number): Ghost
	local root = Draw.new("Frame", {
		Name = "Guide.Ghost",
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = z,
		Parent = parent,
	}) :: Frame
	local item: Frame? = nil
	local face: Frame? = nil
	local nudger: Frame? = nil
	local scale: UIScale? = nil
	local mode: GuideHints.InputMode = "Touch"
	local function build(m: GuideHints.InputMode)
		if item then
			item:Destroy()
		end
		mode = m
		face, nudger = nil, nil
		if m == "Touch" then
			local t = GuideHints.thumbprint(root, G.ghost, z)
			item = t
		elseif m == "Keys" then
			local row = GuideHints.ghostRow(root, z)
			item, face, nudger = row.root, row.face, row.mouse
		else
			local pad = Draw.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(64, 64),
				ZIndex = z,
				Parent = root,
			}) :: Frame
			local _, cap = GuideHints.stick(pad, z)
			item, nudger = pad, cap
		end
		scale = Draw.new("UIScale", { Parent = item })
	end
	build("Touch")
	return {
		root = root,
		fade = GuideParts.fader(root),
		setMode = function(m: GuideHints.InputMode)
			if m ~= mode then
				build(m)
			end
		end,
		set = function(x: number, y: number, press: number, nx: number, ny: number)
			local it = item :: Frame
			place(it, x, y)
			local sc = scale :: UIScale
			sc.Scale = if mode == "Touch" then 1 - 0.12 * press else 1
			local f = face
			if f then
				f.Position = UDim2.fromOffset(0, 3 * press)
				f.BackgroundColor3 = Theme.PANEL:Lerp(Theme.PRIMARY, press)
			end
			local n = nudger
			if n then
				if mode == "Pad" then
					n.Position = UDim2.new(0.5, nx * 10, 0.5, ny * 10)
				else
					n.Position = UDim2.fromOffset(nx * 8, ny * 8)
				end
			end
		end,
	}
end

export type Tag = {
	root: Frame,
	fade: (alpha: number) -> (),
	chip: Frame,
	setText: (text: string) -> (),
	setHint: (picture: GuideHints.Picture?) -> (),
	size: (scale: number) -> (number, number),
	set: (rect: Rect) -> (),
}

--- A word on a chip (04 §3.3 HOME and DASH!): Fredoka on `colour` with a navy stroke, sized to
--- its text, `height` tall, with room for a G8 picture at its left.
function GuideParts.tag(
	parent: Instance,
	z: number,
	name: string,
	colour: Color3,
	height: number,
	textSize: number
): Tag
	local root = Draw.new(
		"Frame",
		{ Name = name, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = z, Parent = parent }
	) :: Frame
	local chip = Draw.new("Frame", {
		Name = "Chip",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, height),
		BackgroundColor3 = colour,
		BackgroundTransparency = 0,
		ZIndex = z,
		Parent = root,
	}, {
		Draw.corner(),
		Draw.stroke(Theme.STROKE_CHIP),
		Draw.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
		Draw.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, G.hintGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: Frame
	local hint = Draw.new("Frame", {
		Name = "Hint",
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, height),
		Visible = false,
		ZIndex = z + 1,
		Parent = chip,
	}) :: Frame
	local label = Draw.text({
		Name = "Text",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, height),
		TextColor3 = Theme.INK,
		ZIndex = z + 1,
		Parent = chip,
	}, textSize, "display")
	return {
		root = root,
		fade = GuideParts.fader(root),
		chip = chip,
		setText = function(text: string)
			label.Text = text
		end,
		setHint = function(picture: GuideHints.Picture?)
			for _, c in hint:GetChildren() do
				if c:IsA("GuiObject") and (picture == nil or c ~= picture.root) then
					c:Destroy()
				end
			end
			hint.Visible = picture ~= nil
			if picture then
				-- Scaled to the chip's height.
				local k = (height - 4) / 64
				Draw.new("UIScale", { Scale = k, Parent = picture.root })
				picture.root.Parent = hint
				picture.root.Position = UDim2.fromOffset(0, 2)
				hint.Size = UDim2.fromOffset(picture.width * k, height)
				hint.AutomaticSize = Enum.AutomaticSize.None
			end
		end,
		size = function(scale: number): (number, number)
			local s = chip.AbsoluteSize
			return s.X / scale, s.Y / scale
		end,
		set = function(rect: Rect)
			place(chip, rect.x, rect.y)
		end,
	}
end

export type Danger = {
	root: Frame,
	fade: (alpha: number) -> (),
	set: (rect: Rect, side: HudLayout.Side) -> (),
}

--- 04 §3.2 `UI_HUD_DangerEdge`: a red glow along one screen edge, 35% at the edge fading to
--- nothing inward.
function GuideParts.danger(parent: Instance, z: number): Danger
	local root = Draw.new("Frame", {
		Name = "Guide.DangerEdge",
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = z,
		Parent = parent,
	}) :: Frame
	local glow = Draw.new("Frame", {
		Name = "UI_HUD_DangerEdge",
		BackgroundColor3 = Theme.DANGER,
		BackgroundTransparency = 0,
		ZIndex = z,
		Parent = root,
	}) :: Frame
	local gradient = Draw.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1 - G.dangerOpacity),
			NumberSequenceKeypoint.new(0.45, 1 - G.dangerOpacity * 0.45),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = glow,
	}) :: UIGradient
	Draw.slot("UI_HUD_DangerEdge", glow, z + 1)
	local fade = GuideParts.fader(root)
	return {
		root = root,
		fade = fade,
		set = function(rect: Rect, side: HudLayout.Side)
			place(glow, rect.x, rect.y)
			glow.Size = UDim2.fromOffset(rect.width, rect.height)
			-- The gradient runs from the edge inward.
			gradient.Rotation = if side == "left"
				then 0
				elseif side == "right" then 180
				elseif side == "top" then 90
				else 270
		end,
	}
end

return table.freeze(GuideParts)
