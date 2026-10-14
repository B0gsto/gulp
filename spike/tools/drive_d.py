#!/usr/bin/env python3
"""Spike part D driver (run under spike/tools/held.sh):  drive_d.py run
Edit: load the RigTest rig, the body and the socket-weight variant (count bones), stage an Edit-made SurfaceAppearance.
Play (one test): the Blender A_Fish_Swim KeyframeSequence on a client-made rig (3-frame bone compare), overlay B
masks at 3 frames, the texture-write probe from real game scripts, S0-A5 visibility presets and the beam/caustic cost.
Nothing is saved. ArtC/DTexEdit are removed from Edit at the end; Lighting changes happen in the play data model only.
Results: spike/out/d/run.json and spike/out/d/*.png."""
import json, os, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from drive import Drv, StudioSession  # noqa: E402
from drive_b import front, spike_pid, lua_json  # noqa: E402
from drive_c import wait_client  # noqa: E402
import drive_b  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "out", "d")
L = lambda n: open(os.path.join(HERE, "luau", n)).read()  # noqa: E731
CLIP, MOD, PARTD, TEX = L("clip.luau"), L("artc.luau"), L("partd.luau"), L("tex_probe.luau")
IDS = {"Rig": 125091724092068, "Body": 135992079926798, "SockW": 97505779898550}
CAUSTICS = json.load(open(os.path.join(OUT, "caustic_ids.json")))

EDIT = r"""
local IS = game:GetService("InsertService") local RS = game:GetService("ReplicatedStorage")
local out = {}
local f = RS:FindFirstChild("ArtC") or Instance.new("Folder") f.Name = "ArtC" f.Parent = RS
for k, id in %s do
  if not f:FindFirstChild(k) then
    local ok, m = pcall(IS.LoadAsset, IS, id)
    if ok then local c = m:GetChildren()[1] c.Name = k c.Parent = f m:Destroy() else out["load" .. k] = tostring(m) end
  end
end
local socks, n = {}, 0
for _, d in f.SockW:GetDescendants() do if d:IsA("Bone") then n += 1 if d.Name:find("^Sock_") then table.insert(socks, d.Name) end end end
out.sockWBones = n out.sockWSockets = socks
local e = f.Body:FindFirstChildWhichIsA("MeshPart", true):Clone() e.Name = "DTexEdit"
local sa = Instance.new("SurfaceAppearance") sa.ColorMapContent = Content.fromUri("rbxassetid://90248245390211") sa.Parent = e
local old = RS:FindFirstChild("DTexEdit") if old then old:Destroy() end
e.Parent = RS
return game:GetService("HttpService"):JSONEncode(out)
"""
RESTORE = r"""
local RS = game:GetService("ReplicatedStorage")
for _, n in { "ArtC", "DTexEdit" } do local x = RS:FindFirstChild(n) if x then x:Destroy() end end
return "restored " .. tostring(RS:FindFirstChild("ArtC") == nil)
"""


def client(d, phase, args=None, timeout=120):
    code = "local buildClip = (function()\n%s\nend)()\nlocal ARGS = game:GetService('HttpService'):JSONDecode([==[%s]==])\n%s\n%s\nreturn D.%s(ARGS)" % (
        CLIP, json.dumps(args or {}), MOD, PARTD, phase)
    return lua_json(d, "Client", code, timeout)


def textures(d):
    src = "[==[" + TEX + "]==]"
    put = ('local s = Instance.new("%s") s.Name = "DTexProbe" s.Source = "local SIDE = \\"%s\\"\\n" .. %s s.Parent = %s return "ok"')
    r = {"mkServer": d.lua("Server", put % ("Script", "server", src, 'game:GetService("ServerScriptService")'))[1][:200],
         "mkClient": d.lua("Client", put % ("LocalScript", "client", src, 'game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")'))[1][:200]}
    time.sleep(6)
    for side, dm in (("server", "Server"), ("client", "Client")):
        r[side] = lua_json(d, dm, 'local v = game:GetService("ReplicatedStorage"):FindFirstChild("DTexResult_%s") return v and v.Value or "{\\"missing\\":1}"' % side)
    r["replicatedToClient"] = d.lua("Client", 'local p = workspace:FindFirstChild("DTex_server") local s = p and p:FindFirstChildOfClass("SurfaceAppearance") return s and s.ColorMapContent.Uri or "none"')[1][:200]
    return r


def ov2(d, res):
    """drive_d.py ov2: the overlay follow-up only (one short play test)."""
    res["edit"] = lua_json(d, "Edit", EDIT % ("{" + ", ".join("%s = %d" % kv for kv in IDS.items()) + "}"), 120)
    d.play(True)
    res["clientReady"] = wait_client(d)
    front(drive_b.STUDIO_PID)
    time.sleep(1)
    res["ov2"] = client(d, "ov2setup", {"f": 7})
    for n in ("M_Species_Base_Fish", "Overlay_T", "Overlay_L", "Overlay_LS", "M_Species_Base_Fish_Shell"):
        client(d, "ov2show", {"show": n})
        res["shot_" + n] = d.shot(os.path.join(OUT, "ov2-%s.png" % n), "ScreenCapture_o2" + n.replace("_", ""))
    ok, n, bad = d.console(os.path.join(OUT, "console-ov2.txt"))
    res["console"] = {"lines": n, "suspect": [b[:240] for b in bad][:15]}


def run(d, res):
    res["edit"] = lua_json(d, "Edit", EDIT % ("{" + ", ".join("%s = %d" % kv for kv in IDS.items()) + "}"), 120)
    print("edit", res["edit"], flush=True)
    d.play(True)
    res["clientReady"] = wait_client(d)
    front(drive_b.STUDIO_PID)
    time.sleep(1)
    res["anim"] = client(d, "anim", {"frames": [3, 7, 12]})
    print("anim", {k: v for k, v in res["anim"].items() if k != "frames"}, flush=True)
    for f in (3, 7, 12):
        for show in ("body", "overlay"):
            client(d, "pose", {"f": f, "show": show})
            res["shot_%d_%s" % (f, show)] = d.shot(os.path.join(OUT, "ov-%02d-%s.png" % (f, show)), "ScreenCapture_d%d%s" % (f, show))
    res["tex"] = textures(d)
    print("tex done", flush=True)
    vis = [("nursery", None, None), ("reef", None, None), ("kelp", None, None), ("dropUpper", None, None), ("dropDeep", None, None),
           ("cove", None, None), ("trench", None, None), ("nursery", None, 0.45), ("nursery", None, 0.6), ("nursery", None, 0.8),
           ("nursery", 220, None), ("nursery", 350, None)]
    res["vis"] = []
    for name, fog, dens in vis:
        front(drive_b.STUDIO_PID)
        v = client(d, "vis", {"preset": name, "fog": fog, "density": dens})
        tag = "%s-%s" % (name, "fog%d" % fog if fog else "d%.2f" % (v.get("density") or 0))
        v["tag"] = tag
        v["shot"] = d.shot(os.path.join(OUT, "vis-%s.png" % tag), "ScreenCapture_v" + tag.replace("-", "").replace(".", ""))
        res["vis"].append(v)
    front(drive_b.STUDIO_PID)
    res["cost"] = client(d, "cost", {"frames": 300, "caustics": ["rbxassetid://%d" % i for i in CAUSTICS]}, 300)
    print("cost", json.dumps(res["cost"])[:600], flush=True)
    res["mem"] = drive_b.studio_mem().get(str(drive_b.STUDIO_PID))
    ok, n, bad = d.console(os.path.join(OUT, "console.txt"))
    res["console"] = {"lines": n, "suspect": [b[:240] for b in bad][:15]}


if __name__ == "__main__":
    drive_b.STUDIO_PID = spike_pid()
    res = {}
    with StudioSession() as s:
        d = Drv(s)
        try:
            (ov2 if sys.argv[1:2] == ["ov2"] else run)(d, res)
        finally:
            if "Current Studio Mode: Edit" not in d.state():
                d.play(False)
                res["backToEdit"] = d.wait_state("edit", 40)[0]
            res["restore"] = d.lua("Edit", RESTORE)
            with open(os.path.join(OUT, "ov2.json" if sys.argv[1:2] == ["ov2"] else "run.json"), "w") as fh:
                json.dump(res, fh, indent=1, default=str)
            print("saved", res.get("restore"), res.get("console"))
