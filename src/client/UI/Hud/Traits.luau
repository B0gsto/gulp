--!strict
-- HUD.Traits (docs/08 section 3.6; docs/04 section 3.2 "Pips"; task S6-C3): three 80 rpx trait
-- slots bottom centre, each with the five progress pips on an arc above it (four with Keen Nose).
-- What each slot shows comes from Logic/TraitRules.slotView; rects from Logic/HudLayout.traits.
--
-- States drawn here: Empty (`UI_HUD_TraitSlotEmpty`, a ring, no pips), In progress (the icon at
-- 45% opacity, no rarity frame, pips lit; a new pip pops to 1.4 x in 180 ms), Owned (the icon in
-- its rarity frame, pips hidden) and Just gained (a 600 ms flash; the S08 card is S6-C5's).
-- TODO(S04): the trait popover and the hold-to-shed button. TODO(S6-C5 or later): the Traits full
-- shake and `hud.traits_full` chip, and `SFX_UI_TraitPip`. TODO(B19): Used up (Plated cracked).
-- Image slots stay empty until the art lands: the stand-ins are drawn with Kit/Draw, and the
-- icon is MomentArt's trait glyph, the one the S08 card shows.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)
local TraitRules = require(ReplicatedStorage.Shared.Logic.TraitRules)

local Draw = require("../Kit/Draw")
local Icons = require("../Kit/Icons")
local MomentArt = require("./MomentArt")
local Theme = require("../Kit/Theme")

local Traits = {}

export type Traits = {
	root: Frame,
	layout: (rects: HudLayout.TraitRects) -> (),
	set: (views: { TraitRules.SlotView }) -> (),
	setCount: (count: number) -> (),
	gained: (index: number) -> (),
}

local PROGRESS_TRANSPARENCY = 0.55 -- 08 §3.6: the in-progress icon at 45% opacity
local PIP_POP = 1.4
local PIP_STROKE = Theme.STROKE_ICON -- both pip states' outline
local PIP_POP_IN = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PIP_POP_OUT = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FLASH = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local GAINED_POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- 08 §3.6: a filled pip is solid sun yellow with a navy outline; an empty one a cream outline only.
type Pip = { disc: Frame, scale: UIScale, stroke: UIStroke }

type Slot = {
	frame: Frame,
	scale: UIScale,
	empty: Frame,
	rarity: Frame,
	rarityStroke: UIStroke,
	iconGroup: CanvasGroup,
	icon: GuiObject?,
	flash: Frame,
	pips: { Pip },
	view: TraitRules.SlotView?,
}

local function newSlot(parent: Instance, index: number): Slot
	local t = HudLayout.TRAITS
	local frame = Draw.new("Frame", {
		Name = `Slot{index}`,
		Size = UDim2.fromOffset(t.slot, t.slot),
		Parent = parent,
	}) :: Frame
	local scale = Draw.new("UIScale", { Parent = frame }) :: UIScale

	-- Empty: a ring on a faint backing (stand-in for the dashed `UI_HUD_TraitSlotEmpty`).
	local empty = Draw.disc(t.slot - 4, Theme.DIM, nil, {
		Name = "Empty",
		BackgroundTransparency = 0.7,
		ZIndex = 1,
		Parent = frame,
	})
	Draw.stroke(Theme.STROKE_ICON, Theme.PANEL).Parent = empty
	Draw.slot("UI_HUD_TraitSlotEmpty", empty, 2)

	-- Owned: the rarity frame (stand-in for `UI_Common_Rarity<Rarity>`): a ring in the rarity
	-- colour round a cream inset, the S08 card's, so the glyph sits on what it was drawn for.
	local rarity = Draw.disc(t.slot, Theme.PANEL, nil, {
		Name = "Rarity",
		BackgroundTransparency = 0,
		ZIndex = 1,
		Visible = false,
		Parent = frame,
	})
	local rarityStroke = Draw.stroke(Theme.STROKE_PANEL * 1.5, Theme.RARITY.Common)
	rarityStroke.Parent = rarity
	Draw.slot("UI_Common_RarityCommon", rarity, 2).Name = "Frame"

	local iconGroup = Draw.new("CanvasGroup", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(t.icon + 8, t.icon + 8),
		ZIndex = 3,
		Parent = frame,
	}) :: CanvasGroup

	local flash = Draw.disc(t.slot, Theme.WHITE, nil, {
		Name = "Flash",
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = frame,
	})

	local pips: { Pip } = {}
	local origin = { x = 0, y = 0, width = t.slot, height = t.slot }
	for i, p in HudLayout.traitPips(origin, 5) do
		local disc = Draw.disc(t.pip, Theme.PRIMARY, UDim2.fromOffset(p.x, p.y), {
			Name = `Pip{i}`,
			BackgroundTransparency = 1,
			ZIndex = 6,
			Visible = false,
			Parent = frame,
		})
		local stroke = Draw.stroke(PIP_STROKE, Theme.PANEL)
		stroke.Parent = disc
		local pipScale = Draw.new("UIScale", { Parent = disc }) :: UIScale
		table.insert(pips, { disc = disc, scale = pipScale, stroke = stroke })
	end
	Draw.slot("UI_Hud_TraitPips", frame, 5)

	return {
		frame = frame,
		scale = scale,
		empty = empty,
		rarity = rarity,
		rarityStroke = rarityStroke,
		iconGroup = iconGroup,
		icon = nil,
		flash = flash,
		pips = pips,
		view = nil,
	}
end

-- Places the pips of a `needed` count (5, or 4 with Keen Nose) and lights the first `lit`.
local function drawPips(slot: Slot, needed: number, lit: number, shown: boolean)
	local t = HudLayout.TRAITS
	local origin = { x = 0, y = 0, width = t.slot, height = t.slot }
	local at = HudLayout.traitPips(origin, needed)
	for i, pip in slot.pips do
		local p = at[i]
		pip.disc.Visible = shown and p ~= nil
		if p then
			pip.disc.Position = UDim2.fromOffset(p.x, p.y)
			local on = i <= lit
			pip.disc.BackgroundTransparency = if on then 0 else 1
			pip.stroke.Color = if on then Theme.INK else Theme.PANEL
		end
	end
end

local function pop(pip: Pip)
	pip.scale.Scale = 1
	local grow = Draw.tween(pip.scale, PIP_POP_IN, { Scale = PIP_POP })
	grow.Completed:Once(function()
		Draw.tween(pip.scale, PIP_POP_OUT, { Scale = 1 })
	end)
end

local function apply(slot: Slot, view: TraitRules.SlotView)
	local before = slot.view
	slot.view = view
	local id = view.traitId
	local sameTrait = before ~= nil and before.traitId == id and before.state == view.state
	if not sameTrait then
		if slot.icon then
			slot.icon:Destroy()
			slot.icon = nil
		end
		if id then
			slot.icon = MomentArt.trait(id, HudLayout.TRAITS.icon, slot.iconGroup, 4)
		end
	end
	slot.empty.Visible = view.state ~= "owned"
	slot.rarity.Visible = view.state == "owned"
	if id then
		slot.rarityStroke.Color = Icons.rarityColour(id)
	end
	slot.iconGroup.Visible = id ~= nil
	slot.iconGroup.GroupTransparency = if view.state == "progress" then PROGRESS_TRANSPARENCY else 0
	-- 08 §3.6: pips show only in progress (Empty has none, Owned hides them). TODO(B31): 04 B5's
	-- first-run slot 1 with five empty pips before the first Glowfry is the tutorial's to ask for.
	drawPips(slot, view.needed, view.pips, view.state == "progress")
	if sameTrait and before and view.state == "progress" and view.pips > before.pips then
		for i = before.pips + 1, math.min(view.pips, #slot.pips) do
			pop(slot.pips[i])
		end
	end
end

function Traits.new(parent: Instance): Traits
	local root = Draw.new("Frame", {
		Name = "HUD.Traits",
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	}) :: Frame
	local slots: { Slot } = {}
	for i = 1, TraitRules.SLOTS do
		table.insert(slots, newSlot(root, i))
	end
	for _, slot in slots do
		apply(slot, { state = "empty", traitId = nil, pips = 0, needed = TraitRules.PIPS })
	end

	return {
		root = root,
		layout = function(rects: HudLayout.TraitRects)
			for i, slot in slots do
				local r = rects.slots[i]
				slot.frame.Position = UDim2.fromOffset(r.x, r.y)
			end
		end,
		-- 04 §3.8 (TutorialDirector): slots after the first `count` stay hidden.
		setCount = function(count: number)
			for i, slot in slots do
				slot.frame.Visible = i <= count
			end
		end,
		set = function(views: { TraitRules.SlotView })
			for i, slot in slots do
				local view = views[i]
				if view then
					apply(slot, view)
				end
			end
		end,
		gained = function(index: number)
			local slot = slots[index]
			if slot == nil then
				return
			end
			slot.flash.BackgroundTransparency = 0.15
			Draw.tween(slot.flash, FLASH, { BackgroundTransparency = 1 })
			slot.scale.Scale = 1.25
			Draw.tween(slot.scale, GAINED_POP, { Scale = 1 })
		end,
	}
end

return table.freeze(Traits)
