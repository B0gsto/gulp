"""Painted tiling ground textures and the shared environment atlas (task S5-A1; docs/07-asset-list.md
section 6.1 rows T_Tile_*_Alb and T_EnvShared_Alb; docs/06-art-bible.md sections 4.2, 5.1 to 5.3,
5.6, 9.2, 9.3, 16.1).

Pure numpy, so it imports in the system python3 and inside Blender. Every field is periodic on the
0..1 square (integer-frequency waves, Voronoi and dots measured with wrap-around distance), so the
four tiles repeat with no seam by construction; `seam()` measures it anyway.

Painting rules carried here (06 5.1, 5.2): shapes, not noise. Large soft value shapes, broad marks
no smaller than 2% of the width (10 px at 512), shadows lean blue-violet (#5A4FA0), lights lean warm
(#FFF6D9), never black. Each tile's mean colour is set exactly to the lightest floor colour it
serves in 06 4.2 (per channel), so every other zone colour is a SurfaceAppearance.Color tint at or
below 1 (06 5.3: "silt and sandstone are tints of these", 07 6.1). TINTS lists them.
"""
import math

import numpy as np

N = 512                       # 06 5.6: 512 x 512, repeating every 32 studs (16 px per stud)
STUDS_PER_TILE = 32
MIN_MARK_PX = N // 50         # 06 5.2: smallest mark 2% of the width

VIOLET = "#5A4FA0"            # 06 5.2: occlusion tint, shadows lean blue-violet
WARM = "#FFF6D9"              # 06 15.3 key light: lights lean yellow

# 06 4.2 floor colours by zone (and the cove's warm stone)
FLOOR = {
    "nursery_sand": "#F6E3B4", "reef_sand": "#F2D9A0", "reef_rock": "#C9A98F",
    "kelp_silt": "#8FA07A", "kelp_rock": "#5F7F6F", "dropoff_upper_slate": "#4F6FA0",
    "dropoff_deep_slate": "#2F4A80", "cove_stone": "#D9B48F",
}
CORAL_PINK = "#FF7F9F"        # 06 9.3 coral colours (coralline crust on coral rock, shell accents)
CORAL_ORANGE = "#FFA35C"

# Which floor colours each tile serves; its mean is the per-channel maximum of these.
SERVES = {
    "T_Tile_Sand_Alb": {"nursery": "nursery_sand", "reef": "reef_sand", "kelp": "kelp_silt"},
    "T_Tile_Rock_Alb": {"reef": "reef_rock", "kelp": "kelp_rock", "cove": "cove_stone"},
    "T_Tile_CoralRock_Alb": {"reef": "reef_rock"},
    "T_Tile_Slate_Alb": {"dropoff_upper": "dropoff_upper_slate", "dropoff_deep": "dropoff_deep_slate"},
}
SIGNAL = ("#A6FF3D", "#FFF23D", "#FF3B4E", "#FF3DC8", "#FFFFFF", "#FFC46B", "#FFF1DC", "#FFE9F2", "#FFB8D9")


# ---------------------------------------------------------------- colour helpers
def rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def hexof(c):
    return "#%02X%02X%02X" % tuple(int(round(float(x) * 255)) for x in np.clip(c, 0, 1))


def lstar(img):
    """CIE L* of sRGB floats (..., 3)."""
    c = np.asarray(img, dtype=float)
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    y = lin[..., 0] * 0.2126 + lin[..., 1] * 0.7152 + lin[..., 2] * 0.0722
    return np.where(y > 0.008856, 116.0 * np.cbrt(y) - 16.0, 903.3 * y)


def mix(a, b, t):
    t = np.asarray(t, dtype=float)
    return a * (1.0 - t[..., None]) + b * t[..., None]


def smooth(e0, e1, x):
    t = np.clip((np.asarray(x, dtype=float) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def base_of(tile):
    return np.max([rgb(FLOOR[k]) for k in SERVES[tile].values()], axis=0)


def tints(tile):
    """zone -> (target hex, tint hex, tint floats): SurfaceAppearance.Color for that zone."""
    base = base_of(tile)
    out = {}
    for zone, key in SERVES[tile].items():
        t = rgb(FLOOR[key]) / base
        out[zone] = (FLOOR[key], hexof(t), [round(float(x), 4) for x in t])
    return out


# ---------------------------------------------------------------- periodic fields
def grid(n=N):
    c = (np.arange(n) + 0.5) / n
    return np.meshgrid(c, c)          # u along columns, v along rows (row 0 at the top)


def waves(rng, u, v, fmin, fmax, count=10, power=1.0):
    """A smooth periodic field in -1..1: random waves with integer frequencies fmin..fmax."""
    f = np.zeros_like(u)
    for _ in range(count):
        while True:
            kx, ky = rng.integers(-fmax, fmax + 1, 2)
            r = math.hypot(kx, ky)
            if fmin <= r <= fmax:
                break
        f += r ** -power * np.cos(2 * math.pi * (kx * u + ky * v) + rng.uniform(0, 2 * math.pi))
    return f / (np.abs(f).max() + 1e-9)


def wrap(d):
    return d - np.round(d)


def voronoi(pts, u, v, sx=1.0, sy=1.0):
    """Wrap-around Voronoi: F1, F2 (in units of the square) and the offset (dx, dy) and index of
    the nearest point. sx, sy stretch the metric (sx < 1 makes cells wide)."""
    f1 = np.full(u.shape, 9.0)
    f2 = np.full(u.shape, 9.0)
    idx = np.zeros(u.shape, dtype=int)
    ox = np.zeros(u.shape)
    oy = np.zeros(u.shape)
    for i, (px, py) in enumerate(pts):
        dx, dy = wrap(u - px), wrap(v - py)
        d = np.hypot(dx * sx, dy * sy)
        nearer = d < f1
        f2 = np.where(nearer, f1, np.minimum(f2, d))
        f1 = np.where(nearer, d, f1)
        idx = np.where(nearer, i, idx)
        ox = np.where(nearer, dx, ox)
        oy = np.where(nearer, dy, oy)
    return f1, f2, ox, oy, idx


def relaxed_points(rng, count, iters=2, n=128):
    """Blue-noise points on the torus (Lloyd relaxation on a coarse grid), so stones are even-sized."""
    pts = rng.uniform(0, 1, (count, 2))
    u, v = grid(n)
    for _ in range(iters):
        _, _, ox, oy, idx = voronoi(pts, u, v)
        for i in range(count):
            m = idx == i
            if m.any():
                pts[i] = (pts[i] + np.array([ox[m].mean(), oy[m].mean()])) % 1.0
    return pts


def dots(rng, u, v, count, rmin, rmax, avoid=None):
    """Round marks: list of (dx, dy, r) offset fields, r in pixels (>= MIN_MARK_PX / 2)."""
    out = []
    for _ in range(count):
        px, py = rng.uniform(0, 1, 2)
        r = rng.uniform(rmin, rmax) / N
        out.append((wrap(u - px), wrap(v - py), r))
    return out


# ---------------------------------------------------------------- tone: value field -> colour
def tone(base, s, light=None, dark=None):
    """s in about -1..1 is the painted value: below 0 toward a darker, violet-shifted shade,
    above 0 toward a warm light (06 4.1: shadows to blue-violet, lights to yellow, no black)."""
    dark = mix(base * 0.58, rgb(VIOLET), 0.28) if dark is None else dark
    light = np.minimum(1.0, mix(base * 1.10, rgb(WARM), 0.5)) if light is None else light
    s = np.clip(s, -1.0, 1.0)
    neg, pos = np.clip(-s, 0, 1), np.clip(s, 0, 1)
    b = np.broadcast_to(base, s.shape + (3,)) if np.ndim(base) == 1 else base
    return b * (1 - neg - pos)[..., None] + dark * neg[..., None] + light * pos[..., None]


def finish(col, target):
    """Sets the mean colour to `target` exactly (per channel), so zone tints are exact."""
    col = np.clip(col, 0, 1)
    for _ in range(3):
        col = np.clip(col * (target / col.reshape(-1, 3).mean(0)), 0, 1)
    return col


LIGHT_DIR = np.array([-0.62, -0.78])     # painted light from the upper left of the tile


# ---------------------------------------------------------------- the four tiles
def paint_sand(seed=11):
    rng = np.random.default_rng(seed)
    u, v = grid()
    base = base_of("T_Tile_Sand_Alb")
    s = 0.20 * waves(rng, u, v, 1, 2.3, 8)                       # big soft patches (rest areas)
    # wind ripples: integer wave vector (1, 6) bent by a slow periodic warp, faded in and out
    warp = 0.55 * waves(rng, u, v, 1, 2, 6) + 0.25 * waves(rng, u, v, 2, 3, 6)
    ph = 2 * math.pi * (1 * u + 6 * v + warp)
    rip = np.sin(ph) + 0.38 * np.sin(2 * ph + 0.6)              # asymmetric: steep lee side
    fade = smooth(-0.35, 0.55, waves(rng, u, v, 1, 2, 6))
    s += 0.36 * rip / 1.3 * fade
    # scattered shell bits (light) and grit pebbles (dark), each a soft painted dab with its own shade
    for dx, dy, r in dots(rng, u, v, 16, 6, 10):
        d = np.hypot(dx, dy) / r
        lit = -(dx * LIGHT_DIR[0] + dy * LIGHT_DIR[1]) / r
        s += 0.55 * smooth(1.0, 0.7, d) * (0.75 + 0.25 * lit)
        sd = np.hypot(dx + 0.35 * r * LIGHT_DIR[0], dy + 0.35 * r * LIGHT_DIR[1]) / r
        s -= 0.25 * smooth(1.25, 0.9, sd) * smooth(0.8, 1.0, d)       # cast shadow, lower right
    for dx, dy, r in dots(rng, u, v, 9, 5, 8):
        d = np.hypot(dx, dy) / r
        lit = -(dx * LIGHT_DIR[0] + dy * LIGHT_DIR[1]) / r
        s += smooth(1.0, 0.65, d) * (-0.55 + 0.2 * lit)
    col = tone(base, s)
    return finish(col, base)


def paint_rock(seed=23):
    rng = np.random.default_rng(seed)
    u, v = grid()
    base = base_of("T_Tile_Rock_Alb")
    wu = u + 0.035 * waves(rng, u, v, 1, 3, 8)
    wv = v + 0.035 * waves(rng, u, v, 1, 3, 8)
    pts = relaxed_points(rng, 22)
    f1, f2, ox, oy, idx = voronoi(pts, wu, wv)
    edge = f2 - f1
    size = 0.5 * (f1 + f2)
    lit = np.clip(-(ox * LIGHT_DIR[0] + oy * LIGHT_DIR[1]) / (size + 1e-6), -1, 1)
    cellv = rng.uniform(-0.16, 0.16, len(pts))[idx]                  # each stone its own value
    s = cellv + 0.28 * lit                                            # domed, lit upper left
    s -= 0.30 * (1 - smooth(0.0, 0.06, edge))                         # painted occlusion near joints
    s -= 0.75 * (1 - smooth(0.006, 0.014, edge))                      # the joint itself (about 10 px)
    lip = smooth(0.012, 0.02, edge) * (1 - smooth(0.028, 0.045, edge)) * np.clip(lit, 0, 1)
    s += 0.55 * lip                                                   # sunlit edge highlight
    s += 0.10 * waves(rng, wu, wv, 4, 7, 10)                          # broad brush marks on the faces
    # a few chips: small flat facets, lighter
    for dx, dy, r in dots(rng, u, v, 7, 7, 12):
        d = np.hypot(dx * 1.4, dy) / r
        s += 0.22 * smooth(1.0, 0.6, d) * smooth(0.02, 0.05, edge)
    col = tone(base, s)
    return finish(col, base)


def paint_coralrock(seed=37):
    rng = np.random.default_rng(seed)
    u, v = grid()
    base = base_of("T_Tile_CoralRock_Alb")
    wu = u + 0.03 * waves(rng, u, v, 1, 3, 8)
    wv = v + 0.03 * waves(rng, u, v, 1, 3, 8)
    pts = relaxed_points(rng, 34)
    f1, f2, ox, oy, idx = voronoi(pts, wu, wv)
    edge = f2 - f1
    size = 0.5 * (f1 + f2)
    lit = np.clip(-(ox * LIGHT_DIR[0] + oy * LIGHT_DIR[1]) / (size + 1e-6), -1, 1)
    # rounded nodules with soft valleys, no hard cracks: the lumpy reef limestone
    s = 0.30 * lit * smooth(0.0, 0.05, edge) - 0.38 * (1 - smooth(0.0, 0.045, edge))
    s += rng.uniform(-0.1, 0.1, len(pts))[idx]
    # pink coralline crust in big soft patches (06 9.3 coral pink, held at low strength)
    crust = smooth(0.25, 0.55, waves(rng, u, v, 1, 3, 9))
    # pits: round holes, dark violet inside, lit on the inner lower-right wall, highlight on the outer upper-left rim
    pit = np.zeros_like(u)
    for dx, dy, r in dots(rng, u, v, 26, 6, 13):
        d = np.hypot(dx, dy) / r
        side = (dx * LIGHT_DIR[0] + dy * LIGHT_DIR[1]) / (r * np.maximum(d, 1e-3))
        inside = smooth(1.0, 0.8, d)
        pit = np.maximum(pit, inside)
        s += inside * (-0.95 + 0.35 * smooth(0.3, 1.0, side) * smooth(0.3, 0.85, d))
        s += 0.4 * smooth(1.0, 1.15, d) * smooth(1.55, 1.15, d) * np.clip(-side, 0, 1)
    # pale encrusting dabs
    for dx, dy, r in dots(rng, u, v, 12, 5, 8):
        d = np.hypot(dx, dy) / r
        s += 0.45 * smooth(1.0, 0.6, d) * (1 - pit)
    col = tone(base, s)
    pink = mix(base, rgb(CORAL_PINK), 0.32)
    col = mix(col, tone(pink, s), 0.85 * crust * (1 - pit))
    return finish(col, base)


def paint_slate(seed=51):
    rng = np.random.default_rng(seed)
    u, v = grid()
    base = base_of("T_Tile_Slate_Alb")
    # strata: five bands down the tile (integer count, so it wraps), gently bent
    b = 5 * v + 0.45 * waves(rng, u, v, 1, 2, 6) + 0.12 * waves(rng, u, v, 2, 3, 6)
    band = np.floor(b).astype(int) % 5
    fb = b - np.floor(b)
    bandv = np.array([0.08, -0.12, 0.16, -0.04, -0.18])[band]
    s = bandv + 0.22 * (0.5 - fb)                                    # each layer lit at its upper lip
    s += 0.5 * smooth(0.0, 0.05, fb) * (1 - smooth(0.06, 0.12, fb))   # bright lip
    s -= 0.65 * smooth(0.90, 0.975, fb)                               # dark groove under the next lip
    # flat plates: wide wrap-around Voronoi, cracks thinner than the rock's
    wu = u + 0.02 * waves(rng, u, v, 1, 3, 6)
    pts = relaxed_points(rng, 16)
    f1, f2, ox, oy, idx = voronoi(pts, wu, v, sx=0.45, sy=1.0)
    edge = f2 - f1
    s += rng.uniform(-0.09, 0.09, len(pts))[idx]
    s -= 0.55 * (1 - smooth(0.004, 0.011, edge)) * smooth(0.08, 0.2, fb)
    s += 0.25 * smooth(0.011, 0.016, edge) * (1 - smooth(0.02, 0.03, edge)) * (ox < 0)
    s += 0.08 * waves(rng, u * 1, v, 3, 6, 8)                         # long horizontal brush marks
    col = tone(base, s, light=np.minimum(1, mix(base * 1.15, rgb("#BFE3FF"), 0.35)))
    return finish(col, base)


# ---------------------------------------------------------------- T_EnvShared_Alb atlas
# Cells (x, y, w, h) in pixels, top-left origin. Opaque everywhere: each cell is painted to its full
# rectangle, so the 8 px bake margin (06 5.5) is the cell's own colour; meshes keep UVs 8 px inside.
ATLAS_CELLS = {
    "pebble_warm": (0, 0, 128, 128), "pebble_sand": (128, 0, 128, 128),
    "pebble_bone": (256, 0, 128, 128), "pebble_slate": (384, 0, 128, 128),
    "shell_scallop": (0, 128, 128, 128), "shell_cone": (128, 128, 128, 128),
    "shell_inner": (0, 256, 128, 128), "shell_cockle": (128, 256, 128, 128),
    "seagrass_nursery": (256, 128, 64, 256), "seagrass_reef": (320, 128, 64, 256),
    "seagrass_kelp": (384, 128, 64, 256), "seagrass_current": (448, 128, 64, 256),
    "eelhole_ring": (0, 384, 512, 128),
}


def _cell(w, h):
    x = (np.arange(w) + 0.5) / w
    y = (np.arange(h) + 0.5) / h
    return np.meshgrid(x, y)


def _pebble(w, h, mid, rng):
    x, y = _cell(w, h)
    # UVs of a pebble wrap its dome: top of the cell is its lit crown, the bottom its shaded underside
    lit = -((x - 0.5) * LIGHT_DIR[0] + (y - 0.5) * LIGHT_DIR[1]) * 1.6
    s = 0.45 * np.tanh(lit) - 0.35 * smooth(0.55, 1.0, y)
    s += 0.12 * waves(rng, x, y, 1, 2, 5)
    return tone(rgb(mid), s)


def _shell_scallop(w, h):
    x, y = _cell(w, h)
    dx, dy = x - 0.5, 1.02 - y                                         # hinge at the bottom middle
    ang = np.arctan2(dx, dy)
    rad = np.hypot(dx, dy)
    rib = np.cos(ang * 13)
    s = 0.35 * rib * smooth(0.1, 0.4, rad) + 0.25 * (rad - 0.5)
    ring = smooth(0.6, 0.8, np.cos(rad * 2 * math.pi * 4))
    col = tone(rgb(FLOOR["nursery_sand"]), s)
    return mix(col, tone(mix(rgb(FLOOR["nursery_sand"]), rgb(CORAL_PINK), 0.55), s), 0.7 * ring)


def _shell_cone(w, h):
    x, y = _cell(w, h)
    stripe = np.sin(2 * math.pi * (3 * x + 4 * y))
    s = 0.3 * np.tanh(3 * stripe) - 0.3 * smooth(0.5, 1.0, abs(x - 0.5) * 2)
    a, b = rgb(FLOOR["nursery_sand"]), rgb(FLOOR["reef_rock"])
    return tone(mix(a, b, smooth(-0.2, 0.2, stripe)), s)


def _shell_inner(w, h):
    x, y = _cell(w, h)
    r = np.hypot(x - 0.45, y - 0.4)
    s = 0.35 - 0.6 * smooth(0.1, 0.7, r)
    return tone(mix(rgb(FLOOR["nursery_sand"]), rgb(CORAL_PINK), 0.18), s)


def _shell_cockle(w, h):
    x, y = _cell(w, h)
    rib = np.cos(2 * math.pi * 7 * x)
    s = 0.3 * rib + 0.3 * (0.5 - y)
    band = smooth(0.2, 0.6, np.sin(2 * math.pi * 3 * y))
    a = rgb(FLOOR["nursery_sand"])
    return mix(tone(a, s), tone(mix(a, rgb(CORAL_ORANGE), 0.45), s), 0.6 * band)


def _seagrass(w, h, dark, light, mid_t=0.5):
    x, y = _cell(w, h)
    t = 1 - y                                                           # 0 at the root (bottom), 1 at the tip
    mid = mix(rgb(dark), rgb(light), np.array(mid_t))
    col = mix(np.broadcast_to(rgb(dark), x.shape + (3,)), np.broadcast_to(mid, x.shape + (3,)), smooth(0.0, 0.45, t))
    col = mix(col, np.broadcast_to(rgb(light), x.shape + (3,)), smooth(0.55, 1.0, t))
    across = np.abs(x - 0.5) * 2
    rib = (1 - smooth(0.08, 0.2, across)) * smooth(0.1, 0.4, t)       # light midrib, 10 px wide
    edge = smooth(0.7, 1.0, across)                                     # darker blade edge
    return tone(col, 0.35 * rib - 0.3 * edge)


def _eelring(w, h):
    x, y = _cell(w, h)
    # 16 barnacle cones around the ring in two staggered rows; wraps in x (the ring's circumference)
    base = mix(rgb("#BFE9FF"), rgb(FLOOR["dropoff_upper_slate"]), 0.35)  # pale, so the teal/dull tint reads
    s = -0.25 * smooth(0.5, 1.0, np.abs(y - 0.5) * 2)
    for row, (cy, off) in enumerate(((0.3, 0.0), (0.72, 0.5))):
        for i in range(16):
            cx = (i + off) / 16.0
            dx = wrap(x - cx) * w / h
            dy = y - cy
            d = np.hypot(dx, dy) / 0.17
            side = (dx * LIGHT_DIR[0] + dy * LIGHT_DIR[1]) / (0.17 * np.maximum(d, 1e-3))
            cone = smooth(1.0, 0.8, d)
            s += cone * (0.35 + 0.3 * np.clip(-side, 0, 1) * d)              # lit upper-left flank
            s -= 0.95 * smooth(0.42, 0.3, d)                            # the dark opening
    return tone(base, s, dark=mix(base * 0.45, rgb(FLOOR["dropoff_deep_slate"]), 0.5))


def paint_envshared(seed=61):
    rng = np.random.default_rng(seed)
    img = np.zeros((N, N, 3))
    painters = {
        "pebble_warm": lambda w, h: _pebble(w, h, FLOOR["reef_rock"], rng),
        "pebble_sand": lambda w, h: _pebble(w, h, FLOOR["reef_sand"], rng),
        "pebble_bone": lambda w, h: _pebble(w, h, hexof(mix(rgb(FLOOR["nursery_sand"]), rgb(WARM), 0.3)), rng),
        "pebble_slate": lambda w, h: _pebble(w, h, FLOOR["dropoff_upper_slate"], rng),
        "shell_scallop": _shell_scallop, "shell_cone": _shell_cone,
        "shell_inner": _shell_inner, "shell_cockle": _shell_cockle,
        "seagrass_nursery": lambda w, h: _seagrass(w, h, FLOOR["kelp_rock"], "#9FF0E6", 0.45),
        "seagrass_reef": lambda w, h: _seagrass(w, h, "#17604F", "#8FE0A0", 0.5),
        "seagrass_kelp": lambda w, h: _seagrass(w, h, "#17604F", FLOOR["kelp_silt"], 0.4),
        "seagrass_current": lambda w, h: _seagrass(w, h, FLOOR["kelp_rock"], "#BFE9FF", 0.55),
        "eelhole_ring": _eelring,
    }
    for name, (x, y, w, h) in ATLAS_CELLS.items():
        img[y:y + h, x:x + w] = np.clip(painters[name](w, h), 0, 1)
    return img


PAINTERS = {
    "T_Tile_Sand_Alb": paint_sand, "T_Tile_Rock_Alb": paint_rock,
    "T_Tile_CoralRock_Alb": paint_coralrock, "T_Tile_Slate_Alb": paint_slate,
    "T_EnvShared_Alb": paint_envshared,
}
TILES = tuple(k for k in PAINTERS if k.startswith("T_Tile_"))


# ---------------------------------------------------------------- checks
def seam(img8):
    """Wrap-around difference: mean |left column - right column| (and top/bottom), in 8-bit levels,
    against the mean and max difference between neighbouring interior columns (rows)."""
    a = img8[..., :3].astype(float)
    out = {}
    for axis, name in ((1, "x"), (0, "y")):
        inner = np.abs(np.diff(a, axis=axis)).mean(axis=(1 - axis, 2))
        first, last = np.take(a, 0, axis=axis), np.take(a, -1, axis=axis)
        w = float(np.abs(first - last).mean())
        out[name] = {"wrap": round(w, 3), "inner_mean": round(float(inner.mean()), 3),
                     "inner_max": round(float(inner.max()), 3), "ratio": round(float(w / max(inner.mean(), 1e-6)), 3)}
    return out


def box_blur(a, r):
    """Wrap-around box blur of radius r (pixels) on a 2D array."""
    out = a.copy()
    for axis in (0, 1):
        acc = np.zeros_like(out)
        for k in range(-r, r + 1):
            acc += np.roll(out, k, axis=axis)
        out = acc / (2 * r + 1)
    return out


def stats(img8, target=None):
    c = img8[..., :3].astype(float) / 255.0
    L = lstar(c)
    mean = c.reshape(-1, 3).mean(0)
    fine = float(np.abs(L - box_blur(L, MIN_MARK_PX // 4)).mean())      # energy finer than a brush mark
    hsv_max = c.max(-1)
    sat = np.where(hsv_max > 0, (hsv_max - c.min(-1)) / np.maximum(hsv_max, 1e-6), 0)
    neon = int(((sat > 0.85) & (hsv_max > 0.95)).sum())
    sig = min(float(np.sqrt(((c - rgb(h)) ** 2).sum(-1)).min()) for h in SIGNAL)
    out = {"mean": hexof(mean), "L_p5": round(float(np.percentile(L, 5)), 1),
           "L_p50": round(float(np.percentile(L, 50)), 1), "L_p95": round(float(np.percentile(L, 95)), 1),
           "fine_noise_L": round(fine, 2), "neon_px": neon, "min_dist_to_signal": round(sig, 3)}
    if target is not None:
        out["target"] = hexof(target)
        out["mean_err_8bit"] = round(float(np.abs(mean - target).max() * 255), 2)
    med = np.median(L)
    out["shares"] = {"dark(<med-12)": round(float((L < med - 12).mean()), 3),
                     "mid": round(float(((L >= med - 12) & (L <= med + 8)).mean()), 3),
                     "light(>med+8)": round(float((L > med + 8).mean()), 3)}
    return out


def validate(name, img8):
    """Problems as strings; empty means pass."""
    bad = []
    h, w = img8.shape[:2]
    if (w, h) != (N, N):
        bad.append("size %dx%d, want %d" % (w, h, N))
    st = stats(img8, base_of(name) if name in TILES else None)
    if st["neon_px"]:
        bad.append("%d px break the saturated-not-neon rule (06 4.1)" % st["neon_px"])
    if st["min_dist_to_signal"] < 0.06:
        bad.append("a texel sits on a reserved signal colour (06 4.5)")
    if st["fine_noise_L"] > 1.5:
        bad.append("fine noise %.2f L* (> 1.5): finer than a brush mark (06 5.2)" % st["fine_noise_L"])
    if name in TILES:
        sm = seam(img8)
        for ax in "xy":
            if sm[ax]["wrap"] > sm[ax]["inner_max"] or sm[ax]["ratio"] > 1.5:
                bad.append("seam %s: wrap %.2f vs inner mean %.2f" % (ax, sm[ax]["wrap"], sm[ax]["inner_mean"]))
        if st["mean_err_8bit"] > 1.5:
            bad.append("mean %s off target %s" % (st["mean"], st["target"]))
    return bad, st
