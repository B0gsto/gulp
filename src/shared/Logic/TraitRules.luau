--!strict
-- TraitRules: what a creature's held traits do to the numbers, and the pip, slot and shed rules
-- (task S4-C3, module B07; canon 9; docs/02, sections 8.1 to 8.5; docs/09, section 5.1
-- TraitService). Pure: numbers, strings and tables only, so it runs in Lune.
--
-- A creature's traits are a dense list of up to three trait IDs (`RunSnapshot.traits`, 09 §12.2);
-- `pips` maps a trait ID to the trait prey of that kind eaten this run (`RunSnapshot.progress`).
-- The functions that change them (`eatTraitPrey`, `shed`, `grantReady`) change the tables the
-- caller passes in and return what happened; nothing else here changes its arguments.
--
-- The rarity bonuses come from Data/Generated/Traits (05 §3.3 data:TraitIncome); the effect
-- numbers (canon 9, 02 §8.4) from Config/Defaults.traits.
local Defaults = require("../Config/Defaults")
local Index = require("../Data/Index")

local TraitRules = {}

local T = Defaults.traits
TraitRules.SLOTS = T.slots
TraitRules.PIPS = T.pips
TraitRules.PIPS_KEEN_NOSE = T.pipsKeenNose
TraitRules.STRIPES_SPEED = T.stripesSpeed
TraitRules.SPOTS_MASS = T.spotsMass
TraitRules.BONEFED_MASS = T.bonefedMass
TraitRules.CRYSTAL_BANK = T.crystalBank
TraitRules.LONGFIN_DASH = T.longfinDash -- adds with the species' own (02 §8.5)
TraitRules.SPINY_DEFENCE = T.spinyDefence
TraitRules.ACTIVATE_DELAY = T.activateDelay
TraitRules.GLOW_RADIUS = T.glowRadius
TraitRules.GLOW_MARKERS = T.glowMarkers
TraitRules.GLOW_LIGHT = T.glowLight

export type MassSource = "prey" | "player" | "predator"
export type PipResult = "gained" | "pip" | "held" | "full" | "unknown"

--- One trait slot as `HUD.Traits` draws it (08 §3.6): "owned" (a held trait), "progress" (the
--- in-progress trait shown in a free slot, with its pips) or "empty".
export type SlotView = {
	state: "owned" | "progress" | "empty",
	traitId: string?,
	pips: number, -- pips lit (progress only; 0 otherwise)
	needed: number, -- pips on the arc: 5, or 4 with Keen Nose
}

--- A trait prey Glow may mark (02 §8.4): its trait, distance from the creature's centre, and any
--- fields the caller needs to draw it (they are kept).
export type MarkerCandidate = { traitId: string, distance: number }

-- 02 §8.3: base states in which a trait cannot be shed.
local NO_SHED: { [string]: boolean } = table.freeze({
	Stunned = true,
	Hooked = true,
	Transit = true,
	Banking = true,
	Gulped = true,
})

--- True when `traits` holds `id`.
function TraitRules.has(traits: { string }, id: string): boolean
	return table.find(traits, id) ~= nil
end

--- A specimen's cove income bonus: the sum of its traits' rarity bonuses (canon 9, 02 §8.5),
--- e.g. 0.30 for Spots and Plated. An unknown ID adds nothing. Summed in hundredths so the sum is
--- exact (0.1 + 0.2 is not 0.3 in floating point).
function TraitRules.incomeBonus(traits: { string }): number
	local hundredths = 0
	for _, id in traits do
		local def = Index.Traits.byId[id]
		if def then
			hundredths += math.round(def.incomeBonus * 100)
		end
	end
	return hundredths / 100
end

--- The swim speed multiplier (02 §8.4 Stripes; speed multipliers multiply, 02 §8.5).
function TraitRules.speedMult(traits: { string }): number
	return if TraitRules.has(traits, "stripes") then TraitRules.STRIPES_SPEED else 1
end

--- The mass gain multiplier for one eat (02 §4.4, §8.5): Spots adds 10% on prey and trait prey
--- only; Bonefed adds 25% on everything; bonuses add (Spots with Bonefed is ×1.35 on prey).
function TraitRules.massMult(traits: { string }, source: MassSource): number
	local bonus = 0
	if source == "prey" and TraitRules.has(traits, "spots") then
		bonus += TraitRules.SPOTS_MASS
	end
	if TraitRules.has(traits, "bonefed") then
		bonus += TraitRules.BONEFED_MASS
	end
	return 1 + bonus
end

--- Tiers added to the creature's defence tier in the eat test (02 §0.4 Spiny; 09 §10.2 rule 5).
function TraitRules.defenceTierBonus(traits: { string }): number
	return if TraitRules.has(traits, "spiny") then TraitRules.SPINY_DEFENCE else 0
end

--- The trait part of the dash length bonus, added to the species' own (02 §7.1, §8.5: Eel with
--- Longfin is +60%).
function TraitRules.dashLengthAdd(traits: { string }): number
	return if TraitRules.has(traits, "longfin") then TraitRules.LONGFIN_DASH else 0
end

--- The bank Pearl multiplier from traits held at the moment of banking (02 §8.4 Crystal).
function TraitRules.bankMult(traits: { string }): number
	return if TraitRules.has(traits, "crystal") then TraitRules.CRYSTAL_BANK else 1
end

--- True when the run still has its one Plated save (02 §8.4): Plated is held and not yet used.
function TraitRules.platedAvailable(traits: { string }, platedUsed: boolean): boolean
	return not platedUsed and TraitRules.has(traits, "plated")
end

--- Trait prey of one kind needed for its trait (02 §8.1).
function TraitRules.pipsNeeded(keenNose: boolean): number
	return if keenNose then TraitRules.PIPS_KEEN_NOSE else TraitRules.PIPS
end

--- One trait prey of `traitId` was eaten (02 §8.1, §8.2). Returns:
---   "held"    the trait is already held: mass only
---   "full"    all three slots are full: mass only, no pip (pips for other traits stay frozen)
---   "pip"     one pip added
---   "gained"  the last pip: the trait takes the next slot (its index is the second value) and its
---             pips are cleared
---   "unknown" not a trait ID: nothing changes
function TraitRules.eatTraitPrey(
	traits: { string },
	pips: { [string]: number },
	traitId: string,
	keenNose: boolean
): (PipResult, number?)
	if Index.Traits.byId[traitId] == nil then
		return "unknown", nil
	end
	if TraitRules.has(traits, traitId) then
		return "held", nil
	end
	if #traits >= TraitRules.SLOTS then
		return "full", nil
	end
	local count = (pips[traitId] or 0) + 1
	if count >= TraitRules.pipsNeeded(keenNose) then
		pips[traitId] = nil
		table.insert(traits, traitId)
		return "gained", #traits
	end
	pips[traitId] = count
	return "pip", nil
end

--- Whether a creature in base state `state` (02 §0.6) may shed (02 §8.3).
function TraitRules.canShed(state: string): boolean
	return not NO_SHED[state]
end

--- Sheds the trait in slot `index` (02 §8.3): it is removed at once, its pips reset to 0, and
--- nothing is given back. Refused with a reason when the state forbids it or the slot is empty.
function TraitRules.shed(
	traits: { string },
	pips: { [string]: number },
	index: number,
	state: string
): (boolean, string?)
	if not TraitRules.canShed(state) then
		return false, "state"
	end
	local id = traits[index]
	if id == nil then
		return false, "empty"
	end
	table.remove(traits, index)
	pips[id] = nil
	return true, nil
end

--- Keen Nose bought mid-run (02 §8.1): every trait already at the Keen Nose count is granted at
--- once while a slot is free, in canon trait order. Returns the IDs granted, in that order.
function TraitRules.grantReady(traits: { string }, pips: { [string]: number }): { string }
	local granted = {}
	for _, def in Index.Traits.list do
		if #traits >= TraitRules.SLOTS then
			break
		end
		local count = pips[def.id]
		if count and count >= TraitRules.PIPS_KEEN_NOSE and not TraitRules.has(traits, def.id) then
			pips[def.id] = nil
			table.insert(traits, def.id)
			table.insert(granted, def.id)
		end
	end
	return granted
end

--- Whether a trait gained at `gainedAt` is active at `now` (02 §8.2: the effect becomes active
--- 0.5 s after the last pip). Both on the same clock.
function TraitRules.isActive(gainedAt: number, now: number): boolean
	return now - gainedAt >= TraitRules.ACTIVATE_DELAY
end

--- The `Traits` player attribute (09 §5.3): the held IDs comma-joined, "" for none.
function TraitRules.joinIds(traits: { string }): string
	return table.concat(traits, ",")
end

--- The trait list of a `Traits` attribute value: known trait IDs only, in order, at most three.
--- Anything that is not a string gives an empty list.
function TraitRules.splitIds(value: unknown): { string }
	local traits: { string } = {}
	if type(value) ~= "string" then
		return traits
	end
	for id in string.gmatch(value, "[^,]+") do
		if Index.Traits.byId[id] and not TraitRules.has(traits, id) then
			table.insert(traits, id)
			if #traits >= TraitRules.SLOTS then
				break
			end
		end
	end
	return traits
end

local function canonOrder(id: string): number
	local def = Index.Traits.byId[id]
	return if def then def.wire else math.huge
end

--- What the three slots of `HUD.Traits` show (08 §3.6): held traits fill slots from the left in
--- the order gained; each free slot then shows the in-progress trait with the most pips (ties:
--- the most recent, by `recency`, a trait ID → a number that grows with each new pip; then canon
--- order). Traits already held and traits with no pips are not shown as in progress. Pips are
--- capped at the count needed.
function TraitRules.slotView(
	traits: { string },
	pips: { [string]: number },
	recency: { [string]: number },
	keenNose: boolean
): { SlotView }
	local needed = TraitRules.pipsNeeded(keenNose)
	local views: { SlotView } = {}
	for i = 1, math.min(#traits, TraitRules.SLOTS) do
		table.insert(views, { state = "owned", traitId = traits[i], pips = 0, needed = needed })
	end
	local waiting: { string } = {}
	for id, count in pips do
		if count > 0 and Index.Traits.byId[id] and not TraitRules.has(traits, id) then
			table.insert(waiting, id)
		end
	end
	table.sort(waiting, function(a: string, b: string): boolean
		if pips[a] ~= pips[b] then
			return pips[a] > pips[b]
		end
		local ra, rb = recency[a] or 0, recency[b] or 0
		if ra ~= rb then
			return ra > rb
		end
		return canonOrder(a) < canonOrder(b)
	end)
	local next = 1
	while #views < TraitRules.SLOTS do
		local id = waiting[next]
		if id then
			table.insert(views, {
				state = "progress",
				traitId = id,
				pips = math.min(pips[id], needed),
				needed = needed,
			})
			next += 1
		else
			table.insert(views, { state = "empty", traitId = nil, pips = 0, needed = needed })
		end
	end
	return views
end

local function nearerFirst(a: MarkerCandidate, b: MarkerCandidate): boolean
	return a.distance < b.distance
end

--- Glow's markers (02 §8.4): sorts `candidates` (trait prey already within the Glow radius)
--- nearest first, in place, and returns how many to draw: at most `limit` (six by default).
function TraitRules.pickMarkers(candidates: { MarkerCandidate }, limit: number?): number
	table.sort(candidates, nearerFirst)
	return math.min(#candidates, limit or TraitRules.GLOW_MARKERS)
end

return table.freeze(TraitRules)
