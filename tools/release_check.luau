--!strict
-- The release check of docs/07, section 16: fails while any row the build loads is still a
-- placeholder, or is final without its Roblox asset ID (section 1.5).
--   lune run tools/release_check                    assets/manifest.csv and its run-time copy
--   lune run tools/release_check -- <file.csv>      another manifest (the specs use fixtures)
-- Exit 0 when every row is final, 1 with the list of offending rows, 2 on a bad manifest.
-- Not a step of tools/check: the build is all placeholders until art lands. Run it before a
-- release (docs/09, section 17.2).
local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local Files = require("./lib/files")
local Manifest = require("../src/shared/Data/Manifest")
local ManifestFiles = require("./lib/manifest_files")

local function say(text: string)
	stdio.write(text .. "\n")
end

local function stop(message: string): never
	stdio.ewrite(`release check: {message}\n`)
	return process.exit(2)
end

Files.requireRepoRoot()

local path: string? = nil
for _, arg in process.args do
	if arg ~= "--" then
		if path then
			stop("usage: lune run tools/release_check [-- <manifest.csv>]")
		end
		path = arg
	end
end
local csvPath = path or ManifestFiles.CSV
if not fs.isFile(csvPath) then
	stop(`{csvPath} not found`)
end

local csv = fs.readFile(csvPath)
local parsed, result = pcall(Manifest.parse, csv)
if not parsed then
	stop(`{csvPath}: {tostring(result)}`)
end
local manifest = result :: Manifest.Manifest

-- The build loads Config/AssetManifest, so the shipped manifest must also match its copy.
local stale = false
if path == nil then
	local module = if fs.isFile(ManifestFiles.MODULE) then fs.readFile(ManifestFiles.MODULE) else ""
	stale = module ~= ManifestFiles.moduleSource(csv)
	if stale then
		say(`{ManifestFiles.MODULE} does not match {csvPath}: run \`lune run tools/gen/manifest\``)
	end
end

local problems = Manifest.releaseProblems(manifest)
for _, problem in problems do
	say(`  {csvPath}:{problem.line}  {problem.name}  {problem.reason}`)
end
if #problems > 0 or stale then
	say(`RELEASE CHECK FAIL: {#problems} of {#manifest.entries} rows are not final`)
	process.exit(1)
end
say(`RELEASE CHECK PASS: all {#manifest.entries} rows are final`)
process.exit(0)
