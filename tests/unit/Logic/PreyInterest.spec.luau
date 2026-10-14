--!strict
local Formation = require("../../../src/shared/Sim/Formation")
local PreyInterest = require("../../../src/shared/Logic/PreyInterest")
local PreySim = require("../../../src/shared/Sim/PreySim")
local PreyState = require("../../../src/shared/Net/Codec/PreyState")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local KRILL = Formation.kindOf("krill") :: number
local SARDINE = Formation.kindOf("sardine") :: number

local function newSim(): PreySim.Sim
	local sim = PreySim.new(7)
	PreySim.setHome(sim, 0, 0, -50, 0, 900, 40)
	return sim
end

local function step(sim: PreySim.Sim)
	PreySim.step(sim, sim.now + 0.1, 0.1)
end

-- Full and delta group IDs of a payload.
local function decode(payload: buffer): ({ number }, { number })
	expect(PreyState.valid(payload)).toBe(true)
	local _, _, f, d = PreyState.header(payload)
	local fulls, deltas = {}, {}
	local full, delta = PreyState.newFull(), PreyState.newDelta()
	for k = 0, f - 1 do
		PreyState.readFull(payload, k, full)
		table.insert(fulls, full.groupId)
	end
	for k = 0, d - 1 do
		PreyState.readDelta(payload, f, k, delta)
		table.insert(deltas, delta.groupId)
	end
	return fulls, deltas
end

describe("PreyInterest", function()
	it(
		"sends a new group as a full record in two consecutive packets, then nothing while it holds still",
		function()
			local sim = newSim()
			local g = PreySim.spawn(sim, SARDINE, 0, 10, -50, 0, 10) :: number
			local state = PreyInterest.new(2)
			step(sim)
			local p1 = PreyInterest.updatePlayer(state, sim, 1, 0, -50, 0) :: buffer
			local f1 = decode(p1)
			expect(f1).toEqual({ g })
			step(sim)
			local f2 = decode(PreyInterest.updatePlayer(state, sim, 1, 0, -50, 0) :: buffer)
			expect(f2).toEqual({ g })
			expect(PreyInterest.knows(state, 1, g, buffer.readu8(sim.buffers.gen, g), sim.tick)).toBe(
				true
			)
			expect(PreyInterest.knows(state, 2, g, buffer.readu8(sim.buffers.gen, g), sim.tick)).toBe(
				false
			)
		end
	)

	it("puts groups in bands and never sends a group beyond 600 studs", function()
		local sim = newSim()
		local far = PreySim.spawn(sim, SARDINE, 0, 500, -50, 0, 10) :: number
		PreySim.spawn(sim, SARDINE, 0, 0, -50, 700, 10)
		local state = PreyInterest.new(1)
		step(sim)
		local fulls = decode(PreyInterest.updatePlayer(state, sim, 1, 0, -50, 0) :: buffer)
		expect(fulls).toEqual({ far })
	end)

	it(
		"keyframes Near groups every 2 s on the staggered tick and keeps Far groups alive",
		function()
			local sim = newSim()
			local near = PreySim.spawn(sim, KRILL, 0, 20, -50, 0, 12) :: number
			local far = PreySim.spawn(sim, KRILL, 0, 450, -50, 0, 12) :: number
			local state = PreyInterest.new(1)
			local nearTicks, farTicks = {}, {}
			for _ = 1, 60 do
				-- Freeze the groups so only keyframes and keep-alives are due.
				for _, g in { near, far } do
					buffer.writef32(sim.buffers.velX, g * 4, 0)
					buffer.writef32(sim.buffers.velY, g * 4, 0)
					buffer.writef32(sim.buffers.velZ, g * 4, 0)
					buffer.writef32(sim.buffers.posX, g * 4, if g == near then 20 else 450)
					buffer.writef32(sim.buffers.posY, g * 4, -50)
					buffer.writef32(sim.buffers.posZ, g * 4, 0)
					buffer.writef32(sim.buffers.scatter, g * 4, 0)
					buffer.writeu8(sim.buffers.flags, g, 0)
				end
				sim.tick += 1
				sim.now += 0.1
				local payload = PreyInterest.updatePlayer(state, sim, 1, 0, -50, 0)
				if payload then
					local fulls, deltas = decode(payload)
					for _, g in fulls do
						if g == near then
							table.insert(nearTicks, sim.tick)
						end
					end
					for _, g in deltas do
						if g == far then
							table.insert(farTicks, sim.tick)
						end
					end
				end
			end
			-- Two fulls at first, then one keyframe per 20 ticks on (near + 1) % 20.
			expect(#nearTicks >= 4).toBe(true)
			for k = 3, #nearTicks do
				expect((nearTicks[k] - (near + 1)) % 20).toBe(0)
			end
			-- Far (8.5): a keep-alive delta every 1 s, on (far + 1) % 10, when the group was quiet
			-- for 0.5 s; never more than 14 ticks of silence.
			expect(#farTicks >= 4).toBe(true)
			for k = 2, #farTicks do
				expect(farTicks[k] - farTicks[k - 1] <= 14).toBe(true)
				expect((farTicks[k] - (far + 1)) % 10).toBe(0)
			end
			expect(farTicks[#farTicks] - farTicks[2]).toBe(10 * (#farTicks - 2))
		end
	)

	it(
		"sends nothing for a straight-line cruise, and a delta once the dead-reckoning error passes the band threshold",
		function()
			local sim = newSim()
			local g = PreySim.spawn(sim, SARDINE, 0, 200, -50, 0, 10) :: number -- Mid band
			local state = PreyInterest.new(1)
			local function set(x: number, vx: number)
				buffer.writef32(sim.buffers.posX, g * 4, x)
				buffer.writef32(sim.buffers.velX, g * 4, vx)
			end
			set(200, 4)
			for _ = 1, 2 do
				sim.tick += 1
				sim.now += 0.1
				PreyInterest.updatePlayer(state, sim, 1, 0, -50, 0)
			end
			local sent = 0
			for k = 1, 9 do
				sim.tick += 1
				sim.now += 0.1
				set(200 + 0.4 * (k + 1), 4) -- exactly as dead-reckoned
				local payload = PreyInterest.updatePlayer(state, sim, 1, 0, -50, 0)
				if payload and (g + 1) % 20 ~= sim.tick % 20 then
					sent += 1
				end
			end
			expect(sent).toBe(0)
			sim.tick += 1
			sim.now += 0.1
			set(200 + 0.4 * 11 + 3.5, 4) -- 3.5 studs off: over the Mid threshold of 3
			local _, deltas = decode(PreyInterest.updatePlayer(state, sim, 1, 0, -50, 0) :: buffer)
			expect(deltas).toEqual({ g })
		end
	)

	it("never builds a packet over 900 bytes and defers the rest, nearest first", function()
		local sim = newSim()
		for k = 0, 99 do
			PreySim.spawn(sim, KRILL, 0, (k % 10) * 40 - 200, -50, (k // 10) * 40 - 200, 12)
		end
		local state = PreyInterest.new(1)
		step(sim)
		local payload = PreyInterest.updatePlayer(state, sim, 1, 0, -50, 0) :: buffer
		expect(buffer.len(payload) <= 900).toBe(true)
		expect(state.lastFull[1]).toBe(PreyState.MAX_FULL)
		expect(state.lastDeferred[1]).toBe(100 - PreyState.MAX_FULL)
		-- Everything chosen is Near or Mid before anything Far... and the nearest are in.
		local fulls = decode(payload)
		local b = sim.buffers
		local worst = 0
		for _, g in fulls do
			local x, z = buffer.readf32(b.posX, g * 4), buffer.readf32(b.posZ, g * 4)
			worst = math.max(worst, math.sqrt(x * x + z * z))
		end
		expect(worst <= 350).toBe(true)
		-- Over the next ticks every group becomes known.
		for _ = 1, 8 do
			step(sim)
			PreyInterest.updatePlayer(state, sim, 1, 0, -50, 0)
			expect(state.lastBytes[1] <= 900).toBe(true)
		end
		local knownCount = 0
		for g = 0, 99 do
			if PreyInterest.knows(state, 1, g, buffer.readu8(b.gen, g), sim.tick) then
				knownCount += 1
			end
		end
		expect(knownCount).toBe(100)
	end)

	it(
		"resends a full record after a group was removed and its slot reused, and after a reset",
		function()
			local sim = newSim()
			local g = PreySim.spawn(sim, SARDINE, 0, 10, -50, 0, 10) :: number
			local state = PreyInterest.new(1)
			for _ = 1, 3 do
				step(sim)
				PreyInterest.updatePlayer(state, sim, 1, 0, -50, 0)
			end
			PreyInterest.forget(state, g)
			PreySim.remove(sim, g)
			local again = PreySim.spawn(sim, SARDINE, 0, 10, -50, 0, 10, false, g) :: number
			step(sim)
			local fulls = decode(PreyInterest.updatePlayer(state, sim, 1, 0, -50, 0) :: buffer)
			expect(fulls).toEqual({ again })
			PreyInterest.reset(state, 1)
			step(sim)
			fulls = decode(PreyInterest.updatePlayer(state, sim, 1, 0, -50, 0) :: buffer)
			expect(fulls).toEqual({ again })
		end
	)
end)
