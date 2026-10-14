--!strict
-- CreatureController (B13, first part; task S3-C6): a rig for every creature that streams in,
-- smoothed, scaled with mass and outlined. docs/09 sections 5.2, 6.1, 6.2, 6.7, 6.8 and 8.8;
-- docs/06 section 13.2; canon 5.2.
--
-- Creatures are found two ways (09 §6.2): the local player's `CharacterAdded`, and
-- `workspace.Creatures.ChildAdded` for everyone else. Each `Creature_<userId>` model gets a
-- client-made rig (Render/CreatureRig) that is never welded to the replicated root. Every frame,
-- in a render-step binding just before the camera's:
--
--   rig.pos     = RigMath spring toward root + clamp(velocity, 1.2 × dash speed) × 2τ
--                 (τ 0.03 s own, 0.08 s others)
--   rig.heading = spring toward the velocity (or the root's look vector when slow), τ 0.10 s
--   rig CFrame  = CFrame.lookAlong(rig.pos, rig.heading) × the bank from the turn rate
--   scale       = TierMath.bodyScale(Mass), eased over 0.15 s with Model:ScaleTo
--
-- The camera follows the own rig's `rig.pos` (setFollowTarget). Outlines: OutlineRules decides
-- the colour per creature from the tiers; the nearest 20 edible and 10 dangerous draw (09 §8.8);
-- the own creature never gets one (06 §13.2).
--
-- Creature facts are the player's replicated attributes (Species, Tier, Mass, Phase, Protected,
-- Slot; CreatureService). A creature model with no player (a dev bot) may carry the same
-- attributes itself.
--
-- Later parts, by sprint (docs/13): pooled nameplates, smoothing pass criteria for other players
-- and the juvenile-to-adult swap under FX_Metamorph are S9-C1 (the rig already holds both forms);
-- the Leviathan crest and trait visuals come with their art; FX_TierUp_T<n>, the burst, hit-stop
-- and sounds with Render/Fx (S10-C1) and the banner with screen S07 (S6-C5); the Smooth-tier
-- outline caps with QualityController.
--
-- Tier-up (task S4-C4; 02 §1.8, §5.1; 09 §6.8): RunLoopService's `CreatureEvent` "tier" with a
-- rise plays `A_Fish_TierUp` when the manifest has its asset ID, else the code pop (RigMath.popMult,
-- 0.6 s to 112% on the mesh only). A gulped creature (`Phase = dead`) hides its rig until it is
-- back, and its smoothing restarts there so it does not glide across the map.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CameraController = require(script.Parent.CameraController)
local Client = require(script.Parent.Parent.Net.Client)
local CreatureRig = require(script.Parent.Parent.Render.CreatureRig)
local Index = require(ReplicatedStorage.Shared.Data.Index)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Manifest = require(ReplicatedStorage.Shared.Data.Manifest)
local OutlineRules = require(ReplicatedStorage.Shared.Logic.OutlineRules)
local Outlines = require(script.Parent.Parent.Render.Outlines)
local RigMath = require(ReplicatedStorage.Shared.Logic.RigMath)
local SwimModel = require(ReplicatedStorage.Shared.Sim.SwimModel)
local TierMath = require(ReplicatedStorage.Shared.Logic.TierMath)

local CreatureController = {}
CreatureController.name = "CreatureController"

local TAG = "CreatureController"
local RENDER_NAME = "GulpCreatureRigs"
local FOLDER = "Creatures" -- CreatureService's folder (09 §6.2)
local RIG_FOLDER = "CreatureRigs"
local DEFAULT_SPECIES = "minnow"
local SELECT_EVERY = 0.25 -- seconds between outline re-selections (tune)

type Rig = CreatureRig.Rig

type Entry = {
	model: Model,
	root: BasePart,
	player: Player?,
	own: boolean,
	rig: Rig,
	species: string,
	tier: number,
	mass: number,
	shielded: boolean,
	radiusMult: number,
	topSpeed: number,
	leadClamp: number,
	kind: OutlineRules.Kind,
	shown: boolean,
	scaling: boolean,
	dead: boolean, -- Phase = dead: the rig is hidden
	popAt: number?, -- os.clock() when the code tier-up pop started
	connections: { RBXScriptConnection },
}

local player = Players.LocalPlayer
local rigFolder: Folder? = nil
local entries: { Entry } = {}
local byModel: { [Model]: Entry } = {}
local ownEntry: Entry? = nil

-- Scratch for the per-frame move and the outline pick (09 §4.7: no allocation per entity).
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}
local pickKinds: { OutlineRules.Kind } = {}
local pickDistances: { number } = {}
local pickOrder: { number } = {}
local pickShown: { boolean } = {}
local sinceSelect = math.huge

--------------------------------------------------------------------------------------------------
-- Attributes

local function source(e: Entry): Instance
	return e.player or e.model
end

local function attr(from: Instance, name: string): any
	return from:GetAttribute(name)
end

local function numberAttr(from: Instance, name: string, default: number): number
	local v = attr(from, name)
	return if typeof(v) == "number" then v else default
end

-- Reads every fact from the replicated attributes; returns true when the species changed.
local function readFacts(e: Entry): boolean
	local from = source(e)
	local speciesId = attr(from, "Species")
	local species = if typeof(speciesId) == "string" and Index.Species.byId[speciesId]
		then speciesId
		else DEFAULT_SPECIES
	local def = Index.Species.byId[species]
	local tier = math.clamp(
		math.floor(numberAttr(from, "Tier", def and def.startTier or 1)),
		1,
		#Index.Tiers.list
	)
	e.tier = tier
	e.mass = numberAttr(from, "Mass", 0)
	-- 09 §8.8 and canon 5.2: protected, in a cove, or gulped means nobody can eat it now.
	local phase = attr(from, "Phase")
	e.shielded = attr(from, "Protected") == true or phase ~= "run"
	e.dead = phase == "dead"
	if def then
		e.radiusMult = def.radiusMult
		e.topSpeed = SwimModel.topSpeed(tier, def, 1)
		e.leadClamp = RigMath.LEAD_CLAMP * SwimModel.dashSpeed(tier, def, 1)
	end
	local changed = species ~= e.species
	e.species = species
	return changed
end

--------------------------------------------------------------------------------------------------
-- Rigs

local function buildRig(e: Entry)
	local rig = CreatureRig.new(e.species, e.radiusMult)
	local scale = TierMath.bodyScale(e.mass)
	rig.scaleEase = RigMath.newScale(scale)
	CreatureRig.applyScale(rig, scale)
	rig.model:PivotTo(e.root.CFrame)
	rig.model.Parent = rigFolder
	e.rig = rig
	e.kind, e.shown = "none", false
end

local function recomputeKind(e: Entry)
	local own = ownEntry
	if e.own or own == nil then
		e.kind = "none"
	else
		e.kind = OutlineRules.creature(own.tier, own.shielded, e.tier, e.shielded)
	end
	sinceSelect = math.huge -- re-pick on the next frame
end

local function recomputeAll()
	for _, e in entries do
		recomputeKind(e)
	end
end

-- Hides the rig of a gulped creature, and restarts its smoothing when it comes back.
local function showAlive(e: Entry)
	local parent = if e.dead then nil else rigFolder
	if e.rig.model.Parent ~= parent then
		e.rig.model.Parent = parent
		if parent then
			e.rig.follow = RigMath.newFollow()
		end
	end
end

local function onFacts(e: Entry)
	if readFacts(e) then
		CreatureRig.destroy(e.rig)
		buildRig(e)
	end
	showAlive(e)
	RigMath.retargetScale(e.rig.scaleEase, TierMath.bodyScale(e.mass))
	if e.own then
		recomputeAll()
	else
		recomputeKind(e)
	end
end

local function remove(model: Model)
	local e = byModel[model]
	if e == nil then
		return
	end
	byModel[model] = nil
	local i = table.find(entries, e)
	if i then
		table.remove(entries, i)
	end
	for _, c in e.connections do
		c:Disconnect()
	end
	CreatureRig.destroy(e.rig)
	if ownEntry == e then
		ownEntry = nil
		recomputeAll()
	end
end

local function watch(e: Entry, from: Instance)
	for _, name in { "Species", "Tier", "Mass", "Phase", "Protected" } do
		table.insert(
			e.connections,
			from:GetAttributeChangedSignal(name):Connect(function()
				onFacts(e)
			end)
		)
	end
end

local function playerOf(model: Model): Player?
	if model == player.Character then
		return player
	end
	local userId = tonumber(string.match(model.Name, "^Creature_(%d+)$"))
	return if userId then Players:GetPlayerByUserId(userId) else nil
end

local function add(model: Instance)
	if not model:IsA("Model") or byModel[model] then
		return
	end
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	if not (root and root:IsA("BasePart")) then
		return -- Atomic streaming delivers the model whole (09 §6.6); anything else is not ours
	end
	local owner = playerOf(model)
	local e: Entry = {
		model = model,
		root = root,
		player = owner,
		own = owner == player,
		rig = (nil :: any) :: Rig,
		species = "",
		tier = 1,
		mass = 0,
		shielded = true,
		radiusMult = 1,
		topSpeed = 26,
		leadClamp = 100,
		kind = "none",
		shown = false,
		scaling = false,
		dead = false,
		popAt = nil,
		connections = {},
	}
	readFacts(e)
	buildRig(e)
	showAlive(e)
	byModel[model] = e
	table.insert(entries, e)
	watch(e, source(e))
	table.insert(
		e.connections,
		model.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				remove(model)
			end
		end)
	)
	if e.own then
		ownEntry = e
		recomputeAll()
	else
		recomputeKind(e)
	end
end

-- A model that arrived before its Player (rare): bind it once the Player is known.
local function rebindOrphans(newPlayer: Player)
	for _, e in table.clone(entries) do
		if e.player == nil and playerOf(e.model) == newPlayer then
			local model = e.model
			remove(model)
			add(model)
		end
	end
end

--------------------------------------------------------------------------------------------------
-- Frame

local function selectOutlines()
	local own = ownEntry
	local count = #entries
	local ox, oy, oz = 0, 0, 0
	if own then
		local p = own.rig.pos
		ox, oy, oz = p.X, p.Y, p.Z
	end
	for i, e in entries do
		local p = e.rig.pos
		local dx, dy, dz = p.X - ox, p.Y - oy, p.Z - oz
		pickKinds[i] = e.kind
		pickDistances[i] = dx * dx + dy * dy + dz * dz
	end
	for i = #pickKinds, count + 1, -1 do
		pickKinds[i] = nil
		pickDistances[i] = nil
	end
	local capEdible, capDangerous = Outlines.caps(false)
	OutlineRules.select(
		pickKinds,
		pickDistances,
		count,
		capEdible,
		capDangerous,
		pickOrder,
		pickShown
	)
	for i, e in entries do
		local show = pickShown[i] == true
		local kind: OutlineRules.Kind = if show then e.kind else "none"
		e.shown = show
		CreatureRig.setOutline(e.rig, kind, Outlines.colour(kind))
	end
end

local function update(dt: number)
	if dt <= 0 then
		return
	end
	debug.profilebegin(TAG)
	local now = os.clock()
	table.clear(moveParts)
	table.clear(moveCFrames)
	local n = 0
	for _, e in entries do
		local root, rig = e.root, e.rig
		if root.Parent ~= nil and not e.dead then
			local f = rig.follow
			local target = root.CFrame
			local p = target.Position
			local v = root.AssemblyLinearVelocity
			local tau = if e.own then RigMath.TAU_OWN else RigMath.TAU_OTHER
			RigMath.stepPosition(f, p.X, p.Y, p.Z, v.X, v.Y, v.Z, e.leadClamp, dt, tau)
			local look = target.LookVector
			local lx, ly, lz = RigMath.lookDirection(v.X, v.Y, v.Z, look.X, look.Y, look.Z)
			RigMath.stepHeading(f, lx, ly, lz, dt)
			local pos = Vector3.new(f.x, f.y, f.z)
			local heading = Vector3.new(f.hx, f.hy, f.hz)
			local cf = CFrame.lookAlong(pos, heading) * CFrame.Angles(0, 0, f.bank)
			rig.pos, rig.heading, rig.cframe = pos, heading, cf

			local scale, moving = RigMath.stepScale(rig.scaleEase, dt)
			local popAt = e.popAt
			if popAt then
				local t = now - popAt
				scale *= RigMath.popMult(t) -- the mesh only; the root never pops (02 §1.8)
				moving = true
				if t >= RigMath.POP_SECONDS then
					e.popAt = nil
				end
			end
			if moving then
				CreatureRig.applyScale(rig, scale)
				e.scaling = true
			elseif e.scaling then
				e.scaling = false
				CreatureRig.refitOutline(rig)
			end

			local speed = v.Magnitude
			local before = rig.loop
			CreatureRig.animate(rig, dt, speed, e.topSpeed)
			if rig.loop == "SwimFast" and before ~= "SwimFast" then
				CreatureRig.playAction(rig, "Dash")
			end
			if e.shown and e.kind == "dangerous" then
				CreatureRig.setOutline(rig, "dangerous", Outlines.colourAt("dangerous", now))
			end

			n += 1
			moveParts[n] = rig.root
			moveCFrames[n] = cf
		end
	end
	if n > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	sinceSelect += dt
	if sinceSelect >= SELECT_EVERY then
		sinceSelect = 0
		selectOutlines()
	end
	debug.profileend()
end

-- The camera's follow target (CameraController.FollowTarget): the own rig, never the root (F2).
local function ownFollow(_dt: number, out: CameraController.FollowSample): boolean
	local e = ownEntry
	if e == nil or e.root.Parent == nil or not e.rig.follow.primed then
		return false
	end
	out.position = e.rig.pos
	out.velocity = e.root.AssemblyLinearVelocity
	out.look = e.rig.heading
	return true
end

--------------------------------------------------------------------------------------------------
-- Public API (09 §5.2)

--- The rig of the creature in `slot`, or nil when it has not streamed in.
function CreatureController.rigOf(slot: number): Rig?
	for _, e in entries do
		if e.player and e.player:GetAttribute("Slot") == slot then
			return e.rig
		end
	end
	return nil
end

--- The own creature's mouth centre and radius from the smoothed rig (02 §4.1; 09 §6.7, F2).
--- RigMath.mouth is BiteMath's mouth, the one the server checks against (09 §8.9). `mouthMult`
--- and `lengthMult` are not in the species data yet, so they are 1; the dash is read from the
--- speed. TODO(B20, S4-C6): the first-run factor (04 §4), with the server's.
function CreatureController.localMouth(): (Vector3, number)
	local e = ownEntry
	if e == nil then
		return Vector3.zero, 0
	end
	local dashing = e.root.AssemblyLinearVelocity.Magnitude > e.topSpeed * RigMath.FAST_RATIO
	local radius, ahead = RigMath.mouth(e.rig.scaleEase.value, 1, dashing)
	return e.rig.pos + e.rig.heading * ahead, radius
end

-- `CreatureEvent` (09 §5.3; RunLoopService): "tier", slot, tier, previous tier. Other kinds are
-- for later tasks (the gulp camera, 02 §3.6, S6; status, revive).
local function onCreatureEvent(kind: unknown, slot: unknown, tier: unknown, before: unknown)
	if kind ~= "tier" or type(slot) ~= "number" or type(tier) ~= "number" then
		return
	end
	if type(before) ~= "number" or tier <= before then
		return -- 02 §5.1 tier-down: no pop (SFX_TierDown comes with AudioController)
	end
	for _, e in entries do
		if e.player and e.player:GetAttribute("Slot") == slot then
			if CreatureRig.hasClip(e.rig, "TierUp") then
				CreatureRig.playAction(e.rig, "TierUp")
			else
				e.popAt = os.clock()
			end
			-- TODO(S10-C1): FX_TierUp_T<tier> (FX_Metamorph at 4) and FX_TierUp_Burst, Render/Fx.
		end
	end
end

function CreatureController.init()
	table.clear(entries)
	table.clear(byModel)
	ownEntry = nil
end

local function loadClipIds()
	local ok, manifest = pcall(Manifest.load)
	if not ok then
		Log.warn(TAG, `manifest did not load ({manifest}); using the code sway`)
		return
	end
	local ids: { [string]: number } = {}
	for _, clip in RigMath.CLIPS do
		local entry = Manifest.get(manifest, `A_Fish_{clip}`)
		if entry and entry.id and not entry.placeholder then
			ids[clip] = entry.id
		end
	end
	CreatureRig.setClipIds(ids)
end

local function watchCreatureFolder(folder: Instance)
	folder.ChildAdded:Connect(add)
	folder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			remove(child)
		end
	end)
	for _, child in folder:GetChildren() do
		add(child)
	end
end

function CreatureController.start()
	loadClipIds()
	local folder = Instance.new("Folder")
	folder.Name = RIG_FOLDER
	folder.Parent = workspace
	rigFolder = folder

	local creatures = workspace:FindFirstChild(FOLDER)
	if creatures then
		watchCreatureFolder(creatures)
	else
		local pending: RBXScriptConnection
		pending = workspace.ChildAdded:Connect(function(child)
			if child.Name == FOLDER then
				pending:Disconnect()
				watchCreatureFolder(child)
			end
		end)
	end
	player.CharacterAdded:Connect(add)
	if player.Character then
		add(player.Character)
	end
	Players.PlayerAdded:Connect(rebindOrphans)

	Client.on("CreatureEvent", onCreatureEvent)
	CameraController.setFollowTarget(ownFollow)
	-- Just before the camera, so it reads this frame's rig.pos. The render step runs after the
	-- Animator has reset the bones, so the sway written here holds (spike surprise 3).
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value - 1, update)
end

return CreatureController
