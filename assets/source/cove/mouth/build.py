"""M_Cove_Mouth with T_Cove_Alb: task S5-A3 (docs/13-sprint-plan.md Sprint 5; docs/07-asset-list.md
6.6 row M_Cove_Mouth, 2,500 tris; docs/03-content-catalog.md 6.7; docs/06-art-bible.md 9.2, 9.3).

    Blender --background --python assets/source/cove/mouth/build.py

A rounded cave opening 36 wide and 28 high in the inner face of the Rim, with the 25-stud throat
behind it. It has to read as "home" from out in the Reef, so it is framed like a front door:
a ring of nine rounded warm sandstone stones (a wide keystone on top, where the Name Shell
hangs) and a flat three-slab doorstep that runs the throat's sand floor out over the sill. The
warm stone stands out of the cooler, rougher Rim rock (T_Tile_Rock_Alb) by colour and by shape;
the lantern light spilling out (FX_CoveBeacon, LGT_Cove) does the rest.

One closed genus-1 mesh: for each of 60 angles around the opening, a 19-point section runs down
the throat, round the lip, over the stone's front, tucks behind the Rim's face and back along the
throat's outer skin. Faces behind the Rim's face are flagged hidden (they are inside the rock)
and left out of the value and texel checks. Origin: the centre of the base (06 6.1); the cove frame
is in coveart.py, and the export writes M_Cove_Mouth.cove.json with the CoveMouth volume and the
anchors of the Name Shell, Trophy Bubble mount and Door Lantern.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

import coveart as ca  # noqa: E402  (puts _shared/blender on the path)

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402
import template  # noqa: E402

NAME = "M_Cove_Mouth"
# Arch stones, degrees round the opening (0 = the right side, 90 = top); the sill takes the rest.
ARCH = (-20.0, 6.0, 30.0, 52.0, 74.0, 106.0, 128.0, 150.0, 174.0, 200.0)
STONE_JITTER = (0.3, -0.4, 0.5, -0.2, 0.0, -0.3, 0.4, -0.5, 0.2)
SILL = (200.0, 340.0)
PER_STONE = 5               # a groove sample and four across the stone
SILL_SAMPLES = 15
T = (0.0, 0.07, 0.18, 0.33, 0.5, 0.67, 0.82, 0.93, 1.0)
SILL_Y = (-4.5, -5.0, -5.2, -5.2, -5.0, -4.6, -3.8, -2.2, 0.0)
TUNNEL_Y = (ca.THROAT, 18.5, 12.0, 5.5, 1.5)
SKIN = 2.5                  # throat wall thickness behind the stone


def samples():
    """[(theta degrees, stone index or 'sill', m = sample index within the stone)]"""
    out = []
    for s in range(len(ARCH) - 1):
        a0, a1 = ARCH[s], ARCH[s + 1]
        for m in range(PER_STONE):
            out.append((a0 + (a1 - a0) * m / PER_STONE, s, m))
    for m in range(SILL_SAMPLES):
        out.append((SILL[0] + (SILL[1] - SILL[0]) * m / SILL_SAMPLES, "sill", m))
    return out


def sill_weight(deg):
    d = (deg - 270.0 + 180.0) % 360.0 - 180.0
    a = min(1.0, max(0.0, (70.0 - abs(d)) / 15.0))
    return a * a * (3.0 - 2.0 * a)


def stone_size(deg, stone, m):
    """(frame width w, forward depth F) at one sample: a rounded pillow per stone, grooves between."""
    s = math.sin(math.radians(deg))
    if stone == "sill":
        return 7.0, 1.0
    top = max(0.0, s) ** 2
    ws = 9.0 + 3.5 * top + STONE_JITTER[stone] + (1.2 if stone == 4 else 0.0)
    fs = 3.0 + 0.6 * top + 0.6 * STONE_JITTER[stone] + (0.6 if stone == 4 else 0.0)
    k = math.sin(math.pi * m / PER_STONE)
    return (ws - 1.6) + 1.6 * k ** 0.5, 0.9 + (fs - 0.9) * k ** 0.6


def section(deg, stone, m):
    """19 (rho, y) points: rho out from the opening's edge, y into the cove."""
    w, f = stone_size(deg, stone, m)
    sb = sill_weight(deg)
    pts = [(0.0, y) for y in TUNNEL_Y]
    for t, sy in zip(T, SILL_Y):
        arch_y = -f * math.sin(math.pi * t) ** 0.55
        pts.append((t * w, (1.0 - sb) * arch_y + sb * sy))
    pts += [(w, 1.2), (0.6 * w, 2.2), (SKIN, 3.5), (SKIN, 14.0), (SKIN, ca.THROAT)]
    return pts


def build_mesh(mat):
    smp = samples()
    rings, info = [], []
    for deg, stone, m in smp:
        th = math.radians(deg)
        hx, hz = ca.hole(th)
        nx, nz = ca.hole_normal(th)
        rings.append([(hx + nx * r, y, hz + nz * r) for r, y in section(deg, stone, m)])
        info.append((deg, stone, m))
    verts, faces = ca.loft(rings, cyclic_rings=True)
    n = len(rings[0])
    uvs, hidden = [], []
    for idx, (kind, r, j) in faces:
        deg, stone, m = info[r]
        floor = math.sin(math.radians(deg + 360.0 / len(smp) / 2.0)) < -0.8
        corners = [(0, 0), (0, 1), (1, 1), (1, 0)]       # (d ring, d point) of the loft's quad corners
        uv = []
        for dr, dj in corners:
            if 5 <= j <= 12:                              # the stone's front
                mm = (m % PER_STONE) + dr
                uv.append(ca.cell_uv("stone", mm / PER_STONE, (j - 5 + dj) / 8.0))
            elif j == 4 and sill_weight(deg) > 0.5:       # the doorstep: the throat's sand run out over the sill
                uv.append(ca.cell_uv("sand", ((r % 3) + dr) / 3.0, dj))
            elif j <= 4:
                cell = "sand" if floor else "wall"
                uv.append(ca.cell_uv(cell, ((r % 3) + dr) / 3.0, ((j % 2) + dj) / 2.0))
            else:
                uv.append(ca.cell_uv("wall", ((r % 2) + dr) / 2.0, ((j % 2) + dj) / 2.0))
        uvs.append(uv)
        hidden.append(j >= 13)
    front = [r * n + j for r in range(len(rings)) for j in range(5, 14)]
    part = ca.Part()
    part.add(verts, faces, uvs, hidden, front)
    return part.to_object(NAME, mat), rings


# ---------------------------------------------------------------- preview helpers

def box(name, lo, hi, colour):
    import meshgen
    md = meshgen.MeshData()
    md.add_part(meshgen.box(lo, hi), colour)
    obj = md.to_object(name, "PREVIEW", smooth=False, material=template.flat_material("MAT_" + name, colour))
    return obj


def lit_box(name, lo, hi, colour):
    import meshgen
    md = meshgen.MeshData()
    md.add_part(meshgen.box(lo, hi), colour)
    return md.to_object(name, "PREVIEW", smooth=False)


def rim_wall(off):
    """A slab of Rim face around the opening (preview only), in the Reef rock colour (06 4.2)."""
    rock = "#B89A86"
    o = Vector(off)
    parts = [((-80, 0.6, -50), (-19, 8, 50)), ((19, 0.6, -50), (80, 8, 50)),
             ((-19, 0.6, 15), (19, 8, 50)), ((-19, 0.6, -50), (19, 8, -15))]
    return [lit_box("PV_RimWall_%d" % i, tuple(Vector(a) - o), tuple(Vector(b) - o), rock) for i, (a, b) in enumerate(parts)]


def home_glow(off):
    """Lantern-amber light at the back of the throat (06 4.5 home; preview stand-in for LGT_Cove)."""
    o = Vector(off)
    return box("PV_HomeGlow", tuple(Vector((-18, 24.0, -14)) - o), tuple(Vector((18, 24.4, 14)) - o), "#FFC46B")


def tier7(off, at=(0.0, 12.0, -2.0)):
    ref = bpy.data.objects["REF_Minnow_T7"].copy()
    ref.name = "PV_Tier7"
    bpy.data.collections["PREVIEW"].objects.link(ref)
    ref.matrix_world = Matrix.Translation(Vector(at) - Vector(off))
    return ref


# ---------------------------------------------------------------- checks and table

def opening_checks(rings, off):
    def check(spec, report):
        lip = [Vector(r[4]) for r in rings]          # the throat's last ring, 1.5 studs inside the mouth plane
        wd = max(p.x for p in lip) - min(p.x for p in lip)
        ht = max(p.z for p in lip) - min(p.z for p in lip)
        report.add(NAME, "opening", abs(wd - ca.MOUTH_W) < 0.5 and abs(ht - ca.MOUTH_H) < 0.5 and wd >= 30.0,
                   "%.2f wide x %.2f high (03 6.7: 36 x 28; 02 11.1: at least 30 across)" % (wd, ht))
        ys = [p[1] for r in rings for p in r[:5]]
        report.add(NAME, "throat", abs(max(ys) - ca.THROAT) < 1e-3, "runs %.1f studs from the mouth plane (03 6.7: 25)" % max(ys))
    return check


def table_writer(mouth, off, anchors):
    def write(spec, report):
        if not report.ok:
            report.add(NAME, "data table", True, "not written: validation failed")
            return
        path = ca.write_table(NAME + ".fbx", {
            "meshes": {NAME: ca.mesh_entry(mouth, off)},
            "volumes": {"CoveMouth": ca.volumes()["CoveMouth"]},
            "anchors": anchors,
        })
        report.add(NAME, "data table", True, path)
    return write


def build():
    img, block, work = ca.texture(NAME)
    mat = ca.material("MAT_" + NAME, work)
    mouth, rings = build_mesh(mat)
    # Anchors on the frame, in the cove frame before the origin moves.
    top = [p for r in rings for p in r[5:14] if abs(p[0]) < 3.0 and p[2] > 0]
    key_front = min(p[1] for p in top)
    anchors = {
        "NameShell": ca.point((0.0, key_front - 0.3, ca.MOUTH_H / 2.0 + 6.5), note="07 6.6: scallop sign 14 wide, centred on the keystone, facing out (-Y blender)"),
        "TrophyBubbleMount": ca.point((15.0, -2.0, ca.MOUTH_H / 2.0 + 6.0), note="bracket beside the sign, viewer's right; the 10-stud bubble clears the arch"),
        "DoorLantern": ca.point((-21.0, -3.5, -ca.MOUTH_H / 2.0 - 0.2), note="stalk foot on the doorstep's left end, viewer's left"),
        "KelpCurtain": ca.point((0.0, -0.2, 0.0), note="across the opening, on the mouth plane"),
        "Membrane": ca.point((0.0, 0.0, 0.0), note="02 11.1 bubble film: the mouth plane, 36 x 28"),
    }
    off = ca.fit_base(mouth)
    size = Vector([max(v.co[i] for v in mouth.data.vertices) - min(v.co[i] for v in mouth.data.vertices) for i in range(3)])
    print("[mouth] size x %.2f y %.2f z %.2f; cove frame origin at %s in mesh space" % (size.x, size.y, size.z, tuple(-off)))

    wall = rim_wall(off)
    glow = home_glow(off)
    fish = tier7(off)
    sample = ca.sampler(img, block)
    scene_objs = [mouth, glow] + wall
    return {
        "name": NAME,
        "category": "Cove",
        "id": "mouth",
        "budget": "cove_mouth",
        "origin": "prop",
        "size": tuple(size),
        "size_tol": 0.001,
        "facing": {"kind": "tag"},
        "meshes": [{"object": mouth, "role": "body", "primary": True}],
        "extra_checks": [ca.surface_checks([mouth], NAME, sample), opening_checks(rings, off), table_writer(mouth, off, anchors)],
        "exports": [{"file": "meshes/%s.fbx" % NAME, "objects": [mouth]}],
        "textures": [{"file": "textures/%s.png" % ca.ALBEDO, "write": lambda path: __import__("preyart").save_rgba(path, img), "max": 512}],
        "preview": {
            "main": [mouth],
            "view_captions": {"Side": ["stones stand 3 to 4.5 studs proud of the Rim face (y 0)"],
                              "Top": ["throat runs 25 studs into the Rim (right)"]},
            "lineup": [
                {"label": "M_Cove_Mouth, 36 x 28 opening", "objects": [mouth]},
                {"label": "tier-7 Minnow, 19.5 studs", "objects": [bpy.data.objects["REF_Minnow_T7"]]},
                {"label": "4-stud cube", "objects": [bpy.data.objects["REF_Cube4"]]},
            ],
            "lineup_caption": ["no look-alike: the only door-shaped stone arch in the sea (Reef arches are bare rock)"],
            "extras": [
                {"title": "From the Reef, 80 studs out", "objects": scene_objs,
                 "camera": {"location": tuple(Vector((22.0, -80.0, 8.0)) - off), "look_at": tuple(Vector((0.0, 0.0, 2.0)) - off), "lens": 30.0},
                 "caption": ["in a slab of Rim rock (preview only), lantern-amber", "home light at the throat's end (06 4.5)"]},
                {"title": "Front, in the Rim face", "view": "Front", "objects": scene_objs,
                 "caption": ["keystone carries the Name Shell; doorstep holds", "the Door Lantern (anchors in the .cove.json)"]},
                {"title": "Tier 7 in the throat", "view": "Front", "objects": [mouth, fish],
                 "caption": ["03 6.7: big enough for a tier 7 creature", "02 11.1: at least 30 across"]},
            ],
            "texture": "%s %d x %d: tiled stone, sand and arch-stone cells, painted by script" % (ca.ALBEDO, ca.SIZE, ca.SIZE),
        },
    }


if __name__ == "__main__":
    import run
    run.main(__file__)
