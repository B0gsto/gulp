--!strict
-- Lighting preset export (docs/07, sections 1.3 and 10; task S3-A2).
--   lune run tools/gen/lighting    src/shared/Data/LightingPresets → assets/export/lighting/LGT_*.json
-- The Luau table is the source (its values come from docs/06, section 10.2, and a unit spec checks
-- them); the export files are build output like the rest of assets/export/, so they are not
-- committed. Each file holds the preset record with the same keys.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local Files = require("../lib/files")
local LightingPresets = require("../../src/shared/Data/LightingPresets")

Files.requireRepoRoot()

local OUT = "assets/export/lighting"
fs.writeDir(OUT)
for _, name in LightingPresets.names() do
	local preset = LightingPresets.get(name) :: LightingPresets.Preset
	local path = `{OUT}/{name}.json`
	fs.writeFile(path, serde.encode("json", preset, true) .. "\n")
	stdio.write(`wrote {path}\n`)
end
