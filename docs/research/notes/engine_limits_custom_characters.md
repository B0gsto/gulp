# Roblox engine limits and behaviours for custom non-Humanoid characters (as of Oct 2026)

Coverage note: about 15 tool calls. Several official doc URLs returned 404 (custom-characters, Rojo docs page, the Rojo docs path, StarterGui). Many items below are gaps and need a fetch of a corrected URL or the Roblox engine reference before use.

## Mesh limits (import, skinning, textures, upload)

### Takeaway
The only verified official numbers are 20,000 triangles per general mesh and a 4-influences-per-vertex cap. Bone counts, texture resolution, PBR map support, and upload fees were not found on fetched official pages.

### Cited Findings
- Individual meshes cannot exceed 20,000 triangles; avatar items have their own budgets on separate pages — [Roblox General specifications](https://create.roblox.com/docs/art/modeling/specifications) (fetched, verified, undated; copyright 2026)
- A vertex cannot be influenced by more than 4 bones or joints — [Roblox General specifications](https://create.roblox.com/docs/art/modeling/specifications) (fetched, verified)
- Only a single animation track can be exported with a mesh or model — [Roblox General specifications](https://create.roblox.com/docs/art/modeling/specifications) (fetched, verified)
- Accessories: layered and rigid accessories each have a 4k triangle budget; layered accessories must be a single mesh — search snippet of [Roblox docs](https://create.roblox.com/docs/avatar/layered-accessories/specifications) (search result only, not fetched)
- Character body total is listed as 10,742 triangles across 15 body parts, and the root bone should not be weighted — search snippet of [character body specifications](https://create.roblox.com/docs/avatar/character-bodies/specifications) (search result only, not fetched). A separate older guide says each part is under 10,000 triangles — [custom characters resource](https://create.roblox.com/docs/resources/beyond-the-dark/custom-characters#rigging) (search result only; conflicts with the body spec figures and is older)
- Bones/joints must be frozen with scale 1,1,1 — search snippet of [General specifications](https://create.roblox.com/docs/art/modeling/specifications) (fetched page's wording not confirmed in the fetch output)

### Inferences
- The 20,000-triangle figure is the authoritative per-mesh cap for general (non-avatar) meshes. Its interaction with the avatar-specific budgets is unclear.

### Gaps
- Maximum total bones/joints per skinned mesh: not stated on the fetched General specifications page, which refers to the R15 standards page (not fetched).
- Bone influence beyond 4: confirmed 4 max; no page confirmed a different number.
- Maximum texture/image resolution: not found (the spec page points to a separate texture specifications page, not fetched).
- SurfaceAppearance PBR map support (Color, Normal, Metalness, Roughness): not fetched.
- Upload fees and moderation delays for meshes, images, animations and audio in 2026: not found on any fetched page.

## Player character without a Humanoid

### Takeaway
Yes, a Player.Character can be any Model without a Humanoid, per a 2023 DevForum reply by an engine-aware user. Official docs were not reachable. Everything that depends on the Humanoid (camera subject, default controls, health, respawn, animations via Animator) must be replaced by custom code.

### Cited Findings
- "Player.Character has to be a Model, it's a typed C++ property, but it does not need to contain a Humanoid Instance." Roblox's default player scripts assume a Humanoid-based avatar, so you must build your own camera and input or modify the scripts — [DevForum: Does a player have to be a humanoid?](https://devforum.roblox.com/t/does-a-player-have-to-be-a-humanoid/2572541) (fetched; forum reply, August 31, 2023, not official)
- "A player doesn't need to include a humanoid, but it's a lot easier if it does." Workaround: a model named StarterCharacter in StarterPlayer, with an AnimationController replacing the Humanoid's Animator — same thread (fetched; forum, Aug 2023)
- Suggested approach to avoid auto-spawning: set Players.CharacterAutoLoads to false and assign the model in script (`Player.Character = model`) — same thread (fetched; forum, Aug 2023)
- Without a Humanoid, the camera must be set manually (subject), controls must be coded (WASD, space, mobile), health must be custom, and animations go through an AnimationController — same thread (forum, Aug 2023)
- Clothing/avatar items lost without a Humanoid — [DevForum: How to apply Shirt and Pant to a Non-Humanoid Custom Character?](https://devforum.roblox.com/t/how-to-apply-shirt-and-pant-to-a-non-humanoid-custom-character/241277) (search snippet only, not fetched; old thread)
- Non-Humanoid reference system: Chickynoid is cited as an example of a custom character system — same 2023 thread (forum reply)

### Inferences
- Respawn, name display (BillboardGui/Humanoid DisplayName), chat bubbles, voice chat, ProximityPrompts, Tools and Seats are likely tied to Humanoid behaviour in the engine, but I did not verify any of these against an official page. Treat them as unverified and test in Studio.

### Gaps
- Respawn and name display: not covered by the fetched thread (first page only).
- Chat bubbles, voice chat, ProximityPrompts, Tools, Seats, streaming and replication focus: no official or fetched source. The official custom characters page returned 404.
- What ball, vehicle and creature games do in practice: only the forum leads above; no survey found.

## Hiding or replacing default UI

### Takeaway
The StarterGui:SetCoreGuiEnabled signature and the full Enum.CoreGuiType value list are verified. Which types can be disabled, the topbar, the loading screen API, and mandatory UI were not confirmed.

### Cited Findings
- `SetCoreGuiEnabled(coreGuiType, enabled)` takes an Enum.CoreGuiType and a boolean — [StarterGui reference](https://create.roblox.com/docs/reference/engine/classes/StarterGui) (fetched, verified)
- Enum.CoreGuiType values: PlayerList 0, Health 1, Backpack 2, Chat 3, All 4, EmotesMenu 5, SelfView 6, Captures 7, AvatarSwitcher 8, ExperienceShop 9 — [CoreGuiType enum reference](https://create.roblox.com/docs/reference/engine/enums/CoreGuiType) (fetched, verified; the page does not say which can be disabled)
- Input Action System docs note that Roblox reserves certain inputs, such as the Esc menu and F9 console, and these cannot be overridden — [Input Action System docs](https://create.roblox.com/docs/en-us/input/input-action-system.md) (fetched, verified)

### Inferences
- The Esc menu and F9 console are reserved by the engine and cannot be replaced (per the input docs). Treat other items on the list as unverified.

### Gaps
- Which CoreGuiType values are non-disableable: not stated on any fetched page.
- Topbar, TextChatService customisation, leaderboard, backpack, emotes: no fetched official page. The TextChatService docs were not fetched.
- ReplicatedFirst:RemoveDefaultLoadingScreen: not verified; the StarterGui page did not contain it.

## Custom camera and input

### Takeaway
The Input Action System is the newer cross-platform input layer. It has 5 action types and gamepad, keyboard/mouse, and touch bindings. Two of its tools are still beta as of the page's last update. Its default-on status was not confirmed.

### Cited Findings
- Action types: Bool, Direction1D, Direction2D, Direction3D, ViewportPosition — [Input Action System docs](https://create.roblox.com/docs/en-us/input/input-action-system.md) (fetched, verified)
- Each action should have an InputBinding for gamepad, keyboard/mouse, and touch — same page (fetched, verified)
- Enable with the Workspace property `PlayerScriptsUseInputActionSystem` set to `Enum.RolloutState|Enabled` — same page (fetched, verified)
- InputActionLabel and the Input Action Manager are beta, enabled via File > Beta Features — same page (fetched, verified). Page metadata last_updated 2026-10-12.
- Touch gestures (swipe, pinch), haptics, and PreferredInput are documented; console and gamepad support are accepted on Xbox and PlayStation controllers — [search snippets from create.roblox.com docs](https://create.roblox.com/docs/en-us/input/mobile.md) (search result only, not fetched)

### Inferences
- A non-humanoid character can drive its own camera by setting the camera subject to its model, and read input through the Input Action System or ContextActionService. The 2023 forum thread says this is required.

### Gaps
- Whether the Input Action System is on by default in 2026: not confirmed; the setting is documented as an opt-in property.
- Console requirements beyond what the input docs say: not fetched.
- Scriptable camera API details: not fetched (the camera docs page was not retrieved).

## Rendering and lighting

### Takeaway
No official source confirmed a "Future" lighting technology, custom shader support, or a 2026 post-processing list. Search results were low quality. Treat this section as a gap.

### Cited Findings
- The Lighting service covers shadows, ambient light, bloom and color correction — low-quality search snippet only, not an official source
- Custom GLSL shaders are not supported natively — conflicting, low-quality search snippets only; no official page found

### Gaps
- Future lighting availability and date: not found.
- Custom shaders in 2026: not found on an official page. The 2025 status in the brief remains unconfirmed.
- Particle, Beam and Trail limits and mobile budgets (triangles on screen, draw calls, memory): not fetched.

## Animation, EditableMesh/EditableImage, server authority

### Gaps
- IKControl, Animator on non-humanoid rigs, animation priority, Bone.Transform procedural animation, and client-to-server animation replication: not fetched. The 2023 forum thread notes that AnimationController can drive an animation on a model without a Humanoid, and that a rig generally needs a PrimaryPart and Motor6D joints.
- EditableMesh / EditableImage status and publishing restrictions in 2026: not researched.
- Server-authoritative model status in 2026 and support for non-humanoid characters: not researched.

## Rojo on macOS

### Takeaway
Rojo's latest release on the GitHub releases page is v7.7.1, released 02 Oct. Rojo syncs with Studio through a plugin, and macOS support is active. Command-line place publishing (rojo build plus Open Cloud) was not verified.

### Cited Findings
- Latest release v7.7.1, released 02 Oct (year not shown on the page); v7.7.0 released 02 Jul — [Rojo GitHub releases](https://github.com/rojo-rbx/rojo/releases) (fetched, verified; the year was not shown and must be confirmed)
- v7.7.0 fixes a bug where macOS paths weren't handled correctly; v7.7.0 moved the core networking to websockets and MessagePack — same page (fetched, verified)
- v7.7.1 install commands: `cargo install rojo --version 7.7.1` and `rojo plugin install` — same page (fetched, verified)
- Rojo 7.1.1 was described as the first release to support Apple Silicon, with `-macos-aarch64` artifacts — [newreleases.io mirror of the Rojo release notes](https://newreleases.io/project/github/rojo-rbx/rojo/release/v7.1.1) (secondary source, search snippet only)
- Rojo 7.7.0 includes a `rojo syncback` command — same GitHub releases page (fetched, verified)

### Inferences
- Rojo syncs with Studio on macOS through the Studio plugin, which the release notes describe as a websocket connection. Studio itself still needs to run for the live sync.
- `rojo build` produces a place file from the command line; Open Cloud publishing would need a separate tool or the Open Cloud API. Neither was verified here.

### Gaps
- Rojo official docs page (rojo.space) and the create.roblox.com Rojo page: 404 or not fetched.
- Command-line publishing to Roblox (Open Cloud place publish): not verified. No publish command appears in the Rojo release notes checked.

## Sources used
- https://create.roblox.com/docs/art/modeling/specifications (fetched)
- https://create.roblox.com/docs/reference/engine/classes/StarterGui (fetched)
- https://create.roblox.com/docs/reference/engine/enums/CoreGuiType (fetched)
- https://create.roblox.com/docs/en-us/input/input-action-system.md (fetched)
- https://devforum.roblox.com/t/does-a-player-have-to-be-a-humanoid/2572541 (fetched; forum, 2023)
- https://github.com/rojo-rbx/rojo/releases (fetched)
- Search snippets only: character body specs, layered accessory specs, custom characters resource, input mobile docs, newreleases.io Rojo mirror
- Failed fetches (404): https://create.roblox.com/docs/art/meshes/mesh-size-and-triangle-limits, https://create.roblox.com/docs/characters/custom-characters, https://create.roblox.com/docs/rojo, https://create.roblox.com/docs/en-us/characters/custom-characters.md
