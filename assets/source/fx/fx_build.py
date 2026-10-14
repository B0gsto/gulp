#!/usr/bin/env python3
"""First effects (sprint task S4-A1): T_FX_Bubble_Mask, T_FX_Star_Mask and the emitter settings of
FX_BiteChomp, FX_BubblePop_T0 and FX_BubblePop_T1T2.

    python3 assets/source/fx/fx_build.py             textures, FX_*.json and the review strips
    python3 assets/source/fx/fx_build.py --check     validate fx_defs.json only (no files written)

Rules: docs/07-asset-list.md section 9 (rows, sizes, budgets; an effect is FX_*.json plus textures),
docs/06-art-bible.md section 11 (chunky and graphic: "a bubble is a ring with one highlight dot, a star
has four fat points"; few, big, short; additive only for light; greyscale sheets coloured by the
emitter; 4 px gutter in every cell; size an exact multiple of the grid).

Writes (all git-ignored):
    assets/export/textures/T_FX_Bubble_Mask.png, T_FX_Star_Mask.png    256 x 256, 2 x 2, greyscale + alpha
    assets/export/fx/FX_<name>.json                                     emitter settings for Render/Fx
    assets/review/fx/FX_<name>_strip.png                                every 30 fps frame of the effect
    assets/review/fx/fx_contact.png                                     textures + all strips, two waters

The preview is a Python re-implementation of the parts of ParticleEmitter these effects use (burst from
an Attachment, spread cone, Speed, Drag as half-life, Acceleration, Size/Transparency/Color sequences,
Rotation, flipbook cell, LightEmission blend). It is a review aid, not the engine.
Needs Pillow and numpy in the system python3. Deterministic (fixed seeds).
"""
import json
import math
import os
import random
import re
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.dirname(os.path.dirname(HERE))
DEFS = os.path.join(HERE, "fx_defs.json")
TEX_DIR = os.path.join(ASSETS, "export", "textures")
FX_DIR = os.path.join(ASSETS, "export", "fx")
REVIEW = os.path.join(ASSETS, "review", "fx")

SHEET, GRID, GUTTER, SS = 256, 2, 4, 4          # 07 9.1: 256², 2x2; 06 11.3: 4 px gutter; supersampling
CELL = SHEET // GRID
TEXTURES = ("T_FX_Bubble_Mask", "T_FX_Star_Mask")
RE_FX = re.compile(r"^FX_(?:(?:UI|Amb)_)?[A-Z][A-Za-z0-9]*(?:_[A-Z0-9][A-Za-z0-9]*)?$")   # 07 1.2
FPS = 30
# 06 section 4.2 water (top, mid) for the preview backgrounds; 4.3 / 4.5 colours for the stand-ins.
WATERS = {"Sunlit Reef": ("#6FDDEE", "#1E9FD0"), "Drop-off deep": ("#0B2A66", "#081C4D")}
MINNOW_MID, MINNOW_DARK, KRILL_MID, PLANKTON = "#FF9A3D", "#922700", "#FF8C7A", "#D9FFE8"
LIME = "#A6FF3D"


# ---------------------------------------------------------------- textures

def _cell_canvas():
    n = CELL * SS
    return np.zeros((n, n), np.float32), np.zeros((n, n), np.float32), n


def _grid(n):
    c = (n - 1) / 2.0
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    return (x - c) / (n / 2.0), (y - c) / (n / 2.0)       # -1..1, y down


def _over(dst_v, dst_a, v, a):
    """Composite a greyscale layer (value, alpha) over the cell (premultiplied maths)."""
    out_a = a + dst_a * (1 - a)
    out_v = np.where(out_a > 1e-6, (v * a + dst_v * dst_a * (1 - a)) / np.maximum(out_a, 1e-6), 0)
    return out_v, out_a


def _smooth(d, w):
    """Antialiased step: 1 inside (d < 0), 0 outside, over a band w (in cell units)."""
    return np.clip(0.5 - d / w, 0, 1)


def bubble_cell(shape):
    """06 11.1: a ring with one highlight dot. Shapes: 0 round, 1 squashed, 2 wobbly, 3 round with a
    crescent highlight. Usable radius leaves the 4 px gutter plus a little air."""
    v, a, n = _cell_canvas()
    x, y = _grid(n)
    r_max = 1.0 - 2.0 * (GUTTER + 3) / CELL
    aa = 2.5 / (n / 2.0)
    ang = np.arctan2(y, x)
    if shape == 1:                                       # squashed, tilted
        t = math.radians(-18)
        xr, yr = x * math.cos(t) + y * math.sin(t), -x * math.sin(t) + y * math.cos(t)
        rr = np.sqrt((xr / 1.0) ** 2 + (yr / 0.84) ** 2)
        R = r_max
    elif shape == 2:                                     # wobbly: a soft three-lobe wobble
        rr = np.sqrt(x * x + y * y) / (1 + 0.045 * np.cos(3 * ang + 0.7) + 0.025 * np.cos(5 * ang))
        R = r_max * 0.93
    else:
        rr = np.sqrt(x * x + y * y)
        R = r_max * (0.97 if shape == 0 else 0.9)
    d = rr - R                                           # signed distance-ish (cell units)
    inside = _smooth(d, aa)
    thick = 0.16 * R
    # body: faint, stronger towards the rim (reads as a sphere, not a disc)
    body_a = inside * (0.10 + 0.22 * np.clip((rr / R), 0, 1) ** 4)
    v, a = _over(v, a, np.full_like(v, 0.92), body_a)
    # outer edge: a thin mid-grey line so the white ring still separates from bright water
    edge = inside * _smooth(-(d + thick * 0.28), aa)
    v, a = _over(v, a, np.full_like(v, 0.62), edge)
    # the ring
    ring = _smooth(np.abs(d + thick * 0.64) - thick * 0.36, aa)      # white band inside the grey edge
    v, a = _over(v, a, np.ones_like(v), ring * inside)
    # highlight: one fat dot upper left (plus a tiny second one for shape 0 and 2)
    hx, hy = -0.36 * R, -0.38 * R
    if shape == 3:                                       # crescent highlight along the upper-left rim
        rim = _smooth(np.abs(rr - R * 0.66) - 0.07 * R, aa)
        sector = np.clip((np.cos(ang - math.radians(-135)) - 0.55) / 0.25, 0, 1)
        v, a = _over(v, a, np.ones_like(v), rim * sector)
        dot = _smooth(np.sqrt((x - 0.30 * R) ** 2 + (y - 0.42 * R) ** 2) - 0.07 * R, aa)
        v, a = _over(v, a, np.ones_like(v), dot * 0.9)
    else:
        sx, sy = (1.0, 0.72) if shape != 1 else (1.0, 0.62)
        t = math.radians(-40)
        dx, dy = x - hx, y - hy
        ex, ey = dx * math.cos(t) + dy * math.sin(t), -dx * math.sin(t) + dy * math.cos(t)
        dot = _smooth(np.sqrt((ex / sx) ** 2 + (ey / sy) ** 2) - 0.2 * R, aa)
        v, a = _over(v, a, np.ones_like(v), dot)
        if shape in (0, 2):
            d2 = _smooth(np.sqrt((x + 0.07 * R) ** 2 + (y + 0.6 * R) ** 2) - 0.07 * R, aa)
            v, a = _over(v, a, np.ones_like(v), d2)
    return v, a


def _star_r(ang, n_pts, r_in, r_out, k):
    """Radius of a star with n fat points: smooth valleys, rounded tips."""
    c = np.abs(np.cos(ang * n_pts / 2.0))
    return r_in + (r_out - r_in) * c ** k


def star_cell(kind):
    """0 fat four-point star (the pop star and glints), 1 sparkle (four points plus four short ones),
    2 slim glint, 3 plus. White with a soft grey rim, plus a faint halo; the emitter colours it."""
    v, a, n = _cell_canvas()
    x, y = _grid(n)
    r_max = 1.0 - 2.0 * (GUTTER + 2) / CELL
    aa = 2.5 / (n / 2.0)
    rr = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    if kind == 0:
        R = _star_r(ang, 4, 0.34 * r_max, r_max, 2.2)
    elif kind == 1:
        R = np.maximum(_star_r(ang, 4, 0.24 * r_max, r_max, 3.0),
                       _star_r(ang + math.pi / 4, 4, 0.2 * r_max, 0.52 * r_max, 3.0))
    elif kind == 2:
        R = _star_r(ang, 4, 0.12 * r_max, r_max, 6.0)
    else:
        ax, ay = np.abs(x), np.abs(y)
        arm = 0.2 * r_max
        d_h = np.maximum(ax - (r_max - arm), ay - arm)       # rounded-end bars via offset boxes
        d_v = np.maximum(ay - (r_max - arm), ax - arm)
        d = np.minimum(d_h, d_v)
        R = None
    if R is not None:
        d = (rr - R) * (0.55 + 0.45 * np.clip(R / r_max, 0, 1))   # keep the AA band even along the points
    # halo: very faint, only for the light uses; kept inside the cell
    halo = np.clip(1 - rr / (r_max * 0.95), 0, 1) ** 2.2 * 0.22
    v, a = _over(v, a, np.ones_like(v), halo)
    shape = _smooth(d, aa)
    v, a = _over(v, a, np.full_like(v, 0.72), shape)                 # soft grey rim
    core = _smooth(d + 0.035, aa)
    v, a = _over(v, a, np.ones_like(v), core)
    hot = np.clip(1 - rr / (0.30 * r_max), 0, 1) ** 1.5              # bright centre (already white; adds alpha)
    v, a = _over(v, a, np.ones_like(v), hot * shape)
    return v, a


def build_sheet(cell_fn):
    rgba = np.zeros((SHEET, SHEET, 4), np.uint8)
    for i in range(GRID * GRID):
        v, a = cell_fn(i)
        img = Image.fromarray(np.dstack([v * 255, a * 255]).clip(0, 255).astype(np.uint8))
        img = img.resize((CELL, CELL), Image.LANCZOS)
        arr = np.asarray(img).astype(np.uint8)
        # enforce the gutter: nothing inside the 4 px border of the cell
        arr = arr.copy()
        arr[:GUTTER, :, 1] = 0
        arr[-GUTTER:, :, 1] = 0
        arr[:, :GUTTER, 1] = 0
        arr[:, -GUTTER:, 1] = 0
        r, c = divmod(i, GRID)
        blk = rgba[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL]
        blk[..., 0] = blk[..., 1] = blk[..., 2] = arr[..., 0]
        blk[..., 3] = arr[..., 1]
        blk[blk[..., 3] == 0, :3] = 255                  # white under clear pixels: no dark fringes when filtered
    return Image.fromarray(rgba)


def build_textures():
    os.makedirs(TEX_DIR, exist_ok=True)
    out = {}
    for name, fn in (("T_FX_Bubble_Mask", bubble_cell), ("T_FX_Star_Mask", star_cell)):
        img = build_sheet(fn)
        path = os.path.join(TEX_DIR, name + ".png")
        img.save(path)
        out[name] = img
    return out


# ---------------------------------------------------------------- definitions

REQUIRED = ("EmissionDirection", "SpreadAngle", "Speed", "Drag", "Acceleration", "Lifetime", "Size",
            "Transparency", "Color", "Rotation", "RotSpeed", "LightEmission", "LightInfluence",
            "FlipbookLayout", "FlipbookMode", "FlipbookFramerate", "FlipbookStartRandom")


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def validate(defs):
    errs = []
    for name, fx in defs["effects"].items():
        if not RE_FX.match(name):
            errs.append("%s: name breaks 07 section 1.2" % name)
        total = sum(e["burst"] for e in fx["emitters"])
        if total > fx["budget"]:
            errs.append("%s: %d particles over the budget of %d" % (name, total, fx["budget"]))
        for e in fx["emitters"]:
            p = e["props"]
            where = "%s.%s" % (name, e["name"])
            for k in REQUIRED:
                if k not in p:
                    errs.append("%s: missing %s" % (where, k))
            if e.get("texture") not in TEXTURES:
                errs.append("%s: texture %r is not one of this task's sheets (never the default image)" % (where, e.get("texture")))
            if p.get("Lifetime", [0, 0])[1] > fx["lifetime"] + 1e-6:
                errs.append("%s: lifetime over the effect's %.2f s" % (where, fx["lifetime"]))
            if p.get("Lifetime", [0, 0])[1] >= 1.0 / p.get("FlipbookFramerate", [1, 1])[0]:
                errs.append("%s: lives long enough to change flipbook cell" % where)
            for seq in ("Size", "Transparency"):
                ts = [k[0] for k in p.get(seq, [])]
                if not ts or ts[0] != 0 or ts[-1] != 1 or ts != sorted(ts):
                    errs.append("%s: %s keypoints must run 0..1 in order" % (where, seq))
            le = p.get("LightEmission", 0)
            light = e["name"] in ("Glint", "Glints")
            if le > 0 and not light:
                errs.append("%s: additive blending is for light only (06 11.1 rule 4)" % where)
            for _, col in p.get("Color", []):
                hexrgb(col)
    return errs


def export_defs(defs):
    os.makedirs(FX_DIR, exist_ok=True)
    for name, fx in defs["effects"].items():
        doc = {"name": name, "schema": 1, "source": "assets/source/fx/fx_defs.json"}
        doc.update(fx)
        with open(os.path.join(FX_DIR, name + ".json"), "w", encoding="utf-8") as f:
            json.dump(doc, f, indent=2)
            f.write("\n")


# ---------------------------------------------------------------- preview simulation

def seq_eval(seq, t):
    for i in range(len(seq) - 1):
        t0, t1 = seq[i][0], seq[i + 1][0]
        if t0 <= t <= t1:
            u = 0 if t1 == t0 else (t - t0) / (t1 - t0)
            v0, v1 = seq[i][1], seq[i + 1][1]
            if isinstance(v0, str):
                c0, c1 = hexrgb(v0), hexrgb(v1)
                return tuple(c0[j] + (c1[j] - c0[j]) * u for j in range(3))
            return v0 + (v1 - v0) * u
    last = seq[-1][1]
    return hexrgb(last) if isinstance(last, str) else last


DIRS = {"Front": (1, 0, 0), "Top": (0, 1, 0)}            # preview: the mouth faces +x (screen right)


def spawn(e, rng):
    p = e["props"]
    out = []
    for _ in range(e["burst"]):
        base = DIRS[p["EmissionDirection"]]
        sx, sy = [math.radians(s) for s in p["SpreadAngle"]]
        # random direction within the spread cone around base (yaw by sx, pitch by sy)
        yaw, pitch = rng.uniform(-sx, sx), rng.uniform(-sy, sy)
        if base == (1, 0, 0):
            d = (math.cos(pitch) * math.cos(yaw), math.sin(pitch), math.cos(pitch) * math.sin(yaw))
        else:
            d = (math.sin(pitch) * math.cos(yaw), math.cos(pitch), math.sin(pitch) * math.sin(yaw))
        spd = rng.uniform(*p["Speed"])
        env = rng.random()
        out.append({
            "e": e, "pos": [0.0, 0.0, 0.0], "vel": [d[0] * spd, d[1] * spd, d[2] * spd],
            "life": rng.uniform(*p["Lifetime"]), "rot": rng.uniform(*p["Rotation"]),
            "rs": rng.uniform(*p["RotSpeed"]), "env": env,
            "cell": rng.randrange(4) if p["FlipbookStartRandom"] else 0,
        })
    return out


def sim(fx, seed, frames):
    rng = random.Random(seed)
    parts = []
    for e in fx["emitters"]:
        parts += spawn(e, rng)
    dt = 1.0 / FPS
    states = []
    for f in range(frames):
        t = f * dt
        snap = []
        for q in parts:
            if t <= q["life"]:
                snap.append((q, t / q["life"], list(q["pos"]), q["rot"]))
        states.append(snap)
        sub = 8
        for _ in range(sub):                              # integrate to the next frame
            h = dt / sub
            for q in parts:
                p = q["e"]["props"]
                acc = p["Acceleration"]
                for k in range(3):
                    q["vel"][k] += acc[k] * h
                damp = 0.5 ** (p["Drag"] * h)
                for k in range(3):
                    q["vel"][k] *= damp
                    q["pos"][k] += q["vel"][k] * h
                q["rot"] += q["rs"] * h
    return states


def tex_cell(tex, cell):
    r, c = divmod(cell, GRID)
    return tex.crop((c * CELL, r * CELL, (c + 1) * CELL, (r + 1) * CELL))


def water(size, top, bottom):
    t, b = np.array(hexrgb(top)), np.array(hexrgb(bottom))
    ramp = np.linspace(0, 1, size)[:, None, None]
    img = (t * (1 - ramp) + b * ramp) * np.ones((size, size, 3))
    return img.astype(np.float32)


def stand_in(canvas, kind, pps, cx, cy):
    """Flat stand-in for what the effect sits on, so scale reads: the Minnow's head for a bite,
    Krill or Plankton for a pop (drawn on frame 0 only for pops)."""
    img = Image.fromarray((canvas * 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    if kind == "eater":
        # head of a 3-stud Minnow, mouth at the emitter: an ellipse ending at the mouth
        L, H = 1.8 * pps, 1.365 * pps
        d.ellipse((cx - L * 1.05, cy - H / 2, cx + 0.05 * pps, cy + H / 2), fill=MINNOW_MID, outline=MINNOW_DARK, width=3)
        ex, ey = cx - 0.55 * pps, cy - 0.18 * pps
        d.ellipse((ex - 0.2 * pps, ey - 0.2 * pps, ex + 0.2 * pps, ey + 0.2 * pps), fill="white")
        d.ellipse((ex - 0.08 * pps, ey - 0.1 * pps, ex + 0.12 * pps, ey + 0.1 * pps), fill="#1A1A1A")
    elif kind == "prey":
        L, H = 0.8 * pps, 0.38 * pps
        d.ellipse((cx - L / 2, cy - H / 2, cx + L / 2, cy + H / 2), fill=KRILL_MID, outline="#952028", width=2)
    elif kind == "plankton":
        r = 0.2 * pps
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=PLANKTON)
    return np.asarray(img).astype(np.float32) / 255.0


def render_frame(snap, textures, size, pps, bg, kind, first):
    cx, cy = size * (0.42 if kind == "eater" else 0.5), size * 0.56
    canvas = water(size, *bg)
    if kind == "eater" or first:
        canvas = stand_in(canvas, kind, pps, cx, cy)
    for q, u, pos, rot in sorted(snap, key=lambda s: s[0]["e"]["props"].get("ZOffset", 0)):
        p = q["e"]["props"]
        sz = seq_eval(p["Size"], u)
        env = [k[2] for k in p["Size"]]
        sz += (q["env"] * 2 - 1) * seq_eval([[k[0], k[2]] for k in p["Size"]], u) if any(env) else 0
        tr = seq_eval(p["Transparency"], u)
        col = seq_eval(p["Color"], u)
        px = int(round(sz * pps))
        if px < 2 or tr >= 0.999:
            continue
        cell = tex_cell(textures[q["e"]["texture"]], q["cell"]).resize((px, px), Image.LANCZOS).rotate(-rot, Image.BICUBIC)
        arr = np.asarray(cell).astype(np.float32) / 255.0
        rgb, al = arr[..., :3] * np.array(col) * p.get("Brightness", 1), arr[..., 3] * (1 - tr)
        x0, y0 = int(round(cx + pos[0] * pps - px / 2)), int(round(cy - pos[1] * pps - px / 2))
        xs, ys = slice(max(x0, 0), min(x0 + px, size)), slice(max(y0, 0), min(y0 + px, size))
        sub_rgb = rgb[ys.start - y0:ys.stop - y0, xs.start - x0:xs.stop - x0]
        sub_a = al[ys.start - y0:ys.stop - y0, xs.start - x0:xs.stop - x0][..., None]
        dst = canvas[ys, xs]
        le = p.get("LightEmission", 0)
        normal = dst * (1 - sub_a) + sub_rgb * sub_a
        additive = dst + sub_rgb * sub_a
        canvas[ys, xs] = np.clip(normal * (1 - le) + additive * le, 0, 1)
    return canvas


def font(sz):
    for f in ("/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc"):
        if os.path.exists(f):
            return ImageFont.truetype(f, sz)
    return ImageFont.load_default()


def strip(name, fx, textures, bg, size=192):
    frames = int(math.ceil(fx["lifetime"] * FPS)) + 1
    states = sim(fx, seed=sum(map(ord, name)), frames=frames)
    kind = {"eater": "eater", "prey": "prey"}.get(fx["scaleWith"], "plankton")
    pps = {"eater": 70, "prey": 90}.get(fx["scaleWith"], 150)
    lab = 18
    out = Image.new("RGB", (size * frames, size + lab), "#222428")
    d = ImageDraw.Draw(out)
    for i, snap in enumerate(states):
        fr = render_frame(snap, textures, size, pps, bg, kind, i == 0)
        out.paste(Image.fromarray((fr * 255).astype(np.uint8)), (i * size, lab))
        d.text((i * size + 4, 2), "f%d  %.0f ms  %d live" % (i, i * 1000.0 / FPS, len(snap)), fill="#DDDDDD", font=font(12))
    return out


def texture_panel(textures):
    pad, lab = 12, 20
    w = 2 * (SHEET * 2 + pad) + pad
    panel = Image.new("RGB", (w, SHEET + lab + pad), "#222428")
    d = ImageDraw.Draw(panel)
    x = pad
    for name in TEXTURES:
        tex = textures[name]
        for bgc in ("#1E9FD0", "#0B2A66"):
            tile = Image.new("RGBA", (SHEET, SHEET), bgc)
            tile.alpha_composite(tex)
            for k in range(1, GRID):
                ImageDraw.Draw(tile).line([(k * CELL, 0), (k * CELL, SHEET)], fill="#FFFFFF40")
                ImageDraw.Draw(tile).line([(0, k * CELL), (SHEET, k * CELL)], fill="#FFFFFF40")
            panel.paste(tile.convert("RGB"), (x, lab))
            x += SHEET
        d.text((x - 2 * SHEET + 4, 3), name + "  (reef / deep water)", fill="#DDDDDD", font=font(13))
        x += pad
    return panel


def previews(defs, textures):
    os.makedirs(REVIEW, exist_ok=True)
    rows = [texture_panel(textures)]
    paths = []
    for name, fx in defs["effects"].items():
        pair = []
        for wname, bg in WATERS.items():
            s = strip(name, fx, textures, bg)
            pair.append(s)
        w = max(s.width for s in pair)
        both = Image.new("RGB", (w, sum(s.height for s in pair) + 26), "#222428")
        ImageDraw.Draw(both).text((4, 4), "%s  (%d particles, %.2f s; top: Sunlit Reef water, bottom: deep Drop-off)"
                                  % (name, sum(e["burst"] for e in fx["emitters"]), fx["lifetime"]), fill="#FFFFFF", font=font(15))
        y = 26
        for s in pair:
            both.paste(s, (0, y))
            y += s.height
        path = os.path.join(REVIEW, name + "_strip.png")
        both.save(path)
        paths.append(path)
        rows.append(both)
    W = max(r.width for r in rows)
    sheet = Image.new("RGB", (W, sum(r.height for r in rows) + 8 * len(rows)), "#16171A")
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height + 8
    cpath = os.path.join(REVIEW, "fx_contact.png")
    sheet.save(cpath)
    return paths + [cpath]


def main(argv):
    with open(DEFS, "r", encoding="utf-8") as f:
        defs = json.load(f)
    errs = validate(defs)
    for e in errs:
        print("FAIL", e)
    if errs:
        return 1
    print("fx_defs.json: %d effects OK" % len(defs["effects"]))
    if "--check" in argv:
        return 0
    textures = build_textures()
    export_defs(defs)
    for p in previews(defs, textures):
        print("wrote", os.path.relpath(p, os.path.dirname(ASSETS)))
    for name in TEXTURES:
        print("wrote", os.path.relpath(os.path.join(TEX_DIR, name + ".png"), os.path.dirname(ASSETS)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
