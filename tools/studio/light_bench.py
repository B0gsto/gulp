#!/usr/bin/env python3
"""Reef lighting bench in Studio (task S3-A2; docs/06 sections 10.2 and 10.3, spike S0-A5 F21).

usage: python3 tools/studio/light_bench.py [--tag NAME] [--keep-open]

Under the machine-wide `studio` lock and one `heavy` slot, like tools/studio/prey_bench.py: build build/ci.rbxl,
open it, bring Studio to the front, start play and wait for the local creature (TideController has applied LGT_Reef).
On the client:
  1  read back Lighting (fog, ambient, grade, no Atmosphere) and compare with Data/LightingPresets
  2  fog check (06 10.2: "a white 8-stud ball ... the distance where it disappears"): white 8-stud balls along the
     camera's level look direction at known distances; two captures, balls shown and hidden; per ball the
     luminance contrast |Y_ball - Y_water| / Y_water at its centre. Done at the authored 400 studs and again under
     the Smooth cap (220). Hidden means contrast under 0.01.
  3  look shots: a creature stand-in (8 studs), three prey stand-ins and the 4-stud scale cube at 20, 60, 150 and
     220 studs, from the game camera: level, looking up toward the surface, and the same scene under the Smooth cap
  4  frame time over 5 s with Studio in front, the scene up
Writes build/lighting/: the raw captures (768 px), lighting-grid.png (the look shots in one grid) and result.txt.
The TestBench place is closed without saving; Studio is left stopped in Edit mode.
"""
import base64, io, os, re, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import smoke  # noqa: E402
from smoke import Smoke, open_place, bring_to_front, opt, REPO, TOOLS, ENV  # noqa: E402
import locks  # noqa: E402
import studio_window as sw  # noqa: E402
from studio import StudioSession, studio_lock  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(REPO, "build", "lighting")
HIDDEN = 0.01
CAMERA_STEP = "GulpCamera"  # CameraController RENDER_NAME
TIDE = ('local T = require(game:GetService("Players").LocalPlayer.PlayerScripts:WaitForChild("Client")'
        '.Controllers.TideController) ')

READBACK = r'''
local L = game:GetService("Lighting")
local function c(x) return x:ToHex() end
local atm = L:FindFirstChildOfClass("Atmosphere")
local cc = L:FindFirstChild("GulpColorCorrection")
local bl = L:FindFirstChild("GulpBloom")
local sr = L:FindFirstChild("GulpSunRays")
local okS, style = pcall(function() return tostring(L.LightingStyle) end)
local okP, prio = pcall(function() return tostring(L.PrioritizeLightingQuality) end)
return string.format("fogStart=%.2f fogEnd=%.2f fogColor=%s brightness=%.2f ambient=%s outdoor=%s shiftTop=%s "
  .. "exposure=%.2f clock=%.2f latitude=%.2f atmosphere=%s style=%s prioritize=%s shadows=%s softness=%.2f "
  .. "envDiffuse=%.2f envSpecular=%.2f cc=%s bloom=%s sunRays=%s cameraY=%.1f",
  L.FogStart, L.FogEnd, c(L.FogColor), L.Brightness, c(L.Ambient), c(L.OutdoorAmbient), c(L.ColorShift_Top),
  L.ExposureCompensation, L.ClockTime, L.GeographicLatitude, tostring(atm ~= nil),
  okS and style or "unreadable", okP and prio or "unreadable", tostring(L.GlobalShadows), L.ShadowSoftness,
  L.EnvironmentDiffuseScale, L.EnvironmentSpecularScale,
  cc and string.format("%.2f/%.2f/%.2f/%s", cc.Brightness, cc.Contrast, cc.Saturation, c(cc.TintColor)) or "none",
  bl and string.format("%.2f/%.0f/%.2f", bl.Intensity, bl.Size, bl.Threshold) or "none",
  sr and string.format("%.2f/%.2f/%s", sr.Intensity, sr.Spread, tostring(sr.Enabled)) or "none",
  workspace.CurrentCamera.CFrame.Position.Y)
'''

# One white 8-stud ball, moved from distance to distance along a level line 20 degrees right of the view centre
# (clear of the creature in the middle of the frame). Returns the viewport position of its centre.
BALL = r'''
local d = %d
local cam = workspace.CurrentCamera
local f = workspace:FindFirstChild("LightBench")
if not f then
  f = Instance.new("Folder") f.Name = "LightBench" f.Parent = workspace
  local p = cam.CFrame.Position
  local look = cam.CFrame.LookVector
  cam.CameraType = Enum.CameraType.Scriptable
  cam.CFrame = CFrame.lookAt(p, p + Vector3.new(look.X, 0, look.Z).Unit)
end
local b = f:FindFirstChild("Ball")
if not b then
  b = Instance.new("Part") b.Name = "Ball"
  b.Shape = Enum.PartType.Ball b.Size = Vector3.new(8, 8, 8) b.Color = Color3.new(1, 1, 1)
  b.Material = Enum.Material.SmoothPlastic b.Anchored = true b.CanCollide = false b.CanQuery = false
  b.CastShadow = false b.Parent = f
end
local cf = cam.CFrame
local dir = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(-20)):VectorToWorldSpace(cf.LookVector)
b.Position = cf.Position + dir * d
b.Transparency = if d > 0 then 0 else 1
local v = cam:WorldToViewportPoint(b.Position)
local vs = cam.ViewportSize
return string.format("vp=%%.0fx%%.0f at=%%.1f,%%.1f", vs.X, vs.Y, v.X, v.Y)
'''

SHOW = 'for _, b in workspace.LightBench:GetChildren() do b.Transparency = %d end return "ok"'

# Look scene: at each distance a creature stand-in, three prey stand-ins and the scale cube, slightly below the
# camera so the floor-ward view shows them against the water.
SCENE = r'''
local cam = workspace.CurrentCamera
local old = workspace:FindFirstChild("LightBench") if old then old:Destroy() end
local f = Instance.new("Folder") f.Name = "LightBench" f.Parent = workspace
local p = cam.CFrame.Position
local look = cam.CFrame.LookVector
local flat = Vector3.new(look.X, 0, look.Z).Unit
local right = flat:Cross(Vector3.yAxis)
local function part(shape, size, colour, pos, mat)
  local x = Instance.new("Part") x.Shape = shape x.Size = size x.Color = Color3.fromHex(colour)
  x.Material = mat or Enum.Material.SmoothPlastic x.Anchored = true x.CanCollide = false x.CanQuery = false
  x.CastShadow = false x.CFrame = CFrame.lookAt(pos, pos + flat) x.Parent = f
  return x
end
for i, d in {20, 60, 150, 220} do
  local side = if i % 2 == 0 then -1 else 1
  local base = p + flat * d + right * side * (4 + d * 0.12) - Vector3.new(0, 3, 0)
  part(Enum.PartType.Cylinder, Vector3.new(8, 3.5, 3.5), "#5CD6C8", base) -- creature stand-in, 8 long
  for k = 1, 3 do
    part(Enum.PartType.Ball, Vector3.new(1.6, 1.0, 1.0), "#FFA35C", base + right * (-side) * (6 + k * 1.6) + Vector3.new(0, k * 0.8, 0))
  end
  local cube = part(Enum.PartType.Block, Vector3.new(4, 4, 4), "#C9C9C9", base + right * side * 7)
  cube.Name = "ScaleCube" .. d
end
cam.CameraType = Enum.CameraType.Scriptable
cam.CFrame = CFrame.lookAt(p, p + flat - Vector3.new(0, 0.08, 0))
return string.format("scene at camera y=%.1f", p.Y)
'''

LOOK_UP = ('local cam = workspace.CurrentCamera local p = cam.CFrame.Position local l = cam.CFrame.LookVector '
           'cam.CFrame = CFrame.lookAt(p, p + Vector3.new(l.X, 0, l.Z).Unit + Vector3.new(0, 0.9, 0)) return "up"')
LEVEL = ('local cam = workspace.CurrentCamera local p = cam.CFrame.Position local l = cam.CFrame.LookVector '
         'cam.CFrame = CFrame.lookAt(p, p + Vector3.new(l.X, 0, l.Z).Unit - Vector3.new(0, 0.08, 0)) return "level"')

FRAMES_START = r'''
workspace:SetAttribute("LightBenchFrames", nil)
task.spawn(function()
  local RS = game:GetService("RunService")
  local t = {}
  local t0 = os.clock()
  while os.clock() - t0 < 5 do table.insert(t, RS.RenderStepped:Wait() * 1000) end
  table.sort(t)
  local s = 0 for _, x in t do s += x end
  local function pc(q) return t[math.clamp(math.ceil(#t * q), 1, #t)] end
  workspace:SetAttribute("LightBenchFrames", string.format("frames=%d fps=%.1f frameMs mean=%.2f p50=%.2f p99=%.2f max=%.2f",
    #t, #t / 5, s / #t, pc(0.5), pc(0.99), t[#t]))
end)
return "started"
'''


def capture(sm, name):
    ok, texts, images = sm.call("screen_capture", {"capture_id": "light"}, 60)
    if not images:
        raise RuntimeError("screen_capture returned no image: %s" % "\n".join(texts)[:200])
    img = Image.open(io.BytesIO(base64.b64decode(images[0]))).convert("RGB")
    small = img.copy()
    small.thumbnail((768, 768))
    small.save(os.path.join(OUT, name + ".png"))
    return img


def lum(px):
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = px
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)


def sample(img, x, y):
    vals = sorted(lum(img.getpixel((min(max(int(x) + dx, 0), img.width - 1), min(max(int(y) + dy, 0), img.height - 1))))
                  for dx in (-1, 0, 1) for dy in (-1, 0, 1))
    return vals[4]


def fog_check(sm, label, dists, cap):
    if cap:
        sm.lua("Client", TIDE + 'T.apply("LGT_Reef", %d) return "ok"' % cap)
    else:
        sm.lua("Client", TIDE + 'T.apply("LGT_Reef") return "ok"')
    old = 'local f = workspace:FindFirstChild("LightBench") if f then f:Destroy() end return "ok"'
    sm.lua("Client", old)
    # Legacy fog colours geometry, not the sky, so the reference is the ball at 600 studs (past every FogEnd, inside the drawn range), not
    # the empty view; the empty view (the sky behind) is captured too, for the backdrop contrast.
    sm.lua("Client", BALL % 0)
    time.sleep(0.8)
    sky = capture(sm, "fog-%s-sky" % label)
    _, text = sm.lua("Client", BALL % 600)
    time.sleep(0.8)
    water = capture(sm, "fog-%s-far" % label)
    m = re.search(r"vp=(\d+)x(\d+) at=([\d.-]+),([\d.-]+)", text)
    rx, ry = float(m.group(3)) * water.width / int(m.group(1)), float(m.group(4)) * water.height / int(m.group(2))
    yf, ys = sample(water, rx, ry), sample(sky, rx, ry)
    sm.add("INFO", "backdrop %s" % label, "fully fogged ball vs the sky behind it: contrast %.3f (Y %.3f vs %.3f)"
           % (abs(yf - ys) / max(ys, 1e-4), yf, ys))
    _, fog = sm.lua("Client", 'local L = game:GetService("Lighting") return string.format("%.1f %.1f", L.FogStart, L.FogEnd)')
    fs, fe = (float(v) for v in fog.split())
    parts, first_hidden = [], None
    for d in dists:
        _, text = sm.lua("Client", BALL % d)
        m = re.search(r"vp=(\d+)x(\d+) at=([\d.-]+),([\d.-]+)", text)
        vw, vh, x, y = int(m.group(1)), int(m.group(2)), float(m.group(3)), float(m.group(4))
        time.sleep(0.6)
        shown = capture(sm, "fog-%s-%d" % (label, d))
        sx, sy = shown.width / vw, shown.height / vh
        a, b = sample(shown, x * sx, y * sy), sample(water, x * sx, y * sy)
        contrast = abs(a - b) / max(b, 1e-4)
        linear = min(max((d - fs) / (fe - fs), 0), 1)
        parts.append("%d:%.3f(fog %.2f)" % (d, contrast, linear))
        if contrast < HIDDEN and first_hidden is None:
            first_hidden = d
    sm.lua("Client", old)
    sm.add("INFO", "fog %s" % label, "against a fully fogged ball: FogStart %.0f FogEnd %.0f; ball contrast %s; first hidden at %s studs"
           % (fs, fe, " ".join(parts), first_hidden))
    return first_hidden, fe


def run(sm):
    mode, _ = sm.mode()
    if mode.lower() != "edit":
        sm.call("start_stop_play", {"is_start": False}, 120)
        sm.wait_mode("edit", 60)
    _, edit = sm.lua("Edit", 'local L = game:GetService("Lighting") return tostring(L.LightingStyle) .. " " '
                     '.. tostring(L.PrioritizeLightingQuality)')
    sm.add("INFO", "edit place", "LightingStyle, PrioritizeLightingQuality in Edit: " + edit.strip())
    sm.call("start_stop_play", {"is_start": True}, 120)
    in_play, _ = sm.wait_mode("play", 60)
    ready, text = sm.poll_lua("Client", 'local p = game:GetService("Players").LocalPlayer '
                              'local c = p and p.Character return if c and c.PrimaryPart then "ready" else "wait"',
                              lambda x: "ready" in x, 60)
    sm.add("PASS" if in_play and ready else "FAIL", "play", "client has its creature" if ready else text[:200])
    if not ready:
        return
    time.sleep(2.0)
    # Hold the camera still: the follow camera writes CFrame every frame (CameraController, BindToRenderStep).
    sm.lua("Client", 'game:GetService("RunService"):UnbindFromRenderStep("%s") return "ok"' % CAMERA_STEP)
    _, text = sm.lua("Client", READBACK)
    want = {"fogStart": "100.00", "fogEnd": "400.00", "fogColor": "1e9fd0", "brightness": "2.00",
            "ambient": "6fb6d9", "outdoor": "9ed8f0", "shiftTop": "fff0b8", "exposure": "0.00", "clock": "13.00",
            "latitude": "15.00", "atmosphere": "false", "cc": "0.02/0.08/0.12/ffffff", "bloom": "0.60/24/0.95"}
    got = dict(re.findall(r"(\w+)=(\S+)", text))
    bad = [k for k, v in want.items() if got.get(k, "").lower() != v]
    sm.add("PASS" if not bad else "FAIL", "readback", text.strip() + ("" if not bad else "  MISMATCH: " + ", ".join(bad)))

    _, srv = sm.lua("Server", 'local L = game:GetService("Lighting") return tostring(L.LightingStyle) .. " " '
                    '.. tostring(L.PrioritizeLightingQuality)')
    sm.add("INFO", "server", "LightingStyle, PrioritizeLightingQuality on the play server: " + srv.strip())
    hid, fe = fog_check(sm, "authored", [20, 60, 150, 220, 300, 340, 370, 390, 400, 450], None)
    sm.add("PASS" if hid is not None and hid <= fe else "FAIL", "fog authored",
           "ball hidden by %s studs (target %.0f)" % (hid, fe))
    hid, fe = fog_check(sm, "smooth", [20, 60, 150, 180, 200, 210, 220, 260], 220)
    sm.add("PASS" if hid is not None and hid <= fe else "FAIL", "fog smooth cap",
           "ball hidden by %s studs (cap %.0f)" % (hid, fe))

    sm.lua("Client", TIDE + 'T.apply("LGT_Reef") return "ok"')
    _, text = sm.lua("Client", SCENE)
    time.sleep(1.0)
    shots = [("Reef level, authored 400", capture(sm, "look-level"))]
    sm.lua("Client", FRAMES_START)
    time.sleep(6.0)
    _, frames = sm.poll_lua("Client", 'return workspace:GetAttribute("LightBenchFrames") or "wait"',
                            lambda x: x.startswith("frames"), 20)
    sm.add("INFO", "frame time", frames.strip() + " (Studio in front, scene up)")
    sm.lua("Client", LOOK_UP)
    time.sleep(1.0)
    shots.append(("Reef looking up", capture(sm, "look-up")))
    sm.lua("Client", LEVEL)
    sm.lua("Client", TIDE + 'T.apply("LGT_Reef", 220) return "ok"')
    time.sleep(1.0)
    shots.append(("Reef level, Smooth cap 220", capture(sm, "look-smooth")))
    sm.lua("Client", TIDE + 'T.apply("LGT_Reef") return "ok"')

    tiles = []
    for _, img in shots:
        t = img.copy()
        t.thumbnail((768, 768))
        tiles.append(t)
    w, h = max(t.width for t in tiles), max(t.height for t in tiles)
    grid = Image.new("RGB", (w * len(tiles), h), (20, 20, 20))
    for i, t in enumerate(tiles):
        grid.paste(t, (i * w, 0))
    path = os.path.join(OUT, "lighting-grid.png")
    grid.save(path)
    sm.add("INFO", "grid", "%s: %s" % (os.path.relpath(path, REPO), " | ".join(n for n, _ in shots)))


def main():
    args = sys.argv[1:]
    tag = opt(args, "--tag", "gulp-light")
    os.makedirs(OUT, exist_ok=True)
    started = time.time()
    rows = []
    with studio_lock(owner="gulp light bench", timeout=1800):
        with locks.Lock("heavy", owner="gulp light bench", timeout=1800):
            b = subprocess.run(["rojo", "build", "ci.project.json", "-o", "build/ci.rbxl"], cwd=REPO, env=ENV,
                               capture_output=True, text=True)
            if b.returncode != 0:
                print("light bench: FAIL\nFAIL build: " + (b.stderr or b.stdout)[-400:])
                sys.exit(1)
            title, sid = open_place(tag)
            previous = sw.frontmost()
            try:
                with StudioSession() as s:
                    sm = Smoke(s, sid)
                    pid = sw.pid_of(title)
                    if pid:
                        bring_to_front(pid)
                    try:
                        run(sm)
                    finally:
                        sm.call("start_stop_play", {"is_start": False}, 120)
                        edit, _ = sm.wait_mode("edit", 60)
                        sm.add("PASS" if edit else "FAIL", "stop", "Edit mode %s" % edit)
                    rows = sm.rows
            finally:
                if "--keep-open" not in args:
                    subprocess.run([sys.executable, os.path.join(TOOLS, "studio-open.py"), "--close", tag,
                                    "--owner", smoke.OWNER], capture_output=True, text=True, timeout=180)
                sw.restore(previous)
    failed = sum(1 for r in rows if r[0] == "FAIL")
    lines = ["light bench: %s (%.0f s)" % ("FAIL" if failed or not rows else "PASS", time.time() - started)]
    lines += ["%s %s: %s" % r for r in rows]
    with open(os.path.join(OUT, "result.txt"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    sys.exit(1 if failed or not rows else 0)


if __name__ == "__main__":
    main()
