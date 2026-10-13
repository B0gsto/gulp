--!strict
-- The Lune front end of TestKit (docs/09, sections 16.1 and 16.2).
--   lune run tools/test/runner -- unit    runs tests/unit/**/*.spec.luau
--   lune run tools/test/runner -- sim     runs tests/sim/**/*.sim.luau
-- Prints every failure and exits with code 1 when anything failed.
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local Files = require("../lib/files")
local TestKit = require("../../src/shared/Util/TestKit")

local SUITES = {
	unit = { root = "tests/unit", suffix = ".spec.luau" },
	sim = { root = "tests/sim", suffix = ".sim.luau" },
}

local function fail(message: string): never
	stdio.ewrite(message .. "\n")
	return process.exit(2)
end

local args = table.clone(process.args)
if args[1] == "--" then
	table.remove(args, 1)
end
local suiteName = args[1] or ""
local suite = SUITES[suiteName]
if not suite or #args > 1 then
	fail("usage: lune run tools/test/runner -- unit|sim")
end
Files.requireRepoRoot()

local started = os.clock()
local files = Files.walk(suite.root, suite.suffix)
local passed, failed = 0, 0

for _, path in files do
	-- Lune resolves a require relative to this file, so go up from tools/test to the root.
	local modulePath = "../../" .. string.sub(path, 1, -#".luau" - 1)
	local loaded, problem = pcall(require, modulePath)
	local summary = TestKit.run()
	if not loaded then
		summary.failed += 1
		table.insert(summary.failures, { name = "(loading the file)", message = tostring(problem) })
	end
	passed += summary.passed
	failed += summary.failed
	if summary.failed > 0 then
		print(`{path}\n{TestKit.report(summary)}`)
	end
end

local seconds = string.format("%.2f", os.clock() - started)
local verdict = if failed == 0 then "PASS" else "FAIL"
print(`{verdict} {suiteName}: {passed} passed, {failed} failed in {#files} files ({seconds} s)`)
process.exit(if failed == 0 then 0 else 1)
