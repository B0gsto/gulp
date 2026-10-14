#!/usr/bin/env python3
"""The client-side play check of the first-time script (task S6-C2; docs/04 sections 3.6 B1 to B5 and 12).

usage: python3 tools/studio/ftue_play.py [--tag NAME] [--seconds N] [--grid PATH]

Under the machine-wide `studio` lock and one `heavy` slot, like tools/studio/hud_shots.py: build build/ci.rbxl, open
it and start play solo. If the profile has already started or finished the script, `/ftue reset` runs through the
server's DevCommand. The client's TutorialDirector probe (`TutorialProbe`, Studio only) runs its autopilot, which
steers at the beat's food as a player would, from `PILOT_AT` seconds after control (before that there is no input, so
the ghost thumb of B2 shows). The director's beat log (J since it started, T since control) is polled until GLOW
(stage 5) or `--seconds` (default 75). Captures, downscaled to 768 px, go to build/ftue/: the hatch, the first bite
(Swarm A and the ghost thumb, before any input), the tier-up banner at full opacity, mid-B5 (Glowfry on screen, a pip
filled) and GLOW after the trait's 0.5 s activation (02 §8.2); `--grid PATH` writes the 2 x 2 contact sheet of the
hatch, the first bite, mid-B5 and GLOW, 1536 px wide. Before each capture the client's state is logged to
build/ftue/state.json: the `Traits` attribute, the trait slots and pips, the Glow light and tint, the Glowfry and krill
on screen with their outline scale, ring, light and screen Y range, the banner's size and opacity, the ghost thumb,
the egg's framing, the camera's pitch, the scene light (B5's dip) and what the HUD shows at the bottom right. Prints the beat timings and the Sprint 6 demo verdict: the first bite by
T = 5, tier 2 by about T = 25 (30 allowed), five Glowfry and GLOW.
The place is closed without saving; Studio is left stopped in Edit mode.
"""
import base64, io, json, os, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import smoke  # noqa: E402
from smoke import Smoke, open_place, bring_to_front, opt, REPO, TOOLS, ENV, error_lines  # noqa: E402
import locks  # noqa: E402
import studio_window as sw  # noqa: E402
from studio import StudioSession, studio_lock  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(REPO, "build", "ftue")
PROBE = ('local P = game:GetService("Players").LocalPlayer.PlayerScripts:WaitForChild("Client")'
         ':WaitForChild("TutorialProbe", 20) ')
STATE = ('return game:GetService("Players").LocalPlayer.PlayerScripts.Client'
         '.StateStoreGet:Invoke("ftue")')
PILOT_AT = 2.0  # s after control: the autopilot's first input (B2's ghost thumb shows until then)
# name: (the beat-log mark it waits for, seconds after it, an extra test on the state log or None)
SHOTS = [("hatch", lambda w: w.startswith("hatch"), 0.5, None),
         ("first-bite", lambda w: w.startswith("control"), 1.2, None),
         ("tier-up", lambda w: w == "banner tierUp", 0.45, None),
         ("mid-b5", lambda w: w == "shown traitSlot", 0.6,
          lambda st: st.get("glowfry", {}).get("onScreen", 0) >= 2 and lit_pips(st) >= 1),
         # 02 §8.2: the light comes on 0.5 s after the trait; the GLOW card holds 1.5 s
         ("glow", lambda w: w == "trait glow", 0.55, lambda st: bool(st.get("glowLight")))]
GRID = ["hatch", "first-bite", "mid-b5", "glow"]
TRACE_EVERY = 3.0  # s: the trace of the Fry and the food nearest it (state.json "trace")
TRACE = r"""
local P = game:GetService("Players").LocalPlayer.PlayerScripts.Client:FindFirstChild("TutorialProbe")
local rig = P and P:Invoke("rig")
if not rig then return "{}" end
local p = rig:GetPivot().Position
local out = { pos = { math.floor(p.X), math.floor(p.Y), math.floor(p.Z) }, mass = rig:GetAttribute("Mass"),
	tier = rig:GetAttribute("Tier"), phase = rig:GetAttribute("Phase") }
local prey = workspace:FindFirstChild("PreyRender")
local near = {}
if prey then
	for _, d in prey:GetChildren() do
		if d:IsA("BasePart") and d.Transparency < 1 and not string.find(d.Name, "_Shell$") then
			local v = d.Position - p
			local n = near[d.Name]
			if n == nil or v.Magnitude < n[1] then near[d.Name] = { math.floor(v.Magnitude * 10) / 10, math.floor(v.Y) } end
		end
	end
end
out.nearest = near
return game:GetService("HttpService"):JSONEncode(out)
"""
MID_B5_LATEST = 6.0  # s after the trait slot shows: capture mid-B5 with any Glowfry on screen

# The client's state at a capture (see the docstring), as JSON.
STATE_LOG = r"""
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")
local OutlineRules = require(RS.Shared.Logic.OutlineRules)
local lp = Players.LocalPlayer
local P = lp.PlayerScripts:WaitForChild("Client"):WaitForChild("TutorialProbe", 5)
local cam = workspace.CurrentCamera
local vp = cam.ViewportSize
local out = { viewport = { vp.X, vp.Y } }
local function r2(x) return math.floor(x * 100 + 0.5) / 100 end
local function proj(p)
	local v = cam:WorldToViewportPoint(p)
	return r2(v.X / vp.X), r2(v.Y / vp.Y), v.Z > 0
end
local function shown(g)
	local x = g
	while x and not x:IsA("LayerCollector") do
		if x:IsA("GuiObject") and not x.Visible then return false end
		x = x.Parent
	end
	return x == nil or x.Enabled
end
local rig = P and P:Invoke("rig")
if rig then
	out.traitsAttr = rig:GetAttribute("Traits")
	local light = rig:FindFirstChild("GlowLight", true)
	out.glowLight = if light then { light.Enabled, light.Brightness, light.Range } else false
	local tints, lit = 0, 0
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, "_GlowTint$") then
			tints += 1
			if d.Transparency < 1 then lit += 1 end
		end
	end
	out.glowTints = { tints, lit }
	local x, y, front = proj(rig:GetPivot().Position)
	out.rigScreen = { x, y, front }
end
out.playerTraits = lp:GetAttribute("Traits")
out.ambient = { Lighting.Ambient:ToHex(), Lighting.OutdoorAmbient:ToHex(), Lighting.FogColor:ToHex(),
	r2(Lighting.Brightness) }
out.camPitch = r2(math.deg(math.asin(cam.CFrame.LookVector.Y)))
local gui = lp:WaitForChild("PlayerGui")
local traits = gui:FindFirstChild("HUD.Traits", true)
if traits then
	local slots = {}
	for i = 1, 3 do
		local s = traits:FindFirstChild("Slot" .. i, true)
		if s then
			local pips, lit = 0, 0
			for _, d in s:GetDescendants() do
				if d:IsA("GuiObject") and string.find(d.Name, "^Pip%d") and d.Visible then
					pips += 1
					if d.BackgroundTransparency < 0.1 then lit += 1 end
				end
			end
			local icon = s:FindFirstChild("Trait", true)
			local empty = s:FindFirstChild("Empty", true)
			table.insert(slots, { shown = shown(s), pips = pips, lit = lit,
				icon = icon ~= nil and shown(icon), empty = empty ~= nil and shown(empty) })
		end
	end
	out.traitSlots = slots
end
local ghost = gui:FindFirstChild("Guide.Ghost", true)
out.ghost = ghost ~= nil and shown(ghost)
for _, name in { "S07.TierUp", "S08.TraitGained" } do
	local card = gui:FindFirstChild(name, true)
	if card then
		local title = card:FindFirstChild("TierName", true) or card:FindFirstChild("TraitName", true)
		out[name] = { size = { card.AbsoluteSize.X, card.AbsoluteSize.Y },
			title = if title then { title.Text, title.TextSize, r2(title.TextTransparency), title.AbsoluteSize.Y } else nil }
	end
end
local corner = {}
for _, d in gui:GetDescendants() do
	if d:IsA("GuiObject") and d.AbsoluteSize.X > 16 and d.AbsoluteSize.X < vp.X / 3 and shown(d) then
		local c = d.AbsolutePosition + d.AbsoluteSize / 2
		if c.X > vp.X * 0.75 and c.Y > vp.Y * 0.7 and #corner < 10 then
			local top = d
			while top.Parent and top.Parent:IsA("GuiObject") and top.Parent.AbsoluteSize.X < vp.X / 3 do top = top.Parent end
			if not table.find(corner, top:GetFullName()) then table.insert(corner, top:GetFullName()) end
		end
	end
end
out.bottomRight = corner
local prey = workspace:FindFirstChild("PreyRender")
local kinds = {}
if prey then
	local shells = {}
	for _, d in prey:GetChildren() do
		if d:IsA("BasePart") and string.find(d.Name, "_Shell$") and d.Transparency < 1 then
			shells[d.Name] = d.Size
		end
	end
	local rp = rig and rig:GetPivot().Position
	for _, d in prey:GetChildren() do
		if d:IsA("BasePart") and d.Transparency < 1 and not string.find(d.Name, "_Shell$") and d.Name ~= "GlintHost" then
			local k = kinds[d.Name] or { n = 0, onScreen = 0, pos = {}, extras = {}, screenY = { 1e9, -1e9 } }
			kinds[d.Name] = k
			k.n += 1
			local x, y, front = proj(d.Position)
			if front and x > 0 and x < 1 and y > 0 and y < 1 then
				k.onScreen += 1
				k.screenY = { math.min(k.screenY[1], y), math.max(k.screenY[2], y) }
			end
			if rp then table.insert(k.pos, d.Position - rp) end
			for _, c in d:GetDescendants() do
				if not c:IsA("SpecialMesh") and not table.find(k.extras, c.ClassName .. ":" .. c.Name) then
					table.insert(k.extras, c.ClassName .. ":" .. c.Name)
				end
			end
			local sh = shells[d.Name .. "_Shell"]
			if sh and k.outline == nil then
				local base = OutlineRules.thickness(d.Size.Y, "edible", true)
				k.outline = r2((sh.Y - d.Size.Y) / 2 / base)
			end
		end
	end
	for name, k in kinds do
		if #k.pos > 0 then
			local c = Vector3.zero
			for _, v in k.pos do c += v end
			c /= #k.pos
			local spread = 0
			for _, v in k.pos do spread = math.max(spread, (v - c).Magnitude) end
			k.centre = r2(c.Magnitude)
			k.spread = r2(spread)
			local near = math.huge
			for _, v in k.pos do near = math.min(near, v.Magnitude) end
			k.nearest = r2(near)
		end
		k.pos = nil
	end
end
out.prey = kinds
out.glowfry = kinds.glowfry or kinds.Glowfry or kinds.M_Prey_Glowfry or { onScreen = 0 }
local egg = P and P:Invoke("egg")
if egg then
	local x0, x1, y0, y1 = 1e9, -1e9, 1e9, -1e9
	for _, p in egg:GetChildren() do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local s = p.Size / 2
			for _, c in { Vector3.new(1,1,1), Vector3.new(1,1,-1), Vector3.new(1,-1,1), Vector3.new(1,-1,-1),
				Vector3.new(-1,1,1), Vector3.new(-1,1,-1), Vector3.new(-1,-1,1), Vector3.new(-1,-1,-1) } do
				local x, y = proj(p.CFrame:PointToWorldSpace(s * c))
				x0, x1, y0, y1 = math.min(x0, x), math.max(x1, x), math.min(y0, y), math.max(y1, y)
			end
		end
	end
	if x0 < 1e9 then out.egg = { x0, x1, y0, y1 } end
end
return HttpService:JSONEncode(out)
"""


def capture(sm, name):
    ok, texts, images = sm.call("screen_capture", {"capture_id": "ftue"}, 60)
    if not images:
        return None
    img = Image.open(io.BytesIO(base64.b64decode(images[0]))).convert("RGB")
    img.thumbnail((768, 768))
    path = os.path.join(OUT, name + ".png")
    img.save(path)
    return path


def marks(sm):
    ok, text = sm.lua("Client", PROBE + 'return P:Invoke("log")')
    try:
        return json.loads(text.strip().splitlines()[-1])
    except (ValueError, IndexError):
        return {"stage": -1, "marks": []}


def lit_pips(st):
    slots = st.get("traitSlots") or []
    return slots[0]["lit"] if slots else 0


def client_state(sm):
    ok, text = sm.lua("Client", STATE_LOG)
    try:
        return json.loads(text.strip().splitlines()[-1])
    except (ValueError, IndexError):
        return {"error": text[-300:]}


def first(log, what):
    for m in log["marks"]:
        if m["what"] == what:
            return m.get("t")
    return None


def run(sm, seconds):
    sm.call("start_stop_play", {"is_start": True}, 120)
    in_play, _ = sm.wait_mode("play", 60)
    ready, text = sm.poll_lua("Client", PROBE + 'return if P then "ready" else "wait"', lambda x: "ready" in x, 60, 0.2)
    sm.add("PASS" if in_play and ready else "FAIL", "play", "probe up" if ready else text[:200])
    if not ready:
        return [], None
    _, out = sm.lua("Client", PROBE + 'return P:Invoke("pilot", "off")')
    sm.add("INFO", "pilot", out.strip() + " until T = %.1f" % PILOT_AT)
    # A profile that already ran the script: reset it (04 §9, /ftue reset).
    time.sleep(1.0)
    _, state = sm.poll_lua("Client", STATE, lambda x: "stage" in x, 30, 0.5)
    try:
        ftue = json.loads(state.strip().splitlines()[-1])
    except (ValueError, IndexError):
        ftue = {}
    if ftue.get("completed") or (ftue.get("stage") or 0) >= 2:
        _, r = sm.lua("Server", 'local p = game:GetService("Players"):GetPlayers()[1] '
                      'return game.ServerScriptService.Server.DevCommand:Invoke(p.UserId, "/ftue reset")')
        sm.add("INFO", "reset", "profile was %s; /ftue reset: %s" % (json.dumps(ftue), r.strip()[:120]))
    shots, taken, states, seen = [], set(), {}, {}
    end = time.time() + seconds
    log, control, pilot = None, None, False
    hatch_frames, trace, traced = [], [], 0.0
    while time.time() < end:
        log = marks(sm)
        now = time.time()
        for name, test, _, _ in SHOTS:
            if name not in seen and any(test(m["what"]) for m in log["marks"]):
                seen[name] = now
        if control is None and any(m["what"].startswith("control") for m in log["marks"]):
            control = now
        if control and not pilot and now >= control + PILOT_AT:
            _, out = sm.lua("Client", PROBE + 'return P:Invoke("pilot", "on")')
            pilot = True
            sm.add("INFO", "pilot", out.strip())
        if "hatch" in seen and control is None:
            st = client_state(sm)  # the egg's framing through the hatch
            if st.get("egg"):
                hatch_frames.append(st["egg"])
        if control and now >= traced + TRACE_EVERY:
            traced = now
            _, text = sm.lua("Client", TRACE)
            try:
                row = json.loads(text.strip().splitlines()[-1])
                row["t"] = round(now - control, 1)
                trace.append(row)
            except (ValueError, IndexError):
                pass
        for name, _, after, test in SHOTS:
            if name in taken or name not in seen or time.time() < seen[name] + after:
                continue
            st = client_state(sm)
            late = name == "mid-b5" and time.time() > seen[name] + MID_B5_LATEST
            if test and not test(st) and not (late and st.get("glowfry", {}).get("onScreen", 0) >= 1):
                continue
            taken.add(name)
            path = capture(sm, name)
            states[name] = st
            if path:
                shots.append((name, path))
        if "glow" in taken or log["stage"] >= 5 and len(taken) == len(SHOTS):
            break
        time.sleep(0.1)
    time.sleep(1.0)
    log = marks(sm)
    states["hatchEggFrames"] = hatch_frames
    states["trace"] = trace
    with open(os.path.join(OUT, "state.json"), "w") as f:
        json.dump(states, f, indent=1)
    return shots, log


def contact_sheet(paths, out, width=1536):
    """The 2 x 2 sheet of GRID (a grey cell for a missing capture), `width` px wide."""
    cell = width // 2
    imgs = [Image.open(paths[n]).convert("RGB") if n in paths else None for n in GRID]
    ratio = max((i.height / i.width for i in imgs if i), default=0.5625)
    ch = int(cell * ratio)
    sheet = Image.new("RGB", (width, 2 * ch), (40, 40, 40))
    for k, img in enumerate(imgs):
        if img:
            sheet.paste(img.resize((cell, int(cell * img.height / img.width))), ((k % 2) * cell, (k // 2) * ch))
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    sheet.save(out)
    return out


def main():
    args = sys.argv[1:]
    tag = opt(args, "--tag", "gulp-ftue")
    seconds = float(opt(args, "--seconds", "75"))
    grid = opt(args, "--grid", None)
    os.makedirs(OUT, exist_ok=True)
    rows, shots, log = [], [], None
    with studio_lock(owner="gulp ftue play", timeout=2400):
        with locks.Lock("heavy", owner="gulp ftue play", timeout=2400):
            b = subprocess.run(["rojo", "build", "ci.project.json", "-o", "build/ci.rbxl"], cwd=REPO, env=ENV,
                               capture_output=True, text=True)
            if b.returncode != 0:
                print("ftue play: FAIL build: " + (b.stderr or b.stdout)[-400:])
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
                        shots, log = run(sm, seconds)
                        _, out = sm.call("get_console_output", {}, 30)[:2]
                        console = "\n".join(out)
                        with open(os.path.join(OUT, "console.txt"), "w") as f:
                            f.write(console)
                        errs = error_lines(console)
                        sm.add("FAIL" if errs else "PASS", "console", "; ".join(errs)[:500] or "no errors")
                    finally:
                        sm.call("start_stop_play", {"is_start": False}, 120)
                        edit, _ = sm.wait_mode("edit", 60)
                        sm.add("PASS" if edit else "FAIL", "stop", "Edit mode %s" % edit)
                    rows = sm.rows
            finally:
                subprocess.run([sys.executable, os.path.join(TOOLS, "studio-open.py"), "--close", tag,
                                "--owner", smoke.OWNER], capture_output=True, text=True, timeout=180)
                sw.restore(previous)
    lines = ["%s %s: %s" % r for r in rows]
    if log:
        with open(os.path.join(OUT, "beats.json"), "w") as f:
            json.dump(log, f, indent=1)
        for m in log["marks"]:
            t = m.get("t")
            lines.append("  J %6.2f  T %s  %s" % (m["j"], "%6.2f" % t if t is not None else "     -", m["what"]))
        bite, tier2, glow = first(log, "stage 3"), first(log, "stage 4"), first(log, "trait glow")
        demo = bite is not None and bite <= 5 and tier2 is not None and tier2 <= 30 and glow is not None
        lines.append("beats: first bite T %s, tier 2 T %s, Glow T %s; demo %s" % (bite, tier2, glow,
                                                                                    "PASS" if demo else "FAIL"))
        rows.append(("PASS" if demo else "FAIL", "demo", ""))
    for name, path in shots:
        lines.append("capture %s: %s" % (name, path))
    if grid and shots:
        lines.append("grid: %s" % contact_sheet(dict(shots), grid))
    print("\n".join(lines))
    sys.exit(1 if any(r[0] == "FAIL" for r in rows) else 0)


if __name__ == "__main__":
    main()
