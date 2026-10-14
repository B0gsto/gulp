# 09 · Technical architecture

This chapter turns section 14 of `01-game-canon.md` into a buildable design. It uses the canon's names, IDs and scope tags. Numbers marked **(tune)** are starting values. Platform facts carry a reference: **V***n* is verified against an official page on 13 October 2026, **U***n* is not verified. Both lists are in section 21. Nothing marked **U** may be relied on until the week-one spike (section 6.11; the canon calls it the Sprint 0 spike) passes.

## 1. Goals and hard constraints

| # | Constraint | What it forces |
|---|---|---|
| G1 | Phones first. Low-end phone holds 30 fps, mid phone 60 fps. | Client draws prey from pools, strict instance and draw-call budgets (section 15), no per-prey Instances on the server. |
| G2 | 24 players per server. | Per-player work on the server is staggered across frames. Every per-player cost in this chapter is multiplied by 24. |
| G3 | About 1,390 live prey in 300 groups, and about 2,710 members in 545 groups during a Feeding Frenzy (normal prey twice normal, chapter 02, section 14.4), with buffers and budgets sized for `MAX_GROUPS = 640` (8.1) **(tune)**. | Prey are bytes in buffers, simulated and replicated per group, not per fish (section 8). |
| G4 | No Humanoid, no avatar, no default interface. | We own spawning, movement, camera, input, health, death, nameplates and chat (section 6.10). |
| G5 | Bites and Pearls cannot be forged. | The client never reports mass, tier or Pearls. It only claims "I bit X"; the server decides (sections 8.9, 10, 14). |
| G6 | Movement feels instant on a phone. | The client owns its root part; the server validates after the fact (section 7). |
| G7 | One human owner, code written by AI agents, on a 16 GB Mac. | Source on disk, every check runnable headless, modules small with typed public APIs, Studio driven through the MCP server, at most two heavy jobs at once (section 2.5). |
| G8 | An agent can start a module from this chapter alone. | Every module below has a path, a responsibility, a public API and an owner of each piece of data. |

Out of scope for this chapter: art pipeline (document 07), prices and balance tables (document 05), screens (document 08).

## 2. Toolchain

### 2.1 Tools

Versions are the latest stable releases on 13 October 2026, read from the GitHub releases API (**V18**). All tools are pinned in `rokit.toml` so every agent and CI run uses the same binaries.

| Tool | Pinned version | Purpose | Config file |
|---|---|---|---|
| Roblox Studio | Latest (self-updating) | World editing, asset import, play tests, publishing the world place | Place settings (section 15.4) |
| Studio MCP server | Ships inside Studio: `/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP` (present on this Mac) | Lets Claude Code read and edit the open place, run Luau, start and stop play, read the console, take screenshots (**V17**) | `.mcp.json` |
| Rokit | 1.2.0 | Installs and pins the tools below | `rokit.toml` |
| Rojo | 7.7.1 | Syncs `src/` into Studio, builds place files, writes `sourcemap.json` | `default.project.json`, `ci.project.json` |
| Wally | 0.3.2 (0.4.0 is alpha, do not use) | Package manager | `wally.toml`, `wally.lock` |
| wally-package-types | 1.7.0 | Re-exports package types so strict mode sees them | none |
| luau-lsp | 1.70.1 | Type checking in the editor and `luau-lsp analyze` in CI | `.luaurc` |
| Selene | 0.32.0 | Lint | `selene.toml` |
| StyLua | 2.6.0 | Format | `stylua.toml` |
| Lune | 0.10.5 (0.11.0 came out on 11 October 2026; move to it after one clean week) | Headless Luau runtime for unit tests, simulations, code generation and Open Cloud calls | none |
| ProfileStore | Single file, vendored at a pinned commit (the project publishes no tagged releases) | Session-locked saves (**V19**) | `src/server/Vendor/ProfileStore.luau` |
| Git + Git LFS | System | Version control; LFS for `assets/**` binaries | `.gitattributes` |
| GitHub Actions | `CompeyDev/setup-rokit@v0.2.1` | Continuous integration (section 16.6) | `.github/workflows/ci.yml` |

This Mac already has Rojo 7.7.0, Lune 0.10.5, StyLua 2.5.2 and Selene 0.31.0 from Homebrew, and luau-lsp 1.70.0 in `~/.local/bin`. Rokit and Wally are not installed. Rokit's shims must win: either remove the Homebrew copies or put `~/.rokit/bin` first in `PATH`.

### 2.2 Install commands

```sh
# 1. Rokit (official installer script)
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
fish_add_path -p ~/.rokit/bin        # this Mac's shell is fish
brew uninstall rojo lune stylua selene   # optional, avoids two copies

# 2. Everything pinned in rokit.toml
cd <repo> && rokit install

# 3. Rojo's Studio plugin
rojo plugin install

# 4. Packages (creates Packages/ and ServerPackages/ once a dependency exists)
wally install && rojo sourcemap default.project.json --output sourcemap.json \
  && wally-package-types --sourcemap sourcemap.json Packages/

# 5. Studio MCP: in Studio open Assistant > ... > Manage MCP Servers > Enable Studio as MCP server,
#    then pick Claude Code in the Quick connect list. The repo also carries .mcp.json (below).
```

### 2.3 Config files

`rokit.toml`

```toml
[tools]
rojo = "rojo-rbx/rojo@7.7.1"
wally = "UpliftGames/wally@0.3.2"
wally-package-types = "JohnnyMorganz/wally-package-types@1.7.0"
luau-lsp = "JohnnyMorganz/luau-lsp@1.70.1"
selene = "Kampfkarren/selene@0.32.0"
stylua = "JohnnyMorganz/StyLua@2.6.0"
lune = "lune-org/lune@0.10.5"
```

`.mcp.json` (JSON taken from the Studio MCP page, **V17**)

```json
{ "mcpServers": { "Roblox_Studio": { "command": "/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP" } } }
```

`.luaurc`

```json
{ "languageMode": "strict", "lint": { "*": true } }
```

`selene.toml`: `std = "roblox"`. `stylua.toml`: `syntax = "Luau"`, `column_width = 100`, `indent_type = "Tabs"`, `quote_style = "AutoPreferDouble"`, `call_parentheses = "Always"`, and `[sort_requires] enabled = true`. These keys were not re-fetched this session (**U16**); `stylua --check` and `selene` reject unknown keys, so a wrong key fails loudly on first run.

`wally.toml` starts with no runtime dependencies. The game needs a signal class (60 lines, written in `src/shared/Util/Signal.luau`) and a save library (vendored). A package is added only when it replaces more than 200 lines of our own code, and it is added to this table first. No registry versions were verified, so none are named here (**U21**).

### 2.4 The edit, sync, run, test loop

| Step | Who | Command or tool | Needs Studio |
|---|---|---|---|
| 1. Edit files under `src/`, `tests/`, `tools/` | Agent | File edits | No |
| 2. Headless gate | Agent | `lune run tools/check` (runs `stylua --check src tests tools`, `selene src`, `rojo sourcemap`, `luau-lsp analyze`, unit tests, simulation tests) | No |
| 3. Sync | Human starts once per Studio session | `rojo serve default.project.json`, then Connect in the Rojo plugin | Yes |
| 4. Play test | Agent, through MCP | `list_roblox_studios` → `get_studio_state` → `start_stop_play` → `execute_luau` (Server: run engine tests; Client: probes) → `get_console_output` → `screen_capture` → `start_stop_play` | Yes |
| 5. Report | Agent | Pass or fail, the console lines that matter, one downscaled screenshot if a visual check was asked for | No |

The type-check command (flags confirmed with `luau-lsp analyze --help` on this Mac):

```sh
rojo sourcemap default.project.json --output sourcemap.json
luau-lsp analyze --platform roblox --sourcemap sourcemap.json --base-luaurc .luaurc \
  --definitions @roblox=.cache/globalTypes-<version>.d.luau \
  --ignore "Packages/**" --ignore "**/Vendor/**" src
```

`--definitions` is required: without it the CLI does not load Roblox globals and reports every one as unknown (spike, F27; **U16** settled). `tools/check` downloads the file that belongs to the luau-lsp version pinned in `rokit.toml` into `.cache/` (not committed).

**Tool traps found in the spike (F27).** `tools/check` enforces the first two; the review of a diff (R15) checks all three:

- `luau-lsp analyze` without `--definitions` still passes shared modules that use no Roblox global, which hides the missing flag until a module touches one. `tools/check` always passes the flag.
- Rojo 7.7.1 rejects the implicit `CFrame` property form (`{"position", "orientation"}`) in project files with only "Failed to deserialize JSON". Write the explicit `{"CFrame": {...}}` wrapper. `tools/check` builds `ci.project.json` and every project file is built before a publish, so a wrong form fails there.
- `Stats.DataReceiveKbps` reads 0 on a Studio client. Bytes received are measured on the server (`DataSendKbps`, or our own byte counters), never from that property in Studio.

Every MCP call needs a `studio_id` (**V17**); the agent calls `list_roblox_studios` first and never assumes one. `script_search` returns at most 10 results and `script_grep` at most 50, so agents search on disk with normal tools and use MCP only for what exists solely in Studio. Agents never edit scripts through `multi_edit`: disk is the source of truth and Rojo would overwrite the change.

**Runs headless (no Studio):** formatting, lint, type check, unit tests, economy and prey simulations, content code generation, `rojo build`, publishing the CI place and running engine tests through Open Cloud (sections 16 and 17).

**Needs Studio open:** anything that steps physics, renders, takes input or replicates between a real server and client; editing the world; importing meshes; publishing the world place. Open Cloud Luau execution does not step physics and does not start scripts on its own (**V16**), so it cannot replace a play test.

Fallback if Rojo live sync misbehaves on a Studio update: Studio's built-in Script Sync maps scripts to the same `.luau`, `.server.luau`, `.client.luau` file names (**V32**). It syncs scripts only, which is all we sync anyway.

### 2.5 Memory rules for a 16 GB Mac

Studio rows were measured in the spike as physical footprint (vmmap), not RSS, which reads far lower (**U15** settled, F25); the other rows are estimates.

| Process | Memory |
|---|---|
| Studio, world place open, not playing | 2.5 to 4 GB (spike place: 3.1 GB) |
| Studio play test (server and one client in one process) | add 0.5 to 1 GB (spike: 3.6 GB, peak 3.9 GB in total) |
| Two-client test (a server process and two client processes beside the editor) | add about 6 GB: 2.0 to 2.1 GB each (spike: about 9.3 GB in total) |
| Blender with one species scene | 2 to 6 GB |
| Claude Code, terminal, editor | 1 to 2 GB |

Rules:

1. A Studio play test and a Blender render are both heavy jobs. Never more than two heavy jobs at once.
2. One Studio window only. Close the place before a Blender bake of more than a few minutes.
3. Multi-client tests (section 16.5) use at most two local clients and run with Blender closed. Only one two-client test runs at a time, and never beside a second Studio. It is ended with `EndTest("<reason>")` on the server instance, which closes all three processes: `EndTest()` with no argument raises an error, and SIGTERM does not end them (F25).
4. Headless agents (code, tests, docs) can run in parallel; only one agent at a time holds the Studio MCP session. The lock is an atomic `mkdir .locks/studio`, held only for sync, play, capture and stop.
5. Screenshots are taken through `screen_capture`, saved to disk and downscaled (`sips -Z 768`) before any agent reads them.

## 3. Repository layout

```text
gulp/
├── default.project.json        Rojo: code into the world place (partial sync)
├── ci.project.json             Rojo: complete code-only place for CI
├── world.project.json          Rojo: one-time build of the world place with the 15.4 settings
├── rokit.toml  wally.toml  wally.lock  .luaurc  selene.toml  stylua.toml  .mcp.json
├── .github/workflows/ci.yml
├── docs/                       design bible (this file is docs/09-technical-architecture.md)
├── src/
│   ├── first/                  → ReplicatedFirst.Boot
│   │   └── Loading.client.luau     custom loading screen, removes the default one
│   ├── shared/                 → ReplicatedStorage.Shared
│   │   ├── Types.luau              every exported type used across modules
│   │   ├── Config/                 Version.luau, Defaults.luau (tunable numbers), Flags.luau,
│   │   │                           FtueConfig.luau (every tunable of chapter 04, section 3.1)
│   │   ├── Data/
│   │   │   ├── Generated/          Tiers, Species, Prey, TraitPrey, Traits, Predators, Hazards,
│   │   │   │                       Zones, Tides, PreySpawns, TraitPreySpawns, PreyMotion, Products,
│   │   │   │                       Goals, Codex, RevivePoints, Strings; at [L]
│   │   │   │                       also Patterns, Decorations, Emotes, RankRewards, Landmarks
│   │   │   │                       (GENERATED, do not edit)
│   │   │   └── Index.luau          lookups by ID and by wire index
│   │   ├── Logic/                  pure rules: BiteRules, TierMath, TraitRules, BankMath,
│   │   │                           CoveIncome, TideClock, GoalRules, Migrations, FtueRules
│   │   ├── Sim/                    pure simulation: SwimModel, PreySim, Formation, SpatialGrid,
│   │   │                           Quantize, PredatorSim
│   │   ├── Net/
│   │   │   ├── Remotes.luau        the remote table (name, kind, direction, size, rate)
│   │   │   └── Codec/              one file per packet: PreyState, PreyEvent, Bite, BiteResult,
│   │   │                           PredatorState, PredatorEvent, WorldInfo, CoveView
│   │   └── Util/                   Signal, Ring, TokenBucket, Rng, Log, Assert
│   ├── server/                 → ServerScriptService.Server
│   │   ├── Main.server.luau        ordered loader (section 4.5)
│   │   ├── Services/               one file per service in section 5
│   │   ├── Net/                    Server.luau (creates remotes, validation wrapper), RateLimiter
│   │   ├── World/                  CollisionGroups, VolumeReader, HeightField (used by Services/WorldIndex)
│   │   ├── Dev/                    BotPlayers, Cheats (dev places only; developer commands such as
│   │   │                           `/ftue reset`, run from the server's command line, section 5.1)
│   │   ├── Tests/                  engine-side specs and RunAll.luau
│   │   └── Vendor/ProfileStore.luau
│   └── client/                 → StarterPlayer.StarterPlayerScripts.Client
│       ├── Main.client.luau        ordered loader
│       ├── Controllers/            one file per controller in section 5
│       ├── Render/                 PreyRenderer, CreatureRig, PredatorRig, Pools, Outlines, Fx
│       ├── UI/                     Kit/ (buttons, panels, tween helpers), Screens/, Hud/
│       └── Net/Client.luau
├── tests/
│   ├── unit/                   *.spec.luau, mirrors src/shared
│   ├── sim/                    economy.sim.luau, prey_soak.sim.luau, movement_fuzz.sim.luau
│   └── fixtures/profiles/      v1.json, ... one saved profile per schema version
├── tools/
│   ├── check.luau              the headless gate
│   ├── check_place_file.luau   15.4 settings read from a saved place file (Lune)
│   ├── test/runner.luau        the spec runner (describe, it, expect)
│   ├── gen/content.luau        docs tables → src/shared/Data/Generated
│   ├── gen/strings.luau        assets/loc/strings.csv → Strings.luau
│   ├── cloud/                  publish_ci.luau, run_engine_tests.luau (Open Cloud)
│   └── studio/                 snippets for execute_luau: check_place.luau, smoke.luau
├── assets/                     Git LFS. Chapter 07, section 1.3 owns the layout below source/ and export/
│   ├── source/  export/  placeholder/  licences/  manifest.csv
│   ├── loc/strings.csv
│   └── place/                  weekly local copy of the world place (.rbxl)
└── Packages/  ServerPackages/  created by wally, not committed
```

### 3.1 Rojo mapping

The world place is **partially managed**: Rojo owns code and data modules; Studio owns the world, the imported assets and the place settings. This split is forced by the platform: the Open Cloud publish endpoint does not update `SurfaceAppearance`, `EditableImage`, `EditableMesh`, `PartOperation` or `BaseWrap` instances (**V15**), so a place built only from files cannot carry our art.

```jsonc
// default.project.json  (comments are allowed since Rojo 7.6.1)
{
  "name": "gulp",
  "tree": {
    "$className": "DataModel",
    "ReplicatedFirst":  { "$ignoreUnknownInstances": true, "Boot":   { "$path": "src/first" } },
    "ReplicatedStorage": {
      "$ignoreUnknownInstances": true,             // keeps ReplicatedStorage.Assets (Studio-owned)
      "Shared": { "$path": "src/shared" }
      // "Packages": { "$path": "Packages" }       // add with the first Wally dependency
    },
    "ServerScriptService": { "$ignoreUnknownInstances": true, "Server": { "$path": "src/server" } },
    "StarterPlayer": {
      "$ignoreUnknownInstances": true,
      "StarterPlayerScripts": { "$ignoreUnknownInstances": true, "Client": { "$path": "src/client" } }
    },
    "Players": { "$properties": { "CharacterAutoLoads": false } }
  }
}
```

`ci.project.json` has the same mappings plus a `Workspace` with a small flat test arena and `$ignoreUnknownInstances` left at its default, so `rojo build ci.project.json -o build/ci.rbxl` is a complete place.

Studio-owned containers, never touched by Rojo:

| Container | Contents |
|---|---|
| `Workspace.World` | Visual set dressing per zone (streamed) |
| `Workspace.Collision` | Low-polygon collision shell, `ModelStreamingMode = Persistent` (section 6.6) |
| `Workspace.Volumes` | Invisible tagged volume parts, read and destroyed at server start (section 9.1) |
| `ReplicatedStorage.Assets` | One folder per canon section 16 category (`Species/`, `Prey/`, `Pred/`, `Hazard/`, `Env/`, `Cove/`, `Prop/`, `Trait/`) plus `Fx/`, `Ui/`, `Audio/`, holding the imported files of `assets/export/` under their chapter 07 names |
| `Lighting`, `SoundService`, `MaterialService` | Look and sound settings |

### 3.2 Content data

All tunable content is a typed Luau module under `src/shared/Data/Generated/`. The generator `tools/gen/content.luau` reads Markdown tables that sit between `<!-- data:NAME -->` and `<!-- /data -->` markers in `03-content-catalog.md` (creatures, traits, zones) and `05-economy-and-monetization.md` (prices and balance), plus the prey density targets of `02-mechanics.md` (section 9.6, data:PreyTargets) and the prey motion table of `06-art-bible.md` (section 7.6, data:PreyMotion), and writes one module per table (`PreySpawns` joins 02's targets with 03's spawn weights, caps and zone plan areas; `TraitPreySpawns` is 02's trait prey rows, alive per zone, with the zone plan areas; `PreyMotion` is checked against the prey IDs of 03). The tables that only the canon has (tiers, section 5.1; banking bands, section 5.4; scraps, section 5.5; zones, section 6; tides, section 10) are marked in `01-game-canon.md` (tasks S1-D1 and S5-D1). The line right after each opening marker starts "Soft-launch slice (chapter 13, section 3.2):" and lists the IDs (first column) of the rows in the slice, or says "every row" or "no rows", so `lune run tools/gen/content` writes the full build and `lune run tools/gen/content -- --slice` writes only the slice rows, with the same wire indices. CI regenerates and fails on any difference, so the documents and the code cannot drift.

Each row gets a stable **wire index** (its 1-based position in the canon table) used in packets; rows are only ever appended. Each table numbers its own rows from 1, so where two tables share one byte the packet adds an offset: the prey `kind` byte (8.2, 8.7) is the `data:Prey` wire index (1 to 127) for ordinary prey and 128 + the `data:TraitPrey` wire index for trait prey (`Formation.TRAIT_BASE`, `Formation.kindOf` and `Formation.defOf` in `shared/Sim/Formation.luau` are the only places that mapping lives).

```lua
--!strict
export type Scope = "MVP" | "L" | "P1" | "P2"
export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Mythic"

export type TierDef = { tier: number, name: string, massNeeded: number, bodyScale: number,
	swimSpeed: number, turnRate: number }

export type SpeciesDef = { id: string, wire: number, scope: Scope, unlockPearls: number,
	passId: string?, speedMult: number, turnMult: number, radiusMult: number,
	dashCooldown: number, dashDurationMult: number, startTier: number, ability: string }

export type PreyDef = { id: string, wire: number, scope: Scope, tier: number, mass: number,
	givesTrait: string?,            -- trait prey only
	zones: { string }, groupMin: number, groupMax: number,
	behaviour: "drift" | "swarm" | "hop" | "school" | "solo" | "run" | "pack",
	cruiseSpeed: number, fleeSpeed: number,
	turnRate: number,               -- °/s; 0 = turns in any direction (hops, drifts) (03 §2.1, §3.1)
	fleeBurst: number,              -- s; 0 = does not flee (03 §2.1, §3.1)
	fleeRadius: number, scatterGain: number,
	radius: number, wobble: number, eventOnly: string?,
	respawn: number?,               -- s (03 §2.1, §3.1 "Respawn (s)"); nil for event prey
	lifetime: number?,              -- crystal_jelly: s a drift stays (240)
	alive: number?,                 -- trait prey: most alive per server (03 §3.1)
	eventTotal: number? }           -- event prey: animals released per event (lunar_fry 40, marrow 60);
	                                -- `alive` is animals at once too (lunar_fry 12, 3 groups of 4)
	-- Acceleration is not a column: PreySim derives it (8.4, step 3)

export type TraitDef = { id: string, wire: number, scope: Scope, rarity: Rarity,
	incomeBonus: number }           -- 0.10, 0.20, 0.35, 0.60, 1.00 (Common to Mythic, canon 9)

export type PredatorDef = { id: string, wire: number, scope: Scope, tier: number,
	eatsMaxTier: number, speed: number, senseRadius: number, strikeRadius: number,
	telegraph: number, giveUpAfter: number, rest: number,
	eatenMass: number? }            -- barracuda 25, grouper 60 (canon 5.2); nil for every other predator

export type HazardDef = { id: string, wire: number, scope: Scope,
	effect: "stun" | "slow" | "burn" | "yank" | "push", magnitude: number, duration: number,
	cycle: { dormant: number, rumble: number, erupting: number }? }   -- vent only: 4, 1 and 3 s (section 9.4)

export type ZoneDef = { id: string, wire: number, scope: Scope, preyTierMin: number,
	preyTierMax: number, safe: boolean, lightingPreset: string }

export type PreySpawnDef = { zone: string, prey: string, weight: number, cap: number,
	base: number, baseUnit: "groups" | "members",   -- 02 §9.6 counts plankton and tuna as individuals
	perPlayerInside: number?,       -- Nursery only (02 §9.6)
	zoneArea: number }              -- studs² from above (03 §6.1); Logic/PreySpawnMath scales by it

export type TraitPreySpawnDef = { zone: string, prey: string, alive: number,
	zoneArea: number }              -- 02 §9.6 trait prey rows; no playerScale or eventScale

export type PreyMotionDef = { id: string, scope: Scope, draw: string,   -- 06 §7.6, client looks only
	wobble: { hz: number, yawDeg: number, rollDeg: number, bobStuds: number }?,
	sway: { hz: number, ampDeg: number, hzPerStudPerS: number, tailLagS: number? }?,
	hop: { height: number, length: number, timeS: number, restS: number, count: number? }?,
	pulse: { kind: "twinkle" | "glow" | "shimmer" | "squash" | "crawl", hz: number, amount: number? }?,
	driftSpeed: number?,
	flee: { style: string, burstWobbleMult: number?, burstSwayMult: number?, hopMult: number?,
		regroupS: number?, bankDeg: number?, turns: number?, pauseS: number?, rollStuds: number?,
		uncurlS: number?, deeperStuds: number?, jetStuds: number?, inkS: number? } }

export type TideDef = { id: string, wire: number, scope: Scope, fallback: string?, outOfBuild: boolean?,
	spawnRateMult: number, eventPrey: { string } }

export type ProductDef = { id: string,   -- chapter 05 purchase ID, unchanged: pass_<name>, prod_<name>,
	                                     -- pat_<species>_<name> or deco_buy_<name> (section 12.6)
	kind: "pass" | "product",           -- the Roblox ID is Config/Defaults' (per environment), never generated
	scope: Scope,
	grant: string,                       -- "pearls", "token", "pattern", "decoration", "flag" or "bundle"
	amount: number?,
	items: { string }? }                 -- pattern and decoration IDs granted; a bundle (prod_starter_pack) lists several

export type AdPlacementDef = { id: string,   -- chapter 05 placement ID: ad_<name>
	scope: Scope, productId: string, perDay: number }   -- the prod_ product it grants (section 18.3)

-- Chapter 03 owns the rows of the next seven tables; chapter 05 owns their prices and Pearl amounts
export type CodexCategoryDef = { id: string, wire: number, scope: Scope,   -- cdx_species, cdx_tiers, cdx_traits, cdx_prey [MVP];
	                                 -- cdx_dangers, cdx_places, cdx_tides, cdx_all [L] (chapter 03, section 8.1)
	entryPearls: { number },         -- Pearls per entry, by tier or rarity; empty when entries pay nothing
	rewardPearls: number, rewardDecoration: string?, rewardTitle: string? }

export type RevivePointDef = { id: string, wire: number, zone: string,     -- rp_01 to rp_12 (chapter 03, section 6.11)
	x: number, z: number, depth: number }                                  -- world position (x, −depth, z)

export type NurseryPointDef = { id: string, wire: number,                 -- hatch_bed ... home_current_mouth (chapter 03, section 6.2)
	at: number, to: number,                  -- distance along the first-run route; to = at for a point
	x: number, z: number, toX: number, toZ: number,   -- the place; a stretch's start and end
	top: number, bottom: number, toBottom: number,    -- depth band (toBottom: at a stretch's end)
	floor: boolean,                          -- bottom is the sea floor; the band runs up to the surface
	markX: number?, markZ: number? }         -- the landmark a point serves (the Glow Grotto's mouth)

export type PatternDef = { id: string, wire: number, scope: Scope, species: string,   -- pat_<species>_<name>, 18 at launch
	source: "robux" | "codex" | "starter_pack" }                           -- chapter 03, section 1.3

export type DecorationDef = { id: string, wire: number, scope: Scope,      -- 50 rows (chapter 03, section 13); wire is sent in CoveView
	size: "S" | "M" | "L", mount: "floor" | "wall" | "ceiling",
	source: "pearls" | "rank" | "codex" | "goals" | "event" | "starter_pack" | "robux",
	price: number?, shelf: number?,  -- Pearl items: chapter 05 price and shop shelf 1 to 8
	need: number?,                   -- rank to reach, goals.fullDays to reach, or event count to reach
	counter: string? }               -- event items: the stats.events key that is counted (section 12.2)

export type EmoteDef = { id: string, wire: number, scope: Scope }          -- em_<name>; wire 1 to 6 is the index in EmoteAction

export type RankRewardDef = { rank: number, title: string?, decoration: string?, shelf: number? }   -- chapter 03, section 11

export type GoalDef = { id: string, wire: number, scope: Scope,   -- dg_<name> (chapter 03, section 9)
	text: string, target: number, difficulty: "Easy" | "Medium" | "Hard",
	reward: string,                  -- R1 to R5: chapter 05's Pearl reward step
	needs: string?,                  -- the condition for offering it; nil when it needs nothing
	kind: string,                    -- the event counted: chapter 03's Kind column (eat_prey, reach_tier, bank_mass …)
	subject: string?,                -- prey, zone, tide or predator ID, tier, rarity or trait count; nil when none
	pool: "eat" | "grow" | "world" } -- chapter 02's goal pool (section 15.3); the picker draws three different pools where it can

export type LandmarkDef = { id: string, wire: number, scope: Scope, zone: string,   -- lm_<name>: chapter 03's landmark IDs (sections 6.2 to 6.6)
	x: number, z: number, depth: number,                                   -- found within 40 studs (cdx_places)
	codexPlace: boolean }                                                  -- true for the 30 Places of chapter 03, section 8.2
```

Decoration IDs are chapter 03's, used unchanged: `deco_<name>` (Pearls), `deco_rank_*`, `deco_cdx_*`, `deco_goals_*`, `deco_evt_*` and `deco_buy_*`. Landmark IDs are chapter 03's too, used unchanged: `lm_<name>` from the ID column of its landmark tables (sections 6.2 to 6.6), for example `lm_noggin_rock`, `lm_little_arch` and `lm_tin_pickle`. `LandmarkDef.id` is that ID, and the keys of `codex.places` are the `lm_*` IDs of the 30 landmarks chapter 03, section 8.2 lists as Places [L]; the other landmarks have a `LandmarkDef` row with `codexPlace = false` and are never written to the save.

Zone **definitions** are data. Zone **geometry** is authored in Studio as tagged volumes (section 9.1). Roblox asset IDs and product IDs live in `Config/Defaults.luau` per environment (section 17.1), never in generated files.

## 4. Code conventions

### 4.1 Typing and style

- Every file starts with `--!strict`. Hot simulation modules (`Sim/*`, `Net/Codec/*`, `PreyService`, `MovementValidator`) add `--!native` and `--!optimize 2`.
- No `any` in a public signature. A cast (`:: T`) needs a one-line comment saying why it is safe.
- Shared types live in `src/shared/Types.luau` and are imported with `local Types = require("./Types")`.
- StyLua formats; Selene lints with zero warnings allowed; `luau-lsp analyze` must report zero errors.

### 4.2 Module pattern

One module, one table, functions only. No classes unless there are many instances (creature rigs, pooled items).

```lua
--!strict
local Types = require("../Types")
local Tiers = require("../Data/Generated/Tiers")

local BiteRules = {}

--- A creature eats prey of its tier or lower (canon 5.2).
function BiteRules.canEatPrey(eaterTier: number, preyTier: number): boolean
	return preyTier <= eaterTier
end

return BiteRules
```

Services and controllers share one shape so the loader can treat them alike:

```lua
export type Service = { name: string, init: () -> (), start: () -> () }
```

`init` sets up private state and must not yield or call another service. `start` connects events and begins loops; other services are safe to call from here.

### 4.3 Naming

| Thing | Rule | Example |
|---|---|---|
| Content IDs | Canon lowercase IDs | `minnow`, `whale_fall` |
| Modules, types | PascalCase | `PreyService`, `SpecimenRecord` |
| Functions, locals | camelCase | `canEatPrey` |
| Constants | UPPER_SNAKE | `MAX_GROUPS` |
| Remotes | PascalCase noun | `PreyState`, `Bite` |
| Player attributes | PascalCase | `Tier`, `Species` |
| Analytics events | snake_case, from one enum module | `run_banked` |
| Assets | Canon section 16 | `M_Prey_Sardine`, `SFX_Gulp` |

### 4.4 Requires and dependency rules

- Inside one root (`shared`, `server`, `client`) use relative string requires: `require("./X")`, `require("../Data/Index")`. This is what lets Lune load `src/shared` unchanged. Roblox, Lune and luau-lsp resolving these paths identically is spike item S11 (**U10**).
- Across roots, require through the instance tree: `require(ReplicatedStorage.Shared.Net.Remotes)`.

```text
client  ──►  shared  ◄──  server          client and server never require each other
shared/Logic, shared/Sim, shared/Net/Codec, shared/Data:
    no `game`, no Instances, no Vector3 or CFrame, no yielding.
    Numbers, tables, buffers and the standard library only. They must run in Lune.
Services call each other only through the public API in section 5, and only from start() onward.
Only DataService touches ProfileStore. Only EconomyService changes Pearls. Only Net/Server creates remotes.
```

A Selene rule plus a small script in `tools/check.luau` fail the build when a file under `shared/Logic`, `shared/Sim`, `shared/Net/Codec` or `shared/Data` contains `game`, `workspace`, `Instance.new`, `Vector3`, `CFrame` or `task.wait`.

### 4.5 Start-up

No framework. Each side has one script that loads a fixed list in order.

```lua
--!strict
-- src/server/Main.server.luau
local ORDER = { "LiveConfig", "Analytics", "DataService", "WorldIndex", "TideService", "EconomyService",
	"CreatureService", "MovementValidator", "TraitService", "PreyService", "PredatorService",
	"BiteService", "RunLoopService", "CoveService", "ShopService", "GoalsService",
	"CodexService", "LeaderboardService", "EmoteService", "TutorialService", "PlayerLifecycle" }   -- EmoteService is [L]

local loaded: { Service } = {}
for _, name in ORDER do
	loaded[#loaded + 1] = require("./Services/" .. name) :: Service   -- luau-lsp: listed explicitly in real code
end
for _, s in loaded do s.init() end
for _, s in loaded do s.start() end
```

In the real file the requires are written out one per line so the type checker sees them. `PlayerLifecycle` starts last so every service is ready before the first `PlayerAdded` is handled; it also replays `Players:GetPlayers()` for anyone who joined during start-up. The client loader does the same with: `StateStore, QualityController, InputController, CameraController, CreatureController, MovementController, PreyRenderer, PredatorController, TideController, AudioController, UIController, TutorialDirector`.

### 4.6 Errors

- Rule functions return values, never throw. Use `(ok: boolean, reason: string?)` for anything that can be refused.
- `error()` is for programmer mistakes only. `Util/Assert` wraps checks that are compiled out of hot paths in production through a flag.
- Every engine call that can fail (`DataStore`, `MarketplaceService`, `PolicyService`, `ConfigService`, `LocalizationService`, `AdService`) is inside `pcall`, has a stated fallback, and logs through `Util/Log` with a tag. `Log.warn` and `Log.error` also count, by level and tag, into an in-memory counter in `Analytics` (`Analytics.logCounts()`), which tests and the Studio debug print read. No analytics event carries the counts: `AnalyticsService` logs every event against one player, the counts belong to the server, and pinning them to an arbitrary player would skew that player's cohort and spend their rate budget (chapter 10, section 2.4). Error spikes on live servers are read from the Creator Dashboard's own error reports (not verified, section 21.2).
- Remote handlers run inside the validation wrapper (section 14.2), which catches errors so one bad packet cannot stop a service.

### 4.7 Hot paths

A hot path is anything that runs every frame or every tick: `Sim/*`, `Codec/*`, `PreyService.step`, `MovementValidator.step`, `PreyRenderer.render`, `CameraController.update`, `MovementController.update`.

- No yielding (`task.wait`, `:Wait()`, any `Async` call).
- No table or closure allocation per entity per tick. Preallocate buffers and reuse scratch tables.
- No Instance property reads inside per-prey loops. Positions live in buffers.
- No string building.
- Each hot function is wrapped in `debug.profilebegin` and `debug.profileend` with the module name so it shows in the MicroProfiler (**V32**).

## 5. Runtime architecture

```text
                                   SERVER (one per 24 players)
 ┌──────────────────────────────────────────────────────────────────────────────────────────┐
 │ PlayerLifecycle ── join, slot, cove, creature, leave                                     │
 │      │                                                                                   │
 │ DataService ◄── EconomyService ◄── ShopService, RunLoopService, CoveService, GoalsService│
 │ (ProfileStore)        │                                                                  │
 │                 AnalyticsService (wrapper)        TideService (UTC clock) ─► PreyService │
 │                                                                                          │
 │ CreatureService ◄─ MovementValidator        PreyService ─► PredatorService               │
 │   (roots, tier,       (pose history)          (group buffers,    (data state machines)   │
 │    status)                 ▲                    grid, interest)        │                 │
 │        ▲                   │                        ▲                  ▼                 │
 │        └──────── BiteService (prey bites, player bites) ─────► RunLoopService            │
 │                        TraitService      CodexService      LeaderboardService            │
 │ WorldIndex (volumes, height field)       Net/Server (remotes, validation, rate limits)   │
 └───────────────▲──────────────────────────────────┬───────────────────────────────────────┘
   reliable: Bite, Ability, *Action                 │ reliable: State, BiteResult, PreyEvent,
   engine physics: own root part                    │   CreatureEvent, PredatorEvent, TideEvent
                 │                                  ▼ unreliable: PreyState, PredatorState
 ┌───────────────┴──────────────────────────────────────────────────────────────────────────┐
 │                                   CLIENT (each player)                                   │
 │ InputController ─► MovementController ─► own root part (LinearVelocity, AlignOrientation)│
 │ CameraController      CreatureController (rigs for every creature, outlines, nameplates) │
 │ PreyRenderer (pools, far particles, local bite detection)   PredatorController           │
 │ StateStore (mirror of own data)   TideController   AudioController                       │
 │ UIController (Hud, Screens)       TutorialDirector                                       │
 └──────────────────────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Server services

`Slot` is a number 1 to 24 assigned at join; it is the player's index in every buffer and their cove number.

| Service | Scope | Responsibility | Owns | Public API |
|---|---|---|---|---|
| **PlayerLifecycle** | MVP | Join and leave sequence: slot, profile, policy, cove, creature, first state push; leave and shutdown settlement | `slotOf[Player]`, `playerAt[Slot]` | `getSlot(player): Slot?`, `getPlayer(slot): Player?`, `onReady: Signal<Player, Slot>`, `onLeaving: Signal<Player, Slot>`, `policy(player): Policy` (the PolicyService answer stored at join, section 18.2; the most restrictive values until it arrives or when the call failed), `controlGranted(player)` (sends `sys_load_time`, J from `PlayerAdded`, once a session, chapter 10, section 4.2; called at the spawn for an account with `ftue.completed`, and by the tutorial when the hatch ends otherwise) |
| **DataService** | MVP | Load, migrate, session-lock, autosave and release profiles; push state patches to the owner | The ProfileStore session, `Profile.Data` | `get(player): ProfileData?`, `patch(player, path: string, value: any)`, `saveNow(player): boolean`, `onLoaded: Signal<Player>` |
| **EconomyService** | MVP | The only place Pearls change | Nothing persistent (writes through DataService) | `grant(player, amount, source: PearlSource, sku: string?)`, `spend(player, amount, sink: PearlSink, sku: string): boolean`, `balance(player): number` |
| **AnalyticsService** (wrapper, module name `Analytics`) | MVP | Typed front for Roblox `AnalyticsService`; enforces the event list and limits of chapter 10; writes to a memory buffer in Studio | Event name enum (the chapter 10 event dictionary), funnel session IDs | The three calls of chapter 10, section 2.4: `step(player, funnel, sessionId, stepNumber, ctx?)`, `event(player, name, value, ctx)`, `pearls(player, flow, amount, balance, transactionType, sku)` |
| **WorldIndex** | MVP | Reads tagged volumes and the 12 revive points at start, builds the height field, answers point queries | Volume table, revive point list, height field buffer | `zoneAt(x,y,z): ZoneId`, `isSafe(x,y,z): boolean`, `coveMouthAt(x,y,z): Slot?`, `volumesOf(kind): {Volume}`, `floorY(x,z): number`, `segmentBlocked(a, b): boolean`, `nurseryPathAt(x,y,z): string?` (the `NurseryPath` `PointId`, section 9.1), `revivePoints(): {RevivePoint}` (the 12 points, section 9.1), `sendWorldInfo(player)` (sends `WorldInfo` once; `PlayerLifecycle` calls it after `ClientReady`, before the creature spawns, because WorldIndex cannot listen to `onReady`: `PlayerLifecycle` requires `CreatureService`, which requires WorldIndex) |
| **CreatureService** | MVP | Builds and owns each creature model; species, mass, the tier and body scale derived from mass (section 6.8), status effects, protection (revive, reconnect, newcomer shield) | Root parts; `CreatureState` per slot | `spawn(player)`, `get(slot): CreatureState?`, `addMass(slot, amount)` (the amount may be negative: hook, vent), `setStatus(slot, effect, seconds)`, `protect(slot, reason, seconds)`, `isProtected(slot): boolean` (any protection window open: revive, reconnect, newcomer shield), `teleport(slot, cf)`, `onTierChanged: Signal<Slot, number>` (fires on a rise and on a fall), `remove(slot)` (destroys the creature on leave, called by `PlayerLifecycle` after `onLeaving` so leave settlement can still read the state), `coveSpawnCFrame(slot): CFrame` (where the creature appears: its `CoveInterior` centre facing its `CoveMouth`; the first revive point on a map with no cove for that slot, such as the CI arena) |
| **MovementValidator** | MVP | Checks every creature's motion 20 times a second; keeps pose history for lag compensation | Pose ring per slot, suspicion score | `poseAt(slot, t): (x,y,z, lx,ly,lz)`, `allowedSpeed(slot): number`, `grace(slot, seconds)`, `suspicion(slot): number`, `flag(slot, points, why)` |
| **TraitService** | MVP | Trait progress (five trait prey, four with `pass_keen_nose`), slots, shedding, effects on rules | `traits`, `progress` in `CreatureState`; the `Traits` attribute; `run.traits` and `run.progress` in `State` | `onTraitPreyEaten(slot, traitId)`, `shed(slot, index)`, `has(slot, traitId): boolean`, `speedMult(slot)`, `massMult(slot, source?)` (`prey` by default), `defenceTierBonus(slot)`, `traits(slot)` (the held list, for the bank), `pipsNeeded(slot): number` (5, or 4 with Keen Nose; the tutorial's Glowfry count), `reset(slot)` (a bank's new start and a respawn), `onGained: Signal<Slot, string, number>` |
| **PreyService** | MVP | Spawns, simulates and replicates prey groups; interest management | Group buffers, spatial grid, per-player send state | `tryEat(slot, groupId, member, gen, t): (boolean, PreyDef?)`, `memberPosAt(groupId, member, t)`, `setTide(tideId?)` (respawn delays ÷ the tide's `spawnRateMult`; targets and caps ×2 only for `frenzy`, chapter 02, section 14.4), `spawnEventPrey(tideId)`, `stunNear(x,y,z, r, maxTier, seconds)`, `spawnScripted(slot, spec): number?`, `steerScripted(slot, scriptedId, target?, speed?): boolean`, `scriptedAlive(slot, scriptedId): (number, Vector3?)` (members alive and the leash centre) and `clearScripted(slot)` (one player's scripted prey, section 8.1), event `onScriptedEaten: Signal<Slot, number, string>` (slot, scripted ID, prey ID), event `onWildEaten: Signal<Slot, string>` (slot, prey ID: a wild member eaten, deferred) |
| **PredatorService** | MVP | Predator state machines, telegraphs, strikes; hazard volume checks; wild creatures [L] (section 9.3) | Predator buffers (32 slots) | `list(): {PredatorView}`, `gather(x,y,z)` (Whale Fall), `tryEat(slot, predatorId, t): boolean`, `onGulp: Signal<Slot, string>` |
| **BiteService** | MVP | Validates bite claims on prey, players and edible predators; applies results | Bite sequence and rate state | Remote handler only, plus `onPlayerEaten: Signal<Slot, Slot>` |
| **RunLoopService** | MVP | Run lifecycle: start, bank, gulp, revive, suspend, resume, settle (sections 12.5 and 13.4) | `RunState` per slot | `join(player, slot)` (places a joining player's creature: the Join row of 6.3), `startRun(player)` (named so it does not clash with every service's `start()` lifecycle function, 4.3), `bank(player)`, `gulp(slot, by: string)`, `offerRevive(player)`, `suspendOnLeave(player)`, `resume(player): boolean`, `settleExpired(player)`, `state(slot): RunPhase` |
| **TideService** | MVP | Tide phase from the UTC clock; Call the Tide override [L] | Override queue | `current(): TideState`, `callTide(player): boolean`, `onPhase: Signal<TideState>` |
| **CoveService** | MVP | Cove assignment, specimens, income accrual, income claim (only on the owner's tap, section 13.2), Cove Boost [L], visits and Bubbles [L] | `coveOwner[Slot]` | `open(player, slot)` (called by `PlayerLifecycle` once the profile is loaded and the slot taken: sets `coveOwner[slot]` and brings the pile up to date, 02 §13.3), `close(player)` (called by `PlayerLifecycle` on leave before the profile is released: settles the pile and frees the slot), `ownerOf(slot): Player?`, `claimIncome(player): number`, `buySlot(player): boolean` (the next cove slot for Pearls, chapter 05, section 4.2; a waiting `cove.pendingSpecimen` moves into it, chapter 02, section 11.5; false when all slots are bought or the balance is short), `boost(player)`, `addSpecimen(player, rec): AddResult`, `release(player, specimenId): boolean`, `view(viewer, ownerSlot)`, `leaveBubble(viewer, ownerSlot)` |
| **ShopService** | MVP | Pearl purchases; Robux prompts; `ProcessReceipt`; game pass ownership; the two-minute rule | Pass ownership cache | `buyWithPearls(player, sku): boolean`, `owns(player, passId): boolean`, `canSell(player): boolean` |
| **GoalsService** | MVP | Three daily goals (one Easy, one Medium, one Hard; on an account's first day the fixed set `dg_eat_50`, `dg_tier3`, `dg_bank_snapper`), progress, claim, reroll; login streak [L] (seven boxes; a missed day never resets it) | Goal and streak state in profile | `progress(player, kind, amount)`, `claim(player, index)`, `reroll(player, index, how)`, `openStreakBox(player)` |
| **CodexService** | MVP | Records discoveries: Species, Tiers, Traits, Prey [MVP]; Dangers, Places, Tides [L]. Reef Rank [L] from rank points (section 13.4) | Codex and rank in profile | `discover(player, kind, id, tier?)`, `addRankPoints(player, amount)` |
| **LeaderboardService** | MVP: server board. L: global boards | Biggest creature on this server; weekly biggest banked; most Bubbles | Cached top lists | `serverTop(): {Entry}`, `submitBank(player, mass)`, `globalTop(board): {Entry}` |
| **TutorialService** | MVP | The server half of the first-time script (chapter 04, section 3; module B31): owns and saves `ftue.stage`, `ftue.completed` and `ftue.attempts` (04 §3.1, §9); feeds the pure `Logic/FtueRules` from the game (`TutorialStep`, `onScriptedEaten` and `onWildEaten` (bites only, never a bare mass rise), mass, `onTierChanged`, `onGained` for the first trait only, the `NurseryPath` place) and runs its actions: the player's scripted prey through `PreyService.spawnScripted` and `steerScripted` at `Config/FtueConfig`'s route distances (`Logic/FtuePlan`), the fail-safes, the idle rule and the restart forms; sends the presentation to the owner as `State` `ftue.cue` (section 5.3). Starts a session at `PlayerLifecycle.onReady` for an account with `ftue.completed = false` and no bank, and for a finished account whose saved stage is `S9_COVE` or `S10_RUN2`, which keeps that stage (04 §4: the run 2 assists read it) and replays nothing; any other finished account gets no session and no stage save. Calls `PlayerLifecycle.controlGranted` at the end of the hatch (T = 0). Until the chase exists (task S7-C1) `S6_CHASE` passes straight into `S7_CURRENT` as a skipped chase. Its `onStep(player, step, ctx)` and `onFailsafe(player, kind)` hooks carry the onboarding steps and `ftue_failsafe` to `Analytics` (task S6-C6). Developer reset (04 §9): `Dev/Cheats` runs `/ftue reset` from `DevCommand:Invoke(userId, "/ftue reset")` on `ServerScriptService.Server`, which `Main` creates only where dev cheats are on, and `reset` refuses itself where they are off (Studio's command bar in server mode, the Developer Console's server tab, or MCP `execute_luau` on the server; text chat is off) | One session per player in the script (FtueRules state, its scripted groups) | `stage(player): number?`, `reset(player): (boolean, string?)` (dev only, reason `devCheats` or `noCreature` when refused: clears `ftue`, a new Fry on the Hatch Bed, the script from the hatch, first cue `reset`), `onStep`, `onFailsafe` |
| **EmoteService** | L | Quick emotes (chapter 02, section 17.1): checks the ID, the cooldown (one per 3 s; more than 8 in 30 s locks emotes for 20 s) and the creature's state, then relays to players within 120 studs. No text is ever sent | Cooldown state per slot | Remote handler only |

### 5.2 Client controllers

| Controller | Scope | Responsibility | Owns | Public API |
|---|---|---|---|---|
| **StateStore** | MVP | Mirror of the player's own saved and run state, fed by `State` patches | Local copy | `get(path)`, `observe(path, fn)` |
| **QualityController** | MVP | Device detection and graphics tier, as specified in chapter 15: the screen class (sections 2.2 and 5.2; `GuiService.ViewportDisplaySize` first, recomputed when the viewport changes) and the tier Smooth, Balanced or Pretty (section 6: start sample, step down, memory guard, cut order; the step-up probe and `lastGoodTier` are [L]). Sends `Telemetry` | Screen class, current tier | `screenClass(): ScreenClass`, `tier(): Tier`, `onTierChanged`, `onScreenClassChanged` |
| **InputController** | MVP: drag to swim, mouse and keyboard. L: gamepad, the two-thumb scheme, the left-handed layout | Turns raw input into one `SwimInput`. The input mode (`Touch`, `Keys`, `Pad`) is `UserInputService.PreferredInput`, re-read on every change (chapter 15, sections 2.2 and 5.1); it picks the scheme, the hints and the client-side assist set, and the server never trusts it | Bindings, scheme setting per input mode | `read(): SwimInput`, `mode(): InputMode`, `onModeChanged`, `onDash`, `onAbility`, `setScheme(id)` |
| **MovementController** | MVP | Runs `SwimModel` each frame and drives the own root part; sends `Ability` | Local swim state | `setStatus(effect, seconds)`, `velocity(): Vector3` |
| **CameraController** | MVP | Scriptable follow camera, zoom by tier, death and cove cameras | `workspace.CurrentCamera` | `setMode(mode)`, `shake(amount)` |
| **CreatureController** | MVP | Builds and animates a rig for every streamed-in creature; smoothing; scale; mesh swap; the Leviathan crest; trait visuals; outline shells (section 8.8); nameplates | Rig per creature | `rigOf(slot)`, `localMouth(): (Vector3, number)` |
| **PreyRenderer** | MVP | Decodes `PreyState`, dead-reckons groups, draws members from pools, far groups as particles, detects local bites | Client group buffers, mesh pools | `nearest(kindFilter)`, `setQuality(tier)` |
| **PredatorController** | MVP | Decodes predator packets, drives rigs, shows telegraphs | Predator rigs | none |
| **TideController** | MVP | Countdown and phase visuals from the shared `TideClock`; lighting presets | none | `state(): TideState` |
| **AudioController** | MVP | Music states, pooled one-shots, underwater filter; no default sounds | Sound pool | `play(id, at?)`, `setMusicState(state)` |
| **UIController** | MVP | Hud and screens built in code from `UI/Kit`; all core GUI off | `PlayerGui` tree | `open(screen)`, `close(screen)`, `toast(key, args)` |
| **TutorialDirector** | MVP | First-session script's presentation: the hatch, prompts, HUD first appearances, music layers, the first bank, from `TutorialService`'s `State` `ftue.cue`; reports loading done, taps, steering and going to the background through `TutorialStep` (section 5.3) | Local step pointer (server holds the saved step) | `step(): number` |

### 5.3 Remotes

Created by `Net/Server` from `shared/Net/Remotes.luau`, parented to `ReplicatedStorage.Net`. The payload column says how each one is encoded. **Buffers** (one `buffer` argument, laid out in 8.7 and 8.9): `Bite`, `Ability`, `Telemetry`, `BiteResult`, `PreyEvent`, `PredatorEvent`, `PreyState` and `PredatorState`. **Every other remote carries plain Luau arguments** (numbers, booleans, short strings, or one table where the row says so): `State`, `WorldInfo`, the low-rate `*Action` remotes, `SettingsSet`, `TutorialStep`, `CreatureEvent`, `TideEvent` and `CoveView`. Plain arguments are type-checked and range-checked on arrival like everything else (14.2).

| Remote | Kind | Direction | Payload | Rate limit per player (bucket size) |
|---|---|---|---|---|
| `ClientReady` | Reliable | C→S | none | 1 per session |
| `Bite` | Reliable | C→S | 8 to 40 bytes (8.9) | 12/s (20) |
| `Ability` | Reliable | C→S | 6 bytes: `op` u8 (1 dash, 2 ability press, 3 ability release for held abilities such as Shell), `seq` u8, `timeMs` u32 (the client's estimate of server time when pressed). The client starts its dash at once and reports it with op 1; the server's dash window (7.1) opens only from that message | 4/s (6) |
| `RunAction` | Reliable | C→S | op + up to 2 numbers. Op 1 **Swim again**, no numbers: accepted only while `Phase = dead` and the gulp card is up (chapter 02, section 12.1); the server pays scraps and respawns (6.3). There is no timeout: the card waits for the tap, and leaving settles the run. Other ops are added with the features that need them, each listed here | 5/s (8) |
| `CoveAction` | Reliable | C→S | op + one argument; the client always sends the second argument, 0 when the op has none. Op 1 **claim** the pile (the Pearl clam, chapter 02, section 13.2; SKU `claim_pile`), op 2 **claim from the welcome card** ("While you were away", 02 §13.3; SKU `claim_welcome`), op 3 **buy the next cove slot** (`CoveService.buySlot`), op 4 **release** a specimen, argument the specimen ID string (an old specimen's, or the waiting new one's, 02 §11.5). Any other op or argument type is ignored | 5/s (8) |
| `ShopAction` | Reliable | C→S | op + sku string ≤ 32 chars | 3/s (5) |
| `GoalAction` | Reliable | C→S | op + index | 2/s (4) |
| `SettingsSet` | Reliable | C→S | Plain arguments, not a buffer: key (string from the fixed settings list, ≤ 32 chars) + value (number or boolean) | 2/s (4) |
| `TutorialStep` | Reliable | C→S | Plain argument, not a buffer: one integer (`Logic/FtuePlan.Code`). 2: onboarding step 02, the first frame of the loading screen (chapter 10, section 3.1); 101: the loading screen exits (`LoadDone`, the end of `S0_LOADING`); 102: a tap that is not a drag; 103: a steering input (a drag of 0.2 s or more, a movement key, a stick), sent again at most once a second while it lasts; 104: the app went to the background. Values held before the session exists are kept for it; any other integer from 2 to 104 is ignored. The client keeps to the rate limit | 2/s (4) |
| `EmoteAction` [L] | Reliable | C→S | emote index 1 to 6 | 1 per 3 s (1) |
| `Telemetry` | Unreliable | C→S | 8 bytes: fps bucket, graphics tier, memory bucket, screen class, display size, input mode (the source of `sess_device`, `perf_tier` and `run_end_input`, chapter 10; the server accepts only values from the fixed lists) | 1 per 20 s (2) |
| `State` | Reliable | S→C | path string, value. A path is dot-separated keys, a segment of digits indexing an array (`cove.slots`, `goals.list.2.progress`); at most 128 characters and 8 segments. The first segment is a top-level key of the profile (12.2: `pearls`, `cove`, `goals`, `tokens` …) or `config`, the root of the live config keys forwarded to clients (17.4: `config.flag.tideEvents`). Profile keys sit at the top level next to `config`; there are no other roots, and no profile key may be named `config`. During a run `TraitService` sends `run.traits` (the held list) and `run.progress` (trait ID → pips) itself, at the paths of the profile's `RunSnapshot` (12.2), without writing the profile. `TutorialService` sends `ftue.cue`, never saved: `{ seq, actions }`, one per batch of the first-time script's presentation actions in order (the kinds and fields of `Logic/FtueRules`' header: `reset` (first in the batch after a developer `/ftue reset`: the client drops whatever it is presenting), `hatch`, `giveControl`, `hold`, `prompt`, `hud`, `pulse`, `music`, `openFog`, `openCurtain`, `predatorShadow`, `startChase`, `autoDash`, `startCurrent`, `reformCurrent`, `pull`, `bankSequence`, `coveItem`, `exitTrail`, `feedNearest`), `seq` rising by one per batch for as long as the player is on the server, across tutorial sessions (a reset does not start it again), so the client plays a batch only when its `seq` is above the last one played; `ftue.stage` arrives through `DataService.patch` | n/a |
| `WorldInfo` | Reliable | S→C | volume table, once after `ClientReady`; the decoder rejects more than 1,024 volumes, more than 16 attributes on a volume or a string over 256 characters **(tune)** | n/a |
| `BiteResult` | Reliable | S→C | 9 bytes | n/a |
| `PreyEvent` | Reliable | S→C | 1 + 6n bytes, n ≥ 1: at least 7 bytes | n/a |
| `CreatureEvent` | Reliable | S→C | Plain arguments to every client, the kind first: `"gulped", slot, by` (`by`: `player:<slot>` or a predator ID); `"tier", slot, tier, previousTier`; `"banked", slot, mass, pearls, crystal, deepPockets, best, specimen` (the bank of 13.4: `mass` the banked mass, `pearls` what the bank paid, `crystal` and `deepPockets` whether those multipliers applied, `best` true for a new best mass, `specimen` `added`, `full` (kept as `cove.pendingSpecimen`) or `none` (tier 1, or refused); the owner's client opens the bank summary from it, chapter 08); `"traitGained", slot, traitId, index` (02 §8.2: `index` is the slot it took, 1 to 3; the owner's client plays the slot's Just gained flash and S08 from it, every client grows the body feature in); `"traitShed", slot, traitId, index` (02 §8.3: the slot it left; the feature pops off as bubbles); revived, status, bite absorbed and emote [L] are added with their features, each listed here | n/a |
| `PredatorEvent` | Reliable | S→C | 14 bytes | n/a |
| `TideEvent` | Reliable | S→C | override start and end only | n/a |
| `CoveView` | Reliable | S→C | specimen list of one cove | n/a |
| `PreyState` | Unreliable | S→C | ≤ 900 bytes, 10 Hz | n/a |
| `PredatorState` | Unreliable | S→C | ≤ 400 bytes, 10 Hz | n/a |

Public facts about other players travel as attributes on their `Player` object, which replicate to everyone regardless of streaming: `Slot`, `Species`, `Pattern`, `Tier`, `Mass` (rounded, at most 4 updates a second), `Traits` (comma-joined IDs), `Phase` (`cove`, `run`, `dead`), `Protected` (boolean: true during revive or reconnect protection and while the newcomer shield of section 10.2 is up; clients draw no outline on a protected creature).

## 6. The custom character

### 6.1 What the server builds

The replicated character is deliberately tiny: one invisible ball and two constraints. Everything visible is built by each client.

```text
Creature_<userId>   Model, PrimaryPart = Root, ModelStreamingMode = Atomic
└── Root            Part, Shape = Ball, Transparency = 1, CanCollide = true, CanTouch = false,
    │               CanQuery = true, CastShadow = false, CollisionGroup = "Creature" or "CreatureEel",
    │               CustomPhysicalProperties = (density 1, friction 0, elasticity 0.2)
    ├── RootAttachment   Attachment
    ├── Move             LinearVelocity   Attachment0 = RootAttachment, mode Vector, world space,
    │                                     MaxForce = 1e6 (tune)
    └── Turn             AlignOrientation Attachment0 = RootAttachment, one-attachment mode,
                                          Responsiveness = 40 (tune), MaxTorque = 1e6 (tune)
```

`Root.Size` is a ball of diameter `1.8 × bodyScale × species.radiusMult` studs, twice chapter 02's collision radius (section 0.2): 1.8 studs for a Fry, 11.7 studs for a Leviathan. There is no Humanoid, no `AnimationController` and no mesh on the server.

`LinearVelocity`, `AlignOrientation` and `VectorForce` are the current mover constraints; `BodyVelocity` and `BodyGyro` are deprecated (**V32**).

### 6.2 Assigning it

`Players.CharacterAutoLoads` is `false` (set in the project file and again in `PlayerLifecycle.init`). We never call `LoadCharacterAsync`. Per player, in order:

```lua
local model = CreatureService.build(player)          -- the tree above
model:PivotTo(coveSpawnCFrame)                        -- inside the player's cove
model.Parent = workspace.Creatures
player.Character = model                              -- Character is a read-write Model property (V1)
root:SetNetworkOwner(player)                          -- server-only call (V5)
player.ReplicationFocus = root                        -- server-only; nil would also fall back to PrimaryPart (V3)
```

`CharacterAdded` fires "shortly after Character is set" (**V1**); the client's `CreatureController` listens to it and to `workspace.Creatures.ChildAdded` for other players. That a `Character` model with no Humanoid raises no core-script errors rests on forum sources only (**U1**) and is spike item S1.

### 6.3 Spawning and respawning

The model is built once per session and reused. Destroying and rebuilding it on every death would re-run streaming and ownership for no benefit.

| Event | Server steps | Time budget |
|---|---|---|
| Join | Build, place in the cove, assign, own, `Phase = cove`. One exception: an account that has never banked is placed in the Nursery for its first run (canon 5.5, chapter 04); every later run starts at the cove | Creature controllable within 1.0 s of `ClientReady` (measured in Studio: 0.34–0.91 s from `ClientReady` to the client's `CharacterAdded`, spike F5; re-measured on a real server with the real map, 6.11) |
| Run start | Player swims out of the cove mouth; `RunLoopService.startRun` sets `Phase = run` | Instant |
| Gulped | `Phase = dead`; `SetNetworkOwner(nil)`; anchor. The server then waits for the "Swim again" tap (`RunAction` op 1, 5.3) with no timeout (chapter 02, section 12.1: the gulp card waits for a tap); a player who leaves first is settled at leave (scraps paid). On the tap: pay scraps; move to cove spawn; reset size to tier 1 (or tier 2 for `shark`); wait for the client's respawn fade (0.3 s out, 0.3 s in, chapter 02, section 12.4); unanchor; `SetNetworkOwner(player)`; `Phase = cove`; `MovementValidator.grace(slot, 2)` | Counted from the tap, not the gulp: control again within 0.8 s of the tap (02 §12.4), budget 2.0 s, canon limit 3 s |
| Revive | Same as gulped but placed by the return rule below (the gulp position, or a revive point), traits kept, mass × 0.7 (the tier is derived again from the new mass), `Protected = true` for 3 s | 1.0 s |
| Resume a suspended run (12.5): after Continue on the card, or at once with no card for an account that has never banked | Place by the return rule below (the stored position, or a revive point); restore mass, traits and progress; `Phase = run`; `Protected = true` for 3 s | 1.0 s |
| Bank | No teleport; the player is already in the cove | Instant |

**Return rule for a revive or a resume** (chapter 02, sections 12.3 and 16.5; chapter 03, section 6.11 owns the points). `RunLoopService` first tests the place the creature was: the gulp position for a revive, the stored `run.x, y, z` for a resume. That place is used if nothing that can eat the creature at its new mass (a player, a wild creature [L] or a predator, by `BiteRules`) is within 60 studs. Otherwise the server takes the 12 revive points `rp_01` to `rp_12` from `WorldIndex.revivePoints()` in order of distance and uses the nearest one that passes the same 60-stud test. If none passes, the nearest point is used anyway; the 3 s of protection covers the arrival. `CreatureService.teleport` moves the creature and `MovementValidator.grace(slot, 2)` follows.

**Revive offer (canon 5.5).** `RunLoopService.offerRevive` makes the offer only when all of these hold: the run has not used its one revive (`reviveUsed`), the lost creature had 30 mass or more, and this is not the account's first death (`newcomer.firstDeath` is already true). The offer has no countdown: the server keeps the dead creature's `RunState` until the player picks Revive, Trait Lock or Continue on the gulped screen, or leaves (which counts as declining). While an offer is open the creature stays anchored at the cove spawn with `Phase = dead`, and the 3-second respawn limit runs from the choice. Reviving is `prod_revive` or, where eligible, `ad_revive` [L].

### 6.4 Network ownership

The player's client owns `Root`. That gives zero-latency control, and the engine replicates the part to the server and on to other clients. Roblox states that it cannot verify physics on client-owned parts (**V5**), which is why section 7 exists. `Workspace.AuthorityMode` stays `Automatic`; Server Authority is evaluated in spike item S12 and is not used at MVP (section 20, R2). Under `AuthorityMode = Server` the spike found that `SetNetworkOwner` throws, string attributes are capped at 50 characters, and scripts cannot read the mode (F24). If Server Authority is ever adopted, every `SetNetworkOwner` call in this chapter is replaced and every long-string attribute is reviewed first, starting with `Traits` (comma-joined IDs, section 5.3).

The server takes ownership back (`SetNetworkOwner(nil)`) only while the creature is dead or being hard-corrected. Anchored parts are always server-owned (**V5**), so anchoring is the freeze switch.

### 6.5 Physics setup

- **Underwater (root Y ≤ 0):** `MovementController` writes `Move.VectorVelocity` and `Turn.CFrame` every frame from `SwimModel.step`. `MaxForce` is high enough that gravity is irrelevant. The sea is **not** Terrain water: it is empty space dressed with fog, colour and a surface mesh, so the engine applies no buoyancy we would have to fight.
- **Above the surface (root Y > 0):** `Move.Enabled = false`; the creature follows a ballistic arc under `Workspace.Gravity` and re-enters. This is the breach. The project files set `Workspace.Gravity = 80`, chapter 02's air gravity (02 §1.7; the engine default is 196.2, **V29**). One global value is enough: under water `MaxForce` overrides gravity whatever its value, nothing else in the game falls (prey and predators are moved by code), and `SwimModel`'s own air step uses the same 80 (`Config/Defaults`, `swim.gravity`), so the client's prediction and the engine's arc agree. No custom downward force is needed. Concretely, when `SwimModel` reports `Airborne`, `MovementController` sets `root.AssemblyLinearVelocity` to the model's velocity, sets `Move.Enabled = false` and keeps `Turn` (turn rate ×0.3, 02 §1.7); the engine then flies the arc. Each frame in the air it copies the root's position and velocity back into the model's state, so `SwimModel`'s air step only predicts between frames. When the centre is below `Y = 0` again it scales the velocity by 0.8 into the model and sets `Move.Enabled = true`.
- `Workspace.FallenPartsDestroyHeight` is set to `-5000`; the map reaches 600 studs below the surface and the engine default would delete creatures in the Drop-off.
- World origin is the centre of the map on the surface: X and Z from −1,024 to +1,024, Y from −600 to +96.
- `PhysicsSteppingMethod = Adaptive` (**V32**).

Collision groups, registered once in `World/CollisionGroups.luau` with `PhysicsService:RegisterCollisionGroup` and `CollisionGroupSetCollidable` (limit 32 groups, **V24**):

| Group | Members | Collides with |
|---|---|---|
| `World` | `Workspace.Collision` shell | `Creature`, `CreatureEel` |
| `Creature` | Roots of every species but `eel` | `World`, `Creature`, `CreatureEel`, `EelGate` |
| `CreatureEel` | `eel` roots | `World`, `Creature`, `CreatureEel` |
| `EelGate` | Blockers across eel holes | `Creature` only |
| `Visual` | All client-made rigs, prey meshes, set dressing | nothing |

Same-tier players bump because `Creature` collides with `Creature`. Bites never depend on a collision event; they are distance checks.

### 6.6 Streaming and ReplicationFocus

Streaming properties cannot be set from scripts (**V4**), and the spike found that scripts cannot read them either (F6). They live in the Rojo project file (`world.project.json`), never set by hand in Studio, and are listed in section 15.4. Decisions:

- The **collision shell is Persistent**, so the owner's physics always has walls to hit even when the visible reef around it has not streamed in. The shell is at most 150 simple parts **(tune)**; Roblox warns that Persistent models are for rare cases (**V4**), and this is one.
- **Creature models are Atomic** (one part each) and stream by distance. A player more than `StreamingTargetRadius` away has no model on this client; the leaderboard and cove signs use `Player` attributes instead.
- Everything the client creates itself (rigs, prey, effects) is exempt from streaming out (**V4**).
- `ReplicationFocus` is the root while alive and the cove anchor part while dead.
- **The client waits for `workspace.PersistentLoaded`** before it touches any Persistent model (the collision shell). Persistent models are absent when `StarterPlayerScripts` start, even when `game:IsLoaded()` is true; the event fired 3 to 341 ms later in the spike (F4). `first/Loading` keeps the loading screen up until it has fired. It runs first, so it is the script that listens; it requires nothing from `ReplicatedStorage`, which has not arrived when it starts. When the minimum set of chapter 04, section 2.3 is in, or the slow-load rule of 04 §2.4 starts anyway, it sets the attribute `LoadMode` (`full`, `partial` or `minimal`) on itself, and `Client/Main` sends `ClientReady` on it. When the creature has arrived too it sets `LoadDone` and plays its 0.4 s exit; the tutorial starts the hatch from `LoadDone` and skips the hatch animation when `LoadMode` is `minimal`.
- **`PauseOutsideLoadedArea` is harmless with our root.** It freezes a non-Humanoid root without anchoring it; in the spike it fired once, 0.7 s after joining, for 56 to 69 ms (F7). Nothing reacts to it except this: while `Player.GameplayPaused` is true, client code and `MovementValidator` ignore the root's velocity (the validator's grace in 7.4 already covers the pose).

### 6.7 Smoothing other players

Each client builds a rig for every creature model that streams in. The rig is never welded to the root. Every `PreRender`:

```text
target      = root.CFrame (own creature: the simulated value; others: the engine's replicated value)
velocity    = root.AssemblyLinearVelocity, clamped to 1.2 × the creature's dash speed (tune)
lead        = target.Position + velocity × 2τ                     -- velocity lead
rig.pos     = critically damped spring toward lead               (τ = 0.08 s others, 0.03 s own) (tune)
rig.heading = spring toward look direction                       (τ = 0.10 s) (tune)
              look direction = velocity if speed > 2 studs/s, else root look vector
rig:PivotTo(CFrame.lookAlong(rig.pos, rig.heading) * bankAndPitchFromTurnRate)
```

**Why the lead.** A critically damped spring toward a target moving at speed v settles 2τv behind it. In the spike (S3, F1) that was 6.1 to 6.4 studs behind the replicated root at 38 studs/s and 12.5 to 13 studs in a dash, at τ = 0.08 s: no pops, but a rig visibly behind the ball the server judges bites from. Springing toward `root + velocity × 2τ` cancels the trail, so the rig sits on the root at steady speed and still smooths its corrections. The clamp stops a replication overshoot from throwing the lead point. In code the spring takes one exact step per frame toward a target sampled at the frame's end, which has already moved `velocity × dt`, so the per-frame lead is `velocity × (2τ − dt/2)`; `shared/Logic/RigMath` does this, and `CameraController`'s fallback spring (used when the own creature has no rig) uses the same lead; a lead of a full 2τ per step leaves the camera half a frame ahead of the rig. `tests/unit` checks the spring against a constant-velocity target: within 0.5 studs of it after 0.5 s **(tune)**.

The engine already interpolates replicated assemblies; the spring hides its corrections and lets us add banking, squash and stretch without touching replicated state. Pass criteria are in S3.

**Visuals read the rig, never the root (F2).** The replicated root of a client-owned creature pops 7.3 to 10.4 studs in one frame at dash onset, at every lag including 0 ms (S3). So every client visual that follows a creature reads the smoothed `rig.pos`, never raw `root.Position`: nameplates, outline shells, bite reach and mouth indicators, threat arrows, UI anchors and the camera's follow point. Server rules do not change: `MovementValidator`, `BiteService` and lag compensation keep reading the replicated root.

### 6.8 Scale with mass, steps with tier

Tier and body scale are both pure functions of mass in `shared/Logic/TierMath.luau` (canon 5.1; chapter 02, section 0.2 owns the formula):

```text
tier(mass)      = the highest tier whose massNeeded ≤ mass          -- can fall when mass is lost
bodyScale(mass) = scaleAt[t] + (scaleAt[t+1] − scaleAt[t]) × (mass − need[t]) / (need[t+1] − need[t])   tiers 1 to 6
bodyScale(mass) = 6.5                                                                                   tier 7, whatever the mass
```

- **Scale is smooth, speed is stepped.** Every accepted bite changes `bodyScale` a little, and the server uses the new value at once for mouth reach and body radius in bite checks (8.9, 10.3). Swim speed and turn rate come from `Tiers[tier]` and change only at a tier step.
- `Root.Size` follows `bodyScale` but is written only when it differs from the last written value by more than 3% **(tune)**, and at every tier change, so the collision ball does not replicate on every bite.
- A tier change in either direction (growth, or mass lost to a hook, a vent or a revive) sets the `Tier` attribute, fires `CreatureService.onTierChanged` and calls `MovementValidator.grace(slot, 0.5)`.
- Clients compute the same `bodyScale` from the replicated `Mass` and ease the rig to it with `Model:ScaleTo(scale)` (**V27**) over 0.15 s. Size never jumps at a tier-up; the tier-up adds a squash-and-stretch pop and `FX_TierUp_T<n>` on top.
- At tier 7 the client attaches the species' Leviathan crest to the rig, and removes it if the tier falls.

### 6.9 Juvenile to adult mesh swap

Each species is one rig Model containing one skeleton and two skinned MeshParts, `Juvenile` and `Adult` (canon section 7). Those are the instance names inside the rig; the meshes they hold are chapter 07's `M_Species_<Species>_Juv` and `M_Species_<Species>_Adult`. Both are loaded; only one is visible. At tier 4 the client plays `FX_Metamorph` (with `FX_TierUp_T4`), and while the bubble cloud covers the body flips the two `Transparency` values in the same frame. If the tier falls below 4 the same swap runs in reverse. Animations keep playing because the skeleton does not change. Two MeshParts sharing one skeleton is spike item S8 (**U18**); the fallback is two separate rigs swapped at the same moment with the animation time copied across.

Animations play through an `Animator` under an `AnimationController` in the client rig. Because rigs are client-made and each client animates what it sees from replicated state (speed, turn rate, dash, bite events), no animation is replicated.

### 6.10 Default behaviour we lose and what replaces it

| Default (Humanoid) behaviour | Replacement | Owner |
|---|---|---|
| Avatar loading and appearance | Never loaded. `CharacterAutoLoads = false` | PlayerLifecycle |
| Control scripts, touch thumbstick, jump button | `InputController` reads `UserInputService` directly. A stub `PlayerModule` in `StarterPlayerScripts` stops the default one from loading (**U1**, S9) | InputController |
| Camera follow, zoom, occlusion | `CameraType = Scriptable` gives full control (**V32**); `CameraController` sets `CFrame` and `Focus` every frame; occlusion by one sphere-cast (radius 1.0, chapter 02, section 3.5) from the look-at point to the desired camera position against `workspace.Collision`, the World shell; a ray in the `World` group would miss it, because that group does not collide with itself | CameraController |
| Health and health bar | No health. A creature is alive, protected or gulped. Plated's single save is a flag in `CreatureState` | CreatureService |
| Death and respawn (`Humanoid.Died`, `RespawnTime`) | `RunLoopService.gulp` and the table in 6.3 | RunLoopService |
| Swimming, buoyancy | `SwimModel` plus mover constraints | MovementController |
| Name and health display over the head | A pooled `BillboardGui` per visible creature: name, tier pips, eat or flee colour | CreatureController |
| Chat window | Text chat is off in the MVP: `StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)` (**V14**). Whether to turn it on is reviewed for launch (canon 14); nothing in this design depends on it. If the review says yes, it is a panel on `TextChatService` behind `flag.textChat`, never shown on a TV (chapter 15). Either way the Rojo project file sets `TextChatService.ChatVersion = TextChatService` (15.4): a Rojo-built place otherwise defaults to legacy chat, and scripts cannot write the property (spike F3) | UIController |
| Chat bubbles | Off in the MVP. Part of the same launch review: `TextChatService:DisplayBubble(root, text)` draws on our ball root (S16 passed on Mac, **U6**), but only with `ChatVersion = TextChatService`; under legacy chat it fails silently, with no error (F3) | UIController |
| Voice chat | Off. `VoiceChatService.EnableDefaultVoice = false` (**V31**) | Place setting |
| Player list, backpack, emotes, health GUI | All core GUI off; our own leaderboard; our own six quick emotes [L] through `EmoteService` | UIController |
| ProximityPrompts | Not used. World prompts are our own Hud elements driven by volumes | UIController |
| Default loading screen | `ReplicatedFirst:RemoveDefaultLoadingScreen()` after our screen is up (**V32**) | `first/Loading` |
| `StarterGui` copying into `PlayerGui` on spawn | Not used. All UI is created in code by a script in `StarterPlayerScripts`, so it does not depend on a character spawning | UIController |
| Fall damage, seats, tools, climbing | Not used | — |
| Idle kick (20 minutes, **V1**) | Kept; nothing to replace | — |

### 6.11 First-week spike

One throwaway place, one week. Each item is pass or fail. A fail triggers the fallback in section 20 before any production module is built on the assumption.

| ID | Prove | Pass when |
|---|---|---|
| S1 | A `Model` with no Humanoid can be `Player.Character` | 10 joins in a row on Mac and phone: `CharacterAdded` fires on server and client, no errors in either console |
| S2 | Swim feel on a phone | Drag-to-swim with `LinearVelocity` and `AlignOrientation`: input to motion in the same frame, 60 fps on a mid phone, 30 fps on a low-end phone, with all seven tier scales |
| S3 | Other players look smooth | Two clients, Studio network simulation at 100 ms and 200 ms: with rig smoothing no visible pop larger than 2 studs at 38 studs/s, and none larger than 4 studs during a dash |
| S4 | Server correction works | Server sets `root.CFrame` on a client-owned root and the owner's creature moves there within 0.3 s; `SetNetworkOwner(nil)` plus anchor freezes it regardless of the client (**U3**) |
| S5 | Streaming | Persistent collision shell present before the creature can move; `PauseOutsideLoadedArea` either behaves or is harmless with a non-Humanoid character; `Player.GameplayPaused` reaches the server (**U18**) |
| S6 | Prey pipeline | 250 groups and 1,300 members: the simulation (8.4, steps 1 to 5) ≤ 2.0 ms per 100 ms tick; interest and send, timed separately, ≤ 0.25 ms per player per tick (15.2); ≤ 6 kB/s per player with 24 bots; a low-end phone draws 80 pooled prey at 30 fps with `BulkMoveTo` |
| S7 | Buffers over remotes | A 900-byte `buffer` arrives intact through `UnreliableRemoteEvent`; measured loss under 5% on Wi-Fi; measured bytes on the wire recorded (**U2**) |
| S8 | Skinned rigs without a Humanoid | `AnimationController` + `Animator` plays on a client-made rig; two MeshParts share one skeleton; 24 rigs on screen at 30 fps on a low-end phone |
| S9 | Camera and controls | Scriptable camera; no default touch controls appear; drag to swim, mouse and keyboard all drive the same `SwimInput` (gamepad is [L] and is not part of the pass criteria) |
| S10 | Core GUI | With everything disabled, list what is still drawn (expected: the Roblox menu button only, **U19**) and lay out the Hud around it |
| S11 | One module, three runtimes | A `src/shared` module with relative string requires loads in Roblox, in Lune and type-checks strict in luau-lsp (**U10**) |
| S12 | Server Authority (one day, time-boxed) | With `AuthorityMode = Server`, a non-Humanoid root driven by `SwimModel` inside `RunService:BindToSimulation` is predicted on the owner with no visible rollback at 100 ms, and server step time for 24 bots stays under 4 ms. Pass opens the fallback in R2; fail closes it. The design does not depend on either result (canon 14) (**U4**) |
| S13 | Saves | ProfileStore session start, autosave and end work in Studio with API access on; a second session on the same key is refused |
| S14 | Clocks | `Workspace:GetServerTimeNow()` on client and server and `os.time()` on the server agree within 0.25 s after 10 s in game |
| S15 | Agent loop | Through MCP an agent starts play, runs Luau on server and on client, reads the console, captures a screenshot and stops, three times in a row with no human click. Record whether MCP can start a two-client test (**U13**) |
| S16 | Bubbles | `TextChatService:DisplayBubble` on a plain Part shows a bubble (an input to the launch chat review) |
| S17 | Headless engine tests | `rojo build ci.project.json`, publish through Open Cloud, run one spec through Luau execution, read the result; record the real concurrency limit (**U9**) |
| S18 | Scaling | `Model:ScaleTo` from 1.0 to 6.5 on an animated skinned rig shows no joint or animation errors |

Sprint 0 ran the spike on the Mac; its results and findings (F1 to F27) are in `docs/spike-report.md`, and the rules they changed are written into the sections they touch. Studio on one Mac cannot settle everything, so these are measured again before the soft launch, with the method of 16.4:

| Re-measure | Where | Spike value | Pass when |
|---|---|---|---|
| Join to control (6.3, F5) | A real server with the real world place | 0.34–0.91 s in Studio, small spike place | Creature controllable within 1.0 s of `ClientReady` on a mid phone |
| Server correction (S4, 7.3, F9) | A real phone on a real network | 0.212–0.272 s at 200 ms simulated lag: about 30 ms margin | The owner's creature reaches a server-set pose within 0.3 s |
| Phone frame rates (S2, S6, S8) | Device rows 1 and 3 of chapter 15 | Not run: Mac only, vsync-capped at 60 fps (F12) | The S2, S6 and S8 phone criteria above |

## 7. Movement validation

`MovementValidator` runs at 20 Hz. It reads each root's replicated `Position` and look vector, never anything the client sends in a remote. Per slot it keeps a ring of 32 pose samples (1.6 s): time, position, look vector, allowed speed at that moment.

### 7.1 Allowed speed

```text
vSwim    = Tiers[tier].swimSpeed × species.speedMult × TraitService.speedMult(slot)   -- Stripes ×1.08
         × statusMult        -- statuses slow 0.5 (anemone), puff 0.4, shell 0, stun 0, rampage 1.25
         × dashFactor        -- species.dashMult (2.2; Sea Turtle 2.0, Squid 2.6) from (dashStart − 0.10 s)
                             -- to (dashStart + dashDuration + 0.25 s), then the dash tail below; else 1
vCurrent = 0.6 × Tiers[tier].swimSpeed while WorldIndex says the pose is inside a Current volume, else 0
vForward = vSwim + vCurrent              -- the most an honest creature moves along its look vector
vAllowed = vSwim × slideMult + vCurrent  -- the most it moves in any direction
slideMult = 1.17                         -- √(1 + 0.6²): full forward speed plus a full strafe (02 §1.3) (tune)
```

A current adds `0.6 × tierSpeed` along the stream after everything else (02 §1.2); it is added here, not multiplied, so a slow species or a dash is not over- or under-credited.

**Dash tail.** After the dash window closes, `dashFactor = 1 + (species.dashMult − 1) × e^(−accel × species.accelMult × t)`, with `t` the seconds since the window closed and `accel` the tier's value from 02 §1.3. This is the relaxation `SwimModel` itself uses, so the validator expects exactly the slow-down an honest creature has. It matters at high tiers: a tier-7 creature (accel 4/s) needs about 0.6 s to fall back within 10% of its top speed after a dash (ln 12 / 4 = 0.62 s), longer than the 0.25 s that closes the window; a tier-1 creature needs 0.28 s. The tail's clock `t` stops while the creature is `Airborne` and runs again from re-entry: there is no drag in the air, so an honest dash into a breach keeps its speed through the arc (measured 1.86 × `vAllowed` in the air and 1.51 × just after re-entry with a running clock; 0.945 × with the clock paused, task S2-C1 follow-up, 14 October 2026). While `Airborne`, the speed check of section 7.2 also allows the vertical speed gravity adds, `80 × (seconds in the air)` studs/s (02 §1.7) **(tune)**.

**Why the slide term.** 02 §1.3 relaxes forward and lateral speed separately, so a creature that strafes at full speed moves at √(1 + 0.6²) = 1.166 × its top speed, and one that turns hard in a dash slides past its forward target for a moment. `SwimModel` measured both on 14 October 2026 (task S2-C1, `movement_fuzz.sim`): the worst honest speed was **1.072 × dash speed** in turns and strafes during dashes, and the worst honest 1 s displacement away from dashes **0.925 × top speed** for the Minnow, **1.051 ×** across all six species (re-measured the same day once `movement_fuzz.sim` ran every species). `slideMult` covers the strafe in any direction; the forward check of 7.2 still holds a creature that is simply faster than it should be to `vForward`.

A dash window opens only when the server accepts an `Ability` message: cooldown elapsed (2.5 s, `minnow` 2.0 s, checked with 0.15 s slack), not stunned, alive. An exploiter who never sends `Ability` gets no window; one who sends it early is refused.

The status `rampage` is the Shark Pup's passive ability (canon 7): `BiteService` sets it for 5 s when a `shark` eats 3 prey within 4 s, with no message from the client. The ID `frenzy` means only the Feeding Frenzy tide event and is never a status.

### 7.2 Checks each tick

| Check | Rule | Starting tolerance (tune) | On failure |
|---|---|---|---|
| Speed (windowed) | Over the last 1.0 s: the distance travelled ≤ Σ(`vAllowed` × dt) × 1.10 + 6 studs + `min(ping, 0.3 s)` × `vAllowed`, **and** the part of it along the sampled look vectors ≤ Σ(`vForward` × dt) × 1.10 + 6 studs + `min(ping, 0.3 s)` × `vForward` (7.1) | 10% + 6 studs + ping slack | Rubber-band, +2 suspicion |
| Teleport | One-sample displacement ≤ `max(30 studs, 4 × vAllowed × dt)` unless explained by a stall (7.4) | 30 studs | Rubber-band, +5 |
| Acceleration | Speed change over 0.1 s ≤ 2 × `vAllowed` + 10 studs/s | Soft | +1 only, no correction |
| World bounds | \|x\|, \|z\| ≤ 1,032; −608 ≤ y ≤ 40 | 8 studs | Rubber-band, +2 |
| Zone bounds | Not inside a closed volume: an `EelHole` unless species is `eel`; `SafeNursery` at tier 3 or higher (canon 5.2); another player's `CoveMouth` or `CoveInterior` unless the creature is a tier 1 Fry (a visit [L], canon 6); the Trench gate unless a tide opens it [P2] | 2 studs inside | Rubber-band, +3. The Nursery and cove limits are honest mistakes far more often than cheats: the client also shows a soft push-back, and the server adds suspicion only from the third failure in 10 s |
| Inside solid | `workspace:Raycast` from the last accepted position to the new one against the `World` group hits nothing (**V25**) | Hit ignored in the last 2% of the segment | Rubber-band to last accepted, +5 |
| Stun and shell | While stunned or shelled, displacement ≤ coasting distance (`v0 × 0.5 s`) | 4 studs | Rubber-band, +2 |

The last accepted position is always in open water, so one ray per tick per player (480 rays a second for 24 players) proves by induction that the creature never crossed a wall. Terrain is not used; "inside terrain" means inside the collision shell.

### 7.3 Response ladder

| Level | Trigger | What the server does | What the player sees |
|---|---|---|---|
| 0. Accept | All checks pass | Store pose as accepted | Nothing |
| 1. Correct | A hard check fails, suspicion < 10 | Set `root.CFrame` to the last accepted pose; the owner's creature is there within 0.3 s (S4; measured in Studio: 0.212–0.272 s at 200 ms lag, about 30 ms margin, F9; re-measured on a real phone and network, 6.11); expect the next poses within 15 studs of it for 1 s. On the client, `MovementController` treats a root more than 8 studs **(tune)** from where `SwimModel` put it on the last frame as a server correction: it moves the model to the root's pose and clears its velocity | A small snap back |
| 2. Rubber-band (hard) | The level 1 correction is ignored, or suspicion ≥ 10 | `SetNetworkOwner(nil)`, anchor at the last accepted pose for 0.5 s, unanchor, return ownership, grace 0.5 s | A half-second freeze |
| 3. Flag | Suspicion ≥ 25 | Log `guard_flag` (chapter 10; ctx is the rule ID, `speed` for movement checks) with the reasons in the server log; reject bites for 10 s; mark the run `untrusted` (it banks Pearls but is excluded from leaderboards and yields no specimen above tier 4) | Bites fail briefly |
| 4. Kick | Suspicion ≥ 50 in one session, or 3 flags | Discard the run, log `guard_action` with ctx `kick`, `player:Kick("Connection problem. Please rejoin.")`, increment `moderation.kicks` in the profile | Disconnect |

Suspicion decays by 1 point every 10 s. There is no automatic ban at MVP; `Players:BanAsync` exists (**V2**) and is used manually after reviewing `guard_flag` events. Levels 1 and 2 log `guard_action` with ctx `rollback`.

### 7.4 Being fair to laggy phones

- **Windowed speed, not per-sample speed.** A phone that stalls for 200 ms and then delivers its updates in a burst shows a huge speed for one sample and a normal distance over one second. Only the one-second distance is checked.
- **Stall catch-up.** If no pose change arrives for more than 0.4 s and then a jump arrives, the allowed distance for that jump is `vAllowed × stallTime`, capped at 2.0 s of travel. Longer gaps are corrected at level 1 with no suspicion.
- **Ping slack.** `Player:GetNetworkPing()` returns the round trip in seconds (**V1**); an average over 5 s widens the speed window and the dash window.
- **Grace periods.** 2 s after spawn, respawn, revive or a server teleport; 0.5 s after a tier-up or a hard correction; for as long as `Player.GameplayPaused` is true, when the root's velocity is also ignored (6.6, F7).
- **Corrections cost nothing by themselves.** Only points do, and points decay. A player on a bad connection sees an occasional snap back, never a kick: honest play cannot reach 50 points because one violation per 10 s nets zero.
- **Tolerances are live config** (`tune.move.*`, section 17.4) so they can be widened without a release if `guard_flag` shows false positives. Target: fewer than 0.5% of sessions reach level 2.

## 8. Prey simulation

### 8.1 The unit is the group

A solo fish is a group of one. A krill swarm is one group of 12 to 20 members. Plankton is a patch of 6 to 10 motes. The server simulates and replicates **group** state only; each member's position is a pure function of group state:

```text
memberPos(i) = groupPos + rotateY(heading) × Formation.offset(kind, seed, i) × (1 + scatter × scatterGain[kind])
heading      = atan2 of the group velocity (kept from the last non-zero velocity)
```

`Formation.offset` is a hash of `(kind, seed, i)` in `shared/Sim/Formation.luau`, so server and client compute identical offsets. The client adds a cosmetic wobble of at most `wobble[kind]` studs (≤ 1.5), which the bite tolerance covers.

Population. Chapter 02 owns the live targets (section 9.6, data:PreyTargets) and chapter 03 the group sizes (section 2.1) and the live cap per zone (section 2.3); this chapter only sizes the code to them. The load below is 02's targets on the whole map with 24 players and the Nursery at its caps (generated `PreySpawns`, `Logic/PreySpawnMath`), members at the mean group size:

| Prey | Groups | Members per group | Members |
|---|---|---|---|
| `plankton` | 94 | 6 to 10 | 752 |
| `krill` | 13 | 12 to 20 | 208 |
| `shrimp` | 65 | 1 to 3 | 130 |
| `sardine` | 11 | 8 to 14 | 121 |
| `darter` | 30 | 1 to 2 | 45 |
| `mackerel` | 26 | 1 to 3 | 52 |
| `bonito` | 5 | 3 to 5 | 20 |
| `tuna` | 3 | 1 | 3 |
| Trait prey ([MVP] rows of 02 §9.6; a roaming `crystal_jelly` drift adds one group of 5) | 52 | 1 to 5 | 56 |
| **Total** | **299** | | **≈ 1,390** |

Limits: `MAX_GROUPS = 640` **(tune)**, `MAX_MEMBERS = 24` per group. A Feeding Frenzy triples the respawn rate (normal prey respawn delays are divided by the tide's `spawnRateMult`, 3, and the spawner makes three spawns per row per pass instead of one) and raises the live target of normal prey to 2 times normal (chapter 02, section 14.4; chapter 03, section 2.3 doubles the zone caps); trait prey are unchanged. Only the `frenzy` tide doubles targets and caps; a spawn rate above 1 on its own does not (chapter 02, section 14.4). That is the **Frenzy count**: about 2,710 members in 545 groups (493 of normal prey, 52 of trait prey), inside the limit with room for event prey. The Frenzy spawns no event prey, and tides never overlap (canon section 10), so the worst case the soak checks adds Moon Tide's `lunar_fry` at once (12 animals in 3 groups of 4, chapter 03, section 3.1) to the Frenzy count: 548 groups and about 2,720 members, still inside `MAX_GROUPS`. This is a conservative bound, not a state the game can reach: a Frenzy and a Moon Tide never run at once. Every budget in this section must hold at that count, trait prey included, and `prey_soak.sim` proves it (16.2). `MAX_GROUPS` was 512 until task S3-D1 found that 02's targets exceed it in a Frenzy (chapter 14, section 4, entry 29).

**Scripted prey.** Chapter 04's first-run prey (section 3.5: Swarm A, the plankton trail, Swarm B, the Glowfry) belongs to one player (04 §12, C8). `PreyService.spawnScripted(slot, spec)` makes it as ordinary groups that are **owned** by that slot: a ball (a member count around a centre, its spread as the leash) or one group of one at each given point (the trail's motes, every 4 studs, since a group's members can only sit where `Formation.offset` puts them). Each owned group gets a home of its own around its spawn point, so it needs no `PreySpawn` volume, moves and flees as its `PreyDef` says inside that leash, and reacts only to its owner's creature; a `calm` spec reacts to nothing, so it never flees or scatters (chapter 04, section 4: the FTUE krill). `steerScripted` slides a group's leash centre toward a target at a given speed, one step per tick, and its members follow inside the leash: the tutorial points it at the player, 6 studs/s inside 25 studs (chapter 04, sections 3.6 B2 and B3, and 4), except Swarm A, which stays still through the first bite until the T = 2.5 assist or the player swims away (B2; 14 §4 row 34). Spark's `stunNear` skips owned groups (its signature names no slot, and scripted prey moves as its script says). Owned groups are in no spawn row: no target, cap, cull or `areaScale` counts them. Only the owner's interest set and packets carry them, only the owner gets their `PreyEvent`s, and to every other slot they are gone: `peek` returns nothing and `tryEat` refuses. `onScriptedEaten` fires deferred, after the bite claim. Scripted prey belongs to the creature it was spawned for: `spawnScripted` refuses a slot with no creature, and the prey goes when the slot's player or creature changes or goes. A gap with no creature ends it too, because the scripted intro offers no revive (chapter 02, section 12.3), nothing can eat a newcomer in run 1 (chapter 04, section 4), and a resumed run replays the script from its last completed beat (chapter 04, section 9). They take group slots from the same 640, so they have their own budget **(tune)**: at most 92 owned groups on the server (640 less the 548 of the worst case above, so normal prey always have their slots) and 20 per slot (one newcomer's whole route is 17: 1 + 10 + 1 + 5); at most 456 owned members on the server (92 groups at the worst case's mean of about 4.96 members, so all 640 groups hold about 3,180 members, not 2,208 more) and 65 per slot (the route's 35 members, 6 + 10 + 14 + 5, plus B4's `grow_burst` of 10 krill and a `home_lure` krill swarm of up to 20); a spec that does not fit whole is refused. `prey_soak.sim` runs four newcomers on the route through the Frenzy to prove the slot and byte budgets with them.

### 8.2 Server data layout

Struct of arrays, one `buffer` per field, indexed by group ID (0 to 639). Total about 88 kB (137 bytes per group × 640).

```lua
--!strict
--!native
export type PreyBuffers = {
	kind: buffer,        -- u8   0 = free slot; prey: PreyDef.wire (1..127); trait prey: 128 + wire (3.2)
	gen: buffer,         -- u8   generation, +1 each time the slot is reused; wraps 254 → 0
	flags: buffer,       -- u8   bit0 fleeing, bit1 stunned, bit2 lured, bit3 dormant, bit4 event prey
	count: buffer,       -- u8   members at spawn (1..24)
	alive: buffer,       -- u32  bit i set = member i alive
	seed: buffer,        -- u16  formation and wander seed
	home: buffer,        -- u16  index of the PreySpawn volume
	posX: buffer, posY: buffer, posZ: buffer,   -- f32
	velX: buffer, velY: buffer, velZ: buffer,   -- f32
	scatter: buffer,     -- f32  0..1
	stateUntil: buffer,  -- f32  end of flee or stun, seconds since ServerEpoch
	wanderX: buffer, wanderY: buffer, wanderZ: buffer,  -- f32 current wander target
	wanderUntil: buffer, -- f32
	respawnAt: buffer,   -- f32  for a free slot reserved by a spawn volume
	cell: buffer,        -- u16  grid cell index, 0xFFFF = none
	nextInCell: buffer, prevInCell: buffer,     -- u16 intrusive list
	histPos: buffer,     -- 8 samples × (u16 x, u16 y, u16 z, u8 scatter, u8 pad) per group = 64 B
	histHead: buffer,    -- u8
	owner: buffer,       -- u8   0 = shared, else the one slot that owns the group (scripted prey, 8.1)
	calm: buffer,        -- u8   1 = an owned group that reacts to no threat (scripted prey, 8.1)
}
```

Per player (slot) the service keeps what that client was last told, for dead reckoning: `known` (u8 per group: 0 or `gen + 1`, which is why `gen` wraps at 254 and never reaches 255), `sentPos` (3 × u16), `sentVel` (3 × i8), `sentTick` (u16), `sentAlive` (u32), `keyTick` (u16). That is 18 bytes × 640 groups × 24 players = 276 kB.

### 8.3 Spatial grid

Two-dimensional on X and Z, 64-stud cells, 32 × 32 = 1,024 cells. `cellHead` is a `u16` buffer; groups are linked through `nextInCell` and `prevInCell`. Depth is handled by the distance test, because the map is 2,048 wide and at most 600 deep. A group changes cell only when it crosses a boundary. Players and predators are few enough (24 and 32) to be looped over directly.

### 8.4 Update loop

`PreyService` runs at 10 Hz. Work is spread over the server's 60 Hz frames so no frame carries it all:

| Frame in a 6-frame cycle | Work |
|---|---|
| 0 | Threat pass, then simulate all active groups, write history |
| 0 to 5 | Interest and send for the players whose `slot % 6` equals the frame number (4 players per frame) |
| 3 | Spawner, on frame 3 of the first tick at or after each whole second since its last pass, so every 10th tick (chapter 02, section 9.5): each spawn row (zone and prey) below its target whose respawn delay has run (02 §9.5: 03's per-prey delay since its last group was eaten or removed) spawns one whole group, three in a pass while the Feeding Frenzy runs (chapter 02, section 14.4); event prey; the roaming `crystal_jelly` drift (one group of five members, about one drift per server every 300 s, canon 8.2). Respawn delays, trait prey counts and event prey counts come from the generated data (`PreyDef.respawn`, `PreyDef.lifetime`, `PreyDef.alive`, `PreyDef.eventTotal`, `TraitPreySpawns`), never from constants in the code |

A group is **active** if any player is within 700 studs. Dormant groups are stepped once a second with `dt = 1`, as a single group point. 700 studs is beyond the 600-stud interest radius (8.5), so every group any client draws moves at the full 10 Hz and the dormant rate only touches groups nobody can see; chapter 02, section 9.1 copies this rule. The budget does not depend on it: the S3-C2 build measured the simulation at 0.12 ms per tick at the Frenzy count, against the 2.0 ms budget below.

Per tick:

1. **Threat pass (player-centric).** For each creature and predator, visit the groups in its 3 × 3 cells. If the creature could eat that prey (`BiteRules.canEatPrey`) and is within `fleeRadius[kind]`, set the group's flee direction away from it and `stateUntil = now + 1.2 s`. For `swarm` kinds also raise the scatter target to 1. For a Moonlit creature within 40 studs, set the lured flag instead.
2. **Steer.** Fleeing: desired velocity = flee direction × `fleeSpeed`. Lured: toward the creature at 4 studs/s. Otherwise: toward the wander target at `cruiseSpeed`; pick a new seeded target inside the home volume every 3 to 6 s. `drift` kinds have a constant slow velocity. A flee lasts at most `fleeBurst`; the group is then tired for 2 s and moves at cruise speed (chapter 03, section 2.1).
3. **Integrate.** `vel += clampLength(desired − vel, accel × dt)`; `pos += vel × dt`. `accel = fleeSpeed × turnRate` (turn rate in radians per second): the sideways acceleration that turns a group at its turn rate at flee speed; the column is in °/s, so `turnRate` in rad/s = `turnRate(°/s) × π / 180`; a turn rate of 0 (turns in any direction) counts as one turn per second (2π rad/s) **(tune)**, and `drift` kinds use 1 stud/s² **(tune)**. Scatter moves toward its target at 2 per second up and 1/3 per second down, so a scattered swarm regroups over 3 s (chapter 02, section 9.2).
4. **Leash.** Outside the home volume, add a pull back; beyond 1.5 times its radius, clamp. Prey therefore never need collision with the world: volumes are authored in open water. `hop` kinds take `y = WorldIndex.floorY(x, z) + hopArc(phase)`.
5. **History.** Write the quantised position and scatter into the 8-sample ring (0.8 s) used by bite validation.

Cost: about 300 group updates per tick (545 at the Frenzy count), no allocation, no Instance access. **Budget: the simulation, steps 1 to 5 above, takes at most 2.0 ms per tick (0.35 ms averaged per frame) at the Frenzy count.** Interest and send (8.5) are not part of that 2.0 ms: they have their own budget, 0.25 ms per player per tick, 4 players per frame (15.2). The spike measured the two apart at 254 groups (S6): simulation p50 0.33 ms, p99 0.41 ms; interest and send about 0.13 ms per player p50 and 0.19 ms p99.

Schooling is therefore free: members hold formation by construction, "flee as a group" is one velocity, and "scatter when approached" is one number.

### 8.5 Interest management

For each player at 10 Hz, visit grid cells within 600 studs and classify each group by distance to the player's root. A group owned by another slot (scripted prey, 8.1) is skipped:

| Band | Distance (tune) | Send when the client's dead-reckoned error exceeds | Drawn as |
|---|---|---|---|
| Near | 0 to 150 studs | 1.0 stud, or flags or scatter changed | Individual meshes |
| Mid | 150 to 350 | 3.0 studs | Individual meshes out to the graphics tier's prey mesh distance (150, 250, 350 studs on Smooth, Balanced, Pretty; section 15.1) while the pool allows, else particles. On Smooth the whole Mid band is particles |
| Far | 350 to 600 | 8.0 studs | One particle cluster per group |
| Out | > 600 | Never. The client drops a Near or Mid group it has not heard about for 3 s, a Far group after 5 s **(tune)** | Nothing |

**Dead reckoning.** The server knows what it last sent to this player (`sentPos`, `sentVel`, `sentTick`). It predicts where the client now believes the group is (`sentPos + sentVel × elapsed`) and sends an update only if the real position differs by more than the band's threshold. A school cruising in a straight line costs zero bytes.

A group new to a player is sent as a **full record** in two consecutive packets; all other updates are **delta records**, except keyframes. When more records are due than fit in one packet, they are ordered by `error ÷ threshold`, nearest band first, and the rest wait for the next tick.

**Keyframes.** In the spike, interest was about 90% of the prey server cost and keyframes were 77% of all records sent (S6, F10). So keyframes are limited and spread out:

- Only groups in the **Near and Mid** bands get a keyframe: their full record again every 2 s.
- Keyframes are **staggered**: a group's keyframe for a player falls on the ticks where `(groupId + slot) % 20` equals `tick % 20`, so each tick carries about a twentieth of them instead of all at once.
- A **Far** group gets no keyframe. On its staggered tick (every 2 s), if nothing else was sent to that player for it in the last 0.5 s (`KEEPALIVE_QUIET`, 5 ticks, **(tune)**), it gets one delta record, which keeps the client from dropping it. The client's drop rule is per band: a Near or Mid group is dropped after 3 s of silence, a Far group after 5 s (`DROP_AFTER_FAR`, **(tune)**), because a Far group is drawn as particles and a few seconds of staleness there is harmless. Tolerance: with no loss the longest silence is 2.4 s (a record sent 0.4 s before a keep-alive tick skips that tick; the next is 2.0 s later). With **one lost packet** it is 4.4 s, under the 5 s drop. Two lost packets in a row can drop a Far group; the server then sends a full record once the group has been silent for `FORGET_AFTER` (2.5 s), so a far particle cluster blinks out briefly. That is the accepted risk. A 1 s keep-alive with the 3 s drop was tried (task S3-C3) and pushed the worst player's Frenzy average in `prey_soak.sim` past 4,500 B/s (16.2). Near and Mid keyframes fall on the staggered tick, so a group that moves out into the Far band starts inside the same bound.

### 8.6 Byte budget

`UnreliableRemoteEvent` payloads above 1,000 bytes risk being dropped (**V6**). In the spike, payloads of 999 bytes or more were dropped every time and silently, while 900 to 980 bytes arrived (S7, F8). One `PreyState` packet is at most 900 bytes and at most one is sent per player per tick. Every unreliable encoder asserts its payload is at most 900 bytes (`buffer.len`) before sending, so an oversized packet fails loudly in tests instead of vanishing in play.

| Stream | Hard cap per player | Expected average |
|---|---|---|
| `PreyState` | 9.0 kB/s (10 × 900 B) | 2.5 to 4 kB/s |
| `PredatorState` | 1.8 kB/s | 0.5 kB/s |
| Reliable events | — | 0.3 kB/s |
| Engine replication of other creatures | not ours to cap | estimate 5 to 14 kB/s (**U2**) |
| **Total received** | | **target ≤ 30 kB/s average, ≤ 50 kB/s peak** |

Worked example for a busy reef: 40 near groups of which half change course each second (20 × 13 B × ~3 sends = 0.8 kB/s), keyframes for 60 Near and Mid groups every 2 s (30 × 22 B = 0.66 kB/s), keep-alive deltas for 60 quiet Far groups every 2 s (30 × 13 B = 0.4 kB/s), headers (80 B/s), mid and far corrections (0.5 kB/s): about 2.4 kB/s. In a Frenzy the group counts double and so, roughly, does the stream: about 5 kB/s here, under the 9.0 kB/s cap.

### 8.7 Packet formats

All integers are little-endian (the `buffer` library's order). Quantisation, in `shared/Sim/Quantize.luau`:

```text
qx = round((x + 1024) × 16)   u16   1/16 stud, x in [−1024, 1024]
qy = round((y +  640) × 16)   u16   y in [−640, 96]
qz = round((z + 1024) × 16)   u16
qv = clamp(round(v × 2), −127, 127)   i8   0.5 studs/s, ±63.5 studs/s
timeMs = floor((Workspace:GetServerTimeNow() − ServerEpoch) × 1000)   u32
ServerEpoch = server start time, sent once in WorldInfo
```

**`PreyState`** (server → client, unreliable)

| Offset | Type | Field |
|---|---|---|
| 0 | u16 | `seq`, +1 per packet to this player; the client drops packets older than the newest seen |
| 2 | u32 | `timeMs` of the simulation tick |
| 6 | u8 | `fullCount` F |
| 7 | u8 | `deltaCount` D |
| 8 | 22 × F | Full records |
| 8 + 22F | 13 × D | Delta records |

Size = 8 + 22F + 13D ≤ 900.

Full record, 22 bytes:

| Offset | Type | Field |
|---|---|---|
| 0 | u16 | `groupId` |
| 2 | u8 | `gen`, 0 to 254 (wraps; 8.2) |
| 3 | u8 | `kind`: the `data:Prey` wire index (1 to 127), or 128 + the `data:TraitPrey` wire index (section 3.2) |
| 4 | u16 | `qx` |
| 6 | u16 | `qy` |
| 8 | u16 | `qz` |
| 10 | i8 | `qvx` |
| 11 | i8 | `qvy` |
| 12 | i8 | `qvz` |
| 13 | u8 | `scatter` (0 to 255 for 0 to 1) |
| 14 | u8 | `flags` |
| 15 | u8 | `count` |
| 16 | u32 | `alive` mask |
| 20 | u16 | `seed` |

Delta record, 13 bytes: `groupId` u16 (0), `qx` u16 (2), `qy` u16 (4), `qz` u16 (6), `qvx` i8 (8), `qvy` i8 (9), `qvz` i8 (10), `scatter` u8 (11), `flags` u8 (12). A delta for a group the client does not know is ignored; the next keyframe fixes it.

**`PreyEvent`** (server → client, reliable), sent to every player who knows the group:

| Offset | Type | Field |
|---|---|---|
| 0 | u8 | `n` records |
| 1 + 6k | u8 | `op`: 1 member eaten, 2 group removed, 3 member restored |
| 2 + 6k | u16 | `groupId` |
| 4 + 6k | u8 | `gen` |
| 5 + 6k | u8 | `member` |
| 6 + 6k | u8 | `eaterSlot` (0 = predator or despawn) |

**`Bite`** (client → server, reliable)

| Offset | Type | Field |
|---|---|---|
| 0 | u8 | `op`: 1 prey, 2 player, 3 predator or wild creature (9.3) |
| 1 | u8 | prey: `count` n (1 to 8); player: victim slot; predator: its slot in `PredatorState` |
| 2 | u16 | `seq`, the client's bite counter |
| 4 | u32 | `claimTimeMs`, the client's server-time estimate at contact |
| 8 + 4k | u16 | `groupId` (prey only) |
| 10 + 4k | u8 | `member` |
| 11 + 4k | u8 | `gen` |

Size: 8 bytes for a player or predator bite, 12 to 40 for prey. Anything else is malformed.

**`BiteResult`** (server → claimant, reliable), 9 bytes: `seq` u16 (0), `acceptedMask` u8 (2), `reason` u8 (3: 0 none, 1 gone, 2 range, 3 tier, 4 time, 5 rate, 6 state, 7 safe zone, 8 protected, 9 repeat), `newMass` f32 (4), `newTier` u8 (8).

**`PredatorState`** (server → client, unreliable): header `seq` u16, `timeMs` u32, `n` u8, pad u8, then n × 14 bytes: `id` u8, `kind` u8, `state` u8, `qx` `qy` `qz` u16 × 3, `qvx` `qvy` `qvz` i8 × 3, `targetSlot` u8, `stateTimer` u8 (units of 0.05 s).

**`PredatorEvent`** (reliable), 14 bytes: `op` u8 (1 telegraph, 2 strike, 3 gulp, 4 appear, 5 leave), `id` u8, `kind` u8, `targetSlot` u8, `qx` `qy` `qz` u16 × 3, `timeMs` u32.

Every codec has an encode and a decode function in `shared/Net/Codec/` and a round-trip unit test. `buffer` read and write functions used are those listed in the library reference (**V7**).

### 8.8 Client drawing

- **State.** `PreyRenderer` mirrors known groups in its own buffers. Each frame the target is `lastPos + lastVel × (now − lastTime)`; the drawn position eases toward it with a 0.1 s time constant, so a new packet never causes a pop.
- **Pools.** One pool of anchored MeshParts per prey kind, created on the client, `CollisionGroup = "Visual"`, `CanCollide`, `CanTouch`, `CanQuery` and `CastShadow` all false. Pool sizes by graphics tier (Smooth, Balanced, Pretty): 80, 150, 250 members drawn as meshes, within 150, 250, 350 studs, out of 250, 400, 800 prey visible in total once particle clusters and glints are counted (section 15.1; the code reads them from `tune.quality.*`, 17.4). Members are assigned nearest first; the rest of a group falls back to particles.
- **Moving them.** One `workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)` per frame for everything that moved (**V25**).
- **Animation.** Prey of tier 0 to 2 (`plankton`, `krill`, `shrimp`, `sardine`) are rigid meshes wiggled in code (yaw, roll and bob from the prey motion table, phase from `seed + i`). Tier 3 and above (`darter`, `mackerel`, `bonito`, `tuna`) are skinned to `RIG_Prey3` (three sway bones; the Tuna adds a fourth) and moved by the players' sway code at LOD0; their `_LOD2` is rigid and wiggled like the small prey (chapter 06, sections 6.3, 6.4 and 7.6; chapter 07, section 4.0). Trait prey use the rig their chapter 07 row names. No prey has a clip; the motion settings are the prey motion table (chapter 06, section 7.6, data:PreyMotion), read from the generated `PreyMotion` module (`Index.PreyMotion.byId`); the renderer copies no motion number.
- **Far groups.** One `ParticleEmitter` on a pooled Attachment per far group, emitting `count` glints coloured by kind. Limit by graphics tier: 30, 60, 60 emitters (section 15.1).
- **Reuse.** Identical MeshId and texture across a pool lets the engine instance the draw (**V32**).
- **Outlines.** Green, red or none (canon 5.2) is decided on the client from `BiteRules` and the local tier, and applied only to the nearest 20 edible and 10 dangerous things (8 and 4 on Smooth). A prey group counts as one thing, and each of its members drawn as a mesh gets the shell (chapter 06, section 13.2). Prey shells are 10% of body height with no minimum thickness (chapter 06, section 13.2), placeholders included. An outline is a **mesh shell**, an inverted hull authored with the asset (chapter 06, section 13.2), in the matte fallback material of chapter 06, section 13.2 (`SmoothPlastic`; Neon clipped lime to yellow and red to pink in Studio, task S3-C6, 14 October 2026), pooled and moved with its owner. One budget of 20 edible and 10 dangerous outlines is shared by creatures and prey, nearest first. `Render/Outlines` picks the mesh by colour (chapter 07, section 1.2): green "can eat" uses the asset's `_Shell`; red "can eat you" uses the 1.5 times thicker `_ShellThick`. `gull`, `moray` and `old_scar` have only `_ShellThick`, because they are never edible; `barracuda` and `grouper` have both, because a player one tier higher can eat them; playable species have both for the juvenile and the adult mesh. Roblox's `Highlight` instance is not used anywhere; it is unreliable on phones. The red shell pulses. `plankton` and hook bait never get a shell, nor does a `Protected` or Camo-hidden creature. Amber is kept for the home marker. The colour-blind setting swaps green and red for yellow and hot pink in `Render/Outlines`, with no other change.

### 8.9 The bite handshake

```text
client                                              server
  │ mouth sphere overlaps member i of group g         │
  │ (own rig mouth, own dead-reckoned prey position)  │
  │ hide member, play the bite, SFX_Bite_<size>       │
  │── Bite {op=1, seq, claimTimeMs, (g, i, gen)…} ───►│ 1 rate: token bucket 12/s
  │                                                   │ 2 state: alive, in a run, not stunned, not flagged
  │                                                   │ 3 target: group exists, gen matches, alive bit set
  │                                                   │ 4 tier: prey.tier ≤ eater tier
  │                                                   │ 5 time: tc = clamp(claimTime, now − 0.4 s, now)
  │                                                   │ 6 distance at tc (below)
  │                                                   │ 7 apply: clear bit, add mass, trait progress,
  │                                                   │   codex, goals, tier-up
  │◄── BiteResult {seq, mask, reason, mass, tier} ────│
  │    mass counter and growth update                 │── PreyEvent {eaten} ──► everyone who knows g
  │    on reject: member pops back with a "miss" puff │
```

Distance check, using only server-held data:

```text
(ex,ey,ez, lx,ly,lz) = MovementValidator.poseAt(slot, tc)      -- interpolated from the pose ring
r      = 1.2 × bodyScale × species.mouthMult × 1.25 × firstRun   -- 02 §4.1 mouthRadius, dash factor always on
nose   = eaterPos + look × (1.5 × bodyScale × species.lengthMult) -- 02 §0.2: half the body length
mouth  = nose + look × (0.5 × r)                                -- 02 §4.1 mouthCentre
prey   = PreyService.memberPosAt(g, i, tc)                     -- group history + Formation.offset
reach  = assist × r                                            -- the widest gulp assist range, 2.5
       + PreyDef.radius + PreyDef.wobble
       + 3.0                                                   -- base tolerance, studs (tune)
       + 0.15 × (eaterSpeed + preySpeed)                       -- 150 ms of relative motion (tune)
accept if |mouth − prey| ≤ reach
```

`bodyScale` is the smooth value for the eater's mass at `tc` (section 6.8). The mouth centre and radius are chapter 02's (section 4.1), so the server and the client measure from the same point with the same sphere. Two inputs the server cannot trust are taken at their widest: `assist` is 2.5, the range of the touch column in chapter 15, section 4.3 (the server never trusts the input type a client states), and the dash factor 1.25 is always applied (a claim can arrive up to 0.4 s after a dash ended, and the rig the client bit with lags the root). `firstRun` is the first-run mouth factor of chapter 04, section 4 (×1.6 in run 1, ×1.3 in run 2, else 1), read from the profile. No assist ever applies to a bite on a player (10.3).

**Every honest claim is inside the reach.** A client claims a prey bite only when the prey is within `max(r_c + preyRadius, 2.5 × r_c)` of its mouth centre (02 §4.1), where `r_c` is the client's mouth radius, at most `r`. Since `2.5 × r_c ≤ 2.5 × r` and `r_c + preyRadius ≤ 2.5 × r + preyRadius`, the server's `reach` exceeds the widest claim. The server's centre sits `0.5 × (r − r_c)` ahead of the client's (0 in a dash, when `r_c = r`), so measured from the server's centre the widest claim is `2.5 × r_c + 0.5 × (r − r_c)`, and the margin is `2 × (r − r_c) + PreyDef.radius + PreyDef.wobble + 3.0 + 0.15 × (eaterSpeed + preySpeed)`, never negative because `r_c ≤ r`. That margin is what covers the client's smoothed rig and dead-reckoned prey being off the server's pose and prey history at `tc`. Worked at tier 7 (`bodyScale` 6.5, `mouthMult` and `lengthMult` 1.0, run 3 or later):

| Case | Client's widest claim, from its own centre | Centre shift | Server reach | Margin |
|---|---|---|---|---|
| Swimming at rest (speed 0) | `2.5 × 1.2 × 6.5 = 19.5` studs | `0.5 × (9.75 − 7.8) = 0.98` | `2.5 × 9.75 + preyRadius + 3.0 = 27.4 + preyRadius` | ≥ 6.9 studs |
| Dashing (speed `38 × 2.2 = 83.6`) | `2.5 × 9.75 = 24.4` studs | 0 | `24.4 + preyRadius + 3.0 + 0.15 × 83.6 = 39.9 + preyRadius` | ≥ 15.5 studs |

**What the reach does not catch.** The reach is never tightened to catch cheats: an honest bite must never be rejected. So a client claiming bites from further than it may is rejected by distance only beyond about 1.4 times its widest honest claim at tier 7 at rest (`(27.4 − 0.98) / 19.5`), 1.6 times in a tier-7 dash and 2.2 times at tier 1 at rest (`(6.75 − 0.15) / 3.0`), less for larger prey **(tune)**. Reach cheats inside that band are caught mainly by the server's reject counters by reason and the guard rules (section 14; risk R5, section 20), not by the distance check alone.

The client's own idea of where its mouth was is never sent, so it cannot be forged. A rejected claim more than three times out of reach adds 2 suspicion. Mass gained is `PreyDef.mass × TraitService.massMult(slot)`; the client is told the result and never computes it. Bites are never logged one by one (chapter 10, section 2.4): the server counts accepted and rejected claims by reason and reports them on the run-end events.

## 9. Predators and hazards

### 9.1 Volumes

Gameplay regions are authored in Studio as invisible parts under `Workspace.Volumes` (Block, Ball or Cylinder), tagged `Volume`, with a `Kind` attribute and kind-specific attributes. At server start `WorldIndex` converts each to data (shape, inverse CFrame as 12 numbers, half-size, attributes), **destroys the parts**, and sends the table to each client once in `WorldInfo` (about 30 bytes per volume). Point-in-volume tests are plain arithmetic on both sides.

| `Kind` | Attributes | Used by |
|---|---|---|
| `Zone` | `ZoneId` | Zone lookup, lighting preset, spawn rules |
| `SafeNursery` | — | Bite rules |
| `CoveMouth`, `CoveInterior` | `CoveIndex` 1 to 24 | Banking, safety, visits |
| `PreySpawn` | `PreyIds`, `MaxGroups`, `Floor` | PreyService spawner and leash |
| `Current` | `Strength`; direction is the part's look vector | Movement (client applies, server allows) |
| `EelHole` | — | Zone bounds check |
| `Hazard` | `HazardId`; for a cycling `vent`, `CycleOffset` in seconds (0 to 8). A vent with no `CycleOffset` always erupts (section 9.4) | Hazard pass |
| `GullSky`, `MorayHole`, `PredatorNode` | `PredatorId`, `Next` | PredatorService |
| `HatchBed` | — (one small Ball part; only its centre and the part's look vector are kept) | `RunLoopService.join`: where an account that has never banked hatches for its first run, facing along the look vector (chapter 04, section 3.5; chapter 03, section 6.2 places it at (−398, 340), floor 24, facing east). Exactly one per place with a Nursery |
| `RevivePoint` | `PointId`: `rp_01` to `rp_12` (chapter 03, section 6.11) | `RunLoopService`: where a revived or resumed creature returns (section 6.3) |
| `NurseryPath` | `PointId`: a row of chapter 03's `data:NurseryPath` (section 6.2): `swarm_a`, `plankton_trail`, `swarm_b`, `glow_grotto`, `kelp_curtain`, `little_arch`, `elbow_leg_1`, `elbow_bend`, `elbow_leg_2`, `home_current_mouth` | `WorldIndex.nurseryPathAt` and `TutorialService`: where on the first-run route a creature is, such as crossing the Gap (chapter 04, section 3.5). Shapes and sizes are chapter 03's (section 6.2, authoring the route); `Logic/NurseryRoute` builds them and `tools/studio/place_nursery_volumes.luau` places them |

A `RevivePoint` is a small Ball part; only its centre is kept. `WorldIndex` stores the 12 centres with the volume table and does not send them to clients. `tools/studio/check_place.luau` fails if any of the 12 IDs is missing, sits away from its row in the generated `RevivePoints` table, or lies inside the collision shell or a `Hazard` volume.

`WorldIndex` also builds a floor height field: 256 × 256 `u16` values (8-stud cells) from 65,536 downward raycasts against the `World` group, spread over the first 2 s after start.

### 9.2 What is an Instance and what is data

| Thing | On the server | On the client |
|---|---|---|
| Prey, trait prey, hook bait | Data (`PreyService`) | Pooled meshes, particles |
| `gull`, `moray`, `barracuda`, `grouper` [L], `old_scar` | Data: `PredatorService`, 32 slots, 20 Hz | Skinned rigs built by `PredatorController` |
| `jelly_bloom`, `anemone` [L], `vent` [L] (nine at the Chimneys), `current`, eel holes, safe zones, cove mouths | Data: volumes | Art in `Workspace.World` plus the volume table |
| `hook` | A `Hazard` volume plus a one-member prey group with the bait flag set. The bait has no content ID of its own; it belongs to `hook` | Mesh. The bait never gets an outline shell (canon 5.2) |
| Whale skeleton [L] | Data: position is a function of event time | Client-animated model |
| Wild creatures [L] | Data: slots in `PredatorService`, driven by `PredatorSim` under the player rules (9.3). No root part, no `Player` | Species rigs with a "Wild" name tag |
| Collision shell, eel gates | Anchored Instances in `Workspace.Collision` | The same Instances |
| Creature roots | One Part per player | The same Part, plus a local rig |

The server therefore holds about 24 unanchored parts and under 200 anchored ones for gameplay. No predator or prey is ever an Instance on the server.

### 9.3 Predator behaviour and attack validation

Predators are state machines in `shared/Sim/PredatorSim.luau` stepped by `PredatorService`. They move along authored node graphs and in straight lines, with a raycast guard, so they need no pathfinding. All numbers **(tune)**. Chapter 03, section 5.1 owns the content numbers (detect range, speeds, chase time, rest) and chapter 02, section 9.4 owns the behaviour; the values below are copied from chapter 03 and reach the code through `Data/Generated/Predators`.

| Predator | Trigger | Telegraph | Strike check (server poses only) |
|---|---|---|---|
| `gull` | A creature of tier ≤ 2 inside a `GullSky` volume within 6 studs of the surface for 2.0 s | `PredatorEvent` op 1 with the strike point and strike time = now + 1.5 s; clients draw the shadow | At strike time, any creature of tier ≤ 2 within 5 studs of the strike point is gulped; 8 s rest |
| `moray` | A creature of tier ≤ 3 within 14 studs of a `MorayHole` | 0.6 s | Lunge 18 studs along the hole axis at 70 studs/s; hit radius 5 studs; 6 s rest |
| `barracuda` | A creature of tier ≤ 3 within 45 studs with a clear ray (tested every 0.25 s) | 0.8 s turn-to-face | Chases in straight lines at 36 studs/s, turn rate 80°/s, gives up after 6 s; bite radius 4 studs; 5 s rest |
| `grouper` [L] | A creature of tier ≤ 4 inside its suction cone (32 studs long, 60° wide) | 1.0 s | Sends status `pull` (22 studs/s for 2.5 s); gulps within 5 studs of the mouth; 6 s rest |
| `old_scar` | A creature of tier ≤ 6 within 90 studs | Tail-kick event 1.0 s | Chases at 40 studs/s for up to 8 s, turn rate 70°/s; bite radius 9 studs; 10 s rest after a gulp |

Validation rules:

- The server decides every predator hit from `MovementValidator` poses at the moment of the strike. There is no client claim and no rewind; the telegraph is the reaction window, and it is longer than any tolerated latency.
- Protection is applied in the same function as player bites (section 10.2): safe volumes, the newcomer rules, revive and reconnect protection, Shell, Puff and Spiny (each lowers the predator's effective `eatsMaxTier` by one for that creature), Plated.
- **Newcomers (canon 5.2; chapter 04, section 4 owns the detail).** While the first-run shield is up, no predator targets or gulps the creature and no hazard stuns, hooks, burns or slows it. In the account's second run, predators do not target it for the first 45 s after it leaves the cove.
- A gulp calls `RunLoopService.gulp(slot, predatorId)`.

**Players eating predators (canon 5.2).** A player at least one tier above a `barracuda` (tier 5 or higher) or a `grouper` (tier 6 or higher) can eat it. The claim is a `Bite` with `op = 3` and the predator's slot; `BiteService` checks the tier, then distance with the lag compensation of 10.3 against the predator's pose history, and calls `PredatorService.tryEat`. The eater gains `PredatorDef.eatenMass` (25 for `barracuda`, 60 for `grouper`, the same as prey of their tier, canon 5.2; nil means not edible) and the predator respawns at its home point 45 s later (chapter 02, section 9.4). `gull`, `moray` and `old_scar` are never edible: such a claim is rejected with reason `tier`.

**Wild creatures [L]** (canon 15; chapter 02, section 9 owns the rules) fill a quiet server: `max(0, 10 − players)` of them, at most 8, labelled "Wild" and never shown as players or on a leaderboard. They are `PredatorSim` state machines that use the player species' sizes and follow every player rule in both directions (`BiteRules`, safe volumes, protection, the newcomer rules). A player eats one with the same `op = 3` claim and gains 30% of its mass. On a private server the owner can switch them off (section 18.4).

### 9.4 Hazards

A hazard pass runs at 10 Hz: each creature in a run is tested against `Hazard` volumes. Effects are applied on the server and announced with `CreatureEvent`; the owning client applies the motion part, and `MovementValidator` enforces it through `vAllowed`.

| Hazard | Server effect | Enforced by |
|---|---|---|
| `jelly_bloom` | Status `stun` 1.5 s, then 3 s of sting immunity. Skipped with Ember | `vAllowed = 0` |
| `anemone` [L] | Status `slow` 2 s | `vAllowed × 0.5` |
| `vent` [L] | Only while the vent is `Erupting` (rule below): mass × 0.95 each second inside the column. Skipped with Ember | Server-side mass only |
| `hook` | Biting the bait (the flagged prey member of 9.2) gives no mass; mass × 0.8; status `yank` 1.0 s | Server-side mass; 1.0 s validator grace for the pull upward |
| `current` | None | `vCurrent = 0.6 × tierSpeed` added to `vAllowed` while inside (7.1, 02 §1.2) |

**Thermal vents [L]** (chapter 03, section 5.1 owns the rule; chapter 02, section 10.3 owns how the burn is ticked). There are nine `Hazard` volumes with `HazardId = "vent"` at the Chimneys. Each is the burning column: a cylinder 10 studs wide (radius 5) and 40 studs tall, rising from the chimney top; a creature is inside when its centre is. Three vents have no `CycleOffset` and are `Erupting` all the time. The other six cycle every 8 s: `Dormant` 4 s, `Rumble` 1 s (the warning, harmless), `Erupting` 3 s. The lengths are `HazardDef.cycle` and each vent's `CycleOffset` is fixed in Studio so the six never all erupt together. The state is a pure function of the clock, like the tides (section 11.1):

```lua
local t = (Workspace:GetServerTimeNow() + cycleOffset) % 8          -- 8 = dormant + rumble + erupting
local state = if t < 4 then "Dormant" elseif t < 5 then "Rumble" else "Erupting"
```

Server and clients evaluate the same line, so the rumble and the column are drawn with no packet. The server alone applies the burn.

Mass lost to a vent or a hook goes through `CreatureService.addMass` with a negative amount, so the tier is derived again and can fall (section 6.8). No hazard affects a creature under the newcomer shield (9.3).

A client that ignores a stun or a slow is corrected by the ladder in 7.3. A client that ignores the Grouper's pull only escapes more easily; that is accepted.

## 10. Player-versus-player bites

### 10.1 Authority and flow

The server decides. The eater's client claims contact with a `Bite` message (`op = 2`, victim slot, `claimTimeMs`); it plays nothing final until `BiteResult` arrives, because eating a player is too important to roll back. The victim's client has no say.

### 10.2 Rules, checked in this order at processing time

| # | Rule | Reject reason |
|---|---|---|
| 1 | Eater and victim are both in a run and alive; eater not stunned, not flagged | state |
| 2 | Victim tier ≥ 2 (tier 1 players cannot be eaten by players) | tier |
| 3 | Victim's server pose is not inside `SafeNursery`, a `CoveMouth` or a `CoveInterior` | safe zone |
| 4 | Victim is not `Protected` and not in Shell. `Protected` covers the 3 s after a revive, the 3 s after resuming a suspended run, and the **first-run shield**: an account that has never banked cannot be eaten by anything until its first bank, for at most 240 s of play time **(tune)**, counted in `newcomer.shieldUsed` and never restarted by a rejoin | protected |
| 5 | `eaterTier ≥ victimTier + 1`, where `victimTier` gains +1 during Puff and +1 with Spiny | tier |
| 6 | Distance with lag compensation (10.3) | range |
| 7 | **Repeat guard** (chapter 02, section 4.2, check 7): this eater has not gulped this same victim in the last 90 s **(tune)**. The victim bumps. | repeat |
| 8 | **Newcomer bubble:** if no player has ever bitten this account (`newcomer.biteAbsorbed` is false), the bite is absorbed once: the flag is set and saved, the victim is thrown 30 studs clear with 3 s of protection and loses nothing, the eater gains nothing | protected |
| 9 | If the victim has unused Plated: the bite is consumed, the victim survives with 1.5 s protection and a knock-away, the eater gains nothing | protected |
| 10 | Otherwise the victim is gulped; the eater gains 30% of the victim's mass **(tune)**. Bonefed raises that gain by 25%; Spots does not apply to eating players (canon 9). The feed guard of chapter 02 halves the gain each time the same eater eats the same victim within 10 minutes | — |

The newcomer rules come from canon 5.2; chapter 04, section 4 owns their detail. Their state is in the profile (`newcomer` in section 12.2), not the session, so leaving and rejoining cannot re-arm the shield or the bubble. A shielded creature still bumps: the `Creature` collision group is unchanged.

Tiers, protection and safe zones are read **when the server processes the claim**, not at the claimed time. A creature that grew, banked, puffed or reached a cove before the claim arrived is safe. This favours the victim on purpose: being eaten wrongly feels worse than missing a bite.

### 10.3 Lag compensation

```text
tc     = clamp(claimTime, now − 0.20 s, now)
mouth  = eater mouth sphere from MovementValidator.poseAt(eaterSlot, tc)
victim = victim body centre at every pose sample in [tc − 0.25 s, tc]
reach  = 0.9 × eaterScale + 1.0 × victimScale + 2.0 studs      (tune)
accept if any sample is within reach
```

The eater's own pose is trusted only as far as the validator accepted it. The 0.25 s look-back on the victim covers what the eater's screen showed (replication delay plus rig smoothing). Total rewind never exceeds 0.45 s, so a player on a very bad connection cannot eat someone who left a second ago.

### 10.4 Tie-breaks

| Case | Result |
|---|---|
| Two eaters claim the same victim | First claim processed wins; the second gets `gone` |
| Eater A claims B while a predator strike on B resolves in the same tick | Player bites are processed before predator strikes in the tick, so A gets the mass |
| A claims B in the tick that B reaches A's tier | Tier at processing time: rejected |
| A claims B and C eats A in the same tick | Claims are processed in arrival order; if C's is first, A is dead and A's claim fails rule 1 |
| Same tier, touching | No bite. Physics pushes them apart |
| Victim disconnects mid-claim | The body stays in the water for 10 s (12.5) and can still be eaten |

Player-bite claims are limited to 2 a second inside the `Bite` bucket. Each accepted bite logs `run_pvp_eat` (value: mass gained; ctx: the eater's tier) and, at [L], `pvp_pair`; both tiers and the measured distance go to the server log, so tolerance tuning has data.

## 11. Tide events

### 11.1 Clock and schedule

The schedule is a pure function of Unix time in `shared/Logic/TideClock.luau`. Every server and every client evaluates the same function, so all servers agree without exchanging a message.

```lua
--!strict
local SLOT, ACTIVE, WARN = 900, 240, 60
local ROTATION = { "frenzy", "moon_tide", "frenzy", "whale_fall" }   -- :00 :15 :30 :45

export type TideState = { phase: "calm" | "warning" | "active", id: string, startsAt: number, endsAt: number }
local TideClock = {}

function TideClock.at(unix: number): TideState
	local slotStart = unix - unix % SLOT
	local index = (slotStart % 3600) // SLOT + 1
	if unix < slotStart + ACTIVE then
		return { phase = "active", id = ROTATION[index], startsAt = slotStart, endsAt = slotStart + ACTIVE }
	end
	local nextStart = slotStart + SLOT
	local nextId = ROTATION[index % 4 + 1]
	if unix >= nextStart - WARN then
		return { phase = "warning", id = nextId, startsAt = nextStart, endsAt = nextStart + ACTIVE }
	end
	return { phase = "calm", id = nextId, startsAt = nextStart, endsAt = nextStart + ACTIVE }
end
```

- **Clock source:** `Workspace:GetServerTimeNow()` on both sides. It is a Unix timestamp, monotonic, and on a client it is that client's estimate of server time, independent of the device clock (**V29**). Roblox recommends it for starting events at the right real-world time.
- Clients draw the countdown and switch lighting from their own evaluation; no packet announces a scheduled tide. Gameplay effects (spawn rate, event prey) are applied by the server only.
- An event whose scope tag is not in the build, or that the build leaves out (`TideDef.outOfBuild`), uses its `fallback` from `TideDef`, followed until a tide that runs. `whale_fall.fallback = "moon_tide"`: until Whale Fall ships at launch, the :45 slot in the MVP build runs a second Moon Tide (canon 10). `moon_tide.fallback = "frenzy"` serves the slice: the slice build (`lune run tools/gen/content -- --slice`) keeps every tide row, because the rotation names all of them, and marks the rows outside the slice `outOfBuild = true`, so all four slots resolve to `frenzy` (chapter 13, section 3.2). The full build never writes `outOfBuild`.
- After launch the :30 slot is the flexible one (canon 10). A limited-time tide replaces its Feeding Frenzy when live config names one and the slot falls inside its window (`live.limitedTideId`, `live.limitedTideStart`, `live.limitedTideEnd`, section 17.4). Server and clients read the same forwarded keys, so they still agree without a message.
- Skew between Roblox servers' clocks is not documented (**U23**). It does not matter in play because no player is on two servers at once.

`TideService` polls `TideClock.at` once a second and fires `onPhase` on change. `PreyService` listens and calls `setTide(tideId)` at a phase start and `setTide(nil)` at its end: during `frenzy` respawn delays are divided by the tide's `spawnRateMult` (3), the spawner makes three spawns per row per pass and normal-prey targets and caps double (section 8.1); `moon_tide` spawns `lunar_fry` (12 at once, in groups of 4) in `PreySpawn` volumes flagged for it and removes them when it ends.

### 11.2 Call the Tide

`prod_call_tide` [L] can always be bought, is held as a token (up to three per player), and never interrupts or overlaps a scheduled tide or its warning (canon 10; chapter 02, section 14.7 owns the rule table).

1. `ProcessReceipt` grants a **token** (`tokens.call_tide += 1`) and saves (section 12.6). That is the purchase. `ShopService` then calls `TideService.callTide(player)` at once; a token left from an earlier session is used the same way from a Hud button.
2. `callTide` moves one token into the server's queue as a local override: a 10 s warning, then a Feeding Frenzy lasting 240 s.
3. The override starts at once when the scheduled phase is `calm`, at least 250 s remain before the next scheduled warning, and no called tide has run in this calm phase. In every other case the token is held in the queue and the override starts when the current (or next) scheduled tide ends. The scheduled clock is never shifted.
4. A player can hold up to three tokens (canon 10; chapters 02 and 05): `ShopService` does not open the prompt while the buyer has three tokens in the profile and the queue together, and a receipt that arrives anyway is still granted. When several players hold tokens, the queue starts them one at a time in the order they were bought, each after its own 10 s warning, and only when no tide is running (no scheduled tide or warning, and no other override). One called tide per calm phase per server, so each later token waits for the next calm phase. The queue has no cap of its own: three tokens for each of 24 players is 72 entries at most.
5. `TideEvent` (reliable) tells clients the override's start, end and buyer name. Late joiners get the queue in `WorldInfo`. The start logs `tide_call_used`.
6. If the buyer leaves or the server closes before the override starts, the token goes back to the profile and can be used on a later server.

Effective state on a server is: scheduled `active` or `warning` if any, else the running override, else scheduled `calm`.

## 12. Data

### 12.1 Stores

| Store | Type | Key | Value |
|---|---|---|---|
| `Player_v1` | Standard, through ProfileStore | `u_<userId>` | `ProfileData` (below) |
| `LB_WeekMass_<week>` [L] | Ordered | `<userId>` | Best banked mass this week, rounded to an integer |
| `LB_Bubbles` [L] | Ordered | `<userId>` | Lifetime Bubbles received |

`week = floor((unix − 345600) / 604800)`, which starts weeks on Monday 00:00 UTC. A small fixed set of stores with keys built from the user ID follows Roblox's guidance (**V8**). Names and keys are under the 50-character limit.

### 12.2 Save schema, version 1

```lua
--!strict
export type SpecimenRecord = {
	id: string,            -- 8-character random ID, unique within the cove
	sp: string,            -- species ID
	tier: number,          -- 2..7
	mass: number,          -- final mass, rounded to 1 decimal
	traits: { string },    -- up to 3 trait IDs
	at: number,            -- Unix seconds when banked
	pat: string?,          -- pattern ID
}

export type RunSnapshot = {
	sp: string, pat: string?, mass: number, tier: number, traits: { string },
	progress: { [string]: number },      -- trait ID → trait prey eaten (0..5)
	startedAt: number, runSeconds: number,
	platedUsed: boolean, reviveUsed: boolean, untrusted: boolean,
	x: number, y: number, z: number,     -- last accepted position, for resuming
	feedGuard: { [string]: number },     -- victim userId → times eaten in the last 10 minutes (chapter 02)
	suspendedAt: number?,                -- Unix seconds; nil while the run is live on a server
	expiresAt: number?,                  -- suspendedAt + 300 after a disconnect, + 900 after a server shutdown;
	                                     -- compared with the clock once, at join (section 12.5)
	onExpiry: ("scraps" | "bank_pearls")?,   -- what an expired run pays (section 12.5)
}

-- Device-shaped settings are saved once per input mode, so a phone setting never lands on a PC (chapter 15)
export type InputSettings = {
	scheme: string,                      -- control scheme ID (chapter 15, section 2.2): "drag" (drag to swim) or "two_thumb" [L]
	                                     -- on touch; "keys" on keys; "pad" [L] on pad
	lookSpeed: number,                   -- sensitivity; range per input mode (chapter 15, section 10 item 7).
	                                     -- On touch this is the drag sensitivity of "drag" (0.5 to 1.5)
	twoThumbLookSpeed: number,           -- [L] touch only: how fast the view turns in "two_thumb" (0.5 to 2.0, default 1.0;
	                                     -- chapter 15, section 3.1). A second saved value, not shared with lookSpeed.
	                                     -- Present but unused on keys and pad
	flipY: boolean,
	graphics: "auto" | "smooth" | "balanced" | "pretty",
}

export type ProfileData = {
	v: number,                           -- schema version, 1
	createdAt: number, lastSeenAt: number, sessions: number, playSeconds: number,
	pearls: number,                      -- whole number, never negative
	rank: { points: number,              -- the only Reef Rank input: base banking and scraps, before pass multipliers (13.4)
		claimed: number,                 -- [L] highest rank whose reward has been paid
		title: string? },                -- [L] chosen title
	species: { owned: { [string]: boolean }, selected: string,
		patterns: { [string]: { string } },      -- species ID → pattern IDs owned
		equipped: { [string]: string } },        -- species ID → pattern ID equipped
	cove: { slots: number,               -- 6..30 bought with Pearls; Bigger Cove adds 10 at read time
		specimens: { SpecimenRecord },
		pendingSpecimen: SpecimenRecord?,        -- banked into a full cove; waits for the release choice (canon 5.4)
		pending: number, accruedAt: number,      -- income pile (section 13.2)
		lastClaim: { amount: number, at: number }?,
		boostDay: number,                        -- [L] UTC day of the last Cove Boost (once a day)
		bubbles: number,                         -- [L] Bubbles received
		decorOwned: { [string]: boolean },       -- [L] decoration IDs owned (chapter 03, section 13), however they were
		                                         -- obtained: Pearls, Reef Rank, Codex, goals, events, Robux, Starter Pack
		decor: { [string]: string } },           -- [L] decorations placed: anchor ID → decoration ID
	codex: { species: { [string]: number },      -- species ID → highest tier reached (categories cdx_species and cdx_tiers)
		traits: { [string]: boolean }, prey: { [string]: number },
		dangers: { [string]: boolean }, places: { [string]: boolean }, tides: { [string]: boolean },   -- [L]; places is keyed
		                                         -- by landmark ID (lm_<name>, chapter 03, sections 6.2 to 6.6 and 8.2)
		rewards: { [string]: boolean } },        -- rewards already paid: category ID (cdx_species ... cdx_all), or
		                                         -- "cdx_tiers:<species>" for one species' Tiers page and its pattern
	goals: { day: number,                        -- UTC day the list belongs to
		list: { { id: string, progress: number, target: number, claimed: boolean } },
		rerolls: number,                         -- free rerolls used today
		paidRerolls: number,                     -- [L] Goal Reroll products used today
		bonusClaimed: boolean,                   -- the all-three bonus
		fullDays: number },                      -- [L] lifetime days with all three goals done (at most +1 a day).
		                                         -- Grants deco_goals_sun_shell at 3, deco_goals_week_wheel at 7,
		                                         -- deco_goals_lucky_starfish at 14, deco_goals_message_bottle at 28
	streak: { day: number, count: number },      -- [L] day = UTC day the last box was opened; count = boxes opened so far.
	                                             -- A missed day changes nothing: count is never reset
	stats: { runs: number, banks: number, deaths: number, bites: number,
		playersEaten: number, bestMass: number, bestTier: number,
		gullDodges: number,                      -- lifetime Gull dives dodged: badge 17 "Not Today, Gull" at 10
		breaches: number,                        -- lifetime breaches (entries into Airborne): badge 19 "Flying Fish" at 100
		bubblesGiven: number,                    -- [L] lifetime Bubbles left on other coves: badge 25 "Good Neighbour" at 25
		events: { [string]: number } },          -- [L] lifetime event-task counters; a missing key reads as 0. Keys and the
		                                         -- decoration each unlocks (chapter 03, section 13):
		                                         --   frenzy_prey   prey eaten during Feeding Frenzies   deco_evt_dinner_bell at 500
		                                         --   lunar_fry     Lunar Fry eaten                      deco_evt_moon_lamp at 25
		                                         --   marrow        Marrow chunks eaten                  deco_evt_whale_rib at 25
		                                         --   [P1] storms_survived (deco_evt_storm_bottle at 5), red_tide_prey
		                                         --   (deco_evt_red_bloom at 300), migrations_followed (deco_evt_fish_kite at 1)
		                                         --   [P2] trench_quiet (deco_evt_trench_lantern at 1)
	newcomer: { firstDeath: boolean,             -- true once the account has died; the Revive offer is hidden on that first death
		biteAbsorbed: boolean,                   -- the one absorbed player bite has been used (10.2)
		runsCompleted: number,                   -- runs ended by a bank, a gulp or an expiry
		shieldUsed: number },                    -- seconds of the first-run shield already used
	passes: { [string]: boolean },               -- pass_<name> → last answer from Roblox (rule below)
	tokens: { revive: number, trait_lock: number, call_tide: number, goal_reroll: number },
	traitLock: { traits: { string } }?,          -- [L] set when a Trait Lock is used; applied and cleared at the next run start
	purchases: { receipts: { string },           -- last 100 PurchaseIds, oldest dropped first
		starterPack: boolean, robuxSpent: number,
		packDay: number, packsToday: number },   -- Pearl packs bought today (chapter 05 owns the cap)
	ads: { day: number, counts: { [string]: number } },   -- [L] rewarded videos watched today, by ad_<name>
	offers: { [string]: number },                -- offer ID → UTC day last dismissed (chapter 05, section 9)
	social: { bubbleDay: number, bubbledUserIds: { number } },   -- [L] coves given a Bubble today, by owner
	board: { week: number, weekBest: number },                   -- [L] avoids reads before writes
	ftue: { stage: number, completed: boolean,                   -- tutorial state (chapter 04); stage: S0_LOADING = 0
		                                         -- to S10_RUN2 = 10, DONE = 11 (chapter 04, section 3.1)
		version: number,                         -- tutorial version the account saw, currently 1 (chapter 04, section 9)
		attempts: number },                      -- +1 each time the tutorial restarts after a disconnect before the first bank
	ab: { [string]: string },                    -- experiment key → arm, copied at first exposure (chapter 10, section 8.1)
	settings: { sfx: number, music: number,      -- 0..10
		colourBlind: boolean,
		reduceMotion: boolean?,                  -- nil = follow the device
		vibration: boolean, tapNotHold: boolean,
		leftHanded: boolean,                     -- [L]
		biggerText: boolean, language: string,   -- [L]; "" = same as Roblox
		interfaceSize: number, swapSticks: boolean,                        -- [L]
		hideEmotes: boolean,                     -- [L] "A setting hides all emotes" (chapter 02, section 17.1). Chapter 08
		                                         -- must expose this toggle in settings (S31); without the row it cannot be set
		input: { touch: InputSettings, keys: InputSettings, pad: InputSettings },
		lastGoodTier: { [string]: string } },    -- [L] screen class → graphics tier (chapter 15, section 6)
	moderation: { kicks: number, flags: number },
	run: RunSnapshot?,                   -- present only while a run is unsettled: live on a server, or suspended
}
```

Rules: dictionary keys are always strings; arrays have no holes; no `NaN` or infinity; no Instances or buffers. `day` fields are `floor(unix / 86400)` (UTC days). Fields tagged [L] are in the version 1 template from the start with empty defaults, so shipping the feature needs no migration.

**Lifetime counters for decorations [L].** `stats.events` and `goals.fullDays` only ever go up. `BiteService` adds to `stats.events` when prey is eaten (a Feeding Frenzy is running, or the prey is `lunar_fry` or `marrow`); `GoalsService` adds to `goals.fullDays` once a day, when the third goal of the day is done. After either changes, `CoveService` compares it with `DecorationDef.need` and sets `cove.decorOwned[id]` for each decoration reached. The check is repeated at join, so a decoration added later reaches players who already passed its count.

**Lifetime counters for badges.** Roblox stores which badges an account holds, so the save keeps only the running counts a badge needs (chapter 03, section 12). `stats.gullDodges` (badge 17, at 10) goes up when a Gull dive aimed at the player ends without a catch, the same event daily goal `dg_gull_dodge_3` counts. `stats.breaches` (badge 19, at 100) goes up on each accepted change to `Airborne`, the same event `dg_breach_5` counts. `stats.bubblesGiven` [L] (badge 25, at 25) goes up with each Bubble left; `social.bubbledUserIds` only holds today's. These three only ever go up, and the badge check is repeated at join. Every other badge reads a value the save already holds (`stats.banks`, `stats.deaths`, `stats.bestTier`, `stats.playersEaten`, `cove.bubbles` for badge 26, `streak.count`, `species.owned`, `codex`, `rank.points`, the specimen list) or a single moment that needs no count. Two badges count inside one running of an event, so their count lives in server memory while the event runs and is not saved: badge 20 (100 prey in one Feeding Frenzy) and the 10 prey that fill a Codex Tides entry in `codex.tides`, which badge 24 reads for all three tides.

**Two touch speeds.** The touch input type saves two values: `lookSpeed` (drag sensitivity, for drag to swim) and `twoThumbLookSpeed` [L] (how fast the view turns in the two-thumb scheme). Chapter 08, section 6.7 shows them as two sliders with different ranges, and switching scheme never overwrites the other value.

Game pass ownership is asked from Roblox each session, and Roblox's answer is the authority. `passes` keeps the last answer so that a failed `UserOwnsGamePassAsync` call falls back to what the player owned before, not to nothing.

Chapter 04 drives its first-run assists from `ftue.stage`, `stats.banks`, `stats.deaths` and `stats.runs` (it calls the last three `banks_total`, `deaths_total` and `runs_total`). `ftue.version` and `ftue.attempts` are chapter 04's too. The 50% scraps rate reads `stats.deaths < 3`.

Size: a full 40-slot cove is about 5 kB of JSON and a complete profile under 20 kB, against a 4 MB limit per key and a 4 MB per minute write limit per key (**V8**). `DataService` refuses to save and logs an error above 200 kB.

### 12.3 Migrations

`shared/Logic/Migrations.luau` holds `SCHEMA_VERSION` and an array where entry `n` upgrades version `n` to `n + 1`. They are pure functions of a table.

1. After the session starts: if `data.v == nil`, the profile is new; fill from the template.
2. While `data.v < SCHEMA_VERSION`, run `Migrations[data.v]` and add 1.
3. `profile:Reconcile()` fills any field the template has and the data lacks.
4. If `data.v > SCHEMA_VERSION` (an old server met newer data after a rollback): change nothing, end the session, kick with "GULP is updating. Please rejoin."

Changes within a release are additive: new fields with defaults. A field is never reused for a new meaning. Removing or reshaping a field takes two releases (write both, then drop the old). Every version has a fixture in `tests/fixtures/profiles/` and a unit test that migrates it to the current version.

### 12.4 Session locking and autosave

ProfileStore gives one server at a time the right to write a profile (**V19**).

```lua
local profile = Store:StartSessionAsync("u_" .. player.UserId, {
	Cancel = function() return player.Parent ~= Players end,
})
if profile == nil then player:Kick("Could not load your save. Please rejoin.") return end
profile:AddUserId(player.UserId)
profile.OnSessionEnd:Connect(function() player:Kick("Your save was opened on another server.") end)
```

| Setting | Value | Source |
|---|---|---|
| Autosave period | 300 s (library default) | **V19** |
| Session steal threshold | 40 s (`SESSION_STEAL`) | **V19** |
| Dead session assumed after | 630 s (`ASSUME_DEAD`) | **V19** |
| Start-session timeout | 120 s; we kick after 20 s without a profile | **V19** |
| Forced save (`profile:Save()`) | After every Robux receipt; after banking a specimen of tier 5 or higher; at most one per player per 30 s | ours |
| In Studio and CI | `Store.Mock`, which never touches real data | **V19** |

No player ever plays unsaved: without a loaded profile there is no creature. If ProfileStore reports a critical state mid-session, play continues, autosaves keep retrying, and Robux purchases answer `NotProcessedYet`.

### 12.5 Mid-run disconnect

`profile.run` is kept current in memory (on every tier change and every 10 s) and cleared when a run is settled. The rule is canon 5.5; chapter 02, sections 16.4 and 16.5 own the detail.

| Situation | Outcome |
|---|---|
| Player leaves while in a run in open water | The creature stays in the water for **10 s** under server ownership, drifting with no input, and can still be eaten. If eaten: a normal gulp, scraps paid (13.4), run cleared. If it survives: the creature is removed and the run is **suspended**: `run.suspendedAt = now`, `run.expiresAt = now + 300`, `run.onExpiry = "scraps"`. The profile is saved and the session ends only after this |
| Player rejoins any server with `now < run.expiresAt`, and the account has banked at least once (`stats.banks > 0`) | `RunLoopService.resume` offers "Continue your run" or "Start fresh" (chapter 08, screen S36). Continue: the run resumes as in 6.3, with 3 s of protection, and `suspendedAt`, `expiresAt` and `onExpiry` are cleared. Start fresh: settled as expired |
| Player rejoins any server with `now < run.expiresAt`, and the account has never banked (`stats.banks == 0`) | No card. `RunLoopService.resume` resumes the run at once as in 6.3, and the first-time script carries on from the last completed beat (`ftue.stage`; chapter 04, section 9) |
| Player leaves again while the card is open | Nothing is chosen. `run` is saved unchanged, with its original `expiresAt` |
| Player joins with `now ≥ run.expiresAt`, or picks Start fresh | `RunLoopService.settleExpired` pays what `onExpiry` says (13.4) before the first spawn, counts the run in `newcomer.runsCompleted`, logs `run_abandoned`, and clears `run`. No specimen |
| Player leaves while the gulped screen is open | Treated as a declined revive: scraps were already paid |
| Player leaves inside their own cove | Already banked. Nothing to settle |
| Server shutdown or update (`game:BindToClose`) | Every open run is suspended at once with `expiresAt = now + 900` and `onExpiry = "bank_pearls"`: if the player does not resume in time it pays the full bank value in Pearls with no specimen. No creature waits 10 s; a shutdown is not the player's choice |
| Server crash (no settlement ran) | The next session finds `run` with no `suspendedAt`. It is treated as a shutdown that happened at `lastSeenAt` |
| Kick at ladder level 4 | Run discarded, no payout |

**The window is measured from the disconnect to the rejoin.** `expiresAt` is `suspendedAt + 300` (or `+ 900`), and `now < run.expiresAt` is tested once, when the profile loads at join. Time spent looking at the card is not counted: the card has no timer, and a run that passed the test at join cannot expire while the card is open, however long the player takes to choose.

The expiry is lazy: nothing has to run while the player is away, because the profile is only read at the next join and the saved `expiresAt` decides. A suspended run blocks nothing: Pearls, the cove and income are settled as usual at the next join.

The 10 s in the water closes the obvious exploit of quitting to avoid a bite; the 5-minute window forgives a dropped connection.

### 12.6 Purchases

One `MarketplaceService.ProcessReceipt` callback, set once in `ShopService` (**V12**). It follows Roblox's published sequence for session-locked data:

```text
ProcessReceipt(info):                      -- info.PurchaseId, PlayerId, ProductId, ProductPurchaseChannel
 1 player not in this server, or profile not loaded within 20 s   → NotProcessedYet
 2 id = info.PurchaseId
   id in profile.Data.purchases.receipts:
       id also in profile.LastSavedData.purchases.receipts        → PurchaseGranted
       else                                                        → wait for save (step 5)
 3 grant in memory through the product's grant function            (Pearls, token, pattern, decoration, flag)
 4 append id to purchases.receipts (drop the oldest beyond 100)    -- same table, same save as the grant
 5 profile:Save(); wait up to 30 s for OnAfterSave whose saved data contains id
       seen                                                        → PurchaseGranted
       not seen                                                    → NotProcessedYet
```

- **No double grant:** the grant and the receipt ID are written to the same profile under one session lock, so a repeated callback finds the ID.
- **No lost purchase:** `PurchaseGranted` is returned only after the save containing the grant is confirmed. After `NotProcessedYet`, Roblox calls again when the player rejoins or starts another purchase (**V12**), and step 2 completes it.
- Consumables used at a moment (`prod_revive`, `prod_trait_lock`, `prod_call_tide`, `prod_goal_reroll`) are granted as **tokens** and consumed by gameplay afterwards. If the moment passed, the token remains.
- `prod_cove_boost` [L] pays 2 hours of the cove's current income straight to Pearls in step 3 (section 13.2) and sets `cove.boostDay`. `ShopService` does not open the prompt or the video when `boostDay` is today; a receipt that arrives anyway is still granted, because a paid purchase is never refused.
- **One-time items [L]:** a pattern (`pat_<species>_<name>`) is added to `species.patterns`; a Robux decoration (`deco_buy_jelly_lamp`, `deco_buy_disco_clam`, `deco_buy_mini_pickle`) sets `cove.decorOwned[id] = true`, using the purchase ID as the decoration ID. `prod_starter_pack` is a bundle, granted in one step: the pattern `pat_minnow_sunrise`, the Golden Chest decoration `deco_buy_gold_chest` (which is not sold on its own), 5,000 Pearls, and `purchases.starterPack = true`. For a one-time item the player already owns, the client hides the button and `ShopService` refuses the `ShopAction`, so no prompt opens (chapter 05, section 14).
- Rewarded video [L] arrives through the same callback with `ProductPurchaseChannel = Enum.ProductPurchaseChannel.AdReward` (**V21**) and takes the same path. The placements `ad_revive`, `ad_cove_boost` and `ad_goal_reroll` grant one unit of `prod_revive`, `prod_cove_boost` and `prod_goal_reroll` (canon 12) and are counted in `ads.counts` against chapter 05's daily caps (3, 1 and 1; 5 in all).
- Game passes: `UserOwnsGamePassAsync` at join and again when `PromptGamePassPurchaseFinished` fires on the server (**V12**). The answer is cached in memory and copied to `passes` in the profile as the fallback for a failed call (12.2).
- **Purchase IDs** are chapter 05's and are used unchanged as `ProductDef.id`, as the `sku` in `ShopAction` and as the keys of `passes` and `ads.counts` in the profile (canon 16): passes `pass_deep_pockets`, `pass_bigger_cove` [MVP], `pass_tide_watcher`, `pass_keen_nose`, `pass_shark_pup` [L]; products `prod_revive`, `prod_pearls_s`, `prod_pearls_m`, `prod_pearls_l`, `prod_pearls_xl` [MVP], `prod_trait_lock`, `prod_call_tide`, `prod_starter_pack`, `prod_cove_boost`, `prod_goal_reroll` [L]; rewarded video placements `ad_revive`, `ad_cove_boost`, `ad_goal_reroll` [L]; Robux decorations `deco_buy_jelly_lamp`, `deco_buy_disco_clam`, `deco_buy_mini_pickle` [L]. Patterns are sold by their own `pat_<species>_<name>` IDs. Patterns and Robux decorations are one-time developer products (chapter 05, section 8.5), so they are `ProductDef` rows of kind `product` like the `prod_` ones. Analytics SKUs are a separate list in chapter 10.
- `MarketplaceService:BindReceiptHandler` also exists; its behaviour was not verified, so it is not used (**U20**).
- `ShopService.canSell(player)` is false for the first 120 s of a player's first session (canon section 12); no prompt can open before that.

### 12.7 Global leaderboards [L]

- **Write:** on bank, if the mass beats `board.weekBest` for the current `week`, update the profile and mark the board dirty. A flush every 60 s per player writes dirty boards with `SetAsync`. Bubbles are flushed the same way.
- **Private servers never write.** When `game.PrivateServerId ~= ""`, `LeaderboardService.submitBank` returns before it touches `board.weekBest`, whatever the player count, and a Bubble given there is shown in the cove but is not added to `cove.bubbles` or `LB_Bubbles` (chapter 02, sections 13.5 and 16.6; chapter 05, section 6.3). Private servers still read and show the global lists.
- **Read:** each server calls `GetSortedAsync(false, 50)` per board every 120 s and shows the cached list. Page size can be up to 100 (**V8**).
- **Server board (MVP):** computed in memory from `CreatureState`, no store.

### 12.8 Budget arithmetic for a full server

Limits (**V8**): per server per minute, standard read and write are each `60 + 40 × players`; ordered write is `30 + 5 × players`; ordered list is `5 + 2 × players`. Across the experience per minute: standard write `300 + 20 × CU`, standard read `300 + 40 × CU`, ordered write `300 + 20 × CU`, ordered list `300 + 2 × CU`, where CU is concurrent users. `UpdateAsync` counts against both read and write.

| Call | Rate at 24 players | Per-server limit | Share |
|---|---|---|---|
| Session start (`UpdateAsync`), 15-minute average stay | 1.6/min | 1,020/min | 0.2% |
| Autosave, 24 profiles every 300 s | 4.8/min | 1,020/min | 0.5% |
| Session end | 1.6/min | 1,020/min | 0.2% |
| Forced saves | ≤ 1/min | 1,020/min | 0.1% |
| **Standard total** | **≈ 9/min** | 1,020/min | **0.9%** |
| Ordered writes [L], worst case every player every minute on two boards | 48/min | 150/min | 32% |
| Ordered writes [L], typical | 3/min | 150/min | 2% |
| Ordered list reads [L] | 1/min | 53/min | 1.9% |

Experience-wide, each concurrent user adds 20 standard writes a minute to the budget and uses about 0.4, so usage stays near 2% at any scale. Ordered lists are the tightest experience-wide: each server adds 48 to the budget and uses 1. Shutdown is the burst case: 24 saves at once fits the 30-request queue (**V8**). ProfileStore's `MessagingService` use is far inside `20 + 8 × players` subscriptions per server (**V10**). `MemoryStoreService` is not used at launch.

Storage: the experience gets 500 MB plus 1 MB per lifetime user (**V8**); a profile uses about 0.02 MB.

## 13. Cove instancing

### 13.1 Twenty-four coves in one server

The reef rim holds 24 physical cove sites built from one modular kit (identical meshes, so the engine instances them, **V32**). There is no per-player copy of anything on the server; a cove is a slot number, two volumes and a profile.

- `PlayerLifecycle` gives a joining player a free slot once the profile is loaded. A new player (an account that has never banked, `stats.banks == 0`) gets the free cove nearest the Nursery, so the first trip home is short: C16, C17, C15, C18, then the next nearest (chapter 04, section 5.5 owns the rule; chapter 03, section 6.7 names the coves). A returning player (an account that has banked before, `stats.banks > 0`) gets the free cove farthest from Little Arch among the 20 coves nearest to it, so the four closest stay free for newcomers where possible **(tune)**; if all 20 are taken, the free one of the other four nearest Little Arch (`CoveRules.preference` lists the coves in this order; `Config/Defaults` holds the 20 as `returningPool`). A player who joined a friend gets the nearest free cove to that friend's instead [L] (chapter 02, section 16.1). Slot = cove index. `CoveService` sets `coveOwner[slot]`.
- Cove contents are data. When a creature enters a `CoveMouth`, the server sends that player a `CoveView` (owner name, slots, specimen list with species, tier, traits and pattern, Bubble count, decorations). The client draws specimens as idle-swimming rigs with reduced animation, at most 12 fully animated.
- The sign over each mouth (owner name and best specimen) is drawn by every client from the owner's `Player` attributes plus a `BestSpecimen` attribute.
- Entering **your own** `CoveMouth` during a run is the bank trigger. Banking happens at once, with no confirmation (canon 5.4). The server detects it from the validated pose; there is no bank remote. Entry also requires the last 0.5 s of poses to be a continuous path, so a teleport into the mouth does not bank. The payout is in 13.4. If the cove is full, the new specimen waits in `cove.pendingSpecimen` until the player releases an old one or the new one, or buys a slot, which the waiting specimen then takes (02 §11.5).
- Entering someone else's cove is a visit [L], allowed only as a tier 1 Fry, so a cove cannot be used as a safe room mid-run (canon 6; enforced by the zone-bounds check in 7.2). A visitor can look and leave one Bubble per cove per UTC day, recorded in the visitor's `social` fields and capped at 24 a day.
- When the owner leaves, the slot is freed after settlement and the sign clears. Visitors inside are simply in an empty cave.
- Coves only exist for players who are present, so no cross-server messaging is needed for visits or Bubbles.

### 13.2 Income from timestamps

Income is one pile per player that fills at the cove's rate and stops at the cap. It is the same formula online and offline (`shared/Logic/CoveIncome.luau`). The numbers are canon 9 and 11; chapter 05, section 3.3 owns them.

```lua
local BASE = { [2] = 6, [3] = 10, [4] = 18, [5] = 30, [6] = 50, [7] = 80 }   -- Pearls per hour by tier; generated from chapter 05

function CoveIncome.rate(specimens: { SpecimenRecord }): number            -- Pearls per hour
	local total = 0
	for _, s in specimens do
		local bonus = 0
		for _, t in s.traits do bonus += Traits[t].incomeBonus end          -- +0.10, 0.20, 0.35, 0.60, 1.00 by rarity, added together
		total += BASE[s.tier] * (1 + bonus)
	end
	return total
end

function CoveIncome.accrue(pending: number, accruedAt: number, now: number, rate: number,
		lastClaimAt: number, capHours: number)
	local stop = math.min(now, lastClaimAt + capHours * 3600)               -- 02 §13.2: counted only while now − lastClaim < cap
	local dt = math.max(0, stop - accruedAt)
	return pending + rate * dt / 3600, math.max(accruedAt, now)             -- never decreases
end
```

`capHours` is 8, or 24 with `pass_tide_watcher`: the pile stops growing once that many hours have passed since the last claim, online or offline. The cap is a time window, not an amount (chapter 02, section 13.2 owns the rule): after a rate change the pile holds what each period earned at the rate it had, so it can be more or less than `rate × capHours` at the new rate. `accrue` is called at session start, before any change to the specimen list (so the old rate applies to the old period), on claim, and at session end. Accruing only moves Pearls into the pile. `lastClaimAt` is `cove.lastClaim.at`; the first-bank payment (chapter 04, section 6, step 6.3) writes `lastClaim` like a claim, so every cove with income has one. A profile without it is treated as `lastClaimAt = accruedAt`, and `CoveService` writes `lastClaim = { amount = 0, at = now }` the first time a specimen is added to it.

**Income is claimed by tapping, never automatically (canon 11).** Pearls leave the pile only when the owner taps it in the cove or taps the welcome-back card; both send `CoveAction` with the claim op. Joining, banking and leaving do not claim. A claim grants `floor(pending)` through `EconomyService.grant(player, n, "CoveIncome")`, keeps the fraction, and records `lastClaim`.

**Cove Boost [L]** (`prod_cove_boost`, or a rewarded video where eligible) grants `floor(2 × CoveIncome.rate(specimens))` straight to Pearls, once per UTC day (`cove.boostDay`). It does not pass through the pile, so it neither empties it nor is limited by the cap.

Worked check: a tier 5 specimen with Spots and Plated earns 30 × (1 + 0.10 + 0.20) = 39 Pearls per hour.

### 13.3 Clock-tamper safety

- `now` is always the Roblox server's `os.time()`. No client-supplied time is ever read, so changing a phone's clock does nothing.
- `dt` is clamped to zero from below and `accruedAt` only moves forward, so a server with a slow clock cannot wind a profile back and re-pay a period.
- The pile stops `capHours` after `lastClaim.at`, so a server with a fast clock can over-pay at most one cap window.
- `os.time()` is not used for anything that needs sub-second precision; that is `GetServerTimeNow`.

### 13.4 Banking and scraps

`shared/Logic/BankMath.luau` holds the arithmetic of canon 5.4 and 5.5; chapter 05, sections 3.1 and 3.2 own the numbers. The steps are applied in this order:

```lua
function BankMath.base(mass: number): number                -- 3 per mass to 1,200, 1 per mass to 3,000, nothing above
	return 3 * math.min(mass, 1200) + math.clamp(mass - 1200, 0, 1800)
end

function BankMath.bank(mass: number, crystal: boolean, deepPockets: boolean): number
	return math.floor(BankMath.base(mass) * (crystal and 1.5 or 1) * (deepPockets and 2 or 1))
end

function BankMath.scraps(mass: number, crystal: boolean, deepPockets: boolean, deathsBefore: number): number
	local rate = if deathsBefore < 3 then 0.5 else 0.1       -- 50% for the first three deaths on the account
	return math.floor(rate * BankMath.bank(mass, crystal, deepPockets))
end
```

| Mass banked | Base | With Crystal | With Deep Pockets | With both |
|---|---|---|---|---|
| 200 | 600 | 900 | 1,200 | 1,800 |
| 1,200 | 3,600 | 5,400 | 7,200 | 10,800 |
| 3,000 or more | 5,400 | 8,100 | 10,800 | 16,200 |

`RunLoopService.bank` runs these steps in one synchronous block, so a disconnect cannot split them:

1. Read mass, tier and traits from `CreatureState`; `deepPockets = ShopService.owns(player, "pass_deep_pockets")`.
2. `EconomyService.grant(player, BankMath.bank(...), "Bank")`.
3. Add rank points: the same bank computed without Deep Pockets. Reef Rank counts only base banking and scraps, before any pass multiplier, so it cannot be bought (canon 11).
4. If the tier is 2 or higher and the run is allowed a specimen (7.3): `CoveService.addSpecimen`, or `cove.pendingSpecimen` when the cove is full.
5. Codex, goals, `stats`, `newcomer.runsCompleted`; the first bank on an account also ends the first-run shield.
6. `LeaderboardService.submitBank` with the full mass (the 3,000 limit applies to Pearls only; nothing is submitted on a private server, 12.7); clear `profile.run`; log `run_banked`.

A gulp pays `BankMath.scraps` with the same two side steps (rank points without Deep Pockets, then `stats.deaths += 1` and `newcomer.firstDeath = true` after the Revive offer rule in 6.3 has been read), and logs `run_gulped` once any revive offer is declined.

## 14. Security and anti-cheat

### 14.1 Trust model

| The server trusts | The server never trusts |
|---|---|
| Its own profile data, clocks, prey and predator state | Any number, ID, time or position inside a remote payload |
| A creature's replicated pose **only after** `MovementValidator` accepted it | That the client honours stuns, cooldowns, zone limits or tiers |
| Roblox services' answers (`ProcessReceipt`, `UserOwnsGamePassAsync`, `PolicyService`) | `Touched` events from client-owned parts (**V5**); none are used |

No remote grants Pearls, mass, traits, specimens or unlocks directly. The client can only ask for an action; the server computes every result from its own state.

### 14.2 Remote validation

Every client-to-server handler is registered through `Net/Server.on(name, spec, handler)`, which rejects before the handler runs:

1. **Count and type.** Exact argument count; each argument's `typeof` matches the spec.
2. **Size.** A `buffer` must have a length the codec accepts (for `Bite`: 8, or 8 + 4n with n from 1 to 8). Strings have a maximum length and are checked against a known ID table.
3. **Range.** Numbers are finite; integers are whole and in range; slots are 1 to 24; indices are within the array they address.
4. **Rate.** A token bucket per player per remote (table in 5.3). Over the limit the message is dropped.
5. **State.** The action is legal now: phase, ownership, balance, cooldown.
6. **Isolation.** The handler runs under `pcall`; errors are logged with the remote name and counted.

Malformed input adds 5 suspicion, a flood adds 3 per second of flooding; both feed the ladder in 7.3. Roblox throttles client-to-server remotes itself and delays the excess (**V6**); the token buckets are our own tighter limit.

### 14.3 Likely exploits

| Exploit | Defence |
|---|---|
| Speed hack | Windowed speed check, dash window opened only by an accepted `Ability` (7.1, 7.2) |
| Teleport to prey, or home to bank | Teleport check; bank needs a continuous path into the mouth (13.1) |
| Swimming through walls or into eel holes | Ray from last accepted pose each tick; volume check (7.2) |
| Bite aura: claim every prey nearby | Reach is computed from server poses; rate limit 12 claims a second; far claims add suspicion (8.9) |
| Eating players from a distance or across tiers | Server-side tier, safe-zone, protection and distance checks (10.2) |
| Editing mass, tier or Pearls on the client | Those values are never read from the client |
| Ignoring stun, slow or Shell's "cannot move" | `vAllowed` drops; ladder corrects (7.1) |
| Dashing with no cooldown | Cooldown tracked on the server; no window, no extra speed |
| Freezing or lag-switching to avoid a bite | The frozen pose stays biteable; catch-up travel is capped at 2 s (7.4) |
| Quitting to avoid being eaten | The creature stays in the water for 10 s and can be eaten; only then is the run suspended (12.5) |
| Rejoining to get the newcomer shield or the absorbed bite again | Both are profile fields, not session state (10.2, 12.2) |
| Parking in another player's cove or the Nursery mid-run | Coves admit visitors only at tier 1; the Nursery is closed to tier 3 and higher (7.2) |
| Replaying or forging a purchase | Purchases enter only through `ProcessReceipt`; `PurchaseId` list (12.6) |
| Opening the same save on two servers to duplicate specimens or Pearls | Session lock (12.4) |
| Changing the device clock for cove income | Server time only (13.3) |
| Remote spam or malformed buffers | Validation wrapper and rate limits (14.2) |
| Buying with Pearls twice in one frame | `EconomyService.spend` is synchronous and checks the balance before it changes anything |
| Bubble farming with alternate accounts | One per visitor per owner per day, 24 a day, account must have banked once |
| Leaderboard injection | Boards are written only by a public server, from banks of runs not marked `untrusted`. A private server never writes (12.7) |
| Seeing prey, Camo or Ink-hidden players through walls | Not preventable while the engine replicates roots. Prey beyond 600 studs is never sent. Accepted at MVP (section 20, R12) |
| Automated play for Pearls | Not a security matter at MVP; `playSeconds` and bank rate are logged for later review |

## 15. Performance budgets and plan

Every number in this section is a starting value **(tune)**. Roblox publishes no memory or frame budgets for phones (**U11**); these are ours.

### 15.1 Client budgets by graphics tier

There is **one** client budget table for the project, and chapter 15, section 3.0 owns it: the three graphics tiers, which device class starts on which tier, the frame-rate floors and the memory ceilings. The rows below are the ones the code reads as constants (`tune.quality.*`); they are copied from that table and must match it. Smooth, Balanced and Pretty are the names in the settings screen and equal the Low, Mid and High of earlier drafts.

| Budget | **Smooth** (Low) | **Balanced** (Mid) | **Pretty** (High) |
|---|---|---|---|
| Typical device | Phones with 4 GB of RAM or less (the reference low phone, chapter 15 test row 1, and older 2 to 3 GB phones), old laptops | Recent phones, tablets, handhelds, most laptops, older consoles | Gaming PCs, current consoles, flagship tablets |
| Frame rate target | 30 fps (33.3 ms) | 60 fps (16.7 ms) | 60 fps, or the player's cap |
| Our script time per frame | ≤ 6 ms | ≤ 4 ms | ≤ 3 ms |
| Client memory ceiling, total | 900 MB | 1,300 MB | 2,500 MB |
| Triangles in view | 150,000 | 300,000 | 600,000 |
| Draw calls | 250 | 400 | 700 |
| Prey drawn as meshes (pool size) | 80 | 150 | 250 |
| Prey mesh distance (the near band drawn as meshes) | 150 studs | 250 studs | 350 studs |
| Prey visible in total, with particle clusters and glints | 250 | 400 | 800 |
| Far prey particle emitters | 30 | 60 | 60 |
| Creature rigs fully animated | 8 | 16 | 24 |
| Skinned creatures drawn at LOD0 or LOD1 | 30 | 50 | 120 |
| Active particle emitters | 40 | 80 | 150 |
| Outlined objects (edible, dangerous) | 12 (8, 4) | 30 (20, 10) | 30 (20, 10) |

`QualityController` implements chapter 15, section 6 and adds no rule of its own: the starting tier by screen class, the 3-second start sample, one step down when the 10 s average is more than 5 fps under target, the memory guard, the cut order (15.6), and at [L] the step-up probe and the saved `lastGoodTier`. A player's fixed Graphics choice (`settings.input.<mode>.graphics`) turns the stepping off. It reports through `Telemetry`, and the session's result is logged as `perf_tier`. The tier changes GULP's own load only; scripts cannot read or set Roblox's own quality level.

Asset ceilings are owned by chapter 06, section 6.3 and are not repeated here beyond the largest: playable species 1,500 triangles juvenile and 3,500 adult; prey from 2 (`plankton`) to 900 (`tuna`), trait prey 300 to 700; `moray` and `barracuda` 2,000; `grouper` 3,500; `old_scar` 8,000. The platform cap is 20,000 triangles per mesh and 4 bone influences per vertex (**V23**). Textures: 256 for prey, 512 for creatures. The 1,024 textures are the list in chapter 06, section 14.2 and no others: `T_OldScar_Alb`, `T_EnvWreck_Alb` (the Tin Pickle), `T_Reef_NogginRock_Alb`, at most two effect flipbooks and the interface atlas sheets at [MVP], plus `T_WhaleFall_Alb` at [L]. The texture page contradicts itself on the maximum (**U7**); nothing above 1,024 is authored.

### 15.2 Server budgets

| Budget | Value |
|---|---|
| Heartbeat | ≥ 58 per second on average; the server-side sign of trouble is under 59 (**V20**) |
| Our script time per frame | ≤ 3 ms average, ≤ 6 ms peak |
| `PreyService` simulate (8.4, steps 1 to 5) | 2.0 ms per 100 ms tick, at the Frenzy count; interest and send are not included |
| `PreyService` interest and send | 0.25 ms per player per tick, 4 players per frame; a budget of its own, separate from the simulation's |
| `MovementValidator` | 0.4 ms per 50 ms tick (24 rays) |
| `PredatorService` including hazards | 0.3 ms per tick |
| `BiteService` | 0.05 ms per claim |
| Server memory | ≤ 2 GB (**U11**) |
| Instances in `Workspace` | ≤ 12,000 |

### 15.3 Network budgets per client

| Direction | Average | Peak |
|---|---|---|
| Received | ≤ 30 kB/s | ≤ 50 kB/s |
| Sent | ≤ 6 kB/s | ≤ 10 kB/s |

### 15.4 Place settings

Every row but the experience setting is set in the Rojo project file that builds the place (`world.project.json`; `ci.project.json` repeats the Workspace rows), never by hand in Studio: most are not scriptable (**V4**, **V29**), and the streaming properties cannot even be read by scripts (spike F6), so a value set by hand could neither be checked nor rebuilt. `tools/studio/check_place.luau` checks the scriptable ones through MCP; the rest are on the release checklist. The world place was first built by `rojo build world.project.json -o assets/place/gulp-world.rbxl`, which sets every row below except the experience setting; the spike found that Studio code cannot read the streaming properties, `AuthorityMode`, `SignalBehavior` or `PhysicsSteppingMethod`, nor write `TextChatService.ChatVersion` (which must be `TextChatService` for `DisplayBubble`), so `lune run tools/check_place_file` reads them from a saved copy.

| Property | Value | Note |
|---|---|---|
| `Workspace.StreamingEnabled` | true | |
| `Workspace.ModelStreamingBehavior` | Improved | Recommended (**V4**) |
| `Workspace.StreamingIntegrityMode` | PauseOutsideLoadedArea | Recommended (**V4**); behaviour with our character is S5 |
| `Workspace.StreamingMinRadius` | 128 **(tune)** | Default 64 |
| `Workspace.StreamingTargetRadius` | 512 **(tune)** | Default 1,024; underwater fog ends near 350 studs. One value for every device: streaming properties cannot be set per client or from scripts (**V4**), so weak devices pull the fog in instead (15.6) |
| `Workspace.StreamOutBehavior` | Opportunistic | Recommended (**V4**) |
| `Workspace.AuthorityMode` | Automatic | Not Server (6.4) |
| `Workspace.SignalBehavior` | Deferred | |
| `Workspace.PhysicsSteppingMethod` | Adaptive | |
| `Workspace.FallenPartsDestroyHeight` | −5000 | |
| `Workspace.Gravity` | 80 | Chapter 02's air gravity (02 §1.7, 6.5); only matters above the surface. The engine default is 196.2 |
| `Players.CharacterAutoLoads` | false | Also set in code |
| `VoiceChatService.EnableDefaultVoice` | false | |
| `StarterGui.ScreenOrientation` | LandscapeSensor | Phones are landscape only (canon 15). The client sets the same value on `PlayerGui` at start (chapter 15) |
| `TextChatService.ChatVersion` | TextChatService | A Rojo-built place defaults to legacy chat, and code cannot write this; `DisplayBubble` needs it (spike tech-a, S16) |
| Playable devices (experience setting) | Phone, Tablet, Computer on; Console and VR off | Console goes on in [P1] after the hardware checks of chapter 15 |
| `Workspace.Collision` model | `ModelStreamingMode = Persistent` | |

### 15.5 Profiling routine

Weekly, and before every release:

1. **Server soak.** Studio, 24 bots (`Dev/BotPlayers`), 10 minutes including one Feeding Frenzy. Read the MicroProfiler for our `debug.profilebegin` labels; record average and worst frame for each service against 15.2.
2. **Phone run.** The staging place on the owner's low-end phone, 10 minutes in the Sunlit Reef during a Frenzy. Developer Console: memory total, `LuaHeap`, `InstanceCount`, network received and sent (**V32**). Record frame rate from `Telemetry`.
3. **Leak check.** `LuaHeap` and `InstanceCount` at minute 1 and minute 10 of the same run; growth above 10% with a steady scene is a bug.
4. **Compare** with the tables above and write the numbers into `docs/perf-log.md` (one line per run). A budget missed twice in a row blocks the release.

### 15.6 First things to cut if a phone struggles

This is the cut order of chapter 15, section 3.0, which owns it. `QualityController` applies one step every 10 s while a device on Smooth stays under 25 fps, and each step is also a switch in live config:

1. Prey meshes drawn 80 → 50; the rest of the mid band become particles.
2. Fully animated rigs 8 → 4; others freeze their animation beyond 60 studs.
3. Particle emitters 40 → 20; far-prey glints off; marine snow off.
4. Outline shells on the 6 nearest objects only.
5. Cove specimens drawn as still meshes.
6. Zone view distance capped at 160 studs (the fog is pulled in). The streaming radius does not change: it cannot be set per device (**V4**, **V29**).
7. `PreyState` near band 150 → 110 studs, which also cuts decode work.
8. Bloom and colour correction off (shadows are already off on Smooth; document 06 owns the look, so this is the last resort).

Never cut on any device: edible and danger outline shells on the nearest 6 objects, threat arrows, and the bite, gulp, tier-up, ink and gull-shadow effects.

## 16. Testing

### 16.1 Unit tests, headless

- **Runner:** `src/shared/Util/TestKit.luau` provides `describe`, `it` and `expect` (`toBe`, `toEqual`, `toBeCloseTo`, `toThrow`) in about 120 lines of plain Luau. `tools/test/runner.luau` is the Lune front end: it finds `tests/unit/**/*.spec.luau`, runs them, prints failures and exits with code 1 on any failure.
- **Command:** `lune run tools/test/runner -- unit`. Target: under 5 s for the whole suite.
- **What must be covered before a module counts as done:** every function in `shared/Logic`; every codec (encode → decode equals input, plus length and bounds rejections); `Quantize` (error ≤ 1/32 stud); `Formation` (deterministic, members inside the formation radius); `SpatialGrid` (insert, move, remove, query against brute force); `TideClock` (every minute of an hour, slot edges, MVP fallback); `CoveIncome` (cap, backwards clock, rate change); `Migrations` (every fixture); `BiteRules` (the full tier and protection matrix from canon 5.2 and section 9 of the canon).

### 16.2 Simulation tests, headless

| Test | What it runs | Fails when |
|---|---|---|
| `tests/sim/economy.sim.luau` | 2,000 scripted players through 30 days using the data tables: bites per minute by tier, bank and death rates, cove income | Time to each tier is more than 25% off canon 5.1; any species unlock day is more than 30% off canon section 7; Pearls per hour grows without bound |
| `tests/sim/prey_soak.sim.luau` | `PreySim` plus the interest code for 10 simulated minutes with 24 scripted swimmers, one Frenzy. The Frenzy runs at the Frenzy count of 8.1 (about 2,710 members in 545 groups, trait prey included), and the soak must prove the byte and step budgets there, not only at the normal count | Live members leave 60% to 160% of target, except for 60 s after a target step (a Feeding Frenzy start or end, chapter 02, section 14.4: the target doubles at once and the surplus is kept at the end), when the check passes if the count is within the band of either the old or the new target; any group leaves its leash; bytes per player per second exceed 9,000 peak or 4,500 average; a packet exceeds 900 bytes; simulation time per tick exceeds 2.0 ms, or interest and send exceed 0.25 ms per player per tick (8.4, 15.2). Times are `os.clock` in Lune, a proxy; the 24-bot server soak of 15.5 confirms them in the engine |
| `tests/sim/movement_fuzz.sim.luau` | `SwimModel` driven by random honest input with injected jitter, 0 to 300 ms latency and 0.4 s stalls, checked by the validator's pure rules | Either of: any honest trace reaches suspicion 10, or a trace at 1.3 × speed is not flagged within 5 s (it passes when no honest trace reaches 10 and the 1.3 × trace is flagged within 5 s, 13 Sprint 8) |

Command: `lune run tools/test/runner -- sim`.

### 16.3 Engine tests

Specs under `src/server/Tests/` use the same `TestKit` and cover what needs the engine: remote wrappers, `WorldIndex` on the test arena, a full join with `ProfileStore.Mock`, a bite end to end against a bot, a bank, a gulp, a simulated receipt (granted once, repeated receipt not granted twice), a Call the Tide override. `Tests/RunAll.luau` returns a summary string.

- Locally through MCP: `execute_luau` with `datamodel_type = "Server"` during a play test, running `return game.ServerScriptService.Server.RunTests:Invoke()`. MCP code runs in its own Luau VM, where requiring `Tests/RunAll` directly would load fresh copies of every module rather than the running services, so `Main` creates the `RunTests` BindableFunction (only when the environment of `Config/Defaults` has dev cheats on, or is CI) and it runs `RunAll` inside the server's VM. Specs that need a player (the join and leave of `CreatureSpec`) use the play test's own player.
- In CI through Open Cloud Luau execution on the CI place. Physics does not step there (**V16**), so these specs call service functions directly and step simulations by hand. Luau execution also does not run the place's scripts: `Main` never starts, so the `RunTests` hook does not exist there and `Tests/RunAll` runs in a fresh VM where no service's `init()` has run; specs that need a service start it themselves (`_test.ensureInit`). Measured on GULP CI on 14 October 2026: 44 specs, all passing.

### 16.4 Play tests through the Studio MCP server

`tools/studio/smoke.luau` is the script an agent follows after any change to a client or server module:

1. `start_stop_play` (start); poll `get_studio_state` until the client datamodel exists.
2. Server `execute_luau`: one player has a slot, a profile and a creature whose network owner is that player.
3. `user_keyboard_input`: hold W for 2 s. Server `execute_luau`: the pose moved more than 30 studs and suspicion is 0.
4. Client `execute_luau`: `PreyRenderer` knows more than 10 groups; frame time average is at most 17 ms (the Mac is vsync-capped at 60 fps, so 16.7 ms is the floor, not a margin).
5. Server `execute_luau`: place a `krill` group in front of the creature. Wait 1 s. Mass is greater than 0.
6. Server `execute_luau`: `return game.ServerScriptService.Server.RunTests:Invoke()` (16.3); the summary's first line starts with `PASS`.
7. `get_console_output`: no line at error level.
8. `screen_capture` to disk, then `start_stop_play` (stop).

`character_navigation` is not used; it is assumed to need a Humanoid.

**Test method (spike F12).** Studio is brought to the front before any timed run: a background Studio window is throttled to 15 fps, which also slows anything driven from `RenderStepped` or `PreRender`. Frame rates measured on the Mac are vsync-capped at 60 fps, so they show a stall or a hitch but never headroom. Phone frame rates and phone budgets (15.1) come only from phones (chapter 15's device rows), never from the Mac or Studio's device emulation.

### 16.5 Multi-client routine

Run by the owner, weekly, with Blender closed:

1. **Local, two clients** (Studio's server-plus-clients test): bump at the same tier; a tier 3 eats a tier 2; a bite attempt inside the Nursery fails; one client banks while the other watches the cove sign change; repeat with Studio's network simulation at 150 ms.
2. **Staging, real devices:** phone and Mac in the staging place with 22 bots filling the server. Ten minutes: movement feel, bite rejects (the server's reject counter under 2% of claims), `guard_flag` count zero, frame rate and memory against 15.1.
3. **Soak:** leave the staging server running 30 minutes with bots; check the server's memory and Heartbeat.

Whether an agent can start a two-client test through MCP is not known (**U13**); until S15 answers it, step 1 is manual.

### 16.6 Continuous integration

`.github/workflows/ci.yml`, on every pull request and on `main`:

| Job | Commands | Runner |
|---|---|---|
| `lint` | `stylua --check src tests tools`; `selene src` | ubuntu-latest |
| `types` | `rojo sourcemap` then `luau-lsp analyze` (2.4) | ubuntu-latest |
| `gen` | `lune run tools/gen/content`; `git diff --exit-code src/shared/Data/Generated` | ubuntu-latest |
| `unit` | `lune run tools/test/runner -- unit` | ubuntu-latest |
| `sim` | `lune run tools/test/runner -- sim` | ubuntu-latest |
| `build` | `rojo build ci.project.json -o build/ci.rbxl`; upload as an artifact | ubuntu-latest |
| `engine` (on `main` only) | `lune run tools/cloud/publish_ci` then `lune run tools/cloud/run_engine_tests`: one Luau execution task that calls the `RunTests` hook of 16.3 (`Main` creates it in the CI environment) and requires `Tests/RunAll` itself only if the hook is not there yet; the summary's first line must start with `PASS` | ubuntu-latest, concurrency group of 1 |

Each job starts with `actions/checkout` and `CompeyDev/setup-rokit@v0.2.1`. The `engine` job needs the secret `ROBLOX_API_KEY` with `universe-places` write on the CI place and `universe.place.luau-execution-session:write` (**V15**, **V16**). Luau execution allows 5 task creations a minute per key owner and tasks of up to 5 minutes (**V16**); one task runs all engine specs.

## 17. Build and release

### 17.1 Environments

Four experiences, so data stores never mix (data stores belong to an experience).

| Environment | Experience | Who can join | Data | How it is updated | Purchases | Analytics | Dev cheats |
|---|---|---|---|---|---|---|---|
| Development | `GULP Dev` | Owner, in Studio | `ProfileStore.Mock` by default | Rojo live sync | On (Studio test purchases) | Off (Studio sends none, 10 §2.4) | On |
| CI | `GULP CI` | Nobody | Mock | `rojo build ci.project.json` + Open Cloud publish | Off | Off | Off |
| Staging | `GULP Staging` | Owner and invited testers, private | Real, disposable | Studio "Publish to Roblox As" from the dev place | On | On | Off |
| Production | `GULP` | Public | Real | Studio "Publish to Roblox As" from the dev place, after staging passes | On | On | Off |

`Config/Defaults.luau` holds one table per environment keyed by `game.GameId` (product IDs, pass IDs, analytics on or off, dev cheats on or off). An unknown `GameId` selects the development table with all purchases disabled, and with dev cheats on only in Studio (`RunService:IsStudio()`, where a place file has GameId 0), so a live experience missing from the list never exposes `server/Dev`.

### 17.2 Producing and publishing a build

The world place cannot be published from the command line with its art intact (**V15**), so a release is a short manual step in Studio around automated checks.

1. `main` is green in CI, including `engine`.
2. An agent bumps `Config/Version.luau`, writes the change list, and tags `vMAJOR.MINOR.PATCH`.
3. Owner: open the dev place in Studio, `rojo serve`, connect, confirm the Rojo plugin reports no pending differences.
4. Agent, through MCP: `tools/studio/check_place.luau` (place settings, required tagged volumes present, 24 cove mouths, 12 revive points, asset folders complete), then the smoke test (16.4).
5. Owner: **Publish to Roblox As** → Staging. Play on a phone for 10 minutes (16.5 step 2).
6. Owner: **Publish to Roblox As** → Production. In the Creator Dashboard, Restart Servers with "only servers with outdated versions" and a 10-minute delay so runs can finish (**V28**).
7. Save a local copy of the place to `assets/place/` (Git LFS).

Open Cloud publishing is used only for the CI place, which has no art: `POST https://apis.roblox.com/universes/v1/{universeId}/places/{placeId}/versions?versionType=Published` with `x-api-key` and `Content-Type: application/octet-stream` (**V15**).

### 17.3 Versioning

| Number | Where | Changes when |
|---|---|---|
| Game version `MAJOR.MINOR.PATCH` | `Config/Version.luau`, shown in settings, sent as an analytics custom field | Every release |
| Place version | `game.PlaceVersion`, assigned by Roblox | Every publish |
| Save schema `v` | `Migrations.SCHEMA_VERSION` | Only with a migration |
| Net protocol `NET_VERSION` | `Net/Remotes.luau`, sent in `WorldInfo` | Any packet layout change. A client with a different value is told to rejoin |

### 17.4 Feature flags and live configuration

`LiveConfig` (server) wraps Roblox experience configs through `ConfigService` (**V22**): values are edited in the Creator Dashboard, a publish reaches servers in about 15 s to 1 minute, and history can be restored. `ConfigService` is server-only, so `LiveConfig` forwards the keys the client needs through `State` under `config.*`. The client keys are exactly those under `flag.`, `kill.`, `live.`, `assist.` and `tune.quality.` (`LiveConfigRules.CLIENT_PREFIXES`); `tune.move.*`, `tune.bite.*`, `tune.prey.*` and `tune.econ.*` are server tolerances and never leave the server. A client key is sent at join when its value differs from the default (the client starts on the same `Config/Defaults`) and again whenever it changes. If `GetConfigAsync` fails, `LiveConfig` runs on the defaults and retries every 60 s **(tune)** until it succeeds (60 s derivation: a publish takes 15 s to 1 minute to reach servers, so retrying at that pace costs one minute at most against a fix the team is already waiting for, and one call a minute per server is far below any rate limit).

```lua
local snapshot = ConfigService:GetConfigAsync()          -- in pcall; on failure use Defaults
snapshot.UpdateAvailable:Connect(function() snapshot:Refresh() end)
local value = snapshot:GetValue("tune.bite.baseTolerance") -- nil → Defaults
```

| Key prefix | Type | Examples |
|---|---|---|
| `flag.*` | boolean | `flag.rewardedVideo`, `flag.globalBoards`, `flag.coveVisits`, `flag.reviveOffer`, `flag.tideEvents`, `flag.whaleFall`, `flag.textChat` (off; see 6.10) |
| `kill.*` | boolean | `kill.purchases`, `kill.pvp`, `kill.callTide`, `kill.banking`, `kill.saves` |
| `live.*` | string or number | `live.limitedTideId`, `live.limitedTideStart`, `live.limitedTideEnd`, `live.noticeTextKey`, `live.minPlaceVersion`, `live.shopDelaySeconds` (120) |
| `assist.*` | boolean | `assist.nudge`, `assist.dashSnap` [L] (chapter 15, section 4.3) |
| `tune.move.*` | number | speed tolerance, slack, suspicion thresholds |
| `tune.bite.*` | number | base tolerance, time window, rate |
| `tune.prey.*` | number | population targets, band distances, send thresholds |
| `tune.econ.*` | number | scraps rates, income cap hours, suspended-run lifetimes |
| `tune.quality.*` | JSON | the per-tier numbers of 15.1 and the cut steps of 15.6. Each key holds `{ Smooth, Balanced, Pretty }`; the prey and outline keys are `tune.quality.preyMeshes` (80, 150, 250), `tune.quality.preyMeshDistance` (150, 250, 350), `tune.quality.preyVisible` (250, 400, 800), `tune.quality.farPreyEmitters` (30, 60, 60), `tune.quality.particleEmitters` (40, 80, 150), `tune.quality.outlinesEdible` (8, 20, 20) and `tune.quality.outlinesDangerous` (4, 10, 10) |

Every key has a default in `Config/Defaults.luau`; a missing or wrongly typed value falls back to it and logs once. Content tables (species, prey, prices) are **not** live config; they change with a release so the documents stay true.

These are the final key names. Chapter 12, section 2.6 lists the same switches under proposed names; they map as follows: `purchases_enabled` is `kill.purchases` inverted, `saves_read_only` is `kill.saves`, `revive_offer_enabled` is `flag.reviveOffer`, `rewarded_video_enabled` is `flag.rewardedVideo`, `tide_events_enabled` is `flag.tideEvents`, `cove_visits_enabled` is `flag.coveVisits`, `leaderboards_enabled` is `flag.globalBoards`, and `limited_tide_id`, `limited_tide_start`, `limited_tide_end`, `notice_text_key`, `min_place_version` and `new_player_shop_delay_s` are the `live.*` keys above.

Experiments use the same service: `ConfigService:GetConfigForPlayerAsync(player)` returns the player's arm for a key, and `LiveConfig` copies it to `ab.<key>` in the profile at first exposure (chapter 10, section 8.1) and logs `ab_exposed`.

### 17.5 Rollback

| Problem | Action | Time |
|---|---|---|
| A feature misbehaves | Turn its `flag.*` or `kill.*` off | About 1 minute |
| A tolerance is wrong | Change `tune.*` | About 1 minute |
| The build is bad | Creator Dashboard → Places → Version History → Restore. Restoring does **not** publish (**V28**): open the restored place in Studio, publish, restart servers | 10 to 15 minutes |
| A save migration is bad | Never rolled back in bulk. The older server refuses newer profiles (12.3 step 4), so a code rollback cannot corrupt them. Fix forward with a new migration; single profiles can be read back by version with ProfileStore's `VersionQuery` (**V19**) | Hours |

Because of the last row, a release that contains a migration is published to staging for at least 24 hours first.

## 18. Localisation, policy and platform hooks

### 18.1 Text

- Every player-visible string has a key in `assets/loc/strings.csv`. `tools/gen/strings.luau` writes `Data/Generated/Strings.luau` (English) and the CSV is also the file uploaded as the cloud localisation table, so it uses the cloud table's columns (**V33**): the header row is `Key,Context,Example,Source`, with the English text in `Source` (the table's source language), our context note in `Context` and `Example` empty; translations [L] go in one more column per locale code (`es`, `pt`) on the same row. A row needs `Source`; no two rows share a `Key`, or a `Source` and `Context` pair. One upload changes at most 1,000 rows and the file stays under 2 MB (10,000 rows at most). The header case is copied from Roblox's page; before the first upload, download the cloud table once from Studio's Localization Tools and match its header row exactly.
- Client code calls `Loc.t(key, args)`. `Loc` gets a translator with `LocalizationService:GetTranslatorForPlayerAsync` inside `pcall`, calls `Translator:FormatByKey(key, args)`, and falls back to the English table on any failure (**V30**).
- Parameters use the documented forms `{1:int}` or `{Name}` (**V30**). No string is built by concatenation.
- Automatic text capture is off on our ScreenGuis; we translate by key only.
- Creature, trait, prey and event names are keys built from the canon ID with the prefixes of chapter 08, section 14, which owns every key (`species.minnow`, `trait.glow`, `prey.krill`, `event.frenzy`, `ability.rampage`). Canon IDs never appear on screen.
- Canon pillar 6 keeps text out of the core loop, so MVP ships English with the pipeline in place. Spanish and Portuguese are [L].
- Player names on cove signs and nameplates are display names from Roblox, shown as given.

### 18.2 PolicyService

`PlayerLifecycle` calls `PolicyService:GetPolicyInfoForPlayerAsync(player)` on the server at join, inside `pcall` (**V13**), and stores the result in memory. **If the call fails, the most restrictive value of every field is assumed.**

| Field | Use in GULP |
|---|---|
| `ArePaidRandomItemsRestricted` | No paid random items exist at launch (canon section 3). Any later one must check this |
| `IsPaidItemTradingAllowed` | Gates specimen trading [P2] |
| `AreAdsAllowed` | Must be true before any ad surface is shown |
| `IsEligibleToPurchaseSubscription` | Not used; there is no subscription |
| `IsSubjectToChinaPolicies` | If true: no Robux prompts and no ads are shown |
| `IsContentSharingAllowed` | Gates any future share-a-screenshot button |

### 18.3 Ads and age

- Rewarded video [L] is offered only when the client's `AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)` says an ad is available, checked just before the button is shown; the server then calls `AdService:ShowRewardedVideoAdAsync(player, reward)` with a reward made by `CreateAdRewardFromDevProductId`, and the grant arrives through `ProcessReceipt` (**V21**). The button is hidden, not disabled, for anyone ineligible.
- The experience itself must qualify: public, questionnaire approved, at least 2,000 unique visitors a month, publisher ID-verified (**V21**). Until then `flag.rewardedVideo` is off and every flow works without it.
- Roblox's rules for rewards: a developer product that is also sold for Robux, not randomised, not inflating the economy, with a clear disclosure before the ad (**V21**). The canon's three rewards meet them: a free Revive (`prod_revive`), a Cove Boost (`prod_cove_boost`, 2 hours of cove income, once a day) and a Goal Reroll (`prod_goal_reroll`), through the placements `ad_revive`, `ad_cove_boost` and `ad_goal_reroll`. Each is a visible product on sale for Robux; there are no hidden products and no "double a claim" reward.
- The rule that rewarded video is shown only to users 13 and older came from a search result, not a fetched page (**U14**). We rely on `GetAdAvailabilityNowAsync` to apply it.
- Voice chat is off. Roblox text chat is off in the MVP and reviewed for launch (canon 14). If the review turns it on, it sends through `TextChatService` channels so Roblox's own filtering and age rules apply, and it is never shown on a TV.

### 18.4 Paid items

- All Robux prompts go through `ShopService`, which checks `canSell(player)`, `kill.purchases` and the policy table before calling `MarketplaceService:PromptProductPurchase` or `PromptGamePassPurchase`.
- Every paid item states exactly what it gives before the prompt. Nothing paid is random.
- Private servers [L]: `game.PrivateServerId ~= ""` marks one. Tides run on the same clock and everything else works as on a public server, with two things left out (chapter 02, section 16.6): banks never count toward the global leaderboards, whatever the player count, and Bubbles are not added to the lifetime count (12.7). There is no minimum number of players.
- Private server owner settings [L] (chapter 02, section 16.6): the owner (`game.PrivateServerOwnerId`) can switch on "Friendly reef" and switch "Wild creatures" off. Both are server-wide, held in server memory, start at the public rules on every new server, and are changed with `SettingsSet`, which accepts these two keys only from the owner on a private server. With Friendly reef on, `BiteService` rejects every player-versus-player claim with reason `state` before rule 1 of 10.2, so players only bump; prey, predators and wild creatures are unchanged. With Wild creatures off, the count in 9.3 is 0. Chapter 08 has no screen for the two switches yet.

## 19. Build order

Sizes: **S** is under about 300 lines and one agent session; **M** is 300 to 800 lines; **L** is more, or needs tuning on a device. An agent takes one row; rows with no unmet dependency can run in parallel.

| ID | Module | Depends on | Size | Scope |
|---|---|---|---|---|
| B00 | Spike place, items S1 to S18 | — | L | MVP |
| B01 | Repo scaffold, toolchain files, `tools/check`, CI workflow | — | S | MVP |
| B02 | `TestKit` and the Lune runner | B01 | S | MVP |
| B03 | `Types`, `Config`, `Util` (Signal, Ring, TokenBucket, Rng, Log, Assert) | B01 | S | MVP |
| B04 | Content generator, `Data/Generated`, `Data/Index` | B03 | M | MVP |
| B05 | `Net`: remote table, server and client wrappers, rate limiter | B03 | M | MVP |
| B06 | `Quantize` and all codecs | B02, B03 | M | MVP |
| B07 | `Logic`: TierMath, BiteRules, BankMath, TraitRules, CoveIncome, TideClock, GoalRules | B02, B04 | M | MVP |
| B08 | `SwimModel` | B04 | M | MVP |
| B09 | `WorldIndex`, `CollisionGroups`, volume authoring notes | B03 | M | MVP |
| B10 | `PlayerLifecycle`, `CreatureService` (build, assign, own, spawn) | B05, B09 | M | MVP |
| B11 | `InputController` (drag to swim, mouse and keyboard, input mode detection), `MovementController` | B08, B10 | L | MVP |
| B12 | `CameraController` | B10 | M | MVP |
| B13 | `CreatureController` and `CreatureRig` (smoothing, smooth scale, mesh swap, crest, nameplates, outline shells) | B10 | L | MVP |
| B14 | `MovementValidator` | B08, B10 | L | MVP |
| B15 | `PreySim`, `Formation`, `SpatialGrid` | B04, B06 | L | MVP |
| B16 | `PreyService` (spawner, interest, send) | B05, B09, B15 | L | MVP |
| B17 | `PreyRenderer` (pools, dead reckoning, particles, local bite detection) | B06, B13, B15 | L | MVP |
| B18 | `BiteService`, prey bites | B14, B16 | M | MVP |
| B19 | `RunLoopService` (bank, gulp, scraps, revive offer, suspend and resume), `TraitService` | B18 | M | MVP |
| B20 | `DataService` (ProfileStore, schema, migrations), `StateStore` | B05, B07 | M | MVP |
| B21 | `EconomyService`, `Analytics` wrapper | B20 | S | MVP |
| B22 | `CoveService` (slots, specimens, income, `CoveView`) | B09, B21 | M | MVP |
| B23 | `UI/Kit` and Hud (mass, tier, traits, dash and ability buttons, bank prompt) | B11, B20 | L | MVP |
| B24 | `PredatorSim`, `PredatorService`, `PredatorController`, hazards | B14, B16 | L | MVP |
| B25 | `BiteService`, player bites and protections, including the newcomer shield and the absorbed first bite; eating a Barracuda (`op = 3`) | B18, B24 | M | MVP |
| B26 | `TideService`, `TideController` | B07, B16 | S | MVP |
| B27 | `ShopService` (Pearl purchases, `ProcessReceipt`, passes, two-minute rule) | B21 | M | MVP |
| B28 | `GoalsService`, `CodexService` | B20 | M | MVP |
| B29 | `LeaderboardService`, server board | B10 | S | MVP |
| B30 | `AudioController` | B13 | M | MVP |
| B31 | `TutorialDirector` (client), `TutorialService` (server) and the onboarding funnel | B19, B23 | M | MVP |
| B32 | Species abilities: Dart, Puff, Slip | B11, B14, B25 | M | MVP |
| B33 | `LiveConfig`, flags, `Loc` | B05 | S | MVP |
| B34 | `BotPlayers`, soak simulations, `QualityController` (screen class, three tiers, step down, cut order), first performance pass | B14, B16 | M | MVP |
| B35 | Screens: shop, cove, Codex, goals, settings | B22, B23, B27, B28 | L | MVP |
| B36 | Global leaderboards, cove visits and Bubbles, login streak, Reef Rank | B22, B29 | M | L |
| B37 | Rewarded video, remaining passes and products (Tide Watcher, Keen Nose, Shark Pup, Trait Lock, Call the Tide, Cove Boost, Goal Reroll, Starter Pack, patterns, Robux decorations), private servers | B27 | M | L |
| B38 | Sea Turtle, Squid, Shark Pup abilities (Shell, Jet, Rampage); Spark, Camo, Ember, Bonefed | B32 | M | L |
| B39 | Grouper (including eating one), anemone, vents, Whale Fall | B24, B26 | M | L |
| B40 | Text chat review for launch; a `TextChatService` panel only if the review says yes | B23 | S | L |
| B41 | Gamepad, the two-thumb phone scheme, the left-handed layout; the step-up probe and `lastGoodTier` | B11, B34 | M | L |
| B42 | `EmoteService` and quick emotes; wild creatures | B24, B25 | M | L |

Milestones on the critical path:

| Milestone | Rows | Proves |
|---|---|---|
| First swim | B01 → B03 → B04 → B08 → B10 → B11, B12, B13 | Pillar 6, feel on a phone |
| First bite | B06, B15 → B16 → B17 → B18 | Pillar 1, the prey pipeline |
| First bank | B19 → B20 → B21 → B22 | Pillar 3 and 4, saves |
| First death | B14, B24, B25 | Danger, validation |
| Soft-launch candidate | B23, B26 to B35 | MVP contents of canon section 15 |

## 20. Technical risks

| # | Risk | Mitigation | Fallback |
|---|---|---|---|
| R1 | A character with no Humanoid breaks core scripts or streaming (**U1**) | Spike S1, S5, S9, S10 in week one | Keep a Humanoid in the model with its state machine and name display switched off, and still drive the root ourselves |
| R2 | Client-owned movement is exploited faster than validation is tuned | Validator from day one; `guard_flag` analytics; tolerances in live config | Move to Server Authority. `SwimModel` is already a pure step function that can be bound to the fixed simulation (**V20**); S12 tells us in week one whether that path is open. Before switching: `SetNetworkOwner` throws under it and string attributes are capped at 50 characters, so every ownership call and long-string attribute is reviewed first (6.4, F24) |
| R3 | Low-end phones miss 30 fps | Budgets and pools from the start; weekly phone run | The ordered cuts in 15.6 |
| R4 | Unreliable packets are dropped or throttled more than expected (**U2**) | Dead reckoning, keyframes every 2 s, reliable eaten events | Halve the send rate, shrink the bands, raise the thresholds |
| R5 | Honest bites are rejected often enough to feel bad | Count rejects by reason on the server and write distances to the server log (no per-bite analytics event); target under 2%; tolerances in live config | Server-side bite detection for the near band (the server sweeps mouth spheres against group members at 20 Hz), making the client claim only a hint |
| R6 | Data store outage or ProfileStore critical state | No play without a profile; retries; purchases wait for a confirmed save | `kill.banking` pauses new specimens; Pearls from runs are held in memory and granted when saving recovers |
| R7 | Streaming pauses or pops with a fast custom character | Persistent collision shell; grace while paused; radii tuned in S5 | Larger radii, or streaming off (the map is 2,048 studs and built from instanced kits) |
| R8 | A Studio, Rojo or MCP update breaks the agent loop | Tools pinned; the headless gate does not need Studio | Studio Script Sync for files; manual play tests for a week |
| R9 | 16 GB is not enough for Studio plus tests plus Blender | Rules in 2.5 | Multi-client tests move to staging on real devices |
| R10 | The world place cannot be published by CI (**V15**) | Accepted: manual publish with an agent-run checklist | None needed |
| R11 | Rewarded video is unavailable (eligibility, age, region) | No flow depends on it; `flag.rewardedVideo` | Ship without it |
| R12 | Position cheats: seeing prey, Camo or Ink-hidden players | Prey beyond 600 studs never sent | [P1]: stop replicating a hidden creature's root to others by making the server own a decoy; needs its own spike |
| R13 | Analytics limits: 100 custom event names, 10 funnels, 8,000 custom-field combinations (**V11**) | One enum module lists every event; custom fields are low-cardinality only | Drop the least useful events |
| R14 | Lune and Roblox Luau differ, so a test passes headless and fails in the engine | The same specs also run in CI through Luau execution | Run pure-logic specs in the engine only |
| R15 | Agents drift from the architecture | The dependency check in `tools/check`; one module per task; this chapter as the brief | Sonnet review of the diff against section 5 before merge |
| R16 | Roblox changes a limit or deprecates an API we rely on | Section 21 lists every dependency with its source; re-fetch before each milestone | Per item |
| R17 | A bad migration damages saves | Fixtures and tests for every version; 24 hours on staging; old servers refuse newer data | Fix forward; restore single profiles by version |

## 21. Platform facts: verified and unverified

Checked on 13 October 2026. Pages on `create.roblox.com` were fetched as `/docs/en-us/<path>.md`.

### 21.1 Verified

| Ref | Fact | Source |
|---|---|---|
| V1 | `Player.Character` is a read-write `Model` property; `CharacterAdded` fires shortly after `Character` is set or `LoadCharacterAsync` is called; `GetNetworkPing` returns round-trip seconds; players idle 20 minutes are disconnected | [Player](https://create.roblox.com/docs/reference/engine/classes/Player) |
| V2 | `Players.CharacterAutoLoads` (boolean); `LoadCharacter` deprecated, `LoadCharacterAsync` current; `PlayerRemoving(player, reason)`; `BanAsync`, `UnbanAsync` | [Players](https://create.roblox.com/docs/reference/engine/classes/Players) |
| V3 | `Player.ReplicationFocus` is set on the server only, defaults to the character's `PrimaryPart`, and does not change network ownership; `AddReplicationFocus` exists | [Player](https://create.roblox.com/docs/reference/engine/classes/Player), [Streaming](https://create.roblox.com/docs/workspace/streaming) |
| V4 | Streaming properties are set in Studio, not scripts. Defaults: min radius 64, target radius 1,024. Recommended: `Improved`, `Opportunistic`, `PauseOutsideLoadedArea`. Model modes: Nonatomic, Atomic, Persistent, PersistentPerPlayer; Persistent is for rare cases. Client-created instances do not stream out. `Player.GameplayPaused` replicates to the server | [Streaming](https://create.roblox.com/docs/workspace/streaming) |
| V5 | `BasePart:SetNetworkOwner`, `SetNetworkOwnershipAuto`; anchored parts are always server-owned; Roblox cannot verify physics on client-owned parts; `Touched` can be spoofed by the owner | [Network ownership](https://create.roblox.com/docs/physics/network-ownership) |
| V6 | `UnreliableRemoteEvent`: no delivery or order guarantee; payloads over 1,000 bytes risk being dropped. `RemoteEvent`: reliable, ordered, including across different RemoteEvents; client-to-server is rate limited and the excess delayed (no numbers given) | [Remote events](https://create.roblox.com/docs/scripting/events/remote), [UnreliableRemoteEvent](https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent) |
| V7 | `buffer`: `create`, `len`, `copy`, `fill`, `fromstring`, `tostring`, `readstring`, `writestring`, `readbits`, `writebits`, and `read`/`write` for `i8 u8 i16 u16 i32 u32 f32 f64` | [buffer](https://create.roblox.com/docs/reference/engine/libraries/buffer) |
| V8 | Data stores: per-server and experience-wide formulas as used in 12.8; `UpdateAsync` uses read and write budget; 4 MB per key; 25 MB/min read and 4 MB/min write per key; names and keys 50 characters; queues of 30; storage 500 MB + 1 MB per lifetime user; `GetSortedAsync` page size up to 100; ordered values are integers with no versioning; advice to use few stores, one key per player, `UpdateAsync` for dependent writes | [Limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits), [OrderedDataStore](https://create.roblox.com/docs/reference/engine/classes/OrderedDataStore), [Best practices](https://create.roblox.com/docs/cloud-services/data-stores/best-practices) |
| V9 | Memory stores: 64 KB + 1.2 KB per user; 1,000 + 120 per concurrent user request units a minute; 32 KB per value; 45-day maximum expiry. Not used at launch | [Memory stores](https://create.roblox.com/docs/cloud-services/memory-stores) |
| V10 | `MessagingService`: 1 kB messages; 600 + 240 × players sent per server per minute; 20 + 8 × players subscriptions per server; best effort | [MessagingService](https://create.roblox.com/docs/reference/engine/classes/MessagingService) |
| V11 | `AnalyticsService`: `LogOnboardingFunnelStepEvent`, `LogFunnelStepEvent`, `LogEconomyEvent`, `LogProgressionEvent`, `LogCustomEvent`; 100 custom events; 10 funnels with steps 1 to 100; 5 currencies, 20 transaction types, 100 SKUs; 3 custom fields with 8,000 combinations; server only, published experiences only | [AnalyticsService](https://create.roblox.com/docs/reference/engine/classes/AnalyticsService), [Custom](https://create.roblox.com/docs/production/analytics/custom-events), [Funnel](https://create.roblox.com/docs/production/analytics/funnel-events), [Economy](https://create.roblox.com/docs/production/analytics/economy-events) |
| V12 | `ProcessReceipt`: fields `PurchaseId`, `PlayerId`, `ProductId`, `PlaceIdWherePurchased`, `CurrencySpent`, `CurrencyType`, `ProductPurchaseChannel`; returns `PurchaseGranted` or `NotProcessedYet`; called again on rejoin or the next purchase; may yield; set once. Recommended sequence for session-locked data. `UserOwnsGamePassAsync` is cached; `PromptGamePassPurchaseFinished` is handled on the server | [MarketplaceService](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService), [Purchasing with player data](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing) |
| V13 | `PolicyService:GetPolicyInfoForPlayerAsync` fields as listed in 18.2; server may call for any player; must be in `pcall` | [PolicyService](https://create.roblox.com/docs/reference/engine/classes/PolicyService) |
| V14 | `StarterGui:SetCoreGuiEnabled`; `Enum.CoreGuiType` values; `TextChatService:DisplayBubble` is client-side | [StarterGui](https://create.roblox.com/docs/reference/engine/classes/StarterGui), [Bubble chat](https://create.roblox.com/docs/chat/bubble-chat) |
| V15 | Open Cloud place publishing endpoint, headers and `versionNumber` response; it does not update `EditableImage`, `EditableMesh`, `PartOperation`, `SurfaceAppearance` or `BaseWrap` | [Place publishing](https://create.roblox.com/docs/cloud/guides/usage-place-publishing) |
| V16 | Open Cloud Luau execution: tasks up to 5 minutes; 10 concurrent per place; 5 creations a minute per key owner; no physics stepping; scripts do not auto-run; scopes `universe.place.luau-execution-session:read` and `:write` | [Luau execution](https://create.roblox.com/docs/cloud/reference/features/luau-execution) |
| V17 | Studio MCP server: how to enable; macOS binary path (also present on this Mac); tool names used in this chapter; `studio_id` on every call; search caps 10 and 50 | [Studio MCP](https://create.roblox.com/docs/studio/mcp) |
| V18 | Latest releases: Rojo 7.7.1 (2 Oct 2026), luau-lsp 1.70.1 (27 Sep 2026), Selene 0.32.0 (1 Oct 2026), StyLua 2.6.0 (10 Oct 2026), Lune 0.11.0 (11 Oct 2026), Rokit 1.2.0 (30 Sep 2025), Wally 0.3.2 (5 Jun 2023), wally-package-types 1.7.0 (24 Sep 2026); `setup-rokit` v0.2.1 | GitHub releases API for [rojo](https://github.com/rojo-rbx/rojo/releases), [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp/releases), [selene](https://github.com/Kampfkarren/selene/releases), [StyLua](https://github.com/JohnnyMorganz/StyLua/releases), [lune](https://github.com/lune-org/lune/releases), [rokit](https://github.com/rojo-rbx/rokit), [wally](https://github.com/UpliftGames/wally/releases), [setup-rokit](https://github.com/CompeyDev/setup-rokit) |
| V19 | ProfileStore API (`New`, `StartSessionAsync`, `Mock`, `Reconcile`, `AddUserId`, `Save`, `EndSession`, `OnSessionEnd`, `OnAfterSave`, `LastSavedData`, `VersionQuery`); constants `AUTO_SAVE_PERIOD` 300, `SESSION_STEAL` 40, `ASSUME_DEAD` 630, `START_SESSION_TIMEOUT` 120; saves with `UpdateAsync`; uses `MessagingService` | [ProfileStore API](https://madstudioroblox.github.io/ProfileStore/api/), [source](https://github.com/MadStudioRoblox/ProfileStore) |
| V20 | Server Authority: `Workspace.AuthorityMode = Server`, needs Next Generation Replication, the Input Action System, deferred signals, fixed simulation and streaming; `RunService:BindToSimulation`, `SetPredictionMode`; server step rate below 59 degrades play | [Server authority](https://create.roblox.com/docs/projects/server-authority), [Techniques](https://create.roblox.com/docs/projects/server-authority/techniques) |
| V21 | `AdService`: `GetAdAvailabilityNowAsync` (client), `CreateAdRewardFromDevProductId`, `ShowRewardedVideoAdAsync` (server); reward through `ProcessReceipt` with channel `AdReward`; eligibility and reward rules | [AdService](https://create.roblox.com/docs/reference/engine/classes/AdService), [Rewarded video ads](https://create.roblox.com/docs/production/promotion/rewarded-video-ads) |
| V22 | `ConfigService` is server-only: `GetConfigAsync`, `GetConfigForPlayerAsync`; snapshot `GetValue`, `Refresh`, `UpdateAvailable`, `GetValueChangedSignal`; up to 1,000 configs; publish reaches servers in about 15 s to 1 minute; history and restore | [ConfigService](https://create.roblox.com/docs/reference/engine/classes/ConfigService), [Experience configs](https://create.roblox.com/docs/production/configs) |
| V23 | 20,000 triangles per mesh; 4 influences per vertex (from the project's earlier research note) | [Modeling specifications](https://create.roblox.com/docs/art/modeling/specifications) |
| V24 | `PhysicsService:RegisterCollisionGroup`, `CollisionGroupSetCollidable`; 32 groups; `BasePart.CollisionGroup`; `CanCollide`, `CanTouch` | [PhysicsService](https://create.roblox.com/docs/reference/engine/classes/PhysicsService), [Collisions](https://create.roblox.com/docs/workspace/collisions) |
| V25 | `WorldRoot:Raycast`, `Spherecast`, `BulkMoveTo` with `Enum.BulkMoveMode.FireCFrameChanged` | [WorldRoot](https://create.roblox.com/docs/reference/engine/classes/WorldRoot) |
| V26 | `RunService` events `PreRender` (client), `PreAnimation`, `PreSimulation`, `PostSimulation`, `Heartbeat`; `RenderStepped` and `Stepped` deprecated | [RunService](https://create.roblox.com/docs/reference/engine/classes/RunService) |
| V27 | `Model:ScaleTo`, `GetScale`, `PivotTo`, `PrimaryPart`, `ModelStreamingMode` | [Model](https://create.roblox.com/docs/reference/engine/classes/Model) |
| V28 | Restart Servers options (outdated only, delay of 1 to 60 minutes); Version History restore does not publish | [Update games](https://create.roblox.com/docs/projects/update-games), [Version history](https://create.roblox.com/docs/projects/version-history) |
| V29 | `Workspace:GetServerTimeNow()` is a Unix timestamp, monotonic, the client's estimate of server time; gravity default 196.2; streaming, authority and stepping properties are not scriptable | [Workspace](https://create.roblox.com/docs/reference/engine/classes/Workspace) |
| V30 | `LocalizationService:GetTranslatorForPlayerAsync`, `Translator:FormatByKey`, parameter formats | [Localize with scripting](https://create.roblox.com/docs/production/localization/localize-with-scripting) |
| V31 | Voice: `VoiceChatService.EnableDefaultVoice`; for verified users 13 and over. ProximityPrompt line of sight is measured from the camera | [Voice chat](https://create.roblox.com/docs/chat/voice-chat), [Proximity prompts](https://create.roblox.com/docs/ui/proximity-prompts) |
| V32 | `CameraType.Scriptable`; mover constraints replace body movers; `ReplicatedFirst:RemoveDefaultLoadingScreen`; Script Sync file naming; performance guidance (identical meshes are instanced, adaptive stepping, Developer Console counters, `debug.profilebegin`) | [Camera](https://create.roblox.com/docs/workspace/camera), [Mover constraints](https://create.roblox.com/docs/physics/mover-constraints), [ReplicatedFirst](https://create.roblox.com/docs/reference/engine/classes/ReplicatedFirst), [Script Sync](https://create.roblox.com/docs/scripting/sync), [Improve performance](https://create.roblox.com/docs/performance-optimization/improve) |
| V33 | The cloud localisation table's CSV: columns `Key`, `Context`, `Example`, `Source` (only `Source` must be filled), translations under a column named by locale code on the source row; at most 10,000 entries, a 2 MB file and 1,000 changed rows per upload; a source row removed from the file is not deleted. Read on 14 October 2026 through an automated fetch-and-summarise tool; the pages give no literal header line, so the header case is taken from the column names shown | [Add source content](https://create.roblox.com/docs/production/localization/add-source-content), [Add translations](https://create.roblox.com/docs/production/localization/add-translations), [Manually edit](https://create.roblox.com/docs/production/localization/manual-translations) |

### 21.2 Not verified

| Ref | Open question | How it gets settled |
|---|---|---|
| U1 | A `Player.Character` model with no Humanoid works with no core-script errors; a stub `PlayerModule` stops default controls. The official page describes Character as containing a Humanoid and does not say one is required. Only forum sources say it works | S1, S9; **Mac half settled in Sprint 0** (`docs/spike-report.md`): no core-script errors in 10/10 joins, the stub stops default controls. Phone open |
| U2 | `buffer` values as remote arguments, their size on the wire, and how much the engine's own creature replication costs | S7, S6; **partly settled in Sprint 0**: buffers arrive intact, about 930–980 bytes on the wire per 900-byte payload, and 999 bytes or more are dropped silently. Engine replication cost open |
| U3 | A server-side `CFrame` write on a client-owned part moves it on the owner | S4; **settled in Sprint 0** (Mac): it moves, within 0.27 s at 200 ms lag |
| U4 | Server Authority with a non-Humanoid custom controller, and its release status on the official page (the DevForum announcement is titled "Full Release"; the docs page states no status) | S12; S12 failed inconclusively in Sprint 0, still open |
| U5 | Character Controller Library without a Humanoid | Not used |
| U6 | Chat bubbles on a non-Humanoid model; voice and ProximityPrompt behaviour without a Humanoid | S16; voice and prompts not used; **bubbles settled in Sprint 0**: they draw with `ChatVersion = TextChatService`, not under legacy chat |
| U7 | Maximum texture size: the specification page says both 4,096 and 1,024 | Author at 1,024 or below |
| U8 | Any Open Cloud way to publish a place with `SurfaceAppearance` intact, or to download a place | Manual publish |
| U9 | Luau execution concurrency: the reference says 10 per place, Roblox's demo repository says 2 per universe | S17; CI uses a concurrency group of 1 |
| U10 | Relative string requires resolve the same way in Roblox, Lune and luau-lsp | S11; **settled in Sprint 0**: they do |
| U11 | `BindToClose` time limit, server memory ceiling, and the memory at which phones close the client. No official numbers found | Measure in soak and phone runs |
| U12 | Exact client-to-server remote throttle | Our own limits are tighter |
| U13 | Whether MCP can start a multi-client test; whether the Rojo plugin reconnects without a click | S15; **multi-client half settled in Sprint 0**: yes, through `StudioTestService:ExecuteMultiplayerTestAsync`, not `start_stop_play`. Rojo reconnect open |
| U14 | The 13-and-over rule for rewarded video (search result only); the full `AdAvailabilityResult` list | Re-fetch before B37 |
| U15 | Studio and Blender memory use on this Mac | Measure in week one; **settled in Sprint 0**: Studio 3.1 GB idle, 3.6–3.9 GB in a play test, about 9.3 GB with a two-client test (physical footprint); Blender under 0.4 GB |
| U16 | StyLua and Selene config keys (from memory, not re-fetched); whether `luau-lsp analyze` loads Roblox definitions unaided; Rojo's default port | First run of `tools/check`; **luau-lsp half settled in Sprint 0**: it needs `--definitions` |
| U17 | Whether `rojo build` can write non-scriptable Workspace properties into the CI place | B01 |
| U18 | Two skinned MeshParts on one skeleton; `PauseOutsideLoadedArea` with a non-Humanoid character | S8, S5; **settled in Sprint 0** (Mac): both work; the pause freezes the root without anchoring it |
| U19 | Which core interface elements cannot be removed (the Roblox menu button is expected) | S10; Mac Studio shows no menu button, but `TopbarInset` still reserves 120 × 58 px; real client open |
| U20 | `MarketplaceService:BindReceiptHandler` behaviour; how long an unprocessed purchase is held | Not used; re-fetch before B27 |
| U21 | Wally registry package names and versions | None used |
| U22 | `MemoryStoreService` getter names | Not used |
| U23 | Clock skew between Roblox servers | Harmless by design (11.1, 13.3) |
| U24 | The Creator Dashboard's error reports show live server `warn` and `error` lines, so error spikes are visible without an analytics event (4.6) | Read the dashboard after the first staging publish; if it does not, chapter 10 adds a custom event for the counts (39 names spare) |

## 22. Proposed canon changes

The chapter above uses the canon as written. The canon has since adopted the earlier proposals on rewarded video rewards, the :45 slot, leaving mid-run, Call the Tide timing, Server Authority, text chat and the sea surface, so they are no longer listed. These remain open suggestions for `01-game-canon.md`.

1. **Untrusted runs.** Suggest a glossary line for a run the server has flagged (7.3 level 3): it banks Pearls but yields no specimen above tier 4 and does not count for leaderboards.
2. **Server shutdown mid-run (canon 5.5).** The canon covers a player's disconnect but not a server closing. Suggest one sentence matching chapter 02, section 16.5 and section 12.5 here: a run cut off by a server shutdown is suspended for 15 minutes, and if it is not resumed it pays its full bank value in Pearls with no specimen.

