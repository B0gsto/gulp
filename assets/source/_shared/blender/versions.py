"""The `shell` and `lod` steps: outline shells and distance versions of any finished mesh.

docs/07-asset-list.md section 14.1 tool row "Shell and distance-version script", built to
docs/06-art-bible.md section 13.2 (outlines), 6.4 (levels of detail), 6.3 (budgets) and the
07 section 1.2 rules for who has which shell.

    lod    every body mesh -> <name>_LOD1 (half the triangles) and <name>_LOD2 (a quarter):
           collapse decimation, mirrored on X, then vertex colours snapped back to the source
           colours and weights cleaned to 4 per vertex. Fails when a level exceeds its budget.
    shell  one clean hull per shell kind: the voxel-remeshed union of every part, pushed out
           along its smooth normals by the thickness and remeshed again (no inner fragments,
           folds merged). Each level's _Shell/_ShellThick is decimated from the level above,
           its corners snapped back to exactly the thickness from the body, faces that dip
           towards the body pushed clear, weights taken from the nearest body point, faces
           flipped. validate checks it lies outside the body and keeps an even width.

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
SHELL_SHARE = 0.4
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


def remesh(obj, voxel):
    """Voxel remesh in place: one closed surface around the union of every part; faces
    inside other parts, and folds, are gone."""
    for m in list(obj.modifiers):
        obj.modifiers.remove(m)
    mod = obj.modifiers.new("Remesh", 'REMESH')
    mod.mode = 'VOXEL'
    mod.voxel_size = voxel
    mod.adaptivity = 0.0
    dg = bpy.context.evaluated_depsgraph_get()
    new = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), depsgraph=dg)
    obj.modifiers.remove(mod)
    old = obj.data
    obj.data = new
    bpy.data.meshes.remove(old)
    new.name = obj.name


def keep_outer(mesh):
    """Drop the closed cavities a remesh can leave inside (parts with negative volume)."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    drop = []
    total = bm.calc_volume(signed=True)       # the outer surface sets the winding; cavities run the other way
    for comp in parts_of(bm):
        faces = {f for v in comp for f in v.link_faces}
        vol = sum(f.verts[0].co.dot(f.verts[k].co.cross(f.verts[k + 1].co))
                  for f in faces for k in range(1, len(f.verts) - 1))
        if vol * total <= 0.0:
            drop.extend(comp)
    if drop:
        bmesh.ops.delete(bm, geom=drop, context='VERTS')
    bm.to_mesh(mesh)
    bm.free()
    return len(drop)


def hull(src, name, distance):
    """The outline hull of 06 section 13.2 as one clean closed surface at an even distance:
    union of every part (voxel remesh), pushed out along its smooth normals, then
    remeshed again so the folds in concave corners (fin roots, eye sockets) merge away.
    Every level's shell is decimated from this one hull, so the width is the same at
    every level."""
    obj = copy_object(src, name, "SHELL")
    obj.parent = None
    obj.vertex_groups.clear()
    dims = [max(v.co[i] for v in obj.data.vertices) - min(v.co[i] for v in obj.data.vertices) for i in range(3)]
    size = max(dims) + 2.0 * distance
    remesh(obj, max(size / 400.0, min(distance / 6.0, 0.015)))
    before = volume(obj.data)
    normals = [v.normal.copy() for v in obj.data.vertices]
    sign = 1.0 if before > 0.0 else -1.0       # grow outward whatever way the remesh wound its faces
    for v, n in zip(obj.data.vertices, normals):
        v.co = v.co + n * distance * sign
    remesh(obj, max(size / 300.0, distance / 5.0))
    keep_outer(obj.data)
    if volume(obj.data) < 0.0:
        obj.data.flip_normals()
    print("[shell] hull %s: body volume %.3f, hull volume %.3f, extent %s" % (
        name, abs(before), volume(obj.data), ["%.2f" % (max(v.co[i] for v in obj.data.vertices) - min(v.co[i] for v in obj.data.vertices)) for i in range(3)]))
    return obj


def volume(mesh):
    bm = bmesh.new()
    bm.from_mesh(mesh)
    v = bm.calc_volume(signed=True)
    bm.free()
    return v


def snap_to_offset(mesh, tree, distance):
    """Put every vertex of a decimated hull back at exactly `distance` from the body, along
    the line from its nearest body point: decimation moves vertices off the offset surface,
    and this keeps the outline the same width at every level."""
    for v in mesh.vertices:
        loc = tree.find_nearest(v.co)[0]
        if loc is None:
            continue
        out = v.co - loc
        if out.length > 1e-9:
            v.co = loc + out.normalized() * distance
    mesh.update()
    # A coarse level's flat faces cut chords into the body between vertices: push the corners
    # of any face whose centre is closer than half the thickness out until it clears.
    for _ in range(12):
        push = {}
        for p in mesh.polygons:
            c = p.center
            loc = tree.find_nearest(c)[0]
            gap = (c - loc).length if loc is not None else distance
            if gap < 0.5 * distance:
                for vi in p.vertices:
                    push[vi] = max(push.get(vi, 0.0), 0.5 * distance - gap + 0.05 * distance)
        if not push:
            break
        for vi, amount in push.items():
            v = mesh.vertices[vi]
            near = tree.find_nearest(v.co)[0]
            out = v.co - near
            width = min(out.length + amount, SHELL_WIDTH[3] * distance)     # never past the width ceiling
            v.co = near + out.normalized() * width
        mesh.update()


# Outline width, measured at shell corners and face centres, in multiples of the thickness
# (06 13.2): nearest at least, mean between, farthest at most, and the spread (coefficient of
# variation) at most. (tune)
SHELL_WIDTH = (0.5, 0.8, 1.3, 1.6, 0.25)


def width_ok(m, d):
    lo, mean_lo, mean_hi, hi, cv = SHELL_WIDTH
    return m["min"] >= lo * d and mean_lo * d <= m["mean"] <= mean_hi * d and m["max"] <= hi * d and m["cv"] <= cv


def transfer_weights(obj, source):
    """Each shell vertex takes the weights of the nearest point of the body (blended over
    that face's corners), at most 4, normalised: same bones, same motion."""
    sm = source.data
    names = {g.index: g.name for g in source.vertex_groups}
    if not names:
        return
    sw = [{names[g.group]: g.weight for g in v.groups if g.group in names} for v in sm.vertices]
    tree = BVHTree.FromPolygons([v.co for v in sm.vertices], [list(p.vertices) for p in sm.polygons])
    for n in names.values():
        if n not in obj.vertex_groups:
            obj.vertex_groups.new(name=n)
    for v in obj.data.vertices:
        loc, _, fi, _ = tree.find_nearest(v.co)
        acc = {}
        corners = sm.polygons[fi].vertices
        for vi in corners:
            k = 1.0 / ((sm.vertices[vi].co - loc).length + 1e-6)
            for bone, w in sw[vi].items():
                acc[bone] = acc.get(bone, 0.0) + w * k
        for bone, w in meshgen.clean_weights(acc).items():
            obj.vertex_groups[bone].add([v.index], w, 'REPLACE')


def shell_metrics(shell, body, level_body):
    """For validate: distance from every shell vertex to the full body (the outline width),
    and shell points (vertices and face centres) that lie inside any part of the level's body."""
    bm = bmesh.new()
    bm.from_mesh(body.data)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    # The visible band lies between the corners and the flat faces between them: sample both.
    dist = [tree.find_nearest(v.co)[3] for v in shell.data.vertices] + [tree.find_nearest(p.center)[3] for p in shell.data.polygons]
    lb = bmesh.new()
    lb.from_mesh(level_body.data)
    lb.normal_update()
    part_trees = []
    for comp in parts_of(lb):
        faces = list({f for v in comp for f in v.link_faces})
        co = [v.co for v in comp]
        box = [(min(c[i] for c in co), max(c[i] for c in co)) for i in range(3)]
        part_trees.append((box, BVHTree.FromPolygons([v.co.copy() for v in lb.verts], [[v.index for v in f.verts] for f in faces])))
    lb.free()
    points = [v.co for v in shell.data.vertices] + [p.center for p in shell.data.polygons]
    ray = Vector((0.5773, 0.5774, 0.5775)).normalized()     # odd direction: no grazing along axes
    inside = 0
    for p in points:
        for box, t in part_trees:
            if not all(box[i][0] <= p[i] <= box[i][1] for i in range(3)):
                continue
            hits, origin = 0, p.copy()
            for _ in range(64):
                loc = t.ray_cast(origin, ray)[0]
                if loc is None:
                    break
                hits += 1
                origin = loc + ray * 1e-5
            if hits % 2 == 1:           # ray parity: an odd number of crossings means inside this closed part
                inside += 1
                break
    mean = sum(dist) / len(dist)
    sd = (sum((x - mean) ** 2 for x in dist) / len(dist)) ** 0.5
    return {"min": round(min(dist), 4), "mean": round(mean, 4), "max": round(max(dist), 4),
            "cv": round(sd / mean, 3), "inside_points": inside, "points": len(points)}


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
    if triangles(obj.data) > 12 * target:      # big steps collapse small meshes to nothing: go down in stages
        decimate(obj, 4 * target)
    saved = [(m.name, m.object) for m in obj.modifiers if m.type == 'ARMATURE']
    for m in list(obj.modifiers):
        obj.modifiers.remove(m)
    source = obj.data
    ratio = target / float(triangles(source))
    lo, hi, best, best_got = 0.0, 1.0, None, -1
    for attempt in range(14):            # bisect the ratio: the most triangles at or under the target
        mod = obj.modifiers.new("Decimate", 'DECIMATE')
        mod.decimate_type = 'COLLAPSE'
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
        mod.use_symmetry = attempt < 10      # mirrored on X unless that cannot reach the target
        mod.symmetry_axis = 'X'
        dg = bpy.context.evaluated_depsgraph_get()
        new = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
        obj.modifiers.remove(mod)
        got = triangles(new)
        if got <= target and got > best_got:
            if best is not None:
                bpy.data.meshes.remove(best)
            best, best_got = new, got
            lo = ratio
        else:
            bpy.data.meshes.remove(new)
            if got > target:
                hi = ratio
        if best_got >= 0.95 * target:
            break
        ratio = (lo + hi) / 2.0 if best is not None or attempt else ratio * 0.97 * target / max(got, 1)
        if best is None and hi < 1.0 and lo == 0.0:
            ratio = min(ratio, hi * 0.97 * target / max(got, 1))
    new = best if best is not None else bpy.data.meshes.new_from_object(obj)
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


def rigid_lod(spec, lod):
    """06 6.4: a prey's LOD2 is rigid (whole-body wobble only), and so is its shell."""
    return plan(spec)["outline"] == "prey" and lod == "LOD2"


def make_rigid(obj):
    """Unskinned and unparented, at the world transform it had (the rest pose)."""
    world = obj.matrix_world.copy()
    for m in list(obj.modifiers):
        obj.modifiers.remove(m)
    obj.vertex_groups.clear()
    obj.parent = None
    obj.matrix_world = world


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
            rigid = rigid_lod(spec, lod)
            if rigid:
                make_rigid(obj)
                new["skinned"] = False
            _register(spec, new, [obj] + ([spec["armature"]] if spec.get("armature") and not rigid else []))
            made.append((name, triangles(obj.data), target))
            print("[lod] %s %d triangles (target %d)" % (name, triangles(obj.data), target))
    return made


def run_shell(spec):
    rest_pose(spec)
    p = plan(spec)
    made = []
    for entry in _body_entries(spec):
        body = entry["object"]
        levels = [(body, None)] + [(e["object"], e["lod"]) for e in spec["meshes"]
                                   if e.get("of") == body.name and e.get("lod") and e["role"] == "body"]
        lo, hi = meshgen_bounds_z(body)
        height = spec["size"][2] if entry.get("primary") and spec.get("size") else hi - lo
        budget = entry.get("budget", spec["budget"])
        for kind in p["shells"]:
            d = thickness(spec, height, thick=(kind == "ShellThick"))
            outer = hull(body, "%s_%s_hull" % (body.name, kind), d)
            prev, spare = outer, [outer]
            bmb = bmesh.new()
            bmb.from_mesh(body.data)
            body_tree = BVHTree.FromBMesh(bmb)
            bmb.free()
            for src, lod in levels:
                name = "%s_%s" % (src.name, kind)
                target = budgets.tri_budget(budget, "shell", lod=lod, body_tris=spec.get("body_tris") or triangles(body.data))
                if p["outline"] != "prey":
                    # 06 13.2: about 40% of the level. Prey keep the 06 6.3 numbers, which sit above 40%
                    # for tier 1 and for LOD2 so the line stays even (6.3).
                    target = min(target, max(12, int(round(SHELL_SHARE * triangles(src.data)))))
                # Each level is decimated from the level above (smoother than one big step). It must
                # have no folds, no point inside the body and an even width (SHELL_WIDTH). If the 06 6.3
                # budget cannot hold that, the triangles are raised in 25% steps up to the body's own
                # count, and the raise is recorded for validate and the owner (never silent).
                tries = [int(target * f) for f in (1.0, 0.94, 0.88)]
                tries += [int(target * 1.25 ** k) for k in range(1, 12) if target * 1.25 ** k <= triangles(body.data)]
                chosen = None
                for want in tries:
                    obj = copy_object(prev, name, "SHELL")
                    decimate(obj, want)
                    snap_to_offset(obj.data, body_tree, d)
                    bm = bmesh.new()
                    bm.from_mesh(obj.data)
                    folds = self_intersections(bm)
                    bm.free()
                    m = shell_metrics(obj, body, src) if folds == 0 else None
                    if m and m["inside_points"] == 0 and width_ok(m, d):
                        chosen = want
                        break
                    print("[shell] %s try %d: %d folds%s" % (name, want, folds, "" if not m else
                          ", %d points inside, width %.3f to %.3f, mean %.3f, cv %.2f for %.3f" % (m["inside_points"], m["min"], m["max"], m["mean"], m["cv"], d)))
                    if want != tries[-1]:
                        bpy.data.meshes.remove(obj.data)
                raised = triangles(obj.data) > target
                prev = copy_object(obj, "%s_next" % name, "SHELL")
                spare.append(prev)
                mesh = obj.data
                if not mesh.uv_layers:
                    mesh.uv_layers.new(name=common.UV_NAME)
                for c in list(mesh.color_attributes):
                    mesh.color_attributes.remove(c)
                mesh.color_attributes.new(common.COLOR_ATTR, 'BYTE_COLOR', 'CORNER')
                mesh.attributes.active_color_name = common.COLOR_ATTR
                set_flat_colour(mesh, common.colour(SHELL_COLOUR[kind]))
                mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
                rigid = bool(lod) and rigid_lod(spec, lod)
                obj.vertex_groups.clear()
                if spec.get("armature") and not rigid:
                    obj.parent = spec["armature"]
                    transfer_weights(obj, body)
                    meshgen.skin(obj, spec["armature"])
                mesh.flip_normals()
                mesh.materials.clear()
                mesh.materials.append(template.flat_material("MAT_" + name, common.colour(SHELL_COLOUR[kind]), culling=True))
                mesh.update()
                bm = bmesh.new()
                bm.from_mesh(mesh)
                crossings = self_intersections(bm)
                bm.free()
                new = {"object": obj, "role": "shell", "lod": lod, "of": src.name, "thickness": round(d, 4),
                       "self_intersections": crossings, "body": body, "level_body": src}
                if raised:
                    new["shell_budget_raised"] = {"bible": target, "used": triangles(mesh)}
                    print("[shell] %s: 06 6.3 budget %d cannot hold an even hull; raised to %d (logged deviation)"
                          % (name, target, triangles(mesh)))
                if "budget" in entry:
                    new["budget"] = entry["budget"]
                if rigid:
                    new["skinned"] = False
                _register(spec, new, [obj] + ([spec["armature"]] if spec.get("armature") and not rigid else []))
                made.append(name)
                print("[shell] %s %.3f studs, %d triangles (budget %s), %d crossings"
                      % (name, d, triangles(mesh), target, crossings))
            for o in spare:
                bpy.data.meshes.remove(o.data)
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
        variants = [("", [obj])]
        for sh in shells:
            suffix = sh["object"].name.replace(obj.name, "")
            variants += [(suffix, [obj, sh["object"]]), (suffix + " alone", [sh["object"]])]
        for suffix, objs in variants:
            label = (obj.name.replace(name, "") or "LOD0") + suffix
            path = os.path.join(tmp, "%s.png" % label.strip("_").replace(" ", "_"))
            preview.shot("Side", objs, path, frame=objs)
            tris = "; ".join("%d tris" % triangles(o.data) for o in objs[-1:])
            extra = by_name[objs[-1].name]
            w = extra.get("width") or {}
            cap = [tris + ("" if extra["role"] != "shell" else ", %.3f studs; width %.3f to %.3f, %d inside"
                           % (extra["thickness"], w.get("min", 0), w.get("max", 0), w.get("inside_points", -1)))]
            cells.append({"title": label, "image": path, "caption": cap})
    if spec.get("uv"):
        cells.append({"title": "UV layout", "uv": uvlayout.review_image(spec, None),
                      "caption": ["density %s px/stud" % ", ".join("%s %s" % (e["object"].name.replace(name, "") or "LOD0", e["texel_density"])
                                                                  for e in spec["meshes"] if e.get("texel_density"))]})
    if not spec.get("versions_made"):
        p = plan(spec)
        cells[0]["caption"] = cells[0].get("caption", []) + [
            "no LODs or shells for %s: 07 1.2 / 06 6.4 (%s)" % (spec.get("category"),
            "scenery uses the engine's automatic versions" if spec.get("category") in ("Env", "Cove", "Prop", "Trait", "Hazard")
            else "lods %s, shells %s" % (p["lods"] or "none", p["shells"] or "none"))]
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
