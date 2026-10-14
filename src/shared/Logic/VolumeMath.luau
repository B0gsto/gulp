--!strict
-- VolumeMath: the pure arithmetic of the gameplay volumes of docs/09, section 9.1. WorldIndex
-- builds `Volume` records from tagged parts at server start; the same tests run on clients from
-- the `WorldInfo` table. Numbers and tables only (section 4.4), so it runs in Lune.
--
-- Shapes follow the engine's part shapes: a Ball's radius is half its smallest size, a Cylinder's
-- axis is its local X with a radius of half the smaller of its Y and Z sizes.
local Types = require("../Types")

type Volume = Types.Volume
type VolumeKind = Types.VolumeKind
type VolumeShape = Types.VolumeShape
type VolumeAttribute = Types.VolumeAttribute

local VolumeMath = {}

--- Every `Kind` of the section 9.1 table.
local KINDS: { VolumeKind } = {
	"Zone",
	"SafeNursery",
	"CoveMouth",
	"CoveInterior",
	"PreySpawn",
	"Current",
	"EelHole",
	"Hazard",
	"GullSky",
	"MorayHole",
	"PredatorNode",
	"RevivePoint",
	"HatchBed", -- a Ball: only its centre and look vector are kept (RunLoopService.join)
}
VolumeMath.KINDS = table.freeze(KINDS)

--- Kinds inside which a creature cannot be bitten by a player (section 10.2, rule 3).
VolumeMath.SAFE_KINDS =
	table.freeze({ "SafeNursery", "CoveMouth", "CoveInterior" } :: { VolumeKind })

--- Cove numbers run 1 to 24, one per slot (section 5.1).
VolumeMath.COVES = 24

local shapes: { [string]: VolumeShape } = { Block = "Block", Ball = "Ball", Cylinder = "Cylinder" }
local kinds: { [string]: VolumeKind } = {}
for _, kind in KINDS do
	kinds[kind] = kind
end

--- A `Kind` attribute as a volume kind, or nil when it is not one of section 9.1.
function VolumeMath.kindOf(value: VolumeAttribute?): VolumeKind?
	return if type(value) == "string" then kinds[value] else nil
end

--- A part shape's name as a volume shape, or nil for any other shape.
function VolumeMath.shapeOf(name: string): VolumeShape?
	return shapes[name]
end

--- The inverse of a rigid frame given as 12 numbers (position, then the rotation by rows).
function VolumeMath.inverse(c: { number }): { number }
	local x, y, z = c[1], c[2], c[3]
	-- The rotation is orthonormal, so its inverse is its transpose.
	local r00, r01, r02 = c[4], c[7], c[10]
	local r10, r11, r12 = c[5], c[8], c[11]
	local r20, r21, r22 = c[6], c[9], c[12]
	return {
		-(r00 * x + r01 * y + r02 * z),
		-(r10 * x + r11 * y + r12 * z),
		-(r20 * x + r21 * y + r22 * z),
		r00,
		r01,
		r02,
		r10,
		r11,
		r12,
		r20,
		r21,
		r22,
	}
end

--- Builds a volume from a part's frame (12 numbers), its size and its attributes.
function VolumeMath.new(
	kind: VolumeKind,
	shape: VolumeShape,
	frame: { number },
	sx: number,
	sy: number,
	sz: number,
	attrs: { [string]: VolumeAttribute }
): Volume
	return table.freeze({
		kind = kind,
		shape = shape,
		inv = table.freeze(VolumeMath.inverse(frame)),
		hx = sx / 2,
		hy = sy / 2,
		hz = sz / 2,
		attrs = table.freeze(table.clone(attrs)),
	})
end

--- A world point in the volume's local space.
function VolumeMath.toLocal(v: Volume, x: number, y: number, z: number): (number, number, number)
	local m = v.inv
	return m[4] * x + m[5] * y + m[6] * z + m[1],
		m[7] * x + m[8] * y + m[9] * z + m[2],
		m[10] * x + m[11] * y + m[12] * z + m[3]
end

--- The volume's centre in world space.
function VolumeMath.centre(v: Volume): (number, number, number)
	local m = v.inv
	-- inv holds Rᵀ and -Rᵀ·p, so the centre p is -R·(inv position); R is the transpose of Rᵀ.
	return -(m[4] * m[1] + m[7] * m[2] + m[10] * m[3]),
		-(m[5] * m[1] + m[8] * m[2] + m[11] * m[3]),
		-(m[6] * m[1] + m[9] * m[2] + m[12] * m[3])
end

--- The direction a part faces (its look vector, the negated local Z axis), used by `Current`.
function VolumeMath.lookVector(v: Volume): (number, number, number)
	local m = v.inv
	return -m[10], -m[11], -m[12]
end

--- True when the point is inside the volume or on its surface.
function VolumeMath.contains(v: Volume, x: number, y: number, z: number): boolean
	local lx, ly, lz = VolumeMath.toLocal(v, x, y, z)
	if v.shape == "Ball" then
		local r = math.min(v.hx, v.hy, v.hz)
		return lx * lx + ly * ly + lz * lz <= r * r
	elseif v.shape == "Cylinder" then
		local r = math.min(v.hy, v.hz)
		return math.abs(lx) <= v.hx and ly * ly + lz * lz <= r * r
	end
	return math.abs(lx) <= v.hx and math.abs(ly) <= v.hy and math.abs(lz) <= v.hz
end

--- Distance from the point to the volume; 0 inside.
function VolumeMath.distance(v: Volume, x: number, y: number, z: number): number
	local lx, ly, lz = VolumeMath.toLocal(v, x, y, z)
	if v.shape == "Ball" then
		local r = math.min(v.hx, v.hy, v.hz)
		return math.max(math.sqrt(lx * lx + ly * ly + lz * lz) - r, 0)
	elseif v.shape == "Cylinder" then
		local r = math.min(v.hy, v.hz)
		local axial = math.max(math.abs(lx) - v.hx, 0)
		local radial = math.max(math.sqrt(ly * ly + lz * lz) - r, 0)
		return math.sqrt(axial * axial + radial * radial)
	end
	local dx = math.max(math.abs(lx) - v.hx, 0)
	local dy = math.max(math.abs(ly) - v.hy, 0)
	local dz = math.max(math.abs(lz) - v.hz, 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

--- The space the volume encloses, in cubic studs.
function VolumeMath.measure(v: Volume): number
	if v.shape == "Ball" then
		local r = math.min(v.hx, v.hy, v.hz)
		return 4 / 3 * math.pi * r * r * r
	elseif v.shape == "Cylinder" then
		local r = math.min(v.hy, v.hz)
		return math.pi * r * r * 2 * v.hx
	end
	return 8 * v.hx * v.hy * v.hz
end

--- Checks a part's `Kind` and the attributes WorldIndex itself reads. `zones` is the set of known
--- zone IDs. Other kind-specific attributes are checked by the service that uses them.
function VolumeMath.validate(
	attrs: { [string]: VolumeAttribute },
	zones: { [string]: boolean }
): (boolean, string?)
	local kind = attrs.Kind
	if VolumeMath.kindOf(kind) == nil then
		return false, `unknown Kind {tostring(kind)}`
	end
	if kind == "Zone" then
		local id = attrs.ZoneId
		if type(id) ~= "string" or not zones[id] then
			return false, `Zone with unknown ZoneId {tostring(id)}`
		end
	elseif kind == "CoveMouth" or kind == "CoveInterior" then
		local index = attrs.CoveIndex
		if
			type(index) ~= "number"
			or index ~= math.floor(index)
			or index < 1
			or index > VolumeMath.COVES
		then
			return false, `{kind} with CoveIndex {tostring(index)}, not 1 to {VolumeMath.COVES}`
		end
	elseif kind == "RevivePoint" then
		if type(attrs.PointId) ~= "string" then
			return false, "RevivePoint without a PointId"
		end
	end
	return true, nil
end

--- Orders zone volumes for `zoneAt`: the smallest first, so a zone nested inside another (the
--- Nursery inside open water, a landmark inside its zone) wins where they overlap. Ties go to
--- the lower ZoneId, then the lower centre, so the order never depends on authoring order.
function VolumeMath.sortZones(zones: { Volume })
	table.sort(zones, function(a: Volume, b: Volume): boolean
		local ma, mb = VolumeMath.measure(a), VolumeMath.measure(b)
		if ma ~= mb then
			return ma < mb
		end
		local ia, ib = tostring(a.attrs.ZoneId), tostring(b.attrs.ZoneId)
		if ia ~= ib then
			return ia < ib
		end
		local ax, ay, az = VolumeMath.centre(a)
		local bx, by, bz = VolumeMath.centre(b)
		if ax ~= bx then
			return ax < bx
		elseif ay ~= by then
			return ay < by
		end
		return az < bz
	end)
end

--- The zone at a point, from zone volumes ordered by `sortZones`: the first that contains the
--- point, else the nearest one (water outside every zone volume belongs to the closest zone).
--- Nil only when there are no zone volumes at all.
function VolumeMath.zoneAt(sortedZones: { Volume }, x: number, y: number, z: number): string?
	for _, v in sortedZones do
		if VolumeMath.contains(v, x, y, z) then
			return v.attrs.ZoneId :: string -- safe: validate() accepted only string ZoneIds
		end
	end
	local best: Volume? = nil
	local bestDistance = math.huge
	for _, v in sortedZones do
		local d = VolumeMath.distance(v, x, y, z)
		if d < bestDistance then
			best, bestDistance = v, d
		end
	end
	return if best then best.attrs.ZoneId :: string else nil -- safe: as above
end

--- The first volume of the list that contains the point, or nil.
function VolumeMath.firstContaining(list: { Volume }, x: number, y: number, z: number): Volume?
	for _, v in list do
		if VolumeMath.contains(v, x, y, z) then
			return v
		end
	end
	return nil
end

return VolumeMath
