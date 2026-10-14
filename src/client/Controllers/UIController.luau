--!strict
-- UIController (docs/09 section 5.2; module B23, task S4-C5): builds the interface in code from
-- `UI/Kit`, turns every core GUI off (09 §6.10) and runs the run HUD, build stage 1 of docs/08
-- section 15. API: `open(screen, data)`, `close(screen)`, `toast(key, args)` (09 §5.2).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local VolumeMath = require(ReplicatedStorage.Shared.Logic.VolumeMath)
local WorldInfo = require(ReplicatedStorage.Shared.Net.Codec.WorldInfo)

local BankSummary = require("../UI/Screens/BankSummary")
local Client = require("../Net/Client")
local CreatureController = require("./CreatureController")
local Gulped = require("../UI/Screens/Gulped")
local Hud = require("../UI/Hud/Hud")
local InputController = require("./InputController")
local MovementController = require("./MovementController")
local Screen = require("../UI/Kit/Screen")

local TAG = "UI"

local UIController = {}
UIController.name = "UIController"

export type ScreenId = "S11" | "S12"

--- Swim again on S11 (08 §4.4). TODO(B19 RunLoopService, S5): sends the run's "continue" choice.
UIController.onSwimAgain = Signal.new() :: Types.Signal<>
--- Continue on S12 (08 §4.5). TODO(B19, S5): the bank's close and the Pearl flight to the cove HUD.
UIController.onBankContinue = Signal.new() :: Types.Signal<>
--- `HUD.setVisible(id, bool)` for chapter 04 (08 §3.3).
UIController.setVisible = Hud.setVisible

-- Studio only (`Dev/HudHarness`): fixed values for the HUD screenshots.
export type Preview = {
	drag: { active: boolean, ox: number, oy: number, tx: number, ty: number }?,
	dashLeft: number?,
	home: Vector3?,
}
local preview: Preview? = nil

local player = Players.LocalPlayer
local homePosition: Vector3? = nil
local volumes: { Types.Volume } = {}
local open: { [ScreenId]: boolean } = {}

local function refreshHome()
	homePosition = nil
	local slot = player:GetAttribute("Slot")
	for _, v in volumes do
		if v.kind == "CoveMouth" and v.attrs.CoveIndex == slot then
			homePosition = Vector3.new(VolumeMath.centre(v))
			return
		end
	end
end

local function attrNumber(name: string): number?
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else nil
end

--- Opens a screen. S11 takes no data at stage 1; S12 takes `BankSummary.Data`.
function UIController.open(screen: ScreenId, data: unknown?)
	open[screen] = true
	Hud.setShown(false) -- HUD fades out (150 ms) under both panels
	if screen == "S11" then
		Gulped.open(function()
			UIController.close("S11")
			UIController.onSwimAgain:fire()
		end)
	elseif screen == "S12" then
		BankSummary.open(data :: BankSummary.Data, function()
			UIController.close("S12")
			UIController.onBankContinue:fire()
		end)
	end
end

function UIController.close(screen: ScreenId)
	open[screen] = nil
	if screen == "S11" then
		Gulped.close()
	elseif screen == "S12" then
		BankSummary.close()
	end
	if next(open) == nil then
		Hud.setShown(true)
	end
end

--- S10 toasts are build stage 2 (08 §15). TODO(S10, stage 2): the toast stack.
function UIController.toast(key: string, _args: { [string]: string | number }?)
	Log.once("info", TAG, `toast "{key}" dropped: toasts are build stage 2`)
end

--- Studio only: fixed HUD values for screenshots, or nil for live values.
function UIController.setPreview(p: Preview?)
	if RunService:IsStudio() then
		preview = p
	end
end

function UIController.init()
	-- 09 §6.10: every core GUI off (V14); the Roblox menu button stays (08 §1.3 keep-out).
	local ok, err = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	if not ok then
		Log.warn(TAG, `SetCoreGuiEnabled failed: {err}`)
	end
end

function UIController.start()
	Screen.start()
	Hud.build(InputController.press)

	local lastMass = attrNumber("Mass") or 0
	Hud.setMass(lastMass, nil, true)
	player:GetAttributeChangedSignal("Mass"):Connect(function()
		local mass = attrNumber("Mass") or 0
		Hud.setMass(mass, lastMass)
		lastMass = mass
	end)

	-- Home: the cove mouth of the player's own slot, from WorldInfo (09 §9.1).
	Client.on("WorldInfo", function(netVersion: unknown, epoch: unknown, list: unknown)
		local info, reason = WorldInfo.decode(netVersion, epoch, list)
		if info == nil then
			Log.warn(TAG, `WorldInfo rejected ({reason}); no home marker`)
			return
		end
		volumes = info.volumes
		refreshHome()
	end)
	player:GetAttributeChangedSignal("Slot"):Connect(refreshHome)

	RunService.RenderStepped:Connect(function()
		local p = preview
		local dashLeft, blocked = MovementController.dashState()
		local active, ox, oy, tx, ty = InputController.drag()
		local mouth: Vector3? = nil
		local at, radius = CreatureController.localMouth()
		if radius > 0 then
			mouth = at
		end
		-- 08 §3.12: hidden inside the player's own cove. TODO(B30 TutorialDirector): hidden until
		-- chapter 04 shows it in the first run.
		local home = if player:GetAttribute("Phase") == "cove" then nil else homePosition
		Hud.update({
			now = os.clock(),
			inputMode = if p and p.drag then "Touch" else InputController.mode(),
			dashLeft = if p and p.dashLeft then p.dashLeft else dashLeft,
			dashBlocked = blocked,
			drag = if p and p.drag
				then p.drag
				else { active = active, ox = ox, oy = oy, tx = tx, ty = ty },
			mouth = mouth,
			home = if p and p.home then p.home else home,
			camera = workspace.CurrentCamera,
		})
	end)
end

return UIController
