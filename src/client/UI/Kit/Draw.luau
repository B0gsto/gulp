--!strict
-- Kit/Draw: the building blocks every Hud element and screen is made of (docs/09 section 3:
-- "Kit/ (buttons, panels, tween helpers)"). Everything is built in code (09 §5.2).
--
-- The interface images of docs/08 section 13 are not drawn yet. Each element is a code-drawn
-- stand-in in docs/06's colours and docs/08's sizes, plus an empty `ImageLabel` slot named after
-- its image (`Draw.slot`): once the image is uploaded, setting `Image` on the slot and hiding the
-- stand-in is the whole change. Names and sizes do not change (08 §15).
local TweenService = game:GetService("TweenService")

local Theme = require("./Theme")

local Draw = {}

export type Props = { [string]: any }

--- A new instance of `class` with `props` set and `children` parented to it.
function Draw.new(class: string, props: Props?, children: { any }?): any
	local object = Instance.new(class :: any)
	if object:IsA("GuiObject") then
		local gui = object :: GuiObject
		gui.BorderSizePixel = 0
		if not object:IsA("TextLabel") and not object:IsA("TextButton") then
			gui.BackgroundTransparency = 1
		end
	end
	if object:IsA("TextLabel") or object:IsA("TextButton") then
		local text = object :: TextLabel
		text.BackgroundTransparency = 1
		text.AutoLocalize = false -- 08 §14.0: text is set by key only
		text.TextColor3 = Theme.INK
		text.FontFace = Theme.FONT_DISPLAY
	end
	if props then
		for key, value in pairs(props) do
			(object :: any)[key] = value
		end
	end
	if children then
		for _, child in ipairs(children) do
			(child :: Instance).Parent = object
		end
	end
	return object
end

--- A UICorner; `radius` in rpx, or nil for a full circle or pill.
function Draw.corner(radius: number?): Instance
	return Draw.new("UICorner", {
		CornerRadius = if radius then UDim.new(0, radius) else UDim.new(0.5, 0),
	})
end

--- A navy stroke with round joins (06 §12.2).
function Draw.stroke(thickness: number, colour: Color3?, contextual: boolean?): UIStroke
	return Draw.new("UIStroke", {
		Thickness = thickness,
		Color = colour or Theme.INK,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = if contextual
			then Enum.ApplyStrokeMode.Contextual
			else Enum.ApplyStrokeMode.Border,
	})
end

--- A text label in rpx. `style`: "display" (Fredoka One) or "body" (Nunito ExtraBold).
function Draw.text(
	props: Props,
	size: number,
	style: ("display" | "body")?,
	outline: number?
): TextLabel
	local label = Draw.new("TextLabel", props) :: TextLabel
	label.TextSize = size
	label.FontFace = if style == "body" then Theme.FONT_BODY else Theme.FONT_DISPLAY
	label.TextWrapped = false
	if outline then
		Draw.stroke(outline, Theme.INK, true).Parent = label
	end
	return label
end

--- The empty image slot for an image of 08 §13, filling `parent`. Invisible until `Image` is set.
function Draw.slot(name: string, parent: Instance, zIndex: number?): ImageLabel
	local slot = Draw.new("ImageLabel", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		Image = "",
		ImageTransparency = 0,
		ZIndex = zIndex or 10,
	}) :: ImageLabel
	slot:SetAttribute("ImageKey", name)
	slot.Parent = parent
	return slot
end

--- A circle of `size` rpx centred at `position`.
function Draw.disc(size: number, colour: Color3, position: UDim2?, props: Props?): Frame
	local disc = Draw.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = colour,
		BackgroundTransparency = 0,
	}, { Draw.corner() }) :: Frame
	if props then
		for key, value in pairs(props) do
			(disc :: any)[key] = value
		end
	end
	return disc
end

--- A hard, unblurred shadow under `shape` (06 §12.2: offset 0, 8 px, #0B1530 at 35%).
function Draw.shadow(shape: GuiObject, radius: number?): Frame
	local shadow = Draw.new("Frame", {
		Name = "Shadow",
		AnchorPoint = shape.AnchorPoint,
		Position = shape.Position + UDim2.fromOffset(0, Theme.SHADOW_OFFSET),
		Size = shape.Size,
		BackgroundColor3 = Theme.DIM,
		BackgroundTransparency = Theme.SHADOW_TRANSPARENCY,
		ZIndex = shape.ZIndex - 1,
	}, { Draw.corner(radius) }) :: Frame
	shadow.Parent = shape.Parent
	return shadow
end

--- A cream panel with the navy stroke and hard shadow (06 §12.1, stand-in for
--- `UI_Common_PanelLarge`, a 9-slice).
function Draw.panel(props: Props, slotName: string?): Frame
	local panel = Draw.new("Frame", props) :: Frame
	panel.BackgroundColor3 = Theme.PANEL
	panel.BackgroundTransparency = 0
	Draw.corner(Theme.PANEL_RADIUS).Parent = panel
	Draw.stroke(Theme.STROKE_PANEL).Parent = panel
	-- A painted inner shade along the bottom edge gives the cut-out paper thickness.
	Draw.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.PANEL),
			ColorSequenceKeypoint.new(0.86, Theme.PANEL),
			ColorSequenceKeypoint.new(1, Theme.PANEL_SHADE),
		}),
		Rotation = 90,
	}).Parent =
		panel
	Draw.slot(slotName or "UI_Common_PanelLarge", panel)
	return panel
end

--- Plays a tween and returns it.
function Draw.tween(object: Instance, info: TweenInfo, goal: Props): Tween
	local tween = TweenService:Create(object, info, goal)
	tween:Play()
	return tween
end

export type ButtonKind = "Primary" | "Secondary"
export type Button = {
	root: Frame, -- holds the hit area; position and size this
	hit: TextButton, -- the transparent hit area, never smaller than the touch minimum
	face: Frame, -- the visible pill
	label: TextLabel,
	scale: UIScale,
	setEnabled: (enabled: boolean) -> (),
}

type Face = { face: Color3, shade: Color3, image: string }
local FACE: { [ButtonKind]: Face } = {
	Primary = {
		face = Theme.PRIMARY,
		shade = Theme.PRIMARY_SHADE,
		image = "UI_Common_ButtonPrimary",
	},
	Secondary = {
		face = Theme.SECONDARY,
		shade = Theme.SECONDARY_SHADE,
		image = "UI_Common_ButtonSecondary",
	},
}

--- Wires the button states of 08 §11.2 onto `hit`, scaling `scale`: hover 1.04, press 0.94 on
--- the press (P5: feedback in the same frame), release back out to 1.0. `onPress` runs on the
--- press and `onRelease` on the release; `darken` gets the pressed tint (true) or not.
function Draw.bindPress(
	hit: GuiButton,
	scale: UIScale,
	callbacks: {
		onPress: (() -> ())?,
		onRelease: (() -> ())?,
		darken: ((pressed: boolean) -> ())?,
		enabled: (() -> boolean)?,
	}
)
	local held: { [InputObject]: boolean } = {}
	local count = 0
	local hovering = false
	local function rest()
		Draw.tween(
			scale,
			Theme.MOTION.release,
			{ Scale = if hovering then Theme.HOVER_SCALE else 1 }
		)
	end
	hit.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseMovement then
			hovering = true
			if count == 0 then
				Draw.tween(scale, Theme.MOTION.hover, { Scale = Theme.HOVER_SCALE })
			end
			return
		end
		if kind ~= Enum.UserInputType.Touch and kind ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if callbacks.enabled and not callbacks.enabled() then
			-- 08 §11.2 disabled: a tap shakes it 6 rpx. TODO(B32): `SFX_UI_Locked`.
			local face = hit.Parent :: GuiObject
			local x = face.Position
			Draw.tween(face, Theme.MOTION.press, { Position = x + UDim2.fromOffset(6, 0) }).Completed
				:Once(function()
					Draw.tween(face, Theme.MOTION.disabled, { Position = x })
				end)
			return
		end
		if held[input] then
			return
		end
		held[input] = true
		count += 1
		Draw.tween(scale, Theme.MOTION.press, { Scale = Theme.PRESS_SCALE })
		if callbacks.darken then
			callbacks.darken(true)
		end
		-- TODO(B32 AudioController, B23 haptics): the press sound and haptic fire here (08 §11.4, §11.5).
		if callbacks.onPress then
			callbacks.onPress()
		end
	end)
	local function finish(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			hovering = false
			if count == 0 then
				rest()
			end
			return
		end
		if not held[input] then
			return
		end
		held[input] = nil
		count -= 1
		if count == 0 then
			rest()
			if callbacks.darken then
				callbacks.darken(false)
			end
			if callbacks.onRelease then
				callbacks.onRelease()
			end
		end
	end
	hit.InputEnded:Connect(finish)
end

--- A pill button (stand-in for `UI_Common_ButtonPrimary` and `UI_Common_ButtonSecondary`):
--- face, 4 rpx darker lip, navy stroke, hard shadow, Fredoka label with a navy stroke.
--- `width` x `height` is the visible face; the hit area grows to `minHit`.
function Draw.button(
	kind: ButtonKind,
	width: number,
	height: number,
	text: string,
	minHit: number,
	onActivate: () -> ()
): Button
	local colours = FACE[kind]
	local root = Draw.new(
		"Frame",
		{ Name = kind .. "Button", Size = UDim2.fromOffset(width, height) }
	) :: Frame
	local scale = Draw.new("UIScale", { Parent = root }) :: UIScale
	local enabled = true

	local radius = height * 0.36
	local lip = Draw.new("Frame", {
		Name = "Lip",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, Theme.LIP),
		BackgroundColor3 = colours.shade,
		BackgroundTransparency = 0,
		ZIndex = 2,
	}, { Draw.corner(radius), Draw.stroke(Theme.STROKE_PANEL) }) :: Frame
	lip.Parent = root
	Draw.shadow(lip, radius).Position = UDim2.fromOffset(0, Theme.LIP + Theme.SHADOW_OFFSET)

	local face = Draw.new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colours.face,
		BackgroundTransparency = 0,
		ZIndex = 3,
	}, { Draw.corner(radius), Draw.stroke(Theme.STROKE_PANEL) }) :: Frame
	face.Parent = root
	-- The shine strip along the top (06 §12.2).
	Draw.new("Frame", {
		Name = "Shine",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 7),
		Size = UDim2.new(1, -radius * 1.4, 0, 9),
		BackgroundColor3 = Theme.WHITE,
		BackgroundTransparency = 0.55,
		ZIndex = 4,
		Parent = face,
	}, { Draw.corner() })
	Draw.slot(colours.image, face, 5)

	local label = Draw.text({
		Name = "Label",
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		Text = text,
		TextColor3 = Theme.INK,
		ZIndex = 6,
		Parent = face,
	}, Theme.TEXT.title * 0.8, "display")

	local hitW, hitH = math.max(width, minHit), math.max(height, minHit)
	local hit = Draw.new("TextButton", {
		Name = "Hit",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(hitW, hitH),
		AutoButtonColor = false,
		ZIndex = 8,
		Parent = root,
	}) :: TextButton

	Draw.bindPress(hit, scale, {
		darken = function(pressed: boolean)
			face.BackgroundColor3 = if pressed
				then colours.face:Lerp(colours.shade, 0.45)
				else colours.face
			face.Position = UDim2.fromOffset(0, if pressed then Theme.LIP * 0.75 else 0)
		end,
		onRelease = function()
			if enabled then
				onActivate()
			end
		end,
		enabled = function()
			return enabled
		end,
	})

	return {
		root = root,
		hit = hit,
		face = face,
		label = label,
		scale = scale,
		setEnabled = function(on: boolean)
			enabled = on
			face.BackgroundColor3 = if on then colours.face else Theme.DISABLED
			lip.BackgroundColor3 = if on then colours.shade else Theme.DISABLED:Lerp(Theme.INK, 0.2)
		end,
	}
end

--- A two-half radial wedge (stand-in for `UI_HUD_CooldownHalf` x 2, 08 §3.7) of `size` rpx in
--- `parent`. `set(share)` shows `share` (0 to 1) of the circle, the rest swept clockwise from
--- 12 o'clock, so 1 is a full disc and 0 is nothing.
function Draw.wedge(
	parent: Instance,
	size: number,
	colour: Color3,
	transparency: number,
	zIndex: number
): (number) -> ()
	local halves: { UIGradient } = {}
	for i, side in { "Right", "Left" } do
		local clip = Draw.new("Frame", {
			Name = "CooldownHalf" .. side,
			AnchorPoint = Vector2.new(if i == 1 then 0 else 1, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size / 2, size),
			ClipsDescendants = true,
			ZIndex = zIndex,
			Parent = parent,
		}) :: Frame
		local disc = Draw.disc(size, colour, UDim2.fromScale(if i == 1 then 0 else 1, 0.5), {
			BackgroundTransparency = transparency,
			ZIndex = zIndex,
			Parent = clip,
		})
		local gradient = Draw.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.4999, 0),
				NumberSequenceKeypoint.new(0.5, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = disc,
		}) :: UIGradient
		halves[i] = gradient
	end
	return function(share: number)
		local s = math.clamp(share, 0, 1)
		-- The shown part ends at 12 o'clock and starts `s` of a turn before it (the empty part
		-- grows clockwise from 12). Right half: 0 to 0.5 of a turn; left half: 0.5 to 1.
		local hidden = 1 - s
		-- Gradient opaque on its left half; rotation r shows the half facing r + 180.
		local right = math.clamp(hidden, 0, 0.5) / 0.5 -- 0 = right half full, 1 = right half empty
		local left = math.clamp(hidden - 0.5, 0, 0.5) / 0.5
		halves[1].Rotation = 180 + 180 * right
		halves[1].Enabled = true
		halves[2].Rotation = 180 * left;
		(halves[1].Parent :: GuiObject).Visible = right < 1
		(halves[2].Parent :: GuiObject).Visible = left < 1 and s > 0
	end
end

return Draw
