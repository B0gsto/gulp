--!strict
-- CoveRules: the pure half of CoveService (task S5-C2, module B22; canon 5.4 and 11; docs/02,
-- sections 11.4, 11.5 and 13; docs/05, sections 3.3, 3.4, 3.10 and 4.2; docs/09, sections 5.1,
-- 12.2 and 13). Tables and numbers only, so it runs in Lune.
--
-- Every change to a cove first brings the income pile up to `now` at the old rate (02 §13.2,
-- 05 §3.4: "the server first adds the income earned so far, then switches to the new rate"), so a
-- specimen never earns for time before it arrived and a released one stops at once. The functions
-- that change a cove change the table they are given; CoveService hands them a copy and writes the
-- copy back through DataService.
local CoveIncome = require("./CoveIncome")
local CoveMouths = require("../Data/Generated/CoveMouths")
local Defaults = require("../Config/Defaults")
local Index = require("../Data/Index")
local Types = require("../Types")

type SpecimenRecord = Types.SpecimenRecord

--- The fields of the saved cove (09 §12.2) that these rules read and write.
export type Cove = {
	slots: number,
	specimens: { SpecimenRecord },
	pendingSpecimen: SpecimenRecord?,
	pending: number,
	accruedAt: number,
	lastClaim: { amount: number, at: number }?,
	bubbles: number,
}

--- What `add` did (09 §5.1 `AddResult`): `added` to the next free slot; `full`, kept as
--- `pendingSpecimen` for the release choice (02 §11.5); `refused`, nothing changed (a bad record,
--- or a release choice already waiting).
export type AddResult = "added" | "full" | "refused"

--- One specimen as the client draws it (09 §13.1).
export type SpecimenView = {
	id: string,
	sp: string,
	tier: number,
	mass: number,
	traits: { string },
	pat: string?,
}

--- The one table `CoveView` carries (09 §5.3, §13.1): whose cove, how many slots, what is in it.
--- Decorations [L] are added with the decoration task.
export type View = {
	slot: number,
	owner: string,
	slots: number,
	specimens: { SpecimenView },
	bubbles: number,
}

local C = Defaults.cove

local CoveRules = {}

--- `CoveAction` ops (09 §5.3: op + up to 2 scalars). The second argument is a specimen ID for
--- `release` and 0 otherwise.
CoveRules.Op = table.freeze({
	claim = 1, -- tap on the Pearl clam (02 §13.2): sku claim_pile
	claimWelcome = 2, -- Claim on the "While you were away" card (02 §13.3): sku claim_welcome
	buySlot = 3, -- the next cove slot for Pearls (05 §4.2)
	release = 4, -- release a specimen, or the waiting new one (02 §11.5)
})
CoveRules.OP_MAX = 4

CoveRules.FREE_SLOTS = Defaults.save.coveSlots
-- 05 §4.2 data:SlotPrices: the last slot sold for Pearls (30).
CoveRules.MAX_SLOTS = Index.SlotPrices.list[#Index.SlotPrices.list].slot
CoveRules.BIGGER_COVE_SLOTS = C.biggerCoveSlots
CoveRules.MIN_TIER = Defaults.bank.specimenTier
CoveRules.MAX_TIER = 7
CoveRules.MAX_TRAITS = Defaults.traits.slots
CoveRules.ID_LENGTH = 8

local ID_CHARS = "abcdefghijkmnpqrstuvwxyz23456789" -- no l, o, 0 or 1

--- Slots the cove holds: the bought ones, plus 10 with Bigger Cove (09 §12.2: at read time).
function CoveRules.capacity(slots: number, biggerCove: boolean): number
	return slots + (if biggerCove then CoveRules.BIGGER_COVE_SLOTS else 0)
end

--- The SKU of buying slot `slot` (10 §5.2 `CoveSlot`), or nil for a slot that is not sold.
function CoveRules.slotSku(slot: number): string?
	if slot >= 7 and slot <= 12 then
		return "slots_07_12"
	elseif slot >= 13 and slot <= 20 then
		return "slots_13_20"
	elseif slot >= 21 and slot <= CoveRules.MAX_SLOTS then
		return "slots_21_30"
	end
	return nil
end

--- The next slot for a cove with `slots` bought slots: its number, price (05 §4.2
--- data:SlotPrices) and SKU, or nil once all 30 are bought.
function CoveRules.nextSlot(slots: number): (number?, number?, string?)
	local slot = slots + 1
	local def = Index.SlotPrices.bySlot[slot]
	if def == nil then
		return nil, nil, nil
	end
	return slot, def.price, CoveRules.slotSku(slot)
end

--- Brings the pile up to `now` at the cove's current rate (09 §13.2, `CoveIncome.accrue`).
function CoveRules.settle(cove: Cove, now: number, capHours: number)
	local lastClaimAt = if cove.lastClaim then cove.lastClaim.at else nil
	cove.pending, cove.accruedAt = CoveIncome.accrue(
		cove.pending,
		cove.accruedAt,
		now,
		CoveIncome.rate(cove.specimens),
		lastClaimAt,
		capHours
	)
end

--- Pearls in the pile at `now`, without changing the cove (the clam's number, 02 §13.2).
function CoveRules.pileAt(cove: Cove, now: number, capHours: number): number
	local lastClaimAt = if cove.lastClaim then cove.lastClaim.at else nil
	local pile = CoveIncome.accrue(
		cove.pending,
		cove.accruedAt,
		now,
		CoveIncome.rate(cove.specimens),
		lastClaimAt,
		capHours
	)
	return pile
end

local function has(cove: Cove, id: string): boolean
	if cove.pendingSpecimen and cove.pendingSpecimen.id == id then
		return true
	end
	for _, s in cove.specimens do
		if s.id == id then
			return true
		end
	end
	return false
end

--- A new 8-character specimen ID, unique within the cove (09 §12.2). `pick(n)` returns a whole
--- number from 1 to n (a `Random`'s NextInteger in the engine).
function CoveRules.newId(cove: Cove, pick: (n: number) -> number): string
	while true do
		local chars = table.create(CoveRules.ID_LENGTH)
		for i = 1, CoveRules.ID_LENGTH do
			local at = pick(#ID_CHARS)
			chars[i] = string.sub(ID_CHARS, at, at)
		end
		local id = table.concat(chars)
		if not has(cove, id) then
			return id
		end
	end
end

--- Whether `rec` can be a specimen (canon 5.4, 09 §12.2): a species, tier 2 to 7, a mass, at
--- most three traits.
function CoveRules.checkRecord(rec: SpecimenRecord): (boolean, string?)
	if type(rec.sp) ~= "string" or rec.sp == "" then
		return false, "no species"
	end
	if
		type(rec.tier) ~= "number"
		or rec.tier ~= math.floor(rec.tier)
		or rec.tier < CoveRules.MIN_TIER
		or rec.tier > CoveRules.MAX_TIER
	then
		return false, `tier {rec.tier} cannot be a specimen`
	end
	if
		type(rec.mass) ~= "number"
		or rec.mass ~= rec.mass
		or rec.mass < 0
		or rec.mass == math.huge
	then
		return false, "bad mass"
	end
	if type(rec.traits) ~= "table" or #rec.traits > CoveRules.MAX_TRAITS then
		return false, "too many traits"
	end
	return true, nil
end

-- Puts `rec` in the next free slot. The first specimen of a cove with no `lastClaim` starts the
-- cap window now (09 §13.2), so `CoveIncome.accrue` always has a `lastClaimAt` to count from.
local function place(cove: Cove, rec: SpecimenRecord, at: number?, now: number)
	if at then
		cove.specimens[at] = rec
	else
		table.insert(cove.specimens, rec)
	end
	if cove.lastClaim == nil then
		cove.lastClaim = { amount = 0, at = now }
	end
end

--- Adds a banked specimen (02 §11.4): settles the pile at the old rate, then takes the lowest
--- free slot, or waits as `pendingSpecimen` when the cove is full (02 §11.5). `rec` is stored as
--- given; the caller gives it its ID (`newId`) and rounds its mass.
function CoveRules.add(
	cove: Cove,
	rec: SpecimenRecord,
	now: number,
	capacity: number,
	capHours: number
): AddResult
	if not CoveRules.checkRecord(rec) or has(cove, rec.id) then
		return "refused"
	end
	if #cove.specimens >= capacity then
		if cove.pendingSpecimen then
			return "refused" -- a choice is already waiting: no new run starts until it is made
		end
		cove.pendingSpecimen = rec
		return "full"
	end
	CoveRules.settle(cove, now, capHours)
	place(cove, rec, nil, now)
	return "added"
end

--- Releases the specimen `id`, or the waiting new one (02 §11.5). The pile is settled first; a
--- waiting new specimen takes the freed slot. Returns the refund (05 §3.10:
--- `max(5, floor(one hour of its income))`), or nil when there is no such specimen.
function CoveRules.release(cove: Cove, id: string, now: number, capHours: number): number?
	local waiting = cove.pendingSpecimen
	if waiting and waiting.id == id then
		cove.pendingSpecimen = nil
		return CoveIncome.refund(CoveIncome.specimenRate(waiting.tier, waiting.traits))
	end
	for index, s in cove.specimens do
		if s.id == id then
			CoveRules.settle(cove, now, capHours)
			if waiting then
				cove.pendingSpecimen = nil
				place(cove, waiting, index, now)
			else
				table.remove(cove.specimens, index)
			end
			return CoveIncome.refund(CoveIncome.specimenRate(s.tier, s.traits))
		end
	end
	return nil
end

--- A claim (02 §13.2, 09 §13.2): the pile is settled, its whole Pearls leave it and `lastClaim`
--- records the claim, which restarts the cap window. Returns the Pearls to grant.
function CoveRules.claim(cove: Cove, now: number, capHours: number): number
	CoveRules.settle(cove, now, capHours)
	local pearls, rest = CoveIncome.claim(cove.pending)
	cove.pending = rest
	cove.lastClaim = { amount = pearls, at = now }
	return pearls
end

--- Adds one bought slot (05 §4.2; the price is spent by the caller). A waiting new specimen moves
--- into it. False when all 30 are bought.
function CoveRules.addSlot(cove: Cove, now: number, capHours: number): boolean
	if CoveRules.nextSlot(cove.slots) == nil then
		return false
	end
	CoveRules.settle(cove, now, capHours)
	cove.slots += 1
	local waiting = cove.pendingSpecimen
	if waiting then
		cove.pendingSpecimen = nil
		place(cove, waiting, nil, now)
	end
	return true
end

--- The `CoveView` table of cove `slot` (09 §13.1).
function CoveRules.view(slot: number, owner: string, cove: Cove, capacity: number): View
	local list = table.create(#cove.specimens)
	for i, s in cove.specimens do
		list[i] = {
			id = s.id,
			sp = s.sp,
			tier = s.tier,
			mass = s.mass,
			traits = table.clone(s.traits),
			pat = s.pat,
		}
	end
	return { slot = slot, owner = owner, slots = capacity, specimens = list, bubbles = cove.bubbles }
end

-- Cove assignment (09 §13.1; 04 §5.5 owns the rule). The mouths come from 03 §6.7
-- (data:CoveMouths); the Gap and the size of the returning pool from Config/Defaults.
CoveRules.RETURNING_POOL = C.returningPool

local function byGap(): { number }
	local gx, gz = C.gap[1], C.gap[2]
	local d: { [number]: number } = {}
	local order: { number } = {}
	for _, m in CoveMouths do
		d[m.wire] = math.sqrt((m.x - gx) ^ 2 + (m.z - gz) ^ 2)
		table.insert(order, m.wire)
	end
	table.sort(order, function(a, b)
		local da, db = math.round(d[a]), math.round(d[b])
		if da ~= db then
			return da < db
		end
		return a < b
	end)
	return order
end

local NEAREST = table.freeze(byGap())

--- The coves to try, in order, for a joining account with `banks` banks (09 §13.1, 04 §5.5): an
--- account that has never banked gets the free cove nearest the Gap (C16, C17, C15, C18 ...); a
--- returning one the free cove farthest from it among the 20 nearest, so the closest stay free
--- for newcomers, then the four beyond those 20. For `SlotPool.take`.
function CoveRules.preference(banks: number): { number }
	if banks <= 0 then
		return table.clone(NEAREST)
	end
	local out = table.create(#NEAREST)
	for i = CoveRules.RETURNING_POOL, 1, -1 do
		table.insert(out, NEAREST[i])
	end
	for i = CoveRules.RETURNING_POOL + 1, #NEAREST do
		table.insert(out, NEAREST[i])
	end
	return out
end

-- The two volumes of every cove (09 §9.1 `CoveMouth` and `CoveInterior`, `CoveIndex` = the cove
-- number; 02 §11.1: together they are `CoveSafe`, from the mouth plane in). Sizes are 03's: the
-- mouth opening 36 wide × 28 high centred at depth 30 on the Rim's inner face, then a 25-stud throat
-- (§6.7); the chamber 76 wide × 44 high × 110 long behind it, floor at depth 52 and ceiling at depth
-- 8 (§6.10). Each cove runs straight out from the Reef's centre through its mouth.
CoveRules.MOUTH_SIZE = table.freeze({ 36, 28, 25 }) -- width, height, throat length
CoveRules.CHAMBER_SIZE = table.freeze({ 76, 44, 110 }) -- width, height, length
CoveRules.MOUTH_DEPTH = 30

--- One box volume: its centre, the horizontal look vector of the part (toward the Reef, as the
--- cove art's mouth faces, 03 §6.7) and its size (X width, Y height, Z length along the look).
export type BoxVolume = {
	x: number,
	y: number,
	z: number,
	lookX: number,
	lookZ: number,
	size: { number },
}

--- The `CoveMouth` (the throat, from the mouth plane in) and `CoveInterior` (the chamber) boxes
--- of the cove whose mouth centre is (`mx`, `mz`) (data:CoveMouths). Y is up and the surface is
--- Y 0, so depth d is Y −d.
function CoveRules.volumes(mx: number, mz: number): (BoxVolume, BoxVolume)
	local r = math.sqrt(mx * mx + mz * mz)
	local ox, oz = mx / r, mz / r -- out from the centre, into the cove
	local m, c = CoveRules.MOUTH_SIZE, CoveRules.CHAMBER_SIZE
	local y = -CoveRules.MOUTH_DEPTH
	local mouthMid, chamberMid = m[3] / 2, m[3] + c[3] / 2
	return {
		x = mx + ox * mouthMid,
		y = y,
		z = mz + oz * mouthMid,
		lookX = -ox,
		lookZ = -oz,
		size = { m[1], m[2], m[3] },
	}, {
		x = mx + ox * chamberMid,
		y = y,
		z = mz + oz * chamberMid,
		lookX = -ox,
		lookZ = -oz,
		size = { c[1], c[2], c[3] },
	}
end

return table.freeze(CoveRules)
