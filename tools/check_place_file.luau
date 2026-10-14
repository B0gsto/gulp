-- Checks the place settings of docs/09-technical-architecture.md section 15.4 in a saved world
-- place file. Studio code cannot read the streaming properties or AuthorityMode (spike tech-a
-- surprise 2, tech-b surprise 4), so tools/studio/check_place.luau reports them as UNREADABLE and
-- this script reads them from the file instead (task S1-C8).
--   lune run tools/check_place_file [-- path/to/place.rbxl]   (default assets/place/gulp-world.rbxl)
-- Exits 0 when every setting matches, 1 otherwise.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local path = process.args[1] or "assets/place/gulp-world.rbxl"
local game = roblox.deserializePlace(fs.readFile(path))

local SETTINGS: { { any } } = {
	{ "Workspace", "StreamingEnabled", true },
	{ "Workspace", "ModelStreamingBehavior", "Improved" },
	{ "Workspace", "StreamingIntegrityMode", "PauseOutsideLoadedArea" },
	{ "Workspace", "StreamingMinRadius", 128 },
	{ "Workspace", "StreamingTargetRadius", 512 },
	{ "Workspace", "StreamOutBehavior", "Opportunistic" },
	{ "Workspace", "AuthorityMode", "Automatic" },
	{ "Workspace", "SignalBehavior", "Deferred" },
	{ "Workspace", "PhysicsSteppingMethod", "Adaptive" },
	{ "Workspace", "FallenPartsDestroyHeight", -5000 },
	{ "Workspace", "Gravity", 196.2 },
	{ "Players", "CharacterAutoLoads", false },
	{ "VoiceChatService", "EnableDefaultVoice", false },
	{ "StarterGui", "ScreenOrientation", "LandscapeSensor" },
	{ "TextChatService", "ChatVersion", "TextChatService" },
}

local function same(actual: any, expected: any): boolean
	if type(expected) == "number" and type(actual) == "number" then
		return math.abs(actual - expected) < 1e-3
	end
	if type(expected) == "string" and typeof(actual) == "EnumItem" then
		return actual.Name == expected
	end
	return actual == expected
end

local failures = 0
local function line(ok: boolean, name: string, detail: string)
	if not ok then
		failures += 1
	end
	print(`{if ok then "PASS" else "FAIL"} {name}: {detail}`)
end

for _, row in SETTINGS do
	local serviceName, property, expected = row[1], row[2], row[3]
	local owner = game:FindFirstChildOfClass(serviceName)
	local ok, actual = pcall(function()
		return (owner :: any)[property]
	end)
	if not owner then
		line(false, `{serviceName}.{property}`, "service not in the file")
	elseif not ok then
		line(false, `{serviceName}.{property}`, `unreadable: {actual}`)
	else
		line(same(actual, expected), `{serviceName}.{property}`, `{actual} (want {expected})`)
	end
end

local workspace = game:FindFirstChildOfClass("Workspace") :: any
local collision = workspace and workspace:FindFirstChild("Collision")
line(
	collision ~= nil
		and collision.ClassName == "Model"
		and collision.ModelStreamingMode.Name == "Persistent",
	"Workspace.Collision",
	if collision then `{collision.ClassName}, {collision.ModelStreamingMode}` else "missing"
)

print(`check_place_file {path}: {if failures == 0 then "PASS" else `FAIL ({failures})`}`)
process.exit(if failures == 0 then 0 else 1)
