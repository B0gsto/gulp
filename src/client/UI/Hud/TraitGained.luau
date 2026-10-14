--!strict
-- S08 Trait gained (docs/08 section 4.3; task S6-C5): the moment card for a new trait, 420 × 104:
-- the trait icon (80 rpx) in its rarity frame (06 §4.4), `moment.trait_gained`, the trait's canon
-- name (`trait.<id>`, in capitals as 04 §3.3's GLOW) and its effect line (`trait.<id>.fx`, Body 24,
-- Small 22 if it does not fit). The icon is `MomentArt`'s glyph for the trait. Epic
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
local MomentArt = require("./MomentArt")
local MomentSlot = require("./MomentSlot")
local Screen = require("../Kit/Screen")
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
		-- 08 §4.3: over the card behind the icon and past its edge, up to the gap under the
		-- chip row (HudLayout.traitCard), in a halo of the rarity colour.
		rays = MomentArt.rays(root, rects.rays, rects.raysClip, frameColour, 0.05, 4)
		MomentArt.halo(root, centre, art.width, frameColour, 5)
	end
	-- The rarity frame (06 §4.4): a rounded square in the rarity colour with the navy outline,
	-- and a darker inner stroke in the same hue so even Common's pale grey reads on cream.
	local holder = Draw.new("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = centre,
		Size = UDim2.fromOffset(art.width, art.height),
		ZIndex = 6,
		Parent = root,
	}) :: Frame
	local scale = Draw.new("UIScale", { Scale = 0.01, Parent = holder }) :: UIScale
	local deep = frameColour:Lerp(Theme.INK, 0.45)
	local frame = Draw.new("Frame", {
		Name = "RarityFrame",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = frameColour,
		BackgroundTransparency = 0,
		ZIndex = 6,
		Parent = holder,
	}, { Draw.corner(16) }) :: Frame
	Draw.stroke(Theme.STROKE_ICON).Parent = frame
	Draw.new("UIGradient", {
		Color = ColorSequence.new(Theme.WHITE, frameColour:Lerp(Theme.INK, 0.12)),
		Rotation = 90,
		Parent = frame,
	})
	local inset = Draw.new("Frame", {
		Name = "Inset",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(art.width - 16, art.height - 16),
		BackgroundColor3 = Theme.PANEL,
		BackgroundTransparency = 0,
		ZIndex = 7,
		Parent = frame,
	}, { Draw.corner(10), Draw.stroke(2, deep) }) :: Frame
	MomentArt.trait(data.traitId, art.width - 24, inset, 8)

	local hp, hs = toRect(rects.header)
	Draw.text({
		Name = "Header",
		Position = hp,
		Size = hs,
		Text = Loc.t("moment.trait_gained"),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = root,
	}, spec.type.header, "body")
	local np, ns = toRect(rects.name)
	Draw.text({
		Name = "TraitName",
		Position = np,
		Size = ns,
		Text = string.upper(Loc.t(`trait.{data.traitId}`)),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = root,
	}, spec.type.name, "display")
	local line = rects.line
	local effect: TextLabel? = nil
	if line then
		local lp, ls = toRect(line)
		effect = Draw.text({
			Name = "Effect",
			Position = lp,
			Size = ls,
			Text = Loc.t(`trait.{data.traitId}.fx`),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 7,
			Parent = root,
		}, spec.type.line, "body")
	end
	local fitted = false

	return {
		root = root,
		rect = rects.card,
		update = function(t: number)
			-- The icon pops in with the card (08 §11.3 number pop).
			scale.Scale = math.max(0.01, MomentQueue.popScale(t, 0))
			local e = effect
			if not fitted and e and e.AbsoluteSize.X > 0 then
				-- 08 §1.5: a line that does not fit shrinks to Small 22, the floor, while the
				-- card is still transparent.
				fitted = true
				if not e.TextFits then
					e:SetAttribute(Screen.TEXT_RPX, HudLayout.TEXT_FLOOR)
					e.TextSize = Screen.textSize(HudLayout.TEXT_FLOOR)
				end
			end
			if rays then
				rays.Rotation = t * MomentQueue.RAYS_TURN
			end
		end,
	}
end

return table.freeze(TraitGained)
