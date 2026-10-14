--!strict
-- TideController (docs/09, section 5.2: "lighting presets"; section 4.5 load order). This first
-- cut (task S3-A2) only applies a lighting preset from Data/LightingPresets to `Lighting`; the
-- tide countdown, the 1.5 s zone blend of 06 section 10.3 and the event looks of 10.6 come with
-- their own tasks. Lighting is written on the client, per player (06 section 10.1).
--
-- `LightingStyle` and `PrioritizeLightingQuality` are never written here: they live in the
-- project files (06 section 10.1, spike F22). Nor are the place-wide constants of 10.1
-- (`GlobalShadows`, `ShadowSoftness`, the environment scales).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LightingPresets = require(ReplicatedStorage.Shared.Data.LightingPresets)
local Log = require(ReplicatedStorage.Shared.Util.Log)

type Preset = LightingPresets.Preset

-- The reference preset (07 section 10), shown until zone lookup drives the choice.
local DEFAULT_PRESET = "LGT_Reef"

-- Effects the controller owns, by name, under `Lighting`.
local COLOR_NAME = "GulpColorCorrection"
local BLOOM_NAME = "GulpBloom"
local SUN_RAYS_NAME = "GulpSunRays"

local TideController = {}
TideController.name = "TideController"

local current: Preset? = nil
local currentCap: number? = nil

local function owned<T>(className: string, name: string): T
	local found = Lighting:FindFirstChild(name)
	if found and found.ClassName == className then
		return (found :: any) :: T
	end
	if found then
		found:Destroy()
	end
	local made = Instance.new(className :: any)
	made.Name = name
	made.Parent = Lighting
	return (made :: any) :: T
end

--- Writes `preset` to `Lighting`. `cap` is the graphics tier's view-distance cap in studs
--- (LightingPresets.VIEW_CAP), nil on Pretty. `cameraY` turns the sun rays on within
--- `SunRays.WithinSurface` studs of the surface at Y = 0 (06 section 10.2).
function TideController.applyPreset(preset: Preset, cap: number?, cameraY: number?)
	-- Legacy fog is hidden while an Atmosphere exists (06 section 2.4, 10.2): remove any.
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") then
			child:Destroy()
		end
	end

	Lighting.Brightness = preset.Brightness
	Lighting.Ambient = Color3.fromHex(preset.Ambient)
	Lighting.OutdoorAmbient = Color3.fromHex(preset.OutdoorAmbient)
	Lighting.ColorShift_Top = Color3.fromHex(preset.ColorShift_Top)
	Lighting.ExposureCompensation = preset.ExposureCompensation
	Lighting.ClockTime = preset.ClockTime
	Lighting.GeographicLatitude = preset.GeographicLatitude

	local fogStart, fogEnd = LightingPresets.fogRange(preset, cap)
	Lighting.FogColor = Color3.fromHex(preset.Fog.Color)
	Lighting.FogStart = fogStart
	Lighting.FogEnd = fogEnd

	local cc = owned("ColorCorrectionEffect", COLOR_NAME) :: ColorCorrectionEffect
	cc.Brightness = preset.ColorCorrection.Brightness
	cc.Contrast = preset.ColorCorrection.Contrast
	cc.Saturation = preset.ColorCorrection.Saturation
	cc.TintColor = Color3.fromHex(preset.ColorCorrection.TintColor)
	cc.Enabled = true

	local bloom = owned("BloomEffect", BLOOM_NAME) :: BloomEffect
	bloom.Intensity = preset.Bloom.Intensity
	bloom.Size = preset.Bloom.Size
	bloom.Threshold = preset.Bloom.Threshold
	bloom.Enabled = true

	local rays = owned("SunRaysEffect", SUN_RAYS_NAME) :: SunRaysEffect
	rays.Intensity = preset.SunRays.Intensity
	rays.Spread = preset.SunRays.Spread
	rays.Enabled = cameraY ~= nil and cameraY > -preset.SunRays.WithinSurface

	-- Depth of field is off during play (06 section 10.2).
	for _, child in Lighting:GetChildren() do
		if child:IsA("DepthOfFieldEffect") then
			child.Enabled = false
		end
	end

	current = preset
	currentCap = cap
end

--- Applies the preset with chapter 07 name `name`; false when it is not built yet.
function TideController.apply(name: string, cap: number?, cameraY: number?): boolean
	local preset = LightingPresets.get(name)
	if not preset then
		Log.warn("TideController", `no lighting preset {name}`)
		return false
	end
	TideController.applyPreset(preset, cap, cameraY)
	return true
end

--- The preset last applied and its cap.
function TideController.preset(): (Preset?, number?)
	return current, currentCap
end

function TideController.init() end

function TideController.start()
	local camera = workspace.CurrentCamera
	TideController.apply(DEFAULT_PRESET, nil, if camera then camera.CFrame.Position.Y else nil)
end

return TideController
