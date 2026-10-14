--!strict
local PreyEvent = require("../../../src/shared/Net/Codec/PreyEvent")
local PreyMirror = require("../../../src/shared/Logic/PreyMirror")
local PreyState = require("../../../src/shared/Net/Codec/PreyState")
local Quantize = require("../../../src/shared/Sim/Quantize")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function full(
	groupId: number,
	x: number,
	z: number,
	vx: number,
	vz: number,
	count: number?,
	gen: number?
): PreyState.Full
	local r = PreyState.newFull()
	local n = count or 12
	r.groupId, r.gen, r.kind, r.count, r.seed = groupId, gen or 1, 2, n, 77
	r.alive = bit32.rshift(0xFFFFFFFF, 32 - n)
	r.qx, r.qy, r.qz = Quantize.x(x), Quantize.y(0), Quantize.z(z)
	r.qvx, r.qvy, r.qvz = Quantize.vel(vx), 0, Quantize.vel(vz)
	return r
end

local function delta(groupId: number, x: number, z: number, vx: number, vz: number): PreyState.Delta
	local r = PreyState.newDelta()
	r.groupId = groupId
	r.qx, r.qy, r.qz = Quantize.x(x), Quantize.y(0), Quantize.z(z)
	r.qvx, r.qvy, r.qvz = Quantize.vel(vx), 0, Quantize.vel(vz)
	return r
end

local function packet(
	seq: number,
	timeMs: number,
	fulls: { PreyState.Full },
	deltas: { PreyState.Delta }
): buffer
	local scratch = PreyState.newScratch()
	for k, r in fulls do
		PreyState.writeFull(scratch, k - 1, r)
	end
	for k, r in deltas do
		PreyState.writeDelta(scratch, #fulls, k - 1, r)
	end
	return PreyState.finish(scratch, seq, timeMs, #fulls, #deltas)
end

describe("PreyMirror packets (09 §8.7)", function()
	it("drops packets not newer than the newest seq, with u16 wrap", function()
		local m = PreyMirror.new()
		expect(PreyMirror.acceptSeq(m, 65534)).toBe(true)
		expect(PreyMirror.acceptSeq(m, 65534)).toBe(false)
		expect(PreyMirror.acceptSeq(m, 65000)).toBe(false)
		expect(PreyMirror.acceptSeq(m, 65535)).toBe(true)
		expect(PreyMirror.acceptSeq(m, 0)).toBe(true)
		expect(PreyMirror.acceptSeq(m, 3)).toBe(true)
		expect(PreyMirror.acceptSeq(m, 65535)).toBe(false)
	end)

	it("adds a group from a full record and ignores a delta for an unknown group", function()
		local m = PreyMirror.new()
		expect(
			PreyMirror.applyPacket(
				m,
				packet(1, 1000, { full(5, 10, 20, 2, 0) }, { delta(9, 0, 0, 0, 0) }),
				0
			)
		).toBe(true)
		expect(PreyMirror.size(m)).toBe(1)
		expect(m.live[6]).toBe(true)
		expect(m.live[10]).toBe(false)
		expect(m.px[6]).toBe(10)
		expect(m.vx[6]).toBe(2)
		expect(m.t0[6]).toBe(1)
		-- A stale packet changes nothing.
		expect(PreyMirror.applyPacket(m, packet(1, 1100, {}, { delta(5, 50, 50, 0, 0) }), 0)).toBe(
			false
		)
		expect(m.px[6]).toBe(10)
		expect(PreyMirror.applyPacket(m, packet(2, 1100, {}, { delta(5, 50, 50, 0, 0) }), 0)).toBe(
			true
		)
		expect(m.px[6]).toBe(50)
	end)

	it("rejects a malformed payload", function()
		local m = PreyMirror.new()
		expect(PreyMirror.applyPacket(m, buffer.create(9), 0)).toBe(false)
		expect(m.hasSeq).toBe(false)
	end)

	it("restarts a group whose ID came back with a new gen", function()
		local m = PreyMirror.new()
		PreyMirror.applyFull(m, full(3, 0, 0, 0, 0), 0, 0)
		PreyMirror.step(m, 0, 1 / 60)
		PreyMirror.applyFull(m, full(3, 100, 0, 0, 0, 12, 2), 0, 0)
		PreyMirror.step(m, 0, 1 / 60)
		expect(m.dx[4]).toBe(100) -- snapped, not eased
		expect(PreyMirror.size(m)).toBe(1)
	end)
end)

describe("PreyMirror dead reckoning (09 §8.8)", function()
	it("targets lastPos + lastVel × elapsed and snaps on the first step", function()
		local m = PreyMirror.new()
		PreyMirror.applyFull(m, full(0, 10, 0, 4, -2), 5, 0)
		local x, _, z = PreyMirror.target(m, 0, 5.5)
		expect(x).toBeCloseTo(12, 1e-9)
		expect(z).toBeCloseTo(-1, 1e-9)
		PreyMirror.step(m, 5.5, 1 / 60)
		expect(m.dx[1]).toBeCloseTo(12, 1e-9)
		-- Heading: atan2(vx, vz), Formation's convention.
		expect(m.heading[1]).toBeCloseTo(math.atan2(4, -2), 1e-9)
	end)

	it("eases toward a corrected target with a 0.1 s time constant, never popping", function()
		local m = PreyMirror.new()
		PreyMirror.applyFull(m, full(0, 0, 0, 0, 0), 0, 0)
		PreyMirror.step(m, 0, 0)
		PreyMirror.applyDelta(m, delta(0, 10, 0, 0, 0), 0, 0)
		PreyMirror.step(m, 0, 0.1)
		expect(m.dx[1]).toBeCloseTo(10 * (1 - math.exp(-1)), 1e-9)
		for _ = 1, 120 do
			PreyMirror.step(m, 0, 1 / 60)
		end
		expect(m.dx[1]).toBeCloseTo(10, 1e-3)
	end)

	it("turns the heading along the shorter arc and keeps it while still", function()
		local m = PreyMirror.new()
		PreyMirror.applyFull(m, full(0, 0, 0, -0.5, -10), 0, 0) -- heading near −π
		PreyMirror.step(m, 0, 0)
		local h0 = m.heading[1]
		PreyMirror.applyDelta(m, delta(0, 0, 0, 0.5, -10), 0, 0) -- heading near +π
		PreyMirror.step(m, 0, 0.05)
		expect(math.abs(m.heading[1] - h0) < 0.2).toBe(true)
		local h1 = m.heading[1]
		PreyMirror.applyDelta(m, delta(0, 0, 0, 0, 0), 0, 0)
		PreyMirror.step(m, 0, 1)
		expect(m.heading[1]).toBe(h1)
	end)
end)

describe("PreyMirror events and the 3 s rule (09 §8.5, §8.7)", function()
	it("clears and restores alive bits, ignores a stale gen, removes on op 2", function()
		local m = PreyMirror.new()
		PreyMirror.applyFull(m, full(7, 0, 0, 0, 0, 4), 0, 0)
		expect(PreyMirror.applyEvent(m, PreyEvent.OP_EATEN, 7, 1, 2)).toBe(true)
		expect(m.alive[8]).toBe(0b1011)
		expect(PreyMirror.applyEvent(m, PreyEvent.OP_EATEN, 7, 9, 0)).toBe(false)
		expect(PreyMirror.applyEvent(m, PreyEvent.OP_RESTORED, 7, 1, 2)).toBe(true)
		expect(m.alive[8]).toBe(0b1111)
		expect(PreyMirror.applyEvent(m, PreyEvent.OP_RESTORED, 7, 1, 5)).toBe(false) -- past count
		local b = PreyEvent.create(1)
		PreyEvent.write(b, 0, PreyEvent.OP_REMOVED, 7, 1, 0, 0)
		expect(PreyMirror.applyEvents(m, b)).toBe(true)
		expect(PreyMirror.size(m)).toBe(0)
	end)

	it("drops a group not heard about for 3 s; a keep-alive delta saves it", function()
		local m = PreyMirror.new()
		PreyMirror.applyFull(m, full(1, 0, 0, 0, 0), 0, 10)
		PreyMirror.applyFull(m, full(2, 0, 0, 0, 0), 0, 10)
		PreyMirror.applyDelta(m, delta(2, 0, 0, 0, 0), 2, 12)
		expect(PreyMirror.dropStale(m, 12.9)).toBe(0)
		expect(PreyMirror.dropStale(m, 13.1)).toBe(1)
		expect(m.live[2]).toBe(false)
		expect(m.live[3]).toBe(true)
		expect(PreyMirror.dropStale(m, 15.1)).toBe(1)
		expect(PreyMirror.size(m)).toBe(0)
	end)
end)

describe("PreyMirror.assign (09 §8.8, §15.1)", function()
	it(
		"gives meshes nearest first, whole groups while the budget lasts, none past the range",
		function()
			local m = PreyMirror.new()
			PreyMirror.applyFull(m, full(0, 100, 0, 0, 0, 20), 0, 0)
			PreyMirror.applyFull(m, full(1, 10, 0, 0, 0, 20), 0, 0)
			PreyMirror.applyFull(m, full(2, 50, 0, 0, 0, 20), 0, 0)
			PreyMirror.applyFull(m, full(3, 400, 0, 0, 0, 20), 0, 0)
			PreyMirror.step(m, 0, 0)
			local given, front = PreyMirror.assign(m, 0, 0, 0, 50)
			expect(given).toBe(50)
			expect(front).toBe(3)
			expect(m.order[1]).toBe(1)
			expect(m.order[2]).toBe(2)
			expect(m.order[3]).toBe(0)
			expect(m.drawn[2]).toBe(20)
			expect(m.drawn[3]).toBe(20)
			expect(m.drawn[1]).toBe(10)
			given, front = PreyMirror.assign(m, 0, 0, 0, 250)
			expect(given).toBe(60)
			expect(front).toBe(3)
			expect(m.drawn[4]).toBe(0) -- Far band: particles (S4-C1)
		end
	)

	it("counts only live members and follows groups that come and go", function()
		local m = PreyMirror.new()
		PreyMirror.applyFull(m, full(0, 10, 0, 0, 0, 8), 0, 0)
		PreyMirror.applyFull(m, full(1, 20, 0, 0, 0, 8), 0, 0)
		PreyMirror.applyEvent(m, PreyEvent.OP_EATEN, 0, 1, 0)
		PreyMirror.step(m, 0, 0)
		expect(PreyMirror.assign(m, 0, 0, 0, 80)).toBe(15)
		PreyMirror.remove(m, 0)
		PreyMirror.applyFull(m, full(5, 5, 0, 0, 0, 8), 0, 0)
		PreyMirror.step(m, 0, 0)
		local given, front = PreyMirror.assign(m, 0, 0, 0, 80)
		expect(given).toBe(16)
		expect(front).toBe(2)
		expect(m.order[1]).toBe(5)
		expect(m.order[2]).toBe(1)
		expect(#m.order).toBe(2)
		for _, id in m.ids do
			expect(m.at[id + 1] > 0).toBe(true)
		end
	end)

	it("finds the nearest group of a kind with a member alive", function()
		local m = PreyMirror.new()
		PreyMirror.applyFull(m, full(0, 10, 0, 0, 0), 0, 0)
		PreyMirror.applyFull(m, full(1, 30, 0, 0, 0), 0, 0)
		PreyMirror.step(m, 0, 0)
		local id, d = PreyMirror.nearest(m, 0, 0, 0, { [2] = true })
		expect(id).toBe(0)
		expect(d).toBeCloseTo(10, 1e-9)
		expect((PreyMirror.nearest(m, 0, 0, 0, { [1] = true }))).toBe(nil)
		expect(PreyMirror.poolSize("Smooth")).toBe(80)
		expect(PreyMirror.poolSize("Pretty")).toBe(250)
	end)
end)
