"""The four tiling ground textures and the shared environment atlas: task S5-A1 (docs/13-sprint-plan.md
Sprint 5; docs/07-asset-list.md section 6.1 rows T_Tile_Sand_Alb, T_Tile_Rock_Alb, T_Tile_CoralRock_Alb,
T_Tile_Slate_Alb and T_EnvShared_Alb; docs/06-art-bible.md 4.2, 5.1 to 5.6, 9.2, 9.3, 10.2, 15, 16.1).

    python3 assets/source/env/shared/tiles/build.py all          # paint, render (Blender), sheet
    python3 assets/source/env/shared/tiles/build.py paint        # textures, validation, tints
    python3 assets/source/env/shared/tiles/build.py sheet        # contact sheets from the renders
    <Blender> --background --python assets/source/env/shared/tiles/build.py -- render

Painting lives in assets/source/_shared/blender/tilegen.py (numpy). `paint` writes
assets/export/textures/T_*.png (8-bit sRGB, 24-bit) and assets/review/<name>/tiles_report.json
(seam numbers, L* spread, validation, the SurfaceAppearance.Color tint per zone). `render` puts each
texture on a flat floor running to the horizon and on a gently curved mound (64 studs across, 5 high),
repeating every 32 studs, under neutral review light and under each MVP zone's light and legacy fog
(06 10.2: FogStart 25% of the target view distance, FogEnd the distance, FogColor the zone fog), with
that zone's tint where the texture serves the zone. `sheet` lays out one 1536 x 1536 sheet per
texture: texture, 3 x 3 repeat, 400% crop over the wrap corner, the twelve renders, greyscale value,
numbers. `all` runs Blender through the machine-wide heavy-job pool (tools/with-heavy.sh).
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LIB = os.path.normpath(os.path.join(HERE, "..", "..", "..", "_shared", "blender"))
sys.path.insert(0, LIB)

import common  # noqa: E402
import tilegen  # noqa: E402

NAMES = tuple(tilegen.PAINTERS)
TEX_DIR = os.path.join(common.EXPORT_DIR, "textures")
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
WITH_HEAVY = os.environ.get("GULP_WITH_HEAVY", "/Users/bogdan/RobloxProjects/tools/with-heavy.sh")
RENDER_PX = 256

# 06 10.2 presets: (sun = ColorShift_Top, Brightness, OutdoorAmbient, fog colour, target view distance)
LIGHTS = {
    "neutral": ("#FFFFFF", 2.0, "#9A9A9A", "#808080", None),
    "nursery": ("#FFF3C4", 2.2, "#B8ECEC", "#4CCFD2", 450),
    "reef": ("#FFF0B8", 2.0, "#9ED8F0", "#1E9FD0", 400),
    "kelp": ("#E6FFB0", 1.4, "#7CCBA8", "#238A72", 260),
    "dropoff_upper": ("#BFE3FF", 1.2, "#5C93D9", "#1B6FBF", 320),
    "dropoff_deep": ("#8FB8FF", 0.6, "#3A5FA8", "#0B2A66", 200),
}
SHAPES = ("flat", "curved")


def tex_path(name):
    return os.path.join(TEX_DIR, name + ".png")


def review(name):
    return common.review_dir(name)


def zone_tint(name, zone):
    if name in tilegen.TILES and zone in tilegen.SERVES[name]:
        return tilegen.tints(name)[zone][2]
    return [1.0, 1.0, 1.0]


# ---------------------------------------------------------------- paint (system python3)
def paint():
    import numpy as np
    from PIL import Image
    os.makedirs(TEX_DIR, exist_ok=True)
    ok = True
    for name in NAMES:
        img = (np.clip(tilegen.PAINTERS[name](), 0, 1) * 255 + 0.5).astype(np.uint8)
        Image.fromarray(img).save(tex_path(name), optimize=True)
        back = np.asarray(Image.open(tex_path(name)).convert("RGB"))
        bad, st = tilegen.validate(name, back)
        rep = {"name": name, "file": tex_path(name), "size": list(back.shape[:2]), "stats": st,
               "validation": bad or "pass", "date": common.today(), "commit": common.git_commit()}
        if name in tilegen.TILES:
            rep["seam"] = tilegen.seam(back)
            rep["tints"] = {z: {"floor": t[0], "SurfaceAppearance.Color": t[1], "rgb": t[2]}
                            for z, t in tilegen.tints(name).items()}
            rep["studs_per_tile"] = tilegen.STUDS_PER_TILE
        else:
            rep["cells"] = tilegen.ATLAS_CELLS
        with open(os.path.join(review(name), "tiles_report.json"), "w") as f:
            json.dump(rep, f, indent=1)
        sm = rep.get("seam")
        print("%-22s %s  mean %s  L* %s/%s/%s  fine %.2f%s" % (
            name, "PASS" if not bad else "FAIL " + "; ".join(bad), st["mean"], st["L_p5"], st["L_p50"],
            st["L_p95"], st["fine_noise_L"],
            "  seam x %.2f (inner %.2f, max %.2f)  y %.2f (inner %.2f, max %.2f)" % (
                sm["x"]["wrap"], sm["x"]["inner_mean"], sm["x"]["inner_max"],
                sm["y"]["wrap"], sm["y"]["inner_mean"], sm["y"]["inner_max"]) if sm else ""))
        ok = ok and not bad
    return ok


# ---------------------------------------------------------------- render (inside Blender)
def render():
    import math
    import bpy
    from mathutils import Vector

    lin = common.hex_to_linear
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.eevee.taa_render_samples = 16
    sc.render.resolution_x = sc.render.resolution_y = RENDER_PX
    sc.render.image_settings.file_format = 'PNG'
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'None'

    def mesh_obj(name, verts, faces):
        me = bpy.data.meshes.new(name)
        me.from_pydata(verts, [], faces)
        me.update()
        for p in me.polygons:
            p.use_smooth = True
        ob = bpy.data.objects.new(name, me)
        sc.collection.objects.link(ob)
        return ob

    big = 6000.0
    floor = mesh_obj("Floor", [(-big, -big, 0), (big, -big, 0), (big, big, 0), (-big, big, 0)], [(0, 1, 2, 3)])
    R, H, n = 32.0, 5.0, 64
    verts, faces = [], []
    for j in range(n + 1):
        for i in range(n + 1):
            x, y = -R + 2 * R * i / n, -R + 2 * R * j / n
            r = math.hypot(x, y) / R
            z = H * (0.5 + 0.5 * math.cos(math.pi * min(r, 1.0))) + 0.6 * math.sin(x / 9.0) * (1 - min(r, 1.0))
            verts.append((x, y, z + 0.02))
    for j in range(n):
        for i in range(n):
            a = j * (n + 1) + i
            faces.append((a, a + 1, a + n + 2, a + n + 1))
    mound = mesh_obj("Mound", verts, faces)

    # material: planar world-space mapping (tile every 32 studs), zone tint, matte, legacy fog by distance
    mat = bpy.data.materials.new("M_Tile")
    mat.use_nodes = True
    nt = mat.node_tree
    nd, lk = nt.nodes, nt.links
    nd.clear()
    geo = nd.new("ShaderNodeNewGeometry")
    sca = nd.new("ShaderNodeVectorMath")
    sca.operation = 'SCALE'
    sca.inputs["Scale"].default_value = 1.0 / tilegen.STUDS_PER_TILE
    tex = nd.new("ShaderNodeTexImage")
    tex.extension = 'REPEAT'
    tint = nd.new("ShaderNodeVectorMath")
    tint.operation = 'MULTIPLY'
    dif = nd.new("ShaderNodeBsdfDiffuse")
    cam = nd.new("ShaderNodeCameraData")
    rng = nd.new("ShaderNodeMapRange")
    emi = nd.new("ShaderNodeEmission")
    mixs = nd.new("ShaderNodeMixShader")
    out = nd.new("ShaderNodeOutputMaterial")
    lk.new(geo.outputs["Position"], sca.inputs[0])
    lk.new(sca.outputs["Vector"], tex.inputs["Vector"])
    lk.new(tex.outputs["Color"], tint.inputs[0])
    lk.new(tint.outputs["Vector"], dif.inputs["Color"])
    lk.new(cam.outputs["View Distance"], rng.inputs["Value"])
    lk.new(rng.outputs["Result"], mixs.inputs[0])
    lk.new(dif.outputs[0], mixs.inputs[1])
    lk.new(emi.outputs[0], mixs.inputs[2])
    lk.new(mixs.outputs[0], out.inputs["Surface"])
    rng.clamp = True
    for ob in (floor, mound):
        ob.data.materials.append(mat)

    world = bpy.data.worlds.new("W")
    sc.world = world
    world.use_nodes = True
    wn, wl = world.node_tree.nodes, world.node_tree.links
    wn.clear()
    lp = wn.new("ShaderNodeLightPath")
    amb = wn.new("ShaderNodeBackground")
    bg = wn.new("ShaderNodeBackground")
    wmix = wn.new("ShaderNodeMixShader")
    wout = wn.new("ShaderNodeOutputWorld")
    wl.new(lp.outputs["Is Camera Ray"], wmix.inputs[0])
    wl.new(amb.outputs[0], wmix.inputs[1])
    wl.new(bg.outputs[0], wmix.inputs[2])
    wl.new(wmix.outputs[0], wout.inputs["Surface"])

    sun_data = bpy.data.lights.new("Key", 'SUN')
    sun_data.use_shadow = False                   # 06 15.3: no shadows, like the weakest phone
    sun = bpy.data.objects.new("Key", sun_data)
    sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(40), 0, math.radians(-30))

    cam_data = bpy.data.cameras.new("Cam")
    camo = bpy.data.objects.new("Cam", cam_data)
    sc.collection.objects.link(camo)
    sc.camera = camo
    views = {"flat": ((0, 80, 12), (0, 112, 0), 35), "curved": ((34, -34, 26), (0, 0, 2), 30)}

    for name in NAMES:
        img = bpy.data.images.load(tex_path(name), check_existing=False)
        img.colorspace_settings.name = 'sRGB'
        tex.image = img
        rdir = os.path.join(review(name), "renders")
        os.makedirs(rdir, exist_ok=True)
        for zone, (sunc, bright, ambc, fogc, dist) in LIGHTS.items():
            t = zone_tint(name, zone)
            tint.inputs[1].default_value = t
            emi.inputs["Color"].default_value = lin(fogc) + (1.0,)
            if dist is None:
                rng.inputs["From Min"].default_value, rng.inputs["From Max"].default_value = 1e6, 2e6
            else:
                rng.inputs["From Min"].default_value, rng.inputs["From Max"].default_value = 0.25 * dist, float(dist)
            sun_data.color = lin(sunc)
            sun_data.energy = 1.35 * bright
            amb.inputs["Color"].default_value = lin(ambc) + (1.0,)
            amb.inputs["Strength"].default_value = 0.45
            bg.inputs["Color"].default_value = lin(fogc) + (1.0,)
            bg.inputs["Strength"].default_value = 1.0
            for shape in SHAPES:
                loc, aim, lens = views[shape]
                camo.location = loc
                camo.rotation_euler = (Vector(aim) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
                cam_data.lens = lens
                cam_data.clip_end = 8000
                sc.render.filepath = os.path.join(rdir, "%s_%s.png" % (zone, shape))
                bpy.ops.render.render(write_still=True)
        print("rendered", name, flush=True)


# ---------------------------------------------------------------- sheet (system python3 + Pillow)
def sheet():
    import numpy as np
    from PIL import Image, ImageDraw, ImageFont

    def font(size):
        try:
            return ImageFont.load_default(size=size)
        except TypeError:
            return ImageFont.load_default()

    paths = []
    for name in NAMES:
        with open(os.path.join(review(name), "tiles_report.json")) as f:
            rep = json.load(f)
        tex = Image.open(tex_path(name)).convert("RGB")
        W = 1536
        sh = Image.new("RGB", (W, W), (34, 36, 42))
        d = ImageDraw.Draw(sh)
        f14, f18, f24 = font(14), font(18), font(24)
        # row A: texture 1:1, 3x3 repeat, 400% crop over the wrap corner (or the atlas cell map)
        sh.paste(tex, (0, 32))
        rep3 = Image.new("RGB", (1536, 1536))
        for j in range(3):
            for i in range(3):
                rep3.paste(tex, (i * 512, j * 512))
        sh.paste(rep3.resize((512, 512), Image.LANCZOS), (512, 32))
        corner = rep3.crop((512 - 64, 512 - 64, 512 + 64, 512 + 64)).resize((512, 512), Image.NEAREST)
        sh.paste(corner, (1024, 32))
        d.text((6, 6), "%s  512 x 512 (1:1)" % name, fill=(240, 240, 240), font=f18)
        is_tile = name in tilegen.TILES
        d.text((518, 6), "3 x 3 repeat (96 studs)" if is_tile else "3 x 3 repeat (atlas: not a tiling texture)",
               fill=(240, 240, 240), font=f18)
        d.text((1030, 6), "400%: wrap corner (seams cross at the centre)" if is_tile else "400%: atlas corner",
               fill=(240, 240, 240), font=f18)
        if not is_tile:
            for cell, (x, y, w, h) in tilegen.ATLAS_CELLS.items():
                d.rectangle((x, 32 + y, x + w - 1, 32 + y + h - 1), outline=(255, 255, 255))
                d.text((x + 4, 32 + y + 4), cell, fill=(255, 255, 255), font=f14)
        # rows B and C: renders, 256 each, 6 per row
        order = [(z, s) for z in LIGHTS for s in SHAPES]
        y0 = 32 + 512 + 28
        for k, (zone, shape) in enumerate(order):
            x, y = (k % 6) * 256, y0 + (k // 6) * 284
            p = os.path.join(review(name), "renders", "%s_%s.png" % (zone, shape))
            if os.path.exists(p):
                sh.paste(Image.open(p).convert("RGB").resize((256, 256), Image.LANCZOS), (x, y))
            t = zone_tint(name, zone)
            lab = "%s %s%s" % (zone, shape, "" if zone == "neutral" or t != [1.0, 1.0, 1.0] or not is_tile
                               else " (untinted)")
            d.text((x + 4, y - 22), lab, fill=(230, 230, 230), font=f14)
        # row D: greyscale value, 48 px thumbnail, numbers
        yD = y0 + 2 * 284 - 8
        grey = tex.convert("L").resize((384, 384), Image.LANCZOS)
        sh.paste(grey.convert("RGB"), (0, yD + 22))
        d.text((4, yD), "greyscale value", fill=(230, 230, 230), font=f14)
        sh.paste(tex.resize((48, 48), Image.LANCZOS), (400, yD + 22))
        d.text((400, yD), "48 px", fill=(230, 230, 230), font=f14)
        st = rep["stats"]
        lines = ["%s   date %s   commit %s" % (name, rep["date"], rep["commit"]),
                 "validation: %s" % (rep["validation"] if isinstance(rep["validation"], str)
                                     else "; ".join(rep["validation"])),
                 "mean %s%s   L* p5/p50/p95 %s / %s / %s   fine noise %.2f L*" % (
                     st["mean"], ("  (target %s)" % st["target"]) if "target" in st else "",
                     st["L_p5"], st["L_p50"], st["L_p95"], st["fine_noise_L"]),
                 "value shares: " + ", ".join("%s %.0f%%" % (k, v * 100) for k, v in st["shares"].items())]
        if is_tile:
            sm = rep["seam"]
            lines.append("seam (8-bit levels, wrap edge vs interior neighbours): x %.2f (mean %.2f, max %.2f)   "
                         "y %.2f (mean %.2f, max %.2f)" % (sm["x"]["wrap"], sm["x"]["inner_mean"], sm["x"]["inner_max"],
                                                          sm["y"]["wrap"], sm["y"]["inner_mean"], sm["y"]["inner_max"]))
            lines.append("repeats every %d studs (16 px per stud). SurfaceAppearance.Color per zone:" % rep["studs_per_tile"])
        else:
            lines.append("atlas cells (px, top-left origin): pebbles, shells, sea grass blades, eel-hole barnacle ring")
        ty = yD + 22
        for ln in lines:
            d.text((470, ty), ln, fill=(235, 235, 235), font=f18)
            ty += 28
        if is_tile:
            x = 470
            for zone, t in rep["tints"].items():
                d.rectangle((x, ty, x + 40, ty + 40), fill=common.hex_to_rgb255(t["floor"]))
                d.rectangle((x + 44, ty, x + 84, ty + 40), fill=common.hex_to_rgb255(t["SurfaceAppearance.Color"]))
                d.text((x + 90, ty + 2), "%s" % zone, fill=(235, 235, 235), font=f18)
                d.text((x + 90, ty + 22), "%s = tint %s" % (t["floor"], t["SurfaceAppearance.Color"]),
                       fill=(200, 200, 200), font=f14)
                x += 330
        out = os.path.join(review(name), "%s_sheet.png" % common.today())
        sh.save(out, optimize=True)
        paths.append(out)
        print("sheet", out)
    return paths


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    step = argv[0] if argv else "all"
    if step == "render":
        render()
    elif step == "paint":
        sys.exit(0 if paint() else 1)
    elif step == "sheet":
        sheet()
    elif step == "all":
        ok = paint()
        cmd = [WITH_HEAVY, "--owner", "gulp-tiles", "--game", "Gulp", "--", BLENDER, "--background",
               "--factory-startup", "--python", os.path.abspath(__file__), "--", "render"]
        r = subprocess.run(cmd, capture_output=True, text=True)
        tail = [ln for ln in (r.stdout + r.stderr).splitlines() if "rendered" in ln or "Error" in ln or "Traceback" in ln]
        print("\n".join(tail[-20:]))
        if r.returncode:
            sys.exit("render failed (%d)" % r.returncode)
        sheet()
        sys.exit(0 if ok else 1)
    else:
        sys.exit("unknown step %s" % step)


if __name__ == "__main__":
    main()
