--!strict
-- S12 Bank summary, build stage 1 (docs/08 sections 4.5 and 15): the title and the Pearls table
-- only (mass row, one row per multiplier, the counted-up total and "New best!"), with Continue,
-- which is active from the start (the panel has no close control, 08 §2.2). The specimen card,
-- Codex row, Reef Rank and goals come in later stages.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)
local HudMath = require(ReplicatedStorage.Shared.Logic.HudMath)

local Draw = require("../Kit/Draw")
local Loc = require("../Loc")
local Screen = require("../Kit/Screen")
local Scrim = require("./Scrim")
local Theme = require("../Kit/Theme")

local BankSummary = {}

export type Row = { nameKey: string, value: number, icon: ("trait" | "pass")? }
export type Data = { mass: number, multipliers: { Row }, total: number, best: boolean }

-- 08 §4.5 timeline.
local T_MASS, T_MULT, T_MULT_STEP, COUNT = 0.3, 0.6, 0.3, 1.0

local token = 0
local current: Frame? = nil

local function pearlIcon(size: number, parent: Instance): Frame
	-- `UI_Common_Pearl` stand-in: a cream-pink pearl with one glint (06 §12.4).
	local pearl = Draw.disc(
		size,
		Theme.PEARL,
		UDim2.fromScale(0.5, 0.5),
		{ Name = "Pearl", ZIndex = 4, Parent = parent }
	)
	Draw.new(
		"UIGradient",
		{ Color = ColorSequence.new(Theme.PEARL, Theme.PEARL_SHADE), Rotation = 60, Parent = pearl }
	)
	Draw.stroke(Theme.STROKE_ICON).Parent = pearl
	Draw.disc(size * 0.26, Theme.WHITE, UDim2.fromScale(0.34, 0.3), { ZIndex = 5, Parent = pearl })
	Draw.slot("UI_Common_Pearl", pearl, 6)
	return pearl
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

--- Opens S12 with `data`; `continue` runs on the Continue button.
function BankSummary.open(data: Data, continue: () -> ())
	BankSummary.close(true)
	token += 1
	local my = token
	local layout = Screen.layout()
	local p = HudLayout.PEARLS
	local rects = HudLayout.pearls(layout.contentSize, #data.multipliers)
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
		UDim2.new(0.5, -150, 0.5, 0),
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
		finish()
	end)
end

function BankSummary.close(instant: boolean?)
	token += 1
	local frame = current
	current = nil
	if frame then
		frame:Destroy()
	end
	if not instant then
		Scrim.set(false, 0.15)
	end
end

return BankSummary
