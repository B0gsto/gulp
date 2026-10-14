--!strict
-- ReplicatedFirst.Boot.Loading: the loading screen S01 (docs/04, section 2; docs/08, section 8.1;
-- docs/09, sections 3 and 6.6).
--
-- It shows on the first frame and only then removes the default screen. ReplicatedFirst runs
-- before the rest of the place has arrived, so this file requires nothing: its numbers, colours
-- and shapes are local, and it touches ReplicatedStorage only after `game.Loaded`, to find the
-- minimum set's assets.
--
-- The screen (04 §2.2): flat lagoon teal with slow light rays, the GULP logo, the loading toy (a
-- flat Fry that follows the thumb and grows 3% for each white dot it eats, up to +60%) and a row
-- of five bubbles, one per 20% of phase D. No other text. Every shape is a stand-in drawn here
-- until the `UI_Load_*` art of 08 §13.11 exists.
--
-- Minimum set (04 §2.3): the collision shell (09 §6.6: `PersistentLoaded`), then the Minnow mesh
-- and krill, then the rest of the list below, preloaded with `ContentProvider:PreloadAsync`.
-- Slow load (04 §2.4), J = seconds since this script started (PlayerAdded is a moment earlier):
--   J 8   the set is not in, but the shell, the Minnow mesh and krill are: start (`partial`).
--   J 15  still not startable: the rest is never started; start on the essentials (`minimal`).
--   J 20  no profile yet (no `Slot` attribute): the bubble row dims to pale grey.
--   J 30  still here: a spinner and a weak-signal icon.
--   J 45  the profile failed: the server's rule (09 §12.4), nothing here.
--
-- Hand-over, through attributes on this script:
--   `LoadMode`  "full" | "partial" | "minimal", set once when the minimum set is ready (or the
--               slow-load rule starts anyway). Client.Main sends `ClientReady` on it; the server
--               spawns the creature and the tutorial leaves S0_LOADING (04 §3.1).
--   `LoadDone`  true when the screen starts its exit: the minimum set is ready and the creature
--               (so the profile) is here. The bubbles split for 0.4 s to show the egg; the
--               tutorial plays the hatch from here (S1_HATCH), and skips the hatch animation
--               when `LoadMode` is "minimal" (04 §2.4). The Fry's size is discarded.
--   `LoadMissing` the minimum-set names not found under ReplicatedStorage.Assets (art not in).
-- `MUS_Nursery`, when it exists, keeps playing after the exit as SoundService.LoadingMusic for
-- the audio code to take over (B1 of 04 §3.6: the base layer continues).
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local startedAt = os.clock()

-- First: `PersistentLoaded` has no "already fired" property, and this is the earliest script.
local shellLoaded = false
local shellConnection = workspace.PersistentLoaded:Once(function()
	shellLoaded = true
end)

-- Tunables. These belong in Shared.Config.FtueConfig (task S6-C7); they stay here because this
-- screen draws before ReplicatedStorage has arrived. 04 §2.2 and §2.4 own them; the toy's feel
-- values are 04 §2.2's (tune). Lengths are rpx: 1/720 of the shorter screen side.
local CONFIG = table.freeze({
	partialAt = 8, -- J s: start without the full set (04 §2.4)
	minimalAt = 15, -- J s: essentials only, no hatch animation (04 §2.4)
	dimAt = 20, -- J s: no profile yet, the bubble row dims (04 §2.4)
	slowAt = 30, -- J s: spinner and weak-signal icon (04 §2.4)
	shellTimeout = 10, -- s: a place with no collision shell still starts (09 §6.6)
	exitTime = 0.4, -- s: the screen splits into bubbles (04 §2.2)
	bubbles = 5, -- one per 20% of phase D (04 §2.2)
	growPerDot = 0.03, -- the Fry grows 3% a dot (04 §2.2)
	growMax = 0.6, -- up to +60% (04 §2.2)
	musicFadeIn = 1, -- s, `MUS_Nursery` base layer (04 §2.2)
	fryLength = 76, -- rpx (tune)
	fryFollow = 6, -- 1/s: the share of the gap to the thumb closed each second (tune)
	fryMaxSpeed = 900, -- rpx/s (tune)
	dotSize = 14, -- rpx (tune)
	dotSpeed = 150, -- rpx/s, right to left (tune)
	dotEvery = 0.5, -- s between dots (tune)
	dotWave = 16, -- rpx of up-and-down drift (tune)
	dotsMax = 12, -- the dot pool (tune)
	dotsAtStart = 9, -- dots already on screen at the first frame, so the middle is never empty
	dotLane = 0.65, -- share of dots that come in near the Fry's height
	dotLaneHalf = 0.11, -- share of the height: half the width of that lane
	splitBubbles = 26, -- bubbles in the exit (tune)
	-- The stand-in look (no bible value: presentation only, replaced by the `UI_Load_*` art).
	logoY = 0.22, -- share of the height: the logo's centre, in the top third (04 §2.2)
	logoWidth = 0.3, -- share of the width the drawn word spans (04 §2.2)
	logoTextSize = 100, -- the size the word is set at, then scaled to `logoWidth`
	logoStroke = 0.042, -- share of the logo box height: about 6% of the cap height
	logoShadow = 0.06, -- share of the logo box height: the drop shadow's offset down
	chompPop = 0.15, -- the Fry's scale pop on a bite, on top of its growth
	chompTime = 0.1, -- s, the pop
	squashTime = 0.18, -- s, the body's squash on a bite
	puffs = 9, -- the bite-puff pool (3 a bite)
	puffLife = 0.45, -- s
	tailWiggle = 16, -- degrees either way
	tailRate = 9, -- rad/s
	dotGlow = 1.75, -- the glow ring around a dot, as a multiple of its size (varied by 15%)
	ambient = 6, -- slow background bubbles (pool)
	ambientEvery = 2.6, -- s between them, on average
	ambientSpeed = 34, -- rpx/s rising, on average
	bubbleSize = 62, -- rpx, a progress bubble
	bubbleGap = 23, -- rpx between progress bubbles
	slowIcon = 92, -- rpx, the spinner's diameter (the slow sign's height inside its pill)
	slowGap = 32, -- rpx between the slow sign's pill and the bubble row
})

-- 04 §2.3's minimum set under chapter 07 names, found under ReplicatedStorage.Assets (09 §3.1).
-- ESSENTIAL is what 04 §2.4 may start on: the Minnow mesh and krill (the hatch point's floor is
-- the collision shell). Task S13-C2 owns the final list and its 25-asset, 4 MB budget.
local ESSENTIAL = { "M_Species_Minnow_Juv", "M_Prey_Krill" }
local REST = {
	"M_Prop_HatchEgg",
	"T_Minnow_Juv_Alb",
	"M_Species_Minnow_Juv_Shell", -- the green outline (09 §8.8)
	"M_Prey_Krill_Shell",
	"M_Prey_Plankton",
	"UI_Atlas_Glyphs1", -- the run HUD atlas (08 §13)
	"UI_Atlas_Content1",
	"SFX_Hatch",
	"SFX_Bite_Small",
	"SFX_TierUp_T2",
	"SFX_UI_TraitPip",
	"SFX_Dash_Small",
	"MUS_Nursery",
}

local hex = Color3.fromHex
local WATER = hex("#4CCFD2") -- 06 §4.2, Nursery Lagoon mid water: lagoon teal
local SURFACE = hex("#9FF0E6") -- 06 §4.2, Nursery Lagoon surface band
local DEEP = hex("#2FAFC0") -- 06 §4.2, Nursery Lagoon deep band
local WHITE = Color3.new(1, 1, 1)
local COLOUR = table.freeze({
	water = WATER,
	waterTop = WATER:Lerp(SURFACE, 0.2), -- the gentle top-to-bottom shade stays in the lagoon ramp
	waterBottom = WATER:Lerp(DEEP, 0.25),
	logoLow = WHITE:Lerp(SURFACE, 0.17), -- the wordmark's faint white-to-sea-glass gradient
	bubbleShade = WHITE:Lerp(SURFACE, 0.45), -- a full bubble's lower side
	ink = hex("#14213D"), -- 06 §4.6 navy (Kit/Theme.INK)
	white = Color3.new(1, 1, 1),
	dim = hex("#B8C4CC"), -- 06 §4.6 disabled grey: pale, never amber (04 §2.4)
	fryBody = hex("#FF9A3D"), -- 06 §5 `minnow` mid
	fryBelly = hex("#FFE2A8"), -- `minnow` light
	fryTail = hex("#FFD23D"), -- `minnow` accent, the yellow tail mark
})

local player = Players.LocalPlayer

-- Studio only, for screenshots (set in Edit before Play): `DevHold` keeps the screen up after the
-- creature arrives; `DevSkip` (seconds) moves J forward to show the slow-load states;
-- `DevNoProfile` treats the profile as never loaded (the J 20 dim); `DevProgress` (0 to 1) holds
-- the bubble row at that share. `DevAutopilot`, read each frame, steers the Fry to the nearest dot
-- and prints its scale on each bite.
local studio = RunService:IsStudio()
local function devNumber(name: string): number?
	local value = script:GetAttribute(name)
	return if studio and type(value) == "number" then value else nil
end
local devSkip = devNumber("DevSkip") or 0
local devProgress = devNumber("DevProgress")
local devNoProfile = studio and script:GetAttribute("DevNoProfile") == true

local function j(): number
	return os.clock() - startedAt + devSkip
end

-- Drawing ---------------------------------------------------------------------------------------

local function frame(name: string, parent: Instance, colour: Color3, transparency: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.BackgroundTransparency = transparency
	f.Parent = parent
	return f
end

local function round(object: GuiObject, radius: UDim?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0.5, 0)
	c.Parent = object
	return c
end

local function stroke(object: GuiObject, colour: Color3): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = object
	return s
end

local gui = Instance.new("ScreenGui")
gui.Name = "GulpLoading" -- the GulpSystem layer of 08 §1.6, its own ScreenGui: UIController is not up yet
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 100
gui.IgnoreGuiInset = true -- before ScreenInsets, which it can rewrite
gui.ScreenInsets = Enum.ScreenInsets.None

local function gradient(parent: Instance, rotation: number): UIGradient
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Parent = parent
	return g
end

-- The sea: lagoon teal, a touch lighter at the top (stand-in for `UI_Load_Background`).
local background = frame("Background", gui, COLOUR.white, 0)
background.Size = UDim2.fromScale(1, 1)
gradient(background, 90).Color = ColorSequence.new(COLOUR.waterTop, COLOUR.waterBottom)

-- Light rays: tall, soft, slowly swaying.
local rays: { Frame } = {}
for i, x in { 0.18, 0.42, 0.63, 0.86 } do
	local ray = frame("Ray", background, COLOUR.white, 0.86)
	ray.AnchorPoint = Vector2.new(0.5, 0)
	ray.Position = UDim2.fromScale(x, -0.25)
	ray.Size = UDim2.fromScale(0.05 + 0.03 * (i % 2), 1.5)
	ray.Rotation = 16
	gradient(ray, 90).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	rays[i] = ray
end

-- Slow background bubbles, rising from the floor (a pool, moved each frame).
type Drift = {
	disc: Frame,
	rim: UIStroke,
	x: number,
	y: number,
	speed: number,
	phase: number,
	alive: boolean,
}
local ambientLayer = frame("Ambient", background, COLOUR.white, 1)
ambientLayer.Size = UDim2.fromScale(1, 1)
local drifts: { Drift } = {}
for i = 1, CONFIG.ambient do
	local disc = frame("Drift", ambientLayer, COLOUR.white, 0.9)
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Visible = false
	round(disc)
	local rim = stroke(disc, COLOUR.white)
	rim.Transparency = 0.6
	drifts[i] = { disc = disc, rim = rim, x = 0, y = 0, speed = 0, phase = 0, alive = false }
end

-- The edge vignette: four soft navy fades, darker in the corners where they cross.
for _, edge in
	{
		{ size = UDim2.fromScale(1, 0.22), at = Vector2.new(0, 0), rotation = 90 },
		{ size = UDim2.fromScale(1, 0.22), at = Vector2.new(0, 1), rotation = -90 },
		{ size = UDim2.fromScale(0.16, 1), at = Vector2.new(0, 0), rotation = 0 },
		{ size = UDim2.fromScale(0.16, 1), at = Vector2.new(1, 0), rotation = 180 },
	}
do
	local shade = frame("Vignette", background, COLOUR.ink, 0)
	shade.AnchorPoint = edge.at
	shade.Position = UDim2.fromScale(edge.at.X, edge.at.Y)
	shade.Size = edge.size
	gradient(shade, edge.rotation).Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 1) })
end

-- Dots and bite puffs under the Fry.
local dotLayer = frame("Dots", background, COLOUR.white, 1)
dotLayer.Size = UDim2.fromScale(1, 1)

-- The logo: top third, the word spanning 30% of the screen width (stand-in for `UI_Load_Logo`):
-- white with a faint sea-glass fade, a thick navy outline and a soft navy shadow under it. The
-- word is set at a fixed size in a box its own size, then a UIScale stretches it to the width
-- (TextScaled stops at size 100, which left the word at about 17% of a laptop screen).
local function wordmark(
	name: string,
	colour: Color3,
	transparency: number
): (TextLabel, UIStroke, UIScale)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne) -- 06 §12.3 display face
	label.Text = "GULP" -- the wordmark, never translated (08 §13.11)
	label.TextColor3 = colour
	label.TextTransparency = transparency
	label.TextSize = CONFIG.logoTextSize
	label.ZIndex = 3
	label.Parent = background
	local outline = Instance.new("UIStroke")
	outline.Color = COLOUR.ink
	outline.Transparency = transparency
	outline.LineJoinMode = Enum.LineJoinMode.Round
	outline.Parent = label
	local scale = Instance.new("UIScale")
	scale.Parent = label
	return label, outline, scale
end
local logoShadow, logoShadowStroke, logoShadowScale = wordmark("LogoShadow", COLOUR.ink, 0.65) -- navy at 35%
local logo, logoStroke, logoScale = wordmark("Logo", COLOUR.white, 0)
gradient(logo, 90).Color = ColorSequence.new(COLOUR.white, COLOUR.logoLow)

-- The Fry (stand-in for `UI_Load_Mascot`): body, belly, tail and a big eye with a highlight,
-- facing right. Positions are shares of its box; `face(-1)` mirrors them.
local fry = frame("Fry", background, COLOUR.white, 1)
fry.AnchorPoint = Vector2.new(0.5, 0.5)
fry.ZIndex = 4
local fryScale = Instance.new("UIScale")
fryScale.Parent = fry
local tail = frame("Tail", fry, COLOUR.fryTail, 0)
tail.AnchorPoint = Vector2.new(0.5, 0.5)
tail.Size = UDim2.fromScale(0.55, 0.55)
tail.Rotation = 45
tail.SizeConstraint = Enum.SizeConstraint.RelativeYY
round(tail, UDim.new(0.18, 0))
local tailStroke = stroke(tail, COLOUR.ink)
local body = frame("Body", fry, COLOUR.fryBody, 0)
body.AnchorPoint = Vector2.new(0.5, 0.5)
body.Size = UDim2.fromScale(0.78, 1)
body.ZIndex = 2
round(body)
local bodyStroke = stroke(body, COLOUR.ink)
local belly = frame("Belly", body, COLOUR.fryBelly, 0)
belly.AnchorPoint = Vector2.new(0.5, 0.5)
belly.Position = UDim2.fromScale(0.52, 0.68)
belly.Size = UDim2.fromScale(0.6, 0.34)
belly.ZIndex = 2
round(belly)
local eye = frame("Eye", body, COLOUR.white, 0)
eye.AnchorPoint = Vector2.new(0.5, 0.5)
eye.Size = UDim2.fromScale(0.46, 0.46)
eye.SizeConstraint = Enum.SizeConstraint.RelativeYY
eye.ZIndex = 3
round(eye)
local eyeStroke = stroke(eye, COLOUR.ink)
local pupil = frame("Pupil", eye, COLOUR.ink, 0)
pupil.AnchorPoint = Vector2.new(0.5, 0.5)
pupil.Size = UDim2.fromScale(0.58, 0.58)
pupil.ZIndex = 3
round(pupil)
local glint = frame("Glint", pupil, COLOUR.white, 0)
glint.AnchorPoint = Vector2.new(0.5, 0.5)
glint.Position = UDim2.fromScale(0.36, 0.32)
glint.Size = UDim2.fromScale(0.4, 0.4)
glint.ZIndex = 3
round(glint)

local facing = 0
local tailX = 0.2
local function face(direction: number)
	if direction == facing then
		return
	end
	facing = direction
	local function x(share: number): number
		return if direction > 0 then share else 1 - share
	end
	tailX = x(0.2)
	tail.Position = UDim2.fromScale(tailX, 0.5)
	body.Position = UDim2.fromScale(x(0.6), 0.5)
	eye.Position = UDim2.fromScale(if direction > 0 then 0.72 else 0.28, 0.4)
	pupil.Position = UDim2.fromScale(if direction > 0 then 0.6 else 0.4, 0.52)
end
face(1)

-- The progress row: five bubbles along the bottom (04 §2.2). Empty is a faint outline; full is a
-- solid white bubble with a shine; at J 20 (04 §2.4) the whole row turns pale grey and solid.
local row = frame("Progress", background, COLOUR.white, 1)
row.AnchorPoint = Vector2.new(0.5, 0.5)
row.Position = UDim2.fromScale(0.5, 0.9)
row.ZIndex = 3
local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.Parent = row

type Bubble = {
	disc: Frame,
	rim: UIStroke,
	shade: UIGradient,
	shine: Frame,
	pop: UIScale,
	full: boolean,
}
local bubbles: { Bubble } = {}
for i = 1, CONFIG.bubbles do
	local disc = frame("Bubble", row, COLOUR.white, 1)
	disc.LayoutOrder = i
	disc.ZIndex = 3
	round(disc)
	local shade = gradient(disc, 50)
	shade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLOUR.white),
		ColorSequenceKeypoint.new(0.45, COLOUR.white),
		ColorSequenceKeypoint.new(1, COLOUR.bubbleShade),
	})
	local shine = frame("Shine", disc, COLOUR.white, 0)
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.Position = UDim2.fromScale(0.33, 0.31)
	shine.Size = UDim2.fromScale(0.28, 0.2)
	shine.Rotation = -35
	shine.ZIndex = 3
	round(shine)
	local pop = Instance.new("UIScale")
	pop.Parent = disc
	bubbles[i] = {
		disc = disc,
		rim = stroke(disc, COLOUR.white),
		shade = shade,
		shine = shine,
		pop = pop,
		full = false,
	}
end

local dimmed = false
local function paintBubble(b: Bubble)
	if dimmed then
		b.disc.BackgroundColor3 = COLOUR.dim
		b.disc.BackgroundTransparency = if b.full then 0 else 0.45
		b.rim.Color = COLOUR.dim
		b.rim.Transparency = 0
		b.shade.Enabled = false
		b.shine.Visible = false
	else
		b.disc.BackgroundColor3 = COLOUR.white
		b.disc.BackgroundTransparency = if b.full then 0 else 1
		b.rim.Color = COLOUR.white
		b.rim.Transparency = if b.full then 0 else 0.6
		b.shade.Enabled = b.full
		b.shine.Visible = b.full
	end
end
for _, b in bubbles do
	paintBubble(b)
end

-- The slow sign (04 §2.4 at J 30; stand-in for `UI_Loading_SlowIcon`): a spinning ring and a
-- signal icon with one bar lit, on a faint navy pill. No text.
local slow = frame("Slow", background, COLOUR.ink, 0.72)
slow.AnchorPoint = Vector2.new(0.5, 1) -- placed above the bubble row in `layout`
slow.Visible = false
slow.ZIndex = 3
round(slow)
local function ring(name: string, transparency: number): (Frame, UIStroke)
	local r = frame(name, slow, COLOUR.white, 1)
	r.AnchorPoint = Vector2.new(0.5, 0.5)
	r.ZIndex = 3
	round(r)
	local s = stroke(r, COLOUR.white)
	s.Transparency = transparency
	return r, s
end
local ringTrack, trackStroke = ring("Track", 0.75)
local spinner, spinnerStroke = ring("Spinner", 0)
gradient(spinnerStroke, 0).Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.45, 0),
	NumberSequenceKeypoint.new(0.62, 1),
	NumberSequenceKeypoint.new(1, 1),
})
local signalBars: { Frame } = {}
for i = 1, 3 do
	local bar = frame("Bar", slow, COLOUR.white, if i == 1 then 0 else 0.4)
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.ZIndex = 3
	round(bar, UDim.new(0.5, 0))
	signalBars[i] = bar
end

-- Dot pool: a white dot in a faint glow ring.
type Dot = {
	disc: Frame,
	glow: Frame,
	x: number,
	y: number,
	phase: number,
	rate: number,
	alive: boolean,
}
local dots: { Dot } = {}
for i = 1, CONFIG.dotsMax do
	local disc = frame("Dot", dotLayer, COLOUR.white, 0.02)
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Visible = false
	disc.ZIndex = 2
	round(disc)
	local glow = frame("Glow", disc, COLOUR.white, 0.8)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.ZIndex = 2
	round(glow)
	dots[i] = { disc = disc, glow = glow, x = 0, y = 0, phase = 0, rate = 1.7, alive = false }
end

-- Bite puffs: three small rising rings at the mouth on each dot eaten.
type Puff = {
	disc: Frame,
	rim: UIStroke,
	x: number,
	y: number,
	vx: number,
	born: number,
	alive: boolean,
}
local puffs: { Puff } = {}
for i = 1, CONFIG.puffs do
	local disc = frame("Puff", dotLayer, COLOUR.white, 1)
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Visible = false
	disc.ZIndex = 5
	round(disc)
	puffs[i] = {
		disc = disc,
		rim = stroke(disc, COLOUR.white),
		x = 0,
		y = 0,
		vx = 0,
		born = 0,
		alive = false,
	}
end

-- Layout in rpx, again whenever the screen changes size.
local width, height, rpx = 1, 1, 1
local function layout()
	local size = gui.AbsoluteSize
	width, height = math.max(size.X, 1), math.max(size.Y, 1)
	rpx = math.min(width, height) / 720
	-- The word's own bounds at its set size (TextBounds once the font is in, else measured).
	local bounds = logo.TextBounds
	if bounds.X < 1 then
		bounds = TextService:GetTextSize(
			"GULP",
			CONFIG.logoTextSize,
			Enum.Font.FredokaOne,
			Vector2.new(4096, 4096)
		)
	end
	local logoScaleBy = CONFIG.logoWidth * width / math.max(bounds.X, 1)
	local logoHeight = bounds.Y * logoScaleBy
	for _, label in { logo, logoShadow } do
		label.Size = UDim2.fromOffset(bounds.X, bounds.Y)
	end
	logoScale.Scale, logoShadowScale.Scale = logoScaleBy, logoScaleBy
	-- The stroke is in the label's units: the UIScale stretches it with the word.
	logoStroke.Thickness = math.max(2, CONFIG.logoStroke * logoHeight) / logoScaleBy
	logoShadowStroke.Thickness = logoStroke.Thickness
	logo.Position = UDim2.fromScale(0.5, CONFIG.logoY)
	logoShadow.Position = UDim2.new(0.5, 0, CONFIG.logoY, CONFIG.logoShadow * logoHeight)
	local length = CONFIG.fryLength * rpx
	fry.Size = UDim2.fromOffset(length, length * 0.56)
	bodyStroke.Thickness = math.max(1, 2.7 * rpx)
	tailStroke.Thickness = bodyStroke.Thickness
	eyeStroke.Thickness = math.max(1, 1.6 * rpx)
	local disc, gap = CONFIG.bubbleSize * rpx, CONFIG.bubbleGap * rpx
	rowLayout.Padding = UDim.new(0, gap)
	row.Size = UDim2.fromOffset(CONFIG.bubbles * disc + (CONFIG.bubbles - 1) * gap, disc)
	for _, b in bubbles do
		b.disc.Size = UDim2.fromOffset(disc, disc)
		b.rim.Thickness = math.max(1.5, 4 * rpx)
	end
	-- The slow sign, in shares of the icon height `h`: the ring at the left, the bars at the right,
	-- its pill `slowGap` above the bubble row.
	local h = CONFIG.slowIcon * rpx
	slow.Size = UDim2.fromOffset(h * 2.75, h * 1.3)
	slow.Position = UDim2.new(0.5, 0, 0.9, -(disc * 0.5 + CONFIG.slowGap * rpx))
	for _, r in { ringTrack, spinner } do
		r.Size = UDim2.fromOffset(h, h)
		r.Position = UDim2.fromOffset(h * 0.8, h * 0.65)
	end
	spinnerStroke.Thickness = math.max(2, 6.5 * rpx)
	trackStroke.Thickness = spinnerStroke.Thickness
	for i, bar in signalBars do
		bar.Size = UDim2.fromOffset(h * 0.22, h * (0.25 + 0.25 * i))
		bar.Position = UDim2.fromOffset(h * (1.68 + 0.34 * (i - 1)), h * 1.15)
	end
	for _, dot in dots do
		dot.disc.Size = UDim2.fromOffset(CONFIG.dotSize * rpx, CONFIG.dotSize * rpx)
	end
	for _, p in puffs do
		p.rim.Thickness = math.max(1, 1.6 * rpx)
	end
	for _, d in drifts do
		d.rim.Thickness = math.max(1, 1.6 * rpx)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
logo:GetPropertyChangedSignal("TextBounds"):Connect(layout) -- the font arrives after the first frame

-- First frame: ours up, then the default screen away (09 §6.10, V32).
gui.Parent = player:WaitForChild("PlayerGui")
layout()
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- `SFX_Bite_Small` on each dot (04 §2.2), once the place has loaded.
local biteSound: Sound? = nil

-- The toy -----------------------------------------------------------------------------------------

local fryX, fryY = width * 0.3, height * 0.55
local targetX, targetY = fryX, fryY
local velX, velY = 0, 0
local growth = 0
local nextDotAt = 0
local chompAt = -math.huge
local tailPhase = 0
local nextDriftAt = 0

local function pointerTo(position: Vector3)
	local inset = GuiService:GetGuiInset() -- InputObject positions start below it; this ScreenGui ignores it
	targetX, targetY = position.X + inset.X, position.Y + inset.Y
end

local touching = false
local inputConnections = {
	UserInputService.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1 then
			touching = true
			pointerTo(input.Position)
		end
	end),
	UserInputService.InputChanged:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.MouseMovement
			or (kind == Enum.UserInputType.Touch and touching)
		then
			pointerTo(input.Position)
		end
	end),
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1 then
			touching = false
		end
	end),
}

-- A new dot at `x`: most come in on the Fry's lane, the rest anywhere in the middle band.
local function spawnDot(now: number, x: number?)
	for _, dot in dots do
		if not dot.alive then
			dot.alive = true
			dot.x = x or width + CONFIG.dotSize * rpx
			if math.random() < CONFIG.dotLane then
				local lane = height * CONFIG.dotLaneHalf
				dot.y =
					math.clamp(fryY + (math.random() * 2 - 1) * lane, height * 0.32, height * 0.8)
			else
				dot.y = height * (0.32 + 0.48 * math.random())
			end
			dot.rate = 1.3 + 0.9 * math.random() -- each dot waves at its own pace
			dot.phase = now * dot.rate + math.random() * 6.28
			local glow = CONFIG.dotGlow * (0.85 + 0.3 * math.random())
			dot.glow.Size = UDim2.fromScale(glow, glow)
			dot.disc.Visible = true
			return
		end
	end
end

local function puff(x: number, y: number, now: number)
	local made = 0
	for _, p in puffs do
		if not p.alive then
			p.alive = true
			p.x, p.y = x + (math.random() - 0.5) * 10 * rpx, y
			p.vx = (math.random() - 0.5) * 60 * rpx
			p.born = now - made * 0.04
			p.disc.Visible = true
			made += 1
			if made == 3 then
				return
			end
		end
	end
end

local bites = 0
local function eat(dot: Dot, now: number, y: number)
	dot.alive = false
	dot.disc.Visible = false
	growth = math.min(growth + CONFIG.growPerDot, CONFIG.growMax)
	bites += 1
	if studio and script:GetAttribute("DevAutopilot") == true then
		print(string.format("[Loading] bite %d, Fry scale %.2f", bites, 1 + growth))
	end
	chompAt = now
	puff(dot.x, y, now)
	if biteSound then
		SoundService:PlayLocalSound(biteSound)
	end
end

local function stepToy(dt: number, now: number)
	if studio and script:GetAttribute("DevAutopilot") == true then
		local best = math.huge
		for _, dot in dots do
			local d = if dot.alive then (dot.x - fryX) ^ 2 + (dot.y - fryY) ^ 2 else math.huge
			if d < best then
				best, targetX, targetY = d, dot.x, dot.y
			end
		end
	end
	-- The Fry closes a share of the gap to the thumb each second, capped in speed.
	local follow = 1 - math.exp(-CONFIG.fryFollow * dt)
	local dx, dy = (targetX - fryX) * follow, (targetY - fryY) * follow
	local cap = CONFIG.fryMaxSpeed * rpx * dt
	local step = math.sqrt(dx * dx + dy * dy)
	if step > cap then
		dx, dy = dx * cap / step, dy * cap / step
	end
	fryX = math.clamp(fryX + dx, 0, width)
	fryY = math.clamp(fryY + dy, 0, height)
	velX, velY = dx / math.max(dt, 1e-3), dy / math.max(dt, 1e-3)
	if math.abs(velX) > 20 * rpx then
		face(if velX > 0 then 1 else -1)
	end
	local tilt = math.deg(math.atan2(velY, math.max(math.abs(velX), 60 * rpx)))
	local bob = math.sin(now * 3) * 3 * rpx
	fry.Position = UDim2.fromOffset(fryX, fryY + bob)
	fry.Rotation = math.clamp(tilt, -30, 30) * facing
	-- Growth stays; a bite adds a short pop on top of it.
	local pop = (now - chompAt) / CONFIG.chompTime
	fryScale.Scale = (1 + growth)
		* (if pop < 1 then 1 + CONFIG.chompPop * math.sin(pop * math.pi) else 1)
	local chomp = math.clamp((now - chompAt) / CONFIG.squashTime, 0, 1)
	local squash = math.sin(chomp * math.pi) * 0.1
	body.Size = UDim2.fromScale(0.78 + squash, 1 - squash)
	-- The tail swings, faster when the Fry swims.
	local speed = math.sqrt(velX * velX + velY * velY) / (600 * rpx)
	tailPhase += dt * CONFIG.tailRate * (1 + math.min(speed, 1))
	local swing = math.sin(tailPhase)
	tail.Rotation = 45 + CONFIG.tailWiggle * swing
	tail.Position = UDim2.fromScale(tailX, 0.5 + 0.07 * swing)

	-- Dots drift in from the right with a gentle wave; the Fry eats any it touches.
	if now >= nextDotAt then
		nextDotAt = now + CONFIG.dotEvery * (0.7 + 0.6 * math.random())
		spawnDot(now)
	end
	local reach = (CONFIG.fryLength * 0.32 * (1 + growth) + CONFIG.dotSize * 0.5) * rpx
	for _, dot in dots do
		if dot.alive then
			dot.x -= CONFIG.dotSpeed * rpx * dt
			local y = dot.y + math.sin(now * dot.rate + dot.phase) * CONFIG.dotWave * rpx
			if dot.x < -CONFIG.dotSize * rpx then
				dot.alive = false
				dot.disc.Visible = false
			elseif (dot.x - fryX) ^ 2 + (y - fryY) ^ 2 <= reach * reach then
				eat(dot, now, y)
			else
				dot.disc.Position = UDim2.fromOffset(dot.x, y)
			end
		end
	end

	-- Bite puffs rise, swell and fade.
	for _, p in puffs do
		if p.alive then
			local age = (now - p.born) / CONFIG.puffLife
			if age >= 1 then
				p.alive = false
				p.disc.Visible = false
			elseif age >= 0 then
				local size = (4 + 7 * age) * rpx
				p.disc.Position = UDim2.fromOffset(
					p.x + p.vx * age * CONFIG.puffLife,
					p.y - 70 * rpx * age * CONFIG.puffLife
				)
				p.disc.Size = UDim2.fromOffset(size, size)
				p.rim.Transparency = 0.15 + 0.85 * age
			end
		end
	end

	-- Slow background bubbles: one now and then, rising and swaying.
	if now >= nextDriftAt then
		nextDriftAt = now + CONFIG.ambientEvery * (0.6 + 0.8 * math.random())
		for _, d in drifts do
			if not d.alive then
				local size = (10 + 16 * math.random()) * rpx
				d.alive = true
				d.x, d.y = width * (0.05 + 0.9 * math.random()), height + size
				d.speed = CONFIG.ambientSpeed * (0.7 + 0.6 * math.random()) * rpx
				d.phase = math.random() * 6.28
				d.disc.Size = UDim2.fromOffset(size, size)
				d.disc.Visible = true
				break
			end
		end
	end
	for _, d in drifts do
		if d.alive then
			d.y -= d.speed * dt
			if d.y < -30 * rpx then
				d.alive = false
				d.disc.Visible = false
			else
				d.disc.Position =
					UDim2.fromOffset(d.x + math.sin(now * 0.8 + d.phase) * 8 * rpx, d.y)
			end
		end
	end

	for i, ray in rays do
		ray.Rotation = 16 + 3 * math.sin(now * 0.25 + i * 1.3)
		ray.BackgroundTransparency = 0.86 + 0.05 * math.sin(now * 0.4 + i * 2.1)
	end
end

-- The first frame already has dots spread ahead of the Fry, as if they had been drifting a while.
do
	local now = os.clock()
	for i = 1, CONFIG.dotsAtStart do
		local share = (i - 0.5 + 0.6 * (math.random() - 0.5)) / CONFIG.dotsAtStart
		spawnDot(now, width * (0.38 + 0.6 * share))
	end
end

-- Minimum set -----------------------------------------------------------------------------------

local mode: string? = nil -- "full" | "partial" | "minimal" (see the header)
local worldLoaded = false
local essentialsDone, restDone, restAbandoned = false, false, false
local stepsDone = 0 -- the world, then each asset; the shell is counted when it is in
local stepsTotal = 2 + #ESSENTIAL + #REST

local function shellReady(): boolean
	return shellLoaded or workspace:FindFirstChild("Collision") ~= nil or j() >= CONFIG.shellTimeout
end

-- Preloads `items` side by side; each counts one step as it finishes, missing ones at once.
local function preload(items: { Instance }, missing: number)
	stepsDone += missing
	local left = #items
	for _, item in items do
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync({ item })
			end)
			stepsDone += 1
			left -= 1
		end)
	end
	while left > 0 do
		task.wait()
	end
end

task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	worldLoaded = true
	stepsDone += 1
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local absent: { string } = {}
	local function find(names: { string }): ({ Instance }, number)
		local found: { Instance } = {}
		for _, name in names do
			local item = if assets then assets:FindFirstChild(name, true) else nil
			if item then
				found[#found + 1] = item
			else
				absent[#absent + 1] = name
			end
		end
		return found, #names - #found
	end
	local essential, essentialMissing = find(ESSENTIAL)
	local rest, restMissing = find(REST)
	script:SetAttribute("LoadMissing", table.concat(absent, ","))

	local musicSource = if assets then assets:FindFirstChild("MUS_Nursery", true) else nil
	if musicSource and musicSource:IsA("Sound") then
		local track = musicSource:Clone()
		track.Name = "LoadingMusic"
		track.Looped = true
		local volume = track.Volume
		track.Volume = 0
		track.Parent = SoundService
		track:Play()
		TweenService:Create(track, TweenInfo.new(CONFIG.musicFadeIn), { Volume = volume }):Play()
	end
	local bite = if assets then assets:FindFirstChild("SFX_Bite_Small", true) else nil
	if bite and bite:IsA("Sound") then
		biteSound = bite
	end

	preload(essential, essentialMissing)
	essentialsDone = true
	if restAbandoned then
		return -- J 15 passed: everything but the essentials is left to stream later (04 §2.4)
	end
	preload(rest, restMissing)
	restDone = true
end)

-- 04 §2.4: decides `mode` once; called every frame until it is set.
local function decide()
	local t = j()
	local startable = worldLoaded and shellReady() and essentialsDone
	if t >= CONFIG.minimalAt and not startable then
		restAbandoned = true
	end
	if not startable then
		return
	end
	if restDone then
		mode = "full"
	elseif restAbandoned then
		mode = "minimal"
	elseif t >= CONFIG.partialAt then
		mode = "partial"
	end
	if mode then
		shellConnection:Disconnect()
		script:SetAttribute("LoadMode", mode)
	end
end

local fillInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local function showProgress()
	local share = devProgress
		or if mode then 1 else (stepsDone + (if shellReady() then 1 else 0)) / stepsTotal
	local lit = math.floor(share * CONFIG.bubbles + 1e-6)
	for i, b in bubbles do
		if i <= lit and not b.full then
			b.full = true
			paintBubble(b)
			b.pop.Scale = 1.3
			TweenService:Create(b.pop, fillInfo, { Scale = 1 }):Play()
		end
	end
	-- 04 §2.4 at J 20: the profile is late (the server sets `Slot` once it has loaded).
	local late = j() >= CONFIG.dimAt and (devNoProfile or player:GetAttribute("Slot") == nil)
	if late ~= dimmed then
		dimmed = late
		for _, b in bubbles do
			paintBubble(b)
		end
	end
	if j() >= CONFIG.slowAt and not slow.Visible then
		slow.Visible = true
	end
end

local function creatureHere(): boolean
	local character = player.Character
	return character ~= nil and character.PrimaryPart ~= nil
end

-- Exit ------------------------------------------------------------------------------------------

local function exit()
	for _, connection in inputConnections do
		connection:Disconnect()
	end
	-- Everything fades while bubbles rise out of the screen (04 §2.2); input is never sunk, so
	-- steering works at once (08 §8.1).
	local info = TweenInfo.new(CONFIG.exitTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, item in background:GetDescendants() do
		if item:IsA("TextLabel") then
			TweenService:Create(item, info, { TextTransparency = 1 }):Play()
		elseif item:IsA("Frame") then
			TweenService:Create(item, info, { BackgroundTransparency = 1 }):Play()
		elseif item:IsA("UIStroke") then
			TweenService:Create(item, info, { Transparency = 1 }):Play()
		end
	end
	TweenService:Create(background, info, { BackgroundTransparency = 1 }):Play()
	local rise = TweenInfo.new(CONFIG.exitTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _ = 1, CONFIG.splitBubbles do
		local size = (24 + 56 * math.random()) * rpx
		local x, y = width * math.random(), height * (0.15 + 0.85 * math.random())
		local split = frame("Split", gui, COLOUR.white, 0.55)
		split.AnchorPoint = Vector2.new(0.5, 0.5)
		split.Position = UDim2.fromOffset(x, y)
		split.Size = UDim2.fromOffset(size * 0.6, size * 0.6)
		split.ZIndex = 5
		round(split)
		local rim = stroke(split, COLOUR.white)
		rim.Thickness = math.max(1.5, 2.7 * rpx)
		TweenService:Create(split, rise, {
			Position = UDim2.fromOffset(x + (math.random() - 0.5) * 40 * rpx, y - height * 0.22),
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(rim, rise, { Transparency = 1 }):Play()
	end
	task.delay(CONFIG.exitTime, function()
		gui:Destroy()
	end)
end

local frameConnection: RBXScriptConnection
frameConnection = RunService.PreRender:Connect(function(dt: number)
	local now = os.clock()
	if not mode then
		decide()
	end
	showProgress()
	stepToy(dt, now)
	if slow.Visible then
		spinner.Rotation = (now * 300) % 360
	end
	if mode and creatureHere() and not (studio and script:GetAttribute("DevHold") == true) then
		frameConnection:Disconnect()
		script:SetAttribute("LoadDone", true)
		exit()
	end
end)
