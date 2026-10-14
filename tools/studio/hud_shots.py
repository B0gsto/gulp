#!/usr/bin/env python3
"""HUD stage 1 screenshots in Studio (task S4-C5; docs/08 sections 1, 3, 4.4, 4.5 and 15).

usage: python3 tools/studio/hud_shots.py [--tag NAME] [--set hud|cove|moments]

Under the machine-wide `studio` lock and one `heavy` slot, like tools/studio/light_bench.py: build build/ci.rbxl,
open it, start play and wait for the local creature. On the client, Dev/HudHarness lays the interface out for a
simulated phone (844 x 390 px, 47 px notch insets, drawn at the top left of the viewport and cropped) and for the
real Studio viewport (a desktop), poses the HUD (drag ring, dash cooldown, mass pops, off-screen home) and opens
S11 and S12. Writes build/hud/: each capture downscaled to 768 px (a cropped one also at full resolution, NAME-raw.png) and
hud-grid.png (one contact sheet).
`--set cove` (task S5-C4) shoots S12 after a bank (specimen card; a tier 1 run on the phone) and S14 (Pearls,
income, slots, Claim all, the Pearl pile) on both devices into build/hud/cove-grid.png.
`--set moments` (task S6-C5) shoots S07 and S08 held in the moment slot (tier 2 and 7, Glow and the Epic Crystal on
the phone; also tier 3 and every [MVP] trait on the desktop), cropped around the slot, into build/hud/moments-grid.png
(at most 1536 wide) and moments-grid-768.png.
The place is closed without saving; Studio is left stopped in Edit mode.
"""
import base64, io, os, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import smoke  # noqa: E402
from smoke import Smoke, open_place, bring_to_front, opt, REPO, TOOLS, ENV  # noqa: E402
import locks  # noqa: E402
import studio_window as sw  # noqa: E402
from studio import StudioSession, studio_lock  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

OUT = os.path.join(REPO, "build", "hud")
H = ('local H = game:GetService("Players").LocalPlayer.PlayerScripts:WaitForChild("Client")'
     ':WaitForChild("HudHarness") ')
PHONE = (844, 390)


def capture(sm, name, crop=None, box=None):
    """`crop`: (w, h) viewport px from the top left; `box`: (x0, y0, x1, y1) viewport px."""
    ok, texts, images = sm.call("screen_capture", {"capture_id": "hud"}, 60)
    if not images:
        raise RuntimeError("screen_capture returned no image: %s" % "\n".join(texts)[:200])
    img = Image.open(io.BytesIO(base64.b64decode(images[0]))).convert("RGB")
    if crop or box:
        _, vp = sm.lua("Client", 'local v = workspace.CurrentCamera.ViewportSize return v.X .. " " .. v.Y')
        vw = float(vp.split()[0])
        k = img.width / vw
        if box:
            img = img.crop(tuple(max(0, int(v * k)) for v in box))
        else:
            img = img.crop((0, 0, int(crop[0] * k), int(crop[1] * k)))
        img.save(os.path.join(OUT, name + "-raw.png"))  # full resolution, for detail crops
    img.thumbnail((768, 768))
    path = os.path.join(OUT, name + ".png")
    img.save(path)
    return path


def run(sm):
    mode, _ = sm.mode()
    if mode.lower() != "edit":
        sm.call("start_stop_play", {"is_start": False}, 120)
        sm.wait_mode("edit", 60)
    sm.call("start_stop_play", {"is_start": True}, 120)
    in_play, _ = sm.wait_mode("play", 60)
    ready, text = sm.poll_lua("Client", 'local p = game:GetService("Players").LocalPlayer '
                              'local c = p and p.Character return if c and c.PrimaryPart then "ready" else "wait"',
                              lambda x: "ready" in x, 60)
    sm.add("PASS" if in_play and ready else "FAIL", "play", "client has its creature" if ready else text[:200])
    if not ready:
        return []
    time.sleep(2.0)
    shots = []
    for device, crop in (("phone", PHONE), ("real", None)):
        _, info = sm.lua("Client", H + 'return H:Invoke("device", "%s")' % device)
        sm.add("INFO", device, info.strip())
        sm.lua("Client", H + 'return H:Invoke("rest")')
        time.sleep(0.3)
        _, info = sm.lua("Client", H + 'return H:Invoke("measure")')
        sm.add("INFO", device + " rest", info.strip())
        _, info = sm.lua("Client", H + 'return H:Invoke("pose")')
        time.sleep(0.12)
        _, info = sm.lua("Client", H + 'return H:Invoke("measure")')
        sm.add("INFO", device + " pose", info.strip())
        shots.append((device + " HUD", capture(sm, device + "-hud", crop)))
        sm.lua("Client", H + 'return H:Invoke("open", "S11")')
        time.sleep(1.9)
        _, info = sm.lua("Client", H + 'return H:Invoke("measure")')
        sm.add("INFO", device + " S11", info.strip())
        shots.append((device + " S11", capture(sm, device + "-s11", crop)))
        sm.lua("Client", H + 'return H:Invoke("close", "S11")')
        sm.lua("Client", H + 'return H:Invoke("open", "S12")')
        time.sleep(3.2)
        _, info = sm.lua("Client", H + 'return H:Invoke("measure")')
        sm.add("INFO", device + " S12", info.strip())
        shots.append((device + " S12", capture(sm, device + "-s12", crop)))
        sm.lua("Client", H + 'return H:Invoke("close", "S12")')
        sm.lua("Client", H + 'return H:Invoke("reset")')
    _, out = sm.call("get_console_output", {}, 30)[:2]
    errors = [l for l in "\n".join(out).splitlines() if "error" in l.lower() and ("UI" in l or "Hud" in l)]
    sm.add("FAIL" if errors else "PASS", "console", "; ".join(errors)[:400] or "no UI errors")
    return shots


def run_cove(sm):
    """S12 with the specimen card and S14 on the phone and the desktop (08 sections 4.5 and 5.1)."""
    if not start(sm):
        return []
    shots = []
    for device, crop in (("phone", PHONE), ("real", None)):
        _, info = sm.lua("Client", H + 'return H:Invoke("device", "%s")' % device)
        sm.add("INFO", device, info.strip())
        variants = ("S12card", "S12small") if device == "phone" else ("S12card",)
        for v in variants:
            sm.lua("Client", H + 'return H:Invoke("open", "%s")' % v)
            time.sleep(4.2)
            _, info = sm.lua("Client", H + 'return H:Invoke("measure")')
            sm.add("INFO", "%s %s" % (device, v), info.strip())
            shots.append(("%s %s" % (device, v), capture(sm, "%s-%s" % (device, v.lower()), crop)))
            sm.lua("Client", H + 'return H:Invoke("close", "S12")')
        sm.lua("Client", H + 'return H:Invoke("cove")')
        time.sleep(1.2)
        _, info = sm.lua("Client", H + 'return H:Invoke("measure")')
        sm.add("INFO", device + " S14", info.strip())
        shots.append((device + " S14", capture(sm, device + "-s14", crop)))
        sm.lua("Client", H + 'return H:Invoke("reset")')
    console_check(sm)
    return shots


# The moment slot's rect in viewport px, from the client.
SLOT = ('local g = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("GulpMoments") '
        'local o = g and g:FindFirstChild("HUD.MomentSlot", true) '
        'if not o then return "" end local p, z = o.AbsolutePosition, o.AbsoluteSize '
        'local i = game:GetService("GuiService"):GetGuiInset() '
        'return p.X .. " " .. (p.Y + i.Y) .. " " .. z.X .. " " .. z.Y')

# S07 and S08 poses: (command, argument). The phone shows the four of loop 1; the desktop adds a
# tier 3 rise (four new foods) and every [MVP] trait glyph (Common to Mythic).
MOMENTS = {
    "phone": (("tierup", "2"), ("tierup", "7"), ("trait", "glow"), ("trait", "crystal")),
    "real": (("tierup", "2"), ("tierup", "3"), ("tierup", "7"), ("trait", "glow"), ("trait", "stripes"),
             ("trait", "spots"), ("trait", "plated"), ("trait", "spiny"), ("trait", "crystal"),
             ("trait", "moonlit")),
}


def run_moments(sm):
    """S07 tier-up and S08 trait gained on the phone and the desktop (08 sections 4.1 to 4.3): each card
    cropped around the slot (with the mass bar above it), plus the whole phone screen once."""
    if not start(sm):
        return []
    shots = []
    for device, crop in (("phone", PHONE), ("real", None)):
        _, info = sm.lua("Client", H + 'return H:Invoke("device", "%s")' % device)
        sm.add("INFO", device, info.strip())
        sm.lua("Client", H + 'return H:Invoke("hold", "on")')
        for cmd, arg in MOMENTS[device]:
            sm.lua("Client", H + 'return H:Invoke("%s", "%s")' % (cmd, arg))
            time.sleep(0.8)
            _, info = sm.lua("Client", H + 'return H:Invoke("measure")')
            sm.add("INFO", "%s %s %s" % (device, cmd, arg), info.strip())
            name = "%s-%s-%s" % (device, cmd, arg)
            if device == "phone" and arg == "7":
                shots.append(("phone whole screen, tier 7", capture(sm, name + "-full", crop)))
            _, rect = sm.lua("Client", SLOT)
            v = [float(x) for x in rect.split()] if rect.strip() else None
            box = None
            if v:
                x, y, w, h = v
                box = (x - 0.3 * w, y - 1.15 * h, x + 1.3 * w, y + 1.5 * h)
            shots.append(("%s %s %s" % (device, cmd, arg), capture(sm, name, crop, box)))
        sm.lua("Client", H + 'return H:Invoke("reset")')
    console_check(sm)
    return shots


def start(sm):
    mode, _ = sm.mode()
    if mode.lower() != "edit":
        sm.call("start_stop_play", {"is_start": False}, 120)
        sm.wait_mode("edit", 60)
    sm.call("start_stop_play", {"is_start": True}, 120)
    in_play, _ = sm.wait_mode("play", 60)
    ready, text = sm.poll_lua("Client", 'local p = game:GetService("Players").LocalPlayer '
                              'local c = p and p.Character return if c and c.PrimaryPart then "ready" else "wait"',
                              lambda x: "ready" in x, 60)
    sm.add("PASS" if in_play and ready else "FAIL", "play", "client has its creature" if ready else text[:200])
    if ready:
        time.sleep(2.0)
    return ready


def console_check(sm):
    _, out = sm.call("get_console_output", {}, 30)[:2]
    errors = [l for l in "\n".join(out).splitlines() if "error" in l.lower() and ("UI" in l or "Hud" in l)]
    sm.add("FAIL" if errors else "PASS", "console", "; ".join(errors)[:400] or "no UI errors")


def grid(shots, name="hud-grid.png", cols=3, max_width=None):
    cells = [Image.open(p) for _, p in shots]
    w = max(c.width for c in cells)
    h = max(c.height for c in cells)
    rows = (len(cells) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w, rows * (h + 24)), (20, 20, 28))
    d = ImageDraw.Draw(sheet)
    for i, (label, _) in enumerate(shots):
        x, y = (i % cols) * w, (i // cols) * (h + 24)
        sheet.paste(cells[i], (x, y + 24))
        d.text((x + 8, y + 6), label, fill=(255, 255, 255))
    if max_width and sheet.width > max_width:
        sheet = sheet.resize((max_width, round(sheet.height * max_width / sheet.width)), Image.LANCZOS)
    path = os.path.join(OUT, name)
    sheet.save(path)
    return path


def main():
    args = sys.argv[1:]
    tag = opt(args, "--tag", "gulp-hud")
    shot_set = opt(args, "--set", "hud")
    os.makedirs(OUT, exist_ok=True)
    rows, shots = [], []
    with studio_lock(owner="gulp hud shots", timeout=2400):
        with locks.Lock("heavy", owner="gulp hud shots", timeout=2400):
            b = subprocess.run(["rojo", "build", "ci.project.json", "-o", "build/ci.rbxl"], cwd=REPO, env=ENV,
                               capture_output=True, text=True)
            if b.returncode != 0:
                print("hud shots: FAIL build: " + (b.stderr or b.stdout)[-400:])
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
                        if shot_set == "cove":
                            shots = run_cove(sm)
                        elif shot_set == "moments":
                            shots = run_moments(sm)
                        else:
                            shots = run(sm)
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
    if shots:
        if shot_set == "cove":
            lines.append("grid: " + grid(shots, "cove-grid.png", 3))
        elif shot_set == "moments":
            path = grid(shots, "moments-grid.png", 4, 1536)
            small = Image.open(path)
            small.thumbnail((768, 768 * 4))
            small.save(os.path.join(OUT, "moments-grid-768.png"))
            lines.append("grid: " + path + " (and moments-grid-768.png)")
        else:
            lines.append("grid: " + grid(shots))
    print("\n".join(lines))
    sys.exit(1 if any(r[0] == "FAIL" for r in rows) or not shots else 0)


if __name__ == "__main__":
    main()
