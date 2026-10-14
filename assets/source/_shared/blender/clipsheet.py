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


def _wrap(lines, f, width):
    out = []
    for line in lines:
        cur = ""
        for word in line.split(" "):
            trial = (cur + " " + word).strip()
            if cur and f.getlength(trial) > width:
                out.append(cur)
                cur = word
            else:
                cur = trial
        out.append(cur)
    return out


def _fit_text(draw, xy, text, size, width):
    """Draws `text` at `xy`, shrinking it until it fits `width` (labels never run into the next cell)."""
    while size > 10 and font(size).getlength(text) > width:
        size -= 1
    draw.text(xy, text, fill=INK, font=font(size))


def square(job):
    """The strip as a square sheet (`square` pixels, 06 15.5's 1536): a band per view, titled with
    the view, of its key poses in reading order, each cell labelled with its frame and pose only;
    the column count is the one that gives the biggest cells. The footer under the bands."""
    side, rows, labels = job["square"], job["rows"], job["labels"]
    n = len(labels)
    lab = max(16, side // 72)
    head_h, label_h = int(lab * 1.7), int(lab * 1.45)
    foot = font(max(14, int(lab * 0.8)))
    lines = _wrap(job["footer"], foot, side - 16)
    line_h = int(lab * 0.8 * 1.35)
    footer_h = line_h * len(lines) + 12
    best = None
    for cols in range(1, n + 1):
        per_view = (n + cols - 1) // cols
        pic = min(side // cols, (side - footer_h - len(rows) * head_h) // (len(rows) * per_view) - label_h)
        if best is None or pic > best[1]:
            best = (cols, pic, per_view)
    cols, pic, per_view = best
    cell_w = side // cols
    sheet = Image.new("RGB", (side, side), (24, 28, 36))
    draw = ImageDraw.Draw(sheet)
    y = 0
    for row in rows:
        draw.text((8, y + (head_h - lab) // 2), row["view"], fill=INK, font=font(int(lab * 1.15)))
        y += head_h
        for c, path in enumerate(row["frames"]):
            x, cy = (c % cols) * cell_w, y + (c // cols) * (pic + label_h)
            _fit_text(draw, (x + 8, cy + (label_h - lab) // 2), labels[c], lab, cell_w - 14)
            sheet.paste(flat(path, pic), (x + (cell_w - pic) // 2, cy + label_h))
        y += per_view * (pic + label_h)
    y = side - footer_h + 6
    for line in lines:
        draw.text((8, y), line, fill=INK, font=foot)
        y += line_h
    os.makedirs(os.path.dirname(job["strip"]), exist_ok=True)
    sheet.save(job["strip"])


def grid(job):
    """The 2-second clip (06 15.5: "a 2-second, 384-pixel clip") as a still contact image, for a
    reviewer who cannot play the GIF: every frame of it in order, 8 to a row at half size, each
    labelled with its clip frame and time; a hold at the end, or a loop's repeat, is one line of text."""
    frames, index, fps = job["clip_frames"], job["clip_index"], job["fps"]
    shown, seen = [], set()
    for i, (path, f) in enumerate(zip(frames, index)):
        if f in seen:
            break
        seen.add(f)
        shown.append((i, f, path))
    rest = len(frames) - len(shown)
    cols, pic = 8, job["size"] // 2
    lab = 16
    label_h, head_h = 22, 34
    nrows = (len(shown) + cols - 1) // cols
    note = ("then %s to %.1f s" % ("holds f%d" % index[-1] if index[-1] == shown[-1][1] else "repeats", len(frames) / float(fps))
            if rest else "")
    sheet = Image.new("RGB", (cols * pic, head_h + nrows * (pic + label_h) + 30), (24, 28, 36))
    draw = ImageDraw.Draw(sheet)
    draw.text((8, 8), "%s: the %.0f s clip at %d fps, every frame (%d px renders shown at %d)"
              % (job["name"], len(frames) / float(fps), fps, job["size"], pic), fill=INK, font=font(18))
    for k, (i, f, path) in enumerate(shown):
        x, y = (k % cols) * pic, head_h + (k // cols) * (pic + label_h)
        draw.text((x + 6, y + 3), "f%d  %.2f s" % (f, i / float(fps)), fill=INK, font=font(lab))
        sheet.paste(flat(path, pic), (x, y + label_h))
    if note:
        draw.text((8, sheet.height - 26), note, fill=INK, font=font(18))
    os.makedirs(os.path.dirname(job["grid"]), exist_ok=True)
    sheet.save(job["grid"])


def strip(job):
    """Text is sized to the sheet, so the labels still read when the strip is viewed at 768 wide."""
    if job.get("square"):
        return square(job)
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
    if job.get("grid"):
        grid(job)


if __name__ == "__main__":
    main()
