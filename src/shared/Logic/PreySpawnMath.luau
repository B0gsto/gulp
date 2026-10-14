--!strict
-- PreySpawnMath: how many groups of each prey a zone, or a spawn area cut from one, keeps alive
-- (docs/02, section 9.6; docs/03, section 2.3; docs/09, section 8.1). Pure numbers, so it runs in
-- Lune; PreyService passes in the players and the plan area of its spawn volumes.
--
--   target = base × playerScale(n) × eventScale × areaScale, never above cap × eventScale × areaScale
--   playerScale(n) = clamp(0.6 + 0.4 × n / 24, 0.6, 1.0)
--   eventScale     = 2 in a Feeding Frenzy (normal prey), else 1
--   areaScale      = spawn area ÷ zone area, both seen from above; 1 on the real map
-- The Nursery uses base + perPlayerInside × playersInside instead of playerScale. A base counted
-- in members becomes groups at the prey's mean group size. Targets and caps round to whole groups,
-- and every prey a zone allows keeps at least 1 group (02 §9.6, "Smaller spawn areas").
local Index = require("../Data/Index")
local Types = require("../Types")

type PreySpawnDef = Types.PreySpawnDef

export type Situation = {
	players: number, -- n, players on the server
	playersInside: number?, -- players inside the zone (the Nursery's rule); default 0
	frenzy: boolean?, -- a Feeding Frenzy is on
	area: number?, -- plan area of the spawn area in studs²; nil for the whole zone
}

export type Target = { prey: string, weight: number, groups: number, cap: number }

local PreySpawnMath = {}

local FULL_SERVER = 24
local FRENZY_SCALE = 2

local function round(x: number): number
	return math.floor(x + 0.5)
end

function PreySpawnMath.playerScale(n: number): number
	return math.clamp(0.6 + 0.4 * n / FULL_SERVER, 0.6, 1.0)
end

--- The plan area of a Block or Ball volume (studs², from above). A Cylinder volume's axis is its
--- local X, so seen from above it is a rectangle too.
function PreySpawnMath.planArea(shape: string, sizeX: number, sizeZ: number): number
	if shape == "Ball" then
		return math.pi * (sizeX / 2) * (sizeZ / 2)
	end
	return sizeX * sizeZ
end

--- Mean members per group of a prey: the middle of its group size (03 §2.1).
function PreySpawnMath.meanMembers(preyId: string): number
	local prey = Index.Prey.byId[preyId]
	assert(prey, `PreySpawnMath: unknown prey {preyId}`)
	return (prey.groupMin + prey.groupMax) / 2
end

--- The live target and cap, in groups, for one spawn row in a situation.
function PreySpawnMath.target(def: PreySpawnDef, situation: Situation): (number, number)
	local scale = if situation.area then situation.area / def.zoneArea else 1
	local event = if situation.frenzy then FRENZY_SCALE else 1
	local base = def.base
	if def.baseUnit == "members" then
		base /= PreySpawnMath.meanMembers(def.prey)
	end
	local raw
	if def.perPlayerInside then
		raw = base + def.perPlayerInside * (situation.playersInside or 0)
	else
		raw = base * PreySpawnMath.playerScale(situation.players)
	end
	local cap = math.max(1, round(def.cap * scale * event))
	local groups = math.max(1, math.min(round(raw * scale * event), cap))
	return groups, cap
end

--- Every prey's target in a zone, in spawn-table order. An unknown zone, or one with no spawn
--- rows (the coves), gives an empty list.
function PreySpawnMath.zoneTargets(zoneId: string, situation: Situation): { Target }
	local out = {}
	local rows: { PreySpawnDef } = Index.PreySpawns.byZone[zoneId] or {}
	for _, def in rows do
		local groups, cap = PreySpawnMath.target(def, situation)
		table.insert(out, { prey = def.prey, weight = def.weight, groups = groups, cap = cap })
	end
	return out
end

return table.freeze(PreySpawnMath)
