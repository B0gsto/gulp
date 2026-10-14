"""The `palette` step of docs/06-art-bible.md section 15.4: "Samples the texture; reports the three
value blocks, their L* and shares; checks the water contrast rule and the reserved colour bands.
Fails the build when a reserved colour is used, or the contrast rule is broken" (task S6-A1).

A build opts in with spec["palette"]:
    zones      the 06 4.2 water zones the asset lives in (palette keys: "nursery", "reef", ...)
    texels     (n, 3) sRGB of every painted, visible texel of the asset (its atlas cells), for the
               band rules; `alpha` optional (n,) to skip see-through texels
    emissive   optional [{"name", "lit_share"}]: emissive masks, held to 06 5.1 / 8.3's 15%

The value blocks are measured on the mesh through spec["texture_sampler"] (validate's sampler),
area-weighted, so "largest block" and its mean colour are what a viewer sees.
"""
import numpy as np

import common
import texbake
import validate

# 06 4.5 "Art may not use": hue bands (degrees, HSV) when saturation > 70% and value > 85%.
BANDS = {"lime (can eat)": (68.0, 108.0), "red (can eat you)": (334.0, 14.0), "lantern amber (home)": (26.0, 46.0)}
BAND_SAT, BAND_VAL = 0.70, 0.85
NEON_SAT, NEON_VAL = 0.85, 0.95          # 06 4.1: saturated but not neon
CONTRAST_L, CONTRAST_HUE, CONTRAST_SAT = 25.0, 90.0, 0.50    # 06 4.1 water contrast rule
EMISSIVE_CAP = 0.15


def _in_band(h, lo, hi):
    return (h >= lo) & (h <= hi) if lo <= hi else (h >= lo) | (h <= hi)


def block_colours(spec):
    """Area-weighted share, mean sRGB and L* of each block on the primary mesh, via the sampler."""
    body = next(e["object"] for e in spec["meshes"] if e.get("primary"))
    sampler = spec.get("texture_sampler")
    mesh = body.data
    mesh.calc_loop_triangles()
    uvs = mesh.uv_layers[common.UV_NAME].data
    acc = {}
    for tri in mesh.loop_triangles:
        corners = [uvs[li].uv for li in tri.loops]
        for w in validate._SAMPLES:
            u = sum(c[0] * k for c, k in zip(corners, w))
            v = sum(c[1] * k for c, k in zip(corners, w))
            name, rgb = sampler(u, v)
            if not name:
                continue
            a = tri.area / len(validate._SAMPLES)
            row = acc.setdefault(name, [0.0, np.zeros(3), 0.0])
            row[0] += a
            row[1] += a * np.array(rgb)
            row[2] += a * common.lstar_from_srgb(rgb)
    total = sum(r[0] for r in acc.values()) or 1.0
    return {k: {"share": r[0] / total, "rgb": r[1] / r[0], "lstar": r[2] / r[0]} for k, r in acc.items() if r[0] > 0}


def run(spec, report):
    cfg = spec.get("palette")
    if not cfg:
        print("[palette] the asset declares no palette data: skipped")
        return None
    name = spec["name"]
    out = {"zones": list(cfg.get("zones", []))}

    # 1. The value blocks, as measured (validate holds them to 06 4.1; listed here for the report).
    blocks = block_colours(spec) if spec.get("texture_sampler") else {}
    for b, row in sorted(blocks.items(), key=lambda kv: -kv[1]["share"]):
        report.add(name, "palette: block %s" % b, True, "%.1f%% of the surface, L* %.1f, mean %s"
                   % (100.0 * row["share"], row["lstar"], "#%02X%02X%02X" % tuple(int(round(c * 255)) for c in row["rgb"])))
    out["blocks"] = {k: {"share": round(v["share"], 4), "lstar": round(v["lstar"], 1)} for k, v in blocks.items()}

    # 2. Water contrast: the largest block against the fog of every zone it lives in.
    if blocks:
        big = max(blocks, key=lambda k: blocks[k]["share"])
        rgb = blocks[big]["rgb"]
        h, s, _ = texbake.hsv(rgb)
        L = common.lstar_from_srgb(rgb)
        out["contrast"] = {}
        for zone in cfg.get("zones", []):
            fog = common.colour("water.%s.fog" % zone)
            fh, _, _ = texbake.hsv(texbake.hex_rgb(fog))
            dl = abs(L - common.lstar(fog))
            dh = abs((float(h) - float(fh) + 180.0) % 360.0 - 180.0)
            ok = dl >= CONTRAST_L or (dh >= CONTRAST_HUE and float(s) > CONTRAST_SAT)
            out["contrast"][zone] = {"dL": round(dl, 1), "dHue": round(dh, 1), "ok": bool(ok)}
            report.add(name, "palette: water contrast %s" % zone, bool(ok),
                       "largest block %s (L* %.1f, hue %.0f, sat %.0f%%) against fog %s (L* %.1f, hue %.0f): "
                       "%.1f L* apart, %.0f degrees apart; rule 25 L*, or 90 degrees with saturation over 50%%"
                       % (big, L, float(h), 100.0 * float(s), fog, common.lstar(fog), float(fh), dl, dh))

    # 3. Reserved colours and neon, on every painted texel.
    tex = cfg.get("texels")
    if tex is not None and len(tex):
        tex = np.asarray(tex, dtype=float)
        if cfg.get("alpha") is not None:
            tex = tex[np.asarray(cfg["alpha"]) > 0.05]
        h, s, v = texbake.hsv(tex)
        hot = (s > BAND_SAT) & (v > BAND_VAL)
        worst = {}
        for band, (lo, hi) in BANDS.items():
            n = int((hot & _in_band(h, lo, hi)).sum())
            worst[band] = n
            report.add(name, "palette: reserved %s" % band, n == 0,
                       "%d of %d texels inside hue %g to %g with saturation over 70%% and value over 85%% (06 4.5)"
                       % (n, len(tex), lo, hi))
        neon = int(((s > NEON_SAT) & (v > NEON_VAL)).sum())
        report.add(name, "palette: not neon", neon == 0, "%d of %d texels with saturation over 85%% and value over 95%% (06 4.1)"
                   % (neon, len(tex)))
        # The closest any texel comes to a band edge while hot, for the reviewer.
        if hot.any():
            margins = []
            for lo, hi in BANDS.values():
                d = np.minimum(np.abs((h[hot] - lo + 180.0) % 360.0 - 180.0), np.abs((h[hot] - hi + 180.0) % 360.0 - 180.0))
                margins.append(float(d.min()))
            out["closest_band_degrees"] = round(min(margins), 1)
        out["reserved"] = worst
        out["neon"] = neon
        out["texels"] = int(len(tex))

    # 4. Emissive masks (06 5.1: glow caps and emissive overlays cover at most 15% of the surface).
    for em in cfg.get("emissive", []):
        report.add(name, "palette: emissive %s" % em["name"], em["lit_share"] <= EMISSIVE_CAP,
                   "lights %.1f%% of the visible surface, cap 15%% (06 5.1, 8.3 rule 3)" % (100.0 * em["lit_share"]))
    out["emissive"] = [{"name": e["name"], "lit_share": round(e["lit_share"], 4)} for e in cfg.get("emissive", [])]
    spec["palette_result"] = out
    return out
