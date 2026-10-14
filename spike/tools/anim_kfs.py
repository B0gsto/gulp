#!/usr/bin/env python3
"""Spike part D (S0-A2/S8): Blender clip JSON -> KeyframeSequence .rbxmx, with no Studio click.
  anim_kfs.py build <clip.json> <rig.bones.json> <out.rbxmx>    (rig.bones.json from luau/dump_bones.luau)
  anim_kfs.py check <clip.json> <rig.bones.json> <studio.json>  compare Studio bone positions with Blender
Maths: Roblox bone world W = A*K*Wblender*G_b, with A*K one rotation fitted (Kabsch) on rest head positions and
G_b the fixed per-bone axis change. Then Bone.Transform = G_b^-1 * matrix_basis * G_b (rotation and translation)."""
import json, sys
import numpy as np
from xml.sax.saxutils import escape


def cf(c):  # Roblox GetComponents -> 4x4
    m = np.eye(4)
    m[:3, 3] = c[:3]
    m[:3, :3] = np.array(c[3:]).reshape(3, 3)
    return m


def q2m(q):
    w, x, y, z = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def rig_rest(rig):
    """World rest frames of every bone, relative to the part holding the bone tree."""
    by = {b["name"]: b for b in rig["bones"]}
    W = {}
    def w(n):
        if n not in W:
            b = by[n]
            W[n] = (w(b["parent"]) if b["parent"] in by else np.eye(4)) @ cf(b["cf"])
        return W[n]
    for n in by:
        w(n)
    return by, W


def fit(clip, rig):
    by, W = rig_rest(rig)
    names = [n for n in by if n in clip["bones"]]
    P = np.array([np.array(clip["bones"][n]["rest"])[:3, 3] for n in names])   # armature space (head = rest translation)
    Q = np.array([W[n][:3, 3] for n in names])
    pc, qc = P.mean(0), Q.mean(0)
    U, _, Vt = np.linalg.svd((P - pc).T @ (Q - qc))
    D = np.diag([1, 1, np.sign(np.linalg.det(Vt.T @ U.T))])
    R = Vt.T @ D @ U.T                          # rbx = R @ blender + t
    t = qc - R @ pc
    res = np.linalg.norm((P @ R.T + t) - Q, axis=1).max()
    G = {n: np.array(clip["bones"][n]["rest"])[:3, :3].T @ R.T @ W[n][:3, :3] for n in names}
    return by, W, names, R, t, res, G


def comps(m):
    p, r = m[:3, 3], m[:3, :3]
    return list(p) + list(r.reshape(-1))


def build(clip, rig, path):
    by, W, names, R, t, res, G = fit(clip, rig)
    print("rest fit: max head residual %.5f studs; A*K =" % res, np.round(R, 3).tolist())
    print("G_b distinct:", sorted({str(np.round(g, 2).tolist()) for g in G.values()})[:3])
    root = next(b["parent"] for b in rig["bones"] if b["parent"] not in by)
    kids = {}
    for n in names:
        kids.setdefault(by[n]["parent"], []).append(n)
    fps, nf = clip["fps"], clip["end"] - clip["start"] + 1
    ref = [0]
    def item(cls, props, children=""):
        ref[0] += 1
        return '<Item class="%s" referent="RBX%d"><Properties>%s</Properties>%s</Item>' % (cls, ref[0], props, children)
    def pose(n, f):
        b = clip["bones"][n]["frames"][f]
        T = np.eye(4)
        T[:3, :3] = G[n].T @ q2m(b["q"]) @ G[n]
        T[:3, 3] = G[n].T @ np.array(b["loc"])
        c = comps(T)
        cfx = "".join("<%s>%.7f</%s>" % (k, v, k) for k, v in zip(["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"], c))
        props = ('<string name="Name">%s</string><CoordinateFrame name="CFrame">%s</CoordinateFrame><float name="Weight">1</float>'
                 '<token name="EasingStyle">0</token><token name="EasingDirection">0</token>') % (escape(n), cfx)
        return item("Pose", props, "".join(pose(c, f) for c in kids.get(n, [])))
    kfs = ""
    for f in range(nf):
        rp = ('<string name="Name">%s</string><float name="Weight">0</float><token name="EasingStyle">0</token>'
              '<token name="EasingDirection">0</token>') % escape(root)
        kfs += item("Keyframe", '<string name="Name">F%02d</string><float name="Time">%.6f</float>' % (f, f / fps),
                    item("Pose", rp, "".join(pose(c, f) for c in kids.get(root, []))))
    top = item("KeyframeSequence", '<string name="Name">%s</string><bool name="Loop">true</bool><token name="Priority">1</token>' % clip["clip"], kfs)
    with open(path, "w") as fh:
        fh.write('<roblox version="4">%s</roblox>' % top)
    print("wrote", path, "keyframes", nf, "bones", len(names), "root pose", root)


def check(clip, rig, studio):
    """studio: {frame: {bone: [x,y,z] relative to the bone-tree part}}. Returns max error per frame."""
    by, W, names, R, t, res, G = fit(clip, rig)
    out = {}
    for f, bones in studio.items():
        errs = {n: float(np.linalg.norm(R @ np.array(clip["bones"][n]["frames"][int(f)]["head"]) + t - np.array(p)))
                for n, p in bones.items() if n in names}
        moved = max(float(np.linalg.norm(np.array(clip["bones"][n]["frames"][int(f)]["head"]) - np.array(clip["bones"][n]["rest"])[:3, 3])) for n in errs)
        worst = max(errs, key=errs.get)
        out[f] = {"maxErr": round(errs[worst], 4), "worst": worst, "meanErr": round(sum(errs.values()) / len(errs), 4), "bones": len(errs), "maxBlenderMove": round(moved, 3)}
    return out


if __name__ == "__main__":
    clip, rig = json.load(open(sys.argv[2])), json.load(open(sys.argv[3]))
    if sys.argv[1] == "build":
        build(clip, rig, sys.argv[4])
    else:
        print(json.dumps(check(clip, rig, json.load(open(sys.argv[4])))))
