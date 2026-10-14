--!strict
-- S07 Tier-up (docs/08 section 4.2; task S6-C5): the moment card for a tier rise, 460 × 112 on
-- `UI_Common_Ribbon`: the new tier badge, `moment.tier_up`, the tier's canon name (`tier.1` to
-- `tier.7`, shown in capitals as in 08 §4.2 and 04 §3.3's NIBBLER) and `moment.new_food` with
-- up to three prey that just became edible, each in an edible-colour ring. Tier 7 holds longer
-- and turns `UI_Common_Rays` behind the badge. Rects come from `HudLayout.tierUpCard`; the slot
-- (`MomentSlot`) moves it in and out.
-- Not here yet: `SFX_UI_TierUp` and the two haptic pulses (08 §11.4: Medium, 40 ms, twice,
-- 100 ms apart) come with the sound and haptics module (TODO(B32)); `toast.leviathan` to the
-- whole server is the toast stack's (TODO(S10, stage 2)).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)
local Index = require(ReplicatedStorage.Shared.Data.Index)
local MomentQueue = require(ReplicatedStorage.Shared.Logic.MomentQueue)

local Draw = require("../Kit/Draw")
local Icons = require("../Kit/Icons")
local Loc = require("../Loc")
local MomentSlot = require("./MomentSlot")
local Theme = require("../Kit/Theme")

local TierUp = {}

export type Data = {
	tier: number,
	previous: number,
	food: { string }, -- prey IDs, at most three (HudMath.newFood)
}

local TOP = #Index.Tiers.list

--- The hold of this card (08 §4.1).
function TierUp.hold(data: Data): number
	return MomentQueue.tierUpHold(data.tier, TOP)
end

local function toRect(r: HudLayout.Rect): (UDim2, UDim2)
	return UDim2.fromOffset(r.x, r.y), UDim2.fromOffset(r.width, r.height)
end

-- `UI_Icon_Prey{Name}` stand-in in an edible-colour ring (08 §4.2), `size` rpx.
local function preyIcon(preyId: string, size: number, parent: Instance, order: number): UIScale
	local holder = Draw.new("Frame", {
		Name = `Food{order}`,
		LayoutOrder = order,
		Size = UDim2.fromOffset(size, size),
		ZIndex = 5,
		Parent = parent,
	}) :: Frame
	local scale = Draw.new("UIScale", { Scale = 0.01, Parent = holder }) :: UIScale
	local disc =
		Draw.disc(size, Theme.SECONDARY, nil, { Name = "Prey", ZIndex = 5, Parent = holder })
	Draw.stroke(Theme.STROKE_CHIP * 1.25, Theme.EDIBLE).Parent = disc
	-- A tail and one highlight, so it reads as a fish at 28 rpx.
	Draw.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.86, 0.5),
		Size = UDim2.fromOffset(size * 0.34, size * 0.34),
		Rotation = 45,
		BackgroundColor3 = Theme.SECONDARY_SHADE,
		BackgroundTransparency = 0,
		ZIndex = 4,
		Parent = holder,
	})
	Draw.disc(size * 0.22, Theme.WHITE, UDim2.fromScale(0.32, 0.32), {
		ZIndex = 6,
		BackgroundTransparency = 0.2,
		Parent = disc,
	})
	-- `zebra_darter` → `UI_Icon_PreyZebraDarter` (08 §13 names).
	local parts: { string } = {}
	for _, word in string.split(preyId, "_") do
		table.insert(parts, string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2))
	end
	Draw.slot(`UI_Icon_Prey{table.concat(parts)}`, disc, 7)
	return scale
end

--- Builds the card for `data` inside a `slot` sized moment slot.
function TierUp.build(
	parent: Frame,
	slot: { width: number, height: number },
	data: Data
): MomentSlot.Card
	local rects = HudLayout.tierUpCard(slot, #data.food > 0)
	local spec = HudLayout.TIER_UP
	local position, size = toRect(rects.card)
	local root = Draw.new("Frame", {
		Name = "S07.TierUp",
		Position = position,
		Size = size,
		ZIndex = 2,
		Parent = parent,
	}) :: Frame

	-- Ribbon stand-in: a cream band with folded sun-yellow tails behind both ends, kept inside the
	-- 480 rpx slot (08 §3.3).
	local tailSize = 36
	for i, x in { 0, 1 } do
		local tail = Draw.new("Frame", {
			Name = `Tail{i}`,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(x, if x == 0 then 16 else -16, 0.5, 8),
			Size = UDim2.fromOffset(tailSize, tailSize),
			Rotation = 45,
			BackgroundColor3 = Theme.PRIMARY_SHADE,
			BackgroundTransparency = 0,
			ZIndex = 1,
			Parent = root,
		}) :: Frame
		Draw.corner(6).Parent = tail
		Draw.stroke(Theme.STROKE_PANEL).Parent = tail
	end
	local panel = Draw.panel({
		Name = "Ribbon",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = root,
	}, "UI_Common_Ribbon")
	Draw.shadow(panel, Theme.PANEL_RADIUS)
	local art = rects.art
	local centre = UDim2.fromOffset(art.x + art.width / 2, art.y + art.height / 2)
	local rays: Frame? = nil
	if data.tier >= TOP then
		rays = MomentSlot.rays(root, spec.rays, Theme.GOLD, centre, 1)
	end
	local badgeHolder = Draw.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = centre,
		Size = UDim2.fromOffset(art.width, art.height),
		ZIndex = 4,
		Parent = root,
	}) :: Frame
	local badgeScale = Draw.new("UIScale", { Scale = 0.01, Parent = badgeHolder }) :: UIScale
	Icons.tier(data.tier, art.width, badgeHolder, nil, 4)

	local hp, hs = toRect(rects.header)
	Draw.text({
		Name = "Header",
		Position = hp,
		Size = hs,
		Text = Loc.t("moment.tier_up"),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = root,
	}, Theme.TEXT.body, "body")
	local np, ns = toRect(rects.name)
	Draw.text({
		Name = "TierName",
		Position = np,
		Size = ns,
		Text = string.upper(Loc.t(`tier.{data.tier}`)),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = root,
	}, Theme.TEXT.title, "display")

	local foodScales: { UIScale } = {}
	local line = rects.line
	if line then
		local lp, ls = toRect(line)
		local row = Draw.new("Frame", {
			Name = "NewFood",
			Position = lp,
			Size = ls,
			ZIndex = 4,
			Parent = root,
		}) :: Frame
		Draw.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, spec.foodGap),
			Parent = row,
		})
		Draw.text({
			Name = "FoodLabel",
			LayoutOrder = 0,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			Text = Loc.t("moment.new_food"),
			ZIndex = 4,
			Parent = row,
		}, Theme.TEXT.small, "body")
		for i, preyId in data.food do
			table.insert(foodScales, preyIcon(preyId, spec.foodIcon, row, i))
		end
	end

	return {
		root = root,
		rect = rects.card,
		update = function(t: number)
			-- The badge pops in with the card; the food icons pop as it lands (08 §11.3 number pop).
			badgeScale.Scale = math.max(0.01, MomentQueue.popScale(t, 0))
			for _, s in foodScales do
				s.Scale = math.max(0.01, MomentQueue.popScale(t, MomentQueue.ENTER))
			end
			if rays then
				rays.Rotation = t * MomentQueue.RAYS_TURN
			end
		end,
	}
end

return table.freeze(TierUp)
