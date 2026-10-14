"""Batch placeholders for every row of assets/manifest.csv (docs/13-sprint-plan.md, S1-A2; rules in
docs/07-asset-list.md section 16).

    python3 assets/source/_shared/blender/placeholder_batch.py [--only <glob>] [--force] [--chunk N] [--no-sheets]
    python3 assets/source/_shared/blender/placeholder_batch.py --sheets          contact sheets and report only

Resumable: a row is skipped when its last result passed and every output file is newer than
every input (the generator and Blender library in this folder, chapters 06 and 07, the
palette). Mesh rows and clips run in Blender, many rows per process (--chunk, default 80),
one process at a time, each through the heavy-job wrapper; distance versions and shells
(`_LOD1`, `_Shell`, ...) are made by their body's run, not a run of their own. Everything else
runs here. Results land in assets/placeholder/batch_state.json as each row finishes.

Writes the tally to assets/review/placeholders_report.md and one contact sheet per 07 section 16
kind to assets/review/placeholders/<kind>_sheet.png (a few representative rows, Pillow grid,
at most 1536 px wide). Nothing is uploaded and the manifest is never written.
"""
import csv
import fnmatch
import glob
import json
import os
import re
import subprocess
import sys
import time

LIB_DIR = os.path.dirname(os.path.abspath(__file__))
if LIB_DIR not in sys.path:
    sys.path.insert(0, LIB_DIR)

import common  # noqa: E402
import placeholder  # noqa: E402

MANIFEST = os.path.join(common.ASSETS_DIR, "manifest.csv")
OUT = placeholder.OUT
STATE = os.path.join(OUT, "batch_state.json")
REPORT = os.path.join(common.REVIEW_DIR, "placeholders_report.md")
SHEETS = os.path.join(common.REVIEW_DIR, "placeholders")
DERIVED = re.compile(r"^(M_.*?)((?:_LOD\d)?(?:_Shell|_ShellThick)?)$")

# 07 section 16, the thirteen kinds, in its order
KINDS = ["Playable species", "Patterns", "Traits", "Prey and trait prey", "Predators and hazards", "Environment",
         "Cove and decorations", "Water and sky", "Effects", "Lighting", "Sound effects", "Music", "Store page"]


def kind(name):
    p = name.split("_")
    if name.startswith(("FX_", "T_FX_")):
        return "Effects"
    if p[0] == "LGT":
        return "Lighting"
    if p[0] == "SFX":
        return "Sound effects"
    if p[0] == "MUS":
        return "Music"
    if p[0] == "SCN":
        return "Store page"
    if p[0] == "SKY" or name.startswith(("T_Sky", "T_Surface", "T_SunPool", "T_Caustics", "M_Water")):
        return "Water and sky"
    if any(x.startswith("Pat") for x in p[2:]):
        return "Patterns"
    if name.startswith(("M_Trait", "T_Trait_")):
        return "Traits"
    if name.startswith(("M_Prey", "T_Prey", "T_TraitPrey")):
        return "Prey and trait prey"
    if name.startswith(("M_Pred", "M_Hazard", "A_Barracuda", "T_Barracuda", "T_Jelly")):
        return "Predators and hazards"
    if name.startswith(("M_Cove", "A_PearlClam", "T_Cove", "T_BubbleShell")) or (p[0] == "M" and p[1] == "Prop" and p[2] != "Nursery"):
        return "Cove and decorations"
    if name.startswith(("M_Species", "A_Fish", "A_Minnow", "A_Puffer", "T_Minnow", "T_Puffer", "T_Shared_Eye")):
        return "Playable species"
    return "Environment"


def manifest_rows():
    with open(MANIFEST, newline="", encoding="utf-8") as f:
        return [r["name"] for r in csv.DictReader(f)]


def unit(name):
    """The run that makes a row: a mesh's distance versions and shells come from its body."""
    if name.startswith("M_"):
        m = DERIVED.match(name)
        return m.group(1)
    return name


def outputs(name):
    p = name.split("_")[0]
    if p == "M":
        return [os.path.join(OUT, "meshes", name + ".fbx")]
    if p == "A":
        return [os.path.join(OUT, "animations", name + ".fbx")]
    if p == "T":
        return [os.path.join(OUT, "textures", name + ".png")]
    if p == "FX":
        return [os.path.join(OUT, "fx", name + ".json")]
    if p == "LGT":
        return [os.path.join(OUT, "lighting", name + ".json")]
    if p == "SKY":
        return [os.path.join(OUT, "lighting", name, "%s_%s.png" % (name, f)) for f in ("Up", "Ft", "Bk", "Lf", "Rt", "Dn")]
    if p == "SFX":
        return [os.path.join(OUT, "audio", "sfx", name + ".ogg")]
    if p == "MUS":
        return [os.path.join(OUT, "audio", "music", s + ".ogg") for s in placeholder.stem_names(name, placeholder.find(name))]
    return []


def inputs_mtime():
    files = glob.glob(os.path.join(LIB_DIR, "*.py")) + [placeholder.DOC, placeholder.BIBLE, common.PALETTE_JSON]
    return max(os.path.getmtime(f) for f in files if os.path.exists(f))


def fresh(name, state, since):
    outs = outputs(name)
    return (state.get(name, {}).get("ok") and outs and all(os.path.exists(o) and os.path.getmtime(o) > since for o in outs))


# ---------------------------------------------------------------- checks of files made outside Blender

def duration(path):
    done = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                          capture_output=True, text=True)
    try:
        return float(done.stdout.strip())
    except ValueError:
        return 0.0


def check_file(name):
    """The validate step for rows made without Blender. Returns (ok, detail)."""
    p = name.split("_")[0]
    outs = outputs(name)
    missing = [o for o in outs if not os.path.exists(o)]
    if missing:
        return False, "missing " + ", ".join(os.path.relpath(m, common.REPO_DIR) for m in missing)
    row = placeholder.find(name)
    if p in ("T", "SKY"):
        from PIL import Image
        import texgen
        for o in outs:
            im = Image.open(o).convert("RGBA")
            w, h = im.size
            if w != h or w & (w - 1) or w > texgen.MAX_TEXTURE:
                return False, "%s is %dx%d: square power of two up to %d" % (os.path.basename(o), w, h, texgen.MAX_TEXTURE)
            if name.startswith("T_FX_"):
                continue                     # the one soft dot: no stamp (07 16)
            ink = sum(1 for px in im.getdata() if px[3] > 0 and max(px[:3]) < 38) / float(w * h)
            if ink < 0.005:
                return False, "%s shows no PH stamp (%.2f%% ink)" % (os.path.basename(o), 100 * ink)
        return True, "%d image(s), %dpx, PH stamp" % (len(outs), w) if not name.startswith("T_FX_") else "soft dot %dpx" % w
    if p in ("FX", "LGT"):
        data = json.load(open(outs[0]))
        ok = data.get("name") == name and data.get("placeholder") is True
        return ok, "name and placeholder flag" + ("" if ok else " wrong")
    if p == "SFX":
        want = placeholder.seconds(placeholder.column(row, "Length", "Size"), 0.4)
        got = duration(outs[0])
        loop = got >= 2.0 and want < 2.0
        ok = got > 0 and (loop or abs(got - want) <= 0.05 * want + 0.03)
        return ok, "%.2f s (row %.2f s%s)" % (got, want, ", loop held to 2 s" if loop else "")
    if p == "MUS":
        lengths = [duration(o) for o in outs]
        ok = all(x > 0 for x in lengths) and max(lengths) - min(lengths) < 0.05
        return ok, "%d stem(s) of %.2f s" % (len(outs), lengths[0])
    return False, "no check for this prefix"


# ---------------------------------------------------------------- batch

def load_state():
    return json.load(open(STATE)) if os.path.exists(STATE) else {}


def save_state(state):
    os.makedirs(OUT, exist_ok=True)
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f, indent=1, sort_keys=True)
    os.replace(tmp, STATE)


def failed_checks(name):
    reports = sorted(glob.glob(os.path.join(common.REVIEW_DIR, name, "*_report.json")))
    if not reports:
        return ""
    rows = json.load(open(reports[-1])).get("checks", [])
    bad = ["%s %s: %s" % (r.get("subject"), r.get("check"), r.get("detail")) for r in rows if not r.get("ok") and not r.get("waiver")]
    return "; ".join(bad[:4])


def run_batch(only=None, force=False, chunk=80):
    names = manifest_rows()
    if only:
        names = [n for n in names if any(fnmatch.fnmatchcase(n, pat) for pat in only.split(","))]
    state = load_state()
    since = inputs_mtime()
    todo = [n for n in names if force or not fresh(n, state, since)]
    print("[batch] %d rows, %d to make" % (len(names), len(todo)))
    blender = [n for n in todo if n.split("_")[0] in ("M", "A")]
    for name in [n for n in todo if n not in blender]:
        try:
            import contextlib
            os.makedirs(os.path.join(OUT, "logs"), exist_ok=True)
            with open(os.path.join(OUT, "logs", "batch_files.log"), "a") as log, contextlib.redirect_stdout(log):
                placeholder.make(name)
            ok, detail = check_file(name)
        except (SystemExit, Exception) as e:
            ok, detail = False, "%s: %s" % (type(e).__name__, e)
        state[name] = {"ok": ok, "detail": detail, "unit": name, "time": time.strftime("%Y-%m-%d %H:%M")}
        if not ok:
            print("[batch] FAILED %s: %s" % (name, detail))
    save_state(state)
    units = []
    for n in blender:
        if unit(n) not in units:
            units.append(unit(n))
    made = {}
    jobs, bad = [], {}
    for u in units:
        try:
            jobs.append(placeholder.blender_job(u, made))
        except (SystemExit, Exception) as e:
            bad[u] = {"ok": False, "error": str(e)}
    for i in range(0, len(jobs), chunk):
        part = jobs[i:i + chunk]
        print("[batch] Blender %d/%d: %d rows" % (i // chunk + 1, (len(jobs) + chunk - 1) // chunk, len(part)), flush=True)
        results = placeholder.run_blender(part, "batch_%02d" % (i // chunk + 1))
        results.update(bad)
        for n in blender:
            r = results.get(unit(n))
            if r is None:
                continue
            exists = all(os.path.exists(o) for o in outputs(n))
            ok = r["ok"] and exists
            detail = "built, validated and exported by %s" % unit(n) if ok else (
                r.get("error") or failed_checks(unit(n)) or ("%s passed but made no %s" % (unit(n), n) if r["ok"] else "failed"))
            state[n] = {"ok": ok, "detail": detail[-400:], "unit": unit(n), "time": time.strftime("%Y-%m-%d %H:%M")}
        save_state(state)
    for u, r in bad.items():
        for n in blender:
            if unit(n) == u:
                state[n] = {"ok": False, "detail": r["error"], "unit": u, "time": time.strftime("%Y-%m-%d %H:%M")}
    save_state(state)
    return state


# ---------------------------------------------------------------- report and contact sheets

KIND_NOTES = {
    "Playable species": "capsule body, cone tail, eyes and lid caps on RIG_Fish with all sockets; puffed is a ball; "
                        "shells and distance versions by versions.py; clips are procedural moves of the row's length",
    "Patterns": "none in the slice",
    "Traits": "trait name tints over the family layout; pieces are blocks on their footprint",
    "Prey and trait prey": "ellipsoids by tier in a flat colour per prey, trait prey with a ring; plankton is a 2-triangle billboard",
    "Predators and hazards": "red primitives: Barracuda a wedge on RIG_Barracuda (12 bones) with its 3 clips; jelly a sphere in two poses",
    "Environment": "grey blocks at the row's footprint, zone tint, landmarks in their own colour",
    "Cove and decorations": "labelled blocks; the Pearl Clam has a hinged lid (Shell and Lid bones) and its Open clip",
    "Water and sky": "flat stamped textures; SKY_ is six flat two-colour faces",
    "Effects": "one white soft dot; emitter JSON tinted by type",
    "Lighting": "one neutral preset with the 06 10.2 fog colour and view distance",
    "Sound effects": "a beep of the row's length pitched by group; loops are soft noise",
    "Music": "eight-bar mallet loop at 124 bpm pitched by name, one file per stem; stingers are three notes",
    "Store page": "07 16: none needed",
}


def write_report(state):
    names = manifest_rows()
    lines = ["# Placeholder report (S1-A2)", "",
             "Generated by `assets/source/_shared/blender/placeholder_batch.py` on %s at commit %s. One line per kind of "
             "docs/07-asset-list.md section 16, for the %d rows of `assets/manifest.csv`. The files are in "
             "`assets/placeholder/` (git-ignored). A row passes when its file exists and passes validate: the Blender "
             "run's validate and export checks for meshes and clips, file checks (size, stamp, length, flags) for the rest."
             % (time.strftime("%Y-%m-%d"), common.git_commit(), len(names)), "",
             "| Kind | Rows | Pass | Fail | Stand-in |", "|---|---|---|---|---|"]
    fails = []
    for k in KINDS:
        rows = [n for n in names if kind(n) == k]
        ok = [n for n in rows if state.get(n, {}).get("ok")]
        lines.append("| %s | %d | %d | %d | %s |" % (k, len(rows), len(ok), len(rows) - len(ok), KIND_NOTES[k]))
        fails += [n for n in rows if n not in ok]
    total_ok = sum(1 for n in names if state.get(n, {}).get("ok"))
    lines += ["| **All** | **%d** | **%d** | **%d** | |" % (len(names), total_ok, len(names) - total_ok), "", "## Failures", ""]
    lines += ["- `%s`: %s" % (n, state.get(n, {}).get("detail", "not run")) for n in fails] or ["None."]
    lines += ["", "## Contact sheets", ""]
    lines += ["- `%s`" % os.path.relpath(p, common.REPO_DIR) for p in sorted(glob.glob(os.path.join(SHEETS, "*_sheet.png")))]
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("[batch] report %s: %d of %d pass" % (os.path.relpath(REPORT, common.REPO_DIR), total_ok, len(names)))


def cell_image(name, size):
    """A preview of one row for a contact sheet."""
    from PIL import Image, ImageDraw
    p = name.split("_")[0]
    if p in ("M", "A"):
        sheets = sorted(glob.glob(os.path.join(common.REVIEW_DIR, unit(name), "*_sheet.png")))
        if sheets:
            return Image.open(sheets[-1]).convert("RGB")
    if p == "T":
        return Image.open(outputs(name)[0]).convert("RGB")
    if p == "SKY":
        faces = [Image.open(o).convert("RGB").resize((size // 3, size // 3)) for o in outputs(name)]
        img = Image.new("RGB", (size, size // 3 * 2), "#202020")
        for i, f in enumerate(faces):
            img.paste(f, ((i % 3) * (size // 3), (i // 3) * (size // 3)))
        return img
    img = Image.new("RGB", (size, size), "#202020")
    d = ImageDraw.Draw(img)
    if p in ("FX", "LGT"):
        data = json.load(open(outputs(name)[0]))
        colour = data.get("colour") or data.get("Atmosphere", {}).get("Color") or "#808080"
        d.rectangle((size // 8, size // 8, size * 7 // 8, size // 2), fill=colour)
        text = ["%s: %s" % (k, v) for k, v in data.items() if not isinstance(v, dict)][1:7]
        for i, t in enumerate(text):
            d.text((10, size // 2 + 10 + 16 * i), str(t)[:60], fill="#E0E0E0")
        return img
    if p in ("SFX", "MUS"):
        outs = outputs(name)
        for s, o in enumerate(outs):
            raw = subprocess.run(["ffmpeg", "-v", "error", "-i", o, "-ac", "1", "-ar", "2000", "-f", "s16le", "-"],
                                 capture_output=True).stdout
            vals = [int.from_bytes(raw[i:i + 2], "little", signed=True) for i in range(0, len(raw) - 1, 2)]
            band = size // len(outs)
            mid = band * s + band // 2
            n = max(1, len(vals) // size)
            for x in range(size):
                chunk = vals[x * n:(x + 1) * n] or [0]
                a = max(abs(v) for v in chunk) / 32768.0 * band / 2
                d.line((x, mid - a, x, mid + a), fill="#7FD0FF")
        d.text((6, size - 18), "%.2f s, %d file(s)" % (duration(outs[0]), len(outs)), fill="#E0E0E0")
        return img
    return img


def contact_sheets(state, per_kind=8, cell=384, cols=4):
    from PIL import Image, ImageDraw
    os.makedirs(SHEETS, exist_ok=True)
    made = []
    for k in KINDS:
        rows = [n for n in manifest_rows() if kind(n) == k and state.get(n, {}).get("ok") and unit(n) == n]
        if not rows:
            continue
        step = max(1, len(rows) / float(per_kind))
        pick = [rows[int(i * step)] for i in range(min(per_kind, len(rows)))]
        r = (len(pick) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * cell, r * (cell + 20)), "#111111")
        d = ImageDraw.Draw(sheet)
        for i, n in enumerate(pick):
            try:
                img = cell_image(n, cell)
            except Exception as e:  # noqa: BLE001  (a sheet cell must not stop the report)
                img = Image.new("RGB", (cell, cell), "#400000")
                ImageDraw.Draw(img).text((6, 6), str(e)[:50], fill="#FFFFFF")
            img.thumbnail((cell, cell))
            x, y = (i % cols) * cell, (i // cols) * (cell + 20)
            sheet.paste(img, (x + (cell - img.size[0]) // 2, y + (cell - img.size[1]) // 2))
            d.text((x + 4, y + cell + 3), n[:56], fill="#FFFFFF")
        path = os.path.join(SHEETS, re.sub(r"[^a-z]+", "_", k.lower()).strip("_") + "_sheet.png")
        sheet.save(path)
        made.append(path)
    return made


def main(argv):
    def opt(flag, default=None):
        return argv[argv.index(flag) + 1] if flag in argv else default
    if "--sheets" in argv:
        state = load_state()
    else:
        state = run_batch(opt("--only"), "--force" in argv, int(opt("--chunk", 80)))
    if "--no-sheets" not in argv:
        for p in contact_sheets(state):
            print("[batch] sheet %s" % os.path.relpath(p, common.REPO_DIR))
    write_report(state)
    names = manifest_rows()
    only = opt("--only")
    if only:
        names = [n for n in names if any(fnmatch.fnmatchcase(n, pat) for pat in only.split(","))]
    return 0 if all(state.get(n, {}).get("ok") for n in names) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
