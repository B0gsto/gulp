--!strict
--!native
--!optimize 2
-- Quantize: the wire quantisation of docs/09, section 8.7, shared by the prey and predator codecs,
-- the prey history ring (8.2) and the client's dead reckoning:
--   qx = round((x + 1024) × 16)          u16  1/16 stud, x in [−1024, 1024]
--   qy = round((y +  640) × 16)          u16  y in [−640, 96]
--   qz = round((z + 1024) × 16)          u16  z in [−1024, 1024]
--   qv = clamp(round(v × 2), −127, 127)  i8   0.5 studs/s, ±63.5 studs/s
--   scatter: 0 to 255 for 0 to 1         u8   (8.7, full record)
--   timeMs = floor((serverNow − ServerEpoch) × 1000)  u32
-- A position outside its range is clamped to the range's edge; NaN reads as the low edge. Inside
-- the range the round trip is off by at most 1/32 stud (section 16.1). Pure and allocation-free.
local Quantize = {}

Quantize.X_MIN, Quantize.X_MAX = -1024, 1024
Quantize.Y_MIN, Quantize.Y_MAX = -640, 96
Quantize.Z_MIN, Quantize.Z_MAX = -1024, 1024
Quantize.STEPS_PER_STUD = 16
--- The largest qx, qy and qz a clamped position gives.
Quantize.QX_MAX = (1024 + 1024) * 16 -- 32768
Quantize.QY_MAX = (96 + 640) * 16 -- 11776
Quantize.QZ_MAX = (1024 + 1024) * 16 -- 32768
--- The largest |qv|; −128 is never written.
Quantize.QV_MAX = 127
Quantize.U32_MAX = 4294967295

local function position(value: number, low: number, high: number): number
	-- `not (value >= low)` also catches NaN.
	if not (value >= low) then
		value = low
	elseif value > high then
		value = high
	end
	return math.round((value - low) * 16)
end

--- qx of a world X.
function Quantize.x(x: number): number
	return position(x, -1024, 1024)
end

--- qy of a world Y.
function Quantize.y(y: number): number
	return position(y, -640, 96)
end

--- qz of a world Z.
function Quantize.z(z: number): number
	return position(z, -1024, 1024)
end

--- World X of a qx.
function Quantize.fromX(qx: number): number
	return qx / 16 - 1024
end

--- World Y of a qy.
function Quantize.fromY(qy: number): number
	return qy / 16 - 640
end

--- World Z of a qz.
function Quantize.fromZ(qz: number): number
	return qz / 16 - 1024
end

--- qv of a velocity component, studs/s: −127 to 127. NaN reads as 0.
function Quantize.vel(v: number): number
	local q = math.round(v * 2)
	if q > 127 then
		return 127
	elseif q < -127 then
		return -127
	elseif q ~= q then
		return 0
	end
	return q
end

--- Velocity component, studs/s, of a qv.
function Quantize.fromVel(qv: number): number
	return qv / 2
end

--- The u8 of a scatter value 0 to 1 (clamped; NaN reads as 0).
function Quantize.scatter(s: number): number
	if not (s >= 0) then
		return 0
	elseif s > 1 then
		return 255
	end
	return math.round(s * 255)
end

--- Scatter 0 to 1 of its u8.
function Quantize.fromScatter(q: number): number
	return q / 255
end

--- `timeMs` of a server time: whole milliseconds since `epoch` (both seconds on the
--- `GetServerTimeNow` clock), clamped to a u32. A time before the epoch, or NaN, reads as 0.
function Quantize.timeMs(serverTime: number, epoch: number): number
	local t = math.floor((serverTime - epoch) * 1000)
	if not (t >= 0) then
		return 0
	elseif t > 4294967295 then
		return 4294967295
	end
	return t
end

--- Server time, seconds on the `GetServerTimeNow` clock, of a `timeMs`.
function Quantize.fromTimeMs(timeMs: number, epoch: number): number
	return epoch + timeMs / 1000
end

return Quantize
