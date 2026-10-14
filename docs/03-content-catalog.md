# 03 · Content catalog

This chapter lists every thing that exists in GULP: what it is, its numbers, and where it lives. Document 01 (canon) wins over this file. Document 02 owns how systems behave, 05 owns prices and balance, 06 owns art style, 07 owns the asset list, 08 owns screens. Appearance notes here are short design briefs (shape, colours, personality) for document 06 to style.

Every number marked **(tune)** is a first guess. Every entry carries a scope tag from canon section 15: **[MVP]**, **[L]**, **[P1]**, **[P2]**.

## 0. Conventions used in this chapter

| Convention | Meaning |
|---|---|
| **Position (X, Z)** | Studs from the map centre. The centre (0, 0) is the top of Noggin Rock. +X is east, +Z is south (north is −Z, as in a Roblox top-down view). |
| **Depth** | Studs below the water surface. Depth 0 is the surface. In Roblox, Y = −depth. |
| **Bearing and radius** | `B090 r560` means bearing 90° clockwise from north, 560 studs from the centre. X = r × sin(bearing), Z = −r × cos(bearing). |
| **Prey speed %** | Percent of the canon swim speed of a player of the same tier (tier 0 prey uses tier 1, 26 studs/s). |
| **Species stat %** | Percent of the canon tier table value (canon 5.1) at every tier. |
| **Body size** | Length × height × width in studs at body scale 1.0. Multiply by the creature's body scale, which grows smoothly with mass between the tier values (canon 5.1). |
| **Reward bands** | R1 to R5. Chapter 05, section 3.12 sets the amounts: R1 = 100 Pearls, R2 = 125, R3 = 175, R4 = 2,500, R5 = 5,000 (tune). Where this chapter repeats any Pearl amount it is a copy, and chapter 05 wins. |
| **Decoration price bands** | D1 to D4. Chapter 05, section 4.3 sets the prices: D1 = 200 Pearls, D2 = 4,500, D3 = 30,000, D4 = 360,000 (tune). |
| **Landmark IDs** | Every landmark has a stable ID, `lm_<name>` in lowercase with no leading "the" (`lm_noggin_rock`, `lm_tin_pickle`), given in the ID column of the landmark tables in sections 6.2 to 6.6. An ID never changes once shipped, even if the display name does. Chapter 09 uses these IDs unchanged for `LandmarkDef.id` and the keys of `codex.places`. |
| **Body families** | Traits are drawn once per family, not once per species. Fish-shaped: Minnow, Pufferfish, Shark Pup, Anglerfish, Orca Calf, Narwhal. Eel-shaped: Eel, Axolotl. Turtle: Sea Turtle. Squid: Squid. These four families are chapter 06's (section 3.1). Post-launch, Manta Ray and Seahorse each need a new family (Ray and Upright; chapter 07, section 2.8). |

## 1. Playable species

Each species is one rig with a juvenile mesh (tiers 1 to 3) and an adult mesh (tiers 4 to 7), as in canon section 7. Unlock prices are in document 05. Base colours in the sheets are copies of chapter 06, section 4.3, which owns them.

### 1.1 Launch species: stat table

All values are percent of the canon tier table or of the canon dash (2.2× speed, 0.35 s, 2.5 s cooldown). All (tune).

<!-- data:Species -->
Soft-launch slice (chapter 13, section 3.2): `minnow`, `puffer`.

| ID | Tag | Swim speed | Turn rate | Dash speed | Dash time | Dash cooldown | Mouth size | Start tier | Body at scale 1.0 (L × H × W) | Collision radius | Ability |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `minnow` | [MVP] | 100% | 100% | 2.2× | 0.35 s | 2.0 s (Dart) | 100% | 1 | 3.0 × 1.1 × 0.7 | 100% **(tune)** | `dart` |
| `puffer` | [MVP] | 88% | 105% | 2.2× | 0.35 s | 2.5 s | 95% | 1 | 2.4 × 2.0 × 2.0 | 100% **(tune)** | `puff` |
| `eel` | [MVP] | 106% | 125% | 2.2× | 0.455 s (Slip) | 2.5 s | 80% | 1 | 5.0 × 0.8 × 0.6 | 100% **(tune)** | `slip` |
| `turtle` | [L] | 85% | 85% | 2.0× | 0.35 s | 3.0 s | 105% | 1 | 3.0 × 1.2 × 2.6 | 100% **(tune)** | `shell` |
| `squid` | [L] | 96% | 75% | 2.6× | 0.35 s | 2.5 s | 90% | 1 | 3.6 × 1.0 × 1.0 | 100% **(tune)** | `jet` |
| `shark` | [L] | 104% | 90% | 2.2× | 0.35 s | 2.5 s | 120% | 2 (mass 10) | 3.4 × 1.3 × 0.9 | 100% **(tune)** | `rampage` |

<!-- /data -->

Mouth size scales the bite zone at the front of the body. Document 02 defines the base bite zone; this chapter only gives the multiplier.

The dash columns describe the dash only. Pressed abilities (Puff, Shell, Jet) have their own numbers in the sheets below: Jet is 3.0× speed for 0.5 s, separate from the Squid's 2.6× dash.

### 1.2 Launch species: sheets

#### Minnow · `minnow` · [MVP]

| | |
|---|---|
| **Fantasy** | The small, quick everyfish that can grow into anything. |
| **Juvenile (tiers 1 to 3)** | Teardrop body. Eyes take a third of the head. Short round tail, one small back fin. Tangerine orange back, pale cream belly, bright yellow tail. Looks eager and a bit nervous. |
| **Adult (tiers 4 to 7)** | Longer torpedo body, forked tail, pointed fins, a small brow that reads as determined. The yellow tail stays as its ID mark at every size. |
| **Signature ability** | **Dart** (passive): dash cooldown is 2.0 s instead of 2.5 s. That is 30 dashes a minute instead of 24. |
| **Strengths** | No weak stat. Most dashes per minute. Easiest species to learn. |
| **Weaknesses** | No way to survive a mistake. Not the best at any one job. |
| **Who it is for** | Every player on day one, and players who like clean dodging. |

#### Pufferfish · `puffer` · [MVP]

| | |
|---|---|
| **Fantasy** | A round little worrier that becomes too big to swallow. |
| **Juvenile** | Almost a ball. Tiny fins that flap fast, small beak mouth with two front teeth, wide worried eyes. Bright yellow back with ochre freckles, cream belly, coral lips. |
| **Adult** | Boxier, heavier brow, low smooth bumps on the back (no spines: spines belong to the Spiny trait). Same yellow, cream and coral. |
| **Puffed form** | A sphere 1.5 times the normal height, skin stretched pale, cheeks full, eyes wide. Must read as "do not eat" from 100 studs. |
| **Signature ability** | **Puff:** inflate for 2 s. Counts as one tier higher for defence, swims 60% slower. 10 s cooldown. |
| **Strengths** | Puff stops any attacker that is exactly one tier above. Tight turning. Forgiving for learning to survive. |
| **Weaknesses** | Slow: cannot run down Mackerel or anything faster without a dash. Puff does nothing against an attacker two tiers up. |
| **Who it is for** | New and careful players, and younger players. First unlock, meant to teach "ability at the right moment". |

#### Eel · `eel` · [MVP]

| | |
|---|---|
| **Fantasy** | A cheeky noodle that knows every back door. |
| **Juvenile** | Short noodle with a big head and one fin ribbon running down the back. Violet back, pale lilac belly, yellow fin ribbon. Sly half-smile. |
| **Adult** | Long body, strong jaw, taller fin ribbon, a confident grin. Same violet and yellow. |
| **Signature ability** | **Slip** (passive): can pass through eel holes (10 tunnels, section 6.9). Dash lasts 30% longer (0.455 s). |
| **Strengths** | Best turning. Longest dash. Private shortcuts through the Rim and the Wall. Thin body fits between kelp stalks and coral heads. |
| **Weaknesses** | Smallest mouth (80%), so prey must be lined up well. Long body is easy to catch from the side. |
| **Who it is for** | Explorers and escape artists. Players who are good at steering. |

#### Sea Turtle · `turtle` · [L]

| | |
|---|---|
| **Fantasy** | A calm tank that shrugs off the scariest thing in the sea. |
| **Juvenile** | Round shell, head and flippers too big for the body, sleepy friendly eyes. Leaf-green skin, warm orange shell, cream belly. |
| **Adult** | Longer shell with raised ridges, broad front flippers, calm half-closed eyes. |
| **Shell form** | Head and flippers pull in, the shell tilts and spins slowly. A soft ring pulses around it while protected. |
| **Signature ability** | **Shell:** tuck in for 2.5 s. Cannot be eaten, cannot move. 14 s cooldown. |
| **Strengths** | The only launch species that can survive Old Scar head-on. Big mouth. Best for banking large, safe runs. |
| **Weaknesses** | Slowest swimmer, weakest dash (2.0×, 3.0 s cooldown). Stuck in place during Shell, so a patient hunter can wait. Poor at catching fast prey. |
| **Who it is for** | Collectors and players who hate losing a run. |

#### Squid · `squid` · [L]

| | |
|---|---|
| **Fantasy** | A jet-powered trickster that vanishes in a puff of ink. |
| **Juvenile** | Short bullet-shaped body, huge eyes, short stubby arms. Coral pink with cream spots and cream arm tips. |
| **Adult** | Long body with wide tail fins, two long feeding arms with paddle tips, sharper eyes. |
| **Signature ability** | **Jet:** shoot backwards at 3.0× speed for 0.5 s (tune) and leave an ink puff 8 studs wide that lasts 2 s (tune). 6 s cooldown. |
| **Strengths** | Strongest dash (2.6×). Jet is a second escape on its own timer. The ink puff breaks line of sight. |
| **Weaknesses** | Worst turning (75%), so it overshoots prey. Jet goes backwards, where the player cannot see. |
| **Who it is for** | Skilled players who enjoy burst movement and tricking other players. |

#### Shark Pup · `shark` · [L]

| | |
|---|---|
| **Fantasy** | A hungry pup that snowballs once the eating starts. |
| **Juvenile** | Chubby, big head, rounded fins, a grin with a tooth gap. Pale steel-blue back, white belly, pink cheeks. |
| **Adult** | A stocky shark outline that still reads as young: thick body, rounded teeth, bright eyes. Fierce but friendly. |
| **Rampage form** | Eyes narrow, speed lines trail from the fins, a short red-orange streak follows the tail for 5 s. |
| **Signature ability** | **Rampage** (passive, ID `rampage`): eating 3 prey within 4 s gives +25% speed for 5 s. Starts each run at tier 2. |
| **Strengths** | Biggest mouth (120%). Skips the first 30 seconds. Rampage chains through schools. |
| **Weaknesses** | Wide turns. No defence. Starting at tier 2 means other players can eat it from the first second. |
| **Who it is for** | Confident hunters. The long-term goal for free players and the headline game pass. |

### 1.3 Launch colour patterns · [L]

A pattern changes base colours only. Patterns use large colour areas (two-tone, fades, coloured fin tips) and never bands, dots or glowing lines, so traits always read on top. Each species has a default look (section 1.2) plus three patterns: 18 in all. Chapter 05, section 8.5 decides how each pattern is obtained and what it costs; the Source column copies it: 1 in the Starter Pack, 11 for Robux (79 to 199) and 6 free from the Codex, one per species. No pattern is sold for Pearls.

| ID | Species | Name | Description | Source |
|---|---|---|---|---|
| `pat_minnow_sunrise` | Minnow | Sunrise | Rosy pink back fading to a gold belly, pale pink fins | Starter Pack |
| `pat_minnow_blueberry` | Minnow | Blueberry | Deep blue back, pale blue belly, yellow tail | Robux |
| `pat_minnow_mint` | Minnow | Mint | Mint green body, white fin tips, dark green tail | Free: Codex, all 7 Minnow tiers |
| `pat_puffer_lemon` | Pufferfish | Lemon Drop | Pale lemon body dusted white like sugar, white fins, lime-green lips | Robux |
| `pat_puffer_bubblegum` | Pufferfish | Bubblegum | Pink back, cream belly, pale blue fins | Robux |
| `pat_puffer_midnight` | Pufferfish | Midnight | Navy back, grey belly, light cyan fin edges | Free: Codex, all 7 Pufferfish tiers |
| `pat_eel_liquorice` | Eel | Liquorice | Black back, red belly, red fin ribbon | Robux |
| `pat_eel_seafoam` | Eel | Seafoam | Pale green-white body, teal fin ribbon | Robux |
| `pat_eel_sunset` | Eel | Sunset | Coral head fading to an orange tail (warm coral, never the hot pink of the colour-blind danger outline) | Free: Codex, all 7 Eel tiers |
| `pat_turtle_mossback` | Sea Turtle | Mossback | Dark green shell with moss tufts, tan skin | Robux |
| `pat_turtle_terracotta` | Sea Turtle | Terracotta | Brick-red clay shell, cream skin | Robux |
| `pat_turtle_royal` | Sea Turtle | Royal | Purple shell with a gold rim, lilac skin | Free: Codex, all 7 Sea Turtle tiers |
| `pat_squid_peach` | Squid | Peach Fizz | Soft peach-orange body, cream arms, yellow tail fins | Robux |
| `pat_squid_deepsea` | Squid | Deep Sea | Dark teal body, pale glowing fin edges | Robux |
| `pat_squid_cherry` | Squid | Cherry | Red body, white arm tips | Free: Codex, all 7 Squid tiers |
| `pat_shark_sandbar` | Shark Pup | Sandbar | Sandy tan back, white belly | Robux |
| `pat_shark_storm` | Shark Pup | Storm | Dark slate back, light grey fin tips, pale belly | Robux |
| `pat_shark_bubble` | Shark Pup | Bubble Blue | Bright blue back, white belly, yellow eyes | Free: Codex, all 7 Shark Pup tiers |

### 1.4 Post-launch species (short sheets)

Order follows canon. Canon names an ability for Anglerfish, Manta Ray and Axolotl only; the abilities for Seahorse, Orca Calf and Narwhal are proposals from this chapter (see section 16). Document 12 owns dates. All numbers (tune).

| ID | Tag | Swim speed | Turn rate | Dash | Mouth size | Start tier | Body at scale 1.0 |
|---|---|---|---|---|---|---|---|
| `anglerfish` | [P1] | 90% | 95% | Canon dash | 130% | 1 | 2.8 × 1.8 × 1.4 |
| `manta` | [P1] | 102% | 80% | Canon dash | 110% | 1 | 3.0 × 0.6 × 4.0 |
| `seahorse` | [P2] | 82% | 130% | 2.0× | 70% | 1 | 1.4 × 3.0 × 0.8 (upright) |
| `axolotl` | [P2] | 94% | 115% | Canon dash | 100% | 1 | 3.6 × 1.0 × 1.0 |
| `orca` | [P2] | 102% | 92% | Canon dash | 115% | 1 | 3.6 × 1.5 × 1.1 |
| `narwhal` | [P2] | 100% | 88% | 2.4× | 95% | 1 | 3.4 × 1.2 × 0.9, plus a 1.6 tusk |

| ID | Fantasy | Juvenile | Adult | Signature ability | Strengths | Weaknesses | Who it is for |
|---|---|---|---|---|---|---|---|
| `anglerfish` | A grumpy lamp that makes dinner come to it. | Dark plum ball, big underbite, a tiny dim lure on a stalk | Wider jaw, long lure with a bright teardrop bulb, small tired eyes | **Lure:** light the lure for 3 s; prey of your tier or lower within 30 studs swims toward you. 12 s cooldown | Biggest mouth in the game; feeds without chasing | Slow; the light also shows other players where you are | Patient players; Moon Tide and deep water fans |
| `manta` | A calm glider that crosses the map in one breath. | Small diamond shape, short tail, two curled head fins, white belly | Wide wings, long whip tail, slow graceful flaps | **Glide:** +35% speed for 3 s, turn rate halved while gliding. 9 s cooldown | Fastest way to get home; hard to catch in open water | Very wide body is easy to bite; poor in kelp and tunnels | Players who bank often and travel far |
| `seahorse` | A tiny sipper that eats without moving. | Upright curl, long snout, big crest, curled tail. Sunny yellow | Taller crest, armoured ridges, longer snout | **Sip:** pull prey of your tier or lower from a 14-stud, 40° cone into your mouth. 5 s cooldown | Eats prey in cracks and schools without chasing; best turning | Slowest species; smallest mouth without Sip | Younger players; reef and kelp grazers |
| `axolotl` | A smiling pink noodle that grows back. | Pink body, six feathery gills, wide flat smile, tiny legs | Longer body, taller gills, paddle tail | **Regrow:** once per run, a bite that would gulp you takes 40% of your mass instead and gives 2 s of protection | A built-in second chance; good turning | Loses a lot of mass when saved; average at everything else | Players who push their luck |
| `orca` | A clever calf that sees the whole hunt. | Chubby black and white calf, round head, small back fin | Tall back fin, strong tail, bright eye patch | **Echo:** for 4 s, see all prey, players and predators within 120 studs through rock and kelp. 15 s cooldown | Finds trait prey and danger first; strong mouth | No escape tool; the ping is visible to others as a ripple | Hunters and trait collectors |
| `narwhal` | A jousting daydreamer with a very useful horn. | Grey-speckled chubby body, short stub of a tusk | Long spiral tusk, pale grey body, kind eyes | **Joust:** while dashing, you can eat prey (not players) one tier above yours | Reaches the next prey tier early; fastest growth when aimed well | Must hit with a dash; wide turns; no defence | Skilled aimers |

## 2. Prey

All eight prey are [MVP]. Prey are data on the server and drawn by clients (canon 14).

### 2.1 Stats

<!-- data:Prey -->
Soft-launch slice (chapter 13, section 3.2): `plankton`, `krill`, `shrimp`, `sardine`, `darter`, `mackerel`.

| ID | Tag | Tier | Mass | Group size | Flee speed (% of same-tier player) | Flee speed (studs/s) | Turn rate (°/s) | Flee distance (studs) | Flee burst (s) | Respawn (s) | Zones (section 2.3) | Behaviour (chapter 02, section 9.2) | Radius (studs) | Wobble (studs) | Scatter gain |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `plankton` | [MVP] | 0 | 0.2 | Patch of 6 to 10 | 8% (drift only) | 2 | None | Does not flee | None | 4 | `nursery`, `reef`, `kelp`, `dropoff`, `trench` | `drift` | 0.2 **(tune)** | 0.1 **(tune)** | 0 **(tune)** |
| `krill` | [MVP] | 1 | 1 | Swarm of 12 to 20 | 55% | 14 | 400 | 10 | 2 | 12 | `nursery`, `reef` | `swarm` | 0.4 **(tune)** | 0.2 **(tune)** | 1 **(tune)** |
| `shrimp` | [MVP] | 1 | 1.5 | 1 to 3 | 45% (hops) | 12 | Hops in any direction | 8 | 1.5 | 10 | `reef`, `kelp` | `hop` | 0.5 **(tune)** | 0.25 **(tune)** | 0 **(tune)** |
| `sardine` | [MVP] | 2 | 4 | School of 8 to 14 | 75% | 21 | 300 | 18 | 3 | 20 | `reef`, `kelp` | `school` | 0.8 **(tune)** | 0.4 **(tune)** | 1 **(tune)** |
| `darter` | [MVP] | 3 | 10 | 1 or 2 | 85% | 25.5 | 480 | 20 | 3 | 25 | `reef`, `kelp` | `solo` | 1.2 **(tune)** | 0.6 **(tune)** | 0 **(tune)** |
| `mackerel` | [MVP] | 4 | 25 | 1 to 3 | 95% | 30.4 | 120 | 28 | 4 | 35 | `kelp`, `dropoff` | `run` | 1.8 **(tune)** | 0.9 **(tune)** | 0 **(tune)** |
| `bonito` | [MVP] | 5 | 60 | Pack of 3 to 5 | 100% | 34 | 110 | 34 | 5 | 50 | `dropoff`, `trench` | `pack` | 2.75 **(tune)** | 1.38 **(tune)** | 1 **(tune)** |
| `tuna` | [MVP] | 6 | 150 | 1 | 110% | 39.6 | 90 | 50 | 6 | 90 | `dropoff`, `trench` | `solo` | 4.25 **(tune)** | 1.5 **(tune)** | 0 **(tune)** |

<!-- /data -->

Notes (all tune):
- **Radius** is the bite size of one member (chapter 09, section 8.9): half its length in section 2.2. **Wobble** is the most the client may shake a member for looks (chapter 09, section 8.1, at most 1.5 studs). **Scatter gain** is how far a group's formation spreads at full scatter: 1 doubles it, 0 for a group that does not scatter (chapter 09, section 8.1).
- **Flee distance** is how close a creature that can eat it must come before it flees.
- **Cruise speed** when calm is 40% of flee speed.
- After a flee burst, prey is **tired** for 2 s and moves at cruise speed. This is the catch window for prey that is as fast as the player.
- **Respawn** is the delay between a group being eaten and a new group appearing at a spawn point at least 60 studs from every player. During a Feeding Frenzy it is divided by 3.
- Canon speed design holds: small prey is slow and turns well; large prey is fast and turns badly, so it is caught by cutting corners, by dashing, or from a current.

### 2.2 Appearance and behaviour

| ID | Length (studs) | Appearance brief | Behaviour |
|---|---|---|---|
| `plankton` | 0.4 | A soft pale-green mote that twinkles. No face. | Drifts in loose patches. Never reacts. |
| `krill` | 0.8 | Pink-orange comma shape, two black dot eyes, feathery legs that flutter. Looks busy. | Swarm hangs in mid-water. Scatters outward when approached, then regroups after 3 s. |
| `shrimp` | 1.0 | See-through peach body, long whiskers, curled tail. Looks startled. | Sits on the floor. Hops 4 to 6 studs at a time, each hop kicks up a sand puff. |
| `sardine` | 1.6 | Silver-blue sliver with one round surprised eye. | Tight school that turns as one. Flees as a group away from the threat; splits in two if hit in the middle. |
| `darter` | 2.4 | Bright orange body, teal fins, pointed nose. Looks smug. | Hovers near coral or kelp. Flees in short zig-zags and hides behind cover. |
| `mackerel` | 3.6 | Teal-green back, silver belly, bullet body, sickle tail. Looks determined. | Cruises open lanes. Flees in a long straight line and does not turn until tired. |
| `bonito` | 5.5 | Navy back, silver belly, thick shoulders, grumpy brow. | Pack swims in a V along the Wall. Flees together in a straight line, then wheels round as a pack. |
| `tuna` | 8.5 | Deep blue barrel body, small yellow fins, huge tail. Looks unimpressed. | Solo, always moving. Flees early and fast; best caught by ambush from below or from a current. |

### 2.3 Spawn weight and live cap per zone

**Weight** is the share of spawn rolls in that zone (each column adds to 100). **Cap** is the most groups alive in that zone at once. All (tune). During a Feeding Frenzy caps are doubled.

| Prey | Nursery Lagoon | Sunlit Reef | Kelp Forest | The Drop-off | The Trench [P2] |
|---|---|---|---|---|---|
| `plankton` | 70 · cap 12 patches | 40 · cap 40 patches | 30 · cap 30 patches | 25 · cap 20 patches | 20 · cap 10 patches |
| `krill` | 30 · cap 5 swarms | 18 · cap 12 swarms | None | None | None |
| `shrimp` | None | 16 · cap 30 groups | 18 · cap 35 groups | None | None |
| `sardine` | None | 14 · cap 8 schools | 16 · cap 8 schools | None | None |
| `darter` | None | 12 · cap 14 groups | 18 · cap 16 groups | None | None |
| `mackerel` | None | None | 18 · cap 12 groups | 38 · cap 14 groups | None |
| `bonito` | None | None | None | 31 · cap 6 packs | 50 · cap 6 packs |
| `tuna` | None | None | None | 6 · cap 4 | 30 · cap 6 |

### 2.4 Spawn rules for prey

- **Doorstep rule (pillar 1):** every occupied cove mouth always has at least 2 plankton patches and 1 krill swarm within 60 studs of it. These do not count against the Reef caps.
- Plankton spawns in open water at any depth. Krill spawns in mid-water over sand. Shrimp spawns only on the floor. Schools spawn at least 15 studs from rock.
- Where each prey gathers inside a zone is listed in the zone sheets (section 6).

## 3. Trait prey

Eat five of the same trait prey in one run to gain its trait (canon 8.2); four with the Keen Nose pass. Trait prey are not affected by the Feeding Frenzy spawn rate.

**How a player recognises any trait prey (one rule for all 13):**
1. A slow pulsing halo ring in the trait's colour (section 4.1), on top of the normal green outline.
2. A short sparkle trail in the same colour when it moves.
3. A shape no ordinary prey has (see the briefs below).
4. With the Glow trait, an edge marker on screen when one is within 60 studs (canon).

### 3.1 Stats

Mass for trait prey is not in canon; chapter 05, section 2.1 sets it (the same as ordinary prey of the same tier, Marrow 40) and this table copies it. "Alive" is the most alive on one server at once.

<!-- data:TraitPrey -->
Soft-launch slice (chapter 13, section 3.2): `glowfry`, `zebra_darter`, `dotted_goby`, `armor_shrimp`, `urchin_puff`.

| ID | Tag | Tier | Mass | Gives | Rarity | Alive per server | Respawn (s) | Flee speed | Flee distance (studs) | Zones (section 3.2) | Behaviour (chapter 02, section 9.3) | Group size | Radius (studs) | Wobble (studs) | Scatter gain |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `glowfry` | [MVP] | 1 | 1 | Glow | Common | 10 (6 Reef, 4 Kelp) | 30 | 60% | 10 | `reef`, `kelp` | `solo` | 1 **(tune)** | 0.45 **(tune)** | 0.23 **(tune)** | 0 **(tune)** |
| `zebra_darter` | [MVP] | 2 | 4 | Stripes | Common | 8 | 30 | 85% | 18 | `reef` | `solo` | 1 **(tune)** | 1 **(tune)** | 0.5 **(tune)** | 0 **(tune)** |
| `dotted_goby` | [MVP] | 1 | 1 | Spots | Common | 10 | 25 | 45% | 8 | `reef` | `hop` | 1 **(tune)** | 0.55 **(tune)** | 0.28 **(tune)** | 0 **(tune)** |
| `armor_shrimp` | [MVP] | 2 | 4 | Plated | Uncommon | 6 | 60 | 40% | 8 | `kelp` | `hop` | 1 **(tune)** | 0.8 **(tune)** | 0.4 **(tune)** | 0 **(tune)** |
| `urchin_puff` | [MVP] | 2 | 4 | Spiny | Uncommon | 6 | 60 | 20% | 5 | `reef` | `drift` | 1 **(tune)** | 0.7 **(tune)** | 0.35 **(tune)** | 0 **(tune)** |
| `ribbonfish` | [MVP] | 3 | 10 | Longfin | Uncommon | 6 | 60 | 80% | 22 | `kelp` | `run` | 1 **(tune)** | 1.6 **(tune)** | 0.8 **(tune)** | 0 **(tune)** |
| `inklet` | [MVP] | 3 | 10 | Ink | Rare | 5 | 120 | 90% | 20 | `dropoff` | `solo` | 1 **(tune)** | 1.1 **(tune)** | 0.55 **(tune)** | 0 **(tune)** |
| `spark_eel` | [L] | 4 | 25 | Spark | Rare | 5 | 120 | 95% | 24 | `dropoff` | `solo` | 1 **(tune)** | 2 **(tune)** | 1 **(tune)** | 0 **(tune)** |
| `leaf_drifter` | [L] | 3 | 10 | Camo | Rare | 5 | 120 | 50% | 6 | `kelp` | `drift` | 1 **(tune)** | 1.3 **(tune)** | 0.65 **(tune)** | 0 **(tune)** |
| `crystal_jelly` | [MVP] | 3 | 10 | Crystal | Epic | 5 (one drift of five) | A new drift every 300, counted from when the last one appeared; jellies not eaten leave 240 after their drift appeared | 6 studs/s drift | Does not flee | `reef`, `kelp`, `dropoff` | `drift` | 5 | 1.4 **(tune)** | 0.7 **(tune)** | 0 **(tune)** |
| `vent_snail` | [L] | 4 | 25 | Ember | Epic | 4 | 180 | 10% (crawls) | Does not flee | `dropoff` | `hop` | 1 **(tune)** | 1.2 **(tune)** | 0.6 **(tune)** | 0 **(tune)** |
| `lunar_fry` | [MVP] | 2 | 4 | Moonlit | Mythic | 12 (4 per moonbeam); 40 in total per event | Event only | 70% | 16 | `reef`, `kelp`, `dropoff` | `school` | 4 | 0.75 **(tune)** | 0.38 **(tune)** | 1 **(tune)** |
| `marrow` | [L] | 3 | 40 | Bonefed | Mythic | 60 in total per event | Event only | 3 studs/s drift | Does not flee | `dropoff` | `drift` | 1 **(tune)** | 1 **(tune)** | 0.5 **(tune)** | 0 **(tune)** |

<!-- /data -->

Intended effort for one player with no competition (tune): Common about 1 minute, Uncommon about 3 minutes, Rare about 6 minutes, Epic one long careful run, Mythic only during its event.

### 3.2 Sheets

| ID | Exact spawn place | Behaviour | Appearance brief | How the player spots it |
|---|---|---|---|---|
| `glowfry` | Inside the 12 holes of Honeycomb Caves (Reef) and among the lit stalks of Glowgrove (Kelp). Five more are scripted in the Nursery's Glow Grotto during a new player's first run only, drawn for that player alone (section 6.2) | Peeks out of a hole, swims a 6-stud loop, darts back in when chased and stays hidden 4 s | Tiny round fry, 0.9 studs, warm yellow, with a glowing belly like a lantern | The only light inside a dark hole |
| `zebra_darter` | Along the walls of Stripe Alley and on the 6 coral heads nearest to it | Hovers by coral. Flees in sharp zig-zags, 3 turns then a pause | Darter shape, 2.0 studs, white with bold black bands, yellow lips | Black and white bands stand out against orange coral |
| `dotted_goby` | On the sand of Goby Flats, at least 10 studs apart | Sits still on the sand. Flees in three short hops, then rests 2 s | Chubby bottom-sitter, 1.1 studs, cream with big orange dots, eyes on top of its head | Orange dots on pale sand; it never leaves the floor |
| `armor_shrimp` | On the floor of Hush Hollow | Walks slowly. When approached it curls into a ball and rolls 10 studs downhill, then uncurls after 2 s | Stocky shrimp, 1.6 studs, steel-blue shell plates with brass edges | A metal glint on the dark floor and a clink sound when it walks |
| `urchin_puff` | Wedged in the cracks of the Crackles, 2 to 3 studs down | Barely moves. Shuffles deeper by 2 studs when approached, then creeps back | Round purple puffball, 1.4 studs, short soft spikes, two tiny eyes | Purple spikes poking out of grey rubble |
| `ribbonfish` | In the Ribbon Roof canopy, depth 10 to 35 | Swims upright, weaving between kelp fronds. Flees upward toward the surface | Thin silver-pink fish, 3.2 studs, with a long pink ribbon fin trailing twice its length | The pink ribbon waving in the green canopy |
| `inklet` | In and around the 8 Ink Pots on the Wall, depth 140 to 320 | Hovers at a pot mouth. When approached it puffs a 6-stud ink cloud (2 s) and jets 20 studs | Tiny squid, 2.2 studs, deep indigo with big pale eyes | Pale eyes in a dark hole, and small ink puffs |
| `spark_eel` | Inside and within 30 studs of the Tin Pickle wreck, depth 220 to 260 | Loops in and out through the wreck's portholes and hull gaps; a small arc crackles off it every 5 s (harmless) | Short thin eel, 4.0 studs, dark navy with a bright cyan zig-zag line | Cyan flashes lighting the wreck's windows |
| `leaf_drifter` | Drifting among the loose kelp leaves of Leafy Lane, depth 50 to 90 | Hangs still and looks like a leaf. Shows no outline or halo until a player is within 15 studs. Flees weakly | Flat leaf-shaped fish, 2.6 studs, olive green with leafy frills and two small eyes | A "leaf" that sways out of time with the others, and has eyes |
| `crystal_jelly` | A drift of five follows one fixed route through three zones (Reef, Kelp, Drop-off): Noggin Rock → North Pass → Ribbon Roof → Lookout Stack → Ink Pots → the Ledge → East Pass → Noggin Rock. The drift starts at a random point on the route at least 100 studs from every player | The five stay within 12 studs of each other and drift at 6 studs/s, depth 20 to 90. They never flee. A chime plays for players within 150 studs. About one drift every 5 minutes (canon); at most one drift is alive at a time | Bell-shaped jelly, 2.8 studs, clear and faceted like cut glass, throws small rainbow glints | Five sets of rainbow glints and a chime; a zone-name banner tells the server where the drift is |
| `vent_snail` | On the rims of the 6 cycling vents at the Chimneys (never on the 3 always-on vents) | Crawls around the vent rim, inside the burn area while the vent is on. Grab it while the vent is off (`Dormant` or `Rumble`, section 5.1) | Fat snail, 2.4 studs, black shell with glowing orange cracks, sleepy eyes on stalks | An orange glow that stays put on a chimney |
| `lunar_fry` | Inside the three active moonbeams during Moon Tide (section 7.2) | Circles inside the beam. If chased out of the beam it fades after 3 s and reappears inside | Small fry, 1.5 studs, silver-white with a crescent mark on its side, leaves silver motes | It is the brightest thing in the dark sea, always inside a beam |
| `marrow` | Released from the whale skeleton at Whale's Rest during Whale Fall (section 7.3) | A chunk, not an animal. Drifts up and outward from the skeleton at 3 studs/s for up to 60 s | Puffy cream-white nugget, 2.0 studs, like a piece of honeycomb, with a soft white glow. No red, no flesh | White glowing chunks rising from the skeleton |

## 4. Traits

### 4.1 Trait list

**Channel** tells artists how three traits fit on one body: Pattern, Light or Form (chapter 06, section 8.1). The colour and body-area columns are copies of chapter 06, section 8.2, which is the authority for how a trait looks; this chapter owns the names, rarities, effects and Codex text. The trait colour is also the halo colour of its trait prey (section 3).

<!-- data:Traits -->
Soft-launch slice (chapter 13, section 3.2): `glow`, `stripes`, `spots`, `plated`, `spiny`.

| ID | Tag | Trait | Rarity | Trait colour | Channel · body area | Codex text |
|---|---|---|---|---|---|---|
| `glow` | [MVP] | Glow | Common | Warm yellow | Light · the line along each side, nose to tail | You light up, and trait prey nearby cannot hide from you. |
| `stripes` | [MVP] | Stripes | Common | Dark navy on white | Pattern · flanks, 4 bold bands | Bold stripes that make you swim a little faster. |
| `spots` | [MVP] | Spots | Common | Cream dots with dark rings | Pattern · back and flanks, 7 to 9 dots | Big dots that squeeze extra mass out of every bite. |
| `plated` | [MVP] | Plated | Uncommon | Steel grey-blue | Form · back, 5 overlapping plates | Tough plates take one bite for you, then crack. |
| `spiny` | [MVP] | Spiny | Uncommon | Cream with red-orange tips | Form · back and flanks, 9 spines | Prickly spines mean only much bigger mouths can swallow you. |
| `longfin` | [MVP] | Longfin | Uncommon | The species' accent colour, fading to white | Form · tail and back fin tips | Long, floaty fins carry your dash much further. |
| `ink` | [MVP] | Ink | Rare | Dark purple-black | Pattern · belly and rear half | Your dash leaves a dark cloud to hide in. |
| `spark` | [L] | Spark | Rare | Electric cyan with a white core | Light · zig-zag lines from the head back | Your dash gives nearby prey a tiny, stunning zap. |
| `camo` | [L] | Camo | Rare | Leaf green and tan | Form · leafy frills along the back and fin edges | Hold still and you fade into the water. |
| `crystal` | [MVP] | Crystal | Epic | Pink, pale blue and white facets | Form · a crown of shards on the back | Shiny all over, and worth extra Pearls when you get home. |
| `ember` | [L] | Ember | Epic | Orange with a yellow core | Light · cracks across the back and flanks | Warm glowing cracks keep vents and jellies from hurting you. |
| `moonlit` | [MVP] | Moonlit | Mythic | Silver-lilac with a cyan glow | Light · a rim around the whole outline, brightest on the back | You shine like the moon, and prey drifts toward you. |
| `bonefed` | [L] | Bonefed | Mythic | Bone white | Pattern · flank and face: spine, ribs and a mask | Fed on whale bone, you grow more from everything you eat. |

<!-- /data -->

### 4.2 Look on the body, by family

Briefs for adapting each trait to the four families. Chapter 06, section 8.2 gives each trait's home zone, fallback zone, colour and piece count, and wins where this table differs.

| Trait | Fish-shaped | Eel-shaped | Turtle | Squid |
|---|---|---|---|---|
| Glow | Soft yellow light along the line on each side, nose to tail; fin edges glow faintly | A glowing line down each side, brightest at the tail tip | Shell rim glows; the seams between shell plates are lit from inside | Body glows from within; each arm tip is a bright dot |
| Stripes | 4 bold dark bands across the flanks, from behind the gills to the tail | 9 narrow rings along the upper body | 3 bands across the shell, one band on each flipper | 4 bands around the body, dark tips on the tail fins |
| Spots | 7 to 9 large cream dots with dark rings across the back and flanks | One row of dots down each side, shrinking toward the tail | One big dot on each shell plate, small dots on the flippers | Dots scattered on the lower body, one on each tail fin |
| Plated | 5 overlapping plates along the back, from the shoulders to the tail | Plate rings on the front third, like a collar of segments | A second, thicker layer of raised shell plates | A plated cap on the body tip and guards on the two long arms |
| Plated, cracked | Plates split, one back plate missing | Two rings broken, one missing | A jagged split across the shell | Cap chipped, one arm guard missing |
| Spiny | 9 spines on the back and upper flanks, cream with red-orange tips | A ridge of short spines along the whole back | Spikes around the shell rim | Spines along both tail fins and on the body tip |
| Longfin | Tail and back fin double in length and trail as ribbons | Fin ribbon doubles in height and trails past the tail | Long trailing edges on the rear flippers, plus a ribbon tail | Tail fins widen and trail; arms 40% longer with ribbon ends |
| Ink | Dark blotches rising like smoke over the belly and rear half | A dark fade from the tail up to mid-body | Dark blotches on the rear flippers and the back edge of the shell | Tail fins and arm tips turn dark, as if dipped in ink |
| Spark | Thin cyan zig-zag on each flank; small arcs jump between fin tips every few seconds | One zig-zag the full length; arcs run nose to tail | Zig-zags follow the shell seams; arcs jump across the shell | Zig-zags on the body; arcs jump between arm tips |
| Camo | Leafy green frills along the back and fin edges; body takes a green tint | Kelp-leaf frills along the whole underside | Sea-grass tufts on the shell, frilled flipper edges | Leaf-shaped tail fins and frilled arms |
| Crystal | A crown of cut-gem shards on the back; faceted glassy patches on the flanks | Gem studs spaced down the back; glassy tail tip | Shell plates become cut-gem facets | Body tip becomes a faceted point; tail fins turn clear |
| Ember | Orange glowing cracks across the back and flanks; faint heat shimmer | Cracks spiral the length of the body | Shell seams glow like coals | Cracks on the body; arm tips glow orange |
| Moonlit | Silver rim light on back and fins; crescent mark on the forehead; slow silver motes trail behind | Silver line down the back; crescent on the head | Silver shell rim; crescent in the centre of the shell | Silver rim; crescent on the body; arm tips shed motes |
| Bonefed | White bone drawing: mask on the face, spine and ribs along the midline | Face mask and a ladder of back-bones the full length | Rib pattern across the shell, mask on the head | Mask above the eyes, bone bands on each arm |

Bonefed is drawn as a friendly costume-style bone pattern (white lines on the skin), not as a real skeleton.

### 4.3 Rules when traits share a body

| Case | Rule |
|---|---|
| Two traits in one channel | The rarer trait keeps its home zone and the other moves to its fallback zone (chapter 06, section 8.3). Equal rarity: the trait gained first keeps its home zone. |
| Three traits in one channel | The third shows only as its sparkle colour on the fin tips and as its icon in the trait slots. It still works in play. |
| Two Light traits | Colours do not blend, and a creature carries one light: Moonlit beats Glow. |
| Any trait on a pattern (section 1.3) | The pattern changes base colours only; trait colours never change. |
| Readability | The silhouette changes for the Form traits: Plated, Spiny, Longfin, Camo and Crystal. A trait must be recognisable at 60 studs on a phone. |

## 5. Predators and hazards

### 5.1 Stats

All numbers beyond the canon behaviour line are (tune). "Detect" is how close a target must be. Predators never enter the Nursery or any cove.

<!-- data:Predators -->
Soft-launch slice (chapter 13, section 3.2): `barracuda`, `jelly_bloom`, `current`.

| ID | Tag | Name | Tier · eats | Zones | Count per server | Cruise / attack speed (studs/s) | Detect (studs) | Attack | Rest after attack (s) | Strike radius (studs) | Telegraph (s) | Give up after (s) | Mass when eaten | Effect | Magnitude | Effect time (s) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `gull` | [MVP] | Gull | 3 · eats tier 2 and lower | Sunlit Reef, surface only | Up to 3 dives at once | Dive 90 | A tier 1 or 2 creature within 6 studs of the surface for 2 s | Dives to depth 12; catch radius 5 | 8 | 5 | 1.5 | 0 | None | None | None | None |
| `moray` | [MVP] | Moray | 4 · eats tier 3 and lower | Kelp Forest, in 8 holes | 8 (one per hole) | Lunge 70 | 14 from the hole | Lunges 18 studs out, pulls back in 1.2 s | 6 | 2.76 | 0.6 | 1.2 | None | None | None | None |
| `barracuda` | [MVP] | Barracuda | 4 · eats tier 3 and lower | Reef (east half), Kelp | 3 (1 Reef, 2 Kelp) | 18 / 36 | 45 | Straight-line chase for 6 s, turn rate 80°/s | 5 | 2.76 **(tune)** | 0.8 | 6 | 25 | None | None | None |
| `grouper` | [L] | Grouper | 5 · eats tier 4 and lower | The Drop-off | 4 (6 during Whale Fall) | 12 / 12 | 32 | Suction cone 32 long, 60° wide, pulls at 22 studs/s for 2.5 s | 6 | 3.84 | 1 | 2.5 | 60 | None | None | None |
| `old_scar` | [MVP] | Old Scar | 7 · eats tier 6 and lower | The Drop-off, depth 110 and below | 1 | 22 / 40 | 90 | Chase for 8 s, turn rate 70°/s | 10 | 7.8 | 1 | 8 | None | None | None | None |
| `jelly_bloom` | [MVP] | Jelly bloom | Hazard | Kelp, Drop-off | 6 blooms (4 Kelp, 2 Drop-off), 8 to 12 jellies each | Drifts at 3 | Touch | Stun 1.5 s, then 3 s of sting immunity | None | None | None | None | None | `stun` | 1 | 1.5 |
| `anemone` | [L] | Anemone | Hazard | Sunlit Reef | 24 | Fixed | Touch, radius 5 | Slow by 50% for 2 s | None | None | None | None | None | `slow` | 0.5 | 2 |
| `vent` | [L] | Thermal vent | Hazard | The Drop-off (the Chimneys) | 9 (3 always on, 6 cycling; rule below) | Fixed | Creature's centre inside the column: 10 wide (radius 5), 40 tall, rising from the chimney top | Burns 5% of current mass per second | None | None | None | None | None | `burn` | 0.05 | 0 |
| `hook` | [MVP] | Fishing hook | Hazard | Sunlit Reef, depth 8 to 20 | 8 | Fixed | Eating the bait | Yanked 30 studs up and out of the water; lose 20% of mass | Bait returns after 45 | None | None | None | None | `yank` | 0.2 | 0.6 |
| `current` | [MVP] | Current | Helper | Between zones | 6 named currents (section 6.8) | +60% speed for riders | Entering the stream | Carries creatures along its path | None | None | None | None | None | `push` | 0.6 | 0 |

<!-- /data -->

The last seven columns are copies, for the content data (chapter 09, section 3.2). **Strike radius**, **Telegraph** and **Give up after** come from chapter 02, section 9.4: the catch radius or mouth radius, the warning state (Shadow, WindUp, Telegraph, Inhale, Stalk) and how long the attack lasts. The Barracuda's strike radius is the mouth radius of its tier (1.2 × 2.3, chapter 02, section 0.2) **(tune)**. **Mass when eaten** is canon 5.2. For hazards, **Magnitude** is the stun (1 = no movement), the speed multiplier while slowed, the share of mass burned per second, the share of mass lost to the hook, or the speed added by a current; **Effect time** is how long it lasts after contact, 0 while inside it (chapter 02, section 10).

**Thermal vent rule (tune).** This chapter owns it; chapter 02, section 10.3 copies it and adds only how the burn is ticked and the upward push.

<!-- data:VentCycle -->
Soft-launch slice (chapter 13, section 3.2): no rows (the vent is not in the slice).

| Vent state | Length | What it does |
|---|---|---|
| `Dormant` | 4 s | Harmless. No column. Vent Snails on the rim can be reached. |
| `Rumble` | 1 s | Harmless. The warning: the rim glows brighter, a burst of small bubbles rises, a low rumble plays. |
| `Erupting` | 3 s | The column burns: a creature whose centre is inside loses 5% of its current mass per second (canon 8.3). |

<!-- /data -->

- **Cycling vents (6):** the six outer chimneys loop `Dormant` → `Rumble` → `Erupting`, 8 s in all (3 s on, 5 s off). Each starts at its own fixed offset, so the six never all erupt together.
- **Always-on vents (3):** the three chimneys at the centre of the cluster stay in `Erupting` for good, with no `Rumble`. They are a wall to swim around, and they mark the Chimneys from far away.
- **Column:** 10 studs wide (radius 5) and 40 studs tall, rising from the chimney top. The same size for all 9.
- A vent can burn mass down to 0 and cause a tier-down, but it never gulps. Ember stops the burn (canon 9).

**Eating a predator (canon 5.2).** A player one tier higher can eat a Barracuda (tier 5 or higher) or a Grouper (tier 6 or higher). A Barracuda gives 25 mass and a Grouper gives 60 mass, the same as prey of their tier (tune). The Gull, the Moray and Old Scar cannot be eaten.

### 5.2 Sheets

| ID | Appearance brief | Where exactly | Telegraph (how the player is warned) |
|---|---|---|---|
| `gull` | Chubby white gull, 8-stud wingspan, orange beak, grumpy eyebrows. Seen from below as a dark shape on the bright surface. | Anywhere over the Sunlit Reef. Gulls rest on Gull Rock between dives. Never over the Nursery. | A dark oval shadow grows on the surface above the target and a squawk plays. The dive comes 1.5 s later. Move down or sideways 6 studs to dodge. |
| `moray` | Olive green with yellow speckles, heavy underbite, small mean eyes. 16 studs show when it lunges. | 5 holes on Peekaboo Ridge, 2 holes in floor rocks under the Tall Stand, 1 hole at the Root Ball. | Two yellow eyes glow in the hole at all times. They widen and a low growl plays 0.6 s before a lunge. Moray holes have a ring of pale bone-white pebbles; eel holes have blue barnacles. |
| `barracuda` | Long silver arrow, 12 studs, underbite, one raised eyebrow. Dark bars near the tail. | Reef: an arc at r 280 from B020 to B160, depth 30 (never closer than 100 studs to a cove mouth). Kelp A: loop between Old Anchor and Hush Hollow. Kelp B: loop between Leafy Lane and Lookout Stack. | Stops, shivers, eyes flash white, 0.8 s before it charges. It cannot turn well: swim sideways or around a coral head. It gives up after 6 s and swims off slowly. |
| `grouper` | Huge brown-green lump, 14 studs long and 9 tall, thick lips, sleepy eyes. | 2 under the Overbite, 1 at the Tin Pickle, 1 on the Ledge below the Ink Pots. During Whale Fall all move to Whale's Rest and 2 more appear. | Cheeks puff and the mouth opens wide with swirl lines for 1.0 s before suction starts. Swim or dash out of the cone sideways. |
| `old_scar` | Great white, 30 studs, pale grey, a long pale scar across the left eye, slow heavy tail. Calm, not angry. Never bloody. | Patrols Scar's Run: along the Wall face and Deep Floor between B055 and B215, depth 250 to 420. Never comes above depth 110, so the Ledge is always safe from it. | Within 120 studs: a slow heartbeat sound and a dark edge on the screen. Its red outline is visible from further than any other creature. It surges with a tail kick 1.0 s before a chase. |
| `jelly_bloom` | Pale pink bells, 2 studs each, with long thin threads. Glow softly and pulse. | Kelp: 3 blooms in Jelly Meadow, 1 drifting a loop between the Tall Stand and Glowgrove. Drop-off: 1 by the Ink Pots (depth 150 to 250), 1 in the Blue Mile (depth 200 to 300). | Always pulsing with light. A soft tingle sound within 20 studs. Stunned creatures show a spiral over the head. |
| `anemone` | Fat stalk, 5 studs, with waving candy-coloured arms (pink, yellow or teal). Looks soft and friendly. | 14 in the Tickle Garden, 10 on coral heads across the east half of the Reef. | Arms reach toward anything within 8 studs. A creature that touches one turns slightly pink and trails slow bubbles while slowed. |
| `vent` | A lumpy black stone chimney, 12 studs tall, with an orange glow at the top. | 9 chimneys within 70 studs of the centre of the Chimneys. | Cycling vents rumble and release a burst of small bubbles for 1 s (`Rumble`) before they switch on. The burning column is bright orange water full of bubbles, 10 wide and 40 tall. The 3 always-on vents show the column all the time. A creature inside flashes orange each second. |
| `hook` | A shiny silver hook with a fat pink worm that wiggles, on a thin line that goes up to a float or boat. | 5 under the Snooze rowboat, 3 single lines with red-and-white floats: by the Hoop, by Gull Rock, by the Tickle Garden. | The line and float are always visible. The bait wiggles on the spot and has no outline (canon 5.2), unlike real food; a metal glint every 2 s is the only other cue. Getting hooked is a joke: a "boing" sound, a flight into the air, a splash back down. |
| `current` | A stream of fast-moving bubbles and pale streaks, 16 studs wide, with sea grass bending along it. | Six named paths, section 6.8. | Visible from 150 studs. Arrow-shaped bubble bursts show its direction. A whoosh plays on entry. |

### 5.3 Wild creatures · [L]

Computer-controlled creatures that keep a server with fewer than 10 players lively (canon 15). Document 02, section 9.7 owns their behaviour and numbers; this entry is the content list.

| | |
|---|---|
| **Species used** | Minnow, Pufferfish, Eel, Sea Turtle and Squid in equal shares, with the same meshes and animations as players. Never the Shark Pup (tune). |
| **Look** | Default colours only. A wild creature never shows a pattern or a trait (tune). |
| **Label** | A name tag reading "Wild" plus the species name ("Wild Minnow"), with a leaf icon. Never a player-style name, never on a leaderboard. |
| **Count** | 10 minus the number of players, at most 8; none on a server with 10 or more players (document 02). |
| **Size** | Appear at tier 1 to 3 and grow no further than tier 5 (document 02). |
| **Where** | Sunlit Reef and Kelp Forest; the Ledge once they are tier 4 or 5. Never in the Nursery or a cove, and never within 80 studs of a cove mouth. |
| **Codex** | Not an entry. Eating one fills nothing in the Codex. |

## 6. Zones

### 6.1 The whole world

The map is the canon disc of water: a **radius of 1,000 studs**, up to 600 studs deep, with the surface at height 0. From r 965 outward the water darkens to deep blue ("the Blue") and a soft current pushes creatures back toward the centre; nothing can pass r 1,000.

The Sunlit Reef is a round basin in the middle. A ring of rock called **the Rim** surrounds it and holds the 24 coves. Four passes cut through the Rim. Outside the Rim, the Kelp Forest wraps the west and north, and the Drop-off wraps the east and south.

| Zone | Tag | Shape and place | Size (studs) | Depth range | View distance (tune) |
|---|---|---|---|---|---|
| Nursery Lagoon | [MVP] | Oval pool in a bulge of the Rim at the south-west, centre (−361, 361) | 220 × 170 | 0 to 30 | 300 |
| Sunlit Reef | [MVP] | Disc at the centre | Radius 400 (800 across) | 0 to 60 | 450 |
| The Rim | [MVP] | Ring of rock around the Reef, from r 400 to r 560 | 160 thick; top is 12 studs above the surface | Solid | Not applicable |
| Kelp Forest | [MVP] | Half ring on the west and north, from B225 clockwise to B045 | r 560 to r 1,000: 440 wide, about 2,450 long | 0 to 170 | 140 |
| The Drop-off | [MVP] | Half ring on the east and south, from B045 clockwise to B225 | r 560 to r 1,000: 440 wide, about 2,450 long | 0 to 480 | 300 on the Ledge, 180 below depth 150 |
| The Trench | [P2] | Curved crack in the Deep Floor, r 900 to r 980, B100 to B170 | About 1,150 long × 80 wide | 480 to 600 | 90 |
| Coves | [MVP] | 24 chambers inside the Rim | Each 76 wide × 110 long × 44 high | 8 to 52 | Whole chamber |

**Top-down map.** North is up. One character is 30 studs wide and 60 studs tall.

```
                               NORTH
                          ......."  "  ".......
                     .... "  "  "  "  "  "  "  "....
                  ..."  "  "M "  "  "  "  "  "  "  "...
               ...  "  "  "  "  "  "N "  "  "  "  "  " ...
             .KELP FOREST  "  "  "  "  "  "  "  "  "  "  "..
           .. "  "  "  "  "  "  "  "  "  "  O  "  "  "  "   ..
         .. "  "  "  "  L  "  "  "  "  "  "  "  "  "  "       ..
        .. "  "  "  "  "  "  "  ##     ##"  "  "  "  "P        ..
       .."  "  "  "  "  "  ########   ########  "  "-%%         ..
      .."  " K"  "  "  "###########   ########### ----%%%        ..
     ..  "  "  "  "  "########@  @     @ @#########-----%%        ..
    ..  "  "  "  "  "#######@       B      @ @######-----%%        ..
    . "Q "  "  "  " ######@                    @#####-----T%    1   .
   .."  "  "  "  " ######@   C            D     @#####----%%        ..
   .. "  "  "  "  ######@      SUNLIT REEF       ######----%%       ..
   . "  "  "  "  " ####                          @#### ----%%        .
W  .  "  "  "  J           I        A       E          ----%%        . E
   . " R"  "  "  " ####                          @#### ----%%        .
   .. "  "  "  "  ######@        H               ######----%U       ..
   .."  "  "  "  " #####@                F      @#####----%%      ==..
    . "  "  "  "  " ######            G        @#####-----%%     ===.
    ..  " S"  "  "  "#nnnnn#               @ @######-----%%      ==..
     ..  "  "  "  "  nnnnnnn###@ @     @ @#########-----%%      ==..
      .."  "  "  "  " nnnnn########   ###########-----%%%      ==..
       .."  "  "  "  ------########   ########-------%%   V   ==..
        .. "  "  Z  %%%---------##     ##---------%%%       ===..
         .. "  "      %%%%---------------------%%%%        ===..
           .. "           %%%%%-----------%%W%%          =2=..
             ..                 %%%%X%%%%             ====..
               ...         Y    THE DROP-OFF       ====...
                  ...                          =====...
                     ....                 ======....
                          .......       .......
                               SOUTH
```

| Symbol | Meaning | Symbol | Meaning |
|---|---|---|---|
| `#` | The Rim (rock). Gaps at N, E, S, W are the four passes | `"` | Kelp Forest |
| `@` | Cove mouths (some share a character at this scale) | `-` | The Ledge (Drop-off shelf) |
| `n` | Nursery Lagoon | `%` | The Wall (cliff) |
| `.` | The Blue (edge of the world) | `=` | The Crack (mouth of the Trench) |
| blank inside the Rim | Sunlit Reef | blank outside the Wall | Deep Floor, with open water above it |

| Key | Landmark | Key | Landmark | Key | Landmark |
|---|---|---|---|---|---|
| A | Noggin Rock | J | Old Anchor | T | Ink Pots |
| B | The Hoop | K | The Tall Stand | U | The Tin Pickle |
| C | Honeycomb Caves | L | Peekaboo Ridge | V | Whale's Rest |
| D | The Crackles | M | Jelly Meadow | W | The Overbite |
| E | Tickle Garden | N | Ribbon Roof | X | The Lift |
| F | Stripe Alley | O | Leafy Lane | Y | The Chimneys |
| G | The Snooze | P | Lookout Stack | Z | Slipstone Slope |
| H | Goby Flats | Q | Root Ball | 1 | The Blue Mile |
| I | Gull Rock | R | Glowgrove | 2 | The Crack |
| | | S | Hush Hollow | | |

The letters are map keys only. Each landmark's stable ID (`lm_<name>`) is in the ID column of its zone table (sections 6.2 to 6.6).

**Side view.** A west-to-east slice just north of the West and East Passes, bent at the east end to cross the Crack. One character is 30 studs wide; one row is 40 studs of depth.

```
depth  WEST                                                              EAST
       Kelp Forest    Rim         Sunlit Reef          Rim  Ledge Wall  Deep Floor
                      ^^^^^                           ^^^^^
   0   ~~~~~~~~~~~~~~~#####~~~~~~~~~~~~~~~~~~~~~~~~~~~#####~~~~~~~~~~~~~~~
  40     |  |  |  |  |#####            ###            #####
  80     |  |  |  | #########################################
 120     |  | #################################################
 160     ################### solid rock #######################
 200   #########################################################  Blue
 240   #########################################################  Mile
 280   #########################################################
 320   #########################################################  Scar's
 360   #########################################################  Run
 400   #########################################################
 440   ###########################################################
 480   ###############################################################   #
 520   ###############################################################   #
 560   ###############################################################   #
 600   ###################################################################
                                                                      ^^^ the Crack (Trench, [P2])
```

`~` is the surface. `^` is the Rim standing above the water. `|` are kelp stalks. The `###` in the middle of the Reef is Noggin Rock. The coves sit inside the two Rim blocks between depth 8 and 52.

### 6.2 Nursery Lagoon · [MVP]

| | |
|---|---|
| **Size** | Oval, 220 long (north-west to south-east) × 170 wide. Centre (−361, 361). |
| **Depth** | 0 to 30. Pale sand floor. |
| **Mood** | A paddling pool: warm turquoise water, bright sun, slow gentle music. Nothing scary is in sight. |
| **Rule (canon)** | Nobody can be eaten here. Creatures of tier 3 or higher cannot enter (document 02, section 6.5 has the mechanism). No predators, no hazards, and no trait prey except five scripted Glowfry during a new player's first run. Only a player's very first run starts here; every later run starts at the cove. Prey eaten here gives full mass at tier 1 and half at tier 2 (chapter 05, section 2.1). |
| **Spawns** | Plankton (cap 12 patches) everywhere. Krill (cap 5 swarms): 3 in Krill Corner, 2 around the Bubble Fountain. A first run adds chapter 04's scripted krill, plankton and Glowfry, drawn only for that player (first-run route, below). |

| Landmark | ID | Position (X, Z) · depth | Size | What it is |
|---|---|---|---|---|
| **Little Arch** | `lm_little_arch` | (−290, 290) · 6 to 28 | Opening 50 wide × 22 high, tunnel 25 long | The only way in or out. A pink coral arch with a row of small shell lights. Its Reef end opens into the Elbow (section 6.3). Chapter 04 calls it the Gap. |
| **Hatch Bed** | `lm_hatch_bed` | (−398, 340) · floor 24 | Sea-grass patch 10 across | Where a new player's egg hatches at the start of their very first run. Nothing starts here after that. |
| **Glow Grotto** | `lm_glow_grotto` | (−322, 301) · 10 to 26 | Rock shelf 24 wide that juts 15 out of the north-east wall | A shaded overhang 20 studs north-west of Little Arch. Empty, except for the five scripted Glowfry of a first run. |
| **Bubble Fountain** | `lm_bubble_fountain` | (−361, 361) · floor 28 | Ring of stones 12 across, bubble column 8 wide | A column of bubbles that lifts a creature to the surface and pops it into the air. Teaches the breach. |
| **Krill Corner** | `lm_krill_corner` | (−418, 304) · 12 to 20 | Sandy bowl 50 across | A bowl where krill always gather. Three krill swarms live here. |
| **Three Rings** | `lm_three_rings` | (−304, 418) · 15 | Three coral rings, each 14 across, 30 apart on a curve | Dash practice. A plankton patch sits inside each ring. |
| **Sleepy Clam** | `lm_sleepy_clam` | (−403, 403) · floor 30 | Giant clam 16 across | Opens and closes slowly and snores bubbles. A shell signpost beside it points to Little Arch. |
| **Baby Slide** | `lm_baby_slide` | From Sleepy Clam to Little Arch | Current 110 long, 12 wide | A short, gentle current (+60% speed). Teaches currents and carries leaving players to the exit. |

- **Links:** Little Arch only. Its Reef end opens into the Elbow, a 200-stud walled channel that ends 25 studs short of Goby Flats. Cove mouths C16 and C17 are each 140 studs from Little Arch.
- **Eel holes:** none.
- **Sight lines and hiding:** the whole pool can be seen from any point in it. Little Arch is visible from everywhere. There are no hiding places because none are needed. From the Reef end of Little Arch, looking over the Elbow's walls, Gull Rock and Noggin Rock are visible within fog range.

**First-run route · [MVP].** Chapter 04 scripts a new player's first run along this route and owns the beats; this table fixes the places. Distances are measured along the route from the Hatch Bed (tune). Inside the Nursery the route is one gentle arc (radius 140, turning 45° to the left), so the next target is always ahead on screen.

| Route point (chapter 04's name) | Distance along the route | Position (X, Z) · depth | What is there |
|---|---|---|---|
| Hatch Bed | 0 | (−398, 340) · floor 24 | The egg. The Fry hatches facing east, along the route. |
| Swarm A | 14 | (−384, 339) · 18 | 6 scripted krill |
| Plankton trail | 20 to 56 | (−378, 339) to (−344, 329) · 18 | 10 scripted motes, one every 4 studs |
| Swarm B | 60 | (−340, 327) · 18 | 14 scripted krill |
| Glow Grotto | 90 | Route point (−314, 312); grotto mouth (−322, 301) · 10 to 26 | 5 scripted Glowfry wait under the overhang |
| Kelp curtain | 110 | (−299, 299) · 6 to 28 | The Nursery end of Little Arch. A kelp curtain closes it until chapter 04's script opens it. Only a first-run player sees it or is stopped by it. |
| Little Arch ("the Gap") | 110 to 135 | (−299, 299) to (−281, 281) · 6 to 28 | The 25-stud tunnel. The Nursery ends at its Reef end, the 135 mark. |
| The Elbow, first leg ("the channel") | 135 to 235 | (−281, 281) to (−210, 210) · floor 30 down to 56 | Straight, heading north-east |
| The Elbow, bend | 235 | (−210, 210) · floor 56 | 40° to the right |
| The Elbow, second leg | 235 to 335 | (−210, 210) to (−110, 201) · floor 56 | Straight, heading just north of east |
| Home Current mouth | 335 | (−110, 201) · 30 | Where chapter 04's Home Current picks the player up. Section 6.7 gives the distances from here to the coves. |

- The route passes 27 studs north of the Bubble Fountain. Krill Corner is 40 studs behind the Hatch Bed.
- Predators never enter the Nursery, so chapter 04's scripted Barracuda waits on the Reef side: under a rock shelf on the Rim face at (−267, 295), 20 studs to the right of Little Arch's Reef end.
- The whole route is in the west half of the Reef, which has no real Barracuda and no anemones (section 6.3).

### 6.3 Sunlit Reef · [MVP]

| | |
|---|---|
| **Size** | Disc, radius 400. |
| **Depth** | Floor at 45 to 60 (sand and low coral). 30 coral heads rise to between depth 6 and 15. |
| **Mood** | A sunny playground: bright warm water, moving light beams, lots of colour and life. Busy, never threatening at first sight. |
| **Gentle side, risky side** | The west half (near the Nursery) has no Barracuda and no anemones. The east half has both. |

| Key | Landmark | ID | Position (X, Z) · depth | Size | What it is | What lives there |
|---|---|---|---|---|---|---|
| A | **Noggin Rock** | `lm_noggin_rock` | (0, 0) · top 6, base 50 | 70 across, 44 tall | A giant brain coral dome at the exact centre. Visible within fog range (chapter 15 caps the view at 220 studs on Smooth and 350 on Balanced), so not from every cove mouth; the home marker steers beyond that. | Sardine schools circle it. Crystal Jelly route starts here. Moon Tide site. |
| B | **The Hoop** | `lm_hoop` | (0, −330) · 15 to 45 | Opening 40 wide × 30 tall | A coral arch the Home Loop current runs through. Start of the North Chute. | Sardines, krill. 1 hook nearby. Moon Tide site. |
| C | **Honeycomb Caves** | `lm_honeycomb_caves` | (−200, −180) · 20 to 55 | Mound 90 across with 12 holes, each 5 across | A lumpy coral mound full of small dark holes. | Glowfry (6). Krill above it. |
| D | **The Crackles** | `lm_crackles` | (190, −190) · 40 to 58 | Rubble field, radius 80 | Broken grey rock full of cracks 2 to 3 studs deep. | Urchin Puff (6). Shrimp. On the Barracuda's arc. |
| E | **Tickle Garden** | `lm_tickle_garden` | (250, 0) · floor 48 | Radius 60 | A field of soft candy-coloured anemones [L]. In [MVP] it is a harmless soft-coral garden. | 14 anemones [L]. Darters between them. 1 hook nearby. |
| F | **Stripe Alley** | `lm_stripe_alley` | From (110, 110) to (215, 215) · 25 to 55 | 150 long, 24 wide | A narrow coral canyon with tall orange walls. | Zebra Darter (8). Darters. |
| G | **The Snooze** | `lm_snooze` | (60, 240) · surface | Rowboat hull 22 long | A small rowboat with "The Snooze" painted on it. Its dark hull shows from below. Five fishing lines hang from it. | 5 hooks at depth 8 to 20. |
| H | **Goby Flats** | `lm_goby_flats` | (−100, 100) · floor 45 | Open sand, radius 75 | A wide flat patch of pale sand with a few shells. | Dotted Goby (10). Shrimp. Krill above. |
| I | **Gull Rock** | `lm_gull_rock` | (−270, 20) · rises above the surface | 30 across, 10 above the water | A rock that breaks the surface, white on top, where the gulls sit. A navigation mark. | Gulls rest here. 1 hook nearby. |
| (route) | **The Elbow** | `lm_elbow` | From (−281, 281) through the bend at (−210, 210) to (−110, 201) · floor 30 at Little Arch, 56 beyond the first 40 studs | 200 long, 36 wide; walls 20 tall (tops at depth 36) | A walled channel with one 40° bend, running from Little Arch into the Reef and ending 25 studs short of Goby Flats. Smooth rock walls on both sides, open above. The Home Loop current crosses over its first leg, 3 studs clear of the wall tops. Chapter 04 calls it the channel. | Krill and plankton. Nothing dangerous. |

- **Other spawns:** krill swarms hang in mid-water over open sand all across the Reef. Shrimp hop on the floor between coral heads. Sardine schools circle Noggin Rock and the Hoop. Darters hover by coral heads, mostly in the east half. Plankton is everywhere.
- **Dangers:** Gulls at the surface everywhere. One Barracuda on the east arc (section 5.2). 8 hooks. 24 anemones [L].
- **Links:** North Pass and West Pass to the Kelp Forest. East Pass and South Pass to the Drop-off. Little Arch to the Nursery. Currents: Home Loop (around the Reef), North Chute and East Chute (outbound), Kelp Slide and Wall Run (inbound). Every cove mouth opens onto the Reef.
- **Eel holes:** four tunnels through the Rim (North, West, East and South Squeeze) and the Noggin Tube (section 6.9).
- **Sight lines:** open water with long views. Noggin Rock, Gull Rock and the hull of the Snooze are visible within fog range and are the three marks players steer by. The glowing door lantern of the player's own cove is visible within fog range; further out the home marker points to it.
- **Hiding places:** each coral head has 1 or 2 hollows, 8 studs across, that fit tier 1 to 3 creatures only (tune). Stripe Alley blocks sight from the sides. The holes in Honeycomb Caves fit tier 1 only.

### 6.4 Kelp Forest · [MVP]

| | |
|---|---|
| **Size** | Half ring, r 560 to r 1,000, from B225 clockwise through north to B045. |
| **Depth** | Floor at 70 beside the Rim, sloping down to 170 at the Blue. Kelp stalks are 60 to 140 tall. The canopy floats at depth 10 to 30. |
| **Mood** | A dim green hall: tall swaying stalks, slanting light shafts, quiet creaks. Calm but watchful. |
| **Kelp density** | About 260 stalks (tune) in three densities. Thick stands: stalks 10 apart. Open forest: 25 apart. Lanes: no stalks, 30 wide, used by Mackerel and Barracuda. |

| Key | Landmark | ID | Position (X, Z) · depth | Size | What it is | What lives there |
|---|---|---|---|---|---|---|
| J | **Old Anchor** | `lm_old_anchor` | (−640, 0) · floor 88 | Anchor 60 tall, chain to a buoy at the surface | A huge rusty anchor at the outer end of the West Pass. "Follow the chain home." | Sardines. End of the Kelp Slide. Feeding Frenzy bait-ball site. |
| K | **The Tall Stand** | `lm_tall_stand` | (−676, −390) · floor 120 | Thick stand, radius 140 | The densest, tallest kelp in the forest. | Darters. 2 Moray holes in floor rocks. |
| L | **Peekaboo Ridge** | `lm_peekaboo_ridge` | (−350, −606) · top 65, base 100 | Rock ridge 180 long, 35 tall | A long rock ridge with five dark holes facing the Kelp Slide. | 5 Morays. Shrimp along its base. |
| M | **Jelly Meadow** | `lm_jelly_meadow` | (−228, −850) · 40 to 110 | Clearing, radius 90 | An open clearing where pink jellies gather. | 3 jelly blooms. Start of the Kelp Slide. |
| N | **Ribbon Roof** | `lm_ribbon_roof` | (0, −800) · canopy 10 to 35 | Canopy patch, radius 130 | The thickest part of the canopy, like a green ceiling. | Ribbonfish (6). Sardines below. Moon Tide site. |
| O | **Leafy Lane** | `lm_leafy_lane` | (246, −677) · 50 to 90 | 200 long, 40 wide | A lane full of loose, drifting kelp leaves. | Leaf Drifter (5) [L]. Mackerel. Feeding Frenzy site. |
| P | **Lookout Stack** | `lm_lookout_stack` | (551, −551) · floor 120, rises above the surface | Rock stack 40 across | A tall rock pillar on the border with the Drop-off. From its east side the Wall falls away. | Darters. Crystal Jelly passes here. |
| Q | **Root Ball** | `lm_root_ball` | (−869, −233) · floor 150 | Dome 50 across, hollow | A giant tangle of kelp roots with a hollow inside. | 1 Moray. Shrimp. Eel tunnel start. |
| R | **Glowgrove** | `lm_glowgrove` | (−867, 76) · 90 to 140 | Dark pocket, radius 60 | A dark hollow where the stalks carry glowing algae. | Glowfry (4). Eel tunnel end. |
| S | **Hush Hollow** | `lm_hush_hollow` | (−771, 280) · floor 150 | Bowl, radius 80 | A quiet bowl-shaped clearing with a soft silt floor. | Armor Shrimp (6). Shrimp. Moon Tide site. |

- **Other spawns:** Shrimp on the floor everywhere. Sardine schools under the canopy. Darters inside stands. Mackerel run the lanes and the Kelp Slide.
- **Dangers:** 8 Morays, 2 Barracudas (loop A: Old Anchor to Hush Hollow; loop B: Leafy Lane to Lookout Stack), 4 jelly blooms.
- **Links:** North Pass (outbound current: North Chute) and West Pass (inbound current: Kelp Slide) to the Reef. To the Drop-off at two places with no current: past Lookout Stack in the north-east, and down Slipstone Slope in the south-west.
- **Eel holes:** North Squeeze and West Squeeze come out here. Root Run and Glow Run link the Root Ball and Glowgrove in two hops through the Halfway Stump. Peekaboo Back Way crosses the ridge behind the Morays.
- **Sight lines:** short. Thick stands block sight beyond 40 studs. Lanes give 140-stud views, which is where Barracudas hunt. The Old Anchor chain and Lookout Stack reach the surface and can be seen above the canopy.
- **Hiding places:** inside any thick stand (a Barracuda cannot turn between stalks 10 apart); the hollow of the Root Ball; the canopy of Ribbon Roof; the rim ledges of Hush Hollow.

### 6.5 The Drop-off · [MVP]

| | |
|---|---|
| **Size** | Half ring, r 560 to r 1,000, from B045 clockwise through south to B225. |
| **Three steps** | **The Ledge:** r 560 to 680, floor at depth 70 to 100. **The Wall:** r 680 to 720, a cliff from depth 100 down to 430. **The Deep Floor:** r 720 to 1,000, depth 430 to 480. |
| **Mood** | Big, cold and quiet. Blue turns to blue-black with depth. Far shapes move in the dark. The music thins out to low notes. |
| **In [MVP]** | Groupers, vents, Spark Eels and Vent Snails are absent. The Chimneys are cold stone. Whale's Rest is an empty bowl with a few old bones. |

| Key | Landmark | ID | Position (X, Z) · depth | Size | What it is | What lives there |
|---|---|---|---|---|---|---|
| (strip) | **The Ledge** | `lm_ledge` | r 560 to 680, all along the zone · 70 to 100 | 120 wide | A sunny rock shelf between the Rim and the cliff. Old Scar never comes up here. | Mackerel. 1 Grouper below the Ink Pots [L]. Feeding Frenzy and Moon Tide site at the East Pass. |
| T | **Ink Pots** | `lm_ink_pots` | (658, −239) · 140 to 320 | 8 round holes, each 10 across, over 180 of cliff height | Dark round pockets in the Wall, stained blue-black. | Inklet (5). 1 jelly bloom. |
| U | **The Tin Pickle** | `lm_tin_pickle` | (729, 128) · 220 to 260 | Hull 90 long, 30 wide, 40 tall | A small sunken tugboat, pickle green, lying on a rock shelf that sticks out of the Wall. Its name is on the bow. | Spark Eel (5) [L]. 1 Grouper [L]. Moon Tide site. |
| 1 | **The Blue Mile** | `lm_blue_mile` | Around (840, −225), B060 to B140 · 150 to 350 | Open water, 240 wide | A wide band of empty blue water above the Deep Floor. | Tuna. Bonito packs. 1 jelly bloom. Feeding Frenzy site. |
| V | **Whale's Rest** | `lm_whales_rest` | (655, 459) · floor 470 | Sandy bowl, radius 80 | A flat pale bowl on the Deep Floor. The Whale Fall site [L]. | Nothing between events. |
| W | **The Overbite** | `lm_overbite` | (239, 658) · 180 to 230 | Overhang 80 wide, sticks out 40 | A rock overhang shaped like a big lower jaw. | 2 Groupers [L]. Bonito pass below. |
| X | **The Lift** | `lm_lift` | (0, 730) · 440 up to 90 | Current column 16 wide | A rising current against the Wall, straight below the South Pass. The fast way home from the deep. | Mackerel ride it. |
| Y | **The Chimneys** | `lm_chimneys` | (−280, 771) · 450 to 470 | 9 chimneys within radius 70 | A cluster of black stone chimneys on the Deep Floor. | 9 vents [L]. Vent Snail (4) [L]. |
| Z | **Slipstone Slope** | `lm_slipstone_slope` | (−566, 566) · 150 down to 450 | Ramp 300 long, 120 wide | A smooth rock ramp on the border with the Kelp Forest. The only way to the Deep Floor without the cliff. | Mackerel. |
| (path) | **Scar's Run** | `lm_scars_run` | Wall face and Deep Floor, B055 to B215 · 250 to 420 | About 2,100 long | Old Scar's patrol path. Marked by long pale scrape marks on the rock. | Old Scar. |
| 2 | **The Crack** | `lm_crack` | r 900 to 980, B100 to B170 · 480 | 1,150 long, 80 wide | A long dark split in the Deep Floor, sealed by the Coldline. Mouth of the Trench [P2]. Until then it is sealed scenery. | Nothing until [P2]. |

- **Other spawns:** Mackerel on the Ledge and along its edge. Bonito packs along the Wall face at depth 120 to 300. Tuna in the Blue Mile. Plankton falls slowly at every depth as "sea snow".
- **Dangers:** Old Scar (1), Groupers (4) [L], jelly blooms (2), vents (9) [L].
- **Links:** East Pass (outbound current: East Chute) and South Pass (inbound current: Wall Run) to the Reef. The Lift carries creatures from the Deep Floor up to the South Pass. Lookout Stack and Slipstone Slope lead to the Kelp Forest.
- **Eel holes:** East Squeeze and South Squeeze come out on the Ledge. The Drainpipe runs from the Ledge down to the Tin Pickle. The Pickle Pipe runs through the wreck.
- **Sight lines:** up to 300 studs on the Ledge where the graphics tier's fog cap allows it (chapter 15), 180 below depth 150. From the outer end of the East Chute the player looks straight down on the Tin Pickle. Whale's Rest is visible within fog range. Old Scar's outline shows before its body does.
- **Hiding places:** the Ink Pots fit tier 4 and lower. The rooms of the Tin Pickle fit tier 5 and lower. Cracks in the Wall every 80 studs fit tier 3 and lower (tune). The whole Ledge is safe from Old Scar.

### 6.6 The Trench · [P2]

| | |
|---|---|
| **Size** | A curved crack about 1,150 long and 80 wide, at r 900 to 980 from B100 to B170. |
| **Depth** | 480 at the mouth to 600 at the bottom. |
| **Mood** | Black water lit only by living things. Slow, heavy, a little eerie but never horror: lights are soft blue and green. |
| **The Coldline** | A shimmering silver-blue layer across the Crack at depth 480. While closed, it pushes creatures up at 30 studs/s (tune). It parts during The Trench Opens (section 7.4). |
| **Spawns** | Section 2.3. Prey tiers 5 and 6 only (canon 6): there is no tier 7 prey. Plus 1 extra drift of five Crystal Jellies along the length of the Trench each opening, and 2 Vent Snails on Hot Row (tune). |
| **Dangers** | 2 Groupers, 2 jelly blooms, 4 vents. Old Scar follows creatures in. |

| Landmark | ID | Place · depth | What it is |
|---|---|---|---|
| **The Crack** | `lm_crack` | Whole length · 480 | The mouth. Jagged rock lips with the Coldline between them. |
| **Lantern Field** | `lm_lantern_field` | B110 · 500 to 540 | Hundreds of thin glowing stalks, soft green. The brightest place in the Trench. |
| **The Ribs** | `lm_ribs` | B135 · 500 to 580 | Huge old arched bones standing across the Trench like a row of gates. Clean, pale, coral-grown. |
| **Bubble Stairs** | `lm_bubble_stairs` | B120, B145 and B165 · 600 up to 480 | Three bubble columns that lift creatures back out. The exits. |
| **Hot Row** | `lm_hot_row` | B160 · 560 | A line of 4 cycling vents (section 5.1). |
| **The Quiet** | `lm_quiet` | B150 · 600 | The deepest point in the game: a round bowl of pale silt where Tuna gather. |

- **Links:** in and out through the Crack only. When the event ends, a cold surge lifts every creature out over 10 s; nobody can be trapped.
- **Eel holes:** none.
- **Sight lines and hiding:** 90 studs. Creatures are seen by their own glow first. Hiding places are between the Ribs and inside the Lantern Field.

### 6.7 The Rim and the 24 cove mouths · [MVP]

The Rim is a ring of pale rock from r 400 to r 560. Its top stands 12 studs above the surface, so nothing can jump over it. Its inner face holds the 24 cove mouths. Low palms, gull nests and tide pools on top are scenery only.

**Openings through the Rim**

| Opening | Centre bearing | Size | Leads to | Current |
|---|---|---|---|---|
| North Pass | B000 | 64 wide, depth 5 to 55, 160 long | Kelp Forest, toward Ribbon Roof | North Chute, outbound |
| East Pass | B090 | Same | The Ledge, above the Tin Pickle | East Chute, outbound |
| South Pass | B180 | Same | The Ledge, above the Lift | Wall Run, inbound |
| West Pass | B270 | Same | Kelp Forest, at Old Anchor | Kelp Slide, inbound |
| Little Arch | B225 | 50 wide, depth 6 to 28, 25 long | Nursery Lagoon. Its Reef end opens into the Elbow. | None |

The rule players learn: **out by north and east, home by west and south.**

**Cove mouths.** Each mouth is on the inner face at r 400, centred at depth 30. Coves are numbered clockwise from north.

| Cove | Bearing | Mouth (X, Z) | Nearest opening · distance | Cove | Bearing | Mouth (X, Z) | Nearest opening · distance |
|---|---|---|---|---|---|---|---|
| C01 | B012 | (83, −391) | North Pass · 84 | C13 | B157 | (156, 368) | South Pass · 161 |
| C02 | B023 | (156, −368) | North Pass · 161 | C14 | B168 | (83, 391) | South Pass · 84 |
| C03 | B034 | (224, −332) | North Pass · 237 | C15 | B194 | (−97, 388) | South Pass · 98 |
| C04 | B045 | (283, −283) | North or East Pass · 314 | C16 | B205 | (−169, 363) | Little Arch · 140 |
| C05 | B056 | (332, −224) | East Pass · 237 | C17 | B245 | (−363, 169) | Little Arch · 140 |
| C06 | B067 | (368, −156) | East Pass · 161 | C18 | B256 | (−388, 97) | West Pass · 98 |
| C07 | B078 | (391, −83) | East Pass · 84 | C19 | B285 | (−386, −104) | West Pass · 105 |
| C08 | B102 | (391, 83) | East Pass · 84 | C20 | B297 | (−356, −182) | West Pass · 188 |
| C09 | B113 | (368, 156) | East Pass · 161 | C21 | B309 | (−311, −252) | West Pass · 272 |
| C10 | B124 | (332, 224) | East Pass · 237 | C22 | B321 | (−252, −311) | North Pass · 272 |
| C11 | B135 | (283, 283) | East or South Pass · 314 | C23 | B333 | (−182, −356) | North Pass · 188 |
| C12 | B146 | (224, 332) | South Pass · 237 | C24 | B345 | (−104, −386) | North Pass · 105 |

Coves are spaced 11° apart (12° in the north-west arc), which is 77 to 84 studs between mouths.

**What a cove mouth looks like**

| Part | Brief |
|---|---|
| **Mouth** | A rounded cave opening 36 wide × 28 high, with a 25-stud throat behind it. Big enough for a tier 7 creature. |
| **Name Shell** | A scallop-shaped sign, 14 wide, above the mouth. Shows the owner's name and, from [L], their Reef Rank title. |
| **Trophy Bubble** | A 10-stud bubble beside the sign holding a slowly turning model of the owner's best specimen, with its traits. |
| **Door Lantern** | A lantern on a stalk. Lantern amber (the canon colour for home) with a tall beam of light to the surface for the player's own cove; teal for friends; lantern warm white (`#FFF1DC`, chapter 06, section 4.5) for others; dark for an empty cove. |
| **Bubble Count** [L] | A small cluster of bubbles under the sign with the number of Bubbles the cove has received. |
| **Empty cove** | A kelp curtain hangs across the mouth. No sign, no lantern. |

**Cove assignment** (chapter 04, section 5.5 owns the rule): a new player (an account that has never banked) gets the free cove nearest the Nursery gap, Little Arch, in the order C16, C17, C15, C18, then the next nearest. A returning player (an account that has banked before) gets the free cove farthest from Little Arch among the 20 coves nearest to it, so the four closest stay free for newcomers where possible (tune). A player who joined a friend gets the nearest free cove to that friend's instead [L].

**First-run route: the trip home.** Chapter 04's Home Current starts at the far end of the Elbow, (−110, 201), 335 studs along the first-run route (section 6.2), and ends 30 studs short of the newcomer's cove mouth. It is drawn only for that player and is gone after the first bank. Straight-line lengths (tune):

| Cove | Mouth (X, Z) | Elbow end to mouth | Home Current length |
|---|---|---|---|
| C16 | (−169, 363) | 172 | 142 |
| C15 | (−97, 388) | 187 | 157 |
| C17 | (−363, 169) | 255 | 225 |
| C18 | (−388, 97) | 297 | 267 |

All four are inside chapter 04's limit of 450 studs, and each path stays in the west half of the Reef. Chapter 04 may bow the current toward Noggin Rock to lengthen the ride; any path up to 450 studs fits. The farthest coves (C01 to C04) are 620 to 650 studs from the Elbow's end, which falls under chapter 04's rule for routes over 600.

### 6.8 Currents and paths · [MVP]

All currents are one-way, 16 studs wide, and give riders +60% speed (canon). Creatures can swim through a pass in either direction; the current only helps one way.

| ID | Name | From → to | Path | Length (studs) |
|---|---|---|---|---|
| `cur_home_loop` | Home Loop | Around the Reef, clockwise | A circle at r 330, depth 25, through the Hoop. Passes 70 studs from every cove mouth. | 2,070 |
| `cur_north_chute` | North Chute | Reef → Kelp Forest | From the Hoop (0, −330) north through the North Pass to (0, −700). Depth 30 down to 60. | 370 |
| `cur_kelp_slide` | Kelp Slide | Kelp Forest → Reef | From Jelly Meadow's edge (B340 r760) anticlockwise along r 760 past Peekaboo Ridge and the Tall Stand to Old Anchor, then east through the West Pass to (−330, 0). Depth 60 to 90. | 1,290 |
| `cur_east_chute` | East Chute | Reef → the Ledge | From (330, 0) east through the East Pass to the Ledge edge at (680, 0). Depth 30 down to 85. | 350 |
| `cur_wall_run` | Wall Run | The Ledge → Reef | From (680, 0) clockwise along the Ledge edge at r 660 to B175, then north through the South Pass to (0, 330). Depth 85. | 1,250 |
| `cur_lift` | The Lift | Deep Floor → the Ledge | Straight up at (0, 730) from depth 440 to 90, then north to join the Wall Run at the South Pass. | 520 |

The Baby Slide in the Nursery (section 6.2) is a seventh, tutorial-sized current. Chapter 04's Home Current (section 6.7) is not on this list: it exists only for one player during their first run.

**Example trips for a tier 1 Fry riding currents (41.6 studs/s):** one full lap of the Home Loop takes 50 s; Hoop to the end of the North Chute takes 9 s. **For a tier 5 Brute (54.4 studs/s):** Deep Floor to the South Pass by the Lift takes 10 s; the whole Wall Run takes 23 s.

**Paths with no current:** Lookout Stack (Kelp ↔ Drop-off, north-east), Slipstone Slope (Kelp ↔ Deep Floor, south-west), and every pass against its current.

### 6.9 Eel holes · [MVP]

Only the Eel can enter (canon). The rule is by species, not by size: an Eel of any tier fits. Tunnels are 7 studs across. Each end is marked by a ring of blue barnacles that glows teal for Eel players and is dull for everyone else.

| ID | Name | End A | End B | Length | Why use it |
|---|---|---|---|---|---|
| `eh_north` | North Squeeze | Reef, Rim face between C02 and C03 (B028), depth 40 | Kelp side of the Rim at B028, depth 70, near Leafy Lane | 165 | Skips the North Pass |
| `eh_west` | West Squeeze | Reef, between C20 and C21 (B303), depth 40 | Kelp side at B303, depth 70, near the Tall Stand | 165 | Skips the West Pass |
| `eh_east` | East Squeeze | Reef, between C09 and C10 (B118), depth 40 | The Ledge at B118, depth 80 | 165 | Skips the East Pass |
| `eh_south` | South Squeeze | Reef, between C15 and C16 (B200), depth 40 | The Ledge at B200, depth 80, near the Lift | 165 | Fast way home from the Chimneys |
| `eh_noggin` | Noggin Tube | West side of Noggin Rock, depth 35 | East side of Noggin Rock, depth 35 | 70 | A hiding place in the middle of the Reef |
| `eh_root` | Root Run | Inside the Root Ball at (−869, −233), depth 145 | The Halfway Stump, a mossy rock stump on the Kelp floor at (−868, −78), depth 140 | 160 | First half of the way to Glowgrove; leaves the Root Ball without passing its Moray |
| `eh_glow` | Glow Run | The Halfway Stump at (−868, −78), depth 140, 10 studs from Root Run's end | Glowgrove at (−867, 76), depth 120 | 160 | Second half; avoids Barracuda loop A |
| `eh_peekaboo` | Peekaboo Back Way | North side of Peekaboo Ridge | South side, behind the Moray holes | 40 | Crosses the ridge without passing a Moray |
| `eh_drain` | The Drainpipe | The Ledge floor at (670, 60), depth 95 | The Wall beside the Tin Pickle at (700, 120), depth 230 | 150 | Escapes Old Scar up to the Ledge |
| `eh_pickle` | Pickle Pipe | The Tin Pickle's smokestack | The hull breach on its far side | 60 | Reaches Spark Eels inside the wreck |

There are 10 tunnels. Every tunnel is under 180 studs, so a transit at 60 studs/s takes under 3 s (document 02, section 7.4). The Root Ball and Glowgrove are 309 studs apart, so that route is two tunnels that meet at the Halfway Stump: an Eel comes out of one and can turn straight into the other. The Halfway Stump is a tunnel end only, not a Codex place.

### 6.10 A cove interior · [MVP]

All 24 coves share one layout. Document 09 decides whether a cove is built in place inside the Rim or loaded separately; the sizes are the same either way.

| | |
|---|---|
| **Size** | Oval chamber 76 wide × 110 long × 44 high, behind a 25-stud throat. Floor at depth 52, ceiling at depth 8. |
| **Mood** | A snug, warm cave: pale sandstone, a soft sand floor, light falling through cracks in the ceiling. Quiet, safe, yours. |
| **Rule (canon)** | Nobody can be eaten here. Nothing spawns here. |

| Part | Place in the chamber | Brief | Tag |
|---|---|---|---|
| **Throat** | Entrance | The tunnel from the mouth. Swimming through it in your own cove banks the run. | [MVP] |
| **Home Stone** | 15 studs inside, centre | A flat round stone with a spiral mark. Where the player's Fry appears at the start of a run. | [MVP] |
| **Pearl Clam** | Left of the Home Stone | A large clam that fills with Pearls as the cove earns. It opens when the owner swims near, to show the pile; the owner claims by tapping the pile (canon 11). Swimming to it or past it never claims. Fuller clam, bigger pile. | [MVP] |
| **Specimen perches** | Along both side walls, 4 rows of 5 per side | 40 marked spots, one per cove slot (canon 11: 6 at the start, 30 with Pearls, 40 with the Bigger Cove pass). A specimen swims a slow 6-stud loop at its perch. Perch 1 is slot 1, and so on. "Perch" is the one name for this part (not "alcove"). Locked perches are covered by a kelp net. The lower three rows are slots 1 to 30; the top row is the 10 Bigger Cove slots and shows a pass mark on its nets. | [MVP] |
| **Bank camera point** (`BankCam`) | 30 studs inside, by the right wall, 12 above the floor | Where the camera sits while the bank results show, looking back at the Home Stone and the throat (document 02). | [MVP] |
| **Trophy Rock** | Centre back | A raised rock with a light beam. The best specimen swims above it. The same specimen shows in the Trophy Bubble outside. | [MVP] |
| **Codex Stone** | Right of the Home Stone | An open stone book with glowing pages. Opens the Codex. | [MVP] |
| **Species Wall** | Back wall, left of the Trophy Rock | A smooth patch of wall where the next species the player can unlock shows as a dark silhouette inside a progress ring (Pearls owned out of its price). Tapping it opens that species' card. Chapter 04 lights it at the first bank. | [MVP] |
| **Tide clock** | Back wall, right of the Trophy Rock | A shell clock with a hand and four picture plates. It shows the next tide event and its countdown, and nothing more. Every cove has one for free; chapter 04 reveals it at the first bank. | [MVP] |
| **Bubble Jar** | Beside the throat | A glass jar that fills with the Bubbles visitors leave. | [L] |
| **Decoration spots** | Floor, walls and ceiling | 10 small floor spots, 6 medium floor spots, 3 large floor spots, 6 wall spots, 4 ceiling spots (tune). Section 13. | [L] |
| **Visitor lane** | Throat to Trophy Rock | The middle strip of the chamber. Visitors stay on it and look; they cannot touch anything. | [L] |

**Specimen display size (tune):** a specimen is shown smaller than it was in the run so 40 fit. Display scale = 0.8 + 0.35 × tier. A tier 2 Minnow is about 4.5 studs long; a tier 7 Minnow is about 9.8 studs long. Traits and patterns are shown in full.

- **Sight lines:** the whole chamber is visible from the Home Stone. Looking out through the throat, the player sees the Reef, and Noggin Rock when it is within fog range.
- **Hiding places and eel holes:** none.

### 6.11 Revive points · [MVP]

Document 02 (section 12.3) returns a revived or reconnecting creature to the place it was gulped, unless something that can eat it is within 60 studs; then it uses the nearest of these 12 points that passes the same test. Every point is in open water away from predator paths and hazards, and the four Drop-off points are on the Ledge, where Old Scar never comes (tune).

<!-- data:RevivePoints -->
Soft-launch slice (chapter 13, section 3.2): `rp_01`, `rp_02`, `rp_03`, `rp_04`, `rp_05`, `rp_06`, `rp_07`, `rp_08`.

| ID | Zone | Place | Position (X, Z) · depth |
|---|---|---|---|
| `rp_01` | Sunlit Reef | West side of Noggin Rock | (−60, 0) · 30 |
| `rp_02` | Sunlit Reef | South of the Hoop | (0, −280) · 30 |
| `rp_03` | Sunlit Reef | Over Goby Flats | (−100, 100) · 30 |
| `rp_04` | Sunlit Reef | East of Noggin Rock | (120, 40) · 30 |
| `rp_05` | Kelp Forest | Glowgrove | (−867, 76) · 100 |
| `rp_06` | Kelp Forest | Under Ribbon Roof | (0, −800) · 45 |
| `rp_07` | Kelp Forest | Inside the Tall Stand, mid-height | (−676, −390) · 70 |
| `rp_08` | Kelp Forest | Canopy edge between Ribbon Roof and Leafy Lane | (120, −760) · 45 |
| `rp_09` | The Drop-off | The Ledge, north of the East Pass | (600, −60) · 75 |
| `rp_10` | The Drop-off | The Ledge, west of the South Pass | (−70, 610) · 75 |
| `rp_11` | The Drop-off | The Ledge at B135 | (438, 438) · 80 |
| `rp_12` | The Drop-off | The Ledge at B200, by the South Squeeze | (−212, 583) · 80 |

<!-- /data -->

## 7. Tide events

The schedule, the 60-second warning and the 4-minute length are canon (section 10): :00 Feeding Frenzy, :15 Moon Tide, :30 Feeding Frenzy, :45 Whale Fall. Until Whale Fall ships at launch, the :45 slot in the MVP runs a second Moon Tide. Document 02 owns the timing logic and document 08 owns the banners. Shared content for every event: a deep bell rings at the warning (`SFX_TideBell`), the water colour starts to shift during the warning, and it shifts back over 10 s when the event ends.

### 7.1 Feeding Frenzy · `frenzy` · [MVP]

| | |
|---|---|
| **What changes** | Respawn time of all eight prey is divided by 3 and live caps are doubled, in every zone (tune). Trait prey are unchanged. |
| **Extra spawns: bait balls** | Six big groups appear at the start and each returns once, 90 s after it is eaten (tune). |
| **Reef** | 2 sardine bait balls of 40: at Noggin Rock and at the Hoop. |
| **Kelp Forest** | 1 sardine bait ball of 40 at Old Anchor. 1 mackerel run of 12 along Leafy Lane. |
| **Drop-off** | 1 mackerel ball of 20 on the Ledge at the East Pass. 1 bonito pack of 10 in the Blue Mile. |
| **Nursery** | Krill cap rises from 5 swarms to 10. |
| **Predators** | Up to 5 Gull dives at once instead of 3, drawn by the bait balls. Others unchanged. |
| **Look** | Warm golden tint in the water. Thick glittering plankton. A cloud of gulls wheels over the Reef. Bait balls flash silver as they turn. Faster, bouncy music. |

### 7.2 Moon Tide · `moon_tide` · [MVP]

| | |
|---|---|
| **What changes** | The sea goes dark: light drops to about 25% of normal. A large moon shows through the surface. Everything that glows gets brighter: plankton turns cyan, jelly blooms and all Light-layer traits shine. |
| **Moonbeams** | Three pillars of moonlight, each 50 across, from the surface to the floor (or to depth 120 over deep water). One per zone. |
| **Moonbeam sites** | Each zone has two sites and swaps between them by the UTC hour. Even hours: Noggin Rock (Reef), Ribbon Roof (Kelp), the Ledge at the East Pass (Drop-off). Odd hours: the Hoop (Reef), Hush Hollow (Kelp), the Tin Pickle (Drop-off). |
| **Lunar Fry** | 40 per event, enough for 8 players to gain Moonlit (chapter 05, section 2.1 owns the count). Each beam starts with 4. Then 1 more appears every 7 s, at the beam with the fewest alive, until 40 have been released. A beam never holds more than 4 at once. |
| **Predators** | Gulls sleep: no Gull dives during Moon Tide (tune). Jelly blooms are easier to see. Others unchanged. |
| **Look** | Deep blue-black water, silver moonbeams full of slow drifting motes, glowing cyan plankton like stars. Quiet, slow music with chimes. |

### 7.3 Whale Fall · `whale_fall` · [L]

| | |
|---|---|
| **Warning (60 s)** | Slow whale song. A huge shadow passes across the surface above Whale's Rest. |
| **The skeleton** | A clean white whale skeleton, 60 long × 22 wide × 18 tall, with soft glowing algae on the ribs. It sinks from the surface to Whale's Rest (depth 470) over 25 s and lands with a puff of silt. No flesh, no red. |
| **Marrow chunks** | 60 per event (chapter 05, section 2.1 owns the count): 20 when the skeleton lands, then 10 more at 40 s, 80 s, 120 s and 160 s. Each drifts up and out from the ribs for 60 s. Mass 40 each (tune). |
| **Extra prey** | 3 bonito packs and 1 tuna circle the skeleton at 100 to 150 studs. |
| **Predators** | Old Scar leaves Scar's Run and circles the skeleton at a radius of 90 studs, depth 380 to 460. The 4 Groupers move to within 50 studs of it and 2 more appear (6 in all). |
| **After the event** | The skeleton stays as scenery until the next event's warning, then breaks up into bubbles. Old Scar and the Groupers go home; the 2 extra Groupers leave. |
| **Look** | A pale beam of light follows the skeleton down. The algae on the bones glows soft white-green. Marrow chunks glow as they rise. Slow, grand music. |

### 7.4 Post-launch events

After launch the :30 slot is the flexible one (canon 10): these events replace its Feeding Frenzy when they run. Document 12 owns the calendar. All numbers (tune).

| ID | Tag | Event | What spawns, where, how many | Changes to the world | Look | Reward |
|---|---|---|---|---|---|---|
| `storm` | [P1] | Storm | Lightning hits a random surface point in the Reef or Kelp every 8 to 12 s. Each strike leaves 2 Spark Eels at depth 5 to 20 (at most 12 alive). | A strike is shown by a bright ring 20 studs wide for 1.5 s; a creature inside it and within 15 studs of the surface is stunned 2 s and loses 10% of mass. Currents run at +120% instead of +60%. No Gulls. Hooks are pulled up. | Dark surface, rain rings, rolling waves, white flashes. View distance −30%. | Spark trait in shallow water |
| `trench_opens` | [P2] | The Trench Opens | Everything in section 6.6. | The Coldline parts for 4 minutes. At 3 min 30 s the water at the bottom turns pale as a warning. At the end, a cold surge lifts every creature out over 10 s. | A line of silver light opens along the Crack and is visible within fog range. | Densest tier 5 and 6 prey, a second Crystal Jelly drift |
| `red_tide` | [P1] | Red Tide | A rust-red cloud covers one zone per event, in the order Reef, Kelp, Drop-off. Inside it: 2 extra Barracudas (Reef, Kelp) or 2 extra Groupers (Drop-off). | Inside the cloud all eight prey give ×2 mass and view distance drops to 70 studs. Outlines stay on. | Rust-red water with slow swirling flecks. The edge of the cloud is a clear wall of colour. | Fast growth at higher risk |
| `migration` | [P1] | Great Migration | One river of prey 600 studs long: 120 Sardines, 40 Mackerel, 20 Bonito and 4 Tuna. It enters at B315 r1000, passes the Tall Stand, the West Pass, Noggin Rock, the East Pass and the Blue Mile, and leaves at B120 r1000. It moves at 9 studs/s and takes the whole event. | Both Kelp Barracudas follow it through the forest. Old Scar meets it at the Wall. Prey in the river does not respawn. | A shining silver ribbon of fish crossing the whole map, with a rising drum beat. | Huge mass for players who follow it |

## 8. Codex

Canon 11 lists the Codex categories: Species, Tiers (one page per species), Traits and Prey at [MVP], plus Dangers, Places and Tides at [L]. An entry shows as a grey outline until it is filled.

### 8.1 Categories and rewards

Pearl amounts are chapter 05's (section 3.8) and are paid once per account. The decorations, patterns, titles and badge are this chapter's. Decoration rewards arrive with decorations at [L]; a player who finished a category in [MVP] gets them then.

<!-- data:Codex -->
Soft-launch slice (chapter 13, section 3.2): `cdx_species`, `cdx_tiers`, `cdx_traits`, `cdx_prey`.

| ID | Category | Tag | Entries at MVP | Entries at launch | How an entry is filled | Pearls per entry (chapter 05) | Reward for completing the category | Reward decoration (section 13) |
|---|---|---|---|---|---|---|---|---|
| `cdx_species` | Species | [MVP] | 3 | 6 | Start a run as the species | None | Family Portrait decoration + Pearls R3 (175) | `deco_cdx_family_portrait` |
| `cdx_tiers` | Tiers | [MVP] | 21 | 42 | Reach the tier in a run as that species (no banking needed) | Tiers 2 to 7: 25 / 50 / 100 / 200 / 400 / 800 | Per species page (7 tiers): 500 Pearls + that species' Codex pattern (section 1.3). All pages: title "Leviathan Maker" + Pearls R5 (5,000) | None |
| `cdx_traits` | Traits | [MVP] | 9 | 13 | Gain the trait in a run | Common 100, Uncommon 200, Rare 400, Epic 800, Mythic 1,500 | Trait Totem decoration + Pearls R4 (2,500) | `deco_cdx_trait_totem` |
| `cdx_prey` | Prey | [MVP] | 17 | 21 | Eat one | Ordinary prey 20, trait prey 30 | Prey Mobile decoration + Pearls R3 (175) | `deco_cdx_prey_mobile` |
| `cdx_dangers` | Dangers | [L] | None | 9 | Come within 30 studs of it, or get caught by it | None | Danger Board decoration + Pearls R3 (175) | `deco_cdx_danger_board` |
| `cdx_places` | Places | [L] | None | 30 | Swim within 40 studs of the landmark (entry key: its `lm_*` ID) | None | Sea Globe decoration + Pearls R3 (175) | `deco_cdx_sea_globe` |
| `cdx_tides` | Tides | [L] | None | 3 | Eat 10 prey during the event | None | Tide Chart decoration + Pearls R2 (125) | `deco_cdx_tide_chart` |
| `cdx_all` | Whole Codex | [L] | 50 | 124 | Complete every category above | None | Badge "Know-It-All" + title "Reef Scholar" + Pearls R5 (5,000) | None |

<!-- /data -->

Post-launch species, traits, places and events add entries to their categories. A category that was complete stays rewarded; each new entry pays the per-entry amount for its category.

### 8.2 Entry lists

| Category | Entries |
|---|---|
| **Species** | [MVP] Minnow, Pufferfish, Eel. [L] Sea Turtle, Squid, Shark Pup. |
| **Tiers** | One page per species, each with 7 entries: Fry, Nibbler, Snapper, Hunter, Brute, Titan, Leviathan. Shark Pup's Fry entry is filled on first play, because it starts at tier 2. |
| **Traits** | [MVP] Glow, Stripes, Spots, Plated, Spiny, Longfin, Ink, Crystal, Moonlit. [L] Spark, Camo, Ember, Bonefed. |
| **Prey** | [MVP] Plankton mote, Krill, Tiny Shrimp, Sardine, Reef Darter, Mackerel, Bonito, Tuna, Glowfry, Zebra Darter, Dotted Goby, Armor Shrimp, Urchin Puff, Ribbonfish, Inklet, Crystal Jelly, Lunar Fry. [L] Spark Eel, Leaf Drifter, Vent Snail, Marrow chunk. |
| **Dangers** | [L] Gull, Moray, Barracuda, Grouper, Old Scar, Jelly bloom, Anemone, Thermal vent, Fishing hook. |
| **Places** | [L] Nursery: Little Arch. Reef: Noggin Rock, the Hoop, Honeycomb Caves, the Crackles, Tickle Garden, Stripe Alley, the Snooze, Goby Flats, Gull Rock. Kelp: Old Anchor, the Tall Stand, Peekaboo Ridge, Jelly Meadow, Ribbon Roof, Leafy Lane, Lookout Stack, Root Ball, Glowgrove, Hush Hollow. Drop-off: the Ledge, Ink Pots, the Tin Pickle, the Blue Mile, Whale's Rest, the Overbite, the Lift, the Chimneys, Slipstone Slope, the Crack. Each entry is saved under the landmark's ID from sections 6.2 to 6.5 (`lm_little_arch`, `lm_noggin_rock` … `lm_crack`). The other landmarks (the rest of the Nursery, the Elbow, Scar's Run and the Trench landmarks) have IDs but are not Codex entries. |
| **Tides** | [L] Feeding Frenzy, Moon Tide, Whale Fall. |

## 9. Daily goals · [MVP]

Three goals a day (canon): one Easy, one Medium, one Hard. Reward band follows difficulty: Easy = R1 (100 Pearls), Medium = R2 (125), Hard = R3 (175), and R1 (100) more when all three are done. Chapter 05, section 3.5 owns these amounts and multiplies them by the rank multiplier. Document 02 owns how goals are picked; the **Needs** column lists what must be true before a goal can be offered. Targets are (tune).

<!-- data:Goals -->
Soft-launch slice (chapter 13, section 3.2): `dg_eat_50`, `dg_krill_30`, `dg_plankton_100`, `dg_shrimp_15`, `dg_sardine_15`, `dg_dash_25`, `dg_runs_3`, `dg_bank_1`, `dg_tier3`, `dg_current_3`, `dg_breach_5`, `dg_trait_1`, `dg_tier4`, `dg_bank_snapper`, `dg_bank_mass_300`, `dg_darter_10`, `dg_mackerel_8`, `dg_kelp_20`, `dg_trait_prey_10`, `dg_traits_2`, `dg_bank_common`, `dg_frenzy_40`, `dg_survive_300`, `dg_species_2`, `dg_player_1`, `dg_tier5`, `dg_tier6`, `dg_bank_brute`, `dg_bank_mass_1000`, `dg_bank_3_traits`, `dg_bank_uncommon`, `dg_players_3`.

| ID | Text | Target | Difficulty | Reward | Needs | Tag |
|---|---|---|---|---|---|---|
| `dg_eat_50` | Eat 50 prey | 50 | Easy | R1 | Nothing | [MVP] |
| `dg_krill_30` | Eat 30 Krill | 30 | Easy | R1 | Nothing | [MVP] |
| `dg_plankton_100` | Eat 100 Plankton motes | 100 | Easy | R1 | Nothing | [MVP] |
| `dg_shrimp_15` | Eat 15 Tiny Shrimp | 15 | Easy | R1 | Nothing | [MVP] |
| `dg_sardine_15` | Eat 15 Sardines | 15 | Easy | R1 | Nothing | [MVP] |
| `dg_dash_25` | Dash 25 times | 25 | Easy | R1 | Nothing | [MVP] |
| `dg_runs_3` | Start 3 runs | 3 | Easy | R1 | Nothing | [MVP] |
| `dg_bank_1` | Bank 1 creature | 1 | Easy | R1 | Nothing | [MVP] |
| `dg_tier3` | Grow into a Snapper | 1 | Easy | R1 | Nothing | [MVP] |
| `dg_current_3` | Ride 3 currents | 3 | Easy | R1 | Nothing | [MVP] |
| `dg_breach_5` | Jump out of the water 5 times | 5 | Easy | R1 | Nothing | [MVP] |
| `dg_trait_1` | Gain 1 trait | 1 | Easy | R1 | Nothing | [MVP] |
| `dg_tier4` | Grow into a Hunter | 1 | Medium | R2 | Nothing | [MVP] |
| `dg_bank_snapper` | Bank a Snapper or bigger | 1 | Medium | R2 | Nothing | [MVP] |
| `dg_bank_mass_300` | Bank 300 mass in total | 300 | Medium | R2 | Nothing | [MVP] |
| `dg_darter_10` | Eat 10 Reef Darters | 10 | Medium | R2 | Nothing | [MVP] |
| `dg_mackerel_8` | Eat 8 Mackerel | 8 | Medium | R2 | Nothing | [MVP] |
| `dg_kelp_20` | Eat 20 prey in the Kelp Forest | 20 | Medium | R2 | Nothing | [MVP] |
| `dg_trait_prey_10` | Eat 10 trait prey | 10 | Medium | R2 | Nothing | [MVP] |
| `dg_traits_2` | Hold 2 traits at once | 2 | Medium | R2 | Nothing | [MVP] |
| `dg_bank_common` | Bank a creature with a Common trait | 1 | Medium | R2 | Nothing | [MVP] |
| `dg_frenzy_40` | Eat 40 prey during a Feeding Frenzy | 40 | Medium | R2 | Nothing | [MVP] |
| `dg_dropoff_home` | Visit the Drop-off, then bank | 1 | Medium | R2 | Nothing | [MVP] |
| `dg_survive_300` | Survive 5 minutes in one run | 300 s | Medium | R2 | Nothing | [MVP] |
| `dg_gull_dodge_3` | Dodge 3 Gull dives | 3 | Medium | R2 | Nothing | [MVP] |
| `dg_moray_dodge_3` | Dodge 3 Moray lunges | 3 | Medium | R2 | Nothing | [MVP] |
| `dg_species_2` | Bank 2 different species | 2 | Medium | R2 | Owns 2 or more species | [MVP] |
| `dg_player_1` | Eat 1 other player | 1 | Medium | R2 | 6 or more players on the server | [MVP] |
| `dg_visit_3` | Visit 3 other coves | 3 | Medium | R2 | 4 or more players on the server | [L] |
| `dg_tier5` | Grow into a Brute | 1 | Hard | R3 | Nothing | [MVP] |
| `dg_tier6` | Grow into a Titan | 1 | Hard | R3 | Has reached Brute before | [MVP] |
| `dg_bank_brute` | Bank a Brute or bigger | 1 | Hard | R3 | Nothing | [MVP] |
| `dg_bank_mass_1000` | Bank 1,000 mass in total | 1,000 | Hard | R3 | Nothing | [MVP] |
| `dg_bank_3_traits` | Bank a creature with 3 traits | 1 | Hard | R3 | Nothing | [MVP] |
| `dg_bank_uncommon` | Bank an Uncommon trait or better | 1 | Hard | R3 | Nothing | [MVP] |
| `dg_bank_rare` | Bank a Rare trait or better | 1 | Hard | R3 | Has reached Hunter before | [MVP] |
| `dg_bonito_6` | Eat 6 Bonito | 6 | Hard | R3 | Has reached Brute before | [MVP] |
| `dg_tuna_1` | Eat 1 Tuna | 1 | Hard | R3 | Has reached Titan before | [MVP] |
| `dg_lunar_3` | Eat 3 Lunar Fry | 3 | Hard | R3 | Nothing | [MVP] |
| `dg_players_3` | Eat 3 other players | 3 | Hard | R3 | 6 or more players on the server | [MVP] |
| `dg_scar_escape` | Escape a chase by Old Scar | 1 | Hard | R3 | Has reached Hunter before | [MVP] |
| `dg_marrow_3` | Eat 3 Marrow chunks | 3 | Hard | R3 | Has reached Snapper before | [L] |

<!-- /data -->

Content limits for the picker: no more than one goal a day that needs eating players; never the same goal two days running; a brand-new account's first day is always the fixed set `dg_eat_50` (Easy), `dg_tier3` (Easy) and `dg_bank_snapper` (Medium), which chapter 04 (section 7.2) builds the first session on. That day is the one exception to "one Easy, one Medium, one Hard" and pays 425 Pearls in full (chapter 05, section 3.5). Finishing all three goals in a day gives a bonus (Pearls R1, 100).

## 10. Login streak · [L]

A 7-box calendar (canon 11). Each day played opens the next box. A missed day never resets it: the next box simply waits. After box 7 the calendar starts again. The amounts are chapter 05's (section 3.6) and are multiplied by the rank multiplier.

| Box | 1 | 2 | 3 | 4 | 5 | 6 | 7 | Total |
|---|---|---|---|---|---|---|---|---|
| Base Pearls | 100 | 100 | 150 | 150 | 200 | 300 | 500 | 1,500 |

The streak gives Pearls only (canon 11): no tokens, items or decorations.

## 11. Reef Rank · [L]

Account level 1 to 50 from lifetime Pearls banked (canon): base banking and scraps only, before any pass multiplier. Chapter 05, section 7 owns the threshold for every rank (`100 × (rank − 1)^2.2`, rounded) and the Pearl gift for every rank-up (25 × the new rank). This chapter owns the title names and the decorations.

Ten bands of five ranks. Entering a band gives a **title** (shown on the Name Shell), one **exclusive decoration** that cannot be bought, and, for the first eight bands, a **shop shelf** of decorations that can then be bought with Pearls (section 13). Rank 50 gives a last title and trophy. The Pearls column is a copy of chapter 05's table.

| Band | Ranks | Title | Lifetime Pearls banked to enter (chapter 05) | Exclusive decoration | Shop shelf opened |
|---|---|---|---|---|---|
| 1 | 1 to 5 | Bubble Blower | 0 | Pebble Tower (at rank 3) | Shelf 1 |
| 2 | 6 to 10 | Sand Scooter | 3,450 | Bubble Fountain | Shelf 2 |
| 3 | 11 to 15 | Shell Seeker | 16,000 | Shell Throne | Shelf 3 |
| 4 | 16 to 20 | Reef Rover | 38,500 | Reef Map | Shelf 4 |
| 5 | 21 to 25 | Kelp Creeper | 73,000 | Kelp Swing | Shelf 5 |
| 6 | 26 to 30 | Pearl Hunter | 119,000 | Giant Pearl Lamp | Shelf 6 |
| 7 | 31 to 35 | Tide Rider | 178,000 | Tide Clock | Shelf 7 |
| 8 | 36 to 40 | Deep Diver | 249,000 | Diving Helmet | Shelf 8 |
| 9 | 41 to 45 | Storm Chaser | 335,000 | Storm Glass | None |
| 10 | 46 to 50 | Leviathan Keeper | 434,000 | Leviathan Statue | None |
| Cap | 50 | Reef Legend | 523,000 | Golden Gulp trophy, and a gold Name Shell | None |

## 12. Badges (Roblox badges)

| # | Name | Description shown to the player | Unlock condition | Tag |
|---|---|---|---|---|
| 1 | Welcome to GULP | You dipped a fin in. | Join the game for the first time | [MVP] |
| 2 | First Gulp | You ate your first snack. | Eat any prey | [MVP] |
| 3 | Home Safe | You banked your first creature. | Bank a run for the first time | [MVP] |
| 4 | Gulped! | Something bigger got you. It happens. | Get gulped for the first time | [MVP] |
| 5 | Growing Up | You grew into a Snapper. | Reach tier 3 | [MVP] |
| 6 | Big Fish | You grew into a Brute. | Reach tier 5 | [MVP] |
| 7 | Titan | You grew into a Titan. | Reach tier 6 | [MVP] |
| 8 | Leviathan | You became the biggest thing in the sea. | Reach tier 7 | [MVP] |
| 9 | Giant at Home | You brought a Leviathan home. | Bank a tier 7 creature | [MVP] |
| 10 | You Are What You Eat | You gained your first trait. | Gain any trait | [MVP] |
| 11 | Triple Treat | You banked a creature with three traits. | Bank a creature with 3 traits | [MVP] |
| 12 | Moon Child | You gained the Moonlit trait. | Gain Moonlit | [MVP] |
| 13 | Gem of the Sea | You banked a Crystal creature. | Bank a creature with Crystal | [MVP] |
| 14 | Bone Deep | You gained the Bonefed trait. | Gain Bonefed | [L] |
| 15 | Full House | Every starting slot in your cove is full. | Hold 6 specimens at once | [MVP] |
| 16 | Close Shave | You got away from Old Scar. | Be chased by Old Scar and survive the chase | [MVP] |
| 17 | Not Today, Gull | You dodged 10 Gull dives. | Dodge 10 Gull dives (lifetime) | [MVP] |
| 18 | Hooked | You ate the worm. Everyone does once. | Get yanked by a fishing hook | [MVP] |
| 19 | Flying Fish | You jumped out of the water 100 times. | Breach 100 times (lifetime) | [MVP] |
| 20 | Frenzy Feeder | You ate 100 prey in one Feeding Frenzy. | Eat 100 prey during a single Feeding Frenzy | [MVP] |
| 21 | Big Bite | You gulped another player. | Eat another player for the first time | [MVP] |
| 22 | Whole Family | You unlocked all six launch species. | Own Minnow, Pufferfish, Eel, Sea Turtle, Squid and Shark Pup | [L] |
| 23 | Safe in the Shell | Your shell saved you. | As a Sea Turtle, be bitten while Shell is active | [L] |
| 24 | Tide Tourist | You joined every kind of tide. | Eat 10 prey in each of Feeding Frenzy, Moon Tide and Whale Fall | [L] |
| 25 | Good Neighbour | You left 25 Bubbles. | Leave 25 Bubbles (lifetime) | [L] |
| 26 | Popular Cove | Your cove got 100 Bubbles. | Receive 100 Bubbles (lifetime) | [L] |
| 27 | Seven Days of Sea | You finished a 7-day streak. | Open box 7 of the login streak | [L] |
| 28 | Know-It-All | You filled the whole Codex. | Complete every launch Codex category | [L] |
| 29 | Reef Legend | You reached Reef Rank 50. | Reach Reef Rank 50 | [L] |

## 13. Cove decorations · [L]

Decorations arrive at launch (canon). They are for looks only and never change stats, except that the Tide Clock really shows the next event and the Dinner Bell really rings. The Tide Clock decoration is a brass second face for the free shell tide clock every cove already has (section 6.10): it shows the same next event and no more.

There are 50, of which 46 arrive at launch; chapter 05, section 4.3 has the same count and owns the prices. 18 are bought with Pearls in price bands D1 to D4, on eight shop shelves that open at Reef Rank 1, 6, 11, 16, 21, 26, 31 and 36 (section 11). The rest are earned or bought another way: 11 free from Reef Rank, 6 free from the Codex, 4 free from daily-goal milestones, 7 from tide events (3 at launch), 1 in the Starter Pack and 3 for Robux (49, 99 and 149; chapter 05, section 8.5). The login streak gives no decoration, because canon 11 makes its rewards Pearls only. The four Monument decorations chapter 05 plans for [P1] are not named yet.

**Size classes:** S fits a 4 × 4 stud spot, M fits 8 × 8, L fits 14 × 14. **Mounts:** floor, wall, ceiling. A cove has 10 small floor spots, 6 medium floor spots, 3 large floor spots, 6 wall spots and 4 ceiling spots (tune); a smaller item may use a bigger spot of the same mount.

**How obtained** is one short line written for the player: chapter 08 shows it unchanged as the decoration's "how to get it" text (`decoitem.<id>.how`). **Source** is the data behind that line: the price band and shop shelf, the Reef Rank, the Codex category, the count of full goal days, or the `stats.events` counter and count that chapter 09 checks (section 12.2). Every count is a lifetime total.

| ID | Name | Appearance brief | Size · mount | How obtained (shown to the player) | Source | Tag |
|---|---|---|---|---|---|---|
| `deco_shell_pile` | Shell Pile | A heap of five mixed shells, pink and cream | S · floor | Buy it with Pearls in the shop. | Pearls D1 · shelf 1 | [L] |
| `deco_sea_fan` | Sea Fan | A flat pink coral fan that sways | S · floor | Buy it with Pearls in the shop. | Pearls D1 · shelf 1 | [L] |
| `deco_bubble_stone` | Bubble Stone | A round grey stone with a crack that leaks a thin stream of bubbles | S · floor | Buy it with Pearls in the shop. | Pearls D1 · shelf 1 | [L] |
| `deco_starfish_trio` | Starfish Trio | Three starfish, orange, red and purple, stuck to the wall | S · wall | Buy it with Pearls in the shop. Opens at Reef Rank 6. | Pearls D1 · shelf 2 | [L] |
| `deco_glow_sprouts` | Glow Sprouts | Three small sea plants with softly glowing teal tips | S · floor | Buy it with Pearls in the shop. Opens at Reef Rank 6. | Pearls D1 · shelf 2 | [L] |
| `deco_old_pot` | Old Pot | A cracked clay pot; a tiny crab peeks out now and then | S · floor | Buy it with Pearls in the shop. Opens at Reef Rank 6. | Pearls D2 · shelf 2 | [L] |
| `deco_kelp_curtain` | Kelp Curtain | A hanging row of green kelp strands that sway | M · ceiling | Buy it with Pearls in the shop. Opens at Reef Rank 11. | Pearls D2 · shelf 3 | [L] |
| `deco_sand_castle` | Sand Castle | A three-tower sand castle with a shell flag | M · floor | Buy it with Pearls in the shop. Opens at Reef Rank 11. | Pearls D2 · shelf 3 | [L] |
| `deco_clam_couch` | Clam Couch | A big open clam with a soft pink cushion inside | M · floor | Buy it with Pearls in the shop. Opens at Reef Rank 11. | Pearls D2 · shelf 3 | [L] |
| `deco_rusty_anchor` | Rusty Anchor | A small anchor leaning on a rock, with barnacles | M · floor | Buy it with Pearls in the shop. Opens at Reef Rank 16. | Pearls D2 · shelf 4 | [L] |
| `deco_porthole` | Porthole | A round brass ship window that glows soft blue | S · wall | Buy it with Pearls in the shop. Opens at Reef Rank 16. | Pearls D2 · shelf 4 | [L] |
| `deco_lantern_string` | Lantern String | A string of six small glowing shell lanterns | M · ceiling | Buy it with Pearls in the shop. Opens at Reef Rank 16. | Pearls D3 · shelf 4 | [L] |
| `deco_bottle_ship` | Ship in a Bottle | A large glass bottle with a tiny sailing ship inside | M · floor | Buy it with Pearls in the shop. Opens at Reef Rank 21. | Pearls D3 · shelf 5 | [L] |
| `deco_net_hammock` | Net Hammock | A fishing net slung as a hammock, with a starfish asleep in it | M · ceiling | Buy it with Pearls in the shop. Opens at Reef Rank 21. | Pearls D3 · shelf 5 | [L] |
| `deco_coral_arch` | Coral Arch | A tall arch of orange and pink coral to swim through | L · floor | Buy it with Pearls in the shop. Opens at Reef Rank 26. | Pearls D3 · shelf 6 | [L] |
| `deco_treasure_barrel` | Treasure Barrel | An open barrel spilling gold coins and beads | M · floor | Buy it with Pearls in the shop. Opens at Reef Rank 26. | Pearls D4 · shelf 6 | [L] |
| `deco_mini_volcano` | Mini Volcano | A small stone cone that puffs warm orange bubbles every 10 s | L · floor | Buy it with Pearls in the shop. Opens at Reef Rank 31. | Pearls D4 · shelf 7 | [L] |
| `deco_golden_minnow` | Golden Minnow | A gold statue of a leaping Minnow on a stone base | M · floor | Buy it with Pearls in the shop. Opens at Reef Rank 36. | Pearls D4 · shelf 8 | [L] |
| `deco_rank_pebble_tower` | Pebble Tower | Seven smooth pebbles balanced in a stack | S · floor | Reach Reef Rank 3. | Free · Reef Rank 3 | [L] |
| `deco_rank_bubble_fountain` | Bubble Fountain | A stone ring with a steady column of bubbles, like the one in the Nursery | M · floor | Reach Reef Rank 6. | Free · Reef Rank 6 | [L] |
| `deco_rank_shell_throne` | Shell Throne | A giant scallop-shell chair with a pearl on top | L · floor | Reach Reef Rank 11. | Free · Reef Rank 11 | [L] |
| `deco_rank_reef_map` | Reef Map | A painted map of the whole reef on stretched sailcloth | M · wall | Reach Reef Rank 16. | Free · Reef Rank 16 | [L] |
| `deco_rank_kelp_swing` | Kelp Swing | A seat hanging on two kelp ropes; it swings slowly | M · ceiling | Reach Reef Rank 21. | Free · Reef Rank 21 | [L] |
| `deco_rank_pearl_lamp` | Giant Pearl Lamp | A pearl the size of a beach ball in an open clam, glowing white | M · floor | Reach Reef Rank 26. | Free · Reef Rank 26 | [L] |
| `deco_rank_tide_clock` | Tide Clock | A brass clock with four pictures; its hand points to the next tide event, the same as the cove's free shell tide clock | M · wall | Reach Reef Rank 31. | Free · Reef Rank 31 | [L] |
| `deco_rank_diving_helmet` | Diving Helmet | An old brass diving helmet with a small fish living inside | M · floor | Reach Reef Rank 36. | Free · Reef Rank 36 | [L] |
| `deco_rank_storm_glass` | Storm Glass | A glass globe holding a tiny swirling storm cloud with sparks | S · floor | Reach Reef Rank 41. | Free · Reef Rank 41 | [L] |
| `deco_rank_leviathan_statue` | Leviathan Statue | A dark stone statue of a huge sea creature rising from waves | L · floor | Reach Reef Rank 46. | Free · Reef Rank 46 | [L] |
| `deco_rank_golden_gulp` | Golden Gulp | A gold trophy: an open fish mouth around a pearl | M · floor | Reach Reef Rank 50. | Free · Reef Rank 50 | [L] |
| `deco_evt_dinner_bell` | Dinner Bell | A brass ship's bell on a post. It rings by itself when a Feeding Frenzy starts | S · floor | Eat 500 prey during Feeding Frenzies. | Event · `frenzy_prey` 500 (lifetime) | [L] |
| `deco_evt_moon_lamp` | Moon Lamp | A glowing crescent moon on a stand, shedding slow silver motes | M · floor | Eat 25 Lunar Fry during Moon Tides. | Event · `lunar_fry` 25 (lifetime) | [L] |
| `deco_evt_whale_rib` | Whale Rib Arch | Two tall white rib bones with glowing algae, meeting as an arch | L · floor | Eat 25 Marrow chunks at Whale Falls. | Event · `marrow` 25 (lifetime) | [L] |
| `deco_evt_storm_bottle` | Lightning in a Bottle | A corked bottle with a small bolt of lightning bouncing inside | S · floor | Get through 5 Storms without being struck. | Event · `storms_survived` 5 (lifetime) | [P1] |
| `deco_evt_trench_lantern` | Trench Lantern | A tall glowing green stalk from the Lantern Field in a stone pot | M · floor | Reach the Quiet, deep in the Trench. | Event · `trench_quiet` 1 | [P2] |
| `deco_evt_red_bloom` | Red Bloom | A glass jar of slowly swirling rust-red water | S · floor | Eat 300 prey inside Red Tides. | Event · `red_tide_prey` 300 (lifetime) | [P1] |
| `deco_evt_fish_kite` | Fish Kite | A silver cloth fish on a string that flutters as if in a current | M · ceiling | Follow the Great Migration from start to end. | Event · `migrations_followed` 1 | [P1] |
| `deco_cdx_family_portrait` | Family Portrait | A framed picture of the six launch species in a row | M · wall | Fill every Species entry in the Codex. | Codex · `cdx_species` complete | [L] |
| `deco_cdx_prey_mobile` | Prey Mobile | A hanging mobile of eight small wooden prey that turn slowly: the eight ordinary prey of canon 8.1, Plankton mote to Tuna (not all 21 Prey entries) | M · ceiling | Fill every Prey entry in the Codex. | Codex · `cdx_prey` complete | [L] |
| `deco_cdx_trait_totem` | Trait Totem | A tall carved pole with one face per trait, each lit in its trait colour | L · floor | Fill every Traits entry in the Codex. | Codex · `cdx_traits` complete | [L] |
| `deco_cdx_danger_board` | Danger Board | A cork board with funny "watch out" posters of each predator | M · wall | Fill every Dangers entry in the Codex. | Codex · `cdx_dangers` complete | [L] |
| `deco_cdx_sea_globe` | Sea Globe | A water-filled glass globe with a tiny model of the whole map | M · floor | Fill every Places entry in the Codex. | Codex · `cdx_places` complete | [L] |
| `deco_cdx_tide_chart` | Tide Chart | A wall chart with a picture for each tide event | S · wall | Fill every Tides entry in the Codex. | Codex · `cdx_tides` complete | [L] |
| `deco_goals_sun_shell` | Sun Shell | A golden scallop that glows like a small sun | S · floor | Finish all three daily goals on 3 days. | Daily goals · 3 full days (lifetime) | [L] |
| `deco_goals_week_wheel` | Week Wheel | A small ship's wheel with seven shells on its rim | S · wall | Finish all three daily goals on 7 days. | Daily goals · 7 full days (lifetime) | [L] |
| `deco_goals_lucky_starfish` | Lucky Starfish | A smiling golden starfish that waves one arm | S · floor | Finish all three daily goals on 14 days. | Daily goals · 14 full days (lifetime) | [L] |
| `deco_goals_message_bottle` | Message in a Bottle | A corked bottle with a rolled note; it bobs gently | S · floor | Finish all three daily goals on 28 days. | Daily goals · 28 full days (lifetime) | [L] |
| `deco_buy_gold_chest` | Golden Chest | An open chest overflowing with Pearls, softly glowing | M · floor | Comes with the Starter Pack. | Starter Pack (chapter 05) | [L] |
| `deco_buy_disco_clam` | Disco Clam | A clam holding a mirror-ball pearl that throws moving dots of light | M · floor | Buy it with Robux in the shop. | Robux (chapter 05, section 8.5) | [L] |
| `deco_buy_jelly_lamp` | Jelly Lamp | A tall glass tube with slow glowing blobs shaped like jellies | S · floor | Buy it with Robux in the shop. | Robux (chapter 05, section 8.5) | [L] |
| `deco_buy_mini_pickle` | Mini Tin Pickle | A 12-stud model of the tugboat wreck with lit windows | L · floor | Buy it with Robux in the shop. | Robux (chapter 05, section 8.5) | [L] |

## 14. Quick emotes · [L]

Six bubble emotes. Each shows a picture in a bubble above the creature for 2.5 s, visible to creatures within 120 studs (document 02, section 17.1 has the rules), with a 3 s cooldown (tune). Pictures only: no words appear in the world, so nothing needs translating there. The label is used in the emote picker and for screen readers.

| ID | Label | Picture in the bubble | Sound | What players use it for |
|---|---|---|---|---|
| `em_hi` | Hi! | A waving fin | Two rising bubble pops | Greeting, making friends |
| `em_this_way` | This way! | An arrow pointing where the creature is facing | A short whistle | Leading a friend to prey or home |
| `em_look_out` | Look out! | A red exclamation mark in a spiky bubble | Two quick warning blips | Warning about a predator or a bigger player |
| `em_thanks` | Thanks! | A pink heart | A soft chime | After a visit, a Bubble or a rescue |
| `em_ha_ha` | Ha ha! | A laughing fish face | A bubbly giggle | Hooks, near misses, funny moments |
| `em_oops` | Oops! | A fish face with a sweat drop | A falling "bloop" | Sorry for the bump, or for eating you |

## 15. Names and short strings

### 15.1 Tone of voice

Friendly, short, a little funny, readable by a nine-year-old, easy to translate.

| Rule | Detail |
|---|---|
| Short | Banners and toasts: 8 words or fewer. Names: 1 to 3 words. |
| Plain words | Use words a nine-year-old reads without help. "Eat", "grow", "home", "run", not "consume", "evolve", "base". |
| Talk to the player | Say "you". Use present tense. "You grew!" not "Tier increased". |
| Funny by being cheerful and honest | "Oops. That was a hook." The joke is the situation, not wordplay. |
| No puns that only work in English | A pun cannot be translated. Funny names are fine when the meaning is funny on its own (the Tin Pickle, the Snooze). |
| Never mean, never scary | Being eaten is "gulped". Never "killed", "dead", "died", "blood". Losing is light: "It happens." |
| One exclamation mark at most | And only for good news or urgent warnings. |
| Numbers as digits | "5 of 5", "+120 Pearls". |
| Sentence case | Only the first word and game terms take a capital: Pearls, Codex, Bubble, Reef Rank, tier names, species, traits, places. |
| Fixed terms | Always the canon glossary words: run, bank, gulped, tier, mass, specimen, cove, trait, Pearls, Bubble, Codex, scraps. Never a second word for the same thing. |
| Do not translate | GULP. Player names. |
| Translate by meaning | Every place, tier, species, prey, trait and event name. Notes for translators are in the tables below. |

### 15.2 Names

| Group | Names | Notes for writers and translators |
|---|---|---|
| **Zones** | Nursery Lagoon, Sunlit Reef, Kelp Forest, the Drop-off, the Trench, cove, the Rim | "The Drop-off" is where the sea floor falls away. "Cove" is never capitalised unless it starts a sentence. |
| **Tiers** | Fry, Nibbler, Snapper, Hunter, Brute, Titan, Leviathan | Fry = a baby fish. Nibbler = takes small bites. Snapper = bites fast (translate the meaning, not the fish). Brute = big, strong, a bit clumsy. Leviathan = a sea giant from old stories. |
| **Species** | Minnow, Pufferfish, Eel, Sea Turtle, Squid, Shark Pup; later Anglerfish, Manta Ray, Seahorse, Axolotl, Orca Calf, Narwhal | Use the everyday animal name in each language. "Pup" and "Calf" mean a young one. |
| **Abilities** | Dart, Puff, Slip, Shell, Jet, Rampage; later Lure, Glide, Sip, Regrow, Echo, Joust | One short action word each. The Shark Pup's ability is Rampage (ID `rampage`); "Frenzy" is used only for the Feeding Frenzy tide event. |
| **Prey** | Plankton mote, Krill, Tiny Shrimp, Sardine, Reef Darter, Mackerel, Bonito, Tuna | Real animals. "Mote" = a tiny speck. |
| **Trait prey** | Glowfry, Zebra Darter, Dotted Goby, Armor Shrimp, Urchin Puff, Ribbonfish, Inklet, Spark Eel, Leaf Drifter, Crystal Jelly, Vent Snail, Lunar Fry, Marrow chunk | Each name hints at its trait. Keep that link in translation. "Inklet" = a little ink squid. |
| **Traits** | Glow, Stripes, Spots, Plated, Spiny, Longfin, Ink, Spark, Camo, Crystal, Ember, Moonlit, Bonefed | One word each. "Bonefed" = fed on whale bone. |
| **Rarities** | Common, Uncommon, Rare, Epic, Mythic | |
| **Predators and hazards** | Gull, Moray, Barracuda, Grouper, Old Scar, Jelly bloom, Anemone, Thermal vent, Fishing hook, Current | "Old Scar" is a nickname: an old shark with a scar. |
| **Tide events** | Feeding Frenzy, Moon Tide, Whale Fall; later Storm, The Trench Opens, Red Tide, Great Migration | |
| **Passes and currents** | North Pass, East Pass, South Pass, West Pass, Little Arch; Home Loop, North Chute, East Chute, Kelp Slide, Wall Run, the Lift, Baby Slide | "Chute" and "Slide" = something you ride down. |
| **Landmarks** | All names in sections 6.2 to 6.6 | Noggin = a playful word for head (the rock looks like a brain). The Snooze = a short nap. The Tin Pickle = a silly boat name. Peekaboo = the baby's hiding game. The Overbite = a jaw that sticks out. The Elbow = a channel with one bend, like a bent arm. |
| **Cove parts** | Name Shell, Trophy Bubble, Door Lantern, Home Stone, Pearl Clam, Trophy Rock, Codex Stone, Species Wall, tide clock, Bubble Jar | |
| **Reef Rank titles** | Bubble Blower, Sand Scooter, Shell Seeker, Reef Rover, Kelp Creeper, Pearl Hunter, Tide Rider, Deep Diver, Storm Chaser, Leviathan Keeper, Reef Legend; Codex titles Leviathan Maker, Reef Scholar | Two words: a sea thing plus a doer. |
| **Currencies and terms** | Mass, Pearls, Bubbles, Codex, Reef Rank, specimen, scraps, run, bank, gulped | Canon glossary. |

### 15.3 Short strings

These are source briefs for tone. Chapter 08, section 14 owns the final string keys and text and wins wherever it differs; no build reads the `str_*` keys below. `{braces}` are filled in by the game; `{max}` is 5, or 4 with the Keen Nose pass.

| Key | Text | Tag |
|---|---|---|
| `str_tagline` | Eat. Grow. Get home. | [MVP] |
| `str_hint_first_bite` | Eat the little green ones! | [MVP] |
| `str_hint_green` | Green means food. | [MVP] |
| `str_hint_red` | Red means run! | [MVP] |
| `str_hint_home` | Swim home to keep it all. | [MVP] |
| `str_tier_up` | You grew! Now you are a {tier}. | [MVP] |
| `str_trait_progress` | {trait}: {n} of {max} | [MVP] |
| `str_trait_gained` | New trait: {trait}! | [MVP] |
| `str_trait_full` | Trait slots full. Tap one, then hold to drop it. | [MVP] |
| `str_bank_done` | Home safe! +{n} Pearls | [MVP] |
| `str_specimen_new` | {species} added to your cove. | [MVP] |
| `str_cove_full` | Your cove is full. Let one go? | [MVP] |
| `str_gulped` | Gulped by {name}! | [MVP] |
| `str_gulped_scraps` | You kept {n} Pearls. | [MVP] |
| `str_revive_offer` | Keep going? | [MVP] |
| `str_ate_player` | You gulped {name}! | [MVP] |
| `str_safe_zone` | Safe here. Nobody can eat you. | [MVP] |
| `str_gull_warn` | Shadow above! Dive! | [MVP] |
| `str_scar_near` | Old Scar is close... | [MVP] |
| `str_hooked` | Oops. That was a hook. | [MVP] |
| `str_plates_cracked` | Your plates took the bite! | [MVP] |
| `str_crystal_spotted` | Crystal Jellies are in the {zone}! | [MVP] |
| `str_income_claim` | Your cove earned {n} Pearls. | [MVP] |
| `str_codex_new` | New in your Codex: {entry} | [MVP] |
| `str_goal_done` | Goal done! +{n} Pearls | [MVP] |
| `str_evt_frenzy_warn` | Feeding Frenzy in 60 seconds! | [MVP] |
| `str_evt_frenzy_start` | Feeding Frenzy! Eat everything! | [MVP] |
| `str_evt_frenzy_end` | The frenzy is over. | [MVP] |
| `str_evt_moon_warn` | Moon Tide in 60 seconds. | [MVP] |
| `str_evt_moon_start` | Moon Tide! Find the moonbeams. | [MVP] |
| `str_evt_moon_end` | The moon slips away. | [MVP] |
| `str_evt_whale_warn` | Something big is sinking... | [L] |
| `str_evt_whale_start` | Whale Fall! Dive to the Drop-off. | [L] |
| `str_evt_whale_end` | The feast is over. | [L] |
| `str_visit_enter` | Visiting {name}'s cove | [L] |
| `str_bubble_left` | You left a Bubble. | [L] |
| `str_bubble_got` | {name} left you a Bubble! | [L] |
| `str_streak_day` | Day {n} of 7 | [L] |
| `str_rank_up` | Reef Rank {n}! | [L] |
| `str_title_new` | New title: {title} | [L] |
| `str_evt_storm_start` | Storm! Stay low. | [P1] |
| `str_evt_trench_start` | The Trench is open! | [P2] |
| `str_evt_trench_close` | The Trench is closing. Swim up! | [P2] |
| `str_evt_red_start` | Red Tide in the {zone}! | [P1] |
| `str_evt_migration_start` | The Great Migration is passing! | [P1] |

## 16. Proposed canon changes

The canon has adopted this chapter's earlier proposals (the drift of five Crystal Jellies, prey tiers with no tier 7, the first run in the Nursery, the whale skeleton, the disc map, the flexible :30 slot, passive ability badges, the Dangers, Places and Tides categories, one Bubble per cove per day, the Barracuda kept to the east side, the six free Codex patterns, the three Robux decorations and the Golden Chest in the Starter Pack). These four are still open.

| # | Canon says | Problem | Suggestion |
|---|---|---|---|
| 1 | The Reef Barracuda eats tier 3 and lower (8.3). | A tier 1 Fry that wanders east in its first minutes can still be eaten by it, against pillar 1. | Consider making the Reef Barracuda ignore tier 1 (tune). |
| 2 | Post-launch species: no ability named for Seahorse, Orca Calf or Narwhal (section 7). | Sheets need one. | Adopt Sip, Echo and Joust from section 1.4, or replace them. |
| 3 | Axolotl ability "Regrow" (section 7). | As written here (survive one bite) it overlaps the Plated trait and the paid Revive. | Document 05 should check its effect on Revive sales before [P2]. |
| 4 | Trait prey have no mass values (8.2). | Needed to build them. Chapter 05, section 2.1 now sets them. | Add a Mass column to canon 8.2 with chapter 05's values: 1, 4, 10 and 25 by tier, and 40 for Marrow. |
