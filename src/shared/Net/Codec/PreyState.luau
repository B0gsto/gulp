--!strict
--!native
--!optimize 2
-- Codec/PreyState: the `PreyState` remote's buffer (docs/09, section 8.7), server to client,
-- unreliable, 10 Hz, at most 900 bytes (8.6, spike finding F8). Little-endian.
--   Header, 8 bytes:  0 u16 seq | 2 u32 timeMs | 6 u8 fullCount F | 7 u8 deltaCount D
--   8        22 × F   full records
--   8 + 22F  13 × D   delta records
--   Size = 8 + 22F + 13D ≤ 900.
-- Full record, 22 bytes: 0 u16 groupId | 2 u8 gen | 3 u8 kind | 4 u16 qx | 6 u16 qy | 8 u16 qz |
--   10 i8 qvx | 11 i8 qvy | 12 i8 qvz | 13 u8 scatter | 14 u8 flags | 15 u8 count |
--   16 u32 alive | 20 u16 seed
-- Delta record, 13 bytes: 0 u16 groupId | 2 u16 qx | 4 u16 qy | 6 u16 qz | 8 i8 qvx | 9 i8 qvy |
--   10 i8 qvz | 11 u8 scatter | 12 u8 flags
--
-- Hot path (section 4.7): the sender writes records into one scratch buffer it keeps
-- (`newScratch`), then `finish` copies the used bytes into the payload: one allocation per packet,
-- none per record. The reader fills a record table the caller keeps. Positions and velocities are
-- already quantised (Sim/Quantize).
local Assert = require("../../Util/Assert")

local PreyState = {}

PreyState.MAX_BYTES = 900
PreyState.HEADER = 8
PreyState.FULL = 22
PreyState.DELTA = 13
--- The most records of one kind a packet can hold.
PreyState.MAX_FULL = (900 - 8) // 22 -- 40
PreyState.MAX_DELTA = (900 - 8) // 13 -- 68

--- Group IDs run 0 to MAX_GROUPS − 1; a group has at most MAX_MEMBERS members (8.1).
PreyState.MAX_GROUPS = 512
PreyState.MAX_MEMBERS = 24
--- `flags` bits 0 to 4: fleeing, stunned, lured, dormant, event prey (8.2).
PreyState.FLAGS_MASK = 0x1F

local QX_MAX, QY_MAX, QZ_MAX = 32768, 11776, 32768 -- Sim/Quantize
local FULL_MASK = 0xFFFFFFFF

export type Full = {
	groupId: number,
	gen: number,
	kind: number, -- PreyDef wire index, 1 or more
	qx: number,
	qy: number,
	qz: number,
	qvx: number,
	qvy: number,
	qvz: number,
	scatter: number,
	flags: number,
	count: number, -- members at spawn, 1 to 24
	alive: number, -- bit i set = member i alive
	seed: number,
}

export type Delta = {
	groupId: number,
	qx: number,
	qy: number,
	qz: number,
	qvx: number,
	qvy: number,
	qvz: number,
	scatter: number,
	flags: number,
}

--- A blank full record, for a caller to reuse.
function PreyState.newFull(): Full
	return {
		groupId = 0,
		gen = 0,
		kind = 0,
		qx = 0,
		qy = 0,
		qz = 0,
		qvx = 0,
		qvy = 0,
		qvz = 0,
		scatter = 0,
		flags = 0,
		count = 0,
		alive = 0,
		seed = 0,
	}
end

--- A blank delta record, for a caller to reuse.
function PreyState.newDelta(): Delta
	return { groupId = 0, qx = 0, qy = 0, qz = 0, qvx = 0, qvy = 0, qvz = 0, scatter = 0, flags = 0 }
end

--- A 900-byte buffer to write packets into; keep one per sender.
function PreyState.newScratch(): buffer
	return buffer.create(900)
end

--- The size of a packet with `fullCount` full and `deltaCount` delta records.
function PreyState.size(fullCount: number, deltaCount: number): number
	return 8 + 22 * fullCount + 13 * deltaCount
end

--- True when that packet is at most 900 bytes.
function PreyState.fits(fullCount: number, deltaCount: number): boolean
	return 8 + 22 * fullCount + 13 * deltaCount <= 900
end

--- Writes full record `index` (0-based) at its place after the header.
function PreyState.writeFull(b: buffer, index: number, r: Full)
	local o = 8 + 22 * index
	buffer.writeu16(b, o, r.groupId)
	buffer.writeu8(b, o + 2, r.gen)
	buffer.writeu8(b, o + 3, r.kind)
	buffer.writeu16(b, o + 4, r.qx)
	buffer.writeu16(b, o + 6, r.qy)
	buffer.writeu16(b, o + 8, r.qz)
	buffer.writei8(b, o + 10, r.qvx)
	buffer.writei8(b, o + 11, r.qvy)
	buffer.writei8(b, o + 12, r.qvz)
	buffer.writeu8(b, o + 13, r.scatter)
	buffer.writeu8(b, o + 14, r.flags)
	buffer.writeu8(b, o + 15, r.count)
	buffer.writeu32(b, o + 16, r.alive)
	buffer.writeu16(b, o + 20, r.seed)
end

--- Writes delta record `index` (0-based) after `fullCount` full records.
function PreyState.writeDelta(b: buffer, fullCount: number, index: number, r: Delta)
	local o = 8 + 22 * fullCount + 13 * index
	buffer.writeu16(b, o, r.groupId)
	buffer.writeu16(b, o + 2, r.qx)
	buffer.writeu16(b, o + 4, r.qy)
	buffer.writeu16(b, o + 6, r.qz)
	buffer.writei8(b, o + 8, r.qvx)
	buffer.writei8(b, o + 9, r.qvy)
	buffer.writei8(b, o + 10, r.qvz)
	buffer.writeu8(b, o + 11, r.scatter)
	buffer.writeu8(b, o + 12, r.flags)
end

--- Writes the header into `scratch` and returns the payload: a new buffer of exactly
--- 8 + 22F + 13D bytes. Throws when the packet would be over 900 bytes (8.6: fail loudly in tests
--- rather than be dropped in play). `seq` wraps at 65536; `timeMs` is a u32 (Quantize.timeMs).
function PreyState.finish(
	scratch: buffer,
	seq: number,
	timeMs: number,
	fullCount: number,
	deltaCount: number
): buffer
	local size = 8 + 22 * fullCount + 13 * deltaCount
	Assert.that(
		size <= 900 and fullCount >= 0 and deltaCount >= 0,
		"PreyState: packet over 900 bytes (09 §8.6)"
	)
	buffer.writeu16(scratch, 0, seq % 65536)
	buffer.writeu32(scratch, 2, timeMs)
	buffer.writeu8(scratch, 6, fullCount)
	buffer.writeu8(scratch, 7, deltaCount)
	local out = buffer.create(size)
	buffer.copy(out, 0, scratch, 0, size)
	return out
end

--- The header of a payload `valid` accepted: seq, timeMs, fullCount, deltaCount.
function PreyState.header(b: buffer): (number, number, number, number)
	return buffer.readu16(b, 0), buffer.readu32(b, 2), buffer.readu8(b, 6), buffer.readu8(b, 7)
end

--- Reads full record `index` (0-based) of a payload `valid` accepted into `out`.
function PreyState.readFull(b: buffer, index: number, out: Full)
	local o = 8 + 22 * index
	out.groupId = buffer.readu16(b, o)
	out.gen = buffer.readu8(b, o + 2)
	out.kind = buffer.readu8(b, o + 3)
	out.qx = buffer.readu16(b, o + 4)
	out.qy = buffer.readu16(b, o + 6)
	out.qz = buffer.readu16(b, o + 8)
	out.qvx = buffer.readi8(b, o + 10)
	out.qvy = buffer.readi8(b, o + 11)
	out.qvz = buffer.readi8(b, o + 12)
	out.scatter = buffer.readu8(b, o + 13)
	out.flags = buffer.readu8(b, o + 14)
	out.count = buffer.readu8(b, o + 15)
	out.alive = buffer.readu32(b, o + 16)
	out.seed = buffer.readu16(b, o + 20)
end

--- Reads delta record `index` (0-based) of a payload `valid` accepted into `out`.
function PreyState.readDelta(b: buffer, fullCount: number, index: number, out: Delta)
	local o = 8 + 22 * fullCount + 13 * index
	out.groupId = buffer.readu16(b, o)
	out.qx = buffer.readu16(b, o + 2)
	out.qy = buffer.readu16(b, o + 4)
	out.qz = buffer.readu16(b, o + 6)
	out.qvx = buffer.readi8(b, o + 8)
	out.qvy = buffer.readi8(b, o + 9)
	out.qvz = buffer.readi8(b, o + 10)
	out.scatter = buffer.readu8(b, o + 11)
	out.flags = buffer.readu8(b, o + 12)
end

-- The fields a full and a delta record share, at `o` (groupId) and `p` (qx).
local function commonValid(b: buffer, o: number, p: number): boolean
	return buffer.readu16(b, o) < 512
		and buffer.readu16(b, p) <= QX_MAX
		and buffer.readu16(b, p + 2) <= QY_MAX
		and buffer.readu16(b, p + 4) <= QZ_MAX
		and buffer.readi8(b, p + 6) ~= -128
		and buffer.readi8(b, p + 7) ~= -128
		and buffer.readi8(b, p + 8) ~= -128
end

--- True when the payload is a well-formed packet: its length is 8 + 22F + 13D and at most 900,
--- and every record is in range (group ID below 512, positions inside Quantize's ranges, no −128
--- velocity, known flag bits; a full record also has a kind, 1 to 24 members, and no alive bit at
--- or above its count). Never throws.
function PreyState.valid(b: buffer): boolean
	local length = buffer.len(b)
	if length < 8 or length > 900 then
		return false
	end
	local fullCount, deltaCount = buffer.readu8(b, 6), buffer.readu8(b, 7)
	if length ~= 8 + 22 * fullCount + 13 * deltaCount then
		return false
	end
	for index = 0, fullCount - 1 do
		local o = 8 + 22 * index
		local count = buffer.readu8(b, o + 15)
		if
			not commonValid(b, o, o + 4)
			or buffer.readu8(b, o + 3) == 0
			or buffer.readu8(b, o + 14) > 0x1F
			or count < 1
			or count > 24
			or buffer.readu32(b, o + 16) > bit32.rshift(FULL_MASK, 32 - count)
		then
			return false
		end
	end
	local base = 8 + 22 * fullCount
	for index = 0, deltaCount - 1 do
		local o = base + 13 * index
		if not commonValid(b, o, o + 2) or buffer.readu8(b, o + 12) > 0x1F then
			return false
		end
	end
	return true
end

return PreyState
