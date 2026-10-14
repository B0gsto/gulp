--!strict
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

-- The screens of docs/15 sections 3.1 to 3.3, with the spike F11 top bar (x 0 to 120 px,
-- y 0 to 58 px; TopbarInset is the free part right of it) and phone notch insets.
local function screen(r: ScreenScale.Reading, insetX: number): Layout
	local w, h = r.viewportWidth, r.viewportHeight
	local safe = { x = insetX, y = 0, width = w - 2 * insetX, height = h }
	local topbar = { x = 120, y = 0, width = w - 120, height = 58 }
	return ScreenScale.compute(r, { width = w, height = h }, safe, topbar, 1)
end

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

describe("HudLayout.compute on every screen class (docs/08 sections 1.3 to 1.5, 3.3)", function()
	for name, layout in SCREENS do
		local content = layout.contentSize
		local rects = HudLayout.compute(layout.screenClass, content, layout.keepOut)
		local box = { x = 0, y = 0, width = content.width, height = content.height }

		it(`{name}: every element is inside the safe frame`, function()
			expect(inside(rects.massBar, box)).toBe(true)
			expect(inside(rects.dash, box)).toBe(true)
			expect(inside(rects.ability, box)).toBe(true)
		end)

		it(`{name}: nothing persistent enters the keep-clear box`, function()
			for _, r in { rects.massBar, rects.dash, rects.dashHit, rects.ability } do
				expect(HudLayout.overlaps(r, rects.keepClear)).toBe(false)
			end
		end)

		it(`{name}: the mass bar clears the Roblox keep-out`, function()
			for _, k in layout.keepOut do
				expect(HudLayout.overlaps(rects.massBar, k)).toBe(false)
			end
		end)

		it(`{name}: the dash hit area meets the minimum target and the bottom rule`, function()
			local min = HudLayout.minTarget(layout.screenClass)
			expect(rects.dashHit.width >= min).toBe(true)
			expect(rects.dashHit.height >= min).toBe(true)
			local fromSafeBottom = content.height
				+ HudLayout.MARGIN_BOTTOM
				- (rects.dash.y + rects.dash.height)
			expect(fromSafeBottom >= HudLayout.BOTTOM_TAP_CLEAR).toBe(true)
		end)

		it(`{name}: dash and ability keep the 16 rpx gap`, function()
			expect(
				HudLayout.overlaps(
					HudLayout.grow(rects.dash, HudLayout.GAP_MIN - 1e-6),
					rects.ability
				)
			).toBe(false)
		end)
	end

	it("puts the phone dash where the element table says", function()
		local content = { width = 1251, height = 677 }
		local dash = HudLayout.dash("Phone", content)
		expect(dash.x).toBe(1251 - 40 - 136)
		expect(dash.y).toBe(677 - 44 - 136)
		expect(dash.width).toBe(136)
		-- Zone A: the far corner of the button is within 340 rpx of the frame's bottom corner.
		local dx = content.width - dash.x
		local dy = content.height + 28 - dash.y
		expect(math.sqrt(dx * dx + dy * dy) <= HudLayout.ZONE_A).toBe(true)
	end)

	it("moves dash 24 rpx in on a tablet and makes it a hint tile on desktop", function()
		local content = { width = 1248, height = 676 }
		local phone = HudLayout.dash("Phone", content)
		local tablet = HudLayout.dash("Tablet", content)
		expect(phone.x - tablet.x).toBe(24)
		expect(phone.y - tablet.y).toBe(24)
		local desk = HudLayout.dash("Desktop", content)
		expect(desk.width).toBe(80)
		expect(desk.height).toBe(96)
		expect(desk.x).toBe(1248 - 32 - 80)
	end)
end)

describe("HudLayout.massBar keep-out fallback (docs/08 section 1.3)", function()
	local content = { width = 1248, height = 676 }
	it("stays 440 wide and centred when the keep-out is far", function()
		local r = HudLayout.massBar(content, { { x = -16, y = -16, width = 200, height = 100 } })
		expect(r.width).toBe(440)
		expect(r.x).toBe((1248 - 440) / 2)
		expect(r.y).toBe(12)
	end)
	it("shrinks to 360 when that clears", function()
		local k = { x = -16, y = -16, width = 410, height = 100 }
		local r = HudLayout.massBar(content, { k })
		expect(r.width).toBe(360)
		expect(r.x).toBe((1248 - 360) / 2)
	end)
	it("then shifts right to clear by 16 rpx", function()
		local k = { x = -16, y = -16, width = 560, height = 100 }
		local r = HudLayout.massBar(content, { k })
		expect(r.width).toBe(360)
		expect(r.x).toBe(k.x + k.width + 16)
	end)
end)

describe("HudLayout.dragRing (docs/08 section 3.16)", function()
	local full = { width = 1283, height = 721 }
	it("holds the knob within 84 rpx and reports the dead zone", function()
		local p = HudLayout.dragRing(400, 400, 600, 400, full)
		expect(p.knobX - p.ringX).toBeCloseTo(84, 1e-9)
		expect(p.dead).toBe(false)
		local q = HudLayout.dragRing(400, 400, 410, 400, full)
		expect(q.knobX - q.ringX).toBe(10)
		expect(q.dead).toBe(true)
	end)
	it("nudges the ring fully on screen near an edge", function()
		local p = HudLayout.dragRing(20, 710, 20, 710, full)
		expect(p.ringX).toBe(84)
		expect(p.ringY).toBe(721 - 84)
		expect(p.knobX).toBe(84)
	end)
end)

describe("HudLayout.homeMarker (docs/08 section 3.12)", function()
	local content = { width = 1248, height = 676 }
	it("sits on the ellipse 72 rpx inside the frame", function()
		local x, y = HudLayout.homeMarker(content, 0, {})
		expect(x).toBeCloseTo(1248 - 72, 1e-9)
		expect(y).toBeCloseTo(338, 1e-9)
	end)
	it("slides around the dash and ability buttons", function()
		local dash = HudLayout.dash("Phone", content)
		local ability = HudLayout.ability("Phone", content)
		local toward = math.atan2(dash.y - 338, dash.x - 624) -- straight at the dash button
		local x, y = HudLayout.homeMarker(content, toward, { dash, ability })
		local r = HudLayout.homeRect(x, y)
		expect(HudLayout.overlaps(r, HudLayout.grow(dash, 16))).toBe(false)
		expect(HudLayout.overlaps(r, HudLayout.grow(ability, 16))).toBe(false)
	end)
end)

describe(
	"HudLayout.homeMarker keep-out on every screen class (docs/08 sections 3.12, 3.16)",
	function()
		for name, layout in SCREENS do
			local content = layout.contentSize
			local origin = layout.contentOrigin
			local full = layout.fullSize
			local rects = HudLayout.compute(layout.screenClass, content, layout.keepOut)
			local box = { x = 0, y = 0, width = content.width, height = content.height }
			-- Desktop has no drag ring; touch screens try the harness pose and a few thumb spots.
			local rings: { Rect? } = { nil }
			if layout.screenClass ~= "Desktop" then
				rings = {}
				for _, at in
					{
						{ 230, full.height - 210 },
						{ 120, full.height - 120 },
						{ 300, full.height / 2 },
						{ 160, 200 },
					}
				do
					local pose = HudLayout.dragRing(at[1], at[2], at[1] + 60, at[2] - 40, full)
					table.insert(
						rings,
						HudLayout.ringRect(pose.ringX - origin.x, pose.ringY - origin.y)
					)
				end
			end
			it(
				`{name}: the marker, pointer and chip clear every HUD element and stay inside`,
				function()
					for _, ring in rings do
						local avoid = HudLayout.homeAvoid(layout.screenClass, rects, ring)
						for deg = 0, 357, 3 do
							local x, y = HudLayout.homeMarker(content, math.rad(deg), avoid)
							local r = HudLayout.homeRect(x, y)
							expect(inside(r, box)).toBe(true)
							for _, a in avoid do
								expect(HudLayout.overlaps(r, HudLayout.grow(a, HudLayout.GAP_MIN))).toBe(
									false
								)
							end
						end
					end
				end
			)
		end
		it("the marker rect holds the pointer's orbit and the distance chip", function()
			local r = HudLayout.homeRect(0, 0)
			expect(r.x <= -HudLayout.HOME_REACH).toBe(true)
			expect(r.y + r.height >= 36 + HudLayout.HOME_CHIP_GAP + HudLayout.HOME.labelHeight).toBe(
				true
			)
		end)
	end
)

describe("HudLayout screens S11 and S12 (docs/08 sections 4.4 and 4.5)", function()
	for name, layout in SCREENS do
		local content = layout.contentSize
		it(`{name}: Swim again is 280 x 96 in zone A and clear of the bottom`, function()
			local g = HudLayout.gulped(layout.screenClass, content)
			expect(g.swimAgain.width).toBe(280)
			expect(g.swimAgain.height).toBe(96)
			-- Zone A (08 §1.4): the button's centre is within 340 rpx of the frame's corner.
			local dx = content.width - (g.swimAgain.x + g.swimAgain.width / 2)
			local dy = content.height + 28 - (g.swimAgain.y + g.swimAgain.height / 2)
			expect(math.sqrt(dx * dx + dy * dy) <= HudLayout.ZONE_A).toBe(true)
			expect(g.swimAgainHit.height >= HudLayout.minTarget(layout.screenClass)).toBe(true)
		end)
		it(`{name}: the Pearls table fits above Continue`, function()
			local p = HudLayout.pearls(content, 2)
			expect(p.panel.y >= 0).toBe(true)
			expect(HudLayout.overlaps(p.panel, p.continue)).toBe(false)
			expect(p.panel.x >= 0 and p.panel.x + p.panel.width <= content.width).toBe(true)
		end)
	end
end)

describe("HudLayout S12 specimen card (docs/08 sections 4.5 and 5.2)", function()
	for name, layout in SCREENS do
		local content = layout.contentSize
		local box = { x = 0, y = 0, width = content.width, height = content.height }
		it(`{name}: table, card and Continue fit without overlap`, function()
			local p = HudLayout.pearls(content, 2, true)
			local card = p.card :: Rect
			expect(card ~= nil).toBe(true)
			expect(inside(p.panel, box) and inside(card, box) and inside(p.title, box)).toBe(true)
			expect(HudLayout.overlaps(p.panel, card)).toBe(false)
			expect(HudLayout.overlaps(card, p.continue)).toBe(false)
			expect(HudLayout.overlaps(p.panel, p.continue)).toBe(false)
			expect(card.x - (p.panel.x + p.panel.width) >= HudLayout.GAP_MIN).toBe(true)
			expect(card.y).toBe(p.panel.y)
		end)
	end
	it("stacks the card's contents inside its height", function()
		local c = HudLayout.SPECIMEN_CARD
		local used = 2 * c.padding
			+ c.renderHeight
			+ c.tierHeight
			+ c.traitSize
			+ c.incomeHeight
			+ c.ribbonHeight
			+ 4 * c.rowGap
		expect(used <= c.height).toBe(true)
		-- Three 32 rpx trait icons with 8 rpx gaps fit the inner width.
		expect(3 * c.traitSize + 2 * c.rowGap <= c.width - 2 * c.padding).toBe(true)
	end)
	it("keeps the stage 1 table centred without a card", function()
		local content = SCREENS["small phone 667 x 375"].contentSize
		local p = HudLayout.pearls(content, 2)
		expect(p.card).toBe(nil)
		expect(math.abs(p.panel.x + p.panel.width / 2 - content.width / 2) < 1e-6).toBe(true)
	end)
end)

describe("HudLayout S14 cove HUD (docs/08 sections 1.3 to 1.5 and 5.1)", function()
	for name, layout in SCREENS do
		local content = layout.contentSize
		local box = { x = 0, y = 0, width = content.width, height = content.height }
		local min = HudLayout.minTarget(layout.screenClass)
		for _, count in { 1, 4 } do
			local r = HudLayout.cove(layout.screenClass, content, count)
			local visible = { r.pearls, r.income, r.slots, r.claimAll, r.dash }
			local hits = { r.plusHit, r.slotsHit, r.claimAllHit, r.dashHit }
			for _, d in r.dock do
				table.insert(visible, d)
				table.insert(hits, d)
			end

			it(`{name}, {count} dock: every element is inside the content box`, function()
				for _, rect in visible do
					expect(inside(rect, box)).toBe(true)
				end
				expect(inside(r.plus, r.pearls)).toBe(true)
			end)

			it(`{name}, {count} dock: no two elements overlap`, function()
				for i = 1, #visible do
					for j = i + 1, #visible do
						expect(HudLayout.overlaps(visible[i], visible[j])).toBe(false)
					end
				end
			end)

			it(`{name}, {count} dock: hit areas meet the minimum and keep 16 rpx apart`, function()
				for _, h in hits do
					expect(h.width >= min and h.height >= min).toBe(true)
				end
				for i = 1, #hits do
					for j = i + 1, #hits do
						local grown = HudLayout.grow(hits[i], HudLayout.GAP_MIN / 2)
						expect(
							HudLayout.overlaps(
								grown,
								HudLayout.grow(hits[j], HudLayout.GAP_MIN / 2)
							)
						).toBe(false)
					end
				end
			end)

			it(`{name}, {count} dock: nothing enters the keep-clear box or the keep-out`, function()
				local clear = HudLayout.keepClear(content)
				for _, rect in visible do
					expect(HudLayout.overlaps(rect, clear)).toBe(false)
				end
				for _, k in layout.keepOut do
					for _, rect in { r.pearls, r.income, r.slots, r.plusHit, r.slotsHit } do
						expect(
							HudLayout.overlaps(HudLayout.grow(rect, HudLayout.KEEP_OUT_CLEAR), k)
						).toBe(false)
					end
				end
			end)

			it(`{name}, {count} dock: dock and Claim all clear the bottom tap margin`, function()
				local floor = content.height + HudLayout.MARGIN_BOTTOM - HudLayout.BOTTOM_TAP_CLEAR
				expect(r.claimAllHit.y + r.claimAllHit.height <= floor).toBe(true)
				for _, d in r.dock do
					expect(d.y + d.height <= floor).toBe(true)
				end
			end)
		end
	end

	it("puts the phone chips and Claim all where the element table says", function()
		local content = SCREENS["large phone 932 x 430"].contentSize
		local r = HudLayout.cove("Phone", content, 4)
		local cx = content.width / 2
		expect(r.pearls.x + r.pearls.width / 2).toBe(cx - 150)
		expect(r.income.x + r.income.width / 2).toBe(cx + 90)
		expect(r.slots.x + r.slots.width / 2).toBe(cx + 270)
		expect(r.pearls.y).toBe(12)
		expect(r.claimAll.x + r.claimAll.width).toBe(content.width - 40)
		-- 196 in the table; 208 so it clears the dash hit area by 16 rpx below its lip and shadow.
		expect(r.claimAll.y + r.claimAll.height).toBe(content.height - 208)
		expect(r.claimAll.width == 260 and r.claimAll.height == 88).toBe(true)
		-- The dock row is centred 60 rpx left of the middle; 4 buttons of 88 with 16 gaps.
		local d = r.dock
		expect((d[1].x + d[4].x + d[4].width) / 2).toBe(cx - 60)
		expect(d[2].x - (d[1].x + d[1].width)).toBe(16)
		expect(d[1].y + d[1].height).toBe(content.height - 28)
	end)

	for name, layout in SCREENS do
		it(`{name}: Claim all and Dash keep 16 rpx between hit areas and drawn shapes`, function()
			local r = HudLayout.cove(layout.screenClass, layout.contentSize, 4)
			local gapHit = r.dashHit.y - (r.claimAllHit.y + r.claimAllHit.height)
			local gapDrawn = r.dash.y - (r.claimAll.y + r.claimAll.height + HudLayout.BUTTON_DROP)
			expect(gapHit >= HudLayout.GAP_MIN).toBe(true)
			expect(gapDrawn >= HudLayout.GAP_MIN).toBe(true)
		end)
	end

	it("keeps every cove text at or above the 22 rpx floor", function()
		for _, size in HudLayout.COVE.text do
			expect(size >= 22).toBe(true)
		end
	end)
end)

describe("HudLayout moment slot, S07 and S08 (docs/08 sections 1.5, 3.3, 4.1 to 4.3)", function()
	local slotSize = { width = HudLayout.MOMENT_SLOT.width, height = HudLayout.MOMENT_SLOT.height }
	local cards = {
		["S07 with food"] = HudLayout.tierUpCard(slotSize, true),
		["S07 without food"] = HudLayout.tierUpCard(slotSize, false),
		["S07 tier 7"] = HudLayout.tierUpCard(slotSize, false, true),
		["S07 tier 7 with food"] = HudLayout.tierUpCard(slotSize, true, true),
		["S08"] = HudLayout.traitCard(slotSize),
		["S08 Epic or Mythic"] = HudLayout.traitCard(slotSize, true),
	}
	-- The cards that turn `UI_Common_Rays` (08 §4.2 tier 7, §4.3 Epic and Mythic).
	local burst = {
		["S07 tier 7"] = true,
		["S07 tier 7 with food"] = true,
		["S08 Epic or Mythic"] = true,
	}
	local function offset(r: Rect, dx: number, dy: number): Rect
		return { x = r.x + dx, y = r.y + dy, width = r.width, height = r.height }
	end

	for name, layout in SCREENS do
		local content = layout.contentSize
		local slot = HudLayout.momentSlot(content)
		local rects = HudLayout.compute(layout.screenClass, content, layout.keepOut)
		local box = { x = 0, y = 0, width = content.width, height = content.height }
		local chip = HudLayout.bankChip(content)

		it(`{name}: the slot is top centre, 130 down, inside the content box`, function()
			expect(slot.y).toBe(130)
			expect(slot.x + slot.width / 2).toBeCloseTo(content.width / 2, 1e-6)
			expect(inside(slot, box)).toBe(true)
		end)

		it(`{name}: the slot clears the mass bar, the bank chip and the keep-out`, function()
			expect(HudLayout.overlaps(slot, rects.massBar)).toBe(false)
			expect(HudLayout.overlaps(slot, chip)).toBe(false)
			for _, k in layout.keepOut do
				expect(HudLayout.overlaps(slot, k)).toBe(false)
			end
		end)

		it(`{name}: the slot and the keep-clear box (docs/14 section 4, row 35)`, function()
			-- On a phone the content box is 676 rpx tall, so the box starts at 229.8 and the
			-- slot dips 12 rpx into it; elsewhere it stays clear.
			local dip = slot.y + slot.height - rects.keepClear.y
			if layout.screenClass == "Phone" then
				expect(dip).toBeCloseTo(12.16, 0.01)
			else
				expect(dip <= 0).toBe(true)
			end
		end)

		for card, c in cards do
			local placed = offset(c.card, slot.x, slot.y)
			it(`{name}, {card}: the card stays in the slot, 16 rpx under the chip row`, function()
				expect(inside(placed, slot)).toBe(true)
				local gap = placed.y - (chip.y + chip.height)
				expect(gap >= HudLayout.GAP_MIN).toBe(true)
				expect(placed.y - (rects.massBar.y + rects.massBar.height) >= HudLayout.GAP_MIN).toBe(
					true
				)
			end)

			it(`{name}, {card}: the rays never reach the chip row or below the card`, function()
				local clip = offset(c.raysClip, placed.x, placed.y)
				expect(HudLayout.overlaps(clip, chip)).toBe(false)
				expect(HudLayout.overlaps(clip, rects.massBar)).toBe(false)
				expect(clip.y + clip.height <= placed.y + placed.height + 1e-6).toBe(true)
				-- They do reach past the card's edge (08 §4.2, §4.3), up to the gap above it.
				expect(c.rays.x < 0 or c.rays.y < 0).toBe(true)
				expect(clip.y < placed.y).toBe(true)
			end)

			if burst[card] then
				it(
					`{name}, {card}: the rays are symmetric about the art and clear the text`,
					function()
						local ax = c.art.x + c.art.width / 2
						local ay = c.art.y + c.art.height / 2
						expect(c.rays.x + c.rays.width / 2).toBeCloseTo(ax, 1e-6)
						expect(c.rays.y + c.rays.height / 2).toBeCloseTo(ay, 1e-6)
						expect(c.raysClip.x + c.raysClip.width / 2).toBeCloseTo(ax, 1e-6)
						expect(c.raysClip.width).toBeCloseTo(c.rays.width, 1e-6)
						-- Past the card's side by as much as they reach right of the art.
						expect(c.raysClip.x < 0).toBe(true)
						-- The spokes show beyond the art (not a thin corona), and stay off the text.
						expect(c.rays.width / 2 - c.art.width / 2 >= 32).toBe(true)
						for _, t in { c.header, c.name, c.line } do
							expect(HudLayout.overlaps(t :: Rect, c.raysClip)).toBe(false)
						end
					end
				)
			end
		end

		-- 08 §1.5: Small 22 is the floor. Kit/Draw sizes text with ScreenScale.textRpx, which
		-- rounds up to whole pixels, so each row must hold the rounded size, and what the engine
		-- draws must not fall under 22 rpx at this class's scale (0.9 on a 1080p desktop).
		it(`{name}: every card text keeps the 22 rpx floor and fits its row`, function()
			local scale = layout.scale
			for _, spec in { HudLayout.TIER_UP, HudLayout.TRAIT_GAINED } do
				for _, row in
					{
						{ spec.type.header, spec.headerHeight },
						{ spec.type.name, spec.nameHeight },
						{ spec.type.line, spec.lineHeight },
					}
				do
					local size = ScreenScale.textRpx(row[1], scale)
					expect(row[1] >= HudLayout.TEXT_FLOOR).toBe(true)
					expect(ScreenScale.drawnPx(size, scale) / scale >= HudLayout.TEXT_FLOOR).toBe(
						true
					)
					expect(size <= row[2]).toBe(true)
				end
			end
		end)
	end

	for name, c in cards do
		it(`{name}: the parts fit the card without overlap`, function()
			local card = { x = 0, y = 0, width = c.card.width, height = c.card.height }
			local text = { c.header, c.name }
			local line = c.line
			if line then
				table.insert(text, line)
			end
			expect(inside(c.art, card)).toBe(true)
			expect(inside(c.band, card)).toBe(true)
			expect(inside(c.art, c.band)).toBe(true)
			for i, p in text do
				expect(inside(p, c.band)).toBe(true)
				expect(HudLayout.overlaps(p, c.art)).toBe(false)
				for j = i + 1, #text do
					expect(HudLayout.overlaps(p, text[j])).toBe(false)
				end
			end
			for _, t in c.tails do
				expect(inside(t, card)).toBe(true)
				-- Each tail shows beyond the band by more than its notch, and tucks under it.
				local shown = if t.x < c.band.x
					then c.band.x - t.x
					else t.x + t.width - (c.band.x + c.band.width)
				expect(shown > HudLayout.TIER_UP.notch).toBe(true)
				expect(HudLayout.overlaps(t, c.band)).toBe(true)
			end
		end)
	end

	it(
		"uses 08's sizes: S07 460 x 104 with a 96 badge (104 at tier 7), S08 420 x 104, icon 80",
		function()
			local t = HudLayout.tierUpCard(slotSize, true)
			expect(t.card.width).toBe(460)
			expect(t.card.height).toBe(104)
			expect(t.art.width).toBe(96)
			expect(t.card.x).toBe(10)
			expect(t.card.y).toBe(8)
			local top = HudLayout.tierUpCard(slotSize, true, true)
			expect(top.art.width).toBe(104)
			expect(top.art.x + top.art.width / 2).toBe(t.art.x + t.art.width / 2)
			-- The badge grows to 104 by a gold rim round the 96 rpx badge.
			expect(top.art.width - 2 * HudLayout.TIER_UP.topRim).toBe(t.art.width)
			expect(top.header.x).toBe(top.rays.x + top.rays.width + HudLayout.TIER_UP.raysGap)
			local s = HudLayout.traitCard(slotSize)
			expect(s.card.width).toBe(420)
			expect(s.card.height).toBe(104)
			expect(s.art.width).toBe(80)
			expect(#s.tails).toBe(0)
		end
	)

	it("sets the S08 effect line in Body 24 and fits three food icons on the S07 row", function()
		expect(HudLayout.TRAIT_GAINED.type.line).toBe(24)
		local t = HudLayout.TIER_UP
		for _, top in { false, true } do
			local line = HudLayout.tierUpCard(slotSize, true, top).line :: Rect
			-- "New food:" at Small 22 is about 100 rpx in English; three icons follow it.
			expect(100 + 3 * (t.foodIcon + t.foodGap) <= line.width).toBe(true)
			expect(t.foodIcon <= line.height).toBe(true)
		end
	end)

	-- The phone the review captures: an iPhone 12 to 15 in landscape, 844 x 390 points with
	-- 47 point notch insets (Dev/HudHarness's simulated phone). What the engine draws for each
	-- S07 and S08 text, the prey icons and the badges, in rpx at that phone's scale.
	describe("on a real phone viewport, 844 x 390 with 47 px notches", function()
		local phone = screen(reading(true, false, 844, 390), 47)
		local scale = phone.scale
		local function drawn(rpx: number): number
			return ScreenScale.drawnPx(ScreenScale.textRpx(rpx, scale), scale) / scale
		end

		it("is the Phone class, so the review's capture is the real size", function()
			expect(phone.screenClass).toBe("Phone")
			expect(scale > 0.5 and scale < 0.7).toBe(true)
		end)

		it(
			"draws You grew! (moment.tier_up) and New food (moment.new_food) at 22 rpx or more",
			function()
				local t = HudLayout.TIER_UP
				expect(drawn(t.type.header) >= 24).toBe(true)
				expect(drawn(t.type.line) >= HudLayout.TEXT_FLOOR).toBe(true)
				-- In screen points: 12 for Small 22 and 13 for Body 24 at this phone's 0.542.
				expect(ScreenScale.drawnPx(ScreenScale.textRpx(t.type.line, scale), scale)).toBe(12)
				expect(ScreenScale.drawnPx(ScreenScale.textRpx(t.type.header, scale), scale)).toBe(
					13
				)
			end
		)

		it("draws every S07 and S08 text at its 08 §1.5 size or more and fits its row", function()
			for _, spec in { HudLayout.TIER_UP, HudLayout.TRAIT_GAINED } do
				for _, row in
					{
						{ spec.type.header, spec.headerHeight },
						{ spec.type.name, spec.nameHeight },
						{ spec.type.line, spec.lineHeight },
					}
				do
					expect(drawn(row[1]) >= row[1]).toBe(true)
					expect(ScreenScale.textRpx(row[1], scale) <= row[2]).toBe(true)
				end
			end
		end)

		it(
			"shows the food icons at 36 rpx (about 20 points) and the tier 7 badge at 104 against 96",
			function()
				expect(HudLayout.TIER_UP.foodIcon * scale >= 19).toBe(true)
				local t = HudLayout.tierUpCard(slotSize, true)
				local top = HudLayout.tierUpCard(slotSize, true, true)
				expect(top.art.width).toBe(104)
				expect(t.art.width).toBe(96)
				expect((top.art.width - t.art.width) * scale >= 4).toBe(true)
			end
		)
	end)
end)
describe(
	"HudLayout HUD.Traits and HUD.TraitMarkers (docs/08 sections 1.5, 3.3, 3.6, 3.10)",
	function()
		for name, layout in SCREENS do
			local content = layout.contentSize
			local box = { x = 0, y = 0, width = content.width, height = content.height }
			local rects = HudLayout.compute(layout.screenClass, content, layout.keepOut)
			local traits = HudLayout.traits(layout.screenClass, content)
			local min = HudLayout.minTarget(layout.screenClass)

			it(`{name}: the slots, their hits and their pips are inside the content box`, function()
				for i = 1, 3 do
					expect(inside(traits.slots[i], box)).toBe(true)
					expect(inside(traits.hits[i], box)).toBe(true)
					expect(inside(HudLayout.traitPipsRect(traits.slots[i]), box)).toBe(true)
				end
			end)

			it(`{name}: slot hit areas meet the minimum and keep 16 rpx apart`, function()
				for i = 1, 3 do
					expect(traits.hits[i].width >= min and traits.hits[i].height >= min).toBe(true)
				end
				for i = 1, 2 do
					local gap = traits.hits[i + 1].x - (traits.hits[i].x + traits.hits[i].width)
					expect(gap >= HudLayout.GAP_MIN - 1e-6).toBe(true)
				end
			end)

			it(
				`{name}: the row and pips stay out of the keep-clear box and clear the bottom`,
				function()
					for i = 1, 3 do
						local pips = HudLayout.traitPipsRect(traits.slots[i])
						expect(HudLayout.overlaps(pips, rects.keepClear)).toBe(false)
						expect(HudLayout.overlaps(traits.hits[i], rects.keepClear)).toBe(false)
						local fromSafeBottom = content.height
							+ HudLayout.MARGIN_BOTTOM
							- (traits.slots[i].y + traits.slots[i].height)
						expect(fromSafeBottom >= HudLayout.BOTTOM_TAP_CLEAR).toBe(true)
					end
				end
			)

			it(`{name}: the slot hits keep 16 rpx from dash, ability and the mass bar`, function()
				local others = {
					rects.massBar,
					rects.dashHit,
					HudLayout.hitRect(rects.ability, min),
				}
				for i = 1, 3 do
					for _, other in others do
						local grown = HudLayout.grow(traits.hits[i], HudLayout.GAP_MIN - 1e-6)
						expect(HudLayout.overlaps(grown, other)).toBe(false)
					end
				end
			end)

			it(`{name}: off-screen trait markers sit 40 rpx inside, clear of the edge`, function()
				local half = HudLayout.TRAIT_MARKER.size / 2
				for step = 0, 35 do
					local x, y = HudLayout.traitMarkerEdge(content, step * math.pi / 18)
					local marker =
						{ x = x - half, y = y - half, width = 2 * half, height = 2 * half }
					expect(inside(marker, box)).toBe(true)
					local fromEdge = math.min(x, y, content.width - x, content.height - y)
					expect(fromEdge).toBeCloseTo(HudLayout.TRAIT_MARKER.inset, 1e-6)
				end
			end)
		end

		it("puts the phone row where the element table says", function()
			local content = { width = 1251, height = 677 }
			local t = HudLayout.traits("Phone", content)
			expect(t.row.width).toBe(3 * 80 + 2 * 24)
			expect(t.row.x).toBe((1251 - t.row.width) / 2)
			expect(t.row.y + t.row.height).toBe(677 - 28)
			expect(t.slots[2].x + 40).toBe(1251 / 2)
			expect(t.hits[1].width).toBe(88)
		end)

		it("lays five pips (four with Keen Nose) on an arc centred above the slot", function()
			local slot = { x = 0, y = 0, width = 80, height = 80 }
			local five = HudLayout.traitPips(slot, 5)
			expect(#five).toBe(5)
			expect(five[3].x).toBeCloseTo(40, 1e-9)
			expect(five[3].y).toBeCloseTo(40 - 50, 1e-9)
			expect(five[1].x < five[2].x and five[4].x < five[5].x).toBe(true)
			expect(five[1].y).toBeCloseTo(five[5].y, 1e-9)
			local four = HudLayout.traitPips(slot, 4)
			expect(#four).toBe(4)
			expect((four[2].x + four[3].x) / 2).toBeCloseTo(40, 1e-9)
			-- No two pips touch.
			for i = 1, 4 do
				local dx, dy = five[i + 1].x - five[i].x, five[i + 1].y - five[i].y
				expect(math.sqrt(dx * dx + dy * dy) > HudLayout.TRAITS.pip).toBe(true)
			end
		end)
	end
)
