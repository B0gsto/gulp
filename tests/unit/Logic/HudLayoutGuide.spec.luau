--!strict
-- The guide kit's layout rules (docs/08 sections 1.4, 1.5 and 7; docs/04 section 3.2) on every
-- screen class: inside the safe frame, never on the keep-clear box, never over the HUD, hit
-- areas kept whole by the cut-out, and no text under the floor.
local HudLayout = require("../../../src/shared/Logic/HudLayout")
local ScreenScale = require("../../../src/shared/Logic/ScreenScale")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type Rect = HudLayout.Rect
type Layout = ScreenScale.Layout

local function reading(touch: boolean, keyboard: boolean, w: number, h: number): ScreenScale.Reading
	return {
		displaySize = "Medium",
		viewportWidth = w,
		viewportHeight = h,
		touch = touch,
		keyboard = keyboard,
		mouse = keyboard,
		gamepad = false,
	}
end

local function screen(r: ScreenScale.Reading, insetX: number): Layout
	local w, h = r.viewportWidth, r.viewportHeight
	local safe = { x = insetX, y = 0, width = w - 2 * insetX, height = h }
	local topbar = { x = 120, y = 0, width = w - 120, height = 58 }
	return ScreenScale.compute(r, { width = w, height = h }, safe, topbar, 1)
end

-- The screen classes of docs/15 section 2.2 at the sizes of sections 3.1 to 3.3.
local SCREENS: { [string]: Layout } = {
	["small phone 667 x 375"] = screen(reading(true, false, 667, 375), 0),
	["large phone 932 x 430"] = screen(reading(true, false, 932, 430), 47),
	["tablet 1024 x 768"] = screen(reading(true, false, 1024, 768), 0),
	["desktop 1920 x 1080"] = screen(reading(false, true, 1920, 1080), 0),
	["narrow desktop 1024 x 768"] = screen(reading(false, true, 1024, 768), 0),
	["ultrawide 2560 x 1080"] = screen(reading(false, true, 2560, 1080), 0),
}

local function inside(inner: Rect, outer: Rect): boolean
	return inner.x >= outer.x - 1e-6
		and inner.y >= outer.y - 1e-6
		and inner.x + inner.width <= outer.x + outer.width + 1e-6
		and inner.y + inner.height <= outer.y + outer.height + 1e-6
end

local function centred(x: number, y: number, w: number, h: number): Rect
	return { x = x - w / 2, y = y - h / 2, width = w, height = h }
end

local g = HudLayout.GUIDE
-- The tallest bubble: two lines of Body 24, its padding and its outline.
local BUBBLE_MAX = g.bubbleLines * g.bubbleLine + g.bubblePad + 2 * HudLayout.bubbleFrame()

describe("Guide kit layout on every screen class (docs/08 section 7)", function()
	for name, layout in SCREENS do
		local content = layout.contentSize
		local area = { x = 0, y = 0, width = content.width, height = content.height }
		local rects = HudLayout.compute(layout.screenClass, content, layout.keepOut)
		local min = HudLayout.minTarget(layout.screenClass)
		-- Desktop draws the pointer, rings, chips and key row larger (08 §7).
		local k = HudLayout.guideScale(layout.screenClass)
		local abilityHit = HudLayout.hitRect(rects.ability, min)
		-- The HUD the guide must stay off, and the targets chapter 04 points at.
		local hud = { rects.massBar, rects.dashHit, abilityHit }
		for _, k in layout.keepOut do
			table.insert(hud, k)
		end
		local targets: { [string]: Rect } = {
			dash = rects.dash,
			massBar = rects.massBar,
			ability = rects.ability,
		}

		for tname, target in targets do
			it(
				`{name}: the arrow at {tname} stays in the frame, off the keep-clear box and the HUD`,
				function()
					local x, y, angle = HudLayout.guideArrow(target, content, hud, k)
					local rect = HudLayout.arrowRect(x, y, k)
					expect(inside(rect, area)).toBe(true)
					expect(HudLayout.overlaps(rect, rects.keepClear)).toBe(false)
					expect(HudLayout.overlaps(rect, target)).toBe(false)
					for _, r in hud do
						if not HudLayout.overlaps(r, target) then
							expect(HudLayout.overlaps(rect, r)).toBe(false)
						end
					end
					-- It points at the target.
					local tx, ty = target.x + target.width / 2, target.y + target.height / 2
					local want = math.atan2(ty - y, tx - x)
					local diff = math.abs((angle - want + math.pi) % (2 * math.pi) - math.pi)
					expect(diff < math.rad(25)).toBe(true)
				end
			)

			it(
				`{name}: the bubble for {tname} clears the keep-clear box, the HUD and the arrow`,
				function()
					local x, y = HudLayout.guideArrow(target, content, hud, k)
					local avoid = table.clone(hud)
					table.insert(avoid, HudLayout.arrowRect(x, y, k))
					-- The bubble draws k times its size on desktop (08 §7).
					for _, size in
						{
							{
								width = 260 * k,
								height = (g.hint + g.bubblePad) * k + 2 * HudLayout.bubbleFrame(k),
							},
							{ width = 420 * k, height = BUBBLE_MAX * k },
						}
					do
						local place = HudLayout.guideBubble(size, target, content, avoid)
						expect(inside(place.rect, area)).toBe(true)
						expect(HudLayout.overlaps(place.rect, rects.keepClear)).toBe(false)
						if place.side ~= "slot" then
							for _, r in avoid do
								if not HudLayout.overlaps(r, target) then
									expect(HudLayout.overlaps(place.rect, r)).toBe(false)
								end
							end
							expect(HudLayout.overlaps(place.rect, target)).toBe(false)
						else
							expect(place.curved).toBe(true)
							local cx, cy = HudLayout.guideCurved(place.rect, target, content)
							local curved = HudLayout.curvedRect(cx, cy)
							expect(inside(curved, area)).toBe(true)
							expect(HudLayout.overlaps(curved, rects.keepClear)).toBe(false)
						end
					end
				end
			)

			it(`{name}: the ring and the cut-out round {tname} keep its whole hit area`, function()
				local ring = HudLayout.guideRing(target, k)
				expect(inside(target, ring)).toBe(true)
				local hole = HudLayout.guideCutout(target, layout.screenClass)
				expect(inside(HudLayout.hitRect(target, min), hole)).toBe(true)
				expect(hole.width >= min and hole.height >= min).toBe(true)
			end)
		end

		it(
			`{name}: the creature's bubble uses the moment slot, above the keep-clear box`,
			function()
				local size = { width = g.bubbleMaxWidth * k, height = BUBBLE_MAX * k }
				local place = HudLayout.guideBubble(size, nil, content, hud)
				expect(place.side).toBe("slot")
				expect(place.curved).toBe(false)
				expect(inside(place.rect, area)).toBe(true)
				expect(HudLayout.overlaps(place.rect, rects.keepClear)).toBe(false)
				expect(HudLayout.overlaps(place.rect, rects.massBar)).toBe(false)
				for _, k in layout.keepOut do
					expect(HudLayout.overlaps(place.rect, k)).toBe(false)
				end
				local tick = HudLayout.guideTick(place.rect, k, content)
				expect(HudLayout.overlaps(tick, rects.keepClear)).toBe(false)
			end
		)

		it(
			`{name}: the step tick sits on the bubble's edge, off its text, the curved arrow and the HUD`,
			function()
				local bubbleSize = { width = 260 * k, height = BUBBLE_MAX * k }
				for _, target in targets do
					local place = HudLayout.guideBubble(bubbleSize, target, content, hud)
					local slot = HudLayout.momentSlot(content, bubbleSize)
					for i, rect in { place.rect, slot } do
						local away = table.clone(hud)
						table.insert(away, rects.keepClear)
						-- The curved arrow shows only for a bubble away from its target.
						if i == 2 or place.curved then
							local cx, cy = HudLayout.guideCurved(rect, target, content)
							table.insert(away, HudLayout.curvedRect(cx, cy))
						end
						local tick = HudLayout.guideTick(rect, k, content, away)
						expect(tick.width).toBeCloseTo(g.tick * k)
						local text = HudLayout.bubbleTextRect(rect, k)
						expect(HudLayout.overlaps(tick, text)).toBe(false)
						for _, r in away do
							expect(HudLayout.overlaps(tick, r)).toBe(false)
						end
						expect(inside(tick, area)).toBe(true)
						-- On a corner: it still touches the bubble.
						expect(HudLayout.overlaps(tick, rect)).toBe(true)
					end
				end
			end
		)

		it(
			`{name}: the ghost thumb and its key row start under the keep-clear box, off the HUD`,
			function()
				local x, y = HudLayout.ghostThumb(content)
				for _, rect in { HudLayout.ghostRect(x, y), HudLayout.ghostRect(x, y, 240) } do
					expect(inside(rect, area)).toBe(true)
					expect(HudLayout.overlaps(rect, rects.keepClear)).toBe(false)
					for _, r in hud do
						expect(HudLayout.overlaps(rect, r)).toBe(false)
					end
				end
				for i = 0, 15 do
					for _, long in { false, true } do
						local ex, ey = HudLayout.ghostDrag(content, x, y, i * math.pi / 8, long)
						local rect = HudLayout.ghostRect(ex, ey)
						expect(inside(rect, area)).toBe(true)
						-- The drag may cross into the keep-clear box (08 §7), never past its middle.
						expect(ey >= rects.keepClear.y + rects.keepClear.height / 2).toBe(true)
					end
				end
			end
		)

		it(
			`{name}: the ghost key row slides off the dock, its labels and the trait slots`,
			function()
				-- The cove's dock (its label hangs 20 rpx past each side) and the run's trait row
				-- with its pips: both sit at the bottom centre with the ghost point.
				local dock = HudLayout.cove(layout.screenClass, content, 1).dock[1]
				local traits = HudLayout.traits(layout.screenClass, content)
				local pips = HudLayout.traitPipsRect(traits.slots[1])
				local avoid = table.clone(hud)
				table.insert(
					avoid,
					{ x = dock.x - 20, y = dock.y, width = dock.width + 40, height = dock.height }
				)
				table.insert(avoid, {
					x = traits.row.x,
					y = pips.y,
					width = traits.row.width,
					height = traits.row.y + traits.row.height - pips.y,
				})
				local w, h = g.ghostKeysWidth * k, g.hint * k
				local x, y = HudLayout.ghostKeys(content, w, h, avoid)
				local rect = HudLayout.ghostRect(x, y, g.ghostKeysWidth, k)
				expect(rect.height).toBe(g.hint * k)
				expect(inside(rect, area)).toBe(true)
				expect(HudLayout.overlaps(rect, rects.keepClear)).toBe(false)
				for _, r in avoid do
					expect(HudLayout.overlaps(rect, HudLayout.grow(r, HudLayout.GAP_MIN - 1e-6))).toBe(
						false
					)
				end
			end
		)

		it(`{name}: the danger edge leaves the home marker, its ring and HOME uncovered`, function()
			local avoid = HudLayout.homeAvoid(layout.screenClass, rects, nil)
			local o = layout.contentOrigin
			for i = 0, 11 do
				local hx, hy = HudLayout.homeMarker(content, i * math.pi / 6, avoid)
				local marker = { x = hx - 36, y = hy - 36, width = 72, height = 72 }
				local parts = {
					HudLayout.homeRect(hx, hy),
					HudLayout.guideRing(marker, k),
					HudLayout.homeTag(hx, hy, 96, content, avoid, k),
				}
				local full: { Rect } = {}
				for _, r in parts do
					table.insert(
						full,
						{ x = r.x + o.x, y = r.y + o.y, width = r.width, height = r.height }
					)
				end
				for _, side in { "left", "right", "top", "bottom" } :: { HudLayout.Side } do
					for _, piece in HudLayout.dangerPieces(side, layout.fullSize, full) do
						for _, r in full do
							expect(HudLayout.overlaps(piece.rect, r)).toBe(false)
						end
					end
				end
			end
		end)

		it(`{name}: off-screen arrows ride the edge clear of the HUD`, function()
			for i = 0, 23 do
				local x, y = HudLayout.guideEdgeArrow(content, i * math.pi / 12, hud, k)
				local rect = HudLayout.arrowRect(x, y, k)
				expect(inside(rect, area)).toBe(true)
				for _, r in hud do
					expect(HudLayout.overlaps(rect, r)).toBe(false)
				end
			end
		end)

		it(
			`{name}: the HOME chip sits by the home marker wherever it rides, clear of the HUD`,
			function()
				local avoid = HudLayout.homeAvoid(layout.screenClass, rects, nil)
				for i = 0, 35 do
					local hx, hy = HudLayout.homeMarker(content, i * math.pi / 18, avoid)
					local tag = HudLayout.homeTag(hx, hy, 96 * k, content, avoid, k)
					expect(inside(tag, area)).toBe(true)
					for _, r in avoid do
						expect(HudLayout.overlaps(tag, r)).toBe(false)
					end
					-- Never on the marker itself.
					expect(
						HudLayout.overlaps(
							tag,
							centred(hx, hy, HudLayout.HOME.size, HudLayout.HOME.size)
						)
					).toBe(false)
				end
			end
		)

		it(
			`{name}: the dash pulse ring and DASH! clear the keep-clear box and the ability`,
			function()
				local ring = HudLayout.dashRing(rects.dash, k)
				expect(inside(rects.dash, ring)).toBe(true)
				local tag = HudLayout.dashTag(rects.dash, 160 * k, content, k)
				expect(tag.height).toBe(g.dashTagHeight * k)
				expect(inside(tag, area)).toBe(true)
				expect(HudLayout.overlaps(tag, rects.keepClear)).toBe(false)
				expect(HudLayout.overlaps(tag, abilityHit)).toBe(false)
				local swell = (ring.height * (g.dashPulse - 1)) / 2
				expect(HudLayout.overlaps(tag, HudLayout.grow(ring, swell))).toBe(false)
			end
		)

		it(`{name}: the danger edge stays on the screen's edge, off the keep-clear box`, function()
			local full = layout.fullSize
			local origin = layout.contentOrigin
			for _, side in { "left", "right", "top", "bottom" } :: { HudLayout.Side } do
				local edge = HudLayout.dangerEdge(side, full)
				expect(inside(edge, { x = 0, y = 0, width = full.width, height = full.height })).toBe(
					true
				)
				local inContent = {
					x = edge.x - origin.x,
					y = edge.y - origin.y,
					width = edge.width,
					height = edge.height,
				}
				expect(HudLayout.overlaps(inContent, rects.keepClear)).toBe(false)
			end
		end)
	end
end)

describe("Guide kit sizes and rules (docs/08 sections 1.5 and 7)", function()
	it("keeps every guide text at or over the floor", function()
		for _, size in { g.bubbleText, g.tagText, g.dashTagText } do
			expect(size >= HudLayout.TEXT_FLOOR).toBe(true)
		end
	end)

	it("uses 08 §7's sizes and timings", function()
		expect(g.arrow).toBe(96)
		expect(g.curved).toBe(128)
		expect(g.hand).toBe(112)
		expect(g.trailDot).toBe(48)
		expect(g.trailChevron).toBe(64)
		expect(g.ring).toBe(160)
		expect(g.bubbleMaxWidth).toBe(420)
		expect(g.hint).toBe(64)
		expect(g.tick).toBe(64)
		expect(g.tapDown + g.tapUp + g.tapPause).toBeCloseTo(1.0)
		expect(g.appear <= 0.2 and g.clear <= 0.1).toBe(true)
	end)

	it("rings a point with 160 and a button 16 rpx out", function()
		local point = HudLayout.guideRing({ x = 100, y = 100, width = 0, height = 0 })
		expect(point.width).toBe(160)
		expect(point.x).toBe(20)
		local dash = HudLayout.guideRing({ x = 0, y = 0, width = 136, height = 136 })
		expect(dash.width).toBe(168)
		expect(dash.x).toBe(-16)
	end)

	it("puts the danger edge on the side the threat is past", function()
		local full = { width = 1600, height = 720 }
		expect(HudLayout.dangerSide(0, full)).toBe("right")
		expect(HudLayout.dangerSide(math.pi, full)).toBe("left")
		expect(HudLayout.dangerSide(math.pi / 2, full)).toBe("bottom")
		expect(HudLayout.dangerSide(-math.pi / 2, full)).toBe("top")
		-- 20 degrees up on a wide screen still leaves by the right edge.
		expect(HudLayout.dangerSide(-math.rad(20), full)).toBe("right")
		local left = HudLayout.dangerEdge("left", full)
		expect(left.width).toBe(96)
		expect(left.height).toBe(720)
	end)

	it("holds bubble text at Body 24 up to two lines at every scale, Small 22 past them", function()
		for i = 0, 22 do
			local scale = 0.4 + i * 0.1
			-- The drawn size never rounds under 24 (whole pixels, 08 §1.5).
			local rpx = ScreenScale.textRpx(g.bubbleText, scale)
			expect(rpx >= g.bubbleText).toBe(true)
			expect(math.ceil(rpx * scale - 1e-6) / scale >= g.bubbleText - 1e-6).toBe(true)
			-- Any line height (Nunito's, or a font's with taller leading) at that scale.
			for _, leading in { 1.15, 1.36, 1.6 } do
				local line = math.ceil(rpx * scale * leading)
				expect(HudLayout.bubbleTextRpx(line, line)).toBe(24)
				expect(HudLayout.bubbleTextRpx(2 * line, line)).toBe(24)
				expect(HudLayout.bubbleTextRpx(2 * line + 2, line)).toBe(24)
				expect(HudLayout.bubbleTextRpx(3 * line, line)).toBe(HudLayout.TEXT_FLOOR)
			end
		end
	end)

	it("draws the guide 1.4x on desktop only, the bubble and its text too", function()
		expect(HudLayout.guideScale("Desktop")).toBe(1.4)
		for _, class in { "Phone", "Tablet", "Handheld", "TV" } :: { HudLayout.ScreenClass } do
			expect(HudLayout.guideScale(class)).toBe(1)
		end
		local r = HudLayout.arrowRect(0, 0, 1.4)
		expect(r.width).toBeCloseTo((g.arrow + 2 * g.bob) * 1.4)
		local dash = { x = 0, y = 0, width = 80, height = 96 }
		expect(HudLayout.dashRing(dash, 1.4).x).toBeCloseTo(-g.dashRingPad * 1.4)
		local tick = HudLayout.guideTick({ x = 100, y = 100, width = 300, height = 100 }, 1.4)
		expect(tick.width).toBeCloseTo(g.tick * 1.4)
	end)

	it("reaches 64 px hints, key caps and bubble text over 24 px on a 1080p desktop", function()
		local layout = SCREENS["desktop 1920 x 1080"]
		expect(layout.screenClass).toBe("Desktop")
		expect(layout.scale).toBeCloseTo(0.9)
		local k = HudLayout.guideScale(layout.screenClass)
		-- G8: the 64 rpx hint (the key caps and the ghost key row) at the desktop factor.
		expect(g.hint * k * layout.scale >= 64).toBe(true)
		-- The bubble's Body 24 scales with it.
		expect(g.bubbleText * k * layout.scale >= 24).toBe(true)
		-- The ghost key row: every cap 56 of the 64, the four arrows in a row.
		expect(g.ghostKeysWidth).toBe(64 + 8 + 56 + 8 + 4 * 56 + 3 * 4)
	end)

	it("fills the hold ring round the target, the hand pressing further out", function()
		local dash = { x = 100, y = 100, width = 136, height = 136 }
		local ring = HudLayout.holdRing(dash)
		expect(ring.width).toBe(136 + 2 * g.holdRingPad)
		expect(inside(dash, ring)).toBe(true)
		local x, y = HudLayout.handPoint(dash, true)
		expect(x).toBe(168 + g.holdOffset)
		expect(y).toBe(168 + g.holdOffset)
		-- The fingertip stays on the round button.
		expect(math.sqrt(2) * g.holdOffset < 68).toBe(true)
		expect(g.holdHandOpacity < 1).toBe(true)
	end)

	it("points the ghost thumb's drag cue past the thumb at the drag's end", function()
		local content = { width = 1280, height = 720 }
		local x, y = 640, 600
		local ex, ey = HudLayout.ghostDrag(content, x, y, -math.pi / 2)
		local tx, ty = HudLayout.ghostCueTip(content, x, y, ex, ey)
		expect(tx).toBeCloseTo(640)
		expect(ty).toBeCloseTo(600 - g.ghostDrag - g.ghost / 2 - g.ghostCueReach)
		-- Clear of the thumb where the drag ends.
		local thumb = HudLayout.ghostRect(ex, ey)
		expect(ty < thumb.y).toBe(true)
		expect(g.ghostOpacity >= 0.9 and g.ghost >= 144).toBe(true)
	end)

	it("presses a tap or hold target at its lower right, inside it", function()
		local dash = { x = 100, y = 100, width = 136, height = 136 }
		local x, y = HudLayout.handPoint(dash)
		expect(x).toBe(168 + g.handOffset)
		expect(y).toBe(168 + g.handOffset)
		local bar = { x = 0, y = 0, width = 440, height = 40 }
		local bx, by = HudLayout.handPoint(bar)
		expect(bx).toBe(220 + g.handOffset)
		expect(by).toBe(40)
	end)

	it("cuts the danger edge round the home marker, soft at the cut ends", function()
		local full = { width = 1280, height = 720 }
		local pieces =
			HudLayout.dangerPieces("left", full, { { x = 20, y = 300, width = 100, height = 120 } })
		expect(#pieces).toBe(2)
		expect(pieces[1].rect.y).toBe(0)
		expect(pieces[1].rect.height).toBe(284)
		expect(pieces[1].softStart).toBe(false)
		expect(pieces[1].softEnd).toBe(true)
		expect(pieces[2].rect.y).toBe(436)
		expect(pieces[2].softStart).toBe(true)
		expect(pieces[2].softEnd).toBe(false)
		-- Off the edge: one whole piece.
		local whole =
			HudLayout.dangerPieces("left", full, { { x = 600, y = 300, width = 80, height = 80 } })
		expect(#whole).toBe(1)
		expect(whole[1].rect.height).toBe(720)
	end)

	it("lays trail dots every 12 studs, at most 12 ahead, the passed ones gone", function()
		local first, last = HudLayout.trailWindow(60, 0)
		expect(first).toBe(1)
		expect(last).toBe(5)
		expect(HudLayout.trailDot(5, 60)).toBe(60)
		first, last = HudLayout.trailWindow(300, 0)
		expect(last - first + 1).toBe(12)
		first, last = HudLayout.trailWindow(300, 30)
		expect(first).toBe(3)
		expect(last).toBe(14)
		first, last = HudLayout.trailWindow(60, 61)
		expect(first > last).toBe(true)
		-- The last dot sits on the target.
		expect(HudLayout.trailDot(5, 55)).toBe(55)
	end)
end)
