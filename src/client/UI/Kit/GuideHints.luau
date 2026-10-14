--!strict
-- Kit/GuideHints: code-drawn stand-ins for the control pictures of the guide kit (docs/08 section
-- 7, G3 and G8, and the images of section 13.11 and 13.12; docs/04 section 3.2): key caps, the
-- mouse, the arrow keys, the gamepad stick and buttons, the hand and the ghost thumbprint. Each
-- carries the empty slot named after its 08 §13 image (`Draw.slot`), so the art drops in without
-- layout changes. Sizes are rpx; every picture fits the 64 rpx input hint (G8) unless noted.
--
-- Keys come from docs/15 section 3.3 (W swims, Space dashes, E is the ability, the arrow keys
-- steer) and pad buttons from the same table (A dashes, X is the ability, the left stick swims).
-- Key cap letters are the engine's (`GetStringForKeyCode`), so W reads Z on an AZERTY keyboard.
local UserInputService = game:GetService("UserInputService")

local Draw = require("./Draw")
local Theme = require("./Theme")

local GuideHints = {}

export type Action = "swim" | "dash" | "ability" | "tap"
export type InputMode = "Touch" | "Keys" | "Pad"

-- docs/15 section 3.3.
local KEYS: { [Action]: Enum.KeyCode } = {
	swim = Enum.KeyCode.W,
	dash = Enum.KeyCode.Space,
	ability = Enum.KeyCode.E,
}
local PAD: { [Action]: Enum.KeyCode } = {
	swim = Enum.KeyCode.Thumbstick1,
	dash = Enum.KeyCode.ButtonA,
	ability = Enum.KeyCode.ButtonX,
	tap = Enum.KeyCode.ButtonA,
}
-- The letter printed on a stand-in pad button (part of the picture, as on `UI_Hint_PadA`).
local PAD_LETTER: { [string]: string } =
	{ ButtonA = "A", ButtonB = "B", ButtonX = "X", ButtonY = "Y" }
-- Xbox colours for the stand-in face buttons (the real glyphs are art, [L]).
local PAD_COLOUR: { [string]: Color3 } = {
	ButtonA = Color3.fromHex("#5FD08A"),
	ButtonB = Theme.DECLINE,
	ButtonX = Color3.fromHex("#4C8DFF"),
	ButtonY = Theme.PRIMARY,
}

GuideHints.CAP = 56 -- a key cap's face, inside the 64 hint
GuideHints.SPACE = 120 -- the Space bar cap stretches (08 §13.12 `UI_Hint_Key`)
GuideHints.ROW_GAP = 8

--- The engine's label for `keyCode` on this keyboard ("" for keys it does not name, like Space).
function GuideHints.keyLabel(keyCode: Enum.KeyCode): string
	local ok, text = pcall(function()
		return UserInputService:GetStringForKeyCode(keyCode)
	end)
	if ok and type(text) == "string" and string.match(text, "%S") then
		return text
	end
	return ""
end

--- The `{Button}` of a `guide.*` string (08 §14.11, "a key picture"): the key or button the
--- action uses in `mode`, as the engine names it.
function GuideHints.buttonText(action: Action, mode: InputMode): string
	local code = if mode == "Pad" then PAD[action] else KEYS[action]
	if code == nil then
		return ""
	end
	local label = if mode == "Pad" then PAD_LETTER[code.Name] else GuideHints.keyLabel(code)
	return if label and label ~= "" then label else code.Name
end

local function bar(
	parent: Instance,
	w: number,
	h: number,
	x: number,
	y: number,
	rotation: number,
	colour: Color3,
	z: number
): Frame
	return Draw.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Rotation = rotation,
		BackgroundColor3 = colour,
		BackgroundTransparency = 0,
		ZIndex = z,
		Parent = parent,
	}, { Draw.corner() }) :: Frame
end

--- A right-pointing triangle `size` deep and `2 x size` tall, centred at `position`: a square
--- turned 45 degrees with its left half cut away by a hard gradient (the trick of `Draw.wedge`),
--- stroke included. Turn it with the parent.
function GuideHints.triangle(
	parent: Instance,
	size: number,
	colour: Color3,
	position: UDim2,
	z: number,
	stroke: number?
): Frame
	local holder = Draw.new("Frame", {
		Name = "Triangle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size, size * 2),
		ZIndex = z,
		Parent = parent,
	}) :: Frame
	local side = size * math.sqrt(2)
	local square = Draw.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(side, side),
		Rotation = 45,
		BackgroundColor3 = colour,
		BackgroundTransparency = 0,
		ZIndex = z,
		Parent = holder,
	}, { Draw.corner(size * 0.12) }) :: Frame
	-- Opaque on the right half of the parent's view: the square's own axis is turned 45 degrees,
	-- so the cut runs along its diagonal at -45.
	local cut = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(0.5001, 0),
		NumberSequenceKeypoint.new(1, 0),
	})
	Draw.new("UIGradient", { Transparency = cut, Rotation = -45, Parent = square })
	if stroke then
		local s = Draw.stroke(stroke)
		Draw.new("UIGradient", { Transparency = cut, Rotation = -45, Parent = s })
		s.Parent = square
	end
	return holder
end

--- `UI_Hint_Key`: a cream key cap `width` x 56 on a navy lip (no grey: it reads on the sun-yellow
--- chips and on bright water, UI review 1), the label in Fredoka. Returns the cap and its face
--- (tint the face to show it pressed).
function GuideHints.keyCap(
	parent: Instance,
	label: string,
	width: number?,
	z: number?
): (Frame, Frame)
	local zi = z or 4
	local w = width or GuideHints.CAP
	local h = GuideHints.CAP
	local cap = Draw.new(
		"Frame",
		{ Name = "KeyCap", Size = UDim2.fromOffset(w, h + 4), ZIndex = zi, Parent = parent }
	) :: Frame
	Draw.new("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Theme.INK,
		BackgroundTransparency = 0,
		ZIndex = zi,
		Parent = cap,
	}, { Draw.corner(10), Draw.stroke(Theme.STROKE_CHIP) })
	local face = Draw.new("Frame", {
		Name = "Face",
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Theme.PANEL,
		BackgroundTransparency = 0,
		ZIndex = zi + 1,
		Parent = cap,
	}, { Draw.corner(10), Draw.stroke(Theme.STROKE_CHIP) }) :: Frame
	if label ~= "" then
		Draw.text({
			Name = "Label",
			Size = UDim2.fromScale(1, 1),
			Text = label,
			ZIndex = zi + 2,
			Parent = face,
		}, Theme.TEXT.number, "display")
	end
	Draw.slot("UI_Hint_Key", face, zi + 3)
	return cap, face
end

--- The dash mark of `HUD.Dash` in small (08 §3.7): a sun-yellow disc with two navy chevrons, so
--- the Space cap matches the button it points at.
function GuideHints.dashMark(parent: Instance, size: number, position: UDim2, z: number): Frame
	local disc =
		Draw.disc(size, Theme.PRIMARY, position, { Name = "DashMark", ZIndex = z, Parent = parent })
	Draw.stroke(Theme.STROKE_CHIP).Parent = disc
	local len = size * 0.36
	local thick = size * 0.14
	for _, dx in { -0.15, 0.13 } do
		for _, r in { 45, -45 } do
			local y = size * 0.5 + (if r > 0 then -len * 0.33 else len * 0.33)
			bar(disc, len, thick, size * (0.5 + dx), y, r, Theme.INK, z + 1)
		end
	end
	return disc
end

--- `UI_Hint_Key` stretched for Space (`width` x 56): the dash mark at its left and the space-bar
--- sign (a navy bracket open upward) beside it, since the engine names no label for Space.
function GuideHints.spaceCap(parent: Instance, width: number, z: number?): (Frame, Frame)
	local zi = z or 4
	local cap, face = GuideHints.keyCap(parent, "", width, zi)
	local h = GuideHints.CAP
	GuideHints.dashMark(face, 36, UDim2.fromOffset(12 + 18, h / 2), zi + 2)
	local signX = 12 + 36 + (width - 12 - 36) / 2
	local signW = math.min(48, width - 36 - 36)
	bar(face, signW, 6, signX, h / 2 + 8, 0, Theme.INK, zi + 2)
	for _, side in { -1, 1 } do
		bar(face, 6, 16, signX + side * (signW / 2 - 3), h / 2 + 3, 0, Theme.INK, zi + 2)
	end
	return cap, face
end

--- `UI_Hint_MouseMove`, `UI_Hint_MouseLeft` or `UI_Hint_MouseRight`: a white mouse 40 x 56,
--- the lit button sun yellow, or small arrows either side for "move".
function GuideHints.mouse(parent: Instance, kind: "move" | "left" | "right", z: number?): Frame
	local zi = z or 4
	local holder = Draw.new("Frame", {
		Name = "Mouse",
		Size = UDim2.fromOffset(if kind == "move" then 64 else 44, 64),
		ZIndex = zi,
		Parent = parent,
	}) :: Frame
	local body = Draw.new("Frame", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(40, 56),
		BackgroundColor3 = Theme.WHITE,
		BackgroundTransparency = 0,
		ZIndex = zi,
		Parent = holder,
	}, { Draw.corner(20), Draw.stroke(Theme.STROKE_CHIP) }) :: Frame
	if kind ~= "move" then
		Draw.new("Frame", {
			Name = "Lit",
			Position = UDim2.fromOffset(if kind == "left" then 3 else 20, 3),
			Size = UDim2.fromOffset(17, 21),
			BackgroundColor3 = Theme.PRIMARY,
			BackgroundTransparency = 0,
			ZIndex = zi + 1,
			Parent = body,
		}, { Draw.corner(8) })
	end
	bar(body, 2, 22, 20, 13, 0, Theme.INK, zi + 2)
	bar(body, 36, 2, 20, 24, 0, Theme.INK, zi + 2)
	if kind == "move" then
		for _, side in { -1, 1 } do
			local t = Draw.new("Frame", {
				Position = UDim2.new(0.5, side * 28, 0.5, 0),
				Size = UDim2.fromOffset(0, 0),
				Rotation = if side < 0 then 180 else 0,
				ZIndex = zi,
				Parent = holder,
			})
			GuideHints.triangle(t, 7, Theme.INK, UDim2.fromOffset(0, 0), zi)
		end
	end
	Draw.slot(
		if kind == "move"
			then "UI_Hint_MouseMove"
			elseif kind == "left" then "UI_Hint_MouseLeft"
			else "UI_Hint_MouseRight",
		holder,
		zi + 3
	)
	return holder
end

GuideHints.ARROWS_GAP = 4
-- The four arrow caps in a row: ← ↑ ↓ → (UI review 2: an inverted T in 64 rpx drew 28 rpx caps).
GuideHints.ARROWS = 4 * GuideHints.CAP + 3 * GuideHints.ARROWS_GAP

--- `UI_Hint_KeyArrows` (08 §13.12, 236 x 64): the four arrow keys as full key caps in a row, each
--- with a bold navy arrow, the same cream face and navy lip as the other caps.
function GuideHints.arrows(parent: Instance, z: number?): Frame
	local zi = z or 4
	local holder = Draw.new("Frame", {
		Name = "Arrows",
		Size = UDim2.fromOffset(GuideHints.ARROWS, 64),
		ZIndex = zi,
		Parent = parent,
	}) :: Frame
	for i, rotation in { 180, -90, 90, 0 } do
		local cap, face = GuideHints.keyCap(holder, "", nil, zi)
		cap.Name = "ArrowKey"
		cap.Position = UDim2.fromOffset((i - 1) * (GuideHints.CAP + GuideHints.ARROWS_GAP), 2)
		local turn = Draw.new("Frame", {
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(0, 0),
			Rotation = rotation,
			ZIndex = zi + 2,
			Parent = face,
		})
		-- Drawn pointing right: a shaft and a head, 28 rpx end to end.
		bar(turn, 18, 8, -4, 0, 0, Theme.INK, zi + 2)
		GuideHints.triangle(turn, 12, Theme.INK, UDim2.fromOffset(8, 0), zi + 2)
	end
	Draw.slot("UI_Hint_KeyArrows", holder, zi + 3)
	return holder
end

--- `UI_Hint_PadLStick`: a grey stick ring with its cap; returns the holder and the cap (nudge
--- the cap to show the push).
function GuideHints.stick(parent: Instance, z: number?): (Frame, Frame)
	local zi = z or 4
	local holder = Draw.new(
		"Frame",
		{ Name = "Stick", Size = UDim2.fromOffset(64, 64), ZIndex = zi, Parent = parent }
	) :: Frame
	local base = Draw.disc(56, Theme.DISABLED, nil, { ZIndex = zi, Parent = holder })
	Draw.stroke(Theme.STROKE_CHIP).Parent = base
	local cap = Draw.disc(
		34,
		Theme.INK:Lerp(Theme.DISABLED, 0.35),
		nil,
		{ Name = "Cap", ZIndex = zi + 1, Parent = holder }
	)
	Draw.stroke(Theme.STROKE_CHIP, Theme.INK).Parent = cap
	Draw.slot("UI_Hint_PadLStick", holder, zi + 3)
	return holder, cap
end

--- `UI_Hint_PadA` and the other face buttons: a coloured disc with its letter.
function GuideHints.padButton(parent: Instance, keyCode: Enum.KeyCode, z: number?): Frame
	local zi = z or 4
	local name = keyCode.Name
	local holder = Draw.new(
		"Frame",
		{ Name = "PadButton", Size = UDim2.fromOffset(64, 64), ZIndex = zi, Parent = parent }
	) :: Frame
	local disc =
		Draw.disc(52, PAD_COLOUR[name] or Theme.DISABLED, nil, { ZIndex = zi, Parent = holder })
	Draw.stroke(Theme.STROKE_CHIP).Parent = disc
	Draw.text({
		Size = UDim2.fromScale(1, 1),
		Text = PAD_LETTER[name] or "",
		TextColor3 = Theme.WHITE,
		ZIndex = zi + 1,
		Parent = disc,
	}, Theme.TEXT.number, "display", Theme.STROKE_TEXT)
	Draw.slot("UI_Hint_Pad" .. string.gsub(name, "^Button", ""), holder, zi + 3)
	return holder
end

--- `UI_Guide_Hand` (G3): a white cartoon hand with one finger out, `size` rpx. Its fingertip is
--- at `GuideHints.FINGERTIP` of the frame: anchor the frame there to press a point.
GuideHints.FINGERTIP = Vector2.new(0.3, 0.06)
function GuideHints.hand(parent: Instance, size: number, z: number?): Frame
	local zi = z or 4
	local holder = Draw.new("Frame", {
		Name = "Hand",
		AnchorPoint = GuideHints.FINGERTIP,
		Size = UDim2.fromOffset(size, size),
		ZIndex = zi,
		Parent = parent,
	}) :: Frame
	local s = size / 112
	local function piece(
		name: string,
		x: number,
		y: number,
		w: number,
		h: number,
		r: number,
		rot: number?
	)
		Draw.new("Frame", {
			Name = name,
			Position = UDim2.fromOffset(x * s, y * s),
			Size = UDim2.fromOffset(w * s, h * s),
			Rotation = rot or 0,
			BackgroundColor3 = Theme.WHITE,
			BackgroundTransparency = 0,
			ZIndex = zi,
			Parent = holder,
		}, { Draw.corner(r * s), Draw.stroke(Theme.STROKE_ICON) })
	end
	-- Folded fingers behind, then the pointing finger, the palm and the thumb.
	piece("Fingers", 46, 40, 44, 26, 12)
	piece("Finger", 24, 2, 22, 64, 11)
	piece("Palm", 22, 50, 66, 54, 22)
	piece("Thumb", 8, 58, 24, 36, 12, -28)
	-- The palm hides the finger's and the fingers' lower strokes; a cuff line closes the wrist.
	Draw.new("Frame", {
		Name = "Cuff",
		Position = UDim2.fromOffset(30 * s, 96 * s),
		Size = UDim2.fromOffset(50 * s, 10 * s),
		BackgroundColor3 = Theme.SECONDARY,
		BackgroundTransparency = 0,
		ZIndex = zi + 1,
		Parent = holder,
	}, { Draw.corner(5 * s), Draw.stroke(Theme.STROKE_CHIP) })
	Draw.slot("UI_Guide_Hand", holder, zi + 3)
	return holder
end

--- `UI_Guide_GhostThumb` (04 §3.2): a bright white thumbprint, `size` rpx, centred on its point
--- (the prompt draws it at 90%).
function GuideHints.thumbprint(parent: Instance, size: number, z: number?): Frame
	local zi = z or 4
	local holder = Draw.new("Frame", {
		Name = "Thumbprint",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		ZIndex = zi,
		Parent = parent,
	}) :: Frame
	local pad = Draw.new("Frame", {
		Name = "Pad",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 0.7, size * 0.9),
		BackgroundColor3 = Theme.WHITE,
		BackgroundTransparency = 0,
		ZIndex = zi,
		Parent = holder,
	}, { Draw.corner(), Draw.stroke(Theme.STROKE_ICON) }) :: Frame
	-- The whorl: three rings inside the pad.
	for i, share in { 0.72, 0.48, 0.24 } do
		local ring = Draw.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.56),
			Size = UDim2.fromScale(share, share * 0.92),
			ZIndex = zi + i,
			Parent = pad,
		}, { Draw.corner() }) :: Frame
		local stroke = Draw.stroke(2, Theme.SECONDARY_SHADE)
		stroke.Transparency = 0.2
		stroke.Parent = ring
	end
	Draw.slot("UI_Guide_GhostThumb", holder, zi + 5)
	return holder
end

export type Picture = {
	root: Frame,
	width: number,
	-- The face to darken for a key press, or the stick cap to nudge; nil when there is none.
	face: Frame?,
	cap: Frame?,
}

--- G8: the picture for `action` in `mode`, in a frame 64 tall (`width` wide): the hand (or the
--- thumbprint for swimming) on touch, the key cap or mouse button with keys, the pad glyph on a pad.
function GuideHints.picture(parent: Instance, action: Action, mode: InputMode, z: number?): Picture
	local zi = z or 4
	local root = Draw.new(
		"Frame",
		{ Name = "Picture", Size = UDim2.fromOffset(64, 64), ZIndex = zi, Parent = parent }
	) :: Frame
	if mode == "Touch" then
		if action == "swim" then
			local t = GuideHints.thumbprint(root, 64, zi)
			t.Position = UDim2.fromScale(0.5, 0.5)
		else
			local h = GuideHints.hand(root, 64, zi)
			h.AnchorPoint = Vector2.new(0.5, 0.5)
			h.Position = UDim2.fromScale(0.5, 0.5)
		end
		return { root = root, width = 64 }
	elseif mode == "Pad" then
		local code = PAD[action]
		if code == Enum.KeyCode.Thumbstick1 then
			local _, cap = GuideHints.stick(root, zi)
			return { root = root, width = 64, cap = cap }
		end
		GuideHints.padButton(root, code, zi)
		return { root = root, width = 64 }
	end
	local key = KEYS[action]
	if key == nil then
		local m = GuideHints.mouse(root, "left", zi)
		m.AnchorPoint = Vector2.new(0.5, 0.5)
		m.Position = UDim2.fromScale(0.5, 0.5)
		return { root = root, width = 64 }
	end
	local wide = key == Enum.KeyCode.Space
	local width = if wide then GuideHints.SPACE else GuideHints.CAP
	root.Size = UDim2.fromOffset(width, 64)
	local cap, face
	if wide then
		cap, face = GuideHints.spaceCap(root, width, zi)
	else
		cap, face = GuideHints.keyCap(root, GuideHints.keyLabel(key), width, zi)
	end
	cap.Position = UDim2.fromOffset(0, 2)
	return { root = root, width = width, face = face }
end

export type GhostRow = { root: Frame, width: number, face: Frame, mouse: Frame }

--- 04 §3.2 ghost thumb with keys: the mouse with move arrows, a W key cap and the four arrow keys
--- in one row 64 tall (`HudLayout.GUIDE.ghostKeysWidth` wide).
function GuideHints.ghostRow(parent: Instance, z: number?): GhostRow
	local zi = z or 4
	local gap = GuideHints.ROW_GAP
	local width = 64 + gap + GuideHints.CAP + gap + GuideHints.ARROWS
	local root = Draw.new("Frame", {
		Name = "GhostKeys",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(width, 64),
		ZIndex = zi,
		Parent = parent,
	}) :: Frame
	local mouse = GuideHints.mouse(root, "move", zi)
	local cap, face = GuideHints.keyCap(root, GuideHints.keyLabel(Enum.KeyCode.W), nil, zi)
	cap.Position = UDim2.fromOffset(64 + gap, 2)
	local arrows = GuideHints.arrows(root, zi)
	arrows.Position = UDim2.fromOffset(64 + gap + GuideHints.CAP + gap, 0)
	return { root = root, width = width, face = face, mouse = mouse }
end

return table.freeze(GuideHints)
