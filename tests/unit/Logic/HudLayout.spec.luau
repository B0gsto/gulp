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
