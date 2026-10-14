--!strict
-- HeightFieldMath: the pure part of WorldIndex's floor height field and segment test (docs/09,
-- sections 9.1 and 7.2). The field is 256 × 256 `u16` values over 8-stud cells, covering the map
-- from -1,024 to +1,024 in X and Z (section 6.5). Each value is the floor height at the cell
-- centre, stored in 1/64 stud steps above the map floor at Y = -600. Numbers and buffers only
-- (section 4.4), so it runs in Lune.
local HeightFieldMath = {}

HeightFieldMath.SIZE = 256 -- cells per side
HeightFieldMath.CELL = 8 -- studs per cell
HeightFieldMath.ORIGIN = -1024 -- world X and Z of the first cell's outer edge
HeightFieldMath.Y_MIN = -600 -- the map floor (section 6.5); a ray that hits nothing stores this
HeightFieldMath.Y_MAX = 96 -- the top of the map (section 6.5)
HeightFieldMath.STEPS = 64 -- stored steps per stud: (96 + 600) × 64 = 44,544 fits a u16
HeightFieldMath.BYTES = HeightFieldMath.SIZE * HeightFieldMath.SIZE * 2

--- The share of a segment's end in which a wall hit is ignored (section 7.2, "Inside solid").
HeightFieldMath.SEGMENT_END_SLACK = 0.02

local SIZE, CELL, ORIGIN = HeightFieldMath.SIZE, HeightFieldMath.CELL, HeightFieldMath.ORIGIN
local Y_MIN, Y_MAX, STEPS = HeightFieldMath.Y_MIN, HeightFieldMath.Y_MAX, HeightFieldMath.STEPS

--- A field with every cell at the map floor.
function HeightFieldMath.new(): buffer
	return buffer.create(HeightFieldMath.BYTES) -- zero-filled: 0 decodes to Y_MIN
end

--- A height as its stored step, clamped to the map's height range.
function HeightFieldMath.encode(y: number): number
	return math.floor((math.clamp(y, Y_MIN, Y_MAX) - Y_MIN) * STEPS + 0.5)
end

--- A stored step as a height.
function HeightFieldMath.decode(v: number): number
	return Y_MIN + v / STEPS
end

--- The cell (0 to 255) a world X or Z falls in, clamped to the map.
function HeightFieldMath.cellOf(coord: number): number
	return math.clamp(math.floor((coord - ORIGIN) / CELL), 0, SIZE - 1)
end

--- The world X or Z of a cell's centre, where its ray is cast.
function HeightFieldMath.cellCentre(cell: number): number
	return ORIGIN + (cell + 0.5) * CELL
end

function HeightFieldMath.set(field: buffer, ix: number, iz: number, y: number)
	buffer.writeu16(field, (iz * SIZE + ix) * 2, HeightFieldMath.encode(y))
end

function HeightFieldMath.get(field: buffer, ix: number, iz: number): number
	return Y_MIN + buffer.readu16(field, (iz * SIZE + ix) * 2) / STEPS
end

--- The floor height at any X and Z: bilinear between the four nearest cell centres, so a hop
--- along a slope is smooth; outside the map and in the outer half cell it holds the edge value.
function HeightFieldMath.sample(field: buffer, x: number, z: number): number
	local fx = math.clamp((x - ORIGIN) / CELL - 0.5, 0, SIZE - 1)
	local fz = math.clamp((z - ORIGIN) / CELL - 0.5, 0, SIZE - 1)
	local ix = math.min(math.floor(fx), SIZE - 2)
	local iz = math.min(math.floor(fz), SIZE - 2)
	local tx, tz = fx - ix, fz - iz
	local get = HeightFieldMath.get
	local a = get(field, ix, iz) + (get(field, ix + 1, iz) - get(field, ix, iz)) * tx
	local b = get(field, ix, iz + 1) + (get(field, ix + 1, iz + 1) - get(field, ix, iz + 1)) * tx
	return a + (b - a) * tz
end

--- The two ends of the downward ray of a cell column: from the top of the map to its floor.
function HeightFieldMath.rayTop(): number
	return Y_MAX
end

function HeightFieldMath.rayLength(): number
	return Y_MAX - Y_MIN
end

--- Whether a wall hit `hitDistance` along a segment of `length` blocks it. A hit in the last 2%
--- is ignored (section 7.2), so a creature resting against a wall is not refused every tick.
function HeightFieldMath.segmentHitBlocks(hitDistance: number, length: number): boolean
	return hitDistance < length * (1 - HeightFieldMath.SEGMENT_END_SLACK)
end

return HeightFieldMath
