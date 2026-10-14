--!strict
-- HUD.TraitMarkers (docs/08 section 3.10; docs/02 section 8.4 Glow; task S6-C3): while the player
-- holds Glow, trait prey within 60 studs of the creature's centre, through terrain, get a marker
-- coloured by rarity: a ring around the prey when it is on screen, a 44 rpx edge marker
-- (`UI_HUD_TraitMarker`, the trait icon at 28 rpx, a pointer toward the prey) clamped 40 rpx
-- inside the content box when it is off screen. Six nearest at most; prey of a held trait shows
-- dimmed. Hud picks and places them each frame; this module only draws. On the `GulpWorld` layer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)
local TraitRules = require(ReplicatedStorage.Shared.Logic.TraitRules)

local Draw = require("../Kit/Draw")
local Icons = require("../Kit/Icons")
local Theme = require("../Kit/Theme")

local TraitMarkers = {}

export type Placement = {
	-- Full-screen rpx of the marker centre.
	x: number,
	y: number,
	onScreen: boolean,
	angle: number, -- screen-space angle toward the prey (radians; 0 = right, π/2 = down)
	traitId: string,
	dimmed: boolean,
}

export type TraitMarkers = {
	root: Frame,
	--- Shows marker `index` (1 to six) at `p`, or hides it with nil.
	place: (index: number, p: Placement?) -> (),
	--- Hides every marker from `index` on.
	hideFrom: (index: number) -> (),
}

local DIMMED = 0.6 -- group transparency of a held trait's marker (02 §8.4 "show dimmed")
local RING = 56 -- rpx: the on-screen ring around the prey
local POINTER = 14
local POINTER_ORBIT = HudLayout.TRAIT_MARKER.size / 2 + 8

type Marker = {
	group: CanvasGroup,
	ring: Frame,
	ringStroke: UIStroke,
	disc: Frame,
	orbit: Frame,
	pointer: Frame,
	icon: Frame?,
	iconHolder: Frame,
	traitId: string?,
}

local function newMarker(parent: Instance, index: number): Marker
	local spec = HudLayout.TRAIT_MARKER
	local box = RING + 2 * POINTER_ORBIT
	local group = Draw.new("CanvasGroup", {
		Name = `Marker{index}`,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(box, box),
		Visible = false,
		Parent = parent,
	}) :: CanvasGroup

	-- On screen: a ring around the prey (rarity colour).
	local ring = Draw.disc(RING, Theme.WHITE, nil, {
		Name = "Ring",
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = group,
	})
	local ringStroke = Draw.stroke(Theme.STROKE_PANEL, Theme.RARITY.Common)
	ringStroke.Parent = ring

	-- Off screen: the marker disc tinted by rarity, its icon and a pointer on an orbit.
	local disc = Draw.disc(spec.size, Theme.RARITY.Common, nil, {
		Name = "Edge",
		ZIndex = 2,
		Parent = group,
	})
	Draw.stroke(Theme.STROKE_ICON).Parent = disc
	Draw.slot("UI_HUD_TraitMarker", disc, 3)
	local iconHolder = Draw.new("Frame", {
		Name = "IconHolder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(spec.icon, spec.icon),
		ZIndex = 4,
		Parent = disc,
	}) :: Frame
	local orbit = Draw.new("Frame", {
		Name = "Orbit",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(2 * POINTER_ORBIT, 2 * POINTER_ORBIT),
		ZIndex = 2,
		Parent = group,
	}) :: Frame
	local pointer = Draw.new("Frame", {
		Name = "Pointer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(POINTER, POINTER),
		Rotation = 45,
		BackgroundColor3 = Theme.RARITY.Common,
		BackgroundTransparency = 0,
		ZIndex = 2,
		Parent = orbit,
	}, { Draw.stroke(Theme.STROKE_CHIP) }) :: Frame

	return {
		group = group,
		ring = ring,
		ringStroke = ringStroke,
		disc = disc,
		orbit = orbit,
		pointer = pointer,
		icon = nil,
		iconHolder = iconHolder,
		traitId = nil,
	}
end

function TraitMarkers.new(parent: Instance): TraitMarkers
	local root = Draw.new("Frame", {
		Name = "HUD.TraitMarkers",
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	}) :: Frame
	local markers: { Marker } = {}
	for i = 1, TraitRules.GLOW_MARKERS do
		table.insert(markers, newMarker(root, i))
	end

	local function place(index: number, p: Placement?)
		local m = markers[index]
		if m == nil then
			return
		end
		if p == nil then
			m.group.Visible = false
			return
		end
		if m.traitId ~= p.traitId then
			m.traitId = p.traitId
			if m.icon then
				m.icon:Destroy()
			end
			m.icon = Icons.trait(p.traitId, HudLayout.TRAIT_MARKER.icon, m.iconHolder, nil, 5)
			local colour = Icons.rarityColour(p.traitId)
			m.ringStroke.Color = colour
			m.disc.BackgroundColor3 = colour
			m.pointer.BackgroundColor3 = colour
		end
		m.group.Visible = true
		m.group.Position = UDim2.fromOffset(p.x, p.y)
		m.group.GroupTransparency = if p.dimmed then DIMMED else 0
		m.ring.Visible = p.onScreen
		m.disc.Visible = not p.onScreen
		m.orbit.Visible = not p.onScreen
		m.orbit.Rotation = math.deg(p.angle)
	end

	return {
		root = root,
		place = place,
		hideFrom = function(index: number)
			for i = index, #markers do
				markers[i].group.Visible = false
			end
		end,
	}
end

return table.freeze(TraitMarkers)
