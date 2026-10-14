--!strict
-- Kit/Icons: code-drawn stand-ins for the small icons several screens share (docs/08 section 13,
-- docs/06 section 12.4: flat fill, navy stroke, one white highlight). Each carries the empty image
-- slot named after its 08 §13 image, so the illustrated art drops in without layout changes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Index = require(ReplicatedStorage.Shared.Data.Index)

local Draw = require("./Draw")
local Theme = require("./Theme")

local Icons = {}

--- `UI_Common_Pearl`: a cream-pink pearl with one glint, `size` rpx, centred at `position`.
function Icons.pearl(size: number, parent: Instance, position: UDim2?, zIndex: number?): Frame
	local z = zIndex or 4
	local pearl = Draw.disc(
		size,
		Theme.PEARL,
		position or UDim2.fromScale(0.5, 0.5),
		{ Name = "Pearl", ZIndex = z, Parent = parent }
	)
	Draw.new(
		"UIGradient",
		{ Color = ColorSequence.new(Theme.PEARL, Theme.PEARL_SHADE), Rotation = 60, Parent = pearl }
	)
	Draw.stroke(Theme.STROKE_ICON).Parent = pearl
	Draw.disc(
		size * 0.26,
		Theme.WHITE,
		UDim2.fromScale(0.34, 0.3),
		{ ZIndex = z + 1, Parent = pearl }
	)
	Draw.slot("UI_Common_Pearl", pearl, z + 2)
	return pearl
end

--- `UI_Common_Plus`: a sun-yellow disc with a navy plus, `size` rpx, centred at `position`.
function Icons.plus(size: number, parent: Instance, position: UDim2?, zIndex: number?): Frame
	local z = zIndex or 4
	local disc = Draw.disc(
		size,
		Theme.PRIMARY,
		position or UDim2.fromScale(0.5, 0.5),
		{ Name = "Plus", ZIndex = z, Parent = parent }
	)
	Draw.stroke(Theme.STROKE_ICON).Parent = disc
	for _, horizontal in { true, false } do
		Draw.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = if horizontal
				then UDim2.fromOffset(size * 0.5, size * 0.14)
				else UDim2.fromOffset(size * 0.14, size * 0.5),
			BackgroundColor3 = Theme.INK,
			BackgroundTransparency = 0,
			ZIndex = z + 1,
			Parent = disc,
		}, { Draw.corner() })
	end
	Draw.slot("UI_Common_Plus", disc, z + 2)
	return disc
end

--- `UI_Icon_Tier{n}`: the tier ring (06 §12.4 colours) around a cream disc with the number.
function Icons.tier(
	tier: number,
	size: number,
	parent: Instance,
	position: UDim2?,
	zIndex: number?
): Frame
	local z = zIndex or 4
	local t = math.clamp(tier, 1, #Theme.TIER_RING)
	local ring = Draw.disc(
		size,
		Theme.TIER_RING[t],
		position or UDim2.fromScale(0.5, 0.5),
		{ Name = "Tier", ZIndex = z, Parent = parent }
	)
	Draw.stroke(Theme.STROKE_ICON).Parent = ring
	local inner = Draw.disc(size * 0.72, Theme.PANEL, nil, { ZIndex = z + 1, Parent = ring })
	Draw.stroke(Theme.STROKE_CHIP * 0.75).Parent = inner
	Draw.text({
		Name = "Number",
		Size = UDim2.fromScale(1, 1),
		Text = tostring(t),
		ZIndex = z + 2,
		Parent = inner,
	}, math.max(22, size * 0.5), "display")
	Draw.disc(
		size * 0.16,
		Theme.WHITE,
		UDim2.fromScale(0.28, 0.24),
		{ ZIndex = z + 2, BackgroundTransparency = 0.2, Parent = ring }
	)
	Draw.slot(`UI_Icon_Tier{t}`, ring, z + 3)
	return ring
end

--- The colour of a trait's rarity frame (06 §4.4), grey for an unknown trait.
function Icons.rarityColour(traitId: string): Color3
	local def = Index.Traits.byId[traitId]
	local colour = if def then (Theme.RARITY :: any)[def.rarity] else nil
	return colour or Theme.RARITY.Common
end

--- `UI_Icon_Trait{Name}`: a trait icon stand-in, a disc in its rarity colour with the initial.
function Icons.trait(
	traitId: string,
	size: number,
	parent: Instance,
	position: UDim2?,
	zIndex: number?
): Frame
	local z = zIndex or 4
	local disc = Draw.disc(
		size,
		Icons.rarityColour(traitId),
		position or UDim2.fromScale(0.5, 0.5),
		{ Name = "Trait", ZIndex = z, Parent = parent }
	)
	Draw.stroke(Theme.STROKE_CHIP).Parent = disc
	Draw.disc(size * 0.22, Theme.WHITE, UDim2.fromScale(0.3, 0.28), {
		ZIndex = z + 1,
		BackgroundTransparency = 0.25,
		Parent = disc,
	})
	local name = string.upper(string.sub(traitId, 1, 1)) .. string.sub(traitId, 2)
	Draw.slot(`UI_Icon_Trait{name}`, disc, z + 2)
	return disc
end

return table.freeze(Icons)
