--!strict
-- HudLayout: the pure geometry of the run HUD stage 1 and of screens S07, S08, S11, S12 and
-- S14 (docs/08, sections 1.3 to 1.5, 3.3, 3.12, 3.16, 4.1 to 4.5 and 5.1; docs/15, sections 3.1
-- to 3.3). Numbers and tables only, so it runs in Lune; `client/UI` places instances where this
-- module says.
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

--- `HUD.MomentSlot` (08 §3.3) in content rpx: centred, 130 rpx from the top.
function HudLayout.momentSlot(content: Size): Rect
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
	raysClip: Rect, -- where the rays may show: as wide as the burst, centred on the art, from the
	-- bank chip's bottom to the card's (08 §4.1: past the sides and up, never below the card)
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
	local slotTop = HudLayout.MOMENT_SLOT.top + HudLayout.CARD_TOP
	local above = slotTop - (HudLayout.BANK_CHIP.top + HudLayout.BANK_CHIP.height)
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
		raysClip = { x = cx - r, y = -above, width = 2 * r, height = spec.height + above },
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
