"""Mouth interior for a Fish-family body (task S4-A3; docs/06-art-bible.md section 3.3: the fish's
mouth "opens very wide", fully open 80% of the head height; 4.1: the mouth interior is in the dark
block, L* 35 or less; 5.4: UV region "Mouth interior and tongue", U 0.25 to 0.50, V 0.00 to 0.25;
7.7: closed smile, open, full gape).

The lofted body is one closed skin and the jaw's weights split it across the lip, so before this
an open jaw stretched a band of body skin over the gap and the gape read as a smile line. Here:

  the lip seam   every lip vertex of the lower jaw (jaw weight 0.9 or more, with head skin above
                 it) gets a twin that keeps the head's weights; the skin faces above the lip take
                 the twin, so the skin opens along the lip instead of stretching over the gap
  the cavity     each seam edge gets a pocket of two quads from the upper lip (the twins), back into the head
                 (the throat row, inset toward the centre line and back toward the hinge, weighted
                 half head and half jaw) and out to the lower lip: dark palate and throat, a
                 lighter tongue on the jaw side. It shares the lips' vertices, so the body stays
                 closed (watertight). Closed, the pocket folds flat inside the head and
                 the twins sit on their originals, so the closed head looks as it did; open, it
                 lines the gape. Where the seam ends at the mouth corner the pocket ends in two
                 triangles on the corner vertex.

Every body vertex keeps its index (the weight check reads the body's grid by index); the twins
and the cavity's own vertices are appended.
"""

MOUTH = "#4A1630"     # palate and throat: deep plum, L* about 16 (06 4.1 dark block, 35 or less)
TONGUE = "#80344A"    # tongue: lighter, so the cavity reads as depth, L* about 32
THROAT = "#2E0E20"    # the back of the throat, darkest


def _head_weights(w):
    """The vertex's weights without the jaw, renormalised: the upper lip's twin."""
    rest = {n: v for n, v in w.items() if n != "Jaw"}
    total = sum(rest.values())
    return {n: v / total for n, v in rest.items()} if total > 0.0 else {"Spine1": 1.0}


def _mix(a, b, t):
    out = {n: (1.0 - t) * a.get(n, 0.0) for n in a}
    for n, v in b.items():
        out[n] = out.get(n, 0.0) + t * v
    return {n: v for n, v in out.items() if v > 1e-6}


def add_mouth(md, body_count, fit, uv_rect, k=1.0, depth=0.45, back=0.10, colours=None):
    """Adds the lip seam and the cavity to MeshData `md` whose first `body_count` vertices are the
    body. `uv_rect` maps (fu, fv) 0..1 into the layout's mouth region. `colours` (optional) gives
    the vertex colours of the upper, throat and tongue rows. Returns {"twins", "cavity_verts",
    "cavity_faces", "seam_edges"} (index lists and counts) for the build's bookkeeping."""
    import meshgen
    jaw = [md.weights[i].get("Jaw", 0.0) for i in range(body_count)]
    pos = md.verts
    body_faces = [fi for fi, f in enumerate(md.faces) if all(v < body_count for v in f)]
    upper = [j < 0.5 for j in jaw]
    lip = set()
    for fi in body_faces:
        f = md.faces[fi]
        for a in f:
            if upper[a] or jaw[a] < 0.9 or pos[a][1] >= fit.jaw_y:
                continue
            for u in f:
                if upper[u] and pos[u][2] - pos[a][2] > 0.5 * abs(pos[u][1] - pos[a][1]):
                    lip.add(a)
    twin = {}
    for a in sorted(lip):
        twin[a] = len(md.verts)
        md.verts.append(tuple(pos[a]))
        md.vcols.append(md.vcols[a])
        md.uvs.append(md.uvs[a])
        md.weights.append(meshgen.clean_weights(_head_weights(md.weights[a])))
        md.tags.append(md.tags[a])
    lower_faces = {}
    for fi in body_faces:
        f = md.faces[fi]
        if not any(upper[v] for v in f):
            for i in range(len(f)):
                lower_faces[(f[i], f[(i + 1) % len(f)])] = fi
    seam = []
    for fi in body_faces:
        f = md.faces[fi]
        if not any(upper[v] for v in f):
            continue
        for i in range(len(f)):
            p, q = f[i], f[(i + 1) % len(f)]
            if (q, p) in lower_faces and (p in twin or q in twin):
                seam.append((p, q))
        md.faces[fi] = tuple(twin.get(v, v) for v in f)

    top, throat, tongue = colours or (MOUTH, THROAT, TONGUE)
    y0, y1 = min(p[1] for p in pos[:body_count]), fit.jaw_y
    hinge_z = fit.lip_z
    first = len(md.verts)
    mid = {}

    def uv(v, row):
        return uv_rect(0.1 + 0.8 * (pos[v][1] - y0) / (y1 - y0), row)

    def throat_vertex(v):
        """The throat row over seam vertex v: inset toward the centre line and back toward the
        hinge, half head and half jaw. A seam end (no twin) is its own throat vertex."""
        if v not in twin:
            return v
        if v not in mid:
            x, y, z = pos[v]
            mid[v] = len(md.verts)
            md.verts.append((x * (1.0 - depth), y + back * k, z + 0.5 * (hinge_z - z)))
            md.vcols.append(throat)
            md.uvs.append(uv(v, 0.5))
            md.weights.append(meshgen.clean_weights(_mix(md.weights[twin[v]], md.weights[v], 0.5)))
            md.tags.append(0)
        return mid[v]

    # The cavity shares the skin's vertices along both lips (the twins above, the originals
    # below), so the body stays one closed surface; its own UVs, in the mouth region, ride on
    # the faces (MeshData.corner_uvs): palate at the region's top, throat in the middle, tongue
    # at its foot.
    faces = 0
    for p, q in seam:
        pm, qm = throat_vertex(p), throat_vertex(q)
        for ring, rows, colour in (((twin.get(q, q), twin.get(p, p), pm, qm), (1.0, 1.0, 0.5, 0.5), top),
                                   ((qm, pm, p, q), (0.5, 0.5, 0.0, 0.0), tongue)):
            seen, f, r = set(), [], []
            for v, row, src in zip(ring, rows, (q, p, p, q)):
                if v not in seen:
                    seen.add(v)
                    f.append(v)
                    r.append(uv(src, row))
            if len(f) >= 3:
                md.corner_uvs[len(md.faces)] = r
                md.faces.append(tuple(f))
                md.fcols.append(colour)
                faces += 1
    return {"twins": list(twin.values()), "cavity_verts": list(range(first, len(md.verts))),
            "cavity_faces": faces, "seam_edges": len(seam)}
