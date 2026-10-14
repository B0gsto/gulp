--!strict
local Rng = require("../../../src/shared/Util/Rng")
local SpatialGrid = require("../../../src/shared/Sim/SpatialGrid")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Sim/SpatialGrid (09 §8.3)", function()
	it("maps positions to 64-stud cells and clamps the map edges", function()
		expect(SpatialGrid.cellOf(-1024, -1024)).toBe(0)
		expect(SpatialGrid.cellOf(-961, -1024)).toBe(0)
		expect(SpatialGrid.cellOf(-960, -1024)).toBe(1)
		expect(SpatialGrid.cellOf(1023.9, 1023.9)).toBe(SpatialGrid.CELLS - 1)
		expect(SpatialGrid.cellOf(5000, -5000)).toBe(31)
		expect(SpatialGrid.cellOf(0 / 0, 0 / 0)).toBe(0)
	end)

	it("answers queries like brute force through random inserts, moves and removes", function()
		local capacity = 640
		local grid = SpatialGrid.new(capacity)
		local rng = Rng.new(8301)
		local inGrid: { [number]: boolean } = {}
		local xs: { [number]: number } = {}
		local zs: { [number]: number } = {}
		local out: { number } = {}
		local function randomPos(): (number, number)
			-- Slightly past the map so the edge clamp is exercised.
			return Rng.range(rng, -1100, 1100), Rng.range(rng, -1100, 1100)
		end
		for round = 1, 60 do
			for _ = 1, 80 do
				local id = Rng.int(rng, 0, capacity - 1)
				local op = Rng.int(rng, 1, 4)
				if op <= 2 then
					local x, z = randomPos()
					if op == 1 then
						SpatialGrid.insert(grid, id, x, z)
					else
						if not inGrid[id] then
							SpatialGrid.insert(grid, id, x, z)
						end
						-- A small move usually stays in the cell; sometimes it crosses.
						x, z =
							(xs[id] or x) + Rng.range(rng, -40, 40),
							(zs[id] or z) + Rng.range(rng, -40, 40)
						expect(SpatialGrid.move(grid, id, x, z)).toBe(SpatialGrid.cellOf(x, z))
					end
					inGrid[id], xs[id], zs[id] = true, x, z
				else
					SpatialGrid.remove(grid, id)
					inGrid[id] = nil
				end
			end
			for _ = 1, 20 do
				local qx, qz = randomPos()
				local r = Rng.range(rng, 0, 200)
				local n = SpatialGrid.query(grid, qx, qz, r, out)
				local seen: { [number]: boolean } = {}
				local c0, c1, r0, r1 = SpatialGrid.range(qx, qz, r)
				for i = 1, n do
					local id = out[i]
					expect(seen[id]).toBe(nil) -- no duplicates
					seen[id] = true
					expect(inGrid[id]).toBe(true)
					local col, row = SpatialGrid.colRow(xs[id], zs[id])
					expect(col >= c0 and col <= c1 and row >= r0 and row <= r1).toBe(true)
				end
				-- Brute force: every ID in the grid within r is found, and every ID in a touched cell.
				local expected = 0
				for id in inGrid do
					local dx, dz = xs[id] - qx, zs[id] - qz
					if dx * dx + dz * dz <= r * r then
						expect(seen[id]).toBe(true)
					end
					local col, row = SpatialGrid.colRow(xs[id], zs[id])
					if col >= c0 and col <= c1 and row >= r0 and row <= r1 then
						expected += 1
					end
				end
				expect(n).toBe(expected)
			end
			expect(round > 0).toBe(true)
		end
		-- Every cell list links both ways and matches the IDs' cells.
		local total = 0
		for cell = 0, SpatialGrid.CELLS - 1 do
			local id = SpatialGrid.head(grid, cell)
			local prev = SpatialGrid.NONE
			while id ~= SpatialGrid.NONE do
				expect(SpatialGrid.cellIdOf(grid, id)).toBe(cell)
				expect(buffer.readu16(grid.prev, id * 2)).toBe(prev)
				total += 1
				prev = id
				id = SpatialGrid.nextOf(grid, id)
			end
		end
		local live = 0
		for _ in inGrid do
			live += 1
		end
		expect(total).toBe(live)
	end)

	it("removes an ID that is not in the grid without harm", function()
		local grid = SpatialGrid.new(4)
		SpatialGrid.remove(grid, 2)
		SpatialGrid.insert(grid, 1, 0, 0)
		SpatialGrid.remove(grid, 1)
		SpatialGrid.remove(grid, 1)
		expect(SpatialGrid.cellIdOf(grid, 1)).toBe(SpatialGrid.NONE)
		expect(SpatialGrid.head(grid, SpatialGrid.cellOf(0, 0))).toBe(SpatialGrid.NONE)
	end)
end)
