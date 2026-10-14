--!strict
-- Rng: a seedable random number generator that gives the same sequence in Roblox and in Lune.
-- Simulations and their tests depend on that, so nothing here uses `math.random` or `Random`.
-- The generator is xoshiro128++ (four 32-bit words of state), seeded through splitmix32.
-- Changing either changes every simulation result: tests/unit/Util/Rng.spec.luau pins the output.
-- Only `new` allocates.

export type Rng = { a: number, b: number, c: number, d: number }

local TWO_32 = 0x100000000

local Rng = {}

-- (a × b) mod 2^32 for two 32-bit values, in halves so no product passes 2^53.
local function multiply(a: number, b: number): number
	local low = (a % 0x10000) * b
	local high = (a // 0x10000) * b % 0x10000
	return (low + high * 0x10000) % TWO_32
end

local function mix(state: number): number
	local z = multiply(bit32.bxor(state, bit32.rshift(state, 16)), 0x85EBCA6B)
	z = multiply(bit32.bxor(z, bit32.rshift(z, 13)), 0xC2B2AE35)
	return bit32.bxor(z, bit32.rshift(z, 16))
end

--- A new generator. The same `seed` always gives the same sequence. The seed is floored and
--- wrapped to 32 bits; it must be a finite number.
function Rng.new(seed: number): Rng
	if seed ~= seed or math.abs(seed) == math.huge then
		error(`Rng.new: the seed must be a finite number, got {seed}`, 2)
	end
	local state = math.floor(seed) % TWO_32
	local words = { 0, 0, 0, 0 }
	for index = 1, 4 do
		state = (state + 0x9E3779B9) % TWO_32
		words[index] = mix(state)
	end
	return { a = words[1], b = words[2], c = words[3], d = words[4] }
end

--- The next whole number from 0 to 4,294,967,295.
function Rng.nextU32(rng: Rng): number
	local a, b, c, d = rng.a, rng.b, rng.c, rng.d
	local result = (bit32.lrotate((a + d) % TWO_32, 7) + a) % TWO_32
	local shifted = bit32.lshift(b, 9)
	c = bit32.bxor(c, a)
	d = bit32.bxor(d, b)
	b = bit32.bxor(b, c)
	a = bit32.bxor(a, d)
	c = bit32.bxor(c, shifted)
	d = bit32.lrotate(d, 11)
	rng.a, rng.b, rng.c, rng.d = a, b, c, d
	return result
end

--- The next number from 0 up to, but never reaching, 1.
function Rng.next(rng: Rng): number
	return Rng.nextU32(rng) / TWO_32
end

--- A number from `min` up to, but never reaching, `max`.
function Rng.range(rng: Rng, min: number, max: number): number
	return min + (max - min) * Rng.next(rng)
end

--- A whole number from `min` to `max`, both included. Both must be whole numbers, `min <= max`.
function Rng.int(rng: Rng, min: number, max: number): number
	if min > max or min % 1 ~= 0 or max % 1 ~= 0 then
		error(`Rng.int: needs whole numbers with min <= max, got {min} and {max}`, 2)
	end
	return min + math.floor(Rng.next(rng) * (max - min + 1))
end

--- True with probability `probability`: never at 0 or less, always at 1 or more.
function Rng.chance(rng: Rng, probability: number): boolean
	return Rng.next(rng) < probability
end

--- One value of `list`, each equally likely; nil when the list is empty.
function Rng.pick<T>(rng: Rng, list: { T }): T?
	local count = #list
	if count == 0 then
		return nil
	end
	return list[1 + math.floor(Rng.next(rng) * count)]
end

--- Shuffles `list` in place (Fisher-Yates) and returns it.
function Rng.shuffle<T>(rng: Rng, list: { T }): { T }
	for index = #list, 2, -1 do
		local other = 1 + math.floor(Rng.next(rng) * index)
		list[index], list[other] = list[other], list[index]
	end
	return list
end

return Rng
