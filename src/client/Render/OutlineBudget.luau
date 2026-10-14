--!strict
-- Render/OutlineBudget (task S3-C6; docs/09 section 8.8, docs/06 section 13.2): the outline caps
-- are one budget per colour across everything on screen, nearest first: 20 edible and 10
-- dangerous things (8 and 4 on Smooth), a player, a predator and a prey group each counting as
-- one. CreatureController and PreyRenderer each pick their own outlines with
-- `OutlineRules.select`; before that, each publishes its candidates here and gets back its share
-- of the budget, worked out against the other side's latest candidates
-- (`OutlineRules.share`). Creatures win ties.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OutlineRules = require(ReplicatedStorage.Shared.Logic.OutlineRules)

export type Side = "creatures" | "prey"

type Candidates = {
	edible: { number },
	nEdible: number,
	dangerous: { number },
	nDangerous: number,
}

local OutlineBudget = {}

local function newCandidates(): Candidates
	return { edible = {}, nEdible = 0, dangerous = {}, nDangerous = 0 }
end

local sides: { [Side]: Candidates } = { creatures = newCandidates(), prey = newCandidates() }
local capEdible: number = OutlineRules.CAP.edible
local capDangerous: number = OutlineRules.CAP.dangerous

--- The graphics tier's caps (`tune.quality.outlinesEdible` / `outlinesDangerous`, 15 §3.0).
function OutlineBudget.setCaps(edible: number, dangerous: number)
	capEdible, capDangerous = edible, dangerous
end

--- Publishes `side`'s candidates (`kinds[i]`, `distances[i]` in studs from the viewer, `count` of
--- them) and returns its edible and dangerous caps for `OutlineRules.select`.
function OutlineBudget.caps(
	side: Side,
	kinds: { OutlineRules.Kind },
	distances: { number },
	count: number
): (number, number)
	local mine = sides[side]
	local otherSide: Side = if side == "creatures" then "prey" else "creatures"
	local other = sides[otherSide]
	mine.nEdible = OutlineRules.sortedDistances(kinds, distances, count, "edible", mine.edible)
	mine.nDangerous =
		OutlineRules.sortedDistances(kinds, distances, count, "dangerous", mine.dangerous)
	local first = side == "creatures"
	return OutlineRules.share(
		capEdible,
		mine.edible,
		mine.nEdible,
		other.edible,
		other.nEdible,
		first
	),
		OutlineRules.share(
			capDangerous,
			mine.dangerous,
			mine.nDangerous,
			other.dangerous,
			other.nDangerous,
			first
		)
end

return OutlineBudget
