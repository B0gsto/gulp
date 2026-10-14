--!strict
-- Spike swim model: numbers only, no Instances, no Vector3 (09 section 4.4), so it also runs in Lune.
local Tiers = require("../Data/Tiers")
local TierMath = require("./TierMath")

export type SwimState = { vx: number, vy: number, vz: number, hx: number, hy: number, hz: number }
export type SwimInput = { x: number, y: number, z: number, throttle: number }

local ACCEL = 8 -- 1/s (tune)

local SwimModel = {}

function SwimModel.new(): SwimState
	return { vx = 0, vy = 0, vz = 0, hx = 0, hy = 0, hz = -1 }
end

function SwimModel.speedForMass(mass: number): number
	return Tiers[TierMath.tier(mass)].swimSpeed
end

function SwimModel.step(s: SwimState, input: SwimInput, tier: number, dt: number): SwimState
	local row = Tiers[tier]
	if input.throttle > 0 then
		local dot = math.clamp(s.hx * input.x + s.hy * input.y + s.hz * input.z, -1, 1)
		local angle = math.acos(dot)
		local maxStep = math.rad(row.turnRate) * dt
		if angle <= maxStep or angle < 1e-4 then
			s.hx, s.hy, s.hz = input.x, input.y, input.z
		else
			local tx, ty, tz = input.x, input.y, input.z
			if angle > math.pi - 1e-3 then -- opposite: turn through a sideways vector first
				tx, ty, tz = -s.hz, 0, s.hx
				if tx * tx + tz * tz < 1e-6 then
					tx, ty, tz = 1, 0, 0
				end
				local m = math.sqrt(tx * tx + ty * ty + tz * tz)
				tx, ty, tz = tx / m, ty / m, tz / m
				angle = math.pi / 2
			end
			local f = math.min(1, maxStep / angle)
			local sinA = math.sin(angle)
			local a, b = math.sin((1 - f) * angle) / sinA, math.sin(f * angle) / sinA
			local x, y, z = s.hx * a + tx * b, s.hy * a + ty * b, s.hz * a + tz * b
			local m = math.sqrt(x * x + y * y + z * z)
			s.hx, s.hy, s.hz = x / m, y / m, z / m
		end
	end
	local speed = row.swimSpeed * input.throttle
	local k = 1 - math.exp(-ACCEL * dt)
	s.vx += (s.hx * speed - s.vx) * k
	s.vy += (s.hy * speed - s.vy) * k
	s.vz += (s.hz * speed - s.vz) * k
	return s
end

return SwimModel
