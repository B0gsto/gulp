--!strict
--!native
--!optimize 2
-- Codec/BiteResult: the `BiteResult` remote's buffer (docs/09, sections 8.7 and 8.9), server to
-- the claimant, reliable, 9 bytes:
--   0  u16  seq           the claim's `seq` (Codec/Bite)
--   2  u8   acceptedMask  bit k set = target k of the claim accepted
--   3  u8   reason        0 none, 1 gone, 2 range, 3 tier, 4 time, 5 rate, 6 state, 7 safe zone,
--                         8 protected
--   4  f32  newMass
--   8  u8   newTier
-- Pure: no engine calls.
local Index = require("../../Data/Index")

local BiteResult = {}

BiteResult.SIZE = 9

BiteResult.REASON_NONE = 0
BiteResult.REASON_GONE = 1
BiteResult.REASON_RANGE = 2
BiteResult.REASON_TIER = 3
BiteResult.REASON_TIME = 4
BiteResult.REASON_RATE = 5
BiteResult.REASON_STATE = 6
BiteResult.REASON_SAFE_ZONE = 7
BiteResult.REASON_PROTECTED = 8
BiteResult.MAX_REASON = 8

local MAX_TIER = #Index.Tiers.list

--- A 9-byte payload. `seq` wraps at 65536; `newMass` is stored as an f32.
function BiteResult.encode(
	seq: number,
	acceptedMask: number,
	reason: number,
	newMass: number,
	newTier: number
): buffer
	local b = buffer.create(9)
	buffer.writeu16(b, 0, seq % 65536)
	buffer.writeu8(b, 2, acceptedMask)
	buffer.writeu8(b, 3, reason)
	buffer.writef32(b, 4, newMass)
	buffer.writeu8(b, 8, newTier)
	return b
end

--- seq, acceptedMask, reason, newMass and newTier of a payload `valid` accepted.
function BiteResult.decode(b: buffer): (number, number, number, number, number)
	return buffer.readu16(b, 0),
		buffer.readu8(b, 2),
		buffer.readu8(b, 3),
		buffer.readf32(b, 4),
		buffer.readu8(b, 8)
end

--- The length the codec accepts.
function BiteResult.accepts(length: number): boolean
	return length == 9
end

--- True when the payload is 9 bytes with a known reason, a finite mass of 0 or more and a tier
--- of the tier table. Never throws.
function BiteResult.valid(b: buffer): boolean
	if buffer.len(b) ~= 9 then
		return false
	end
	local mass, tier = buffer.readf32(b, 4), buffer.readu8(b, 8)
	return buffer.readu8(b, 3) <= 8
		and mass >= 0
		and mass < math.huge
		and tier >= 1
		and tier <= MAX_TIER
end

return BiteResult
