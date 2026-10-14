--!strict
-- movement_fuzz (docs/09, section 16.2): SwimModel driven by random honest input with injected
-- jitter, 0 to 300 ms latency and 0.4 s stalls, as the server would see it.
--
-- Two halves:
--   1. The model half (runs now): honest traces stay inside the envelope the validator's rules
--      assume (finite poses, pitch within ±70°, speed never above the dash speed, dashes no
--      closer than the cooldown, never started in the air), traces are deterministic for a seed,
--      and the harness delivers the 20 Hz server pose stream with the latency, jitter and stalls
--      it promises. A 1.3 × speed cheat trace is built and checked to really be 1.3 × faster.
--   2. The validator half (SKIPPED): "no honest trace reaches suspicion 10; a 1.3 × speed trace
--      is flagged within 5 s" needs MovementValidator's pure rules (09 §7, module B14, task
--      S8-C3). Nothing here stands in for them. When B14 lands, feed `serverStream` of the honest
--      and cheat traces below to its rules and add the two checks.
local Index = require("../../src/shared/Data/Index")
local Rng = require("../../src/shared/Util/Rng")
local SwimModel = require("../../src/shared/Sim/SwimModel")
local TestKit = require("../../src/shared/Util/TestKit")
local Types = require("../../src/shared/Types")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- Harness parameters (test inputs, not game tunables).
local TRACES = 24 -- one per player slot
local SECONDS = 60
local SERVER_TICK = 1 / 20 -- 09 §7: the validator runs at 20 Hz
local MAX_LATENCY = 0.3 -- 09 §16.2: 0 to 300 ms
local JITTER = 0.04 -- ± seconds of latency jitter per sample
local STALL = 0.4 -- 09 §16.2: 0.4 s stalls
local STALLS_PER_MINUTE = 6
local SPECIES = { "minnow", "puffer", "eel" } -- the MVP species
local SPEED_CEILING = 1.15 -- × dash speed: a sanity ceiling for the slide, not a game rule

export type Sample = { t: number, x: number, y: number, z: number, tier: number }

export type Trace = {
	speciesId: string,
	tier: number,
	serverStream: { Sample }, -- what the server reads each tick: the newest pose that has arrived
	dashStarts: { number }, -- client times
	worstSpeedOverDash: number, -- max speed / dash speed
	airDashes: number, -- dashes started while airborne, must be 0
	finite: boolean,
	pitchOk: boolean,
	stalls: number,
	latencyOk: boolean,
	worstWindowRatio: number, -- informational: max 1 s displacement / top speed, outside dashes
}

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

-- One trace. `cheat` multiplies speed as an exploiter's client would (statusMult 1.3).
local function runTrace(seed: number, cheat: number): Trace
	local rng = Rng.new(seed)
	local speciesId = SPECIES[1 + (seed % #SPECIES)]
	local tier = 1 + (seed % 7)
	local species = Index.Species.byId[speciesId]
	local state = SwimModel.new(speciesId, tier)
	SwimModel.place(
		state,
		Rng.range(rng, -500, 500),
		Rng.range(rng, -300, -20),
		Rng.range(rng, -500, 500),
		0,
		0
	)
	state.mods.speedMult = cheat
	local top = SwimModel.topSpeed(tier, species, cheat)
	local dashSpeed = SwimModel.dashSpeed(tier, species, cheat)

	local input: Types.SwimInput = {
		throttle = 0,
		strafe = 0,
		brake = false,
		yawTarget = nil,
		yawRate = 0,
		pitchTarget = 0,
		dash = false,
	}
	local frameDt = if Rng.chance(rng, 0.5) then 1 / 60 else 1 / 30
	local baseLatency = Rng.range(rng, 0, MAX_LATENCY)

	-- Client poses with their arrival time at the server.
	local sentT, sentX, sentY, sentZ, arrive = {}, {}, {}, {}, {}
	local trace: Trace = {
		speciesId = speciesId,
		tier = tier,
		serverStream = {},
		dashStarts = {},
		worstSpeedOverDash = 0,
		airDashes = 0,
		finite = true,
		pitchOk = true,
		stalls = 0,
		latencyOk = true,
		worstWindowRatio = 0,
	}

	local t, nextChange, stallUntil, lastArrival = 0, 0, -1, 0
	while t < SECONDS do
		-- An honest player changes intent every 0.2 to 2 s.
		if t >= nextChange then
			nextChange = t + Rng.range(rng, 0.2, 2)
			input.throttle = if Rng.chance(rng, 0.8) then Rng.range(rng, 0.3, 1) else 0
			input.strafe = if Rng.chance(rng, 0.2) then Rng.range(rng, -1, 1) else 0
			input.brake = Rng.chance(rng, 0.05)
			input.yawRate = Rng.range(rng, -400, 400)
			input.pitchTarget = Rng.range(rng, -70, 70)
			-- Steer home when far out, and up when deep, so the trace stays in the map.
			if state.x * state.x + state.z * state.z > 900 * 900 then
				input.yawTarget = math.deg(math.atan2(state.x, state.z))
			else
				input.yawTarget = nil
			end
			if state.y < -550 then
				input.pitchTarget = 40
			end
		end
		input.dash = Rng.chance(rng, 0.02)

		-- A jittered client frame, and now and then a hitch longer than MAX_DT.
		local dt = frameDt * Rng.range(rng, 0.8, 1.2)
		if Rng.chance(rng, 0.002) then
			dt = Rng.range(rng, 0.1, 0.5)
		end
		local wasAirborne = state.airborne
		SwimModel.step(state, input, dt)
		t += dt

		if state.dashStarted then
			table.insert(trace.dashStarts, t - dt)
			if wasAirborne then
				trace.airDashes += 1
			end
		end
		local speed = SwimModel.speed(state)
		trace.worstSpeedOverDash = math.max(trace.worstSpeedOverDash, speed / dashSpeed)
		if not (finite(state.x) and finite(state.y) and finite(state.z) and finite(speed)) then
			trace.finite = false
		end
		if math.abs(state.pitch) > 70 + 1e-9 then
			trace.pitchOk = false
		end

		-- The network: latency with jitter, in order, and stalls that release in a burst.
		if t > stallUntil and Rng.chance(rng, STALLS_PER_MINUTE / 60 * dt) then
			stallUntil = t + STALL
			trace.stalls += 1
		end
		local latency = math.clamp(baseLatency + Rng.range(rng, -JITTER, JITTER), 0, MAX_LATENCY)
		local at = math.max(t + latency, lastArrival)
		if t < stallUntil then
			at = math.max(at, stallUntil + latency)
		end
		lastArrival = at
		table.insert(sentT, t)
		table.insert(sentX, state.x)
		table.insert(sentY, state.y)
		table.insert(sentZ, state.z)
		table.insert(arrive, at)
	end

	-- The server's 20 Hz view: at each tick, the newest pose that has arrived.
	local newest = 0
	local tick = SERVER_TICK
	while tick < SECONDS do
		while newest < #arrive and arrive[newest + 1] <= tick do
			newest += 1
		end
		if newest > 0 then
			local lag = tick - sentT[newest]
			if lag < -1e-9 then
				trace.latencyOk = false
			end
			table.insert(
				trace.serverStream,
				{ t = tick, x = sentX[newest], y = sentY[newest], z = sentZ[newest], tier = tier }
			)
		end
		tick += SERVER_TICK
	end

	-- Informational: the largest 1 s client-side displacement over top speed, away from dashes.
	local first = 1
	for last = 1, #sentT do
		while sentT[last] - sentT[first] > 1 do
			first += 1
		end
		local nearDash = false
		for _, start in trace.dashStarts do
			if start > sentT[first] - 2 and start < sentT[last] then
				nearDash = true
				break
			end
		end
		if not nearDash and sentT[last] - sentT[first] > 0.9 then
			local dx, dy, dz =
				sentX[last] - sentX[first], sentY[last] - sentY[first], sentZ[last] - sentZ[first]
			local ratio = math.sqrt(dx * dx + dy * dy + dz * dz)
				/ (top * (sentT[last] - sentT[first]))
			trace.worstWindowRatio = math.max(trace.worstWindowRatio, ratio)
		end
	end
	return trace
end

local honest: { Trace } = {}
for seed = 1, TRACES do
	honest[seed] = runTrace(seed, 1)
end

describe("movement_fuzz, model half", function()
	it("keeps every honest pose finite with pitch inside ±70°", function()
		for _, trace in honest do
			expect(trace.finite).toBe(true)
			expect(trace.pitchOk).toBe(true)
		end
	end)

	it("stays near the dash speed: turn slide and strafe add a few percent, never more", function()
		-- 02 §1.3 relaxes forward and lateral speed separately, so a creature that turns or
		-- strafes at full speed slides: its speed can pass the forward target briefly.
		local worst = 0
		for _, trace in honest do
			worst = math.max(worst, trace.worstSpeedOverDash)
		end
		print(string.format("movement_fuzz: worst honest speed = %.3f × dash speed", worst))
		expect(worst <= SPEED_CEILING).toBe(true)
	end)

	it("spaces dashes by at least the species cooldown and never starts one in the air", function()
		local dashes = 0
		for _, trace in honest do
			local cooldown = SwimModel.dashCooldown(Index.Species.byId[trace.speciesId])
			for i = 2, #trace.dashStarts do
				expect(trace.dashStarts[i] - trace.dashStarts[i - 1] >= cooldown - 1e-9).toBe(true)
			end
			dashes += #trace.dashStarts
			expect(trace.airDashes).toBe(0)
		end
		expect(dashes > TRACES * 5).toBe(true)
	end)

	it("delivers a 20 Hz server stream with latency, jitter and 0.4 s stalls", function()
		local stalls = 0
		for _, trace in honest do
			expect(trace.latencyOk).toBe(true)
			expect(#trace.serverStream > SECONDS / SERVER_TICK - 10).toBe(true)
			stalls += trace.stalls
		end
		expect(stalls > TRACES).toBe(true)
	end)

	it("is deterministic for a seed", function()
		local again = runTrace(5, 1)
		expect(again.serverStream).toEqual(honest[5].serverStream)
	end)

	it("builds a 1.3 × speed cheat trace that really is 1.3 × faster", function()
		local cheat = runTrace(5, 1.3)
		local fair = SwimModel.topSpeed(cheat.tier, Index.Species.byId[cheat.speciesId], 1)
		local probe = SwimModel.new(cheat.speciesId, cheat.tier)
		probe.mods.speedMult = 1.3
		SwimModel.place(probe, 0, -100, 0, 0, 0)
		local input: Types.SwimInput = {
			throttle = 1,
			strafe = 0,
			brake = false,
			yawTarget = nil,
			yawRate = 0,
			pitchTarget = 0,
			dash = false,
		}
		for _ = 1, 240 do
			SwimModel.step(probe, input, 1 / 60)
		end
		expect(SwimModel.speed(probe)).toBeCloseTo(1.3 * fair, 0.01)
		expect(#cheat.serverStream).toBe(#honest[5].serverStream)
	end)

	it("reports the honest 1 s displacement envelope (informational, for B14)", function()
		local worst = 0
		for _, trace in honest do
			worst = math.max(worst, trace.worstWindowRatio)
		end
		print(
			string.format(
				"movement_fuzz: worst honest 1 s displacement away from dashes = %.3f × top speed "
					.. "(strafe adds up to 0.6 × top sideways)",
				worst
			)
		)
		expect(worst > 0).toBe(true)
	end)
end)

print(
	"movement_fuzz: validator half SKIPPED until MovementValidator (B14, S8-C3): "
		.. "honest traces below suspicion 10, 1.3× trace flagged within 5 s"
)
