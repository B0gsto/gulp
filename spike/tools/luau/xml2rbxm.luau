-- Lune: convert an .rbxmx (XML model) to binary .rbxm. Open Cloud rejects model/x-rbxmx for Animation assets.
-- Usage: lune run xml2rbxm.luau <in.rbxmx> <out.rbxm>
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local inst = roblox.deserializeModel(fs.readFile(process.args[1]))
local kf = inst[1]
print(kf.ClassName, kf.Name, "Loop", kf.Loop, "Priority", kf.Priority, "keyframes", #kf:GetChildren())
fs.writeFile(process.args[2], roblox.serializeModel(inst))
