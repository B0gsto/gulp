"""Shared code for the Rim kit: task S5-A2 (docs/13-sprint-plan.md Sprint 5; docs/07-asset-list.md 6.1 rows
M_Env_Rim_Wall, M_Env_Rim_Pass, M_Env_Blue_Haze, T_Haze_Mask; docs/03-content-catalog.md 6.1 and 6.7;
docs/06-art-bible.md 4.2, 5.1, 5.3, 9.1 to 9.3, 10.2).

The ring frame. Every Rim piece is modelled in the map's own frame and centred on north: the map centre
at (0, 0), +Y north (bearing B000), +X east, z = 0 the sea surface. A piece is built "unrolled" in
(s, d, z): s runs along the ring (studs of arc at r 480), d out from the Rim's inner face (r 400; d < 0
stands proud into the Reef), z up. bend() rolls it onto the ring. The Reef side is -Y, the piece's front
(06 6.1), and FBX export turns that into the MeshPart's LookVector (coveart.A).

Sizes (03 6.7): the Rim runs from r 400 to r 560, top 12 studs above the surface; its foot is modelled
down to depth 100 so it stays buried under every floor beside it (Reef 60, Kelp 70, the Ledge 70 to 100).
Coves are 11 degrees apart (12 in the north-west), so a cove or plain piece spans 12 degrees and two
neighbours overlap by up to 1 degree; their ends are recessed so a joint reads as a crease between rock
masses. The pass spans 12 degrees too (64-stud corridor plus its flanks). Wall_03 is a 4-degree rounded
buttress that fills the 1 to 3 degree gaps beside the North, South and West passes and caps the Rim's
ends at the Nursery bulge. layout() is the whole ring; write_layout() puts it in the export folder.
"""
import json
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.normpath(os.path.join(HERE, "..", ".."))
for p in (os.path.join(SOURCE, "_shared", "blender"), os.path.join(SOURCE, "cove")):
    if p not in sys.path:
        sys.path.insert(0, p)

import common  # noqa: E402

# ---------------------------------------------------------------- sizes (03 6.1, 6.7)
R_IN, R_OUT, R0 = 400.0, 560.0, 480.0
TOP, BASE = 12.0, -100.0
TILE = 64.0                       # T_Rim_Alb repeats every 64 studs (large rock planes; review loop 1)
WALL_SPAN, JOINT_SPAN, PASS_SPAN = 12.0, 4.0, 12.0
PASS_HALF_W, PASS_FLOOR, PASS_ROOF = 32.0, -55.0, -5.0     # 03 6.7: 64 wide, depth 5 to 55
COVE_DEPTH = 30.0
HAZE_R, HAZE_SPAN, HAZE_TOP, HAZE_BOTTOM, HAZE_THICK = 980.0, 15.0, 0.0, -200.0, 4.0
HAZE_CUT_R = 620.0
HAZE_RADIAL_LEN = (985.0 - HAZE_CUT_R) / 2.0     # each straight piece; review loop 3: no clipped edge at the Nursery gap
HAZE_RADIAL_MIDS = (HAZE_CUT_R + HAZE_RADIAL_LEN / 2.0, HAZE_CUT_R + 1.5 * HAZE_RADIAL_LEN)                # 13 3.2: the soft-launch edge east and south of the Reef (no Drop-off)
ROCK_TILE = "T_Rim_Alb"           # review loop 1: the floor tile read as paving on a wall; no 07 row yet
SAND = "#F2D9A0"                  # 06 4.2 Reef sand: the Rim reads at least 15 L* darker and cooler
RIM_MID, RIM_MID2 = "#A2948F", "#978C8E"     # mid block, L* 62 / 59, cool grey-mauve
RIM_LIGHT = "#E8DCCB"             # sunlit top edges of the planes (light, L* 88)
RIM_DARK = "#4C4466"              # creases and undersides, blue-violet (dark, L* 31; 06 4.1 shadows to 250)
PLACEMENT_TINTS = (1.0, 0.93, 1.0, 0.96, 0.9, 0.98)   # SurfaceAppearance.Color per copy (06 5.3: variation by tint)
HAZE_MASK = "T_Haze_Mask"

COVES = (("C01", 12), ("C02", 23), ("C03", 34), ("C04", 45), ("C05", 56), ("C06", 67), ("C07", 78),
         ("C08", 102), ("C09", 113), ("C10", 124), ("C11", 135), ("C12", 146), ("C13", 157), ("C14", 168),
         ("C15", 194), ("C16", 205), ("C17", 245), ("C18", 256), ("C19", 285), ("C20", 297), ("C21", 309),
         ("C22", 321), ("C23", 333), ("C24", 345))
PASSES = (("North Pass", 0), ("East Pass", 90), ("South Pass", 180), ("West Pass", 270))
# Wall_03 buttresses: the gaps beside the passes, and the two ends of the Rim at the Nursery bulge.
JOINTS = (("N-west gatepost", 352.5), ("S-west gatepost", 187.0), ("Nursery bulge, south end", 212.0),
          ("Nursery bulge, north end", 238.0), ("W-south gatepost", 263.0), ("W-north gatepost", 277.5))
NURSERY_BULGE = (214.0, 236.0)     # Little Arch at B225: built by the Nursery kit (07 6.2), not the Rim

# 06 4.2 / 10.2: zone fog and light; the Rim rock tint is the tile's Reef rock (tilegen.tints)
FOG = {"reef": "#1E9FD0", "kelp": "#238A72", "nursery": "#4CCFD2"}
DEEP = {"reef": "#1783BF", "kelp": "#17604F"}


def smooth(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------- the rock: profile and pillows

def base_profile():
    """The Rim's cross-section, a closed loop in (d, z) with a kind per point, clockwise seen from +s:
    up the inner face, over the rounded top, down the outer face, back along the buried base."""
    pts = [(-4.0, BASE, "bottom")]
    for z in (-84.0, -70.0) + tuple(float(z) for z in range(-62, 7, 4)):
        pts.append((-4.0 * min(1.0, max(0.0, (8.0 - z) / 68.0)), z, "inner"))
    pts += [(0.7, 9.2, "nose_in"), (2.6, 11.3, "nose_in")]
    for d in (6.0, 14.0, 26.0, 40.0, 56.0, 72.0, 88.0, 104.0, 120.0, 134.0, 146.0):
        pts.append((d, TOP, "top"))
    pts += [(153.5, 11.5, "nose_out"), (157.6, 9.4, "nose_out")]
    for z in (5.0, -1.0, -9.0, -19.0, -31.0, -45.0, -61.0, -77.0, -91.0):
        t = min(1.0, max(0.0, (5.0 - z) / 105.0))
        pts.append((160.0 + 9.0 * t ** 1.6, z, "outer"))
    pts.append((169.0, BASE, "bottom"))
    return pts


def make_blocks(seed, s0, s1, rows, counts, amp):
    """Rounded rock slabs: rows (t0, t1) cut along s at staggered joints."""
    rng = random.Random(seed)
    out = []
    for t0, t1 in rows:
        n = rng.choice(counts)
        span = s1 - s0
        cuts = sorted(s0 + span * (k + rng.uniform(0.25, 0.75)) / n for k in range(1, n)) if n > 1 else []
        cuts = [c + rng.uniform(-0.08, 0.08) * span / n for c in cuts]
        edges = [s0 - 30.0] + cuts + [s1 + 30.0]
        for a, b in zip(edges, edges[1:]):
            out.append((a, b, t0, t1, rng.uniform(*amp)))
    return out


def jittered(seed, marks, jit):
    rng = random.Random(seed)
    return [m + (rng.uniform(-jit, jit) if 0 < i < len(marks) - 1 else 0.0) for i, m in enumerate(marks)]


def rows_of(marks):
    return list(zip(marks, marks[1:]))


class Rock:
    """Pillow fields of one piece: inner face (s, z), top (s, d), outer face (s, z)."""

    def __init__(self, seed, s0, s1, counts=(2, 3), amp_in=(1.6, 3.6), amp_out=(2.2, 4.4), humps=(3.0, 6.0), bulge=(2.0, 4.0)):
        rng = random.Random(seed + 7)
        L = s1 - s0
        self.humps = [(rng.uniform(s0 + 0.2 * L, s1 - 0.2 * L), rng.uniform(0.16, 0.3) * L, rng.uniform(*humps)) for _ in range(2)]
        self.bulges = [(rng.uniform(s0 + 0.2 * L, s1 - 0.2 * L), rng.uniform(0.15, 0.28) * L, rng.uniform(-42.0, -12.0),
                        rng.uniform(*bulge)) for _ in range(2)]
        self.inner = make_blocks(seed + 1, s0, s1, rows_of(jittered(seed + 2, [-120.0, -64.0, -42.0, -21.0, -1.0, 16.0], 3.5)), counts, amp_in)
        self.top = make_blocks(seed + 3, s0, s1, rows_of(jittered(seed + 4, [-10.0, 38.0, 82.0, 124.0, 175.0], 7.0)), counts, (0.4, 1.3))
        self.outer = make_blocks(seed + 5, s0, s1, rows_of(jittered(seed + 6, [-120.0, -72.0, -42.0, -15.0, 16.0], 4.0)), counts, amp_out)

    @staticmethod
    def field(blocks, s, t, radius=5.5):
        best = 0.0
        for a, b, t0, t1, amp in blocks:
            if a <= s <= b and t0 <= t <= t1:
                e = min(s - a, b - s, t - t0, t1 - t)
                k = min(1.0, e / radius)
                best = max(best, amp * (1.0 - (1.0 - k) ** 2))
        return best

    def hump(self, s):
        return sum(h * math.exp(-((s - c) / w) ** 2) for c, w, h in self.humps)

    def bulge(self, s, z):
        return sum(b * math.exp(-((s - c) / w) ** 2 - ((z - zc) / 24.0) ** 2) for c, w, zc, b in self.bulges)

    def disp(self, kind, s, d, z):
        if kind == "inner":
            return self.field(self.inner, s, z) + self.bulge(s, z)
        if kind == "nose_in":
            return 0.55 * self.field(self.inner, s, z) + 0.3 * self.field(self.top, s, 4.0) + 0.75 * self.hump(s)
        if kind == "top":
            return self.field(self.top, s, d) + self.hump(s) * (0.75 + 0.25 * math.sin(d / 25.0))
        if kind == "nose_out":
            return 0.55 * self.field(self.outer, s, z) + 0.3 * self.field(self.top, s, 150.0) + 0.6 * self.hump(s)
        if kind == "outer":
            return (self.field(self.outer, s, z) + 0.8 * self.bulge(s, z)) * smooth(BASE, BASE + 20.0, z)
        return 0.0


def normals2d(pts):
    out = []
    n = len(pts)
    for i in range(n):
        (d0, z0), (d1, z1) = pts[i - 1][:2], pts[(i + 1) % n][:2]
        td, tz = d1 - d0, z1 - z0
        ln = math.hypot(td, tz) or 1.0
        out.append((-tz / ln, td / ln))       # outward for a clockwise loop
    return out


def mouth_zone(phi, z):
    """1 where the Rim face must lie on the mouth plane (the cove mouth's stones and sill sit on it),
    falling to 0 just outside the stones: the arch outline (coveart.hole) grown by the stone frame."""
    x = R_IN * math.sin(phi)
    zz = z + COVE_DEPTH
    if zz >= 0.0:
        a, b, q = 18.0 + 15.5, 14.0 + 17.5, 2.5
    else:
        a, b, q = 18.0 + 15.5, 14.0 + 9.0, 6.0
    rho = (abs(x / a) ** q + abs(zz / b) ** q) ** (1.0 / q)
    return 1.0 - smooth(1.0, 1.22, rho)


def ring_section(s, profile, rock, end_w=0.0, cove=False, scale=None):
    """3D points of one cross-section at arc position s."""
    phi = s / R0
    nrm = normals2d(profile)
    out = []
    for (d, z, kind), (nd, nz) in zip(profile, nrm):
        h = rock.disp(kind, s, d, z) if rock else 0.0
        if kind != "bottom":
            h = h * (1.0 - end_w) - 2.4 * end_w
        dd, zz = d + nd * h, z + nz * h
        if kind == "bottom":
            zz = BASE
        if cove and kind in ("inner", "nose_in"):
            w = mouth_zone(phi, z)
            plane = R_IN / math.cos(phi) - R_IN            # the mouth plane y = 400 (the cove frame's y = 0)
            dd = dd * (1.0 - w) + plane * w
        if scale:
            kd, kz = scale
            dd = 80.0 + (dd - 80.0) * kd
            zz = BASE + (zz - BASE) * kz
        r = R_IN + dd
        out.append((r * math.sin(phi), r * math.cos(phi), zz))
    return out


def loft(sections):
    """Quads between consecutive sections and an n-gon cap at each end."""
    m = len(sections[0])
    verts = [p for sec in sections for p in sec]
    faces = []
    for k in range(len(sections) - 1):
        for i in range(m):
            j = (i + 1) % m
            faces.append((k * m + i, k * m + j, (k + 1) * m + j, (k + 1) * m + i))
    faces.append(tuple(range(m)))
    last = (len(sections) - 1) * m
    faces.append(tuple(last + i for i in range(m))[::-1])
    return verts, faces


def wall_sections(span_deg, seed, cove=False, s_range=None, end_recess=(True, True), columns=22, rock=None, **shape):
    L = math.radians(span_deg) * R0
    s0, s1 = s_range if s_range else (-L / 2.0, L / 2.0)
    rock = rock or Rock(seed, -L / 2.0, L / 2.0, **shape)
    prof = base_profile()
    secs = []
    for k in range(columns + 1):
        s = s0 + (s1 - s0) * k / columns
        w = 0.0
        if end_recess[0]:
            w = max(w, 1.0 - smooth(0.0, 9.0, s - (-L / 2.0)))
        if end_recess[1]:
            w = max(w, 1.0 - smooth(0.0, 9.0, L / 2.0 - s))
        secs.append(ring_section(s, prof, rock, w, cove))
    return secs


def joint_sections(seed, columns=16):
    """Wall_03: a rounded buttress swollen past the Rim's profile (so it covers a neighbour's end),
    tapering to a dome at both ends; the taper is scaled down toward the buried base."""
    L = math.radians(JOINT_SPAN) * R0
    rock = Rock(seed, -L / 2.0, L / 2.0, counts=(1, 2), amp_in=(2.0, 3.6), amp_out=(2.0, 3.6), humps=(1.5, 3.0), bulge=(1.0, 2.5))
    prof = base_profile()
    secs = []
    for k in range(columns + 1):
        u = -1.0 + 2.0 * k / columns
        s = (L / 2.0) * math.sin(0.5 * math.pi * u)
        t = max(0.0, (abs(s) - 8.5) / (L / 2.0 - 8.5))
        f = 0.22 + 0.78 * math.sqrt(max(0.0, 1.0 - min(1.0, t) ** 2)) if t > 0.0 else 1.0
        secs.append(ring_section(s, prof, rock, 0.0, False, scale=(1.10 * f, 1.05 * f)))
    return secs


# ---------------------------------------------------------------- Blender side

def bpy_mods():
    import bmesh
    import bpy
    from mathutils import Matrix, Vector
    return bpy, bmesh, Matrix, Vector


def mesh_object(name, verts, faces, collection="GEO"):
    bpy, bmesh, Matrix, Vector = bpy_mods()
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.validate()
    me.update()
    ob = bpy.data.objects.new(name, me)
    coll = bpy.data.collections.get(collection)
    (coll.objects if coll else bpy.context.scene.collection.objects).link(ob)
    return ob


def tidy(ob, triangulate=True):
    """Outward normals, merged slivers, triangles (06 6.5: triangulated at export; counted now)."""
    bpy, bmesh, Matrix, Vector = bpy_mods()
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.02)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=0.02)
    if triangulate:
        bmesh.ops.triangulate(bm, faces=bm.faces, quad_method='BEAUTY', ngon_method='BEAUTY')
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=0.02)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bm.calc_volume(signed=True) < 0.0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def boolean(ob, cutter, op='DIFFERENCE'):
    bpy, bmesh, Matrix, Vector = bpy_mods()
    for solver, nudge in (('EXACT', 0.0), ('EXACT', 0.0137), ('EXACT', -0.0291), ('MANIFOLD', 0.0)):
        # EXACT can return nothing on near-degenerate input; a hair's nudge of the cutter clears it
        cutter.matrix_world = Matrix.Translation((nudge, 0.7 * nudge, 0.4 * nudge))
        bpy.context.view_layer.update()
        mod = ob.modifiers.new("cut", 'BOOLEAN')
        mod.operation = op
        try:
            mod.solver = solver
        except TypeError:
            ob.modifiers.remove(mod)
            continue
        mod.object = cutter
        if solver == 'EXACT':
            for attr in ("use_self", "use_hole_tolerant"):   # remeshed, decimated rock may touch itself
                if hasattr(mod, attr):
                    setattr(mod, attr, True)
        dg = bpy.context.evaluated_depsgraph_get()
        new = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        ob.modifiers.remove(mod)
        if len(new.vertices):
            break
        print("[rim] %s: %s boolean (nudge %.4f) came back empty, trying again" % (ob.name, solver, nudge))
        bpy.data.meshes.remove(new)
    old = ob.data
    ob.data = new
    bpy.data.meshes.remove(old)
    new.name = ob.name


def remove(ob):
    bpy, bmesh, Matrix, Vector = bpy_mods()
    me = ob.data
    bpy.data.objects.remove(ob)
    if me and me.users == 0:
        bpy.data.meshes.remove(me)


def tile_uvs(ob):
    """Box projection in the ring's own axes (radial, along the ring, up), one tile per 32 studs, so
    the rock's strata run level and the repeat matches every other piece on the ring."""
    me = ob.data
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    uvl = me.uv_layers.new(name=common.UV_NAME).data
    vs = me.vertices
    for poly in me.polygons:
        c, n = poly.center, poly.normal
        r = math.hypot(c.x, c.y) or 1.0
        ar = abs(n.x * c.x / r + n.y * c.y / r)
        at = abs(n.x * c.y / r - n.y * c.x / r)
        az = abs(n.z)
        for li in poly.loop_indices:
            v = vs[me.loops[li].vertex_index].co
            rv = math.hypot(v.x, v.y)
            s = math.atan2(v.x, v.y) * rv
            if az >= max(ar, at):
                u, w = s, rv - R_IN
            elif ar >= at:
                u, w = s, v.z
            else:
                u, w = rv - R_IN, v.z
            uvl[li].uv = (u / TILE, w / TILE)


def finish(ob, front_r=None, front_fn=None):
    """Vertex colour layer (white: it does not show under a SurfaceAppearance, 06 5.3) and the
    front-marker tag on the Reef-side vertices for validate's facing check."""
    me = ob.data
    for a in list(me.color_attributes):
        me.color_attributes.remove(a)
    col = me.color_attributes.new(common.COLOR_ATTR, 'BYTE_COLOR', 'CORNER')
    for d in col.data:
        d.color = (1.0, 1.0, 1.0, 1.0)
    me.attributes.active_color_name = common.COLOR_ATTR
    me.attributes.default_color_name = common.COLOR_ATTR
    tag = me.attributes.get(common.TAG_ATTR) or me.attributes.new(common.TAG_ATTR, 'INT', 'POINT')
    for v, t in zip(me.vertices, tag.data):
        if front_fn:
            t.value = common.TAG_FRONT if front_fn(v.co) else 0
        else:
            t.value = common.TAG_FRONT if math.hypot(v.co.x, v.co.y) < front_r else 0
    for p in me.polygons:
        p.use_smooth = True


def fit_base(ob):
    """06 6.1 kit-piece origin: the centre of the base. Returns the ring-frame position of the origin."""
    bpy, bmesh, Matrix, Vector = bpy_mods()
    vs = ob.data.vertices
    lo = min(v.co.z for v in vs)
    base = [v.co for v in vs if v.co.z <= lo + 1e-4]
    off = Vector(((min(p.x for p in base) + max(p.x for p in base)) / 2.0,
                  (min(p.y for p in base) + max(p.y for p in base)) / 2.0, lo))
    ob.data.transform(Matrix.Translation(-off))
    ob.data.update()
    return off


def bounds(ob, off=None):
    vs = [tuple(v.co) for v in ob.data.vertices]
    lo = [min(v[i] for v in vs) for i in range(3)]
    hi = [max(v[i] for v in vs) for i in range(3)]
    if off is not None:
        lo = [lo[i] + off[i] for i in range(3)]
        hi = [hi[i] + off[i] for i in range(3)]
    return lo, hi


LIT, CREASE = (0.0, 0.3), 0.045      # review loop 3: facet tops lit, creases where boulders meet
UNDER = (-0.5, -0.9, 1.0)


def rim_texture(n=512, seed=43, points=14):
    """T_Rim_Alb, RGBA rows from the top, tiling both ways (review loop 3: no courses, no seam grid).
    Large irregular rock facets (a periodic Voronoi of 14 cells per 64-stud repeat, so 15 to 25 studs
    across): each facet one mid value with one broad gradient that lightens toward its upper edge (the
    light top planes) and cools to blue-violet along its underside; soft dark crevices only along about
    half the facet borders, where boulders meet (06 4.1, 5.2)."""
    import numpy as np
    rng = random.Random(seed)
    c = (np.arange(n) + 0.5) / n
    U, V = np.meshgrid(c, 1.0 - c)

    def rgb(h):
        h = h.lstrip("#")
        return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])

    def sm(e0, e1, x):
        t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
        return t * t * (3.0 - 2.0 * t)

    def mix(a, b, t):
        return a * (1.0 - t[..., None]) + b * t[..., None]
    pts = []
    while len(pts) < points:                   # well spread, no grid
        p = (rng.random(), rng.random())
        if all(min(abs(p[0] - q[0]), 1 - abs(p[0] - q[0])) ** 2 + min(abs(p[1] - q[1]), 1 - abs(p[1] - q[1])) ** 2 > 0.16 ** 2 for q in pts):
            pts.append(p)
    P = np.array(pts)
    best = np.full((2,) + U.shape, 9.0)
    ids = np.zeros((2,) + U.shape, dtype=int)
    dvs = np.zeros(U.shape)
    for i, (px, py) in enumerate(P):
        dx = (U - px + 0.5) % 1.0 - 0.5
        dy = (V - py + 0.5) % 1.0 - 0.5
        # stretched a little sideways (a shear would break the wrap)
        d = np.sqrt(dx ** 2 * 0.75 + dy ** 2)
        first = d < best[0]
        second = ~first & (d < best[1])
        best[1] = np.where(first, best[0], np.where(second, d, best[1]))
        ids[1] = np.where(first, ids[0], np.where(second, i, ids[1]))
        best[0] = np.where(first, d, best[0])
        ids[0] = np.where(first, i, ids[0])
        dvs = np.where(first, dy, dvs)
    edge = best[1] - best[0]
    tone = np.array([rng.uniform(0.0, 1.0) for _ in range(points)])
    lean = np.array([rng.uniform(-0.6, 0.6) for _ in range(points)])
    meet = np.array([[rng.random() < 0.5 for _ in range(points)] for _ in range(points)])
    meet = meet | meet.T
    size = 0.14
    up = np.clip((dvs + lean[ids[0]] * 0.2 * ((U - P[ids[0], 0] + 0.5) % 1.0 - 0.5)) / size, -1.5, 1.5)
    col = mix(rgb(RIM_MID), rgb(RIM_MID2), tone[ids[0]] * 0.7 + 0.15)
    col = mix(col, rgb(RIM_LIGHT), sm(LIT[0], LIT[1], up))                       # light top planes
    col = mix(col, rgb(RIM_DARK), sm(UNDER[0], UNDER[1], up) * UNDER[2])           # blue-violet undersides
    crease = (1.0 - sm(0.0, CREASE, edge)) * meet[ids[0], ids[1]]
    col = mix(col, rgb(RIM_DARK), crease)
    img = np.ones((n, n, 4))
    img[..., :3] = col
    return img


def banding(img):
    """Masonry guard: how much of the texture's value variation is explained by rows (or columns)
    alone, and the strongest single row period. Courses or a seam grid score high."""
    import numpy as np
    import tilegen
    lab = tilegen.lstar(img[..., :3])
    out = {}
    for axis, name in ((1, "rows"), (0, "columns")):
        prof = lab.mean(axis=axis)
        spread = float(prof.std() / (lab.std() or 1.0))
        f = np.abs(np.fft.rfft(prof - prof.mean()))[2:]
        k = int(np.argmax(f)) + 2
        peak = float(f.max() / (np.abs(np.fft.rfft(prof - prof.mean())).sum() or 1.0))
        out[name] = (spread, k, peak)
    return out


def rim_texture_file():
    """Paints T_Rim_Alb and writes the working copy the previews load; returns (img, path)."""
    from preyart import save_rgba
    img = rim_texture()
    path = os.path.join(common.review_dir(ROCK_TILE), "%s_work.png" % ROCK_TILE)
    save_rgba(path, img)
    return img, path


def rim_texture_checks(img):
    def check(spec, report):
        import numpy as np
        import tilegen
        lab = tilegen.lstar(img[..., :3])
        mean = img[..., :3].reshape(-1, 3).mean(axis=0)
        sand = np.array([int(SAND[i:i + 2], 16) / 255.0 for i in (1, 3, 5)])
        dl = common.lstar(SAND) - float(tilegen.lstar(mean))
        cool = mean[2] / mean[0] - sand[2] / sand[0]
        report.add(ROCK_TILE, "darker and cooler than sand", dl >= 15.0 and cool > 0.1,
                   "mean %s L* %.1f, %.1f below Reef sand %s; blue/red %.2f against sand's %.2f" % (
                       tilegen.hexof(mean), float(tilegen.lstar(mean)), dl, SAND, mean[2] / mean[0], sand[2] / sand[0]))
        dark, light = float((lab <= 35).mean()), float((lab >= 85).mean())
        mid = 1.0 - dark - light
        report.add(ROCK_TILE, "three values", 0.10 <= dark <= 0.15 and 0.20 <= light <= 0.30 and 0.55 <= mid <= 0.65,
                   "dark (L* 35 or less) %.1f%%, light (85 or more) %.1f%%, mid %.1f%% (06 4.1: 10-15 / 20-30 / 55-65)" % (
                       100 * dark, 100 * light, 100 * mid))
        for name, (spread, k, peak) in banding(img).items():
            report.add(ROCK_TILE, "no banding: %s" % name, spread < 0.45 and peak < 0.18,
                       "%s alone explain %.0f%% of the value spread (under 45%%; loop 2's courses: 67%%); strongest period %d per repeat "
                       "holds %.0f%% of it (under 18%%; courses: 29%%)"
                       % (name, 100 * spread, k, 100 * peak))
        rgb3 = img[..., :3]
        seam = np.concatenate([np.abs(rgb3[:, 0] - rgb3[:, -1]).max(axis=1), np.abs(rgb3[0] - rgb3[-1]).max(axis=1)])
        inner = np.concatenate([np.abs(np.diff(rgb3, axis=1)).max(axis=2).ravel(), np.abs(np.diff(rgb3, axis=0)).max(axis=2).ravel()])
        s_mean, i_mean = float(seam.mean()), float(inner.mean())
        report.add(ROCK_TILE, "tiles both ways", s_mean <= 1.5 * i_mean + 0.005 and float(seam.max()) <= float(inner.max()) + 1e-6,
                   "mean step across the wrap %.4f against %.4f inside; largest %.3f against %.3f inside (facet edges)" % (
                       s_mean, i_mean, float(seam.max()), float(inner.max())))
    return check


def rock_material(name="MAT_Rim_Rock", zone="reef"):
    """Preview stand-in for the SurfaceAppearance: T_Rim_Alb (painted, no tint), matte."""
    bpy, bmesh, Matrix, Vector = bpy_mods()
    img, path = rim_texture_file()
    tint = (1.0, 1.0, 1.0)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(path, check_existing=True)
    tex.extension = 'REPEAT'
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = 'RGBA'
    mul.blend_type = 'MULTIPLY'
    mul.inputs["Factor"].default_value = 1.0
    mul.inputs[7].default_value = (tint[0], tint[1], tint[2], 1.0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.85
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(tex.outputs["Color"], mul.inputs[6])
    nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def place(ob, bearing, radius_scale=1.0):
    """Puts a ring-frame object at its bearing (degrees clockwise from north, seen from above)."""
    bpy, bmesh, Matrix, Vector = bpy_mods()
    ob.matrix_world = Matrix.Rotation(-math.radians(bearing), 4, 'Z') @ Matrix.Diagonal((radius_scale, radius_scale, 1.0, 1.0))


# ---------------------------------------------------------------- the layout table

def roblox_cframe(centre, bearing, look=None, scale=(1.0, 1.0)):
    """Ring-frame box centre of a piece built on north -> its Roblox CFrame at `bearing`."""
    b = math.radians(bearing)
    x, y, z = centre[0] * scale[0], centre[1] * scale[1], centre[2]
    wx = x * math.cos(b) + y * math.sin(b)
    wy = -x * math.sin(b) + y * math.cos(b)
    pos = [round(wx, 3), round(z, 3), round(-wy, 3)]
    lk = look or (-math.sin(b), 0.0, math.cos(b))
    return {"position": pos, "look": [round(c, 5) for c in lk],
            "luau": "CFrame.lookAt(Vector3.new(%.3f, %.3f, %.3f), Vector3.new(%.3f, %.3f, %.3f))" % (
                pos[0], pos[1], pos[2], pos[0] + lk[0], pos[1] + lk[1], pos[2] + lk[2])}


def layout():
    """Every Rim and haze placement on the ring, by bearing (03 6.7)."""
    items = []
    for cove, b in COVES:
        items.append({"slot": cove, "mesh": "M_Env_Rim_Wall_02", "bearing": b, "note": "cove mouth on the inner face, r 400, depth 30"})
    for name, b in PASSES:
        items.append({"slot": name, "mesh": "M_Env_Rim_Pass_01", "bearing": b, "note": "west half (left, seen from the Reef)"})
        items.append({"slot": name, "mesh": "M_Env_Rim_Pass_02", "bearing": b, "note": "east half (right, seen from the Reef)"})
    for name, b in JOINTS:
        items.append({"slot": name, "mesh": "M_Env_Rim_Wall_03", "bearing": b, "note": "buttress over a gap or an end"})
    items = sorted(items, key=lambda it: it["bearing"])
    order = (0, 3, 1, 4, 2, 5)
    for i, it in enumerate(items):           # neighbours never share a tint; no mirroring (MeshParts cannot)
        t = PLACEMENT_TINTS[order[i % 6]]
        it["tint"] = "#%02X%02X%02X" % ((int(round(255 * t)),) * 3)
    return items


def haze_layout():
    out = []
    for k in range(12):             # the Kelp's outer edge, B225 clockwise to B045 (03 6.1: r 965 to 1,000)
        out.append({"slot": "edge %02d" % (k + 1), "bearing": 225.0 + 7.5 + 15.0 * k, "radius": HAZE_R, "kind": "arc"})
    for k in range(12):             # 13 3.2: east and south of the Reef, where the Drop-off is cut
        out.append({"slot": "cut %02d" % (k + 1), "bearing": 45.0 + 7.5 + 15.0 * k, "radius": HAZE_CUT_R, "kind": "arc"})
    for b, side in ((45.0, -1.0), (225.0, 1.0)):     # the Kelp's two ends, r 620 to 985, facing the Kelp;
        for k, rm in enumerate(HAZE_RADIAL_MIDS):    # they meet both arcs in corners, so no free edge shows
            out.append({"slot": "Kelp end B%03d %d" % (b, k + 1), "bearing": b, "radius": rm, "kind": "radial", "side": side})
    return out


def write_layout(content, stem="M_Env_Rim"):
    path = os.path.join(common.EXPORT_DIR, "meshes", stem + ".rim.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    table = {
        "frame": ("ring frame: the map centre at (0, 0, 0), the surface at height 0. Bearings are degrees clockwise from "
                  "north (Roblox -Z), east is +X (03 6.7: C07 at B078 is (391, -83)). Every piece is built centred on north; "
                  "'cframe' is the MeshPart's CFrame at its bearing. Studio places an imported MeshPart by its box centre, "
                  "so 'cframe.position' is the box centre, and LookVector (the mesh's front, -Y in Blender) faces the map "
                  "centre. 'blender' values are the source axes, 'roblox' = coveart.A @ blender."),
        "units": "studs",
        "source": "assets/source/env/rim (task S5-A2); sizes docs/03-content-catalog.md 6.1 and 6.7, 13 3.2",
    }
    table.update(content)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(table, f, indent=1)
    print("[rim] %s" % os.path.relpath(path, common.REPO_DIR))
    return path


# ---------------------------------------------------------------- the pieces (ring frame, before fit_base)

SEEDS = {"M_Env_Rim_Wall_01": 1101, "M_Env_Rim_Wall_02": 2202, "M_Env_Rim_Wall_03": 3303, "pass": 4404}
COVE_CUT_GROW = 3.0               # the Rim's opening: the mouth outline grown past the throat's 2.5-stud skin
CHAMBER_CUT = (42.0, 23.0, 137.0, 26.5)   # half width, y from, y to, half height: the interior shell (WALL 3) + 1


def cove_origin():
    return (0.0, R_IN, -COVE_DEPTH)


def cove_cutters():
    """Tunnel (the mouth's throat) and chamber box, in the ring frame, for the cove piece."""
    import coveart as ca
    ox, oy, oz = cove_origin()
    n = 48
    ring = []
    for k in range(n):
        th = 2.0 * math.pi * k / n
        hx, hz = ca.hole(th)
        nx, nz = ca.hole_normal(th)
        ring.append((hx + nx * COVE_CUT_GROW, hz + nz * COVE_CUT_GROW))
    verts = [(ox + x, oy + y, oz + z) for y in (-3.0, 26.0) for x, z in ring]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    faces += [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    tunnel = mesh_object("CUT_Tunnel", verts, faces, collection="PREVIEW")
    hw, y0, y1, hh = CHAMBER_CUT
    bv = [(ox + x, oy + y, oz + z) for x in (-hw, hw) for y in (y0, y1) for z in (-hh, hh)]
    bf = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    box = mesh_object("CUT_Chamber", bv, bf, collection="PREVIEW")
    for ob in (tunnel, box):
        tidy(ob, triangulate=False)
    return tunnel, box


def pass_cutter():
    """The 64-wide corridor, depth 5 to 55, straight through the Rim, its walls dented outward only."""
    pts = []
    def arc(cx, cz, r, a0, a1, n):
        for k in range(n):
            a = a0 + (a1 - a0) * k / n
            pts.append((cx + r * math.cos(a), cz + r * math.sin(a), "wall"))
    rt, rb = 17.0, 3.0              # review loop 2: a rounded arch, not a lintel
    hw = PASS_HALF_W + 0.7         # chords and triangles never pinch it under 64
    arc(hw - rb, PASS_FLOOR + rb, rb, -0.5 * math.pi, 0.0, 2)
    for z in (PASS_FLOOR + 12.0, PASS_FLOOR + 24.0, PASS_FLOOR + 36.0):
        pts.append((hw, z, "wall"))
    arc(hw - rt, PASS_ROOF + 0.6 - rt, rt, 0.0, 0.5 * math.pi, 5)
    for x in (10.5, 0.7, -9.5):           # no cutter vertex on the halves' seam plane x = 0
        pts.append((x, PASS_ROOF + 0.6, "roof"))
    arc(-hw + rt, PASS_ROOF + 0.6 - rt, rt, 0.5 * math.pi, math.pi, 5)
    for z in (PASS_FLOOR + 36.0, PASS_FLOOR + 24.0, PASS_FLOOR + 12.0):
        pts.append((-hw, z, "wall"))
    arc(-hw + rb, PASS_FLOOR + rb, rb, math.pi, 1.5 * math.pi, 2)
    for x in (-14.0, 0.0, 14.0):
        pts.append((x, PASS_FLOOR, "floor"))
    secs = []
    ys = [360.0 + 12.0 * k for k in range(21)]
    for y in ys:
        sec = []
        for i, (x, z, kind) in enumerate(pts):
            if kind == "floor":
                sec.append((x, y, z))
                continue
            bump = 1.8 * max(0.0, math.sin(y / 21.0 + i * 0.9)) * (0.6 + 0.4 * math.cos(y / 33.0 - i * 0.5))
            if kind == "roof":                   # irregular rock vault: dents upward only, never under depth 5
                sec.append((x, y, z + 1.4 * bump + 0.8 * max(0.0, math.sin(y / 9.0 + x / 7.0))))
            else:
                ln = math.hypot(x, z - (PASS_FLOOR + PASS_ROOF) / 2.0) or 1.0
                sec.append((x + bump * x / ln, y, z + bump * (z - (PASS_FLOOR + PASS_ROOF) / 2.0) / ln * 0.5))
        secs.append(sec)
    m = len(pts)
    verts = [p for sec in secs for p in sec]
    faces = []
    for k in range(len(secs) - 1):
        for i in range(m):
            j = (i + 1) % m
            faces.append((k * m + i, k * m + j, (k + 1) * m + j, (k + 1) * m + i))
    faces += [tuple(range(m)), tuple((len(secs) - 1) * m + i for i in range(m))[::-1]]
    ob = mesh_object("CUT_Pass", verts, faces, collection="PREVIEW")
    tidy(ob, triangulate=True)
    return ob


NOTCH_Y = ((352.0, 462.0), (498.0, 608.0))     # open to the sky; a 36-stud rock bridge stays between


def notch_cutters():
    """Review loop 1: the pass reads as a gap in the ring. Above the corridor the Rim is cut open to the
    sky with rounded, flaring sides, except for a natural bridge over the middle of its length."""
    hw = PASS_HALF_W + 0.7
    side = ((0.0, PASS_ROOF - 3.0), (0.8, 0.0), (2.5, 5.0), (5.0, 9.0), (8.0, 14.0), (9.0, 40.0))
    poly = [(hw + dx, z) for dx, z in side] + [(-hw - dx, z) for dx, z in side[::-1]]
    out = []
    for k, (y0, y1) in enumerate(NOTCH_Y):
        secs = []
        for j in range(9):
            y = y0 + (y1 - y0) * j / 8
            sec = []
            for i, (x, z) in enumerate(poly):
                bump = 1.2 * max(0.0, math.sin(y / 17.0 + i * 1.1)) if 0 < z < 30 else 0.0
                sec.append((x + math.copysign(bump, x), y, z))
            secs.append(sec)
        m = len(poly)
        verts = [p for sec in secs for p in sec]
        faces = [(a * m + i, a * m + (i + 1) % m, (a + 1) * m + (i + 1) % m, (a + 1) * m + i) for a in range(8) for i in range(m)]
        faces += [tuple(range(m)), tuple(8 * m + i for i in range(m))[::-1]]
        ob = mesh_object("CUT_Notch%d" % k, verts, faces, collection="PREVIEW")
        tidy(ob, triangulate=False)
        out.append(ob)
    return out


def bend(p):
    """Unrolled (s, d, z) -> ring frame."""
    s_, d, z = p
    phi = s_ / R0
    r = R_IN + d
    return (r * math.sin(phi), r * math.cos(phi), z)


def boulder(c, radii, seed, lean=12.0, facets=4, lumps=0.08):
    """One deformed rock mass in unrolled coordinates: an icosphere stretched to `radii`, lumped by a
    few soft waves, cut by flat facet planes (rock planes, 06 3: rounded but not blobby), its foot
    flattened, leaned and turned. Returns (verts in the ring frame, faces)."""
    import bmesh
    from mathutils import Matrix, Vector
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    waves = [(Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))).normalized() * rng.uniform(1.5, 3.2),
              rng.uniform(0.5, 1.0) * lumps, rng.uniform(0, 2 * math.pi)) for _ in range(5)]
    planes = [(Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 0.6) + 0.5)).normalized(), rng.uniform(0.8, 0.92))
              for _ in range(facets)] + [(Vector((0.0, 0.0, -1.0)), 0.7)]
    rot = (Matrix.Rotation(math.radians(rng.uniform(-25, 25)), 3, 'Z') @ Matrix.Rotation(math.radians(rng.uniform(-lean, lean)), 3, 'X')
           @ Matrix.Rotation(math.radians(rng.uniform(-lean, lean)), 3, 'Y'))
    verts = []
    for v in bm.verts:
        n = v.co.normalized()
        r = 1.0 + sum(a * math.cos(f.dot(n) * 2.0 + ph) for f, a, ph in waves)
        for m, o in planes:
            k = n.dot(m)
            if k > 1e-3:
                r = min(r, o / k)
        q = rot @ Vector((n.x * r * radii[0], n.y * r * radii[1], n.z * r * radii[2]))
        verts.append(bend((c[0] + q.x, c[1] + q.y, c[2] + q.z)))
    faces = [tuple(v.index for v in f.verts) for f in bm.faces]
    bm.free()
    return verts, faces


def apply_mod(ob, kind, **props):
    bpy, bmesh, Matrix, Vector = bpy_mods()
    mod = ob.modifiers.new(kind.lower(), kind)
    for k, v in props.items():
        setattr(mod, k, v)
    dg = bpy.context.evaluated_depsgraph_get()
    new = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.remove(mod)
    old = ob.data
    ob.data = new
    bpy.data.meshes.remove(old)
    new.name = ob.name


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def fuse(name, parts, target, voxel=1.6):
    """Joins the core and the boulders, fuses them into one closed surface (voxel remesh), then
    decimates to `target` triangles (06 6.3 budgets)."""
    verts, faces = [], []
    for v, f in parts:
        o = len(verts)
        verts += v
        faces += [tuple(i + o for i in t) for t in f]
    ob = mesh_object(name, verts, faces)
    tidy(ob, triangulate=False)
    apply_mod(ob, 'REMESH', mode='VOXEL', voxel_size=voxel, adaptivity=0.0)
    apply_mod(ob, 'DECIMATE', decimate_type='COLLAPSE', ratio=min(1.0, target / float(max(1, tri_count(ob)))), use_collapse_triangulate=True)
    return ob


def core_parts(span_deg, s_range=None, top=TOP, inset=3.0):
    """The Rim's body behind the boulders: the plain profile, set back `inset` on the inner face."""
    L = math.radians(span_deg) * R0
    s0, s1 = s_range if s_range else (-L / 2.0, L / 2.0)
    prof = [(d + (inset if k in ("inner", "nose_in") else 0.0), z, k) for d, z, k in base_profile()]
    secs = [ring_section(s0 + (s1 - s0) * k / 10, prof, None) for k in range(11)]
    return loft(secs)


def scatter(seed, L, kind):
    """Boulder list [(centre (s, d, z), radii (s, d, z), seed)] for a span of arc L (at R0)."""
    rng = random.Random(seed)
    h = L / 2.0
    out = []

    def add(s_, d, z, rs, rd, rz):
        rs = min(rs, h - abs(s_) - 1.5)
        if rs > 5.0:
            out.append(((s_, d, z), (rs, rd, rz), rng.randint(0, 1 << 30)))
    if kind == "wall":
        n = rng.choice((3, 4))
        for i in range(n):                                   # the Reef face: big leaning masses
            s_ = -h + (i + 0.5) * L / n + rng.uniform(-5, 5)
            add(s_, rng.uniform(3.0, 9.0), rng.uniform(-48, -20), rng.uniform(17, 25), rng.uniform(13, 18), rng.uniform(24, 34))
        for i in range(rng.choice((2, 3))):                  # the skyline: stepped, uneven, never under +12
            add(rng.uniform(-h + 18, h - 18), rng.uniform(20, 135), rng.uniform(5, 11), rng.uniform(18, 28), rng.uniform(26, 40), rng.uniform(9, 15))
        for i in range(2):                                   # the outer face
            add(rng.uniform(-h + 20, h - 20), rng.uniform(152, 160), rng.uniform(-48, -12), rng.uniform(20, 28), rng.uniform(12, 18), rng.uniform(22, 32))
        for i in range(rng.choice((1, 2))):                  # low feet that bury into the sand
            add(rng.uniform(-h + 14, h - 14), rng.uniform(-8, -2), rng.uniform(-68, -60), rng.uniform(12, 18), rng.uniform(10, 14), rng.uniform(8, 12))
    elif kind == "cove":
        for sgn in (-1, 1):                                  # flanks of the mouth, leaning in
            add(sgn * rng.uniform(40, 44), rng.uniform(2, 6), rng.uniform(-44, -26), rng.uniform(9, 12), rng.uniform(12, 16), rng.uniform(22, 30))
        add(rng.uniform(-8, 8), rng.uniform(2, 6), rng.uniform(7, 10), rng.uniform(26, 34), rng.uniform(12, 16), rng.uniform(8, 11))   # brow
        for i in range(2):
            add(rng.uniform(-h + 18, h - 18), rng.uniform(30, 130), rng.uniform(5, 10), rng.uniform(18, 26), rng.uniform(26, 38), rng.uniform(9, 13))
        for i in range(2):
            add(rng.uniform(-h + 20, h - 20), rng.uniform(152, 160), rng.uniform(-48, -12), rng.uniform(18, 26), rng.uniform(12, 16), rng.uniform(22, 30))
        add(rng.uniform(-30, 30), rng.uniform(-8, -2), rng.uniform(-70, -62), rng.uniform(16, 22), rng.uniform(10, 14), rng.uniform(8, 11))
    elif kind == "joint":
        add(0.0, rng.uniform(0, 4), -30.0, h - 1.5, rng.uniform(16, 20), rng.uniform(34, 40))
        add(rng.uniform(-3, 3), rng.uniform(50, 90), 9.0, h - 1.5, 50.0, rng.uniform(12, 15))
        add(0.0, 160.0, -30.0, h - 1.5, 16.0, 34.0)
    elif kind == "pass":
        for sgn in (-1, 1):                                  # jambs at both ends of the corridor, rounded and uneven
            for d, z in ((rng.uniform(0, 4), rng.uniform(-40, -26)), (rng.uniform(156, 160), rng.uniform(-40, -26))):
                xs = 37.0 if d < 80 else 46.0
                add(sgn * xs * R0 / (R_IN + d), d, z, rng.uniform(8, 10), rng.uniform(12, 16), rng.uniform(22, 30))
        add(rng.uniform(-6, 6), rng.uniform(-2, 2), rng.uniform(4, 7), rng.uniform(28, 34), rng.uniform(11, 14), rng.uniform(9, 12))      # brow, inner
        add(rng.uniform(-6, 6), rng.uniform(156, 160), rng.uniform(3, 6), rng.uniform(28, 34), rng.uniform(11, 14), rng.uniform(9, 12))   # brow, outer
        add(rng.uniform(-4, 4), rng.uniform(70, 90), 13.0, rng.uniform(32, 38), rng.uniform(48, 58), rng.uniform(11, 14))                # crown, thick mid-span
    return out


def zone_cutter():
    """Prism of the stone frame's outline (mouth_zone) in front of the mouth plane: cuts the Rim flat there."""
    ox, oy, oz = cove_origin()
    pts = []
    for k in range(72):
        th = 2.0 * math.pi * k / 72
        c, s_ = math.cos(th), math.sin(th)
        a, b, q = (33.5, 31.5, 2.5) if s_ >= 0 else (33.5, 23.0, 6.0)
        a, b = a * 1.04, b * 1.04
        pts.append((a * math.copysign(abs(c) ** (2.0 / q), c), b * math.copysign(abs(s_) ** (2.0 / q), s_)))
    m = len(pts)
    verts = [(ox + x, y, oz + z) for y in (oy - 40.0, oy) for x, z in pts]
    faces = [(i, (i + 1) % m, m + (i + 1) % m, m + i) for i in range(m)] + [tuple(range(m))[::-1], tuple(range(m, 2 * m))]
    ob = mesh_object("CUT_Zone", verts, faces, collection="PREVIEW")
    tidy(ob, triangulate=False)
    return ob


def half_box(west):
    x0, x1 = (-400.0, 0.0) if west else (0.0, 400.0)
    verts = [(x, y, z) for x in (x0, x1) for y in (300.0, 700.0) for z in (-300.0, 200.0)]
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    ob = mesh_object("CUT_Half", verts, faces, collection="PREVIEW")
    tidy(ob, triangulate=False)
    return ob


TARGETS = {"M_Env_Rim_Wall_01": 2300, "M_Env_Rim_Wall_02": 1950, "M_Env_Rim_Wall_03": 1500, "pass": 2900}


def build_piece(name):
    """One Rim piece in the ring frame (review loop 3): the plain Rim body with 5 to 9 large rounded
    rock masses fused into it (voxel remesh, decimated to budget), then cut where the kit needs it."""
    L = math.radians(WALL_SPAN) * R0
    if name == "M_Env_Rim_Wall_01":
        parts = [core_parts(WALL_SPAN)] + [boulder(c, r, sd) for c, r, sd in scatter(SEEDS[name], L, "wall")]
        ob = fuse(name, parts, TARGETS[name])
    elif name == "M_Env_Rim_Wall_02":
        block = boulder((0.0, 8.0, -COVE_DEPTH), (47.0, 20.0, 42.0), SEEDS[name] + 1, lean=0.0, facets=0, lumps=0.03)
        parts = [core_parts(WALL_SPAN), block] + [boulder(c, r, sd) for c, r, sd in scatter(SEEDS[name], L, "cove")]
        ob = fuse(name, parts, TARGETS[name])
        for cut in [zone_cutter()] + list(cove_cutters()):
            boolean(ob, cut)
            remove(cut)
    elif name == "M_Env_Rim_Wall_03":
        Lj = math.radians(JOINT_SPAN) * R0
        v, f = loft(joint_sections(SEEDS[name]))
        parts = [(v, f)] + [boulder(c, r, sd, lean=6.0) for c, r, sd in scatter(SEEDS[name], Lj, "joint")]
        ob = fuse(name, parts, TARGETS[name])
    elif name in ("M_Env_Rim_Pass_01", "M_Env_Rim_Pass_02"):
        parts = [core_parts(PASS_SPAN)] + [boulder(c, r, sd, lean=8.0) for c, r, sd in scatter(SEEDS["pass"], L, "pass")]
        ob = fuse(name, parts, TARGETS["pass"])
        for cut in (pass_cutter(), half_box(name.endswith("_01"))):
            boolean(ob, cut, op='INTERSECT' if cut.name.startswith("CUT_Half") else 'DIFFERENCE')
            remove(cut)
    else:
        raise KeyError(name)
    tidy(ob)
    ob.data.materials.clear()             # the cutters' empty slots (06 6.5: one material per mesh)
    for p in ob.data.polygons:
        p.material_index = 0
    tile_uvs(ob)
    finish(ob, front_r=R_IN + 8.0)
    return ob


# ---------------------------------------------------------------- the Blue Haze

HAZE_COLS = 15
HAZE_ROWS = ((HAZE_BOTTOM, HAZE_R - 5.0), (-125.0, HAZE_R - 1.5), (-50.0, HAZE_R), (HAZE_TOP, HAZE_R))


def build_haze(name="M_Env_Blue_Haze"):
    """A curved curtain 15 degrees long at r 980, the floor to the surface, 4 studs thick. Only its
    inner face is drawn with the mask; the back, rims and ends map to the mask's clear top corner."""
    half = math.radians(HAZE_SPAN) / 2.0
    C, R = HAZE_COLS, len(HAZE_ROWS)
    verts = []
    for k in range(C + 1):
        a = -half + 2.0 * half * k / C
        for z, r in HAZE_ROWS:
            verts.append((r * math.sin(a), r * math.cos(a), z))
    back0 = len(verts)
    rb = HAZE_R + HAZE_THICK
    for k in range(C + 1):
        a = -half + 2.0 * half * k / C
        for z in (HAZE_BOTTOM, HAZE_TOP):
            verts.append((rb * math.sin(a), rb * math.cos(a), z))
    F = lambda k, j: k * R + j
    B = lambda k, j: back0 + k * 2 + j
    faces, uvs = [], []
    clear = (0.5, 0.996)
    for k in range(C):
        for j in range(R - 1):
            faces.append((F(k, j), F(k + 1, j), F(k + 1, j + 1), F(k, j + 1)))
            uvs.append([(k / C, (HAZE_ROWS[j][0] - HAZE_BOTTOM) / (HAZE_TOP - HAZE_BOTTOM)),
                        ((k + 1) / C, (HAZE_ROWS[j][0] - HAZE_BOTTOM) / (HAZE_TOP - HAZE_BOTTOM)),
                        ((k + 1) / C, (HAZE_ROWS[j + 1][0] - HAZE_BOTTOM) / (HAZE_TOP - HAZE_BOTTOM)),
                        (k / C, (HAZE_ROWS[j + 1][0] - HAZE_BOTTOM) / (HAZE_TOP - HAZE_BOTTOM))])
        faces.append((B(k, 0), B(k, 1), B(k + 1, 1), B(k + 1, 0)))
        faces.append((F(k, R - 1), F(k + 1, R - 1), B(k + 1, 1), B(k, 1)))
        faces.append((F(k, 0), B(k, 0), B(k + 1, 0), F(k + 1, 0)))
        uvs += [[clear] * 4] * 3
    faces.append(tuple([F(0, j) for j in range(R)] + [B(0, 1), B(0, 0)])[::-1])
    faces.append(tuple([F(C, j) for j in range(R)] + [B(C, 1), B(C, 0)]))
    uvs += [[clear] * (R + 2)] * 2
    ob = mesh_object(name, verts, faces)
    me = ob.data
    uvl = me.uv_layers.new(name=common.UV_NAME).data
    for poly, uv in zip(me.polygons, uvs):
        for li, t in zip(poly.loop_indices, uv):
            uvl[li].uv = t
    tidy(ob)
    finish(ob, front_fn=lambda co: math.hypot(co.x, co.y) < HAZE_R + 0.5)
    return ob


def haze_mask(n=256, seed=11):
    """T_Haze_Mask: RGBA, row 0 at the top. Alpha: dense at the floor, one long smooth fade up the water
    column that clears before the surface (review loop 1 replaced the ragged top); it wraps left to right.
    RGB: white above, easing to 0.80 at the floor, so the zone fog tint darkens to the deep band there."""
    import numpy as np
    rng = random.Random(seed)
    u = (np.arange(n) + 0.5) / n
    v = 1.0 - (np.arange(n) + 0.5) / n
    U, V = np.meshgrid(u, v)
    tau = 2.0 * math.pi

    def sm(e0, e1, x):
        t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
        return t * t * (3.0 - 2.0 * t)
    # review loop 1: one long smooth vertical fade, no ragged teeth; dense only near the floor
    alpha = np.clip(0.92 - 0.06 * sm(0.0, 0.25, V), 0.0, 1.0) * (1.0 - sm(0.12, 0.93, V)) ** 1.15
    shade = 0.80 + 0.20 * sm(0.0, 0.8, V)
    img = np.zeros((n, n, 4))
    img[..., 0] = img[..., 1] = img[..., 2] = shade
    img[..., 3] = alpha
    return img


def haze_material(image_path, fog_hex, name="MAT_Blue_Haze"):
    """Preview of SurfaceAppearance(ColorMap = T_Haze_Mask, AlphaMode = Transparency, Color = zone fog):
    drawn unlit at the fog colour so it reads as the fog thickening, not as a lit wall."""
    bpy, bmesh, Matrix, Vector = bpy_mods()
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(image_path, check_existing=True)
    tex.extension = 'REPEAT'
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = 'RGBA'
    mul.blend_type = 'MULTIPLY'
    mul.inputs["Factor"].default_value = 1.0
    mul.inputs[7].default_value = tuple(common.hex_to_linear(fog_hex)) + (1.0,)
    emi = nt.nodes.new("ShaderNodeEmission")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(tex.outputs["Color"], mul.inputs[6])
    nt.links.new(mul.outputs[2], emi.inputs["Color"])
    nt.links.new(tex.outputs["Alpha"], mix.inputs[0])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(emi.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    for attr, val in (("surface_render_method", 'BLENDED'), ("blend_method", 'BLEND')):
        try:
            setattr(mat, attr, val)
        except Exception:
            pass
    mat.use_backface_culling = True
    return mat


# ---------------------------------------------------------------- checks shared by the build files

def piece_checks(entries):
    """Origin and facing rows for the meshes that are not the spec's primary (validate checks that one)."""
    def check(spec, report):
        for ob in entries:
            vs = ob.data.vertices
            lo = min(v.co.z for v in vs)
            base = [v.co for v in vs if v.co.z <= lo + 1e-4]
            bx = (min(p.x for p in base) + max(p.x for p in base)) / 2.0
            by = (min(p.y for p in base) + max(p.y for p in base)) / 2.0
            report.add(ob.name, "origin", abs(lo) < 1e-4 and abs(bx) < 0.5 and abs(by) < 0.5,
                       "base at z %.4f, base centre (%.3f, %.3f); origin is the centre of the base" % (lo, bx, by))
            attr = ob.data.attributes.get(common.TAG_ATTR)
            ys = [v.co.y for v, t in zip(vs, attr.data) if t.value == common.TAG_FRONT] if attr else []
            cy = sum(ys) / len(ys) if ys else 0.0
            report.add(ob.name, "facing", bool(ys) and cy < 0.0, "Reef-side vertices centred at y %.2f; front is -Y" % cy)
    return check
