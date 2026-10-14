"""Triangle and bone budgets, copied from docs/06-art-bible.md section 6.3.

The bible owns these numbers: change it first, then this table.
`tris` is the LOD0 ceiling, `tris_min` a floor where the bible gives a range,
`shell` the outline-shell ceiling (a number, or a share of the body's triangles).
"""

RIG_MAX_BONES = 32          # hard ceiling for any rig, sockets included (tune)
LOD_SHARE = {"LOD1": 0.5, "LOD2": 0.25}   # 06 section 6.4
PREY_LOD2_SHELL = 80        # 06 6.3: a prey _LOD2_Shell gets 80 triangles, or a quarter of its LOD0 shell if more (tune)

BUDGETS = {
    "species_juv": {"tris": 1500, "shell": 600},
    "species_adult": {"tris": 3500, "shell": 1400},
    "puffer_puffed_juv": {"tris": 1800, "shell": 0.4},
    "puffer_puffed_adult": {"tris": 4000, "shell": 0.4},
    "turtle_tucked_juv": {"tris": 900, "shell": 0.4},
    "turtle_tucked_adult": {"tris": 2000, "shell": 0.4},
    "crest": {"tris": 150, "bones": 0},
    "plankton": {"tris": 2, "bones": 0},
    "prey_t1": {"tris": 120, "tris_min": 60, "shell": 80, "bones": 0},   # (tune) 80 since S3-A1: an even 0.033-stud krill shell needs it
    "prey_t2": {"tris": 150, "shell": 60, "bones": 0},
    "prey_t3": {"tris": 300, "shell": 120, "bones": 3},
    "prey_t4": {"tris": 450, "shell": 180, "bones": 3},
    "prey_t5": {"tris": 600, "shell": 240, "bones": 3},
    "prey_t6": {"tris": 900, "shell": 360, "bones": 4},
    "trait_prey": {"tris": 700, "tris_min": 300, "shell": 0.4, "bones": 4},
    "gull": {"tris": 800, "shell": 320, "bones": 0},
    "moray": {"tris": 2000, "shell": 800, "bones": 12},
    "barracuda": {"tris": 2000, "shell": 800, "bones": 12},
    "grouper": {"tris": 3500, "shell": 1400, "bones": 14},
    "old_scar": {"tris": 8000, "shell": 2400, "bones": 24},
    "jelly": {"tris": 300, "bones": 0},
    "anemone": {"tris": 400, "bones": 0},
    "vent": {"tris": 500, "bones": 0},
    "hook": {"tris": 150, "bones": 0},
    "trait_piece": {"tris": 120, "tris_min": 20, "bones": 0},
    "kelp": {"tris": 500, "bones": 4},
    "coral_small": {"tris": 250, "bones": 0},
    "coral_medium": {"tris": 700, "bones": 0},
    "coral_large": {"tris": 1800, "bones": 0},
    "rock_small": {"tris": 120, "bones": 0},
    "rock_medium": {"tris": 350, "bones": 0},
    "rock_large": {"tris": 1000, "bones": 0},
    "floor_chunk": {"tris": 3000, "bones": 0},
    "cliff_module": {"tris": 2500, "bones": 0},
    "landmark": {"tris": 5000, "bones": 0},
    "set_piece_mesh": {"tris": 6000, "bones": 0},
    "cove_shell": {"tris": 6000, "bones": 0},
    "cove_prop": {"tris": 800, "tris_min": 100, "bones": 0},
    # Not a bible row: M_Prop_ScaleCube is a script output (07 section 17 tool row).
    # It is held to the cove-prop ceiling, with no floor.
    "calibration": {"tris": 800, "bones": 0},
    # Not a bible row: the grey-box stand-ins of 07 section 16 (blocks, cones, rings) have no floor.
    "placeholder_block": {"tris": 800, "bones": 0},
}

# Skeletons by family (06 section 6.3). Sockets are extra, weightless bones (06 section 8.4).
_FACE = ["Eye_L", "Eye_R", "Lid_L", "Lid_R"]
_GIRTH4 = ["Girth_Top", "Girth_Bot", "Girth_L", "Girth_R"]
_SOCKETS8 = ["Sock_Back_01", "Sock_Back_02", "Sock_Back_03", "Sock_Flank_L", "Sock_Flank_R",
             "Sock_Head", "Sock_Tail", "Sock_Crest"]
_SOCKETS10 = _SOCKETS8 + ["Sock_FinDorsal", "Sock_FinTail"]

FAMILIES = {
    "Fish": {
        "deform": ["Root", "Spine1", "Spine2", "Spine3", "Spine4", "TailFin", "Jaw", "Dorsal",
                   "Pec_L", "Pec_R"] + _FACE + _GIRTH4,
        "sockets": _SOCKETS10,
    },
    "Eel": {
        "deform": ["Root"] + ["Spine%d" % i for i in range(1, 11)] + ["Jaw", "Dorsal1", "Dorsal2"] + _FACE + _GIRTH4,
        "sockets": _SOCKETS10,
    },
    "Turtle": {
        "deform": ["Root", "Shell", "Neck", "Head", "Jaw", "Flip_FL1", "Flip_FL2", "Flip_FR1", "Flip_FR2",
                   "Flip_BL", "Flip_BR", "Tail"] + _FACE + _GIRTH4,
        "sockets": _SOCKETS8,
    },
    # RIG_Prey3 (07 section 4.0): three sway bones for fish-shaped prey of tier 3 and up under an
    # unweighted Root at the origin (no root weights, 06 15.4). The 06 6.3 bone count (3) is the
    # sway bones; the Tuna's fourth sway bone is a later row.
    "Prey3": {"deform": ["Root", "Spine1", "Spine2", "TailFin"], "sockets": []},
    "Squid": {
        "deform": ["Root", "Mantle1", "Mantle2", "Mantle3", "Fin_L", "Fin_R"]
                  + ["Arm%d_%d" % (a, s) for a in range(1, 7) for s in (1, 2)] + _FACE + ["Girth_L", "Girth_R"],
        "sockets": _SOCKETS8,
    },
}
FAMILY_DEFORM_COUNT = {"Fish": 18, "Eel": 22, "Turtle": 20, "Squid": 24, "Prey3": 4}


def tri_budget(budget_class, role, lod=None, body_tris=None):
    """Ceiling for one mesh. role: 'body', 'shell' or 'piece'."""
    row = BUDGETS[budget_class]
    if role == "shell":
        shell = row.get("shell")
        if shell is None:
            return None
        limit = shell if shell > 1 else int(shell * (body_tris or row["tris"]))
    else:
        limit = row["tris"]
    if lod:
        limit = int(limit * LOD_SHARE[lod])
        if role == "shell" and lod == "LOD2" and budget_class.startswith("prey_t"):
            limit = max(PREY_LOD2_SHELL, limit)
    return limit
