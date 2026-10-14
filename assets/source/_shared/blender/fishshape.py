"""The capsule fish shape at body scale 1.0 (Minnow size: 3.0 long, 1.1 tall, 0.7 wide;
docs/06-art-bible.md section 6.2). Shared by the family base build (families/fish) and the
template's tier-1 and tier-7 reference silhouettes.

Every part takes an `offset`: the same part grown outward by that distance along its
surface normals, which is how the outline shell is made without self-intersections.
"""
import math

from mathutils import Vector

import meshgen

LENGTH, HEIGHT, WIDTH = 3.0, 1.1, 0.7
Y_NOSE, Y_BODY_END, Y_TAIL_ROOT, Y_TAIL_TIP = -1.5, 1.05, 0.95, 1.5
FIN_THICK = 0.04            # the floor is 0.03 (06 section 6.5)


def half_h(y):
    """Half height of the body at station y: a slightly fat teardrop, blunt nose, thin tail root."""
    t = min(1.0, max(0.0, (y - Y_NOSE) / (Y_BODY_END - Y_NOSE)))
    return 0.45 * math.sin(math.pi * (0.93 * t) ** 0.75) ** 0.6


def half_w(y):
    return half_h(y) * (0.26 / 0.45)


def spread(a, b, n):
    return [a + (b - a) * i / (n - 1) for i in range(n)]


def _surface(y, a):
    return Vector((half_w(y) * math.sin(a), y, half_h(y) * math.cos(a)))


def _normal(y, a):
    eps = 1e-3
    dy = _surface(y + eps, a) - _surface(y - eps, a)
    da = _surface(y, a + eps) - _surface(y, a - eps)
    n = dy.cross(da)
    p = _surface(y, a)
    if n.dot(Vector((p.x, 0.0, p.z))) < 0.0:
        n = -n
    return n.normalized()


def body_part(segs, rings, offset=0.0):
    out = []
    for k in range(1, rings + 1):
        y = Y_NOSE + (k / rings) ** 1.25 * (Y_BODY_END - Y_NOSE)
        ring = []
        for j in range(segs):
            a = 2.0 * math.pi * j / segs
            ring.append(tuple(_surface(y, a) + _normal(y, a) * offset))
        out.append(ring)
    return meshgen.loft(out, (0.0, Y_NOSE - offset, 0.0), (0.0, Y_BODY_END + 0.05 + offset, 0.0))


def tail_part(n, offset=0.0):
    rows, cols = n
    grid = [[(0.0, Y_TAIL_ROOT + u * ((Y_TAIL_TIP - Y_TAIL_ROOT) - 0.18 * (1.0 - abs(v)) ** 2 + offset),
              v * (0.13 + (HEIGHT / 2.0 - 0.13) * u ** 0.8 + offset * u))
             for v in spread(-1.0, 1.0, cols)] for u in spread(0.0, 1.0, rows)]
    return meshgen.slab(grid, (1.0, 0.0, 0.0), FIN_THICK + 2.0 * offset)


def dorsal_part(n, offset=0.0):
    rows, cols = n
    grid = []
    for u in spread(0.0, 1.0, rows):
        yb = -0.5 - offset + (0.8 + 2.0 * offset) * u
        rise = 0.05 + 0.09 * math.sin(math.pi * u ** 0.6) + offset
        grid.append([(0.0, yb + 0.12 * v, min(HEIGHT / 2.0 + offset, half_h(yb) - 0.04 + v * rise))
                     for v in spread(0.0, 1.0, cols)])
    return meshgen.slab(grid, (1.0, 0.0, 0.0), FIN_THICK + 2.0 * offset)


def silhouette(colour, scale=1.0):
    """Body, tail and back fin at `scale` times Minnow size: the template's reference fish."""
    md = meshgen.MeshData()
    for part in (body_part(16, 14), tail_part((4, 3)), dorsal_part((4, 3))):
        md.add_part(part, colour, uv=(0.5, 0.5))
    md.verts = [tuple(c * scale for c in v) for v in md.verts]
    return md
