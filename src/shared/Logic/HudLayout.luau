--!strict
-- HudLayout: the pure geometry of the run HUD stage 1, of screens S07, S08, S11, S12 and S14
-- and of the guide kit S33 (docs/08, sections 1.3 to 1.5, 3.3, 3.12, 3.16, 4.1 to 4.5, 5.1 and 7;
-- docs/04, section 3.2; docs/15, sections 3.1 to 3.3). Numbers and tables only, so it runs in
-- Lune; `client/UI` places instances where this module says.
--
-- Coordinates are rpx. A `content` rect is the safe frame less its margins (Kit/Screen's
-- `Layout.contentSize`), origin at its top left; the keep-out rects of `Layout.keepOut` are in
-- the same space. The drag ring works in rpx of the full screen (the `GulpWorld` layer).

local HudLayout = {}

export type Rect = { x: number, y: number, width: number, height: number }
export type Size = { width: number, height: number }
export type ScreenClass = "Phone" | "Tablet" | "Desktop" | "Handheld" | "TV"

-- 08 §1.5.
HudLayout.TOUCH_MIN = 88 -- minimum hit area on phone and tablet
HudLayout.MOUSE_MIN = 48 -- minimum mouse target on desktop
HudLayout.GAP_MIN = 16 -- minimum gap between two hit areas
-- 08 §1.3: tappable elements keep 40 rpx from the bottom of the device safe area, which lies
-- 28 rpx (the bottom margin) under the content box.
HudLayout.BOTTOM_TAP_CLEAR = 40
HudLayout.MARGIN_BOTTOM = 28

-- 08 §1.4: the keep-clear box, as shares of the safe frame.
HudLayout.KEEP_CLEAR = table.freeze({ x0 = 0.28, x1 = 0.72, y0 = 0.34, y1 = 0.76 })

-- 08 §3.3 and §3.4: the mass bar, and its keep-out fallback of §1.3.
HudLayout.MASS_BAR = table.freeze({ top = 12, width = 440, narrowWidth = 360, height = 64 })
HudLayout.KEEP_OUT_CLEAR = 16

-- 08 §3.3 (phone), the tablet switch (24 rpx further from the edges) and the desktop switch
-- (hint tiles 80 × 96). `right` and `bottom` are the distances from the content box's edges.
type Corner = { right: number, bottom: number, width: number, height: number }
local DASH: { [string]: Corner } = {
	Phone = { right = 40, bottom = 44, width = 136, height = 136 },
	Tablet = { right = 64, bottom = 68, width = 136, height = 136 },
	Desktop = { right = 32, bottom = 32, width = 80, height = 96 },
}
-- `HUD.Ability` is built in stage 2; stage 1 keeps its place free (the home marker slides
-- around it, 08 §3.12).
local ABILITY: { [string]: Corner } = {
	Phone = { right = 196, bottom = 36, width = 108, height = 108 },
	Tablet = { right = 220, bottom = 60, width = 108, height = 108 },
	Desktop = { right = 128, bottom = 32, width = 80, height = 96 },
}

-- 08 §3.16 and §3.3: ring 168, knob 72, the knob held within 84 rpx, dead zone 14.
HudLayout.DRAG = table.freeze({ ring = 168, knob = 72, reach = 84, deadZone = 14 })

-- 08 §3.12: marker 72, clamped to an ellipse 72 rpx inside the safe frame; label Small 22.
HudLayout.HOME = table.freeze({ size = 72, inset = 72, labelHeight = 28, pointer = 24 })
local HOME_SLIDE_STEP = math.rad(2)

-- 08 §4.4: Swim again is the primary button, 280 × 96, bottom right (zone A).
HudLayout.SWIM_AGAIN = table.freeze({ width = 280, height = 96, right = 40, bottom = 44 })
-- 08 §1.4: zone A reaches 340 rpx from a bottom corner.
HudLayout.ZONE_A = 340

-- 08 §4.5, the Pearls table of S12 (centred alone at stage 1, beside the specimen card from
-- stage 2). Row heights follow the type sizes of 08 §1.5 on the 8 rpx grid.
HudLayout.PEARLS = table.freeze({
	width = 560,
	padding = 24,
	titleHeight = 88, -- shell art and `bank.title` (Title 40) above the panel
	headerHeight = 48,
	rowHeight = 48,
	dividerHeight = 24,
	totalHeight = 72,
	continueWidth = 280,
	continueHeight = 96,
})

local function classKey(screenClass: ScreenClass): string
	if screenClass == "Tablet" then
		return "Tablet"
	elseif screenClass == "Desktop" or screenClass == "Handheld" or screenClass == "TV" then
		-- Handheld [L] and TV [P1] use the desktop tiles with glyphs (08 §3.3).
		return "Desktop"
	end
	return "Phone"
end

local function fromCorner(c: Corner, content: Size): Rect
	return {
		x = content.width - c.right - c.width,
		y = content.height - c.bottom - c.height,
		width = c.width,
		height = c.height,
	}
end

--- True when two rects share any area (touching edges do not count).
function HudLayout.overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.width
		and b.x < a.x + a.width
		and a.y < b.y + b.height
		and b.y < a.y + a.height
end

--- `rect` grown by `by` on every side.
function HudLayout.grow(rect: Rect, by: number): Rect
	return {
		x = rect.x - by,
		y = rect.y - by,
		width = rect.width + 2 * by,
		height = rect.height + 2 * by,
	}
end

--- The hit area of a visible rect: centred on it and at least `minSize` on each side.
function HudLayout.hitRect(rect: Rect, minSize: number): Rect
	local w = math.max(rect.width, minSize)
	local h = math.max(rect.height, minSize)
	return {
		x = rect.x + (rect.width - w) / 2,
		y = rect.y + (rect.height - h) / 2,
		width = w,
		height = h,
	}
end

--- The minimum hit size for a screen class: 48 with a mouse, 88 on touch (08 §1.5).
function HudLayout.minTarget(screenClass: ScreenClass): number
	return if classKey(screenClass) == "Desktop" then HudLayout.MOUSE_MIN else HudLayout.TOUCH_MIN
end

--- The keep-clear box of 08 §1.4 in content rpx.
function HudLayout.keepClear(content: Size): Rect
	local k = HudLayout.KEEP_CLEAR
	return {
		x = content.width * k.x0,
		y = content.height * k.y0,
		width = content.width * (k.x1 - k.x0),
		height = content.height * (k.y1 - k.y0),
	}
end

--- The mass bar (08 §3.3), moved out of the Roblox keep-out by 08 §1.3: first 360 wide, then
--- shifted right until it clears every keep-out rect by 16 rpx.
function HudLayout.massBar(content: Size, keepOut: { Rect }): Rect
	local spec = HudLayout.MASS_BAR
	local function centred(width: number): Rect
		return { x = (content.width - width) / 2, y = spec.top, width = width, height = spec.height }
	end
	local function blocked(rect: Rect): Rect?
		for _, k in keepOut do
			if HudLayout.overlaps(HudLayout.grow(rect, HudLayout.KEEP_OUT_CLEAR), k) then
				return k
			end
		end
		return nil
	end
	local rect = centred(spec.width)
	if blocked(rect) == nil then
		return rect
	end
	rect = centred(spec.narrowWidth)
	for _ = 1, #keepOut + 1 do
		local k = blocked(rect)
		if k == nil then
			break
		end
		rect.x = k.x + k.width + HudLayout.KEEP_OUT_CLEAR
	end
	return rect
end

--- The dash button or hint tile, by screen class (08 §3.3).
function HudLayout.dash(screenClass: ScreenClass, content: Size): Rect
	return fromCorner(DASH[classKey(screenClass)], content)
end

--- The place kept for the ability button or tile (built in stage 2).
function HudLayout.ability(screenClass: ScreenClass, content: Size): Rect
	return fromCorner(ABILITY[classKey(screenClass)], content)
end

export type HudRects = {
	massBar: Rect,
	dash: Rect,
	dashHit: Rect,
	ability: Rect,
	keepClear: Rect,
}

--- Every stage 1 rect of the run HUD for one screen.
function HudLayout.compute(screenClass: ScreenClass, content: Size, keepOut: { Rect }): HudRects
	local dash = HudLayout.dash(screenClass, content)
	return {
		massBar = HudLayout.massBar(content, keepOut),
		dash = dash,
		dashHit = HudLayout.hitRect(dash, HudLayout.minTarget(screenClass)),
		ability = HudLayout.ability(screenClass, content),
		keepClear = HudLayout.keepClear(content),
	}
end

export type DragPose = {
	-- Ring centre and knob centre, full-screen rpx.
	ringX: number,
	ringY: number,
	knobX: number,
	knobY: number,
	-- True inside the dead zone: the swim does not steer yet.
	dead: boolean,
}

--- `HUD.DragRing` (08 §3.16): the ring sits at the drag origin, nudged so the whole ring is on
--- a `screen` sized full screen; the knob follows the thumb, held within 84 rpx of the origin.
function HudLayout.dragRing(
	originX: number,
	originY: number,
	touchX: number,
	touchY: number,
	screen: Size
): DragPose
	local spec = HudLayout.DRAG
	local radius = spec.ring / 2
	local cx = math.clamp(originX, radius, math.max(radius, screen.width - radius))
	local cy = math.clamp(originY, radius, math.max(radius, screen.height - radius))
	local dx, dy = touchX - originX, touchY - originY
	local length = math.sqrt(dx * dx + dy * dy)
	if length > spec.reach then
		dx, dy = dx / length * spec.reach, dy / length * spec.reach
	end
	return {
		ringX = cx,
		ringY = cy,
		knobX = cx + dx,
		knobY = cy + dy,
		dead = length < spec.deadZone,
	}
end

--- The point of the home ellipse (08 §3.12) at angle `angle` (radians, screen space: 0 points
--- right, π/2 points down) around the centre of `content`.
function HudLayout.homeOnEllipse(content: Size, angle: number): (number, number)
	local inset = HudLayout.HOME.inset
	local ax = math.max(0, content.width / 2 - inset)
	local ay = math.max(0, content.height / 2 - inset)
	return content.width / 2 + ax * math.cos(angle), content.height / 2 + ay * math.sin(angle)
end

-- What the marker draws around its centre: the pointer orbits 48 rpx out (its tip 60), the
-- glow is 1.3 x the marker, and the distance chip hangs 4 rpx under the marker.
HudLayout.HOME_REACH = 48 + HudLayout.HOME.pointer / 2
HudLayout.HOME_CHIP_GAP = 4

--- The rect the home marker takes with its centre on (x, y): the pointer's whole orbit, the
--- glow and the distance chip under it.
function HudLayout.homeRect(x: number, y: number): Rect
	local h = HudLayout.HOME
	local reach = math.max(HudLayout.HOME_REACH, h.size * 1.3 / 2)
	local bottom = math.max(reach, h.size / 2 + HudLayout.HOME_CHIP_GAP + h.labelHeight)
	return {
		x = x - reach,
		y = y - reach,
		width = 2 * reach,
		height = reach + bottom,
	}
end

--- The drag ring's area (08 §3.16) as a rect, from a pose's ring centre.
function HudLayout.ringRect(ringX: number, ringY: number): Rect
	local r = HudLayout.DRAG.ring / 2
	return { x = ringX - r, y = ringY - r, width = 2 * r, height = 2 * r }
end

--- Everything the off-screen home marker keeps clear of (08 §3.12 and §1.5): the mass bar, the
--- dash and ability hit areas and, while a touch steers, the drag ring (content-box rpx).
function HudLayout.homeAvoid(screenClass: ScreenClass, rects: HudRects, ring: Rect?): { Rect }
	local min = HudLayout.minTarget(screenClass)
	local avoid = {
		rects.massBar,
		rects.dashHit,
		HudLayout.hitRect(rects.ability, min),
	}
	if ring then
		table.insert(avoid, ring)
	end
	return avoid
end

--- The off-screen home marker (08 §3.12): on the ellipse in the direction of home, slid along it
--- the shortest way until the marker, its pointer and its label clear every `avoid` rect by
--- 16 rpx.
--- Returns the centre and the angle used.
function HudLayout.homeMarker(
	content: Size,
	angle: number,
	avoid: { Rect }
): (number, number, number)
	local function clear(a: number): boolean
		local x, y = HudLayout.homeOnEllipse(content, a)
		local rect = HudLayout.homeRect(x, y)
		for _, r in avoid do
			if HudLayout.overlaps(rect, HudLayout.grow(r, HudLayout.GAP_MIN)) then
				return false
			end
		end
		return true
	end
	local steps = math.ceil(math.pi / HOME_SLIDE_STEP)
	for i = 0, steps do
		for _, sign in { 1, -1 } do
			local a = angle + sign * i * HOME_SLIDE_STEP
			if clear(a) then
				local x, y = HudLayout.homeOnEllipse(content, a)
				return x, y, a
			end
		end
	end
	local x, y = HudLayout.homeOnEllipse(content, angle)
	return x, y, angle
end

-- 08 §3.3 and §4.1: `HUD.MomentSlot`, top centre 130 rpx down, up to 480 × 112. 08 §3.3 also
-- places `HUD.BankChip` (82 down, 40 tall) between it and the mass bar.
HudLayout.MOMENT_SLOT = table.freeze({ top = 130, width = 480, height = 112 })
HudLayout.BANK_CHIP = table.freeze({ top = 82, width = 240, height = 40 })
-- 08 §4.1: every moment card sits `CARD_TOP` down in the slot, so it keeps 08 §1.5's 16 rpx gap
-- under `HUD.BankChip` (122) and ends with the slot (242), 104 rpx tall.
HudLayout.CARD_TOP = 8
HudLayout.CARD_HEIGHT = 104
-- `UI_Common_Rays` stand-in: the light spokes' outer corners reach r / cos(π/16), 2 % past the
-- burst's radius, so its clip leaves this much round it.
HudLayout.RAYS_PAD = 4
-- 08 §1.5 type sizes (Kit/Theme.TEXT), here so the specs can prove the 22 rpx floor.
HudLayout.TEXT_FLOOR = 22

-- 08 §4.2, S07: the tier-up card, 460 × 104 on `UI_Common_Ribbon`: a cream band with a notched
-- tail tucked behind each end, the new tier badge (96; 104 at tier 7) at the left of the band,
-- then `moment.tier_up` (Body 24), the tier name (Title 40) and the `moment.new_food` row
-- (Small 22 and up to three 36 rpx prey icons, each in an edible-colour ring, read at a glance on
-- a phone). Rays (tier 7) turn behind the badge, over the band: a burst of `raysRadius` centred on
-- the badge, the text moved right to clear it by `raysGap`.
HudLayout.TIER_UP = table.freeze({
	width = 460,
	height = HudLayout.CARD_HEIGHT,
	band = 24, -- each tail shows this much beyond the band
	tailWidth = 44,
	tailHeight = 76,
	tailDrop = 8, -- the tails hang this much below the band's middle
	notch = 16, -- depth of the V cut into each tail's outer end
	art = 96,
	topArt = 104, -- tier 7: the climax badge, on the same centre
	topRim = 4, -- tier 7: a gold rim round the 96 rpx badge makes those 104
	artInset = 8, -- band edge to badge
	gap = 16, -- art to text, and text to the band's right edge
	headerHeight = 26,
	nameHeight = 42,
	lineHeight = 36,
	foodIcon = 36,
	foodGap = 6,
	raysRadius = 92,
	raysGap = 8,
	type = table.freeze({ header = 24, name = 40, line = 22 }),
})
-- 08 §4.3, S08: the trait gained card, 420 × 104: the trait icon (80) in its rarity frame, then
-- `moment.trait_gained` (Body 24), the trait name (Title 40) and the effect line `trait.<id>.fx`
-- (Body 24; Small 22 when a translation does not fit, 08 §1.5). Epic and Mythic add rays
-- behind the icon, over the card, as S07's tier 7 does.
HudLayout.TRAIT_GAINED = table.freeze({
	width = 420,
	height = HudLayout.CARD_HEIGHT,
	band = 0,
	art = 80,
	artInset = 16,
	gap = 16,
	headerHeight = 28,
	nameHeight = 44,
	lineHeight = 28,
	raysRadius = 84,
	raysGap = 8,
	type = table.freeze({ header = 24, name = 40, line = 24 }),
})

--- `HUD.MomentSlot` (08 §3.3) in content rpx as the moment cards use it: centred, 130 rpx from
--- the top, 480 x 112, never moved (14 row 35 (c)). A guide bubble's place in the slot is
--- `momentSlot(content, size)`.
function HudLayout.momentCardSlot(content: Size): Rect
	local s = HudLayout.MOMENT_SLOT
	return { x = (content.width - s.width) / 2, y = s.top, width = s.width, height = s.height }
end

--- `HUD.BankChip` at its widest (08 §3.3), in content rpx. Stage 2 builds it; the moment slot
--- keeps clear of it now.
function HudLayout.bankChip(content: Size): Rect
	local b = HudLayout.BANK_CHIP
	return { x = (content.width - b.width) / 2, y = b.top, width = b.width, height = b.height }
end

export type MomentCardRects = {
	card: Rect, -- in the slot, top centred
	band: Rect, -- the cream panel, card-local from here down (all of the card for S08)
	tails: { Rect }, -- S07's two ribbon tails behind the band ends, left first; empty for S08
	art: Rect, -- badge or icon
	rays: Rect, -- the ray burst, centred on the art
	raysClip: Rect, -- where the rays may show: the whole burst and its spoke tips, cut only at the
	-- card's bottom (08 §4.1: a round burst past the sides and the top, never below the card)
	header: Rect,
	name: Rect,
	line: Rect?, -- the new food row or the effect line; nil when there is none
}

type CardSpec = {
	width: number,
	height: number,
	band: number,
	art: number,
	artInset: number,
	gap: number,
	headerHeight: number,
	nameHeight: number,
	lineHeight: number,
	raysRadius: number,
	raysGap: number,
}

local function momentCard(
	spec: CardSpec,
	slot: Size,
	line: boolean,
	artSize: number?,
	rays: boolean?
): MomentCardRects
	local band = { x = spec.band, y = 0, width = spec.width - 2 * spec.band, height = spec.height }
	-- A bigger badge grows about the same centre, so the text does not move.
	local cx = band.x + spec.artInset + spec.art / 2
	local cy = spec.height / 2
	local a = artSize or spec.art
	local art = { x = cx - a / 2, y = cy - a / 2, width = a, height = a }
	local r = spec.raysRadius
	local x = band.x + spec.artInset + spec.art + spec.gap
	if rays then
		-- The burst is symmetric about the art, so the text starts past its right end.
		x = math.max(x, cx + r + spec.raysGap)
	end
	local width = band.x + band.width - spec.gap - x
	local stack = spec.headerHeight + spec.nameHeight + (if line then spec.lineHeight else 0)
	local y = (spec.height - stack) / 2
	local pad = HudLayout.RAYS_PAD
	return {
		card = {
			x = (slot.width - spec.width) / 2,
			y = HudLayout.CARD_TOP,
			width = spec.width,
			height = spec.height,
		},
		band = band,
		tails = {},
		art = art,
		rays = { x = cx - r, y = cy - r, width = 2 * r, height = 2 * r },
		raysClip = {
			x = cx - r - pad,
			y = cy - r - pad,
			width = 2 * (r + pad),
			height = spec.height - (cy - r - pad),
		},
		header = { x = x, y = y, width = width, height = spec.headerHeight },
		name = { x = x, y = y + spec.headerHeight, width = width, height = spec.nameHeight },
		line = if line
			then {
				x = x,
				y = y + spec.headerHeight + spec.nameHeight,
				width = width,
				height = spec.lineHeight,
			}
			else nil,
	}
end

--- S07 (08 §4.2) inside a `slot` sized slot; `food` false when no prey became edible, `top`
--- true for the last tier (the bigger badge and the rays).
function HudLayout.tierUpCard(slot: Size, food: boolean, top: boolean?): MomentCardRects
	local spec = HudLayout.TIER_UP
	local rects = momentCard(spec, slot, food, if top then spec.topArt else nil, top)
	local y = (spec.height - spec.tailHeight) / 2 + spec.tailDrop
	rects.tails = {
		{ x = 0, y = y, width = spec.tailWidth, height = spec.tailHeight },
		{
			x = spec.width - spec.tailWidth,
			y = y,
			width = spec.tailWidth,
			height = spec.tailHeight,
		},
	}
	return rects
end

--- S08 (08 §4.3) inside a `slot` sized slot; `rays` true for an Epic or Mythic trait.
function HudLayout.traitCard(slot: Size, rays: boolean?): MomentCardRects
	return momentCard(HudLayout.TRAIT_GAINED, slot, true, nil, rays)
end

export type GulpedRects = { swimAgain: Rect, swimAgainHit: Rect, title: Rect }

--- S11 stage 1 (08 §4.4): the title at the top centre and Swim again bottom right, in zone A.
function HudLayout.gulped(screenClass: ScreenClass, content: Size): GulpedRects
	local s = HudLayout.SWIM_AGAIN
	local swim = {
		x = content.width - s.right - s.width,
		y = content.height - s.bottom - s.height,
		width = s.width,
		height = s.height,
	}
	return {
		swimAgain = swim,
		swimAgainHit = HudLayout.hitRect(swim, HudLayout.minTarget(screenClass)),
		title = { x = (content.width - 640) / 2, y = 24, width = 640, height = 136 },
	}
end

-- 08 §4.5 step 5 and §5.2: the specimen card of S12 (build stage 2), right of the Pearls table.
-- Top to bottom inside 16 rpx padding: the 3D render, the tier row (badge and tier name), up to
-- three 32 rpx trait icons, the Pearls an hour line and the `bank.new_specimen` ribbon.
HudLayout.SPECIMEN_CARD = table.freeze({
	width = 300,
	height = 360,
	gap = 32, -- between the Pearls table and the card
	padding = 16,
	renderHeight = 150,
	tierHeight = 40,
	traitSize = 32,
	incomeHeight = 32,
	ribbonHeight = 40,
	rowGap = 8,
})

export type PearlsRects = {
	title: Rect,
	panel: Rect,
	continue: Rect,
	rowsTop: number,
	card: Rect?,
}

--- S12 (08 §4.5): the title, the Pearls table with `rows` multiplier rows (the mass row comes
--- first), Continue bottom right and, with `card` (stage 2), the specimen card right of the table.
--- The table and card are top-aligned and centred together; the title is centred over them.
function HudLayout.pearls(content: Size, rows: number, card: boolean?): PearlsRects
	local p = HudLayout.PEARLS
	local c = HudLayout.SPECIMEN_CARD
	local height = p.padding * 2
		+ p.headerHeight
		+ p.rowHeight * (1 + rows)
		+ p.dividerHeight
		+ p.totalHeight
	local continue = {
		x = content.width - HudLayout.SWIM_AGAIN.right - p.continueWidth,
		y = content.height - HudLayout.SWIM_AGAIN.bottom - p.continueHeight,
		width = p.continueWidth,
		height = p.continueHeight,
	}
	local rowWidth = if card then p.width + c.gap + c.width else p.width
	local rowHeight = if card then math.max(height, c.height) else height
	-- Centre the title and the row in the space above Continue's row, never above the top.
	local block = p.titleHeight + 16 + rowHeight
	local top = math.max(0, (continue.y - 16 - block) / 2)
	local x = (content.width - rowWidth) / 2
	local y = top + p.titleHeight + 16
	return {
		title = {
			x = (content.width - p.width) / 2,
			y = top,
			width = p.width,
			height = p.titleHeight,
		},
		panel = { x = x, y = y, width = p.width, height = height },
		continue = continue,
		rowsTop = p.padding + p.headerHeight,
		card = if card
			then { x = x + p.width + c.gap, y = y, width = c.width, height = c.height }
			else nil,
	}
end

-- 08 §5.1, the cove HUD (S14) at build stage 2: the Pearls, income and slots chips top centre
-- (`offset` is the chip centre's distance from the content centre), Claim all bottom right
-- above the dash button, and the dock bottom centre. Text sizes are 08 §1.5's.
HudLayout.COVE = table.freeze({
	top = 12,
	chipHeight = 56,
	pearls = { offset = -150, width = 240 },
	income = { offset = 90, width = 200 },
	slots = { offset = 270, width = 120 },
	plus = 44, -- the plus disc at the Pearls chip's right end; its hit area is the touch minimum
	claimAll = { right = 40, bottom = 196, width = 260, height = 88 },
	dock = { offset = -60, bottom = 28, size = 88, gap = 16, icon = 56 },
	-- Income and dock labels sit over the 3D world: Fredoka at 26 and 24 (UI review 1: Nunito 24
	-- and Small 22 read under the floor on the phone).
	text = table.freeze({ balance = 28, income = 26, slots = 28, claim = 28, dock = 24 }),
	-- 08 §5.1 world: the Pearl pile bubble over the clam.
	bubble = 72,
})
-- 08 §1.4 tablet switch: thumb elements sit 24 rpx further from the edges.
local TABLET_SHIFT = 24
-- What a pill button draws under its face (06 §12.2): the 4 rpx lip, the 5.3 rpx hard shadow and
-- half the panel stroke, rounded up. Claim all keeps 16 rpx plus this above the dash hit area,
-- so both the hit areas and the drawn shapes stay 16 rpx apart (08 §1.5).
HudLayout.BUTTON_DROP = 12

export type CoveRects = {
	pearls: Rect,
	plus: Rect,
	plusHit: Rect,
	income: Rect,
	slots: Rect,
	slotsHit: Rect,
	claimAll: Rect,
	claimAllHit: Rect,
	dock: { Rect },
	dash: Rect,
	dashHit: Rect,
}

--- S14 (08 §5.1): every rect of the cove HUD for one screen, with `dockCount` dock buttons
--- (stage 2 builds Creatures only; the MVP dock has four). The dash button is the run HUD's.
function HudLayout.cove(screenClass: ScreenClass, content: Size, dockCount: number): CoveRects
	local c = HudLayout.COVE
	local min = HudLayout.minTarget(screenClass)
	local function chip(spec: { offset: number, width: number }): Rect
		return {
			x = content.width / 2 + spec.offset - spec.width / 2,
			y = c.top,
			width = spec.width,
			height = c.chipHeight,
		}
	end
	local pearls = chip(c.pearls)
	local inset = (c.chipHeight - c.plus) / 2
	local plus = {
		x = pearls.x + pearls.width - inset - c.plus,
		y = pearls.y + inset,
		width = c.plus,
		height = c.plus,
	}
	local slots = chip(c.slots)
	local shift = if classKey(screenClass) == "Tablet" then TABLET_SHIFT else 0
	local a = c.claimAll
	local dash = HudLayout.dash(screenClass, content)
	local dashHit = HudLayout.hitRect(dash, min)
	-- 08 §5.1 puts it at {1, -196}; it rises further when the dash hit area would come within
	-- 16 rpx of its hit area or of its lip and shadow (on the phone: 208 above the bottom).
	local claimHitGrow = math.max(0, min - a.height) / 2
	local bottom = math.min(
		content.height - a.bottom - shift,
		dashHit.y - HudLayout.GAP_MIN - math.max(HudLayout.BUTTON_DROP, claimHitGrow)
	)
	local claimAll = {
		x = content.width - a.right - shift - a.width,
		y = bottom - a.height,
		width = a.width,
		height = a.height,
	}
	local d = c.dock
	local rowWidth = dockCount * d.size + math.max(0, dockCount - 1) * d.gap
	local dock: { Rect } = {}
	for i = 1, dockCount do
		table.insert(dock, {
			x = content.width / 2 + d.offset - rowWidth / 2 + (i - 1) * (d.size + d.gap),
			y = content.height - d.bottom - d.size,
			width = d.size,
			height = d.size,
		})
	end
	return {
		pearls = pearls,
		plus = plus,
		plusHit = HudLayout.hitRect(plus, min),
		income = chip(c.income),
		slots = slots,
		slotsHit = HudLayout.hitRect(slots, min),
		claimAll = claimAll,
		claimAllHit = HudLayout.hitRect(claimAll, min),
		dock = dock,
		dash = dash,
		dashHit = dashHit,
	}
end

-- 08 §7: the guide kit (S33) and chapter 04's prompts built from it (04 §3.2), on the `GulpGuide`
-- layer. Rects are content-box rpx like the rest of this module; the danger edge alone is in rpx
-- of the full screen (it reaches the physical edges). Sizes and timings are 08 §7's.
HudLayout.TEXT_FLOOR = 22 -- 08 §1.5: Small 22 is the smallest text anywhere
HudLayout.GUIDE = table.freeze({
	-- G1 arrow: 96 rpx, bobbing 12 rpx at 1.5 Hz along its own direction, 8 rpx off its target.
	arrow = 96,
	bob = 12,
	bobHz = 1.5,
	arrowGap = 8,
	-- Edge arrows (G1 for an off-screen target) ride the home marker's ellipse (08 §3.12).
	edgeInset = 72,
	-- G2 curved arrow.
	curved = 128,
	-- G3 hand and its loops (seconds).
	hand = 112,
	-- The hand presses the lower right of a tap target (UI review 1), so the button stays in
	-- sight: its fingertip sits this far right and down of the centre. A hold presses further out
	-- (UI review 2) and the hand shows at 60% while it is down, so the button reads through it.
	handOffset = 28,
	holdOffset = 44,
	holdHandOpacity = 0.6,
	tapDown = 0.12,
	tapUp = 0.38,
	tapPause = 0.5,
	dragTime = 0.8,
	-- The hold ring fills round the target, 20 rpx outside it and 12 thick, over the hand
	-- (UI review 2: a ring under the fingertip was hidden by the hand).
	holdRingPad = 20,
	holdRingWidth = 12,
	-- G4 trail: a dot every 12 studs, at most 12; chevrons flow at two dots a second, one per
	-- four dots; a dot fades out over the 3 studs after the creature passes it.
	trailDot = 48,
	trailChevron = 64,
	trailSpacing = 12,
	trailMax = 12,
	chevronRate = 2,
	chevronEvery = 4,
	trailFade = 3, -- studs past a dot over which it fades out
	trailNear = 30, -- studs from the camera within which a dot is drawn full size
	-- G5 ring: 16 rpx around its target (never under the 96 rpx source image), 160 round a
	-- point; pulses 1.0 to 1.15 at 1 Hz.
	ring = 160,
	ringMin = 96,
	ringPad = 16,
	ringPulse = 1.15,
	ringHz = 1,
	-- G6 cut-out: 50% dim, the hole 16 rpx round the target's hit area, corners 24.
	cutoutDim = 0.5,
	cutoutPad = 16,
	cutoutRadius = 24,
	-- G7 bubble: up to 420 wide, two lines of Body 24, 16 rpx padding; the tail is 24 x 16 and
	-- the bubble keeps 16 rpx from its target. With no target it uses `HUD.MomentSlot` (08 §3.3).
	bubbleMaxWidth = 420,
	bubbleText = 24,
	bubbleLines = 2,
	bubblePad = 16,
	bubbleLine = 32, -- one line of Body 24
	-- The bubble reads on bright scenes (UI review 1): a 4.5 rpx navy outline and a hard shadow
	-- 7 rpx down at 50%.
	bubbleStroke = 4.5,
	-- And outside it a 6 rpx white band with a 2 rpx navy edge (UI review 2), so it reads on dark
	-- water too; the tail is white like the band.
	bubbleOutline = 6,
	bubbleEdge = 2,
	bubbleShadow = 7,
	bubbleShadowTransparency = 0.5,
	bubbleGap = 16,
	tailWidth = 24,
	tailHeight = 16,
	momentTop = 130,
	momentHeight = 112,
	-- G8 input hint and G9 step tick.
	hint = 64,
	hintGap = 8,
	tick = 64,
	tickTime = 0.4,
	-- The tick sits on a top corner of the bubble, outside it but for this share of its size, so
	-- it stays in the bubble's padding, off the text (UI review 2).
	tickInset = 0.25,
	-- 08 §7 rules: in within 200 ms, out within 100 ms, a replay after 6 s with no input, and a
	-- 0.5 Hz fade instead of bobbing and pulsing with Less motion.
	appear = 0.2,
	clear = 0.1,
	idle = 6,
	bounce = 0.4,
	lessMotionHz = 0.5,
	-- 04 §3.2 ghost thumb (08 §7): a bright white thumbprint 144 rpx at 90% (UI review 2: 112 at
	-- 45% went grey on the sand), an 84 rpx drag (the drag ring's reach; 128 for the replay),
	-- every 1.6 s.
	ghost = 144,
	ghostOpacity = 0.9,
	ghostDrag = 84,
	ghostDragLong = 128,
	ghostLoop = 1.6,
	-- Its 5 rpx navy rim and soft shadow, and the drag cue: a white arrow with a navy edge from
	-- the press point to 24 rpx past the thumb's far edge at the drag's end, a 16 rpx shaft and a
	-- head 28 deep and 56 wide, so the direction reads while the thumb still sits on its start.
	ghostRim = 5,
	ghostRimOpacity = 0.9,
	ghostCueWidth = 16,
	ghostCueHead = 28,
	ghostCueReach = 24,
	-- The key row (04 §3.2): the mouse (64), the W cap and the four arrow caps (56 each, 4 apart)
	-- in one row 64 tall, 8 between the groups (UI review 2: the arrows were too small to read).
	ghostKeysWidth = 64 + 8 + 56 + 8 + 4 * 56 + 3 * 4,
	-- 04 §3.2 dash pulse: the button and a white ring 8 rpx outside it (a 10 rpx band) swell to
	-- 1.3x and back twice a second.
	dashPulse = 1.3,
	dashPulseHz = 2,
	dashRingPad = 8,
	dashRingBand = 10,
	-- 04 §3.3 HOME and DASH! chips.
	tagHeight = 32,
	tagText = 22,
	dashTagHeight = 40,
	dashTagText = 24,
	tagGap = 8,
	-- 04 §3.2 danger edge (08 §7): 96 rpx deep, 35% at the edge, out over 0.5 s.
	dangerDepth = 96,
	dangerOpacity = 0.35,
	dangerFade = 0.5,
	-- The edge leaves a gap round the home marker (16 rpx clear), its ends fading over 48 rpx.
	dangerSoftEnd = 48,
	-- Desktop draws the pointer, rings, chips, the ghost key row, and the bubble with its picture
	-- and tick 1.4x (tune): the desktop scale (deviceFactor 0.6, 08 §1.2) left them small in a
	-- window (UI reviews 1 and 2). The bubble's text is Body 24 inside the bubble's own size.
	desktop = 1.4,
})

--- The size factor of the guide's pointer, rings, chips, ghost key row and bubble on `screenClass`.
function HudLayout.guideScale(screenClass: ScreenClass): number
	return if screenClass == "Desktop" then HudLayout.GUIDE.desktop else 1
end

--- 08 §1.5 for the G7 bubble: Body 24 while its text takes at most two lines (`boundsY` is the
--- text's drawn height and `lineY` one line's, in the same units, at any scale); a longer
--- translation drops to Small 22.
function HudLayout.bubbleTextRpx(boundsY: number, lineY: number): number
	local g = HudLayout.GUIDE
	if lineY <= 0 then
		return g.bubbleText
	end
	local lines = math.floor(boundsY / lineY + 0.5)
	return if lines > g.bubbleLines then HudLayout.TEXT_FLOOR else g.bubbleText
end

local function box(content: Size): Rect
	return { x = 0, y = 0, width = content.width, height = content.height }
end

local function within(inner: Rect, outer: Rect): boolean
	return inner.x >= outer.x - 1e-6
		and inner.y >= outer.y - 1e-6
		and inner.x + inner.width <= outer.x + outer.width + 1e-6
		and inner.y + inner.height <= outer.y + outer.height + 1e-6
end

local function centredRect(x: number, y: number, width: number, height: number): Rect
	return { x = x - width / 2, y = y - height / 2, width = width, height = height }
end

-- True when `rect` clears every `avoid` rect by `gap`, skipping the ones that share area with
-- `own` (the target itself and its hit area).
local function clearOf(rect: Rect, avoid: { Rect }, gap: number, own: Rect?): boolean
	for _, r in avoid do
		local mine = own ~= nil and HudLayout.overlaps(r, own)
		if not mine and HudLayout.overlaps(rect, HudLayout.grow(r, gap)) then
			return false
		end
	end
	return true
end

-- 08 §7 rule: prompts never cover the keep-clear box, unless their target is in it (a world
-- target beside the creature), when only the HUD is kept clear.
local function clearOfBox(rect: Rect, content: Size, target: Rect?): boolean
	local kc = HudLayout.keepClear(content)
	if target and HudLayout.overlaps(HudLayout.grow(target, 1e-6), kc) then
		return true
	end
	return not HudLayout.overlaps(rect, kc)
end

--- G5: the highlight ring round `target` (a zero-sized rect is a point); `k` is
--- `guideScale` (the gap round a target and a point's ring grow with it).
function HudLayout.guideRing(target: Rect, k: number?): Rect
	local g = HudLayout.GUIDE
	local f = k or 1
	local cx, cy = target.x + target.width / 2, target.y + target.height / 2
	if target.width <= 0 and target.height <= 0 then
		return centredRect(cx, cy, g.ring * f, g.ring * f)
	end
	return centredRect(
		cx,
		cy,
		math.max(target.width + 2 * g.ringPad * f, g.ringMin),
		math.max(target.height + 2 * g.ringPad * f, g.ringMin)
	)
end

--- G6: the cut-out's hole, the target's hit area (at least the touch or mouse minimum, 08 §1.5)
--- grown by 16 rpx, so every tap the target takes lands in the hole.
function HudLayout.guideCutout(target: Rect, screenClass: ScreenClass): Rect
	local hit = HudLayout.hitRect(target, HudLayout.minTarget(screenClass))
	return HudLayout.grow(hit, HudLayout.GUIDE.cutoutPad)
end

--- The rect an arrow centred at (x, y) can take while it bobs, `k` times its size.
function HudLayout.arrowRect(x: number, y: number, k: number?): Rect
	local g = HudLayout.GUIDE
	local side = (g.arrow + 2 * g.bob) * (k or 1)
	return centredRect(x, y, side, side)
end

-- Directions tried for an arrow beside its target, nearest the way to the centre first.
local ARROW_DIRECTIONS = 16

--- G1 beside an on-screen `target`: the arrow sits on the side facing the centre of the screen
--- (the nearest direction that keeps it inside the content box, off the keep-clear box and clear
--- of every `avoid` rect by 8 rpx) and points at the target. Returns its centre and the angle it
--- points along (radians, screen space: 0 right, π/2 down).
function HudLayout.guideArrow(
	target: Rect,
	content: Size,
	avoid: { Rect },
	k: number?
): (number, number, number)
	local g = HudLayout.GUIDE
	local cx, cy = target.x + target.width / 2, target.y + target.height / 2
	local dx, dy = content.width / 2 - cx, content.height / 2 - cy
	local toward = if math.abs(dx) + math.abs(dy) < 1 then -math.pi / 2 else math.atan2(dy, dx)
	local order: { number } = {}
	for i = 0, ARROW_DIRECTIONS - 1 do
		table.insert(order, toward + i * 2 * math.pi / ARROW_DIRECTIONS)
	end
	local function gap(a: number): number
		local d = math.abs((a - toward + math.pi) % (2 * math.pi) - math.pi)
		return d
	end
	table.sort(order, function(a: number, b: number)
		return gap(a) < gap(b)
	end)
	local area = box(content)
	local clearTarget = HudLayout.grow(target, g.arrowGap)
	local first: { number }? = nil
	for _, a in order do
		local ux, uy = math.cos(a), math.sin(a)
		-- Walk out from the target's centre until the bobbing arrow clears it by 8 rpx.
		local x, y = cx, cy
		for step = 0, 200 do
			x, y = cx + ux * step * 4, cy + uy * step * 4
			if not HudLayout.overlaps(HudLayout.arrowRect(x, y, k), clearTarget) then
				break
			end
		end
		local rect = HudLayout.arrowRect(x, y, k)
		local pointing = a + math.pi
		if first == nil then
			first = { x, y, pointing }
		end
		if
			within(rect, area)
			and clearOfBox(rect, content, target)
			and clearOf(rect, avoid, g.arrowGap, target)
		then
			return x, y, pointing
		end
	end
	local f = first :: { number } -- safe: the loop runs at least once
	return f[1], f[2], f[3]
end

--- The point at `angle` (radians, from the centre) on the ellipse `inset` rpx inside `content`.
function HudLayout.onEllipse(content: Size, angle: number, inset: number): (number, number)
	local ax = math.max(0, content.width / 2 - inset)
	local ay = math.max(0, content.height / 2 - inset)
	return content.width / 2 + ax * math.cos(angle), content.height / 2 + ay * math.sin(angle)
end

--- G1 for an off-screen target: on the 72 rpx ellipse toward it (like `HUD.Home`, 08 §3.12;
--- `k` times further in for a `k` times larger arrow), slid the shortest way until it clears
--- every `avoid` rect by 16 rpx. Returns its centre and the angle it points along (outward).
function HudLayout.guideEdgeArrow(
	content: Size,
	angle: number,
	avoid: { Rect },
	k: number?
): (number, number, number)
	local inset = HudLayout.GUIDE.edgeInset * (k or 1)
	local steps = math.ceil(math.pi / HOME_SLIDE_STEP)
	for i = 0, steps do
		for _, sign in { 1, -1 } do
			local a = angle + sign * i * HOME_SLIDE_STEP
			local x, y = HudLayout.onEllipse(content, a, inset)
			if clearOf(HudLayout.arrowRect(x, y, k), avoid, HudLayout.GAP_MIN) then
				return x, y, angle
			end
		end
	end
	local x, y = HudLayout.onEllipse(content, angle, inset)
	return x, y, angle
end

export type BubbleSide = "above" | "below" | "left" | "right" | "slot"
export type BubblePlace = {
	rect: Rect,
	-- Where the bubble sits from its target; its tail points the other way. "slot" has no tail.
	side: BubbleSide,
	-- The tail's centre along the bubble edge facing the target (content rpx).
	tailX: number,
	tailY: number,
	-- True when the bubble could not sit by its target: the curved arrow (G2) joins them.
	curved: boolean,
}

local BUBBLE_VERTICAL: { BubbleSide } = { "above", "below" }
local BUBBLE_SIDEWAYS: { BubbleSide } = { "right", "left" }

--- `HUD.MomentSlot` (08 §3.3, §4.1) for a bubble of `size`: top centre, 130 rpx down, raised
--- when it must so its bottom stays 8 rpx over the keep-clear box (P4: moments stay above it),
--- but never onto the mass bar.
function HudLayout.momentSlot(content: Size, size: Size): Rect
	local g = HudLayout.GUIDE
	local kc = HudLayout.keepClear(content)
	local floor = HudLayout.MASS_BAR.top + HudLayout.MASS_BAR.height + g.hintGap
	local y = math.max(floor, math.min(g.momentTop, kc.y - g.hintGap - size.height))
	return {
		x = (content.width - size.width) / 2,
		y = y,
		width = size.width,
		height = size.height,
	}
end

--- G7: where a bubble of `size` goes for `target` (nil: the creature, so the moment slot). Tries
--- above the target, then below, then right and left, each centred on the target or slid just
--- off the keep-clear box, and takes the first that stays in the content box, off the keep-clear
--- box and 8 rpx clear of every `avoid` rect (the HUD and the pointer), with its tail still over
--- the target. If none fits, the moment slot and a curved arrow (G2).
function HudLayout.guideBubble(
	size: Size,
	target: Rect?,
	content: Size,
	avoid: { Rect }
): BubblePlace
	local g = HudLayout.GUIDE
	local slot = HudLayout.momentSlot(content, size)
	if target == nil then
		return {
			rect = slot,
			side = "slot",
			tailX = slot.x + slot.width / 2,
			tailY = slot.y + slot.height,
			curved = false,
		}
	end
	local t = target :: Rect
	local area = box(content)
	local kc = HudLayout.keepClear(content)
	local away = g.bubbleGap + g.tailHeight
	local tcx, tcy = t.x + t.width / 2, t.y + t.height / 2
	local w, h = size.width, size.height
	local inset = g.tailWidth -- the tail keeps clear of the rounded corners
	local candidates: { BubblePlace } = {}
	local function add(side: string, x: number, y: number)
		local rx = math.clamp(x, 0, math.max(0, content.width - w))
		local ry = math.clamp(y, 0, math.max(0, content.height - h))
		local rect = { x = rx, y = ry, width = w, height = h }
		local tailX, tailY
		if side == "above" or side == "below" then
			if tcx < rx + inset or tcx > rx + w - inset then
				return -- the tail would miss the target
			end
			tailX, tailY = tcx, if side == "above" then ry + h else ry
		else
			if tcy < ry + inset or tcy > ry + h - inset then
				return
			end
			tailX, tailY = if side == "left" then rx + w else rx, tcy
		end
		table.insert(candidates, {
			rect = rect,
			side = (side :: any) :: BubbleSide,
			tailX = tailX,
			tailY = tailY,
			curved = false,
		})
	end
	for _, side in BUBBLE_VERTICAL do
		local y = if side == "above" then t.y - away - h else t.y + t.height + away
		add(side, tcx - w / 2, y)
		add(side, kc.x + kc.width + g.bubbleGap, y)
		add(side, kc.x - g.bubbleGap - w, y)
	end
	for _, side in BUBBLE_SIDEWAYS do
		local x = if side == "right" then t.x + t.width + away else t.x - away - w
		add(side, x, tcy - h / 2)
		add(side, x, kc.y + kc.height + g.bubbleGap)
		add(side, x, kc.y - g.bubbleGap - h)
	end
	for _, c in candidates do
		if
			within(c.rect, area)
			and clearOfBox(c.rect, content, t)
			and clearOf(c.rect, avoid, g.hintGap, t)
			and not HudLayout.overlaps(c.rect, HudLayout.grow(t, g.bubbleGap - 1e-6))
		then
			return c
		end
	end
	return {
		rect = slot,
		side = "slot",
		tailX = slot.x + slot.width / 2,
		tailY = slot.y + slot.height,
		curved = true,
	}
end

--- G2: the curved arrow at the end of `bubble` nearest `target`, outside it and above the
--- keep-clear box, turned toward the target. Returns its centre and the angle it points along.
function HudLayout.guideCurved(bubble: Rect, target: Rect, content: Size): (number, number, number)
	local g = HudLayout.GUIDE
	local kc = HudLayout.keepClear(content)
	local tcx, tcy = target.x + target.width / 2, target.y + target.height / 2
	local right = tcx >= bubble.x + bubble.width / 2
	local half = g.curved / 2
	local x = if right
		then bubble.x + bubble.width + g.hintGap + half
		else bubble.x - g.hintGap - half
	local y = bubble.y + bubble.height / 2
	if bubble.y + bubble.height <= kc.y then
		y = math.min(y, kc.y - half)
	end
	x = math.clamp(x, half, math.max(half, content.width - half))
	y = math.clamp(y, half, math.max(half, content.height - half))
	return x, y, math.atan2(tcy - y, tcx - x)
end

--- The rect the curved arrow takes, centred at (x, y).
function HudLayout.curvedRect(x: number, y: number): Rect
	local s = HudLayout.GUIDE.curved
	return centredRect(x, y, s, s)
end

--- How far a bubble's outline reaches past its panel (`k` times on desktop): the navy stroke, the
--- white band and its navy edge. A bubble's rect in this module is the whole of it.
function HudLayout.bubbleFrame(k: number?): number
	local g = HudLayout.GUIDE
	return (g.bubbleStroke + g.bubbleOutline + g.bubbleEdge) * (k or 1)
end

--- The rect a bubble's text can take: inside its outline and padding (16 rpx at the sides, 8
--- above and below, all `k` times on desktop).
function HudLayout.bubbleTextRect(bubble: Rect, k: number?): Rect
	local g = HudLayout.GUIDE
	local f = k or 1
	local side = HudLayout.bubbleFrame(f) + g.bubblePad * f
	local top = HudLayout.bubbleFrame(f) + g.bubblePad / 2 * f
	return {
		x = bubble.x + side,
		y = bubble.y + top,
		width = math.max(0, bubble.width - 2 * side),
		height = math.max(0, bubble.height - 2 * top),
	}
end

--- G9: the step tick (`k` times its size) on the bubble's top right corner, outside it but for
--- `tickInset` of its size, so it stays in the outline, off the text. The top left corner when the
--- right one leaves the content box or comes within 8 rpx of an `avoid` rect (the curved arrow,
--- the HUD, the keep-clear box), then the bottom corners, then the middle of either end.
function HudLayout.guideTick(bubble: Rect, k: number?, content: Size?, avoid: { Rect }?): Rect
	local g = HudLayout.GUIDE
	local s = g.tick * (k or 1)
	local inset = s * g.tickInset
	local top = bubble.y + inset - s
	local bottom = bubble.y + bubble.height - inset
	local middle = bubble.y + (bubble.height - s) / 2
	local right = bubble.x + bubble.width - inset
	local left = bubble.x + inset - s
	local candidates = {
		{ x = right, y = top, width = s, height = s },
		{ x = left, y = top, width = s, height = s },
		{ x = right, y = bottom, width = s, height = s },
		{ x = left, y = bottom, width = s, height = s },
		{ x = right, y = middle, width = s, height = s },
		{ x = left, y = middle, width = s, height = s },
	}
	for _, rect in candidates do
		local fits = content == nil or within(rect, box(content :: Size))
		if fits and clearOf(rect, avoid or {}, g.hintGap) then
			return rect
		end
	end
	return candidates[1]
end

--- 04 §3.2 ghost thumb: the press point at lower centre, halfway between the keep-clear box and
--- the bottom of the content box.
function HudLayout.ghostThumb(content: Size): (number, number)
	local kc = HudLayout.keepClear(content)
	local bottom = kc.y + kc.height
	return content.width / 2, bottom + (content.height - bottom) / 2
end

--- Where the ghost thumb's drag ends: 84 rpx (128 when `long`) from (x, y) along `angle`, held
--- so the whole thumb stays in the content box. The drag is the one prompt that may cross into
--- the keep-clear box (08 §7); it starts under it.
function HudLayout.ghostDrag(
	content: Size,
	x: number,
	y: number,
	angle: number,
	long: boolean?
): (number, number)
	local g = HudLayout.GUIDE
	local length = if long then g.ghostDragLong else g.ghostDrag
	local half = g.ghost / 2
	local ex = x + math.cos(angle) * length
	local ey = y + math.sin(angle) * length
	ex = math.clamp(ex, half, math.max(half, content.width - half))
	ey = math.clamp(ey, half, math.max(half, content.height - half))
	return ex, ey
end

--- 04 §3.2 the ghost thumb's drag cue: the tip of its arrow, from the press point (x, y) past the
--- drag's end (ex, ey) by half the thumb and `ghostCueReach`, kept in the content box.
function HudLayout.ghostCueTip(
	content: Size,
	x: number,
	y: number,
	ex: number,
	ey: number
): (number, number)
	local g = HudLayout.GUIDE
	local dx, dy = ex - x, ey - y
	local length = math.sqrt(dx * dx + dy * dy)
	if length < 1e-6 then
		return ex, ey
	end
	local reach = g.ghost / 2 + g.ghostCueReach
	local tx = ex + dx / length * reach
	local ty = ey + dy / length * reach
	return math.clamp(tx, 0, content.width), math.clamp(ty, 0, content.height)
end

--- The rect of the ghost thumb (touch) or of its key row (keys: `width` x 64, both `k` times)
--- centred at (x, y).
function HudLayout.ghostRect(x: number, y: number, width: number?, k: number?): Rect
	local g = HudLayout.GUIDE
	if width then
		local f = k or 1
		return centredRect(x, y, width * f, g.hint * f)
	end
	return centredRect(x, y, g.ghost, g.ghost)
end

--- 04 §3.2 ghost thumb with keys or a pad: the row of `width` x `height` at the ghost point,
--- slid sideways the shortest way (8 rpx steps) until it stays in the content box, off the
--- keep-clear box and 16 rpx clear of every `avoid` rect (the HUD, the dock and its labels, the
--- trait slots). Returns its centre.
function HudLayout.ghostKeys(
	content: Size,
	width: number,
	height: number,
	avoid: { Rect }
): (number, number)
	local x0, y = HudLayout.ghostThumb(content)
	local area = box(content)
	local kc = HudLayout.keepClear(content)
	local reach = math.ceil(content.width / 8)
	for i = 0, reach do
		for _, sign in (if i == 0 then { 1 } else { -1, 1 }) :: { number } do
			local x = x0 + sign * i * 8
			local rect = centredRect(x, y, width, height)
			if
				within(rect, area)
				and not HudLayout.overlaps(rect, kc)
				and clearOf(rect, avoid, HudLayout.GAP_MIN)
			then
				return x, y
			end
		end
	end
	return x0, y
end

--- G3 tap and hold: where the fingertip presses `target`, right of and below its centre (by
--- `handOffset`, `holdOffset` for a hold; held inside the target), so the target stays in sight.
function HudLayout.handPoint(target: Rect, hold: boolean?): (number, number)
	local g = HudLayout.GUIDE
	local o = if hold then g.holdOffset else g.handOffset
	local cx, cy = target.x + target.width / 2, target.y + target.height / 2
	local dx = math.min(o, target.width / 2)
	local dy = math.min(o, target.height / 2)
	return cx + dx, cy + dy
end

--- 04 §3.3 HOME: a chip of `width` under the home marker's distance chip at (x, y), or above the
--- marker's pointer orbit when there is no room under it (or the space is taken by an `avoid`
--- rect), kept in the content box.
function HudLayout.homeTag(
	x: number,
	y: number,
	width: number,
	content: Size,
	avoid: { Rect },
	k: number?
): Rect
	local g = HudLayout.GUIDE
	local h = HudLayout.HOME
	local height = g.tagHeight * (k or 1)
	local under = y + h.size / 2 + HudLayout.HOME_CHIP_GAP + h.labelHeight + HudLayout.HOME_CHIP_GAP
	local over = y - HudLayout.HOME_REACH - HudLayout.HOME_CHIP_GAP - height
	local area = box(content)
	local first: Rect? = nil
	for _, top in { under, over } do
		local rect = {
			x = math.clamp(x - width / 2, 0, math.max(0, content.width - width)),
			y = top,
			width = width,
			height = height,
		}
		first = first or rect
		if within(rect, area) and clearOf(rect, avoid, g.hintGap) then
			return rect
		end
	end
	local r = first :: Rect -- safe: set on the first pass
	r.y = math.clamp(r.y, 0, math.max(0, content.height - height))
	return r
end

--- G3 hold: the ring that fills round `target` while the hand is down, a circle `holdRingPad`
--- (`k` times) outside the target's larger side.
function HudLayout.holdRing(target: Rect, k: number?): Rect
	local g = HudLayout.GUIDE
	local side = math.max(target.width, target.height) + 2 * g.holdRingPad * (k or 1)
	return centredRect(target.x + target.width / 2, target.y + target.height / 2, side, side)
end

--- 04 §3.2 dash pulse: the white ring round the dash button or tile (`k` times further out).
function HudLayout.dashRing(dash: Rect, k: number?): Rect
	return HudLayout.grow(dash, HudLayout.GUIDE.dashRingPad * (k or 1))
end

--- 04 §3.3 DASH!: a chip of `width` centred over the dash button, clear of the ring at its
--- largest, kept in the content box.
function HudLayout.dashTag(dash: Rect, width: number, content: Size, k: number?): Rect
	local g = HudLayout.GUIDE
	local f = k or 1
	local ring = HudLayout.dashRing(dash, f)
	local swell = ring.height * (g.dashPulse - 1) / 2
	local bottom = ring.y - swell - g.tagGap * f
	local height = g.dashTagHeight * f
	return {
		x = math.clamp(dash.x + dash.width / 2 - width / 2, 0, math.max(0, content.width - width)),
		y = bottom - height,
		width = width,
		height = height,
	}
end

export type Side = "left" | "right" | "top" | "bottom"

--- The screen edge a threat at `angle` (radians from the centre of a `full` screen) lies past.
function HudLayout.dangerSide(angle: number, full: Size): Side
	local c, s = math.cos(angle), math.sin(angle)
	local tx = if math.abs(c) > 1e-9 then (full.width / 2) / math.abs(c) else math.huge
	local ty = if math.abs(s) > 1e-9 then (full.height / 2) / math.abs(s) else math.huge
	if tx <= ty then
		return if c >= 0 then "right" else "left"
	end
	return if s >= 0 then "bottom" else "top"
end

--- 04 §3.2 danger edge: the glow along `side` of a `full` screen, in full-screen rpx.
function HudLayout.dangerEdge(side: Side, full: Size): Rect
	local d = HudLayout.GUIDE.dangerDepth
	if side == "left" then
		return { x = 0, y = 0, width = d, height = full.height }
	elseif side == "right" then
		return { x = full.width - d, y = 0, width = d, height = full.height }
	elseif side == "top" then
		return { x = 0, y = 0, width = full.width, height = d }
	end
	return { x = 0, y = full.height - d, width = full.width, height = d }
end

export type DangerPiece = { rect: Rect, softStart: boolean, softEnd: boolean }

--- 04 §3.2 danger edge with gaps: the glow along `side` of a `full` screen (full-screen rpx),
--- cut where it would run under an `avoid` rect (the home marker, its ring and HOME chip) with
--- 16 rpx to spare. Each piece says which of its ends (top or left first) is a cut, to fade.
function HudLayout.dangerPieces(side: Side, full: Size, avoid: { Rect }): { DangerPiece }
	local edge = HudLayout.dangerEdge(side, full)
	local vertical = side == "left" or side == "right"
	local lo = if vertical then edge.y else edge.x
	local hi = lo + (if vertical then edge.height else edge.width)
	local cuts: { { number } } = {}
	for _, r in avoid do
		local grown = HudLayout.grow(r, HudLayout.GAP_MIN)
		if HudLayout.overlaps(grown, edge) then
			local a = if vertical then grown.y else grown.x
			local b = a + (if vertical then grown.height else grown.width)
			table.insert(cuts, { math.max(lo, a), math.min(hi, b) })
		end
	end
	table.sort(cuts, function(p: { number }, q: { number }): boolean
		return p[1] < q[1]
	end)
	local pieces: { DangerPiece } = {}
	local at, soft = lo, false
	local function add(to: number, cutAfter: boolean)
		if to - at > 1 then
			local rect = if vertical
				then { x = edge.x, y = at, width = edge.width, height = to - at }
				else { x = at, y = edge.y, width = to - at, height = edge.height }
			table.insert(pieces, { rect = rect, softStart = soft, softEnd = cutAfter })
		end
	end
	for _, c in cuts do
		if c[2] > at then
			add(c[1], true)
			at, soft = math.max(at, c[2]), true
		end
	end
	add(hi, false)
	return pieces
end

--- G4: which trail dots show. Dots sit every 12 studs from the trail's start to its end
--- (`length` studs; the last one on the target). The creature is `progress` studs along it:
--- the dots it has passed are gone and at most 12 ahead of it show. Returns the first and last
--- dot numbers (1 is 12 studs from the start); `first > last` when none are left.
function HudLayout.trailWindow(length: number, progress: number): (number, number)
	local g = HudLayout.GUIDE
	local count = math.max(1, math.ceil(length / g.trailSpacing - 1e-6))
	local first = math.max(1, math.floor(progress / g.trailSpacing) + 1)
	return first, math.min(count, first + g.trailMax - 1)
end

--- The distance in studs of trail dot `k` along a trail of `length` studs (the last one sits on
--- the target).
function HudLayout.trailDot(k: number, length: number): number
	return math.min(k * HudLayout.GUIDE.trailSpacing, length)
end

-- 08 §3.3 and §3.6, `HUD.Traits`: three 80 rpx slots bottom centre, 28 rpx above the content
-- box's bottom, each with an 88 rpx hit area and a 56 rpx icon. The gap is 24 so the hit areas
-- keep 08 §1.5's 16 rpx apart (14 §4 entry 32). The pips sit on an arc above each slot: 14 rpx
-- dots whose centres are 50 rpx from the slot's centre, 24° apart, centred on 12 o'clock.
HudLayout.TRAITS = table.freeze({
	bottom = 28,
	slot = 80,
	gap = 24,
	icon = 56,
	pip = 14,
	pipRadius = 50,
	pipStep = math.rad(24),
})

-- 08 §3.3 and §3.10, `HUD.TraitMarkers`: 44 rpx markers, the trait icon at 28; off screen the
-- marker's centre is clamped 40 rpx inside the content box.
HudLayout.TRAIT_MARKER = table.freeze({ size = 44, icon = 28, inset = 40 })

export type TraitRects = {
	row: Rect, -- the three slots and their gaps
	slots: { Rect },
	hits: { Rect },
}

--- `HUD.Traits` (08 §3.3, §3.6) for one screen: the row, each slot and each slot's hit area.
--- The same on every screen class (the desktop key caps under the slots are a later stage).
function HudLayout.traits(screenClass: ScreenClass, content: Size): TraitRects
	local t = HudLayout.TRAITS
	local min = HudLayout.minTarget(screenClass)
	local width = 3 * t.slot + 2 * t.gap
	local x0 = (content.width - width) / 2
	local y = content.height - t.bottom - t.slot
	local slots: { Rect } = {}
	local hits: { Rect } = {}
	for i = 1, 3 do
		local slot = { x = x0 + (i - 1) * (t.slot + t.gap), y = y, width = t.slot, height = t.slot }
		table.insert(slots, slot)
		table.insert(hits, HudLayout.hitRect(slot, min))
	end
	return { row = { x = x0, y = y, width = width, height = t.slot }, slots = slots, hits = hits }
end

--- The centres of `count` pips (5, or 4 with Keen Nose) on the arc above a slot whose rect is
--- `slot`, left to right, in the slot rect's space.
function HudLayout.traitPips(slot: Rect, count: number): { { x: number, y: number } }
	local t = HudLayout.TRAITS
	local cx, cy = slot.x + slot.width / 2, slot.y + slot.height / 2
	local pips = {}
	for i = 1, count do
		local a = -math.pi / 2 + (i - (count + 1) / 2) * t.pipStep
		table.insert(
			pips,
			{ x = cx + t.pipRadius * math.cos(a), y = cy + t.pipRadius * math.sin(a) }
		)
	end
	return pips
end

--- The rect every pip of a slot can take (the arc of five), for the layout checks.
function HudLayout.traitPipsRect(slot: Rect): Rect
	local half = HudLayout.TRAITS.pip / 2
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for _, p in HudLayout.traitPips(slot, 5) do
		x0, y0 = math.min(x0, p.x - half), math.min(y0, p.y - half)
		x1, y1 = math.max(x1, p.x + half), math.max(y1, p.y + half)
	end
	return { x = x0, y = y0, width = x1 - x0, height = y1 - y0 }
end

--- An off-screen trait prey marker (08 §3.10): the point where the ray from the content centre
--- at `angle` (radians, screen space: 0 points right, π/2 down) meets the rect 40 rpx inside the
--- content box.
function HudLayout.traitMarkerEdge(content: Size, angle: number): (number, number)
	local inset = HudLayout.TRAIT_MARKER.inset
	local ax = math.max(0, content.width / 2 - inset)
	local ay = math.max(0, content.height / 2 - inset)
	local c, s = math.cos(angle), math.sin(angle)
	local tx = if math.abs(c) > 1e-9 then ax / math.abs(c) else math.huge
	local ty = if math.abs(s) > 1e-9 then ay / math.abs(s) else math.huge
	local t = math.min(tx, ty)
	return content.width / 2 + t * c, content.height / 2 + t * s
end

return table.freeze(HudLayout)
