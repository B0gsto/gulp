--!strict
-- Data/LightingPresets against docs/06 (sections 4.2, 10.1, 10.2) and against any export files
-- in assets/export/lighting/ (docs/07, section 1.3). Task S3-A2.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local LightingPresets = require("../../../src/shared/Data/LightingPresets")
local TestKit = require("../../../src/shared/Util/TestKit")
local Zones = require("../../../src/shared/Data/Generated/Zones")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local BIBLE = fs.readFile("docs/06-art-bible.md")

local function cells(line: string): { string }
	local out = {}
	local body = string.match(line, "^%s*|(.*)|%s*$") or ""
	for cell in string.gmatch(body .. "|", "([^|]*)|") do
		local plain = string.gsub(string.gsub(cell, "`", ""), "%*%*%(tune%)%*%*", "")
		table.insert(out, (string.gsub(plain, "^%s*(.-)%s*$", "%1")))
	end
	return out
end

-- The first table row of 06 whose first cell is `first` and which has `width` cells.
local function bibleRow(first: string, width: number): { string }
	for line in string.gmatch(BIBLE, "[^\n]+") do
		if string.sub(line, 1, 1) == "|" then
			local row = cells(line)
			if row[1] == first and #row == width then
				return row
			end
		end
	end
	error(`06 has no {width}-cell row "{first}"`, 0)
end

local function number(cell: string): number
	local text = string.gsub(string.gsub(cell, "−", "-"), ",", "")
	return tonumber(text) or error(`not a number: {cell}`, 0)
end

-- 06 section 10.2's preset table, by row name.
local function presetRow(row: string)
	local r = bibleRow(row, 13)
	return {
		Brightness = number(r[2]),
		Ambient = r[3],
		OutdoorAmbient = r[4],
		ColorShift_Top = r[5],
		ExposureCompensation = number(r[6]),
		Atmosphere = {
			Density = number(r[7]),
			Offset = number(r[8]),
			Haze = number(r[9]),
			Glare = number(r[10]),
			Color = r[11],
			Decay = r[12],
		},
		TargetViewDistance = number(r[13]),
	}
end

describe("LightingPresets against docs/06", function()
	local reef = LightingPresets.get("LGT_Reef") or error("LGT_Reef is missing", 0)

	it("LGT_Reef carries every value of the Sunlit Reef row of section 10.2", function()
		local row = presetRow("Sunlit Reef")
		expect(reef.zoneRow).toBe("Sunlit Reef")
		expect(reef.Brightness).toBe(row.Brightness)
		expect(reef.Ambient).toBe(row.Ambient)
		expect(reef.OutdoorAmbient).toBe(row.OutdoorAmbient)
		expect(reef.ColorShift_Top).toBe(row.ColorShift_Top)
		expect(reef.ExposureCompensation).toBe(row.ExposureCompensation)
		expect(reef.Atmosphere).toEqual(row.Atmosphere)
		expect(reef.Fog.TargetViewDistance).toBe(row.TargetViewDistance)
	end)

	it("fog is the section 4.2 fog colour, starting at 25% of the view distance", function()
		local water = bibleRow("Sunlit Reef", 7) -- 4.2: zone, scope, surface, fog, deep, L*, floor
		expect(reef.Fog.Color).toBe(water[4])
		expect(reef.Fog.Color).toBe(reef.Atmosphere.Color) -- 10.2: "the same as the Atm. Color column"
		expect(reef.Fog.StartFraction).toBe(0.25)
		local fogStart, fogEnd = LightingPresets.fogRange(reef)
		expect(fogStart).toBe(100)
		expect(fogEnd).toBe(400)
	end)

	it("post-processing is the shared table of section 10.2", function()
		expect(reef.ColorCorrection.Brightness).toBe(number(bibleRow("ColorCorrection", 4)[3]))
		expect(reef.ColorCorrection).toEqual({
			Brightness = 0.02,
			Contrast = 0.08,
			Saturation = 0.12,
			TintColor = "#FFFFFF",
		})
		expect(reef.Bloom).toEqual({ Intensity = 0.6, Size = 24, Threshold = 0.95 })
		local rays = bibleRow("SunRays", 4)
		expect(rays[2]).toBe("Intensity 0.08, Spread 0.6")
		expect(rays[3]).toBe("On only within 40 studs of the surface")
		expect(reef.SunRays).toEqual({ Intensity = 0.08, Spread = 0.6, WithinSurface = 40 })
	end)

	it("light direction is the section 10.1 day values", function()
		expect(number(bibleRow("GeographicLatitude", 3)[2])).toBe(reef.GeographicLatitude)
		expect(string.match(bibleRow("ClockTime", 3)[2], "^([%d.]+) by day")).toBe("13.0")
		expect(reef.ClockTime).toBe(13)
	end)

	it("the darkness floor holds: Ambient is not below L* 30 (section 10.3)", function()
		-- sRGB to CIE L*, D65
		local function lstar(hex: string): number
			local function lin(c: number): number
				c /= 255
				return if c <= 0.04045 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
			end
			local r = lin(tonumber(string.sub(hex, 2, 3), 16) :: number)
			local g = lin(tonumber(string.sub(hex, 4, 5), 16) :: number)
			local b = lin(tonumber(string.sub(hex, 6, 7), 16) :: number)
			local y = 0.2126 * r + 0.7152 * g + 0.0722 * b
			return if y > 216 / 24389 then 116 * y ^ (1 / 3) - 16 else y * 24389 / 27
		end
		expect(lstar(reef.Ambient) >= 30).toBe(true)
	end)

	it("the Reef zone's lightingPreset finds LGT_Reef", function()
		local found = false
		for _, zone in Zones do
			if zone.id == "reef" then
				found = true
				expect(LightingPresets.forZoneRow(zone.lightingPreset)).toBe(reef)
			end
		end
		expect(found).toBe(true)
	end)
end)

describe("LightingPresets.fogRange", function()
	local reef = LightingPresets.get("LGT_Reef") or error("LGT_Reef is missing", 0)

	it("a tier cap pulls the whole fog in; colours do not change", function()
		local s, e = LightingPresets.fogRange(reef, LightingPresets.VIEW_CAP.Smooth)
		expect(e).toBe(220)
		expect(s).toBe(55)
		s, e = LightingPresets.fogRange(reef, LightingPresets.VIEW_CAP.Balanced)
		expect(e).toBe(350)
		expect(s).toBe(87.5)
	end)

	it("a cap beyond the view distance changes nothing", function()
		local s, e = LightingPresets.fogRange(reef, 1000)
		expect(s).toBe(100)
		expect(e).toBe(400)
	end)
end)

-- The export files are build output (assets/.gitignore), written by `lune run tools/gen/lighting`,
-- so a clean checkout has none; any that exist must match the table and name a built preset.
describe("LightingPresets against assets/export/lighting", function()
	it("every export file present matches its preset", function()
		local dir = "assets/export/lighting"
		if not fs.isDir(dir) then
			return
		end
		for _, entry in fs.readDir(dir) do
			local name = string.match(entry, "^(LGT_.+)%.json$")
			if name then
				local preset = LightingPresets.get(name)
					or error(`{entry} has no preset in Data/LightingPresets`, 0)
				expect(serde.decode("json", fs.readFile(`{dir}/{entry}`))).toEqual(preset)
			end
		end
	end)
end)
