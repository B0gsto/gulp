--!strict
-- S08 Trait gained (docs/08 section 4.3; task S6-C5): the moment card for a new trait, 420 × 112:
-- the trait icon (80 rpx) in its rarity frame (06 §4.4), `moment.trait_gained`, the trait's canon
-- name (`trait.<id>`, in capitals as 04 §3.3's GLOW) and its effect line (`trait.<id>.fx`). Epic
-- and Mythic hold 3 s and turn `UI_Common_Rays` behind the icon. Rects come from
-- `HudLayout.traitCard`; the slot (`MomentSlot`) moves it in and out. `HUD.Traits` plays the
-- slot's Just gained state at the same time, from `MomentSlot.shown` (08 §3.6).
-- Not here yet: `SFX_UI_TraitGain` and the haptic (08 §11.4: Medium, 30 ms, twice, 80 ms apart)
-- come with the sound and haptics module (TODO(B32)).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)
local Index = require(ReplicatedStorage.Shared.Data.Index)
local MomentQueue = require(ReplicatedStorage.Shared.Logic.MomentQueue)

local Draw = require("../Kit/Draw")
local Icons = require("../Kit/Icons")
local Loc = require("../Loc")
local MomentSlot = require("./MomentSlot")
local Theme = require("../Kit/Theme")

local TraitGained = {}

export type Data = {
	traitId: string,
	slotIndex: number, -- 1 to 3, the `HUD.Traits` slot it filled
}

local function rarity(traitId: string): string?
	local def = Index.Traits.byId[traitId]
	return if def then def.rarity else nil
end

--- The hold of this card (08 §4.1).
function TraitGained.hold(data: Data): number
	return MomentQueue.traitHold(rarity(data.traitId))
end

local function toRect(r: HudLayout.Rect): (UDim2, UDim2)
	return UDim2.fromOffset(r.x, r.y), UDim2.fromOffset(r.width, r.height)
end

--- Builds the card for `data` inside a `slot` sized moment slot.
function TraitGained.build(
	parent: Frame,
	slot: { width: number, height: number },
	data: Data
): MomentSlot.Card
	local rects = HudLayout.traitCard(slot)
	local spec = HudLayout.TRAIT_GAINED
	local frameColour = Icons.rarityColour(data.traitId)
	local position, size = toRect(rects.card)
	local root = Draw.new("Frame", {
		Name = "S08.TraitGained",
		Position = position,
		Size = size,
		ZIndex = 2,
		Parent = parent,
	}) :: Frame
	local panel = Draw.panel({
		Name = "Card",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = root,
	})
	Draw.shadow(panel, Theme.PANEL_RADIUS)

	local art = rects.art
	local centre = UDim2.fromOffset(art.x + art.width / 2, art.y + art.height / 2)
	local r = rarity(data.traitId)
	local rays: Frame? = nil
	if r == "Epic" or r == "Mythic" then
		rays = MomentSlot.rays(root, spec.rays, frameColour, centre, 1)
	end
	-- The rarity frame: a rounded square in the rarity colour, the icon on a cream inset.
	local holder = Draw.new("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = centre,
		Size = UDim2.fromOffset(art.width, art.height),
		ZIndex = 4,
		Parent = root,
	}) :: Frame
	local scale = Draw.new("UIScale", { Scale = 0.01, Parent = holder }) :: UIScale
	local frame = Draw.new("Frame", {
		Name = "RarityFrame",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = frameColour,
		BackgroundTransparency = 0,
		ZIndex = 4,
		Parent = holder,
	}, { Draw.corner(16) }) :: Frame
	Draw.stroke(Theme.STROKE_ICON).Parent = frame
	local inset = Draw.new("Frame", {
		Name = "Inset",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(art.width - 16, art.height - 16),
		BackgroundColor3 = Theme.PANEL,
		BackgroundTransparency = 0,
		ZIndex = 5,
		Parent = frame,
	}, { Draw.corner(10) }) :: Frame
	Icons.trait(data.traitId, art.width - 24, inset, nil, 6)

	local hp, hs = toRect(rects.header)
	Draw.text({
		Name = "Header",
		Position = hp,
		Size = hs,
		Text = Loc.t("moment.trait_gained"),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = root,
	}, Theme.TEXT.body, "body")
	local np, ns = toRect(rects.name)
	Draw.text({
		Name = "TraitName",
		Position = np,
		Size = ns,
		Text = string.upper(Loc.t(`trait.{data.traitId}`)),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = root,
	}, Theme.TEXT.title, "display")
	local line = rects.line
	if line then
		local lp, ls = toRect(line)
		Draw.text({
			Name = "Effect",
			Position = lp,
			Size = ls,
			Text = Loc.t(`trait.{data.traitId}.fx`),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 4,
			Parent = root,
		}, Theme.TEXT.small, "body")
	end

	return {
		root = root,
		rect = rects.card,
		update = function(t: number)
			-- The icon pops in with the card (08 §11.3 number pop).
			scale.Scale = math.max(0.01, MomentQueue.popScale(t, 0))
			if rays then
				rays.Rotation = t * MomentQueue.RAYS_TURN
			end
		end,
	}
end

return table.freeze(TraitGained)
