#!/usr/bin/env python3
"""Clip JSON -> Roblox KeyframeSequence (.rbxmx), and the rig's socket table: the click-free
animation route proven in Sprint 0 (docs/spike-report.md F20, spike/results/tech-d.md item 1).
Plain Python with numpy: imported by clips.py and export.py inside Blender, and runnable alone.

    python3 animrbx.py build <clip.json> <out.rbxmx> [--rig <bones.json>] [--root RootPart]
    python3 animrbx.py check <clip.json> <bones.json>          rest fit of a Studio-imported rig

The route: clips.dump_json writes per bone its parent, armature-space rest matrix and, per frame,
its local transform (matrix_basis: location and quaternion w, x, y, z). This file turns that into
a KeyframeSequence (Keyframe -> Pose RootPart, weight 0 -> one Pose per bone, nested like the
bones); assets/source/_shared/luau/xml2rbxm.luau (Lune) writes the binary .rbxm that Open Cloud
takes for Animation assets, and reads it back so the pose names can be checked against the rig.

The maths (spike part D, measured to 0.0001 studs in Studio): Roblox bone world W = A * B * G,
with A the axis change of the FBX import, Roblox (x, y, z) = Blender (-x, z, y), B the Blender
rest matrix and G the same fixed turn for every bone, 180 degrees about the bone's own Y axis.
So Pose.CFrame = G^-1 * matrix_basis * G (rotation and translation). With a bones.json dumped
from a Studio import (luau/dump_bones.luau) A and every G are fitted instead (Kabsch on the rest
heads) and the residual is reported; without one the measured constants above are used.
"""
import json
import sys
from xml.sax.saxutils import escape

import numpy as np

A = np.array([[-1.0, 0.0, 0.0], [0.0, 0.0, 1.0], [0.0, 1.0, 0.0]])    # Roblox = A @ Blender
G = np.diag([-1.0, 1.0, -1.0])                                          # 180 degrees about Y
PRIORITY = {"Idle": 0, "Movement": 1, "Action": 2, "Core": 1000}
CF_KEYS = ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]


def q2m(q):
    w, x, y, z = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def components(m):
    """A 4 x 4 matrix as the 12 numbers of CFrame.new(x, y, z, R00 ... R22) (GetComponents order)."""
    return [float(v) for v in m[:3, 3]] + [float(v) for v in m[:3, :3].reshape(-1)]


def roblox_rest(bones):
    """Predicted Roblox rest frame (4 x 4, in the RootPart's space up to one shared offset) of every
    bone of {name: {"rest": 4 x 4 armature-space matrix}}: A * B * G."""
    out = {}
    for name, b in bones.items():
        rest = np.array(b["rest"])
        m = np.eye(4)
        m[:3, :3] = A @ rest[:3, :3] @ G
        m[:3, 3] = A @ rest[:3, 3]
        out[name] = m
    return out


def _cf(c):
    m = np.eye(4)
    m[:3, 3] = c[:3]
    m[:3, :3] = np.array(c[3:]).reshape(3, 3)
    return m


def fit_rig(clip, rig):
    """Fits A and each bone's G from a Studio-imported rig (luau/dump_bones.luau). Returns
    ({bone: G}, max head residual in studs, root part name)."""
    by = {b["name"]: b for b in rig["bones"]}
    world = {}

    def w(n):
        if n not in world:
            b = by[n]
            world[n] = (w(b["parent"]) if b["parent"] in by else np.eye(4)) @ _cf(b["cf"])
        return world[n]

    names = [n for n in by if n in clip["bones"]]
    P = np.array([np.array(clip["bones"][n]["rest"])[:3, 3] for n in names])
    Q = np.array([w(n)[:3, 3] for n in names])
    pc, qc = P.mean(0), Q.mean(0)
    U, _, Vt = np.linalg.svd((P - pc).T @ (Q - qc))
    D = np.diag([1.0, 1.0, np.sign(np.linalg.det(Vt.T @ U.T))])
    R = Vt.T @ D @ U.T
    res = float(np.linalg.norm((P - pc) @ R.T + qc - Q, axis=1).max())
    gs = {n: np.array(clip["bones"][n]["rest"])[:3, :3].T @ R.T @ w(n)[:3, :3] for n in names}
    root = next(b["parent"] for b in rig["bones"] if b["parent"] not in by)
    return gs, res, root


def pose_cframe(frame, g):
    """Bone.Transform for one frame {"loc", "q"} of a bone whose axis change is g."""
    t = np.eye(4)
    t[:3, :3] = g.T @ q2m(frame["q"]) @ g
    t[:3, 3] = g.T @ np.array(frame["loc"])
    return t


def kfs_xml(clip, bones=None, gs=None, root="RootPart", priority=None):
    """The KeyframeSequence as .rbxmx text. `bones`: the bone names to pose (default: the clip's
    deform bones; socket bones are weightless and never reach Roblox). One Keyframe per frame,
    linear (every frame is keyed, 06 6.7)."""
    names = [n for n, b in clip["bones"].items() if (bones is None and b.get("deform", True)) or (bones and n in bones)]
    gs = gs or {n: G for n in names}
    kids = {}
    for n in names:
        parent = clip["bones"][n]["parent"]
        kids.setdefault(parent if parent in names else None, []).append(n)
    ref = [0]

    def item(cls, props, children=""):
        ref[0] += 1
        return '<Item class="%s" referent="RBX%d"><Properties>%s</Properties>%s</Item>' % (cls, ref[0], props, children)

    def pose(n, f):
        cfx = "".join("<%s>%.7f</%s>" % (k, v, k) for k, v in zip(CF_KEYS, components(pose_cframe(clip["bones"][n]["frames"][f], gs[n]))))
        props = ('<string name="Name">%s</string><CoordinateFrame name="CFrame">%s</CoordinateFrame><float name="Weight">1</float>'
                 '<token name="EasingStyle">0</token><token name="EasingDirection">0</token>') % (escape(n), cfx)
        return item("Pose", props, "".join(pose(c, f) for c in kids.get(n, [])))

    fps, count = clip["fps"], clip["end"] - clip["start"] + 1
    keyframes = ""
    for f in range(count):
        rp = ('<string name="Name">%s</string><float name="Weight">0</float><token name="EasingStyle">0</token>'
              '<token name="EasingDirection">0</token>') % escape(root)
        keyframes += item("Keyframe", '<string name="Name">F%02d</string><float name="Time">%.6f</float>' % (f, f / float(fps)),
                          item("Pose", rp, "".join(pose(c, f) for c in kids.get(None, []))))
    prio = priority or ("Idle" if "Idle" in clip["clip"] else "Movement" if clip.get("loop") else "Action")
    top = item("KeyframeSequence", '<string name="Name">%s</string><bool name="Loop">%s</bool><token name="Priority">%d</token>'
               % (escape(clip["clip"]), "true" if clip.get("loop") else "false", PRIORITY[prio]), keyframes)
    return '<roblox version="4">%s</roblox>' % top, names, prio


def socket_table(bones):
    """The rig's socket table (06 8.4: sockets stay weightless; code builds them): for every Sock_
    bone of {name: {"parent", "rest"}}, its parent bone and its offset from that bone's rest frame
    in Roblox axes, as CFrame components and as position plus the socket's outward axis (+Y)."""
    rb = roblox_rest(bones)
    out = []
    for name in sorted(n for n in bones if n.startswith("Sock_")):
        parent = bones[name]["parent"]
        rel = np.linalg.inv(rb[parent]) @ rb[name]
        out.append({"name": name, "parent": parent, "cframe": [round(v, 6) for v in components(rel)],
                    "position": [round(float(v), 6) for v in rel[:3, 3]], "axis": [round(float(v), 6) for v in rel[:3, 1]]})
    return out


def main(argv):
    clip = json.load(open(argv[1]))
    if argv[0] == "build":
        rig = json.load(open(argv[argv.index("--rig") + 1])) if "--rig" in argv else None
        root = argv[argv.index("--root") + 1] if "--root" in argv else "RootPart"
        gs = None
        if rig:
            gs, res, root = fit_rig(clip, rig)
            print("rest fit on the imported rig: max head residual %.5f studs" % res)
        xml, names, prio = kfs_xml(clip, gs=gs, root=root, bones=list(gs) if gs else None)
        with open(argv[2], "w") as fh:
            fh.write(xml)
        print("wrote %s: %d keyframes, %d bones, priority %s" % (argv[2], clip["end"] - clip["start"] + 1, len(names), prio))
    elif argv[0] == "check":
        gs, res, root = fit_rig(clip, json.load(open(argv[2])))
        worst = max(float(np.abs(g - G).max()) for g in gs.values())
        print(json.dumps({"root": root, "head_residual": round(res, 6), "bones": len(gs), "max_G_diff_from_constant": round(worst, 6)}))
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
