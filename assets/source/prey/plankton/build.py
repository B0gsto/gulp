"""M_Prey_Plankton with T_PreySmall_Alb: task S3-A1 (docs/13-sprint-plan.md Sprint 3; docs/07-asset-list.md
section 4 rows M_Prey_Plankton and T_PreySmall_Alb; docs/03-content-catalog.md section 2.2 plankton;
docs/06-art-bible.md 4.3, 6.2, 6.3, 13.2; docs/09-technical-architecture.md 8.8).

    Blender --background --python assets/source/prey/plankton/build.py

The plankton mote, tier 0, 0.4 studs (06 6.2): a 2-triangle camera-facing billboard (06 6.3). Its
drawn side is -Y; the client turns that side to the camera every frame (as the preview does).
The atlas holds three mote shapes (07: "a camera-facing dot in three shapes"): a round soft mote
(the mesh's UVs), a four-point twinkle and a little diatom. 03: "a soft pale-green mote that
twinkles. No face." Colours are the plankton row of 06 4.3 only: white core, #D9FFE8 body, soft
alpha edge; no dark block (the row has none) and no outline (06 13.2). Feeding Frenzy gold-white
and Moon Tide cyan are tints set by the client (07 row).
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "_shared", "blender"))

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix  # noqa: E402

import common  # noqa: E402
import meshgen  # noqa: E402
import preyart  # noqa: E402

NAME = "M_Prey_Plankton"
ALBEDO = "T_PreySmall_Alb"
LENGTH = 0.4                     # 06 6.2


def quad(name, cell, collection="GEO", material=None):
    s = LENGTH / 2.0
    verts = [(-s, 0.0, -s), (s, 0.0, -s), (s, 0.0, s), (-s, 0.0, s)]
    part = (verts, [(0, 1, 2), (0, 2, 3)], [(0.0, 0.0)] * 4)
    md = meshgen.MeshData().add_part(part, preyart.PL_MID,
                                     uv=lambda p, q: preyart.cell_uv(cell, (p[0] + s) / LENGTH, (p[2] + s) / LENGTH, margin=1))
    obj = md.to_object(name, collection, smooth=False, material=material)
    obj["gulp_billboard"] = 1
    return obj


def palette_check(img):
    """06 4.3 plankton row: every visible texel of the three motes lies between #D9FFE8 and white."""
    mid, light = preyart.rgb(preyart.PL_MID), preyart.rgb(preyart.PL_LIGHT)

    def check(spec, report):
        worst = 0.0
        seg = light - mid
        for k in "abc":
            x, y, w, h = preyart.CELLS["plankton_" + k]
            px = img[y:y + h, x:x + w]
            vis = px[..., 3] > 0.05
            c = px[vis][:, :3]
            t = np.clip(((c - mid) @ seg) / (seg @ seg), 0.0, 1.0)
            d = np.linalg.norm(c - (mid + t[:, None] * seg), axis=1)
            worst = max(worst, float(d.max()) if len(d) else 0.0)
        report.add(NAME, "palette: plankton row", worst < 0.01,
                   "every visible texel of the three motes between %s and %s (largest miss %.4f)" % (preyart.PL_MID, preyart.PL_LIGHT, worst))
    return check


def patch(material, seed=3):
    """A patch of 6 to 10 motes (03) in the three shapes, for the review sheet."""
    rnd = random.Random(seed)
    out = []
    for i in range(9):
        o = quad("PV_PlanktonPatch_%02d" % i, "plankton_" + "abc"[i % 3], "PREVIEW", material)
        a, r = rnd.uniform(0, 2 * math.pi), 1.2 * math.sqrt(rnd.random())
        o.matrix_world = Matrix.Translation((r * math.cos(a), r * math.sin(a), rnd.uniform(-0.6, 0.6)))
        out.append(o)
    return out


def build():
    img, block = preyart.atlas()
    work = os.path.join(common.review_dir(NAME), "%s_work.png" % ALBEDO)
    preyart.save_rgba(work, img)
    mat = preyart.material("MAT_" + NAME, work, alpha=True)
    body = quad(NAME, "plankton_a", material=mat)
    shapes = [quad("PV_Plankton_%s" % k.upper(), "plankton_" + k, "PREVIEW", mat) for k in "bc"]
    for i, o in enumerate(shapes):
        o.matrix_world = Matrix.Translation((0.0, 0.0, -0.6 * (i + 1)))
    crowd = patch(mat)
    return {
        "name": NAME,
        "category": "Prey",
        "id": "plankton",
        "tier": 0,
        "budget": "plankton",
        "billboard": True,
        "uv": {"texture": "prey_small_atlas"},
        "origin": "creature",
        "size": (LENGTH, 0.0, LENGTH),
        "size_tol": 0.02,
        "facing": {"kind": "billboard"},
        "meshes": [{"object": body, "role": "body", "primary": True}],
        "extra_checks": [palette_check(img)],
        "exports": [{"file": "meshes/%s.fbx" % NAME, "objects": [body]}],
        "textures": [{"file": "textures/%s.png" % ALBEDO, "write": lambda path: preyart.save_rgba(path, img), "max": 256}],
        "preview": {
            "main": [body],
            "lineup": [
                {"label": "M_Prey_Plankton and the other two shapes, 0.4 studs", "objects": [body] + shapes},
                {"label": "template tier-1 Minnow (3 studs)", "objects": [bpy.data.objects["REF_Minnow_T1"]]},
            ],
            "lineup_caption": ["every view turns the billboard to the camera, as the client does"],
            "view_captions": {v: ["billboard turned to this camera (the client does it every frame)"]
                              for v in ("Side", "ThreeQuarter", "Game", "Top")},
            "extras": [
                {"title": "Patch of 9, three shapes, game camera", "view": "Game", "objects": crowd,
                 "caption": ["03: patches of 6 to 10 that drift"]},
                {"title": "The three shapes", "view": "Front", "objects": [body] + shapes,
                 "caption": ["round mote (the mesh), twinkle, diatom"]},
            ],
            "texture": "%s %d x %d (three plankton cells), painted by script; billboard, no outline" % (ALBEDO, preyart.SIZE, preyart.SIZE),
        },
    }


if __name__ == "__main__":
    import run
    run.main(__file__)
