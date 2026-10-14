"""Shared code for the Nursery kit, first half: task S6-A3 (docs/13-sprint-plan.md Sprint 6; docs/07-asset-list.md
6.2 rows M_Env_Nursery_Floor_01-04, M_Env_Nursery_Rim_01-02, T_EnvNursery_Alb; docs/03-content-catalog.md 6.2;
docs/06-art-bible.md 4.1 to 4.5, 5.1 to 5.6, 6.1 to 6.5, 9.1 to 9.3, 10.2, 15, 16.1).

The Nursery Lagoon (03 6.2) is an oval pool 220 x 170, depth 0 to 30, in a bulge of the Rim at the south-west.
Its floor features sit between depth 24 (Hatch Bed) and 30 (Sleepy Clam); the kit's sand level is depth 26.

Floor chunks (07 6.2: 128 x 128 studs, 3,000 tris each, T_Tile_Sand_Alb). Each chunk is a closed slab: a sand
surface on a flat base 8 studs below it (origin: the centre of the base, 06 6.1). Every edge carries the same
symmetric profile, `edge_field` (zero slope across the edge, the same heights along it), so any chunk meets any
other at any of the four 90-degree turns with no step and no crease; boundary vertices sit every 8 studs on every
edge, so neighbours share vertices and leave no T-junction. The relief fades into that profile over the outer
12 studs; corner normals come from the height field, so the seams carry no shading crease. Top-down UVs, one T_Tile_Sand_Alb repeat per 32 studs from the chunk's corner: chunks laid unrotated on
the 128-stud grid continue the sand pattern across the seam (a turned chunk still meets in shape). The surface is
an adaptive triangulation (greedy insertion on Blender's constrained Delaunay), so the triangles go where the sand
has shape and the calm sand (06 9.1: about 60% of a view) costs little.

Rim pieces (07 6.2: 1,000 tris each). Low rounded banks of coral rock that enclose the pool. Each is a closed slab
whose top is a height field over the arc's plan: from a toe buried in the sand 32 studs into the pool, up a soft foot
into a round dome (steepest 52 degrees), then a round shoulder over the outer face down to depth 86, below the Kelp
(70), Reef (60) and Ledge (70 to 100) floors beside the bulge, onto a flat buried base. Independent review loop 1
(06 16.1 lines 1, 5, 8, 9, 15, 18): each piece has its own uneven crest, a tall dome and a low saddle in different
places (4 to 12 above the surface; the Rim's own top is 12, 03 6.1), and a few broad rock masses of its own fused on
both faces by a soft maximum; within 5 studs of each joint both neighbours take one shared joint profile, and past
the joint each runs on 12 studs and dives under its neighbour, so a ring of pieces is one continuous bank with no
notch at a joint. The oval of 03 6.2 is the sand floor's outline, the toe line. Each piece is an arc concave toward
the pool (-Y, its front): Rim_01 follows the long sides of the oval (toe radius 140), Rim_02 its ends (64).
Texture: the rim cell of T_EnvNursery_Alb, a gradient map (three flat pastel coral blocks, a soft violet dark, a
rose-to-peach mid and a pale peach light, with two broad gradients), mapped by each vertex's exposure, not the
shared T_Tile_CoralRock_Alb (other zones use it; its polygon cells and pits read as cobbles here).

T_EnvNursery_Alb (07 6.2: the pastel atlas for the Nursery pieces, 512 x 512): one opaque cell per later piece
(S7-A1 and the deferred landmarks), each painted in three value blocks (06 4.1, 5.2): a pastel mid block in the
coral hues of 06 9.3, lit tops in pale warm tints, and a dark block that is the cell's own colour taken down and
toward blue-violet, all kept clear of the reserved colours (06 4.5).
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.normpath(os.path.join(HERE, "..", ".."))
for p in (os.path.join(SOURCE, "_shared", "blender"), os.path.join(SOURCE, "env", "rim"), os.path.join(SOURCE, "cove")):
    if p not in sys.path:
        sys.path.insert(0, p)

import common  # noqa: E402

# ---------------------------------------------------------------- sizes
CHUNK = 128.0                 # 06 6.3 sea-floor chunk
HALF = CHUNK / 2.0
SLAB = 8.0                    # sand level above the chunk's flat base
EDGE_STEP = 8.0               # boundary vertices every 8 studs on every edge
EDGE_BAND = 12.0              # relief fades into the edge profile over this band
SAND_DEPTH = 26.0             # the kit's sand level in the Nursery (03 6.2: floor 24 to 30)
SAND_TILE = 32.0              # 07 6.1: ground tiles repeat every 32 studs
SAND = "T_Tile_Sand_Alb"
FLOOR_TRIS = 2950             # target for the whole closed slab (06 6.3: 3,000)

CREST_MIN = 4.0               # the crest stays above the surface by at least this much along the whole span
FOOT_IN = -34.0               # the pool face reaches this far down (8 below the sand level)
BOTTOM = -86.0                # flat buried base
RIM_TRIS = 1000               # 07 6.2

# 06 10.2 Nursery preset; fog colour 06 4.2
NURSERY = {"sun": "#FFF3C4", "brightness": 2.2, "ambient": "#8FD3D6", "outdoor": "#B8ECEC", "fog": "#4CCFD2",
           "surface": "#9FF0E6", "deep": "#2FAFC0", "view": 450.0}
FOG = {"nursery": "#4CCFD2", "reef": "#1E9FD0", "kelp": "#238A72", "dropoff_upper": "#1B6FBF"}


def smooth(e0, e1, x):
    import numpy as np
    t = np.clip((np.asarray(x, dtype=float) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# ================================================================ floors

def edge_field(X, Y):
    """The profile every edge shares: g(x) + g(y) with g a sum of cosines of whole periods over the chunk,
    so it is symmetric (a chunk turned 180 degrees still matches) and flat across each edge."""
    import numpy as np

    def g(t):
        return 0.32 * np.cos(2.0 * math.pi * 2.0 * t / CHUNK) - 0.22 * np.cos(2.0 * math.pi * 3.0 * t / CHUNK + 0.0)
    return g(X) + g(Y)


def edge_mask(X, Y):
    import numpy as np
    return smooth(0.0, EDGE_BAND, HALF - np.abs(X)) * smooth(0.0, EDGE_BAND, HALF - np.abs(Y))


def _rot(X, Y, cx, cy, ang):
    a = math.radians(ang)
    dx, dy = X - cx, Y - cy
    return dx * math.cos(a) + dy * math.sin(a), -dx * math.sin(a) + dy * math.cos(a)


def mound(X, Y, cx, cy, rx, ry, ang, h, skew=0.0):
    """A soft dome (cosine bell), zero slope at its foot; skew > 0 steepens its +u side (a sand bank's lee)."""
    import numpy as np
    u, v = _rot(X, Y, cx, cy, ang)
    k = 1.0 + skew * np.clip(u / rx, -1.0, 1.0)
    r = np.sqrt((u * k / rx) ** 2 + (v / ry) ** 2)
    return h * 0.5 * (1.0 + np.cos(math.pi * np.clip(r, 0.0, 1.0)))


def dunes(X, Y, ang, lam, amp, seed, centres):
    """Sand waves in patches: crests run across `ang`, wavelength `lam`, asymmetric (steep lee), bent by a slow
    warp, faded in and out by soft patches around `centres` [(x, y, r)] so the calm sand stays calm."""
    import numpy as np
    rng = random.Random(seed)
    a = math.radians(ang)
    warp = sum(rng.uniform(0.5, 1.1) * np.sin(2 * math.pi * (X * math.cos(b) + Y * math.sin(b)) / rng.uniform(70, 140) + rng.uniform(0, 6.3))
               for b in (rng.uniform(0, 6.3) for _ in range(3)))
    ph = 2.0 * math.pi * (X * math.cos(a) + Y * math.sin(a)) / lam + 1.1 * warp
    wave = (np.sin(ph) + 0.33 * np.sin(2.0 * ph + 0.7)) / 1.25
    patch = np.zeros_like(X)
    for cx, cy, r in centres:
        patch = np.maximum(patch, 1.0 - smooth(0.35, 1.0, np.hypot(X - cx, Y - cy) / r))
    return amp * wave * patch


def bowl(X, Y, cx, cy, r, depth, lip, seed):
    """Krill Corner (03 6.2: a sandy bowl 50 across): a soft dish `depth` deep with an uneven raised lip."""
    import numpy as np
    rng = random.Random(seed)
    dx, dy = X - cx, Y - cy
    rr = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    wob = 1.0 + 0.06 * np.cos(2 * th + rng.uniform(0, 6.3)) + 0.04 * np.cos(3 * th + rng.uniform(0, 6.3))
    q = rr / (r * wob)
    dish = -depth * (1.0 - smooth(0.3, 1.05, q))         # review loop 3: a dish with a wall, not a dimple
    lipv = lip * (0.75 + 0.45 * np.cos(th - rng.uniform(0, 6.3))) * np.exp(-((q - 1.1) / 0.24) ** 2)
    return dish + lipv


FLOORS = {
    "M_Env_Nursery_Floor_01": {
        "title": "Hatch bank",
        "caption": "a low sand bank 3 high (the Hatch Bed sits on it, floor 24 at sand level 26), a small hump, a soft hollow",
        "features": [("mound", -12.0, 8.0, 36.0, 24.0, 28.0, 3.0, 0.35), ("mound", 30.0, -30.0, 15.0, 11.0, -20.0, 1.2, 0.0),
                     ("mound", 28.0, 30.0, 19.0, 14.0, 60.0, -1.3, 0.0),
                     ("dunes", 72.0, 17.0, 0.75, 11, [(26.0, -20.0, 38.0), (-36.0, -38.0, 26.0)])]},
    "M_Env_Nursery_Floor_02": {
        "title": "Ripple flat",
        "caption": "two fields of sand waves (18 and 13 studs apart), a shallow dish 2 deep and a low hump",
        "features": [("dunes", 35.0, 18.0, 0.9, 21, [(-26.0, 22.0, 40.0), (6.0, 40.0, 26.0)]),
                     ("dunes", 112.0, 13.0, 0.6, 22, [(30.0, -10.0, 34.0)]),
                     ("mound", -22.0, -24.0, 23.0, 17.0, 15.0, -2.0, 0.0), ("mound", 36.0, 34.0, 20.0, 14.0, -40.0, 0.9, 0.3)]},
    "M_Env_Nursery_Floor_03": {
        "title": "Krill Corner bowl",
        "caption": "the bowl of 03 6.2: 50 across, 5 deep, an uneven lip up to 3 high; a soft swell beside it",
        "features": [("bowl", 4.0, -4.0, 25.0, 4.9, 2.6, 31), ("mound", -40.0, 38.0, 20.0, 14.0, 35.0, 1.4, 0.0),
                     ("dunes", 150.0, 15.0, 0.5, 32, [(-30.0, -38.0, 26.0), (40.0, 36.0, 24.0)])]},
    "M_Env_Nursery_Floor_04": {
        "title": "Twin swells",
        "caption": "two swells 2.2 and 1.6 high with a saddle between, sand waves 20 apart on their flanks",
        "features": [("mound", -24.0, -18.0, 27.0, 19.0, 20.0, 2.2, 0.25), ("mound", 24.0, 22.0, 23.0, 16.0, -35.0, 1.6, 0.2),
                     ("mound", 30.0, -30.0, 18.0, 12.0, 50.0, -1.0, 0.0),
                     ("dunes", -20.0, 20.0, 0.8, 41, [(-2.0, 2.0, 30.0), (-40.0, 30.0, 24.0)])]},
}
FLOOR_NAMES = tuple(FLOORS)


def floor_height(name, X, Y):
    """Sand surface height above the chunk's base: SLAB + edge profile + relief faded into the edge band."""
    import numpy as np
    X = np.asarray(X, dtype=float)
    Y = np.asarray(Y, dtype=float)
    R = np.zeros_like(X)
    for f in FLOORS[name]["features"]:
        kind = f[0]
        if kind == "mound":
            R = R + mound(X, Y, *f[1:])
        elif kind == "dunes":
            R = R + dunes(X, Y, *f[1:])
        elif kind == "bowl":
            R = R + bowl(X, Y, *f[1:])
    return SLAB + edge_field(X, Y) + edge_mask(X, Y) * R


def boundary_points():
    """The square's boundary, counter-clockwise from (-64, -64), one vertex every EDGE_STEP studs."""
    n = int(round(CHUNK / EDGE_STEP))
    pts = []
    for i in range(n):
        pts.append((-HALF + i * EDGE_STEP, -HALF))
    for i in range(n):
        pts.append((HALF, -HALF + i * EDGE_STEP))
    for i in range(n):
        pts.append((HALF - i * EDGE_STEP, HALF))
    for i in range(n):
        pts.append((-HALF, HALF - i * EDGE_STEP))
    return pts


def _cdt(pts):
    from mathutils import Vector
    from mathutils.geometry import delaunay_2d_cdt
    out = delaunay_2d_cdt([Vector(p) for p in pts], [], [], 0, 1e-6)
    verts = [(v.x, v.y) for v in out[0]]
    faces = [tuple(f) for f in out[2]]
    return verts, faces


def adaptive_surface(name, top_tris):
    """Greedy insertion: start from the boundary and a coarse interior grid; each round re-triangulates and adds
    the worst-fitting candidate point of the worst triangles (height error, plus a little area so no triangle
    stays huge), until the surface reaches `top_tris` triangles. Returns (2D verts, triangles)."""
    import numpy as np
    bnd = boundary_points()
    b = len(bnd)
    want_n = (top_tris + b + 2) // 2
    pts = list(bnd)
    g = 16.0
    k = int(CHUNK / g)
    for i in range(1, k):
        for j in range(1, k):
            pts.append((-HALF + i * g, -HALF + j * g))
    bary = np.array([(1 / 3, 1 / 3, 1 / 3), (0.6, 0.2, 0.2), (0.2, 0.6, 0.2), (0.2, 0.2, 0.6),
                     (0.45, 0.45, 0.1), (0.1, 0.45, 0.45), (0.45, 0.1, 0.45)])
    while True:
        verts, faces = _cdt(pts)
        if len(verts) >= want_n:
            break
        V = np.array(verts)
        Hv = floor_height(name, V[:, 0], V[:, 1])
        F = np.array(faces)
        P = V[F]                                   # (m, 3, 2)
        C = np.einsum("kj,mjd->mkd", bary, P)      # (m, 7, 2) candidates
        lin = np.einsum("kj,mj->mk", bary, Hv[F])
        true = floor_height(name, C[..., 0], C[..., 1])
        err = np.abs(true - lin)
        area = 0.5 * np.abs((P[:, 1, 0] - P[:, 0, 0]) * (P[:, 2, 1] - P[:, 0, 1]) - (P[:, 2, 0] - P[:, 0, 0]) * (P[:, 1, 1] - P[:, 0, 1]))
        best = err.argmax(axis=1)
        score = err[np.arange(len(F)), best] + 0.0025 * area
        order = np.argsort(-score)
        room = want_n - len(verts)
        batch = max(8, min(room, len(F) // 10))
        added = []
        for m in order:
            if len(added) >= batch:
                break
            p = C[m, best[m]]
            if all((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 > 2.0 ** 2 for q in added):
                added.append((float(p[0]), float(p[1])))
        if not added:
            break
        pts = verts + added
    return verts, faces


def build_floor(name):
    """One closed sand slab: adaptive top, vertical skirt on the boundary, flat base (06 6.5: watertight)."""
    import numpy as np
    import rimart as ra
    bnd = boundary_points()
    b = len(bnd)
    bottom_2d, bottom_faces = _cdt(bnd)
    top_tris = FLOOR_TRIS - 2 * b - (len(bottom_faces))
    verts2, faces2 = adaptive_surface(name, top_tris)
    V = np.array(verts2)
    H = floor_height(name, V[:, 0], V[:, 1])
    verts = [(float(x), float(y), float(h)) for (x, y), h in zip(verts2, H)]
    faces = list(faces2)
    index = {(round(x, 4), round(y, 4)): i for i, (x, y) in enumerate(verts2)}
    loop = [index[(round(x, 4), round(y, 4))] for x, y in bnd]
    base0 = len(verts)
    verts += [(x, y, 0.0) for x, y in bnd]
    for k in range(b):
        a, c = loop[k], loop[(k + 1) % b]
        faces.append((a, c, base0 + (k + 1) % b, base0 + k))
    bmap = {(round(x, 4), round(y, 4)): base0 + i for i, (x, y) in enumerate(bnd)}
    for f in bottom_faces:
        faces.append(tuple(bmap[(round(bottom_2d[i][0], 4), round(bottom_2d[i][1], 4))] for i in reversed(f)))
    ob = ra.mesh_object(name, verts, faces)
    ra.tidy(ob)
    floor_uvs(ob)
    ra.finish(ob, front_fn=lambda co: co.y < -HALF + 8.0)
    floor_normals(ob, name)
    return ob


def floor_normals(ob, name, eps=0.25):
    """Review loop 1: the sand's corner normals come from the height field itself, not from the triangles. Along
    an edge the field is the shared profile with no slope across it, so two chunks side by side carry the same
    normal on the seam and no shading crease shows; inside, the light runs smooth over the big calm triangles.
    The skirt and the base keep their face normals."""
    import numpy as np
    me = ob.data
    co = np.array([v.co[:] for v in me.vertices])
    X, Y = co[:, 0], co[:, 1]
    hx = (floor_height(name, X + eps, Y) - floor_height(name, X - eps, Y)) / (2 * eps)
    hy = (floor_height(name, X, Y + eps) - floor_height(name, X, Y - eps)) / (2 * eps)
    n = np.stack([-hx, -hy, np.ones_like(hx)], axis=1)
    n /= np.linalg.norm(n, axis=1)[:, None]
    out = []
    for poly in me.polygons:
        top = poly.normal.z > 0.5
        for li in poly.loop_indices:
            out.append(tuple(n[me.loops[li].vertex_index]) if top else tuple(poly.normal))
    me.normals_split_custom_set(out)
    me.update()


def floor_uvs(ob):
    """Top and base: top-down, one repeat per 32 studs from the chunk's corner. Skirt: along the edge and up."""
    me = ob.data
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    uvl = me.uv_layers.new(name=common.UV_NAME).data
    vs = me.vertices
    for poly in me.polygons:
        n = poly.normal
        for li in poly.loop_indices:
            v = vs[me.loops[li].vertex_index].co
            if abs(n.z) >= 0.5:
                u, w = (v.x + HALF) / SAND_TILE, (v.y + HALF) / SAND_TILE
            elif abs(n.x) >= abs(n.y):
                u, w = (v.y + HALF) / SAND_TILE, v.z / SAND_TILE
            else:
                u, w = (v.x + HALF) / SAND_TILE, v.z / SAND_TILE
            uvl[li].uv = (u, w)


def floor_checks(objs):
    """Edge match: every chunk's boundary carries the shared profile at the shared spacing, so any two chunks
    meet at any turn; and the surface stays inside the Nursery's depths (03 6.2: 0 to 30, floor 24 to 30)."""
    def check(spec, report):
        import numpy as np
        for ob in objs:
            vs = ob.data.vertices
            top = [v.co for v in vs if v.co.z > 0.5]
            edge = [p for p in top if abs(abs(p.x) - HALF) < 1e-3 or abs(abs(p.y) - HALF) < 1e-3]
            along = sorted({round(p.y if abs(abs(p.x) - HALF) < 1e-3 else p.x, 3) for p in edge})
            want = sorted({round(-HALF + i * EDGE_STEP, 3) for i in range(int(CHUNK / EDGE_STEP) + 1)})
            prof = [abs(p.z - (SLAB + float(edge_field(np.array(p.x), np.array(p.y))))) for p in edge]
            report.add(ob.name, "edges match any chunk", along == want and max(prof) < 0.01,
                       "%d boundary vertices on the 8-stud spacing, off the shared edge profile by at most %.4f studs"
                       % (len(edge), max(prof)))
            zs = [p.z for p in top]
            lo, hi = SAND_DEPTH - (max(zs) - SLAB), SAND_DEPTH + (SLAB - min(zs))
            report.add(ob.name, "inside the Nursery's depths", 22.0 <= lo and hi <= 31.0,
                       "at sand level depth %.0f the floor runs from depth %.1f to %.1f (03 6.2: floor 24 to 30, krill bowl lip)"
                       % (SAND_DEPTH, lo, hi))
            slopes = []
            me = ob.data
            for p in me.polygons:
                if p.normal.z > 0.2:
                    slopes.append(math.degrees(math.acos(min(1.0, p.normal.z))))
            report.add(ob.name, "gentle sand", max(slopes) < 35.0,
                       "steepest sand face %.1f degrees (a paddling pool: nothing steep)" % max(slopes))
    return check


# ================================================================ rim pieces
# Independent review loop 3 (06 16.1 lines 1, 4, 5, 9, 18). Every piece is built on one cross-section, a broad low
# dome; its crest line rises from the joint crest by smooth bumps that fade to nothing within BAND of each joint,
# so every joint is the same profile and the two pieces still differ in silhouette. The mesh is a structured grid:
# columns across the bank, and rows that run along the bank's level lines, so the three value blocks end on edge
# loops (smooth, level boundaries, no jagged blotches) and a piece's ends take exactly the colours of its middle.

RIMS = {
    # radius and span at the waterline (d 0); cols: columns over the span (each nose adds NOSE_X). crest: (s as a
    # share of the span, rise over the joint crest (a dip if negative), half-width in studs, lean); a lean widens
    # the bump's -s side and steepens its +s side by that share.
    "M_Env_Nursery_Rim_01": {"radius": 172.0, "span": 64.0, "cols": 11,
                             "crest": [(-0.25, -1.2, 10.0, 0.0), (0.12, 2.6, 14.0, 0.0)],
                             "title": "long low swell", "caption": "gentle arc: waterline radius 172, 64 studs"},
    "M_Env_Nursery_Rim_02": {"radius": 96.0, "span": 50.0, "cols": 9,
                             "crest": [(-0.24, -1.6, 7.0, 0.0), (0.12, 5.2, 10.0, 0.3)],
                             "title": "fuller hump, leaning", "caption": "tight arc: waterline radius 96, 50 studs"},
}
RIM_NAMES = tuple(RIMS)

TOE, UNDER, OUTER = -32.0, -46.0, 104.0   # unbent d: the buried toe, where the bank meets the base on each side
TOE_Z = -30.0                 # the toe, buried 4 below the sand
DC = 18.0                     # the crest's d
POOL_M = 1.9                  # the pool face: 1 - (1 - t)^m, convex all the way, flat at the crest
OUTER_Q = 1.7                 # the outer face: crest - drop * u^q, convex, flat at the crest
JOINT_CREST = 6.0             # the crest at every joint, above the surface ...
JOINT_FALL = 0.12             # ... falling this much a stud toward +s across it (rim_crest)
BAND = 5.0                    # within BAND of a joint every piece is exactly the joint profile
RAMP = 11.0                   # a piece's own crest then grows in over RAMP studs
END = 30.0                    # a piece runs this far past each joint, under its neighbour
HOLD = 0.3                    # over the first 30% of that it keeps the joint profile, sunk by SINK x^2 ...
SINK = 6.0
NOSE_X = (0.15, 0.3, 0.475, 0.65, 0.825, 1.0)    # ... then it dives to the base (a rounded nose on a lone piece)
SAND_Z = -SAND_DEPTH          # the pool face shows above the sand ...
OUTER_FLOOR_Z = -66.0         # ... and the outer face above the Reef, Kelp and Ledge floors beside the bulge (60 to 70)
RIM_TOP = 12.0                # 03 6.1: the Rim's own top above the surface
NOTCH_MAX = 0.25              # the visible crest may dip this little at a joint ...
NOTCH_WIN = 8.0               # ... measured within this of it
POKE_MAX = 0.05               # a nose may rise this little above the neighbour it runs under
CREST_VARY = 0.25             # independent review loop 1: the crest varies by at least 25% of its peak along a piece
POOL_DARK = 2.5               # value blocks on the pool face (what the game camera sees): a thin dark toe band from
POOL_LIGHT = -3.5             # the sand line, the light cap from 3.5 under the surface; the outer face's two
                              # boundaries are solved for 06 4.1's shares (rim_rows)


def abs_(x):
    import numpy as np
    return np.abs(np.asarray(x, dtype=float))


def bend(p, Rf):
    """Unrolled (s along the pool face, d out from the pool, z up from the surface) -> piece frame: an arc of
    radius Rf whose centre lies on the pool side at (0, -Rf); the pool face at s = 0 is the origin's -Y side."""
    s, d, z = p
    phi = s / Rf
    r = Rf + d
    return (r * math.sin(phi), r * math.cos(phi) - Rf, z)


def unbend(co, Rf):
    r = math.hypot(co[0], co[1] + Rf)
    return math.atan2(co[0], co[1] + Rf) * Rf, r - Rf, co[2]


def rim_weight(name, S):
    """1 where the piece shows its own crest, 0 within BAND of a joint (and past it), smooth in between."""
    h = RIMS[name]["span"] / 2.0
    return smooth(h - BAND, h - BAND - RAMP, abs_(S))


def rim_crest(name, S):
    """Crest height above the surface along the piece. Near every joint it is the joint line: JOINT_CREST at the
    joint, falling JOINT_FALL a stud toward +s, so a joint sits on the flank of a roll, never at a dip or a peak (a
    ring of pieces reads as one rolling bank, not a row of humps); inside, the piece's own dip and swell."""
    import numpy as np
    cfg = RIMS[name]
    L = cfg["span"]
    h = L / 2.0
    S = np.asarray(S, dtype=float)
    own = np.zeros_like(S)
    for frac, amp, wid, lean in cfg["crest"]:
        c = frac * L
        w = np.where(S < c, wid * (1.0 + lean), wid * (1.0 - lean))
        own = own + amp * np.exp(-((S - c) / w) ** 2)
    line = JOINT_CREST - JOINT_FALL * (S - np.sign(S) * h)
    w = rim_weight(name, S)
    return (1.0 - w) * line + w * (JOINT_CREST + own)


def rim_profile(D, C):
    """The bank across: from the base, up under the sand to the buried toe, up the convex pool face into a round
    dome at (DC, C), then down the convex outer face to the base. No flat top and no vertical wall."""
    import numpy as np
    D = np.asarray(D, dtype=float)
    t = np.clip((D - TOE) / (DC - TOE), 0.0, 1.0)
    pool = TOE_Z + (C - TOE_Z) * (1.0 - (1.0 - t) ** POOL_M)
    under = np.clip((TOE - D) / (TOE - UNDER), 0.0, 1.0)
    pool = pool - (TOE_Z - BOTTOM) * (1.0 - np.cos(0.5 * math.pi * under))
    u = np.clip((D - DC) / (OUTER - DC), 0.0, 1.0)
    outer = C - (C - BOTTOM) * u ** OUTER_Q
    return np.where(D < DC, pool, outer)


def pool_d(z, C):
    """d on the pool face where the bank is at height z (TOE_Z <= z <= C)."""
    import numpy as np
    g = np.clip((z - TOE_Z) / (C - TOE_Z), 0.0, 1.0)
    return TOE + (DC - TOE) * (1.0 - (1.0 - g) ** (1.0 / POOL_M))


def outer_d(z, C):
    import numpy as np
    g = np.clip((C - z) / (C - BOTTOM), 0.0, 1.0)
    return DC + (OUTER - DC) * g ** (1.0 / OUTER_Q)


def nose(name, S, Z):
    """Past each joint: the joint profile sunk by SINK x^2 (x the share of END), then a dive to the base."""
    import numpy as np
    h = RIMS[name]["span"] / 2.0
    x = np.clip((abs_(S) - h) / END, 0.0, 1.0)
    Z = Z - SINK * x ** 2
    y = np.clip((x - HOLD) / (1.0 - HOLD), 0.0, 1.0)
    dv = np.where(y <= 0.75, 0.4 * (y / 0.75) ** 2, 0.4 + 0.6 * (y - 0.75) / 0.25)
    return Z - (Z - (BOTTOM + 2.0)) * dv


def rim_height(name, S, D):
    """Height of the bank (z, the surface at 0) over unbent (s, d)."""
    import numpy as np
    S, D = np.broadcast_arrays(np.asarray(S, dtype=float), np.asarray(D, dtype=float))
    Z = nose(name, S, rim_profile(D, rim_crest(name, S)))
    return np.where((D <= UNDER) | (D >= OUTER), BOTTOM, np.maximum(Z, BOTTOM))


def crest_line(name, ss, step=0.25):
    """Highest point of the bank across each s of `ss`, from the height field."""
    import numpy as np
    ds = np.arange(TOE, OUTER + 1e-6, step)
    S, D = np.meshgrid(np.asarray(ss, dtype=float), ds, indexing="ij")
    return rim_height(name, S, D).max(axis=1)


def rim_columns(name):
    import numpy as np
    cfg = RIMS[name]
    h = cfg["span"] / 2.0
    mid = np.linspace(-h, h, cfg["cols"] + 1)
    nx = np.array(NOSE_X) * END
    return np.concatenate([-(h + nx[::-1]), mid, h + nx])


# the rows across the bank: (row kind, value block of the quad above it); see rim_rows
ROW_BLOCKS = ("buried", "buried", "dark", "mid", "mid", "mid", "mid", "light", "light", "light", "light", "light",
              "light", "mid", "mid", "mid", "mid", "dark", "buried")


def rim_rows(name, outer_dark, outer_light):
    """(S, D, Z, Z0, frac) for the grid, columns x rows: rows 0 to 19 run base, toe, sand line, pool dark top,
    three mid rows, the pool light line, two light rows, the crest, two light rows, the outer light line, three mid
    rows, the outer dark top, the outer floors' line, base. Z0 is the height before the nose; frac the place of a
    vertex in its face's mid block (0 at the dark top, 1 at the light line), for the mid gradient. outer_dark: the
    outer dark top's height above the floors' line; outer_light: the outer light line's depth under the crest."""
    import numpy as np
    ss = rim_columns(name)
    C = rim_crest(name, ss)
    lerp = lambda a, b, k: a + (b - a) * k
    p_sand, p_dark, p_light = pool_d(SAND_Z, C), pool_d(SAND_Z + POOL_DARK, C), pool_d(POOL_LIGHT, C)
    o_light, o_dark, o_floor = outer_d(C - outer_light, C), outer_d(OUTER_FLOOR_Z + outer_dark, C), outer_d(OUTER_FLOOR_Z, C)
    cols = [np.full_like(C, UNDER), np.full_like(C, TOE), p_sand, p_dark]
    cols += [lerp(p_dark, p_light, k / 4.0) for k in (1, 2, 3)]
    cols += [p_light] + [lerp(p_light, np.full_like(C, DC), k / 3.0) for k in (1, 2)] + [np.full_like(C, DC)]
    cols += [lerp(np.full_like(C, DC), o_light, k / 3.0) for k in (1, 2)] + [o_light]
    cols += [lerp(o_light, o_dark, k / 4.0) for k in (1, 2, 3)] + [o_dark, o_floor, np.full_like(C, OUTER)]
    D = np.stack(cols, axis=1)
    S = np.repeat(ss[:, None], D.shape[1], axis=1)
    Z0 = rim_profile(D, C[:, None])
    Z0[:, 0] = Z0[:, -1] = BOTTOM
    Z = np.maximum(nose(name, S, Z0), BOTTOM)
    Z[:, 0] = Z[:, -1] = BOTTOM
    fp = (Z0 - (SAND_Z + POOL_DARK)) / (POOL_LIGHT - (SAND_Z + POOL_DARK))
    fo = (Z0 - (OUTER_FLOOR_Z + outer_dark)) / (C[:, None] - outer_light - (OUTER_FLOOR_Z + outer_dark))
    frac = np.clip(np.where(D < DC, fp, fo), 0.0, 1.0)
    return S, D, Z, Z0, frac


def _bend_np(name, S, D):
    import numpy as np
    R = RIMS[name]["radius"]
    return (R + D) * np.sin(S / R), (R + D) * np.cos(S / R) - R


def rim_shares(name, outer_dark, outer_light):
    """Area shares of the dark, mid and light blocks over every face that is not buried, as validate measures
    them on the painted texture."""
    import numpy as np
    S, D, Z, _, _ = rim_rows(name, outer_dark, outer_light)
    X, Y = _bend_np(name, S, D)
    P = np.stack([X, Y, Z], axis=-1)
    a, b, c, d = P[:-1, :-1], P[1:, :-1], P[1:, 1:], P[:-1, 1:]
    area = 0.5 * (np.linalg.norm(np.cross(b - a, c - a), axis=-1) + np.linalg.norm(np.cross(c - a, d - a), axis=-1))
    acc = {"dark": 0.0, "mid": 0.0, "light": 0.0}
    for j, blk in enumerate(ROW_BLOCKS):
        if blk in acc:
            acc[blk] += float(area[:, j].sum())
    tot = sum(acc.values())
    return {k: v / tot for k, v in acc.items()}


def solve_bands(name):
    """The outer face's dark top (above the floors' line) and light line (under the crest), by bisection, for 06
    4.1's shares (RIM_SHARE): the pool face's two lines are fixed by eye (POOL_DARK, POOL_LIGHT)."""
    od, ol = 10.0, 10.0
    for _ in range(4):
        lo, hi = 0.5, 50.0
        for _ in range(40):
            od = 0.5 * (lo + hi)
            lo, hi = (od, hi) if rim_shares(name, od, ol)["dark"] < RIM_SHARE["dark"] else (lo, od)
        lo, hi = 0.5, 40.0
        for _ in range(40):
            ol = 0.5 * (lo + hi)
            lo, hi = (ol, hi) if rim_shares(name, od, ol)["light"] < RIM_SHARE["light"] else (lo, ol)
    return od, ol


def build_rim(name, target=None):
    """One rim piece: the structured grid of rim_rows bent onto the piece's arc, closed by a flat base strip and
    two end walls (both buried: the noses end 2 studs above the base); the value blocks go on by rows."""
    import numpy as np
    import rimart as ra
    Rf = RIMS[name]["radius"]
    od, ol = solve_bands(name)
    S, D, Z, Z0, frac = rim_rows(name, od, ol)
    X, Y = _bend_np(name, S, D)
    nc, nr = S.shape
    verts = [(float(X[i, j]), float(Y[i, j]), float(Z[i, j])) for i in range(nc) for j in range(nr)]
    vid = lambda i, j: i * nr + j
    faces, blocks = [], []
    for i in range(nc - 1):
        for j in range(nr - 1):
            faces.append((vid(i, j), vid(i + 1, j), vid(i + 1, j + 1), vid(i, j + 1)))
            blocks.append(ROW_BLOCKS[j])
    for i in range(nc - 1):                                     # the base strip
        faces.append((vid(i, 0), vid(i, nr - 1), vid(i + 1, nr - 1), vid(i + 1, 0)))
        blocks.append("buried")
    faces.append(tuple(vid(0, j) for j in range(nr))[::-1])     # the end walls
    faces.append(tuple(vid(nc - 1, j) for j in range(nr)))
    blocks += ["buried", "buried"]
    ob = ra.mesh_object(name, verts, faces)
    me = ob.data
    me.uv_layers.new(name=common.UV_NAME)
    uvl = me.uv_layers[0].data
    B = RIM_BANDS
    fl = frac.reshape(-1)
    px = ATLAS_CELLS[RIM_CELL][2] / 2.0
    for poly, blk in zip(me.polygons, blocks):
        for li in poly.loop_indices:
            k = me.loops[li].vertex_index
            if blk == "mid":
                b = B["dark"] + 0.5 + (B["mid"] - B["dark"] - 1.0) * fl[k]
            else:
                b = {"buried": 0.5 * (B["inset"] + B["buried"]), "dark": 0.5 * (B["buried"] + B["dark"]),
                     "light": 0.5 * (B["mid"] + B["top"])}[blk]
            uvl[li].uv = rim_cell_uv(px, b)
    ra.tidy(ob)
    sh = rim_shares(name, od, ol)
    ob["rim_value_shares"] = [round(100 * sh[k], 1) for k in ("dark", "mid", "light")]
    ob["rim_outer_lines"] = [round(OUTER_FLOOR_Z + od, 2), round(ol, 2)]
    print("[nursery] %s: outer dark top z %.1f, outer light line %.1f under the crest: dark %.1f%%, mid %.1f%%, light %.1f%%"
          % (name, OUTER_FLOOR_Z + od, ol, 100 * sh["dark"], 100 * sh["mid"], 100 * sh["light"]))
    ra.finish(ob, front_fn=lambda co: unbend(co, Rf)[1] < -4.0 and co.z > -60.0)    # the pool face and the toe under it
    return ob


# ---------------------------------------------------------------- joints and chains

def pose_point(pose, X, Y):
    th, tx, ty = pose
    c, s = math.cos(th), math.sin(th)
    return c * X - s * Y + tx, s * X + c * Y + ty


def pose_local(pose, X, Y):
    th, tx, ty = pose
    c, s = math.cos(th), math.sin(th)
    X, Y = X - tx, Y - ty
    return c * X + s * Y, -s * X + c * Y


def next_pose(pose, a, b):
    """The pose (turn, x, y) of piece b's frame when its -s joint meets piece a's +s joint at the waterline with
    the tangents matched (a G1 chain of arcs: every row line runs on across the joint)."""
    ha, Ra = RIMS[a]["span"] / 2.0, RIMS[a]["radius"]
    hb, Rb = RIMS[b]["span"] / 2.0, RIMS[b]["radius"]
    thb = pose[0] - ha / Ra - hb / Rb
    qx, qy = pose_point(pose, *bend((ha, 0.0, 0.0), Ra)[:2])
    px, py = pose_point((thb, 0.0, 0.0), *bend((-hb, 0.0, 0.0), Rb)[:2])
    return (thb, qx - px, qy - py)


def ring_poses(seq, reps):
    """A closed ring: the chain `seq` repeated `reps` times round a centre (the origin). Within a unit the joints
    are exact; between units the tangents differ by the unit's turn short of 2 pi / reps (a fraction of a degree)."""
    import numpy as np
    poses = [(0.0, 0.0, 0.0)]
    for a, b in zip(seq, seq[1:]):
        poses.append(next_pose(poses[-1], a, b))
    nxt = next_pose(poses[-1], seq[-1], seq[0])
    h0, R0 = RIMS[seq[0]]["span"] / 2.0, RIMS[seq[0]]["radius"]
    sx, sy = bend((-h0, 0.0, 0.0), R0)[:2]
    ex, ey = pose_point(nxt, sx, sy)
    al = -2.0 * math.pi / reps
    Ra = np.array([[math.cos(al), -math.sin(al)], [math.sin(al), math.cos(al)]])
    O = np.linalg.solve(np.eye(2) - Ra, np.array([ex, ey]) - Ra @ np.array([sx, sy]))
    out = []
    for m in range(reps):
        c, s = math.cos(m * al), math.sin(m * al)
        for name, (th, tx, ty) in zip(seq, poses):
            x, y = tx - O[0], ty - O[1]
            out.append((name, th + m * al, c * x - s * y, s * x + c * y))
    return out


def _height_or_none(name, S, D):
    import numpy as np
    h = RIMS[name]["span"] / 2.0
    z = rim_height(name, S, D)
    return np.where((abs_(S) <= h + END) & (D >= UNDER) & (D <= OUTER), z, -1e9)


def joint_report():
    """Every neighbour pair (a's +s joint on b's -s joint, chained as next_pose places them), on the real plan: the
    visible bank is the higher of the two. Returns [(pair, notch, poke)]: notch, how far the visible crest within
    NOTCH_WIN of the joint dips under the straight line between its ends there (a V at the joint); poke, how far either piece rises above the other on the other's
    side (more than a stud past the joint, above the floors), which would show as a seam."""
    import numpy as np
    out = []
    win = BAND + RAMP
    ds = np.arange(UNDER, OUTER + 1e-6, 0.5)
    for a in RIM_NAMES:
        for b in RIM_NAMES:
            ha, Ra = RIMS[a]["span"] / 2.0, RIMS[a]["radius"]
            pb = next_pose((0.0, 0.0, 0.0), a, b)
            ss = np.arange(ha - win, ha + win + 1e-6, 0.25)
            S, D = np.meshgrid(ss, ds, indexing="ij")
            za = _height_or_none(a, S, D)
            X, Y = _bend_np(a, S, D)
            Xb, Yb = pose_local(pb, X, Y)
            Rb = RIMS[b]["radius"]
            Sb, Db = np.arctan2(Xb, Yb + Rb) * Rb, np.hypot(Xb, Yb + Rb) - Rb
            zb = _height_or_none(b, Sb, Db)
            vis = np.maximum(za, zb)
            crest = vis.max(axis=1)
            near = np.abs(ss - ha) <= NOTCH_WIN
            cn, sn = crest[near], ss[near]
            chord = cn[0] + (cn[-1] - cn[0]) * (sn - sn[0]) / (sn[-1] - sn[0])
            notch = float(max(0.0, (chord - cn).max()))
            floor = np.where(D < DC, SAND_Z, OUTER_FLOOR_Z)
            past, before = S > ha + 1.0, S < ha - 1.0
            pa = np.where(past & (za > floor), za - zb, 0.0).max()
            pbk = np.where(before & (zb > floor), zb - za, 0.0).max()
            out.append(("%s>%s" % (a[-2:], b[-2:]), notch, float(max(0.0, pa, pbk))))
    return out


RIM_CELL = "rim_bank"
# the rim cell's bands, in pixels from the cell's bottom (64 x 256 cell; independent review loop 3: three flat
# blocks, the mid with one broad gradient up the bank). Rows below 16 are the buried band (outside the value count):
# faces under the sand, under the neighbouring floors, the end walls and the base, painted the mid's foot colour.
RIM_BANDS = {"inset": 8, "buried": 16, "dark": 42, "mid": 192, "top": 248}
RIM_SHARE = {"dark": 0.115, "light": 0.25}   # 06 4.1: dark 10-15%, light 20-30% of the bank above the floors


def rim_cell_uv(px, b):
    """Cell pixel (px from its left, b from its bottom) -> atlas UV (Blender, v up)."""
    x0, y0, w, h = ATLAS_CELLS[RIM_CELL]
    return (x0 + px) / float(N), 1.0 - (y0 + h - b) / float(N)


def rim_sampler(img):
    """For validate's value check: (block, sRGB) of the atlas texel at (u, v); the rim cell's buried band and every
    other cell are 'none', outside the count."""
    x0, y0, w, h = ATLAS_CELLS[RIM_CELL]
    B = RIM_BANDS

    def sample(u, v):
        r = min(N - 1, max(0, int((1.0 - v) * N)))
        c = min(N - 1, max(0, int(u * N)))
        if not (x0 <= c < x0 + w and y0 <= r < y0 + h):
            return "none", (0.0, 0.0, 0.0)
        b = y0 + h - 1 - r + 0.5
        block = "none" if b < B["buried"] else "dark" if b < B["dark"] else "mid" if b < B["mid"] else "light"
        return block, tuple(float(x) for x in img[r, c, :3])
    return sample


def rim_uv_check(objs):
    """No texture cell edge crosses a rim face: every UV 8 px or more inside the rim cell."""
    def check(spec, report):
        x0, y0, w, h = ATLAS_CELLS[RIM_CELL]
        ins = RIM_BANDS["inset"] - 1e-3
        for ob in objs:
            uv = ob.data.uv_layers[0].data
            px = [(d.uv.x * N - x0, (1.0 - d.uv.y) * N - y0) for d in uv]
            lo_x, hi_x = min(p[0] for p in px), max(p[0] for p in px)
            lo_y, hi_y = min(p[1] for p in px), max(p[1] for p in px)
            ok = lo_x >= ins and hi_x <= w - ins and lo_y >= ins and hi_y <= h - ins
            report.add(ob.name, "UVs inside the rim cell", ok,
                       "cell %s of %s at (%d, %d) %d x %d: UVs %.1f to %.1f across, %.1f to %.1f down (8 px margin)"
                       % (RIM_CELL, ATLAS, x0, y0, w, h, lo_x, hi_x, lo_y, hi_y))
    return check


def surface_samples(ob, off, Rf, per=12):
    """Points spread over every triangle (a coarse mesh has few vertices on its crest), unbent to (s, d, z)."""
    rng = random.Random(5)
    vs = ob.data.vertices
    out = []
    for p in ob.data.polygons:
        a, b, c = (vs[i].co for i in p.vertices[:3])
        for _ in range(per):
            u, v = rng.random(), rng.random()
            if u + v > 1.0:
                u, v = 1.0 - u, 1.0 - v
            q = a + (b - a) * u + (c - a) * v
            out.append(unbend((q.x + off.x, q.y + off.y, q.z + off.z), Rf))
    return out


def rim_checks(objs, offs):
    """Encloses the pool: the crest stays above the surface over the whole span (and 4 above it away from the
    joints), the pool face reaches below the sand everywhere (no gap at the foot), the face and crest run out
    past the joints, where neighbours overlap; the slopes stay under 65 degrees above the floors (no wall)."""
    def check(spec, report):
        import numpy as np
        for ob in objs:
            cfg = RIMS[ob.name]
            Rf, L = cfg["radius"], cfg["span"]
            h = L / 2.0
            pts = surface_samples(ob, offs[ob.name], Rf)
            bins = 2 * int(L / 4.0)
            mids, foot = [], []
            for k in range(bins):
                s0 = -h + L * k / bins
                s1 = s0 + L / bins
                col = [p for p in pts if s0 <= p[0] < s1]
                mids.append(max((p[2] for p in col), default=-999.0))
                foot.append(min((p[2] for p in col if p[1] < 6.0), default=999.0))
            report.add(ob.name, "crest above the surface", min(mids) >= CREST_MIN,
                       "crest %.1f to %.1f studs above the surface between the joints (at least %.0f; the Rim's own top is 12); "
                       "past each joint the piece runs %.0f studs under its neighbour" % (min(mids), max(mids), CREST_MIN, END))
            report.add(ob.name, "pool face buried", max(foot) <= -(SAND_DEPTH + 3.0),
                       "the pool face reaches depth %.1f or lower all along (sand level %.0f, relief to 30)" % (-max(foot), SAND_DEPTH))
            ext = [p[0] for p in pts if p[2] > -26.0 and p[1] < 20.0]
            report.add(ob.name, "face reaches the joints", min(ext) <= -h - 2.0 and max(ext) >= h + 2.0,
                       "pool face and crest run from s %.1f to %.1f of +-%.1f (neighbours overlap there)" % (min(ext), max(ext), h))
            vary = (max(mids) - min(mids)) / max(mids)
            report.add(ob.name, "uneven crest", vary >= CREST_VARY and max(mids) <= RIM_TOP,
                       "the crest rises and falls by %.0f%% of its peak along the piece (at least %.0f%%; %.1f at its lowest, "
                       "%.1f at its top; never above the Rim's top, %.0f)" % (100 * vary, 100 * CREST_VARY, min(mids), max(mids), RIM_TOP))
            ss = np.linspace(-h, h, 33)
            ds = np.arange(UNDER, OUTER + 1e-6, 0.25)
            S, D = np.meshgrid(ss, ds, indexing="ij")
            Z = rim_height(ob.name, S, D)
            slope = np.degrees(np.arctan(np.abs(np.gradient(Z, 0.25, axis=1))))
            shown = Z > np.where(D < DC, SAND_Z, OUTER_FLOOR_Z)
            steep = float(slope[shown].max())
            report.add(ob.name, "sloped sides, no wall", steep <= 65.0,
                       "steepest %.0f degrees across the bank above the sand and the outer floors (limit 65); a convex dome "
                       "flat at its crest" % steep)
        rows = joint_report()
        worst_notch, worst_poke = max(r[1] for r in rows), max(r[2] for r in rows)
        report.add(objs[0].name, "joints: one bank", worst_notch <= NOTCH_MAX and worst_poke <= POKE_MAX,
                   "every neighbour pair (%s), chained tangent to tangent: the visible crest dips at most %.2f at a joint "
                   "(limit %.2f); a nose rises at most %.3f above the piece it runs under (limit %.2f)" % (
                       ", ".join(r[0] for r in rows), worst_notch, NOTCH_MAX, worst_poke, POKE_MAX))
        for ob in objs:
            d_, m_, l_ = ob.get("rim_value_shares", (0, 0, 0))
            report.add(ob.name, "three values on the bank", 10 <= d_ <= 15 and 55 <= m_ <= 65 and 20 <= l_ <= 30,
                       "dark %.1f%%, mid %.1f%%, light %.1f%% of the bank above the floors (06 4.1); its block lines run "
                       "level along edge loops" % (d_, m_, l_))
    return check


# ================================================================ T_EnvNursery_Alb

ATLAS = "T_EnvNursery_Alb"
N = 512
WARM = "#FFF6D9"
ATLAS_CELLS = {               # (x, y, w, h) in pixels, top-left origin; meshes keep UVs 8 px inside a cell
    "coral_bubble": (0, 0, 128, 128), "coral_knob": (128, 0, 128, 128), "coral_brain": (256, 0, 128, 128),
    "buoy": (384, 0, 128, 128),
    "arch_coral": (0, 128, 192, 256), "rim_bank": (192, 128, 64, 256),
    "grass_gold": (256, 128, 64, 256), "grass_olive": (320, 128, 64, 256),
    "ring_coral": (384, 128, 128, 64), "shell_lights": (384, 192, 128, 64),
    "coral_crust": (384, 256, 128, 128),
    "clam_shell": (0, 384, 128, 128), "clam_mantle": (128, 384, 128, 128),
    "sign_shell": (256, 384, 128, 128), "post_drift": (384, 384, 128, 128),
}
CELL_USE = {
    "coral_bubble": "M_Env_Nursery_Coral_01 (pink bubble coral)", "coral_knob": "M_Env_Nursery_Coral_02 (peach knob coral)",
    "coral_brain": "M_Env_Nursery_Coral_03 (lilac brain coral)", "buoy": "M_Env_Nursery_GlowBuoy (float; glow by cap)",
    "arch_coral": "M_Env_Nursery_LM_LittleArch (pink coral, wraps both ways)",
    "rim_bank": "M_Env_Nursery_Rim_01-02 (gradient map: three blocks up the cell, by mesh rows)", "grass_gold": "M_Env_Nursery_GrassTuft_01",
    "grass_olive": "M_Env_Nursery_GrassTuft_02", "ring_coral": "M_Env_Nursery_LM_ThreeRings (wraps across)",
    "shell_lights": "Little Arch shell lights", "coral_crust": "Little Arch tunnel and coral feet (shaded crust)",
    "clam_shell": "M_Env_Nursery_LM_SleepyClam shell", "clam_mantle": "Sleepy Clam mantle",
    "sign_shell": "M_Prop_Nursery_ShellSign (arch and arrow picture)", "post_drift": "Shell Sign post",
}
MIDS = {   # review loop 1: pastel mids (L* 64 to 78, saturation 25 to 45%) in the 06 9.3 coral hues. 06 4.1's water
           # contrast rule is a creature rule; scenery may sit near the fog's lightness
    "coral_bubble": "#F4A3B5", "coral_knob": "#F7B48E", "coral_brain": "#C3A6EC", "arch_coral": "#F29AAE",
    "ring_coral": "#F5A78F", "buoy": "#F2A0A8", "shell_lights": "#F4B79E", "coral_crust": "#D99AC0", "rim_bank": "#E89D93",
    "grass_gold": "#CDBB6E", "grass_olive": "#A9BF72", "clam_shell": "#A99BE0", "clam_mantle": "#9AA3EC",
    "sign_shell": "#F5AE86", "post_drift": "#B8957A",
}
LIGHTS = {     # pale warm lights (L* 85 or more), each at least 0.06 from every reserved colour (06 4.5)
    "pink": "#FFD9CC", "peach": "#FFE0BF", "lilac": "#EBDDFC", "cream": "#F6E6C2", "gold": "#F2E6A6",
    "mint": "#C8F4E6", "sand": "#F3E0B4",
}
# the rim cell (independent review loops 1 and 3, 06 16.1 lines 5, 8, 9): the 06 9.3 coral hues (#FF7F9F pink,
# #FFA35C orange, #B48CFF violet) taken pastel, as three flat blocks: a soft violet toe band (L* 33), a mid body
# with one broad gradient up the bank (rose at its foot, peach under the cap: L* 70 to 74) and a pale peach cap
# (L* 88). The sand (#F6E3B4) is 91, so the body sits 17 to 21 L* under it, and the toe band meets it.
RIM_PAINT = {
    "dark": "#54427F",                     # soft violet, L* 33
    "mid": ("#E5979A", "#ECA596"),         # (foot, top)
    "light": "#FDD5C7",
}
RIM_BLOCKS = {"dark": "#54427F", "mid": "#E89D93", "light": "#FDD5C7"}   # each block's middle, for validate (L* 33, 72, 88)
SHARE = {"dark": 0.11, "light": 0.26}      # 06 4.1: dark 10-15%, light 20-30% (review loop 3: darks toward the low end)


def _hex(h):
    import numpy as np
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def _grid(w, h):
    import numpy as np
    x = (np.arange(w) + 0.5) / w
    y = (np.arange(h) + 0.5) / h
    return np.meshgrid(x, y)


def _wrap(d):
    import numpy as np
    return d - np.round(d)


def _blur(a, r, wrap=True):
    import numpy as np
    out = np.asarray(a, dtype=float).copy()
    for axis in (0, 1):
        if wrap:
            acc = sum(np.roll(out, k, axis=axis) for k in range(-r, r + 1))
        else:
            pad = [(0, 0), (0, 0)]
            pad[axis] = (r, r)
            p = np.pad(out, pad, mode="edge")
            acc = sum(np.take(p, range(k, k + out.shape[axis]), axis=axis) for k in range(2 * r + 1))
        out = acc / (2 * r + 1)
    return out


def _blocks(name, light, grad, lscore, dscore, wrap=True):
    """Three value blocks (06 4.1, 5.2) from two painted score fields: the darkest-scoring 12.5% of the cell
    becomes the dark block (dark_of: the mid taken toward blue-violet), the best-lit 25% of the rest the light block, the remainder the mid block
    with its broad gradient (at most +-12 L*: warm toward the light, cooler toward the dark). The scores are
    softened first so no block edge is harder than a brush mark."""
    import numpy as np
    import tilegen
    ds = _blur(dscore, 3, wrap)
    ls = _blur(lscore, 3, wrap)
    m = _hex(MIDS[name])
    up = np.minimum(1.0, m * 1.07 + 0.02)
    dn = tilegen.mix(m * 0.87, _hex("#5A4FA0"), 0.12)
    g = _blur(np.clip(grad, -1.0, 1.0), 4, wrap)

    def compose(qd, ql):
        td = np.quantile(ds, 1.0 - qd)
        wd = 0.22 * (ds.std() + 1e-9)
        dark = _blur(_blur(smooth(td - wd, td + wd, ds), 3, wrap), 3, wrap)      # brush-soft block edges
        rest = ls[dark < 0.5]
        tl = np.quantile(rest, 1.0 - min(0.95, ql / max(1e-3, 1.0 - qd))) if rest.size else 1e9
        wl = 0.22 * (ls.std() + 1e-9)
        lightm = _blur(_blur(smooth(tl - wl, tl + wl, ls), 3, wrap), 3, wrap) * (1.0 - dark)
        col = tilegen.mix(np.broadcast_to(m, g.shape + (3,)), np.broadcast_to(up, g.shape + (3,)), np.clip(g, 0, 1))
        col = tilegen.mix(col, np.broadcast_to(dn, g.shape + (3,)), np.clip(-g, 0, 1))
        col = tilegen.mix(col, np.broadcast_to(_hex(light), g.shape + (3,)), lightm)
        col = tilegen.mix(col, np.broadcast_to(dark_of(MIDS[name]), g.shape + (3,)), dark)
        return col
    qd, ql = SHARE["dark"], SHARE["light"]
    for _ in range(20):                    # the soft edges move a little of each block into the mid: correct for it
        col = compose(qd, ql)
        L = tilegen.lstar(col)
        qd += 0.6 * (SHARE["dark"] - float((L <= 35).mean()))
        ql += 0.6 * (SHARE["light"] - float((L >= 85).mean()))
        qd, ql = min(max(qd, 0.02), 0.4), min(max(ql, 0.05), 0.6)
    return compose(qd, ql)


def dark_of(mid):
    """The dark block of a cell: its own mid colour taken down and toward blue-violet (06 4.1: shadows toward
    250 degrees, never black) until L* is just under 35, the lightest a dark block may be, so a crease reads as the coral's shadow, not an outline."""
    import numpy as np
    import tilegen
    c = tilegen.mix(_hex(mid) * 0.45, _hex("#5A4FA0"), 0.4)
    while float(tilegen.lstar(c)) > 33.8:
        c = c * 0.95
    return c


def _voronoi(x, y, count, rng, aspect=1.0):
    """Wrap-around Voronoi on a cell (aspect = width / height of the cell in pixels): F1, F2, offsets."""
    import numpy as np
    import tilegen
    pts = tilegen.relaxed_points(rng, count, iters=3)
    f1 = np.full(x.shape, 9.0)
    f2 = np.full(x.shape, 9.0)
    ox = np.zeros(x.shape)
    oy = np.zeros(x.shape)
    for px, py in pts:
        dx = _wrap(x - px)
        dy = _wrap(y - py) / aspect
        d = np.hypot(dx, dy)
        nearer = d < f1
        f2 = np.where(nearer, f1, np.minimum(f2, d))
        f1 = np.where(nearer, d, f1)
        ox = np.where(nearer, dx, ox)
        oy = np.where(nearer, dy, oy)
    return f1, f2, ox, oy


def _lumps(w, h, name, light, rng, count, holes=0.0):
    """Rounded masses packed together (bubble coral, coral rock, ring knobs): each a dome lit from the tiles'
    painted light (tilegen.LIGHT_DIR); dark in the shaded crescent under each mass and the crease below it, and
    in a polyp hole at its centre if `holes`."""
    import numpy as np
    import tilegen
    x, y = _grid(w, h)
    f1, f2, ox, oy = _voronoi(x, y, count, rng, aspect=w / h)
    size = 0.5 * (f1 + f2) + 1e-6
    lit = -(ox * tilegen.LIGHT_DIR[0] + oy * tilegen.LIGHT_DIR[1]) / size
    edge = (f2 - f1) / size
    dscore = -lit + 1.6 * (1.0 - smooth(0.0, 0.35, edge))
    if holes:
        dscore = np.maximum(dscore, 2.5 * (1.0 - smooth(0.0, holes, f1)))
    lscore = lit + 0.6 * smooth(0.1, 0.5, edge)
    grad = 0.9 * np.tanh(1.4 * lit)
    return _blocks(name, light, grad, lscore, dscore)


def _brain(w, h, name, rng):
    """Brain coral: wide meandering ridges (light along their lit crest) and grooves (dark), 2 to 3 per cell."""
    import numpy as np
    import tilegen
    x, y = _grid(w, h)
    wa = tilegen.waves(rng, x, y, 1, 2, 6)
    wb = tilegen.waves(rng, x, y, 1, 2, 6)
    ph = 2 * math.pi * (2.0 * x + 1.0 * y + 0.5 * wa) + 1.8 * np.sin(2 * math.pi * (y + 0.35 * wb))
    s = np.sin(ph)
    return _blocks(name, LIGHTS["lilac"], 0.8 * s, s + 0.5 * np.cos(ph), -s)


def _blades(w, h, name, light):
    """A sea-grass blade strip (root at the bottom): dark root and edges, a pale tip and a lit midrib."""
    import numpy as np
    x, y = _grid(w, h)
    t = 1.0 - y
    across = np.abs(x - 0.5) * 2
    dscore = 2.0 * smooth(0.3, 0.0, t) + 0.9 * smooth(0.6, 1.0, across)
    lscore = 1.6 * smooth(0.45, 1.0, t) + 0.8 * (1.0 - smooth(0.0, 0.35, across)) - 0.6 * across
    return _blocks(name, light, 1.4 * (t - 0.5), lscore, dscore, wrap=False)


def _buoy(w, h):
    """Wraps round the float (x) from the cap (top) to the weight (bottom): a pale lantern band under the cap
    (the glow itself is the cap mesh or the emissive mask, 06 5.1), coral body with a pale stripe, a dark seam
    under the lantern, a dark rope band and weight."""
    import numpy as np
    x, y = _grid(w, h)

    def band(a, b):
        return smooth(a - 0.02, a + 0.02, y) * smooth(b + 0.02, b - 0.02, y)
    dscore = 2.0 * band(0.0, 0.07) + 2.0 * band(0.30, 0.37) + 2.0 * band(0.86, 1.0) - 0.4 * np.cos(2 * math.pi * (x - 0.68))
    lscore = 2.0 * band(0.08, 0.29) + 1.4 * band(0.52, 0.6) + 0.5 * np.cos(2 * math.pi * (x - 0.18))
    return _blocks("buoy", LIGHTS["cream"], 0.7 * np.cos(2 * math.pi * (x - 0.18)), lscore, dscore, wrap=False)


def _cones(w, h, name):
    """A row of four small cone shells (Little Arch's shell lights): spiral bands, lit left flank, dark gaps."""
    import numpy as np
    x, y = _grid(w, h)
    n = 4
    cx = (np.floor(x * n) + 0.5) / n
    dx = (x - cx) * n * 2
    prof = np.maximum(1.0 - y * 0.8, 0.05)
    outside = smooth(0.85, 1.05, np.abs(dx) / prof)
    spiral = np.sin(2 * math.pi * (3 * y + 0.6 * dx))
    dscore = 2.0 * outside + 0.8 * smooth(0.4, 1.0, spiral) + 0.5 * dx
    lscore = -dx - 0.8 * outside + 0.4 * (1 - y)
    return _blocks(name, LIGHTS["peach"], -0.7 * dx, lscore, dscore)


def _ribs(w, h, name, light, ribs=6, picture=False):
    """A ribbed shell from its hinge (bottom middle): broad ribs fanning out, a lit lip at the rim. With
    `picture` it carries the Shell Sign's painted picture (07 6.2: a picture, no words): an arch with an arrow
    pointing into it, strokes 12 px wide."""
    import numpy as np
    x, y = _grid(w, h)
    dx, dy = x - 0.5, 1.04 - y
    ang = np.arctan2(dx, dy)
    rad = np.hypot(dx, dy)
    rib = np.cos(ang * ribs * 2)
    dscore = -rib * smooth(0.1, 0.35, rad) + 1.2 * smooth(0.25, 0.0, rad)
    lscore = 1.2 * smooth(0.6, 0.95, rad) + 0.6 * rib
    if picture:
        ax, ay = x - 0.6, y - 0.47
        r = np.hypot(ax, np.minimum(ay, 0.0))
        arch = ((np.abs(r - 0.17) < 0.05) & (ay < 0.17)).astype(float)
        shaft = ((np.abs(y - 0.55) < 0.045) & (x > 0.12) & (x < 0.36)).astype(float)
        head = ((x >= 0.33) & (x < 0.47) & (np.abs(y - 0.55) < (0.47 - x) * 0.8)).astype(float)
        pic = np.clip(arch + shaft + head, 0.0, 1.0)
        dscore = 0.3 * dscore + 3.0 * pic
        lscore = lscore - 2.0 * pic + 1.0 * smooth(0.32, 0.12, np.hypot(x - 0.45, y - 0.52))
    return _blocks(name, light, 0.4 * rib + 0.6 * (rad - 0.55), lscore, dscore, wrap=False)


def _mottle(w, h, name, rng):
    """A clam's mantle: broad wavy lip bands (dark) and soft pale spots (light) on violet-blue."""
    import numpy as np
    import tilegen
    x, y = _grid(w, h)
    wv = tilegen.waves(rng, x, y, 1, 2, 6)
    lips = np.cos(2 * math.pi * (2.0 * y + 0.06 * np.sin(2 * math.pi * 3 * x) + 0.1 * wv))
    spots = np.zeros_like(x)
    for px, py in tilegen.relaxed_points(rng, 9, iters=3):
        d = np.hypot(_wrap(x - px), _wrap(y - py)) / 0.09
        spots = np.maximum(spots, 1.0 - smooth(0.6, 1.0, d))
    return _blocks(name, LIGHTS["mint"], 0.5 * wv, 2.0 * spots - 0.5 * lips, lips - 1.5 * spots)


def _grain(w, h, name, rng):
    """Driftwood: broad grain along the post (y), a knot, a sun-bleached lit flank, dark cracks."""
    import numpy as np
    import tilegen
    x, y = _grid(w, h)
    wv = tilegen.waves(rng, x, y, 1, 2, 6)
    g = np.sin(2 * math.pi * (3 * x + 0.3 * wv + 0.15 * np.sin(2 * math.pi * y)))
    knot = np.hypot(_wrap(x - 0.62) * 1.6, _wrap(y - 0.4))
    dscore = g + 2.5 * smooth(0.12, 0.04, knot)
    lscore = -g + 1.6 * np.cos(2 * math.pi * (x - 0.1))
    return _blocks(name, LIGHTS["cream"], 0.6 * np.cos(2 * math.pi * (x - 0.1)), lscore, dscore)


def paint_rim_cell(w, h):
    """The rim's gradient map (64 x 256): bands up the cell (RIM_BANDS): the buried band (the mid's foot colour),
    the dark block (one flat soft violet), the mid block (one broad gradient, rose at its foot to peach at its top)
    and the light block (one flat pale peach). Flat across the cell; no marks and no blur across the band edges, so
    a block ends exactly on the mesh's edge loop."""
    import numpy as np
    import tilegen
    B = RIM_BANDS
    b = (h - 1 - np.arange(h) + 0.5)[:, None] * np.ones((1, w))          # pixels from the bottom
    g = np.clip((b - B["dark"] - 0.5) / (B["mid"] - B["dark"] - 1.0), 0.0, 1.0)
    mid = tilegen.mix(np.broadcast_to(_hex(RIM_PAINT["mid"][0]), (h, w, 3)), np.broadcast_to(_hex(RIM_PAINT["mid"][1]), (h, w, 3)), g)
    dark = np.broadcast_to(_hex(RIM_PAINT["dark"]), (h, w, 3))
    light = np.broadcast_to(_hex(RIM_PAINT["light"]), (h, w, 3))
    buried = np.broadcast_to(_hex(RIM_PAINT["mid"][0]), (h, w, 3))
    return np.where((b < B["buried"])[..., None], buried, np.where((b < B["dark"])[..., None], dark,
                                                                   np.where((b < B["mid"])[..., None], mid, light)))


def paint_atlas(seed=71):
    """T_EnvNursery_Alb, RGB floats (512, 512, 3), rows from the top. Opaque: every cell fills its rectangle,
    so the 8 px bake margin (06 5.5) is the cell's own colour."""
    import numpy as np
    rng = np.random.default_rng(seed)
    img = np.zeros((N, N, 3))
    painters = {
        "coral_bubble": lambda w, h: _lumps(w, h, "coral_bubble", LIGHTS["pink"], rng, 6),
        "coral_knob": lambda w, h: _lumps(w, h, "coral_knob", LIGHTS["peach"], rng, 5, holes=0.07),
        "coral_brain": lambda w, h: _brain(w, h, "coral_brain", rng),
        "buoy": lambda w, h: _buoy(w, h),
        "arch_coral": lambda w, h: _lumps(w, h, "arch_coral", LIGHTS["pink"], rng, 12, holes=0.035),
        "rim_bank": lambda w, h: paint_rim_cell(w, h),
        "grass_gold": lambda w, h: _blades(w, h, "grass_gold", LIGHTS["gold"]),
        "grass_olive": lambda w, h: _blades(w, h, "grass_olive", LIGHTS["gold"]),
        "ring_coral": lambda w, h: _lumps(w, h, "ring_coral", LIGHTS["peach"], rng, 4),
        "shell_lights": lambda w, h: _cones(w, h, "shell_lights"),
        "coral_crust": lambda w, h: _lumps(w, h, "coral_crust", LIGHTS["lilac"], rng, 6, holes=0.08),
        "clam_shell": lambda w, h: _ribs(w, h, "clam_shell", LIGHTS["lilac"], ribs=5),
        "clam_mantle": lambda w, h: _mottle(w, h, "clam_mantle", rng),
        "sign_shell": lambda w, h: _ribs(w, h, "sign_shell", LIGHTS["peach"], ribs=6, picture=True),
        "post_drift": lambda w, h: _grain(w, h, "post_drift", rng),
    }
    for name, (x, y, w, h) in ATLAS_CELLS.items():
        img[y:y + h, x:x + w] = np.clip(painters[name](w, h), 0.0, 1.0)
    return img


def atlas_report(img):
    """Rows (subject, check, ok, detail): the tilegen texture rules (size, neon, reserved colours, fine noise) on
    the whole atlas, and the three-value shares of each cell (06 4.1: dark 10-15% at L* 35 or less, light 20-30%
    at 85 or more, mid 55-65%) and its fine noise."""
    import numpy as np
    import tilegen
    img8 = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
    rows = []
    st = tilegen.stats(img8)
    rows.append((ATLAS, "size", img8.shape[:2] == (N, N), "%d x %d (07 6.2: 512)" % img8.shape[:2][::-1]))
    rows.append((ATLAS, "saturated, not neon", st["neon_px"] == 0, "%d texels over 85%% saturation and 95%% value (06 4.1)" % st["neon_px"]))
    rows.append((ATLAS, "no reserved colour", st["min_dist_to_signal"] >= 0.06,
                 "nearest texel %.3f from a reserved colour (06 4.5; at least 0.06)" % st["min_dist_to_signal"]))
    rows.append((ATLAS, "painted, no fine noise", st["fine_noise_L"] <= 1.5,
                 "%.2f L* finer than a brush mark (06 5.2; tilegen limit 1.5)" % st["fine_noise_L"]))
    c = img8[..., :3].astype(float) / 255.0
    hmax = c.max(-1)
    sat = np.where(hmax > 0, (hmax - c.min(-1)) / np.maximum(hmax, 1e-6), 0)
    hue = _hue(c)
    amber = ((hue >= 26) & (hue <= 46) | (hue >= 68) & (hue <= 108) | (hue >= 334) | (hue <= 14)) & (sat > 0.70) & (hmax > 0.85)
    rows.append((ATLAS, "signal hue bands", int(amber.sum()) == 0,
                 "%d texels in the lime, red or amber bands above 70%% saturation and 85%% value (06 4.5)" % int(amber.sum())))
    cells = {}
    for name, (x, y, w, h) in ATLAS_CELLS.items():
        L = tilegen.lstar(c[y:y + h, x:x + w])
        dark, light = float((L <= 35).mean()), float((L >= 85).mean())
        mid = 1.0 - dark - light
        cells[name] = (dark, mid, light)
        ok = 0.08 <= dark <= 0.17 and 0.18 <= light <= 0.32 and 0.51 <= mid <= 0.69
        Lb = tilegen.lstar(c[y:y + h, x:x + w])
        fine = float(np.abs(Lb - _blur(Lb, tilegen.MIN_MARK_PX // 4, wrap=False)).mean())
        rows.append((name, "painted, no fine noise", fine <= 1.5, "%.2f L* finer than a brush mark (06 5.2; limit 1.5)" % fine))
        rows.append((name, "three values", ok, "dark %.0f%%, mid %.0f%%, light %.0f%% (06 4.1: 10-15 / 55-65 / 20-30; +-2 for soft edges)"
                     % (100 * dark, 100 * mid, 100 * light)))
    return rows, st, cells


def _hue(c):
    import numpy as np
    c = np.asarray(c, dtype=float)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    mx, mn = c.max(-1), c.min(-1)
    d = np.maximum(mx - mn, 1e-9)
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60.0
    return np.where(mx - mn < 1e-6, 0.0, h)


def rim_material(name="MAT_Nursery_Rim"):
    """Preview stand-in for the rim's SurfaceAppearance: T_EnvNursery_Alb (its rim cell) on the mesh UVs, matte."""
    import bpy
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(atlas_path(), check_existing=True)
    tex.extension = 'EXTEND'
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.85          # T_Shared_Rgh (06 5.1)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def sand_material(name="MAT_Nursery_Sand"):
    """Preview stand-in for the floor's SurfaceAppearance: T_Tile_Sand_Alb on the mesh UVs, times the Nursery
    tint (tilegen.tints, 06 5.3), matte."""
    import bpy
    import tilegen
    tint = tilegen.tints(SAND)["nursery"][2]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.join(common.EXPORT_DIR, "textures", SAND + ".png"), check_existing=True)
    tex.extension = 'REPEAT'
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = 'RGBA'
    mul.blend_type = 'MULTIPLY'
    mul.inputs["Factor"].default_value = 1.0
    mul.inputs[7].default_value = (tint[0], tint[1], tint[2], 1.0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 1.0          # T_Shared_RghChalk (06 5.1)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(tex.outputs["Color"], mul.inputs[6])
    nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def atlas_path():
    return os.path.join(common.EXPORT_DIR, "textures", ATLAS + ".png")
