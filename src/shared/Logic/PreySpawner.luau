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
--           TRAIT_ALIVE (02 §9.6, MVP rows; no playerScale or eventScale, areaScale applies).
--   Pass.   `pass` runs once a second (02 §9.5). Per row below target whose respawn delay has run,
--           it spawns one whole group at a point of one of the row's areas with no player within
--           60 studs (the farthest of 4 tries otherwise). Stragglers (a swarm or school down to two
--           members, 02 §9.2) leave after 10 s with no player within 80 studs and no longer count,
--           so the school respawns whole. A row above 150% of target (after a Frenzy) loses its
--           groups that have no player within 80 studs, 10 per second in all. The crystal_jelly
--           drift (one group of five) appears every 300 s and leaves 240 s after it appeared.
--   Rate.   `setRate(mult)`: respawn delays of normal prey are divided by mult; mult > 1 is a
--           Feeding Frenzy, which also doubles normal targets and caps (02 §14.4). Trait prey are
--           unchanged.
-- Respawn delays and trait prey targets are copied from docs/03 §2.1 and §3.1 and 02 §9.6 because
-- the generated PreyDef and PreySpawns do not carry them yet (reported gap).
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
PreySpawner.JELLY_EVERY = 300 -- s (03 §3.1)
PreySpawner.JELLY_STAY = 240
PreySpawner.JELLY_COUNT = 5

-- docs/03 §2.1 and §3.1, "Respawn (s)" (gap: not in the generated PreyDef).
local RESPAWN: { [string]: number } = {
	plankton = 4,
	krill = 12,
	shrimp = 10,
	sardine = 20,
	darter = 25,
	mackerel = 35,
	bonito = 50,
	tuna = 90,
	glowfry = 30,
	zebra_darter = 30,
	dotted_goby = 25,
	armor_shrimp = 60,
	urchin_puff = 60,
	ribbonfish = 60,
	inklet = 120,
	spark_eel = 120,
	leaf_drifter = 120,
	vent_snail = 180,
}
-- docs/02 §9.6 data:PreyTargets, trait prey rows ("Animals" alive per server, by zone). The
-- generated PreySpawns has normal prey only (gap). Rows whose prey is not [MVP] are skipped.
local TRAIT_ALIVE: { { zone: string, prey: string, alive: number } } = {
	{ zone = "reef", prey = "glowfry", alive = 6 },
	{ zone = "kelp", prey = "glowfry", alive = 4 },
	{ zone = "reef", prey = "dotted_goby", alive = 10 },
	{ zone = "reef", prey = "zebra_darter", alive = 8 },
	{ zone = "reef", prey = "urchin_puff", alive = 6 },
	{ zone = "kelp", prey = "armor_shrimp", alive = 6 },
	{ zone = "kelp", prey = "ribbonfish", alive = 6 },
	{ zone = "kelp", prey = "leaf_drifter", alive = 5 },
	{ zone = "dropoff", prey = "inklet", alive = 5 },
	{ zone = "dropoff", prey = "spark_eel", alive = 5 },
	{ zone = "dropoff", prey = "vent_snail", alive = 4 },
}

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

export type Spawner = {
	sim: PreySim.Sim,
	rng: Rng.Rng,
	areas: { Area },
	rows: { Row },
	zoneScale: { [string]: number }, -- areaScale per zone (spawn area ÷ zone area, at most 1)
	playersInside: { [string]: number },
	players: number,
	rate: number,
	rowOf: buffer, -- u16 per group: row index, 0 = not counted (event prey, jelly, straggler)
	straggleAt: buffer, -- f64 per group: last time a player was near a straggler, 0 = not one
	spawnedAt: buffer, -- f64 per group
	nextPass: number,
	jellyKind: number?,
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
		rate = 1,
		rowOf = buffer.create(G * 2),
		straggleAt = buffer.create(G * 8),
		spawnedAt = buffer.create(G * 8),
		nextPass = 0,
		jellyKind = nil,
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
			table.insert(sp.rows, {
				zone = def.zone,
				prey = def.prey,
				kind = Formation.kindOf(def.prey) :: number,
				def = prey,
				spawnDef = def,
				alive = nil,
				respawn = RESPAWN[def.prey] or 30,
				trait = false,
				areas = areas,
				target = 0,
				count = 0,
				readyAt = 0,
			})
		end
	end
	for _, t in TRAIT_ALIVE do
		local areas = areasFor(sp, t.zone, t.prey)
		local prey = Index.TraitPrey.byId[t.prey]
		if #areas > 0 and prey and prey.scope == "MVP" then
			table.insert(sp.rows, {
				zone = t.zone,
				prey = t.prey,
				kind = Formation.kindOf(t.prey) :: number,
				def = prey,
				spawnDef = nil,
				alive = t.alive,
				respawn = RESPAWN[t.prey] or 60,
				trait = true,
				areas = areas,
				target = 0,
				count = 0,
				readyAt = 0,
			})
		end
	end
	local jelly = Index.TraitPrey.byId.crystal_jelly
	sp.jellyKind = if jelly and jelly.scope == "MVP" then Formation.kindOf("crystal_jelly") else nil
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

--- Respawn multiplier (PreyService.setSpawnRate): 3 in a Feeding Frenzy, else 1.
function PreySpawner.setRate(sp: Spawner, mult: number)
	assert(mult > 0, "PreySpawner.setRate: bad multiplier")
	sp.rate = mult
	PreySpawner.retarget(sp)
end

--- Recomputes every row's target from the current situation.
function PreySpawner.retarget(sp: Spawner)
	local situation = sp.situation
	situation.players = sp.players
	situation.frenzy = sp.rate > 1
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
	if now < sp.nextPass then
		return 0
	end
	sp.nextPass = now + PreySpawner.PASS_EVERY
	PreySpawner.retarget(sp)
	local sim = sp.sim
	local b = sim.buffers
	local straggle2 = PreySpawner.STRAGGLE_RADIUS * PreySpawner.STRAGGLE_RADIUS
	local culls = PreySpawner.CULL_PER_PASS

	-- Stragglers and culls over 150% of target.
	for g = 0, PreySim.MAX_GROUPS - 1 do
		if buffer.readu8(b.kind, g) == 0 then
			continue
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
		if sp.jellyGroup >= 0 and now - sp.jellyAt >= PreySpawner.JELLY_STAY then
			if PreySim.isLive(sim, sp.jellyGroup, sp.jellyGen) then
				removeGroup(sp, sp.jellyGroup, now)
			end
			sp.jellyGroup = -1
		end
		if now >= sp.jellyNext then
			local jelly = Formation.defOf(sp.jellyKind :: number) :: PreyDef
			local zone = jelly.zones[Rng.int(sp.rng, 1, #jelly.zones)]
			local areas = areasFor(sp, zone, jelly.id)
			if #areas > 0 then
				local area, x, y, z = pickPoint(sp, areas, zone, px, py, pz, n)
				local g, gen = PreySim.spawn(
					sim,
					sp.jellyKind :: number,
					area.home,
					x,
					y,
					z,
					PreySpawner.JELLY_COUNT
				)
				if g then
					buffer.writeu16(sp.rowOf, g * 2, 0)
					buffer.writef64(sp.spawnedAt, g * 8, now)
					sp.jellyGroup, sp.jellyGen, sp.jellyAt = g, gen, now
				end
			end
			sp.jellyNext = now + PreySpawner.JELLY_EVERY
		end
	end

	-- One group per row below target whose delay has run.
	local spawned = 0
	for rowIndex, row in sp.rows do
		if row.count < row.target and now >= row.readyAt then
			if spawnRow(sp, rowIndex, row, now, px, py, pz, n) then
				spawned += 1
			end
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

--- Spawns `groups` groups of event prey `preyId` (flag bit4) in its zones' areas. Returns how many.
function PreySpawner.spawnEvent(
	sp: Spawner,
	preyId: string,
	groups: number,
	now: number,
	px: { number },
	py: { number },
	pz: { number },
	n: number
): number
	local kind = Formation.kindOf(preyId)
	local def = if kind then Formation.defOf(kind) else nil
	if kind == nil or def == nil then
		return 0
	end
	-- Round-robin over the prey's zones that have spawn areas.
	local zones: { string } = {}
	local areasOf: { { Area } } = {}
	for _, zone in def.zones do
		local areas = areasFor(sp, zone, preyId)
		if #areas > 0 then
			table.insert(zones, zone)
			table.insert(areasOf, areas)
		end
	end
	local made = 0
	for k = 1, if #zones > 0 then groups else 0 do
		local zone = zones[(k - 1) % #zones + 1]
		local areas = areasOf[(k - 1) % #zones + 1]
		do
			local area, x, y, z = pickPoint(sp, areas, zone, px, py, pz, n)
			local size = Rng.int(sp.rng, def.groupMin, def.groupMax)
			local g = PreySim.spawn(sp.sim, kind, area.home, x, y, z, size, true)
			if g then
				buffer.writeu16(sp.rowOf, g * 2, 0)
				buffer.writef64(sp.spawnedAt, g * 8, now)
				made += 1
			end
		end
	end
	return made
end

--- Removes every event prey group (the tide ended). Returns how many.
function PreySpawner.clearEvents(sp: Spawner, now: number): number
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
