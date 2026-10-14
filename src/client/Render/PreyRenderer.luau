--!strict
-- PreyRenderer (module B17, first part; task S3-C4; docs/09, sections 4.7, 5.2 and 8.5 to 8.8):
-- decodes `PreyState` and `PreyEvent`, dead-reckons every known group and draws the nearest
-- members from pooled parts moved by one `workspace:BulkMoveTo` per frame (V25; spike tech-b S6).
--
--   Group table, packets, events, the drop rule (3 s, Far 5 s), dead reckoning and the mesh budget are the
--   pure `Shared.Logic.PreyMirror` (specs in tests/unit/Logic). Members are placed with the same
--   `Sim/Formation` the server uses: a pure function of group state, member index and time.
--   Quality    per graphics tier from `tune.quality.*` (09 §15.1, §17.4; Config/Flags): meshes
--              (`preyMeshes`), the distance they reach (`preyMeshDistance`: 150, 250, 350 studs,
--              so on Smooth the whole Mid band is particles, 8.5), far emitters
--              (`farPreyEmitters`, for part 2) and the outline caps (`outlinesEdible`,
--              `outlinesDangerous`). Read at start and on `setQuality`.
--   Pools      one `Render/Pools` pool per prey kind, sized by the tier's mesh budget. Parts
--              are anchored, `CollisionGroup` "Visual", and CanCollide,
--              CanTouch, CanQuery and CastShadow off. Unused parts are hidden, not moved.
--   Look       `ReplicatedStorage.Assets.Prey.<Kind>` (a BasePart, e.g. the imported MeshPart) is
--              cloned when Studio holds it; until then a placeholder ellipsoid sized from 06 §6.3's
--              lengths and coloured with 06 §6.2's Mid colour (07 §16: "low-poly ellipsoids sized
--              by tier in one flat colour per prey"). A missing asset never errors.
--   Motion     every member is wiggled in code, yaw, roll and bob, phase from seed + member (8.8),
--              with the `wobble` block of the prey motion table (06 §7.6, `Index.PreyMotion`; a
--              row with only `sway` wiggles its yaw by the sway; a row with neither is not
--              wiggled) plus Formation's cosmetic wobble. No motion number is copied here.
--   Outlines   lime "can eat" shells (06 §13.2, canon 5.2) on the nearest edible groups, capped by
--              the tier's outline caps (8.8: 20 groups, 8 on Smooth). Prey shells are 10% of body
--              height with no minimum (06 §13.2). Placeholder shells are the CreatureRig
--              kind: a slightly larger copy pushed away from the camera so only a rim shows; the
--              push is folded into the shell's CFrame, so it costs no property write.
--
-- Not here yet: far groups and members past the pool as particles (S4-C1), and
-- TODO(S4-C1): local bite detection (09 §8.9, PreyRenderer part 2). Skinned prey (tier 3 and up,
-- `RIG_Prey3`) are wiggled rigid until their meshes exist. The Smooth tier and `setQuality` come
-- from QualityController once it exists; until then the tier is Balanced. The far emitter cap is
-- read but nothing draws far groups yet (S4-C1).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Flags = require(ReplicatedStorage.Shared.Config.Flags)
local Formation = require(ReplicatedStorage.Shared.Sim.Formation)
local Index = require(ReplicatedStorage.Shared.Data.Index)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local OutlineRules = require(ReplicatedStorage.Shared.Logic.OutlineRules)
local PreyMirror = require(ReplicatedStorage.Shared.Logic.PreyMirror)
local Types = require(ReplicatedStorage.Shared.Types)

local Client = require(script.Parent.Parent.Net.Client)
local Outlines = require(script.Parent.Outlines)
local Pools = require(script.Parent.Pools)

export type GraphicsTier = PreyMirror.GraphicsTier

type Item = {
	body: BasePart,
	shell: BasePart?, -- nil for prey that never get an outline (plankton)
	outlined: boolean,
}

type Look = {
	kind: number,
	def: Types.PreyDef,
	template: BasePart?,
	size: Vector3,
	colour: Color3,
	shellPush: number, -- studs the shell is pushed away from the camera
	shellSize: Vector3,
	hasShell: boolean,
	hz: number, -- wiggle, cycles per second
	yaw: number, -- radians, half the swing
	roll: number,
	bob: number, -- studs
}

local PreyRenderer = {}
PreyRenderer.name = "PreyRenderer"

local TAG = "PreyRenderer"
local VISUAL_GROUP = "Visual" -- 09 §6.5
local FOLDER = "PreyRender"
local RENDER_NAME = "GulpPrey"
local TWO_PI = 2 * math.pi
local PUSH = 2.5 -- placeholder shell pushed back by this many line widths (CreatureRig's, tune)

-- 06 §6.3 lengths (studs) and 06 §6.2 Mid colours. Width and height of the placeholder ellipsoid
-- are shares of the length (tune); plankton is a round mote.
local PLACEHOLDER: { [string]: { length: number, colour: string } } = {
	plankton = { length = 0.4, colour = "#D9FFE8" },
	krill = { length = 0.8, colour = "#FF8C7A" },
	shrimp = { length = 1.0, colour = "#FFB48A" },
	sardine = { length = 1.6, colour = "#BFD9E8" },
	darter = { length = 2.4, colour = "#FFD23D" },
	mackerel = { length = 3.6, colour = "#2FA89A" },
	bonito = { length = 5.5, colour = "#6F8FD9" },
	tuna = { length = 8.5, colour = "#4F6FD0" },
}
local PLACEHOLDER_COLOUR = "#E6EEF5" -- trait prey until chapter 06 rows are wired (tune)
local WIDTH, HEIGHT = 0.4, 0.45 -- shares of the length (tune)

local player = Players.LocalPlayer
local mirror = PreyMirror.new()
local tier: GraphicsTier = "Balanced"
-- The tier's numbers (tune.quality.*), set by `readQuality`.
local budget = 0 -- prey drawn as meshes
local meshDistance = 0 -- studs
local farEmitters = 0 -- far group emitters (part 2, S4-C1)
local capEdible, capDangerous = 0, 0
local viewerTier = 1
local folder: Folder? = nil
local looks: { [number]: Look } = {}
local pools: { [number]: Pools.Pool<Item> } = {}
local poolList: { Pools.Pool<Item> } = {}
local missingKind: { [number]: boolean } = {}
local clock = 0 -- seconds of drawing, for the wiggle

-- Scratch, reused every frame (09 §4.7).
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}
local moveCount = 0
local outlineKinds: { OutlineRules.Kind } = {}
local outlineDistances: { number } = {}
local outlineOrder: { number } = {}
local outlineShown: { boolean } = {}

-- Frame statistics for the dev harness: the draw step's time and the meshes drawn.
local stats = {
	drawMs = 0,
	drawn = 0,
	outlined = 0,
	groups = 0,
	packets = 0,
	rejected = 0,
	ignored = 0, -- packets from a source the mirror is not taking (PreyMirror.setFeed)
	-- The graphics tier's numbers in use (tune.quality.*).
	tier = "Balanced" :: string,
	meshes = 0,
	meshDistance = 0,
	farEmitters = 0,
}

local function readQuality(t: GraphicsTier)
	budget = Flags.tiers("tune.quality.preyMeshes")[t]
	meshDistance = Flags.tiers("tune.quality.preyMeshDistance")[t]
	farEmitters = Flags.tiers("tune.quality.farPreyEmitters")[t]
	capEdible = Flags.tiers("tune.quality.outlinesEdible")[t]
	capDangerous = Flags.tiers("tune.quality.outlinesDangerous")[t]
	stats.tier, stats.meshes, stats.meshDistance, stats.farEmitters =
		t, budget, meshDistance, farEmitters
end
readQuality(tier)

local function setVisualPart(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	pcall(function() -- the group exists once the server registered it (09 §6.5)
		part.CollisionGroup = VISUAL_GROUP
	end)
end

local function findTemplate(id: string): BasePart?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local prey = assets and assets:FindFirstChild("Prey")
	if not prey then
		return nil
	end
	-- `krill` → `Krill`, `zebra_darter` → `ZebraDarter` (07 §1.2 names).
	local name = string.gsub(id, "^%l", string.upper)
	name = string.gsub(name, "_(%l)", string.upper)
	local found = prey:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

local function lookOf(kind: number): Look?
	local look = looks[kind]
	if look then
		return look
	end
	local def = Formation.defOf(kind)
	if def == nil then
		if not missingKind[kind] then
			missingKind[kind] = true
			Log.warn(TAG, `unknown prey kind {kind}; its groups are not drawn`)
		end
		return nil
	end
	local place = PLACEHOLDER[def.id]
	local length = if place then place.length else 2 * def.radius
	local template = findTemplate(def.id)
	local size = if template
		then template.Size
		elseif def.tier == 0 then Vector3.new(length, length, length)
		else Vector3.new(length * WIDTH, length * HEIGHT, length)
	local edibleT = OutlineRules.thickness(size.Y, "edible", true)
	-- 06 §7.6 data:PreyMotion: the wobble block, else the sway as a yaw wiggle, else still.
	local motion = Index.PreyMotion.byId[def.id]
	local wobble = motion and motion.wobble
	local sway = motion and motion.sway
	local made: Look = {
		kind = kind,
		def = def,
		template = template,
		size = size,
		colour = Color3.fromHex(if place then place.colour else PLACEHOLDER_COLOUR),
		shellPush = PUSH * edibleT,
		shellSize = size + Vector3.new(2 * edibleT, 2 * edibleT, 2 * edibleT),
		-- 06 §13.2: plankton has no shell; hook bait is not a prey kind.
		hasShell = OutlineRules.prey(math.huge, def.tier, false) ~= "none",
		hz = if wobble then wobble.hz elseif sway then sway.hz else 0,
		yaw = math.rad(if wobble then wobble.yawDeg elseif sway then sway.ampDeg else 0),
		roll = math.rad(if wobble then wobble.rollDeg else 0),
		bob = if wobble then wobble.bobStuds else 0,
	}
	looks[kind] = made
	return made
end

local function ellipsoid(name: string, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Material = Enum.Material.SmoothPlastic
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function makeItem(look: Look): Item
	local body: BasePart
	if look.template then
		body = look.template:Clone()
	else
		local p = ellipsoid(look.def.id, look.size)
		p.Color = look.colour
		body = p
	end
	setVisualPart(body)
	body.Transparency = 1
	body.Parent = folder
	local shell: BasePart? = nil
	if look.hasShell then
		-- TODO(S3-A1 meshes): clone `M_Prey_<Kind>_Shell` once uploaded instead of this hull.
		local s = ellipsoid(look.def.id .. "_Shell", look.shellSize)
		s.Material = Enum.Material.Neon -- 06 §13.2
		s.Color = Outlines.colour("edible")
		s.Transparency = 1
		setVisualPart(s)
		s.Parent = folder
		shell = s
	end
	return { body = body, shell = shell, outlined = false }
end

local function destroyItem(item: Item)
	item.body:Destroy()
	if item.shell then
		item.shell:Destroy()
	end
end

local function poolOf(look: Look): Pools.Pool<Item>
	local pool = pools[look.kind]
	if pool == nil then
		local made = Pools.new(function(): Item
			return makeItem(look)
		end, budget)
		pools[look.kind] = made
		table.insert(poolList, made)
		return made
	end
	return pool
end

local function push(part: BasePart, cf: CFrame)
	moveCount += 1
	moveParts[moveCount] = part
	moveCFrames[moveCount] = cf
end

local function viewerPosition(): Vector3?
	local character = player and player.Character
	local root = character and character.PrimaryPart
	if root then
		return root.Position
	end
	local camera = workspace.CurrentCamera
	return if camera then camera.CFrame.Position else nil
end

--- The draw step, every frame (09 §4.7 hot path).
function PreyRenderer.render(dt: number)
	debug.profilebegin(TAG)
	local started = os.clock()
	clock += dt
	local viewer = viewerPosition()
	if viewer then
		PreyMirror.dropStale(mirror, started, viewer.X, viewer.Y, viewer.Z)
	else
		PreyMirror.dropStale(mirror, started)
	end
	PreyMirror.step(mirror, Client.timeMs() / 1000, dt)

	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local ex, ey, ez = eye.X, eye.Y, eye.Z
	local given, front = 0, 0
	if viewer then
		given, front = PreyMirror.assign(mirror, viewer.X, viewer.Y, viewer.Z, budget, meshDistance)
	end

	-- Outlines: nearest edible groups first, up to the cap (8.8).
	local order, kinds, drawn = mirror.order, mirror.kind, mirror.drawn
	for k = 1, front do
		local i = order[k] + 1
		local look = lookOf(kinds[i])
		outlineKinds[k] = if look
				and look.hasShell
				and Outlines.visible() -- HUD.Outlines
			then OutlineRules.prey(viewerTier, look.def.tier, false)
			else "none"
		outlineDistances[k] = mirror.dist[i]
	end
	OutlineRules.select(
		outlineKinds,
		outlineDistances,
		front,
		capEdible,
		capDangerous,
		outlineOrder,
		outlineShown
	)

	for _, pool in poolList do
		Pools.begin(pool)
	end
	moveCount = 0
	local outlined = 0
	local t = clock
	local dx, dy, dz, heading = mirror.dx, mirror.dy, mirror.dz, mirror.heading
	for k = 1, front do
		local i = order[k] + 1
		local want = drawn[i]
		local look = if want > 0 then lookOf(kinds[i]) else nil
		if look then
			local pool = poolOf(look)
			local kind, seed, count, alive =
				look.kind, mirror.seed[i], mirror.count[i], mirror.alive[i]
			local gx, gy, gz, h, scatter = dx[i], dy[i], dz[i], heading[i], mirror.scatter[i]
			local outline = outlineShown[k] == true
			local hz, yawAmp, rollAmp, bob = look.hz, look.yaw, look.roll, look.bob
			local member = 0
			while want > 0 and member < count do
				if bit32.btest(alive, bit32.lshift(1, member)) then
					want -= 1
					local item, wasHidden = Pools.take(pool)
					if item == nil then
						break
					end
					local x, y, z = Formation.memberPos(kind, seed, member, gx, gy, gz, h, scatter)
					local wx, wy, wz = Formation.wobble(kind, seed, member, t)
					local phase = TWO_PI * hz * t + seed + member
					local yaw = h + math.pi + yawAmp * math.sin(phase)
					local roll = rollAmp * math.sin(phase + 1.3)
					x, y, z = x + wx, y + wy + bob * math.sin(phase * 2), z + wz
					-- Ry(yaw) × Rz(roll): local −Z (LookVector) faces the heading (sin h, 0, cos h).
					local c, s, cr, sr =
						math.cos(yaw), math.sin(yaw), math.cos(roll), math.sin(roll)
					local r00, r01, r02 = c * cr, -c * sr, s
					local r10, r11, r12 = sr, cr, 0
					local r20, r21, r22 = -s * cr, s * sr, c
					local body = item.body
					if wasHidden then
						body.Transparency = 0
					end
					push(body, CFrame.new(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22))
					local shell = item.shell
					if shell then
						if outline then
							if not item.outlined then
								item.outlined = true
								shell.Color = Outlines.colour("edible")
								shell.Transparency = 0
							end
							local ax, ay, az = x - ex, y - ey, z - ez
							local d = math.sqrt(ax * ax + ay * ay + az * az)
							local p = if d > 1e-3 then look.shellPush / d else 0
							push(
								shell,
								CFrame.new(
									x + ax * p,
									y + ay * p,
									z + az * p,
									r00,
									r01,
									r02,
									r10,
									r11,
									r12,
									r20,
									r21,
									r22
								)
							)
							outlined += 1
						elseif item.outlined then
							item.outlined = false
							shell.Transparency = 1
						end
					end
				end
				member += 1
			end
		end
	end

	for _, pool in poolList do
		local from, to = Pools.finish(pool)
		for n = from, to do
			local item = Pools.at(pool, n)
			item.body.Transparency = 1
			local shell = item.shell
			if shell and item.outlined then
				item.outlined = false
				shell.Transparency = 1
			end
		end
	end
	for n = #moveParts, moveCount + 1, -1 do
		moveParts[n] = nil
		moveCFrames[n] = nil
	end
	if moveCount > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	stats.drawn, stats.outlined, stats.groups = given, outlined, PreyMirror.size(mirror)
	stats.drawMs = (os.clock() - started) * 1000
	debug.profileend()
end

--- Applies one `PreyState` payload from `feed` ("remote", the default: the remote handler; the dev
--- harness passes its own name). Packets from a source the mirror is not taking are ignored.
function PreyRenderer.feed(payload: buffer, feed: string?)
	if not PreyMirror.takes(mirror, feed or "remote") then
		stats.ignored += 1
		return
	end
	if PreyMirror.applyPacket(mirror, payload, os.clock()) then
		stats.packets += 1
	else
		stats.rejected += 1
	end
end

--- Applies one `PreyEvent` payload.
function PreyRenderer.feedEvents(payload: buffer)
	if not PreyMirror.applyEvents(mirror, payload) then
		Log.once("warn", TAG, "dropped a malformed PreyEvent")
	end
	-- TODO(S4-C1): eaten members get FX_BubblePop and the eat sound here (09 §8.9).
end

--- 5.2: the nearest live group (to the local creature) of a kind in `kindFilter` (kind codes,
--- `Formation.kindOf`; nil for any), its drawn position and distance; nil when there is none.
function PreyRenderer.nearest(kindFilter: { [number]: boolean }?): (number?, Vector3?, number)
	local viewer = viewerPosition()
	if viewer == nil then
		return nil, nil, math.huge
	end
	local id, d = PreyMirror.nearest(mirror, viewer.X, viewer.Y, viewer.Z, kindFilter)
	if id == nil then
		return nil, nil, math.huge
	end
	local i = id + 1
	return id, Vector3.new(mirror.dx[i], mirror.dy[i], mirror.dz[i]), d
end

--- 5.2: the graphics tier (QualityController calls it): the tier's numbers from tune.quality.*
--- (15.1: 80, 150 or 250 meshes within 150, 250 or 350 studs).
function PreyRenderer.setQuality(newTier: GraphicsTier)
	tier = newTier
	readQuality(newTier)
	for _, pool in poolList do
		Pools.setCap(pool, budget, destroyItem)
	end
end

--- Dev: makes `feed` the one packet source ("remote" by default; PreyHarness takes it while it
--- runs, so the live stream and its synthetic one never interleave).
function PreyRenderer.setFeed(feed: string)
	PreyMirror.setFeed(mirror, feed)
end

--- Dev and tests: the last frame's draw time (ms), meshes drawn, shells shown, groups known, and
--- packets accepted and rejected.
function PreyRenderer.stats(): typeof(stats)
	return stats
end

local function readViewerTier()
	local v = player and player:GetAttribute("Tier")
	viewerTier = if typeof(v) == "number" then v else 1
end

function PreyRenderer.init()
	mirror = PreyMirror.new()
	table.clear(looks)
	table.clear(pools)
	table.clear(poolList)
end

function PreyRenderer.start()
	local f = Instance.new("Folder")
	f.Name = FOLDER
	f.Parent = workspace
	folder = f
	if player then
		readViewerTier()
		player:GetAttributeChangedSignal("Tier"):Connect(readViewerTier)
	end
	Client.on("PreyState", function(payload: unknown)
		if typeof(payload) == "buffer" then
			PreyRenderer.feed(payload)
		end
	end)
	Client.on("PreyEvent", function(payload: unknown)
		if typeof(payload) == "buffer" then
			PreyRenderer.feedEvents(payload)
		end
	end)
	-- After the camera (Camera + 1), so the shells face this frame's eye.
	RunService:BindToRenderStep(
		RENDER_NAME,
		Enum.RenderPriority.Camera.Value + 1,
		PreyRenderer.render
	)
end

return PreyRenderer
