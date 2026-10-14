"""Mesh side of the UV layout and atlas tools (docs/07-asset-list.md section 14.1): keep the
family UV layout identical across species (docs/06-art-bible.md section 5.4), measure texel
density against section 5.6, and move a mesh's UVs into an atlas cell.

A build declares spec["uv"] = {"layout": "Fish", "texture": "species_juv"}; validate then checks
every body mesh (LODs included; shells carry no texture) with `check`.
"""
import bmesh

import texgen


def _uv_joined(f, g, edge, uv):
    for v in edge.verts:
        a = next(l[uv].uv for l in f.loops if l.vert == v)
        b = next(l[uv].uv for l in g.loops if l.vert == v)
        if abs(a.x - b.x) > 1e-6 or abs(a.y - b.y) > 1e-6:
            return False
    return True


def parts_uvs(mesh):
    """UVs per UV island: faces joined across an edge where both faces' UVs agree at both of the
    edge's ends (S4-A3: a part may carry a UV seam, as the body with its mouth interior does,
    whose faces are joined to the lips but laid out in the mouth region): [[(u, v), ...], ...]."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv = bm.loops.layers.uv.active
    seen, out = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, uvs = [f], []
        seen.add(f.index)
        while stack:
            cur = stack.pop()
            uvs.extend(tuple(l[uv].uv) for l in cur.loops)
            for e in cur.edges:
                for o in e.link_faces:
                    if o.index not in seen and _uv_joined(cur, o, e, uv):
                        seen.add(o.index)
                        stack.append(o)
        out.append(uvs)
    bm.free()
    return out


def texel_density(mesh, size):
    """Pixels per stud: sqrt(texture area used / surface area). Mirrored halves count on both
    sides of the division, so the answer is per side."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv = bm.loops.layers.uv.active
    area3d, area_uv = 0.0, 0.0
    for f in bm.faces:
        area3d += f.calc_area()
        pts = [l[uv].uv for l in f.loops]
        a = 0.0
        for i in range(1, len(pts) - 1):
            a += abs((pts[i].x - pts[0].x) * (pts[i + 1].y - pts[0].y) - (pts[i + 1].x - pts[0].x) * (pts[i].y - pts[0].y)) / 2.0
        area_uv += a
    bm.free()
    return (area_uv * size * size / area3d) ** 0.5 if area3d > 0 else 0.0


def uv_triangles(mesh):
    uv = mesh.uv_layers.active.data
    return [[tuple(uv[li].uv) for li in p.loop_indices] for p in mesh.polygons]


def to_atlas_cell(obj, rect):
    """Squeeze a mesh's whole 0..1 UV square into an atlas cell (u0, v0, u1, v1)."""
    u0, v0, u1, v1 = rect
    for d in obj.data.uv_layers.active.data:
        d.uv = (u0 + (u1 - u0) * d.uv[0], v0 + (v1 - v0) * d.uv[1])


def check(spec, report):
    cfg = spec.get("uv")
    if not cfg:
        return
    size, target = texgen.TEXTURE_CLASSES[cfg["texture"]]
    layout = cfg.get("layout")
    report.add(spec["name"], "texture size", size <= texgen.MAX_TEXTURE, "%s: %d px (06 5.6), bake margin %d px (06 5.5)"
               % (cfg["texture"], size, texgen.margin_px(size)))
    for e in spec["meshes"]:
        if e["role"] != "body":
            continue
        obj = e["object"]
        if layout:
            regions = [texgen.region_of(layout, uvs, size) for uvs in parts_uvs(obj.data)]
            missing = regions.count(None)
            used = sorted({r for r in regions if r})
            report.add(obj.name, "UV layout", missing == 0, "%s layout: %d parts in %s; %d outside a region or its margin"
                       % (layout, len(regions), ", ".join(used), missing))
        if target and not e.get("lod"):
            d = texel_density(obj.data, size)
            e["texel_density"] = round(d, 1)
            report.add(obj.name, "texel density", d >= target, "%.0f px/stud at %d px, target %d or more" % (d, size, target))


def review_image(spec, out):
    """UV map of the primary mesh over its layout, for the reviewer."""
    cfg = spec.get("uv") or {}
    body = [e["object"] for e in spec["meshes"] if e.get("primary")][0]
    layout = texgen.FAMILY_LAYOUTS.get(cfg.get("layout"), {})
    return {"layout": layout, "triangles": uv_triangles(body.data),
            "title": "%s UVs, %s layout (06 5.4), %s" % (body.name, cfg.get("layout", "none"), cfg.get("texture", ""))}


def project(obj, rect, size, mode="side"):
    """Placeholder unwrap (07 section 16: the PH stamp must show on the mesh): every corner
    gets a UV inside `rect` (a layout region or an atlas cell), inside the bake margin.
    side: projected from the creature's side (Y along U, Z along V; left and right mirrored).
    box: each face from its main axis, so every face of a block shows the whole texture."""
    u0, v0, u1, v1 = texgen.inner(rect, size)
    mesh = obj.data
    co = [v.co for v in mesh.vertices]
    lo = [min(c[i] for c in co) for i in range(3)]
    span = [max(max(c[i] for c in co) - lo[i], 1e-6) for i in range(3)]
    uv = mesh.uv_layers.active.data
    for poly in mesh.polygons:
        n = poly.normal
        if mode == "box":
            axis = max(range(3), key=lambda i: abs(n[i]))
            a, b = [(1, 2), (0, 2), (0, 1)][axis]
        else:
            a, b = 1, 2
        for li in poly.loop_indices:
            c = co[mesh.loops[li].vertex_index]
            fu, fv = (c[a] - lo[a]) / span[a], (c[b] - lo[b]) / span[b]
            uv[li].uv = (u0 + (u1 - u0) * fu, v0 + (v1 - v0) * fv)
