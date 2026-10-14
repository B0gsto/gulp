-- Spike part C test module (Studio, through execute_luau). drive_c.py prepends `local buildClip = ...` and ARGS,
-- then appends `return M.<phase>(ARGS)`. Every phase returns a JSON string.
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local HS = game:GetService("HttpService")
local AS = game:GetService("AssetService")
local Lighting = game:GetService("Lighting")
local M = {}
local ANIM_ID = "rbxassetid://70745358657372"
local STAGE = Vector3.new(0, 300, 0)

local function J(t) return HS:JSONEncode(t) end
local function stage()
	local f = workspace:FindFirstChild("ArtCStage")
	if not f then f = Instance.new("Folder") f.Name = "ArtCStage" f.Parent = workspace end
	return f
end
local function cam(cf, fov)
	local c = workspace.CurrentCamera
	pcall(function() Run:UnbindFromRenderStep("ArtCCam") end)
	Run:BindToRenderStep("ArtCCam", Enum.RenderPriority.Last.Value + 10, function()
		c.CameraType = Enum.CameraType.Scriptable
		c.CFrame = cf
		c.FieldOfView = fov or 40
	end)
	task.wait(0.3)
end
local function label(part, text)
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromOffset(150, 22) g.StudsOffsetWorldSpace = Vector3.new(0, 1.3, 0) g.AlwaysOnTop = true
	local t = Instance.new("TextLabel") t.Size = UDim2.fromScale(1, 1) t.BackgroundTransparency = 1
	t.TextColor3 = Color3.new(1, 1, 1) t.TextStrokeTransparency = 0 t.TextScaled = true t.Text = text t.Parent = g
	g.Adornee = part g.Parent = part
end
local function angle(cf) local _, a = cf:ToAxisAngle() return math.abs(a) end
local function bones(root)
	local t = {}
	for _, d in root:GetDescendants() do if d:IsA("Bone") then t[d.Name] = d end end
	return t
end
local function bandsImage(alphaBg)
	local N = 256
	local img = AS:CreateEditableImage({ Size = Vector2.new(N, N) })
	local b = buffer.create(N * N * 4)
	for y = 0, N - 1 do for x = 0, N - 1 do
		local o = (y * N + x) * 4
		local band = (y // 24) % 2 == 0
		if band then buffer.writeu8(b, o, 20) buffer.writeu8(b, o + 1, 40) buffer.writeu8(b, o + 2, 120) buffer.writeu8(b, o + 3, 255)
		else buffer.writeu8(b, o, 255) buffer.writeu8(b, o + 1, 255) buffer.writeu8(b, o + 2, 255) buffer.writeu8(b, o + 3, alphaBg and 0 or 255) end
	end end
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(N, N), b)
	return img
end

-- A client-made rig: a clone of the uploaded RigTest model (body, LOD1, shell, crest; one skeleton under RootPart).
function M.makeRig(cf, name, opts)
	opts = opts or {}
	local m = RS.ArtC.Rig:Clone()
	m.Name = name
	local root = m:FindFirstChild("RootPart")
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then p.CanCollide = false p.CanTouch = false p.CanQuery = false p.Anchored = false p.Massless = true end
	end
	root.Anchored = true root.Transparency = 1
	m.PrimaryPart = root
	m.M_Species_Base_Fish_LOD1.Transparency = 1
	m:PivotTo(cf)
	local ac = m:FindFirstChildOfClass("AnimationController")
	local an = ac:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	an.Parent = ac
	m.Parent = stage()
	-- Sockets: the importer drops the 10 weightless socket bones, so code makes them (Sock_Crest at the crest piece).
	local b = bones(root)
	local crest = m.M_Species_Base_Fish_Crest
	local best, bd = nil, math.huge
	for n, bone in b do
		if not (n:find("Girth") or n:find("Eye") or n:find("Lid") or n == "Jaw") then
			local d = (bone.WorldPosition - crest.Position).Magnitude
			if d < bd then best, bd = bone, d end
		end
	end
	local socks = { "Sock_Crest", "Sock_Back_01", "Sock_Back_02", "Sock_Back_03", "Sock_Flank_L", "Sock_Flank_R", "Sock_Head", "Sock_Tail", "Sock_FinDorsal", "Sock_FinTail" }
	for i, sn in socks do
		local s = Instance.new("Bone")
		s.Name = sn
		s.Parent = (i == 1) and best or (b.Spine2 or best)
		s.WorldCFrame = (i == 1) and crest.CFrame or (b.Spine2.WorldCFrame * CFrame.new(0, 0.4, 0))
	end
	local sock = best:FindFirstChild("Sock_Crest")
	local mot = crest:FindFirstChildOfClass("Motor6D")
	if mot then mot:Destroy() end
	local a1 = Instance.new("Attachment") a1.Parent = crest
	if opts.crestMode == "code" then
		crest.Anchored = true
	else
		local rc = Instance.new("RigidConstraint") rc.Attachment0 = sock rc.Attachment1 = a1 rc.Parent = crest
	end
	local track
	local anim = Instance.new("Animation") anim.AnimationId = opts.animId or ANIM_ID
	track = an:LoadAnimation(anim)
	track:Play(0)
	return m, root, an, track, sock, crest, best
end

function M.loadClip(track)
	local t0 = os.clock()
	while track.Length == 0 and os.clock() - t0 < 5 do task.wait(0.1) end
	return track.Length
end

-- ------------------------------------------------------------------------------------------------ phases
function M.cube(args)
	local c = RS.ArtC.Cube:Clone()
	c.Parent = stage()
	c:PivotTo(CFrame.new(STAGE + Vector3.new(-30, 0, 0)))
	local p = c:FindFirstChildWhichIsA("MeshPart")
	label(p, "S0-A1 cube")
	-- 3/4 view from the cube's Front (-Z) and its left (-X)
	local target = p.Position
	cam(CFrame.lookAt(target + Vector3.new(-7, 4, -9), target), 40)
	return J({ size = tostring(p.Size), pos = tostring(p.Position - (STAGE + Vector3.new(-30, 0, 0))), color = tostring(p.Color), orient = tostring(p.Orientation) })
end

function M.rigs(args)
	local out = { variants = {} }
	local base = STAGE + Vector3.new(0, 0, 0)
	-- eight rigs, side view (fish forward = -Z, camera on +X)
	local names = { "plain", "noShell", "spread+jaw", "SA white+rough", "SA+emissive", "A decal", "B shell", "C composite" }
	local rigs = {}
	for i, n in names do
		local col, row = (i - 1) % 4, (i - 1) // 4
		local cf = CFrame.new(base + Vector3.new(0, 1.6 - row * 2.6, -6 + col * 4))
		local m, root, an, track, sock, crest, best = M.makeRig(cf, "Rig_" .. n, {})
		rigs[n] = { m = m, root = root, track = track, sock = sock, crest = crest, b = bones(root) }
		label(m.M_Species_Base_Fish, n)
	end
	out.clipLength = M.loadClip(rigs.plain.track)
	out.trackPlaying = rigs.plain.track.IsPlaying
	out.boneCount = #(function() local t = {} for _, d in rigs.plain.root:GetDescendants() do if d:IsA("Bone") then table.insert(t, d) end end return t end)()
	out.importedBones = out.boneCount - 10
	out.socketParent = rigs.plain.sock.Parent.Name
	out.shellDoubleSided = rigs.plain.m.M_Species_Base_Fish_Shell.DoubleSided
	out.shellColor = tostring(rigs.plain.m.M_Species_Base_Fish_Shell.Color)
	rigs.noShell.m.M_Species_Base_Fish_Shell.Transparency = 1
	-- S0-A3: SurfaceAppearance (white colour map, flat roughness 1.0, metal 0)
	local WHITE, ROUGH, METAL, EMIS = "rbxassetid://90248245390211", "rbxassetid://90248245390211", "rbxassetid://138878327518024", "rbxassetid://133030237967373"
	local sa = {}
	for _, n in { "SA white+rough", "SA+emissive" } do
		local s = Instance.new("SurfaceAppearance")
		sa[n] = {}
		for prop, v in { ColorMapContent = Content.fromUri(WHITE), RoughnessMapContent = Content.fromUri(ROUGH), MetalnessMapContent = Content.fromUri(METAL) } do
			local ok, e = pcall(function() s[prop] = v end) sa[n][prop] = ok or tostring(e)
		end
		if n == "SA+emissive" then
			for prop, v in { EmissiveMaskContent = Content.fromUri(EMIS), EmissiveStrength = 3, EmissiveTint = Color3.fromRGB(255, 226, 168) } do
				local ok, e = pcall(function() s[prop] = v end) sa[n][prop] = ok or tostring(e)
			end
		end
		s.Parent = rigs[n].m.M_Species_Base_Fish
	end
	out.sa = sa
	-- S0-A4 overlays
	local bandsA = bandsImage(true)
	local A = {}
	A.ok, A.err = pcall(function()
		local d = Instance.new("Decal") d.Face = Enum.NormalId.Right d.TextureContent = Content.fromObject(bandsA)
		d.Parent = rigs["A decal"].m.M_Species_Base_Fish
		local s = Instance.new("SurfaceAppearance") s.ColorMapContent = Content.fromUri(WHITE) s.Parent = rigs["A decal"].m.M_Species_Base_Fish
	end)
	out.overlayA = { ok = A.ok, err = A.err and tostring(A.err) }
	local B = {}
	B.ok, B.err = pcall(function()
		local body = rigs["B shell"].m.M_Species_Base_Fish
		local o = body:Clone()
		for _, c in o:GetChildren() do if not c:IsA("SurfaceAppearance") then c:Destroy() end end
		o.Name = "Overlay" o.Size = body.Size * 1.005
		local s = Instance.new("SurfaceAppearance") s.AlphaMode = Enum.AlphaMode.Transparency
		s.ColorMapContent = Content.fromObject(bandsA) s.Parent = o
		o.CFrame = body.CFrame
		local w = Instance.new("Motor6D") w.Part0 = rigs["B shell"].root w.Part1 = o w.C0 = rigs["B shell"].root.CFrame:ToObjectSpace(body.CFrame) w.Parent = o
		o.Parent = rigs["B shell"].m
	end)
	out.overlayB = { ok = B.ok, err = B.err and tostring(B.err) }
	local C = {}
	C.ok, C.err = pcall(function()
		local img = bandsImage(false)
		local s = Instance.new("SurfaceAppearance") s.ColorMapContent = Content.fromObject(img) s.Parent = rigs["C composite"].m.M_Species_Base_Fish
	end)
	out.overlayC = { ok = C.ok, err = C.err and tostring(C.err) }
	-- S0-A2: code writes Bone.Transform beside the playing clip
	local r = rigs["spread+jaw"]
	local res = { preAnimN = 0, n = 0, jawAtPreAnim = 0, jawAfterAnim = 0, jawWritten = 0, girthL = 0 }
	local spread = 0.3
	local c1 = Run.PreAnimation:Connect(function()
		res.preAnimN += 1
		res.jawAtPreAnim = math.max(res.jawAtPreAnim, angle(r.b.Jaw.Transform))
		r.b.Spine3.Transform = CFrame.Angles(0, 0, 0.9) -- written before the Animator steps; the clip also animates Spine3
	end)
	local post = {}
	local c2 = Run.PreRender:Connect(function()
		res.n += 1
		res.jawAfterAnim = math.max(res.jawAfterAnim, angle(r.b.Jaw.Transform))
		table.insert(post, angle(r.b.Spine3.Transform))
		-- written after the Animator: Jaw (not in the clip), Spine3 (in the clip), the four Girth bones (spread)
		r.b.Jaw.Transform = CFrame.Angles(0.6, 0, 0)
		r.b.Spine3.Transform = CFrame.Angles(0, 0, 0.5)
		for _, g in { "Girth_L", "Girth_R", "Girth_Top", "Girth_Bot" } do
			local bn = r.b[g]
			bn.Transform = CFrame.new(bn.CFrame:VectorToObjectSpace(bn.CFrame.Position * spread))
		end
		res.jawWritten = angle(r.b.Jaw.CFrame:Inverse() * r.b.Jaw.TransformedCFrame)
		res.spine3Written = angle(r.b.Spine3.CFrame:Inverse() * r.b.Spine3.TransformedCFrame)
		res.girthL = (r.b.Girth_L.TransformedCFrame.Position - r.b.Girth_L.CFrame.Position).Magnitude
		res.girthLRest = r.b.Girth_L.CFrame.Position.Magnitude
	end)
	-- rigid crest: compare the crest with its socket bone over 1 s while the clip plays
	local p = rigs.plain
	local err, crestMove, sockMove = 0, 0, 0
	local c0, s0 = p.crest.Position, p.sock.TransformedWorldCFrame.Position
	local t0 = os.clock()
	local spineMax = 0
	while os.clock() - t0 < 1.2 do
		Run.PreRender:Wait()
		local sp = p.sock.TransformedWorldCFrame.Position
		err = math.max(err, (p.crest.Position - sp).Magnitude)
		crestMove = math.max(crestMove, (p.crest.Position - c0).Magnitude)
		sockMove = math.max(sockMove, (sp - s0).Magnitude)
		spineMax = math.max(spineMax, angle(p.b.Spine4.Transform))
	end
	local s3max, s3min = 0, math.huge
	for _, v in post do s3max = math.max(s3max, v) s3min = math.min(s3min, v) end
	res.spine3AfterAnimMax, res.spine3AfterAnimMin = s3max, s3min
	out.boneCode = res
	out.crestConstraint = { maxErr = err, crestMove = crestMove, sockMove = sockMove, spine4MaxAngle = spineMax, timePos = p.track.TimePosition }
	cam(CFrame.lookAt(base + Vector3.new(15.5, 0.4, 0), base + Vector3.new(0, 0.3, 0)), 40)
	return J(out)
end

-- Rigid piece moved by code instead of a constraint: crest.CFrame = socket.TransformedWorldCFrame on PreRender.
function M.crestCode(args)
	local m, root, an, track, sock, crest = M.makeRig(CFrame.new(STAGE + Vector3.new(0, 8, 0)), "Rig_crestCode", { crestMode = "code" })
	M.loadClip(track)
	local conn = Run.PreRender:Connect(function() crest.CFrame = sock.TransformedWorldCFrame end)
	local err, mv, c0 = 0, 0, crest.Position
	local t0 = os.clock()
	while os.clock() - t0 < 1 do
		Run.PreRender:Wait()
		err = math.max(err, (crest.Position - sock.TransformedWorldCFrame.Position).Magnitude)
		mv = math.max(mv, (crest.Position - c0).Magnitude)
	end
	conn:Disconnect()
	m:Destroy()
	return J({ maxErr = err, crestMove = mv })
end

-- S18: Model:ScaleTo 1.0 -> 6.5 on the animated skinned rig
function M.scale(args)
	local m, root, an, track, sock, crest = M.makeRig(CFrame.new(STAGE + Vector3.new(0, 0, 40)), "Rig_scale", {})
	M.loadClip(track)
	local body = m.M_Species_Base_Fish
	local out = { size0 = tostring(body.Size) }
	local function swing()
		local b = bones(root)
		local p0, mx, ang = b.TailFin.TransformedWorldCFrame.Position, 0, 0
		local t = os.clock()
		while os.clock() - t < 0.6 do
			Run.PreRender:Wait()
			mx = math.max(mx, (b.TailFin.TransformedWorldCFrame.Position - p0).Magnitude)
			ang = math.max(ang, angle(b.Spine4.Transform))
		end
		return mx, ang
	end
	out.tailSwing1, out.spine4Ang1 = swing()
	local t0 = os.clock()
	local ok, e = pcall(function() m:ScaleTo(6.5) end)
	out.scaleMs = (os.clock() - t0) * 1000
	out.ok, out.err = ok, e and tostring(e)
	task.wait(0.5)
	out.scale = m:GetScale()
	out.size1 = tostring(body.Size)
	out.playing = track.IsPlaying
	out.timePos = track.TimePosition
	local b = bones(root)
	out.spine4Pos = tostring(b.Spine4.Position)
	local err, mv, c0 = 0, 0, crest.Position
	local am = 0
	local t1 = os.clock()
	while os.clock() - t1 < 1 do
		Run.PreRender:Wait()
		err = math.max(err, (crest.Position - sock.TransformedWorldCFrame.Position).Magnitude)
		mv = math.max(mv, (crest.Position - c0).Magnitude)
		am = math.max(am, (b.TailFin.TransformedWorldCFrame.Position - b.TailFin.WorldPosition).Magnitude)
	end
	out.crestErr, out.crestMove = err, mv
	out.tailSwing65, out.spine4Ang65 = swing()
	label(body, "S18 x6.5")
	local small = M.makeRig(CFrame.new(STAGE + Vector3.new(0, -3, 52)), "Rig_scale1", {})
	label(small.M_Species_Base_Fish, "x1.0")
	cam(CFrame.lookAt(STAGE + Vector3.new(34, 4, 44), STAGE + Vector3.new(0, 1, 44)), 50)
	return J(out)
end

-- S8 / S0-A5: a Nursery-like lit scene with 24 animated rigs; frame time over N frames
function M.scene(args)
	local f = stage()
	local origin = STAGE + Vector3.new(0, -60, 600)
	local function part(sz, cf, col, shape)
		local p = Instance.new("Part") p.Anchored = true p.CanCollide = false p.Size = sz p.CFrame = cf p.Color = col
		p.Material = Enum.Material.SmoothPlastic if shape then p.Shape = shape end p.Parent = f return p
	end
	if not f:FindFirstChild("Floor") then
		part(Vector3.new(1400, 2, 1400), CFrame.new(origin + Vector3.new(0, -1, -500)), Color3.fromHex("#E8D7A8")).Name = "Floor"
		local rng = Random.new(7)
		for i = 1, 160 do
			local p = origin + Vector3.new(rng:NextNumber(-300, 300), 0, -rng:NextNumber(10, 900))
			part(Vector3.new(1, 1, 1) * rng:NextNumber(4, 16), CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6), 0.3), Color3.fromHex(i % 3 == 0 and "#FF8A6B" or (i % 3 == 1 and "#7FD8BE" or "#B9A27A")), i % 2 == 0 and Enum.PartType.Ball or nil)
		end
		for i, d in { 100, 150, 220, 300, 450 } do
			local b = part(Vector3.new(8, 8, 8), CFrame.new(origin + Vector3.new((i - 3) * d * 0.12, 14, -d)), Color3.new(1, 1, 1), Enum.PartType.Ball)
			b.Name = "Ball" .. d
		end
		for i = 1, 24 do
			local m = M.makeRig(CFrame.new(origin + Vector3.new(((i - 1) % 6 - 2.5) * 5, 8 + ((i - 1) // 6) * 3, -20 - ((i - 1) // 6) * 3)) * CFrame.Angles(0, math.pi / 2, 0), "Swarm" .. i, {})
			m:ScaleTo(1.4)
		end
	end
	cam(CFrame.lookAt(origin + Vector3.new(0, 14, 0), origin + Vector3.new(0, 12, -100)), 70)
	local balls = {}
	local vp = workspace.CurrentCamera.ViewportSize
	for _, d in { 100, 150, 220, 300, 450 } do
		local v = workspace.CurrentCamera:WorldToViewportPoint(f["Ball" .. d].Position)
		balls[tostring(d)] = { v.X, v.Y }
	end
	task.wait(1)
	local dts = {}
	local n = args.frames or 300
	for i = 1, n do table.insert(dts, Run.RenderStepped:Wait()) end
	table.sort(dts)
	local sum = 0 for _, v in dts do sum += v end
	return J({ meanMs = sum / n * 1000, p50 = dts[n // 2] * 1000, p99 = dts[math.ceil(n * 0.99)] * 1000, max = dts[n] * 1000, vp = { vp.X, vp.Y }, balls = balls,
		style = tostring(Lighting.LightingStyle), prio = Lighting.PrioritizeLightingQuality })
end

-- Nursery preset (06 section 10.2) with Atmosphere, or legacy fog at a given end distance
function M.light(args)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
	Lighting.Brightness = 2.2 Lighting.Ambient = Color3.fromHex("#8FD3D6") Lighting.OutdoorAmbient = Color3.fromHex("#B8ECEC")
	Lighting.ColorShift_Top = Color3.fromHex("#FFF3C4") Lighting.ExposureCompensation = 0.10 Lighting.ClockTime = 13
	local cc = Lighting:FindFirstChild("ArtCCC") or Instance.new("ColorCorrectionEffect", Lighting) cc.Name = "ArtCCC"
	cc.Brightness, cc.Contrast, cc.Saturation = 0.02, 0.08, 0.12
	local bl = Lighting:FindFirstChild("ArtCBloom") or Instance.new("BloomEffect", Lighting) bl.Name = "ArtCBloom"
	bl.Intensity, bl.Size, bl.Threshold = 0.6, 24, 0.95
	if args.mode == "fog" then
		atm.Parent = nil
		Lighting.FogColor = Color3.fromHex("#4CCFD2") Lighting.FogStart = args.fogEnd * 0.25 Lighting.FogEnd = args.fogEnd
	else
		atm.Parent = Lighting
		atm.Density, atm.Offset, atm.Haze, atm.Glare = args.density or 0.32, 0.10, 2.0, 0.4
		atm.Color, atm.Decay = Color3.fromHex("#4CCFD2"), Color3.fromHex("#BFF5E8")
		Lighting.FogEnd = 100000 Lighting.FogStart = 0
	end
	task.wait(0.6)
	return J({ mode = args.mode or "atm", density = args.density, fogEnd = args.fogEnd })
end

function M.cleanup(args)
	pcall(function() Run:UnbindFromRenderStep("ArtCCam") end)
	local f = workspace:FindFirstChild("ArtCStage") if f then f:Destroy() end
	return J({ ok = true })
end
