--!strict
--!native
--!optimize 2
-- PreyInterest: interest management and packing of the `PreyState` stream (docs/09, sections 8.5
-- and 8.6). Pure: numbers and buffers only, so `tests/sim/prey_soak.sim.luau` drives it in Lune
-- exactly as PreyService drives it in the engine.
--
-- For one player per call (`updatePlayer`), at the sim's current tick:
--   1 Visit the grid cells within 600 studs and put each group in a band by 3D distance:
--     Near 0 to 150, Mid 150 to 350, Far 350 to 600 (beyond: nothing, the client drops it).
--     A group owned by another slot (PreySim.own: scripted prey, docs/04 §3.5) is skipped, so
--     only its owner is ever sent it, knows it, or gets its PreyEvents.
--   2 Dead reckoning: the client believes the group is at sentPos + sentVel × (now − sentTime),
--     from the quantised values it was last sent. A delta record is due when the real position is
--     off by more than the band's threshold (1, 3, 8 studs); in Near also when the flags change or
--     the scatter moved by SCATTER_STEP.
--   3 A group the player does not know (new, new generation, or silent for FORGET_AFTER ticks, so
--     the client has dropped it) gets a full record in two consecutive packets.
--   4 Keyframes, Near and Mid only: the full record again every 2 s, on the staggered ticks where
--     (groupId + slot) % 20 == tick % 20; one missed through the byte cap is sent at the latest
--     KEY_LATE ticks after the last one.
--   5 Far keep-alive (8.5): on its staggered tick (every 2 s) a Far group with nothing sent for
--     KEEPALIVE_QUIET ticks (0.5 s) gets one delta record. Longest silence with no loss 2.4 s,
--     with one lost packet 4.4 s, under the client's 5 s drop for Far groups (PreyMirror).
--   6 One packet of at most 900 bytes. When the due records do not fit, they are ordered nearest
--     band first, then by error ÷ threshold (full records of new groups first within a band); what
--     does not fit waits for the next tick (its send state is left as it was).
--
-- Send state per (slot, group), about 29 bytes (8.2 lists 18; this keeps the scatter, flags and an
-- f64 send time as well): known (gen + 1, or 0), fullLeft, sentQ (3 × u16), sentV (3 × i8),
-- sentScatter, sentFlags, sentTime (f64), sentTick and keyTick (u32 sim ticks).
-- Hot path (09 §4.7): no allocation per group; the candidate list and the scratch packet are
-- reused; table.sort runs on plain numbers only when the due records exceed one packet.
local PreySim = require("../Sim/PreySim")
local PreyState = require("../Net/Codec/PreyState")
local Quantize = require("../Sim/Quantize")
local SpatialGrid = require("../Sim/SpatialGrid")

local profileBegin: (string) -> () = debug.profilebegin or function(_label: string) end
local profileEnd: () -> () = debug.profileend or function() end

local PreyInterest = {}

PreyInterest.NEAR = 150 -- studs (tune) 8.5
PreyInterest.MID = 350
PreyInterest.FAR = 600
PreyInterest.THRESHOLD_NEAR = 1.0 -- studs of dead-reckoning error (tune)
PreyInterest.THRESHOLD_MID = 3.0
PreyInterest.THRESHOLD_FAR = 8.0
PreyInterest.KEY_PERIOD = 20 -- ticks: keyframe every 2 s at 10 Hz
PreyInterest.KEY_LATE = 24 -- ticks: a keyframe deferred by the byte cap goes out by then
PreyInterest.KEEPALIVE_QUIET = 5 -- ticks (tune) 8.5: a Far keep-alive skips if anything went out in the last 0.5 s
PreyInterest.FORGET_AFTER = 25 -- ticks of silence after which the client is assumed to have dropped it
PreyInterest.FULL_REPEAT = 2 -- a new group's full record goes in two consecutive packets
PreyInterest.SCATTER_STEP = 13 -- quantised scatter (0 to 255) change that counts in Near (tune)
PreyInterest.KNOWS_WITHIN = 50 -- ticks: `knows` is true for 5 s after the last record (the client drops Far groups after 5 s)

local G = PreySim.MAX_GROUPS
local NEAR2 = PreyInterest.NEAR * PreyInterest.NEAR
local MID2 = PreyInterest.MID * PreyInterest.MID
local FAR = PreyInterest.FAR
local FAR2 = FAR * FAR
local KEY_PERIOD = PreyInterest.KEY_PERIOD
local KEY_LATE = PreyInterest.KEY_LATE
local KEEPALIVE_QUIET = PreyInterest.KEEPALIVE_QUIET
local FORGET_AFTER = PreyInterest.FORGET_AFTER
local SCATTER_STEP = PreyInterest.SCATTER_STEP
local SIDE = SpatialGrid.SIDE
local NONE = SpatialGrid.NONE
local MAX_BYTES = PreyState.MAX_BYTES
local HEADER, FULL, DELTA = PreyState.HEADER, PreyState.FULL, PreyState.DELTA
local REC_DELTA, REC_FULL = 1, 2
local THRESHOLDS =
	{ PreyInterest.THRESHOLD_NEAR, PreyInterest.THRESHOLD_MID, PreyInterest.THRESHOLD_FAR }

export type State = {
	maxSlots: number,
	known: buffer, -- u8 per (slot, group): gen + 1 of what the client was told, 0 = unknown
	fullLeft: buffer, -- u8: full records still to send for a new group
	sentQ: buffer, -- u16 × 3: quantised position last sent
	sentV: buffer, -- i8 × 3: quantised velocity last sent
	sentScatter: buffer, -- u8
	sentFlags: buffer, -- u8
	sentTime: buffer, -- f64: sim time of the last record
	sentTick: buffer, -- u32: sim tick of the last record of any kind (0 = never)
	keyTick: buffer, -- u32: sim tick of the last full record
	seq: { number }, -- per slot, the last PreyState seq
	-- Per-call scratch.
	recType: buffer, -- u8 per group: 0 none, 1 delta, 2 full
	candidates: { number },
	chosenFull: { number },
	chosenDelta: { number },
	scratch: buffer,
	fullRecord: PreyState.Full,
	deltaRecord: PreyState.Delta,
	packets: { [number]: buffer },
	-- Per slot, the last call's numbers and a running byte total (for the soak and the profiler).
	lastBytes: { number },
	lastFull: { number },
	lastDelta: { number },
	lastDeferred: { number },
	totalBytes: { number },
	totalPackets: { number },
}

--- Send state for `maxSlots` players (slots 1 to maxSlots).
function PreyInterest.new(maxSlots: number): State
	assert(maxSlots >= 1 and maxSlots % 1 == 0, "PreyInterest.new: bad slot count")
	local n = maxSlots * G
	return {
		maxSlots = maxSlots,
		known = buffer.create(n),
		fullLeft = buffer.create(n),
		sentQ = buffer.create(n * 6),
		sentV = buffer.create(n * 3),
		sentScatter = buffer.create(n),
		sentFlags = buffer.create(n),
		sentTime = buffer.create(n * 8),
		sentTick = buffer.create(n * 4),
		keyTick = buffer.create(n * 4),
		seq = table.create(maxSlots, 0),
		recType = buffer.create(G),
		candidates = table.create(G),
		chosenFull = table.create(PreyState.MAX_FULL),
		chosenDelta = table.create(PreyState.MAX_DELTA),
		scratch = PreyState.newScratch(),
		fullRecord = PreyState.newFull(),
		deltaRecord = PreyState.newDelta(),
		packets = {},
		lastBytes = table.create(maxSlots, 0),
		lastFull = table.create(maxSlots, 0),
		lastDelta = table.create(maxSlots, 0),
		lastDeferred = table.create(maxSlots, 0),
		totalBytes = table.create(maxSlots, 0),
		totalPackets = table.create(maxSlots, 0),
	}
end

--- Forgets everything slot `slot` was told (a player left, or a new player took the slot).
function PreyInterest.reset(state: State, slot: number)
	local base = (slot - 1) * G
	buffer.fill(state.known, base, 0, G)
	buffer.fill(state.fullLeft, base, 0, G)
	buffer.fill(state.sentTick, base * 4, 0, G * 4)
	buffer.fill(state.keyTick, base * 4, 0, G * 4)
	state.seq[slot] = 0
	state.lastBytes[slot], state.lastFull[slot], state.lastDelta[slot], state.lastDeferred[slot] =
		0, 0, 0, 0
end

--- Group `g` was removed: no slot knows it any more (call after building its PreyEvent).
function PreyInterest.forget(state: State, g: number)
	for s = 0, state.maxSlots - 1 do
		local i = s * G + g
		buffer.writeu8(state.known, i, 0)
		buffer.writeu8(state.fullLeft, i, 0)
	end
end

--- True when slot `slot`'s client knows group `g` at generation `gen`: it was sent a record for it
--- within the last 5 s (8.7: a PreyEvent goes to every player who knows the group).
function PreyInterest.knows(
	state: State,
	slot: number,
	g: number,
	gen: number,
	tick: number
): boolean
	local i = (slot - 1) * G + g
	return buffer.readu8(state.known, i) == gen + 1
		and tick - buffer.readu32(state.sentTick, i * 4) <= PreyInterest.KNOWS_WITHIN
end

-- Fills the reusable full record of group g from the sim.
local function fillFull(r: PreyState.Full, b: PreySim.PreyBuffers, g: number)
	local o4 = g * 4
	r.groupId = g
	r.gen = buffer.readu8(b.gen, g)
	r.kind = buffer.readu8(b.kind, g)
	r.qx = Quantize.x(buffer.readf32(b.posX, o4))
	r.qy = Quantize.y(buffer.readf32(b.posY, o4))
	r.qz = Quantize.z(buffer.readf32(b.posZ, o4))
	r.qvx = Quantize.vel(buffer.readf32(b.velX, o4))
	r.qvy = Quantize.vel(buffer.readf32(b.velY, o4))
	r.qvz = Quantize.vel(buffer.readf32(b.velZ, o4))
	r.scatter = Quantize.scatter(buffer.readf32(b.scatter, o4))
	r.flags = bit32.band(buffer.readu8(b.flags, g), PreyState.FLAGS_MASK)
	r.count = buffer.readu8(b.count, g)
	r.alive = buffer.readu32(b.alive, o4)
	r.seed = buffer.readu16(b.seed, g * 2)
end

-- Records what slot index base + g was just sent.
local function remember(
	state: State,
	i: number,
	qx: number,
	qy: number,
	qz: number,
	qvx: number,
	qvy: number,
	qvz: number,
	scatter: number,
	flags: number,
	now: number,
	tick: number
)
	buffer.writeu16(state.sentQ, i * 6, qx)
	buffer.writeu16(state.sentQ, i * 6 + 2, qy)
	buffer.writeu16(state.sentQ, i * 6 + 4, qz)
	buffer.writei8(state.sentV, i * 3, qvx)
	buffer.writei8(state.sentV, i * 3 + 1, qvy)
	buffer.writei8(state.sentV, i * 3 + 2, qvz)
	buffer.writeu8(state.sentScatter, i, scatter)
	buffer.writeu8(state.sentFlags, i, flags)
	buffer.writef64(state.sentTime, i * 8, now)
	buffer.writeu32(state.sentTick, i * 4, tick)
end

--- Builds this tick's `PreyState` packet for the player in `slot` (1 to maxSlots) whose root is at
--- (px, py, pz), from the sim's current state (sim.tick, sim.now). Returns the payload, or nil when
--- nothing is due. The packet's timeMs is the sim tick's time (sim.now is seconds since
--- ServerEpoch). At most 900 bytes, always (PreyState.finish asserts it).
function PreyInterest.updatePlayer(
	state: State,
	sim: PreySim.Sim,
	slot: number,
	px: number,
	py: number,
	pz: number
): buffer?
	profileBegin("PreyInterest.updatePlayer")
	local b, grid = sim.buffers, sim.grid
	local owner = b.owner
	local tick, now = sim.tick, sim.now
	local base = (slot - 1) * G
	local known, fullLeft, sentTick, keyTick =
		state.known, state.fullLeft, state.sentTick, state.keyTick
	local sentQ, sentV, sentTime = state.sentQ, state.sentV, state.sentTime
	local recType, candidates = state.recType, state.candidates
	local stagger = tick % KEY_PERIOD
	table.clear(candidates)
	local n = 0
	local bytes = HEADER

	local c0, c1, r0, r1 = SpatialGrid.range(px, pz, FAR)
	for row = r0, r1 do
		for col = c0, c1 do
			local g = buffer.readu16(grid.cellHead, (row * SIDE + col) * 2)
			while g ~= NONE do
				local o4 = g * 4
				local x, y, z =
					buffer.readf32(b.posX, o4),
					buffer.readf32(b.posY, o4),
					buffer.readf32(b.posZ, o4)
				local dx, dy, dz = x - px, y - py, z - pz
				local d2 = dx * dx + dy * dy + dz * dz
				local own = buffer.readu8(owner, g)
				if d2 <= FAR2 and (own == 0 or own == slot) then
					local band = if d2 <= NEAR2 then 0 elseif d2 <= MID2 then 1 else 2
					local i = base + g
					local gen = buffer.readu8(b.gen, g)
					local lastTick = buffer.readu32(sentTick, i * 4)
					if
						buffer.readu8(known, i) ~= gen + 1
						or tick - lastTick > FORGET_AFTER
						or lastTick == 0
					then
						if buffer.readu8(fullLeft, i) == 0 then
							buffer.writeu8(known, i, 0)
							buffer.writeu8(fullLeft, i, PreyInterest.FULL_REPEAT)
						end
					end
					local kind = 0
					local ratio = 0
					if buffer.readu8(fullLeft, i) > 0 then
						kind, ratio = REC_FULL, 255
					else
						-- Dead-reckoned error against what the client was last told.
						local elapsed = now - buffer.readf64(sentTime, i * 8)
						local ex = x
							- (
								Quantize.fromX(buffer.readu16(sentQ, i * 6))
								+ Quantize.fromVel(buffer.readi8(sentV, i * 3)) * elapsed
							)
						local ey = y
							- (
								Quantize.fromY(buffer.readu16(sentQ, i * 6 + 2))
								+ Quantize.fromVel(buffer.readi8(sentV, i * 3 + 1)) * elapsed
							)
						local ez = z
							- (
								Quantize.fromZ(buffer.readu16(sentQ, i * 6 + 4))
								+ Quantize.fromVel(buffer.readi8(sentV, i * 3 + 2)) * elapsed
							)
						ratio = math.sqrt(ex * ex + ey * ey + ez * ez) / THRESHOLDS[band + 1]
						local staggered = (g + slot) % KEY_PERIOD == stagger
						if band < 2 then
							local sinceKey = tick - buffer.readu32(keyTick, i * 4)
							if
								(staggered and sinceKey >= KEY_PERIOD // 2)
								or sinceKey >= KEY_LATE
							then
								kind = REC_FULL
							end
						end
						if kind == 0 then
							-- Over the threshold, or a Far keep-alive (ranked by its small error).
							local keepAlive = band == 2
								and staggered
								and tick - lastTick >= KEEPALIVE_QUIET
							if ratio > 1 or keepAlive then
								kind = REC_DELTA
							elseif band == 0 then
								local flags =
									bit32.band(buffer.readu8(b.flags, g), PreyState.FLAGS_MASK)
								local sc = Quantize.scatter(buffer.readf32(b.scatter, o4))
								if
									flags ~= buffer.readu8(state.sentFlags, i)
									or math.abs(sc - buffer.readu8(state.sentScatter, i))
										>= SCATTER_STEP
								then
									kind, ratio = REC_DELTA, 1
								end
							end
						end
					end
					if kind ~= 0 then
						buffer.writeu8(recType, g, kind)
						n += 1
						-- Nearest band first, then the larger error ÷ threshold; the group ID breaks ties.
						local urgency = math.min(math.floor(ratio * 16), 4095)
						candidates[n] = (band * 4096 + (4095 - urgency)) * 1024 + g
						bytes += if kind == REC_FULL then FULL else DELTA
					end
				end
				g = buffer.readu16(grid.next, g * 2)
			end
		end
	end

	-- Choose what fits in one packet.
	local chosenFull, chosenDelta = state.chosenFull, state.chosenDelta
	table.clear(chosenFull)
	table.clear(chosenDelta)
	local fullCount, deltaCount, deferred = 0, 0, 0
	local overflow = bytes > MAX_BYTES
	if overflow then
		table.sort(candidates)
		bytes = HEADER
	end
	for k = 1, n do
		local g = candidates[k] % 1024
		local kind = buffer.readu8(recType, g)
		local size = if kind == REC_FULL then FULL else DELTA
		if not overflow or bytes + size <= MAX_BYTES then
			if overflow then
				bytes += size
			end
			if kind == REC_FULL then
				fullCount += 1
				chosenFull[fullCount] = g
			else
				deltaCount += 1
				chosenDelta[deltaCount] = g
			end
		else
			deferred += 1
		end
	end

	state.lastFull[slot], state.lastDelta[slot], state.lastDeferred[slot] =
		fullCount, deltaCount, deferred
	if fullCount + deltaCount == 0 then
		state.lastBytes[slot] = 0
		profileEnd()
		return nil
	end

	local scratch = state.scratch
	local r = state.fullRecord
	for k = 1, fullCount do
		local g = chosenFull[k]
		fillFull(r, b, g)
		PreyState.writeFull(scratch, k - 1, r)
		local i = base + g
		remember(state, i, r.qx, r.qy, r.qz, r.qvx, r.qvy, r.qvz, r.scatter, r.flags, now, tick)
		buffer.writeu8(known, i, r.gen + 1)
		buffer.writeu32(keyTick, i * 4, tick)
		local left = buffer.readu8(fullLeft, i)
		if left > 0 then
			buffer.writeu8(fullLeft, i, left - 1)
		end
	end
	local d = state.deltaRecord
	for k = 1, deltaCount do
		local g = chosenDelta[k]
		fillFull(r, b, g)
		d.groupId = g
		d.qx, d.qy, d.qz = r.qx, r.qy, r.qz
		d.qvx, d.qvy, d.qvz = r.qvx, r.qvy, r.qvz
		d.scatter, d.flags = r.scatter, r.flags
		PreyState.writeDelta(scratch, fullCount, k - 1, d)
		remember(
			state,
			base + g,
			r.qx,
			r.qy,
			r.qz,
			r.qvx,
			r.qvy,
			r.qvz,
			r.scatter,
			r.flags,
			now,
			tick
		)
	end
	local seq = (state.seq[slot] + 1) % 65536
	state.seq[slot] = seq
	local payload = PreyState.finish(scratch, seq, Quantize.timeMs(now, 0), fullCount, deltaCount)
	local size = buffer.len(payload)
	state.lastBytes[slot] = size
	state.totalBytes[slot] += size
	state.totalPackets[slot] += 1
	profileEnd()
	return payload
end

--- Convenience for tests and the soak: `updatePlayer` for every slot that has a position.
--- `positions[slot]` is { x, y, z } or nil (no player: the slot's state is reset). Returns
--- `state.packets`, reused between calls: slot → payload for the slots that got one.
function PreyInterest.update(
	state: State,
	sim: PreySim.Sim,
	positions: { [number]: { number }? }
): { [number]: buffer }
	local packets = state.packets
	table.clear(packets)
	for slot = 1, state.maxSlots do
		local p = positions[slot]
		if p then
			local payload = PreyInterest.updatePlayer(state, sim, slot, p[1], p[2], p[3])
			if payload then
				packets[slot] = payload
			end
		elseif state.seq[slot] ~= 0 then
			PreyInterest.reset(state, slot)
		end
	end
	return packets
end

return table.freeze(PreyInterest)
