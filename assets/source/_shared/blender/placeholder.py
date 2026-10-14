"""Placeholder generator (docs/07-asset-list.md section 14.1 tool row; rules in section 16).

    python3 assets/source/_shared/blender/placeholder.py <AssetName> [<AssetName> ...]
    python3 assets/source/_shared/blender/placeholder.py --list <prefix>      names chapter 07 knows

One command builds the stand-in for a named row of chapter 07, under the final name, in
assets/placeholder/ (07 section 1.3), laid out like assets/export/. Names are read from the
chapter 07 tables themselves; a name that is not in them is refused.

  M_*    meshes, built in Blender (one process for all the names given, under the heavy-job
         wrapper) through run.py: build, lod, shell, validate, export, preview. Species: capsule,
         cone tail, eyes, lid caps on the real family skeleton (Fish family: the slice's Minnow and
         Pufferfish). Prey: ellipsoids by tier, trait prey with a ring, plankton a 2-triangle
         billboard. Predators and hazards: red-toned primitives; the Barracuda on RIG_Barracuda
         (placeholder_rigs.py). Env, cove, props and trait pieces: grey blocks at the footprint the
         row gives, every face showing its cell's stamp; the Pearl Clam with a hinged lid.
  A_*    clips: the host body on its skeleton, one procedural move of the row's length in frames
         (placeholder_rigs.py), exported as one take.
  T_*    flat tint, "PH" stamp and the name (texgen.py); effect textures are the soft dot.
  FX_*   emitter settings JSON on the soft dot, tinted by type.
  LGT_*  one neutral preset with the fog colour and view distance of 06 section 10.2.
  SKY_*  six flat two-colour faces.
  SFX_*  a beep of the row's length pitched by group, loops are soft noise (ffmpeg, OGG Vorbis).
  MUS_*  an eight-bar mallet loop at 124 bpm pitched by name, one file per stem (<Name>_Stem<n>
         when Qty > 1); stingers are three notes over the row's length.
  SCN_*  none (07 says none needed). RIG_*: skeletons travel inside the mesh and clip files.

Every manifest row at once, resumable: placeholder_batch.py.
"""
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import sys

LIB_DIR = os.path.dirname(os.path.abspath(__file__))
if LIB_DIR not in sys.path:
    sys.path.insert(0, LIB_DIR)

import common  # noqa: E402

DOC = os.path.join(common.REPO_DIR, "docs", "07-asset-list.md")
BIBLE = os.path.join(common.REPO_DIR, "docs", "06-art-bible.md")
OUT = os.path.join(common.ASSETS_DIR, "placeholder")
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"


def heavy_wrapper():
    """The machine-wide heavy-job wrapper (tools/with-heavy.sh in a folder above the repo, or
    $GULP_HEAVY): every Blender run goes through it, so no more than two heavy jobs run at once."""
    if os.environ.get("GULP_HEAVY"):
        return os.environ["GULP_HEAVY"]
    d = os.path.dirname(common.REPO_DIR)
    while d != os.path.dirname(d):
        path = os.path.join(d, "tools", "with-heavy.sh")
        if os.path.exists(path):
            return path
        d = os.path.dirname(d)
    raise SystemExit("tools/with-heavy.sh not found above the repo: set GULP_HEAVY")
TEMPO = 124                     # 07 section 12, shared tempo (tune)

# 06 section 6.2 (chapter 03 owns them): length, height, width at body scale 1.0. Where the
# bible gives only a length, height and width follow the shape's proportions below (tune).
SIZES = {
    "minnow": (3.0, 1.1, 0.7), "puffer": (2.4, 2.0, 2.0), "shark": (3.4, None, None),
    "eel": (5.0, 0.8, 0.6), "turtle": (3.0, None, 2.6), "squid": (3.6, None, None),
    "plankton": (0.4, None, None), "krill": (0.8, None, None), "shrimp": (1.0, None, None),
    "sardine": (1.6, None, None), "darter": (2.4, None, None), "mackerel": (3.6, None, None),
    "bonito": (5.5, None, None), "tuna": (8.5, None, None), "gull": (8.0, None, None),
    "moray": (16.0, None, None), "barracuda": (12.0, None, None), "grouper": (14.0, 9.0, None),
    "old_scar": (30.0, None, None),
}
FISH_FAMILY = ("minnow", "puffer", "shark")      # 06 section 3.1
ADULT_LENGTH = 1.2                               # adult vs juvenile length at body scale 1.0 (tune; 07 16 only says they differ)
TIER_LENGTH = {1: 0.9, 2: 1.6, 3: 2.4, 4: 3.6, 5: 5.5, 6: 8.5}   # trait prey: the 06 6.2 prey length of their tier


# ---------------------------------------------------------------- reading chapter 07

def pascal_to_id(word):
    return re.sub(r"(?<!^)([A-Z])", r"_\1", word).lower()


def _expand(cell):
    """Names in a row's Asset cell: `A, B`, `X_01–06`, `M_Species_Minnow_*_LOD1, _LOD2`."""
    names = []
    for chunk in re.findall(r"`([^`]+)`", cell):
        prev = None
        for part in [p.strip() for p in chunk.split(",")]:
            if part.startswith("_") and prev:
                part = prev.rsplit("_", 1)[0] + part
            m = re.match(r"^(.*?)(\d+)[–-](\d+)(_[A-Za-z]\w*)?$", part)      # `X_01–06` and `T_Caustics_01–16_Mask`
            if m:
                width = len(m.group(2))
                names += [m.group(1) + str(i).zfill(width) + (m.group(4) or "") for i in range(int(m.group(2)), int(m.group(3)) + 1)]
            else:
                names.append(part)
            prev = part
    return names


_ROWS = []


def rows():
    """Every table row of chapter 07 whose Asset cell names files, with its section (read once)."""
    if not _ROWS:
        _ROWS.extend(_read_rows())
    return _ROWS


def _read_rows():
    out, header, section = [], None, ""
    with open(DOC, encoding="utf-8") as f:
        for line in f:
            if line.startswith("#"):
                section, header = line.strip("# \n"), None
                continue
            if not line.startswith("|"):
                header = None
                continue
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if header is None:
                header = cells
                continue
            if set(cells[0]) <= set("-: "):
                continue
            row = dict(zip(header, cells))
            row["section"] = section
            row["names"] = _expand(cells[0])
            if row["names"]:
                out.append(row)
    return out


def find(name):
    import fnmatch
    for row in rows():
        if name in row["names"]:
            return row
    for row in rows():
        if any("*" in n and fnmatch.fnmatchcase(name, n) for n in row["names"]):
            return row
    raise SystemExit("'%s' is not a row of docs/07-asset-list.md: placeholder names come from that list only" % name)


def column(row, *prefixes):
    for key, value in row.items():
        if any(key.startswith(p) for p in prefixes):
            return value
    return ""


def seeded(name, n):
    return int(hashlib.sha1(name.encode()).hexdigest(), 16) % n


def name_colour(name, group=("creatures",)):
    """A palette colour picked by the name, so every stand-in has its own flat colour."""
    flat = [hexcode for path, hexcode in common.flat_palette() if path.split(".")[0] in group]
    return flat[seeded(name, len(flat))]


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1)
    return path


# ---------------------------------------------------------------- textures, effects, lighting

def texture(name, row):
    import texgen
    m = re.search(r"(\d+)²", column(row, "Size") or "")
    size = min(int(m.group(1)) if m else 256, texgen.MAX_TEXTURE)
    parts = name.split("_")
    path = os.path.join(OUT, "textures", name + ".png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if parts[1] == "FX":
        img, note = fx_mask(name, row, size)
    else:
        species = pascal_to_id(parts[1])
        try:
            hexcode = common.colour("creatures.%s.mid" % species)
        except KeyError:
            hexcode = "#9A9A9A"
        if species in PRED_HAZARD:
            hexcode = common.colour("ui.destructive")     # red-toned like their meshes (07 16)
        elif parts[1] == "Surface":
            hexcode = common.colour("water.reef.surface")  # 07: light aqua water
        label = name
        if any(p.startswith("Pat") for p in parts):
            hexcode = name_colour(name)                      # 07 16: a different flat tint per pattern
        if parts[1] == "Trait" and len(parts) > 3 and parts[2] != "Pieces":
            hexcode, label = name_colour(parts[2], ("rarity", "creatures")), parts[2].upper()   # trait name in big letters
        desc = row.get("Description", "").lower()
        users = texture_users(name) if ("atlas" in desc or " cells" in desc) else []
        stale = path.replace(".png", ".atlas.json")
        if len(users) <= 1 and os.path.exists(stale):
            os.remove(stale)             # a texture that is not an atlas has no cells (a stale file would misplace UVs)
        if len(users) > 1:                   # a shared atlas: one stamped cell per mesh that uses it
            n = math.ceil(math.sqrt(len(users)))
            cell = size // n
            rects = texgen.atlas_rects([(u, cell, cell) for u in users], size)
            img = texgen.flat(size, "#9A9A9A", False)
            for u in users:
                r = rects[u]
                img.paste(texgen.flat(cell, mesh_colour(u), u.split("_", 2)[-1]), (int(r[0] * size), int((1.0 - r[3]) * size)))
            write_json(path.replace(".png", ".atlas.json"), {"texture": name, "cells": rects})
            note = "atlas of %d stamped %d px cells (texgen.atlas_rects)" % (len(users), cell)
        else:
            family = species in common.palette()["creatures"] and parts[1] != "Trait"
            img = texgen.flat(size, hexcode, label, centre=0.25 if family else 0.5)   # family layout: stamp on the body region
            note = "flat %s, PH stamp" % hexcode
    img.save(path)
    return path, "%dx%d, %s" % (img.size[0], img.size[1], note)


PRED_HAZARD = ("barracuda", "moray", "grouper", "gull", "old_scar", "jelly", "vent", "anemone", "hook")


def fx_mask(name, row, size):
    """Effect masks: white on clear in their shape class, with the PH stamp in dark opaque ink so
    it shows in colour and in alpha. Shafts (GodRay, Streak) are a soft vertical gradient at the
    row's width x height; rings (Ring, TierRing, Foam) a soft ring; flipbooks (`_Flip`, `4×4`) a
    grid of frames that grow and break up (a `2×2` mask holds variants the same way); everything else the soft dot of 07 section 16."""
    import texgen
    from PIL import Image
    cell = column(row, "Size") or ""
    m = None if "²" in cell else re.search(r"(\d+)\s*×\s*(\d+)", cell)        # `64 × 256`: a non-square mask
    grid = re.search(r"(\d+)×(\d+)", cell.replace(" ", "").split(",")[-1]) if "," in cell else None   # `512², 4×4` frames or variants
    w, h = (int(m.group(1)), int(m.group(2))) if m and not grid else (size, size)
    shape = "shaft" if any(k in name for k in ("GodRay", "Streak")) else "ring" if any(k in name for k in ("Ring", "Foam")) else "dot"

    def frame(fw, fh, t=0.0):
        img = Image.new("RGBA", (fw, fh), (255, 255, 255, 0))
        px = img.load()
        for y in range(fh):
            for x in range(fw):
                u, v = (x + 0.5) / fw * 2 - 1, (y + 0.5) / fh * 2 - 1
                if shape == "shaft":                    # bright at the top, soft edges, fading down
                    a = max(0.0, 1 - abs(u)) ** 1.5 * (1 - (v + 1) / 2) ** 0.7
                elif shape == "ring":                   # a ring that spreads and breaks up with t
                    r = (u * u + v * v) ** 0.5
                    a = max(0.0, 1 - abs(r - (0.35 + 0.5 * t)) / 0.12) * (1 - 0.8 * t * (seeded("%d,%d" % (x // 4, y // 4), 3) == 0))
                else:
                    a = max(0.0, 1 - (u * u + v * v) ** 0.5) ** 1.6
                px[x, y] = (255, 255, 255, int(255 * max(0.0, min(1.0, a))))
        return img
    if grid:
        cols, rws = int(grid.group(1)), int(grid.group(2))
        cw, ch = size // cols, size // rws
        img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
        for i in range(cols * rws):
            img.paste(frame(cw, ch, i / float(cols * rws - 1)), ((i % cols) * cw, (i // cols) * ch))
        note = "%s flipbook %dx%d frames" % (shape, cols, rws)
    else:
        img = frame(w, h)
        note = "white %s %dx%d" % (shape, w, h)
    texgen.stamp(img, name.split("_")[2])
    return img, note + ", PH stamp in opaque ink"


def texture_users(tex):
    """Mesh rows of 07 whose Depends on column names this texture."""
    return [n for r in rows() if re.search(r"\b%s\b" % tex, r.get("Depends on", "")) for n in r["names"]
            if n.startswith("M_") and "*" not in n and "<" not in n]


def mesh_colour(name):
    ident = pascal_to_id(name.split("_")[2]) if name.count("_") >= 2 else ""
    try:
        return common.colour("creatures.%s.mid" % ident)
    except KeyError:
        return name_colour(name)


def texture_for(name, row):
    """The texture a mesh row draws with: the first T_ name in its Depends on column, else
    the species texture T_<Species>_<Juv|Adult>_Alb. Chapter 07 names it; none is invented."""
    m = re.search(r"\b(T_\w+)", row.get("Depends on", ""))
    if m:
        return m.group(1)
    parts = name.split("_")
    if parts[1] == "Species" and len(parts) > 3:
        cand = "T_%s_%s_Alb" % (parts[2], parts[3])
        try:
            find(cand)
            return cand
        except SystemExit:
            return None
    return None


def soft_dot_texture():
    path = os.path.join(OUT, "textures", "T_FX_SoftDot_Mask.png")
    if not os.path.exists(path):
        texture("T_FX_SoftDot_Mask", find("T_FX_SoftDot_Mask"))
    return path


def effect(name, row):
    soft_dot_texture()
    sec = row["section"]
    if "Pearl" in name:
        tint = common.colour("signal.pearl")
    elif sec.startswith("9.2"):
        tint = common.colour("signal.can_eat")
    elif sec.startswith("9.6") or "Danger" in name:
        tint = common.colour("signal.can_eat_you")
    else:
        tint = common.colour("water.reef.surface")
    size = column(row, "Size")
    m = re.search(r"(\d+)\s*particles", size)
    data = {"name": name, "placeholder": True, "texture": "T_FX_SoftDot_Mask", "colour": tint,
            "particles": int(m.group(1)) if m else 8, "duration_s": 0.6, "size_studs": 0.5,
            "source_row": {"section": sec, "size": size}}
    return write_json(os.path.join(OUT, "fx", name + ".json"), data), "%d particles, tint %s" % (data["particles"], tint)


ZONE_ROWS = {"Nursery": "Nursery Lagoon", "Reef": "Sunlit Reef", "Kelp": "Kelp Forest", "DropOff": "Drop-off, upper",
             "Cove": "Cove interior", "Surface": "Above the surface", "Trench": "The Trench"}


def fog_table():
    out = {}
    with open(BIBLE, encoding="utf-8") as f:
        for line in f:
            cells = [c.strip().strip("`") for c in line.strip().strip("|").split("|")]
            if len(cells) == 13 and cells[0].replace(" [P2]", "") in ZONE_ROWS.values():
                out[cells[0].replace(" [P2]", "")] = {"colour": cells[10], "decay": cells[11],
                                                     "view_distance": float(cells[12].replace(",", ""))}
    return out


# Presets that change a zone preset rather than own a 06 10.2 row: the values 06 gives, else 07's words.
LIGHT_CHANGES = {
    "LGT_Event_Frenzy": ("Reef", {"Brightness": 0.2, "fog_toward": ("#6FDDEE", 0.15),
                                  "ColorCorrection": {"Saturation": 0.25, "TintColor": "#FFF1CC"}, "Bloom": {"Intensity": 0.8}},
                         "06 10.6 Feeding Frenzy: brightness +0.2, fog 15% toward #6FDDEE, saturation 0.25, tint #FFF1CC, bloom 0.8"),
    "LGT_Gulped": ("Reef", {"Brightness": -0.8, "ColorCorrection": {"Saturation": -0.7, "TintColor": "#B8B8C8"},
                            "duration_s": 0.5},
                   "06 gives no values; 07 'half-second dim and desaturate': placeholder brightness -0.8, saturation -0.7, "
                   "tint #B8B8C8 over 0.5 s (tune)"),
}


def mix(a, b, t):
    ca, cb = common.hex_to_rgb255(a), common.hex_to_rgb255(b)
    return "#%02X%02X%02X" % tuple(int(round(x + (y - x) * t)) for x, y in zip(ca, cb))


def lighting(name, row):
    neutral = {"Brightness": 2.0, "Ambient": "#808080", "OutdoorAmbient": "#808080", "ColorShift_Top": "#FFFFFF",
               "ExposureCompensation": 0.0, "Atmosphere": {"Density": 0.35, "Offset": 0.1, "Haze": 2.0, "Glare": 0.0}}
    key = name.split("_")[-1]
    fog = fog_table().get(ZONE_ROWS.get(key, ""), None)
    data = {"name": name, "placeholder": True, **neutral}
    data["Atmosphere"] = dict(neutral["Atmosphere"])
    if name in LIGHT_CHANGES:
        base, change, source = LIGHT_CHANGES[name]
        fog = fog_table().get(ZONE_ROWS[base])
        data["Atmosphere"].update(Color=fog["colour"], Decay=fog["decay"])
        data["TargetViewDistance"] = fog["view_distance"]
        for k, v in change.items():
            if k == "fog_toward":
                data["Atmosphere"]["Color"] = mix(fog["colour"], v[0], v[1])
            elif k == "Brightness":
                data["Brightness"] = round(data["Brightness"] + v, 3)
            else:
                data[k] = v
        data["applies_over"] = "the current zone preset (%s here)" % base
        data["source"] = source
        return write_json(os.path.join(OUT, "lighting", name + ".json"), data), source
    if fog:
        data["Atmosphere"].update(Color=fog["colour"], Decay=fog["decay"])
        data["TargetViewDistance"] = fog["view_distance"]
        note = "fog %s, view %d studs (06 10.2)" % (fog["colour"], fog["view_distance"])
    else:
        note = "no 06 10.2 row for '%s': neutral fog kept" % key
    return write_json(os.path.join(OUT, "lighting", name + ".json"), data), note


def sky(name, row):
    import texgen
    folder = os.path.join(OUT, "lighting", name)
    os.makedirs(folder, exist_ok=True)
    top, low = common.colour("water.above_surface.sky_top"), common.colour("water.reef.surface")
    for face in ("Up", "Ft", "Bk", "Lf", "Rt", "Dn"):
        hexcode = low if face == "Dn" else top
        img = texgen.flat(512, hexcode, False)
        if face not in ("Up", "Dn"):           # flat two-colour: sky over a sea band
            from PIL import ImageDraw
            h = low.lstrip("#")
            ImageDraw.Draw(img).rectangle((0, 300, 511, 511), fill=tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,))
        texgen.stamp(img, name + " " + face).save(os.path.join(folder, "%s_%s.png" % (name, face)))
    return folder, "six 512 faces, %s over %s" % (top, low)


# ---------------------------------------------------------------- audio (ffmpeg)

def seconds(text, default):
    m = re.search(r"(\d+(?:\.\d+)?)\s*s\b", text or "")
    return float(m.group(1)) if m else default


def ffmpeg(args, out):
    exe = shutil.which("ffmpeg")
    if not exe:
        raise SystemExit("ffmpeg not found: audio placeholders need it (no install is done by this tool)")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    cmd = [exe, "-hide_banner", "-loglevel", "error", "-y"] + args + ["-ac", "2", "-ar", "44100",
                                                                       "-c:a", "vorbis", "-strict", "-2", out]
    done = subprocess.run(cmd, capture_output=True, text=True)
    if done.returncode != 0:
        raise SystemExit("ffmpeg failed: " + done.stderr[-400:])
    return out


def sound(name, row):
    length = seconds(column(row, "Length", "Size"), 0.4)
    desc = row.get("Description", "").lower()
    loop = "loop" in name.lower() or name.startswith("SFX_Amb_") or " loop" in desc
    sec = row["section"]
    if name.startswith("SFX_UI_") or sec.startswith("11.5"):
        pitch, group = 660.0, "interface, mid"
    elif sec.startswith("11.4") or "danger" in desc:
        pitch, group = 220.0, "danger, low"
    elif sec.startswith("11.2"):
        pitch, group = 1320.0, "eat and growth, high"
    else:
        pitch, group = 880.0, "other, mid-high"
    pitch *= 2 ** (seeded(name, 5) / 12.0)                  # a step apart per name, so files tell apart
    out = os.path.join(OUT, "audio", "sfx", name + ".ogg")
    if loop:
        length = max(length, 2.0)
        ffmpeg(["-f", "lavfi", "-i", "anoisesrc=color=pink:amplitude=0.08:duration=%.3f" % length], out)
        return out, "%.2f s soft noise loop" % length
    fade = min(0.02, length / 4)
    expr = "0.5*sin(2*PI*%.2f*t)*min(1,t/%.3f)*min(1,(%.3f-t)/%.3f)" % (pitch, fade, length, fade)
    ffmpeg(["-f", "lavfi", "-i", "aevalsrc='%s':d=%.3f:s=44100" % (expr, length)], out)
    return out, "%.2f s beep at %.0f Hz (%s)" % (length, pitch, group)


def stem_names(name, row):
    """07 section 12: "stems are separate files of the same length that start together; Qty
    counts them". Chapter 07 names no stem file, so a track of n > 1 stems is written as
    <Name>_Stem1 .. _Stem<n> (stem 1 the base); a one-stem track keeps its own name."""
    try:
        n = int(re.sub(r"[^0-9]", "", row.get("Qty", "")) or 1)
    except ValueError:
        n = 1
    return [name] if n <= 1 else ["%s_Stem%d" % (name, i) for i in range(1, n + 1)]


def music(name, row):
    beat = 60.0 / TEMPO
    root = 220.0 * 2 ** (seeded(name, 12) / 12.0)
    if name.startswith("MUS_Sting_"):
        notes = [0, 4, 7]                                     # three notes spread over the row's length
        step = seconds(column(row, "Length"), 1.5) / 3.0
    else:
        notes, step = [0, 7, 4, 7, 12, 7, 4, 7] * 4, beat      # eight bars of 4/4 in quarter notes = 32 beats
    length = len(notes) * step
    stems = stem_names(name, row)
    for i, stem in enumerate(stems):
        # stem 1: the mallet loop; stem 2: an octave-up off-beat pulse; then a fifth below, a high pad
        shift, offset = [(0, 0.0), (12, step / 2), (-5, 0.0), (19, 0.0)][i % 4]
        terms = []
        for j, semis in enumerate(notes):
            f = root * 2 ** ((semis + shift) / 12.0)
            t0 = j * step + (offset if j % 2 == 0 else 0.0)
            t1 = min(length, t0 + step)
            terms.append("between(t,%.4f,%.4f)*sin(2*PI*%.2f*(t-%.4f))*exp(-7*(t-%.4f))" % (t0, t1, f, t0, t0))
        expr = "0.45*(" + "+".join(terms) + ")"
        out = os.path.join(OUT, "audio", "music", stem + ".ogg")
        ffmpeg(["-f", "lavfi", "-i", "aevalsrc='%s':d=%.3f:s=44100" % (expr, length)], out)
    return os.path.join(OUT, "audio", "music", stems[0] + ".ogg"), "%.2f s mallet %s at %d bpm, root %.0f Hz, %d stem file(s)" % (
        length, "stinger" if len(notes) == 3 else "loop", TEMPO, root, len(stems))


# ---------------------------------------------------------------- meshes (inside Blender)

def mesh_spec(name, row):
    """The spec run.py builds, validates, exports and previews."""
    import bpy  # noqa: F401
    from mathutils import Vector

    import meshgen
    import rigs
    parts = name.split("_")
    cat = parts[1]
    root = os.path.join(OUT)
    md = meshgen.MeshData()
    spec = {"name": name, "category": cat, "origin": "creature", "size_tol": 0.03, "export_root": root,
            "placeholder": True}
    arm = None
    desc = row.get("Description", "")

    def ellipsoid(c, l, h, w, segs, rings):
        sx, sy, sz = w / 2.0, l / 2.0, h / 2.0
        verts, faces, params = meshgen.sphere((0, 0, 0), 1.0, (0, -1, 0), (0, 0, 1), segs, rings)
        return [(c[0] + v[0] * sx, c[1] + v[1] * sy, c[2] + v[2] * sz) for v in verts], faces, params

    if cat == "Species":
        ident = pascal_to_id(parts[2])
        if ident not in FISH_FAMILY:
            raise SystemExit("%s: only the Fish family skeleton exists so far (rigs.py); %s waits for its family rig"
                             % (name, ident))
        L, H, W = SIZES[ident]
        H = H or L * 1.1 / 3.0
        W = W or L * 0.7 / 3.0
        if "Adult" in parts:
            L *= ADULT_LENGTH
        colour = common.colour("creatures.%s.mid" % ident)
        k = L / 3.0
        body_end = L / 2.0 - 0.28 * L

        def half_h(y):
            t = min(1.0, max(0.0, (y + L / 2.0) / (body_end + L / 2.0)))
            return H / 2.0 * max(0.05, math.sin(math.pi * t) ** 0.55)

        half_w = lambda y: half_h(y) * W / H
        eye_r = 0.09 * H
        ey = -L / 2.0 + 0.2 * L
        eye = (min(half_w(ey) * 0.8 + 0.3 * eye_r, W / 2.0 - eye_r - 0.01), ey, 0.12 * H)
        pec = (half_w(-0.15 * L) * 0.8, -0.15 * L, -0.1 * H)
        fit = rigs.FishFit(L, half_h, half_w, eye, pec, (0.0, -0.05 * L, H / 2.0))
        bones = fit.bones()
        arm = meshgen.build_armature("RIG_Fish", bones)
        if "Puffed" in parts:               # 06 6.2: a ball 1.5 times the normal height
            d = 1.5 * H
            L = H = W = d
            md.add_part(meshgen.sphere((0, 0, 0), d / 2.0, (0, -1, 0), (0, 0, 1), 20, 14), colour,
                        weights=lambda p, q: fit.body_weights(p))
        else:
            rings = []
            nr, ns = (21, 20) if "Adult" in parts else (15, 16)     # adults have 2.3 times the triangle budget (06 6.3)
            for i in range(1, nr):
                y = -L / 2.0 + (body_end + L / 2.0) * i / float(nr)
                rings.append([(half_w(y) * math.sin(a), y, half_h(y) * math.cos(a))
                              for a in (2.0 * math.pi * j / ns for j in range(ns))])
            md.add_part(meshgen.loft(rings, (0, -L / 2.0, 0), (0, body_end + 0.02 * L, 0)), colour,
                        weights=lambda p, q: fit.body_weights(p))
            tail = [[(0.45 * W * (0.1 + 0.25 * t) * math.sin(a), body_end - 0.06 * L + t * (L / 2.0 - body_end + 0.06 * L),
                      H / 2.0 * (0.15 + 0.85 * t) * math.cos(a)) for a in (2.0 * math.pi * j / 10 for j in range(10))]
                    for t in (0.0, 0.5, 1.0)]
            md.add_part(meshgen.loft(tail, (0, body_end - 0.08 * L, 0), (0, L / 2.0, 0)), colour, weights={"TailFin": 1.0})
        for side, tag in ((1.0, "L"), (-1.0, "R")):
            c = Vector((side * eye[0], eye[1], eye[2]))
            md.add_part(meshgen.sphere(c, eye_r, (side, 0, 0), (0, 0, 1), 8, 6), "#FFFFFF", weights={"Eye_" + tag: 1.0})
            lid = ellipsoid((c.x, c.y, c.z + 0.75 * eye_r), 2.1 * eye_r, 0.7 * eye_r, 1.6 * eye_r, 8, 4)
            md.add_part(lid, colour, weights={"Lid_" + tag: 1.0})
        spec.update(budget="species_adult" if "Adult" in parts else "species_juv", rig="Fish", armature=arm,
                    facing={"kind": "bones", "front": "Jaw", "back": "TailFin"}, size=(W, L, H), id=ident)
        if "Puffed" in parts:
            spec["budget"] = "puffer_puffed_adult" if "Adult" in parts else "puffer_puffed_juv"
    elif cat in ("Prey", "Pred", "Hazard"):
        ident = pascal_to_id(parts[2])
        m = re.search(r"tier (\d)", desc)
        tier = int(m.group(1)) if m else 3
        trait = row["section"].startswith("4.2")
        L = SIZES.get(ident, (TIER_LENGTH.get(tier, 2.0),))[0]
        H = SIZES.get(ident, (0, None))[1] or (0.45 * L if cat == "Prey" else 0.35 * L)
        W = 0.3 * L if cat == "Prey" else 0.3 * L
        colour = mesh_colour(name) if cat == "Prey" else common.colour("ui.destructive")
        segs, rings = ((8, 4) if tier <= 1 else (12, 5) if tier == 2 else (12, 7) if tier <= 4 else (16, 9))
        if row["section"].startswith("4.2"):
            segs, rings = 14, 9             # trait prey: 06 6.3 floor of 300 triangles
        if cat == "Prey":
            if ident == "plankton":         # 06 6.3: a 2-triangle camera-facing billboard, open by design
                s = L / 2.0
                md.add_part(([(-s, 0.0, -s), (s, 0.0, -s), (s, 0.0, s), (-s, 0.0, s)], [(0, 1, 2), (0, 2, 3)],
                             [(0.0, 0.0)] * 4), colour)
                spec.update(budget="plankton", tier=0, billboard=True, size=(L, 0.0, L), id=ident, facing={"kind": "none"})
                return finish_spec(spec, md, name, cat, None)
            md.add_part(ellipsoid((0, 0, 0), L, H, W, segs, rings), colour, tag=0)
            md.add_part(ellipsoid((0, -0.4 * L, 0), 0.16 * L, 0.2 * H, 0.2 * W, 4 if tier == 2 else 6, 3), colour,
                        tag=common.TAG_FRONT)     # tier 2's 150-triangle ceiling (06 6.3) takes a 4-sided nose
            if trait:                       # trait prey carry a ring (07 16)
                ring = [[(0.62 * W * math.cos(b) + 0.06 * L * math.cos(a) * math.cos(b), 0.06 * L * math.sin(a),
                          0.62 * H * math.sin(b) + 0.06 * L * math.cos(a) * math.sin(b)) for b in
                         (2.0 * math.pi * j / 12 for j in range(12))] for a in (2.0 * math.pi * i / 6 for i in range(6))]
                md.add_part(torus(ring), common.colour("signal.pearl"))
            spec.update(budget="trait_prey" if trait else "prey_t%d" % max(1, min(6, tier)), tier=tier)
        else:
            shape = {"barracuda": "wedge", "old_scar": "wedge", "moray": "tube", "grouper": "sphere_lid", "gull": "cross",
                     "jelly_bloom": "sphere", "jelly": "sphere", "vent": "cone", "anemone": "ring", "hook": "ring"}.get(ident, "wedge")
            if shape == "wedge" and ident == "barracuda":   # 07 7: RIG_Barracuda, 12 bones (placeholder_rigs.py)
                import placeholder_rigs
                arm = meshgen.build_armature("RIG_Barracuda", placeholder_rigs.barracuda_bones(L, H, W))
                wts = placeholder_rigs.barracuda_weights(L, H)
                rings = []
                for i in range(1, 16):     # a wedge: grows from the nose to 60% of the length, tapers to the tail
                    t = i / 16.0
                    y = -L / 2.0 + L * t
                    r = 0.2 + 0.8 * t / 0.6 if t <= 0.6 else 1.0 - 0.6 * (t - 0.6) / 0.4
                    rings.append([(W / 2 * r * math.sin(a), y, H / 2 * r * math.cos(a)) for a in (2.0 * math.pi * j / 12 for j in range(12))])
                md.add_part(meshgen.loft(rings, (0, -L / 2.0, 0), (0, L / 2.0, 0)), colour, weights=wts)
                spec.update(rig="Barracuda", armature=arm)
                shape = "done"              # faces by its bones: Jaw at the front, TailFin at the back
            elif shape == "wedge":
                md.add_part(meshgen.prism([(-W / 2, L / 2, -H / 2), (0, -L / 2, -H / 2), (W / 2, L / 2, -H / 2)], (0, 0, H)), colour)
            elif shape == "tube":
                H = W = 0.08 * L
                md.add_part(ellipsoid((0, 0, 0), L, H, W, 12, 16), colour)
            elif shape in ("sphere", "sphere_lid"):
                W = 0.5 * L if shape == "sphere_lid" else L
                H = H if shape == "sphere_lid" else L
                if "Squeezed" in parts:     # the pulse pose: a narrower, taller bell
                    W, H, L = 0.75 * W, 1.2 * H, 0.75 * L
                lid = shape == "sphere_lid"
                md.add_part(ellipsoid((0, 0, -0.06 * H if lid else 0.0), L, 0.88 * H if lid else H, W, 16 if lid else 14, 10), colour)
                if shape == "sphere_lid":   # the hinged lid: a cap over the front top
                    md.add_part(ellipsoid((0, -0.2 * L, 0.38 * H), 0.5 * L, 0.24 * H, 0.8 * W, 10, 5), colour)
            elif shape == "cross":          # the Gull: 8 wingspan across X, body along Y
                W, H = L, 0.2 * L
                L = 0.45 * W
                md.add_part(meshgen.box((-W / 2, -0.1 * L, -0.05 * H), (W / 2, 0.15 * L, 0.05 * H)), colour)
                md.add_part(meshgen.box((-0.06 * W, -L / 2, -H / 2), (0.06 * W, L / 2, H / 2)), colour)
            elif shape == "cone":
                md.add_part(meshgen.loft([[(0.5 * L * math.cos(a), 0.5 * L * math.sin(a), -L / 2)
                                           for a in (2.0 * math.pi * j / 12 for j in range(12))]],
                                         (0, 0, -L / 2), (0, 0, L / 2)), colour)
                W = H = L
            # a small tagged nose block inside the bounds marks the front (-Y) for the facing check
            if shape != "done":
                    md.add_part(meshgen.box((-0.04 * W, -0.5 * L, -0.04 * H), (0.04 * W, -0.42 * L, 0.04 * H)), "#3D3D3D",
                                tag=common.TAG_FRONT)
            import budgets                  # the row's own class where 06 6.3 has one (barracuda, jelly), else a block
            spec.update(budget=ident if ident in budgets.BUDGETS else "placeholder_block")
        spec.update(size=None, id=ident, facing={"kind": "bones", "front": "Jaw", "back": "TailFin"} if arm else {"kind": "tag"})
    else:                                   # Env, Cove, Prop, Trait: grey blocks (07 16)
        text = column(row, "Size") + " " + desc
        m = re.search(r"(\d+(?:\.\d+)?)\s*×\s*(\d+(?:\.\d+)?)(?:\s*×\s*(\d+(?:\.\d+)?))?\s*studs", text)
        if m:
            W, L = float(m.group(1)), float(m.group(2))
            H = float(m.group(3)) if m.group(3) else max(1.0, 0.25 * min(W, L))
        else:
            W = L = H = 0.5 if cat == "Trait" else 4.0
        zone = parts[2] if parts[2] in ("Nursery", "Reef", "Kelp", "DropOff", "Trench") else None
        zone_key = {"DropOff": "dropoff_upper"}.get(zone, (zone or "").lower())
        colour = (name_colour(name, ("rarity",)) if "_LM_" in name else
                  common.colour("water.%s.fog" % zone_key) if zone else "#9A9A9A")
        if name == "M_Cove_PearlClam":      # 07 11: "Two bones": a shell box and a lid box hinged at the back
            import placeholder_rigs
            hinge = 0.6 * H
            arm = meshgen.build_armature("RIG_PearlClam", placeholder_rigs.clam_bones(L, hinge))
            md.add_part(meshgen.box((-W / 2, -L / 2, 0.0), (W / 2, L / 2, hinge - 0.02)), colour, weights={"Shell": 1.0})
            md.add_part(meshgen.box((-W / 2, -L / 2, hinge), (W / 2, L / 2, H)), colour, weights={"Lid": 1.0})
            spec.update(rig="PearlClam", armature=arm, face_uvs=True)
        else:
            md.add_part(meshgen.box((-W / 2, -L / 2, 0.0), (W / 2, L / 2, H)), colour)
        md.add_part(meshgen.box((-0.1 * W, -0.5 * L, 0.98 * H), (0.1 * W, -0.35 * L, 1.05 * H)), "#3D3D3D",
                    tag=common.TAG_FRONT, weights={"Lid": 1.0} if arm else None)   # front marker on top, inside the footprint
        spec.update(budget="placeholder_block", origin="prop", facing={"kind": "tag"}, size=(W, L, 1.05 * H))

    return finish_spec(spec, md, name, cat, arm)


def finish_spec(spec, md, name, cat, arm):
    """Object, UVs, stamped material, skin, exports and preview of a mesh placeholder."""
    import meshgen
    root = OUT
    obj = md.to_object(name, "GEO")
    import uvlayout
    tex = TEXTURE or {}
    rect = tuple(tex.get("rect") or ((0.0, 0.5, 1.0, 1.0) if cat == "Species" else (0.0, 0.0, 1.0, 1.0)))
    if spec.get("tier") == 2 and tex.get("focus"):
        rect = tuple(tex["focus"])          # tier 2's few faces sample too little of a small atlas cell: map onto its stamp
    uvlayout.project(obj, rect, tex.get("size", 256), "box" if cat in ("Env", "Cove", "Prop", "Trait") or spec.get("billboard") else "side")
    if spec.get("face_uvs") or spec.get("billboard") or cat in BLOCKS:
        face_uvs(obj, tuple(tex.get("focus") or rect))
    if tex.get("path"):
        spec["ph_texture"] = tex["path"]
        obj.data.materials.clear()
        obj.data.materials.append(textured_material("MAT_" + name, tex["path"]))
    spec["texture_note"] = "%s, cell %s" % (tex.get("name"), ", ".join("%.3f" % x for x in rect)) if tex else "none in 07"
    if arm:
        meshgen.skin(obj, arm)
    lo = [min(v.co[i] for v in obj.data.vertices) for i in range(3)]
    hi = [max(v.co[i] for v in obj.data.vertices) for i in range(3)]
    if spec.get("size") is None:
        spec["size"] = tuple(hi[i] - lo[i] for i in range(3))
    objs = [obj] + ([arm] if arm else [])
    spec.update(meshes=[{"object": obj, "role": "body", "primary": True, "skinned": bool(arm)}],
                exports=[{"file": os.path.join(root, "meshes", name + ".fbx"), "objects": objs}],
                actions=[],
                preview={"main": [obj], "lineup": [{"label": name, "objects": [obj]}], "lineup_caption": ["placeholder"],
                         "extras": [], "texture": "placeholder " + spec["texture_note"]})
    return spec


def face_uvs(obj, rect, share=1.0, lift=0.0):
    """Every face shows the whole stamped cell (two-box props, whose box projection would give
    thin faces a sliver); `share` < 1 keeps a billboard's two triangles on the stamp in the
    middle of its cell (texgen.stamp sets "PH" a tenth of the cell above the middle: `lift`)."""
    u0, v0, u1, v1 = rect
    cu, cv = (u0 + u1) / 2.0, (v0 + v1) / 2.0 + lift * (v1 - v0)
    hu, hv = (u1 - u0) / 2.0 * share, (v1 - v0) / 2.0 * share
    uv = obj.data.uv_layers.active.data
    lo = [min(d.uv[i] for d in uv) for i in (0, 1)]
    hi = [max(d.uv[i] for d in uv) for i in (0, 1)]
    for poly in obj.data.polygons:
        loops = list(poly.loop_indices)
        if len(loops) == 4:
            for li, (a, b) in zip(loops, ((-1, -1), (1, -1), (1, 1), (-1, 1))):
                uv[li].uv = (cu + a * hu, cv + b * hv)
        else:                       # triangles: the mesh's own UV bounds stretched onto the box
            for li in loops:
                u, v = uv[li].uv
                uv[li].uv = (cu + hu * (2.0 * (u - lo[0]) / max(hi[0] - lo[0], 1e-9) - 1.0),
                             cv + hv * (2.0 * (v - lo[1]) / max(hi[1] - lo[1], 1e-9) - 1.0))


TEXTURE = None      # set by blender_main: {"name", "path", "size", "rect"}


def textured_material(name, path):
    """The placeholder's one material: its stamped texture through the mesh's one UV set."""
    import bpy
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfDiffuse")
    img = nt.nodes.new("ShaderNodeTexImage")
    img.image = bpy.data.images.load(path, check_existing=True)
    nt.links.new(img.outputs["Color"], bsdf.inputs["Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def torus(rings):
    """Closed ring from a list of point loops (each loop one cross-section, joined end to end)."""
    n, m = len(rings), len(rings[0])
    verts = [tuple(p) for ring in rings for p in ring]
    faces = []
    for i in range(n):
        for j in range(m):
            a, b = i * m + j, ((i + 1) % n) * m + j
            faces.append((a, b, ((i + 1) % n) * m + (j + 1) % m, i * m + (j + 1) % m))
    return verts, faces, [(0.0, 0.0)] * len(verts)


# ---------------------------------------------------------------- clips (inside Blender)

# The body each clip is played on: the family clips on the reference Minnow (06 section 7.3),
# a species' or prop's own clips on its own mesh. The rig travels in that body's spec.
CLIP_HOSTS = {"Fish": "M_Species_Minnow_Juv", "Minnow": "M_Species_Minnow_Juv", "Puffer": "M_Species_Puffer_Juv",
              "Barracuda": "M_Pred_Barracuda", "PearlClam": "M_Cove_PearlClam"}


def clip_host(name):
    owner, action = name.split("_")[1], name.split("_")[2]
    if owner == "Puffer" and action == "PuffHold":
        return "M_Species_Puffer_Juv_Puffed"          # 07: "slow bob and paddle on the puffed mesh"
    return CLIP_HOSTS.get(owner)


def clip_spec(name, row):
    """A_<Rig>_<Action>: the host body on its real skeleton, one procedural action of the row's
    length (07 section 16), exported as one take with the rig and the body."""
    import placeholder_rigs
    host = clip_host(name)
    if not host:
        raise SystemExit("%s: no placeholder rig for '%s' yet" % (name, name.split("_")[1]))
    frames, loop = placeholder_rigs.clip_length(row)
    if not frames:
        raise SystemExit("%s: chapter 07 gives no length in frames" % name)
    spec = mesh_spec(host, find(host))
    arm = spec["armature"]
    owner, action = name.split("_")[1], name.split("_")[2]
    pose = placeholder_rigs.clip_pose(action, spec["rig"], spec["size"][1] / 3.0, set(b.name for b in arm.data.bones), owner)
    clip = placeholder_rigs.bake(arm, name, frames, loop, pose)
    body = spec["meshes"][0]["object"]
    spec.update(name=name, host=host, actions=[clip],
                exports=[{"file": os.path.join(OUT, "animations", name + ".fbx"), "objects": [body, arm], "clip": clip}])
    spec["preview"]["lineup_caption"] = ["placeholder clip %s, %d frames%s, on %s" % (name, frames, " loop" if loop else "", host)]
    return spec


BILLBOARD_WAIVER = "06 6.3: plankton is a 2-triangle camera-facing billboard: open, flat and without a front by design"


def billboard_validation():
    """The plankton billboard cannot be watertight or enclose a volume: those two checks are
    recorded as waived (with the bible's reason) instead of failed. Nothing else is relaxed."""
    import validate
    if getattr(validate, "_ph_billboard", False):
        return
    plain = validate.check_mesh

    def check_mesh(spec, entry, report):
        if not spec.get("billboard"):
            return plain(spec, entry, report)
        add = report.add

        def waive(subject, check, ok, detail="", waiver=None):
            if not ok and check in ("watertight", "faces outward", "facing"):
                waiver = BILLBOARD_WAIVER
            return add(subject, check, ok, detail, waiver)
        report.add = waive
        try:
            return plain(spec, entry, report)
        finally:
            report.add = add
    validate.check_mesh = check_mesh
    validate._ph_billboard = True


def blender_batch(jobs_path, results_path):
    """Builds many mesh and clip rows in this one Blender process (template reloaded per row).
    Each result is appended to results_path as it lands, so a killed run resumes cleanly."""
    global TEXTURE
    import traceback
    import run
    billboard_validation()
    with open(jobs_path, encoding="utf-8") as f:
        jobs = json.load(f)
    for job in jobs:
        name = job["name"]
        TEXTURE = job.get("texture")
        err = ""
        try:
            row = find(name)
            if name.startswith("A_"):
                ok = run.run(None, ["build", "validate", "export", "preview"], builder=lambda: clip_spec(name, row))
            else:
                ok = run.run(None, list(run.IMPLEMENTED), builder=lambda: mesh_spec(name, row))
        except SystemExit as e:
            ok, err = False, str(e)
        except Exception:
            ok, err = False, traceback.format_exc()[-800:]
        with open(results_path, "a", encoding="utf-8") as f:
            f.write(json.dumps({"name": name, "ok": bool(ok), "error": err}) + "\n")
        print("[batch] %s %s %s" % (name, "OK" if ok else "FAILED", err.splitlines()[-1] if err else ""), flush=True)
    sys.exit(0)


def blender_main(*args):
    if not args or args[0] != "--batch":
        raise SystemExit("inside Blender: placeholder.py -- --batch <jobs.json> <results.jsonl>")
    blender_batch(args[1], args[2])


# ---------------------------------------------------------------- Blender jobs (outside Blender)

def blender_job(name, made=None):
    """The job a Blender batch needs for one M_ or A_ row: its name and its stamped texture,
    made here (Pillow is outside Blender). `made` caches textures already written this run."""
    host = clip_host(name) if name.startswith("A_") else name
    if host is None:
        raise SystemExit("%s: no placeholder rig for '%s' yet" % (name, name.split("_")[1]))
    job = {"name": name}
    tex = texture_for(host, find(host))
    if tex:
        made = made if made is not None else {}
        if tex not in made:
            path, note = texture(tex, find(tex))
            from PIL import Image
            made[tex] = (path, Image.open(path).size[0])
        path, size = made[tex]
        atlas = path.replace(".png", ".atlas.json")
        rect = json.load(open(atlas))["cells"].get(host) if os.path.exists(atlas) else None
        job["texture"] = {"name": tex, "path": path, "size": size, "rect": rect}
        if host in BILLBOARDS or host.split("_")[1] in BLOCKS or host.startswith("M_Prey_"):
            job["texture"]["focus"] = stamp_focus(path, rect or (0.0, 0.0, 1.0, 1.0))
    return job


BILLBOARDS = ("M_Prey_Plankton",)
BLOCKS = ("Env", "Cove", "Prop", "Trait")   # block-out pieces: every face shows its cell's stamp


def stamp_focus(path, rect):
    """The UV box around the stamp ink inside a texture cell. A 2-triangle billboard maps onto it,
    so its two faces show the "PH" stamp (07 section 16) rather than mostly the flat tint. The
    margin is the first that puts at least 3 of validate.check_ph_stamp's lattice samples on ink,
    centred (thin strokes can fall between the lattice points)."""
    from PIL import Image
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    u0, v0, u1, v1 = rect
    ink = [(x, y) for x in range(int(u0 * w), int(u1 * w)) for y in range(int((1 - v1) * h), int((1 - v0) * h))
           if max(px[x, y]) < 38]
    if not ink:
        return list(rect)
    x0, x1 = min(x for x, _ in ink) / w, (max(x for x, _ in ink) + 1) / w
    y0, y1 = 1 - (max(y for _, y in ink) + 1) / h, 1 - min(y for _, y in ink) / h

    def lattice(box):                   # the samples check_ph_stamp takes over the two triangles
        a, b, c, d = (box[0], box[1]), (box[2], box[1]), (box[2], box[3]), (box[0], box[3])
        hits = []
        for p, q, r in ((a, b, c), (a, c, d)):
            for i in range(7):
                for j in range(7 - i):
                    u = (p[0] * (6 - i - j) + q[0] * i + r[0] * j) / 6
                    v = (p[1] * (6 - i - j) + q[1] * i + r[1] * j) / 6
                    if max(px[min(w - 1, int(u * w)), min(h - 1, int((1 - v) * h))]) < 38:
                        hits.append((u, v))
        if len(hits) < 3:
            return False
        return all(0.3 <= (sum(hh[i] for hh in hits) / len(hits) - box[i]) / (box[i + 2] - box[i]) <= 0.7 for i in (0, 1))

    for k in range(0, 41):
        m = 0.01 * k
        mx, my = m * (x1 - x0), m * (y1 - y0)
        box = [max(u0, x0 - mx), max(v0, y0 - my), min(u1, x1 + mx), min(v1, y1 + my)]
        if lattice(box):
            return box
    return [x0, y0, x1, y1]


def run_blender(jobs, tag="batch"):
    """One Blender process for all `jobs`, through the heavy-job wrapper. Returns {name: result}."""
    logs = os.path.join(OUT, "logs")
    os.makedirs(logs, exist_ok=True)
    jobs_path, results = os.path.join(logs, tag + ".jobs.json"), os.path.join(logs, tag + ".results.jsonl")
    write_json(jobs_path, jobs)
    if os.path.exists(results):
        os.remove(results)
    cmd = [heavy_wrapper(), "--owner", os.environ.get("GULP_HEAVY_OWNER", "gulp-placeholders"), "--game", "Gulp", "--",
           BLENDER, "--background", "--python", os.path.abspath(__file__), "--", "--batch", jobs_path, results]
    with open(os.path.join(logs, tag + ".log"), "w") as f:
        subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT)
    out = {}
    if os.path.exists(results):
        with open(results, encoding="utf-8") as f:
            for line in f:
                r = json.loads(line)
                out[r["name"]] = r
    for job in jobs:
        out.setdefault(job["name"], {"name": job["name"], "ok": False, "error": "Blender stopped before this row (see logs/%s.log)" % tag})
    return out


# ---------------------------------------------------------------- command line

KINDS = {"T": texture, "FX": effect, "LGT": lighting, "SKY": sky, "SFX": sound, "MUS": music}


def make(name):
    row = find(name)
    prefix = name.split("_")[0]
    if prefix in ("M", "A"):
        r = run_blender([blender_job(name)], "single_" + name)[name]
        print("[placeholder] %s %s %s" % (name, "OK" if r["ok"] else "FAILED", r["error"]))
        return r["ok"]
    if prefix in ("SCN", "RIG"):
        print("%s: no placeholder generated (%s)" % (name, {"SCN": "07 16: none needed",
                                                            "RIG": "skeletons travel inside the species placeholders"}[prefix]))
        return True
    if prefix not in KINDS:
        raise SystemExit("%s: no placeholder kind for prefix %s" % (name, prefix))
    path, note = KINDS[prefix](name, row)
    print("[placeholder] %s -> %s (%s; row in 07 section %s)" % (name, os.path.relpath(path, common.REPO_DIR), note,
                                                                row["section"].split(" ")[0]))
    return True


def main(argv):
    if "--list" in argv:
        prefix = argv[argv.index("--list") + 1] if len(argv) > argv.index("--list") + 1 else ""
        print("\n".join(n for r in rows() for n in r["names"] if n.startswith(prefix)))
        return 0
    if not argv:
        print(__doc__)
        return 2
    heavy = [n for n in argv if n.split("_")[0] in ("M", "A")]
    ok = True
    if heavy:
        made = {}
        for n, r in run_blender([blender_job(n, made) for n in heavy], "cli").items():
            print("[placeholder] %s %s %s" % (n, "OK" if r["ok"] else "FAILED", r["error"]))
            ok = ok and r["ok"]
    return 0 if all([make(n) for n in argv if n not in heavy]) and ok else 1


if __name__ == "__main__":
    try:
        import bpy  # noqa: F401
        IN_BLENDER = True
    except ImportError:
        IN_BLENDER = False
    if IN_BLENDER:
        blender_main(*sys.argv[sys.argv.index("--") + 1:])
    else:
        sys.exit(main(sys.argv[1:]))
