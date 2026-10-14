--!strict
-- PreySpawner: the spawn and despawn policy of the prey groups (docs/02, sections 9.2, 9.5 and
-- 9.6; docs/03, sections 2.1, 2.3 and 3.1; docs/09, section 8.4, frame 3). Pure: it drives a
-- PreySim and never touches the engine, so the soak (tests/sim/prey_soak.sim.luau) and PreyService
-- share it.
--
--   Areas.  A spawn area is a vertical cylinder in one zone (a PreySpawn volume, or a Zone volume
--           where a zone has none). Each area is one PreySim home, so groups wander and are
--           leashed inside the area they were spawned in.
--   Rows.   One row per (zone, prey): normal prey from data:PreySpawns through PreySpawnMath
--           (playerScale, the Nursery's per-player rule, Frenzy ×2, areaScale), trait prey from
--           data:TraitPreySpawns (02 §9.6; no playerScale or eventScale, areaScale applies). A
--           row's respawn delay is its prey's `PreyDef.respawn` (03 §2.1, §3.1; 02 §9.5).
--   Pass.   `pass` runs on the first tick at or after each whole second since the last pass, so
--           every 10th tick (02 §9.5, 09 §8.4 frame 3). Per row below target whose respawn delay
--           has run, it spawns one whole group (three in a Feeding Frenzy: the tide's
--           spawnRateMult, 02 §14.4) at a point of one of the row's areas with no player within
--           60 studs (the farthest of 4 tries otherwise). Stragglers (a swarm or school down to two
--           members, 02 §9.2) leave after 10 s with no player within 80 studs and no longer count,
--           so the school respawns whole. A row above 150% of target (after a Frenzy) loses its
--           groups that have no player within 80 studs, 10 per second in all. The crystal_jelly
--           drift (one group of `alive` members) appears every `respawn` s, counted from when the
--           last one appeared, and leaves `lifetime` s after it appeared (03 §3.1).
--   Tide.   `setTide(tideId?)`: respawn delays of normal prey are divided by the tide's
--           spawnRateMult (canon data:Tides), which is also the spawns per row per pass. Only the
--           `frenzy` tide doubles normal targets and caps (02 §14.4). Trait prey are unchanged.
--   Events. `startEvent` keeps `PreyDef.alive` groups of an event prey alive until
--           `PreyDef.eventTotal` groups have been released (03 §3.1; 09 §8.1 counts lunar_fry's 12
--           as groups), topping up on each pass; `clearEvents` ends it.
local Formation = require("../Sim/Formation")
local Index = require("../Data/Index")
local PreySim = require("../Sim/PreySim")
local PreySpawnMath = require("./PreySpawnMath")
local Rng = require("../Util/Rng")
local Types = require("../Types")

type PreyDef = Types.PreyDef
type PreySpawnDef = Types.PreySpawnDef

local PreySpawner = {}

PreySpawner.PASS_EVERY = 1.0 -- s (02 §9.5)
PreySpawner.CLEAR_RADIUS = 60 -- no player this close to a new group
PreySpawner.STRAGGLE_RADIUS = 80
PreySpawner.STRAGGLE_AFTER = 10 -- s
PreySpawner.OVER_TARGET = 1.5
PreySpawner.CULL_PER_PASS = 10
PreySpawner.FADE_IN = 0.5 -- s: a new group cannot be eaten before it has faded in (02 §9.5)
PreySpawner.PASS_SLACK = 0.05 -- s: half a tick, so the pass keeps to every 10th tick
PreySpawner.FRENZY_TIDE = "frenzy" -- the one tide that doubles normal targets (02 §14.4)

export type Area = {
	zone: string,
	home: number, -- PreySim home index
	cx: number,
	cy: number,
	cz: number,
	radius: number,
	halfHeight: number,
	preyIds: { [string]: boolean }?, -- a PreySpawn volume's PreyIds; nil = every prey of the zone
}

export type Row = {
	zone: string,
	prey: string,
	kind: number,
	def: PreyDef,
	spawnDef: PreySpawnDef?, -- normal prey
	alive: number?, -- trait prey: 02 §9.6 count
	respawn: number,
	trait: boolean,
	areas: { Area },
	target: number,
	count: number, -- live groups that count (stragglers do not)
	readyAt: number,
}

export type EventRun = {
	prey: string,
	kind: number,
	alive: number, -- groups kept alive at once
	left: number, -- groups still to release
	live: number, -- live groups, counted by each pass
}

export type Spawner = {
	sim: PreySim.Sim,
	rng: Rng.Rng,
	areas: { Area },
	rows: { Row },
	zoneScale: { [string]: number }, -- areaScale per zone (spawn area ÷ zone area, at most 1)
	playersInside: { [string]: number },
	players: number,
	tide: string?, -- the running tide, nil = none
	rate: number, -- the running tide's spawnRateMult (1 with none)
	events: { EventRun }, -- event prey being released
	rowOf: buffer, -- u16 per group: row index, 0 = not counted (event prey, jelly, straggler)
	straggleAt: buffer, -- f64 per group: last time a player was near a straggler, 0 = not one
	spawnedAt: buffer, -- f64 per group
	nextPass: number,
	jellyKind: number?,
	jellyDef: PreyDef?,
	jellyGroup: number, -- -1 = none
	jellyGen: number,
	jellyAt: number,
	jellyNext: number,
	situation: PreySpawnMath.Situation,
	onRemoved: ((g: number, gen: number) -> ())?, -- called just before a group is removed
	zoneAt: ((x: number, y: number, z: number) -> string)?, -- rejects points in a nested zone
}

local function behaviourOf(def: PreyDef): string
	return def.behaviour
end

--- A spawner for `sim`. Add areas, then `build`.
function PreySpawner.new(sim: PreySim.Sim, seed: number): Spawner
	local G = PreySim.MAX_GROUPS
	return {
		sim = sim,
		rng = Rng.new(seed),
		areas = {},
		rows = {},
		zoneScale = {},
		playersInside = {},
		players = 0,
		tide = nil,
		rate = 1,
		events = {},
		rowOf = buffer.create(G * 2),
		straggleAt = buffer.create(G * 8),
		spawnedAt = buffer.create(G * 8),
		nextPass = 0,
		jellyKind = nil,
		jellyDef = nil,
		jellyGroup = -1,
		jellyGen = 0,
		jellyAt = 0,
		jellyNext = 0,
		situation = { players = 0 },
		onRemoved = nil,
		zoneAt = nil,
	}
end

--- Adds a spawn area and sets it as a PreySim home. Returns the home index.
function PreySpawner.addArea(
	sp: Spawner,
	zone: string,
	cx: number,
	cy: number,
	cz: number,
	radius: number,
	halfHeight: number,
	preyIds: { string }?
): number
	local home = #sp.areas
	local set: { [string]: boolean }? = nil
	if preyIds then
		local s = {}
		for _, id in preyIds do
			s[id] = true
		end
		set = s
	end
	PreySim.setHome(sp.sim, home, cx, cy, cz, radius, halfHeight)
	table.insert(sp.areas, {
		zone = zone,
		home = home,
		cx = cx,
		cy = cy,
		cz = cz,
		radius = radius,
		halfHeight = halfHeight,
		preyIds = set,
	})
	return home
end

--- areaScale of a zone (02 §9.6 "Smaller spawn areas"): plan area of its spawn space ÷ the zone's
--- plan area, at most 1. Default 1.
function PreySpawner.setZoneScale(sp: Spawner, zone: string, scale: number)
	sp.zoneScale[zone] = math.clamp(scale, 0, 1)
end

local function areasFor(sp: Spawner, zone: string, prey: string): { Area }
	local out = {}
	for _, a in sp.areas do
		if a.zone == zone and (a.preyIds == nil or (a.preyIds :: { [string]: boolean })[prey]) then
			table.insert(out, a)
		end
	end
	return out
end

--- Builds the rows from the data tables for every zone that has an area. Call once after the
--- areas are in.
function PreySpawner.build(sp: Spawner)
	table.clear(sp.rows)
	for _, def in Index.PreySpawns.list do
		local areas = areasFor(sp, def.zone, def.prey)
		local prey = Index.Prey.byId[def.prey]
		if #areas > 0 and prey and prey.scope == "MVP" then
			assert(prey.respawn, `PreySpawner: {def.prey} has no respawn delay`)
			table.insert(sp.rows, {
				zone = def.zone,
				prey = def.prey,
				kind = Formation.kindOf(def.prey) :: number,
				def = prey,
				spawnDef = def,
				alive = nil,
				respawn = prey.respawn :: number,
				trait = false,
				areas = areas,
				target = 0,
				count = 0,
				readyAt = 0,
			})
		end
	end
	for _, t in Index.TraitPreySpawns.list do
		local areas = areasFor(sp, t.zone, t.prey)
		local prey = Index.TraitPrey.byId[t.prey]
		if #areas > 0 and prey and prey.scope == "MVP" then
			assert(prey.respawn, `PreySpawner: {t.prey} has no respawn delay`)
			table.insert(sp.rows, {
				zone = t.zone,
				prey = t.prey,
				kind = Formation.kindOf(t.prey) :: number,
				def = prey,
				spawnDef = nil,
				alive = t.alive,
				respawn = prey.respawn :: number,
				trait = true,
				areas = areas,
				target = 0,
				count = 0,
				readyAt = 0,
			})
		end
	end
	local jelly = Index.TraitPrey.byId.crystal_jelly
	local live = jelly ~= nil
		and jelly.scope == "MVP"
		and jelly.respawn ~= nil
		and jelly.lifetime ~= nil
		and jelly.alive ~= nil
	sp.jellyKind = if live then Formation.kindOf("crystal_jelly") else nil
	sp.jellyDef = if live then jelly else nil
	PreySpawner.retarget(sp)
end

--- Players on the server and, for the Nursery's rule, inside each zone.
function PreySpawner.setPlayers(sp: Spawner, n: number, insideByZone: { [string]: number }?)
	sp.players = n
	table.clear(sp.playersInside)
	if insideByZone then
		for zone, k in insideByZone do
			sp.playersInside[zone] = k
		end
	end
end

--- The running tide (PreyService.setTide), nil for none. Its spawnRateMult (canon data:Tides)
--- divides the respawn delays of normal prey and sets the spawns per row per pass; only the
--- `frenzy` tide doubles the targets and caps of normal prey (02 §9.5, §14.4).
function PreySpawner.setTide(sp: Spawner, tideId: string?)
	local rate = 1
	if tideId then
		local tide = Index.Tides.byId[tideId]
		assert(tide, `PreySpawner.setTide: unknown tide {tideId}`)
		assert(tide.spawnRateMult > 0, "PreySpawner.setTide: bad spawnRateMult")
		rate = tide.spawnRateMult
	end
	sp.tide = tideId
	sp.rate = rate
	PreySpawner.retarget(sp)
end

--- Recomputes every row's target from the current situation.
function PreySpawner.retarget(sp: Spawner)
	local situation = sp.situation
	situation.players = sp.players
	situation.frenzy = sp.tide == PreySpawner.FRENZY_TIDE
	for _, row in sp.rows do
		local scale = sp.zoneScale[row.zone] or 1
		if row.spawnDef then
			local def = row.spawnDef :: PreySpawnDef
			situation.playersInside = sp.playersInside[row.zone] or 0
			situation.area = if scale < 1 then scale * def.zoneArea else nil
			row.target = PreySpawnMath.target(def, situation)
		else
			row.target = math.max(1, math.floor((row.alive :: number) * scale + 0.5))
		end
	end
end

local function nearestPlayer2(
	x: number,
	y: number,
	z: number,
	px: { number },
	py: { number },
	pz: { number },
	n: number
): number
	local best = math.huge
	for k = 1, n do
		local dx, dy, dz = px[k] - x, py[k] - y, pz[k] - z
		local d2 = dx * dx + dy * dy + dz * dz
		if d2 < best then
			best = d2
		end
	end
	return best
end

-- A point for a new group of `row`: no player within CLEAR_RADIUS, else the farthest of the tries.
local function pickPoint(
	sp: Spawner,
	areas: { Area },
	zone: string,
	px: { number },
	py: { number },
	pz: { number },
	n: number
): (Area, number, number, number)
	local rng = sp.rng
	local clear2 = PreySpawner.CLEAR_RADIUS * PreySpawner.CLEAR_RADIUS
	local bestArea, bx, by, bz, bestD2 = areas[1], areas[1].cx, areas[1].cy, areas[1].cz, -1
	for _ = 1, 4 do
		local a = areas[Rng.int(rng, 1, #areas)]
		local angle = Rng.range(rng, 0, 2 * math.pi)
		local r = a.radius * 0.8 * math.sqrt(Rng.next(rng))
		local x = a.cx + math.sin(angle) * r
		local z = a.cz + math.cos(angle) * r
		local y = a.cy + Rng.range(rng, -0.8, 0.8) * a.halfHeight
		local inZone = sp.zoneAt == nil
			or (sp.zoneAt :: (number, number, number) -> string)(x, y, z) == zone
		local d2 = if inZone then nearestPlayer2(x, y, z, px, py, pz, n) else -0.5
		if d2 > bestD2 then
			bestArea, bx, by, bz, bestD2 = a, x, y, z, d2
		end
		if d2 >= clear2 then
			break
		end
	end
	return bestArea, bx, by, bz
end

local function spawnRow(
	sp: Spawner,
	rowIndex: number,
	row: Row,
	now: number,
	px: { number },
	py: { number },
	pz: { number },
	n: number
): boolean
	local area, x, y, z = pickPoint(sp, row.areas, row.zone, px, py, pz, n)
	local size = Rng.int(sp.rng, row.def.groupMin, row.def.groupMax)
	local g =
		PreySim.spawn(sp.sim, row.kind, area.home, x, y, z, math.min(size, PreySim.MAX_MEMBERS))
	if g == nil then
		return false
	end
	buffer.writeu16(sp.rowOf, g * 2, rowIndex)
	buffer.writef64(sp.straggleAt, g * 8, 0)
	buffer.writef64(sp.spawnedAt, g * 8, now)
	row.count += 1
	return true
end

-- Removes group g through the callback, and un-counts it.
local spawnEventGroups: (
	sp: Spawner,
	run: EventRun,
	groups: number,
	now: number,
	px: { number },
	py: { number },
	pz: { number },
	n: number
) -> number

local function removeGroup(sp: Spawner, g: number, now: number)
	local sim = sp.sim
	local rowIndex = buffer.readu16(sp.rowOf, g * 2)
	if rowIndex > 0 then
		local row = sp.rows[rowIndex]
		row.count -= 1
		row.readyAt = math.max(row.readyAt, now + row.respawn / (if row.trait then 1 else sp.rate))
		buffer.writeu16(sp.rowOf, g * 2, 0)
	end
	buffer.writef64(sp.straggleAt, g * 8, 0)
	if g == sp.jellyGroup then
		sp.jellyGroup = -1
	end
	local onRemoved = sp.onRemoved
	if onRemoved then
		onRemoved(g, buffer.readu8(sim.buffers.gen, g))
	end
	PreySim.remove(sim, g)
end

-- Spawns up to `groups` groups of a running event's prey (flag bit4), round-robin over its zones
-- that have spawn areas. Returns how many.
spawnEventGroups = function(
	sp: Spawner,
	run: EventRun,
	groups: number,
	now: number,
	px: { number },
	py: { number },
	pz: { number },
	n: number
): number
	local def = Formation.defOf(run.kind) :: PreyDef
	local zones: { string } = {}
	local areasOf: { { Area } } = {}
	for _, zone in def.zones do
		local areas = areasFor(sp, zone, run.prey)
		if #areas > 0 then
			table.insert(zones, zone)
			table.insert(areasOf, areas)
		end
	end
	local made = 0
	for k = 1, if #zones > 0 then groups else 0 do
		local zone = zones[(k - 1) % #zones + 1]
		local areas = areasOf[(k - 1) % #zones + 1]
		local area, x, y, z = pickPoint(sp, areas, zone, px, py, pz, n)
		local size = Rng.int(sp.rng, def.groupMin, def.groupMax)
		local g = PreySim.spawn(sp.sim, run.kind, area.home, x, y, z, size, true)
		if g then
			buffer.writeu16(sp.rowOf, g * 2, 0)
			buffer.writef64(sp.spawnedAt, g * 8, now)
			made += 1
		end
	end
	return made
end

--- Fills every row to its target at once (server start). Players' positions as in `pass`.
function PreySpawner.fill(
	sp: Spawner,
	now: number,
	px: { number },
	py: { number },
	pz: { number },
	n: number
)
	PreySpawner.retarget(sp)
	for rowIndex, row in sp.rows do
		while row.count < row.target do
			if not spawnRow(sp, rowIndex, row, now, px, py, pz, n) then
				return
			end
		end
	end
	sp.nextPass = now + PreySpawner.PASS_EVERY
	sp.jellyNext = now -- the first drift appears with the first pass
end

--- The once-a-second pass (call it every tick; it returns at once until a second has gone by).
--- Players are given as parallel arrays of positions, n of them. Returns groups spawned.
function PreySpawner.pass(
	sp: Spawner,
	now: number,
	px: { number },
	py: { number },
	pz: { number },
	n: number
): number
	if now < sp.nextPass - PreySpawner.PASS_SLACK then
		return 0
	end
	sp.nextPass = now + PreySpawner.PASS_EVERY
	PreySpawner.retarget(sp)
	local sim = sp.sim
	local b = sim.buffers
	local straggle2 = PreySpawner.STRAGGLE_RADIUS * PreySpawner.STRAGGLE_RADIUS
	local culls = PreySpawner.CULL_PER_PASS

	-- Stragglers and culls over 150% of target; live event groups counted per event.
	local events = sp.events
	for _, run in events do
		run.live = 0
	end
	for g = 0, PreySim.MAX_GROUPS - 1 do
		local kind = buffer.readu8(b.kind, g)
		if kind == 0 then
			continue
		end
		if #events > 0 and bit32.btest(buffer.readu8(b.flags, g), PreySim.FLAG_EVENT) then
			for _, run in events do
				if run.kind == kind then
					run.live += 1
				end
			end
		end
		local since = buffer.readf64(sp.straggleAt, g * 8)
		local rowIndex = buffer.readu16(sp.rowOf, g * 2)
		local over = rowIndex > 0
			and sp.rows[rowIndex].count > sp.rows[rowIndex].target * PreySpawner.OVER_TARGET
		if since == 0 and not over then
			continue
		end
		local o4 = g * 4
		local near = nearestPlayer2(
			buffer.readf32(b.posX, o4),
			buffer.readf32(b.posY, o4),
			buffer.readf32(b.posZ, o4),
			px,
			py,
			pz,
			n
		) <= straggle2
		if since > 0 then
			if near then
				buffer.writef64(sp.straggleAt, g * 8, now)
			elseif now - since >= PreySpawner.STRAGGLE_AFTER then
				removeGroup(sp, g, now)
			end
		elseif over and not near and culls > 0 then
			culls -= 1
			removeGroup(sp, g, now)
		end
	end

	-- Crystal Jelly drift.
	if sp.jellyKind then
		local jellyDef = sp.jellyDef :: PreyDef
		if sp.jellyGroup >= 0 and now - sp.jellyAt >= (jellyDef.lifetime :: number) then
			if PreySim.isLive(sim, sp.jellyGroup, sp.jellyGen) then
				removeGroup(sp, sp.jellyGroup, now)
			end
			sp.jellyGroup = -1
		end
		if now >= sp.jellyNext then
			local jelly = jellyDef
			-- A random zone of the jelly's that has spawn areas.
			local zones: { string } = {}
			for _, z in jelly.zones do
				if #areasFor(sp, z, jelly.id) > 0 then
					table.insert(zones, z)
				end
			end
			local zone = if #zones > 0 then zones[Rng.int(sp.rng, 1, #zones)] else nil
			local areas = if zone then areasFor(sp, zone, jelly.id) else {}
			if zone and #areas > 0 then
				local area, x, y, z = pickPoint(sp, areas, zone, px, py, pz, n)
				local g, gen = PreySim.spawn(
					sim,
					sp.jellyKind :: number,
					area.home,
					x,
					y,
					z,
					jelly.alive :: number
				)
				if g then
					buffer.writeu16(sp.rowOf, g * 2, 0)
					buffer.writef64(sp.spawnedAt, g * 8, now)
					sp.jellyGroup, sp.jellyGen, sp.jellyAt = g, gen, now
				end
			end
			sp.jellyNext = now + (jelly.respawn :: number)
		end
	end

	-- Event prey: top each running event up to its groups alive at once.
	for _, run in events do
		local want = math.min(run.alive - run.live, run.left)
		if want > 0 then
			run.left -= spawnEventGroups(sp, run, want, now, px, py, pz, n)
		end
	end

	-- One group per row below target whose delay has run; the tide's spawnRateMult per pass for
	-- normal prey (three in a Feeding Frenzy, 02 §14.4 "Three spawns per pass instead of one").
	local spawned = 0
	local frenzyBurst = math.max(1, math.floor(sp.rate))
	for rowIndex, row in sp.rows do
		local burst = if row.trait then 1 else frenzyBurst
		while burst > 0 and row.count < row.target and now >= row.readyAt do
			burst -= 1
			if not spawnRow(sp, rowIndex, row, now, px, py, pz, n) then
				break
			end
			spawned += 1
		end
	end
	return spawned
end

--- After member `member` of group g was eaten (the alive bit is already clear): removes a group
--- with nobody left, and turns a swarm or school down to two members into stragglers. Returns
--- true when the group was removed.
function PreySpawner.onEaten(sp: Spawner, g: number, now: number): boolean
	local sim = sp.sim
	local left = PreySim.aliveCount(sim, g)
	if left == 0 then
		removeGroup(sp, g, now)
		return true
	end
	local rowIndex = buffer.readu16(sp.rowOf, g * 2)
	if rowIndex > 0 and left <= 2 then
		local row = sp.rows[rowIndex]
		local behaviour = behaviourOf(row.def)
		if (behaviour == "swarm" or behaviour == "school") and row.def.groupMin > 2 then
			row.count -= 1
			row.readyAt =
				math.max(row.readyAt, now + row.respawn / (if row.trait then 1 else sp.rate))
			buffer.writeu16(sp.rowOf, g * 2, 0)
			buffer.writef64(sp.straggleAt, g * 8, now)
		end
	end
	return false
end

--- True once a group has faded in (02 §9.5: not edible during its first 0.5 s).
function PreySpawner.edibleAt(sp: Spawner, g: number, t: number): boolean
	return t >= buffer.readf64(sp.spawnedAt, g * 8) + PreySpawner.FADE_IN
end

--- Starts releasing event prey `preyId` (flag bit4): `PreyDef.alive` groups at once (all of
--- `eventTotal` when it has no alive count), topped up by each pass until `PreyDef.eventTotal`
--- groups have been released (03 §3.1). Spawns the first groups now. Returns how many.
function PreySpawner.startEvent(
	sp: Spawner,
	preyId: string,
	now: number,
	px: { number },
	py: { number },
	pz: { number },
	n: number
): number
	local kind = Formation.kindOf(preyId)
	local def = if kind then Formation.defOf(kind) else nil
	if kind == nil or def == nil or def.eventTotal == nil then
		return 0
	end
	local total = def.eventTotal :: number
	local run: EventRun = {
		prey = preyId,
		kind = kind,
		alive = math.min(def.alive or total, total),
		left = total,
		live = 0,
	}
	table.insert(sp.events, run)
	local made = spawnEventGroups(sp, run, run.alive, now, px, py, pz, n)
	run.left -= made
	return made
end

--- Removes every event prey group and ends every event (the tide ended). Returns how many.
function PreySpawner.clearEvents(sp: Spawner, now: number): number
	table.clear(sp.events)
	local b = sp.sim.buffers
	local n = 0
	for g = 0, PreySim.MAX_GROUPS - 1 do
		if
			buffer.readu8(b.kind, g) ~= 0
			and bit32.btest(buffer.readu8(b.flags, g), PreySim.FLAG_EVENT)
		then
			removeGroup(sp, g, now)
			n += 1
		end
	end
	return n
end

--- Sum over rows of target × mean group size: the members the spawner aims for (soak: live
--- members must stay within 60% to 160% of it).
function PreySpawner.targetMembers(sp: Spawner): number
	local total = 0
	for _, row in sp.rows do
		total += row.target * (row.def.groupMin + row.def.groupMax) / 2
	end
	return total
end

--- Members alive in every live group, and the number of live groups.
function PreySpawner.liveMembers(sp: Spawner): (number, number)
	local sim = sp.sim
	local members, groups = 0, 0
	for g = 0, PreySim.MAX_GROUPS - 1 do
		if PreySim.isLive(sim, g) then
			members += PreySim.aliveCount(sim, g)
			groups += 1
		end
	end
	return members, groups
end

return table.freeze(PreySpawner)
