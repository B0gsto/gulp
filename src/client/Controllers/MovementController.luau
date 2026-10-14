--!strict
--!native
-- MovementController: runs `SwimModel` each frame and drives the own root part (docs/09, sections
-- 5.2 and 6.5; module B11). The client owns the root (6.4), so movement replicates by ownership:
-- nothing is sent per frame.
--
-- Every `PreRender` (code-owned writes go on PreRender: spike F15, 09 §6.7): read the root's
-- position (the engine's, after collisions with the shell), step the model with
-- `InputController.read()`, then write `Move.VectorVelocity` and `Turn.CFrame`. Under water
-- (Y ≤ 0) the mover holds the velocity; after a breach `Move.Enabled = false` and the root flies
-- a ballistic arc under `Workspace.Gravity` (09 §6.5), whose velocity the model reads back until
-- it re-enters. A jump of the root the model did not make is a server correction (6.3, 7.3,
-- spike S4): the model is placed there at rest.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Index = require(ReplicatedStorage.Shared.Data.Index)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local SwimModel = require(ReplicatedStorage.Shared.Sim.SwimModel)
local SwimStatus = require(ReplicatedStorage.Shared.Logic.SwimStatus)
local TierMath = require(ReplicatedStorage.Shared.Logic.TierMath)

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

-- setStatus: what is on, and until when (os.clock()).
local active: { [string]: boolean } = {}
local untilTime: { [string]: number } = {}
local timed = 0 -- number of entries in untilTime

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
	SwimStatus.apply(s.mods, active)
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
		SwimStatus.apply(state.mods, active)
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
	-- TODO(B14, S8-C2): on `s.dashStarted`, send `Ability` (09 §5.2, §7.1). 09 §5.3 gives its
	-- layout ("6 bytes: op, seq, time") but no op codes or codec exist yet, and no handler.

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
		SwimStatus.apply(state.mods, active)
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

function MovementController.init() end

function MovementController.start()
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
	player.CharacterAdded:Connect(bind)
	player.CharacterRemoving:Connect(unbind)
	if player.Character then
		bind(player.Character)
	end
	RunService.PreRender:Connect(MovementController.update)
end

return MovementController
