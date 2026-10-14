--!strict
-- BankMath: the Pearl arithmetic of banking and of getting gulped (task S4-C3, module B07;
-- canon 5.4 and 5.5; docs/02, sections 0.7, 11 and 12.2; docs/05, sections 3.1 and 3.2;
-- docs/09, section 13.4). Pure numbers, so it runs in Lune.
--
-- 05 §3.1 and §3.2 give the numbers as formulas, so they live in Config/Defaults.bank.
local Defaults = require("../Config/Defaults")
local TraitRules = require("./TraitRules")

local BankMath = {}

local B = Defaults.bank
BankMath.FULL_RATE_MASS = B.fullRateMass
BankMath.CEILING_MASS = B.ceilingMass
BankMath.FULL_RATE = B.fullRate
BankMath.LOW_RATE = B.lowRate
BankMath.DEEP_POCKETS = B.deepPockets
BankMath.SCRAPS_RATE = B.scrapsRate
BankMath.SCRAPS_RATE_EARLY = B.scrapsRateEarly
BankMath.EARLY_DEATHS = B.earlyDeaths
BankMath.ARMED_MASS = B.armedMass
BankMath.SPECIMEN_TIER = B.specimenTier

--- Base Pearls for banking `mass` (05 §3.1): 3 per mass to 1,200, 1 per mass to 3,000, nothing
--- above. Mass below 0 pays nothing.
function BankMath.base(mass: number): number
	local low = math.clamp(mass, 0, BankMath.FULL_RATE_MASS)
	local high = math.clamp(
		mass - BankMath.FULL_RATE_MASS,
		0,
		BankMath.CEILING_MASS - BankMath.FULL_RATE_MASS
	)
	return BankMath.FULL_RATE * low + BankMath.LOW_RATE * high
end

--- Pearls a bank pays (05 §3.1): the base × 1.5 with Crystal × 2 with Deep Pockets, rounded down.
function BankMath.bank(mass: number, crystal: boolean, deepPockets: boolean): number
	local mult = (if crystal then TraitRules.CRYSTAL_BANK else 1)
		* (if deepPockets then BankMath.DEEP_POCKETS else 1)
	return math.floor(BankMath.base(mass) * mult)
end

--- The scraps share (canon 5.5): 50% while the account has died fewer than three times before,
--- then 10%.
function BankMath.scrapsRate(deathsBefore: number): number
	return if deathsBefore < BankMath.EARLY_DEATHS
		then BankMath.SCRAPS_RATE_EARLY
		else BankMath.SCRAPS_RATE
end

--- Pearls a gulp pays (05 §3.2): the share of what the run would have banked, rounded down.
function BankMath.scraps(
	mass: number,
	crystal: boolean,
	deepPockets: boolean,
	deathsBefore: number
): number
	return math.floor(BankMath.scrapsRate(deathsBefore) * BankMath.bank(mass, crystal, deepPockets))
end

--- Reef Rank points for a bank (09 §13.4 step 3, canon 11): the bank without Deep Pockets.
function BankMath.bankRankPoints(mass: number, crystal: boolean): number
	return BankMath.bank(mass, crystal, false)
end

--- Reef Rank points for a gulp (02 §12.2): the scraps without Deep Pockets.
function BankMath.scrapsRankPoints(mass: number, crystal: boolean, deathsBefore: number): number
	return BankMath.scraps(mass, crystal, false, deathsBefore)
end

--- Whether entering the own cove banks (02 §0.7, §11.2): the run is armed at mass ≥ 1.
function BankMath.armed(mass: number): boolean
	return mass >= BankMath.ARMED_MASS
end

--- Whether a bank at `tier` keeps a specimen (canon 5.4, 02 §11.4); a free slot is the caller's.
function BankMath.keepsSpecimen(tier: number): boolean
	return tier >= BankMath.SPECIMEN_TIER
end

return table.freeze(BankMath)
