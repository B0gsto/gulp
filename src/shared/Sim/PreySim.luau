--!strict
--!native
--!optimize 2
-- PreySim: the server's prey groups (docs/09, sections 8.1 to 8.4 and 8.9; docs/02, section 9).
-- The unit is the group: behaviour is stepped once per group, never per member, and each member's
-- position is a pure function of group state through Formation (8.1). Pure: numbers and buffers
-- only, so it runs in Lune. PreyService (S3-C3) owns spawning policy, interest and sending; it
-- drives this module and reads the buffers directly.
--
-- Data layout (8.2): struct of arrays, one buffer per field, indexed by group ID 0 to 639. The
-- `cell`, `nextInCell` and `prevInCell` buffers are the SpatialGrid's own (8.3). Two additions,
-- both reported as deviations: `burstUntil` (f32, end of the current flee burst, then end of the
-- 2 s tired window that follows it, docs/03 §2.1) and the history sample's pad byte, which holds the
-- quantised heading (u8, 2π/256) so `memberPosAt` can rebuild the formation at a past time.
-- While a group flees, `wanderX/Y/Z` hold its unit flee direction; while it is lured, the lure
-- point. `wanderUntil = 0` then makes it pick a fresh wander target when that ends.
--
-- One tick (8.4), `step(sim, now, dt)` at 10 Hz:
--   0 Activity: a group is active if a player threat is within 700 studs, else dormant (flag
--     bit3); dormant groups are stepped once a second with dt = 1, staggered by group ID.
--   1 Threat pass, per threat: the groups in its 3 × 3 cells. The nearest threat that can eat a
--     group and is within its fleeRadius sets the flee direction away from it and
--     stateUntil = now + 1.2 s; a Moonlit player within 40 studs lures it instead.
--   2 Steer: stunned holds still; fleeing goes at fleeSpeed; lured goes toward the lure at 4 studs/s;
--     otherwise toward the wander target at cruiseSpeed (a new seeded target in the home volume
--     every 3 to 6 s). A flee lasts at most the prey's burst, then it is tired for 2 s (cruise only).
--   3 Integrate: vel += clampLength(desired − vel, accel × dt); pos += vel × dt. Scatter moves
--     toward its target at 2/s up, 0.5/s down. Swarms and packs scatter while fleeing, schools for
--     the first second of a flee.
--   4 Leash: outside the home radius a pull back is added; beyond 1.5 × radius the position is
--     clamped. `hop` kinds take y = floorY(x, z) + hop arc.
--   5 History: the quantised position, scatter and heading of every live group go into its
--     8-sample ring (0.8 s) for lag-compensated bite checks (8.9).
-- No allocation per group or per tick. `debug.profilebegin` exists only in the engine, so it is
-- looked up once and replaced by a no-op in Lune.
local Formation = require("./Formation")
local Quantize = require("./Quantize")
local Rng = require("../Util/Rng")
local SpatialGrid = require("./SpatialGrid")

local profileBegin: (string) -> () = debug.profilebegin or function(_label: string) end
local profileEnd: () -> () = debug.profileend or function() end

local PreySim = {}

PreySim.MAX_GROUPS = 640 -- (tune) 09 §8.1
PreySim.MAX_MEMBERS = 24
PreySim.MAX_THREATS = 64 -- 24 creatures and 32 predators fit
PreySim.MAX_HOMES = 1024
PreySim.HIST = 8 -- samples in the history ring, one per tick (0.8 s)
PreySim.MAX_GEN = 254 -- gen wraps 0 to 254 so a client's `known = gen + 1` fits a u8 (8.2)

PreySim.FLAG_FLEEING = 1
PreySim.FLAG_STUNNED = 2
PreySim.FLAG_LURED = 4
PreySim.FLAG_DORMANT = 8
PreySim.FLAG_EVENT = 16

PreySim.THREAT_PLAYER = 1 -- counts for activity; can lure when Moonlit
PreySim.THREAT_MOONLIT = 2 -- a Moonlit creature lures prey within 40 studs instead of scaring it
PreySim.THREAT_HIDDEN = 4 -- Camo or inside an ink cloud: prey do not detect it (02 §9.1)

-- Numbers of 09 §8.4 and 02/03 (tune).
local ACTIVE_RANGE = 700
local DORMANT_EVERY = 10 -- ticks between dormant steps (1 s at 10 Hz)
local FLEE_HOLD = 1.2
local TIRED = 2
local LURE_RANGE = 40
local LURE_SPEED = 4
local SCATTER_UP = 2
local SCATTER_DOWN = 0.5
local SCHOOL_SCATTER = 1 -- s: members of a school scatter for the first second of a flee (02 §9.2)
local WANDER_MIN, WANDER_MAX = 3, 6
local WANDER_REACHED = 2 -- studs
local LEASH_CLAMP = 1.5
local HOP_HEIGHT = 2 -- 02 §9.2: arc 2 studs high
local HOP_CALM, HOP_FLEE = 1.2, 0.5 -- s per hop
local DRIFT_ACCEL = 1 -- studs/s²: plankton changes direction slowly

local MAX_GROUPS = PreySim.MAX_GROUPS
local MAX_THREATS = PreySim.MAX_THREATS
local HIST = PreySim.HIST
local HIST_BYTES = 8 -- u16 x, u16 y, u16 z, u8 scatter, u8 heading
local NONE = SpatialGrid.NONE
local TAU = 2 * math.pi

local FLEEING, STUNNED, LURED, DORMANT, EVENT = 1, 2, 4, 8, 16
local T_PLAYER, T_MOONLIT, T_HIDDEN = 1, 2, 4

-- Behaviour codes.
local DRIFT, SWARM, HOP, SCHOOL, SOLO, RUN, PACK = 1, 2, 3, 4, 5, 6, 7
local behaviourCode = {
	drift = DRIFT,
	swarm = SWARM,
	hop = HOP,
	school = SCHOOL,
	solo = SOLO,
	run = RUN,
	pack = PACK,
}

-- Turn rate (°/s; 0 = turns in any direction) and flee burst (s) of docs/03 §2.1, which the
-- generated PreyDef does not carry yet (reported gap). Trait prey use the prey whose behaviour they
-- borrow (02 §9.3), so the behaviour default stands in for them.
local TURN_BURST_BY_ID: { [string]: { number } } = {
	krill = { 400, 2 },
	shrimp = { 0, 1.5 },
	sardine = { 300, 3 },
	darter = { 480, 3 },
	mackerel = { 120, 4 },
	bonito = { 110, 5 },
	tuna = { 90, 6 },
}
local TURN_BURST_BY_BEHAVIOUR: { [number]: { number } } = {
	[DRIFT] = { 0, 0 },
	[SWARM] = { 400, 2 },
	[HOP] = { 0, 1.5 },
	[SCHOOL] = { 300, 3 },
	[SOLO] = { 480, 3 },
	[RUN] = { 120, 4 },
	[PACK] = { 110, 5 },
}

-- Per-kind tables, indexed by kind code + 1.
local kTier = table.create(256, 99) :: { number }
local kBehaviour = table.create(256, 0) :: { number }
local kCruise = table.create(256, 0) :: { number }
local kFlee = table.create(256, 0) :: { number }
local kFleeR2 = table.create(256, 0) :: { number }
local kAccel = table.create(256, 0) :: { number }
local kBurst = table.create(256, 0) :: { number }
local reactRange = LURE_RANGE

for _, kind in Formation.kinds() do
	local def = Formation.defOf(kind)
	assert(def, "PreySim: kind without a def")
	local code = behaviourCode[def.behaviour]
	assert(code, `PreySim: unknown behaviour {def.behaviour}`)
	local turnBurst = TURN_BURST_BY_ID[def.id] or TURN_BURST_BY_BEHAVIOUR[code]
	local turn = if turnBurst[1] > 0 then math.rad(turnBurst[1]) else TAU
	local i = kind + 1
	kTier[i] = def.tier
	kBehaviour[i] = code
	kCruise[i] = def.cruiseSpeed
	kFlee[i] = def.fleeSpeed
	kFleeR2[i] = def.fleeRadius * def.fleeRadius
	-- Turning at `turn` rad/s at flee speed needs a lateral acceleration of speed × turn.
	kAccel[i] = if code == DRIFT then DRIFT_ACCEL else def.fleeSpeed * turn
	kBurst[i] = turnBurst[2]
	reactRange = math.max(reactRange, def.fleeRadius)
end
-- The threat pass visits the 3 × 3 cells around a threat, so no reaction may reach past one cell.
assert(reactRange <= SpatialGrid.CELL, "PreySim: a flee radius exceeds the 64-stud grid cell")

export type PreyBuffers = {
	kind: buffer, -- u8   0 = free slot, else Formation kind code
	gen: buffer, -- u8   generation, +1 each time the slot is reused (0 to 254)
	flags: buffer, -- u8  bit0 fleeing, bit1 stunned, bit2 lured, bit3 dormant, bit4 event prey
	count: buffer, -- u8  members at spawn (1..24)
	alive: buffer, -- u32 bit i set = member i alive
	seed: buffer, -- u16  formation and wander seed
	home: buffer, -- u16  index of the PreySpawn volume
	posX: buffer,
	posY: buffer,
	posZ: buffer, -- f32
	velX: buffer,
	velY: buffer,
	velZ: buffer, -- f32
	scatter: buffer, -- f32 0..1
	stateUntil: buffer, -- f32 end of flee or stun, seconds since ServerEpoch
	wanderX: buffer,
	wanderY: buffer,
	wanderZ: buffer, -- f32 wander target; flee direction while fleeing; lure point while lured
	wanderUntil: buffer, -- f32
	respawnAt: buffer, -- f32 for a free slot reserved by a spawn volume
	cell: buffer, -- u16 grid cell index, 0xFFFF = none (SpatialGrid's)
	nextInCell: buffer,
	prevInCell: buffer, -- u16 intrusive list (SpatialGrid's)
	histPos: buffer, -- 8 samples × (u16 x, u16 y, u16 z, u8 scatter, u8 heading) per group = 64 B
	histHead: buffer, -- u8
	burstUntil: buffer, -- f32 (addition) end of the flee burst, then of the tired window
}

export type Sim = {
	buffers: PreyBuffers,
	grid: SpatialGrid.Grid,
	rng: Rng.Rng,
	tick: number,
	now: number,
	liveGroups: number,
	cursor: number, -- where the next free-slot search starts
	histTime: buffer, -- f64 × 8: time of each history sample (shared by all groups)
	homes: buffer, -- f32 × 5 per home: cx, cy, cz, radius, halfHeight
	floorY: ((x: number, z: number) -> number)?,
	threatCount: number,
	threats: buffer, -- f64 × 4 per threat: x, y, z, eatTier
	threatFlags: buffer, -- u8 per threat
	-- Threat pass scratch.
	bestD2: buffer, -- f64 per group
	bestThreat: buffer, -- u8 per group
	stamp: buffer, -- u32 per group: tick the best threat was set
	touched: buffer, -- u16 list of groups reached this tick
}

local function f32(n: number): buffer
	return buffer.create(n * 4)
end

--- A new, empty simulation. `seed` drives every random choice (group seeds, wander targets), so
--- two sims given the same seed and the same calls give identical buffers.
function PreySim.new(seed: number): Sim
	local grid = SpatialGrid.new(MAX_GROUPS)
	local n = MAX_GROUPS
	local buffers: PreyBuffers = {
		kind = buffer.create(n),
		gen = buffer.create(n),
		flags = buffer.create(n),
		count = buffer.create(n),
		alive = buffer.create(n * 4),
		seed = buffer.create(n * 2),
		home = buffer.create(n * 2),
		posX = f32(n),
		posY = f32(n),
		posZ = f32(n),
		velX = f32(n),
		velY = f32(n),
		velZ = f32(n),
		scatter = f32(n),
		stateUntil = f32(n),
		wanderX = f32(n),
		wanderY = f32(n),
		wanderZ = f32(n),
		wanderUntil = f32(n),
		respawnAt = f32(n),
		cell = grid.cell,
		nextInCell = grid.next,
		prevInCell = grid.prev,
		histPos = buffer.create(n * HIST * HIST_BYTES),
		histHead = buffer.create(n),
		burstUntil = f32(n),
	}
	return {
		buffers = buffers,
		grid = grid,
		rng = Rng.new(seed),
		tick = 0,
		now = 0,
		liveGroups = 0,
		cursor = 0,
		histTime = buffer.create(HIST * 8),
		homes = buffer.create(PreySim.MAX_HOMES * 20),
		floorY = nil,
		threatCount = 0,
		threats = buffer.create(MAX_THREATS * 32),
		threatFlags = buffer.create(MAX_THREATS),
		bestD2 = buffer.create(n * 8),
		bestThreat = buffer.create(n),
		stamp = buffer.create(n * 4),
		touched = buffer.create(n * 2),
	}
end

--- Sets home volume `home` (0 to MAX_HOMES − 1): a vertical cylinder around (cx, cy, cz) of
--- horizontal `radius` and half height `halfHeight`. PreyService fits it to the PreySpawn volume.
function PreySim.setHome(
	sim: Sim,
	home: number,
	cx: number,
	cy: number,
	cz: number,
	radius: number,
	halfHeight: number
)
	assert(
		home >= 0 and home < PreySim.MAX_HOMES and home % 1 == 0,
		"PreySim.setHome: bad home index"
	)
	assert(radius > 0 and halfHeight >= 0, "PreySim.setHome: bad size")
	local o = home * 20
	buffer.writef32(sim.homes, o, cx)
	buffer.writef32(sim.homes, o + 4, cy)
	buffer.writef32(sim.homes, o + 8, cz)
	buffer.writef32(sim.homes, o + 12, radius)
	buffer.writef32(sim.homes, o + 16, halfHeight)
end

--- The sea floor height used by `hop` kinds (WorldIndex.floorY on the server). Without one, a hop
--- kind walks on the bottom of its home volume.
function PreySim.setFloor(sim: Sim, floorY: ((x: number, z: number) -> number)?)
	sim.floorY = floorY
end

--- Sets how many threats the next `step` reads (0 to MAX_THREATS).
function PreySim.setThreatCount(sim: Sim, n: number)
	assert(n >= 0 and n <= MAX_THREATS, "PreySim.setThreatCount: too many threats")
	sim.threatCount = n
end

--- Threat `i` (0-based): a creature or predator at (x, y, z). `eatTier` is the highest prey tier it
--- may eat (BiteRules.canEatPrey; −1 for none). `flags` is a sum of THREAT_* bits.
function PreySim.setThreat(
	sim: Sim,
	i: number,
	x: number,
	y: number,
	z: number,
	eatTier: number,
	flags: number
)
	local o = i * 32
	buffer.writef64(sim.threats, o, x)
	buffer.writef64(sim.threats, o + 8, y)
	buffer.writef64(sim.threats, o + 16, z)
	buffer.writef64(sim.threats, o + 24, eatTier)
	buffer.writeu8(sim.threatFlags, i, flags)
end

local function quantHeading(vx: number, vz: number, fallback: number): number
	if vx * vx + vz * vz < 0.0025 then
		return fallback
	end
	return math.floor(math.atan2(vx, vz) / TAU * 256 + 0.5) % 256
end

local function writeHistory(
	b: PreyBuffers,
	g: number,
	head: number,
	x: number,
	y: number,
	z: number,
	scatter: number
)
	local base = g * HIST * HIST_BYTES
	local prevHead = (head - 1) % HIST
	local fallback = buffer.readu8(b.histPos, base + prevHead * HIST_BYTES + 7)
	local o = base + head * HIST_BYTES
	buffer.writeu16(b.histPos, o, Quantize.x(x))
	buffer.writeu16(b.histPos, o + 2, Quantize.y(y))
	buffer.writeu16(b.histPos, o + 4, Quantize.z(z))
	buffer.writeu8(b.histPos, o + 6, Quantize.scatter(scatter))
	buffer.writeu8(
		b.histPos,
		o + 7,
		quantHeading(buffer.readf32(b.velX, g * 4), buffer.readf32(b.velZ, g * 4), fallback)
	)
	buffer.writeu8(b.histHead, g, head)
end

--- Spawns a group of `count` members (1 to 24) of `kind` at (x, y, z) with home volume `home`.
--- Takes slot `slot` when given (it must be free), else the next free slot. Returns the group ID
--- and its gen, or nil when every slot is taken.
function PreySim.spawn(
	sim: Sim,
	kind: number,
	home: number,
	x: number,
	y: number,
	z: number,
	count: number,
	eventPrey: boolean?,
	slot: number?
): (number?, number)
	assert(Formation.defOf(kind) ~= nil, "PreySim.spawn: unknown kind")
	assert(
		count >= 1 and count <= PreySim.MAX_MEMBERS and count % 1 == 0,
		"PreySim.spawn: bad count"
	)
	local b = sim.buffers
	local g: number
	if slot ~= nil then
		assert(buffer.readu8(b.kind, slot) == 0, "PreySim.spawn: the slot is taken")
		g = slot
	else
		local found = -1
		for step = 0, MAX_GROUPS - 1 do
			local candidate = (sim.cursor + step) % MAX_GROUPS
			if
				buffer.readu8(b.kind, candidate) == 0
				and buffer.readf32(b.respawnAt, candidate * 4) == 0
			then
				found = candidate
				break
			end
		end
		if found < 0 then
			return nil, 0
		end
		g = found
		sim.cursor = (found + 1) % MAX_GROUPS
	end
	local gen = (buffer.readu8(b.gen, g) + 1) % (PreySim.MAX_GEN + 1)
	local seed = Rng.nextU32(sim.rng) % 0x10000
	local o4 = g * 4
	buffer.writeu8(b.kind, g, kind)
	buffer.writeu8(b.gen, g, gen)
	buffer.writeu8(b.flags, g, if eventPrey then EVENT else 0)
	buffer.writeu8(b.count, g, count)
	buffer.writeu32(b.alive, o4, 2 ^ count - 1)
	buffer.writeu16(b.seed, g * 2, seed)
	buffer.writeu16(b.home, g * 2, home)
	buffer.writef32(b.posX, o4, x)
	buffer.writef32(b.posY, o4, y)
	buffer.writef32(b.posZ, o4, z)
	buffer.writef32(b.velX, o4, 0)
	buffer.writef32(b.velY, o4, 0)
	buffer.writef32(b.velZ, o4, 0)
	buffer.writef32(b.scatter, o4, 0)
	buffer.writef32(b.stateUntil, o4, 0)
	buffer.writef32(b.wanderUntil, o4, 0)
	buffer.writef32(b.respawnAt, o4, 0)
	buffer.writef32(b.burstUntil, o4, 0)
	SpatialGrid.insert(sim.grid, g, x, z)
	-- Fill the whole history ring with the spawn point and a seeded heading.
	local heading = seed % 256
	local base = g * HIST * HIST_BYTES
	local qx, qy, qz = Quantize.x(x), Quantize.y(y), Quantize.z(z)
	for k = 0, HIST - 1 do
		local o = base + k * HIST_BYTES
		buffer.writeu16(b.histPos, o, qx)
		buffer.writeu16(b.histPos, o + 2, qy)
		buffer.writeu16(b.histPos, o + 4, qz)
		buffer.writeu8(b.histPos, o + 6, 0)
		buffer.writeu8(b.histPos, o + 7, heading)
	end
	buffer.writeu8(b.histHead, g, sim.tick % HIST)
	sim.liveGroups += 1
	return g, gen
end

--- Frees a group's slot (eaten out, straggler or event despawn). Its gen stays, so the next spawn
--- in the slot gets gen + 1.
function PreySim.remove(sim: Sim, g: number)
	local b = sim.buffers
	if buffer.readu8(b.kind, g) == 0 then
		return
	end
	buffer.writeu8(b.kind, g, 0)
	buffer.writeu8(b.flags, g, 0)
	buffer.writeu32(b.alive, g * 4, 0)
	SpatialGrid.remove(sim.grid, g)
	sim.liveGroups -= 1
end

--- True when group `g` is live, and has generation `gen` if one is given.
function PreySim.isLive(sim: Sim, g: number, gen: number?): boolean
	if g < 0 or g >= MAX_GROUPS or g % 1 ~= 0 then
		return false
	end
	local b = sim.buffers
	return buffer.readu8(b.kind, g) ~= 0 and (gen == nil or buffer.readu8(b.gen, g) == gen)
end

--- True when member `i` of group `g` is alive.
function PreySim.memberAlive(sim: Sim, g: number, i: number): boolean
	if i < 0 or i >= PreySim.MAX_MEMBERS or not PreySim.isLive(sim, g) then
		return false
	end
	return bit32.btest(buffer.readu32(sim.buffers.alive, g * 4), bit32.lshift(1, i))
end

--- Clears member `i`'s alive bit and returns how many members are still alive. The caller removes
--- the group or turns it into stragglers (02 §9.2).
function PreySim.clearMember(sim: Sim, g: number, i: number): number
	local b = sim.buffers
	local alive = bit32.band(buffer.readu32(b.alive, g * 4), bit32.bnot(bit32.lshift(1, i)))
	buffer.writeu32(b.alive, g * 4, alive)
	return PreySim.aliveCount(sim, g)
end

--- Members still alive in group `g`.
function PreySim.aliveCount(sim: Sim, g: number): number
	local alive = buffer.readu32(sim.buffers.alive, g * 4)
	local n = 0
	while alive ~= 0 do
		alive = bit32.band(alive, alive - 1)
		n += 1
	end
	return n
end

--- Freezes every live group of prey tier ≤ maxTier within r of (x, y, z) for `seconds` (Spark,
--- 02 §9.2: whatever its state). Returns how many groups were stunned.
function PreySim.stunNear(
	sim: Sim,
	x: number,
	y: number,
	z: number,
	r: number,
	maxTier: number,
	seconds: number,
	now: number
): number
	local b, grid = sim.buffers, sim.grid
	local c0, c1, r0, r1 = SpatialGrid.range(x, z, r)
	local r2 = r * r
	local n = 0
	for row = r0, r1 do
		for col = c0, c1 do
			local g = buffer.readu16(grid.cellHead, (row * SpatialGrid.SIDE + col) * 2)
			while g ~= NONE do
				local kind = buffer.readu8(b.kind, g)
				if kTier[kind + 1] <= maxTier then
					local o4 = g * 4
					local dx = buffer.readf32(b.posX, o4) - x
					local dy = buffer.readf32(b.posY, o4) - y
					local dz = buffer.readf32(b.posZ, o4) - z
					if dx * dx + dy * dy + dz * dz <= r2 then
						local flags = buffer.readu8(b.flags, g)
						flags = bit32.bor(bit32.band(flags, bit32.bnot(FLEEING + LURED)), STUNNED)
						buffer.writeu8(b.flags, g, flags)
						buffer.writef32(b.stateUntil, o4, now + seconds)
						buffer.writef32(b.velX, o4, 0)
						buffer.writef32(b.velY, o4, 0)
						buffer.writef32(b.velZ, o4, 0)
						buffer.writef32(b.wanderUntil, o4, 0)
						n += 1
					end
				end
				g = buffer.readu16(grid.next, g * 2)
			end
		end
	end
	return n
end

--- Writes the IDs of the groups in the cells a circle of radius r around (x, z) touches into `out`
--- and returns the count: a superset, the caller tests distance (SpatialGrid.query).
function PreySim.query(sim: Sim, x: number, z: number, r: number, out: { number }): number
	return SpatialGrid.query(sim.grid, x, z, r, out)
end

-- Step 1: the threat pass. Returns how many groups it reached (in `touched`).
local function threatPass(sim: Sim, now: number): number
	local b, grid = sim.buffers, sim.grid
	local threats, threatFlags = sim.threats, sim.threatFlags
	local bestD2, bestThreat, stamp, touched = sim.bestD2, sim.bestThreat, sim.stamp, sim.touched
	local tick = sim.tick
	local nTouched = 0
	for t = 0, sim.threatCount - 1 do
		local tf = buffer.readu8(threatFlags, t)
		local eatTier = buffer.readf64(threats, t * 32 + 24)
		if bit32.btest(tf, T_HIDDEN) or eatTier < 0 then
			continue
		end
		local tx = buffer.readf64(threats, t * 32)
		local ty = buffer.readf64(threats, t * 32 + 8)
		local tz = buffer.readf64(threats, t * 32 + 16)
		local lures = bit32.band(tf, T_PLAYER + T_MOONLIT) == T_PLAYER + T_MOONLIT
		local c0, c1, r0, r1 = SpatialGrid.range(tx, tz, reactRange)
		for row = r0, r1 do
			for col = c0, c1 do
				local g = buffer.readu16(grid.cellHead, (row * 32 + col) * 2)
				while g ~= NONE do
					local k1 = buffer.readu8(b.kind, g) + 1
					local fleeR2 = kFleeR2[k1]
					if kTier[k1] <= eatTier and fleeR2 > 0 then
						local o4 = g * 4
						local dx = buffer.readf32(b.posX, o4) - tx
						local dy = buffer.readf32(b.posY, o4) - ty
						local dz = buffer.readf32(b.posZ, o4) - tz
						local d2 = dx * dx + dy * dy + dz * dz
						if d2 <= fleeR2 or (lures and d2 <= LURE_RANGE * LURE_RANGE) then
							if buffer.readu32(stamp, o4) ~= tick then
								buffer.writeu32(stamp, o4, tick)
								buffer.writef64(bestD2, g * 8, d2)
								buffer.writeu8(bestThreat, g, t)
								buffer.writeu16(touched, nTouched * 2, g)
								nTouched += 1
							elseif d2 < buffer.readf64(bestD2, g * 8) then
								buffer.writef64(bestD2, g * 8, d2)
								buffer.writeu8(bestThreat, g, t)
							end
						end
					end
					g = buffer.readu16(grid.next, g * 2)
				end
			end
		end
	end
	-- Apply the nearest threat of each group reached.
	for n = 0, nTouched - 1 do
		local g = buffer.readu16(touched, n * 2)
		local o4 = g * 4
		local flags = buffer.readu8(b.flags, g)
		if bit32.btest(flags, STUNNED) then
			continue
		end
		local t = buffer.readu8(bestThreat, g)
		local tf = buffer.readu8(threatFlags, t)
		local tx = buffer.readf64(threats, t * 32)
		local ty = buffer.readf64(threats, t * 32 + 8)
		local tz = buffer.readf64(threats, t * 32 + 16)
		local d2 = buffer.readf64(bestD2, g * 8)
		local k1 = buffer.readu8(b.kind, g) + 1
		if
			bit32.band(tf, T_PLAYER + T_MOONLIT) == T_PLAYER + T_MOONLIT
			and d2 <= LURE_RANGE * LURE_RANGE
		then
			buffer.writeu8(b.flags, g, bit32.bor(bit32.band(flags, bit32.bnot(FLEEING)), LURED))
			buffer.writef32(b.wanderX, o4, tx)
			buffer.writef32(b.wanderY, o4, ty)
			buffer.writef32(b.wanderZ, o4, tz)
			buffer.writef32(b.wanderUntil, o4, 0)
			continue
		end
		if d2 > kFleeR2[k1] then
			continue
		end
		local fleeing = bit32.btest(flags, FLEEING)
		local burstUntil = buffer.readf32(b.burstUntil, o4)
		if not fleeing then
			if now < burstUntil then
				continue -- tired: cruise only until the window ends
			end
			burstUntil = now + kBurst[k1]
			buffer.writef32(b.burstUntil, o4, burstUntil)
			buffer.writeu8(b.flags, g, bit32.bor(flags, FLEEING))
		end
		buffer.writef32(b.stateUntil, o4, math.min(now + FLEE_HOLD, burstUntil))
		local dx = buffer.readf32(b.posX, o4) - tx
		local dy = buffer.readf32(b.posY, o4) - ty
		local dz = buffer.readf32(b.posZ, o4) - tz
		if kBehaviour[k1] == HOP then
			dy = 0
		end
		local len = math.sqrt(dx * dx + dy * dy + dz * dz)
		if len < 1e-3 then
			-- On top of the threat: flee along the current heading, or +Z.
			dx, dy, dz = buffer.readf32(b.velX, o4), 0, buffer.readf32(b.velZ, o4)
			len = math.sqrt(dx * dx + dz * dz)
			if len < 1e-3 then
				dx, dz, len = 0, 1, 1
			end
		end
		buffer.writef32(b.wanderX, o4, dx / len)
		buffer.writef32(b.wanderY, o4, dy / len)
		buffer.writef32(b.wanderZ, o4, dz / len)
		buffer.writef32(b.wanderUntil, o4, 0)
	end
	return nTouched
end

-- A new seeded wander target for group g inside its home.
local function pickWander(sim: Sim, g: number, now: number, code: number, px: number, pz: number)
	local b, rng, homes = sim.buffers, sim.rng, sim.homes
	local o4 = g * 4
	local h = buffer.readu16(b.home, g * 2) * 20
	local cx = buffer.readf32(homes, h)
	local cy = buffer.readf32(homes, h + 4)
	local cz = buffer.readf32(homes, h + 8)
	local radius = buffer.readf32(homes, h + 12)
	local half = buffer.readf32(homes, h + 16)
	local angle = Rng.next(rng) * TAU
	local r = radius * 0.9 * math.sqrt(Rng.next(rng))
	local tx, tz = cx + r * math.cos(angle), cz + r * math.sin(angle)
	if code == RUN then
		-- Straight runs: aim across the home, through its middle (02 §9.2 lanes, simplified).
		local ax, az = cx - (px - cx), cz - (pz - cz)
		local jitter = radius * 0.25
		tx = ax + (Rng.next(rng) * 2 - 1) * jitter
		tz = az + (Rng.next(rng) * 2 - 1) * jitter
	end
	buffer.writef32(b.wanderX, o4, tx)
	buffer.writef32(b.wanderY, o4, cy + half * 0.8 * (Rng.next(rng) * 2 - 1))
	buffer.writef32(b.wanderZ, o4, tz)
	buffer.writef32(b.wanderUntil, o4, now + Rng.range(rng, WANDER_MIN, WANDER_MAX))
end

-- Steps 2 to 4 for one group.
local function stepGroup(sim: Sim, g: number, now: number, dt: number)
	local b, homes = sim.buffers, sim.homes
	local o4 = g * 4
	local k1 = buffer.readu8(b.kind, g) + 1
	local code = kBehaviour[k1]
	local flags = buffer.readu8(b.flags, g)
	local px = buffer.readf32(b.posX, o4)
	local py = buffer.readf32(b.posY, o4)
	local pz = buffer.readf32(b.posZ, o4)
	local vx = buffer.readf32(b.velX, o4)
	local vy = buffer.readf32(b.velY, o4)
	local vz = buffer.readf32(b.velZ, o4)
	local scatter = buffer.readf32(b.scatter, o4)
	local scatterTarget = 0

	-- Stunned: frozen in place whatever its state (02 §9.2).
	if bit32.btest(flags, STUNNED) then
		if now < buffer.readf32(b.stateUntil, o4) then
			buffer.writef32(b.velX, o4, 0)
			buffer.writef32(b.velY, o4, 0)
			buffer.writef32(b.velZ, o4, 0)
			return
		end
		flags = bit32.band(flags, bit32.bnot(STUNNED))
	end

	-- Step 2, steer.
	local dvx, dvy, dvz = 0, 0, 0
	local fleeing = false
	if bit32.btest(flags, FLEEING) then
		local burstUntil = buffer.readf32(b.burstUntil, o4)
		if now >= buffer.readf32(b.stateUntil, o4) or now >= burstUntil then
			-- The flee is over: tired for 2 s, then free to flee again.
			flags = bit32.band(flags, bit32.bnot(FLEEING))
			buffer.writef32(b.burstUntil, o4, now + TIRED)
		else
			fleeing = true
			local speed = kFlee[k1]
			dvx = buffer.readf32(b.wanderX, o4) * speed
			dvy = buffer.readf32(b.wanderY, o4) * speed
			dvz = buffer.readf32(b.wanderZ, o4) * speed
			-- Swarms and packs scatter for the whole flee, schools for its first second.
			local schoolBurst = code == SCHOOL and now < burstUntil - kBurst[k1] + SCHOOL_SCATTER
			if code == SWARM or code == PACK or schoolBurst then
				scatterTarget = 1
			end
		end
	end
	if not fleeing then
		if bit32.btest(flags, LURED) then
			local dx = buffer.readf32(b.wanderX, o4) - px
			local dy = buffer.readf32(b.wanderY, o4) - py
			local dz = buffer.readf32(b.wanderZ, o4) - pz
			local len = math.sqrt(dx * dx + dy * dy + dz * dz)
			if len > 1 then
				dvx, dvy, dvz = dx / len * LURE_SPEED, dy / len * LURE_SPEED, dz / len * LURE_SPEED
			end
			flags = bit32.band(flags, bit32.bnot(LURED)) -- set again by the next threat pass
		else
			local until_ = buffer.readf32(b.wanderUntil, o4)
			local wx = buffer.readf32(b.wanderX, o4)
			local wy = buffer.readf32(b.wanderY, o4)
			local wz = buffer.readf32(b.wanderZ, o4)
			local dx, dy, dz = wx - px, wy - py, wz - pz
			local d2 = dx * dx + dy * dy + dz * dz
			if now >= until_ or d2 < WANDER_REACHED * WANDER_REACHED then
				pickWander(sim, g, now, code, px, pz)
				wx = buffer.readf32(b.wanderX, o4)
				wy = buffer.readf32(b.wanderY, o4)
				wz = buffer.readf32(b.wanderZ, o4)
				dx, dy, dz = wx - px, wy - py, wz - pz
				d2 = dx * dx + dy * dy + dz * dz
			end
			if d2 > 1e-6 then
				local len = math.sqrt(d2)
				local speed = kCruise[k1]
				dvx, dvy, dvz = dx / len * speed, dy / len * speed, dz / len * speed
			end
		end
	end
	if code == HOP then
		dvy = 0
	end

	-- Step 4a, leash pull: outside the home, steer back, at full strength by 1.5 × radius.
	local h = buffer.readu16(b.home, g * 2) * 20
	local cx = buffer.readf32(homes, h)
	local cy = buffer.readf32(homes, h + 4)
	local cz = buffer.readf32(homes, h + 8)
	local radius = buffer.readf32(homes, h + 12)
	local half = buffer.readf32(homes, h + 16)
	local ox, oz = px - cx, pz - cz
	local horiz = math.sqrt(ox * ox + oz * oz)
	local pullSpeed = math.max(kFlee[k1], kCruise[k1])
	if horiz > radius then
		local w = math.min(1, (horiz - radius) / ((LEASH_CLAMP - 1) * radius))
		-- Cancel the outward part of the desired velocity, then pull inward.
		local nx, nz = ox / horiz, oz / horiz
		local outward = dvx * nx + dvz * nz
		if outward > 0 then
			dvx -= nx * outward * w
			dvz -= nz * outward * w
		end
		dvx -= nx * pullSpeed * w
		dvz -= nz * pullSpeed * w
	end
	if code ~= HOP and half > 0 then
		local oy = py - cy
		local ay = math.abs(oy)
		if ay > half then
			local w = math.min(1, (ay - half) / ((LEASH_CLAMP - 1) * half))
			local ny = if oy > 0 then 1 else -1
			if dvy * ny > 0 then
				dvy -= dvy * w
			end
			dvy -= ny * pullSpeed * w
		end
	end

	-- Step 3, integrate.
	local ex, ey, ez = dvx - vx, dvy - vy, dvz - vz
	local e = math.sqrt(ex * ex + ey * ey + ez * ez)
	local maxDv = kAccel[k1] * dt
	if e > maxDv then
		local s = maxDv / e
		ex, ey, ez = ex * s, ey * s, ez * s
	end
	vx, vy, vz = vx + ex, vy + ey, vz + ez
	px, py, pz = px + vx * dt, py + vy * dt, pz + vz * dt
	if scatter < scatterTarget then
		scatter = math.min(scatterTarget, scatter + SCATTER_UP * dt)
	elseif scatter > scatterTarget then
		scatter = math.max(scatterTarget, scatter - SCATTER_DOWN * dt)
	end

	-- Step 4b, leash clamp at 1.5 × the home's size.
	ox, oz = px - cx, pz - cz
	horiz = math.sqrt(ox * ox + oz * oz)
	local limit = LEASH_CLAMP * radius
	if horiz > limit then
		local s = limit / horiz
		px, pz = cx + ox * s, cz + oz * s
		-- Drop the outward part of the velocity.
		local nx, nz = ox / horiz, oz / horiz
		local outward = vx * nx + vz * nz
		if outward > 0 then
			vx -= nx * outward
			vz -= nz * outward
		end
	end
	if code == HOP then
		local floorY = sim.floorY
		local floor = if floorY then floorY(px, pz) else cy - half
		local period = if fleeing then HOP_FLEE else HOP_CALM
		local seedPhase = buffer.readu16(b.seed, g * 2) / 0x10000
		local phase = (now / period + seedPhase) % 1
		py = floor + 4 * HOP_HEIGHT * phase * (1 - phase)
		vy = 0
	else
		local yLimit = LEASH_CLAMP * half
		if py > cy + yLimit then
			py = cy + yLimit
			vy = math.min(vy, 0)
		elseif py < cy - yLimit then
			py = cy - yLimit
			vy = math.max(vy, 0)
		end
	end

	buffer.writef32(b.posX, o4, px)
	buffer.writef32(b.posY, o4, py)
	buffer.writef32(b.posZ, o4, pz)
	buffer.writef32(b.velX, o4, vx)
	buffer.writef32(b.velY, o4, vy)
	buffer.writef32(b.velZ, o4, vz)
	buffer.writef32(b.scatter, o4, scatter)
	buffer.writeu8(b.flags, g, flags)
	SpatialGrid.move(sim.grid, g, px, pz)
end

--- One 10 Hz tick at time `now` (seconds since ServerEpoch) with step `dt` (0.1): activity, threat
--- pass, steer, integrate, leash, history. Threats are whatever `setThreat` last wrote.
function PreySim.step(sim: Sim, now: number, dt: number)
	profileBegin("PreySim.step")
	local b = sim.buffers
	sim.tick += 1
	sim.now = now
	local tick = sim.tick
	local head = tick % HIST
	buffer.writef64(sim.histTime, head * 8, now)

	threatPass(sim, now)

	local threats, threatFlags, threatCount = sim.threats, sim.threatFlags, sim.threatCount
	local active2 = ACTIVE_RANGE * ACTIVE_RANGE
	for g = 0, MAX_GROUPS - 1 do
		if buffer.readu8(b.kind, g) == 0 then
			continue
		end
		local o4 = g * 4
		local x = buffer.readf32(b.posX, o4)
		local y = buffer.readf32(b.posY, o4)
		local z = buffer.readf32(b.posZ, o4)
		-- Step 0, activity: any player within 700 studs.
		local active = false
		for t = 0, threatCount - 1 do
			if bit32.btest(buffer.readu8(threatFlags, t), T_PLAYER) then
				local dx = buffer.readf64(threats, t * 32) - x
				local dy = buffer.readf64(threats, t * 32 + 8) - y
				local dz = buffer.readf64(threats, t * 32 + 16) - z
				if dx * dx + dy * dy + dz * dz <= active2 then
					active = true
					break
				end
			end
		end
		local flags = buffer.readu8(b.flags, g)
		if active then
			buffer.writeu8(b.flags, g, bit32.band(flags, bit32.bnot(DORMANT)))
			stepGroup(sim, g, now, dt)
		else
			buffer.writeu8(b.flags, g, bit32.bor(flags, DORMANT))
			if (tick + g) % DORMANT_EVERY == 0 then
				stepGroup(sim, g, now, dt * DORMANT_EVERY)
			end
		end
		-- Step 5, history.
		writeHistory(
			b,
			g,
			head,
			buffer.readf32(b.posX, o4),
			buffer.readf32(b.posY, o4),
			buffer.readf32(b.posZ, o4),
			buffer.readf32(b.scatter, o4)
		)
	end
	profileEnd()
end

local function lerp(a: number, c: number, alpha: number): number
	return a + (c - a) * alpha
end

--- Heading in radians of a group now: from its velocity, else its last recorded heading.
function PreySim.heading(sim: Sim, g: number): number
	local b = sim.buffers
	local vx, vz = buffer.readf32(b.velX, g * 4), buffer.readf32(b.velZ, g * 4)
	if vx * vx + vz * vz >= 0.0025 then
		return math.atan2(vx, vz)
	end
	local headSample = buffer.readu8(b.histHead, g)
	return buffer.readu8(b.histPos, g * HIST * HIST_BYTES + headSample * HIST_BYTES + 7) / 256 * TAU
end

--- Position of member `member` of group `g` at time `t` (seconds since ServerEpoch), from the
--- group's history ring and Formation (8.9). Between samples it interpolates; before the oldest it
--- uses the oldest; after the newest it extrapolates the live state by at most one tick. The caller
--- checks the group is live and the gen matches first.
function PreySim.memberPosAt(
	sim: Sim,
	g: number,
	member: number,
	t: number
): (number, number, number)
	local b = sim.buffers
	local kind = buffer.readu8(b.kind, g)
	local seed = buffer.readu16(b.seed, g * 2)
	local head = buffer.readu8(b.histHead, g)
	local newest = buffer.readf64(sim.histTime, head * 8)
	if t >= newest or sim.tick == 0 then
		local o4 = g * 4
		local ahead = math.clamp(t - newest, 0, 0.1)
		return Formation.memberPos(
			kind,
			seed,
			member,
			buffer.readf32(b.posX, o4) + buffer.readf32(b.velX, o4) * ahead,
			buffer.readf32(b.posY, o4) + buffer.readf32(b.velY, o4) * ahead,
			buffer.readf32(b.posZ, o4) + buffer.readf32(b.velZ, o4) * ahead,
			PreySim.heading(sim, g),
			buffer.readf32(b.scatter, o4)
		)
	end
	local base = g * HIST * HIST_BYTES
	local hist = b.histPos
	local samples = math.min(HIST, sim.tick)
	-- Walk back from the newest sample to the first one at or before t.
	local newer = head
	local older = head
	local alpha = 0
	for k = 1, samples - 1 do
		local candidate = (head - k) % HIST
		local tc = buffer.readf64(sim.histTime, candidate * 8)
		older = candidate
		if tc <= t then
			local tn = buffer.readf64(sim.histTime, newer * 8)
			alpha = if tn > tc then (t - tc) / (tn - tc) else 0
			break
		end
		newer = candidate
		alpha = 0 -- before the oldest sample: use the oldest
	end
	if older == newer then
		alpha = 0
	end
	local oo, on = base + older * HIST_BYTES, base + newer * HIST_BYTES
	local gx = lerp(
		Quantize.fromX(buffer.readu16(hist, oo)),
		Quantize.fromX(buffer.readu16(hist, on)),
		alpha
	)
	local gy = lerp(
		Quantize.fromY(buffer.readu16(hist, oo + 2)),
		Quantize.fromY(buffer.readu16(hist, on + 2)),
		alpha
	)
	local gz = lerp(
		Quantize.fromZ(buffer.readu16(hist, oo + 4)),
		Quantize.fromZ(buffer.readu16(hist, on + 4)),
		alpha
	)
	local sc = lerp(
		Quantize.fromScatter(buffer.readu8(hist, oo + 6)),
		Quantize.fromScatter(buffer.readu8(hist, on + 6)),
		alpha
	)
	local h0 = buffer.readu8(hist, oo + 7)
	local dh = (buffer.readu8(hist, on + 7) - h0 + 128) % 256 - 128 -- shortest way round
	local heading = (h0 + dh * alpha) / 256 * TAU
	return Formation.memberPos(kind, seed, member, gx, gy, gz, heading, sc)
end

return table.freeze(PreySim)
