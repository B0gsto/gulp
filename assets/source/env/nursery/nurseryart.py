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

Rim pieces (07 6.2: 1,000 tris each). Low rounded banks of rock that enclose the pool. Each is a
closed slab whose top is a height field over the arc's plan: a wide, shallow wedge from below the sand at the toe
up to a domed crest (39 degrees on average), with a few broad, low rock masses fused onto it by a soft
maximum (rounded creases where they meet, no overhang, no stacked boulders), running 12 studs past each joint
and diving there under its neighbour; decimated to budget. The crest stands 4 to 7 studs above the surface (the Rim's own
top is 12, 03 6.1); the outer face runs down to depth 86, below the Kelp (70), Reef (60) and Ledge (70 to 100)
floors beside the bulge, onto a flat buried base. The toe reaches 32 studs into the pool from the waterline: the
oval of 03 6.2 is the sand floor's outline, the toe line. Each piece is an arc concave toward the pool (-Y, its
front): Rim_01 follows the long sides of the oval (toe radius 140, about the curvature at the ends of its short
axis, 142), Rim_02 its ends (64, against 66). Texture (review loop 4): T_Tile_CoralRock_Alb, the warm lumpy coral rock of the S5-A1
ground set, on the bank's own surface parametrisation (u along the arc, v over the surface from the toe), one
repeat per 160 studs, slid so the visible face falls between the texture's pits, a SurfaceAppearance.Color
tint per copy. The 07 row named T_Tile_Rock_Alb, which read as paving on a wall (S5-A2 loop 1); the Rim's own T_Rim_Alb read as cold dry-stone cobbles in the pastel pool.

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

ROCK = "T_Tile_CoralRock_Alb"  # review loop 4: the warm coral rock, not the Rim's cool faceted T_Rim_Alb (read as
                              # dry-stone cobbles and cold in the pastel pool in loops 1 to 4)
ROCK_TILE = 160.0             # one repeat per 160 studs here (the floors: 32): two or three of its masses show on a
                              # piece's face (3.2 px per stud; review loops 5 and 6: larger)
CREST_MIN = 4.0               # the crest stays above the surface by at least this much along the whole span
FOOT_IN = -34.0               # the pool face reaches this far down (8 below the sand level)
BOTTOM = -86.0                # flat buried base
RIM_TRIS = 1000               # 07 6.2

# 06 10.2 Nursery preset; fog colour 06 4.2
NURSERY = {"sun": "#FFF3C4", "brightness": 2.2, "ambient": "#8FD3D6", "outdoor": "#B8ECEC", "fog": "#4CCFD2",
           "surface": "#9FF0E6", "deep": "#2FAFC0", "view": 450.0}
FOG = {"nursery": "#4CCFD2", "reef": "#1E9FD0", "kelp": "#238A72", "dropoff_upper": "#1B6FBF"}
# SurfaceAppearance.Color per copy of a rim piece (06 5.3: variation by tint; value and hue shift only slightly,
# leaning warm under the Nursery's warm light)
RIM_TINTS = ("#FFFFFF", "#FBF2EA", "#FFF7EF", "#F2EAE4", "#FAEFE6")   # small value and warmth steps between copies


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

RIMS = {
    # radius and span at the waterline (d 0); the toe, 32 studs into the pool, follows the oval: radius 142 on its long
    # sides, 66 at its ends (03 6.2: 220 x 170)
    "M_Env_Nursery_Rim_01": {"seed": 611, "radius": 172.0, "span": 64.0, "target": 940,
                             "title": "gentle arc", "caption": "the oval's long sides: toe radius 140, waterline 172, 64 studs"},
    "M_Env_Nursery_Rim_02": {"seed": 622, "radius": 96.0, "span": 50.0, "target": 940,
                             "title": "tight arc", "caption": "the oval's ends: toe radius 64, waterline 96, 50 studs"},
}
RIM_NAMES = tuple(RIMS)


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


def ease(t):
    """Half linear, half cosine: soft at both ends, steepest at 1.29 times the average slope."""
    import numpy as np
    t = np.clip(t, 0.0, 1.0)
    return 0.5 * t + 0.5 * (0.5 - 0.5 * np.cos(math.pi * t))


def smax(a, b, k):
    """Soft maximum: the larger surface wins, with a rounded crease `k` studs wide where two masses meet."""
    import numpy as np
    hh = np.clip(0.5 + 0.5 * (a - b) / k, 0.0, 1.0)
    return b + (a - b) * hh + k * hh * (1.0 - hh)


TOE, TOP, OUTER = -32.0, 10.0, 56.0      # unbent d: the sand toe, the top of the crest, the outer foot
CREST_Z = 3.0                 # the crest line before its humps (review loop 4: lower and rounder)
END = 12.0                    # a piece runs this far past each joint, diving under its neighbour


def rim_profile(D):
    """The bank across (review loops 2 to 4: a low, wide bank into the sand, not stacked masses or a slab): one
    smooth curve with no kink, flat at the buried toe (z -31, 32 studs into the pool from the waterline), rising
    at 39 degrees on average to a round crest at +3 (the humps lift it to 4 to 7), then falling as smoothly
    down the outer face to the buried base."""
    import numpy as np

    def cos_ease(t):
        t = np.clip(t, 0.0, 1.0)
        return 0.5 - 0.5 * np.cos(math.pi * t)
    pool = -31.0 + (CREST_Z + 31.0) * cos_ease((D - TOE) / (TOP - TOE))
    outer = CREST_Z - (CREST_Z - BOTTOM) * cos_ease((D - TOP) / (OUTER - TOP)) ** 2.2      # a broad, round top
    return np.where(D < TOP, pool, outer)


def rim_masses(seed, L):
    """Rock masses on the bank [(s, d, rs, rd, height)]: broad, low, few (review loop 2), so the bank reads as a few
    rounded rocks fused together, with soft creases between them; they shrink toward the ends."""
    rng = random.Random(seed)
    h = L / 2.0
    out = []

    def row(count, d, rd, hgt, grow, jit=3.0):
        for i in range(count):
            s_ = -h + (i + 0.5) * L / count + rng.uniform(-jit, jit)
            out.append((s_, d + rng.uniform(-2.0, 2.0), L / count * 0.5 + grow * rng.uniform(0.8, 1.2),
                        rd * rng.uniform(0.9, 1.1), hgt * rng.uniform(0.8, 1.15)))
    n = 2 if L < 50 else 3
    row(n, -17.0, 13.0, 2.4, 6.0)          # the slope: broad, low swellings
    row(n + 1, -4.0, 10.0, 2.0, 3.0)       # under the crest, offset from the slope's
    row(n, 9.0, 9.0, 3.0, 5.0)             # the crest humps, 4 to 7 above the surface
    row(2 if L < 50 else 3, 30.0, 14.0, 4.0, 4.0)      # the outer face
    s_ = rng.uniform(-0.3, 0.3) * L                    # one low rock at the toe, sunk in the sand
    out.append((s_, -27.0, rng.uniform(7.0, 9.0), 7.0, 2.4))
    return out


def rim_height(name, S, D):
    """Height of the bank (z, the surface at 0) over unbent (s, d)."""
    import numpy as np
    cfg = RIMS[name]
    L = cfg["span"]
    h = L / 2.0
    rng = random.Random(cfg["seed"] + 7)
    B = rim_profile(D)
    # slow irregularity along the span
    B = B + sum(rng.uniform(0.5, 0.9) * np.sin(2 * math.pi * S / rng.uniform(26, 48) + rng.uniform(0, 6.3))
                * np.sin(2 * math.pi * D / rng.uniform(40, 70) + rng.uniform(0, 6.3)) for _ in range(3))
    f = B
    for sc, dc, rs, rd, hgt in rim_masses(cfg["seed"], L):
        k = smooth(h + END, h - 6.0, abs(sc))                       # masses shrink toward the ends
        r2 = ((S - sc) / rs) ** 2 + ((D - dc) / rd) ** 2
        cap = hgt * k * (1.6 * np.sqrt(np.clip(1.0 - r2, 0.0, 1.0)) - 0.6)
        f = smax(f, B + cap, 1.4)
    # review loop 5: past each joint the piece runs on END studs and dives there, a rounded nose sinking 40 studs
    # (below the sand on the pool side) under its neighbour, which is at full height over the same stretch. The
    # crest therefore runs on unbroken across a joint, and a lone piece ends in rounded noses, not cut walls.
    x = np.clip((np.abs(S) - h) / END, 0.0, 1.0)
    f = f - 40.0 * (1.0 - np.cos(0.5 * math.pi * x)) ** 1.5
    return np.maximum(f, BOTTOM + 1.0)


def build_rim(name, target=None):
    """One rim piece (review loops 2 to 4): a closed slab whose top is the bank's height field over the unbent (s, d)
    plan, s from -(L/2 + END) to L/2 + END, d from the buried toe to the outer foot, bent onto the piece's arc; its
    walls and base are buried or hidden by the neighbours; decimated to budget."""
    import numpy as np
    import rimart as ra
    cfg = RIMS[name]
    Rf, L = cfg["radius"], cfg["span"]
    h = L / 2.0 + END
    target = target or cfg["target"]
    ns, nd = int(2 * h / 0.8), int((OUTER - TOE + 2.0) / 0.8)
    ss = np.linspace(-h, h, ns + 1)
    ds = np.linspace(TOE - 2.0, OUTER, nd + 1)
    S, D = np.meshgrid(ss, ds, indexing="ij")
    Z = rim_height(name, S, D)
    verts, faces = [], []

    def vid(i, j, top):
        return (i * (nd + 1) + j) * 2 + (0 if top else 1)
    for i in range(ns + 1):
        for j in range(nd + 1):
            verts.append(bend((ss[i], ds[j], float(Z[i, j])), Rf))
            verts.append(bend((ss[i], ds[j], BOTTOM), Rf))
    for i in range(ns):
        for j in range(nd):
            faces.append((vid(i, j, True), vid(i + 1, j, True), vid(i + 1, j + 1, True), vid(i, j + 1, True)))
            faces.append((vid(i, j, False), vid(i, j + 1, False), vid(i + 1, j + 1, False), vid(i + 1, j, False)))
    for i in range(ns):                               # the toe and outer walls
        for j in (0, nd):
            faces.append((vid(i, j, True), vid(i, j, False), vid(i + 1, j, False), vid(i + 1, j, True)))
    for j in range(nd):                               # the end walls
        for i in (0, ns):
            faces.append((vid(i, j, True), vid(i, j + 1, True), vid(i, j + 1, False), vid(i, j, False)))
    ob = ra.mesh_object(name, verts, faces)
    ra.tidy(ob, triangulate=False)
    for _ in range(4):
        ra.apply_mod(ob, 'DECIMATE', decimate_type='COLLAPSE', ratio=min(1.0, target / float(max(1, ra.tri_count(ob)))),
                     use_collapse_triangulate=True)
        if ra.tri_count(ob) <= RIM_TRIS - 10:
            break
        target -= 30
    ra.tidy(ob)
    drop_loose(ob)
    flatten_base(ob)
    ob.data.materials.clear()
    for p in ob.data.polygons:
        p.material_index = 0
    rim_uvs(ob, Rf, name)
    ra.finish(ob, front_fn=lambda co: unbend(co, Rf)[1] < 4.0 and co.z > FOOT_IN - 2.0)
    return ob


def drop_loose(ob):
    """The decimation can leave a vertex with no face: delete it (06 6.5: no loose geometry)."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def flatten_base(ob):
    """The decimation may lift a base vertex a hair off the cut plane: put the base back on it."""
    for v in ob.data.vertices:
        if v.co.z < BOTTOM + 0.05:
            v.co.z = BOTTOM
    ob.data.update()


def rim_uvs(ob, Rf, name):
    """Review loop 3: the bank is mapped by its own surface, not by a box projection (whose switch between axes
    left a seam along every few triangles): u runs along the arc at each point's radius, v is the distance over
    the surface from the toe, up the pool face and over the crest, so the rock texture lies on the bank in one piece with
    its lit tops uphill on the pool side. Walls and base (buried or under a neighbour) are projected flat. The scale
    is then set so the median face carries one repeat per ROCK_TILE studs."""
    import numpy as np
    me = ob.data
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    uvl = me.uv_layers.new(name=common.UV_NAME).data
    L = RIMS[name]["span"]
    h = L / 2.0 + END
    s_grid = np.linspace(-h - 1.0, h + 1.0, int(2 * h) + 3)
    d_grid = np.linspace(TOE - 2.0, OUTER, int((OUTER - TOE + 2.0) / 0.25) + 1)
    Sg, Dg = np.meshgrid(s_grid, d_grid, indexing="ij")
    Zg = rim_height(name, Sg, Dg)
    seg = np.sqrt(np.diff(Dg, axis=1) ** 2 + np.diff(Zg, axis=1) ** 2)
    Vg = np.concatenate([np.zeros((len(s_grid), 1)), np.cumsum(seg, axis=1)], axis=1)

    def path(s_, d):
        k = min(max(np.searchsorted(s_grid, s_) - 1, 0), len(s_grid) - 2)
        t = (s_ - s_grid[k]) / (s_grid[k + 1] - s_grid[k])
        return (1 - t) * np.interp(d, d_grid, Vg[k]) + t * np.interp(d, d_grid, Vg[k + 1])
    vs = me.vertices
    for poly in me.polygons:
        pts = [unbend(vs[me.loops[li].vertex_index].co, Rf) for li in poly.loop_indices]
        top = all(p[2] > BOTTOM + 0.5 for p in pts) and all(
            abs(p[2] - float(rim_height(name, np.array(p[0]), np.array(p[1])))) < 0.6 for p in pts)
        for li, (s_, d, z) in zip(poly.loop_indices, pts):
            if top:
                u, w = s_ * (Rf + d) / Rf, path(s_, d)
            elif abs(poly.normal.z) > 0.7:
                u, w = s_, d
            else:
                u, w = (s_ if abs(abs(s_) - h) > 0.5 else d), z
            uvl[li].uv = (u / ROCK_TILE, w / ROCK_TILE)
    ratios = []
    for poly in me.polygons:
        if poly.area < 1.0:
            continue
        us = [uvl[li].uv.copy() for li in poly.loop_indices]
        a = sum(abs((us[k].x - us[0].x) * (us[k + 1].y - us[0].y) - (us[k + 1].x - us[0].x) * (us[k].y - us[0].y)) / 2.0
                for k in range(1, len(us) - 1))
        if a > 1e-9:
            ratios.append((poly.area / a) ** 0.5)
    ratios.sort()
    k = ratios[len(ratios) // 2] / ROCK_TILE if ratios else 1.0
    for dd in uvl:
        dd.uv = (dd.uv.x * k, dd.uv.y * k)
    # review loop 6: slide the texture so the visible pool face and crest fall between its dark pits
    seen = [uvl[li].uv for poly in me.polygons for li in poly.loop_indices
            if poly.normal.z > -0.2 and unbend(vs[me.loops[li].vertex_index].co, Rf)[1] < TOP + 4.0
            and vs[me.loops[li].vertex_index].co.z > -(SAND_DEPTH + 1.0)]
    if seen:
        u0, u1 = min(p.x for p in seen), max(p.x for p in seen)
        v0, v1 = min(p.y for p in seen), max(p.y for p in seen)
        ou, ov, share = pit_free_offset(u0, u1, v0, v1)
        for dd in uvl:
            dd.uv = (dd.uv.x + ou, dd.uv.y + ov)
        ob["pit_share"] = share


_PITS = {}


def pit_free_offset(u0, u1, v0, v1, n=64):
    """The UV offset (in whole 1/n steps) that puts the fewest of the rock texture's pits (its darkest 4%) inside the
    rectangle [u0, u1] x [v0, v1] of the visible faces; returns (du, dv, share of that rectangle that is pit)."""
    import numpy as np
    import tilegen
    if ROCK not in _PITS:
        img = tilegen.PAINTERS[ROCK]()
        L = tilegen.lstar(np.clip(img, 0, 1))
        _PITS[ROCK] = (L < np.percentile(L, 4.0)).astype(float)[::-1]       # rows from v = 0 (Blender UVs)
    dark = _PITS[ROCK]
    size = dark.shape[0]
    big = np.tile(dark, (3, 3))
    ii = np.pad(big.cumsum(0).cumsum(1), ((1, 0), (1, 0)))
    w = max(1, min(2 * size, int(round((u1 - u0) * size))))
    hgt = max(1, min(2 * size, int(round((v1 - v0) * size))))
    best = None
    for a in range(n):
        for b in range(n):
            du, dv = a / float(n), b / float(n)
            x0 = int(round(((u0 + du) % 1.0) * size))
            y0 = int(round(((v0 + dv) % 1.0) * size))
            tot = ii[y0 + hgt, x0 + w] - ii[y0, x0 + w] - ii[y0 + hgt, x0] + ii[y0, x0]
            if best is None or tot < best[0]:
                best = (tot, du, dv)
    return best[1], best[2], float(best[0]) / (w * hgt)


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
    joints), the pool face reaches below the sand everywhere (no gap at the foot), and the face and crest run out
    to the joints, where neighbours overlap."""
    def check(spec, report):
        for ob in objs:
            cfg = RIMS[ob.name]
            Rf, L = cfg["radius"], cfg["span"]
            h = L / 2.0
            pts = surface_samples(ob, offs[ob.name], Rf)
            bins = 2 * int(L / 4.0)
            crest, foot, mids = [], [], []
            for k in range(bins):
                s0 = -h - END + (L + 2 * END) * k / bins
                s1 = s0 + (L + 2 * END) / bins
                col = [p for p in pts if s0 <= p[0] < s1]
                top = max((p[2] for p in col), default=-999.0)
                crest.append(top)
                if abs(s0) <= h and abs(s1) <= h:
                    mids.append(top)
                if abs(s0) <= h and abs(s1) <= h:
                    foot.append(min((p[2] for p in col if p[1] < 6.0), default=999.0))
            report.add(ob.name, "crest above the surface", min(mids) >= CREST_MIN,
                       "crest %.1f to %.1f studs above the surface between the overlaps (at least %.0f; the Rim's own top is 12); "
                       "past each joint the piece dives under its neighbour" % (min(mids), max(mids), CREST_MIN))
            report.add(ob.name, "pool face buried", max(foot) <= -(SAND_DEPTH + 3.0),
                       "the pool face reaches depth %.1f or lower all along (sand level %.0f, relief to 30)" % (-max(foot), SAND_DEPTH))
            ext = [p[0] for p in pts if p[2] > -26.0 and p[1] < 20.0]
            report.add(ob.name, "face reaches the joints", min(ext) <= -h - 2.0 and max(ext) >= h + 2.0,
                       "pool face and crest run from s %.1f to %.1f of +-%.1f (neighbours overlap there)" % (min(ext), max(ext), h))
    return check


# ================================================================ T_EnvNursery_Alb

ATLAS = "T_EnvNursery_Alb"
N = 512
WARM = "#FFF6D9"
ATLAS_CELLS = {               # (x, y, w, h) in pixels, top-left origin; meshes keep UVs 8 px inside a cell
    "coral_bubble": (0, 0, 128, 128), "coral_knob": (128, 0, 128, 128), "coral_brain": (256, 0, 128, 128),
    "buoy": (384, 0, 128, 128),
    "arch_coral": (0, 128, 256, 256),
    "grass_gold": (256, 128, 64, 256), "grass_olive": (320, 128, 64, 256),
    "ring_coral": (384, 128, 128, 64), "shell_lights": (384, 192, 128, 64),
    "coral_crust": (384, 256, 128, 128),
    "clam_shell": (0, 384, 128, 128), "clam_mantle": (128, 384, 128, 128),
    "sign_shell": (256, 384, 128, 128), "post_drift": (384, 384, 128, 128),
}
CELL_USE = {
    "coral_bubble": "M_Env_Nursery_Coral_01 (pink bubble coral)", "coral_knob": "M_Env_Nursery_Coral_02 (peach knob coral)",
    "coral_brain": "M_Env_Nursery_Coral_03 (lilac brain coral)", "buoy": "M_Env_Nursery_GlowBuoy (float; glow by cap)",
    "arch_coral": "M_Env_Nursery_LM_LittleArch (pink coral, wraps both ways)", "grass_gold": "M_Env_Nursery_GrassTuft_01",
    "grass_olive": "M_Env_Nursery_GrassTuft_02", "ring_coral": "M_Env_Nursery_LM_ThreeRings (wraps across)",
    "shell_lights": "Little Arch shell lights", "coral_crust": "Little Arch tunnel and coral feet (shaded crust)",
    "clam_shell": "M_Env_Nursery_LM_SleepyClam shell", "clam_mantle": "Sleepy Clam mantle",
    "sign_shell": "M_Prop_Nursery_ShellSign (arch and arrow picture)", "post_drift": "Shell Sign post",
}
MIDS = {   # review loop 1: pastel mids (L* 64 to 78, saturation 25 to 45%) in the 06 9.3 coral hues. 06 4.1's water
           # contrast rule is a creature rule; scenery may sit near the fog's lightness
    "coral_bubble": "#F4A3B5", "coral_knob": "#F7B48E", "coral_brain": "#C3A6EC", "arch_coral": "#F29AAE",
    "ring_coral": "#F5A78F", "buoy": "#F2A0A8", "shell_lights": "#F4B79E", "coral_crust": "#D99AC0",
    "grass_gold": "#CDBB6E", "grass_olive": "#A9BF72", "clam_shell": "#A99BE0", "clam_mantle": "#9AA3EC",
    "sign_shell": "#F5AE86", "post_drift": "#B8957A",
}
LIGHTS = {     # pale warm lights (L* 85 or more), each at least 0.06 from every reserved colour (06 4.5)
    "pink": "#FFD9CC", "peach": "#FFE0BF", "lilac": "#EBDDFC", "cream": "#F6E6C2", "gold": "#F2E6A6",
    "mint": "#C8F4E6", "sand": "#F3E0B4",
}
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


def rock_material(name="MAT_Nursery_Rim"):
    """Preview stand-in for the rim's SurfaceAppearance: T_Tile_CoralRock_Alb on the mesh UVs, no tint, matte."""
    import bpy
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.join(common.EXPORT_DIR, "textures", ROCK + ".png"), check_existing=True)
    tex.extension = 'REPEAT'
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
