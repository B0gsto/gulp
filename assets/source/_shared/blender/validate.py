"""The `validate` step (docs/06-art-bible.md section 15.4), first version.

Checks one asset against the budgets of section 6.3, the mesh rules of 6.5, the
conventions of 6.1 and the names of 6.6 / chapter 07 section 1.2. Any failed row fails
the build. Not in this version: size against every row of 6.2 (the asset states its own
expected size), fin thickness, interior faces, and the `palette` checks.
"""
import os
import re

import bmesh
import bpy
from mathutils import Matrix, Vector

import budgets
import uvlayout
import common

WORD = r"[A-Z][A-Za-z0-9]*"
SUFFIX_RANK = {"Juv": 1, "Adult": 1, "Puffed": 2, "Tucked": 2, "Glide": 2, "Dive": 2, "Open": 2,
               "Squeezed": 2, "LOD1": 3, "LOD2": 3, "Shell": 4, "ShellThick": 4}
RE_RIG = re.compile(r"^RIG_%s$" % WORD)
RE_ACTION = re.compile(r"^A_%s_%s$" % (WORD, WORD))
RE_BONE = re.compile(r"^%s(_(L|R|%s))?$" % (WORD, WORD))
RE_SOCKET = re.compile(r"^Sock_[A-Z][A-Za-z]*(_(L|R|\d\d))?$")


class Report:
    def __init__(self):
        self.rows = []

    def add(self, subject, check, ok, detail="", waiver=None):
        """A failed check passes only with a waiver: a stated reason, logged in the report."""
        waived = bool(not ok and waiver)
        if waived:
            detail = "WAIVED (%s): %s" % (waiver, detail)
        self.rows.append({"subject": subject, "check": check, "ok": bool(ok) or waived, "waived": waived,
                          "detail": str(detail)})
        return bool(ok) or waived

    @property
    def ok(self):
        return all(r["ok"] for r in self.rows)

    def failures(self):
        return [r for r in self.rows if not r["ok"]]

    def waived(self):
        return [r for r in self.rows if r.get("waived")]

    def print(self):
        for r in self.rows:
            print("[validate] %s  %-28s %-22s %s" % ("WAIV" if r.get("waived") else "PASS" if r["ok"] else "FAIL", r["subject"], r["check"], r["detail"]))
        print("[validate] %s: %d checks, %d failed, %d waived" % ("PASS" if self.ok else "FAIL", len(self.rows),
                                                                 len(self.failures()), len(self.waived())))


def mesh_name_problem(name):
    """None when `name` follows M_<Category>_<Name>[_Juv|_Adult][_<Form>][_LOD1|_LOD2][_Shell|_ShellThick]."""
    parts = name.split("_")
    if len(parts) < 3 or parts[0] != "M":
        return "must be M_<Category>_<Name>"
    if parts[1] not in common.CATEGORIES:
        return "category '%s' is not one of %s" % (parts[1], ", ".join(common.CATEGORIES))
    words = parts[2:]
    for w in words:
        if not (re.fullmatch(WORD, w) or re.fullmatch(r"\d\d", w)):
            return "'%s' is not a PascalCase word, a short code or a two-digit number" % w
    rank, seen_suffix = 0, False
    for i, w in enumerate(words):
        r = SUFFIX_RANK.get(w)
        if r is None:
            if seen_suffix:
                return "'%s' comes after a suffix; order is age, form, LOD, shell" % w
            continue
        if i == 0:
            return "no name before the suffix '%s'" % w
        if r <= rank:
            return "suffix '%s' is out of order (age, form, LOD, shell)" % w
        rank, seen_suffix = r, True
    return None


def triangle_count(mesh):
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def is_identity(matrix, eps=1e-5):
    ident = Matrix.Identity(len(matrix))
    return all(abs(matrix[i][j] - ident[i][j]) < eps for i in range(len(matrix)) for j in range(len(matrix)))


def bounds(mesh):
    xs, ys, zs = zip(*[tuple(v.co) for v in mesh.vertices])
    return Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))


def action_fcurves(action):
    try:
        return list(action.fcurves)
    except AttributeError:
        out = []
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    out.extend(bag.fcurves)
        return out


# ---------------------------------------------------------------- meshes

def check_mesh(spec, entry, report):
    obj = entry["object"]
    mesh = obj.data
    name = obj.name
    role, lod = entry["role"], entry.get("lod")
    add = lambda check, ok, detail="": report.add(name, check, ok, detail)

    problem = mesh_name_problem(name)
    add("naming", problem is None and mesh.name == name, problem or name)

    tris = triangle_count(mesh)
    entry["tris"] = tris
    body_tris = spec.get("body_tris")
    limit = budgets.tri_budget(entry.get("budget", spec["budget"]), "shell" if role == "shell" else "body",
                               lod=lod, body_tris=body_tris)
    entry["tri_budget"] = limit
    raised = entry.get("shell_budget_raised")
    report.add(name, "triangles", limit is not None and tris <= limit, "%d of %s" % (tris, limit),
               waiver=("06 6.3 shell budget %d cannot hold an even outline; raised to %d, logged for the owner in "
                       "spike/results/art-blender.md" % (raised["bible"], raised["used"])) if raised else None)
    floor = budgets.BUDGETS[entry.get("budget", spec["budget"])].get("tris_min")
    if floor and role != "shell" and not lod:
        add("triangles floor", tris >= floor, "%d, at least %d" % (tris, floor))

    slots = {p.material_index for p in mesh.polygons}
    add("one material", len(mesh.materials) == 1 and slots == {0}, "%d material(s)" % len(mesh.materials))

    uv_ok, uv_detail = len(mesh.uv_layers) == 1, "%d UV set(s)" % len(mesh.uv_layers)
    if uv_ok:
        flat = [0.0] * (2 * len(mesh.loops))
        mesh.uv_layers[0].data.foreach_get("uv", flat)
        lo, hi = min(flat), max(flat)
        uv_ok = lo >= -1e-6 and hi <= 1.0 + 1e-6
        uv_detail = "1 UV set, %.3f to %.3f" % (lo, hi)
    add("one UV set in 0..1", uv_ok, uv_detail)

    cols = [a.name for a in mesh.color_attributes]
    add("vertex colours", cols == [common.COLOR_ATTR], "layers: %s" % (", ".join(cols) or "none"))

    bm = bmesh.new()
    bm.from_mesh(mesh)
    open_edges = sum(1 for e in bm.edges if not (e.is_manifold and e.is_contiguous))
    loose = sum(1 for v in bm.verts if not v.link_faces)
    add("watertight", open_edges == 0 and loose == 0, "%d bad edges, %d loose verts" % (open_edges, loose))
    volume = bm.calc_volume(signed=True)
    if role == "shell":
        add("faces flipped", volume < 0.0, "signed volume %.4f (a shell shows its back faces)" % volume)
        if entry.get("body") is not None:
            import versions
            m = versions.shell_metrics(obj, entry["body"], entry["level_body"])
            entry["width"] = m
            d = entry["thickness"]
            add("shell outside body", m["inside_points"] == 0,
                "%d of %d shell points inside the body" % (m["inside_points"], m["points"]))
            add("shell width even", versions.width_ok(m, d),
                "corners and face centres %.3f to %.3f studs from the body (mean %.3f, cv %.2f) for %.3f; "
                "allowed min %.1fx, mean %.1fx to %.1fx, max %.1fx, cv %.2f" % ((m["min"], m["max"], m["mean"], m["cv"], d) + versions.SHELL_WIDTH))
        if "self_intersections" in entry:
            add("no self-intersection", entry["self_intersections"] == 0,
                "%d crossing face pairs inside a part; grown %.3f studs" % (entry["self_intersections"], entry["thickness"]))
    else:
        add("faces outward", volume > 0.0, "signed volume %.4f" % volume)
    min_area = min((f.calc_area() for f in bm.faces), default=0.0)
    min_edge = min((e.calc_length() for e in bm.edges), default=0.0)
    add("no thin faces", min_area > 1e-6 and min_edge > 1e-4, "smallest face %.6f, shortest edge %.5f" % (min_area, min_edge))
    bm.free()

    if obj.parent_type == 'BONE':
        scale = obj.matrix_world.to_scale()
        add("transforms applied", all(abs(s - 1.0) < 1e-5 for s in scale) and is_identity(obj.matrix_world.to_3x3()),
            "rigid piece on bone %s, world rotation and scale identity" % obj.parent_bone)
    else:
        add("transforms applied", is_identity(obj.matrix_world), "location, rotation and scale")

    armature = spec.get("armature")
    if armature and entry.get("skinned", True) and role != "piece":
        check_skin(obj, armature, add)
    elif role == "piece":
        socket = entry.get("socket")
        ok = (obj.parent is armature and obj.parent_type == 'BONE' and obj.parent_bone == socket
              and len(obj.vertex_groups) == 0) if socket else len(obj.vertex_groups) == 0
        add("rigid on socket", ok, "parent bone %s, %d vertex groups" % (obj.parent_bone or "none", len(obj.vertex_groups)))

    if entry.get("primary"):
        check_placement(spec, obj, add)


def check_skin(obj, armature, add):
    mesh = obj.data
    mods = [m for m in obj.modifiers if m.type == 'ARMATURE']
    add("skinned to rig", obj.parent is armature and len(mods) == 1 and mods[0].object is armature and len(obj.modifiers) == 1,
        "armature %s" % armature.name)
    bones = armature.data.bones
    names = {g.index: g.name for g in obj.vertex_groups}
    unknown = sorted(n for n in names.values() if n not in bones)
    over = unweighted = unnormalised = on_root = on_socket = 0
    most = 0
    used = set()
    for v in mesh.vertices:
        ws = [(names[g.group], g.weight) for g in v.groups if g.weight > 1e-6]
        most = max(most, len(ws))
        over += len(ws) > 4
        unweighted += len(ws) == 0
        unnormalised += bool(ws) and abs(sum(w for _, w in ws) - 1.0) > 1e-3
        on_root += any(n == "Root" for n, _ in ws)
        on_socket += any(n.startswith("Sock_") for n, _ in ws)
        used.update(n for n, _ in ws)
    add("weights: 4 per vertex", over == 0 and unweighted == 0, "most %d, %d over, %d unweighted" % (most, over, unweighted))
    add("weights: normalised", unnormalised == 0, "%d vertices off 1.0" % unnormalised)
    add("weights: none on Root", on_root == 0 and on_socket == 0, "%d on Root, %d on sockets" % (on_root, on_socket))
    add("weights: bones exist", not unknown, "%d bones used%s" % (len(used), (", unknown: " + ", ".join(unknown)) if unknown else ""))


def check_placement(spec, obj, add):
    mesh = obj.data
    lo, hi = bounds(mesh)
    size, centre = hi - lo, (lo + hi) / 2.0
    want = spec["size"]
    tol = spec.get("size_tol", 0.02)
    ok = all(abs(size[i] - want[i]) <= tol * want[i] for i in range(3))
    add("size", ok, "x %.3f  y %.3f  z %.3f studs, expected %s (within %.1f%%)" % (size.x, size.y, size.z, tuple(want), tol * 100))

    if spec["origin"] == "creature":
        ok = all(abs(centre[i]) <= 0.02 * want[i] for i in range(3))
        add("origin", ok, "body centre at (%.3f, %.3f, %.3f); origin is the middle of length and height" % tuple(centre))
    else:
        base = [v.co for v in mesh.vertices if v.co.z <= lo.z + 1e-4]
        bx = (min(p.x for p in base) + max(p.x for p in base)) / 2.0
        by = (min(p.y for p in base) + max(p.y for p in base)) / 2.0
        ok = abs(lo.z) < 1e-4 and abs(bx) < 0.01 * want[0] and abs(by) < 0.01 * want[1]
        add("origin", ok, "base at z %.4f, base centre (%.3f, %.3f); origin is the centre of the base" % (lo.z, bx, by))

    facing = spec.get("facing", {})
    if facing.get("kind") == "bones":
        bones = spec["armature"].data.bones
        front, back = bones[facing["front"]].head_local.y, bones[facing["back"]].head_local.y
        add("facing", front < 0.0 < back, "%s at y %.2f, %s at y %.2f; nose on -Y" % (facing["front"], front, facing["back"], back))
    elif facing.get("kind") == "tag":
        attr = mesh.attributes.get(common.TAG_ATTR)
        tagged = [v.co for v, t in zip(mesh.vertices, attr.data) if t.value == common.TAG_FRONT] if attr else []
        if tagged:
            cy = sum(p.y for p in tagged) / len(tagged)
            cx = sum(p.x for p in tagged) / len(tagged)
            ok = cy < centre.y - 0.25 * size.y and abs(cx - centre.x) < 0.25 * size.x
            add("facing", ok, "front marker centred at y %.2f; front is -Y" % cy)
        else:
            add("facing", False, "no vertices tagged as the front marker")
    else:
        add("facing", False, "the asset states no facing check")


BLOCK_RULES = {  # 06 section 4.1: share of surface, lightness
    "mid": ((55, 65), (45, 80)),
    "light": ((20, 30), (85, 100)),
    "dark": ((10, 15), (0, 35)),
    "accent": ((0, 5), (0, 100)),
}


# Barycentric sample points per triangle when a painted texture is measured: the centre,
# three points towards the corners and three towards the edge middles.
_SAMPLES = [(1 / 3, 1 / 3, 1 / 3)] + [tuple(0.6 if i == k else 0.2 for i in range(3)) for k in range(3)] \
    + [tuple(0.1 if i == k else 0.45 for i in range(3)) for k in range(3)]


def value_blocks(obj, declared, sampler=None):
    """Share of surface and L* of each declared colour block, from the vertex colours, or, for a
    textured asset, from its painted texture: `sampler(u, v)` returns (block name, sRGB colour)
    of the texel at that UV, so the shares are the painted blocks and the L* the painted colours
    (gradients, occlusion and highlights included)."""
    mesh = obj.data
    mesh.calc_loop_triangles()
    col = mesh.color_attributes[common.COLOR_ATTR]
    uvs = mesh.uv_layers.get(common.UV_NAME) if sampler else None
    targets = {name: common.hex_to_srgb(h) for name, h in declared.items()}
    area = {name: 0.0 for name in targets}
    light = {name: 0.0 for name in targets}
    for tri in mesh.loop_triangles:
        if uvs is not None:
            corners = [uvs.data[li].uv for li in tri.loops]
            for w in _SAMPLES:
                u = sum(c[0] * k for c, k in zip(corners, w))
                v = sum(c[1] * k for c, k in zip(corners, w))
                name, rgb = sampler(u, v)
                if name not in area:
                    continue
                area[name] += tri.area / len(_SAMPLES)
                light[name] += common.lstar_from_srgb(rgb) * tri.area / len(_SAMPLES)
            continue
        for li in tri.loops:
            rgb = tuple(col.data[li].color_srgb[:3])
            name = min(targets, key=lambda n: sum((a - b) ** 2 for a, b in zip(rgb, targets[n])))
            area[name] += tri.area / 3.0
            light[name] += common.lstar_from_srgb(rgb) * tri.area / 3.0
    total = sum(area.values()) or 1.0
    out = []
    for name in ("mid", "light", "dark", "accent"):
        if name not in targets or area[name] <= 0.0:
            continue
        share, lstar = 100.0 * area[name] / total, light[name] / area[name]
        (s0, s1), (l0, l1) = BLOCK_RULES[name]
        out.append({"block": name, "share": round(share, 1), "lstar": round(lstar, 1),
                    "share_ok": s0 <= share <= s1, "lstar_ok": l0 <= lstar <= l1,
                    "rule": "%d-%d%%, L* %d-%d" % (s0, s1, l0, l1)})
    return out


def check_values(spec, report):
    """06 section 4.1 (checklist line 5): every declared block inside its share and L* range.
    Checks the palette colours themselves and the area-weighted vertex colours of the body.
    A failure can only pass through a waiver the asset states, and the report says so."""
    declared = spec["preview"]["blocks"]
    body = next(e["object"] for e in spec["meshes"] if e.get("primary"))
    waivers = spec.get("waivers", {})
    for block, hexcode in declared.items():
        (l0, l1) = BLOCK_RULES[block][1]
        lstar = common.lstar(hexcode)
        check = "palette: %s L*" % block
        report.add(body.name, check, l0 <= lstar <= l1, "%s is L* %.1f, rule %d-%d" % (hexcode, lstar, l0, l1),
                   waiver=waivers.get(check))
    blocks = value_blocks(body, declared, spec.get("texture_sampler"))
    spec["value_blocks"] = blocks
    if spec.get("texture_sampler"):
        report.add(body.name, "value: measured on", True, "the painted texture (%s)" % spec.get("texture_name", "albedo"))
    for b in blocks:
        check = "value: %s share" % b["block"]
        report.add(body.name, check, b["share_ok"], "%.1f%% of the surface, rule %s" % (b["share"], b["rule"]),
                   waiver=waivers.get(check))
        check = "value: %s L*" % b["block"]
        report.add(body.name, check, b["lstar_ok"], "L* %.1f, rule %s" % (b["lstar"], b["rule"]), waiver=waivers.get(check))


# ---------------------------------------------------------------- rig and clips

def check_rig(spec, report):
    arm = spec["armature"]
    family = spec["rig"]
    add = lambda check, ok, detail="": report.add(arm.name, check, ok, detail)
    bones = arm.data.bones
    want = budgets.FAMILIES[family]

    add("naming", bool(RE_RIG.match(arm.name)) and arm.name == "RIG_" + family and arm.data.name == arm.name, arm.name)
    sockets = [b.name for b in bones if b.name.startswith("Sock_")]
    deform = [b.name for b in bones if not b.name.startswith("Sock_")]
    spec["bone_counts"] = {"deform": len(deform), "sockets": len(sockets), "total": len(bones)}
    missing = sorted(set(want["deform"]) - set(deform))
    extra = sorted(set(deform) - set(want["deform"]))
    add("deform bones", not missing and not extra and len(deform) == budgets.FAMILY_DEFORM_COUNT[family],
        "%d of %d%s%s" % (len(deform), budgets.FAMILY_DEFORM_COUNT[family],
                          (", missing " + ", ".join(missing)) if missing else "", (", extra " + ", ".join(extra)) if extra else ""))
    missing = sorted(set(want["sockets"]) - set(sockets))
    extra = sorted(set(sockets) - set(want["sockets"]))
    add("socket bones", not missing and not extra,
        "%d of %d%s%s" % (len(sockets), len(want["sockets"]),
                          (", missing " + ", ".join(missing)) if missing else "", (", extra " + ", ".join(extra)) if extra else ""))
    add("bone ceiling", len(bones) <= budgets.RIG_MAX_BONES, "%d of %d, sockets included" % (len(bones), budgets.RIG_MAX_BONES))
    bad = [b.name for b in bones if not (RE_SOCKET.match(b.name) if b.name.startswith("Sock_") else RE_BONE.match(b.name))]
    add("bone naming", not bad, ", ".join(bad) or "PascalCase, sides _L and _R, sockets Sock_<Zone>")
    root = bones.get("Root")
    roots = [b.name for b in bones if b.parent is None]
    add("root", root is not None and roots == ["Root"] and root.head_local.length < 1e-6,
        "Root at (%.3f, %.3f, %.3f), parentless bones: %s" % (*(root.head_local if root else (9, 9, 9)), ", ".join(roots)))
    add("sockets weightless", all(not bones[n].use_deform for n in sockets), "deform flag off on every socket")
    rotated = [b.name for b in bones if not b.name.startswith("Sock_") and not is_identity(b.matrix_local.to_3x3())]
    add("bones at rotation 0", not rotated, ", ".join(rotated) or "every deform bone rests world-aligned")
    scaled = [pb.name for pb in arm.pose.bones if any(abs(s - 1.0) > 1e-5 for s in pb.scale)]
    add("bones at scale 1", not scaled, ", ".join(scaled) or "no bone is scaled")
    add("transforms applied", is_identity(arm.matrix_world), "location, rotation and scale")


def check_action(spec, clip, report):
    scene = bpy.context.scene
    action, arm = clip["action"], clip["armature"]
    add = lambda check, ok, detail="": report.add(action.name, check, ok, detail)
    add("naming", bool(RE_ACTION.match(action.name)) and action.name == clip["name"], action.name)
    add("frame rate", scene.render.fps == common.FPS and scene.render.fps_base == 1.0, "%d frames a second" % scene.render.fps)
    paths = {}
    for fc in action_fcurves(action):
        paths[fc.data_path] = paths.get(fc.data_path, 0) + 1
        keys = len(fc.keyframe_points)
        clip["keys_per_curve"] = min(clip.get("keys_per_curve", keys), keys)
    unkeyed = [pb.name for pb in arm.pose.bones
               if paths.get('pose.bones["%s"].location' % pb.name) != 3
               or paths.get('pose.bones["%s"].rotation_quaternion' % pb.name) != 4]
    add("all bones keyed", not unkeyed and clip.get("keys_per_curve", 0) == clip["end"] - clip["start"] + 1,
        ", ".join(unkeyed) or "%d bones, %d keys each" % (len(arm.pose.bones), clip.get("keys_per_curve", 0)))
    if clip.get("loop"):
        arm.animation_data.action = action
        scene.frame_set(clip["start"])
        first = [pb.matrix_basis.copy() for pb in arm.pose.bones]
        scene.frame_set(clip["end"])
        last = [pb.matrix_basis.copy() for pb in arm.pose.bones]
        scene.frame_set(clip["start"])
        worst = max(abs(a[i][j] - b[i][j]) for a, b in zip(first, last) for i in range(4) for j in range(4))
        add("loops", worst < 1e-4, "%d frames, first and last pose differ by %.6f" % (clip["end"] - clip["start"], worst))


def check_ph_stamp(spec, report):
    """07 section 16: a placeholder's "PH" stamp must show on the mesh. Samples the texture over
    every face of the primary mesh through its UVs and counts stamp-ink pixels."""
    import numpy as np
    body = next(e["object"] for e in spec["meshes"] if e.get("primary"))
    img = bpy.data.images.load(spec["ph_texture"], check_existing=True)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    mesh = body.data
    uv = mesh.uv_layers.active.data
    total = ink = 0
    inks, all_uv = [], []
    steps = 6
    for poly in mesh.polygons:
        corners = [uv[li].uv for li in poly.loop_indices]
        for k in range(1, len(corners) - 1):
            a, b, c = corners[0], corners[k], corners[k + 1]
            for i in range(steps + 1):
                for j in range(steps + 1 - i):
                    u = (a.x * (steps - i - j) + b.x * i + c.x * j) / steps
                    v = (a.y * (steps - i - j) + b.y * i + c.y * j) / steps
                    p = px[min(h - 1, int(v * h)), min(w - 1, int(u * w))]
                    total += 1
                    all_uv.append((u, v))
                    if p[0] < 0.15 and p[1] < 0.15 and p[2] < 0.15:
                        ink += 1
                        inks.append((u, v))
    share = ink / max(total, 1)
    # The stamp must be the mesh's own, in the middle of the area its UVs use, not the edge of
    # someone else's (a wrong atlas cell shows only a corner of a neighbour's stamp).
    lo = [min(c[i] for c in all_uv) for i in range(2)]
    hi = [max(c[i] for c in all_uv) for i in range(2)]
    centre = [sum(c[i] for c in inks) / len(inks) for i in range(2)] if inks else [-1.0, -1.0]
    rel = [(centre[i] - lo[i]) / max(hi[i] - lo[i], 1e-6) for i in range(2)]
    centred = all(0.25 <= r <= 0.75 for r in rel)
    report.add(body.name, "PH stamp on mesh", ink >= 3 and share >= 0.01 and centred,
               "%d of %d samples of %s over the UVs are stamp ink (%.1f%%, at least 1%%); ink centre at %.2f, %.2f "
               "of the UV area (0.25 to 0.75)" % (ink, total, os.path.basename(spec["ph_texture"]), 100.0 * share, rel[0], rel[1]))


def run(spec):
    report = Report()
    body = [e for e in spec["meshes"] if e.get("primary")]
    if body:
        spec["body_tris"] = triangle_count(body[0]["object"].data)
    for entry in spec["meshes"]:
        check_mesh(spec, entry, report)
    if spec.get("preview", {}).get("blocks"):
        check_values(spec, report)
    if spec.get("uv"):
        uvlayout.check(spec, report)
    if spec.get("ph_texture"):
        check_ph_stamp(spec, report)
    if spec.get("armature"):
        check_rig(spec, report)
    for clip in spec.get("actions", []):
        check_action(spec, clip, report)
    report.print()
    return report
