--!strict
--!native
--!optimize 2
-- SpatialGrid: the prey spatial grid of docs/09, section 8.3. Two-dimensional on X and Z, 64-stud
-- cells, 32 × 32 = 1,024 cells covering the map's −1,024 to 1,024 studs (positions outside are
-- clamped to the edge cells). Depth is left to the caller's distance test.
--
-- Entries are IDs 0 to capacity − 1 (the prey group IDs). Each cell's list is intrusive: `cellHead`
-- (u16 per cell) points at the first ID, and `next`/`prev` (u16 per ID) link the rest. `cell` holds
-- each ID's cell, NONE when it is not in the grid. These are the `cell`, `nextInCell` and
-- `prevInCell` buffers of the group layout (8.2); PreySim shares them.
--
-- Nothing here allocates after `new`. Iterate a cell without allocation:
--   local id = SpatialGrid.head(grid, cell)
--   while id ~= SpatialGrid.NONE do ...; id = SpatialGrid.nextOf(grid, id) end
local SpatialGrid = {}

SpatialGrid.CELL = 64 -- studs
SpatialGrid.SIDE = 32 -- cells per side
SpatialGrid.CELLS = 32 * 32
SpatialGrid.ORIGIN = -1024 -- world X and Z of the grid's low corner
SpatialGrid.NONE = 0xFFFF

local CELL = 64
local SIDE = 32
local ORIGIN = -1024
local NONE = 0xFFFF

export type Grid = {
	capacity: number,
	cellHead: buffer, -- u16 × 1,024
	cell: buffer, -- u16 × capacity
	next: buffer, -- u16 × capacity
	prev: buffer, -- u16 × capacity
}

local function fillNone(b: buffer, count: number)
	for i = 0, count - 1 do
		buffer.writeu16(b, i * 2, NONE)
	end
end

--- An empty grid for IDs 0 to capacity − 1 (capacity at most 65,535).
function SpatialGrid.new(capacity: number): Grid
	assert(capacity >= 1 and capacity < NONE and capacity % 1 == 0, "SpatialGrid.new: bad capacity")
	local grid: Grid = {
		capacity = capacity,
		cellHead = buffer.create(SIDE * SIDE * 2),
		cell = buffer.create(capacity * 2),
		next = buffer.create(capacity * 2),
		prev = buffer.create(capacity * 2),
	}
	fillNone(grid.cellHead, SIDE * SIDE)
	fillNone(grid.cell, capacity)
	fillNone(grid.next, capacity)
	fillNone(grid.prev, capacity)
	return grid
end

local function axis(v: number): number
	local c = (v - ORIGIN) // CELL
	if c ~= c or c < 0 then
		return 0
	elseif c >= SIDE then
		return SIDE - 1
	end
	return c
end

--- Column (X) and row (Z) of a world position, each 0 to 31.
function SpatialGrid.colRow(x: number, z: number): (number, number)
	return axis(x), axis(z)
end

--- Cell index of a world position: row × 32 + column.
function SpatialGrid.cellOf(x: number, z: number): number
	return axis(z) * SIDE + axis(x)
end

--- The inclusive column and row ranges of the cells a circle of radius r around (x, z) touches.
function SpatialGrid.range(x: number, z: number, r: number): (number, number, number, number)
	return axis(x - r), axis(x + r), axis(z - r), axis(z + r)
end

--- First ID in a cell, NONE if empty.
function SpatialGrid.head(grid: Grid, cell: number): number
	return buffer.readu16(grid.cellHead, cell * 2)
end

--- The ID after `id` in its cell, NONE at the end.
function SpatialGrid.nextOf(grid: Grid, id: number): number
	return buffer.readu16(grid.next, id * 2)
end

--- The cell an ID is in, NONE if it is not in the grid.
function SpatialGrid.cellIdOf(grid: Grid, id: number): number
	return buffer.readu16(grid.cell, id * 2)
end

local function link(grid: Grid, id: number, cell: number)
	local head = buffer.readu16(grid.cellHead, cell * 2)
	buffer.writeu16(grid.cell, id * 2, cell)
	buffer.writeu16(grid.prev, id * 2, NONE)
	buffer.writeu16(grid.next, id * 2, head)
	if head ~= NONE then
		buffer.writeu16(grid.prev, head * 2, id)
	end
	buffer.writeu16(grid.cellHead, cell * 2, id)
end

local function unlink(grid: Grid, id: number, cell: number)
	local prev = buffer.readu16(grid.prev, id * 2)
	local nxt = buffer.readu16(grid.next, id * 2)
	if prev ~= NONE then
		buffer.writeu16(grid.next, prev * 2, nxt)
	else
		buffer.writeu16(grid.cellHead, cell * 2, nxt)
	end
	if nxt ~= NONE then
		buffer.writeu16(grid.prev, nxt * 2, prev)
	end
	buffer.writeu16(grid.cell, id * 2, NONE)
	buffer.writeu16(grid.next, id * 2, NONE)
	buffer.writeu16(grid.prev, id * 2, NONE)
end

--- Adds an ID at a position. An ID already in the grid is moved instead.
function SpatialGrid.insert(grid: Grid, id: number, x: number, z: number)
	local cell = SpatialGrid.cellOf(x, z)
	local old = buffer.readu16(grid.cell, id * 2)
	if old == cell then
		return
	elseif old ~= NONE then
		unlink(grid, id, old)
	end
	link(grid, id, cell)
end

--- Moves an ID to a new position; it only relinks when the cell changes. Returns the cell.
function SpatialGrid.move(grid: Grid, id: number, x: number, z: number): number
	local cell = SpatialGrid.cellOf(x, z)
	local old = buffer.readu16(grid.cell, id * 2)
	if old ~= cell then
		if old ~= NONE then
			unlink(grid, id, old)
		end
		link(grid, id, cell)
	end
	return cell
end

--- Removes an ID; nothing happens if it is not in the grid.
function SpatialGrid.remove(grid: Grid, id: number)
	local old = buffer.readu16(grid.cell, id * 2)
	if old ~= NONE then
		unlink(grid, id, old)
	end
end

--- Writes into `out` (from index 1) every ID in the cells a circle of radius r around (x, z)
--- touches, and returns how many. A superset of the IDs within r: the caller applies its own
--- distance test. `out` is the caller's scratch table; entries past the count are left as they are.
function SpatialGrid.query(grid: Grid, x: number, z: number, r: number, out: { number }): number
	local c0, c1, r0, r1 = SpatialGrid.range(x, z, r)
	local n = 0
	for row = r0, r1 do
		for col = c0, c1 do
			local id = buffer.readu16(grid.cellHead, (row * SIDE + col) * 2)
			while id ~= NONE do
				n += 1
				out[n] = id
				id = buffer.readu16(grid.next, id * 2)
			end
		end
	end
	return n
end

return table.freeze(SpatialGrid)
