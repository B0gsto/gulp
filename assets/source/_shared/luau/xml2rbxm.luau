-- Lune: .rbxmx KeyframeSequence -> binary .rbxm (Open Cloud takes only binary .rbxm for Animation
-- assets; docs/spike-report.md F20), then reads the .rbxm back and writes what it holds as JSON, so
-- the build can check the pose names against the rig (clips.py, step clips-rbxm).
-- Usage: lune run xml2rbxm.luau <in.rbxmx> <out.rbxm> <summary.json>
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local inPath, outPath, summaryPath = process.args[1], process.args[2], process.args[3]
assert(inPath and outPath and summaryPath, "usage: lune run xml2rbxm.luau <in.rbxmx> <out.rbxm> <summary.json>")
fs.writeFile(outPath, roblox.serializeModel(roblox.deserializeModel(fs.readFile(inPath))))

-- Read back the binary file, not the XML: this is what would be uploaded.
local back = roblox.deserializeModel(fs.readFile(outPath))
assert(#back == 1, "expected one root instance, got " .. #back)
local kfs = back[1]
local poses, rootPoses, keyframes, last, perFrame = {}, {}, 0, 0, {}
local function walk(pose, depth)
	if depth == 0 then
		rootPoses[pose.Name] = true
	else
		poses[pose.Name] = true
	end
	for _, child in pose:GetChildren() do
		if child.ClassName == "Pose" then
			walk(child, depth + 1)
		end
	end
end
for _, kf in kfs:GetChildren() do
	if kf.ClassName == "Keyframe" then
		keyframes += 1
		last = math.max(last, kf.Time)
		local count = 0
		for _, p in kf:GetDescendants() do
			if p.ClassName == "Pose" then count += 1 end
		end
		table.insert(perFrame, count)
		for _, p in kf:GetChildren() do
			if p.ClassName == "Pose" then walk(p, 0) end
		end
	end
end
local names, roots = {}, {}
for n in poses do table.insert(names, n) end
for n in rootPoses do table.insert(roots, n) end
table.sort(names)
local summary = {
	class = kfs.ClassName, name = kfs.Name, loop = kfs.Loop, priority = kfs.Priority.Name,
	keyframes = keyframes, length = last, rootPoses = roots, bones = names,
	posesPerKeyframe = perFrame, bytes = #fs.readFile(outPath),
}
fs.writeFile(summaryPath, serde.encode("json", summary))
print(string.format("%s %s: %d keyframes, %.3f s, loop %s, %s, %d bones, %d bytes", kfs.ClassName, kfs.Name,
	keyframes, last, tostring(kfs.Loop), kfs.Priority.Name, #names, summary.bytes))
