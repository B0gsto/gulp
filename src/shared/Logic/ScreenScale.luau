--!strict
-- ScreenScale: the pure half of the screen class and the interface scale (docs/15, sections 2.2
-- and 5.2; docs/08, sections 1.2 and 1.3). Numbers and tables only, so it runs in Lune.
--
-- The engine half is `client/UI/Kit/Screen`: it reads the device, feeds a `Reading` and the
-- measured rects in here, and applies the returned `Layout` to every ScreenGui layer.
--
-- Coordinates: every px rect is in interface pixels with the origin at the top left of the full
-- screen (a ScreenGui with `ScreenInsets = None`), unless a field says otherwise. rpx are the
-- reference pixels of the 1280 x 720 canvas (docs/08, section 1.2): px = rpx x scale.

export type ScreenClass = "Phone" | "Tablet" | "Desktop" | "Handheld" | "TV"

-- `GuiService.ViewportDisplaySize` (docs/15, PF19).
export type DisplaySize = "Small" | "Medium" | "Large"

export type Rect = { x: number, y: number, width: number, height: number }
export type Size = { width: number, height: number }

-- The raw values the class is worked out from. The client logs them once per session
-- (`sess_device`, docs/15 section 4.4) so the class table can be corrected from real data.
export type Reading = {
	displaySize: DisplaySize,
	-- `Camera.ViewportSize`: the device safe area in interface pixels (docs/15, PF22).
	viewportWidth: number,
	viewportHeight: number,
	touch: boolean,
	keyboard: boolean,
	mouse: boolean,
	gamepad: boolean,
}

export type Layout = {
	screenClass: ScreenClass,
	scale: number,
	interfaceSize: number,
	-- The safe frame in px, relative to the top left of the device safe area: the area a
	-- `DeviceSafeInsets` layer roots its scaled frame in (TV margins and the ultrawide cap applied).
	safeFrame: Rect,
	-- The safe frame and the full screen measured in rpx: the sizes of the two kinds of root frame.
	safeSize: Size,
	fullSize: Size,
	-- The safe frame less its margins (docs/08 section 1.3), in rpx: the content box children of
	-- a `DeviceSafeInsets` root are laid out in.
	contentSize: Size,
	-- The top left of the content box in rpx of the full screen (a `None` layer's root), so the
	-- markers of the full-screen `GulpWorld` layer can be clamped into the safe frame.
	contentOrigin: { x: number, y: number },
	-- The occupied parts of the Roblox top bar in rpx, clipped to the safe frame and measured from
	-- the top left of the content box (so a rect may start at a negative x or y, inside the
	-- margin). Nothing persistent may overlap them (docs/08 section 1.3; spike F11).
	keepOut: { Rect },
	-- Below the tiny window size the HUD hides `HUD.Biggest` and the toast stack (docs/15, 5.2).
	tiny: boolean,
}

local ScreenScale = {}

-- docs/08 section 1.2: the reference canvas, in rpx.
ScreenScale.REFERENCE_WIDTH = 1280
ScreenScale.REFERENCE_HEIGHT = 720

-- docs/15 section 2.2: the clamp on the final scale.
ScreenScale.SCALE_MIN = 0.40
ScreenScale.SCALE_MAX = 2.60

-- docs/15 section 2.2: the Interface size setting [L].
ScreenScale.INTERFACE_SIZE_MIN = 0.8
ScreenScale.INTERFACE_SIZE_MAX = 1.3
ScreenScale.INTERFACE_SIZE_DEFAULT = 1.0

-- docs/15 section 2.2: deviceFactor by screen class (tune).
ScreenScale.DEVICE_FACTOR = table.freeze({
	TV = 0.80,
	Handheld = 0.90,
	Phone = 1.00,
	Tablet = 0.65,
	Desktop = 0.60,
}) :: { [ScreenClass]: number } -- safe: the table has exactly one key per ScreenClass

-- docs/15 section 2.2: the short-side tests, in interface pixels.
ScreenScale.HANDHELD_MIN_SHORT_SIDE = 700
ScreenScale.PHONE_MAX_SHORT_SIDE = 500 -- Phone when the short side is under this

-- docs/15 sections 2.2 and 5.2: seconds with no further viewport change before a recompute.
ScreenScale.RECOMPUTE_DEBOUNCE = 0.25

-- docs/08 section 1.3: safe frame margins inside the device safe area, in rpx.
ScreenScale.MARGIN_TOP = 16
ScreenScale.MARGIN_SIDE = 16
ScreenScale.MARGIN_BOTTOM = 28
-- docs/08 section 1.3: tappable elements keep this far from the bottom of the device safe area.
ScreenScale.BOTTOM_TAP_CLEARANCE = 40
-- docs/15 section 2.2: on a Tablet the touch buttons sit this much further in, in rpx.
ScreenScale.TABLET_TOUCH_INSET = 24

-- docs/15 section 2.2: TV margins, as a fraction of each screen dimension on each side.
ScreenScale.TV_MARGIN = 0.05
-- docs/15 section 5.2: the HUD frame is capped at this many times its height, and centred.
ScreenScale.ULTRAWIDE_MAX_ASPECT = 2.34

-- docs/08 section 1.3: the keep-out box when `TopbarInset` is not ready, in px (tune).
ScreenScale.TOPBAR_FALLBACK_WIDTH = 200
ScreenScale.TOPBAR_FALLBACK_HEIGHT = 58

-- docs/15 section 5.2: below this window size the HUD drops `HUD.Biggest` and the toasts.
ScreenScale.TINY_WIDTH = 512
ScreenScale.TINY_HEIGHT = 288

--- The screen class, by the first matching test of docs/15 section 2.2.
local function classify(reading: Reading): ScreenClass
	local shortSide = math.min(reading.viewportWidth, reading.viewportHeight)
	if reading.displaySize == "Large" then
		return "TV"
	end
	if
		reading.displaySize == "Small"
		and reading.gamepad
		and shortSide >= ScreenScale.HANDHELD_MIN_SHORT_SIDE
	then
		return "Handheld"
	end
	if reading.touch and shortSide < ScreenScale.PHONE_MAX_SHORT_SIDE then
		return "Phone"
	end
	if reading.touch and not (reading.keyboard and reading.mouse) then
		return "Tablet"
	end
	return "Desktop"
end
ScreenScale.classify = classify

--- The Interface size setting clamped to its range; NaN gives the default.
function ScreenScale.clampInterfaceSize(value: number): number
	if value ~= value then
		return ScreenScale.INTERFACE_SIZE_DEFAULT
	end
	return math.clamp(value, ScreenScale.INTERFACE_SIZE_MIN, ScreenScale.INTERFACE_SIZE_MAX)
end

--- The scale formula of docs/15 section 2.2 (docs/08 section 1.2):
--- clamp(min(viewportHeight / 720 x deviceFactor x interfaceSize, safeFrameWidth / 1280), 0.40, 2.60).
function ScreenScale.scale(
	screenClass: ScreenClass,
	viewportHeight: number,
	safeFrameWidth: number,
	interfaceSize: number
): number
	local heightScale = (viewportHeight / ScreenScale.REFERENCE_HEIGHT)
		* ScreenScale.DEVICE_FACTOR[screenClass]
		* ScreenScale.clampInterfaceSize(interfaceSize)
	local widthScale = safeFrameWidth / ScreenScale.REFERENCE_WIDTH
	return math.clamp(
		math.min(heightScale, widthScale),
		ScreenScale.SCALE_MIN,
		ScreenScale.SCALE_MAX
	)
end

--- The TextSize (rpx) to give a label so that text of `rpx` drawn at `scale` keeps at least
--- ceil(rpx x scale) whole pixels. The engine draws a scaled TextSize floored to whole pixels,
--- so a 22 rpx label at scale 0.542 (11.9 px) would draw 11 px, 20 rpx, under the 22 rpx floor
--- of docs/08 section 1.5. Rounding up holds the floor at every scale.
function ScreenScale.textRpx(rpx: number, scale: number): number
	if scale <= 0 then
		return rpx
	end
	local px = math.ceil(rpx * scale - 1e-6)
	return math.max(rpx, math.ceil(px / scale))
end

--- A length of `rpx` rounded up to whole pixels at `scale`, in rpx: a text stroke of 2 rpx at
--- scale 0.542 (1.08 px) draws 2 px, so the dark outline of docs/08 section 1.5 never thins out.
function ScreenScale.wholePxRpx(rpx: number, scale: number): number
	if scale <= 0 then
		return rpx
	end
	return math.max(1, math.ceil(rpx * scale - 1e-6)) / scale
end

--- The whole pixels the engine draws a `textSize` rpx label at `scale` (floored).
function ScreenScale.drawnPx(textSize: number, scale: number): number
	return math.floor(textSize * scale + 1e-6)
end

--- The safe frame inside a device safe area of the given size, relative to its top left: the TV
--- margins on a TV, then the ultrawide cap, centred.
function ScreenScale.safeFrame(screenClass: ScreenClass, safeAreaSize: Size): Rect
	local x, y = 0, 0
	local width, height = safeAreaSize.width, safeAreaSize.height
	if screenClass == "TV" then
		local marginX = width * ScreenScale.TV_MARGIN
		local marginY = height * ScreenScale.TV_MARGIN
		x, y = marginX, marginY
		width, height = width - 2 * marginX, height - 2 * marginY
	end
	local maxWidth = height * ScreenScale.ULTRAWIDE_MAX_ASPECT
	if width > maxWidth then
		x += (width - maxWidth) / 2
		width = maxWidth
	end
	return { x = x, y = y, width = width, height = height }
end

--- The occupied parts of the Roblox top bar in screen px. `topbar` is `GuiService.TopbarInset`:
--- the free part of the top bar, so what lies left and right of it along its height is taken.
--- When it is not ready (no width or no height) the fallback box sits at the top left of the
--- device safe area.
function ScreenScale.topbarKeepOut(topbar: Rect, screenWidth: number, safeArea: Rect): { Rect }
	if topbar.width <= 0 or topbar.height <= 0 then
		return {
			{
				x = safeArea.x,
				y = safeArea.y,
				width = ScreenScale.TOPBAR_FALLBACK_WIDTH,
				height = ScreenScale.TOPBAR_FALLBACK_HEIGHT,
			},
		}
	end
	local bottom = topbar.y + topbar.height
	local rects: { Rect } = {}
	if topbar.x > 0 then
		table.insert(rects, { x = 0, y = 0, width = topbar.x, height = bottom })
	end
	local right = topbar.x + topbar.width
	if right < screenWidth then
		table.insert(rects, { x = right, y = 0, width = screenWidth - right, height = bottom })
	end
	return rects
end

--- A screen px rect as rpx relative to `frame` (screen px), clipped to the frame. Nil when the
--- two do not overlap.
function ScreenScale.toFrameRpx(rect: Rect, frame: Rect, scale: number): Rect?
	local left = math.max(rect.x, frame.x)
	local top = math.max(rect.y, frame.y)
	local right = math.min(rect.x + rect.width, frame.x + frame.width)
	local bottom = math.min(rect.y + rect.height, frame.y + frame.height)
	if right <= left or bottom <= top then
		return nil
	end
	return {
		x = (left - frame.x) / scale,
		y = (top - frame.y) / scale,
		width = (right - left) / scale,
		height = (bottom - top) / scale,
	}
end

--- True when the window is smaller than the tiny size in either dimension.
function ScreenScale.isTiny(width: number, height: number): boolean
	return width < ScreenScale.TINY_WIDTH or height < ScreenScale.TINY_HEIGHT
end

--- Everything a layer needs, from one reading. `screen` is the full screen size, `safeArea` the
--- device safe area in screen px, `topbar` the raw `GuiService.TopbarInset` in screen px.
function ScreenScale.compute(
	reading: Reading,
	screen: Size,
	safeArea: Rect,
	topbar: Rect,
	interfaceSize: number
): Layout
	local screenClass: ScreenClass = classify(reading)
	local size = ScreenScale.clampInterfaceSize(interfaceSize)
	local frame =
		ScreenScale.safeFrame(screenClass, { width = safeArea.width, height = safeArea.height })
	local scale = ScreenScale.scale(screenClass, reading.viewportHeight, frame.width, size)

	local frameOnScreen = {
		x = safeArea.x + frame.x,
		y = safeArea.y + frame.y,
		width = frame.width,
		height = frame.height,
	}
	local keepOut: { Rect } = {}
	for _, rect in ScreenScale.topbarKeepOut(topbar, screen.width, safeArea) do
		local inFrame = ScreenScale.toFrameRpx(rect, frameOnScreen, scale)
		if inFrame then
			inFrame.x -= ScreenScale.MARGIN_SIDE
			inFrame.y -= ScreenScale.MARGIN_TOP
			table.insert(keepOut, inFrame)
		end
	end

	return {
		screenClass = screenClass,
		scale = scale,
		interfaceSize = size,
		safeFrame = frame,
		safeSize = { width = frame.width / scale, height = frame.height / scale },
		contentSize = {
			width = frame.width / scale - 2 * ScreenScale.MARGIN_SIDE,
			height = frame.height / scale - ScreenScale.MARGIN_TOP - ScreenScale.MARGIN_BOTTOM,
		},
		contentOrigin = {
			x = (safeArea.x + frame.x) / scale + ScreenScale.MARGIN_SIDE,
			y = (safeArea.y + frame.y) / scale + ScreenScale.MARGIN_TOP,
		},
		fullSize = { width = screen.width / scale, height = screen.height / scale },
		keepOut = keepOut,
		tiny = ScreenScale.isTiny(reading.viewportWidth, reading.viewportHeight),
	}
end

return table.freeze(ScreenScale)
