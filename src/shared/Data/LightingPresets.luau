--!strict
-- Lighting presets (docs/07, section 10; values from docs/06, sections 10.1 and 10.2; task S3-A2).
-- A preset is one settings record: light direction and colours, fog colour and distance, colour
-- grade, bloom and the near-surface sun rays. This table is the source; `lune run tools/gen/lighting`
-- writes each preset's export file, `assets/export/lighting/<Name>.json` (07 section 1.3), with
-- the same keys. tests/unit/Data/LightingPresets.spec.luau checks the table against 06.
-- `TideController` applies a preset on the client (docs/09, section 4.5). Pure: no `game`, no
-- Instances, colours as hex strings (docs/09, section 4.4).
--
-- Fog (06 section 10.2, spike F21): legacy fog, not Atmosphere. `FogColor` is the zone's fog
-- colour (06 section 4.2), `FogEnd` its target view distance, `FogStart` 25% of that. The
-- Atmosphere values are kept for the follow-up 06 names and are not applied: fog properties are
-- hidden while Lighting holds an Atmosphere.
--
-- Every number here is **(tune)** in 06.

export type Fog = {
	Color: string,
	TargetViewDistance: number, -- studs: where a white 8-stud ball disappears (06 section 10.2)
	StartFraction: number, -- FogStart as a share of the view distance
}

export type ColorCorrection = {
	Brightness: number,
	Contrast: number,
	Saturation: number,
	TintColor: string,
}
export type Bloom = { Intensity: number, Size: number, Threshold: number }
export type SunRays = { Intensity: number, Spread: number, WithinSurface: number } -- on within this many studs of the surface
export type Atmosphere = {
	Density: number,
	Offset: number,
	Haze: number,
	Glare: number,
	Color: string,
	Decay: string,
}

export type Preset = {
	name: string, -- chapter 07 name, `LGT_<Name>`
	zoneRow: string, -- the 06 section 10.2 row, which is also `ZoneDef.lightingPreset`
	Brightness: number,
	Ambient: string,
	OutdoorAmbient: string,
	ColorShift_Top: string,
	ExposureCompensation: number,
	ClockTime: number,
	GeographicLatitude: number,
	Fog: Fog,
	ColorCorrection: ColorCorrection,
	Bloom: Bloom,
	SunRays: SunRays,
	Caustics: boolean, -- floor caustic shells allowed (06 section 10.4: Nursery and Reef only)
	Atmosphere: Atmosphere, -- not applied while legacy fog is in use (06 section 10.2)
}

local LightingPresets = {}

-- 15 section 3.0 (quoted in 06 section 10.2): underwater view distance caps by graphics tier,
-- applied by pulling the fog in; colours do not change. Pretty has no cap. 15.6 step 6 is the
-- struggling-phone cap.
LightingPresets.VIEW_CAP = table.freeze({ Smooth = 220, Balanced = 350, Struggling = 160 })

-- Post-processing shared by every zone (06 section 10.2, second table).
local COLOR_CORRECTION: ColorCorrection =
	table.freeze({ Brightness = 0.02, Contrast = 0.08, Saturation = 0.12, TintColor = "#FFFFFF" })
local BLOOM: Bloom = table.freeze({ Intensity = 0.6, Size = 24, Threshold = 0.95 })
local SUN_RAYS: SunRays = table.freeze({ Intensity = 0.08, Spread = 0.6, WithinSurface = 40 })

local PRESETS: { [string]: Preset } = {
	-- 06 section 10.2 row "Sunlit Reef"; fog colour from 06 section 4.2; fixed values from 10.1.
	LGT_Reef = {
		name = "LGT_Reef",
		zoneRow = "Sunlit Reef",
		Brightness = 2.0,
		Ambient = "#6FB6D9",
		OutdoorAmbient = "#9ED8F0",
		ColorShift_Top = "#FFF0B8",
		ExposureCompensation = 0.0,
		ClockTime = 13.0,
		GeographicLatitude = 15,
		Fog = { Color = "#1E9FD0", TargetViewDistance = 400, StartFraction = 0.25 },
		ColorCorrection = COLOR_CORRECTION,
		Bloom = BLOOM,
		SunRays = SUN_RAYS,
		Caustics = true,
		Atmosphere = {
			Density = 0.36,
			Offset = 0.1,
			Haze = 2.2,
			Glare = 0.3,
			Color = "#1E9FD0",
			Decay = "#7FE0E8",
		},
	},
}

local byZoneRow: { [string]: Preset } = {}
for _, preset in PRESETS do
	byZoneRow[preset.zoneRow] = preset
end

--- The preset with chapter 07 name `name`, or nil when it is not built yet.
function LightingPresets.get(name: string): Preset?
	return PRESETS[name]
end

--- The preset for a zone's `lightingPreset` (the 06 section 10.2 row name), or nil.
function LightingPresets.forZoneRow(row: string): Preset?
	return byZoneRow[row]
end

--- Every built preset name, sorted.
function LightingPresets.names(): { string }
	local out = {}
	for name in PRESETS do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

--- `FogStart` and `FogEnd` for `preset` under an optional tier cap (studs). The cap pulls the
--- whole fog in, so `FogStart` stays the same share of the distance actually seen.
function LightingPresets.fogRange(preset: Preset, cap: number?): (number, number)
	local fogEnd = preset.Fog.TargetViewDistance
	if cap and cap < fogEnd then
		fogEnd = cap
	end
	return fogEnd * preset.Fog.StartFraction, fogEnd
end

return LightingPresets
