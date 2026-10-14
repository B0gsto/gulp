--!strict
-- CameraController (B12; docs/09, sections 5.2, 4.7 and 6.10; docs/02, section 3; docs/15,
-- section 3.2): the scripted follow camera. `CameraType = Scriptable`; `CFrame` and `Focus` are set
-- every frame. The numbers and the pure steps live in `Shared.Logic.CameraMath`.
--
-- The camera follows a `FollowTarget`: the smoothed position of the own creature (`rig.pos`,
-- docs/09 section 6.7 and spike findings F1/F2), never the raw `root.Position`. Until
-- CreatureController (B13) exists, the default target is a critically damped spring of its own on
-- the root (τ = 0.03 s, the own creature's rig value) chasing `root + velocity × 2τ` (F1).
-- CreatureController replaces it through `setFollowTarget`.
--
-- Not here yet: the gulped and banking cameras (02 §3.6, §3.7; need RunLoopService and the cove),
-- mouse-driven rotation for Keys (02 §3.2; needs InputController), the dash kick trigger (§3.4;
-- needs MovementController), the own-creature and frond fades (§3.5; need the rig), the eel-hole
-- spline (§3.5) and the camera-shake setting from StateStore (`setShakeEnabled` until then).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CameraMath = require(ReplicatedStorage.Shared.Logic.CameraMath)
local Index = require(ReplicatedStorage.Shared.Data.Index)
local TierMath = require(ReplicatedStorage.Shared.Logic.TierMath)

export type Mode = "follow" | "hold"

--- Filled by a follow target each frame: the smoothed creature centre, its velocity and the
--- direction it faces (unit). Preallocated; targets write into it, never allocate.
export type FollowSample = { position: Vector3, velocity: Vector3, look: Vector3 }

--- Fills `out` for this frame and returns true, or returns false when there is no creature.
export type FollowTarget = (dt: number, out: FollowSample) -> boolean

local CameraController = {}
CameraController.name = "CameraController"

local RENDER_NAME = "GulpCamera"
local HEADING_MIN_SPEED = 2 -- docs/09 §6.7: look direction = velocity above 2 studs/s
local SNAP_DISTANCE = 64 -- a jump this far (respawn, teleport) resets the springs (tune)

local player = Players.LocalPlayer
local camera: Camera? = nil
local cameraConnection: RBXScriptConnection? = nil

local mode: Mode = "follow"
local followTarget: FollowTarget
local sample: FollowSample =
	{ position = Vector3.zero, velocity = Vector3.zero, look = Vector3.zAxis * -1 }

-- Creature facts from replicated attributes (09 §5.3), cached on change.
local bodyScale = 1
local radiusMult = 1
local topSpeed = 26
local tier = 1

-- Smoothed camera state.
local primed = false
local focus = Vector3.zero
local yaw, pitch = 0, 0
local baseDistance = CameraMath.distance(1)
local occludedRatio = 1
local heightRatio = CameraMath.HEIGHT_RATIO
local tightFov = 0
local surfaceCap = CameraMath.SURFACE_Y
local tight = CameraMath.newTight()
local baseFov = CameraMath.BASE_VFOV

-- Tier transitions (02 §3.3), as `os.clock()` start times; nil when none is running.
local tierUpAt: number? = nil
local tierDownAt: number? = nil
local tierDownFrom = 0

-- Shake (02 §3.4).
local shakeEnabled = true
local shakeAmount, shakeSeconds, shakeAt = 0, 0, -math.huge
local rng = Random.new()

local castParams = RaycastParams.new()

--------------------------------------------------------------------------------------------------
-- Default follow target: a spring on the root (09 §6.7, F1)

local springRoot: BasePart? = nil
local springPos = Vector3.zero
local springVel = Vector3.zero

local function ownRoot(): BasePart?
	local character = player.Character
	return if character then character.PrimaryPart else nil
end

local function rootSpringTarget(dt: number, out: FollowSample): boolean
	local root = ownRoot()
	if root == nil then
		springRoot = nil
		return false
	end
	local p = root.Position
	local v = root.AssemblyLinearVelocity
	if root ~= springRoot or (p - springPos).Magnitude > SNAP_DISTANCE then
		springRoot, springPos, springVel = root, p, v
	else
		local tau = CameraMath.TAU_OWN_RIG
		local lag = 2 * tau
		local x, vx = CameraMath.spring(
			springPos.X,
			springVel.X,
			CameraMath.leadTarget(p.X, v.X, lag),
			dt,
			tau
		)
		local y, vy = CameraMath.spring(
			springPos.Y,
			springVel.Y,
			CameraMath.leadTarget(p.Y, v.Y, lag),
			dt,
			tau
		)
		local z, vz = CameraMath.spring(
			springPos.Z,
			springVel.Z,
			CameraMath.leadTarget(p.Z, v.Z, lag),
			dt,
			tau
		)
		springPos, springVel = Vector3.new(x, y, z), Vector3.new(vx, vy, vz)
	end
	out.position = springPos
	out.velocity = v
	out.look = if v.Magnitude > HEADING_MIN_SPEED then v.Unit else root.CFrame.LookVector
	return true
end

followTarget = rootSpringTarget

--------------------------------------------------------------------------------------------------
-- Attributes

local function readCreature()
	local mass = player:GetAttribute("Mass")
	bodyScale = TierMath.bodyScale(if typeof(mass) == "number" then mass else 0)
	local speciesId = player:GetAttribute("Species")
	local species = if typeof(speciesId) == "string" then Index.Species.byId[speciesId] else nil
	radiusMult = if species then species.radiusMult else 1
	local t = player:GetAttribute("Tier")
	local tierDef = Index.Tiers.byTier[if typeof(t) == "number" then t else 1]
	topSpeed = (if tierDef then tierDef.swimSpeed else 26)
		* (if species then species.speedMult else 1)
end

local function onTier()
	local t = player:GetAttribute("Tier")
	local newTier = if typeof(t) == "number" then t else 1
	if primed and newTier > tier then
		tierUpAt, tierDownAt = os.clock(), nil
		CameraController.shake(CameraMath.SHAKE_TIER_UP, CameraMath.SHAKE_TIER_UP_SECONDS)
	elseif primed and newTier < tier then
		tierDownAt, tierUpAt = os.clock(), nil
		tierDownFrom = baseDistance
	end
	tier = newTier
	readCreature()
end

--------------------------------------------------------------------------------------------------
-- Camera instance

local function readAspect(cam: Camera)
	local size = cam.ViewportSize
	-- The field of view follows a new aspect in the same frame (docs/15 §5.2).
	baseFov = CameraMath.baseVFov(if size.Y > 0 then size.X / size.Y else 16 / 9)
end

local function bindCamera()
	local cam = workspace.CurrentCamera
	if cam == camera then
		return
	end
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	camera = cam
	if cam then
		cam.CameraType = Enum.CameraType.Scriptable
		readAspect(cam)
		cameraConnection = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			readAspect(cam)
		end)
	end
end

local function refreshCastFilter()
	-- Occlusion casts hit only the World shell (09 §6.10). A Raycast `CollisionGroup` cannot do
	-- this: `World` does not collide with itself (09 §6.5). Parts tagged `CameraIgnore` never block.
	local shell = workspace:FindFirstChild("Collision")
	if shell then
		castParams.FilterType = Enum.RaycastFilterType.Include
		castParams.FilterDescendantsInstances = { shell }
	else
		local exclude: { Instance } = CollectionService:GetTagged("CameraIgnore")
		local creatures = workspace:FindFirstChild("Creatures")
		if creatures then
			table.insert(exclude, creatures)
		end
		castParams.FilterType = Enum.RaycastFilterType.Exclude
		castParams.FilterDescendantsInstances = exclude
	end
	castParams.IgnoreWater = true
end

--------------------------------------------------------------------------------------------------
-- The frame

local function prime(s: FollowSample)
	focus = s.position
	yaw = math.deg(math.atan2(-s.look.X, -s.look.Z)) % 360
	pitch = CameraMath.PITCH_FOLLOW * math.deg(math.asin(math.clamp(s.look.Y, -1, 1)))
	baseDistance = CameraMath.distance(bodyScale)
	occludedRatio, heightRatio, tightFov = 1, CameraMath.HEIGHT_RATIO, 0
	surfaceCap = CameraMath.SURFACE_Y
	tight = CameraMath.newTight()
	tierUpAt, tierDownAt = nil, nil
	primed = true
end

local function update(dt: number)
	debug.profilebegin("CameraController.update")
	local cam = camera
	if cam == nil then
		debug.profileend()
		return
	end
	if cam.CameraType ~= Enum.CameraType.Scriptable then
		cam.CameraType = Enum.CameraType.Scriptable
	end
	if mode == "hold" or not followTarget(dt, sample) then
		primed = false
		cam.FieldOfView = baseFov
		debug.profileend()
		return
	end
	if not primed or (sample.position - focus).Magnitude > SNAP_DISTANCE then
		prime(sample)
	end
	local now = os.clock()
	local pos, vel, look = sample.position, sample.velocity, sample.look

	-- Distance by body scale (02 §3.1), tier-down ease and tier-up pull-back (§3.3).
	local desiredBase = CameraMath.distance(bodyScale)
	if tierDownAt then
		local t = now - tierDownAt
		baseDistance = CameraMath.tierDown(tierDownFrom, desiredBase, t)
		if t >= CameraMath.TIER_DOWN_SECONDS then
			tierDownAt = nil
		end
	else
		baseDistance = CameraMath.smooth(baseDistance, desiredBase, dt, CameraMath.TAU_DISTANCE)
	end
	local distance = baseDistance
	if tierUpAt then
		local t = now - tierUpAt
		distance *= CameraMath.pullBack(t)
		if t >= CameraMath.PULL_END then
			tierUpAt = nil
		end
	end

	-- Orientation (02 §3.2): yaw follows the creature, pitch is 0.6 × the creature's.
	local yawTarget = math.deg(math.atan2(-look.X, -look.Z))
	local pitchTarget = CameraMath.PITCH_FOLLOW * math.deg(math.asin(math.clamp(look.Y, -1, 1)))
	yaw = CameraMath.smoothAngle(yaw, yawTarget, dt, CameraMath.TAU_YAW)
	pitch = CameraMath.smooth(pitch, pitchTarget, dt, CameraMath.TAU_PITCH)
	local rotation = CFrame.fromOrientation(math.rad(pitch), math.rad(yaw), 0)
	local facing = rotation.LookVector

	-- Position (02 §3.2): exponential, chasing `centre + velocity × τ` so the camera lags only
	-- while the creature accelerates ("pulls ahead slightly"), not at steady speed.
	local tau = CameraMath.TAU_POSITION
	focus = Vector3.new(
		CameraMath.smooth(focus.X, pos.X + vel.X * tau, dt, tau),
		CameraMath.smooth(focus.Y, pos.Y + vel.Y * tau, dt, tau),
		CameraMath.smooth(focus.Z, pos.Z + vel.Z * tau, dt, tau)
	)

	-- Framing (02 §3.1, §3.5): tight-space mode lowers the camera and widens the view.
	heightRatio = CameraMath.smooth(
		heightRatio,
		if tight.tight then CameraMath.TIGHT_HEIGHT_RATIO else CameraMath.HEIGHT_RATIO,
		dt,
		CameraMath.TAU_DISTANCE
	)
	tightFov = CameraMath.smooth(
		tightFov,
		if tight.tight then CameraMath.TIGHT_FOV else 0,
		dt,
		CameraMath.TAU_DISTANCE
	)
	local lookAt = focus + facing * CameraMath.lookAhead(bodyScale)
	local desiredPos = focus - facing * distance + Vector3.yAxis * (heightRatio * distance)

	-- Occlusion (02 §3.5, 09 §6.10): one sphere cast from lookAt to the desired position.
	local ray = desiredPos - lookAt
	local rayLength = ray.Magnitude
	local minimum = CameraMath.minDistance(bodyScale, radiusMult)
	local clear = rayLength
	if rayLength > 1e-3 then
		local hit = workspace:Spherecast(lookAt, CameraMath.OCCLUSION_RADIUS, ray, castParams)
		clear = CameraMath.clearDistance(if hit then hit.Distance else nil, rayLength, minimum)
	end
	local clearRatio = if rayLength > 1e-3 then clear / rayLength else 1
	occludedRatio = CameraMath.stepOcclusion(occludedRatio, clearRatio, dt)
	CameraMath.stepTight(tight, clearRatio, 1, dt)
	local camPos = lookAt + ray * occludedRatio

	-- Surface (02 §3.5): below Y = 0 unless Airborne; then follow its height with τ = 0.30 s.
	-- TODO(B11): read the Airborne state from MovementController; the centre above Y = 0 for now.
	local airborne = pos.Y > CameraMath.SURFACE_Y
	surfaceCap = CameraMath.smooth(
		surfaceCap,
		if airborne then math.max(camPos.Y, CameraMath.SURFACE_Y) else CameraMath.SURFACE_Y,
		dt,
		CameraMath.TAU_SURFACE
	)
	if camPos.Y > surfaceCap then
		camPos = Vector3.new(camPos.X, surfaceCap, camPos.Z)
	end

	-- Shake (02 §3.4).
	local amp = if shakeEnabled
		then CameraMath.shakeAmplitude(shakeAmount, shakeSeconds, now - shakeAt)
		else 0
	if amp > 0 then
		local jitter = Vector3.new(
			rng:NextNumber(-1, 1),
			rng:NextNumber(-1, 1),
			rng:NextNumber(-1, 1)
		) * amp
		camPos += jitter
		lookAt += jitter
	end

	-- Field of view (02 §3.1): the aspect clamp, then the speed and tight-space offsets.
	local forward = vel:Dot(look)
	cam.FieldOfView = baseFov + CameraMath.speedFov(forward, topSpeed) + tightFov
	cam.CFrame = CFrame.lookAt(camPos, lookAt)
	cam.Focus = CFrame.new(lookAt)
	debug.profileend()
end

--------------------------------------------------------------------------------------------------
-- Public API (09 §5.2)

--- "follow" tracks the own creature; "hold" leaves the camera where it is.
--- TODO(B19, B21): "gulped" and "bank" (02 §3.6, §3.7).
function CameraController.setMode(newMode: Mode)
	mode = newMode
	primed = false
end

--- Shakes the camera by `amount` studs, decaying over `seconds` (02 §3.4: a bite is 0.15 studs
--- for 0.10 s, a tier-up 0.5 studs for 0.25 s). `seconds` defaults to the bite's.
function CameraController.shake(amount: number, seconds: number?)
	shakeAmount, shakeSeconds, shakeAt =
		amount, seconds or CameraMath.SHAKE_BITE_SECONDS, os.clock()
end

--- The "camera shake" setting (02 §3.4). TODO(StateStore): read it from the saved settings.
function CameraController.setShakeEnabled(enabled: boolean)
	shakeEnabled = enabled
end

--- Replaces the follow target; CreatureController passes its own rig's `rig.pos` here. nil goes
--- back to the default root spring.
function CameraController.setFollowTarget(target: FollowTarget?)
	followTarget = target or rootSpringTarget
	primed = false
end

function CameraController.init()
	mode, primed = "follow", false
end

function CameraController.start()
	bindCamera()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	refreshCastFilter()
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Collision" or child.Name == "Creatures" then
			refreshCastFilter()
		end
	end)
	onTier() -- not primed yet: reads the tier without a transition
	player:GetAttributeChangedSignal("Mass"):Connect(readCreature)
	player:GetAttributeChangedSignal("Species"):Connect(readCreature)
	player:GetAttributeChangedSignal("Tier"):Connect(onTier)
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value, update)
end

return CameraController
