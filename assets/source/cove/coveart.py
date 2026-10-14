"""Shared side of the cove structure (task S5-A3, docs/13-sprint-plan.md Sprint 5): the cove frame,
the atlas T_Cove_Alb, the mesh helpers of M_Cove_Mouth and M_Cove_Interior, the perch layout and
the data table for the Studio assembly (docs/09-technical-architecture.md sections 3.1, 9.1, 13.1).

Sizes are chapter 03's (sections 6.7 and 6.10), copied in 06 9.3 and 07 6.6:
  mouth opening 36 wide x 28 high, 25-stud throat; chamber 76 wide x 110 long x 44 high,
  floor at depth 52, ceiling at depth 8; the mouth is centred at depth 30.

The cove frame (all positions below, Blender axes, studs): origin at the centre of the mouth
opening on the mouth plane (the flat plane CoveSafe starts at, 02 11.1), at depth 30. +Y runs
into the cove (out through the Rim), -Y out to the Reef; +Z up; +X is on the right of a creature
swimming in. Roblox axes are (-x, z, y) (animrbx.A): the mouth's LookVector points out to the Reef.

Texturing (06 5.1, 5.3, 5.6): one 512 atlas for the whole cove kit, base colours in the colour
map (a SurfaceAppearance hides vertex colour, spike F16). The two structure meshes are far larger
than the atlas can cover at 24 px/stud, so they use tileable cells (stone, sand, terrace step, ceiling
crack, arch stone) that faces share: overlapping UV islands, each face inside one cell. Free atlas
space (RESERVED) is left for the cove props of the later rows of 07 6.6.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "_shared", "blender"))

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402
import preyart  # noqa: E402
import validate  # noqa: E402

ALBEDO = "T_Cove_Alb"
SIZE = 512
HIDDEN_ATTR = "gulp_hidden"    # build-time face flag: buried in the Rim rock, never seen; never exported

# ---------------------------------------------------------------- sizes (03 6.7, 6.10)
MOUTH_W, MOUTH_H = 36.0, 28.0
THROAT = 25.0
CH_W, CH_L, CH_H = 76.0, 110.0, 44.0
CH_Y0 = THROAT                      # the chamber starts where the throat ends
CH_YC = CH_Y0 + CH_L / 2.0
FLOOR_Z, CEIL_Z = -22.0, 22.0       # depth 52 and 8 around the mouth centre at depth 30
DEPTH = 30.0                        # depth of the cove frame origin

# ---------------------------------------------------------------- palette (06 4.1, 4.2 cove row, 4.5)
STONE = "#D9B48F"         # 06 4.2: cove interior warm stone (mid, L* 76)
WARM_A = "#D6B08C"        # walls, lit end of their one gradient (mid, L* 74)
WARM_B = "#CDA88A"        # walls, other end (mid, L* 71)
COOL_A = "#C8A693"        # vault: hue toward violet (06 4.1), still mid (L* 70)
COOL_B = "#C2A194"        # (mid, L* 68: within 6 of the walls, 12 of the base)
SAND = "#F8E2AE"          # the soft sand floor, warmer than 06 4.2's Nursery sand (light, L* 90)
SAND_SHADE = "#F4DCA8"    # one broad soft gradient, still light
THROAT_INK = "#4A3F66"        # the mouth's throat: blue-violet dark (dark block, L* 29)
THROAT_INK_DEEP = "#33294A"   # its inner ring, deeper (dark block, L* 19)
LIP = "#F8E8C6"           # worn lips and step edges catching the warm light (light)
GLOW = "#FCF1D2"          # light through the ceiling cracks and the Trophy niche (light; not the reserved #FFF1DC)
DARK = "#5E4058"          # crevices and creases: violet-brown, never black (dark, L* 31)

CELLS = {   # pixels (x0, y0, x1, y1), y from the top of the image
    "warm": (0, 0, 256, 128),        # lower walls
    "cool": (0, 128, 256, 256),      # ceiling and throat
    "blend": (0, 256, 256, 320),     # warm (fv 0) to cool (fv 1), the row where the wall turns into the vault
    "blend_u": (0, 384, 256, 512),   # warm (fu 1) to cool (fu 0), where the throat's funnel meets the room
    "crack": (0, 320, 256, 384),     # one whole ceiling crack, tapered ends
    "terrace": (256, 0, 512, 192),
    "sand": (256, 192, 384, 320),
    "stone": (384, 192, 512, 320),
    "niche": (256, 320, 384, 448),   # the lit back wall behind the Trophy Rock
    "throat": (384, 320, 512, 448),  # the mouth's throat: flat cool shade, no joints, so the opening reads dark
    "throat_deep": (256, 448, 384, 512),   # the throat's last 6.5 studs: its deep half in shadow (fv 0 is the deep end)
}
RESERVED = "x 384-511 of rows 448-511"   # cove props (07 6.6), not painted here
INSET = 2                           # pixels kept from a cell's edge (bilinear bleed)
BLOCKS = {0: "mid", 1: "light", 2: "dark", 3: "accent"}


def cell_uv(name, fu, fv):
    """(u, v) of the point (fu, fv) of a cell, fv = 0 at the cell's bottom."""
    x0, y0, x1, y1 = CELLS[name]
    fu, fv = min(1.0, max(0.0, fu)), min(1.0, max(0.0, fv))
    px = x0 + INSET + fu * (x1 - x0 - 2 * INSET)
    py = y1 - INSET - fv * (y1 - y0 - 2 * INSET)
    return px / SIZE, 1.0 - py / SIZE


# ---------------------------------------------------------------- painting (06 5.2: large soft shapes, no noise)

def _rgb(h):
    return np.array(common.hex_to_srgb(h), dtype=np.float32)


def _sm(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _mix(img, colour, t):
    t = np.clip(t, 0.0, 1.0)[..., None]
    return img * (1.0 - t) + _rgb(colour) * t


def _grid(w, h):
    """Cell coordinates: fu 0..1 left to right, fv 0..1 bottom to top (row 0 is the top)."""
    fu = (np.arange(w, dtype=np.float32) + 0.5) / w
    fv = 1.0 - (np.arange(h, dtype=np.float32) + 0.5) / h
    return np.meshgrid(fu, fv)


def _base(w, h, colour):
    return np.ones((h, w, 3), np.float32) * _rgb(colour)


def paint_wall(w, h, a=WARM_A, b=WARM_B):
    """Tileable sandstone: two broad flat blocks split by one large wavy joint, a short upright
    joint in the lower one; each block a single soft gradient (06 5.2: at most two per block).
    Periodic in both directions, so it repeats face to face without a seam."""
    U, V = _grid(w, h)
    img = _mix(_base(w, h, a), b, 0.15 - 0.15 * np.cos(2.0 * math.pi * U))   # near-flat: under 1 L* of drift, no stripes
    return img, np.zeros((h, w), np.int32)


def paint_cool(w, h):
    return paint_wall(w, h, COOL_A, COOL_B)


def paint_blend(w, h, along_u=False):
    warm, blk = paint_wall(w, h)
    cool, _ = paint_cool(w, h)
    U, V = _grid(w, h)
    t = _sm(0.0, 1.0, (1.0 - U) if along_u else V)[..., None]
    return warm * (1.0 - t) + cool * t, blk


def paint_sand(w, h):
    U, V = _grid(w, h)
    tau = 2.0 * math.pi
    img = _base(w, h, SAND)
    img = _mix(img, SAND_SHADE, 0.2 - 0.2 * np.cos(tau * U))
    return img, np.ones((h, w), np.int32)


def paint_terrace(w, h):
    """One shelf, bottom to top: cool foot, stone riser, the dark underside of the ledge above
    (the riser leans back under its lip), the worn light lip, the sand-dusted tread. Periodic along fu."""
    U, V = _grid(w, h)
    img = _mix(_base(w, h, WARM_A), WARM_B, _sm(0.3, 0.0, V))
    under = (V >= 0.24) & (V < 0.55)
    lip = (V >= 0.55) & (V < 0.70)
    tread = (V >= 0.70) & (V < 0.75)    # sand dusted along the lip; the back of the shelf is bare stone
    img[under] = _rgb(DARK)
    img[lip] = _rgb(LIP)
    sand, _ = paint_sand(w, h)
    img[tread] = sand[tread]
    block = np.where(under, 2, np.where(lip | tread, 1, 0))
    return img, block


def paint_crack(w, h):
    """One whole ceiling crack along fu on cool stone: a wide light core, thin dark rims, tapered ends."""
    U, V = _grid(w, h)
    tau = 2.0 * math.pi
    img = _base(w, h, COOL_A)
    c = 0.5 + 0.08 * np.sin(tau * U * 0.8 + 0.6)
    taper = _sm(0.0, 0.25, U) * _sm(1.0, 0.75, U)
    width = 0.17 * taper
    d = np.abs(V - c)
    img = _mix(img, COOL_B, _sm(0.45, 0.2, d))
    rim = (d < width + 0.045) & (taper > 0.05)
    core = d < width - 0.005
    img[rim] = _rgb(DARK)
    img[core] = _rgb(GLOW)
    block = np.where(core, 1, np.where(rim, 2, 0))
    return img, block


def paint_stone(w, h):
    """One arch stone: fu across it (grooves at both edges), fv from the lip (0) to where it meets
    the Rim wall (1). One soft gradient from the lit lip side; a wide worn light lip."""
    U, V = _grid(w, h)
    img = _mix(_base(w, h, WARM_A), WARM_B, _sm(0.2, 0.9, V))
    edge = np.minimum(U, 1.0 - U)
    groove = (edge < 0.05) | (V > 0.87)
    lip = (V < 0.33) & ~groove      # the inner half catches the light spilling out of the cove
    img[groove] = _rgb(DARK)
    img[lip] = _rgb(LIP)
    block = np.where(groove, 2, np.where(lip, 1, 0))
    return img, block


def paint_niche(w, h):
    """The lit niche behind the Trophy Rock: light falling on the back wall, brightest in the middle."""
    U, V = _grid(w, h)
    r = np.sqrt((U - 0.5) ** 2 + ((V - 0.45) * 1.2) ** 2)
    img = _mix(_base(w, h, SAND), LIP, _sm(0.55, 0.3, r))
    img = _mix(img, GLOW, _sm(0.32, 0.12, r))                 # the bright halo round the Trophy Rock
    return img, np.ones((h, w), np.int32)


def paint_throat(w, h):
    U, V = _grid(w, h)
    return _base(w, h, THROAT_INK), np.full((h, w), 2, np.int32)


def paint_throat_deep(w, h):
    U, V = _grid(w, h)
    return _mix(_base(w, h, THROAT_INK), THROAT_INK_DEEP, _sm(1.0, 0.3, V)), np.full((h, w), 2, np.int32)


PAINTERS = {"throat": paint_throat, "throat_deep": paint_throat_deep, "warm": paint_wall, "cool": paint_cool, "blend": paint_blend,
            "blend_u": lambda w, h: paint_blend(w, h, along_u=True), "crack": paint_crack,
            "terrace": paint_terrace, "sand": paint_sand, "stone": paint_stone, "niche": paint_niche}


def atlas():
    """(image rows top to bottom, sRGB 0..1, RGBA; block map, -1 where unpainted)."""
    img = np.zeros((SIZE, SIZE, 4), np.float32)
    img[..., :3] = _rgb(STONE)
    img[..., 3] = 1.0
    block = -np.ones((SIZE, SIZE), np.int32)
    for name, (x0, y0, x1, y1) in CELLS.items():
        rgb, blk = PAINTERS[name](x1 - x0, y1 - y0)
        img[y0:y1, x0:x1, :3] = rgb
        block[y0:y1, x0:x1] = blk
    return img, block


def sampler(img, block):
    def sample(u, v):
        r = min(SIZE - 1, max(0, int((1.0 - v) * SIZE)))
        c = min(SIZE - 1, max(0, int(u * SIZE)))
        return BLOCKS.get(int(block[r, c]), "none"), tuple(float(x) for x in img[r, c, :3])
    return sample


def texture(review_name):
    """Paints the atlas, writes the working copy for the preview material, returns what the spec needs."""
    img, block = atlas()
    work = os.path.join(common.review_dir(review_name), "%s_work.png" % ALBEDO)
    preyart.save_rgba(work, img)
    return img, block, work


def material(name, work):
    return preyart.material(name, work)


# ---------------------------------------------------------------- the mouth outline (shared by both meshes)

def hole(theta):
    """Point of the mouth opening at angle theta (radians, 0 = +X, pi/2 = top): a rounded arch
    36 x 28, its bottom flattened into a sill (superellipse 2.5 above, 6 below)."""
    c, s = math.cos(theta), math.sin(theta)
    q = 2.5 if s >= 0.0 else 6.0
    x = MOUTH_W / 2.0 * math.copysign(abs(c) ** (2.0 / q), c)
    z = MOUTH_H / 2.0 * math.copysign(abs(s) ** (2.0 / q), s)
    return x, z


def hole_normal(theta, d=1e-3):
    (x0, z0), (x1, z1) = hole(theta - d), hole(theta + d)
    tx, tz = x1 - x0, z1 - z0
    n = math.hypot(tx, tz) or 1.0
    return tz / n, -tx / n          # outward for a counter-clockwise curve


def resample(points, count):
    """`count` points spaced evenly by arc length along a closed polyline, from its first point."""
    pts = [Vector(p) for p in points]
    seg = [(pts[i] - pts[i - 1]).length for i in range(1, len(pts))] + [(pts[0] - pts[-1]).length]
    total = sum(seg)
    out, acc, i = [], 0.0, 0
    for k in range(count):
        target = total * k / count
        while acc + seg[i] < target:
            acc += seg[i]
            i += 1
        a, b = pts[i], pts[(i + 1) % len(pts)]
        f = (target - acc) / seg[i] if seg[i] > 0 else 0.0
        out.append(tuple(a.lerp(b, f)))
    return out


def hole_ring(count):
    """The opening as a ring from the bottom centre, right side up first (shell ring order)."""
    dense = [hole(1.5 * math.pi + 2.0 * math.pi * k / 720.0) for k in range(720)]
    return resample(dense, count)


# ---------------------------------------------------------------- chamber shape

PLAN_EXP, HEIGHT_EXP = 2.4, 4.0


def plan_half_width(y):
    t = min(1.0, abs((y - CH_YC) / (CH_L / 2.0)))
    return CH_W / 2.0 * (1.0 - t ** PLAN_EXP) ** (1.0 / PLAN_EXP)


def height_factor(y):
    t = min(1.0, abs((y - CH_YC) / (CH_L / 2.0)))
    return (1.0 - t ** HEIGHT_EXP) ** (1.0 / HEIGHT_EXP)


def chamber_section(y, count):
    """Cross-section of the cavity at y: a flat sand floor, near-upright lower walls and a domed
    ceiling (superellipse 6 below the shoulder, 2.4 above), as `count` points from the floor centre."""
    w, ev = plan_half_width(y), height_factor(y)
    zf, zt = FLOOR_Z, CEIL_Z
    zm = zf + 0.45 * (zt - zf)
    dense = []
    for k in range(720):
        a = 1.5 * math.pi + 2.0 * math.pi * k / 720.0
        c, s = math.cos(a), math.sin(a)
        q = 2.4 if s >= 0.0 else 6.0
        x = w * math.copysign(abs(c) ** (2.0 / q), c)
        z = zm + (zt - zm) * abs(s) ** (2.0 / q) if s >= 0.0 else zm - (zm - zf) * abs(s) ** (2.0 / q)
        dense.append((x, z * ev))
    return resample(dense, count)


# ---------------------------------------------------------------- perch terraces (03 6.10, 07 6.6)

ROW_Z = (-18.0, -10.5, -3.0, 4.5)     # tread heights of the four rows, bottom to top
TREAD = 4.0                           # tread depth
PERCH_Y = (52.0, 67.0, 82.0, 97.0, 112.0)   # five columns a side
TERRACE_Y = (40.0, 126.0)             # where the terraces leave and rejoin the wall
TAPER = 9.0                           # studs over which they grow out of the wall
SPECIMEN_LIFT = 3.0                   # loop centre above the tread
LOOP_RADIUS = 3.0                     # 03 6.10: a slow 6-stud loop


def terrace_amount(y):
    a = min(1.0, max(0.0, (y - TERRACE_Y[0]) / TAPER), max(0.0, (TERRACE_Y[1] - y) / TAPER))
    return a * a * (3.0 - 2.0 * a)


def perches():
    """The 40 perches. Slots run row by row from the bottom; in a row, front to back, right then
    left at each column, so slots 1 to 6 (the starting six, canon 11) are the six nearest the throat
    and the Home Stone. Rows 1 to 3 are slots 1 to 30 (Pearls), row 4 slots 31 to 40 (Bigger Cove)."""
    out, slot = [], 0
    for row, z in enumerate(ROW_Z, start=1):
        inset = (4 - row + 0.5) * TREAD
        for col, y in enumerate(PERCH_Y, start=1):
            for side, sx in (("right", 1.0), ("left", -1.0)):
                slot += 1
                x = sx * (plan_half_width(y) - inset)
                face = (-sx, 0.0, 0.0)
                out.append({"slot": slot, "row": row, "column": col, "side": side,
                            "group": "start" if slot <= 6 else ("pearls" if row <= 3 else "bigger_cove"),
                            "base": (x, y, z), "facing": face,
                            "loop_centre": (x - sx * 1.5, y, z + SPECIMEN_LIFT)})
    return out


# ---------------------------------------------------------------- generic lofts with per-face UVs

def loft(rings, cyclic_rings=False, pole_start=None, pole_end=None):
    """Quads between consecutive closed rings (equal length), optionally the ring sequence closed
    into a torus, or capped by pole points. Returns verts and faces as (indices, meta): meta is
    ("q", r, j) for the quad from ring r point j, ("p0", j) or ("p1", j) for pole triangles."""
    n = len(rings[0])
    verts = [tuple(p) for ring in rings for p in ring]
    faces = []
    last = len(rings) if cyclic_rings else len(rings) - 1
    for r in range(last):
        r2 = (r + 1) % len(rings)
        for j in range(n):
            j2 = (j + 1) % n
            faces.append(((r * n + j, r * n + j2, r2 * n + j2, r2 * n + j), ("q", r, j)))
    if pole_start is not None:
        verts.append(tuple(pole_start))
        p = len(verts) - 1
        for j in range(n):
            faces.append(((p, (j + 1) % n, j), ("p0", j)))
    if pole_end is not None:
        verts.append(tuple(pole_end))
        p = len(verts) - 1
        base = (len(rings) - 1) * n
        for j in range(n):
            faces.append(((base + j, base + (j + 1) % n, p), ("p1", j)))
    return verts, faces


def signed_volume(verts, faces):
    total = 0.0
    for f in faces:
        a = Vector(verts[f[0]])
        for k in range(1, len(f) - 1):
            total += a.dot(Vector(verts[f[k]]).cross(Vector(verts[f[k + 1]])))
    return total / 6.0


class Part:
    """A closed part: faces with a UV per corner and a hidden flag, oriented outward on add."""

    def __init__(self):
        self.verts, self.faces, self.uvs, self.hidden, self.front = [], [], [], [], set()

    def add(self, verts, faces, uvs, hidden, front_verts=()):
        idx = [f for f, _ in faces]
        flip = signed_volume(verts, idx) < 0.0
        base = len(self.verts)
        self.verts.extend(verts)
        for f, uv, h in zip(idx, uvs, hidden):
            if flip:
                f, uv = tuple(reversed(f)), list(reversed(uv))
            self.faces.append(tuple(base + i for i in f))
            self.uvs.append(uv)
            self.hidden.append(bool(h))
        self.front.update(base + i for i in front_verts)
        return flip

    def to_object(self, name, material, collection="GEO"):
        import template
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.verts, [], self.faces)
        mesh.update()
        mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
        col = mesh.color_attributes.new(common.COLOR_ATTR, 'BYTE_COLOR', 'CORNER')
        uv = mesh.uv_layers.new(name=common.UV_NAME)
        for poly in mesh.polygons:
            for c, li in enumerate(poly.loop_indices):
                col.data[li].color_srgb = (1.0, 1.0, 1.0, 1.0)
                uv.data[li].uv = self.uvs[poly.index][c]
        mesh.attributes.active_color_name = common.COLOR_ATTR
        mesh.attributes.default_color_name = common.COLOR_ATTR
        hid = mesh.attributes.new(HIDDEN_ATTR, 'INT', 'FACE')
        hid.data.foreach_set("value", [int(h) for h in self.hidden])
        tags = mesh.attributes.new(common.TAG_ATTR, 'INT', 'POINT')
        tags.data.foreach_set("value", [common.TAG_FRONT if i in self.front else 0 for i in range(len(self.verts))])
        mesh.materials.append(material)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        template.link(obj, collection)
        return obj


def fit_base(obj, extra=()):
    """Prop origin (06 6.1): the centre of the base. Moves the mesh (and `extra` objects) so the
    lowest point's centre is at the origin; returns the cove-frame position of the new origin."""
    vs = obj.data.vertices
    lo = min(v.co.z for v in vs)
    base = [v.co for v in vs if v.co.z <= lo + 1e-4]
    off = Vector(((min(p.x for p in base) + max(p.x for p in base)) / 2.0,
                  (min(p.y for p in base) + max(p.y for p in base)) / 2.0, lo))
    from mathutils import Matrix
    obj.data.transform(Matrix.Translation(-off))
    obj.data.update()
    for o in extra:
        o.data.transform(Matrix.Translation(-off))
        o.data.update()
    return off


# ---------------------------------------------------------------- checks on the visible surface

def _visible_triangles(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    hid = mesh.attributes.get(HIDDEN_ATTR)
    flags = [d.value for d in hid.data] if hid else [0] * len(mesh.polygons)
    return mesh, [t for t in mesh.loop_triangles if not flags[t.polygon_index]], flags


def visible_values(objs, sample):
    """06 4.1 on the surface a player can see (faces buried in the Rim rock left out), measured
    on the painted atlas: [{block, share, lstar, share_ok, lstar_ok, rule}]."""
    area, light = {}, {}
    for obj in objs:
        mesh, tris, _ = _visible_triangles(obj)
        uvs = mesh.uv_layers[common.UV_NAME].data
        for tri in tris:
            corners = [uvs[li].uv for li in tri.loops]
            for w in validate._SAMPLES:
                u = sum(c[0] * k for c, k in zip(corners, w))
                v = sum(c[1] * k for c, k in zip(corners, w))
                name, rgb = sample(u, v)
                area[name] = area.get(name, 0.0) + tri.area / len(validate._SAMPLES)
                light[name] = light.get(name, 0.0) + common.lstar_from_srgb(rgb) * tri.area / len(validate._SAMPLES)
    total = sum(a for n, a in area.items() if n in validate.BLOCK_RULES) or 1.0
    out = []
    for name in ("mid", "light", "dark", "accent"):
        if area.get(name, 0.0) <= 0.0:
            continue
        share, lstar = 100.0 * area[name] / total, light[name] / area[name]
        (s0, s1), (l0, l1) = validate.BLOCK_RULES[name]
        out.append({"block": name, "share": round(share, 1), "lstar": round(lstar, 1),
                    "share_ok": s0 <= share <= s1, "lstar_ok": l0 <= lstar <= l1,
                    "rule": "%d-%d%%, L* %d-%d" % (s0, s1, l0, l1)})
    return out


def visible_density(objs):
    """Pixels per stud over the visible faces (overlapping tile islands each count, 06 5.6)."""
    a3, auv = 0.0, 0.0
    for obj in objs:
        mesh, tris, _ = _visible_triangles(obj)
        uvs = mesh.uv_layers[common.UV_NAME].data
        for tri in tris:
            (u0, v0), (u1, v1), (u2, v2) = [tuple(uvs[li].uv) for li in tri.loops]
            auv += abs((u1 - u0) * (v2 - v0) - (u2 - u0) * (v1 - v0)) / 2.0
            a3 += tri.area
    return (auv * SIZE * SIZE / a3) ** 0.5 if a3 else 0.0


def surface_checks(objs, label, sample, waivers=None):
    """extra_checks entry: three values and texel density on the visible surface, and the
    atlas size (06 4.1, 5.6; texgen cove_atlas 512 px, 24 px/stud)."""
    waivers = waivers or {}

    def check(spec, report):
        blocks = visible_values(objs, sample)
        spec["value_blocks"] = blocks
        report.add(label, "value: measured on", True, "the painted %s, visible faces only (%s buried in the Rim left out)"
                   % (ALBEDO, ", ".join("%s %d" % (o.name, sum(1 for p in o.data.attributes[HIDDEN_ATTR].data if p.value)) for o in objs)))
        names = [b["block"] for b in blocks]
        report.add(label, "value: three blocks", all(n in names for n in ("mid", "light", "dark")), ", ".join(names))
        for b in blocks:
            report.add(label, "value: %s share" % b["block"], b["share_ok"], "%.1f%% of the visible surface, rule %s" % (b["share"], b["rule"]),
                       waiver=waivers.get("value: %s share" % b["block"]))
            report.add(label, "value: %s L*" % b["block"], b["lstar_ok"], "L* %.1f, rule %s" % (b["lstar"], b["rule"]))
        d = visible_density(objs)
        report.add(label, "texel density", d >= 24.0, "%.1f px/stud on the visible faces at %d px, target 24 or more (06 5.6 cove kit)" % (d, SIZE),
                   waiver=waivers.get("texel density"))
        report.add(label, "texture size", True, "%s %d x %d, one atlas for the whole cove kit (06 5.6)" % (ALBEDO, SIZE, SIZE))
        spec.setdefault("density", {})[label] = round(d, 1)
    return check


# ---------------------------------------------------------------- data table for the Studio assembly

A = ((-1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, 1.0, 0.0))    # Roblox = A @ Blender (animrbx.A)


def roblox(p):
    return [round(sum(A[i][k] * p[k] for k in range(3)), 3) for i in range(3)]


def write_table(fbx_name, content):
    """<stem>.cove.json beside the FBX in assets/export/meshes/ (generated, not committed)."""
    path = os.path.join(common.EXPORT_DIR, "meshes", fbx_name[:-4] + ".cove.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    table = {
        "frame": ("cove frame: origin at the centre of the mouth opening on the mouth plane, depth %d. "
                  "'roblox' values are in the cove's own CFrame: -Z (LookVector) points out of the cove to the "
                  "Reef, +Y up, +Z into the cove through the Rim. 'blender' values are the source axes." % DEPTH),
        "units": "studs",
        "source": "assets/source/cove (task S5-A3); sizes docs/03-content-catalog.md 6.7 and 6.10",
    }
    table.update(content)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(table, f, indent=1)
    print("[cove] %s" % os.path.relpath(path, common.REPO_DIR))
    return os.path.relpath(path, common.REPO_DIR)


def point(p, **extra):
    out = {"blender": [round(c, 3) for c in p], "roblox": roblox(p)}
    out.update(extra)
    return out


def mesh_entry(obj, origin):
    """Where a mesh sits in the cove frame: its FBX origin and its bounding-box centre (Studio
    places an imported MeshPart by its box centre)."""
    vs = [v.co + origin for v in obj.data.vertices]
    lo = Vector([min(v[i] for v in vs) for i in range(3)])
    hi = Vector([max(v[i] for v in vs) for i in range(3)])
    size = hi - lo
    return {"origin": point(tuple(origin)), "box_centre": point(tuple((lo + hi) / 2.0)),
            "box_size": {"blender": [round(c, 3) for c in size], "roblox": [round(size.x, 3), round(size.z, 3), round(size.y, 3)]}}


def volumes():
    """09 9.1: invisible tagged Blocks under Workspace.Volumes, attribute CoveIndex 1 to 24.
    CoveMouth runs from the mouth plane (02 11.1: the bank starts the tick a creature's centre
    crosses it) to the chamber; CoveInterior is the chamber's box. Both reach into rock where
    the walls curve, which nothing can enter."""
    return {
        "CoveMouth": {"shape": "Block", "centre": point((0.0, THROAT / 2.0, 0.0)),
                      "size": {"blender": [MOUTH_W, THROAT, MOUTH_H], "roblox": [MOUTH_W, MOUTH_H, THROAT]}},
        "CoveInterior": {"shape": "Block", "centre": point((0.0, CH_YC, (FLOOR_Z + CEIL_Z) / 2.0)),
                         "size": {"blender": [CH_W, CH_L, CH_H], "roblox": [CH_W, CH_H, CH_L]}},
    }
