"""M_Cove_Interior_01 and M_Cove_Interior_02 with T_Cove_Alb: task S5-A3 (docs/13-sprint-plan.md
Sprint 5; docs/07-asset-list.md 6.6 row M_Cove_Interior: 2 meshes, 6,000 tris together;
docs/03-content-catalog.md 6.10; docs/06-art-bible.md 9.2, 9.3; 02 11.1 and 13.1).

    Blender --background --python assets/source/cove/interior/build.py

The oval chamber, 76 wide x 110 long x 44 high, behind the 25-stud throat: a snug, warm sandstone
cave with a soft sand floor and light falling through a crack along the ceiling. The two meshes:

  _01  the chamber shell: the throat's end flares into an egg-shaped room (narrow at the throat,
       widest in the middle, a rounded apse at the back for the Trophy Rock, Species Wall and tide
       clock). Flat sand floor at depth 52, upright lower walls, a domed ceiling at depth 8 with a
       lit crack along its crown. Thick-walled, closed; its outside is buried in the Rim (hidden).
  _02  the perch terraces: four stepped shelves along each side wall, like a display shelf, that
       grow out of the wall over 9 studs at each end. Each tread is a sand-dusted ledge with a worn
       lit lip; each riser has a dark crease at its foot. Five perches a row per side: 40.

Two meshes so the sand-dusted terraces and the shell can be set up separately in Studio; they
share the atlas. Origins are the centre of each mesh's base (06 6.1); the cove frame and the data
table M_Cove_Interior_01.cove.json (perches, volumes, Home Stone, BankCam and the back-wall spots)
come from coveart.py.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

import coveart as ca  # noqa: E402

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import template  # noqa: E402

NAME = "M_Cove_Interior"
SHELL, TERRACES = NAME + "_01", NAME + "_02"
M = 40                         # points round a ring, evenly spaced; 0 is the floor centre, M/2 the crown
WALL = 3.0                     # shell thickness
CRACKS = ((52.0, 70.0), (85.0, 103.0))   # two wide light cracks along the crown, one face row each side
VAULT_Z = 8.0                  # walls warm below, vault and throat cool above (painted occlusion)
NICHE = (124.0, 12.0, 8.0)     # back-wall faces from y 124, |x| < 12, z < 8: the lit Trophy niche
INNER_Y = [ca.CH_Y0 + 3.0 * i for i in range(37)] + [134.4]
OUTER_Y = [25.0, 31.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0, 110.0, 120.0, 128.0, 133.0, 134.4]
TERRACE_STATIONS = [ca.TERRACE_Y[0] + (ca.TERRACE_Y[1] - ca.TERRACE_Y[0]) * i / 24.0 for i in range(25)]
BACK = -3.0                    # terrace back face, inside the rock
HIDE = 2.2                     # how far the steps sit inside the wall where the terraces end


def smooth(a):
    a = min(1.0, max(0.0, a))
    return a * a * (3.0 - 2.0 * a)


def inner_ring(y, crack=True):
    cham = ca.chamber_section(max(y, ca.CH_Y0 + 1e-3), M)
    if y < 40.0:
        b = smooth((y - ca.CH_Y0) / (40.0 - ca.CH_Y0))
        hole = ca.hole_ring(M)
        cham = [((1 - b) * h[0] + b * c[0], (1 - b) * h[1] + b * c[1]) for h, c in zip(hole, cham)]
    pts = [[x, y, z] for x, z in cham]
    if crack and any(a <= y <= b for a, b in CRACKS):
        pts[M // 2][2] += 1.4
        pts[M // 2 - 1][2] += 0.4
        pts[M // 2 + 1][2] += 0.4
    return pts


def offset_ring(ring, d):
    out = []
    n = len(ring)
    for k in range(n):
        a, b = ring[k - 1], ring[(k + 1) % n]
        tx, tz = b[0] - a[0], b[2] - a[2]
        ln = math.hypot(tx, tz) or 1.0
        out.append([ring[k][0] + d * tz / ln, ring[k][1], ring[k][2] - d * tx / ln])
    return out


def shell_part():
    inner = [inner_ring(y) for y in INNER_Y]
    outer = [offset_ring(inner_ring(y, crack=False), WALL) for y in OUTER_Y]
    rings = outer[::-1] + inner
    no = len(outer)
    c_in = Vector((0.0, 135.0, sum(p[2] for p in inner[-1]) / M))
    c_out = Vector((0.0, 138.0, c_in.z))
    verts, faces = ca.loft(rings, pole_start=tuple(c_out), pole_end=tuple(c_in))
    uvs, hidden = [], []
    for idx, meta in faces:
        if meta[0] != "q":
            j = meta[1]
            cell = "niche" if meta[0] == "p1" else "warm"
            uvs.append([ca.cell_uv(cell, 0.5, 0.5), ca.cell_uv(cell, 0.3, 0.2), ca.cell_uv(cell, 0.7, 0.2)])
            hidden.append(meta[0] == "p0")
            continue
        _, r, j = meta
        if r < no:                       # outside of the shell and the front annulus: in the rock
            uvs.append([ca.cell_uv("warm", ((r % 2) + dr) / 2.0, float(dj)) for dr, dj in ((0, 0), (0, 1), (1, 1), (1, 0))])
            hidden.append(True)
            continue
        i = r - no
        y = INNER_Y[i]
        zs = [verts[v][2] for v in idx]
        floor_z = min(p[2] for p in inner[i])
        uv = []
        xs = [verts[v][0] for v in idx]
        crack = next((c for c in CRACKS if c[0] <= y < c[1]), None)
        niche = y >= NICHE[0] and max(abs(x) for x in xs) < NICHE[1] and max(zs) < NICHE[2]
        lower_j = 0 if verts[idx[0]][2] <= verts[idx[1]][2] else 1     # which point of the face is lower
        for dr, dj in ((0, 0), (0, 1), (1, 1), (1, 0)):
            p = verts[idx[[(0, 0), (0, 1), (1, 1), (1, 0)].index((dr, dj))]]
            if max(zs) < floor_z + 0.6:
                uv.append(ca.cell_uv("sand", ((i % 2) + dr) / 2.0, float(dj)))
            elif crack and M // 2 - 2 <= j <= M // 2 + 1:
                n_st = round((crack[1] - crack[0]) / 3.0)
                uv.append(ca.cell_uv("crack", ((y - crack[0]) / 3.0 + dr) / n_st, (j - (M // 2 - 2) + dj) / 4.0))
            elif niche:
                uv.append(ca.cell_uv("niche", (p[0] + NICHE[1]) / (2 * NICHE[1]), (p[2] - floor_z) / (NICHE[2] - floor_z)))
            elif y < 37.0:
                uv.append(ca.cell_uv("cool", ((i % 3) + dr) / 3.0, float(dj)))
            elif y < 40.0 and max(zs) < VAULT_Z:
                uv.append(ca.cell_uv("blend_u", float(dr), float(dj)))
            elif max(zs) <= VAULT_Z:
                uv.append(ca.cell_uv("warm", ((i % 3) + dr) / 3.0, float(dj)))
            elif min(zs) >= VAULT_Z:
                uv.append(ca.cell_uv("cool", ((i % 3) + dr) / 3.0, float(dj)))
            else:
                uv.append(ca.cell_uv("blend", ((i % 3) + dr) / 3.0, float(dj != lower_j)))
        uvs.append(uv)
        hidden.append(False)
    part = ca.Part()
    part.add(verts, faces, uvs, hidden, front_verts=range(no * M, no * M + M))   # the throat ring
    return part, inner


def terrace_section(y):
    tau = ca.terrace_amount(y)
    tp = 0.08 + 0.92 * tau
    e = [(4 - k) * ca.TREAD * tp - HIDE * (1.0 - tau) for k in range(5)]
    c = 0.7 * min(1.0, 2.0 * tp)
    uc = 0.7 * tau                 # each riser leans back under its lip: a shaded underside
    pts = [(e[0] - uc, -23.0)]
    for k in range(1, 5):
        z = ca.ROW_Z[k - 1]
        pts += [(e[k - 1], z - c), (e[k - 1] - c, z), (e[k] - (uc if k < 4 else 0.0), z)]
    pts += [(BACK, ca.ROW_Z[3]), (BACK, -23.0)]
    return pts


def terraces_part():
    part = ca.Part()
    v_of = []
    for k in range(4):
        v_of += [(0.0, 0.55), (0.55, 0.66), (0.66, 1.0)]
    for sx in (1.0, -1.0):
        rings = []
        for y in TERRACE_STATIONS:
            w = ca.plan_half_width(y)
            rings.append([(sx * (w - e), y, z) for e, z in terrace_section(y)])
        n = len(rings[0])
        p0 = Vector((sx * (ca.plan_half_width(TERRACE_STATIONS[0]) + 1.0), TERRACE_STATIONS[0] - 0.4, -12.0))
        p1 = Vector((sx * (ca.plan_half_width(TERRACE_STATIONS[-1]) + 1.0), TERRACE_STATIONS[-1] + 0.4, -12.0))
        verts, faces = ca.loft(rings, pole_start=tuple(p0), pole_end=tuple(p1))
        uvs, hidden = [], []
        for idx, meta in faces:
            if meta[0] != "q" or meta[2] >= 12:
                j = meta[-1]
                uv = [ca.cell_uv("warm", ((j % 2) + d) / 2.0, d) for d in (0, 1, 1, 0)][:len(idx)]
                uvs.append(uv)
                hidden.append(True)
                continue
            _, r, j = meta
            v0, v1 = v_of[j]
            uvs.append([ca.cell_uv("terrace", ((r % 2) + dr) / 2.0, v0 + (v1 - v0) * dj) for dr, dj in ((0, 0), (0, 1), (1, 1), (1, 0))])
            hidden.append(False)
        part.add(verts, faces, uvs, hidden)
    return part


# ---------------------------------------------------------------- preview helpers

def cut_copy(obj, name, keep):
    """Preview-only copy with faces removed, to see inside (the game meshes stay closed)."""
    me = obj.data.copy()
    me.name = name
    bm = bmesh.new()
    bm.from_mesh(me)
    dead = [f for f in bm.faces if not keep([v.co for v in f.verts])]
    bmesh.ops.delete(bm, geom=dead, context='FACES')
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    template.link(o, "PREVIEW")
    return o


def marker(name, at, colour, r=1.1):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r)
    bmesh.ops.scale(bm, vec=(1.0, 1.0, 0.6), verts=bm.verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(template.flat_material("MAT_" + colour, colour))
    o = bpy.data.objects.new(name, me)
    template.link(o, "PREVIEW")
    o.location = at
    return o


def fish(name, ref, length, at):
    o = bpy.data.objects[ref].copy()
    o.name = name
    bpy.data.collections["PREVIEW"].objects.link(o)
    k = length / (3.0 if ref == "REF_Minnow_T1" else 19.5)
    o.matrix_world = Matrix.Translation(at) @ Matrix.Scale(k, 4)
    return o


GROUP_COLOUR = {"start": "#5CD6C8", "pearls": "#FFFFFF", "bigger_cove": "#B48CFF"}


# ---------------------------------------------------------------- checks and table

def floor_at(y):
    return ca.FLOOR_Z * ca.height_factor(y)


def wall_spot(y, z, side):
    ring = ca.chamber_section(y, 240)
    p = min((q for q in ring if side * q[0] > 0), key=lambda q: abs(q[1] - z))
    pos = Vector((p[0], y, p[1]))
    n = (Vector((0.0, ca.CH_YC, z)) - pos).normalized()
    return pos, n


def points():
    home = (0.0, ca.CH_Y0 + 15.0, ca.FLOOR_Z)
    sw, swn = wall_spot(127.0, -6.0, -1.0)
    tc, tcn = wall_spot(127.0, -6.0, 1.0)
    return {
        "HomeStone": ca.point(home, note="03 6.10: 15 studs inside (from the throat's end), centre"),
        "PearlClam": ca.point((-11.0, home[1], ca.FLOOR_Z), note="left of the Home Stone"),
        "CodexStone": ca.point((11.0, home[1], ca.FLOOR_Z), note="right of the Home Stone"),
        "BankCam": ca.point((16.0, ca.CH_Y0 + 30.0, ca.FLOOR_Z + 12.0), look_at=ca.point((0.0, 33.0, -15.0)),
                            note="03 6.10: 30 studs inside, by the right wall, 12 above the floor, looking back at the Home Stone and the throat"),
        "TrophyRock": ca.point((0.0, 121.0, floor_at(121.0)), note="centre back"),
        "SpeciesWall": ca.point(tuple(sw), normal=ca.point(tuple(swn)), note="back wall, left of the Trophy Rock"),
        "TideClock": ca.point(tuple(tc), normal=ca.point(tuple(tcn)), note="back wall, right of the Trophy Rock"),
        "LightMounts": [
            ca.point((0.0, (a + b) / 2.0, ca.CEIL_Z + 1.0), kind="crack", note="light falling through a ceiling crack, %d studs long" % (b - a))
            for a, b in CRACKS] + [
            ca.point((0.0, 129.0, 0.0), kind="niche", note="the lit niche behind the Trophy Rock: the room's focal light"),
            ca.point((0.0, home[1], ca.FLOOR_Z + 10.0), kind="pool", note="warm pool over the Home Stone")] + [
            ca.point((sx * (ca.plan_half_width(y) - 1.5), y, 12.0), kind="sconce", note="warm lantern between perch columns, above row 4")
            for y in (59.5, 89.5) for sx in (1.0, -1.0)],
    }


def chamber_checks(shell, terraces, cavity):
    def check(spec, report):
        (lo, hi) = cavity
        size = hi - lo
        ok = abs(size.x - ca.CH_W) < 0.5 and abs(size.y - ca.CH_L) < 0.5 and abs(size.z - ca.CH_H) < 0.5
        report.add(NAME, "chamber", ok, "cavity %.1f wide x %.1f long x %.1f high, floor z %.1f, ceiling z %.1f (03 6.10: 76 x 110 x 44, floor depth 52, ceiling depth 8)"
                   % (size.x, size.y, size.z, lo.z, hi.z))
        tris = sum(validate_tris(o) for o in (shell, terraces))
        report.add(NAME, "triangles, both meshes", tris <= 6000, "%d of 6000 (07 6.6: 6,000 tris in 2 meshes)" % tris)
        bad = []
        for p in ca.perches():
            x, y, z = p["base"]
            w = ca.plan_half_width(y)
            inset = w - abs(x)
            on_tread = (4 - p["row"]) * ca.TREAD < inset < (5 - p["row"]) * ca.TREAD and ca.terrace_amount(y) > 0.999
            cx, cy, cz = p["loop_centre"]
            room = abs(cx) + ca.LOOP_RADIUS < w and cz + 2.0 < ca.CEIL_Z
            if not (on_tread and room):
                bad.append(p["slot"])
        report.add(NAME, "perches", len(ca.perches()) == 40 and not bad,
                   "40 perches, 4 rows of 5 a side on full-depth treads, columns %.0f studs apart; off a tread or cramped: %s"
                   % (ca.PERCH_Y[1] - ca.PERCH_Y[0], bad or "none"))
    return check


def validate_tris(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def table_writer(shell, terraces, offs):
    def write(spec, report):
        if not report.ok:
            report.add(NAME, "data table", True, "not written: validation failed")
            return
        perch_rows = []
        for p in ca.perches():
            perch_rows.append({k: p[k] for k in ("slot", "row", "column", "side", "group")})
            perch_rows[-1].update(base=ca.point(p["base"]), facing=ca.point(p["facing"]), loop_centre=ca.point(p["loop_centre"]),
                                  loop_radius=ca.LOOP_RADIUS)
        path = ca.write_table(SHELL + ".fbx", {
            "meshes": {SHELL: ca.mesh_entry(shell, offs[0]), TERRACES: ca.mesh_entry(terraces, offs[1])},
            "volumes": ca.volumes(),
            "points": points(),
            "perches_note": ("03 6.10: perch N is slot N. Rows 1 to 3 (slots 1 to 30) open with Pearls, slots 1 to 6 at the start; "
                             "row 4 (slots 31 to 40) is the Bigger Cove row. 'base' is where M_Cove_Perch stands on its tread, "
                             "'facing' points into the room, the specimen loops round 'loop_centre'."),
            "perches": perch_rows,
        })
        report.add(NAME, "data table", True, path)
    return write


def build():
    img, block, work = ca.texture(NAME)
    mat = ca.material("MAT_" + NAME, work)
    shell_p, inner = shell_part()
    shell = shell_p.to_object(SHELL, mat)
    terraces = terraces_part().to_object(TERRACES, mat)
    flat = [inner_ring(y, crack=False) for y in INNER_Y]
    pts = [Vector(p) for r in flat for p in r] + [Vector((0.0, 135.0, 0.0))]
    cavity = (Vector([min(p[i] for p in pts) for i in range(3)]), Vector([max(p[i] for p in pts) for i in range(3)]))

    # Preview set (cove frame), built before the origins move, then moved with the shell.
    half = cut_copy(shell, "PV_ShellHalf", lambda vs: min(v.x for v in vs) < 0.5)
    half_t = cut_copy(terraces, "PV_TerracesHalf", lambda vs: min(v.x for v in vs) < 0.5)
    roof_off = cut_copy(shell, "PV_ShellOpen", lambda vs: min(v.z for v in vs) < 3.0)
    marks, fishes = [], []
    for p in ca.perches():
        marks.append(marker("PV_Perch_%02d" % p["slot"], Vector(p["base"]) + Vector((0, 0, 0.5)), GROUP_COLOUR[p["group"]]))
    for p in ca.perches():
        if p["side"] == "left" and p["column"] in (1, 3, 5):
            big = p["row"] in (2, 4)
            fishes.append(fish("PV_Specimen_%02d" % p["slot"], "REF_Minnow_T7" if big else "REF_Minnow_T1",
                               9.75 if big else 4.5, Vector(p["loop_centre"])))
    home = marker("PV_HomeStone", Vector((0.0, ca.CH_Y0 + 15.0, ca.FLOOR_Z + 0.3)), "#FFC46B", r=3.0)
    preview_objs = [half, half_t, roof_off] + marks + fishes + [home]

    off = ca.fit_base(shell, extra=preview_objs[:3])
    off_t = ca.fit_base(terraces)
    terr_pv = cut_copy(terraces, "PV_Terraces", lambda vs: True)
    terr_pv.data.transform(Matrix.Translation(off_t - off))    # in the shell's frame, for the preview only
    for o in preview_objs[3:]:
        o.location = o.location - off
    size = Vector([max(v.co[i] for v in shell.data.vertices) - min(v.co[i] for v in shell.data.vertices) for i in range(3)])
    print("[interior] shell size x %.2f y %.2f z %.2f; cove frame origin at %s" % (size.x, size.y, size.z, tuple(-off)))

    sample = ca.sampler(img, block)
    cam = lambda p: tuple(Vector(p) - off)
    open_set = [roof_off, terr_pv] + marks + fishes + [home]
    inside = [shell, terr_pv] + marks + fishes + [home]

    pt = points()
    bank = pt["BankCam"]
    return {
        "name": NAME,
        "category": "Cove",
        "id": "interior",
        "budget": "cove_shell",
        "origin": "prop",
        "size": tuple(size),
        "size_tol": 0.001,
        "facing": {"kind": "tag"},
        "meshes": [{"object": shell, "role": "body", "primary": True},
                   {"object": terraces, "role": "body"}],
        "extra_checks": [ca.surface_checks([shell, terraces], NAME, sample), chamber_checks(shell, terraces, cavity),
                         table_writer(shell, terraces, (off, off_t))],
        "exports": [{"file": "meshes/%s.fbx" % SHELL, "objects": [shell]},
                    {"file": "meshes/%s.fbx" % TERRACES, "objects": [terraces]}],
        "textures": [{"file": "textures/%s.png" % ca.ALBEDO, "write": lambda path: __import__("preyart").save_rgba(path, img), "max": 512}],
        "preview": {
            "main": [half, half_t],
            "view_captions": {"Side": ["right half cut away (preview only): left wall's", "four perch terraces, throat on the left"],
                              "Top": ["right half cut away; throat on the left"]},
            "lineup": [
                {"label": "M_Cove_Interior_01 (shell)", "objects": [shell]},
                {"label": "M_Cove_Interior_02 (terraces)", "objects": [terraces]},
                {"label": "tier-7 Minnow, 19.5 studs", "objects": [bpy.data.objects["REF_Minnow_T7"]]},
            ],
            "lineup_caption": ["no look-alike: the only warm sandstone room in the sea"],
            "extras": [
                {"title": "Ceiling off: 40 perches", "view": "Top", "objects": open_set,
                 "caption": ["teal slots 1-6 (start), white 7-30 (Pearls), violet 31-40", "(Bigger Cove); amber Home Stone; display-size fish"]},
                {"title": "From BankCam", "objects": inside,
                 "camera": {"location": cam(bank["blender"]), "look_at": cam(bank["look_at"]["blender"]), "lens": 14.0},
                 "caption": ["03 6.10 BankCam, looking back at the", "Home Stone and the throat"]},
                {"title": "From the Home Stone", "objects": inside,
                 "camera": {"location": cam((0.0, 36.0, -12.0)), "look_at": cam((0.0, 110.0, -4.0)), "lens": 12.0},
                 "caption": ["03 6.10 sight line: the whole chamber", "from the Home Stone"]},
            ],
            "texture": "%s %d x %d: tiled stone, sand, terrace-step and ceiling-crack cells, painted by script" % (ca.ALBEDO, ca.SIZE, ca.SIZE),
        },
    }


if __name__ == "__main__":
    import run
    run.main(__file__)
