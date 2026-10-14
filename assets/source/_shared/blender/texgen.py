"""Texture side of the UV layout and atlas tools (docs/07-asset-list.md section 14.1, "UV layout
and atlas tools": pack atlases, stamp placeholders), with the numbers of
docs/06-art-bible.md sections 5.4 to 5.6. Pure Python: the rectangle maths imports anywhere
(inside Blender too); the image functions need Pillow in the system python3 (06 section 15.1).
"""
import os

# 06 section 5.4: the standard creature UV layout, (u0, v0, u1, v1) of the 0 to 1 square.
# Every family uses it; named predators may break it (they take no traits).
STANDARD_LAYOUT = {
    "body": (0.0, 0.5, 1.0, 1.0),
    "fins": (0.0, 0.25, 1.0, 0.5),
    "eye": (0.0, 0.0, 0.25, 0.25),
    "mouth": (0.25, 0.0, 0.5, 0.25),
    "teeth": (0.5, 0.0, 0.625, 0.25),
    "free": (0.625, 0.0, 1.0, 0.25),
}
FAMILY_LAYOUTS = {f: STANDARD_LAYOUT for f in ("Fish", "Eel", "Turtle", "Squid")}

# 06 section 5.6: colour texture size and target texel density (pixels per stud at body scale 1.0).
TEXTURE_CLASSES = {
    "species_juv": (256, 60), "species_adult": (512, 26), "prey_small_atlas": (256, 40),
    "prey_cell": (128, 30), "predator": (512, 24), "old_scar": (1024, 24), "trait_overlay": (256, None),
    "trait_pieces": (256, 40), "env_tiling": (512, 16), "env_kit_atlas": (512, 24), "landmark": (1024, 16),
    "cove_atlas": (512, 24), "flipbook": (512, None), "skybox_face": (512, None),
}
MAX_TEXTURE = 1024          # 06 section 5.6 and 07 section 1.4


def margin_px(size):
    """06 section 5.5: 8 pixels at 512, 4 at 256 (so 2 at 128, 16 at 1024)."""
    return max(2, size // 64)


def inner(rect, size):
    m = margin_px(size) / float(size)
    u0, v0, u1, v1 = rect
    return (u0 + m, v0 + m, u1 - m, v1 - m)


def place(layout, region, size, u=(None, None), v=(None, None)):
    """A function (fu, fv) -> (U, V) that puts a part's 0..1 parameters into `region` of the
    layout, inside the bake margin. `u` and `v` optionally pin the part to absolute U or V
    stations inside the region (06 section 5.4: nose at U 0.05, tail root at U 0.80)."""
    r = inner(FAMILY_LAYOUTS[layout][region] if isinstance(layout, str) else layout[region], size)
    u0 = max(r[0], u[0]) if u[0] is not None else r[0]
    u1 = min(r[2], u[1]) if u[1] is not None else r[2]
    v0 = max(r[1], v[0]) if v[0] is not None else r[1]
    v1 = min(r[3], v[1]) if v[1] is not None else r[3]
    return lambda fu, fv: (u0 + (u1 - u0) * min(1.0, max(0.0, fu)), v0 + (v1 - v0) * min(1.0, max(0.0, fv)))


def region_of(layout, uvs, size):
    """The region that holds every (u, v) in `uvs` inside its margin, or None."""
    eps = 1e-5
    for name, rect in (FAMILY_LAYOUTS[layout] if isinstance(layout, str) else layout).items():
        r = inner(rect, size)
        if all(r[0] - eps <= u <= r[2] + eps and r[1] - eps <= v <= r[3] + eps for u, v in uvs):
            return name
    return None


def atlas_rects(items, atlas):
    """Shelf-pack square or rectangular cells (name, w, h) in pixels into an `atlas`-pixel
    square, biggest first. Returns {name: (u0, v0, u1, v1)} in UV space (V up), and
    raises when they do not fit (06 section 5.6: four 128 cells to a 256 atlas, etc.)."""
    if atlas > MAX_TEXTURE:
        raise ValueError("atlas %d is over the %d ceiling" % (atlas, MAX_TEXTURE))
    out, x, y, row_h = {}, 0, 0, 0
    for name, w, h in sorted(items, key=lambda it: (-it[2], -it[1], it[0])):
        if x + w > atlas:
            x, y, row_h = 0, y + row_h, 0
        if y + h > atlas or w > atlas:
            raise ValueError("%s (%dx%d) does not fit in a %d atlas" % (name, w, h, atlas))
        out[name] = (x / atlas, 1.0 - (y + h) / atlas, (x + w) / atlas, 1.0 - y / atlas)
        x += w
        row_h = max(row_h, h)
    return out


# ---------------------------------------------------------------- images (Pillow)

def _pil():
    from PIL import Image, ImageDraw, ImageFont
    return Image, ImageDraw, ImageFont


def _font(size):
    _, _, ImageFont = _pil()
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def stamp(img, label=None):
    """The placeholder stamp of 07 section 16: a big "PH" across the middle, the name (or any
    label) under it, and a diagonal band, so no stand-in can ship by accident."""
    _, ImageDraw, _ = _pil()
    w, h = img.size
    draw = ImageDraw.Draw(img)
    ink = (20, 20, 20, 255)
    paper = (255, 255, 255, 255)
    band = max(2, w // 24)
    draw.line((0, h - 1, w - 1, 0), fill=paper, width=band)
    big = _font(max(8, h // 3))
    box = draw.textbbox((0, 0), "PH", font=big)
    draw.text(((w - box[2]) // 2, (h - box[3]) // 2 - h // 10), "PH", font=big, fill=ink,
              stroke_width=max(1, w // 128), stroke_fill=paper)
    if label:
        size = max(8, h // 14)
        small = _font(size)
        while size > 8 and draw.textbbox((0, 0), label, font=small)[2] > w - 8:
            size -= 1
            small = _font(size)
        box = draw.textbbox((0, 0), label, font=small)
        draw.text(((w - box[2]) // 2, int(h * 0.68)), label, font=small, fill=ink, stroke_width=1, stroke_fill=paper)
    return img


def flat(size, hexcode, label=None, rgba=False):
    Image, _, _ = _pil()
    h = hexcode.lstrip("#")
    rgb = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    w, hh = (size, size) if isinstance(size, int) else size
    img = Image.new("RGBA", (w, hh), rgb + (255,))
    return stamp(img, label) if label is not False else img


def soft_dot(size):
    """White soft round glow on transparent: the one effect texture of 07 section 16."""
    Image, _, _ = _pil()
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    px = img.load()
    c = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            r = (((x - c) ** 2 + (y - c) ** 2) ** 0.5) / c
            a = max(0.0, 1.0 - r) ** 1.6
            px[x, y] = (255, 255, 255, int(255 * a))
    return img


def pack_images(paths, atlas, cell, out):
    """Pack image files into one atlas of `atlas` pixels, each scaled to `cell` pixels.
    Returns the UV rects by file stem."""
    Image, _, _ = _pil()
    rects = atlas_rects([(os.path.splitext(os.path.basename(p))[0], cell, cell) for p in paths], atlas)
    sheet = Image.new("RGBA", (atlas, atlas), (0, 0, 0, 0))
    for p in paths:
        stem = os.path.splitext(os.path.basename(p))[0]
        u0, v0, u1, v1 = rects[stem]
        sheet.paste(Image.open(p).convert("RGBA").resize((cell, cell)), (int(u0 * atlas), int((1.0 - v1) * atlas)))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)
    return rects


def uv_map(job, out, size=768):
    """Review image of a UV layout: the regions tinted and labelled, every UV triangle drawn.
    job = {"layout": {region: rect}, "triangles": [[(u, v) x3], ...], "title": str}."""
    Image, ImageDraw, _ = _pil()
    img = Image.new("RGB", (size, size), (250, 250, 250))
    draw = ImageDraw.Draw(img)
    tints = [(255, 226, 168), (190, 230, 240), (220, 240, 200), (240, 210, 230), (230, 230, 200), (215, 215, 240)]
    to_px = lambda u, v: (u * (size - 1), (1.0 - v) * (size - 1))
    for i, (name, (u0, v0, u1, v1)) in enumerate(job["layout"].items()):
        draw.rectangle((*to_px(u0, v1), *to_px(u1, v0)), fill=tints[i % len(tints)], outline=(120, 120, 120))
        draw.text((to_px(u0, v1)[0] + 4, to_px(u0, v1)[1] + 3), name, font=_font(14), fill=(90, 90, 90))
    for tri in job["triangles"]:
        draw.polygon([to_px(u, v) for u, v in tri], outline=(30, 40, 90))
    draw.text((6, size - 20), job.get("title", ""), font=_font(14), fill=(0, 0, 0))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    img.save(out)
    return out
