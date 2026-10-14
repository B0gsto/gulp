#!/usr/bin/env python3
"""S15, second half: can a two-client test be started through MCP? start_stop_play has no client-count argument, so
this tries StudioTestService:ExecuteMultiplayerTestAsync from execute_luau (Edit). Run under spike/tools/held.sh.
  mp_probe.py sig                 call with no arguments and print the error (reveals the signature)
  mp_probe.py run '<lua args>'    call with the given Luau argument list, watch for 25 s, then stop and clean up
"""
import json, os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from drive import Drv, StudioSession, save  # noqa: E402


def pids():
    out = subprocess.run(["pgrep", "-x", "RobloxStudio"], capture_output=True, text=True).stdout.split()
    return sorted(int(p) for p in out)


def rss_mb(pid_list):
    tot = 0
    for p in pid_list:
        o = subprocess.run(["ps", "-o", "rss=", "-p", str(p)], capture_output=True, text=True).stdout.strip()
        tot += int(o or 0)
    return round(tot / 1024)


mode = sys.argv[1]
with StudioSession() as s:
    d = Drv(s)
    before = pids()
    res = {"mode": mode, "pidsBefore": before, "rssBeforeMb": rss_mb(before)}
    if mode == "sig":
        res["noArgs"] = d.lua("Edit", 'local ok, e = pcall(function() return game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync() end) return tostring(ok) .. " | " .. tostring(e)', 30)
        time.sleep(3)
    else:
        args = sys.argv[2]
        res["args"] = args
        res["call"] = d.lua("Edit", 'task.spawn(function() local ok, e = pcall(function() return game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(%s) end) print("[SPIKE] MP_RESULT " .. tostring(ok) .. " | " .. tostring(e)) end) return "spawned"' % args, 30)
        res["timeline"] = []
        for i in range(9):
            time.sleep(3)
            now = pids()
            res["timeline"].append({"t": (i + 1) * 3, "studios": [x["name"] for x in json.loads(s.call("list_roblox_studios", {})[1][0])["studios"]],
                                    "state": d.state().replace("\n", " ; ")[:160], "newPids": [p for p in now if p not in before], "rssAllMb": rss_mb(now)})
        res["playersSeenByServer"] = d.lua("Server", 'local n = {} for _, p in game:GetService("Players"):GetPlayers() do table.insert(n, p.Name) end return #n .. " " .. table.concat(n, ",")', 20)
    res["stateAfter"] = d.state().replace("\n", " ; ")
    if "Current Studio Mode: Edit" not in res["stateAfter"]:
        res["stop"] = [d.play(False)[0], d.wait_state("edit", 30)[0]]
    time.sleep(4)
    left = [p for p in pids() if p not in before]
    res["leftoverPidsAfterStop"] = left
    if left:  # processes this test started under our lock and that the stop did not end
        time.sleep(8)
        left = [p for p in pids() if p not in before]
        for p in left:
            subprocess.run(["kill", str(p)])
        res["killedLeftover"] = left
    res["consoleTail"] = [l for l in "\n".join(d.call("get_console_output")[1]).splitlines() if "MP_RESULT" in l or "Multiplayer" in l][-4:]
    res["finalState"] = d.state().replace("\n", " ; ")
    save("mp-%s.json" % mode, res)
    print(json.dumps(res, indent=1)[:3000])
