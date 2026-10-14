"""M_Species_Base_Fish on RIG_Fish, final: task S1-A3 (docs/13-sprint-plan.md Sprint 1; docs/07-asset-list.md
section 2.0 rows M_Species_Base_Fish and RIG_Fish; docs/06-art-bible.md sections 3, 5.4, 6 to 8).

    Blender --background --python assets/source/families/fish/build.py

The family base every Fish species starts from (source only, not uploaded): the family body
(fishbody.FishBody, lofted on the family topology) with the family's neutral numbers and fins
(fishshape.py), at the family size of fishbody (the Minnow's: 3.0 long, 1.365 tall, 0.7 wide),
on the final family skeleton fitted by rigs.FishFit: 18 deform bones and 10 weightless sockets,
the weights every species uses. The export writes the socket table beside the FBX (name, parent
bone, offset). It makes:
  M_Species_Base_Fish         the skinned body: body, fins, eyes and lids in one mesh
  and, from the run.py steps lod and shell (versions.py), on the same skeleton:
  M_Species_Base_Fish_LOD1, _LOD2                       half and a quarter of the triangles
  M_Species_Base_Fish[_LOD1|_LOD2]_Shell, _ShellThick   flipped-face outline shells
  M_Species_Base_Fish_Crest   the family back sail stand-in, rigid on the socket Sock_Crest
  A_Fish_Swim, _SwimFast, _Idle, _Dash, _Bite, _Gulp, _Hit, _Stunned, _TierUp, _Gulped, _Hatch
                              the eleven family clips (rigs.FISH_CLIPS), baked here for the rig
                              review only: their export files (A_*.fbx and .rbxm) come from the
                              Minnow juvenile (species/minnow/build.py, S2-A3, S4-A3, S6-A2)
  M_Species_Base_Fish_RigTest all of the above in one file, for the Studio rig tests
and the weight check (weightcheck.py): the dash squash and stretch and the bite, measured and
rendered. Vertex-coloured in the Minnow palette; the UVs follow the family layout (06 5.4).
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "_shared", "blender"))

import bpy  # noqa: E402

import clips  # noqa: E402
import common  # noqa: E402
import meshgen  # noqa: E402
import mouth  # noqa: E402
import rigs  # noqa: E402
import texgen  # noqa: E402
from fishshape import (EYE, HEIGHT, LENGTH, MOUTH_Y, PEC, WIDTH, Y_BODY_END, Y_NOSE, Y_TAIL_ROOT,  # noqa: E402
                       Y_TAIL_TIP, Z_HI, BODY, body_part, crest_part, dorsal_part, eye_part, lid_part, pec_part,
                       tail_part)

NAME = "M_Species_Base_Fish"

# Rings and segments per part: 1,456 of 1,500 triangles. LODs and shells come from versions.py.
RES = dict(segs=20, rings=20, tail=(5, 5), dorsal=(7, 3), pec=(5, 4), eye=(12, 4), lid=(3, 4))   # eye 12 x 4 (was 5): S4-A3 freed 48 triangles for the mouth interior
TEXTURE = "species_juv"     # 06 section 5.6: 256 x 256, 60 px/stud
TEX = texgen.TEXTURE_CLASSES[TEXTURE][0]

LIGHT, MID, DARK, ACCENT = (common.colour("creatures.minnow." + k) for k in ("light", "mid", "dark", "accent"))
EYE_WHITE, PUPIL = "#FFFFFF", common.colour("ui.ink")
MOUTH = PUPIL               # mouth interior: the darkest value, so the gape reads at 48 px


# ---------------------------------------------------------------- colours and the standard UV layout (06 section 5.4)

def body_colour(p, q):
    """Mid back and flank, light belly, and a navy mouth line (mouth interior, dark block of 06 section 4.1)
    along the lip, where the sharp jaw weights split; it widens as the jaw opens."""
    if p.y < MOUTH_Y and -0.12 <= p.z <= 0.01:
        return MOUTH
    return LIGHT if p.z / max(BODY.bot(p.y), 1e-6) < -0.45 else MID


# Parts placed in the standard layout (06 section 5.4) inside the bake margin (5.5).
_BODY = texgen.place("Fish", "body", TEX, u=(0.05, 0.80))
_TAIL = texgen.place("Fish", "body", TEX, u=(0.80, 1.0))
UV = {
    "dorsal": texgen.place("Fish", "fins", TEX, u=(0.0, 0.5)),
    "pec": texgen.place("Fish", "fins", TEX, u=(0.5, 1.0)),
    "eye": texgen.place("Fish", "eye", TEX, v=(0.0, 0.125)),
    "lid": texgen.place("Fish", "eye", TEX, v=(0.125, 0.25)),
    "crest": texgen.place("Fish", "free", TEX),
    "mouth": texgen.place("Fish", "mouth", TEX),                # S4-A3: the mouth interior (mouth.py)
}


def body_uv(p, q):
    """Nose at U 0.05, tail root at U 0.80; back edge at the top of the region, belly line at its foot."""
    return _BODY((p.y - Y_NOSE) / (Y_BODY_END + BODY.poles[1] - Y_NOSE), 1.0 - q[1])


def tail_uv(p, q):
    return _TAIL((p.y - Y_TAIL_ROOT) / (Y_TAIL_TIP - Y_TAIL_ROOT), 0.5 + 0.5 * p.z / 0.5)


def fish_meshdata(res, fit):
    """The fish's parts: body, tail, back fin, pectorals, eyes and lids, each a closed volume. Every
    weight comes from the family fit: the body's skin, the back fin's root following the skin under
    it, the rigid parts on their bones."""
    md = meshgen.MeshData()
    md.add_part(body_part(res["segs"], res["rings"]), body_colour, uv=body_uv,
                weights=lambda p, q: fit.body_weights(p))
    body_count = len(md.verts)
    md.add_part(tail_part(res["tail"]), lambda p, q: DARK if q[0] > 0.78 else MID, uv=tail_uv,
                weights=fit.part_weights("tail"))
    md.add_part(dorsal_part(res["dorsal"]), lambda p, q: DARK if q[1] > 0.6 else MID, uv=lambda p, q: UV["dorsal"](*q),
                weights=lambda p, q: fit.fin_weights("Dorsal", p, q[1]))
    for side, tag in ((1.0, "L"), (-1.0, "R")):
        md.add_part(pec_part(side, res["pec"]), lambda p, q: ACCENT if q[0] > 0.6 else MID,
                    uv=lambda p, q: UV["pec"](*q), weights=fit.part_weights("pec", tag), clamp=(WIDTH / 2.0, 0.0, 0.0))
        md.add_part(eye_part(side, res["eye"]), lambda p, q: PUPIL if q[0] < 0.36 else EYE_WHITE,
                    uv=lambda p, q: UV["eye"](q[0] ** 0.5, q[1]), weights=fit.part_weights("eye", tag))
        md.add_part(lid_part(side, res["lid"]), MID, uv=lambda p, q: UV["lid"](*q), weights=fit.part_weights("lid", tag))
    mouth.add_mouth(md, body_count, fit, UV["mouth"], k=fit.k)     # S4-A3: the lip seam and the mouth interior
    return md


# ---------------------------------------------------------------- the asset

def build():
    fit = rigs.FishFit(BODY, EYE, PEC, (0.0, 0.18, Z_HI))   # Sock_FinDorsal at the back fin's top
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
        "weight_check": {"body": body, "rings": RES["rings"], "segs": RES["segs"]},
        "rig_k": fit.k,
        "meshes": [
            {"object": body, "role": "body", "primary": True},
            {"object": crest, "role": "piece", "budget": "crest", "socket": "Sock_Crest"},
        ],
        "actions": actions,
        "clip_files": False,      # the A_ files are the Minnow's (S2-A3); this build does not overwrite them
        "exports": [
            {"file": "meshes/%s.fbx" % NAME, "objects": [body, arm]},
            {"file": "meshes/%s_Crest.fbx" % NAME, "objects": [crest], "at_origin": True},
            {"file": "meshes/%s_RigTest.fbx" % NAME, "objects": [body, crest, arm], "clip": swim, "all_versions": True},
        ],
        "preview": {
            "main": [body, crest],
            "blocks": {"mid": MID, "light": LIGHT, "dark": DARK, "accent": ACCENT},
            "lineup": [
                {"label": "LOD0 with crest", "objects": [body, crest]},
                {"label": "template reference fish (this base's silhouette, 3 studs)", "objects": [bpy.data.objects["REF_Minnow_T1"]]},
            ],
            "lineup_caption": ["species built on this base: the Minnow juvenile (species/minnow)"],
            "view_captions": {v: ["the thin dark line is the back and tail fins seen edge-on (0.04 studs thick)",
                                  "rendered: body and crest only (see the report's rendered_objects)"]
                              for v in ("Game", "Top")},
            "extras": [{"title": title, "view": view, "pose": pose} for title, view, pose in rigs.fish_poses()],
            "texture": "none (vertex colour, Minnow palette; family base, source only)",
        },
    }


if __name__ == "__main__":
    import run
    run.main(__file__)
