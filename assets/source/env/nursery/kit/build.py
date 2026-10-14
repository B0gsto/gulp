"""Nursery kit, first half (task S6-A3): T_EnvNursery_Alb and the kit sheet (06 15.5 zone sheet) under the Nursery
preset (06 10.2: Brightness 2.2, ColorShift_Top #FFF3C4, OutdoorAmbient #B8ECEC, legacy fog #4CCFD2 from 25% of
the 450-stud view distance to 450, and once at the 220-stud Smooth cap, 15 3.0).

    python3 assets/source/env/nursery/kit/build.py            # paint, render (Blender, heavy-job pool), sheet
    python3 assets/source/env/nursery/kit/build.py paint      # T_EnvNursery_Alb + its report
    <Blender> --background --factory-startup --python assets/source/env/nursery/kit/build.py -- render
    python3 assets/source/env/nursery/kit/build.py sheet      # the 1536 x 1536 sheet and its 768 preview

The vignette is a review scene, not the Nursery's assembly (S7-A2): the four floor chunks on the 128 grid at sand
level depth 26, and rim pieces walked round an oval 220 x 170 (03 6.2), closed (Little Arch, S7-A1, replaces one
span in the assembly). Each copy is chosen by the oval's curvature (Rim_02 at the ends, Rim_01 on the
sides), scaled 80 to 125% to it (06 9.1) and tinted from nurseryart.RIM_TINTS.

Writes assets/export/textures/T_EnvNursery_Alb.png, assets/review/T_EnvNursery_Alb/atlas_report.json,
assets/review/M_Env_Nursery_Kit/renders/*.png and assets/review/M_Env_Nursery_Kit/<date>_kit_sheet.png (+ _768).
"""
import json
import math
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

import nurseryart as na  # noqa: E402
import common  # noqa: E402

BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
WITH_HEAVY = os.environ.get("GULP_WITH_HEAVY", "/Users/bogdan/RobloxProjects/tools/with-heavy.sh")
REVIEW = common.review_dir("M_Env_Nursery_Kit")
RENDERS = os.path.join(REVIEW, "renders")
SHEET = 1536
CELL_W, CELL_H = 496, 424
OVAL = (110.0, 85.0)            # 03 6.2: 220 x 170
GAP = 0.0                       # review loop 1: the ring is closed in the vignette; Little Arch takes a span in S7
OVERLAP = 0.0                   # pieces step by their nominal span; each runs nurseryart.END past the joint
SHOW_FLOORS = {"M_Env_Nursery_Floor_03": (-64.0, 64.0), "M_Env_Nursery_Floor_04": (64.0, 64.0),
               "M_Env_Nursery_Floor_02": (-64.0, -64.0), "M_Env_Nursery_Floor_01": (64.0, -64.0)}
SHOWCASE = (1400.0, 0.0)        # the pieces alone, far out of every vignette shot
FLOORCASE = (0.0, 1400.0)

# (file, fog end or None, camera, look at, lens or ('ortho', scale), hide surface, caption)
SHOTS = [
    ("pool_game", 450.0, (80.0, 18.0, -14.0), (-125.0, -4.0, -14.0), 18.0, False,
     "In the pool, toward the west end: Rim_02 round the end, Rim_01 on the sides"),
    ("pool_smooth", 220.0, (80.0, 18.0, -14.0), (-125.0, -4.0, -14.0), 18.0, False,
     "The same at the Smooth cap (fog 55 to 220, 15 3.0): judged first"),
    ("bowl", 450.0, (-8.0, 14.0, -19.0), (-78.0, 82.0, -27.0), 20.0, False,
     "Krill Corner bowl (Floor_03) and the north-west rim"),
    ("crest", 450.0, (-70.0, -18.0, -5.0), (-140.0, -30.0, 1.5), 20.0, False,
     "Just under the surface: the crest breaks it 4 to 7 high"),
    ("plan", None, (0.0, 0.0, 600.0), (0.0, 0.0, 0.0), ("ortho", 400.0), True,
     "Plan, no fog: chunks 03 04 / 02 01 on the 128 grid, rim walked round the oval"),
    ("overview", None, (250.0, -280.0, 185.0), (-10.0, 10.0, -22.0), 24.0, True,
     "From above, no fog (surface hidden): the low rim round the pale pool"),
    ("pieces", 450.0, (SHOWCASE[0], SHOWCASE[1] - 120.0, -12.0), (SHOWCASE[0], SHOWCASE[1], -10.0), 22.0, False,
     "Rim_01 (left) and Rim_02 (right) alone, pool face, Nursery fog"),
    ("floors", None, (FLOORCASE[0], FLOORCASE[1] - 330.0, 95.0), (FLOORCASE[0], FLOORCASE[1] + 20.0, -32.0), 28.0, True,
     "Floor_01 to _04 apart (left to right), no fog: the relief"),
]


# ---------------------------------------------------------------- paint (system python3)
def paint():
    import numpy as np
    from PIL import Image
    img = na.paint_atlas()
    path = na.atlas_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)).save(path, optimize=True)
    back = np.asarray(Image.open(path).convert("RGB")).astype(float) / 255.0
    rows, st, cells = na.atlas_report(back)
    ok = all(bool(r[2]) for r in rows)
    rep = {"name": na.ATLAS, "file": os.path.relpath(path, common.REPO_DIR), "size": [na.N, na.N], "stats": st,
           "cells": {k: {"rect": list(v), "use": na.CELL_USE[k], "mid": na.MIDS[k], "shares": [round(x, 3) for x in cells[k]]}
                     for k, v in na.ATLAS_CELLS.items()},
           "checks": [{"subject": a, "check": b, "ok": bool(c), "detail": d} for a, b, c, d in rows],
           "validation": "pass" if ok else "fail", "date": common.today(), "commit": common.git_commit()}
    with open(os.path.join(common.review_dir(na.ATLAS), "atlas_report.json"), "w") as f:
        json.dump(rep, f, indent=1)
    for a, b, c, d in rows:
        if not c:
            print("FAIL %s %s: %s" % (a, b, d))
    print("%s %s: %d checks, mean %s, L* p5/p50/p95 %s/%s/%s, fine %.2f, nearest reserved %.3f" % (
        na.ATLAS, "PASS" if ok else "FAIL", len(rows), st["mean"], st["L_p5"], st["L_p50"], st["L_p95"],
        st["fine_noise_L"], st["min_dist_to_signal"]))
    return ok


# ---------------------------------------------------------------- the oval walk
def ellipse(t):
    a, b = OVAL
    p = (a * math.cos(t), b * math.sin(t))
    tan = (-a * math.sin(t), b * math.cos(t))
    n = math.hypot(*tan)
    tan = (tan[0] / n, tan[1] / n)
    out = (tan[1], -tan[0])                        # counter-clockwise walk: the outward normal is on the right
    rho = (a * a * math.sin(t) ** 2 + b * b * math.cos(t) ** 2) ** 1.5 / (a * b)
    return p, out, rho


def walk():
    """[(name, waterline point (x, y), outward normal, scale, tint)] round the oval, counter-clockwise from its east
    end: each piece's toe (30 studs inside its waterline) lies on the oval, the sand floor's outline."""
    import bisect
    ts = [2 * math.pi * k / 4000 for k in range(4001)]
    arc = [0.0]
    for t0, t1 in zip(ts, ts[1:]):
        p0, p1 = ellipse(t0)[0], ellipse(t1)[0]
        arc.append(arc[-1] + math.hypot(p1[0] - p0[0], p1[1] - p0[1]))
    total = arc[-1]

    def at(s):
        s %= total
        i = min(len(ts) - 2, bisect.bisect_left(arc, s))
        return ts[i]
    out, s, k = [], GAP / 2.0, 0
    end = total - GAP / 2.0
    while s < end - 10.0:
        rho = ellipse(at(s + 18.0))[2]                 # the toe follows the oval: toe radius = rho
        name = "M_Env_Nursery_Rim_02" if rho < 100.0 else "M_Env_Nursery_Rim_01"
        cfg = na.RIMS[name]
        toe_r = cfg["radius"] + na.TOE
        scale = min(1.25, max(0.8, rho / toe_r))
        half = rho * cfg["span"] / cfg["radius"] / 2.0     # the piece's arc measured along its toe
        c = s + half
        p, n, _ = ellipse(at(c))
        w = (p[0] - na.TOE * scale * n[0], p[1] - na.TOE * scale * n[1])   # its waterline point, outside the toe
        out.append((name, w, n, scale, na.RIM_TINTS[k % len(na.RIM_TINTS)]))
        s = c + half - OVERLAP
        k += 1
    return out


# ---------------------------------------------------------------- render (inside Blender)
def render():
    import bpy
    from mathutils import Matrix, Vector
    import rimart as ra
    import tilegen
    lin = common.hex_to_linear
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.eevee.taa_render_samples = 24
    sc.render.resolution_x, sc.render.resolution_y = 2 * CELL_W, 2 * CELL_H
    sc.render.image_settings.file_format = 'PNG'
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'None'
    fog_nodes = []

    def fogged(mat, shader_out):
        nt = mat.node_tree
        out = next(n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL')
        cam = nt.nodes.new("ShaderNodeCameraData")
        rng = nt.nodes.new("ShaderNodeMapRange")
        rng.clamp = True
        emi = nt.nodes.new("ShaderNodeEmission")
        mix = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(cam.outputs["View Distance"], rng.inputs["Value"])
        nt.links.new(rng.outputs["Result"], mix.inputs[0])
        nt.links.new(shader_out, mix.inputs[1])
        nt.links.new(emi.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs["Surface"])
        fog_nodes.append((rng, emi))

    def lit(name, image, tint, per_copy=False):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        nt = mat.node_tree
        nt.nodes.clear()
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(image, check_existing=True)
        tex.extension = 'REPEAT'
        mul = nt.nodes.new("ShaderNodeVectorMath")
        mul.operation = 'MULTIPLY'
        mul.inputs[1].default_value = tint
        dif = nt.nodes.new("ShaderNodeBsdfDiffuse")
        nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(tex.outputs["Color"], mul.inputs[0])
        if per_copy:                                  # SurfaceAppearance.Color per placement
            info = nt.nodes.new("ShaderNodeObjectInfo")
            mul2 = nt.nodes.new("ShaderNodeVectorMath")
            mul2.operation = 'MULTIPLY'
            nt.links.new(mul.outputs["Vector"], mul2.inputs[0])
            nt.links.new(info.outputs["Color"], mul2.inputs[1])
            nt.links.new(mul2.outputs["Vector"], dif.inputs["Color"])
        else:
            nt.links.new(mul.outputs["Vector"], dif.inputs["Color"])
        fogged(mat, dif.outputs[0])
        return mat

    tex_dir = os.path.join(common.EXPORT_DIR, "textures")
    sand_tex = os.path.join(tex_dir, na.SAND + ".png")
    rock = lit("Rock", os.path.join(tex_dir, na.ROCK + ".png"), (1.0, 1.0, 1.0), per_copy=True)
    sand = lit("SandNursery", sand_tex, tilegen.tints(na.SAND)["nursery"][2])
    silt = lit("SandOuter", sand_tex, tilegen.tints(na.SAND)["kelp"][2])

    floors, rims = {}, {}
    for name in na.FLOOR_NAMES:
        ob = na.build_floor(name)
        ob.data.materials.append(sand)
        floors[name] = ob
    for name in na.RIM_NAMES:
        ob = na.build_rim(name)                       # piece frame: pool face at (0, 0), surface at z 0
        ob.data.materials.append(rock)
        rims[name] = ob

    def inst(src, matrix, colour=None):
        c = src.copy()
        sc.collection.objects.link(c)
        c.matrix_world = matrix
        if colour:
            k = [int(colour[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]
            c.color = (k[0], k[1], k[2], 1.0)
        return c

    base_z = -(na.SAND_DEPTH + na.SLAB)
    for name, (x, y) in SHOW_FLOORS.items():
        inst(floors[name], Matrix.Translation((x, y, base_z)))
    placed = walk()
    for name, p, n, scale, tint in placed:
        theta = math.atan2(-n[0], n[1])
        m = Matrix.Translation((p[0], p[1], 0.0)) @ Matrix.Rotation(theta, 4, 'Z') @ Matrix.Diagonal((scale, scale, 1.0, 1.0))
        inst(rims[name], m, tint)
    # the pieces alone, and the four chunks apart
    inst(rims["M_Env_Nursery_Rim_01"], Matrix.Translation((SHOWCASE[0] - 44.0, SHOWCASE[1], 0.0)))
    inst(rims["M_Env_Nursery_Rim_02"], Matrix.Translation((SHOWCASE[0] + 44.0, SHOWCASE[1], 0.0)), na.RIM_TINTS[1])
    inst(floors["M_Env_Nursery_Floor_01"], Matrix.Translation((SHOWCASE[0] - 64.0, SHOWCASE[1] - 100.0, base_z)))
    inst(floors["M_Env_Nursery_Floor_02"], Matrix.Translation((SHOWCASE[0] + 64.0, SHOWCASE[1] - 100.0, base_z)))
    for i, name in enumerate(na.FLOOR_NAMES):
        inst(floors[name], Matrix.Translation((FLOORCASE[0] + (i - 1.5) * 140.0, FLOORCASE[1], base_z)))
    for src in list(floors.values()) + list(rims.values()):
        src.hide_render = True

    def plane(name, size, z, mat, centre=(0.0, 0.0)):
        cx, cy = centre
        verts = [(cx - size, cy - size, z), (cx + size, cy - size, z), (cx + size, cy + size, z), (cx - size, cy + size, z)]
        ob = ra.mesh_object(name, verts, [(0, 1, 2, 3)])
        me = ob.data
        uvl = me.uv_layers.new(name="UVMap").data
        for li, lp in enumerate(me.loops):
            v = me.vertices[lp.vertex_index].co
            uvl[li].uv = (v.x / na.SAND_TILE, v.y / na.SAND_TILE)
        ob.data.materials.append(mat)
        return ob
    plane("FloorOuter", 2400.0, -72.0, silt, centre=(700.0, 700.0))
    # the water surface from below: the Nursery's surface band colour (06 4.2), fogged like everything else
    surf = bpy.data.materials.new("Surface")
    surf.use_nodes = True
    nt = surf.node_tree
    nt.nodes.clear()
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = lin(na.NURSERY["surface"]) + (1.0,)
    e.inputs["Strength"].default_value = 0.85
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(e.outputs[0], o.inputs["Surface"])
    fogged(surf, e.outputs[0])
    surface = plane("Surface", 2400.0, 0.0, surf, centre=(700.0, 700.0))

    world = bpy.data.worlds.new("W")
    sc.world = world
    world.use_nodes = True
    wn, wl = world.node_tree.nodes, world.node_tree.links
    wn.clear()
    lp, amb, bg = wn.new("ShaderNodeLightPath"), wn.new("ShaderNodeBackground"), wn.new("ShaderNodeBackground")
    wmix, wout = wn.new("ShaderNodeMixShader"), wn.new("ShaderNodeOutputWorld")
    wl.new(lp.outputs["Is Camera Ray"], wmix.inputs[0])
    wl.new(amb.outputs[0], wmix.inputs[1])
    wl.new(bg.outputs[0], wmix.inputs[2])
    wl.new(wmix.outputs[0], wout.inputs["Surface"])
    sun_data = bpy.data.lights.new("Key", 'SUN')
    sun_data.use_shadow = False                  # 06 15.3: no shadows, as on the weakest phone
    sun = bpy.data.objects.new("Key", sun_data)
    sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(32), 0, math.radians(-35))
    cam_data = bpy.data.cameras.new("Cam")
    camo = bpy.data.objects.new("Cam", cam_data)
    sc.collection.objects.link(camo)
    sc.camera = camo
    os.makedirs(RENDERS, exist_ok=True)
    L = na.NURSERY
    sun_data.color = lin(L["sun"])
    sun_data.energy = 1.35 * L["brightness"]
    amb.inputs["Color"].default_value = lin(L["outdoor"]) + (1.0,)
    amb.inputs["Strength"].default_value = 0.45
    for fname, fog_end, loc, aim, lens, hide_surface, cap in SHOTS:
        for rng, emi in fog_nodes:
            emi.inputs["Color"].default_value = lin(L["fog"]) + (1.0,)
            a, b = (1e6, 2e6) if fog_end is None else (0.25 * fog_end, float(fog_end))
            rng.inputs["From Min"].default_value, rng.inputs["From Max"].default_value = a, b
        bg.inputs["Color"].default_value = lin(L["fog"] if fog_end else "#3A5A66") + (1.0,)
        surface.hide_render = hide_surface
        camo.location = loc
        d = Vector(aim) - Vector(loc)
        if isinstance(lens, tuple):
            cam_data.type = 'ORTHO'
            cam_data.ortho_scale = lens[1]
            camo.location = (aim[0], aim[1], loc[2])
            camo.rotation_euler = (0.0, 0.0, 0.0)
        else:
            cam_data.type = 'PERSP'
            cam_data.lens = lens
            camo.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
        cam_data.clip_start, cam_data.clip_end = 0.5, 6000.0
        sc.render.filepath = os.path.join(RENDERS, fname + ".png")
        bpy.ops.render.render(write_still=True)
        print("rendered", fname, flush=True)
    meta = {"tris": {n: ra.tri_count(o) for n, o in list(floors.items()) + list(rims.items())},
            "placements": [{"mesh": n, "scale": round(s, 3), "tint": t} for n, _, _, s, t in placed]}
    with open(os.path.join(RENDERS, "meta.json"), "w") as f:
        json.dump(meta, f, indent=1)


# ---------------------------------------------------------------- sheet (system python3)
def sheet():
    from PIL import Image, ImageDraw, ImageFont
    meta = json.load(open(os.path.join(RENDERS, "meta.json")))
    atlas_rep = json.load(open(os.path.join(common.review_dir(na.ATLAS), "atlas_report.json")))

    def font(size):
        for p in ("/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc"):
            if os.path.exists(p):
                return ImageFont.truetype(p, size)
        return ImageFont.load_default()
    f20, f14, f12 = font(21), font(14), font(12)
    sh = Image.new("RGB", (SHEET, SHEET), (28, 30, 36))
    d = ImageDraw.Draw(sh)
    d.text((12, 10), "Nursery kit, first half (S6-A3): M_Env_Nursery_Floor_01-04, M_Env_Nursery_Rim_01-02, T_EnvNursery_Alb",
           fill=(240, 240, 240), font=f20)
    d.text((12, 36), "06 10.2 Nursery preset: Brightness 2.2, sun #FFF3C4, ambient #B8ECEC, legacy fog #4CCFD2 112-450 "
           "(cell 2: Smooth cap 55-220). Review vignette, not the assembly (S7-A2). %d rim copies." % len(meta["placements"]),
           fill=(190, 190, 190), font=f14)
    top, gap, cap = 58, 12, 38
    cells = [s[0] for s in SHOTS] + ["atlas"]
    caps = [s[6] for s in SHOTS] + ["T_EnvNursery_Alb 512 x 512: one cell per later piece (S7-A1, deferred landmarks)"]
    for i, name in enumerate(cells):
        x = gap + (i % 3) * (CELL_W + gap)
        y = top + (i // 3) * (CELL_H + cap + 6)
        if name == "atlas":
            img = Image.open(na.atlas_path()).convert("RGB")
            side = 360
            sh.paste(img.resize((side, side), Image.LANCZOS), (x, y))
            k = side / float(na.N)
            for cname, (cx, cy, cw, chh) in na.ATLAS_CELLS.items():
                d.rectangle([x + cx * k, y + cy * k, x + (cx + cw) * k - 1, y + (cy + chh) * k - 1], outline=(30, 30, 40))
            lx = x + side + 6
            for j, cname in enumerate(na.ATLAS_CELLS):
                d.text((lx, y + 2 + j * 15), cname.replace("_", " "), fill=(220, 220, 220), font=f12)
            sv = atlas_rep["stats"]
            d.text((lx, y + 2 + 15 * len(na.ATLAS_CELLS) + 6), "3 values per cell:", fill=(200, 200, 200), font=f12)
            d.text((lx, y + 2 + 15 * len(na.ATLAS_CELLS) + 21), "dark 12, mid 63, light 25%", fill=(200, 200, 200), font=f12)
            d.text((lx, y + 2 + 15 * len(na.ATLAS_CELLS) + 36), "reserved >= %.2f" % sv["min_dist_to_signal"], fill=(200, 200, 200), font=f12)
            d.text((lx, y + 2 + 15 * len(na.ATLAS_CELLS) + 51), atlas_rep["validation"].upper(), fill=(200, 200, 200), font=f12)
        else:
            img = Image.open(os.path.join(RENDERS, name + ".png")).convert("RGB")
            sh.paste(img.resize((CELL_W, CELL_H), Image.LANCZOS), (x, y))
        d.text((x, y + CELL_H + 3), "%d. %s" % (i + 1, caps[i]), fill=(230, 230, 230), font=f14)
        if i < len(SHOTS):
            fe = SHOTS[i][1]
            d.text((x, y + CELL_H + 20), ("Nursery fog %d-%d" % (fe * 0.25, fe)) if fe else "Nursery light, no fog",
                   fill=(160, 160, 160), font=f12)
    t = meta["tris"]
    foot1 = "Triangles: " + ", ".join("%s %d" % (k.replace("M_Env_Nursery_", ""), v) for k, v in sorted(t.items())) + \
        "  (06 6.3 / 07 6.2: floor chunk 3,000; rim 1,000)"
    foot2 = "Textures: T_Tile_Sand_Alb 512 (Nursery tint), T_Tile_CoralRock_Alb 512 (tint per copy), T_EnvNursery_Alb 512 (06 5.6: 512 tiling / zone atlas)" \
        "    %s    commit %s" % (common.today(), common.git_commit())
    d.text((12, SHEET - 44), foot1, fill=(200, 200, 200), font=f14)
    d.text((12, SHEET - 24), foot2, fill=(200, 200, 200), font=f14)
    out = os.path.join(REVIEW, "%s_kit_sheet.png" % common.today())
    sh.save(out, optimize=True)
    small = out.replace(".png", "_768.png")
    subprocess.run(["sips", "-Z", "768", out, "--out", small], capture_output=True)
    print("sheet", out)
    print("sheet", small)
    return out


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    step = argv[0] if argv else "all"
    if step == "paint":
        sys.exit(0 if paint() else 1)
    elif step == "render":
        render()
    elif step == "sheet":
        sheet()
    elif step == "all":
        if not paint():
            sys.exit("T_EnvNursery_Alb failed its checks")
        cmd = [WITH_HEAVY, "--owner", "gulp-nursery-kit", "--game", "Gulp", "--", BLENDER, "--background", "--factory-startup",
               "--python", os.path.abspath(__file__), "--", "render"]
        r = subprocess.run(cmd, capture_output=True, text=True)
        tail = [ln for ln in (r.stdout + r.stderr).splitlines() if "rendered" in ln or "rror" in ln or "Traceback" in ln]
        print("\n".join(tail[-25:]))
        if r.returncode:
            sys.exit("render failed (%d)" % r.returncode)
        sheet()
    else:
        sys.exit("unknown step %s" % step)


if __name__ == "__main__":
    main()
