"""Clip tools (docs/07-asset-list.md section 14.1, "Clip tools"; rules in docs/06-art-bible.md
section 7, previews in 15.5).

Used from an asset's build.py and from run.py:
  bake(arm, name, pose_at)         keys every bone on every frame, at the length and loop flag that
                                   chapter 07 gives the clip (section 2.1 and every other A_ row)
  check(spec, clip, report)        the clip checks run by the validate step (below)
  export_entry(clip, objects)      the one-action A_*.fbx entry of a spec's "exports" list
  copy_to(clip, armature, name)    copy a clip to another species on the same family skeleton
  strip(clip, bones)               drop bones from a clip (the sway bones, 06 7.6, if code and
                                   clips cannot be layered); the checks then expect them unkeyed
  dump_json(clip)                  per bone its parent and rest matrix, per frame its local transform
  to_rbxm(spec, report, ok)        the `clips-rbxm` step: every clip as a click-free Roblox
                                   KeyframeSequence, binary .rbxm in assets/export/animations/
                                   (animrbx.py, then Lune luau/xml2rbxm.luau), read back and checked
  preview(spec, report, ok)        the `clips` step: per clip a strip of key poses (side and top)
                                   and a 2-second, 384-pixel clip (GIF, 30 fps) in
                                   assets/review/<A_name>/

Checks (any failure fails the build, like every validate row):
  length       frames match the 07 row (`loop 16 frames`, `14 frames`, `7 to 9 frames`)
  loop flag    the clip loops exactly when its 07 row says `loop`
  bone names   every curve drives a bone of the family rig (budgets.FAMILIES), position or rotation
               only: Roblox animations carry no bone scale (06 7.5)
  loop seam    first and last pose equal, and the motion through the seam continuous: the step
               from the last frame back to the first matches the steps either side of it (no hitch)
  no root motion  Root keeps its rest place (the creature is moved by code). The bible gives no
               root-motion rule; this is the tool's assumption. A clip may set "root_motion": True.
"""
import json
import os
import re
import shutil
import subprocess
import tempfile

import bpy

import budgets
import common
import preview as previewlib
import rigs

DOC = os.path.join(common.REPO_DIR, "docs", "07-asset-list.md")
PREVIEW_SIZE = 384            # 06 15.5: a 2-second, 384-pixel clip
STRIP_SIZE = 640              # key-pose strips larger, so every pose reads whole
PREVIEW_SECONDS = 2
STRIP_VIEWS = ("Side", "Top")  # the fish wave is sideways, so it reads from the top
CLIP_VIEW = "ThreeQuarter"
# Clips whose strips need more (S4-A3 review): bigger cells, and a close-up row of the head from
# the side (the front `head` share of the body), where the action is in the mouth.
# S6-A2: the hatch reads with its egg: a square 1536 sheet (06 15.5 sheet size) of side views of the
# Fry alone and three-quarter views with the egg (the build's spec "clip_props": objects and a
# per-frame hook that shows the whole egg or the thrown halves).
STRIP_EXTRA = {"A_Fish_Gulp": {"size": 800, "head": 0.45},
               "A_Fish_Hatch": {"views": ("Side", "ThreeQuarter"), "props_views": ("ThreeQuarter",), "square": 1536}}
ONLY_ENV = "GULP_ONLY_CLIPS"  # comma-separated A_ names: the clips step renders only those (the rest are unchanged)
RE_PATH = re.compile(r'^pose\.bones\["([^"]+)"\]\.(location|rotation_quaternion|rotation_euler|scale)$')
RE_LENGTH = re.compile(r"^\s*(loop\s+)?(\d+)(?:\s+to\s+(\d+))?\s+frames", re.I)


def doc_row(name):
    """{'min', 'max', 'loop', 'section'} for the A_ row of chapter 07 named `name`, or None."""
    import placeholder            # its chapter 07 reader; plain Python, no Blender state
    for row in placeholder.rows():
        if name in row["names"]:
            m = RE_LENGTH.match(placeholder.column(row, "Size", "Length"))
            if not m:
                return {"min": None, "max": None, "loop": False, "section": row["section"]}
            lo = int(m.group(2))
            return {"min": lo, "max": int(m.group(3) or lo), "loop": bool(m.group(1)), "section": row["section"]}
    return None


def bake(armature, name, pose_at, frames=None, keys=None):
    """Bakes the clip at its chapter 07 length (the middle of a range, or `frames`). Loops get a
    phase 0..1 and repeat frame 0 at the end; actions get the frame number."""
    row = doc_row(name)
    if row is None or row["min"] is None:
        raise RuntimeError("%s: no length for it in docs/07 (a clip must be a row there)" % name)
    frames = frames or (row["min"] + row["max"]) // 2
    if row["loop"]:
        clip = rigs.bake_clip(armature, name, frames, pose_at)
    else:
        import meshgen
        if armature.animation_data and armature.animation_data.action:
            armature.animation_data.action = None
        for frame in range(frames + 1):
            meshgen.apply_pose(armature, pose_at(frame))
            for pb in armature.pose.bones:
                pb.keyframe_insert("location", frame=frame)
                pb.keyframe_insert("rotation_quaternion", frame=frame)
        action = armature.animation_data.action
        action.name = name
        action.use_fake_user = True
        clip = {"action": action, "name": name, "start": 0, "end": frames, "loop": False, "armature": armature}
    clip["keys"] = keys or [(round(i * frames / 4.0), "") for i in range(4 if row["loop"] else 5)]
    return clip


def bake_family(armature, table, names=None):
    """Bakes every clip of a family table (rigs.FISH_CLIPS) or the listed ones."""
    return [bake(armature, n, table[n][0], keys=table[n][1]) for n in (names or table)]


def export_entry(clip, objects):
    return {"file": "animations/%s.fbx" % clip["name"], "objects": objects, "clip": clip}


def _fcurves(action):
    import validate
    return validate.action_fcurves(action)


def copy_to(clip, armature, name):
    """The same clip on another species of the family: same bone names, new A_ name."""
    have = {pb.name for pb in armature.pose.bones}
    missing = sorted({RE_PATH.match(fc.data_path).group(1) for fc in _fcurves(clip["action"])
                      if RE_PATH.match(fc.data_path)} - have)
    if missing:
        raise RuntimeError("%s cannot go on %s: no bones %s" % (clip["name"], armature.name, ", ".join(missing)))
    action = clip["action"].copy()
    action.name = name
    action.use_fake_user = True
    if armature.animation_data is None:
        armature.animation_data_create()
    armature.animation_data.action = action
    return dict(clip, action=action, name=name, armature=armature)


def strip(clip, bones):
    """Removes every curve of `bones` from the clip (06 7.6: sway bones left out of keyframed clips)."""
    action, bones = clip["action"], set(bones)
    for fc in list(_fcurves(action)):
        m = RE_PATH.match(fc.data_path)
        if m and m.group(1) in bones:
            if hasattr(action, "fcurves") and fc in list(action.fcurves):
                action.fcurves.remove(fc)
            else:
                _remove_layered(action, fc)
    clip["stripped"] = sorted(set(clip.get("stripped", [])) | bones)
    return clip


def _remove_layered(action, fc):
    for layer in action.layers:
        for strip_ in layer.strips:
            for bag in strip_.channelbags:
                if fc in list(bag.fcurves):
                    bag.fcurves.remove(fc)
                    return


# ---------------------------------------------------------------- checks

def _sample(arm, frame):
    bpy.context.scene.frame_set(frame)
    return [list(pb.location) + list(pb.rotation_quaternion) for pb in arm.pose.bones]


def check(spec, clip, report):
    action, arm = clip["action"], clip["armature"]
    add = lambda check_, ok, detail="": report.add(action.name, check_, ok, detail)
    frames = clip["end"] - clip["start"]
    row = doc_row(clip["name"])
    if row is None or row["min"] is None:
        add("length", False, "no length in docs/07 for %s" % clip["name"])
    else:
        want = "%d" % row["min"] if row["min"] == row["max"] else "%d to %d" % (row["min"], row["max"])
        add("length", row["min"] <= frames <= row["max"],
            "%d frames (%.2f s); 07 section %s: %s%s" % (frames, frames / float(common.FPS), row["section"].split(" ")[0],
                                                        "loop " if row["loop"] else "", want))
        add("loop flag", bool(clip.get("loop")) == row["loop"],
            "clip %s, 07 %s" % ("loops" if clip.get("loop") else "plays once", "loop" if row["loop"] else "once"))

    family = spec.get("rig")
    rig_bones = set(budgets.FAMILIES[family]["deform"]) | set(budgets.FAMILIES[family]["sockets"]) if family else set()
    bad_bone, bad_channel = set(), set()
    for fc in _fcurves(action):
        m = RE_PATH.match(fc.data_path)
        if not m:
            bad_channel.add(fc.data_path)
            continue
        if m.group(1) not in rig_bones:
            bad_bone.add(m.group(1))
        if m.group(2) == "scale":
            bad_channel.add(m.group(1) + ".scale")
    add("bone names", not bad_bone and not bad_channel,
        ("not in RIG_%s: %s. " % (family, ", ".join(sorted(bad_bone))) if bad_bone else "") +
        ("not allowed: %s" % ", ".join(sorted(bad_channel)) if bad_channel else
         "every curve drives a RIG_%s bone, position or rotation only" % family))

    arm.animation_data.action = action
    start, end = clip["start"], clip["end"]
    if not clip.get("root_motion"):
        root = arm.pose.bones.get("Root")
        worst = 0.0
        if root:
            for f in range(start, end + 1):
                bpy.context.scene.frame_set(f)
                turn = max(abs(a - b) for a, b in zip(root.rotation_quaternion, (1.0, 0.0, 0.0, 0.0)))
                worst = max(worst, root.location.length, turn)
        add("no root motion", worst < 1e-5, "Root moves at most %.6f over %d frames" % (worst, end - start))

    if clip.get("loop") and end - start >= 3:
        poses = [_sample(arm, f) for f in range(start, end + 1)]
        flat = [[v for bone in p for v in bone] for p in poses]
        pose_gap = max(abs(a - b) for a, b in zip(flat[0], flat[-1]))
        # A hitch at the seam is a kink: the second difference across it (frames end-1, 0, 1) is out
        # of line with every other one of the same channel. Allowed: 1.25 x that channel's largest.
        n, worst, where = len(flat) - 1, 0.0, ""
        for c in range(len(flat[0])):
            acc = [abs(flat[(i + 1) % n][c] - 2.0 * flat[i][c] + flat[(i - 1) % n][c]) for i in range(n)]
            excess = acc[0] - 1.25 * max(acc[1:]) - 1e-4
            if excess > worst:
                worst, where = excess, arm.pose.bones[c // 7].name
        add("loop seam", pose_gap < 1e-4 and worst <= 0.0,
            "first and last pose differ by %.6f; %s" % (pose_gap, ("kink at the seam on %s (%.5f over the clip's own curve)"
                                                                  % (where, worst)) if worst > 0.0 else "no kink at the seam"))
    bpy.context.scene.frame_set(start)


# ---------------------------------------------------------------- previews (06 15.5)

def _render_set(objs, view, frames, folder, prefix, head=None, on_frame=None):
    previewlib.show_only(objs)
    previewlib.show_helpers(False)
    at = lambda f: (bpy.context.scene.frame_set(f), on_frame and on_frame(f))
    pts = []
    for f in sorted(set(frames)):          # one still camera that frames every pose: motion shows against it,
        at(f)                              # and a stretch or a lunge cannot leave the cell
        pts += previewlib.world_points(objs)
    if head:                               # a close-up: only the front `head` share of the body (-Y forward)
        y0, y1 = min(p.y for p in pts), max(p.y for p in pts)
        pts = [p for p in pts if p.y <= y0 + head * (y1 - y0)]
    at(frames[0])
    previewlib.fit_camera(view, objs, margin=1.3, pts=pts)
    out = []
    for i, f in enumerate(frames):
        at(f)
        out.append(os.path.join(folder, "%s_%s%s_%03d.png" % (prefix, view, "_head" if head else "", i)))
        previewlib.render(out[-1])
    return out


def preview(spec, report, validation_ok):
    objs = spec["preview"]["main"]
    scene = bpy.context.scene
    saved = (scene.render.resolution_x, scene.render.resolution_y, scene.frame_current)
    scene.render.resolution_x = scene.render.resolution_y = PREVIEW_SIZE
    results = {}
    tmp = tempfile.mkdtemp(prefix="gulp_clips_")
    try:
        only = [n for n in os.environ.get(ONLY_ENV, "").split(",") if n]
        for clip in spec.get("actions", []):
            arm, name = clip["armature"], clip["name"]
            if only and name not in only:
                continue
            arm.data.pose_position = 'POSE'
            arm.animation_data.action = clip["action"]
            length = clip["end"] - clip["start"]
            keys = clip.get("keys") or [(clip["start"], "")]
            extra = STRIP_EXTRA.get(name, {})
            strip_size = extra.get("size", STRIP_SIZE)
            scene.render.resolution_x = scene.render.resolution_y = strip_size
            key_frames = [clip["start"] + k for k, _ in keys]
            props = spec.get("clip_props", {}).get(name)        # {"objects": [...], "at": hook(frame)}
            with_props = lambda v: (objs + props["objects"], props["at"]) if props and v in extra.get("props_views", ()) else (objs, None)
            rows = [{"view": v, "frames": _render_set(with_props(v)[0], v, key_frames, tmp, name + "_k", on_frame=with_props(v)[1])}
                    for v in extra.get("views", STRIP_VIEWS)]
            if extra.get("head"):
                rows.insert(1, {"view": "Head", "frames": _render_set(objs, "Side", key_frames, tmp, name + "_k", head=extra["head"])})
            scene.render.resolution_x = scene.render.resolution_y = PREVIEW_SIZE
            # 2 seconds at 30 fps: a loop repeats, an action plays and then holds its last frame
            seq = [clip["start"] + (i % length if clip.get("loop") else min(i, length)) for i in range(PREVIEW_SECONDS * common.FPS)]
            unique = sorted(set(seq))
            clip_objs, hook = with_props(CLIP_VIEW)
            rendered = dict(zip(unique, _render_set(clip_objs, CLIP_VIEW, unique, tmp, name + "_c", on_frame=hook)))
            rows_ok = [r for r in report.rows if r["subject"] == name]
            base = os.path.join(common.review_dir(name), common.today())
            job = {"name": name, "strip": base + "_strip.png", "gif": base + "_clip.gif", "size": PREVIEW_SIZE, "strip_size": strip_size,
                   "square": extra.get("square"),
                   "labels": ["f%d %s" % (k, lab) for k, lab in keys], "rows": rows,
                   "clip_frames": [rendered[f] for f in seq], "fps": common.FPS,
                   "footer": ["%s  %d frames%s  %s  RIG_%s" % (name, length, " loop" if clip.get("loop") else "",
                                                            common.today(), spec.get("rig")),
                              "checks: " + ", ".join("%s %s" % (r["check"], "ok" if r["ok"] else "FAIL") for r in rows_ok),
                              "validation %s  commit %s" % ("passed" if validation_ok else "FAILED", common.git_commit())]}
            job_path = os.path.join(tmp, name + ".json")
            with open(job_path, "w") as f:
                json.dump(job, f)
            python = shutil.which("python3") or "/usr/bin/python3"
            done = subprocess.run([python, os.path.join(common.LIB_DIR, "clipsheet.py"), job_path], capture_output=True, text=True)
            if done.returncode != 0:
                raise RuntimeError("clipsheet.py failed (needs Pillow in the system python3):\n" + done.stderr[-600:])
            print("[clips] %s strip %s" % (name, job["strip"]))
            print("[clips] %s clip  %s" % (name, job["gif"]))
            results[name] = {"strip": job["strip"], "clip": job["gif"]}
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
        scene.render.resolution_x, scene.render.resolution_y = saved[0], saved[1]
        scene.frame_set(saved[2])
    return results


# ---------------------------------------------------------------- Roblox animation files (step clips-rbxm)

LUAU_DIR = os.path.join(common.LIB_DIR, "..", "luau")


def dump_json(clip):
    """The clip as data (port of the Sprint 0 spike's fish_anim_json.py): per bone its parent,
    deform flag and armature-space rest matrix; per frame its local transform (matrix_basis,
    location and quaternion w, x, y, z) and its armature-space head."""
    import mathutils
    arm, action = clip["armature"], clip["action"]
    arm.data.pose_position = 'POSE'
    arm.animation_data.action = action
    bones = {b.name: {"parent": b.parent.name if b.parent else None, "deform": b.use_deform,
                      "rest": [list(r) for r in b.matrix_local], "frames": []} for b in arm.data.bones}
    for f in range(clip["start"], clip["end"] + 1):
        bpy.context.scene.frame_set(f)
        for pb in arm.pose.bones:
            mb = pb.matrix_basis
            q = mb.to_quaternion()
            bones[pb.name]["frames"].append({"loc": list(mb.to_translation()), "q": [q.w, q.x, q.y, q.z],
                                             "head": list(mathutils.Vector(pb.head))})
    bpy.context.scene.frame_set(clip["start"])
    return {"clip": clip["name"], "fps": common.FPS, "start": clip["start"], "end": clip["end"],
            "loop": bool(clip.get("loop")), "rig": arm.name, "bones": bones}


def _lune():
    for path in (shutil.which("lune"), os.path.expanduser("~/.rokit/bin/lune")):
        if path and os.path.exists(path):
            return path
    raise RuntimeError("lune not found (export PATH=\"$HOME/.rokit/bin:$PATH\")")


def to_rbxm(spec, report, validation_ok):
    """Writes assets/export/animations/<A_name>.rbxm for every clip and checks it read back: one
    KeyframeSequence, a keyframe per frame over the clip's length, the 07 loop flag, and pose names
    exactly the deform bones of the rig, of the family (budgets.FAMILIES) and of the exported FBX."""
    import animrbx
    import export
    results = {}
    if not validation_ok:
        print("[clips-rbxm] validation failed: no animation files written")
        return results
    if spec.get("clip_files") is False:
        print("[clips-rbxm] %s writes no clip files (spec clip_files False)" % spec["name"])
        return results
    family = set(budgets.FAMILIES[spec["rig"]]["deform"])
    fbx_bones = None
    mesh_fbx = next((e["file"] for e in spec.get("exports", []) if not e.get("clip") and
                     any(o.type == 'ARMATURE' for o in e["objects"])), None)
    if mesh_fbx and os.path.exists(os.path.join(common.EXPORT_DIR, mesh_fbx)):
        fbx_bones = {b for b in export.inspect_fbx(os.path.join(common.EXPORT_DIR, mesh_fbx))["bones"] if not b.startswith("Sock_")}
    tmp = tempfile.mkdtemp(prefix="gulp_rbxm_")
    try:
        for clip in spec.get("actions", []):
            name = clip["name"]
            add = lambda check_, ok, detail="": report.add(name + ".rbxm", check_, ok, detail)
            data = dump_json(clip)
            xml, posed, prio = animrbx.kfs_xml(data)
            src = os.path.join(tmp, name + ".rbxmx")
            with open(src, "w", encoding="utf-8") as f:
                f.write(xml)
            out = os.path.join(common.EXPORT_DIR, "animations", name + ".rbxm")
            os.makedirs(os.path.dirname(out), exist_ok=True)
            summary_path = os.path.join(tmp, name + ".json")
            done = subprocess.run([_lune(), "run", os.path.join(LUAU_DIR, "xml2rbxm.luau"), src, out, summary_path],
                                  capture_output=True, text=True)
            if done.returncode != 0 or not os.path.exists(summary_path):
                add("rbxm written", False, (done.stderr or done.stdout)[-400:])
                continue
            got = json.load(open(summary_path))
            frames = clip["end"] - clip["start"]
            rig_deform = {b.name for b in clip["armature"].data.bones if b.use_deform}
            bones = set(got["bones"])
            add("rbxm written", got["class"] == "KeyframeSequence" and got["name"] == name,
                "%s, %d bytes, priority %s" % (os.path.relpath(out, common.REPO_DIR), got["bytes"], got["priority"]))
            add("rbxm keyframes", got["keyframes"] == frames + 1 and abs(got["length"] - frames / float(common.FPS)) < 1e-4
                and set(got["posesPerKeyframe"]) == {len(posed) + 1},
                "%d keyframes over %.3f s, %d poses each" % (got["keyframes"], got["length"], max(got["posesPerKeyframe"] or [0])))
            add("rbxm loop", bool(got["loop"]) == bool(clip.get("loop")), "Loop %s" % got["loop"])
            want = [("rig", rig_deform), ("RIG_%s family" % spec["rig"], family)] + ([("FBX", fbx_bones)] if fbx_bones else [])
            bad = ["%s: missing %s, extra %s" % (label, sorted(ref - bones), sorted(bones - ref)) for label, ref in want if ref != bones]
            add("rbxm bone names", not bad and got["rootPoses"] == ["RootPart"],
                "; ".join(bad) or "%d poses under RootPart match the deform bones of the rig, the family%s"
                % (len(bones), " and the exported FBX" if fbx_bones else ""))
            print("[clips-rbxm] %s" % done.stdout.strip())
            results[name] = os.path.relpath(out, common.REPO_DIR)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return results
