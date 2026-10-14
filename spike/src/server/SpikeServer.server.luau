--!nonstrict
-- GULP Sprint 0 technical spike, part A (throwaway). Server half.
-- Builds the 09 section 6.1 creature, assigns it per 6.2 and runs the measured sequence for S14, S2, S4, S5.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local PhysicsService = game:GetService("PhysicsService")

Players.CharacterAutoLoads = false

local results = Instance.new("Folder")
results.Name = "SpikeResults"
results.Parent = RS
local ev = Instance.new("RemoteEvent")
ev.Name = "SpikeEvent"
ev.Parent = RS
local fn = Instance.new("RemoteFunction")
fn.Name = "SpikeFn"
fn.Parent = RS

local function report(key: string, value: any)
	local json = HttpService:JSONEncode(value)
	local __v = json if not pcall(function() results:SetAttribute(key, __v) end) then local __sv = results:FindFirstChild(key) or Instance.new("StringValue") __sv.Name = key __sv.Value = tostring(__v) __sv.Parent = results end -- S12 place: attribute strings are capped at 50 chars
	print("[SPIKE] " .. key .. " " .. json)
end

-- S11, Roblox half: relative string requires inside ReplicatedStorage.Shared.
do
	local ok, res = pcall(function()
		local TierMath = require(RS.Shared.Logic.TierMath)
		local SwimModel = require(RS.Shared.Logic.SwimModel)
		return { scale8 = TierMath.bodyScale(8), tier250 = TierMath.tier(250), speed250 = SwimModel.speedForMass(250) }
	end)
	local okPack, pack = pcall(function()
		return require(RS.Shared.Pack).value
	end)
	report("S11_roblox", { ok = ok, res = ok and res or tostring(res), packOk = okPack, pack = okPack and pack or tostring(pack) })
end
local Tiers = require(RS.Shared.Data.Tiers)

-- Collision groups (09 section 6.5).
PhysicsService:RegisterCollisionGroup("World")
PhysicsService:RegisterCollisionGroup("Creature")
PhysicsService:CollisionGroupSetCollidable("World", "Creature", true)
PhysicsService:CollisionGroupSetCollidable("Creature", "Creature", true)
for _, p in workspace.Collision:GetChildren() do
	if p:IsA("BasePart") then
		p.CollisionGroup = "World"
	end
end

-- Non-persistent clutter: near the spawn (streams with the player) and 4,000 studs away (S5).
local rng = Random.new(7)
local function clutter(name: string, centre: Vector3, count: number)
	local folder = Instance.new("Folder")
	folder.Name = name
	if name == "FarReef" then
		local floor = Instance.new("Part")
		floor.Name = "Floor"
		floor.Anchored = true
		floor.Size = Vector3.new(700, 4, 700)
		floor.Position = centre + Vector3.new(0, -62, 0)
		floor.Parent = folder
	end
	for i = 1, count do
		local p = Instance.new("Part")
		p.Name = "Rock"
		p.Anchored = true
		p.CanCollide = false
		p.Size = Vector3.one * rng:NextNumber(2, 6)
		p.Position = centre + Vector3.new(rng:NextNumber(-280, 280), rng:NextNumber(-58, 40), rng:NextNumber(-280, 280))
		p.Color = Color3.fromHSV(rng:NextNumber(), 0.6, 0.9)
		p.Parent = folder
	end
	folder.Parent = workspace
end
clutter("Reef", Vector3.new(0, -60, 0), 1500)
clutter("FarReef", Vector3.new(4000, -60, 0), 4000)

local SPAWN = CFrame.new(0, -60, 0)

local function build(player: Player): (Model, Part)
	local model = Instance.new("Model")
	model.Name = "Creature_" .. player.UserId
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Shape = Enum.PartType.Ball
	root.Size = Vector3.one * 2.0
	root.Transparency = 1
	root.CanCollide = true
	root.CanTouch = false
	root.CanQuery = true
	root.CastShadow = false
	root.CollisionGroup = "Creature"
	root.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0.2)
	local att = Instance.new("Attachment")
	att.Name = "RootAttachment"
	att.Parent = root
	local move = Instance.new("LinearVelocity")
	move.Name = "Move"
	move.Attachment0 = att
	move.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	move.RelativeTo = Enum.ActuatorRelativeTo.World
	move.MaxForce = 1e6
	move.VectorVelocity = Vector3.zero
	move.Parent = root
	local turn = Instance.new("AlignOrientation")
	turn.Name = "Turn"
	turn.Mode = Enum.OrientationAlignmentMode.OneAttachment
	turn.Attachment0 = att
	turn.Responsiveness = 40
	turn.MaxTorque = 1e6
	turn.Parent = root
	root.Parent = model
	model.PrimaryPart = root
	return model, root
end

local sessions = {} -- [player] = { tJoin, root, reports = {}, arrivals = {} }

local function onPlayer(player: Player)
	local s = { tJoin = os.clock(), reports = {}, arrivals = {}, pauseLog = {}, persistentT = nil }
	sessions[player] = s
	player:GetPropertyChangedSignal("GameplayPaused"):Connect(function()
		table.insert(s.pauseLog, { t = os.clock() - s.tJoin, paused = player.GameplayPaused })
	end)
end
workspace.PersistentLoaded:Connect(function(player)
	local s = sessions[player]
	if s and not s.persistentT then
		s.persistentT = os.clock() - s.tJoin
	end
end)
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	if not sessions[p] then
		onPlayer(p)
	end
end

local function onHello(player: Player)
	local s = sessions[player]
	if s.root then
		return
	end
	local tHello = os.clock()
	local model, root = build(player)
	s.root = root
	local fired = false
	player.CharacterAdded:Connect(function(c)
		fired = true
		report("S1_server", {
			characterAdded = true,
			sameModel = c == model,
			hasHumanoid = c:FindFirstChildOfClass("Humanoid") ~= nil,
			dtFromAssign = os.clock() - tHello,
			helloAfterJoin = tHello - s.tJoin,
			persistentLoadedAfterJoin = s.persistentT or "not yet",
		})
	end)
	-- 09 section 6.2, in order.
	model:PivotTo(SPAWN)
	model.Parent = workspace.Creatures
	player.Character = model
	root:SetNetworkOwner(player)
	player.ReplicationFocus = root
	task.delay(3, function()
		if not fired then
			report("S1_server", { characterAdded = false })
		end
		report("S5_join", { persistentLoadedAfterJoin = s.persistentT or "never", pauseLog = s.pauseLog })
	end)
end

local function waitReport(s, key: string, timeout: number)
	local t0 = os.clock()
	while s.reports[key] == nil and os.clock() - t0 < timeout do
		task.wait(0.05)
	end
	return s.reports[key]
end

fn.OnServerInvoke = function(_player, what)
	if what == "time" then
		return workspace:GetServerTimeNow(), DateTime.now().UnixTimestampMillis / 1000, os.time()
	end
	return nil
end

local function s4Target(i: number): Vector3
	if i <= 5 then
		return Vector3.new(-200 + 30 * i, -40, 150)
	end
	return Vector3.new(-200 + 30 * (i - 5), -40, -150)
end

local function runAll(player: Player)
	local s = sessions[player]
	local root: Part = s.root

	-- S14 --------------------------------------------------------------------------------------
	local elapsed = os.clock() - s.tJoin
	if elapsed < 10 then
		task.wait(10 - elapsed)
	end
	local edges = {}
	local last = os.time()
	local tEnd = os.clock() + 3.3
	while os.clock() < tEnd do
		RunService.Heartbeat:Wait()
		local now = os.time()
		if now ~= last then
			last = now
			-- at the first frame after os.time() ticks, GetServerTimeNow() - os.time() should be within one frame of 0
			table.insert(edges, workspace:GetServerTimeNow() - now)
		end
	end
	report("S14_server", {
		serverTimeNowMinusOsTimeAtTick = edges,
		dateTimeNowMinusServerTimeNow = DateTime.now().UnixTimestampMillis / 1000 - workspace:GetServerTimeNow(),
		secondsInGame = os.clock() - s.tJoin,
	})
	ev:FireClient(player, "s14")
	waitReport(s, "S14_client", 10)

	-- S2 (Mac half) and S18-lite -----------------------------------------------------------------
	for tier = 1, 7 do
		local scale = Tiers[tier].scale
		root.Size = Vector3.one * 2.0 * scale
		ev:FireClient(player, "s2", tier, scale)
		local r = waitReport(s, "S2_t" .. tier, 20)
		local pos = root.Position
		report("S2_server_t" .. tier, { clientReported = r ~= nil, rootSize = root.Size.X, mass = root.AssemblyMass, serverSeesY = pos.Y })
	end
	root.Size = Vector3.one * 2.0
	task.wait(0.5)

	-- S4, single-client half -------------------------------------------------------------------
	local rows = {}
	for i = 1, 10 do
		if i == 1 then
			ev:FireClient(player, "s4mode", "idle")
			task.wait(0.5)
		elseif i == 6 then
			ev:FireClient(player, "s4mode", "swim")
			task.wait(0.5)
		end
		local target = s4Target(i)
		local distBefore = (root.Position - target).Magnitude
		local t0 = workspace:GetServerTimeNow()
		root.CFrame = CFrame.new(target)
		local tw = os.clock()
		while s.arrivals[i] == nil and os.clock() - tw < 2 do
			RunService.Heartbeat:Wait()
		end
		local a = s.arrivals[i]
		task.wait(0.3)
		table.insert(rows, {
			i = i,
			mode = i <= 5 and "idle" or "swim",
			distBefore = distBefore,
			ownerArrivedAfter = a and (a.clientStamp - t0) or "never",
			serverHeardAfter = a and (a.serverRecv - t0) or "never",
			serverDistAfter03 = (root.Position - target).Magnitude,
			owner = tostring(root:GetNetworkOwner()),
		})
		task.wait(0.4)
	end
	report("S4_write", rows)

	-- freeze: SetNetworkOwner(nil) then anchor, while the client fights it
	ev:FireClient(player, "s4mode", "fight")
	task.wait(0.7)
	local movingBefore = root.AssemblyLinearVelocity.Magnitude
	root:SetNetworkOwner(nil)
	root.Anchored = true
	task.wait(0.25)
	local p0 = root.Position
	local maxDrift = 0
	local tf = os.clock()
	while os.clock() - tf < 2 do
		RunService.Heartbeat:Wait()
		maxDrift = math.max(maxDrift, (root.Position - p0).Magnitude)
	end
	ev:FireClient(player, "s4mode", "idle")
	local fightClient = waitReport(s, "S4_fightClient", 5)
	-- gulped flow: move it to the cove spawn while frozen
	root.CFrame = SPAWN
	task.wait(0.4)
	s.reports["S4_where"] = nil
	ev:FireClient(player, "where")
	local where = waitReport(s, "S4_where", 5)
	local whereJson = where and HttpService:JSONDecode(where) or nil
	-- thaw and check the client drives it again
	root.Anchored = false
	root:SetNetworkOwner(player)
	task.wait(0.3)
	local q0 = root.Position
	ev:FireClient(player, "s4mode", "swim")
	task.wait(1.0)
	local regained = (root.Position - q0).Magnitude
	ev:FireClient(player, "s4mode", "idle")
	report("S4_freeze", {
		speedBeforeFreeze = movingBefore,
		serverMaxDriftWhileFrozen = maxDrift,
		clientFight = fightClient and HttpService:JSONDecode(fightClient) or "no report",
		clientDistFromSpawnAfterServerMove = whereJson and whereJson.distFromSpawn or "no report",
		movedAfterThaw1s = regained,
		ownerAfterThaw = tostring(root:GetNetworkOwner()),
	})
	task.wait(0.5)

	-- S5: teleport the creature 4,000 studs into an unloaded area ----------------------------
	local logStart = #s.pauseLog
	ev:FireClient(player, "s5far")
	task.wait(0.3)
	local tTeleport = os.clock() - s.tJoin
	root.CFrame = CFrame.new(4000, -60, 0)
	task.wait(6)
	local serverXFar = root.Position.X
	ev:FireClient(player, "s5back")
	waitReport(s, "S5_client", 5)
	root.CFrame = SPAWN
	task.wait(3)
	local log = {}
	for i = logStart + 1, #s.pauseLog do
		table.insert(log, s.pauseLog[i])
	end
	report("S5_server", {
		teleportAt = tTeleport,
		gameplayPausedChangesOnServer = log,
		serverRootXAfter6s = serverXFar,
		replicationFocusIsRoot = player.ReplicationFocus == root,
		persistentLoadedAfterJoin = s.persistentT or "never",
	})
	report("done", { t = os.clock() - s.tJoin })
end

ev.OnServerEvent:Connect(function(player, kind, a, b)
	local s = sessions[player]
	if not s then
		return
	end
	if kind == "hello" then
		onHello(player)
	elseif kind == "report" then
		s.reports[a] = b
		local __v = b if not pcall(function() results:SetAttribute(a, __v) end) then local __sv = results:FindFirstChild(a) or Instance.new("StringValue") __sv.Name = a __sv.Value = tostring(__v) __sv.Parent = results end -- S12 place: attribute strings are capped at 50 chars
		print("[SPIKE] " .. tostring(a) .. " " .. tostring(b))
	elseif kind == "s4arrive" then
		s.arrivals[a] = { clientStamp = b, serverRecv = workspace:GetServerTimeNow() }
	end
end)

-- The driver (spike/tools/drive.py) sets this attribute through MCP execute_luau.
results:GetAttributeChangedSignal("cmd"):Connect(function()
	if results:GetAttribute("cmd") == "runAll" then
		local player = Players:GetPlayers()[1]
		if player and sessions[player] and sessions[player].root then
			task.spawn(function()
				local ok, err = pcall(runAll, player)
				if not ok then
					report("runAllError", { err = tostring(err) })
					report("done", { failed = true })
				end
			end)
		end
	end
end)

print("[SPIKE] server ready")
