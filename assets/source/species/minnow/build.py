"""M_Species_Minnow_Juv on RIG_Fish with T_Minnow_Juv_Alb: art spike S0-A7, the agent art trial
(docs/13-sprint-plan.md Sprint 0; docs/06-art-bible.md sections 3 to 7 and 15; 07 rows
M_Species_Minnow_Juv and T_Minnow_Juv_Alb).

    Blender --background --python assets/source/species/minnow/build.py

The Minnow juvenile at body scale 1.0 (3.0 long, 1.1 tall, 0.7 wide; 06 section 6.2): a slightly
fat teardrop with a big round head, very large eyes, one small back fin and a short tail with a
shallow fork (the fork grows into the adult's signature; 06 3.2, 03 "Minnow"). It sits on the
family skeleton (rigs.FishFit, 18 deform bones and 10 sockets) and reuses the family swim clip
and key poses. LODs and outline shells come from the run.py steps lod and shell (versions.py).

The colour texture is painted by this script (06 section 5.2), not by hand: every texel of the
family UV layout (5.4) is traced back to its point on the mesh, and a paint function lays the
three value blocks of 4.1 in the Minnow palette of 4.3 with large soft gradients (cool violet
shadows, warm yellow lights, the head lightest and most saturated), fin rays and translucent fin
edges, a painted wet highlight and eye glints. Cycles then bakes ambient occlusion (5.5), which
is multiplied in at 35% tinted #5A4FA0 (5.2 step 4). Roughness is the shared flat 85% map.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "_shared", "blender"))

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402
import meshgen  # noqa: E402
import rigs  # noqa: E402
import texgen  # noqa: E402
from fishshape import spread  # noqa: E402

NAME = "M_Species_Minnow_Juv"
ALBEDO = "T_Minnow_Juv_Alb"
TEXTURE = "species_juv"                       # 06 section 5.6: 256 x 256, 60 px/stud
TEX = texgen.TEXTURE_CLASSES[TEXTURE][0]
PAINT = 2 * TEX                               # painted at twice the size, then filtered down

LENGTH, HEIGHT, WIDTH = 3.0, 1.1, 0.7         # 06 section 6.2
Y_NOSE, Y_BODY_END = -1.5, 0.95
Y_TAIL_ROOT, Y_TAIL_TIP = 0.86, 1.5
HEAD_END = 0.40                               # body fraction where the head (and the cheek) ends: 42% of body length
FIN_THICK = 0.04                              # 06 section 6.5 floor is 0.03

LIGHT, MID, DARK, ACCENT = (common.colour("creatures.minnow." + k) for k in ("light", "mid", "dark", "accent"))
EYE_WHITE, PUPIL = "#FFFFFF", common.colour("ui.ink")
BLOCKS = ("mid", "light", "dark", "accent")
BLOCK_HEX = {"mid": MID, "light": LIGHT, "dark": DARK, "accent": ACCENT}

# Rings and segments per part (1,500 triangle budget, 06 section 6.3).
RES = dict(segs=18, rings=19, tail=(5, 5), dorsal=(7, 3), pec=(6, 5), eye=(16, 5), lid=(3, 3))


# ---------------------------------------------------------------- the body profile (side, top and section)

def _t(y):
    return min(1.0, max(0.0, (y - Y_NOSE) / (Y_BODY_END - Y_NOSE)))


def _front(t):
    """A round, blunt head that blends into the body with no change of curvature (no crease)."""
    u = min(1.0, t / 0.40)
    return math.sqrt(max(0.0, 1.0 - (1.0 - u) ** 3))


def _rear(t, waist, start=0.38, power=1.35):
    """The taper from the deepest point to the thin tail root."""
    u = min(1.0, max(0.0, (t - start) / (1.0 - start)))
    return waist + (1.0 - waist) * math.cos(0.5 * math.pi * u) ** power


def top(y):
    t = _t(y)
    return 0.40 * _front(t) * _rear(t, 0.28, 0.42, 1.15) - 0.03 * (1.0 - _front(t))


def bot(y):
    t = _t(y)
    return 0.52 * _front(t) ** 0.85 * _rear(t, 0.24, 0.5, 0.95) + 0.03 * (1.0 - _front(t))


def half_w(y):
    t = _t(y)
    cheeks = 1.0 + 0.06 * math.exp(-((t - 0.24) / 0.12) ** 2)
    return 0.29 * _front(t) ** 0.95 * _rear(t, 0.2) * cheeks


def half_h(y):
    return 0.5 * (top(y) + bot(y))


def section(y, a):
    """Point on the body at station y and angle a around it (0 on the back, pi on the belly)."""
    s, c = math.sin(a), math.cos(a)
    x = half_w(y) * math.copysign(abs(s) ** 0.85, s)
    z = (top(y) if c >= 0.0 else bot(y)) * math.copysign(abs(c) ** 0.9, c)
    return Vector((x, y, z))


def body_part(segs, rings):
    out = []
    for k in range(1, rings + 1):
        t = 0.5 - 0.5 * math.cos(math.pi * k / (rings + 1))      # rings close together at nose and tail root
        t = 0.55 * t + 0.45 * (k / (rings + 1))
        y = Y_NOSE + t * (Y_BODY_END - Y_NOSE)
        out.append([tuple(section(y, 2.0 * math.pi * j / segs)) for j in range(segs)])
    return meshgen.loft(out, (0.0, Y_NOSE, -0.03), (0.0, Y_BODY_END + 0.04, 0.0))


Z_LO, Z_HI = -0.555, 0.545      # the bounding height of 1.1: the pectorals' lowest tip, the back fin's top


def on_flank(y, z, inset):
    return half_w(y) * math.sqrt(max(0.0, 1.0 - (z / (top(y) if z >= 0 else bot(y))) ** 2)) - inset


# The face (06 section 3.3, juvenile): eye diameter 34% of head height, pupil 60% of the eye.
EYE_Y, EYE_Z = -1.05, 0.12
EYE_R = 1.46 * 0.34 * (top(EYE_Y) + bot(EYE_Y)) / 2.0    # well over the 34% row: big cartoon eyes (art-director loops)
EYE = (WIDTH / 2.0 - 0.025 - EYE_R, EYE_Y, EYE_Z)   # set 0.02 into the head
EYE_AXIS = Vector((1.0, -0.42, 0.06)).normalized()        # looking where it is heading
PUPIL_COS = math.cos(math.asin(0.60))                       # pupil 60% of the eye diameter
PEC = (on_flank(-0.52, -0.25, 0.03), -0.52, -0.25)
DORSAL = (-0.42, 0.55)                                      # fore and aft ends of the back fin's root
MOUTH_END = -1.27                                           # the closed smile runs back to here


def eye_centre(side):
    return Vector((side * EYE[0], EYE[1], EYE[2]))


def tail_reach(v):
    """How far back the tail reaches at height fraction v: a shallow fork, round lobes."""
    return 1.0 - 0.24 * (1.0 - np.abs(v)) ** 1.6 - 0.10 * np.abs(v) ** 6


def tail_spread(u):
    return 0.11 + (0.43 - 0.11) * np.sin(0.5 * math.pi * u) ** 0.9


def tail_part(n):
    """A short tail with a shallow fork and round lobes."""
    rows, cols = n
    grid = []
    for u in spread(0.0, 1.0, rows):
        row = []
        for v in spread(-1.0, 1.0, cols):
            y = Y_TAIL_ROOT + u * float(tail_reach(v)) * (Y_TAIL_TIP - Y_TAIL_ROOT)
            row.append((0.0, y, v * float(tail_spread(u))))
        grid.append(row)
    return meshgen.slab(grid, (1.0, 0.0, 0.0), FIN_THICK)


def _dorsal_grid(rows, cols, lift):
    y0, y1 = DORSAL
    grid = []
    for u in spread(0.0, 1.0, rows):
        yb = y0 + (y1 - y0) * u
        rise = lift * math.sin(math.pi * u) ** 0.8 + 0.03
        grid.append([(0.0, yb + 0.22 * v * v, top(yb) - 0.035 + v * rise) for v in spread(0.0, 1.0, cols)])
    return grid


def dorsal_part(n):
    """One small, round, swept-back fin; its top sets the creature's height of 1.1."""
    rows, cols = n
    lo, hi = 0.0, 0.4
    for _ in range(40):          # the lift that puts the fin's highest point at the bounding height
        mid = 0.5 * (lo + hi)
        peak = max(p[2] for row in _dorsal_grid(rows, cols, mid) for p in row)
        lo, hi = (mid, hi) if peak < Z_HI else (lo, mid)
    return meshgen.slab(_dorsal_grid(rows, cols, lo), (1.0, 0.0, 0.0), FIN_THICK)


def _pec_grid(side, rows, cols, length, bx=None):
    root = Vector((side * PEC[0], PEC[1], PEC[2]))
    back = Vector((side * (PEC_BX[0] if bx is None else bx), 0.8, -0.56)).normalized()
    across = Vector((0.0, 0.3, 1.0))
    across = (across - across.dot(back) * back).normalized()
    grid = []
    for u in spread(0.0, 1.0, rows):
        row = []
        for v in spread(-1.0, 1.0, cols):
            phi = math.radians(40.0) * v                      # a fan of rays from the root
            reach = length * (1.0 - 0.12 * abs(v) ** 2.5)    # a round outer edge
            d = math.cos(phi) * back + math.sin(phi) * across
            row.append(root + d * (reach * (0.08 + 0.92 * u)))
        grid.append(row)
    return grid, back.cross(across)


PEC_BX = [None]


def pec_length():
    """As long as the 0.7 width and the bounding height allow: the tip just hangs below the belly."""
    def limits(bx):
        grid, _ = _pec_grid(1.0, 6, 5, 1.0, bx)
        kx = max(p.x for row in grid for p in row) - PEC[0]
        kz = PEC[2] - min(p.z for row in grid for p in row)
        return (WIDTH / 2.0 - 0.018 - PEC[0]) / kx, (PEC[2] - Z_LO) / kz
    if PEC_BX[0] is None:      # turn the fin out until its tip meets the width and the depth together
        lo, hi = 0.05, 0.8
        for _ in range(40):
            mid = 0.5 * (lo + hi)
            lx, lz = limits(mid)
            lo, hi = (mid, hi) if lx > lz else (lo, mid)
        PEC_BX[0] = lo
    return min(limits(PEC_BX[0]))


def pec_part(side, n):
    """A rounded fan (140% of a real minnow's pectoral), sized so its tip touches the 0.7 width."""
    rows, cols = n
    grid, normal = _pec_grid(side, rows, cols, pec_length())
    return meshgen.slab(grid, normal, 0.035)


def lid_part(side, n):
    """A visor over the upper band of the eye (neutral: 85% open); it turns about the eye's fore-aft axis."""
    rows, cols = n
    c = eye_centre(side)
    out, up, fwd = Vector((side, 0.0, 0.0)), Vector((0.0, 0.0, 1.0)), Vector((0.0, -1.0, 0.0))
    r = EYE_R + 0.016
    grid = [[c + r * (math.cos(b) * (math.cos(a) * out + math.sin(a) * up) + math.sin(b) * fwd)
             for b in spread(math.radians(-62), math.radians(62), cols)]
            for a in spread(math.radians(74), math.radians(118), rows)]
    return meshgen.slab(grid, lambda p: p - c, 0.03)


# ---------------------------------------------------------------- the standard UV layout (06 section 5.4)

_BODY = texgen.place("Fish", "body", TEX, u=(0.05, 0.80))
_TAILUV = texgen.place("Fish", "body", TEX, u=(0.80, 1.0))
UV = {
    "dorsal": texgen.place("Fish", "fins", TEX, u=(0.0, 0.5)),
    "pec": texgen.place("Fish", "fins", TEX, u=(0.5, 1.0)),
    "eye": texgen.place("Fish", "eye", TEX, v=(0.0, 0.125)),
    "lid": texgen.place("Fish", "eye", TEX, v=(0.125, 0.25)),
}


def body_uv(p, q):
    """Nose at U 0.05, tail root at U 0.80; back edge at the top of the region, belly line at its foot."""
    return _BODY((p.y - Y_NOSE) / (Y_BODY_END + 0.04 - Y_NOSE), 1.0 - q[1])


def tail_uv(p, q):
    return _TAILUV((p.y - Y_TAIL_ROOT) / (Y_TAIL_TIP - Y_TAIL_ROOT), 0.5 + 0.5 * p.z / 0.45)


PARTS = ("body", "tail", "dorsal", "pec", "eye", "lid")


def minnow_meshdata(res, fit):
    """Body, tail, back fin, pectorals, eyes and lids, each a closed volume. Returns the mesh data and
    the part index of every vertex (the painter needs to know which part a texel belongs to)."""
    md = meshgen.MeshData()
    part_of = []

    def add(part, kind, **kw):
        md.add_part(part, MID, **kw)
        part_of.extend([PARTS.index(kind)] * (len(md.verts) - len(part_of)))

    add(body_part(res["segs"], res["rings"]), "body", uv=body_uv, weights=lambda p, q: fit.body_weights(p))
    add(tail_part(res["tail"]), "tail", uv=tail_uv, weights={"TailFin": 1.0})
    add(dorsal_part(res["dorsal"]), "dorsal", uv=lambda p, q: UV["dorsal"](*q), weights={"Dorsal": 1.0})
    for side, tag in ((1.0, "L"), (-1.0, "R")):
        add(pec_part(side, res["pec"]), "pec", uv=lambda p, q: UV["pec"](*q), weights={"Pec_" + tag: 1.0})
        axis = Vector((side * EYE_AXIS.x, EYE_AXIS.y, EYE_AXIS.z))
        add(meshgen.sphere(eye_centre(side), EYE_R, axis, (0.0, 0.0, 1.0), *res["eye"]), "eye",
            uv=lambda p, q: UV["eye"](q[0] ** 0.5, q[1]), weights={"Eye_" + tag: 1.0})
        add(lid_part(side, res["lid"]), "lid", uv=lambda p, q: UV["lid"](*q), weights={"Lid_" + tag: 1.0})
    return md, np.array(part_of)


# ---------------------------------------------------------------- colour maths (numpy, sRGB <-> CIE L*a*b*)

_M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
_WHITE = np.array([0.95047, 1.0, 1.08883])


def srgb_to_lab(c):
    c = np.asarray(c, dtype=float)
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    xyz = lin @ _M.T / _WHITE
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16.0 / 116.0)
    return np.stack([116.0 * f[..., 1] - 16.0, 500.0 * (f[..., 0] - f[..., 1]), 200.0 * (f[..., 1] - f[..., 2])], -1)


def lab_to_srgb(lab):
    fy = (lab[..., 0] + 16.0) / 116.0
    f = np.stack([fy + lab[..., 1] / 500.0, fy, fy - lab[..., 2] / 200.0], -1)
    xyz = np.where(f ** 3 > 0.008856, f ** 3, (f - 16.0 / 116.0) / 7.787) * _WHITE
    lin = np.clip(xyz @ np.linalg.inv(_M).T, 0.0, 1.0)
    return np.clip(np.where(lin <= 0.0031308, lin * 12.92, 1.055 * lin ** (1.0 / 2.4) - 0.055), 0.0, 1.0)


def _toward(h, target, amount):
    d = (target - h + 180.0) % 360.0 - 180.0
    return h + np.sign(d) * np.minimum(np.abs(d), amount)


_VIOLET_AB = None


def violet_ab():
    """a*, b* of the shadow tint #5A4FA0 (06 section 5.2 step 4)."""
    global _VIOLET_AB
    if _VIOLET_AB is None:
        _VIOLET_AB = srgb_to_lab(hex_rgb("#5A4FA0"))[1:]
    return _VIOLET_AB


def shade(hexes, s, fade):
    """Paint a block colour with a shading value s in -1..1 (06 section 4.1): at most 6 L* either way
    (12 points across the block). Shadows lean toward the blue-violet #5A4FA0 (mixed in a*b*, so no
    colour passes through brown or green on the way); lights lean toward yellow (hue toward 50).
    `fade` 0..1 takes up to 15% of the saturation off toward the tail."""
    lab = srgb_to_lab(hexes)
    L, ab = lab[..., 0], lab[..., 1:]
    s = np.clip(s, -1.0, 1.0)
    dark = np.clip(-s, 0.0, 1.0)[..., None]
    ab = ab + 0.16 * dark * (violet_ab() - ab)
    C, h = np.hypot(ab[..., 0], ab[..., 1]), np.degrees(np.arctan2(ab[..., 1], ab[..., 0])) % 360.0
    h = np.where(s > 0.0, _toward(h, 50.0, 8.0 * np.clip(s, 0.0, 1.0)), h)
    C = C * (1.0 - 0.15 * fade) * (1.0 + 0.05 * np.clip(s, 0.0, 1.0))
    L = np.minimum(100.0, L + 6.0 * s)
    hr = np.radians(h)
    return lab_to_srgb(np.stack([L, C * np.cos(hr), C * np.sin(hr)], -1))


def hex_rgb(h):
    return np.array(common.hex_to_srgb(h))


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------- the paint (06 section 5.2)

_top_v = np.vectorize(top)
_bot_v = np.vectorize(bot)
_hw_v = np.vectorize(half_w)


def paint(P, N, part):
    """Block, painted sRGB colour and unshaded block colour (hex) at points P (n x 3) with normals N
    on parts `part`. Left and right sides share one UV island, so the paint is mirror-symmetric (|x|).
    Blocks: tangerine back and flank and fins (mid), one cream belly from chin to tail base (light),
    rust back ridge and fin edges (dark), the yellow tail (accent); ink pupils and smile."""
    n = len(P)
    x, y, z = np.abs(P[:, 0]), P[:, 1], P[:, 2]
    nz = N[:, 2]
    t = np.clip((y - Y_NOSE) / (Y_BODY_END - Y_NOSE), 0.0, 1.0)
    block = np.zeros(n, dtype=int)                    # index into BLOCKS
    base = np.tile(hex_rgb(MID), (n, 1))
    s = 0.1 + 0.5 * nz                                # top-down light: warm above, cool below
    s += 0.3 * (1.0 - smoothstep(0.0, 0.55, t))       # the head is the lightest third
    fade = smoothstep(0.25, 1.0, t)

    def put(mask, name, hexcode=None):
        block[mask] = BLOCKS.index(name)
        base[mask] = hex_rgb(hexcode or BLOCK_HEX[name])

    # Body.
    b = part == PARTS.index("body")
    hwv, tv, bv = _hw_v(y), _top_v(y), _bot_v(y)
    zn = np.where(z >= 0.0, z / np.maximum(tv, 1e-4), z / np.maximum(bv, 1e-4))
    ang = np.arctan2(np.clip(x / np.maximum(hwv, 1e-4), 0.0, None), zn)          # 0 back, pi belly
    edge = 2.22 - 0.3 * (1.0 - smoothstep(0.04, 0.3, t)) + 0.03 * np.sin(15.0 * t + 1.0)   # belly line, chin to tail base
    light = b & (ang > edge)
    put(light, "light")
    ridge_w = 0.40 * smoothstep(0.17, 0.38, t) * (1.0 - 0.3 * smoothstep(0.7, 1.0, t)) + 0.02 * np.sin(13.0 * t)
    ridge = b & (ang < ridge_w)
    put(ridge, "dark")
    s = np.where(light, s + 0.25 * (1.0 - fade), s)
    s = np.where(b, s + 0.12 * np.sin(8.0 * ang + 2.2 * np.sin(5.0 * t + 0.6)), s)     # broad strokes along the form
    s = np.where(b & ~ridge, s + 0.3 * np.exp(-((ang - ridge_w - 0.12) / 0.2) ** 2), s)  # rim light under the ridge
    brow = np.exp(-((y - (EYE_Y + 0.05)) / 0.16) ** 2 - ((ang - 0.42) / 0.2) ** 2)
    s = np.where(b, s + 0.4 * brow, s)                                                   # wet highlight on the brow
    # The smile: short, thick and upturned on the side of the head, below and in front of the eye and
    # clear of the snout tip, sitting on a cream lip patch so it still reads at 48 px.
    my, mz, half, k = -1.235, -0.26, 0.17, 3.4
    curve = mz + k * (y - my) ** 2                         # corners turn up
    mouth = b & (np.abs(y - my) < half) & (np.abs(z - curve) < 0.05 - 0.9 * (y - my) ** 2)
    corner_z = mz + k * half ** 2
    ends = np.minimum(np.hypot(y - (my - half), z - corner_z), np.hypot(y - (my + half), z - corner_z))
    mouth = mouth | (b & (ends < 0.034))                  # round corners
    # a thin cream lip line under the smile, so it holds at 48 px
    lip_patch = b & ~mouth & (np.abs(y - my) < half * 0.92) & (z < curve - 0.045) & (z > curve - 0.08)
    put(lip_patch, "light")
    s = np.where(lip_patch, s + 0.4, s)
    # the snout tip, where the nose's UV fan meets, stays one plain colour (no streaks)
    tip = b & (t < 0.05)
    put(tip & ~lip_patch, "mid")
    put(mouth, "dark", PUPIL)
    s = np.where(mouth, 0.0, s)

    # Back fin: tangerine with a rust edge and rays.
    d = part == PARTS.index("dorsal")
    if d.any():
        y0, y1 = DORSAL
        u = np.clip((y - y0) / (y1 - y0), 0.0, 1.0)
        v = np.clip((z - _top_v(y) + 0.035) / np.maximum(Z_HI - _top_v(y) + 0.035, 0.05), 0.0, 1.0)
        put(d, "mid")
        put(d & (v > 0.86), "dark")
        rays = 0.5 + 0.5 * np.cos(2.0 * math.pi * (5.0 * u - 1.2 * v))
        s = np.where(d, 0.1 + 0.5 * v - 0.4 * rays * (1.0 - v) + 0.2 * nz, s)
    # Pectorals: rounded tangerine paddles with a rust rim and rays, lighter toward the tip.
    p = part == PARTS.index("pec")
    if p.any():
        r = np.hypot(x - PEC[0], np.hypot(y - PEC[1], z - PEC[2])) / pec_length()
        put(p, "mid")
        put(p & (r > 0.76), "dark")
        ray = 0.5 + 0.5 * np.cos(30.0 * np.arctan2(z - PEC[2], y - PEC[1]))
        s = np.where(p, -0.1 + 0.8 * r - 0.35 * ray * (1.0 - r) + 0.3 * nz, s)
    # Tail: the Minnow's ID mark, yellow across the whole fin with a thin rust edge.
    tl = part == PARTS.index("tail")
    if tl.any():
        u = np.clip((y - Y_TAIL_ROOT) / (Y_TAIL_TIP - Y_TAIL_ROOT), 0.0, 1.0)
        v = np.clip(z / tail_spread(u), -1.0, 1.0)
        urel = u / np.maximum(tail_reach(v), 1e-3)
        put(tl, "accent")
        put(tl & ((urel > 0.86) | ((np.abs(v) > 0.84) & (u > 0.2))), "dark")
        fan = np.arctan2(z, y - (Y_TAIL_ROOT - 0.25))
        ray = 0.5 + 0.5 * np.cos(30.0 * fan)
        s = np.where(tl, -0.3 + 0.9 * u - 0.5 * ray * (1.0 - 0.5 * u), s)
        fade = np.where(tl, 0.0, fade)

    # Eyes: white, a big ink pupil looking ahead, two painted glints that never move (06 7.7).
    e = part == PARTS.index("eye")
    if e.any():
        c = np.array([EYE[0], EYE[1], EYE[2]])
        dvec = np.stack([x, y, z], -1) - c
        dvec /= np.maximum(np.linalg.norm(dvec, axis=1, keepdims=True), 1e-6)
        ax = np.array(EYE_AXIS)
        cos_a = dvec @ ax
        g1 = np.array(Vector(EYE_AXIS) + Vector((0.0, -0.2, 0.36)))
        g1 /= np.linalg.norm(g1)
        g2 = np.array(Vector(EYE_AXIS) + Vector((0.0, 0.22, -0.2)))
        g2 /= np.linalg.norm(g2)
        put(e, "light", EYE_WHITE)
        s = np.where(e, -1.0 + 1.6 * smoothstep(-0.2, 0.7, cos_a) + 0.4 * dvec[:, 2], s)
        pupil = e & (cos_a > PUPIL_COS)
        put(pupil, "dark", PUPIL)
        s = np.where(pupil, 0.6 * smoothstep(0.86, 0.98, cos_a) - 0.6, s)
        # main glint about a quarter of the pupil across, a small second one opposite
        glint = e & ((dvec @ g1 > math.cos(math.radians(9.5))) | (dvec @ g2 > math.cos(math.radians(4.5))))
        put(glint, "light", EYE_WHITE)
        s = np.where(glint, 1.0, s)
        fade = np.where(e, 0.0, fade)
    # Lids: tangerine, hugging the eyeball; no lashes and no brows (06 7.7).
    lid = part == PARTS.index("lid")
    if lid.any():
        c = np.array([EYE[0], EYE[1], EYE[2]])
        dv = np.stack([x, y, z], -1) - c
        elev = np.degrees(np.arctan2(dv[:, 2], np.maximum(dv[:, 0], 1e-6)))
        put(lid, "mid")
        s = np.where(lid, 0.3 + 0.4 * nz, s)
        fade = np.where(lid, 0.0, fade)

    # Fin roots, eyeballs and lids buried in the body are never seen: they take the body colour and
    # stay out of the value-block shares (06 4.1 counts the visible surface).
    ins = (part != PARTS.index("body")) & (y > Y_NOSE) & (y < Y_BODY_END) & (
        (x / np.maximum(hwv, 1e-4)) ** (2 / 0.85) + np.abs(zn) ** (2 / 0.9) < 0.97)
    base[ins] = hex_rgb(MID)
    block[ins] = -1

    rgb = shade(base, s, fade)
    # Eye whites and ink are neutral: no hue shading on them.
    neutral = (e & (block != BLOCKS.index("mid"))) | mouth
    rgb[neutral] = np.clip(base[neutral] + (np.clip(s[neutral], -1, 1) * 0.06)[:, None], 0.0, 1.0)
    keys = ["#%02X%02X%02X" % tuple(int(round(255 * c)) for c in row) for row in base]
    return block, rgb, keys


# ---------------------------------------------------------------- texture: trace texels back to the mesh

def rasterise(obj, part_of_vertex, size):
    """For every texel of a size x size map (row 0 at V 0): the mesh point, normal and part under it."""
    mesh = obj.data
    mesh.calc_loop_triangles()
    uvl = mesh.uv_layers[common.UV_NAME].data
    normals = mesh.corner_normals
    P = np.zeros((size, size, 3))
    N = np.zeros((size, size, 3))
    part = np.full((size, size), -1, dtype=int)
    for tri in mesh.loop_triangles:
        uv = np.array([uvl[li].uv[:] for li in tri.loops]) * size - 0.5
        pts = np.array([mesh.vertices[vi].co[:] for vi in tri.vertices])
        nrm = np.array([normals[li].vector[:] for li in tri.loops])
        (x0, y0), (x1, y1) = np.floor(uv.min(0)).astype(int), np.ceil(uv.max(0)).astype(int)
        x0, y0, x1, y1 = max(0, x0), max(0, y0), min(size - 1, x1), min(size - 1, y1)
        a, b, c = uv
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-9 or x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        w0 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / den
        w1 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / den
        w2 = 1.0 - w0 - w1
        inside = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
        if not inside.any():
            continue
        W = np.stack([w0[inside], w1[inside], w2[inside]], -1)
        rows, cols = gy[inside], gx[inside]
        P[rows, cols] = W @ pts
        nn = W @ nrm
        N[rows, cols] = nn / np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-6)
        part[rows, cols] = part_of_vertex[tri.vertices[0]]
    return P, N, part


def dilate(rgb, filled, steps):
    """Bleed the painted islands outward (the bake margin of 06 section 5.5)."""
    rgb, filled = rgb.copy(), filled.copy()
    for _ in range(steps):
        acc = np.zeros_like(rgb)
        cnt = np.zeros(filled.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            f = np.roll(filled, (dy, dx), (0, 1))
            acc += np.roll(rgb, (dy, dx), (0, 1)) * f[..., None]
            cnt += f
        grow = ~filled & (cnt > 0)
        rgb[grow] = acc[grow] / cnt[grow][:, None]
        filled = filled | grow
    return rgb


def bake_occlusion(obj, size):
    """Cycles ambient occlusion bake from the game mesh (06 section 5.5: CPU, 64 samples), or None."""
    scene = bpy.context.scene
    keep = (scene.render.engine, {o.name: o.hide_render for o in scene.objects})
    img = bpy.data.images.new("BAKE_AO", size, size, float_buffer=True, alpha=False)
    mat = obj.data.materials[0]
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = img
    mat.node_tree.nodes.active = node
    try:
        scene.render.engine = 'CYCLES'
        scene.cycles.device = 'CPU'
        scene.cycles.samples = 64
        if scene.world:
            scene.world.light_settings.distance = 0.35
        for o in scene.objects:
            o.hide_render = o is not obj
        bpy.ops.object.select_all(action='DESELECT')
        obj.hide_set(False)
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.bake(type='AO', margin=texgen.margin_px(size), use_clear=True)
        ao = np.array(img.pixels[:]).reshape(size, size, 4)[..., 0]
        print("[minnow] occlusion baked in Cycles, mean %.2f" % ao.mean())
        return ao
    except Exception as exc:       # the paint still stands without it; the report says so
        print("[minnow] occlusion bake failed (%s): painted without it" % exc)
        return None
    finally:
        mat.node_tree.nodes.remove(node)
        scene.render.engine = keep[0]
        for o in scene.objects:
            o.hide_render = keep[1].get(o.name, o.hide_render)


def textured_material(name, image):
    """Matte, as in game: the colour map with the shared flat 85% roughness (06 section 5.1)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = 'Linear'
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Metallic"].default_value = 0.0
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def save_png(path, rgb, size):
    img = bpy.data.images.new(os.path.basename(path)[:-4] + "_out", size, size, alpha=False)
    rgba = np.concatenate([rgb, np.ones((size, size, 1))], -1)
    img.pixels.foreach_set(rgba.astype(np.float32).ravel())
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    return size, size


def paint_texture(body, part_of_vertex):
    """The colour map: rasterise, paint, filter down, multiply occlusion, bleed the margin."""
    P, N, part = rasterise(body, part_of_vertex, PAINT)
    filled = part >= 0
    block = np.full(part.shape, -1, dtype=int)
    rgb = np.zeros(P.shape)
    blk, col, hexes = paint(P[filled], N[filled], part[filled])
    block[filled], rgb[filled] = blk, col
    base_key = np.full(part.shape, "", dtype=object)
    base_key[filled] = np.array(hexes, dtype=object)
    rgb = dilate(rgb, filled, 6)
    small = rgb.reshape(TEX, 2, TEX, 2, 3).mean(axis=(1, 3))
    small_filled = filled.reshape(TEX, 2, TEX, 2).any(axis=(1, 3))
    ao = bake_occlusion(body, TEX)
    if ao is not None:
        # 35% strength, tinted #5A4FA0 and never black: occlusion takes lightness and leans the
        # colour toward the violet in a*b*, so crevices go cool, not brown.
        amt = 0.35 * (1.0 - np.clip(ao, 0.0, 1.0))
        lab = srgb_to_lab(small)
        lab[..., 0] -= 14.0 * amt
        lab[..., 1:] += 0.5 * amt[..., None] * (violet_ab() - lab[..., 1:])
        small = lab_to_srgb(lab)
    # 06 4.1: a gradient moves the lightness inside a block by at most 12 L* points, occlusion
    # included. Where a texel lies wholly inside one block colour, hold it to that colour's band.
    sub = base_key.reshape(TEX, 2, TEX, 2).transpose(0, 2, 1, 3).reshape(TEX, TEX, 4)
    keys = sub[..., 0]
    whole = (sub == keys[..., None]).all(-1) & (keys != "")
    lab = srgb_to_lab(small)
    for k in set(keys[whole].tolist()):
        if k == PUPIL:
            continue
        lb = float(srgb_to_lab(hex_rgb(k))[0])
        lo, hi = (88.0, 100.0) if k == EYE_WHITE else (lb - 6.0, lb + 6.0)
        sel = whole & (keys == k)
        lab[sel, 0] = np.clip(lab[sel, 0], lo, hi)
    small = np.where(whole[..., None], lab_to_srgb(lab), small)
    small = dilate(small, small_filled, texgen.margin_px(TEX) + 4)
    # Report the painted lightness spread inside each block colour.
    lab = srgb_to_lab(small)[..., 0]
    coarse = block.reshape(TEX, 2, TEX, 2)[:, 0, :, 0]
    for k in sorted(set(keys[coarse >= 0].tolist())):
        sel = (keys == k) & (coarse >= 0)
        lo, hi = np.percentile(lab[sel], [5, 95])
        print("[minnow] L* spread %-8s %4d texels: %.1f to %.1f (%.1f points, 5th to 95th percentile)" % (k, sel.sum(), lo, hi, hi - lo))
    return np.clip(small, 0.0, 1.0), block, ao is not None


# ---------------------------------------------------------------- the asset

def build():
    fit = rigs.FishFit(LENGTH, half_h, half_w, EYE, PEC, (0.0, -0.15, HEIGHT / 2.0))
    arm = meshgen.build_armature("RIG_Fish", fit.bones())
    md, part_of_vertex = minnow_meshdata(RES, fit)
    body = meshgen.skin(md.to_object(NAME, "GEO"), arm)

    albedo, block_map, baked = paint_texture(body, part_of_vertex)
    work = os.path.join(common.review_dir(NAME), "%s_work_%d.png" % (ALBEDO, TEX))
    save_png(work, albedo, TEX)
    body.data.materials[0] = textured_material("MAT_" + NAME, bpy.data.images.load(work))

    # The vertex colours carry each corner's block, for the outline shells and anything vertex-coloured.
    mesh = body.data
    col = mesh.color_attributes[common.COLOR_ATTR]
    nrm = mesh.corner_normals
    loops = list(mesh.loops)
    P = np.array([mesh.vertices[l.vertex_index].co[:] for l in loops])
    Nn = np.array([nrm[i].vector[:] for i in range(len(loops))])
    blk, _, _ = paint(P, Nn, part_of_vertex[[l.vertex_index for l in loops]])
    for i, k in enumerate(blk):
        col.data[i].color_srgb = (*common.hex_to_srgb(BLOCK_HEX[BLOCKS[max(0, k)]]), 1.0)

    def sampler(u, v):
        r = min(PAINT - 1, max(0, int(v * PAINT)))
        c = min(PAINT - 1, max(0, int(u * PAINT)))
        k = block_map[r, c]
        rr, cc = min(TEX - 1, r // 2), min(TEX - 1, c // 2)
        return (BLOCKS[k] if k >= 0 else None), tuple(float(c) for c in albedo[rr, cc])

    swim = rigs.bake_clip(arm, "A_Fish_Swim", 16, rigs.fish_swim_pose)

    def write_flat(value):
        return lambda path: save_png(path, np.full((8, 8, 3), value), 8)

    return {
        "name": NAME,
        "category": "Species",
        "budget": "species_juv",
        "rig": "Fish",
        "uv": {"layout": "Fish", "texture": TEXTURE},
        "armature": arm,
        "origin": "creature",
        "size": (WIDTH, LENGTH, HEIGHT),
        "size_tol": 0.02,
        "facing": {"kind": "bones", "front": "Jaw", "back": "TailFin"},
        "texture_sampler": sampler,
        "texture_name": "%s, %d px, occlusion %s" % (ALBEDO, TEX, "baked" if baked else "NOT baked"),
        # The bible's own Minnow dark (06 section 4.3) breaks its dark-block rule (4.1): logged and
        # waived, as on the family base mesh; the owner decides (spike/results/art-blender.md).
        "waivers": {
            "palette: dark L*": "06 4.3 Minnow dark #C2491D vs 4.1 dark <= 35; bible inconsistency for the owner",
            "value: dark L*": "follows from the palette waiver above",
            "value: accent share": "03 Minnow: the yellow tail is the ID mark, so the whole tail fin is accent "
                                   "(art-director loop 1) vs 06 4.1 accent <= 5%; conflict logged for the owner",
        },
        "meshes": [{"object": body, "role": "body", "primary": True}],
        "actions": [swim],
        "exports": [{"file": "meshes/%s.fbx" % NAME, "objects": [body, arm]}],
        "textures": [
            {"file": "textures/%s.png" % ALBEDO, "write": lambda path: save_png(path, albedo, TEX), "max": TEX},
            # 06 section 5.1: the three shared flat roughness maps, 8 x 8 (07 T_Shared_Rgh*).
            {"file": "textures/T_Shared_Rgh.png", "write": write_flat(0.85), "max": 8},
            {"file": "textures/T_Shared_RghWet.png", "write": write_flat(0.35), "max": 8},
            {"file": "textures/T_Shared_RghChalk.png", "write": write_flat(1.0), "max": 8},
        ],
        "preview": {
            "main": [body],
            "blocks": {"mid": MID, "light": LIGHT, "dark": DARK, "accent": ACCENT},
            "lineup": [
                {"label": "Minnow juvenile", "objects": [body]},
                {"label": "family capsule stand-in, 3 studs", "objects": [bpy.data.objects["REF_Minnow_T1"]]},
            ],
            "lineup_caption": ["sardine, its look-alike (06 3.2), is not built yet"],
            "view_captions": {"Game": ["game camera: behind and 25 degrees above"]},
            "extras": [{"title": title, "view": view, "pose": pose} for title, view, pose in rigs.fish_poses()],
            "texture": "%s %d x %d painted by script, occlusion %s; roughness T_Shared_Rgh 85%%"
                       % (ALBEDO, TEX, TEX, "baked" if baked else "not baked"),
        },
    }


if __name__ == "__main__":
    import run
    run.main(__file__)
