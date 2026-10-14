--!strict
local Remotes = require("../../../../src/shared/Net/Remotes")
local Rng = require("../../../../src/shared/Util/Rng")
local TestKit = require("../../../../src/shared/Util/TestKit")
local Types = require("../../../../src/shared/Types")
local VolumeMath = require("../../../../src/shared/Logic/VolumeMath")
local WorldInfo = require("../../../../src/shared/Net/Codec/WorldInfo")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type Volume = Types.Volume

local SENT_KINDS = {}
for _, kind in VolumeMath.KINDS do
	if kind ~= "RevivePoint" then
		table.insert(SENT_KINDS, kind)
	end
end
local SHAPES = { "Block", "Ball", "Cylinder" }

local function randomVolume(rng: Rng.Rng): Volume
	local kind = Rng.pick(rng, SENT_KINDS) :: string
	local a = Rng.range(rng, -math.pi, math.pi)
	local c, s = math.cos(a), math.sin(a)
	local frame = { -- a turn about Y, then a position
		Rng.range(rng, -1024, 1024),
		Rng.range(rng, -600, 90),
		Rng.range(rng, -1024, 1024),
		c,
		0,
		s,
		0,
		1,
		0,
		-s,
		0,
		c,
	}
	local attrs: { [string]: Types.VolumeAttribute } = { Kind = kind }
	if Rng.chance(rng, 0.5) then
		attrs.CoveIndex = Rng.int(rng, 1, 24)
	end
	if Rng.chance(rng, 0.5) then
		attrs.PreyIds = "krill,plankton"
	end
	if Rng.chance(rng, 0.3) then
		attrs.Floor = true
	end
	return VolumeMath.new(
		kind,
		Rng.pick(rng, SHAPES) :: string,
		frame,
		Rng.range(rng, 1, 400),
		Rng.range(rng, 1, 200),
		Rng.range(rng, 1, 400),
		attrs
	)
end

local function randomList(rng: Rng.Rng, n: number): { Volume }
	local list = {}
	for i = 1, n do
		list[i] = randomVolume(rng)
	end
	return list
end

-- A plain, editable copy of encoded arguments, as a client would receive them.
local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

describe("Codec/WorldInfo (09 §5.3, §9.1, §17.3)", function()
	it("round-trips the version, the epoch and random volume tables", function()
		local rng = Rng.new(8708)
		for _ = 1, 50 do
			local volumes = randomList(rng, Rng.int(rng, 0, 120))
			local epoch = Rng.range(rng, 1.6e9, 1.9e9)
			local version, sentEpoch, wire = WorldInfo.encode(epoch, volumes)
			expect(version).toBe(Remotes.NET_VERSION)
			expect(table.isfrozen(wire)).toBe(false)
			local info, reason = WorldInfo.decode(deepCopy(version), sentEpoch, deepCopy(wire))
			expect(reason).toBe(nil)
			local got = info :: WorldInfo.Info
			expect(got.netVersion).toBe(Remotes.NET_VERSION)
			expect(got.serverEpoch).toBe(epoch)
			expect(got.volumes).toEqual(volumes)
			expect(table.isfrozen(got.volumes)).toBe(true)
			for i, v in got.volumes do
				expect(table.isfrozen(v) and table.isfrozen(v.inv) and table.isfrozen(v.attrs)).toBe(
					true
				)
				local cx, cy, cz = VolumeMath.centre(volumes[i])
				expect(VolumeMath.contains(v, cx, cy, cz)).toBe(true)
			end
		end
	end)

	it("sends plain copies and never a revive point", function()
		local volumes = randomList(Rng.new(8709), 3)
		local _, _, wire = WorldInfo.encode(0, volumes)
		for _, v in wire do
			expect(table.isfrozen(v.inv) or table.isfrozen(v.attrs)).toBe(false)
		end
		local point = VolumeMath.new(
			"RevivePoint",
			"Ball",
			{ 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
			4,
			4,
			4,
			{
				Kind = "RevivePoint",
				PointId = "rp_01",
			}
		)
		expect(function()
			WorldInfo.encode(0, { point })
		end).toThrow()
		expect(function()
			WorldInfo.encode(0, table.create(WorldInfo.MAX_VOLUMES + 1, volumes[1]))
		end).toThrow()
	end)

	it("rejects a wrong version or wrong argument types without throwing", function()
		local _, epoch, wire = WorldInfo.encode(5, randomList(Rng.new(8710), 2))
		local function reason(...: unknown): string?
			local info, why = WorldInfo.decode(...)
			expect(info).toBe(nil)
			return why
		end
		expect(reason(Remotes.NET_VERSION + 1, epoch, wire)).toBe("version")
		expect(reason(tostring(Remotes.NET_VERSION), epoch, wire)).toBe("type")
		expect(reason(Remotes.NET_VERSION, nil, wire)).toBe("type")
		expect(reason(Remotes.NET_VERSION, epoch, "volumes")).toBe("type")
		expect(reason(Remotes.NET_VERSION, 0 / 0, wire)).toBe("range")
		expect(reason(Remotes.NET_VERSION, -1, wire)).toBe("range")
		local tooMany = table.create(WorldInfo.MAX_VOLUMES + 1, wire[1])
		expect(reason(Remotes.NET_VERSION, epoch, tooMany)).toBe("size")
	end)

	it("rejects malformed volumes without throwing", function()
		local _, epoch, wire = WorldInfo.encode(5, randomList(Rng.new(8711), 1))
		local edits: { (any) -> () } = {
			function(v)
				v.kind = "Nope"
			end,
			function(v)
				v.kind = "RevivePoint"
				v.attrs.Kind = "RevivePoint"
			end,
			function(v)
				v.kind = 3
			end,
			function(v)
				v.shape = "Wedge"
			end,
			function(v)
				v.inv[12] = nil
			end,
			function(v)
				v.inv[13] = 0
			end,
			function(v)
				v.inv[4] = 0 / 0
			end,
			function(v)
				v.inv[1] = "0"
			end,
			function(v)
				v.inv = nil
			end,
			function(v)
				v.hx = -1
			end,
			function(v)
				v.hy = math.huge
			end,
			function(v)
				v.hz = nil
			end,
			function(v)
				v.attrs = nil
			end,
			function(v)
				v.attrs.Kind = "Zone2"
			end,
			function(v)
				v.attrs.Big = string.rep("x", WorldInfo.MAX_STRING + 1)
			end,
			function(v)
				v.attrs[1] = 1
			end,
			function(v)
				v.attrs.Bad = {}
			end,
			function(v)
				v.attrs.Bad = 0 / 0
			end,
			function(v)
				for i = 1, WorldInfo.MAX_ATTRIBUTES do
					v.attrs["A" .. i] = i
				end
			end,
		}
		for _, edit in edits do
			local copy = deepCopy(wire)
			edit(copy[1])
			local info, why = WorldInfo.decode(Remotes.NET_VERSION, epoch, copy)
			expect(info).toBe(nil)
			expect(why).toBe("range")
		end
		local holes = deepCopy(wire)
		holes[3] = holes[1] -- 1 and 3, no 2
		expect(select(2, WorldInfo.decode(Remotes.NET_VERSION, epoch, holes))).toBe("range")
		local notVolume = { "Zone" }
		expect(select(2, WorldInfo.decode(Remotes.NET_VERSION, epoch, notVolume))).toBe("range")
		local info = WorldInfo.decode(Remotes.NET_VERSION, epoch, {})
		expect(info and #info.volumes).toBe(0)
	end)
end)
