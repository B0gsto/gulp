--!strict
-- CreatureService: builds and owns each creature model (docs/09, sections 5.1 and 6.1 to 6.8).
-- The replicated character is one invisible ball and two mover constraints; everything visible
-- is built by each client. The model is built once per session and reused (section 6.3).
-- Species, mass, and the tier and body scale derived from mass (Logic/TierMath) live in one
-- `CreatureState` per slot. PlayerLifecycle calls `spawn` after ClientReady and `remove` on leave.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Index = require(ReplicatedStorage.Shared.Data.Index)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local TierMath = require(ReplicatedStorage.Shared.Logic.TierMath)
local Types = require(ReplicatedStorage.Shared.Types)
local VolumeMath = require(ReplicatedStorage.Shared.Logic.VolumeMath)

local CollisionGroups = require("../World/CollisionGroups")
local WorldIndex = require("./WorldIndex")

type Slot = Types.Slot
type Volume = Types.Volume

-- The server's view of one creature (section 5.1: "CreatureState per slot"). Traits, progress,
-- statuses and protection are added by the tasks that own them (TraitService, B19; hazards,
-- B24; protections, B19 and B25).
export type CreatureState = {
	slot: Slot,
	player: Player,
	species: string,
	mass: number,
	tier: number,
	bodyScale: number, -- TierMath.bodyScale(mass), used at once for reach and radius (6.8)
	model: Model,
	root: Part,
	writtenDiameter: number, -- the last Root.Size written (6.8: 3% rule)
}

local TAG = "Creature"
local FOLDER = "Creatures"
local DIAMETER = 1.8 -- studs at body scale 1: twice 02 §0.2's collision radius 0.9 (section 6.1)
local SIZE_STEP = 0.03 -- (tune) Root.Size is rewritten past a 3% change, and at every tier change
local MASS_INTERVAL = 0.25 -- the Mass attribute updates at most 4 times a second (5.3)
local MOVE_MAX_FORCE = 1e6 -- (tune)
local TURN_RESPONSIVENESS = 40 -- (tune)
local TURN_MAX_TORQUE = 1e6 -- (tune)
local DEFAULT_SPECIES = "minnow" -- the species every account owns (unlockPearls 0)

local CreatureService = {}
CreatureService.name = "CreatureService"

--- Fires (slot, new tier) on a rise and on a fall (section 6.8).
CreatureService.onTierChanged = Signal.new() :: Types.Signal<Slot, number>

local states: { [Slot]: CreatureState } = {}
local massWrittenAt: { [Slot]: number } = {}
local massPending: { [Slot]: boolean } = {}
local folder: Folder

local function diameterOf(bodyScale: number, species: string): number
	return DIAMETER * bodyScale * Index.Species.byId[species].radiusMult
end

local function roundMass(mass: number): number
	return math.floor(mass * 10 + 0.5) / 10 -- 12.2 keeps mass to 1 decimal
end

-- Writes the Mass attribute now if the last write is 0.25 s old, else once when it is.
local function publishMass(state: CreatureState)
	local slot = state.slot
	local now = os.clock()
	local last = massWrittenAt[slot] or -math.huge
	if now - last >= MASS_INTERVAL then
		massWrittenAt[slot] = now
		state.player:SetAttribute("Mass", roundMass(state.mass))
	elseif not massPending[slot] then
		massPending[slot] = true
		task.delay(MASS_INTERVAL - (now - last), function()
			massPending[slot] = nil
			if states[slot] == state then
				massWrittenAt[slot] = os.clock()
				state.player:SetAttribute("Mass", roundMass(state.mass))
			end
		end)
	end
end

local function writeSize(state: CreatureState)
	local d = diameterOf(state.bodyScale, state.species)
	state.root.Size = Vector3.new(d, d, d)
	state.writtenDiameter = d
end

-- The tree of section 6.1. Parented by the caller.
local function build(player: Player, species: string, bodyScale: number): (Model, Part)
	local model = Instance.new("Model")
	model.Name = `Creature_{player.UserId}`
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local d = diameterOf(bodyScale, species)
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Shape = Enum.PartType.Ball
	root.Size = Vector3.new(d, d, d)
	root.Transparency = 1
	root.CanCollide = true
	root.CanTouch = false
	root.CanQuery = true
	root.CastShadow = false
	root.CollisionGroup = if species == "eel"
		then CollisionGroups.CREATURE_EEL
		else CollisionGroups.CREATURE
	root.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0.2) -- density, friction, elasticity
	root.Parent = model

	local attachment = Instance.new("Attachment")
	attachment.Name = "RootAttachment"
	attachment.Parent = root

	local move = Instance.new("LinearVelocity")
	move.Name = "Move"
	move.Attachment0 = attachment
	move.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	move.RelativeTo = Enum.ActuatorRelativeTo.World
	move.MaxForce = MOVE_MAX_FORCE
	move.VectorVelocity = Vector3.zero
	move.Parent = root

	local turn = Instance.new("AlignOrientation")
	turn.Name = "Turn"
	turn.Attachment0 = attachment
	turn.Mode = Enum.OrientationAlignmentMode.OneAttachment
	turn.Responsiveness = TURN_RESPONSIVENESS
	turn.MaxTorque = TURN_MAX_TORQUE
	turn.Parent = root

	model.PrimaryPart = root
	return model, root
end

local function firstWithIndex(kind: string, slot: Slot): Volume?
	for _, v in WorldIndex.volumesOf(kind) do
		if v.attrs.CoveIndex == slot then
			return v
		end
	end
	return nil
end

--- Where a creature of `slot` appears: the centre of its `CoveInterior`, facing its `CoveMouth`.
--- A map with no cove for the slot (the CI arena has only cove 3) gives the first revive point.
function CreatureService.coveSpawnCFrame(slot: Slot): CFrame
	local interior = firstWithIndex("CoveInterior", slot)
	if interior then
		local at = Vector3.new(VolumeMath.centre(interior))
		local mouth = firstWithIndex("CoveMouth", slot)
		if mouth then
			local to = Vector3.new(VolumeMath.centre(mouth))
			if (to - at).Magnitude > 1e-3 then
				return CFrame.lookAt(at, to)
			end
		end
		return CFrame.new(at)
	end
	Log.once("warn", TAG, `no CoveInterior for cove {slot}: spawning at the first revive point`)
	local points = WorldIndex.revivePoints()
	if #points > 0 then
		return CFrame.new(points[1].x, points[1].y, points[1].z)
	end
	return CFrame.new(0, -50, 0)
end

function CreatureService.init()
	states, massWrittenAt, massPending = {}, {}, {}
	local existing = workspace:FindFirstChild(FOLDER)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER
		folder.Parent = workspace
	end
end

function CreatureService.start() end

--- Builds the player's creature, places it in their cove, makes it their Character, gives its
--- root to them and sets the public attributes (sections 6.2 and 6.3, Join row). The slot is
--- the `Slot` attribute PlayerLifecycle set. A second call for the same session returns the
--- creature already built.
function CreatureService.spawn(player: Player): CreatureState
	local slot = player:GetAttribute("Slot")
	assert(type(slot) == "number", "CreatureService.spawn: the player has no Slot yet")
	local existing = states[slot]
	if existing and existing.player == player then
		return existing
	end
	assert(existing == nil, `CreatureService.spawn: slot {slot} already has a creature`)

	-- TODO(B20, S4-C6): species and pattern from the profile (`species.selected`); the
	-- free Minnow until DataService exists.
	-- TODO(B19, S4-C4 and S4-C6): an account that has never banked starts its first run in the
	-- Nursery (6.3, Join row; canon 5.5), and a suspended run resumes by the return rule.
	local species = DEFAULT_SPECIES
	local def = Index.Species.byId[species]
	local mass = Index.Tiers.byTier[def.startTier].massNeeded
	local bodyScale = TierMath.bodyScale(mass)
	local model, root = build(player, species, bodyScale)
	local state: CreatureState = {
		slot = slot,
		player = player,
		species = species,
		mass = mass,
		tier = TierMath.tier(mass),
		bodyScale = bodyScale,
		model = model,
		root = root,
		writtenDiameter = root.Size.X,
	}
	states[slot] = state

	local cf = CreatureService.coveSpawnCFrame(slot)
	model:PivotTo(cf)
	local turn = root:FindFirstChild("Turn") :: AlignOrientation -- safe: built just above
	turn.CFrame = cf.Rotation
	model.Parent = folder
	player.Character = model -- a read-write Model property (V1); no Humanoid needed (spike S1)
	root:SetNetworkOwner(player) -- server-only (V5)
	player.ReplicationFocus = root -- the root while alive (6.6)

	player:SetAttribute("Species", species)
	player:SetAttribute("Tier", state.tier)
	massWrittenAt[slot] = os.clock()
	player:SetAttribute("Mass", roundMass(mass))
	player:SetAttribute("Phase", "cove")
	-- TODO(B20, S4-C6): `Pattern` from the profile. TODO(B19): `Traits`. TODO(B19, B25):
	-- `Protected` from protect().
	return state
end

--- Destroys the creature of `slot` and forgets it. PlayerLifecycle calls it on leave, after
--- `onLeaving` has fired, so leave settlement still reads the state.
function CreatureService.remove(slot: Slot)
	local state = states[slot]
	if not state then
		return
	end
	states[slot] = nil
	massWrittenAt[slot] = nil
	massPending[slot] = nil
	local player = state.player
	if player.Parent == Players and player.Character == state.model then
		player.ReplicationFocus = nil
		player.Character = nil
	end
	state.model:Destroy()
end

--- The creature of `slot`, or nil when it has none.
function CreatureService.get(slot: Slot): CreatureState?
	return states[slot]
end

--- Adds `amount` to the mass (negative for a hook or a vent; mass never goes below 0). The tier
--- and body scale follow from the new mass at once (section 6.8): Root.Size is rewritten past
--- a 3% change and at every tier change, and a tier change sets `Tier` and fires
--- `onTierChanged`.
function CreatureService.addMass(slot: Slot, amount: number)
	local state = states[slot]
	if not state then
		return
	end
	state.mass = math.max(0, state.mass + amount)
	state.bodyScale = TierMath.bodyScale(state.mass)
	local tier = TierMath.tier(state.mass)
	local changed = tier ~= state.tier
	local d = diameterOf(state.bodyScale, state.species)
	if changed or math.abs(d - state.writtenDiameter) > SIZE_STEP * state.writtenDiameter then
		writeSize(state)
	end
	publishMass(state)
	if changed then
		state.tier = tier
		state.player:SetAttribute("Tier", tier)
		-- TODO(B14, S8-C2): MovementValidator.grace(slot, 0.5) on every tier change (6.8).
		CreatureService.onTierChanged:fire(slot, tier)
	end
end

--- Starts a status effect (stun, slow, burn, yank, push) on the creature for `seconds`.
--- TODO(B24): hazards and status effects (02 §0.6 overlays) are written with PredatorService.
function CreatureService.setStatus(_slot: Slot, _effect: string, _seconds: number) end

--- Protects the creature for `seconds` (revive, reconnect, newcomer shield) and sets the
--- `Protected` attribute. TODO(B19, S4-C4; B25, S12-C2): revive and reconnect protection with
--- RunLoopService, the newcomer shield with player bites.
function CreatureService.protect(_slot: Slot, _reason: string, _seconds: number) end

--- Moves the creature to `cf` (the return rule of section 6.3 picks the place; the caller
--- follows it with MovementValidator.grace). The owner's copy snaps to it (spike S4).
function CreatureService.teleport(slot: Slot, cf: CFrame)
	local state = states[slot]
	if not state then
		return
	end
	state.model:PivotTo(cf)
	state.root.AssemblyLinearVelocity = Vector3.zero
end

return CreatureService
