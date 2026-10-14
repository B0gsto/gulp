"""Kit sheet for the Rim (task S5-A2): every Rim piece and haze curtain placed on the ring by rimart.layout(),
24 M_Cove_Mouth (S5-A3) inserted, rendered under the Reef and Kelp light and legacy fog (06 10.2: FogStart
25% of the target view distance, FogEnd the distance, FogColor the zone fog) and under neutral light.

    python3 assets/source/env/rim/kit/build.py            # render (Blender, heavy-job pool) + sheet
    <Blender> --background --factory-startup --python assets/source/env/rim/kit/build.py -- render
    python3 assets/source/env/rim/kit/build.py sheet      # sheet only, from the renders

Writes assets/review/M_Env_Rim_Kit/renders/*.png and assets/review/M_Env_Rim_Kit/<date>_kit_sheet.png.
"""
import json
import math
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

import rimart as ra  # noqa: E402
import common  # noqa: E402

BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
WITH_HEAVY = os.environ.get("GULP_WITH_HEAVY", "/Users/bogdan/RobloxProjects/tools/with-heavy.sh")
REVIEW = common.review_dir("M_Env_Rim_Kit")
RENDERS = os.path.join(REVIEW, "renders")
PX = 512
# 06 10.2 presets: (sun = ColorShift_Top, Brightness, OutdoorAmbient, fog colour, target view distance)
LIGHTS = {
    "neutral": ("#FFFFFF", 2.0, "#9A9A9A", "#808080", None),
    "reef": ("#FFF0B8", 2.0, "#9ED8F0", "#1E9FD0", 400),
    "kelp": ("#E6FFB0", 1.4, "#7CCBA8", "#238A72", 260),
}


def polar(b, r, z):
    a = math.radians(b)
    return (r * math.sin(a), r * math.cos(a), z)


# (file, zone, camera, look at, lens or ('ortho', scale), caption)
SHOTS = [
    ("reef_west", "reef", polar(270, 255, -18), polar(270, 430, -26), 15,
     "Reef fog, 175 studs out: C18, gatepost (Wall_03), West Pass, gatepost, C19"),
    ("reef_cove", "reef", polar(279, 335, -20), polar(285, 402, -30), 22,
     "Reef fog: C19's mouth in its Wall_02, the gatepost and the pass edge"),
    ("reef_east", "reef", polar(90, 330, -28), polar(90, 700, -30), 22,
     "Reef fog through East Pass: the soft-launch edge, haze at r 620 (13 3.2)"),
    ("kelp_west", "kelp", polar(258, 700, -40), polar(270, 560, -28), 18,
     "Kelp fog: the Rim's outer face and West Pass from the Kelp"),
    ("kelp_edge", "kelp", polar(300, 800, -95), polar(303, 980, -95), 18,
     "Kelp fog at the world edge: M_Env_Blue_Haze at r 980"),
    ("kelp_end", "kelp", polar(30, 760, -70), polar(45, 760, -90), 18,
     "Kelp fog: the Kelp's north-east end, haze run straight (flattened)"),
    ("neutral_plan", "neutral", (0.0, 0.0, 1500.0), (0.0, 0.0, 0.0), ("ortho", 2080.0),
     "Neutral, plan: 24 coves, 4 passes, 6 buttresses, haze at r 980 / r 620"),
    ("neutral_west", "neutral", polar(248, 300, 130), polar(270, 470, -20), 20,
     "Neutral, from above the surface: the West segment snapped"),
    ("neutral_nursery", "neutral", polar(225, 330, 90), polar(225, 470, -10), 20,
     "Neutral: the Rim's ends at the Nursery bulge, capped by Wall_03"),
]


def render():
    import bpy
    from mathutils import Matrix, Vector
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
    sc.eevee.taa_render_samples = 16
    sc.render.resolution_x = sc.render.resolution_y = PX
    sc.render.image_settings.file_format = 'PNG'
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'None'
    for cname in ("GEO", "PREVIEW"):      # the template's collections, which the cove mouth's builder links into
        coll = bpy.data.collections.new(cname)
        sc.collection.children.link(coll)
    fog_nodes = []

    def fogged(mat, shader_out):
        """Wraps a material's surface in legacy fog by camera distance (06 10.2)."""
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

    def lit(name, image, tint, planar=False, per_copy=False):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        nt = mat.node_tree
        nt.nodes.clear()
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(image, check_existing=True)
        tex.extension = 'REPEAT'
        if planar:
            geo = nt.nodes.new("ShaderNodeNewGeometry")
            sca = nt.nodes.new("ShaderNodeVectorMath")
            sca.operation = 'SCALE'
            sca.inputs["Scale"].default_value = 1.0 / 32.0      # 07 6.1: ground tiles repeat every 32 studs
            nt.links.new(geo.outputs["Position"], sca.inputs[0])
            nt.links.new(sca.outputs["Vector"], tex.inputs["Vector"])
        mul = nt.nodes.new("ShaderNodeVectorMath")
        mul.operation = 'MULTIPLY'
        mul.inputs[1].default_value = tint
        dif = nt.nodes.new("ShaderNodeBsdfDiffuse")
        nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(tex.outputs["Color"], mul.inputs[0])
        if per_copy:                          # the layout's SurfaceAppearance.Color per placement
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
    rock = lit("Rock", ra.rim_texture_file()[1], (1.0, 1.0, 1.0), per_copy=True)
    sand_reef = lit("SandReef", os.path.join(tex_dir, "T_Tile_Sand_Alb.png"), tilegen.tints("T_Tile_Sand_Alb")["reef"][2], planar=True)
    sand_kelp = lit("SandKelp", os.path.join(tex_dir, "T_Tile_Sand_Alb.png"), tilegen.tints("T_Tile_Sand_Alb")["kelp"][2], planar=True)

    # pieces
    pieces = {}
    for name in ("M_Env_Rim_Wall_02", "M_Env_Rim_Wall_03", "M_Env_Rim_Pass_01", "M_Env_Rim_Pass_02"):
        ob = ra.build_piece(name)
        ob.data.materials.append(rock)
        pieces[name] = ob
    import importlib.util
    spec = importlib.util.spec_from_file_location("gulp_cove_mouth", os.path.join(ra.SOURCE, "cove", "mouth", "build.py"))
    mb = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mb)
    img, block, work = mb.ca.texture(mb.NAME)
    mouth_mat = lit("CoveMouth", work, (1.0, 1.0, 1.0))
    mouth, _, _ = mb.build_mesh(mouth_mat)
    mask = os.path.join(REVIEW, "T_Haze_Mask_work.png")
    from preyart import save_rgba
    save_rgba(mask, ra.haze_mask())
    haze_mat = ra.haze_material(mask, "#FFFFFF", "Haze")
    hz_tint = haze_mat.node_tree.nodes["Mix"].inputs[7]
    fogged(haze_mat, next(n for n in haze_mat.node_tree.nodes if n.type == 'MIX_SHADER' and n.outputs[0].links
                          and n.outputs[0].links[0].to_node.type == 'OUTPUT_MATERIAL').outputs[0])
    haze = ra.build_haze("Haze")
    haze.data.materials.append(haze_mat)

    def inst(src, matrix):
        c = src.copy()
        sc.collection.objects.link(c)
        c.matrix_world = matrix
        return c
    rot = lambda b: Matrix.Rotation(-math.radians(b), 4, 'Z')
    for it in ra.layout():
        c = inst(pieces[it["mesh"]], rot(it["bearing"]))
        k = int(it["tint"][1:3], 16) / 255.0
        c.color = (k, k, k, 1.0)
        if it["mesh"] == "M_Env_Rim_Wall_02":
            inst(mouth, rot(it["bearing"]) @ Matrix.Translation(ra.cove_origin()))
    for it in ra.haze_layout():
        if it["kind"] == "arc":
            k = it["radius"] / ra.HAZE_R
            inst(haze, rot(it["bearing"]) @ Matrix.Diagonal((k, k, 1.0, 1.0)))
        else:
            # straight run: the piece turned to lie along the bearing, flattened, facing the Kelp side
            b = it["bearing"]
            sx = 210.0 / (2.0 * ra.HAZE_R * math.sin(math.radians(ra.HAZE_SPAN / 2.0)))
            flat = Matrix.Translation((0.0, -ra.HAZE_R, 0.0))
            m = Matrix.Diagonal((sx, 0.25, 1.0, 1.0)) @ flat
            turn = Matrix.Rotation(math.radians(90.0 if it["side"] < 0 else -90.0), 4, 'Z')
            inst(haze, rot(b) @ Matrix.Translation((0.0, it["radius"], 0.0)) @ turn @ m)
    for src in list(pieces.values()) + [mouth, haze]:
        src.hide_render = True

    # floors: Reef sand disc at depth 60, the outer floor sloping 70 (by the Rim) to 170 (at the Blue)
    def floor(name, r0, r1, z_of, mat, n=96, rings=10):
        verts, faces = [], []
        for j in range(rings + 1):
            r = r0 + (r1 - r0) * j / rings
            for i in range(n):
                a = 2 * math.pi * i / n
                verts.append((r * math.sin(a), r * math.cos(a), z_of(r)))
        for j in range(rings):
            for i in range(n):
                faces.append((j * n + i, j * n + (i + 1) % n, (j + 1) * n + (i + 1) % n, (j + 1) * n + i))
        ob = ra.mesh_object(name, verts, faces)
        ob.data.materials.append(mat)
        return ob
    floor("FloorReef", 5.0, 420.0, lambda r: -60.0, sand_reef, rings=6)
    floor("FloorOut", 540.0, 1010.0, lambda r: -70.0 - 100.0 * max(0.0, min(1.0, (r - 560.0) / 440.0)), sand_kelp)

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
    sun_data.use_shadow = False
    sun = bpy.data.objects.new("Key", sun_data)
    sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(35), 0, math.radians(-30))
    cam_data = bpy.data.cameras.new("Cam")
    camo = bpy.data.objects.new("Cam", cam_data)
    sc.collection.objects.link(camo)
    sc.camera = camo
    os.makedirs(RENDERS, exist_ok=True)
    for fname, zone, loc, aim, lens, cap in SHOTS:
        sunc, bright, ambc, fogc, dist = LIGHTS[zone]
        for rng, emi in fog_nodes:
            emi.inputs["Color"].default_value = lin(fogc) + (1.0,)
            a, b = (1e6, 2e6) if dist is None else (0.25 * dist, float(dist))
            rng.inputs["From Min"].default_value, rng.inputs["From Max"].default_value = a, b
        hz_tint.default_value = lin(ra.FOG.get(zone, "#1E9FD0")) + (1.0,)
        sun_data.color = lin(sunc)
        sun_data.energy = 1.35 * bright
        amb.inputs["Color"].default_value = lin(ambc) + (1.0,)
        amb.inputs["Strength"].default_value = 0.45
        bg.inputs["Color"].default_value = lin(fogc if zone != "neutral" else "#3A4A5A") + (1.0,)
        camo.location = loc
        d = Vector(aim) - Vector(loc)
        camo.rotation_euler = d.to_track_quat('-Z', 'Y' if abs(d.normalized().z) < 0.99 else 'Y').to_euler()
        if isinstance(lens, tuple):
            cam_data.type = 'ORTHO'
            cam_data.ortho_scale = lens[1]
            camo.rotation_euler = (0.0, 0.0, 0.0)
        else:
            cam_data.type = 'PERSP'
            cam_data.lens = lens
        cam_data.clip_start, cam_data.clip_end = 0.5, 6000.0
        sc.render.filepath = os.path.join(RENDERS, fname + ".png")
        bpy.ops.render.render(write_still=True)
        print("rendered", fname, flush=True)
    tris = {n: len(o.data.polygons) for n, o in pieces.items()}
    tris["M_Env_Blue_Haze"] = len(haze.data.polygons)
    with open(os.path.join(RENDERS, "meta.json"), "w") as f:
        json.dump({"tris": tris, "placements": len(ra.layout()), "haze": len(ra.haze_layout())}, f)


def sheet():
    from PIL import Image, ImageDraw, ImageFont
    meta = json.load(open(os.path.join(RENDERS, "meta.json")))

    def font(size):
        for p in ("/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc"):
            if os.path.exists(p):
                return ImageFont.truetype(p, size)
        return ImageFont.load_default()
    f20, f15 = font(22), font(15)
    cols, cell, cap = 3, PX, 46
    rows = (len(SHOTS) + cols - 1) // cols
    W, H = cols * cell + 4 * 12, 70 + rows * (cell + cap + 12) + 60
    sh = Image.new("RGB", (W, H), (28, 30, 36))
    d = ImageDraw.Draw(sh)
    d.text((12, 14), "M_Env_Rim kit: Rim_Wall_02 x24 with M_Cove_Mouth, Wall_03 x6, Rim_Pass_01/_02 x4, Blue_Haze x28 (rimart.layout)", fill=(240, 240, 240), font=f20)
    d.text((12, 44), "06 10.2 legacy fog: Reef FogEnd 400, Kelp 260 (FogStart 25%); rock = T_Rim_Alb x per-copy tint; haze tinted with the zone fog",
           fill=(190, 190, 190), font=f15)
    for i, shot in enumerate(SHOTS):
        x = 12 + (i % cols) * (cell + 12)
        y = 70 + (i // cols) * (cell + cap + 12)
        sh.paste(Image.open(os.path.join(RENDERS, shot[0] + ".png")).convert("RGB").resize((cell, cell)), (x, y))
        d.text((x, y + cell + 4), "%d. %s" % (i + 1, shot[5]), fill=(230, 230, 230), font=f15)
        d.text((x, y + cell + 24), "%s fog" % shot[1] if shot[1] != "neutral" else "neutral light, no fog", fill=(160, 160, 160), font=f15)
    foot = "Triangles: " + ", ".join("%s %d" % (k.replace("M_Env_", ""), v) for k, v in sorted(meta["tris"].items()))
    d.text((12, H - 48), foot + "    %s    commit %s" % (common.today(), common.git_commit()), fill=(200, 200, 200), font=f15)
    out = os.path.join(REVIEW, "%s_kit_sheet.png" % common.today())
    sh.save(out, optimize=True)
    print("sheet", out)
    return out


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    step = argv[0] if argv else "all"
    if step == "render":
        render()
    elif step == "sheet":
        sheet()
    elif step == "all":
        cmd = [WITH_HEAVY, "--owner", "gulp-rim", "--game", "Gulp", "--", BLENDER, "--background", "--factory-startup",
               "--python", os.path.abspath(__file__), "--", "render"]
        r = subprocess.run(cmd, capture_output=True, text=True)
        tail = [ln for ln in (r.stdout + r.stderr).splitlines() if "rendered" in ln or "Error" in ln or "Traceback" in ln or "rror" in ln]
        print("\n".join(tail[-25:]))
        if r.returncode:
            sys.exit("render failed (%d)" % r.returncode)
        sheet()
    else:
        sys.exit("unknown step %s" % step)


if __name__ == "__main__":
    main()
