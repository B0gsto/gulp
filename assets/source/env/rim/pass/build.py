"""M_Env_Rim_Pass_01 and _02: task S5-A2 (docs/13-sprint-plan.md Sprint 5; docs/07-asset-list.md 6.1 row
M_Env_Rim_Pass, 5,000 tris in 2 meshes, T_Tile_Rock_Alb; docs/03-content-catalog.md 6.7: 64 wide,
depth 5 to 55, 160 long, used four times at B000, B090, B180, B270).

    Blender --background --python assets/source/env/rim/pass/build.py

A tunnel straight through the Rim: a level corridor 64 wide from depth 55 (a 5-stud sill above the Reef
floor) to depth 5 under a 17-stud rock lintel, so nothing can jump the Rim (03 6.7). Its walls are dented
outward only (never narrower than 64), its upper corners rounded (radius 13) like a worn arch. The 12
degrees of Rim it replaces is cut into two meshes along the corridor's centre line: _01 the west half
(left, seen from the Reef), _02 the east half. One rock field runs across both, so the lintel and the sill
meet without a step; the outer ends are recessed like every Rim piece's. Origins: the centre of each
half's base (06 6.1); both halves take the pass's bearing (rimart.layout, M_Env_Rim_Pass_01.rim.json).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

import rimart as ra  # noqa: E402

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

NAMES = ("M_Env_Rim_Pass_01", "M_Env_Rim_Pass_02")
PRIMARY = NAMES[0]


def corridor_check(objs, offs):
    """03 6.7: 64 wide and clear from depth 5 to 55 along the whole 160 studs: rays across and up the corridor."""
    def check(spec, report):
        from mathutils.bvhtree import BVHTree
        trees = []
        for ob in objs:
            me = ob.data
            vs = [v.co + offs[ob.name] for v in me.vertices]
            trees.append(BVHTree.FromPolygons(vs, [tuple(p.vertices) for p in me.polygons]))
        def dist(origin, direction):
            hits = [t.ray_cast(origin, direction, 300.0) for t in trees]
            return min((h[3] for h in hits if h[0] is not None), default=999.0)
        widths, heights = [], []
        for y in [ra.R_IN + 2.0 + 156.0 * k / 12 for k in range(13)]:
            for z in (-52.0, -40.0, -30.0, -19.0):
                o = Vector((0.0, y, z))
                widths.append(dist(o, Vector((-1.0, 0.0, 0.0))) + dist(o, Vector((1.0, 0.0, 0.0))))
            for x in (-16.0, 0.0, 16.0):
                o = Vector((x, y, -30.0))
                heights.append((dist(o, Vector((0.0, 0.0, 1.0))), dist(o, Vector((0.0, 0.0, -1.0)))))
        wmin = min(widths)
        roof = min(u for u, d in heights)
        floor = max(d for u, d in heights)
        ok = 64.0 - 0.05 <= wmin <= 72.0 and roof >= 25.0 - 0.6 and abs(floor - 25.0) < 0.6
        report.add(PRIMARY, "corridor", ok, "narrowest %.1f studs across at depths 19 to 52 (64 to 72; above depth 17 the upper corners round off, radius 12); roof over the middle 32 at depth %.1f or higher, floor at depth %.1f (03 6.7: 5 to 55), "
                   "measured at 13 stations over the Rim's 160" % (wmin, 30.0 - roof, 30.0 + floor))
    return check


def build():
    mat = ra.rock_material()
    objs, offs, boxes = {}, {}, {}
    for name in NAMES:
        ob = ra.build_piece(name)
        ob.data.materials.append(mat)
        objs[name] = ob
        boxes[name] = ra.bounds(ob)
        offs[name] = ra.fit_base(ob)
        print("[rim] %s: %d tris, origin at ring-frame %s" % (name, len(ob.data.polygons), tuple(round(c, 2) for c in offs[name])))
    import coveart as ca
    table = {"pieces": {}, "placements": []}
    for name in NAMES:
        lo, hi = boxes[name]
        size = [hi[i] - lo[i] for i in range(3)]
        table["pieces"][name] = {"origin_ring_frame": ca.point(tuple(offs[name])),
                                 "box_centre_ring_frame": ca.point(tuple((lo[i] + hi[i]) / 2.0 for i in range(3))),
                                 "box_size": {"blender": [round(c, 3) for c in size], "roblox": [round(size[0], 3), round(size[2], 3), round(size[1], 3)]}}
    for it in ra.layout():
        if it["mesh"] in NAMES:
            lo, hi = boxes[it["mesh"]]
            it["cframe"] = ra.roblox_cframe([(lo[i] + hi[i]) / 2.0 for i in range(3)], it["bearing"])
            table["placements"].append(it)

    pv = []
    for name in NAMES:
        c = objs[name].copy()
        c.name = "PV_" + name
        bpy.data.collections["PREVIEW"].objects.link(c)
        c.matrix_world = Matrix.Translation(offs[name])
        c.hide_render = True
        pv.append(c)
    neighbours = []
    for nm, b, tag in (("M_Env_Rim_Wall_02", -12.0, "W"), ("M_Env_Rim_Wall_02", 12.0, "E")):
        ob = ra.build_piece(nm)
        ob.name = "PV_%s_%s" % (nm, tag)
        ob.data.materials.append(mat)
        for c in list(ob.users_collection):
            c.objects.unlink(ob)
        bpy.data.collections["PREVIEW"].objects.link(ob)
        ra.place(ob, b)
        ob.hide_render = True
        neighbours.append(ob)

    def write_table(spec, report):
        if report.ok:
            report.add(PRIMARY, "layout table", True, ra.write_layout(table, PRIMARY))
    body = objs[PRIMARY]
    size = tuple(Vector(ra.bounds(body)[1]) - Vector(ra.bounds(body)[0]))
    return {
        "name": PRIMARY,
        "category": "Env",
        "id": "pass",
        "budget": "rim_pass",
        "origin": "prop",
        "size": size,
        "size_tol": 0.001,
        "facing": {"kind": "tag"},
        "meshes": [{"object": objs[n], "role": "body", "primary": n == PRIMARY, "uv_tile_studs": ra.TILE} for n in NAMES],
        "extra_checks": [ra.piece_checks([objs[NAMES[1]]]), corridor_check([objs[n] for n in NAMES], offs), write_table],
        "exports": [{"file": "meshes/%s.fbx" % n, "objects": [objs[n]]} for n in NAMES],
        "preview": {
            "main": [body],
            "view_captions": {"Side": ["west half; the corridor runs left to right", "depth 5 to 55 under a 17-stud lintel"]},
            "lineup": [
                {"label": "M_Env_Rim_Pass_01 west half", "objects": [body]},
                {"label": "M_Env_Rim_Pass_02 east half", "objects": [objs[NAMES[1]]]},
                {"label": "tier-7 Minnow", "objects": [bpy.data.objects["REF_Minnow_T7"]]},
            ],
            "lineup_caption": ["5,000 tris in 2 meshes (07 6.1)"],
            "extras": [
                {"title": "Both halves, from the Reef", "objects": pv,
                 "camera": {"location": (0.0, 250.0, -22.0), "look_at": (0.0, 420.0, -30.0), "lens": 22.0},
                 "caption": ["64 wide, depth 5 to 55, 160 long (03 6.7)"]},
                {"title": "Between two cove pieces (E Pass, C07 and C08)", "objects": pv + neighbours,
                 "camera": {"location": (-150.0, 230.0, 25.0), "look_at": (0.0, 420.0, -25.0), "lens": 20.0},
                 "caption": ["flank ends recessed into a crease against _02"]},
                {"title": "Looking out through the pass", "objects": pv,
                 "camera": {"location": (0.0, 370.0, -30.0), "look_at": (0.0, 600.0, -30.0), "lens": 18.0},
                 "caption": ["walls dented outward only; floor level at depth 55"]},
                {"title": "From above", "objects": pv + neighbours,
                 "camera": {"location": (0.0, 480.0, 330.0), "look_at": (0.0, 480.0, 0.0), "lens": 22.0},
                 "caption": ["12 degrees of Rim between two coves"]},
            ],
            "texture": "%s (shared tile, S5-A1), one repeat per 32 studs, Reef tint" % ra.ROCK_TILE,
        },
    }


if __name__ == "__main__":
    import run
    run.main(__file__)
