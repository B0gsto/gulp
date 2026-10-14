--!strict
-- S11 Gulped panel, build stage 1 (docs/08 sections 4.4 and 15): the title and Swim again only.
-- The "what you lost" column, the revive offers and the eater line come in later stages. Swim
-- again is the primary button, 280 x 96, bottom right (zone A), always present, with no timer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)

local Draw = require("../Kit/Draw")
local Loc = require("../Loc")
local Screen = require("../Kit/Screen")
local Scrim = require("./Scrim")
local Theme = require("../Kit/Theme")

local Gulped = {}

-- 08 §4.4 timeline, seconds after the gulp.
local T_TITLE = 0.4
local T_PANEL = 0.9
local T_INPUT = 1.6 -- 700 ms guard against taps meant for dash

local root: Frame? = nil
local token = 0
local onSwimAgain: (() -> ())? = nil

local function splat(parent: Instance): Frame
	-- `UI_Moment_GulpedSplat` stand-in: a coral paper splat with droplets, tilted.
	local holder = Draw.new(
		"Frame",
		{ Name = "Splat", Size = UDim2.fromScale(1, 1), Rotation = -4, Parent = parent }
	) :: Frame
	local body = Draw.new("Frame", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -40, 1, -24),
		BackgroundColor3 = Theme.DECLINE,
		BackgroundTransparency = 0,
		ZIndex = 2,
		Parent = holder,
	}, { Draw.corner(48), Draw.stroke(Theme.STROKE_PANEL) }) :: Frame
	Draw.shadow(body, 48)
	for _, d in { { 0.04, 0.2, 34 }, { 0.97, 0.72, 40 }, { 0.9, 0.08, 22 }, { 0.1, 0.9, 26 } } do
		local drop = Draw.disc(
			d[3],
			Theme.DECLINE,
			UDim2.fromScale(d[1], d[2]),
			{ ZIndex = 1, Parent = holder }
		)
		Draw.stroke(Theme.STROKE_PANEL).Parent = drop
	end
	Draw.slot("UI_Moment_GulpedSplat", holder, 6)
	return holder
end

local function build(): Frame
	local _, layer = Screen.createLayer("GulpMoments")
	local frame = Draw.new(
		"Frame",
		{ Name = "S11.Gulped", Size = UDim2.fromScale(1, 1), Visible = false, Parent = layer }
	) :: Frame

	local title = Draw.new(
		"Frame",
		{ Name = "Title", AnchorPoint = Vector2.new(0.5, 0.5), Parent = frame }
	) :: Frame
	local titleScale = Draw.new("UIScale", { Parent = title }) :: UIScale
	splat(title)
	Draw.text({
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		Rotation = -4,
		Text = Loc.t("gulped.title"),
		TextColor3 = Theme.PANEL,
		ZIndex = 7,
		Parent = title,
	}, Theme.TEXT.hero * 1.25, "display", Theme.STROKE_PANEL * 1.4)

	local swim = Draw.button(
		"Primary",
		280,
		96,
		Loc.t("gulped.again"),
		HudLayout.TOUCH_MIN,
		function()
			if onSwimAgain then
				onSwimAgain()
			end
		end
	)
	swim.root.Name = "SwimAgain"
	swim.root.Parent = frame

	local function place(layout: Screen.Layout)
		local g = HudLayout.gulped(layout.screenClass, layout.contentSize)
		title.Size = UDim2.fromOffset(g.title.width, g.title.height)
		title.Position =
			UDim2.fromOffset(g.title.x + g.title.width / 2, g.title.y + g.title.height / 2)
		swim.root:SetAttribute("RestY", g.swimAgain.y)
		swim.root.Position = UDim2.fromOffset(g.swimAgain.x, g.swimAgain.y)
	end
	place(Screen.layout())
	Screen.changed:connect(place)

	local function show(myToken: number)
		frame.Visible = true
		title.Visible = false
		swim.root.Visible = false
		swim.setEnabled(false)
		Scrim.set(true, 0.3)
		task.delay(T_TITLE, function()
			if token ~= myToken then
				return
			end
			-- Title slams in (250 ms) from 160%.
			title.Visible = true
			titleScale.Scale = 1.6
			Draw.tween(titleScale, Theme.MOTION.slam, { Scale = 1 })
		end)
		task.delay(T_PANEL, function()
			if token ~= myToken then
				return
			end
			-- The button slides up (220 ms).
			local restY = swim.root:GetAttribute("RestY") :: number
			swim.root.Visible = true
			swim.root.Position = UDim2.fromOffset(swim.root.Position.X.Offset, restY + 160)
			Draw.tween(
				swim.root,
				Theme.MOTION.panelIn,
				{ Position = UDim2.fromOffset(swim.root.Position.X.Offset, restY) }
			)
		end)
		task.delay(T_INPUT, function()
			if token == myToken then
				swim.setEnabled(true)
			end
		end)
	end
	frame:GetAttributeChangedSignal("Open"):Connect(function()
		if frame:GetAttribute("Open") then
			show(token)
		end
	end)
	return frame
end

--- Opens S11. `swimAgain` runs when the player presses Swim again.
function Gulped.open(swimAgain: () -> ())
	onSwimAgain = swimAgain
	local frame = root or build()
	root = frame
	token += 1
	frame:SetAttribute("Open", false)
	frame:SetAttribute("Open", true)
end

function Gulped.close()
	token += 1
	local frame = root
	if frame then
		frame:SetAttribute("Open", false)
		frame.Visible = false
	end
	Scrim.set(false, 0.15)
end

return Gulped
