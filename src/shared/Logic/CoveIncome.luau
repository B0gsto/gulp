--!strict
-- CoveIncome: the cove's income pile from timestamps (task S4-C3, module B07; canon 9 and 11;
-- docs/02, sections 13.2 and 13.3; docs/05, sections 3.3, 3.4 and 3.10; docs/09, sections 13.2
-- and 13.3). Pure numbers, so it runs in Lune. One formula online and offline.
--
-- Clock-tamper safety (09 §13.3): `now` is the caller's server `os.time()`; elapsed time is
-- clamped to 0 from below and `accruedAt` only moves forward, so a slow clock cannot wind the
-- pile back and re-pay a period; the pile is capped, so a fast clock over-pays at most one cap.
--
-- The base rate per tier comes from Data/Generated/Tiers (05 §3.3 data:CoveIncome), trait bonuses
-- from Traits (05 data:TraitIncome) through TraitRules, the caps and thresholds from
-- Config/Defaults.cove.
local Defaults = require("../Config/Defaults")
local Index = require("../Data/Index")
local TraitRules = require("./TraitRules")
local Types = require("../Types")

local CoveIncome = {}

local C = Defaults.cove
CoveIncome.CAP_HOURS = C.capHours
CoveIncome.CAP_HOURS_TIDE_WATCHER = C.capHoursTideWatcher
CoveIncome.BOOST_HOURS = C.boostHours
CoveIncome.REFUND_MIN = C.refundMin
CoveIncome.AWAY_MIN_SECONDS = C.awayMinSeconds
CoveIncome.AWAY_MIN_PEARLS = C.awayMinPearls

local HOUR = 3600

--- Pearls per hour of one specimen (05 §3.3): base(tier) × (1 + its traits' rarity bonuses).
--- A tier with no base (tier 1, or out of range) earns nothing. Computed in hundredths so the
--- worked examples come out exact (30 × 1.30 = 39).
function CoveIncome.specimenRate(tier: number, traits: { string }): number
	local def = Index.Tiers.byTier[tier]
	local base = if def then def.coveIncome else nil
	if base == nil then
		return 0
	end
	return base * math.round(100 + TraitRules.incomeBonus(traits) * 100) / 100
end

--- The cove's Pearls per hour: the sum over its specimens (05 §3.3).
function CoveIncome.rate(specimens: { Types.SpecimenRecord }): number
	local total = 0
	for _, s in specimens do
		total += CoveIncome.specimenRate(s.tier, s.traits)
	end
	return total
end

--- Hours the pile fills before it stops (canon 11; 05 §3.4).
function CoveIncome.capHours(tideWatcher: boolean): number
	return if tideWatcher then CoveIncome.CAP_HOURS_TIDE_WATCHER else CoveIncome.CAP_HOURS
end

--- Brings the pile up to `now` at `rate` Pearls per hour (09 §13.2). Returns the new pile and the
--- new `accruedAt`. Call it before any change to the specimen list, so the old rate applies to
--- the old period. The pile never decreases and never grows past `rate × capHours`; `accruedAt`
--- never moves back; a clock behind `accruedAt` adds nothing.
function CoveIncome.accrue(
	pending: number,
	accruedAt: number,
	now: number,
	rate: number,
	capHours: number
): (number, number)
	local dt = math.clamp(now - accruedAt, 0, capHours * HOUR)
	local newPending = math.min(pending + rate * dt / HOUR, rate * capHours)
	return math.max(newPending, pending), math.max(accruedAt, now)
end

--- A claim (02 §13.2, 05 §3.3): the whole Pearls of the pile are paid, the fraction stays.
--- Returns the Pearls to grant and the pile left behind.
function CoveIncome.claim(pending: number): (number, number)
	local pearls = math.max(0, math.floor(pending))
	return pearls, pending - pearls
end

--- Cove Boost [L] (05 §3.4, 09 §13.2): two hours of the current rate, straight to Pearls.
function CoveIncome.boost(rate: number): number
	return math.floor(CoveIncome.BOOST_HOURS * rate)
end

--- The release refund (02 §11.5, 05 §3.10): one hour of the released specimen's income, at least 5.
function CoveIncome.refund(specimenRate: number): number
	return math.max(CoveIncome.REFUND_MIN, math.floor(specimenRate))
end

--- The first-bank reward (canon 11, 05 §3.3): one hour of the first specimen's income, rounded
--- down (6 Pearls for a tier 2 with Glow).
function CoveIncome.firstBankReward(tier: number, traits: { string }): number
	return math.floor(CoveIncome.specimenRate(tier, traits))
end

--- Whether the join shows the "While you were away" card (02 §13.3).
function CoveIncome.showAwayCard(awaySeconds: number, earned: number): boolean
	return awaySeconds >= CoveIncome.AWAY_MIN_SECONDS and earned >= CoveIncome.AWAY_MIN_PEARLS
end

return table.freeze(CoveIncome)
