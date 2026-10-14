--!strict
-- prey_soak (docs/09, section 16.2): PreySim, PreySpawner and PreyInterest for 10 simulated
-- minutes at 10 Hz with 24 scripted swimmers on the full map and one Feeding Frenzy, driven the
-- way PreyService drives them (8.4: threats, step, interest and send per player, spawn pass).
--
-- Map. The spawn areas tile the data:ZoneAreas shapes of docs/03 §6 (Nursery oval 220 × 170 in
-- the Reef's south-west, Reef disc r 400 at the centre, Kelp half ring r 560 to 1,000 on the
-- north-west side, Drop-off the same ring on the south-east side), so areaScale is 1 and the
-- targets are 02 §9.6's whole-map numbers (09 §8.1's load), not the CI arena's.
-- Swimmers. Two packs (6 in the Reef, 4 in the Kelp) hunt around a wandering anchor; 8 roam from
-- area to area across every zone; 6 dash across the map (3 s at dash speed, 2 s at cruise).
-- Every swimmer bites the nearest edible prey within reach (tier ≤ its own, faded in), then
-- spends that catch's seconds from 05 §2.2 before the next, through PreySim.clearMember and PreySpawner.onEaten, as PreyService.tryEat does.
-- Frenzy. 02 §14.2 and §14.4: T+0 at FRENZY_AT, rules off 240 s later; PreySpawner.setTide("frenzy")
-- (spawnRateMult 3 divides respawn delays; the frenzy tide doubles normal prey targets). Its
-- eventPrey list is empty, so the soak adds the worst case 09 §8.1 leaves room for: Moon Tide's
-- lunar_fry event (PreyDef.alive = 12 animals at once, 3 groups of 4, topped up to eventTotal)
-- for the Frenzy's length, cleared at its end.
--
-- Fails (16.2): live members outside 60% to 160% of target; a group outside its leash (1.5 × its
-- home's radius and half height, 8.4 step 4); bytes per player per second above 9,000 in any
-- one-second window or above 4,500 averaged over the run or over the Frenzy; a packet above 900
-- bytes; the Frenzy not reaching about the Frenzy count of 8.1 (the budgets must be proved there).
-- Population while the target moves: 02 §14.4 doubles the target at T+0 (the refill takes time)
-- and keeps the surplus at T+240 (the 150% rule trims it), so for SETTLE seconds after a target
-- step the band is applied to the envelope of the old and new targets; outside those windows it
-- is applied to the current target as written. Both ratios are printed.
-- Timing. 16.2's step (2.0 ms per tick) and interest (0.25 ms per player per tick) budgets are
-- `os.clock` in Lune, a proxy for the engine: printed, not asserted (15.5's bot soak confirms).
-- Length. PREY_SOAK_SECONDS overrides the 600 s (the Frenzy moves to keep its place); CI runs the
-- full 600 s.
local process = require("@lune/process")

local Formation = require("../../src/shared/Sim/Formation")
local Index = require("../../src/shared/Data/Index")
local PreyInterest = require("../../src/shared/Logic/PreyInterest")
local PreySim = require("../../src/shared/Sim/PreySim")
local PreySpawner = require("../../src/shared/Logic/PreySpawner")
local PreyState = require("../../src/shared/Net/Codec/PreyState")
local Rng = require("../../src/shared/Util/Rng")
local SwimModel = require("../../src/shared/Sim/SwimModel")
local TestKit = require("../../src/shared/Util/TestKit")
local Types = require("../../src/shared/Types")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type PreyDef = Types.PreyDef

-- Harness parameters (test inputs, not game tunables).
local SEED = 0x50AC
local TICK = 0.1
local SECONDS = tonumber(process.env.PREY_SOAK_SECONDS) or 600
local TICKS = math.floor(SECONDS / TICK + 0.5)
local FRENZY_AT = math.floor(SECONDS * 0.3) -- T+0 of the Frenzy, s
local FRENZY_LENGTH = math.min(240, math.floor(SECONDS * 0.4)) -- 02 §14.2
local SETTLE = 60 -- s after a target step in which the population band uses the envelope
local PLAYERS = 24
-- Seconds a catch costs (05 §2.2, for prey one tier below the eater; ×1.6 for the eater's own
-- tier, ×0.8 two or more below). Trait prey are not in that table: CATCH_OTHER.
local CATCH_SECONDS: { [string]: number } = {
	plankton = 1.0,
	krill = 1.7,
	shrimp = 4.0,
	sardine = 9.0,
	darter = 11.0,
	mackerel = 16.0,
	bonito = 24.0,
	tuna = 45.0,
}
local CATCH_OTHER = 8.0
local BITE_REACH = 10 -- studs from the swimmer to a group's centre
local HUNT_RADIUS = 120 -- studs: packs chase prey this close to their anchor
local LEASH_EPS = 0.05 -- studs of f32 slack on the leash check
local EVENT_PREY = "lunar_fry"
-- 16.2 limits.
local POP_LOW, POP_HIGH = 0.6, 1.6
local PEAK_BYTES, AVG_BYTES = 9000, 4500
local FRENZY_GROUPS, FRENZY_MEMBERS = 545, 2710 -- 09 §8.1, the Frenzy count
local FRENZY_REACH = 0.9 -- the Frenzy must reach this share of the Frenzy count
-- 15.2 budgets (advisory in Lune).
local SIM_BUDGET_MS, INTEREST_BUDGET_MS = 2.0, 0.25

local frenzyTide = Index.Tides.byId.frenzy
assert(frenzyTide, "prey_soak: no frenzy tide in the data")

------------------------------------------------------------------------------------------------
-- The map (docs/03 data:ZoneAreas and the top-down map of §6).

local NURSERY_X, NURSERY_Z, NURSERY_A, NURSERY_B = -210, 230, 110, 85
local REEF_R, RIM_SPLIT, RING_IN, RING_OUT = 400, 480, 560, 1000
local KELP_DIR = math.atan2(-1, -1) -- north-west (−Z is north): angle of (x, z)

local function zoneAt(x: number, _y: number, z: number): string
	local nx, nz = (x - NURSERY_X) / NURSERY_A, (z - NURSERY_Z) / NURSERY_B
	if nx * nx + nz * nz <= 1 then
		return "nursery"
	end
	if math.sqrt(x * x + z * z) <= RIM_SPLIT then
		return "reef"
	end
	local d = math.atan2(z, x) - KELP_DIR
	d = (d + math.pi) % (2 * math.pi) - math.pi
	return if math.abs(d) <= math.pi / 2 then "kelp" else "dropoff"
end

local function buildMap(sp: PreySpawner.Spawner)
	PreySpawner.addArea(sp, "nursery", NURSERY_X, -30, NURSERY_Z, NURSERY_B, 15, nil)
	PreySpawner.addArea(sp, "reef", 0, -50, 0, 140, 35, nil)
	for i = 0, 5 do
		local a = i * math.pi / 3 + math.pi / 6
		PreySpawner.addArea(sp, "reef", math.cos(a) * 255, -50, math.sin(a) * 255, 140, 35, nil)
	end
	local ringMid = (RING_IN + RING_OUT) / 2
	for _, zone in { "kelp", "dropoff" } do
		local base = if zone == "kelp" then KELP_DIR else KELP_DIR + math.pi
		local cy, half = if zone == "kelp" then -70 else -170, if zone == "kelp" then 55 else 120
		for i = 0, 6 do
			local a = base - math.pi / 2 + (i + 0.5) * math.pi / 7
			PreySpawner.addArea(
				sp,
				zone,
				math.cos(a) * ringMid,
				cy,
				math.sin(a) * ringMid,
				200,
				half,
				nil
			)
		end
	end
	sp.zoneAt = zoneAt
	PreySpawner.build(sp)
end

------------------------------------------------------------------------------------------------
-- Swimmers.

type Swimmer = {
	role: string, -- "pack", "roam", "dash"
	tier: number,
	cruise: number,
	dash: number,
	x: number,
	y: number,
	z: number,
	tx: number,
	ty: number,
	tz: number,
	pack: number, -- pack index for "pack"
	ox: number, -- offset from the pack anchor
	oz: number,
	dashUntil: number,
	cycleAt: number,
	biteAt: number,
	bites: number,
}

type Anchor = { x: number, y: number, z: number, tx: number, ty: number, tz: number, zone: string }

local function pointIn(rng: Rng.Rng, a: PreySpawner.Area): (number, number, number)
	local angle = Rng.range(rng, 0, 2 * math.pi)
	local r = a.radius * math.sqrt(Rng.next(rng))
	return a.cx + math.cos(angle) * r,
		a.cy + Rng.range(rng, -0.8, 0.8) * a.halfHeight,
		a.cz + math.sin(angle) * r
end

local function areaOf(rng: Rng.Rng, sp: PreySpawner.Spawner, zone: string?): PreySpawner.Area
	local list = {}
	for _, a in sp.areas do
		if zone == nil or a.zone == zone then
			table.insert(list, a)
		end
	end
	return list[Rng.int(rng, 1, #list)]
end

-- Moves (x, y, z) toward (tx, ty, tz) by at most `step`; returns the new point and whether it
-- arrived.
local function moveToward(
	x: number,
	y: number,
	z: number,
	tx: number,
	ty: number,
	tz: number,
	step: number
): (number, number, number, boolean)
	local dx, dy, dz = tx - x, ty - y, tz - z
	local d = math.sqrt(dx * dx + dy * dy + dz * dz)
	if d <= step then
		return tx, ty, tz, true
	end
	local s = step / d
	return x + dx * s, y + dy * s, z + dz * s, false
end

------------------------------------------------------------------------------------------------
-- The run.

export type Result = {
	ticks: number,
	-- Population, sampled once a second after the pass.
	popStrictMin: number,
	popStrictMax: number,
	popEnvelopeMin: number,
	popEnvelopeMax: number,
	popBad: number, -- seconds outside the band (strict outside SETTLE, envelope inside)
	popBack: { number }, -- per target step: seconds until live ÷ target is back in 0.6..1.6
	popFirstBad: string?,
	normalTarget: number,
	normalMembers: number,
	normalGroups: number,
	frenzyTarget: number,
	frenzyPeakMembers: number,
	frenzyPeakGroups: number,
	frenzyEventGroups: number,
	finalMembers: number,
	finalGroups: number,
	leashBreaks: number,
	leashWorst: number, -- distance over the clamp, studs
	-- Bytes.
	maxPacket: number,
	packets: number,
	peakBytes: number, -- worst one-second window of any player
	avgBytes: number, -- worst player's average over the run
	frenzyAvgBytes: number, -- worst player's average over the Frenzy
	meanAvgBytes: number, -- mean of the players' averages over the run
	deferredTicks: number, -- player ticks with records left for the next tick
	-- Eating.
	bites: number,
	-- Timing (Lune os.clock, ms).
	simMean: number,
	simP99: number,
	simMax: number,
	simFrenzyMean: number,
	interestMean: number,
	interestP99: number,
	interestMax: number,
	interestFrenzyMean: number,
	wall: number,
	packetSizes: { number }, -- for the determinism check: every packet size in order, slot 1
}

local function percentile(samples: { number }, p: number): number
	local sorted = table.clone(samples)
	table.sort(sorted)
	return sorted[math.max(1, math.ceil(#sorted * p))] or 0
end

local function run(seed: number): Result
	local started = os.clock()
	local rng = Rng.new(seed)
	local sim = PreySim.new(seed + 1)
	local sp = PreySpawner.new(sim, seed + 2)
	local interest = PreyInterest.new(PLAYERS)
	sp.onRemoved = function(g: number, _gen: number)
		PreyInterest.forget(interest, g)
	end
	buildMap(sp)

	-- Swimmers and pack anchors.
	local anchors: { Anchor } = {}
	for _, zone in { "reef", "kelp" } do
		local x, y, z = pointIn(rng, areaOf(rng, sp, zone))
		table.insert(anchors, { x = x, y = y, z = z, tx = x, ty = y, tz = z, zone = zone })
	end
	local speciesList = Index.Species.list
	local swimmers: { Swimmer } = {}
	for i = 1, PLAYERS do
		local role = if i <= 10 then "pack" elseif i <= 18 then "roam" else "dash"
		local tier = Rng.int(rng, 2, 6)
		local species = speciesList[(i - 1) % #speciesList + 1]
		local pack = if i <= 6 then 1 else 2
		local a = if role == "pack" then anchors[pack] else nil
		local x, y, z
		if a then
			x, y, z = a.x, a.y, a.z
		else
			x, y, z = pointIn(rng, areaOf(rng, sp, nil))
		end
		table.insert(swimmers, {
			role = role,
			tier = tier,
			cruise = SwimModel.topSpeed(tier, species, 1),
			dash = SwimModel.dashSpeed(tier, species, 1),
			x = x,
			y = y,
			z = z,
			tx = x,
			ty = y,
			tz = z,
			pack = pack,
			ox = Rng.range(rng, -40, 40),
			oz = Rng.range(rng, -40, 40),
			dashUntil = 0,
			cycleAt = Rng.range(rng, 0, 5),
			biteAt = 0,
			bites = 0,
		})
	end
	local px, py, pz = table.create(PLAYERS, 0), table.create(PLAYERS, 0), table.create(PLAYERS, 0)
	local function syncPositions()
		for i, s in swimmers do
			px[i], py[i], pz[i] = s.x, s.y, s.z
		end
	end
	syncPositions()

	local function setPlayers()
		local inside: { [string]: number } = {}
		for _, s in swimmers do
			local zone = zoneAt(s.x, s.y, s.z)
			inside[zone] = (inside[zone] or 0) + 1
		end
		PreySpawner.setPlayers(sp, PLAYERS, inside)
	end
	setPlayers()
	PreySpawner.fill(sp, 0, px, py, pz, PLAYERS)

	local result: Result = {
		ticks = TICKS,
		popStrictMin = math.huge,
		popStrictMax = 0,
		popEnvelopeMin = math.huge,
		popEnvelopeMax = 0,
		popBad = 0,
		popBack = {},
		popFirstBad = nil,
		normalTarget = PreySpawner.targetMembers(sp),
		normalMembers = 0,
		normalGroups = 0,
		frenzyTarget = 0,
		frenzyPeakMembers = 0,
		frenzyPeakGroups = 0,
		frenzyEventGroups = 0,
		finalMembers = 0,
		finalGroups = 0,
		leashBreaks = 0,
		leashWorst = 0,
		maxPacket = 0,
		packets = 0,
		peakBytes = 0,
		avgBytes = 0,
		frenzyAvgBytes = 0,
		meanAvgBytes = 0,
		deferredTicks = 0,
		bites = 0,
		simMean = 0,
		simP99 = 0,
		simMax = 0,
		simFrenzyMean = 0,
		interestMean = 0,
		interestP99 = 0,
		interestMax = 0,
		interestFrenzyMean = 0,
		wall = 0,
		packetSizes = {},
	}
	result.normalMembers, result.normalGroups = PreySpawner.liveMembers(sp)

	local windowBytes = table.create(PLAYERS, 0)
	local totalBytes = table.create(PLAYERS, 0)
	local frenzyBytes = table.create(PLAYERS, 0)
	local simTimes: { number } = table.create(TICKS)
	local interestTimes: { number } = table.create(TICKS * PLAYERS)
	local simFrenzy, simFrenzyN, interestFrenzy, interestFrenzyN = 0, 0, 0, 0
	local prevTarget = result.normalTarget
	local lastTargetStep = -math.huge
	local queryOut: { number } = {}
	local b = sim.buffers
	local frenzyEnd = FRENZY_AT + FRENZY_LENGTH

	-- One bite for a swimmer: the nearest edible group centre within reach.
	local function tryBite(s: Swimmer, now: number)
		if now < s.biteAt then
			return
		end
		local n = PreySim.query(sim, s.x, s.z, BITE_REACH, queryOut)
		local best, bestD2 = -1, BITE_REACH * BITE_REACH
		for k = 1, n do
			local g = queryOut[k]
			local def = Formation.defOf(buffer.readu8(b.kind, g))
			if def == nil or def.tier > s.tier or not PreySpawner.edibleAt(sp, g, now) then
				continue
			end
			local o4 = g * 4
			local dx = buffer.readf32(b.posX, o4) - s.x
			local dy = buffer.readf32(b.posY, o4) - s.y
			local dz = buffer.readf32(b.posZ, o4) - s.z
			local d2 = dx * dx + dy * dy + dz * dz
			if d2 < bestD2 then
				best, bestD2 = g, d2
			end
		end
		if best < 0 then
			return
		end
		for m = 0, buffer.readu8(b.count, best) - 1 do
			if PreySim.memberAlive(sim, best, m) then
				PreySim.clearMember(sim, best, m)
				local def = Formation.defOf(buffer.readu8(b.kind, best)) :: PreyDef
				local below = s.tier - def.tier -- creature tier 2 eats krill (tier 1) as "one below"
				local cost = (CATCH_SECONDS[def.id] or CATCH_OTHER)
					* (if below <= 0 then 1.6 elseif below >= 2 then 0.8 else 1)
				PreySpawner.onEaten(sp, best, now)
				s.biteAt = now + cost
				s.bites += 1
				result.bites += 1
				return
			end
		end
	end

	-- The nearest edible group to (x, z) within r, or nil.
	local function nearestPrey(s: Swimmer, x: number, z: number, r: number): number?
		local n = PreySim.query(sim, x, z, r, queryOut)
		local best: number?, bestD2 = nil, r * r
		for k = 1, n do
			local g = queryOut[k]
			local def = Formation.defOf(buffer.readu8(b.kind, g))
			if def == nil or def.tier > s.tier then
				continue
			end
			local o4 = g * 4
			local dx = buffer.readf32(b.posX, o4) - x
			local dz = buffer.readf32(b.posZ, o4) - z
			local d2 = dx * dx + dz * dz
			if d2 < bestD2 then
				best, bestD2 = g, d2
			end
		end
		return best
	end

	local function moveSwimmers(now: number)
		for _, a in anchors do
			local arrived
			a.x, a.y, a.z, arrived = moveToward(a.x, a.y, a.z, a.tx, a.ty, a.tz, 6 * TICK)
			if arrived then
				a.tx, a.ty, a.tz = pointIn(rng, areaOf(rng, sp, a.zone))
			end
		end
		for _, s in swimmers do
			local speed = s.cruise
			if s.role == "pack" then
				-- Hunt near the anchor: chase the nearest edible group, dash when close.
				local a = anchors[s.pack]
				local g = nearestPrey(s, a.x + s.ox, a.z + s.oz, HUNT_RADIUS)
				if g then
					local o4 = g * 4
					s.tx = buffer.readf32(b.posX, o4)
					s.ty = buffer.readf32(b.posY, o4)
					s.tz = buffer.readf32(b.posZ, o4)
					local dx, dz = s.tx - s.x, s.tz - s.z
					if dx * dx + dz * dz < 40 * 40 then
						speed = s.dash
					end
				else
					s.tx, s.ty, s.tz = a.x + s.ox, a.y, a.z + s.oz
				end
			elseif s.role == "roam" then
				-- Area to area across the map, snapping at prey met on the way.
				local g = nearestPrey(s, s.x, s.z, 25)
				if g then
					local o4 = g * 4
					s.tx = buffer.readf32(b.posX, o4)
					s.ty = buffer.readf32(b.posY, o4)
					s.tz = buffer.readf32(b.posZ, o4)
				end
			else
				-- Dash 3 s, cruise 2 s, on long straight runs across the map.
				if now >= s.cycleAt then
					s.dashUntil = now + 3
					s.cycleAt = now + 5
				end
				if now < s.dashUntil then
					speed = s.dash
				end
			end
			local arrived
			s.x, s.y, s.z, arrived = moveToward(s.x, s.y, s.z, s.tx, s.ty, s.tz, speed * TICK)
			if arrived and s.role ~= "pack" then
				s.tx, s.ty, s.tz = pointIn(rng, areaOf(rng, sp, nil))
			end
			tryBite(s, now)
		end
	end

	for tick = 1, TICKS do
		local now = tick * TICK
		local second = math.floor(now + 1e-6)
		local frenzy = now >= FRENZY_AT and now < frenzyEnd

		-- Tide.
		if math.abs(now - FRENZY_AT) < 1e-6 then
			PreySpawner.setTide(sp, frenzyTide.id)
			for _, id in frenzyTide.eventPrey do
				PreySpawner.startEvent(sp, id, now, px, py, pz, PLAYERS)
			end
			result.frenzyEventGroups =
				PreySpawner.startEvent(sp, EVENT_PREY, now, px, py, pz, PLAYERS)
		elseif math.abs(now - frenzyEnd) < 1e-6 then
			PreySpawner.setTide(sp, nil)
			PreySpawner.clearEvents(sp, now)
		end

		-- Frame 0: threats and the step.
		moveSwimmers(now)
		syncPositions()
		for i, s in swimmers do
			PreySim.setThreat(sim, i - 1, s.x, s.y, s.z, s.tier, PreySim.THREAT_PLAYER)
		end
		PreySim.setThreatCount(sim, PLAYERS)
		local t0 = os.clock()
		PreySim.step(sim, now, TICK)
		local ms = (os.clock() - t0) * 1000
		table.insert(simTimes, ms)
		if frenzy then
			simFrenzy += ms
			simFrenzyN += 1
		end

		-- Frames 0 to 5: interest and send for every player.
		for slot = 1, PLAYERS do
			t0 = os.clock()
			local payload =
				PreyInterest.updatePlayer(interest, sim, slot, px[slot], py[slot], pz[slot])
			ms = (os.clock() - t0) * 1000
			table.insert(interestTimes, ms)
			if frenzy then
				interestFrenzy += ms
				interestFrenzyN += 1
			end
			if interest.lastDeferred[slot] > 0 then
				result.deferredTicks += 1
			end
			if payload then
				local size = buffer.len(payload)
				result.packets += 1
				result.maxPacket = math.max(result.maxPacket, size)
				windowBytes[slot] += size
				totalBytes[slot] += size
				if frenzy then
					frenzyBytes[slot] += size
				end
				if slot == 1 then
					table.insert(result.packetSizes, size)
				end
			end
		end

		-- Frame 3: the spawn pass, once a second.
		if now >= sp.nextPass - 1e-6 then
			setPlayers()
		end
		PreySpawner.pass(sp, now, px, py, pz, PLAYERS)

		-- Once a second: bytes window, population, leash.
		if tick % 10 == 0 then
			for slot = 1, PLAYERS do
				result.peakBytes = math.max(result.peakBytes, windowBytes[slot])
				windowBytes[slot] = 0
			end
			local target = PreySpawner.targetMembers(sp)
			if math.abs(target - prevTarget) > 0.25 * prevTarget then
				lastTargetStep = second
				table.insert(result.popBack, -1)
			end
			local members, groups = PreySpawner.liveMembers(sp)
			local ratio = members / target
			local steps = #result.popBack
			if
				steps > 0
				and result.popBack[steps] < 0
				and ratio >= POP_LOW
				and ratio <= POP_HIGH
			then
				result.popBack[steps] = second - lastTargetStep
			end
			result.popStrictMin = math.min(result.popStrictMin, ratio)
			result.popStrictMax = math.max(result.popStrictMax, ratio)
			local low, high = target, target
			if second - lastTargetStep < SETTLE then
				local lo, hi = result.normalTarget, result.frenzyTarget
				if hi == 0 then
					hi = target
				end
				low, high = math.min(lo, hi, target), math.max(lo, hi, target)
				result.popEnvelopeMin = math.min(result.popEnvelopeMin, members / low)
				result.popEnvelopeMax = math.max(result.popEnvelopeMax, members / high)
			end
			if members < POP_LOW * low or members > POP_HIGH * high then
				result.popBad += 1
				if result.popFirstBad == nil then
					result.popFirstBad = string.format(
						"t=%d s: %d members, target %.0f (band %.0f to %.0f)",
						second,
						members,
						target,
						POP_LOW * low,
						POP_HIGH * high
					)
				end
			end
			if not frenzy and second < FRENZY_AT then
				result.normalTarget = target
			end
			if frenzy then
				result.frenzyTarget = math.max(result.frenzyTarget, target)
				result.frenzyPeakMembers = math.max(result.frenzyPeakMembers, members)
				result.frenzyPeakGroups = math.max(result.frenzyPeakGroups, groups)
			end
			prevTarget = target

			for g = 0, PreySim.MAX_GROUPS - 1 do
				if buffer.readu8(b.kind, g) == 0 then
					continue
				end
				local h = buffer.readu16(b.home, g * 2) * 20
				local cx, cy, cz =
					buffer.readf32(sim.homes, h),
					buffer.readf32(sim.homes, h + 4),
					buffer.readf32(sim.homes, h + 8)
				local radius, half =
					buffer.readf32(sim.homes, h + 12), buffer.readf32(sim.homes, h + 16)
				local o4 = g * 4
				local dx, dz = buffer.readf32(b.posX, o4) - cx, buffer.readf32(b.posZ, o4) - cz
				local over = math.max(
					math.sqrt(dx * dx + dz * dz) - 1.5 * radius,
					math.abs(buffer.readf32(b.posY, o4) - cy) - 1.5 * half
				)
				if over > LEASH_EPS then
					result.leashBreaks += 1
				end
				result.leashWorst = math.max(result.leashWorst, over)
			end
		end
	end

	result.finalMembers, result.finalGroups = PreySpawner.liveMembers(sp)
	local sum = 0
	for slot = 1, PLAYERS do
		local avg = totalBytes[slot] / SECONDS
		sum += avg
		result.avgBytes = math.max(result.avgBytes, avg)
		result.frenzyAvgBytes = math.max(result.frenzyAvgBytes, frenzyBytes[slot] / FRENZY_LENGTH)
	end
	result.meanAvgBytes = sum / PLAYERS
	local simSum, interestSum = 0, 0
	for _, v in simTimes do
		simSum += v
		result.simMax = math.max(result.simMax, v)
	end
	for _, v in interestTimes do
		interestSum += v
		result.interestMax = math.max(result.interestMax, v)
	end
	result.simMean = simSum / #simTimes
	result.simP99 = percentile(simTimes, 0.99)
	result.simFrenzyMean = if simFrenzyN > 0 then simFrenzy / simFrenzyN else 0
	result.interestMean = interestSum / #interestTimes
	result.interestP99 = percentile(interestTimes, 0.99)
	result.interestFrenzyMean = if interestFrenzyN > 0 then interestFrenzy / interestFrenzyN else 0
	result.wall = os.clock() - started
	return result
end

local r = run(SEED)

local function row(name: string, value: string, limit: string, ok: boolean?)
	local verdict = if ok == nil then "info" elseif ok then "ok" else "FAIL"
	print(string.format("  %-34s %14s  %-22s %s", name, value, limit, verdict))
end

print(
	string.format(
		"prey_soak: %d s at 10 Hz, %d swimmers, Frenzy T+%d s for %d s (seed %d)",
		SECONDS,
		PLAYERS,
		FRENZY_AT,
		FRENZY_LENGTH,
		SEED
	)
)
row(
	"normal target / live members",
	string.format("%.0f / %d", r.normalTarget, r.normalMembers),
	"",
	nil
)
row("normal live groups", tostring(r.normalGroups), "", nil)
row("Frenzy target members", string.format("%.0f", r.frenzyTarget), "", nil)
row(
	"Frenzy peak members / groups",
	string.format("%d / %d", r.frenzyPeakMembers, r.frenzyPeakGroups),
	string.format("~%d / ~%d (8.1)", FRENZY_MEMBERS, FRENZY_GROUPS),
	r.frenzyPeakGroups >= FRENZY_REACH * FRENZY_GROUPS
)
row("event groups in the Frenzy", tostring(r.frenzyEventGroups), "", nil)
row("final members / groups", string.format("%d / %d", r.finalMembers, r.finalGroups), "", nil)
row(
	"live / target, strict min..max",
	string.format("%.2f..%.2f", r.popStrictMin, r.popStrictMax),
	"info (steps at T+0, T+240)",
	nil
)
row(
	"after a step: live/lower, live/upper",
	string.format("%.2f, %.2f", r.popEnvelopeMin, r.popEnvelopeMax),
	"≥ 0.60, ≤ 1.60",
	nil
)
local back = {}
for _, v in r.popBack do
	table.insert(back, if v < 0 then "never" else `{v}`)
end
row(
	"s back in band after T+0, T+240",
	table.concat(back, ", "),
	string.format("< %d (SETTLE)", SETTLE),
	nil
)
row("seconds outside the band", tostring(r.popBad), "0", r.popBad == 0)
row(
	"leash breaks (worst over, studs)",
	string.format("%d (%.3f)", r.leashBreaks, r.leashWorst),
	"0",
	r.leashBreaks == 0
)
row("bites", tostring(r.bites), "", nil)
row(
	"packets / largest (B)",
	string.format("%d / %d", r.packets, r.maxPacket),
	string.format("≤ %d", PreyState.MAX_BYTES),
	r.maxPacket <= PreyState.MAX_BYTES
)
row(
	"peak B per player per s",
	tostring(r.peakBytes),
	string.format("≤ %d", PEAK_BYTES),
	r.peakBytes <= PEAK_BYTES
)
row(
	"avg B/s, worst player (run)",
	string.format("%.0f", r.avgBytes),
	string.format("≤ %d", AVG_BYTES),
	r.avgBytes <= AVG_BYTES
)
row(
	"avg B/s, worst player (Frenzy)",
	string.format("%.0f", r.frenzyAvgBytes),
	string.format("≤ %d", AVG_BYTES),
	r.frenzyAvgBytes <= AVG_BYTES
)
row(
	"avg B/s, mean of players (run)",
	string.format("%.0f", r.meanAvgBytes),
	"2,500..4,000 (8.6)",
	nil
)
row("player ticks with deferred records", tostring(r.deferredTicks), "", nil)
row(
	"sim ms/tick mean / p99 / max",
	string.format("%.3f/%.3f/%.3f", r.simMean, r.simP99, r.simMax),
	string.format("≤ %.1f (advisory)", SIM_BUDGET_MS),
	nil
)
row(
	"sim ms/tick, Frenzy mean",
	string.format("%.3f", r.simFrenzyMean),
	string.format("≤ %.1f (advisory)", SIM_BUDGET_MS),
	nil
)
row(
	"interest ms/player mean/p99/max",
	string.format("%.3f/%.3f/%.3f", r.interestMean, r.interestP99, r.interestMax),
	string.format("≤ %.2f (advisory)", INTEREST_BUDGET_MS),
	nil
)
row(
	"interest ms/player, Frenzy mean",
	string.format("%.3f", r.interestFrenzyMean),
	string.format("≤ %.2f (advisory)", INTEREST_BUDGET_MS),
	nil
)
row("wall time (s)", string.format("%.1f", r.wall), "", nil)
if r.popFirstBad then
	print("  first population miss: " .. r.popFirstBad)
end

describe("prey_soak (09 §16.2)", function()
	it("keeps live members within 60% to 160% of target", function()
		expect(r.popBad).toBe(0)
	end)

	it("keeps every group inside its leash", function()
		expect(r.leashBreaks).toBe(0)
	end)

	it("reaches the Frenzy count of 8.1, so the budgets are proved there", function()
		expect(r.frenzyPeakGroups >= FRENZY_REACH * FRENZY_GROUPS).toBe(true)
		expect(r.frenzyPeakMembers >= FRENZY_REACH * FRENZY_MEMBERS).toBe(true)
		expect(r.frenzyPeakGroups <= PreySim.MAX_GROUPS).toBe(true)
	end)

	it("never sends a packet over 900 bytes", function()
		expect(r.maxPacket <= PreyState.MAX_BYTES).toBe(true)
	end)

	it("keeps bytes per player under 9,000 per second peak", function()
		expect(r.peakBytes <= PEAK_BYTES).toBe(true)
	end)

	it("keeps bytes per player under 4,500 per second on average, Frenzy included", function()
		expect(r.avgBytes <= AVG_BYTES).toBe(true)
		expect(r.frenzyAvgBytes <= AVG_BYTES).toBe(true)
	end)

	it("lets the swimmers eat", function()
		expect(r.bites > PLAYERS * 10).toBe(true)
	end)

	it("is deterministic for a seed", function()
		local again = run(SEED)
		expect(again.packetSizes).toEqual(r.packetSizes)
		expect(again.bites).toBe(r.bites)
		expect(again.finalMembers).toBe(r.finalMembers)
	end)
end)
