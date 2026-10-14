"""Shared trait-prey textures: the cells of T_TraitPrey_01_Alb to _04_Alb and of T_TraitPrey_Emi
(task S6-A1; docs/07-asset-list.md section 4.2 rows T_TraitPrey_01_Alb to _04_Alb and
T_TraitPrey_Emi; docs/06-art-bible.md sections 5.1, 5.5 and 5.6).

06 5.6: trait prey get 128 x 128 each, packed four to a 256 atlas, at 30 px per stud or more.
Cells (pixels, top-left origin, 128 x 128 each):

  T_TraitPrey_01_Alb   glowfry (0, 0)       zebra_darter (128, 0)
                       dotted_goby (0, 128) lunar_fry (128, 128)
  T_TraitPrey_02_Alb   armor_shrimp (0, 0)  urchin_puff (128, 0)
                       ribbonfish (0, 128)  inklet (128, 128)
  T_TraitPrey_03_Alb   crystal_jelly (128, 0); the three other cells are for launch (07 4.2)
  T_TraitPrey_04_Alb   marrow 01 to 03 (launch)

T_TraitPrey_Emi is one 256 x 256 glow mask for every glowing trait prey (07: Glowfry, Lunar Fry
and Crystal Jelly at soft launch). An emissive mask shares its mesh's UVs, so each glowing prey's
mask sits in its own albedo cell's place, and no two glowing prey may share a cell position:
Glowfry top-left, Crystal Jelly top-right, Lunar Fry bottom-right; bottom-left is free. Spark
Eel, Vent Snail and Marrow (launch) need more places than are left (chapter 14 records it).

A build that paints one cell writes the whole atlas with every cell made so far (as preyart.py
does for T_PreySmall_Alb), so the file is the same whichever build wrote it last: the later
builds call the earlier builds' `paint_cell` (prey/glowfry/build.py for the Glowfry).
"""
import numpy as np

import texgen

SIZE = 256
CELL = 128
MARGIN = texgen.margin_px(SIZE)      # 06 5.5: 4 px at 256

ATLASES = {
    "T_TraitPrey_01_Alb": {"glowfry": (0, 0), "zebra_darter": (128, 0), "dotted_goby": (0, 128), "lunar_fry": (128, 128)},
    "T_TraitPrey_02_Alb": {"armor_shrimp": (0, 0), "urchin_puff": (128, 0), "ribbonfish": (0, 128), "inklet": (128, 128)},
    "T_TraitPrey_03_Alb": {"crystal_jelly": (128, 0)},
    "T_TraitPrey_04_Alb": {},
}
EMI = "T_TraitPrey_Emi"
EMI_CELLS = {"glowfry": (0, 0), "crystal_jelly": (128, 0), "lunar_fry": (128, 128)}
UNPAINTED = (0.5, 0.5, 0.5)          # cells no build has painted yet: flat mid grey


def atlas_of(prey):
    return next(name for name, cells in ATLASES.items() if prey in cells)


def cell_xy(prey):
    return ATLASES[atlas_of(prey)][prey]


def cell_uv(prey, fu, fv, margin=MARGIN):
    """(fu, fv) in 0..1 of the prey's cell (fv 0 at the cell's foot) to atlas UV inside the margin."""
    x, y = cell_xy(prey)
    u0, u1 = (x + margin) / SIZE, (x + CELL - margin) / SIZE
    v1, v0 = 1.0 - (y + margin) / SIZE, 1.0 - (y + CELL - margin) / SIZE
    return (u0 + (u1 - u0) * min(1.0, max(0.0, fu)), v0 + (v1 - v0) * min(1.0, max(0.0, fv)))


def cell_bounds(prey, scale=1):
    """(r0, r1, c0, c1) of the prey's cell in an array with row 0 at V 0, at `scale` x the atlas size."""
    x, y = cell_xy(prey)
    r0 = (SIZE - y - CELL) * scale
    return r0, r0 + CELL * scale, x * scale, (x + CELL) * scale


def compose(cells, kind="alb"):
    """The whole atlas (row 0 at V 0) from painted cells {prey: array CELL x CELL (x 3 for albedo)}."""
    if kind == "alb":
        img = np.ones((SIZE, SIZE, 3)) * np.array(UNPAINTED)
    else:
        img = np.zeros((SIZE, SIZE))
    for prey, pix in cells.items():
        r0, r1, c0, c1 = cell_bounds(prey)
        img[r0:r1, c0:c1] = pix
    return img
