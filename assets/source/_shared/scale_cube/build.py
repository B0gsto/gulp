"""M_Prop_ScaleCube: the calibration asset of docs/06-art-bible.md section 6.1 (spike S0-A1).

A 4-stud cube with an arrow on its front, imported once per Blender or Studio version to
confirm scale, facing and the vertex-colour space. Prop origin: centre of the base.

    Blender --background --python assets/source/_shared/scale_cube/build.py

What Studio should show if the export settings in _shared/blender/export.py are right:
  - Size 4 studs across (Blender X) and 4 studs tall (Blender Z). The arrow stands 0.1 proud
    of the front face, so the depth reads 4.1 and the front is the side that sticks out.
  - The orange face with the navy arrow faces Roblox Front; the arrow points up.
  - The arrow has a square tab low on one side: the cube's own left (Blender +X), which is
    the viewer's right when looking at the front. The same side is the red face. A tab on
    the other side, or red and green swapped, means the import mirrored the mesh.
  - The back face is 50% grey, written as sRGB (128, 128, 128). Reading it back as about
    0.50 means the importer takes vertex colours as sRGB; about 0.22 means linear.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "blender"))

import bpy  # noqa: E402

import common  # noqa: E402
import meshgen  # noqa: E402

NAME = "M_Prop_ScaleCube"
SIDE = 4.0
MARKER_PROUD = 0.1      # how far the arrow stands out of the front face
MARKER_SUNK = 0.02      # and how far it is sunk in, so the two volumes overlap
MARKER_COLOUR = "#14213D"
# In the order meshgen.box() makes its faces.
FACES = [
    ("front, Blender -Y", "#FF9A3D"),
    ("back, +Y: 50% grey", "#808080"),
    ("+X, the cube's left", "#FF0000"),
    ("-X, the cube's right", "#00FF00"),
    ("top, +Z", "#0000FF"),
    ("bottom, -Z", "#FFFFFF"),
]
# Arrow pointing up, seen from the front (x to the viewer's right, z up), with the tab on +X.
ARROW = [(-0.3, 0.8), (0.9, 0.8), (0.9, 1.3), (0.3, 1.3), (0.3, 2.2), (0.9, 2.2), (0.0, 3.2), (-0.9, 2.2), (-0.3, 2.2)]


def build():
    h = SIDE / 2.0
    md = meshgen.MeshData()
    md.add_part(meshgen.box((-h, -h, 0.0), (h, h, SIDE)), "#FFFFFF",
                uv=lambda p, q: (p.x / SIDE + 0.5, p.y / SIDE + 0.5),
                face_colours=[c for _, c in FACES])
    front = -h - MARKER_PROUD
    md.add_part(meshgen.prism([(x, front, z) for x, z in ARROW], (0.0, MARKER_PROUD + MARKER_SUNK, 0.0)), MARKER_COLOUR,
                uv=lambda p, q: (p.x / SIDE + 0.5, p.z / SIDE), tag=common.TAG_FRONT)
    cube = md.to_object(NAME, "GEO", smooth=False)

    refs = bpy.data.objects
    return {
        "name": NAME,
        "category": "Prop",
        "budget": "calibration",
        "origin": "prop",
        "size": (SIDE, SIDE + MARKER_PROUD, SIDE),
        "size_tol": 0.001,
        "facing": {"kind": "tag"},
        "meshes": [{"object": cube, "role": "body", "primary": True}],
        "exports": [{"file": "meshes/%s.fbx" % NAME, "objects": [cube]}],
        "preview": {
            "main": [cube],
            "lineup": [
                {"label": NAME, "objects": [cube]},
                {"label": "the template's 4-stud cube", "objects": [refs["REF_Cube4"]]},
                {"label": "capsule fish silhouette, 3 studs", "objects": [refs["REF_Minnow_T1"]]},
            ],
            "lineup_caption": ["a calibration asset has no look-alikes"],
            "extras": [
                {"title": "Front", "view": "Front", "caption": ["arrow up; tab on the viewer's right (the cube's left, +X)"]},
                {"title": "Rear three-quarter", "view": "RearThreeQuarter", "caption": ["grey back face, green right face (-X), blue top"]},
                {"title": "Vertex colours written (sRGB)", "legend": [(label, c) for label, c in FACES] + [("arrow", MARKER_COLOUR)]},
            ],
            "texture": "none (vertex colour)",
        },
    }


if __name__ == "__main__":
    import run
    run.main(__file__)
