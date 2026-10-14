--!nonstrict
--!native
-- GULP Sprint 0 spike, part B (throwaway). Server half of S6 (prey pipeline stand-in), S7 (900-byte buffers over
-- UnreliableRemoteEvent) and S4 under latency. Inert until the driver sets ReplicatedStorage.SpikeBResults.cmd.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")

local results = Instance.new("Folder")
results.Name = "SpikeBResults"
results.Parent = RS
local preyEv = Instance.new("UnreliableRemoteEvent")
preyEv.Name = "PreyState"
preyEv.Parent = RS
local s7Ev = Instance.new("UnreliableRemoteEvent")
s7Ev.Name = "S7Probe"
s7Ev.Parent = RS
local ctl = Instance.new("RemoteEvent")
ctl.Name = "SpikeBEvent"
ctl.Parent = RS

local function report(key: string, value: any)
	local __v = HttpService:JSONEncode(value) if not pcall(function() results:SetAttribute(key, __v) end) then local __sv = results:FindFirstChild(key) or Instance.new("StringValue") __sv.Name = key __sv.Value = tostring(__v) __sv.Parent = results end -- S12 place: attribute strings are capped at 50 chars
	print("[SPIKEB] " .. key)
end

local function pct(t: { number }, p: number): number
	if #t == 0 then
		return 0
	end
	local c = table.clone(t)
	table.sort(c)
	return c[math.clamp(math.ceil(#c * p), 1, #c)]
end
local function r3(x: number): number
	return math.round(x * 1000) / 1000
end

ctl.OnServerEvent:Connect(function(player, kind, a)
	if kind == "ping" then
		ctl:FireClient(player, "pong", a)
	elseif kind == "report" then
		report("C_" .. player.Name .. "_" .. tostring(a.key), a.value)
	end
end)

----------------------------------------------------------------------------------------------------------------
-- S7: deterministic payloads, checked byte by byte on the client
----------------------------------------------------------------------------------------------------------------
local function payload(seq: number, phase: number, size: number): buffer
	local b = buffer.create(size)
	buffer.writeu32(b, 0, seq)
	buffer.writeu16(b, 4, phase)
	buffer.writeu16(b, 6, size)
	local x = (seq * 2654435761 + phase) % 4294967296
	for i = 8, size - 1 do
		x = (x * 1664525 + 1013904223) % 4294967296
		buffer.writeu8(b, i, bit32.rshift(x, 24))
	end
	return b
end

local function s7(player: Player, sweep: boolean?)
	local phases = { { 1, 400, 20, 900 }, { 2, 300, 60, 900 }, { 3, 50, 10, 1000 }, { 4, 50, 10, 1200 }, { 5, 20, 10, 8000 } }
	if sweep then
		phases = { { 11, 10, 10, 950 }, { 12, 10, 10, 970 }, { 13, 10, 10, 980 }, { 14, 10, 10, 985 }, { 15, 10, 10, 990 }, { 16, 10, 10, 995 }, { 17, 10, 10, 999 } }
	end
	local out = {}
	for _, ph in phases do
		local id, n, rate, size = ph[1], ph[2], ph[3], ph[4]
		ctl:FireClient(player, "s7phase", id, n, size)
		task.wait(1.0)
		local kbps = {}
		local sent, acc, t0 = 0, 0, os.clock()
		local conn
		local done = Instance.new("BindableEvent")
		conn = RunService.Heartbeat:Connect(function(dt)
			acc += dt
			while acc >= 1 / rate and sent < n do
				acc -= 1 / rate
				sent += 1
				s7Ev:FireClient(player, payload(sent, id, size))
			end
			if sent >= n then
				conn:Disconnect()
				done:Fire()
			end
		end)
		local sampler = task.spawn(function()
			while true do
				task.wait(0.5)
				table.insert(kbps, Stats.DataSendKbps)
			end
		end)
		done.Event:Wait()
		task.wait(1.5)
		task.cancel(sampler)
		table.insert(out, { phase = id, sent = n, rateHz = rate, size = size, seconds = r3(os.clock() - t0), serverDataSendKbps = kbps })
	end
	ctl:FireClient(player, "s7end")
	report(if sweep then "S7sweep_server" else "S7_server", out)
end

----------------------------------------------------------------------------------------------------------------
-- S6: prey groups (09 sections 8.1 to 8.7, minimal stand-in)
----------------------------------------------------------------------------------------------------------------
local MAXG, NB, CELL, GRID, HALF = 384, 24, 64, 32, 1024
local NONE = 0xFFFF
-- kind: groups, min, max, cruise, flee speed, flee radius, accel, prey tier, swarm
local KINDS = {
	{ 80, 6, 10, 2, 8, 20, 10, 1, true }, -- plankton
	{ 15, 12, 20, 5, 16, 25, 20, 1, true }, -- krill
	{ 50, 1, 3, 6, 18, 25, 30, 1, false }, -- shrimp
	{ 14, 8, 14, 9, 24, 35, 30, 2, true }, -- sardine
	{ 30, 1, 2, 10, 28, 30, 40, 2, false }, -- darter
	{ 16, 1, 3, 12, 30, 40, 40, 3, false }, -- mackerel
	{ 6, 3, 5, 14, 32, 45, 40, 4, true }, -- bonito
	{ 3, 1, 1, 14, 30, 50, 30, 5, false }, -- tuna
	{ 40, 1, 5, 4, 12, 25, 20, 2, false }, -- trait prey
}

local B = {
	kind = buffer.create(MAXG), gen = buffer.create(MAXG), flags = buffer.create(MAXG), count = buffer.create(MAXG),
	alive = buffer.create(MAXG * 4), seed = buffer.create(MAXG * 2),
	px = buffer.create(MAXG * 4), py = buffer.create(MAXG * 4), pz = buffer.create(MAXG * 4),
	vx = buffer.create(MAXG * 4), vy = buffer.create(MAXG * 4), vz = buffer.create(MAXG * 4),
	scatter = buffer.create(MAXG * 4), scatterT = buffer.create(MAXG * 4), stateUntil = buffer.create(MAXG * 4),
	fx = buffer.create(MAXG * 4), fz = buffer.create(MAXG * 4),
	wx = buffer.create(MAXG * 4), wy = buffer.create(MAXG * 4), wz = buffer.create(MAXG * 4), wUntil = buffer.create(MAXG * 4),
	hx = buffer.create(MAXG * 4), hy = buffer.create(MAXG * 4), hz = buffer.create(MAXG * 4), hr = buffer.create(MAXG * 4),
	cell = buffer.create(MAXG * 2), nextC = buffer.create(MAXG * 2), prevC = buffer.create(MAXG * 2),
	hist = buffer.create(MAXG * 64), histHead = buffer.create(MAXG),
	cellHead = buffer.create(GRID * GRID * 2),
}
-- per bot (slot) and group: what this client was told
local P = {
	known = buffer.create(NB * MAXG), again = buffer.create(NB * MAXG),
	sx = buffer.create(NB * MAXG * 4), sy = buffer.create(NB * MAXG * 4), sz = buffer.create(NB * MAXG * 4),
	svx = buffer.create(NB * MAXG * 4), svy = buffer.create(NB * MAXG * 4), svz = buffer.create(NB * MAXG * 4),
	st = buffer.create(NB * MAXG * 4), kt = buffer.create(NB * MAXG * 4), sflags = buffer.create(NB * MAXG), ssc = buffer.create(NB * MAXG),
}
local NG = 0
local rng = Random.new(1)
local bots = {} -- { x, y, z, tx, ty, tz, tier }
local area = 1000 -- half-extent of the scenario area

local function cellOf(x: number, z: number): number
	local cx = math.clamp(math.floor((x + HALF) / CELL), 0, GRID - 1)
	local cz = math.clamp(math.floor((z + HALF) / CELL), 0, GRID - 1)
	return cz * GRID + cx
end
local function unlink(g: number)
	local c = buffer.readu16(B.cell, g * 2)
	if c == NONE then
		return
	end
	local n, p = buffer.readu16(B.nextC, g * 2), buffer.readu16(B.prevC, g * 2)
	if p ~= NONE then
		buffer.writeu16(B.nextC, p * 2, n)
	else
		buffer.writeu16(B.cellHead, c * 2, n)
	end
	if n ~= NONE then
		buffer.writeu16(B.prevC, n * 2, p)
	end
	buffer.writeu16(B.cell, g * 2, NONE)
end
local function link(g: number, c: number)
	local h = buffer.readu16(B.cellHead, c * 2)
	buffer.writeu16(B.nextC, g * 2, h)
	buffer.writeu16(B.prevC, g * 2, NONE)
	if h ~= NONE then
		buffer.writeu16(B.prevC, h * 2, g)
	end
	buffer.writeu16(B.cellHead, c * 2, g)
	buffer.writeu16(B.cell, g * 2, c)
end

local function populate(scenario: string)
	area = if scenario == "crowded" then 350 else 1000
	rng = Random.new(42)
	buffer.fill(B.cellHead, 0, 0xFF)
	buffer.fill(B.cell, 0, 0xFF)
	buffer.fill(P.known, 0, 0)
	buffer.fill(P.again, 0, 0)
	NG = 0
	local members = 0
	for k, def in KINDS do
		for _ = 1, def[1] do
			local g = NG
			NG += 1
			local hx, hz = rng:NextNumber(-area, area), rng:NextNumber(-area, area)
			local hy, hr = rng:NextNumber(-500, -40), rng:NextNumber(40, 120)
			local cnt = rng:NextInteger(def[2], def[3])
			members += cnt
			buffer.writeu8(B.kind, g, k)
			buffer.writeu8(B.gen, g, 1)
			buffer.writeu8(B.flags, g, 0)
			buffer.writeu8(B.count, g, cnt)
			buffer.writeu32(B.alive, g * 4, if cnt >= 32 then 0xFFFFFFFF else 2 ^ cnt - 1)
			buffer.writeu16(B.seed, g * 2, rng:NextInteger(0, 65535))
			buffer.writef32(B.hx, g * 4, hx)
			buffer.writef32(B.hy, g * 4, hy)
			buffer.writef32(B.hz, g * 4, hz)
			buffer.writef32(B.hr, g * 4, hr)
			buffer.writef32(B.px, g * 4, hx)
			buffer.writef32(B.py, g * 4, hy)
			buffer.writef32(B.pz, g * 4, hz)
			buffer.writef32(B.wUntil, g * 4, 0)
			link(g, cellOf(hx, hz))
		end
	end
	bots = {}
	for b = 1, NB do
		bots[b] = { rng:NextNumber(-area, area), rng:NextNumber(-300, -40), rng:NextNumber(-area, area), 0, 0, 0, rng:NextInteger(1, 7) }
	end
	return members
end

local now = 0
local function simulate(dt: number, dormantTick: boolean)
	-- 1 threat pass, player-centric: 3 x 3 cells around each bot
	for b = 1, NB do
		local bot = bots[b]
		local bx, by, bz, tier = bot[1], bot[2], bot[3], bot[7]
		local c0 = cellOf(bx, bz)
		local cx0, cz0 = c0 % GRID, c0 // GRID
		for cz = math.max(cz0 - 1, 0), math.min(cz0 + 1, GRID - 1) do
			for cx = math.max(cx0 - 1, 0), math.min(cx0 + 1, GRID - 1) do
				local g = buffer.readu16(B.cellHead, (cz * GRID + cx) * 2)
				while g ~= NONE do
					local def = KINDS[buffer.readu8(B.kind, g)]
					if def[8] <= tier then
						local dx, dy, dz = buffer.readf32(B.px, g * 4) - bx, buffer.readf32(B.py, g * 4) - by, buffer.readf32(B.pz, g * 4) - bz
						local d2 = dx * dx + dy * dy + dz * dz
						if d2 < def[6] * def[6] and d2 > 1e-6 then
							local m = math.sqrt(dx * dx + dz * dz) + 1e-3
							buffer.writef32(B.fx, g * 4, dx / m)
							buffer.writef32(B.fz, g * 4, dz / m)
							buffer.writef32(B.stateUntil, g * 4, now + 1.2)
							buffer.writeu8(B.flags, g, bit32.bor(buffer.readu8(B.flags, g), 1))
							if def[9] then
								buffer.writef32(B.scatterT, g * 4, 1)
							end
						end
					end
					g = buffer.readu16(B.nextC, g * 2)
				end
			end
		end
	end
	-- 2 to 5: steer, integrate, leash, history
	local active = 0
	for g = 0, NG - 1 do
		local x, y, z = buffer.readf32(B.px, g * 4), buffer.readf32(B.py, g * 4), buffer.readf32(B.pz, g * 4)
		local isActive = false
		for b = 1, NB do
			local bot = bots[b]
			local dx, dz = bot[1] - x, bot[3] - z
			if dx * dx + dz * dz < 490000 then
				isActive = true
				break
			end
		end
		local step = dt
		if not isActive then
			if not dormantTick then
				continue
			end
			step = 1
		else
			active += 1
		end
		local def = KINDS[buffer.readu8(B.kind, g)]
		local flags = buffer.readu8(B.flags, g)
		local dvx, dvy, dvz
		if bit32.band(flags, 1) ~= 0 and now < buffer.readf32(B.stateUntil, g * 4) then
			dvx, dvy, dvz = buffer.readf32(B.fx, g * 4) * def[5], 0, buffer.readf32(B.fz, g * 4) * def[5]
		else
			if bit32.band(flags, 1) ~= 0 then
				buffer.writeu8(B.flags, g, bit32.band(flags, 0xFE))
				buffer.writef32(B.scatterT, g * 4, 0)
			end
			if now >= buffer.readf32(B.wUntil, g * 4) then
				local r = buffer.readf32(B.hr, g * 4)
				buffer.writef32(B.wx, g * 4, buffer.readf32(B.hx, g * 4) + rng:NextNumber(-r, r))
				buffer.writef32(B.wy, g * 4, buffer.readf32(B.hy, g * 4) + rng:NextNumber(-r, r) * 0.3)
				buffer.writef32(B.wz, g * 4, buffer.readf32(B.hz, g * 4) + rng:NextNumber(-r, r))
				buffer.writef32(B.wUntil, g * 4, now + rng:NextNumber(3, 6))
			end
			local tx, ty, tz = buffer.readf32(B.wx, g * 4) - x, buffer.readf32(B.wy, g * 4) - y, buffer.readf32(B.wz, g * 4) - z
			local m = math.sqrt(tx * tx + ty * ty + tz * tz)
			if m > 1 then
				dvx, dvy, dvz = tx / m * def[4], ty / m * def[4], tz / m * def[4]
			else
				dvx, dvy, dvz = 0, 0, 0
			end
		end
		local vx, vy, vz = buffer.readf32(B.vx, g * 4), buffer.readf32(B.vy, g * 4), buffer.readf32(B.vz, g * 4)
		local ax, ay, az = dvx - vx, dvy - vy, dvz - vz
		local am = math.sqrt(ax * ax + ay * ay + az * az)
		local lim = def[7] * step
		if am > lim then
			ax, ay, az = ax / am * lim, ay / am * lim, az / am * lim
		end
		vx, vy, vz = vx + ax, vy + ay, vz + az
		x, y, z = x + vx * step, y + vy * step, z + vz * step
		-- leash
		local hx, hy, hz, hr = buffer.readf32(B.hx, g * 4), buffer.readf32(B.hy, g * 4), buffer.readf32(B.hz, g * 4), buffer.readf32(B.hr, g * 4)
		local ox, oy, oz = x - hx, y - hy, z - hz
		local od = math.sqrt(ox * ox + oy * oy + oz * oz)
		if od > hr * 1.5 then
			local k = hr * 1.5 / od
			x, y, z = hx + ox * k, hy + oy * k, hz + oz * k
		elseif od > hr then
			vx, vy, vz = vx - ox / od * 4 * step, vy - oy / od * 4 * step, vz - oz / od * 4 * step
		end
		x, z = math.clamp(x, -1023, 1023), math.clamp(z, -1023, 1023)
		y = math.clamp(y, -639, 95)
		local sc, st = buffer.readf32(B.scatter, g * 4), buffer.readf32(B.scatterT, g * 4)
		sc = if st > sc then math.min(st, sc + 2 * step) else math.max(st, sc - 0.5 * step)
		buffer.writef32(B.scatter, g * 4, sc)
		buffer.writef32(B.px, g * 4, x)
		buffer.writef32(B.py, g * 4, y)
		buffer.writef32(B.pz, g * 4, z)
		buffer.writef32(B.vx, g * 4, vx)
		buffer.writef32(B.vy, g * 4, vy)
		buffer.writef32(B.vz, g * 4, vz)
		local c = cellOf(x, z)
		if c ~= buffer.readu16(B.cell, g * 2) then
			unlink(g)
			link(g, c)
		end
		local hh = (buffer.readu8(B.histHead, g) + 1) % 8
		buffer.writeu8(B.histHead, g, hh)
		local o = g * 64 + hh * 8
		buffer.writeu16(B.hist, o, math.round((x + 1024) * 16))
		buffer.writeu16(B.hist, o + 2, math.round((y + 640) * 16))
		buffer.writeu16(B.hist, o + 4, math.round((z + 1024) * 16))
		buffer.writeu8(B.hist, o + 6, math.round(sc * 255))
	end
	return active
end

-- interest and send for one bot (09 sections 8.5 to 8.7)
local THR = { 1.0, 3.0, 8.0 }
local cand, key = table.create(MAXG), table.create(MAXG)
local scratch = buffer.create(900)
local seqs = table.create(NB, 0)
local function qv(v: number): number
	return math.clamp(math.round(v * 2), -127, 127)
end
local function interest(b: number, nowMs: number): (number, number, number, number)
	local bot = bots[b]
	local bx, by, bz = bot[1], bot[2], bot[3]
	local base = (b - 1) * MAXG
	local nc = 0
	local near = 0
	local c0 = cellOf(bx, bz)
	local cx0, cz0 = c0 % GRID, c0 // GRID
	for cz = math.max(cz0 - 10, 0), math.min(cz0 + 10, GRID - 1) do
		for cx = math.max(cx0 - 10, 0), math.min(cx0 + 10, GRID - 1) do
			local g = buffer.readu16(B.cellHead, (cz * GRID + cx) * 2)
			while g ~= NONE do
				local x, y, z = buffer.readf32(B.px, g * 4), buffer.readf32(B.py, g * 4), buffer.readf32(B.pz, g * 4)
				local dx, dy, dz = x - bx, y - by, z - bz
				local d = math.sqrt(dx * dx + dy * dy + dz * dz)
				if d <= 600 then
					local band = if d <= 150 then 1 elseif d <= 350 then 2 else 3
					if band == 1 then
						near += 1
					end
					local i = base + g
					local gen1 = buffer.readu8(B.gen, g) + 1
					local st = buffer.readf32(P.st, i * 4)
					local k = 0
					if buffer.readu8(P.known, i) ~= gen1 or now - st > 3 then
						buffer.writeu8(P.known, i, 0)
						k = 3 + (4 - band) * 10 -- new: full, highest within its band
					elseif buffer.readu8(P.again, i) ~= 0 or now - buffer.readf32(P.kt, i * 4) >= 2 then
						k = 2 + (4 - band) * 10 -- full again or keyframe
					else
						local el = now - st
						local ex = buffer.readf32(P.sx, i * 4) + buffer.readf32(P.svx, i * 4) * el - x
						local ey = buffer.readf32(P.sy, i * 4) + buffer.readf32(P.svy, i * 4) * el - y
						local ez = buffer.readf32(P.sz, i * 4) + buffer.readf32(P.svz, i * 4) * el - z
						local err = math.sqrt(ex * ex + ey * ey + ez * ez) / THR[band]
						local changed = band == 1 and (buffer.readu8(P.sflags, i) ~= buffer.readu8(B.flags, g)
							or buffer.readu8(P.ssc, i) ~= math.round(buffer.readf32(B.scatter, g * 4) * 255))
						if err > 1 or changed then
							k = math.min(err, 9) / 10 + (4 - band) * 10
						end
					end
					if k > 0 then
						nc += 1
						cand[nc] = g
						key[g] = k
					end
				end
				g = buffer.readu16(B.nextC, g * 2)
			end
		end
	end
	for j = nc + 1, #cand do
		cand[j] = nil
	end
	table.sort(cand, function(a, c)
		return key[a] > key[c]
	end)
	-- pick records in priority order until 900 bytes; fulls first in the packet
	local size, F, D = 8, 0, 0
	local isFull = {}
	local picked = {}
	for j = 1, nc do
		local g = cand[j]
		local full = key[g] % 10 >= 2
		local add = if full then 22 else 13
		if size + add > 900 then
			break
		end
		size += add
		table.insert(picked, g)
		isFull[g] = full
		if full then
			F += 1
		else
			D += 1
		end
	end
	if F + D == 0 then
		return 0, 0, 0, near
	end
	seqs[b] = (seqs[b] + 1) % 65536
	buffer.writeu16(scratch, 0, seqs[b])
	buffer.writeu32(scratch, 2, nowMs)
	buffer.writeu8(scratch, 6, F)
	buffer.writeu8(scratch, 7, D)
	local of, od = 8, 8 + 22 * F
	for _, g in picked do
		local i = base + g
		local x, y, z = buffer.readf32(B.px, g * 4), buffer.readf32(B.py, g * 4), buffer.readf32(B.pz, g * 4)
		local qvx, qvy, qvz = qv(buffer.readf32(B.vx, g * 4)), qv(buffer.readf32(B.vy, g * 4)), qv(buffer.readf32(B.vz, g * 4))
		local sc = math.round(buffer.readf32(B.scatter, g * 4) * 255)
		local o = if isFull[g] then of else od
		buffer.writeu16(scratch, o, g)
		local p = o + 2
		if isFull[g] then
			buffer.writeu8(scratch, o + 2, buffer.readu8(B.gen, g))
			buffer.writeu8(scratch, o + 3, buffer.readu8(B.kind, g))
			p = o + 4
		end
		buffer.writeu16(scratch, p, math.round((x + 1024) * 16))
		buffer.writeu16(scratch, p + 2, math.round((y + 640) * 16))
		buffer.writeu16(scratch, p + 4, math.round((z + 1024) * 16))
		buffer.writei8(scratch, p + 6, qvx)
		buffer.writei8(scratch, p + 7, qvy)
		buffer.writei8(scratch, p + 8, qvz)
		buffer.writeu8(scratch, p + 9, sc)
		buffer.writeu8(scratch, p + 10, buffer.readu8(B.flags, g))
		if isFull[g] then
			buffer.writeu8(scratch, o + 15, buffer.readu8(B.count, g))
			buffer.writeu32(scratch, o + 16, buffer.readu32(B.alive, g * 4))
			buffer.writeu16(scratch, o + 20, buffer.readu16(B.seed, g * 2))
			of += 22
			buffer.writef32(P.kt, i * 4, now)
			local wasNew = buffer.readu8(P.known, i) == 0
			buffer.writeu8(P.again, i, if wasNew then 1 else 0)
		else
			od += 13
		end
		buffer.writeu8(P.known, i, buffer.readu8(B.gen, g) + 1)
		buffer.writef32(P.sx, i * 4, x)
		buffer.writef32(P.sy, i * 4, y)
		buffer.writef32(P.sz, i * 4, z)
		buffer.writef32(P.svx, i * 4, qvx / 2)
		buffer.writef32(P.svy, i * 4, qvy / 2)
		buffer.writef32(P.svz, i * 4, qvz / 2)
		buffer.writef32(P.st, i * 4, now)
		buffer.writeu8(P.sflags, i, buffer.readu8(B.flags, g))
		buffer.writeu8(P.ssc, i, sc)
	end
	return size, F, D, near
end

local function moveBots(dt: number, real: BasePart?)
	for b = 1, NB do
		local bot = bots[b]
		if b == 1 and real then
			local p = real.Position
			bot[1], bot[2], bot[3] = p.X, p.Y, p.Z
			continue
		end
		local dx, dy, dz = bot[4] - bot[1], bot[5] - bot[2], bot[6] - bot[3]
		local m = math.sqrt(dx * dx + dy * dy + dz * dz)
		if m < 5 then
			bot[4], bot[5], bot[6] = rng:NextNumber(-area, area), rng:NextNumber(-400, -40), rng:NextNumber(-area, area)
		else
			local s = 30 * dt / m
			bot[1], bot[2], bot[3] = bot[1] + dx * s, bot[2] + dy * s, bot[3] + dz * s
		end
	end
end

local function s6(player: Player?, scenario: string, seconds: number)
	local members = populate(scenario)
	local real: BasePart? = nil
	if player and player.Character then
		real = player.Character:FindFirstChild("Root") :: BasePart
	end
	local frame, tickCost, simMs, intMs, tickMs, frameMax = 0, 0, {}, {}, {}, 0
	local bytes = table.create(NB, 0)
	local packets = table.create(NB, 0)
	local fulls, deltas, nears, actives = 0, 0, {}, {}
	local realBytes, realPackets = 0, 0
	local t0 = os.clock()
	local warm = 20 -- ticks before measuring (initial full records)
	local ticks = 0
	local epoch = workspace:GetServerTimeNow()
	local done = Instance.new("BindableEvent")
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		local c0 = os.clock()
		moveBots(dt, real)
		local slot = frame % 6
		if slot == 0 then
			ticks += 1
			now = workspace:GetServerTimeNow() - epoch
			local a = simulate(0.1, ticks % 10 == 0)
			local c1 = os.clock()
			if ticks > warm then
				table.insert(simMs, (c1 - c0) * 1000)
				table.insert(actives, a)
			end
		end
		local ci = os.clock()
		local nowMs = math.floor(now * 1000)
		for b = slot + 1, NB, 6 do
			local size, F, D, near = interest(b, nowMs)
			if ticks > warm then
				if size > 0 then
					bytes[b] += size
					packets[b] += 1
					fulls += F
					deltas += D
				end
				table.insert(nears, near)
			end
			if b == 1 and size > 0 and player then
				local out = buffer.create(size)
				buffer.copy(out, 0, scratch, 0, size)
				preyEv:FireClient(player, out)
				if ticks > warm then
					realBytes += size
					realPackets += 1
				end
			end
		end
		local c2 = os.clock()
		if ticks > warm then
			tickCost += (c2 - c0) * 1000
			frameMax = math.max(frameMax, (c2 - c0) * 1000)
			if slot ~= 0 then
				table.insert(intMs, (c2 - ci) * 1000)
			end
			if slot == 5 then
				table.insert(tickMs, tickCost)
				tickCost = 0
			end
		end
		frame += 1
		if os.clock() - t0 > seconds + warm / 10 then
			conn:Disconnect()
			done:Fire()
		end
	end)
	done.Event:Wait()
	local dur = #tickMs / 10
	local perBot = {}
	local sum = 0
	for b = 1, NB do
		perBot[b] = bytes[b] / dur
		sum += perBot[b]
	end
	local sortedPB = table.clone(perBot)
	table.sort(sortedPB)
	report("S6_" .. scenario, {
		groups = NG, members = members, areaHalf = area, measuredTicks = #tickMs, seconds = r3(dur),
		native = true,
		tickMs = { p50 = r3(pct(tickMs, 0.5)), p99 = r3(pct(tickMs, 0.99)), max = r3(pct(tickMs, 1)) },
		simMs = { p50 = r3(pct(simMs, 0.5)), p99 = r3(pct(simMs, 0.99)), max = r3(pct(simMs, 1)) },
		interestFrameMs = { p50 = r3(pct(intMs, 0.5)), p99 = r3(pct(intMs, 0.99)) },
		worstFrameMs = r3(frameMax),
		bytesPerBotPerSec = { mean = math.round(sum / NB), min = math.round(sortedPB[1]), p50 = math.round(sortedPB[12]), max = math.round(sortedPB[NB]) },
		packetsPerBotPerSec = r3((function() local s = 0 for b = 1, NB do s += packets[b] end return s / NB / dur end)()),
		recordsPerSec = { full = math.round(fulls / dur), delta = math.round(deltas / dur) },
		nearGroupsPerBot = { p50 = pct(nears, 0.5), max = pct(nears, 1) },
		activeGroups = { p50 = pct(actives, 0.5) },
		realPlayer = { bytes = realBytes, packets = realPackets, bytesPerSec = math.round(realBytes / dur), slot1PerSec = math.round(perBot[1]) },
	})
end

----------------------------------------------------------------------------------------------------------------
-- S4 under latency (two-client test): correction and freeze on Player1's client-owned root
----------------------------------------------------------------------------------------------------------------
local function s4lag(tag: string)
	local p = Players:GetPlayers()[1]
	for _, q in Players:GetPlayers() do
		if q.Name == "Player1" then
			p = q
		end
	end
	local root = p.Character and p.Character:FindFirstChild("Root") :: BasePart
	local writes = {}
	for i = 1, 6 do
		local target = Vector3.new(-120 + 40 * i, -50 + (i % 2) * 10, -150)
		local t = workspace:GetServerTimeNow()
		root.CFrame = CFrame.new(target)
		ctl:FireClient(p, "s4target", i, target, t)
		table.insert(writes, { i = i, t = t })
		task.wait(1.5)
	end
	-- freeze while the client keeps pushing
	root:SetNetworkOwner(nil)
	root.Anchored = true
	local p0 = root.Position
	local maxDrift = 0
	local t0 = os.clock()
	while os.clock() - t0 < 2 do
		RunService.Heartbeat:Wait()
		maxDrift = math.max(maxDrift, (root.Position - p0).Magnitude)
	end
	root.Anchored = false
	root:SetNetworkOwner(p)
	report("S4lag_server_" .. tag, { writes = #writes, freezeDriftStuds = r3(maxDrift) })
end

----------------------------------------------------------------------------------------------------------------
-- S12: Server Authority probe (only meaningful in the s12 build, where the project file sets AuthorityMode)
----------------------------------------------------------------------------------------------------------------
do
	local ok, v = pcall(function()
		return tostring(workspace.AuthorityMode)
	end)
	local __v = (ok and "" or "unreadable: ") .. tostring(v) if not pcall(function() results:SetAttribute("S12_authorityMode", __v) end) then local __sv = results:FindFirstChild("S12_authorityMode") or Instance.new("StringValue") __sv.Name = "S12_authorityMode" __sv.Value = tostring(__v) __sv.Parent = results end -- S12 place: attribute strings are capped at 50 chars
end
local function s12(seconds: number)
	local folder = Instance.new("Folder")
	folder.Name = "S12Bots"
	folder.Parent = workspace
	local bots = {}
	for i = 1, 24 do
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(2, 2, 2)
		p.Position = Vector3.new(-200 + (i % 6) * 70, -90 + (i // 6) * 15, -200 + (i // 6) * 70)
		local a = Instance.new("Attachment")
		a.Parent = p
		local lv = Instance.new("LinearVelocity")
		lv.Attachment0 = a
		lv.MaxForce = 1e6
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.Parent = p
		p.Parent = folder
		pcall(function()
			p:SetNetworkOwner(nil)
		end)
		bots[i] = { p, lv, p.Position }
	end
	local cost, step, hb = {}, {}, {}
	local t0 = os.clock()
	local function drive(dt)
		local c0 = os.clock()
		local t = os.clock() - t0
		for i, b in bots do
			local ang = t * 38 / 40 + i
			b[2].VectorVelocity = Vector3.new(-math.sin(ang), 0, math.cos(ang)) * 38
		end
		table.insert(cost, (os.clock() - c0) * 1000)
	end
	local okBind, bindErr = pcall(function()
		RunService:BindToSimulation(drive)
	end)
	local conn
	if not okBind then
		conn = RunService.PreSimulation:Connect(drive)
	end
	while os.clock() - t0 < seconds do
		task.wait(0.25)
		table.insert(step, Stats.PhysicsStepTimeMs)
		table.insert(hb, Stats.HeartbeatTimeMs)
	end
	pcall(function()
		RunService:UnbindFromSimulation(drive)
	end)
	if conn then
		conn:Disconnect()
	end
	folder:Destroy()
	report("S12_server", { bindOk = okBind, bindErr = tostring(bindErr), callbacks = #cost, callbackMs = { p50 = r3(pct(cost, 0.5)), p99 = r3(pct(cost, 0.99)) },
		physicsStepTimeMs = { p50 = r3(pct(step, 0.5)), max = r3(pct(step, 1)) }, heartbeatTimeMs = { p50 = r3(pct(hb, 0.5)), max = r3(pct(hb, 1)) } })
end

results:GetAttributeChangedSignal("cmd"):Connect(function()
	local c = results:GetAttribute("cmd")
	if typeof(c) ~= "string" or c == "" then
		return
	end
	results:SetAttribute("cmd", "")
	local parts = string.split(c, ":")
	task.spawn(function()
		local ok, err = pcall(function()
			if parts[1] == "s7" then
				s7(Players:GetPlayers()[1], parts[2] == "sweep")
			elseif parts[1] == "s6" then
				s6(Players:GetPlayers()[1], parts[2], tonumber(parts[3]) or 20)
			elseif parts[1] == "s12" then
				s12(tonumber(parts[2]) or 15)
			elseif parts[1] == "s4lag" then
				s4lag(parts[2])
			end
		end)
		if not ok then
			report("error_" .. parts[1], tostring(err))
		end
		results:SetAttribute("done_" .. parts[1] .. (parts[2] and ("_" .. parts[2]) or ""), true)
	end)
end)
