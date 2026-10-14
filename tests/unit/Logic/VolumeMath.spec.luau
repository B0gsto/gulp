--!strict
local TestKit = require("../../../src/shared/Util/TestKit")
local Types = require("../../../src/shared/Types")
local VolumeMath = require("../../../src/shared/Logic/VolumeMath")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type Volume = Types.Volume

local IDENTITY = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
-- A quarter turn about Z: the part's local X axis points up the world Y axis.
local UPRIGHT = { 0, -1, 0, 1, 0, 0, 0, 0, 1 }
-- A quarter turn about Y: the part faces world -X (its look vector, -Z local, maps to -X).
local FACE_WEST = { 0, 0, 1, 0, 1, 0, -1, 0, 0 }

local function frame(x: number, y: number, z: number, rotation: { number }?): { number }
	local f = { x, y, z }
	for _, r in rotation or IDENTITY do
		table.insert(f, r)
	end
	return f
end

local function zone(
	id: string,
	shape: Types.VolumeShape,
	x: number,
	y: number,
	z: number,
	s: number
): Volume
	return VolumeMath.new("Zone", shape, frame(x, y, z), s, s, s, { Kind = "Zone", ZoneId = id })
end

describe("VolumeMath", function()
	it("inverse undoes a rotated, moved frame", function()
		local v = VolumeMath.new(
			"Hazard",
			"Block",
			frame(10, -20, 30, UPRIGHT),
			4,
			2,
			2,
			{ Kind = "Hazard" }
		)
		local lx, ly, lz = VolumeMath.toLocal(v, 10, -20, 30)
		expect(lx).toBeCloseTo(0)
		expect(ly).toBeCloseTo(0)
		expect(lz).toBeCloseTo(0)
		-- One stud up the world is one stud along the part's local X.
		lx, ly, lz = VolumeMath.toLocal(v, 10, -19, 30)
		expect(lx).toBeCloseTo(1)
		expect(ly).toBeCloseTo(0)
		expect(lz).toBeCloseTo(0)
		local cx, cy, cz = VolumeMath.centre(v)
		expect({ cx, cy, cz }).toEqual({ 10, -20, 30 })
	end)

	it("tests a block on its rotated axes, surface included", function()
		local v = VolumeMath.new(
			"Hazard",
			"Block",
			frame(0, 0, 0, UPRIGHT),
			20,
			4,
			4,
			{ Kind = "Hazard" }
		)
		expect(VolumeMath.contains(v, 0, 10, 0)).toBe(true) -- local X reaches 10 up
		expect(VolumeMath.contains(v, 10, 0, 0)).toBe(false)
		expect(VolumeMath.contains(v, 2, 0, 2)).toBe(true)
		expect(VolumeMath.contains(v, 0, 10.01, 0)).toBe(false)
	end)

	it("gives a ball half its smallest size as radius", function()
		local v = VolumeMath.new(
			"SafeNursery",
			"Ball",
			frame(0, 0, 0),
			10,
			40,
			40,
			{ Kind = "SafeNursery" }
		)
		expect(VolumeMath.contains(v, 0, 5, 0)).toBe(true)
		expect(VolumeMath.contains(v, 0, 6, 0)).toBe(false)
		expect(VolumeMath.distance(v, 0, 8, 0)).toBeCloseTo(3)
		expect(VolumeMath.measure(v)).toBeCloseTo(4 / 3 * math.pi * 125)
	end)

	it("runs a cylinder along its local X", function()
		local attrs = { Kind = "CoveMouth", CoveIndex = 3 }
		local v = VolumeMath.new(
			"CoveMouth",
			"Cylinder",
			frame(150, -50, 150, UPRIGHT),
			20,
			30,
			30,
			attrs
		)
		expect(VolumeMath.contains(v, 150, -50, 160)).toBe(true) -- 10 out of a radius of 15
		expect(VolumeMath.contains(v, 150, -50, 166)).toBe(false)
		expect(VolumeMath.contains(v, 150, -41, 150)).toBe(true) -- 9 up of a half height of 10
		expect(VolumeMath.contains(v, 150, -39, 150)).toBe(false)
		expect(VolumeMath.distance(v, 150, -37, 170)).toBeCloseTo(math.sqrt(9 + 25))
		expect(VolumeMath.measure(v)).toBeCloseTo(math.pi * 225 * 20)
	end)

	it("measures block distance from outside and 0 inside", function()
		local v = zone("reef", "Block", 0, 0, 0, 10)
		expect(VolumeMath.distance(v, 1, 1, 1)).toBe(0)
		expect(VolumeMath.distance(v, 8, 0, 0)).toBeCloseTo(3)
		expect(VolumeMath.distance(v, 8, 9, 0)).toBeCloseTo(5)
	end)

	it("reads a Current's direction from its look vector", function()
		local v = VolumeMath.new(
			"Current",
			"Block",
			frame(0, 0, 0, FACE_WEST),
			4,
			4,
			4,
			{ Kind = "Current" }
		)
		local x, y, z = VolumeMath.lookVector(v)
		expect(x).toBeCloseTo(-1)
		expect(y).toBeCloseTo(0)
		expect(z).toBeCloseTo(0)
		x, y, z = VolumeMath.lookVector(zone("reef", "Block", 5, 5, 5, 2))
		expect({ x, y, z }).toEqual({ -0, -0, -1 })
	end)

	it("lets the smallest zone win where zones overlap, in any authoring order", function()
		local reef = zone("reef", "Block", 0, 0, 0, 500)
		local nursery = zone("nursery", "Ball", 100, 0, 0, 80)
		for _, list in { { reef, nursery }, { nursery, reef } } do
			VolumeMath.sortZones(list)
			expect(list[1]).toBe(nursery)
			expect(VolumeMath.zoneAt(list, 100, 0, 0)).toBe("nursery")
			expect(VolumeMath.zoneAt(list, -100, 0, 0)).toBe("reef")
		end
	end)

	it("breaks equal-size ties by ZoneId, then by centre", function()
		local a = zone("kelp", "Block", 0, 0, 0, 10)
		local b = zone("reef", "Block", 0, 0, 0, 10)
		local c = zone("kelp", "Block", -5, 0, 0, 10)
		local list = { b, a, c }
		VolumeMath.sortZones(list)
		expect(list).toEqual({ c, a, b })
	end)

	it("gives water outside every zone to the nearest zone, and nil with no zones", function()
		local list = { zone("reef", "Block", 0, 0, 0, 512), zone("kelp", "Block", 420, 0, 0, 200) }
		VolumeMath.sortZones(list)
		expect(VolumeMath.zoneAt(list, 300, 0, 0)).toBe("kelp") -- 20 from kelp, 44 from reef
		expect(VolumeMath.zoneAt(list, 270, 0, 0)).toBe("reef") -- 14 from reef, 50 from kelp
		expect(VolumeMath.zoneAt({}, 0, 0, 0)).toBe(nil)
	end)

	it("finds the first volume holding a point", function()
		local a = zone("reef", "Block", 0, 0, 0, 10)
		local b = zone("kelp", "Block", 100, 0, 0, 10)
		expect(VolumeMath.firstContaining({ a, b }, 100, 0, 0)).toBe(b)
		expect(VolumeMath.firstContaining({ a, b }, 50, 0, 0)).toBe(nil)
	end)

	it("validates Kind and the attributes WorldIndex reads", function()
		local zones = { reef = true }
		expect(VolumeMath.validate({ Kind = "Zone", ZoneId = "reef" }, zones)).toBe(true)
		expect(select(2, VolumeMath.validate({ Kind = "Zone", ZoneId = "moon" }, zones))).toBe(
			"Zone with unknown ZoneId moon"
		)
		expect(select(2, VolumeMath.validate({ Kind = "Lava" }, zones))).toBe("unknown Kind Lava")
		expect(select(2, VolumeMath.validate({}, zones))).toBe("unknown Kind nil")
		expect(VolumeMath.validate({ Kind = "CoveMouth", CoveIndex = 24 }, zones)).toBe(true)
		for _, bad in { 0, 25, 2.5, "3" } do
			expect(VolumeMath.validate({ Kind = "CoveInterior", CoveIndex = bad }, zones)).toBe(
				false
			)
		end
		expect(VolumeMath.validate({ Kind = "RevivePoint", PointId = "rp_01" }, zones)).toBe(true)
		expect(VolumeMath.validate({ Kind = "RevivePoint" }, zones)).toBe(false)
		expect(VolumeMath.validate({ Kind = "EelHole" }, zones)).toBe(true)
		expect(VolumeMath.validate({ Kind = "HatchBed" }, zones)).toBe(true)
	end)

	it("lists the thirteen kinds of section 9.1 and the three safe ones", function()
		expect(#VolumeMath.KINDS).toBe(13)
		expect(table.find(VolumeMath.KINDS, "HatchBed") ~= nil).toBe(true)
		expect(VolumeMath.SAFE_KINDS).toEqual({ "SafeNursery", "CoveMouth", "CoveInterior" })
	end)

	it("freezes what it builds", function()
		local v = zone("reef", "Block", 0, 0, 0, 10)
		expect(table.isfrozen(v)).toBe(true)
		expect(table.isfrozen(v.inv)).toBe(true)
		expect(table.isfrozen(v.attrs)).toBe(true)
	end)
end)
