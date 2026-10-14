--!strict
--!native
--!optimize 2
-- Codec/Ability: the `Ability` remote's buffer (docs/09, section 5.3), client to server, 6 bytes:
--   0  u8   op      1 dash, 2 ability press, 3 ability release (held abilities such as Shell)
--   1  u8   seq     wraps at 256
--   2  u32  timeMs  the client's estimate of server time when pressed (8.7: ms since ServerEpoch)
-- Pure: no engine calls (section 4.3). `valid` is the range check of 14.2, step 3.
local Ability = {}

Ability.SIZE = 6
Ability.OP_DASH = 1
Ability.OP_PRESS = 2
Ability.OP_RELEASE = 3

local U32_MAX = 4294967295

--- A 6-byte payload. `seq` wraps to 0..255; `timeMs` is floored and clamped to a u32.
function Ability.encode(op: number, seq: number, timeMs: number): buffer
	local b = buffer.create(Ability.SIZE)
	buffer.writeu8(b, 0, op)
	buffer.writeu8(b, 1, seq % 256)
	local t = math.floor(timeMs)
	if not (t >= 0) then
		t = 0
	elseif t > U32_MAX then
		t = U32_MAX
	end
	buffer.writeu32(b, 2, t)
	return b
end

--- The op, seq and timeMs of a payload `valid` accepted.
function Ability.decode(b: buffer): (number, number, number)
	return buffer.readu8(b, 0), buffer.readu8(b, 1), buffer.readu32(b, 2)
end

--- The length the codec accepts (14.2, step 2).
function Ability.accepts(length: number): boolean
	return length == Ability.SIZE
end

--- True when the payload is 6 bytes with a known op (14.2, steps 2 and 3).
function Ability.valid(b: buffer): boolean
	if buffer.len(b) ~= Ability.SIZE then
		return false
	end
	local op = buffer.readu8(b, 0)
	return op >= Ability.OP_DASH and op <= Ability.OP_RELEASE
end

return Ability
