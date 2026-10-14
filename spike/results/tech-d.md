# Sprint 0 spike, part D: results (Mac; open items from parts B and C)

Measured on 14 October 2026 on the 16 GB Mac (tasks S0-A2, S0-A4, S0-A5, S0-C7, S0-C9). Blender 5.2 ran headless
under `with-heavy.sh`. Studio was driven through the MCP by `spike/tools/drive_d.py` (one play test for items 1, 3,
4 and 6, plus a short `ov2` follow-up) and `drive_b.py s12` (item 5). Every hold took the machine `studio` lock, one
`heavy` slot and `.locks/studio` (`spike/tools/held.sh`). Nothing was saved. `ArtC` and `DTexEdit` were removed from
Edit again. Every Lighting change was made in the play data model only. Studio was left in Edit mode, and the S12 tab
was closed with `tools/studio-open.py --close`. Console: 0 errors in the play tests.

- **New tools:**
  - `spike/tools/blender/fish_anim_json.py`: the clip as JSON, plus the socket-weight FBX.
  - `spike/tools/anim_kfs.py`: JSON to KeyframeSequence `.rbxmx`, and the Studio compare.
  - `spike/tools/luau/xml2rbxm.luau` and `dump_bones.luau` (Lune).
  - `spike/tools/upload_d.py`.
  - `spike/tools/luau/partd.luau` and `tex_probe.luau`.
  - `spike/tools/analyse_d.py`.
- **Raw numbers:** `spike/results/raw/d-run.json`, `d-summary.json`, `d-ov2.json` and `d-s12.json`. Screenshots are in
  `spike/out/d/`, which is not committed.
- **Phones:** none were run.

## Uploaded assets (private, owner user 11718681576)

| Asset | Type | Id |
|---|---|---|
| `A_Fish_Swim_KFS.rbxm` (the real Blender clip as a KeyframeSequence) | **Animation** | **135392356967319** |
| `M_Fish_SockW.fbx` (body on RIG_Fish with tiny socket weights) | Model | 97505779898550 |
| `caustic_00..15.png` (256², procedural, RGBA) | Image | 129209278525581, 90286354425515, 88274638838502, 79836571920217, 129599285880051, 126492656281797, 123459640186026, 71151673415870, 124233447296986, 121833050125714, 106600620546018, 122917260206529, 80505127633049, 73929021506909, 74464584574668, 139824206087762 (ids in order in `spike/out/d/caustic_ids.json`) |

## Results

| ID | Result | Measured | How |
|---|---|---|---|
| 1. Animation route (S0-A2, S8) | **pass. The real `A_Fish_Swim` plays, with no click.** | **Bone positions** at frames 3, 7 and 12: all 18 imported bones match Blender within **0.0001 studs** (max; the mean is 0.0000). Over those frames, Blender moves the bones up to 0.201 studs. **Clip:** Length 0.533 s, Looped true, Priority Movement, `IsPlaying` true. At speed 1, Spine4 swings up to 0.224 rad and TailFin up to 0.331 rad. The Jaw stays at 0 because the clip keys it at rest. **KeyframeSequence poses drive skinned Bones directly**, so no CurveAnimation was needed. | **Blender:** `fish_anim_json.py` writes each bone's `matrix_basis` and its armature-space head for each frame. **Python:** `anim_kfs.py` fits Blender to Roblox on the rest heads (from the imported rig `.rbxm`, read with Lune). The residual is 0.00000 studs. The mapping is Roblox = (−x, z, y) of Blender, and every bone has the same axis change, a 180° turn about Y. Then `Pose.CFrame = G⁻¹ · matrix_basis · G`. The hierarchy is Keyframe → Pose `RootPart` (weight 0) → Pose per bone, nested like the bones. **Upload:** Open Cloud **rejects `.rbxmx` for Animation** ("model/x-rbxmx … not supported yet"), so Lune converts the file to binary `.rbxm` first. **Studio:** `TimePosition = f/30` at speed 0, then a read of `TransformedWorldCFrame` in RootPart space. |
| 2. Socket bones (S0-A2) | **pass with a weight of 0.02 or more** | The FBX had all 10 sockets set to deform, each with one vertex weighted at one of 5 levels. **Kept:** the 4 sockets at **0.02 and 0.05** (Sock_Head, Sock_Tail, Sock_FinDorsal, Sock_FinTail). **Dropped:** the 6 at **0.01, 0.004 and 0.001**. That gives 22 bones (18 + 4) in the downloaded `.rbxm` and in Studio Edit (`LoadAsset`). The threshold lies between 0.01 and 0.02 and was not narrowed further. | `fish_anim_json.py` (spike-only copy; `assets/` is unchanged). Each weight goes on the nearest vertex that has fewer than 4 influences, 0.011–0.073 studs from the socket head. **Cost:** a weight of 0.02 moves that vertex 2% with the socket. Sockets are not animated against their parent bone, so this is harmless unless code moves a socket. **Options for 06 §8.4:** a weight of 0.02 per socket in the build (and relax the validator's "no weight on sockets" rule), or sockets made by code (part C). |
| 3. Overlay option B deforms (S0-A4) | **pass, if the overlay is added to the rig before it is spawned. A clone added to a live rig does not deform.** | Masks were taken from top-down shots, comparing the body only with the overlay only, on a paused frame-7 bend. **The clone made in the template** (`Rig` before `Clone()`, at 1.005× size): IoU **0.994**, with only 9 body pixels uncovered. **A clone added after the rig was animating** stays in the rest pose: IoU 0.648 at 1.005× and 0.645 at 1.0×, with about 1,980 body pixels uncovered. `HasSkinnedMesh` reads true for every clone. The first run used late clones (IoU 0.62 / 0.86 / 0.97 at frames 3 / 7 / 12, following how far the body bends). The imported `_Shell` covers the body at every pixel. | `D.anim` and `D.pose`, then `D.ov2setup` and `D.ov2show` in `partd.luau`, analysed by `analyse_d.py`. Body and overlays were drawn as white Neon over a black Neon plate. **Rule:** build overlays into the creature template (or author them in Blender as skinned meshes); never clone them onto a live rig. |
| 4. Textures from game scripts (S0-A3, S0-A4) | **SurfaceAppearance maps are not script-writable. MeshPart, Decal and Texture images are.** | **Writable from a server Script and a client LocalScript** (same on both): `Instance.new("SurfaceAppearance")`, parenting it, its `Color`, `AlphaMode`, `EmissiveStrength` and `EmissiveTint`, `MeshPart.TextureID` and `TextureContent` (including `Content.fromObject(EditableImage)`), `Decal.Texture` and `TextureContent`, `Texture.Texture`, `AssetService:CreateEditableImage` and `CreateEditableMeshAsync` (908 vertices read), and cloning a skinned MeshPart. **Refused with "lacking capability Plugin":** `ColorMap` (string), `ColorMapContent`, `NormalMapContent`, `RoughnessMapContent`, `MetalnessMapContent` and `EmissiveMaskContent`. That includes swapping them on an SA made in Edit, and pointing them at an EditableImage. **"lacking capability NotAccessible":** `MeshPart.MeshId` and `MeshContent`. | `tex_probe.luau`, put as source into a `Script` (ServerScriptService) and a `LocalScript` (PlayerScripts) during play, so it ran with game-script rights. **Consequences:** overlay patterns (B) and colour maps must come as **pre-made SurfaceAppearance instances**, cloned and parented. They cannot be assembled at run time. Option C (an EditableImage as `ColorMapContent`) **does not work from game code**. Its only script route is `MeshPart.TextureContent` (no PBR). |
| 5. S12 retry (S0-C9) | **fail as run; still not conclusive** (time-box: 3 turns) | The input is now a pure function of the simulated state: the root's angle on the R = 60 circle gives the heading, and dash sectors replace dash times. So a replayed tick sees the same input. **0 ms:** client callbacks 451 in 12 s (the server's run 368, at 30 Hz with dt 0.0333). Owner pops reached **105 studs** max, with p99 2.8. In 360 of 451 steps the root sat more than 0.5 studs off where the previous step had sent it (p99 8.4 studs). **100 ms:** **1,576** client callbacks (4.3× the server's count), owner pops up to 104 studs, p99 1.8, and 1,575 of 1,576 steps off (p99 17.8 studs). **Server:** callback p50 0.09 ms, `PhysicsStepTimeMs` p50 0.8 ms. | `drive_b.py s12` on a fresh `s12.rbxl` (rebuilt with the new `SpikeBClient` s12 step), opened with `tools/studio-open.py`. **New cause found:** in that place, `SetNetworkOwner` fails ("Can not call Network Ownership API when workspace.AuthorityMode = Server", SpikeServer line 167), and the step runs only on the client. **The server never runs the same input**, so it disagrees on every tick, and the rollbacks are expected. A fair test needs the identical step bound on the server for the player's root (or input sent through the engine's input-action route). Not done. R2's fallback stays closed. |
| 6. S0-A5 (Mac half) | **partial.** Legacy fog meets the 220 and 350 caps. **The Atmosphere does not reach the targets.** Beams and caustics are cheap on the Mac. Phone gate: not run. | **Setup:** white 8-stud balls in a clear lane (no rocks within 30 + 0.15·d studs of the lane), at 60–600 studs, under a 35%-transparent water ceiling at 70 studs. Contrast is ball centre minus the background beside it, in luminance. **Fog** (Nursery, `FogStart` = 25%): **cap 220** puts the 220-stud ball at **0.003**, invisible, and 200 at 0.081, so the ball disappears at 220 as intended. **Cap 350:** the ball fades out by 450 (0.008). **Atmosphere:** the presets in 06 §10.2 never lost the ball by 600 studs (Nursery 0.04 at 600; Reef, Cove, Drop-off deep and Trench all kept contrast at 600). Raising the Nursery Density to 0.45, 0.60 and 0.80 gave **identical** contrast and images, so the haze is not reaching objects in this setup. Kelp and Drop-off upper fell below 2% only at some balls, because the floor colour matched. **Cost** (Studio in front, Nursery, 300 frames each; frame mean 16.67 ms at the vsync cap everywhere). `Stats.RenderGPUFrameTime` mean: base **3.55 ms**, 24 beams 3.85, 96 beams 3.79, a static caustic Texture 3.77, **16 frames swapped at 20 fps 4.26**, at 60 fps 4.18, and 16 EditableImage frames at 20 fps 3.48. GPU p99 was 7.9–8.5 ms in every case. A swap costs **24 µs of Lua**. The 16 caustic images preloaded in 4.0 s (16/16 Success, though still "Reviewing" at upload). The EditableImage run had one 58.7 ms frame. | `D.vis` and `D.cost`; `analyse_d.py` contrast. **Caveats:** in Studio, `RenderCPUFrameTime` reads about 11–12 ms (it seems to include the vsync wait; 2.9 ms in one run), so it is not used. The Atmosphere result may be an artefact of the camera height (Y ≈ 254) or of the ceiling, and it was not isolated. With the time-box, 06 §10.2's fallback rule (use fog when the Atmosphere cannot hit the targets) is the supported route today. |

## Surprises

1. **Open Cloud Animation uploads take binary `.rbxm` only.** An `.rbxmx` is refused ("model/x-rbxmx … not supported
   yet"). Lune converts in one call (`xml2rbxm.luau`).
2. **KeyframeSequence poses drive skinned Bones exactly.** The imported bone frames differ from Blender's by one
   fixed 180° turn about Y for every bone. The converter fits this from the rest pose, so no hand-tuned constants are
   needed.
3. **The FBX importer keeps a bone only if some vertex weight on it is at least about 0.02.** 0.01 and below are
   dropped together with the bone.
4. **A skinned MeshPart cloned onto a live, animating rig stays in its bind pose**, even though `HasSkinnedMesh` is
   true. Added to the template before spawning, it deforms exactly. This applies to overlays, gear shells and any
   runtime-attached skinned piece.
5. **No SurfaceAppearance texture map can be written by game scripts** (Plugin capability), on the server or the
   client. That includes EditableImage content. Only `Color`, `AlphaMode` and the emissive strength and tint can.
   `MeshPart.TextureContent` with an EditableImage does work from a LocalScript.
6. **Under `AuthorityMode = Server`, `SetNetworkOwner` throws.** Part B's S12 rig was therefore never client-owned,
   which is a further reason its numbers are not a fair test.
7. **Atmosphere Density 0.45–0.80 changed nothing measurable** in the visibility scene, while legacy fog behaved
   exactly as set (the 220 cap hits at 220 studs).

## Not run, or left open

- **S12:** a server-mirrored input step, or the engine's input-action replication. Still inconclusive.
- **Socket weight threshold:** not narrowed below 0.02. The validator change is for the owner.
- **Atmosphere:** why the Density does not affect distant objects here (camera altitude, the ceiling or Offset). Not
  isolated.
- **Every phone half:** the S0-A5 gate, caustic and beam cost on a phone, and S8 at 30 fps.
