# 07 · Asset list

This file lists every asset GULP needs that is not an interface image: 3D models, rigs, textures, animations, visual effects, lighting presets, sounds, music and the 3D scenes behind the store page. **If an asset is not on this list, it does not get built.** To add one, add a row here first.

Who owns what:

- **Document 01 (canon)** owns names, IDs and scope tags. It gives this chapter the asset naming rules (section 1.2).
- **Document 03** owns appearance briefs, landmark names and places, patterns and decorations. Rows here use its names and IDs.
- **Document 05** owns prices and how many things are for sale.
- **Document 06** owns the art style, the build methods and every triangle, bone and texture budget. Budgets here are copied from it or set in its spirit; where they differ, 06 wins.
- **Document 08** owns the interface and lists every interface image and icon (`UI_…`). None are listed here. Interface *sounds* are listed here, under the names 08 calls.
- **Document 11** owns the finished store images and video. This file lists only the posed 3D scenes behind them.

This file follows the canon (document 01) as it stood after the reconciliation of 13 October 2026. Where another document still differs from this list, section 17 says which reading this list follows.

## 1. How to read this list

### 1.1 Columns

| Column | Meaning |
|---|---|
| **Asset** | The file name without extension. A name in brackets is either a task that takes hours but produces no named file, such as *(assembly)* or *(check)*, or a *(bundle)* of files that get their names when the work is scheduled. A name ending in `_*` or listing several suffixes covers several files, and `<trait prey>` stands for each trait prey in turn. |
| **Tag** | Scope tag from canon section 15: [MVP] soft launch, [L] public launch, [P1] first quarter after launch (weeks 1 to 12), [P2] later. |
| **Description** | What it is and what makes it different from its neighbours. |
| **Qty** | Only in some tables. Number of variants or files the row covers. The hours are for all of them. |
| **Size / budget** | Triangles, bones, texture size, clip length in frames at 30 a second, particle count or audio length. |
| **Depends on** | What must exist first, or what the asset uses. |
| **Hours** | Work hours for one artist using scripted Blender, first pass, including export. |
| **Status** | See 1.5. Every row starts as `not started`. |

**Every number in the Size / budget, Length and Hours columns is a first guess, which is why those column headers say (tune).** Hours do not include review loops; section 14 adds an allowance for those.

### 1.2 Naming

Canon section 16 gives the prefixes, the mesh categories and the mesh suffixes, and makes this chapter the owner of the full asset naming rules. This section is the complete statement of those rules. Every row in this list obeys it, and where another document still shows a different name, the name here wins (section 17.3 lists them). Interface images (`UI_…`) are named by document 08 and are not covered here.

| Kind | Pattern | Examples |
|---|---|---|
| Mesh | `M_<Category>_<Name>[_Juv or _Adult][_<Form>][_LOD1 or _LOD2][_Shell or _ShellThick]` | `M_Species_Minnow_Juv`, `M_Species_Puffer_Adult_Puffed`, `M_Species_Minnow_Adult_LOD1`, `M_Prey_Krill_Shell`, `M_Pred_OldScar_LOD2_ShellThick`, `M_Env_Reef_Coral_Brain_01`, `M_Trait_Plated_Plate`, `M_Cove_Mouth`, `M_Prop_Pearl_01` |
| Rig (skeleton) | `RIG_<Name>` | `RIG_Fish`, `RIG_OldScar`, `RIG_PreyBlob4` |
| Texture | `T_<Name>_<Map>` | `T_Minnow_Adult_Alb`, `T_Trait_Glow_Fish_Emi`, `T_FX_Bubble_Mask` |
| Animation | `A_<Rig>_<Action>` | `A_Fish_Bite`, `A_Minnow_Dart`, `A_Moray_Lunge` |
| Effect | `FX_[<Group>_]<Name>[_<Variant>]` | `FX_BiteChomp`, `FX_GullDiveSplash`, `FX_Amb_KelpBits`, `FX_TierUp_T4` |
| Sound | `SFX_[<Group>_]<Name>[_<Variant>]` | `SFX_Gulp`, `SFX_UI_Tap`, `SFX_Amb_Reef`, `SFX_Bite_Small`, `SFX_TideHorn_MoonTide` |
| Music | `MUS_<Name>`, `MUS_Event_<Event>`, `MUS_Sting_<Name>`; one stem of a track adds `_Stem<n>`, numbered in the order the stems join (section 12) | `MUS_Reef`, `MUS_Chase`, `MUS_Event_Frenzy`, `MUS_Sting_Gulped`, `MUS_Reef_Stem1` (base), `MUS_Reef_Stem2` (rhythm) |
| Lighting preset | `LGT_<Name>`, `LGT_Event_<Event>` | `LGT_Kelp`, `LGT_Event_MoonTide` |
| Skybox | `SKY_<Name>` | `SKY_Day` |
| Store-art scene | `SCN_<Kind>_<Name>` | `SCN_Icon_A_BehindYou`, `SCN_Thumb_T1_Chase` |

**Rules for every kind**

- **Words.** Each part between underscores is a PascalCase word, a short code (`LM`, `UI`, `LOD1`, `T4`) or a number: letters and digits only, no spaces, no hyphens.
- **Canon things keep their canon ID.** A species, prey, predator, hazard, trait or tide event is written as its ID in PascalCase: `old_scar` is `OldScar`, `zebra_darter` is `ZebraDarter`, `moon_tide` is `MoonTide`, `anglerfish` is `Anglerfish`. Two exceptions: the zone `dropoff` is written `DropOff`, and one member of a `jelly_bloom` is `Jelly`. Post-launch events use the IDs in document 03: `Storm`, `RedTide`, `Migration`, `TrenchOpens`.
- **"Frenzy" means the Feeding Frenzy tide event only** (ID `frenzy`). It appears in no other asset name.
- **The Shark Pup ability is Rampage** (ID `rampage`, canon section 7), so its clip, effects and sounds say `Rampage`.
- **Variants** end in a two-digit number: `M_Env_Rock_03`. A row named `…_01–06` covers six files.

**Meshes**

- Categories: `Species`, `Prey`, `Pred`, `Hazard`, `Env`, `Cove`, `Prop`, `Trait`. Trait prey use `Prey`. Cove decorations use `Prop` (`M_Prop_Deco_<Name>`).
- Suffixes come in this order: age (`_Juv` for tiers 1 to 3, `_Adult` for tiers 4 to 7), form or pose (`_Puffed`, `_Tucked`; `_Glide` and `_Dive` for the Gull; `_Open` and `_Squeezed` for a jelly), distance version (`_LOD1` half the triangles, `_LOD2` a quarter), outline shell (`_Shell` or `_ShellThick`).
- **Outline shells.** `_Shell` is the standard shell, drawn green for "you can eat it". `_ShellThick` is the 1.5× thicker shell, drawn red and pulsing for "it can eat you" (document 06, section 13.2). They are two files, so they need two names; canon section 16 lists both suffixes. A name that ends in `_Shell` is always an outline shell. Who has which: playable species have both, on every body mesh (wild creatures [L] use the same files); prey and trait prey have `_Shell` only; the Barracuda and the Grouper have both; the Gull, the Moray and Old Scar have `_ShellThick` only, because they cannot be eaten; Plankton, hook bait, hazards and scenery have none.
- Shells and distance versions are made by script from the finished mesh and checked by eye. They are listed as one grouped row per creature.
- Environment meshes are `M_Env_<Zone>_<Piece>`, with the zone written `Nursery`, `Reef`, `Kelp`, `DropOff` or `Trench`. Pieces shared by every zone have no zone part (`M_Env_Rock_03`). A piece may have two words, kind then type (`Coral_Brain`).
- Landmarks are `M_Env_<Zone>_LM_<Landmark>`: the name from document 03, section 6, without "The" (`M_Env_Reef_LM_NogginRock`, `M_Env_Reef_LM_Hoop`). A landmark built from several different parts adds the part (`M_Env_DropOff_LM_TinPickle_Bow`).
- Trait kit pieces are `M_Trait_<Trait>_<Piece>` (`M_Trait_Spiny_Spine`).

**Textures**

- Maps: `Alb` colour, `Emi` glow mask, `Mask` greyscale opacity, `Rgh` roughness, `Nrm` normal (not used at soft launch). This file adds `Flip` for a flipbook sheet.
- Species textures are `T_<Species>_<Juv or Adult>_Alb`. A pattern adds `Pat<Pattern>` after the species: `T_Minnow_PatSunrise_Juv_Alb`.
- Trait overlays are `T_Trait_<Trait>_<Family>_<Map>`, and the fallback-zone file of the same overlay adds `_Fallback` before the map (`T_Trait_Glow_Fish_Fallback_Emi`); the kit-piece atlas is `T_Trait_Pieces_Alb`. Effect textures are `T_FX_<Name>_<Map>`.
- One exception: the three shared roughness textures keep the names document 06 gives them, `T_Shared_Rgh`, `T_Shared_RghWet` and `T_Shared_RghChalk`.

**Rigs and animations**

- Body families (document 06, section 3.1): `Fish` (Minnow, Pufferfish, Shark Pup), `Eel`, `Turtle`, `Squid`. A family shares a skeleton layout, a UV layout and a clip set.
- The `<Rig>` in `A_<Rig>_<Action>` is the rig name without its prefix for a family clip (`A_Fish_Bite`). A clip that belongs to one species, predator or prop uses that name instead (`A_Minnow_Dart`, `A_Shark_RampageStart`, `A_PearlClam_Open`). The action is one PascalCase name with no underscore.

**Effects and sounds: the one rule for inner underscores**

After the prefix, an `FX_` or `SFX_` name is **one PascalCase name with no underscore inside it, subject first, then what happens**: `FX_GullDiveSplash`, `SFX_BarracudaAlert`, `FX_RampageStart`. An underscore is allowed in only two places: after a **group**, and before a **variant**. So a name has two inner underscores at most.

| Part | Allowed values | Examples |
|---|---|---|
| Group (optional) | `UI` for interface sounds, which keep the names document 08 calls. `Amb` for ambient loops, spot sounds and ambient particle sets that belong to a place. No other groups | `SFX_UI_TraitPip`, `SFX_Amb_Kelp`, `FX_Amb_DeepMotes` |
| Variant (optional) | Only when the same effect or sound exists in several versions that code picks by a value: a size (`Small`, `Medium`, `Large`, `Huge`), a tier or tier range (`T2` to `T7`, `T1T2`), or a tide event (`Frenzy`, `MoonTide`, `WhaleFall`, and later `Storm`, `RedTide`, `Migration`, `TrenchOpens`) | `SFX_Bite_Small`, `FX_TierUp_T4`, `FX_BubblePop_T1T2`, `SFX_TideHorn_Frenzy`, `FX_TideBanner_WhaleFall` |

A species, trait, predator or ability is never a group: it is the first word of the name (`SFX_MinnowChirp`, `FX_GlowAura`, `SFX_OldScarNear`, `FX_PuffInflate`). A phase such as Start, Loop, In or Out is part of the name, not a variant (`SFX_RampageLoop`, `SFX_CamoOff`).

**Sound takes.** A row's "× 3" is its number of takes: recordings of the same sound that code picks among at random so repeats do not sound mechanical. Takes are files, not rows. Each file is the row's name with a two-digit take number appended, **without** an extra underscore, so a name still has at most two inner underscores: `SFX_Bite_Small01`, `SFX_Bite_Small02`, `SFX_Bite_Small03`; `SFX_Gulp01`; `SFX_UI_Tap01`. A sound with one take still gets `01`. A take is not a variant: a variant is picked by a value and is its own row.

**Music, lighting, skies and scenes**

- `MUS_Event_<Event>` is a tide event theme (`MUS_Event_Warning` is the shared 60-second warning) and `MUS_Sting_<Name>` is a stinger. Every other track is `MUS_<Name>`, where the name is a zone or a state.
- `LGT_<Name>` is a zone or state preset; `LGT_Event_<Event>` is the preset a tide event blends in.
- `SCN_<Kind>_<Name>`: the kind is `Stage`, `Icon`, `Thumb`, `Brand` or `Event`. Icons and thumbnails put document 11's letter or number before the name. Where document 11 has a soft-launch and a public-launch version of one image under one name, the soft-launch scene keeps the plain name and the public-launch scene adds `_Launch` (`SCN_Icon_A_BehindYou_Launch`); where the two versions have different names, each scene takes its own (`SCN_Thumb_T4_FiveSizes`, `SCN_Thumb_T4_SevenSizes`).

### 1.3 Folder layout

```
assets/
  source/                 working files, never uploaded
    _shared/              family base meshes, UV templates, palettes, Blender scripts
    species/<id>/         one .blend per species: all meshes, the fitted skeleton, its own clips
    families/<family>/    the family skeleton and its shared clip set
    traits/               overlay masters and kit pieces
    prey/                 prey and trait prey
    predators/<id>/
    hazards/<id>/
    env/shared/  env/nursery/  env/reef/  env/kelp/  env/dropoff/  env/trench/
    cove/                 cove kit and decorations
    water_sky/
    events/<id>/
    fx/                   flipbook render scenes
    audio/sfx/  audio/music/    project files and licensed source clips
    store/                icon and thumbnail scenes
  export/                 exactly what is uploaded to Roblox, named as in this list
    meshes/               M_*.fbx (a skeleton travels inside its mesh file)
    animations/           A_*.fbx
    textures/             T_*.png
    fx/                   FX_*.json emitter settings
    lighting/             LGT_*.json, SKY_*/ (six faces each)
    audio/sfx/            SFX_*.ogg
    audio/music/          MUS_*.ogg
    store/                rendered scene plates handed to document 11
  placeholder/            grey-box stand-ins with the same names (section 16)
  licences/               one text file per licensed audio source
  manifest.csv            name, tag, status, Roblox asset ID, placeholder yes/no
```

Document 09 decides how `export/` maps into the Rojo project. Code refers to assets by name through the manifest, never by a pasted asset ID.

### 1.4 Engine limits and build methods this list assumes

All from document 06 unless noted. Each one that fails in the first-sprint tests changes hours here (section 17.5).

- A mesh can have at most 20,000 triangles and a vertex can follow at most 4 bones. The largest single mesh planned here is 8,000 triangles (Old Scar); bigger set pieces are split into meshes of 6,000 or fewer.
- Animations move and rotate bones but do not scale them. Squash and stretch is done by sliding the spine bones and four Girth bones. Extreme shapes (Pufferfish puffed, Sea Turtle tucked, the tier 4 form change) are **mesh swaps** hidden by a short effect.
- **Swimming is driven by code**, not by clips: the spine sways with speed and bends into turns. So there are no turn clips, and each family has one reference swim cycle that the code is matched to (and that serves as the fallback if code and clips cannot be layered; Sprint 0 measured that they can, when code writes the bones on `PreRender`, document 06, section 7.6).
- Eyes and eyelids are bones moved by code. Expressions need no textures or clips.
- **Outlines are our own shell meshes**, not an engine effect (the built-in `Neon` material is allowed on them, canon section 13). Every creature of tier 1 or more needs them: `_Shell` for the green outline, `_ShellThick` for the red one (section 1.2 says who has which). Plankton and hook bait have no outline.
- Creatures ship three distance versions (full, `_LOD1`, `_LOD2`) plus a far-away dot (`FX_Glint`). Static scenery uses the engine's automatic versions.
- Trait overlays are extra texture layers in the family UV layout, drawn on an **overlay shell**: a second skinned mesh just outside the body, built into the creature's template before it spawns (document 06, section 8.4; the Sprint 0 trait test chose it and ruled out decals).
- **The world is meshes, not Roblox terrain**, and the sea is fog and light, not a water volume.
- One hand-painted colour texture per asset, plus three tiny shared roughness textures. No normal maps, no metal.
- No texture here is larger than 1024 × 1024. Particle flipbooks are 512 × 512 in a 4×4 grid.

**Default-art traps.** Canon forbids default Roblox art. These engine defaults must each be replaced or switched off, and the replacement is on this list: the sky, sun and moon images (section 7); built-in clouds (off); terrain and terrain water (not used); the default particle image (every effect names its own texture); default sounds (section 11); the default plastic shine (the shared roughness textures in section 2.0).

### 1.5 Status

| Status | Meaning |
|---|---|
| `not started` | Nothing exists except the placeholder. |
| `blocked` | Cannot start or finish; the manifest notes what it is waiting for. |
| `in progress` | Being made. |
| `in review` | Exported and in the game; waiting for an art or audio review. |
| `done` | Reviewed, uploaded, asset ID in the manifest, placeholder removed. |

The Status column in this file is the starting state. The live status is kept in `assets/manifest.csv`.

## 2. Playable species

Each species has a juvenile mesh (tiers 1 to 3) and an adult mesh (tiers 4 to 7) on one skeleton and one UV layout, so clips, traits and patterns work on both. Both are built at body scale 1.0; the game scales them per tier. A Leviathan (tier 7) also wears a small crest piece. Document 06, section 3.6 defines one crest shape per body family: a back sail on `Fish`, a head fan on `Eel`, a shell keel on `Turtle` and a mantle crown on `Squid`.

Budgets from document 06: juvenile 1,500 triangles with a 256 × 256 texture, adult 3,500 with 512 × 512; outline shell 600 triangles for a juvenile and 1,400 for an adult (about 40% of the body).

Every body mesh, including the puffed and tucked forms, gets two outline shells: `_Shell` for the green "you can eat it" outline and the 1.5× thicker `_ShellThick` for the red "it can eat you" outline. A juvenile needs the thick one too, because a tier 3 creature can eat a tier 2 player (canon section 5.2). The crest has no shell; the outline follows the body.

### 2.0 Shared species sources

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `M_Species_Base_Fish` | [MVP] | Family base mesh and the standard UV layout (document 06, section 5.4). Source only, not uploaded. Every `Fish` species starts from it | 1,500 tris | — | 3 | not started |
| `M_Species_Base_Eel` | [MVP] | Family base mesh and the standard UV layout (document 06, section 5.4). Source only, not uploaded. Every `Eel` species starts from it | 1,500 tris | — | 3 | not started |
| `M_Species_Base_Turtle` | [L] | Family base mesh and the standard UV layout (document 06, section 5.4). Source only, not uploaded. Every `Turtle` species starts from it | 1,500 tris | — | 3 | not started |
| `M_Species_Base_Squid` | [L] | Family base mesh and the standard UV layout (document 06, section 5.4). Source only, not uploaded. Every `Squid` species starts from it | 1,500 tris | — | 3 | not started |
| `RIG_Fish` | [MVP] | Family skeleton: Root, Spine 1 to 4, TailFin, Jaw, Dorsal, two Pec, two Eye, two Lid, four Girth; plus ten weightless socket bones for trait pieces and the crest, exported as a socket table too (the importer drops weightless bones; the game builds the sockets from the table, document 06, section 8.4) | 18 bones + 10 sockets | M_Species_Base_Fish | 3 | not started |
| `RIG_Eel` | [MVP] | Family skeleton: Spine 1 to 10, Jaw, Dorsal 1 to 2, eyes, lids, Girth; ten sockets | 22 bones + 10 sockets | M_Species_Base_Eel | 4 | not started |
| `RIG_Turtle` | [L] | Family skeleton: Shell, Neck, Head, Jaw, four flippers, Tail, eyes, lids, Girth; eight sockets | 20 bones + 8 sockets | M_Species_Base_Turtle | 5 | not started |
| `RIG_Squid` | [L] | Family skeleton: Mantle 1 to 3, two fins, six arms of two bones, eyes, lids, two Girth; eight sockets | 24 bones + 8 sockets | M_Species_Base_Squid | 6 | not started |
| `T_Shared_Rgh, T_Shared_RghWet, T_Shared_RghChalk` | [MVP] | Three flat roughness textures used by every asset so nothing shows the default plastic shine: matte, wet (eyes, Pearls), chalk (sand) | 8 × 8 each | — | 0.3 | not started |
| `M_Prop_EyeX, T_Shared_EyeX_Alb` | [MVP] | Two-triangle card with an X mark, shown over each eye for the four frames of being gulped | 2 tris, 64² | — | 0.3 | not started |
| `T_Shared_EyeRing_Emi` | [MVP] | Soft glow ring for every creature's eyes during Moon Tide; two dots for anything that can eat the player | 64² | — | 0.3 | not started |
| `M_Prop_HatchEgg` | [MVP] | The pale egg a new Fry hatches from, on the Hatch Bed in the Nursery and on the Home Stone in a cove. Whole egg and two cracked halves | 200 tris | T_Cove_Alb | 1.2 | not started |
| (check) Wild creatures | [L] | Computer-controlled wild creatures (canon section 15) are the six species meshes with their base textures, clips, voices and both outline shells, at tiers 1 to 5. They never wear a pattern. No new mesh or texture: the leaf name tag that marks them as wild is `UI_HUD_WildTag` in document 08. This row is the check that each species reads as that species, with the tag, next to real players | — | all six species | 1 | not started |

### 2.1 Family clip sets

Shared by every species in the family. Lengths are frames at 30 a second (document 06, section 7.2). There are no turn clips (the code bends the spine into the turn), no eye or face textures (eyes and lids are bones moved by code) and no emote clips (emotes are picture bubbles, document 03 section 14; their sounds are in section 11). `Fish` and `Eel` sets are [MVP]; `Turtle` and `Squid` sets are [L] and exist only because of those two species.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `A_Fish_Swim` | [MVP] | Reference swim cycle that the sway code is matched to; the fallback if code cannot layer over clips | loop 16 frames | RIG_Fish | 1.5 | not started |
| `A_Fish_SwimFast` | [MVP] | Dash-speed version: shorter loop, bigger sweep, fins folded | loop 8 frames | RIG_Fish | 0.8 | not started |
| `A_Fish_Idle` | [MVP] | Hover when the player lets go: fins scull, body bobs | loop 60 frames | RIG_Fish | 1 | not started |
| `A_Fish_Dash` | [MVP] | Squash to 85%, stretch to 125% with fins pinned back, settle. Matches the 0.35 s dash | 14 frames | RIG_Fish | 0.8 | not started |
| `A_Fish_Bite` | [MVP] | Jaw snap and a 12% head lunge; cheeks bulge | 7 to 9 frames | RIG_Fish | 0.8 | not started |
| `A_Fish_Gulp` | [MVP] | Eater swallows a player or large prey: full gape, snap, swallow bulge down the body | 12 frames | RIG_Fish | 0.8 | not started |
| `A_Fish_Hit` | [MVP] | Squash to 80%: bite survived, or two same-tier players bump. The white flash is code, not keyed (06 §7.2) | 11 frames | RIG_Fish | 0.5 | not started |
| `A_Fish_Stunned` | [MVP] | Wobble loop (eyes spiral in code). Also used when slowed, burning, hooked or pulled by a Grouper | loop 20 frames | RIG_Fish | 0.8 | not started |
| `A_Fish_TierUp` | [MVP] | Squash to 75%, pop to 130% of the new size, settle | 18 frames | RIG_Fish | 1 | not started |
| `A_Fish_Gulped` | [MVP] | Stretch 140% toward the mouth, the body pulled in behind the head. Bones only: the shrink to nothing is code, `Model:ScaleTo` over frames 4 to 8 (06 §7.2) | 8 frames | RIG_Fish | 0.6 | not started |
| `A_Fish_Bank` | [MVP] | Happy spin with eyes closed on entering the cove | 18 frames | RIG_Fish | 0.8 | not started |
| `A_Fish_Breach` | [MVP] | Arc through the air and flop back in | 30 frames | RIG_Fish | 0.8 | not started |
| `A_Fish_Hatch` | [MVP] | Wriggle out of the egg and stretch; the player has control by 1.5 s | 45 frames | RIG_Fish | 1 | not started |
| `A_Fish_CoveNotice` | [L] | A specimen turns to face a visitor with a small happy squash, then turns back | 30 frames | RIG_Fish | 0.6 | not started |
| `A_Eel_Swim` | [MVP] | Reference swim cycle that the sway code is matched to; the fallback if code cannot layer over clips | loop 20 frames | RIG_Eel | 1.8 | not started |
| `A_Eel_SwimFast` | [MVP] | Dash-speed version | loop 10 frames | RIG_Eel | 1 | not started |
| `A_Eel_Idle` | [MVP] | Hover when the player lets go | loop 60 frames | RIG_Eel | 1.2 | not started |
| `A_Eel_Dash` | [MVP] | Squash to 85%, stretch to 125% with fins pinned back, settle | 14 frames | RIG_Eel | 1 | not started |
| `A_Eel_Bite` | [MVP] | Jaw snap and a 12% head lunge; cheeks bulge | 7 to 9 frames | RIG_Eel | 1 | not started |
| `A_Eel_Gulp` | [MVP] | Eater swallows a player or large prey | 12 frames | RIG_Eel | 1 | not started |
| `A_Eel_Hit` | [MVP] | Flash and squash to 80% | 11 frames | RIG_Eel | 0.6 | not started |
| `A_Eel_Stunned` | [MVP] | Wobble loop (eyes spiral in code) | loop 20 frames | RIG_Eel | 1 | not started |
| `A_Eel_TierUp` | [MVP] | Squash to 75%, pop to 130% of the new size, settle | 18 frames | RIG_Eel | 1.2 | not started |
| `A_Eel_Gulped` | [MVP] | Stretch 140% toward the mouth and shrink to nothing | 8 frames | RIG_Eel | 0.7 | not started |
| `A_Eel_Bank` | [MVP] | Happy spin with eyes closed on entering the cove | 18 frames | RIG_Eel | 1 | not started |
| `A_Eel_Breach` | [MVP] | Arc through the air and flop back in | 30 frames | RIG_Eel | 1 | not started |
| `A_Eel_Hatch` | [MVP] | Wriggle out of the egg and stretch; the player has control by 1 | 45 frames | RIG_Eel | 1.2 | not started |
| `A_Eel_CoveNotice` | [L] | A specimen turns to face a visitor with a small happy squash, then turns back | 30 frames | RIG_Eel | 0.7 | not started |
| `A_Turtle_Swim` | [L] | Reference swim cycle that the sway code is matched to; the fallback if code cannot layer over clips | loop 30 frames | RIG_Turtle | 1.8 | not started |
| `A_Turtle_SwimFast` | [L] | Dash-speed version | loop 16 frames | RIG_Turtle | 1 | not started |
| `A_Turtle_Idle` | [L] | Hover when the player lets go | loop 60 frames | RIG_Turtle | 1.2 | not started |
| `A_Turtle_Dash` | [L] | Squash to 85%, stretch to 125% with fins pinned back, settle | 14 frames | RIG_Turtle | 1 | not started |
| `A_Turtle_Bite` | [L] | Jaw snap and a 12% head lunge; cheeks bulge | 7 to 9 frames | RIG_Turtle | 1 | not started |
| `A_Turtle_Gulp` | [L] | Eater swallows a player or large prey | 12 frames | RIG_Turtle | 1 | not started |
| `A_Turtle_Hit` | [L] | Flash and squash to 80% | 11 frames | RIG_Turtle | 0.6 | not started |
| `A_Turtle_Stunned` | [L] | Wobble loop (eyes spiral in code) | loop 20 frames | RIG_Turtle | 1 | not started |
| `A_Turtle_TierUp` | [L] | Squash to 75%, pop to 130% of the new size, settle | 18 frames | RIG_Turtle | 1.2 | not started |
| `A_Turtle_Gulped` | [L] | Stretch 140% toward the mouth and shrink to nothing | 8 frames | RIG_Turtle | 0.7 | not started |
| `A_Turtle_Bank` | [L] | Happy spin with eyes closed on entering the cove | 18 frames | RIG_Turtle | 1 | not started |
| `A_Turtle_Breach` | [L] | Arc through the air and flop back in | 30 frames | RIG_Turtle | 1 | not started |
| `A_Turtle_Hatch` | [L] | Wriggle out of the egg and stretch; the player has control by 1 | 45 frames | RIG_Turtle | 1.2 | not started |
| `A_Turtle_CoveNotice` | [L] | A specimen turns to face a visitor with a small happy squash, then turns back | 30 frames | RIG_Turtle | 0.7 | not started |
| `A_Squid_Swim` | [L] | Reference swim cycle that the sway code is matched to; the fallback if code cannot layer over clips | loop 24 frames | RIG_Squid | 2.1 | not started |
| `A_Squid_SwimFast` | [L] | Dash-speed version | loop 10 frames | RIG_Squid | 1.1 | not started |
| `A_Squid_Idle` | [L] | Hover when the player lets go | loop 60 frames | RIG_Squid | 1.4 | not started |
| `A_Squid_Dash` | [L] | Squash to 85%, stretch to 125% with fins pinned back, settle | 14 frames | RIG_Squid | 1.1 | not started |
| `A_Squid_Bite` | [L] | Jaw snap and a 12% head lunge; cheeks bulge | 7 to 9 frames | RIG_Squid | 1.1 | not started |
| `A_Squid_Gulp` | [L] | Eater swallows a player or large prey | 12 frames | RIG_Squid | 1.1 | not started |
| `A_Squid_Hit` | [L] | Flash and squash to 80% | 11 frames | RIG_Squid | 0.7 | not started |
| `A_Squid_Stunned` | [L] | Wobble loop (eyes spiral in code) | loop 20 frames | RIG_Squid | 1.1 | not started |
| `A_Squid_TierUp` | [L] | Squash to 75%, pop to 130% of the new size, settle | 18 frames | RIG_Squid | 1.4 | not started |
| `A_Squid_Gulped` | [L] | Stretch 140% toward the mouth and shrink to nothing | 8 frames | RIG_Squid | 0.8 | not started |
| `A_Squid_Bank` | [L] | Happy spin with eyes closed on entering the cove | 18 frames | RIG_Squid | 1.1 | not started |
| `A_Squid_Breach` | [L] | Arc through the air and flop back in | 30 frames | RIG_Squid | 1.1 | not started |
| `A_Squid_Hatch` | [L] | Wriggle out of the egg and stretch; the player has control by 1 | 45 frames | RIG_Squid | 1.4 | not started |
| `A_Squid_CoveNotice` | [L] | A specimen turns to face a visitor with a small happy squash, then turns back | 30 frames | RIG_Squid | 0.8 | not started |

### 2.2 Minnow (`minnow`) [MVP]

Family `Fish`. **Dart** is passive (shorter dash cooldown, no button); its only asset is the Minnow's own dash clip. Effects (rows in section 9): `FX_DashBurst`, `FX_DashTrail`. Voice sounds are in section 11.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `M_Species_Minnow_Juv` | [MVP] | Slightly fat teardrop, forked tail, very large eyes. Orange, so it is never mistaken for a Sardine. Biggest head and eyes | 1,500 tris | M_Species_Base_Fish | 4 | not started |
| `M_Species_Minnow_Adult` | [MVP] | Longer body, smaller eyes, full signature feature. Swapped in at tier 4 inside `FX_Metamorph` | 3,500 tris | M_Species_Minnow_Juv | 5 | not started |
| `M_Species_Minnow_*_LOD1, _LOD2` | [MVP] | Half and quarter triangle versions of each mesh, made by script and checked | half and quarter | finished meshes | 1 | not started |
| `M_Species_Minnow_*_Shell, _ShellThick` | [MVP] | Outline shells by script: `_Shell` (green, "you can eat it") and the 1.5× thicker `_ShellThick` (red, "it can eat you") for the juvenile and the adult, each with its two distance versions | 600 tris juvenile, 1,400 adult | finished meshes | 1 | not started |
| `M_Species_Minnow_Crest` | [MVP] | Leviathan crest for tier 7, attached to `Sock_Crest`: the `Fish` back sail, three rounded spines joined by a web, the front one tallest (document 06, section 3.6) | 150 tris | RIG_Fish | 0.8 | not started |
| (fit) Minnow on RIG_Fish | [MVP] | Family skeleton fitted to this body, weights for every mesh, sockets placed | — | RIG_Fish | 2.5 | not started |
| `T_Minnow_Juv_Alb` | [MVP] | Juvenile colours: three clear values, hand-painted, eye and mouth in the standard layout | 256² | family UV layout | 2 | not started |
| `T_Minnow_Adult_Alb` | [MVP] | Adult colours | 512² | T_Minnow_Juv_Alb | 3 | not started |
| `T_Minnow_PatSunrise_Juv_Alb, _Adult_Alb` | [L] | Pattern `pat_minnow_sunrise`: rosy pink back fading to a gold belly, pale pink fins. Starter Pack. Large colour areas only, never bands, dots or glow | 256² and 512² | base textures | 2 | not started |
| `T_Minnow_PatBlueberry_Juv_Alb, _Adult_Alb` | [L] | Pattern `pat_minnow_blueberry`: deep blue back, pale blue belly, yellow tail. Large colour areas only, never bands, dots or glow | 256² and 512² | base textures | 2 | not started |
| `T_Minnow_PatMint_Juv_Alb, _Adult_Alb` | [L] | Pattern `pat_minnow_mint`: mint body, white fin tips, dark green tail. Large colour areas only, never bands, dots or glow | 256² and 512² | base textures | 2 | not started |
| `A_Minnow_Dart` | [MVP] | The Minnow's own dash: a sharper, shorter snap used in place of `A_Fish_Dash` | 12 frames | RIG_Fish | 0.6 | not started |
| `A_Minnow_Fidget` | [MVP] | Cove fidget, about every 12 s: chases its own tail | 50 frames | RIG_Fish | 1 | not started |

### 2.3 Pufferfish (`puffer`) [MVP]

Family `Fish`. **Puff** is a mesh swap. The round body shares the `Fish` skeleton and clips, so it needs its own check pass. Effects (rows in section 9): `FX_PuffInflate`, `FX_PuffDeflate`. Voice sounds are in section 11.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `M_Species_Puffer_Juv` | [MVP] | Almost a ball: tiny fins, a small beak mouth with two front teeth, wide worried eyes. Smooth skin with no spines; spines belong to the Spiny trait and the Urchin Puff. Biggest head and eyes | 1,500 tris | M_Species_Base_Fish | 4.5 | not started |
| `M_Species_Puffer_Adult` | [MVP] | Longer body, smaller eyes, full signature feature. Swapped in at tier 4 inside `FX_Metamorph` | 3,500 tris | M_Species_Puffer_Juv | 5.5 | not started |
| `M_Species_Puffer_Juv_Puffed` | [MVP] | Inflated juvenile: a smooth pale sphere 1.5 times the normal height, cheeks full, eyes wide. No spines. Swapped in for the 2 s of Puff | 1,800 tris | M_Species_Puffer_Juv | 2 | not started |
| `M_Species_Puffer_Adult_Puffed` | [MVP] | Inflated adult: the same smooth pale sphere; must read as "do not eat" from 100 studs. Document 06 allows this one mesh above the adult budget | 4,000 tris | M_Species_Puffer_Juv | 2.5 | not started |
| `M_Species_Puffer_*_LOD1, _LOD2` | [MVP] | Half and quarter triangle versions of each mesh, made by script and checked | half and quarter | finished meshes | 1.5 | not started |
| `M_Species_Puffer_*_Shell, _ShellThick` | [MVP] | Outline shells by script: `_Shell` (green, "you can eat it") and the 1.5× thicker `_ShellThick` (red, "it can eat you") for the juvenile, the adult and the two puffed meshes, each with its two distance versions | 40% of each body: 600 and 1,400 tris; 720 and 1,600 puffed | finished meshes | 1 | not started |
| `M_Species_Puffer_Crest` | [MVP] | Leviathan crest for tier 7, attached to `Sock_Crest`: the `Fish` back sail with three short, fat spines (document 06, section 3.6) | 150 tris | RIG_Fish | 0.8 | not started |
| (fit) Pufferfish on RIG_Fish | [MVP] | Family skeleton fitted to this body, weights for every mesh, sockets placed | — | RIG_Fish | 3.5 | not started |
| `T_Puffer_Juv_Alb` | [MVP] | Juvenile colours: three clear values, hand-painted, eye and mouth in the standard layout | 256² | family UV layout | 2 | not started |
| `T_Puffer_Adult_Alb` | [MVP] | Adult colours | 512² | T_Puffer_Juv_Alb | 3 | not started |
| `T_Puffer_PatLemon_Juv_Alb, _Adult_Alb` | [L] | Pattern `pat_puffer_lemon`: "Lemon Drop": pale lemon body dusted white like sugar, white fins, lime-green lips (a soft lime under the saturation limit in document 06, section 4.5). Large colour areas only, never bands, dots or glow | 256² and 512² | base textures | 2 | not started |
| `T_Puffer_PatBubblegum_Juv_Alb, _Adult_Alb` | [L] | Pattern `pat_puffer_bubblegum`: pink back, cream belly, pale blue fins. Large colour areas only, never bands, dots or glow | 256² and 512² | base textures | 2 | not started |
| `T_Puffer_PatMidnight_Juv_Alb, _Adult_Alb` | [L] | Pattern `pat_puffer_midnight`: navy back, grey belly, light cyan fin edges. Large colour areas only, never bands, dots or glow | 256² and 512² | base textures | 2 | not started |
| (check) Fish clips on the Pufferfish | [MVP] | Play the whole `A_Fish_*` set on this body and fix poses that break | — | A_Fish_* | 1.5 | not started |
| `A_Puffer_FinWhir` | [MVP] | Tiny fins whir on a 4-frame loop while the body barely bends; layered over the family swim | loop 4 frames | RIG_Fish | 0.4 | not started |
| `A_Puffer_PuffIn` | [MVP] | Gulp; the puffed mesh is swapped in on frame 3 behind `FX_PuffInflate` | 9 frames | RIG_Fish | 0.8 | not started |
| `A_Puffer_PuffHold` | [MVP] | Slow bob and paddle on the puffed mesh | loop 30 frames | RIG_Fish | 0.6 | not started |
| `A_Puffer_PuffOut` | [MVP] | Deflate wobble; swap back | 12 frames | RIG_Fish | 0.6 | not started |
| `A_Puffer_Fidget` | [MVP] | Cove fidget: hiccups a bubble | 45 frames | RIG_Fish | 1 | not started |

### 2.4 Eel (`eel`) [MVP]

Family `Eel`. **Slip** is passive (no button): the Eel can pass through eel holes and its dash is 30% longer. It needs one clip for the eel holes (section 6); the longer dash reuses `A_Eel_Dash`. Effects (rows in section 9): `FX_SlipHole`. Voice sounds are in section 11.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `M_Species_Eel_Juv` | [MVP] | Ribbon with a round head and a long back-fin ribbon. Friendly, never angular like the Moray. Biggest head and eyes | 1,500 tris | M_Species_Base_Eel | 4 | not started |
| `M_Species_Eel_Adult` | [MVP] | Longer body, smaller eyes, full signature feature. Swapped in at tier 4 inside `FX_Metamorph` | 3,500 tris | M_Species_Eel_Juv | 5 | not started |
| `M_Species_Eel_*_LOD1, _LOD2` | [MVP] | Half and quarter triangle versions of each mesh, made by script and checked | half and quarter | finished meshes | 1 | not started |
| `M_Species_Eel_*_Shell, _ShellThick` | [MVP] | Outline shells by script: `_Shell` (green, "you can eat it") and the 1.5× thicker `_ShellThick` (red, "it can eat you") for the juvenile and the adult, each with its two distance versions | 600 tris juvenile, 1,400 adult | finished meshes | 1 | not started |
| `M_Species_Eel_Crest` | [MVP] | Leviathan crest for tier 7, attached to `Sock_Crest`: the `Eel` head fan, five rounded lobes standing up behind the head (document 06, section 3.6) | 150 tris | RIG_Eel | 0.8 | not started |
| (fit) Eel on RIG_Eel | [MVP] | Family skeleton fitted to this body, weights for every mesh, sockets placed | — | RIG_Eel | 3 | not started |
| `T_Eel_Juv_Alb` | [MVP] | Juvenile colours: three clear values, hand-painted, eye and mouth in the standard layout | 256² | family UV layout | 2 | not started |
| `T_Eel_Adult_Alb` | [MVP] | Adult colours | 512² | T_Eel_Juv_Alb | 3 | not started |
| `T_Eel_PatLiquorice_Juv_Alb, _Adult_Alb` | [L] | Pattern `pat_eel_liquorice`: black back, red belly, red fin ribbon. Large colour areas only, never bands, dots or glow | 256² and 512² | base textures | 2 | not started |
| `T_Eel_PatSeafoam_Juv_Alb, _Adult_Alb` | [L] | Pattern `pat_eel_seafoam`: pale green-white body, teal fin ribbon. Large colour areas only, never bands, dots or glow | 256² and 512² | base textures | 2 | not started |
| `T_Eel_PatSunset_Juv_Alb, _Adult_Alb` | [L] | Pattern `pat_eel_sunset`: coral head fading to an orange tail. Large colour areas only, never bands, dots or glow | 256² and 512² | base textures | 2 | not started |
| `A_Eel_Slip` | [MVP] | Straighten and thread through an eel hole | loop 18 frames | RIG_Eel | 1 | not started |
| `A_Eel_Fidget` | [MVP] | Cove fidget: ties a loose knot and unties it | 60 frames | RIG_Eel | 1.2 | not started |

### 2.5 Sea Turtle (`turtle`) [L]

Family `Turtle`. **Shell** is a mesh swap. The only member of the `Turtle` family, so it carries that family's skeleton, clip set and trait overlays. Effects (rows in section 9): `FX_ShellTuck`, `FX_ShellDeflect`. Voice sounds are in section 11.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `M_Species_Turtle_Juv` | [L] | Dome over four paddles, shell rim and beak. Biggest head and eyes | 1,500 tris | M_Species_Base_Turtle | 6 | not started |
| `M_Species_Turtle_Adult` | [L] | Longer body, smaller eyes, full signature feature. Swapped in at tier 4 inside `FX_Metamorph` | 3,500 tris | M_Species_Turtle_Juv | 7 | not started |
| `M_Species_Turtle_Juv_Tucked` | [L] | Juvenile with head and flippers inside the shell. Swapped in for the 2.5 s of Shell | 900 tris | M_Species_Turtle_Juv | 1.5 | not started |
| `M_Species_Turtle_Adult_Tucked` | [L] | Tucked adult | 2,000 tris | M_Species_Turtle_Juv | 1.5 | not started |
| `M_Species_Turtle_*_LOD1, _LOD2` | [L] | Half and quarter triangle versions of each mesh, made by script and checked | half and quarter | finished meshes | 1.5 | not started |
| `M_Species_Turtle_*_Shell, _ShellThick` | [L] | Outline shells by script: `_Shell` (green, "you can eat it") and the 1.5× thicker `_ShellThick` (red, "it can eat you") for the juvenile, the adult and the two tucked meshes, each with its two distance versions | 40% of each body: 600 and 1,400 tris; 360 and 800 tucked | finished meshes | 1 | not started |
| `M_Species_Turtle_Crest` | [L] | Leviathan crest for tier 7, attached to `Sock_Crest`: the `Turtle` shell keel, three rounded knobs down the centre line of the shell (document 06, section 3.6) | 150 tris | RIG_Turtle | 0.8 | not started |
| (fit) Sea Turtle on RIG_Turtle | [L] | Family skeleton fitted to this body, weights for every mesh, sockets placed | — | RIG_Turtle | 4 | not started |
| `T_Turtle_Juv_Alb` | [L] | Juvenile colours: three clear values, hand-painted, eye and mouth in the standard layout | 256² | family UV layout | 2 | not started |
| `T_Turtle_Adult_Alb` | [L] | Adult colours | 512² | T_Turtle_Juv_Alb | 3 | not started |
| `T_Turtle_PatMossback_Juv_Alb, _Adult_Alb` | [L] | Pattern `pat_turtle_mossback`: dark green shell with moss tufts, tan skin. Large colour areas only, never bands, dots or glow | 256² and 512² | base textures | 2 | not started |
| `T_Turtle_PatTerracotta_Juv_Alb, _Adult_Alb` | [L] | Pattern `pat_turtle_terracotta`: brick-red clay shell, cream skin. Large colour areas only, never bands, dots or glow | 256² and 512² | base textures | 2 | not started |
| `T_Turtle_PatRoyal_Juv_Alb, _Adult_Alb` | [L] | Pattern `pat_turtle_royal`: purple shell with a gold rim, lilac skin. Large colour areas only, never bands, dots or glow | 256² and 512² | base textures | 2 | not started |
| `A_Turtle_ShellIn` | [L] | Head and flippers pull in; the tucked mesh is swapped in behind `FX_ShellTuck` | 9 frames | RIG_Turtle | 0.8 | not started |
| `A_Turtle_ShellHold` | [L] | The shell rocks gently | loop 45 frames | RIG_Turtle | 0.4 | not started |
| `A_Turtle_ShellOut` | [L] | Pop back out | 12 frames | RIG_Turtle | 0.6 | not started |
| `A_Turtle_Fidget` | [L] | Cove fidget: scratches its shell with a back flipper | 50 frames | RIG_Turtle | 1.2 | not started |

### 2.6 Squid (`squid`) [L]

Family `Squid`. **Jet** is one clip. The only member of the `Squid` family and the most expensive creature at launch. Effects (rows in section 9): `FX_JetBurst`, `FX_JetInkPuff`. Voice sounds are in section 11.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `M_Species_Squid_Juv` | [L] | Bullet body, big eyes low on the mantle, six short arms and two long feeding tentacles. Biggest head and eyes | 1,500 tris | M_Species_Base_Squid | 6 | not started |
| `M_Species_Squid_Adult` | [L] | Longer body, smaller eyes, full signature feature. Swapped in at tier 4 inside `FX_Metamorph` | 3,500 tris | M_Species_Squid_Juv | 7 | not started |
| `M_Species_Squid_*_LOD1, _LOD2` | [L] | Half and quarter triangle versions of each mesh, made by script and checked | half and quarter | finished meshes | 1 | not started |
| `M_Species_Squid_*_Shell, _ShellThick` | [L] | Outline shells by script: `_Shell` (green, "you can eat it") and the 1.5× thicker `_ShellThick` (red, "it can eat you") for the juvenile and the adult, each with its two distance versions | 600 tris juvenile, 1,400 adult | finished meshes | 1 | not started |
| `M_Species_Squid_Crest` | [L] | Leviathan crest for tier 7, attached to `Sock_Crest`: the `Squid` mantle crown, three leaf-shaped points at the tip of the mantle (document 06, section 3.6) | 150 tris | RIG_Squid | 0.8 | not started |
| (fit) Squid on RIG_Squid | [L] | Family skeleton fitted to this body, weights for every mesh, sockets placed | — | RIG_Squid | 5 | not started |
| `T_Squid_Juv_Alb` | [L] | Juvenile colours: three clear values, hand-painted, eye and mouth in the standard layout | 256² | family UV layout | 2 | not started |
| `T_Squid_Adult_Alb` | [L] | Adult colours | 512² | T_Squid_Juv_Alb | 3 | not started |
| `T_Squid_PatPeach_Juv_Alb, _Adult_Alb` | [L] | Pattern `pat_squid_peach`: "Peach Fizz": soft peach-orange body, cream arms, yellow tail fins. Large colour areas only, never bands, dots or glow | 256² and 512² | base textures | 2 | not started |
| `T_Squid_PatDeepSea_Juv_Alb, _Adult_Alb` | [L] | Pattern `pat_squid_deepsea`: dark teal body, pale glowing fin edges. Large colour areas only, never bands, dots or glow | 256² and 512² | base textures | 2 | not started |
| `T_Squid_PatCherry_Juv_Alb, _Adult_Alb` | [L] | Pattern `pat_squid_cherry`: red body, white arm tips. Large colour areas only, never bands, dots or glow | 256² and 512² | base textures | 2 | not started |
| `A_Squid_Jet` | [L] | Arms snap shut and the body shoots backwards | 15 frames | RIG_Squid | 1.2 | not started |
| `A_Squid_Fidget` | [L] | Cove fidget: juggles a pebble between two arms | 60 frames | RIG_Squid | 1.4 | not started |

### 2.7 Shark Pup (`shark`) [L]

Family `Fish`. **Rampage** is passive: it triggers by itself after three quick bites, so there is no button to press. The slower, head-sweeping swim is a setting of the sway code. The juvenile covers tiers 2 and 3 only. Effects (rows in section 9): `FX_RampageStart`, `FX_RampageAura`. Voice sounds are in section 11.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `M_Species_Shark_Juv` | [L] | Wedge with a blunt round snout, tall back fin, two to four blunt tooth nubs. Light and round-nosed, never like Old Scar. Biggest head and eyes | 1,500 tris | M_Species_Base_Fish | 4 | not started |
| `M_Species_Shark_Adult` | [L] | Longer body, smaller eyes, full signature feature. Swapped in at tier 4 inside `FX_Metamorph` | 3,500 tris | M_Species_Shark_Juv | 6 | not started |
| `M_Species_Shark_*_LOD1, _LOD2` | [L] | Half and quarter triangle versions of each mesh, made by script and checked | half and quarter | finished meshes | 1 | not started |
| `M_Species_Shark_*_Shell, _ShellThick` | [L] | Outline shells by script: `_Shell` (green, "you can eat it") and the 1.5× thicker `_ShellThick` (red, "it can eat you") for the juvenile and the adult, each with its two distance versions | 600 tris juvenile, 1,400 adult | finished meshes | 1 | not started |
| `M_Species_Shark_Crest` | [L] | Leviathan crest for tier 7, attached to `Sock_Crest`: the `Fish` back sail, kept low in front of the tall dorsal fin (document 06, section 3.6) | 150 tris | RIG_Fish | 0.8 | not started |
| (fit) Shark Pup on RIG_Fish | [L] | Family skeleton fitted to this body, weights for every mesh, sockets placed | — | RIG_Fish | 2.5 | not started |
| `T_Shark_Juv_Alb` | [L] | Juvenile colours: three clear values, hand-painted, eye and mouth in the standard layout | 256² | family UV layout | 2 | not started |
| `T_Shark_Adult_Alb` | [L] | Adult colours | 512² | T_Shark_Juv_Alb | 3 | not started |
| `T_Shark_PatSandbar_Juv_Alb, _Adult_Alb` | [L] | Pattern `pat_shark_sandbar`: sandy tan back, white belly. Large colour areas only, never bands, dots or glow | 256² and 512² | base textures | 2 | not started |
| `T_Shark_PatStorm_Juv_Alb, _Adult_Alb` | [L] | Pattern `pat_shark_storm`: dark slate back, light grey fin tips, pale belly. Large colour areas only, never bands, dots or glow | 256² and 512² | base textures | 2 | not started |
| `T_Shark_PatBubble_Juv_Alb, _Adult_Alb` | [L] | Pattern `pat_shark_bubble`: "Bubble Blue": bright blue back, white belly, yellow eyes. Large colour areas only, never bands, dots or glow | 256² and 512² | base textures | 2 | not started |
| (check) Fish clips on the Shark Pup | [L] | Play the whole `A_Fish_*` set on this body and fix poses that break | — | A_Fish_* | 1.5 | not started |
| `A_Shark_RampageStart` | [L] | Head shake and jaw snap when Rampage triggers | 15 frames | RIG_Fish | 0.8 | not started |
| `A_Shark_Fidget` | [L] | Cove fidget: snaps at a passing bubble | 45 frames | RIG_Fish | 1 | not started |

Patterns follow the 18 briefs in document 03, section 1.3. Document 05, section 8.5 uses the same 18 IDs and says how each is obtained: six free through the Codex, one in the Starter Pack and eleven for Robux.

### 2.8 Post-launch species

Planned order from canon section 7, tags from document 03. Each row bundles the same asset set a launch species has, including both outline shells for every body mesh; the bundle is split into single rows when the species is scheduled. Names use the species ID from canon section 16.

| Asset | Tag | Description | Qty | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|---|
| `M_Species_Anglerfish_*` | [P1] | Anglerfish: juvenile, adult, distance versions, `_Shell` and `_ShellThick` outline shells, and crest. Family `Fish` | 13 | as launch species | family base mesh | 12 | not started |
| `T_Anglerfish_*` | [P1] | Juvenile and adult colour textures and three patterns | 8 | 256² and 512² | — | 9 | not started |
| (rig) Anglerfish | [P1] | Skeleton and clips: the lure is a small glowing mesh on a stalk bone | 1 | — | — | 3 | not started |
| `A_Anglerfish_*` | [P1] | Cove fidget and ability clips. Ability: Lure | 3 | — | — | 3 | not started |
| (traits) Anglerfish | [P1] | Trait piece placement and overlay check; a new family also needs its 11 overlays | 1 | — | section 3 | 2 | not started |
| (bundle) Anglerfish effects and sounds | [P1] | Ability effects (about 2) and sounds: three voice blips plus ability sounds | 7 | — | — | 4 | not started |
| `M_Species_Manta_*` | [P1] | Manta Ray: juvenile, adult, distance versions, `_Shell` and `_ShellThick` outline shells, and crest. Family `Ray (new)` | 13 | as launch species | family base mesh | 12 | not started |
| `T_Manta_*` | [P1] | Juvenile and adult colour textures and three patterns | 8 | 256² and 512² | — | 9 | not started |
| (rig) Manta Ray | [P1] | Skeleton and clips: wide wings need a fifth family: skeleton, 14 clips, 11 overlays | 1 | — | — | 22 | not started |
| `A_Manta_*` | [P1] | Cove fidget and ability clips. Ability: Glide | 3 | — | — | 3 | not started |
| (traits) Manta Ray | [P1] | Trait piece placement and overlay check; a new family also needs its 11 overlays | 1 | — | section 3 | 14 | not started |
| (bundle) Manta Ray effects and sounds | [P1] | Ability effects (about 2) and sounds: three voice blips plus ability sounds | 7 | — | — | 4 | not started |
| `M_Species_Seahorse_*` | [P2] | Seahorse: juvenile, adult, distance versions, `_Shell` and `_ShellThick` outline shells, and crest. Family `Upright (new)` | 13 | as launch species | family base mesh | 12 | not started |
| `T_Seahorse_*` | [P2] | Juvenile and adult colour textures and three patterns | 8 | 256² and 512² | — | 9 | not started |
| (rig) Seahorse | [P2] | Skeleton and clips: upright body needs a sixth family | 1 | — | — | 22 | not started |
| `A_Seahorse_*` | [P2] | Cove fidget and ability clips. Ability: see document 03 | 3 | — | — | 3 | not started |
| (traits) Seahorse | [P2] | Trait piece placement and overlay check; a new family also needs its 11 overlays | 1 | — | section 3 | 14 | not started |
| (bundle) Seahorse effects and sounds | [P2] | Ability effects (about 2) and sounds: three voice blips plus ability sounds | 7 | — | — | 4 | not started |
| `M_Species_Axolotl_*` | [P2] | Axolotl: juvenile, adult, distance versions, `_Shell` and `_ShellThick` outline shells, and crest. Family `Eel` | 13 | as launch species | family base mesh | 12 | not started |
| `T_Axolotl_*` | [P2] | Juvenile and adult colour textures and three patterns | 8 | 256² and 512² | — | 9 | not started |
| (rig) Axolotl | [P2] | Skeleton and clips: four small legs and six gill frills added to the `Eel` skeleton | 1 | — | — | 4 | not started |
| `A_Axolotl_*` | [P2] | Cove fidget and ability clips. Ability: Regrow | 3 | — | — | 3 | not started |
| (traits) Axolotl | [P2] | Trait piece placement and overlay check; a new family also needs its 11 overlays | 1 | — | section 3 | 2 | not started |
| (bundle) Axolotl effects and sounds | [P2] | Ability effects (about 2) and sounds: three voice blips plus ability sounds | 7 | — | — | 4 | not started |
| `M_Species_Orca_*` | [P2] | Orca Calf: juvenile, adult, distance versions, `_Shell` and `_ShellThick` outline shells, and crest. Family `Fish` | 13 | as launch species | family base mesh | 12 | not started |
| `T_Orca_*` | [P2] | Juvenile and adult colour textures and three patterns | 8 | 256² and 512² | — | 9 | not started |
| (rig) Orca Calf | [P2] | Skeleton and clips: fits the `Fish` family | 1 | — | — | 3 | not started |
| `A_Orca_*` | [P2] | Cove fidget and ability clips. Ability: see document 03 | 3 | — | — | 3 | not started |
| (traits) Orca Calf | [P2] | Trait piece placement and overlay check; a new family also needs its 11 overlays | 1 | — | section 3 | 2 | not started |
| (bundle) Orca Calf effects and sounds | [P2] | Ability effects (about 2) and sounds: three voice blips plus ability sounds | 7 | — | — | 4 | not started |
| `M_Species_Narwhal_*` | [P2] | Narwhal: juvenile, adult, distance versions, `_Shell` and `_ShellThick` outline shells, and crest. Family `Fish` | 13 | as launch species | family base mesh | 12 | not started |
| `T_Narwhal_*` | [P2] | Juvenile and adult colour textures and three patterns | 8 | 256² and 512² | — | 9 | not started |
| (rig) Narwhal | [P2] | Skeleton and clips: fits the `Fish` family; the tusk is part of the mesh | 1 | — | — | 3 | not started |
| `A_Narwhal_*` | [P2] | Cove fidget and ability clips. Ability: see document 03 | 3 | — | — | 3 | not started |
| (traits) Narwhal | [P2] | Trait piece placement and overlay check; a new family also needs its 11 overlays | 1 | — | section 3 | 2 | not started |
| (bundle) Narwhal effects and sounds | [P2] | Ability effects (about 2) and sounds: three voice blips plus ability sounds | 7 | — | — | 4 | not started |

## 3. Trait visuals

Document 06 (section 8) gives every trait one of three channels so three traits can share a body:

- **Pattern** and **Light** traits are **overlay textures** in the family UV layout: one per trait per family, 256 × 256. Each row below is two files, the home zone and the fallback zone (used when two traits share a channel; the second file adds `_Fallback`, section 1.2). Each trait has one scripted Blender master; the `Fish` row carries the hours for that master and the other families are bakes from it with touch-ups.
- **Form** traits are **kit pieces**: small rigid meshes attached to socket bones. One set of pieces serves every family; a placement table per species says which sockets, how many and at what scale.

An overlay row is tagged with the later of its trait tag and its family tag. All gain and shed effects are shared (`FX_TraitGain`, `FX_TraitShed`). Trait icons belong to document 08.

### 3.0 Kit pieces, placement and checks

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `M_Trait_Plated_Plate` | [MVP] | Plated: one plate, used five times along the back | 60 tris | T_Trait_Pieces_Alb | 0.8 | not started |
| `M_Trait_Plated_PlateCracked` | [MVP] | Plated: the same plate cracked; swapped in after the plates save the creature | 60 tris | T_Trait_Pieces_Alb | 0.4 | not started |
| `M_Trait_Plated_Helmet` | [MVP] | Plated, fallback zone: one helmet plate on the head | 80 tris | T_Trait_Pieces_Alb | 0.6 | not started |
| `M_Trait_Spiny_Spine` | [MVP] | Spiny: one cream spine with a red tip, used nine times (three on the tail in the fallback zone) | 20 tris | T_Trait_Pieces_Alb | 0.4 | not started |
| `M_Trait_Longfin_RibbonTail` | [MVP] | Longfin: trailing ribbon for the tail fin tip, in the species accent colour by tint | 80 tris | T_Trait_Pieces_Alb | 0.8 | not started |
| `M_Trait_Longfin_RibbonFin` | [MVP] | Longfin: shorter ribbon for the back fin and side fin tips | 80 tris | T_Trait_Pieces_Alb | 0.6 | not started |
| `M_Trait_Crystal_Shard_01–03` | [MVP] | Crystal: three hard-edged shards that form a crown on the back | 30 tris each | T_Trait_Pieces_Alb | 1 | not started |
| `M_Trait_Camo_Leaf_01–02` | [L] | Camo: two leafy frills for the back and fin edges, swayed by the sway code | 40 tris each | T_Trait_Pieces_Alb | 1 | not started |
| `T_Trait_Pieces_Alb` | [MVP] | One atlas for every kit piece; the leaf cells are painted at launch | 256² | — | 2.5 | not started |
| (placement) Trait pieces on the Minnow | [MVP] | Socket, count and scale for each of the five piece traits, home and fallback zones, on juvenile and adult | — | RIG_Fish | 1.5 | not started |
| (placement) Trait pieces on the Pufferfish | [MVP] | Socket, count and scale for each of the five piece traits, home and fallback zones, on juvenile and adult | — | RIG_Fish | 1.5 | not started |
| (placement) Trait pieces on the Eel | [MVP] | Socket, count and scale for each of the five piece traits, home and fallback zones, on juvenile and adult | — | RIG_Eel | 1.5 | not started |
| (placement) Trait pieces on the Sea Turtle | [L] | Socket, count and scale for each of the five piece traits, home and fallback zones, on juvenile and adult | — | RIG_Turtle | 1.5 | not started |
| (placement) Trait pieces on the Squid | [L] | Socket, count and scale for each of the five piece traits, home and fallback zones, on juvenile and adult | — | RIG_Squid | 1.5 | not started |
| (placement) Trait pieces on the Shark Pup | [L] | Socket, count and scale for each of the five piece traits, home and fallback zones, on juvenile and adult | — | RIG_Fish | 1.5 | not started |
| (check) Trait combination sheet, soft launch | [MVP] | Render the 12 hardest trait triples on Minnow, Pufferfish and Eel; fix pieces that clip and overlays that hide each other (document 06, section 8.3) | — | all MVP trait rows | 3 | not started |
| (check) Trait combination sheet, launch | [L] | The same with the four launch traits and on Sea Turtle, Squid and Shark Pup | — | all launch trait rows | 3 | not started |

### 3.1 Overlays by trait

Spiny and Longfin have no overlay; they are kit pieces only.

**Glow** (`glow`, [MVP], Light channel). Effects: `FX_GlowAura`, plus a light set in code.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `T_Trait_Glow_Fish_Emi`, `T_Trait_Glow_Fish_Fallback_Emi` | [MVP] | Glow band along the lateral line, nose to tail. Includes the scripted master | 256², glow mask; 2 files | M_Species_Base_Fish | 2.5 | not started |
| `T_Trait_Glow_Eel_Emi` | [MVP] | Bake from the master onto the `Eel` layout and touch up | 256², glow mask; 2 files | M_Species_Base_Eel | 1 | not started |
| `T_Trait_Glow_Turtle_Emi` | [L] | Bake from the master onto the `Turtle` layout and touch up | 256², glow mask; 2 files | M_Species_Base_Turtle | 1 | not started |
| `T_Trait_Glow_Squid_Emi` | [L] | Bake from the master onto the `Squid` layout and touch up | 256², glow mask; 2 files | M_Species_Base_Squid | 1 | not started |

**Stripes** (`stripes`, [MVP], Pattern channel). Effects: none.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `T_Trait_Stripes_Fish_Alb` | [MVP] | Four bold bands on the flank. Includes the scripted master | 256², with alpha; 2 files | M_Species_Base_Fish | 2.5 | not started |
| `T_Trait_Stripes_Eel_Alb` | [MVP] | Bake from the master onto the `Eel` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Eel | 1 | not started |
| `T_Trait_Stripes_Turtle_Alb` | [L] | Bake from the master onto the `Turtle` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Turtle | 1 | not started |
| `T_Trait_Stripes_Squid_Alb` | [L] | Bake from the master onto the `Squid` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Squid | 1 | not started |

**Spots** (`spots`, [MVP], Pattern channel). Effects: none.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `T_Trait_Spots_Fish_Alb` | [MVP] | Seven to nine ringed dots on the back and flank. Includes the scripted master | 256², with alpha; 2 files | M_Species_Base_Fish | 2.5 | not started |
| `T_Trait_Spots_Eel_Alb` | [MVP] | Bake from the master onto the `Eel` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Eel | 1 | not started |
| `T_Trait_Spots_Turtle_Alb` | [L] | Bake from the master onto the `Turtle` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Turtle | 1 | not started |
| `T_Trait_Spots_Squid_Alb` | [L] | Bake from the master onto the `Squid` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Squid | 1 | not started |

**Plated** (`plated`, [MVP], Form channel). Effects: `FX_PlateCrack`.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `T_Trait_Plated_Fish_Alb` | [MVP] | Thin plate seams and rivet shadows under the plates. Includes the scripted master | 256², with alpha; 2 files | M_Species_Base_Fish | 1.5 | not started |
| `T_Trait_Plated_Eel_Alb` | [MVP] | Bake from the master onto the `Eel` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Eel | 0.6 | not started |
| `T_Trait_Plated_Turtle_Alb` | [L] | Bake from the master onto the `Turtle` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Turtle | 0.6 | not started |
| `T_Trait_Plated_Squid_Alb` | [L] | Bake from the master onto the `Squid` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Squid | 0.6 | not started |

**Ink** (`ink`, [MVP], Pattern channel). Effects: `FX_InkCloud`.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `T_Trait_Ink_Fish_Alb` | [MVP] | Blue-black blotches rising like smoke over the belly and rear half. Includes the scripted master | 256², with alpha; 2 files | M_Species_Base_Fish | 2.5 | not started |
| `T_Trait_Ink_Eel_Alb` | [MVP] | Bake from the master onto the `Eel` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Eel | 1 | not started |
| `T_Trait_Ink_Turtle_Alb` | [L] | Bake from the master onto the `Turtle` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Turtle | 1 | not started |
| `T_Trait_Ink_Squid_Alb` | [L] | Bake from the master onto the `Squid` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Squid | 1 | not started |

**Spark** (`spark`, [L], Light channel). Effects: `FX_SparkArc`, `FX_SparkStun`.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `T_Trait_Spark_Fish_Emi` | [L] | Zigzag lines from the head back, in three frames swapped ten times a second. Includes the scripted master | 256², glow mask; 6 files | M_Species_Base_Fish | 3.5 | not started |
| `T_Trait_Spark_Eel_Emi` | [L] | Bake from the master onto the `Eel` layout and touch up | 256², glow mask; 6 files | M_Species_Base_Eel | 1.5 | not started |
| `T_Trait_Spark_Turtle_Emi` | [L] | Bake from the master onto the `Turtle` layout and touch up | 256², glow mask; 6 files | M_Species_Base_Turtle | 1.5 | not started |
| `T_Trait_Spark_Squid_Emi` | [L] | Bake from the master onto the `Squid` layout and touch up | 256², glow mask; 6 files | M_Species_Base_Squid | 1.5 | not started |

**Camo** (`camo`, [L], Form channel). Effects: `FX_CamoShimmer`.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `T_Trait_Camo_Fish_Alb` | [L] | Leaf-vein mottling in green and tan. Includes the scripted master | 256², with alpha; 2 files | M_Species_Base_Fish | 1.5 | not started |
| `T_Trait_Camo_Eel_Alb` | [L] | Bake from the master onto the `Eel` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Eel | 0.6 | not started |
| `T_Trait_Camo_Turtle_Alb` | [L] | Bake from the master onto the `Turtle` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Turtle | 0.6 | not started |
| `T_Trait_Camo_Squid_Alb` | [L] | Bake from the master onto the `Squid` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Squid | 0.6 | not started |

**Crystal** (`crystal`, [MVP], Form channel). Effects: `FX_CrystalGlint`, `FX_CrystalBankBonus`.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `T_Trait_Crystal_Fish_Alb` | [MVP] | Faceted patches that read as cut gem. Includes the scripted master | 256², with alpha; 2 files | M_Species_Base_Fish | 2.5 | not started |
| `T_Trait_Crystal_Eel_Alb` | [MVP] | Bake from the master onto the `Eel` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Eel | 1 | not started |
| `T_Trait_Crystal_Turtle_Alb` | [L] | Bake from the master onto the `Turtle` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Turtle | 1 | not started |
| `T_Trait_Crystal_Squid_Alb` | [L] | Bake from the master onto the `Squid` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Squid | 1 | not started |

**Ember** (`ember`, [L], Light channel). Effects: `FX_EmberMotes`, `FX_EmberShrug`.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `T_Trait_Ember_Fish_Emi` | [L] | Glowing cracks across the back and flank. Includes the scripted master | 256², glow mask; 2 files | M_Species_Base_Fish | 2.5 | not started |
| `T_Trait_Ember_Eel_Emi` | [L] | Bake from the master onto the `Eel` layout and touch up | 256², glow mask; 2 files | M_Species_Base_Eel | 1 | not started |
| `T_Trait_Ember_Turtle_Emi` | [L] | Bake from the master onto the `Turtle` layout and touch up | 256², glow mask; 2 files | M_Species_Base_Turtle | 1 | not started |
| `T_Trait_Ember_Squid_Emi` | [L] | Bake from the master onto the `Squid` layout and touch up | 256², glow mask; 2 files | M_Species_Base_Squid | 1 | not started |

**Moonlit** (`moonlit`, [MVP], Light channel). Effects: `FX_MoonlitAura`, `FX_MoonlitPull`, plus a light set in code.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `T_Trait_Moonlit_Fish_Emi` | [MVP] | Silver rim around the whole outline, brightest on the back. Includes the scripted master | 256², glow mask; 2 files | M_Species_Base_Fish | 2.5 | not started |
| `T_Trait_Moonlit_Eel_Emi` | [MVP] | Bake from the master onto the `Eel` layout and touch up | 256², glow mask; 2 files | M_Species_Base_Eel | 1 | not started |
| `T_Trait_Moonlit_Turtle_Emi` | [L] | Bake from the master onto the `Turtle` layout and touch up | 256², glow mask; 2 files | M_Species_Base_Turtle | 1 | not started |
| `T_Trait_Moonlit_Squid_Emi` | [L] | Bake from the master onto the `Squid` layout and touch up | 256², glow mask; 2 files | M_Species_Base_Squid | 1 | not started |

**Bonefed** (`bonefed`, [L], Pattern channel). Effects: `FX_BonefedAura`.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `T_Trait_Bonefed_Fish_Alb` | [L] | A friendly cartoon skeleton: spine, ribs and a smiling skull mask. A costume, not a corpse. Includes the scripted master | 256², with alpha; 2 files | M_Species_Base_Fish | 3 | not started |
| `T_Trait_Bonefed_Eel_Alb` | [L] | Bake from the master onto the `Eel` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Eel | 2 | not started |
| `T_Trait_Bonefed_Turtle_Alb` | [L] | Bake from the master onto the `Turtle` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Turtle | 2 | not started |
| `T_Trait_Bonefed_Squid_Alb` | [L] | Bake from the master onto the `Squid` layout and touch up | 256², with alpha; 2 files | M_Species_Base_Squid | 2 | not started |

## 4. Prey

Prey are data on the server and are drawn by each client (canon section 14). A phone may have several hundred in view, so prey art is built to be cheap (document 06, sections 6.3, 6.4 and 7.6):

1. **Small prey are rigid.** Plankton is a two-triangle dot. Krill, Tiny Shrimp and Sardine have no bones; the client moves the whole mesh with a small wobble, and the shared motion of the school does the rest.
2. **Identical meshes with one texture are drawn in one batch.** A Feeding Frenzy bait ball of 40 Sardines is 40 copies of one 150-triangle mesh.
3. **Bigger prey (tier 3 and up) have three or four bones** moved by the same sway code as the players. They need no clips.
4. **Distance:** prey of tier 3 and up have a quarter-triangle rigid version (`_LOD2`); every prey becomes a single dot (`FX_Glint`) when it is very small on screen.
5. **Every prey of tier 1 or more has an outline shell** (`_Shell`), 10% of body height thick so the green line survives at small size. Prey never eat a player, so they need no thick shell. Plankton has none.

No prey has an authored clip. The motion of each one is a row of settings in the prey motion table (document 06, section 7.6, data:PreyMotion). Being eaten is an effect (`FX_BubblePop_…`).

### 4.0 Shared prey rigs, settings and textures

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `RIG_Prey3` | [MVP] | Three sway bones for fish-shaped prey of tier 3 and up; the Tuna adds a fourth | 3 or 4 bones | — | 1 | not started |
| `RIG_PreyRibbon4` | [MVP] | Four-bone chain for long bodies: Ribbonfish, Spark Eel | 4 bones | — | 0.8 | not started |
| `RIG_PreyBlob4` | [MVP] | Centre and three rim bones for pulse and squash: Urchin Puff, Inklet, Crystal Jelly | 4 bones | — | 1 | not started |
| (data) Prey motion table | [MVP] | For each of the 21 prey: wobble or sway speed and size, hop arc, pulse rate, flee settings. Tuned in the game | 21 entries; the table is `data:PreyMotion` in document 06, section 7.6, generated to `PreyMotion` | document 03, sections 2.1, 2.2 and 3.1 | 3 | not started |
| `T_PreySmall_Alb` | [MVP] | One atlas for prey tiers 0 to 2: three Plankton dots, Krill, Tiny Shrimp, Sardine | 256² | — | 2 | not started |
| `T_PreyLarge_Alb` | [MVP] | Four 128 × 128 cells: Reef Darter, Mackerel, Bonito, Tuna | 256² | — | 2.5 | not started |
| `T_TraitPrey_01_Alb` | [MVP] | Four cells: Glowfry, Zebra Darter, Dotted Goby, Lunar Fry | 256² | — | 2.5 | not started |
| `T_TraitPrey_02_Alb` | [MVP] | Four cells: Armor Shrimp, Urchin Puff, Ribbonfish, Inklet | 256² | — | 2.5 | not started |
| `T_TraitPrey_03_Alb` | [MVP] | Crystal Jelly at soft launch; three cells left for launch | 256² | — | 1 | not started |
| (update) T_TraitPrey_03_Alb launch cells | [L] | Add Spark Eel, Leaf Drifter and Vent Snail | — | T_TraitPrey_03_Alb | 1.8 | not started |
| `T_TraitPrey_04_Alb` | [L] | Three Marrow chunks; one cell spare | 256² | — | 0.8 | not started |
| `T_TraitPrey_Emi` | [MVP] | Glow masks for Glowfry, Lunar Fry and Crystal Jelly; Spark Eel, Vent Snail and Marrow added at launch. Each mask sits in its prey's albedo cell place: Glowfry top-left, Crystal Jelly top-right, Lunar Fry bottom-right (task S6-A1) | 256² | trait prey atlases | 1.2 | not started |
| `M_Prey_*_Shell` | [MVP] | Outline shells for the seven prey of tier 1 or more, by script. Prey only ever show the green "you can eat it" outline, so there is no thick shell. Plankton has none | 80 to 360 tris by tier (document 06, section 6.3) | prey meshes | 1.5 | not started |
| `M_Prey_*_LOD2` | [MVP] | Quarter-triangle rigid versions of Reef Darter, Mackerel, Bonito and Tuna, each with its `_LOD2_Shell` | quarter; shells 80 tris or a quarter of the full shell, whichever is more (tune) | prey meshes | 1 | not started |
| `M_Prey_<trait prey>_Shell, _LOD2 (soft launch)` | [MVP] | Outline shells (green outline only) for the nine soft-launch trait prey; distance versions for the three of tier 3 | shell 40% of each body | trait prey meshes | 1.8 | not started |
| `M_Prey_<trait prey>_Shell, _LOD2 (launch)` | [L] | Outline shells (green outline only) and distance versions for Spark Eel, Leaf Drifter and Vent Snail; shells for the three Marrow chunks | shell 40% of each body | trait prey meshes | 1.2 | not started |

### 4.1 Prey

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `M_Prey_Plankton` | [MVP] | Plankton mote, tier 0. A camera-facing dot in three shapes; drifts. Gold-white in a Feeding Frenzy, cyan in a Moon Tide (tint) | 2 tris | T_PreySmall_Alb | 0.3 | not started |
| `M_Prey_Krill` | [MVP] | Krill, tier 1. Pink comma with a leg fringe. Rigid; swarms of 12 to 20 that scatter | 60 tris | T_PreySmall_Alb | 1 | not started |
| `M_Prey_Shrimp` | [MVP] | Tiny Shrimp, tier 1. Curled body, long feelers. Rigid; hops along the bottom | 120 tris | T_PreySmall_Alb | 1.2 | not started |
| `M_Prey_Sardine` | [MVP] | Sardine, tier 2. Slim silver-blue fish, half as chunky as a Minnow. Rigid; tight schools of 8 to 14 | 150 tris | T_PreySmall_Alb | 1.2 | not started |
| `M_Prey_Darter` | [MVP] | Reef Darter, tier 3. Short and tall-finned; quick turns | 300 tris, 3 bones | RIG_Prey3, T_PreyLarge_Alb | 1.5 | not started |
| `M_Prey_Mackerel` | [MVP] | Mackerel, tier 4. Long with a striped back; straight runs | 450 tris, 3 bones | RIG_Prey3, T_PreyLarge_Alb | 1.5 | not started |
| `M_Prey_Bonito` | [MVP] | Bonito, tier 5. Thick body, crescent tail; packs of 3 to 5 | 600 tris, 3 bones | RIG_Prey3, T_PreyLarge_Alb | 1.8 | not started |
| `M_Prey_Tuna` | [MVP] | Tuna, tier 6. The biggest prey: deep body, yellow finlets | 900 tris, 4 bones | RIG_Prey3, T_PreyLarge_Alb | 2.2 | not started |

### 4.2 Trait prey

Always single animals. Each has a silhouette no plain prey has and two small sparkles in its rarity colour (`FX_TraitSparkle`), so it reads as special without text. Budget from document 06: 300 to 700 triangles, up to four bones.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `M_Prey_Glowfry` | [MVP] | Glowfry, tier 1, gives Glow. Tiny round fry with a lit belly. Rigid | 410 tris (S6-A1: a round body needs 16 sides; 06 §6.3 allows 300 to 700) | T_TraitPrey_01_Alb, T_TraitPrey_Emi | 1.2 | not started |
| `M_Prey_ZebraDarter` | [MVP] | Zebra Darter, tier 2, gives Stripes. Reef Darter body with a taller fin and bold bands | 300 tris, 3 bones | M_Prey_Darter, T_TraitPrey_01_Alb | 0.8 | not started |
| `M_Prey_DottedGoby` | [MVP] | Dotted Goby, tier 1, gives Spots. Big-headed bottom sitter. Rigid; hops on the sand | 300 tris | T_TraitPrey_01_Alb | 1.2 | not started |
| `M_Prey_LunarFry` | [MVP] | Lunar Fry, tier 2, gives Moonlit. Glowfry body with a crescent tail, silver. The brightest thing in the sea; Moon Tide only | 300 tris | M_Prey_Glowfry, FX_LunarFryTrail | 0.8 | not started |
| `M_Prey_ArmorShrimp` | [MVP] | Armor Shrimp, tier 2, gives Plated. Shrimp body under chunky plates. Rigid | 350 tris | M_Prey_Shrimp, T_TraitPrey_02_Alb | 1.2 | not started |
| `M_Prey_UrchinPuff` | [MVP] | Urchin Puff, tier 2, gives Spiny. Spiky ball with a face; must not read as a Pufferfish | 400 tris, 4 bones | RIG_PreyBlob4, T_TraitPrey_02_Alb | 1.5 | not started |
| `M_Prey_Ribbonfish` | [MVP] | Ribbonfish, tier 3, gives Longfin. Long flat body with trailing fins | 400 tris, 4 bones | RIG_PreyRibbon4, T_TraitPrey_02_Alb | 1.5 | not started |
| `M_Prey_Inklet` | [MVP] | Inklet, tier 3, gives Ink. Baby squid with a big head; puffs ink when it flees | 450 tris, 4 bones | RIG_PreyBlob4, FX_InkletPuff | 1.5 | not started |
| `M_Prey_CrystalJelly` | [MVP] | Crystal Jelly, tier 3, gives Crystal. Faceted bell with short ribbon arms; roams all zones | 500 tris, 4 bones | RIG_PreyBlob4, T_TraitPrey_03_Alb | 2 | not started |
| `M_Prey_SparkEel` | [L] | Spark Eel, tier 4, gives Spark. Thin eel with lit zigzag lines | 450 tris, 4 bones | RIG_PreyRibbon4, T_TraitPrey_03_Alb | 1.5 | not started |
| `M_Prey_LeafDrifter` | [L] | Leaf Drifter, tier 3, gives Camo. Leafy sea-dragon shape that hides among kelp leaves | 600 tris, 3 bones | RIG_Prey3, T_TraitPrey_03_Alb | 2 | not started |
| `M_Prey_VentSnail` | [L] | Vent Snail, tier 4, gives Ember. Dark shell with glowing cracks; crawls by stretch and pull | 500 tris, 2 bones | T_TraitPrey_03_Alb | 1.5 | not started |
| `M_Prey_Marrow_01–03` | [L] | Marrow chunk, tier 3, gives Bonefed. Three puffy cream-white pieces, clean and toy-like, with a soft white glow. No red, no flesh. Rigid; drifts up from the ribs. Whale Fall only | 300 tris each | T_TraitPrey_04_Alb, FX_MarrowGlow | 1.5 | not started |

## 5. Predators and hazards

Predators read as danger from silhouette alone: triangles and wedges, darker values, small eyes, visible teeth (document 06, section 3.4). They take no traits, so they may break the family UV layout. Their swimming uses the same sway code as the players; the clips below are actions. Effects are in section 9 and sounds in section 11.

Every predator has the thick `_ShellThick` shell for the red "it can eat you" outline. A player one tier higher can eat a Barracuda or a Grouper (canon section 5.2), so those two also have the standard `_Shell` for the green outline. The Gull, the Moray and Old Scar cannot be eaten and have only the thick one.

### 5.1 Gull (`gull`) [MVP]

A rigid two-pose model moved by code, seen mostly from below. Effects: `FX_GullShadow`, `FX_GullDiveSplash`, `FX_GullFeathers`.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `M_Pred_Gull_Glide` | [MVP] | Chunky seabird with an oversized beak, wings spread. Sits on Gull Rock and circles | 800 tris | — | 4 | not started |
| `M_Pred_Gull_Dive` | [MVP] | The same bird with wings folded and beak forward | 800 tris | M_Pred_Gull_Glide | 1.5 | not started |
| `M_Pred_Gull_*_ShellThick` | [MVP] | Thick red-outline shell for each pose, by script. The Gull cannot be eaten, so it has no green shell | 320 tris each | both poses | 0.5 | not started |
| `T_Gull_Alb` | [MVP] | White and grey with an orange beak | 512² | — | 2.5 | not started |
| `T_Gull_Shadow_Mask` | [MVP] | Dark oval for the surface shadow that shrinks and darkens for 1.5 s before the dive | 256² | — | 0.3 | not started |

### 5.2 Moray (`moray`) [MVP]

Lives in the holes of Peekaboo Ridge and the root mounds (section 6). Effects: `FX_MorayGlint`, `FX_MorayLunge`, `FX_PredBite`.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `M_Pred_Moray` | [MVP] | Angular, mustard-coloured eel with an underbite and teeth; the opposite of the playable Eel | 2,000 tris | — | 5 | not started |
| `RIG_Moray` | [MVP] | Spine chain, jaw, eyes | 12 bones | M_Pred_Moray | 3 | not started |
| `T_Moray_Alb` | [MVP] | Mustard with dark mottling | 512² | — | 3 | not started |
| `M_Pred_Moray_LOD1, _LOD2, _ShellThick` | [MVP] | Distance versions, and the thick red-outline shell with its own distance versions, by script. The Moray cannot be eaten, so it has no green shell | half and quarter; shell 800 tris | M_Pred_Moray | 1 | not started |
| `A_Moray_Lurk` | [MVP] | Head in the hole, jaw working | loop 90 frames | RIG_Moray | 0.8 | not started |
| `A_Moray_Warn` | [MVP] | Twitch and eye flash: the warning before every lunge | 12 frames | RIG_Moray | 0.6 | not started |
| `A_Moray_Lunge` | [MVP] | Shoot out of the hole | 12 frames | RIG_Moray | 1 | not started |
| `A_Moray_Catch` | [MVP] | Bite and pull back in | 24 frames | RIG_Moray | 0.8 | not started |
| `A_Moray_Retract` | [MVP] | Miss and slide back | 24 frames | RIG_Moray | 0.6 | not started |

### 5.3 Barracuda (`barracuda`) [MVP]

Effects: `FX_BarracudaStreak`, `FX_PredBite`.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `M_Pred_Barracuda` | [MVP] | Long silver spear of a fish with a jutting lower jaw | 2,000 tris | M_Species_Base_Fish | 4.5 | not started |
| `RIG_Barracuda` | [MVP] | Longer spine than the `Fish` family, jaw, eyes, fins | 12 bones | M_Pred_Barracuda | 2.5 | not started |
| `T_Barracuda_Alb` | [MVP] | Steel blue with dark bars | 512² | — | 3 | not started |
| `M_Pred_Barracuda_LOD1, _LOD2, _Shell, _ShellThick` | [MVP] | Distance versions, and two outline shells with their own distance versions, by script: the thick one for the red outline and the standard one for the green outline that a player one tier higher sees (canon section 5.2) | half and quarter; shells 800 tris | M_Pred_Barracuda | 1 | not started |
| `A_Barracuda_Burst` | [MVP] | Explodes out of a rock shadow to start a chase | 15 frames | RIG_Barracuda | 0.8 | not started |
| `A_Barracuda_Bite` | [MVP] | Lunge and jaw snap | 9 frames | RIG_Barracuda | 0.6 | not started |
| `A_Barracuda_GiveUp` | [MVP] | After 6 s: clips a coral branch with a comic bonk, shakes its head, peels away | 36 frames | RIG_Barracuda | 1 | not started |

### 5.4 Grouper (`grouper`) [L]

Effects: `FX_GrouperSuction`, `FX_PredBite`.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `M_Pred_Grouper` | [L] | Heavy, wide-mouthed fish that is mostly mouth | 3,500 tris | — | 6 | not started |
| `RIG_Grouper` | [L] | Short spine, wide two-part jaw, throat bones that slide out when it sucks, fins, eyes | 14 bones | M_Pred_Grouper | 4 | not started |
| `T_Grouper_Alb` | [L] | Brown and cream blotches | 512² | — | 3 | not started |
| `M_Pred_Grouper_LOD1, _LOD2, _Shell, _ShellThick` | [L] | Distance versions, and two outline shells with their own distance versions, by script: the thick one for the red outline and the standard one for the green outline that a player one tier higher sees (canon section 5.2) | half and quarter; shells 1,400 tris | M_Pred_Grouper | 1 | not started |
| `A_Grouper_Drift` | [L] | Hang in place, fins sculling | loop 90 frames | RIG_Grouper | 0.8 | not started |
| `A_Grouper_SuckStart` | [L] | Mouth yawns open: the warning | 12 frames | RIG_Grouper | 0.8 | not started |
| `A_Grouper_SuckLoop` | [L] | Mouth held open, throat pumping | loop 24 frames | RIG_Grouper | 0.6 | not started |
| `A_Grouper_Gulp` | [L] | Snap shut | 12 frames | RIG_Grouper | 0.8 | not started |

### 5.5 Old Scar (`old_scar`) [MVP]

The one hero predator; its outline shows before its body does. Effects: `FX_OldScarWake`, `FX_PredBite`.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `M_Pred_OldScar` | [MVP] | Great white with a pale healed scar across the upper lip and one eye, and a notched back fin. Simple toy-like teeth. The biggest moving thing in the game | 8,000 tris | — | 10 | not started |
| `RIG_OldScar` | [MVP] | Spine 8, two-part jaw, gills, eyes, all fins | 24 bones | M_Pred_OldScar | 4 | not started |
| `T_OldScar_Alb` | [MVP] | Grey over white, scar, tooth rows. No red in the mouth | 1024² | — | 5 | not started |
| `M_Pred_OldScar_LOD1, _LOD2, _ShellThick` | [MVP] | Distance versions, and the thick red-outline shell with its own distance versions, by script. Old Scar cannot be eaten, so it has no green shell | half and quarter; shell 2,400 tris | M_Pred_OldScar | 1 | not started |
| `A_OldScar_Alert` | [MVP] | Head swing and jaw gape when it picks a target: the warning | 24 frames | RIG_OldScar | 1 | not started |
| `A_OldScar_Bite` | [MVP] | Lunging bite | 15 frames | RIG_OldScar | 1 | not started |
| `A_OldScar_Feed` | [L] | Circling nudge at the whale skeleton during Whale Fall | loop 60 frames | RIG_OldScar | 1 | not started |

### 5.6 Hazards and the helper current

Hazards have no bones and no outline shell (document 06, section 6.3); hook bait has no outline either (canon section 5.2). The thermal vents are the chimneys of the landmark "The Chimneys": cold stone at soft launch, lit at launch. Document 03, section 5.1 owns the rule: nine vents, of which the three at the centre erupt all the time and the six outer ones cycle (4 s `Dormant`, 1 s `Rumble` warning, 3 s `Erupting`), each at its own offset. The burning column is 10 studs wide and 40 tall, the same for all nine. A current is drawn with streak particles and bent sea grass only (`FX_Current`). Effects: `FX_JellySting`, `FX_AnemoneSlow`, `FX_VentRumble`, `FX_VentPlume`, `FX_VentBurn`, `FX_HookGlint`, `FX_HookYank`, `FX_Current`, `FX_CurrentEntry`.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `M_Hazard_Jelly_Open, _Squeezed` | [MVP] | Jelly bloom member in two poses, swapped for the pulse: round pink bell, solid ribbon arms. Brighter in a Moon Tide | 300 tris each | — | 2.5 | not started |
| `T_Jelly_Alb` | [MVP] | Pink-violet bell and arms | 256² | — | 1.5 | not started |
| `T_Jelly_Emi` | [MVP] | Glow mask for the bell rim | 128² | T_Jelly_Alb | 0.4 | not started |
| `M_Hazard_Anemone_01–03` | [L] | Soft candy-coloured anemones in three sizes for Tickle Garden. Colour by tint | 400 tris each | — | 3.5 | not started |
| `T_Anemone_Alb` | [L] | One sheet for the three meshes | 256² | — | 1.5 | not started |
| `M_Hazard_Vent_01–03` | [MVP] | Lumpy black stone chimneys, 12 studs tall, in three shapes, each with one mouth at the top where the column rises. Nine stand within 70 studs of the centre of The Chimneys: three at the centre (always erupting at launch) and six around them (cycling) | 500 tris each | — | 4 | not started |
| `T_Vent_Alb` | [MVP] | Dark crusted stone with pale mineral rims | 256² | — | 1.5 | not started |
| `T_Vent_Emi` | [L] | Glow mask for the hot cracks and the orange rim at the top when the vents wake at launch. Code brightens it during `Rumble` | 128² | T_Vent_Alb | 0.5 | not started |
| `M_Hazard_Hook` | [MVP] | Oversized cartoon fishing hook | 150 tris | — | 1 | not started |
| `M_Hazard_Bait_01–02` | [MVP] | A fat worm and a shiny lure; rigid, jiggled in code | 120 tris each | — | 1 | not started |
| `M_Hazard_Bobber` | [MVP] | Red and white float at the surface above each hook that is not under The Snooze (document 03, section 5.2). Its red is the soft tomato `#D2564B` that document 06, section 4.5 allows, never the outline red | 120 tris | — | 0.5 | not started |
| `T_HookSet_Alb` | [MVP] | One sheet for hook, baits and bobber | 256² | — | 1.2 | not started |
| `T_FishingLine_Mask` | [MVP] | Thin line texture for the beam from the surface to the hook | 64 × 256 | — | 0.2 | not started |
| `M_Env_SeaGrass_Bent_01–02` | [MVP] | Sea grass bent over in the flow, placed along current paths | 80 tris each | T_EnvShared_Alb | 0.8 | not started |

## 6. Environment kits

The whole world is built from our own meshes; there is no Roblox terrain (document 06, section 9.1). Each zone is a small kit of pieces reused with rotation, scale (80% to 125%) and tint, because identical meshes with identical textures are drawn in one batch. One row is one kit piece; **Qty** is the number of unique meshes and the hours cover all of them. Kit counts follow document 06, section 9.2.

Landmarks use the names, keys and sizes in document 03, section 6. Each one that needs its own mesh has its own row. Landmarks that are only a place (an open flat, a clearing, a lane, a current) need no mesh; they are listed under each table so nothing looks forgotten.

Budgets from document 06: sea-floor chunk (128 × 128 studs) 3,000 triangles; cliff module (64 × 96) 2,500; coral 250, 700 or 1,800 by size; rock 120, 350 or 1,000; landmark 5,000 in all; large set piece (the Tin Pickle wreck, the Whale Fall skeleton) 15,000 at most, split into meshes of 6,000 or fewer. A landmark that is a stretch of wall or floor (Stripe Alley, Ink Pots, Hush Hollow, Slipstone Slope, The Crack) is built from cliff modules or sea-floor chunks and uses their budget for each piece. Textures: four 512 × 512 tiling grounds, one 512 × 512 atlas per zone, and a texture of its own only for the largest set pieces. Depth and distance shading on scenery comes from vertex colour.

**Assembly rows.** Placing the kit in each zone takes real time, so each zone has one *(assembly)* row. It is not an asset.

### 6.1 Shared pieces and the Rim [MVP]

| Asset | Tag | Description | Qty | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|---|
| `T_Tile_Sand_Alb, T_Tile_Rock_Alb, T_Tile_CoralRock_Alb, T_Tile_Slate_Alb` | [MVP] | The four tiling ground textures, repeating every 32 studs: sand, rock, coral rock, slate. Silt and sandstone are tints of these (`SurfaceAppearance.Color` tints shift value and hue only slightly: sand to silt, rock to kelp rock, slate to deep slate). Stripe Alley's orange canyon is not a tint of coral rock; Stripe Alley is deferred (document 13, section 3.3), so it needs no extra tile until it returns | 4 | 512² each | — | 6 | not started |
| `T_EnvShared_Alb` | [MVP] | Atlas for rocks, pebbles, shells, sea grass and eel-hole rings | 1 | 512² | — | 2.5 | not started |
| `M_Env_Rock_01–06` | [MVP] | Rounded rocks: two small, two medium, two large | 6 | 120, 350 or 1,000 tris | T_Tile_Rock_Alb | 3.5 | not started |
| `M_Env_Pebble_01–03` | [MVP] | Smooth pebbles | 3 | 60 tris | T_EnvShared_Alb | 0.8 | not started |
| `M_Env_Shell_01–02` | [MVP] | Scatter shells | 2 | 100 tris | T_EnvShared_Alb | 0.8 | not started |
| `M_Env_SeaGrass_01–03` | [MVP] | Sea grass tufts made of thin closed leaves | 3 | 80 tris | T_EnvShared_Alb | 1.5 | not started |
| `M_Env_Rim_Wall_01–03` | [MVP] | The Rim: the ring of rock between the Reef and the outer zones. Its inner face carries the 24 cove mouths. Three pieces (document 13, Sprint 5, S5-A2): a plain span, a cove span and a buttress for the gaps beside the passes and the ends at the Nursery bulge. A fourth piece, `M_Env_Rim_Wall_04`, is deferred: the 24-cove layout needs none | 3 | 2,500 tris each | T_Rim_Alb | 6 | not started |
| `M_Env_Rim_Pass` | [MVP] | A pass through the Rim, 64 wide and 160 long. Used four times (North, East, South, West) | 1 | 5,000 tris in 2 meshes | T_Rim_Alb | 3 | not started |
| `T_Rim_Alb` | [MVP] | The Rim's own rock texture, repeating every 64 studs on the Rim walls and passes: large soft rock planes in three values, light top edges, blue-violet creases, darker and cooler than the Reef sand. The floor tile `T_Tile_Rock_Alb` read as paving on a wall | 1 | 512² | — | 1.5 | not started |
| `M_Env_EelHole_Ring_01–02` | [MVP] | Ring of blue barnacles around each eel-hole end. Glows teal for Eel players, dull for everyone else (tint) | 2 | 300 tris | T_EnvShared_Alb | 1.5 | not started |
| `M_Env_EelHole_Tunnel_01–03` | [MVP] | Eel tunnel, 7 studs across: straight, bend, long. All ten tunnels are built from them, `eh_north` to `eh_pickle` (document 03, section 6.9). Glow Run (`eh_glow`) reuses the long piece, as Root Run (`eh_root`) does; the Halfway Stump where the two meet is a `M_Env_Kelp_MossBoulder` with two rings, so it needs no new piece | 3 | 400 to 700 tris | T_Tile_Rock_Alb | 2.5 | not started |
| `M_Env_Blue_Haze` | [MVP] | The Blue: a curved wall of soft haze at the edge of the world, so the map ends in open water and not a hard wall | 1 | 200 tris | T_Haze_Mask | 1 | not started |
| `T_Haze_Mask` | [MVP] | Soft gradient with a ragged top for the haze wall | 1 | 256² | — | 0.5 | not started |

### 6.2 Nursery Lagoon [MVP]

Places with no mesh of their own: **Krill Corner** (a bowl-shaped floor chunk), **Baby Slide** (a current), **Hatch Bed** (sea grass and the egg from section 2.0), **Glow Grotto** (a shaded overhang made from one large shared rock, `M_Env_Rock`, set into the rim). The kelp curtain that closes Little Arch during a first run is `M_Cove_KelpCurtain`, used twice side by side.

| Asset | Tag | Description | Qty | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|---|
| `M_Env_Nursery_Floor_01–04` | [MVP] | Pale sand floor chunks; one is the Krill Corner bowl | 4 | 3,000 tris each | T_Tile_Sand_Alb | 5 | not started |
| `M_Env_Nursery_Rim_01–02` | [MVP] | Low rounded rim pieces that enclose the pool | 2 | 1,000 tris | T_Tile_Rock_Alb | 2 | not started |
| `M_Env_Nursery_Coral_01–03` | [MVP] | Round pastel corals | 3 | 250 tris | T_EnvNursery_Alb | 2 | not started |
| `M_Env_Nursery_GrassTuft_01–02` | [MVP] | Soft sea-grass tufts | 2 | 80 tris | T_EnvNursery_Alb | 1 | not started |
| `M_Env_Nursery_GlowBuoy` | [MVP] | Lantern warm-white (`#FFF1DC`) glow buoy. A ring of them marks the safe edge | 1 | 150 tris | T_EnvNursery_Alb | 1 | not started |
| `M_Env_Nursery_LM_LittleArch` | [MVP] | Landmark "Little Arch": pink coral arch, opening 50 wide and 22 high, tunnel 25 long, with a row of small shell lights. The only way in or out | 1 | 5,000 tris | T_EnvNursery_Alb | 4 | not started |
| `M_Env_Nursery_LM_BubbleFountain` | [MVP] | Landmark "Bubble Fountain": ring of stones 12 across; its bubble column lifts a creature to the surface and teaches the breach | 1 | 600 tris | FX_Amb_BubbleColumn | 1.5 | not started |
| `M_Env_Nursery_LM_ThreeRings` | [MVP] | Landmark "Three Rings": a coral ring 14 across, placed three times for dash practice | 1 | 700 tris | T_EnvNursery_Alb | 1.5 | not started |
| `M_Env_Nursery_LM_SleepyClam` | [MVP] | Landmark "Sleepy Clam": giant clam 16 across that opens and closes slowly and snores bubbles. Two bones | 1 | 1,800 tris, 2 bones | T_EnvNursery_Alb | 3 | not started |
| `A_SleepyClam_Snore` | [MVP] | Slow open and close | 1 | loop 120 frames | M_Env_Nursery_LM_SleepyClam | 0.6 | not started |
| `M_Prop_Nursery_ShellSign` | [MVP] | Shell signpost beside the Sleepy Clam that points to Little Arch. A picture, no words | 1 | 200 tris | T_EnvNursery_Alb | 0.8 | not started |
| `T_EnvNursery_Alb` | [MVP] | Pastel atlas for the Nursery pieces | 1 | 512² | — | 2.5 | not started |
| (assembly) Nursery Lagoon | [MVP] | Build the pool, place the kit and landmarks, check that Little Arch is visible from everywhere and the first Krill are in view from the Hatch Bed | 1 | — | Nursery kit, shared pieces | 6 | not started |

### 6.3 Sunlit Reef [MVP]

Places with no mesh of their own: **Tickle Garden** (soft coral below; the anemones arrive at launch, section 5.6), **Goby Flats** (open sand), **The Elbow** (the walled channel that leads from Little Arch into the Reef; its walls are the rock masses below). One 512 × 512 atlas for twelve corals and four sponges is tight; a second atlas is the first thing to add if they look soft.

| Asset | Tag | Description | Qty | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|---|
| `M_Env_Reef_Floor_01–08` | [MVP] | Sand floor chunks at depth 45 to 60 | 8 | 3,000 tris each | T_Tile_Sand_Alb | 8 | not started |
| `M_Env_Reef_RockBlock_01–06` | [MVP] | Big rounded rock masses that set the paths; the 30 coral heads are built on them. Four have a hollow 8 studs across for tier 1 to 3 creatures | 6 | 1,000 to 1,800 tris | T_Tile_CoralRock_Alb | 6 | not started |
| `M_Env_Reef_Arch_01–04` | [MVP] | Arches and short tunnels, every opening at least 20 studs wide | 4 | 1,000 to 1,800 tris | T_Tile_CoralRock_Alb | 5 | not started |
| `M_Env_Reef_Coral_Brain_01–03` | [MVP] | Brain coral in three sizes | 3 | 250, 700, 1,800 tris | T_EnvReef_Alb | 2.5 | not started |
| `M_Env_Reef_Coral_Staghorn_01–03` | [MVP] | Staghorn coral in three sizes; chunky branches | 3 | 250, 700, 1,800 tris | T_EnvReef_Alb | 3 | not started |
| `M_Env_Reef_Coral_Table_01–02` | [MVP] | Table coral that makes shade | 2 | 700 tris | T_EnvReef_Alb | 2 | not started |
| `M_Env_Reef_Coral_Tube_01–02` | [MVP] | Tube coral clusters | 2 | 700 tris | T_EnvReef_Alb | 1.5 | not started |
| `M_Env_Reef_Coral_Fan_01–02` | [MVP] | Sea fans as thin closed sheets | 2 | 250 tris | T_EnvReef_Alb | 1.5 | not started |
| `M_Env_Reef_Sponge_01–04` | [MVP] | Barrel, vase, tube and cluster sponges | 4 | 250 to 700 tris | T_EnvReef_Alb | 2.5 | not started |
| `M_Env_Reef_SoftCoral_01–03` | [MVP] | Soft candy-coloured coral for Tickle Garden | 3 | 250 tris | T_EnvReef_Alb | 2 | not started |
| `M_Env_Reef_LM_NogginRock` | [MVP] | Landmark A "Noggin Rock": giant brain-coral dome at the exact centre, 70 across and 44 tall, with the Noggin Tube eel hole through it. Must be visible within fog range | 2 | 5,000 tris in 2 meshes | T_Reef_NogginRock_Alb | 8 | not started |
| `T_Reef_NogginRock_Alb` | [MVP] | Its own texture: the brain-coral groove pattern at landmark scale | 1 | 1024² | — | 2.5 | not started |
| `M_Env_Reef_LM_Hoop` | [MVP] | Landmark B "The Hoop": coral arch, opening 40 wide and 30 tall; the Home Loop current runs through it | 1 | 3,000 tris | T_Tile_CoralRock_Alb | 3 | not started |
| `M_Env_Reef_LM_HoneycombCaves` | [MVP] | Landmark C "Honeycomb Caves": lumpy mound 90 across with 12 dark holes, each 5 across, for Glowfry | 2 | 5,000 tris in 2 meshes | T_Tile_CoralRock_Alb | 6 | not started |
| `M_Env_Reef_LM_Crackles_01–03` | [MVP] | Landmark D "The Crackles": broken grey rock pieces with cracks 2 to 3 studs deep, for Urchin Puff | 3 | 1,000 tris each | T_Tile_Rock_Alb | 3 | not started |
| `M_Env_Reef_LM_StripeAlley_01–02` | [MVP] | Landmark F "Stripe Alley": tall orange canyon wall pieces for a canyon 150 long and 24 wide | 2 | 2,500 tris each | T_Tile_CoralRock_Alb | 4 | not started |
| `M_Env_Reef_LM_Snooze` | [MVP] | Landmark G "The Snooze": small rowboat at the surface with its name painted on, dark hull seen from below, five rod tips for the fishing lines. Nobody aboard | 1 | 900 tris | T_EnvReef_Alb | 3 | not started |
| `M_Env_Reef_LM_GullRock` | [MVP] | Landmark I "Gull Rock": a rock that breaks the surface, white on top, where the gulls sit | 1 | 1,500 tris | T_Tile_Rock_Alb | 2.5 | not started |
| `T_EnvReef_Alb` | [MVP] | Atlas for corals, sponges, soft coral and the rowboat | 1 | 512² | — | 4 | not started |
| (assembly) Sunlit Reef | [MVP] | Lay the floor, rock masses and coral clusters; place nine landmarks, hooks and the gentle west half; check that Noggin Rock is visible within fog range | 1 | — | Reef kit, shared pieces | 12 | not started |

### 6.4 Kelp Forest [MVP]

About 260 stalks. The 24 nearest are skinned plants swayed by the client; the rest are the static version. Places with no mesh of their own: **The Tall Stand** (the tallest plant at 125%, planted 10 apart), **Jelly Meadow** (a clearing), **Leafy Lane** (a lane full of `FX_Amb_KelpBits`).

| Asset | Tag | Description | Qty | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|---|
| `M_Env_Kelp_Floor_01–06` | [MVP] | Silt floor chunks sloping from depth 70 to 170 | 6 | 3,000 tris each | T_Tile_Sand_Alb | 6 | not started |
| `M_Env_Kelp_MossBoulder_01–04` | [MVP] | Mossy boulders | 4 | 350 to 1,000 tris | T_EnvKelp_Alb | 3 | not started |
| `M_Env_Kelp_RootMound_01–03` | [MVP] | Root mounds with a dark Moray hole in each | 3 | 1,000 tris | T_EnvKelp_Alb | 3.5 | not started |
| `M_Env_Kelp_Plant_01–03` | [MVP] | Kelp plant at three heights (40, 80, 140 studs), each as a four-bone skinned mesh and a static mesh | 6 | 500 tris, 4 bones | T_EnvKelp_Alb | 4 | not started |
| `M_Env_Kelp_CanopyCard_01–03` | [MVP] | Canopy leaf sheets that float at depth 10 to 30 and break the light | 3 | 100 tris | T_EnvKelp_Alb | 2 | not started |
| `M_Env_Kelp_Fern_01–03` | [MVP] | Floor ferns | 3 | 150 tris | T_EnvKelp_Alb | 1.5 | not started |
| `M_Env_Kelp_Log_01–02` | [MVP] | Fallen logs; one is hollow | 2 | 350 to 700 tris | T_EnvKelp_Alb | 2 | not started |
| `M_Env_Kelp_LM_OldAnchor` | [MVP] | Landmark J "Old Anchor": huge rusty anchor 60 tall, a chain link to repeat, and a buoy at the surface. "Follow the chain home" | 3 | 3,000 tris in all | T_EnvKelp_Alb | 5 | not started |
| `M_Env_Kelp_LM_PeekabooRidge_01–03` | [MVP] | Landmark L "Peekaboo Ridge": rock ridge 180 long and 35 tall in three pieces, with five dark Moray holes | 3 | 5,000 tris in 3 meshes | T_Tile_Rock_Alb | 6 | not started |
| `M_Env_Kelp_LM_RibbonRoof_01–02` | [MVP] | Landmark N "Ribbon Roof": thick canopy mats that make a green ceiling | 2 | 700 tris each | T_EnvKelp_Alb | 2.5 | not started |
| `M_Env_Kelp_LM_LookoutStack` | [MVP] | Landmark P "Lookout Stack": rock pillar 40 across that rises from the floor at 120 to above the surface | 2 | 5,000 tris in 2 meshes | T_Tile_Rock_Alb | 4 | not started |
| `M_Env_Kelp_LM_RootBall` | [MVP] | Landmark Q "Root Ball": hollow dome of tangled roots 50 across, with a way in | 2 | 5,000 tris in 2 meshes | T_EnvKelp_Alb | 5 | not started |
| `M_Env_Kelp_LM_Glowgrove_01–02` | [MVP] | Landmark R "Glowgrove": kelp stalks carrying glowing algae | 2 | 500 tris | T_EnvKelp_Alb, T_EnvKelp_Emi | 2 | not started |
| `M_Env_Kelp_LM_HushHollow` | [MVP] | Landmark S "Hush Hollow": bowl-shaped floor, radius 80, in two sea-floor chunks, with rim ledges to hide under | 2 | 3,000 tris each | T_Tile_Sand_Alb | 3 | not started |
| `T_EnvKelp_Alb` | [MVP] | Atlas for kelp, moss, roots, ferns, logs and the anchor | 1 | 512² | — | 4 | not started |
| (assembly) Kelp Forest | [MVP] | Plant about 260 stalks in three densities with lanes 30 wide; place ten landmarks, eight Moray holes and four jelly blooms | 1 | — | Kelp kit, shared pieces | 10 | not started |

### 6.5 The Drop-off [MVP, with a launch pass]

Documents 03 and 06 both build the whole Drop-off at soft launch, including the wreck: the Chimneys are cold stone and Whale's Rest is an empty bowl until launch. Places with no mesh of their own: **The Ledge** (floor shelves below), **The Blue Mile** (open water), **The Lift** (a rising current).

| Asset | Tag | Description | Qty | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|---|
| `M_Env_DropOff_Cliff_01–08` | [MVP] | Cliff modules, 64 × 96 studs, that stack into the Wall from depth 100 to 430. Darker and cooler with depth by a `SurfaceAppearance` colour tint per module (document 06, section 5.3) | 8 | 2,500 tris each | T_Tile_Slate_Alb | 10 | not started |
| `M_Env_DropOff_Ledge_01–04` | [MVP] | Ledges every 60 to 90 studs down the Wall so depth can be counted | 4 | 700 tris | T_Tile_Slate_Alb | 3 | not started |
| `M_Env_DropOff_Overhang_01–03` | [MVP] | Overhangs | 3 | 1,000 tris | T_Tile_Slate_Alb | 3 | not started |
| `M_Env_DropOff_FloorShelf_01–02` | [MVP] | Floor shelves for the sunny Ledge strip between the Rim and the cliff | 2 | 3,000 tris each | T_Tile_Rock_Alb | 2.5 | not started |
| `M_Env_DropOff_DeepFloor_01–04` | [MVP] | Deep Floor chunks at depth 430 to 480; one is the pale bowl of Whale's Rest (landmark V) | 4 | 3,000 tris each | T_Tile_Slate_Alb | 4.5 | not started |
| `M_Env_DropOff_WallCrack_01–02` | [MVP] | Hiding cracks set into the Wall every 80 studs; fit tier 3 and lower | 2 | 500 tris | T_Tile_Slate_Alb | 1.5 | not started |
| `M_Env_DropOff_DarkSponge_01–04` | [MVP] | Dark sponges | 4 | 250 to 700 tris | T_EnvDropOff_Alb | 2.5 | not started |
| `M_Env_DropOff_SeaWhip_01–03` | [MVP] | Sea whips; one is pale, to give scale against the dark | 3 | 250 tris | T_EnvDropOff_Alb | 2 | not started |
| `M_Env_DropOff_TubeWorm_01–02` | [MVP] | Tube-worm clusters | 2 | 700 tris | T_EnvDropOff_Alb | 1.5 | not started |
| `M_Env_DropOff_Bones_01–03` | [MVP] | A few old whale bones for Whale's Rest: rib, vertebra, jaw piece. Clean and pale | 3 | 250 to 700 tris | T_EnvDropOff_Alb | 2 | not started |
| `M_Env_DropOff_LM_InkPots_01–02` | [MVP] | Landmark T "Ink Pots": cliff modules with round pockets 10 across, stained blue-black; eight holes over 180 studs of height | 2 | 2,500 tris each | T_Tile_Slate_Alb | 4 | not started |
| `M_Env_DropOff_LM_TinPickle_Bow` | [MVP] | Landmark U "The Tin Pickle": bow of the small pickle-green tugboat, 90 long in all, with its name painted on | 1 | 5,000 tris | T_EnvWreck_Alb | 5 | not started |
| `M_Env_DropOff_LM_TinPickle_Stern` | [MVP] | Tin Pickle: stern with the hull breach | 1 | 5,000 tris | T_EnvWreck_Alb | 5 | not started |
| `M_Env_DropOff_LM_TinPickle_Cabin` | [MVP] | Tin Pickle: cabin and rooms that fit tier 5 and lower, and the smokestack (the Pickle Pipe eel hole) | 2 | 4,000 tris in 2 meshes | T_EnvWreck_Alb | 5 | not started |
| `M_Env_DropOff_LM_TinPickle_Debris_01–03` | [MVP] | Tin Pickle: crates, a lifebuoy, a broken mast | 3 | 250 tris each | T_EnvWreck_Alb | 2 | not started |
| `M_Env_DropOff_LM_TinPickle_Shelf` | [MVP] | The rock shelf sticking out of the Wall that the wreck lies on | 1 | 2,500 tris | T_Tile_Slate_Alb | 2 | not started |
| `T_EnvWreck_Alb` | [MVP] | Pickle-green paint, rust, barnacles, wood | 1 | 1024² | — | 4 | not started |
| `M_Env_DropOff_LM_Overbite` | [MVP] | Landmark W "The Overbite": overhang 80 wide that sticks out 40, shaped like a big lower jaw | 1 | 4,000 tris | T_Tile_Slate_Alb | 3.5 | not started |
| `M_Env_DropOff_LM_SlipstoneSlope_01–03` | [MVP] | Landmark Z "Slipstone Slope": smooth ramp pieces, 300 long and 120 wide in all | 3 | 3,000 tris each | T_Tile_Slate_Alb | 4 | not started |
| `M_Env_DropOff_LM_Crack_01–03` | [MVP] | Landmark 2 "The Crack": jagged rock lips for the sealed mouth of the Trench, 1,150 long in all. Sealed scenery; the Trench behind it is [P2] | 3 | 2,500 tris each | T_Tile_Slate_Alb | 4 | not started |
| `T_Decal_ScarScrape_Mask` | [MVP] | "Scar's Run": three long pale scrape marks laid on the Wall along Old Scar's patrol path | 3 | 256 × 64 each | — | 1 | not started |
| `T_EnvDropOff_Alb` | [MVP] | Atlas for sponges, whips, worms and bones | 1 | 512² | — | 3.5 | not started |
| (assembly) The Drop-off | [MVP] | Stack the Wall and its ledges, lay the Ledge and Deep Floor, place nine landmarks and the nine cold chimneys, mark Old Scar's path | 1 | — | Drop-off kit, shared pieces | 14 | not started |
| (assembly) The Drop-off, launch pass | [L] | Wake the nine vents (three always on at the centre, six cycling at their own offsets), place Grouper spots, dress Whale's Rest for the Whale Fall | 1 | — | launch rows | 4 | not started |

The Chimneys (landmark Y) are the vent meshes in section 5.6.

### 6.6 Coves [MVP, with launch additions]

All 24 coves use the same pieces (document 03, sections 6.7 and 6.10). Specimens on display are the species meshes themselves, swimming a slow loop at their perch; they need no extra art. The owner name on the Name Shell is interface text (document 08).

| Asset | Tag | Description | Qty | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|---|
| `M_Cove_Mouth` | [MVP] | Rounded cave opening 36 wide and 28 high with a 25-stud throat; fits a tier 7 creature. Swimming through your own banks the run | 1 | 2,500 tris | T_Cove_Alb | 5 | not started |
| `M_Cove_NameShell` | [MVP] | Scallop-shaped sign 14 wide above the mouth | 1 | 300 tris | T_Cove_Alb | 1 | not started |
| `M_Cove_TrophyBubbleMount` | [MVP] | Bracket beside the sign that holds the 10-stud Trophy Bubble with the best specimen | 1 | 200 tris | M_Prop_BubbleShell | 0.8 | not started |
| `M_Cove_DoorLantern` | [MVP] | Lantern on a stalk. Lantern amber with a beam to the surface for your own cove (amber means home, canon section 5.2), teal for friends, lantern warm white (`#FFF1DC`) for others, dark when empty (tint) | 1 | 300 tris | FX_CoveBeacon | 1.5 | not started |
| `M_Cove_KelpCurtain` | [MVP] | Kelp curtain across the mouth of a cove nobody owns | 1 | 400 tris | T_EnvKelp_Alb | 1.2 | not started |
| `M_Cove_Interior` | [MVP] | Oval chamber 76 × 110 × 44 in pale sandstone with light cracks in the ceiling and stepped side walls for 40 perches, four rows of five a side: the lower three rows are the 30 slots Pearls can open and the top row is the 10 Bigger Cove slots (canon section 11; document 03, section 6.10) | 2 | 6,000 tris in 2 meshes | T_Cove_Alb | 8 | not started |
| `M_Cove_HomeStone` | [MVP] | Flat round stone with a spiral mark where the Fry hatches | 1 | 150 tris | T_Cove_Alb | 0.8 | not started |
| `M_Cove_PearlClam` | [MVP] | Large clam that fills with Pearls as the cove earns and opens when the player swims to it. Two bones | 1 | 600 tris, 2 bones | T_Cove_Alb | 2.5 | not started |
| `A_PearlClam_Open` | [MVP] | Lid pops open | 1 | 15 frames | M_Cove_PearlClam | 0.5 | not started |
| `M_Prop_Pearl_01–03` | [MVP] | The Pearl: single, small pile, big pile | 3 | 60 to 400 tris | T_Cove_Alb | 1.5 | not started |
| `M_Cove_Perch` | [MVP] | Small rock perch that marks a specimen spot; used 40 times | 1 | 150 tris | T_Cove_Alb | 1 | not started |
| `M_Cove_PerchNet` | [MVP] | Kelp net that covers a perch not yet opened. The nets on the ten Bigger Cove perches show a pass mark, painted in a second cell of the cove atlas | 1 | 200 tris | T_Cove_Alb | 1 | not started |
| `M_Cove_TrophyRock` | [MVP] | Raised rock at the back with a light beam; the best specimen swims above it | 1 | 500 tris | T_Cove_Alb | 1.5 | not started |
| `M_Cove_CodexStone` | [MVP] | Open stone book with glowing pages; opens the Codex | 1 | 400 tris | T_Cove_Alb | 2 | not started |
| `M_Cove_SpeciesWall` | [MVP] | Species Wall: a smooth oval patch of the back wall, left of the Trophy Rock, with a raised shell rim (document 03, section 6.10). The next species the player can unlock shows on it as a dark silhouette inside a progress ring; both are interface drawn on the patch (the species portrait tinted dark in code, document 08), so this row is the wall patch only. Lit at the first bank (document 04) | 1 | 200 tris | T_Cove_Alb | 1 | not started |
| `M_Cove_TideClock` | [MVP] | Tide clock: a shell clock on the back wall, right of the Trophy Rock, that shows the next tide event and its countdown and nothing more, free in every cove (document 03, section 6.10) and revealed at the first bank (document 04). Hand and four picture plates; the countdown is interface text. The Tide Watcher tide board is interface (document 08) | 1 | 400 tris, 1 bone | T_Cove_Alb | 2 | not started |
| `T_Cove_Alb` | [MVP] | One atlas for the whole cove kit, the egg and the Pearls | 1 | 512² | — | 4 | not started |
| (assembly) Cove template and Rim | [MVP] | Build one cove; mark 40 perches and 29 decoration spots; set 24 mouths on the Rim at the positions in document 03 | 1 | — | cove kit | 6 | not started |
| `M_Cove_BubbleCount` | [L] | Small cluster of bubbles under the Name Shell that shows the Bubbles received | 1 | 150 tris | M_Prop_BubbleShell | 0.8 | not started |
| `M_Cove_BubbleJar` | [L] | Glass jar beside the throat that fills with the Bubbles visitors leave | 1 | 400 tris | T_Cove_Alb | 1.5 | not started |
| (bundle) Cove biome variants | [P2] | New cove looks for the Migration prestige system: a recoloured atlas and new trim per biome; two biomes assumed | 2 | — | cove kit | 24 | not started |

### 6.7 Cove decorations [L]

The 50 decorations in document 03, section 13, one row each. Size class sets the footprint (S 4 × 4 studs, M 8 × 8, L 14 × 14) and the budget: S 100 to 250 triangles, M 250 to 500, L 500 to 800. Document 05, section 4.3 prices the same 50 and agrees that 46 are at launch. The other four arrive with their tides: Storm, Red Tide and Great Migration at [P1], the Trench at [P2].

| Asset | Tag | Description | Qty | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|---|
| `T_CoveDeco_01–03_Alb` | [L] | Three atlases shared by all launch decorations | 3 | 512² each | — | 6 | not started |
| `M_Prop_Deco_ShellPile` | [L] | `deco_shell_pile` Shell Pile: heap of five shells | 1 | S, floor | T_CoveDeco_01–03_Alb | 0.6 | not started |
| `M_Prop_Deco_SeaFan` | [L] | `deco_sea_fan` Sea Fan: flat pink coral fan that sways | 1 | S, floor | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_BubbleStone` | [L] | `deco_bubble_stone` Bubble Stone: cracked stone leaking bubbles | 1 | S, floor | T_CoveDeco_01–03_Alb | 0.6 | not started |
| `M_Prop_Deco_StarfishTrio` | [L] | `deco_starfish_trio` Starfish Trio: three starfish on the wall | 1 | S, wall | T_CoveDeco_01–03_Alb | 0.6 | not started |
| `M_Prop_Deco_GlowSprouts` | [L] | `deco_glow_sprouts` Glow Sprouts: three plants with glowing teal tips | 1 | S, floor | T_CoveDeco_01–03_Alb | 0.6 | not started |
| `M_Prop_Deco_OldPot` | [L] | `deco_old_pot` Old Pot: cracked clay pot; a tiny crab peeks out | 1 | S, floor | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_KelpCurtain` | [L] | `deco_kelp_curtain` Kelp Curtain: hanging row of kelp strands that sway | 1 | M, ceiling | T_CoveDeco_01–03_Alb | 1.4 | not started |
| `M_Prop_Deco_SandCastle` | [L] | `deco_sand_castle` Sand Castle: three towers and a shell flag | 1 | M, floor | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_ClamCouch` | [L] | `deco_clam_couch` Clam Couch: open clam with a pink cushion | 1 | M, floor | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_RustyAnchor` | [L] | `deco_rusty_anchor` Rusty Anchor: small anchor leaning on a rock | 1 | M, floor | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_Porthole` | [L] | `deco_porthole` Porthole: brass ship window glowing soft blue | 1 | S, wall | T_CoveDeco_01–03_Alb | 0.6 | not started |
| `M_Prop_Deco_LanternString` | [L] | `deco_lantern_string` Lantern String: six glowing shell lanterns on a string | 1 | M, ceiling | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_BottleShip` | [L] | `deco_bottle_ship` Ship in a Bottle: glass bottle with a tiny ship | 1 | M, floor | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_NetHammock` | [L] | `deco_net_hammock` Net Hammock: net slung as a hammock, starfish asleep in it | 1 | M, ceiling | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_CoralArch` | [L] | `deco_coral_arch` Coral Arch: tall orange and pink arch to swim through | 1 | L, floor | T_CoveDeco_01–03_Alb | 1.6 | not started |
| `M_Prop_Deco_TreasureBarrel` | [L] | `deco_treasure_barrel` Treasure Barrel: open barrel spilling coins and beads | 1 | M, floor | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_MiniVolcano` | [L] | `deco_mini_volcano` Mini Volcano: stone cone that puffs orange bubbles | 1 | L, floor | T_CoveDeco_01–03_Alb | 1.6 | not started |
| `M_Prop_Deco_GoldenMinnow` | [L] | `deco_golden_minnow` Golden Minnow: gold statue of a leaping Minnow | 1 | M, floor | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_RankPebbleTower` | [L] | `deco_rank_pebble_tower` Pebble Tower: seven balanced pebbles. Reef Rank 3 | 1 | S, floor | T_CoveDeco_01–03_Alb | 0.6 | not started |
| `M_Prop_Deco_RankBubbleFountain` | [L] | `deco_rank_bubble_fountain` Bubble Fountain: stone ring with a bubble column. Reef Rank 6 | 1 | M, floor | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_RankShellThrone` | [L] | `deco_rank_shell_throne` Shell Throne: giant scallop chair with a pearl. Reef Rank 11 | 1 | L, floor | T_CoveDeco_01–03_Alb | 1.6 | not started |
| `M_Prop_Deco_RankReefMap` | [L] | `deco_rank_reef_map` Reef Map: painted map of the reef on sailcloth. Reef Rank 16 | 1 | M, wall | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_RankKelpSwing` | [L] | `deco_rank_kelp_swing` Kelp Swing: seat on two kelp ropes that swings. Reef Rank 21 | 1 | M, ceiling | T_CoveDeco_01–03_Alb | 1.4 | not started |
| `M_Prop_Deco_RankPearlLamp` | [L] | `deco_rank_pearl_lamp` Giant Pearl Lamp: beach-ball pearl glowing in a clam. Reef Rank 26 | 1 | M, floor | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_RankTideClock` | [L] | `deco_rank_tide_clock` Tide Clock: brass clock whose hand points to the next tide event. Reef Rank 31 | 1 | M, wall | T_CoveDeco_01–03_Alb | 1.4 | not started |
| `M_Prop_Deco_RankDivingHelmet` | [L] | `deco_rank_diving_helmet` Diving Helmet: brass helmet with a small fish inside. Reef Rank 36 | 1 | M, floor | T_CoveDeco_01–03_Alb | 1.4 | not started |
| `M_Prop_Deco_RankStormGlass` | [L] | `deco_rank_storm_glass` Storm Glass: globe with a tiny storm cloud and sparks. Reef Rank 41 | 1 | S, floor | T_CoveDeco_01–03_Alb | 0.6 | not started |
| `M_Prop_Deco_RankLeviathanStatue` | [L] | `deco_rank_leviathan_statue` Leviathan Statue: dark stone sea creature rising from waves. Reef Rank 46 | 1 | L, floor | T_CoveDeco_01–03_Alb | 1.6 | not started |
| `M_Prop_Deco_RankGoldenGulp` | [L] | `deco_rank_golden_gulp` Golden Gulp: gold trophy: a fish mouth around a pearl. Reef Rank 50 | 1 | M, floor | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_EvtDinnerBell` | [L] | `deco_evt_dinner_bell` Dinner Bell: brass bell on a post; rings when a Feeding Frenzy starts | 1 | S, floor | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_EvtMoonLamp` | [L] | `deco_evt_moon_lamp` Moon Lamp: glowing crescent on a stand, shedding silver motes | 1 | M, floor | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_EvtWhaleRib` | [L] | `deco_evt_whale_rib` Whale Rib Arch: two white ribs with glowing algae, meeting as an arch | 1 | L, floor | T_CoveDeco_01–03_Alb | 1.6 | not started |
| `M_Prop_Deco_EvtStormBottle` | [P1] | `deco_evt_storm_bottle` Lightning in a Bottle: corked bottle with a bouncing bolt | 1 | S, floor | T_CoveDeco_01–03_Alb | 0.6 | not started |
| `M_Prop_Deco_EvtTrenchLantern` | [P2] | `deco_evt_trench_lantern` Trench Lantern: glowing green stalk in a stone pot | 1 | M, floor | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_EvtRedBloom` | [P1] | `deco_evt_red_bloom` Red Bloom: jar of swirling rust-red water | 1 | S, floor | T_CoveDeco_01–03_Alb | 0.6 | not started |
| `M_Prop_Deco_EvtFishKite` | [P1] | `deco_evt_fish_kite` Fish Kite: silver cloth fish that flutters on a string | 1 | M, ceiling | T_CoveDeco_01–03_Alb | 1.4 | not started |
| `M_Prop_Deco_CdxFamilyPortrait` | [L] | `deco_cdx_family_portrait` Family Portrait: framed picture of the six launch species | 1 | M, wall | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_CdxPreyMobile` | [L] | `deco_cdx_prey_mobile` Prey Mobile: eight small wooden prey that turn slowly | 1 | M, ceiling | T_CoveDeco_01–03_Alb | 1.4 | not started |
| `M_Prop_Deco_CdxTraitTotem` | [L] | `deco_cdx_trait_totem` Trait Totem: carved pole with one lit face per trait | 1 | L, floor | T_CoveDeco_01–03_Alb | 1.6 | not started |
| `M_Prop_Deco_CdxDangerBoard` | [L] | `deco_cdx_danger_board` Danger Board: cork board of funny predator posters | 1 | M, wall | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_CdxSeaGlobe` | [L] | `deco_cdx_sea_globe` Sea Globe: glass globe with a tiny model of the whole map | 1 | M, floor | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_CdxTideChart` | [L] | `deco_cdx_tide_chart` Tide Chart: wall chart with a picture per tide event | 1 | S, wall | T_CoveDeco_01–03_Alb | 0.6 | not started |
| `M_Prop_Deco_GoalsSunShell` | [L] | `deco_goals_sun_shell` Sun Shell: golden scallop that glows like a small sun. Daily goals, all three done on 3 days | 1 | S, floor | T_CoveDeco_01–03_Alb | 0.6 | not started |
| `M_Prop_Deco_GoalsWeekWheel` | [L] | `deco_goals_week_wheel` Week Wheel: small ship wheel with seven shells on its rim. Daily goals, all three done on 7 days | 1 | S, wall | T_CoveDeco_01–03_Alb | 0.6 | not started |
| `M_Prop_Deco_GoalsLuckyStarfish` | [L] | `deco_goals_lucky_starfish` Lucky Starfish: smiling golden starfish that waves an arm. Daily goals, all three done on 14 days | 1 | S, floor | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_GoalsMessageBottle` | [L] | `deco_goals_message_bottle` Message in a Bottle: corked bottle with a note; bobs. Daily goals, all three done on 28 days | 1 | S, floor | T_CoveDeco_01–03_Alb | 0.6 | not started |
| `M_Prop_Deco_BuyGoldChest` | [L] | `deco_buy_gold_chest` Golden Chest: open chest overflowing with Pearls. Starter Pack | 1 | M, floor | T_CoveDeco_01–03_Alb | 1 | not started |
| `M_Prop_Deco_BuyDiscoClam` | [L] | `deco_buy_disco_clam` Disco Clam: clam with a mirror-ball pearl throwing dots of light | 1 | M, floor | T_CoveDeco_01–03_Alb | 1.4 | not started |
| `M_Prop_Deco_BuyJellyLamp` | [L] | `deco_buy_jelly_lamp` Jelly Lamp: glass tube of slow glowing blobs | 1 | S, floor | T_CoveDeco_01–03_Alb | 0.6 | not started |
| `M_Prop_Deco_BuyMiniPickle` | [L] | `deco_buy_mini_pickle` Mini Tin Pickle: 12-stud model of the tugboat wreck with lit windows | 1 | L, floor | T_CoveDeco_01–03_Alb | 1.6 | not started |

### 6.8 The Trench [P2]

Canon sections 6 and 10 tag the Trench, and The Trench Opens that unlocks it, [P2]. Document 03 gives its landmarks. The zone is bundled into a few rows until it is scheduled. The Crack and the Coldline that seal it are Drop-off scenery and stay [MVP] (section 6.5 and `FX_Coldline`).

| Asset | Tag | Description | Qty | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|---|
| (bundle) Trench kit | [P2] | Trench wall modules (6), floor chunks (3), rocks (3) | 12 | as Drop-off kit | T_Tile_Slate_Alb | 16 | not started |
| `M_Env_Trench_LM_LanternField` | [P2] | Thin glowing green stalks, three variants, planted in hundreds | 3 | 150 tris each | T_EnvTrench_Alb | 3 | not started |
| `M_Env_Trench_LM_Ribs` | [P2] | Huge old arched bones standing across the Trench like gates; clean, pale, coral-grown | 2 | 3,000 tris each | T_EnvTrench_Alb | 5 | not started |
| `M_Env_Trench_LM_Quiet` | [P2] | Round bowl of pale silt at the deepest point in the game | 1 | 3,000 tris | T_Tile_Sand_Alb | 2 | not started |
| `T_EnvTrench_Alb, T_EnvTrench_Emi` | [P2] | Trench atlas and its glow mask | 2 | 512² | — | 4 | not started |
| (assembly) The Trench | [P2] | Build the zone inside the Crack, with Hot Row (four vents) and the three Bubble Stairs | 1 | — | Trench kit | 10 | not started |

## 7. Water and sky

The sea is fog and light; only the surface is a model (document 06, sections 9.4, 9.5 and 10.4). The player is under water almost all the time, so the underside of the surface matters more than the top. Depth colour and view distance come from the lighting presets (section 10), not from extra meshes.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `M_Env_Surface_Under, M_Env_Surface_Top` | [MVP] | Flat sheet at height 0 in 256-stud tiles, as two single-sided meshes: the underside seen from below and the top seen when breaching. The surface does not move as geometry at soft launch | 2 tris each | — | 0.5 | not started |
| `T_Surface_Under_01–08_Alb` | [MVP] | Underside: hand-painted ripple pattern in light aqua and white, tiling every 64 studs, in eight frames swapped eight times a second | 512² each | — | 5 | not started |
| `T_Surface_Top_Alb` | [MVP] | Top side: flat turquoise with painted foam shapes, tiling | 512² | — | 1.5 | not started |
| `M_Env_SunPool, T_SunPool_Mask` | [MVP] | Soft bright round card 96 studs across that follows the camera just under the surface, so the brightest patch is always overhead | 2 tris, 256² | — | 0.5 | not started |
| `SKY_Day` | [MVP] | Six-face skybox: clear toy-blue sky with painted clouds low on the horizon | 6 × 512² | — | 4 | not started |
| `SKY_MoonTide` | [MVP] | Six-face night skybox: deep blue with large soft stars | 6 × 512² | SKY_Day | 2.5 | not started |
| `T_Sky_Sun_Alb` | [MVP] | Painted sun disc; replaces the default sun image | 256² | — | 0.5 | not started |
| `T_Sky_Moon_Alb` | [MVP] | Painted full moon, oversized so it shows through the surface in a Moon Tide; replaces the default moon image | 256² | — | 0.5 | not started |
| `M_Env_HorizonIsland_01–03` | [MVP] | Far island cut-outs on the horizon so a breach has something to look at | 100 tris each | T_Tile_Rock_Alb | 1.5 | not started |
| `M_Env_CausticShell_*` | [MVP] | Thin shell lying 0.1 studs above each Nursery and Reef sand chunk and the flat reef tops, with top-down UVs tiling every 32 studs. Made by script from the floor meshes, one file per source mesh, named after it: `M_Env_CausticShell_<source name without M_Env_>` (for example `M_Env_CausticShell_ReefFloor_03`). Shown only above 60 studs depth | as the floor chunks | Nursery and Reef floor chunks | 2 | not started |
| `T_Caustics_01–16_Mask` | [MVP] | Caustics: a white web of light in 16 looping frames, rendered in Blender, swapped 12 times a second | 256² each | — | 3 | not started |
| `T_FX_GodRay_Mask` | [MVP] | Soft streak for the light-shaft beams (`FX_GodRay`); tinted silver for moon shafts. A placeholder may be square | 64 × 256 | — | 0.4 | not started |
| (test) Surface, caustics and fog on a phone | [MVP] | Prove the frame-swapped surface, the caustic shells and the depth fog on a low-end phone before the kits are textured; cut frames or reach if needed | — | rows above, LGT_Reef | 4 | not started |

## 8. Tide event assets

Everything an event needs beyond the normal world (document 03, section 7; document 06, section 10.6). Effects named here have their rows in section 9, lighting in section 10, sounds in section 11 and themes in section 12.

### 8.1 Feeding Frenzy (`frenzy`) [MVP]

No new meshes. Bait balls are ordinary prey in large groups; the cloud of gulls over the Reef is more copies of the Gull. Uses `LGT_Event_Frenzy`, `FX_TideWarningPulse`, `FX_TideBanner_Frenzy`, `FX_FrenzySurge`, `FX_GodRay` at double count, gold-white Plankton by tint, `SFX_TideBell`, `SFX_TideHorn_Frenzy`, `SFX_UI_EventWarn`, `SFX_UI_EventStart`, `SFX_UI_EventEnd`, `MUS_Event_Warning`, `MUS_Event_Frenzy`. The paid **Call the Tide** adds `FX_CallTheTide` and `SFX_CallTheTide` [L].

### 8.2 Moon Tide (`moon_tide`) [MVP]

The night look reuses every mesh: each kit piece has a night tint, and coral tips, kelp leaf edges and sponge rims glow through the masks below. Three moonbeam pillars, 50 across, stand at the sites in document 03. Uses `LGT_Event_MoonTide`, `SKY_MoonTide`, `T_Sky_Moon_Alb`, `T_Shared_EyeRing_Emi`, `M_Prey_LunarFry`, `FX_LunarFryTrail`, `FX_Moonbeam`, `FX_TideBanner_MoonTide`, `FX_MoonTideMotes`, cyan Plankton by tint, `SFX_TideHorn_MoonTide`, `SFX_Amb_MoonTide`, `MUS_Event_MoonTide`, plus the rows below.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `T_EnvReef_Emi` | [MVP] | Glow mask for coral tips, sponge rims and soft coral | 256² | T_EnvReef_Alb | 1.5 | not started |
| `T_EnvKelp_Emi` | [MVP] | Glow mask for kelp leaf edges and the Glowgrove algae | 256² | T_EnvKelp_Alb | 1.5 | not started |
| `T_EnvNursery_Emi` | [MVP] | Glow mask for the Nursery corals and buoys | 256² | T_EnvNursery_Alb | 0.8 | not started |
| `T_EnvDropOff_Emi` | [MVP] | Glow mask for sponge rims and sea whips | 256² | T_EnvDropOff_Alb | 0.8 | not started |
| (data) Night tints | [MVP] | A night tint for every kit piece and creature class, in cyan and silver-lavender only | — | all MVP kits | 2 | not started |
| (test) Moon Tide switch | [MVP] | Check the change from day to night in every zone: outlines stay the brightest things, anything that can eat the player shows two eye dots within 120 studs, the player's own cove lantern stays amber and the others stay warm white (`#FFF1DC`), no black corners | — | LGT_Event_MoonTide | 3 | not started |

### 8.3 Whale Fall (`whale_fall`) [L]

A clean white whale skeleton, 60 long, 22 wide and 18 tall, with soft glowing algae on the ribs. It sinks to Whale's Rest over 25 s, stays as scenery until the next event warning, then breaks into bubbles. No flesh, no red. Uses `LGT_Event_WhaleFall`, `M_Prey_Marrow_01–03`, `FX_MarrowGlow`, `FX_WhaleFallBeam`, `FX_TideBanner_WhaleFall`, `FX_WhaleFallSinkTrail`, `FX_WhaleFallSilt`, `FX_WhaleFallDissolve`, `A_OldScar_Feed`, `SFX_TideHorn_WhaleFall`, `SFX_WhaleFallSink`, `SFX_WhaleFallImpact`, `SFX_MarrowCrunch`, `MUS_Event_WhaleFall`, plus the rows below.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `M_Env_WhaleFall_Skull` | [L] | Skull and jaw; creatures can swim through the mouth. The jaw has two bones | 5,000 tris, 2 bones | T_WhaleFall_Alb | 6 | not started |
| `M_Env_WhaleFall_Ribcage` | [L] | Rib cage; Marrow chunks drift up from inside it | 6,000 tris | T_WhaleFall_Alb | 6 | not started |
| `M_Env_WhaleFall_Tail` | [L] | Spine and tail bones | 4,000 tris | T_WhaleFall_Alb | 4 | not started |
| `T_WhaleFall_Alb` | [L] | Bone white and cream with soft blue shadows | 1024² | — | 4 | not started |
| `T_WhaleFall_Emi` | [L] | Glow mask for the white-green algae on the ribs | 512² | T_WhaleFall_Alb | 1 | not started |
| `T_Whale_Shadow_Mask` | [L] | Huge soft whale shadow that crosses the surface above Whale's Rest during the 60 s warning | 512² | — | 0.5 | not started |
| (test) Whale Fall staging | [L] | Time the shadow, the 25 s sink, the landing and the break-up; check the site with Old Scar and six Groupers present | — | rows above | 3 | not started |

### 8.4 Post-launch events

Bundled until scheduled. Tags from canon section 10: Storm, Red Tide and Great Migration are [P1]; The Trench Opens is [P2]. Each bundle covers meshes, effects and sounds; the lighting preset and the theme are separate rows in sections 10 and 12.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| (bundle) Storm | [P1] | Lightning strike ring and bolt seen from below, rain on the surface, storm skybox `SKY_Storm`, thunder and rain sounds | — | — | 20 | not started |
| (bundle) The Trench Opens | [P2] | The Coldline parting (the closed shimmer is `FX_Coldline`), a line of silver light along the Crack, the cold surge that lifts creatures out, sounds. The Trench itself is in section 6.8 | — | M_Env_DropOff_LM_Crack_01–03 | 12 | not started |
| (bundle) Red Tide | [P1] | Rust-red cloud effects for one zone at a time, a red preset tint, bloom sounds | — | — | 12 | not started |
| (bundle) Great Migration | [P1] | A river of ordinary prey 600 studs long needs no new meshes: a leading-edge effect, far school dots, passing-herd sounds | — | — | 10 | not started |

## 9. Visual effects library

Every effect is a named set of emitter settings (`FX_….json`) plus the textures it uses. Budgets are the most particles alive at once on a phone. Effects never use the default particle image. Floating numbers such as "+4" are interface (document 08).

### 9.1 Effect textures and meshes

Shared by many effects. Flipbooks are rendered from Blender or painted, then packed by script.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `T_FX_Bubble_Mask` | [MVP] | Four bubble shapes with a painted highlight | 256², 2×2 | — | 1 | not started |
| `T_FX_SoftDot_Mask` | [MVP] | Soft round glow | 64² | — | 0.2 | not started |
| `T_FX_SoftPuff_Flip` | [MVP] | Puff that swells and thins | 512², 4×4 | — | 1.5 | not started |
| `T_FX_Ring_Mask` | [MVP] | Plain shock ring | 256² | — | 0.3 | not started |
| `T_FX_TierRing_Mask` | [MVP] | Ornate wave-crest ring for tier-ups and trait gains | 512² | — | 0.8 | not started |
| `T_FX_Star_Mask` | [MVP] | Glint, sparkle, star and plus shapes | 256², 2×2 | — | 0.5 | not started |
| `T_FX_Streak_Mask` | [MVP] | Speed streak for trails and beams | 64 × 256 | — | 0.3 | not started |
| `T_FX_Droplet_Mask` | [MVP] | Four droplet shapes | 128², 2×2 | — | 0.4 | not started |
| `T_FX_Foam_Flip` | [MVP] | Foam ring that spreads and breaks up | 512², 4×4 | — | 1.5 | not started |
| `T_FX_Silt_Flip` | [MVP] | Sandy puff | 512², 4×4 | — | 1.5 | not started |
| `T_FX_Shard_Mask` | [MVP] | Plate shards and crystal shards | 256², 2×2 | — | 0.6 | not started |
| `T_FX_Crack_Mask` | [MVP] | Crack burst | 256² | — | 0.5 | not started |
| `T_FX_StunSpiral_Mask` | [MVP] | Dizzy spiral and three stars | 256², 2×2 | — | 0.5 | not started |
| `T_FX_Zap_Flip` | [MVP] | Jagged arcs; jelly sting at soft launch, Spark at launch | 512², 4×4 | — | 1.5 | not started |
| `T_FX_Pearl_Mask` | [MVP] | Pearl sprite with a glint | 128² | — | 0.4 | not started |
| `T_FX_Moon_Mask` | [MVP] | Crescent and silver mote shapes | 128², 2×2 | — | 0.4 | not started |
| `T_FX_Leaf_Mask` | [MVP] | Kelp scraps and leaves | 128², 2×2 | — | 0.4 | not started |
| `T_FX_Feather_Mask` | [MVP] | Gull feather | 128² | — | 0.3 | not started |
| `T_FX_Snow_Mask` | [MVP] | Marine snow specks | 64², 2×2 | — | 0.2 | not started |
| `T_FX_BannerRibbon_Mask` | [MVP] | Tall ribbon for event light columns | 128 × 512 | — | 0.5 | not started |
| `T_FX_Ember_Mask` | [L] | Ember specks | 128², 2×2 | — | 0.4 | not started |
| `T_FX_Bone_Mask` | [L] | Tiny cartoon bones | 128², 2×2 | — | 0.4 | not started |
| `T_FX_HeatPlume_Flip` | [L] | Rolling hot plume | 512², 4×4 | — | 1.5 | not started |
| `T_FX_SuctionLine_Mask` | [L] | Curved inward streak | 64 × 256 | — | 0.3 | not started |
| `M_Prop_BubbleShell` | [MVP] | Bubble sphere with a painted highlight. Used for the protection bubble, cove displays and Bubbles | 200 tris | T_BubbleShell_Alb | 1 | not started |
| `T_BubbleShell_Alb` | [MVP] | Bubble skin: mostly clear, bright rim and highlight | 256², with alpha | — | 0.5 | not started |

### 9.2 Eating and growth

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `FX_BiteChomp` | [MVP] | A bite landed: five bubbles and one lime-white pop star at the mouth | 6 particles | T_FX_Bubble_Mask, T_FX_Star_Mask (2×2: the star is one still frame of the sheet, not a flipbook; 06 §11.2) | 0.5 | not started |
| `FX_BubblePop_T0` | [MVP] | Plankton eaten: one tiny glint. Must be nearly free; it fires several times a second | 1 particle | T_FX_Star_Mask | 0.3 | not started |
| `FX_BubblePop_T1T2` | [MVP] | Tier 1 and 2 prey: bubble pop and two glints in the prey colour | 8 particles | T_FX_Bubble_Mask, T_FX_Star_Mask | 0.5 | not started |
| `FX_BubblePop_T3T4` | [MVP] | Tier 3 and 4 prey: bigger pop with a ring | 12 particles | T_FX_Ring_Mask | 0.5 | not started |
| `FX_BubblePop_T5T6` | [MVP] | Tier 5 and 6 prey: large pop, ring and bubbles that linger | 18 particles | T_FX_Ring_Mask | 0.6 | not started |
| `FX_TraitPip` | [MVP] | A coloured orb leaves the trait prey and flies into the eater; colour per trait | 4 particles and a trail | T_FX_SoftDot_Mask, T_FX_Streak_Mask | 0.8 | not started |
| `FX_TraitSparkle` | [MVP] | Two small sparkles in the rarity colour on every trait prey | 2 particles each | T_FX_SoftDot_Mask | 0.5 | not started |
| `FX_InkletPuff` | [MVP] | Small ink puff an Inklet leaves when it flees | 4 particles | T_FX_SoftPuff_Flip | 0.3 | not started |
| `FX_TraitGain` | [MVP] | Fifth trait prey eaten: ring and sparkle burst in the trait colour as the body part appears | 30 particles | T_FX_TierRing_Mask, T_FX_Star_Mask | 1 | not started |
| `FX_TraitShed` | [MVP] | Trait dropped: the look drifts off as bubbles | 12 particles | T_FX_Bubble_Mask | 0.5 | not started |
| `FX_TierUp_T2` | [MVP] | Nibbler: ring shockwave, four-point stars in the species light colour, bubbles, and a 0.2 s white flash on the body. The first one a new player sees, inside 30 seconds. Documents 04 and 02 call this effect `FX_TierUp` and `FX_TierUp_Burst` | 20 particles | T_FX_TierRing_Mask | 0.6 | not started |
| `FX_TierUp_T3` | [MVP] | Snapper: ring and glints | 20 particles | FX_TierUp_T2 | 0.5 | not started |
| `FX_TierUp_T4` | [MVP] | Hunter: ring and stars as the adult form appears; `FX_Metamorph` covers the mesh swap | 30 particles | FX_TierUp_T2 | 1 | not started |
| `FX_TierUp_T5` | [MVP] | Brute: ring, glints and a short shockwave | 30 particles | FX_TierUp_T2 | 0.5 | not started |
| `FX_TierUp_T6` | [MVP] | Titan: double ring and pressure wave | 40 particles | FX_TierUp_T2 | 0.6 | not started |
| `FX_TierUp_T7` | [MVP] | Leviathan: the biggest effect in the game; long shimmer, seen by players nearby | 60 particles | FX_TierUp_T2 | 1.5 | not started |
| `FX_Metamorph` | [MVP] | Opaque bubble cloud that covers the body for 0.2 s during the tier 4 form change and the Puff and Shell mesh swaps | 20 particles | T_FX_SoftPuff_Flip | 0.8 | not started |
| `FX_Hatch` | [MVP] | The egg pops: shell bits and bubbles | 10 particles | T_FX_Shard_Mask | 0.4 | not started |

### 9.3 Movement and water

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `FX_DashBurst` | [MVP] | Ring and bubble kick at the start of a dash | 10 particles | T_FX_Ring_Mask, T_FX_Bubble_Mask | 0.5 | not started |
| `FX_DashTrail` | [MVP] | Streak trail for the 0.35 s of a dash, tinted per species | 1 trail, 4 particles | T_FX_Streak_Mask | 0.5 | not started |
| `FX_BubbleTrail` | [MVP] | Ring bubbles off the tail. Denser at sprint speed; a constant thin wake from tier 5 up | 8 particles | T_FX_Bubble_Mask | 0.3 | not started |
| `FX_Bump` | [MVP] | Same-tier players bump: small star and ring | 6 particles | T_FX_Star_Mask | 0.4 | not started |
| `FX_Glint` | [MVP] | One twinkling dot that stands in for any creature too far away to draw; takes the outline colour if the creature has one | 1 particle each | T_FX_Star_Mask | 0.4 | not started |
| `FX_PerfectDodge` | [MVP] | Sparkle on the creature for a dash made just before a predator snaps | 6 particles | T_FX_Star_Mask | 0.3 | not started |
| `FX_GodRay` | [MVP] | Light shafts: beams from the surface, 6 studs wide at the top and 22 at the bottom, with a slow scroll. Hand-placed at canopy gaps, arches and landmarks, plus four that follow the camera. Gone below 200 studs | beams only | T_FX_GodRay_Mask | 1.5 | not started |
| `FX_Splash` | [MVP] | Chunky ring and six teardrops when a creature breaks the surface in either direction, scaled by body size. Never spray | 7 particles | T_FX_Ring_Mask, T_FX_Droplet_Mask | 1 | not started |
| `FX_SurfaceRipple` | [MVP] | Foam rings above a creature that lingers at the surface; this is what gulls see | 4 particles | T_FX_Foam_Flip | 0.5 | not started |
| `FX_Current` | [MVP] | White-aqua streak particles along a current path. No arrows, no tubes | 24 particles per stream | T_FX_Streak_Mask | 1 | not started |
| `FX_CurrentEntry` | [MVP] | Whoosh ring when a creature joins a current | 8 particles | T_FX_Ring_Mask | 0.4 | not started |
| `FX_MarineSnow` | [MVP] | Slow specks fixed to the camera that slide past as it moves; denser with depth | 40 particles; 60 in the deep Drop-off | T_FX_Snow_Mask | 0.5 | not started |
| `FX_Amb_BubbleColumn` | [MVP] | Bubble column for springs | 12 particles | T_FX_Bubble_Mask | 0.4 | not started |
| `FX_Amb_KelpBits` | [MVP] | Kelp scraps drifting in the Kelp Forest | 15 particles | T_FX_Leaf_Mask | 0.3 | not started |
| `FX_Amb_DeepMotes` | [MVP] | Sparse pale motes in the Drop-off | 15 particles | T_FX_SoftDot_Mask | 0.3 | not started |
| `FX_Amb_SandPuff` | [L] | Sand kicks up when a creature skims the floor | 6 particles | T_FX_Silt_Flip | 0.4 | not started |

### 9.4 Run end, banking and cove

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `FX_GulpPop` | [MVP] | A creature is gulped: 12 bubbles, one spinning star and a ring. No debris. Larger when the victim is a player, with the bubbles streaming into the eater. Document 02 calls this the large `FX_BubblePop` | 14 particles | T_FX_Bubble_Mask | 1 | not started |
| `FX_GulpedScraps` | [MVP] | A few Pearls float up from the pop: the scraps | 5 particles | T_FX_Pearl_Mask | 0.4 | not started |
| `FX_ReviveBurst` | [MVP] | Bubbles rush back together and the creature reforms | 30 particles | T_FX_Bubble_Mask | 0.8 | not started |
| `FX_ProtectBubble` | [MVP] | Shield bubble for the 3 s of protection after a revive | 1 mesh, 6 particles | M_Prop_BubbleShell | 0.8 | not started |
| `FX_CoveMembrane` | [MVP] | Soft shimmering curtain across each cove mouth that marks the safe line | 2 scrolling cards | T_FX_Streak_Mask | 1 | not started |
| `FX_CoveBeacon` | [MVP] | Tall lantern-amber beam from the Door Lantern of the player's own cove to the surface | 1 beam, 6 particles | T_FX_GodRay_Mask | 0.5 | not started |
| `FX_HomeTrail` | [MVP] | First-session guide: a line of pearl-white bubbles, one every 6 studs, drifting along the route home | 20 particles | T_FX_Bubble_Mask | 0.5 | not started |
| `FX_BankSwirl` | [MVP] | Spiral of 12 amber motes and a Pearl burst as the creature crosses its cove mouth | 16 particles | T_FX_Bubble_Mask, T_FX_Pearl_Mask | 1.5 | not started |
| `FX_SpecimenPlace` | [MVP] | A new specimen settles into its display: ring and bubbles | 15 particles | T_FX_TierRing_Mask | 0.5 | not started |
| `FX_SpecimenRelease` | [MVP] | A released specimen swims off in a bubble trail | 10 particles | T_FX_Bubble_Mask | 0.4 | not started |
| `FX_PearlPickup` | [MVP] | Pearls arc from the Pearl Clam to the player | 12 particles | T_FX_Pearl_Mask | 0.6 | not started |
| `FX_IncomeTick` | [MVP] | One Pearl pops off a specimen when it earns | 2 particles | T_FX_Pearl_Mask | 0.3 | not started |
| `FX_PearlGlint` | [MVP] | Idle sparkle on waiting Pearls | 2 particles | T_FX_Star_Mask | 0.2 | not started |
| `FX_BubbleLike` | [L] | A visitor's Bubble floats up and joins the jar | 1 mesh, 4 particles | M_Prop_BubbleShell | 0.6 | not started |
| `FX_RankUpBurst` | [L] | Reef Rank gained, shown in the cove | 30 particles | T_FX_TierRing_Mask | 0.6 | not started |
| `FX_TraitLockSeal` | [L] | A shell seal snaps around the traits when a Trait Lock saves them | 10 particles | T_FX_Ring_Mask | 0.6 | not started |

### 9.5 Traits and species abilities

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `FX_GlowAura` | [MVP] | Soft pulsing halo plus a small light | 1 sprite, 1 light | T_FX_SoftDot_Mask | 0.5 | not started |
| `FX_PlateCrack` | [MVP] | Plates crack: shards fly and a crack flashes | 14 particles | T_FX_Shard_Mask, T_FX_Crack_Mask | 0.8 | not started |
| `FX_SpinyDeflect` | [MVP] | A predator that is not big enough bounces off: star burst at the spines | 8 particles | T_FX_Star_Mask | 0.5 | not started |
| `FX_LongfinRibbon` | [MVP] | Two soft ribbons trail from the fins during a dash | 2 trails | T_FX_Streak_Mask | 0.5 | not started |
| `FX_InkCloud` | [MVP] | Eight large soft blobs growing from 3 to 9 studs, plus four small curls, in blue-black. Lasts 3 s and hides a creature | 12 particles | T_FX_SoftPuff_Flip | 1.5 | not started |
| `FX_CrystalGlint` | [MVP] | Occasional glint on the shards | 2 particles | T_FX_Star_Mask | 0.3 | not started |
| `FX_CrystalBankBonus` | [MVP] | Shards burst into extra Pearls on banking | 20 particles | T_FX_Shard_Mask, T_FX_Pearl_Mask | 0.6 | not started |
| `FX_MoonlitAura` | [MVP] | Silver motes in slow orbit | 8 particles | T_FX_Moon_Mask | 0.5 | not started |
| `FX_MoonlitPull` | [MVP] | Faint silver lines from nearby prey toward the creature | 6 beams | T_FX_Streak_Mask | 0.6 | not started |
| `FX_Stun` | [MVP] | Three stars circling the head of any stunned creature | 3 particles | T_FX_StunSpiral_Mask | 0.5 | not started |
| `FX_SparkArc` | [L] | Three short zigzag beams that jump every two frames, plus dot sparks, over the body | 3 beams, 6 particles | T_FX_Zap_Flip | 0.6 | not started |
| `FX_SparkStun` | [L] | Burst 12 studs wide on a dash | 24 particles | T_FX_Zap_Flip, T_FX_Ring_Mask | 1 | not started |
| `FX_CamoShimmer` | [L] | Leaf-edge shimmer as the creature fades out and back | 8 particles | T_FX_Leaf_Mask | 0.6 | not started |
| `FX_EmberMotes` | [L] | Rising ember specks | 8 particles | T_FX_Ember_Mask | 0.4 | not started |
| `FX_EmberShrug` | [L] | A vent or sting fizzles off harmlessly | 8 particles | T_FX_Ember_Mask | 0.5 | not started |
| `FX_BonefedAura` | [L] | Tiny bones in slow orbit | 6 particles | T_FX_Bone_Mask | 0.5 | not started |
| `FX_PuffInflate` | [MVP] | Pufferfish: bubble ring as it balloons | 12 particles | T_FX_Ring_Mask, T_FX_Bubble_Mask | 0.6 | not started |
| `FX_PuffDeflate` | [MVP] | Pufferfish: thin bubble stream from the mouth | 10 particles | T_FX_Bubble_Mask | 0.4 | not started |
| `FX_SlipHole` | [MVP] | Eel: silt puff at an eel hole on entry and exit | 8 particles | T_FX_Silt_Flip | 0.5 | not started |
| `FX_ShellTuck` | [L] | Sea Turtle: glint sweeps across the shell | 4 particles | T_FX_Star_Mask | 0.5 | not started |
| `FX_ShellDeflect` | [L] | Sea Turtle: bonk stars when something bites the shell | 8 particles | T_FX_Star_Mask | 0.5 | not started |
| `FX_JetBurst` | [L] | Squid: hard bubble cone out the front as it shoots back | 16 particles | T_FX_Bubble_Mask | 0.6 | not started |
| `FX_JetInkPuff` | [L] | Squid: small ink puff, a one-second version of the Ink cloud | 6 particles | T_FX_SoftPuff_Flip | 0.4 | not started |
| `FX_RampageStart` | [L] | Shark Pup: warm orange ring when Rampage triggers | 10 particles | T_FX_Ring_Mask | 0.5 | not started |
| `FX_RampageAura` | [L] | Shark Pup: speed streaks and warm glow for 5 s | 10 particles | T_FX_Streak_Mask | 0.6 | not started |

### 9.6 Predators and hazards

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `FX_GullShadow` | [MVP] | Dark oval on the surface that shrinks and darkens for 1.5 s before the dive | no particles | T_Gull_Shadow_Mask | 0.4 | not started |
| `FX_GullDiveSplash` | [MVP] | Plunge seen from below: bubble column and ring | 24 particles | T_FX_Bubble_Mask, T_FX_Ring_Mask | 0.8 | not started |
| `FX_GullFeathers` | [MVP] | Two feathers drift down after a miss | 2 particles | T_FX_Feather_Mask | 0.3 | not started |
| `FX_MorayGlint` | [MVP] | Eyes flash in the hole as the warning | 2 particles | T_FX_Star_Mask | 0.3 | not started |
| `FX_MorayLunge` | [MVP] | Silt bursts from the hole | 10 particles | T_FX_Silt_Flip | 0.5 | not started |
| `FX_BarracudaStreak` | [MVP] | Thin speed streaks while it chases | 1 trail | T_FX_Streak_Mask | 0.4 | not started |
| `FX_OldScarWake` | [MVP] | Dark pressure wake and drifting silt, so players feel Old Scar before they see it | 20 particles | T_FX_Silt_Flip, T_FX_SoftPuff_Flip | 1 | not started |
| `FX_PredBite` | [MVP] | Jaw-snap burst shared by all predators | 10 particles | T_FX_Star_Mask, T_FX_Bubble_Mask | 0.5 | not started |
| `FX_GrouperSuction` | [L] | Cone of inward streaks and bubbles in front of the mouth | 24 particles | T_FX_SuctionLine_Mask | 1 | not started |
| `FX_JellySting` | [MVP] | Zap flash and arcs at the touch point | 8 particles | T_FX_Zap_Flip | 0.6 | not started |
| `FX_AnemoneSlow` | [L] | Sticky wisps cling to the creature for 2 s | 8 particles | T_FX_SoftPuff_Flip | 0.6 | not started |
| `FX_VentPlume` | [L] | Wobbling column of ten orange-white blobs and bubbles, 10 studs wide and 40 tall, rising from the chimney top while a vent is `Erupting`; always on at the three centre vents. Must read as danger from far away | 12 particles per vent | T_FX_HeatPlume_Flip, T_FX_Ember_Mask | 1.5 | not started |
| `FX_VentRumble` | [L] | The 1 s `Rumble` warning before a cycling vent erupts: a burst of small bubbles rises from the chimney top while the rim glow brightens | 8 particles | T_FX_Bubble_Mask | 0.4 | not started |
| `FX_VentBurn` | [L] | Sizzle bubbles on a creature losing mass in a vent | 10 particles | T_FX_Bubble_Mask | 0.5 | not started |
| `FX_HookGlint` | [MVP] | Glint on the bait so it tempts | 1 particle | T_FX_Star_Mask | 0.2 | not started |
| `FX_HookYank` | [MVP] | Comic yank: the line snaps tight, a bubble column, a few mass blobs drop away | 20 particles | T_FX_Bubble_Mask, T_FishingLine_Mask | 1 | not started |

### 9.7 Tide events

The "banner" of an event in the world is a tall light column with a ribbon, visible across the map. It carries no text; the event name is interface.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `FX_TideWarningPulse` | [MVP] | Slow ripple of light across the sea during the 60 s warning | 4 rings | T_FX_Ring_Mask | 0.8 | not started |
| `FX_TideBanner_Frenzy` | [MVP] | Orange light column and ribbon over the busiest spawn area | 2 beams, 10 particles | T_FX_BannerRibbon_Mask | 0.8 | not started |
| `FX_TideBanner_MoonTide` | [MVP] | Silver-blue moonbeam column | 2 beams, 10 particles | FX_TideBanner_Frenzy | 0.5 | not started |
| `FX_TideBanner_WhaleFall` | [L] | Bone-white column over the skeleton site | 2 beams, 10 particles | FX_TideBanner_Frenzy | 0.5 | not started |
| `FX_FrenzySurge` | [MVP] | Feeding Frenzy: shimmer burst where a new school spawns | 10 particles | T_FX_Star_Mask | 0.5 | not started |
| `FX_MoonTideMotes` | [MVP] | Glowing plankton drifting everywhere | 40 particles | T_FX_SoftDot_Mask | 0.5 | not started |
| `FX_LunarFryTrail` | [MVP] | Silver trail so Lunar Fry can be followed in the dark | 1 trail, 4 particles | T_FX_Moon_Mask | 0.4 | not started |
| `FX_Moonbeam` | [MVP] | Pillar of moonlight 50 across from the surface to the floor, full of slow motes. Three per Moon Tide | 2 beams, 20 particles | T_FX_GodRay_Mask, T_FX_Moon_Mask | 0.8 | not started |
| `FX_Coldline` | [MVP] | Shimmering silver-blue layer across the Crack that seals the Trench. Scenery at soft launch and launch; it parts only in The Trench Opens [P2] | 2 scrolling cards | T_FX_Streak_Mask | 0.8 | not started |
| `FX_WhaleFallSinkTrail` | [L] | Bubble and silt trail behind the sinking skeleton | 40 particles | T_FX_Bubble_Mask | 0.8 | not started |
| `FX_WhaleFallSilt` | [L] | Wide silt cloud when the skeleton lands | 30 particles | T_FX_Silt_Flip | 1 | not started |
| `FX_WhaleFallDissolve` | [L] | The skeleton breaks into bubbles when the event ends | 60 particles | T_FX_Bubble_Mask | 0.8 | not started |
| `FX_MarrowGlow` | [L] | Warm pulse on each Marrow chunk | 1 sprite | T_FX_SoftDot_Mask | 0.3 | not started |
| `FX_WhaleFallBeam` | [L] | Pale beam of light that follows the skeleton down and stays over it | 1 beam | T_FX_GodRay_Mask | 0.4 | not started |
| `FX_CallTheTide` | [L] | Wave ring that spreads from the buyer across the sea | 6 rings | T_FX_TierRing_Mask | 0.8 | not started |

## 10. Lighting and atmosphere presets

A preset is one settings file: light direction and colours, fog colour and distance, colour grade, bloom, depth blur, and the strength of light shafts, caustics and glow masks. The game blends between presets as the player crosses zones. Fog distance is also a gameplay number: it sets how early a player can see danger. Starting values for every preset are in document 06, section 10.2; fog colour shifts from the surface colour to the deep colour with camera depth.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `LGT_Nursery` | [MVP] | Brightest and warmest. Turquoise water, long view, strong shafts and caustics. Must feel safe | see document 06 | document 06, section 10.2 | 2.5 | not started |
| `LGT_Reef` | [MVP] | Bright blue-green, full colour, clear view. The reference preset the others are graded from | see document 06 | document 06, section 10.2 | 3 | not started |
| `LGT_Kelp` | [MVP] | Dim green, short view, broken shafts through the canopy | see document 06 | document 06, section 10.2 | 2.5 | not started |
| `LGT_DropOff` | [MVP] | Deep blue falling to near black. Two depth steps blended by how deep the player is; the view shortens on the way down | see document 06 | document 06, section 10.2 | 3 | not started |
| `LGT_Cove` | [MVP] | Warm, lantern-like interior. Specimens lit clearly from the front | no fog | document 06, section 10.2 | 2.5 | not started |
| `LGT_Surface` | [MVP] | Above the waterline during a breach: open sky, no fog | no fog | SKY_Day | 1.5 | not started |
| `LGT_Gulped` | [MVP] | Half-second dim and desaturate when the player is gulped, then back. Values in document 06, section 10.6 | 0.5 s | — | 0.5 | not started |
| `LGT_Event_Frenzy` | [MVP] | The current zone pushed warmer and more saturated | — | zone presets | 1 | not started |
| `LGT_Event_MoonTide` | [MVP] | Night: dark blue ambient, silver shafts, glow masks at full strength, bloom up. Outlines must stay readable | view 220 studs in every zone | SKY_MoonTide, glow masks | 3 | not started |
| (variant) Low-end device variants | [MVP] | Every MVP preset with bloom, depth blur, caustics and shafts reduced or off | — | MVP presets | 2 | not started |
| `LGT_Event_WhaleFall` | [L] | Drop-off made colder and darker with a pale pool of light around the skeleton | — | LGT_DropOff | 2 | not started |
| `LGT_Event_Storm` | [P1] | Grey-green, flickering light from above | — | — | 2 | not started |
| `LGT_Trench` | [P2] | Almost black; light only from glowing things | — | — | 2.5 | not started |
| `LGT_Event_TrenchOpens` | [P2] | Drop-off with a rising glow from below | — | — | 2 | not started |
| `LGT_Event_RedTide` | [P1] | Rust-red haze, short view | — | — | 2 | not started |
| `LGT_Event_Migration` | [P1] | Bright, clear and wide | — | — | 1.5 | not started |

## 11. Audio: sound effects

One row per sound. "× 3" means three takes that play in rotation so the sound does not repeat exactly; the hours cover all takes. All sound effects are mono OGG files. No default Roblox sound is used anywhere, including in the interface.

Two things are done in the engine and need no asset: pitch is lowered as the creature's tier rises, so one bite or voice file serves all seven tiers; and everything is muffled under water and clear above it.

### 11.1 Species voices

Three short blips per species. They are creature noises, never words.

| Asset | Tag | Description | Length (tune) | Hours (tune) | Status |
|---|---|---|---|---|---|
| `SFX_MinnowChirp` | [MVP] | Happy blip: tier-up, banking, Happy emote. Character: bright, glassy squeak | 0.3 s × 2 | 0.5 | not started |
| `SFX_MinnowYelp` | [MVP] | Alarm blip: hit, stunned, or danger very close | 0.3 s × 2 | 0.5 | not started |
| `SFX_MinnowLastSqueak` | [MVP] | Cut-off squeak as the creature is gulped | 0.5 s | 0.5 | not started |
| `SFX_PufferChirp` | [MVP] | Happy blip: tier-up, banking, Happy emote. Character: round, rubbery honk | 0.3 s × 2 | 0.5 | not started |
| `SFX_PufferYelp` | [MVP] | Alarm blip: hit, stunned, or danger very close | 0.3 s × 2 | 0.5 | not started |
| `SFX_PufferLastSqueak` | [MVP] | Cut-off squeak as the creature is gulped | 0.5 s | 0.5 | not started |
| `SFX_EelChirp` | [MVP] | Happy blip: tier-up, banking, Happy emote. Character: sliding, nasal whirr | 0.3 s × 2 | 0.5 | not started |
| `SFX_EelYelp` | [MVP] | Alarm blip: hit, stunned, or danger very close | 0.3 s × 2 | 0.5 | not started |
| `SFX_EelLastSqueak` | [MVP] | Cut-off squeak as the creature is gulped | 0.5 s | 0.5 | not started |
| `SFX_TurtleChirp` | [L] | Happy blip: tier-up, banking, Happy emote. Character: low, woody hoot | 0.3 s × 2 | 0.5 | not started |
| `SFX_TurtleYelp` | [L] | Alarm blip: hit, stunned, or danger very close | 0.3 s × 2 | 0.5 | not started |
| `SFX_TurtleLastSqueak` | [L] | Cut-off squeak as the creature is gulped | 0.5 s | 0.5 | not started |
| `SFX_SquidChirp` | [L] | Happy blip: tier-up, banking, Happy emote. Character: wet, bubbly chirrup | 0.3 s × 2 | 0.5 | not started |
| `SFX_SquidYelp` | [L] | Alarm blip: hit, stunned, or danger very close | 0.3 s × 2 | 0.5 | not started |
| `SFX_SquidLastSqueak` | [L] | Cut-off squeak as the creature is gulped | 0.5 s | 0.5 | not started |
| `SFX_SharkChirp` | [L] | Happy blip: tier-up, banking, Happy emote. Character: gruff little bark | 0.3 s × 2 | 0.5 | not started |
| `SFX_SharkYelp` | [L] | Alarm blip: hit, stunned, or danger very close | 0.3 s × 2 | 0.5 | not started |
| `SFX_SharkLastSqueak` | [L] | Cut-off squeak as the creature is gulped | 0.5 s | 0.5 | not started |

### 11.2 Eating, movement and growth

| Asset | Tag | Description | Length (tune) | Hours (tune) | Status |
|---|---|---|---|---|---|
| `SFX_Bite_Small` | [MVP] | Eater tiers 1 and 2. Light wooden click with a wet edge | 0.15 s × 3 | 0.6 | not started |
| `SFX_Bite_Medium` | [MVP] | Eater tiers 3 and 4. Fuller chomp | 0.2 s × 3 | 0.6 | not started |
| `SFX_Bite_Large` | [MVP] | Eater tiers 5 and 6. Deep chomp with a short low thump | 0.25 s × 3 | 0.6 | not started |
| `SFX_Bite_Huge` | [MVP] | Tier 7. Boom and jaw clack | 0.35 s × 3 | 0.8 | not started |
| `SFX_EatPlankton` | [MVP] | Tiny soft tick. Quiet, because it can fire many times a second | 0.08 s × 4 | 0.4 | not started |
| `SFX_Swallow_Small` | [MVP] | Quick rising gulp after a small bite | 0.2 s × 3 | 0.5 | not started |
| `SFX_Swallow_Large` | [MVP] | Big cartoon gulp after a large bite | 0.4 s × 3 | 0.5 | not started |
| `SFX_Gulp` | [MVP] | The eater's gulp, then a bubble burp. This is the sound the game is named after; it gets the most care | 0.8 s × 2 | 1.5 | not started |
| `SFX_UI_TraitPip` | [MVP] | Mallet note that steps up with each trait prey, 1 to 5. Document 04 calls it `SFX_TraitPip` | 0.3 s × 5 | 0.8 | not started |
| `SFX_UI_TraitsFull` | [MVP] | Trait prey eaten with three traits already held | 0.3 s | 0.2 | not started |
| `SFX_PreyScatter` | [MVP] | Soft swish as a school breaks apart | 0.5 s × 2 | 0.5 | not started |
| `SFX_CrystalJellyShimmer` | [MVP] | Glassy shimmer heard within about 80 studs, so players can hunt the Crystal Jelly by ear | loop 2 s | 0.6 | not started |
| `SFX_LunarFryShimmer` | [MVP] | Softer, lower shimmer on each Lunar Fry | loop 2 s | 0.4 | not started |
| `SFX_SwimLoop` | [MVP] | Soft water rush; volume and pitch follow speed | loop 3 s | 0.6 | not started |
| `SFX_Dash_Small` | [MVP] | Tiers 1 to 3. Quick bubbly whoosh | 0.3 s × 2 | 0.5 | not started |
| `SFX_Dash_Large` | [MVP] | Tiers 4 to 7. Heavier whoosh | 0.4 s × 2 | 0.5 | not started |
| `SFX_UI_Dash` | [MVP] | Dash button pressed: soft click under the whoosh | 0.08 s | 0.2 | not started |
| `SFX_UI_Ability` | [MVP] | Ability button pressed | 0.1 s | 0.2 | not started |
| `SFX_UI_DashReady` | [MVP] | Faint tick when the dash cooldown ends | 0.1 s | 0.2 | not started |
| `SFX_Bump` | [MVP] | Rubbery bonk when same-tier players collide | 0.2 s | 0.3 | not started |
| `SFX_TierUp_T2` | [MVP] | Nibbler. Three-note mallet run and a bubble swell | 0.8 s | 0.6 | not started |
| `SFX_TierUp_T3` | [MVP] | Snapper. Adds a note | 0.9 s | 0.5 | not started |
| `SFX_TierUp_T4` | [MVP] | Hunter. Adds a low drum for the adult body | 1.2 s | 0.8 | not started |
| `SFX_TierUp_T5` | [MVP] | Brute. Adds weight and a second drum | 1.3 s | 0.5 | not started |
| `SFX_TierUp_T6` | [MVP] | Titan. Full run with a low swell | 1.6 s | 0.6 | not started |
| `SFX_TierUp_T7` | [MVP] | Leviathan. Full chord and a low horn; nearby players hear it too | 2.5 s | 1.2 | not started |
| `SFX_UI_TierUp` | [MVP] | Interface layer over the tier-up; a longer take for tier 7 | 0.6 s and 1.5 s × 2 | 0.5 | not started |
| `SFX_TierDown` | [MVP] | Short falling note when mass is lost and a tier drops | 0.4 s | 0.3 | not started |
| `SFX_Hatch` | [MVP] | Soft pop and a squeak as a Fry leaves the egg, at the start of every run | 0.6 s | 0.4 | not started |
| `SFX_PerfectDodge` | [MVP] | Bright ping for a dash made just before a predator snaps | 0.3 s | 0.3 | not started |

### 11.3 Abilities and traits

| Asset | Tag | Description | Length (tune) | Hours (tune) | Status |
|---|---|---|---|---|---|
| `SFX_UI_AbilityReady` | [MVP] | Soft chime when an ability cooldown ends | 0.2 s | 0.2 | not started |
| `SFX_UI_Locked` | [MVP] | Dull thud for a tap on a disabled or locked control, including an ability on cooldown | 0.15 s | 0.2 | not started |
| `SFX_PuffInflate` | [MVP] | Pufferfish: balloon squeak and a pop of air | 0.4 s | 0.5 | not started |
| `SFX_PuffDeflate` | [MVP] | Pufferfish: raspberry of bubbles | 0.5 s | 0.4 | not started |
| `SFX_SlipHole` | [MVP] | Eel: slick slurp through rock | 0.4 s | 0.4 | not started |
| `SFX_ShellTuck` | [L] | Sea Turtle: hollow wooden clunk | 0.3 s | 0.4 | not started |
| `SFX_ShellDeflect` | [L] | Sea Turtle: coconut bonk when bitten in the shell | 0.3 s | 0.4 | not started |
| `SFX_ShellOut` | [L] | Sea Turtle: soft pop back out | 0.3 s | 0.3 | not started |
| `SFX_Jet` | [L] | Squid: sharp squirt | 0.4 s | 0.4 | not started |
| `SFX_RampageStart` | [L] | Shark Pup: playful growl that revs up | 0.6 s | 0.5 | not started |
| `SFX_RampageLoop` | [L] | Shark Pup: fast pulsing rush for the 5 s boost | loop 1 s | 0.4 | not started |
| `SFX_UI_TraitGain` | [MVP] | Trait gained, one take per rarity: a two-note chime for Common up to a chord with a choir-like tail for Mythic. Document 04 calls it `SFX_TraitGained` | 0.8 to 1.8 s × 5 | 2.5 | not started |
| `SFX_UI_TraitShed` | [MVP] | Trait dropped: small falling note and bubbles | 0.4 s | 0.3 | not started |
| `SFX_GlowPing` | [MVP] | Glow: soft sonar ping when a trait-prey marker appears | 0.3 s | 0.3 | not started |
| `SFX_PlateCrack` | [MVP] | Plated: pottery crack | 0.4 s | 0.4 | not started |
| `SFX_SpinyDeflect` | [MVP] | Spiny: springy boing as a predator bounces off | 0.3 s | 0.3 | not started |
| `SFX_InkCloud` | [MVP] | Ink: wet puff | 0.6 s | 0.4 | not started |
| `SFX_CrystalBonus` | [MVP] | Crystal: glass chimes over the bank tally | 0.8 s | 0.4 | not started |
| `SFX_MoonlitHum` | [MVP] | Moonlit: faint choir-like hum while prey drifts in | loop 2 s | 0.5 | not started |
| `SFX_SparkStun` | [L] | Spark: zap with a rubbery tail | 0.5 s | 0.5 | not started |
| `SFX_CamoOn` | [L] | Camo: soft leafy hush as the creature fades | 0.4 s | 0.3 | not started |
| `SFX_CamoOff` | [L] | Camo: the reverse | 0.3 s | 0.2 | not started |
| `SFX_EmberShrug` | [L] | Ember: sizzle that fizzles out | 0.4 s | 0.3 | not started |
| `SFX_BonefedRattle` | [L] | Bonefed: xylophone bone rattle on bonus mass | 0.4 s | 0.3 | not started |

### 11.4 Predators and hazards

Each predator has a warning sound that plays before it can hurt the player. A player should be able to dodge with the screen dimmed.

| Asset | Tag | Description | Length (tune) | Hours (tune) | Status |
|---|---|---|---|---|---|
| `SFX_GullCry` | [MVP] | Warning: muffled gull cry from above as the shadow appears | 0.8 s × 2 | 0.5 | not started |
| `SFX_GullDive` | [MVP] | Plunge splash heard from below | 0.6 s | 0.5 | not started |
| `SFX_GullMiss` | [MVP] | Annoyed squawk and wing flaps | 0.8 s | 0.4 | not started |
| `SFX_MorayHiss` | [MVP] | Warning: bubbly hiss from the hole | 0.5 s | 0.4 | not started |
| `SFX_MorayLunge` | [MVP] | Whip and snap | 0.4 s | 0.4 | not started |
| `SFX_BarracudaAlert` | [MVP] | Warning: sharp metallic ting when it locks on | 0.4 s | 0.4 | not started |
| `SFX_BarracudaChase` | [MVP] | Fast fluttering rush while it chases | loop 1 s | 0.4 | not started |
| `SFX_BarracudaGiveUp` | [MVP] | Huffy bubble snort | 0.5 s | 0.3 | not started |
| `SFX_BarracudaSnap` | [MVP] | Wooden clack on each Barracuda lunge | 0.3 s × 2 | 0.3 | not started |
| `SFX_PredatorShadow` | [MVP] | Low swell as a predator's shadow passes; never a jump scare | 1.5 s | 0.4 | not started |
| `SFX_UI_ThreatNear` | [MVP] | Soft double pulse when a threat comes within 30 studs; at most once per threat every 5 s | 0.4 s | 0.3 | not started |
| `SFX_OldScarNear` | [MVP] | Low rumble with a slow drum pulse; louder as Old Scar gets closer | loop 4 s | 1 | not started |
| `SFX_OldScarAlert` | [MVP] | Warning: low horn stab when it picks a target | 1.0 s | 0.8 | not started |
| `SFX_OldScarBite` | [MVP] | Huge clap of jaws | 0.6 s | 0.5 | not started |
| `SFX_PredBite` | [MVP] | Predator snap shared by Moray and Barracuda, and by Grouper at launch | 0.3 s × 2 | 0.4 | not started |
| `SFX_GrouperWarn` | [L] | Warning: deep slow inhale | 0.8 s | 0.4 | not started |
| `SFX_GrouperSuction` | [L] | Hollow vacuum rush | loop 1.5 s | 0.5 | not started |
| `SFX_GrouperGulp` | [L] | Wide wet gulp | 0.5 s | 0.3 | not started |
| `SFX_JellyHum` | [MVP] | Faint electric hum near a bloom | loop 2 s | 0.4 | not started |
| `SFX_JellySting` | [MVP] | Soft zap and wobble | 0.4 s | 0.4 | not started |
| `SFX_AnemoneSlow` | [L] | Sticky squelch | 0.5 s | 0.3 | not started |
| `SFX_VentLoop` | [L] | Rumbling hiss around a vent while it is `Erupting` | loop 3 s | 0.5 | not started |
| `SFX_VentRumble` | [L] | Low rumble for the 1 s warning before a cycling vent erupts, heard within 60 studs | 1.0 s | 0.3 | not started |
| `SFX_VentBurn` | [L] | Sizzle while a creature is inside | loop 1 s | 0.3 | not started |
| `SFX_HookBite` | [MVP] | Metal ting: the bait was a hook | 0.3 s | 0.3 | not started |
| `SFX_HookReel` | [MVP] | Comic fast reel with a rising whistle | 1.2 s | 0.6 | not started |
| `SFX_HookDrop` | [MVP] | Plop back into the water | 0.6 s | 0.3 | not started |
| `SFX_CurrentLoop` | [MVP] | Steady rushing stream | loop 3 s | 0.5 | not started |
| `SFX_CurrentEnter` | [MVP] | Short whoosh on joining a current | 0.4 s | 0.3 | not started |

### 11.5 Run end, banking, Pearls and interface

| Asset | Tag | Description | Length (tune) | Hours (tune) | Status |
|---|---|---|---|---|---|
| `SFX_Gulped` | [MVP] | Pop, then a small sad bubble trail. Funny, never harsh | 0.8 s | 1 | not started |
| `SFX_UI_Gulped` | [MVP] | Interface layer when the player is gulped | 0.6 s | 0.3 | not started |
| `SFX_Scraps` | [MVP] | Three small Pearl ticks for the scraps | 0.5 s | 0.3 | not started |
| `SFX_UI_Revive` | [MVP] | Reversed pop and a rising chime | 1.0 s | 0.5 | not started |
| `SFX_Bank` | [MVP] | Crossing your own cove mouth: a deep, satisfying clunk and chime. The relief of getting home | 1.2 s | 1 | not started |
| `SFX_UI_BankStart` | [MVP] | Bank summary opens | 0.5 s | 0.3 | not started |
| `SFX_UI_PearlBurst` | [MVP] | A Pearl count-up ends | 0.5 s | 0.3 | not started |
| `SFX_UI_BankCard` | [MVP] | The specimen card flips in | 0.4 s | 0.3 | not started |
| `SFX_UI_PearlTick` | [MVP] | One tick per step of a Pearl count-up, every 60 ms. Document 04 calls it `SFX_PearlCount` | 0.06 s | 0.4 | not started |
| `SFX_SpecimenPlace` | [MVP] | Settling chime as the specimen takes its place | 1.0 s | 0.5 | not started |
| `SFX_UI_Release` | [MVP] | Soft swish and bubbles | 0.6 s | 0.3 | not started |
| `SFX_PearlPickup` | [MVP] | Glassy clink in four rising pitches | 0.15 s × 4 | 0.5 | not started |
| `SFX_IncomeTick` | [MVP] | One soft clink when a specimen earns | 0.2 s | 0.2 | not started |
| `SFX_UI_Claim` | [MVP] | Shower of clinks for the offline claim | 1.5 s | 0.5 | not started |
| `SFX_PearlSpend` | [MVP] | Clinks pouring out | 0.5 s | 0.3 | not started |
| `SFX_UI_Bubble` | [L] | A Bubble is blown and let go | 0.5 s | 0.3 | not started |
| `SFX_UI_Tap` | [MVP] | Any button. Soft wooden tap | 0.08 s | 0.3 | not started |
| `SFX_UI_Hover` | [MVP] | Desktop hover; very quiet | 0.05 s | 0.2 | not started |
| `SFX_UI_Focus` | [L] | Gamepad focus moves | 0.05 s | 0.2 | not started |
| `SFX_UI_Back` | [MVP] | Close or back. Lower tap | 0.1 s | 0.2 | not started |
| `SFX_UI_Open` | [MVP] | Panel opens. Rising bubble | 0.25 s | 0.3 | not started |
| `SFX_UI_Tab` | [MVP] | Tab or page change | 0.1 s | 0.2 | not started |
| `SFX_UI_Toggle` | [MVP] | Switch on and switch off | 0.1 s × 2 | 0.2 | not started |
| `SFX_UI_Error` | [MVP] | Not allowed or not enough Pearls. Two dull mallet notes down | 0.25 s | 0.3 | not started |
| `SFX_UI_Purchase` | [MVP] | Any completed purchase. Bright chime and Pearl shimmer | 1.0 s | 0.5 | not started |
| `SFX_UI_SpeciesUnlock` | [MVP] | Short fanfare for a new species | 2.0 s | 0.8 | not started |
| `SFX_UI_GoalDone` | [MVP] | Daily goal complete | 0.8 s | 0.4 | not started |
| `SFX_UI_GoalClaim` | [MVP] | A goal reward is claimed | 0.6 s | 0.3 | not started |
| `SFX_UI_SlotUnlock` | [MVP] | A cove slot is added | 0.8 s | 0.3 | not started |
| `SFX_UI_Pick` | [MVP] | A species is picked; a puff of bubbles | 0.4 s | 0.3 | not started |
| `SFX_UI_GuideStep` | [MVP] | A first-session prompt step is done | 0.3 s | 0.2 | not started |
| `SFX_SilhouetteReveal` | [MVP] | The next species lights up as a silhouette on the cove wall | 1.2 s | 0.4 | not started |
| `SFX_TideClock` | [MVP] | The tide clock appears and ticks once | 0.8 s | 0.3 | not started |
| `SFX_UI_CodexNew` | [MVP] | New Codex entry | 0.6 s | 0.3 | not started |
| `SFX_UI_Toast` | [MVP] | A toast arrives | 0.4 s | 0.3 | not started |
| `SFX_UI_Countdown` | [MVP] | Tick played at 3, 2 and 1 seconds before a tide event starts, inside the last-10-seconds banner (document 08). One file, played three times | 0.15 s | 0.2 | not started |
| `SFX_UI_EventWarn` | [MVP] | Event warning banner | 0.5 s | 0.3 | not started |
| `SFX_UI_EventStart` | [MVP] | Event start banner; also when a player calls the tide | 0.6 s | 0.3 | not started |
| `SFX_UI_StreakClaim` | [L] | Login streak reward claimed | 1.0 s | 0.4 | not started |
| `SFX_UI_RankUp` | [L] | Reef Rank gained | 1.5 s | 0.5 | not started |
| `SFX_UI_DecoPlace` | [L] | A decoration is placed | 0.3 s | 0.2 | not started |
| `SFX_UI_DecoStore` | [L] | A decoration is put away | 0.3 s | 0.2 | not started |
| `SFX_UI_Emote` | [L] | One take per emote in document 03: two bubble pops (Hi), a short whistle (This way), two warning blips (Look out), a soft chime (Thanks), a bubbly giggle (Ha ha), a falling bloop (Oops) | 0.3 to 0.6 s × 6 | 1.5 | not started |

### 11.6 Events, ambience and transitions

Ambience beds are stereo loops; the game crossfades between them at zone borders. Spot sounds are mono and placed in the world.

| Asset | Tag | Description | Length (tune) | Hours (tune) | Status |
|---|---|---|---|---|---|
| `SFX_TideBell` | [MVP] | The 60-second warning for every event: one deep bell that carries across the whole sea (document 03). Document 04 calls the warning `SFX_TideHorn` | 2.5 s | 1 | not started |
| `SFX_TideHorn_Frenzy` | [MVP] | Feeding Frenzy starts. Two rising conch blasts with drums | 2.0 s | 0.8 | not started |
| `SFX_TideHorn_MoonTide` | [MVP] | Moon Tide starts. Soft glass horn and a chime swell | 3.0 s | 0.8 | not started |
| `SFX_TideHorn_WhaleFall` | [L] | Whale Fall starts. Low horn answered by a falling whale call | 4.0 s | 1 | not started |
| `SFX_UI_EventEnd` | [MVP] | Any event ends. Horn falling away | 1.5 s | 0.4 | not started |
| `SFX_WhaleFallSink` | [L] | Slow groaning descent | loop 4 s | 0.6 | not started |
| `SFX_WhaleFallImpact` | [L] | Deep soft boom and a rush of silt | 2.0 s | 0.6 | not started |
| `SFX_MarrowCrunch` | [L] | Hollow crunchy bite for Marrow chunks | 0.3 s × 2 | 0.3 | not started |
| `SFX_CallTheTide` | [L] | Bright horn flourish when a player calls the tide | 2.0 s | 0.5 | not started |
| `SFX_Amb_Nursery` | [MVP] | Gentle bubbles and soft lapping. No low end | loop 30 s | 1 | not started |
| `SFX_Amb_Reef` | [MVP] | Busy reef crackle, far-off clicks, light water movement | loop 45 s | 1.5 | not started |
| `SFX_Amb_Kelp` | [MVP] | Muffled and close; slow swells and creaks | loop 45 s | 1.5 | not started |
| `SFX_Amb_DropOff` | [MVP] | Wide low drone, sparse; far whale calls | loop 45 s | 1.5 | not started |
| `SFX_Amb_Cove` | [MVP] | Cave drip and soft bubbling. Calm | loop 30 s | 1 | not started |
| `SFX_Amb_Surface` | [MVP] | Above water: wind, small waves, distant gulls | loop 30 s | 1 | not started |
| `SFX_Amb_MoonTide` | [MVP] | Night sea: shimmer and soft tones over the zone bed | loop 30 s | 1 | not started |
| `SFX_Amb_Trench` | [P2] | Pressure, slow groans, almost silent | loop 45 s | 1.5 | not started |
| `SFX_Amb_BubbleColumn` | [MVP] | Spot: bubbling spring | loop 4 s | 0.3 | not started |
| `SFX_Amb_KelpCreak` | [MVP] | Spot: stalk creaks at random | 1.0 s × 3 | 0.4 | not started |
| `SFX_KelpPart` | [MVP] | Soft rustle as a creature pushes through kelp | 0.4 s × 2 | 0.3 | not started |
| `SFX_Amb_AnchorBuoy` | [MVP] | Spot: muffled bell from the buoy above the Old Anchor, so players can find the West Pass by ear | 2.0 s × 2 | 0.5 | not started |
| `SFX_Amb_WhaleFar` | [MVP] | Rare far-off whale call in the Drop-off | 5.0 s × 2 | 0.5 | not started |
| `SFX_Amb_WreckGroan` | [MVP] | Spot: metal groans at the Tin Pickle | 3.0 s × 2 | 0.4 | not started |
| `SFX_SurfaceBreach` | [MVP] | Bursting out: splash and sudden open air | 0.6 s | 0.5 | not started |
| `SFX_SurfaceSplash` | [MVP] | Landing splash, then the muffle returns | 0.7 s | 0.5 | not started |
| `SFX_SurfaceRipple` | [MVP] | Small lapping while a creature sits at the surface | loop 2 s | 0.3 | not started |
| `SFX_ZoneEnter` | [MVP] | Soft swell on crossing a zone border | 1.0 s | 0.3 | not started |
| `SFX_DepthPressure` | [MVP] | Low creak on passing into deep water | 1.5 s | 0.3 | not started |

## 12. Audio: music

**Audio style.** GULP sounds like a toy box under water. The core instruments are wooden mallets (marimba, kalimba, xylophone), hand percussion, a plucked bass, soft rounded synth pads, and bubbles and water sounds used as rhythm. Melodies are short and hummable. Nothing is harsh, metallic or orchestral-heavy; danger is carried by low drums and bass, not by horror sounds. Sound effects use the same materials (wood, glass, rubber, bubbles) so the effects and the music sound like one set.

**How the music is mixed in the game.**

- All looping tracks share one tempo (124 beats per minute, tune; the tempo document 11 gives the theme) and related keys, so tracks can crossfade and layers can stack without clashing.
- Each zone track has two stems: **base** (pads, bass, melody) and **rhythm** (mallet pattern, percussion). Only the base plays when the player is idle or tiny; the rhythm stem joins as the player grows, so the music gains a layer with size (documents 04 and 11). `MUS_Nursery` has four stems because the first two minutes add them one at a time.
- `MUS_Danger` has no melody. It fades in over any zone track when a creature that can eat the player is close; its second stem joins when the threat is very close. When a predator locks on, `MUS_Chase` takes over, then resolves into `MUS_Current` or back to the zone track.
- An event theme replaces the zone track with a two-second crossfade when the event starts, and hands back when it ends. `MUS_Event_Warning` plays over the zone track during the 60-second warning.
- `MUS_Tier7` replaces the zone track while the player is a Leviathan.
- Stingers play on top and briefly lower the music under them.
- Four volume groups: music, ambience, effects, interface. The settings screen (document 08) exposes music and effects sliders.

Stems are separate files of the same length that start together; Qty counts them.

| Asset | Tag | Description | Qty | Length and loop (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|---|
| `MUS_Cove` | [MVP] | Cove and menu theme. Home: warm, slow, safe. Marimba, soft pad, light bubbles. States the main tune | 1 | 90 s loop | main tune | 8 | not started |
| `MUS_Reef` | [MVP] | Sunlit Reef. Bright and bouncy. Mallets, plucked bass, hand percussion. The main tune at full energy | 2 | 120 s loop | main tune | 10 | not started |
| `MUS_Nursery` | [MVP] | Nursery Lagoon and the first session. Four stems that the first two minutes add one at a time: base, a light pluck at mass 5, percussion at the first tier-up, a shimmering pad at the first trait (document 04) | 4 | 60 s loop | MUS_Reef | 6 | not started |
| `MUS_Kelp` | [MVP] | Kelp Forest. Curious and a little tense. Kalimba, bowed pad, shakers | 2 | 120 s loop | — | 9 | not started |
| `MUS_DropOff` | [MVP] | The Drop-off. Wide and deep. Low mallets, slow synth swells, long echo | 2 | 120 s loop | — | 9 | not started |
| `MUS_Danger` | [MVP] | Danger layer. Low drums and pulsing bass in two strengths. No melody, so it sits over every zone track | 2 | 32 s loop | tempo of zone tracks | 5 | not started |
| `MUS_Chase` | [MVP] | Chase track for a predator that has locked on: tense for a few seconds at a time, never scary. A loop and a short ending for when the predator gives up | 2 | 30 s loop and 4 s ending | MUS_Danger | 5 | not started |
| `MUS_Current` | [MVP] | Wide, relieved theme that the chase resolves into when the player rides a current home | 1 | 20 s | MUS_Chase | 3 | not started |
| `MUS_Event_Warning` | [MVP] | Riser for the 60-second warning; lands on the event start | 1 | 60 s, plays once | — | 3 | not started |
| `MUS_Event_Frenzy` | [MVP] | Feeding Frenzy. Fast, drum-led party version of the main tune | 1 | 60 s loop, plays 4 times | MUS_Reef | 7 | not started |
| `MUS_Event_MoonTide` | [MVP] | Moon Tide. Slow and glowing. Glass mallets, choir-like pad | 1 | 80 s loop, plays 3 times | — | 7 | not started |
| `MUS_Sting_Victory` | [MVP] | Bank stinger. Rising mallet run to a warm chord | 1 | 4 s | MUS_Cove | 1 | not started |
| `MUS_Sting_Gulped` | [MVP] | Gulped stinger. Falling mallet run and one bubble. Light, never punishing | 1 | 3 s | — | 1 | not started |
| `MUS_Event_WhaleFall` | [L] | Whale Fall. Solemn, then tense. Low horn calls, deep drums | 1 | 80 s loop, plays 3 times | — | 8 | not started |
| `MUS_Tier7` | [L] | Leviathan theme. The main tune played slow and huge on low synths | 1 | 60 s loop | MUS_Reef | 6 | not started |
| `MUS_Sting_Leviathan` | [L] | Stinger on reaching tier 7; leads into `MUS_Tier7` | 1 | 5 s | MUS_Tier7 | 1 | not started |
| `MUS_Theme` | [MVP] | The GULP theme: the main tune at full strength for the gameplay preview video and its social cuts (document 11). Marimba, kalimba, plucked strings, hand claps, round sub-bass, water percussion. Ends on a beat of silence before the "gulp" | 1 | 30 s | those three tracks | 5 | not started |
| `MUS_Event_Storm` | [P1] | Storm theme | 1 | 80 s loop | — | 7 | not started |
| `MUS_Trench` | [P2] | Trench zone track with two stems | 2 | 120 s loop | — | 9 | not started |
| `MUS_Event_TrenchOpens` | [P2] | Trench Opens theme | 1 | 80 s loop | — | 7 | not started |
| `MUS_Event_RedTide` | [P1] | Red Tide theme | 1 | 80 s loop | — | 7 | not started |
| `MUS_Event_Migration` | [P1] | Great Migration theme | 1 | 80 s loop | — | 7 | not started |

Loop points: every loop starts and ends on a bar line with the echo tail of the end mixed into the start, so the file loops from its first sample to its last with no gap.

Music hours assume composing from scratch. Licensing finished tracks instead cuts the hours by more than half but gives up the shared tune and the matching stems.

**Roblox audio upload rules to check before any audio work is scheduled** (these change; confirm the current values in the Creator documentation):

1. Which file types are accepted, and the per-file caps on length and size. Believed to be about 7 minutes and 20 MB; every file here is far below that.
2. The free upload quota per month, and whether verifying the account raises it. This list has about 262 audio files, about 201 of them for soft launch, so the quota sets the upload calendar.
3. Ownership: upload every file from the account or group that owns the game, so the game has permission to play it. Audio is private to its owner.
4. Moderation: each file is reviewed and can be rejected. Voice blips must not sound like words.
5. Licences: any library sound must allow use in a commercial game and upload to a third-party platform. Keep the licence text in `assets/licences/`.
6. Loops: MP3 files gain a short silence at each end and click when looped. Export loops as OGG and test each one in Studio.
7. Loudness: the platform does not level files. Level them before upload (suggested: music at −16 LUFS, effect peaks at −3 dB, tune).

## 13. Store-page source art

Document 11 owns the store page: it defines five icons (A to E), eight thumbnails (T1 to T8) and a 24-second gameplay preview, and it names the finished files `UI_Store_…`. Icon A and thumbnails T3, T4 and T5 each have a soft-launch version [MVP], which shows only what is in the soft-launch slice (the Barracuda, not Old Scar), and a public-launch version [L] (document 11, sections 3.2 and 4.2). Each version is its own row here, with its own hours; a public-launch row is sized as a re-stage of its soft-launch scene. Each image is staged with the real game models, rendered, then lightly painted over. **This section lists only the staged 3D scenes** that produce the plates for that paint-over. Nothing may appear in a scene that is not in the build at that scope.

The preview video is recorded gameplay, not a rendered trailer, so it needs capture set-ups, not scenes. Pass, product and badge icons (document 11, section 12, rows 12 to 18) are flat images; where one needs a creature, it uses a render from the pose set below.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| `SCN_Stage_Reef` | [MVP] | Master stage: a dressed piece of Reef, the water look, a light rig with a warm key from top left, and camera presets. Every plate starts from it | — | Reef kit, water and sky, LGT_Reef | 6 | not started |
| (pose) Marketing pose set, soft launch | [MVP] | Expression and action poses for Minnow, Pufferfish and Eel, the Barracuda mid-lunge and with its jaws open for icon A, and Krill, following document 11, section 8.5. Rendered on clear backgrounds for icons and flat art | — | species and predator rigs | 5 | not started |
| (pose) Marketing pose set, launch | [L] | The same for Sea Turtle, Squid and Shark Pup, each in its ability pose, and the Grouper | — | launch species | 4 | not started |
| `SCN_Icon_A_BehindYou` | [MVP] | Main icon, soft-launch version (document 11, section 3.2). A Minnow that has just eaten, krill tail in its mouth, eyes turned back; behind it the long open jaws of the Barracuda, seen from the front and slightly to one side, close in from the top and the bottom. Old Scar is not in the soft-launch slice, so it is not in this scene. Must read at 110 and 64 pixels | 2048² master | SCN_Stage_Reef, pose set | 5 | not started |
| `SCN_Icon_D_Puffed` | [MVP] | Test icon. One fully puffed Pufferfish face fills 85% of the frame, a Sardine tail sticking out of its lips | 2048² master | pose set | 3 | not started |
| `SCN_Icon_A_BehindYou_Launch` | [L] | Main icon, public-launch version, live at public launch. The same Minnow, layout, colours and light as `SCN_Icon_A_BehindYou`; the predator changes to Old Scar, whose open mouth fills the whole frame like a ring, with the pale healed scar line across the upper lip. The hours include Old Scar's open-mouth pose. Must read at 110 and 64 pixels | 2048² master | SCN_Icon_A_BehindYou, M_Pred_OldScar | 2.5 | not started |
| `SCN_Icon_B_TeethFrame` | [L] | Test icon. Camera inside the predator's mouth looking out; teeth frame the top and bottom; the Minnow brakes in bright water beyond | 2048² master | SCN_Icon_A_BehindYou | 3 | not started |
| `SCN_Icon_C_FoodChain` | [L] | Test icon. A diagonal of Krill, Minnow and Barracuda, each with its mouth open behind the one before | 2048² master | pose set | 3 | not started |
| `SCN_Icon_E_MouthMark` | [L] | Test icon "Mouth mark". The mouth shape of the logo's U (document 11, section 8.1), on its own with no letters, fills 80% of the width; a small Minnow is half inside it, tail and one worried eye showing. No text, as on every icon | 2048² master | pose set | 1.5 | not started |
| `SCN_Thumb_T1_Chase` | [MVP] | Lead thumbnail. Side view: a Barracuda with a red outline, mouth opening; the Minnow at full dash ahead of it | 1920 × 1080 | SCN_Stage_Reef | 4 | not started |
| `SCN_Thumb_T2_BecomeWhatYouEat` | [MVP] | Three panels: a trait prey on the left of each, the same Minnow on the right now wearing that trait | 1920 × 1080 | MVP trait rows | 4 | not started |
| `SCN_Thumb_T3_GetHome` | [MVP] | Soft-launch version. From behind and above: a Nibbler-tier Minnow with Glow races for a lit cove mouth; a Barracuda, a little under twice the Minnow's size, enters from the left edge with a red outline. This is the chase of the first two minutes | 1920 × 1080 | M_Cove_Mouth, M_Pred_Barracuda | 4 | not started |
| `SCN_Thumb_T3_GetHome_Launch` | [L] | Public-launch version. The same shot with a Snapper-tier Minnow; the predator is Old Scar's head, about four times the Minnow's size | 1920 × 1080 | SCN_Thumb_T3_GetHome, M_Pred_OldScar | 1.5 | not started |
| `SCN_Thumb_T4_FiveSizes` | [MVP] | Soft-launch version, "Five sizes". The Minnow at tiers 1, 2, 3, 4 and 5 (Fry to Brute) in a line on a plain gradient, the adult mesh from tier 4; the Brute breaks the top and right edges of the frame. No Titan, no Leviathan and no crest: the slice does not reach them | 1920 × 1080 | pose set | 3 | not started |
| `SCN_Thumb_T4_SevenSizes` | [L] | Public-launch version, "Seven sizes". The same line-up with the Minnow at tiers 1, 3, 5 and 7; the Leviathan wears its crest and breaks the top and right edges of the frame | 1920 × 1080 | SCN_Thumb_T4_FiveSizes, M_Species_Minnow_Crest | 1.5 | not started |
| `SCN_Thumb_T5_YourCove` | [MVP] | Soft-launch version. Inside a cove in warm light: six specimens at their perches, Minnow and Pufferfish only, wearing the five slice traits (Glow, Stripes, Spots, Plated, Spiny); Pearls drifting up, a Minnow swimming in | 1920 × 1080 | cove kit | 4 | not started |
| `SCN_Thumb_T5_YourCove_Launch` | [L] | Public-launch version. The same shot with six specimens of Minnow, Pufferfish and Eel, with traits | 1920 × 1080 | SCN_Thumb_T5_YourCove, Eel rows | 1 | not started |
| `SCN_Thumb_T6_MoonTide` | [MVP] | The Reef at night with glowing edges; a school of Lunar Fry crosses; a Pufferfish with the Moonlit glow in the centre | 1920 × 1080 | Moon Tide rows | 4 | not started |
| `SCN_Thumb_T7_PickYourCreature_3` | [MVP] | Optional soft-launch version of T7 with the three soft-launch species | 1920 × 1080 | pose set | 1.5 | not started |
| `SCN_Thumb_T7_PickYourCreature` | [L] | Six species in a shallow arc, each in its ability pose | 1920 × 1080 | launch pose set | 3.5 | not started |
| `SCN_Thumb_T8_WhaleFall` | [L] | Wide shot of the Drop-off: the skeleton sinks as a pale shape, small creatures swarm the Marrow, Old Scar and a Grouper circle | 1920 × 1080 | Whale Fall rows | 4 | not started |
| (staging) Gameplay preview capture set-ups | [MVP] | For the eight shots in document 11, section 5.2: saved game states, scripted predators and camera paths so each shot can be recorded again after any art change | 8 shots | soft-launch build | 6 | not started |
| (staging) Gameplay preview, launch re-cut | [L] | Update the set-ups for launch content | 8 shots | launch build | 3 | not started |
| `SCN_Brand_EndCard` | [MVP] | Plate for the end card of short videos: a slow orbit inside a cove, clean space for the logo | 1920 × 1080 and 1080 × 1920 | cove kit | 2 | not started |
| `SCN_Brand_Banner` | [MVP] | Wide plate for the channel banner and the community emblem crop | 2560 × 1440 | SCN_Stage_Reef | 2 | not started |
| `SCN_Event_LaunchWeek` | [L] | Plate for the launch-week event thumbnail | 1920 × 1080 | SCN_Stage_Reef | 3 | not started |
| `SCN_Event_Storm` | [P1] | Plate for the Storm event thumbnail | 1920 × 1080 | event bundle | 2 | not started |
| `SCN_Event_RedTide` | [P1] | Plate for the Red Tide event thumbnail | 1920 × 1080 | event bundle | 2 | not started |
| `SCN_Event_TrenchOpens` | [P2] | Plate for The Trench Opens event thumbnail | 1920 × 1080 | event bundle | 2 | not started |

## 14. Totals and production order

### 14.1 Pipeline tasks (not assets)

Scripts and routines that the hours in every other section rely on. Document 06 specifies several of them (export checks, shells, bakes, contact sheets); they are listed here so the totals are honest.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| (tool) Export and validate script | [MVP] | One-command export of meshes, skeletons and clips with the final names; checks triangle and bone counts, four weights per vertex, one material, one UV set, size against document 06, and the naming rules in section 1.2. Its first job is the calibration cube `M_Prop_ScaleCube` from document 06, section 6.1, which is a script output and has no row | — | — | 6 | not started |
| (tool) Shell and distance-version script | [MVP] | Makes `_Shell`, `_ShellThick`, `_LOD1` and `_LOD2` from any finished creature mesh | — | — | 5 | not started |
| (tool) UV layout and atlas tools | [MVP] | Keep the family UV layout identical across species; pack atlases; stamp placeholders | — | — | 4 | not started |
| (tool) Trait overlay bake | [MVP] | Bake a trait master pattern onto any family layout, home and fallback zones | — | family base meshes | 5 | not started |
| (tool) Clip tools | [MVP] | Copy clips between species on one family skeleton, batch export, strip sway bones from clips if code and clips cannot be layered, and the no-click clip route: clip JSON to KeyframeSequence to binary `.rbxm` (Lune) to Open Cloud Animation upload (document 06, section 6.7; the Sprint 0 converter `spike/tools/anim_kfs.py`) | — | — | 3 | not started |
| (tool) Flipbook and frame-set render | [MVP] | Render or pack an effect sequence into a 4×4 sheet; render the caustic and surface frame sets | — | — | 4 | not started |
| (tool) Placeholder generator | [MVP] | Reads this list and writes a stand-in for every row (section 16) | — | — | 5 | not started |
| (tool) Audio batch | [MVP] | Trim, level, export to OGG, check loops | — | — | 2 | not started |
| (tool) Upload and manifest routine | [MVP] | Upload a file, record its asset ID and status in `manifest.csv`, swap out the placeholder | — | — | 6 | not started |
| (tool) Review contact sheets | [MVP] | Render any set of assets, and the trait combination sheet, onto one image for an art review | — | — | 3 | not started |
| (test) Rig test and trait test | [MVP] | The two engine tests document 06 calls for before any creature is finished: outline shells and code sway on a skinned mesh, and the three ways to draw trait overlays | — | placeholder species | 8 | not started |
| (import) Studio import and fixes, soft launch | [MVP] | Import every [MVP] file, set `MeshPart.Color` to white, surfaces and collisions, check each rig's socket table, fix what breaks | — | all MVP rows | 14 | not started |
| (import) Studio import and fixes, launch | [L] | The same for [L] files | — | all L rows | 8 | not started |

### 14.2 Rows and hours by category and scope tag

Each cell is **rows / hours**. A row can cover several files (variants, takes, stems, frames, bundles); the Files column counts them.

| Category | Section | [MVP] | [L] | [P1] | [P2] | All rows | Files | All hours |
|---|---|---|---|---|---|---|---|---|
| Species (launch) | 2 | 70 / 114 | 88 / 169 | — | — | 158 | 297 | 283 |
| Species (post-launch) | 2.8 | — | — | 12 / 97 | 24 / 164 | 36 | 198 | 261 |
| Traits | 3 | 26 / 38 | 35 / 48 | — | — | 61 | 124 | 85 |
| Prey | 4 | 30 / 44 | 7 / 10 | — | — | 37 | 67 | 54 |
| Predators and hazards | 5 | 38 / 75 | 12 / 24 | — | — | 50 | 80 | 98 |
| Environment | 6 | 102 / 337 | 50 / 60 | 3 / 3 | 8 / 65 | 163 | 306 | 465 |
| Water and sky | 7 | 13 / 26 | — | — | — | 13 | 60 | 26 |
| Tide events | 8 | 6 / 10 | 7 / 24 | 3 / 42 | 1 / 12 | 17 | 17 | 88 |
| Visual effects | 9 | 100 / 62 | 32 / 20 | — | — | 132 | 132 | 82 |
| Lighting | 10 | 10 / 22 | 1 / 2 | 3 / 6 | 2 / 4 | 16 | 16 | 34 |
| Sound effects | 11 | 132 / 66 | 39 / 17 | — | 1 / 2 | 172 | 231 | 85 |
| Music | 12 | 14 / 79 | 3 / 15 | 3 / 21 | 2 / 16 | 22 | 31 | 131 |
| Store-page source art | 13 | 14 / 54 | 12 / 32 | 2 / 4 | 1 / 2 | 29 | 29 | 91 |
| Placeholders | 16 | 13 / 26 | — | — | — | 13 | 13 | 26 |
| Pipeline | 14.1 | 12 / 65 | 1 / 8 | — | — | 13 | 13 | 73 |
| **Total** | | **580 / 1,016** | **287 / 429** | **26 / 172** | **39 / 265** | **932** | **1,614** | **1,882** |

### 14.3 Hours by scope tag

First-pass hours are the sums above. The allowance adds 30% (tune) for review loops, re-exports and fixes found in the game. Weeks assume 25 art and audio hours a week from one person who is also writing the game (tune).

| Scope | Rows | First-pass hours | With 30% allowance | Weeks at 25 h/week |
|---|---|---|---|---|
| [MVP] soft launch | 580 | 1,016 | 1,320 | 53 |
| [L] added for launch | 287 | 429 | 558 | 22 |
| **[MVP] + [L] public launch** | 867 | 1,445 | 1,878 | 75 |
| [P1] first quarter after launch | 26 | 172 | 224 | 9 |
| [P2] later | 39 | 265 | 344 | 14 |
| **Everything on this list** | 932 | 1,882 | 2,447 | 98 |

### 14.4 Suggested production order

Sprints are themes, not fixed lengths. Hours are first-pass sums of the rows named; the running total shows where each build lands.

| Order | Sprint theme | Build it unlocks | What must exist | Hours | Running total |
|---|---|---|---|---|---|
| 1 | Pipeline, grey-box and one real fish | **First playable** | All tools and the rig and trait tests in 14.1 (not the import passes). Every placeholder in section 16. Finished: the `Fish` base mesh and skeleton, the Minnow juvenile with its fit, texture and outline shells, five family clips (Swim, SwimFast, Idle, Dash, Bite), the shared roughness textures; Plankton and Krill with the small-prey atlas and prey shells; `FX_BiteChomp`, the two smallest bubble pops and their two textures; three eating sounds; `LGT_Reef`. Everything else is a stand-in | 101 | 101 |
| 2 | The first two minutes | **First-two-minutes build** | Everything document 04 scripts for a new player. The rest of the `Fish` clip set, the Minnow's Dart and fidget, its distance versions, the egg. The Nursery kit, landmarks and assembly. Shared pieces, the Rim and the four ground textures. A slice of Reef: floor, rock masses, brain and staghorn coral, Noggin Rock. Kelp plants for the kelp patch. The whole [MVP] cove with its Species Wall and tide clock. Tiny Shrimp, Sardine, Glowfry and the Glow overlay for the first trait. The Barracuda for the scripted chase. All daytime water and sky rows and the phone test. Effects for tier-ups 2 and 3, dash, bubbles, gulp pop, hatch, bank, cove membrane and beacon, home trail, Pearls, currents, light shafts, the first trait. Presets for Nursery, Cove, Surface and Gulped. About 45 sounds, including the Minnow voice and the interface sounds the first session calls. `MUS_Nursery`, `MUS_Chase`, `MUS_Current`, `MUS_Cove`, `MUS_Reef` and both stingers | 289 | 390 |
| 3 | Creatures, prey and traits for soft launch | — | Minnow adult and crest; Pufferfish and Eel complete, with the `Eel` skeleton and clip set; the remaining prey; the other eight soft-launch trait prey; the eight remaining soft-launch traits on `Fish` and `Eel`; kit pieces, placement and the combination sheet | 147 | 537 |
| 4 | The soft-launch world | — | The rest of the Reef and its landmarks; the Kelp Forest; the whole Drop-off with the Tin Pickle, the cold Chimneys and the Crack; eel holes; night sky; remaining presets and low-end variants | 212 | 749 |
| 5 | Danger, events and effects | — | Gull, Moray, Old Scar, jelly bloom, hooks; Moon Tide glow masks, night tints and test; the rest of the [MVP] effects | 105 | 854 |
| 6 | Sound, music, store page, import | **Soft launch** | Remaining [MVP] sounds and music including the theme; icons A and D and thumbnails T1 to T6, all in their soft-launch versions, the pose set and the capture set-ups; the soft-launch import pass | 162 | 1,016 |
| 7 | Launch creatures and traits | — | Sea Turtle and Squid with their two skeletons and clip sets; Shark Pup; 18 patterns; Spark, Camo, Ember and Bonefed on all four families; the soft-launch overlays on `Turtle` and `Squid`; launch trait prey | 227 | 1,243 |
| 8 | Launch world and events | — | Grouper, anemones, lit vents; the Whale Fall skeleton; cove Bubble jar and count; 46 decorations; the Drop-off launch pass; Whale Fall preset | 110 | 1,353 |
| 9 | Launch effects, sound and music | — | All [L] effects and sounds, `MUS_Event_WhaleFall`, `MUS_Tier7` | 52 | 1,405 |
| 10 | Store page and launch import | **Public launch** | Icons B, C and E, thumbnails T7 and T8, the public-launch versions of icon A and of thumbnails T3, T4 and T5, the launch pose set, the launch-week plate, the preview re-cut; the launch import pass | 40 | 1,445 |

The first playable needs about 101 first-pass hours and the first-two-minutes build about 289 more. Those two builds decide whether the game is fun, and together they use roughly 38% of the [MVP] art and audio hours. Do not start sprint 3 until the first-two-minutes build has been played by new players.

### 14.5 Biggest cost drivers (launch scope)

| Driver | First-pass hours | Share of launch | Note |
|---|---|---|---|
| Environment kits, landmarks, coves and assembly | 397 | 27% | Landmarks are 102 of it, decorations 54, assembly 52 |
| Six playable species | 283 | 20% | Meshes and textures dominate; clips are only 72 because swimming is code and families share clip sets |
| Sound and music | 178 | 12% | Music composed from scratch is 94 of it |
| Pipeline, tests, import and placeholders | 98 | 7% | Not assets, but every other number relies on them |
| Predators and hazards | 98 | 7% | Old Scar alone is 23 |
| Trait visuals | 85 | 6% | 13 traits across 4 families; grows with each new family, not each new species |
| Store-page scenes | 85 | 6% | Plates only; the paint-over and the video edit are in document 11 |
| Visual effects | 82 | 6% | 106 effects, most of them settings over shared textures |

## 15. Reuse plan

The hours in this list already assume the reuse below. If a reuse turns out not to work, the saving in the last column comes back as extra hours.

| What is shared | What it serves | How | Hours saved (estimate) |
|---|---|---|---|
| Four family skeletons | All six launch species; later Anglerfish, Axolotl, Orca Calf, Narwhal | Same bone names and sockets; each species only fits the skeleton to its body | 30 |
| Family clip sets (14 clips each) | Every species in the family, juvenile and adult | Minnow, Pufferfish and Shark Pup share one set of 14 instead of 42 clips | 30 at launch |
| Code-driven swimming and turning | Every player creature, predator and large prey | No swim variants per speed, no turn clips, no prey clips | 60 |
| Code-driven eyes and lids | Every creature | No eye textures or face clips | 15 |
| Standard UV layout per family | Base textures, patterns and trait overlays | One overlay per trait per family fits every species in it, juvenile and adult | 60 at launch, more with each new species |
| Trait master patterns | 11 overlay traits across 4 families | One scripted Blender pattern per trait, baked onto each family layout | 40 |
| Socketed kit pieces | Five piece traits on every species | Eleven small meshes serve all species; only a placement table differs | 60 |
| Script-made shells and distance versions | Every creature | Made from the finished mesh, checked by eye | 40 |
| Stunned clip | Slowed, burning, hooked, pulled by a Grouper | One loop for five states; the effect tells them apart | 12 |
| Rigid prey with a motion table | Plankton, Krill, Tiny Shrimp, Sardine, five trait prey | No bones, no clips | 12 |
| Prey meshes | Zebra Darter from Reef Darter; Armor Shrimp from Tiny Shrimp; Lunar Fry from Glowfry | Edit, do not rebuild | 3 |
| Six prey atlases | All 21 prey | Small cells in shared sheets, so schools batch | 8, plus frame rate |
| Four tiling ground textures | Every floor, rock, cliff and Rim piece in every zone | Tints make silt, sandstone and deep slate | 30 |
| Kit pieces at 80% to 125% with tints | Every zone | A dozen corals dress the whole Reef; night is a tint, not new meshes | 50 |
| Vent chimneys | The Chimneys landmark at soft launch, the vent hazard at launch | Same meshes; launch adds a glow mask, a plume and a rumble warning | 6 |
| One cove | All 24 coves | Same pieces; the lantern colour and the owner's specimens make them differ | 100 or more |
| `M_Prop_BubbleShell` | Protection bubble, Trophy Bubble, Bubble count, Bubbles | One mesh | 3 |
| `M_Prop_HatchEgg` | Nursery Hatch Bed and every cove's Home Stone | One egg | 1 |
| Effect textures | All effects | An effect is settings plus shared textures; most effects add no texture | 40 |
| Tier-up effect | Tiers 2 to 7 | One effect with six settings files | 4 |
| `FX_Metamorph` | Tier 4 form change, Puff, Shell | One cover-up cloud for every mesh swap | 2 |
| Light-shaft texture | Sun shafts, moon shafts, moonbeams, cove beacon, Whale Fall beam, event banners | One streak, tinted | 3 |
| Soft-puff flipbook | Ink cloud, Squid ink puff, Inklet puff, Metamorph, anemone wisps | One sheet | 5 |
| Bite, dash and voice sounds | All seven tiers | Pitch lowered by tier in the engine; bites also step up a semitone in a streak | 30 |
| Main tune | Theme, Cove, Reef, Feeding Frenzy, Tier 7 | One melody arranged five ways | 12 |
| `MUS_Danger` | All zones | One layer over any zone track because tempo is shared | 15 |
| `SCN_Stage_Reef` and the pose sets | Icons, thumbnails, flat marketing art | One lit stage, one set of poses | 20 |

## 16. Placeholder plan

Code is never blocked by art. On day one a script fills `assets/placeholder/` with a stand-in for **every row in this list**, using the final asset name. The game loads assets by name through the manifest, so finishing an asset means replacing a file and flipping one manifest flag; no code changes.

Rules for stand-ins:

- They have the final name, the final size in studs (document 06, section 6.2), the final bone and socket names, and clips of the final length. Timing, hit areas and socket placement can then be tuned before the art exists.
- They are plain and obviously unfinished (flat colours, a "PH" stamp on textures) so none can ship by accident. The manifest lists which names are still placeholders, and a release check fails if any [MVP] row is one.
- They are our own files. No stand-in is a default Roblox part, texture, sound or avatar, so the "no default art" rule holds from the first build.

| Asset | Tag | Description | Size / budget (tune) | Depends on | Hours (tune) | Status |
|---|---|---|---|---|---|---|
| (placeholder) Playable species | [MVP] | Capsule body, cone tail, two sphere eyes with lid caps, flat species colour, on the real family skeleton with all sockets. Juvenile and adult differ in length; puffed and tucked versions are a sphere and a dome. Shells and distance versions are made by the real script. Clips are procedural moves of the right length: stretch for dash, jaw flap for bite, spin for tier-up, shrink for gulped | 6 species, 4 skeletons, 90 clips | export script | 5 | not started |
| (placeholder) Patterns | [MVP] | Base texture tinted a different flat colour per pattern | 18 patterns | — | 0.5 | not started |
| (placeholder) Traits | [MVP] | Overlays: a flat tint in the trait colour over the home zone, with the trait name in big letters. Pieces: cones for spines, boxes for plates, strips for ribbons and leaves, octahedra for shards, on the real sockets | 44 overlay sets, 11 pieces | placeholder species | 2 | not started |
| (placeholder) Prey and trait prey | [MVP] | Low-poly ellipsoids sized by tier in one flat colour per prey; trait prey carry a ring. Shells by the real script | 21 prey | — | 1 | not started |
| (placeholder) Predators and hazards | [MVP] | Red-toned primitives: wedge for Barracuda and Old Scar, tube for Moray, sphere with a hinged lid for Grouper, cross for Gull, sphere for jelly, cone for chimney, ring for anemone, torus for hook. Action clips of the final length | 5 predators, 5 hazards | — | 3 | not started |
| (placeholder) Environment | [MVP] | Grey block-out pieces at final footprint and height: slabs for floor chunks, boxes and wedges for rocks, cliffs and the Rim, tubes for eel holes, poles for kelp. Each landmark is a block of its real size in a unique colour with its key letter on it. Each zone gets one tint | 206 pieces | — | 5 | not started |
| (placeholder) Cove and decorations | [MVP] | Block-out mouth and chamber with the 40 perches and 29 decoration spots marked; fixtures are labelled boxes; each decoration is a box of its size class | cove kit, 46 decorations | — | 2 | not started |
| (placeholder) Water and sky | [MVP] | Flat semi-clear sheet with one ripple frame, flat two-colour skybox, plain discs for sun and moon. No caustics | — | — | 1 | not started |
| (placeholder) Effects | [MVP] | One white soft dot texture for everything. Each effect is a short burst with the final name, size and duration, tinted by type: green eat, gold Pearl, red danger, blue water | 106 effects | — | 2 | not started |
| (placeholder) Lighting | [MVP] | One neutral preset copied under every preset name with only the fog colour and distance from document 06 changed | 10 presets | — | 0.5 | not started |
| (placeholder) Sound effects | [MVP] | Script-made tones: a short beep per sound at the final length, pitched by group (eat high, danger low, interface mid). Loops are soft noise | 230 files | audio batch script | 2 | not started |
| (placeholder) Music | [MVP] | One eight-bar mallet loop at the shared tempo, pitched differently per track name, cut into the right number of stems; stingers are three notes | 25 files | — | 1.5 | not started |
| (placeholder) Store page | [MVP] | None needed: the soft launch uses the real [MVP] icons and thumbnails | — | — | 0 | not started |

## 17. Open points and proposals

The canon (document 01) was updated after this list was first written, and this list now follows it. The proposals the canon adopted are closed and are no longer listed here: the whale is a skeleton, the Shark Pup ability is Rampage, the `Trait` mesh category, the `RIG_`, `LGT_`, `SKY_` and `SCN_` prefixes and the mesh suffixes are in canon section 16, the built-in `Neon` material is allowed for outline shells, and the passive abilities show a badge instead of a button.

What is left is still open. **Nothing in section 17.1 has been applied**: the rows and the totals in section 14 are the full scope.

### 17.1 Proposals: the launch scope is large for one person

Launch scope ([MVP] + [L]) is about **1,445 first-pass hours, or 1,878 with the 30% allowance: roughly 75 weeks at 25 hours a week** of art and audio alone, before any code. Soft launch alone is about 1,320 hours with allowance (53 weeks). Options that cut launch hours, with first-pass hours saved:

| Proposal | Hours saved | Effect on the game |
|---|---|---|
| Move the Squid from [L] to [P1] (launch with five species) | 76 | The Squid is the only member of its family, so it alone carries a skeleton, 14 clips and 11 trait overlays. It becomes the first content update. The Sea Turtle costs 76 for the same reason and is the next candidate |
| Launch with 20 decorations instead of 46 | 32 | A smaller shop and fewer reward decorations on day one; the rest arrive in updates. Document 05 would have to re-spread its Pearl prices |
| Make a third fewer variants of every environment kit piece | 38 | More visible repetition; variants can be added in updates |
| License half the music instead of composing it | 47 | Zone tracks lose the shared tune; keep the theme, Nursery, Cove and the stingers original |
| Launch with one pattern per species instead of three | 24 | Each species keeps one pattern. Document 05 (section 8.5) sells eleven for Robux and gives six through the Codex, so most of those would wait for an update |
| **All of the above** | **217** | Launch drops to about 1,227 first-pass hours (15% less) |

The scope stays large after these cuts because most of the cost is the base game: four zones built from meshes, six creatures in four families, and 13 traits.

Soft launch is harder to cut because it is mostly world and core creatures. Three moves from [MVP] to [L] that shorten the road to soft launch without changing the launch total:

| Proposal | Hours moved out of soft launch | Effect on the soft launch |
|---|---|---|
| Move the Eel, the `Eel` family rows and the eel holes from [MVP] to [L] | 57 | Soft launch has two species, both in the `Fish` family. The day-2 unlock goal in canon section 7 cannot be measured until launch |
| Move the Tin Pickle wreck from [MVP] to [L], when the Spark Eels that live in it arrive | 23 | Documents 03 and 06 both want it at soft launch as a Drop-off landmark and a Moon Tide site; the rock shelf stays as a bare ledge |
| Keep seven landmarks at soft launch (Little Arch, Noggin Rock, The Hoop, Old Anchor, Peekaboo Ridge, Ink Pots, The Crack) and move the rest to [L] | 48 | Zones are harder to navigate by sight; some trait prey sites become plain kit pieces for a while |

Document 13 (the sprint plan) makes its own, deeper cut for the soft launch. It starts from the [MVP] hours in section 14.

### 17.2 Where other documents still differ from this list

| Subject | The difference | This list follows |
|---|---|---|
| Leviathan crest shape | Document 02 (section 1.8) says documents 03 and 07 own the crest's shape per species. Document 06, section 3.6 now defines one shape per body family | Document 06; the six `M_Species_<Species>_Crest` rows quote it |
| Where a new Fry appears | Document 04: a hatch pool at the centre of the cove. Document 03: the Home Stone | Document 03; the egg sits on the Home Stone |
| Tide clock and tide board | Documents 03 and 04 put a free shell tide clock on every cove wall from the first session. Document 03 also has a brass Tide Clock decoration at Reef Rank 31, a second face for it. Canon section 12 sells a tide board (the next three tides and a marker to the event) with Tide Watcher | `M_Cove_TideClock` [MVP] and `M_Prop_Deco_RankTideClock` [L] both show only the next tide, which every player sees for free. The Tide Watcher board and marker are interface (document 08, the tide popover), so this list has no 3D asset for them |
| Tide warning sound | Document 03: a bell, `SFX_TideBell`. Document 04: `SFX_TideHorn`. Document 08: `SFX_UI_EventWarn` | A world bell `SFX_TideBell` for the warning, a start horn per event `SFX_TideHorn_<Event>`, and the interface sounds from document 08 |
| Emote sounds | Document 03 gives each of six emotes its own sound. Document 08 calls one `SFX_UI_Emote` | One name with six takes |
| Chase music | Document 04 names `MUS_Chase` and `MUS_Current`. The audio plan here also has a `MUS_Danger` layer | All three are listed. If the chase track can serve as the danger layer, `MUS_Danger` is dropped |

### 17.3 Names other documents must change to match section 1.2

Section 1.2 is the final naming rule. Effect and sound names that other documents already use (`FX_BiteChomp`, `FX_InkCloud`, `SFX_TideBell`, `SFX_BarracudaSnap`, every `SFX_UI_…` name) fit the rule and did not change. These names in other documents are older or shorter forms of names in this list:

| Name elsewhere | Document | Name in this list |
|---|---|---|
| `FX_TierUp`, `FX_TierUp_Burst` | 04, 02 | `FX_TierUp_T2` to `FX_TierUp_T7` |
| `FX_BubblePop` (and its large version) | 02 | `FX_BubblePop_T0` to `FX_BubblePop_T5T6` by prey tier; the large version is `FX_GulpPop` |
| `SFX_TierUp`, `SFX_TierUp_Start` | 04, 02 | `SFX_TierUp_T2` to `SFX_TierUp_T7`, with `SFX_UI_TierUp` layered on top |
| `SFX_TraitPip`, `SFX_TraitGained` | 04 | `SFX_UI_TraitPip`, `SFX_UI_TraitGain` |
| `SFX_Dash` | 04 | `SFX_Dash_Small`, `SFX_Dash_Large` |
| `SFX_PearlCount` | 04 | `SFX_UI_PearlTick`, ending in `SFX_UI_PearlBurst` |
| `SFX_GoalDone` | 04 | `SFX_UI_GoalDone` |
| `SFX_TideHorn` | 04 | `SFX_TideBell` (warning) and `SFX_TideHorn_<Event>` (start) |
| `A_Minnow_Hatch` | 04 | `A_Fish_Hatch` (the family clip) |
| `Juvenile`, `Adult` mesh parts | 09 | No change needed: these are instance names inside the rig Model, not asset names. The files they hold are `M_Species_<Species>_Juv` and `_Adult` |
| `M_Prop_Trait<Trait>_<Piece>`, `T_Trait<Trait>_<Family>_<Map>`, `T_TraitPieces_Alb` | 13 | `M_Trait_<Trait>_<Piece>`, `T_Trait_<Trait>_<Family>_<Map>`, `T_Trait_Pieces_Alb` (canon section 16) |
| The Shark Pup ability clip under the old ability name | 13 | `A_Shark_RampageStart` |
| `M_Species_Angler_*`, `T_Angler_*`, `A_Angler_*` | 13 | `M_Species_Anglerfish_*`, `T_Anglerfish_*`, `A_Anglerfish_*` |
| `M_Cove_Interior_Shell` | 13 | `M_Cove_Interior` (a name that ends in `_Shell` is an outline shell) |
| `M_Env_DropOff_LM_PickleShelf` | 13 | `M_Env_DropOff_LM_TinPickle_Shelf` |
| `T_Sky_Moon` | 13 | `T_Sky_Moon_Alb` |
| `SCN_Icon_E_Wordmark` | 11 | `SCN_Icon_E_MouthMark` (icon E has no text; document 11, section 3.3) |

One more point for other documents:

1. **Document 13 quotes row names and hours from this list.** It needs the renames above; none of the effect or sound names it uses changed. In the first consistency pass the [MVP] total moved by −0.2 hours (`SFX_UI_Focus` is now [L]). The second pass added `M_Cove_SpeciesWall` (+1 hour, [MVP]) and `FX_VentRumble` and `SFX_VentRumble` (+0.7 hours, [L]), and renamed the four daily-goal decorations from `M_Prop_Deco_Streak…` to `M_Prop_Deco_Goals…`. The third pass gave icon A and thumbnails T3, T4 and T5 one row per version: four public-launch rows were added (`SCN_Icon_A_BehindYou_Launch`, `SCN_Thumb_T3_GetHome_Launch`, `SCN_Thumb_T4_SevenSizes`, `SCN_Thumb_T5_YourCove_Launch`; +6.5 hours, [L]), the soft-launch T4 is now `SCN_Thumb_T4_FiveSizes` (same 3 hours, [MVP]) and `SCN_Icon_E_Wordmark` is now `SCN_Icon_E_MouthMark`. The [MVP] total did not move.

### 17.4 Tags and counts chosen here

- **`MUS_Tier7` is [L]** although tier 7 can be reached at soft launch. Few soft-launch players will reach it; the zone track plays instead.
- **The Crack and the Coldline stay [MVP]** although the Trench behind them is [P2]. Document 03 makes them sealed Drop-off scenery from soft launch. Moving them to [P2] would save about 5 hours and leave a plain Deep Floor there.
- **`SFX_UI_Focus` is [L]** because gamepad support is [L] (canon section 15). No asset on this list is needed by consoles alone, so nothing is tagged [P1] for them.
- **Wild creatures [L] add one check row and no art** (section 2.0). They are the playable species with a name tag from document 08.
- **Passive abilities have no button asset.** Dart, Slip and Rampage are passive (canon section 7) and show a badge from document 08. `SFX_UI_Ability` is for Puff, Shell and Jet only.
- **Manta Ray and Seahorse each need a new body family** (wings, upright body). Their rows are sized for a new skeleton, 14 clips and 11 overlays. If document 06 fits them into an existing family, each drops by about 30 hours.
- **Abilities for Seahorse, Orca Calf and Narwhal** are sized as "one ability" pending document 03.
- **Great Migration has no thumbnail plate row yet.** Storm, Red Tide and The Trench Opens have one each; its plate is added when the event is scheduled.
- **"Bubble" has two meanings in art terms:** the like left on a cove, and ordinary bubbles in effects. The like always uses `M_Prop_BubbleShell` so it reads as an object.

### 17.5 Engine tests that change this list

Document 06 marks these as unverified. Row "(test) Rig test and trait test" in 14.1 and the test rows in sections 7 and 8 cover them.

| Test | If it fails |
|---|---|
| Flipped back faces draw on a skinned mesh, so outline shells work | Outlines become a ring sprite behind each creature. All `_Shell` and `_ShellThick` rows are dropped (about −25 hours) and one ring texture is added |
| Code can move sway bones while a clip plays on the same skeleton (passed on Mac in Sprint 0, writing on `PreRender`) | Sway bones are left out of every clip; the reference swim clips become unused. No extra hours |
| Decal layers follow the UVs of a skinned mesh under a painted surface (**failed** in Sprint 0: decals project per face; the overlay shell was chosen, so this row's cost applies and is not yet in the rows above) | Overlays move to a second shell mesh per creature (about +1 hour per species mesh and double the triangles while a trait shows) or are combined into one texture at run time |
| Part of a texture can glow from a mask on every target device | Glow traits, Moon Tide masks and eye rings use small `Neon` caps and brighter paint instead; a few more kit pieces, similar hours |
| Sway code is fast enough for the creatures in view on a low-end phone | Fewer creatures sway; the rest use the reference swim clips |
| Eight swapped surface frames and sixteen caustic frames hold frame rate and memory | Fewer frames, or two scrolling layers instead |
| Image size cap and audio upload quota (sections 1.4 and 12) | Texture sizes drop, or the audio upload calendar stretches |
