#!/usr/bin/env python3
"""GULP play-test smoke check, no human click (docs/09-technical-architecture.md, section 16.4; task S2-C7).

usage: python3 tools/studio/smoke.py [--tag NAME] [--keep-open] [--control]

Under the machine-wide `studio` lock, then one `heavy` slot (~/RobloxProjects/tools/locks.py order):
  build   rojo build ci.project.json -o build/ci.rbxl
  open    ~/RobloxProjects/tools/studio-open.py (TestBench-<tag>; an old window of that tag is closed first so the
          fresh build is loaded); Studio is then brought to the front for the play test, since a background
          window is throttled to 15 fps (spike F12), and the previous app is given focus back at the end
  1       start_stop_play (start); poll get_studio_state until Play, and a Client execute_luau until it sees the
          LocalPlayer
  2       tools/studio/smoke.luau, STEP "owner": slot, creature, root network owner (polled while it says WAIT)
  3       user_keyboard_input holds W for 2 s; smoke.luau, STEP "moved": the pose moved more than 30 studs
  4, 5    smoke.luau, STEP "later": PENDING with the sprint that enables each
  6       get_console_output: no line at error level
  7       screen_capture, downscaled to 768 px, saved to build/smoke/; start_stop_play (stop), Edit mode
  close   the TestBench place is closed without saving (unless --keep-open)
--control proves the console check: it writes a warning and an error on each side before step 6, and reports
whether exactly the two errors were caught (step 6 then fails, as it should).
Prints one report; its first line is the verdict. Exit 0 on PASS, 1 on FAIL. Raw console and state go to
build/smoke/ next to the screenshot.
"""
import base64, os, re, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TOOLS = os.path.expanduser("~/RobloxProjects/tools")
sys.path.insert(0, TOOLS)
import locks  # noqa: E402
import studio_window as sw  # noqa: E402
from studio import StudioSession, studio_lock  # noqa: E402

OWNER = "gulp-smoke"  # one owner for every worktree, so any of them may close a leftover smoke window
SNIPPET = os.path.join(HERE, "smoke.luau")
OUT = os.path.join(REPO, "build", "smoke")
HOLD_MS = 2000
ENV = dict(os.environ, PATH=os.path.expanduser("~/.rokit/bin") + ":" + os.environ.get("PATH", ""))
# get_console_output gives plain lines with no MessageType. An engine error (error(), a runtime error) is the line
# followed by "Stack Begin" ... "Stack End"; a warning has no stack. Log.error (src/shared/Util/Log) writes
# "[Tag] ERROR: ..." through warn, so it is matched by its text. Checked with --control.
LOG_ERROR = re.compile(r"^\[[^\]]+\] ERROR: ")


def error_lines(console):
    lines = console.splitlines()
    out = []
    for i, line in enumerate(lines):
        followed = i + 1 < len(lines) and lines[i + 1].strip() == "Stack Begin"
        if (followed and line.strip() not in ("Stack Begin", "Stack End")) or LOG_ERROR.match(line):
            out.append(line)
    return out


def opt(args, key, default=None):
    return args[args.index(key) + 1] if key in args else default


def snippet(step, frm=None):
    code = open(SNIPPET).read()
    code = code.replace('local STEP = "owner"', 'local STEP = "%s"' % step, 1)
    if frm:
        code = code.replace("local FROM: Vector3? = nil", "local FROM: Vector3? = Vector3.new(%s, %s, %s)" % frm, 1)
    return code


class Smoke:
    def __init__(self, s, sid):
        self.s, self.sid = s, sid
        self.rows = []  # (status, step, detail)
        self.t0 = time.time()

    def add(self, status, step, detail):
        self.rows.append((status, step, detail))

    def call(self, tool, args=None, timeout=120):
        a = {"studio_id": self.sid}
        a.update(args or {})
        return self.s.call(tool, a, timeout)

    def lua(self, dm, code, timeout=60):
        ok, texts, _ = self.call("execute_luau", {"datamodel_type": dm, "code": code}, timeout)
        return ok, "\n".join(texts)

    def mode(self):
        ok, texts, _ = self.call("get_studio_state", {}, 30)
        text = "\n".join(texts)
        m = re.search(r"Current Studio Mode:\s*(\w+)", text)
        return (m.group(1) if m else "?"), text

    def wait_mode(self, want, timeout):
        end = time.time() + timeout
        while time.time() < end:
            mode, text = self.mode()
            if mode.lower() == want.lower():
                return True, text
            time.sleep(0.5)
        return False, text

    def poll_lua(self, dm, code, done, timeout, every=0.5):
        end = time.time() + timeout
        text = ""
        while time.time() < end:
            ok, text = self.lua(dm, code)
            if ok and done(text):
                return True, text
            time.sleep(every)
        return False, text


def run_smoke(sm, tag):
    stamp = time.strftime("%Y%m%d-%H%M%S")
    # Step 1: play started and the client data model exists.
    mode, _ = sm.mode()
    if mode.lower() != "edit":
        sm.call("start_stop_play", {"is_start": False}, 120)
        sm.wait_mode("edit", 60)
    t = time.time()
    ok, texts, _ = sm.call("start_stop_play", {"is_start": True}, 120)
    inPlay, state = sm.wait_mode("play", 60)
    client, text = sm.poll_lua("Client", 'local p = game:GetService("Players").LocalPlayer return "client " .. (p and p.Name or "none")',
                               lambda x: "client " in x and "client none" not in x, 60)
    sm.add("PASS" if ok and inPlay and client else "FAIL", "step 1",
           "play started, client data model has the LocalPlayer (%.1f s)" % (time.time() - t) if inPlay and client
           else "start ok=%s, mode play=%s, client: %s" % (ok, inPlay, text.strip()[:200]))
    with open(os.path.join(OUT, "state-%s.txt" % stamp), "w") as f:
        f.write(state)
    if not (inPlay and client):
        return stamp

    # Step 2: slot, creature, network owner.
    t = time.time()
    _, text = sm.poll_lua("Server", snippet("owner"), lambda x: not x.startswith("smoke step 2: WAIT"), 30)
    sm.add(verdict(text), "step 2", "%s (after %.1f s)" % (body(text), time.time() - t))
    m = re.search(r"POSE (\S+) (\S+) (\S+)", text)
    if not m or verdict(text) != "PASS":
        return stamp
    frm = m.groups()

    # Step 3: hold W for 2 s; the pose moved more than 30 studs. The client must see its root first.
    sm.poll_lua("Client", 'local c = game:GetService("Players").LocalPlayer.Character '
                'return if c and c:FindFirstChild("Root") then "ready" else "no root"', lambda x: "ready" in x, 15)
    ok, texts, _ = sm.call("user_keyboard_input", {"datamodel_type": "Client", "actions": [
        {"action": "keyDown", "key_code": "W"}, {"action": "wait", "wait_time_ms": HOLD_MS},
        {"action": "keyUp", "key_code": "W"}]}, 60)
    if not ok:
        sm.add("FAIL", "step 3", "user_keyboard_input: %s" % " ".join(texts)[:200])
        return stamp
    time.sleep(0.3)
    _, text = sm.lua("Server", snippet("moved", frm))
    sm.add(verdict(text), "step 3", body(text))

    # Steps 4 and 5: pending until their modules exist.
    _, text = sm.lua("Server", snippet("later"))
    for line in text.splitlines()[1:]:
        m = re.match(r"(\w+) (step \d): (.*)", line)
        if m:
            sm.add(m.group(1), m.group(2), m.group(3))
    return stamp


def verdict(text):
    m = re.match(r"smoke [^:]+: (\w+)", text.strip())
    return m.group(1) if m else "FAIL"


def body(text):
    lines = [l for l in text.strip().splitlines()[1:] if not l.startswith("POSE ")]
    return "; ".join(lines) if lines else text.strip()[:300]


def control(sm):
    """Negative control for step 6: a warning and an error on each side; only the errors must be caught."""
    for dm in ("Server", "Client"):
        sm.lua(dm, 'warn("SMOKE_WARN_CONTROL_%s") task.spawn(error, "SMOKE_ERR_CONTROL_%s") return "ok"' % (dm, dm))
    time.sleep(1.0)
    ok, texts, _ = sm.call("get_console_output", {}, 60)
    caught = [l.strip() for l in error_lines("\n".join(texts)) if "SMOKE_" in l]
    want = ["SMOKE_ERR_CONTROL_Server", "SMOKE_ERR_CONTROL_Client"]
    sm.add("PASS" if sorted(caught) == sorted(want) else "FAIL", "control",
           "console check catches the 2 control errors and neither control warning (caught: %s)" % caught)


def finish(sm, stamp):
    # Step 6: no line at error level (read before stopping, so it is this play test's console).
    ok, texts, _ = sm.call("get_console_output", {}, 60)
    console = "\n".join(texts)
    with open(os.path.join(OUT, "console-%s.txt" % stamp), "w") as f:
        f.write(console)
    errors = error_lines(console)
    sm.add("PASS" if ok and not errors else "FAIL", "step 6",
           "%d console lines, %d at error level%s" % (len(console.splitlines()), len(errors),
                                                     (": " + errors[0][:200]) if errors else ""))
    # Step 7: screenshot to disk, downscaled; then stop play and wait for Edit mode.
    ok, texts, images = sm.call("screen_capture", {"capture_id": "smoke"}, 60)
    path = os.path.join(OUT, "smoke-%s.png" % stamp)
    if images:
        with open(path, "wb") as f:
            f.write(base64.b64decode(images[0]))
        subprocess.run(["sips", "-Z", "768", path, "--out", path], capture_output=True)
    sm.call("start_stop_play", {"is_start": False}, 120)
    edit, _ = sm.wait_mode("edit", 60)
    sm.add("PASS" if images and edit else "FAIL", "step 7",
           "screenshot %s; stopped, Edit mode %s" % (os.path.relpath(path, REPO) if images else "missing", edit))


def open_place(tag):
    subprocess.run([sys.executable, os.path.join(TOOLS, "studio-open.py"), "--close", tag, "--owner", OWNER],
                   capture_output=True, text=True, timeout=180)
    r = subprocess.run([sys.executable, os.path.join(TOOLS, "studio-open.py"), os.path.join(REPO, "build", "ci.rbxl"),
                        "--tag", tag, "--owner", OWNER], capture_output=True, text=True, timeout=600, cwd=REPO)
    title = re.search(r"^title: (.*)$", r.stdout, re.M)
    sid = re.search(r"^studio_id: (\S+)", r.stdout, re.M)
    if r.returncode != 0 or not title or not sid:
        raise RuntimeError("studio-open failed (%d): %s %s" % (r.returncode, r.stdout[-400:], r.stderr[-400:]))
    return title.group(1).strip(), sid.group(1)


def bring_to_front(pid):
    subprocess.run(["osascript", "-e", 'tell application "System Events" to set frontmost of (first process whose '
                    "unix id is %d) to true" % pid], capture_output=True, timeout=15)
    time.sleep(0.5)


def main():
    args = sys.argv[1:]
    tag = opt(args, "--tag", "gulp-smoke")
    os.makedirs(OUT, exist_ok=True)
    started = time.time()
    rows = []
    with studio_lock(owner="gulp smoke", timeout=1800):
        with locks.Lock("heavy", owner="gulp smoke", timeout=1800):
            b = subprocess.run(["rojo", "build", "ci.project.json", "-o", "build/ci.rbxl"], cwd=REPO, env=ENV,
                               capture_output=True, text=True)
            if b.returncode != 0:
                print("smoke: FAIL\nFAIL build: " + (b.stderr or b.stdout)[-400:])
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
                        stamp = run_smoke(sm, tag)
                        if "--control" in args:
                            control(sm)
                    finally:
                        finish(sm, stamp)
                    rows = sm.rows
            finally:
                if "--keep-open" not in args:
                    subprocess.run([sys.executable, os.path.join(TOOLS, "studio-open.py"), "--close", tag,
                                    "--owner", OWNER], capture_output=True, text=True, timeout=180)
                sw.restore(previous)
    failed = sum(1 for r in rows if r[0] == "FAIL")
    passed = sum(1 for r in rows if r[0] == "PASS")
    pending = sum(1 for r in rows if r[0] == "PENDING")
    print("smoke: %s (%d pass, %d fail, %d pending; %.0f s)" % ("FAIL" if failed or not rows else "PASS", passed,
                                                              failed, pending, time.time() - started))
    for status, step, detail in rows:
        print("%s %s: %s" % (status, step, detail))
    sys.exit(1 if failed or not rows else 0)


if __name__ == "__main__":
    main()
