--!strict
-- Publishes build/ci.rbxl to the GULP CI place through Open Cloud (docs/09, section 17.2).
--   lune run tools/cloud/publish_ci
-- Needs ROBLOX_API_KEY with universe-places write on the CI place. Build first with
-- `lune run tools/check -- build`.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Files = require("../lib/files")
local OpenCloud = require("./open_cloud")

local PLACE_FILE = "build/ci.rbxl"

Files.requireRepoRoot()
local target = OpenCloud.targetOrSkip("publishing the CI place")
if not fs.isFile(PLACE_FILE) then
	OpenCloud.fail(`{PLACE_FILE} is missing: run \`lune run tools/check -- build\` first`)
end

local place = fs.readFile(PLACE_FILE)
local response = OpenCloud.request(
	"POST",
	`/universes/v1/{target.universeId}/places/{target.placeId}/versions?versionType=Published`,
	"application/octet-stream",
	place
)
if not response.ok then
	OpenCloud.fail(`publishing {PLACE_FILE} failed, {OpenCloud.explain(response)}`)
end

local decoded, body = pcall(serde.decode, "json" :: "json", response.body)
local version = if decoded and type(body) == "table" then body.versionNumber else nil
if type(version) ~= "number" then
	OpenCloud.fail(
		`publishing answered without a versionNumber: {string.sub(response.body, 1, 500)}`
	)
end
fs.writeFile(OpenCloud.VERSION_FILE, tostring(version))
OpenCloud.write(
	`published {PLACE_FILE} ({#place} bytes) to place {target.placeId} as version {version}`
)
