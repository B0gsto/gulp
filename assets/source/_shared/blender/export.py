"""The `export` step (docs/06-art-bible.md sections 6.7 and 15.4): M_*.fbx and A_*.fbx.

The scale and axis constants below are what the calibration asset M_Prop_ScaleCube
confirms in Studio (06 section 6.1, spike S0-A1). Change them here and nowhere else.
"""
import os

import bpy

import common

# With unit system None, Blender's exporter writes UnitScaleFactor = 100 * global_scale when
# Apply Scalings is "FBX All" and leaves the vertex numbers untouched. 0.01 therefore
# writes "1 unit = 1 cm" and a 4-unit cube stays 4.0 in the file. Expected to import as
# 4 studs with the importer's Scale Unit on Stud; [U] until the Studio half of S0-A1.
FBX_GLOBAL_SCALE = 0.01
FBX_APPLY_SCALINGS = 'FBX_SCALE_ALL'
# Blender's exporter maps Blender +Y to the FBX "forward" given here. The bible puts the
# nose on Blender -Y and asks for Forward -Z, Up Y; whether the nose then lands on Roblox
# Front is the second thing S0-A1 confirms. If it lands on Back, set this to 'Z'.
FBX_AXIS_FORWARD = '-Z'
FBX_AXIS_UP = 'Y'
FBX_VERTEX_COLOURS = 'SRGB'      # [U]: S0-A1 reads the grey face back in Studio

BASE_SETTINGS = dict(
    use_selection=True,
    object_types={'MESH', 'ARMATURE'},
    global_scale=FBX_GLOBAL_SCALE,
    apply_unit_scale=True,
    apply_scale_options=FBX_APPLY_SCALINGS,
    axis_forward=FBX_AXIS_FORWARD,
    axis_up=FBX_AXIS_UP,
    use_space_transform=True,
    bake_space_transform=False,
    use_mesh_modifiers=True,         # apply modifiers
    use_triangles=True,              # triangulate
    mesh_smooth_type='OFF',          # smoothing "Normals Only"
    use_tspace=False,                # no tangents
    colors_type=FBX_VERTEX_COLOURS,
    prioritize_active_color=True,
    use_armature_deform_only=False,  # sockets must export
    add_leaf_bones=False,
    primary_bone_axis='Y',
    secondary_bone_axis='X',
    armature_nodetype='NULL',
    use_custom_props=False,
    path_mode='AUTO',
    embed_textures=False,            # textures are uploaded separately
    bake_anim=False,
)
ANIM_SETTINGS = dict(
    bake_anim=True,
    bake_anim_use_all_bones=True,            # key all bones
    bake_anim_use_nla_strips=False,
    bake_anim_use_all_actions=False,         # one action per file
    bake_anim_force_startend_keying=True,
    bake_anim_step=1.0,
    bake_anim_simplify_factor=0.0,           # no simplification
)


def recorded_settings():
    """The settings as plain data, for the report."""
    out = {}
    for key, value in {**BASE_SETTINGS, **ANIM_SETTINGS}.items():
        out[key] = sorted(value) if isinstance(value, set) else value
    out["bake_anim"] = "True for A_*.fbx and rig-test bundles, False for M_*.fbx"
    return out


def _props(elem):
    for child in elem.elems:
        if child.id == b'Properties70':
            return {p.props[0].decode(): list(p.props[4:]) for p in child.elems}
    return {}


def _name(raw):
    return raw.split(b'\x00\x01')[0].decode()


def inspect_fbx(path):
    """Reads back what was written: units, axes, node names, triangles, bones, clips."""
    from io_scene_fbx import parse_fbx
    root, version = parse_fbx.parse(path)
    info = {"file": os.path.relpath(path, common.REPO_DIR), "bytes": os.path.getsize(path), "fbx_version": version,
            "meshes": [], "bones": [], "nulls": [], "clips": [], "skin_clusters": 0, "anim_curves": 0, "parents": {}}
    uids, links = {}, []
    for elem in root.elems:
        if elem.id == b'GlobalSettings':
            p = _props(elem)
            info["unit_scale_factor"] = p.get("UnitScaleFactor", [None])[0]
            info["axes"] = {k: (p.get(k, [None])[0]) for k in
                            ("UpAxis", "UpAxisSign", "FrontAxis", "FrontAxisSign", "CoordAxis", "CoordAxisSign")}
        elif elem.id == b'Objects':
            geometry = []
            for obj in elem.elems:
                kind = obj.props[2] if len(obj.props) > 2 else b''
                if obj.id == b'Model':
                    name = _name(obj.props[1])
                    uids[obj.props[0]] = name
                    if kind == b'LimbNode':
                        info["bones"].append(name)
                    elif kind == b'Mesh':
                        p = _props(obj)
                        info["meshes"].append({"name": name, "lcl_rotation": p.get("Lcl Rotation"),
                                               "lcl_scaling": p.get("Lcl Scaling")})
                    else:
                        info["nulls"].append(name)
                elif obj.id == b'Geometry' and kind == b'Mesh':
                    g = {"name": _name(obj.props[1])}
                    for child in obj.elems:
                        if child.id == b'Vertices':
                            v = child.props[0]
                            g["vertices"] = len(v) // 3
                            g["min"] = [round(min(v[i::3]), 4) for i in range(3)]
                            g["max"] = [round(max(v[i::3]), 4) for i in range(3)]
                        elif child.id == b'PolygonVertexIndex':
                            idx = child.props[0]
                            polys = sum(1 for i in idx if i < 0)
                            g["polygons"] = polys
                            g["all_triangles"] = len(idx) == 3 * polys
                        elif child.id == b'LayerElementColor':
                            for sub in child.elems:
                                if sub.id == b'Colors':
                                    c = sub.props[0]
                                    rgb = {tuple(int(round(x * 255)) for x in c[i:i + 3]) for i in range(0, len(c), 4)}
                                    g["unique_colours"] = len(rgb)
                                    g["colours_rgb255"] = sorted(rgb)[:16]
                    geometry.append(g)
                elif obj.id == b'Deformer' and kind == b'Cluster':
                    info["skin_clusters"] += 1
                elif obj.id == b'AnimationStack':
                    p = _props(obj)
                    stop = p.get("LocalStop", [0])[0]
                    info["clips"].append({"name": _name(obj.props[1]), "seconds": round(stop / 46186158000.0, 4)})
                elif obj.id == b'AnimationCurve':
                    info["anim_curves"] += 1
            info["geometry"] = geometry
        elif elem.id == b'Connections':
            links = [(c.props[1], c.props[2]) for c in elem.elems if c.props[0] == b'OO']
    info["parents"] = {uids[child]: uids[parent] for child, parent in links if child in uids and parent in uids}
    return info


def export_file(entry, scene):
    path = os.path.join(common.EXPORT_DIR, entry["file"])
    os.makedirs(os.path.dirname(path), exist_ok=True)
    known = set(bpy.ops.export_scene.fbx.get_rna_type().properties.keys())
    clip = entry.get("clip")
    settings = dict(BASE_SETTINGS)
    if clip:
        settings.update(ANIM_SETTINGS)
    dropped = sorted(k for k in settings if k not in known)
    settings = {k: v for k, v in settings.items() if k in known}

    armatures = [o for o in entry["objects"] if o.type == 'ARMATURE']
    saved_name, saved_range = scene.name, (scene.frame_start, scene.frame_end)
    for arm in armatures:
        arm.data.pose_position = 'POSE' if clip else 'REST'
    if clip:
        clip["armature"].animation_data.action = clip["action"]
        scene.frame_start, scene.frame_end = clip["start"], clip["end"]
        scene.frame_set(clip["start"])
        scene.name = clip["name"]            # the exporter names the one take after the scene
    detached = []
    if entry.get("at_origin"):               # a kit piece leaves its socket and exports at its own origin
        for obj in entry["objects"]:
            detached.append((obj, obj.parent, obj.parent_type, obj.parent_bone, obj.matrix_basis.copy()))
            obj.parent = None
            obj.matrix_basis.identity()
        bpy.context.view_layer.update()
    for obj in scene.objects:
        obj.select_set(False)
    for obj in entry["objects"]:
        obj.hide_set(False)
        obj.select_set(True)
    bpy.context.view_layer.objects.active = entry["objects"][0]
    try:
        result = bpy.ops.export_scene.fbx(filepath=path, **settings)
    finally:
        for obj, parent, parent_type, parent_bone, basis in detached:
            obj.parent, obj.parent_type, obj.parent_bone = parent, parent_type, parent_bone
            obj.matrix_basis = basis
        bpy.context.view_layer.update()
        scene.name = saved_name
        scene.frame_start, scene.frame_end = saved_range
        for arm in armatures:
            arm.data.pose_position = 'POSE'
        for obj in entry["objects"]:
            obj.select_set(False)
    if 'FINISHED' not in result:
        raise RuntimeError("FBX export of %s returned %s" % (entry["file"], result))
    info = inspect_fbx(path)
    info["dropped_settings"] = dropped
    return info


def run(spec, report):
    """Writes every file the asset lists and checks what landed in each."""
    scene = bpy.context.scene
    infos = []
    for entry in spec["exports"]:
        info = export_file(entry, scene)
        infos.append(info)
        name = os.path.basename(entry["file"])
        add = lambda check, ok, detail="": report.add(name, check, ok, detail)
        stem = name[:-4]
        import validate
        ok = name.endswith(".fbx") and (validate.RE_ACTION.match(stem) if stem.startswith("A_")
                                        else validate.mesh_name_problem(stem) is None)
        add("file naming", ok, entry["file"])
        add("units", abs((info.get("unit_scale_factor") or 0.0) - 1.0) < 1e-6,
            "UnitScaleFactor %s (global scale %s, %s)" % (info.get("unit_scale_factor"), FBX_GLOBAL_SCALE, FBX_APPLY_SCALINGS))
        ax = info.get("axes", {})
        add("axes", (ax.get("UpAxis"), ax.get("UpAxisSign"), ax.get("FrontAxis"), ax.get("FrontAxisSign")) == (1, 1, 2, 1),
            "UpAxis %s sign %s, FrontAxis %s sign %s, CoordAxis %s sign %s" % (
                ax.get("UpAxis"), ax.get("UpAxisSign"), ax.get("FrontAxis"), ax.get("FrontAxisSign"),
                ax.get("CoordAxis"), ax.get("CoordAxisSign")))
        want_meshes = sorted(o.name for o in entry["objects"] if o.type == 'MESH')
        got_meshes = sorted(m["name"] for m in info["meshes"])
        add("meshes", want_meshes == got_meshes and all(g.get("all_triangles") for g in info["geometry"]),
            "%s; %d triangles" % (", ".join(got_meshes), sum(g.get("polygons", 0) for g in info["geometry"])))
        arm = next((o for o in entry["objects"] if o.type == 'ARMATURE'), None)
        if arm:
            add("bones", sorted(info["bones"]) == sorted(b.name for b in arm.data.bones),
                "%d bones, %d skin clusters" % (len(info["bones"]), info["skin_clusters"]))
        for obj in entry["objects"]:
            if obj.type == 'MESH' and obj.parent_type == 'BONE' and obj.parent in entry["objects"]:
                add("piece on socket", info["parents"].get(obj.name) == obj.parent_bone,
                    "%s hangs from %s" % (obj.name, info["parents"].get(obj.name)))
        clip = entry.get("clip")
        if clip:
            seconds = (clip["end"] - clip["start"]) / common.FPS
            names = [c["name"] for c in info["clips"]]
            add("one action", names == [clip["name"]] and abs(info["clips"][0]["seconds"] - seconds) < 1e-3,
                "%s, %.4f s, %d curves" % (", ".join(names), info["clips"][0]["seconds"] if info["clips"] else 0.0, info["anim_curves"]))
        else:
            add("no animation", not info["clips"], "%d takes" % len(info["clips"]))
        if info["dropped_settings"]:
            add("exporter settings", False, "not accepted by this Blender: " + ", ".join(info["dropped_settings"]))
        print("[export] %s  %d bytes" % (entry["file"], info["bytes"]))
    return infos
