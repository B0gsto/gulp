--!strict
-- HUD.DragRing (docs/08 section 3.16): `UI_HUD_DragRing` at 35% opacity at the drag origin (fade
-- in 80 ms) and `UI_HUD_DragKnob` under the thumb, held within 84 rpx; dead zone 14 rpx. Lives on
-- the full-screen `GulpWorld` layer; positions come from `Shared.Logic.HudLayout.dragRing`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)

local Draw = require("../Kit/Draw")
local Theme = require("../Kit/Theme")

local DragRing = {}

export type DragRing = {
	root: Frame,
	update: (
		active: boolean,
		ox: number,
		oy: number,
		tx: number,
		ty: number,
		full: HudLayout.Size
	) -> (),
}

local FADE = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RING_OPACITY = 0.35

function DragRing.new(parent: Instance): DragRing
	local spec = HudLayout.DRAG
	local root = Draw.new(
		"Frame",
		{ Name = "HUD.DragRing", Size = UDim2.fromScale(1, 1), Parent = parent }
	) :: Frame
	local group = Draw.new("CanvasGroup", {
		Name = "Group",
		Size = UDim2.fromScale(1, 1),
		GroupTransparency = 1,
		Visible = false,
		Parent = root,
	}) :: CanvasGroup

	-- Ring: a white band with a navy rim, inner dead-zone dot.
	local ring = Draw.disc(spec.ring, Theme.WHITE, nil, {
		Name = "UI_HUD_DragRing",
		BackgroundTransparency = 1 - RING_OPACITY,
		ZIndex = 1,
		Parent = group,
	})
	local rim = Draw.stroke(Theme.STROKE_ICON, Theme.INK)
	rim.Transparency = 0.45 -- the whole ring reads at about 35% (08 §3.16)
	rim.Parent = ring
	local inner = Draw.disc(
		spec.ring - 40,
		Theme.WHITE,
		nil,
		{ Name = "Inner", BackgroundTransparency = 1, ZIndex = 1, Parent = ring }
	)
	local innerStroke = Draw.stroke(2, Theme.WHITE)
	innerStroke.Transparency = 0.45
	innerStroke.Parent = inner
	Draw.disc(
		spec.deadZone * 2,
		Theme.INK,
		nil,
		{ Name = "DeadZone", BackgroundTransparency = 0.7, ZIndex = 1, Parent = ring }
	)
	Draw.slot("UI_HUD_DragRing", ring, 3)

	local knob = Draw.disc(
		spec.knob,
		Theme.PANEL,
		nil,
		{ Name = "UI_HUD_DragKnob", ZIndex = 4, Parent = group }
	)
	Draw.stroke(Theme.STROKE_PANEL).Parent = knob
	Draw.new(
		"UIGradient",
		{ Color = ColorSequence.new(Theme.WHITE, Theme.PANEL_SHADE), Rotation = 90, Parent = knob }
	)
	Draw.disc(
		spec.knob * 0.3,
		Theme.WHITE,
		UDim2.fromScale(0.32, 0.28),
		{ ZIndex = 5, BackgroundTransparency = 0.1, Parent = knob }
	)
	Draw.slot("UI_HUD_DragKnob", knob, 6)

	local shown = false
	return {
		root = root,
		update = function(
			active: boolean,
			ox: number,
			oy: number,
			tx: number,
			ty: number,
			full: HudLayout.Size
		)
			if active then
				local pose = HudLayout.dragRing(ox, oy, tx, ty, full)
				ring.Position = UDim2.fromOffset(pose.ringX, pose.ringY)
				knob.Position = UDim2.fromOffset(pose.knobX, pose.knobY)
				knob.BackgroundColor3 = if pose.dead then Theme.PANEL_SHADE else Theme.PANEL
			end
			if active ~= shown then
				shown = active
				if active then
					group.Visible = true
					group.GroupTransparency = 1
				end
				Draw.tween(group, FADE, { GroupTransparency = if active then 0 else 1 }).Completed
					:Once(function()
						if not shown then
							group.Visible = false
						end
					end)
			end
		end,
	}
end

return DragRing
