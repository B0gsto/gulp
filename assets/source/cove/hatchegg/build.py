"""M_Prop_HatchEgg on T_Cove_Alb: task S6-A2 (docs/13-sprint-plan.md Sprint 6; docs/07-asset-list.md
section 2.0 row M_Prop_HatchEgg: "the pale egg a new Fry hatches from, on the Hatch Bed in the
Nursery and on the Home Stone in a cove. Whole egg and two cracked halves", 200 tris; the beat is
docs/04-first-two-minutes.md 3.6 B1; look docs/06-art-bible.md 4.1, 5.6, 6.1, 15.5, 16.1).

    Blender --background --python assets/source/cove/hatchegg/build.py

A pale lilac egg with a lit cream crown and soft plum freckles, 2.6 across and 3.3 tall (eggart.py
has the shape, the paint and the reasons). Three closed meshes in one FBX, so the upload is one
Model with three MeshParts in place:
  M_Prop_HatchEgg         the whole egg, 192 tris
  M_Prop_HatchEgg_Top     the cap above the zigzag crack (six teeth), with its broken edge and inside, 72 tris
  M_Prop_HatchEgg_Bottom  the cup below it, 120 tris
The two halves are never on screen with the whole egg (the code swaps it for them on the crack),
so the scene holds 192 triangles at a time: inside the row's 200 either way.

All three share one frame: origin at the bottom pole (06 6.1, the centre of the base), +Z up, the
front (-Y) the way the Fry faces as it hatches (the Hatch Bed's look vector, 03 6.2). The paint is
a third of the shell repeated round it (overlapping UVs, like the cove's tiled cells) in the last
free corner of T_Cove_Alb (coveart.CELLS egg_*), so it reaches the cove kit's 24 px/stud (06 5.6).

The hatch in the game (04 B1; code task S6-C2), timed to A_Fish_Hatch (45 frames, rigs.py):
frames 0-13 the whole egg wobbles twice on its base with the Fry's two wriggles (about 8 degrees,
peaks on frames 4 and 10); frame 15 it is swapped for the halves, the cap flips off backwards and
falls away, the cup rocks once and stays; the Fry's model sits HATCH_FRY_ABOVE_BASE studs above the
egg's base for the whole clip (the clip lowers the body into the egg and raises it out, Root still).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

import coveart as ca  # noqa: E402  (puts _shared/blender on the path)
import eggart  # noqa: E402

import bpy  # noqa: E402
from mathutils import Matrix  # noqa: E402

import common  # noqa: E402
import template  # noqa: E402

NAME = "M_Prop_HatchEgg"
NAMES = {"whole": NAME, "top": NAME + "_Top", "bottom": NAME + "_Bottom"}
CELLS = eggart.CELLS
HATCH_FRY_ABOVE_BASE = eggart.fry_above_base()      # 3.10: where the code puts the Fry's model (tune)
PAIR_BUDGET = 200                                  # 07 row: the two halves together, on screen at once


def _copy(obj, name, matrix):
    """A preview-only copy (shares the mesh), placed by `matrix`; never exported."""
    o = obj.copy()
    o.name = name
    template.link(o, "PREVIEW")
    o.matrix_world = matrix
    return o


def _shell_density(objs):
    """Pixels per stud over the painted outside (faces mapped into the shell cell), overlaps counted."""
    x0, y0, x1, y1 = ca.CELLS[CELLS["shell"]]
    u0, u1, v0, v1 = x0 / ca.SIZE, x1 / ca.SIZE, 1.0 - y1 / ca.SIZE, 1.0 - y0 / ca.SIZE
    a3 = auv = 0.0
    for obj in objs:
        mesh = obj.data
        mesh.calc_loop_triangles()
        uvs = mesh.uv_layers[common.UV_NAME].data
        for tri in mesh.loop_triangles:
            c = [tuple(uvs[li].uv) for li in tri.loops]
            if not all(u0 <= u <= u1 and v0 <= v <= v1 for u, v in c):
                continue
            (a, b), (p, q), (r, s) = c
            auv += abs((p - a) * (s - b) - (r - a) * (q - b)) / 2.0
            a3 += tri.area
    return (auv * ca.SIZE * ca.SIZE / a3) ** 0.5 if a3 else 0.0


def egg_checks(whole, top, bottom, sample):
    def check(spec, report):
        tris = [len(o.data.loop_triangles) for o in (top, bottom)]
        report.add(NAME, "halves: triangles together", sum(tris) <= PAIR_BUDGET,
                   "%d + %d = %d of %d (07 row; never on screen with the whole egg)" % (tris[0], tris[1], sum(tris), PAIR_BUDGET))
        d = _shell_density([whole, top, bottom])
        report.add(NAME, "texel density", d >= 24.0, "%.1f px/stud on the painted outside at %d px, target 24 or more "
                   "(06 5.6 cove props); the inside and the broken edge are one flat colour each" % (d, ca.SIZE))
        report.add(NAME, "texture size", True, "%s %d x %d, the cove kit's one atlas (06 5.6), cells %s"
                   % (ca.ALBEDO, ca.SIZE, ca.SIZE, ", ".join(CELLS.values())))
        blocks = ca.visible_values([top, bottom], sample)
        report.add(NAME + " halves", "value (for the record)", True,
                   "; ".join("%s %.0f%% L* %.0f" % (b["block"], b["share"], b["lstar"]) for b in blocks) +
                   ": outside and inside together; the inside of a broken shell is the dark block, seen for under a second "
                   "as the halves fall away. The whole egg carries the 06 4.1 shares (rows above)")
        lo = min(v.co.z for v in bottom.data.vertices)
        rim = max(v.co.z for v in bottom.data.vertices)
        belly = HATCH_FRY_ABOVE_BASE - 1.365 / 2.0
        report.add(NAME, "Fry clears the cup", lo > -1e-4 and belly > rim,
                   "cup rim at most %.2f; the risen Fry's belly at %.2f (model %.2f above the base, 06 6.2 height 1.365)"
                   % (rim, belly, HATCH_FRY_ABOVE_BASE))
    return check


def build():
    img, block, work = ca.texture(NAME)
    mat = ca.material("MAT_" + NAME, work)
    objs = eggart.to_objects(ca, mat, NAMES, CELLS)
    whole, top, bottom = objs["whole"], objs["top"], objs["bottom"]
    sample = ca.sampler(img, block)

    # Preview set: the halves as the code throws them on the crack (cap flipped off backwards, cup
    # rocked), and the Fry's place once it has risen out.
    cap_off = _copy(top, "PV_Top_Off", eggart.throw_matrices(24.0)["top"])
    cup_rock = _copy(bottom, "PV_Bottom_Rock", eggart.throw_matrices(17.0)["bottom"])
    fry = _copy(bpy.data.objects["REF_Minnow_T1"], "PV_Fry", Matrix.Translation((0.0, 0.0, HATCH_FRY_ABOVE_BASE)))
    fry.hide_render = False
    apart = _copy(top, "PV_Top_Apart", Matrix.Translation((0.0, 0.0, 0.5)))
    cam8 = {"location": (2.4, -7.4, 0.9), "look_at": (0.0, 0.0, 1.5), "lens": 35.0}   # 04 B1: 8 studs from the egg, low

    return {
        "name": NAME,
        "category": "Prop",
        "id": "hatchegg",
        "budget": "hatch_egg",
        "origin": "prop",
        "size": (eggart.W, eggart.W, eggart.H),
        "size_tol": 0.02,
        "facing": {"kind": "tag"},
        "meshes": [{"object": whole, "role": "body", "primary": True},
                   {"object": top, "role": "body"},
                   {"object": bottom, "role": "body"}],
        "texture_sampler": sample,
        "texture_name": ca.ALBEDO,
        "extra_checks": [egg_checks(whole, top, bottom, sample)],
        "exports": [{"file": "meshes/%s.fbx" % NAME, "objects": [whole, top, bottom]}],
        "textures": [{"file": "textures/%s.png" % ca.ALBEDO, "write": lambda path: __import__("preyart").save_rgba(path, img), "max": 512}],
        "preview": {
            "main": [whole],
            "blocks": {"mid": eggart.MID_LOW, "light": eggart.CROWN, "dark": eggart.SPOT},
            "view_captions": {"Side": ["front (-Y, the way the Fry faces) on the left"]},
            "lineup": [
                {"label": "M_Prop_HatchEgg (whole), %.1f x %.1f" % (eggart.W, eggart.H), "objects": [whole]},
                {"label": "_Top and _Bottom, opened 0.5 apart", "objects": [apart, bottom]},
                {"label": "tier-1 Minnow, 3.0 long (the Fry)", "objects": [bpy.data.objects["REF_Minnow_T1"]]},
            ],
            "lineup_caption": ["no look-alike: the only egg; round pebbles (06 9.2) are grey and flat"],
            "extras": [
                {"title": "Cracked: the cap flips off (frame 15)", "view": "ThreeQuarter", "objects": [cap_off, cup_rock],
                 "caption": ["preview of the code's throw (S6-C2)", "zigzag crack, lit edge, dark inside"]},
                {"title": "The Fry out (frame 18 on)", "view": "Side", "objects": [cup_rock, cap_off, fry],
                 "caption": ["Fry model %.2f above the egg's base" % HATCH_FRY_ABOVE_BASE, "(ink stand-in at rest)"]},
                {"title": "04 B1 opening shot: 8 studs, low", "objects": [whole], "camera": cam8,
                 "caption": ["camera 8 studs from the egg, low"]},
            ],
            "texture": "%s %d x %d: egg cells (a third of the shell, repeated round it; inside; edge), painted by script"
                       % (ca.ALBEDO, ca.SIZE, ca.SIZE),
        },
    }


if __name__ == "__main__":
    import run
    run.main(__file__)
