"""RIG_Prey3 on a tier-3 test body, with the prey distance version and shells: task S3-A1
(docs/13-sprint-plan.md Sprint 3; docs/07-asset-list.md section 4.0 rows RIG_Prey3, M_Prey_*_Shell,
M_Prey_*_LOD2; docs/06-art-bible.md 6.3, 6.4, 7.6, 13.2).

    Blender --background --python assets/source/prey/prey3/build.py

RIG_Prey3 (preyart.prey3_bones): an unweighted Root at the origin and three sway bones, Spine1,
Spine2 and TailFin, for the fish-shaped prey of tier 3 and up; the same sway code as the players
moves them (06 7.6), and no prey has a clip (07 4). The skeleton travels inside each prey's mesh
file (07 1.3), so this build carries it on a plain test body at the Reef Darter's 2.4 studs
(06 6.2), source only and not the Darter art (a later row). It proves the prey path of the
shell and lod steps on a boned prey (versions.py):
  M_Prey_Base_Prey3            skinned to RIG_Prey3, inside the tier-3 budget of 300 triangles
  M_Prey_Base_Prey3_Shell      skinned, 10% of body height, 120 triangles (06 6.3)
  M_Prey_Base_Prey3_LOD2       a quarter of the triangles, rigid (06 6.4: whole-body wobble only)
  M_Prey_Base_Prey3_LOD2_Shell rigid, 80 triangles or a quarter of the LOD0 shell, whichever is more
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "_shared", "blender"))

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402
import meshgen  # noqa: E402
import preyart  # noqa: E402

NAME = "M_Prey_Base_Prey3"
LENGTH = 2.4                      # 06 6.2: darter
LIGHT, MID, DARK, ACCENT = (common.colour("creatures.darter." + k) for k in ("light", "mid", "dark", "accent"))
RINGS, SEGS = 10, 10
Y0, Y1 = -1.2, 0.86               # nose to the tail root


def half_h(t):
    return 0.52 * math.sin(math.pi * min(1.0, 0.08 + 0.92 * t)) ** 0.75 + 0.05


def body_part():
    rings = []
    for k in range(RINGS):
        t = (k + 1) / (RINGS + 1)
        y = Y0 + (Y1 - Y0) * t
        h = half_h(t) * (1.0 - 0.55 * t * t)
        w = 0.42 * h
        rings.append([(w * math.cos(a), y, h * math.sin(a) + 0.04 * (1 - t)) for a in
                      (math.radians(90.0 + 360.0 * j / SEGS) for j in range(SEGS))])
    return meshgen.loft(rings, (0.0, Y0, 0.05), (0.0, Y1, 0.0))


def fin(outline, half):
    n = len(outline)
    verts = [(half, y, z) for y, z in outline] + [(-half, y, z) for y, z in outline]
    tris = [(0, i, i + 1) for i in range(1, n - 1)]
    faces = tris + [tuple(n + i for i in reversed(t)) for t in tris]
    faces += [(i, n + i, n + (i + 1) % n, (i + 1) % n) for i in range(n)]
    return verts, faces, [(0.0, 0.0)] * len(verts)


def build():
    arm = meshgen.build_armature("RIG_Prey3", preyart.prey3_bones(LENGTH))
    weights = preyart.prey3_weights(LENGTH)
    md = meshgen.MeshData()
    md.add_part(body_part(), lambda p, q: LIGHT if p.z < -0.12 else MID, weights=weights)
    md.add_part(fin([(0.74, 0.0), (1.2, 0.42), (1.08, 0.0), (1.2, -0.42)], 0.03), DARK, weights=weights)
    md.add_part(fin([(-0.35, 0.40), (-0.05, 0.78), (0.35, 0.30)], 0.03), ACCENT, weights=weights)
    body = meshgen.skin(md.to_object(NAME, "GEO"), arm)
    vs = body.data.vertices
    lo = Vector([min(v.co[i] for v in vs) for i in range(3)])
    hi = Vector([max(v.co[i] for v in vs) for i in range(3)])
    c = (lo + hi) / 2.0
    body.data.transform(Matrix.Translation((0.0, -c.y, -c.z)))
    size = hi - lo
    poses = [("Sway, phase %d of 3" % (i + 1), "Top", preyart.sway_pose(2.0 * math.pi * i / 3.0)) for i in range(3)]
    return {
        "name": NAME,
        "category": "Prey",
        "id": "prey3",
        "tier": 3,
        "budget": "prey_t3",
        "rig": "Prey3",
        "armature": arm,
        "origin": "creature",
        "size": (size.x, size.y, size.z),
        "size_tol": 0.02,
        "facing": {"kind": "bones", "front": "Spine1", "back": "TailFin"},
        "meshes": [{"object": body, "role": "body", "primary": True}],
        "exports": [{"file": "meshes/%s.fbx" % NAME, "objects": [body, arm]}],
        "preview": {
            "main": [body],
            "lineup": [
                {"label": "RIG_Prey3 test body, 2.4 studs", "objects": [body]},
                {"label": "template tier-1 Minnow (3 studs)", "objects": [bpy.data.objects["REF_Minnow_T1"]]},
            ],
            "lineup_caption": ["test body for the rig, shells and distance version; not the Darter art"],
            "extras": [{"title": t, "view": v, "pose": p, "caption": ["06 7.6 code sway on three bones, seen from above"]}
                       for t, v, p in poses],
            "texture": "none (vertex colour, darter palette; rig test body, source only)",
        },
    }


if __name__ == "__main__":
    import run
    run.main(__file__)
