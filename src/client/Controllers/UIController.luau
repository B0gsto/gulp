--!strict
-- UIController (docs/09 section 5.2; module B23, tasks S4-C5 and S5-C4): builds the interface in
-- code from `UI/Kit`, turns every core GUI off (09 §6.10) and runs the run HUD (build stage 1 of
-- docs/08 section 15), the bank summary S12 and the cove HUD S14 (stage 2 parts). API:
-- `open(screen, data)`, `close(screen)`, `toast(key, args)` (09 §5.2).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local BankMath = require(ReplicatedStorage.Shared.Logic.BankMath)
local CoveIncome = require(ReplicatedStorage.Shared.Logic.CoveIncome)
local CoveRules = require(ReplicatedStorage.Shared.Logic.CoveRules)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local TraitRules = require(ReplicatedStorage.Shared.Logic.TraitRules)
local Types = require(ReplicatedStorage.Shared.Types)
local VolumeMath = require(ReplicatedStorage.Shared.Logic.VolumeMath)
local WorldInfo = require(ReplicatedStorage.Shared.Net.Codec.WorldInfo)

local BankSummary = require("../UI/Screens/BankSummary")
local Client = require("../Net/Client")
local CoveHud = require("../UI/Hud/CoveHud")
local CreatureController = require("./CreatureController")
local Gulped = require("../UI/Screens/Gulped")
local Hud = require("../UI/Hud/Hud")
local InputController = require("./InputController")
local MovementController = require("./MovementController")
local Screen = require("../UI/Kit/Screen")
local StateStore = require("./StateStore")
local TierMath = require(ReplicatedStorage.Shared.Logic.TierMath)

local TAG = "UI"

local UIController = {}
UIController.name = "UIController"

export type ScreenId = "S11" | "S12"

--- Swim again on S11 (08 §4.4). TODO(B19 RunLoopService, S5): sends the run's "continue" choice.
UIController.onSwimAgain = Signal.new() :: Types.Signal<>
--- Continue on S12 (08 §4.5). TODO(B19, S5): the bank's close and the Pearl flight to the cove HUD.
UIController.onBankContinue = Signal.new() :: Types.Signal<>
--- The cove HUD's menu buttons (08 §5.1): the plus on the Pearls chip ("pearls", the shop's
--- Pearls tab), the slots chip ("slots", S16) and the dock ("species", S22). TODO(S22, S16, S27):
--- the menus open from here once they are built.
UIController.onCoveMenu = Signal.new() :: Types.Signal<string>
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
-- S14 state (08 §5.1): the capacity from the last own `CoveView` (server truth, Bigger Cove
-- included), else from the save; the server's pile clock is os.time (09 §13.3).
local viewCapacity: number? = nil
local covePreview: CoveHud.State? = nil -- Studio only (`Dev/HudHarness`)

local function inCove(): boolean
	return covePreview ~= nil or player:GetAttribute("Phase") == "cove"
end

-- TODO(B23, S10-C2): read owned passes through ShopService's State once it writes `passes`.
local function ownsPass(id: string): boolean
	local passes = StateStore.get("passes")
	return type(passes) == "table" and passes[id] == true
end

local function coveState(): CoveHud.State
	if covePreview then
		return covePreview
	end
	local cove = StateStore.get("cove")
	local pearls = StateStore.get("pearls")
	local s: CoveHud.State = {
		pearls = if type(pearls) == "number" then pearls else 0,
		rate = 0,
		used = 0,
		capacity = 0,
		pile = 0,
		pileFull = false,
	}
	if type(cove) ~= "table" or type(cove.specimens) ~= "table" then
		return s
	end
	local c = cove :: CoveRules.Cove
	local capHours = CoveIncome.capHours(ownsPass("pass_tide_watcher"))
	local now = math.floor(workspace:GetServerTimeNow())
	s.rate = CoveIncome.rate(c.specimens)
	s.used = #c.specimens
	s.capacity = viewCapacity or CoveRules.capacity(c.slots, ownsPass("pass_bigger_cove"))
	s.pile = math.floor(CoveRules.pileAt(c, now, capHours))
	-- The pile stops growing once the cap window since the last claim is over (05 §3.4).
	local since = if c.lastClaim then c.lastClaim.at else c.accruedAt
	s.pileFull = s.rate > 0 and now >= since + capHours * 3600
	return s
end

local function refreshCove(instant: boolean?)
	local here = inCove()
	Hud.setCove(here)
	CoveHud.setShown(here and next(open) == nil)
	CoveHud.set(coveState(), instant)
end

-- The Pearl Clam of the player's own cove (08 §5.1: the one pile). TODO(S5-A4 or the cove props
-- task): the world tags `M_Cove_PearlClam` "PearlClam" with a `CoveIndex` attribute; until then
-- there is no clam and no bubble (Claim all still claims).
local function refreshPileAnchor()
	local slot = player:GetAttribute("Slot")
	for _, part in CollectionService:GetTagged("PearlClam") do
		if part:IsA("BasePart") and part:GetAttribute("CoveIndex") == slot then
			CoveHud.setPileAnchor(part)
			return
		end
	end
	CoveHud.setPileAnchor(nil)
end

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

-- The specimen a bank just kept (08 §4.5 step 5), from the mirrored cove: the newest `at` among
-- the specimens, or the waiting one when the cove was full. The "banked" event follows the
-- bank's State patches, but this waits up to 0.5 s for them all the same.
local function bankedSpecimen(kind: unknown, bankedAt: number): BankSummary.Specimen?
	if kind ~= "added" and kind ~= "full" then
		return nil
	end
	local deadline = os.clock() + 0.5
	while true do
		local cove = StateStore.get("cove")
		local found: Types.SpecimenRecord? = nil
		if type(cove) == "table" then
			if kind == "full" then
				-- TODO(S13, stage 3): the cove-full choice replaces the card (08 §4.5).
				found = cove.pendingSpecimen
			elseif type(cove.specimens) == "table" then
				for _, sp in cove.specimens do
					if sp.at >= bankedAt - 10 and (found == nil or sp.at >= found.at) then
						found = sp
					end
				end
			end
		end
		if found then
			return {
				sp = found.sp,
				tier = found.tier,
				traits = found.traits,
				perHour = CoveIncome.specimenRate(found.tier, found.traits),
			}
		end
		if os.clock() > deadline then
			return nil
		end
		task.wait(0.05)
	end
end

-- `CreatureEvent` "banked" (RunLoopService, task S5-C3): slot, mass, pearls, crystal,
-- deepPockets, best, specimen ("added", "full" or "none"). The owner's bank opens S12 with what
-- the server paid; the bank sequence around it is S7-C3's.
local function onCreatureEvent(
	kind: unknown,
	slot: unknown,
	mass: unknown,
	pearls: unknown,
	crystal: unknown,
	deep: unknown,
	best: unknown,
	specimen: unknown
)
	if kind ~= "banked" or slot ~= player:GetAttribute("Slot") then
		return
	end
	if type(mass) ~= "number" or type(pearls) ~= "number" then
		return
	end
	local rows: { BankSummary.Row } = {}
	if crystal == true then
		table.insert(
			rows,
			{ nameKey = "trait.crystal", value = TraitRules.CRYSTAL_BANK, icon = "trait" }
		)
	end
	if deep == true then
		table.insert(
			rows,
			{ nameKey = "pass.deep_pockets", value = BankMath.DEEP_POCKETS, icon = "pass" }
		)
	end
	local kept = bankedSpecimen(specimen, workspace:GetServerTimeNow())
	UIController.showBank({
		mass = mass,
		multipliers = rows,
		total = pearls,
		best = best == true,
		specimen = kept,
		tooSmall = kept == nil and TierMath.tier(mass) < CoveRules.MIN_TIER,
	})
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
			-- 08 §4.5 step 7: Pearls fly to the cove HUD's Pearl chip as the panel goes.
			local from = BankSummary.totalPosition()
			UIController.close("S12")
			if from then
				CoveHud.flyPearls(from, 8)
			end
			UIController.onBankContinue:fire()
		end)
	end
	refreshCove(true)
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
	refreshCove()
end

--- Shows S12 for a bank (08 §4.5); the "banked" `CreatureEvent` (S5-C3) is its one caller.
function UIController.showBank(data: BankSummary.Data)
	UIController.open("S12", data)
end

--- S10 toasts are build stage 2 (08 §15). TODO(S10, stage 2): the toast stack.
function UIController.toast(key: string, _args: { [string]: string | number }?)
	Log.once("info", TAG, `toast "{key}" dropped: toasts are build stage 2`)
end

--- Studio only: shows S14 with fixed values for screenshots, or nil for live values.
function UIController.setCovePreview(p: CoveHud.State?)
	if RunService:IsStudio() then
		covePreview = p
		refreshCove(true)
	end
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

	-- S14, the cove HUD (08 §5.1).
	local hudRoot = Hud.root()
	if hudRoot then
		CoveHud.build(hudRoot, {
			claim = function()
				local pile = coveState().pile
				if pile < 1 then
					return
				end
				-- 08 §5.4: the Pearls fly to the chip; the balance counts up when the State lands.
				-- TODO(B32): `SFX_UI_Claim` and the light haptic.
				if Client.send("CoveAction", CoveRules.Op.claim, 0) then
					local from = CoveHud.claimFrom()
					if from then
						CoveHud.flyPearls(from, math.clamp(math.floor(pile / 10), 4, 10))
					end
					CoveHud.claimed()
				end
			end,
			plus = function()
				UIController.onCoveMenu:fire("pearls")
			end,
			slots = function()
				UIController.onCoveMenu:fire("slots")
			end,
			dock = function(id: CoveHud.DockId)
				UIController.onCoveMenu:fire(id)
			end,
		})
	end
	Client.on("CoveView", function(view: unknown)
		local v = view :: any
		if
			type(v) == "table"
			and v.slot == player:GetAttribute("Slot")
			and type(v.slots) == "number"
		then
			viewCapacity = v.slots
			refreshCove()
		end
	end)
	for _, path in { "pearls", "cove", "passes" } do
		StateStore.observe(path, function()
			refreshCove()
		end)
	end
	player:GetAttributeChangedSignal("Phase"):Connect(function()
		refreshCove(true)
	end)
	player:GetAttributeChangedSignal("Slot"):Connect(function()
		viewCapacity = nil
		refreshPileAnchor()
	end)
	CollectionService:GetInstanceAddedSignal("PearlClam"):Connect(refreshPileAnchor)
	refreshPileAnchor()
	-- The pile grows every second (02 §13.2); its number and Claim all follow.
	task.spawn(function()
		while true do
			task.wait(1)
			if CoveHud.isShown() then
				CoveHud.set(coveState())
			end
		end
	end)

	-- Home: the cove mouth of the player's own slot, from WorldInfo (09 §9.1).
	Client.on("CreatureEvent", onCreatureEvent)
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
