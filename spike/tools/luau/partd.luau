-- Spike part D test phases (Studio Client, through execute_luau). drive_d.py prepends clip.luau and artc.luau
-- (for M.makeRig, cam, stage) and ARGS, then appends `return D.<phase>(ARGS)`. Every phase returns JSON.
local D = {}
local Stats = game:GetService("Stats")
local CP = game:GetService("ContentProvider")
local KFS_ID = "rbxassetid://135392356967319" -- A_Fish_Swim, Blender clip -> KeyframeSequence (anim_kfs.py)
local WHITE = "rbxassetid://90248245390211"
local RIGPOS = STAGE + Vector3.new(0, 0, -200)

local function waitFrames(n) for _ = 1, n do Run.PreRender:Wait() end end
local function rigParts()
	local m = stage():FindFirstChild("D_Anim")
	return m, m and m:FindFirstChild("RootPart")
end

-- S0-A2/S8: the real Blender clip on a client-made rig; bone positions at 3 frames; overlay B clone for S0-A4
function D.anim(args)
	local m, root, an, track = M.makeRig(CFrame.new(RIGPOS), "D_Anim", { animId = KFS_ID })
	local len = M.loadClip(track)
	local out = { length = len, looped = track.Looped, priority = tostring(track.Priority), name = track.Name }
	local b = bones(root)
	-- plays: Spine4 / TailFin rotation range over 1 s at speed 1
	local mx = { Spine4 = 0, TailFin = 0, Jaw = 0 }
	local t0 = os.clock()
	while os.clock() - t0 < 1 do
		Run.PreRender:Wait()
		for n in mx do if b[n] then mx[n] = math.max(mx[n], angle(b[n].Transform)) end end
	end
	out.playingMaxRad = mx
	out.isPlaying = track.IsPlaying
	-- the imported bones only (code-made sockets excluded)
	local frames = {}
	track:AdjustSpeed(0)
	for _, f in args.frames or { 3, 7, 12 } do
		track.TimePosition = f / 30
		waitFrames(3)
		local t = {}
		for n, bone in b do
			if not n:find("^Sock_") then
				local p = root.CFrame:PointToObjectSpace(bone.TransformedWorldCFrame.Position)
				t[n] = { p.X, p.Y, p.Z }
			end
		end
		frames[tostring(f)] = t
	end
	out.frames = frames
	-- overlay option B: a 1.005x clone of the skinned body on the same skeleton; both made flat white for masks
	local body = m.M_Species_Base_Fish
	local o = body:Clone()
	for _, c in o:GetChildren() do c:Destroy() end
	o.Name = "Overlay" o.Size = body.Size * 1.005 o.Parent = m
	for _, p in { body, o } do p.Material = Enum.Material.Neon p.Color = Color3.new(1, 1, 1) end
	for _, n in { "M_Species_Base_Fish_Shell", "M_Species_Base_Fish_Crest", "M_Species_Base_Fish_LOD1" } do
		local p = m:FindFirstChild(n) if p then p.Transparency = 1 end
	end
	out.overlaySkinned = o.HasSkinnedMesh
	local plate = Instance.new("Part")
	plate.Name = "DPlate" plate.Anchored = true plate.CanCollide = false plate.CastShadow = false
	plate.Size = Vector3.new(60, 1, 60) plate.Color = Color3.new(0, 0, 0) plate.Material = Enum.Material.Neon
	plate.CFrame = CFrame.new(RIGPOS - Vector3.new(0, 8, 0)) plate.Parent = stage()
	return J(out)
end

-- set the paused clip to frame f and show only the body or only the overlay, top-down camera
function D.pose(args)
	local m, root = rigParts()
	local an = m.AnimationController.Animator
	local track = an:GetPlayingAnimationTracks()[1]
	track:AdjustSpeed(0)
	track.TimePosition = args.f / 30
	m.M_Species_Base_Fish.Transparency = args.show == "body" and 0 or 1
	m.Overlay.Transparency = args.show == "overlay" and 0 or 1
	cam(CFrame.lookAt(root.Position + Vector3.new(0, 14, 0), root.Position, Vector3.new(0, 0, -1)), 20)
	waitFrames(4)
	return J({ f = args.f, show = args.show, t = track.TimePosition })
end

-- S0-A5: visibility of white 8-stud balls (clear lane, under a water ceiling) for one 06 10.2 preset
local PRESETS = {
	nursery = { 2.2, "#8FD3D6", "#B8ECEC", "#FFF3C4", 0.10, 0.32, 0.10, 2.0, 0.4, "#4CCFD2", "#BFF5E8" },
	reef = { 2.0, "#6FB6D9", "#9ED8F0", "#FFF0B8", 0.00, 0.36, 0.10, 2.2, 0.3, "#1E9FD0", "#7FE0E8" },
	kelp = { 1.4, "#4F9E88", "#7CCBA8", "#E6FFB0", -0.10, 0.45, 0.05, 2.6, 0.2, "#238A72", "#A6E08A" },
	dropUpper = { 1.2, "#3F6FB8", "#5C93D9", "#BFE3FF", -0.20, 0.42, 0.05, 2.4, 0.1, "#1B6FBF", "#3FA3E0" },
	dropDeep = { 0.6, "#2F4A8C", "#3A5FA8", "#8FB8FF", -0.40, 0.52, 0.00, 2.8, 0.0, "#0B2A66", "#1B4FA0" },
	cove = { 1.0, "#7A8FB0", "#A8C4D9", "#FFD9A0", 0.10, 0.25, 0.10, 1.2, 0.0, "#3E8FA8", "#FFD9A0" },
	trench = { 0.3, "#30408A", "#3A4FA0", "#6F7FFF", -0.50, 0.58, 0.00, 3.0, 0.0, "#060F33", "#1A0F45" },
}
local DISTS = { 60, 100, 150, 200, 220, 260, 320, 400, 450, 600 }
local ORIGIN = STAGE + Vector3.new(0, -60, 600)

local function visScene()
	local f = workspace:FindFirstChild("PartDVis")
	if f then return f end
	f = Instance.new("Folder") f.Name = "PartDVis" f.Parent = workspace
	local function part(sz, cf, col, shape)
		local p = Instance.new("Part") p.Anchored = true p.CanCollide = false p.Size = sz p.CFrame = cf p.Color = col
		p.Material = Enum.Material.SmoothPlastic if shape then p.Shape = shape end p.Parent = f return p
	end
	part(Vector3.new(1400, 2, 1400), CFrame.new(ORIGIN + Vector3.new(0, -1, -500)), Color3.fromHex("#E8D7A8")).Name = "Floor"
	local ceil = part(Vector3.new(2400, 2, 2400), CFrame.new(ORIGIN + Vector3.new(0, 70, -500)), Color3.fromHex("#6FD6E0"))
	ceil.Name = "WaterCeiling" ceil.Transparency = 0.35 ceil.CastShadow = false
	local rng = Random.new(7)
	for i = 1, 160 do
		local p = ORIGIN + Vector3.new(rng:NextNumber(-300, 300), 0, -rng:NextNumber(10, 900))
		if math.abs(p.X - ORIGIN.X) > 30 + 0.15 * math.abs(p.Z - ORIGIN.Z) then
			part(Vector3.new(1, 1, 1) * rng:NextNumber(4, 16), CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6), 0.3), Color3.fromHex(i % 3 == 0 and "#FF8A6B" or (i % 3 == 1 and "#7FD8BE" or "#B9A27A")), i % 2 == 0 and Enum.PartType.Ball or nil)
		end
	end
	for i, d in DISTS do
		local x = (i % 2 == 0 and 1 or -1) * (6 + d * 0.08)
		local b = part(Vector3.new(8, 8, 8), CFrame.new(ORIGIN + Vector3.new(x, 14, -d)), Color3.new(1, 1, 1), Enum.PartType.Ball)
		b.Name = "Ball" .. d b.CastShadow = false
	end
	return f
end

local function preset(name, fog)
	local p = PRESETS[name]
	Lighting.Brightness = p[1] Lighting.Ambient = Color3.fromHex(p[2]) Lighting.OutdoorAmbient = Color3.fromHex(p[3])
	Lighting.ColorShift_Top = Color3.fromHex(p[4]) Lighting.ExposureCompensation = p[5] Lighting.ClockTime = 13
	local cc = Lighting:FindFirstChild("DCC") or Instance.new("ColorCorrectionEffect", Lighting) cc.Name = "DCC"
	cc.Brightness, cc.Contrast, cc.Saturation = 0.02, 0.08, 0.12
	local bl = Lighting:FindFirstChild("DBloom") or Instance.new("BloomEffect", Lighting) bl.Name = "DBloom"
	bl.Intensity, bl.Size, bl.Threshold = 0.6, 24, 0.95
	for _, a in Lighting:GetChildren() do if a:IsA("Atmosphere") then a:Destroy() end end
	if fog then
		Lighting.FogColor = Color3.fromHex(p[10]) Lighting.FogStart = fog * 0.25 Lighting.FogEnd = fog
	else
		local atm = Instance.new("Atmosphere")
		atm.Density, atm.Offset, atm.Haze, atm.Glare = p[6], p[7], p[8], p[9]
		atm.Color, atm.Decay = Color3.fromHex(p[10]), Color3.fromHex(p[11])
		atm.Parent = Lighting
		Lighting.FogEnd = 100000 Lighting.FogStart = 0
		return atm
	end
end

function D.vis(args)
	visScene()
	local atm = preset(args.preset, args.fog)
	if atm and args.density then atm.Density = args.density end
	local c = workspace.CurrentCamera
	cam(CFrame.lookAt(ORIGIN + Vector3.new(0, 14, 0), ORIGIN + Vector3.new(0, 14, -100)), 70)
	task.wait(1.2)
	local balls = {}
	for _, d in DISTS do
		local b = workspace.PartDVis["Ball" .. d]
		local v, on = c:WorldToViewportPoint(b.Position)
		local e = c:WorldToViewportPoint(b.Position + c.CFrame.RightVector * 4)
		balls[tostring(d)] = { v.X, v.Y, math.abs(e.X - v.X), on }
	end
	return J({ preset = args.preset, fog = args.fog, density = atm and atm.Density, vp = { c.ViewportSize.X, c.ViewportSize.Y }, balls = balls })
end

-- S0-A5 cost: light-shaft beams and 16 swapped caustic frames, frame time with Studio in front
local STATS = { "RenderCPUFrameTime", "RenderGPUFrameTime", "FrameTime", "HeartbeatTimeMs", "RenderStepTimeMs" }
local function measure(n, onFrame)
	local dts, st = {}, {}
	for _, k in STATS do st[k] = {} end
	for i = 1, n do
		local dt = Run.RenderStepped:Wait()
		if onFrame then onFrame(i) end
		table.insert(dts, dt)
		for _, k in STATS do local ok, v = pcall(function() return Stats[k] end) if ok and type(v) == "number" then table.insert(st[k], v) end end
	end
	table.sort(dts)
	local sum = 0 for _, v in dts do sum += v end
	local o = { meanMs = sum / n * 1000, p99 = dts[math.ceil(n * 0.99)] * 1000, max = dts[n] * 1000 }
	for k, a in st do
		if #a > 0 then table.sort(a) local s = 0 for _, v in a do s += v end o[k] = { mean = s / #a, p99 = a[math.ceil(#a * 0.99)] } end
	end
	return o
end

function D.cost(args)
	visScene()
	preset("nursery")
	cam(CFrame.lookAt(ORIGIN + Vector3.new(0, 14, 0), ORIGIN + Vector3.new(0, 14, -100)), 70)
	task.wait(1)
	local out = {}
	local N = args.frames or 300
	out.base = measure(N)
	-- light shafts: textured, additive, camera-facing beams from the water ceiling to the floor
	local bf = Instance.new("Folder") bf.Name = "DBeams" bf.Parent = workspace
	local anchor = Instance.new("Part") anchor.Anchored = true anchor.CanCollide = false anchor.Transparency = 1 anchor.CFrame = CFrame.new(ORIGIN) anchor.Parent = bf
	local rng = Random.new(3)
	local function addBeams(n)
		for _ = 1, n do
			local x, z = rng:NextNumber(-120, 120), -rng:NextNumber(20, 400)
			local a0 = Instance.new("Attachment") a0.Position = Vector3.new(x, 68, z) a0.Parent = anchor
			local a1 = Instance.new("Attachment") a1.Position = Vector3.new(x + 12, 0, z - 6) a1.Parent = anchor
			local b = Instance.new("Beam")
			b.Attachment0, b.Attachment1 = a0, a1
			b.Texture = WHITE b.TextureMode = Enum.TextureMode.Stretch
			b.Width0, b.Width1 = 14, 26 b.LightEmission = 1 b.LightInfluence = 0 b.FaceCamera = true b.Segments = 1
			b.Color = ColorSequence.new(Color3.fromHex("#DFFFF8"))
			b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
			b.Parent = anchor
		end
	end
	addBeams(24) task.wait(0.5) out.beams24 = measure(N)
	addBeams(72) task.wait(0.5) out.beams96 = measure(N)
	bf:Destroy()
	-- caustics: one Texture on the floor's top face, its image swapped through 16 uploaded frames
	local ids = args.caustics or {}
	local tex = Instance.new("Texture") tex.Face = Enum.NormalId.Top tex.StudsPerTileU, tex.StudsPerTileV = 48, 48
	tex.Transparency = 0.35 tex.Parent = workspace.PartDVis.Floor
	local status = {}
	local probes = {}
	for _, id in ids do local d = Instance.new("Decal") d.Texture = id table.insert(probes, d) end
	local tp = os.clock()
	pcall(function() CP:PreloadAsync(probes, function(id, st) status[tostring(st)] = (status[tostring(st)] or 0) + 1 end) end)
	out.preload = { status = status, seconds = os.clock() - tp }
	local swaps, swapT = 0, 0
	local function swapEvery(k)
		return function(i)
			if #ids > 0 and i % k == 0 then
				local t = os.clock() tex.Texture = ids[(i // k) % #ids + 1] swapT += os.clock() - t swaps += 1
			end
		end
	end
	tex.Texture = ids[1] or WHITE task.wait(0.5)
	out.caustic16_static = measure(N)
	out.caustic16_20fps = measure(N, swapEvery(3))
	out.caustic16_60fps = measure(N, swapEvery(1))
	out.swapUs = swaps > 0 and swapT / swaps * 1e6 or nil
	-- the same through 16 EditableImages (frames made on the client, no asset review)
	local imgs = {}
	local okE, errE = pcall(function()
		local S = 128
		for f = 0, 15 do
			local img = AS:CreateEditableImage({ Size = Vector2.new(S, S) })
			local b = buffer.create(S * S * 4)
			local ph = f / 16 * 2 * math.pi
			for y = 0, S - 1 do for x = 0, S - 1 do
				local u, v = x / S * 2 * math.pi, y / S * 2 * math.pi
				local s = math.sin(3 * u + ph + 0.8 * math.sin(2 * v - ph)) + math.sin(2 * v - 2 * u + 2 * ph) + math.sin(u + 3 * v + ph)
				local a = math.clamp(1 - math.abs(s) / 1.2, 0, 1) ^ 3
				local o = (y * S + x) * 4
				buffer.writeu8(b, o, 255) buffer.writeu8(b, o + 1, 255) buffer.writeu8(b, o + 2, 240) buffer.writeu8(b, o + 3, math.floor(a * 255))
			end end
			img:WritePixelsBuffer(Vector2.zero, Vector2.new(S, S), b)
			imgs[f + 1] = Content.fromObject(img)
		end
	end)
	out.editable = okE and "ok" or tostring(errE)
	if okE then
		local k = 0
		out.editable16_20fps = measure(N, function(i) if i % 3 == 0 then k += 1 tex.TextureContent = imgs[k % 16 + 1] end end)
	end
	tex:Destroy()
	return J(out)
end


-- S0-A4 B follow-up: which overlay clones follow the skeleton? (template-time clone vs late clone, resized or not)
function D.ov2setup(args)
	local tpl = RS.ArtC.Rig
	if not tpl:FindFirstChild("Overlay_T") then
		local o = tpl.M_Species_Base_Fish:Clone() o.Name = "Overlay_T" o.Size = o.Size * 1.005 o.Parent = tpl
	end
	local pos = RIGPOS + Vector3.new(30, 0, 0)
	local m, root, an, track = M.makeRig(CFrame.new(pos), "D_Ov", { animId = KFS_ID })
	M.loadClip(track)
	task.wait(0.5)
	local body = m.M_Species_Base_Fish
	local l = body:Clone() for _, c in l:GetChildren() do c:Destroy() end l.Name = "Overlay_L" l.Parent = m
	local ls = body:Clone() for _, c in ls:GetChildren() do c:Destroy() end ls.Name = "Overlay_LS" ls.Size = body.Size * 1.005 ls.Parent = m
	local out = {}
	for _, n in { "M_Species_Base_Fish", "Overlay_T", "Overlay_L", "Overlay_LS", "M_Species_Base_Fish_Shell" } do
		local p = m[n] p.Material = Enum.Material.Neon p.Color = Color3.new(1, 1, 1) p.DoubleSided = true
		out[n] = p.HasSkinnedMesh
	end
	for _, n in { "M_Species_Base_Fish_Crest", "M_Species_Base_Fish_LOD1" } do m[n].Transparency = 1 end
	local plate = Instance.new("Part") plate.Anchored = true plate.CanCollide = false plate.CastShadow = false
	plate.Size = Vector3.new(60, 1, 60) plate.Color = Color3.new(0, 0, 0) plate.Material = Enum.Material.Neon
	plate.CFrame = CFrame.new(pos - Vector3.new(0, 8, 0)) plate.Parent = stage()
	track:AdjustSpeed(0) track.TimePosition = (args.f or 7) / 30
	return J(out)
end

function D.ov2show(args)
	local m = stage().D_Ov
	for _, n in { "M_Species_Base_Fish", "Overlay_T", "Overlay_L", "Overlay_LS", "M_Species_Base_Fish_Shell" } do
		m[n].Transparency = n == args.show and 0 or 1
	end
	local root = m.RootPart
	cam(CFrame.lookAt(root.Position + Vector3.new(0, 14, 0), root.Position, Vector3.new(0, 0, -1)), 20)
	waitFrames(6)
	return J({ show = args.show })
end

function D.cleanup(args)
	pcall(function() Run:UnbindFromRenderStep("ArtCCam") end)
	for _, n in { "PartDVis", "DBeams", "ArtCStage" } do local f = workspace:FindFirstChild(n) if f then f:Destroy() end end
	return J({ ok = true })
end
