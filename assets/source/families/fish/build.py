"""M_Species_Base_Fish on RIG_Fish: the capsule stand-in of spikes S0-A2 and S0-C7 (S8) and
the starting point of S1-A3 (docs/13-sprint-plan.md; docs/06-art-bible.md sections 6 to 8).

    Blender --background --python assets/source/families/fish/build.py

A capsule fish at the Minnow's size (3.0 long, 1.1 tall, 0.7 wide; 06 section 6.2) on the
real family skeleton: 18 deform bones and 10 sockets with the bible's names. It makes:
  M_Species_Base_Fish         the skinned body: body, fins, eyes and lids in one mesh
  and, from the run.py steps lod and shell (versions.py), on the same skeleton:
  M_Species_Base_Fish_LOD1, _LOD2                       half and a quarter of the triangles
  M_Species_Base_Fish[_LOD1|_LOD2]_Shell, _ShellThick   flipped-face outline shells
  M_Species_Base_Fish_Crest   a rigid piece parented to the socket bone Sock_Crest
  A_Fish_Swim, _SwimFast, _Idle, _Dash, _Bite
                              the first five family clips (13, S2-A3) as procedural stand-ins
                              at the lengths chapter 07 gives (clips.py, poses in rigs.py)
  M_Species_Base_Fish_RigTest all of the above in one file, for the Studio rig tests
Everything is vertex-coloured in the Minnow palette; there is no texture yet, but the UVs are
laid out by the family layout tool (uvlayout.py / texgen.py, 06 section 5.4) for a 256 texture.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "_shared", "blender"))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import clips  # noqa: E402
import common  # noqa: E402
import meshgen  # noqa: E402
import rigs  # noqa: E402
import texgen  # noqa: E402


NAME = "M_Species_Base_Fish"
from fishshape import (FIN_THICK, HEIGHT, LENGTH, WIDTH, Y_NOSE, Y_TAIL_ROOT, Y_TAIL_TIP,  # noqa: E402
                       body_part, dorsal_part, half_h, half_w, spread, tail_part)
EYE_RADIUS = 0.11
MOUTH_Y = -1.12             # the mouth line runs from the nose back to here

# Rings and segments per part: 1,452 of 1,500 triangles. LODs and shells come from versions.py.
RES = dict(segs=20, rings=20, tail=(5, 5), dorsal=(6, 4), pec=(4, 4), eye=(8, 6), lid=(5, 4))
TEXTURE = "species_juv"     # 06 section 5.6: 256 x 256, 60 px/stud
TEX = texgen.TEXTURE_CLASSES[TEXTURE][0]

LIGHT, MID, DARK, ACCENT = (common.colour("creatures.minnow." + k) for k in ("light", "mid", "dark", "accent"))
EYE_WHITE, PUPIL = "#FFFFFF", common.colour("ui.ink")
MOUTH = PUPIL               # mouth interior: the darkest value, so the gape reads at 48 px


def on_flank(y, z, inset):
    return half_w(y) * math.sqrt(max(0.0, 1.0 - (z / half_h(y)) ** 2)) - inset


EYE = (on_flank(-1.05, 0.10, 0.03), -1.05, 0.10)      # left eye centre (+X is the creature's left)
PEC = (on_flank(-0.55, -0.12, 0.03), -0.55, -0.12)    # left pectoral root
DORSAL_TIP = (0.0, -0.1, HEIGHT / 2.0)


def pec_part(side, n):
    rows, cols = n
    root = Vector((side * PEC[0], PEC[1], PEC[2]))
    along = Vector((side * 0.35, 0.85, -0.4)).normalized()
    across = Vector((0.0, 0.3, 1.0))
    across = (across - across.dot(along) * along).normalized()
    length = (WIDTH / 2.0 - 0.005 - PEC[0]) / abs(along.x)
    grid = [[root + along * (length * u) + across * (v * (0.04 + 0.09 * math.sin(math.pi * u ** 0.8)))
             for v in spread(-1.0, 1.0, cols)] for u in spread(0.0, 1.0, rows)]
    return meshgen.slab(grid, along.cross(across), 0.035)


def eye_centre(side):
    return Vector((side * EYE[0], EYE[1], EYE[2]))


def lid_part(side, n):
    """A visor over the upper band of the eye; it turns about the eye's fore-aft axis."""
    rows, cols = n
    c = eye_centre(side)
    out, up, fwd = Vector((side, 0.0, 0.0)), Vector((0.0, 0.0, 1.0)), Vector((0.0, -1.0, 0.0))
    r = EYE_RADIUS + 0.02
    grid = [[c + r * (math.cos(b) * (math.cos(a) * out + math.sin(a) * up) + math.sin(b) * fwd)
             for b in spread(math.radians(-65), math.radians(65), cols)]
            for a in spread(math.radians(35), math.radians(110), rows)]
    return meshgen.slab(grid, lambda p: p - c, 0.03)


def crest_part():
    """The back sail of 06 section 3.6, as a stand-in: three rounded bumps. Origin at its base."""
    grid = []
    for u in spread(0.0, 1.0, 7):
        rise = 0.08 + 0.2 * math.sin(math.pi * u ** 0.7) * (0.75 + 0.25 * math.cos(6.0 * math.pi * u))
        grid.append([(0.0, -0.2 + 0.4 * u + 0.06 * v, -0.03 + v * rise) for v in spread(0.0, 1.0, 3)])
    return meshgen.slab(grid, (1.0, 0.0, 0.0), FIN_THICK)


# ---------------------------------------------------------------- colours and the standard UV layout (06 section 5.4)

def body_colour(p, q):
    """Mid back and flank, light belly, and a navy mouth line (mouth interior, dark block of 06 section 4.1)
    along the lip, where the sharp jaw weights split; it widens as the jaw opens."""
    if p.y < MOUTH_Y and -0.12 <= p.z <= 0.01:
        return MOUTH
    return LIGHT if p.z / max(half_h(p.y), 1e-6) < -0.5 else MID


# Parts placed in the standard layout (06 section 5.4) inside the bake margin (5.5).
_BODY = texgen.place("Fish", "body", TEX, u=(0.05, 0.80))
_TAIL = texgen.place("Fish", "body", TEX, u=(0.80, 1.0))
UV = {
    "dorsal": texgen.place("Fish", "fins", TEX, u=(0.0, 0.5)),
    "pec": texgen.place("Fish", "fins", TEX, u=(0.5, 1.0)),
    "eye": texgen.place("Fish", "eye", TEX, v=(0.0, 0.125)),
    "lid": texgen.place("Fish", "eye", TEX, v=(0.125, 0.25)),
    "crest": texgen.place("Fish", "free", TEX),
}


def body_uv(p, q):
    """Nose at U 0.05, tail root at U 0.80; back edge at the top of the region, belly line at its foot."""
    return _BODY((p.y - Y_NOSE) / (1.0 - Y_NOSE), 1.0 - q[1])


def tail_uv(p, q):
    return _TAIL((p.y - Y_TAIL_ROOT) / (Y_TAIL_TIP - Y_TAIL_ROOT), 0.5 + 0.5 * p.z / (HEIGHT / 2.0))


def fish_meshdata(res, fit):
    """The fish's parts: body, tail, back fin, pectorals, eyes and lids, each a closed volume."""
    md = meshgen.MeshData()
    md.add_part(body_part(res["segs"], res["rings"]), body_colour, uv=body_uv,
                weights=lambda p, q: fit.body_weights(p))
    md.add_part(tail_part(res["tail"]), lambda p, q: DARK if q[0] > 0.55 else MID, uv=tail_uv,
                weights={"TailFin": 1.0})
    md.add_part(dorsal_part(res["dorsal"]), DARK, uv=lambda p, q: UV["dorsal"](*q), weights={"Dorsal": 1.0})
    for side, tag in ((1.0, "L"), (-1.0, "R")):
        md.add_part(pec_part(side, res["pec"]), lambda p, q: ACCENT if q[0] > 0.6 else MID,
                    uv=lambda p, q: UV["pec"](*q), weights={"Pec_" + tag: 1.0}, clamp=(WIDTH / 2.0, 0.0, 0.0))
        md.add_part(meshgen.sphere(eye_centre(side), EYE_RADIUS, (side, 0.0, 0.0), (0.0, 0.0, 1.0), *res["eye"]),
                    lambda p, q: PUPIL if q[0] < 0.4 else EYE_WHITE, uv=lambda p, q: UV["eye"](*q),
                    weights={"Eye_" + tag: 1.0})
        md.add_part(lid_part(side, res["lid"]), MID, uv=lambda p, q: UV["lid"](*q), weights={"Lid_" + tag: 1.0})
    return md


# ---------------------------------------------------------------- the asset

def build():
    fit = rigs.FishFit(LENGTH, half_h, half_w, EYE, PEC, DORSAL_TIP)
    arm = meshgen.build_armature("RIG_Fish", fit.bones())

    body = meshgen.skin(fish_meshdata(RES, fit).to_object(NAME, "GEO"), arm)

    crest_md = meshgen.MeshData().add_part(crest_part(), ACCENT, uv=lambda p, q: UV["crest"](*q))
    crest = meshgen.attach_to_bone(crest_md.to_object(NAME + "_Crest", "SOCKETS"), arm, "Sock_Crest")

    actions = clips.bake_family(arm, rigs.FISH_CLIPS)
    swim = actions[0]

    return {
        "name": NAME,
        "category": "Species",
        "budget": "species_juv",
        "rig": "Fish",
        "uv": {"layout": "Fish", "texture": TEXTURE},
        "armature": arm,
        "origin": "creature",
        "size": (WIDTH, LENGTH, HEIGHT),
        "size_tol": 0.02,
        "facing": {"kind": "bones", "front": "Jaw", "back": "TailFin"},
        "meshes": [
            {"object": body, "role": "body", "primary": True},
            {"object": crest, "role": "piece", "budget": "crest", "socket": "Sock_Crest"},
        ],
        "actions": actions,
        "exports": [
            {"file": "meshes/%s.fbx" % NAME, "objects": [body, arm]},
            {"file": "meshes/%s_Crest.fbx" % NAME, "objects": [crest], "at_origin": True},
            *[clips.export_entry(clip, [body, arm]) for clip in actions],
            {"file": "meshes/%s_RigTest.fbx" % NAME, "objects": [body, crest, arm], "clip": swim, "all_versions": True},
        ],
        "preview": {
            "main": [body, crest],
            "blocks": {"mid": MID, "light": LIGHT, "dark": DARK, "accent": ACCENT},
            "lineup": [
                {"label": "LOD0 with crest", "objects": [body, crest]},
                {"label": "capsule fish silhouette, 3 studs", "objects": [bpy.data.objects["REF_Minnow_T1"]]},
            ],
            "lineup_caption": ["no look-alike species exist yet"],
            "view_captions": {v: ["the thin dark line is the back and tail fins seen edge-on (0.04 studs thick)",
                                  "rendered: body and crest only (see the report's rendered_objects)"]
                              for v in ("Game", "Top")},
            "extras": [{"title": title, "view": view, "pose": pose} for title, view, pose in rigs.fish_poses()],
            "texture": "none (vertex colour; capsule stand-in)",
        },
    }


if __name__ == "__main__":
    import run
    run.main(__file__)
