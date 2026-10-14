-- Spike part D (S0-A3/S0-A4): which texture properties can a normal game script write at run time?
-- drive_d.py puts this source in a server Script (ServerScriptService) or a LocalScript (PlayerScripts) during a play
-- test, with `local SIDE = "server"|"client"` prepended. It runs with game-script rights, not plugin rights.
-- Result: ReplicatedStorage.DTexResult_<SIDE> (StringValue, JSON).
local RS = game:GetService("ReplicatedStorage")
local AS = game:GetService("AssetService")
local HS = game:GetService("HttpService")
local IMG = "rbxassetid://90248245390211"
local IMG2 = "rbxassetid://133030237967373"
local r = { side = SIDE }
local function try(k, f)
	local ok, e = pcall(f)
	r[k] = ok and (e == nil and "ok" or ("ok " .. tostring(e))) or ("ERR " .. string.sub(tostring(e), 1, 150))
end
local body = RS:WaitForChild("ArtC", 10).Body:FindFirstChildWhichIsA("MeshPart", true)
local mp, sa, img
try("meshpart.clone", function()
	mp = body:Clone() mp.Name = "DTex_" .. SIDE mp.Anchored = true
	mp.CFrame = CFrame.new(0, 320, SIDE == "server" and -150 or -144) mp.Parent = workspace
end)
try("sa.new", function() sa = Instance.new("SurfaceAppearance") end)
try("sa.ColorMap (string)", function() sa.ColorMap = IMG end)
try("sa.ColorMapContent", function() sa.ColorMapContent = Content.fromUri(IMG) return sa.ColorMapContent.Uri end)
try("sa.NormalMapContent", function() sa.NormalMapContent = Content.fromUri(IMG) end)
try("sa.RoughnessMapContent", function() sa.RoughnessMapContent = Content.fromUri(IMG) end)
try("sa.MetalnessMapContent", function() sa.MetalnessMapContent = Content.fromUri(IMG) end)
try("sa.EmissiveMaskContent", function() sa.EmissiveMaskContent = Content.fromUri(IMG2) end)
try("sa.EmissiveStrength", function() sa.EmissiveStrength = 2 end)
try("sa.EmissiveTint", function() sa.EmissiveTint = Color3.fromHex("#FFE2A8") end)
try("sa.Color", function() sa.Color = Color3.new(1, 0.6, 0.6) end)
try("sa.AlphaMode", function() sa.AlphaMode = Enum.AlphaMode.Transparency end)
try("sa.Parent = meshpart", function() sa.Parent = mp end)
try("sa.ColorMapContent live swap", function() sa.ColorMapContent = Content.fromUri(IMG2) return sa.ColorMapContent.Uri end)
try("editSA.clone + swap", function()
	local c = RS.DTexEdit:Clone() c.Name = "DTexEditClone_" .. SIDE c.Anchored = true c.Parent = workspace
	c.SurfaceAppearance.ColorMapContent = Content.fromUri(IMG2)
	return c.SurfaceAppearance.ColorMapContent.Uri
end)
try("meshpart.TextureID", function() mp.TextureID = IMG return mp.TextureID end)
try("meshpart.TextureContent", function() mp.TextureContent = Content.fromUri(IMG2) end)
try("meshpart.MeshId", function() mp.MeshId = "rbxassetid://89699184428054" end)
try("meshpart.MeshContent", function() mp.MeshContent = Content.fromUri(body.MeshId) end)
try("decal.Texture", function() local d = Instance.new("Decal") d.Texture = IMG d.Parent = mp end)
try("decal.TextureContent", function() local d = Instance.new("Decal") d.TextureContent = Content.fromUri(IMG) d.Parent = mp end)
try("texture.Texture", function() local t = Instance.new("Texture") t.Texture = IMG t.Parent = mp end)
try("overlayB.clone 1.005 + SA", function()
	local o = mp:Clone() o.Name = "DTexOverlay_" .. SIDE o.Size = mp.Size * 1.005 o.Parent = workspace
	o:FindFirstChildOfClass("SurfaceAppearance").ColorMapContent = Content.fromUri(IMG2)
end)
try("editableImage.create", function() img = AS:CreateEditableImage({ Size = Vector2.new(64, 64) }) end)
if img then
	try("sa.ColorMapContent = EditableImage", function() sa.ColorMapContent = Content.fromObject(img) end)
	try("meshpart.TextureContent = EditableImage", function() mp.TextureContent = Content.fromObject(img) end)
end
try("editableMesh.create", function() return #AS:CreateEditableMeshAsync(Content.fromUri(body.MeshId)):GetVertices() end)
local sv = Instance.new("StringValue") sv.Name = "DTexResult_" .. SIDE sv.Value = HS:JSONEncode(r) sv.Parent = RS
