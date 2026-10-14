--!strict
local PreyState = require("../../../../src/shared/Net/Codec/PreyState")
local Quantize = require("../../../../src/shared/Sim/Quantize")
local Remotes = require("../../../../src/shared/Net/Remotes")
local Rng = require("../../../../src/shared/Util/Rng")
local TestKit = require("../../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type Full = PreyState.Full
type Delta = PreyState.Delta

local function randomFull(rng: Rng.Rng): Full
	local r = PreyState.newFull()
	local count = Rng.int(rng, 1, 24)
	r.groupId = Rng.int(rng, 0, 511)
	r.gen = Rng.int(rng, 0, 255)
	r.kind = Rng.int(rng, 1, 255)
	r.qx = Quantize.x(Rng.range(rng, -1100, 1100))
	r.qy = Quantize.y(Rng.range(rng, -700, 120))
	r.qz = Quantize.z(Rng.range(rng, -1100, 1100))
	r.qvx = Quantize.vel(Rng.range(rng, -80, 80))
	r.qvy = Quantize.vel(Rng.range(rng, -80, 80))
	r.qvz = Quantize.vel(Rng.range(rng, -80, 80))
	r.scatter = Quantize.scatter(Rng.next(rng))
	r.flags = Rng.int(rng, 0, PreyState.FLAGS_MASK)
	r.count = count
	r.alive = Rng.nextU32(rng) % 2 ^ count
	r.seed = Rng.int(rng, 0, 65535)
	return r
end

local function randomDelta(rng: Rng.Rng): Delta
	local r = PreyState.newDelta()
	r.groupId = Rng.int(rng, 0, 511)
	r.qx = Rng.int(rng, 0, Quantize.QX_MAX)
	r.qy = Rng.int(rng, 0, Quantize.QY_MAX)
	r.qz = Rng.int(rng, 0, Quantize.QZ_MAX)
	r.qvx = Rng.int(rng, -127, 127)
	r.qvy = Rng.int(rng, -127, 127)
	r.qvz = Rng.int(rng, -127, 127)
	r.scatter = Rng.int(rng, 0, 255)
	r.flags = Rng.int(rng, 0, PreyState.FLAGS_MASK)
	return r
end

-- A packet of the given records, through one reused scratch buffer.
local scratch = PreyState.newScratch()
local function pack(seq: number, timeMs: number, fulls: { Full }, deltas: { Delta }): buffer
	for i, r in fulls do
		PreyState.writeFull(scratch, i - 1, r)
	end
	for i, r in deltas do
		PreyState.writeDelta(scratch, #fulls, i - 1, r)
	end
	return PreyState.finish(scratch, seq, timeMs, #fulls, #deltas)
end

local function edgeFull(): Full
	local r = PreyState.newFull()
	r.groupId, r.gen, r.kind = 511, 255, 255
	r.qx, r.qy, r.qz = Quantize.QX_MAX, Quantize.QY_MAX, Quantize.QZ_MAX
	r.qvx, r.qvy, r.qvz = -127, 127, -127
	r.scatter, r.flags, r.count, r.alive, r.seed = 255, PreyState.FLAGS_MASK, 24, 0xFFFFFF, 65535
	return r
end

describe("Codec/PreyState (09 §8.7)", function()
	it("round-trips random packets record for record", function()
		local rng = Rng.new(8703)
		local full, delta = PreyState.newFull(), PreyState.newDelta()
		for _ = 1, 200 do
			local fullCount = Rng.int(rng, 0, PreyState.MAX_FULL)
			local deltaCount = Rng.int(rng, 0, (900 - 8 - 22 * fullCount) // 13)
			local fulls, deltas = {}, {}
			for i = 1, fullCount do
				fulls[i] = randomFull(rng)
			end
			for i = 1, deltaCount do
				deltas[i] = randomDelta(rng)
			end
			local seq, timeMs = Rng.int(rng, 0, 65535), Rng.nextU32(rng)
			local b = pack(seq, timeMs, fulls, deltas)
			expect(buffer.len(b)).toBe(PreyState.size(fullCount, deltaCount))
			expect(PreyState.valid(b)).toBe(true)
			local s, t, f, d = PreyState.header(b)
			expect({ s, t, f, d }).toEqual({ seq, timeMs, fullCount, deltaCount })
			for i = 1, fullCount do
				PreyState.readFull(b, i - 1, full)
				expect(full).toEqual(fulls[i])
			end
			for i = 1, deltaCount do
				PreyState.readDelta(b, fullCount, i - 1, delta)
				expect(delta).toEqual(deltas[i])
			end
		end
	end)

	it("round-trips the edge values of every field", function()
		local zero = PreyState.newFull()
		zero.kind, zero.count = 1, 1
		local fulls = { edgeFull(), zero }
		local d = PreyState.newDelta()
		d.qvx, d.qvy, d.qvz, d.groupId = 127, -127, 0, 511
		local b = pack(65536 + 3, 4294967295, fulls, { d, PreyState.newDelta() })
		expect(PreyState.valid(b)).toBe(true)
		local seq, timeMs = PreyState.header(b)
		expect(seq).toBe(3) -- seq wraps at 65536
		expect(timeMs).toBe(4294967295)
		local out = PreyState.newFull()
		PreyState.readFull(b, 0, out)
		expect(out).toEqual(fulls[1])
		PreyState.readFull(b, 1, out)
		expect(out).toEqual(zero)
		local outDelta = PreyState.newDelta()
		PreyState.readDelta(b, 2, 0, outDelta)
		expect(outDelta).toEqual(d)
	end)

	it(
		"keeps the worst cases within 900 bytes (§5.3, §8.6) and refuses to build a bigger one",
		function()
			expect(Remotes.byName.PreyState.maxBytes).toBe(PreyState.MAX_BYTES)
			expect(PreyState.size(PreyState.MAX_FULL, 0)).toBe(888)
			expect(PreyState.size(0, PreyState.MAX_DELTA)).toBe(892)
			expect(PreyState.fits(PreyState.MAX_FULL + 1, 0)).toBe(false)
			expect(PreyState.fits(0, PreyState.MAX_DELTA + 1)).toBe(false)
			for f = 0, PreyState.MAX_FULL do
				local most = (900 - 8 - 22 * f) // 13
				expect(PreyState.fits(f, most)).toBe(true)
				expect(PreyState.fits(f, most + 1)).toBe(false)
			end
			local fulls = table.create(PreyState.MAX_FULL, edgeFull())
			local b = pack(0, 0, fulls, {})
			expect(buffer.len(b) <= 900 and PreyState.valid(b)).toBe(true)
			expect(function()
				PreyState.finish(scratch, 0, 0, PreyState.MAX_FULL, 1)
			end).toThrow()
			expect(function()
				PreyState.finish(scratch, 0, 0, 0, PreyState.MAX_DELTA + 1)
			end).toThrow()
		end
	)

	it("rejects truncated, padded and oversize buffers without throwing", function()
		local rng = Rng.new(8704)
		local b = pack(1, 2, { randomFull(rng), randomFull(rng) }, { randomDelta(rng) })
		local length = buffer.len(b)
		for cut = 0, length - 1 do
			local short = buffer.create(cut)
			buffer.copy(short, 0, b, 0, cut)
			expect(PreyState.valid(short)).toBe(false)
		end
		local long = buffer.create(length + 1)
		buffer.copy(long, 0, b, 0, length)
		expect(PreyState.valid(long)).toBe(false)
		expect(PreyState.valid(buffer.create(901))).toBe(false)
		expect(PreyState.valid(buffer.create(8))).toBe(true) -- an empty packet is well formed
		local lying = buffer.create(8)
		buffer.writeu8(lying, 6, 1) -- claims a full record it does not carry
		expect(PreyState.valid(lying)).toBe(false)
	end)

	it("rejects out-of-range fields", function()
		local function withFull(edit: (Full) -> ()): buffer
			local r = edgeFull()
			edit(r)
			return pack(0, 0, { r }, {})
		end
		local function withDelta(edit: (Delta) -> ()): buffer
			local r = PreyState.newDelta()
			edit(r)
			return pack(0, 0, {}, { r })
		end
		expect(PreyState.valid(withFull(function() end))).toBe(true)
		local bad = {
			withFull(function(r)
				r.groupId = 512
			end),
			withFull(function(r)
				r.kind = 0
			end),
			withFull(function(r)
				r.count = 0
			end),
			withFull(function(r)
				r.count = 25
			end),
			withFull(function(r)
				r.count, r.alive = 3, 8
			end),
			withFull(function(r)
				r.qx = Quantize.QX_MAX + 1
			end),
			withFull(function(r)
				r.qy = Quantize.QY_MAX + 1
			end),
			withFull(function(r)
				r.qz = 65535
			end),
			withFull(function(r)
				r.qvy = -128
			end),
			withFull(function(r)
				r.flags = 0x20
			end),
			withDelta(function(r)
				r.groupId = 65535
			end),
			withDelta(function(r)
				r.qy = Quantize.QY_MAX + 1
			end),
			withDelta(function(r)
				r.qvz = -128
			end),
			withDelta(function(r)
				r.flags = 0xFF
			end),
		}
		for _, b in bad do
			expect(PreyState.valid(b)).toBe(false)
		end
	end)
end)
