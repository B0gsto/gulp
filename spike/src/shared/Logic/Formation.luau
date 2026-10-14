--!strict
--!native
-- Spike stand-in for shared/Sim/Formation (09 section 8.1): member offset = hash of (kind, seed, i), identical on
-- server and client. Returns the offset in the group's local frame (studs), before rotation by heading.
local Formation = {}

local SPREAD = { 6, 5, 2, 7, 3, 4, 5, 1, 3 } -- studs, per spike kind 1..9

local function h(a: number, b: number, c: number): number
	local x = bit32.bxor(a * 73856093, b * 19349663, c * 83492791)
	x = bit32.bxor(x, bit32.rshift(x, 13))
	x = (x * 1274126177) % 4294967296
	return bit32.bxor(x, bit32.rshift(x, 16))
end

function Formation.offset(kind: number, seed: number, i: number): (number, number, number)
	local s = SPREAD[kind] or 3
	local x = h(kind, seed, i * 3 + 1) / 4294967295 * 2 - 1
	local y = h(kind, seed, i * 3 + 2) / 4294967295 * 2 - 1
	local z = h(kind, seed, i * 3 + 3) / 4294967295 * 2 - 1
	return x * s, y * s * 0.5, z * s
end

return Formation
