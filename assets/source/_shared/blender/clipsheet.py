"""Lays out a clip's review files (docs/06-art-bible.md section 15.5: "a strip of key poses plus a
2-second, 384-pixel clip") from the frames clips.py rendered. System python3 with Pillow
(Blender's Python has none).

    python3 clipsheet.py <job.json>
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

BACKDROP = (46, 111, 142)      # a flat water blue behind the transparent renders
INK = (245, 245, 240)
LABEL_H = 28
ROW_LABEL_W = 70


def font(size):
    for path in ("/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def flat(path, size):
    img = Image.open(path).convert("RGBA").resize((size, size), Image.LANCZOS)
    back = Image.new("RGBA", img.size, BACKDROP + (255,))
    return Image.alpha_composite(back, img).convert("RGB")


def strip(job):
    size, rows, labels = job["size"], job["rows"], job["labels"]
    cols = len(labels)
    footer_h = 22 * len(job["footer"]) + 12
    w = ROW_LABEL_W + cols * size
    h = LABEL_H + len(rows) * size + footer_h
    sheet = Image.new("RGB", (w, h), (24, 28, 36))
    draw = ImageDraw.Draw(sheet)
    small = font(16)
    for c, text in enumerate(labels):
        draw.text((ROW_LABEL_W + c * size + 8, 5), text, fill=INK, font=small)
    for r, row in enumerate(rows):
        y = LABEL_H + r * size
        draw.text((8, y + size // 2 - 8), row["view"], fill=INK, font=small)
        for c, path in enumerate(row["frames"]):
            sheet.paste(flat(path, size), (ROW_LABEL_W + c * size, y))
    y = LABEL_H + len(rows) * size + 6
    for line in job["footer"]:
        draw.text((8, y), line[:220], fill=INK, font=font(14))
        y += 22
    os.makedirs(os.path.dirname(job["strip"]), exist_ok=True)
    sheet.save(job["strip"])


def gif(job):
    size = job["size"]
    cache, frames = {}, []
    for path in job["clip_frames"]:
        if path not in cache:
            img = flat(path, size)
            ImageDraw.Draw(img).text((8, 6), job["name"], fill=INK, font=font(14))
            cache[path] = img.convert("P", palette=Image.ADAPTIVE, colors=128)
        frames.append(cache[path])
    # GIF delays are in 1/100 s: 3, 3, 4 per three frames is exactly 30 frames a second
    durations = [40 if i % 3 == 2 else 30 for i in range(len(frames))]
    frames[0].save(job["gif"], save_all=True, append_images=frames[1:], duration=durations, loop=0, disposal=1)


def main():
    with open(sys.argv[1]) as f:
        job = json.load(f)
    strip(job)
    gif(job)


if __name__ == "__main__":
    main()
