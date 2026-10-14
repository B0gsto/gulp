#!/usr/bin/env python3
"""Spike part B driver (S6, S7, S3/S4 under latency, S12, S0-C11 memory). Run under spike/tools/held.sh.

  drive_b.py probe     read-only: network-simulation settings, AuthorityMode, BindToSimulation, memory at idle
  drive_b.py sync      push spike/src into the open place, creating scripts that do not exist yet
  drive_b.py play      one play test: S7 (900-byte buffers), S6 (prey server + client BulkMoveTo), memory
  drive_b.py mp        two-client test: S3 rig smoothing and S4 correction at 0, 100 and 200 ms, memory
Results go to spike/out/b-*.json.
"""
import json, os, re, subprocess, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from drive import Drv, StudioSession, save, sync as sync_a, SPIKE, OUT  # noqa: E402


def studio_mem():
    """RSS (MB) of every RobloxStudio process, and vmmap physical footprint of each."""
    out = {}
    pids = subprocess.run(["pgrep", "-x", "RobloxStudio"], capture_output=True, text=True).stdout.split()
    for p in pids:
        rss = subprocess.run(["ps", "-o", "rss=", "-p", p], capture_output=True, text=True).stdout.strip()
        vm = subprocess.run(["vmmap", "--summary", p], capture_output=True, text=True).stdout
        m = re.search(r"Physical footprint:\s+(\S+)", vm)
        mp = re.search(r"Physical footprint \(peak\):\s+(\S+)", vm)
        out[p] = {"rssMb": round(int(rss or 0) / 1024), "footprint": m and m.group(1), "footprintPeak": mp and mp.group(1)}
    return out


def lua_json(d, dm, code, timeout=90):
    ok, text = d.lua(dm, code, timeout)
    m = re.search(r"\{.*\}", text, re.S)
    if not m:
        return {"_raw": text[:600], "_ok": ok}
    for cand in (m.group(0),):
        try:
            return json.loads(cand)
        except ValueError:
            try:
                return json.loads(json.loads('"' + cand + '"'))
            except ValueError:
                return {"_raw": text[:600]}


PROBE = r"""
local out = {}
local function try(name, f) local ok, v = pcall(f) out[name] = ok and tostring(v) or ("ERR " .. tostring(v)) end
try("net.IncomingReplicationLag", function() return settings().Network.IncomingReplicationLag end)
try("net.class", function() return settings().Network.ClassName end)
try("ws.AuthorityMode", function() return workspace.AuthorityMode end)
try("rs.BindToSimulation", function() return typeof(game:GetService("RunService").BindToSimulation) end)
try("ws.PhysicsSteppingMethod", function() return workspace.PhysicsSteppingMethod end)
try("ure", function() return Instance.new("UnreliableRemoteEvent").ClassName end)
try("stats.DataReceiveKbps", function() return game:GetService("Stats").DataReceiveKbps end)
try("stats.DataSendKbps", function() return game:GetService("Stats").DataSendKbps end)
try("bulkMoveTo", function() return typeof(workspace.BulkMoveTo) end)
return game:GetService("HttpService"):JSONEncode(out)
"""


def probe(d):
    res = {"state": d.state()[:200], "edit": lua_json(d, "Edit", PROBE), "memIdle": studio_mem()}
    save("b-probe.json", res)
    print(json.dumps(res, indent=1)[:2500])


def sync(d):
    # create any script under src/ that the open place does not have yet, then reuse part A's source push
    made = []
    for base, root in (("src/server", "game.ServerScriptService.Server"), ("src/client", "game.StarterPlayer.StarterPlayerScripts"),
                       ("src/shared", "game.ReplicatedStorage.Shared"), ("src/shared/Logic", "game.ReplicatedStorage.Shared.Logic")):
        for fn in sorted(os.listdir(os.path.join(SPIKE, base))):
            if not fn.endswith(".luau") or fn == "init.luau":
                continue
            cls = "Script" if fn.endswith(".server.luau") else "LocalScript" if fn.endswith(".client.luau") else "ModuleScript"
            stem = fn.replace(".server.luau", "").replace(".client.luau", "").replace(".luau", "")
            ok, text = d.lua("Edit", 'local p = %s if p:FindFirstChild("%s") then return "have" end local s = Instance.new("%s") s.Name = "%s" s.Parent = p return "made"' % (root, stem, cls, stem))
            if "made" in text:
                made.append(fn)
    print("created", made)
    sync_a(d)


def front(pid=None):
    """Bring the spike Studio window to the front (Studio throttles a background window to 15 fps)."""
    pid = pid or STUDIO_PID
    subprocess.run(["osascript", "-e", 'tell application "System Events" to set frontmost of (first process whose unix id is %s) to true' % pid], capture_output=True)


def spike_pid():
    for p in subprocess.run(["pgrep", "-x", "RobloxStudio"], capture_output=True, text=True).stdout.split():
        if "TestBench-gulp-spike" in subprocess.run(["lsof", "-p", p], capture_output=True, text=True).stdout:
            return p
    return None


def wait_attr(d, dm, folder, key, timeout, every=2.0):
    t0 = time.time()
    while time.time() - t0 < timeout:
        a = d.attrs(dm, folder)
        if key in a:
            return a
        time.sleep(every)
    return d.attrs(dm, folder)


def play(d):
    res = {"memIdle": studio_mem()}
    t0 = time.time()
    d.play(True)
    ok, _, a = d.wait_attr("Server", "SpikeResults", ["S1_server", "S1_client"], 45)
    res["ready"] = [ok, round(time.time() - t0, 1)]
    time.sleep(2)
    res["memPlay"] = studio_mem()
    d.lua("Client", 'game:GetService("ReplicatedStorage").SpikeBClientState.Cmd:Fire("rtt", "solo") return 1')
    res["rtt"] = wait_attr(d, "Client", "SpikeBClientState", "rtt_solo", 20).get("rtt_solo")
    # S7
    d.lua("Server", 'game:GetService("ReplicatedStorage").SpikeBResults:SetAttribute("cmd", "s7") return 1')
    a = wait_attr(d, "Server", "SpikeBResults", "done_s7", 120, 3)
    res["S7_server"], res["S7_err"] = a.get("S7_server"), a.get("error_s7")
    res["S7_client"] = wait_attr(d, "Client", "SpikeBClientState", "S7", 10).get("S7")
    save("b-play.json", res)
    print("S7 done", json.dumps(res["S7_client"])[:600], flush=True)
    # S6: crowded then spread, client drawing 80 pooled parts with Studio in front
    for sc in ("crowded", "spread"):
        front()
        d.lua("Client", 'game:GetService("ReplicatedStorage").SpikeBClientState.Cmd:Fire("s6draw", 22) return 1')
        d.lua("Server", 'game:GetService("ReplicatedStorage").SpikeBResults:SetAttribute("cmd", "s6:%s:20") return 1' % sc)
        a = wait_attr(d, "Server", "SpikeBResults", "done_s6_" + sc, 90, 3)
        res["S6_" + sc], res["S6_err_" + sc] = a.get("S6_" + sc), a.get("error_s6")
        time.sleep(1)
        res["S6_client_" + sc] = d.attrs("Client", "SpikeBClientState").get("S6_client")
        if sc == "crowded":
            res["memPlayLoaded"] = studio_mem()
        save("b-play.json", res)
        print(sc, json.dumps(res["S6_" + sc])[:900], json.dumps(res["S6_client_" + sc])[:600], flush=True)
    ok, n, bad = d.console(os.path.join(OUT, "b-play-console.txt"))
    res["consoleSuspect"] = [b[:200] for b in bad][:12]
    d.play(False)
    res["backToEdit"] = d.wait_state("edit", 40)[0]
    save("b-play.json", res)
    print("console suspect", res["consoleSuspect"], "edit", res["backToEdit"])


def inst(s, sid):
    x = Drv.__new__(Drv)
    x.s, x.sid = s, sid
    return x


def windows(pid):
    r = subprocess.run(["osascript", "-e", 'tell application "System Events" to get name of every window of (first process whose unix id is %s)' % pid], capture_output=True, text=True)
    return r.stdout.strip()


SETLAG = 'local ok, e = pcall(function() settings().Network.IncomingReplicationLag = %s end) return tostring(ok) .. " " .. tostring(e) .. " now=" .. tostring(settings().Network.IncomingReplicationLag)'


def mp(d, s):
    res = {"memBefore": studio_mem(), "editLagBefore": d.lua("Edit", "return settings().Network.IncomingReplicationLag")[1]}
    before = set(subprocess.run(["pgrep", "-x", "RobloxStudio"], capture_output=True, text=True).stdout.split())
    known = {x["id"] for x in d.studios}
    d.lua("Edit", 'task.spawn(function() game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2, {}) end) return 1')
    roles, t0 = {}, time.time()
    while time.time() - t0 < 90 and len(roles) < 3:
        time.sleep(3)
        for x in json.loads(s.call("list_roblox_studios", {})[1][0])["studios"]:
            if x["id"] in known or x["id"] in roles.values():
                continue
            o = inst(s, x["id"])
            for dm in ("Server", "Client"):
                ok, text = o.lua(dm, 'local p = game:GetService("Players").LocalPlayer local rs = game:GetService("ReplicatedStorage") return (game:GetService("RunService"):IsServer() and "SERVER" or ("CLIENT " .. tostring(p and p.Name))) .. " ready=" .. tostring(rs:FindFirstChild("SpikeBResults") ~= nil or rs:FindFirstChild("SpikeBClientState") ~= nil)', 20)
                if ok and "ready=true" in text:
                    roles["server" if "SERVER" in text else text.split()[1]] = x["id"]
                    break
    res["roles"], res["startS"] = dict(roles), round(time.time() - t0, 1)
    new = [p for p in subprocess.run(["pgrep", "-x", "RobloxStudio"], capture_output=True, text=True).stdout.split() if p not in before]
    res["newPids"] = new
    res["windows"] = {p: windows(p) for p in new}
    print("roles", roles, res["windows"], flush=True)
    srv, p1, p2 = inst(s, roles.get("server")), inst(s, roles.get("Player1")), inst(s, roles.get("Player2"))
    try:
        time.sleep(4)
        res["memMp"] = studio_mem()
        obs_pid = next((p for p, w in res["windows"].items() if "Player2" in w), None)
        for li, lag in enumerate(LAGS):
            tag = "%d_%s" % (li, lag.replace(".", ""))
            row = {"set": {k: o.lua(dm, SETLAG % lag)[1] for k, o, dm in (("server", srv, "Server"), ("p1", p1, "Client"), ("p2", p2, "Client"))}}
            for nm, o in (("p1", p1), ("p2", p2)):
                o.lua("Client", 'game:GetService("ReplicatedStorage").SpikeBClientState.Cmd:Fire("rtt", "%s") return 1' % tag)
            time.sleep(4)
            row["rttP1"] = p1.attrs("Client", "SpikeBClientState").get("rtt_" + tag)
            row["rttP2"] = p2.attrs("Client", "SpikeBClientState").get("rtt_" + tag)
            if obs_pid:
                front(obs_pid)
            p2.lua("Client", 'game:GetService("ReplicatedStorage").SpikeBClientState.Cmd:Fire("observe", 20, "%s") return 1' % tag)
            p1.lua("Client", 'game:GetService("ReplicatedStorage").SpikeBClientState.Cmd:Fire("drive", 21, 10) return 1')
            row["S3"] = wait_attr(p2, "Client", "SpikeBClientState", "S3_" + tag, 40).get("S3_" + tag)
            print(lag, "S3", json.dumps(row["S3"])[:700], flush=True)
            # S4 while Player1 swims the circle
            p1.lua("Client", 'local c = game:GetService("ReplicatedStorage").SpikeBClientState.Cmd c:Fire("s4reset") c:Fire("drive", 14, 99) return 1')
            srv.lua("Server", 'game:GetService("ReplicatedStorage").SpikeBResults:SetAttribute("cmd", "s4lag:%s") return 1' % tag)
            a = wait_attr(srv, "Server", "SpikeBResults", "done_s4lag_" + tag, 40, 2)
            row["S4server"], row["S4err"] = a.get("S4lag_server_" + tag), a.get("error_s4lag")
            p1.lua("Client", 'game:GetService("ReplicatedStorage").SpikeBClientState.Cmd:Fire("s4report", "%s") return 1' % tag)
            time.sleep(1)
            a1 = p1.attrs("Client", "SpikeBClientState")
            row["S4client"], row["drive"] = a1.get("S4_" + tag), a1.get("drive")
            print(lag, "S4", json.dumps(row["S4server"]), json.dumps(row["S4client"])[:500], flush=True)
            res["lag_" + tag] = row
            save(MPOUT, res)
        # S7 size sweep to Player1 at the last lag setting
        if not SWEEP:
            return
        srv.lua("Server", 'game:GetService("ReplicatedStorage").SpikeBResults:SetAttribute("cmd", "s7:sweep") return 1')
        a = wait_attr(srv, "Server", "SpikeBResults", "done_s7_sweep", 60, 3)
        res["S7sweep_server"] = a.get("S7sweep_server")
        time.sleep(1)
        res["S7sweep_client"] = p1.attrs("Client", "SpikeBClientState").get("S7")
        print("sweep", json.dumps(res["S7sweep_client"])[:900], flush=True)
    finally:
        res["lagReset"] = {k: o.lua(dm, SETLAG % "0")[1] for k, o, dm in (("server", srv, "Server"), ("p1", p1, "Client"), ("p2", p2, "Client")) if o.sid}
        res["end"] = srv.lua("Server", 'game:GetService("StudioTestService"):EndTest("spike-b done") return "ended"', 30)[1] if srv.sid else "no server"
        time.sleep(8)
        res["pidsAfterEndTest"] = subprocess.run(["pgrep", "-x", "RobloxStudio"], capture_output=True, text=True).stdout.split()
        left = [p for p in subprocess.run(["pgrep", "-x", "RobloxStudio"], capture_output=True, text=True).stdout.split() if p not in before]
        res["leftover"] = left
        for p in left:  # started by this test under our lock
            subprocess.run(["kill", p])
        res["editLagAfter"] = d.lua("Edit", "return settings().Network.IncomingReplicationLag")[1]
        res["memAfter"] = studio_mem()
        save(MPOUT, res)
        print("end", res["end"], "leftover", left, "editLag", res["editLagBefore"], res["editLagAfter"])


def s12(s):
    st = json.loads(s.call("list_roblox_studios", {})[1][0])["studios"]
    mine = [x for x in st if x["name"] and "gulp-spike-s12" in x["name"]]
    if not mine:
        sys.exit("s12 place not open: %s" % [x["name"] for x in st])
    d = inst(s, mine[0]["id"])
    res = {"studio": mine[0]["name"]}
    ATTR = 'local ok, e = pcall(function() workspace:SetAttribute("SpikeAttrProbe", string.rep("a", 60)) end) workspace:SetAttribute("SpikeAttrProbe", nil) return "attr60 ok=" .. tostring(ok) .. " " .. tostring(e)'
    res["attr60_s12Edit"] = d.lua("Edit", ATTR)[1]
    ctrl = [x for x in st if x["name"] and "TestBench-gulp-spike.rbxl" in x["name"]]
    if ctrl:
        res["attr60_normalEdit"] = inst(s, ctrl[0]["id"]).lua("Edit", ATTR)[1]
    print(res, flush=True)
    d.play(True)
    ok, _, a = d.wait_attr("Server", "SpikeResults", ["S1_server", "S1_client"], 45)
    res["ready"] = ok
    time.sleep(2)
    res["authorityServer"] = d.attrs("Server", "SpikeBResults").get("S12_authorityMode")
    for lag in ("0", "0.1"):
        res["lagSet_" + lag] = d.lua("Server", SETLAG % lag)[1], d.lua("Client", SETLAG % lag)[1]
        d.lua("Client", 'game:GetService("ReplicatedStorage").SpikeBClientState.Cmd:Fire("s12", 12) return 1')
        d.lua("Server", 'game:GetService("ReplicatedStorage").SpikeBResults:SetAttribute("cmd", "s12:12") return 1')
        a = wait_attr(d, "Server", "SpikeBResults", "done_s12_12", 40, 2)
        res["server_" + lag], res["err_" + lag] = a.get("S12_server"), a.get("error_s12")
        time.sleep(1)
        res["client_" + lag] = d.attrs("Client", "SpikeBClientState").get("S12_client")
        d.lua("Server", 'game:GetService("ReplicatedStorage").SpikeBResults:SetAttribute("done_s12_12", nil) return 1')
        print(lag, json.dumps(res["server_" + lag]), json.dumps(res["client_" + lag]), flush=True)
    res["lagReset"] = d.lua("Server", SETLAG % "0")[1], d.lua("Client", SETLAG % "0")[1]
    ok, n, bad = d.console(os.path.join(OUT, "b-s12-console.txt"))
    res["consoleSuspect"] = [b[:240] for b in bad][:10]
    d.play(False)
    res["backToEdit"] = d.wait_state("edit", 40)[0]
    save("b-s12.json", res)
    print(json.dumps({k: v for k, v in res.items() if not k.startswith(("server_", "client_"))})[:1500])


STUDIO_PID = None
MPOUT = "b-mp-%s.json" % time.strftime("%H%M")
LAGS = (sys.argv[2] if len(sys.argv) > 2 else "0,0.1,0.2").split(",")
SWEEP = "--sweep" in sys.argv
if __name__ == "__main__":
    mode = sys.argv[1]
    with StudioSession() as s:
        if mode == "s12":
            s12(s)
            sys.exit(0)
        d = Drv(s)
        try:
            if mode == "probe":
                probe(d)
            elif mode == "sync":
                sync(d)
            elif mode == "play":
                STUDIO_PID = spike_pid()
                play(d)
            elif mode == "mp":
                mp(d, s)
        finally:
            st = d.state()
            if "Current Studio Mode: Edit" not in st and mode in ("play",):
                d.play(False)
                d.wait_state("edit", 30)
