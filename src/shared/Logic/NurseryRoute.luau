--!strict
-- NurseryRoute: the first-run route through the Nursery and the Elbow, and the volumes that lay it
-- out in the place (task S6-D1; docs/03, section 6.2 data:NurseryPath owns the places; docs/04,
-- section 3.5 owns the distances; docs/09, section 9.1 `NurseryPath` and `HatchBed`). Tables and
-- numbers only, so it runs in Lune; tools/studio/place_nursery_volumes.luau, the CI arena and the
-- tutorial read it.
--
-- The route starts at the Hatch Bed facing east and runs along one arc (radius 140, 45° to the
-- left) to the kelp curtain, then straight through Little Arch and the two legs of the Elbow to
-- the Home Current mouth. Y is up and the surface is Y 0, so depth d is Y −d; north is −Z.
local Defaults = require("../Config/Defaults")
local NurseryPath = require("../Data/Generated/NurseryPath")
local Types = require("../Types")

type NurseryPointDef = Types.NurseryPointDef

local N = Defaults.nursery

local NurseryRoute = {}

--- The `Kind` of a route volume (09 §9.1); its `PointId` is the data:NurseryPath row ID.
NurseryRoute.KIND = "NurseryPath"

local byId: { [string]: NurseryPointDef } = {}
for _, def in NurseryPath do
	byId[def.id] = def
end

local function row(id: string): NurseryPointDef
	local def = byId[id]
	if def == nil then
		error(`NurseryRoute: data:NurseryPath has no row {id}`)
	end
	return def
end

local HATCH = row("hatch_bed")
local RADIUS = N.arcRadius
-- The straight stretches after the arc, in route order (03 §6.2).
local STRAIGHT = table.freeze({ row("little_arch"), row("elbow_leg_1"), row("elbow_leg_2") })

--- Length of the arc from the Hatch Bed (about 110: it ends at the kelp curtain).
NurseryRoute.ARC_LENGTH = RADIUS * math.rad(N.arcTurn)
--- Length of the whole route, Hatch Bed to the Home Current mouth (335).
NurseryRoute.LENGTH = STRAIGHT[#STRAIGHT].to

-- The stretch holding distance `s` past the arc, and how far along it (0 to 1).
local function straightAt(s: number): (NurseryPointDef, number)
	for _, def in STRAIGHT do
		if s <= def.to then
			return def, math.clamp((s - def.at) / (def.to - def.at), 0, 1)
		end
	end
	return STRAIGHT[#STRAIGHT], 1
end

--- The route's (x, z) at distance `s` from the Hatch Bed, clamped to the route.
function NurseryRoute.pointAt(s: number): (number, number)
	s = math.clamp(s, 0, NurseryRoute.LENGTH)
	if s <= NurseryRoute.ARC_LENGTH then
		-- Facing east (+X) and turning left (toward −Z): the centre is RADIUS north of the start.
		local a = s / RADIUS
		return HATCH.x + RADIUS * math.sin(a), HATCH.z - RADIUS + RADIUS * math.cos(a)
	end
	local def, t = straightAt(s)
	return def.x + (def.toX - def.x) * t, def.z + (def.toZ - def.z) * t
end

--- The route's heading at distance `s`, a unit (x, z).
function NurseryRoute.headingAt(s: number): (number, number)
	s = math.clamp(s, 0, NurseryRoute.LENGTH)
	if s <= NurseryRoute.ARC_LENGTH then
		local a = s / RADIUS
		return math.cos(a), -math.sin(a)
	end
	local def = straightAt(s)
	local dx, dz = def.toX - def.x, def.toZ - def.z
	local length = math.sqrt(dx * dx + dz * dz)
	return dx / length, dz / length
end

--- One part to author: its name, `Kind`, `PointId` (nil for the HatchBed), shape, frame as 12
--- numbers (position, then the rotation by rows, as `CFrame.new` and ci.project.json take them)
--- and size (X, Y, Z).
export type Volume = {
	name: string,
	kind: string,
	pointId: string?,
	shape: string, -- "Block", "Ball" or "Cylinder"
	frame: { number },
	size: { number },
}

-- A frame at (x, y, z) whose look vector is the horizontal (lx, lz): X = look × up, Y up.
local function facing(x: number, y: number, z: number, lx: number, lz: number): { number }
	return { x, y, z, -lz, 0, -lx, 0, 1, 0, lx, 0, -lz }
end

-- A frame at (x, y, z) with the local X axis up: an upright Cylinder (its axis is local X).
local function upright(x: number, y: number, z: number): { number }
	return { x, y, z, 0, -1, 0, 1, 0, 0, 0, 0, 1 }
end

-- The deepest point of a row's band, and the Y of its middle (a floor point sits on the floor).
local function band(def: NurseryPointDef): (number, number)
	local deepest = math.max(def.bottom, def.toBottom)
	return deepest - def.top, -(def.top + deepest) / 2
end

-- Widths across the route (03 §6.2, 04 §3.5); any other stretch is a marker.
local WIDTH: { [string]: number } = {
	little_arch = N.archWidth,
	elbow_leg_1 = N.channelWidth,
	elbow_leg_2 = N.channelWidth,
}

local function volumeOf(def: NurseryPointDef): Volume
	local m = N.markerSize
	local height, midY = band(def)
	local name = `Nursery_{def.id}`
	if def.id == "hatch_bed" then
		-- 09 §9.1 HatchBed: a small Ball on the egg, facing along the route (03 §6.2).
		local hx, hz = NurseryRoute.headingAt(0)
		return {
			name = "HatchBed",
			kind = "HatchBed",
			pointId = nil,
			shape = "Ball",
			frame = facing(def.x, -def.bottom, def.z, hx, hz),
			size = { m, m, m },
		}
	elseif def.to > def.at then
		-- A stretch: a Block from its start to its end, looking along the route.
		local dx, dz = def.toX - def.x, def.toZ - def.z
		local length = math.sqrt(dx * dx + dz * dz)
		local cx, cz = (def.x + def.toX) / 2, (def.z + def.toZ) / 2
		return {
			name = name,
			kind = NurseryRoute.KIND,
			pointId = def.id,
			shape = "Block",
			frame = facing(cx, midY, cz, dx / length, dz / length),
			size = { WIDTH[def.id] or m, if height > 0 then height else m, length },
		}
	elseif def.id == "kelp_curtain" then
		-- Across the Nursery end of Little Arch: the arch's opening, a thin slab.
		local hx, hz = NurseryRoute.headingAt(def.at)
		return {
			name = name,
			kind = NurseryRoute.KIND,
			pointId = def.id,
			shape = "Block",
			frame = facing(def.x, midY, def.z, hx, hz),
			size = { N.archWidth, height, N.curtainThickness },
		}
	elseif def.id == "elbow_bend" then
		-- An upright Cylinder as wide as the channel, so the two legs join without a gap.
		return {
			name = name,
			kind = NurseryRoute.KIND,
			pointId = def.id,
			shape = "Cylinder",
			frame = upright(def.x, midY, def.z),
			size = { height, N.channelWidth, N.channelWidth },
		}
	end
	-- A point: a marker Ball at its place (a landmark's, when it has one), facing along the
	-- route, or from the landmark toward its route point.
	local x, z = def.markX or def.x, def.markZ or def.z
	local lx, lz = NurseryRoute.headingAt(def.at)
	if def.markX ~= nil then
		local dx, dz = def.x - x, def.z - z
		local length = math.sqrt(dx * dx + dz * dz)
		lx, lz = dx / length, dz / length
	end
	local y = if def.floor then -def.bottom else midY
	return {
		name = name,
		kind = NurseryRoute.KIND,
		pointId = def.id,
		shape = "Ball",
		frame = facing(x, y, z, lx, lz),
		size = { m, m, m },
	}
end

--- Every volume of the route in data:NurseryPath order: the `HatchBed` first, then one
--- `NurseryPath` volume per other row.
function NurseryRoute.volumes(): { Volume }
	local out = table.create(#NurseryPath)
	for _, def in NurseryPath do
		table.insert(out, volumeOf(def))
	end
	return out
end

return table.freeze(NurseryRoute)
