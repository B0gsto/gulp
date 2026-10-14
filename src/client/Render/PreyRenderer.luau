--!strict
-- PreyRenderer (module B17; tasks S3-C4 and S4-C1; docs/09, sections 4.7, 5.2 and 8.5 to 8.9):
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
--              height with no minimum (06 §13.2). Placeholder shells are Render/HullMesh's
--              flipped-face ellipsoid, body size plus twice the line width, moved with the body;
--              made on first use, since the mesh is built async.
--
--   Glints   (S4-C1) every member not drawn as a mesh, of a group past the mesh range or past the
--              pool, is a glint (8.8; 06 `FX_Glint`, 07 §4: "every prey becomes a single dot"):
--              one ParticleEmitter on a pooled Attachment per group, `count` glints in the kind's
--              colour, within the tier's emitter cap (30, 60, 60) and prey visible in total (250,
--              400, 800, meshes included). `PreyMirror.assignGlints` keeps a group on its emitter.
--              The Attachment's anchored host part moves in the same BulkMoveTo as the meshes and
--              the glints are locked to it, so a cluster swims with its group.
--   Bites    (S4-C1; 8.9) every frame, before drawing, the own mouth (`CreatureController.
--              localMouth`, the smoothed rig, 6.7) is tested against the drawn position of every
--              live member of an edible kind near it, with the gulp assist of the current input
--              mode (`Shared.Logic.BiteDetect`; 02 §4.1, 15 §4.3). A hit is hidden at once and
--              claimed in one `Bite` per frame, kept to the `Bite` bucket (`Shared.Logic.
--              BiteClaims`); `BiteResult` marks accepted members eaten and shows rejected ones
--              again, fading in over 0.15 s with a puff (02 §4.3). Members the assist is pulling
--              are drawn moved toward the mouth by the distance pulled.
--
-- Not here yet: `FX_BubblePop_*`, `SFX_Bite_*` and the "+mass" number (07 rows not started; a
-- placeholder bubble pop and miss puff stand in), the predicted mass on the HUD (02 §4.3) and
-- the jaw. Skinned prey (tier 3 and up, `RIG_Prey3`) are wiggled rigid until their meshes exist.
-- The Smooth tier and `setQuality` come from QualityController once it exists; until then the
-- tier is Balanced.
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

local BiteClaims = require(ReplicatedStorage.Shared.Logic.BiteClaims)
local BiteDetect = require(ReplicatedStorage.Shared.Logic.BiteDetect)
local BiteResult = require(ReplicatedStorage.Shared.Net.Codec.BiteResult)
local PreyEvent = require(ReplicatedStorage.Shared.Net.Codec.PreyEvent)

local Client = require(script.Parent.Parent.Net.Client)
local CreatureController = require(script.Parent.Parent.Controllers.CreatureController)
local HullMesh = require(script.Parent.HullMesh)
local InputController = require(script.Parent.Parent.Controllers.InputController)
local Outlines = require(script.Parent.Outlines)
local Pools = require(script.Parent.Pools)

export type GraphicsTier = PreyMirror.GraphicsTier

type Item = {
	body: BasePart,
	shell: BasePart?, -- nil for prey that never get an outline (plankton), and until first used
	outlined: boolean,
	fading: boolean, -- drawn part-transparent while fading back in after a rejected claim
}

-- One far glint emitter (8.8): an anchored, invisible host part moved with the meshes, holding
-- the Attachment and its ParticleEmitter.
type Host = {
	part: BasePart,
	emitter: ParticleEmitter,
	group: number, -- groupId + 1 it draws, 0 for none
	gen: number,
	rate: number,
	size: number,
}

type Look = {
	kind: number,
	def: Types.PreyDef,
	template: BasePart?,
	size: Vector3,
	colour: Color3,
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
local farEmitters = 0 -- far group emitters
local visibleCap = 0 -- prey visible in total, meshes and glints
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

-- Bites (8.9).
local claims = BiteClaims.new(os.clock())
local detect = BiteDetect.new()
local accepted: { BiteClaims.Target } = {}
local missed: { BiteClaims.Target } = {}
local gone: { BiteClaims.Target } = {}
local mouthX, mouthY, mouthZ = 0, 0, 0
local pulling = false -- some member is being pulled by the assist this frame
local puffAttachment: Attachment? = nil
local popEmitter: ParticleEmitter? = nil
local missEmitter: ParticleEmitter? = nil

-- Far glints (8.8).
local hosts: { Host } = {}
local GLINT_LIFE = NumberRange.new(1.6, 2.4) -- seconds (tune)
local GLINT_MEAN_LIFE = 2.0
local GLINT_ANGLE = 0.007 -- glint size, studs per stud of distance: about 4 px at 800 px tall (tune)
local GLINT_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds" -- until T_FX_Star_Mask
local GLINT_TWINKLE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.15, 0.05),
	NumberSequenceKeypoint.new(0.5, 0.35),
	NumberSequenceKeypoint.new(0.7, 0.05),
	NumberSequenceKeypoint.new(1, 1),
})

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
	-- Far glints (S4-C1).
	emitters = 0,
	glints = 0,
	-- Bites (S4-C1): claims sent, members claimed, results, members hidden now.
	claims = 0,
	claimed = 0,
	accepted = 0,
	missed = 0, -- members: rejected by the server or timed out
	gone = 0, -- members: rejected as eaten by someone else
	hidden = 0,
	pending = 0,
	lastSeq = -1, -- the seq of the last claim sent
	lastReason = 0,
	lastMass = 0,
	lastTier = 0,
	biteMs = 0,
}

local function readQuality(t: GraphicsTier)
	budget = Flags.tiers("tune.quality.preyMeshes")[t]
	meshDistance = Flags.tiers("tune.quality.preyMeshDistance")[t]
	farEmitters = Flags.tiers("tune.quality.farPreyEmitters")[t]
	visibleCap = Flags.tiers("tune.quality.preyVisible")[t]
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

-- The outline shell of one member, or nil (no shell for this kind, or the hull not built yet).
local function makeShell(look: Look): BasePart?
	if not look.hasShell then
		return nil
	end
	-- TODO(S3-A1 meshes): clone `M_Prey_<Kind>_Shell` once uploaded instead of this hull.
	local s = HullMesh.new(look.def.id .. "_Shell", look.shellSize)
	if s then
		s.Color = Outlines.colour("edible")
		setVisualPart(s)
		s.Parent = folder
	end
	return s
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
	return { body = body, shell = makeShell(look), outlined = false, fading = false }
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

local function newPuffEmitter(
	name: string,
	colour: Color3,
	size: number,
	speed: number
): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Enabled = false
	e.Texture = GLINT_TEXTURE
	e.Color = ColorSequence.new(colour)
	e.LightEmission = 0.6
	e.LightInfluence = 0
	e.Lifetime = NumberRange.new(0.3, 0.5)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.4),
		NumberSequenceKeypoint.new(1, size),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	return e
end

-- Placeholder pop on a bite and puff on a miss (02 §4.3; 07 `FX_BubblePop_*` not made yet).
local function puff(emitter: ParticleEmitter?, x: number, y: number, z: number, count: number)
	local a = puffAttachment
	if emitter and a then
		a.WorldPosition = Vector3.new(x, y, z)
		emitter:Emit(count)
	end
end

local function makeHost(): Host
	local part = Instance.new("Part")
	part.Name = "GlintHost"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	setVisualPart(part)
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	local e = Instance.new("ParticleEmitter")
	e.Name = "FX_Glint"
	e.Enabled = false
	e.Texture = GLINT_TEXTURE
	e.LightEmission = 1
	e.LightInfluence = 0
	e.LockedToPart = true -- the cluster swims with its group
	e.Lifetime = GLINT_LIFE
	e.SpreadAngle = Vector2.new(180, 180)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Rotation = NumberRange.new(0, 360)
	e.Transparency = GLINT_TWINKLE
	e.Parent = attachment
	part.Parent = folder
	return { part = part, emitter = e, group = 0, gen = 0, rate = 0, size = 0 }
end

local function setHostCap(cap: number)
	for n = #hosts, cap + 1, -1 do
		hosts[n].part:Destroy()
		hosts[n] = nil
	end
end

-- Draws the far glints `PreyMirror.assignGlints` gave out; queues each host's move.
local function drawGlints()
	local slotGroup, glints = mirror.slotGroup, mirror.glints
	local emitters, total = 0, 0
	for slot = 1, farEmitters do
		local i = slotGroup[slot] or 0
		local host = hosts[slot]
		if i > 0 then
			local look = lookOf(mirror.kind[i])
			if look then
				if host == nil then
					host = makeHost()
					hosts[slot] = host
				end
				local e = host.emitter
				if host.group ~= i or host.gen ~= mirror.gen[i] then
					-- A new group on this emitter: start clean, in its kind's colour and spread.
					host.group, host.gen = i, mirror.gen[i]
					e:Clear()
					e.Color = ColorSequence.new(look.colour)
					local kind = look.kind
					local spread = Formation.radius(kind)
							* (1 + mirror.scatter[i] * Formation.scatterGain(kind))
						+ Formation.wobbleCap(kind)
					local v = math.max(spread, 0.5) / GLINT_MEAN_LIFE
					e.Speed = NumberRange.new(0.3 * v, v)
					host.rate, host.size = 0, 0
				end
				local n = glints[i]
				local rate = n / GLINT_MEAN_LIFE
				if rate ~= host.rate then
					host.rate = rate
					e.Rate = rate
				end
				local size = math.max(look.size.Z * 0.8, mirror.dist[i] * GLINT_ANGLE)
				if math.abs(size - host.size) > 0.15 * host.size then
					host.size = size
					e.Size = NumberSequence.new(size)
				end
				if not e.Enabled then
					e.Enabled = true
					-- Warm start: a new cluster appears whole instead of growing in.
					e:Emit(n)
				end
				push(host.part, CFrame.new(mirror.dx[i], mirror.dy[i], mirror.dz[i]))
				emitters += 1
				total += n
			end
		elseif host and host.group ~= 0 then
			-- Freed: stop emitting; the last glints twinkle out where they are.
			host.group = 0
			host.emitter.Enabled = false
		end
	end
	stats.emitters, stats.glints = emitters, total
end

-- A rejected member pops back with a "miss" puff where it is drawn (8.9).
local function missPuff(target: BiteClaims.Target)
	stats.missed += 1
	local i = target.groupId + 1
	if mirror.live[i] and mirror.gen[i] == target.gen then
		local x, y, z = Formation.memberPos(
			mirror.kind[i],
			mirror.seed[i],
			target.member,
			mirror.dx[i],
			mirror.dy[i],
			mirror.dz[i],
			mirror.heading[i],
			mirror.scatter[i]
		)
		puff(missEmitter, x, y, z, 5)
	end
end

-- The own mouth, its facing and radius, from the smoothed rig (6.7); nil when there is no
-- creature.
local function ownMouth(): (Vector3?, Vector3, number)
	local mouth, radius = CreatureController.localMouth()
	if radius <= 0 then
		return nil, Vector3.zero, 0
	end
	local slot = player and player:GetAttribute("Slot")
	local rig = if typeof(slot) == "number" then CreatureController.rigOf(slot) else nil
	local facing = if rig then rig.heading else Vector3.zero
	if facing.Magnitude < 1e-3 then
		local viewer = viewerPosition()
		facing = if viewer then mouth - viewer else Vector3.zAxis
	end
	return mouth, facing.Unit, radius
end

-- Settles results and time-outs, then tests the mouth against the members near it (8.9).
local function biteStep(now: number, dt: number, t: number)
	local started = os.clock()
	BiteDetect.beginFrame(detect)
	pulling = false
	table.clear(missed)
	BiteClaims.expire(claims, now, missed)
	for _, target in missed do
		missPuff(target)
	end

	local mouth, facing, r = ownMouth()
	if mouth == nil then
		stats.biteMs = (os.clock() - started) * 1000
		return
	end
	local mx, my, mz = mouth.X, mouth.Y, mouth.Z
	local fx, fy, fz = facing.X, facing.Y, facing.Z
	mouthX, mouthY, mouthZ = mx, my, mz
	local set = BiteDetect.assistSet(InputController.mode())
	local reach = math.max(set.range, 1) * r
	local live, kinds, gens, alive, counts =
		mirror.live, mirror.kind, mirror.gen, mirror.alive, mirror.count
	local dx, dy, dz = mirror.dx, mirror.dy, mirror.dz
	for _, id in mirror.ids do
		local i = id + 1
		local look = if live[i] and alive[i] ~= 0 then lookOf(kinds[i]) else nil
		-- 02 §4.2 check 6, prey side: only prey the creature can eat are tested or pulled.
		if look and look.def.tier <= viewerTier then
			local kind = look.kind
			local scatter = mirror.scatter[i]
			local preyRadius = look.def.radius
			local around = Formation.radius(kind) * (1 + scatter * Formation.scatterGain(kind))
				+ Formation.wobbleCap(kind)
				+ preyRadius
				+ reach
			local ax, ay, az = dx[i] - mx, dy[i] - my, dz[i] - mz
			if ax * ax + ay * ay + az * az <= around * around then
				local seed, gen, mask, h = mirror.seed[i], gens[i], alive[i], mirror.heading[i]
				for member = 0, counts[i] - 1 do
					if
						bit32.btest(mask, bit32.lshift(1, member))
						and not BiteClaims.isHidden(claims, id, member, gen)
					then
						local x, y, z =
							Formation.memberPos(kind, seed, member, dx[i], dy[i], dz[i], h, scatter)
						local wx, wy, wz = Formation.wobble(kind, seed, member, t)
						local result = BiteDetect.test(
							detect,
							BiteDetect.key(id, member),
							dt,
							mx,
							my,
							mz,
							r,
							fx,
							fy,
							fz,
							x + wx,
							y + wy,
							z + wz,
							preyRadius,
							set
						)
						if result == BiteDetect.HIT then
							if BiteClaims.add(claims, id, member, gen, now) then
								stats.claimed += 1
								puff(popEmitter, x + wx, y + wy, z + wz, 6)
								-- TODO(S4-C1 assets): SFX_Bite_<size> and FX_BubblePop_<tier> (07).
							end
						elseif result == BiteDetect.ASSIST then
							pulling = true
						end
					end
				end
			end
		end
	end
	local rtt = if player then player:GetNetworkPing() else nil
	local payload, seq = BiteClaims.flush(claims, Client.timeMs(), now, BiteClaims.timeout(rtt))
	if payload then
		if Client.send("Bite", payload) then
			stats.claims += 1
			stats.lastSeq = seq
		else
			BiteClaims.unsent(claims, seq)
		end
	end
	stats.hidden = BiteClaims.hiddenCount(claims)
	stats.pending = BiteClaims.pendingCount(claims)
	stats.biteMs = (os.clock() - started) * 1000
end

--- Applies one `BiteResult` payload (8.9): accepted members, and those rejected as `gone`, are
--- eaten in the mirror; members rejected for any other reason (range, tier, time, rate, state,
--- safe zone, protected) fade back in with a puff.
function PreyRenderer.onBiteResult(payload: buffer)
	if not BiteResult.valid(payload) then
		Log.once("warn", TAG, "dropped a malformed BiteResult")
		return
	end
	local seq, mask, reason, mass, newTier = BiteResult.decode(payload)
	stats.lastReason, stats.lastMass, stats.lastTier = reason, mass, newTier
	table.clear(accepted)
	table.clear(missed)
	table.clear(gone)
	if not BiteClaims.result(claims, seq, mask, reason, os.clock(), accepted, missed, gone) then
		return
	end
	for _, target in accepted do
		PreyMirror.applyEvent(mirror, PreyEvent.OP_EATEN, target.groupId, target.gen, target.member)
		stats.accepted += 1
	end
	-- `gone`: someone else ate it first; it stays gone and nothing plays (8.9).
	for _, target in gone do
		PreyMirror.applyEvent(mirror, PreyEvent.OP_EATEN, target.groupId, target.gen, target.member)
		stats.gone += 1
	end
	for _, target in missed do
		missPuff(target)
	end
	stats.hidden = BiteClaims.hiddenCount(claims)
	stats.pending = BiteClaims.pendingCount(claims)
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
	-- Bites before drawing, so a member hidden this frame is not drawn (8.9).
	biteStep(started, dt, clock)

	local given, front = 0, 0
	if viewer then
		given, front = PreyMirror.assign(mirror, viewer.X, viewer.Y, viewer.Z, budget, meshDistance)
	end
	PreyMirror.assignGlints(mirror, farEmitters, math.max(visibleCap - given, 0))

	-- Outlines: nearest edible groups first, up to the cap (8.8).
	local order, kinds, drawn = mirror.order, mirror.kind, mirror.drawn
	for k = 1, front do
		local i = order[k] + 1
		local look = lookOf(kinds[i])
		outlineKinds[k] = if look and look.hasShell
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
	local anyHidden = next(claims.hidden) ~= nil
	local anyFading = BiteClaims.fading(claims)
	for k = 1, front do
		local i = order[k] + 1
		local want = drawn[i]
		local look = if want > 0 then lookOf(kinds[i]) else nil
		if look then
			local pool = poolOf(look)
			local kind, seed, count, alive =
				look.kind, mirror.seed[i], mirror.count[i], mirror.alive[i]
			local groupId, gen = order[k], mirror.gen[i]
			local gx, gy, gz, h, scatter = dx[i], dy[i], dz[i], heading[i], mirror.scatter[i]
			local outline = outlineShown[k] == true
			local hz, yawAmp, rollAmp, bob = look.hz, look.yaw, look.roll, look.bob
			local member = 0
			while want > 0 and member < count do
				if
					bit32.btest(alive, bit32.lshift(1, member))
					and not (anyHidden and BiteClaims.isHidden(claims, groupId, member, gen))
				then
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
					if pulling then
						-- 02 §4.1: the gulp assist pulls the member toward the mouth centre.
						local p = BiteDetect.pulled(detect, BiteDetect.key(groupId, member))
						if p > 0 then
							local ax, ay, az = mouthX - x, mouthY - y, mouthZ - z
							local d = math.sqrt(ax * ax + ay * ay + az * az)
							if d > 1e-3 then
								local f = math.min(p / d, 1)
								x, y, z = x + ax * f, y + ay * f, z + az * f
							end
						end
					end
					-- Ry(yaw) × Rz(roll): local −Z (LookVector) faces the heading (sin h, 0, cos h).
					local c, s, cr, sr =
						math.cos(yaw), math.sin(yaw), math.cos(roll), math.sin(roll)
					local r00, r01, r02 = c * cr, -c * sr, s
					local r10, r11, r12 = sr, cr, 0
					local r20, r21, r22 = -s * cr, s * sr, c
					local body = item.body
					local shown = if anyFading
						then BiteClaims.fadeIn(claims, groupId, member, started)
						else 1
					if shown < 1 then
						-- 02 §4.3: a rejected member fades back in.
						item.fading = true
						body.Transparency = 1 - shown
					elseif wasHidden or item.fading then
						item.fading = false
						body.Transparency = 0
					end
					local cf = CFrame.new(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
					push(body, cf)
					local shell = item.shell
					if outline and not shell then
						shell = makeShell(look)
						item.shell = shell
					end
					if shell then
						if outline then
							if not item.outlined then
								item.outlined = true
								shell.Color = Outlines.colour("edible")
								shell.Transparency = 0
							end
							push(shell, cf)
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
			item.fading = false
			local shell = item.shell
			if shell and item.outlined then
				item.outlined = false
				shell.Transparency = 1
			end
		end
	end
	drawGlints()
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
	setHostCap(farEmitters)
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
	claims = BiteClaims.new(os.clock())
	detect = BiteDetect.new()
	table.clear(hosts)
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
	Client.on("BiteResult", function(payload: unknown)
		if typeof(payload) == "buffer" then
			PreyRenderer.onBiteResult(payload)
		end
	end)
	-- One attachment for the placeholder bite pop and miss puff (02 §4.3).
	local puffHost = Instance.new("Part")
	puffHost.Name = "PuffHost"
	puffHost.Size = Vector3.new(0.2, 0.2, 0.2)
	puffHost.Transparency = 1
	setVisualPart(puffHost)
	local a = Instance.new("Attachment")
	a.Parent = puffHost
	popEmitter = newPuffEmitter("BitePop", Color3.fromHex("#E8F8FF"), 0.6, 6)
	missEmitter = newPuffEmitter("MissPuff", Color3.fromHex("#9FB3C2"), 0.8, 3)
	if popEmitter then
		popEmitter.Parent = a
	end
	if missEmitter then
		missEmitter.Parent = a
	end
	puffAttachment = a
	puffHost.Parent = f
	-- After the camera (Camera + 1), so the glints see this frame's eye.
	RunService:BindToRenderStep(
		RENDER_NAME,
		Enum.RenderPriority.Camera.Value + 1,
		PreyRenderer.render
	)
end

return PreyRenderer
