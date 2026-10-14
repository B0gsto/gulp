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
    # sides, 66 at its ends (03 6.2: 220 x 170). Independent review loop 1 (06 16.1 lines 1 and 18): each piece has its
    # own uneven crest, a tall rounded dome and a low saddle at different places, and rock masses of its own on both
    # faces; within BAND of each joint both pieces take the one shared joint profile, so a ring is one bank.
    #   crest: (s as a share of the span, rise over the joint crest, half-width in studs)
    #   masses: (s share, d, half-length along s, half-width across, height)
    "M_Env_Nursery_Rim_01": {"seed": 611, "radius": 172.0, "span": 64.0, "target": 940,
                             "crest": [(-0.15, 4.4, 11.0), (0.22, -2.7, 7.5)],
                             "crest_shift": [(-0.12, -2.5, 12.0), (0.25, 2.0, 9.0)],
                             "masses": [(0.08, -13.0, 12.0, 8.0, 3.0), (-0.32, -21.0, 8.0, 6.0, 2.0),
                                        (-0.05, 33.0, 14.0, 11.0, 4.0), (0.28, 29.0, 9.0, 9.0, 3.0)],
                             "title": "gentle arc", "caption": "the oval's long sides: toe radius 140, waterline 172, 64 studs"},
    "M_Env_Nursery_Rim_02": {"seed": 622, "radius": 96.0, "span": 50.0, "target": 940,
                             "crest": [(-0.17, -2.9, 6.5), (0.13, 4.5, 8.0)],
                             "crest_shift": [(0.12, -2.0, 9.0)],
                             "masses": [(-0.14, -17.0, 9.0, 7.0, 2.6), (0.30, -9.0, 6.0, 5.0, 1.8),
                                        (0.06, 31.0, 12.0, 12.0, 3.6)],
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


def smax(a, b, k):
    """Soft maximum: the larger surface wins, with a rounded crease `k` studs wide where two masses meet."""
    import numpy as np
    hh = np.clip(0.5 + 0.5 * (a - b) / k, 0.0, 1.0)
    return b + (a - b) * hh + k * hh * (1.0 - hh)


TOE, OUTER = -32.0, 60.0      # unbent d: the sand toe, the outer foot
UNDER = -46.0                 # under the sand the bank rounds down from the toe to the base here (no cut wall)
TOE_Z = -31.0                 # the toe, buried 5 below the sand
JOINT_CREST = 7.0             # the shared joint profile: its crest height above the surface ...
JOINT_AT = 14.0               # ... and its unbent d (the waterline then falls at d 0)
POOL_K = 2.3                  # the pool face: 1 - (1 - t)^k (1 + k t), soft at the foot, a round dome at the top
OUTER_Q = 1.7                 # the outer face: crest - drop * u^q, a round shoulder over a steep buried foot
BAND = 5.0                    # within BAND of a joint both neighbours are exactly the joint profile
RAMP = 11.0                   # a piece's own shape then grows in over RAMP studs
END = 12.0                    # a piece runs this far past each joint, diving under its neighbour
SAND_Z = -SAND_DEPTH          # the pool face shows above the sand ...
OUTER_FLOOR_Z = -66.0         # ... and the outer face above the Reef, Kelp and Ledge floors beside the bulge (60 to 70)
MASS_K = 1.6                  # the rounded crease where a mass meets the bank
RIM_TOP = 12.0                # 03 6.1: the Rim's own top above the surface
NOTCH_MAX = 0.75              # a saddle at a joint shallower than this is no notch
CREST_VARY = 0.25             # independent review loop 1: the crest varies by at least 25% of its peak along a piece


def rim_weight(name, S):
    """1 where the piece shows its own shape, 0 within BAND of a joint (and past it), smooth in between."""
    h = RIMS[name]["span"] / 2.0
    return smooth(h - BAND, h - BAND - RAMP, abs_(S))


def abs_(x):
    import numpy as np
    return np.abs(np.asarray(x, dtype=float))


def _gauss(S, items, L):
    import numpy as np
    out = np.zeros_like(np.asarray(S, dtype=float))
    for frac, amp, wid in items:
        out = out + amp * np.exp(-((S - frac * L) / wid) ** 2)
    return out


def rim_crest(name, S):
    """(crest height above the surface, crest d) along the piece: the joint profile's, plus the piece's own domes
    and saddles, faded to nothing within BAND of each joint."""
    cfg = RIMS[name]
    L = cfg["span"]
    w = rim_weight(name, S)
    return JOINT_CREST + w * _gauss(S, cfg["crest"], L), JOINT_AT + w * _gauss(S, cfg["crest_shift"], L)


def rim_profile(D, C, dc):
    """The bank across, no kink and no cut wall: from the base under the sand, round up to the flat buried toe, up the
    pool face (steepest 52 degrees, a third of the way up) into a round dome at (dc, C), then a round shoulder over the
    outer face down to the buried base."""
    import numpy as np
    t = np.clip((D - TOE) / (dc - TOE), 0.0, 1.0)
    under = np.clip((TOE - D) / (TOE - UNDER), 0.0, 1.0)
    pool = TOE_Z + (C - TOE_Z) * (1.0 - (1.0 - t) ** POOL_K * (1.0 + POOL_K * t)) - (TOE_Z - BOTTOM) * under ** 1.7
    u = np.clip((D - dc) / (OUTER - dc), 0.0, 1.0)
    outer = C - (C - BOTTOM) * u ** OUTER_Q
    return np.where(D < dc, pool, outer)


def rim_height(name, S, D):
    """Height of the bank (z, the surface at 0) over unbent (s, d)."""
    import numpy as np
    cfg = RIMS[name]
    L = cfg["span"]
    h = L / 2.0
    C, dc = rim_crest(name, S)
    B = rim_profile(D, C, dc)
    w = rim_weight(name, S)
    rng = random.Random(cfg["seed"] + 7)
    # slow irregularity along the span (piece-own, so it fades at the joints too)
    B = B + w * sum(rng.uniform(0.4, 0.8) * np.sin(2 * math.pi * S / rng.uniform(22, 40) + rng.uniform(0, 6.3))
                    * np.sin(2 * math.pi * D / rng.uniform(30, 60) + rng.uniform(0, 6.3)) for _ in range(3))
    f = B
    for frac, dm, rs, rd, hgt in cfg["masses"]:
        r2 = ((S - frac * L) / rs) ** 2 + ((D - dm) / rd) ** 2
        # a dome of `hgt` (plus the crease) at full weight; with no weight it sits more than the crease below the
        # bank, so the soft maximum leaves the joint profile exactly as it is
        cap = w * (hgt + 1.01 * MASS_K) * 1.6 * np.sqrt(np.clip(1.0 - r2, 0.0, 1.0)) - 0.6 * hgt * w - 1.01 * MASS_K
        f = smax(f, B + cap, MASS_K)
    # past each joint the piece runs on END studs and dives, a rounded nose sinking to the base under its neighbour
    # (which is exactly the joint profile over the first BAND studs and its own shape after that): no cut end wall
    x = np.clip((np.abs(S) - h) / END, 0.0, 1.0)
    f = f - (f - BOTTOM) * (1.0 - np.cos(0.5 * math.pi * x)) ** 1.5
    return np.maximum(f, BOTTOM + 1.0)


def crest_line(name, ss, step=0.25):
    """Highest point of the bank across each s of `ss`, from the height field."""
    import numpy as np
    ds = np.arange(TOE, OUTER + 1e-6, step)
    S, D = np.meshgrid(np.asarray(ss, dtype=float), ds, indexing="ij")
    return rim_height(name, S, D).max(axis=1)


def joint_report():
    """Every neighbour pair (A's +s end on B's -s end), unbent at scale 1: the visible bank is max(A, B). Returns
    [(pair, notch, gap)]: notch, how far the visible crest within BAND + RAMP / 2 of the joint dips below the lower of
    its two ends there (a notch is a dip lower than both sides); gap, how far the visible surface falls below the
    joint profile within BAND of the joint."""
    import numpy as np
    out = []
    ds = np.arange(TOE, OUTER + 1e-6, 0.5)
    win = BAND + RAMP / 2.0
    for a in RIM_NAMES:
        for b in RIM_NAMES:
            ha, hb = RIMS[a]["span"] / 2.0, RIMS[b]["span"] / 2.0
            ss = np.arange(ha - win, ha + win + 1e-6, 0.25)                # A's frame; B's s = s - ha - hb
            S, D = np.meshgrid(ss, ds, indexing="ij")
            vis = np.maximum(rim_height(a, S, D), rim_height(b, S - ha - hb, D))
            crest = vis.max(axis=1)
            notch = float(max(0.0, min(crest[0], crest[-1]) - crest.min()))
            band = np.abs(ss - ha) <= BAND
            gap = float(max(0.0, (rim_profile(D, JOINT_CREST, JOINT_AT)[band] - vis[band]).max()))
            out.append(("%s>%s" % (a[-2:], b[-2:]), notch, gap))
    return out


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
    ns, nd = int(2 * h / 0.8), int((OUTER - UNDER) / 0.8)
    ss = np.linspace(-h, h, ns + 1)
    ds = np.linspace(UNDER, OUTER, nd + 1)
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
    target -= CUT_TRIS
    for _ in range(6):
        ra.apply_mod(ob, 'DECIMATE', decimate_type='COLLAPSE', ratio=min(1.0, target / float(max(1, ra.tri_count(ob)))),
                     use_collapse_triangulate=True)
        if ra.tri_count(ob) <= RIM_TRIS - 10 - CUT_TRIS:
            break
        target -= 30
    cut_value_lines(ob, Rf)
    ra.tidy(ob)
    drop_loose(ob)
    flatten_base(ob)
    ob.data.materials.clear()
    for p in ob.data.polygons:
        p.material_index = 0
    rim_uvs(ob, Rf, name)
    ra.finish(ob, front_fn=lambda co: unbend(co, Rf)[1] < -4.0 and co.z > -60.0)    # the pool face and the toe under it
    return ob


CUT_TRIS = 110                # triangles kept back for the two cuts below


def cut_value_lines(ob, Rf):
    """An edge loop along the sand line on the pool face (z -26) and along the neighbouring floors' level on the
    outer face (z -66): the value map's buried band meets the dark block exactly there, so the dark foot keeps one
    width whatever the triangles (a triangle across the line would stretch it). Vertices within 0.5 of a line are
    moved onto it first, so the cut leaves no sliver."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    for z0, side in ((SAND_Z, -1), (OUTER_FLOOR_Z, 1)):
        on_side = [v for v in bm.verts if (unbend(v.co, Rf)[1] - JOINT_AT) * side > 0 and v.co.z > BOTTOM + 0.5]
        for v in on_side:
            if abs(v.co.z - z0) < 0.5:
                v.co.z = z0
        faces = [f for f in bm.faces if all((unbend(v.co, Rf)[1] - JOINT_AT) * side > 0 for v in f.verts)]
        geom = list({e for f in faces for e in f.edges}) + faces + list({v for f in faces for v in f.verts})
        bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-4, plane_co=(0.0, 0.0, z0), plane_no=(0.0, 0.0, 1.0))
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


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


RIM_CELL = "rim_bank"
# the rim cell's bands, in pixels from the cell's bottom (64 x 256 cell, value up the cell; independent review loop 1:
# three flat pastel coral blocks and two broad gradients, no pits, no seams). Rows below 16 are the buried band
# (outside the value count): faces under the sand, under the neighbouring floors, the walls and the base. It fades
# from the dark block at the line to the mid block's foot colour, so on a review sheet the hidden bulk does not read
# as a dark block and the foot has no hard lower edge.
RIM_BANDS = {"inset": 8, "buried": 16, "dark": 42, "mid": 192, "top": 248}
RIM_SHARE = {"dark": 0.115, "light": 0.26}   # 06 4.1: dark 10-15%, light 20-30% of the visible bank (the noses add dark)


def rim_cell_uv(px, b):
    """Cell pixel (px from its left, b from its bottom) -> atlas UV (Blender, v up)."""
    x0, y0, w, h = ATLAS_CELLS[RIM_CELL]
    return (x0 + px) / float(N), 1.0 - (y0 + h - b) / float(N)


def rim_exposure(name, s, d, z, nz):
    """How lit a point of the bank is: 0 at the sand line on the pool face and at the neighbouring floors' level on
    the outer face, rising with height (the pool face is measured against the water surface, so its light block starts
    just under the waterline, where a player sees it), plus a little for faces turned up to the sun. Below 0: buried."""
    import numpy as np
    C, dc = rim_crest(name, np.asarray(s, dtype=float))
    top = (C - SAND_Z) / (0.0 - SAND_Z)                       # the pool side's value at the crest
    pool = (z - SAND_Z) / (0.0 - SAND_Z)
    outer = (z - OUTER_FLOOR_Z) / (C - OUTER_FLOOR_Z) * top
    k = smooth(dc - 3.0, dc + 3.0, d)                         # the two agree at the crest; blend across it
    e = pool * (1.0 - k) + outer * k
    return np.where(e < 0.0, e, e + 0.15 * (nz - 0.7) * smooth(0.0, 0.15, e))


def rim_hue(name, s, d):
    """The second broad gradient, across the cell: peach (0) to rose (1), slow along the bank and up it."""
    import numpy as np
    rng = random.Random(RIMS[name]["seed"] + 31)
    n = 0.65 * np.sin(2 * math.pi * s / rng.uniform(34, 44) + rng.uniform(0, 6.3)) \
        + 0.35 * np.sin(2 * math.pi * d / rng.uniform(44, 60) + rng.uniform(0, 6.3))
    return 0.5 + 0.45 * np.tanh(1.6 * n)


def rim_uvs(ob, Rf, name):
    """Independent review loop 1 (06 16.1 lines 5, 8, 9, 15): the bank is painted from T_EnvNursery_Alb's rim cell,
    a gradient map, not a tiling rock texture. v runs up the cell with each vertex's exposure: the least lit 12% of
    the visible bank (its foot at the sand, the outer face low down) takes the dark band, the best lit 25% (the crest,
    the upper pool face just under the waterline, the top of the outer face) the light band, and the rest the mid band,
    in rank order, so each block's own gradient runs up the bank; u takes the slow peach-to-rose drift. Buried faces,
    walls and base go to the buried band. Every UV stays 8 px inside the cell, so no cell edge crosses a face. The
    band edges are set by measuring the shares as validate does (seven samples a triangle) and correcting."""
    import numpy as np
    me = ob.data
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    uvl = me.uv_layers.new(name=common.UV_NAME).data
    vs = me.vertices
    nv = len(vs)
    sdz = np.array([unbend(v.co, Rf) for v in vs])
    nz = np.array([v.normal.z for v in vs])
    e = rim_exposure(name, sdz[:, 0], sdz[:, 1], sdz[:, 2], nz)
    hue = rim_hue(name, sdz[:, 0], sdz[:, 1])
    top_poly = []
    for poly in me.polygons:
        pts = [sdz[i] for i in poly.vertices]
        top_poly.append(all(p[2] > BOTTOM + 0.5 for p in pts) and all(
            abs(p[2] - float(rim_height(name, np.array(p[0]), np.array(p[1])))) < 0.6 for p in pts))
    area = np.zeros(nv)
    for poly, top in zip(me.polygons, top_poly):
        if top:
            for i in poly.vertices:
                area[i] += poly.area / len(poly.vertices)
    vis = (area > 0) & (e >= 0.0)
    order = np.argsort(e[vis])
    cum = np.cumsum(area[vis][order])
    rank = np.zeros(nv)
    idx = np.nonzero(vis)[0][order]
    rank[idx] = (cum - 0.5 * area[vis][order]) / cum[-1]
    B = RIM_BANDS
    me.calc_loop_triangles()
    # the shares are set on what a ring shows: past BAND beyond a joint a piece is under its neighbour
    h_vis = RIMS[name]["span"] / 2.0 + BAND
    tris = [(t.vertices[:], t.area) for t in me.loop_triangles
            if top_poly[t.polygon_index] and abs(sum(sdz[i][0] for i in t.vertices) / 3.0) <= h_vis]
    import validate
    samples = validate._SAMPLES

    def vpx(qd, ql):
        out = np.where(rank < qd, B["buried"] + (B["dark"] - B["buried"] - 0.5) * rank / qd,
                       np.where(rank < ql, B["dark"] + 0.5 + (B["mid"] - B["dark"] - 1.0) * (rank - qd) / (ql - qd),
                                B["mid"] + 0.5 + (B["top"] - B["mid"] - 0.5) * (rank - ql) / (1.0 - ql)))
        bur = B["inset"] + (B["buried"] - B["inset"]) * np.clip(1.0 + e / 0.25, 0.0, 1.0)
        return np.where(vis, out, np.where(area > 0, bur, B["inset"] + 0.5))

    def shares(v):
        acc = {"dark": 0.0, "mid": 0.0, "light": 0.0}
        for (a, b_, c), ar in tris:
            for w in samples:
                x = w[0] * v[a] + w[1] * v[b_] + w[2] * v[c]
                if x < B["buried"]:
                    continue
                acc["dark" if x < B["dark"] else "mid" if x < B["mid"] else "light"] += ar
        tot = sum(acc.values()) or 1.0
        return {k: x / tot for k, x in acc.items()}
    qd, ql = RIM_SHARE["dark"], 1.0 - RIM_SHARE["light"]
    for _ in range(12):
        sh = shares(vpx(qd, ql))
        qd = min(0.3, max(0.02, qd + 0.9 * (RIM_SHARE["dark"] - sh["dark"])))
        ql = min(0.95, max(qd + 0.2, ql - 0.9 * (RIM_SHARE["light"] - sh["light"])))
    v = vpx(qd, ql)
    print("[nursery] %s value bands at ranks %.3f / %.3f: dark %.1f%%, mid %.1f%%, light %.1f%%"
          % (name, qd, ql, 100 * sh["dark"], 100 * sh["mid"], 100 * sh["light"]))
    ob["rim_value_shares"] = [round(100 * x, 1) for x in (sh["dark"], sh["mid"], sh["light"])]
    w = ATLAS_CELLS[RIM_CELL][2]
    pu = B["inset"] + 0.5 + (w - 2 * B["inset"] - 1.0) * hue
    for poly, top in zip(me.polygons, top_poly):
        for li in poly.loop_indices:
            i = me.loops[li].vertex_index
            if top:
                uvl[li].uv = rim_cell_uv(pu[i], v[i])
            else:
                uvl[li].uv = rim_cell_uv(w / 2.0, B["inset"] + 0.5)


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
            vary = (max(mids) - min(mids)) / max(mids)
            report.add(ob.name, "uneven crest", vary >= CREST_VARY and max(mids) <= RIM_TOP,
                       "the crest rises and falls by %.0f%% of its peak along the piece (at least %.0f%%; a dome to %.1f, a "
                       "saddle at %.1f; never above the Rim's top, %.0f)" % (100 * vary, 100 * CREST_VARY, max(mids), min(mids), RIM_TOP))
        rows = joint_report()
        worst_notch, worst_gap = max(r[1] for r in rows), max(r[2] for r in rows)
        report.add(objs[0].name, "joints: one bank", worst_notch <= NOTCH_MAX and worst_gap <= 0.05,
                   "every neighbour pair (%s): the visible crest dips at most %.2f below both sides of a joint (limit %.2f), "
                   "the visible bank at most %.2f under the shared joint profile" % (
                       ", ".join(r[0] for r in rows), worst_notch, NOTCH_MAX, worst_gap))
        for ob in objs:
            d_, m_, l_ = ob.get("rim_value_shares", (0, 0, 0))
            report.add(ob.name, "three values on the bank", 10 <= d_ <= 15 and 55 <= m_ <= 65 and 20 <= l_ <= 30,
                       "dark %.1f%%, mid %.1f%%, light %.1f%% of the visible bank (06 4.1)" % (d_, m_, l_))
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
    "rim_bank": "M_Env_Nursery_Rim_01-02 (gradient map: value up the cell, peach to rose across)", "grass_gold": "M_Env_Nursery_GrassTuft_01",
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
# the rim cell (independent review loop 1, 06 16.1 line 8: pastel coral, not muddy brown): the 06 9.3 coral hues
# (#FF7F9F pink, #FFA35C orange, #B48CFF violet) taken pastel. Mid 66 to 77 L*, light 87 to 90, dark 33; the sand
# (#F6E3B4) is 91, so the bank's largest block sits 14 to 25 L* under it, and its dark foot meets it.
RIM_PAINT = {
    "dark": "#54427F",                                         # soft violet, L* 33
    "mid": (("#DC8D86", "#F5AE98"), ("#D6899A", "#F1A8A9")),   # (low, high): peach column, rose column
    "light": (("#FAD0C1", "#FFDACA"), ("#F7CEC9", "#FCD7D1")),
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
    """The rim's gradient map (64 x 256): bands up the cell (RIM_BANDS) from the buried band and the dark block
    (one flat soft violet) through the mid block (rose-mauve at its foot to peach at its top, 11 L*) to the light
    block (87 to 90 L*); across the cell, the peach column to the rose column at the same lightness. Brush-soft band
    edges (3 px); no marks, so nothing reads as pits, cells or seams."""
    import numpy as np
    import tilegen
    B = RIM_BANDS
    b = (h - 1 - np.arange(h) + 0.5)[:, None] * np.ones((1, w))          # pixels from the bottom
    t = np.clip((np.arange(w)[None, :] + 0.5 - B["inset"]) / (w - 2.0 * B["inset"]), 0.0, 1.0) * np.ones((h, 1))

    def col(pair_a, pair_b, g):
        lo = tilegen.mix(_hex(pair_a[0]), _hex(pair_b[0]), t)
        hi = tilegen.mix(_hex(pair_a[1]), _hex(pair_b[1]), t)
        return tilegen.mix(lo, hi, np.clip(g, 0.0, 1.0))
    mid = col(RIM_PAINT["mid"][0], RIM_PAINT["mid"][1], (b - B["dark"]) / (B["mid"] - B["dark"]))
    light = col(RIM_PAINT["light"][0], RIM_PAINT["light"][1], (b - B["mid"]) / (B["top"] - B["mid"]))
    dark = np.broadcast_to(_hex(RIM_PAINT["dark"]), (h, w, 3))
    buried = tilegen.mix(col(RIM_PAINT["mid"][0], RIM_PAINT["mid"][1], np.zeros((h, w))), dark,
                         smooth(B["inset"], B["buried"], b))       # the dark foot fades out under the sand
    img = np.where((b < B["buried"])[..., None], buried, np.where((b < B["dark"])[..., None], dark,
                                                                  np.where((b < B["mid"])[..., None], mid, light)))
    for c in range(3):
        img[..., c] = _blur(img[..., c], 1, wrap=False)
    return img


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
