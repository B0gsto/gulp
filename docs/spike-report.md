# Sprint 0 spike report

Task S0-T1 (13 §5, Sprint 0). Measured 13–14 October 2026 on the 16 GB Mac (Roblox Studio driven through the
Studio MCP; Blender 5.2.2 headless). **No phone was used:** every phone half (device rows 1 and 3) is "not run".
Evidence files are in `spike/results/` (raw numbers in `spike/results/raw/`). The decision at the end is the
owner's and is left blank.

Result words: **pass** (every criterion of 09 §6.11 or 13 met), **partial** (the Mac half or some questions pass;
the rest are not run or fail), **fail**, **not run**.

## 1. Technical spike items (09 §6.11)

| ID | Result | Measured | Where | Evidence |
|---|---|---|---|---|
| S1 | **partial**: Mac pass; phone not run | 10/10 play starts: `CharacterAdded` on server (0.2–2.2 ms after `player.Character = model`) and client (0.34–0.91 s after the client's hello); plain `Model`, no Humanoid; 0 console errors or warnings in 10 starts and 3 runs of about 100 s | Mac, Studio | tech-a S1 |
| S2 | **partial**: Mac pass; phone fps not run | All 7 tier scales: Mac 60.0 fps (vsync cap), p99 ≤ 19.2 ms; physics velocity responds in the same frame in 32/32 bursts and 13/14 patterns (1 frame once, after 13 s idle); tier speed reached exactly, 90% in 0.30–0.40 s; heading error 0.06° | Mac, Studio; device rows 1 and 3 not run | tech-a S2 |
| S3 | **pass** (with finding F1) | Largest rig pop at 0, 100 and 200 ms: cruise 0.023–0.056 studs (limit 2), dash 0.10–0.20 studs (limit 4). The rig trails the root 6.1–6.4 studs at 38 studs/s and 12.5–13 studs in a dash | Mac, two Studio clients, incoming lag 0 / 0.1 / 0.2 s (RTT 0.033 / 0.233 / 0.433 s) | tech-b S3 |
| S4 | **pass** (thin margin, F9) | Server `root.CFrame` write reached the owner in 0.017–0.063 s at 0 ms, 0.108–0.173 s at 100 ms, 0.212–0.272 s at 200 ms (limit 0.3 s; 12 of 42 writes untimed, 8 of them confirmed within 2.7 studs). Freeze: 0.000 studs server drift over 2 s at every lag | Mac, one and two Studio clients | tech-a S4, tech-b S4 |
| S5 | **pass** | Persistent shell complete (150/150) at every client `CharacterAdded` (13/13); `PauseOutsideLoadedArea` froze the non-Humanoid root for 86–121 ms after a 4,000-stud teleport without anchoring it (harmless); server saw `GameplayPaused` true then false | Mac, Studio | tech-a S5 |
| S6 | **partial**: server and bytes pass; Mac client pass; phone not run | Server simulate p50 0.33 ms, p99 0.41 ms per tick (budget 2.0). Interest and send about 0.13 ms per recipient per tick crowded (budget 0.25, 09 §15.2); simulate + interest for 24 recipients p50 3.35 ms, p99 4.98 ms crowded. Worst server frame 1.37 ms. Bytes ≤ 3.36 kB/s per player (budget 6). Mac client: 80 pooled parts by `BulkMoveTo`, 60 fps, draw step p99 1.13 ms | Mac, Studio; 23 of 24 recipients simulated; device row 1 not run | tech-b S6 |
| S7 | **partial**: intact pass; Wi-Fi loss not run | 900-byte buffers: 400/400 at 20 Hz and 300/300 at 60 Hz intact (0 corrupt, duplicate or reordered). ≥ 999 bytes dropped every time, silently. On the wire about 930–980 bytes per 900-byte payload (server `DataSendKbps`) | Mac, Studio loopback | tech-b S7 |
| S8 | **partial**: Mac pass; phone not run | `AnimationController` + `Animator` on a client-cloned rig plays a KeyframeSequence (stand-in, then the real `A_Fish_Swim`, bones within 0.0001 studs of Blender); body, LOD1 and shell deform on one skeleton; 24 rigs at 16.67 ms mean, p99 17.8–18.8 ms (vsync cap) | Mac, Studio; device row 1 not run | tech-c S8, tech-d item 1 |
| S9 | **partial**: keyboard and camera pass; touch and drag not run | `CameraType` stayed `Scriptable`; stub `PlayerModule` (0 children), no default controls; keyboard (3 `InputBegan`) drove `SwimInput`, 44–46 studs moved. Mouse not separately tested | Mac, Studio; touch needs device row 1 | tech-a S9 |
| S10 | **pass** (Studio list) | With all `CoreGuiType` off: nothing drawn in the top 70 px but Studio's own drag bar; no menu button in Studio. `GuiService.TopbarInset` still reserves x 0–120, y 0–58 px. Real client and phone list still open (U19) | Mac, Studio | tech-a S10 |
| S11 | **pass** | Relative requires load in Roblox, Lune 0.10.5 and luau-lsp 1.70.1 strict (same values; negative control caught) | Mac | tech-a S11 |
| S12 | **fail, inconclusive** (time-box used twice) | Owner corrections up to 66–68 studs/frame; resimulation 2,232 callbacks at 100 ms vs 527 at 0. Retry: pops to 104–105 studs. Cause: under `AuthorityMode = Server`, `SetNetworkOwner` throws and the step ran on the client only, so the server never ran the same input. 24 server bots: callback p50 0.13 ms, physics step p50 0.9–1.0 ms (< 4 ms). R2's fallback stays closed | Mac, Studio | tech-b S12, tech-d item 5 |
| S13 | **not run** | — (ProfileStore needs Studio API access on a published experience; GULP Dev does not exist yet, task S0-M1) | — | — |
| S14 | **pass** (weak: one Mac clock) | After 13.3 s: `GetServerTimeNow − os.time` 0.005–0.015 s; client vs server `GetServerTimeNow` ≤ 0.012 s (limit 0.25) | Mac, Studio | tech-a S14 |
| S15 | **pass** | Full loop 3/3, then 10/10 starts, no human click; cycle 4.7–5.6 s. Two clients: yes through `StudioTestService:ExecuteMultiplayerTestAsync(2, {})`, not through `start_stop_play`; ended by `EndTest("…")` | Mac, Studio MCP | tech-a S15, tech-b surprise 7 |
| S16 | **pass** (needs `ChatVersion = TextChatService`, F3) | `DisplayBubble` on a plain Part drew a 149 × 32 px bubble with `CoreGuiType.Chat` off. Under LegacyChatService nothing is drawn | Mac, Studio | tech-a S16 |
| S17 | **not run** | — (needs the GULP CI experience and an Open Cloud key; task S0-M1). U9 open | — | — |
| S18 | **pass** | `Model:ScaleTo(6.5)` on the playing skinned rig: 0.15–0.47 ms, no errors; clip kept playing; bone rotations unchanged; socket crest error 0.000 studs | Mac, Studio | tech-c S18 |

**S6 budget reading.** 09 §8.4 puts the 2.0 ms on the simulate steps 1–5 of the tick ("Budget 2.0 ms per tick,
0.35 ms averaged per frame"), and 09 §15.2 gives interest and send its own row (0.25 ms per player per tick, 4
players per frame). Read that way the server half passes (0.33 ms simulate; about 0.13 ms per recipient p50, about
0.19 ms at p99 by subtraction). If the owner reads S6's "server step ≤ 2.0 ms" as simulate plus interest, the
crowded case (p50 3.35 ms) fails and the S6 row of the decision table applies.

## 2. Art spikes (06 §18.2)

The acceptance line says "each of the six art spikes"; the Sprint 0 table has seven (S0-A1 to S0-A7). All seven
are reported.

| ID | Result | Measured | Where | Evidence |
|---|---|---|---|---|
| S0-A1 Calibration | **pass** | FBX `global_scale` 0.01 gives 4 × 4.000001 × 4.1 studs, arrow on Front (−Z), no manual fix; vertex colours arrive as sRGB bytes (grey reads 0.502) | Blender + Mac Studio | art-blender, tech-c S0-A1 |
| S0-A2 Rig | **partial** | Shell outline draws (pass). `Bone.Transform` beside a clip: pass only on `PreRender` (F15). Bone spread: pass (Girth +30%). Rigid piece on a socket: pass by `RigidConstraint`, error 0.000 studs. Bones: 18 deform arrive; weightless sockets dropped; sockets kept at weight ≥ 0.02 (22 imported) or made by code (28 total). 32 bones not tested | Blender + Mac Studio | tech-c S0-A2, tech-d item 2 |
| S0-A3 Surface | **partial** (1 fail, 2 pass on Mac) | Vertex colour under a `SurfaceAppearance`: **fail** (renders white-grey). Flat roughness removes the shine: pass by eye. Emissive mask (strength 3, tint `#FFE2A8`): pass on Mac; target phones not run | Mac Studio | tech-c S0-A3 |
| S0-A4 Trait | **pass**: option B | B (overlay shell built into the template): IoU 0.994. A (Decal) projects per face, not by UV: fail. C (EditableImage as `ColorMapContent`): refused to game scripts. A clone added to a live rig stays in bind pose (IoU 0.645–0.648) | Mac Studio | tech-c S0-A4, tech-d items 3–4 |
| S0-A5 Lighting | **partial**; phone gate not run | Legacy fog caps hit: ball contrast 0.003 at 220 studs (cap 220), 0.008 at 450 (cap 350). Atmosphere presets of 06 §10.2 never hid the ball by 600 studs (Nursery 0.04 at 600); Density 0.45–0.80 changed nothing (cause not isolated). GPU frame: base 3.55 ms, 96 beams 3.79, 16 swapped caustic frames 4.26; swap 24 µs Lua. Realistic vs Soft not separable (vsync); Realistic single-frame spikes 25–49 ms | Mac Studio; device row 1 not run | tech-c S0-A5, tech-d item 6 |
| S0-A6 Phone | **not run** | — (needs device rows 1 and 3, task S0-M3) | — | — |
| S0-A7 Agent art trial | **fail**: no reviewer pass within three loops | Third review failed on the face. Three extra loops followed; final sheet validates (179 checks, 0 failed, 3 waived) and awaits the owner's sign-off | Blender headless | art-a7 |

## 3. Memory on this Mac (09 §2.5, U15; acceptance line 3)

Measured with `ps -o rss` and `vmmap --summary` (physical footprint), not Activity Monitor.

| Case | RSS | Physical footprint |
|---|---|---|
| Studio idle, place open in Edit | 1.1–1.4 GB | 3.1 GB |
| Studio during a play test | 2.17 GB | 3.6 GB (peak 3.9 GB) |
| Two-client test (editor + server + 2 clients) | 2.5 GB (memory compressed under pressure) | about 9.3 GB (3.1 + 3 × 2.0–2.1); about 6 GB above an open Studio |
| Blender 5.2 headless (cube, fish) | — | peak 385–392 MB |

## 4. Agent art trial effort (S0-A7; acceptance line 4)

Planned: 3 WH (13 Sprint 0 art table), time-box 4 OH.

| Measure | Within the 3-loop trial | Beyond (3 extra loops) | Total |
|---|---|---|---|
| Builder agent turns (tool calls) | about 44 | 12 | about 56 |
| Logged seconds (`date`, understates wall time) | 1,072 s | 150 s | 1,222 s |
| WH (agent build time) | not separable from turns; see above | | |
| OH (owner time) | ______ (owner fills in) | ______ | ______ |

Owner time during the agent loops was about zero; the sign-off review of the final sheet is not yet done.

## 5. Design findings that change or threaten the bible

Proposals only; nothing in the bible was changed on these. Each needs an owner decision.

| # | Finding | Threatens | Proposal |
|---|---|---|---|
| F1 | The 6.7 critically damped spring trails a moving root by 2τv: 6.1–6.4 studs at 38 studs/s, 12.5–13 in a dash | 09 §6.7 (rig vs ball and bite position) | Spring toward root + velocity × 2τ, or spring the offset to zero |
| F2 | The replicated root of a client-owned creature pops 7.3–10.4 studs/frame at dash onset, even at 0 ms lag | Any client code reading raw `root.Position` (bite reach, outlines, UI anchors) | Read the smoothed rig position for visuals |
| F3 | A Rojo-built place defaults to LegacyChatService; `ChatVersion` is not script-writable; `DisplayBubble` then fails silently | 09 chat setup, D7 | Set `ChatVersion` in the project file |
| F4 | Persistent models are absent when StarterPlayerScripts start (even with `IsLoaded`); `PersistentLoaded` fires 3–341 ms later | 09 §6.6 client start | Client waits for `workspace.PersistentLoaded` |
| F5 | Client `CharacterAdded` 0.34–0.91 s after ClientReady in local Studio | 09 §6.3 "controllable within 1.0 s" | Re-measure on a real server with the real map |
| F6 | Streaming properties are unreadable from scripts; the Rojo project file sets them | 09 §6.6 and §15.4 "set by hand in Studio" | Keep them in the project file |
| F7 | `PauseOutsideLoadedArea` freezes a non-Humanoid root without anchoring; it fired once 0.7 s after joining (56–69 ms) | 09 §6.6 grace while paused | Treat as harmless; ignore velocity reads while paused |
| F8 | `UnreliableRemoteEvent` drops ≥ 999-byte payloads every time, silently (V6 says "over 1,000 risk") | 09 §8.6 byte cap | Codec asserts size ≤ 900 |
| F9 | S4 at 200 ms incoming lag arrives at 0.212–0.272 s: about 30 ms margin to 0.3 s | 09 §7 correction timing | Re-check on a real phone and network |
| F10 | Interest is about 90% of prey server cost; keyframes are 77% of records | 09 §8.5 | Stagger keyframes or limit them to Near and Mid |
| F11 | `TopbarInset` reserves x 0–120, y 0–58 px with all core GUI off | 08 HUD keep-out box | Lay the Hud outside `TopbarInset` |
| F12 | Studio throttles a background window to 15 fps; Mac fps are vsync-capped at 60 | 09 §16.4 test method | Bring Studio to front; phone numbers only from devices |
| F13 | The FBX importer drops bones without a vertex weight ≥ about 0.02 (0.01 and below dropped) | 06 §8.4 weightless sockets; the validator's "no weight on sockets" rule | Weight 0.02 per socket, or sockets made by code from a table |
| F14 | A mesh parented to a socket bone imports as a `Motor6D` on RootPart | 06 §8.4 rigid pieces | `RigidConstraint` from the socket bone (error 0.000) |
| F15 | The Animator resets every bone each frame, keyed or not; `PreAnimation` writes are lost | 06 §7.5–7.6 code-driven sway, jaw, eyes | Write code-owned bones on `PreRender` |
| F16 | Vertex colour does not show under a `SurfaceAppearance` | 06 §2.4, §5.3 (vertex colour × SA) | Base colours in the colour map, or no SA; 06 §5.3's fallback for environment meshes |
| F17 | SurfaceAppearance texture maps are not writable by game scripts (Plugin capability), server or client; only `Color`, `AlphaMode`, emissive strength and tint | 06 §8.4 options B and C | Ship pre-made SA instances and clone them; C only through `MeshPart.TextureContent` (no PBR) |
| F18 | A Decal on a skinned MeshPart is projected per face, not by UV | 06 §8.4 option A | Drop option A |
| F19 | A skinned MeshPart cloned onto a live rig stays in bind pose; added to the template before spawning it deforms (IoU 0.994) | Overlays, gear shells, runtime skinned pieces; 09 §6.9 mesh swap | Build skinned pieces into the template |
| F20 | Open Cloud Model upload drops animation; Animation upload takes binary `.rbxm` only. Click-free route works: Blender JSON → KeyframeSequence → Lune `.rbxm` → Open Cloud | 06 §6.7, 07 clip import (owner click) | Adopt the converter (`spike/tools/anim_kfs.py`) |
| F21 | Atmosphere presets of 06 §10.2 never hid a ball at 600 studs; legacy fog hits its caps exactly | 06 §10.2 view-distance targets | Use 06 §10.2's fog fallback until the Atmosphere result is isolated |
| F22 | `Lighting.Technology` is unreadable by scripts; `LightingStyle` and `PrioritizeLightingQuality` are writable from Edit code | 06 §10.1, 15 PF26 | Set them in the project file or build step |
| F23 | The importer leaves `MeshPart.Color` at 163,162,165, darkening faces | 06 §6.7 import | Set `Color` white on import (not verified) |
| F24 | Under `AuthorityMode = Server`: `SetNetworkOwner` throws; string attributes capped at 50 characters; the mode is unreadable | R2 fallback (V20) | Review long-string attributes if Server Authority is ever adopted |
| F25 | Two-client tests cost about 6 GB footprint; `EndTest` needs an argument; SIGTERM does not end them | 09 §2.5 memory rules, R9 | One two-client test at a time, never beside a second Studio |
| F26 | Bible conflicts found by the art builds: Minnow dark `#C2491D` is L* 47 (06 §4.1 asks ≤ 35); a yellow tail is 8% accent (cap 5%); body depth 55% does not fit 06 §6.2's 3.0 × 1.1 size; tier-1 prey shells need about 62 triangles (budget 40) and prey LOD2 shells about 76 (budget 20) | 06 §3.3, §4.1, §4.3, §6.2, §6.3; 03 | Owner rules on each; waivers are logged in the build scripts |
| F27 | Tooling: luau-lsp needs `--definitions` for Roblox globals (U16); Rojo 7.7.1 rejects the implicit `CFrame` form; `Stats.DataReceiveKbps` reads 0 on a Studio client; the shared preview lighting was wrong until S0-A7 loop 2 | 09 §2, §16 | Encode in `tools/check` and the review template |

## 6. Fallbacks the results trigger (13 Sprint 0 decision table)

| Spike | Result | Row of the decision table | Applies? |
|---|---|---|---|
| S1, S9, S10 | partial / partial / pass | "S1, S9 or S10 fails" | No on the Mac; open until device row 1 |
| S2 | partial | "S2 fails on frame rate only" / "on feel" | Open until device rows 1 and 3 |
| S3, S4, S5 | pass | — | No |
| S6 | partial | "S6 or S7 fails" | No under the 09 §15.2 reading; yes if the owner reads 2.0 ms as simulate + interest; phone half open |
| S7 | partial | "S6 or S7 fails" | No in Studio; Wi-Fi loss open |
| S8 | partial | "S8 fails" | No on the Mac; open until device row 1 |
| S12 | fail, inconclusive | Only "S12 passes" has a row | None applies; R2's fallback stays closed |
| S13, S17 | not run | "S13 fails", "S17 fails" | Cannot be judged; the "Go" row needs both to pass |
| S0-A1 | pass | "Calibration fails" | No |
| S0-A2 | partial | "Outline shell does not draw" | No (it draws). Sockets (F13) have no row |
| S0-A3 | partial | "Emissive masks fail on a target device" | No on the Mac; phones open. Vertex colour fail (F16) has no row in 13; 06 §5.3's own fallback covers environment meshes |
| S0-A4 | pass (B) | "Decal overlays do not follow a skinned mesh" | **Yes**: overlays move to a second shell per creature (run-time combining is not available to game scripts, F17) |
| S0-A5 | partial | "Realistic lighting misses 30 fps on device row 1" | Open until device row 1. Fog over Atmosphere is 06 §10.2's own fallback, no row in 13 |
| S0-A6 | not run | — | Open |
| S0-A7 | fail | "The agent art trial cannot reach a reviewer pass in three loops" | **Yes**, unless the owner rules otherwise after signing off the Minnow sheet |
| S1, S2, S6, S8 together | — | "Stop" | Not triggered on Mac evidence; depends on the phone halves |

## 7. Owner actions still needed for the decision

1. Run the phone halves on device row 1 (S1, S2, S6, S8, S9 touch, S0-A3 emissive, S0-A5 gate, S0-A6) and device
   row 3 (S2, S0-A6).
2. Run S13 and S17 once GULP Dev and GULP CI exist (S0-M1).
3. Rule on the S6 budget reading (section 1).
4. Sign off (or reject) the Minnow juvenile sheet from S0-A7 and record OH in section 4.
5. Answer decisions D1, D2, D3, D11 and D12 in chapter 14.
6. Create the community (if D11 chooses it) and then GULP Dev, GULP CI and GULP Staging (S0-M1).
7. Account checks A1 to A3 (S0-M2); device rows 1 and 2 or 3 in hand (S0-M3).
8. Rule on the findings F1 to F27 that need a bible change.

## 8. Decision

Decision: ______ (go / change / stop)

Rows that apply: ______

Signed: ______ (owner)

Date: ______
