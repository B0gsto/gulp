"""The `preview` step (docs/06-art-bible.md section 15.5): renders the views of one asset
with EEVEE and hands them to sheet.py, which lays out the 1536 x 1536 contact sheet.

Blender's Python has no Pillow, so the layout runs in the system python3.
"""
import json
import os
import shutil
import subprocess
import tempfile

import bpy
from mathutils import Matrix, Vector

import common
import meshgen
import template

BLOCK_RULES = {  # 06 section 4.1: share of surface, lightness
    "mid": ((55, 65), (45, 80)),
    "light": ((20, 30), (85, 100)),
    "dark": ((10, 15), (0, 35)),
    "accent": ((0, 5), (0, 100)),
}


def world_points(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for obj in objs:
        if obj.type != 'MESH':
            continue
        eo = obj.evaluated_get(dg)
        mesh = eo.to_mesh()
        mw = eo.matrix_world.copy()
        pts.extend(mw @ v.co for v in mesh.vertices)
        eo.to_mesh_clear()
    return pts


def extent(pts):
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def fit_camera(view, objs, margin=1.2):
    scene = bpy.context.scene
    look, up = template.VIEWS[view]
    cam = bpy.data.objects.get("CAM_" + view)
    if cam is None:
        data = bpy.data.cameras.new("CAM_" + view)
        data.type, data.clip_start, data.clip_end = 'ORTHO', 0.1, 400.0
        cam = template.link(bpy.data.objects.new("CAM_" + view, data), "PREVIEW")
    pts = world_points(objs)
    lo, hi = extent(pts)
    centre = (lo + hi) / 2.0
    m = template.look_matrix(look, up)
    right, upv = m.col[0].xyz, m.col[1].xyz
    half = max(max(abs((p - centre).dot(right)) for p in pts), max(abs((p - centre).dot(upv)) for p in pts))
    cam.data.ortho_scale = 2.0 * half * margin
    cam.matrix_world = template.look_matrix(look, up, centre - Vector(look).normalized() * 100.0)
    scene.camera = cam


def show_only(objs):
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH':
            obj.hide_render = obj not in objs


def render(path):
    scene = bpy.context.scene
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return os.path.basename(path)


def shot(view, objs, path, frame=None):
    show_only(objs)
    bpy.context.view_layer.update()
    fit_camera(view, frame or objs)
    return render(path)


def stack(groups, gap):
    """Moves each group of objects into a column, first group on top. Returns what to restore."""
    bpy.context.view_layer.update()
    saved, cursor = {}, 0.0
    for objs in groups:
        lo, hi = extent(world_points(objs))
        shift = Matrix.Translation((-(lo.x + hi.x) / 2.0, -(lo.y + hi.y) / 2.0, cursor - hi.z))
        for obj in objs:
            saved[obj] = (obj.matrix_basis.copy(), obj.location.copy())
            obj.matrix_world = shift @ obj.matrix_world
        cursor -= (hi.z - lo.z) + gap
        bpy.context.view_layer.update()
    return saved


def value_blocks(obj, declared):
    """Share of surface and L* of each declared colour block, from the vertex colours."""
    mesh = obj.data
    mesh.calc_loop_triangles()
    col = mesh.color_attributes[common.COLOR_ATTR]
    targets = {name: common.hex_to_srgb(h) for name, h in declared.items()}
    area = {name: 0.0 for name in targets}
    light = {name: 0.0 for name in targets}
    for tri in mesh.loop_triangles:
        for li in tri.loops:
            rgb = tuple(col.data[li].color_srgb[:3])
            name = min(targets, key=lambda n: sum((a - b) ** 2 for a, b in zip(rgb, targets[n])))
            area[name] += tri.area / 3.0
            light[name] += common.lstar_from_srgb(rgb) * tri.area / 3.0
    total = sum(area.values()) or 1.0
    out = []
    for name in ("mid", "light", "dark", "accent"):
        if name not in targets or area[name] <= 0.0:
            continue
        share, lstar = 100.0 * area[name] / total, light[name] / area[name]
        (s0, s1), (l0, l1) = BLOCK_RULES[name]
        out.append({"block": name, "share": round(share, 1), "lstar": round(lstar, 1),
                    "share_ok": s0 <= share <= s1, "lstar_ok": l0 <= lstar <= l1,
                    "rule": "%d-%d%%, L* %d-%d" % (s0, s1, l0, l1)})
    return out


def run(spec, report, validation_ok):
    scene = bpy.context.scene
    pv = spec["preview"]
    name = spec["name"]
    main = pv["main"]
    arm = spec.get("armature")
    tmp = tempfile.mkdtemp(prefix="gulp_preview_")
    ad = arm.animation_data if arm else None
    saved_action = ad.action if ad else None
    saved_slot = getattr(ad, "action_slot", None) if ad else None
    if ad:
        ad.action = None
    if arm:
        meshgen.apply_pose(arm, None)
    cells = []
    try:
        for title, view in (("Side", "Side"), ("Three-quarter", "ThreeQuarter"), ("Game camera", "Game"), ("Top", "Top")):
            cells.append({"title": title, "kind": "view", "image": shot(view, main, os.path.join(tmp, view + ".png"))})
        cells.append({"title": "Silhouettes: side, game camera", "kind": "silhouette", "images": ["Side.png", "Game.png"]})
        cells.append({"title": "Phone sizes", "kind": "phone", "image": "Side.png",
                      "caption": ["96, 48, 20 and 8 pixels long", "top: Sunlit Reef fog, bottom: deep Drop-off fog"]})
        cells.append({"title": "Six fog colours, lime and red outline", "kind": "fogs", "image": "Side.png",
                      "caption": [", ".join(template.BACKDROP_ZONES), "outline drawn by the sheet tool, not the shell mesh"]})

        blocks = value_blocks(main[0], pv["blocks"]) if pv.get("blocks") else []
        caption = ["%s %.0f%% L* %.0f%s" % (b["block"], b["share"], b["lstar"],
                                            "" if b["share_ok"] and b["lstar_ok"] else "  (rule: %s)" % b["rule"]) for b in blocks]
        cells.append({"title": "Value check", "kind": "value", "image": "Side.png",
                      "caption": caption or ["no value blocks declared"]})

        groups = pv["lineup"]
        saved = stack([g["objects"] for g in groups], pv.get("lineup_gap", 0.5))
        everything = [o for g in groups for o in g["objects"]]
        image = shot("Side", everything, os.path.join(tmp, "Lineup.png"))
        for obj, (basis, _) in saved.items():
            obj.matrix_basis = basis
        bpy.context.view_layer.update()
        cells.append({"title": "Line-up", "kind": "view", "image": image,
                      "caption": ["top to bottom: " + "; ".join(g["label"] for g in groups)] + pv.get("lineup_caption", [])})

        for i, extra in enumerate(pv["extras"]):
            if "legend" in extra:
                cells.append({"title": extra["title"], "kind": "legend", "legend": extra["legend"], "caption": extra.get("caption", [])})
                continue
            if arm:
                meshgen.apply_pose(arm, extra.get("pose"))
            image = shot(extra.get("view", "ThreeQuarter"), extra.get("objects", main), os.path.join(tmp, "Extra%d.png" % i))
            if arm:
                meshgen.apply_pose(arm, None)
            cells.append({"title": extra["title"], "kind": "view", "image": image, "caption": extra.get("caption", [])})
    finally:
        if arm:
            meshgen.apply_pose(arm, None)
        if ad and saved_action:
            ad.action = saved_action
            try:
                if saved_slot is not None:
                    ad.action_slot = saved_slot
            except Exception:
                pass
        show_only(main)

    tris = "; ".join("%s %d of %s" % (e["object"].name.replace(name, "") or "body", e.get("tris", 0), e.get("tri_budget"))
                     for e in spec["meshes"])
    counts = spec.get("bone_counts")
    bones = ("%d deform + %d sockets = %d of 32" % (counts["deform"], counts["sockets"], counts["total"])) if counts else "none"
    failures = report.failures()
    out = os.path.join(common.review_dir(name), "%s_sheet.png" % common.today())
    job = {
        "asset": name, "out": out, "dir": tmp, "cells": cells, "blocks": blocks,
        "footer": [
            "%s    %s    script commit %s    Blender %s" % (name, common.today(), common.git_commit(), bpy.app.version_string),
            "Triangles: " + tris,
            "Bones: %s    Texture: %s" % (bones, pv.get("texture", "none (vertex colour)")),
            "Validation: %s (%d checks%s)" % ("PASS" if validation_ok and not failures else "FAIL", len(report.rows),
                                               "" if not failures else ", failed: " + ", ".join(sorted({r["check"] for r in failures}))),
        ],
    }
    job_path = os.path.join(tmp, "sheet.json")
    with open(job_path, "w", encoding="utf-8") as f:
        json.dump(job, f, indent=1)
    python = shutil.which("python3") or "/usr/bin/python3"
    done = subprocess.run([python, os.path.join(common.LIB_DIR, "sheet.py"), job_path], capture_output=True, text=True)
    if done.returncode != 0:
        raise RuntimeError("sheet.py failed (needs Pillow in the system python3):\n" + done.stdout + done.stderr)
    shutil.rmtree(tmp, ignore_errors=True)
    print("[preview] contact sheet", out)
    return {"sheet": out, "blocks": blocks}
