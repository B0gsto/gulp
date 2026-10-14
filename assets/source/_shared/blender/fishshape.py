"""The Fish family base shape, M_Species_Base_Fish (docs/07-asset-list.md section 2.0;
docs/06-art-bible.md sections 3, 5.4, 6.2 and 6.5): the family body (fishbody.FishBody) with the
family's neutral numbers and the family's fins, at the size in fishbody (LENGTH, HEIGHT, WIDTH).
Shared by the family base build (families/fish) and the template's tier-1 and tier-7 reference
silhouettes, so the reference fish is the base fish.

Neutral juvenile proportions (06 section 3.3): head 42% of the body length, body depth 47% of it
(fishbody.DEPTH_SHARE), eye 34% of the head height, closed mouth a quarter of the head width
(the lip line where the jaw weights split), tail fin 80% of the body height with a shallow fork,
fins at 140% of a real fish's. A species keeps the topology and changes these numbers.
"""
import math

from mathutils import Vector

import meshgen
from fishbody import (FIN_THICK, HEIGHT, LENGTH, SPINE_NODES, WIDTH, DEPTH_SHARE, Y_NOSE, Y_TAIL_TIP,  # noqa: F401
                      FishBody)

Y_BODY_END = 0.95                       # the tail root: the body's end, where the tail fin starts
Y_TAIL_ROOT = 0.86                      # the tail fin's root is sunk into the body's last rings
BODY = FishBody(nose=Y_NOSE, root=Y_BODY_END, max_depth=DEPTH_SHARE * (Y_BODY_END - Y_NOSE), head=0.40,
                back=(0.42, 0.26, 0.42, 1.3), belly=(0.58, 0.9, 0.22, 0.48, 1.0), nose_drop=0.02,
                width=(0.28, 0.95, 0.2, 0.38, 1.35), cheeks=(0.04, 0.24, 0.12))
top, bot, half_w, half_h, section = BODY.top, BODY.bot, BODY.half_w, BODY.half_h, BODY.section

Z_LO = -BODY.lowest()                   # the belly is the lowest point; the pectoral tips stay above it
Z_HI = Z_LO + HEIGHT                    # the back fin's top makes up the height

EYE_Y = -1.06
EYE_R = 0.17 * (top(EYE_Y) + bot(EYE_Y))                     # diameter 34% of the head height
EYE = (BODY.on_flank(EYE_Y, 0.12, 0.0) - 0.55 * EYE_R, EYE_Y, 0.12)   # set a little into the head
PEC = (BODY.on_flank(-0.52, -0.28, 0.03), -0.52, -0.28)
DORSAL = (-0.32, 0.48)                  # fore and aft ends of the back fin's root
MOUTH_Y = -1.10                         # the closed mouth line runs from the nose back to here (25% of head width)


def spread(a, b, n):
    return [a + (b - a) * i / (n - 1) for i in range(n)]


def eye_centre(side):
    return Vector((side * EYE[0], EYE[1], EYE[2]))


def body_part(segs, rings):
    return BODY.part(segs, rings, SPINE_NODES)


def tail_part(n):
    """Tail fin 80% of the body height, a shallow fork with round lobes; a closed slab."""
    rows, cols = n
    half = 0.40 * DEPTH_SHARE * (Y_BODY_END - Y_NOSE)
    def fork(v):
        return 1.0 - 0.22 * (1.0 - abs(v)) ** 1.6 - 0.08 * abs(v) ** 6
    longest = max(fork(v) for v in spread(-1.0, 1.0, 101))      # the lobe tips reach the tail tip
    grid = []
    for u in spread(0.0, 1.0, rows):
        row = []
        for v in spread(-1.0, 1.0, cols):
            reach = fork(v) / longest
            spread_v = 0.12 + (half - 0.12) * math.sin(0.5 * math.pi * u) ** 0.9
            row.append((0.0, Y_TAIL_ROOT + u * reach * (Y_TAIL_TIP - Y_TAIL_ROOT), v * spread_v))
        grid.append(row)
    return meshgen.slab(grid, (1.0, 0.0, 0.0), FIN_THICK)


def _dorsal_grid(rows, cols, lift):
    y0, y1 = DORSAL
    grid = []
    for u in spread(0.0, 1.0, rows):
        yb = y0 + (y1 - y0) * u
        rise = lift * math.sin(math.pi * u ** 0.85) ** 0.6 + 0.03     # steep leading edge, round top
        grid.append([(0.0, yb + 0.2 * v * v, top(yb) - 0.035 + v * rise) for v in spread(0.0, 1.0, cols)])
    return grid


def dorsal_part(n):
    """One round, swept-back back fin whose top sets the creature's height."""
    rows, cols = n
    lo, hi = 0.0, 0.5
    for _ in range(40):
        mid = 0.5 * (lo + hi)
        peak = max(p[2] for row in _dorsal_grid(rows, cols, mid) for p in row)
        lo, hi = (mid, hi) if peak < Z_HI else (lo, mid)
    return meshgen.slab(_dorsal_grid(rows, cols, lo), (1.0, 0.0, 0.0), FIN_THICK)


def pec_part(side, n):
    """A rounded fan of rays from the root, swept back and down; the tip meets the width or the
    belly line, whichever comes first."""
    rows, cols = n
    root = Vector((side * PEC[0], PEC[1], PEC[2]))
    back = Vector((side * 0.42, 0.8, -0.5)).normalized()
    across = Vector((0.0, 0.3, 1.0))
    across = (across - across.dot(back) * back).normalized()

    def grid(length):
        return [[root + (math.cos(math.radians(38.0) * v) * back + math.sin(math.radians(38.0) * v) * across)
                 * (length * (1.0 - 0.12 * abs(v) ** 2.5) * (0.08 + 0.92 * u))
                 for v in spread(-1.0, 1.0, cols)] for u in spread(0.0, 1.0, rows)]
    unit = grid(1.0)
    kx = max(abs(p.x) for row in unit for p in row) - PEC[0]
    kz = PEC[2] - min(p.z for row in unit for p in row)
    length = min((WIDTH / 2.0 - 0.018 - PEC[0]) / kx, (PEC[2] - Z_LO) / kz)
    return meshgen.slab(grid(length), back.cross(across), 0.035)


def eye_part(side, n):
    axis = Vector((side, -0.35, 0.05)).normalized()
    return meshgen.sphere(eye_centre(side), EYE_R, axis, (0.0, 0.0, 1.0), *n)


def lid_part(side, n):
    """A visor over the upper band of the eye (neutral: 85% open); it turns about the eye's fore-aft axis."""
    rows, cols = n
    c = eye_centre(side)
    out, up, fwd = Vector((side, 0.0, 0.0)), Vector((0.0, 0.0, 1.0)), Vector((0.0, -1.0, 0.0))
    r = EYE_R + 0.016
    pts = [[c + r * (math.cos(b) * (math.cos(a) * out + math.sin(a) * up) + math.sin(b) * fwd)
            for b in spread(math.radians(-62), math.radians(62), cols)]
           for a in spread(math.radians(74), math.radians(118), rows)]
    return meshgen.slab(pts, lambda p: p - c, 0.03)


def crest_part():
    """The family back sail of 06 section 3.6, as the base's stand-in: three rounded spines joined
    by a web, the front one tallest. Origin at its base (it hangs on Sock_Crest)."""
    grid = []
    for u in spread(0.0, 1.0, 9):
        spines = 0.75 + 0.25 * math.cos(6.0 * math.pi * u)
        rise = 0.08 + 0.24 * (1.0 - 0.35 * u) * math.sin(math.pi * u ** 0.7) * spines
        grid.append([(0.0, -0.22 + 0.44 * u + 0.08 * v * v, -0.03 + v * rise) for v in spread(0.0, 1.0, 3)])
    return meshgen.slab(grid, (1.0, 0.0, 0.0), FIN_THICK)


def silhouette(colour, scale=1.0):
    """Body, tail and back fin at `scale` times the family size: the template's reference fish."""
    md = meshgen.MeshData()
    for part in (body_part(16, 14), tail_part((4, 3)), dorsal_part((4, 3))):
        md.add_part(part, colour, uv=(0.5, 0.5))
    md.verts = [tuple(c * scale for c in v) for v in md.verts]
    return md
