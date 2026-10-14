--!strict
-- CollisionGroups: registers the collision groups of docs/09, section 6.5 once, puts the
-- `Workspace.Collision` shell in `World`, and builds the ray parameters that hit the shell only.
-- Five groups of the engine's limit of 32 (V24).
local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = {}

CollisionGroups.WORLD = "World"
CollisionGroups.CREATURE = "Creature"
CollisionGroups.CREATURE_EEL = "CreatureEel"
CollisionGroups.EEL_GATE = "EelGate"
CollisionGroups.VISUAL = "Visual"

--- Every group, in the order of the section 6.5 table.
CollisionGroups.NAMES = table.freeze({ "World", "Creature", "CreatureEel", "EelGate", "Visual" })

--- The pairs that collide (section 6.5). Every other pair, and every pair with `Default`, does not.
CollisionGroups.COLLIDES = table.freeze({
	{ "World", "Creature" },
	{ "World", "CreatureEel" },
	{ "Creature", "Creature" },
	{ "Creature", "CreatureEel" },
	{ "Creature", "EelGate" },
	{ "CreatureEel", "CreatureEel" },
})

local function collides(a: string, b: string): boolean
	for _, pair in CollisionGroups.COLLIDES do
		if (pair[1] == a and pair[2] == b) or (pair[1] == b and pair[2] == a) then
			return true
		end
	end
	return false
end

--- Registers the groups and sets the whole matrix. Safe to call more than once.
function CollisionGroups.register()
	for _, name in CollisionGroups.NAMES do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	local all = table.clone(CollisionGroups.NAMES)
	table.insert(all, "Default")
	for i, a in all do
		for j = i, #all do
			local b = all[j]
			if a ~= "Default" or b ~= "Default" then
				PhysicsService:CollisionGroupSetCollidable(a, b, collides(a, b))
			end
		end
	end
end

--- Puts every part of the collision shell in `World`. A part authored in Studio with the
--- `EelGate` group (a blocker across an eel hole) keeps it. Returns the number of parts set.
function CollisionGroups.assignShell(shell: Instance): number
	local count = 0
	for _, part in shell:GetDescendants() do
		if part:IsA("BasePart") and part.CollisionGroup ~= CollisionGroups.EEL_GATE then
			part.CollisionGroup = CollisionGroups.WORLD
			count += 1
		end
	end
	return count
end

--- Ray parameters that hit the `World` parts of the shell and nothing else: the ray acts as a
--- `CreatureEel` (which collides with `World` but not with `EelGate`) and only looks inside the
--- shell, so creature roots are never hit. With no shell the ray hits nothing.
function CollisionGroups.worldRayParams(shell: Instance?): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = if shell then { shell } else {}
	params.CollisionGroup = CollisionGroups.CREATURE_EEL
	params.IgnoreWater = true
	return params
end

return CollisionGroups
