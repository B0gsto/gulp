#!/usr/bin/env python3
"""Spike part C driver: the Studio half of the art spikes (S0-A1..A5) and S8/S18 on the uploaded skinned rig.
Run under spike/tools/held.sh.  drive_c.py run   (edit-mode insert and checks, play 1 Realistic, play 2 Soft)
Assets come from spike/tools/upload_c.py (ids in spike/out/oc/manifest.json). Results: spike/out/c-*.json, c-*.png.
Nothing is saved: the ArtC folder and Lighting are restored before the driver exits."""
import json, os, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from drive import Drv, StudioSession, save, OUT  # noqa: E402
from drive_b import front, spike_pid, lua_json  # noqa: E402
import drive_b  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
IDS = {"Cube": 89699184428054, "Rig": 125091724092068, "Body": 135992079926798}
CLIP = open(os.path.join(HERE, "luau", "clip.luau")).read()
MOD = open(os.path.join(HERE, "luau", "artc.luau")).read()

EDIT = r"""
local IS = game:GetService("InsertService")
local RS = game:GetService("ReplicatedStorage")
local AS = game:GetService("AssetService")
local L = game:GetService("Lighting")
local out = {}
local f = RS:FindFirstChild("ArtC") or Instance.new("Folder")
f.Name = "ArtC" f.Parent = RS
for k, id in %s do
  if not f:FindFirstChild(k) then
    local ok, m = pcall(IS.LoadAsset, IS, id)
    if ok then local c = m:GetChildren()[1] c.Name = k c.Parent = f m:Destroy() else out["load" .. k] = tostring(m) end
  end
end
-- S0-A1: the cube as inserted, with no fix
local cube = f.Cube:FindFirstChildWhichIsA("MeshPart")
out.cubeSize = tostring(cube.Size) out.cubeCF = tostring(cube.CFrame) out.cubeColor = tostring(cube.Color)
out.cubeExtentsSize = tostring(f.Cube:GetExtentsSize())
local ok, em = pcall(function() return AS:CreateEditableMeshAsync(Content.fromUri(cube.MeshId)) end)
if ok then
  local cols = {}
  for _, fid in em:GetFaces() do
    local cids = em:GetFaceColors(fid)
    local vids = em:GetFaceVertices(fid)
    for i, cid in cids do
      local c = em:GetColor(cid)
      local key = string.format("%%.3f,%%.3f,%%.3f", c.R, c.G, c.B)
      local e = cols[key] or { n = 0, sx = 0, sy = 0, sz = 0, minz = 1e9, maxz = -1e9 }
      local p = em:GetPosition(vids[i])
      e.n += 1 e.sx += p.X e.sy += p.Y e.sz += p.Z e.minz = math.min(e.minz, p.Z) e.maxz = math.max(e.maxz, p.Z)
      cols[key] = e
    end
  end
  local list = {}
  for k, e in cols do table.insert(list, { color = k, n = e.n, mean = string.format("%%.2f,%%.2f,%%.2f", e.sx / e.n, e.sy / e.n, e.sz / e.n), z = string.format("%%.2f..%%.2f", e.minz, e.maxz) }) end
  out.cubeColors = list
  local bb = { 1e9, -1e9, 1e9, -1e9, 1e9, -1e9 }
  for _, v in em:GetVertices() do local p = em:GetPosition(v) bb[1] = math.min(bb[1], p.X) bb[2] = math.max(bb[2], p.X) bb[3] = math.min(bb[3], p.Y) bb[4] = math.max(bb[4], p.Y) bb[5] = math.min(bb[5], p.Z) bb[6] = math.max(bb[6], p.Z) end
  out.cubeMeshBounds = bb
else out.editableMesh = tostring(em) end
-- skinned rig as uploaded
local rig = f.Rig
local nb = 0 for _, d in rig:GetDescendants() do if d:IsA("Bone") then nb += 1 end end
out.rigBones = nb
local hasSkin = {}
for _, p in rig:GetChildren() do if p:IsA("MeshPart") then hasSkin[p.Name] = { skinned = p.HasSkinnedMesh, dbl = p.DoubleSided, size = tostring(p.Size) } end end
out.rigParts = hasSkin
-- lighting style: who can write it
out.styleBefore = tostring(L.LightingStyle) out.prioBefore = L.PrioritizeLightingQuality
local w1, e1 = pcall(function() L.LightingStyle = Enum.LightingStyle["%s"] end)
local w2, e2 = pcall(function() L.PrioritizeLightingQuality = true end)
out.styleWrite = w1 or tostring(e1) out.prioWrite = w2 or tostring(e2)
out.styleAfter = tostring(L.LightingStyle) out.prioAfter = L.PrioritizeLightingQuality
-- SurfaceAppearance properties present in this build
local sa = Instance.new("SurfaceAppearance") local props = {}
for _, n in { "ColorMapContent", "RoughnessMapContent", "EmissiveMaskContent", "EmissiveStrength", "EmissiveTint", "Color", "AlphaMode" } do
  props[n] = (pcall(function() return sa[n] end)) end
sa:Destroy() out.saProps = props
return game:GetService("HttpService"):JSONEncode(out)
"""

RESTORE = r"""
local L = game:GetService("Lighting") local RS = game:GetService("ReplicatedStorage")
pcall(function() L.LightingStyle = Enum.LightingStyle["%s"] end) pcall(function() L.PrioritizeLightingQuality = %s end)
for _, n in { "ArtCCC", "ArtCBloom" } do local x = L:FindFirstChild(n) if x then x:Destroy() end end
local f = RS:FindFirstChild("ArtC") if f then f:Destroy() end
return tostring(L.LightingStyle) .. " " .. tostring(L.PrioritizeLightingQuality)
"""


def client(d, phase, args=None, timeout=90):
    code = "local buildClip = (function()\n%s\nend)()\nlocal ARGS = game:GetService('HttpService'):JSONDecode([==[%s]==])\n%s\nreturn M.%s(ARGS)" % (
        CLIP, json.dumps(args or {}), MOD, phase)
    return lua_json(d, "Client", code, timeout)


def wait_client(d, timeout=60):
    t0 = time.time()
    while time.time() - t0 < timeout:
        ok, text = d.lua("Client", 'return game:GetService("ReplicatedStorage"):FindFirstChild("ArtC") and "ready" or "no"', 20)
        if ok and "ready" in text:
            return True
        time.sleep(1)
    return False


def session(d, res, tag, style, full):
    d.play(True)
    res[tag + "_clientReady"] = wait_client(d)
    front(drive_b.STUDIO_PID)
    time.sleep(1)
    if full:
        res["cube"] = client(d, "cube")
        res["shot_cube"] = d.shot(os.path.join(OUT, "c-cube.png"), "ScreenCapture_c1")
        res["rigs"] = client(d, "rigs")
        time.sleep(0.5)
        res["shot_rigs"] = d.shot(os.path.join(OUT, "c-rigs.png"), "ScreenCapture_c2")
        res["crestCode"] = client(d, "crestCode")
        res["scale"] = client(d, "scale")
        res["shot_scale"] = d.shot(os.path.join(OUT, "c-scale.png"), "ScreenCapture_c3")
    looks = [("atm032", {"mode": "atm", "density": 0.32})] + ([("atm050", {"mode": "atm", "density": 0.5}), ("fog220", {"mode": "fog", "fogEnd": 220})] if full else [])
    for name, a in looks:
        res["%s_light_%s" % (tag, name)] = client(d, "light", a)
        front(drive_b.STUDIO_PID)
        res["%s_scene_%s" % (tag, name)] = client(d, "scene", {"frames": 300})
        res["%s_shot_%s" % (tag, name)] = d.shot(os.path.join(OUT, "c-%s-%s.png" % (tag, name)), "ScreenCapture_%s%s" % (tag, name))
    res[tag + "_mem"] = drive_b.studio_mem().get(str(drive_b.STUDIO_PID))
    okc, n, bad = d.console(os.path.join(OUT, "c-console-%s.txt" % tag))
    res[tag + "_console"] = {"lines": n, "suspect": [b[:240] for b in bad][:15]}
    d.play(False)
    res[tag + "_edit"] = d.wait_state("edit", 40)[0]


if __name__ == "__main__":
    drive_b.STUDIO_PID = spike_pid()
    res = {}
    with StudioSession() as s:
        d = Drv(s)
        try:
            ids = "{" + ", ".join("%s = %d" % kv for kv in IDS.items()) + "}"
            res["edit"] = lua_json(d, "Edit", EDIT % (ids, "Realistic"), 120)
            save("c-run.json", res)
            before = (res["edit"].get("styleBefore", "Enum.LightingStyle.Realistic").split(".")[-1], str(res["edit"].get("prioBefore", False)).lower())
            session(d, res, "realistic", "Realistic", True)
            save("c-run.json", res)
        finally:
            if "Current Studio Mode: Edit" not in d.state():
                d.play(False)
                d.wait_state("edit", 30)
            res["restore"] = d.lua("Edit", RESTORE % ("Soft", "false"))
            save("c-run.json", res)
            print(json.dumps({k: (v if len(json.dumps(v, default=str)) < 300 else "...") for k, v in res.items()}, default=str)[:3000])
