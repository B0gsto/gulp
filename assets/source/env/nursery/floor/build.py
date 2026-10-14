"""M_Env_Nursery_Floor_01 to _04: task S6-A3 (docs/13-sprint-plan.md Sprint 6; docs/07-asset-list.md 6.2 row
M_Env_Nursery_Floor_01-04, 3,000 tris each, T_Tile_Sand_Alb; docs/03-content-catalog.md 6.2; docs/06-art-bible.md
6.3, 9.1, 9.2).

    Blender --background --python assets/source/env/nursery/floor/build.py

Pale sand chunks 128 x 128 (nurseryart: closed slabs, the sand level 8 above the flat base, every edge on the shared
profile so any chunk meets any other at any turn, top-down UVs one T_Tile_Sand_Alb repeat per 32 studs, adaptive
triangles). The four chunks (07 6.2: "one is the Krill Corner bowl"):

  _01  Hatch bank: a low bank 3 high, where the Hatch Bed's sea grass and egg sit (03 6.2: floor 24)
  _02  Ripple flat: two fields of sand waves, a shallow dish and a low hump
  _03  Krill Corner bowl (03 6.2: 50 across): 4.5 deep, an uneven lip
  _04  Twin swells: two swells with a saddle, waves on their flanks

13 3.2 thins kit variants by a third, so the slice manifest carries _01 to _03 (the bowl among them); _04 is
built and exported with the rest for the full kit. The SurfaceAppearance takes T_Tile_Sand_Alb with the Nursery
tint (tilegen.tints, 06 5.3) and T_Shared_RghChalk (06 5.1). Origin: the centre of the base (06 6.1); place the
base at depth 34 so the sand level lies at depth 26.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

import nurseryart as na  # noqa: E402

import bpy  # noqa: E402
from mathutils import Matrix  # noqa: E402

PRIMARY = "M_Env_Nursery_Floor_03"


def copy_at(ob, loc, turn, tag):
    c = ob.copy()
    c.name = "PV_%s_%s" % (ob.name.replace("M_Env_Nursery_", ""), tag)
    bpy.data.collections["PREVIEW"].objects.link(c)
    c.matrix_world = Matrix.Translation(loc) @ Matrix.Rotation(math.radians(turn), 4, 'Z')
    c.hide_render = True
    return c


def build():
    import rimart as ra
    mat = na.sand_material()
    objs = {}
    for name in na.FLOOR_NAMES:
        ob = na.build_floor(name)
        ob.data.materials.append(mat)
        objs[name] = ob
        print("[nursery] %s: %d tris" % (name, ra.tri_count(ob)))
    H = na.HALF
    grid = [copy_at(objs[n], (x, y, 0.0), 0.0, "G")
            for n, (x, y) in zip(na.FLOOR_NAMES, ((-H, -H), (H, -H), (-H, H), (H, H)))]
    turned = [copy_at(objs["M_Env_Nursery_Floor_01"], (-H, 0.0, 0.0), 0.0, "T0"),
              copy_at(objs["M_Env_Nursery_Floor_04"], (H, 0.0, 0.0), 90.0, "T90")]
    prim = objs[PRIMARY]
    lo, hi = ra.bounds(prim)
    size = tuple(hi[i] - lo[i] for i in range(3))
    return {
        "name": PRIMARY,
        "category": "Env",
        "id": "floor",
        "budget": "floor_chunk",
        "origin": "prop",
        "size": size,
        "size_tol": 0.001,
        "facing": {"kind": "tag"},
        "meshes": [{"object": objs[n], "role": "body", "primary": n == PRIMARY, "uv_tile_studs": na.SAND_TILE} for n in na.FLOOR_NAMES],
        "extra_checks": [ra.piece_checks([objs[n] for n in na.FLOOR_NAMES if n != PRIMARY]), na.floor_checks(list(objs.values()))],
        "exports": [{"file": "meshes/%s.fbx" % n, "objects": [objs[n]]} for n in na.FLOOR_NAMES],
        "textures": [],
        "preview": {
            "main": [prim],
            "view_captions": {"Side": ["Krill Corner bowl: 50 across, 4.5 deep;", "sand level 8 above the base"],
                              "Top": ["128 x 128; 4 repeats of T_Tile_Sand_Alb"]},
            "lineup": [{"label": "%s %s" % (n.replace("M_Env_Nursery_", ""), na.FLOORS[n]["title"]), "objects": [objs[n]]}
                       for n in na.FLOOR_NAMES] + [{"label": "tier-7 Minnow", "objects": [bpy.data.objects["REF_Minnow_T7"]]}],
            "lineup_caption": ["T_Tile_Sand_Alb x Nursery tint, repeats every 32 studs"],
            "extras": [
                {"title": "Four chunks on the 128 grid", "objects": grid,
                 "camera": {"location": (-150.0, -190.0, 70.0), "look_at": (0.0, 0.0, 4.0), "lens": 22.0},
                 "caption": ["01 02 / 03 04, unrotated: sand repeat continuous", "edges on one shared profile"]},
                {"title": "From above", "objects": grid,
                 "camera": {"location": (0.0, 0.0, 330.0), "look_at": (0.0, 0.1, 0.0), "lens": 24.0},
                 "caption": ["relief fades into the edge band (18 studs)"]},
                {"title": "Turned 90 degrees and still meeting", "objects": turned,
                 "camera": {"location": (0.0, -95.0, 30.0), "look_at": (0.0, 0.0, 6.0), "lens": 24.0},
                 "caption": ["01 beside 04 turned 90: no step, no crease"]},
                {"title": "Krill Corner bowl, low", "objects": [prim],
                 "camera": {"location": (-40.0, -70.0, 18.0), "look_at": (4.0, -4.0, 6.0), "lens": 26.0},
                 "caption": ["a sandy bowl 50 across (03 6.2)"]},
            ],
            "texture": "T_Tile_Sand_Alb 512 x 512 (S5-A1), Nursery tint %s, one repeat per 32 studs" % (
                __import__("tilegen").tints(na.SAND)["nursery"][1]),
        },
    }


if __name__ == "__main__":
    import run
    run.main(__file__)
