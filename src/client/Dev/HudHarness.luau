--!strict
-- Dev/HudHarness (Studio only; task S4-C5): poses the stage 1 HUD for screenshots. The loader
-- calls `bind`, which puts a BindableFunction named `HudHarness` next to the client scripts.
-- An `execute_luau` snippet on the client invokes it:
--   HudHarness:Invoke("device", "phone" | "desktop" | "real")  lays out for a simulated device
--   HudHarness:Invoke("pose")       drag ring, a dash cooldown, mass pops and an off-screen home
--   HudHarness:Invoke("open", "S11" | "S12")   and   HudHarness:Invoke("close", "S11" | "S12")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Screen = require("../UI/Kit/Screen")
local UIController = require("../Controllers/UIController")

local HudHarness = {}

-- docs/15 section 3.1's small-ish modern phone (844 x 390 px, 47 px notch insets) and the
-- spike F11 top bar; a 1920 x 1080 desktop.
local DEVICES: { [string]: Screen.Simulated } = {
	phone = {
		reading = {
			displaySize = "Small",
			viewportWidth = 750,
			viewportHeight = 390,
			touch = true,
			keyboard = false,
			mouse = false,
			gamepad = false,
		},
		screen = { width = 844, height = 390 },
		safeArea = { x = 47, y = 0, width = 750, height = 390 },
		topbar = { x = 120, y = 0, width = 724, height = 58 },
	},
	desktop = {
		reading = {
			displaySize = "Medium",
			viewportWidth = 1920,
			viewportHeight = 1080,
			touch = false,
			keyboard = true,
			mouse = true,
			gamepad = false,
		},
		screen = { width = 1920, height = 1080 },
		safeArea = { x = 0, y = 0, width = 1920, height = 1080 },
		topbar = { x = 120, y = 0, width = 1800, height = 58 },
	},
}

local function pose(): string
	local layout = Screen.layout()
	local full = layout.fullSize
	local camera = workspace.CurrentCamera
	local home = if camera then (camera.CFrame * CFrame.new(-400, -20, 120)).Position else nil
	UIController.setPreview({
		drag = if layout.screenClass ~= "Desktop"
			then {
				active = true,
				ox = 230,
				oy = full.height - 210,
				tx = 290,
				ty = full.height - 250,
			}
			else nil,
		dashLeft = 0.35,
		home = home,
	})
	local player = Players.LocalPlayer
	local mass = player:GetAttribute("Mass")
	local base = if type(mass) == "number" then mass else 30
	player:SetAttribute("Mass", base + 4)
	task.delay(0.25, function()
		player:SetAttribute("Mass", base + 11)
	end)
	return `posed {layout.screenClass} at scale {layout.scale}`
end

function HudHarness.bind(parent: Instance)
	if not RunService:IsStudio() then
		return
	end
	local f = Instance.new("BindableFunction")
	f.Name = "HudHarness"
	f.OnInvoke = function(command: string, arg: string?): string
		if command == "device" then
			Screen.simulate(if arg then DEVICES[arg] else nil)
			local l = Screen.layout()
			return `{l.screenClass} scale {l.scale} content {l.contentSize.width} x {l.contentSize.height}`
		elseif command == "pose" then
			return pose()
		elseif command == "open" and arg == "S11" then
			UIController.open("S11")
			return "S11"
		elseif command == "open" and arg == "S12" then
			UIController.open("S12", {
				mass = 86,
				multipliers = {
					{ nameKey = "trait.crystal", value = 1.5, icon = "trait" },
					{ nameKey = "pass.deep_pockets", value = 2, icon = "pass" },
				},
				total = 774,
				best = true,
			})
			return "S12"
		elseif command == "close" and (arg == "S11" or arg == "S12") then
			UIController.close(arg)
			return "closed"
		end
		UIController.setPreview(nil)
		return "reset"
	end
	f.Parent = parent
end

return HudHarness
