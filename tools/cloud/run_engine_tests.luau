--!strict
-- Runs the engine specs on the GULP CI place through Open Cloud Luau execution
-- (docs/09, sections 16.3 and 16.6).
--   lune run tools/cloud/run_engine_tests
-- One task runs Tests/RunAll, which returns TestKit's report: a first line starting with PASS
-- or FAIL. Needs ROBLOX_API_KEY with universe.place.luau-execution-session:write. Runs on the
-- version publish_ci just wrote when there is one, else on the place's latest version.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local task = require("@lune/task")

local Files = require("../lib/files")
local OpenCloud = require("./open_cloud")

local SCRIPT = "return require(game.ServerScriptService.Server.Tests.RunAll)()"
local TASK_TIMEOUT = "300s" -- a task may run for up to 5 minutes
local POLL_SECONDS = 3
local GIVE_UP_SECONDS = 420

type Json = { [string]: any }

local function decode(response: OpenCloud.Response, what: string): Json
	if not response.ok then
		OpenCloud.fail(`{what} failed, {OpenCloud.explain(response)}`)
	end
	local decoded, body = pcall(serde.decode, "json" :: "json", response.body)
	if not decoded or type(body) ~= "table" then
		OpenCloud.fail(`{what} answered with something that is not JSON`)
	end
	return body
end

Files.requireRepoRoot()
local target = OpenCloud.targetOrSkip("the engine tests")

local place = `/cloud/v2/universes/{target.universeId}/places/{target.placeId}`
if fs.isFile(OpenCloud.VERSION_FILE) then
	local version = string.match(fs.readFile(OpenCloud.VERSION_FILE), "^%d+")
	if version then
		place ..= `/versions/{version}`
	end
end

local created = decode(
	OpenCloud.request(
		"POST",
		`{place}/luau-execution-session-tasks`,
		"application/json",
		serde.encode("json", { script = SCRIPT, timeout = TASK_TIMEOUT })
	),
	"creating the Luau execution task"
)
local taskPath = created.path
if type(taskPath) ~= "string" then
	OpenCloud.fail("the Luau execution task has no path")
end
OpenCloud.write(`engine tests: task {taskPath}`)

local current = created
local waited = 0
while current.state ~= "COMPLETE" and current.state ~= "FAILED" and current.state ~= "CANCELLED" do
	if waited >= GIVE_UP_SECONDS then
		OpenCloud.fail(`the task is still {tostring(current.state)} after {waited} s`)
	end
	task.wait(POLL_SECONDS)
	waited += POLL_SECONDS
	current = decode(OpenCloud.request("GET", `/cloud/v2/{taskPath}`), "reading the task")
end

-- What the specs printed. Only a help when something failed, so a refusal here is not fatal.
local logs = OpenCloud.request("GET", `/cloud/v2/{taskPath}/logs`)
local logsDecoded, logsBody = pcall(serde.decode, "json" :: "json", logs.body)
if logs.ok and logsDecoded and type(logsBody) == "table" then
	for _, entry in logsBody.luauExecutionSessionTaskLogs or {} do
		for _, message in entry.messages or {} do
			OpenCloud.write(`  | {tostring(message)}`)
		end
	end
end

if current.state ~= "COMPLETE" then
	local problem = current.error or {}
	OpenCloud.fail(
		`the task ended {current.state}: {tostring(problem.code)} {tostring(problem.message)}`
	)
end

local results = if type(current.output) == "table" then current.output.results else nil
local report = if type(results) == "table" then results[1] else nil
if type(report) ~= "string" then
	OpenCloud.fail("Tests/RunAll did not return its summary string")
end
OpenCloud.write(report)
if string.sub(report, 1, 5) ~= "PASS:" then
	OpenCloud.fail("engine tests failed")
end
