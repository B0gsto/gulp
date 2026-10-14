--!strict
--!native
-- MovementController: runs `SwimModel` each frame and drives the own root part (docs/09, sections
-- 5.2 and 6.5; module B11). The client owns the root (6.4), so movement replicates by ownership:
-- nothing is sent per frame.
--
-- Every `PreRender` (code-owned writes go on PreRender: spike F15, 09 §6.7): read the root's
-- position (the engine's, after collisions with the shell), step the model with
-- `InputController.read()`, then write `Move.VectorVelocity` and `Turn.CFrame`. Under water
-- (Y ≤ 0) the mover holds the velocity. On a breach it hands the arc to the engine (09 §6.5):
-- `AssemblyLinearVelocity` = the model's velocity, `Move.Enabled = false`, `Turn` kept; the root
-- flies under `Workspace.Gravity` (80, set in the project files, the same value as SwimModel's
-- `swim.gravity`; no force of ours is added), and each frame its position and velocity are read
-- back into the model. Re-entry (×0.8) is the model's, and `Move` takes over again. A dash start
-- is reported with `Ability` op 1 (09 §5.3). A jump of the root the model did not make is a server correction (6.3, 7.3,
-- spike S4): the model is placed there at rest.
--
-- Traits (task S6-C3; 02 §8.4, §8.5): Stripes multiplies the status speed product by 1.08. The
-- own held traits come from the replicated `Traits` attribute (TraitService, 09 §5.3); a gain
-- takes effect 0.5 s after the client hears it (02 §8.2, TraitRules.noteHeld), a shed at once.
-- The server stays authoritative: TODO(B14, S8-C2) MovementValidator bounds the speed with
-- TraitService.speedMult(slot).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ability = require(ReplicatedStorage.Shared.Net.Codec.Ability)
local Defaults = require(ReplicatedStorage.Shared.Config.Defaults)
local Index = require(ReplicatedStorage.Shared.Data.Index)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local SwimModel = require(ReplicatedStorage.Shared.Sim.SwimModel)
local SwimStatus = require(ReplicatedStorage.Shared.Logic.SwimStatus)
local TierMath = require(ReplicatedStorage.Shared.Logic.TierMath)
local TraitRules = require(ReplicatedStorage.Shared.Logic.TraitRules)

local Client = require("../Net/Client")
local InputController = require("./InputController")

type Status = SwimStatus.Status

local TAG = "Movement"
local BIND_TIMEOUT = 10 -- s to wait for the root, its movers and the Species attribute
-- A root more than this far (plus two frames of travel) from where the model put it was moved
-- by the server. NOT FROM THE BIBLE (tune).
local SNAP_DISTANCE = 8

local rad, deg = math.rad, math.deg

local MovementController = {}
MovementController.name = "MovementController"

local player = Players.LocalPlayer
local state: SwimModel.SwimState? = nil
local root: BasePart? = nil
local move: LinearVelocity? = nil
local turn: AlignOrientation? = nil
local bindCount = 0
local abilitySeq = 0 -- `Ability` seq, u8 (09 §5.3)

-- setStatus: what is on, and until when (os.clock()).
local active: { [string]: boolean } = {}
local untilTime: { [string]: number } = {}
local timed = 0 -- number of entries in untilTime

-- The own traits (Stripes): when each held trait was first read, and the speed they give now.
local traitSeen: { [string]: number } = {}
local traitsRead = false
local traitSpeed = 1
local traitWake = 0 -- token of the pending re-read at the next activation

-- The mods from the statuses, then the traits' speed (02 §8.5: speed multipliers multiply).
local function applyMods(s: SwimModel.SwimState)
	SwimStatus.apply(s.mods, active)
	s.mods.speedMult *= traitSpeed
end

local function placeAtRoot(s: SwimModel.SwimState, part: BasePart)
	local cf = part.CFrame
	local pitch, yaw = cf:ToEulerAnglesYXZ()
	SwimModel.place(s, cf.X, cf.Y, cf.Z, deg(yaw), deg(pitch))
end

local function attributeNumber(name: string): number?
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else nil
end

-- A fresh model for the creature's species and tier, at the root's pose.
local function rebuild()
	local part = root
	local species = player:GetAttribute("Species")
	local tier = attributeNumber("Tier") or 1
	if part == nil or type(species) ~= "string" or Index.Species.byId[species] == nil then
		return
	end
	local s = SwimModel.new(species, math.clamp(tier, 1, #Index.Tiers.list))
	SwimModel.setBodyScale(s, TierMath.bodyScale(attributeNumber("Mass") or 0))
	applyMods(s)
	placeAtRoot(s, part)
	state = s
end

local function unbind()
	bindCount += 1
	state, root, move, turn = nil, nil, nil, nil
end

local function bind(character: Model)
	unbind()
	local token = bindCount
	task.spawn(function()
		local part = character:WaitForChild("Root", BIND_TIMEOUT)
		local m = part and part:WaitForChild("Move", BIND_TIMEOUT)
		local t = part and part:WaitForChild("Turn", BIND_TIMEOUT)
		local from = os.clock()
		while player:GetAttribute("Species") == nil and os.clock() - from < BIND_TIMEOUT do
			task.wait()
		end
		if token ~= bindCount then
			return -- a newer character, or none
		end
		if
			not (part and part:IsA("BasePart"))
			or not (m and m:IsA("LinearVelocity"))
			or not (t and t:IsA("AlignOrientation"))
		then
			Log.warn(TAG, `{character.Name} has no Root with Move and Turn; not driving it`)
			return
		end
		root, move, turn = part, m, t
		rebuild()
	end)
end

local function expireStatuses(now: number)
	local changed = false
	for status, at in untilTime do
		if now >= at then
			untilTime[status] = nil
			active[status] = nil
			timed -= 1
			changed = true
		end
	end
	if changed and state then
		applyMods(state)
	end
end

--- One frame: hot path (09 §4.7). No yields; allocates only the Vector3 and CFrame it writes.
function MovementController.update(dt: number)
	local s, part, m, t = state, root, move, turn
	if s == nil or part == nil or m == nil or t == nil then
		return
	end
	debug.profilebegin("MovementController")
	if timed > 0 then
		expireStatuses(os.clock())
	end

	local p = part.Position
	local ex, ey, ez = p.X - s.x, p.Y - s.y, p.Z - s.z
	local slack = SNAP_DISTANCE + 2 * SwimModel.speed(s) * dt
	if ex * ex + ey * ey + ez * ez > slack * slack then
		placeAtRoot(s, part) -- the server moved it
	else
		s.x, s.y, s.z = p.X, p.Y, p.Z
		if s.airborne then
			local v = part.AssemblyLinearVelocity
			s.vx, s.vy, s.vz = v.X, v.Y, v.Z
		end
	end

	SwimModel.step(s, InputController.read(), dt)
	if s.dashStarted then
		-- 09 §5.3, §7.1: the dash is already running; this opens the server's dash window.
		abilitySeq = (abilitySeq + 1) % 256
		Client.send("Ability", Ability.encode(Ability.OP_DASH, abilitySeq, Client.timeMs()))
	end

	if s.breached then
		-- 09 §6.5: hand the arc to the engine at the model's velocity.
		part.AssemblyLinearVelocity = Vector3.new(s.vx, s.vy, s.vz)
	end
	m.Enabled = not s.airborne
	if not s.airborne then
		local vx, vy, vz = SwimModel.velocity(s)
		m.VectorVelocity = Vector3.new(vx, vy, vz)
	end
	t.CFrame = CFrame.fromEulerAnglesYXZ(rad(s.pitch), rad(s.yaw), 0)
	debug.profileend()
end

--- Turns a movement status on for `seconds` (math.huge until turned off), or off with 0 or
--- less. `effect` is one of `SwimStatus.ALL` (02 §0.6 states and overlays that change movement).
function MovementController.setStatus(effect: Status, seconds: number)
	if not SwimStatus.isStatus(effect) then
		Log.warn(TAG, `setStatus: unknown status "{effect}"`)
		return
	end
	if untilTime[effect] ~= nil then
		timed -= 1
		untilTime[effect] = nil
	end
	if seconds > 0 then
		active[effect] = true
		if seconds < math.huge then
			untilTime[effect] = os.clock() + seconds
			timed += 1
		end
	else
		active[effect] = nil
	end
	if state then
		applyMods(state)
	end
end

-- Reads the own `Traits` attribute; re-reads itself when a new trait's 0.5 s are up.
local function readTraits()
	local held = TraitRules.splitIds(player:GetAttribute("Traits"))
	local now = os.clock()
	local wait = TraitRules.noteHeld(traitSeen, held, now, not traitsRead)
	traitsRead = true
	traitSpeed = TraitRules.speedMult(TraitRules.activeOf(held, traitSeen, now))
	if state then
		applyMods(state)
	end
	traitWake += 1
	if wait then
		local token = traitWake
		task.delay(wait, function()
			if token == traitWake then
				readTraits()
			end
		end)
	end
end

--- The own creature's velocity, studs/s, the current included (zero with no creature).
function MovementController.velocity(): Vector3
	local s = state
	if s == nil then
		return Vector3.zero
	end
	return Vector3.new(SwimModel.velocity(s))
end

--- For `HUD.Dash` (08 §3.7): the share of the dash cooldown still to run (1 just after a dash
--- starts, 0 when ready) and whether a status blocks the dash (stunned, tucked in Shell).
function MovementController.dashState(): (number, boolean)
	local s = state
	if s == nil then
		return 0, false
	end
	local cooldown = s.dashCooldown
	local left = if cooldown > 0 then math.clamp(1 - s.dashAge / cooldown, 0, 1) else 0
	return left, s.mods.dashBlocked
end

function MovementController.init() end

function MovementController.start()
	if workspace.Gravity ~= Defaults.swim.gravity then
		-- 09 §6.5: the project files set it; a place that lost the setting arcs wrongly.
		Log.warn(
			TAG,
			`Workspace.Gravity is {workspace.Gravity}, SwimModel uses {Defaults.swim.gravity} (09 §6.5)`
		)
	end
	player:GetAttributeChangedSignal("Tier"):Connect(function()
		local tier = attributeNumber("Tier")
		if state and tier and Index.Tiers.byTier[tier] then
			SwimModel.setTier(state, tier)
		end
	end)
	player:GetAttributeChangedSignal("Mass"):Connect(function()
		local mass = attributeNumber("Mass")
		if state and mass then
			SwimModel.setBodyScale(state, TierMath.bodyScale(mass))
		end
	end)
	player:GetAttributeChangedSignal("Species"):Connect(rebuild)
	player:GetAttributeChangedSignal("Traits"):Connect(readTraits)
	readTraits()
	player.CharacterAdded:Connect(bind)
	player.CharacterRemoving:Connect(unbind)
	if player.Character then
		bind(player.Character)
	end
	RunService.PreRender:Connect(MovementController.update)
end

return MovementController
