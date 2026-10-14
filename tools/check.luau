--!strict
-- The headless gate (docs/09, sections 2.4 and 16.6). Needs no Studio.
--   lune run tools/check                 every step in order, stopping at the first failure
--   lune run tools/check -- lint types   only the named steps (CI runs one step per job)
-- Steps: lint, types, gen, unit, sim, build. Exit code 0 when every step run passed, else 1.
local datetime = require("@lune/datetime")
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local DependencyRules = require("./lib/dependency_rules")
local Files = require("./lib/files")

type Step = { name: string, what: string, run: () -> boolean }

local GENERATED_ROOT = "src/shared/Data/Generated"
local CI_PLACE = "build/ci.rbxl"
local CI_VERSION = "build/ci.version" -- written by tools/cloud/publish_ci.luau
local SOURCEMAP = "sourcemap.json"
local PURE_LINT_DIR = "tools/lint"

-- Rokit's shims must win over any other copy of the tools (docs/09, section 2.1).
local childEnv: { [string]: string } = {}
do
	local home = process.env.HOME
	if home and fs.isDir(`{home}/.rokit/bin`) then
		childEnv.PATH = `{home}/.rokit/bin:{process.env.PATH or ""}`
	end
end

local function now(): number
	return datetime.now().unixTimestampMillis / 1000
end

local function say(text: string)
	stdio.write(text .. "\n")
end

-- Runs one command with its output shown. False when it exits non-zero or cannot start.
local function run(program: string, args: { string }, cwd: string?): boolean
	local prefix = if cwd then `(in {cwd}) ` else ""
	say(`  $ {prefix}{program} {table.concat(args, " ")}`)
	local started, result = pcall(process.exec, program, args, {
		stdio = "inherit",
		env = childEnv,
		cwd = cwd,
	})
	if not started then
		say(`  could not start {program}: is it installed? Run \`rokit install\`.`)
		return false
	end
	return result.ok
end

-- The pinned luau-lsp version from rokit.toml, so the Roblox definitions match the analyzer.
local function luauLspVersion(): string
	local version = string.match(fs.readFile("rokit.toml"), 'luau%-lsp%s*=%s*"[^"@]+@([^"]+)"')
	return version or error("rokit.toml does not pin luau-lsp", 0)
end

-- `luau-lsp analyze` does not fetch Roblox definitions itself, so keep the file that belongs
-- to the pinned version in .cache/ (not committed). Returns its path, or nil when it is missing
-- and cannot be downloaded.
local function robloxDefinitions(): string?
	local version = luauLspVersion()
	local path = `.cache/globalTypes-{version}.d.luau`
	if fs.isFile(path) then
		return path
	end
	local url =
		`https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/{version}/scripts/globalTypes.d.luau`
	say(`  downloading Roblox definitions for luau-lsp {version}`)
	local sent, response = pcall(net.request, { url = url, method = "GET" })
	if not sent or not response.ok or #response.body < 100_000 then
		local reason = if sent then `HTTP {response.statusCode}` else tostring(response)
		say(`  could not download {url}: {reason}`)
		return nil
	end
	fs.writeDir(".cache")
	fs.writeFile(path, response.body)
	return path
end

-- Section 4.4, script half: the banned names in the pure roots.
local function dependencyScript(): boolean
	local files, bad = 0, 0
	for _, root in DependencyRules.PURE_ROOTS do
		for _, path in Files.walk(root, ".luau") do
			files += 1
			for _, violation in DependencyRules.check(fs.readFile(path)) do
				bad += 1
				say(`  {path}:{violation.line}: {violation.token} is not allowed in a pure module`)
			end
		end
	end
	say(`  dependency rules: {files} pure files checked, {bad} banned uses`)
	return bad == 0
end

-- Section 4.4, "Only EconomyService changes Pearls": no other server file writes `pearls`.
local function pearlScript(): boolean
	local files, bad = 0, 0
	for _, path in Files.walk(DependencyRules.PEARL_ROOT, ".luau") do
		if DependencyRules.pearlRuleApplies(path) then
			files += 1
			for _, violation in DependencyRules.pearlWrites(fs.readFile(path)) do
				bad += 1
				say(
					`  {path}:{violation.line}: {violation.token}: only EconomyService changes Pearls`
				)
			end
		end
	end
	say(`  pearl rule: {files} server files checked, {bad} writes outside EconomyService`)
	return bad == 0
end

-- Section 4.4, Selene half: the pure roots linted against plain Luau.
local function dependencySelene(): boolean
	local roots: { string } = {}
	for _, root in DependencyRules.PURE_ROOTS do
		if #Files.walk(root, ".luau") > 0 then
			table.insert(roots, `../../{root}`)
		end
	end
	if #roots == 0 then
		return true
	end
	return run("selene", roots, PURE_LINT_DIR)
end

local function snapshot(root: string): { [string]: string }
	local contents: { [string]: string } = {}
	for _, path in Files.walk(root, ".luau") do
		contents[path] = fs.readFile(path)
	end
	return contents
end

local STEPS: { Step } = {
	{
		name = "lint",
		what = "format, lint and the dependency rules",
		run = function()
			return run("stylua", { "--check", "src", "tests", "tools" })
				and run("selene", { "src" })
				and dependencyScript()
				and pearlScript()
				and dependencySelene()
		end,
	},
	{
		name = "types",
		what = "sourcemap and strict type check",
		run = function()
			if not run("rojo", { "sourcemap", "default.project.json", "--output", SOURCEMAP }) then
				return false
			end
			local definitions = robloxDefinitions()
			if not definitions then
				return false
			end
			return run("luau-lsp", {
				"analyze",
				"--platform",
				"roblox",
				"--sourcemap",
				SOURCEMAP,
				"--base-luaurc",
				".luaurc",
				"--definitions",
				`@roblox={definitions}`,
				"--ignore",
				"Packages/**",
				"--ignore",
				"**/Vendor/**",
				"src",
			})
		end,
	},
	{
		name = "gen",
		what = "generated content matches the documents",
		run = function()
			-- Regenerate and compare with what was on disk, so this also works on a tree with
			-- uncommitted work. On a clean checkout it equals `git diff --exit-code`.
			local before = snapshot(GENERATED_ROOT)
			-- Content from the bible's tables; the English string table from assets/loc (18.1).
			if
				not run("lune", { "run", "tools/gen/content" })
				or not run("lune", { "run", "tools/gen/strings" })
			then
				return false
			end
			local after = snapshot(GENERATED_ROOT)
			local stale: { string } = {}
			for path, content in after do
				if before[path] ~= content then
					table.insert(stale, path)
				end
			end
			for path in before do
				if after[path] == nil then
					table.insert(stale, path)
				end
			end
			table.sort(stale)
			for _, path in stale do
				say(`  {path} was out of date and has been regenerated: commit it`)
			end
			return #stale == 0
		end,
	},
	{
		name = "unit",
		what = "unit tests",
		run = function()
			return run("lune", { "run", "tools/test/runner", "--", "unit" })
		end,
	},
	{
		name = "sim",
		what = "simulation tests",
		run = function()
			return run("lune", { "run", "tools/test/runner", "--", "sim" })
		end,
	},
	{
		name = "build",
		what = "the CI place",
		run = function()
			fs.writeDir("build")
			-- A new build has not been published: drop the version note of the last one, so
			-- run_engine_tests cannot run on an older place.
			if fs.isFile(CI_VERSION) then
				fs.removeFile(CI_VERSION)
			end
			return run("rojo", { "build", "ci.project.json", "-o", CI_PLACE })
		end,
	},
}

local function usage(): never
	local names: { string } = {}
	for _, step in STEPS do
		table.insert(names, step.name)
	end
	stdio.ewrite(`usage: lune run tools/check [-- step ...]\nsteps: {table.concat(names, ", ")}\n`)
	return process.exit(2)
end

local wanted: { Step } = {}
for _, arg in process.args do
	if arg ~= "--" then
		local known: Step? = nil
		for _, step in STEPS do
			if step.name == arg then
				known = step
			end
		end
		table.insert(wanted, known or usage())
	end
end
if #wanted == 0 then
	wanted = STEPS
end
Files.requireRepoRoot()

local passedNames: { string } = {}
for _, step in wanted do
	say(`== {step.name}: {step.what}`)
	local started = now()
	local finished, passed = pcall(step.run)
	local seconds = string.format("%.1f", now() - started)
	if not finished then
		say(`  {tostring(passed)}`)
	end
	if finished and passed then
		say(`PASS {step.name} ({seconds} s)`)
		table.insert(passedNames, step.name)
	else
		say(`FAIL {step.name} ({seconds} s)`)
		local before = if #passedNames > 0 then table.concat(passedNames, ", ") else "nothing"
		say(`\nGATE FAIL at {step.name} (passed before it: {before})`)
		process.exit(1)
	end
end
say(`\nGATE PASS: {table.concat(passedNames, ", ")}`)
process.exit(0)
