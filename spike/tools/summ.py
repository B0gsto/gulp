#!/usr/bin/env python3
"""Prints a compact summary of spike/out/main.json (pass a file name to read another run)."""
import json, os, sys
r = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "out", sys.argv[1] if len(sys.argv) > 1 else "main.json")))
a = r.get("results") or {}
f = lambda v: round(v, 4) if isinstance(v, float) else v
print("S14 server:", {k: ([f(x) for x in v] if isinstance(v, list) else f(v)) for k, v in a["S14_server"].items()})
for s in a["S14_client"]["samples"]:
    print("  S14 client:", {k: f(v) for k, v in s.items()})
print("S2: tier scale diam | fps mean p50 p95 p99 max(ms) n | velFrames posFrames | target max cruise t90 | headErr stopSpeed | sizeDelay rigScale ok ext | serverMass")
for t in range(1, 8):
    x, sv = a["S2_t%d" % t], a["S2_server_t%d" % t]
    fr = x["frame"]
    print("  ", t, x["scale"], f(x["rootDiameter"]), "|", round(fr["fps"], 1), round(fr["meanMs"], 2), round(fr["p50Ms"], 2), round(fr["p95Ms"], 2), round(fr["p99Ms"], 2), round(fr["maxMs"], 2), fr["n"],
          "|", x["physicsVelocityFramesAfterInput"], x["positionChangedFramesAfterInput"], "|", x["targetSpeed"], round(x["maxSpeed"], 2), round(x["cruiseSpeed"], 2), f(x["timeTo90pct"]),
          "|", round(x["headingErrDegAfterTurn"], 2), round(x["speedAfterStop07"], 3), "|", round(x["sizeReplicationDelay"], 3), round(x["rigScale"], 3), x["rigScaleToOk"], [round(e, 1) for e in x["rigExtents"]], "|", round(sv["mass"], 1),
          "| bursts(rest:vel/pos)", " ".join("%s:%s/%s" % (b["rest"], b["vel"], b["pos"]) for b in x.get("bursts", [])))
print("S4 writes:")
for row in a["S4_write"]:
    print("  ", {k: f(v) for k, v in row.items()})
print("S4 freeze:", json.dumps(a["S4_freeze"])[:600])
print("S5 join:", json.dumps(a["S5_join"])[:300])
print("S5 client:", json.dumps(a["S5_client"])[:1200])
print("S5 server:", json.dumps(a["S5_server"])[:600])
print("S1 client:", json.dumps(a["S1_client"])[:700])
for k in ("ready", "sequenceDone", "S10_coreGuiDrawn", "S10_client", "S9", "console", "S16", "backToEdit"):
    print(k + ":", json.dumps(r.get(k))[:1500])
