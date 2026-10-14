"""The hatch egg's shape and paint (task S6-A2, docs/13-sprint-plan.md Sprint 6; docs/07-asset-list.md
section 2.0 row M_Prop_HatchEgg: "the pale egg a new Fry hatches from ... whole egg and two cracked
halves", 200 tris, on T_Cove_Alb; the beat is 04 3.6 B1).

Shared by the egg's build (cove/hatchegg/build.py), by coveart.py (the egg's two cells of the cove
atlas T_Cove_Alb, so every build that writes the atlas writes the same one) and by the Minnow build
(its A_Fish_Hatch review strip shows the clip with the egg). Plain numpy and Blender mesh data.

Size (tune; chapter 14 section 5.1 row "Hatch egg size"): 2.6 across and 3.3 tall, so the tier-1
Minnow (3.0 long, 1.365 tall, 06 6.2) fits inside it squashed and curled (A_Fish_Hatch frames 0-15),
and its cup (the bottom half, rim at most 2.21) clears the Fry's belly once it has risen out.
The egg's axis is +Z, its origin the bottom pole (06 6.1: a prop's origin is the centre of its base).
"""
import math
import os

import numpy as np

W, H = 2.6, 3.3                  # studs across and tall (tune)
EGGNESS = 0.12                   # how much wider the lower half is than the upper (0: an ellipsoid)
SEGS = 12                        # points round every ring
SECTORS = 3                      # the paint repeats three times round the egg (overlapping UVs, 06 5.6 density)
RINGS = 8                        # whole egg: rings every 20 degrees of the profile angle from pole to pole
CRACK = 100.0                    # profile angle of the crack (degrees from the bottom pole): rim at about 1.76
TOOTH = 10.0                     # the zigzag: crack points alternate CRACK +- TOOTH (six teeth round the egg)
SHELL = 0.07                     # shell thickness at the crack (studs)
CUP_RINGS = (40.0, 60.0, 80.0)   # the bottom half's outer rings below the crack
CAP_RINGS = (140.0,)             # the top half's outer ring above the crack
CELLS = {"shell": "egg_shell", "inside": "egg_inside", "edge": "egg_edge"}   # coveart.CELLS of T_Cove_Alb
FRY_IN_EGG = 1.6                # the curled Fry's centre above the egg's base, A_Fish_Hatch frames 0-15 (tune)


def fry_above_base():
    """Where the code puts the Fry's model for the whole hatch, studs above the egg's base: the curled
    Fry's place plus the depth A_Fish_Hatch lowers the body by (rigs.HATCH_DEPTH). 3.10 (tune)."""
    import rigs
    return FRY_IN_EGG + rigs.HATCH_DEPTH

# Colours (06 4.1 three values, 4.3: shadows toward blue-violet, lights toward yellow). Pale lilac,
# so the tangerine Minnow (the warmest thing in the Nursery, 06 4.3) pops out of it; no reserved hue (4.5).
MID_LOW = "#C9B3E2"     # lower shell (mid, L* 76)
MID_HIGH = "#D0BDE6"    # upper shell, its one gradient (mid, L* 79)
CROWN = "#FFF4E2"       # the lit crown, warm cream (light, L* 97); also the broken shell's edge
SPOT = "#5E4058"        # soft plum freckles: the cove kit's dark (coveart.DARK, L* 31)
INSIDE = "#523A57"      # inside of the shell, in shadow (dark, L* 28)
LIGHT_SHARE = 0.25      # share of the egg's area the crown takes (06 4.1 light: 20 to 30%)
DARK_SHARE = 0.125      # share the freckles take (06 4.1 dark: 10 to 15%)
# Freckles per paint sector: (fu round the sector 0..1, fv up the egg 0..1, radius as a share of the
# biggest); sized together so they cover DARK_SHARE of the surface.
FRECKLES = ((0.20, 0.50, 1.0), (0.66, 0.36, 0.78), (0.58, 0.66, 0.62), (0.93, 0.25, 0.52), (0.40, 0.80, 0.42),
            (0.03, 0.62, 0.5))


def _radius_raw(t):
    return math.sin(t) * (1.0 + EGGNESS * math.cos(t))


_R = (W / 2.0) / max(_radius_raw(math.radians(a / 10.0)) for a in range(0, 1801))


def profile(deg):
    """(r, z) of the outer surface at profile angle `deg` (0 bottom pole, 180 top pole)."""
    t = math.radians(deg)
    return _R * _radius_raw(t), H / 2.0 * (1.0 - math.cos(t))


def normal(deg):
    """Outward unit normal (nr, nz) of the profile at `deg`."""
    a, b = profile(deg - 0.05), profile(deg + 0.05)
    dr, dz = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dr, dz)
    return dz / n, -dr / n


def _arc_table(n=1801):
    deg = np.linspace(0.0, 180.0, n)
    pts = np.array([profile(d) for d in deg])
    seg = np.hypot(np.diff(pts[:, 0]), np.diff(pts[:, 1]))
    s = np.concatenate([[0.0], np.cumsum(seg)])
    return deg, s, pts[:, 0]


_DEG, _S, _RAD = _arc_table()
ARC = float(_S[-1])                # meridian length, pole to pole


def fv_of(deg):
    """Paint row (0 bottom pole, 1 top pole) of profile angle `deg`: arc length along the meridian."""
    return float(np.interp(deg, _DEG, _S)) / ARC


def point(deg, phi):
    r, z = profile(deg)
    return (r * math.cos(phi), r * math.sin(phi), z)


def phi(j):
    """Ring point j's angle; point 0 faces -Y (06 6.1 front), the side the Fry faces on hatching."""
    return -math.pi / 2.0 + 2.0 * math.pi * j / SEGS


# ---------------------------------------------------------------- paint (the two atlas cells, coveart.CELLS)

def _hex(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def _sm(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _cell_grid(w, h, inset):
    """fu, fv of every pixel in the mapped part of a cell (coveart.cell_uv's inset), fv 0 at the bottom."""
    fu = (np.arange(w, dtype=np.float64) + 0.5 - inset) / (w - 2 * inset)
    fv = 1.0 - (np.arange(h, dtype=np.float64) + 0.5 - inset) / (h - 2 * inset)
    return np.meshgrid(fu, fv)


def _crown_fv():
    """The paint row above which LIGHT_SHARE of the egg's area lies (area by arc length times radius)."""
    da = np.concatenate([[0.0], np.cumsum(np.diff(_S) * 0.5 * (_RAD[1:] + _RAD[:-1]))])
    above = 1.0 - da / da[-1]
    return float(np.interp(LIGHT_SHARE, above[::-1], (_S / ARC)[::-1]))


def _freckle_distance(fu, fv, scale):
    """Each pixel's distance in studs to the nearest freckle edge (negative inside), measured on the
    egg's surface: round the egg by the ring's circumference at that row, up it by arc length."""
    sv = np.clip(fv, 0.0, 1.0) * ARC
    ring = 2.0 * math.pi * np.interp(sv, _S, _RAD) / SECTORS      # studs one sector spans at that row
    d = np.full(fu.shape, 1e9)
    for cu, cv, rel in FRECKLES:
        du = (fu - cu + 0.5) % 1.0 - 0.5                             # tileable round the egg
        dist = np.hypot(du * ring, (fv - cv) * ARC) - rel * scale
        d = np.minimum(d, dist)
    return d


def _freckle_scale():
    """Biggest freckle's radius (studs) that covers DARK_SHARE of the surface, by bisection."""
    fu, fv = np.meshgrid(np.linspace(0.0, 1.0, 240, endpoint=False) + 0.5 / 240, np.linspace(0.0, 1.0, 400) )
    weight = np.interp(fv * ARC, _S, _RAD)
    lo, hi = 0.02, 1.0
    for _ in range(40):
        mid = 0.5 * (lo + hi)
        share = float((weight * (_freckle_distance(fu, fv, mid) < 0.0)).sum() / weight.sum())
        lo, hi = (mid, hi) if share < DARK_SHARE else (lo, mid)
    return 0.5 * (lo + hi)


def paint_shell(w, h, inset):
    """The outside of the egg, one paint sector: fu round the sector, fv from the bottom pole (0) to
    the top (1). The shell is one soft gradient, lower to upper; the crown is lit warm cream with a
    wide soft edge; plum freckles, round on the egg, edged over a pixel. Block map: 0 mid, 1 light, 2 dark."""
    fu, fv = _cell_grid(w, h, inset)
    crown = _crown_fv()
    t = _sm(0.15, crown, fv)[..., None]
    img = _hex(MID_LOW) * (1.0 - t) + _hex(MID_HIGH) * t
    lit = _sm(crown - 0.05, crown + 0.05, fv)
    img = img * (1.0 - lit[..., None]) + _hex(CROWN) * lit[..., None]
    d = _freckle_distance(fu, fv, _freckle_scale())
    px = ARC / (h - 2 * inset)                                        # studs per pixel up the egg
    ink = np.clip(0.5 - d / px, 0.0, 1.0)[..., None]
    img = img * (1.0 - ink) + _hex(SPOT) * ink
    block = np.where(ink[..., 0] > 0.5, 2, np.where(lit > 0.5, 1, 0)).astype(np.int32)
    return img.astype(np.float32), block


def paint_inside(w, h):
    """Inside of the broken shell: one flat shadow colour, the dark block."""
    return np.ones((h, w, 3), np.float32) * _hex(INSIDE), np.full((h, w), 2, np.int32)


def paint_edge(w, h):
    """The broken edge of the shell: catches the light (light block)."""
    return np.ones((h, w, 3), np.float32) * _hex(CROWN), np.full((h, w), 1, np.int32)


# ---------------------------------------------------------------- meshes (coveart.Part, coveart.loft)

def _ring(deg_of_j, inset=0.0):
    """Ring points; `deg_of_j(j)` is each point's profile angle; `inset` moves them in along the normal."""
    out = []
    for j in range(SEGS):
        d = deg_of_j(j)
        r, z = profile(d)
        nr, nz = normal(d)
        r, z = r - inset * nr, z - inset * nz
        out.append((r * math.cos(phi(j)), r * math.sin(phi(j)), z))
    return out


def _crack_deg(j):
    return CRACK + (TOOTH if j % 2 == 0 else -TOOTH)


def build_parts(ca, cells):
    """The three closed meshes as coveart.Part: whole egg, top half (the cap), bottom half (the cup).
    `cells` maps "shell", "inside", "edge" to coveart cell names. Front points (tagged for the facing
    check) are the ring points facing -Y."""
    k = SEGS // SECTORS
    uv = lambda cell, fu, fv: ca.cell_uv(cells[cell], fu, fv)

    def outer_corner(deg, j_corner, j_face):
        # fu runs 0..1 over the k segments of a sector; the corner after a sector's last segment is 1, not 0
        s = j_face % k
        fu = (s + (1 if (j_corner - j_face) % SEGS == 1 else 0)) / float(k)
        return uv("shell", fu, fv_of(deg))

    def build(rings, kinds, pole_start, pole_end, pole_kinds):
        """rings: [(points, degs, "outer" or "inner")], kinds[r]: the band between ring r and r+1 ("outer", "edge",
        "inside"); pole_kinds: the kind of the fans at each end."""
        verts, faces = ca.loft([ring[0] for ring in rings], pole_start=pole_start[0], pole_end=pole_end[0])
        n = SEGS
        uvs, hidden = [], []
        for idx, meta in faces:
            if meta[0] == "q":
                r, j = meta[1], meta[2]
                kind = kinds[r]
                corners = [(r, j), (r, (j + 1) % n), (r + 1, (j + 1) % n), (r + 1, j)]
            else:
                kind = pole_kinds[0] if meta[0] == "p0" else pole_kinds[1]
                j = meta[1]
                rr = 0 if meta[0] == "p0" else len(rings) - 1
                corners = [None, (rr, (j + 1) % n), (rr, j)] if meta[0] == "p0" else [(rr, j), (rr, (j + 1) % n), None]
            face_uv = []
            for i, c in enumerate(corners):
                if kind == "outer":
                    if c is None:
                        deg = pole_start[1] if meta[0] == "p0" else pole_end[1]
                        face_uv.append(uv("shell", ((j % k) + 0.5) / k, fv_of(deg)))
                    else:
                        face_uv.append(outer_corner(rings[c[0]][1][c[1]], c[1], j))
                elif kind == "edge":
                    jj = c[1] if (c[1] != 0 or j != n - 1) else n
                    face_uv.append(uv("edge", jj / float(n), 0.0 if rings[c[0]][2] == "outer" else 1.0))
                else:
                    p = verts[idx[i]]
                    face_uv.append(uv("inside", 0.5 + p[0] / W, 0.5 + p[1] / W))
            uvs.append(face_uv)
            hidden.append(False)
        return verts, faces, uvs, hidden

    def outer_ring(deg_of_j):
        return (_ring(deg_of_j), [deg_of_j(j) for j in range(SEGS)], "outer")

    def inner_ring(deg_of_j):
        return (_ring(deg_of_j, inset=SHELL), [deg_of_j(j) for j in range(SEGS)], "inner")

    front = lambda nrings: [r * SEGS for r in range(nrings)]      # point 0 of every ring faces -Y

    parts = {}
    # whole egg: bottom pole, rings every 20 degrees, top pole
    rings = [outer_ring(lambda j, d=d: d) for d in (20.0 * i for i in range(1, RINGS + 1))]
    v, f, u, hdn = build(rings, ["outer"] * (len(rings) - 1), ((0.0, 0.0, 0.0), 0.0), ((0.0, 0.0, H), 180.0),
                         ("outer", "outer"))
    parts["whole"] = (v, f, u, hdn, front(len(rings)))
    # bottom half (the cup): bottom pole, rings up to the crack, the edge, the inside down to an inner pole
    rings = [outer_ring(lambda j, d=d: d) for d in CUP_RINGS] + [outer_ring(_crack_deg), inner_ring(_crack_deg)]
    kinds = ["outer"] * len(CUP_RINGS) + ["edge"]
    v, f, u, hdn = build(rings, kinds, ((0.0, 0.0, 0.0), 0.0), ((0.0, 0.0, SHELL), None), ("outer", "inside"))
    parts["bottom"] = (v, f, u, hdn, front(len(CUP_RINGS) + 1))
    # top half (the cap): top pole, its ring, the crack, the edge, the inside up to an inner pole
    rings = [outer_ring(lambda j, d=d: d) for d in sorted(CAP_RINGS, reverse=True)] + [outer_ring(_crack_deg), inner_ring(_crack_deg)]
    kinds = ["outer"] * len(CAP_RINGS) + ["edge"]
    v, f, u, hdn = build(rings, kinds, ((0.0, 0.0, H), 180.0), ((0.0, 0.0, H - SHELL), None), ("outer", "inside"))
    parts["top"] = (v, f, u, hdn, front(len(CAP_RINGS) + 1))
    return parts


# ---------------------------------------------------------------- the code's part of the hatch, as a preview
# 04 B1 "it wobbles twice, cracks": in the game this is code (task S6-C2); these keys are the
# stand-in the review renders use, timed to A_Fish_Hatch, and the starting values for that code (tune).
CRACK_FRAME = 15                                  # the whole egg is swapped for the halves
WOBBLE = [(0, 0.0), (2, 0.0), (4, 1.0, "snap"), (6, -0.6, "io"), (8, 0.0, "io"), (10, 1.0, "snap"), (12, -0.6, "io"),
          (14, 0.0, "io")]
WOBBLE_DEG = 8.0                                  # the whole egg tips on its base, sideways (about Y)
CAP_FLIP = [(15, 0.0), (19, 0.75, "out"), (24, 1.0, "io")]
CAP_FLIP_DEG = -115.0                             # the cap tips off backwards (+Y) about its back edge...
CAP_DROP = (0.0, 0.5, -1.25)                      # ...and falls to the bed behind the egg (studs)
CUP_ROCK = [(15, 0.0), (17, 1.0, "snap"), (20, -0.5, "io"), (23, 0.2, "io"), (26, 0.0, "io")]
CUP_ROCK_DEG = -7.0                               # the cup rocks back once as the Fry shoots out


def throw_matrices(frame):
    """Egg-frame matrices of the whole egg, the cap and the cup at `frame` of the hatch, and whether
    the whole egg (True) or the halves show."""
    import rigs
    from mathutils import Matrix, Vector
    whole = Matrix.Rotation(math.radians(WOBBLE_DEG * rigs.ease_keys(frame, WOBBLE)), 4, 'Y')
    hinge = Vector((0.0, profile(CRACK)[0], profile(CRACK)[1]))
    flip = rigs.ease_keys(frame, CAP_FLIP)
    top = (Matrix.Translation(Vector(CAP_DROP) * flip) @ Matrix.Translation(hinge)
           @ Matrix.Rotation(math.radians(CAP_FLIP_DEG * flip), 4, 'X') @ Matrix.Translation(-hinge))
    bottom = Matrix.Rotation(math.radians(CUP_ROCK_DEG * rigs.ease_keys(frame, CUP_ROCK)), 4, 'X')
    return {"whole": whole, "top": top, "bottom": bottom, "show_whole": frame < CRACK_FRAME}


def clip_props(ca, base_z):
    """The egg for A_Fish_Hatch's review strip and clip in a creature build (clips.py spec
    "clip_props"): preview-only objects (never exported or checked) with the egg's base `base_z`
    under the Fry's origin, and the per-frame hook that wobbles, swaps and throws them."""
    import tempfile
    from mathutils import Matrix
    import preyart
    img, _ = ca.atlas()
    work = os.path.join(tempfile.mkdtemp(prefix="gulp_egg_"), ca.ALBEDO + "_work.png")
    preyart.save_rgba(work, img)
    objs = to_objects(ca, ca.material("MAT_PV_HatchEgg", work),
                      {"whole": "PV_HatchEgg", "top": "PV_HatchEgg_Top", "bottom": "PV_HatchEgg_Bottom"}, CELLS, "PREVIEW")
    base = Matrix.Translation((0.0, 0.0, base_z))

    def at(frame):
        m = throw_matrices(frame)
        for key, obj in objs.items():
            obj.matrix_world = base @ m[key]
            obj.hide_render = (key == "whole") != m["show_whole"]
    return {"objects": list(objs.values()), "at": at}


def fit_check(body, clip_name="A_Fish_Hatch"):
    """extra_checks entry for a creature build: on every frame before the crack the posed body (the
    skinned mesh as the clip deforms it) stays inside the whole egg's shell."""
    import bpy

    zs = np.linspace(0.0, H, 400)
    radius = np.interp(zs, [profile(d)[1] for d in np.linspace(0.0, 180.0, 721)],
                       [max(0.0, profile(d)[0] - SHELL) for d in np.linspace(0.0, 180.0, 721)])

    def check(spec, report):
        clip = next((c for c in spec.get("actions", []) if c["name"] == clip_name), None)
        if clip is None:
            return
        arm = clip["armature"]
        saved = arm.data.pose_position
        arm.data.pose_position = 'POSE'                 # the lod and shell steps leave the rig at rest
        arm.animation_data.action = clip["action"]
        base = fry_above_base()
        worst, at = -1e9, 0
        for f in range(clip["start"], clip["start"] + CRACK_FRAME):
            bpy.context.scene.frame_set(f)
            ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
            pts = np.array([(body.matrix_world @ v.co)[:] for v in ev.to_mesh().vertices])
            ev.to_mesh_clear()
            z = pts[:, 2] + base
            out = np.maximum(np.hypot(pts[:, 0], pts[:, 1]) - np.interp(z, zs, radius), np.maximum(-z, z - H + SHELL))
            if out.max() > worst:
                worst, at, where = float(out.max()), f, tuple(pts[int(out.argmax())])
        bpy.context.scene.frame_set(clip["start"])
        arm.data.pose_position = saved
        report.add(clip_name, "inside the egg", worst <= 0.0,
                   "frames 0-%d: the body comes %.3f studs %s the shell's inside at its closest (frame %d, at x %.2f y %.2f, "
                   "%.2f above the egg's base); egg %.1f x %.1f, Fry model %.2f above its base"
                   % (CRACK_FRAME - 1, abs(worst), "past" if worst > 0 else "short of", at, where[0], where[1], where[2] + base, W, H, base))
    return check


def to_objects(ca, material, names, cells, collection="GEO"):
    """Blender objects {"whole", "top", "bottom"} named by `names`, on `material`."""
    out = {}
    for key, (verts, faces, uvs, hidden, front) in build_parts(ca, cells).items():
        part = ca.Part()
        part.add(verts, faces, uvs, hidden, front_verts=front)
        out[key] = part.to_object(names[key], material, collection)
    return out
