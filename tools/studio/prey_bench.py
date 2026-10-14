#!/usr/bin/env python3
"""PreyRenderer bench in Studio, no server prey needed (task S3-C4; docs/09 sections 8.8 and 15.1, spike tech-b S6).

usage: python3 tools/studio/prey_bench.py [--tag NAME] [--seconds N] [--keep-open]

Under the machine-wide `studio` lock and one `heavy` slot, like tools/studio/smoke.py (whose helpers it reuses):
build build/ci.rbxl, open it as TestBench-<tag>, bring Studio to the front (a background window runs at 15 fps,
spike F12), start play, wait for the local creature, then on the client:
  1  Dev/PreyHarness.start (Smooth tier: 80 pooled meshes) feeds synthetic PreyState packets at 10 Hz and samples
     the frame time and PreyRenderer's draw step for N seconds (default 10) after a 2 s warm-up
  2  (S4-C1: plus 40 far groups and 2 groups held on the mouth) pass when 80 meshes were drawn, 170 far
     glints (250 visible − 80 meshes) on at most 30 emitters, bite claims were sent and the harness's accepts applied, lime shells showed, no packet was rejected and the frame-time p99 is at most
     20 ms (60 fps, vsync-capped on the Mac: 16.7 ms frames; tech-b S6 measured p99 17.7 ms) or within 2 ms of a
     control run with no prey measured just before it (Studio's own hitches)
  3  a second short run for the screenshot, then smoke.py's finish: no console line at error level, one screenshot
     downscaled to 768 px in build/prey/, stop play, Edit mode; the TestBench place is closed without saving.
"""
import os, re, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import smoke  # noqa: E402
from smoke import Smoke, open_place, bring_to_front, finish, opt, REPO, TOOLS, ENV  # noqa: E402
import locks  # noqa: E402
import studio_window as sw  # noqa: E402
from studio import StudioSession, studio_lock  # noqa: E402

OUT = os.path.join(REPO, "build", "prey")
HARNESS = 'local H = game:GetService("Players").LocalPlayer.PlayerScripts.Client:WaitForChild("PreyHarness", 10) '
P99_LIMIT_MS = 20.0
# S4-C1: 40 far krill groups (glints; Smooth has 30 emitters) and 2 groups held on the mouth, whose
# claims the harness answers as accepted.
S4_OPTIONS = "farGroups = 40, biteGroups = 2, acceptBites = true"
CONTROL_MARGIN_MS = 2.0  # or: no worse than the empty control run's p99 plus this


def run(sm, seconds):
    mode, _ = sm.mode()
    if mode.lower() != "edit":
        sm.call("start_stop_play", {"is_start": False}, 120)
        sm.wait_mode("edit", 60)
    sm.call("start_stop_play", {"is_start": True}, 120)
    in_play, _ = sm.wait_mode("play", 60)
    ready, text = sm.poll_lua("Client", 'local p = game:GetService("Players").LocalPlayer '
                              'local c = p and p.Character return if c and c.PrimaryPart and '
                              'p.PlayerScripts:FindFirstChild("Client") then "ready" else "wait"',
                              lambda x: "ready" in x, 60)
    sm.add("PASS" if in_play and ready else "FAIL", "play", "client has its creature" if ready else text[:200])
    if not ready:
        return
    # Control: the same measurement with no prey, so Studio's own hitches are not blamed on the renderer.
    sm.lua("Client", HARNESS + 'return H:Invoke("start", { seconds = %d, krillGroups = 0, planktonGroups = 0 })'
           % seconds)
    time.sleep(seconds + 2.5)
    _, control = sm.poll_lua("Client", HARNESS + 'return H:Invoke("result")', lambda x: x.startswith("done"),
                             30, every=1.0)
    control = control.strip()
    m = re.search(r"frameMs .*?p99=([\d.]+)", control)
    control_p99 = float(m.group(1)) if m else 0.0
    sm.add("INFO", "control", control[:300])
    _, text = sm.lua("Client", HARNESS + 'return H:Invoke("start", { seconds = %d, tier = "Smooth", %s })'
                     % (seconds, S4_OPTIONS))
    sm.add("PASS" if text.startswith("started") else "FAIL", "harness", text.strip()[:200])
    time.sleep(seconds + 2.5)  # no MCP calls while measuring: each one can cost Studio a frame
    done, text = sm.poll_lua("Client", HARNESS + 'return H:Invoke("result")', lambda x: x.startswith("done"),
                             seconds + 30, every=1.0)
    text = text.strip()
    with open(os.path.join(OUT, "result-%s.txt" % time.strftime("%Y%m%d-%H%M%S")), "w") as f:
        f.write(text + "\n")
    nums = dict((k, float(v)) for k, v in re.findall(r"(\w+)=([\d.]+)", text))
    p99 = re.search(r"frameMs .*?p99=([\d.]+)", text)
    p99 = float(p99.group(1)) if p99 else 999.0
    ok = (done and nums.get("drawnMax") == 80 and nums.get("outlinedMax", 0) > 0 and nums.get("rejected", 1) == 0
          and (p99 <= P99_LIMIT_MS or p99 <= control_p99 + CONTROL_MARGIN_MS))
    # S4-C1: far glints fill Smooth's prey-visible total (250 - 80 meshes = 170) within its 30 emitters, and
    # the mouth's bites were claimed, hidden and accepted (the harness accepts in the frame after the claim).
    ok = ok and 0 < nums.get("emittersMax", 0) <= 30 and nums.get("glintsMax") == 170 \
        and nums.get("claims", 0) > 0 and nums.get("accepted", 0) > 0
    sm.add("PASS" if ok else "FAIL", "bench", text[:600])
    # A short second run, so the screenshot shows prey; finish() captures while it runs.
    sm.lua("Client", HARNESS + 'return H:Invoke("start", { seconds = 6, tier = "Smooth", %s })' % S4_OPTIONS)
    time.sleep(4.0)


def main():
    args = sys.argv[1:]
    tag = opt(args, "--tag", "gulp-prey")
    seconds = int(opt(args, "--seconds", "10"))
    os.makedirs(OUT, exist_ok=True)
    smoke.OUT = OUT  # finish() writes its console log and screenshot here
    started = time.time()
    rows = []
    with studio_lock(owner="gulp prey bench", timeout=1800):
        with locks.Lock("heavy", owner="gulp prey bench", timeout=1800):
            b = subprocess.run(["rojo", "build", "ci.project.json", "-o", "build/ci.rbxl"], cwd=REPO, env=ENV,
                               capture_output=True, text=True)
            if b.returncode != 0:
                print("prey bench: FAIL\nFAIL build: " + (b.stderr or b.stdout)[-400:])
                sys.exit(1)
            title, sid = open_place(tag)
            previous = sw.frontmost()
            try:
                with StudioSession() as s:
                    sm = Smoke(s, sid)
                    pid = sw.pid_of(title)
                    if pid:
                        bring_to_front(pid)
                    stamp = time.strftime("%Y%m%d-%H%M%S")
                    try:
                        run(sm, seconds)
                    finally:
                        finish(sm, stamp)
                    rows = sm.rows
            finally:
                if "--keep-open" not in args:
                    subprocess.run([sys.executable, os.path.join(TOOLS, "studio-open.py"), "--close", tag,
                                    "--owner", smoke.OWNER], capture_output=True, text=True, timeout=180)
                sw.restore(previous)
    failed = sum(1 for r in rows if r[0] == "FAIL")
    print("prey bench: %s (%.0f s)" % ("FAIL" if failed or not rows else "PASS", time.time() - started))
    for status, step, detail in rows:
        print("%s %s: %s" % (status, step, detail))
    sys.exit(1 if failed or not rows else 0)


if __name__ == "__main__":
    main()
