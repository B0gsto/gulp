"""Placeholder generator (docs/07-asset-list.md section 14.1 tool row; rules in section 16).

    python3 assets/source/_shared/blender/placeholder.py <AssetName> [<AssetName> ...]
    python3 assets/source/_shared/blender/placeholder.py --list <prefix>      names chapter 07 knows

One command builds the stand-in for a named row of chapter 07, under the final name, in
assets/placeholder/ (07 section 1.3), laid out like assets/export/. Names are read from the
chapter 07 tables themselves; a name that is not in them is refused.

  M_*    meshes, built in Blender (this file re-runs itself under the heavy-job wrapper) through
         run.py: build, lod, shell, validate, export, preview. Species: capsule, cone tail, eyes,
         lid caps on the real family skeleton (Fish family only so far). Prey: ellipsoids by
         tier, trait prey with a ring. Predators and hazards: red-toned primitives. Env, cove,
         props and trait pieces: grey blocks at the footprint the row gives.
  T_*    flat tint, "PH" stamp and the name (texgen.py); effect textures are the soft dot.
  FX_*   emitter settings JSON on the soft dot, tinted by type.
  LGT_*  one neutral preset with the fog colour and view distance of 06 section 10.2.
  SKY_*  six flat two-colour faces.
  SFX_*  a beep of the row's length pitched by group, loops are soft noise (ffmpeg, OGG Vorbis).
  MUS_*  an eight-bar mallet loop at 124 bpm pitched by name; stingers are three notes.
  A_*, SCN_*  not generated yet (A_: needs every family skeleton; SCN_: 07 says none needed).
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
            m = re.match(r"^(.*?)(\d+)[–-](\d+)$", part)
            if m:
                width = len(m.group(2))
                names += [m.group(1) + str(i).zfill(width) for i in range(int(m.group(2)), int(m.group(3)) + 1)]
            else:
                names.append(part)
            prev = part
    return names


def rows():
    """Every table row of chapter 07 whose Asset cell names files, with its section."""
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
        img = texgen.soft_dot(size)
        note = "white soft dot (07 16: one effect texture for everything)"
    else:
        species = pascal_to_id(parts[1])
        try:
            hexcode = common.colour("creatures.%s.mid" % species)
        except KeyError:
            hexcode = "#9A9A9A"
        label = name
        if any(p.startswith("Pat") for p in parts):
            hexcode = name_colour(name)                      # 07 16: a different flat tint per pattern
        if parts[1] == "Trait" and len(parts) > 3 and parts[2] != "Pieces":
            hexcode, label = name_colour(parts[2], ("rarity", "creatures")), parts[2].upper()   # trait name in big letters
        users = texture_users(name) if "atlas" in row.get("Description", "").lower() else []
        if len(users) > 1:                   # a shared atlas: one stamped cell per mesh that uses it
            n = math.ceil(math.sqrt(len(users)))
            cell = size // n
            rects = texgen.atlas_rects([(u, cell, cell) for u in users], size)
            img = texgen.flat(size, "#9A9A9A", False)
            for u in users:
                r = rects[u]
                img.paste(texgen.flat(cell, mesh_colour(u), u.split("_", 2)[-1]), (int(r[0] * size), int((1.0 - r[3]) * size)))
            texgen.stamp(img, None)
            write_json(path.replace(".png", ".atlas.json"), {"texture": name, "cells": rects})
            note = "atlas of %d stamped %d px cells (texgen.atlas_rects)" % (len(users), cell)
        else:
            family = species in common.palette()["creatures"] and parts[1] != "Trait"
            img = texgen.flat(size, hexcode, label, centre=0.25 if family else 0.5)   # family layout: stamp on the body region
            note = "flat %s, PH stamp" % hexcode
    img.save(path)
    return path, "%dx%d, %s" % (size, size, note)


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


def lighting(name, row):
    neutral = {"Brightness": 2.0, "Ambient": "#808080", "OutdoorAmbient": "#808080", "ColorShift_Top": "#FFFFFF",
               "ExposureCompensation": 0.0, "Atmosphere": {"Density": 0.35, "Offset": 0.1, "Haze": 2.0, "Glare": 0.0}}
    key = name.split("_")[-1]
    fog = fog_table().get(ZONE_ROWS.get(key, ""), None)
    data = {"name": name, "placeholder": True, **neutral}
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


def music(name, row):
    beat = 60.0 / TEMPO
    root = 220.0 * 2 ** (seeded(name, 12) / 12.0)
    if name.startswith("MUS_Sting_"):
        notes, step = [0, 4, 7], beat / 2
    else:
        notes, step = [0, 7, 4, 7, 12, 7, 4, 7] * 4, beat      # eight bars of 4/4 in quarter notes = 32 beats
    length = len(notes) * step
    terms = []
    for i, semis in enumerate(notes):
        f = root * 2 ** (semis / 12.0)
        t0 = i * step
        terms.append("between(t,%.4f,%.4f)*sin(2*PI*%.2f*(t-%.4f))*exp(-7*(t-%.4f))" % (t0, t0 + step, f, t0, t0))
    expr = "0.45*(" + "+".join(terms) + ")"
    out = os.path.join(OUT, "audio", "music", name + ".ogg")
    ffmpeg(["-f", "lavfi", "-i", "aevalsrc='%s':d=%.3f:s=44100" % (expr, length)], out)
    return out, "%.2f s mallet %s at %d bpm, root %.0f Hz; one file, stems not split" % (
        length, "stinger" if len(notes) == 3 else "loop", TEMPO, root)


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
            for i in range(1, 15):
                y = -L / 2.0 + (body_end + L / 2.0) * i / 15.0
                rings.append([(half_w(y) * math.sin(a), y, half_h(y) * math.cos(a))
                              for a in (2.0 * math.pi * j / 16 for j in range(16))])
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
        segs, rings = ((8, 4) if tier <= 1 else (12, 7) if tier <= 4 else (16, 9))
        if cat == "Prey":
            if ident == "plankton":
                raise SystemExit("M_Prey_Plankton is a 2-triangle billboard: not a closed mesh, left to the effect tools")
            md.add_part(ellipsoid((0, 0, 0), L, H, W, segs, rings), colour, tag=0)
            md.add_part(ellipsoid((0, -0.4 * L, 0), 0.16 * L, 0.2 * H, 0.2 * W, 6, 3), colour, tag=common.TAG_FRONT)
            if trait:                       # trait prey carry a ring (07 16)
                ring = [[(0.62 * W * math.cos(b) + 0.06 * L * math.cos(a) * math.cos(b), 0.06 * L * math.sin(a),
                          0.62 * H * math.sin(b) + 0.06 * L * math.cos(a) * math.sin(b)) for b in
                         (2.0 * math.pi * j / 12 for j in range(12))] for a in (2.0 * math.pi * i / 6 for i in range(6))]
                md.add_part(torus(ring), common.colour("signal.pearl"))
            spec.update(budget="trait_prey" if trait else "prey_t%d" % max(1, min(6, tier)), tier=tier)
        else:
            shape = {"barracuda": "wedge", "old_scar": "wedge", "moray": "tube", "grouper": "sphere_lid", "gull": "cross",
                     "jelly_bloom": "sphere", "jelly": "sphere", "vent": "cone", "anemone": "ring", "hook": "ring"}.get(ident, "wedge")
            if shape == "wedge":
                md.add_part(meshgen.prism([(-W / 2, L / 2, -H / 2), (0, -L / 2, -H / 2), (W / 2, L / 2, -H / 2)], (0, 0, H)), colour)
            elif shape == "tube":
                H = W = 0.08 * L
                md.add_part(ellipsoid((0, 0, 0), L, H, W, 12, 16), colour)
            elif shape in ("sphere", "sphere_lid"):
                W = 0.5 * L if shape == "sphere_lid" else L
                H = H if shape == "sphere_lid" else L
                md.add_part(ellipsoid((0, 0, -0.06 * H), L, 0.88 * H, W, 16, 10), colour)
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
            md.add_part(meshgen.box((-0.04 * W, -0.5 * L, -0.04 * H), (0.04 * W, -0.42 * L, 0.04 * H)), "#3D3D3D",
                        tag=common.TAG_FRONT)
            spec.update(budget="placeholder_block")
        spec.update(size=None, id=ident, facing={"kind": "tag"})
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
        md.add_part(meshgen.box((-W / 2, -L / 2, 0.0), (W / 2, L / 2, H)), colour)
        md.add_part(meshgen.box((-0.1 * W, -0.5 * L, 0.98 * H), (0.1 * W, -0.35 * L, 1.05 * H)), "#3D3D3D",
                    tag=common.TAG_FRONT)          # front marker on top, inside the footprint
        spec.update(budget="placeholder_block", origin="prop", facing={"kind": "tag"}, size=(W, L, 1.05 * H))

    obj = md.to_object(name, "GEO")
    import uvlayout
    tex = TEXTURE or {}
    rect = tuple(tex.get("rect") or ((0.0, 0.5, 1.0, 1.0) if cat == "Species" else (0.0, 0.0, 1.0, 1.0)))
    uvlayout.project(obj, rect, tex.get("size", 256), "box" if cat in ("Env", "Cove", "Prop", "Trait") else "side")
    if tex.get("path"):
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


def blender_main(name, texture_json=None):
    global TEXTURE
    import run
    TEXTURE = json.loads(texture_json) if texture_json else None
    row = find(name)
    ok = run.run(None, list(run.IMPLEMENTED), builder=lambda: mesh_spec(name, row))
    sys.exit(0 if ok else 1)


# ---------------------------------------------------------------- command line

KINDS = {"T": texture, "FX": effect, "LGT": lighting, "SKY": sky, "SFX": sound, "MUS": music}


def make(name):
    row = find(name)
    prefix = name.split("_")[0]
    if prefix == "M":
        cmd = [heavy_wrapper(), "--owner", "gulp-art", "--game", "Gulp", "--", BLENDER, "--background",
               "--python", os.path.abspath(__file__), "--", name]
        tex = texture_for(name, row)
        if tex:
            path, note = texture(tex, find(tex))
            print("[placeholder] %s -> %s (%s)" % (tex, os.path.relpath(path, common.REPO_DIR), note))
            atlas = path.replace(".png", ".atlas.json")
            rect = json.load(open(atlas))["cells"].get(name) if os.path.exists(atlas) else None
            from PIL import Image
            cmd.append(json.dumps({"name": tex, "path": path, "size": Image.open(path).size[0], "rect": rect}))
        log = os.path.join(OUT, "logs", name + ".log")
        os.makedirs(os.path.dirname(log), exist_ok=True)
        with open(log, "w") as f:
            done = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT)
        with open(log) as f:
            lines = [l.rstrip() for l in f if l.startswith(("[run]", "[lod]", "[shell]", "[validate] FAIL", "[validate] PASS:",
                                                          "[validate] FAIL:", "[export]", "[versions]", "[preview]", "Traceback", "SystemExit"))
                     or "Error" in l]
        print("\n".join(lines[-40:]))
        return done.returncode == 0
    if prefix in ("A", "SCN", "RIG"):
        print("%s: no placeholder generated (%s)" % (name, {"SCN": "07 16: none needed", "A": "clips wait for every family skeleton",
                                                            "RIG": "skeletons travel inside the species placeholders"}[prefix]))
        return prefix == "SCN"
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
    return 0 if all([make(n) for n in argv]) else 1


if __name__ == "__main__":
    try:
        import bpy  # noqa: F401
        IN_BLENDER = True
    except ImportError:
        IN_BLENDER = False
    if IN_BLENDER:
        blender_main(*sys.argv[sys.argv.index("--") + 1:][:2])
    else:
        sys.exit(main(sys.argv[1:]))
