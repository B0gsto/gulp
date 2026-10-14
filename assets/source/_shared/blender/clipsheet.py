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
    """Text is sized to the sheet, so the labels still read when the strip is viewed at 768 wide."""
    size, rows, labels = job.get("strip_size", job["size"]), job["rows"], job["labels"]
    cols = len(labels)
    lab = max(16, int(size * cols / 64))           # about 12 px at 768 wide
    small, foot = font(lab), font(max(14, int(lab * 0.75)))
    row_w = max(ROW_LABEL_W, int(lab * 3.2))
    label_h = max(LABEL_H, int(lab * 1.5))
    w = row_w + cols * size
    lines = []
    for line in job["footer"]:
        words, cur = line.split(" "), ""
        for word in words:
            trial = (cur + " " + word).strip()
            if cur and foot.getlength(trial) > w - 16:
                lines.append(cur)
                cur = word
            else:
                cur = trial
        lines.append(cur)
    line_h = int(lab * 0.75 * 1.35)
    h = label_h + len(rows) * size + line_h * len(lines) + 12
    sheet = Image.new("RGB", (w, h), (24, 28, 36))
    draw = ImageDraw.Draw(sheet)
    for c, text in enumerate(labels):
        draw.text((row_w + c * size + 8, (label_h - lab) // 2), text, fill=INK, font=small)
    for r, row in enumerate(rows):
        y = label_h + r * size
        draw.text((8, y + size // 2 - lab // 2), row["view"], fill=INK, font=small)
        for c, path in enumerate(row["frames"]):
            sheet.paste(flat(path, size), (row_w + c * size, y))
    y = label_h + len(rows) * size + 6
    for line in lines:
        draw.text((8, y), line, fill=INK, font=foot)
        y += line_h
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
