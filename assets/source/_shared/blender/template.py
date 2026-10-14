"""The scene template of docs/06-art-bible.md section 15.3.

`gulp_template.blend` (next to this file) is a build product (binaries are not committed):
`open_template()` writes it when it is missing or older than this file, then opens it.
"""
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

import common

COLLECTIONS = ("GEO", "RIG", "SHELL", "LOD", "SOCKETS", "HIGH", "PREVIEW")

# Camera views: name -> (look direction, up hint). The creature's nose is on -Y, up is +Z.
VIEWS = {
    "Side": ((-1.0, 0.0, 0.0), (0.0, 0.0, 1.0)),            # nose to the left
    "ThreeQuarter": ((-1.0, 1.0, -0.45), (0.0, 0.0, 1.0)),  # from front-left-above
    "Game": ((0.0, -math.cos(math.radians(25)), -math.sin(math.radians(25))), (0.0, 0.0, 1.0)),  # behind, 25 deg above
    "Top": ((0.0, 0.0, -1.0), (-1.0, 0.0, 0.0)),            # nose to the left
    "Front": ((0.0, 1.0, 0.0), (0.0, 0.0, 1.0)),
    "RearThreeQuarter": ((1.0, -1.0, -0.45), (0.0, 0.0, 1.0)),
}
TEMPLATE_CAMERAS = ("Side", "ThreeQuarter", "Game", "Top", "Front")

# Six backdrop cards "in the fog colours of section 4.2". The table has eight rows; the six
# kept are the underwater zones a soft-launch creature can be seen in (Trench is [P2]).
BACKDROP_ZONES = ("nursery", "reef", "kelp", "dropoff_upper", "dropoff_deep", "cove")

RENDER_SIZE = 384
# Review lighting, so a painted texture reads true in cells 1 to 4: a near-white key from above,
# front and the camera's side, a soft fill from below, and a near-neutral ambient carrying a
# fifth of the Sunlit Reef colour (06 15.3). A flank facing the side camera shows about 0.8
# of its albedo, the back about 0.95, the belly about 0.8; hue stays the painted hue. The
# earlier set-up (key from straight above, blue ambient at 0.35) lit a flank at about 0.2 of
# its albedo plus blue, which turned orange brown, cream teal and yellow olive.
KEY_STRENGTH = 1.7
FILL_STRENGTH = 0.8
AMBIENT_STRENGTH = 0.6
AMBIENT_REEF_SHARE = 0.2


def look_matrix(look, up, location=(0.0, 0.0, 0.0)):
    """World matrix of a camera or sun at `location` whose -Z axis points along `look`."""
    z = -Vector(look).normalized()
    x = Vector(up).cross(z).normalized()
    y = z.cross(x)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = Vector(location)
    return m


def link(obj, collection_name):
    bpy.data.collections[collection_name].objects.link(obj)
    return obj


def flat_material(name, hexcode, culling=False):
    """Unlit colour: backdrops, reference silhouettes, outline shells."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    if mat.node_tree is None:
        mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = (*common.hex_to_linear(hexcode), 1.0)
    emit.inputs["Strength"].default_value = 1.0
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    mat.use_backface_culling = culling
    mat.diffuse_color = (*common.hex_to_linear(hexcode), 1.0)
    return mat


def vertex_colour_material(name):
    """The one material of a vertex-coloured game mesh: matte, colour from the `Col` layer."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    if mat.node_tree is None:
        mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfDiffuse")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = common.COLOR_ATTR
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def _mesh_object(name, bm, collection_name, material=None):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    if material:
        mesh.materials.append(material)
    obj.hide_render = True
    return link(obj, collection_name)


def build_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.name = "GULP"

    # Units, frame rate, colour management.
    scene.unit_settings.system = 'NONE'
    scene.unit_settings.scale_length = 1.0
    scene.render.fps = common.FPS
    scene.render.fps_base = 1.0
    scene.display_settings.display_device = 'sRGB'
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'None'
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0

    # Small, fast previews: EEVEE, low samples, transparent film (sheet.py adds the backdrop).
    scene.render.engine = 'BLENDER_EEVEE'
    scene.eevee.taa_render_samples = 8
    scene.render.resolution_x = RENDER_SIZE
    scene.render.resolution_y = RENDER_SIZE
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '8'

    for name in COLLECTIONS:
        scene.collection.children.link(bpy.data.collections.new(name))

    # Ambient at the Sunlit Reef colour (06 section 10.2, Ambient).
    world = bpy.data.worlds.new("PREVIEW_World")
    if world.node_tree is None:
        world.use_nodes = True
    nt = world.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    reef = common.hex_to_linear(common.colour("preview.ambient_reef"))
    bg.inputs["Color"].default_value = (*(1.0 - AMBIENT_REEF_SHARE + AMBIENT_REEF_SHARE * c for c in reef), 1.0)
    bg.inputs["Strength"].default_value = AMBIENT_STRENGTH
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    scene.world = world

    # One soft key from above-front, no shadows (matches the weakest phone).
    sun = bpy.data.lights.new("PREVIEW_Key", 'SUN')
    sun.color = common.hex_to_linear(common.colour("preview.key_light"))
    sun.energy = KEY_STRENGTH
    sun.angle = math.radians(20)
    sun.use_shadow = False
    key = link(bpy.data.objects.new("PREVIEW_Key", sun), "PREVIEW")
    key.matrix_world = look_matrix((-0.5, 0.45, -0.75), (0.0, 0.0, 1.0), (20.0, -20.0, 30.0))
    fill_light = bpy.data.lights.new("PREVIEW_Fill", 'SUN')
    fill_light.color = (1.0, 1.0, 1.0)
    fill_light.energy = FILL_STRENGTH
    fill_light.angle = math.radians(45)
    fill_light.use_shadow = False
    fill = link(bpy.data.objects.new("PREVIEW_Fill", fill_light), "PREVIEW")
    fill.matrix_world = look_matrix((-0.6, 0.3, 0.75), (0.0, 0.0, 1.0), (20.0, -10.0, -25.0))

    # Cameras: orthographic, re-fitted to each asset by preview.py.
    for view in TEMPLATE_CAMERAS:
        look, up = VIEWS[view]
        cam = bpy.data.cameras.new("CAM_" + view)
        cam.type = 'ORTHO'
        cam.ortho_scale = 6.0
        cam.clip_start = 0.1
        cam.clip_end = 400.0
        obj = link(bpy.data.objects.new("CAM_" + view, cam), "PREVIEW")
        obj.matrix_world = look_matrix(look, up, -Vector(look).normalized() * 60.0)
    scene.camera = bpy.data.objects["CAM_Side"]

    # Six flat backdrop cards, parked behind the stage for hand viewing.
    for i, zone in enumerate(BACKDROP_ZONES):
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=8.0)
        card = _mesh_object("BG_" + zone, bm, "PREVIEW",
                            flat_material("PREVIEW_BG_" + zone, common.colour("water.%s.fog" % zone)))
        card.matrix_world = Matrix.Translation((-40.0, (i - 2.5) * 17.0, 0.0)) @ Matrix.Rotation(math.radians(90), 4, 'Y')

    # Reference objects: a 4-stud cube and tier-1 and tier-7 minnow silhouettes (06 section 6.2).
    ref_mat = flat_material("PREVIEW_Ref", common.colour("ui.ink"))
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=4.0)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0.0, 0.0, 2.0))
    cube = _mesh_object("REF_Cube4", bm, "PREVIEW", ref_mat)
    cube.location = (0.0, 30.0, 0.0)
    import fishshape   # late: fishshape -> meshgen -> template
    for name, scale in (("REF_Minnow_T1", 1.0), ("REF_Minnow_T7", 6.5)):
        ref = fishshape.silhouette(common.colour("ui.ink"), scale).to_object(name, "PREVIEW", material=ref_mat)
        ref.hide_render = True
        ref.location = (0.0, 40.0 if scale == 1.0 else 60.0, 0.0)
    return scene


def ensure_template():
    path = common.TEMPLATE_BLEND
    sources = [__file__, common.PALETTE_JSON, os.path.join(common.LIB_DIR, "fishshape.py"),
               os.path.join(common.LIB_DIR, "meshgen.py")]
    stale = (not os.path.exists(path)) or os.path.getmtime(path) < max(os.path.getmtime(s) for s in sources)
    if stale:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        build_scene()
        bpy.ops.wm.save_as_mainfile(filepath=path, check_existing=False)
        print("[template] wrote", path)
    return path


def open_template():
    bpy.ops.wm.open_mainfile(filepath=ensure_template())
    return bpy.context.scene
