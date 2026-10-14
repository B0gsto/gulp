"""Texel-to-mesh helpers for painted and baked textures (docs/06-art-bible.md sections 5.2 and 5.5),
shared by the trait overlay bake (traitbake.py) and the painted prey (prey/glowfry). The same
method as the Minnow's paint (species/minnow/build.py, which keeps its own copy): every texel of
a UV map is traced back to its point on the mesh, so a paint or a mask can be written as a
function of the 3D surface.

Arrays here have row 0 at V 0 (the bottom of the image, Blender's pixel order) unless a function
says otherwise. Colours are sRGB floats 0 to 1.
"""
import json
import os
import shutil
import subprocess
import tempfile

import bpy
import numpy as np

import common

# ---------------------------------------------------------------- colour maths (sRGB <-> CIE L*a*b*, D65)

_M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
_WHITE = np.array([0.95047, 1.0, 1.08883])


def srgb_to_lab(c):
    c = np.asarray(c, dtype=float)
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    xyz = lin @ _M.T / _WHITE
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16.0 / 116.0)
    return np.stack([116.0 * f[..., 1] - 16.0, 500.0 * (f[..., 0] - f[..., 1]), 200.0 * (f[..., 1] - f[..., 2])], -1)


def lab_to_srgb(lab):
    lab = np.asarray(lab, dtype=float)
    fy = (lab[..., 0] + 16.0) / 116.0
    f = np.stack([fy + lab[..., 1] / 500.0, fy, fy - lab[..., 2] / 200.0], -1)
    xyz = np.where(f ** 3 > 0.008856, f ** 3, (f - 16.0 / 116.0) / 7.787) * _WHITE
    lin = np.clip(xyz @ np.linalg.inv(_M).T, 0.0, 1.0)
    return np.clip(np.where(lin <= 0.0031308, lin * 12.92, 1.055 * lin ** (1.0 / 2.4) - 0.055), 0.0, 1.0)


def hex_rgb(h):
    return np.array(common.hex_to_srgb(h), dtype=float)


def smoothstep(e0, e1, x):
    t = np.clip((np.asarray(x, dtype=float) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def hsv(c):
    """HSV of sRGB colours (..., 3): hue in degrees, saturation and value 0 to 1."""
    c = np.asarray(c, dtype=float)
    mx, mn = c.max(-1), c.min(-1)
    d = mx - mn
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    safe = np.where(d > 1e-9, d, 1.0)
    h = np.where(mx == r, ((g - b) / safe) % 6.0, np.where(mx == g, (b - r) / safe + 2.0, (r - g) / safe + 4.0))
    h = np.where(d > 1e-9, 60.0 * h, 0.0) % 360.0
    s = np.where(mx > 1e-9, d / np.maximum(mx, 1e-9), 0.0)
    return h, s, mx


def hsv_to_rgb(h, s, v):
    h = (np.asarray(h, dtype=float) % 360.0) / 60.0
    s, v = np.asarray(s, dtype=float), np.asarray(v, dtype=float)
    i = np.floor(h).astype(int) % 6
    f = h - np.floor(h)
    p, q, t = v * (1.0 - s), v * (1.0 - s * f), v * (1.0 - s * (1.0 - f))
    choices = [np.stack(c, -1) for c in ((v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q))]
    out = np.zeros(h.shape + (3,))
    for k in range(6):
        out = np.where((i == k)[..., None], choices[k], out)
    return out


def hold_out_of_band(rgb, lo, hi, sat=0.70, val=0.85, margin=1.0):
    """06 4.5: texels that are saturated and bright (over `sat` and `val`) and whose hue fell inside
    the reserved band lo..hi are turned to the nearer band edge plus `margin` degrees. Returns the
    colours and the count moved. Used by painted yellows next to lantern amber ("do not drift them
    inward")."""
    rgb = np.asarray(rgb, dtype=float)
    h, s, v = hsv(rgb)
    hot = (s > sat) & (v > val) & (h >= lo - margin) & (h <= hi + margin)
    if not hot.any():
        return rgb, 0
    to_hi = np.abs(h - (hi + margin)) <= np.abs(h - (lo - margin))
    h2 = np.where(to_hi, hi + margin, lo - margin)
    fixed = hsv_to_rgb(h2, s, v)
    return np.where(hot[..., None], fixed, rgb), int(hot.sum())


# ---------------------------------------------------------------- mesh parts

def components(mesh):
    """Connected part index of every vertex (the closed volumes a build adds one by one)."""
    n = len(mesh.vertices)
    parent = list(range(n))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for e in mesh.edges:
        a, b = find(e.vertices[0]), find(e.vertices[1])
        if a != b:
            parent[a] = b
    roots = [find(i) for i in range(n)]
    ids = {r: k for k, r in enumerate(sorted(set(roots)))}
    return np.array([ids[r] for r in roots], dtype=int)


# ---------------------------------------------------------------- texel to surface

def rasterise(obj, size, vattrs=None):
    """For every texel of a size x size map (row 0 at V 0): the mesh point P, the smooth normal N,
    the part index of the vertex under it and, when `vattrs` (one row of numbers per vertex) is
    given, those numbers interpolated across the triangle. `filled` marks texels on the mesh.
    Mirrored halves share texels: the last triangle drawn wins, so paint by |x|."""
    mesh = obj.data
    mesh.calc_loop_triangles()
    uvl = mesh.uv_layers[common.UV_NAME].data
    normals = mesh.corner_normals
    comp = components(mesh)
    k = 0 if vattrs is None else np.asarray(vattrs).shape[1]
    P = np.zeros((size, size, 3))
    N = np.zeros((size, size, 3))
    A = np.zeros((size, size, max(k, 1)))
    part = np.full((size, size), -1, dtype=int)
    for tri in mesh.loop_triangles:
        uv = np.array([uvl[li].uv[:] for li in tri.loops]) * size - 0.5
        pts = np.array([mesh.vertices[vi].co[:] for vi in tri.vertices])
        nrm = np.array([normals[li].vector[:] for li in tri.loops])
        (x0, y0), (x1, y1) = np.floor(uv.min(0)).astype(int), np.ceil(uv.max(0)).astype(int)
        x0, y0, x1, y1 = max(0, x0), max(0, y0), min(size - 1, x1), min(size - 1, y1)
        a, b, c = uv
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12 or x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        w0 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / den
        w1 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / den
        w2 = 1.0 - w0 - w1
        inside = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
        if not inside.any():
            continue
        W = np.stack([w0[inside], w1[inside], w2[inside]], -1)
        rows, cols = gy[inside], gx[inside]
        P[rows, cols] = W @ pts
        nn = W @ nrm
        N[rows, cols] = nn / np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-6)
        if k:
            A[rows, cols] = W @ np.asarray(vattrs)[list(tri.vertices)]
        part[rows, cols] = comp[tri.vertices[0]]
    return {"P": P, "N": N, "part": part, "attrs": A, "filled": part >= 0, "comp": comp}


def dilate(img, filled, steps, bounds=None):
    """Bleeds the painted islands outward by `steps` texels (the bake margin of 06 section 5.5).
    `bounds` (r0, r1, c0, c1) keeps the bleed inside one atlas cell."""
    img = np.array(img, dtype=float)
    flat = img.ndim == 2
    if flat:
        img = img[..., None]
    filled = filled.copy()
    if bounds is not None:
        r0, r1, c0, c1 = bounds
        sub = dilate(img[r0:r1, c0:c1], filled[r0:r1, c0:c1], steps)
        img[r0:r1, c0:c1] = sub if sub.ndim == 3 else sub[..., None]
        return img[..., 0] if flat else img
    for _ in range(steps):
        acc = np.zeros_like(img)
        cnt = np.zeros(filled.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            f = np.roll(filled, (dy, dx), (0, 1))
            if dy == 1:
                f[0, :] = False
            elif dy == -1:
                f[-1, :] = False
            elif dx == 1:
                f[:, 0] = False
            else:
                f[:, -1] = False
            acc += np.roll(img, (dy, dx), (0, 1)) * f[..., None]
            cnt += f
        grow = ~filled & (cnt > 0)
        img[grow] = acc[grow] / cnt[grow][:, None]
        filled = filled | grow
    return img[..., 0] if flat else img


def downsample(img, factor):
    """Box filter by an integer factor (a texture painted at twice its size, then filtered down)."""
    h, w = img.shape[:2]
    shape = (h // factor, factor, w // factor, factor) + img.shape[2:]
    return img.reshape(shape).mean(axis=(1, 3))


# ---------------------------------------------------------------- Cycles bake (06 section 5.5)

def bake_occlusion(obj, size, tag="bake", subdivide=0):
    """Cycles ambient occlusion from the game mesh (CPU, 64 samples, margin of 06 5.5), as an
    array (row 0 at V 0), or None if the bake fails (the caller reports it). `subdivide` bakes
    from a smoothed copy instead (a Catmull-Clark subdivision of the game mesh, the same UVs):
    06 5.5's optional high-poly source, so a low-poly prey's occlusion has no facets."""
    import texgen
    if subdivide:
        src = obj
        obj = obj.copy()
        obj.data = src.data.copy()
        obj.name = obj.data.name = src.name + "_AOsource"
        for coll in src.users_collection:
            coll.objects.link(obj)
        for m in list(obj.modifiers):
            obj.modifiers.remove(m)
        obj.parent = None
        obj.matrix_world = src.matrix_world.copy()
        mod = obj.modifiers.new("Smooth", 'SUBSURF')
        mod.levels = mod.render_levels = subdivide
        try:
            mod.uv_smooth = 'PRESERVE_BOUNDARIES'
        except Exception:
            pass
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
        try:
            return bake_occlusion(obj, size, tag, 0)
        finally:
            mesh = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            bpy.data.meshes.remove(mesh)
    scene = bpy.context.scene
    keep = (scene.render.engine, {o.name: o.hide_render for o in scene.objects})
    img = bpy.data.images.new("BAKE_AO_" + obj.name, size, size, float_buffer=True, alpha=False)
    mat = obj.data.materials[0]
    mat.use_nodes = True
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = img
    mat.node_tree.nodes.active = node
    try:
        scene.render.engine = 'CYCLES'
        scene.cycles.device = 'CPU'
        scene.cycles.samples = 64
        if scene.world:
            scene.world.light_settings.distance = 0.35 * max(obj.dimensions) / 3.0
        for o in scene.objects:
            o.hide_render = o is not obj
        bpy.ops.object.select_all(action='DESELECT')
        obj.hide_set(False)
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.bake(type='AO', margin=texgen.margin_px(size), use_clear=True)
        ao = np.array(img.pixels[:]).reshape(size, size, 4)[..., 0]
        print("[%s] occlusion baked in Cycles, mean %.2f" % (tag, ao.mean()))
        return ao
    except Exception as exc:
        print("[%s] occlusion bake failed (%s)" % (tag, exc))
        return None
    finally:
        mat.node_tree.nodes.remove(node)
        bpy.data.images.remove(img)
        scene.render.engine = keep[0]
        for o in scene.objects:
            o.hide_render = keep[1].get(o.name, o.hide_render)


# ---------------------------------------------------------------- files

def save_png(path, img, mode="RGB", top_row_first=False):
    """Writes an 8-bit PNG with Pillow in the system python3 (06 15.1), so greyscale masks are
    true 8-bit greyscale: mode "L" (a mask), "LA" (a mask carrying itself as alpha), "RGB" or
    "RGBA". `img` is float 0 to 1, (h, w) or (h, w, channels)."""
    arr = np.clip(np.asarray(img, dtype=float), 0.0, 1.0)
    if not top_row_first:
        arr = arr[::-1]
    arr = np.round(arr * 255.0).astype(np.uint8)
    tmp = tempfile.mkdtemp(prefix="gulp_png_")
    raw = os.path.join(tmp, "img.npy")
    np.save(raw, arr)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    code = ("import sys, numpy as np\nfrom PIL import Image\na = np.load(sys.argv[1])\n"
            "Image.fromarray(a.squeeze() if sys.argv[3] == 'L' else a, sys.argv[3]).save(sys.argv[2])\n")
    python = shutil.which("python3") or "/usr/bin/python3"
    done = subprocess.run([python, "-c", code, raw, path, mode], capture_output=True, text=True)
    shutil.rmtree(tmp, ignore_errors=True)
    if done.returncode != 0:
        raise RuntimeError("writing %s failed (needs Pillow and numpy in the system python3): %s" % (path, done.stderr))
    h, w = arr.shape[:2]
    return w, h


def png_info(path):
    """Mode and size of a PNG as written, read back with Pillow."""
    python = shutil.which("python3") or "/usr/bin/python3"
    code = "import sys, json\nfrom PIL import Image\nim = Image.open(sys.argv[1])\nprint(json.dumps([im.mode, im.size[0], im.size[1]]))\n"
    done = subprocess.run([python, "-c", code, path], capture_output=True, text=True)
    return json.loads(done.stdout) if done.returncode == 0 else None


def blender_image(name, img, colorspace="sRGB"):
    """A Blender image from a float array (row 0 at V 0), for preview materials. The colour space
    is set before the pixels: changing it afterwards reloads a generated image blank."""
    arr = np.asarray(img, dtype=float)
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, -1)
    h, w = arr.shape[:2]
    if arr.shape[2] == 3:
        arr = np.concatenate([arr, np.ones((h, w, 1))], -1)
    old = bpy.data.images.get(name)
    if old:
        bpy.data.images.remove(old)
    im = bpy.data.images.new(name, w, h, alpha=True)
    im.colorspace_settings.name = colorspace
    im.pixels.foreach_set(np.clip(arr, 0.0, 1.0).astype(np.float32).ravel())
    im.update()
    return im
