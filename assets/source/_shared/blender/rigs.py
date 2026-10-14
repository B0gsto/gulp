"""Family skeletons: RIG_Fish, final (task S1-A3; docs/06-art-bible.md sections 6.1, 6.3, 6.5, 7
and 8.4; 07 row RIG_Fish).

Bone names and counts are the bible's: 18 deform bones and 10 weightless sockets. The hierarchy,
joint placement and weights are FishFit's (below), fitted to a family body (fishbody.py), and are
the reference every Fish species uses: the base (families/fish) and the Minnow call the same fit.
Root sits at the body centre, Spine2 -> Spine1 run forward to the head and Spine3 -> Spine4 ->
TailFin run back, so sliding the Spine bones apart stretches the body (06 section 7.5) and the swim
wave grows from the middle to the tail. weightcheck.py measures the skin at the squash, stretch and
bite poses of the clips below.
"""
import math

import meshgen
from fishbody import SPINE_NODES

SPINE_ORDER = ("Spine1", "Spine2", "Spine3", "Spine4", "TailFin")
CANON_NOSE, CANON_ROOT = -1.5, 0.95       # the family base body at scale 1 (fishshape.py): k = 1
CANON_LENGTH = CANON_ROOT - CANON_NOSE
SPINE_EASE = 0.28       # 0: linear hand-over (even stretch); 1: smoothstep (zero slope at the nodes)
ONSET = 0.95            # share of the mean strain the span out of the rigid head takes (the stretch fades in)
PIVOTS = {"Spine1": 0.37, "Spine2": 0.59, "Spine3": 0.63, "Spine4": 0.80, "TailFin": 0.95}   # bone heads, body fractions
GIRTH_T, GIRTH_REACH, GIRTH_PEAK = 0.50, 0.30, 0.29  # soft over the middle 60% of the body (06 7.5): 0.2 to 0.8
JAW_T, LIP_Z = 0.22, -0.03    # the mouth corner (body fraction) and the lip line's height at k = 1
GIRTH = ("Girth_Top", "Girth_Bot", "Girth_L", "Girth_R")


def _girth_ref():
    """Back height, belly depth and half width of the family base at the girth centre, k = 1."""
    from fishshape import BODY
    y = BODY.y(GIRTH_T)
    return BODY.top(y), BODY.bot(y), BODY.half_w(y)


GIRTH_REF = _girth_ref()


def ramp(u, ease_in, ease_out):
    """Share of the next spine bone at fraction u between two weight nodes. Between two bending
    nodes the ramp is linear eased by SPINE_EASE, which keeps its slope equal on both sides of
    every inner node (an even stretch has no corner there). Out of the rigid head (`ease_in`) the
    ramp starts with zero slope and the span takes ONSET of the mean strain, so the stretch fades
    in from the head instead of starting at a ring: a cubic whose end slope meets the inner ramps'
    at the next node, rising without overshoot. Into a rigid end (`ease_out`) it mirrors that."""
    u = max(0.0, min(1.0, u))
    c = 1.0 - SPINE_EASE                  # the inner ramps' slope at a node, as a share of their mean
    if ease_in and ease_out:
        return smooth(u)
    if ease_in:
        e = c / ONSET
        return (3.0 - e) * u * u + (e - 2.0) * u ** 3
    if ease_out:
        return 1.0 - ramp(1.0 - u, True, False)
    return u + SPINE_EASE * (smooth(u) - u)


def span_share(i):
    """Share of the body's strain taken by spine span i (nodes i to i + 1) per unit length: ONSET
    for the span out of the rigid head, 1 for the others."""
    return ONSET if i == 0 else 1.0


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


class FishFit:
    """RIG_Fish fitted to a family body (fishbody.FishBody): the one source of the family's bone
    placement and skin weights, used by the base and by every Fish species, so they cannot drift.
    `eye` and `pec` are the left-side (+X) eye centre and pectoral root, `dorsal_tip` the back
    fin's top (Sock_FinDorsal). Everything else is placed by body fractions (fishbody.SPINE_NODES,
    the JAW_T, PIVOTS and GIRTH numbers below).

    Hierarchy: Root at the body centre; Spine2 -> Spine1 -> (Jaw, Eye_L/R, Lid_L/R) run forward,
    Spine3 -> Spine4 -> TailFin run back; Dorsal and Pec_L/R hang on Spine2; the four Girth bones
    hang on Root, the neutral middle between the front half and the back half, which bend opposite
    ways in the dash's C (on Spine2 the girth dragged the back half's flank the wrong way). Every bone, sockets
    included, rests with rotation 0 and roll 0 (06 section 6.1), so a pose's loc and rot are in the
    creature's axes: -Y forward, +Z up, +X its left.

    Weights (06 sections 6.5 and 7.5): along the body each vertex takes the two spine bones whose
    weight nodes it lies between, blended by an eased linear ramp (no plateaus between nodes, so
    sliding the Spine bones apart stretches the body evenly instead of creasing a narrow band; the
    ease softens the slope change at a node, and the ramp out of the rigid head starts flat). The four Girth bones take up to GIRTH_PEAK over the middle of the
    body with a falloff of zero slope at both ends, shared by the vertex's place in its section, so
    that moving them in and out scales the section evenly. The lower jaw
    takes the head below the lip line, with a sharp split across the lip (the mouth must open) and
    a soft one along the body behind the mouth corner. Never Root, never a socket, at most four.
    """

    def __init__(self, body, eye, pec, dorsal_tip):
        self.body = body
        self.k = body.length / CANON_LENGTH
        self.half_h, self.half_w = body.half_h, body.half_w
        self.eye, self.pec, self.dorsal_tip = eye, pec, dorsal_tip
        self.nodes = [body.y(t) for t in SPINE_NODES]
        self.girth_y = body.y(GIRTH_T)
        self.girth_reach = GIRTH_REACH * body.length
        self.jaw_y = body.y(JAW_T)
        self.lip_z = LIP_Z * self.k

    def bones(self):
        b, k = self.body, self.k
        ex, ey, ez = self.eye
        px, py, pz = self.pec
        gy = self.girth_y
        up, out_l, out_r = (0.0, 0.0, 1.0), (1.0, 0.0, 0.0), (-1.0, 0.0, 0.0)

        def top(t):
            return (0.0, b.y(t), b.top(b.y(t)))

        def spine(name):
            return (0.0, b.y(PIVOTS[name]), 0.0)

        deform = [
            ("Root", (0.0, 0.0, 0.0), None),
            ("Spine2", spine("Spine2"), "Root"),
            ("Spine1", spine("Spine1"), "Spine2"),
            ("Spine3", spine("Spine3"), "Root"),
            ("Spine4", spine("Spine4"), "Spine3"),
            ("TailFin", spine("TailFin"), "Spine4"),
            ("Jaw", (0.0, self.jaw_y, self.lip_z), "Spine1"),
            ("Dorsal", (0.0, self.dorsal_tip[1], b.top(self.dorsal_tip[1])), "Spine2"),
            ("Pec_L", (px, py, pz), "Spine2"),
            ("Pec_R", (-px, py, pz), "Spine2"),
            ("Eye_L", (ex, ey, ez), "Spine1"),
            ("Eye_R", (-ex, ey, ez), "Spine1"),
            ("Lid_L", (ex, ey, ez), "Spine1"),
            ("Lid_R", (-ex, ey, ez), "Spine1"),
            ("Girth_Top", (0.0, gy, b.top(gy)), "Root"),
            ("Girth_Bot", (0.0, gy, -b.bot(gy)), "Root"),
            ("Girth_L", (b.half_w(gy), gy, 0.0), "Root"),
            ("Girth_R", (-b.half_w(gy), gy, 0.0), "Root"),
        ]
        flank = b.y(0.53)
        sockets = [
            ("Sock_Back_01", top(0.47), "Spine2", up),
            ("Sock_Back_02", top(0.69), "Spine3", up),
            ("Sock_Back_03", top(0.81), "Spine4", up),
            ("Sock_Flank_L", (b.half_w(flank), flank, 0.0), "Spine2", out_l),
            ("Sock_Flank_R", (-b.half_w(flank), flank, 0.0), "Spine2", out_r),
            ("Sock_Head", top(0.12), "Spine1", (0.0, -0.5, 1.0)),
            ("Sock_Tail", top(0.94), "Spine4", (0.0, 0.5, 1.0)),
            ("Sock_Crest", top(0.33), "Spine2", up),
            ("Sock_FinDorsal", self.dorsal_tip, "Dorsal", up),
            ("Sock_FinTail", (0.0, b.root + 0.35 * k, 0.0), "TailFin", (0.0, 1.0, 0.0)),
        ]
        out = [{"name": n, "head": h, "parent": p, "deform": True} for n, h, p in deform]
        out += [{"name": n, "head": h, "parent": p, "deform": False, "direction": d} for n, h, p, d in sockets]
        return out

    def spine_weights(self, y):
        nodes = self.nodes
        if y <= nodes[0]:
            return {SPINE_ORDER[0]: 1.0}
        for i in range(len(nodes) - 1):
            if y <= nodes[i + 1]:
                u = ramp((y - nodes[i]) / (nodes[i + 1] - nodes[i]), i == 0, False)   # the body ends at the last node
                return {SPINE_ORDER[i]: 1.0 - u, SPINE_ORDER[i + 1]: u}
        return {SPINE_ORDER[-1]: 1.0}

    def girth(self, y):
        x = (y - self.girth_y) / self.girth_reach
        return GIRTH_PEAK * (1.0 - x * x) ** 2 if abs(x) < 1.0 else 0.0

    def jaw(self, y, z):
        return smooth((self.jaw_y - y) / (0.2 * self.k)) * smooth((self.lip_z - z) / (0.04 * self.k))

    def body_weights(self, p):
        x, y, z = p
        b = self.body
        w = self.spine_weights(y)
        jaw, g = self.jaw(y, z), self.girth(y)
        girth = {}
        if g > 0.0:
            # The vertex's offset from the centre line as a share of the family's reference half width
            # and back or belly height (GIRTH_REF): the clips move the Girth bones by the same share
            # of those, so the section scales evenly, in both directions, on any species.
            rt, rb, rw = (self.k * r for r in GIRTH_REF)
            nx = min(1.0, abs(x) / rw)
            nz = min(1.0, abs(z) / (rt if z >= 0.0 else rb))
            g *= 1.0 - jaw
            for name, part in (("Girth_L" if x > 0.0 else "Girth_R", nx), ("Girth_Top" if z > 0.0 else "Girth_Bot", nz)):
                if part > 0.0:
                    girth[name] = g * part
        keep = (1.0 - jaw) * (1.0 - sum(girth.values()))
        w = {n: v * keep for n, v in w.items()}
        w.update(girth)
        if jaw > 0.0:
            w["Jaw"] = jaw
        return w

    def fin_weights(self, bone, p, height):
        """A fin rooted in the body: the root row follows the skin under it, the fin above it the
        fin bone, eased over the lower half of the fin (`height` 0 at the root, 1 at the edge)."""
        b = self.body
        on = smooth(height / 0.5)
        under = self.body_weights((0.0, p[1], b.top(p[1])))
        w = {n: v * (1.0 - on) for n, v in under.items()}
        w[bone] = w.get(bone, 0.0) + on
        return w

    PART_BONES = {"tail": "TailFin", "dorsal": "Dorsal", "pec": "Pec_%s", "eye": "Eye_%s", "lid": "Lid_%s"}

    def part_weights(self, kind, side=""):
        """Weights of a rigid part: {bone: 1}."""
        return {self.PART_BONES[kind].replace("%s", side): 1.0}


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
    """Key poses for the contact sheet, cells 10 to 12 (06 section 15.5), as (title, view, pose),
    taken from the clips so the sheet shows what ships: the bite's wide jaw (frame 1), the dash's
    125% stretch with fins pinned back, and a scared squash with the lids up."""
    scared = fish_stretch_pose(0.9, k)
    _put(scared, "TailFin", rot=(0.0, 0.0, 14.0))
    _put(scared, "Lid_L", rot=(0.0, -28.0, 0.0))
    _put(scared, "Lid_R", rot=(0.0, 28.0, 0.0))
    _put(scared, "Pec_L", rot=(0.0, 30.0, 0.0))
    _put(scared, "Pec_R", rot=(0.0, -30.0, 0.0))
    return [
        ("Bite (frame 1, jaw wide)", "Side", fish_bite_pose(1, k)),
        ("Dash stretch 125%", "Side", fish_stretch_pose(1.25, k, fins_back=1.0)),
        ("Scared", "ThreeQuarter", scared),
    ]


# ---------------------------------------------------------------- the first family clips (07 section 2.1, task S2-A3)
# Final clips at the lengths chapter 07 gives (clips.py reads them). Loops take a phase 0..1 and
# are periodic functions, so their seams are seamless; actions take the frame number, are timed
# by keys (06 section 7.2) and end on the rest pose, so code sway takes over without a pop.
# Every value is (tune).


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


def canon_nodes(k=1.0):
    """y of each spine bone's weight node on the family base body at scale k (FishFit.nodes)."""
    return [k * (CANON_NOSE + t * CANON_LENGTH) for t in SPINE_NODES]


def slide_share(y, k=1.0):
    """Share (0 at Spine1's node, 1 at the tail root) of a slide along the body that the skin at
    station y takes when the spine nodes slide by their strain shares (span_share): the stretch is
    even along the body, fading in out of the rigid head. Between nodes it follows the weight
    ramp, so it is exactly where a centre-line vertex at y goes."""
    nodes = canon_nodes(k)
    cum = [0.0]
    for i in range(len(nodes) - 1):
        cum.append(cum[-1] + span_share(i) * (nodes[i + 1] - nodes[i]))
    if y <= nodes[0]:
        return 0.0
    for i in range(len(nodes) - 1):
        if y <= nodes[i + 1]:
            u = (y - nodes[i]) / (nodes[i + 1] - nodes[i])
            return (cum[i] + (cum[i + 1] - cum[i]) * ramp(u, i == 0, False)) / cum[-1]
    return 1.0


def spine_slide(pose, disp, k=1.0):
    """Adds world slides along the body to the spine chain: `disp` gives each spine bone's world
    y displacement at its weight node; the chain's local offsets are worked out (Spine1 rides on
    Spine2, Spine4 on Spine3, TailFin on Spine4; Spine2 and Spine3 on Root)."""
    d = dict(zip(SPINE_ORDER, (disp(y) for y in canon_nodes(k))))
    parent = {"Spine1": "Spine2", "Spine2": None, "Spine3": None, "Spine4": "Spine3", "TailFin": "Spine4"}
    for bone in SPINE_ORDER:
        _put(pose, bone, loc=(0.0, d[bone] - (d[parent[bone]] if parent[bone] else 0.0), 0.0))
    gy = disp(k * (CANON_NOSE + GIRTH_T * CANON_LENGTH))      # the Girth bones (on Root) slide with their station
    for bone in GIRTH:
        _put(pose, bone, loc=(0.0, gy, 0.0))
    return pose


def fish_stretch_pose(stretch, k=1.0, fins_back=0.0):
    """Creature length `stretch` (1.25 = 125%, nose to tail tip) by sliding the Spine bones apart
    (06 section 7.5). The head in front of Spine1's node and the tail fin are rigid, so the body
    between them takes the whole change, evenly but fading in out of the head (slide_share); the
    head and the tail move apart by the same amount. Girth by the bible (06 7.1 and 7.5): the
    section at the girth centre scales by 1 / sqrt(stretch) (stretch 125% means girth 89%), the
    Girth bones' offset divided by GIRTH_PEAK, their weight there."""
    total = (stretch - 1.0) * 3.0 * k
    pose = spine_slide({}, lambda y: total * (slide_share(y, k) - 0.5), k)
    g = (1.0 / math.sqrt(stretch) - 1.0) / GIRTH_PEAK
    gz_top, gz_bot, gx = (r * k * g for r in GIRTH_REF)
    _put(pose, "Girth_Top", loc=(0.0, 0.0, gz_top))
    _put(pose, "Girth_Bot", loc=(0.0, 0.0, -gz_bot))
    _put(pose, "Girth_L", loc=(gx, 0.0, 0.0))
    _put(pose, "Girth_R", loc=(-gx, 0.0, 0.0))
    _put(pose, "Pec_L", rot=(0.0, 0.0, 22.0 * fins_back))
    _put(pose, "Pec_R", rot=(0.0, 0.0, -22.0 * fins_back))
    _put(pose, "Dorsal", rot=(-14.0 * fins_back, 0.0, 0.0))
    return pose


def lunge_slide(pose, lunge, k=1.0):
    """The head lunges forward by `lunge` studs and the body follows it, tail root anchored: the
    slide falls off along the body as the stretch does (slide_share), no stretch piled into the neck."""
    return spine_slide(pose, lambda y: -lunge * (1.0 - slide_share(y, k)), k)


def rotate_about(pose, bone, rot, pivot_t, k=1.0):
    """Adds rotation `rot` (degrees, XYZ) to `bone` about the point on its axis at body fraction
    `pivot_t` instead of about its head: the location that moves the head onto that rotation is
    added too ((I - R) q, q from the head to the pivot), so a clip can turn a bone about the
    point that skins best (06 6.5) without moving the rest skeleton."""
    rx, ry, rz = (math.radians(a) for a in rot)
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    q = k * (pivot_t - (GIRTH_T if bone in GIRTH else PIVOTS[bone])) * CANON_LENGTH
    # R = Rz Ry Rx (Blender XYZ euler) applied to (0, q, 0): its second column times q
    col = (cz * sy * sx - sz * cx, sz * sy * sx + cz * cx, cy * sx)
    _put(pose, bone, loc=(-col[0] * q, q - col[1] * q, -col[2] * q), rot=rot)
    return pose


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
    bob = 0.15 * k * math.sin(a)                    # 06 7.4: 0.15 studs up and down, eased
    rise = math.cos(a)                              # the bob's speed, -1..1
    drag = math.cos(a - 0.6)                        # the same, 3 frames late
    s = 10.0 * a
    flap, feather = 34.0 * _flutter(s), 18.0 * math.cos(s)
    breathe = 0.5 - 0.5 * math.cos(2.0 * a)
    pose = {}
    for bone in ("Spine2", "Spine3") + GIRTH:
        _put(pose, bone, loc=(0.0, 0.0, bob))
    _put(pose, "Girth_L", loc=(0.012 * k * breathe, 0.0, 0.0))
    _put(pose, "Girth_R", loc=(-0.012 * k * breathe, 0.0, 0.0))
    _put(pose, "Spine2", rot=(0.0, 0.0, 0.6 * math.sin(2.0 * a)))
    _put(pose, "Spine1", rot=(4.0 * rise, 0.0, -0.8 * math.sin(2.0 * a)))
    _put(pose, "Spine4", rot=(-5.0 * drag, 0.0, 5.0 * math.sin(2.0 * a - 1.0)))
    _put(pose, "TailFin", rot=(-8.0 * math.cos(a - 1.0), 4.0 * math.sin(2.0 * a - 2.2), 9.0 * math.sin(2.0 * a - 1.8)))
    _put(pose, "Dorsal", rot=(-3.0 + 3.0 * math.sin(a - 0.8), 2.5 * math.sin(2.0 * a - 1.4), 0.0))
    _put(pose, "Jaw", rot=(5.0 * breathe, 0.0, 0.0))
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
# The C at full bend: (bone, degrees about Z, pivot as a body fraction, lag in frames). 40 degrees
# from head to tail, 13 in the head and 30 in the back half, spread over the joints by their span
# and turned about the pivots that skin best (S1-A3: solved against weightcheck.py on the base and
# the Minnow; Spine2 stays straight, the head turns on Spine1 alone).
DASH_C = (("Spine1", 13.0, 0.40, 0.0), ("Spine3", -11.0, 0.63, 0.5), ("Spine4", -10.0, 0.79, 1.2),
          ("TailFin", -9.0, 0.93, 2.0))
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
    for bone, angle, pivot, lag in DASH_C:
        rotate_about(pose, bone, (0.0, 0.0, angle * bend(lag)), pivot, k)
    _put(pose, "TailFin", rot=(0.0, 8.0 * bend(2.6), 0.0))
    pose["Pec_L"] = {"rot": (0.0, -6.0 * min(fins, 0.0), 26.0 * fins)}
    pose["Pec_R"] = {"rot": (0.0, 6.0 * min(fins, 0.0), -26.0 * fins)}
    pose["Dorsal"] = {"rot": (-16.0 * fins, 5.0 * bend(1.8), 0.0)}
    return pose


BITE_FLICK = [(0, 0.0), (1, 1.0, "snap"), (2.5, -0.45, "io"), (4, 0.12, "io"), (5, 0.0, "io")]


# The bite's cheeks (06 7.2: "cheeks bulge on frame 2"). RIG_Fish has no cheek bone (06 6.3 lists
# the 18), so the Girth bones make them: Girth_L and Girth_R turn about Z and Girth_Bot about X,
# about a pivot behind the head (CHEEK_PIVOT, a body fraction), so their weight's front half, just
# behind the jaw, swells out and down while the middle of the body stays (the back half narrows a
# little, under the bite's stretch). Degrees at full bulge.
CHEEK_SIDE, CHEEK_THROAT, CHEEK_PIVOT = 30.0, 16.0, 0.55


def cheeks(pose, amount, k=1.0):
    rotate_about(pose, "Girth_L", (0.0, 0.0, CHEEK_SIDE * amount), CHEEK_PIVOT, k)
    rotate_about(pose, "Girth_R", (0.0, 0.0, -CHEEK_SIDE * amount), CHEEK_PIVOT, k)
    rotate_about(pose, "Girth_Bot", (CHEEK_THROAT * amount, 0.0, 0.0), CHEEK_PIVOT, k)
    return pose


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
    bulge = ease_keys(frame, [(0, 0.0), (1, 0.0), (2, 1.0, "snap"), (4, 0.5, "io"), (7, 0.0, "io")])
    brake = ease_keys(frame - 1.0, [(0, 0.0), (1, 0.0), (2, 1.0, "snap"), (4, 0.35, "io"), (7, 0.0, "io")])
    flick = lambda lag: ease_keys(frame - lag, BITE_FLICK)
    pose = fish_stretch_pose(stretch, k)
    lunge_slide(pose, lunge, k)
    _put(pose, "Spine1", rot=(nod, 0.0, 0.0))
    _put(pose, "Jaw", rot=(jaw, 0.0, 0.0))
    cheeks(pose, bulge, k)
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
    "A_Fish_Dash": (fish_dash_pose, [(0, "start"), (1, "wind-up"), (2, "squash 85%, C"), (4, "snap 125%"), (8, "hold"),
                                     (10, "overshoot 95%"), (14, "settled")]),
    "A_Fish_Bite": (fish_bite_pose, [(0, "jaw opening"), (1, "wind-up"), (2, "snap, lunge, cheeks"), (3, "cheeks"),
                                     (4, "stretch 115%"), (6, "rebound"), (8, "settled")]),
}
