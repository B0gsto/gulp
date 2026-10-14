--!strict
-- CreatureRig (B13, first part; task S3-C6): builds, poses and scales the visible rig of one
-- creature. docs/09 sections 6.1, 6.7 to 6.9; docs/06 sections 8.4 and 13.2; spikes tech-c/tech-d.
--
-- The rig is client-made, never welded to the replicated root, and moved by CreatureController
-- every frame from the smoothed `rig.pos`. Its tree:
--
--   Rig_<species>        Model, PrimaryPart = RootPart, CollisionGroup "Visual" on every part
--   ├── RootPart         anchored, invisible; the skeleton (RIG_Fish bone names) hangs under it
--   ├── AnimationController ── Animator
--   ├── Juvenile, Adult  the two forms (09 §6.9); only one is visible
--   └── *_Shell, *_ShellThick   outline shells per form (06 §13.2), hidden until a colour is set
--
-- Where the template comes from:
--   1. `ReplicatedStorage.Assets.Species.<Species>` when Studio holds the imported rig (09 §3.1):
--      cloned once, given its socket bones from the exported socket table (a `Sockets`
--      StringValue holding `<rig>.sockets.json`, 06 §8.4, spike F13), `MeshPart.Color` set to
--      white (the importer leaves it grey, spike S0-A1) and an Animator, then cloned per
--      creature, so skinned pieces are in the template before spawning (spike F19).
--   2. Otherwise a code-built placeholder with the RIG_Fish bone names (rigs.py FishFit): rigid
--      ellipsoid pieces held to their bones by RigidConstraint (06 §8.4, spike F14), and
--      placeholder shells: a flipped-face ellipsoid hull per outlined piece (Render/HullMesh),
--      the body piece's size plus twice the line width, held to the same bone. Only its far
--      inside draws, so a rim shows around the body from any camera. Two earlier stand-ins drew
--      solid blobs over the body in Studio: a negative mesh scale (it does not flip faces) and a
--      larger shell pushed away from the camera. The imported `_Shell` meshes have real flipped
--      faces (spike S0-A2).
--
-- Animation: the five fish clips play through the Animator when the manifest has their asset
-- IDs; otherwise `sway` writes the reference swim wave onto the bones. Bones are written on the
-- render step, after the Animator has reset them (spike surprise 3). Never errors on a missing
-- asset: anything absent falls back.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HullMesh = require(script.Parent.HullMesh)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local OutlineRules = require(ReplicatedStorage.Shared.Logic.OutlineRules)
local Outlines = require(script.Parent.Outlines)
local RigMath = require(ReplicatedStorage.Shared.Logic.RigMath)
local TraitRules = require(ReplicatedStorage.Shared.Logic.TraitRules)

local CreatureRig = {}

local TAG = "CreatureRig"
local VISUAL_GROUP = "Visual" -- 09 §6.5
-- Glow (06 §8.2 trait table: colour #FFE98A, light brightness 0.5; the radius is 02 §8.4's).
local GLOW_COLOUR = Color3.fromHex("#FFE98A")
local GLOW_BRIGHTNESS = 0.5
local GLOW_OVERLAY_GROW = 1.04 -- the placeholder tint overlay's size over its body piece
local GLOW_OVERLAY_TRANSPARENCY = 0.55

export type Form = "Juvenile" | "Adult"
export type Kind = OutlineRules.Kind
export type Clip = RigMath.Clip

--- A placeholder shell: a flipped-face hull (Render/HullMesh) over one body piece, made the
--- first time the form shows an outline once the hull mesh is ready.
type HullShell = { body: BasePart, part: BasePart? }

type FormParts = {
	body: { BasePart },
	thin: { BasePart }, -- the `_Shell` (green)
	thick: { BasePart }, -- the `_ShellThick` (red); the same parts as `thin` on the placeholder
	hulls: { HullShell }, -- placeholder only
	folder: Instance?, -- placeholder only: where its hulls go
}

-- Glow's body light (02 §8.4, 04 B5; task S6-C3): a point light on the rig root and, until
-- S6-A1's overlay shell and `T_Trait_Glow_Fish_Emi` land, a flat tint overlay: a copy of each
-- body piece 4% larger in the Glow colour, welded to it.
type Glow = { light: PointLight, overlays: { Juvenile: { BasePart }, Adult: { BasePart } } }

export type Rig = {
	model: Model,
	root: BasePart,
	species: string,
	placeholder: boolean,
	bones: { [string]: Bone },
	animator: Animator?,
	tracks: { [string]: AnimationTrack },
	forms: { Juvenile: FormParts, Adult: FormParts },
	form: Form,
	outline: Kind,
	bodyHeight: number, -- studs at scale 1
	follow: RigMath.Follow,
	scaleEase: RigMath.ScaleEase,
	-- animation state
	loop: Clip,
	phase: number,
	amp: number,
	period: number,
	-- what the rest of the client reads (09 §6.7: visuals read the rig, never the root)
	pos: Vector3,
	heading: Vector3,
	cframe: CFrame,
	glow: Glow?, -- set while the creature holds Glow
}

-- Clip IDs by clip name, filled by CreatureController from the manifest.
local clipIds: { [string]: number } = {}

--------------------------------------------------------------------------------------------------
-- Placeholder geometry: RIG_Fish (assets/source/_shared/blender/rigs.py, FishFit.bones) on the
-- family base body. Blender axes (−Y forward, +Z up, +X the creature's left) become Roblox axes
-- (−Z forward, +Y up, +X right): (x, y, z)_rbx = (−x, z, y)_blender. Body fractions run nose 0 to
-- tail 1 over the canon length 2.45 (nose −1.5, tail 0.95), then stretch to 02 §0.2's 3.0 studs.

local CANON_NOSE, CANON_LENGTH = -1.5, 2.45
local LENGTH_FIT = RigMath.BODY_LENGTH / CANON_LENGTH

local function frac(t: number): number
	return CANON_NOSE + CANON_LENGTH * t
end

-- name, parent, position in rig space at k = 1 (Roblox axes, canon units). Deform bones first,
-- then the ten sockets (06 §8.4). Parents come before children.
local BONES: { { any } } = {
	{ "Root", nil, Vector3.zero },
	{ "Spine2", "Root", Vector3.new(0, 0, frac(0.59)) },
	{ "Spine1", "Spine2", Vector3.new(0, 0, frac(0.37)) },
	{ "Spine3", "Root", Vector3.new(0, 0, frac(0.63)) },
	{ "Spine4", "Spine3", Vector3.new(0, 0, frac(0.80)) },
	{ "TailFin", "Spine4", Vector3.new(0, 0, frac(0.95)) },
	{ "Jaw", "Spine1", Vector3.new(0, -0.03, frac(0.22)) },
	{ "Dorsal", "Spine2", Vector3.new(0, 0.40, frac(0.55)) },
	{ "Pec_L", "Spine2", Vector3.new(-0.30, -0.12, frac(0.36)) },
	{ "Pec_R", "Spine2", Vector3.new(0.30, -0.12, frac(0.36)) },
	{ "Eye_L", "Spine1", Vector3.new(-0.26, 0.12, frac(0.12)) },
	{ "Eye_R", "Spine1", Vector3.new(0.26, 0.12, frac(0.12)) },
	{ "Lid_L", "Spine1", Vector3.new(-0.26, 0.12, frac(0.12)) },
	{ "Lid_R", "Spine1", Vector3.new(0.26, 0.12, frac(0.12)) },
	{ "Girth_Top", "Root", Vector3.new(0, 0.42, frac(0.50)) },
	{ "Girth_Bot", "Root", Vector3.new(0, -0.40, frac(0.50)) },
	{ "Girth_L", "Root", Vector3.new(-0.36, 0, frac(0.50)) },
	{ "Girth_R", "Root", Vector3.new(0.36, 0, frac(0.50)) },
	{ "Sock_Back_01", "Spine2", Vector3.new(0, 0.42, frac(0.47)) },
	{ "Sock_Back_02", "Spine3", Vector3.new(0, 0.36, frac(0.69)) },
	{ "Sock_Back_03", "Spine4", Vector3.new(0, 0.24, frac(0.81)) },
	{ "Sock_Flank_L", "Spine2", Vector3.new(-0.36, 0, frac(0.53)) },
	{ "Sock_Flank_R", "Spine2", Vector3.new(0.36, 0, frac(0.53)) },
	{ "Sock_Head", "Spine1", Vector3.new(0, 0.36, frac(0.12)) },
	{ "Sock_Tail", "Spine4", Vector3.new(0, 0.14, frac(0.94)) },
	{ "Sock_Crest", "Spine2", Vector3.new(0, 0.42, frac(0.33)) },
	{ "Sock_FinDorsal", "Dorsal", Vector3.new(0, 0.62, frac(0.52)) },
	{ "Sock_FinTail", "TailFin", Vector3.new(0, 0, 0.95 + 0.35) },
}

-- Visible pieces: name, bone, centre in rig space, size (x width, y height, z length), colour
-- key, shell? Sizes in canon units at k = 1.
local PIECES: { { any } } = {
	{
		"Head",
		"Spine1",
		Vector3.new(0, 0.02, frac(0.18)),
		Vector3.new(0.68, 0.78, 0.92),
		"mid",
		true,
	},
	{
		"Front",
		"Spine2",
		Vector3.new(0, 0, frac(0.46)),
		Vector3.new(0.74, 0.86, 1.02),
		"mid",
		true,
	},
	{
		"Mid",
		"Spine3",
		Vector3.new(0, -0.01, frac(0.68)),
		Vector3.new(0.58, 0.70, 0.88),
		"mid",
		true,
	},
	{ "Rear", "Spine4", Vector3.new(0, 0, frac(0.86)), Vector3.new(0.34, 0.42, 0.62), "mid", true },
	{
		"Belly",
		"Spine2",
		Vector3.new(0, -0.18, frac(0.42)),
		Vector3.new(0.62, 0.52, 1.10),
		"light",
		false,
	},
	{
		"Tail",
		"TailFin",
		Vector3.new(0, 0, frac(0.95) + 0.22),
		Vector3.new(0.07, 0.78, 0.46),
		"dark",
		true,
	},
	{
		"DorsalFin",
		"Dorsal",
		Vector3.new(0, 0.50, frac(0.55)),
		Vector3.new(0.06, 0.30, 0.55),
		"dark",
		false,
	},
	{
		"PecL",
		"Pec_L",
		Vector3.new(-0.40, -0.16, frac(0.40)),
		Vector3.new(0.30, 0.05, 0.22),
		"dark",
		false,
	},
	{
		"PecR",
		"Pec_R",
		Vector3.new(0.40, -0.16, frac(0.40)),
		Vector3.new(0.30, 0.05, 0.22),
		"dark",
		false,
	},
	{
		"EyeL",
		"Eye_L",
		Vector3.new(-0.27, 0.13, frac(0.12)),
		Vector3.new(0.27, 0.27, 0.27),
		"eye",
		false,
	},
	{
		"EyeR",
		"Eye_R",
		Vector3.new(0.27, 0.13, frac(0.12)),
		Vector3.new(0.27, 0.27, 0.27),
		"eye",
		false,
	},
	{
		"PupilL",
		"Eye_L",
		Vector3.new(-0.35, 0.14, frac(0.10)),
		Vector3.new(0.13, 0.15, 0.13),
		"ink",
		false,
	},
	{
		"PupilR",
		"Eye_R",
		Vector3.new(0.35, 0.14, frac(0.10)),
		Vector3.new(0.13, 0.15, 0.13),
		"ink",
		false,
	},
}
local BODY_HEIGHT = 0.86 -- canon units: the tallest body piece (Front)

-- 06 §5 species palettes (Light, Mid, Dark). Unknown species fall back to the Minnow's.
local PALETTES: { [string]: { light: string, mid: string, dark: string } } = {
	minnow = { light = "#FFE2A8", mid = "#FF9A3D", dark = "#922700" },
	puffer = { light = "#FFF6D6", mid = "#FFD84A", dark = "#B8791F" },
	eel = { light = "#E0D6FF", mid = "#8A6BF0", dark = "#3B2A8C" },
	turtle = { light = "#FFF1C2", mid = "#7CCB7A", dark = "#7A4A1E" },
	squid = { light = "#FFD1E0", mid = "#FF6FA3", dark = "#B8336B" },
	shark = { light = "#F2F7FA", mid = "#8FA9C4", dark = "#3D5878" },
}
local EYE_WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromHex("#14213D") -- 06 §5 ink navy

local function colourOf(species: string, key: string): Color3
	if key == "eye" then
		return EYE_WHITE
	elseif key == "ink" then
		return INK
	end
	local p = PALETTES[species] or PALETTES.minnow
	return Color3.fromHex(
		if key == "light" then p.light elseif key == "dark" then p.dark else p.mid
	)
end

local function setVisualPart(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	pcall(function() -- the group exists once the server registered it (09 §6.5)
		part.CollisionGroup = VISUAL_GROUP
	end)
end

local function newBones(root: BasePart, k: number): { [string]: Bone }
	local bones: { [string]: Bone } = {}
	local at: { [string]: Vector3 } = {}
	for _, row in BONES do
		local name, parentName, pos = row[1] :: string, row[2] :: string?, (row[3] :: Vector3) * k
		local bone = Instance.new("Bone")
		bone.Name = name
		local parentPos = if parentName then at[parentName] else Vector3.zero
		bone.Position = pos - parentPos
		bone.Parent = if parentName then bones[parentName] else root
		bones[name] = bone
		at[name] = pos
	end
	return bones
end

-- Holds `part` at `centre` (rig space) on `bone` with a RigidConstraint (06 §8.4, spike F14).
local function attach(part: BasePart, bone: Bone, centre: Vector3)
	local a = Instance.new("Attachment")
	a.Name = "RigAttach"
	-- part.CFrame = bone.WorldCFrame * offset, with the bones at rest and unrotated.
	a.CFrame = CFrame.new(bone.WorldPosition - centre)
	a.Parent = part
	local c = Instance.new("RigidConstraint")
	c.Attachment0 = bone
	c.Attachment1 = a
	c.Parent = part
end

local function buildPlaceholderForm(
	model: Model,
	root: BasePart,
	bones: { [string]: Bone },
	species: string,
	k: number,
	form: Form
): FormParts
	local folder = Instance.new("Model")
	folder.Name = form
	local parts: FormParts = { body = {}, thin = {}, thick = {}, hulls = {} }
	parts.thick = parts.thin -- one hull per piece, sized per colour by `fitHulls`
	-- The adult reads a little deeper in the body until its mesh exists (09 §6.9 placeholder).
	local depth = if form == "Adult" then 1.12 else 1
	for _, row in PIECES do
		local name, boneName = row[1] :: string, row[2] :: string
		local centre, size = (row[3] :: Vector3) * k, (row[4] :: Vector3) * k
		size = Vector3.new(size.X, size.Y * depth, size.Z)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = colourOf(species, row[5] :: string)
		p.Material = Enum.Material.SmoothPlastic
		p.CFrame = root.CFrame * CFrame.new(centre)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		setVisualPart(p)
		attach(p, bones[boneName], centre)
		p.Parent = folder
		table.insert(parts.body, p)
		if row[6] then
			-- Its outline hull is made on first use (`ensureHulls`): the mesh is built async.
			table.insert(parts.hulls, { body = p :: BasePart })
		end
	end
	parts.folder = folder
	if form == "Adult" then
		for _, p in parts.body do
			p.Transparency = 1
		end
	end
	folder.Parent = model
	return parts
end

local function newRigShell(species: string): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = `Rig_{species}`
	local root = Instance.new("Part")
	root.Name = "RootPart"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CastShadow = false
	pcall(function()
		root.CollisionGroup = VISUAL_GROUP
	end)
	root.Parent = model
	model.PrimaryPart = root
	return model, root
end

local function ensureAnimator(model: Model): Animator
	local controller = model:FindFirstChildOfClass("AnimationController")
	if controller == nil then
		local made = Instance.new("AnimationController")
		made.Parent = model
		controller = made
	end
	assert(controller, "AnimationController")
	local animator = controller:FindFirstChildOfClass("Animator")
	if animator == nil then
		local made = Instance.new("Animator")
		made.Parent = controller
		animator = made
	end
	assert(animator, "Animator")
	return animator
end

--------------------------------------------------------------------------------------------------
-- Imported templates (Studio-owned, 09 §3.1)

local templates: { [string]: Model | false } = {}

local function pascal(id: string): string
	return (string.gsub("_" .. id, "_(%w)", string.upper))
end

-- Adds one Bone per socket-table row under its parent bone (06 §8.4, spike F13).
local function buildSockets(template: Model)
	local value = template:FindFirstChild("Sockets")
	if not (value and value:IsA("StringValue")) then
		Log.warn(TAG, `{template.Name}: no Sockets table; kit pieces will have nowhere to attach`)
		return
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value.Value)
	if not ok or typeof(decoded) ~= "table" or typeof(decoded.sockets) ~= "table" then
		Log.warn(TAG, `{template.Name}: unreadable Sockets table`)
		return
	end
	for _, row in decoded.sockets do
		local parent = template:FindFirstChild(row.parent, true)
		if parent and parent:IsA("Bone") and template:FindFirstChild(row.name, true) == nil then
			local bone = Instance.new("Bone")
			bone.Name = row.name
			bone.CFrame = CFrame.new(table.unpack(row.cframe))
			bone.Parent = parent
		end
	end
end

local function templateFor(species: string): Model?
	local cached = templates[species]
	if cached ~= nil then
		return if cached == false then nil else cached :: Model
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Species")
	local source = folder
		and (folder:FindFirstChild(pascal(species)) or folder:FindFirstChild(species))
	if not (source and source:IsA("Model") and source:FindFirstChild("Juvenile", true)) then
		templates[species] = false
		return nil
	end
	local template = source:Clone()
	local root = template.PrimaryPart or template:FindFirstChildWhichIsA("BasePart")
	if root == nil then
		templates[species] = false
		return nil
	end
	template.PrimaryPart = root
	for _, d in template:GetDescendants() do
		if d:IsA("BasePart") then
			setVisualPart(d)
			if d:IsA("MeshPart") then
				d.Color = Color3.new(1, 1, 1) -- spike S0-A1: the importer leaves it grey
			end
		end
	end
	root.Anchored = true
	buildSockets(template)
	ensureAnimator(template)
	templates[species] = template
	return template
end

local function formFromTemplate(model: Model, form: Form): FormParts
	local parts: FormParts = { body = {}, thin = {}, thick = {}, hulls = {} }
	local body = model:FindFirstChild(form, true)
	if body and body:IsA("BasePart") then
		table.insert(parts.body, body)
		body.Transparency = if form == "Juvenile" then 0 else 1
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == form .. "_Shell" then
				table.insert(parts.thin, d)
			elseif d.Name == form .. "_ShellThick" then
				table.insert(parts.thick, d)
			end
		end
	end
	local lists: { { BasePart } } = { parts.thin, parts.thick }
	for _, list in lists do
		for _, s in list do
			s.Material = Outlines.MATERIAL -- 06 §13.2 matte fallback
			s.Transparency = 1
		end
	end
	if #parts.thick == 0 then
		parts.thick = parts.thin
	end
	return parts
end

--------------------------------------------------------------------------------------------------
-- Public API

--- Clip asset IDs by clip name (RigMath.CLIPS). Rigs built after
--- this call load the clips that have an ID.
function CreatureRig.setClipIds(ids: { [string]: number })
	clipIds = ids
end

--- Builds a rig for `species` at scale 1 for `radiusMult` (the placeholder is sized to the
--- species' collision ball). Not parented; the caller parents and places it.
function CreatureRig.new(species: string, radiusMult: number): Rig
	local template = templateFor(species)
	local model: Model, root: BasePart
	local juvenile: FormParts, adult: FormParts
	local bones: { [string]: Bone } = {}
	local bodyHeight: number
	if template then
		model = template:Clone()
		root = model.PrimaryPart :: BasePart
		for _, d in model:GetDescendants() do
			if d:IsA("Bone") then
				bones[d.Name] = d
			end
		end
		juvenile = formFromTemplate(model, "Juvenile")
		adult = formFromTemplate(model, "Adult")
		local body = juvenile.body[1]
		bodyHeight = if body then body.Size.Y else BODY_HEIGHT
	else
		local k = LENGTH_FIT * radiusMult
		model, root = newRigShell(species)
		bones = newBones(root, k)
		juvenile = buildPlaceholderForm(model, root, bones, species, k, "Juvenile")
		-- 09 §6.9: both forms are in the rig before it spawns; the swap is S9-C1.
		adult = buildPlaceholderForm(model, root, bones, species, k, "Adult")
		bodyHeight = BODY_HEIGHT * k
	end
	local animator = ensureAnimator(model)
	local rig: Rig = {
		model = model,
		root = root,
		species = species,
		placeholder = template == nil,
		bones = bones,
		animator = animator,
		tracks = {},
		forms = { Juvenile = juvenile, Adult = adult },
		form = "Juvenile",
		outline = "none",
		bodyHeight = bodyHeight,
		follow = RigMath.newFollow(),
		scaleEase = RigMath.newScale(1),
		loop = "Idle",
		phase = 0,
		amp = RigMath.SWAY_AMP.Idle,
		period = RigMath.CLIP_SECONDS.Idle,
		pos = root.Position,
		heading = Vector3.new(0, 0, -1),
		cframe = root.CFrame,
		glow = nil,
	}
	for _, clip in RigMath.CLIPS do
		local id = clipIds[clip]
		if id then
			local animation = Instance.new("Animation")
			animation.AnimationId = `rbxassetid://{id}`
			local ok, track = pcall(animator.LoadAnimation, animator, animation)
			if ok and track then
				track.Looped = RigMath.SWAY_AMP[clip] ~= nil
				rig.tracks[clip] = track
			else
				Log.warn(TAG, `clip {clip} ({id}) did not load; using the code sway`)
			end
		end
	end
	return rig
end

local function formParts(rig: Rig, form: Form): FormParts
	return if form == "Adult" then rig.forms.Adult else rig.forms.Juvenile
end

--- The current scale (what `Model:ScaleTo` last set).
function CreatureRig.scale(rig: Rig): number
	return rig.scaleEase.value
end

--- Applies an eased scale value (09 §6.8, `Model:ScaleTo`, V27). Cheap when unchanged.
function CreatureRig.applyScale(rig: Rig, scale: number)
	if math.abs(rig.model:GetScale() - scale) > 1e-4 then
		rig.model:ScaleTo(scale)
		local glow = rig.glow
		if glow then
			glow.light.Range = TraitRules.GLOW_LIGHT -- 02 §8.4: 20 studs at every size
		end
	end
end

-- Placeholder shells: the body piece's current size plus twice the line width on each axis.
local function fitHulls(rig: Rig, kind: Kind)
	local t = OutlineRules.thickness(rig.bodyHeight * rig.scaleEase.value, kind, false)
	local grow = Vector3.new(2 * t, 2 * t, 2 * t)
	for _, h in formParts(rig, rig.form).hulls do
		local part = h.part
		if part then
			part.Size = h.body.Size + grow
		end
	end
end

-- Placeholder only: makes the form's missing hulls once the hull mesh is ready, each held to
-- its body piece's bone at the body piece's offset. True when the form has all of them.
local function ensureHulls(parts: FormParts): boolean
	if #parts.thin == #parts.hulls then
		return true
	end
	for _, h in parts.hulls do
		local body = h.body
		local at = body:FindFirstChild("RigAttach") :: Attachment?
		local bone = at and body:FindFirstChildOfClass("RigidConstraint")
		local boneAt = bone and (bone :: RigidConstraint).Attachment0
		if not h.part and at and boneAt then
			local s = HullMesh.new(body.Name .. "_Shell", body.Size)
			if not s then
				return false
			end
			s.CFrame = body.CFrame
			local a = Instance.new("Attachment")
			a.Name = "RigAttach"
			a.CFrame = at.CFrame
			a.Parent = s
			local c = Instance.new("RigidConstraint")
			c.Attachment0 = boneAt
			c.Attachment1 = a
			c.Parent = s
			setVisualPart(s)
			s.Parent = parts.folder
			h.part = s
			table.insert(parts.thin, s)
		end
	end
	return #parts.thin == #parts.hulls
end

--- Shows the outline of `kind` in `colour` on the visible form, or hides it ("none").
function CreatureRig.setOutline(rig: Rig, kind: Kind, colour: Color3)
	local parts = formParts(rig, rig.form)
	-- A placeholder whose hulls were not made yet (mesh still building) shows its outline as soon
	-- as they are: until then it reads as having none, so the next call retries.
	if rig.placeholder and kind ~= "none" and rig.outline ~= kind and not ensureHulls(parts) then
		return
	end
	if kind ~= rig.outline then
		for _, s in parts.thin do
			s.Transparency = 1
		end
		for _, s in parts.thick do
			s.Transparency = 1
		end
		rig.outline = kind
		if kind ~= "none" then
			local list: { BasePart } = if kind == "dangerous" then parts.thick else parts.thin
			for _, s in list do
				s.Transparency = 0
			end
		end
		if rig.placeholder and kind ~= "none" then
			fitHulls(rig, kind)
		end
	end
	if kind ~= "none" then
		local list: { BasePart } = if kind == "dangerous" then parts.thick else parts.thin
		for _, s in list do
			s.Color = colour
		end
	end
end

--- Re-fits the placeholder line after a scale ease ends (its thickness has a floor in studs).
function CreatureRig.refitOutline(rig: Rig)
	if rig.placeholder and rig.outline ~= "none" then
		fitHulls(rig, rig.outline)
	end
end

--- Shows one form and hides the other (09 §6.9; the FX_Metamorph cover is S9-C1).
function CreatureRig.setForm(rig: Rig, form: Form)
	if form == rig.form or #formParts(rig, form).body == 0 then
		return
	end
	local outline: Kind = rig.outline
	local lit = formParts(rig, rig.form).thin[1]
	local colour = if lit then lit.Color else Color3.new(1, 1, 1)
	CreatureRig.setOutline(rig, "none", Color3.new())
	for _, p in formParts(rig, rig.form).body do
		p.Transparency = 1
	end
	for _, p in formParts(rig, form).body do
		p.Transparency = 0
	end
	rig.form = form
	rig.outline = "none"
	if outline ~= "none" then
		CreatureRig.setOutline(rig, outline, colour)
	end
	local glow = rig.glow
	if glow then
		for _, o in glow.overlays.Juvenile do
			o.Transparency = if form == "Juvenile" then GLOW_OVERLAY_TRANSPARENCY else 1
		end
		for _, o in glow.overlays.Adult do
			o.Transparency = if form == "Adult" then GLOW_OVERLAY_TRANSPARENCY else 1
		end
	end
end

-- The flat tint overlay of one form's body pieces (see `Glow`).
local function glowOverlays(parts: FormParts, shown: boolean): { BasePart }
	local list: { BasePart } = {}
	for _, body in parts.body do
		local o = body:Clone()
		o:ClearAllChildren()
		o.Name = body.Name .. "_GlowTint"
		o.Size = body.Size * GLOW_OVERLAY_GROW
		o.CFrame = body.CFrame
		o.Material = Enum.Material.SmoothPlastic
		o.Color = GLOW_COLOUR
		o.Transparency = if shown then GLOW_OVERLAY_TRANSPARENCY else 1
		setVisualPart(o)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = o
		weld.Parent = o
		o.Parent = body.Parent
		table.insert(list, o)
	end
	return list
end

--- Glow's look (02 §8.4, 04 B5 "the body lights up"): the body light, radius 20 studs, and the
--- placeholder tint overlay; off removes both. Cheap when unchanged.
--- TODO(B19): off while camouflaged and not seen from outside an ink cloud (02 §8.7).
function CreatureRig.setGlow(rig: Rig, on: boolean)
	local glow = rig.glow
	if on == (glow ~= nil) then
		return
	end
	if glow then
		glow.light:Destroy()
		for _, list in { glow.overlays.Juvenile, glow.overlays.Adult } do
			for _, o in list do
				o:Destroy()
			end
		end
		rig.glow = nil
		return
	end
	local light = Instance.new("PointLight")
	light.Name = "GlowLight"
	light.Color = GLOW_COLOUR
	light.Brightness = GLOW_BRIGHTNESS
	light.Range = TraitRules.GLOW_LIGHT
	light.Shadows = false
	light.Parent = rig.root
	rig.glow = {
		light = light,
		overlays = {
			Juvenile = glowOverlays(rig.forms.Juvenile, rig.form == "Juvenile"),
			Adult = glowOverlays(rig.forms.Adult, rig.form == "Adult"),
		},
	}
end

--- Whether `clip` is loaded on this rig (its asset ID is in the manifest and it loaded).
function CreatureRig.hasClip(rig: Rig, clip: Clip): boolean
	local track: AnimationTrack? = rig.tracks[clip]
	return track ~= nil
end

--- Plays a one-shot clip ("Dash", "Bite" or "TierUp") when it is uploaded; the code sway has no one-shots
--- yet (the jaw and the dash squash are code-owned bones for a later task).
function CreatureRig.playAction(rig: Rig, clip: Clip)
	local track = rig.tracks[clip]
	if track then
		track:Play(0.05)
	end
end

local swayBones = RigMath.SWAY

--- Animates one frame at `speed` studs/s against `topSpeed`. With clips: crossfades the loops.
--- Without: advances the phase and writes the sway onto the bones (render step, after the
--- Animator). Hot path: no allocation beyond the CFrames it writes.
function CreatureRig.animate(rig: Rig, dt: number, speed: number, topSpeed: number)
	local loop: Clip = RigMath.loopFor(speed, topSpeed) :: Clip
	if next(rig.tracks) ~= nil then
		if loop ~= rig.loop or not (rig.tracks[loop] and rig.tracks[loop].IsPlaying) then
			local old = rig.tracks[rig.loop]
			if old and loop ~= rig.loop then
				old:Stop(0.2)
			end
			local new = rig.tracks[loop]
			if new and not new.IsPlaying then
				new:Play(0.2)
			end
		end
		rig.loop = loop
		return
	end
	rig.loop = loop
	rig.amp = rig.amp + (RigMath.SWAY_AMP[loop] - rig.amp) * (1 - math.exp(-dt / RigMath.TAU_SWAY))
	rig.period = rig.period
		+ (RigMath.CLIP_SECONDS[loop] - rig.period) * (1 - math.exp(-dt / RigMath.TAU_SWAY))
	rig.phase = (rig.phase + dt / rig.period) % 1
	local bones = rig.bones
	for _, b in swayBones do
		local bone = bones[b.name]
		if bone then
			local yaw, roll = RigMath.sway(b, rig.phase, rig.amp)
			bone.Transform = CFrame.Angles(0, yaw, roll)
		end
	end
	local flap = RigMath.pecFlap(rig.phase, if loop == "SwimFast" then 0.3 else 1)
	local pecL, pecR = bones.Pec_L, bones.Pec_R
	if pecL and pecR then
		pecL.Transform = CFrame.Angles(0, 0, flap)
		pecR.Transform = CFrame.Angles(0, 0, -flap)
	end
end

function CreatureRig.destroy(rig: Rig)
	for _, track in rig.tracks do
		track:Stop(0)
		track:Destroy()
	end
	table.clear(rig.tracks)
	rig.model:Destroy()
end

return CreatureRig
