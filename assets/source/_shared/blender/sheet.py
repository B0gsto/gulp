"""Lays out the contact sheet of docs/06-art-bible.md section 15.5 from the renders that
preview.py made: 1536 x 1536, twelve cells and a footer. Runs in the system python3
with Pillow:  python3 sheet.py <job.json>
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402

SIZE = 1536
COLS, ROWS = 4, 3
CELL_W, CELL_H = 384, 480
TITLE_H, IMG, CAPTION_H = 28, 384, 68
FOOTER_H = SIZE - ROWS * CELL_H
FOG_ZONES = ("nursery", "reef", "kelp", "dropoff_upper", "dropoff_deep", "cove")
PHONE_SIZES = (96, 48, 20, 8)


def rgb(hexcode):
    return common.hex_to_rgb255(hexcode)


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def load(job, name):
    return Image.open(os.path.join(job["dir"], name)).convert("RGBA")


def over(img, hexcode):
    bg = Image.new("RGBA", img.size, rgb(hexcode) + (255,))
    bg.alpha_composite(img)
    return bg.convert("RGB")


def cropped(img):
    box = img.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    return img.crop(box) if box else img


def fitted(img, w, h):
    scale = min(w / img.width, h / img.height)
    return img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)


def silhouette(img, size):
    alpha = img.getchannel("A").resize((size, size), Image.LANCZOS)
    out = Image.new("RGB", (size, size), (255, 255, 255))
    out.paste((0, 0, 0), (0, 0), alpha)
    return out


def outlined(sprite, hexcode, px):
    pad = px + 1
    canvas = Image.new("RGBA", (sprite.width + 2 * pad, sprite.height + 2 * pad), (0, 0, 0, 0))
    canvas.alpha_composite(sprite, (pad, pad))
    grown = canvas.getchannel("A").point(lambda a: 255 if a > 96 else 0).filter(ImageFilter.MaxFilter(2 * px + 1))
    line = Image.new("RGBA", canvas.size, rgb(hexcode) + (0,))
    line.putalpha(grown)
    line.alpha_composite(canvas)
    return line


def cell_image(job, cell):
    kind = cell["kind"]
    reef = common.colour("water.reef.fog")
    if kind == "view":
        return over(load(job, cell["image"]), reef)
    if kind == "silhouette":
        out = Image.new("RGB", (IMG, IMG), (255, 255, 255))
        for i, name in enumerate(cell["images"]):
            out.paste(silhouette(load(job, name), IMG // 2), (i * IMG // 2, IMG // 4))
        return out
    if kind == "phone":
        sprite = cropped(load(job, cell["image"]))
        out = Image.new("RGBA", (IMG, IMG), rgb(reef) + (255,))
        out.paste(rgb(common.colour("water.dropoff_deep.fog")) + (255,), (0, IMG // 2, IMG, IMG))
        for row in range(2):
            x = 24
            for length in PHONE_SIZES:
                small = sprite.resize((length, max(1, round(sprite.height * length / sprite.width))), Image.LANCZOS)
                out.alpha_composite(small, (x, row * IMG // 2 + IMG // 4 - small.height // 2))
                x += length + 40
        return out.convert("RGB")
    if kind == "fogs":
        sprite = fitted(cropped(load(job, cell["image"])), 92, 60)
        out = Image.new("RGBA", (IMG, IMG), (0, 0, 0, 255))
        w, h = IMG // 3, IMG // 4
        for i in range(12):
            zone = FOG_ZONES[i % 6]
            line = common.colour("signal.can_eat") if i < 6 else common.colour("signal.can_eat_you")
            tile = Image.new("RGBA", (w, h), rgb(common.colour("water.%s.fog" % zone)) + (255,))
            mark = outlined(sprite, line, 2)
            tile.alpha_composite(mark, ((w - mark.width) // 2, (h - mark.height) // 2))
            out.paste(tile, ((i % 3) * w, (i // 3) * h))
        return out.convert("RGB")
    if kind == "value":
        return over(load(job, cell["image"]), "#808080").convert("L").convert("RGB")
    out = Image.new("RGB", (IMG, IMG), rgb(common.colour("ui.panel_shade")))
    if kind == "legend":
        draw = ImageDraw.Draw(out)
        f = font(15)
        for i, (label, hexcode) in enumerate(cell["legend"]):
            y = 14 + i * 40
            draw.rectangle((14, y, 62, y + 30), fill=rgb(hexcode), outline=rgb(common.colour("ui.ink")))
            draw.text((74, y + 6), "%s  %s" % (hexcode, label), font=f, fill=rgb(common.colour("ui.ink")))
    return out


def build(job):
    ink, panel = rgb(common.colour("ui.ink")), rgb(common.colour("ui.panel"))
    sheet = Image.new("RGB", (SIZE, SIZE), panel)
    draw = ImageDraw.Draw(sheet)
    title_font, caption_font, footer_font = font(16), font(12), font(15)
    for i, cell in enumerate(job["cells"][:COLS * ROWS]):
        x, y = (i % COLS) * CELL_W, (i // COLS) * CELL_H
        sheet.paste(cell_image(job, cell), (x, y + TITLE_H))
        draw.text((x + 8, y + 5), "%d  %s" % (i + 1, cell["title"]), font=title_font, fill=ink)
        for n, line in enumerate(cell.get("caption", [])[:4]):
            draw.text((x + 8, y + TITLE_H + IMG + 3 + n * 15), line, font=caption_font, fill=ink)
        draw.rectangle((x, y, x + CELL_W - 1, y + CELL_H - 1), outline=ink)
    top = ROWS * CELL_H
    draw.rectangle((0, top, SIZE - 1, SIZE - 1), fill=rgb(common.colour("ui.panel_shade")), outline=ink)
    for n, line in enumerate(job["footer"][:4]):
        draw.text((12, top + 8 + n * 21), line, font=footer_font, fill=ink)
    os.makedirs(os.path.dirname(job["out"]), exist_ok=True)
    sheet.save(job["out"])
    return job["out"]


if __name__ == "__main__":
    with open(sys.argv[1], "r", encoding="utf-8") as fh:
        print(build(json.load(fh)))
