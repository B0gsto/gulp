"""The hatch egg's shape and paint (task S6-A2, docs/13-sprint-plan.md Sprint 6; docs/07-asset-list.md
section 2.0 row M_Prop_HatchEgg: "the pale egg a new Fry hatches from ... whole egg and two cracked
halves", 200 tris, on T_Cove_Alb; the beat is 04 3.6 B1).

Shared by the egg's build (cove/hatchegg/build.py), by coveart.py (the egg's two cells of the cove
atlas T_Cove_Alb, so every build that writes the atlas writes the same one) and by the Minnow build
(its A_Fish_Hatch review strip shows the clip with the egg). Plain numpy and Blender mesh data.

Size (tune; chapter 14 section 5.1 row "Hatch egg size"): 2.6 across and 3.3 tall, so the tier-1
Minnow (3.0 long, 1.365 tall, 06 6.2) fits inside it squashed and curled (A_Fish_Hatch frames 0-15).
The egg's axis is +Z, its origin the bottom pole (06 6.1: a prop's origin is the centre of its base).
Personality (S6-A2 review): a full bottom, a slight lean to its left (+X), a few big plum spots
each with a glint on its rim, three small apricot freckles (the accent) and a lit cream crown.

Triangles (07 row, 200 on screen at a time) go to the silhouette: 15 points round every ring (the
outline seen from above and the cup's rim) and rings placed where the profile bends most. The two
halves are open shells with no thickness: the outside, then a fan into the dark inside, whose
painted lit band along the rim reads as the broken edge; the crack is a hard edge.
"""
import math
import os

import numpy as np

W, H = 2.6, 3.3                  # studs across and tall (tune)
EGGNESS = 0.20                   # how much wider the lower half is than the upper (0: an ellipsoid): a full bottom
LEAN_DEG = 4.0                   # the egg leans this far to its left (+X), its base planted (tune)
SEGS = 15                        # points round every ring
SECTORS = 3                      # the paint repeats three times round the egg (overlapping UVs, 06 5.6 density)
WHOLE_RINGS = (23.9, 46.9, 70.2, 96.3, 126.6, 155.7)   # profile angles (degrees from the bottom pole): equal chord sag
CRACK = 100.0                    # profile angle of the crack: its rim between 1.65 and 2.21 studs up
TEETH = (-1.0, 0.3, -0.6, 0.9, -0.7, 1.0, -0.6, 0.85, -0.9, 0.7, -0.65, 1.0, -0.8, 0.6, -0.3)  # the crack's zigzag,
TOOTH = 10.0                     # times this many degrees, point 0 the front: uneven, so it reads broken, not cut, and
                                 # lowest at the front, where the Fry pushes the cap up and swims out over the rim
SHELL = 0.07                     # how far in the inside's pole sits from the outside's
CUP_RINGS = (22.9, 44.9, 67.2)   # the bottom half's rings below the crack
CAP_RINGS = (147.6,)             # the top half's ring above it
CELLS = {"shell": "egg_shell", "inside": "egg_inside"}   # coveart.CELLS of T_Cove_Alb
EDGE_FV = 0.06                   # the inside's lit band along the rim, as a share of the fan from rim to pole


def lean_dx(z):
    """How far the egg's axis has leaned to +X at height z: zero and level at the base."""
    return math.tan(math.radians(LEAN_DEG)) * z * z / H


# Colours (06 4.1 three values, 4.3: shadows toward blue-violet, lights toward yellow). Pale lilac,
# so the tangerine Minnow (the warmest thing in the Nursery, 06 4.3) pops out of it; no reserved hue (4.5).
MID_LOW = "#C9B3E2"     # lower shell (mid, L* 76)
MID_HIGH = "#D0BDE6"    # upper shell, its one gradient (mid, L* 79: 3 points)
CROWN_LOW = "#F7E6CF"   # the lit crown at its edge (light, L* 92) ...
CROWN = "#FFF4E2"       # ... to its top (L* 97: 5 points); also the spots' glints and the broken edge
SPOT = "#5E4058"        # plum spots: the cove kit's dark (coveart.DARK, L* 31; measured over the spots with their
                        # one-pixel edges, L* 34)
ACCENT = "#FFB38A"      # apricot freckles: 06 4.3's warm accent (shark row), hue 21, saturation 46%: not reserved
INSIDE = "#62476A"      # inside of the shell, in shadow (dark, L* 34: the top of 06 4.1's dark block, no black)
LIGHT_SHARE = 0.28      # share of the egg's area above the crown's edge (06 4.1 light: 20 to 30%; the spots take some)
DARK_SHARE = 0.125      # share the spots take (06 4.1 dark: 10 to 15%)
ACCENT_R = 0.13         # apricot freckle radius, studs (3 per sector: about 2.5% of the surface, 06 4.1 cap 5%)
# Spots per paint sector: (fu round the sector 0..1, fv up the egg 0..1, radius as a share of the
# biggest); sized together so they cover DARK_SHARE of the surface. Two to a sector: from any side
# three to five show, hard edged.
SPOTS = ((0.27, 0.40, 1.0), (0.78, 0.66, 0.68))
FRECKLES = ((0.62, 0.30), (0.95, 0.47), (0.50, 0.80))   # the accent's (fu, fv)
GLINT = (0.50, 0.80, -0.55, 0.85)   # each spot's glint: a crescent between these shares of its radius, toward
# (round, up) = (-0.55, 0.85), the light's side (06 15.3 key light high and to the left)


def _radius_raw(t):
    return math.sin(t) * (1.0 + EGGNESS * math.cos(t))


_R = (W / 2.0) / max(_radius_raw(math.radians(a / 10.0)) for a in range(0, 1801))


def profile(deg):
    """(r, z) of the outer surface at profile angle `deg` (0 bottom pole, 180 top pole), before the lean."""
    t = math.radians(deg)
    return _R * _radius_raw(t), H / 2.0 * (1.0 - math.cos(t))


def normal(deg):
    """Outward unit normal (nr, nz) of the profile at `deg`."""
    a, b = profile(deg - 0.05), profile(deg + 0.05)
    dr, dz = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dr, dz)
    return dz / n, -dr / n


def extent():
    """(across x, across y, tall) of the leaned egg as built: its rings are 15-sided, so a little
    under W across (the points touch the true egg), for the size check."""
    xs, ys = [], []
    for d in np.linspace(0.0, 180.0, 181):
        r, z = profile(d)
        for j in range(SEGS):
            xs.append(r * math.cos(phi(j)) + lean_dx(z))
            ys.append(r * math.sin(phi(j)))
    return max(xs) - min(xs), max(ys) - min(ys), H


def base_radius():
    """Radius of curvature of the round base at the bottom pole (the rock rolls on it, rigs.HATCH_EGG_ROLL)."""
    r, z = profile(1.0)
    return r * r / (2.0 * z)


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


def phi(j):
    """Ring point j's angle; point 0 faces -Y (06 6.1 front), the side the Fry faces on hatching."""
    return -math.pi / 2.0 + 2.0 * math.pi * j / SEGS


def crack_deg(j):
    return CRACK + TOOTH * TEETH[j % SEGS]


def rim_height(angle):
    """Height of the cup's rim (studs above the base, before the lean) at `angle` round the egg (radians, phi's
    convention), along the crack's straight edges."""
    u = ((angle - phi(0)) / (2.0 * math.pi) * SEGS) % SEGS
    j = int(u)
    a, b = profile(crack_deg(j))[1], profile(crack_deg((j + 1) % SEGS))[1]
    return a + (b - a) * (u - j)


# ---------------------------------------------------------------- paint (the two atlas cells, coveart.CELLS)
# The shell cell lies on its side: up the egg runs along the cell's width (96 px for the 4.7-stud
# meridian) and round it along its height (64 px for a third of the 8-stud girth), so the paint is
# about 20 px per stud both ways.

def _hex(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def _cell_grid(w, h, inset):
    """x, y of every pixel in the mapped part of a cell (coveart.cell_uv's inset), 0..1, y 0 at the bottom."""
    x = (np.arange(w, dtype=np.float64) + 0.5 - inset) / (w - 2 * inset)
    y = 1.0 - (np.arange(h, dtype=np.float64) + 0.5 - inset) / (h - 2 * inset)
    return np.meshgrid(x, y)


def shell_uv(ca, cells, fu, fv):
    """Atlas UV of the shell's point fu (round the sector), fv (up the egg): the cell lies on its side."""
    return ca.cell_uv(cells["shell"], fv, fu)


def _crown_fv():
    """The paint row above which LIGHT_SHARE of the egg's area lies (area by arc length times radius)."""
    da = np.concatenate([[0.0], np.cumsum(np.diff(_S) * 0.5 * (_RAD[1:] + _RAD[:-1]))])
    above = 1.0 - da / da[-1]
    return float(np.interp(LIGHT_SHARE, above[::-1], (_S / ARC)[::-1]))


def _surface(fu, fv):
    """Studs per unit of fu round the sector at each row, and the row in studs up the egg."""
    sv = np.clip(fv, 0.0, 1.0) * ARC
    return 2.0 * math.pi * np.interp(sv, _S, _RAD) / SECTORS, sv


def _spot_fields(fu, fv, scale):
    """Distance (studs, negative inside) to the nearest spot's edge, and that spot's centre offset
    (round, up, in studs) and radius at every pixel, measured on the egg's surface."""
    ring, _ = _surface(fu, fv)
    best = np.full(fu.shape, 1e9)
    off_u, off_v, rad = np.zeros(fu.shape), np.zeros(fu.shape), np.ones(fu.shape)
    for cu, cv, rel in SPOTS:
        du = ((fu - cu + 0.5) % 1.0 - 0.5) * ring          # tileable round the egg
        dv = (fv - cv) * ARC
        r = rel * scale
        d = np.hypot(du, dv) - r
        take = d < best
        best = np.where(take, d, best)
        off_u, off_v, rad = np.where(take, du, off_u), np.where(take, dv, off_v), np.where(take, r, rad)
    return best, off_u, off_v, rad


def _spot_scale():
    """Biggest spot's radius (studs) that covers DARK_SHARE of the surface, by bisection."""
    fu, fv = np.meshgrid(np.linspace(0.0, 1.0, 240, endpoint=False) + 0.5 / 240, np.linspace(0.0, 1.0, 400))
    weight = np.interp(fv * ARC, _S, _RAD)
    lo, hi = 0.02, 1.0
    for _ in range(40):
        mid = 0.5 * (lo + hi)
        share = float((weight * (_spot_fields(fu, fv, mid)[0] < 0.0)).sum() / weight.sum())
        lo, hi = (mid, hi) if share < DARK_SHARE else (lo, mid)
    return 0.5 * (lo + hi)


def _ink(d, px):
    """Coverage of a hard edge `d` studs away (negative inside), antialiased over one pixel."""
    return np.clip(0.5 - d / px, 0.0, 1.0)


def paint_shell(w, h, inset):
    """The outside of the egg, one paint sector. Mid: one gentle gradient, lower to upper. Light: the
    crown above a hard, softly waving edge, its own short gradient, and a glint on each spot's rim.
    Dark: hard-edged plum spots. Accent: three apricot freckles. Block map: 0 mid, 1 light, 2 dark, 3 accent."""
    fv, fu = _cell_grid(w, h, inset)          # the cell lies on its side: x up the egg, y round it
    px = ARC / (w - 2 * inset)                # studs per pixel up the egg
    crown = _crown_fv()
    t = np.clip((fv - 0.15) / (crown - 0.15), 0.0, 1.0)[..., None]
    img = _hex(MID_LOW) * (1.0 - t) + _hex(MID_HIGH) * t
    edge = crown + 0.018 * np.sin(2.0 * math.pi * (2.0 * fu + 0.15))       # two waves a sector, so it tiles
    lit = _ink((edge - fv) * ARC, px)
    tc = np.clip((fv - crown) / (1.0 - crown), 0.0, 1.0)[..., None]
    crown_rgb = _hex(CROWN_LOW) * (1.0 - tc) + _hex(CROWN) * tc
    img = img * (1.0 - lit[..., None]) + crown_rgb * lit[..., None]
    d, ou, ov, rad = _spot_fields(fu, fv, _spot_scale())
    spot = _ink(d, px)
    img = img * (1.0 - spot[..., None]) + _hex(SPOT) * spot[..., None]
    gu, gv = GLINT[2], GLINT[3]
    dist = np.hypot(ou, ov)
    facing = (ou * gu + ov * gv) / np.maximum(dist, 1e-6)                  # cosine to the light's side
    band = np.minimum(dist - GLINT[0] * rad, GLINT[1] * rad - dist)        # inside the crescent's ring: > 0
    glint = np.clip(band / px + 0.5, 0.0, 1.0) * np.clip((facing - 0.55) / 0.15, 0.0, 1.0) * (d < 0.0)
    img = img * (1.0 - glint[..., None]) + _hex(CROWN) * glint[..., None]
    ring, _ = _surface(fu, fv)
    fd = np.full(fu.shape, 1e9)
    for cu, cv in FRECKLES:
        fd = np.minimum(fd, np.hypot(((fu - cu + 0.5) % 1.0 - 0.5) * ring, (fv - cv) * ARC) - ACCENT_R)
    warm = _ink(fd, px) * (d > px)
    img = img * (1.0 - warm[..., None]) + _hex(ACCENT) * warm[..., None]
    block = np.where(warm > 0.5, 3, np.where(glint > 0.5, 1, np.where(spot > 0.5, 2, np.where(lit > 0.5, 1, 0))))
    return img.astype(np.float32), block.astype(np.int32)


def paint_inside(w, h, inset):
    """Inside of the broken shell, one fan from the rim (y 1) to the inner pole (y 0): flat shadow
    colour (the dark block) under a lit band along the rim, the broken edge catching the light."""
    _, y = _cell_grid(w, h, inset)
    px = 1.0 / (h - 2 * inset)
    lit = np.clip((y - (1.0 - EDGE_FV)) / px + 0.5, 0.0, 1.0)[..., None]
    img = _hex(INSIDE) * (1.0 - lit) + _hex(CROWN) * lit
    return img.astype(np.float32), np.where(lit[..., 0] > 0.5, 1, 2).astype(np.int32)


# ---------------------------------------------------------------- meshes (coveart.Part, coveart.loft)

def _ring(deg_of_j):
    """Ring points; `deg_of_j(j)` is each point's profile angle."""
    out = []
    for j in range(SEGS):
        r, z = profile(deg_of_j(j))
        out.append((r * math.cos(phi(j)) + lean_dx(z), r * math.sin(phi(j)), z))
    return out


def build_parts(ca, cells):
    """The three closed meshes: whole egg, top half (the cap), bottom half (the cup), each as
    (verts, faces, uvs, hidden, front verts, crack verts). `cells` maps "shell" and "inside" to
    coveart cell names. Front points (tagged for the facing check) face -Y; crack points are the
    rim, where the outside meets the inside on a hard edge."""
    k = SEGS // SECTORS
    n = SEGS

    def build(rings, pole_start, pole_end, inside_end):
        """rings: [(points, degs)] outside, pole to crack; pole_start/pole_end: (point, profile degree or
        None); inside_end: the fan at the end is the inside."""
        verts, faces = ca.loft([ring[0] for ring in rings], pole_start=pole_start[0], pole_end=pole_end[0])
        uvs = []
        for idx, meta in faces:
            if meta[0] == "q":
                r, j = meta[1], meta[2]
                corners = [(r, j, 0), (r, j, 1), (r + 1, j, 1), (r + 1, j, 0)]
                uvs.append([shell_uv(ca, cells, ((j % k) + step) / float(k), fv_of(rings[rr][1][(j + step) % n]))
                            for rr, j, step in corners])
                continue
            j = meta[1]
            if meta[0] == "p1" and inside_end:
                rr = len(rings) - 1
                uvs.append([ca.cell_uv(cells["inside"], j / float(n), 1.0), ca.cell_uv(cells["inside"], (j + 1) / float(n), 1.0),
                            ca.cell_uv(cells["inside"], (j + 0.5) / float(n), 0.0)])
                continue
            rr = 0 if meta[0] == "p0" else len(rings) - 1
            deg = pole_start[1] if meta[0] == "p0" else pole_end[1]
            pole = shell_uv(ca, cells, ((j % k) + 0.5) / k, fv_of(deg))
            a = shell_uv(ca, cells, ((j % k) + 1) / float(k), fv_of(rings[rr][1][(j + 1) % n]))
            b = shell_uv(ca, cells, (j % k) / float(k), fv_of(rings[rr][1][j]))
            uvs.append([pole, a, b] if meta[0] == "p0" else [b, a, pole])
        return verts, faces, uvs, [False] * len(faces)

    def ring(deg_of_j):
        return (_ring(deg_of_j), [deg_of_j(j) for j in range(SEGS)])

    def pole(deg, inset=0.0):
        z = profile(deg)[1] + inset
        return ((lean_dx(z), 0.0, z), deg)

    front = lambda nrings: [r * SEGS for r in range(nrings)]      # point 0 of every ring faces -Y
    crack = lambda nrings: list(range((nrings - 1) * SEGS, nrings * SEGS))

    parts = {}
    rings = [ring(lambda j, d=d: d) for d in WHOLE_RINGS]
    v, f, u, hdn = build(rings, pole(0.0), pole(180.0), False)
    parts["whole"] = (v, f, u, hdn, front(len(rings)), [])
    # bottom half (the cup): bottom pole, rings up to the crack, then the inside's fan down to an inner pole
    rings = [ring(lambda j, d=d: d) for d in CUP_RINGS] + [ring(crack_deg)]
    v, f, u, hdn = build(rings, pole(0.0), ((lean_dx(SHELL), 0.0, SHELL), None), True)
    parts["bottom"] = (v, f, u, hdn, front(len(rings)), crack(len(rings)))
    # top half (the cap): top pole, its ring, the crack, the inside's fan up to an inner pole
    rings = [ring(lambda j, d=d: d) for d in sorted(CAP_RINGS, reverse=True)] + [ring(crack_deg)]
    v, f, u, hdn = build(rings, pole(180.0), ((lean_dx(H - SHELL), 0.0, H - SHELL), None), True)
    parts["top"] = (v, f, u, hdn, front(len(rings)), crack(len(rings)))
    return parts


# ---------------------------------------------------------------- the code's part of the hatch, as a preview
# 04 B1 "it wobbles twice, cracks": in the game this is code (task S6-C2); these keys are the
# stand-in the review renders use, timed to A_Fish_Hatch (rigs.py owns the rock, the squash and
# the crack and pop frames, since the Fry rides them), and the starting values for that code (tune).
CAP_LIFT = [(0, 0.0), (8, 0.0), (9, 0.05, "snap"), (11, 0.03, "io"), (12, 0.08, "snap"), (14, 0.06, "io"), (15, 0.1, "in")]
CAP_TILT = [(0, 0.0), (8, 0.0), (9, 3.0, "snap"), (11, 2.0, "io"), (12, 7.0, "snap"), (14, 5.0, "io"), (15, 9.0, "in")]
# On the pop the Fry's head flips the cap open backwards about its back edge like a lid (to frame
# CAP_RELEASE), then it flies free on one gravity arc, tumbling on (about X, top to +Y) and turning
# on its own axis (CAP_SPIN), to the bed behind the egg and to the Fry's left (CAP_LAND_AT: x and y
# of its tip's centre of curvature). It lands open side up on frame CAP_LAND and rolls on its
# round tip (no slide), rocking out the tumble to rest on frame 40. CAP_TUMBLE: (frame, degrees
# about X), one smooth curve; from CAP_LAND, -180 is upside down at rest.
CAP_RELEASE = 18
CAP_LAND = 26
CAP_LAND_AT = (0.9, 2.9)                         # studs, egg frame: back (+Y) and to the Fry's left (+X)
CAP_SPIN = 50.0                                   # degrees it turns on its own axis in the air
CAP_TUMBLE = [(15, -9.0), (16, -68.0), (17, -98.0), (18, -118.0), (22, -146.0), (26, -167.0), (29, -193.0), (32, -173.0),
              (35, -184.0), (38, -178.5), (40, -180.0)]
CUP_ROCK = [(15, 0.0), (17, 1.0, "snap"), (20, -0.5, "io"), (23, 0.2, "io"), (26, 0.0, "io")]
CUP_ROCK_DEG = 5.0                                # the cup rocks back once (top to +Y) as the Fry shoots up out of it


def tip_radius():
    """Radius of curvature of the round top at the top pole (the landed cap rolls on it)."""
    r, z = profile(179.0)
    return r * r / (2.0 * (H - z))


def cap_points():
    """Points over the cap's outside (top pole to the crack), egg frame at rest, for its contact."""
    pts = []
    for j in range(SEGS):
        for d in np.linspace(crack_deg(j), 180.0, 24):
            r, z = profile(d)
            pts.append((r * math.cos(phi(j)) + lean_dx(z), r * math.sin(phi(j)), z))
    return np.array(pts)


def egg_matrix(frame):
    """The whole egg's (and the closed halves') rock and squash at `frame`, in the egg's frame."""
    import rigs
    from mathutils import Matrix
    rock = rigs.hatch_egg_rock(frame) if frame <= rigs.HATCH_POP else Matrix.Identity(4)
    return rock @ rigs.hatch_egg_squash(frame)


def _hinge():
    from mathutils import Vector
    zc = profile(CRACK)[1]
    return Vector((lean_dx(zc), profile(CRACK)[0], zc))


def _cap_centre():
    from mathutils import Vector
    rc = tip_radius()
    return Vector((lean_dx(H - rc), 0.0, H - rc))


def _lid(frame, theta):
    """The cap turned `theta` degrees about its back edge (the hinge), lifted by CAP_LIFT."""
    import rigs
    from mathutils import Matrix
    h = _hinge()
    return (Matrix.Translation((0.0, 0.0, rigs.ease_keys(min(frame, rigs.HATCH_POP), CAP_LIFT))) @ Matrix.Translation(h)
            @ Matrix.Rotation(math.radians(theta), 4, 'X') @ Matrix.Translation(-h))


def _turn(theta, psi, at):
    """The cap tumbled `theta` about X after `psi` about its own axis, its tip's centre moved to `at`."""
    from mathutils import Matrix
    c = _cap_centre()
    return (Matrix.Translation(at) @ Matrix.Rotation(math.radians(theta), 4, 'X') @ Matrix.Rotation(math.radians(psi), 4, 'Z')
            @ Matrix.Translation(-c))


_FLIGHT = []


def _flight():
    """The free flight, worked out once from the lid's speed at release: the gravity that brings the
    tip's centre down onto the bed on CAP_LAND (where the turned cap's lowest point touches it)."""
    import rigs
    from mathutils import Vector
    if _FLIGHT:
        return _FLIGHT[0]
    tumble = lambda f: rigs.smooth_keys(f, CAP_TUMBLE, 1)
    c = _cap_centre()
    p0, p1 = (_lid(f, tumble(f)) @ c for f in (CAP_RELEASE - 1, CAP_RELEASE))
    pts = [Vector(p) for p in cap_points()]
    m = _turn(tumble(CAP_LAND), CAP_SPIN, Vector((0.0, 0.0, 0.0)))
    z_land = -min((m @ p).z for p in pts)
    t = float(CAP_LAND - CAP_RELEASE)
    vz = p1.z - p0.z
    g = 2.0 * (p1.z + vz * t - z_land) / (t * t)
    _FLIGHT.append({"p": p1, "v": p1 - p0, "g": g, "t": t, "pts": pts, "rc": tip_radius()})
    return _FLIGHT[0]


def cap_matrix(frame):
    """The cap's egg-frame matrix at `frame`, from the pop on: the lid flip, the flight, the rest."""
    import rigs
    from mathutils import Vector
    theta = rigs.smooth_keys(frame, CAP_TUMBLE, 1)
    if frame <= CAP_RELEASE:
        return _lid(frame, theta)
    fl = _flight()
    land = Vector((CAP_LAND_AT[0], CAP_LAND_AT[1], 0.0))
    if frame < CAP_LAND:
        t = frame - CAP_RELEASE
        u = t / fl["t"]
        s = u * u * (3.0 - 2.0 * u)                    # across the bed: leaving at the lid's speed, slowing by drag
        y = fl["p"].y + (land.y - fl["p"].y) * (1.0 - (1.0 - u) ** 2)
        x = fl["p"].x + (land.x - fl["p"].x) * s
        at = Vector((x, y, fl["p"].z + fl["v"].z * t - 0.5 * fl["g"] * t * t))
        return _turn(theta, CAP_SPIN * s, at)
    # on the bed: rolling on its tip, a turn of -d theta about X carries it +Y by rc d theta (no slide)
    roll = math.radians(theta - rigs.smooth_keys(CAP_LAND, CAP_TUMBLE, 1))
    m = _turn(theta, CAP_SPIN, Vector((land.x, land.y - fl["rc"] * roll, 0.0)))
    low = min((m @ p).z for p in fl["pts"])
    return _turn(theta, CAP_SPIN, Vector((land.x, land.y - fl["rc"] * roll, -low)))


def throw_matrices(frame):
    """Egg-frame matrices of the whole egg, the cap and the cup at `frame` of the hatch, and whether
    the whole egg (True) or the halves show."""
    import rigs
    from mathutils import Matrix
    egg = egg_matrix(frame)
    if frame <= rigs.HATCH_POP:
        top = egg @ _lid(frame, -rigs.ease_keys(frame, CAP_TILT))
    else:
        top = cap_matrix(frame)
    bottom = egg @ Matrix.Rotation(math.radians(CUP_ROCK_DEG * rigs.ease_keys(frame, CUP_ROCK)), 4, 'X')
    return {"whole": egg, "top": top, "bottom": bottom, "show_whole": frame < rigs.HATCH_CRACK}


def clip_props(ca):
    """The egg for A_Fish_Hatch's review strip and clip in a creature build (clips.py spec
    "clip_props"): preview-only objects (never exported or checked) with the egg's base at
    rigs.HATCH_EGG_AT in the Fry's frame, and the per-frame hook that rocks, cracks and throws them."""
    import tempfile
    from mathutils import Matrix
    import preyart
    import rigs
    img, _ = ca.atlas()
    work = os.path.join(tempfile.mkdtemp(prefix="gulp_egg_"), ca.ALBEDO + "_work.png")
    preyart.save_rgba(work, img)
    objs = to_objects(ca, ca.material("MAT_PV_HatchEgg", work),
                      {"whole": "PV_HatchEgg", "top": "PV_HatchEgg_Top", "bottom": "PV_HatchEgg_Bottom"}, CELLS, "PREVIEW")
    base = Matrix.Translation(rigs.HATCH_EGG_AT)

    def at(frame):
        m = throw_matrices(frame)
        for key, obj in objs.items():
            obj.matrix_world = base @ m[key]
            obj.hide_render = (key == "whole") != m["show_whole"]
    return {"objects": list(objs.values()), "at": at}


def fit_check(body, clip_name="A_Fish_Hatch"):
    """extra_checks entry for a creature build, on the posed body (the skinned mesh as the clip
    deforms it), in the egg's own frame (its rock, squash and lean taken out): until the pop it
    stays inside the closed egg's shell; from the pop on it never goes through the cup's wall or the thrown cap (no
    frame has body points below the rim both inside the cup and outside it) or under the bed."""
    import bpy
    import rigs
    from mathutils import Vector

    zs = np.linspace(0.0, H, 400)
    radius = np.interp(zs, [profile(d)[1] for d in np.linspace(0.0, 180.0, 721)],
                       [profile(d)[0] for d in np.linspace(0.0, 180.0, 721)])

    def check(spec, report):
        clip = next((c for c in spec.get("actions", []) if c["name"] == clip_name), None)
        if clip is None:
            return
        arm = clip["armature"]
        saved = arm.data.pose_position
        arm.data.pose_position = 'POSE'                 # the lod and shell steps leave the rig at rest
        arm.animation_data.action = clip["action"]
        egg_at = Vector(rigs.HATCH_EGG_AT)
        worst, at, where, through, capped = -1e9, 0, (0.0, 0.0, 0.0), [], []
        for f in range(clip["start"], clip["end"] + 1):
            frame = f - clip["start"]
            bpy.context.scene.frame_set(f)
            ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
            m = throw_matrices(frame)["whole" if frame <= rigs.HATCH_POP else "bottom"].inverted()
            pts_world = [body.matrix_world @ v.co - egg_at for v in ev.to_mesh().vertices]
            pts = np.array([(m @ p)[:] for p in pts_world])
            ev.to_mesh_clear()
            z = pts[:, 2]
            x = pts[:, 0] - np.array([lean_dx(max(0.0, min(H, zz))) for zz in z])
            r = np.hypot(x, pts[:, 1])
            if frame <= rigs.HATCH_POP:
                out = np.maximum(r - (np.interp(z, zs, radius) - SHELL), np.maximum(SHELL - z, z - H + SHELL))
                if out.max() > worst:
                    worst, at, where = float(out.max()), frame, tuple(pts[int(out.argmax())])
                continue
            rim = np.array([rim_height(math.atan2(yy, xx)) for xx, yy in zip(x, pts[:, 1])])
            low = z < rim
            inside = low & (r < np.interp(z, zs, radius))
            if (inside.any() and (low & ~inside).any()) or (z < 0.0).any():
                o = np.where(low & ~inside)[0]
                i = o[int(np.argmin(r[o] - np.interp(z[o], zs, radius)))] if len(o) else int(np.argmin(z))
                through.append("%d (%.2f %.2f %.2f)" % (frame, pts[i, 0], pts[i, 1], pts[i, 2]))
            # the free cap, in its own rest frame: no body points both under its dome and outside it above its rim
            cm = throw_matrices(frame)["top"].inverted()
            cp = np.array([(cm @ Vector(p))[:] for p in pts_world])
            cz = cp[:, 2]
            cx = cp[:, 0] - np.array([lean_dx(max(0.0, min(H, zz))) for zz in cz])
            cr = np.hypot(cx, cp[:, 1])
            high = cz > np.array([rim_height(math.atan2(yy, xx)) for xx, yy in zip(cx, cp[:, 1])])
            under = high & (cr < np.interp(cz, zs, radius) - SHELL) & (cz < H - SHELL)
            over = high & ~under & (cr < np.interp(cz, zs, radius) + 0.3) & (cz < H + 0.3)
            if under.any() and over.any():
                capped.append(str(frame))
        bpy.context.scene.frame_set(clip["start"])
        arm.data.pose_position = saved
        report.add(clip_name, "inside the egg", worst <= 0.0,
                   "frames 0-%d: the body comes %.3f studs %s the shell's inside at its closest (frame %d, at x %.2f y %.2f "
                   "z %.2f in the egg's frame); egg %.1f x %.1f, its base at %s in the Fry's frame"
                   % (rigs.HATCH_POP, abs(worst), "past" if worst > 0 else "short of", at, where[0], where[1], where[2], W, H,
                      tuple(round(c, 2) for c in rigs.HATCH_EGG_AT)))
        report.add(clip_name, "out of the cup", not through,
                   ("frames %s go through the cup's wall or under the bed (the outside point nearest the wall)" % ", ".join(through[:8]))
                   if through else
                   "frames %d-%d: the body is inside the cup or clear of it, never through its wall, rising out over the rim"
                   % (rigs.HATCH_POP + 1, clip["end"] - clip["start"]))
        report.add(clip_name, "clear of the cap", not capped,
                   ("frames %s: the body goes through the thrown cap's shell" % ", ".join(capped[:8])) if capped else
                   "frames %d-%d: the body never goes through the thrown cap (eggart.cap_matrix)"
                   % (rigs.HATCH_POP + 1, clip["end"] - clip["start"]))
    return check


def to_objects(ca, material, names, cells, collection="GEO"):
    """Blender objects {"whole", "top", "bottom"} named by `names`, on `material`; the halves' rims
    are hard edges (the outside and the inside meet at an angle)."""
    out = {}
    for key, (verts, faces, uvs, hidden, front, crack) in build_parts(ca, cells).items():
        part = ca.Part()
        part.add(verts, faces, uvs, hidden, front_verts=front)
        obj = part.to_object(names[key], material, collection)
        if crack:
            rim = set(crack)
            mesh = obj.data
            sharp = mesh.attributes.get("sharp_edge") or mesh.attributes.new("sharp_edge", 'BOOLEAN', 'EDGE')
            sharp.data.foreach_set("value", [e.vertices[0] in rim and e.vertices[1] in rim for e in mesh.edges])
            mesh.update()
        out[key] = obj
    return out
