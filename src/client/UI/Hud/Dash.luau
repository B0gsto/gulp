--!strict
-- HUD.Dash (docs/08 section 3.7; docs/15 sections 3.1 to 3.3): the 136 rpx dash button on touch,
-- the 80 x 96 hint tile on desktop (display only: Space and the left mouse button dash, 15 §3.3).
-- Stand-ins for `UI_HUD_DashButton` (normal, pressed), `UI_HUD_CooldownHalf` x 2,
-- `UI_Common_RingPulse` and `UI_HUD_HintTile`. Key caps under the tile are stage 2 (08 §15).
local Draw = require("../Kit/Draw")
local Theme = require("../Kit/Theme")

local Dash = {}

export type Dash = {
	root: Frame,
	layout: (
		x: number,
		y: number,
		width: number,
		height: number,
		hitSize: number,
		tile: boolean
	) -> (),
	update: (cooldownLeft: number, blocked: boolean) -> (),
}

local READY_PULSE = 0.25 -- 08 §3.7 ring pulse
local GROUP_PAD = 16

-- The dash symbol: two navy chevrons pointing forward (up-right), drawn from bars.
local function chevrons(parent: Instance, size: number, z: number)
	local symbol = Draw.new("Frame", {
		Name = "Symbol",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		Rotation = -12,
		ZIndex = z,
		Parent = parent,
	}) :: Frame
	local bar = size * 0.36
	local thick = size * 0.13
	for i, dx in { -0.17, 0.13 } do
		for _, r in { 45, -45 } do
			Draw.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5 + dx, 0, 0.5, if r > 0 then -bar * 0.33 else bar * 0.33),
				Size = UDim2.fromOffset(bar, thick),
				Rotation = r,
				BackgroundColor3 = if i == 2
					then Theme.INK
					else Theme.INK:Lerp(Theme.PRIMARY_SHADE, 0.45),
				BackgroundTransparency = 0,
				ZIndex = z,
				Parent = symbol,
			}, { Draw.corner() })
		end
	end
	-- Speed streaks behind the chevrons.
	for k, y in { 0.34, 0.66 } do
		Draw.new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(0.2, y),
			Size = UDim2.fromOffset(size * (if k == 1 then 0.16 else 0.22), thick * 0.55),
			BackgroundColor3 = Theme.INK,
			BackgroundTransparency = 0.35,
			ZIndex = z,
			Parent = symbol,
		}, { Draw.corner() })
	end
end

function Dash.new(parent: Instance, press: (down: boolean) -> ()): Dash
	local root = Draw.new(
		"Frame",
		{ Name = "HUD.Dash", Size = UDim2.fromOffset(136, 136), Parent = parent }
	) :: Frame
	-- The CanvasGroup (for the 40% disabled fade) clips to its bounds, so it is padded on every
	-- side to hold the stroke, the lip and the hard shadow around the 136 rpx face.
	local group = Draw.new("CanvasGroup", {
		Name = "Group",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 2 * GROUP_PAD, 1, 2 * GROUP_PAD),
		Parent = root,
	}) :: CanvasGroup
	local scale = Draw.new("UIScale", { Parent = group }) :: UIScale

	-- Touch button: a round sun-yellow face over a darker lip, navy stroke, hard shadow.
	local button = Draw.new("Frame", {
		Name = "Button",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -2 * GROUP_PAD, 1, -2 * GROUP_PAD),
		Parent = group,
	}) :: Frame
	local shadow =
		Draw.disc(136, Theme.DIM, UDim2.new(0.5, 0, 0.5, Theme.LIP + Theme.SHADOW_OFFSET), {
			Name = "Shadow",
			BackgroundTransparency = Theme.SHADOW_TRANSPARENCY,
			ZIndex = 1,
			Parent = button,
		})
	local lip = Draw.disc(
		136,
		Theme.PRIMARY_SHADE,
		UDim2.new(0.5, 0, 0.5, Theme.LIP),
		{ Name = "Lip", ZIndex = 2, Parent = button }
	)
	Draw.stroke(Theme.STROKE_PANEL).Parent = lip
	local face = Draw.disc(136, Theme.PRIMARY, nil, { Name = "Face", ZIndex = 3, Parent = button })
	Draw.stroke(Theme.STROKE_PANEL).Parent = face
	Draw.new("UIGradient", {
		Color = ColorSequence.new(Theme.PRIMARY:Lerp(Theme.WHITE, 0.25), Theme.PRIMARY),
		Rotation = 90,
		Parent = face,
	})
	Draw.disc(
		136 * 0.3,
		Theme.WHITE,
		UDim2.fromScale(0.3, 0.26),
		{ Name = "Highlight", BackgroundTransparency = 0.45, ZIndex = 4, Parent = face }
	)
	-- The wedge sits under the symbol, light enough that the button still reads (08 §3.7).
	local setWedge = Draw.wedge(face, 136, Theme.DIM, 0.6, 4)
	chevrons(face, 136 * 0.62, 5)
	Draw.slot("UI_HUD_DashButton", face, 7)

	-- Desktop hint tile: icon 64 with the cooldown on it.
	local tile = Draw.new("Frame", {
		Name = "Tile",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -2 * GROUP_PAD, 1, -2 * GROUP_PAD),
		Visible = false,
		BackgroundColor3 = Theme.DIM,
		BackgroundTransparency = 0.45,
		Parent = group,
	}, { Draw.corner(14), Draw.stroke(Theme.STROKE_CHIP) }) :: Frame
	Draw.slot("UI_HUD_HintTile", tile, 2)
	local icon = Draw.disc(
		64,
		Theme.PRIMARY,
		UDim2.new(0.5, 0, 0, 40),
		{ Name = "Icon", ZIndex = 3, Parent = tile }
	)
	Draw.stroke(Theme.STROKE_ICON).Parent = icon
	local setTileWedge = Draw.wedge(icon, 64, Theme.DIM, 0.6, 3)
	chevrons(icon, 40, 4)

	-- Ready again: `UI_Common_RingPulse`.
	local pulse = Draw.disc(
		136,
		Theme.WHITE,
		nil,
		{ Name = "UI_Common_RingPulse", BackgroundTransparency = 1, ZIndex = 9, Parent = root }
	)
	local pulseStroke = Draw.stroke(Theme.STROKE_PANEL * 1.4, Theme.WHITE)
	pulseStroke.Parent = pulse
	pulseStroke.Transparency = 1

	local hit = Draw.new("TextButton", {
		Name = "Hit",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		ZIndex = 10,
		Parent = root,
	}) :: TextButton

	local blockedNow = false
	Draw.bindPress(hit, scale, {
		onPress = function()
			press(true)
		end,
		onRelease = function()
			press(false)
		end,
		darken = function(pressed: boolean)
			-- The pressed sprite: face drops onto the lip and darkens 15% (08 §11.2).
			face.Position = UDim2.new(0.5, 0, 0.5, if pressed then Theme.LIP else 0)
			face.BackgroundColor3 = if pressed
				then Theme.PRIMARY:Lerp(Theme.INK, 0.15)
				else Theme.PRIMARY
		end,
		enabled = function()
			-- TODO(B32): `SFX_UI_Locked` on a tap while disabled.
			return not blockedNow
		end,
	})

	local wasCooling = false
	local isTile = false
	local size = 136
	local self: Dash = {
		root = root,
		layout = function(
			x: number,
			y: number,
			width: number,
			height: number,
			hitSize: number,
			tileMode: boolean
		)
			isTile = tileMode
			size = width
			root.Position = UDim2.fromOffset(x, y)
			root.Size = UDim2.fromOffset(width, height)
			button.Visible = not tileMode
			tile.Visible = tileMode
			hit.Visible = not tileMode
			hit.Size = UDim2.fromOffset(math.max(width, hitSize), math.max(height, hitSize))
			for _, disc in { shadow, lip, face, pulse } do
				disc.Size =
					UDim2.fromOffset(if tileMode then 64 else width, if tileMode then 64 else width)
			end
			pulse.Position = if tileMode
				then UDim2.new(0.5, 0, 0, 40)
				else UDim2.fromScale(0.5, 0.5)
		end,
		update = function(left: number, blocked: boolean)
			if isTile then
				setTileWedge(left)
			else
				setWedge(left)
			end
			local cooling = left > 0
			if wasCooling and not cooling then
				-- TODO(B32): `SFX_UI_DashReady` at low volume.
				local s = Draw.new("UIScale", { Parent = pulse, Scale = 1 }) :: UIScale
				pulseStroke.Transparency = 0
				Draw.tween(
					s,
					TweenInfo.new(READY_PULSE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Scale = 1.35 }
				)
				Draw.tween(pulseStroke, TweenInfo.new(READY_PULSE), { Transparency = 1 }).Completed
					:Once(function()
						s:Destroy()
					end)
			end
			wasCooling = cooling
			if blocked ~= blockedNow then
				blockedNow = blocked
				-- Disabled (stunned, tucked in Shell): 40% opacity.
				Draw.tween(
					group,
					Theme.MOTION.disabled,
					{ GroupTransparency = if blocked then 0.6 else 0 }
				)
			end
			local _ = size
		end,
	}
	return self
end

return Dash
