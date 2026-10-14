--!strict
-- HudLayout: the pure geometry of the run HUD stage 1 and of screens S11 and S12 (docs/08,
-- sections 1.3 to 1.5, 3.3, 3.12, 3.16, 4.4 and 4.5; docs/15, sections 3.1 to 3.3). Numbers and
-- tables only, so it runs in Lune; `client/UI` places instances where this module says.
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

-- 08 §4.5, the Pearls table of S12 (stage 1: the specimen column is not built, so the table is
-- centred). Row heights follow the type sizes of 08 §1.5 on the 8 rpx grid.
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

--- The rect the home marker and its distance label take with the marker centred on (x, y).
function HudLayout.homeRect(x: number, y: number): Rect
	local h = HudLayout.HOME
	return {
		x = x - h.size / 2,
		y = y - h.size / 2,
		width = h.size,
		height = h.size + h.labelHeight,
	}
end

--- The off-screen home marker (08 §3.12): on the ellipse in the direction of home, slid along it
--- the shortest way until the marker and its label clear every `avoid` rect by 16 rpx.
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

export type PearlsRects = { title: Rect, panel: Rect, continue: Rect, rowsTop: number }

--- S12 stage 1 (08 §4.5): the title, the Pearls table with `rows` multiplier rows (the mass row
--- comes first) and Continue bottom right.
function HudLayout.pearls(content: Size, rows: number): PearlsRects
	local p = HudLayout.PEARLS
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
	-- Centre the title and panel in the space above Continue's row, never above the top.
	local block = p.titleHeight + 16 + height
	local top = math.max(0, (continue.y - 16 - block) / 2)
	local x = (content.width - p.width) / 2
	return {
		title = { x = x, y = top, width = p.width, height = p.titleHeight },
		panel = { x = x, y = top + p.titleHeight + 16, width = p.width, height = height },
		continue = continue,
		rowsTop = p.padding + p.headerHeight,
	}
end

return table.freeze(HudLayout)
