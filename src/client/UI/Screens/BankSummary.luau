--!strict
-- S12 Bank summary, build stage 2 (docs/08 sections 4.5 and 15): the title, the Pearls table
-- (mass row, one row per multiplier, the counted-up total and "New best!") and the specimen card
-- (stage 2: a static 3D render, tier, traits, Pearls an hour and "New specimen!", or the tier 2
-- badge with "Reach Nibbler to keep it" after a tier 1 run), with Continue, which is active from
-- the start (the panel has no close control, 08 §2.2). The bottom row (Codex finds, Reef Rank,
-- goals) and the cove-full choice (S13) come with their screens in stage 3 and launch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)
local HudMath = require(ReplicatedStorage.Shared.Logic.HudMath)
local Index = require(ReplicatedStorage.Shared.Data.Index)

local CreatureRig = require("../../Render/CreatureRig")
local Draw = require("../Kit/Draw")
local Icons = require("../Kit/Icons")
local Loc = require("../Loc")
local Screen = require("../Kit/Screen")
local Scrim = require("./Scrim")
local Theme = require("../Kit/Theme")

local BankSummary = {}

export type Row = { nameKey: string, value: number, icon: ("trait" | "pass")? }
--- The specimen the bank added (08 §4.5 step 5): species, tier, traits and Pearls an hour.
export type Specimen = { sp: string, tier: number, traits: { string }, perHour: number }
--- `specimen` when the run kept one; `tooSmall` after a tier 1 run (no specimen, 08 §4.5).
export type Data = {
	mass: number,
	multipliers: { Row },
	total: number,
	best: boolean,
	specimen: Specimen?,
	tooSmall: boolean?,
}

-- 08 §4.5 timeline.
local T_MASS, T_MULT, T_MULT_STEP, COUNT, T_CARD = 0.3, 0.6, 0.3, 1.0, 0.2
local CARD_IN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local RARITY_ORDER = { "Mythic", "Epic", "Rare", "Uncommon", "Common" }

local token = 0
local current: Frame? = nil
local currentTotal: GuiObject? = nil
local currentRig: CreatureRig.Rig? = nil

local function pearlIcon(size: number, parent: Instance): Frame
	return Icons.pearl(size, parent, nil, 4)
end

local function shortText(n: number): string
	local digits, kind = HudMath.short(n)
	if kind == "thousand" then
		return Loc.t("common.thousand", { Value = digits })
	elseif kind == "million" then
		return Loc.t("common.million", { Value = digits })
	end
	return digits
end

local function multiplierText(value: number): string
	-- A number with the multiplication sign; no words (08 §14.0).
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return "×" .. text
end

local function row(
	parent: Instance,
	y: number,
	width: number,
	label: string,
	value: string,
	iconColour: Color3?
): Frame
	local p = HudLayout.PEARLS
	local r = Draw.new("Frame", {
		Name = "Row",
		Position = UDim2.fromOffset(p.padding, y),
		Size = UDim2.fromOffset(width - 2 * p.padding, p.rowHeight),
		ZIndex = 3,
		Parent = parent,
	}) :: Frame
	local x = 0
	if iconColour then
		local icon = Draw.disc(32, iconColour, UDim2.new(0, 16, 0.5, 0), { ZIndex = 4, Parent = r })
		Draw.stroke(Theme.STROKE_CHIP).Parent = icon
		x = 44
	end
	Draw.text({
		Name = "Name",
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.new(0.7, -x, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = label,
		ZIndex = 4,
		Parent = r,
	}, Theme.TEXT.body, "body")
	Draw.text({
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.3, 1),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = value,
		ZIndex = 4,
		Parent = r,
	}, Theme.TEXT.number, "display")
	return r
end

-- The highest rarity among `traits` (06 §4.4), or nil for none: it picks the card frame (08 §5.2).
local function topRarity(traits: { string }): string?
	local have: { [string]: boolean } = {}
	for _, id in traits do
		local def = Index.Traits.byId[id]
		if def then
			have[def.rarity] = true
		end
	end
	for _, r in RARITY_ORDER do
		if have[r] then
			return r
		end
	end
	return nil
end

-- A static ViewportFrame of the creature (08 §5.2: drawn once), seen from the side.
local function render(holder: Frame, sp: string): CreatureRig.Rig?
	local ok, rig = pcall(function()
		local def = Index.Species.byId[sp]
		return CreatureRig.new(sp, if def then def.radiusMult else 1)
	end)
	if not ok or rig == nil then
		return nil
	end
	local view = Draw.new("ViewportFrame", {
		Name = "Render",
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(190, 200, 215),
		LightColor = Color3.fromRGB(255, 244, 225),
		LightDirection = Vector3.new(-0.4, -1, -0.5),
		ZIndex = 4,
		Parent = holder,
	}) :: ViewportFrame
	local model = rig.model
	model.Parent = view
	model:PivotTo(CFrame.new())
	local cf, size = model:GetBoundingBox()
	local reach = math.max(size.X, size.Y, size.Z)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local eye = cf.Position + Vector3.new(reach * 1.2, reach * 0.34, reach * 0.98)
	camera.CFrame = CFrame.lookAt(eye, cf.Position)
	camera.Parent = view
	view.CurrentCamera = camera
	return rig
end

-- 08 §4.5 step 5: the specimen card, or the tier 2 badge and `bank.too_small` (no specimen).
local function card(parent: Instance, rect: HudLayout.Rect, data: Data): Frame
	local c = HudLayout.SPECIMEN_CARD
	local s = data.specimen
	local rarity = if s then topRarity(s.traits) else nil
	local frameColour = if rarity then (Theme.RARITY :: any)[rarity] else Theme.INK
	local root = Draw.new("Frame", {
		Name = "Specimen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(rect.x + rect.width / 2, rect.y + rect.height / 2),
		Size = UDim2.fromOffset(rect.width, rect.height),
		ZIndex = 2,
		Parent = parent,
	}) :: Frame
	local face = Draw.panel({
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = root,
	}, `UI_Cove_Card{rarity or "Plain"}`)
	Draw.shadow(face, Theme.PANEL_RADIUS)
	local stroke = face:FindFirstChildOfClass("UIStroke")
	if stroke and rarity then
		stroke.Color = frameColour
		stroke.Thickness = Theme.STROKE_PANEL * 1.6
	end
	local inner = rect.width - 2 * c.padding
	local y = c.padding
	-- The render well: a deep-water vignette behind the creature.
	local well = Draw.new("Frame", {
		Name = "Well",
		Position = UDim2.fromOffset(c.padding, y),
		Size = UDim2.fromOffset(inner, c.renderHeight),
		BackgroundColor3 = Theme.SECONDARY_SHADE,
		BackgroundTransparency = 0,
		ClipsDescendants = true,
		ZIndex = 3,
		Parent = face,
	}, { Draw.corner(14), Draw.stroke(Theme.STROKE_CHIP) }) :: Frame
	Draw.new("UIGradient", {
		Color = ColorSequence.new(Theme.SECONDARY, Theme.INK:Lerp(Theme.SECONDARY_SHADE, 0.5)),
		Rotation = 90,
		Parent = well,
	})
	y += c.renderHeight + c.rowGap
	if s then
		currentRig = render(well, s.sp)
		local tierRow = Draw.new("Frame", {
			Name = "TierRow",
			Position = UDim2.fromOffset(c.padding, y),
			Size = UDim2.fromOffset(inner, c.tierHeight),
			ZIndex = 3,
			Parent = face,
		}) :: Frame
		Icons.tier(s.tier, c.tierHeight, tierRow, UDim2.new(0, c.tierHeight / 2, 0.5, 0), 4)
		Draw.text({
			Name = "TierName",
			Position = UDim2.fromOffset(c.tierHeight + 10, 0),
			Size = UDim2.new(1, -(c.tierHeight + 10), 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = Loc.t(`tier.{s.tier}`),
			TextColor3 = Theme.INK,
			ZIndex = 4,
			Parent = tierRow,
		}, Theme.TEXT.number, "display")
		y += c.tierHeight + c.rowGap
		local count = math.min(#s.traits, 3)
		local span = count * c.traitSize + math.max(0, count - 1) * c.rowGap
		for i = 1, count do
			local x = c.padding + (inner - span) / 2 + (i - 1) * (c.traitSize + c.rowGap)
			Icons.trait(
				s.traits[i],
				c.traitSize,
				face,
				UDim2.fromOffset(x + c.traitSize / 2, y + c.traitSize / 2),
				4
			)
		end
		y += c.traitSize + c.rowGap
		local income = Draw.new("Frame", {
			Name = "Income",
			Position = UDim2.fromOffset(c.padding, y),
			Size = UDim2.fromOffset(inner, c.incomeHeight),
			ZIndex = 3,
			Parent = face,
		}, {
			Draw.new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
			}),
		}) :: Frame
		local pearlHolder = Draw.new("Frame", {
			Size = UDim2.fromOffset(28, 28),
			LayoutOrder = 1,
			ZIndex = 3,
			Parent = income,
		}) :: Frame
		Icons.pearl(28, pearlHolder, nil, 4)
		Draw.text({
			Name = "PerHour",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, c.incomeHeight),
			LayoutOrder = 2,
			Text = Loc.t("common.per_hour", { Amount = HudMath.grouped(s.perHour) }),
			TextColor3 = Theme.INK,
			ZIndex = 4,
			Parent = income,
		}, Theme.TEXT.body, "body")
		y += c.incomeHeight + c.rowGap
		local ribbon = Draw.new("Frame", {
			Name = "NewSpecimen",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, y),
			Size = UDim2.fromOffset(inner - 16, c.ribbonHeight),
			Rotation = -2,
			BackgroundColor3 = Theme.PRIMARY,
			BackgroundTransparency = 0,
			ZIndex = 4,
			Parent = face,
		}, { Draw.corner(), Draw.stroke(Theme.STROKE_CHIP) }) :: Frame
		Draw.text({
			Size = UDim2.fromScale(1, 1),
			Text = Loc.t("bank.new_specimen"),
			TextColor3 = Theme.INK,
			ZIndex = 5,
			Parent = ribbon,
		}, Theme.TEXT.body, "display")
	else
		-- Tier 1 run: the tier 2 badge in the well and the note under it.
		Icons.tier(2, 96, well, UDim2.fromScale(0.5, 0.5), 4)
		local note = Draw.text({
			Name = "TooSmall",
			Position = UDim2.fromOffset(c.padding, y + 8),
			Size = UDim2.fromOffset(inner, rect.height - y - c.padding - 8),
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = Loc.t("bank.too_small"),
			TextColor3 = Theme.INK,
			ZIndex = 4,
			Parent = face,
		}, Theme.TEXT.title * 0.8, "display")
		note.TextWrapped = true
	end
	return root
end

--- Screen pixels of the counted Pearl total, for the flight to the cove HUD (08 §4.5 step 7).
function BankSummary.totalPosition(): Vector2?
	local total = currentTotal
	if total == nil then
		return nil
	end
	return total.AbsolutePosition + Vector2.new(32, total.AbsoluteSize.Y / 2)
end

--- Opens S12 with `data`; `continue` runs on the Continue button.
function BankSummary.open(data: Data, continue: () -> ())
	BankSummary.close(true)
	token += 1
	local my = token
	local layout = Screen.layout()
	local p = HudLayout.PEARLS
	local withCard = data.specimen ~= nil or data.tooSmall == true
	local rects = HudLayout.pearls(layout.contentSize, #data.multipliers, withCard)
	local _, layer = Screen.createLayer("GulpMoments")
	local frame = Draw.new(
		"Frame",
		{ Name = "S12.BankSummary", Size = UDim2.fromScale(1, 1), Parent = layer }
	) :: Frame
	current = frame
	Scrim.set(true, 0.15)

	-- Title: `UI_Moment_BankShell` stand-in and `bank.title`, tilted 3° (06 §12.2).
	local title = Draw.new("Frame", {
		Name = "Title",
		Position = UDim2.fromOffset(rects.title.x, rects.title.y),
		Size = UDim2.fromOffset(rects.title.width, rects.title.height),
		Rotation = -3,
		Parent = frame,
	}) :: Frame
	local shell = Draw.disc(
		72,
		Theme.PEARL_SHADE,
		UDim2.new(0.5, -170, 0.5, 0),
		{ Name = "UI_Moment_BankShell", ZIndex = 2, Parent = title }
	)
	Draw.stroke(Theme.STROKE_ICON).Parent = shell
	for i = -2, 2 do
		Draw.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.92),
			Size = UDim2.fromOffset(4, 52),
			Rotation = i * 22,
			BackgroundColor3 = Theme.INK,
			BackgroundTransparency = 0.55,
			ZIndex = 3,
			Parent = shell,
		}, { Draw.corner() })
	end
	Draw.slot("UI_Moment_BankShell", shell, 6)
	Draw.text({
		Name = "Text",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(1, 1),
		Text = Loc.t("bank.title"),
		TextColor3 = Theme.PRIMARY,
		ZIndex = 4,
		Parent = title,
	}, Theme.TEXT.title * 1.3, "display", Theme.STROKE_PANEL)

	-- The Pearls table.
	local panel = Draw.panel({
		Name = "Pearls",
		Position = UDim2.fromOffset(rects.panel.x, rects.panel.y),
		Size = UDim2.fromOffset(rects.panel.width, rects.panel.height),
		ZIndex = 2,
		Parent = frame,
	})
	Draw.shadow(panel, Theme.PANEL_RADIUS)
	local scale = Draw.new("UIScale", { Parent = panel, Scale = 0.8 }) :: UIScale
	Draw.tween(scale, Theme.MOTION.panelIn, { Scale = 1 })
	Draw.text({
		Name = "Header",
		Position = UDim2.fromOffset(p.padding, p.padding),
		Size = UDim2.new(1, -2 * p.padding, 0, p.headerHeight),
		Text = Loc.t("common.pearls"),
		ZIndex = 3,
		Parent = panel,
	}, Theme.TEXT.title, "display")

	local rows: { Frame } = {}
	local y = rects.rowsTop
	local massRow = row(panel, y, p.width, Loc.t("common.mass"), shortText(data.mass), nil)
	table.insert(rows, massRow)
	for _, m in data.multipliers do
		y += p.rowHeight
		local colour = if m.icon == "pass" then Theme.PRIMARY else Theme.SECONDARY
		table.insert(
			rows,
			row(panel, y, p.width, Loc.t(m.nameKey), multiplierText(m.value), colour)
		)
	end
	y += p.rowHeight
	-- Wavy divider stand-in: a row of small dashes (06 §12.2: never a 1-pixel rule).
	local divider = Draw.new("Frame", {
		Name = "Divider",
		Position = UDim2.fromOffset(p.padding, y + p.dividerHeight / 2 - 3),
		Size = UDim2.new(1, -2 * p.padding, 0, 6),
		ZIndex = 3,
		Parent = panel,
	}, {
		Draw.new(
			"UIListLayout",
			{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }
		),
	}) :: Frame
	for i = 1, 26 do
		Draw.new("Frame", {
			Size = UDim2.fromOffset(12, 5),
			Rotation = if i % 2 == 0 then 8 else -8,
			BackgroundColor3 = Theme.PANEL_SHADE:Lerp(Theme.INK, 0.25),
			BackgroundTransparency = 0,
			ZIndex = 3,
			Parent = divider,
		}, { Draw.corner() })
	end
	y += p.dividerHeight
	local totalRow = Draw.new("Frame", {
		Name = "Total",
		Position = UDim2.fromOffset(p.padding, y),
		Size = UDim2.new(1, -2 * p.padding, 0, p.totalHeight),
		ZIndex = 3,
		Parent = panel,
	}) :: Frame
	local iconHolder = Draw.new("Frame", {
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.fromOffset(0, 8),
		ZIndex = 3,
		Parent = totalRow,
	}) :: Frame
	pearlIcon(52, iconHolder)
	local total = Draw.text({
		Name = "Amount",
		Position = UDim2.fromOffset(68, 0),
		Size = UDim2.fromScale(0.5, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0",
		ZIndex = 4,
		Parent = totalRow,
	}, Theme.TEXT.hero * 0.85, "display")
	local totalScale = Draw.new("UIScale", { Parent = total }) :: UIScale
	currentTotal = iconHolder
	local specimenCard = if rects.card then card(frame, rects.card, data) else nil
	local cardScale = if specimenCard
		then Draw.new("UIScale", { Parent = specimenCard, Scale = 1 }) :: UIScale
		else nil
	if specimenCard then
		specimenCard.Visible = false
	end
	local best = Draw.new("Frame", {
		Name = "Best",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(176, 44),
		Rotation = 4,
		BackgroundColor3 = Theme.PRIMARY,
		BackgroundTransparency = 0,
		Visible = false,
		ZIndex = 4,
		Parent = totalRow,
	}, { Draw.corner(), Draw.stroke(Theme.STROKE_CHIP) }) :: Frame
	Draw.text(
		{ Size = UDim2.fromScale(1, 1), Text = Loc.t("bank.best"), ZIndex = 5, Parent = best },
		Theme.TEXT.body,
		"display"
	)
	Draw.slot("UI_Moment_PersonalBest", best, 6)

	local continueButton = Draw.button(
		"Primary",
		p.continueWidth,
		p.continueHeight,
		Loc.t("common.continue"),
		HudLayout.TOUCH_MIN,
		continue
	)
	continueButton.root.Name = "Continue"
	continueButton.root.Position = UDim2.fromOffset(rects.continue.x, rects.continue.y)
	continueButton.root.Parent = frame

	-- Steps 2 to 4 of 08 §4.5; a tap anywhere jumps to the end state.
	for _, r in rows do
		r.Visible = false
	end
	divider.Visible = false
	totalRow.Visible = false
	local finished = false
	local function finish()
		if finished or token ~= my then
			return
		end
		finished = true
		for _, r in rows do
			r.Visible = true
		end
		divider.Visible = true
		totalRow.Visible = true
		total.Text = shortText(data.total)
		best.Visible = data.best
		if specimenCard then
			specimenCard.Visible = true
			specimenCard.Rotation = 0
		end
	end
	local skip = Draw.new("TextButton", {
		Name = "Skip",
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		AutoButtonColor = false,
		Parent = frame,
	})
	skip.Activated:Connect(finish)
	task.spawn(function()
		local start = os.clock()
		local function waitUntil(t: number): boolean
			while os.clock() - start < t do
				task.wait()
				if finished or token ~= my then
					return false
				end
			end
			return true
		end
		if not waitUntil(T_MASS) then
			return
		end
		rows[1].Visible = true
		for i = 2, #rows do
			if not waitUntil(T_MULT + (i - 2) * T_MULT_STEP) then
				return
			end
			rows[i].Visible = true
		end
		local countFrom = T_MULT + math.max(0, #rows - 2) * T_MULT_STEP + T_MULT_STEP
		if not waitUntil(countFrom) then
			return
		end
		divider.Visible = true
		totalRow.Visible = true
		-- TODO(B32): `SFX_UI_PearlTick` every 60 ms, `SFX_UI_PearlBurst` at the end.
		local t0 = os.clock()
		while os.clock() - t0 < COUNT do
			if finished or token ~= my then
				return
			end
			local k = (os.clock() - t0) / COUNT
			total.Text = shortText(data.total * (1 - (1 - k) * (1 - k)))
			task.wait()
		end
		totalScale.Scale = 1.3
		Draw.tween(totalScale, Theme.MOTION.release, { Scale = 1 })
		total.Text = shortText(data.total)
		best.Visible = data.best
		-- Step 5: the card flips in 200 ms later (400 ms). TODO(B32): `SFX_UI_BankCard`.
		if specimenCard and cardScale and not waitUntil(countFrom + COUNT + T_CARD) then
			return
		end
		finish()
		if specimenCard and cardScale then
			specimenCard.Rotation = -10
			cardScale.Scale = 0.4
			Draw.tween(cardScale, CARD_IN, { Scale = 1 })
			Draw.tween(specimenCard, CARD_IN, { Rotation = 0 })
		end
	end)
end

function BankSummary.close(instant: boolean?)
	token += 1
	local frame = current
	current = nil
	currentTotal = nil
	local rig = currentRig
	currentRig = nil
	if rig then
		CreatureRig.destroy(rig)
	end
	if frame then
		frame:Destroy()
	end
	if not instant then
		Scrim.set(false, 0.15)
	end
end

return BankSummary
