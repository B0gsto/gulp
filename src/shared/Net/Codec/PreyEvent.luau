--!strict
--!native
--!optimize 2
-- Codec/PreyEvent: the `PreyEvent` remote's buffer (docs/09, sections 5.3 and 8.7), server to
-- client, reliable, sent to every player who knows the group. 1 + 6n bytes, n from 1 to 255:
--   0       u8   n records
--   1 + 6k  u8   op         1 member eaten, 2 group removed, 3 member restored
--   2 + 6k  u16  groupId
--   4 + 6k  u8   gen
--   5 + 6k  u8   member     0 to 23 (bit of the alive mask)
--   6 + 6k  u8   eaterSlot  0 = predator or despawn, else the eater's slot 1 to 24
-- Records are 0-based (k = 0 first). Pure: no engine calls.
local PreyState = require("./PreyState")

local PreyEvent = {}

PreyEvent.OP_EATEN = 1
PreyEvent.OP_REMOVED = 2
PreyEvent.OP_RESTORED = 3
PreyEvent.RECORD = 6
PreyEvent.MAX_RECORDS = 255
PreyEvent.MAX_BYTES = 1 + 6 * 255 -- 1531
PreyEvent.MAX_SLOT = 24

local MAX_GROUPS, MAX_MEMBERS = PreyState.MAX_GROUPS, PreyState.MAX_MEMBERS

--- A payload of `n` records (1 to 255), zero-filled; fill it with `write`.
function PreyEvent.create(n: number): buffer
	if not (n >= 1 and n <= 255 and n % 1 == 0) then
		error(`PreyEvent.create: needs 1 to 255 records, got {n}`, 2)
	end
	local b = buffer.create(1 + 6 * n)
	buffer.writeu8(b, 0, n)
	return b
end

--- Writes record `k` (0-based).
function PreyEvent.write(
	b: buffer,
	k: number,
	op: number,
	groupId: number,
	gen: number,
	member: number,
	eaterSlot: number
)
	local o = 1 + 6 * k
	buffer.writeu8(b, o, op)
	buffer.writeu16(b, o + 1, groupId)
	buffer.writeu8(b, o + 3, gen)
	buffer.writeu8(b, o + 4, member)
	buffer.writeu8(b, o + 5, eaterSlot)
end

--- The record count of a payload `valid` accepted.
function PreyEvent.count(b: buffer): number
	return buffer.readu8(b, 0)
end

--- Record `k` (0-based) of a payload `valid` accepted: op, groupId, gen, member, eaterSlot.
function PreyEvent.read(b: buffer, k: number): (number, number, number, number, number)
	local o = 1 + 6 * k
	return buffer.readu8(b, o),
		buffer.readu16(b, o + 1),
		buffer.readu8(b, o + 3),
		buffer.readu8(b, o + 4),
		buffer.readu8(b, o + 5)
end

--- The lengths the codec accepts: 1 + 6n with n from 1 to 255.
function PreyEvent.accepts(length: number): boolean
	return length >= 7 and length <= 1 + 6 * 255 and (length - 1) % 6 == 0
end

--- True when the length matches its count and every record has a known op, a group ID below
--- 640, a member below 24 and an eater slot 0 to 24. Never throws.
function PreyEvent.valid(b: buffer): boolean
	local length = buffer.len(b)
	if not PreyEvent.accepts(length) or length ~= 1 + 6 * buffer.readu8(b, 0) then
		return false
	end
	for o = 1, length - 6, 6 do
		local op = buffer.readu8(b, o)
		if
			op < 1
			or op > 3
			or buffer.readu16(b, o + 1) >= MAX_GROUPS
			or buffer.readu8(b, o + 4) >= MAX_MEMBERS
			or buffer.readu8(b, o + 5) > 24
		then
			return false
		end
	end
	return true
end

return PreyEvent
