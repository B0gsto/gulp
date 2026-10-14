--!strict
--!native
--!optimize 2
-- Codec/Bite: the `Bite` remote's buffer (docs/09, sections 8.7 and 8.9), client to server,
-- reliable. 8 bytes for a player or predator bite, 12 to 40 for prey; anything else is malformed.
--   0       u8   op           1 prey, 2 player, 3 predator or wild creature (9.3)
--   1       u8   prey: count n (1 to 8); player: victim slot (1 to 24); predator: its slot in
--                PredatorState
--   2       u16  seq          the client's bite counter, wraps at 65536
--   4       u32  claimTimeMs  the client's server-time estimate at contact (ms since ServerEpoch)
--   8 + 4k  u16  groupId      prey only, k = 0 to n − 1
--   10 + 4k u8   member
--   11 + 4k u8   gen
-- Pure: no engine calls. `accepts` and `valid` are the size and range checks of 14.2.
local PreyState = require("./PreyState")

local Bite = {}

Bite.OP_PREY = 1
Bite.OP_PLAYER = 2
Bite.OP_PREDATOR = 3
Bite.HEADER = 8
Bite.TARGET = 4
Bite.MAX_TARGETS = 8
Bite.MIN_BYTES = 8
Bite.MAX_BYTES = 8 + 4 * 8 -- 40
Bite.MAX_SLOT = 24

local MAX_GROUPS, MAX_MEMBERS = PreyState.MAX_GROUPS, PreyState.MAX_MEMBERS
local U32_MAX = 4294967295

local function header(
	length: number,
	op: number,
	target: number,
	seq: number,
	timeMs: number
): buffer
	local b = buffer.create(length)
	buffer.writeu8(b, 0, op)
	buffer.writeu8(b, 1, target)
	buffer.writeu16(b, 2, seq % 65536)
	local t = math.floor(timeMs)
	if not (t >= 0) then
		t = 0
	elseif t > U32_MAX then
		t = U32_MAX
	end
	buffer.writeu32(b, 4, t)
	return b
end

--- A prey bite of `count` targets (1 to 8); fill them with `writePrey`.
function Bite.encodePrey(seq: number, claimTimeMs: number, count: number): buffer
	if not (count >= 1 and count <= 8 and count % 1 == 0) then
		error(`Bite.encodePrey: needs 1 to 8 targets, got {count}`, 2)
	end
	return header(8 + 4 * count, 1, count, seq, claimTimeMs)
end

--- Writes prey target `k` (0-based) of a prey bite.
function Bite.writePrey(b: buffer, k: number, groupId: number, member: number, gen: number)
	local o = 8 + 4 * k
	buffer.writeu16(b, o, groupId)
	buffer.writeu8(b, o + 2, member)
	buffer.writeu8(b, o + 3, gen)
end

--- A bite on the player in `victimSlot`.
function Bite.encodePlayer(seq: number, claimTimeMs: number, victimSlot: number): buffer
	return header(8, 2, victimSlot, seq, claimTimeMs)
end

--- A bite on the predator or wild creature at `predatorSlot` of PredatorState.
function Bite.encodePredator(seq: number, claimTimeMs: number, predatorSlot: number): buffer
	return header(8, 3, predatorSlot, seq, claimTimeMs)
end

--- The header of a payload `valid` accepted: op, its second byte (count, victim slot or
--- predator slot), seq, claimTimeMs.
function Bite.header(b: buffer): (number, number, number, number)
	return buffer.readu8(b, 0), buffer.readu8(b, 1), buffer.readu16(b, 2), buffer.readu32(b, 4)
end

--- Prey target `k` (0-based) of a prey bite `valid` accepted: groupId, member, gen.
function Bite.readPrey(b: buffer, k: number): (number, number, number)
	local o = 8 + 4 * k
	return buffer.readu16(b, o), buffer.readu8(b, o + 2), buffer.readu8(b, o + 3)
end

--- The lengths the codec accepts (14.2, step 2): 8, or 8 + 4n with n from 1 to 8.
function Bite.accepts(length: number): boolean
	return length == 8 or (length >= 12 and length <= 40 and length % 4 == 0)
end

--- True when the payload is well formed (14.2, steps 2 and 3): a known op; a prey bite's length
--- is 8 + 4n for its count n, each target with a group ID below 512 and a member below 24; a
--- player bite is 8 bytes naming slot 1 to 24; a predator bite is 8 bytes. Never throws.
function Bite.valid(b: buffer): boolean
	local length = buffer.len(b)
	if not Bite.accepts(length) then
		return false
	end
	local op, target = buffer.readu8(b, 0), buffer.readu8(b, 1)
	if op == 1 then
		if target < 1 or target > 8 or length ~= 8 + 4 * target then
			return false
		end
		for o = 8, length - 4, 4 do
			if buffer.readu16(b, o) >= MAX_GROUPS or buffer.readu8(b, o + 2) >= MAX_MEMBERS then
				return false
			end
		end
		return true
	elseif op == 2 then
		return length == 8 and target >= 1 and target <= 24
	elseif op == 3 then
		return length == 8
	end
	return false
end

return Bite
