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
HAZE_CUT_R = 620.0                # 13 3.2: the soft-launch edge east and south of the Reef (no Drop-off)
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
    mod = ob.modifiers.new("cut", 'BOOLEAN')
    mod.operation = op
    try:
        mod.solver = 'EXACT'
    except TypeError:
        pass
    mod.object = cutter
    dg = bpy.context.evaluated_depsgraph_get()
    new = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.remove(mod)
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


def rim_texture(n=512, seed=21):
    """T_Rim_Alb, RGBA rows from the top, tiling both ways: three strata of large soft rock planes per
    repeat, each split at staggered joints; each plane one broad gradient in the mid block, a light lit
    band along its top edge, a blue-violet crease under it and at its joints (06 4.1, 5.2). No cobble:
    planes are 20 to 40 studs wide on the wall."""
    import numpy as np
    rng = random.Random(seed)
    tau = 2.0 * math.pi
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
    marks = np.array([0.0, 0.34 + rng.uniform(-0.03, 0.03), 0.68 + rng.uniform(-0.03, 0.03), 1.0])
    vv = (V + 0.03 * np.sin(tau * U + rng.uniform(0, tau)) + 0.018 * np.sin(tau * 2 * U + rng.uniform(0, tau))) % 1.0
    row = np.clip(np.searchsorted(marks, vv, side="right") - 1, 0, 2)
    t0, t1 = marks[row], marks[row + 1]
    ty = (vv - t0) / (t1 - t0)
    tx = np.zeros_like(U)
    dj = np.ones_like(U)
    grad = np.zeros_like(U)
    for r in range(3):
        k = rng.choice((2, 3))
        start = rng.uniform(0, 1)
        cuts = sorted((start + (i + rng.uniform(-0.12, 0.12)) / k) % 1.0 for i in range(k))
        m = row == r
        uu = (U[m] + 0.02 * np.sin(tau * V[m] * 3 + r)) % 1.0
        cs = np.array(cuts + [cuts[0] + 1.0])
        uq = np.where(uu < cs[0], uu + 1.0, uu)
        idx = np.clip(np.searchsorted(cs, uq, side="right") - 1, 0, k - 1)
        a, b = cs[idx], cs[idx + 1]
        tx[m] = (uq - a) / (b - a)
        dj[m] = np.minimum(uq - a, b - uq)
        dirs = np.array([rng.uniform(-1, 1) for _ in range(k)])
        grad[m] = 0.5 + 0.5 * (dirs[idx] * (tx[m] - 0.5) * 1.6)
    brush = 0.5 + 0.25 * np.sin(tau * (2 * U + V) + 1.3) * np.sin(tau * (U - 2 * V) + 0.4)
    col = mix(rgb(RIM_MID), rgb(RIM_MID2), np.clip(0.6 * grad + 0.4 * brush, 0, 1))
    db = np.minimum(ty, 1.0 - ty) * (t1 - t0)                      # distance to the stratum line, in repeats
    col = mix(col, rgb(RIM_LIGHT), sm(0.66, 0.8, ty) * (1.0 - sm(0.9, 0.95, ty)) * 0.97)
    crease = np.maximum(1.0 - sm(0.006, 0.03, db), 1.0 - sm(0.006, 0.026, dj))
    under = (1.0 - sm(0.0, 0.25, ty)) * 0.25                     # occlusion under each plane, violet
    col = mix(col, rgb(RIM_DARK), np.clip(np.maximum(crease, under), 0, 1))
    img = np.ones((n, n, 4))
    img[..., :3] = col
    return img


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
        dark, light = float((lab <= 40).mean()), float((lab >= 80).mean())
        report.add(ROCK_TILE, "three values", 0.08 <= dark <= 0.2 and 0.12 <= light <= 0.3,
                   "dark (L* 40 or less) %.0f%%, light (80 or more) %.0f%%, mid %.0f%% (06 4.1: 10-15 / 20-30 / 55-65, tuned for a wall)" % (
                       100 * dark, 100 * light, 100 * (1 - dark - light)))
        seam = max(float(np.abs(img[:, 0, :3] - img[:, -1, :3]).max()), float(np.abs(img[0, :, :3] - img[-1, :, :3]).max()))
        report.add(ROCK_TILE, "tiles both ways", seam < 0.12, "largest colour step across the wrap %.3f" % seam)
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
    for b, side in ((45.0, -1.0), (225.0, 1.0)):     # the Kelp's two ends, r 560 to 980, facing the Kelp
        for k, rm in enumerate((665.0, 875.0)):
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
    rt, rb = 12.0, 3.0
    hw = PASS_HALF_W + 0.7         # chords and triangles never pinch it under 64
    arc(hw - rb, PASS_FLOOR + rb, rb, -0.5 * math.pi, 0.0, 2)
    for z in (PASS_FLOOR + 12.0, PASS_FLOOR + 24.0, PASS_FLOOR + 36.0):
        pts.append((hw, z, "wall"))
    arc(hw - rt, PASS_ROOF + 0.4 - rt, rt, 0.0, 0.5 * math.pi, 4)
    for x in (12.0, 0.0, -12.0):
        pts.append((x, PASS_ROOF + 0.4, "roof"))
    arc(-hw + rt, PASS_ROOF + 0.4 - rt, rt, 0.5 * math.pi, math.pi, 4)
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
            if kind == "roof":
                sec.append((x, y, z + 0.6 * bump))
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
    tidy(ob, triangulate=False)
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


def build_piece(name):
    """One Rim piece in the ring frame: tidy, triangulated, UVs, vertex colour, front tag."""
    if name == "M_Env_Rim_Wall_01":
        v, f = loft(wall_sections(WALL_SPAN, SEEDS[name], columns=22, humps=(4.5, 8.0), bulge=(3.5, 6.0)))
        ob = mesh_object(name, v, f)
    elif name == "M_Env_Rim_Wall_02":
        v, f = loft(wall_sections(WALL_SPAN, SEEDS[name], cove=True, columns=22, humps=(2.5, 5.0), bulge=(2.0, 4.0)))
        ob = mesh_object(name, v, f)
        tidy(ob, triangulate=False)
        for cut in cove_cutters():
            boolean(ob, cut)
            remove(cut)
    elif name == "M_Env_Rim_Wall_03":
        v, f = loft(joint_sections(SEEDS[name]))
        ob = mesh_object(name, v, f)
    elif name in ("M_Env_Rim_Pass_01", "M_Env_Rim_Pass_02"):
        L = math.radians(PASS_SPAN) * R0
        rock = Rock(SEEDS["pass"], -L / 2.0, L / 2.0)
        west = name.endswith("_01")
        secs = wall_sections(PASS_SPAN, 0, s_range=(-L / 2.0, 0.0) if west else (0.0, L / 2.0),
                             end_recess=(True, False) if west else (False, True), columns=13, rock=rock)
        v, f = loft(secs)
        ob = mesh_object(name, v, f)
        tidy(ob, triangulate=False)
        for cut in [pass_cutter()] + notch_cutters():
            boolean(ob, cut)
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
