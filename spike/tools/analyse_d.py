#!/usr/bin/env python3
"""Spike part D analysis of spike/out/d/run.json and its screenshots (Pillow only, no Studio).
  analyse_d.py   prints: bone compare (anim_kfs.check), overlay mask IoU per frame, ball contrast per preset;
                 writes spike/out/d/summary.json and one 768-px contact sheet spike/out/d/sheet.png"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "out", "d")
sys.path.insert(0, HERE)
import anim_kfs  # noqa: E402

res = json.load(open(os.path.join(OUT, "run.json")))
summ = {}
clip = json.load(open(os.path.join(OUT, "A_Fish_Swim.json")))
rig = json.load(open(os.path.join(OUT, "M_Species_Base_Fish_RigTest.bones.json")))
summ["boneCompare"] = anim_kfs.check(clip, rig, res["anim"]["frames"])


def mask(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(int)
    return a.max(axis=2) > 60


ov = {}
masks = {}
for f in (3, 7, 12):
    try:
        b, o = mask(os.path.join(OUT, "ov-%02d-body.png" % f)), mask(os.path.join(OUT, "ov-%02d-overlay.png" % f))
    except OSError:
        continue
    masks[f] = (b, o)
    inter, uni = (b & o).sum(), (b | o).sum()
    ov[f] = {"iou": round(inter / max(uni, 1), 4), "bodyPx": int(b.sum()), "overlayPx": int(o.sum()),
             "bodyNotCovered": int((b & ~o).sum())}
if 3 in masks and 12 in masks:
    b3, b12 = masks[3][0], masks[12][0]
    ov["control_body3_vs_body12_iou"] = round((b3 & b12).sum() / max((b3 | b12).sum(), 1), 4)
summ["overlay"] = ov


def lum(img, x, y, r):
    x0, x1, y0, y1 = int(x - r), int(x + r) + 1, int(y - r), int(y + r) + 1
    p = np.asarray(img.crop((max(x0, 0), max(y0, 0), x1, y1)).convert("RGB")).astype(float)
    return (0.2126 * p[..., 0] + 0.7152 * p[..., 1] + 0.0722 * p[..., 2]).mean() if p.size else float("nan")


vis = {}
for v in res.get("vis", []):
    path = os.path.join(OUT, "vis-%s.png" % v["tag"])
    if not os.path.exists(path):
        continue
    img = Image.open(path)
    s = img.width / v["vp"][0]
    row = {}
    for d, (x, y, r, on) in sorted(v["balls"].items(), key=lambda kv: int(kv[0])):
        x, y, r = x * s, y * s, max(r * s, 1.0)
        c = lum(img, x, y, max(r * 0.4, 0.6))
        bg = (lum(img, x - 2.5 * r - 2, y, max(r * 0.5, 1)) + lum(img, x + 2.5 * r + 2, y, max(r * 0.5, 1))) / 2
        row[d] = round((c - bg) / 255, 3)
    gone = [int(d) for d, c in row.items() if abs(c) < 0.02]
    vis[v["tag"]] = {"contrast": row, "firstBelow2pct": min(gone) if gone else None}
summ["vis"] = vis
json.dump(summ, open(os.path.join(OUT, "summary.json"), "w"), indent=1)
print(json.dumps(summ)[:4000])

# contact sheet: overlay masks row + 4 visibility shots
tiles = []
for f in (3, 7, 12):
    for show in ("body", "overlay"):
        p = os.path.join(OUT, "ov-%02d-%s.png" % (f, show))
        if os.path.exists(p):
            tiles.append(("f%d %s" % (f, show), Image.open(p).convert("RGB")))
for tag in ("nursery-d0.32", "nursery-d0.60", "nursery-fog220", "kelp-d0.45", "dropDeep-d0.52", "nursery-d0.80"):
    p = os.path.join(OUT, "vis-%s.png" % tag)
    if os.path.exists(p):
        tiles.append((tag, Image.open(p).convert("RGB")))
if tiles:
    W, H = 384, 216
    cols = 4
    sheet = Image.new("RGB", (W * cols, H * ((len(tiles) + cols - 1) // cols)), (30, 30, 30))
    for i, (name, im) in enumerate(tiles):
        im = im.copy()
        im.thumbnail((W, H))
        sheet.paste(im, ((i % cols) * W, (i // cols) * H))
        ImageDraw.Draw(sheet).text(((i % cols) * W + 4, (i // cols) * H + 4), name, fill=(255, 255, 0))
    sheet.thumbnail((768, 768))
    sheet.save(os.path.join(OUT, "sheet.png"))
