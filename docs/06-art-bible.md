# 06 · Art bible

This document defines how GULP looks and moves. It expands section 13 of `01-game-canon.md`. Names, IDs and scope tags come from the canon. Document 07 lists every asset; this document says what each asset must look like and what it may cost.

Numbers marked **(tune)** are starting values. Engine facts carry one of three marks:

| Mark | Meaning |
|---|---|
| **[V]** | Read on an official Roblox documentation page on 13 October 2026. The link is given. |
| **[F]** | Found only on the developer forum or a secondary site. Treat as a lead. |
| **[U]** | Not verified. Must be tested in Studio before art depends on it. Section 18 lists the tests. |

---

## 1. The style

GULP is a bright toy-box sea. Every creature is a chunky, rounded toy with a big head, big eyes and a mouth that opens far too wide. Every surface is hand-painted in flat, clean colour with soft gradients, as if a toy maker painted it with three pots of paint and one small brush for the accent. The water is thick, coloured and friendly near the reef and turns deep and heavy at the Drop-off, so the player always knows where they are from colour alone. Motion is snappy: creatures hold a strong pose, then pop to the next one with squash and stretch. Nothing on screen looks like a Roblox part, a Roblox material, a Roblox avatar or a Roblox menu.

### Five rules that settle arguments

When two rules disagree, the lower number wins.

1. **Silhouette first.** If an asset is not recognisable as a solid black shape at 48 pixels tall, it is rejected. Detail never rescues a weak shape.
2. **Three values and one accent.** Every creature and prop is built from one light, one mid and one dark value, plus at most one small accent colour. No fourth value block.
3. **Painted, not simulated.** Light, form, wetness and wear are painted into the colour texture. No photographic textures, no normal maps, no metal, no realistic shading.
4. **Signal colours belong to gameplay.** The "can eat", "can eat you" and "home" colours (section 4.5) never appear in art for any other reason.
5. **The phone decides.** An asset is judged on a phone-sized frame (844 × 390 points) at the lowest graphics quality. If it needs shadows, bloom, depth of field, sun rays or flipbooks to read, it is rejected, because Roblox removes those on weak devices (section 10.5).

---

## 2. Reference board

Inspiration only. We copy no character, design or name. Each reference lends exactly one quality.

### 2.1 What we borrow

| # | Reference | Link (found and opened unless noted) | The one quality we take | What we do not take |
|---|---|---|---|---|
| 1 | **Slime Rancher** (Monomi Park) | [slimerancher.com](https://www.slimerancher.com/) (official; its footer links the [press kit](https://monomipark.com/press-slime-rancher-2), which I did not open) | **Appeal from one simple body shape plus a big face.** A creature is a ball with eyes and a mouth, and that is enough. | The see-through jelly look (needs a custom shader we do not have), the pastel desert palette |
| 2 | **Kirby and the Forgotten Land** (HAL Laboratory, Nintendo) | [Ask the Developer interview, 24 March 2022](https://www.nintendo.com/sg/interview/arzg/index.html) | **A round hero whose silhouette changes when it eats.** The director also says a round body is "hard to tell which direction he's facing at a glance" from behind in 3D. We take that warning: every GULP creature has a tail and a dorsal fin that show its heading. | The character, the ruined-city setting, platformer staging |
| 3 | **Abzû** (Giant Squid) | [GDC 2017 talk "Creating the Art of ABZU"](https://www.gdcvault.com/play/1024409/Creating-the-Art-of-ABZ); [80 Level interview with Matt Nava, 9 December 2016](https://80.lv/articles/interview-with-the-creative-director-of-abzu/) | **Underwater colour and murk.** Nava: "even simply adjusting the distance you can see into the murk can have a huge effect on the player's emotional state." Each zone gets its own fog colour and view distance. | The calm, meditative mood, real-world species proportions, the muted temple palette |
| 4 | **Sea of Thieves** (Rare) | [80 Level note on Ryan Stevenson's GDC 2018 talk](https://80.lv/articles/gdc18-visual-adventures-on-sea-of-thieves/); [Game Developer video page](https://gamedeveloper.com/art/video-how-rare-crafted-the-look-and-feel-of-i-sea-of-thieves-i-) | **A few simple rules applied to everything.** The talk's thesis is that "a few simple rules can permeate through all aspects of a game's visuals". Section 1 is our version. Also the chunky, hand-painted props. | The simulated ocean, the realistic lighting, the human pirates |
| 5 | **Fall Guys** (Mediatonic) | [PlayStation Blog, "Creating the Character Designs of Fall Guys", May 2020](https://blog.playstation.com/?p=224711) | **Vinyl-toy proportions and the half-cover test.** The team simplified costumes so they read small, and checked by hiding half the character. We use that test (section 3.4). | The bean humanoid, the glossy plastic surface, costume-as-identity |
| 6 | **Luca** (Pixar) | [SlashFilm interview with animation supervisor Mike Venturini, 28 April 2021](https://www.slashfilm.com/580760/luca-inspiration-mike-venturini-interview/) | **Hold a strong pose, move only when it matters.** The team studied animators who "find really wonderfully drawn poses and spend a lot of time in the pose" and use "very simple" mouth shapes. | Film-quality rendering, the human cast, the sea-monster designs |
| 7 | **Dota 2 Workshop Character Art Guide** (Valve) | [Steam Support page](https://help.steampowered.com/faqs/view/0688-7692-4D5A-1935) (the page title loaded; my tool could not read the body, so the rules below come from search summaries of the guide) | **Readability from a far camera:** a clear silhouette that also shows heading, a value gradient that pulls the eye to the head, and large areas of rest. | The gritty fantasy detail, the dark palette |
| 8 | **Subnautica** (Unknown Worlds) | [Concept art post: Kelp Forest, 29 December 2013](https://unknownworlds.com/news/subnautica-concept-art-kelp-forest) | **One colour identity per biome.** The posts describe each biome by its colour ("From red, to green"). A GULP player names the zone from a screenshot with the interface hidden. | Realism, dread, alien anatomy |
| 9 | **Hungry Shark World** (Ubisoft) | [Ubisoft product page](https://www.ubisoft.com/en-us/games/hungry-shark-world) | **Genre baseline: bright prey against blue water.** Food is always the warmest, lightest thing on screen. | Blood and gore, eating people, the side-on camera, the mean tone |
| 10 | **Octonauts** (Meomi) | [octonauts.com](https://www.octonauts.com/) (official) | **Real sea animals reduced to toy shapes that are still the right animal.** A child can name the species. | The characters, the flat 2D look, the preschool tone |

### 2.2 Published breakdowns and talks

| Topic | Source | Use |
|---|---|---|
| Stylised underwater rendering | [Creating the Art of ABZU, GDC 2017](https://www.gdcvault.com/play/1024409/Creating-the-Art-of-ABZ). The description covers "animating vast amounts of fish, simulating huge dynamic kelp forests, and modeling undersea lighting and atmospherics". | Fog, schools and kelp. Abzû animated most fish in the material instead of with bones; Roblox cannot do that, so our small prey are rigid (section 7.6). |
| Stylised water | [The Technical Art of Sea of Thieves, SIGGRAPH 2018 talk (PDF)](https://history.siggraph.org/wp-content/uploads/2022/09/2018-Talks-Ang_The-Technical-Art-of-Sea-of-Thieves.pdf). The file downloaded; I could not extract its text, so I cite it by title only. | Background reading for the surface. We do not simulate water. |
| Hand-painted texturing from baked maps | [Marie Lazar, "Viking Shield: Creating Stylized Textures Using Baked Maps", Sketchfab blog, 11 May 2016](https://sketchfab.com/blogs/community/viking-shield-creating-stylized-textures-using-baked-maps) | Our texture method in section 5.2: greyscale first, ambient occlusion multiplied in, cooler shadows and warmer lights, painted edge highlights last. |
| Stylised textures in Blender | [Blender Artists tutorial, "Create stylized textures in Blender"](https://blenderartists.org/t/tutorial-create-stylized-textures-in-blender/673948) (found by search, not opened) | Baking a greyscale base in Cycles. |
| Readable characters | Valve guide, row 7 above | Value gradient and rest areas. |

### 2.3 Proof that Roblox can look unlike Roblox

| Game | Link | What it proves |
|---|---|---|
| **Frontlines** (MAXIMILLIAN) | [Pocket Tactics, updated 3 March 2023](https://www.pockettactics.com/roblox/frontlines): it "looks so incredible that we'd forgive you for mistaking it as an official CoD title" | Lighting, custom models and a custom interface can hide the engine completely. (Its look is realistic; ours is not.) |
| **Creatures of Sonaria** (Sonar Studios) | [Roblox game page](https://www.roblox.com/games/5233782396/Creatures-of-Sonaria): "Play as a variety of creatures" | A hit game where the player is a custom creature that grows from young to adult, not an avatar. |
| **Beyond the Dark** (Roblox's own showcase) | [Creator Hub overview](https://create.roblox.com/docs/resources/beyond-the-dark) | An official, editable example of skinned custom creatures, modular kits and a custom interface, with documentation of how it was built. |

### 2.4 Engine limits the art is designed to

| Fact | Mark | Source |
|---|---|---|
| A mesh may not exceed 20,000 triangles. | [V] | [General specifications](https://create.roblox.com/docs/art/modeling/specifications) |
| A vertex may be influenced by at most 4 bones. The root bone carries no weights. Bones must be frozen (scale 1, rotation 0). | [V] | Same page |
| Geometry must be watertight and may not have zero thickness. | [V] | Same page |
| One animation track per exported file. | [V] | Same page |
| A maximum bone count per mesh. | [U] | Not stated on the specifications, rigging or Bone pages. |
| A mesh has one material and one UV set; UVs sit in 0 to 1; overlapping UVs are allowed. | [V] | [Texture specifications](https://create.roblox.com/docs/art/modeling/texture-specifications) |
| Texture size. The page says "up to 4096×4096" and, further down, "up to 1024×1024 pixel spaces for texture maps". The two lines conflict. We never exceed 1024. | [V], conflicting | Same page |
| Suggested sizes: 256 for a 5 × 5 stud object, 512 for 10 × 10, 1024 for 20 × 20 (about 51 pixels per stud). | [V] | Same page |
| Texture files: .png, .jpg, .tga, .bmp. | [V] | Same page |
| SurfaceAppearance maps: colour, normal (OpenGL tangent space only), roughness, metalness, emissive mask. | [V] | [PBR textures](https://create.roblox.com/docs/art/modeling/surface-appearance) |
| SurfaceAppearance maps cannot be changed by script while the game runs; `SurfaceAppearance.Color` can, and tinting costs nothing. `AlphaMode = TintMask` tints only where the alpha is visible. | [V]; measured in Sprint 0: game scripts, server or client, can write only `Color`, `AlphaMode` and the emissive strength and tint; every map needs Plugin capability (spike S0-A4, F17). So each map variant ships as a pre-made `SurfaceAppearance` that the game clones. | Same page |
| Importer accepts .fbx, .gltf and .obj; default scale unit is studs; it has an "Ignore Vertex Colors" switch, so vertex colours are imported by default. | [V] | [3D Importer](https://create.roblox.com/docs/art/modeling/3d-importer) |
| The FBX importer drops every bone with no vertex weight of about 0.02 or more (0.01 and below are dropped), and turns a mesh parented to such a bone into a `Motor6D` on the root part. It leaves `MeshPart.Color` at 163, 162, 165, which darkens the faces. | Measured in Sprint 0 (spike S0-A2, F13, F14, F23) | Sections 6.7 and 8.4 |
| Vertex colour multiplies the part colour. Whether it still multiplies under a SurfaceAppearance. | [F]; under a SurfaceAppearance it does **not** show, measured in Mac Studio (spike S0-A3, F16). So any mesh with a SurfaceAppearance carries its base colours in the colour map (section 5.3). | [Forum tutorial](https://devforum.roblox.com/t/3050119) |
| `Bone.Transform` is a CFrame that scripts may write. It carries position and rotation, not scale. The Animator resets every bone each frame, keyed or not, so a script write survives only on `RunService.PreRender`; a `PreAnimation` write is lost. | [V]; the reset measured in Sprint 0 (spike S0-A2, F15) | [Bone reference](https://create.roblox.com/docs/reference/engine/classes/Bone.md) |
| Lighting: `LightingStyle` (Realistic or Soft) and `PrioritizeLightingQuality`. Shadows are switched off below graphics quality level 4. | [V] | [Lighting guide](https://create.roblox.com/docs/environment/lighting), [performance guide](https://create.roblox.com/docs/performance-optimization/improve) |
| `Lighting.Technology` is being retired for `LightingStyle` plus `PrioritizeLightingQuality`. Staff mapping of the old names: Future = Realistic + prioritise on; ShadowMap = Soft + prioritise on; Voxel = Soft + prioritise off. So the pair in section 10.1 is the old Future, the most expensive of the three. How each renders and what it costs on phones is not documented. Measured in Sprint 0: `Lighting.Technology` cannot even be read by scripts, and `LightingStyle` and `PrioritizeLightingQuality` are writable from Edit (plugin) code, so both are set in the project file or the build step (spike S0-A5, F22). | [V] staff post, January 2025; cost [U]; script access measured | [Unified lighting](https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512); chapter 15, fact PF26 |
| Fog properties are hidden when Lighting contains an Atmosphere. | [V] | [Atmosphere reference](https://create.roblox.com/docs/reference/engine/classes/Atmosphere.md) |
| Numeric ranges and defaults for Atmosphere, Bloom, Depth of Field and Colour Correction. | [U] | The pages give types and descriptions only. |
| Depth of field "may render differently on low-end devices"; sun rays "may not render on low-end devices". | [V] | [DepthOfFieldEffect](https://create.roblox.com/docs/reference/engine/classes/DepthOfFieldEffect.md), [SunRaysEffect](https://create.roblox.com/docs/reference/engine/classes/SunRaysEffect.md) |
| A particle emitter makes at most 400 particles a second, 100 on mobile; lifetime at most 20 seconds. | [V] | [Particle emitters](https://create.roblox.com/docs/effects/particle-emitters) |
| Flipbooks: 2×2, 4×4, 8×8 or custom grid; at most 30 frames a second; texture size an exact multiple of the grid; leave spacing between frames; switched off automatically on low-memory phones. | [V] | Same page and [ParticleEmitter reference](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter.md) |
| At most 255 Highlight instances; outline thickness is not adjustable. | [V] | [Highlight reference](https://create.roblox.com/docs/reference/engine/classes/Highlight.md) |
| Highlight outlines may not draw on phones. | [F] | [Forum thread](https://devforum.roblox.com/t/highlights-wont-show-on-mobile/2850334) |
| Identical meshes with identical textures batch into one draw call. Particles "don't batch well". A 1024 texture uses four times the memory of a 512. | [V] | [Performance guide](https://create.roblox.com/docs/performance-optimization/improve) |
| Skinned meshes in a model with no Humanoid sit in clusters that are rebuilt as they move; size changes also force rebuilds. | [V] | Same page. See section 14.3. |
| Terrain is made of 4-stud voxels; terrain water has five style properties. | [V] | [Terrain](https://create.roblox.com/docs/parts/terrain) |
| Custom shaders. | [U] | No official page found. We assume none. |
| Triangle, draw-call or memory budgets for phones. | [U] | Roblox publishes none on the pages read. Sections 6.3 and 14 (art) and chapter 15, section 3.0 (per device) are our own. |

---

## 3. Shape language

### 3.1 The four body families

Every creature belongs to one family. A family shares a skeleton layout, a UV layout (section 5.4) and a swim cycle (section 7.3).

| Family | Core shape | Playable species | Other creatures |
|---|---|---|---|
| **Fish** | Teardrop | `minnow` [MVP], `puffer` [MVP], `shark` [L] | All eight prey, most trait prey, `barracuda`, `grouper`, `old_scar` |
| **Eel** | Ribbon | `eel` [MVP] | `moray`, `spark_eel`, `ribbonfish` |
| **Turtle** | Dome on a disc | `turtle` [L] | — |
| **Squid** | Bullet with a tassel | `squid` [L] | `inklet`, `crystal_jelly` and `jelly_bloom` (mantle only) |

`gull` is a rigid two-pose model, not a family.

For playable species, the family is also the rig. For every other creature, "family" means style only (shape, UV habits, the swim motion to match): prey, trait prey and predators have their own smaller rigs or none, with the bone counts in section 6.3 and the rig names in chapter 07 (`RIG_Moray`, `RIG_Barracuda`, `RIG_Grouper` and so on).

### 3.2 One primary shape per playable species

| Species | Primary shape | Signature feature (grows from juvenile to adult) | Must never be confused with |
|---|---|---|---|
| `minnow` | Teardrop, slightly fat | Forked tail | `sardine` (minnow is orange and twice as chunky) |
| `puffer` | Ball | Tiny fins on a huge round body; lips | `urchin_puff` |
| `eel` | Ribbon with a round head | Long dorsal ribbon | `moray` (moray is angular, mustard, toothy) |
| `turtle` | Dome over four paddles | Shell rim and beak | Reef rocks |
| `squid` | Bullet, big eyes low on the mantle | Two long feeding tentacles | `jelly_bloom` |
| `shark` | Wedge with a blunt snout | Tall dorsal fin | `old_scar` (pup is light, round-nosed, no scar) |

### 3.3 Proportions

Measured on the side view. Body length excludes the tail fin.

| Measure | Player juvenile (tiers 1 to 3) | Player adult (tiers 4 to 7) | Prey | Predator |
|---|---|---|---|---|
| Head length as a share of body length | 42% (40 to 45) | 32% (30 to 34) | 40 to 50% | 22 to 28% |
| Eye diameter as a share of head height | 34% (30 to 38) | 24% (22 to 26) | 36 to 42% | 10 to 14% |
| Pupil as a share of eye diameter | 60% | 50% | 65% | 35%, slit or small dot |
| Mouth, closed, as a share of head width | 25% | 35% | 15% | 60 to 70% of head length, teeth showing |
| Mouth, fully open, as a share of head height | 80% | 90% | not animated | 100% and over |
| Fins compared with the real animal | 140% | 130% | 120% | 100%, swept back |
| Tail fin height as a share of body height | 80% | 90% | 70% | 100 to 120% |
| Body depth as a share of body length (fish family) | 45 to 55%, as the species' size row in section 6.2 allows | 42% | 45% | 25 to 35% |
| Smallest radius on any outside corner | 6% of body height | 5% | 6% | 1% (sharp is allowed) |

All values **(tune)** after the first three species are reviewed side by side. Where a proportion here and a size in section 6.2 disagree, the size wins. The Minnow juvenile was 3.0 × 1.1 studs, which with chapter 03's short round tail could not reach this depth (spike S0-A7, F26); on 14 October 2026 its height became 1.365 studs, the reviewed S2-A1 mesh, whose body depth is 47% of its body length.

### 3.4 How danger reads in shape

| | Food | Neutral or player | Danger |
|---|---|---|---|
| Outline | Circles and ovals | Rounded teardrops | Triangles and wedges |
| Head | Bigger than the body suggests | Big | Small, low, pushed forward |
| Eyes | Huge, round, wide apart, on the side | Big, round, forward | Small, under a slanted brow ridge |
| Mouth | A dot or a small smile | Smile line; opens very wide | A long line with teeth that show when closed |
| Fins | Short, round tips | Round tips | Long, pointed, swept back |
| Posture | Bobbing | Level | Nose slightly down |
| Tooth count | None | None on juveniles; 2 to 4 blunt nubs on `shark` | 6 to 14 triangles, each at least 4% of head height so they survive distance |

A predator is frightening because it is big, sharp and fast. It is never bloody, scarred with wounds, or realistic. `old_scar` has one pale, healed scar line and a notched fin.

**Hazards** are neither round nor toothy: they are **spiky or wobbly and do not have faces** (`anemone`, `jelly_bloom`, `vent`, `hook`). No face means "this does not chase you".

### 3.5 Silhouette tests

Every creature passes all five before texturing starts. The preview script (section 15.5) renders them.

| Test | Method | Pass |
|---|---|---|
| **48-pixel test** | Solid black side view, 48 pixels long | A person who knows the roster names the creature |
| **Heading test** | Solid black from behind and above (the game camera) | Head end and tail end are obvious. This is the Kirby lesson. |
| **Half-cover test** | Hide the front half, then the back half | Either half alone still names the creature |
| **Line-up test** | All creatures of one class as silhouettes at equal length | No two can be swapped |
| **Friend-or-foe test** | Silhouette shown for half a second | A new viewer says "food" or "danger" correctly |

### 3.6 Tiers and the two forms

Body scale per tier comes from canon section 5.1. Art adds the differences below so a tier is readable without a number.

| Tier | Name | Mesh | Body scale | What changes visually |
|---|---|---|---|---|
| 1 | Fry | Juvenile | 1.0 | Baseline: biggest head and eyes |
| 2 | Nibbler | Juvenile | 1.3 | Scale only; tail beat 12% slower |
| 3 | Snapper | Juvenile | 1.7 | Scale; bubble wake appears when dashing |
| 4 | Hunter | **Adult** | 2.3 | Mesh swap inside the tier-up burst: longer body, smaller eyes, full signature feature |
| 5 | Brute | Adult | 3.2 | Scale; constant thin bubble wake |
| 6 | Titan | Adult | 4.5 | Scale; slow drifting sparkle motes around the body |
| 7 | Leviathan | Adult | 6.5 | Scale; a **crest** piece on `Sock_Crest` (one mesh per species, 150 triangles or fewer; shapes below); camera shake on bite |

The juvenile and adult meshes share one skeleton and one UV layout, so animations, traits and patterns work on both. Both are authored at body scale 1.0; the game multiplies by the tier scale.

**The Leviathan crest** (canon section 5.1) makes tier 7 readable by silhouette. Each body family has one crest shape; a species changes only its proportions and colours. All sizes **(tune)**.

| Family | Species | Crest shape | Where `Sock_Crest` sits |
|---|---|---|---|
| **Fish** | `minnow`, `puffer`, `shark` | A back sail: three rounded spines joined by a web, the front one tallest, 40% of body height tall and 30% of body length long. On `puffer` the three spines are short and fat; on `shark` the sail is lower (25%) so the tall dorsal fin stays the signature | On the back, between the head and the dorsal fin |
| **Eel** | `eel` | A head fan: five rounded lobes standing up in a half circle behind the head, as tall as the head is high, where the dorsal ribbon starts | On top of the neck, just behind the head |
| **Turtle** | `turtle` | A shell keel: three rounded knobs in a row down the centre line of the shell, the middle one tallest at 30% of shell height | On the top of the dome |
| **Squid** | `squid` | A mantle crown: three leaf-shaped points fanned at the tip of the mantle between the two tail fins, 25% of mantle length | At the tip of the mantle |

Rules for every crest: one rigid mesh with no bones and no outline shell (the outline follows the body); rounded tips like the rest of the body (section 3.3), never a spike or a wedge; painted in the species' dark colour with light tips, from the free block of the family UV layout (section 5.4), never in a signal colour. With the crest on, the tier 7 side silhouette must differ from the tier 6 one in the 48-pixel test (section 3.5). The crest grows in during the tier-up scale pop and pops off as bubbles if the tier falls (chapter 02). A new family (Manta Ray, Seahorse) defines its crest with its skeleton. Chapter 07 has one `M_Species_<Species>_Crest` row per species.

Tail-beat frequency falls as the creature grows: frequency = base ÷ √(body scale). Big reads as heavy.

---

## 4. Colour

### 4.1 The three-value rule

Every creature and prop has exactly three value blocks and one optional accent.

| Block | Share of visible surface | Lightness (L\*) | Where on a creature |
|---|---|---|---|
| **Mid** (the identity colour) | 55 to 65% | 45 to 80 | Back and flank |
| **Light** | 20 to 30% | 85 or more | Belly, cheeks, eye whites |
| **Dark** | 10 to 15% | 35 or less | Fin edges, markings, mouth interior, pupils |
| **Accent** (optional) | 5% or less (a species' ID mark: up to 10%, section 4.3) | any | Fin tips, one stripe, eye ring |

Rules that go with it:

- Gradients inside a block may move the lightness by at most 12 L\* points. More than that makes a fourth value.
- The head is the lightest and most saturated third of the body; saturation falls by about 15% toward the tail. This pulls the eye to the mouth.
- Shadows shift toward blue-violet (hue +20° toward 250°). Lights shift toward yellow (hue toward 50°). Never shade by adding black.
- **Water contrast rule:** the largest value block of a creature must differ from the fog colour of every zone it lives in by at least 25 L\* points, or sit at least 90° away in hue with saturation over 50%.
- Saturated but not neon: outside the signal colours, no surface colour may have both saturation above 85% and value above 95% (HSV).

### 4.2 Water by zone and depth

Fog colour is the colour distant objects fade to. L\* values were computed for this document.

| Zone | Scope | Surface band | Fog (mid water) | Deep band or floor shadow | Fog L\* | Floor |
|---|---|---|---|---|---|---|
| Nursery Lagoon | [MVP] | `#9FF0E6` | `#4CCFD2` | `#2FAFC0` | 77 | Sand `#F6E3B4` |
| Sunlit Reef | [MVP] | `#6FDDEE` | `#1E9FD0` | `#1783BF` | 61 | Sand `#F2D9A0`, rock `#C9A98F` |
| Kelp Forest | [MVP] | `#8FE0A0` | `#238A72` | `#17604F` | 52 | Silt `#8FA07A`, rock `#5F7F6F` |
| The Drop-off, upper (to 150 studs down) | [MVP] | `#3FA3E0` | `#1B6FBF` | `#124E9C` | 46 | Slate `#4F6FA0` |
| The Drop-off, deep (300 studs and below) | [MVP] | — | `#0B2A66` | `#081C4D` | 19 | Slate `#2F4A80` |
| The Trench | [P2] | — | `#060F33` | `#1A0F45` | 6 | Basalt `#1F1F4A` |
| Cove interior | [MVP] | `#7FE0E0` | `#3E8FA8` | `#2E6F8E` | 56 | Warm stone `#D9B48F` |
| Above the surface | [MVP] | Sky top `#4FB8FF` | Horizon `#BFE9FF` | — | 89 | — |

Between the upper and deep Drop-off values the client blends by camera depth (section 10.3).

### 4.3 Creature colours

Light / mid / dark / accent. All **(tune)** in the first review round.

**ID-mark exception to the accent cap.** A species' ID mark named in chapter 03 (the Minnow's yellow tail, for example) may take up to 10% of the visible surface **(tune)**. The 5% cap of section 4.1 applies to every other accent. (The Minnow's tail measures 8%; spike S0-A7, F26.)

| ID | Scope | Light | Mid | Dark | Accent | Note |
|---|---|---|---|---|---|---|
| `minnow` | [MVP] | `#FFE2A8` | `#FF9A3D` | `#922700` | `#FFD23D` | Tangerine. The starter must be the warmest thing in the Nursery. Dark was `#C2491D` (L\* 47, over the dark block's 35); `#922700` is L\* 33 at the same hue, chroma lowered to stay in sRGB (spike S0-A7, F26). Accent is the yellow tail ID mark, about 8% |
| `puffer` | [MVP] | `#FFF6D6` | `#FFD84A` | `#B8791F` | `#FF8C5A` | Yellow ball, ochre freckles, coral lips |
| `eel` | [MVP] | `#E0D6FF` | `#8A6BF0` | `#3B2A8C` | `#FFE066` | Violet with a yellow dorsal ribbon |
| `turtle` | [L] | `#FFF1C2` | Skin `#7CCB7A`, shell `#D9933D` | `#7A4A1E` | `#FFE08A` | The only species with two mids: skin and shell count as one block each, belly is the light |
| `squid` | [L] | `#FFD1E0` | `#FF6FA3` | `#B8336B` | `#FFF0A8` | Coral pink, cream spots |
| `shark` | [L] | `#F2F7FA` | `#8FA9C4` | `#3D5878` | `#FFB38A` | Pale steel. Pink cheeks keep it a pup. |
| `plankton` | [MVP] | `#FFFFFF` | `#D9FFE8` | — | — | A soft mote; drawn as a billboard |
| `krill` | [MVP] | `#FFD9CC` | `#FF8C7A` | `#C24A4A` | — | |
| `shrimp` | [MVP] | `#FFE6D1` | `#FFB48A` | `#C2693D` | — | |
| `sardine` | [MVP] | `#F2F8FC` | `#BFD9E8` | `#5C9AD9` | — | |
| `darter` | [MVP] | `#FFF6C9` | `#FFD23D` | `#2F7F8C` | `#FF7A5C` | |
| `mackerel` | [MVP] | `#E8F2F0` | `#2FA89A` | `#16574F` | — | Dark tiger marks on the back |
| `bonito` | [MVP] | `#E6EEF5` | `#6F8FD9` | `#23366B` | — | |
| `tuna` | [MVP] | `#F0F4F8` | `#4F6FD0` | `#162657` | `#FFD23D` | Yellow finlets |
| `gull` | [MVP] | `#FFFFFF` | `#C9D3DA` | `#5A6670` | `#F2A65A` | |
| `moray` | [MVP] | `#E6E0A0` | `#A8A23D` | `#4A4A1F` | `#FFF2D9` teeth | Mustard, angular |
| `barracuda` | [MVP] | `#F2F6F8` | `#C7D3D9` | `#3A4750` | `#FFD23D` eye | Dark bars |
| `grouper` | [L] | `#F0D9B0` | `#C4764A` | `#5F3320` | — | Brick with cream blotches |
| `old_scar` | [MVP] | `#F5F8FA` | `#B9C4CC` | `#4A5560` | `#FFD9D0` scar | |
| `jelly_bloom` | [MVP] | `#FFFFFF` | `#FFC2E2` | `#7A5CC2` | — | Pale pink bells with violet shade (chapter 03, section 5.2), see-through at 0.35 transparency. Paler and cooler than `anemone` pink |
| `anemone` | [L] | `#FFE6F0` | `#FF8FB8` | `#A83D6B` | `#FFF2A8` tips | |

**Prey temperature ramp.** Small prey is warm and light; large prey is cool with a silver flank. A player learns "warm and small is always food; cool and big, check the outline".

Trait prey carry their trait's signature colour (section 8.2) on a body built from the nearest prey palette.

### 4.4 Rarity colours

Used in the interface, on Codex cards, and as a small sparkle on trait prey. Never as a body colour.

| Rarity | Colour | Extra cue that does not depend on colour |
|---|---|---|
| Common | `#C9D6DF` pearl grey | 1 pip |
| Uncommon | `#2ED3C6` aqua | 2 pips |
| Rare | `#4D8DFF` blue | 3 pips |
| Epic | `#A862FF` violet | 4 pips, slow shine sweep |
| Mythic | `#FFB01F` gold | 5 pips, animated shimmer and a star |

Green and red are not rarity colours because they are signals.

### 4.5 Reserved signal colours

| Signal | Meaning (canon 5.2) | Default | Colour-blind alternative | Cue that does not depend on colour |
|---|---|---|---|---|
| **Can eat** | You can eat it | `#A6FF3D` lime | `#FFF23D` yellow | Steady outline |
| **Can eat you** | It can eat you | `#FF3B4E` red | `#FF3DC8` hot pink | Outline **pulses to white** twice a second, is 1.5× thicker, and a chevron points to it at the screen edge |
| **Home** | Yours only: the player's own cove mouth, the home marker pointing to it, the bank prompt | `#FFC46B` lantern amber | Same | Always a soft glow, never an outline |
| **Safe, not yours** | Other players' cove mouths and the Nursery's safe edge | `#FFF1DC` lantern warm white | Same | A soft glow, dimmer than home (60% of the amber's brightness **(tune)**), never an outline, no beam to the surface |
| **Pearls** | Currency | `#FFE9F2` with a `#FFB8D9` shade | Same | Pearl icon |

Notes:

- The lime sits at hue 88°, far from the kelp fog (hue 166°) and the reef fog (hue 197°). Its contrast against fog is 2.5 : 1 in the Reef, 3.4 : 1 in the Kelp and 6.5 : 1 in the upper Drop-off.
- The red has almost the same lightness as Reef and Kelp water (contrast 1.2 : 1). It separates by hue only. That is why the pulse to white is mandatory: white reaches 3.0 : 1 and 4.2 : 1 there. The same holds for the hot pink.
- The alternative pair differs strongly in lightness (L\* 94 against 61), so it survives red-green colour blindness. **(tune)** with a colour-blind simulator before soft launch; I did not simulate it.
- **Art may not use** any colour within 20° of hue of lime (68° to 108°) or red (334° to 14°), or within 10° of lantern amber (26° to 46°), when saturation is over 70% and value is over 85% (HSV). `minnow` mid (hue 29°, saturation 76%) is the one exception, approved because the starter is "home-coloured" on purpose. `ember` cracks use `#FF7A1F` at hue 24°, and `puffer` and `darter` yellows sit at hue 46° to 47°, all just outside the amber band; do not drift them inward. The float above a fishing hook is red and white (chapter 03, section 5.2): its red is the soft tomato `#D2564B` (hue 5°, saturation 64%, value 82%), under both limits, so it is not an exception and must not be brightened toward the outline red.
- **Amber is the player's own.** Lantern amber marks only the player's own cove mouth and the home marker (canon 5.2). Every other cove mouth and the Nursery's edge buoys glow lantern warm white `#FFF1DC` (hue 36°, saturation 14%), a neutral colour far below the saturation limit above, so it cannot be mistaken for home. The colour is chosen per viewer on the client: each player sees exactly one amber mouth. Chapter 03, section 6.7 owns the Door Lantern states and tints a friend's lantern teal.
- Rarity gold (`#FFB01F`) appears in the world only as the two-particle sparkle on Mythic trait prey. A sparkle is never a steady glow, so it does not read as home.

### 4.6 Interface colours

| Role | Colour |
|---|---|
| Ink (outlines, text) | `#14213D` navy |
| Panel | `#FFF8E7` cream |
| Panel shade | `#F2E3C4` |
| Primary button | `#FFC93D` sun yellow, shade `#E09A1F` |
| Secondary button | `#3DD6D0` aqua, shade `#1FA3A8` |
| Destructive or decline | `#FF6B5E` coral, with navy text (white on coral is only 2.8 : 1) |
| Text on dark | `#FFFFFF` |
| Disabled | `#B8C4CC` |
| Screen dim behind panels | `#0B1530` at 55% |

Navy on cream measures 15.1 : 1, navy on sun yellow 10.4 : 1, navy on aqua 8.9 : 1.

---

## 5. Texturing

### 5.1 What a GULP surface is

- One colour texture, hand-painted. No normal map, no metalness map, no photographic source, no procedural noise that looks like a photo.
- Matte. Every textured asset uses a `SurfaceAppearance` with its colour map plus a shared 8 × 8 flat roughness texture `T_Shared_Rgh` at 85% roughness **(tune)**, so nothing shows the default plastic shine. Sharing one tiny texture costs no memory.
- Wet highlights, eye glints and rim light are painted in.

| Map | Used? | Rule |
|---|---|---|
| Colour (albedo) | Always | sRGB .png, power-of-two, 24-bit, or 32-bit when a mask is needed |
| Roughness | The shared flat texture only | Two more shared values exist: `T_Shared_RghWet` at 35% for eyes and pearls, `T_Shared_RghChalk` at 100% for sand |
| Normal | **No** at MVP | Reconsider only for `old_scar` and the Whale Fall skeleton at [L], and only if a review shows flat lighting on them. If used: OpenGL tangent space. [V] |
| Metalness | **Never** | Metal needs sky reflections and reads as stock Roblox |
| Emissive mask | For glowing parts only | 8-bit greyscale. Documented for avatar items [V]; works on an ordinary skinned mesh in Mac Studio (Sprint 0, `docs/spike-report.md`); on phones [U]. Fallback: a small glow cap in the `Neon` material (rule below). |

**The Neon rule (canon section 13).** No asset uses a built-in Roblox material, with one exception: the built-in `Neon` material is allowed on **outline shells** (section 13.2) and on **small glow caps**, and nowhere else. A glow cap is a separate mesh piece of 120 triangles or fewer that sits over a part meant to glow (a coral tip, a kelp leaf edge, a trait's glowing line, an eye ring); together the caps on one asset cover at most 15% of its visible surface, the same cap as emissive overlays (section 8.3). A glow cap is the fallback where an emissive mask does not work, not a first choice. No creature body, prop, kit piece, floor, wall, beam or interface element is ever `Neon`.

### 5.2 Painting method

1. Bake ambient occlusion and a top-down gradient from the model in Blender to greyscale (section 5.5).
2. Paint the three value blocks in greyscale. Check the 48-pixel thumbnail. Stop if it does not read.
3. Colour each block with a gradient map: cooler dark end, warmer light end.
4. Multiply the baked occlusion at 30 to 40% strength, tinted `#5A4FA0`, never black.
5. Paint broad brush marks along the form. Smallest mark: 2% of the texture width.
6. Paint edge highlights and the eye glint last, on their own layer.

**Gradient rule.** Gradients are large, soft and few: at most two per value block, each covering at least 30% of the block. No banding, no airbrushed glow around details, no gradient that crosses from one value block into another.

**No photographic textures.** No scans, no photo-sourced stone, sand or skin, no AI images with photographic grain. Texture review zooms to 400%: visible noise finer than a brush mark is a rejection.

### 5.3 Colour texture or vertex colour

| Carried by | Used for | Why |
|---|---|---|
| Colour texture | Creature bodies, faces, patterns, hero props, anything with drawn shapes | Needs detail |
| Vertex colour | Only meshes with no `SurfaceAppearance`. It does not show under one (spike S0-A3, F16). | Free, but every textured asset has a `SurfaceAppearance` (section 5.1), so in practice it is rarely used |
| `SurfaceAppearance.Color` tint with `AlphaMode = TintMask` | Coral, kelp, anemone and prey colour variants; cheap pattern recolours | One texture, many colours, changeable at runtime [V] |

With no custom shaders, vertex colour cannot act as a mask. It is simply a colour multiplied over the texture. Where it is used, keep it between `#808080` and `#FFFFFF` so it only darkens gently. Under a `SurfaceAppearance` vertex colour does not show (measured in Mac Studio, spike S0-A3, F16), so **any mesh with a `SurfaceAppearance` carries its base colours in the colour map**. Environment meshes keep their `SurfaceAppearance`: depth darkening is a `SurfaceAppearance.Color` tint per chunk or module, and the other large gradients (moss, sand to rock blends, occlusion on kit pieces, variation between copies) are painted into the tiling textures or given by tint. A bare `MeshPart.TextureID` with no `SurfaceAppearance` is not an option for them, because it would show a built-in material's shine, which canon section 13 rules out.

Creatures do not use vertex colour. Their texture is the whole look.

### 5.4 Standard creature UV layout

Roblox allows one UV set [V], so base texture, pattern overlays and trait overlays must share it. Every creature in a family uses the same layout, so one overlay texture fits every species in that family.

| Region of the 0 to 1 square | Contents |
|---|---|
| U 0.00 to 1.00, V 0.50 to 1.00 | Body side, nose at U 0.05, tail root at U 0.80, tail fin from 0.80 to 1.00. Back edge at V 1.00, belly centre line at V 0.50. Left and right sides are mirrored on top of each other. |
| U 0.00 to 1.00, V 0.25 to 0.50 | Fins: dorsal, pectoral, pelvic, anal, each mirrored |
| U 0.00 to 0.25, V 0.00 to 0.25 | Eye (white, iris, pupil, lid) |
| U 0.25 to 0.50, V 0.00 to 0.25 | Mouth interior and tongue |
| U 0.50 to 0.625, V 0.00 to 0.25 | Teeth |
| U 0.625 to 1.00, V 0.00 to 0.25 | Free: family-specific (shell plates, arms, crest) |

Named predators (`old_scar`, `grouper`, `moray`, `barracuda`) take no traits, so they may break the layout and use unmirrored UVs.

### 5.5 Baking from Blender

| Setting | Value |
|---|---|
| Engine | Cycles, CPU, 64 samples for occlusion |
| Bake types | Ambient occlusion; an Emission bake of a top-down gradient material |
| Margin | 8 pixels at 512, 4 at 256 |
| Colour management while baking and saving | View transform **Standard**, look None, so hex values survive |
| Output | 16-bit PNG working file, 8-bit PNG export |
| High-poly source | Optional. Most assets bake from the game mesh with smooth shading. |

Only one bake or render job per asset at a time, and never more than two Blender processes on the development Mac.

### 5.6 Texture sizes and texel density

Density is measured at the authored size (body scale 1.0).

| Asset class | Colour texture | Target density |
|---|---|---|
| Player species, juvenile | 256 × 256 | 60 or more pixels per stud |
| Player species, adult | 512 × 512 | 26 or more at tier 7 (`minnow`, 19.5 studs long) |
| Pattern (painted variant) | Same as the form it replaces | — |
| Prey tiers 0 to 2 | One shared 256 × 256 atlas for all of them | 40 |
| Prey tiers 3 to 6, trait prey | 128 × 128 each, packed four to a 256 atlas | 30 |
| Predators | 512 × 512 | 24 |
| `old_scar`, Whale Fall skeleton | 1024 × 1024 | 24 |
| Trait overlays | 256 × 256 per trait per family | — |
| Trait kit pieces | One 256 × 256 atlas for all pieces | 40 |
| Environment tiling (sand, rock, coral rock, slate) | 512 × 512, tiles every 32 studs | 16, plus a `SurfaceAppearance.Color` tint (section 5.3) |
| Environment kit pieces (coral, kelp, rocks) | One 512 × 512 atlas per zone | 24 |
| Landmarks and set pieces | The zone atlas or a tiling texture by default. A 1024 × 1024 of its own only for the ones named in section 14.3 | 16 |
| Cove kit and props | One 512 × 512 atlas | 24 |
| Particle flipbooks | 512 × 512 (4 × 4), or 1024 × 1024 (8 × 8) for at most two effects | — |
| Interface icons | 256 × 256 master, shipped in 1024 × 1024 atlases | — |
| Skybox | 6 × 512 × 512 | — |

Nothing exceeds 1024. All **(tune)**.

---

## 6. Modelling specifications

### 6.1 Scale, axes and pivots

| Convention | Value |
|---|---|
| Unit | **1 Blender unit = 1 stud.** Unit system "None" in the template. |
| Forward | The creature's nose points along Blender **−Y**. Up is **+Z**. Exported as FBX −Z forward, Y up, which is Roblox's front. |
| Creature origin | On the centre line, at the middle of the body length and height. The root bone sits there at 0, 0, 0 with no weights. [V] |
| Prop origin | Centre of the base, where it meets the floor |
| Kit-piece origin | The snapping corner or the centre of the base; stated in the asset's `build.py` |
| Transforms | Location, rotation and scale applied before export. Bones at scale 1, rotation 0. [V] |
| Calibration asset | `M_Prop_ScaleCube`: a 4-stud cube with an arrow on its front. Imported once per Blender or Studio version to confirm scale and facing. The FBX scale factor that makes it 4 studs (0.01, measured in Sprint 0: 4 studs, facing Front) is stored in the export script. |

### 6.2 Authored sizes at body scale 1.0

| Creature | Length in studs | Note |
|---|---|---|
| `minnow` | 3.0 long, 1.365 tall, 0.7 wide | Tier 7 is 19.5. Height raised from 1.1 on 14 Oct 2026 (chapter 03, section 1.1); no gameplay rule reads it |
| `puffer` | 2.4 long, 2.0 tall and across | Puffed mesh is a ball 3.0 across (1.5 times the normal height) |
| `eel` | 5.0 long, 0.8 tall, 0.6 wide | Eel tunnels are 7 studs across (chapter 03, section 6.9); art supplies the ring (section 9.3) |
| `turtle` | 3.0 long, shell 2.6 wide | |
| `squid` | 3.6 with arms | |
| `shark` | 3.4 | |
| `plankton` / `krill` / `shrimp` | 0.4 / 0.8 / 1.0 | Chunkier than life so they stay visible |
| `sardine` / `darter` | 1.6 / 2.4 | |
| `mackerel` / `bonito` / `tuna` | 3.6 / 5.5 / 8.5 | |
| `gull` | 8 wingspan | |
| `moray` | 16 showing at full lunge | |
| `barracuda` | 12 | |
| `grouper` | 14 long, 9 tall | |
| `old_scar` | 30 | One and a half times a Leviathan `minnow` |

**Chapter 03 owns these sizes** (its sections 1.1, 2.2 and 5.2); this table is a copy for the modeller, and hit radius and cove display scale derive from the same numbers. If the two differ, chapter 03 wins.

**Prey size rule:** prey of tier N is never more than two-thirds as long as a tier-N `minnow` (the closest is `tuna` at 63%). All **(tune)**.

### 6.3 Triangle and bone budgets

Triangles are counted after triangulation. "Shell" is the outline mesh (section 13.2). A prey `_LOD2_Shell` gets 80 triangles **(tune)**, or a quarter of its LOD0 shell where that is more. The tier-1 and LOD2 prey shell numbers sit above "about 40% of the body" because an outline of even width needs them: measured about 62 on `krill` and 76 on the `darter` LOD2 with the Sprint 0 shell tool (`spike/results/art-blender.md`, F26).

| Asset class | Triangles, LOD0 | Shell | Bones | Scope |
|---|---|---|---|---|
| Player species, juvenile | 1,500 | 600 | Family count below | per species |
| Player species, adult | 3,500 | 1,400 | Same skeleton | per species |
| `puffer` puffed mesh, juvenile / adult (`_Juv_Puffed`, `_Adult_Puffed`) | 1,800 / 4,000 (the one mesh allowed above the adult 3,500, because a ball needs the extra rings) | 40% | Same skeleton | [MVP] |
| `turtle` tucked mesh, juvenile / adult (`_Juv_Tucked`, `_Adult_Tucked`) | 900 / 2,000 | 40% | Same skeleton | [L] |
| Leviathan crest | 150 | — | 0 (socketed) | per species |
| `plankton` | 2 (billboard) | none | 0 | [MVP] |
| Prey tier 1 (`krill`, `shrimp`) | 60 to 120 | 64 **(tune)** | 0 | [MVP] |
| Prey tier 2 (`sardine`) | 150 | 60 | 0 | [MVP] |
| Prey tier 3 (`darter`) | 300 | 120 | 3 | [MVP] |
| Prey tier 4 (`mackerel`) | 450 | 180 | 3 | [MVP] |
| Prey tier 5 (`bonito`) | 600 | 240 | 3 | [MVP] |
| Prey tier 6 (`tuna`) | 900 | 360 | 4 | [MVP] |
| Trait prey | 300 to 700 | 40% | 0 to 4 | by trait |
| `gull` | 800 | 320 | 0 (two-pose swap) | [MVP] |
| `moray`, `barracuda` | 2,000 | 800 | 12 | [MVP] |
| `grouper` | 3,500 | 1,400 | 14 | [L] |
| `old_scar` | 8,000 | 2,400 | 24 | [MVP] |
| `jelly_bloom` (each) | 300 | none | 0 | [MVP] |
| `anemone`, `vent`, `hook` | 400 / 500 / 150 | none | 0 | [L] / [L] / [MVP] |
| Trait kit piece | 20 to 120 | — | 0 | by trait |
| Kelp plant | 500 | — | 4 near, 0 far | [MVP] |
| Coral, small / medium / large | 250 / 700 / 1,800 | — | 0 | [MVP] |
| Rock, small / medium / large | 120 / 350 / 1,000 | — | 0 | [MVP] |
| Sea-floor chunk, 128 × 128 studs | 3,000 | — | 0 | [MVP] |
| Cliff module, 64 × 96 studs | 2,500 | — | 0 | [MVP] |
| Landmark | 5,000 | — | 0 | [MVP] |
| Large set piece (the Tin Pickle wreck; the Whale Fall skeleton) | 15,000 each at most, split into meshes of 6,000 or fewer | — | 0; skeleton jaw 2 | [MVP] / [L] |
| Cove interior shell | 6,000 | — | 0 | [MVP] |
| Cove prop or decoration | 100 to 800 | — | 0 | [MVP] / [L] |

Skeletons by family. Sockets (section 8.4) are extra, weightless bones in the Blender rig; the importer drops them, so the game rebuilds them from the socket table exported with each rig (section 8.4).

| Family | Deform bones | List | Sockets |
|---|---|---|---|
| Fish | 18 | Root, Spine1 to 4, TailFin, Jaw, Dorsal, Pec_L, Pec_R, Eye_L, Eye_R, Lid_L, Lid_R, Girth_Top, Girth_Bot, Girth_L, Girth_R | 10 |
| Eel | 22 | Root, Spine1 to 10, Jaw, Dorsal1 to 2, Eye_L/R, Lid_L/R, Girth_Top/Bot/L/R | 10 |
| Turtle | 20 | Root, Shell, Neck, Head, Jaw, Flip_FL/FR (2 each), Flip_BL/BR, Tail, Eye_L/R, Lid_L/R, Girth_Top/Bot/L/R | 8 |
| Squid | 24 | Root, Mantle1 to 3, Fin_L/R, Arm1 to 6 (2 each), Eye_L/R, Lid_L/R, Girth_L/R | 8 |

Hard ceiling for any rig: **32 bones including sockets (tune)**. Roblox states no bone limit on the pages read [U]; the ceiling is ours, for skinning cost on phones.

### 6.4 Level of detail

Switching is by size on screen, so it holds for every tier and every device.

| Level | When (creature's length on screen, in points on an 844-point-wide frame) | What is drawn |
|---|---|---|
| LOD0 | Over 80 | Full mesh, full skeleton, eyes and lids animate |
| LOD1 | 20 to 80 | Half the triangles, same skeleton, lids frozen |
| LOD2 | 8 to 20 | A quarter of the triangles, rigid, whole-body wobble only |
| Glint | Under 8 | A 2-triangle billboard dot in the creature's light colour, or in its outline colour if it has one |

- Player species and predators ship LOD0, LOD1 and LOD2. Prey of tier 3 and up ship LOD0 and LOD2. Smaller prey ship one mesh.
- The client chooses the level, because prey are drawn by the client from plain data (canon section 14).
- Static environment meshes use `RenderFidelity = Automatic` [V]. The switching distances are not documented [U].
- Shells follow the same levels; the Glint replaces the shell.
- The graphics tier can lower the best level other players are drawn at (on Smooth, other players start at LOD1 and only your own creature uses LOD0). Chapter 15, section 3.0 owns that table.

### 6.5 Mesh rules

- Quads while modelling; triangulated by the export script.
- Watertight, no zero-thickness faces [V]. Fins and kelp leaves are thin closed volumes at least 0.03 studs thick.
- One material and one UV set per mesh [V].
- At most 4 bone weights per vertex [V]; weights normalised; no weights on Root.
- Smooth shading with split normals only where a hard edge is intended (teeth, plates, crystal).
- No interior faces, no geometry smaller than 1% of the asset's length.
- Eyes are separate spheres inside the same mesh so they can turn. Eyelids are caps that rotate over them.

### 6.6 Naming

Canon section 16 gives the patterns, the categories (`Species`, `Prey`, `Pred`, `Hazard`, `Env`, `Cove`, `Prop`, `Trait`) and the mesh suffixes. Chapter 07 owns the full asset naming rules and chapter 08 owns interface image names; where an example below differs from them, they win.

| Thing | Pattern | Example |
|---|---|---|
| Mesh | `M_<Category>_<Name>[_Juv\|_Adult][_<Form>][_LOD1\|_LOD2][_Shell\|_ShellThick]`, where the form is a second pose or state of the same mesh (`_Puffed`, `_Tucked`, `_Glide`, `_Dive`, `_Open`, `_Squeezed`) | `M_Species_Minnow_Adult_LOD1`, `M_Species_Puffer_Juv_Puffed` |
| Texture | `T_<Name>_<Map>` with maps `Alb`, `Rgh`, `Emi`, `Mask`, `Nrm` | `T_Minnow_Adult_Alb` |
| Animation | `A_<Rig>_<Action>` | `A_Fish_Bite`, `A_Minnow_Dart` |
| Effect | `FX_<Name>` | `FX_TierUp_T4` |
| Interface image | `UI_<Screen>_<Name>` | `UI_HUD_DashButton` |
| Trait kit piece | `M_Trait_<Trait>_<Piece>` | `M_Trait_Plated_Plate` |
| Trait overlay | `T_Trait_<Trait>_<Family>_Alb` | `T_Trait_Stripes_Fish_Alb` |
| Bone | `PascalCase`, side as `_L` or `_R` | `Pec_L` |
| Socket bone | `Sock_<Zone>[_<nn>]` | `Sock_Back_02`, `Sock_Crest` |

Rigs use `RIG_`, lighting presets `LGT_`, skies `SKY_` and store-art scenes `SCN_` (canon section 16).

### 6.7 Export and import

| Blender FBX export setting | Value |
|---|---|
| Format | FBX binary. One format for everything, because skinning and animation need it. [V] |
| Selection | Selected objects only: the mesh, its armature |
| Scale | The factor stored by the calibration asset; Apply Scalings "FBX All" |
| Axes | Forward −Z, Up Y |
| Geometry | Apply modifiers; triangulate; smoothing "Normals Only"; no tangents |
| Vertex colours | sRGB (measured in Sprint 0: a 128 grey reads 0.502 in Studio) |
| Armature | Only deform bones **off**; Add Leaf Bones **off**. Socket bones still export, but the importer drops them (section 8.4) |
| Socket table | Written beside each rig's FBX by the export script: socket name, parent bone, offset CFrame. The game builds the sockets from it (section 8.4) |
| Animation | One action per file [V]; 30 frames a second; key all bones; no simplification. Clips also go out as JSON for the clip route below |
| Textures | Not embedded. Uploaded separately as .png. |

| Roblox 3D Importer setting | Value |
|---|---|
| Scale Unit | Stud (the default [V]) |
| Rig Type | Custom for rigs, No Rig for props [V] |
| Import Only As Model | On |
| Set Pivot to Scene Origin | On |
| Anchored | Off for rigs, on for props |
| Merge Meshes | Off |
| Ignore Vertex Colors | Off |
| Make Double Sided | Off, always. It costs more [V]. |

After import, set `MeshPart.Color` to white (255, 255, 255) on every imported mesh: the importer leaves it at 163, 162, 165, which darkens the faces (spike S0-A2, F23; that white restores the painted colour is not verified). Set `CollisionFidelity` to Box on small props and `CastShadow` to false on every creature, prey item, kelp leaf and small prop.

**Clip route, no click.** An Open Cloud Model upload drops the animation, and an Open Cloud Animation upload accepts only a binary `.rbxm`. So every clip goes: Blender action exported as JSON → a `KeyframeSequence` built against the imported skeleton (converter `spike/tools/anim_kfs.py`) → a binary `.rbxm` written by Lune → an Open Cloud Animation upload. Measured in Sprint 0: `A_Fish_Swim` arrived this way with every bone within 0.0001 studs of Blender and no owner click (spike S0-A2, F20).

---

## 7. Animation style

### 7.1 Principles and timing

Animations are authored at **30 frames a second**; Roblox interpolates on faster screens. One frame is 33 milliseconds.

| Principle | GULP rule |
|---|---|
| Pose to pose | Every action is 2 to 4 strong poses. Hold a pose for at least 3 frames before leaving it. |
| Anticipation | Gameplay actions: 2 frames at most, because the player must never feel a delay. Showpiece actions (tier-up, ability, emote): 4 to 6 frames. |
| Overshoot | Go 10 to 30% past the target pose for 2 frames. |
| Settle | Return in 4 to 8 frames with one small rebound (3 to 5% the other way). |
| Squash and stretch | Length and girth trade off. Stretch 125% means girth 89%. Limits: 70% to 135% in gameplay, 60% to 150% in showpieces. |
| Arcs and drag | Tail, fins and arms lag the body by 2 to 3 frames. |
| Exaggeration | If it reads in the viewport, double it and check on the phone frame. |
| Easing | Fast out, slow in. No linear keys except loops. |

### 7.2 Actions

Frames at 30 a second. All **(tune)**.

| Action | Anticipation | Action | Overshoot | Settle | Total | Notes |
|---|---|---|---|---|---|---|
| **Bite** | 0 to 2 (jaw already opening as prey nears) | 1: jaw snaps shut, head lunges 12% of body length | 2: body stretch 115% | 4 | 7 to 9 | Played on predicted contact. Cheeks bulge on frame 2. |
| **Swallow bulge** | — | 8: a bump travels from head to tail on the Girth bones | — | 4 | 12 | Bigger prey, bigger bump |
| **Dash** (0.35 s) | 2: squash to 85% | 6: stretch 125%, fins pinned back | 2: 95% | 4 | 14 | The move itself starts on frame 1; the squash overlaps it |
| **Tier-up** | 3: squash to 75% | 3: pop to 130% of the new size | 4: 110%, then 96% | 8 | 18, plus a 6-frame sparkle hold | The mesh swap at tier 4 happens on the pop frame, hidden by `FX_TierUp_T4` and `FX_Metamorph` (chapter 07) |
| **Gulped** (victim) | — | 4: stretch 140% toward the mouth | 4: shrink to nothing | `FX_GulpPop` for 12 | 20 | No blood. A burst of bubbles and one spinning star. |
| **Gulp** (eater) | 2: mouth opens to full | 1: snap | 3: head 110% | 6, with the swallow bulge | 12 | |
| **Hit and survived** (Plated) | — | 2: flash white, squash 80% | 3 | 6 | 11 | Plates crack on frame 2 |
| **Ability start** | 4 | by species | 2 | 6 | varies | `Puff` and `Shell` swap meshes (section 7.5) |
| **Bank** (enter cove) | — | 10: happy spin, eyes closed | — | 8 | 18 | |
| **Stunned** | — | Loop of 20: wobble, eyes spiral | — | — | loop | |

### 7.3 Swim cycles by family

Players' spines are swayed by code (section 7.6); the table gives the motion to match. Loop lengths are at cruising speed and tier 1.

| Family | Motion | Loop | At dash | Details |
|---|---|---|---|---|
| **Fish** | A wave from head to tail: 5% of body height at the head, 100% at the tail tip | 16 frames | 8 frames, amplitude 130% | Pectoral fins flutter on a 6-frame loop when slow, fold when fast. `puffer`: body barely bends; the tiny fins whir on a 4-frame loop and the body wobbles. `shark`: slower, 20 frames, head sweeps 8%. |
| **Eel** | A full sine wave, one and a half wavelengths along the body | 20 frames | 10 frames | Head stays steadier than the body: 30% of mid-body amplitude. Dorsal ribbon lags 3 frames. |
| **Turtle** | Front flippers row together: power stroke 10 frames, recovery 20 | 30 frames | 16 frames | Body rises 4% on the power stroke and sinks on recovery. Back flippers steer only. |
| **Squid** | Mantle squeezes for 4 frames, then glides for 20 while the arms trail closed, then arms open | 24 frames | Squeeze every 10 frames | Moves tail-first when jetting. Side fins ripple on an 8-frame loop. |

### 7.4 Idle in the cove

Specimens in a cove are the trophy shelf, so they act.

| Beat | Timing |
|---|---|
| Bob | 90-frame loop, 0.15 studs up and down, eased |
| Blink | Every 2 to 4 seconds: close 1 frame, hold 1, open 2 |
| Look | Eyes jump to a new target every 1 to 3 seconds in 2 frames; the head follows over 8 |
| Notice a visitor | Turn to face over 10 frames, small happy squash (92%), then return |
| Species fidget | One 40- to 60-frame clip per species, played about every 12 seconds: `minnow` chases its tail, `puffer` hiccups a bubble, `eel` ties a loose knot and unties it |

### 7.5 Squash and stretch inside Roblox's limits

`Bone.Transform` holds position and rotation only [V], and Roblox animations do not carry bone scale. Resizing a skinned mesh forces a costly rebuild [V]. So:

| Need | Method |
|---|---|
| Stretch and squash along the body | **Move the bones.** Spread the Spine bones apart to stretch, bring them together to squash. The skin follows. |
| Keep the volume | Move the four **Girth** bones outward when squashing and inward when stretching. They are weighted softly over the middle 60% of the body. Girth offset = body radius × (1 ÷ √stretch − 1). |
| Swallow bulge | Slide the Girth bones' influence by offsetting them in sequence with a neighbour Spine bone |
| Growing on tier-up | `Model:ScaleTo` on the whole creature, once per tier. Uniform scale only. Cost measured in Sprint 0: 0.15–0.47 ms for 6.5× on a playing rig (Mac); tier-ups are rare. |
| Extreme shapes: `puffer` Puff, `turtle` Shell, the tier-4 form change | **Mesh swap** hidden by a 3-frame effect. `M_Species_Puffer_Juv_Puffed` and `_Adult_Puffed`, and `M_Species_Turtle_Juv_Tucked` and `_Adult_Tucked`, share their species' skeleton (budgets in section 6.3). |
| Rigid prey | Whole-part CFrame: a small yaw wobble, and non-uniform `Size` is avoided. A bite victim simply shrinks. |

### 7.6 Code-driven sway and keyframes

| Layer | Bones | Driven by |
|---|---|---|
| Swim sway | Spine, TailFin, Dorsal | Code on each client, every frame on `PreRender`, for every creature at LOD0 or LOD1. Frequency follows speed, amplitude follows acceleration, and the spine bends toward the turn (up to 25° across the body at full turn rate). |
| Stretch | Spine spacing, Girth | Code: stretch follows forward acceleration, clamped to the limits in 7.1 |
| Eyes and lids | Eye, Lid | Code: look target and expression (section 7.7) |
| Actions | All bones | Keyframed clips: bite, dash pose, abilities, tier-up, gulped, bank, cove fidgets. While a clip plays, sway amplitude drops to 30%. |
| Fins | Pec, flippers, arms | Keyframed loops |

Bones are not replicated [V], so each client computes sway locally; nothing is sent over the network. **Code-owned bones are written on `RunService.PreRender`.** The Animator resets every bone each frame, keyed or not, so a write survives only after it, on `PreRender`; a `PreAnimation` write is lost (measured in Mac Studio, spike S0-A2, F15). Every bone code drives (sway, stretch, jaw, eyes and lids) follows this rule. Written there, code layers over a playing clip, so the fallback (leaving the sway bones out of every keyframed clip) is not needed.

Prey of tiers 3 to 6 use the same sway code on 3 or 4 bones. Smaller prey are rigid; the school's shared motion sells them.

### 7.7 Faces: expression through the eyes

There are no mouth shapes for speech and no eyebrows. The eyes and lids do the acting; the mouth has three states (closed smile, open, full gape).

| Expression | Lids | Eyes | When |
|---|---|---|---|
| Neutral | Open 85% | Look where the creature is heading | Default |
| Happy | Lower edge raised 30%, making an arch | Soft | After a bite, banking, in the cove |
| Hunting | Inner edges tilted down 20° | Locked on the nearest green-outlined prey | Prey within 30 studs |
| Scared | Fully open | Eye bones pushed outward 15% (bulge), looking at the threat | A red-outlined creature within 60 studs |
| Dizzy | Half closed, uneven | Eyes rotate in opposite circles | Stunned, hooked |
| Gulped | — | Swapped for two `X` marks (a 2-triangle card per eye) for the 4 shrink frames | Being eaten |

Eye turn limit: 35° from rest. A white glint is painted on the eye texture and does not move, so the eye always looks wet and alive.

---

## 8. How traits appear on bodies

Canon pillar 2: traits come from prey and appear on the body. A trait must be nameable from the 96-pixel thumbnail.

### 8.1 Three channels

A creature has three visual channels. Each trait owns one channel, so three traits can share a body without mud.

| Channel | What it changes | Method |
|---|---|---|
| **Pattern** | Flat markings on the skin | Overlay texture in the standard UV layout |
| **Light** | Glow, crackle, shimmer | Emissive overlay (fallback: small `Neon` glow caps, section 5.1), plus one particle emitter and, for two traits, a point light |
| **Form** | The silhouette | Kit pieces attached to sockets |

### 8.2 The thirteen traits

| ID | Rarity | Scope | Channel | Method | Signature colour | Home zone on the body | Fallback zone | Pieces and cost |
|---|---|---|---|---|---|---|---|---|
| `glow` | Common | [MVP] | Light | Overlay (emissive) + light | `#FFE98A` | Lateral line, nose to tail | Tail tip and fin edges | 256 overlay; `PointLight` range 10 × scale, brightness 0.5 |
| `stripes` | Common | [MVP] | Pattern | Overlay | `#1E2A4A` on `#FFFFFF` | Flank: 4 bold bands | Rear third: 2 bands | 256 overlay |
| `spots` | Common | [MVP] | Pattern | Overlay | `#FFF3D1` dots ringed `#3A2A4A` | Back and flank: 7 to 9 dots | Head and shoulders: 4 dots | 256 overlay. Smallest dot is 8% of body height. |
| `plated` | Uncommon | [MVP] | Form | Kit pieces + thin overlay | `#B8C4CC`, edge `#6B7A85` | Back: 5 overlapping plates | Head: 1 helmet plate | 1 plate piece (60 triangles) used 5 times; a second "cracked" piece for after the saved bite |
| `spiny` | Uncommon | [MVP] | Form | Kit pieces | `#F2E6C9`, tips `#C2491D` | Back and flanks: 9 spines | Tail: 3 spines | 1 spine piece (20 triangles) |
| `longfin` | Uncommon | [MVP] | Form | Kit pieces + trail | Species accent fading to `#FFFFFF` | Tail and dorsal fin tips | Pectoral tips | 2 ribbon pieces (80 triangles); a `Trail` from each tip while moving |
| `ink` | Rare | [MVP] | Pattern | Overlay | `#2A1F3D` | Belly and rear half: blotches rising like smoke | Fins only | 256 overlay; `FX_InkCloud` on dash |
| `spark` | Rare | [L] | Light | Overlay (emissive) + particles | `#5CF2FF`, core `#FFFFFF` | Zigzag lines from the head back | Dorsal edge | 256 overlay with 3 swap frames at 10 a second, each a pre-made `SurfaceAppearance` swapped in (section 8.4); `FX_SparkArc` |
| `camo` | Rare | [L] | Form | Kit pieces + overlay | `#6FA35A`, `#A8843D` | Leafy frills along back and fin edges | Chin and tail | 2 leaf pieces (40 triangles), swayed by the sway code |
| `crystal` | Epic | [MVP] | Form | Kit pieces + overlay | `#FF9BE6`, `#9BD6FF`, `#FFFFFF` | A crown of shards on the back; faceted patches | Tail shards | 3 shard pieces (30 triangles each), hard-edged, `T_Shared_RghWet`; slow glint particle |
| `ember` | Epic | [L] | Light | Overlay (emissive) + particles | `#FF7A1F`, core `#FFD23D` | Cracks across back and flank | Belly cracks | 256 overlay; rising ember motes, 4 a second |
| `moonlit` | Mythic | [MVP] | Light | Overlay (emissive) + light + particles | `#D9D6FF`, glow `#7DF9FF` | A silver rim around the whole outline, brightest on the back | Fin rims | 256 overlay; `PointLight` range 14 × scale; drifting star motes, 3 a second |
| `bonefed` | Mythic | [L] | Pattern | Overlay | `#F3ECD8` | A friendly cartoon skeleton drawn on the flank: spine, ribs, a skull mask on the face | Tail bones only | 256 overlay; the body's mid colour is darkened 30% under it |

Bonefed is a costume, not a corpse: round bones, a smiling skull.

### 8.3 Combining three traits without mud

1. **One trait per channel gets the home zone.** If two traits share a channel, the higher rarity keeps its home zone and the other moves to its fallback zone. Equal rarity: the trait gained first keeps home.
2. **Three in one channel:** the third trait shows only as its sparkle colour on the fin tips and as its icon in the trait slots. It still works in play.
3. **Coverage caps.** Pattern overlays cover at most 35% of the body. Emissive overlays cover at most 15%. Kit pieces add at most 25% to the silhouette's area. The head, from the nose to behind the eye, is always free of pattern, except the Bonefed mask.
4. **One light.** A creature carries at most one `PointLight`. Moonlit beats Glow.
5. **One emitter per trait, 6 particles a second each at most.**
6. **Order of layers, bottom to top:** base texture, pattern (lower rarity first), emissive, kit pieces, outline shell.
7. **Value check.** With all three traits on, the 48-pixel thumbnail must still show the species' mid colour over at least 40% of the body.

The combination sheet (section 15.5) renders every species with the 12 hardest triples; a reviewer checks it once per new trait.

### 8.4 Sockets and overlays in the engine

**Sockets.** Each fish and eel species carries ten weightless bones: `Sock_Back_01` to `03`, `Sock_Flank_L`, `Sock_Flank_R`, `Sock_Head`, `Sock_Tail`, `Sock_Crest`, `Sock_FinDorsal` and `Sock_FinTail`. Turtle and squid carry eight (no fin sockets). Sockets stay weightless in Blender, and the validator keeps its "no weight on sockets" rule. A socket's rest rotation points the piece outward. Kit pieces are small rigid meshes the client attaches to sockets. A placement table per species gives each piece a socket, an offset and a scale, so one socket can carry several pieces (five plates hang from three back sockets). So a new species needs only sockets, and a new trait needs only one to three pieces.

**Sockets are built by code.** The FBX importer drops every bone with no vertex weight of about 0.02 or more, so no socket survives import (spike S0-A2, F13). The export script therefore writes a **socket table** with each rig: socket name, parent bone, offset CFrame. When a rig template is built, code adds one `Bone` per row under its parent bone; the measured rig then had all 28 bones (18 deform, 10 sockets).

**Rigid pieces attach by `RigidConstraint`.** A piece is a rigid `MeshPart` held to its socket bone by a `RigidConstraint`, which followed a playing clip with an error of 0.000 studs (spike S0-A2, F14). The `Motor6D` on the root part that the importer makes for a mesh parented to a socket is not used.

**Skinned pieces are built into the template.** A skinned `MeshPart` cloned onto a live rig stays in its bind pose (IoU 0.645); one added to the template before the creature spawns deforms with it (IoU 0.994) (spike S0-A4, F19). So every skinned piece (overlay shells, gear shells and any other skinned piece added at run time) goes into the template before spawning.

**Overlays.** The trait spike picked **option B** (spike S0-A4):

| Option | How | Result |
|---|---|---|
| A. Decal layers (dropped) | A `Decal` on a skinned `MeshPart` is projected per face, not along the mesh UVs (spike S0-A4, F18). | Fail |
| **B. Overlay shell** (chosen) | A second skinned mesh 0.5% outside the body with the overlay as its `SurfaceAppearance`, `AlphaMode = Transparency`, built into the template before spawning (above). Each overlay's `SurfaceAppearance` is made ahead of time and cloned; game scripts cannot set its maps (F17). | Pass, IoU 0.994. Doubles the creature's triangles while any pattern trait is active |
| C. Composite | Build one texture per creature on the client from base and overlays, shown only through `MeshPart.TextureContent`, with no PBR maps: game scripts cannot set an `EditableImage` as a `SurfaceAppearance` map (spike S0-A4, F17) | Kept only as a fallback |

---

## 9. Environment art

### 9.1 Approach

- **Mesh, not Roblox terrain.** Terrain voxels are 4 studs [V], terrain uses stock materials, and terrain water offers only colour, reflectance, transparency, wave size and wave speed [V]. The whole world is built from our meshes.
- **The sea is not a water volume.** Underwater, the "water" is fog and light (section 10). Only the surface is a model.
- **Kits.** Each zone has a small set of pieces reused with rotation, scale (80% to 125%) and tint. Identical meshes with identical textures batch into one draw call [V], so fewer unique pieces is also faster.
- **Rest and detail.** About 60% of any view is calm (open water, plain sand, plain rock). Detail gathers in clumps at eye level and around landmarks.

### 9.2 Kit pieces per zone

Counts are unique meshes. All [MVP] unless tagged.

| Zone | Floor and walls | Kit pieces | Unique to the zone |
|---|---|---|---|
| **Nursery Lagoon** | 4 sand chunks, 2 low rim pieces | 3 round pastel corals, 2 sea-grass tufts, 3 smooth pebbles, 2 shells | A ring of lantern warm-white (`#FFF1DC`) glow buoys marking the safe edge; water so shallow the surface ripples show on the sand |
| **Sunlit Reef** | 8 sand chunks, 6 reef-rock blocks, 4 arches and tunnels | 12 corals (brain, staghorn, fan, tube, table; 3 sizes), 4 sponges, 3 sea grasses, `anemone` [L], 2 eel-hole rings | Crevices for `urchin_puff`, caves for `glowfry`, bait `hook`s hanging from the surface |
| **Kelp Forest** | 6 silt chunks, 4 mossy boulders, 3 root mounds with moray holes | Kelp plant in 3 heights (40, 80, 140 studs), canopy leaf cards, 3 ferns, 2 fallen logs | The canopy: a broken ceiling of leaves with shafts of light between |
| **The Drop-off** | 8 cliff modules, 4 ledges, 3 overhangs, 2 floor shelves | 4 dark sponges, 3 sea whips, 2 tube-worm clusters, nine `vent` chimneys at the Chimneys, each 12 studs tall (cold stone in the MVP, lit at launch [L]) | The Tin Pickle wreck (home of `spark_eel` [L]), the pale bowl of Whale's Rest (the Whale Fall site [L]), current streams |
| **Coves** | 1 interior shell, 1 mouth arch | Specimen perch marker (40 perches, one per cove slot; a kelp net covers a locked one), Name Shell, Trophy Bubble, Door Lantern, Home Stone, Pearl Clam, Trophy Rock, Codex Stone, Species Wall, tide clock; Bubble Jar, 29 decoration spots and decorations [L] | Warm lantern light. All 24 coves use the same meshes. Chapter 03, sections 6.7 and 6.10 own the parts list and sizes. |
| **The Trench** | — | — | [P2]. Not designed here beyond its colours. |

### 9.3 How each place is built

**The reef.** Three layers. Layer 1: big rounded rock masses in a calm, low-saturation mid value set the paths; every path is at least 20 studs wide so a tier-5 creature fits. Layer 2: coral clusters in saturated colour, in groups of 3, 5 or 7, each group one hue family. Layer 3: small bright details at eye level only. Coral colours come from one greyscale atlas tinted per cluster: `#FF7F9F`, `#FFA35C`, `#FFD86B`, `#B48CFF`, `#5CD6C8`, `#FF6B6B` reduced to 80% saturation near signal hues.

**Eel holes** (tunnels 7 studs across) have a ring of blue barnacles at each end. The ring glows teal (`#5CD6C8`, a tint set per viewer) for Eel players and stays dull blue for everyone else, so an Eel player learns "glowing ring means my shortcut". **Moray holes** have a ring of pale bone-white pebbles instead, and two yellow eyes in the dark, so the two kinds of hole are never confused. Chapter 03 (sections 5.2 and 6.9) owns both looks.

**The kelp forest.** Stalks stand 12 to 30 studs apart, in groves with clearings between. Plants within 80 studs of the camera, 24 at most, are 4-bone skinned plants swayed by the client; farther plants are static. The forest is dim, but clearings sit under canopy gaps where light shafts fall, so the player always has a bright place to aim for.

**The Drop-off.** A cliff wall built from 64 × 96 stud modules, stepping down in ledges every 60 to 90 studs so depth is countable. The wall is darker and cooler with depth through a `SurfaceAppearance.Color` tint per module (section 5.3). Lone pale objects (a white sea whip, a tube-worm cluster) give scale against the dark.

**Coves.** Each cave mouth is a rounded opening 36 studs wide and 28 high, with a 25-stud throat behind it and warm lantern light spilling out: lantern amber `#FFC46B` from the player's own cove, lantern warm white `#FFF1DC` from everyone else's (section 4.5). The mouth carries the owner's name on the Name Shell and the best specimen in the Trophy Bubble beside it (canon section 6). Inside: an oval chamber 76 wide, 110 long and 44 high, with 40 specimen perches along both side walls (four rows of five per side; the top row is for the Bigger Cove pass) like a display shelf, and a sandy centre. Sizes are chapter 03's (sections 6.7 and 6.10). Warm stone, warm light: the only warm-lit places in the sea.

**Currents** are streams of white-aqua streak particles and bent sea grass along the path. No arrows, no neon tubes.

### 9.4 The water surface

- A flat mesh sheet at height 0, in 256-stud tiles, with two faces: the top (seen when breaching) and the underside (seen from below). They are separate meshes so each face is single-sided.
- **Underside:** a hand-painted ripple pattern in light aqua and white, 512 × 512, tiling every 64 studs. It animates by swapping 8 painted frames at 8 frames a second **(tune)**.
- **Sun pool:** a soft, bright, round card 96 studs across that follows the camera just under the surface, so the brightest patch is always overhead. This is the cheap version of the bright window a diver sees when looking up.
- **Top side:** flat turquoise with painted foam shapes, a painted sky, and far island cut-outs on the horizon. A breach makes a chunky ring splash (`FX_Splash`), never spray.
- The surface does not move as geometry at MVP. A boned wave sheet is a possible later upgrade [U].

### 9.5 Sense of depth

| Cue | How |
|---|---|
| Fog colour | Shifts from the zone's surface colour to its deep colour with camera depth (section 10.3) |
| View distance | Shorter in the Kelp and the deep Drop-off (section 10.2) |
| Value stacking | Near things keep full contrast; fog flattens far things to a silhouette in one value. Kit pieces are built to read as silhouettes. |
| Floating motes | `FX_MarineSnow`: slow particles near the camera that slide past as it moves. Denser with depth. |
| Light shafts | `FX_GodRay` beams from the surface, strongest in the top 80 studs, gone below 200 |
| Floor light | Moving light pattern on sand above 60 studs depth only (section 10.4) |
| Size | Something big and far in most views: a landmark, a cliff, the surface |
| Surface glow | Looking up always shows a lighter band, even at 500 studs |

### 9.6 Landmarks

Chapter 03, section 6 owns every landmark: its name, key letter, position and size. Chapter 07 lists the meshes. This section gives the art brief for the main steering mark of each zone, the one that must read as a silhouette from 300 studs (or from the zone's view distance, where that is shorter) so a player can steer home without a map. The other landmarks in chapter 03 follow the same rules.

| Zone | Landmark (chapter 03 name) | Shape | Colour hook |
|---|---|---|---|
| Nursery Lagoon | **Little Arch** | A pink coral arch, opening 50 wide and 22 high, with a row of small shell lights. The only way in or out, visible from everywhere in the pool. | Pastel coral pink from the Nursery kit; soft white shell lights |
| Sunlit Reef | **Noggin Rock** | A giant brain-coral dome at the exact centre, 70 across and 44 tall, with the Noggin Tube eel hole through it. Visible within fog range (section 10.2). | Coral pink `#FF7F9F` |
| Kelp Forest | **Old Anchor** | A huge anchor 60 tall with a chain rising to a buoy at the surface: a pole that shows above the canopy | Rust `#B86A5A` |
| Kelp Forest | **The Tall Stand** | The densest, tallest kelp in the forest, a stand 140 in radius | Yellow-green `#C9E06B` leaf tips (below signal saturation) |
| The Drop-off | **The Tin Pickle** | A small, toy-like sunken tugboat, hull 90 long, 30 wide and 40 tall, lying on a rock shelf that sticks out of the Wall, with its name on the bow, a smokestack and a hull breach on one side | Pickle green `#7A9A4A` **(tune)**, kept below signal saturation, with rust patches; cyan spark flickers inside from [L] |
| The Drop-off | **Whale's Rest** | A flat bowl of pale sand, 80 in radius, on the Deep Floor, with a few old bones at [MVP]. The Whale Fall skeleton lands here [L]. | Bone white `#F3ECD8` |

Landmark rules: one simple outer shape (arch, dome, pole, wedge, bowl); at least 40 studs in one dimension; no other object in the zone shares its shape.

---

## 10. Lighting and atmosphere

### 10.1 Technology and fixed settings

| Setting | Value | Reason |
|---|---|---|
| `LightingStyle` | Realistic | "Soft" is described as "a flat, retro-Roblox look" [V], which we must avoid. We flatten the light ourselves with strong ambient colour. A/B both in the lighting spike. |
| `PrioritizeLightingQuality` | true **(tune)** | Fog already limits view distance, so spend the budget near the camera. With Realistic, this pair is what the old `Technology = Future` was: the most expensive lighting Roblox has (section 2.4). **Gate:** it must hold 30 fps on the low Android phone (chapter 15, section 8, test row 1) in the lighting spike. **Fallback:** `LightingStyle = Soft` with prioritise on (the old ShadowMap), with our ambient and painted light carrying the look. |
| `Technology` | Not set | Retired by Roblox in favour of the two properties above (section 2.4), and scripts cannot even read it (spike S0-A5, F22). The setting is one value for the whole place; it cannot differ per device (chapter 15, section 3.0). |
| `GlobalShadows` | true | Only landmarks, cliffs and floor chunks cast. Creatures, prey, kelp and props have `CastShadow` off. Shadows vanish below quality level 4 [V] and are switched off on the Smooth tier (chapter 15), so nothing may depend on them. |
| `ShadowSoftness` | 0.8 **(tune)** | Soft, toy-like |
| `EnvironmentDiffuseScale`, `EnvironmentSpecularScale` | 0 and 0 | Ambient comes from our colours, and nothing reflects the sky |
| `GeographicLatitude` | 15 **(tune)** | Sun almost overhead with a slight slant so forms show a light side |
| `ClockTime` | 13.0 by day; 0.0 in Moon Tide | Time does not pass. Only tide events change it. |
| Sky | A custom painted skybox: a vertical gradient per the surface row in 4.2. No stars, no stock sun or moon textures. | |
| `ColorGradingEffect.TonemapperPreset` | Default [V] | Vivid |

`LightingStyle` and `PrioritizeLightingQuality` are set in the project file or by the build step, never by game scripts at run time (spike S0-A5, F22). All other lighting changes are made on the client, per player, from the camera's zone and depth.

### 10.2 Starting values per zone

**Fog decision.** We use the legacy fog: `FogStart`, `FogEnd` and `FogColor`, with `FogStart` at 25% of each zone's **target view distance** and `FogColor` the zone's fog colour (section 4.2, the same as the Atm. Color column below). It was planned as the fallback; the lighting spike measured that the Atmosphere presets below never hid a white 8-stud ball by 600 studs (Nursery contrast 0.04 at 600), while legacy fog hit its caps exactly (contrast 0.003 at 220 studs, 0.008 at 350) (spike S0-A5, F21). Fog properties are hidden while Lighting contains an `Atmosphere` [V], so the presets carry none while fog is in use. Until then, Atmosphere values given elsewhere in this chapter (sections 10.3 and 10.6) act on the fog: their `Color` becomes `FogColor`; their Density changes are set by eye as a shorter `FogEnd` **(tune)**. **Open:** isolate why Atmosphere Density 0.45 to 0.80 changed nothing. If a fixed Atmosphere hits the targets, it comes back for its two-colour fade into the sky gradient (`Color` near the sun, `Decay` away from it). The Atmosphere columns below are kept for that follow-up. A target view distance is calibrated by placing a white 8-stud ball and reading the distance where it disappears.

Ranges for these properties are not on the documentation pages [U]. Values are first guesses to be set by eye in Studio: all **(tune)**.

| Preset | Brightness | Ambient | OutdoorAmbient | ColorShift_Top | Exposure | Atm. Density | Atm. Offset | Atm. Haze | Atm. Glare | Atm. Color | Atm. Decay | Target view distance (studs) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Nursery Lagoon | 2.2 | `#8FD3D6` | `#B8ECEC` | `#FFF3C4` | 0.10 | 0.32 | 0.10 | 2.0 | 0.4 | `#4CCFD2` | `#BFF5E8` | 450 |
| Sunlit Reef | 2.0 | `#6FB6D9` | `#9ED8F0` | `#FFF0B8` | 0.00 | 0.36 | 0.10 | 2.2 | 0.3 | `#1E9FD0` | `#7FE0E8` | 400 |
| Kelp Forest | 1.4 | `#4F9E88` | `#7CCBA8` | `#E6FFB0` | −0.10 | 0.45 | 0.05 | 2.6 | 0.2 | `#238A72` | `#A6E08A` | 260 |
| Drop-off, upper | 1.2 | `#3F6FB8` | `#5C93D9` | `#BFE3FF` | −0.20 | 0.42 | 0.05 | 2.4 | 0.1 | `#1B6FBF` | `#3FA3E0` | 320 |
| Drop-off, deep | 0.6 | `#2F4A8C` | `#3A5FA8` | `#8FB8FF` | −0.40 | 0.52 | 0.00 | 2.8 | 0.0 | `#0B2A66` | `#1B4FA0` | 200 |
| Cove interior | 1.0 | `#7A8FB0` | `#A8C4D9` | `#FFD9A0` | 0.10 | 0.25 | 0.10 | 1.2 | 0.0 | `#3E8FA8` | `#FFD9A0` | 300 |
| Above the surface | 3.0 | `#9FB8D9` | `#CFE6FF` | `#FFF6D9` | 0.00 | 0.28 | 0.25 | 1.6 | 1.0 | `#BFE9FF` | `#FFE6B8` | 1,500 |
| The Trench [P2] | 0.3 | `#30408A` | `#3A4FA0` | `#6F7FFF` | −0.50 | 0.58 | 0.00 | 3.0 | 0.0 | `#060F33` | `#1A0F45` | 150 |

**View distance caps by graphics tier.** The distances above are the authored look, seen on the Pretty tier. Chapter 15, section 3.0 caps the underwater view distance at **220 studs on Smooth** and **350 on Balanced** **(tune)**, because the engine draws only about 200 studs on weak Android phones today, and its cut order can pull a struggling phone in to 160. The client applies the cap by raising the fog; the colours do not change. So most players on phones see the Nursery (authored 450), the Reef (400) and the upper Drop-off (320) at 220: these three presets are judged at 220 first and at their authored distance second (a check added to the lighting spike, section 18.2). One known clash: chapter 03 wants Noggin Rock visible from every cove mouth, which is 400 studs away and so beyond the cap on Smooth and Balanced (section 18.3).

Post-processing, the same in every zone unless an event changes it. These are the full values; chapter 15, section 3.0 says which tier lowers or drops each one (bloom is weaker on Smooth; sun rays are Pretty only; depth of field and menu blur are off on Smooth).

| Effect | Property | Value | Note |
|---|---|---|---|
| ColorCorrection | Brightness | 0.02 | |
| | Contrast | 0.08 | |
| | Saturation | 0.12 | The toy-box push. More than 0.2 turns the signals neon-on-neon. |
| | TintColor | `#FFFFFF` | Zones tint through fog and ambient, not here |
| Bloom | Intensity | 0.6 | |
| | Size | 24 | |
| | Threshold | 0.95 | Only glow traits, lanterns, outlines and sparkles should bloom. If the threshold scale differs in Studio [U], set it so a `#FFE2A8` belly does not bloom. |
| DepthOfField | — | **Off during play** | Blur hides food and danger. On only in the cove inspect view and the photo view: FocusDistance = distance to the specimen, InFocusRadius 12, FarIntensity 0.35, NearIntensity 0. May differ on weak devices [V]. |
| SunRays | Intensity 0.08, Spread 0.6 | On only within 40 studs of the surface | A bonus. May not render on weak devices [V]. Light shafts come from beams instead. |
| Blur | Size 12 | Behind full-screen menus only | |

### 10.3 Blending by position

- The client keeps a **current preset** and blends toward the preset of the camera's zone over 1.5 seconds.
- In the Drop-off, the blend between "upper" and "deep" follows camera depth: 0% at 150 studs down, 100% at 300.
- Inside any zone, the fog colour (`Atmosphere.Color` if the Atmosphere returns) moves toward the surface band colour when the camera is within 30 studs of the surface.
- A local `PointLight` (range 40, brightness 0.6, colour `#CFE6FF`) follows the player's creature whenever the fog L\* is under 35, so the area around the player never goes black.
- **Darkness floor:** no preset may bring `Ambient` below L\* 30. Dark zones are dark blue, not black.

### 10.4 Fake caustics and light shafts

Roblox has no light textures and, as far as the research could confirm, no custom shaders.

| Effect | Method | Limits |
|---|---|---|
| **Light shafts** (`FX_GodRay`) | `Beam` objects from the surface downward: narrow at the top (6 studs), wide at the bottom (22 studs), 80 to 160 studs long, a soft streak texture, additive (`LightEmission` 1), transparency fading to nothing at both ends, slow texture scroll. Placed by hand at canopy gaps, arches and landmarks, plus 4 that follow the camera at random offsets. | At most 12 visible on the Smooth tier; chapter 15, section 3.0 has the count for each tier |
| **Caustics on the floor** | A thin "caustic shell" mesh lying 0.1 studs above sand chunks and flat reef tops, with top-down UVs tiling every 32 studs, showing a white web pattern at 0.75 transparency. 16 painted or Blender-rendered frames at 256 × 256, swapped at 12 a second. | Only in the Nursery and Reef, only above 60 studs depth, only within 150 studs of the camera. Off on the Smooth tier and drawn to a shorter distance on Balanced (chapter 15, section 3.0). Swapping a decal texture every frame is [U] for cost. |
| **Caustics on creatures** | None. The painted light on the back does the job. | |
| **Sun pool** | Section 9.4 | 1 |
| **Glow** | Emissive overlays over the bloom threshold (fallback: small `Neon` glow caps, section 5.1), plus at most one `PointLight` per creature | At most 8 creature lights within view on the Smooth tier, nearest first; chapter 15, section 3.0 has the count for each tier |

### 10.5 What survives on a weak phone

The look is designed for the worst case, then improved.

| Feature | Lowest quality | What carries the look instead |
|---|---|---|
| Shadows | Gone below level 4 [V] | Painted occlusion, tints, contact blobs under cove specimens |
| Depth of field, sun rays | May not draw [V] | Not used for play |
| Flipbooks | Turned off on low-memory phones [V] | Every effect must still read as a single frame |
| Bloom | [U] | Signals are bright colours on their own; bloom only adds polish |
| Outlines | Our own shells (section 13.2), not `Highlight` | Always present |
| Fog, ambient, textures, tints | Present | These are the style |

### 10.6 Tide events

Events blend in over 3 seconds. During the 60-second warning, the event look is shown at 30% strength, pulsing slowly, so the sea itself gives the warning.

| Event | Scope | Change from the zone preset |
|---|---|---|
| **Feeding Frenzy** (`frenzy`) | [MVP] | Brightness +0.2. Fog colour moves 15% toward `#6FDDEE`. ColorCorrection Saturation 0.25, TintColor `#FFF1CC`. Bloom Intensity 0.8. Plankton motes sparkle gold-white. Light shafts double in number. Feels like midday at a fairground. |
| **Moon Tide** (`moon_tide`) | [MVP] | See below |
| **Whale Fall** (`whale_fall`) | [L] | Within 300 studs of the whale skeleton only: Atmosphere Density +0.06, Color `#25566B`, Saturation 0.00, a single wide pale shaft over the skeleton, heavy `FX_MarineSnow`. The skeleton is clean bone-white and cream; the Marrow chunks are cream-white with a soft white glow (chapter 03, section 7.3). No flesh, no red, no pink. |

**The gulped look (`LGT_Gulped`).** Over the zone preset, on the gulped player's screen only, starting at the gulp: ColorCorrection Saturation −0.6 (from the zone's 0.12), Brightness −0.08, TintColor `#D6DCE8`; bloom, fog and lighting unchanged **(tune)**. It blends in over 0.3 s, matching the 300 ms in which the gulped panel's screen edges lose colour (08 §4.4), and back to the zone preset over 0.2 s: chapter 07's half second in all. Derived from 08 §4.4's colour loss and the "dim and desaturate" of chapter 07; the Whale Fall's Saturation 0.00 above is the nearest existing grey look, and the gulped one goes further so it reads as a moment, not a place.

**The night look for Moon Tide.** "The sea goes dark and glows."

| Property | Value **(tune)** |
|---|---|
| ClockTime | 0.0 (moon overhead) |
| Brightness | 0.5 |
| Ambient / OutdoorAmbient | `#33448C` / `#3A4FA0` (L\* 31 and 36: dark, never black) |
| ColorShift_Top | `#B8C8FF` |
| Exposure | 0.20 |
| Atmosphere | Density 0.40, Haze 2.0, Glare 0.3, Color `#0A1440`, Decay `#2A2A80` |
| Target view distance | 220 studs in every zone |
| ColorCorrection | Contrast 0.15, Saturation 0.15, TintColor `#D6DCFF` |
| Bloom | Intensity 1.2, Size 32, Threshold 0.85 |
| Light shafts | Replaced by 6 thin silver moon shafts, `#D9D6FF` |

What glows, in two colours only (cyan `#7DF9FF` and silver-lavender `#D9D6FF`):

- Coral tips, kelp leaf edges and sponge rims, through emissive masks or small `Neon` caps. Each kit piece has a "night" variant of its tint; no new meshes.
- Plankton turns cyan and brightens; a creature leaves a short cyan sparkle trail when it dashes.
- Every creature's eyes get a soft emissive ring.
- `lunar_fry` are the brightest things in the sea: silver bodies with a small `PointLight`, visible from 220 studs.
- Cove mouths stay lit: the player's own in lantern amber, the others in lantern warm white (section 4.5). In the dark they are the only warm lights and only one of them is amber, so home is easier to find at night than by day.

Signals at night: outlines stay at full brightness and gain the most contrast of any condition (lime 14 : 1 and red 5 : 1 against the night fog). The darkness must never hide a creature that can eat the player: anything red-outlined within 120 studs also shows its eyes as two emissive dots.

---

## 11. Visual effects

### 11.1 Style rules

1. **Chunky and graphic.** A bubble is a ring with one highlight dot. A star has four fat points. A splash is three teardrops and a ring. No realistic smoke, sparks or spray.
2. **Few, big, short.** Fewer than 20 particles for most effects, each large, lasting under a second.
3. **Palette only.** Effect colours come from section 4. An effect on a creature uses that creature's light colour and white.
4. **Additive only for light** (glow, spark, sparkle, light shafts). Everything else is normal blending, so it stays visible on bright water.
5. **Timing matches animation.** Bursts fire on the action frame, expand fast (2 to 3 frames) and fade slowly.
6. **No effect may use the signal colours** except those that carry the signal (the eat pop is lime-white; the warning chevron is red).
7. **Each effect has a still fallback:** it must read with flipbooks off (section 10.5).
8. **Size follows body scale.** Particle size and speed multiply by the creature's scale; count does not.

### 11.2 Effects and budgets

Counts are live particles at the peak, on a phone. All **(tune)**.

| Effect | What it shows | Build | Peak particles | Lifetime |
|---|---|---|---|---|
| `FX_BubbleTrail` | Movement, wake at tier 5 and up | 1 emitter, ring bubbles rising | 8 | 0.8 s |
| `FX_BiteChomp` | A bite landed | Burst: 5 bubbles, 1 lime-white "pop" star (4 × 4 flipbook, 512) | 6 | 0.3 s |
| `FX_GulpPop` | A creature was gulped | Burst: 12 bubbles, 1 spinning star, 1 ring | 14 | 0.5 s |
| `FX_TierUp_T2` to `_T7` | Tier-up, one effect per tier reached (chapter 07) | Burst: ring shockwave, 10 four-point stars in the species' light colour, 8 bubbles; a 0.2 s white flash on the body | 20 at tiers 2 and 3, rising to 60 at tier 7 | 0.6 s |
| `FX_DashTrail` | Dash | A `Trail` from the tail (white to clear, 0.25 s), plus 4 streak particles | 4, plus the trail | 0.25 s |
| `FX_InkCloud` | Ink trait, Squid Jet | 8 large soft blobs in `#2A1F3D`, growing from 3 to 9 studs, plus 4 small curls | 12 | 3.0 s (canon) |
| `FX_SparkArc` | Spark trait | 3 short zigzag `Beam`s that jump every 2 frames for 6 frames, plus 6 dot sparks | 6, plus beams | 0.2 s |
| `FX_BankSwirl` | Banking | A spiral of 12 amber motes and a pearl burst | 16 | 0.8 s |
| `FX_Glint` | A far creature (LOD "Glint") | 1 billboard dot, twinkling | 1 each | — |
| `FX_MarineSnow` | Depth | 1 emitter fixed to the camera | 40 (60 in the deep Drop-off) | 4 s |
| `FX_GodRay` | Light shafts | Beams (section 10.4) | 0 | — |
| `FX_Current` | A current stream | Streak particles along the path | 24 per visible stream | 1.5 s |
| `FX_VentPlume` | `vent` [L], while `Erupting` | Wobbling column 10 studs wide and 40 tall, rising from the chimney top: 10 orange-white blobs, heat-shimmer is not possible so the blobs wobble instead. Chapter 03, section 5.1 owns the rule: nine vents at the Chimneys, the three at the centre always erupting and the six outer ones cycling (3 s on, 5 s off) | 12 per vent | 1.2 s |
| `FX_VentRumble` | `vent` [L], the 1 s `Rumble` warning before a cycling vent erupts | The rim glow brightens and a burst of small bubbles rises from the chimney top | 8 | 1 s |
| `FX_Splash` | Breaching the surface | Burst: 1 ring, 6 teardrops | 7 | 0.5 s |
| `FX_GullShadow` | `gull` warning (1.5 s, canon) | A dark oval decal on the surface that shrinks and darkens; no particles | 0 | 1.5 s |
| `FX_TraitSparkle` | Trait prey marker | 2 small sparkles in the rarity colour | 2 each | 0.6 s |
| `FX_Stun` | Stunned | 3 stars circling the head | 3 | loop |

### 11.3 Flipbooks made in Blender

| Setting | Value |
|---|---|
| Source | A small Blender scene per effect: animated shapes or a simple simulation, rendered flat (emission shader, orthographic camera, transparent background) so it looks drawn |
| Grid | 4 × 4 (16 frames) on 512 × 512 as the default; 8 × 8 on 1024 × 1024 allowed for the tier-up effects and `FX_InkCloud` only (chapter 07 currently ships both at 512) |
| Frame rate | 16 to 24 a second; the engine limit is 30 [V] |
| Gutter | 4 pixels of empty space inside every cell [V: "include spacing"] |
| Texture size | An exact multiple of the grid [V] |
| Colour | Greyscale with alpha where possible, coloured by the emitter, so one sheet serves many effects |
| Assembly | The preview script packs frames into the sheet with Pillow |

### 11.4 Limits for phones

**Chapter 15, section 3.0 owns the counts per graphics tier** (Smooth, Balanced, Pretty): live particles, active particle emitters, far-prey emitters, light shafts, trails and creature point lights. This chapter does not repeat that table. Effects are designed against its Smooth column (400 live particles, 40 active emitters, 12 light shafts, 12 trails, 8 creature point lights at the time of writing; if the numbers differ, chapter 15 wins).

The limits below are art rules for a single effect. Chapter 15 does not carry them.

| Limit | Smooth and Balanced | Pretty |
|---|---|---|
| Rate of any one emitter | 30 a second (the engine caps mobile at 100 [V]) | 100 |
| Largest particle on screen | 25% of screen height (ink only: 40%) | same |
| Beams visible other than light shafts | 6 | 12 |

When over budget, the client drops effects in this order: marine snow, bubble trails of other players, trait sparkles, light shafts. It never drops bite, gulp, tier-up, ink or gull-shadow effects, because they carry gameplay. Chapter 15's cut order for a struggling phone keeps the same never-cut list.

---

## 12. Interface art direction

Document 08 owns layouts and flows. This section owns the look.

### 12.1 The look in one line

Cut-out paper and painted wood toys: cream panels with a thick navy outline, a hard offset shadow, slightly uneven edges, and bouncy motion.

### 12.2 Shapes, corners, strokes

Values are in pixels on a 1920 × 1080 reference and scale with the screen.

| Element | Rule |
|---|---|
| Panels | 9-slice images with hand-cut, slightly irregular edges; corner radius about 28. Never a plain `Frame` with a perfect `UICorner`. |
| Buttons | Pill or rounded rectangle, radius 22 to 50% of height. A 6-pixel darker "lip" at the bottom gives thickness. |
| Stroke | 5 pixels navy `#14213D` on panels and buttons, 4 on icons, 3 on small chips. Round joins [V: `UIStroke.LineJoinMode`]. |
| Shadow | Hard, no blur: offset 0, 8; `#0B1530` at 35%. Painted into the 9-slice, or `UIShadow` with blur 0 [V]. |
| Tilt | Titles and badges tilt 2° to 4°. Nothing sits on a perfect grid except lists. |
| Dividers | Hand-drawn wavy lines, never 1-pixel rules |
| Bars (mass to next tier, cooldowns) | Fat, 28 pixels high, rounded ends, navy stroke, a lighter "shine" strip on top. Here `UICorner` is correct. |
| Touch targets | Chapter 08 owns interface sizes, on its own 1280 × 720 canvas in reference pixels (rpx): a hit area of 88 × 88 rpx at least, the Dash button 136 × 136 rpx and the Ability button 108 × 108 rpx |
| Transparency | Panels are opaque. The in-run heads-up display uses no panels at all: icons and numbers sit directly on the water with a navy stroke. |

### 12.3 Type

Roblox's built-in font list was checked on the [Font datatype page](https://create.roblox.com/docs/reference/engine/datatypes/Font.md) [V]. It includes Fredoka One, Nunito, Luckiest Guy, Bangers, Montserrat and Builder Sans. It does not include Baloo, Lilita, Rubik, Poppins or Quicksand. The page does not list weights [U].

| Use | Font | Notes |
|---|---|---|
| Titles, buttons, big numbers, tier names | **Fredoka One** | Round, fat, friendly. One weight. Always with a navy `UIStroke`. |
| Body text, descriptions, small labels | **Nunito**, ExtraBold or Bold | Rounded and very legible small. Check available weights in Studio; if only Regular and Bold exist, use Bold. |
| Never | Builder Sans, Gotham, Source Sans, Arial | These are the default Roblox voice |

Sizes are chapter 08's, in its reference pixels (rpx) on a 1280 × 720 canvas: Small 22 (the floor), Body 24, Number 28, Title 40, Hero 64. On a phone nothing renders under 13 points. Numbers that change (mass, Pearls) pop to 120% for 4 frames when they rise.

### 12.4 Icons

- One style: a fat navy outline (4 pixels at 128), two flat tones, one white highlight blob, no gradients finer than two steps.
- **Creature, prey and trait icons are renders of the real models** from Blender with the preview script's flat light and an outline pass, never separate drawings. The icon and the thing in the water always match.
- Icon canvas 256 × 256, the subject filling 80%, facing right, tilted 15° toward the viewer.
- Trait icons sit on a rounded shield in the rarity colour with rarity pips beneath.
- Currency: a pearl (cream-pink, one glint). Bubbles: a ring bubble with a heart-shaped glint.
- No emoji in the interface. (The store title keeps its fish, per canon.)

### 12.5 Motion

At 60 frames a second in the interface.

| Motion | Timing |
|---|---|
| Panel opens | 0.18 s: scale 0.8 → 1.06 → 1.0, back-out ease; the dim fades in over 0.12 s |
| Panel closes | 0.10 s: scale 1.0 → 0.9 and fade |
| Button press | Down: scale 0.92 and drop 4 pixels in 0.05 s. Up: 1.06 → 1.0 in 0.12 s. |
| List items appear | Staggered 0.03 s apart, each sliding up 20 pixels |
| Reward (Pearls, new Codex entry) | Icon pops to 130%, then flies along an arc to its counter in 0.4 s; the counter bumps |
| Tier-up banner | Slams in from 160% to 100% in 0.12 s, holds 0.8 s, shrinks into the tier badge |
| Danger | A red vignette of soft painted wave shapes pulses at the screen edge with the chevron. Never a flat red overlay. |
| Idle | Primary buttons breathe: scale 1.0 ↔ 1.03 every 1.6 s. Nothing else moves at rest. |

Every motion has a reduced version (fade only) for a "reduce motion" setting.

### 12.6 How it avoids looking like default Roblox

| Default Roblox | GULP |
|---|---|
| Grey see-through black panels | Opaque cream cut-outs with navy outlines |
| Thin white sans-serif text | Fat rounded type with a stroke |
| Square frames, 1-pixel borders | Hand-cut 9-slice shapes, hard shadows |
| Avatar headshots | Creature renders; the avatar is never shown (canon section 1) |
| Stock leaderboard, backpack, health bar, emote menu | Switched off with `SetCoreGuiEnabled` and replaced (document 08) |
| Stock loading screen | A painted GULP screen with a creature swimming a loop. Removing the stock screen is [U] in the research notes. |
| Stock proximity prompts and chat bubbles | Not used in the world |
| Robux-green buy buttons | Sun-yellow buttons with a Robux icon |

Roblox reserves some interface that cannot be removed (the menu button and system menu). The art leaves the top-left corner clear for it.

---

## 13. Readability on a phone

Reference frame: a phone held sideways, 844 × 390 points.

### 13.1 Sizes

| Thing | Rule |
|---|---|
| The player's creature | 12% to 16% of screen height long (47 to 62 points). The camera pulls back as the creature grows to hold this. Document 09 owns the camera; this is the art requirement. |
| Smallest size at which a creature must be recognisable by species | 20 points long |
| Smallest size at which food or danger must be clear | 8 points: by then it is a glint in its outline colour |
| Smallest prey dimension in the world | 0.4 studs |
| A predator about to strike | Never under 40 points when it enters its attack range; if it would be, its chevron shows instead |
| Text | Never under 13 points |

### 13.2 Outlines

Outlines are **our own meshes**, not Roblox `Highlight`: a `Highlight`'s thickness cannot be set [V] and its outline may not draw on phones [F].

| Rule | Value |
|---|---|
| Method | An **outline shell**: a copy of the mesh, pushed out along its normals, with its faces flipped so only the back faces show around the edge. Skinned to the same bones. One colour, set per viewer on the client. Hidden when the creature has no outline. |
| Shell thickness, players and predators | 6% of body height **(tune)**; at least 0.12 studs |
| Shell thickness, prey | 10% of body height (small things need a fatter line) |
| "Can eat you" | 1.5× thicker and pulsing to white. The thicker shell is a second export, `_ShellThick`, made for predators and for both forms of every player species, juvenile and adult: a tier 3 juvenile can eat a tier 2 player (canon sections 5.2 and 16) |
| Target on screen | 2 to 3 points wide at normal play distance; never under 1.5 |
| Material | The built-in `Neon`, so fog and darkness do not dim it **(tune)**. This is one of the two uses of `Neon` that canon section 13 allows (section 5.1). Fallback: a matte shell with `CastShadow` off and the colour brightened. |
| Shell triangles | About 40% of the body's; tier-1 prey shells and prey LOD2 shells get more so the line stays even (section 6.3) |
| Who gets a shell | Every creature with a tier of 1 or more. `plankton` has no shell and no outline, and neither does `hook` bait (canon section 5.2); the other hazards have none either (section 6.3). |
| How many at once | Capped per graphics tier, nearest first: 12 on Smooth (8 edible, 4 dangerous). Chapter 15, section 3.0 owns the counts. |
| Far away | Under 8 points the shell is replaced by a glint in the outline colour |
| The player's own creature | No outline. It is found by position: always at the centre. |

Flipped back faces draw as an outline on a skinned `MeshPart`: measured in Mac Studio by the rig spike (Sprint 0, `docs/spike-report.md`). If it fails, the fallback is a billboard ring behind each creature in the outline colour.

### 13.3 Contrast against water

- The water contrast rule (section 4.1) is checked by script against the fog colours in section 4.2 for every zone where the creature can appear.
- Creatures are lit to the same brightness everywhere: a creature may not fall below 60% of its texture's brightness in any preset. If a preset fails, raise `Ambient`, do not darken the texture.
- Every creature has a light belly and a dark fin edge, so one of the two always separates from the water behind it.
- Schools read as one shape. `sardine` schools turn together and flash their light flanks; that flash is the cue.
- Camouflage is a gameplay trait (`camo`). No other creature may blend into its background.

### 13.4 Dark zones

| Problem | Answer |
|---|---|
| Deep Drop-off and Moon Tide dim the bodies | Darkness floor on `Ambient` (L\* 30), plus the local follow light (section 10.3) |
| Dark predators against dark water | Outlines are `Neon` and do not dim; red-outlined creatures within 120 studs show glowing eye dots; `old_scar` has a pale belly and a pale scar |
| Cool prey (`bonito`, `tuna`) against blue | Their flank is silver (L\* 94 or more), 60 points above the fog, and it is the block the player sees side-on |
| Hazards | `jelly_bloom` pulses with a soft inner glow; `vent` glows orange at the chimney top, brighter during its `Rumble` warning |
| Finding home | Cove mouths are the only warm lights, and the player's own is the only amber one |

---

## 14. Performance budgets tied to art

These are **our starting budgets**, to be replaced by measurements on real phones. Roblox publishes no such numbers on the pages read [U].

### 14.1 Frame budgets

**One table, owned by chapter 15.** The per-device graphics tiers (Smooth, Balanced and Pretty, the same as Low, Mid and High in document 09) are in chapter 15, section 3.0: triangles in view, draw calls, prey drawn as meshes, prey visible in total, fully animated rigs, skinned creatures at LOD0 or LOD1, outlined objects, particles, emitters, trails, creature lights, fog caps, script time and the client memory ceiling. This chapter keeps no second copy. It owns the budget **per asset** (sections 5.6 and 6.3) and the art-only frame budgets below, which chapter 15 does not carry.

Two numbers from that table drive the art, quoted here only so section 14.2 can be checked (chapter 15 wins if they change): on **Smooth**, 150,000 triangles in view and 250 draw calls. The table also keeps two prey rows apart, and so does the art: **prey drawn as meshes** (80 on Smooth) and **prey visible in total**, including particle clusters and glints (250 on Smooth). Likewise **fully animated rigs** (8 on Smooth) are a smaller set than **skinned creatures at LOD0 or LOD1** (30 on Smooth).

| Art budget | Smooth | Balanced | Pretty |
|---|---|---|---|
| Art texture memory (worked out as uncompressed, with mipmaps) | 150 MB | 220 MB | 400 MB |
| Unique textures loaded | 120 | 160 | 250 |
| Dynamic lights in view, all kinds | 10 | 16 | 32 |
| See-through layers over any pixel | 3 | 4 | 6 |

### 14.2 A typical busy frame against the Smooth budget

Worked out with the Smooth rules of chapter 15, section 3.0: other players at LOD1 at best, 12 outlined objects, 80 prey meshes, view capped at 220 studs, caustic shells off.

| Content | Count | Triangles |
|---|---|---|
| Players in view: your own adult at LOD0, nine others at LOD1 | 10 | 19,000 |
| Shells on the outlined objects: 4 dangerous (thick shells, counted at adult size), 8 edible prey | 12 | 8,500 |
| Predators | 3 | 9,000 |
| Prey drawn as meshes, about 150 each | 80 | 12,000 |
| Far prey as glints and particle clusters | 170 | 500 |
| Floor, cliffs, rock inside 220 studs | 10 chunks | 30,000 |
| Coral, kelp, props inside 220 studs | 120 | 44,000 |
| One landmark or set piece | 1 | 8,000 |
| Surface and effects | — | 6,000 |
| **Total** | | **137,000** |

That leaves 13,000 triangles of headroom under 150,000 **(tune)**. Scenery is 60% of the frame, so it is the first thing to thin if the phone spike (section 18.2) measures over. The working limit for zone assembly is about 120 kit pieces in any one view at 220 studs.

### 14.3 Rules that keep the budgets

- **One skinned mesh per creature**, plus its shell and kit pieces. Skinned meshes in a model without a Humanoid are re-clustered as they move [V], so many small parts per creature would be costly. This is flagged for document 09, which decides the character model.
- **Never resize a skinned mesh every frame** [V]. Squash and stretch moves bones (section 7.5).
- **Instance, do not vary.** Copies of a kit piece share mesh and texture exactly; variety comes from rotation, scale and tint.
- **Atlases.** One texture per zone kit, one for small prey, one for trait pieces.
- **No double-sided meshes** [V] and no see-through textures on large surfaces. See-through is for jellies, fins with `longfin`, the surface and effects.
- **Prefer 256 and 512.** A 1024 costs four 512s [V]. The complete list of 1024 textures: at [MVP], three in the world (`T_OldScar_Alb`, `T_EnvWreck_Alb` for the Tin Pickle, `T_Reef_NogginRock_Alb`), at most two effect flipbooks (section 11.3), and the interface atlas sheets, whose count chapter 08 owns (six at [MVP], section 13.13); at [L], `T_WhaleFall_Alb` is added. Eleven at most at [MVP] is about 62 MB of the 150 MB Smooth texture budget. Any other 1024 needs a line here first.
- **Lights are rationed** (section 11.4).

---

## 15. Blender pipeline

### 15.1 Tools

Blender 5.2 at `/Applications/Blender.app`, run headless by scripts. Python with Pillow for contact sheets. No more than two Blender jobs at once on the development Mac.

### 15.2 Folder layout

```
assets/
  palette/
    gulp_palette.json        every colour in section 4, by name
    gulp_palette.gpl         the same for paint programs
  blender/
    _template/gulp_template.blend
    _lib/                    shared Python: build, validate, bake, export, preview, sheet
    species/<id>/            <id>.blend, build.py, notes.md
    prey/<id>/
    pred/<id>/
    hazard/<id>/
    env/<zone>/<piece>/
    cove/<piece>/
    prop/<piece>/
    traits/<trait>/
    fx/<name>/               flipbook scenes
    ui/icons/
  textures/
    src/                     layered paint files
    out/                     T_*.png, exported
  export/
    Species/ Prey/ Pred/ Hazard/ Env/ Cove/ Prop/ Trait/     M_*.fbx and A_*.fbx
  review/
    <asset>/<date>_sheet.png      contact sheets
    <asset>/<date>_verdict.md     reviewer's verdict
  refs/                      reference images, with sources
```

Folder names under `export/` match the canon categories.

### 15.3 Scene template

| Setting | Value |
|---|---|
| Units | None; 1 unit = 1 stud |
| Frame rate | 30 |
| Colour management | View transform Standard, look None, sRGB display |
| Collections | `GEO` (game mesh), `RIG`, `SHELL`, `LOD`, `SOCKETS`, `HIGH` (optional bake source), `PREVIEW` (lights, cameras, backdrops) |
| Preview lights | One soft key from above-front (`#FFF6D9`), ambient at the Sunlit Reef colour. No shadows, to match the weakest phone. |
| Backdrops | Six flat cards in the fog colours of section 4.2 |
| Cameras | Side, three-quarter, game camera (behind and 25° above), top, front |
| Reference objects | A 4-stud cube, and tier-1 and tier-7 `minnow` silhouettes for scale |

### 15.4 The headless script approach

Every asset has a `build.py`. Running it produces everything from source: nothing in `export/` is edited by hand.

```
/Applications/Blender.app/Contents/MacOS/Blender --background \
  assets/blender/species/minnow/minnow.blend \
  --python assets/blender/_lib/run.py -- --asset minnow --steps validate,bake,export,preview
```

| Step | What it does | Fails the build when |
|---|---|---|
| `build` | For generated assets (rocks, corals, kelp, kit pieces, shells, LODs): creates the mesh from parameters and a fixed random seed. For sculpted assets: loads the .blend. | — |
| `validate` | Counts triangles and bones; checks 4 weights per vertex, no root weights, no weights on sockets, applied transforms, one material, one UV set inside 0 to 1, watertight, no thin faces, naming, origin, facing, size against section 6.2 | Any check fails |
| `palette` | Samples the texture; reports the three value blocks, their L\* and shares; checks the water contrast rule and the reserved colour bands | Reserved colour used, or contrast rule broken |
| `shell` | Builds the outline shell at the right thickness and transfers weights; also builds the thick danger shell `_ShellThick` for predators and for the juvenile and adult form of every player species | — |
| `lod` | Decimates to the LOD targets, keeping silhouette edges and UV seams | A level exceeds its budget |
| `bake` | Occlusion and gradient bakes | — |
| `export` | Writes `M_*.fbx`, one `A_*.fbx` and one clip JSON per action (section 6.7), the socket table of each rig (section 8.4), and `T_*.png` | — |
| `preview` | Renders the contact sheet | — |

An agent that makes or changes an asset edits `build.py` or the .blend, runs the steps, and hands back the validation report and the contact sheet path. The script, not the agent's memory, holds the rules, which is what keeps assets made months apart consistent.

### 15.5 Previews and contact sheets

One image per asset per review, 1536 × 1536, viewed at 768 for review.

| Cell | Content |
|---|---|
| 1 to 4 | Side, three-quarter, game-camera and top views on the Sunlit Reef backdrop |
| 5 | Solid black silhouettes: side and game-camera |
| 6 | Phone sizes: the asset at 96, 48, 20 and 8 pixels long |
| 7 | The asset over all six fog colours, with lime and red outlines |
| 8 | Value check: greyscale, with the three blocks' L\* printed |
| 9 | Line-up beside its nearest look-alikes at equal length |
| 10 to 12 | For rigs: bite, dash stretch and scared poses. For traits: three hard combinations. |
| Footer | Triangles, bones, texture size, validation result, date, script commit |

Extra sheets: the **combination sheet** (every species with 12 trait triples), the **zone sheet** (a kit assembled into a 128-stud scene under that zone's colours), and the **roster sheet** (all creatures at true relative size).

Animations are reviewed as a strip of key poses plus a 2-second, 384-pixel clip.

Reviews are done from the contact sheet by a fresh reviewer who has not seen the build conversation, using section 16.

---

## 16. Quality bar

### 16.1 Reviewer's checklist

An asset is accepted only with every applicable line passed. One failure is a rejection with the line number.

| # | Check | Pass |
|---|---|---|
| 1 | 48-pixel silhouette | Named correctly without colour |
| 2 | Heading | Head and tail obvious from the game camera |
| 3 | Friend or foe | Shape alone says food, neutral or danger (section 3.4) |
| 4 | Line-up | Not confusable with any existing asset |
| 5 | Three values | Exactly three blocks in greyscale, shares within section 4.1 |
| 6 | Water contrast | Passes in every zone where it appears |
| 7 | Reserved colours | None used |
| 8 | Palette | Colours are from section 4, or new ones were added to the palette file with a reason |
| 9 | Painted | No photo texture, no fine noise at 400%, no black shading, gradients large and few |
| 10 | Proportions | Inside the ranges of section 3.3 |
| 11 | Face | Eyes and mouth read at 48 pixels; glint present |
| 12 | Budgets | Triangles, bones, texture size inside sections 5.6 and 6.3 |
| 13 | Technical | Validation step passed; naming correct |
| 14 | Phone | Recognisable at 20 pixels; food or danger clear at 8 |
| 15 | No stock look | Nothing resembles a Roblox part, material, avatar or stock asset. `Neon` appears only on outline shells and small glow caps (section 5.1). |
| 16 | Animation (rigs) | Poses hold; timings inside section 7.2; stretch inside limits; nothing slides |
| 17 | Traits (species) | Sockets present; combination sheet passes rule 7 of section 8.3 |
| 18 | Family likeness | On the roster sheet it looks made by the same hand as its neighbours |

### 16.2 Five common failures and their fixes

| Failure | How it shows | Fix |
|---|---|---|
| **Mush at small size** | The 48-pixel cell is a blob; many small details | Delete the smallest third of the details. Enlarge eyes and fins by 20%. Merge value blocks until there are three. |
| **Realism creep** | Correct anatomy, small eyes, thin fins, natural muted colours | Return to the primary shape in section 3.2. Push head, eyes and fins to the table values. Raise saturation to the palette. |
| **Noisy texture** | Speckle, grain, airbrush haze, shading done with black | Repaint from the greyscale step: flat blocks, two gradients, a few broad marks. Shade toward blue-violet. |
| **Lost in the water** | Blue, teal or green creature vanishes in one zone's cell | Move the largest block's lightness 25 points from that fog, or move the hue 90° away. Add a light belly and a dark fin edge. |
| **Floaty animation** | Even timing, no holds, soft start and stop | Cut in-betweens. Hold poses 3 frames. Add a 2-frame overshoot and a rebound. Check stretch reaches at least 115% on fast moves. |

---

## 17. Do and do not

| Do | Do not |
|---|---|
| Start every asset as a black silhouette | Start with a texture or a detail |
| Use three values and one accent | Add a fourth value "just for the fins" |
| Paint light and wetness into the texture | Use normal maps, metalness or shine to add interest |
| Take every colour from the palette file | Eyeball a new colour inside an asset |
| Keep lime, red and lantern amber for their signals | Make a lime kelp leaf, a red coral or an amber fish |
| Make food round and warm, danger sharp and cool | Make a cute predator or a scary snack |
| Give every creature a tail and a dorsal fin that show heading | Ship a ball with no front |
| Exaggerate: big head, big eyes, huge gape | Copy real proportions |
| Hold strong poses and pop between them | Animate smooth, even, floaty motion |
| Move bones to squash and stretch | Resize skinned meshes every frame |
| Design for the weakest phone first | Rely on shadows, bloom, depth of field, sun rays or flipbooks |
| Use our outline shells | Use Roblox `Highlight` for gameplay signals |
| Build the world from our kit meshes | Use Roblox terrain, terrain water, stock materials, studs or stock parts |
| Keep `Neon` for outline shells and small glow caps | Put `Neon` on a body, a prop, a kit piece or anything large |
| Reuse kit pieces with rotation, scale and tint | Make a unique mesh where a tinted copy would do |
| Keep 60% of each view calm | Fill every surface with coral |
| Show a swallowed creature popping into bubbles | Show blood, wounds, bones of the victim, or anything realistic about eating |
| Keep the cove warm and the sea cool | Put warm lights anywhere that is not home |
| Render icons from the real models | Draw icons that differ from the models |
| Use Fredoka One and Nunito with a navy stroke | Use Builder Sans, Gotham or any thin default type |
| Put the rule in the script | Rely on remembering the rule |
| Take one quality from each reference | Copy a character, design or name |

---

## 18. Open tests and proposed canon changes

### 18.1 What was verified and what was not

Section 2.4 lists every engine fact with its mark and link. In short:

- **Verified on official pages:** the 20,000-triangle and 4-influence limits; watertight and frozen-bone rules; one material and one UV set; texture formats and suggested sizes; the five PBR map types; tinting; importer formats and switches; `Bone.Transform`; `LightingStyle`; shadows off below quality level 4; fog hidden under an Atmosphere; particle and flipbook limits; the `Highlight` limit; batching; the skinned-mesh cost without a Humanoid; the built-in fonts; the interface modifiers.
- **Not verified:** a bone-count limit; the true maximum texture size; ranges and defaults for Atmosphere and post-processing; custom shaders; how each lighting style renders and what it costs on phones and consoles; everything marked [U] in the sections above; any official phone budget.

### 18.2 Spikes to run in Studio before production art starts

| Spike | Questions it answers | Sections that depend on it |
|---|---|---|
| **Calibration** | Does `M_Prop_ScaleCube` arrive at 4 studs facing forward? Which FBX scale factor? Which vertex-colour space? | 6.1, 6.7 |
| **Rig** | Does a flipped-face shell draw as an outline on a skinned mesh? Can code write `Bone.Transform` alongside a playing clip? Does bone spreading stretch cleanly? Can a rigid piece follow a socket bone? What does `Model:ScaleTo` cost? Is 32 bones accepted? | 7.5, 7.6, 8.4, 13.2 |
| **Surface** | Does vertex colour multiply under a `SurfaceAppearance`? Does the flat roughness texture kill the plastic shine? Do emissive masks work on a game mesh? Answered on the Mac: vertex colour does not show under a `SurfaceAppearance` (base colours go in the colour map), flat roughness removes the shine, emissive masks work in Studio; target phones still open (spike S0-A3) | 5.1, 5.3 |
| **Trait** | Overlay option A, B or C? Answered: B, built into the template (spike S0-A4) | 8.4 |
| **Lighting** | **Gate:** does `LightingStyle = Realistic` with `PrioritizeLightingQuality = true` (the old Future) hold 30 fps on the low Android phone (chapter 15, section 8, test row 1)? If not, the game ships on Soft with prioritise on. Atmosphere or legacy fog for the view-distance targets? Answered for now: legacy fog (F21); why Atmosphere Density changed nothing is still open. Do the Nursery, Reef and upper Drop-off looks hold at the 220-stud Smooth cap? Real ranges for every value in 10.2. Cost of beams and of swapped caustic frames on a phone. | 10 |
| **Phone** | Measure the busy frame of 14.2 on a low phone on Smooth and a mid phone on Balanced (chapter 15, section 8, test rows 1 and 3) | 14 |

### 18.3 Proposed canon changes

The canon has adopted this chapter's earlier proposals (the pulsing danger outline, the yellow and hot pink colour-blind pair, no outline on plankton, amber for home, the `Trait` category and mesh suffixes, the Leviathan crest, outlines as mesh shells), so they are no longer listed. Two points that needed a ruling are also settled: amber is kept for the player's own cove mouth and the home marker, with lantern warm white for other coves and the Nursery edge (section 4.5), and chapter 03 now asks for Noggin Rock to be visible within fog range only. What is still open:

1. **For document 09, not canon:** the "no Humanoid" character (canon 14) has a documented rendering cost for skinned meshes (section 14.3).
