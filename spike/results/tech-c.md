# Sprint 0 spike, part C: results (art spikes, Studio half; S8 and S18 on the skinned rig)

Measured on 14 October 2026 on the 16 GB Mac. The FBX files were rebuilt headless (Blender 5.2.2, `with-heavy.sh`;
cube peak 388 MB, fish 392 MB, every check OK). They went into Studio with no manual click: Open Cloud upload, then
`InsertService:LoadAsset` in Edit, then a play test driven through the MCP by `spike/tools/drive_c.py`. Every hold
took the machine `studio` lock, one `heavy` slot and `.locks/studio` (`spike/tools/held.sh`).

- **Upload:** `spike/tools/upload_c.py` reuses `tools/assets.py`. The creator is the owner's user, and the assets
  are private. The manifest is in the git-ignored `spike/out/oc/`.
- **Test code:** `spike/tools/luau/artc.luau` (run as `execute_luau` on the Client, so it has plugin rights) and
  `spike/tools/luau/clip.luau` (the stand-in clip; it runs in both Lune and Studio).
- **Two play tests on the spike place:** run 1 with LightingStyle Soft and PrioritizeLightingQuality off (the
  place's own setting), and run 2 with Realistic and prioritise on. The Soft-with-prioritise-on frame time comes
  from a third session at the end of run 1.
- **Raw numbers:** `spike/results/raw/c-run1-soft.json` and `c-run2-realistic.json`. Screenshots are in
  `spike/out/c-*.png`, which is not committed.
- **Console:** 0 errors or warnings in either run, and none after `ScaleTo`.
- **Housekeeping:** Lighting was restored to Soft with prioritise off, and the `ArtC` folder was removed. Nothing
  was saved. Studio was left in Edit mode.
- **Phones:** none. Every phone half is "not run (needs device row 1)".

## Uploaded assets (private, owner user 11718681576)

| Asset | Type | Id |
|---|---|---|
| `M_Prop_ScaleCube.fbx` | Model | 89699184428054 |
| `M_Species_Base_Fish_RigTest.fbx` (body, LOD1, shell and crest on one skeleton) | Model | 125091724092068 |
| `M_Species_Base_Fish.fbx` | Model | 135992079926798 |
| `A_Fish_Swim.fbx` (uploaded as a Model; see surprise 2) | Model | 127567883988435 |
| `A_Fish_Swim_Stand.rbxm` (code-made KeyframeSequence, built in Lune) | **Animation** | 70745358657372 |
| Test textures: white and flat roughness (identical bytes, so one id), black metalness, emissive stripes, overlay bands | Image | 90248245390211, 138878327518024, 133030237967373, 95542763575176 (the last was "Reviewing" and was not used) |

## Results

| ID | Result | Measured | How |
|---|---|---|---|
| S0-A1 | **pass**, with no manual fix (`FBX_AXIS_FORWARD = '-Z'` is unchanged) | **Size:** 4 × 4.000001 × 4.1 studs (the 0.1 is the arrow), orientation 0,0,0. **Facing:** the navy arrow sits at mesh z −2.05..−1.93, so it is on the **Front** face (−Z, the part's LookVector). The orange face is at −Z, the grey face at +Z (Back), red at −X, green at +X, blue on top and white underneath. The screenshot shows the arrow pointing up on the front, with red on the viewer's right, as `art-blender.md` predicted. **Vertex colours:** all 7 arrive intact (EditableMesh reads `#FF9A3D`, navy `#14213D`, and so on). The grey reads **0.502**, so Studio takes the bytes as sRGB. The import pivots the part on its bounding box, so the centre sits at z −0.05. | `EditableMesh` (`CreateEditableMeshAsync`) colour and face-position read in Edit, plus a 3/4 screenshot. **Note:** the importer leaves `MeshPart.Color` at the default 163,162,165, and the faces render darker than their hex values. Set `Color` to white on import (not verified). |
| S0-A2 | **partial: 4 of 5 pass**; "28 (32) bones accepted": **fail as imported** | **Bones:** only the **18 deform bones arrive**. The importer drops all 10 weightless socket bones (`Sock_*`) in both the body and RigTest uploads. Ten `Bone`s made by code at run time (28 in total) are accepted, and the clip still plays. **Shell outline:** pass. The flipped-face `_Shell` (skinned, `DoubleSided` false) draws as a dark rim around the animated body, and it is absent on the rig with the shell hidden. **Code writing `Bone.Transform` beside a playing clip:** pass, **but only after the Animator** (`RunService.PreRender`). The Animator **resets every bone of the skeleton each frame, even bones the clip has no Pose for**: Jaw was written to 0.60 rad, read 0.60 at the next PreAnimation, then read 0 after the Animator. A PreAnimation write to Spine3 (0.9 rad) was overwritten by the clip (0.01–0.16 rad). PreRender writes held: Jaw 0.60, Spine3 0.50. **Bone spread:** pass. With the 4 Girth bones pushed out by 30% (Girth_L 0.119 of 0.396 studs), the body swells cleanly in the screenshot. **Rigid piece on a socket:** pass, by code. The importer turns the crest (which was a child of `Sock_Crest`) into a `Motor6D` on RootPart. On a code-made `Sock_Crest` bone (under Spine1), a `RigidConstraint` from the bone to the crest **follows `TransformedWorldCFrame` with 0.000 studs of error** (it moved 0.03–0.04 studs with the clip). A per-frame CFrame write gave a 0.006-stud error. | Edit-mode read of the uploaded model, then 8 client-made rigs in play (screenshot `c-rigs.png`). Measurements were taken per frame on PreAnimation and PreRender over 1.2 s (92 frames). |
| S0-A3 | **vertex colour under a SurfaceAppearance: fail.** Flat roughness: pass (by eye). Emissive mask: **pass** | **With a white `ColorMap`, the body renders white-grey: the vertex colours do not multiply under a `SurfaceAppearance`.** The rigs with no SurfaceAppearance keep their orange. **Roughness:** with the flat map (1.0) and metalness 0, the body looks matte. The plastic rigs show a highlight band along the back. **Emissive:** `EmissiveMaskContent`, `EmissiveStrength` (3) and `EmissiveTint` (`#FFE2A8`) exist and are writable. The striped mask glows in bands and blooms (Bloom 0.6 / 24 / 0.95). | `SurfaceAppearance` with `*MapContent = Content.fromUri(id)` on the body MeshPart; Studio screenshot only. These properties were set with plugin rights; LocalScript rights were not tested. |
| S0-A4 | **B works. C works, but loses vertex colour. A does not follow the UVs.** | **A, Decal** (`Face = Right`, `TextureContent` = EditableImage, over a white SurfaceAppearance): it draws on the skinned mesh, but the bands are straight and evenly spaced. The same image through UVs (C) curves and crowds at the head, so **a decal is projected per face, not along the mesh UVs**. **B, overlay shell:** a clone of the body MeshPart at 1.005× with a `SurfaceAppearance` (`AlphaMode = Transparency`, bands with a transparent background) draws the bands with the body's vertex colours showing between them. It costs the extra triangles. It was checked in a still frame only; whether the clone deforms with the clip was not measured. **C, composite:** an `EditableImage` (256², `WritePixelsBuffer`) set as `ColorMapContent` works in a Studio client, but the vertex colour is lost (see S0-A3). | One rig per option in `c-rigs.png`. **Recommendation:** choose B, or C if base colours move from vertex colour into the texture. A's premise fails. |
| S0-A5 (Mac half) | **partial.** Phone gate: not run (needs device row 1) | **Settings:** `Lighting.LightingStyle` and `PrioritizeLightingQuality` are writable from Edit (plugin) code. `Lighting.Technology` is not readable at all ("lacking capability RobloxScript"). The spike place defaulted to Soft with prioritise off. **Frame time** for the Nursery-like scene (a 1,400-stud sand floor, 160 rocks and spheres, 5 marker balls and 24 animated rigs; Nursery values from 06 §10.2 plus ColorCorrection and Bloom), mean / p99 / max in ms: **Soft, prioritise off:** 16.67 / 17.8 / 18.2 (Atmosphere 0.32), 16.67 / 18.5 / 19.7 (Atmosphere 0.50), 16.67 / 18.8 / 19.1 (fog). **Soft, prioritise on:** 16.66 / 18.7 / 19.0. **Realistic, prioritise on:** 16.67 / 18.6 / 25.9 (Atmosphere 0.32), 16.72 / 18.7 / 49.4 (Atmosphere 0.50), 16.67 / 18.8 / 25.3 (fog). All runs are vsync-capped at 60 fps, so the Mac cannot separate the styles; only Realistic showed single-frame spikes. **Look, by eye:** with the Nursery Atmosphere (Density 0.32 or 0.50), the floor barely fades out to the horizon, and the open sky stays visible because the scene has no water ceiling. Legacy fog (start 55, end 220, `#4CCFD2`) puts a clear cyan wall at about 220 studs. **The 220-stud ball test is invalid:** the marker balls sat behind the rig swarm. | `drive_c.py`; `RenderStepped` dt over 300 frames with Studio in front; screenshots `c-*-atm032.png` and `c-*-fog220.png`. The ranges in 06 §10.2, the beam cost and the caustic-frame cost were **not run**. |
| S8 (Mac half) | **pass (Mac)**; 30 fps on a low phone: not run (needs device row 1) | **The clip was uploaded as an Animation asset:** a KeyframeSequence built in Lune from the imported skeleton (a sine wave on Spine1–4 and TailFin, 16 frames, 0.533 s), uploaded through Open Cloud as `Animation` (70745358657372). `Animator:LoadAnimation` on a **client-cloned** rig (`AnimationController` + `Animator`, no Humanoid) loaded it (Length 0.533) and played it: `IsPlaying` true, `TimePosition` advancing, Spine4 up to 0.256 rad. **Several MeshParts on one skeleton:** body, LOD1 and shell all report `HasSkinnedMesh` and deform together on one RootPart bone tree. **24 rigs on screen**, each playing its own track, in the lit scene: 16.67 ms mean, p99 17.8–18.8 ms (vsync cap). | The real Blender `A_Fish_Swim` clip did **not** come through (surprise 2), so the clip is a stand-in rather than the authored swim. |
| S18 | **pass (Mac)** | `Model:ScaleTo(6.5)` on the playing skinned rig took **0.15–0.47 ms** and raised no error or warning. Body 0.7 × 1.1 × 3 became 4.55 × 7.15 × 19.5, and `GetScale()` returned 6.5. The track kept playing. Bone rotations were unchanged (Spine4 max 0.256 rad before and after), and the tail swing grew with the size (0.23 to 2.6 studs, phase-dependent). The `RigidConstraint` crest still followed its socket bone exactly (error 0.000). In the screenshot, the 6.5× rig keeps its shell rim and looks undistorted next to a 1.0× rig. | `drive_c.py` (`M.scale`); `c-scale.png`. |

## Surprises (for chapter 06, chapter 09 and the art pipeline)

1. **The FBX importer drops weightless bones.** All 10 `Sock_*` sockets vanish, and a mesh parented to a socket
   becomes a `Motor6D` on RootPart. The 06 §8.4 plan (sockets in the rig, pieces attached to them) needs one of
   these:
   - sockets made by code from a placement table, which works and was measured here;
   - a tiny skin weight on each socket, which was not tested.
2. **Open Cloud Model upload drops the animation.** `A_Fish_Swim.fbx` arrives as a mesh, an `AnimationController`
   and `InitialPoses`, with no KeyframeSequence. Open Cloud *does* accept an `.rbxm` KeyframeSequence as assetType
   **Animation**. The no-click route for real clips is therefore an offline FBX-to-KeyframeSequence converter (Lune
   can write the `.rbxm`, as done here), or Studio's animation import, which takes a manual click.
3. **The Animator resets every bone of the skeleton each frame**, not only the keyed ones. Code-owned bones (jaw,
   eyes, spread, look-at) must be written on `PreRender`, after the Animator, every frame.
4. **Vertex colour does not show under a `SurfaceAppearance`.** The 06 §5 "vertex colour × SurfaceAppearance"
   assumption fails in Studio: base colours need to live in the colour map, or use no SurfaceAppearance.
5. **A Decal on a skinned MeshPart is projected per face, not mapped by UV**, so overlay option A cannot draw
   UV-placed patterns.
6. **`Lighting.Technology` is unreadable by scripts.** `LightingStyle` and `PrioritizeLightingQuality` can be set
   from Edit and from plugin code, so they can go in the project file or a build step.
7. **The Mac cannot rank the lighting styles:** every run is pinned at 60 fps. Only Realistic showed one-frame
   spikes (25–49 ms).

## Not run

- Every phone half: S0-A5 gate, S8 at 30 fps, S0-A6 (needs device rows 1 and 3).
- S0-A5: the 220-stud visibility judgement (redo with the balls clear of the swarm and a water ceiling), the real
  ranges for 06 §10.2, the beam cost and the 16 swapped caustic frames.
- S0-A2: a skin-weight workaround to keep the sockets.
- S0-A4 B: whether the cloned overlay deforms with the clip.
- Run-time LocalScript permission for `*MapContent` and `EditableImage`.
