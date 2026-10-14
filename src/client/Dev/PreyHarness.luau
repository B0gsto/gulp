--!strict
-- Dev/PreyHarness (task S3-C4): a Studio-only test bench for PreyRenderer that needs no
-- PreyService. It builds synthetic `PreyState` packets with the real codec at 10 Hz (two full
-- records for a new group, then deltas, keyframes every 2 s staggered by group ID; 09 §8.5) and
-- feeds them to `PreyRenderer.feed`, the same entry point the remote uses. Groups of krill and
-- plankton circle a point in front of the camera; the frame time and PreyRenderer's draw step are
-- sampled every frame. Nothing requires this module: tools/studio/prey_bench.py drives it with
-- execute_luau on the client:
--   require(LocalPlayer.PlayerScripts.Client.Dev.PreyHarness).start({ seconds = 10 })
--   ... then poll .result() until it does not start with "running".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Formation = require(ReplicatedStorage.Shared.Sim.Formation)
local PreyState = require(ReplicatedStorage.Shared.Net.Codec.PreyState)
local Quantize = require(ReplicatedStorage.Shared.Sim.Quantize)

local Client = require(script.Parent.Parent.Net.Client)
local PreyRenderer = require(script.Parent.Parent.Render.PreyRenderer)

export type Options = {
	seconds: number?, -- measuring time after a 2 s warm-up (default 10)
	tier: PreyRenderer.GraphicsTier?, -- default Smooth: 80 meshes (15.1)
	krillGroups: number?, -- default 6, 16 members each
	planktonGroups: number?, -- default 3, 8 members each
	radius: number?, -- studs from the centre the groups circle at (default 14 to 34)
}

type Group = {
	record: PreyState.Full,
	radius: number,
	speed: number, -- studs/s along the circle
	angle: number,
	y: number,
}

local PreyHarness = {}

local WARMUP = 2 -- seconds
local running = false
local finished = ""
local frames: { number } = {}
local draws: { number } = {}
local drawnMax, outlinedMax = 0, 0

local function percentile(sorted: { number }, p: number): number
	if #sorted == 0 then
		return 0
	end
	return sorted[math.clamp(math.ceil(#sorted * p), 1, #sorted)]
end

local function summary(): string
	table.sort(frames)
	table.sort(draws)
	local sum = 0
	for _, f in frames do
		sum += f
	end
	local mean = if #frames > 0 then sum / #frames else 0
	local s = PreyRenderer.stats()
	return string.format(
		"done frames=%d fps=%.1f frameMs mean=%.2f p50=%.2f p99=%.2f max=%.2f drawMs p50=%.3f p99=%.3f max=%.3f drawnMax=%d outlinedMax=%d groups=%d packets=%d rejected=%d",
		#frames,
		if mean > 0 then 1000 / mean else 0,
		mean,
		percentile(frames, 0.5),
		percentile(frames, 0.99),
		percentile(frames, 1),
		percentile(draws, 0.5),
		percentile(draws, 0.99),
		percentile(draws, 1),
		drawnMax,
		outlinedMax,
		s.groups,
		s.packets,
		s.rejected
	)
end

local function newGroup(
	id: number,
	kind: number,
	count: number,
	radius: number,
	speed: number,
	y: number
): Group
	local r = PreyState.newFull()
	r.groupId, r.gen, r.kind, r.count = id, 1, kind, count
	r.alive = bit32.rshift(0xFFFFFFFF, 32 - count)
	r.seed = (id * 7919) % 65536
	return { record = r, radius = radius, speed = speed, angle = id * 0.9, y = y }
end

-- Moves group `g` to time `t` around `centre`, writing its quantised state into its record.
local function place(g: Group, centre: Vector3, t: number)
	local w = g.speed / g.radius
	local a = g.angle + w * t
	local r = g.record
	r.qx = Quantize.x(centre.X + g.radius * math.cos(a))
	r.qy = Quantize.y(centre.Y + g.y)
	r.qz = Quantize.z(centre.Z + g.radius * math.sin(a))
	r.qvx = Quantize.vel(-g.speed * math.sin(a))
	r.qvy = 0
	r.qvz = Quantize.vel(g.speed * math.cos(a))
	r.scatter = 0
end

--- Starts feeding and measuring; returns at once. Errors outside Studio.
function PreyHarness.start(options: Options?): string
	assert(RunService:IsStudio(), "PreyHarness is a Studio dev tool")
	if running then
		return "already running"
	end
	local o: Options = options or {}
	local seconds = o.seconds or 10
	PreyRenderer.setQuality(o.tier or "Smooth")
	local camera = workspace.CurrentCamera
	local look = camera.CFrame.LookVector
	local centre = camera.CFrame.Position + Vector3.new(look.X, 0, look.Z).Unit * 40
	centre = Vector3.new(centre.X, math.min(centre.Y, Quantize.Y_MAX - 10), centre.Z)

	local krill = Formation.kindOf("krill") :: number
	local plankton = Formation.kindOf("plankton") :: number
	local groups: { Group } = {}
	for k = 1, o.krillGroups or 6 do
		local radius = (o.radius or 14) + 4 * k
		table.insert(groups, newGroup(#groups, krill, 16, radius, 5.6, (k % 3) * 3 - 3))
	end
	for k = 1, o.planktonGroups or 3 do
		table.insert(groups, newGroup(#groups, plankton, 8, 8 + 3 * k, 2, k * 2 - 4))
	end

	running, finished = true, ""
	table.clear(frames)
	table.clear(draws)
	drawnMax, outlinedMax = 0, 0
	local scratch = PreyState.newScratch()
	local delta = PreyState.newDelta()
	local started = os.clock()

	local connection = RunService.PreRender:Connect(function(dt: number)
		local age = os.clock() - started
		if age < WARMUP or not running then
			return
		end
		table.insert(frames, dt * 1000)
		local s = PreyRenderer.stats()
		table.insert(draws, s.drawMs)
		drawnMax = math.max(drawnMax, s.drawn)
		outlinedMax = math.max(outlinedMax, s.outlined)
	end)

	task.spawn(function()
		local seq, tick = 0, 0
		while running and os.clock() - started < WARMUP + seconds do
			local nowMs = Client.timeMs()
			local t = os.clock() - started
			local fullCount, deltaCount = 0, 0
			-- Full records first (new groups twice, then staggered keyframes), deltas after.
			for _, g in groups do
				place(g, centre, t)
				if tick < 2 or (g.record.groupId % 20) == (tick % 20) then
					PreyState.writeFull(scratch, fullCount, g.record)
					fullCount += 1
				end
			end
			for _, g in groups do
				if not (tick < 2 or (g.record.groupId % 20) == (tick % 20)) then
					local r = g.record
					delta.groupId, delta.qx, delta.qy, delta.qz = r.groupId, r.qx, r.qy, r.qz
					delta.qvx, delta.qvy, delta.qvz = r.qvx, r.qvy, r.qvz
					delta.scatter, delta.flags = r.scatter, r.flags
					PreyState.writeDelta(scratch, fullCount, deltaCount, delta)
					deltaCount += 1
				end
			end
			PreyRenderer.feed(PreyState.finish(scratch, seq, nowMs, fullCount, deltaCount))
			seq = (seq + 1) % 65536
			tick += 1
			task.wait(0.1)
		end
		connection:Disconnect()
		finished = summary()
		running = false
	end)
	return `started: {#groups} groups, tier {o.tier or "Smooth"}, {seconds} s after {WARMUP} s warm-up`
end

--- "running" while measuring, then the summary line (starts with "done").
function PreyHarness.result(): string
	if running then
		return "running"
	end
	return if finished ~= "" then finished else "not started"
end

--- Stops early; the summary covers the frames so far.
function PreyHarness.stop()
	running = false
end

return PreyHarness
