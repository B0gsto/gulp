--!strict
-- Shared by the Open Cloud tools (docs/09, sections 16.3, 16.6 and 17.2). Open Cloud is used
-- for the GULP CI place only; the world place is published by hand from Studio.
-- The API key comes from the environment variable ROBLOX_API_KEY and is sent as `x-api-key`.
-- It is never printed, and neither are request headers.
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

export type Target = { universeId: number, placeId: number }
export type Response = { ok: boolean, statusCode: number, body: string }

local TARGET_FILE = "tools/cloud/target.json"
local API_ROOT = "https://apis.roblox.com"

local OpenCloud = {}

OpenCloud.API_ROOT = API_ROOT
-- Written by publish_ci, read by run_engine_tests, so the specs run on the build just sent.
OpenCloud.VERSION_FILE = "build/ci.version"

--- Prints a line, and marks it as an annotation when running in GitHub Actions.
function OpenCloud.announce(level: "notice" | "error", text: string)
	if process.env.GITHUB_ACTIONS == "true" then
		print(`::{level}::{text}`)
	else
		print(text)
	end
end

--- Prints the problem and stops with exit code 1.
function OpenCloud.fail(text: string): never
	OpenCloud.announce("error", text)
	return process.exit(1)
end

--- The CI universe and place from tools/cloud/target.json.
function OpenCloud.readTarget(): Target
	local decoded = serde.decode("json", fs.readFile(TARGET_FILE))
	local universeId, placeId = decoded.universeId, decoded.placeId
	if type(universeId) ~= "number" or type(placeId) ~= "number" then
		OpenCloud.fail(`{TARGET_FILE} must hold the numbers universeId and placeId`)
	end
	return { universeId = universeId, placeId = placeId }
end

--- The target, or a clean exit with a notice while the GULP CI experience does not exist yet.
function OpenCloud.targetOrSkip(action: string): Target
	local target = OpenCloud.readTarget()
	if target.universeId == 0 or target.placeId == 0 then
		OpenCloud.announce(
			"notice",
			`GULP CI place not configured yet: skipped {action}. `
				.. `Put the universe and place IDs of the GULP CI experience in {TARGET_FILE}.`
		)
		process.exit(0)
	end
	return target
end

local function apiKey(): string
	local key = process.env.ROBLOX_API_KEY
	if not key or key == "" then
		return OpenCloud.fail("the environment variable ROBLOX_API_KEY is not set")
	end
	return key
end

--- One Open Cloud call. `path` starts with a slash. Stops on a network failure.
function OpenCloud.request(
	method: "GET" | "POST",
	path: string,
	contentType: string?,
	body: string?
): Response
	local sent, response = pcall(net.request, {
		url = API_ROOT .. path,
		method = method,
		headers = { ["x-api-key"] = apiKey(), ["Content-Type"] = contentType },
		body = body,
	})
	if not sent then
		-- The error text of a failed request holds no headers, so no key.
		return OpenCloud.fail(`{method} {path} could not be sent: {tostring(response)}`)
	end
	return { ok = response.ok, statusCode = response.statusCode, body = response.body }
end

--- What to tell the owner when Open Cloud refuses a call.
function OpenCloud.explain(response: Response): string
	local hint = ""
	if response.statusCode == 401 or response.statusCode == 403 then
		hint = " (the key needs universe-places write and"
			.. " universe.place.luau-execution-session:write on the GULP CI experience)"
	end
	return `HTTP {response.statusCode}{hint}: {string.sub(response.body, 1, 500)}`
end

function OpenCloud.write(text: string)
	stdio.write(text .. "\n")
end

return OpenCloud
