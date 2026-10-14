--!nonstrict
-- GULP Sprint 0 spike, part B (throwaway). Client half: S7 receiver, S6 PreyState decoder and 80 pooled prey moved
-- with BulkMoveTo, S3 driver (Player1) and observer with the 09 section 6.7 spring (Player2), S4 arrival stamps.
-- Commands: ReplicatedStorage.SpikeBClientState.Cmd:Fire(name, ...); results are attributes on that folder.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")

local me = Players.LocalPlayer
local state = Instance.new("Folder")
state.Name = "SpikeBClientState"
state.Parent = RS
local cmd = Instance.new("BindableEvent")
cmd.Name = "Cmd"
cmd.Parent = state
local ctl = RS:WaitForChild("SpikeBEvent")
local preyEv = RS:WaitForChild("PreyState")
local s7Ev = RS:WaitForChild("S7Probe")
local Formation = require(RS:WaitForChild("Shared"):WaitForChild("Logic"):WaitForChild("Formation"))

local function put(k: string, v: any)
	local __v = HttpService:JSONEncode(v) if not pcall(function() state:SetAttribute(k, __v) end) then local __sv = state:FindFirstChild(k) or Instance.new("StringValue") __sv.Name = k __sv.Value = tostring(__v) __sv.Parent = state end -- S12 place: attribute strings are capped at 50 chars
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
local function myRoot(): BasePart?
	local c = me.Character
	return c and c:FindFirstChild("Root") :: BasePart
end

-- RTT ----------------------------------------------------------------------------------------------------------
local pings = {}
ctl.OnClientEvent:Connect(function(kind, a, b, c, d)
	if kind == "pong" then
		table.insert(pings, os.clock() - a)
	end
end)
local function rtt(n: number)
	pings = {}
	for _ = 1, n do
		ctl:FireServer("ping", os.clock())
		task.wait(0.15)
	end
	task.wait(1)
	return { n = #pings, p50 = r3(pct(pings, 0.5)), max = r3(pct(pings, 1)) }
end

-- S7 receiver ----------------------------------------------------------------------------------------------------
local s7 = nil
local function check(b: buffer): (boolean, number, number)
	local len = buffer.len(b)
	if len < 8 then
		return false, -1, -1
	end
	local seq, phase, size = buffer.readu32(b, 0), buffer.readu16(b, 4), buffer.readu16(b, 6)
	if size ~= len % 65536 then
		return false, seq, phase
	end
	local x = (seq * 2654435761 + phase) % 4294967296
	for i = 8, len - 1 do
		x = (x * 1664525 + 1013904223) % 4294967296
		if buffer.readu8(b, i) ~= bit32.rshift(x, 24) then
			return false, seq, phase
		end
	end
	return true, seq, phase
end
s7Ev.OnClientEvent:Connect(function(b)
	if not s7 then
		return
	end
	local ph = s7.cur
	if typeof(b) ~= "buffer" then
		ph.wrongType += 1
		return
	end
	local ok, seq = check(b)
	if not ok then
		ph.corrupt += 1
	elseif ph.seen[seq] then
		ph.dup += 1
	else
		ph.seen[seq] = true
		ph.ok += 1
		if seq < ph.maxSeq then
			ph.reordered += 1
		end
		ph.maxSeq = math.max(ph.maxSeq, seq)
	end
end)
ctl.OnClientEvent:Connect(function(kind, id, n, size)
	if kind == "s7phase" then
		s7 = s7 or { phases = {} }
		if s7.cur then
			table.insert(s7.phases, s7.cur)
		end
		s7.cur = { id = id, expected = n, size = size, ok = 0, corrupt = 0, dup = 0, reordered = 0, wrongType = 0, maxSeq = 0, seen = {}, kbps = {} }
		local cur = s7.cur
		task.spawn(function()
			while s7 and s7.cur == cur do
				table.insert(cur.kbps, Stats.DataReceiveKbps)
				task.wait(0.5)
			end
		end)
	elseif kind == "s7end" and s7 then
		table.insert(s7.phases, s7.cur)
		local out = {}
		for _, p in s7.phases do
			table.insert(out, { phase = p.id, size = p.size, expected = p.expected, intact = p.ok, corrupt = p.corrupt, dup = p.dup,
				reordered = p.reordered, wrongType = p.wrongType, lossPct = r3(100 * (1 - p.ok / p.expected)), clientDataReceiveKbps = p.kbps })
		end
		s7 = nil
		put("S7", out)
	end
end)

-- S6 client: decode PreyState, draw 80 pooled members with one BulkMoveTo per frame -----------------------------
local groups = {} -- id -> { kind, seed, count, x, y, z, vx, vy, vz, t }
local rx = { packets = 0, bytes = 0, seqDrops = 0, lastSeq = -1, full = 0, delta = 0, unknownDelta = 0 }
preyEv.OnClientEvent:Connect(function(b)
	rx.packets += 1
	rx.bytes += buffer.len(b)
	local seq = buffer.readu16(b, 0)
	if rx.lastSeq >= 0 and seq ~= (rx.lastSeq + 1) % 65536 then
		rx.seqDrops += (seq - rx.lastSeq - 1) % 65536
	end
	rx.lastSeq = seq
	local F, D = buffer.readu8(b, 6), buffer.readu8(b, 7)
	local t = os.clock()
	local o = 8
	for _ = 1, F do
		local id = buffer.readu16(b, o)
		local g = groups[id] or {}
		groups[id] = g
		g.kind, g.count, g.seed = buffer.readu8(b, o + 3), buffer.readu8(b, o + 15), buffer.readu16(b, o + 20)
		g.x, g.y, g.z = buffer.readu16(b, o + 4) / 16 - 1024, buffer.readu16(b, o + 6) / 16 - 640, buffer.readu16(b, o + 8) / 16 - 1024
		g.vx, g.vy, g.vz = buffer.readi8(b, o + 10) / 2, buffer.readi8(b, o + 11) / 2, buffer.readi8(b, o + 12) / 2
		g.t = t
		g.dx = g.dx or g.x
		g.dy = g.dy or g.y
		g.dz = g.dz or g.z
		o += 22
		rx.full += 1
	end
	for _ = 1, D do
		local id = buffer.readu16(b, o)
		local g = groups[id]
		if g then
			g.x, g.y, g.z = buffer.readu16(b, o + 2) / 16 - 1024, buffer.readu16(b, o + 4) / 16 - 640, buffer.readu16(b, o + 6) / 16 - 1024
			g.vx, g.vy, g.vz = buffer.readi8(b, o + 8) / 2, buffer.readi8(b, o + 9) / 2, buffer.readi8(b, o + 10) / 2
			g.t = t
		else
			rx.unknownDelta += 1
		end
		o += 13
		rx.delta += 1
	end
end)

local pool, draw = {}, nil
local function s6draw(seconds: number)
	if #pool == 0 then
		local folder = Instance.new("Folder")
		folder.Name = "PreyPool"
		folder.Parent = workspace
		for i = 1, 80 do
			local p = Instance.new("Part")
			p.Size = Vector3.new(0.8, 0.5, 1.4)
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
			p.Color = Color3.fromHSV((i % 9) / 9, 0.6, 0.9)
			p.Material = Enum.Material.SmoothPlastic
			p.Parent = folder
			pool[i] = p
		end
	end
	rx = { packets = 0, bytes = 0, seqDrops = 0, lastSeq = rx.lastSeq, full = 0, delta = 0, unknownDelta = 0 }
	local dts, costs, fromPackets = {}, {}, {}
	local cfs = table.create(80)
	local t0 = os.clock()
	draw = function(dt)
		local c0 = os.clock()
		local r = myRoot()
		local rp = if r then r.Position else Vector3.zero
		local now = os.clock()
		-- nearest known groups first; drop groups unheard for 3 s
		local list = {}
		for id, g in groups do
			if now - g.t > 3 then
				groups[id] = nil
				continue
			end
			local el = now - g.t
			local tx, ty, tz = g.x + g.vx * el, g.y + g.vy * el, g.z + g.vz * el
			local k = 1 - math.exp(-dt / 0.1)
			g.dx += (tx - g.dx) * k
			g.dy += (ty - g.dy) * k
			g.dz += (tz - g.dz) * k
			table.insert(list, g)
			g.d2 = (g.dx - rp.X) ^ 2 + (g.dz - rp.Z) ^ 2
		end
		table.sort(list, function(a, b)
			return a.d2 < b.d2
		end)
		local n = 0
		local wob = now * 6
		for _, g in list do
			local yaw = math.atan2(-g.vx, -g.vz)
			local rot = CFrame.Angles(0, yaw, 0)
			for i = 0, g.count - 1 do
				if n >= 80 then
					break
				end
				local ox, oy, oz = Formation.offset(g.kind, g.seed, i)
				local off = rot:VectorToWorldSpace(Vector3.new(ox, oy, oz))
				n += 1
				cfs[n] = CFrame.new(g.dx + off.X, g.dy + off.Y, g.dz + off.Z) * rot * CFrame.Angles(0, math.sin(wob + i) * 0.2, 0)
			end
			if n >= 80 then
				break
			end
		end
		local real = n
		for i = n + 1, 80 do -- not enough known members nearby: keep every pooled part moving anyway
			cfs[i] = CFrame.new(rp + Vector3.new(math.cos(wob * 0.2 + i) * 20, math.sin(i) * 6, math.sin(wob * 0.2 + i) * 20))
		end
		workspace:BulkMoveTo(pool, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		table.insert(costs, (os.clock() - c0) * 1000)
		table.insert(dts, dt * 1000)
		table.insert(fromPackets, real)
		if os.clock() - t0 > seconds then
			draw = nil
			put("S6_client", {
				frames = #dts, frameMs = { mean = r3((function() local s = 0 for _, v in dts do s += v end return s / #dts end)()), p50 = r3(pct(dts, 0.5)), p99 = r3(pct(dts, 0.99)), max = r3(pct(dts, 1)) },
				drawStepMs = { p50 = r3(pct(costs, 0.5)), p99 = r3(pct(costs, 0.99)), max = r3(pct(costs, 1)) },
				membersFromPackets = { p50 = pct(fromPackets, 0.5), min = pct(fromPackets, 0) },
				rx = { packets = rx.packets, bytes = rx.bytes, bytesPerSec = math.round(rx.bytes / seconds), seqDrops = rx.seqDrops, full = rx.full, delta = rx.delta, unknownDelta = rx.unknownDelta },
				knownGroups = #list,
			})
		end
	end
end
RunService.RenderStepped:Connect(function(dt)
	if draw then
		draw(dt)
	end
end)

-- S3 driver (Player1): circle at 38 studs/s, then the same with a 2.2x dash for 0.35 s every 2.5 s -------------
local drive = nil
RunService:BindToRenderStep("SpikeBDrive", Enum.RenderPriority.Input.Value + 2, function(dt)
	local r = myRoot()
	if not (drive and r) then
		return
	end
	local move = r:FindFirstChild("Move") :: LinearVelocity
	local turn = r:FindFirstChild("Turn") :: AlignOrientation
	local t = os.clock() - drive.t0
	if drive.last then
		drive.path += (r.Position - drive.last).Magnitude
	end
	drive.last = r.Position
	drive.frames += 1
	if t > drive.seconds then
		put("drive", { seconds = drive.seconds, frames = drive.frames, pathStuds = r3(drive.path), meanSpeed = r3(drive.path / drive.seconds) })
		drive = nil
		move.VectorVelocity = Vector3.zero
		return
	end
	local C, R = Vector3.new(0, -50, 0), 60
	local rel = r.Position - C
	local flat = Vector3.new(rel.X, 0, rel.Z)
	local rr = math.max(flat.Magnitude, 1)
	local tangent = Vector3.new(-flat.Z, 0, flat.X) / rr
	local dir = tangent + (-flat / rr) * math.clamp((rr - R) / 20, -1, 1) + Vector3.yAxis * math.clamp((C.Y - r.Position.Y) / 20, -0.5, 0.5)
	local speed = 38
	if t > drive.dashFrom and ((t - drive.dashFrom) % 2.5) < 0.35 then
		speed = 38 * 2.2
	end
	move.VectorVelocity = dir.Unit * speed
	turn.CFrame = CFrame.lookAlong(Vector3.zero, dir.Unit)
end)

-- S3 observer (Player2): spring per 09 section 6.7 on the other creature's replicated root ---------------------
local obs = nil
local function springStep(x: Vector3, v: Vector3, target: Vector3, omega: number, dt: number): (Vector3, Vector3)
	local e = math.exp(-omega * dt)
	local d = x - target
	local temp = (v + d * omega) * dt
	return target + (d + temp) * e, (v - temp * omega) * e
end
local renderEvent = RunService.PreRender or RunService.RenderStepped
renderEvent:Connect(function(dt)
	if not obs then
		return
	end
	if not obs.root or not obs.root.Parent then
		for _, m in workspace.Creatures:GetChildren() do
			if m.Name ~= "Creature_" .. me.UserId and m:FindFirstChild("Root") then
				obs.root = m.Root
			end
		end
		if not obs.root then
			return
		end
		obs.rig, obs.vel = obs.root.Position, Vector3.zero
		obs.prevRaw, obs.prevRig = obs.root.Position, obs.rig
		return
	end
	local raw = obs.root.Position
	obs.rig, obs.vel = springStep(obs.rig, obs.vel, raw, 1 / obs.tau, dt)
	local rawStep, rigStep = raw - obs.prevRaw, obs.rig - obs.prevRig
	local rawV = rawStep / math.max(dt, 1e-4)
	local speed = rawV.Magnitude
	-- pop: how far this frame's step departs from the previous frame's velocity carried over this frame
	local rawPop = obs.prevRawV and (rawStep - obs.prevRawV * dt).Magnitude or 0
	local rigPop = obs.prevRigV and (rigStep - obs.prevRigV * dt).Magnitude or 0
	local t = os.clock()
	if speed > 55 then
		obs.lastDash = t
	end
	local bucket = if obs.lastDash and t - obs.lastDash < 0.8 then obs.dash else obs.cruise
	if speed > 2 or bucket == obs.dash then
		bucket.frames += 1
		table.insert(bucket.rawPop, rawPop)
		table.insert(bucket.rigPop, rigPop)
		bucket.maxLag = math.max(bucket.maxLag, (obs.rig - raw).Magnitude)
		bucket.maxRawSpeed = math.max(bucket.maxRawSpeed, speed)
		if rawStep.Magnitude < 1e-3 then
			bucket.stalls += 1
		end
	end
	table.insert(obs.dts, dt)
	obs.prevRaw, obs.prevRig = raw, obs.rig
	obs.prevRawV, obs.prevRigV = rawV, rigStep / math.max(dt, 1e-4)
	if t - obs.t0 > obs.seconds then
		local function sum(bk)
			return { frames = bk.frames, rigPopMax = r3(pct(bk.rigPop, 1)), rigPopP99 = r3(pct(bk.rigPop, 0.99)), rawPopMax = r3(pct(bk.rawPop, 1)),
				rawPopP99 = r3(pct(bk.rawPop, 0.99)), rigLagMax = r3(bk.maxLag), maxRawSpeed = r3(bk.maxRawSpeed), rawStallFrames = bk.stalls }
		end
		put("S3_" .. obs.tag, { framesWithTarget = #obs.dts, tau = obs.tau, cruise = sum(obs.cruise), dash = sum(obs.dash), frameMsP50 = r3(pct(obs.dts, 0.5) * 1000), frameMsMax = r3(pct(obs.dts, 1) * 1000) })
		obs = nil
	end
end)

-- S4 arrival stamps (Player1) -------------------------------------------------------------------------------------
local ring = {}
local s4 = {}
RunService.RenderStepped:Connect(function()
	local r = myRoot()
	if not r then
		return
	end
	table.insert(ring, { workspace:GetServerTimeNow(), r.Position })
	if #ring > 400 then
		table.remove(ring, 1)
	end
	for i, p in s4 do
		if not p.done and workspace:GetServerTimeNow() - p.t < 1.5 then
			for _, smp in ring do
				if smp[1] >= p.t - 0.05 then
					p.minDist = math.min(p.minDist or math.huge, (smp[2] - p.target).Magnitude)
				end
				if smp[1] >= p.t - 0.05 and (smp[2] - p.target).Magnitude < 2.5 then
					p.done = true
					p.delay = r3(smp[1] - p.t)
					break
				end
			end
		end
	end
end)
ctl.OnClientEvent:Connect(function(kind, i, target, t)
	if kind == "s4target" then
		s4[i] = { target = target, t = t, msgDelay = r3(workspace:GetServerTimeNow() - t) }
	end
end)

-- S12 owner side: drive the own root inside BindToSimulation and look for corrections (pops) on the owner
local function s12(seconds: number)
	local r = myRoot()
	local move = r:FindFirstChild("Move") :: LinearVelocity
	local sim = 0
	-- Part D retry: the input is a pure function of the simulated state (the root's own position on the R = 60
	-- circle), not of wall-clock time, so a resimulated tick sees exactly the input the first pass saw.
	local CENTER = r.Position - Vector3.new(60, 0, 0)
	local argInfo, lastP, lastV = nil, nil, nil
	local stepDev = {}
	local function step(dt, ...)
		sim += 1
		if not argInfo then
			argInfo = { n = select("#", ...) + 1, t1 = typeof(dt), v1 = tostring(dt) }
			for i = 1, select("#", ...) do argInfo["t" .. (i + 1)] = typeof((select(i, ...))) argInfo["v" .. (i + 1)] = string.sub(tostring((select(i, ...))), 1, 40) end
		end
		local p = r.Position
		if lastP and type(dt) == "number" then
			table.insert(stepDev, (p - (lastP + lastV * dt)).Magnitude)
		end
		local rel = Vector3.new(p.X - CENTER.X, 0, p.Z - CENTER.Z)
		local ang = math.atan2(rel.Z, rel.X)
		local tangent = Vector3.new(-math.sin(ang), 0, math.cos(ang))
		local radial = if rel.Magnitude > 1e-3 then rel.Unit else Vector3.zero
		local dash = ((ang / (2 * math.pi)) * 6) % 1 < 0.14
		local v = tangent * (if dash then 83.6 else 38) + radial * (60 - rel.Magnitude) * 2
		move.VectorVelocity = v
		lastP, lastV = p, v
	end
	local okBind, err = pcall(function()
		RunService:BindToSimulation(step)
	end)
	local pops, prev, prevV = {}, nil, nil
	local conn = RunService.RenderStepped:Connect(function(dt)
		local p = r.Position
		if prev then
			local v = (p - prev) / math.max(dt, 1e-4)
			if prevV then
				table.insert(pops, ((p - prev) - prevV * dt).Magnitude)
			end
			prevV = v
		end
		prev = p
	end)
	local ok2, am = pcall(function()
		return tostring(workspace.AuthorityMode)
	end)
	task.wait(seconds)
	conn:Disconnect()
	pcall(function()
		RunService:UnbindFromSimulation(step)
	end)
	move.VectorVelocity = Vector3.zero
	put("S12_client", { authorityMode = (ok2 and "" or "unreadable: ") .. tostring(am), bindOk = okBind, bindErr = tostring(err), simCallbacks = sim,
		frames = #pops, ownerPopMax = r3(pct(pops, 1)), ownerPopP99 = r3(pct(pops, 0.99)), cbArgs = argInfo,
		stepDevMax = r3(pct(stepDev, 1)), stepDevP99 = r3(pct(stepDev, 0.99)), stepDevOver05 = (function() local n = 0 for _, x in stepDev do if x > 0.5 then n += 1 end end return n end)() })
end

cmd.Event:Connect(function(what, a, b)
	if what == "s12" then
		task.spawn(s12, a)
	end
	if what == "rtt" then
		put("rtt_" .. tostring(a), rtt(12))
	elseif what == "s6draw" then
		s6draw(a)
	elseif what == "drive" then
		drive = { t0 = os.clock(), seconds = a, dashFrom = b, path = 0, frames = 0 }
	elseif what == "observe" then
		local function bk()
			return { frames = 0, rawPop = {}, rigPop = {}, maxLag = 0, maxRawSpeed = 0, stalls = 0 }
		end
		obs = { t0 = os.clock(), seconds = a, tag = b, tau = 0.08, cruise = bk(), dash = bk(), dts = {}, found = 0 }
	elseif what == "s4reset" then
		s4 = {}
	elseif what == "s4report" then
		local out = {}
		for i, p in s4 do
			out[i] = { delay = p.delay or "not seen", msgDelay = p.msgDelay, minDistWithin1_5s = p.minDist and r3(p.minDist) }
		end
		put("S4_" .. tostring(a), out)
	end
end)
