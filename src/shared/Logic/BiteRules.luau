--!strict
-- BiteRules: who can eat whom, and what an eat gives (task S4-C3, module B07; canon 5.2 and 9;
-- docs/02, sections 0.4, 0.5, 4.2, 4.4, 6.1, 6.3, 6.5 and 6.6; docs/09, section 10.2). The one
-- eat rule of the game: BiteService, PredatorService, the prey threat pass and the outlines all
-- read it. Pure numbers and tables, so it runs in Lune. Rule functions return `(ok, reason)` and
-- never throw (09 §4.6).
--
-- Wild creatures [L] count as players on both sides (02 §0.4, §6.1 rule 9): pass kind "player".
-- Predator tiers and the mass of edible predators come from Data/Generated/Predators; a predator
-- with no `eatenMass` (Gull, Moray, Old Scar) is never edible (canon 5.2). The other numbers have
-- no data row in the bible; they are below with their source.
local Index = require("../Data/Index")
local TraitRules = require("./TraitRules")

local BiteRules = {}

BiteRules.PLAYER_GAIN = 0.30 -- canon 5.2: eating a player gives 30% of the victim's mass
BiteRules.REPEAT_GUARD_SECONDS = 90 -- 02 §4.2 check 7, §6.1 rule 7
BiteRules.FEED_GUARD_SECONDS = 600 -- 02 §6.6: repeats of the same victim within 10 minutes
BiteRules.FEED_GUARD = table.freeze({ 1, 0.5, 0.25 }) -- 02 §4.4: then 0 from the fourth time
BiteRules.NURSERY_MAX_TIER = 2 -- canon 5.2, 02 §0.5: tier 3 or higher cannot enter the Nursery
BiteRules.NURSERY_SHARE = table.freeze({ 1, 0.5 }) -- 02 §4.4: Nursery prey to tier 1, tier 2; else 0

export type Kind = "prey" | "player" | "predator"

--- 09 §10.2's reject reasons, plus "repeat" (02 §4.2 check 7) and "inedible" (canon 5.2).
export type Reason = "state" | "tier" | "safe zone" | "protected" | "range" | "repeat" | "inedible"

--- What saved a victim whose bite was otherwise legal (09 §10.2 rules 7 and 8).
export type Save = "bubble" | "plated"

--- The target of a `canEat` test. Prey ignores every flag (02 §0.4). `protected` is any
--- protection window of 02 §6.3, the first-run shield included; `tucked` is the turtle's Shell.
export type Target = {
	kind: Kind,
	tier: number,
	inSafeVolume: boolean?,
	protected: boolean?,
	tucked: boolean?,
	puffed: boolean?,
	spiny: boolean?,
}

--- A player's bite on another player as the server sees it at processing time (09 §10.2).
export type PlayerBite = {
	eaterInRun: boolean, -- in a run and alive
	eaterStunned: boolean,
	eaterFlagged: boolean,
	victimInRun: boolean, -- in a run and alive (a disconnected body still counts, 09 §10.4)
	eaterTier: number,
	victimTier: number,
	victimInSafeVolume: boolean, -- NurserySafe, a CoveMouth or a CoveInterior
	victimProtected: boolean, -- revive, resume, first-run shield, spawn, tier-up, ... (02 §6.3)
	victimTucked: boolean, -- Shell
	victimPuffed: boolean,
	victimSpiny: boolean,
	inRange: boolean, -- 09 §10.3, the caller's lag-compensated distance test
	recentlyGulped: boolean, -- this eater gulped this victim in the last 90 s
	bubbleAvailable: boolean, -- `newcomer.biteAbsorbed` is false
	platedAvailable: boolean, -- TraitRules.platedAvailable
}

--- A creature eats prey of its tier or lower (canon 5.2). Plankton (tier 0) is edible by all.
function BiteRules.canEatPrey(eaterTier: number, preyTier: number): boolean
	return preyTier <= eaterTier
end

--- The tier a non-prey target defends with (09 §10.2 rule 5): +1 while puffed, +1 with Spiny.
--- Equal to 02 §0.4's "gap 2 with Spiny".
function BiteRules.defenceTier(tier: number, puffed: boolean, spiny: boolean): number
	return tier + (if puffed then 1 else 0) + (if spiny then TraitRules.SPINY_DEFENCE else 0)
end

--- The bare tier test of 02 §0.4 for a non-prey target, with no window, volume or Shell: tier 1
--- immunity when both sides are players, then one full tier above the defence tier.
function BiteRules.tierAllows(
	eaterTier: number,
	eaterIsPlayer: boolean,
	targetTier: number,
	targetIsPlayer: boolean,
	puffed: boolean,
	spiny: boolean
): boolean
	if eaterIsPlayer and targetIsPlayer and targetTier <= 1 then
		return false
	end
	return eaterTier >= BiteRules.defenceTier(targetTier, puffed, spiny) + 1
end

--- 02 §0.4 `canEat`, the one function that decides every bite. `eaterIsPlayer` is true for a
--- player or wild creature, false for a predator. Edibility of predators by kind is
--- `canEatPredator`; this tests the tier and the flags only.
function BiteRules.canEat(
	eaterTier: number,
	eaterIsPlayer: boolean,
	target: Target
): (boolean, Reason?)
	if target.kind == "prey" then
		if BiteRules.canEatPrey(eaterTier, target.tier) then
			return true, nil
		end
		return false, "tier"
	end
	if target.inSafeVolume then
		return false, "safe zone"
	end
	if target.protected or target.tucked then
		return false, "protected"
	end
	if
		not BiteRules.tierAllows(
			eaterTier,
			eaterIsPlayer,
			target.tier,
			target.kind == "player",
			target.puffed == true,
			target.spiny == true
		)
	then
		return false, "tier"
	end
	return true, nil
end

--- Whether a predator can ever be eaten (canon 5.2: Barracuda and Grouper; never the Gull, the
--- Moray or Old Scar). Read from data: edible predators have an `eatenMass`.
function BiteRules.predatorEdible(predatorId: string): boolean
	local def = Index.Predators.byId[predatorId]
	return def ~= nil and def.eatenMass ~= nil
end

--- A player eating a predator (02 §0.4): an edible predator, one full tier higher.
function BiteRules.canEatPredator(eaterTier: number, predatorId: string): (boolean, Reason?)
	local def = Index.Predators.byId[predatorId]
	if def == nil or def.eatenMass == nil then
		return false, "inedible"
	end
	return BiteRules.canEat(eaterTier, true, { kind = "predator", tier = def.tier })
end

--- A predator's strike on a player (02 §0.4: predators use their own tier; they eat tier 1).
function BiteRules.predatorCanEat(predatorId: string, target: Target): (boolean, Reason?)
	local def = Index.Predators.byId[predatorId]
	if def == nil then
		return false, "inedible"
	end
	return BiteRules.canEat(def.tier, false, target)
end

--- 09 §10.2: a player's bite on a player, checked in order at processing time; the first failure
--- decides. Returns true to gulp. A refused bite returns the reason, and for the newcomer bubble
--- (rule 7) and the Plated save (rule 8) also which one the caller must spend. 02 §4.2 check 7
--- (the 90 s repeat guard), which 09 §10.2 does not list, runs after the range test.
function BiteRules.playerBite(b: PlayerBite): (boolean, Reason?, Save?)
	if not b.eaterInRun or not b.victimInRun or b.eaterStunned or b.eaterFlagged then
		return false, "state", nil
	end
	if b.victimTier <= 1 then
		return false, "tier", nil
	end
	if b.victimInSafeVolume then
		return false, "safe zone", nil
	end
	if b.victimProtected or b.victimTucked then
		return false, "protected", nil
	end
	if
		not BiteRules.tierAllows(
			b.eaterTier,
			true,
			b.victimTier,
			true,
			b.victimPuffed,
			b.victimSpiny
		)
	then
		return false, "tier", nil
	end
	if not b.inRange then
		return false, "range", nil
	end
	if b.recentlyGulped then
		return false, "repeat", nil
	end
	if b.bubbleAvailable then
		return false, "protected", "bubble"
	end
	if b.platedAvailable then
		return false, "protected", "plated"
	end
	return true, nil, nil
end

--- True while the 90 s repeat guard holds: this eater last gulped this victim at `lastAt`.
function BiteRules.repeatBlocked(lastAt: number?, now: number): boolean
	return lastAt ~= nil and now - lastAt < BiteRules.REPEAT_GUARD_SECONDS
end

--- The feed guard (02 §4.4, §6.6) for an eat after `timesBefore` eats of the same victim by the
--- same eater inside 10 minutes: 1, 0.5, 0.25, then 0.
function BiteRules.feedGuard(timesBefore: number): number
	return BiteRules.FEED_GUARD[math.max(0, math.floor(timesBefore)) + 1] or 0
end

--- The Nursery share of a prey's mass (02 §4.4): 100% at tier 1, 50% at tier 2, nothing above.
function BiteRules.nurseryShare(eaterTier: number): number
	return BiteRules.NURSERY_SHARE[eaterTier] or 0
end

--- Whether a creature of `tier` may enter `NurserySafe` (canon 5.2, 02 §0.5).
function BiteRules.mayEnterNursery(tier: number): boolean
	return tier <= BiteRules.NURSERY_MAX_TIER
end

--- Mass from eating prey or trait prey of mass `preyMass` (02 §4.4): Spots and Bonefed apply,
--- and inside the Nursery the tier share does too.
function BiteRules.preyGain(
	preyMass: number,
	traits: { string },
	eaterTier: number,
	inNursery: boolean
): number
	local share = if inNursery then BiteRules.nurseryShare(eaterTier) else 1
	return preyMass * TraitRules.massMult(traits, "prey") * share
end

--- Mass from eating a player of mass `victimMass` (canon 5.2, 02 §4.4): 30%, Bonefed (not
--- Spots), then the feed guard.
function BiteRules.playerGain(victimMass: number, traits: { string }, timesBefore: number): number
	return BiteRules.PLAYER_GAIN
		* victimMass
		* TraitRules.massMult(traits, "player")
		* BiteRules.feedGuard(timesBefore)
end

--- Mass from eating a predator (canon 5.2, 02 §4.4): its `eatenMass`, Bonefed (not Spots).
--- 0 for a predator that cannot be eaten.
function BiteRules.predatorGain(predatorId: string, traits: { string }): number
	local def = Index.Predators.byId[predatorId]
	if def == nil or def.eatenMass == nil then
		return 0
	end
	return def.eatenMass * TraitRules.massMult(traits, "predator")
end

return table.freeze(BiteRules)
