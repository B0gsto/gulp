"""The `shell` and `lod` steps: outline shells and distance versions of any finished mesh.

docs/07-asset-list.md section 14.1 tool row "Shell and distance-version script", built to
docs/06-art-bible.md section 13.2 (outlines), 6.4 (levels of detail), 6.3 (budgets) and the
07 section 1.2 rules for who has which shell.

    lod    every body mesh -> <name>_LOD1 (half the triangles) and <name>_LOD2 (a quarter):
           collapse decimation, mirrored on X, then vertex colours snapped back to the source
           colours and weights cleaned to 4 per vertex. Fails when a level exceeds its budget.
    shell  every body level -> <level>_Shell and/or <level>_ShellThick: the level is trimmed of
           parts that sit inside the grown body, decimated to the shell budget (about 40%),
           and each closed part is grown along its own normals (even thickness, so thin fins
           grow as much as the body), then the faces are flipped. Same bones, same weights.

Who gets what comes from the spec's category (07 section 1.2 and 06 section 6.4); a build may
override it with spec["versions"] = {"lods": [...], "shells": [...], "outline": "player"|"prey"}.
"""
import math

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

import budgets
import common
import meshgen
import template

SHELL_COLOUR = {"Shell": "signal.can_eat", "ShellThick": "signal.can_eat_you"}   # 06 section 13.2
THICK_FACTOR = 1.5
THICK_ONLY = ("gull", "moray", "old_scar")      # 07 section 1.2: they cannot be eaten
NO_OUTLINE = ("plankton", "hook")               # 06 section 13.2


# ---------------------------------------------------------------- who gets what

def plan(spec):
    """{"lods": [...], "shells": [...], "outline": "player" or "prey"} for this asset."""
    plan = {"lods": [], "shells": [], "outline": "player"}
    cat, ident = spec.get("category"), spec.get("id", "")
    budget = spec.get("budget", "")
    if cat == "Species":
        plan.update(lods=["LOD1", "LOD2"], shells=["Shell", "ShellThick"])
    elif cat == "Pred":
        plan.update(lods=["LOD1", "LOD2"], shells=["ShellThick"] if ident in THICK_ONLY else ["Shell", "ShellThick"])
    elif cat == "Prey" and ident not in NO_OUTLINE:
        tier = spec.get("tier") or (int(budget[-1]) if budget.startswith("prey_t") else 3)
        plan.update(lods=["LOD2"] if tier >= 3 else [], shells=["Shell"], outline="prey")
    plan.update(spec.get("versions") or {})
    return plan


def thickness(spec, body_height, thick=False):
    """06 section 13.2: players and predators 6% of body height, at least 0.12 studs;
    prey 10% of body height. The thick shell is 1.5 times that."""
    if plan(spec)["outline"] == "prey":
        base = 0.10 * body_height
    else:
        base = meshgen.shell_thickness(body_height)
    return base * (THICK_FACTOR if thick else 1.0)


# ---------------------------------------------------------------- mesh helpers

def parts_of(bm):
    """Connected components as lists of BMVerts."""
    seen, out = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, comp = [v], []
        seen.add(v.index)
        while stack:
            cur = stack.pop()
            comp.append(cur)
            for e in cur.link_edges:
                o = e.other_vert(cur)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        out.append(comp)
    return out


def offset_vectors(bm, distance):
    """Even-thickness offset of every vertex along its angle-weighted normal: each face
    next to the vertex moves out by `distance`. Parts are disconnected, so every part
    grows along its own normals."""
    bm.normal_update()
    out = {}
    for v in bm.verts:
        n = Vector()
        for loop in v.link_loops:
            n += loop.face.normal * loop.calc_angle()
        if n.length < 1e-9:
            n = v.normal.copy()
        n.normalize()
        cos_min = min((n.dot(f.normal) for f in v.link_faces), default=1.0)
        out[v.index] = n * (distance / max(cos_min, 0.35))
    return out


def relax(bm, vectors, rounds):
    """Average each offset direction with its neighbours (length kept): unfolds concave spots."""
    for _ in range(rounds):
        new = {}
        for v in bm.verts:
            acc = vectors[v.index].copy()
            for e in v.link_edges:
                acc += vectors[e.other_vert(v).index]
            new[v.index] = acc.normalized() * vectors[v.index].length
        vectors = new
    return vectors


def self_intersections(bm):
    """Face pairs that cross inside one part (parts may overlap each other by design)."""
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    part_of = {}
    for i, comp in enumerate(parts_of(bm)):
        for v in comp:
            part_of[v.index] = i
    tree = BVHTree.FromBMesh(bm, epsilon=0.0)
    bad = 0
    for a, b in tree.overlap(tree):
        if a >= b:
            continue
        fa, fb = bm.faces[a], bm.faces[b]
        va, vb = {v.index for v in fa.verts}, {v.index for v in fb.verts}
        if va & vb or part_of[fa.verts[0].index] != part_of[fb.verts[0].index]:
            continue
        bad += 1
    return bad


def grow(mesh, distance):
    """Grow every part of `mesh` by `distance` in place. Returns self-intersecting face pairs
    left after up to three relax passes (0 is the goal)."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    base = [v.co.copy() for v in bm.verts]
    vectors = offset_vectors(bm, distance)
    bad = 0
    for attempt in range(4):
        if attempt:
            vectors = relax(bm, vectors, 2)
        for v in bm.verts:
            v.co = base[v.index] + vectors[v.index]
        bm.normal_update()
        bad = self_intersections(bm)
        if bad == 0:
            break
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    return bad


def hidden_parts(mesh, distance):
    """Indices (lists of vertex indices) of parts that, once grown, sit wholly inside
    another grown part: they would add triangles and draw nothing."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    vectors = offset_vectors(bm, distance)
    for v in bm.verts:
        v.co = v.co + vectors[v.index]
    bm.normal_update()
    comps = parts_of(bm)
    trees = []
    for comp in comps:
        idx = {v.index for v in comp}
        faces = {f for v in comp for f in v.link_faces}
        verts = [v.co.copy() for v in bm.verts]
        trees.append(BVHTree.FromPolygons(verts, [[v.index for v in f.verts] for f in faces]) if idx else None)
    hidden = []
    for i, comp in enumerate(comps):
        for j, tree in enumerate(trees):
            if i == j:
                continue
            inside = True
            for v in comp:
                hit = tree.find_nearest(v.co)
                if hit[0] is None or (hit[0] - v.co).dot(hit[1]) <= 0.0:
                    inside = False
                    break
            if inside:
                hidden.append([v.index for v in comp])
                break
    bm.free()
    return hidden


def delete_verts(mesh, indices):
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in indices], context='VERTS')
    bm.to_mesh(mesh)
    bm.free()


def triangles(mesh):
    return sum(len(p.vertices) - 2 for p in mesh.polygons)


def copy_object(src, name, collection):
    obj = src.copy()
    obj.data = src.data.copy()
    obj.name = name
    obj.data.name = name
    for coll in list(obj.users_collection):
        coll.objects.unlink(obj)
    template.link(obj, collection)
    return obj


def decimate(obj, target):
    """Collapse-decimate `obj` (mirrored on X) to at most `target` triangles, in place."""
    if triangles(obj.data) <= target:
        return
    saved = [(m.name, m.object) for m in obj.modifiers if m.type == 'ARMATURE']
    for m in list(obj.modifiers):
        obj.modifiers.remove(m)
    source = obj.data
    ratio = target / float(triangles(source))
    for _ in range(8):
        mod = obj.modifiers.new("Decimate", 'DECIMATE')
        mod.decimate_type = 'COLLAPSE'
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
        mod.use_symmetry = True
        mod.symmetry_axis = 'X'
        dg = bpy.context.evaluated_depsgraph_get()
        new = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
        obj.modifiers.remove(mod)
        got = triangles(new)
        if got <= target:
            break
        bpy.data.meshes.remove(new)
        ratio *= 0.97 * target / got
    name = source.name
    obj.data = new
    bpy.data.meshes.remove(source)
    new.name = name
    for mod_name, arm in saved:
        m = obj.modifiers.new(mod_name, 'ARMATURE')
        m.object = arm


def keep_parts_in_regions(mesh, layout, size):
    """Decimation can push a collapsed vertex's UV a little outside its part's island: pull
    every part's UVs back inside the layout region that holds the part's UV centre."""
    import texgen
    regions = texgen.FAMILY_LAYOUTS[layout]
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv = bm.loops.layers.uv.active
    for comp in parts_of(bm):
        loops = [l for v in comp for l in v.link_loops]
        cu = sum(l[uv].uv.x for l in loops) / len(loops)
        cv = sum(l[uv].uv.y for l in loops) / len(loops)
        for rect in regions.values():
            if rect[0] <= cu <= rect[2] and rect[1] <= cv <= rect[3]:
                u0, v0, u1, v1 = texgen.inner(rect, size)
                for l in loops:
                    l[uv].uv = (min(u1, max(u0, l[uv].uv.x)), min(v1, max(v0, l[uv].uv.y)))
                break
    bm.to_mesh(mesh)
    bm.free()


def tidy(obj, colours, source=None, uv=None):
    """After decimation: snap corner colours to the source's colours (no blended in-between
    values), keep UVs in 0..1 (and in their layout region), and keep at most 4 normalised
    weights per vertex; a vertex left with none takes the nearest source vertex's."""
    from mathutils.kdtree import KDTree
    mesh = obj.data
    if uv and uv.get("layout"):
        import texgen
        keep_parts_in_regions(mesh, uv["layout"], texgen.TEXTURE_CLASSES[uv["texture"]][0])
    col = mesh.color_attributes.get(common.COLOR_ATTR)
    if col and colours:
        for c in col.data:
            rgb = tuple(c.color_srgb)[:3]
            best = min(colours, key=lambda k: sum((a - b) ** 2 for a, b in zip(k, rgb)))
            c.color_srgb = (*best, 1.0)
    uv = mesh.uv_layers.get(common.UV_NAME)
    if uv:
        for d in uv.data:
            d.uv = (min(1.0, max(0.0, d.uv[0])), min(1.0, max(0.0, d.uv[1])))
    groups = {g.index: g for g in obj.vertex_groups}
    tree, src_w = None, None
    if source is not None and obj.vertex_groups:
        sg = {g.index: g.name for g in source.vertex_groups}
        src_w = [{sg[g.group]: g.weight for g in v.groups if g.group in sg} for v in source.data.vertices]
        tree = KDTree(len(source.data.vertices))
        for v in source.data.vertices:
            tree.insert(v.co, v.index)
        tree.balance()
    for v in mesh.vertices:
        w = {groups[g.group].name: g.weight for g in v.groups if g.group in groups}
        clean = meshgen.clean_weights(w)
        if not clean and tree is not None:
            clean = meshgen.clean_weights(src_w[tree.find(v.co)[1]])
            for name, value in clean.items():
                obj.vertex_groups[name].add([v.index], value, 'REPLACE')
            continue
        for index in [g.group for g in v.groups if g.group in groups]:   # remove first: v.groups shifts as it shrinks
            groups[index].remove([v.index])
        for name, value in clean.items():
            obj.vertex_groups[name].add([v.index], value, 'REPLACE')
    mesh.update()


def source_colours(obj):
    col = obj.data.color_attributes.get(common.COLOR_ATTR)
    return list({tuple(round(x, 4) for x in tuple(c.color_srgb)[:3]) for c in col.data}) if col else []


def set_flat_colour(mesh, hexcode):
    col = mesh.color_attributes.get(common.COLOR_ATTR)
    rgb = common.hex_to_srgb(hexcode)
    for c in col.data:
        c.color_srgb = (*rgb, 1.0)


# ---------------------------------------------------------------- the steps

def _body_entries(spec):
    return [e for e in spec["meshes"] if e["role"] == "body" and not e.get("lod") and not e.get("generated")]


def _register(spec, entry, objs_for_export):
    entry["generated"] = True
    spec["meshes"].append(entry)
    obj = entry["object"]
    root = spec.get("export_root")
    rel = "meshes/%s.fbx" % obj.name
    spec["exports"].append({"file": rel if not root else "%s/%s" % (root, rel), "objects": objs_for_export})
    for e in spec["exports"]:
        if e.get("all_versions"):
            e["objects"].insert(len(e["objects"]) - 1, obj)
    spec.setdefault("versions_made", []).append(obj.name)


def rest_pose(spec):
    """Evaluating the decimation updates the scene; keep the skeleton in its rest pose for
    that, so bone-parented pieces stay where validate expects them."""
    arm = spec.get("armature")
    if arm:
        arm.data.pose_position = 'REST'
        bpy.context.view_layer.update()


def run_lod(spec):
    rest_pose(spec)
    p = plan(spec)
    made = []
    for entry in _body_entries(spec):
        src = entry["object"]
        colours = source_colours(src)
        budget = entry.get("budget", spec["budget"])
        for lod in p["lods"]:
            name = "%s_%s" % (src.name, lod)
            obj = copy_object(src, name, "LOD")
            target = min(budgets.tri_budget(budget, "body", lod=lod),
                         int(triangles(src.data) * budgets.LOD_SHARE[lod]))
            decimate(obj, target)
            tidy(obj, colours, src, spec.get("uv"))
            new = {"object": obj, "role": "body", "lod": lod, "of": src.name}
            if "budget" in entry:
                new["budget"] = entry["budget"]
            _register(spec, new, [obj] + ([spec["armature"]] if spec.get("armature") else []))
            made.append((name, triangles(obj.data), target))
            print("[lod] %s %d triangles (target %d)" % (name, triangles(obj.data), target))
    return made


def run_shell(spec):
    rest_pose(spec)
    p = plan(spec)
    made = []
    levels = []
    for entry in _body_entries(spec):
        levels.append((entry, entry["object"], None))
        for e in spec["meshes"]:
            if e.get("of") == entry["object"].name and e.get("lod") and e["role"] == "body":
                levels.append((entry, e["object"], e["lod"]))
    for entry, src, lod in levels:
        lo, hi = meshgen_bounds_z(entry["object"])
        height = spec.get("size", (0, 0, hi - lo))[2] if entry.get("primary") else hi - lo
        budget = entry.get("budget", spec["budget"])
        for kind in p["shells"]:
            d = thickness(spec, height, thick=(kind == "ShellThick"))
            name = "%s_%s" % (src.name, kind)
            obj = copy_object(src, name, "SHELL")
            hidden = sorted({i for part in hidden_parts(obj.data, d) for i in part})
            if hidden:
                delete_verts(obj.data, hidden)
            target = budgets.tri_budget(budget, "shell", lod=lod, body_tris=spec.get("body_tris") or triangles(entry["object"].data))
            decimate(obj, target)
            tidy(obj, None, src)
            crossings = grow(obj.data, d)
            obj.data.flip_normals()
            set_flat_colour(obj.data, common.colour(SHELL_COLOUR[kind]))
            obj.data.materials.clear()
            obj.data.materials.append(template.flat_material("MAT_" + name, common.colour(SHELL_COLOUR[kind]), culling=True))
            obj.data.update()
            new = {"object": obj, "role": "shell", "lod": lod, "of": src.name, "thickness": round(d, 4),
                   "self_intersections": crossings, "parts_left_out": len(hidden)}
            if "budget" in entry:
                new["budget"] = entry["budget"]
            _register(spec, new, [obj] + ([spec["armature"]] if spec.get("armature") else []))
            made.append(name)
            print("[shell] %s %.3f studs, %d triangles (budget %s), %d hidden verts left out, %d crossings"
                  % (name, d, triangles(obj.data), target, len(hidden), crossings))
    return made


def meshgen_bounds_z(obj):
    zs = [v.co.z for v in obj.data.vertices]
    return min(zs), max(zs)


# ---------------------------------------------------------------- review sheet

def review_sheet(spec, report, ok):
    """<date>_versions.png beside the contact sheet: every level side-on, bare and inside each
    of its shells, then the UV map over the family layout. Built by sheet.py's grid mode."""
    import json
    import os
    import shutil
    import subprocess
    import tempfile

    import preview
    import uvlayout

    name = spec["name"]
    tmp = tempfile.mkdtemp(prefix="gulp_versions_")
    arm = spec.get("armature")
    if arm:
        meshgen.apply_pose(arm, None)
    by_name = {e["object"].name: e for e in spec["meshes"]}
    cells = []
    bodies = [e for e in spec["meshes"] if e["role"] == "body" and (e.get("primary") or e.get("of"))]
    for e in bodies:
        obj = e["object"]
        shells = [by_name[n] for n in spec.get("versions_made", []) if by_name[n]["role"] == "shell"
                  and by_name[n].get("of") == obj.name]
        variants = [("", [obj])] + [(s["object"].name.replace(obj.name, ""), [obj, s["object"]]) for s in shells]
        for suffix, objs in variants:
            label = (obj.name.replace(name, "") or "LOD0") + suffix
            path = os.path.join(tmp, "%s.png" % label.strip("_"))
            preview.shot("Side", objs, path, frame=objs)
            tris = "; ".join("%d tris" % triangles(o.data) for o in objs[-1:])
            extra = by_name[objs[-1].name]
            cap = [tris + ("" if extra["role"] != "shell" else ", %.3f studs, %d crossings, %d parts left out"
                           % (extra["thickness"], extra["self_intersections"], extra["parts_left_out"]))]
            cells.append({"title": label, "image": path, "caption": cap})
    if spec.get("uv"):
        cells.append({"title": "UV layout", "uv": uvlayout.review_image(spec, None),
                      "caption": ["density %s px/stud" % ", ".join("%s %s" % (e["object"].name.replace(name, "") or "LOD0", e["texel_density"])
                                                                  for e in spec["meshes"] if e.get("texel_density"))]})
    out = os.path.join(common.review_dir(name), "%s_versions.png" % common.today())
    failures = report.failures()
    job = {"grid": True, "out": out, "cols": 4, "cells": cells,
           "footer": ["%s distance versions and outline shells (06 6.4, 13.2) and UVs (06 5.4 to 5.6)" % name,
                      "%s    script commit %s    validation %s" % (common.today(), common.git_commit(),
                                                                   "PASS" if ok and not failures else "FAIL")]}
    job_path = os.path.join(tmp, "grid.json")
    with open(job_path, "w", encoding="utf-8") as f:
        json.dump(job, f)
    python = shutil.which("python3") or "/usr/bin/python3"
    done = subprocess.run([python, os.path.join(common.LIB_DIR, "sheet.py"), job_path], capture_output=True, text=True)
    if done.returncode != 0:
        raise RuntimeError("sheet.py grid failed:\n" + done.stdout + done.stderr)
    shutil.rmtree(tmp, ignore_errors=True)
    print("[versions] review sheet", out)
    return out
