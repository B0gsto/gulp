--!strict
-- Screens/Scrim: the screen dim behind post-run panels (06 §4.6: #0B1530 at 55%), on its own
-- ScreenGui with `ScreenInsets = None` so it reaches the physical edges (docs/08 section 1.3),
-- one display order under `GulpMoments` (08 §1.6 lists no order for it; 19 keeps it under 20).
local Players = game:GetService("Players")

local Draw = require("../Kit/Draw")
local Theme = require("../Kit/Theme")

local Scrim = {}

local frame: Frame? = nil

local function get(): Frame
	local existing = frame
	if existing then
		return existing
	end
	local gui = Draw.new("ScreenGui", {
		Name = "GulpMomentsScrim",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 19,
		IgnoreGuiInset = true,
	}) :: ScreenGui
	gui.ScreenInsets = Enum.ScreenInsets.None
	local f = Draw.new("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.DIM,
		BackgroundTransparency = 1,
		Active = true, -- swallows taps meant for the world
		Visible = false,
		Parent = gui,
	}) :: Frame
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	frame = f
	return f
end

--- Fades the dim in over `seconds` (or out with `on` false).
function Scrim.set(on: boolean, seconds: number)
	local f = get()
	if on then
		f.Visible = true
	end
	Draw.tween(f, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = if on then Theme.DIM_TRANSPARENCY else 1,
	}).Completed
		:Once(function()
			if not on then
				f.Visible = false
			end
		end)
end

return Scrim
