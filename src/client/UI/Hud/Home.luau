--!strict
-- HUD.Home (docs/08 section 3.12): `UI_HUD_HomeMarker` (72 rpx, lantern amber: home is the one
-- thing amber marks, 06 §4.5) with `UI_HUD_HomePointer` orbiting it toward home, and the
-- distance under it (`hud.home_dist`, Small 22). Off screen it rides an ellipse 72 rpx inside the
-- safe frame and slides around dash and ability; on screen it floats 40 rpx above the cove mouth
-- and the pointer hides. On the full-screen `GulpWorld` layer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)
local HudMath = require(ReplicatedStorage.Shared.Logic.HudMath)

local Draw = require("../Kit/Draw")
local Loc = require("../Loc")
local Theme = require("../Kit/Theme")

local Home = {}

export type Placement = {
	-- Full-screen rpx of the marker centre.
	x: number,
	y: number,
	onScreen: boolean,
	-- Screen-space angle toward home (radians; 0 = right, π/2 = down), for the pointer.
	angle: number,
	studs: number,
}

export type Home = {
	root: Frame,
	place: (p: Placement?) -> (),
	setBest: (best: boolean) -> (),
}

local ABOVE_MOUTH = 40
local POINTER_ORBIT = 36 + 12

function Home.new(parent: Instance): Home
	local spec = HudLayout.HOME
	local root = Draw.new(
		"Frame",
		{ Name = "HUD.Home", Size = UDim2.fromScale(1, 1), Parent = parent }
	) :: Frame
	local marker = Draw.new("Frame", {
		Name = "Marker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(spec.size, spec.size),
		Visible = false,
		Parent = root,
	}) :: Frame

	-- Marker stand-in: an amber lantern disc with a navy rim and a cream cove arch.
	local glow = Draw.disc(
		spec.size * 1.3,
		Theme.HOME,
		nil,
		{ Name = "Glow", BackgroundTransparency = 0.78, ZIndex = 1, Parent = marker }
	)
	local disc =
		Draw.disc(spec.size, Theme.HOME, nil, { Name = "Disc", ZIndex = 2, Parent = marker })
	local rim = Draw.stroke(Theme.STROKE_ICON)
	rim.Parent = disc
	Draw.new("UIGradient", {
		Color = ColorSequence.new(Theme.HOME:Lerp(Theme.WHITE, 0.35), Theme.HOME),
		Rotation = 90,
		Parent = disc,
	})
	local arch = Draw.new("Frame", {
		Name = "Arch",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.78),
		Size = UDim2.fromScale(0.44, 0.5),
		BackgroundColor3 = Theme.INK,
		BackgroundTransparency = 0,
		ZIndex = 3,
		Parent = disc,
	}, { Draw.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }) :: Frame
	Draw.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = Theme.INK,
		BackgroundTransparency = 0,
		ZIndex = 3,
		Parent = arch,
	})
	Draw.disc(
		spec.size * 0.14,
		Theme.PANEL,
		UDim2.fromScale(0.5, 0.42),
		{ Name = "Lantern", ZIndex = 4, Parent = arch }
	)
	Draw.disc(
		spec.size * 0.2,
		Theme.WHITE,
		UDim2.fromScale(0.3, 0.26),
		{ ZIndex = 4, BackgroundTransparency = 0.35, Parent = disc }
	)
	Draw.slot("UI_HUD_HomeMarker", disc, 6)

	-- Pointer: an amber arrowhead on an orbit, pointing home.
	local orbit = Draw.new("Frame", {
		Name = "Orbit",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		ZIndex = 5,
		Parent = marker,
	}) :: Frame
	local pointer = Draw.new("Frame", {
		Name = "UI_HUD_HomePointer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(POINTER_ORBIT, 0),
		Size = UDim2.fromOffset(spec.pointer, spec.pointer),
		ZIndex = 5,
		Parent = orbit,
	}) :: Frame
	for _, r in { 40, -40 } do
		Draw.new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, if r > 0 then 4 else -4),
			Size = UDim2.fromOffset(18, 8),
			Rotation = r,
			BackgroundColor3 = Theme.HOME,
			BackgroundTransparency = 0,
			ZIndex = 5,
			Parent = pointer,
		}, { Draw.corner(), Draw.stroke(Theme.STROKE_CHIP) })
	end
	Draw.slot("UI_HUD_HomePointer", pointer, 6)

	-- 08 §1.5: text over the 3D world sits on a chip (and keeps its 2 rpx dark stroke).
	local chip = Draw.new("Frame", {
		Name = "DistanceChip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.fromOffset(0, spec.labelHeight),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.DIM,
		BackgroundTransparency = 0.3,
		ZIndex = 5,
		Parent = marker,
	}, {
		Draw.corner(),
		Draw.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	}) :: Frame
	local distance = Draw.text({
		Name = "Distance",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = Theme.WHITE,
		ZIndex = 6,
		Parent = chip,
	}, Theme.TEXT.small, "body", Theme.STROKE_TEXT)

	local nextText = 0
	return {
		root = root,
		place = function(p: Placement?)
			if p == nil then
				marker.Visible = false
				return
			end
			marker.Visible = true
			marker.Position =
				UDim2.fromOffset(p.x, p.y - (if p.onScreen then ABOVE_MOUTH + spec.size / 2 else 0))
			orbit.Visible = not p.onScreen
			orbit.Rotation = math.deg(p.angle)
			local now = os.clock()
			if now >= nextText then
				nextText = now + 1 / HudMath.HOME_HZ
				distance.Text = Loc.t("hud.home_dist", { Dist = HudMath.homeDistance(p.studs) })
			end
		end,
		setBest = function(best: boolean)
			-- Best state (08 §3.12): a gold rim when the Pearl preview beats the best run.
			rim.Color = if best then Theme.GOLD else Theme.INK
			rim.Thickness = if best then Theme.STROKE_ICON * 1.6 else Theme.STROKE_ICON
			glow.BackgroundTransparency = if best then 0.6 else 0.78
		end,
	}
end

return Home
