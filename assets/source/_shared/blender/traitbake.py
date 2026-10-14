"""(tool) Trait overlay bake: docs/07-asset-list.md section 14.1, "Bake a trait master pattern onto
any family layout, home and fallback zones" (task S6-A1; 07 section 3 and docs/06-art-bible.md
sections 5.4, 5.5, 8.1 to 8.4).

A trait's **master** is one scripted function (assets/source/traits/<trait>/build.py) that says how
strongly each point of a creature's surface carries the trait, from body coordinates that every
family has, never from pixels of one layout:

    role   which kind of part the point is on: "body" (the main body volume), "tail" (another
           volume in the layout's body region: the tail fin), "fin" (a volume in the fins region),
           "eye" (eye and lid), "mouth" (the mouth interior), "teeth", "free"
    t      along the body: 0 at the nose, 1 at the main body's end (the tail root). On the tail
           fin, 0 at its root and 1 at its far tip
    h      up the side: -1 at the belly, +1 at the back, 0 halfway, at that station of the part
    rim    on fins and the tail fin: 0 where the part meets the body, 1 at its farthest point
    edge   on fins and the tail fin: 0 on the part's outline seen flat (its free edge, and its
           root), 1 at the point deepest inside it; 1 on every other part
    side   +1 or -1 (left and right halves share texels, 06 5.4)

and a zone, "home" or "fallback" (06 8.3 rule 1). `master(zone, S, frame)` returns the mask,
0 to 1, for the arrays in S; `frame` carries the body's measured stations and the eyes.

`bake(obj, layout, master, zone)` traces every texel of the family's base mesh (its UVs follow
the family layout, 06 5.4) back to its surface point, works out those coordinates, evaluates the
master at twice the texture size, filters down, and bleeds the islands by the margin of 06 5.5.
Because every species of a family follows the same layout stations (nose at U 0.05, tail root at
U 0.80, belly line at V 0.50, back at V 1.00), the one texture fits them all; `fits()` measures
that on a species' own mesh. Another family needs only its base mesh: the same master bakes onto
the Eel, Turtle or Squid layout, and its touch-up is a second master function if the review asks.

Outputs are 256 x 256 (06 5.6) greyscale masks written with the mask as alpha too ("LA"), so one
file serves the overlay shell (06 8.4 option B: `AlphaMode = Transparency`, tinted with the trait's
signature colour) and its emissive mask.
"""
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

import common
import texbake
import texgen

SIZE = 256                  # 06 5.6: trait overlays are 256 x 256 per trait per family
SUPERSAMPLE = 2
EMISSIVE_CAP = 0.15         # 06 8.3 rule 3: emissive overlays cover at most 15% of the body
PATTERN_CAP = 0.35          # 06 8.3 rule 3: pattern overlays at most 35%
ROLE_OF_REGION = {"body": "body", "fins": "fin", "eye": "eye", "mouth": "mouth", "teeth": "teeth", "free": "free"}
HIDDEN_ROLES = ("mouth", "teeth")      # inside the closed head: not visible surface (06 4.1 counts the visible)
STATIONS = 64


# ---------------------------------------------------------------- the body frame of one mesh

def region_at(layout, u, v):
    """Name of the layout region each (u, v) falls in (arrays), or "" outside every region."""
    u, v = np.asarray(u, dtype=float), np.asarray(v, dtype=float)
    out = np.full(u.shape, "", dtype=object)
    for name, (u0, v0, u1, v1) in texgen.FAMILY_LAYOUTS[layout].items():
        out = np.where((out == "") & (u >= u0) & (u <= u1) & (v >= v0) & (v <= v1), name, out)
    return out


def majority_region(layout, pts, size):
    """The region holding most of a part's UVs. A part may reach into a second region (the Fish
    body's lip seam carries the mouth interior into the mouth region); its texels there take that
    region's role (`Frame.texel_roles`)."""
    pts = np.asarray(pts, dtype=float)
    names = region_at(layout, pts[:, 0], pts[:, 1])
    names = names[names != ""]
    if not len(names):
        return None
    vals, counts = np.unique(names.astype(str), return_counts=True)
    return str(vals[np.argmax(counts)])


def _part_uvs(mesh, comp):
    uvl = mesh.uv_layers[common.UV_NAME].data
    out = {}
    for poly in mesh.polygons:
        c = comp[poly.vertices[0]]
        out.setdefault(c, []).extend(tuple(uvl[li].uv) for li in poly.loop_indices)
    return out


def _stations(co, nbins=STATIONS):
    """Top, bottom and half width of a set of points, per station along y, smoothed and filled."""
    y0, y1 = co[:, 1].min(), co[:, 1].max()
    edges = np.linspace(y0, y1, nbins + 1)
    mids = (edges[:-1] + edges[1:]) / 2.0
    top, bot, hw = np.full(nbins, np.nan), np.full(nbins, np.nan), np.full(nbins, np.nan)
    idx = np.clip(np.searchsorted(edges, co[:, 1], side="right") - 1, 0, nbins - 1)
    for k in range(nbins):
        sel = idx == k
        if sel.any():
            top[k], bot[k], hw[k] = co[sel, 2].max(), co[sel, 2].min(), np.abs(co[sel, 0]).max()
    ok = ~np.isnan(top)
    fill = lambda a: np.interp(mids, mids[ok], a[ok])
    return {"y": mids, "top": fill(top), "bot": fill(bot), "hw": fill(hw), "y0": float(y0), "y1": float(y1)}


EDGE_GRID = 96


def _outline_grid(co, polys, n=EDGE_GRID):
    """A part flattened onto its own plane (its two longest principal axes): which cells of an
    n x n grid it covers, and each covered cell's chamfer distance to the outline, in cells."""
    idx = sorted({i for p in polys for i in p})
    pts = co[idx]
    centre = pts.mean(0)
    _, _, vt = np.linalg.svd(pts - centre, full_matrices=False)
    axes = vt[:2]
    q = (co - centre) @ axes.T
    lo, hi = q[idx].min(0), q[idx].max(0)
    cell = float((hi - lo).max()) / (n - 6)
    lo = lo - 3.0 * cell
    filled = np.zeros((n, n), dtype=bool)
    gx, gy = np.meshgrid(np.arange(n) + 0.5, np.arange(n) + 0.5, indexing="ij")
    for p in polys:
        for k in range(1, len(p) - 1):
            a, b, c = ((q[v] - lo) / cell for v in (p[0], p[k], p[k + 1]))
            den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(den) < 1e-12:
                continue
            w0 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / den
            w1 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / den
            filled |= (w0 >= -1e-3) & (w1 >= -1e-3) & (1.0 - w0 - w1 >= -1e-3)
    big = 1e9
    d = np.where(filled, big, 0.0)
    for i in range(n):              # chamfer 3-4, forward then back (distances in thirds of a cell)
        for j in range(n):
            if d[i, j]:
                m = d[i, j]
                if i: m = min(m, d[i - 1, j] + 3, d[i - 1, j - 1] + 4 if j else big, d[i - 1, j + 1] + 4 if j < n - 1 else big)
                if j: m = min(m, d[i, j - 1] + 3)
                d[i, j] = m
    for i in range(n - 1, -1, -1):
        for j in range(n - 1, -1, -1):
            if d[i, j]:
                m = d[i, j]
                if i < n - 1: m = min(m, d[i + 1, j] + 3, d[i + 1, j + 1] + 4 if j < n - 1 else big, d[i + 1, j - 1] + 4 if j else big)
                if j < n - 1: m = min(m, d[i, j + 1] + 3)
                d[i, j] = m
    d = np.where(filled, np.maximum(d / 3.0 - 0.5, 0.0), 0.0)
    return {"centre": centre, "axes": axes, "lo": lo, "cell": cell, "dist": d, "dmax": float(d.max())}


def _at(st, key, y):
    return np.interp(y, st["y"], st[key])


class Frame:
    """What the bake measures on a family mesh: its parts, their roles, the main body's stations,
    the tail fin's stations, each fin's rim distance and the eyes in body coordinates."""

    def __init__(self, obj, layout, size=SIZE):
        mesh = obj.data
        self.obj, self.layout, self.size = obj, layout, size
        self.comp = texbake.components(mesh)
        co = np.array([v.co[:] for v in mesh.vertices])
        self.co = co
        uvs = _part_uvs(mesh, self.comp)
        self.region = {c: majority_region(layout, pts, size) for c, pts in uvs.items()}
        area = {}
        for poly in mesh.polygons:
            c = self.comp[poly.vertices[0]]
            area[c] = area.get(c, 0.0) + poly.area
        self.area = area
        body_parts = [c for c, r in self.region.items() if r == "body"]
        if not body_parts:
            raise ValueError("%s has no part in the %s layout's body region" % (obj.name, layout))
        self.main = max(body_parts, key=lambda c: area[c])
        self.role = {}
        for c, r in self.region.items():
            role = ROLE_OF_REGION.get(r, "free") if r else "free"
            if r == "body" and c != self.main:
                role = "tail"
            self.role[c] = role
        self.body = _stations(co[self.comp == self.main])
        self.nose, self.root = self.body["y0"], self.body["y1"]
        tails = [c for c, role in self.role.items() if role == "tail"]
        self.tail = {c: _stations(co[self.comp == c], 24) for c in tails}
        # Rim: distance of every appendage vertex from the main body's surface, 0..1 per part.
        tris = [tuple(p.vertices) for p in mesh.polygons if self.comp[p.vertices[0]] == self.main]
        tree = BVHTree.FromPolygons([Vector(v) for v in co], tris)
        self.rim = np.zeros(len(co))
        for c, role in self.role.items():
            if role not in ("tail", "fin"):
                continue
            sel = np.nonzero(self.comp == c)[0]
            d = np.array([tree.find_nearest(Vector(co[i]))[3] or 0.0 for i in sel])
            self.rim[sel] = d / max(d.max(), 1e-9)
        # Edge: for the same parts, how far a point lies inside the part's own outline, seen
        # flat (0 on the outline, 1 at the point deepest inside), so a master can light a fin's
        # whole free edge and not only its far tip (rim).
        self.edge = {}
        for c, role in self.role.items():
            if role in ("tail", "fin"):
                tris = [tuple(p.vertices) for p in mesh.polygons if self.comp[p.vertices[0]] == c]
                self.edge[c] = _outline_grid(co, tris)
        self.eyes = []
        for c, role in self.role.items():
            if role == "eye" and self.area[c] > 0.0:
                pts = co[self.comp == c]
                tt, hh = self.body_coords(pts)
                self.eyes.append({"t": float(tt.mean()), "h": float((hh.max() + hh.min()) / 2.0),
                                  "r_h": float((hh.max() - hh.min()) / 2.0), "r_t": float((tt.max() - tt.min()) / 2.0),
                                  "area": float(self.area[c])})

    def edge_at(self, c, P):
        """Edge distance (0 on the part's outline, 1 deepest inside) of points P on part c."""
        g = self.edge[c]
        q = (np.asarray(P) - g["centre"]) @ g["axes"].T
        f = (q - g["lo"]) / g["cell"] - 0.5
        n = g["dist"].shape[0]
        i0 = np.clip(np.floor(f).astype(int), 0, n - 2)
        w = np.clip(f - i0, 0.0, 1.0)
        d = g["dist"]
        a, b = i0[:, 0], i0[:, 1]
        val = (d[a, b] * (1 - w[:, 0]) * (1 - w[:, 1]) + d[a + 1, b] * w[:, 0] * (1 - w[:, 1])
               + d[a, b + 1] * (1 - w[:, 0]) * w[:, 1] + d[a + 1, b + 1] * w[:, 0] * w[:, 1])
        return np.clip(val / max(g["dmax"], 1e-9), 0.0, 1.0)

    def texel_roles(self, part, u, v):
        """Role of each texel: its part's role, except where the texel lies in the mouth or teeth
        region (the inside of the mouth, joined to the body at the lip)."""
        roles = np.array([self.role.get(int(c), "free") for c in part], dtype=object)
        reg = region_at(self.layout, u, v)
        for r in ("mouth", "teeth"):
            roles = np.where(reg == r, ROLE_OF_REGION[r], roles)
        return roles

    def body_coords(self, P):
        """t along the body and h around it: h = 1 - 2 a / pi, where a is the angle round the
        section from the back line (0) to the belly line (pi), measured on the section's own half
        width and half depth at that station. 0 is the middle of the flank. Measured round the
        section, not straight up, so h follows a family's loft (its UV V) on every species."""
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        t = (y - self.nose) / (self.root - self.nose)
        top, bot = _at(self.body, "top", y), _at(self.body, "bot", y)
        hw = np.maximum(_at(self.body, "hw", y), 1e-6)
        half = np.maximum((top - bot) / 2.0, 1e-6)
        a = np.arctan2(np.abs(x) / hw, (z - (top + bot) / 2.0) / half)
        return t, 1.0 - 2.0 * a / np.pi

    def tail_coords(self, c, P):
        st = self.tail[c]
        y, z = P[:, 1], P[:, 2]
        t = (y - st["y0"]) / max(st["y1"] - st["y0"], 1e-6)
        top, bot = _at(st, "top", y), _at(st, "bot", y)
        h = (z - (top + bot) / 2.0) / np.maximum((top - bot) / 2.0, 1e-6)
        return t, np.clip(h, -1.2, 1.2)

    def length(self):
        return self.root - self.nose

    def depth(self, t):
        y = self.nose + np.asarray(t) * (self.root - self.nose)
        return _at(self.body, "top", y) - _at(self.body, "bot", y)

    def summary(self):
        roles = {}
        for c, role in self.role.items():
            roles.setdefault(role, []).append(c)
        return {"parts": len(self.role), "roles": {k: len(v) for k, v in roles.items()},
                "body": "y %.3f to %.3f" % (self.nose, self.root), "eyes": self.eyes}


# ---------------------------------------------------------------- texel samples

def samples(frame, P, part, rim, side, u=None, v=None):
    """The master's inputs (S) for points P on parts `part` (at texture coordinates u, v)."""
    n = len(P)
    roles = frame.texel_roles(part, u, v) if u is not None else np.array([frame.role.get(int(c), "free") for c in part], dtype=object)
    S = {"role": roles,
         "t": np.zeros(n), "h": np.zeros(n), "rim": rim, "edge": np.ones(n), "side": side, "P": P, "part": part}
    for c in frame.edge:
        sel = part == c
        if sel.any():
            S["edge"][sel] = frame.edge_at(c, P[sel])
    body = S["role"] == "body"
    if body.any():
        S["t"][body], S["h"][body] = frame.body_coords(P[body])
    for c in frame.tail:
        sel = part == c
        if sel.any():
            S["t"][sel], S["h"][sel] = frame.tail_coords(c, P[sel])
    return S


def bake(obj, layout, master, zone, size=SIZE, frame=None):
    """The mask of `master` in `zone` on `obj`'s UVs, size x size (row 0 at V 0), filtered from
    twice the size and bled by the margin of 06 5.5; and the frame it used."""
    frame = frame or Frame(obj, layout, size)
    big = size * SUPERSAMPLE
    r = texbake.rasterise(obj, big, vattrs=frame.rim[:, None])
    filled = r["filled"]
    P, part = r["P"][filled], r["part"][filled]
    rows, cols = np.nonzero(filled)
    S = samples(frame, P, part, r["attrs"][filled][:, 0], np.sign(P[:, 0] + 1e-9), (cols + 0.5) / big, (rows + 0.5) / big)
    m = np.zeros((big, big))
    m[filled] = np.clip(master(zone, S, frame), 0.0, 1.0)
    small = texbake.downsample(m, SUPERSAMPLE)
    cover = texbake.downsample(filled.astype(float), SUPERSAMPLE)
    # Edge texels half on an island: their mean is over the island only, so the edge does not fade.
    small = np.where(cover > 0, small / np.maximum(cover, 1e-6), 0.0)
    small = texbake.dilate(small, cover > 0, texgen.margin_px(size) + 2)
    return np.clip(small, 0.0, 1.0), frame


# ---------------------------------------------------------------- measuring a mask on a mesh

_SAMPLES = [(1 / 3, 1 / 3, 1 / 3)] + [tuple(0.6 if i == k else 0.2 for i in range(3)) for k in range(3)] \
    + [tuple(0.1 if i == k else 0.45 for i in range(3)) for k in range(3)]


def sample_mask(mask, u, v):
    size = mask.shape[0]
    r = np.clip((np.asarray(v) * size).astype(int), 0, size - 1)
    c = np.clip((np.asarray(u) * size).astype(int), 0, size - 1)
    return mask[r, c]


def coverage(obj, mask, frame=None):
    """Share of the visible surface the mask lights (mask 0.5 or more), the mask's mean over it,
    and the lit share per role. Visible means every part but the mouth interior and teeth (with
    no frame, every part counts)."""
    mesh = obj.data
    mesh.calc_loop_triangles()
    uvl = mesh.uv_layers[common.UV_NAME].data
    total, lit, mean = 0.0, 0.0, 0.0
    per_role = {}
    for tri in mesh.loop_triangles:
        uv = np.array([uvl[li].uv[:] for li in tri.loops])
        if frame:
            cu, cv = uv.mean(0)
            role = frame.texel_roles([frame.comp[tri.vertices[0]]], np.array([cu]), np.array([cv]))[0]
        else:
            role = "all"
        if role in HIDDEN_ROLES:
            continue
        pts = np.array(_SAMPLES) @ uv
        m = sample_mask(mask, pts[:, 0], pts[:, 1])
        a = tri.area
        total += a
        lit += a * float((m >= 0.5).mean())
        mean += a * float(m.mean())
        rr = per_role.setdefault(role, [0.0, 0.0])
        rr[0] += a
        rr[1] += a * float((m >= 0.5).mean())
    total = max(total, 1e-9)
    return {"lit_share": lit / total, "mean": mean / total,
            "by_role": {k: round(v[1] / max(v[0], 1e-9), 4) for k, v in per_role.items()},
            "lit_area_by_role": {k: round(v[1] / total, 4) for k, v in per_role.items()}}


FIT_TOLERANCE = 2           # texels: a lit texel matches if the other mask is lit within this distance


def _grow(mask, px):
    out = mask.copy()
    for _ in range(px):
        g = out.copy()
        g[1:, :] |= out[:-1, :]
        g[:-1, :] |= out[1:, :]
        g[:, 1:] |= out[:, :-1]
        g[:, :-1] |= out[:, 1:]
        out = g
    return out


def fits(base_mask, obj, layout, master, zone, level=0.5):
    """How well the family texture fits another species of the family: the master baked on the
    species' own mesh against the base-mesh texture, over the texels the species uses. `match`:
    the share of lit texels (mask `level` or more) of each that the other lights within
    FIT_TOLERANCE texels (2 texels of 256: under 1% of the layout), overall and per role; the
    strict IoU and the mean absolute difference are reported beside it."""
    own, frame = bake(obj, layout, master, zone)
    size = base_mask.shape[0]
    r = texbake.rasterise(obj, size)
    used = r["filled"]
    A, B = (base_mask >= level) & used, (own >= level) & used
    Ag, Bg = _grow(A, FIT_TOLERANCE), _grow(B, FIT_TOLERANCE)
    rows, cols = np.nonzero(used)
    roles_map = np.full(used.shape, "", dtype=object)
    roles_map[used] = frame.texel_roles(r["part"][used], (cols + 0.5) / size, (rows + 0.5) / size)

    def match(sel):
        n = (A & sel).sum() + (B & sel).sum()
        return float(((A & Bg & sel).sum() + (B & Ag & sel).sum()) / n) if n else 1.0

    by_role = {role: round(match(roles_map == role), 3) for role in sorted(set(roles_map[used].tolist()))
               if ((A | B) & (roles_map == role)).any()}
    union = (A | B).sum()
    return {"match": match(used), "match_by_role": by_role, "iou": float((A & B).sum() / union) if union else 1.0,
            "mean_abs": float(np.abs(base_mask[used] - own[used]).mean()), "own": own, "frame": frame}


def outside_layout(mask, layout, size=SIZE):
    """Texels lit (0.05 or more) outside every region of the layout, which no species can show."""
    lit = mask >= 0.05
    inside = np.zeros_like(lit)
    for rect in texgen.FAMILY_LAYOUTS[layout].values():
        u0, v0, u1, v1 = rect
        inside[int(round(v0 * size)):int(round(v1 * size)), int(round(u0 * size)):int(round(u1 * size))] = True
    return int((lit & ~inside).sum())


# ---------------------------------------------------------------- files and previews

def save(path, mask):
    """06 5.1: an 8-bit greyscale mask; written as greyscale with the same mask as alpha (LA), so
    the overlay shell can use the one file for its colour map (tinted) and its emissive mask."""
    la = np.stack([mask, mask], -1)
    return texbake.save_png(path, la, mode="LA")


def overlay_shell(body, name, mask, colour_hex, offset_share=0.005, strength=1.8, collection="PREVIEW"):
    """Preview of 06 8.4 option B: a copy of `body` pushed out along its normals by 0.5% of its
    length, drawn with the trait colour, see-through where the mask is 0 and emissive by the mask.
    Shares the body's skin and parent, so it follows a pose as the template's shell does."""
    shell = body.copy()
    shell.data = body.data.copy()
    shell.name = shell.data.name = name
    bpy.data.collections[collection].objects.link(shell)
    d = offset_share * max(body.dimensions)
    mesh = shell.data
    nrm = [Vector(v.normal) for v in mesh.vertices]
    for v, n in zip(mesh.vertices, nrm):
        v.co = v.co + n * d
    mesh.update()
    img = texbake.blender_image("IMG_" + name, mask, colorspace="Non-Color")
    mat = bpy.data.materials.new("MAT_" + name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = 'Linear'
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = (*common.hex_to_linear(colour_hex), 1.0)
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = 'MULTIPLY'
    mul.inputs[1].default_value = strength
    nt.links.new(tex.outputs["Color"], mul.inputs[0])
    nt.links.new(mul.outputs[0], emit.inputs["Strength"])
    clear = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(tex.outputs["Color"], mix.inputs["Fac"])
    nt.links.new(clear.outputs["BSDF"], mix.inputs[1])
    nt.links.new(emit.outputs["Emission"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    for attr, value in (("surface_render_method", 'BLENDED'), ("blend_method", 'BLEND')):
        if hasattr(mat, attr):
            try:
                setattr(mat, attr, value)
            except Exception:
                pass
    mesh.materials.clear()
    mesh.materials.append(mat)
    return shell


def layout_picture(masks, layout, size=SIZE, colour_hex="#FFE98A"):
    """An RGB picture (row 0 at V 0) of masks side by side over the layout's regions, for the sheet."""
    ink = texbake.hex_rgb(common.colour("ui.ink"))
    panel = texbake.hex_rgb(common.colour("water.dropoff_deep.fog"))     # dark, so the glow reads
    glow = texbake.hex_rgb(colour_hex)
    edge = texbake.hex_rgb(common.colour("ui.disabled"))
    gap = 8
    w = len(masks) * size + (len(masks) - 1) * gap
    pic = np.ones((size, w, 3)) * texbake.hex_rgb(common.colour("ui.panel"))
    for i, m in enumerate(masks):
        x0 = i * (size + gap)
        tile = np.ones((size, size, 3)) * panel
        tile = tile * (1.0 - m[..., None]) + glow * m[..., None]
        for rect in texgen.FAMILY_LAYOUTS[layout].values():
            u0, v0, u1, v1 = (int(round(c * (size - 1))) for c in rect)
            tile[v0:v1 + 1, u0] = edge
            tile[v0:v1 + 1, u1] = edge
            tile[v0, u0:u1 + 1] = edge
            tile[v1, u0:u1 + 1] = edge
        pic[:, x0:x0 + size] = tile
    return pic


def smooth_band(x, half, soft):
    """1 inside |x| <= half, falling to 0 at half + soft (a painted edge, not a hard step)."""
    return 1.0 - texbake.smoothstep(half, half + soft, np.abs(x))

