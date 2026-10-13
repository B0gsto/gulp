# Roblox Non-Avatar Game Viability: Technical Feasibility (as of 2026-10-13)

Scope note: research budget was about 14 tool calls. Official Creator Hub pages were fetched for the character controller and MCP server only. Everything else comes from DevForum threads, third-party guides, or press, and is flagged as such. Items marked **Gap** need primary-source verification before design decisions depend on them.

## 1. Replacing the default avatar (StarterCharacter, CharacterAutoLoads, controllers)

### Takeaway
A custom non-humanoid character is feasible through `Players.CharacterAutoLoads = false` plus manual `LoadCharacter()`. Roblox's newer Character Controller Library (CCL) is the intended path for custom movement, but it is still beta and is documented around Humanoid-driven characters. Whether it works on a character with no Humanoid is **Gap**.

### Cited Findings
- Controller types documented: GroundController, AirController, ClimbController, SwimController. ControllerManager sits in the character model, handles physical simulation, and exposes `BaseMoveSpeed`, `BaseTurnSpeed`, `UpDirection`. Controllers hold tuning properties such as `MoveSpeedFactor`, `TurnSpeedFactor`, `AccelerationTime`, `DecelerationTime`, `MoveMaxForce`, `TurnMaxTorque`, `PitchMaxTorque`, `RollMaxTorque`. — [Roblox Creator Hub: Controllers](https://create.roblox.com/docs/en-us/characters/character-controller-library/controllers.md)
- CCL status: "CCL is in beta. You must enable it through File > Beta Features, then turn it on in Avatar Settings." — [Roblox Creator Hub: Controllers (characters path)](https://create.roblox.com/docs/characters/character-controller-library/controllers). **Conflict:** the en-us `.md` page fetched in the same session states no beta/release status. Treat the beta label as the more specific claim, but verify it in Studio.
- CCL is opt-in: Avatar Settings > Movement > Abilities > Character Controller Library. Running, Jumping, Climbing are on by default. Roblox warns not to disable Running (ground movement breaks) and to keep Getting Up enabled when Falling Down is enabled. — [Controllers (en-us)](https://create.roblox.com/docs/en-us/characters/character-controller-library/controllers.md)
- Humanoid properties copy one way into ability attributes and do not stay in sync both ways. Custom abilities are described in a separate guide the controllers page links to (not fetched). — [Controllers (characters path)](https://create.roblox.com/docs/characters/character-controller-library/controllers)
- Legacy physics controller (older tutorial): ControllerManager with GroundController and ClimbController, GroundOffset must stay below GroundSensor SearchDistance. The page is older and may not match current CCL. — [Roblox Creator Hub: Character controllers](https://create.roblox.com/docs/physics/character-controllers)
- `Players.CharacterAutoLoads` defaults to true. When false, characters do not spawn until `Player:LoadCharacter()` is called, including on join. — [Players API reference](https://developer.roblox.com/api-reference/class/Players)
- DevForum reports on CharacterAutoLoads = false: spawn position may be 0,0,0 unless spawn logic is synced with load; StarterGui contents are copied into PlayerGui only at first spawn, so GUI is missing until `LoadCharacter()`; a custom ball character failed to respawn and needed `Humanoid.Died` plus `LoadCharacter()` after a delay. — [DevForum 2483239](https://devforum.roblox.com/t/2483239), [DevForum 2188517](https://devforum.roblox.com/t/custom-spawn-script-not-working/2188517), [DevForum 2807595](https://devforum.roblox.com/t/custom-character-wont-respawn/2807595), [DevForum 2482626](https://devforum.roblox.com/t/2482626)

### Inferences
- A "no Humanoid" character is most robust when the game owns the full pipeline: `CharacterAutoLoads = false`, a custom `LoadCharacter` flow that places the model, and your own physics/controller. This avoids Humanoid-driven defaults (animate script, health, death), but then you must reimplement death, respawn, and state.
- The DevForum respawn reports suggest that a custom non-Humanoid character needs an explicit death signal rather than relying on `Humanoid.Died`.

### Gaps
- Whether CCL runs without a Humanoid. The docs describe Humanoid-to-ability attribute syncing, so this is unclear.
- Official Roblox guidance on custom abilities and custom (non-humanoid) characters. Only a link was seen.
- Whether CCL beta has reached general release by 2026-10-13. Sources conflict.

## 2. Networking: ownership, prediction, server authority

### Takeaway
Roblox's 2026 answer to server-authoritative movement is "Server Authority," announced July 2026 and gated on Next Generation Replication. Its exact status (beta vs. release) and whether it covers custom controllers are unconfirmed.

### Cited Findings
- Roblox security docs: a determined exploiter controls local state and network traffic, so client-side enforcement is bypassable and validation must be server-side. — [Security and cheat mitigation tactics](https://create.roblox.com/docs/en-us/scripting/security/security-tactics)
- Server Authority is described in a DevForum post titled "[Full Release] Ship Fair And Competitive Games with Server Authority." The post says exploiters can no longer inject movement the server does not expect, the server runs scripted abilities and accepts movement the game's code defines as legal, and Next Generation Replication is required. — [DevForum 4727993](https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993)
- Roblox newsroom (July 2026) positions Server Authority as a foundation for responsive, cheat-resistant games. The cheating-is-"basically gone" line is promotional, not a measured result. — [Roblox newsroom 2026/07](https://about.roblox.com/newsroom/2026/07/creating-responsive-cheat-resistant-games-roblox-server-authority)
- Network ownership docs exist (scripting/security/network-ownership). Not fetched. — [Network ownership](https://create.roblox.com/docs/en-us/scripting/security/network-ownership.md)
- A third-party article says Server Authority is in client beta and validates each physics step. It also says it costs more server compute per player. Unverified. (Source not stable; treat as weak.)
- Open-source Chickynoid describes a server-authoritative character controller meant to replace Humanoid characters. Found via a mirror, not the GitHub page. (Weak.)

### Inferences
- A non-humanoid character with its own movement is exactly the case where the server must validate movement. Server Authority is the sanctioned route, but it likely means the server simulates the controller, so budget server CPU per player.
- Client prediction for custom controllers is probably the developer's responsibility unless CCL/Server Authority provides it. Not verified.

### Gaps
- Official Creator Hub page for Server Authority, its beta/release status, and its API surface.
- Whether Server Authority supports fully custom (non-CCL) physics.
- Official guidance on client prediction for custom characters.

## 3. Art pipeline (Blender, meshes, bones, textures, animation)

### Takeaway
Forum and third-party sources agree on a 21k-triangle per-MeshPart cap and 4 bone influences per vertex. No official Creator Hub page for these was retrieved, so these numbers are unverified against primary docs.

### Cited Findings
- Skinned MeshPart beta: 50k triangles per rig and 10k per mesh at beta; later raised to 21k. — [DevForum 705528](https://devforum.roblox.com/t/skinned-meshpart-studio-beta/705528); [DevForum 831011](https://devforum.roblox.com/t/skinned-meshparts-are-live/831011?page=38)
- Current guides: 21,000-triangle hard cap per MeshPart; one August 2026 guide recommends staying under 10,000 for safety. — [Nilo: triangle limit](https://nilo.io/articles/vibe-code-roblox-triangle-limit)
- UGC accessories capped at 4,000 triangles per mesh (multiple guides; not primary). — [Nilo: rig 3D assets](https://nilo.io/articles/rig-3d-assets-roblox)
- Maximum of 4 bone influences per vertex (Nilo 2026; DevForum beta notes agree). — [Nilo: rig 3D assets](https://nilo.io/articles/rig-3d-assets-roblox)
- Avatar Joint Upgrade converts Motor6D joints to AnimationConstraints, and allows connecting chains of Bones. — [Nilo: vibe code export guide](https://nilo.io/articles/vibe-code-roblox-export-guide) (secondary)

### Inferences
- Skinned characters with many players need a tight triangle budget (well under 21k, practically under 10k for mobile) and few bones.

### Gaps
- Official limits: MeshPart triangles/vertices, texture size caps, SurfaceAppearance PBR limits, moderation/upload delays. Not retrieved.
- IKControl, custom animation via the Animation Editor, EditableMesh/EditableImage, the 3D Importer workflow: not researched.
- Upload costs, moderation delays: not researched.

## 4. Visual features (Future lighting, atmosphere, post-processing, UI, branding)

### Takeaway
Lighting technology choice is the main mobile lever. Future is the most expensive, ShadowMap is a middle ground, and Voxel is the lightest. Those claims come from secondary guides. The official docs were not retrieved, and custom shaders and CoreGui replacement were not researched.

### Cited Findings
- Future lighting is the best-looking option but needs more GPU. ShadowMap is a middle ground and Voxel is the lightest for mobile. — [Nilo: Roblox Studio light mobile](https://nilo.io/articles/roblox-studio-light-mobile) (secondary; search snippet only)
- Post-processing effects commonly listed: Bloom, ColorCorrection, DepthOfField, SunRays, Blur. — (community plugin pages; unverified)
- Studio Lite (browser) exposes only a subset of lighting objects and lacks full lighting technology settings. — (search summary, no reliable URL; **Gap**)

### Inferences
- A non-Roblox art style is achievable with post-processing and lighting controls. Mobile is likely to force ShadowMap or Voxel.

### Gaps
- Official Creator Hub pages for Future lighting, Atmosphere, custom materials (MaterialVariant), particles, and camera scripting.
- Custom shader status (believed unsupported; not confirmed).
- CoreGui replacement (topbar, chat, leaderboard, backpack) and the custom loading screen.
- What Roblox branding cannot be removed (not researched).

## 5. Performance (mobile, StreamingEnabled, budgets)

### Takeaway
No primary performance guidance was retrieved. Based on the sources above, the main levers are triangle counts, bone counts, and lighting technology.

### Inferences
- Many skinned characters with custom physics will load the server (Server Authority cost) and clients (skinning and draw calls). Budget per-player server CPU early.

### Gaps
- StreamingEnabled behavior with custom characters, instance and draw-call budgets, memory limits. Not researched.

## 6. Tooling: AI-assisted development outside Studio, on macOS

### Takeaway
The official Studio MCP server runs on macOS, so an AI agent can drive a Mac-based Studio session. Rojo/Argon/Wally are the common file-sync and package options, but macOS-specific 2026 support was not confirmed.

### Cited Findings
- Official Studio MCP server: enable via Assistant > ⋯ > Manage MCP Servers > Enable Studio as MCP server. Quick-connect clients: Antigravity, Codex CLI, Claude Code, Claude Desktop, Cursor, Gemini CLI, VS Code. Any stdio client works. — [Roblox Creator Hub: Studio MCP](https://create.roblox.com/docs/studio/mcp)
- Tools: script read/edit (multi-edit), fuzzy script search (max 10 results), grep (max 50), mesh/material/procedural generation, asset search/insert/upload, Data model exploration, Luau execution in Edit/Client/Server contexts, play-mode start/stop, console output, screenshots, character movement and simulated input, documentation fetch, session listing. — [Studio MCP](https://create.roblox.com/docs/studio/mcp)
- macOS: config launches the StudioMCP binary inside RobloxStudio.app. Windows uses mcp.bat. Linux not mentioned. Each tool call needs a `studio_id` when several Studio windows are open. Clients can read and modify open places, so only trusted clients should connect. — [Studio MCP](https://create.roblox.com/docs/studio/mcp)
- Roblox's February 2026 update added playtest console, play-mode control, and mode-check tools. A MoguraVR report mentions an August 20, 2026 update letting agents edit open sessions, but the article was truncated and not verified. — [MoguraVR](https://www.moguravr.com/?p=346779) (unverified)
- Open Cloud Luau Execution: run Luau in a place headlessly for testing, config, or procedural generation. Tasks run up to 5 minutes, max 10 concurrent per place. Changes are saved with `SavePlaceAsync`. Auth via API key (`x-api-key`), OAuth2, or cookie. Some translated pages label endpoints "Beta." — [Open Cloud: Luau Execution](https://create.roblox.com/docs/en-us/cloud/reference/features/luau-execution.md)
- Argon: a DevForum thread says v2 includes the features of Rojo plus more. The post is a user comment with no clear date. — [DevForum 2021776](https://devforum.roblox.com/t/argon-vs-code-sync-plugin/2021776)
- Wally: a repo aggregator shows the last push on 2026-01-28. — [gittrend: Wally](https://gittrend.io/repo/UpliftGames/wally) (secondary)
- A July 2026 skills page recommends Studio + Rojo + Rokit + Wally, and says Script Sync has been a full release since June 2026. — (secondary; unverified)
- Roblox Studio on Mac: the MCP official doc confirms a macOS Studio binary exists. A Roblox Wiki stub says Studio supports macOS 10.13+. — [Roblox Wiki: Roblox (Mac)](https://roblox.fandom.com/wiki/Roblox_(Mac)) (stub; dated)

### Inferences
- A solo developer on a 16 GB Mac can run the AI agent in a terminal, edit Luau locally with Rojo, and use the MCP server for in-Studio testing. Headless tests can run through Open Cloud Luau Execution against a published place, rather than against a local place.
- Lune, luau-lsp, Selene, StyLua, TestEZ/Jest-Lua, roblox-ts, and the Studio Assistant were not researched. Their status is **Gap**.
- Windows-only: the MCP launcher on Windows uses mcp.bat. The macOS path exists but is a different launcher. Not known to be Windows-only otherwise.

### Gaps
- Rojo, Lune, luau-lsp, Selene/StyLua, roblox-ts, TestEZ/Jest macOS status in 2026. Not researched.
- Place publishing Open Cloud endpoint (only Luau execution was found).
- Asset upload API details and costs.

## 7. Known limitations for non-humanoid characters (checklist)

- Default animate script, control scripts, camera occlusion, swimming, climbing, seats, tools, proximity prompts, voice chat, mobile touch controls: **Gap**. Not researched. The CCL SwimController and ClimbController exist, but their interaction with seats, tools, and voice chat is unknown.
- Death/respawn: a non-humanoid character needs its own death signal. (See section 1.)
- GUI and StarterGui copy: with CharacterAutoLoads off, GUI appears only after first LoadCharacter. (See section 1.)

## 8. Platform and event context

### Cited Findings
- RDC 2026 (September 10–12, San Jose) keynote: "Roblox Everywhere" (standalone apps for mobile, PC, consoles); offline and online modes; Chrome-based play late 2026; Roblox Wallet for US creators 18+ late 2026, global 2027; "Roblox Reality" video world model for photorealistic graphics. — [GamesBeat](https://gamesbeat.com/roblox-hits-20-and-opens-rdc-2026-to-invite-the-world-to-play-and-make-games-dave-baszucki-keynote/); [Pocket Tactics](https://www.pockettactics.com/roblox/rdc-2026)
- One blog says DevEx ends in the US in mid-2027. Could not verify against Roblox's own posts. — (unverified)

### Gaps
- Official RDC 2026 notes and dated release notes for CCL, Server Authority, and Future lighting.

## Overall feasibility assessment (inference)
- Feasible now: custom visuals, a custom spawn flow, a custom non-Humanoid character model, and custom controllers with server validation as the design target. Costs: more code to own (death, respawn, prediction, camera, UI), and a dependency on beta/new features (CCL, Server Authority) whose status is unclear.
- Highest risk: the mobile performance budget and the unverified CCL/Server Authority status. Verify both in Studio before committing to architecture.
