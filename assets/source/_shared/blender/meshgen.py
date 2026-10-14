"""The `build` helpers: meshes, skeletons and outline shells made from parameters.

Conventions (docs/06-art-bible.md section 6): 1 unit = 1 stud, nose on -Y, up +Z,
every part a closed volume, one material, one UV set, one vertex-colour layer.
"""
import math

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

import common
import template


# ---------------------------------------------------------------- part generators
# Each returns (verts, faces, params): params[i] is a (u, v) pair in 0..1 for vertex i.

def loft(rings, pole_start, pole_end):
    """Closed tube through `rings` (equal-length point lists), capped by two pole points."""
    n = len(rings[0])
    verts, params = [tuple(pole_start)], [(0.0, 0.0)]
    count = len(rings)
    for k, ring in enumerate(rings):
        for j, p in enumerate(ring):
            f = j / n
            verts.append(tuple(p))
            params.append(((k + 1) / (count + 1), 1.0 - abs(2.0 * f - 1.0)))
    verts.append(tuple(pole_end))
    params.append((1.0, 0.0))
    last = len(verts) - 1
    faces = []
    for j in range(n):
        faces.append((0, 1 + j, 1 + (j + 1) % n))
    for k in range(count - 1):
        a, b = 1 + k * n, 1 + (k + 1) * n
        for j in range(n):
            j2 = (j + 1) % n
            faces.append((a + j, b + j, b + j2, a + j2))
    a = 1 + (count - 1) * n
    for j in range(n):
        faces.append((a + j, last, a + (j + 1) % n))
    return verts, faces, params


def sphere(centre, radius, axis, up, segs, rings):
    """UV sphere whose first pole points along `axis`."""
    c, o, u = Vector(centre), Vector(axis).normalized(), Vector(up).normalized()
    f = o.cross(u).normalized()
    out = []
    for k in range(1, rings + 1):
        a = math.pi * k / (rings + 1)
        out.append([c + radius * (math.cos(a) * o + math.sin(a) * (math.cos(b) * u + math.sin(b) * f))
                    for b in (2.0 * math.pi * j / segs for j in range(segs))])
    return loft(out, c + radius * o, c - radius * o)


def slab(grid, normal, thickness):
    """Thin closed volume around a mid-surface. grid[i][j] are points; `normal` is a vector
    or a function of the point. The bible's floor for fins is 0.03 studs thick."""
    rows, cols = len(grid), len(grid[0])
    verts, params = [], []
    for side in (0.5, -0.5):
        for i in range(rows):
            for j in range(cols):
                p = Vector(grid[i][j])
                nrm = Vector(normal(p) if callable(normal) else normal).normalized()
                verts.append(tuple(p + nrm * thickness * side))
                params.append((i / (rows - 1), j / (cols - 1)))
    front = lambda i, j: i * cols + j
    back = lambda i, j: rows * cols + i * cols + j
    faces = []
    for i in range(rows - 1):
        for j in range(cols - 1):
            faces.append((front(i, j), front(i + 1, j), front(i + 1, j + 1), front(i, j + 1)))
            faces.append((back(i, j), back(i, j + 1), back(i + 1, j + 1), back(i + 1, j)))
    rim = ([(i, 0) for i in range(rows)] + [(rows - 1, j) for j in range(1, cols)]
           + [(i, cols - 1) for i in range(rows - 2, -1, -1)] + [(0, j) for j in range(cols - 2, 0, -1)])
    for k in range(len(rim)):
        a, b = rim[k], rim[(k + 1) % len(rim)]
        faces.append((front(*a), back(*a), back(*b), front(*b)))
    return verts, faces, params


def prism(outline, depth):
    """Closed prism: `outline` is a planar point loop, extruded along the vector `depth`."""
    n = len(outline)
    d = Vector(depth)
    verts = [tuple(Vector(p)) for p in outline] + [tuple(Vector(p) + d) for p in outline]
    faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    for k in range(n):
        k2 = (k + 1) % n
        faces.append((k, n + k, n + k2, k2))
    return verts, faces, [(0.0, 0.0)] * (2 * n)


def box(lo, hi):
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    verts = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
             (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    faces = [(0, 1, 5, 4),   # -Y front
             (2, 3, 7, 6),   # +Y back
             (1, 2, 6, 5),   # +X
             (3, 0, 4, 7),   # -X
             (4, 5, 6, 7),   # +Z top
             (3, 2, 1, 0)]   # -Z bottom
    return verts, faces, [(0.0, 0.0)] * 8


def signed_volume(verts, faces):
    total = 0.0
    for face in faces:
        a = Vector(verts[face[0]])
        for k in range(1, len(face) - 1):
            total += a.dot(Vector(verts[face[k]]).cross(Vector(verts[face[k + 1]])))
    return total / 6.0


def clean_weights(weights, limit=4):
    """At most `limit` bones per vertex, normalised (06 section 6.5)."""
    items = sorted(((n, w) for n, w in weights.items() if w > 0.01), key=lambda it: -it[1])[:limit]
    total = sum(w for _, w in items)
    if total <= 0.0:
        return {}
    return {n: w / total for n, w in items}


# ---------------------------------------------------------------- mesh assembly

class MeshData:
    """Collects closed parts into one mesh with vertex colours, one UV set and bone weights."""

    def __init__(self):
        self.verts, self.faces = [], []
        self.vcols, self.fcols, self.uvs, self.weights, self.tags = [], [], [], [], []

    def add_part(self, part, colour, uv=None, weights=None, face_colours=None, tag=0, clamp=None):
        """colour, uv and weights are constants or functions of (point, param).
        face_colours overrides the vertex colour per face (hard colour edges)."""
        verts, faces, params = part
        if clamp:
            verts = [tuple(max(-c, min(c, v)) if c else v for v, c in zip(p, clamp)) for p in verts]
        if signed_volume(verts, faces) < 0.0:
            faces = [tuple(reversed(f)) for f in faces]
            if face_colours:
                face_colours = list(face_colours)
        base = len(self.verts)
        for p, q in zip(verts, params):
            pv = Vector(p)
            self.verts.append(tuple(p))
            self.vcols.append(colour(pv, q) if callable(colour) else colour)
            self.uvs.append(uv(pv, q) if callable(uv) else (uv or (0.5, 0.5)))
            w = weights(pv, q) if callable(weights) else (weights or {})
            self.weights.append(clean_weights(w))
            self.tags.append(tag)
        for i, face in enumerate(faces):
            self.faces.append(tuple(base + v for v in face))
            self.fcols.append(face_colours[i] if face_colours else None)
        return self

    def to_object(self, name, collection, smooth=True, material=None):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.verts, [], self.faces)
        mesh.update()
        if smooth:
            mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
        col = mesh.color_attributes.new(common.COLOR_ATTR, 'BYTE_COLOR', 'CORNER')
        uv = mesh.uv_layers.new(name=common.UV_NAME)
        for poly in mesh.polygons:
            for li in poly.loop_indices:
                vi = mesh.loops[li].vertex_index
                hexcode = self.fcols[poly.index] or self.vcols[vi]
                col.data[li].color_srgb = (*common.hex_to_srgb(hexcode), 1.0)
                u, v = self.uvs[vi]
                uv.data[li].uv = (min(1.0, max(0.0, u)), min(1.0, max(0.0, v)))
        mesh.attributes.active_color_name = common.COLOR_ATTR
        mesh.attributes.default_color_name = common.COLOR_ATTR
        if any(self.tags):
            tags = mesh.attributes.new(common.TAG_ATTR, 'INT', 'POINT')
            tags.data.foreach_set("value", self.tags)
        mesh.materials.append(material or template.vertex_colour_material("MAT_" + name))
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        template.link(obj, collection)
        groups = {}
        for vi, w in enumerate(self.weights):
            for bone, value in w.items():
                group = groups.get(bone) or groups.setdefault(bone, obj.vertex_groups.new(name=bone))
                group.add([vi], value, 'REPLACE')
        return obj


# ---------------------------------------------------------------- skeleton

def build_armature(name, bones, collection="RIG"):
    """bones: dicts with name, head, parent, and optionally deform, direction, length.
    Deform bones are short stubs along +Y with roll 0, so every rest matrix is a pure
    translation: "bones at scale 1, rotation 0" (06 section 6.1). Sockets take a
    `direction` that points the piece outward (06 section 8.4)."""
    arm = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, arm)
    template.link(obj, collection)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for spec in bones:
        eb = arm.edit_bones.new(spec["name"])
        head = Vector(spec["head"])
        eb.head = head
        eb.tail = head + Vector(spec.get("direction", (0.0, 1.0, 0.0))).normalized() * spec.get("length", 0.1)
        eb.roll = 0.0
        eb.use_connect = False
        if spec.get("parent"):
            eb.parent = arm.edit_bones[spec["parent"]]
    bpy.ops.object.mode_set(mode='OBJECT')
    for spec in bones:
        arm.bones[spec["name"]].use_deform = spec.get("deform", True)
    for pb in obj.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    obj.select_set(False)
    arm.display_type = 'STICK'
    return obj


def skin(obj, armature):
    obj.parent = armature
    mod = obj.modifiers.new("Armature", 'ARMATURE')
    mod.object = armature
    return obj


def attach_to_bone(obj, armature, bone_name):
    """Rigid piece on a socket: bone-parented, with its origin on the bone's head and
    world-aligned axes."""
    bpy.context.view_layer.update()
    bone = armature.data.bones[bone_name]
    parent = armature.matrix_world @ bone.matrix_local @ Matrix.Translation((0.0, bone.length, 0.0))
    world = Matrix.Translation(armature.matrix_world @ bone.head_local)
    obj.parent = armature
    obj.parent_type = 'BONE'
    obj.parent_bone = bone_name
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.matrix_basis = parent.inverted() @ world
    bpy.context.view_layer.update()
    return obj


# A pose is {bone: {"loc": (x, y, z), "rot": (rx, ry, rz) in degrees}}. Deform bones rest
# world-aligned, so both are in the creature's axes: -Y forward, +Z up, +X its left.

def apply_pose(armature, pose):
    for pb in armature.pose.bones:
        pb.location = (0.0, 0.0, 0.0)
        pb.rotation_quaternion = Quaternion()
        pb.scale = (1.0, 1.0, 1.0)
    for name, tr in (pose or {}).items():
        pb = armature.pose.bones[name]
        pb.location = tr.get("loc", (0.0, 0.0, 0.0))
        pb.rotation_quaternion = Euler([math.radians(a) for a in tr.get("rot", (0.0, 0.0, 0.0))], 'XYZ').to_quaternion()


# ---------------------------------------------------------------- outline shell

def make_shell(source, name, thickness, colour_hex, collection="SHELL"):
    """Outline shell (06 section 13.2): a copy pushed out along its normals with the faces
    flipped, skinned to the same bones. `source` is consumed and renamed."""
    mesh = source.data
    normals = [v.normal.copy() for v in mesh.vertices]
    for v, n in zip(mesh.vertices, normals):
        v.co = v.co + n * thickness
    mesh.flip_normals()
    mesh.update()
    source.name = name
    mesh.name = name
    mesh.materials.clear()
    mesh.materials.append(template.flat_material("MAT_" + name, colour_hex, culling=True))
    for coll in list(source.users_collection):
        coll.objects.unlink(source)
    template.link(source, collection)
    return source


def shell_thickness(body_height, share=0.06, floor=0.12):
    """Players and predators: 6% of body height (tune), at least 0.12 studs."""
    return max(body_height * share, floor)
