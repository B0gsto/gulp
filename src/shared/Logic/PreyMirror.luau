--!strict
--!native
--!optimize 2
-- PreyMirror: the client's table of known prey groups (task S3-C4; module B17, first part;
-- docs/09, sections 8.5, 8.7 and 8.8). Pure, so it runs in Lune; Render/PreyRenderer draws from it.
--
--   Packets   `PreyState` payloads are checked by the codec (`valid`), then dropped when their
--             `seq` is not newer than the newest seen (8.7; u16, so the comparison wraps). A full
--             record adds a group, or replaces it when its `gen` or kind changed; a delta record
--             for a group the client does not know is ignored (8.7: the next keyframe fixes it).
--   Events    `PreyEvent` records clear (eaten) or set (restored) a member's alive bit, or drop the
--             group (removed). A record whose `gen` differs from the group's is stale and ignored.
--   Drop rule A group not heard about for 3 s is dropped (8.5, `Out` band).
--   Dead reckoning  target = lastPos + lastVel × (now − lastTime), times in server seconds since
--             ServerEpoch (`timeMs` / 1000). The drawn position eases toward the target with a
--             0.1 s time constant, so a new packet never pops (8.8). A group's first record snaps.
--             The heading (Formation's: atan2(velX, velZ)) eases the same way along the shorter
--             arc and is kept while the group is still.
--   Pools     `assign` gives the mesh budget (8.8 and 15.1: tune.quality.preyMeshes, within
--             tune.quality.preyMeshDistance; the renderer passes both) to the nearest groups
--             first, whole groups while it lasts; the group where it runs out is drawn in part, and the rest of it, like every group past the mesh range, falls to
--             particles (part 2, S4-C1).
--
-- Hot path (09 §4.7): the group table is arrays indexed by groupId + 1, preallocated for the 512
-- IDs the codec allows; `applyPacket`, `step` and `assign` allocate nothing once warm.
local PreyEvent = require("../Net/Codec/PreyEvent")
local PreyState = require("../Net/Codec/PreyState")
local Quantize = require("../Sim/Quantize")

export type GraphicsTier = "Smooth" | "Balanced" | "Pretty"

export type Mirror = {
	-- Per group, indexed by groupId + 1.
	live: { boolean },
	gen: { number },
	kind: { number },
	count: { number }, -- members at spawn, 1 to 24
	alive: { number }, -- bit i set = member i alive
	seed: { number },
	flags: { number },
	scatter: { number }, -- 0 to 1
	px: { number }, -- last reported position, studs
	py: { number },
	pz: { number },
	vx: { number }, -- last reported velocity, studs/s
	vy: { number },
	vz: { number },
	t0: { number }, -- server seconds of the last record
	heard: { number }, -- local clock seconds of the last record (the 3 s rule)
	dx: { number }, -- drawn position
	dy: { number },
	dz: { number },
	heading: { number }, -- drawn heading, radians
	snap: { boolean }, -- the next `step` snaps instead of easing
	dist: { number }, -- distance to the viewer at the last `assign`
	drawn: { number }, -- members drawn as meshes at the last `assign`
	-- The live group IDs, in no order, and each one's place in that list.
	ids: { number },
	at: { number },
	-- Live group IDs nearest first, as of the last `assign` (kept between frames: nearly sorted).
	order: { number },
	newestSeq: number,
	hasSeq: boolean,
	fullScratch: PreyState.Full,
	deltaScratch: PreyState.Delta,
}

local PreyMirror = {}

PreyMirror.MAX_GROUPS = PreyState.MAX_GROUPS -- 512
--- 8.5: a group not heard about for this long is dropped.
PreyMirror.DROP_AFTER = 3 -- seconds
--- 8.8: time constant of the ease toward the dead-reckoned target.
PreyMirror.EASE_TAU = 0.1 -- seconds
--- 8.5: the default mesh range, the outer edge of the Mid band; the renderer passes its graphics
--- tier's prey mesh distance (150, 250, 350 studs, 15.1). Past it, and on Smooth the whole Mid
--- band, groups are particles.
PreyMirror.MESH_RANGE = 350 -- studs (tune)
--- Below this speed a group keeps its heading.
PreyMirror.STILL_SPEED = 0.25 -- studs/s

local N = PreyState.MAX_GROUPS
local TWO_PI = 2 * math.pi

function PreyMirror.new(): Mirror
	return {
		live = table.create(N, false),
		gen = table.create(N, 0),
		kind = table.create(N, 0),
		count = table.create(N, 0),
		alive = table.create(N, 0),
		seed = table.create(N, 0),
		flags = table.create(N, 0),
		scatter = table.create(N, 0),
		px = table.create(N, 0),
		py = table.create(N, 0),
		pz = table.create(N, 0),
		vx = table.create(N, 0),
		vy = table.create(N, 0),
		vz = table.create(N, 0),
		t0 = table.create(N, 0),
		heard = table.create(N, 0),
		dx = table.create(N, 0),
		dy = table.create(N, 0),
		dz = table.create(N, 0),
		heading = table.create(N, 0),
		snap = table.create(N, false),
		dist = table.create(N, 0),
		drawn = table.create(N, 0),
		ids = table.create(N),
		at = table.create(N, 0),
		order = table.create(N),
		newestSeq = 0,
		hasSeq = false,
		fullScratch = PreyState.newFull(),
		deltaScratch = PreyState.newDelta(),
	}
end

--- Live groups.
function PreyMirror.size(m: Mirror): number
	return #m.ids
end

--- True when `seq` is newer than every packet seen so far, and records it as the newest. u16
--- order wraps: a seq up to 32767 ahead of the newest is newer.
function PreyMirror.acceptSeq(m: Mirror, seq: number): boolean
	if m.hasSeq then
		local ahead = (seq - m.newestSeq) % 65536
		if ahead == 0 or ahead >= 32768 then
			return false
		end
	end
	m.newestSeq = seq
	m.hasSeq = true
	return true
end

local function add(m: Mirror, i: number)
	m.live[i] = true
	table.insert(m.ids, i - 1)
	m.at[i] = #m.ids
end

--- Forgets group `groupId`. False when it was not known.
function PreyMirror.remove(m: Mirror, groupId: number): boolean
	local i = groupId + 1
	if not m.live[i] then
		return false
	end
	m.live[i] = false
	m.drawn[i] = 0
	local ids = m.ids
	local place, last = m.at[i], #ids
	local moved = ids[last]
	ids[place] = moved
	m.at[moved + 1] = place
	ids[last] = nil
	return true
end

local function setMotion(m: Mirror, i: number, qvx: number, qvy: number, qvz: number)
	m.vx[i], m.vy[i], m.vz[i] = Quantize.fromVel(qvx), Quantize.fromVel(qvy), Quantize.fromVel(qvz)
end

--- Applies one full record heard at server time `t` (seconds) and local clock `now`.
function PreyMirror.applyFull(m: Mirror, r: PreyState.Full, t: number, now: number)
	local i = r.groupId + 1
	if not m.live[i] then
		add(m, i)
		m.snap[i] = true
	elseif m.gen[i] ~= r.gen or m.kind[i] ~= r.kind then
		-- The ID was reused for a new group (8.2 `gen`): start it fresh.
		m.snap[i] = true
	end
	m.gen[i], m.kind[i], m.count[i], m.alive[i], m.seed[i] = r.gen, r.kind, r.count, r.alive, r.seed
	m.flags[i], m.scatter[i] = r.flags, Quantize.fromScatter(r.scatter)
	m.px[i], m.py[i], m.pz[i] = Quantize.fromX(r.qx), Quantize.fromY(r.qy), Quantize.fromZ(r.qz)
	setMotion(m, i, r.qvx, r.qvy, r.qvz)
	m.t0[i], m.heard[i] = t, now
end

--- Applies one delta record; ignored (false) for a group the client does not know (8.7).
function PreyMirror.applyDelta(m: Mirror, r: PreyState.Delta, t: number, now: number): boolean
	local i = r.groupId + 1
	if not m.live[i] then
		return false
	end
	m.flags[i], m.scatter[i] = r.flags, Quantize.fromScatter(r.scatter)
	m.px[i], m.py[i], m.pz[i] = Quantize.fromX(r.qx), Quantize.fromY(r.qy), Quantize.fromZ(r.qz)
	setMotion(m, i, r.qvx, r.qvy, r.qvz)
	m.t0[i], m.heard[i] = t, now
	return true
end

--- Applies a `PreyState` payload heard at local clock `now`. False, and nothing changes, when the
--- payload is malformed or not newer than the newest packet seen.
function PreyMirror.applyPacket(m: Mirror, payload: buffer, now: number): boolean
	if not PreyState.valid(payload) then
		return false
	end
	local seq, timeMs, fullCount, deltaCount = PreyState.header(payload)
	if not PreyMirror.acceptSeq(m, seq) then
		return false
	end
	local t = timeMs / 1000
	local full, delta = m.fullScratch, m.deltaScratch
	for k = 0, fullCount - 1 do
		PreyState.readFull(payload, k, full)
		PreyMirror.applyFull(m, full, t, now)
	end
	for k = 0, deltaCount - 1 do
		PreyState.readDelta(payload, fullCount, k, delta)
		PreyMirror.applyDelta(m, delta, t, now)
	end
	return true
end

--- Applies one `PreyEvent` record. False when it changed nothing (unknown group, other `gen`).
function PreyMirror.applyEvent(
	m: Mirror,
	op: number,
	groupId: number,
	gen: number,
	member: number
): boolean
	local i = groupId + 1
	if not m.live[i] or m.gen[i] ~= gen then
		return false
	end
	if op == PreyEvent.OP_REMOVED then
		return PreyMirror.remove(m, groupId)
	end
	local bit = bit32.lshift(1, member)
	local before = m.alive[i]
	if op == PreyEvent.OP_EATEN then
		m.alive[i] = bit32.band(before, bit32.bnot(bit))
	elseif op == PreyEvent.OP_RESTORED and member < m.count[i] then
		m.alive[i] = bit32.bor(before, bit)
	end
	return m.alive[i] ~= before
end

--- Applies every record of a `PreyEvent` payload; false when it is malformed.
function PreyMirror.applyEvents(m: Mirror, payload: buffer): boolean
	if not PreyEvent.valid(payload) then
		return false
	end
	for k = 0, PreyEvent.count(payload) - 1 do
		local op, groupId, gen, member = PreyEvent.read(payload, k)
		PreyMirror.applyEvent(m, op, groupId, gen, member)
	end
	return true
end

--- The 3 s rule (8.5): drops every group not heard about since `now − DROP_AFTER`. Returns how
--- many were dropped.
function PreyMirror.dropStale(m: Mirror, now: number): number
	local ids, heard = m.ids, m.heard
	local limit = now - PreyMirror.DROP_AFTER
	local dropped = 0
	local k = #ids
	while k >= 1 do
		local id = ids[k]
		if heard[id + 1] < limit then
			PreyMirror.remove(m, id)
			dropped += 1
		end
		k -= 1
	end
	return dropped
end

--- Where the client believes group `groupId` is at server time `t`: lastPos + lastVel × elapsed.
function PreyMirror.target(m: Mirror, groupId: number, t: number): (number, number, number)
	local i = groupId + 1
	local e = t - m.t0[i]
	return m.px[i] + m.vx[i] * e, m.py[i] + m.vy[i] * e, m.pz[i] + m.vz[i] * e
end

--- The share of the remaining gap an ease with time constant `tau` closes in `dt` seconds.
function PreyMirror.easeAlpha(dt: number, tau: number): number
	if dt <= 0 then
		return 0
	end
	return 1 - math.exp(-dt / tau)
end

-- The signed angle from `a` to `b` along the shorter arc, in (−π, π].
local function arc(a: number, b: number): number
	local d = (b - a) % TWO_PI
	if d > math.pi then
		d -= TWO_PI
	end
	return d
end

--- Advances every drawn position and heading toward its dead-reckoned target at server time `t`,
--- `dt` seconds after the last call.
function PreyMirror.step(m: Mirror, t: number, dt: number)
	local alpha = PreyMirror.easeAlpha(dt, PreyMirror.EASE_TAU)
	local still2 = PreyMirror.STILL_SPEED * PreyMirror.STILL_SPEED
	local px, py, pz, vx, vy, vz, t0 = m.px, m.py, m.pz, m.vx, m.vy, m.vz, m.t0
	local dx, dy, dz, heading, snap = m.dx, m.dy, m.dz, m.heading, m.snap
	for _, id in m.ids do
		local i = id + 1
		local e = t - t0[i]
		local gvx, gvz = vx[i], vz[i]
		local tx, ty, tz = px[i] + gvx * e, py[i] + vy[i] * e, pz[i] + gvz * e
		local moving = gvx * gvx + gvz * gvz > still2
		if snap[i] then
			snap[i] = false
			dx[i], dy[i], dz[i] = tx, ty, tz
			if moving then
				heading[i] = math.atan2(gvx, gvz)
			end
		else
			dx[i] += (tx - dx[i]) * alpha
			dy[i] += (ty - dy[i]) * alpha
			dz[i] += (tz - dz[i]) * alpha
			if moving then
				local h = heading[i]
				heading[i] = h + arc(h, math.atan2(gvx, gvz)) * alpha
			end
		end
	end
end

--- Members alive in a mask of `count` members.
function PreyMirror.aliveCount(mask: number, count: number): number
	local n = 0
	for b = 0, count - 1 do
		if bit32.btest(mask, bit32.lshift(1, b)) then
			n += 1
		end
	end
	return n
end

--- Shares `budget` meshes among the groups nearest the viewer at (x, y, z), nearest first, whole
--- groups while it lasts (8.8). Groups past `range` studs (default MESH_RANGE) get none. Writes
--- `m.drawn` and `m.dist` and leaves `m.order` nearest first; returns the meshes given and how
--- many entries at the front of `m.order` have any.
function PreyMirror.assign(
	m: Mirror,
	x: number,
	y: number,
	z: number,
	budget: number,
	range: number?
): (number, number)
	local limit = range or PreyMirror.MESH_RANGE
	local ids, order, dist, drawn, live = m.ids, m.order, m.dist, m.drawn, m.live
	local dx, dy, dz = m.dx, m.dy, m.dz
	for _, id in ids do
		local i = id + 1
		local ax, ay, az = dx[i] - x, dy[i] - y, dz[i] - z
		dist[i] = math.sqrt(ax * ax + ay * ay + az * az)
		drawn[i] = 0
	end
	-- Keep last frame's order (nearly sorted), dropping groups that left and appending new ones.
	local n = 0
	local seen = m.at -- reuse: a live group's `at` is its place in `ids`, never 0
	for k = 1, #order do
		local id = order[k]
		if live[id + 1] and seen[id + 1] > 0 then
			n += 1
			order[n] = id
			seen[id + 1] = -seen[id + 1] -- mark as placed
		end
	end
	for _, id in ids do
		if seen[id + 1] > 0 then
			n += 1
			order[n] = id
		else
			seen[id + 1] = -seen[id + 1] -- unmark
		end
	end
	for k = #order, n + 1, -1 do
		order[k] = nil
	end
	-- Insertion sort by distance: linear when the order barely changed since last frame.
	for k = 2, n do
		local id = order[k]
		local d = dist[id + 1]
		local j = k - 1
		while j >= 1 and dist[order[j] + 1] > d do
			order[j + 1] = order[j]
			j -= 1
		end
		order[j + 1] = id
	end
	local given, front = 0, 0
	for k = 1, n do
		if given >= budget then
			break
		end
		local i = order[k] + 1
		if dist[i] > limit then
			break
		end
		local want = PreyMirror.aliveCount(m.alive[i], m.count[i])
		local take = math.min(want, budget - given)
		drawn[i] = take
		given += take
		front = k
	end
	return given, front
end

--- The nearest live group to (x, y, z) whose kind is in `kinds` (any kind when nil) and that has
--- a member alive: its ID and distance, or nil.
function PreyMirror.nearest(
	m: Mirror,
	x: number,
	y: number,
	z: number,
	kinds: { [number]: boolean }?
): (number?, number)
	local best: number? = nil
	local bestD2 = math.huge
	for _, id in m.ids do
		local i = id + 1
		if (kinds == nil or kinds[m.kind[i]]) and m.alive[i] ~= 0 then
			local ax, ay, az = m.dx[i] - x, m.dy[i] - y, m.dz[i] - z
			local d2 = ax * ax + ay * ay + az * az
			if d2 < bestD2 then
				best, bestD2 = id, d2
			end
		end
	end
	return best, if best then math.sqrt(bestD2) else math.huge
end

return table.freeze(PreyMirror)
