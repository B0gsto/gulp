--!strict
-- TutorialDirector: the client half of the first-time script (task S6-C2, module B31; docs/09,
-- sections 5.2 and 5.3; docs/04, sections 1.4, 3.2, 3.6 B1 to B5, 3.7 and 3.8). The server's
-- TutorialService owns the stage; this plays its presentation, last in the loader (09 §4.5).
--
-- In     `State` `ftue.cue` = { seq, actions } (TutorialService's header; FtueRules' header has
--        the fields). A batch plays only when its seq is above the last played; actions play in
--        order; `reset` drops everything being presented. `ftue.stage` and `ftue.completed` say
--        whether the first-run presentation applies (FtuePresent.inFtue).
-- Out    `TutorialStep` (FtuePlan.Code): 2 when the director starts under the loading screen,
--        101 on the loading screen's `LoadDone`, 102 for a tap, 103 for steering (at most once a
--        `director.steerEvery` while it lasts), 104 when the app goes to the background.
-- B1     `hatch { seconds }`: control is held (the `Transit` status) until `giveControl`. The egg
--        (`M_Prop_HatchEgg`) stands `hatch.egg.fryAhead` behind the Fry's model and `fryUp` below
--        it and plays chapter 14 §5.1's staging on the clip's frames; the Fry plays `A_Fish_Hatch`
--        from the manifest (its ID, even while the row is still a placeholder). The camera starts
--        `hatch.cameraStart` from the egg, low, and blends to the follow pose over the hatch.
--        `LoadMode` "minimal" (04 §2.4) skips the animation. TODO(S6-A2 upload): the egg mesh;
--        until then the 07 §16 stand-in, an ellipsoid whole egg and two ellipsoid halves.
-- B2-B5  the ghost thumb toward the beat's target (Kit/Guide), hidden at once on steering; the
--        30% thicker food outline (`prompts.outlineThicken`) and the 1.5 s banners in run 1 and
--        run 2; HUD elements hidden until their `hud` cue and shown one at a time,
--        `prompts.newElementGap` apart (04 §1.4; chapter 14 §4 row 40), a rejoin's first batch at
--        once; the trait slot's five empty pips (`pips`); the dash button's two pulses; a ring on
--        the target for `pulse` until the next input; B5's ambient dip and camera push-in on the
--        first trait.
-- Hold   04 §3.7 (`hold`): the music is low-pass filtered until input (`idle.holdHighGain`,
--        `holdMidGain`); the server freezes the beat clock and the prey.
-- Later  TODO(AudioController): `music` layers and SFX_Hatch. TODO(S7-C1, S7-C2, S7-C3, S7-C6):
--        the chase, the Home Current, the bank and the curtain cues are logged and not drawn.
--        The settings gear of 04 §3.8 is not built yet (08 stage 2).
-- Studio the `TutorialProbe` BindableFunction (tools/studio/ftue_play.py): "log" returns the beat
--        log as JSON; "pilot", "on" | "off" steers at the nearest food (InputController.setPilot).
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local CameraMath = require(ReplicatedStorage.Shared.Logic.CameraMath)
local Formation = require(ReplicatedStorage.Shared.Sim.Formation)
local FtueConfig = require(ReplicatedStorage.Shared.Config.FtueConfig)
local FtuePlan = require(ReplicatedStorage.Shared.Logic.FtuePlan)
local FtuePresent = require(ReplicatedStorage.Shared.Logic.FtuePresent)
local FtueRules = require(ReplicatedStorage.Shared.Logic.FtueRules)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Manifest = require(ReplicatedStorage.Shared.Data.Manifest)
local Types = require(ReplicatedStorage.Shared.Types)

local CameraController = require("./CameraController")
local Client = require("../Net/Client")
local CreatureController = require("./CreatureController")
local CreatureRig = require("../Render/CreatureRig")
local Guide = require("../UI/Kit/Guide")
local Hud = require("../UI/Hud/Hud")
local InputController = require("./InputController")
local MovementController = require("./MovementController")
local PreyRenderer = require("../Render/PreyRenderer")
local StateStore = require("./StateStore")
local UIController = require("./UIController")

type Action = FtueRules.Action
type Rig = CreatureRig.Rig
type EggPose = FtuePresent.EggPose

local TAG = "Tutorial"
local RENDER_NAME = "GulpTutorial"
local HATCH_CLIP = "A_Fish_Hatch"
local FOLDER = "GulpTutorial" -- the client's own props (the egg)

local cfg = FtueConfig
local egg = cfg.hatch.egg
local S = FtueRules.Stage
local C = FtuePlan.Code

local TutorialDirector = {}
TutorialDirector.name = "TutorialDirector"

local player = Players.LocalPlayer

-- The script as the client knows it.
local cues = FtuePresent.newCues()
local input = FtuePresent.newInput()
local reveals = FtuePresent.newReveals()
local stage = S.S0_LOADING -- the local step pointer (the server holds the saved one)
local completed: boolean? = nil
local present = true -- FtuePresent.inFtue for the current stage

-- Prompts.
local ghostOn, ghostLong, ghostShown = false, false, false
local ghostTarget = Guide.world(Vector3.zero) -- position written every frame
local ringTarget = Guide.world(Vector3.zero)
local ringKind: string? = nil -- "target" | "homeMarker" while a pulse waits for input
local dashRingUntil: number? = nil
local holdEffects: { EqualizerSoundEffect } = {}

-- B5.
local traitAt: number? = nil
local ambient: { Color3 }? = nil

-- Kinds for the beat's target.
local foodKinds: { [number]: boolean } = {}
local glowKinds: { [number]: boolean } = {}

-- The play check's log (J: since the director started; T: since control).
type Mark = { what: string, j: number, t: number? }
local marks: { Mark } = {}
local startedAt = 0
local controlAt: number? = nil
local pilotOn = false
local pilotSteering = false

local function now(): number
	return os.clock()
end

local function mark(what: string)
	local at = now()
	local t = if controlAt then at - controlAt else nil
	table.insert(marks, { what = what, j = at - startedAt, t = t })
	local tt = if t then string.format(" T %.2f", t) else ""
	Log.info(TAG, string.format("%s at J %.2f%s", what, at - startedAt, tt))
end

local function send(code: number)
	Client.send("TutorialStep", code)
end

local function ownRig(): Rig?
	local slot = player:GetAttribute("Slot")
	if type(slot) ~= "number" then
		return nil
	end
	return CreatureController.rigOf(slot)
end

local function loadingScript(): Instance?
	local boot = ReplicatedFirst:FindFirstChild("Boot")
	return if boot then boot:FindFirstChild("Loading") else nil
end

local function flat(v: Vector3, fallback: Vector3): Vector3
	local h = Vector3.new(v.X, 0, v.Z)
	return if h.Magnitude > 1e-3 then h.Unit else fallback
end

---------------------------------------------------------------------------------------------------
-- HUD first appearances (04 §3.8)

local function setHud(ids: { string }, on: boolean)
	for _, id in ids do
		UIController.setVisible(id :: any, on) -- safe: FtuePresent's IDs are Hud.Id values
	end
end

local function showElement(id: string)
	setHud(FtuePresent.HUD_OF[id] or {}, true)
	if id == "dashButton" then
		-- 04 §3.6 B4: it pops in and pulses twice (at the dash pulse's rate).
		dashRingUntil = now() + 2 / cfg.prompts.dashPulseRate
		Guide.ring(Guide.hud("HUD.Dash"))
	elseif id == "homeMarker" then
		Guide.home(true)
	end
	mark("shown " .. id)
end

local function hideAll()
	setHud(FtuePresent.HIDDEN, false)
end

local function showAll()
	setHud(FtuePresent.HIDDEN, true)
end

---------------------------------------------------------------------------------------------------
-- The hold (04 §3.7)

local function musicTargets(): { Instance }
	local out: { Instance } = {}
	local loading = SoundService:FindFirstChild("LoadingMusic")
	if loading and loading:IsA("Sound") then
		table.insert(out, loading)
	end
	local group = SoundService:FindFirstChild("Music")
	if group and group:IsA("SoundGroup") then
		table.insert(out, group)
	end
	return out
end

local function setHold(on: boolean)
	for _, e in holdEffects do
		e:Destroy()
	end
	table.clear(holdEffects)
	if on then
		for _, target in musicTargets() do
			local e = Instance.new("EqualizerSoundEffect")
			e.Name = "GulpFtueHold"
			e.HighGain = cfg.idle.holdHighGain
			e.MidGain = cfg.idle.holdMidGain
			e.LowGain = 0
			e.Parent = target
			table.insert(holdEffects, e)
		end
	end
	mark(if on then "hold on" else "hold off")
end

---------------------------------------------------------------------------------------------------
-- B1: the hatch

type Hatch = {
	started: number,
	seconds: number,
	speed: number, -- clip frames per second of hatch time ÷ 30
	base: CFrame?, -- the egg's base: LookVector toward the Fry, UpVector up
	whole: BasePart?,
	top: BasePart?,
	bottom: BasePart?,
	rig: Rig?,
	track: AnimationTrack?,
	hidden: { BasePart }?, -- the Fry's parts hidden inside the egg (no clip)
	camFrom: CFrame?,
	camLook: Vector3?,
	camDone: boolean,
	controlled: boolean,
}

local hatch: Hatch? = nil
local hatchClipId: number? = nil
local folder: Folder? = nil

local function propFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = FOLDER
	made.Parent = workspace
	folder = made
	return made
end

local function ellipsoid(name: string, size: Vector3): Part
	-- TODO(S6-A2 upload): clone `M_Prop_HatchEgg`, `_Top` and `_Bottom` from ReplicatedStorage.Assets.
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromHex(egg.placeholderColour)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	p.Parent = propFolder()
	return p
end

local function clearEgg()
	local f = folder
	if f then
		f:ClearAllChildren()
	end
end

-- The base frame rolled by `deg` (+ to its right) on its round base: it rolls, so the base moves.
local function rolled(base: CFrame, deg: number): CFrame
	local a = math.rad(deg)
	local r = egg.rollRadius
	return base * CFrame.new(r * a, r, 0) * CFrame.Angles(0, 0, -a) * CFrame.new(0, -r, 0)
end

local function placeEgg(h: Hatch, pose: EggPose)
	local base = h.base
	local whole, top, bottom = h.whole, h.top, h.bottom
	if not (base and whole and top and bottom) then
		return
	end
	local split, capHalf = egg.split, (egg.height - egg.split) / 2
	whole.Transparency = if pose.whole then 0 else 1
	top.Transparency = if pose.whole then 1 else 0
	bottom.Transparency = top.Transparency
	if pose.whole then
		whole.Size =
			Vector3.new(egg.width * pose.wide, egg.height * pose.tall, egg.width * pose.wide)
		whole.CFrame = rolled(base, pose.roll) * CFrame.new(0, egg.height * pose.tall / 2, 0)
		return
	end
	local shell = rolled(base, pose.roll + pose.bottomRock)
	bottom.CFrame = shell * CFrame.new(0, split / 2, 0)
	if pose.free then
		top.CFrame = base
			* CFrame.new(pose.topR, pose.topU, -pose.topF)
			* CFrame.Angles(0, math.rad(pose.topYaw), 0)
			* CFrame.Angles(-math.rad(pose.topPitch), 0, 0)
			* CFrame.Angles(0, 0, -math.rad(pose.topRock))
	else
		-- About its back edge (+Z is away from the Fry), turning backwards.
		local hinge = rolled(base, pose.roll) * CFrame.new(0, split + pose.lift, egg.width / 2)
		top.CFrame = hinge
			* CFrame.Angles(-math.rad(pose.open), 0, 0)
			* CFrame.new(0, capHalf, -egg.width / 2)
	end
end

local function hideFry(rig: Rig): { BasePart }
	local parts: { BasePart } = {}
	for _, d in rig.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
			table.insert(parts, d)
		end
	end
	return parts
end

local function showFry(h: Hatch)
	local parts = h.hidden
	if parts then
		for _, p in parts do
			p.LocalTransparencyModifier = 0
		end
		h.hidden = nil
	end
end

-- Where the follow camera will be once primed (CameraController's prime and update at rest).
local function followPose(rig: Rig): (Vector3, Vector3)
	local look = flat(rig.cframe.LookVector, Vector3.new(0, 0, -1))
	local d = cfg.hatch.cameraFollow
	local scale = CreatureRig.scale(rig)
	local pos = rig.pos - look * d + Vector3.yAxis * (CameraMath.HEIGHT_RATIO * d)
	return pos, rig.pos + look * CameraMath.lookAhead(scale)
end

local function finishCamera(h: Hatch)
	if not h.camDone then
		h.camDone = true
		CameraController.setMode("follow")
	end
end

local function endHatch(h: Hatch)
	if h.track and h.track.IsPlaying and h.rig then
		CreatureRig.stopOverride(h.rig)
	end
	showFry(h)
	finishCamera(h)
end

local function startHatch(seconds: number)
	local old = hatch
	if old then
		endHatch(old)
	end
	clearEgg()
	if seconds <= 0 then
		hatch = nil
		return
	end
	MovementController.setStatus("Transit", math.huge)
	local loading = loadingScript()
	local minimal = loading ~= nil and loading:GetAttribute("LoadMode") == "minimal"
	local h: Hatch = {
		started = now(),
		seconds = seconds,
		speed = FtuePresent.clipSeconds(cfg) / seconds,
		camDone = true,
		controlled = false,
	}
	hatch = h
	local rig = ownRig()
	if minimal or rig == nil then
		mark(if minimal then "hatch (minimal: no animation)" else "hatch (no rig yet)")
		return
	end
	h.rig = rig
	local look = flat(rig.cframe.LookVector, Vector3.new(0, 0, -1))
	local basePos = rig.pos - look * egg.fryAhead - Vector3.yAxis * egg.fryUp
	local base = CFrame.lookAlong(basePos, look)
	h.base = base
	h.whole = ellipsoid("M_Prop_HatchEgg", Vector3.new(egg.width, egg.height, egg.width))
	h.bottom = ellipsoid("M_Prop_HatchEgg_Bottom", Vector3.new(egg.width, egg.split, egg.width))
	h.top =
		ellipsoid("M_Prop_HatchEgg_Top", Vector3.new(egg.width, egg.height - egg.split, egg.width))
	placeEgg(h, FtuePresent.eggPose(cfg, 0))
	local id = hatchClipId
	if id then
		h.track = CreatureRig.playOverride(rig, id, h.speed)
	end
	if h.track == nil then
		h.hidden = hideFry(rig) -- the stand-in: the Fry pops out when the top flips
	end
	-- The camera: `cameraStart` from the egg's centre, behind it and to the Fry's right, low.
	local centre = (base * CFrame.new(0, egg.height / 2, 0)).Position
	local back = CFrame.fromAxisAngle(Vector3.yAxis, -math.rad(cfg.hatch.cameraYaw))
		:VectorToWorldSpace(-look)
	h.camFrom = CFrame.lookAt(
		centre + back * cfg.hatch.cameraStart + Vector3.yAxis * cfg.hatch.cameraHeight,
		centre
	)
	h.camLook = centre
	h.camDone = false
	CameraController.setMode("hold")
	mark(if h.track then "hatch (clip)" else "hatch (stand-in)")
end

local function giveControl()
	MovementController.setStatus("Transit", 0)
	controlAt = now()
	local h = hatch
	if h then
		h.controlled = true
		if h.track and h.track.IsPlaying and h.rig then
			CreatureRig.stopOverride(h.rig)
		end
		showFry(h)
	end
	mark("control (T = 0)")
end

local function stepHatch(h: Hatch, t: number)
	local f = (t - h.started) * h.speed * egg.fps
	if h.base and f <= egg.restFrame + 1 then
		placeEgg(h, FtuePresent.eggPose(cfg, f))
	end
	if h.hidden and f >= egg.flipFrame then
		showFry(h)
	end
	if not h.camDone then
		local cam = workspace.CurrentCamera
		local rig, from, look = h.rig, h.camFrom, h.camLook
		local u = (t - h.started) / h.seconds
		if cam and rig and from and look then
			local e = FtuePresent.ease(u)
			local toPos, toLook = followPose(rig)
			cam.CFrame = CFrame.lookAt(from.Position:Lerp(toPos, e), look:Lerp(toLook, e))
		end
		if u >= 1 then
			finishCamera(h)
		end
	end
	if h.camDone and h.controlled and f > egg.restFrame + 1 then
		hatch = nil -- the egg stays on the bed until a reset
	end
end

---------------------------------------------------------------------------------------------------
-- Cues

local function resetAll()
	local h = hatch
	if h then
		endHatch(h)
		hatch = nil
	end
	clearEgg()
	MovementController.setStatus("Transit", 0)
	Guide.reset()
	ghostOn, ghostShown, ringKind, dashRingUntil = false, false, nil, nil
	Hud.setTraitHint(nil)
	reveals = FtuePresent.newReveals()
	setHold(false)
	hideAll()
	controlAt = nil
	table.clear(marks) -- the probe's log restarts with the script
	mark("reset")
end

local LATER: { [string]: string } = {
	openFog = "04 §2.3 fog: TideController's presets own Lighting fog",
	openCurtain = "S7-C6",
	predatorShadow = "S7-C1",
	startChase = "S7-C1",
	autoDash = "S7-C1",
	startCurrent = "S7-C2",
	reformCurrent = "S7-C2",
	pull = "S7-C6",
	bankSequence = "S7-C3",
	coveItem = "S7-C3",
	exitTrail = "S7-C3",
}

local function play(a: Action, first: boolean)
	local kind = a.kind
	if kind == "reset" then
		resetAll()
	elseif kind == "hatch" then
		startHatch(a.seconds or cfg.hatch.seconds)
	elseif kind == "giveControl" then
		giveControl()
	elseif kind == "hold" then
		setHold(a.on == true)
	elseif kind == "prompt" then
		local show = a.show == true
		if a.id == "ghostThumb" then
			ghostOn, ghostLong, ghostShown = show, a.mode == "long", false
			if not show then
				Guide.ghost(nil)
			end
		elseif a.id == "pips" then
			Hud.setTraitHint(if show then cfg.arms.firstTrait else nil)
		elseif a.id == "dashPulse" then
			Guide.dashPulse(show)
		else
			Log.once("info", TAG, `prompt {a.id}: TODO(S7-C6) not drawn yet`)
		end
		mark(`prompt {a.id} {if show then "on" else "off"}`)
	elseif kind == "hud" and a.id then
		FtuePresent.reveal(reveals, a.id, if first then now() else nil)
		if first then
			showElement(a.id)
		end
	elseif kind == "pulse" or kind == "feedNearest" then
		local id = if kind == "feedNearest" then "target" else a.id
		if id == "target" then
			ringKind = "target"
		elseif id == "homeMarker" then
			ringKind = "homeMarker"
			Guide.ring(Guide.hud("HUD.Home"))
		else
			Log.once("info", TAG, `pulse {id}: TODO(S7) not drawn yet`)
		end
		mark(`pulse {id}`)
	elseif kind == "music" then
		Log.once("info", TAG, `music {a.id}: TODO(AudioController)`)
		mark(`music {a.id}`)
	else
		Log.once("info", TAG, `cue {kind}: TODO({LATER[kind] or "?"}) not presented yet`)
		mark(`cue {kind}`)
	end
end

local function onCue(value: unknown)
	local actions, first = FtuePresent.accept(cues, value)
	if actions == nil then
		return
	end
	for _, a in actions do
		play(a, first)
	end
end

local function onFtue(value: unknown)
	local v = if type(value) == "table" then value :: { [string]: any } else nil
	if v == nil then
		return
	end
	local newStage = if type(v.stage) == "number" then v.stage else stage
	if newStage ~= stage then
		stage = newStage
		mark(`stage {stage}`)
	end
	completed = v.completed == true
	present = FtuePresent.inFtue(stage, completed)
	PreyRenderer.setOutlineScale(if present then 1 + cfg.prompts.outlineThicken else 1)
	UIController.setBannerHold(if present then cfg.prompts.bannerSeconds else nil)
	if completed then
		showAll() -- a banked account: its HUD is all there (TutorialService replays nothing)
	end
end

---------------------------------------------------------------------------------------------------
-- Input (04 §3.7: any input; 04 §3.6 B2: a drag of 0.2 s or more is steering)

local MOVE_KEYS: { Enum.KeyCode } = {
	Enum.KeyCode.W,
	Enum.KeyCode.A,
	Enum.KeyCode.S,
	Enum.KeyCode.D,
	Enum.KeyCode.Up,
	Enum.KeyCode.Down,
	Enum.KeyCode.Left,
	Enum.KeyCode.Right,
}

local function keysHeld(): boolean
	for _, key in MOVE_KEYS do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

local function onAnyInput()
	if ringKind then
		ringKind = nil
		Guide.ring(nil)
	end
end

local function onSteer()
	onAnyInput()
	if ghostOn then
		-- Hidden at once; the server's hide cue follows.
		ghostOn, ghostShown = false, false
		Guide.ghost(nil)
	end
end

local function isPress(io: InputObject): boolean
	local t = io.UserInputType
	return t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1
end

local function onInputBegan(io: InputObject, processed: boolean)
	if isPress(io) then
		if processed then
			send(C.TAP) -- a HUD button: input, never a drag
			onAnyInput()
		else
			FtuePresent.press(input, now())
		end
	elseif
		io.UserInputType == Enum.UserInputType.Keyboard and not table.find(MOVE_KEYS, io.KeyCode)
	then
		send(C.TAP)
		onAnyInput()
	end
end

local function onInputEnded(io: InputObject, _processed: boolean)
	if isPress(io) then
		local code = FtuePresent.release(cfg, input, now())
		if code then
			send(code)
			onAnyInput()
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Per frame

local function beatTarget(): Vector3?
	local kinds = if stage == S.S4_TRAIT then glowKinds else foodKinds
	local _, at = PreyRenderer.nearest(kinds)
	if at == nil and stage == S.S4_TRAIT then
		_, at = PreyRenderer.nearest(foodKinds)
	end
	return at
end

local function frame()
	local t = now()
	local h = hatch
	if h then
		stepHatch(h, t)
	end

	local code = FtuePresent.sense(cfg, input, t, keysHeld() or pilotSteering)
	if code then
		send(code)
		onSteer()
	end

	-- First appearances, one at a time.
	local id = FtuePresent.due(cfg, reveals, t)
	if id then
		showElement(id)
	end
	if dashRingUntil and t >= dashRingUntil then
		dashRingUntil = nil
		if ringKind == nil then
			Guide.ring(nil)
		end
	end

	-- The ghost thumb and the pulse ring follow the beat's target.
	local target = if ghostOn or ringKind == "target" then beatTarget() else nil
	if ghostOn then
		if target then
			ghostTarget.position = target
			if not ghostShown then
				ghostShown = true
				Guide.ghost(ghostTarget, { long = ghostLong })
			end
		elseif stage >= S.S5_CALL_HOME and not ghostShown then
			ghostShown = true
			Guide.ghost(Guide.hud("HUD.Home"), { long = ghostLong })
		end
	end
	if ringKind == "target" and target then
		ringTarget.position = target
		Guide.ring(ringTarget)
	end

	-- B5: the ambient dip on the first trait.
	local at = traitAt
	if at then
		local saved: { Color3 } = ambient or { Lighting.Ambient, Lighting.OutdoorAmbient }
		ambient = saved
		local dim = FtuePresent.dimAt(cfg, t - at)
		Lighting.Ambient = saved[1]:Lerp(Color3.new(), dim)
		Lighting.OutdoorAmbient = saved[2]:Lerp(Color3.new(), dim)
		if t - at > math.max(cfg.trait.dimSeconds, cfg.trait.pushInSeconds) then
			Lighting.Ambient, Lighting.OutdoorAmbient = saved[1], saved[2]
			traitAt, ambient = nil, nil
			CameraController.setPush(nil)
		end
	end
end

local function onTraitGained(traitId: string)
	if not present or traitId ~= cfg.arms.firstTrait or stage > S.S5_CALL_HOME then
		return
	end
	local at = now()
	traitAt = at
	CameraController.setPush(function(): number
		return FtuePresent.pushAt(cfg, os.clock() - at)
	end)
	mark("trait " .. traitId)
end

---------------------------------------------------------------------------------------------------
-- Studio: the play check's probe and autopilot

local function pilot(swim: Types.SwimInput)
	local rig = ownRig()
	local target = if rig and controlAt then beatTarget() else nil
	pilotSteering = false
	if rig == nil or target == nil then
		return
	end
	local d = target - rig.pos
	local horizontal = Vector3.new(d.X, 0, d.Z).Magnitude
	swim.throttle = 1
	swim.strafe = 0
	swim.brake = false
	swim.yawTarget = math.deg(math.atan2(-d.X, -d.Z))
	swim.yawRate = 0
	swim.pitchTarget = math.deg(math.atan2(d.Y, horizontal))
	pilotSteering = true
end

local function bindProbe()
	local probe = Instance.new("BindableFunction")
	probe.Name = "TutorialProbe"
	probe.OnInvoke = function(command: string, arg: string?): string
		if command == "pilot" then
			pilotOn = arg ~= "off"
			InputController.setPilot(if pilotOn then pilot else nil)
			if not pilotOn then
				pilotSteering = false
			end
			return `pilot {pilotOn}`
		elseif command == "log" then
			return HttpService:JSONEncode({ stage = stage, marks = marks })
		end
		return "unknown command"
	end
	probe.Parent = script.Parent.Parent
end

---------------------------------------------------------------------------------------------------
-- Public API (09 §5.2)

--- The local step pointer: the last `ftue.stage` the server sent (S0_LOADING until then).
function TutorialDirector.step(): number
	return stage
end

function TutorialDirector.init()
	startedAt = now()
	for _, id in { FtuePlan.KRILL, FtuePlan.PLANKTON } do
		local k = Formation.kindOf(id)
		if k then
			foodKinds[k] = true
		end
	end
	local glow = FtuePlan.traitPreyFor(cfg.arms.firstTrait)
	local gk = if glow then Formation.kindOf(glow) else nil
	if gk then
		glowKinds[gk] = true
	end
	-- 07 §2.1 `A_Fish_Hatch`: its ID even while the row is a placeholder (task S6-A2 merged it so
	-- the tutorial plays the real clip before the owner signs it off).
	local ok, manifest = pcall(Manifest.load)
	if ok then
		local entry = Manifest.get(manifest, HATCH_CLIP)
		hatchClipId = if entry then entry.id else nil
	end
end

function TutorialDirector.start()
	Guide.mount({ inputMode = InputController.mode, modeChanged = InputController.onModeChanged })
	hideAll() -- until the profile says otherwise (a banked account) or a cue shows them
	StateStore.observe("ftue", onFtue)
	StateStore.observe("ftue.cue", onCue)
	Client.on("CreatureEvent", function(kind: unknown, slot: unknown, a: unknown)
		if
			kind == "traitGained"
			and slot == player:GetAttribute("Slot")
			and type(a) == "string"
		then
			onTraitGained(a)
		end
	end)
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	UserInputService.WindowFocusReleased:Connect(function()
		send(C.BACKGROUND)
		mark("backgrounded")
	end)
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, frame)
	local shown = Hud.moments()
	if shown then
		shown:connect(function(kind: string)
			mark("banner " .. kind)
		end)
	end

	-- Loading (10 §3.1 step 02, 04 §3.1): the screen is up now; its exit ends S0.
	local loading = loadingScript()
	send(C.LOADING_SHOWN)
	local function loaded()
		send(C.LOADED)
		mark("load done")
	end
	if loading == nil or loading:GetAttribute("LoadDone") == true then
		loaded()
	else
		local connection: RBXScriptConnection? = nil
		connection = loading:GetAttributeChangedSignal("LoadDone"):Connect(function()
			if loading:GetAttribute("LoadDone") == true then
				if connection then
					connection:Disconnect()
				end
				loaded()
			end
		end)
	end
	if RunService:IsStudio() then
		bindProbe()
	end
end

return TutorialDirector
