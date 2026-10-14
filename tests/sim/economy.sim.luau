--!strict
-- economy.sim (docs/09, section 16.2; task S5-C6): scripted players through 30 days on the
-- generated data tables and the pure Logic modules, checked against the canon's pacing.
--
-- What it runs:
--   * Growth inside a run: bites per minute by tier in the tier's home zone (05 §2.2, result
--     table) × prey mass (generated Prey, through BiteRules and BiteMath), the Feeding Frenzy
--     uplift (05 §2.3, last column) while TideClock says a Frenzy is running, and TierMath for
--     the tier at each mass. Integrated per second for every start time in the hour.
--   * Runs: 05 §5.3's run types (mass at bank, bank chance, gulped 60% of the way through, the
--     average trait bonus of the specimen) and each player's run-time mix by day; a run's length
--     is the time this growth model needs to reach its bank mass. Banks and scraps through
--     BankMath (generated BankRates and Scraps), specimens and the 8-hour pile through
--     CoveIncome (generated Tiers income), claimed on entering the cove at each session start.
--   * Rewards: daily goals (generated RewardBands × GoalRules.rankMultiplier), Reef Rank from
--     lifetime banked Pearls (generated ReefRanks), Codex as 05 §5.2 assumption 6. The login
--     streak, the tide bonus and the rank Pearl rewards are [L], but 05 §5's model (and so the
--     canon's unlock days) counts them, so they are paid here as 05 §3.6 and §3.9 give them.
--   * Spending: 05 §5.2 assumption 7 (species first; slots from generated SlotPrices).
--
-- Fails when (09 §16.2): time to a tier is more than 25% off canon 5.1; the regular player's
-- median day for a species is more than 30% off canon section 7 (05 §5.1 reads the canon's
-- "non-paying daily player" as the regular player; casual and heavy are printed, not gated);
-- Pearls per hour grow without bound (the cove rate passes 05 §6.2's ceiling, or the regular
-- player's daily Pearls still grow as fast in the last week as in the second).
--
-- Runs in CI as is (`lune run tools/test/runner -- sim`): 2,000 players per profile, 39 days
-- (30 × 1.3, so the Shark Pup gate can be decided), a few seconds. ECONOMY_SIM_PLAYERS changes the
-- cohort size. Deterministic for the seed. Balance numbers are never changed here: the table is
-- printed and the gap reported.
local process = require("@lune/process")

local BankMath = require("../../src/shared/Logic/BankMath")
local BiteMath = require("../../src/shared/Logic/BiteMath")
local BiteRules = require("../../src/shared/Logic/BiteRules")
local CoveIncome = require("../../src/shared/Logic/CoveIncome")
local GoalRules = require("../../src/shared/Logic/GoalRules")
local Index = require("../../src/shared/Data/Index")
local Rng = require("../../src/shared/Util/Rng")
local TestKit = require("../../src/shared/Util/TestKit")
local TideClock = require("../../src/shared/Logic/TideClock")
local TierMath = require("../../src/shared/Logic/TierMath")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- Harness parameters (test inputs, not game tunables).
local SEED = 0xEC05
local PLAYERS = tonumber(process.env.ECONOMY_SIM_PLAYERS) or 2000
local DAYS = 39 -- 30 days, run on to 30 × 1.3 so a late Shark Pup is measured, not cut off
local REPORT_DAYS = 30
local OFFSET_STEP = 10 -- s: growth curves for every 10 s of the hour
local CURVE_SECONDS = 2400 -- s: longest run the curves cover (D banks at about 20 minutes)
local DAY = 86400
local HOUR = 3600

-- Canon targets (the oracle, not inputs). Canon 5.1: minutes to each tier.
local TIER_TARGET: { [number]: number } =
	{ [2] = 0.5, [3] = 2, [4] = 4, [5] = 7, [6] = 12, [7] = 20 }
local TIER_TOLERANCE = 0.25 -- 09 §16.2
-- Canon section 7: unlock day, as a range (Pufferfish "by the end of the first session" is day 1;
-- Sea Turtle "day 4 or 5").
local UNLOCK_TARGET: { [string]: { number } } = {
	puffer = { 1, 1 },
	eel = { 2, 2 },
	turtle = { 4, 5 },
	squid = { 10, 10 },
	shark = { 30, 30 },
}
local UNLOCK_TOLERANCE = 0.30 -- 09 §16.2
-- Gaps this sim found that are the owner's to settle (balance is never changed here). A listed
-- gap is printed, not failed; the gate fails if it closes, so the entry is then removed. None
-- now: the day-1 Eel (task S5-C6) was settled by the Eel's price (chapter 14, section 4).
local OWNER_GAPS: { [string]: boolean } = {}

-- 05 §2.2 result table: catches per minute of an average player in the tier's home zone.
local BITES: { [number]: { [string]: number } } = {
	[1] = { krill = 18, plankton = 5.04 },
	[2] = { krill = 4, shrimp = 1.5, sardine = 2.03 },
	[3] = { krill = 4, darter = 1.6, shrimp = 1.5, sardine = 0.4 },
	[4] = { mackerel = 1.1, darter = 0.99 },
	[5] = { mackerel = 1.8, bonito = 0.19 },
	[6] = { bonito = 1.1, tuna = 0.13 },
	[7] = { tuna = 0.25, bonito = 1.1, mackerel = 0.28 },
}
-- 05 §2.3: mass per minute in the home zone, normal and during a Feeding Frenzy (the uplift).
local FRENZY_UPLIFT: { [number]: number } = {
	[1] = 28.4 / 19.0,
	[2] = 24.8 / 14.4,
	[3] = 36.8 / 23.8,
	[4] = 54.4 / 37.4,
	[5] = 80.4 / 56.2,
	[6] = 128.6 / 86.0,
	[7] = 167.7 / 110.6,
}

-- 05 §5.3: run types. `mass` at bank, `bank` chance, average trait `bonus` of the specimen.
type RunType = { mass: number, bank: number, bonus: number }
local RUN_TYPES: { [string]: RunType } = {
	A0 = { mass = 79, bank = 0.65, bonus = 0 },
	A = { mass = 80, bank = 0.80, bonus = 0.10 },
	B = { mass = 200, bank = 0.65, bonus = 0.25 },
	C = { mass = 500, bank = 0.45, bonus = 0.45 },
	D = { mass = 1200, bank = 0.25, bonus = 0.65 },
	["A+"] = { mass = 80, bank = 0.90, bonus = 0.10 },
	["B+"] = { mass = 200, bank = 0.78, bonus = 0.30 },
	["C+"] = { mass = 500, bank = 0.60, bonus = 0.55 },
	["D+"] = { mass = 1200, bank = 0.40, bonus = 0.90 },
}
local GULPED_AT = 0.6 -- 05 §5.3: a gulped run ends 60% of the way through

-- 05 §5.1 and §5.3: the three players. Sessions are (start hour UTC, minutes): 05 §5.1's play
-- per day with the gaps of 05 §5.5's re-check (casual 23.75 h, regular about 11.7 h, heavy 5, 5
-- and 12.5 h). Mix: run-time shares by first day.
type Mix = { from: number, shares: { [string]: number } }
type Profile = {
	name: string,
	sessions: { { number } },
	goalShare: number,
	tideBonuses: number,
	codex: number,
	mixes: { Mix },
}
local RUN_SHARE = 0.85 -- 05 §5.1: share of a session spent in runs
local PROFILES: { Profile } = {
	{
		name = "Casual",
		sessions = { { 18, 15 } },
		goalShare = 0.60,
		tideBonuses = 0.7,
		codex = 3500,
		mixes = {
			{ from = 1, shares = { A0 = 1 } },
			{ from = 4, shares = { A = 0.8, B = 0.2 } },
			{ from = 11, shares = { A = 0.6, B = 0.4 } },
		},
	},
	{
		name = "Regular",
		sessions = { { 8, 20 }, { 20, 20 } },
		goalShare = 0.90,
		tideBonuses = 2,
		codex = 7000,
		mixes = {
			{ from = 1, shares = { A0 = 1 } },
			{ from = 2, shares = { A = 1 } },
			{ from = 3, shares = { A = 0.5, B = 0.5 } },
			{ from = 8, shares = { A = 0.25, B = 0.5, C = 0.25 } },
			{ from = 15, shares = { A = 0.15, B = 0.4, C = 0.35, D = 0.1 } },
		},
	},
	{
		name = "Heavy",
		sessions = { { 7, 30 }, { 12.5, 30 }, { 18, 30 } },
		goalShare = 1,
		tideBonuses = 3,
		codex = 14000,
		mixes = {
			{ from = 1, shares = { A0 = 0.5, A = 0.5 } },
			{ from = 2, shares = { A = 0.3, B = 0.5, C = 0.2 } },
			{ from = 5, shares = { ["A+"] = 0.1, ["B+"] = 0.35, ["C+"] = 0.4, ["D+"] = 0.15 } },
			{ from = 11, shares = { ["B+"] = 0.25, ["C+"] = 0.4, ["D+"] = 0.35 } },
		},
	},
}
local GATED = "Regular"
local CODEX_DAYS = 12 -- 05 §5.2 assumption 6: total × (1 − e^(−day ÷ 12))
local STREAK = { 100, 100, 150, 150, 200, 300, 500 } -- 05 §3.6 [L], × rank multiplier
local TIDE_BONUS = 40 -- 05 §3.9 [L], × rank multiplier
local SLOT_SHARE, DECO_SHARE, DECO_FROM = 0.20, 0.05, 5 -- 05 §5.2 assumption 7
local SLOT_SHARE_AFTER, DECO_SHARE_AFTER = 0.70, 0.30 -- after the Shark Pup

---------------------------------------------------------------------------------------------
-- Growth inside a run.

-- Mass per minute by tier from the bites and the generated prey masses.
local MASS_PER_MIN: { [number]: number } = {}
for tier, bites in BITES do
	local total = 0
	for id, perMinute in bites do
		local prey = Index.Prey.byId[id]
		assert(prey, `economy.sim: no prey {id}`)
		assert(BiteRules.canEatPrey(tier, prey.tier), `economy.sim: tier {tier} cannot eat {id}`)
		total += perMinute * BiteMath.gain(prey.mass, 1, 1)
	end
	MASS_PER_MIN[tier] = total
end

-- Seconds of the hour in which a Feeding Frenzy runs (TideClock, MVP build, no limited tide).
local frenzyAt: { boolean } = {}
for s = 0, HOUR - 1 do
	local state = TideClock.at(s)
	frenzyAt[s + 1] = state.phase == "active" and state.id == "frenzy"
end

-- curves[i][k + 1] = mass k seconds into a run that starts (i − 1) × OFFSET_STEP into the hour.
local OFFSETS = HOUR // OFFSET_STEP
local curves: { { number } } = {}
for i = 1, OFFSETS do
	local start = (i - 1) * OFFSET_STEP
	local mass = 0
	local curve = table.create(CURVE_SECONDS + 1)
	curve[1] = 0
	for k = 1, CURVE_SECONDS do
		local tier = TierMath.tier(mass)
		local rate = MASS_PER_MIN[tier] / 60
		if frenzyAt[(start + k - 1) % HOUR + 1] then
			rate *= FRENZY_UPLIFT[tier]
		end
		mass += rate
		curve[k + 1] = mass
	end
	curves[i] = curve
end

local function offsetIndex(clock: number): number
	return (math.floor(clock) % HOUR) // OFFSET_STEP + 1
end

-- Seconds a run starting at `clock` needs to reach `mass` (linear between samples).
local function timeTo(clock: number, mass: number): number
	local curve = curves[offsetIndex(clock)]
	assert(curve[#curve] >= mass, `economy.sim: {mass} mass is beyond the growth curve`)
	local lo, hi = 1, #curve
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if curve[mid] >= mass then
			hi = mid
		else
			lo = mid
		end
	end
	local a, b = curve[lo], curve[hi]
	return (lo - 1) + (if b > a then (mass - a) / (b - a) else 0)
end

local function massAt(clock: number, seconds: number): number
	local curve = curves[offsetIndex(clock)]
	local k = math.clamp(seconds, 0, CURVE_SECONDS)
	local lo = math.floor(k)
	local hi = math.min(lo + 1, CURVE_SECONDS)
	return curve[lo + 1] + (curve[hi + 1] - curve[lo + 1]) * (k - lo)
end

local function meanTimeTo(mass: number): number
	local total = 0
	for i = 1, OFFSETS do
		total += timeTo((i - 1) * OFFSET_STEP, mass)
	end
	return total / OFFSETS
end

-- Expected minutes of a run of each type, for turning run-time shares into run choices.
local EXPECTED_MINUTES: { [string]: number } = {}
local LENGTH_MINUTES: { [string]: number } = {}
for id, rt in RUN_TYPES do
	local length = meanTimeTo(rt.mass) / 60
	LENGTH_MINUTES[id] = length
	EXPECTED_MINUTES[id] = length * (rt.bank + (1 - rt.bank) * GULPED_AT)
end

---------------------------------------------------------------------------------------------
-- Players.

local SPECIES_ORDER: { { id: string, price: number } } = {}
for _, def in Index.Species.list do
	if def.unlockPearls ~= nil and def.unlockPearls > 0 then
		table.insert(SPECIES_ORDER, { id = def.id, price = def.unlockPearls })
	end
end
table.sort(SPECIES_ORDER, function(a, b)
	return a.price < b.price
end)
local FREE_SLOTS = Index.SlotPrices.list[1].slot - 1
local FULL_DAY = 0
for _, band in { "R1", "R2", "R3", GoalRules.ALL_DONE_BAND } do
	FULL_DAY += Index.RewardBands.byId[band].pearls
end

type DayRow = {
	earned: number,
	rate: number,
	slots: number,
	rank: number,
	balance: number,
	sources: { [string]: number }, -- cumulative by source
}

type Player = {
	rng: Rng.Rng,
	jitter: number, -- s added to every session start: the player's phase against the tides
	pearls: number,
	earned: number,
	banked: number, -- lifetime banked Pearls (base banking and scraps), for Reef Rank
	rank: number,
	deaths: number,
	specimens: { number }, -- Pearls per hour of each specimen
	rate: number,
	slots: number,
	pile: number,
	accruedAt: number,
	lastClaimAt: number,
	firstBank: boolean,
	nextSpecies: number,
	slotSpent: number,
	decoSpent: number,
	carry: number, -- run minutes carried to the next session (05 §5.2 assumption 8)
	streakBox: number,
	tideCarry: number,
	codexPaid: number,
	unlockDay: { [string]: number },
	pufferMinute: number?,
	playedMinutes: number,
	byDay: { DayRow },
	slotDay: { [number]: number }, -- day each Pearl slot was bought
	sources: { [string]: number },
}

local function newPlayer(rng: Rng.Rng): Player
	return {
		rng = rng,
		jitter = Rng.int(rng, 0, 59) * 60,
		pearls = 0,
		earned = 0,
		banked = 0,
		rank = 1,
		deaths = 0,
		specimens = {},
		rate = 0,
		slots = FREE_SLOTS,
		pile = 0,
		accruedAt = 0,
		lastClaimAt = 0,
		firstBank = false,
		nextSpecies = 1,
		slotSpent = 0,
		decoSpent = 0,
		carry = 0,
		streakBox = 0,
		tideCarry = 0,
		codexPaid = 0,
		unlockDay = {},
		pufferMinute = nil,
		playedMinutes = 0,
		byDay = {},
		slotDay = {},
		sources = { banking = 0, cove = 0, daily = 0, oneTime = 0 },
	}
end

local function spend(p: Player, day: number)
	while p.nextSpecies <= #SPECIES_ORDER and p.pearls >= SPECIES_ORDER[p.nextSpecies].price do
		local s = SPECIES_ORDER[p.nextSpecies]
		p.pearls -= s.price
		p.unlockDay[s.id] = day
		if s.id == "puffer" then
			p.pufferMinute = p.playedMinutes
		end
		p.nextSpecies += 1
	end
	local afterShark = p.unlockDay.shark ~= nil
	local slotShare = if afterShark then SLOT_SHARE_AFTER else SLOT_SHARE
	if p.unlockDay.puffer ~= nil and #p.specimens >= p.slots then
		local next = Index.SlotPrices.bySlot[p.slots + 1]
		while
			next ~= nil
			and p.pearls >= next.price
			and p.slotSpent + next.price <= slotShare * p.earned
		do
			p.pearls -= next.price
			p.slotSpent += next.price
			p.slots += 1
			p.slotDay[p.slots] = day
			next = Index.SlotPrices.bySlot[p.slots + 1]
		end
	end
	local decoShare = if afterShark
		then DECO_SHARE_AFTER
		elseif day >= DECO_FROM then DECO_SHARE
		else 0
	local deco = math.min(p.pearls, decoShare * p.earned - p.decoSpent)
	if deco > 0 and p.nextSpecies > 1 then
		p.pearls -= deco
		p.decoSpent += deco
	end
end

local function pay(p: Player, amount: number, source: string, day: number)
	p.pearls += amount
	p.earned += amount
	p.sources[source] += amount
	spend(p, day)
end

local function rankMult(p: Player): number
	return GoalRules.rankMultiplier(p.rank)
end

local function addBanked(p: Player, base: number, day: number)
	p.banked += base
	local ranks = Index.ReefRanks.list
	while p.rank < #ranks and p.banked >= ranks[p.rank + 1].threshold do
		p.rank += 1
		pay(p, ranks[p.rank].reward, "oneTime", day)
	end
end

local function accrue(p: Player, now: number)
	p.pile, p.accruedAt = CoveIncome.accrue(
		p.pile,
		p.accruedAt,
		now,
		p.rate,
		p.lastClaimAt,
		CoveIncome.capHours(false)
	)
end

local function placeSpecimen(p: Player, now: number, tier: number, bonus: number, day: number)
	accrue(p, now) -- the old rate up to now (09 §13.2)
	local rate = CoveIncome.specimenRate(tier, {}) * (1 + bonus)
	table.insert(p.specimens, rate)
	if #p.specimens > p.slots then
		-- 05 §5.2 assumption 5: keep the best, release the worst for the refund.
		table.sort(p.specimens, function(a, b)
			return a > b
		end)
		local released = table.remove(p.specimens) :: number
		pay(p, CoveIncome.refund(released), "oneTime", day)
	end
	local total = 0
	for _, r in p.specimens do
		total += r
	end
	p.rate = total
	if not p.firstBank then
		p.firstBank = true
		pay(p, CoveIncome.firstBankReward(tier, {}), "cove", day)
	end
end

local function pickRun(p: Player, day: number, profile: Profile): string
	local shares = profile.mixes[1].shares
	for _, mix in profile.mixes do
		if day >= mix.from then
			shares = mix.shares
		end
	end
	local ids: { string } = {}
	for id in shares do
		table.insert(ids, id)
	end
	table.sort(ids)
	local total = 0
	for _, id in ids do
		total += shares[id] / EXPECTED_MINUTES[id]
	end
	local roll = Rng.next(p.rng) * total
	for _, id in ids do
		roll -= shares[id] / EXPECTED_MINUTES[id]
		if roll <= 0 then
			return id
		end
	end
	return ids[#ids]
end

local function playDay(p: Player, day: number, profile: Profile)
	local dayStart = (day - 1) * DAY
	-- Once a day: goals, streak, tide bonuses and the Codex.
	local mult = rankMult(p)
	local goals = 0
	local all = true
	for _, band in { "R1", "R2", "R3" } do
		if Rng.chance(p.rng, profile.goalShare) then
			goals += math.floor(Index.RewardBands.byId[band].pearls * mult + 1e-9)
		else
			all = false
		end
	end
	if all then
		goals += GoalRules.allDoneBonus(p.rank)
	end
	p.streakBox = p.streakBox % #STREAK + 1
	p.tideCarry += profile.tideBonuses
	local tides = math.floor(p.tideCarry)
	p.tideCarry -= tides
	local daily = goals
		+ math.floor(STREAK[p.streakBox] * mult + 1e-9)
		+ tides * math.floor(TIDE_BONUS * mult + 1e-9)
	local codexDue = math.floor(profile.codex * (1 - math.exp(-day / CODEX_DAYS)))

	for _, session in profile.sessions do
		local now = dayStart + session[1] * HOUR + p.jitter
		-- Claim on entering the cove (05 §5.2 assumption 9).
		accrue(p, now)
		local claimed, left = CoveIncome.claim(p.pile)
		p.pile = left
		p.lastClaimAt = now
		if claimed > 0 then
			pay(p, claimed, "cove", day)
		end
		local budget = p.carry + RUN_SHARE * session[2]
		while budget > 0 do
			local id = pickRun(p, day, profile)
			local rt = RUN_TYPES[id]
			local length = timeTo(now, rt.mass)
			local seconds, mass
			if Rng.chance(p.rng, rt.bank) then
				seconds, mass = length, rt.mass
				now += seconds
				addBanked(p, BankMath.bankRankPoints(mass, false), day)
				pay(p, BankMath.bank(mass, false, false), "banking", day)
				local tier = TierMath.tier(mass)
				if BankMath.keepsSpecimen(tier) then
					placeSpecimen(p, now, tier, rt.bonus, day)
				end
			else
				seconds = length * GULPED_AT
				mass = massAt(now, seconds)
				now += seconds
				local scraps = BankMath.scraps(mass, false, false, p.deaths)
				addBanked(p, BankMath.scrapsRankPoints(mass, false, p.deaths), day)
				p.deaths += 1
				pay(p, scraps, "banking", day)
			end
			p.playedMinutes += seconds / 60
			budget -= seconds / 60
		end
		p.carry = budget
		-- The day's goals, streak box, tide bonuses and Codex are earned during play: paid at
		-- the end of the first session.
		if session == profile.sessions[1] then
			pay(p, daily, "daily", day)
			pay(p, codexDue - p.codexPaid, "oneTime", day)
			p.codexPaid = codexDue
		end
	end
	p.byDay[day] = {
		earned = p.earned,
		rate = p.rate,
		slots = p.slots,
		rank = p.rank,
		balance = p.pearls,
		sources = table.clone(p.sources),
	}
end

---------------------------------------------------------------------------------------------
-- The cohorts.

local function percentile(values: { number }, q: number): number
	local sorted = table.clone(values)
	table.sort(sorted)
	return sorted[math.clamp(math.floor(q * (#sorted - 1) + 1.5), 1, #sorted)]
end

local function mean(values: { number }): number
	local total = 0
	for _, v in values do
		total += v
	end
	return total / math.max(1, #values)
end

type CohortDay = {
	earned: number,
	rate: number,
	slots: number,
	rank: number,
	pearls: number,
	balance: number,
	slotsMedian: number,
	rankMedian: number,
	bySource: { [string]: number },
}

type Cohort = {
	profile: Profile,
	unlock: { [string]: { median: number?, p10: number?, p90: number?, reached: number } },
	pufferMinute: number?,
	day: { [number]: CohortDay },
	slotMedian: { [number]: number? },
	sources: { [string]: number },
	maxRate: number,
}

local function runCohort(profile: Profile, index: number): Cohort
	local players: { Player } = {}
	for i = 1, PLAYERS do
		players[i] = newPlayer(Rng.new(SEED + index * 100003 + i))
	end
	for _, p in players do
		for day = 1, DAYS do
			playDay(p, day, profile)
		end
	end
	local unlock = {}
	for _, s in SPECIES_ORDER do
		local days: { number } = {}
		for _, p in players do
			table.insert(days, p.unlockDay[s.id] or math.huge)
		end
		local reached = 0
		for _, d in days do
			if d ~= math.huge then
				reached += 1
			end
		end
		local function q(x: number): number?
			local v = percentile(days, x)
			return if v == math.huge then nil else v
		end
		unlock[s.id] = { median = q(0.5), p10 = q(0.1), p90 = q(0.9), reached = reached }
	end
	local minutes: { number } = {}
	for _, p in players do
		if p.pufferMinute then
			table.insert(minutes, p.pufferMinute)
		end
	end
	local day = {}
	local maxRate = 0
	for d = 1, DAYS do
		local earned, rate, slots, rank, pearls, balance = {}, {}, {}, {}, {}, {}
		local bySource = { banking = 0, cove = 0, daily = 0, oneTime = 0 }
		for _, p in players do
			local row = p.byDay[d]
			local before = if d > 1 then p.byDay[d - 1].earned else 0
			table.insert(balance, row.balance)
			for k in bySource do
				local prev = if d > 1 then p.byDay[d - 1].sources[k] else 0
				bySource[k] += (row.sources[k] - prev) / PLAYERS
			end
			table.insert(earned, row.earned)
			table.insert(rate, row.rate)
			table.insert(slots, row.slots)
			table.insert(rank, row.rank)
			table.insert(pearls, row.earned - before)
			maxRate = math.max(maxRate, row.rate)
		end
		day[d] = {
			earned = mean(earned),
			rate = mean(rate),
			slots = mean(slots),
			rank = mean(rank),
			pearls = mean(pearls),
			balance = mean(balance),
			slotsMedian = percentile(slots, 0.5),
			rankMedian = percentile(rank, 0.5),
			bySource = bySource,
		}
	end
	local sources = { banking = 0, cove = 0, daily = 0, oneTime = 0 }
	for _, p in players do
		for k in sources do
			sources[k] += p.sources[k] / PLAYERS
		end
	end
	local slotMedian: { [number]: number? } = {}
	for slot = FREE_SLOTS + 1, Index.SlotPrices.list[#Index.SlotPrices.list].slot do
		local days: { number } = {}
		for _, p in players do
			table.insert(days, p.slotDay[slot] or math.huge)
		end
		local v = percentile(days, 0.5)
		slotMedian[slot] = if v == math.huge then nil else v
	end
	return {
		profile = profile,
		slotMedian = slotMedian,
		unlock = unlock,
		pufferMinute = if #minutes > 0 then percentile(minutes, 0.5) else nil,
		day = day,
		sources = sources,
		maxRate = maxRate,
	}
end

local started = os.clock()
local cohorts: { [string]: Cohort } = {}
for i, profile in PROFILES do
	cohorts[profile.name] = runCohort(profile, i)
end
local seconds = os.clock() - started

-- The cove's Pearls per hour can never pass 05 §6.2's ceiling: every Pearl slot (no pass) full of
-- the top tier with the three best trait bonuses.
local bonuses: { number } = {}
for _, t in Index.Traits.list do
	table.insert(bonuses, t.incomeBonus)
end
table.sort(bonuses, function(a, b)
	return a > b
end)
local topTier = Index.Tiers.list[#Index.Tiers.list]
local RATE_CEILING = Index.SlotPrices.list[#Index.SlotPrices.list].slot
	* (topTier.coveIncome :: number)
	* (1 + bonuses[1] + bonuses[2] + bonuses[3])

---------------------------------------------------------------------------------------------
-- The report.

local function fmt(n: number?, places: number?): string
	if n == nil then
		return `after day {DAYS}`
	end
	local text = string.format(`%.{places or 0}f`, n)
	local int, frac = string.match(text, "^(%-?%d+)(.*)$")
	local grouped = (int :: string)
		:reverse()
		:gsub("(%d%d%d)", "%1,")
		:reverse()
		:gsub("^(%-?),", "%1")
	return grouped .. (frac :: string)
end

local function off(value: number?, range: { number }): number
	if value == nil then
		return math.huge
	end
	if value < range[1] then
		return (range[1] - value) / range[1]
	elseif value > range[2] then
		return (value - range[2]) / range[2]
	end
	return 0
end

local lines: { string } = {}
local function out(text: string)
	table.insert(lines, text)
end
out(
	`economy.sim: {PLAYERS} players per profile, {DAYS} days, seed {SEED} ({string.format(
		"%.1f",
		seconds
	)} s)`
)
out("Time to each tier (minutes; mean over start times, Frenzy by TideClock):")
out("  Tier  Mass   Canon 5.1  Sim     Off     No Frenzy")
local tierOff: { [number]: number } = {}
for tier = 2, 7 do
	local need = Index.Tiers.byTier[tier].massNeeded
	local sim = meanTimeTo(need) / 60
	local calm = 0
	do
		local mass, t = 0, 0
		while mass < need do
			mass += MASS_PER_MIN[TierMath.tier(mass)] / 60
			t += 1
		end
		calm = t / 60
	end
	tierOff[tier] = (sim - TIER_TARGET[tier]) / TIER_TARGET[tier]
	out(
		string.format(
			"  %-5d %-6d %-10.1f %-7.2f %+6.0f%%  %.2f",
			tier,
			need,
			TIER_TARGET[tier],
			sim,
			tierOff[tier] * 100,
			calm
		)
	)
end
out("Run lengths from the growth model (05 §5.3 says A 4, B 7, C 12, D 20 minutes):")
out(
	string.format(
		"  A0 %.1f  A %.1f  B %.1f  C %.1f  D %.1f",
		LENGTH_MINUTES.A0,
		LENGTH_MINUTES.A,
		LENGTH_MINUTES.B,
		LENGTH_MINUTES.C,
		LENGTH_MINUTES.D
	)
)
out("Species unlock day (median, 10th to 90th percentile):")
out("  Species  Canon 7    Casual          Regular         Heavy")
for _, s in SPECIES_ORDER do
	local target = UNLOCK_TARGET[s.id]
	local cells: { string } = {}
	for _, profile in PROFILES do
		local u = cohorts[profile.name].unlock[s.id]
		table.insert(cells, string.format("%-15s", `{fmt(u.median)} ({fmt(u.p10)}-{fmt(u.p90)})`))
	end
	local canon = if target[1] == target[2] then `{target[1]}` else `{target[1]} or {target[2]}`
	out(string.format("  %-8s %-10s %s", s.id, canon, table.concat(cells, " ")))
end
local regular = cohorts[GATED]
out(`Pufferfish: median {fmt(regular.pufferMinute, 1)} minutes of play into day 1 (regular player)`)
out("Day 30 (means):  Earned    Pearls/day  Cove/h  Slots  Rank")
for _, profile in PROFILES do
	local d = cohorts[profile.name].day[REPORT_DAYS]
	out(
		string.format(
			"  %-14s %-9s %-11s %-7s %-6.1f %.1f",
			profile.name,
			fmt(d.earned),
			fmt(d.pearls),
			fmt(d.rate),
			d.slots,
			d.rank
		)
	)
end
out("Regular player's Pearls by source (05 §5.6 says cove 68%, banking 16%):")
do
	local s = regular.sources
	local total = s.banking + s.cove + s.daily + s.oneTime
	out(
		string.format(
			"  banking %.0f%%, cove %.0f%%, daily %.0f%%, one-time %.0f%% (to day %d)",
			s.banking / total * 100,
			s.cove / total * 100,
			s.daily / total * 100,
			s.oneTime / total * 100,
			DAYS
		)
	)
end
for id in OWNER_GAPS do
	out(
		`GAP (owner): {id} median day {fmt(regular.unlock[id].median)} against canon section 7; see OWNER_GAPS`
	)
end
out(
	`Day 1 earned (means): casual {fmt(cohorts.Casual.day[1].earned)}, regular {fmt(
		regular.day[1].earned
	)}, heavy {fmt(cohorts.Heavy.day[1].earned)}`
)
out(`Cove ceiling (05 §6.2): {fmt(RATE_CEILING)} Pearls/h; highest seen {fmt(regular.maxRate, 1)}`)
print(table.concat(lines, "\n"))

-- ECONOMY_SIM_TABLES=1 prints 05 §5.4's day tables (means; slots and rank are medians; an
-- unlock is listed on the median day it happens).
if process.env.ECONOMY_SIM_TABLES == "1" then
	-- Display names (canon section 7); SpeciesDef carries no name.
	local SPECIES_NAME: { [string]: string } = {
		puffer = "Pufferfish",
		eel = "Eel",
		turtle = "Sea Turtle",
		squid = "Squid",
		shark = "Shark Pup",
	}
	for _, profile in PROFILES do
		local c = cohorts[profile.name]
		local t = {
			`\n**{profile.name}**\n`,
			"| Day | Banking | Cove | Daily rewards | One-time | Total | Cumulative | Balance | Slots | Cove/h | Rank | Unlocks |",
			"|---|---|---|---|---|---|---|---|---|---|---|---|",
		}
		for d = 1, REPORT_DAYS do
			local row = c.day[d]
			local unlocks: { string } = {}
			for _, s in SPECIES_ORDER do
				if c.unlock[s.id].median == d then
					table.insert(unlocks, `**{SPECIES_NAME[s.id]}**`)
				end
			end
			for slot = FREE_SLOTS + 1, Index.SlotPrices.list[#Index.SlotPrices.list].slot do
				if c.slotMedian[slot] == d then
					table.insert(unlocks, `Slot {slot}`)
				end
			end
			local b = row.bySource
			table.insert(
				t,
				`| {d} | {fmt(b.banking)} | {fmt(b.cove)} | {fmt(b.daily)} | {fmt(b.oneTime)} | {fmt(
					row.pearls
				)} | {fmt(row.earned)} | {fmt(row.balance)} | {row.slotsMedian} | {fmt(row.rate)} | {row.rankMedian} | {table.concat(
					unlocks,
					", "
				)} |`
			)
		end
		print(table.concat(t, "\n"))
	end
	print("\nMilestones (median day):")
	for _, profile in PROFILES do
		local c = cohorts[profile.name]
		local parts: { string } = {}
		for _, slot in { 7, 10, 12, 15, 20, 25, 30 } do
			table.insert(parts, `slot {slot} {fmt(c.slotMedian[slot])}`)
		end
		print(`  {profile.name}: {table.concat(parts, ", ")}`)
	end
end

describe("economy.sim (09 §16.2, 05 §5)", function()
	it("reaches every tier within 25% of canon 5.1's time", function()
		for tier = 2, 7 do
			if math.abs(tierOff[tier]) > TIER_TOLERANCE then
				error(
					`tier {tier}: {string.format("%+.0f", tierOff[tier] * 100)}% off canon 5.1's {TIER_TARGET[tier]} minutes`
				)
			end
		end
	end)

	it("unlocks every species within 30% of canon section 7's day (regular player)", function()
		for _, s in SPECIES_ORDER do
			local u = regular.unlock[s.id]
			local miss = off(u.median, UNLOCK_TARGET[s.id])
			if OWNER_GAPS[s.id] then
				if miss <= UNLOCK_TOLERANCE then
					error(`{s.id}: the listed gap has closed; remove it from OWNER_GAPS`)
				end
			elseif miss > UNLOCK_TOLERANCE then
				error(
					`{s.id}: median day {fmt(u.median)} is {if miss == math.huge
						then "never reached"
						else string.format("%.0f%%", miss * 100)} off canon section 7`
				)
			end
		end
	end)

	it("keeps Pearls per hour bounded", function()
		for _, profile in PROFILES do
			expect(cohorts[profile.name].maxRate <= RATE_CEILING).toBe(true)
		end
		-- Daily Pearls of the regular player grow more slowly in the last week than in the second.
		local d = regular.day
		local early = d[14].pearls - d[7].pearls
		local late = d[REPORT_DAYS].pearls - d[REPORT_DAYS - 7].pearls
		if late >= early then
			error(
				`daily Pearls grew {fmt(late)} in days 23 to 30 against {fmt(early)} in days 7 to 14`
			)
		end
	end)

	it("is deterministic for the seed", function()
		local again = runCohort(PROFILES[1], 1)
		local first = cohorts[PROFILES[1].name]
		expect(again.day[REPORT_DAYS].earned).toBe(first.day[REPORT_DAYS].earned)
	end)
end)
