--!strict
local HeightFieldMath = require("../../../src/shared/Logic/HeightFieldMath")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("HeightFieldMath", function()
	it("covers the map with 256 × 256 cells of 8 studs (section 9.1)", function()
		expect(HeightFieldMath.SIZE * HeightFieldMath.CELL).toBe(2048)
		expect(HeightFieldMath.BYTES).toBe(131072)
		expect(buffer.len(HeightFieldMath.new())).toBe(131072)
		expect(HeightFieldMath.encode(HeightFieldMath.Y_MAX) <= 65535).toBe(true)
	end)

	it("maps world X and Z to cells and back to cell centres", function()
		expect(HeightFieldMath.cellOf(-1024)).toBe(0)
		expect(HeightFieldMath.cellOf(-1016.01)).toBe(0)
		expect(HeightFieldMath.cellOf(0)).toBe(128)
		expect(HeightFieldMath.cellOf(1023.9)).toBe(255)
		expect(HeightFieldMath.cellOf(5000)).toBe(255)
		expect(HeightFieldMath.cellOf(-5000)).toBe(0)
		expect(HeightFieldMath.cellCentre(0)).toBe(-1020)
		expect(HeightFieldMath.cellCentre(128)).toBe(4)
		expect(HeightFieldMath.cellOf(HeightFieldMath.cellCentre(77))).toBe(77)
	end)

	it("stores heights in 1/64 stud steps, clamped to the map", function()
		for _, y in { -600, -100, -40.5, 0, 96, -123.015625 } do
			expect(HeightFieldMath.decode(HeightFieldMath.encode(y))).toBe(y)
		end
		expect(HeightFieldMath.decode(HeightFieldMath.encode(-37.3))).toBeCloseTo(-37.3, 1 / 128)
		expect(HeightFieldMath.encode(-900)).toBe(0)
		expect(HeightFieldMath.decode(HeightFieldMath.encode(500))).toBe(96)
	end)

	it("starts every cell at the map floor", function()
		local field = HeightFieldMath.new()
		expect(HeightFieldMath.get(field, 0, 0)).toBe(-600)
		expect(HeightFieldMath.get(field, 255, 255)).toBe(-600)
		expect(HeightFieldMath.sample(field, 12.3, -400)).toBe(-600)
	end)

	it("returns a cell's value at its centre and blends between centres", function()
		local field = HeightFieldMath.new()
		for iz = 0, 255 do
			for ix = 0, 255 do
				HeightFieldMath.set(field, ix, iz, -100)
			end
		end
		HeightFieldMath.set(field, 128, 128, -40)
		local c = HeightFieldMath.cellCentre(128)
		expect(HeightFieldMath.sample(field, c, c)).toBe(-40)
		expect(HeightFieldMath.sample(field, c + 4, c)).toBe(-70) -- halfway to the next centre
		expect(HeightFieldMath.sample(field, c + 4, c + 4)).toBe(-85) -- a quarter of the rise
		expect(HeightFieldMath.sample(field, c + 8, c)).toBe(-100)
	end)

	it("holds the edge value outside the map", function()
		local field = HeightFieldMath.new()
		HeightFieldMath.set(field, 0, 0, -10)
		HeightFieldMath.set(field, 255, 255, -20)
		expect(HeightFieldMath.sample(field, -2000, -2000)).toBe(-10)
		expect(HeightFieldMath.sample(field, -1023, -1023)).toBe(-10)
		expect(HeightFieldMath.sample(field, 2000, 2000)).toBe(-20)
		expect(HeightFieldMath.sample(field, 1023, 1023)).toBe(-20)
	end)

	it("casts each column from the map top to the map floor", function()
		expect(HeightFieldMath.rayTop()).toBe(96)
		expect(HeightFieldMath.rayTop() - HeightFieldMath.rayLength()).toBe(-600)
	end)

	it("ignores a wall hit in the last 2% of a segment (section 7.2)", function()
		expect(HeightFieldMath.segmentHitBlocks(50, 100)).toBe(true)
		expect(HeightFieldMath.segmentHitBlocks(97.9, 100)).toBe(true)
		expect(HeightFieldMath.segmentHitBlocks(98, 100)).toBe(false)
		expect(HeightFieldMath.segmentHitBlocks(99.5, 100)).toBe(false)
		expect(HeightFieldMath.segmentHitBlocks(0, 100)).toBe(true)
	end)
end)
