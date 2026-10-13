--!strict
-- File helpers shared by the Lune tools. Paths are relative to the repository root, which is
-- where every tool is run from.
local fs = require("@lune/fs")

local Files = {}

--- Every file under `root` whose name ends with `suffix` ("" for all), sorted. A missing root
--- gives {}.
function Files.walk(root: string, suffix: string): { string }
	local found: { string } = {}
	local function visit(dir: string)
		for _, name in fs.readDir(dir) do
			local path = `{dir}/{name}`
			if fs.isDir(path) then
				visit(path)
			elseif suffix == "" or string.sub(name, -#suffix) == suffix then
				table.insert(found, path)
			end
		end
	end
	if fs.isDir(root) then
		visit(root)
	end
	table.sort(found)
	return found
end

--- Stops with a clear message unless the tool was started from the repository root.
function Files.requireRepoRoot()
	if not (fs.isFile("rokit.toml") and fs.isFile("default.project.json")) then
		error("run this from the repository root (rokit.toml not found here)", 0)
	end
end

return Files
