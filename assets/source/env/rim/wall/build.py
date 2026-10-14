"""M_Env_Rim_Wall_01, _02 and _03: task S5-A2 (docs/13-sprint-plan.md Sprint 5; docs/07-asset-list.md 6.1
row M_Env_Rim_Wall, 2,500 tris each, T_Tile_Rock_Alb; docs/03-content-catalog.md 6.7).

    Blender --background --python assets/source/env/rim/wall/build.py

The Rim is pale rock (03 6.7) from r 400 to r 560, 12 studs above the surface, its foot buried to
depth 100. Review loop 3: each piece is a cluster of large rounded rock masses, not a slab with a
profile: the plain Rim body (rimart.core_parts) with 5 to 9 deformed boulders (icospheres lumped, cut by
flat rock planes, leaned and turned) on the Reef face, the skyline (stepped, uneven, never under +12),
the outer face and low feet that bury into the sand, fused by a voxel remesh and decimated to budget.
The texture is the Rim's own T_Rim_Alb (07 6.1): large irregular rock facets with lit tops, blue-violet
undersides and soft crevices only where masses meet, box-projected on the ring's axes, one repeat per
64 studs; a banding check keeps masonry courses out. The layout tints every copy so neighbours differ
(MeshParts cannot be mirrored).

  _01  plain span, 12 degrees (84 studs of inner face): the same rock as _02 with no mouth, so any cove
       slot can take either. 03's 24 coves leave no plain span on the ring today; it is the slot filler
       for a cove-less stretch (test arenas, the place before coves are set, a retired slot).
  _02  cove span, 12 degrees, one per cove (24): a rounded mass behind the mouth is cut flat on the
       mouth plane where the M_Cove_Mouth stones sit, framed by leaning flank masses and a brow (cove frame y = 0), with an opening 3 studs wider than the mouth outline
       (the throat's 2.5-stud skin slides in) running 26 studs in, into a closed pocket that holds the
       M_Cove_Interior shell. The cove frame (03 6.7: mouth centre on the inner face at r 400, depth 30)
       is (0, 400, -30) in the ring frame.
  _03  buttress, 4 degrees: a rounded rock swelling 8 studs proud of the Rim and 6 above its top, domed
       at both ends. It fills the 1 to 3 degree gaps beside the North, South and West passes (a pair of
       gateposts) and caps the Rim's two ends at the Nursery bulge.

Origins: the centre of each piece's base (06 6.1). The ring layout with every placement's CFrame goes to
assets/export/meshes/M_Env_Rim.rim.json (rimart.layout; written by this build).
"""
import importlib.util
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

import rimart as ra  # noqa: E402

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402

NAMES = ("M_Env_Rim_Wall_01", "M_Env_Rim_Wall_02", "M_Env_Rim_Wall_03")
PRIMARY = "M_Env_Rim_Wall_02"


def mouth_object():
    """M_Cove_Mouth from its own build (S5-A3), in the cove frame, for the previews."""
    path = os.path.join(ra.SOURCE, "cove", "mouth", "build.py")
    spec = importlib.util.spec_from_file_location("gulp_cove_mouth", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    img, block, work = mod.ca.texture(mod.NAME)
    mat = mod.ca.material("MAT_PV_CoveMouth", work)
    ob, rings, kinds = mod.build_mesh(mat)
    ob.name = "PV_CoveMouth"
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    bpy.data.collections["PREVIEW"].objects.link(ob)
    return ob


def copy_at(ob, off, bearing, tag):
    c = ob.copy()
    c.name = "PV_%s_%s" % (ob.name.replace("M_Env_Rim_", ""), tag)
    bpy.data.collections["PREVIEW"].objects.link(c)
    c.matrix_world = Matrix.Rotation(-math.radians(bearing), 4, 'Z') @ Matrix.Translation(off)
    return c


def mouth_at(mouth, bearing, tag):
    c = mouth.copy()
    c.name = "PV_Mouth_%s" % tag
    bpy.data.collections["PREVIEW"].objects.link(c)
    c.matrix_world = Matrix.Rotation(-math.radians(bearing), 4, 'Z') @ Matrix.Translation(ra.cove_origin())
    return c


def opening_check(wall, off):
    """The opening clears the mouth's throat skin and the pocket clears the interior shell."""
    import coveart as ca

    def check(spec, report):
        ox, oy, oz = ra.cove_origin()
        pts = [v.co + off for v in wall.data.vertices]

        def outline(grow, n=360):
            out = []
            for k in range(n):
                th = 2.0 * math.pi * k / n
                (hx, hz), (nx, nz) = ca.hole(th), ca.hole_normal(th)
                out.append((hx + nx * grow, hz + nz * grow))
            return out

        def inside(p, poly):
            x, z = p.x - ox, p.z - oz
            c = False
            for (x0, z0), (x1, z1) in zip(poly, poly[1:] + poly[:1]):
                if (z0 > z) != (z1 > z) and x < x0 + (z - z0) * (x1 - x0) / (z1 - z0):
                    c = not c
            return c
        skin, near = outline(2.5), outline(6.0)
        band = [p for p in pts if oy - 1.0 <= p.y <= oy + 26.0]
        blocked = [p for p in band if inside(p, skin)]
        wall_pts = [p for p in band if inside(p, near)]
        wd = max(p.x for p in wall_pts) - min(p.x for p in wall_pts) if wall_pts else 0.0
        ht = max(p.z for p in wall_pts) - min(p.z for p in wall_pts) if wall_pts else 0.0
        report.add(wall.name, "cove opening", not blocked and wd >= ca.MOUTH_W + 5.0 and ht >= ca.MOUTH_H + 5.0,
                   "%d Rim vertices inside the mouth's throat skin (outline + 2.5) over the 25-stud throat; tunnel %.1f x %.1f "
                   "(03 6.7 mouth 36 x 28; the opening is the outline grown by %.0f)" % (len(blocked), wd, ht, ra.COVE_CUT_GROW))
        hw, y0, y1, hh = ra.CHAMBER_CUT
        inside = [p for p in pts if abs(p.x) < ca.CH_W / 2.0 + 3.0 and oy + 26.0 < p.y < oy + 134.0
                  and abs(p.z - oz) < ca.CH_H / 2.0 + 3.0]
        report.add(wall.name, "cove pocket", not inside,
                   "%d Rim vertices inside the interior shell's outside (76 x 110 x 44 chamber, 3-stud wall); pocket %.0f x %.0f x %.0f"
                   % (len(inside), 2 * hw, y1 - y0, 2 * hh))
        zone = [p for p in pts if p.y < oy + 3.0 and ra.mouth_zone(math.atan2(p.x, p.y), p.z) > 0.999]
        off_plane = [p for p in zone if abs(p.y - oy) > 0.05]
        report.add(wall.name, "mouth plane", bool(zone) and not off_plane,
                   "%d of %d face vertices under the stone frame off the mouth plane (cove frame y = 0, where the M_Cove_Mouth stones sit)"
                   % (len(off_plane), len(zone)))
    return check


def build():
    mat = ra.rock_material()
    tex_img = ra.rim_texture()
    objs, offs = {}, {}
    for name in NAMES:
        ob = ra.build_piece(name)
        ob.data.materials.append(mat)
        objs[name] = ob
    # ring-frame boxes for the layout table, before the origins move
    boxes = {n: ra.bounds(o) for n, o in objs.items()}
    for name, ob in objs.items():
        offs[name] = ra.fit_base(ob)
        print("[rim] %s: %d tris, origin at ring-frame %s" % (name, len(ob.data.polygons), tuple(round(c, 2) for c in offs[name])))

    import coveart as ca
    table = {"pieces": {}, "placements": []}
    for name in NAMES:
        lo, hi = boxes[name]
        centre = [(lo[i] + hi[i]) / 2.0 for i in range(3)]
        size = [hi[i] - lo[i] for i in range(3)]
        table["pieces"][name] = {"origin_ring_frame": ca.point(tuple(offs[name])), "box_centre_ring_frame": ca.point(tuple(centre)),
                                 "box_size": {"blender": [round(c, 3) for c in size], "roblox": [round(size[0], 3), round(size[2], 3), round(size[1], 3)]}}
    table["pieces"][PRIMARY]["cove_frame_in_piece"] = ca.point(tuple(Vector(ra.cove_origin()) - offs[PRIMARY]),
                                                               note="M_Cove_Mouth's cove frame (S5-A3 M_Cove_Mouth.cove.json) relative to this piece's origin")
    table["note"] = ("pass halves and their boxes are in M_Env_Rim_Pass_01.rim.json; haze placements in M_Env_Blue_Haze.rim.json. "
                     "Nursery bulge B%03d to B%03d (Little Arch, B225) is the Nursery kit's (07 6.2)" % ra.NURSERY_BULGE)
    for it in ra.layout():
        if it["mesh"] in table["pieces"]:
            lo, hi = boxes[it["mesh"]]
            it["cframe"] = ra.roblox_cframe([(lo[i] + hi[i]) / 2.0 for i in range(3)], it["bearing"])
        table["placements"].append(it)

    # previews: three coves at 11-degree pitch, and the three pieces snapped with a cove mouth inserted
    mouth = mouth_object()
    seg = [copy_at(objs[PRIMARY], offs[PRIMARY], b, "C%d" % i) for i, b in enumerate((-11.0, 0.0, 11.0))]
    seg += [mouth_at(mouth, b, "C%d" % i) for i, b in enumerate((-11.0, 0.0, 11.0))]
    kit = [copy_at(objs["M_Env_Rim_Wall_01"], offs["M_Env_Rim_Wall_01"], -14.0, "K"),
           copy_at(objs["M_Env_Rim_Wall_03"], offs["M_Env_Rim_Wall_03"], -7.0, "K"),
           copy_at(objs[PRIMARY], offs[PRIMARY], 0.0, "K"), mouth_at(mouth, 0.0, "K")]
    mouth.hide_render = True
    for o in seg + kit:
        o.hide_render = True
    wall2 = objs[PRIMARY]
    size = tuple(Vector(ra.bounds(wall2)[1]) - Vector(ra.bounds(wall2)[0]))

    def write_table(spec, report):
        if not report.ok:
            report.add(PRIMARY, "layout table", True, "not written: validation failed")
            return
        report.add(PRIMARY, "layout table", True, ra.write_layout(table))
    return {
        "name": PRIMARY,
        "category": "Env",
        "id": "wall",
        "budget": "rim_wall",
        "origin": "prop",
        "size": size,
        "size_tol": 0.001,
        "facing": {"kind": "tag"},
        "meshes": [{"object": objs[n], "role": "body", "primary": n == PRIMARY, "uv_tile_studs": ra.TILE} for n in NAMES],
        "extra_checks": [ra.piece_checks([objs[n] for n in NAMES if n != PRIMARY]), opening_check(wall2, offs[PRIMARY]),
                         ra.rim_texture_checks(tex_img), write_table],
        "exports": [{"file": "meshes/%s.fbx" % n, "objects": [objs[n]]} for n in NAMES],
        "textures": [{"file": "textures/%s.png" % ra.ROCK_TILE, "write": lambda path: __import__("preyart").save_rgba(path, tex_img), "max": 512}],
        "preview": {
            "main": [wall2],
            "view_captions": {"Side": ["Reef side left; top 12 above the surface,", "foot buried to depth 100"],
                              "Top": ["12 degrees: 84 studs of inner face, 117 of outer"]},
            "lineup": [
                {"label": "M_Env_Rim_Wall_01 plain", "objects": [objs["M_Env_Rim_Wall_01"]]},
                {"label": "M_Env_Rim_Wall_02 cove", "objects": [wall2]},
                {"label": "M_Env_Rim_Wall_03 buttress", "objects": [objs["M_Env_Rim_Wall_03"]]},
                {"label": "tier-7 Minnow", "objects": [bpy.data.objects["REF_Minnow_T7"]]},
            ],
            "lineup_caption": ["T_Rim_Alb: large rock planes, lit top edges, violet creases"],
            "extras": [
                {"title": "Three coves, 11-degree pitch, from the Reef", "objects": seg,
                 "camera": {"location": (0.0, 255.0, -24.0), "look_at": (0.0, 400.0, -26.0), "lens": 20.0},
                 "caption": ["M_Cove_Mouth (S5-A3) set in each _02 opening", "ends overlap 1 degree in a recessed crease"]},
                {"title": "01 + 03 + 02 snapped, mouth inserted", "objects": kit,
                 "camera": {"location": (-95.0, 270.0, 30.0), "look_at": (-45.0, 410.0, -20.0), "lens": 20.0},
                 "caption": ["plain span, buttress over the joint, cove span"]},
                {"title": "Snapped, from above", "objects": kit,
                 "camera": {"location": (-45.0, 470.0, 260.0), "look_at": (-45.0, 470.0, 0.0), "lens": 24.0},
                 "caption": ["humped top (never under +12), bulging face"]},
                {"title": "Mouth fit, front", "objects": [seg[1], seg[4]],
                 "camera": {"location": (0.0, 330.0, -30.0), "look_at": (0.0, 400.0, -30.0), "lens": 28.0},
                 "caption": ["face flat on the mouth plane under the stones", "opening 3 studs past the mouth outline"]},
            ],
            "texture": "%s 512 x 512, painted by script, one repeat per 64 studs, no tint (07 row to add)" % ra.ROCK_TILE,
        },
    }


if __name__ == "__main__":
    import run
    run.main(__file__)
