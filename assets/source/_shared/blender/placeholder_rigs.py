"""Placeholder skeletons and procedural clips (docs/07-asset-list.md section 16) for the slice
rows that rigs.py does not cover yet: RIG_Barracuda (07 section 7: "longer spine than the Fish
family, jaw, eyes, fins", 12 bones, 06 section 6.3) and the Pearl Clam's two bones (07: "Two
bones"; the clip is A_PearlClam_Open). The slice's two species, Minnow and Pufferfish, are both
in the Fish family (06 section 3.1), so RIG_Fish from rigs.py carries every species clip.

Bone names and joint positions here are this tool's first fit, open to the rig review, exactly
like rigs.py. Clips are 07 section 16's "procedural moves of the right length": stretch for dash,
jaw flap for bite, spin for tier-up, shrink for gulped; the rest are a swim wave, a bob or a
wobble. Only bone location and rotation are keyed (Roblox bones take no scale), so "shrink" is
the body folding into the head with the girth pinched.
"""
import math

import budgets
import meshgen

# Skeletons this file adds to budgets.FAMILIES (registered at import; validate.check_rig reads it).
EXTRA_FAMILIES = {
    "Barracuda": {"deform": ["Root", "Spine1", "Spine2", "Spine3", "Spine4", "Spine5", "TailFin", "Jaw",
                             "Eye_L", "Eye_R", "Pec_L", "Pec_R"], "sockets": []},
    "PearlClam": {"deform": ["Root", "Shell", "Lid"], "sockets": []},
}


def register():
    for fam, bones in EXTRA_FAMILIES.items():
        budgets.FAMILIES.setdefault(fam, bones)
        budgets.FAMILY_DEFORM_COUNT.setdefault(fam, len(bones["deform"]))


register()

BARRACUDA_STATIONS = (("Spine1", -0.38), ("Spine2", -0.2), ("Spine3", 0.0), ("Spine4", 0.15), ("Spine5", 0.3),
                      ("TailFin", 0.42))       # share of body length along +Y (front is -Y)


def barracuda_bones(L, H, W):
    st = dict(BARRACUDA_STATIONS)
    deform = [("Root", (0.0, 0.0, 0.0), None), ("Spine3", (0.0, 0.0, 0.0), "Root"),
              ("Spine2", (0.0, st["Spine2"] * L, 0.0), "Spine3"), ("Spine1", (0.0, st["Spine1"] * L, 0.0), "Spine2"),
              ("Spine4", (0.0, st["Spine4"] * L, 0.0), "Spine3"), ("Spine5", (0.0, st["Spine5"] * L, 0.0), "Spine4"),
              ("TailFin", (0.0, st["TailFin"] * L, 0.0), "Spine5"), ("Jaw", (0.0, -0.42 * L, -0.12 * H), "Spine1"),
              ("Eye_L", (0.12 * W, -0.36 * L, 0.08 * H), "Spine1"), ("Eye_R", (-0.12 * W, -0.36 * L, 0.08 * H), "Spine1"),
              ("Pec_L", (0.25 * W, -0.22 * L, -0.15 * H), "Spine2"), ("Pec_R", (-0.25 * W, -0.22 * L, -0.15 * H), "Spine2")]
    return [{"name": n, "head": h, "parent": p, "deform": True} for n, h, p in deform]


def barracuda_weights(L, H):
    """Linear blend between the two nearest spine stations; the jaw takes the lower front."""
    def weights(p, q=None):
        y = p[1] / L
        names = [n for n, _ in BARRACUDA_STATIONS]
        ys = [s for _, s in BARRACUDA_STATIONS]
        if y <= ys[0]:
            w = {names[0]: 1.0}
        elif y >= ys[-1]:
            w = {names[-1]: 1.0}
        else:
            i = max(j for j in range(len(ys)) if ys[j] <= y)
            t = (y - ys[i]) / (ys[i + 1] - ys[i])
            w = {names[i]: 1.0 - t, names[i + 1]: t}
        if y < -0.36 and p[2] < 0.0:
            w = {"Jaw": 1.0}
        return w
    return weights


def clam_bones(L, hinge_z):
    return [{"name": "Root", "head": (0.0, 0.0, 0.0), "parent": None, "deform": True},
            {"name": "Shell", "head": (0.0, 0.0, 0.0), "parent": "Root", "deform": True},
            {"name": "Lid", "head": (0.0, 0.5 * L, hinge_z), "parent": "Shell", "deform": True}]


# ---------------------------------------------------------------- procedural clips

def clip_length(row):
    """Frames and loop flag from the row's length cell: `loop 16 frames`, `7 to 9 frames` (the mean)."""
    import re
    for key, value in row.items():
        if not isinstance(value, str) or key in ("names", "section", "Description"):
            continue
        m = re.search(r"(\d+)(?:\s*to\s*(\d+))?\s*frames", value)
        if m:
            lo = int(m.group(1))
            hi = int(m.group(2)) if m.group(2) else lo
            return int(round((lo + hi) / 2.0)), "loop" in value.lower()
    return None, False


CHAINS = {"Fish": ("Spine1", ("Spine3", "Spine4", "TailFin")), "Barracuda": ("Spine1", ("Spine4", "Spine5", "TailFin"))}


def _env(t):
    return math.sin(math.pi * max(0.0, min(1.0, t)))


def _merge(*poses):
    out = {}
    for pose in poses:
        for bone, tr in pose.items():
            cur = out.setdefault(bone, {"loc": (0.0, 0.0, 0.0), "rot": (0.0, 0.0, 0.0)})
            cur["loc"] = tuple(a + b for a, b in zip(cur["loc"], tr.get("loc", (0.0, 0.0, 0.0))))
            cur["rot"] = tuple(a + b for a, b in zip(cur["rot"], tr.get("rot", (0.0, 0.0, 0.0))))
    return out


def clip_pose(action, rig, k, bones, owner=""):
    """pose_at(t) for t in 0..1, by the action name. k is a third of the body length; owner is the
    clip's <Rig> word (the Minnow's fidget chases its tail, the Pufferfish's hiccups)."""
    head, tail = CHAINS.get(rig, ("Spine1", ()))
    girth = [b for b in ("Girth_Top", "Girth_Bot", "Girth_L", "Girth_R") if b in bones]
    gdir = {"Girth_Top": (0, 0, 1), "Girth_Bot": (0, 0, -1), "Girth_L": (1, 0, 0), "Girth_R": (-1, 0, 0)}

    def wave(t, amp, cycles=1):
        a = 2.0 * math.pi * t * cycles
        out = {b: {"rot": (0.0, 0.0, amp * (6.0 + 6.0 * i) * math.sin(a - 0.9 * (i + 1)))} for i, b in enumerate(tail)}
        out[head] = {"rot": (0.0, 0.0, -amp * 1.5 * math.sin(a))}
        return out

    def stretch(e):
        out = {head: {"loc": (0.0, -0.35 * k * e, 0.0)}}
        for i, b in enumerate(tail):
            out[b] = {"loc": (0.0, (0.06 + 0.04 * i) * k * e, 0.0)}
        for g in girth:
            out[g] = {"loc": tuple(-0.05 * k * e * c for c in gdir[g])}
        for side, s in (("Pec_L", 1), ("Pec_R", -1)):
            if side in bones:
                out[side] = {"rot": (0.0, 0.0, s * 22.0 * e)}
        return out

    def squash(e):     # e > 0 shortens and fattens the body
        out = {head: {"loc": (0.0, 0.2 * k * e, 0.0)}}
        if tail:
            out[tail[-1]] = {"loc": (0.0, -0.2 * k * e, 0.0)}
        for g in girth:
            out[g] = {"loc": tuple(0.06 * k * e * c for c in gdir[g])}
        return out

    def jaw(e, lunge=0.36):
        out = {head: {"loc": (0.0, -lunge * k * e, 0.0)}}
        if "Jaw" in bones:
            out["Jaw"] = {"rot": (52.0 * e, 0.0, 0.0)}
        for g in girth:
            out[g] = {"loc": tuple(0.04 * k * e * c for c in gdir[g])}
        return out

    def flutter(t, cycles, amp=25.0):
        s = amp * math.sin(2.0 * math.pi * t * cycles)
        return {b: {"rot": (0.0, sg * s, 0.0)} for b, sg in (("Pec_L", 1), ("Pec_R", -1)) if b in bones}

    def bob(t, amp=0.06):
        return {"Root": {"loc": (0.0, 0.0, amp * k * math.sin(2.0 * math.pi * t))}}

    if action == "Open":                        # A_PearlClam_Open: the lid pops up, overshoots, settles
        return lambda t: {"Lid": {"rot": (-60.0 * min(1.0, t / 0.4) - 10.0 * _env((t - 0.4) / 0.6), 0.0, 0.0)}}
    table = {
        "Swim": lambda t: _merge(wave(t, 1.0), flutter(t, 2, 12.0)),
        "SwimFast": lambda t: _merge(wave(t, 1.6), stretch(0.3)),
        "Idle": lambda t: _merge(wave(t, 0.2), bob(t), flutter(t, 3)),
        "FinWhir": lambda t: _merge(flutter(t, 1, 35.0), wave(t, 0.1)),
        "PuffHold": lambda t: _merge(bob(t, 0.12), flutter(t, 2, 30.0)),
        "Stunned": lambda t: _merge({"Root": {"rot": (0.0, 14.0 * math.sin(4.0 * math.pi * t), 0.0)}}, wave(t, 0.5, 2)),
        "Dash": lambda t: stretch(-0.15 * _env(t / 0.3) if t < 0.3 else _env((t - 0.3) / 0.7)),
        "Dart": lambda t: stretch(-0.15 * _env(t / 0.25) if t < 0.25 else 1.2 * _env((t - 0.25) / 0.75)),
        "Burst": lambda t: _merge(stretch(_env(t)), wave(t, 1.5 * _env(t), 2)),
        "Bite": lambda t: jaw(_env(t), 0.36),
        "Gulp": lambda t: _merge(jaw(_env(t / 0.6) if t < 0.6 else 0.0, 0.2), squash(0.5 * _env((t - 0.5) / 0.5) if t > 0.5 else 0.0)),
        "PuffIn": lambda t: _merge(jaw(_env(t), 0.1), squash(0.6 * _env(t))),
        "PuffOut": lambda t: squash(0.6 * math.sin(6.0 * math.pi * t) * (1.0 - t)),
        "Hit": lambda t: squash(_env(t)),
        "TierUp": lambda t: _merge({"Root": {"rot": (0.0, 360.0 * t, 0.0)}}, squash(0.8 * _env(t / 0.4) if t < 0.4 else -0.9 * _env((t - 0.4) / 0.6))),
        "Bank": lambda t: _merge({"Root": {"rot": (0.0, 360.0 * t, 0.0)}}, {b: {"rot": (0.0, -40.0 * _env(t) if b.endswith("_L") else 40.0 * _env(t), 0.0)} for b in ("Lid_L", "Lid_R") if b in bones}),
        "Gulped": lambda t: _merge(stretch(1.6 * _env(t / 0.5) if t < 0.5 else 0.0),
                                   {b: {"loc": (0.0, -(0.6 + 0.4 * i) * k * max(0.0, (t - 0.5) / 0.5), 0.0)} for i, b in enumerate(tail)},
                                   {g: {"loc": tuple(-0.25 * k * max(0.0, (t - 0.4) / 0.6) * c for c in gdir[g])} for g in girth}),
        "Breach": lambda t: _merge({"Root": {"loc": (0.0, -1.5 * k * t, 2.0 * k * _env(t)), "rot": (-35.0 * math.cos(math.pi * t), 0.0, 0.0)}}, wave(t, 1.0, 2)),
        "Hatch": lambda t: _merge(wave(t, 1.5 * _env(t), 4), stretch(_env((t - 0.6) / 0.4) if t > 0.6 else 0.0)),
        "Fidget": lambda t: _merge({"Root": {"rot": (0.0, 0.0, 360.0 * t)}}, wave(t, 1.0, 2)) if owner == "Minnow"
        else _merge(squash(0.5 * _env(t / 0.3) if t < 0.3 else 0.0), jaw(0.4 * _env((t - 0.3) / 0.3) if 0.3 < t < 0.6 else 0.0, 0.0), bob(t)),
        "GiveUp": lambda t: _merge({head: {"rot": (0.0, 0.0, 20.0 * math.sin(6.0 * math.pi * t) * _env(t))}},
                                   squash(_env(t / 0.25) if t < 0.25 else 0.0), {"Root": {"rot": (0.0, 0.0, 90.0 * max(0.0, (t - 0.5) / 0.5))}}),
    }
    return table.get(action, table["Swim"])


def bake(armature, name, frames, loop, pose_at):
    """Keys location and rotation of every bone on frames 0..frames (06 section 6.7). A loop's
    pose function is periodic, so its last frame repeats its first."""
    if armature.animation_data and armature.animation_data.action:
        armature.animation_data.action = None
    for frame in range(frames + 1):
        t = frame / float(frames)
        meshgen.apply_pose(armature, pose_at(0.0 if loop and frame == frames else t))
        for pb in armature.pose.bones:
            pb.keyframe_insert("location", frame=frame)
            pb.keyframe_insert("rotation_quaternion", frame=frame)
    action = armature.animation_data.action
    action.name = name
    action.use_fake_user = True
    meshgen.apply_pose(armature, {})
    return {"action": action, "name": name, "start": 0, "end": frames, "loop": loop, "armature": armature}
