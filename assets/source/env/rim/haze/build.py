"""M_Env_Blue_Haze and T_Haze_Mask: task S5-A2 (docs/13-sprint-plan.md Sprint 5 and 3.2; docs/07-asset-list.md
6.1 rows M_Env_Blue_Haze, 200 tris, and T_Haze_Mask, 256 x 256; docs/03-content-catalog.md 6.1: from r 965
the water darkens to deep blue and nothing passes r 1,000; docs/06-art-bible.md 4.2, 5.1, 10.2).

    Blender --background --python assets/source/env/rim/haze/build.py

"The Blue": the map ends in open water, not a wall. A curved curtain 15 degrees long at r 980, from depth
200 (below every floor it meets) to the surface, 4 studs thick so it is a closed mesh (06 6.5). Only its
inner face shows the mask; the back, rims and ends map to the mask's clear top corner. In Studio:
SurfaceAppearance { ColorMap = T_Haze_Mask, AlphaMode = Transparency, Color = the zone's fog colour
(06 4.2: Reef #1E9FD0, Kelp #238A72) (tune) }, CastShadow off, CanCollide off (the turn-back current is
code). The mask is dense at the floor (it hides the floor's end) and thins in one long smooth fade up the
water column, clear before the surface (review loop 1 replaced 07's ragged top: it read as saw teeth), so beyond it the legacy fog (06 10.2) carries on in the same
colour. Its RGB eases from white to 0.80 at the floor, so the tint darkens toward the zone's deep band.
The mask wraps left to right and each piece spans exactly one repeat, so pieces join with no seam.

One mesh does every run: placed at r 980 as is (the Kelp's outer edge), scaled in plan by r / 980 for a
smaller ring (r 620 east and south of the Reef, where the Drop-off is cut in the soft launch, 13 3.2), and
flattened in depth for the straight runs at the Kelp's two ends (B045, B225). Placements and MeshPart sizes:
assets/export/meshes/M_Env_Blue_Haze.rim.json. Origin: the centre of the base (06 6.1).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

import rimart as ra  # noqa: E402

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402
import preyart  # noqa: E402

NAME = "M_Env_Blue_Haze"


def mask_checks(img):
    def check(spec, report):
        a = img[..., 3]
        n = a.shape[0]
        seam = float(np.max(np.abs(a[:, 0] - a[:, -1])))
        inner = float(np.max(np.abs(np.diff(a, axis=1))))
        step_v = float(np.max(np.abs(np.diff(a, axis=0))))
        top, bottom = float(a[:3].max()), float(a[-8:].min())
        report.add(ra.HAZE_MASK, "size", a.shape == (256, 256), "%d x %d (07 6.1: 256 x 256)" % (n, a.shape[1]))
        report.add(ra.HAZE_MASK, "wraps left to right", seam <= max(inner, 0.01) * 1.5,
                   "alpha step across the wrap %.4f, largest step inside %.4f" % (seam, inner))
        report.add(ra.HAZE_MASK, "clear top", top < 0.01, "top rows alpha at most %.3f (the surface stays open water)" % top)
        report.add(ra.HAZE_MASK, "dense floor", bottom > 0.85, "bottom rows alpha at least %.3f (the floor's end is hidden)" % bottom)
        report.add(ra.HAZE_MASK, "soft", step_v < 0.035 and inner < 0.035,
                   "largest alpha step %.4f down, %.4f across, per pixel (no hard line; 06 5.2 gradients large and soft)" % (step_v, inner))
        import tilegen
        half = int(np.argmin(np.abs(a[:, 0] - 0.5)))
        for zone in ("reef", "kelp"):
            fog = np.array(common.hex_to_srgb(ra.FOG[zone]))
            top, floor, deep = fog * img[0, 0, :3], fog * img[-1, 0, :3], np.array(common.hex_to_srgb(ra.DEEP[zone]))
            lt, lf, ld = (float(tilegen.lstar(c)) for c in (top, floor, deep))
            report.add(ra.HAZE_MASK, "colour: %s" % zone, abs(lt - common.lstar(ra.FOG[zone])) < 0.5 and abs(lf - ld) < 8.0,
                       "x %s fog: L* %.1f where it fades out (fog L* %.1f), %.1f at the floor (deep band %s L* %.1f); half opacity %.0f%% up"
                       % (ra.FOG[zone], lt, common.lstar(ra.FOG[zone]), lf, ra.DEEP[zone], ld, 100.0 * (1 - half / float(a.shape[0]))))
    return check


def build():
    img = ra.haze_mask()
    work = os.path.join(common.review_dir(NAME), "%s_work.png" % ra.HAZE_MASK)
    preyart.save_rgba(work, img)
    haze = ra.build_haze(NAME)
    haze.data.materials.append(ra.haze_material(work, ra.FOG["reef"]))
    lo, hi = ra.bounds(haze)
    centre = [(lo[i] + hi[i]) / 2.0 for i in range(3)]
    box = [hi[i] - lo[i] for i in range(3)]
    off = ra.fit_base(haze)

    import coveart as ca
    places = []
    for it in ra.haze_layout():
        b = it["bearing"]
        if it["kind"] == "arc":
            k = it["radius"] / ra.HAZE_R
            cf = ra.roblox_cframe(centre, b, scale=(k, k))
            size = [box[0] * k, box[2], box[1] * k]
        else:
            br = math.radians(b)
            rm = it["radius"]
            look = (it["side"] * math.cos(br), 0.0, it["side"] * math.sin(br))
            pos = (rm * math.sin(br), centre[2], -rm * math.cos(br))
            cf = {"position": [round(c, 3) for c in pos], "look": [round(c, 5) for c in look],
                  "luau": "CFrame.lookAt(Vector3.new(%.3f, %.3f, %.3f), Vector3.new(%.3f, %.3f, %.3f))" % (
                      pos[0], pos[1], pos[2], pos[0] + look[0], pos[1] + look[1], pos[2] + look[2])}
            size = [ra.HAZE_RADIAL_LEN, box[2], box[1] * 0.25]
        it["cframe"] = cf
        it["meshpart_size_roblox"] = [round(c, 3) for c in size]
        places.append(it)
    table = {"pieces": {NAME: {"origin_ring_frame": ca.point(tuple(off)), "box_centre_ring_frame": ca.point(tuple(centre)),
                               "box_size": {"blender": [round(c, 3) for c in box], "roblox": [round(box[0], 3), round(box[2], 3), round(box[1], 3)]}}},
             "surface_appearance": {"ColorMap": ra.HAZE_MASK, "AlphaMode": "Transparency",
                                    "Color": {"reef": ra.FOG["reef"], "kelp": ra.FOG["kelp"]}, "note": "06 4.2 fog colours (tune by eye in Studio)"},
             "placements": places}

    # preview: five pieces in a row under Reef fog colour, and the mask as a card
    row = []
    for k, b in enumerate((-30.0, -15.0, 0.0, 15.0, 30.0)):
        c = haze.copy()
        c.name = "PV_Haze_%d" % k
        bpy.data.collections["PREVIEW"].objects.link(c)
        c.matrix_world = Matrix.Rotation(-math.radians(b), 4, 'Z') @ Matrix.Translation(off)
        c.hide_render = True
        row.append(c)
    kelp = []
    mat_k = ra.haze_material(work, ra.FOG["kelp"], "MAT_Blue_Haze_Kelp")
    for k, b in enumerate((-15.0, 0.0, 15.0)):
        c = haze.copy()
        c.data = haze.data.copy()
        c.data.materials[0] = mat_k
        c.name = "PV_HazeKelp_%d" % k
        bpy.data.collections["PREVIEW"].objects.link(c)
        c.matrix_world = Matrix.Rotation(-math.radians(b), 4, 'Z') @ Matrix.Translation(off)
        c.hide_render = True
        kelp.append(c)

    def write_table(spec, report):
        if report.ok:
            report.add(NAME, "layout table", True, ra.write_layout(table, NAME))
    return {
        "name": NAME,
        "category": "Env",
        "id": "haze",
        "budget": "haze",
        "origin": "prop",
        "size": tuple(box),
        "size_tol": 0.001,
        "facing": {"kind": "normals"},
        "meshes": [{"object": haze, "role": "body", "primary": True}],
        "extra_checks": [mask_checks(img), write_table],
        "exports": [{"file": "meshes/%s.fbx" % NAME, "objects": [haze]}],
        "textures": [{"file": "textures/%s.png" % ra.HAZE_MASK, "write": lambda path: preyart.save_rgba(path, img), "max": 256}],
        "preview": {
            "main": [haze],
            "view_captions": {"Side": ["inner face left: depth 200 to the surface"], "Top": ["15 degrees of r 980, 4 thick"]},
            "lineup": [{"label": "M_Env_Blue_Haze", "objects": [haze]},
                       {"label": "tier-7 Minnow", "objects": [bpy.data.objects["REF_Minnow_T7"]]}],
            "lineup_caption": ["Reef fog tint #1E9FD0 (preview drawn unlit)"],
            "extras": [
                {"title": "Five pieces, Reef tint, from 140 studs", "objects": row,
                 "camera": {"location": (0.0, 840.0, -60.0), "look_at": (0.0, 980.0, -80.0), "lens": 14.0},
                 "caption": ["the mask wraps: no seam between pieces", "one long fade, clear before the surface"]},
                {"title": "Kelp tint, looking along the edge", "objects": kelp,
                 "camera": {"location": (-180.0, 900.0, -70.0), "look_at": (60.0, 975.0, -90.0), "lens": 18.0},
                 "caption": ["#238A72 (06 4.2 Kelp fog)"]},
            ],
            "texture": "%s 256 x 256 RGBA: alpha mask, RGB white to 0.80 at the floor" % ra.HAZE_MASK,
        },
    }


if __name__ == "__main__":
    import run
    run.main(__file__)
