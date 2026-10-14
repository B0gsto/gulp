--!strict
-- BankMath: the Pearl arithmetic of banking and of getting gulped (task S4-C3, module B07;
-- canon 5.4 and 5.5; docs/02, sections 0.7, 11 and 12.2; docs/05, sections 3.1 and 3.2;
-- docs/09, section 13.4). Pure numbers, so it runs in Lune.
--
-- The mass bands and their rates come from Data/Generated/BankRates (canon 5.4 data:BankRates),
-- the scraps shares from Scraps (canon 5.5 data:Scraps); the Deep Pockets multiplier and the
-- run thresholds, which the bible gives in prose, from Config/Defaults.bank.
local Defaults = require("../Config/Defaults")
local Index = require("../Data/Index")
local TraitRules = require("./TraitRules")

local BankMath = {}

local B = Defaults.bank
BankMath.DEEP_POCKETS = B.deepPockets
BankMath.ARMED_MASS = B.armedMass
BankMath.SPECIMEN_TIER = B.specimenTier

--- Base Pearls for banking `mass` (canon 5.4, 05 §3.1): each band of data:BankRates pays its rate
--- for the mass inside it (3 per mass to 1,200, 1 per mass to 3,000, nothing above). Mass below 0
--- pays nothing.
function BankMath.base(mass: number): number
	local total = 0
	for _, band in Index.BankRates.list do
		local top = if band.upTo then math.min(mass, band.upTo) else mass
		if top > band.from then
			total += band.pearlsPerMass * (top - band.from)
		end
	end
	return total
end

--- Pearls a bank pays (05 §3.1): the base × 1.5 with Crystal × 2 with Deep Pockets, rounded down.
function BankMath.bank(mass: number, crystal: boolean, deepPockets: boolean): number
	local mult = (if crystal then TraitRules.CRYSTAL_BANK else 1)
		* (if deepPockets then BankMath.DEEP_POCKETS else 1)
	return math.floor(BankMath.base(mass) * mult)
end

--- The scraps share (canon 5.5 data:Scraps): 50% while the account has died fewer than three
--- times before, then 10%. `deathsBefore` counts earlier deaths, so this death is number
--- `deathsBefore + 1`.
function BankMath.scrapsRate(deathsBefore: number): number
	local share = 0
	for _, row in Index.Scraps.list do
		if deathsBefore + 1 >= row.fromDeath then
			share = row.share
		end
	end
	return share
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

--- The Pearls of one bank split by 10 §5.1's SKUs, so each line logs on its own: `base` (bank_t1
--- to bank_t7), the extra from Crystal's ×1.5 (bank_crystal) and the extra from Deep Pockets' ×2
--- (bank_deep_pockets). Whole numbers that add up to `BankMath.bank`.
function BankMath.parts(
	mass: number,
	crystal: boolean,
	deepPockets: boolean
): { base: number, crystal: number, deepPockets: number }
	local base = math.floor(BankMath.base(mass))
	local withCrystal = BankMath.bank(mass, crystal, false)
	return {
		base = base,
		crystal = withCrystal - base,
		deepPockets = BankMath.bank(mass, crystal, deepPockets) - withCrystal,
	}
end

--- The base bank SKU of 10 §5.1 for a bank at `tier` (1 to 7): `bank_t<tier>`.
function BankMath.bankSku(tier: number): string
	return `bank_t{math.clamp(math.floor(tier), 1, 7)}`
end

--- The scraps SKU of 10 §5.1 (`scraps_50` for the first three deaths, else `scraps_10`).
function BankMath.scrapsSku(deathsBefore: number): string
	return `scraps_{math.round(BankMath.scrapsRate(deathsBefore) * 100)}`
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
