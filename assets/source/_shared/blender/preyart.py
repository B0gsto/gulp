"""Shared prey art: the T_PreySmall_Alb atlas and RIG_Prey3 (task S3-A1; docs/07-asset-list.md
section 4.0 rows T_PreySmall_Alb and RIG_Prey3; docs/06-art-bible.md sections 4.1, 4.3, 5.6, 6.3, 7.6).

T_PreySmall_Alb is one 256 x 256 atlas for prey tiers 0 to 2 (06 5.6: 40 px/stud). Every build
that uses it paints the whole atlas with `atlas()`, so the file is the same whichever build
wrote it last. Cells (pixels, top-left origin):
  plankton A, B, C   32 x 32 each at (0, 0), (32, 0), (64, 0): round mote, twinkle, diatom
  krill              128 x 64 at (128, 0): side projection of body, legs and tail (left 96 px)
                     and the eye island (right 32 px)
  shrimp, sardine    reserved: (0, 64) 128 x 64 and (0, 128) 256 x 96, painted by later rows
Painted by script (06 5.2), not by hand: large soft gradients inside each value block, cool
violet shadows, warm lights, head lighter than tail, eye glints. No noise.

RIG_Prey3: Root (unweighted, at the origin) and three sway bones, Spine1, Spine2 and TailFin,
in a chain from head to tail, rest world-aligned (06 6.1). Weights blend smoothly along the
body so the sway code of 06 7.6 bends it like a fish; the head stays on Spine1.
"""
import math
import os

import bpy
import numpy as np

import common

SIZE = 256
CELLS = {   # name: (x, y, w, h) in pixels, top-left origin
    "plankton_a": (0, 0, 32, 32),
    "plankton_b": (32, 0, 32, 32),
    "plankton_c": (64, 0, 32, 32),
    "krill_body": (128, 0, 96, 64),
    "krill_eye": (224, 0, 32, 64),
    "shrimp": (0, 64, 128, 64),
    "sardine": (0, 128, 256, 96),
}
MARGIN = 4          # 06 5.5: 4 px at 256


def cell_uv(cell, fu, fv, margin=MARGIN):
    """(fu, fv) in 0..1 of a cell (fv 0 at the cell's bottom) -> atlas UV inside the margin."""
    x, y, w, h = CELLS[cell]
    u0, u1 = (x + margin) / SIZE, (x + w - margin) / SIZE
    v1, v0 = 1.0 - (y + margin) / SIZE, 1.0 - (y + h - margin) / SIZE
    return (u0 + (u1 - u0) * min(1.0, max(0.0, fu)), v0 + (v1 - v0) * min(1.0, max(0.0, fv)))


# ---------------------------------------------------------------- colour helpers

def rgb(h):
    return np.array(common.hex_to_srgb(h), dtype=float)


def mix(a, b, t):
    t = np.asarray(t, dtype=float)[..., None] if np.ndim(t) else t
    return a * (1.0 - t) + b * t


def smooth(e0, e1, x):
    t = np.clip((np.asarray(x, dtype=float) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


VIOLET = rgb("#5A4FA0")      # 06 5.2: shadows lean blue-violet, never black
WARM = rgb("#FFF6D9")        # 06 15.3 key light: lights lean yellow

PL_LIGHT, PL_MID = (common.colour("creatures.plankton." + k) for k in ("light", "mid"))
KR_LIGHT, KR_MID, KR_DARK = (common.colour("creatures.krill." + k) for k in ("light", "mid", "dark"))
INK = common.colour("ui.ink")


# ---------------------------------------------------------------- plankton (06 4.3: white and pale green, no dark)

def _plankton_shape(kind, n):
    """Alpha and white-core weight of one mote, n x n, row 0 at the top."""
    c = (n - 1) / 2.0
    yy, xx = np.mgrid[0:n, 0:n]
    dx, dy = (xx - c) / c, (yy - c) / c
    r = np.hypot(dx, dy)
    if kind == "a":          # round soft mote
        body = 1.0 - smooth(0.62, 0.92, r)
        core = 1.0 - smooth(0.22, 0.42, np.hypot(dx + 0.12, dy + 0.12))
    elif kind == "b":        # four-point twinkle
        star = np.minimum(np.abs(dx), np.abs(dy)) * 2.4 + r * 0.55
        body = np.maximum(1.0 - smooth(0.50, 0.80, star), 1.0 - smooth(0.42, 0.62, r))
        core = 1.0 - smooth(0.16, 0.34, r)
    else:                    # little diatom: a tilted oval with a bright spot
        a = math.radians(35.0)
        ex, ey = dx * math.cos(a) + dy * math.sin(a), -dx * math.sin(a) + dy * math.cos(a)
        e = np.hypot(ex / 0.92, ey / 0.52)
        body = 1.0 - smooth(0.80, 1.0, e)
        core = 1.0 - smooth(0.20, 0.40, np.hypot(ex + 0.25, ey + 0.05))
    return body, core


def paint_plankton(img, block):
    light, mid = rgb(PL_LIGHT), rgb(PL_MID)
    for kind in "abc":
        x, y, w, h = CELLS["plankton_" + kind]
        body, core = _plankton_shape(kind, w)
        col = mix(mid, light, np.clip(core * 1.2, 0.0, 1.0))
        img[y:y + h, x:x + w, :3] = col
        img[y:y + h, x:x + w, 3] = np.clip(body, 0.0, 1.0)
        block[y:y + h, x:x + w] = np.where(body > 0.5, np.where(core > 0.5, 1, 0), -1)


# ---------------------------------------------------------------- krill (06 4.3 krill row)

# Krill side projection: cell U along the body (y from Y0 to Y1), V up (z from Z0 to Z1).
KRILL_Y = (-0.42, 0.42)
KRILL_Z = (-0.24, 0.20)


def krill_body_uv(p):
    return cell_uv("krill_body", (p[1] - KRILL_Y[0]) / (KRILL_Y[1] - KRILL_Y[0]), (p[2] - KRILL_Z[0]) / (KRILL_Z[1] - KRILL_Z[0]))


def paint_krill(img, block, profile):
    """profile(y) -> (z_back, z_belly, z_centre) of the body at y; legs below z_belly, the tail fan
    past the body's end. Blocks: 0 mid, 1 light, 2 dark, 3 accent."""
    light, mid, dark, accent = rgb(KR_LIGHT), rgb(KR_MID), rgb(INK), rgb(KR_DARK)
    x, y, w, h = CELLS["krill_body"]
    ys = KRILL_Y[0] + (np.arange(w) + 0.5 - MARGIN) / (w - 2 * MARGIN) * (KRILL_Y[1] - KRILL_Y[0])
    zs = KRILL_Z[1] - (np.arange(h) + 0.5 - MARGIN) / (h - 2 * MARGIN) * (KRILL_Z[1] - KRILL_Z[0])
    Y, Z = np.meshgrid(ys, zs)
    back, belly, centre, legs_top = (np.vectorize(lambda yy, i=i: profile(yy)[i])(Y) for i in range(4))
    t = np.clip((Y - KRILL_Y[0]) / (KRILL_Y[1] - KRILL_Y[0]), 0.0, 1.0)      # 0 at the nose
    s = np.clip((Z - belly) / np.maximum(back - belly, 1e-3), 0.0, 1.0)       # 0 belly, 1 back
    # mid: the head lightest and warmest, cooler and a touch violet toward the tail (06 4.1)
    m = mix(mid, mix(mid, WARM, 0.18), 1.0 - smooth(0.15, 0.55, t))
    m = mix(m, mix(mid, VIOLET, 0.16), smooth(0.45, 1.0, t))
    m = mix(m, mix(m, VIOLET, 0.10), 1.0 - smooth(0.35, 0.75, s))            # cool lower flank
    l = mix(light, WARM, 0.25 * (1.0 - t))
    is_light = s < 0.18
    col = np.where(is_light[..., None], l, m)
    blk = np.where(is_light, 1, 0)
    # the segment bands across the back (krill dark, a thin accent) behind the head
    seg = (t > 0.36) & (t < 0.86) & (s > 0.72) & (np.abs(((t - 0.36) / 0.1) % 1.0 - 0.5) < 0.11)
    col = np.where(seg[..., None], accent, col)
    blk = np.where(seg, 3, blk)
    # a wet highlight along the top of the head (inside the mid block's 12 L* band)
    hi = (s > 0.80) & (t > 0.10) & (t < 0.34)
    col = np.where(hi[..., None], mix(col, WARM, 0.22), col)
    # legs: everything under the belly line is the leg fringe (dark, violet-navy, lighter tips)
    # the top of the comb, next to the belly, stays body colour; the fringe below it is dark
    leg = Z < legs_top - 0.035
    col = np.where(((Z < legs_top) & ~leg)[..., None], mix(m, VIOLET, 0.12), col)
    blk = np.where((Z < legs_top) & ~leg, 0, blk)
    lc = mix(dark, mix(dark, rgb(KR_MID), 0.22), smooth(0.0, 1.0, (legs_top - 0.035 - Z) / 0.10))
    col = np.where(leg[..., None], lc, col)
    blk = np.where(leg, 2, blk)
    # tail fan past the body's end: mid with an accent rim
    fan = t > 0.90
    fan_rim = fan & ((t > 0.975) | (np.abs(Z - centre) > 0.055))
    col = np.where(fan[..., None], mix(mid, VIOLET, 0.14), col)
    blk = np.where(fan, 0, blk)
    col = np.where(fan_rim[..., None], accent, col)
    blk = np.where(fan_rim, 3, blk)
    img[y:y + h, x:x + w, :3] = col
    img[y:y + h, x:x + w, 3] = 1.0
    block[y:y + h, x:x + w] = blk
    # eye island: ink with a big white glint up and forward, a small one behind
    x, y, w, h = CELLS["krill_eye"]
    yy, xx = np.mgrid[0:h, 0:w]
    fu = (xx + 0.5 - MARGIN) / (w - 2 * MARGIN)
    fv = 1.0 - (yy + 0.5 - MARGIN) / (h - 2 * MARGIN)
    g1 = np.hypot((fu - 0.30) / 0.19, (fv - 0.70) / 0.12) < 1.0
    g2 = np.hypot((fu - 0.62) / 0.07, (fv - 0.46) / 0.04) < 1.0
    eye = np.broadcast_to(dark, (h, w, 3)).copy()
    eye[g1 | g2] = rgb("#FFFFFF")
    img[y:y + h, x:x + w, :3] = eye
    img[y:y + h, x:x + w, 3] = 1.0
    block[y:y + h, x:x + w] = np.where(g1 | g2, 1, 2)


def krill_eye_uv(fu, fv):
    return cell_uv("krill_eye", fu, fv)


# ---------------------------------------------------------------- the atlas

def atlas(krill_profile=None):
    """RGBA float image (row 0 at the top) and block map of T_PreySmall_Alb, every cell made so far."""
    img = np.zeros((SIZE, SIZE, 4))
    block = np.full((SIZE, SIZE), -1, dtype=int)
    paint_plankton(img, block)
    if krill_profile:
        paint_krill(img, block, krill_profile)
    # bleed opaque cells into their margins (06 5.5); the plankton keep their soft alpha
    return img, block


def save_rgba(path, img):
    """Writes an RGBA PNG through Blender (row 0 of `img` is the top)."""
    h, w = img.shape[:2]
    name = os.path.basename(path)[:-4] + "_out"
    old = bpy.data.images.get(name)
    if old:
        bpy.data.images.remove(old)
    im = bpy.data.images.new(name, w, h, alpha=True)
    im.pixels.foreach_set(np.clip(img[::-1], 0.0, 1.0).astype(np.float32).ravel())
    im.filepath_raw = path
    im.file_format = 'PNG'
    im.save()
    return w, h


def sampler(block):
    """For validate's value check: (block name, sRGB) of the atlas texel at (u, v)."""
    names = {0: "mid", 1: "light", 2: "dark", 3: "accent"}

    def at(img):
        def sample(u, v):
            r = min(SIZE - 1, max(0, int((1.0 - v) * SIZE)))
            c = min(SIZE - 1, max(0, int(u * SIZE)))
            return names.get(int(block[r, c]), "none"), tuple(float(x) for x in img[r, c, :3])
        return sample
    return at


def material(name, path, alpha=False):
    """Matte as in game (06 5.1): the atlas colour, alpha for the billboard."""
    image = bpy.data.images.load(path, check_existing=False)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = 'Linear'
    bsdf.inputs["Roughness"].default_value = 0.85
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if alpha:
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        emit = bsdf.inputs.get("Emission Color")
        if emit is not None:          # 03: plankton twinkles; a soft self-light so it reads in dark water
            nt.links.new(tex.outputs["Color"], emit)
            bsdf.inputs["Emission Strength"].default_value = 0.35
        if hasattr(mat, "blend_method"):
            try:
                mat.blend_method = 'BLEND'
            except Exception:
                pass
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


# ---------------------------------------------------------------- RIG_Prey3

def prey3_bones(length):
    """Root at the origin; Spine1 behind the head, Spine2 at mid-body, TailFin at the tail root.
    Nose on -Y (06 6.1)."""
    L = length
    return [
        {"name": "Root", "head": (0.0, 0.0, 0.0), "deform": True},
        {"name": "Spine1", "head": (0.0, -0.12 * L, 0.0), "parent": "Root"},
        {"name": "Spine2", "head": (0.0, 0.10 * L, 0.0), "parent": "Spine1"},
        {"name": "TailFin", "head": (0.0, 0.30 * L, 0.0), "parent": "Spine2"},
    ]


def prey3_weights(length):
    """Smooth weights along the body (y): head on Spine1, mid on Spine2, tail on TailFin."""
    L = length
    stations = [("Spine1", -0.12 * L), ("Spine2", 0.10 * L), ("TailFin", 0.30 * L)]

    def weights(p, q=None):
        y = p[1]
        if y <= stations[0][1]:
            return {"Spine1": 1.0}
        if y >= stations[-1][1]:
            return {"TailFin": 1.0}
        for (a, ya), (b, yb) in zip(stations, stations[1:]):
            if ya <= y <= yb:
                t = float(smooth(0.0, 1.0, (y - ya) / (yb - ya)))
                return {a: 1.0 - t, b: t} if 0.0 < t < 1.0 else ({a: 1.0} if t <= 0.0 else {b: 1.0})
        return {"Spine2": 1.0}
    return weights


def sway_pose(phase, amp=1.0):
    """06 7.6 code-driven sway on three bones: a travelling wave, bigger toward the tail. Degrees of yaw."""
    out = {}
    for i, (bone, gain) in enumerate((("Spine1", 4.0), ("Spine2", 9.0), ("TailFin", 16.0))):
        out[bone] = {"rot": (0.0, 0.0, amp * gain * math.sin(phase - 0.9 * i))}
    return out
