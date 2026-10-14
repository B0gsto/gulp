#!/usr/bin/env python3
"""The client-side play check of the first-time script (task S6-C2; docs/04 sections 3.6 B1 to B5 and 12).

usage: python3 tools/studio/ftue_play.py [--tag NAME] [--seconds N]

Under the machine-wide `studio` lock and one `heavy` slot, like tools/studio/hud_shots.py: build build/ci.rbxl, open
it and start play solo. If the profile has already started or finished the script, `/ftue reset` runs through the
server's DevCommand. The client's TutorialDirector probe (`TutorialProbe`, Studio only) turns its autopilot on, which
steers at the beat's food from control on, as a player would. The director's beat log (J since it started, T since
control) is polled until GLOW (stage 5) or `--seconds` (default 75); captures at the hatch, the first bite, the tier-up
banner and GLOW go to build/ftue/, downscaled to 768 px. Prints the beat timings and the Sprint 6 demo verdict: the
first bite by T = 5, tier 2 by about T = 25 (30 allowed), five Glowfry and GLOW.
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
SHOTS = [("hatch", lambda w: w.startswith("hatch")), ("first-bite", lambda w: w == "stage 3"),
         ("tier-up", lambda w: w == "banner tierUp"), ("glow", lambda w: w == "banner trait")]


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
    _, out = sm.lua("Client", PROBE + 'return P:Invoke("pilot", "on")')
    sm.add("INFO", "pilot", out.strip())
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
    shots, taken = [], set()
    end = time.time() + seconds
    log = None
    while time.time() < end:
        log = marks(sm)
        for name, test in SHOTS:
            if name not in taken and any(test(m["what"]) for m in log["marks"]):
                taken.add(name)
                path = capture(sm, name)
                if path:
                    shots.append((name, path))
        if "glow" in taken or log["stage"] >= 5 and len(taken) == len(SHOTS):
            break
        time.sleep(0.15)
    time.sleep(1.0)
    log = marks(sm)
    return shots, log


def main():
    args = sys.argv[1:]
    tag = opt(args, "--tag", "gulp-ftue")
    seconds = float(opt(args, "--seconds", "75"))
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
    print("\n".join(lines))
    sys.exit(1 if any(r[0] == "FAIL" for r in rows) else 0)


if __name__ == "__main__":
    main()
