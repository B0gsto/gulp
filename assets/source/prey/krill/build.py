"""M_Prey_Krill with T_PreySmall_Alb and its outline shell M_Prey_Krill_Shell: task S3-A1
(docs/13-sprint-plan.md Sprint 3; docs/07-asset-list.md section 4 rows M_Prey_Krill, T_PreySmall_Alb,
M_Prey_*_Shell; docs/03-content-catalog.md section 2.2 krill; docs/06-art-bible.md 4.1, 4.3, 6.2 to
6.4, 13.2; docs/09-technical-architecture.md 8.8).

    Blender --background --python assets/source/prey/krill/build.py

Krill, tier 1, 0.8 studs long (06 6.2): a pink-orange comma (03), round blunt head with two big
black eyes that stand out past the head so they read from above, a back that arches and a tail
that curls down into a small three-point fan, and a fringe of legs under the belly drawn as one
dark comb, so the silhouette says "busy little shrimp-thing" even at 20 pixels. Rigid, no bones
(07 4: the client wobbles the whole mesh and the swarm's motion does the rest; 09 8.8 pools it).

Colour (06 4.1, 4.3 krill row): mid #FF8C7A body, light #FFD9CC belly, dark block the interface
ink (06 4.6) on the eyes and the leg fringe, and the krill row's #C24A4A as a thin accent (segment
bands on the back, the tail-fan rim). The krill row's dark #C24A4A is L* 48, over 4.1's 35 for a
dark block, so it cannot be the dark block; it is used as the accent and the owner is told.

The shell (run.py step shell, versions.py) is 10% of body height (06 13.2) with the 06 6.3
tier-1 budget of 64 triangles. No LOD (06 6.4: prey under tier 3 ship one mesh).
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "_shared", "blender"))

import bpy  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

import common  # noqa: E402
import meshgen  # noqa: E402
import preyart  # noqa: E402

NAME = "M_Prey_Krill"
ALBEDO = "T_PreySmall_Alb"
LENGTH = 0.8                     # 06 6.2
SEGS = 6                         # around the body; a vertex on the back ridge and the belly
RING_T = (0.07, 0.24, 0.45, 0.66, 0.84)
TAIL_T = 0.97


# ---------------------------------------------------------------- shape: a comma along a curved spine

def spine(t):
    """(y, z) of the body's centre line; nose on -Y, the tail drops into the comma."""
    return -0.40 + 0.70 * t, 0.05 - 0.13 * t * t


def tangent(t):
    return 0.70, -0.26 * t


def radius(t):
    head = float(preyart.smooth(-0.15, 0.25, t)) ** 0.5
    return 0.12 * head * (1.0 - 0.72 * float(preyart.smooth(0.30, 1.0, t)))


def up(t):
    dy, dz = tangent(t)
    n = math.hypot(dy, dz)
    return -dz / n, dy / n           # (y, z) of the ring's up direction


def ring(t):
    cy, cz = spine(t)
    uy, uz = up(t)
    r = radius(t)
    out = []
    for k in range(SEGS):
        a = math.radians(90.0 + 360.0 * k / SEGS)
        out.append((0.85 * r * math.cos(a), cy + r * math.sin(a) * uy, cz + r * math.sin(a) * uz))
    return out


def belly(y):
    t = min(max((y + 0.40) / 0.70, 0.0), TAIL_T)
    return spine(t)[1] - radius(t)


def profile(y):
    """(z_back, z_belly, z_centre, z_legs_top) at y, for the painter."""
    t = min(max((y + 0.40) / 0.70, 0.0), 1.0)
    cz, r = spine(min(t, TAIL_T))[1], max(radius(min(t, TAIL_T)), 0.03)
    legs_top = belly(y) - 0.004 if -0.27 <= y <= 0.13 else -9.0
    return cz + r, cz - r, cz, legs_top


def body_part():
    rings = [ring(t) for t in RING_T]
    ny, nz = spine(0.0)
    ty, tz = spine(TAIL_T)
    return meshgen.loft(rings, (0.0, ny, nz), (0.0, ty, tz))


def extrude(outline, tris, half):
    """Closed slab of an (y, z) outline, `half` either side of x = 0; `tris` index the outline."""
    n = len(outline)
    verts = [(half, y, z) for y, z in outline] + [(-half, y, z) for y, z in outline]
    faces = [tuple(t) for t in tris] + [tuple(n + i for i in reversed(t)) for t in tris]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, n + i, n + j, j))
    return verts, faces, [(0.0, 0.0)] * len(verts)


def legs_part():
    """The leg fringe: one comb under the belly, three teeth swept back (03: feathery legs)."""
    ya, yb = -0.26, 0.10
    tips = (-0.20, -0.08, 0.04)
    notches = (-0.14, -0.02)
    A0 = (ya, belly(ya) + 0.035)
    A3 = (yb, belly(yb) + 0.035)
    B = [(y + 0.03, belly(y) - (0.09 - 0.01 * i)) for i, y in enumerate(tips)]
    N = [(y, belly(y) - 0.062) for y in notches]
    outline = [A0, B[0], N[0], B[1], N[1], B[2], A3]
    tris = [(0, 1, 2), (2, 3, 4), (4, 5, 6), (0, 2, 4), (0, 4, 6)]
    return extrude(outline, tris, 0.04)


def tail_part():
    """Three-point tail fan behind the curled tail tip."""
    outline = [(0.24, -0.045), (0.40, -0.04), (0.365, -0.10), (0.38, -0.17), (0.25, -0.10)]
    tris = [(0, 1, 2), (0, 2, 4), (2, 3, 4)]
    return extrude(outline, tris, 0.026)


EYE_C, EYE_R = (0.086, -0.295, 0.085), 0.05


def eye_part(side):
    c = (side * EYE_C[0], EYE_C[1], EYE_C[2])
    return meshgen.sphere(c, EYE_R, (side, 0.0, 0.0), (0.0, 0.0, 1.0), 4, 1)


def eye_uv(p, q):
    return preyart.krill_eye_uv(0.5 + (p[1] - EYE_C[1]) / (2.2 * EYE_R), 0.5 + (p[2] - EYE_C[2]) / (2.2 * EYE_R))


def krill_meshdata():
    md = meshgen.MeshData()
    side_uv = lambda p, q: preyart.krill_body_uv(p)
    md.add_part(body_part(), preyart.KR_MID, uv=side_uv)
    md.add_part(legs_part(), preyart.INK, uv=side_uv)
    md.add_part(tail_part(), preyart.KR_MID, uv=side_uv)
    for side in (1.0, -1.0):
        md.add_part(eye_part(side), preyart.INK, uv=eye_uv, tag=common.TAG_FRONT)
    return md


def recentre(obj):
    """Origin at the middle of length and height (06 6.1); the mesh only moves, UVs stay."""
    vs = obj.data.vertices
    lo = Vector([min(v.co[i] for v in vs) for i in range(3)])
    hi = Vector([max(v.co[i] for v in vs) for i in range(3)])
    c = (lo + hi) / 2.0
    c.x = 0.0
    obj.data.transform(Matrix.Translation(-c))
    obj.data.update()
    return hi - lo


# ---------------------------------------------------------------- preview helpers

def swarm(body, count=16, seed=7):
    """A swarm of 12 to 20 (03) for the review sheet: copies sharing the mesh, each with the
    client's wobble (09 8.8: yaw within 12 degrees and a roll)."""
    rnd = random.Random(seed)
    out = []
    for i in range(count):
        o = body.copy()
        o.name = "PV_KrillSwarm_%02d" % i
        bpy.data.collections["PREVIEW"].objects.link(o)
        a, r = rnd.uniform(0, 2 * math.pi), 1.6 * math.sqrt(rnd.random())
        o.matrix_world = Matrix.Translation((r * math.cos(a), r * math.sin(a) * 0.8, rnd.uniform(-0.5, 0.5))) @ \
            Euler((math.radians(rnd.uniform(-8, 8)), math.radians(rnd.uniform(-10, 10)),
                   math.radians(18.0 + rnd.uniform(-12, 12))), 'XYZ').to_matrix().to_4x4()
        out.append(o)
    return out


# ---------------------------------------------------------------- the asset

def build():
    img, block = preyart.atlas(krill_profile=profile)
    work = os.path.join(common.review_dir(NAME), "%s_work.png" % ALBEDO)
    preyart.save_rgba(work, img)
    md = krill_meshdata()
    body = md.to_object(NAME, "GEO", material=preyart.material("MAT_" + NAME, work))
    size = recentre(body)
    print("[krill] size x %.3f y %.3f z %.3f" % tuple(size))

    blocks = {"mid": preyart.KR_MID, "light": preyart.KR_LIGHT, "dark": preyart.INK, "accent": preyart.KR_DARK}
    crowd = swarm(body)
    return {
        "name": NAME,
        "category": "Prey",
        "id": "krill",
        "tier": 1,
        "budget": "prey_t1",
        "uv": {"texture": "prey_small_atlas"},
        "origin": "creature",
        "size": (size.x, LENGTH, size.z),
        "size_tol": 0.02,
        "facing": {"kind": "tag"},
        "meshes": [{"object": body, "role": "body", "primary": True}],
        "texture_sampler": preyart.sampler(block)(img),
        "texture_name": "%s krill cells, painted by script" % ALBEDO,
        "exports": [{"file": "meshes/%s.fbx" % NAME, "objects": [body]}],
        "textures": [{"file": "textures/%s.png" % ALBEDO, "write": lambda path: preyart.save_rgba(path, img), "max": 256}],
        "preview": {
            "main": [body],
            "blocks": blocks,
            "lineup": [
                {"label": "M_Prey_Krill, 0.8 studs", "objects": [body]},
                {"label": "template tier-1 Minnow (3 studs)", "objects": [bpy.data.objects["REF_Minnow_T1"]]},
            ],
            "lineup_caption": ["03 2.2: pink-orange comma, two black dot eyes, feathery legs"],
            "extras": [
                {"title": "Swarm of 16, game camera", "view": "Game", "objects": crowd,
                 "caption": ["03: swarms of 12 to 20; 09 8.8 wobble: yaw within 12 degrees and a roll"]},
                {"title": "Swarm of 16, side", "view": "Side", "objects": crowd},
                {"title": "Front", "view": "Front", "objects": [body], "caption": ["eyes stand out past the head"]},
            ],
            "texture": "%s %d x %d (krill cells), painted by script; rigid, no bones" % (ALBEDO, preyart.SIZE, preyart.SIZE),
        },
    }


if __name__ == "__main__":
    import run
    run.main(__file__)
