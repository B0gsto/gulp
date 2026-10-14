--!strict
-- HUD.MassBar (docs/08 section 3.4): current tier badge, the fat mass bar, the mass number, the
-- mass still needed and the next tier's badge at 44 rpx and 50%. Stand-ins for
-- `UI_HUD_MassBarFrame`, `UI_HUD_MassBarFill`, `UI_HUD_GoalArrow`, `UI_Icon_Tier1..7`, `UI_HUD_Crown`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudMath = require(ReplicatedStorage.Shared.Logic.HudMath)

local Draw = require("../Kit/Draw")
local Loc = require("../Loc")
local Theme = require("../Kit/Theme")

local MassBar = {}

export type MassBar = {
	root: Frame,
	set: (mass: number, instant: boolean?) -> (),
	layout: (x: number, y: number, width: number) -> (),
	update: (now: number) -> (),
}

local BADGE, NEXT_BADGE, BAR_H, GAP = 64, 44, 28, 8
-- Tier badge stand-in: a cream disc with the tier number, tinted ring per tier (rarity-free:
-- the colour is decoration, the number carries the meaning, 08 §12).
local TIER_RING = {
	Color3.fromHex("#9FE7FF"),
	Color3.fromHex("#3DD6D0"),
	Color3.fromHex("#5FD08A"),
	Color3.fromHex("#4C8DFF"),
	Color3.fromHex("#9A6BFF"),
	Color3.fromHex("#FF7AB8"),
	Theme.GOLD,
}

local function shortText(n: number): string
	local digits, kind = HudMath.short(n)
	if kind == "thousand" then
		return Loc.t("common.thousand", { Value = digits })
	elseif kind == "million" then
		return Loc.t("common.million", { Value = digits })
	end
	return digits
end

local function badge(name: string, size: number, tilt: number): (Frame, TextLabel, Frame)
	local holder = Draw.new("Frame", { Name = name, Size = UDim2.fromOffset(size, size) }) :: Frame
	local ring = Draw.disc(
		size,
		TIER_RING[1],
		nil,
		{ Name = "Ring", ZIndex = 2, Rotation = tilt, Parent = holder }
	)
	Draw.stroke(Theme.STROKE_ICON).Parent = ring
	local inner =
		Draw.disc(size * 0.72, Theme.PANEL, nil, { Name = "Inner", ZIndex = 3, Parent = ring })
	Draw.stroke(Theme.STROKE_CHIP * 0.75).Parent = inner
	local number = Draw.text({
		Name = "Number",
		Size = UDim2.fromScale(1, 1),
		Text = "1",
		ZIndex = 4,
		Parent = inner,
	}, size * 0.5, "display")
	-- Highlight blob (06 §12.4: one white highlight).
	Draw.disc(
		size * 0.16,
		Theme.WHITE,
		UDim2.fromScale(0.28, 0.24),
		{ ZIndex = 4, BackgroundTransparency = 0.2, Parent = ring }
	)
	Draw.slot("UI_Icon_Tier1", holder, 6)
	return holder, number, ring
end

function MassBar.new(parent: Instance): MassBar
	local root = Draw.new("Frame", {
		Name = "HUD.MassBar",
		AnchorPoint = Vector2.new(0, 0),
		Size = UDim2.fromOffset(440, 64),
		Parent = parent,
	}) :: Frame
	local shake =
		Draw.new("Frame", { Name = "Shake", Size = UDim2.fromScale(1, 1), Parent = root }) :: Frame

	local current, currentNumber, currentRing = badge("Badge", BADGE, -3)
	current.Position = UDim2.fromOffset(0, 0)
	current.ZIndex = 5
	current.Parent = shake
	local currentScale = Draw.new("UIScale", { Parent = current }) :: UIScale

	local nextBadge, nextNumber, nextRing = badge("NextBadge", NEXT_BADGE, 3)
	nextBadge.AnchorPoint = Vector2.new(1, 0.5)
	nextBadge.Parent = shake
	local nextGroup = Draw.new(
		"CanvasGroup",
		{ Name = "NextGroup", Size = UDim2.fromScale(1, 1), GroupTransparency = 0.5 }
	) :: CanvasGroup
	nextGroup.Parent = nextBadge
	nextRing.Parent = nextGroup
	local nextScale = Draw.new("UIScale", { Parent = nextBadge }) :: UIScale
	local crown = Draw.new(
		"Frame",
		{ Name = "UI_HUD_Crown", Size = UDim2.fromScale(1, 1), Visible = false, Parent = nextBadge }
	) :: Frame
	do
		-- Crown stand-in: a gold band with three points.
		local band = Draw.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.86),
			Size = UDim2.fromScale(0.8, 0.34),
			BackgroundColor3 = Theme.GOLD,
			BackgroundTransparency = 0,
			ZIndex = 3,
			Parent = crown,
		}, { Draw.corner(3), Draw.stroke(Theme.STROKE_CHIP) })
		for i, x in { 0.2, 0.5, 0.8 } do
			local point = Draw.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(x, if i == 2 then 0.36 else 0.44),
				Size = UDim2.fromOffset(13, 13),
				Rotation = 45,
				BackgroundColor3 = Theme.GOLD,
				BackgroundTransparency = 0,
				ZIndex = 2,
				Parent = crown,
			}, { Draw.corner(2), Draw.stroke(Theme.STROKE_CHIP) })
			Draw.disc(6, Theme.PEARL, UDim2.fromScale(x, 0.62), { ZIndex = 4, Parent = crown })
			local _ = point
		end
		local _ = band
		Draw.slot("UI_HUD_Crown", crown, 6)
	end

	-- The bar: navy-stroked track, fill, shine strip (06 §12.2), `UI_HUD_MassBarFrame` and Fill.
	local bar = Draw.new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, BADGE + GAP, 0.5, 0),
		Size = UDim2.fromOffset(300, BAR_H),
		BackgroundColor3 = Theme.DIM,
		BackgroundTransparency = 0.35,
		ClipsDescendants = false,
		Parent = shake,
	}, { Draw.corner(), Draw.stroke(Theme.STROKE_PANEL) }) :: Frame
	Draw.slot("UI_HUD_MassBarFrame", bar, 9)
	local fillClip = Draw.new("Frame", {
		Name = "FillClip",
		Size = UDim2.fromScale(0, 1),
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = bar,
	}) :: Frame
	local fill = Draw.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromOffset(300, BAR_H),
		BackgroundColor3 = Theme.SECONDARY,
		BackgroundTransparency = 0,
		ZIndex = 2,
		Parent = fillClip,
	}, { Draw.corner() }) :: Frame
	Draw.new("Frame", {
		Name = "Shine",
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 0, 6),
		BackgroundColor3 = Theme.WHITE,
		BackgroundTransparency = 0.45,
		ZIndex = 3,
		Parent = fill,
	}, { Draw.corner() })
	Draw.slot("UI_HUD_MassBarFill", fill, 4)
	local flash = Draw.new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.WHITE,
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = bar,
	}, { Draw.corner() }) :: Frame

	-- The numbers sit on a dark plate at each end of the bar, so the white digits and their dark
	-- 2 rpx stroke (08 §1.5) read on any fill colour or world behind (review: weak on teal).
	local function plate(name: string, anchorX: number, x: UDim): Frame
		return Draw.new("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(anchorX, 0.5),
			Position = UDim2.new(x, UDim.new(0.5, 0)),
			Size = UDim2.fromOffset(0, BAR_H + 6),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.INK,
			BackgroundTransparency = 0.35,
			ZIndex = 5,
			Parent = bar,
		}, {
			Draw.corner(),
			Draw.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
		}) :: Frame
	end
	local massPlate = plate("MassPlate", 0, UDim.new(0, -2))
	local mass = Draw.text({
		Name = "Mass",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.WHITE,
		Text = "0",
		ZIndex = 6,
		Parent = massPlate,
	}, Theme.TEXT.number, "display", Theme.STROKE_TEXT)
	local massScale = Draw.new("UIScale", { Parent = mass }) :: UIScale

	local goal = plate("Goal", 1, UDim.new(1, 2))
	goal.ZIndex = 5
	Draw.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = goal,
	})
	-- The mass still needed is a number too: Number 28, like the mass (08 §1.5 and §3.4).
	local goalText = Draw.text({
		Name = "ToGo",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.WHITE,
		Text = "",
		ZIndex = 6,
		Parent = goal,
	}, Theme.TEXT.number, "display", Theme.STROKE_TEXT)
	local arrow = Draw.new("Frame", {
		Name = "UI_HUD_GoalArrow",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(20, 20),
		ZIndex = 6,
		Parent = goal,
	}) :: Frame
	do
		-- Arrow stand-in: a chevron of two short bars.
		for _, r in { 45, -45 } do
			Draw.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, if r > 0 then -3.5 else 3.5),
				Size = UDim2.fromOffset(11, 4),
				Rotation = r,
				BackgroundColor3 = Theme.WHITE,
				BackgroundTransparency = 0,
				ZIndex = 7,
				Parent = arrow,
			}, { Draw.corner(), Draw.stroke(1.4) })
		end
		Draw.slot("UI_HUD_GoalArrow", arrow, 8)
	end

	-- Tap or hover chip: `hud.next_tier` under the bar for 2 s.
	local chip = Draw.new("Frame", {
		Name = "NextTierChip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.fromOffset(200, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.PANEL,
		BackgroundTransparency = 0,
		Visible = false,
		ZIndex = 8,
		Parent = root,
	}, {
		Draw.corner(),
		Draw.stroke(Theme.STROKE_CHIP),
		Draw.new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
	}) :: Frame
	local chipText = Draw.text({
		Name = "Text",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 9,
		Parent = chip,
	}, Theme.TEXT.small, "body")
	local chipUntil = 0
	local tap = Draw.new("TextButton", {
		Name = "Hit",
		Text = "",
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		ZIndex = 10,
		Parent = root,
	}) :: TextButton

	local shown = -1
	local shownTier = 0
	local barWidth = 300
	local nearSince: number? = nil
	local state = HudMath.massBar(0)

	local function showChip()
		if state.max or state.nextTier == nil then
			return
		end
		chipText.Text = Loc.t("hud.next_tier", {
			Mass = shortText(state.toGo),
			Tier = Loc.t(`tier.{state.nextTier}`),
		})
		chip.Visible = true
		chipUntil = os.clock() + 2
	end
	tap.MouseEnter:Connect(showChip)
	tap.Activated:Connect(showChip)

	local function paintTier(tier: number)
		currentNumber.Text = tostring(tier)
		currentRing.BackgroundColor3 = TIER_RING[tier]
		local nxt = math.min(tier + 1, 7)
		nextNumber.Text = tostring(nxt)
		nextRing.BackgroundColor3 = TIER_RING[nxt]
		-- The image slots follow the tier: `UI_Icon_Tier1` to `UI_Icon_Tier7` (08 §13).
		for holder, t in { [current] = tier, [nextBadge] = nxt } do
			for _, child in holder:GetChildren() do
				if child:IsA("ImageLabel") and child:GetAttribute("ImageKey") ~= nil then
					child.Name = `UI_Icon_Tier{t}`
					child:SetAttribute("ImageKey", child.Name)
				end
			end
		end
		fill.BackgroundColor3 = if tier >= 7 then Theme.GOLD else Theme.SECONDARY
	end

	local self: MassBar
	self = {
		root = root,
		set = function(value: number, instant: boolean?)
			local before = shown
			shown = value
			state = HudMath.massBar(value)
			mass.Text = shortText(value)
			if state.max then
				goalText.Text = Loc.t("common.max")
				arrow.Visible = false
			else
				goalText.Text = shortText(state.toGo)
				arrow.Visible = true
			end
			nextRing.Visible = not state.max
			crown.Visible = state.max
			local goalFill = UDim2.fromScale(state.fill, 1)
			if instant or before < 0 then
				fillClip.Size = goalFill
			else
				Draw.tween(
					fillClip,
					TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = goalFill }
				)
			end
			if state.tier ~= shownTier then
				local rose = shownTier > 0 and state.tier > shownTier
				shownTier = state.tier
				paintTier(state.tier)
				if rose and not instant then
					-- Tier-up: the bar flashes white for 80 ms; the badge pops in (08 §3.4).
					-- TODO(S07, stage 2): the next badge slides left into the current one (300 ms).
					flash.BackgroundTransparency = 0
					Draw.tween(flash, TweenInfo.new(0.08), { BackgroundTransparency = 1 })
					currentScale.Scale = 0.6
					Draw.tween(currentScale, Theme.MOTION.slam, { Scale = 1 })
				end
			end
			if not instant and before >= 0 then
				if value > before then
					-- Gain: the number pops to 1.15 for 120 ms.
					massScale.Scale = 1.15
					Draw.tween(
						massScale,
						TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ Scale = 1 }
					)
				elseif value < before then
					-- Loss: the fill flashes the danger colour, the bar shakes 6 rpx for 200 ms.
					fill.BackgroundColor3 = Theme.DANGER
					task.delay(0.2, function()
						fill.BackgroundColor3 = if state.tier >= 7
							then Theme.GOLD
							else Theme.SECONDARY
					end)
					local t0 = os.clock()
					task.spawn(function()
						while os.clock() - t0 < 0.2 do
							local k = 1 - (os.clock() - t0) / 0.2
							shake.Position =
								UDim2.fromOffset(math.sin((os.clock() - t0) * 90) * 6 * k, 0)
							task.wait()
						end
						shake.Position = UDim2.new()
					end)
				end
			end
			nearSince = if state.near then (nearSince or os.clock()) else nil
		end,
		layout = function(x: number, y: number, width: number)
			root.Position = UDim2.fromOffset(x, y)
			root.Size = UDim2.fromOffset(width, 64)
			barWidth = width - BADGE - NEXT_BADGE - 2 * GAP
			bar.Size = UDim2.fromOffset(barWidth, BAR_H)
			fill.Size = UDim2.fromOffset(barWidth, BAR_H)
			nextBadge.Position = UDim2.new(0, width, 0.5, 0)
		end,
		update = function(now: number)
			if chip.Visible and now > chipUntil then
				chip.Visible = false
			end
			-- Near: the next badge pulses at 1 Hz at full opacity.
			if nearSince then
				nextGroup.GroupTransparency = 0
				nextScale.Scale = 1 + 0.08 * (0.5 - 0.5 * math.cos((now - nearSince) * 2 * math.pi))
			else
				nextGroup.GroupTransparency = 0.5
				nextScale.Scale = 1
			end
		end,
	}
	return self
end

return MassBar
