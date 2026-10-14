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

def _flutter(s):
    """One fin beat at angle s: a quick power stroke and a slower recovery (skewed sine)."""
    return math.sin(s + 0.35 * math.sin(s))


def fish_swim_pose(phase, k=1.0, amp=1.0, fold=False):
    """Reference swim cycle (06 section 7.3): a wave from head to tail, about 5% of body
    height at the head and close to 100% at the tail tip (peak to peak). Each bone back from
    the middle lags the one before it by about 2.3 frames of the 16-frame loop, the tail fin
    cups (rolls) a further 2 frames late and the back fin sways 2 frames behind the body
    (06 7.1 arcs and drag). The head nods twice a loop, very little. The pectorals beat three
    times a loop (5.3 frames, the nearest whole count to the bible's 6-frame flutter): a fast
    power stroke, a slower recovery and a feathering turn a quarter beat out, so the fin tip
    draws a figure eight. `amp` scales the wave (1.3 at dash); `fold` pins the pectorals
    back with a small shiver and lays the back fin down (fast swim)."""
    a = 2.0 * math.pi * phase
    pose = _swim_body(lambda size, lag: amp * size * math.sin(a - lag))
    pose["Spine1"]["rot"] = (0.8 * math.sin(2.0 * a + 0.4), 0.0, pose["Spine1"]["rot"][2])
    if fold:
        shiver = 3.0 * math.sin(2.0 * a - 2.0)
        pose["Pec_L"] = {"rot": (0.0, shiver, 26.0)}
        pose["Pec_R"] = {"rot": (0.0, -shiver, -26.0)}
        pose["Dorsal"] = {"rot": (-12.0, pose["Dorsal"]["rot"][1], 0.0)}
        return pose
    s = 3.0 * a
    flap, feather = 14.0 * _flutter(s), 8.0 * math.cos(s)
    pose["Pec_L"] = {"rot": (feather, flap, 0.0)}
    pose["Pec_R"] = {"rot": (feather, -flap, 0.0)}
    return pose


def _swim_body(wave):
    return {
        "Spine2": {"rot": (0.0, 0.0, wave(1.3, -0.6))},
        "Spine1": {"rot": (0.0, 0.0, wave(-0.7, -0.6))},
        "Spine3": {"rot": (0.0, 0.0, wave(10.0, 0.9))},
        "Spine4": {"rot": (0.0, 0.0, wave(17.0, 1.8))},
        "TailFin": {"rot": (0.0, wave(7.0, 3.5), wave(25.0, 2.7))},
        "Dorsal": {"rot": (0.0, wave(6.0, 1.7), 0.0)},
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
    (title, view, pose). Bite: jaw wide open (52 degrees) and the head lunging 12% of body length, reaching
    the 115% stretch of 06 section 7.2. Dash: stretched to 125% (07, A_Fish_Dash)."""
    return [
        ("Bite", "Side", {
            "Jaw": {"rot": (52.0, 0.0, 0.0)},
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


# ---------------------------------------------------------------- the first family clips (07 section 2.1, task S2-A3)
# Final clips at the lengths chapter 07 gives (clips.py reads them). Loops take a phase 0..1 and
# are periodic functions, so their seams are seamless; actions take the frame number, are timed
# by keys (06 section 7.2) and end on the rest pose, so code sway takes over without a pop.
# Every value is (tune).

FISH_HALF_H, FISH_HALF_W = 0.55, 0.35     # body half height and width at the Girth bones (fishshape.py)

_EASE = {
    "out": lambda u: 1.0 - (1.0 - u) ** 2,          # fast out, slow in (06 7.1): the default
    "in": lambda u: u * u,                          # slow out, fast in: winding up an anticipation
    "io": lambda u: u * u * (3.0 - 2.0 * u),        # both ends soft: holds, settles and rebounds
    "snap": lambda u: 1.0 - (1.0 - u) ** 3,         # the hardest fast out: snaps and strikes
}


def ease_keys(frame, keys):
    """Value at `frame` between keys (frame, value[, ease]); the ease names the curve into that key
    (default "out": fast out, slow in, 06 section 7.1). Before the first key and after the last
    the value holds, so a key list can be sampled a few frames early or late (overlap)."""
    if frame <= keys[0][0]:
        return keys[0][1]
    for k0, k1 in zip(keys, keys[1:]):
        if frame <= k1[0]:
            u = (frame - k0[0]) / float(k1[0] - k0[0])
            return k0[1] + (k1[1] - k0[1]) * _EASE[k1[2] if len(k1) > 2 else "out"](u)
    return keys[-1][1]


def fish_stretch_pose(stretch, k=1.0, fins_back=0.0):
    """Body length `stretch` (1.25 = 125%) by moving the Spine bones apart, girth kept by the
    Girth bones: offset = radius x (1 / sqrt(stretch) - 1) (06 section 7.5)."""
    d = (stretch - 1.0) / 0.25            # 1 at 125%, the dash pose of fish_poses()
    g = 1.0 / math.sqrt(stretch) - 1.0
    gz, gx = FISH_HALF_H * k * g, FISH_HALF_W * k * g
    return {
        "Spine1": {"loc": (0.0, -0.35 * k * d, 0.0)},
        "Spine3": {"loc": (0.0, 0.14 * k * d, 0.0)},     # the stretch spread evenly down the back half,
        "Spine4": {"loc": (0.0, 0.14 * k * d, 0.0)},     # so the tail root does not thin to a step
        "TailFin": {"loc": (0.0, 0.06 * k * d, 0.0)},
        "Girth_Top": {"loc": (0.0, 0.0, gz)}, "Girth_Bot": {"loc": (0.0, 0.0, -gz)},
        "Girth_L": {"loc": (gx, 0.0, 0.0)}, "Girth_R": {"loc": (-gx, 0.0, 0.0)},
        "Pec_L": {"rot": (0.0, 0.0, 22.0 * fins_back)}, "Pec_R": {"rot": (0.0, 0.0, -22.0 * fins_back)},
        "Dorsal": {"rot": (-14.0 * fins_back, 0.0, 0.0)},
    }


def _put(pose, bone, loc=None, rot=None):
    """Adds a location and/or rotation to a bone of `pose` (pose values add, they do not replace)."""
    entry = pose.setdefault(bone, {})
    if loc is not None:
        entry["loc"] = tuple(a + b for a, b in zip(entry.get("loc", (0.0, 0.0, 0.0)), loc))
    if rot is not None:
        entry["rot"] = tuple(a + b for a, b in zip(entry.get("rot", (0.0, 0.0, 0.0)), rot))


def fish_swimfast_pose(phase, k=1.0):
    """A_Fish_SwimFast: the swim wave at 130% on the 8-frame dash loop, pectorals pinned back with
    a shiver, back fin laid down (06 7.3)."""
    return fish_swim_pose(phase, k, amp=1.3, fold=True)


def fish_idle_pose(phase, k=1.0):
    """A_Fish_Idle, 60-frame hover. The whole body bobs once a loop (Spine and Girth bones; Root
    stays put), eased by the sine. Head and tail drag behind the bob (they pitch against its
    speed, the tail about 3 frames late), the tail drifts side to side twice, the mouth breathes
    twice, and the pectorals scull ten times on the bible's 6-frame beat in a figure eight
    (flap, then feather a quarter beat later), so the fish looks held up by its fins."""
    a = 2.0 * math.pi * phase
    bob = 0.05 * k * math.sin(a)
    rise = math.cos(a)                              # the bob's speed, -1..1
    drag = math.cos(a - 0.6)                        # the same, 3 frames late
    s = 10.0 * a
    flap, feather = 20.0 * _flutter(s), 10.0 * math.cos(s)
    breathe = 0.5 - 0.5 * math.cos(2.0 * a)
    pose = {}
    for bone in ("Spine2", "Spine3"):
        _put(pose, bone, loc=(0.0, 0.0, bob))
    for bone in ("Girth_Top", "Girth_Bot", "Girth_L", "Girth_R"):
        _put(pose, bone, loc=(0.0, 0.0, bob))
    _put(pose, "Girth_L", loc=(0.012 * k * breathe, 0.0, 0.0))
    _put(pose, "Girth_R", loc=(-0.012 * k * breathe, 0.0, 0.0))
    _put(pose, "Spine2", rot=(0.0, 0.0, 0.6 * math.sin(2.0 * a)))
    _put(pose, "Spine1", rot=(1.4 * rise, 0.0, -0.4 * math.sin(2.0 * a)))
    _put(pose, "Spine4", rot=(-2.2 * drag, 0.0, 2.6 * math.sin(2.0 * a - 1.0)))
    _put(pose, "TailFin", rot=(-3.2 * math.cos(a - 1.0), 2.0 * math.sin(2.0 * a - 2.2), 4.5 * math.sin(2.0 * a - 1.8)))
    _put(pose, "Dorsal", rot=(-3.0 + 3.0 * math.sin(a - 0.8), 2.5 * math.sin(2.0 * a - 1.4), 0.0))
    _put(pose, "Jaw", rot=(3.0 * breathe, 0.0, 0.0))
    _put(pose, "Pec_L", rot=(feather, flap, 0.0))
    _put(pose, "Pec_R", rot=(feather, -flap, 0.0))
    return pose


# A_Fish_Dash, 14 frames (06 7.2): the squash winds up slowly into 85% (anticipation, 2 frames,
# overlapping the move), the body snaps to 125% in 2 and holds it, moving, for 4 more; it
# overshoots to 95% on frame 10, rebounds 3% and settles on frame 14.
DASH_STRETCH = [(0, 1.0), (2, 0.85, "in"), (4, 1.25, "snap"), (8, 1.23, "io"), (10, 0.95, "io"), (12, 1.03, "io"), (14, 1.0, "io")]
# The bend of a C-start: the body curls into a C during the squash, whips through to the other
# side on the power stroke and swings out in shrinking beats. +1 curls head and tail to the left.
DASH_BEND = [(0, 0.0), (2, 1.0, "in"), (4, -0.75, "snap"), (6, 0.32, "io"), (8, -0.12, "io"), (10, 0.0, "io")]
# Fins pinned back from the snap (fast out), flaring past rest on the overshoot (follow-through).
DASH_FINS = [(0, 0.0), (2, 0.25, "in"), (4, 1.0, "snap"), (8, 1.0), (11, -0.3, "io"), (13, 0.0, "io")]


def fish_dash_pose(frame, k=1.0):
    """A_Fish_Dash: squash and C-bend, snap to a 125% stretch with fins pinned back, overshoot to
    95%, settle. The wave of the bend travels down the body: each bone back from the middle takes
    it about a frame later and the tail fin 2 frames late; the fins follow the body 1 frame late."""
    pose = fish_stretch_pose(ease_keys(frame, DASH_STRETCH), k)
    # Into the C every bone curls together (an even C, no kink at the tail); from the snap on,
    # each bone holds the C for its lag, then follows: the wave runs down the body.
    bend = lambda lag: ease_keys(max(frame - lag, min(frame, 2.0)), DASH_BEND)
    fins = ease_keys(frame - 1.0, DASH_FINS)
    _put(pose, "Spine2", rot=(0.0, 0.0, 9.0 * bend(0.0)))
    _put(pose, "Spine1", rot=(0.0, 0.0, 7.0 * bend(0.0)))
    _put(pose, "Spine3", rot=(0.0, 0.0, -12.0 * bend(0.5)))
    _put(pose, "Spine4", rot=(0.0, 0.0, -13.0 * bend(1.2)))
    _put(pose, "TailFin", rot=(0.0, 8.0 * bend(2.6), -15.0 * bend(2.0)))
    pose["Pec_L"] = {"rot": (0.0, -6.0 * min(fins, 0.0), 26.0 * fins)}
    pose["Pec_R"] = {"rot": (0.0, 6.0 * min(fins, 0.0), -26.0 * fins)}
    pose["Dorsal"] = {"rot": (-16.0 * fins, 5.0 * bend(1.8), 0.0)}
    return pose


BITE_FLICK = [(0, 0.0), (1, 1.0, "snap"), (2.5, -0.45, "io"), (4, 0.12, "io"), (5, 0.0, "io")]


def fish_bite_pose(frame, k=1.0):
    """A_Fish_Bite, 8 frames (07: 7 to 9; 06 7.2). Frame 0: the jaw is already opening as the prey
    nears; frame 1 (anticipation): jaw wide, head drawn back and up, body squashed a little;
    frame 2: the jaw snaps shut, the head lunges 12% of body length and chomps down, the cheeks
    bulge; frames 3 and 4: the body stretches to 115%; then 4 frames of settle with a 3% rebound.
    The pectorals flare forward to brake and the tail flicks, 1 and 2 frames behind the head."""
    jaw = ease_keys(frame, [(0, 28.0), (1, 55.0), (2, 0.0, "snap")])
    stretch = ease_keys(frame, [(0, 1.0), (1, 0.93, "in"), (2, 1.08, "snap"), (4, 1.15), (6, 0.97, "io"), (8, 1.0, "io")])
    lunge = ease_keys(frame, [(0, 0.0), (1, -0.05 * k, "in"), (2, 0.36 * k, "snap"), (4, 0.22 * k, "io"), (6, -0.02 * k, "io"), (8, 0.0, "io")])
    nod = ease_keys(frame, [(0, -2.0), (1, -7.0, "in"), (2, 6.0, "snap"), (4, 0.0, "io"), (6, -1.5, "io"), (8, 0.0, "io")])
    bulge = ease_keys(frame, [(0, 0.0), (1, 0.0), (2, 0.08, "snap"), (4, 0.045, "io"), (7, 0.0, "io")])
    brake = ease_keys(frame - 1.0, [(0, 0.0), (1, 0.0), (2, 1.0, "snap"), (4, 0.35, "io"), (7, 0.0, "io")])
    flick = lambda lag: ease_keys(frame - lag, BITE_FLICK)
    pose = fish_stretch_pose(stretch, k)
    _put(pose, "Spine1", loc=(0.0, -lunge, 0.0), rot=(nod, 0.0, 0.0))
    _put(pose, "Jaw", rot=(jaw, 0.0, 0.0))
    _put(pose, "Girth_L", loc=(bulge, 0.0, 0.0))
    _put(pose, "Girth_R", loc=(-bulge, 0.0, 0.0))
    _put(pose, "Pec_L", rot=(0.0, 12.0 * brake, -24.0 * brake))
    _put(pose, "Pec_R", rot=(0.0, -12.0 * brake, 24.0 * brake))
    _put(pose, "Dorsal", rot=(8.0 * brake, 0.0, 0.0))
    _put(pose, "Spine4", rot=(0.0, 0.0, 5.0 * flick(2.0)))
    _put(pose, "TailFin", rot=(0.0, 0.0, 11.0 * flick(2.6)))
    return pose


# name -> (pose function, key frames for the review strip as (frame, label)). Loop or not, and
# the length, come from chapter 07 (clips.py).
FISH_CLIPS = {
    "A_Fish_Swim": (fish_swim_pose, [(0, "phase 0"), (4, "1/4"), (8, "1/2"), (12, "3/4")]),
    "A_Fish_SwimFast": (fish_swimfast_pose, [(0, "phase 0"), (2, "1/4"), (4, "1/2"), (6, "3/4")]),
    "A_Fish_Idle": (fish_idle_pose, [(0, "phase 0"), (15, "bob top"), (30, "1/2"), (45, "bob low")]),
    "A_Fish_Dash": (fish_dash_pose, [(0, "start"), (2, "squash 85%, C"), (4, "snap 125%"), (8, "hold"),
                                     (10, "overshoot 95%"), (14, "settled")]),
    "A_Fish_Bite": (fish_bite_pose, [(0, "jaw opening"), (1, "wind-up"), (2, "snap, lunge 12%"), (4, "stretch 115%"),
                                     (6, "rebound"), (8, "settled")]),
}
