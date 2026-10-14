--!strict
-- Dev/PreyHarness (task S3-C4): a Studio-only test bench for PreyRenderer that needs no
-- PreyService. It builds synthetic `PreyState` packets with the real codec at 10 Hz (two full
-- records for a new group, then deltas, keyframes every 2 s staggered by group ID; 09 §8.5) and
-- feeds them to `PreyRenderer.feed`, the same entry point the remote uses. Groups of krill and
-- plankton circle a point in front of the camera; the frame time and PreyRenderer's draw step are
-- sampled every frame. Task S4-C1 adds far groups (drawn as glints) and groups held on the own
-- mouth, so the local bite test claims their members; with `acceptBites` the harness answers
-- each claim itself with an all-accepted `BiteResult` (no BiteService needed). In Studio the loader calls `bind`, which puts a BindableFunction named
-- `PreyHarness` next to it; tools/studio/prey_bench.py invokes it with execute_luau on the client
-- (a module required from execute_luau would be a second copy, not the running renderer):
--   LocalPlayer.PlayerScripts.Client.PreyHarness:Invoke("start", { seconds = 10 })
--   ... then Invoke("result") until it does not start with "running".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BiteResult = require(ReplicatedStorage.Shared.Net.Codec.BiteResult)
local Formation = require(ReplicatedStorage.Shared.Sim.Formation)
local PreyState = require(ReplicatedStorage.Shared.Net.Codec.PreyState)
local Quantize = require(ReplicatedStorage.Shared.Sim.Quantize)

local Client = require(script.Parent.Parent.Net.Client)
local CreatureController = require(script.Parent.Parent.Controllers.CreatureController)
local PreyRenderer = require(script.Parent.Parent.Render.PreyRenderer)

export type Options = {
	seconds: number?, -- measuring time after a 2 s warm-up (default 10)
	tier: PreyRenderer.GraphicsTier?, -- default Smooth: 80 meshes (15.1)
	krillGroups: number?, -- default 6, 16 members each
	planktonGroups: number?, -- default 3, 8 members each
	radius: number?, -- studs from the centre the groups circle at (default 14 to 34)
	farGroups: number?, -- default 0: krill groups 200 to 600 studs out, drawn as glints
	biteGroups: number?, -- default 0: krill groups held on the own mouth, to be bitten
	acceptBites: boolean?, -- answer every claim with an all-accepted BiteResult
}

type Group = {
	record: PreyState.Full,
	radius: number,
	speed: number, -- studs/s along the circle
	angle: number,
	y: number,
	onMouth: boolean?,
}

local PreyHarness = {}

local WARMUP = 2 -- seconds
local running = false
local FEED = "harness"
local finished = ""
local frames: { number } = {}
local draws: { number } = {}
local drawnMax, outlinedMax = 0, 0
local emittersMax, glintsMax, hiddenMax = 0, 0, 0
local bites: { number } = {}
local base = { claims = 0, claimed = 0, accepted = 0, missed = 0 }
-- Kept across runs: PreyRenderer drops a packet whose seq is not newer than the newest seen.
local seq = 0

local function percentile(sorted: { number }, p: number): number
	if #sorted == 0 then
		return 0
	end
	return sorted[math.clamp(math.ceil(#sorted * p), 1, #sorted)]
end

local function summary(): string
	table.sort(frames)
	table.sort(draws)
	table.sort(bites)
	local sum = 0
	for _, f in frames do
		sum += f
	end
	local mean = if #frames > 0 then sum / #frames else 0
	local s = PreyRenderer.stats()
	return string.format(
		"done frames=%d fps=%.1f frameMs mean=%.2f p50=%.2f p99=%.2f max=%.2f drawMs p50=%.3f p99=%.3f max=%.3f drawnMax=%d outlinedMax=%d groups=%d packets=%d rejected=%d emittersMax=%d glintsMax=%d biteMs p99=%.3f claims=%d claimed=%d accepted=%d missed=%d hiddenMax=%d",
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
		s.rejected,
		emittersMax,
		glintsMax,
		percentile(bites, 0.99),
		s.claims - base.claims,
		s.claimed - base.claimed,
		s.accepted - base.accepted,
		s.missed - base.missed,
		hiddenMax
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
	local r = g.record
	if g.onMouth then
		local mouth, radius = CreatureController.localMouth()
		if radius > 0 then
			r.qx, r.qy, r.qz = Quantize.x(mouth.X), Quantize.y(mouth.Y), Quantize.z(mouth.Z)
			r.qvx, r.qvy, r.qvz, r.scatter = 0, 0, 0, 0
			return
		end
	end
	local w = g.speed / g.radius
	local a = g.angle + w * t
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
	-- The harness is the renderer's only packet source while it runs: the live PreyService stream
	-- has its own seq counter, and the two interleaved reject each other (PreyMirror.setFeed).
	PreyRenderer.setFeed(FEED)
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

	for k = 1, o.farGroups or 0 do
		table.insert(groups, newGroup(#groups, krill, 16, 200 + 10 * k, 4, (k % 5) * 6 - 12))
	end
	for _ = 1, o.biteGroups or 0 do
		local g = newGroup(#groups, krill, 16, 1, 0, 0)
		g.onMouth = true
		table.insert(groups, g)
	end

	running, finished = true, ""
	table.clear(frames)
	table.clear(draws)
	table.clear(bites)
	drawnMax, outlinedMax = 0, 0
	emittersMax, glintsMax, hiddenMax = 0, 0, 0
	do
		local s = PreyRenderer.stats()
		base.claims, base.claimed, base.accepted, base.missed =
			s.claims, s.claimed, s.accepted, s.missed
	end
	local answered = PreyRenderer.stats().lastSeq
	local scratch = PreyState.newScratch()
	local delta = PreyState.newDelta()
	local started = os.clock()

	local connection = RunService.PreRender:Connect(function(dt: number)
		local age = os.clock() - started
		if not running then
			return
		end
		local st = PreyRenderer.stats()
		if o.acceptBites and st.lastSeq ~= answered then
			answered = st.lastSeq
			PreyRenderer.onBiteResult(
				BiteResult.encode(answered, 0xFF, BiteResult.REASON_NONE, 10, 1)
			)
		end
		if age < WARMUP then
			return
		end
		table.insert(frames, dt * 1000)
		local s = PreyRenderer.stats()
		table.insert(draws, s.drawMs)
		drawnMax = math.max(drawnMax, s.drawn)
		outlinedMax = math.max(outlinedMax, s.outlined)
		emittersMax = math.max(emittersMax, s.emitters)
		glintsMax = math.max(glintsMax, s.glints)
		hiddenMax = math.max(hiddenMax, s.hidden)
		table.insert(bites, s.biteMs)
	end)

	task.spawn(function()
		local tick = 0
		while running and os.clock() - started < WARMUP + seconds do
			local nowMs = Client.timeMs()
			local t = os.clock() - started
			local fullCount, deltaCount = 0, 0
			-- One packet stays within 900 bytes (8.6); more groups go out in more packets.
			local function send()
				if fullCount + deltaCount > 0 then
					PreyRenderer.feed(
						PreyState.finish(scratch, seq, nowMs, fullCount, deltaCount),
						FEED
					)
					seq = (seq + 1) % 65536
				end
				fullCount, deltaCount = 0, 0
			end
			-- Full records first (new groups twice, then staggered keyframes), deltas after.
			for _, g in groups do
				place(g, centre, t)
				if tick < 2 or (g.record.groupId % 20) == (tick % 20) then
					if not PreyState.fits(fullCount + 1, deltaCount) then
						send()
					end
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
					if not PreyState.fits(fullCount, deltaCount + 1) then
						send()
					end
					PreyState.writeDelta(scratch, fullCount, deltaCount, delta)
					deltaCount += 1
				end
			end
			send()
			tick += 1
			task.wait(0.1)
		end
		connection:Disconnect()
		finished = summary()
		running = false
		PreyRenderer.setFeed("remote")
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

--- Studio only: exposes `start`, `result` and `stop` to execute_luau through a BindableFunction
--- named `PreyHarness` under `parent`.
function PreyHarness.bind(parent: Instance)
	if not RunService:IsStudio() then
		return
	end
	local f = Instance.new("BindableFunction")
	f.Name = "PreyHarness"
	f.OnInvoke = function(command: string, options: Options?): string
		if command == "start" then
			return PreyHarness.start(options)
		elseif command == "stop" then
			PreyHarness.stop()
			return "stopped"
		end
		return PreyHarness.result()
	end
	f.Parent = parent
end

return PreyHarness
