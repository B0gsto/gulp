"""M_Prop_HatchEgg on T_Cove_Alb: task S6-A2 (docs/13-sprint-plan.md Sprint 6; docs/07-asset-list.md
section 2.0 row M_Prop_HatchEgg: "the pale egg a new Fry hatches from, on the Hatch Bed in the
Nursery and on the Home Stone in a cove. Whole egg and two cracked halves", 200 tris; the beat is
docs/04-first-two-minutes.md 3.6 B1; look docs/06-art-bible.md 4.1, 5.6, 6.1, 15.5, 16.1).

    Blender --background --python assets/source/cove/hatchegg/build.py

A pale lilac egg with a full bottom and a slight lean, a lit cream crown, big plum spots with a glint
on each rim and three small apricot freckles, 2.6 across and 3.3 tall (eggart.py has the shape, the
paint and the reasons). Three closed meshes in one FBX, so the upload is one Model with three
MeshParts in place:
  M_Prop_HatchEgg         the whole egg, 180 tris (15 round, 6 rings)
  M_Prop_HatchEgg_Top     the cap above the uneven zigzag crack, open into its dark inside, 60 tris
  M_Prop_HatchEgg_Bottom  the cup below it, 120 tris
The two halves are never on screen with the whole egg (the code swaps it for them on the crack),
so the scene holds at most 180 triangles at a time: inside the row's 200 either way.

All three share one frame: origin at the bottom pole (06 6.1, the centre of the base), +Z up, the
front (-Y) the way the Fry faces as it hatches (the Hatch Bed's look vector, 03 6.2). The paint is
a third of the shell repeated round it (overlapping UVs, like the cove's tiled cells) in the last
free corner of T_Cove_Alb (coveart.CELLS egg_*), so it reaches the cove kit's 24 px/stud (06 5.6).

The hatch in the game (04 B1; code task S6-C2), timed to A_Fish_Hatch (45 frames, rigs.py; the
numbers are chapter 14 section 5.1's): the whole egg rocks twice on its round base, each rock
after a squash (+8 degrees on frame 5, -8 on frame 11); from frame 8 the code shows the two halves
closed, the crack showing and the cap lifting; on frame 15 the cap flips off backwards and falls
away, and the cup springs and rocks once and stays. The Fry's model sits at its swim spot ahead of
the egg (rigs.HATCH_EGG_AT) for the whole clip; the clip carries the body out of the egg to it.
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
FRY_AT = tuple(-c for c in __import__("rigs").HATCH_EGG_AT)   # the Fry's model in the egg's frame (tune, 14 5.1)
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
                   "(06 5.6 cove props); the inside is one flat colour under a lit band" % (d, ca.SIZE))
        report.add(NAME, "texture size", True, "%s %d x %d, the cove kit's one atlas (06 5.6), cells %s"
                   % (ca.ALBEDO, ca.SIZE, ca.SIZE, ", ".join(CELLS.values())))
        blocks = ca.visible_values([top, bottom], sample)
        report.add(NAME + " halves", "value (for the record)", True,
                   "; ".join("%s %.0f%% L* %.0f" % (b["block"], b["share"], b["lstar"]) for b in blocks) +
                   ": outside and inside together; the inside of a broken shell is the dark block, seen for under a second "
                   "as the halves fall away. The whole egg carries the 06 4.1 shares (rows above)")
        fry = bpy.data.objects["REF_Minnow_T1"]
        pts = [fry.matrix_world.to_3x3() @ v.co for v in fry.data.vertices]      # about its own origin
        y_back = max(p.y for p in pts) + FRY_AT[1]
        z_low = min(p.z for p in pts) + FRY_AT[2]
        front = min(v.co.y for v in bottom.data.vertices)
        rim = max(v.co.z for v in bottom.data.vertices)
        report.add(NAME, "Fry clears the cup", y_back < front or z_low > rim,
                   "the Fry at its swim spot (%.2f ahead of the base, %.2f up): its tail end %.2f ahead of the cup's front, "
                   "its belly %.2f above the bed (cup rim at most %.2f)" % (-FRY_AT[1], FRY_AT[2], front - y_back, z_low, rim))
        report.add(NAME, "rolls on its base", abs(eggart.base_radius() - __import__("rigs").HATCH_EGG_ROLL) < 0.03,
                   "base radius %.3f, the rock's roll radius %.3f (rigs.HATCH_EGG_ROLL)" % (eggart.base_radius(),
                                                                                       __import__("rigs").HATCH_EGG_ROLL))
    return check


def build():
    img, block, work = ca.texture(NAME)
    mat = ca.material("MAT_" + NAME, work)
    objs = eggart.to_objects(ca, mat, NAMES, CELLS)
    whole, top, bottom = objs["whole"], objs["top"], objs["bottom"]
    sample = ca.sampler(img, block)

    # Preview set: the halves closed on the crack (frame 11, mid-rock), and the cap thrown off with
    # the Fry at its swim spot once it has swum out (frame 45).
    closed = {k: _copy(o, "PV_%s_Closed" % k, eggart.throw_matrices(11.0)[k]) for k, o in (("top", top), ("bottom", bottom))}
    cap_off = _copy(top, "PV_Top_Off", eggart.throw_matrices(24.0)["top"])
    fry = _copy(bpy.data.objects["REF_Minnow_T1"], "PV_Fry", Matrix.Translation(FRY_AT))
    fry.hide_render = False
    apart = _copy(top, "PV_Top_Apart", Matrix.Translation((0.0, 0.0, 0.9)))
    cam8 = {"location": (2.4, -7.4, 0.9), "look_at": (0.0, 0.0, 1.5), "lens": 35.0}   # 04 B1: 8 studs from the egg, low

    return {
        "name": NAME,
        "category": "Prop",
        "id": "hatchegg",
        "budget": "hatch_egg",
        "origin": "prop",
        "size": eggart.extent(),
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
            "blocks": {"mid": eggart.MID_LOW, "light": eggart.CROWN, "dark": eggart.SPOT, "accent": eggart.ACCENT},
            "view_captions": {"Side": ["front (-Y) on the left"]},
            "lineup": [
                {"label": "egg %.1f x %.1f" % (eggart.W, eggart.H), "objects": [whole]},
                {"label": "halves", "objects": [apart, bottom]},
                {"label": "Fry, 3.0", "objects": [bpy.data.objects["REF_Minnow_T1"]]},
            ],
            "lineup_caption": ["the only egg; pebbles (06 9.2) are grey and flat"],
            "extras": [
                {"title": "Cracked (f11)", "view": "ThreeQuarter", "objects": list(closed.values()),
                 "caption": ["halves closed, cap lifting", "uneven zigzag crack"]},
                {"title": "Fry out (f45)", "view": "Side", "objects": [bottom, cap_off, fry],
                 "caption": ["cap thrown off (code, S6-C2)", "Fry %.1f ahead, %.2f up (ink stand-in)" % (-FRY_AT[1], FRY_AT[2])]},
                {"title": "B1 shot", "objects": [whole], "camera": cam8,
                 "caption": ["8 studs from the egg, low"]},
            ],
            "texture": "%s %d x %d: egg cells (a third of the shell on its side, repeated round it; the inside with its lit edge), painted by script"
                       % (ca.ALBEDO, ca.SIZE, ca.SIZE),
        },
    }


if __name__ == "__main__":
    import run
    run.main(__file__)
