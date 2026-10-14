"""M_Env_Nursery_Rim_01 and _02: task S6-A3 (docs/13-sprint-plan.md Sprint 6; docs/07-asset-list.md 6.2 row
M_Env_Nursery_Rim_01-02, 1,000 tris each; docs/03-content-catalog.md 6.1 and 6.2; docs/06-art-bible.md 6.3, 9.1,
9.2).

    Blender --background --python assets/source/env/nursery/rim/build.py

Low rounded rim pieces that enclose the pool (nurseryart: a closed slab whose top is a height field over the arc's
plan, a bank from a toe buried in the sand 32 studs into the pool up into a round, uneven dome 4 to 12 above the
surface, a few broad rock masses fused on both faces, the outer face down to a flat base at depth 86;
decimated to budget; painted from the rim cell of T_EnvNursery_Alb, a gradient map: three flat pastel coral value
blocks and two broad gradients, mapped by each vertex's exposure). Each is an arc concave toward the pool, its front
(-Y); radius and span are measured at the waterline:

  _01  gentle arc, radius 172 (its toe follows the oval's long sides at 140), 64 studs
  _02  tight arc, radius 96 (its toe follows the oval's ends at 64), 50 studs

Within 5 studs of each joint both neighbours take one shared joint profile (crest 7 above the surface); each piece
runs 12 studs past its joints and dives there under its neighbour, so a ring is one bank with no notch at a joint and
a lone piece ends in rounded noses. Copies take 80 to 125% scale (06 9.1) to follow the oval, and a
SurfaceAppearance.Color tint each (nurseryart.RIM_TINTS) so neighbours differ (MeshParts cannot be mirrored).
Origin: the centre of the flat base (06 6.1); the arc frame (centre, radius, surface and sand level relative to the
origin) goes to assets/export/meshes/M_Env_Nursery_Rim.kit.json.
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
                               "base). Place a copy so its arc centre sits on the pool's local centre of curvature; scale 0.8 to 1.25 "
                               "moves the face to R = arc_radius x scale (06 9.1). Tints: nurseryart.RIM_TINTS. Assembly is S7-A2.",
                       "tints": list(na.RIM_TINTS), "pieces": frames}, f, indent=1)
        report.add(PRIMARY, "kit frame table", True, os.path.relpath(path, common.REPO_DIR))

    # previews: three _01 along a gentle curve; an end of the oval: _01, _02, _02, _01
    rim1, rim2 = objs["M_Env_Nursery_Rim_01"], objs["M_Env_Nursery_Rim_02"]
    run1 = []
    for i, deg in enumerate((-21.3, 0.0, 21.3)):
        m = Matrix.Rotation(math.radians(-deg), 4, 'Z') @ Matrix.Translation((0.0, na.RIMS[PRIMARY]["radius"], 0.0)) @ Matrix.Translation(offs[PRIMARY])
        run1.append(copy_at(rim1, Matrix.Translation((0.0, -na.RIMS[PRIMARY]["radius"], 0.0)) @ m, "S%d" % i))
    end = []
    R2 = na.RIMS["M_Env_Nursery_Rim_02"]["radius"]
    for i, deg in enumerate((-14.9, 14.9)):
        m = Matrix.Rotation(math.radians(-deg), 4, 'Z') @ Matrix.Translation((0.0, R2, 0.0)) @ Matrix.Translation(offs["M_Env_Nursery_Rim_02"])
        end.append(copy_at(rim2, Matrix.Translation((0.0, -R2, 0.0)) @ m, "E%d" % i))
    solo = copy_at(rim1, Matrix.Translation(offs[PRIMARY]), "Solo")
    # the Nursery sand (06 4.2, #F6E3B4) on the pool side at depth 26, the Reef floor (#F2D9A0) beyond the outer face
    R1 = na.RIMS[PRIMARY]["radius"]
    sand1 = ground("Sand_01", (0.0, -R1), 0.0, R1 - 21.0, na.SAND_Z, "#F6E3B4")
    sand2 = ground("Sand_02", (0.0, -R2), 0.0, R2 - 21.0, na.SAND_Z, "#F6E3B4")
    floor1 = ground("Floor_01", (0.0, -R1), R1 + 40.0, R1 + 400.0, na.OUTER_FLOOR_Z, "#F2D9A0")
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
            "view_captions": {"Side": ["pool side left; a round dome 4 to 12 above the surface,", "base buried at depth 86"],
                              "Top": ["waterline radius 172, 64 studs; toe 32 into the pool"]},
            "lineup": [{"label": "Rim_01 gentle arc", "objects": [rim1]}, {"label": "Rim_02 tight arc", "objects": [rim2]},
                       {"label": "tier-7 Minnow", "objects": [bpy.data.objects["REF_Minnow_T7"]]}],
            "lineup_caption": ["T_EnvNursery_Alb rim cell: soft violet dark, rose-to-peach mid, pale peach light"],
            "extras": [
                {"title": "Three Rim_01 along a long side, from the pool", "objects": run1 + [sand1],
                 "camera": {"location": (0.0, -95.0, -16.0), "look_at": (0.0, 0.0, -14.0), "lens": 20.0},
                 "caption": ["one shared profile at each joint, then each piece dives under the next", "crest above the surface (z 0)"]},
                {"title": "Two Rim_02 round an end, from the pool", "objects": end + [sand2],
                 "camera": {"location": (0.0, -75.0, -12.0), "look_at": (0.0, 0.0, -10.0), "lens": 18.0},
                 "caption": ["toe radius 64: the oval's ends"]},
                {"title": "Pool face, low, on the sand", "objects": [solo, sand1],
                 "camera": {"location": (-24.0, -48.0, -22.0), "look_at": (0.0, 0.0, -16.0), "lens": 24.0},
                 "caption": ["a dark foot at the sand, a light band", "just under the waterline"]},
                {"title": "Outer face, on the Reef floor (depth 66)", "objects": [solo, floor1],
                 "camera": {"location": (30.0, 120.0, -30.0), "look_at": (0.0, 20.0, -40.0), "lens": 24.0},
                 "caption": ["runs down to the Kelp, Reef and Ledge floors"]},
            ],
            "texture": "T_EnvNursery_Alb 512 x 512, rim cell 64 x 256 (a gradient map), tint per copy",
        },
    }


if __name__ == "__main__":
    import run
    run.main(__file__)
