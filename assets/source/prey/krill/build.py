"""M_Prey_Krill with T_PreySmall_Alb and its outline shell M_Prey_Krill_Shell: task S3-A1
(docs/13-sprint-plan.md Sprint 3; docs/07-asset-list.md section 4 rows M_Prey_Krill, T_PreySmall_Alb,
M_Prey_*_Shell; docs/03-content-catalog.md section 2.2 krill; docs/06-art-bible.md 4.1, 4.3, 6.2 to
6.4, 13.2; docs/09-technical-architecture.md 8.8).

    Blender --background --python assets/source/prey/krill/build.py

Krill, tier 1, 0.8 studs long (06 6.2), a pink-orange comma (03): a thick carapace with a round
front, then a tapered abdomen that arches and curls down under itself, ending in a spread fan
telson. Two big dark eyes on stalks stick out forward and to the sides, so the head reads from
the side and from above. Under the carapace hangs the feathery leg fringe (03): a dark comb of
three swept-back teeth. It must read as krill and not as a small fish from the side, alone and
in a side-view swarm, at 20 pixels (06 16.1 lines 1 and 14). Rigid, no bones (07 4: the client
wobbles the whole mesh and the swarm's motion does the rest; 09 8.8 pools it).

Colour (06 4.1, 4.3 krill row): mid #FF8C7A body, light #FFD9CC belly band, dark #952028 (L* 33)
on the eyes, the leg fringe and the abdomen's segment bands. White eye glints. No accent.

The shell (run.py step shell, versions.py) is 10% of body height (06 13.2), 80 triangles at most
(06 6.3, tier 1). No LOD (06 6.4: prey under tier 3 ship one mesh).
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
ARC = 0.86                       # spine length before the model is scaled to LENGTH
SEGS = 5                         # around the body: a vertex on the back ridge, a flat belly
RING_U = (0.06, 0.24, 0.45, 0.66, 0.85)
TAIL_U = 0.97
CURL = 92.0                      # degrees the abdomen turns down by its tip


# ---------------------------------------------------------------- the curved spine

def theta(u):
    return math.radians(CURL) * float(preyart.smooth(0.3, 1.0, u)) ** 1.3


def spine(u, steps=200):
    """(y, z) of the spine at u (0 nose, 1 tail tip): straight carapace, then the curl."""
    y = z = 0.0
    n = max(1, int(steps * u))
    for i in range(n):
        th = theta((i + 0.5) / n * u)
        y += math.cos(th) * ARC * u / n
        z -= math.sin(th) * ARC * u / n
    return y, z


def direction(u):
    th = theta(u)
    return math.cos(th), -math.sin(th)


def up(u):
    th = theta(u)
    return math.sin(th), math.cos(th)


def radius(u):
    head = float(preyart.smooth(-0.12, 0.2, u)) ** 0.5
    return 0.118 * head * (1.0 - 0.74 * float(preyart.smooth(0.32, 1.0, u)))


def at(u, along=0.0, out=0.0):
    """Point on the spine plane: `along` the spine direction, `out` along its up."""
    (y, z), (dy, dz), (uy, uz) = spine(u), direction(u), up(u)
    return y + along * dy + out * uy, z + along * dz + out * uz


def ring(u):
    r = radius(u)
    out = []
    for k in range(SEGS):
        a = math.radians(90.0 + 360.0 * k / SEGS)
        y, z = at(u, 0.0, r * math.sin(a))
        out.append((0.85 * r * math.cos(a), y, z))
    return out


# ---------------------------------------------------------------- parts

def body_part():
    ny, nz = spine(0.0)
    ty, tz = spine(TAIL_U)
    return meshgen.loft([ring(u) for u in RING_U], (0.0, ny, nz), (0.0, ty, tz))


def body_uv(p, q):
    return preyart.krill_body_uv(q[0], min(1.0, (1.0 - q[1] - 0.2) / 0.8) if q[0] > 0.0 and q[0] < 1.0 else 1.0)


def extrude(outline, tris, half):
    """Closed slab of an (y, z) outline, `half` either side of x = 0; `tris` index the outline."""
    n = len(outline)
    verts = [(half, y, z) for y, z in outline] + [(-half, y, z) for y, z in outline]
    faces = [tuple(t) for t in tris] + [tuple(n + i for i in reversed(t)) for t in tris]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, n + i, n + j, j))
    return verts, faces, [(0.0, 0.0)] * len(verts)


def belly(u, drop):
    return at(u, 0.0, -radius(u) - drop)


LEG_U = (0.12, 0.52)


def legs_part():
    """The feathery leg fringe (03): a comb under the carapace, three teeth swept back."""
    A0, A3 = belly(LEG_U[0], -0.035), belly(LEG_U[1], -0.03)
    tips = [(0.19, 0.105), (0.31, 0.10), (0.43, 0.088)]
    B = [(lambda p: (p[0] + 0.035, p[1]))(belly(u, d)) for u, d in tips]
    N = [belly(u, 0.035) for u in (0.25, 0.37)]
    outline = [A0, B[0], N[0], B[1], N[1], B[2], A3]
    tris = [(0, 1, 2), (2, 3, 4), (4, 5, 6), (0, 2, 4), (0, 4, 6)]
    return extrude(outline, tris, 0.042)


def legs_uv(p, q):
    lo = min(LEG_DROP)
    return preyart.krill_part_uv("legs", 0.5, (p[2] - lo) / 0.1)


LEG_DROP = [0.0]


def telson_part():
    """The tail fan, spread in the side plane past the curled tip."""
    u = TAIL_U
    pts = [at(u, -0.03, 0.022), at(u, 0.105, 0.07), at(u, 0.14, 0.0), at(u, 0.105, -0.07), at(u, -0.03, -0.022)]
    return extrude(pts, [(0, 1, 2), (0, 2, 4), (2, 3, 4)], 0.022)


def telson_uv(p, q):
    ty, tz = spine(TAIL_U)
    dy, dz = direction(TAIL_U)
    return preyart.krill_part_uv("telson", 0.5, ((p[1] - ty) * dy + (p[2] - tz) * dz + 0.03) / 0.17)


EYE_U = 0.08
EYE_R = 0.045


def eye_axis(side):
    v = Vector((side * 0.78, -0.5, 0.38)).normalized()
    return v


def eye_base(side):
    y, z = at(EYE_U, 0.0, 0.04)
    return Vector((side * 0.045, y, z))


def eye_centre(side):
    return eye_base(side) + eye_axis(side) * 0.085


def eye_part(side):
    """A stalk and a big eye: a three-sided loft from inside the head out along the stalk."""
    base, ax = eye_base(side), eye_axis(side)
    a = ax.cross(Vector((0.0, 0.0, 1.0))).normalized()
    b = ax.cross(a).normalized()

    def rg(d, r):
        c = base + ax * d
        return [tuple(c + r * (math.cos(t) * a + math.sin(t) * b)) for t in (math.radians(90 + 120 * k) for k in range(3))]
    rings = [rg(0.03, 0.022), rg(0.085, EYE_R)]
    return meshgen.loft(rings, tuple(base - ax * 0.01), tuple(base + ax * (0.085 + EYE_R)))


def eye_uv(side):
    c = eye_centre(side)
    return lambda p, q: preyart.krill_part_uv("eye", 0.5 + (p[1] - c.y) / (2.4 * EYE_R), 0.5 + (p[2] - c.z) / (2.4 * EYE_R))


def krill_meshdata():
    md = meshgen.MeshData()
    md.add_part(body_part(), preyart.KR_MID, uv=body_uv)
    legs = legs_part()
    LEG_DROP[:] = [v[2] for v in legs[0]]
    md.add_part(legs, preyart.KR_DARK, uv=legs_uv)
    md.add_part(telson_part(), preyart.KR_MID, uv=telson_uv)
    for side in (1.0, -1.0):
        md.add_part(eye_part(side), preyart.KR_DARK, uv=eye_uv(side), tag=common.TAG_FRONT)
    return md


def fit(obj):
    """Scaled to 0.8 studs long, origin at the middle of length and height (06 6.1, 6.2)."""
    vs = obj.data.vertices
    lo = Vector([min(v.co[i] for v in vs) for i in range(3)])
    hi = Vector([max(v.co[i] for v in vs) for i in range(3)])
    c = (lo + hi) / 2.0
    c.x = 0.0
    k = LENGTH / (hi.y - lo.y)
    obj.data.transform(Matrix.Scale(k, 4) @ Matrix.Translation(-c))
    obj.data.update()
    return (hi - lo) * k


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
                   math.radians(rnd.uniform(-12, 12))), 'XYZ').to_matrix().to_4x4()
        out.append(o)
    return out


# ---------------------------------------------------------------- the asset

def build():
    img, block = preyart.atlas()
    work = os.path.join(common.review_dir(NAME), "%s_work.png" % ALBEDO)
    preyart.save_rgba(work, img)
    body = krill_meshdata().to_object(NAME, "GEO", material=preyart.material("MAT_" + NAME, work))
    size = fit(body)
    print("[krill] size x %.3f y %.3f z %.3f" % tuple(size))
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
            "blocks": {"mid": preyart.KR_MID, "light": preyart.KR_LIGHT, "dark": preyart.KR_DARK},
            "lineup": [
                {"label": "M_Prey_Krill, 0.8 studs", "objects": [body]},
                {"label": "template tier-1 Minnow (3 studs)", "objects": [bpy.data.objects["REF_Minnow_T1"]]},
            ],
            "lineup_caption": ["03 2.2: pink-orange comma, two black dot eyes, feathery legs"],
            "extras": [
                {"title": "Swarm of 16, side", "view": "Side", "objects": crowd,
                 "caption": ["03: swarms of 12 to 20; 09 8.8 wobble: yaw within 12 degrees and a roll"]},
                {"title": "Swarm of 16, game camera", "view": "Game", "objects": crowd},
                {"title": "Front", "view": "Front", "objects": [body], "caption": ["eyes on stalks stand out past the head"]},
            ],
            "texture": "%s %d x %d (krill cells), painted by script; rigid, no bones" % (ALBEDO, preyart.SIZE, preyart.SIZE),
        },
    }


if __name__ == "__main__":
    import run
    run.main(__file__)
