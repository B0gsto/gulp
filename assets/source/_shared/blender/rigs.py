"""Family skeletons. First version: RIG_Fish (docs/06-art-bible.md sections 6.3, 7 and 8.4).

Bone names and counts are the bible's. The bible does not give a hierarchy or joint
positions; the ones here are this tool's first fit and are open to the rig review:
Root sits at the body centre, Spine2 -> Spine1 run forward to the head and
Spine3 -> Spine4 -> TailFin run back, so sliding Spine1 and Spine4 apart stretches the
body (06 section 7.5) and the swim wave grows from the middle to the tail.
"""
import math

import meshgen

SPINE_ORDER = ("Spine1", "Spine2", "Spine3", "Spine4", "TailFin")


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


class FishFit:
    """RIG_Fish fitted to a body: `half_h(y)` and `half_w(y)` give the body's half height and
    half width at station y; `eye` and `pec` are the left-side (+X) eye centre and fin root."""

    def __init__(self, length, half_h, half_w, eye, pec, dorsal_tip):
        self.k = length / 3.0
        self.half_h, self.half_w = half_h, half_w
        self.eye, self.pec, self.dorsal_tip = eye, pec, dorsal_tip
        k = self.k
        self.bounds = (-0.85 * k, 0.0, 0.6 * k, 1.0 * k)   # where one spine bone hands over to the next
        self.blend = 0.12 * k
        self.girth_y, self.girth_reach = -0.3 * k, 0.55 * k
        self.jaw_y = -0.95 * k

    def bones(self):
        k, hh, hw = self.k, self.half_h, self.half_w
        ex, ey, ez = self.eye
        px, py, pz = self.pec
        gy = self.girth_y
        up, out_l, out_r = (0.0, 0.0, 1.0), (1.0, 0.0, 0.0), (-1.0, 0.0, 0.0)

        def top(y):
            return (0.0, y * k, hh(y * k))

        deform = [
            ("Root", (0.0, 0.0, 0.0), None),
            ("Spine2", (0.0, -0.05 * k, 0.0), "Root"),
            ("Spine1", (0.0, -0.85 * k, 0.0), "Spine2"),
            ("Spine3", (0.0, 0.05 * k, 0.0), "Root"),
            ("Spine4", (0.0, 0.6 * k, 0.0), "Spine3"),
            ("TailFin", (0.0, 1.0 * k, 0.0), "Spine4"),
            ("Jaw", (0.0, self.jaw_y, -0.25 * hh(self.jaw_y)), "Spine1"),
            ("Dorsal", top(-0.1), "Spine2"),
            ("Pec_L", (px, py, pz), "Spine2"),
            ("Pec_R", (-px, py, pz), "Spine2"),
            ("Eye_L", (ex, ey, ez), "Spine1"),
            ("Eye_R", (-ex, ey, ez), "Spine1"),
            ("Lid_L", (ex, ey, ez), "Spine1"),
            ("Lid_R", (-ex, ey, ez), "Spine1"),
            ("Girth_Top", (0.0, gy, hh(gy)), "Root"),
            ("Girth_Bot", (0.0, gy, -hh(gy)), "Root"),
            ("Girth_L", (hw(gy), gy, 0.0), "Root"),
            ("Girth_R", (-hw(gy), gy, 0.0), "Root"),
        ]
        sockets = [
            ("Sock_Back_01", top(-0.35), "Spine2", up),
            ("Sock_Back_02", top(0.2), "Spine3", up),
            ("Sock_Back_03", top(0.5), "Spine3", up),
            ("Sock_Flank_L", (hw(-0.2 * k), -0.2 * k, 0.0), "Spine2", out_l),
            ("Sock_Flank_R", (-hw(-0.2 * k), -0.2 * k, 0.0), "Spine2", out_r),
            ("Sock_Head", top(-1.2), "Spine1", (0.0, -0.5, 1.0)),
            ("Sock_Tail", top(0.85), "Spine4", (0.0, 0.5, 1.0)),
            ("Sock_Crest", top(-0.7), "Spine2", up),
            ("Sock_FinDorsal", self.dorsal_tip, "Dorsal", up),
            ("Sock_FinTail", (0.0, 1.3 * k, 0.0), "TailFin", (0.0, 1.0, 0.0)),
        ]
        out = [{"name": n, "head": h, "parent": p, "deform": True} for n, h, p in deform]
        out += [{"name": n, "head": h, "parent": p, "deform": False, "direction": d} for n, h, p, d in sockets]
        return out

    def spine_weights(self, y):
        h = self.blend
        for i, b in enumerate(self.bounds):
            if y < b - h:
                return {SPINE_ORDER[i]: 1.0}
            if y <= b + h:
                t = smooth((y - (b - h)) / (2.0 * h))
                return {SPINE_ORDER[i]: 1.0 - t, SPINE_ORDER[i + 1]: t}
        return {SPINE_ORDER[-1]: 1.0}

    def body_weights(self, p):
        """Up to two spine bones, plus the lower jaw in the head or up to two girth bones
        at mid-body. Never more than four, never Root (06 section 6.5)."""
        x, y, z = p
        w = self.spine_weights(y)
        hh, hw = max(self.half_h(y), 1e-6), max(self.half_w(y), 1e-6)
        girth = 0.5 * max(0.0, 1.0 - ((y - self.girth_y) / self.girth_reach) ** 2)
        jaw = smooth((self.jaw_y - y) / (0.2 * self.k)) * smooth((-0.03 - z) / 0.04)   # a sharp lip line, so the mouth opens
        if jaw > 0.0:
            w = {n: v * (1.0 - jaw) for n, v in w.items()}
            w["Jaw"] = jaw
        elif girth > 0.0:
            nx, nz = x / hw, z / hh
            norm = math.hypot(nx, nz) or 1.0
            nx, nz = nx / norm, nz / norm
            w = {n: v * (1.0 - girth) for n, v in w.items()}
            w["Girth_Top"] = girth * max(0.0, nz) ** 2
            w["Girth_Bot"] = girth * max(0.0, -nz) ** 2
            w["Girth_L"] = girth * max(0.0, nx) ** 2
            w["Girth_R"] = girth * max(0.0, -nx) ** 2
        return w


# ---------------------------------------------------------------- poses and clips
# A pose is {bone: {"loc": (x, y, z), "rot": (rx, ry, rz) in degrees}}. Deform bones rest
# world-aligned, so both are in the creature's axes: -Y forward, +Z up, +X its left.

def fish_swim_pose(phase, k=1.0):
    """Reference swim cycle (06 section 7.3): a wave from head to tail, about 5% of body
    height at the head and close to 100% at the tail tip; pectorals flutter twice a loop
    (the bible's 6-frame flutter does not divide a 16-frame loop)."""
    a = 2.0 * math.pi * phase
    wave = lambda amp, lag: amp * math.sin(a - lag)
    flutter = 12.0 * math.sin(2.0 * a)
    return {
        "Spine2": {"rot": (0.0, 0.0, wave(1.1, -0.6))},
        "Spine1": {"rot": (0.0, 0.0, wave(-0.6, -0.6))},
        "Spine3": {"rot": (0.0, 0.0, wave(8.0, 0.9))},
        "Spine4": {"rot": (0.0, 0.0, wave(13.0, 1.8))},
        "TailFin": {"rot": (0.0, 0.0, wave(19.0, 2.7))},
        "Dorsal": {"rot": (0.0, wave(5.0, 1.5), 0.0)},
        "Pec_L": {"rot": (0.0, flutter, 0.0)},
        "Pec_R": {"rot": (0.0, -flutter, 0.0)},
    }


def bake_clip(armature, name, frames, pose_at):
    """Keys location and rotation of every bone on every frame 0..frames (06 section 6.7:
    key all bones, no simplification). Frame `frames` repeats frame 0, so the clip loops."""
    if armature.animation_data and armature.animation_data.action:
        armature.animation_data.action = None
    for frame in range(frames + 1):
        meshgen.apply_pose(armature, pose_at((frame % frames) / frames))
        for pb in armature.pose.bones:
            pb.keyframe_insert("location", frame=frame)
            pb.keyframe_insert("rotation_quaternion", frame=frame)
    action = armature.animation_data.action
    action.name = name
    action.use_fake_user = True
    return {"action": action, "name": name, "start": 0, "end": frames, "loop": True, "armature": armature}


def fish_poses(k=1.0):
    """Key poses for the contact sheet, cells 10 to 12 (06 section 15.5), as
    (title, view, pose). Bite: jaw open and the head lunging 12% of body length, reaching
    the 115% stretch of 06 section 7.2. Dash: stretched to 125% (07, A_Fish_Dash)."""
    return [
        ("Bite", "Side", {
            "Jaw": {"rot": (38.0, 0.0, 0.0)},
            "Spine1": {"loc": (0.0, -0.36 * k, 0.0)},
            "TailFin": {"loc": (0.0, 0.09 * k, 0.0)},
            "Girth_L": {"loc": (0.04, 0.0, 0.0)}, "Girth_R": {"loc": (-0.04, 0.0, 0.0)},
        }),
        ("Dash stretch", "Side", {
            "Spine1": {"loc": (0.0, -0.35 * k, 0.0)},
            "Spine3": {"loc": (0.0, 0.12 * k, 0.0)},
            "Spine4": {"loc": (0.0, 0.18 * k, 0.0)},
            "TailFin": {"loc": (0.0, 0.1 * k, 0.0)},
            "Girth_Top": {"loc": (0.0, 0.0, -0.07)}, "Girth_Bot": {"loc": (0.0, 0.0, 0.07)},
            "Girth_L": {"loc": (-0.04, 0.0, 0.0)}, "Girth_R": {"loc": (0.04, 0.0, 0.0)},
            "Pec_L": {"rot": (0.0, 0.0, 22.0)}, "Pec_R": {"rot": (0.0, 0.0, -22.0)},
            "Dorsal": {"rot": (-14.0, 0.0, 0.0)},
        }),
        ("Scared", "ThreeQuarter", {
            "Spine1": {"loc": (0.0, 0.12 * k, 0.0)},
            "TailFin": {"loc": (0.0, -0.1 * k, 0.0), "rot": (0.0, 0.0, 14.0)},
            "Girth_Top": {"loc": (0.0, 0.0, 0.06)}, "Girth_Bot": {"loc": (0.0, 0.0, -0.06)},
            "Girth_L": {"loc": (0.04, 0.0, 0.0)}, "Girth_R": {"loc": (-0.04, 0.0, 0.0)},
            "Lid_L": {"rot": (0.0, -28.0, 0.0)}, "Lid_R": {"rot": (0.0, 28.0, 0.0)},
            "Eye_L": {"loc": (0.03, 0.0, 0.0)}, "Eye_R": {"loc": (-0.03, 0.0, 0.0)},
            "Pec_L": {"rot": (0.0, 30.0, 0.0)}, "Pec_R": {"rot": (0.0, -30.0, 0.0)},
        }),
    ]
