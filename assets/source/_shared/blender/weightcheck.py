"""Skin-weight check for a Fish-family body (task S1-A3; docs/06-art-bible.md sections 6.5, 7.1 and
7.5): measures the skin at the poses where weights show their faults, the dash squash (85%, with
the C-bend) and stretch (125%) and the bite (jaw wide, the snap with the 12% lunge, the 115%
stretch), and (S4-A3) the extremes of the gulp, hit, stunned, tier-up and gulped clips, and renders them with the weights as colour and the edge loops as wire.

A build turns it on with spec["weight_check"] = {"body": <skinned body object>, "rings": n,
"segs": n} (the body is the first part of the mesh, lofted by fishbody.FishBody.part). Then:
  validate step   rows "weights: smooth falloff" and "deform: <pose>" (validate.run)
  preview step    <date>_weights.png in the asset's review folder (run.py)

What is measured, on the body's grid of rings and segments, outside the mouth (any vertex with
jaw weight: the lip is meant to split):
  falloff  the steepest change of any bone's weight along the body, per stud (at rest)
  bend     the most that the angle between two neighbouring edges along a segment line changes
           from rest to the pose, in degrees: a crease ring shows as a sharp local bend
  jump     the largest ratio between the stretch of two neighbouring edges along a segment
           line: a crease ring shows as stretch piled into one band
  ring     the same bend measure around each ring (girth pulling the section out of shape)
"""
import json
import math
import os
import shutil
import subprocess
import tempfile

import bpy
import numpy as np

import common
import meshgen
import preview
import rigs
import template

# Limits (tune). The old Minnow weights (S2-A3) creased at the dash squash with abrupt 0.24-stud
# hand-overs: a falloff of 6.3 per stud. Smooth means no band takes more than its share.
LIMITS = {"falloff": 4.5, "bend": 12.0, "jump": 1.3, "ring": 15.0}

COLOURS = {"Spine1": "#E8505B", "Spine2": "#F2A33A", "Spine3": "#5BC06A", "Spine4": "#3A9BDC",
           "TailFin": "#8A5CD8", "Jaw": "#E84DB8", "Girth_Top": "#FFFFFF", "Girth_Bot": "#FFFFFF",
           "Girth_L": "#FFFFFF", "Girth_R": "#FFFFFF", "Dorsal": "#F5E04A", "Pec_L": "#4AD9D9",
           "Pec_R": "#4AD9D9", "Eye_L": "#2A2A2A", "Eye_R": "#2A2A2A", "Lid_L": "#6B6B6B", "Lid_R": "#6B6B6B"}
LEGEND = ("Spine1 red, Spine2 orange, Spine3 green, Spine4 blue, TailFin violet, Jaw magenta, "
          "Girth mixes toward white; fins: Dorsal yellow, Pec cyan")


def poses(k=1.0):
    return [
        ("Rest", None),
        ("Dash f2: squash 85%, C-bend", rigs.fish_dash_pose(2, k)),
        ("Dash f4: stretch 125%", rigs.fish_dash_pose(4, k)),
        ("Bite f1: jaw wide", rigs.fish_bite_pose(1, k)),
        ("Bite f2: snap, 12% lunge", rigs.fish_bite_pose(2, k)),
        ("Bite f4: stretch 115%", rigs.fish_bite_pose(4, k)),
        ("Gulp f1: full gape", rigs.fish_gulp_pose(1, k)),
        ("Gulp f2: gape held, squash", rigs.fish_gulp_pose(2, k)),
        ("Gulp f4: head 110%", rigs.fish_gulp_pose(4, k)),
        ("Gulp f7: swallow bulge", rigs.fish_gulp_pose(7, k)),
        ("Gulp f9: bulge back", rigs.fish_gulp_pose(9, k)),
        ("Gulp f11: bulge at the tail", rigs.fish_gulp_pose(11, k)),
        ("Hit f1: knock", rigs.fish_hit_pose(1, k)),
        ("Hit f2: squash 80%", rigs.fish_hit_pose(2, k)),
        ("Hit f3: shudder", rigs.fish_hit_pose(3, k)),
        ("Stunned f5: roll, sway", rigs.fish_stunned_pose(0.25, k)),
        ("Stunned f15: roll, sway", rigs.fish_stunned_pose(0.75, k)),
        ("Stunned f10: bob, see-saw", rigs.fish_stunned_pose(0.5, k)),
        ("TierUp f2: into the squash", rigs.fish_tierup_pose(2, k)),
        ("TierUp f3: squash 75%, crouch", rigs.fish_tierup_pose(3, k)),
        ("TierUp f5: pop", rigs.fish_tierup_pose(5, k)),
        ("TierUp f6: pop 130%, arch", rigs.fish_tierup_pose(6, k)),
        ("TierUp f12: wag", rigs.fish_tierup_pose(12, k)),
        ("Gulped f4: stretch 140%", rigs.fish_gulped_pose(4, k)),
        ("Gulped f6: shrinking", rigs.fish_gulped_pose(6, k)),
        ("Gulped f8: drawn in", rigs.fish_gulped_pose(8, k)),
        ("Hatch f0: curled 86%", rigs.fish_hatch_pose(0, k)),       # S6-A2
        ("Hatch f15: squeeze 82%", rigs.fish_hatch_pose(15, k)),
        ("Hatch f18: pop 130%", rigs.fish_hatch_pose(18, k)),
        ("Hatch f25: glance, blink", rigs.fish_hatch_pose(25, k)),
        ("Hatch f30: tail kick", rigs.fish_hatch_pose(30, k)),
    ]


def _weights(obj):
    names = {g.index: g.name for g in obj.vertex_groups}
    return [{names[g.group]: g.weight for g in v.groups if g.weight > 1e-6} for v in obj.data.vertices]


def _grid(obj, rings, segs):
    dg = bpy.context.evaluated_depsgraph_get()
    eo = obj.evaluated_get(dg)
    mesh = eo.to_mesh()
    co = np.array([v.co[:] for v in mesh.vertices[1:1 + rings * segs]])
    eo.to_mesh_clear()
    return co.reshape(rings, segs, 3)


def _angles(a, b):
    na, nb = np.linalg.norm(a, axis=-1), np.linalg.norm(b, axis=-1)
    c = np.sum(a * b, axis=-1) / np.maximum(na * nb, 1e-12)
    return np.degrees(np.arccos(np.clip(c, -1.0, 1.0)))


def measure(spec):
    """{"falloff": (value, where), "poses": [(title, {"bend", "jump", "ring"})]}"""
    wc = spec["weight_check"]
    obj, rings, segs = wc["body"], wc["rings"], wc["segs"]
    arm = spec["armature"]
    ws = _weights(obj)[1:1 + rings * segs]
    free = np.array([w.get("Jaw", 0.0) < 0.01 for w in ws]).reshape(rings, segs)
    ad = arm.animation_data
    saved = ad.action if ad else None
    saved_position = arm.data.pose_position
    arm.data.pose_position = 'POSE'      # an earlier step may leave the rig at rest
    if ad:
        ad.action = None
    try:
        meshgen.apply_pose(arm, None)
        bpy.context.view_layer.update()
        rest = _grid(obj, rings, segs)
        bones = sorted({n for w in ws for n in w} - {"Jaw"})
        W = np.array([[w.get(b, 0.0) for b in bones] for w in ws]).reshape(rings, segs, len(bones))
        step = np.linalg.norm(rest[1:] - rest[:-1], axis=-1)
        grad = np.abs(W[1:] - W[:-1]).max(axis=-1) / np.maximum(step, 1e-6)
        grad[~(free[1:] & free[:-1])] = 0.0
        i, j = np.unravel_index(np.argmax(grad), grad.shape)
        falloff = (float(grad[i, j]), "y %.2f" % rest[i, j, 1])
        e0 = rest[1:] - rest[:-1]
        c0 = np.roll(rest, -1, axis=1) - rest
        out = []
        for title, pose in poses(spec.get("rig_k", 1.0)):
            if pose is None:
                continue
            meshgen.apply_pose(arm, pose)
            bpy.context.view_layer.update()
            p = _grid(obj, rings, segs)
            e = p[1:] - p[:-1]
            ok3 = free[2:] & free[1:-1] & free[:-2]
            bend = np.abs(_angles(e[1:], e[:-1]) - _angles(e0[1:], e0[:-1]))
            bend[~ok3] = 0.0
            r = np.linalg.norm(e, axis=-1) / np.maximum(np.linalg.norm(e0, axis=-1), 1e-9)
            jump = np.maximum(r[1:] / r[:-1], r[:-1] / r[1:])
            jump[~ok3] = 1.0
            c = np.roll(p, -1, axis=1) - p
            ring = np.abs(_angles(c, np.roll(c, 1, axis=1)) - _angles(c0, np.roll(c0, 1, axis=1)))
            okr = free & np.roll(free, 1, axis=1) & np.roll(free, -1, axis=1)
            ring[~okr] = 0.0
            ring[[0, -1]] = 0.0          # the rings on the pole fans
            where = {}
            for key, arr, off in (("bend", bend, 1), ("jump", jump, 1), ("ring", ring, 0)):
                i, j = np.unravel_index(np.argmax(arr), arr.shape)
                where[key] = "y %.2f seg %d" % (rest[i + off, j, 1], j)
            out.append((title, {"bend": float(bend.max()), "jump": float(jump.max()), "ring": float(ring.max()), "where": where}))
    finally:
        meshgen.apply_pose(arm, None)
        arm.data.pose_position = saved_position
        if ad and saved:
            ad.action = saved
        bpy.context.view_layer.update()
    return {"falloff": falloff, "poses": out}


def check(spec, report):
    m = measure(spec)
    spec["weight_check"]["measured"] = m
    name = spec["weight_check"]["body"].name
    value, where = m["falloff"]
    report.add(name, "weights: smooth falloff", value <= LIMITS["falloff"],
               "steepest %.2f per stud at %s (limit %.1f; the lip split is left out)" % (value, where, LIMITS["falloff"]))
    waivers = spec["weight_check"].get("waivers", {})
    for title, v in m["poses"]:
        ok = v["bend"] <= LIMITS["bend"] and v["jump"] <= LIMITS["jump"] and v["ring"] <= LIMITS["ring"]
        report.add(name, "deform: " + title.split(":")[0], ok, waiver=waivers.get(title.split(":")[0]), detail=(
                   "%s: bend %.1f deg (%s), stretch jump %.2f (%s), ring bend %.1f deg (%s); limits %.0f, %.2f, %.0f"
                   % (title, v["bend"], v["where"]["bend"], v["jump"], v["where"]["jump"], v["ring"], v["where"]["ring"],
                      LIMITS["bend"], LIMITS["jump"], LIMITS["ring"])))


def _viz_objects(spec):
    """A weight-coloured copy of the body and a wire copy of its edge loops, both skinned."""
    src, arm = spec["weight_check"]["body"], spec["armature"]
    ws = _weights(src)
    mesh = src.data.copy()
    mesh.materials.clear()
    mesh.materials.append(template.vertex_colour_material("WCHK_Weights"))
    col = mesh.color_attributes.get(common.COLOR_ATTR) or mesh.color_attributes.new(common.COLOR_ATTR, 'BYTE_COLOR', 'CORNER')
    rgb = {}
    for i, w in enumerate(ws):
        c = np.zeros(3)
        for n, v in w.items():
            c += v * np.array(common.hex_to_srgb(COLOURS.get(n, "#999999")))
        rgb[i] = c
    for li, loop in enumerate(mesh.loops):
        col.data[li].color_srgb = (*rgb[loop.vertex_index], 1.0)
    viz = bpy.data.objects.new("WCHK_Body", mesh)
    template.link(viz, "PREVIEW")
    for g in src.vertex_groups:
        viz.vertex_groups.new(name=g.name)
    for v in src.data.vertices:
        for g in v.groups:
            viz.vertex_groups[src.vertex_groups[g.group].name].add([v.index], g.weight, 'REPLACE')
    meshgen.skin(viz, arm)
    viz.matrix_world = src.matrix_world.copy()
    wire = bpy.data.objects.new("WCHK_Wire", mesh.copy())
    template.link(wire, "PREVIEW")
    for g in viz.vertex_groups:
        wire.vertex_groups.new(name=g.name)
    for v in viz.data.vertices:
        for g in v.groups:
            wire.vertex_groups[viz.vertex_groups[g.group].name].add([v.index], g.weight, 'REPLACE')
    meshgen.skin(wire, arm)
    wire.matrix_world = src.matrix_world.copy()
    mod = wire.modifiers.new("Wire", 'WIREFRAME')
    mod.thickness, mod.offset, mod.use_replace = 0.007, 1.0, True
    wire.data.materials.clear()
    wire.data.materials.append(template.flat_material("WCHK_Wire", common.colour("ui.ink")))
    return viz, wire


def sheet(spec, report, validation_ok):
    """Renders every pose from the side and the top on one sheet: <date>_weights.png."""
    if "measured" not in spec["weight_check"]:
        spec["weight_check"]["measured"] = measure(spec)
    m = spec["weight_check"]["measured"]
    metrics = dict(m["poses"])
    arm, name = spec["armature"], spec["name"]
    scene = bpy.context.scene
    ad = arm.animation_data
    saved = ad.action if ad else None
    if ad:
        ad.action = None
    saved_position = arm.data.pose_position
    arm.data.pose_position = 'POSE'
    tmp = tempfile.mkdtemp(prefix="gulp_weights_")
    viz, wire = _viz_objects(spec)
    objs = [viz, wire]
    cells = []
    try:
        cams = {}
        meshgen.apply_pose(arm, None)
        for view in ("Side", "Top"):
            preview.fit_camera(view, [viz], margin=1.4)
            cams[view] = (scene.camera, scene.camera.matrix_world.copy(), scene.camera.data.ortho_scale)
        for title, pose in poses(spec.get("rig_k", 1.0)):
            meshgen.apply_pose(arm, pose)
            bpy.context.view_layer.update()
            v = metrics.get(title)
            caption = (["bend %.1f deg, jump %.2f, ring %.1f deg" % (v["bend"], v["jump"], v["ring"])] if v
                       else ["falloff %.2f per stud, steepest at %s" % m["falloff"]])
            for view in ("Side", "Top"):
                preview.show_only(objs)
                preview.show_helpers(False)
                cam, mw, scale = cams[view]
                cam.matrix_world, cam.data.ortho_scale = mw, scale
                scene.camera = cam
                path = os.path.join(tmp, "%d_%s.png" % (len(cells), view))
                preview.render(path)
                cells.append({"title": "%s (%s)" % (title, view.lower()), "image": path, "caption": caption})
    finally:
        meshgen.apply_pose(arm, None)
        arm.data.pose_position = saved_position
        if ad and saved:
            ad.action = saved
        for o in objs:
            bpy.data.objects.remove(o, do_unlink=True)
    rows = [r for r in report.rows if r["check"].startswith(("deform:", "weights: smooth"))]
    verdict = "PASS" if rows and all(r["ok"] for r in rows) else "FAIL" if rows else "not validated"
    out = os.path.join(common.review_dir(name), "%s_weights.png" % common.today())
    job = {"grid": True, "out": out, "cols": 4, "cells": cells, "footer": [
        "%s  RIG_Fish weight check  %s  commit %s  weights and deform checks: %s" % (name, common.today(), common.git_commit(), verdict),
        LEGEND,
        "limits: falloff %.1f/stud, bend %.0f deg, stretch jump %.2f, ring bend %.0f deg; mouth (jaw-weighted) left out"
        % (LIMITS["falloff"], LIMITS["bend"], LIMITS["jump"], LIMITS["ring"])]}
    job_path = os.path.join(tmp, "weights.json")
    with open(job_path, "w", encoding="utf-8") as f:
        json.dump(job, f)
    python = shutil.which("python3") or "/usr/bin/python3"
    done = subprocess.run([python, os.path.join(common.LIB_DIR, "sheet.py"), job_path], capture_output=True, text=True)
    shutil.rmtree(tmp, ignore_errors=True)
    if done.returncode != 0:
        raise RuntimeError("sheet.py failed:\n" + done.stdout + done.stderr)
    print("[weights] sheet", out)
    return out
