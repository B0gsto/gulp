--!strict
-- Render/HullMesh (task S3-C6 fix; docs/06 section 13.2, docs/09 section 8.8): the outline shell
-- for placeholder bodies, which have no exported `_Shell` mesh. It is the bible's method on a
-- primitive: an ellipsoid hull with its faces flipped, so back-face culling hides the side facing
-- the camera and only the far inside shows around the body's edge. Sized to the body plus twice
-- the line width, it draws a rim of that width from any camera, with no per-frame work.
--
-- Why not the earlier stand-ins: a negative `SpecialMesh.Scale` does not flip faces (a solid neon
-- ellipsoid over the body, measured for S3-C6), and a larger shell pushed behind the body from
-- the camera drew a solid blob wherever the push was not run every frame or the camera was close.
-- `Highlight` is not used anywhere (canon 5.2, 06 §13.2, 09 §8.8).
--
-- The mesh is a unit sphere built once per client with `EditableMesh`; every shell is a clone of
-- the one `MeshPart` made from it. Building it yields, so it starts when this module is required;
-- until it is ready `new` returns nil and callers retry on their next outline update. If the engine
-- refuses (memory budget), placeholders draw no outline rather than a blob, and it says so once.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Outlines = require(script.Parent.Outlines)

local HullMesh = {}

local TAG = "HullMesh"
local RINGS = 12 -- latitude bands
local SEGMENTS = 20 -- longitude slices: 440 triangles in all

local template: MeshPart? = nil
local failed = false

-- Unit sphere (bounding box 1 stud), every triangle wound the reverse of an outward face, so its
-- front faces point inward: the inverted hull.
local function build(): MeshPart
	local mesh = AssetService:CreateEditableMesh()
	local top = mesh:AddVertex(Vector3.new(0, 0.5, 0))
	local bottom = mesh:AddVertex(Vector3.new(0, -0.5, 0))
	local rows: { { number } } = {}
	for r = 1, RINGS - 1 do
		local lat = math.pi * r / RINGS
		local y, ring = 0.5 * math.cos(lat), 0.5 * math.sin(lat)
		local row = {}
		for s = 0, SEGMENTS - 1 do
			local lon = 2 * math.pi * s / SEGMENTS
			row[s + 1] = mesh:AddVertex(Vector3.new(ring * math.cos(lon), y, ring * math.sin(lon)))
		end
		rows[r] = row
	end
	-- Outward-facing order is (a, b, c) going top → bottom and +longitude; the hull adds (a, c, b).
	local function tri(a: number, b: number, c: number)
		mesh:AddTriangle(a, c, b)
	end
	for s = 1, SEGMENTS do
		local n = s % SEGMENTS + 1
		tri(top, rows[1][n], rows[1][s])
		tri(bottom, rows[RINGS - 1][s], rows[RINGS - 1][n])
		for r = 1, RINGS - 2 do
			local a, b = rows[r][s], rows[r][n]
			local c, d = rows[r + 1][s], rows[r + 1][n]
			tri(a, b, d)
			tri(a, d, c)
		end
	end
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
	part.Name = "HullShell"
	part.Material = Outlines.MATERIAL -- 06 §13.2 matte fallback
	part.Transparency = 1
	part.CastShadow = false
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	return part
end

task.spawn(function()
	local ok, result = pcall(build)
	if ok then
		template = result
	else
		failed = true
		Log.warn(TAG, `placeholder outline hull not built ({result}); placeholders draw no outline`)
	end
end)

--- Whether the hull mesh is built (false while building and after a failure).
function HullMesh.ready(): boolean
	return template ~= nil
end

--- Whether building the hull failed for good.
function HullMesh.failed(): boolean
	return failed
end

--- A new hidden hull named `name`, `size` studs across (body size plus twice the line
--- width), or nil while the mesh is not built yet.
function HullMesh.new(name: string, size: Vector3): MeshPart?
	local t = template
	if not t then
		return nil
	end
	local part = t:Clone()
	part.Name = name
	part.Size = size
	return part
end

return HullMesh
