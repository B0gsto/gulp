--!nonstrict
-- GULP Sprint 0 technical spike, part A (throwaway). Client half.
-- Scriptable camera, keyboard SwimInput, LinearVelocity + AlignOrientation swim, client-made rig, probes.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local tStart = os.clock()
local player = Players.LocalPlayer
local SPAWN = Vector3.new(0, -60, 0)

local function shellCount(): number
	local c = workspace:FindFirstChild("Collision")
	return c and #c:GetChildren() or -1
end
local early = {
	shellAtScriptStart = shellCount(),
	gameLoadedAtStart = game:IsLoaded(),
	charAtStart = player.Character ~= nil,
	pausedAtStart = player.GameplayPaused,
}
local persistentLoadedT: number? = nil
workspace.PersistentLoaded:Connect(function()
	persistentLoadedT = persistentLoadedT or (os.clock() - tStart)
end)

-- Local-only state the driver reads through MCP execute_luau on the Client data model.
local state = Instance.new("Folder")
state.Name = "SpikeClientState"
local cmd = Instance.new("BindableEvent")
cmd.Name = "Cmd"
cmd.Parent = state
state.Parent = RS

local ev = RS:WaitForChild("SpikeEvent")
local fn = RS:WaitForChild("SpikeFn")
local function setState(k: string, v: any)
	local __v = HttpService:JSONEncode(v) if not pcall(function() state:SetAttribute(k, __v) end) then local __sv = state:FindFirstChild(k) or Instance.new("StringValue") __sv.Name = k __sv.Value = tostring(__v) __sv.Parent = state end -- S12 place: attribute strings are capped at 50 chars
end
local function report(k: string, v: any)
	local j = HttpService:JSONEncode(v)
	local __v = j if not pcall(function() state:SetAttribute(k, __v) end) then local __sv = state:FindFirstChild(k) or Instance.new("StringValue") __sv.Name = k __sv.Value = tostring(__v) __sv.Parent = state end -- S12 place: attribute strings are capped at 50 chars
	ev:FireServer("report", k, j)
end

-- S10: all core GUI off.
local coreOk, coreErr = pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end)
pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local SwimModel = require(RS:WaitForChild("Shared"):WaitForChild("Logic"):WaitForChild("SwimModel"))
local Tiers = require(RS.Shared.Data.Tiers)

-- Client-made rig (never welded to the root; 09 section 6.7).
local rig = Instance.new("Model")
rig.Name = "Rig"
local function mk(name: string, size: Vector3, offset: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.CFrame = CFrame.new(offset)
	p.Parent = rig
	return p
end
local body = mk("Body", Vector3.new(1.4, 1.5, 2.6), Vector3.zero, Color3.fromRGB(255, 140, 40))
mk("Tail", Vector3.new(0.3, 1.4, 1.0), Vector3.new(0, 0, 1.7), Color3.fromRGB(255, 200, 60))
mk("Fin", Vector3.new(0.2, 0.7, 1.0), Vector3.new(0, 1.0, 0.2), Color3.fromRGB(255, 200, 60))
mk("EyeL", Vector3.new(0.4, 0.4, 0.4), Vector3.new(-0.7, 0.3, -0.9), Color3.new(0, 0, 0), Enum.PartType.Ball)
mk("EyeR", Vector3.new(0.4, 0.4, 0.4), Vector3.new(0.7, 0.3, -0.9), Color3.new(0, 0, 0), Enum.PartType.Ball)
rig.PrimaryPart = body
rig.Parent = workspace

-- Creature references.
local root: Part? = nil
local move: LinearVelocity? = nil
local turn: AlignOrientation? = nil
local tHello: number? = nil
local charAddedCount = 0

player.CharacterAdded:Connect(function(c)
	charAddedCount += 1
	local dt = tHello and (os.clock() - tHello) or -1
	local rootNow = c:FindFirstChild("Root") ~= nil
	local r = c:WaitForChild("Root", 5)
	root = r
	move = r and r:WaitForChild("Move", 5)
	turn = r and r:WaitForChild("Turn", 5)
	report("S1_client", {
		characterAdded = true,
		dtFromHello = dt,
		name = c.Name,
		className = c.ClassName,
		hasHumanoid = c:FindFirstChildOfClass("Humanoid") ~= nil,
		rootPresentWhenEventFired = rootNow,
		constraintsFound = move ~= nil and turn ~= nil,
		shellAtCharacterAdded = shellCount(),
		gameLoaded = game:IsLoaded(),
		persistentLoadedAfterScriptStart = persistentLoadedT or "not seen (fired before the script, or never)",
		early = early,
	})
end)

-- Movement ---------------------------------------------------------------------------------------
local swim = SwimModel.new()
local tier, scale = 1, 1.0
local bot: Vector3? = nil -- nil = keyboard; a vector = scripted SwimInput direction (zero = no throttle)
local hostile = false
local frame = 0
local keyFrames, inputBegan, keyDisp = 0, 0, 0
local lastPos: Vector3? = nil
local probes: { [string]: any } = {}
local camResets = 0

UIS.InputBegan:Connect(function(io)
	if io.UserInputType == Enum.UserInputType.Keyboard then
		inputBegan += 1
	end
end)

local function keyDir(): Vector3
	local cam = workspace.CurrentCamera
	local look = cam.CFrame.LookVector
	local fwd = Vector3.new(look.X, 0, look.Z)
	fwd = if fwd.Magnitude > 1e-3 then fwd.Unit else Vector3.new(0, 0, -1)
	local right = fwd:Cross(Vector3.yAxis)
	local d = Vector3.zero
	if UIS:IsKeyDown(Enum.KeyCode.W) then d += fwd end
	if UIS:IsKeyDown(Enum.KeyCode.S) then d -= fwd end
	if UIS:IsKeyDown(Enum.KeyCode.D) then d += right end
	if UIS:IsKeyDown(Enum.KeyCode.A) then d -= right end
	if UIS:IsKeyDown(Enum.KeyCode.Space) then d += Vector3.yAxis end
	if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then d -= Vector3.yAxis end
	return if d.Magnitude > 1e-3 then d.Unit else Vector3.zero
end

local armed, inputFrame, tInput = false, nil, nil

RunService:BindToRenderStep("SpikeSwim", Enum.RenderPriority.Input.Value + 1, function(dt)
	frame += 1
	if not (root and move and turn) then
		return
	end
	for _, p in probes do
		p(dt)
	end
	local d = bot or keyDir()
	local throttle = if d.Magnitude > 0 then 1 else 0
	if not bot and throttle > 0 then
		keyFrames += 1
		if lastPos then
			keyDisp += (root.Position - lastPos).Magnitude
		end
	end
	lastPos = root.Position
	if armed and throttle > 0 and not inputFrame then
		inputFrame = frame
		tInput = os.clock()
	end
	SwimModel.step(swim, { x = d.X, y = d.Y, z = d.Z, throttle = throttle }, tier, dt)
	move.VectorVelocity = Vector3.new(swim.vx, swim.vy, swim.vz)
	turn.CFrame = CFrame.lookAlong(Vector3.zero, Vector3.new(swim.hx, swim.hy, swim.hz))
	if hostile then
		root.CFrame = root.CFrame + Vector3.xAxis * 0.5
	end
end)

RunService:BindToRenderStep("SpikeCam", Enum.RenderPriority.Camera.Value, function()
	local cam = workspace.CurrentCamera
	if cam.CameraType ~= Enum.CameraType.Scriptable then
		camResets += 1
		cam.CameraType = Enum.CameraType.Scriptable
	end
	if not root then
		return
	end
	local h = Vector3.new(swim.hx, swim.hy, swim.hz)
	local pos = root.Position - h * (4 + 10 * scale) + Vector3.yAxis * (1 + 1.5 * scale)
	cam.CFrame = CFrame.lookAt(pos, root.Position + h * 4 * scale)
	cam.Focus = CFrame.new(root.Position)
	rig:PivotTo(CFrame.lookAlong(root.Position, h))
end)

-- S9 and S10 state, refreshed twice a second for the driver.
local function names(inst: Instance?): { string }
	local out = {}
	if inst then
		for _, c in inst:GetChildren() do
			table.insert(out, c.Name .. ":" .. c.ClassName .. ":" .. #c:GetDescendants())
		end
	end
	return out
end
task.spawn(function()
	while true do
		local cam = workspace.CurrentCamera
		local core = {}
		for _, t in Enum.CoreGuiType:GetEnumItems() do
			core[t.Name] = StarterGui:GetCoreGuiEnabled(t)
		end
		local inset = GuiService.TopbarInset
		local tl, br = GuiService:GetGuiInset()
		setState("S9", {
			cameraType = cam.CameraType.Name,
			cameraTypeSetByUs = camResets,
			keyFramesIsKeyDown = keyFrames,
			keyboardInputBegan = inputBegan,
			keyDisplacement = keyDisp,
			playerScripts = names(player:FindFirstChild("PlayerScripts")),
			playerGui = names(player:FindFirstChild("PlayerGui")),
			touchEnabled = UIS.TouchEnabled,
			charAddedCount = charAddedCount,
			frame = frame,
		})
		setState("S10", {
			setCoreGuiEnabledOk = coreOk,
			err = coreErr and tostring(coreErr) or nil,
			coreGuiEnabled = core,
			topbarInset = { inset.Min.X, inset.Min.Y, inset.Max.X, inset.Max.Y },
			guiInset = { tl.X, tl.Y, br.X, br.Y },
			viewport = { cam.ViewportSize.X, cam.ViewportSize.Y },
		})
		task.wait(0.5)
	end
end)

-- S2 / S18-lite -------------------------------------------------------------------------------
local function stats(dts: { number })
	table.sort(dts)
	local n = #dts
	local sum = 0
	for _, v in dts do
		sum += v
	end
	local function pct(p: number): number
		return dts[math.clamp(math.ceil(n * p), 1, n)] * 1000
	end
	return { n = n, meanMs = sum / n * 1000, p50Ms = pct(0.5), p95Ms = pct(0.95), p99Ms = pct(0.99), maxMs = dts[n] * 1000, fps = n / sum }
end

local function runS2(t: number, sc: number)
	local r = root :: Part
	local t0 = os.clock()
	while math.abs(r.Size.X - 2.0 * sc) > 0.01 and os.clock() - t0 < 3 do
		RunService.RenderStepped:Wait()
	end
	local sizeDelay = os.clock() - t0
	tier, scale = t, sc
	local scaleOk, scaleErr = pcall(function()
		local from = rig:GetScale()
		local a = 0
		while a < 1 do
			a = math.min(1, a + RunService.RenderStepped:Wait() / 0.15)
			rig:ScaleTo(from + (sc - from) * a)
		end
	end)
	bot = Vector3.zero
	swim.vx, swim.vy, swim.vz = 0, 0, 0
	r.CFrame = CFrame.new(-150, -60, -150)
	r.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.4)

	local target = Tiers[t].swimSpeed
	local dts = {}
	local maxSpeed, t90 = 0, nil
	local velFrame, posFrame = nil, nil
	local p0 = r.Position
	inputFrame, tInput = nil, nil
	probes.s2 = function(dt)
		table.insert(dts, dt)
		if inputFrame and not posFrame and (r.Position - p0).Magnitude > 1e-3 then
			posFrame = frame
		end
		local sp = r.AssemblyLinearVelocity.Magnitude
		maxSpeed = math.max(maxSpeed, sp)
		if tInput and not t90 and sp >= 0.9 * target then
			t90 = os.clock() - tInput
		end
	end
	local post = RunService.PostSimulation:Connect(function()
		if inputFrame and not velFrame and r.AssemblyLinearVelocity.Magnitude > 0.05 then
			velFrame = frame
		end
	end)
	armed = true
	bot = Vector3.xAxis
	task.wait(1.5)
	bot = Vector3.zAxis
	task.wait(1.5)
	local turnErr = math.deg(math.acos(math.clamp(r.CFrame.LookVector:Dot(Vector3.zAxis), -1, 1)))
	local speedCruise = r.AssemblyLinearVelocity.Magnitude
	bot = Vector3.new(1, 1, 0).Unit
	task.wait(1.0)
	local climbY = r.Position.Y
	bot = Vector3.zero
	task.wait(0.7)
	local stopSpeed = r.AssemblyLinearVelocity.Magnitude
	armed = false
	probes.s2 = nil
	post:Disconnect()
	-- the bursts below reuse inputFrame: keep the main pattern's latency first (run 2 of main reported it after them)
	local mainVelFrames = if velFrame and inputFrame then velFrame - inputFrame else "never"
	local mainPosFrames = if posFrame and inputFrame then posFrame - inputFrame else "never"
	-- Input-to-motion latency, repeated: from a root held still, frames until physics velocity and position respond.
	local bursts = {}
	local function burst(rest: number)
		bot = Vector3.zero
		swim.vx, swim.vy, swim.vz = 0, 0, 0
		r.AssemblyLinearVelocity = Vector3.zero
		task.wait(rest)
		local q0 = r.Position
		local restSpeed = r.AssemblyLinearVelocity.Magnitude
		local vF, pF = nil, nil
		inputFrame, tInput = nil, nil
		probes.burst = function()
			if inputFrame and not pF and (r.Position - q0).Magnitude > 1e-3 then
				pF = frame
			end
		end
		local c = RunService.PostSimulation:Connect(function()
			if inputFrame and not vF and r.AssemblyLinearVelocity.Magnitude > restSpeed + 0.05 then
				vF = frame
			end
		end)
		armed = true
		bot = Vector3.xAxis
		task.wait(0.25)
		armed = false
		c:Disconnect()
		probes.burst = nil
		table.insert(bursts, { rest = rest, restSpeed = restSpeed, vel = if vF and inputFrame then vF - inputFrame else -1, pos = if pF and inputFrame then pF - inputFrame else -1 })
	end
	for _ = 1, 4 do
		burst(0.3)
	end
	if t == 1 or t == 7 then
		burst(3.0)
	end
	bot = Vector3.zero
	local ext = rig:GetExtentsSize()
	report("S2_t" .. t, {
		tier = t,
		scale = sc,
		rootDiameter = r.Size.X,
		sizeReplicationDelay = sizeDelay,
		frame = stats(dts),
		inputFrame = inputFrame,
		physicsVelocityFramesAfterInput = mainVelFrames,
		positionChangedFramesAfterInput = mainPosFrames,
		targetSpeed = target,
		maxSpeed = maxSpeed,
		cruiseSpeed = speedCruise,
		timeTo90pct = t90 or "never",
		headingErrDegAfterTurn = turnErr,
		climbedTo = climbY,
		speedAfterStop07 = stopSpeed,
		rigScaleToOk = scaleOk,
		rigScaleToErr = scaleErr and tostring(scaleErr) or nil,
		rigScale = rig:GetScale(),
		rigExtents = { ext.X, ext.Y, ext.Z },
		bursts = bursts,
	})
end

-- S4 ---------------------------------------------------------------------------------------------
local s4Done = {}
local function s4Target(i: number): Vector3
	if i <= 5 then
		return Vector3.new(-200 + 30 * i, -40, 150)
	end
	return Vector3.new(-200 + 30 * (i - 5), -40, -150)
end
local function s4Check()
	local r = root
	if not r then
		return
	end
	for i = 1, 10 do
		if not s4Done[i] and (r.Position - s4Target(i)).Magnitude < 4 then
			s4Done[i] = true
			ev:FireServer("s4arrive", i, workspace:GetServerTimeNow())
		end
	end
end
local fight = nil

-- S5 ---------------------------------------------------------------------------------------------
local s5 = nil
local function s5Start()
	local r = root :: Part
	local t0 = os.clock()
	local rec = {
		pausedChanges = {},
		farCounts = {},
		arriveT = nil,
		firstFarPartT = nil,
		farFloorT = nil,
		movedWhilePaused = 0,
		anchoredWhilePaused = false,
		pausedFrames = 0,
		shellMin = shellCount(),
		reefAtStart = #workspace.Reef:GetChildren(),
		reefMin = #workspace.Reef:GetChildren(),
	}
	local marks = { 0, 0.1, 0.25, 0.5, 1, 2, 4 }
	local nextMark = 1
	local prev = r.Position
	local pauseStart: Vector3? = nil
	local pauseEnd: Vector3? = nil
	rec.maxSpeedWhilePaused = 0
	rec.displacementDuringPauseAfterArrive = "no paused frame after arrival"
	rec.conn = player:GetPropertyChangedSignal("GameplayPaused"):Connect(function()
		table.insert(rec.pausedChanges, { t = os.clock() - t0, paused = player.GameplayPaused })
	end)
	probes.s5 = function()
		local now = os.clock() - t0
		local far = workspace:FindFirstChild("FarReef")
		local n = far and #far:GetChildren() or 0
		if not rec.arriveT and r.Position.X > 3000 then
			rec.arriveT = now
		end
		if n > 0 and not rec.firstFarPartT then
			rec.firstFarPartT = now
		end
		if far and far:FindFirstChild("Floor") and not rec.farFloorT then
			rec.farFloorT = now
		end
		if rec.arriveT then
			while nextMark <= #marks and now - rec.arriveT >= marks[nextMark] do
				table.insert(rec.farCounts, { afterArrive = marks[nextMark], farParts = n })
				nextMark += 1
			end
		end
		if player.GameplayPaused and rec.arriveT then
			pauseStart = pauseStart or r.Position
			pauseEnd = r.Position
			rec.maxSpeedWhilePaused = math.max(rec.maxSpeedWhilePaused, r.AssemblyLinearVelocity.Magnitude)
			rec.displacementDuringPauseAfterArrive = ((pauseEnd :: Vector3) - (pauseStart :: Vector3)).Magnitude
		end
		if player.GameplayPaused then
			rec.pausedFrames += 1
			rec.movedWhilePaused += (r.Position - prev).Magnitude
			rec.anchoredWhilePaused = rec.anchoredWhilePaused or r.Anchored
		end
		prev = r.Position
		rec.shellMin = math.min(rec.shellMin, shellCount())
		rec.reefMin = math.min(rec.reefMin, #workspace.Reef:GetChildren())
	end
	bot = Vector3.xAxis
	s5 = rec
end
local function s5Stop()
	local rec = s5
	if not rec then
		return
	end
	bot = Vector3.zero
	probes.s5 = nil
	rec.conn:Disconnect()
	rec.conn = nil
	rec.finalX = (root :: Part).Position.X
	rec.pausedAtEnd = player.GameplayPaused
	report("S5_client", rec)
	s5 = nil
end

-- S16 --------------------------------------------------------------------------------------------
local function s16()
	local r = root :: Part
	local part = workspace:FindFirstChild("BubblePart")
	if not part then
		part = Instance.new("Part")
		part.Name = "BubblePart"
		part.Anchored = true
		part.CanCollide = false
		part.Size = Vector3.new(3, 3, 3)
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(80, 255, 200)
		part.Parent = workspace
	end
	local h = Vector3.new(swim.hx, swim.hy, swim.hz)
	part.Position = r.Position + h * (8 + 6 * scale)
	local fired = false
	local conn
	pcall(function()
		conn = TextChatService.BubbleDisplayed:Connect(function()
			fired = true
		end)
	end)
	local ok, err = pcall(function()
		TextChatService:DisplayBubble(part, "GULP bubble S16")
	end)
	task.wait(0.6)
	if conn then
		conn:Disconnect()
	end
	local cfg = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
	report("S16_client", {
		callOk = ok,
		err = err and tostring(err) or nil,
		bubbleDisplayedEvent = fired,
		chatVersion = TextChatService.ChatVersion.Name,
		bubbleConfigEnabled = cfg and cfg.Enabled,
		chatCoreGuiEnabled = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Chat),
		partClass = part.ClassName,
	})
end
cmd.Event:Connect(function(what)
	if what == "s16" then
		s16()
	end
end)

-- Server-driven steps ------------------------------------------------------------------------------
RunService.Heartbeat:Connect(s4Check)
ev.OnClientEvent:Connect(function(kind, a, b)
	if kind == "s14" then
		local rows = {}
		for _ = 1, 5 do
			local c0 = workspace:GetServerTimeNow()
			local st, unix, ost = fn:InvokeServer("time")
			local c1 = workspace:GetServerTimeNow()
			table.insert(rows, {
				clientMinusServer = (c0 + c1) / 2 - st,
				rtt = c1 - c0,
				clientServerTimeNowMinusServerOsTime = (c0 + c1) / 2 - ost,
				clientDateTimeMinusClientServerTimeNow = DateTime.now().UnixTimestampMillis / 1000 - c1,
				serverDateTimeMinusServerTimeNow = unix - st,
			})
			task.wait(0.2)
		end
		report("S14_client", { secondsSinceScriptStart = os.clock() - tStart, samples = rows })
	elseif kind == "s2" then
		runS2(a, b)
	elseif kind == "s4mode" then
		local r = root :: Part
		if tier ~= 1 then -- S4 and S5 run at tier 1 again
			tier, scale = 1, 1.0
			pcall(function()
				rig:ScaleTo(1)
			end)
		end
		if fight and a ~= "fight" then
			hostile = false
			probes.fight = nil
			report("S4_fightClient", { localMaxDisplacement = fight.maxDisp, clientSawAnchored = fight.sawAnchored, frames = fight.frames })
			fight = nil
		end
		if a == "idle" then
			bot = Vector3.zero
		elseif a == "swim" then
			bot = Vector3.zAxis
		elseif a == "fight" then
			bot = Vector3.xAxis
			task.delay(0.9, function() -- start the hostile CFrame writes once the server has frozen the root
				local start = r.Position
				fight = { maxDisp = 0, sawAnchored = false, frames = 0 }
				hostile = true
				probes.fight = function()
					if fight then
						fight.frames += 1
						fight.maxDisp = math.max(fight.maxDisp, (r.Position - start).Magnitude)
						fight.sawAnchored = fight.sawAnchored or r.Anchored
					end
				end
			end)
		end
	elseif kind == "where" then
		local r = root :: Part
		report("S4_where", { distFromSpawn = (r.Position - SPAWN).Magnitude, anchored = r.Anchored })
	elseif kind == "s5far" then
		s5Start()
	elseif kind == "s5back" then
		s5Stop()
	end
end)

RunService.RenderStepped:Connect(s4Check)

-- Say hello only now that CharacterAdded is connected: the server assigns the creature on hello (ClientReady).
tHello = os.clock()
ev:FireServer("hello")
