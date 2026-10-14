"""M_Env_Nursery_Rim_01 and _02: task S6-A3 (docs/13-sprint-plan.md Sprint 6; docs/07-asset-list.md 6.2 row
M_Env_Nursery_Rim_01-02, 1,000 tris each; docs/03-content-catalog.md 6.1 and 6.2; docs/06-art-bible.md 6.3, 9.1,
9.2).

    Blender --background --python assets/source/env/nursery/rim/build.py

Low rounded rim pieces that enclose the pool (nurseryart, independent review loop 3): a closed slab whose top is a
structured grid over the arc's plan, one cross-section for both pieces, a broad convex dome from a toe buried in
the sand 32 studs into the pool up to a crest 4 to 12 above the surface and down the outer face to a flat base at
depth 86, with no flat top and no wall (under 65 degrees above the floors). The grid's rows run along the bank's
level lines, so the three value blocks of the rim cell of T_EnvNursery_Alb (a soft violet toe band, a mid body with
one broad gradient, a pale peach cap) end on edge loops. Each is an arc concave toward the pool, its front (-Y);
radius and span are measured at the waterline:

  _01  long low swell: radius 172, 64 studs (crest 4.9 to 8.6)
  _02  fuller hump, leaning: radius 96, 50 studs (crest 4.9 to 11.2)

At every joint the crest is 6 above the surface, falling 0.12 a stud toward +s, and within 5 studs of it both
neighbours are exactly that profile; each piece runs 30 studs past its joints under its neighbour (the joint profile
sunk by 6 x^2 over the first 9, then a dive to the base), so a ring is one rolling bank and a lone piece ends in
rounded noses. Copies chain end to end at scale 1, tangent to tangent at the waterline (nurseryart.next_pose), one
tint for all (a scaled copy or a tint per copy would break the joint). Origin: the centre of the flat base (06 6.1);
the arc frame (centre, radius, surface and sand level relative to the origin) goes to
assets/export/meshes/M_Env_Nursery_Rim.kit.json.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

import nurseryart as na  # noqa: E402

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402

PRIMARY = "M_Env_Nursery_Rim_01"


def copy_at(ob, matrix, tag):
    c = ob.copy()
    c.name = "PV_%s_%s" % (ob.name.replace("M_Env_Nursery_", ""), tag)
    bpy.data.collections["PREVIEW"].objects.link(c)
    c.matrix_world = matrix
    c.hide_render = True
    return c


def ground(tag, centre, r0, r1, z, colour):
    """Preview-only context (06 15.5 kit sheets show pieces in place): a flat ring of floor from radius r0 to r1 round
    the arc centre at height z, matte, so the context shots show the bank as a player sees it, with its buried bulk
    hidden. Never exported."""
    import bmesh
    me = bpy.data.meshes.new("PV_" + tag)
    bm = bmesh.new()
    n = 160
    ring = [[bm.verts.new((centre[0] + r * math.sin(2 * math.pi * k / n), centre[1] + r * math.cos(2 * math.pi * k / n), z))
             for k in range(n)] for r in ((r0, r1) if r0 > 0 else (r1,))]
    if len(ring) == 1:
        bm.faces.new(ring[0])
    else:
        for k in range(n):
            bm.faces.new((ring[0][k], ring[0][(k + 1) % n], ring[1][(k + 1) % n], ring[1][k]))
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("PV_" + tag, me)
    bpy.data.collections["PREVIEW"].objects.link(ob)
    mat = bpy.data.materials.new("MAT_PV_" + tag)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = common.hex_to_linear(colour) + (1.0,)
    bsdf.inputs["Roughness"].default_value = 1.0
    me.materials.append(mat)
    ob.hide_render = True
    return ob


def build():
    import rimart as ra
    mat = na.rim_material()
    atlas = na.paint_atlas()                    # the same pixels as assets/export/textures/T_EnvNursery_Alb.png
    objs, offs = {}, {}
    for name in na.RIM_NAMES:
        ob = na.build_rim(name)
        ob.data.materials.append(mat)
        objs[name] = ob
    frames = {}
    for name, ob in objs.items():
        lo, hi = ra.bounds(ob)
        offs[name] = ra.fit_base(ob)
        Rf = na.RIMS[name]["radius"]
        o = offs[name]
        frames[name] = {
            "arc_centre_from_origin": [round(-o.x, 3), round(-Rf - o.y, 3), round(-o.z, 3)],
            "arc_radius": Rf, "pool_face_span": na.RIMS[name]["span"],
            "pool_face_at_s0_from_origin": [round(-o.x, 3), round(-o.y, 3)],
            "surface_z_from_origin": round(-o.z, 3), "sand_z_from_origin": round(-na.SAND_DEPTH - o.z, 3),
            "box_size": [round(hi[i] - lo[i], 3) for i in range(3)],
            "tris": ra.tri_count(ob),
            "value_shares_dark_mid_light": list(ob.get("rim_value_shares", [])),
        }
        print("[nursery] %s: %d tris, origin at piece-frame %s" % (name, ra.tri_count(ob), tuple(round(c, 2) for c in o)))

    def write_frames(spec, report):
        if not report.ok:
            report.add(PRIMARY, "kit frame table", True, "not written: validation failed")
            return
        path = os.path.join(common.EXPORT_DIR, "meshes", "M_Env_Nursery_Rim.kit.json")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            json.dump({"note": "Blender frame (Z up, -Y the pool side). Every value is relative to the piece's origin (the centre of its flat "
                               "base). Chain copies end to end at scale 1 and one tint: each piece's +s joint (the pool face's waterline at "
                               "s = +span/2) on the next piece's -s joint, tangents matched (nurseryart.next_pose and ring_poses); each runs "
                               "%.0f studs past its joints under its neighbour. Assembly is S7-A2." % na.END,
                       "pieces": frames}, f, indent=1)
        report.add(PRIMARY, "kit frame table", True, os.path.relpath(path, common.REPO_DIR))

    # previews: _01, _02, _01 chained as a ring places them (the middle piece at its own frame)
    rim1, rim2 = objs["M_Env_Nursery_Rim_01"], objs["M_Env_Nursery_Rim_02"]
    seq = ["M_Env_Nursery_Rim_01", "M_Env_Nursery_Rim_02", "M_Env_Nursery_Rim_01"]
    poses = [(0.0, 0.0, 0.0)]
    for a, b in zip(seq, seq[1:]):
        poses.append(na.next_pose(poses[-1], a, b))
    mid = poses[1]
    run = []
    for i, (name, pose) in enumerate(zip(seq, poses)):
        th = pose[0] - mid[0]
        x, y = na.pose_local(mid, pose[1], pose[2])
        m = Matrix.Translation((x, y, 0.0)) @ Matrix.Rotation(th, 4, 'Z') @ Matrix.Translation(offs[name])
        run.append(copy_at(objs[name], m, "C%d" % i))
    solo = copy_at(rim1, Matrix.Translation(offs[PRIMARY]), "Solo")
    # the Nursery sand (06 4.2, #F6E3B4) on the pool side at depth 26 (it runs on under the bank, hidden), the Reef
    # floor (#F2D9A0) beyond the outer face
    R1, R2 = na.RIMS[PRIMARY]["radius"], na.RIMS["M_Env_Nursery_Rim_02"]["radius"]
    sand1 = ground("Sand_01", (0.0, -R1), 0.0, R1 + 30.0, na.SAND_Z, "#F6E3B4")
    sand2 = ground("Sand_02", (0.0, -R2), 0.0, R2 + 30.0, na.SAND_Z, "#F6E3B4")
    floor1 = ground("Floor_01", (0.0, -R1), R1 + 60.0, R1 + 400.0, na.OUTER_FLOOR_Z, "#F2D9A0")
    jx, jy = na.bend((na.RIMS["M_Env_Nursery_Rim_02"]["span"] / 2.0, 0.0, 0.0), R2)[:2]
    lo, hi = ra.bounds(rim1)
    size = tuple(hi[i] - lo[i] for i in range(3))
    return {
        "name": PRIMARY,
        "category": "Env",
        "id": "rim",
        "budget": "nursery_rim",
        "origin": "prop",
        "size": size,
        "size_tol": 0.001,
        "facing": {"kind": "tag"},
        "meshes": [{"object": objs[n], "role": "body", "primary": n == PRIMARY} for n in na.RIM_NAMES],
        "texture_sampler": na.rim_sampler(atlas),
        "texture_name": "%s, cell %s (gradient map)" % (na.ATLAS, na.RIM_CELL),
        "extra_checks": [ra.piece_checks([objs[n] for n in na.RIM_NAMES if n != PRIMARY]), na.rim_checks(list(objs.values()), offs),
                         na.rim_uv_check(list(objs.values())), write_frames],
        "exports": [{"file": "meshes/%s.fbx" % n, "objects": [objs[n]]} for n in na.RIM_NAMES],
        "textures": [],
        "preview": {
            "main": [rim1],
            "blocks": {"mid": na.RIM_BLOCKS["mid"], "light": na.RIM_BLOCKS["light"], "dark": na.RIM_BLOCKS["dark"]},
            "view_captions": {"Side": ["pool side left; a broad convex dome, crest 4.9 to 8.6", "above the surface; base buried at depth 86"],
                              "Top": ["waterline radius 172, 64 studs; toe 32 into the pool"]},
            "lineup": [{"label": "Rim_01 long low swell", "objects": [rim1]}, {"label": "Rim_02 fuller hump, leaning", "objects": [rim2]},
                       {"label": "tier-7 Minnow", "objects": [bpy.data.objects["REF_Minnow_T7"]]}],
            "lineup_caption": ["T_EnvNursery_Alb rim cell: soft violet toe band, rose-to-peach mid, pale peach cap"],
            "extras": [
                {"title": "Rim_01, Rim_02, Rim_01 chained, from the pool", "objects": run + [sand2],
                 "camera": {"location": (0.0, -120.0, -14.0), "look_at": (0.0, 0.0, -10.0), "lens": 18.0},
                 "caption": ["scale 1, one tint, tangent to tangent: one rolling bank", "crest above the surface (z 0)"]},
                {"title": "A joint up close (Rim_02 into Rim_01)", "objects": run + [sand2],
                 "camera": {"location": (jx - 14.0, jy - 46.0, -16.0), "look_at": (jx, jy, -8.0), "lens": 24.0},
                 "caption": ["the joint is mid-frame: the same profile and colours", "on both sides, no notch, no seam"]},
                {"title": "Pool face, low, on the sand", "objects": [solo, sand1],
                 "camera": {"location": (-24.0, -60.0, -22.0), "look_at": (0.0, 0.0, -14.0), "lens": 24.0},
                 "caption": ["a thin violet toe band at the sand, the pale cap", "from 3.5 under the waterline"]},
                {"title": "Outer face, on the Reef floor (depth 66)", "objects": [solo, floor1],
                 "camera": {"location": (30.0, 170.0, -30.0), "look_at": (0.0, 30.0, -40.0), "lens": 24.0},
                 "caption": ["runs down to the Kelp, Reef and Ledge floors"]},
            ],
            "texture": "T_EnvNursery_Alb 512 x 512, rim cell 64 x 256 (a gradient map), one tint",
        },
    }


if __name__ == "__main__":
    import run
    run.main(__file__)
