--!strict
local Index = require("../../../src/shared/Data/Index")
local SwimModel = require("../../../src/shared/Sim/SwimModel")
local TestKit = require("../../../src/shared/Util/TestKit")
local Types = require("../../../src/shared/Types")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type SwimState = SwimModel.SwimState

local DT = 1 / 60

local function newInput(): Types.SwimInput
	return {
		throttle = 0,
		strafe = 0,
		brake = false,
		yawTarget = nil,
		yawRate = 0,
		pitchTarget = 0,
		dash = false,
	}
end

-- A creature placed deep enough that the surface never matters.
local function deep(speciesId: string, tier: number): SwimState
	local state = SwimModel.new(speciesId, tier)
	SwimModel.place(state, 0, -200, 0, 0, 0)
	return state
end

local function run(state: SwimState, input: Types.SwimInput, seconds: number, dt: number?)
	local h = dt or DT
	local steps = math.floor(seconds / h + 0.5)
	for _ = 1, steps do
		SwimModel.step(state, input, h)
	end
end

local function horizontalDistance(state: SwimState, x: number, z: number): number
	return math.sqrt((state.x - x) ^ 2 + (state.z - z) ^ 2)
end

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function allFinite(state: SwimState): boolean
	return finite(state.x)
		and finite(state.y)
		and finite(state.z)
		and finite(state.vx)
		and finite(state.vy)
		and finite(state.vz)
		and finite(state.yaw)
		and finite(state.pitch)
		and finite(state.lookX)
		and finite(state.lookY)
		and finite(state.lookZ)
end

describe("SwimModel tier tables", function()
	it("reaches each tier's swim speed from the Tiers data at full throttle", function()
		for _, def in Index.Tiers.list do
			local state = deep("minnow", def.tier)
			local input = newInput()
			input.throttle = 1
			run(state, input, 4)
			expect(SwimModel.speed(state)).toBeCloseTo(def.swimSpeed, 0.01)
			expect(SwimModel.tierSpeed(def.tier)).toBe(def.swimSpeed)
		end
	end)

	it("turns at each tier's turn rate from the Tiers data, and turns on the spot", function()
		for _, def in Index.Tiers.list do
			local state = deep("minnow", def.tier)
			local input = newInput()
			input.yawRate = -10000 -- hard left: clamped to the turn rate
			run(state, input, 0.25)
			expect(state.yaw).toBeCloseTo(def.turnRate * 0.25, 1e-6)
			expect(SwimModel.speed(state)).toBe(0)
		end
	end)

	it("eases into a target heading over the last degrees and never overshoots", function()
		local state = deep("minnow", 1)
		local input = newInput()
		input.yawTarget = 90
		local last = 0
		for _ = 1, 120 do
			SwimModel.step(state, input, DT)
			expect(state.yaw <= 90).toBe(true)
			expect(state.yaw >= last).toBe(true)
			last = state.yaw
		end
		-- 81° at 360°/s takes 0.225 s, then the last 9° ease out as e^(−10 t).
		expect(state.yaw).toBeCloseTo(90, 0.01)
		input.yawTarget = -170 -- the short way round is through ±180
		run(state, input, 0.1)
		expect(state.yaw > 90).toBe(true)
	end)

	it("clamps pitch to ±70 and uses the same rate for pitch as for yaw", function()
		local state = deep("minnow", 4)
		local input = newInput()
		input.pitchTarget = 90
		run(state, input, 0.1)
		expect(state.pitch).toBeCloseTo(24, 1e-6) -- 240°/s × 0.1 s
		run(state, input, 2)
		expect(state.pitch).toBeCloseTo(70, 0.01)
		input.pitchTarget = -300
		run(state, input, 2)
		expect(state.pitch).toBeCloseTo(-70, 0.01)
	end)

	it("switches speed and turn rate at once on a tier change", function()
		local state = deep("minnow", 1)
		local input = newInput()
		input.throttle = 1
		run(state, input, 3)
		SwimModel.setTier(state, 7)
		expect(state.turnRate).toBe(140)
		run(state, input, 5)
		expect(SwimModel.speed(state)).toBeCloseTo(38, 0.01)
		SwimModel.setTier(state, 2)
		run(state, input, 5)
		expect(SwimModel.speed(state)).toBeCloseTo(28, 0.01)
	end)

	it("refuses an unknown tier or species", function()
		expect(function()
			SwimModel.new("minnow", 8)
		end).toThrow("no tier 8")
		expect(function()
			SwimModel.new("kraken", 1)
		end).toThrow("no species kraken")
	end)
end)

describe("SwimModel species multipliers", function()
	it("scales top speed by species.speedMult", function()
		for _, id in { "puffer", "eel", "turtle", "squid", "shark" } do
			local species = Index.Species.byId[id]
			local state = deep(id, 3)
			local input = newInput()
			input.throttle = 1
			run(state, input, 4)
			expect(SwimModel.speed(state)).toBeCloseTo(30 * species.speedMult, 0.01)
			expect(SwimModel.topSpeed(3, species, 1)).toBeCloseTo(30 * species.speedMult, 1e-9)
		end
	end)

	it("scales turn rate by species.turnMult", function()
		for _, id in { "puffer", "eel", "turtle", "squid" } do
			local species = Index.Species.byId[id]
			local state = deep(id, 1)
			local input = newInput()
			input.yawRate = 10000
			run(state, input, 0.1)
			expect(state.yaw).toBeCloseTo(-36 * species.turnMult, 1e-6)
			expect(SwimModel.turnRate(1, species)).toBeCloseTo(360 * species.turnMult, 1e-9)
		end
	end)

	it("applies the status speed and turn multipliers from the mods", function()
		local state = deep("minnow", 1)
		local input = newInput()
		input.throttle = 1
		input.yawRate = 10000
		state.mods.speedMult = 0.4 -- Puffed
		state.mods.turnMult = 0 -- Stunned
		run(state, input, 4)
		expect(SwimModel.speed(state)).toBeCloseTo(26 * 0.4, 0.01)
		expect(state.yaw).toBe(0)
	end)

	it("sets the collision radius from body scale and species.radiusMult", function()
		local state = SwimModel.new("minnow", 4)
		expect(state.radius).toBeCloseTo(0.9 * 2.3, 1e-9)
		SwimModel.setBodyScale(state, 1.24)
		expect(state.radius).toBeCloseTo(0.9 * 1.24, 1e-9)
	end)
end)

describe("SwimModel dash", function()
	it("bursts to 2.2× top speed along the facing, without throttle, for 0.35 s", function()
		local state = deep("minnow", 1)
		local input = newInput()
		input.throttle = 1
		run(state, input, 3)
		input.throttle = 0
		input.dash = true
		SwimModel.step(state, input, DT)
		expect(state.dashStarted).toBe(true)
		expect(state.dashing).toBe(true)
		input.dash = false
		local x, z = state.x, state.z
		run(state, input, 0.35 - DT)
		expect(state.dashing).toBe(false)
		expect(state.dashLength).toBeCloseTo(0.35, 1e-9)
		-- Peak forward speed is 57.2; distance over the dash "about 20" studs (02 §7.1).
		local travelled = horizontalDistance(state, x, z) + 26 * DT
		expect(travelled > 18 and travelled < 21).toBe(true)
		expect(SwimModel.dashSpeed(1, Index.Species.byId.minnow, 1)).toBeCloseTo(57.2, 1e-9)
	end)

	it("reaches the dash speed within the dash", function()
		local state = deep("puffer", 5)
		local input = newInput()
		input.dash = true
		run(state, input, 0.3)
		expect(SwimModel.speed(state)).toBeCloseTo(34 * 0.88 * 2.2, 0.01)
	end)

	it("lasts 0.455 s for the Eel and 0.3 longer per Longfin", function()
		local eel = Index.Species.byId.eel
		expect(SwimModel.dashDuration(eel, 0)).toBeCloseTo(0.455, 1e-9)
		expect(SwimModel.dashDuration(Index.Species.byId.minnow, 1)).toBeCloseTo(0.455, 1e-9)
		expect(SwimModel.dashDuration(eel, 1)).toBeCloseTo(0.56, 1e-9)
		local state = deep("eel", 1)
		state.mods.longfins = 1
		local input = newInput()
		input.dash = true
		SwimModel.step(state, input, DT)
		expect(state.dashLength).toBeCloseTo(0.56, 1e-9)
	end)

	it("cools down from the dash start: 2.0 s for the Minnow, 2.5 s for the Puffer", function()
		for _, case in { { id = "minnow", cooldown = 2.0 }, { id = "puffer", cooldown = 2.5 } } do
			local state = deep(case.id, 1)
			expect(SwimModel.dashCooldown(Index.Species.byId[case.id])).toBe(case.cooldown)
			local tap = newInput()
			tap.dash = true
			local idle = newInput()
			SwimModel.step(state, tap, DT)
			expect(state.dashStarted).toBe(true)
			-- Pressed 0.3 s before the cooldown ends: outside the 0.25 s buffer, dropped.
			run(state, idle, case.cooldown - 0.3 - DT)
			SwimModel.step(state, tap, DT)
			expect(state.dashStarted).toBe(false)
			run(state, idle, 0.4)
			expect(state.dashing).toBe(false)
			expect(SwimModel.canDash(state)).toBe(true)
		end
	end)

	it("buffers a blocked press for 0.25 s and fires it when the block ends", function()
		local state = deep("puffer", 1)
		local tap = newInput()
		tap.dash = true
		local idle = newInput()
		SwimModel.step(state, tap, DT) -- starts at t = 0
		run(state, idle, 2.3 - DT)
		SwimModel.step(state, tap, DT) -- pressed at t = 2.3, still cooling
		expect(state.dashStarted).toBe(false)
		local fired = -1
		for frame = 1, 30 do
			SwimModel.step(state, idle, DT)
			if state.dashStarted then
				fired = frame
				break
			end
		end
		-- The cooldown ends at t = 2.5, 12 frames after the press (13 when the summed frame
		-- times land a hair short of 2.5).
		expect(fired >= 12 and fired <= 13).toBe(true)
	end)

	it("re-fires a held dash each time the cooldown ends", function()
		local state = deep("minnow", 1)
		local held = newInput()
		held.dash = true
		local starts = 0
		for _ = 1, 60 * 5 do
			SwimModel.step(state, held, DT)
			if state.dashStarted then
				starts += 1
			end
		end
		expect(starts).toBe(3) -- t = 0, 2, 4
	end)

	it("halves the turn rate while dashing", function()
		local state = deep("minnow", 1)
		local input = newInput()
		input.dash = true
		input.yawRate = -10000
		run(state, input, 0.2)
		expect(state.yaw).toBeCloseTo(180 * 0.2, 1e-6)
	end)

	it("cannot start while blocked by a status, and endDash ends it early", function()
		local state = deep("minnow", 1)
		local input = newInput()
		input.dash = true
		state.mods.dashBlocked = true
		run(state, input, 0.5)
		expect(state.dashing).toBe(false)
		state.mods.dashBlocked = false
		SwimModel.step(state, input, DT)
		expect(state.dashing).toBe(true)
		SwimModel.endDash(state)
		expect(state.dashing).toBe(false)
		expect(SwimModel.canDash(state)).toBe(false)
	end)
end)

describe("SwimModel per-species dash and acceleration", function()
	it(
		"dashes at topSpeed × species.dashMult: 2.2, Sea Turtle 2.0, Squid 2.6 (03 §1.1)",
		function()
			for _, case in
				{
					{ id = "minnow", mult = 2.2 },
					{ id = "turtle", mult = 2.0 },
					{ id = "squid", mult = 2.6 },
				}
			do
				local species = Index.Species.byId[case.id]
				expect(species.dashMult).toBe(case.mult)
				expect(SwimModel.dashMult(species)).toBe(case.mult)
				local state = deep(case.id, 3)
				expect(state.dashMult).toBe(case.mult)
				local input = newInput()
				input.dash = true
				run(state, input, 0.3)
				local top = 30 * species.speedMult
				expect(SwimModel.speed(state)).toBeCloseTo(top * case.mult, 0.01)
				expect(SwimModel.dashSpeed(3, species, 1)).toBeCloseTo(top * case.mult, 1e-9)
			end
		end
	)

	it("multiplies accel, coast, brake and grip by species.accelMult (02 §1.3)", function()
		for _, species in Index.Species.list do
			expect(species.accelMult).toBe(1)
		end
		local state = SwimModel.new("minnow", 2)
		expect(state.accel).toBe(8.5)
		expect(SwimModel.accel(2, Index.Species.byId.minnow)).toBe(8.5)
		state.accelMult = 1.5
		SwimModel.setTier(state, 2)
		expect(state.accel).toBeCloseTo(8.5 * 1.5, 1e-9)
		expect(state.coast).toBeCloseTo(2.5 * 1.5, 1e-9)
		expect(state.brake).toBeCloseTo(7.5 * 1.5, 1e-9)
		expect(state.grip).toBeCloseTo(11 * 1.5, 1e-9)
	end)
end)

describe("SwimModel allowed-speed rules (09 §7.1)", function()
	it("adds a current as 0.6 × tierSpeed, unscaled by species or dash", function()
		expect(SwimModel.currentSpeed(1)).toBeCloseTo(0.6 * 26, 1e-9)
		local vF, vA = SwimModel.allowedSpeed(1, 10, true)
		expect(vF).toBeCloseTo(10 + 15.6, 1e-9)
		expect(vA).toBeCloseTo(10 * 1.17 + 15.6, 1e-9)
		vF, vA = SwimModel.allowedSpeed(1, 10, false)
		expect(vF).toBe(10)
		expect(vA).toBeCloseTo(11.7, 1e-9)
	end)

	it("covers a full strafe at full throttle with slideMult 1.17", function()
		local state = deep("minnow", 1)
		local input = newInput()
		input.throttle = 1
		input.strafe = 1
		run(state, input, 3)
		local _, vA =
			SwimModel.allowedSpeed(1, SwimModel.topSpeed(1, Index.Species.byId.minnow, 1), false)
		expect(SwimModel.speed(state) <= vA).toBe(true)
		expect(SwimModel.speed(state)).toBeCloseTo(26 * math.sqrt(1 + 0.36), 0.01)
	end)

	it(
		"opens the dash window 0.10 s before the start and closes it 0.25 s after the dash",
		function()
			local squid = Index.Species.byId.squid
			expect(SwimModel.dashFactor(3, squid, 0, -0.2)).toBe(1)
			expect(SwimModel.dashFactor(3, squid, 0, -0.1)).toBe(2.6)
			expect(SwimModel.dashFactor(3, squid, 0, 0.35 + 0.25)).toBe(2.6)
			local after = SwimModel.dashFactor(3, squid, 0, 0.35 + 0.25 + 0.1)
			expect(after).toBeCloseTo(SwimModel.dashTail(3, squid, 0.1), 1e-9)
			expect(after < 2.6 and after > 1).toBe(true)
			-- A Longfin keeps the window open 0.105 s longer.
			expect(SwimModel.dashFactor(3, squid, 1, 0.455 + 0.24)).toBe(2.6)
		end
	)

	it(
		"accepts a dash only after the cooldown, with 0.15 s slack and the claim held to ping",
		function()
			local minnow = Index.Species.byId.minnow -- cooldown 2.0
			expect(SwimModel.acceptDash(minnow, -math.huge, 10, 10, 0.1)).toBe(10)
			expect(SwimModel.acceptDash(minnow, 10, 11.9, 11.9, 0.1)).toBe(11.9)
			expect(SwimModel.acceptDash(minnow, 10, 11.8, 11.8, 0.1)).toBe(nil)
			-- A claim in the future is held to now; one older than the ping (cap 0.3 s) to now − ping.
			expect(SwimModel.acceptDash(minnow, -math.huge, 50, 20, 0.1)).toBe(20)
			expect(SwimModel.acceptDash(minnow, -math.huge, 0, 20, 0.1)).toBeCloseTo(19.9, 1e-9)
			expect(SwimModel.acceptDash(minnow, -math.huge, 0, 20, 5)).toBeCloseTo(19.7, 1e-9)
			expect(SwimModel.acceptDash(minnow, -math.huge, 0 / 0, 20, 0)).toBe(20)
			-- Backdating cannot dodge the cooldown: the claim is clamped before the check.
			expect(SwimModel.acceptDash(minnow, 10, 0, 11.9, 0.3)).toBe(nil)
			expect(SwimModel.acceptDash(Index.Species.byId.puffer, 10, 12.36, 12.36, 0)).toBe(12.36)
		end
	)

	it("matches the dash tail to the model's own slow-down after a dash", function()
		for _, case in
			{ { id = "squid", tier = 7 }, { id = "turtle", tier = 1 }, { id = "minnow", tier = 4 } }
		do
			local species = Index.Species.byId[case.id]
			local state = deep(case.id, case.tier)
			local input = newInput()
			input.throttle = 1
			input.dash = true
			SwimModel.step(state, input, DT)
			input.dash = false
			while state.dashing do
				SwimModel.step(state, input, DT)
			end
			-- From the dash end, forward speed relaxes to topSpeed at the tier's accel.
			local top = SwimModel.topSpeed(case.tier, species, 1)
			local factor0 = SwimModel.speed(state) / top
			local since = state.dashAge - state.dashLength
			local since0 = since
			for _ = 1, 30 do
				SwimModel.step(state, input, DT)
				since += DT
				local accel = SwimModel.accel(case.tier, species)
				local expected = 1 + (factor0 - 1) * math.exp(-accel * (since - since0))
				expect(SwimModel.speed(state) / top).toBeCloseTo(expected, 1e-3)
				expect(
					SwimModel.speed(state) / top
						<= SwimModel.dashTail(case.tier, species, since) + 1e-6
				).toBe(true)
			end
		end
		expect(SwimModel.dashTail(7, Index.Species.byId.minnow, 0)).toBeCloseTo(2.2, 1e-9)
		expect(SwimModel.dashTail(7, Index.Species.byId.minnow, math.log(12) / 4)).toBeCloseTo(
			1.1,
			1e-9
		)
	end)
end)

describe("SwimModel thrust, coast and brake", function()
	it("reaches 90% of top speed in the tier's time (02 §1.3)", function()
		for _, case in { { tier = 1, t = 0.26 }, { tier = 4, t = 0.33 }, { tier = 7, t = 0.58 } } do
			local state = deep("minnow", case.tier)
			local input = newInput()
			input.throttle = 1
			local top = SwimModel.tierSpeed(case.tier)
			local time = 0
			while SwimModel.speed(state) < 0.9 * top do
				SwimModel.step(state, input, 1 / 600)
				time += 1 / 600
			end
			expect(time).toBeCloseTo(case.t, 0.01)
		end
	end)

	it("coasts to a stop over the tier's coast distance and then holds its depth", function()
		for _, case in { { tier = 1, d = 10.0 }, { tier = 4, d = 14.5 }, { tier = 7, d = 23.8 } } do
			local state = deep("minnow", case.tier)
			local input = newInput()
			input.throttle = 1
			run(state, input, 4)
			input.throttle = 0
			local x, y, z = state.x, state.y, state.z
			run(state, input, 6)
			expect(SwimModel.speed(state)).toBe(0)
			-- The table rounds top / coast; the stop below 0.5 studs/s trims the tail.
			expect(horizontalDistance(state, x, z)).toBeCloseTo(case.d, 0.4)
			expect(state.y).toBe(y)
		end
	end)

	it("brakes harder than it coasts, and never reverses", function()
		local coasting, braking = deep("minnow", 1), deep("minnow", 1)
		local input = newInput()
		input.throttle = 1
		run(coasting, input, 3)
		run(braking, input, 3)
		input.throttle = 0
		run(coasting, input, 0.5)
		input.brake = true
		run(braking, input, 0.5)
		expect(SwimModel.speed(braking) < SwimModel.speed(coasting)).toBe(true)
		run(braking, input, 3)
		expect(SwimModel.speed(braking)).toBe(0)
		expect(braking.z < 0).toBe(true)
	end)

	it("strafes sideways at 0.6 × top speed", function()
		local state = deep("minnow", 1)
		local input = newInput()
		input.strafe = 1
		run(state, input, 2)
		expect(state.vx).toBeCloseTo(26 * 0.6, 0.01) -- right of a −Z facing is +X
		expect(state.vz).toBeCloseTo(0, 1e-9)
	end)

	it("adds a current of 0.6 × tierSpeed along the stream", function()
		local state = deep("minnow", 2)
		state.mods.currentX = 1
		run(state, newInput(), 1)
		expect(state.x).toBeCloseTo(0.6 * 28, 1e-6)
		local vx = SwimModel.velocity(state)
		expect(vx).toBeCloseTo(0.6 * 28, 1e-9)
	end)

	it("coasts without thrust while canThrust is off", function()
		local state = deep("minnow", 1)
		local input = newInput()
		input.throttle = 1
		state.mods.canThrust = false
		run(state, input, 1)
		expect(SwimModel.speed(state)).toBe(0)
	end)
end)

describe("SwimModel surface and breach", function()
	-- Full speed straight up at 70° from below, until back under water.
	local function breach(tier: number, dash: boolean, dt: number): (number, number, SwimState)
		local state = SwimModel.new("minnow", tier)
		SwimModel.place(state, 0, -60, 0, 0, 70)
		local input = newInput()
		input.throttle = 1
		input.pitchTarget = 70
		while true do
			-- Reach top speed before the surface; dash 0.3 s before it if asked.
			if
				dash
				and state.y > -0.3 * 57.2 * 0.94
				and not state.dashing
				and state.dashAge > 10
			then
				input.dash = true
			else
				input.dash = false
			end
			SwimModel.step(state, input, dt)
			if state.breached then
				break
			end
		end
		local peak, airTime = state.y, 0
		while state.airborne do
			SwimModel.step(state, input, dt)
			peak = math.max(peak, state.y)
			airTime = state.airTime
		end
		return peak, airTime, state
	end

	it("breaches on a ballistic arc with the reference heights and air times (02 §1.7)", function()
		for _, case in
			{
				{ tier = 1, h = 3.7, t = 0.61 },
				{ tier = 4, h = 5.7, t = 0.75 },
				{ tier = 7, h = 8.0, t = 0.89 },
			}
		do
			local peak, airTime = breach(case.tier, false, 1 / 240)
			expect(peak).toBeCloseTo(case.h, 0.06)
			expect(airTime).toBeCloseTo(case.t, 0.02)
		end
	end)

	it("dash breaches reach the dash reference heights", function()
		local peak, airTime = breach(1, true, 1 / 240)
		expect(peak).toBeCloseTo(18.1, 0.3)
		expect(airTime).toBeCloseTo(1.34, 0.03)
	end)

	it("re-enters at 0.8 × velocity, back to swimming, with a splash", function()
		local state = SwimModel.new("minnow", 1)
		SwimModel.place(state, 0, 0.001, 0, 0, 0)
		state.vy = 20
		state.vz = -10
		local input = newInput()
		local splashed = false
		local vzBefore = 0
		for _ = 1, 600 do
			vzBefore = state.vz
			SwimModel.step(state, input, DT)
			if state.splashed then
				splashed = true
				break
			end
		end
		expect(splashed).toBe(true)
		expect(state.airborne).toBe(false)
		expect(state.vz).toBeCloseTo(vzBefore * 0.8, 1e-9)
		expect(state.y < 0).toBe(true)
	end)

	it("in the air: no thrust, no dash, turn rate × 0.3", function()
		local state = SwimModel.new("minnow", 1)
		SwimModel.place(state, 0, 0.001, 0, 0, 0)
		state.vy = 30
		local input = newInput()
		input.throttle = 1
		input.dash = true
		input.yawRate = -10000
		run(state, input, 0.1)
		expect(state.airborne).toBe(true)
		expect(state.dashing).toBe(false)
		expect(state.vz).toBe(0)
		expect(state.yaw).toBeCloseTo(360 * 0.3 * 0.1, 1e-6)
	end)

	it("skims under an upward speed of 8: the back rides out of the water", function()
		local state = SwimModel.new("minnow", 1)
		SwimModel.place(state, 0, -5, 0, 0, 15) -- 26 × sin 15° ≈ 6.7 studs/s up
		local input = newInput()
		input.throttle = 1
		input.pitchTarget = 15
		local highest = -5
		for _ = 1, 60 * 4 do
			SwimModel.step(state, input, DT)
			expect(state.airborne).toBe(false)
			highest = math.max(highest, state.y)
		end
		expect(highest).toBeCloseTo(-0.5 * 0.9, 1e-6)
		expect(SwimModel.speed(state) > 20).toBe(true)
	end)
end)

describe("SwimModel determinism and frame rate", function()
	-- A scripted input as a pure function of time: cruise, turn, climb, dash, coast, breach.
	local function script(input: Types.SwimInput, t: number)
		input.throttle = if t < 5 then 1 else 0
		input.yawRate = if t > 1 and t < 2.5 then 200 else 0
		input.pitchTarget = if t > 3 and t < 4.5 then 35 else 0
		input.strafe = if t > 2 and t < 3 then -1 else 0
		input.dash = t >= 3.5 and t < 3.6
	end

	local function trace(dt: number, seconds: number): { number }
		local state = SwimModel.new("eel", 3)
		SwimModel.place(state, 10, -40, 20, 30, 0)
		local input = newInput()
		local samples = {}
		local steps = math.floor(seconds / dt + 0.5)
		local every = math.floor(0.5 / dt + 0.5)
		for i = 1, steps do
			-- Sample the script mid-frame: its switch times are multiples of 1/30 s, so both
			-- frame rates switch on the same frame boundary.
			script(input, (i - 0.5) * dt)
			SwimModel.step(state, input, dt)
			if i % every == 0 then
				table.insert(samples, state.x)
				table.insert(samples, state.y)
				table.insert(samples, state.z)
			end
		end
		return samples
	end

	it("gives the same trace for the same inputs", function()
		expect(trace(DT, 8)).toEqual(trace(DT, 8))
	end)

	it("30 fps and 60 fps traces agree within a quarter stud over 8 s", function()
		local slow, fast = trace(1 / 30, 8), trace(1 / 60, 8)
		expect(#slow).toBe(#fast)
		local worst = 0
		for i = 1, #slow do
			worst = math.max(worst, math.abs(slow[i] - fast[i]))
		end
		expect(worst < 0.25).toBe(true)
	end)
end)

describe("SwimModel robustness", function()
	it("stays still and finite on zero input", function()
		local state = deep("minnow", 1)
		run(state, newInput(), 10)
		expect(allFinite(state)).toBe(true)
		expect(state.x).toBe(0)
		expect(state.y).toBe(-200)
		expect(state.z).toBe(0)
	end)

	it("clamps a huge, zero, negative or NaN dt", function()
		local state = deep("minnow", 1)
		local input = newInput()
		input.throttle = 1
		for _, dt in { 1e9, math.huge, 0, -5, 0 / 0 } do
			SwimModel.step(state, input, dt)
			expect(allFinite(state)).toBe(true)
		end
		-- Two clamped steps of MAX_DT at most, starting from rest.
		expect(math.abs(state.z) <= 2 * SwimModel.MAX_DT * 26).toBe(true)
	end)

	it("survives NaN and infinite input fields", function()
		local state = deep("minnow", 1)
		local input = newInput()
		local nan = 0 / 0
		input.throttle = nan
		input.strafe = math.huge
		input.yawRate = nan
		input.yawTarget = nan
		input.pitchTarget = -math.huge
		run(state, input, 1)
		expect(allFinite(state)).toBe(true)
		expect(state.pitch).toBeCloseTo(-70, 0.01)
	end)

	it("allocates nothing per step", function()
		local state = deep("minnow", 1)
		local input = newInput()
		input.throttle = 1
		input.yawRate = 100
		input.dash = true
		SwimModel.step(state, input, DT)
		local before = gcinfo()
		for _ = 1, 20000 do
			SwimModel.step(state, input, DT)
		end
		expect(gcinfo() - before <= 1).toBe(true)
	end)
end)
