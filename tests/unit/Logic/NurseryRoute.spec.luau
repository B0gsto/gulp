--!strict
local Index = require("../../../src/shared/Data/Index")
local NurseryPath = require("../../../src/shared/Data/Generated/NurseryPath")
local NurseryRoute = require("../../../src/shared/Logic/NurseryRoute")
local TestKit = require("../../../src/shared/Util/TestKit")
local Types = require("../../../src/shared/Types")
local VolumeMath = require("../../../src/shared/Logic/VolumeMath")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type Volume = Types.Volume

local function near(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

-- The route volumes as WorldIndex keeps them, smallest first (as WorldIndex.nurseryPathAt).
local function routeVolumes(): { Volume }
	local list: { Volume } = {}
	for _, v in NurseryRoute.volumes() do
		if v.kind == NurseryRoute.KIND then
			local attrs = { Kind = v.kind, PointId = v.pointId :: string }
			table.insert(
				list,
				VolumeMath.new(v.kind, v.shape, v.frame, v.size[1], v.size[2], v.size[3], attrs)
			)
		end
	end
	VolumeMath.sortBySize(list, "PointId")
	return list
end

local function at(list: { Volume }, x: number, y: number, z: number): string?
	local v = VolumeMath.firstContaining(list, x, y, z)
	return if v then v.attrs.PointId :: string else nil
end

describe("NurseryRoute", function()
	it("puts every data:NurseryPath place on the arc and the Elbow (03 §6.2)", function()
		expect(NurseryRoute.ARC_LENGTH).toBeCloseTo(110, 0.1)
		expect(NurseryRoute.LENGTH).toBe(335)
		for _, def in NurseryPath do
			local x, z = NurseryRoute.pointAt(def.at)
			expect(`{def.id} {near(x, z, def.x, def.z) < 1}`).toBe(`{def.id} true`)
			local tx, tz = NurseryRoute.pointAt(def.to)
			expect(`{def.id} end {near(tx, tz, def.toX, def.toZ) < 1}`).toBe(`{def.id} end true`)
		end
	end)

	it(
		"starts facing east, leaves the Nursery north-east, bends about 40° right (04 §3.5)",
		function()
			local hx, hz = NurseryRoute.headingAt(0)
			expect(hx).toBeCloseTo(1, 1e-9)
			expect(hz).toBeCloseTo(0, 1e-9)
			local ax, az = NurseryRoute.headingAt(122)
			expect(math.deg(math.atan2(-az, ax))).toBeCloseTo(45, 0.5) -- north is −Z
			local bx, bz = NurseryRoute.headingAt(300)
			local turn = math.deg(math.atan2(-az, ax) - math.atan2(-bz, bx))
			expect(turn).toBeCloseTo(40, 1)
			-- Clamped past either end.
			local ex, ez = NurseryRoute.pointAt(400)
			expect(near(ex, ez, -110, 201) < 1e-9).toBe(true)
		end
	)

	it("lays out the HatchBed and one NurseryPath volume per other row", function()
		local volumes = NurseryRoute.volumes()
		expect(#volumes).toBe(#NurseryPath)
		local hatch = volumes[1]
		expect(hatch.kind).toBe("HatchBed")
		expect(hatch.shape).toBe("Ball")
		expect(`{hatch.frame[1]} {hatch.frame[2]} {hatch.frame[3]}`).toBe("-398 -24 340")
		local v = VolumeMath.new("HatchBed", "Ball", hatch.frame, 4, 4, 4, { Kind = "HatchBed" })
		local lx, ly, lz = VolumeMath.lookVector(v)
		expect(lx).toBeCloseTo(1, 1e-9) -- east (03 §6.2)
		expect(math.abs(ly) + math.abs(lz)).toBeCloseTo(0, 1e-9)
		local seen: { [string]: boolean } = {}
		for i = 2, #volumes do
			local id = volumes[i].pointId :: string
			expect(volumes[i].kind).toBe("NurseryPath")
			expect(Index.NurseryPath.byId[id] ~= nil).toBe(true)
			expect(seen[id]).toBe(nil)
			seen[id] = true
			expect(VolumeMath.validate({ Kind = "NurseryPath", PointId = id }, {})).toBe(true)
		end
		expect(VolumeMath.validate({ Kind = "NurseryPath" }, {})).toBe(false)
	end)

	it("answers which route place a point is in, the smallest first", function()
		local list = routeVolumes()
		-- The Gap: inside the tunnel, at the curtain, across its 50-stud width.
		local gx, gz = NurseryRoute.pointAt(122)
		expect(at(list, gx, -17, gz)).toBe("little_arch")
		expect(at(list, -299, -17, 299)).toBe("kelp_curtain")
		local hx, hz = NurseryRoute.headingAt(122)
		expect(at(list, gx - hz * 24, -17, gz + hx * 24)).toBe("little_arch")
		expect(at(list, gx - hz * 26, -17, gz + hx * 26)).toBe(nil)
		expect(at(list, gx, -4, gz)).toBe(nil) -- above the arch's opening (depth 6)
		-- The channel: each leg, the bend, and no gap anywhere from the Gap to the Home Current.
		local ax, az = NurseryRoute.pointAt(185)
		expect(at(list, ax, -40, az)).toBe("elbow_leg_1")
		expect(at(list, -210, -28, 210)).toBe("elbow_bend")
		local bx, bz = NurseryRoute.pointAt(300)
		expect(at(list, bx, -40, bz)).toBe("elbow_leg_2")
		for s = 110, 335, 0.5 do
			local x, z = NurseryRoute.pointAt(s)
			expect(`{s} {at(list, x, -20, z) ~= nil}`).toBe(`{s} true`)
		end
		-- Points: the swarms and the Glow Grotto's mouth at their depths.
		expect(at(list, -384, -18, 339)).toBe("swarm_a")
		expect(at(list, -340, -18, 327)).toBe("swarm_b")
		expect(at(list, -322, -18, 301)).toBe("glow_grotto")
		expect(at(list, -110, -30, 201)).toBe("home_current_mouth")
		local tx, tz = NurseryRoute.pointAt(38)
		expect(at(list, tx, -18, tz)).toBe("plankton_trail")
		expect(at(list, -361, -18, 361)).toBe(nil) -- the Bubble Fountain, off the route
	end)
end)
