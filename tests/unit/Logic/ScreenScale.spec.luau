--!strict
local ScreenScale = require("../../../src/shared/Logic/ScreenScale")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type Reading = ScreenScale.Reading

local function reading(overrides: { [string]: unknown }): Reading
	local base: { [string]: unknown } = {
		displaySize = "Medium",
		viewportWidth = 1920,
		viewportHeight = 1080,
		touch = false,
		keyboard = true,
		mouse = true,
		gamepad = false,
	}
	for key, value in overrides do
		base[key] = value
	end
	return base :: any -- safe: every Reading field is set above and the overrides use the same keys
end

local function rect(x: number, y: number, width: number, height: number): ScreenScale.Rect
	return { x = x, y = y, width = width, height = height }
end

describe("ScreenScale.classify (docs/15 section 2.2, first match wins)", function()
	it("a Large display is a TV whatever else is true", function()
		expect(
			ScreenScale.classify(
				reading({ displaySize = "Large", touch = true, viewportHeight = 375 })
			)
		).toBe("TV")
	end)

	it("a Small display with a pad and a short side of 700 px or more is a Handheld", function()
		expect(
			ScreenScale.classify(
				reading({ displaySize = "Small", gamepad = true, viewportHeight = 700 })
			)
		).toBe("Handheld")
		expect(
			ScreenScale.classify(
				reading({ displaySize = "Small", gamepad = true, viewportHeight = 699 })
			)
		).toBe("Desktop")
		expect(
			ScreenScale.classify(
				reading({ displaySize = "Small", gamepad = false, viewportHeight = 800 })
			)
		).toBe("Desktop")
	end)

	it("touch with a short side under 500 px is a Phone", function()
		local phone =
			reading({ displaySize = "Small", touch = true, keyboard = false, mouse = false })
		phone.viewportWidth, phone.viewportHeight = 812, 375
		expect(ScreenScale.classify(phone)).toBe("Phone")
		phone.viewportHeight = 500
		expect(ScreenScale.classify(phone)).toBe("Tablet")
	end)

	it("the short side is the smaller dimension, whichever way round the viewport is", function()
		local phone = reading({
			touch = true,
			keyboard = false,
			mouse = false,
			viewportWidth = 375,
			viewportHeight = 812,
		})
		expect(ScreenScale.classify(phone)).toBe("Phone")
	end)

	it(
		"a touch phone with a pad is still a Phone, and the pad does not make a big phone a Handheld",
		function()
			local phone = reading({
				displaySize = "Small",
				touch = true,
				gamepad = true,
				viewportHeight = 390,
			})
			expect(ScreenScale.classify(phone)).toBe("Phone")
		end
	)

	it("touch without both keyboard and mouse is a Tablet", function()
		expect(
			ScreenScale.classify(
				reading({ touch = true, keyboard = false, mouse = false, viewportHeight = 768 })
			)
		).toBe("Tablet")
		expect(
			ScreenScale.classify(
				reading({ touch = true, keyboard = true, mouse = false, viewportHeight = 768 })
			)
		).toBe("Tablet")
	end)

	it("touch with keyboard and mouse, or no touch at all, is a Desktop", function()
		expect(ScreenScale.classify(reading({ touch = true, viewportHeight = 768 }))).toBe(
			"Desktop"
		)
		expect(ScreenScale.classify(reading({}))).toBe("Desktop")
	end)
end)

describe("ScreenScale.scale (docs/15 section 2.2)", function()
	-- The "scale at a typical size" row of docs/15 section 2.2, with a wide enough frame.
	it("matches the typical sizes in the bible", function()
		expect(ScreenScale.scale("Phone", 375, 812, 1)).toBeCloseTo(0.52, 0.005)
		expect(ScreenScale.scale("Tablet", 768, 1024, 1)).toBeCloseTo(0.69, 0.005)
		expect(ScreenScale.scale("Desktop", 1080, 1920, 1)).toBeCloseTo(0.90, 1e-9)
		expect(ScreenScale.scale("Handheld", 1080, 1920, 1)).toBeCloseTo(1.35, 1e-9)
		expect(ScreenScale.scale("Handheld", 800, 1280, 1)).toBeCloseTo(1.00, 1e-9)
		expect(ScreenScale.scale("TV", 1080, 1920, 1)).toBeCloseTo(1.20, 1e-9)
	end)

	it("matches the 4K row of docs/15 section 5.2", function()
		expect(ScreenScale.scale("Desktop", 2160, 3840, 1)).toBeCloseTo(1.80, 1e-9)
		expect(ScreenScale.scale("TV", 2160, 3840, 1)).toBeCloseTo(2.40, 1e-9)
	end)

	it("the width term keeps 1280 rpx visible in a narrow window", function()
		-- Height alone would give 1.20; 960 px wide only fits 1280 rpx at 0.75.
		expect(ScreenScale.scale("TV", 1080, 960, 1)).toBeCloseTo(0.75, 1e-9)
	end)

	it("clamps to 0.40 and 2.60", function()
		expect(ScreenScale.scale("Phone", 200, 400, 1)).toBe(0.40)
		expect(ScreenScale.scale("TV", 4320, 7680, 1.3)).toBe(2.60)
	end)

	it("multiplies by the Interface size, clamped to 0.8 to 1.3", function()
		expect(ScreenScale.scale("Desktop", 1080, 3840, 1.2)).toBeCloseTo(1.08, 1e-9)
		expect(ScreenScale.scale("Desktop", 1080, 3840, 5)).toBeCloseTo(0.90 * 1.3, 1e-9)
		expect(ScreenScale.scale("Desktop", 1080, 3840, 0.1)).toBeCloseTo(0.90 * 0.8, 1e-9)
	end)
end)

describe("ScreenScale.clampInterfaceSize", function()
	it("keeps values in range and replaces NaN with the default", function()
		expect(ScreenScale.clampInterfaceSize(1.1)).toBe(1.1)
		expect(ScreenScale.clampInterfaceSize(0)).toBe(0.8)
		expect(ScreenScale.clampInterfaceSize(2)).toBe(1.3)
		expect(ScreenScale.clampInterfaceSize(0 / 0)).toBe(1.0)
	end)
end)

describe("ScreenScale.safeFrame", function()
	it("is the whole safe area on a 16:9 phone or desktop", function()
		expect(ScreenScale.safeFrame("Phone", { width = 812, height = 375 })).toEqual(
			rect(0, 0, 812, 375)
		)
		expect(ScreenScale.safeFrame("Desktop", { width = 1920, height = 1080 })).toEqual(
			rect(0, 0, 1920, 1080)
		)
	end)

	it("takes a 5% margin on every side of a TV", function()
		expect(ScreenScale.safeFrame("TV", { width = 1920, height = 1080 })).toEqual(
			rect(96, 54, 1728, 972)
		)
	end)

	it("caps an ultrawide frame at 2.34 x its height, centred", function()
		local frame = ScreenScale.safeFrame("Desktop", { width = 3440, height = 1000 })
		expect(frame.width).toBeCloseTo(2340, 1e-9)
		expect(frame.x).toBeCloseTo(550, 1e-9)
		expect(frame.height).toBe(1000)
		-- 21:9 is 2.33, under the cap.
		expect(ScreenScale.safeFrame("Desktop", { width = 2520, height = 1080 }).width).toBe(2520)
	end)
end)

describe("ScreenScale.topbarKeepOut (docs/08 section 1.3, spike F11)", function()
	it("reserves what lies left of the free part of the top bar", function()
		-- Spike S10: TopbarInset leaves x 0 to 120, y 0 to 58 taken.
		local rects =
			ScreenScale.topbarKeepOut(rect(120, 0, 1800, 58), 1920, rect(0, 0, 1920, 1080))
		expect(rects).toEqual({ rect(0, 0, 120, 58) })
	end)

	it("reserves the right end too when the free part stops short of it", function()
		local rects =
			ScreenScale.topbarKeepOut(rect(120, 0, 1700, 58), 1920, rect(0, 0, 1920, 1080))
		expect(rects).toEqual({ rect(0, 0, 120, 58), rect(1820, 0, 100, 58) })
	end)

	it(
		"falls back to 200 x 58 px at the top left of the device safe area when not ready",
		function()
			local rects = ScreenScale.topbarKeepOut(rect(0, 0, 0, 0), 844, rect(47, 0, 750, 390))
			expect(rects).toEqual({ rect(47, 0, 200, 58) })
		end
	)
end)

describe("ScreenScale.toFrameRpx", function()
	it("moves a px rect into the frame and divides by the scale", function()
		expect(ScreenScale.toFrameRpx(rect(0, 0, 120, 58), rect(0, 0, 1920, 1080), 0.5)).toEqual(
			rect(0, 0, 240, 116)
		)
	end)

	it("clips to the frame and drops a rect outside it", function()
		expect(ScreenScale.toFrameRpx(rect(0, 0, 120, 58), rect(47, 0, 750, 390), 1)).toEqual(
			rect(0, 0, 73, 58)
		)
		expect(ScreenScale.toFrameRpx(rect(0, 0, 40, 58), rect(47, 0, 750, 390), 1)).toBe(nil)
	end)
end)

describe("ScreenScale.isTiny (docs/15 section 5.2)", function()
	it("is true below 512 x 288 in either dimension", function()
		expect(ScreenScale.isTiny(512, 288)).toBe(false)
		expect(ScreenScale.isTiny(511, 600)).toBe(true)
		expect(ScreenScale.isTiny(1024, 287)).toBe(true)
	end)
end)

describe("ScreenScale.compute", function()
	it("lays out a phone with a notch", function()
		local phone = reading({
			displaySize = "Small",
			touch = true,
			keyboard = false,
			mouse = false,
			viewportWidth = 750,
			viewportHeight = 375,
		})
		local layout = ScreenScale.compute(
			phone,
			{ width = 812, height = 375 },
			rect(47, 0, 750, 375),
			rect(120, 0, 692, 58),
			1
		)
		local scale = 375 / 720
		expect(layout.screenClass).toBe("Phone")
		expect(layout.scale).toBeCloseTo(scale, 1e-9)
		expect(layout.interfaceSize).toBe(1)
		expect(layout.safeFrame).toEqual(rect(0, 0, 750, 375))
		expect(layout.safeSize.height).toBeCloseTo(720, 1e-9)
		expect(layout.safeSize.width).toBeCloseTo(1440, 1e-9)
		expect(layout.fullSize.width).toBeCloseTo(812 / scale, 1e-9)
		expect(layout.contentSize.width).toBeCloseTo(1440 - 32, 1e-9)
		expect(layout.contentSize.height).toBeCloseTo(720 - 44, 1e-9)
		expect(#layout.keepOut).toBe(1)
		-- Measured from the content box, 16 rpx in from the safe frame on the left and top.
		expect(layout.keepOut[1].x).toBe(-16)
		expect(layout.keepOut[1].y).toBe(-16)
		expect(layout.keepOut[1].width).toBeCloseTo(73 / scale, 1e-9)
		expect(layout.keepOut[1].height).toBeCloseTo(58 / scale, 1e-9)
		expect(layout.tiny).toBe(false)
	end)

	it("measures a TV keep-out from inside the TV margins", function()
		local tv = reading({ displaySize = "Large", gamepad = true })
		local layout = ScreenScale.compute(
			tv,
			{ width = 1920, height = 1080 },
			rect(0, 0, 1920, 1080),
			rect(150, 0, 1770, 58),
			1
		)
		expect(layout.screenClass).toBe("TV")
		expect(layout.scale).toBeCloseTo(1.2, 1e-9)
		expect(layout.safeFrame).toEqual(rect(96, 54, 1728, 972))
		expect(#layout.keepOut).toBe(1)
		expect(layout.keepOut[1].x).toBe(-16)
		expect(layout.keepOut[1].y).toBe(-16)
		expect(layout.keepOut[1].width).toBeCloseTo(54 / 1.2, 1e-9)
		expect(layout.keepOut[1].height).toBeCloseTo(4 / 1.2, 1e-9)
	end)

	it("flags a tiny window", function()
		local small = reading({ viewportWidth = 500, viewportHeight = 280 })
		local layout = ScreenScale.compute(
			small,
			{ width = 500, height = 280 },
			rect(0, 0, 500, 280),
			rect(120, 0, 380, 58),
			1
		)
		expect(layout.tiny).toBe(true)
		expect(layout.scale).toBe(0.40)
	end)
end)

describe(
	"ScreenScale.textRpx (docs/08 section 1.5 text floor, rounded up to whole pixels)",
	function()
		it("lifts the 22 rpx floor on the 844 x 390 phone (scale 0.542) to 12 px drawn", function()
			local size = ScreenScale.textRpx(22, 0.542)
			expect(ScreenScale.drawnPx(size, 0.542)).toBe(12)
			expect(ScreenScale.drawnPx(size, 0.542) / 0.542 >= 22).toBe(true)
		end)

		it("keeps the size at scale 1 and on exact pixels", function()
			expect(ScreenScale.textRpx(22, 1)).toBe(22)
			expect(ScreenScale.textRpx(22, 0.5)).toBe(22)
			expect(ScreenScale.textRpx(28, 1.5)).toBe(28)
		end)

		it("never draws under ceil(rpx x scale) at any scale from 0.40 to 2.60", function()
			for _, rpx in { 22, 24, 28, 40, 64 } do
				for step = 0, 220 do
					local scale = 0.40 + step * 0.01
					local size = ScreenScale.textRpx(rpx, scale)
					expect(size >= rpx).toBe(true)
					expect(ScreenScale.drawnPx(size, scale) >= math.ceil(rpx * scale - 1e-6)).toBe(
						true
					)
				end
			end
		end)
	end
)

describe("ScreenScale.wholePxRpx (text strokes in whole pixels)", function()
	it("draws a 2 rpx stroke as 2 px on the phone and keeps it at scale 1", function()
		expect(math.abs(ScreenScale.wholePxRpx(2, 0.542) * 0.542 - 2) < 1e-9).toBe(true)
		expect(ScreenScale.wholePxRpx(2, 1)).toBe(2)
		expect(ScreenScale.wholePxRpx(2, 1.5)).toBe(2)
	end)
end)
