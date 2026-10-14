#!/usr/bin/env python3
"""Drives the GULP spike place in the shared Roblox Studio through its MCP server. Run under spike/tools/held.sh.

  drive.py probe            list Studios, state, execute_luau return format, StudioTestService members
  drive.py sync             push spike/src scripts into the open place (Edit data model), no re-open needed
  drive.py s1 [N=10]        N play-test starts: S1 (CharacterAdded both sides, console errors) and, on the first
                            three, the whole S15 loop (server Luau, client Luau, console, screenshot, stop)
  drive.py main             one play test: S10, S9 keys, then the server sequence (S14, S2, S4, S5), S16, screenshot
Results go to spike/out/*.json. The Studio id is resolved by window name (TestBench-gulp-spike), never assumed.
"""
import base64, json, os, re, sys, time

sys.path.insert(0, "/Users/bogdan/RobloxProjects/tools")
from studio import StudioSession  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
SPIKE = os.path.dirname(HERE)
OUT = os.path.join(SPIKE, "out")
WINDOW = "TestBench-gulp-spike"
ERR = re.compile(r"error|exception|attempt to|is not a valid member|stack begin|infinite yield|failed", re.I)


class Drv:
    def __init__(self, s):
        self.s = s
        ok, texts, _ = s.call("list_roblox_studios", {})
        self.studios = json.loads(texts[0])["studios"]
        mine = [x for x in self.studios if WINDOW in x["name"]]
        if not mine:
            # The MCP lists a freshly opened Rojo-built place as "Game", not by its file name. Identify ours by a
            # read-only fingerprint (the 150-part shell and the spike server script); never drive anything else.
            for x in self.studios:
                if "TestBench" in x["name"]:
                    continue
                self.sid = x["id"]
                ok, text = self.lua("Edit", 'local c = workspace:FindFirstChild("Collision") local s = game:GetService("ServerScriptService"):FindFirstChild("Server") return "fp=" .. tostring(c and #c:GetChildren()) .. "/" .. tostring(s and s:FindFirstChild("SpikeServer") ~= nil)')
                if ok and "fp=150/true" in text:
                    mine = [x]
                    break
        if not mine:
            sys.exit("no Studio window is the GULP spike place among %s" % (self.studios,))
        self.sid = mine[0]["id"]

    def call(self, tool, args=None, timeout=120):
        a = {"studio_id": self.sid}
        a.update(args or {})
        return self.s.call(tool, a, timeout)

    def lua(self, dm, code, timeout=90):
        ok, texts, _ = self.call("execute_luau", {"datamodel_type": dm, "code": code}, timeout)
        return ok, "\n".join(texts)

    def state(self):
        ok, texts, _ = self.call("get_studio_state")
        return "\n".join(texts)

    def attrs(self, dm, folder):
        """JSON attributes of ReplicatedStorage.<folder> as a dict of decoded values."""
        ok, text = self.lua(dm, """
local f = game:GetService("ReplicatedStorage"):FindFirstChild("%s")
return game:GetService("HttpService"):JSONEncode(f and f:GetAttributes() or {})""" % folder)
        m = re.search(r"\{.*\}", text, re.S)
        if not (ok and m):
            return {}
        try:
            raw = json.loads(m.group(0))
        except ValueError:
            try:
                raw = json.loads(json.loads('"' + m.group(0) + '"'))
            except ValueError:
                return {"_unparsed": text[:400]}
        out = {}
        for k, v in raw.items():
            try:
                out[k] = json.loads(v) if isinstance(v, str) else v
            except ValueError:
                out[k] = v
        return out

    def play(self, start):
        return self.call("start_stop_play", {"is_start": start}, 120)

    def wait_state(self, want, timeout=60):
        t0 = time.time()
        st = ""
        while time.time() - t0 < timeout:
            st = self.state()
            m = re.search(r"Current Studio Mode:\s*(\w+)", st)
            if m and m.group(1).lower() == want.lower():
                return True, time.time() - t0, st
            time.sleep(0.5)
        return False, time.time() - t0, st

    def wait_attr(self, dm, folder, keys, timeout=40, every=0.7):
        t0 = time.time()
        a = {}
        while time.time() - t0 < timeout:
            a = self.attrs(dm, folder)
            if all(k in a for k in keys):
                return True, time.time() - t0, a
            time.sleep(every)
        return False, time.time() - t0, a

    def console(self, path):
        ok, texts, _ = self.call("get_console_output")
        text = "\n".join(texts)
        with open(path, "w") as f:
            f.write(text)
        lines = text.splitlines()
        bad = [l for l in lines if ERR.search(l) and "[SPIKE]" not in l]
        return ok, len(lines), bad

    def shot(self, path, cid="ScreenCapture_1"):
        ok, texts, images = self.call("screen_capture", {"capture_id": cid}, 60)
        if images:
            with open(path, "wb") as f:
                f.write(base64.b64decode(images[0]))
        return ok and bool(images), (texts[0][:200] if texts else "")


def save(name, data):
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name), "w") as f:
        json.dump(data, f, indent=1, default=str)


def probe(d):
    print("studios:", d.studios)
    print("mine:", d.sid)
    print("state:", d.state()[:400])
    print("ret:", d.lua("Edit", 'return game:GetService("HttpService"):JSONEncode({a=1,name=game.Name})'))
    print("ws:", d.lua("Edit", """
local out = {}
for _, n in {"StreamingEnabled","StreamingMinRadius","StreamingTargetRadius","StreamingIntegrityMode","ModelStreamingBehavior","FallenPartsDestroyHeight"} do
  local ok, v = pcall(function() return workspace[n] end)
  table.insert(out, n .. "=" .. (ok and tostring(v) or "UNREADABLE"))
end
table.insert(out, "shell=" .. #workspace.Collision:GetChildren() .. " " .. tostring(workspace.Collision.ModelStreamingMode))
table.insert(out, "autoLoads=" .. tostring(game:GetService("Players").CharacterAutoLoads))
table.insert(out, "chat=" .. tostring(game:GetService("TextChatService").ChatVersion))
return table.concat(out, " ")"""))
    print("sts:", d.lua("Edit", """
local out = {}
local ok, sts = pcall(function() return game:GetService("StudioTestService") end)
if not ok then return "no StudioTestService: " .. tostring(sts) end
for _, n in {"ExecutePlayModeAsync","ExecuteRunModeAsync","ExecuteMultiplayerTestAsync","ExecuteServerAndClientsAsync","StartMultiplayerTest","EndTest","GetTestArgs","NumberOfPlayers","NumPlayers","ExecuteTeamTestAsync"} do
  local ok2, v = pcall(function() return sts[n] end)
  table.insert(out, n .. "=" .. (ok2 and typeof(v) or "missing"))
end
local ok3, ts = pcall(function() return game:GetService("TestService").NumberOfPlayers end)
table.insert(out, "TestService.NumberOfPlayers=" .. tostring(ok3 and ts))
return table.concat(out, " ")"""))


def sync(d):
    rules = []
    for base, root in (("src/shared", "game.ReplicatedStorage.Shared"), ("src/server", "game.ServerScriptService.Server"),
                       ("src/client", "game.StarterPlayer.StarterPlayerScripts")):
        for dp, _, files in os.walk(os.path.join(SPIKE, base)):
            for fn in files:
                if not fn.endswith(".luau"):
                    continue
                rel = os.path.relpath(os.path.join(dp, fn), os.path.join(SPIKE, base))
                parts = rel.split(os.sep)
                stem = parts[-1].replace(".server.luau", "").replace(".client.luau", "").replace(".luau", "")
                path = parts[:-1] + ([] if stem == "init" else [stem])
                rules.append((os.path.join(dp, fn), root + "".join('["%s"]' % p for p in path)))
    for fpath, inst in rules:
        src = open(fpath).read()
        lvl = "=" * 3
        assert "]" + lvl + "]" not in src
        ok, text = d.lua("Edit", "local s = %s\ns.Source = [%s[\n%s]%s]\nreturn s:GetFullName() .. ' ' .. #s.Source" % (inst, lvl, src, lvl))
        print("sync", ok, text[:120])


def s1(d, n):
    rows = []
    for i in range(1, n + 1):
        row = {"cycle": i}
        t0 = time.time()
        ok, texts, _ = d.play(True)
        row["startOk"], row["startText"] = ok, (texts[0][:120] if texts else "")
        okS, tS, a = d.wait_attr("Server", "SpikeResults", ["S1_server", "S1_client", "S5_join"], 45)
        row["readyAfterStartS"] = round(time.time() - t0, 2)
        row["S1_server"], row["S1_client"], row["S5_join"] = a.get("S1_server"), a.get("S1_client"), a.get("S5_join")
        row["S11_roblox"] = a.get("S11_roblox")
        if i <= 3:  # the S15 loop
            okL, sv = d.lua("Server", 'return "server players=" .. #game:GetService("Players"):GetPlayers() .. " creatures=" .. #workspace.Creatures:GetChildren() .. " isServer=" .. tostring(game:GetService("RunService"):IsServer())')
            okC, cl = d.lua("Client", 'local p = game:GetService("Players").LocalPlayer return "client char=" .. tostring(p.Character) .. " cam=" .. tostring(workspace.CurrentCamera.CameraType) .. " isClient=" .. tostring(game:GetService("RunService"):IsClient())')
            okShot, shotText = d.shot(os.path.join(OUT, "s15-shot-%d.png" % i), "ScreenCapture_%d" % i)
            row["s15"] = {"serverLuau": [okL, sv[:200]], "clientLuau": [okC, cl[:200]], "screenshot": [okShot, shotText]}
        okCon, nLines, bad = d.console(os.path.join(OUT, "s1-console-%d.txt" % i))
        row["consoleOk"], row["consoleLines"], row["consoleSuspect"] = okCon, nLines, bad[:12]
        ok, texts, _ = d.play(False)
        row["stopOk"] = ok
        okE, tE, st = d.wait_state("edit", 40)
        row["backToEdit"], row["stopS"] = okE, round(tE, 2)
        row["cycleS"] = round(time.time() - t0, 2)
        if i <= 3:
            row["s15"]["loopComplete"] = bool(row["startOk"] and okL and okC and okCon and okShot and row["stopOk"] and okE)
        rows.append(row)
        print("cycle", i, "server", bool(row["S1_server"] and row["S1_server"].get("characterAdded")),
              "client", bool(row["S1_client"] and row["S1_client"].get("characterAdded")),
              "suspect", len(bad), "ready %.1fs" % row["readyAfterStartS"], "cycle %.1fs" % row["cycleS"], flush=True)
        save("s1.json", rows)
        time.sleep(1.0)


CORE_GUI = """
local out = {}
local cg = game:GetService("CoreGui")
local function visible(g)
  local a = g
  while a and a ~= cg do
    if a:IsA("GuiObject") and not a.Visible then return false end
    if a:IsA("LayerCollector") and not a.Enabled then return false end
    a = a.Parent
  end
  return true
end
local find = "%s"
local found = 0
for _, sg in cg:GetDescendants() do
  if sg:IsA("GuiObject") and visible(sg) then
    local s, p = sg.AbsoluteSize, sg.AbsolutePosition
    local drawn = (sg.BackgroundTransparency < 1) or (sg:IsA("ImageLabel") or sg:IsA("ImageButton")) and sg.ImageTransparency < 1 and sg.Image ~= ""
      or (sg:IsA("TextLabel") or sg:IsA("TextButton")) and sg.TextTransparency < 1 and sg.Text ~= ""
    if find ~= "" and (sg:IsA("TextLabel") or sg:IsA("TextButton")) and string.find(sg.Text, find, 1, true) then found += 1 end
    if drawn and s.X > 2 and s.Y > 2 and p.X < 4000 and p.Y < 4000 and p.X + s.X > 0 and p.Y + s.Y > 0 then
      local top = sg
      while top.Parent and top.Parent ~= cg do top = top.Parent end
      local key = top.Name
      out[key] = out[key] or { n = 0, sample = {} }
      out[key].n += 1
      if #out[key].sample < 4 then
        table.insert(out[key].sample, string.format("%%s %%s %%dx%%d@%%d,%%d", sg.Name, sg.ClassName, s.X, s.Y, p.X, p.Y))
      end
    end
  end
end
-- looser second view: every visible Image/Text object in the top 70 px, and every enabled top-level ScreenGui
local top, screens = {}, {}
for _, sg in cg:GetDescendants() do
  if sg:IsA("GuiObject") and visible(sg) and (sg:IsA("ImageLabel") or sg:IsA("ImageButton") or sg:IsA("TextLabel") or sg:IsA("TextButton")) then
    local s, p = sg.AbsoluteSize, sg.AbsolutePosition
    if p.Y < 70 and p.Y + s.Y > 0 and s.X >= 8 and s.Y >= 8 and p.X >= 0 and p.X < 4000 and #top < 30 then
      local anc = sg:FindFirstAncestorWhichIsA("LayerCollector")
      table.insert(top, string.format("%%s/%%s %%s %%dx%%d@%%d,%%d", anc and anc.Name or "?", sg.Name, sg.ClassName, s.X, s.Y, p.X, p.Y))
    end
  end
end
for _, c in cg:GetChildren() do
  if c:IsA("LayerCollector") and c.Enabled then
    local n = 0
    for _, g in c:GetDescendants() do if g:IsA("GuiObject") and visible(g) and g.AbsoluteSize.X > 2 then n += 1 end end
    table.insert(screens, c.Name .. ":" .. n)
  end
end
return game:GetService("HttpService"):JSONEncode({ drawn = out, found = found, topArea = top, screens = screens })
"""


def core_gui(d, find=""):
    ok, text = d.lua("Client", CORE_GUI % find)
    m = re.search(r"\{.*\}", text, re.S)
    try:
        return json.loads(m.group(0)) if m else {"raw": text[:300]}
    except ValueError:
        return {"raw": text[:600]}


def main_run(d):
    res = {}
    t0 = time.time()
    ok, texts, _ = d.play(True)
    okS, tS, a = d.wait_attr("Server", "SpikeResults", ["S1_server", "S1_client"], 45)
    res["ready"] = [okS, round(time.time() - t0, 2)]
    time.sleep(2.0)
    res["S10_coreGuiDrawn"] = core_gui(d)
    # S9: keys through MCP drive the same SwimInput
    before = d.attrs("Client", "SpikeClientState").get("S9")
    okK, textsK, _ = d.call("user_keyboard_input", {"datamodel_type": "Client", "actions": [
        {"action": "keyDown", "key_code": "W"}, {"action": "wait", "wait_time_ms": 1000}, {"action": "keyUp", "key_code": "W"},
        {"action": "keyDown", "key_code": "D"}, {"action": "wait", "wait_time_ms": 600}, {"action": "keyUp", "key_code": "D"},
        {"action": "keyDown", "key_code": "Space"}, {"action": "wait", "wait_time_ms": 400}, {"action": "keyUp", "key_code": "Space"}]}, 60)
    time.sleep(1.2)
    cs = d.attrs("Client", "SpikeClientState")
    res["S9"] = {"keyCallOk": okK, "keyCallText": (textsK[0][:200] if textsK else ""), "before": before, "after": cs.get("S9")}
    res["S10_client"] = cs.get("S10")
    save("main.json", res)
    # server sequence
    d.lua("Server", 'game:GetService("ReplicatedStorage").SpikeResults:SetAttribute("cmd", "runAll") return "ok"')
    okD, tD, a = d.wait_attr("Server", "SpikeResults", ["done"], 200, every=3.0)
    res["sequenceDone"] = [okD, round(tD, 1)]
    res["results"] = a
    save("main.json", res)
    # S16 with all core GUI off (the design's condition), then with the Chat core GUI on if no bubble appeared
    s16 = {}
    d.lua("Client", 'game:GetService("ReplicatedStorage").SpikeClientState.Cmd:Fire("s16") return "ok"')
    time.sleep(1.5)
    s16["coreGuiAllOff"] = {"client": d.attrs("Client", "SpikeClientState").get("S16_client"), "coreGui": core_gui(d, "GULP bubble S16")}
    if not s16["coreGuiAllOff"]["coreGui"].get("found"):
        d.lua("Client", 'game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true) return "ok"')
        time.sleep(0.5)
        d.lua("Client", 'game:GetService("ReplicatedStorage").SpikeClientState.Cmd:Fire("s16") return "ok"')
        time.sleep(1.5)
        s16["chatCoreGuiOn"] = {"client": d.attrs("Client", "SpikeClientState").get("S16_client"), "coreGui": core_gui(d, "GULP bubble S16")}
    s16["screenshot"] = d.shot(os.path.join(OUT, "main-shot.png"), "ScreenCapture_9")
    res["S16"] = s16
    # negative control: does get_console_output show warnings and errors from both sides at all?
    for dm in ("Server", "Client"):
        d.lua(dm, 'warn("SPIKE_WARN_CONTROL_%s") task.spawn(function() error("SPIKE_ERR_CONTROL_%s") end) return "ok"' % (dm, dm))
    time.sleep(1.0)
    okCon, nLines, bad = d.console(os.path.join(OUT, "main-console.txt"))
    text = open(os.path.join(OUT, "main-console.txt")).read()
    res["console"] = {"lines": nLines, "suspect": [b[:300] for b in bad if "CONTROL" not in b][:20],
                      "controlSeen": {k: (k in text) for k in ("SPIKE_WARN_CONTROL_Server", "SPIKE_ERR_CONTROL_Server", "SPIKE_WARN_CONTROL_Client", "SPIKE_ERR_CONTROL_Client")}}
    d.play(False)
    res["backToEdit"] = d.wait_state("edit", 40)[0]
    save("main.json", res)
    print("main done: sequence", res["sequenceDone"], "ready", res["ready"], "edit", res["backToEdit"])


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "probe"
    with StudioSession() as s:
        d = Drv(s)
        try:
            if mode == "probe":
                probe(d)
            elif mode == "sync":
                sync(d)
            elif mode == "s1":
                s1(d, int(sys.argv[2]) if len(sys.argv) > 2 else 10)
            elif mode == "main":
                main_run(d)
        finally:
            if mode in ("s1", "main"):  # never leave Studio playing
                st = d.state()
                if "Current Studio Mode: Edit" not in st:
                    d.play(False)
                    d.wait_state("edit", 30)
