--!strict
-- S07 Tier-up (docs/08 section 4.2; task S6-C5): the moment card for a tier rise, 460 × 104 on
-- `UI_Common_Ribbon`: the new tier badge, `moment.tier_up`, the tier's canon name (`tier.1` to
-- `tier.7`, shown in capitals as in 08 §4.2 and 04 §3.3's NIBBLER) and `moment.new_food` with
-- up to three prey that just became edible, each in an edible-colour ring. Tier 7 holds longer,
-- turns `UI_Common_Rays` behind a bigger, gold-rimmed badge and edges the ribbon in gold. Rects come from
-- `HudLayout.tierUpCard`; the slot (`MomentSlot`) moves it in and out. The images are
-- `MomentArt`'s stand-ins.
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
local MomentArt = require("./MomentArt")
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

-- `UI_Icon_Prey{Name}` in an edible-colour ring (08 §4.2), `size` rpx, popping in by its UIScale.
local function preyIcon(preyId: string, size: number, parent: Instance, order: number): UIScale
	local holder = Draw.new("Frame", {
		Name = `Food{order}`,
		LayoutOrder = order,
		Size = UDim2.fromOffset(size, size),
		ZIndex = 7,
		Parent = parent,
	}) :: Frame
	local scale = Draw.new("UIScale", { Scale = 0.01, Parent = holder }) :: UIScale
	MomentArt.prey(preyId, size, holder, 7)
	return scale
end

--- Builds the card for `data` inside a `slot` sized moment slot.
function TierUp.build(
	parent: Frame,
	slot: { width: number, height: number },
	data: Data
): MomentSlot.Card
	local top = data.tier >= TOP
	local rects = HudLayout.tierUpCard(slot, #data.food > 0, top)
	local spec = HudLayout.TIER_UP
	local position, size = toRect(rects.card)
	local root = Draw.new("Frame", {
		Name = "S07.TierUp",
		Position = position,
		Size = size,
		ZIndex = 2,
		Parent = parent,
	}) :: Frame

	-- `UI_Common_Ribbon` stand-in: a cream band with a notched sun-yellow tail tucked behind each
	-- end (gold at tier 7), all inside the 460 rpx card.
	local tailColour = if top then Theme.GOLD else Theme.PRIMARY
	for i, t in rects.tails do
		local left = i == 1
		local shown = if left
			then rects.band.x - t.x
			else t.x + t.width - (rects.band.x + rects.band.width)
		MomentArt.tail(root, t, left, spec.notch, shown, tailColour, Theme.STROKE_PANEL, 1)
	end
	local bp, bs = toRect(rects.band)
	local panel = Draw.panel({
		Name = "Ribbon",
		Position = bp,
		Size = bs,
		ZIndex = 3,
		Parent = root,
	}, "UI_Common_Ribbon")
	Draw.shadow(panel, Theme.PANEL_RADIUS)
	if top then
		-- Tier 7's gold edge, just inside the navy one.
		Draw.new("Frame", {
			Name = "GoldEdge",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -10, 1, -10),
			ZIndex = 3,
			Parent = panel,
		}, { Draw.corner(Theme.PANEL_RADIUS - 5), Draw.stroke(3, Theme.GOLD) })
	end
	local art = rects.art
	local centre = UDim2.fromOffset(art.x + art.width / 2, art.y + art.height / 2)
	local rays: Frame? = nil
	if top then
		-- 08 §4.2: the climax. Crisp gold spokes, light and dark in turn, turn over the band
		-- behind the badge, centred on it, past the card's side and up into the gap under the
		-- chip row, never below the card (HudLayout.tierUpCard).
		rays = MomentArt.rays(
			root,
			rects.rays,
			rects.raysClip,
			Theme.PRIMARY:Lerp(Theme.WHITE, 0.45),
			Theme.PRIMARY_SHADE,
			4
		)
	end
	local badgeHolder = Draw.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = centre,
		Size = UDim2.fromOffset(art.width, art.height),
		ZIndex = 6,
		Parent = root,
	}) :: Frame
	local badgeScale = Draw.new("UIScale", { Scale = 0.01, Parent = badgeHolder }) :: UIScale
	if top then
		-- The climax badge fills all 104 rpx: a gold rim with a white glint round the tier 7
		-- badge, so it reads bigger than the 96 rpx badges below it.
		local rim = Draw.disc(art.width, Theme.GOLD, nil, {
			Name = "GoldRim",
			ZIndex = 6,
			Parent = badgeHolder,
		})
		Draw.stroke(Theme.STROKE_ICON).Parent = rim
		local glint = Draw.disc(art.width - 4, Theme.GOLD, nil, {
			Name = "Glint",
			BackgroundTransparency = 1,
			ZIndex = 6,
			Parent = rim,
		})
		Draw.stroke(2, Theme.PRIMARY:Lerp(Theme.WHITE, 0.6)).Parent = glint
		Icons.tier(data.tier, art.width - 2 * spec.topRim, badgeHolder, nil, 7)
	else
		Icons.tier(data.tier, art.width, badgeHolder, nil, 6)
	end

	local hp, hs = toRect(rects.header)
	Draw.text({
		Name = "Header",
		Position = hp,
		Size = hs,
		Text = Loc.t("moment.tier_up"),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = root,
	}, spec.type.header, "body")
	local np, ns = toRect(rects.name)
	Draw.text({
		Name = "TierName",
		Position = np,
		Size = ns,
		Text = string.upper(Loc.t(`tier.{data.tier}`)),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = root,
	}, spec.type.name, "display")

	local foodScales: { UIScale } = {}
	local line = rects.line
	if line then
		local lp, ls = toRect(line)
		local row = Draw.new("Frame", {
			Name = "NewFood",
			Position = lp,
			Size = ls,
			ZIndex = 7,
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
			ZIndex = 7,
			Parent = row,
		}, spec.type.line, "body")
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
