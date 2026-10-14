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
-- The tallest bubble: two lines of Body 24 and its padding.
local BUBBLE_MAX = g.bubbleLines * g.bubbleLine + 2 * g.bubblePad

describe("Guide kit layout on every screen class (docs/08 section 7)", function()
	for name, layout in SCREENS do
		local content = layout.contentSize
		local area = { x = 0, y = 0, width = content.width, height = content.height }
		local rects = HudLayout.compute(layout.screenClass, content, layout.keepOut)
		local min = HudLayout.minTarget(layout.screenClass)
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
					local x, y, angle = HudLayout.guideArrow(target, content, hud)
					local rect = HudLayout.arrowRect(x, y)
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
					local x, y = HudLayout.guideArrow(target, content, hud)
					local avoid = table.clone(hud)
					table.insert(avoid, HudLayout.arrowRect(x, y))
					for _, size in
						{
							{ width = 260, height = g.hint + 2 * g.bubblePad },
							{ width = 420, height = BUBBLE_MAX },
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
				local ring = HudLayout.guideRing(target)
				expect(inside(target, ring)).toBe(true)
				local hole = HudLayout.guideCutout(target, layout.screenClass)
				expect(inside(HudLayout.hitRect(target, min), hole)).toBe(true)
				expect(hole.width >= min and hole.height >= min).toBe(true)
			end)
		end

		it(
			`{name}: the creature's bubble uses the moment slot, above the keep-clear box`,
			function()
				local size = { width = g.bubbleMaxWidth, height = BUBBLE_MAX }
				local place = HudLayout.guideBubble(size, nil, content, hud)
				expect(place.side).toBe("slot")
				expect(place.curved).toBe(false)
				expect(inside(place.rect, area)).toBe(true)
				expect(HudLayout.overlaps(place.rect, rects.keepClear)).toBe(false)
				expect(HudLayout.overlaps(place.rect, rects.massBar)).toBe(false)
				for _, k in layout.keepOut do
					expect(HudLayout.overlaps(place.rect, k)).toBe(false)
				end
				local tick = HudLayout.guideTick(place.rect)
				expect(HudLayout.overlaps(tick, rects.keepClear)).toBe(false)
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

		it(`{name}: off-screen arrows ride the edge clear of the HUD`, function()
			for i = 0, 23 do
				local x, y = HudLayout.guideEdgeArrow(content, i * math.pi / 12, hud)
				local rect = HudLayout.arrowRect(x, y)
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
					local tag = HudLayout.homeTag(hx, hy, 96, content, avoid)
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
				local ring = HudLayout.dashRing(rects.dash)
				expect(inside(rects.dash, ring)).toBe(true)
				local tag = HudLayout.dashTag(rects.dash, 160, content)
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
