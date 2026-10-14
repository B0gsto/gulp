# Art spikes S0-A1 and S0-A2: Blender side

Measured 2026-10-14 with Blender 5.2.2 LTS, headless. Rebuild with
`Blender --background --python assets/source/_shared/scale_cube/build.py` and
`Blender --background --python assets/source/families/fish/build.py`. Studio import not run yet.

## S0-A1 Calibration (`M_Prop_ScaleCube`)

| Item | Measured |
|---|---|
| FBX scale factor (in `_shared/blender/export.py`) | `global_scale` 0.01, Apply Scalings "FBX All", apply unit scale on, scene units None |
| What the file says | FBX 7.4 binary. `UnitScaleFactor` 0.9999999776 (1 unit = 1 cm). Vertex numbers unscaled: X −2..2, Y −2.1..2.0, Z 0..4 |
| Axes | Forward −Z, Up Y. GlobalSettings UpAxis 1 (+), FrontAxis 2 (+), CoordAxis 0 (+). The mesh node carries Lcl Rotation (−90, 0, 0) and its vertex data stays Z-up |
| Facing prediction | The exporter maps Blender −Y (the arrow) to FBX +Z. If Studio puts the arrow on Back, set `FBX_AXIS_FORWARD = 'Z'` |
| Expected in Studio | Size 4 (X) × 4 (up) × 4.1 (depth; the arrow stands out 0.1). Orange face with a navy arrow pointing up on Front. A square tab on the cube's left (Blender +X, the viewer's right), and the same side red. Back face grey |
| Vertex colours | Written as sRGB bytes. Read back from the file: 7 colours, including the grey (128, 128, 128). A reading of about 0.50 in Studio means sRGB; about 0.22 means linear |
| Triangles, file | 44 of 800; 16,108 bytes |

## S0-A2 Rig (`M_Species_Base_Fish` on `RIG_Fish`)

| Item | Measured |
|---|---|
| Bones | 18 deform + 10 sockets = 28 of 32. In the file: 28 LimbNodes under a Null `RIG_Fish` |
| Triangles | Body 1,452 of 1,500; `_LOD1` 704 of 750; `_Shell` 576 of 600; `_Crest` 80 of 150 |
| Shell | Each part is grown 0.12 studs along its own surface normals: the bible's floor, since 6% of 1.1 is only 0.066. Faces are flipped (signed volume < 0) and skinned to the same bones. The pectoral fins are left out because they sit inside the grown body |
| Two meshes on one skeleton | `_RigTest.fbx`: body, `_LOD1` and `_Shell` skinned to one skeleton (84 skin clusters) |
| Rigid piece on a socket | `_Crest` is a child of the bone node `Sock_Crest` in `_RigTest.fbx` (read back from the file's connections) |
| Clip | `A_Fish_Swim`: 16 frames at 30 fps (0.533 s), 17 keys on every curve, all 28 bones keyed, last frame equals first |
| FBX sizes (bytes) | Body 102,604; `_LOD1` 85,468; `_Shell` 81,996; `_Crest` 17,068; `A_Fish_Swim` 288,540; `_RigTest` 397,596 |
| Validation | 117 checks pass, 2 of them by logged waiver (the dark-block L* rows below). Weights at most 4 per vertex, normalised, none on Root or sockets; watertight; one material; one UV set; 06 §4.1 value blocks: mid 58%, light 26%, dark 13.5%, accent 2.4% |
| Poses | Bite: jaw open 52°, head lunges 12% of length, body at 115%. Dash: 125% |

## Both

| Item | Measured |
|---|---|
| Blender peak memory | 385 MB (cube), 390 MB (fish), including EEVEE previews |
| Exporter problems | None blocking. Every 06 §6.7 setting is accepted. `UnitScaleFactor` is 0.9999999776, not exactly 1. Geometry nodes are named `<mesh>.001` (the exporter's triangulated copy); the Model nodes, which Studio uses for names, are correct |
| Bible inconsistency, for the owner | The Minnow's dark `#C2491D` (06 §4.3) is L* 47.4, but 06 §4.1 asks for 35 or less. Validation fails on it. The stand-in passes only through a logged waiver in `families/fish/build.py`; the bible colour is unchanged. Measured dark block on the body, pupils and navy mouth included: L* 38.4 |
