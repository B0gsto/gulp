-- Lune: dump the Bone tree of a Studio-imported model .rbxm as JSON (rest CFrames relative to their
-- parent, plus the parts), for `animrbx.py build --rig` / `animrbx.py check` (port of the Sprint 0
-- spike tool). Only needed to re-measure the import convention; the build uses the measured one.
-- Usage: lune run dump_bones.luau <in.rbxm> <out.json>
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local inst = roblox.deserializeModel(fs.readFile(process.args[1]))
local out = { bones = {}, parts = {}, count = 0 }
local function comps(cf)
	return { cf:GetComponents() }
end
local function walk(x)
	if x.ClassName == "Bone" then
		out.count += 1
		table.insert(out.bones, { name = x.Name, parent = x.Parent.Name, parentClass = x.Parent.ClassName, cf = comps(x.CFrame) })
	elseif x:IsA("BasePart") then
		table.insert(out.parts, { name = x.Name, class = x.ClassName, cf = comps(x.CFrame), size = { x.Size.X, x.Size.Y, x.Size.Z } })
	end
	for _, c in x:GetChildren() do
		walk(c)
	end
end
for _, r in inst do
	walk(r)
end
fs.writeFile(process.args[2], serde.encode("json", out))
print(process.args[1], "bones", out.count, "parts", #out.parts)
