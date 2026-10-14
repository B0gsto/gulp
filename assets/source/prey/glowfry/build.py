"""M_Prey_Glowfry with its cells of T_TraitPrey_01_Alb and T_TraitPrey_Emi, and its outline shell
M_Prey_Glowfry_Shell: task S6-A1 (docs/13-sprint-plan.md Sprint 6; docs/07-asset-list.md section
4.2 rows M_Prey_Glowfry, T_TraitPrey_01_Alb, T_TraitPrey_Emi; docs/03-content-catalog.md section
3.2 glowfry; docs/06-art-bible.md sections 3.3, 3.4, 4.1, 4.3, 5, 6.3, 7.6, 13.2).

    Blender --background --python assets/source/prey/glowfry/build.py

Glowfry, the trait prey that gives Glow, tier 1, 0.9 studs long (03 3.2): a tiny round fry,
warm yellow, with a glowing belly like a lantern, "the only light inside a dark hole". It is
the creature that teaches the first trait (04 B5), so it must read as special at a glance and
never as an ordinary prey: a round body with a big round head, very large eyes with a golden
ring, a flared fan tail with a shallow fork and stubby fins (06 3.4: food is circles, huge eyes, short round fins),
and under it the lantern, a lit near-white disc on the belly and lower flanks, set off by a
slightly deeper yellow around it, whose core glows (T_TraitPrey_Emi). No plain prey has that
silhouette or that light. Rigid, no bones
(06 7.6 data:PreyMotion: drawn `rigid`, the client wobbles it and pulses the glow at 0.8 Hz).

Colour (06 4.3 glowfry row, built from the darter's palette as 06 4.3 asks of trait prey): mid
#E6C029 back and flank (the darter's yellow, two degrees further from lantern amber and inside
the mid block's L* 45 to 80), light #FFE98A the lantern belly and the eye rings (the Glow
signature colour, 06 8.2), dark #1B5662 the pupils, the tail's edge, the back fin's crest,
the pectoral tips and a saddle at the tail root (the darter's teal at L* 33). No accent. Painted by script (06 5.2): every texel
of its cell traced back to the mesh, large soft gradients, head lightest and most saturated,
shadows toward violet, lights toward yellow, wet highlight and eye glints, then Cycles occlusion
(06 5.5, baked from a subdivided copy so the low-poly body shows no facets) multiplied in at 30%
tinted #5A4FA0.

408 triangles (06 6.3 trait prey 300 to 700; 07 4.2's 300 was raised to 410 in task S6-A1, a
round body needs 16 sides). Body depth 58% of the body length (06 3.3's note on round trait prey). The shell (run.py step shell,
versions.py) is 10% of body height (06 13.2, 07 4), at most 40% of the body's triangles
(06 6.3). No LOD (06 6.4: prey under tier 3 ship one mesh).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "_shared", "blender"))

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402
import meshgen  # noqa: E402
import texbake  # noqa: E402
import traitbake  # noqa: E402
import traitpreyart as tpa  # noqa: E402

NAME = "M_Prey_Glowfry"
PREY = "glowfry"
ALBEDO = "T_TraitPrey_01_Alb"
EMI = tpa.EMI
LENGTH = 0.9                      # 03 3.2 (radius 0.45 in 03 3.1)
ZONES = ("nursery", "reef", "kelp")   # 03 3.2: Reef caves and Kelp; five scripted in the Nursery
LIGHT, MID, DARK = (common.colour("creatures.glowfry." + k) for k in ("light", "mid", "dark"))
GLOW = common.colour("traits.glow.signature")
PAINT = 2                         # painted at twice the atlas size, then filtered down
BLOCKS = ("mid", "light", "dark", "accent")

# ---------------------------------------------------------------- shape (studs; nose on -Y, 06 6.1)

Y_NOSE, Y_ROOT, Y_TIP = -0.45, 0.17, 0.45     # body from the nose to the tail root, then the paddle tail
SEGS = 16                          # around the body: vertex lines on the back, belly and both flanks
RING_T = (0.03, 0.09, 0.18, 0.30, 0.44, 0.59, 0.75, 0.90)
SQUARE = 0.86                      # section exponent: a plump, slightly full section


def _egg(t, tc, end):
    """1 at tc, a round front (an ellipse quarter) to 0 at the nose, a soft taper to `end` at the root."""
    t = np.asarray(t, dtype=float)
    front = np.sqrt(np.clip(1.0 - ((tc - t) / tc) ** 2, 0.0, 1.0))
    back = end + (1.0 - end) * 0.5 * (1.0 + np.cos(np.pi * np.clip((t - tc) / (1.0 - tc), 0.0, 1.0)))
    return np.where(t <= tc, front, back)


def top(t):
    """The back: a round head with a soft forehead bump, then the taper to the tail root."""
    return 0.176 * _egg(t, 0.40, 0.25) + 0.012 * np.exp(-((np.asarray(t, dtype=float) - 0.20) / 0.10) ** 2)


def bot(t):
    """The belly: deepest at the lantern, under the middle of the body."""
    return 0.178 * _egg(t, 0.48, 0.20)


def half_w(t):
    return 0.158 * _egg(t, 0.40, 0.19)


def z_mid(t):
    return -0.012 * (1.0 - t) + 0.004 * t


def y_of(t):
    return Y_NOSE + (Y_ROOT - Y_NOSE) * t


def t_of(y):
    return (y - Y_NOSE) / (Y_ROOT - Y_NOSE)


def section(t, a):
    """Point at angle a around the body at station t (a = 0 on the back, pi on the belly)."""
    s, c = math.sin(a), math.cos(a)
    sq = lambda v: math.copysign(abs(v) ** SQUARE, v)
    x = float(half_w(t)) * sq(s)
    z = float(z_mid(t)) + (float(top(t)) if c >= 0.0 else float(bot(t))) * sq(c)
    return (x, y_of(t), z)


def body_part():
    rings = [[section(t, 2.0 * math.pi * j / SEGS) for j in range(SEGS)] for t in RING_T]
    return meshgen.loft(rings, (0.0, Y_NOSE, float(z_mid(0.0)) - 0.01), (0.0, Y_ROOT, float(z_mid(1.0))))


def slab(outline, tris, half, normal=(1.0, 0.0, 0.0)):
    """A closed thin volume (06 6.5: fins at least 0.03 studs thick) from a planar outline."""
    n = len(outline)
    nv = Vector(normal).normalized()
    verts = [tuple(Vector(p) + nv * half) for p in outline] + [tuple(Vector(p) - nv * half) for p in outline]
    faces = [tuple(t) for t in tris] + [tuple(n + i for i in reversed(t)) for t in tris]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, n + i, n + j, j))
    params = [(i / max(n - 1, 1), 0.0) for i in range(n)] * 2
    return verts, faces, params


def fan(n):
    return [(0, i, i + 1) for i in range(1, n - 1)]


TAIL = [(0.140, -0.030), (0.262, -0.070), (0.382, -0.112), (0.450, -0.090), (0.418, 0.004),
        (0.450, 0.098), (0.382, 0.118), (0.262, 0.078), (0.140, 0.040)]       # a fan with a shallow fork
TAIL_HALF = 0.016


def tail_part():
    pts = [(0.0, y, z) for y, z in TAIL]
    return slab(pts, fan(len(pts)), TAIL_HALF)


DORSAL_T = (0.50, 0.80)


def dorsal_outline():
    ya, yb = y_of(DORSAL_T[0]), y_of(DORSAL_T[1])
    za, zb = float(z_mid(DORSAL_T[0]) + top(DORSAL_T[0])) - 0.022, float(z_mid(DORSAL_T[1]) + top(DORSAL_T[1])) - 0.02
    return [(0.0, ya, za), (0.0, ya + 0.028, za + 0.060), (0.0, ya + 0.090, za + 0.068),
            (0.0, yb - 0.006, zb + 0.040), (0.0, yb, zb)]


def dorsal_part():
    return slab(dorsal_outline(), fan(5), 0.015)


PEC_T = 0.40


def pec_frame(side):
    """Root on the lower flank behind the eye; the paddle swept back, out and a little down."""
    t = PEC_T
    a = math.radians(118.0)
    root = Vector(section(t, a if side > 0 else -a))
    root.x -= side * 0.012
    back = Vector((side * 0.55, 1.0, -0.38)).normalized()
    normal = Vector((side * -0.35, 0.10, 1.0)).normalized()
    across = normal.cross(back).normalized()
    return root, back, across, normal


def pec_part(side):
    root, back, across, normal = pec_frame(side)
    pts = [root + across * 0.026, root + back * 0.085 + across * 0.034,
           root + back * 0.105 - across * 0.010, root - across * 0.022]
    return slab([tuple(p) for p in pts], fan(4), 0.015, normal)


EYE_T = 0.235
EYE_R = 0.068                      # 41% of the head height where it sits (06 3.3 prey: 36 to 42%)
EYE_Z = 0.034
EYE_SEGS = 10
EYE_RINGS = (38.0, 90.0)           # polar angles of the two rings from the outer pole


def eye_frame(side):
    t = EYE_T
    hw = float(half_w(t)) * (1.0 - (EYE_Z / float(top(t))) ** 2) ** 0.5
    c = Vector((side * (hw - 0.42 * EYE_R), y_of(t), float(z_mid(t)) + EYE_Z))
    axis = Vector((side * 1.0, -0.48, 0.12)).normalized()
    up = Vector((0.0, 0.0, 1.0))
    b1 = up.cross(axis).normalized()            # across the eye, toward the nose on both sides
    if b1.y > 0:
        b1 = -b1
    b2 = axis.cross(b1).normalized()
    if b2.z < 0:
        b2 = -b2
    return c, axis, b1, b2


def eye_part(side):
    """A dome of two rings over the outer pole, closed inside the head by a flat fan."""
    c, axis, b1, b2 = eye_frame(side)
    rings = []
    for polar in EYE_RINGS:
        p = math.radians(polar)
        rings.append([tuple(c + EYE_R * (math.cos(p) * axis + math.sin(p) * (math.cos(b) * b1 + math.sin(b) * b2)))
                      for b in (2.0 * math.pi * j / EYE_SEGS for j in range(EYE_SEGS))])
    return meshgen.loft(rings, tuple(c + EYE_R * axis), tuple(c - 0.55 * EYE_R * axis))


# ---------------------------------------------------------------- UVs: the Glowfry's cell (traitpreyart)

# Islands inside the 128 x 128 cell (fu, fv: 0..1, fv 0 at the cell's foot), 4 px apart.
ISLAND = {
    "body": (0.0, 0.31, 0.70, 1.0),
    "tail": (0.735, 0.50, 1.0, 1.0),
    "dorsal": (0.735, 0.31, 1.0, 0.465),
    "pec": (0.0, 0.0, 0.30, 0.275),
    "eye": (0.335, 0.0, 0.61, 0.275),
    "eye_back": (0.645, 0.0, 0.70, 0.05),
}
KIND = {"body": 0, "tail": 1, "dorsal": 2, "pec": 3, "eye": 4}


def island_uv(name, fu, fv):
    u0, v0, u1, v1 = ISLAND[name]
    return tpa.cell_uv(PREY, u0 + (u1 - u0) * min(1.0, max(0.0, fu)), v0 + (v1 - v0) * min(1.0, max(0.0, fv)))


def tail_param(p):
    ys = [y for y, _ in TAIL]
    zs = [z for _, z in TAIL]
    fu = (p.y - min(ys)) / (max(ys) - min(ys))
    fv = (p.z - min(zs)) / (max(zs) - min(zs))
    return fu, fv


def dorsal_param(p):
    pts = dorsal_outline()
    ys, zs = [q[1] for q in pts], [q[2] for q in pts]
    return (p.y - min(ys)) / (max(ys) - min(ys)), (p.z - min(zs)) / (max(zs) - min(zs))


def pec_param(p, side):
    root, back, across, normal = pec_frame(side)
    d = p - root
    return (d.dot(back) + 0.005) / 0.115, (d.dot(across) + 0.028) / 0.066


def eye_param(p, side):
    c, axis, b1, b2 = eye_frame(side)
    d = p - c
    return 0.5 + 0.5 * d.dot(b1) / EYE_R, 0.5 + 0.5 * d.dot(b2) / EYE_R


def body_param(p, q):
    t = min(1.0, max(0.0, t_of(p.y)))
    if abs(p.y - Y_NOSE) < 1e-6 or abs(p.y - Y_ROOT) < 1e-6:
        s = 0.5                    # the poles sit at mid-height in the unwrap
    else:
        s = q[1]                   # loft: 0 on the back line, 1 on the belly line, mirrored sides
    return t, s


def glowfry_meshdata():
    """Body, tail, back fin, pectorals and eyes, each a closed volume; also the paint attributes of
    every vertex: [kind, a, b] (body: t along, s around; tail and fins: their own 0..1 params)."""
    md = meshgen.MeshData()
    attrs = []

    def add(part, kind, uv, param, tag=0):
        before = len(md.verts)
        md.add_part(part, MID, uv=uv, tag=tag)
        verts, _, params = part
        for p, q in zip(verts, params):
            a, b = param(Vector(p), q)
            attrs.append((KIND[kind], a, b))
        assert len(attrs) == len(md.verts) == before + len(verts)

    add(body_part(), "body", lambda p, q: island_uv("body", *(lambda t, s: (t, 1.0 - s))(*body_param(p, q))), body_param)
    add(tail_part(), "tail", lambda p, q: island_uv("tail", *tail_param(p)), lambda p, q: tail_param(p))
    add(dorsal_part(), "dorsal", lambda p, q: island_uv("dorsal", *dorsal_param(p)), lambda p, q: dorsal_param(p))
    for side in (1.0, -1.0):
        add(pec_part(side), "pec", lambda p, q, s=side: island_uv("pec", *pec_param(p, s)), lambda p, q, s=side: pec_param(p, s))
    for side in (1.0, -1.0):
        f0 = len(md.faces)
        add(eye_part(side), "eye", lambda p, q, s=side: island_uv("eye", *eye_param(p, s)),
            lambda p, q, s=side: eye_param(p, s), tag=common.TAG_FRONT)
        # The fan that closes the dome inside the head is never seen: give it its own sliver of
        # the cell, so it neither overwrites the visible eye's texels nor its occlusion.
        n_faces = len(md.faces) - f0
        u0, v0 = island_uv("eye_back", 0.2, 0.3)
        u1, v1 = island_uv("eye_back", 0.8, 0.7)
        for fi in range(f0 + n_faces - EYE_SEGS, f0 + n_faces):
            md.corner_uvs[fi] = [(u0, v0), ((u0 + u1) / 2.0, v1), (u1, v0)][:len(md.faces[fi])]
    return md, np.array(attrs, dtype=float)


def flat_fins(obj, attrs):
    """Fins and the tail are thin flat slabs: flat-shaded, so their broad faces light evenly
    instead of in facets (06 6.5: smooth shading, hard edges only where intended)."""
    kinds = np.rint(attrs[:, 0]).astype(int)
    flat = [bool(kinds[p.vertices[0]] in (KIND["tail"], KIND["dorsal"], KIND["pec"])) for p in obj.data.polygons]
    obj.data.polygons.foreach_set("use_smooth", [not f for f in flat])
    obj.data.update()


def fit(obj):
    """Scaled to 0.9 studs long, origin at the middle of length and height (06 6.1, 6.2)."""
    vs = obj.data.vertices
    lo = Vector([min(v.co[i] for v in vs) for i in range(3)])
    hi = Vector([max(v.co[i] for v in vs) for i in range(3)])
    c = (lo + hi) / 2.0
    c.x = 0.0
    k = LENGTH / (hi.y - lo.y)
    obj.data.transform(Matrix.Scale(k, 4) @ Matrix.Translation(-c))
    obj.data.update()
    return (hi - lo) * k, k, c


# ---------------------------------------------------------------- the paint (06 section 5.2)

_VIOLET = None
_LIGHTEN = None


def shade(base_hex, sv, fade=0.0):
    """A block colour shaded by sv in -1..1: at most 6 L* either way (06 4.1: 12 across a block).
    Shadows lean toward the blue-violet #5A4FA0 in a*b*; lights lean toward a pale lemon (HSV hue
    about 51, away from lantern amber, 06 4.5); `fade` takes up to 15% of the chroma toward the tail."""
    global _VIOLET, _LIGHTEN
    if _VIOLET is None:
        _VIOLET = texbake.srgb_to_lab(texbake.hex_rgb("#5A4FA0"))[1:]
        _LIGHTEN = texbake.srgb_to_lab(texbake.hex_rgb("#FFF2A6"))[1:]
    lo = -2.0 if base_hex == DARK else -1.5 if base_hex == MID else -1.0   # 06 4.1: 12 L* across a block
    sv = np.clip(np.asarray(sv, dtype=float), lo, 1.0)
    lab = np.broadcast_to(texbake.srgb_to_lab(texbake.hex_rgb(base_hex)), sv.shape + (3,)).copy()
    dark = np.clip(-sv, 0.0, 1.0)[..., None] * (0.5 if base_hex == DARK else 1.0)
    light = np.clip(sv, 0.0, 1.0)[..., None]
    lab[..., 1:] += 0.18 * dark * (_VIOLET - lab[..., 1:]) + 0.22 * light * (_LIGHTEN - lab[..., 1:])
    lab[..., 1:] *= (1.0 - 0.15 * np.clip(np.asarray(fade, dtype=float), 0.0, 1.0))[..., None]
    lab[..., 0] = np.minimum(100.0, lab[..., 0] + 6.0 * sv)
    return texbake.lab_to_srgb(lab)


def lantern(t, s):
    """The lantern on the belly: r 0 at its core, 1 at its edge (t along, s around, 1 on the belly line)."""
    return np.hypot((t - 0.47) / 0.27, (s - 1.0) / 0.60)


FIT = {"k": 1.0, "c": (0.0, 0.0, 0.0)}     # the fit's scale and offset, so paint can work in build units


def body_ts(P, t_attr, s_attr):
    """t and s of body texels from their 3D point (smooth across triangles, unlike interpolated
    attributes): t from y, s from the angle around the section (inverse of `section`)."""
    k, c = FIT["k"], np.array(FIT["c"])
    Q = P / k + c
    t = np.clip(t_of(Q[:, 1]), 0.0, 1.0)
    hw = np.maximum(half_w(t), 1e-6)
    zm = z_mid(t)
    dz = Q[:, 2] - zm
    H = np.where(dz >= 0.0, top(t), bot(t))
    sx = np.clip(np.abs(Q[:, 0]) / hw, 0.0, 1.0) ** (1.0 / SQUARE)
    cz = np.sign(dz) * np.clip(np.abs(dz) / np.maximum(H, 1e-6), 0.0, 1.0) ** (1.0 / SQUARE)
    s = np.arctan2(sx, cz) / np.pi
    near_pole = (t < 0.02) | (t > 0.985)
    return t, np.where(near_pole, s_attr, s)


GLOW_CORE = 0.70                   # the glow mask is full inside this share of the lantern, then falls to its edge


def paint(kind, a, b, P, N):
    """Block (0 mid, 1 light, 2 dark), painted sRGB and glow mask at texels of each kind."""
    n = len(kind)
    blk = np.zeros(n, dtype=int)
    col = np.zeros((n, 3))
    glow = np.zeros(n)
    up = np.clip(N[:, 2], -1.0, 1.0)

    # Body: t along, s around (0 back line, 1 belly line).
    m = kind == KIND["body"]
    t, s = body_ts(P[m], a[m], b[m])
    r = lantern(t, s)
    head = 1.0 - texbake.smoothstep(0.05, 0.55, t)
    sv = 0.45 + 0.3 * head - 0.35 * texbake.smoothstep(0.45, 0.85, s) + 0.15 * up[m]
    sv = np.minimum(sv, 0.5) + 0.5 * np.exp(-(((t - 0.17) / 0.10) ** 2 + ((s - 0.20) / 0.10) ** 2))   # wet highlight on the brow
    c = shade(MID, sv, texbake.smoothstep(0.3, 1.0, t))
    k = np.zeros(len(t), dtype=int)
    # The lantern: light block, a near-white core over most of the Glow colour's disc with a
    # short falloff to its edge, so it reads as one bright lit shape at any size.
    lit = r <= 1.0
    lv = 0.95 * (1.0 - texbake.smoothstep(0.68, 0.98, r)) - 0.2 * texbake.smoothstep(0.92, 1.0, r)
    c = np.where(lit[:, None], shade(LIGHT, lv), c)
    # the core goes toward white (the lamp itself): chroma falls to a third, inside the block's 12 L*
    core_w = (1.0 - texbake.smoothstep(0.45, 0.88, r)) * lit
    lab = texbake.srgb_to_lab(c)
    lab[:, 1:] *= (1.0 - 0.6 * core_w)[:, None]
    c = np.where(lit[:, None], texbake.lab_to_srgb(lab), c)
    k = np.where(lit, 1, k)
    g = np.where(r < GLOW_CORE, 1.0 - 0.15 * (r / GLOW_CORE) ** 2, 0.85 * (1.0 - texbake.smoothstep(GLOW_CORE, 0.86, r)))
    g = np.where(lit, g, 0.0)
    # Around it, the body's yellow deepens a little (inside the mid block's 12 L*), so the lit
    # shape stands out by value at 20 px without a drawn line.
    ring = (r > 1.0) & (r < 1.28)
    deep = (1.0 - texbake.smoothstep(1.0, 1.28, r)) * ring
    c = np.where(ring[:, None], shade(MID, np.clip(sv, -1, 1) * (1 - deep) - 1.5 * deep, texbake.smoothstep(0.3, 1.0, t)), c)
    # The tail root: a dark saddle over the back, so the tail end reads from the game camera.
    line = (t > 0.865 + 0.05 * (s / 0.52) ** 2) & (s < 0.52)
    c = np.where(line[:, None], shade(DARK, -1.4 - 0.4 * texbake.smoothstep(0.875, 1.0, t)), c)
    k = np.where(line, 2, k)
    # The mouth: a small dark smile at the nose (06 3.4: a dot or a small smile).
    smile = (t < 0.055) & (np.abs(s - (0.62 - 1.2 * t)) < 0.032) & (t > 0.004)
    c = np.where(smile[:, None], shade(DARK, -1.6), c)
    k = np.where(smile, 2, k)
    blk[m], col[m], glow[m] = k, c, g

    # Tail: mid at the root, lighter and paler out along the paddle, a dark edge, three soft rays.
    m = kind == KIND["tail"]
    fu, fv = a[m], b[m]
    zc = (fv - 0.48) * 2.0
    edge = (fu > 0.78) | ((np.abs(zc) > 0.80) & (fu > 0.45))
    ray = sum(np.exp(-((zc - z0) / 0.07) ** 2) for z0 in (-0.42, 0.0, 0.42)) * texbake.smoothstep(0.2, 0.6, fu)
    c = shade(MID, 0.15 + 0.45 * texbake.smoothstep(0.1, 0.8, fu) - 0.35 * np.clip(ray, 0, 1), 0.6)
    c = np.where(edge[:, None], shade(DARK, -1.5 - 0.3 * fu), c)
    blk[m], col[m] = np.where(edge, 2, 0), c

    # Back fin: mid, a dark crest.
    m = kind == KIND["dorsal"]
    crest = b[m] > 0.50
    blk[m] = np.where(crest, 2, 0)
    col[m] = np.where(crest[:, None], shade(DARK, -1.6), shade(MID, 0.25 + 0.3 * b[m], 0.4))

    # Pectorals: mid, lighter at the tip.
    m = kind == KIND["pec"]
    tip = a[m] > 0.74
    blk[m] = np.where(tip, 2, 0)
    col[m] = np.where(tip[:, None], shade(DARK, -1.5), shade(MID, 0.1 + 0.5 * texbake.smoothstep(0.2, 1.0, a[m]), 0.3))

    # Eyes, by their place on the eye's disc (the same on both eyes): a big dark pupil (06 3.3 prey:
    # 65% of the eye), a golden ring of the Glow colour around it, two glints.
    m = kind == KIND["eye"]
    du, dv = (a[m] - 0.5) * 2.0, (b[m] - 0.5) * 2.0
    rho = np.hypot(du, dv)
    pupil = rho < 0.65
    c = np.where(pupil[:, None], shade(DARK, -1.7 + 0.9 * texbake.smoothstep(-0.05, -0.45, dv) * (rho > 0.3)),
                 shade(LIGHT, 0.2 - 0.9 * texbake.smoothstep(0.7, 1.0, rho)))
    k = np.where(pupil, 2, 1)
    glint = (np.hypot(du + 0.20, dv - 0.28) < 0.25) | (np.hypot(du - 0.24, dv + 0.22) < 0.10)
    c = np.where(glint[:, None], texbake.hex_rgb("#FFFFFF"), c)
    k = np.where(glint, 1, k)
    blk[m], col[m] = k, c
    return blk, col, glow


def paint_cell(body, attrs):
    """The Glowfry's albedo cell, glow cell and block map: rasterised at twice the atlas size,
    painted, filtered down, occlusion multiplied in, bled inside the cell (06 5.5)."""
    big = tpa.SIZE * PAINT
    ras = texbake.rasterise(body, big, vattrs=attrs)
    filled = ras["filled"]
    A = ras["attrs"]
    kind = np.rint(A[filled][:, 0]).astype(int)
    blk, col, glow = paint(kind, A[filled][:, 1], A[filled][:, 2], ras["P"][filled], ras["N"][filled])
    rgb = np.zeros((big, big, 3))
    gmap = np.zeros((big, big))
    block = np.full((big, big), -1, dtype=int)
    rgb[filled], gmap[filled], block[filled] = col, glow, blk
    bounds = tpa.cell_bounds(PREY, PAINT)
    rgb = texbake.dilate(rgb, filled, 6, bounds)
    small = texbake.downsample(rgb, PAINT)
    cover = texbake.downsample(filled.astype(float), PAINT)
    gsmall = texbake.downsample(gmap, PAINT)
    gsmall = np.where(cover > 0, gsmall / np.maximum(cover, 1e-6), 0.0)
    ao = texbake.bake_occlusion(body, tpa.SIZE, tag="glowfry", subdivide=2)
    if ao is not None:
        # Normalised to the open surface (the 90th percentile of the cell), so only crevices darken:
        # fin roots, eye sockets, under the tail. A tiny convex body is otherwise dimmed all over.
        r0, r1, c0, c1 = tpa.cell_bounds(PREY)
        cell_ao = ao[r0:r1, c0:c1][cover[r0:r1, c0:c1] > 0]
        open_level = max(float(np.percentile(cell_ao, 90)), 1e-3) if len(cell_ao) else 1.0
        print("[glowfry] occlusion: open surface %.2f, median %.2f" % (open_level, float(np.median(cell_ao)) if len(cell_ao) else 1.0))
        amt = 0.30 * (1.0 - np.clip(ao / open_level, 0.0, 1.0))
        lab = texbake.srgb_to_lab(small)
        lab[..., 0] -= 14.0 * amt
        violet = texbake.srgb_to_lab(texbake.hex_rgb("#5A4FA0"))[1:]
        lab[..., 1:] += 0.5 * amt[..., None] * (violet - lab[..., 1:])
        small = texbake.lab_to_srgb(lab)
    # 06 4.1: inside a block the lightness moves at most 12 L* (occlusion included); hold each
    # texel that lies wholly in one block to that block's band.
    sub = block.reshape(tpa.SIZE, PAINT, tpa.SIZE, PAINT).transpose(0, 2, 1, 3).reshape(tpa.SIZE, tpa.SIZE, PAINT * PAINT)
    whole = (sub == sub[..., :1]).all(-1) & (sub[..., 0] >= 0)
    keys = sub[..., 0]
    lab = texbake.srgb_to_lab(small)
    bands = {0: (common.lstar(MID) - 9.0, common.lstar(MID) + 3.0), 1: (86.5, 98.5), 2: (21.5, 33.5)}
    for kb, (lo, hi) in bands.items():
        sel = whole & (keys == kb)
        lab[sel, 0] = np.clip(lab[sel, 0], lo, hi)
    glint_white = whole & (keys == 1) & (small.min(-1) > 0.97)
    small = np.where((whole & ~glint_white)[..., None], texbake.lab_to_srgb(lab), small)
    # 06 4.5: the yellow sits two degrees outside lantern amber; shading must not drift it inward.
    small, moved = texbake.hold_out_of_band(small, 26.0, 46.0, margin=1.5)
    print("[glowfry] %d texels held outside the lantern amber band (06 4.5)" % moved)
    on = cover > 0
    r0, r1, c0, c1 = tpa.cell_bounds(PREY)
    small = texbake.dilate(small, on, tpa.MARGIN + 4, (r0, r1, c0, c1))
    gsmall = texbake.dilate(gsmall, on, tpa.MARGIN + 4, (r0, r1, c0, c1))
    return {"albedo": np.clip(small, 0.0, 1.0)[r0:r1, c0:c1], "glow": np.clip(gsmall, 0.0, 1.0)[r0:r1, c0:c1],
            "block": block, "on": on, "ao": ao is not None, "atlas_rgb": np.clip(small, 0.0, 1.0)}


# ---------------------------------------------------------------- preview helpers

def textured(name, albedo, glow, strength=1.5):
    """Matte as in game (06 5.1: colour map and 85% roughness) with the glow mask as emission in
    the lantern's light colour, so the preview shows what the emissive mask does."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = texbake.blender_image("IMG_" + name, albedo)
    tex.interpolation = 'Linear'
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Metallic"].default_value = 0.0
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if glow is not None:
        gt = nt.nodes.new("ShaderNodeTexImage")
        gt.image = texbake.blender_image("IMG_%s_glow" % name, glow, colorspace="Non-Color")
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = 'MULTIPLY'
        mul.inputs[1].default_value = strength
        nt.links.new(gt.outputs["Color"], mul.inputs[0])
        bsdf.inputs["Emission Color"].default_value = (*common.hex_to_linear(GLOW), 1.0)
        nt.links.new(mul.outputs[0], bsdf.inputs["Emission Strength"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def lineup_copy(src, name, length):
    """A copy of a look-alike scaled to `length` studs, for the equal-length line-up (06 15.5 cell 9)."""
    o = src.copy()
    o.data = src.data.copy()
    o.name = name
    for c in list(o.users_collection):
        c.objects.unlink(o)
    bpy.data.collections["PREVIEW"].objects.link(o)
    for mod in list(o.modifiers):
        o.modifiers.remove(mod)
    o.parent = None
    vs = o.data.vertices
    ys = [v.co.y for v in vs]
    k = length / (max(ys) - min(ys))
    o.data.transform(Matrix.Scale(k, 4))
    o.matrix_world = Matrix.Identity(4)
    return o


def krill_lookalike():
    """M_Prey_Krill as its own build makes it (prey/krill), textured, for the line-up."""
    import importlib.util
    import preyart
    spec = importlib.util.spec_from_file_location("gulp_krill_build", os.path.join(HERE, "..", "krill", "build.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    img, _ = preyart.atlas()
    work = os.path.join(common.review_dir(NAME), "lineup_T_PreySmall_Alb.png")
    preyart.save_rgba(work, img)
    obj = mod.krill_meshdata().to_object("PV_Krill", "PREVIEW", material=preyart.material("MAT_PV_Krill", work))
    mod.fit(obj)
    return obj


def lantern_glow_sheet(cells):
    """The two textures side by side for the sheet: the atlas and its glow mask (06 15.5 cell 12)."""
    alb = tpa.compose(cells["alb"])
    emi = tpa.compose(cells["emi"], kind="emi")
    gap = np.ones((tpa.SIZE, 8, 3)) * texbake.hex_rgb(common.colour("ui.panel"))
    return np.concatenate([alb, gap, np.repeat(emi[..., None], 3, -1)], 1)


# ---------------------------------------------------------------- the asset

def build():
    md, attrs = glowfry_meshdata()
    body = md.to_object(NAME, "GEO")
    size, k, centre = fit(body)
    FIT.update(k=k, c=tuple(centre))
    flat_fins(body, attrs)
    print("[glowfry] size x %.3f y %.3f z %.3f studs, scale %.4f" % (tuple(size) + (k,)))
    depth = float(np.max(top(np.linspace(0, 1, 200)) + bot(np.linspace(0, 1, 200)))) * k
    print("[glowfry] body depth %.3f studs = %.0f%% of the body length (nose to tail root, %.3f); head to t %.2f"
          % (depth, 100.0 * depth / ((Y_ROOT - Y_NOSE) * k), (Y_ROOT - Y_NOSE) * k, 0.47))

    review = common.review_dir(NAME)
    lit_path = os.path.join(review, "textures_preview.png")
    state = {}

    def bake(spec):
        cells = paint_cell(body, attrs)
        state.update(cells)
        body.data.materials[0] = textured("MAT_" + NAME, cells["atlas_rgb"], tpa.compose({PREY: cells["glow"]}, "emi"))
        dark_mat = textured("MAT_%s_Dark" % NAME, cells["atlas_rgb"], tpa.compose({PREY: cells["glow"]}, "emi"), strength=4.0)
        state["dark_mat"] = dark_mat
        texbake.save_png(lit_path, lantern_glow_sheet({"alb": {PREY: cells["albedo"]}, "emi": {PREY: cells["glow"]}}))
        em = traitbake.coverage(body, tpa.compose({PREY: cells["glow"]}, "emi"))
        state["emissive"] = em
        spec["texture_sampler"] = sampler
        spec["palette"]["texels"] = cells["atlas_rgb"][cells["on"]]
        spec["palette"]["emissive"] = [{"name": EMI + " (glowfry cell)", "lit_share": em["lit_share"]}]
        return {"occlusion": "baked" if cells["ao"] else "NOT baked", "emissive_lit_share": round(em["lit_share"], 4),
                "emissive_mean": round(em["mean"], 4)}

    def sampler(u, v):
        big = tpa.SIZE * PAINT
        r = min(big - 1, max(0, int(v * big)))
        c = min(big - 1, max(0, int(u * big)))
        kb = state["block"][r, c]
        rr, cc = min(tpa.SIZE - 1, r // PAINT), min(tpa.SIZE - 1, c // PAINT)
        return (BLOCKS[kb] if kb >= 0 else None), tuple(float(x) for x in state["atlas_rgb"][rr, cc])

    def write_albedo(path):
        return texbake.save_png(path, tpa.compose({PREY: state["albedo"]}), mode="RGB")

    def write_emi(path):
        return texbake.save_png(path, tpa.compose({PREY: state["glow"]}, "emi"), mode="L")

    def check_files(spec, report):
        for name, mode in ((ALBEDO, "RGB"), (EMI, "L")):
            path = os.path.join(common.EXPORT_DIR, "textures", name + ".png")
            info = texbake.png_info(path) if os.path.exists(path) else None
            if info:
                report.add(name + ".png", "texture mode", info[0] == mode and info[1] == info[2] == tpa.SIZE,
                           "%s %d x %d, want %s %d x %d (06 5.1: 24-bit colour; 8-bit greyscale glow mask)"
                           % (info[0], info[1], info[2], mode, tpa.SIZE, tpa.SIZE))

    krill = krill_lookalike()
    minnow = lineup_copy(bpy.data.objects["REF_Minnow_T1"], "PV_Minnow_Equal", LENGTH)
    krill_eq = lineup_copy(krill, "PV_Krill_Equal", LENGTH)
    krill_eq.data.materials[0] = krill.data.materials[0]
    for o in (krill,):
        o.hide_render = True
        o.matrix_world = Matrix.Translation((0.0, 0.0, -50.0))
    dark_copy = body.copy()
    dark_copy.data = body.data.copy()
    dark_copy.name = "PV_Glowfry_Dark"
    bpy.data.collections["PREVIEW"].objects.link(dark_copy)

    def dark_material(spec):
        dark_copy.data.materials[0] = state["dark_mat"]
        return {}

    def emissive_check(spec, report):
        em = state["emissive"]
        report.add(NAME, "glow mask coverage", em["lit_share"] <= traitbake.EMISSIVE_CAP,
                   "%s lights %.1f%% of the visible surface (mask 0.5 or more; mean %.2f), cap 15%% (06 5.1)"
                   % (EMI, 100.0 * em["lit_share"], em["mean"]))

    return {
        "name": NAME,
        "category": "Prey",
        "id": PREY,
        "tier": 1,
        "budget": "trait_prey",
        "uv": {"texture": "trait_prey_atlas"},
        "origin": "creature",
        "size": (size.x, LENGTH, size.z),
        "size_tol": 0.02,
        "facing": {"kind": "tag"},
        "meshes": [{"object": body, "role": "body", "primary": True}],
        "bake": [bake, dark_material],
        "texture_name": "%s glowfry cell, painted by script" % ALBEDO,
        "palette": {"zones": list(ZONES)},
        "extra_checks": [emissive_check],
        "post_export_checks": [check_files],
        "exports": [{"file": "meshes/%s.fbx" % NAME, "objects": [body]}],
        "textures": [
            {"file": "textures/%s.png" % ALBEDO, "write": write_albedo, "max": tpa.SIZE},
            {"file": "textures/%s.png" % EMI, "write": write_emi, "max": tpa.SIZE},
        ],
        "preview": {
            "main": [body],
            "blocks": {"mid": MID, "light": LIGHT, "dark": DARK},
            "lineup": [
                {"label": "M_Prey_Glowfry, 0.9 studs", "objects": [body]},
                {"label": "M_Prey_Krill at 0.9", "objects": [krill_eq]},
                {"label": "tier-1 Minnow silhouette at 0.9", "objects": [minnow]},
            ],
            "lineup_caption": ["equal length; the Pufferfish (a yellow ball, 2.4 studs) and Reef Darter are not built yet",
                               "Glowfry: round body, lantern belly, paddle tail"],
            "extras": [
                {"title": "Front", "view": "Front", "objects": [body], "caption": ["eyes stand out past the head; lantern underneath"]},
                {"title": "In a dark hole: deep Drop-off fog", "view": "ThreeQuarter", "objects": [dark_copy], "backdrop": "dropoff_deep",
                 "light_scale": 0.12,
                 "caption": ["03: the only light inside a dark hole; preview lights at 12%",
                             "glow mask at full pulse (06 7.6: 0.8 Hz, +-0.3); no bloom"]},
                {"title": "Textures: atlas cell and glow mask", "picture": lit_path,
                 "caption": ["%s (Glowfry top-left; other cells later rows) and %s, 256 x 256 each" % (ALBEDO, EMI)]},
            ],
            "texture": "%s and %s 256 x 256 (Glowfry cell 128 x 128), painted by script, occlusion baked; rigid, no bones"
                       % (ALBEDO, EMI),
        },
    }


if __name__ == "__main__":
    import run
    run.main(__file__)
