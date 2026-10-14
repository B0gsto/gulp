# 04 · The first two minutes

This chapter scripts what a brand-new player sees, does and hears from tapping Play until the game opens up, then covers the rest of the first session and the first return. It expands canon pillar 1 ("Eating in five seconds") and canon section 17 (success measures). Names, IDs and numbers come from `01-game-canon.md`. Event names come from `10-analytics-and-funnels.md`.

Numbers marked **(tune)** are first guesses. Everything in this chapter is **[MVP]** unless a tag says otherwise.

**Short names used here**

| Name | Meaning |
|---|---|
| **FTUE** | First-time experience: everything from join to the start of run 2 |
| **J** | Seconds since the server saw the player join (`PlayerAdded`). The closest clock we have to Roblox's session clock. Used here only for load budgets and for lining up with Roblox's own signals. |
| **T** | Seconds since the player gained control. T = 0 is the first frame where input moves the creature. On the reference phone T is about J − 5. Every success measure runs on T (canon section 17). |
| **Run 1** | The scripted first run, from hatching in the Nursery to the first bank |
| **Reference phone** | An Android phone with 4 GB of RAM and a 2021 to 2023 mid-range chip (Galaxy A13 or A14 class) on home Wi-Fi **(tune)**. Second check device: iPhone SE (2nd generation) class. |

## 1. Goals and the numbers we design against

### 1.1 What the first two minutes must do

1. Put food in the creature's mouth within 5 seconds of control.
2. Make the creature visibly bigger within 30 seconds.
3. Show "you are what you eat" with a guaranteed first trait by about 45 seconds.
4. Make the player feel hunted once, safely, at about 60 seconds.
5. Get the run banked by about 2 minutes so the player owns something that stays.
6. End on two open questions: "what is that silhouette?" and "what happens when the tide clock hits zero?"

### 1.2 Targets

Canon targets are copied from canon section 17. Chapter targets are our own additions. All are our own targets, not Roblox benchmarks.

| Measure | Target | Source | Event that measures it |
|---|---|---|---|
| Join to control (J at T = 0), reference phone | 5 s median, 10 s for 90% **(tune)** | Chapter | `sys_load_time` |
| First bite within 5 s of control | 75% of new players **(tune)** | Chapter (pillar 1) | `ftue_milestone` = `bite_le5` |
| First bite within 10 s of control | 90% | Canon | `ftue_milestone` = `bite_le5` + `bite_le10` |
| Reach tier 2 within 30 s of control | 50% **(tune)** | Chapter (canon 5.1 average) | `ftue_milestone` = `tier2_le30` |
| Reach tier 2 within 45 s of control | 75% | Canon | `ftue_milestone` = `tier2_le30` + `tier2_le45` |
| Gain the first trait within 60 s of control | 70% **(tune)** | Chapter | `ftue_milestone` = `trait_le45` + `trait_le60` |
| Still playing at T = 60 | 80% | Canon | `fs_time_mark` = `s60` |
| Bank within 120 s of control | 50% **(tune)** | Chapter | `ftue_milestone` = `bank_le90` + `bank_le120` |
| Still playing at T = 180 | 65% | Canon | `fs_time_mark` = `s180` |
| Bank the first creature (any time in session 1) | 60% | Canon | Onboarding step `13_banked` |
| Start a second run in session 1 | 50% | Canon | Onboarding step `17_run2_started` |
| Still playing at T = 600 (10 minutes) in session 1 | 50% | Canon | `fs_time_mark` = `m10` |

The three "still playing" marks are counted from control, as the canon rules. Chapter 10 owns the `fs_time_mark` event.

### 1.3 How the script lines up with Roblox's signals

Roblox's recommendation system counts a first play as a bounce when it ends in under 60 seconds, and separately when it ends at 61 to 180 seconds. These are Roblox's lines, not our measures: our measures in section 1.2 run on T. Roblox's clock starts before ours (we cannot see the time between the tap on Play and `PlayerAdded`), so each of its lines falls a few seconds earlier on T, and we place a strong beat just before it.

| Roblox line | Our clock at that moment | What the player is in the middle of |
|---|---|---|
| 60 seconds | T ≈ 50 to 55 | Just gained Glow, the way home has opened, a shadow has passed outside the Gap |
| 180 seconds | T ≈ 170 to 175 | Run 2 in open water, tier 2 again, a goal chip part-filled, the tide clock counting down |
| 10 minutes (Creator Rewards counts spenders who play 10 minutes or more) | T ≈ 595 | Third run or so; the Pufferfish just bought, or its ring nearly full |

### 1.4 Rules that hold for the whole FTUE

- The player cannot lose in run 1. Nothing can eat, stun, hook or slow them.
- Control is never taken away, with one exception: up to 3.5 seconds at the first bank, when there is no creature to steer.
- No modal windows. Nothing asks for a tap to continue.
- Prompts are icons first. A prompt may carry one word of at most 8 letters. Section 3.3 lists every word.
- One new interface element at a time, at least 4 seconds apart.
- Every beat has a fail-safe, so a player who does nothing, or the wrong thing, still moves forward.
- Phone prompts assume one thumb. The optional two-thumb scheme is never offered during the FTUE.

## 2. Load sequence

### 2.1 Phases and budgets

| Phase | From → to | Budget, reference phone | What the player sees | Ours to control? |
|---|---|---|---|---|
| A | Tap Play → `PlayerAdded` | Not measurable by us (Roblox client start and server join) | Roblox's own join screen | No. We keep it short only by keeping the place small. |
| B | `PlayerAdded` → our loading screen's first frame | 0.5 s | Our loading screen replaces the default one | Yes |
| C | Profile load (runs in parallel with D) | 1.5 s median, 4 s for 90% | Loading screen | Yes (document 09) |
| D | Minimum set streamed and preloaded | 3 s median, 8 s for 90% | Loading screen | Yes |
| E | Hatch | 1.5 s, cut short by any touch after 0.4 s | The egg in the Nursery | Yes |
| **B to E total** | `PlayerAdded` → control | **5 s median, 10 s for 90% (tune)** | | |

The avatar is never loaded (canon section 1), which removes the largest usual cost in phase D. Engine calls we expect to use, named from memory and not re-checked for this chapter (document 09 owns the final list): `ReplicatedFirst:RemoveDefaultLoadingScreen()`, `Players.CharacterAutoLoads = false`, `Player.ReplicationFocus` set to the creature's root part, `Player:RequestStreamAroundAsync()` on the Nursery spawn, and `ContentProvider:PreloadAsync()` for the minimum set only.

### 2.2 The loading screen

One screen, no text other than the logo.

| Element | Detail |
|---|---|
| Background | Flat lagoon teal with slow light rays (`UI_Loading_Background`), no 3D |
| Logo | `UI_Loading_Logo` (GULP), top third, 30% of screen width |
| The toy | A flat Fry (`UI_Loading_Fry`) that follows the thumb and eats white dots that drift in from the right. Each dot eaten makes the Fry 3% bigger, up to +60%. This is the drag-to-swim control in 2D, so the player has practised the input before the game starts. |
| Progress | A row of five bubbles along the bottom that fill left to right, one per 20% of phase D. No percentage, no words. |
| Sound | `MUS_Nursery` base layer fades in over 1 s. `SFX_Bite_Small` on each dot. |
| Exit | When phases C and D are done the screen splits into bubbles (0.4 s) to reveal the egg. The size the 2D Fry reached is discarded. |

### 2.3 What streams first

| Set | Contents | Needed for | Budget (tune) |
|---|---|---|---|
| **Minimum set** | Nursery floor and walls within 90 studs of the hatch point, the egg, the Minnow juvenile mesh and textures, krill, plankton, the green outline effect, the HUD atlas, 6 sounds (`SFX_Hatch`, `SFX_Bite_Small`, `SFX_TierUp`, `SFX_TraitPip`, `SFX_Dash`, `MUS_Nursery`) | Control at T = 0 | 4 MB download, 25 assets in the preload list |
| **First-minute set** | The rest of the Nursery, Glowfry, the Glow effect, the kelp curtain, the Barracuda, the channel, the Home Current effect, chase music | Loads during T = 0 to 40 | 8 MB |
| **Rest** | Sunlit Reef, the player's cove, other zones | Loads by proximity after the Gap opens | Normal streaming |

Nursery water fog limits the view to 90 studs until T = 20, then opens to 160 studs over 3 seconds, so geometry that has not arrived yet is never seen popping in.

### 2.4 If loading is slow

Times are J (seconds since `PlayerAdded`).

| J | Condition | What we do | Event |
|---|---|---|---|
| 0 to 8 | Normal | Loading toy | — |
| 8 | Minimum set not complete | Start anyway if the hatch point floor, the Minnow mesh and krill are present. Missing textures show as flat colour and fade in. | `ftue_failsafe` = `load_partial` |
| 15 | Still not startable | Stop preloading everything except the Minnow mesh and krill. Skip the hatch animation. | `ftue_failsafe` = `load_minimal` |
| 20 | Profile still not loaded | Keep the toy running; the bubble row dims to pale grey (not amber, which is kept for home). Document 09's retry rule applies. | — |
| 30 | Still on the loading screen | Show a spinner with a weak-signal icon (`UI_Loading_SlowIcon`). No text. | `sys_load_time` bucket `gt20` on completion |
| 45 | Profile failed | Document 09's rule: leave the player on the toy and retry, or disconnect with Roblox's standard message. No tutorial progress is lost because none has been made. | `sys_profile_fail` |

## 3. The script

### 3.1 Stages

The server owns the stage and saves it in the profile as `ftue.stage`. The client plays the presentation. All tunables live in one config module (`FtueConfig`; document 09 owns its location: `shared/Config`, section 3). The saved stage is a number: `S0_LOADING` is 0, each stage after it the number in its name, and `DONE` is 11.

| Stage | Enters when | Leaves when |
|---|---|---|
| `S0_LOADING` | `PlayerAdded`, profile says `ftue.completed = false` | Minimum set ready |
| `S1_HATCH` | Loading screen exits | 1.5 s pass, or any touch after 0.4 s |
| `S2_FIRST_BITE` | Control gained (T = 0) | First prey eaten |
| `S3_GROW` | First prey eaten | Mass ≥ 10 (tier 2) |
| `S4_TRAIT` | Tier 2 reached | Glow gained |
| `S5_CALL_HOME` | Glow gained, or T = 70 with input in the last 10 s | Player crosses the Gap |
| `S6_CHASE` | Player crosses the Gap | Chase ends (section 5) |
| `S7_CURRENT` | Chase ends | Player enters own cove mouth |
| `S8_BANK` | Cove mouth crossed | New Fry hatched in the cove |
| `S9_COVE` | New Fry has control | Player leaves the cove mouth |
| `S10_RUN2` | Player leaves the cove mouth | Run 2 ends (bank or gulped) |
| `DONE` | Run 2 ends | — |

`ftue.completed` is set to true at the end of `S8_BANK`. Stages `S9` and `S10` only drive prompts and assists.

### 3.2 Prompt vocabulary

Seven prompt types cover the whole FTUE. Each has a glyph set per input type. Gamepad support is **[L]** (canon section 15), so the gamepad glyphs are too.

| Prompt | Asset | What it looks like | Phone | PC | Gamepad [L] |
|---|---|---|---|---|---|
| Ghost thumb | `UI_Ftue_GhostThumb` | A see-through thumbprint presses at lower centre and drags toward the target, looping every 1.6 s | Thumbprint | Mouse glyph plus a W key cap, with the arrow-key glyph `UI_Hint_KeyArrows` beside W: the arrow keys steer, for laptops with a trackpad and no mouse (chapter 15, section 3.3) | Left-stick glyph |
| Food outline | Canon green outline | Always on (canon 5.2). During the FTUE it is 30% thicker **(tune)**. | Same | Same | Same |
| Food trail | Plankton motes | Edible motes every 4 studs. Following the trail is eating. | Same | Same | Same |
| Pips | `UI_Hud_TraitPips` | Five empty dots around trait slot 1; each fills with a pop | Same | Same | Same |
| Home marker | `UI_Hud_HomeMarker` | A cave icon pinned to the screen edge in the direction of the cove, with a pulsing ring | Same | Same | Same |
| Bubble trail | `FX_HomeTrail` | A line of pearl-white bubbles, one every 6 studs, drifting along the route | Same | Same | Same |
| Dash pulse | `UI_Hud_DashButton` | The dash button swells to 1.3× and back twice a second with a white ring | Button under right thumb | Space key cap | A button glyph |

Danger uses the canon red outline plus a red screen-edge glow (`UI_Hud_DangerEdge`) on the side the predator is on.

### 3.3 Every word shown in the first 180 seconds

All strings go through the localisation table. Tier and trait names are the canon names.

| Word | Where | When | Duration |
|---|---|---|---|
| GULP | Loading screen logo | Loading | Until the game starts |
| NIBBLER | Tier-up banner | Tier 2 reached (run 1 and run 2) | 1.5 s |
| GLOW | Trait banner | Trait gained | 1.5 s |
| HOME | Under the home marker | From `S5_CALL_HOME` to the first bank | Persistent |
| DASH! | On the dash button | During the chase, until the first dash | Up to 6 s |
| BANKED | Stamp at the cove mouth | First bank | 0.8 s |
| Player's name | The sign over the player's cove | When the cove is in view | Persistent |

Numbers shown: the Pearl counter, the specimen's income per hour, the species price ring (Pearls owned / 500), the tide countdown, and goal counts. There is no mass number; mass is a bar.

### 3.4 Timeline at a glance

Times are expected windows for an average player. The script is driven by states, not by the clock, so a slow player sees the same beats later.

| T (s) | J (s) | Beat | Stage | What happens | Onboarding funnel step fired |
|---|---|---|---|---|---|
| — | 0 to 5 | B0 Load | `S0` | Loading toy | `01_joined`, `02_loading_screen` |
| −1.5 to 0 | 3.5 to 5 | B1 Hatch | `S1` | Egg pops, Fry wriggles out | `03_control` at T = 0 |
| 0 to 5 | 5 to 10 | B2 First bite | `S2` | Krill straight ahead; first gulp | `04_first_input`, `05_first_bite` |
| 5 to 20 | 10 to 25 | B3 Feed | `S3` | Plankton trail to a second swarm | `06_mass_5` |
| 18 to 28 | 23 to 33 | B4 Tier up | `S3` → `S4` | Becomes a Nibbler; dash button appears | `07_tier2` |
| 22 to 45 | 27 to 50 | B5 First trait | `S4` | Five Glowfry; body lights up | `08_glowfry_1`, `09_trait_gained` |
| 45 to 58 | 50 to 63 | B6 Call home | `S5` | Kelp curtain opens; home marker and bubble trail | `10_left_nursery` at the Gap |
| 58 to 66 | 63 to 71 | B7 Chase | `S6` | Barracuda chases for 6 s and misses | `11_channel_cleared` |
| 66 to 88 | 71 to 93 | B8 Home Current | `S7` | Carried over the reef to the cove | `12_cove_in_sight` |
| 88 to 92 | 93 to 97 | B9 Bank | `S8` | Mass turns into Pearls; specimen placed | `13_banked`, `14_specimen_placed` |
| 92 to 108 | 97 to 113 | B10 Cove | `S9` | First income tick; new Fry | `15_first_tick` |
| 100 to 120 | 105 to 125 | B11 Cliffhanger | `S9` | Pufferfish silhouette, tide clock, way out | `16_cliffhanger_seen` |
| 115 to 130 | 120 to 135 | B12 Run 2 starts | `S10` | Leaves the cove; goals chip | `17_run2_started` |
| 130 to 180 | 135 to 185 | B13 Open water | `S10` | Eats in the Sunlit Reef, reaches tier 2 | `18_run2_tier2` |

The funnel has 20 steps (chapter 10, section 3.1). The last two, `19_run2_ended` and `20_run3_started`, fire after this table's window.

### 3.5 Nursery layout the script needs

The world chapter owns the geometry. The script needs these distances **(tune)**, measured along one gently curving path so the next target is always on screen.

| Point | Distance from the hatch point | Contents |
|---|---|---|
| Hatch Bed | 0 | The egg on sea grass. The Fry faces the Gap. |
| Swarm A | 14 studs | 6 krill in a ball 6 studs wide |
| Plankton trail | 20 to 56 studs | 10 motes, one every 4 studs |
| Swarm B | 60 studs | 14 krill |
| Glow Grotto | 90 studs | A shaded overhang; 5 Glowfry wait inside |
| The Gap | 135 studs | This chapter's name for Little Arch (chapter 03, section 6.2), the Nursery's only exit: 50 studs wide with a 25-stud tunnel. Closed by a kelp curtain until `S5`. |
| The channel | 135 to 335 studs | 200 studs long, 36 studs wide, rock walls on both sides, one bend of about 40° at its midpoint |
| Home Current mouth | 335 studs | Start of the Home Current |

**On the map.** Chapter 03 places every point in this table: section 6.2 (first-run route) has the Hatch Bed, both swarms, the Glow Grotto, the kelp curtain, Little Arch and the channel, which it names the Elbow, and section 6.7 has the Home Current from the Elbow's end to each newcomer cove. Chapter 03 owns the coordinates; this chapter owns the beats.

All scripted prey belongs to one player: only that player's client draws it and the server accepts bites on it only from that player. Other newcomers in the Nursery are visible but have their own prey.

### 3.6 Beats in detail

#### B1 · Hatch (T −1.5 to 0)

| | |
|---|---|
| On screen | Close on a pale egg on sea grass. It wobbles twice, cracks, and the Fry pops out with a stretch. Swarm A is already visible ahead. |
| Player does | Nothing needed. Any touch after 0.4 s ends the hatch and gives control at once. |
| Game does | Plays `A_Minnow_Hatch`. Gives control at 1.5 s. |
| Prompt | None |
| Sound | `SFX_Hatch` (a soft pop and a squeak). `MUS_Nursery` base layer continues from the loading screen. |
| Camera | Starts 8 studs from the egg, low. Pulls back to the tier 1 follow distance (14 studs **(tune)**; chapter 02, section 3.1 owns the camera table) over 1.5 s and settles behind the Fry facing Swarm A. |
| Fail-safe | None needed; the beat ends on its own. |

#### B2 · First bite (T 0 to 5)

| | |
|---|---|
| On screen | The Fry, Swarm A 14 studs ahead with green outlines, nothing else. No HUD except a faint settings gear. |
| Player does | Drags toward the krill. |
| Game does | Bite on contact: the krill is sucked in, the Fry does a 0.15 s gulp pulse (scale 1.12× and back), three bubbles rise. The mass bar appears on the first bite, already 10% full. |
| Prompt | Ghost thumb from T = 0 if there has been no input; it hides on the first drag of 0.2 s or more. |
| Sound | `SFX_Bite_Small`. Each bite within 1.5 s of the last plays one semitone higher, up to +7. |
| Camera | Follow camera. No moves. |
| Fail-safe | T = 2.5 with no bite: Swarm A drifts toward the Fry at 6 studs/s, so a krill reaches the mouth by T = 5 with no input at all (`ftue_bite_assist`). Three taps without a drag: the ghost thumb replays with a longer drag. Swimming away: the swarm follows at 6 studs/s up to 60 studs from the hatch point. |

#### B3 · Feed (T 5 to 20)

| | |
|---|---|
| On screen | The rest of Swarm A, then a line of plankton motes curving to Swarm B. |
| Player does | Eats along the trail. |
| Game does | Mass: Swarm A gives 6, the trail gives 2, so tier 2 arrives two krill into Swarm B. Krill in the FTUE do not scatter; inside 25 studs they drift toward the player at 6 studs/s. At least 8 scripted krill are kept within 40 studs until `S5`. |
| Prompt | The food trail. The mass bar's end cap shows the tier 2 badge. |
| Sound | Rising bite pitch. `MUS_Nursery` adds a light pluck layer at mass 5. |
| Camera | Follow camera. |
| Fail-safe | No input for 4 s: ghost thumb returns. No input for 8 s: the nearest krill pulses and swims into the mouth. Swimming to the Gap: the kelp curtain is closed; the Fry bounces off softly, the curtain shakes, and the trail pulses once. Swimming to the surface: allowed, with a splash; there are no gulls in the Nursery. |

#### B4 · Tier up (T 18 to 28)

| | |
|---|---|
| On screen | The Fry has been growing a little with every bite (canon 5.1), so it is already close to scale 1.3 when it crosses mass 10. The tier-up adds a flourish: a 0.6 s swell that overshoots to 112% of the new scale and settles at 1.3 (chapter 02, section 5.1), a ring of bubbles bursts outward, and the banner NIBBLER with a "2" badge shows for 1.5 s. |
| Player does | Keeps swimming; nothing pauses. |
| Game does | Swim speed becomes 28 studs/s (canon). 1.0 s after the banner, the dash button pops in under the right thumb and pulses twice. Using it is optional here. |
| Prompt | Banner only. |
| Sound | `SFX_TierUp` (rising three-note chime). Music adds a percussion layer and keeps it. |
| Camera | Follow distance grows from 14 to 17 studs over 0.6 s **(tune)** (chapter 02's tier 1 and tier 2 values). The Fry's own animation freezes for 0.10 s as the swell starts (the hit-stop in chapter 02, section 5.1); the world does not slow. |
| Fail-safe | T = 30 and mass < 10: every krill within 30 studs homes on the mouth at 14 studs/s (`ftue_failsafe` = `grow_homing`). T = 40 and mass < 10: ten krill spawn 8 studs ahead and swim into the mouth (`ftue_failsafe` = `grow_burst`). Both need input in the last 10 s. |

#### B5 · First trait (T 22 to 45)

| | |
|---|---|
| On screen | 1.0 s after the tier-up banner, five Glowfry swim out of the Glow Grotto in a line toward the player. Each carries a soft light, a green outline and a small ring that marks trait prey. Trait slot 1 appears on the HUD with five empty pips. |
| Player does | Eats five Glowfry. |
| Game does | Each one fills a pip and sends a line of light down the Fry's body. On the fifth: the body lights up, the Nursery's ambient light drops 20% for 2 s so the glow reads, the banner GLOW shows for 1.5 s with the trait icon, and the slot fills. The trait is fixed: every new player gets `glow`. |
| Prompt | Pips. Glowfry swim at 8 studs/s and circle within 12 studs of the player. |
| Sound | `SFX_TraitPip` rising one step per pip. `SFX_TraitGained` (a warm chord). Music adds a shimmering pad and keeps it. |
| Camera | Follow camera. On the fifth pip, a 0.5 s push-in of 3 studs and back. |
| Fail-safe | 15 s in this stage with fewer than five eaten: the remaining Glowfry home on the mouth at 14 studs/s. T = 50: they home at 20 studs/s, so the trait arrives by T = 55 (`ftue_failsafe` = `trait_homing`). T = 70 without the trait: the stage moves on anyway and the Glowfry keep following until eaten. |

#### B6 · Call home (T 45 to 58)

| | |
|---|---|
| On screen | 2.5 s after the GLOW banner the kelp curtain at the Gap parts with a rustle. The home marker appears at the screen edge with the word HOME. A bubble trail runs from the player through the Gap. One second later a long shadow slides across the sand beyond the Gap and is gone. |
| Player does | Follows the trail, eating krill placed along it. |
| Game does | Nothing else. |
| Prompt | Home marker and bubble trail. |
| Sound | `SFX_KelpPart`. Music drops the percussion layer when the shadow passes. `SFX_PredatorShadow` (a low swell, not a jump scare). |
| Camera | 0.6 s widen of field of view from 70° to 76° when the curtain opens, to show the way out, then back. |
| Fail-safe | 8 s without moving toward the Gap: the home marker pulses and the trail brightens. 20 s: a krill swarm drifts along the trail as a lure (`ftue_failsafe` = `home_lure`). 40 s: a gentle Nursery current starts pushing toward the Gap at 6 studs/s (`ftue_failsafe` = `home_push`). |

#### B7 · The chase (T 58 to 66)

Section 5 has the full staging. Summary:

| | |
|---|---|
| On screen | A Barracuda with a red outline bursts from a rock shadow behind the player. Red glow on the screen edge nearest it. The dash button pulses with DASH!. |
| Player does | Dashes and swims down the channel along the bubble trail. |
| Game does | The Barracuda keeps 12 studs behind, lunges three times and misses three times, then gives up at 6 s (canon). It cannot touch the player. |
| Prompt | Dash pulse. |
| Sound | `MUS_Chase` sting replaces the Nursery music. `SFX_BarracudaSnap` on each lunge. `SFX_Dash`. |
| Camera | One 0.8 s look-back at the start (35° yaw, control kept), then a field of view of 78° for the chase and a 0.2 s shake on each snap. |
| Fail-safe | Section 5.4. |

#### B8 · Home Current (T 66 to 88)

| | |
|---|---|
| On screen | At the channel's end a pearl-white current picks the player up and carries them over the Sunlit Reef. The reef opens out below; other players' creatures are visible. Ahead, a column of soft light marks the player's cove, with their name on the sign. |
| Player does | Steers, or nothing. Krill stream through the current and can be eaten. |
| Game does | The current carries at +60% of swim speed (canon): 44.8 studs/s at tier 2. It ends 30 studs short of the cove mouth, pointing at it. |
| Prompt | Home marker. The cove beacon (`FX_CoveBeacon`). |
| Sound | `SFX_CurrentEnter` (a whoosh). `MUS_Current`: the chase music resolves into a wide, relieved theme. |
| Camera | Field of view opens from 70° to 80° for the ride and returns over the last 2 s. Follow distance +4 studs. |
| Fail-safe | The player may steer out of the current; the marker and trail stay. 10 s outside the current and more than 80 studs from the cove: a branch of the current re-forms at the player's position. See 5.5 for the distance rule. |

#### B9 · Bank (T 88 to 92)

Section 6 has the full walk-through.

| | |
|---|---|
| On screen | Crossing the cove mouth: white flash, the stamp BANKED, the mass bar pours into a Pearl counter that appears for the first time. |
| Player does | Swims in. |
| Game does | Pays 3 Pearls per mass (canon 5.4). The creature becomes specimen 1. A new Fry hatches in the cove. |
| Sound | `SFX_Bank` (a deep, satisfying clunk and chime). `SFX_PearlCount`. `MUS_Cove`. |
| Camera | A 2.5 s orbit inside the cove; any touch after 0.5 s of orbit ends it. |
| Fail-safe | 12 s within 60 studs of the cove mouth without entering: a slow current pulls toward the mouth at 8 studs/s. |

#### B10 and B11 · Cove and cliffhanger (T 92 to 120)

See section 6.

#### B12 · Run 2 starts (T 115 to 130)

| | |
|---|---|
| On screen | The new Fry leaves the cove mouth into the edge of the Sunlit Reef. 5 s later the goals chip slides in at top left with three icon rows (section 7.2). |
| Player does | Swims out. |
| Game does | Stage `S10_RUN2`. Run 2 assists apply (section 4). Krill and plankton are dense near the cove mouth: at least 12 krill within 50 studs for the first 30 s of this run. |
| Prompt | Bubble trail for the first 40 studs only, then nothing. |
| Sound | `MUS_Reef` fades in over 2 s. |
| Camera | Follow camera. |
| Fail-safe | 20 s in the cove after the cliffhanger: the mouth pulses and a trail leads out. 40 s: a krill swarm drifts past the mouth. |

#### B13 · Open water (T 130 to 180)

| | |
|---|---|
| On screen | Krill (green outline), a Sardine school with no outline (tier 2: not food yet), other players. The tide clock counts down. |
| Player does | Eats, grows. |
| Game does | Reaching tier 2 shows NIBBLER again and the Sardines turn green in the same instant. This teaches the colour language without a word. |
| Prompt | None beyond the outlines. |
| Sound | Normal game audio. |
| Camera | Follow camera. |
| Fail-safe | 30 s into run 2 with mass < 5: krill within 30 studs drift toward the player at 4 studs/s until mass reaches 10 (`ftue_failsafe` = `run2_homing`). |

**What must be true at T = 175 (Roblox's 180-second line):** the player is steering a creature in open water, has grown at least once in this run, sees a goal chip with progress on it, sees a tide countdown, and has not yet been shown anything to buy.

### 3.7 Idle and absence rules

| Situation | Rule |
|---|---|
| No input for 4 s (stages `S2` to `S5`) | Ghost thumb returns until the next input |
| No input for 8 s | The current beat's target pulses and its fail-safe starts early |
| No input for 20 s | Hold: beat timers freeze, scripted prey idles nearby, music is low-pass filtered. Everything resumes on input. (`ftue_failsafe` = `afk_hold`) |
| No input during the chase | Section 5.4 |
| App goes to the background | Same as the 20 s hold, at once |
| Disconnect before the first bank | Section 9 |

How the timers are read (set by task S6-C2 where this chapter was silent; chapter 14, section 5.1):

- The 8 s and 20 s rules, and the hold on going to the background, apply in `S2` to `S5`, `S7`, `S9` and `S10`. Not in `S1` (the hatch ends by itself), `S6` (section 5.4) or `S8` (control is suspended).
- "Beat timers" are every fail-safe timer, including those set on T (T = 30, 40, 50, 70). They run on a beat clock that stops during a hold; T itself, and every analytics value, keeps running.
- B6's 8, 20 and 40 s count from the moment the curtain opens and restart whenever the player moves toward the Gap. The curtain opens 2.5 s after `S5` starts also when `S5` started at T = 70 without the trait.
- B12's 20 and 40 s count from the tide clock (6.1, 10.3 s after the bank).
- Turning back into the Nursery during the chase returns the stage to `S5`; the next crossing re-enters `S6`.
- A run resumed in `S6` cannot replay the crossing, so the chase counts as `skipped` and the script carries on in `S7`.
- The fast form's halved idle timers are this section's 4, 8 and 20 s, and B6's 8, 20 and 40 s.

### 3.8 When each HUD element first appears

| Element | First appears | Tag |
|---|---|---|
| Settings gear (40% opacity, top right) | T = 0 | [MVP] |
| Mass bar | First bite | [MVP] |
| Dash button | 1.0 s after the first tier-up | [MVP] |
| Trait slot 1 | Glowfry appear | [MVP] |
| Home marker | `S5_CALL_HOME` | [MVP] |
| Pearl counter | First bank | [MVP] |
| Tide clock | Cliffhanger, 10 s after the first bank | [MVP] |
| Goals chip | 5 s into run 2 | [MVP] |
| Trait slots 2 and 3 | First trait prey eaten in run 2 or later | [MVP] |
| Codex button | Second bank | [MVP] |
| Shop button (Robux) | Second bank, or 6 minutes of account play time, whichever is first **(tune)**; never before T = 120 | [MVP] |
| Ability button | First run as a species with an active ability (not Minnow: Dart is passive) | [MVP] |
| Server leaderboard chip (the canon's "biggest on this server" strip) | First time at tier 3 in run 2 or later | [MVP] |

There is no chat button: Roblox text chat is switched off in the MVP (canon section 14).

## 4. First-run assists

"Standard" means the value every player gets; the controls chapter owns standard values and the ones shown here are assumptions **(tune)**.

| Assist | Run 1 value | Run 2 value | Standard | Turns off exactly when |
|---|---|---|---|---|
| Steering pull toward food | Heading bends up to 60% of the way toward green-outlined prey inside a 35° half-angle cone, 30 studs | 40% | 25%, 20° cone, 20 studs | Run 1 value ends at the first bank. Run 2 value ends when run 2 ends. |
| Mouth zone size | ×1.6 radius | ×1.3 | ×1.0 | Same as above |
| Prey swims toward the player | Scripted krill drift in at 6 studs/s inside 25 studs and never scatter | Only the `run2_homing` fail-safe | Krill scatter (canon) | When the player crosses the Gap in run 1 |
| Glowfry in the Nursery | 5 scripted Glowfry, 8 studs/s, circling | None | Glowfry live in Reef caves and Kelp (canon) | When Glow is gained |
| Scripted predator | Rubber-banded Barracuda that cannot bite (section 5) | None | Real Barracuda | When the chase ends |
| First-run shield | No player, predator or hazard can eat, stun, hook, burn or slow the newcomer. Other players see a white bubble-shield outline on them, never red or green (chapter 02, section 6.3), and bump off harmlessly. | Off | — | At the first bank, or after 240 s of play time **(tune)** if the player has not banked. The 240 s count only time in control of the creature on this account, are saved in the profile (`newcomer.shieldUsed`, chapter 09), and do not restart on a rejoin: a returning player has only what is left. The creature's bubble sheen flickers for the last 10 s. (`ftue_shield_end`) |
| Predator grace | — | Computer-controlled predators do not target the newcomer for the first 45 s after leaving the cove | None | 45 s into run 2 |
| Newcomer bubble | — | The first bite by another player on this account is absorbed: the bubble pops, the newcomer is thrown 30 studs clear with 3 s of protection, nothing is lost | None | When used (canon 5.2: absorbed once) |
| Tide visuals | Moon Tide darkness is not shown to the newcomer; the tide clock is hidden | Normal | Normal | At the first bank |
| Thicker food outline | +30% | +30% | Normal | When run 2 ends |
| Scraps | — | 50% for the first three deaths on the account (canon 5.5) | 10% | After the third death |
| Auto-dash | One automatic dash in the chase if the player has not dashed 1.5 s after the prompt | None | None | After it fires once |

Assists are driven by profile fields (`ftue.stage`, `banks_total`, `deaths_total`, `runs_total`, and the seconds of shield already used), not by the session, so they survive a reconnect and cannot be re-armed by rejoining.

## 5. The scripted chase

### 5.1 Purpose

Teach three things in six seconds, without a word of explanation: red outline means run, the dash button exists, and home is where you run to.

### 5.2 Guarantee

The chase cannot be failed. The scripted Barracuda has no bite. It exists only for this player (drawn by their client, tracked by the server as a flag, invisible to everyone else), and the first-run shield (section 4) stops everything else in the reef from touching them.

### 5.3 Staging

| Chase time (s) | What happens |
|---|---|
| — | During B6 a long shadow crosses the sand beyond the Gap. |
| 0.0 | The player crosses the Gap. The Barracuda (`M_Pred_Barracuda`, red outline) bursts from a rock shadow 50 studs behind and 20 studs to the right. `MUS_Chase` starts. Red glow on the right screen edge. |
| 0.0 to 0.8 | Camera yaws 35° toward the Barracuda and back. The creature keeps obeying input throughout. |
| 0.3 | The dash button pulses with DASH!. |
| 1.5 | Lunge 1. Red edge flash 0.4 s before. The Barracuda closes to 3 studs behind the tail, snaps (`SFX_BarracudaSnap`, a wooden clack), bubbles burst, 0.2 s camera shake, then it falls back to 14 studs. |
| 3.5 | Lunge 2, same. The channel bends here; the Barracuda swings wide on the bend (canon: it chases in straight lines), which shows that turning beats it. |
| 5.5 | Lunge 3, same. |
| 6.0 | It gives up (canon: 6 s): clips a coral branch with a comic bonk, shakes its head and swims off. The red outline and edge glow fade over 0.5 s. `MUS_Chase` resolves. |
| 6.0 to 8.0 | The player reaches the Home Current mouth. |

**Speed rule.** The Barracuda's speed is the player's average speed over the last 0.5 s multiplied by a factor, clamped to 10 to 40 studs/s **(tune)**:

| Gap to the player | Factor |
|---|---|
| Under 12 studs | 0.90 |
| 12 to 25 studs | 1.00 |
| Over 25 studs | 1.25 |

It never comes closer than 5 studs except during a lunge, and a lunge always stops 3 studs short.

**Reward for doing it right.** A dash that starts in the 0.6 s before a snap triggers a sparkle on the creature and a bright ping (`SFX_PerfectDodge`). Nothing else is granted.

**If the player reaches the Home Current before 6 s,** the chase ends at that moment: the Barracuda hits the edge of the current and tumbles away.

### 5.4 If the player does the wrong thing

| Player does | Game does | Logged as (`ftue_chase_result`) |
|---|---|---|
| Does not dash within 1.5 s of the prompt | One automatic dash along the trail; the dash button visibly presses itself. The prompt stays until the player dashes. | `assisted` |
| Stops moving | The next lunge's bow wave shoves the player 20 studs along the trail. After two shoves the Home Current mouth extends back up the channel to the player. | `assisted` |
| Swims at the Barracuda | On reaching 5 studs it snaps, misses, and the player is flung past and 20 studs down the trail with a 0.4 s impulse. | `assisted` |
| Turns back into the Nursery | The Barracuda cannot enter (canon: the Nursery is safe). It circles outside the Gap for 4 s and leaves. After 5 s the trail pulses. On the second exit the chase runs once more. On a third exit there is no predator. | `retreated`, or `skipped` if the chase never completed |
| Swims up to the surface | The Barracuda follows. Gulls ignore a shielded player. | `clean` or `assisted` as above |
| Hugs a wall or gets stuck on the bend | Channel walls are smooth and slide the player along. If speed stays under 5 studs/s for 1 s, treated as "stops moving". | `assisted` |
| Never leaves the Nursery | Section 3.6, B6 fail-safes. | — |

A chase with no automatic help is logged `clean`. The value on every `ftue_chase_result` is the number of manual dashes.

### 5.5 The trip home and which cove a newcomer gets

The route from the Home Current mouth to the cove mouth should be at most 450 studs **(tune)**, a ride of about 10 seconds. To make that possible:

- When a player with `banks_total = 0` joins, the server gives them the free cove nearest the Gap.
- When a player with `banks_total > 0` joins, the server gives them the free cove farthest from the Gap among those within the nearest 20, so the four closest stay free for newcomers where possible **(tune)**. If all 20 are taken, they get the free one of the other four that is nearest the Gap.
- If the route is longer than 600 studs anyway, the Home Current's speed is raised so the ride takes 12 s.

The Home Current is drawn only for this player and disappears at the first bank.

### 5.6 Tone

The Barracuda is a toy-box villain: big eyes, an underbite, a clack for a bite, a bonk for a miss. Nothing is shown being hurt. If the `ftue_chase_mode` test (section 11) shows it loses younger players, the `escort` variant replaces it.

## 6. The first bank

### 6.1 Sequence

Times are seconds after the player crosses the cove mouth.

| Time | What happens | Sound |
|---|---|---|
| 0.0 | Server confirms the bank. Input is suspended. White flash (0.15 s). Stamp BANKED (0.8 s). | `SFX_Bank` |
| 0.3 | The mass bar empties into a Pearl counter that appears at top right. The counter rolls up by the bank amount, 3 Pearls per mass (example: mass 20 → +60 Pearls). It appears already holding the Codex Pearls earned during run 1 (section 6.2), which were credited silently while the counter was hidden. | `SFX_PearlCount` |
| 0.8 | Camera orbits the cove interior for 2.5 s. The banked creature swims on its own to perch 1 (chapter 03, section 6.10 owns the cove part names) and settles. A plate under it shows the species icon, the tier badge "2", the Glow icon and "6.6/h" beside a pearl. | `SFX_SpecimenPlace`, `MUS_Cove` |
| 1.3 | From here any touch ends the orbit. | |
| 3.3 | A new Fry hatches on the Home Stone, near the front of the cove. Control returns (3.5 s at the latest). `ftue.completed = true`. | `SFX_Hatch` |
| 6.3 | **First income tick.** Six Pearls pop out of the specimen one by one and fly to the counter: "+6". The amount is small on purpose: it is one true hour of this specimen's income, so the plate and the payout agree. This is the only income ever paid without a tap (canon section 11: the first-bank reward); every later claim is a tap on the pile or the welcome-back card. | `SFX_IncomeTick` |
| 8.3 | **Cliffhanger 1.** On the Species Wall, at the back of the cove, a dark Pufferfish silhouette lights at the edges. A ring around it fills to Pearls owned / 500 (example: 261 / 500, 52%). | `SFX_SilhouetteReveal` |
| 10.3 | **Cliffhanger 2.** The tide clock appears: a shell clock on the back wall of the cove and a small copy on the HUD, showing the next event's icon and a countdown in minutes and seconds. If an event is running it shows the event icon, a pulsing ring and the time left. | `SFX_TideClock` |
| 12.3 | The cove mouth pulses and a bubble trail leads out. | |

If the player leaves the cove before 12.3 s, the remaining items still fire in order, 4 s apart, as HUD pings in open water.

### 6.2 The numbers behind it

| Item | Rule | Example |
|---|---|---|
| Pearls from the bank | 3 per mass (canon 5.4; the rate drops only above 1,200 mass) | Mass 20 → 60 Pearls |
| Expected mass at the first bank | 15 to 23 **(tune)**. Mass 10 at the tier-up (Swarm A 6, the trail 2, two krill of Swarm B). After that, prey eaten inside the Nursery gives a tier 2 creature half its mass (chapter 05, section 2.1): up to 12 more krill (6) and 5 Glowfry at mass 1 each (2.5). Krill in the channel and the Home Current give full mass. | 20 |
| Specimen | Created because the creature is tier 2 or higher and a slot is free (canon). The fail-safes in B4 guarantee tier 2. | Minnow, tier 2, Glow |
| Specimen income | Base for the tier × (1 + trait bonuses) (canon section 11; chapter 05, section 3.3). Tier 2 earns 6 an hour and Glow is Common, +10%: 6 × 1.10 | 6.6 Pearls per hour |
| First income tick | One hour of the first specimen's income, rounded down as every claim is, paid once, 3 s after placement. Logged as cove income with SKU `income_first_tick`. | +6 Pearls |
| Bank + first tick | | 66 |
| Codex Pearls earned in run 1 | Chapter 05, section 3.8 pays these at the moment of discovery: plankton 20, krill 20, Glowfry 30, Glow 100, tier 2 as a Minnow 25. No number is shown until the counter appears at the bank. | 195 |
| Pearls on the counter after the first bank | Codex + bank + first tick | 261 |

### 6.3 What the cove shows

| Thing | State after the first bank |
|---|---|
| Perch 1 | The specimen, glowing, with its plate |
| Perches 2 to 6 | Empty, each with a faint creature outline. Perch 2's outline carries a tier 3 badge, which matches the third starter goal. |
| Home Stone | The player's new Fry |
| Species Wall | Pufferfish silhouette with its progress ring. Tapping it shows the Pufferfish card (name, the Puff ability as a 2-second looping clip, price 500 Pearls). Other species are not shown yet. |
| Tide clock | Next event and countdown |
| Cove sign (outside) | Player's name and best specimen (canon section 6) |

### 6.4 If the tide clock is far from zero

Events start on the quarter hour, so the wait is anywhere from 0 to 15 minutes. If the countdown is over 10 minutes when the cliffhanger plays, the tide clock ping is shortened to 0.6 s and the Pufferfish ring is held on screen 1 s longer, so the nearer goal leads.

## 7. Minutes 2 to 15

### 7.1 Rules for introducing things

- Triggers are states, not times. The times below are expectations for an average player.
- One introduction at a time. An introduction is a "ping": the new element appears with a 1.2 s highlight ring and at most one word. It never pauses the game.
- At least 20 s between pings. Pings queue; the queue holds while a red-outlined creature is within 40 studs.
- Nothing introduced in this window needs to be read to be used.

### 7.2 Starter goals

On the account's first day the three daily goals are a fixed set of two Easy and one Medium, the one exception canon section 11 allows to "one Easy, one Medium, one Hard". The goals and their difficulty come from chapter 03, section 9. Chapter 05, section 3.5 owns what each difficulty pays: Easy 100, Medium 125, Hard 175, and 100 more when all three are done.

| ID | Goal | Shown as | Difficulty | Reward (chapter 05) |
|---|---|---|---|---|
| `dg_eat_50` | Eat 50 prey | Krill icon, "0/50" | Easy | 100 Pearls |
| `dg_tier3` | Grow into a Snapper (tier 3) | Tier 3 badge | Easy | 100 Pearls |
| `dg_bank_snapper` | Bank a Snapper or bigger | Cave icon plus tier 3 badge | Medium | 125 Pearls |
| — | All three done | — | — | +100 Pearls |

Completing a goal sends its Pearls flying to the counter with `SFX_GoalDone`. No claim button.

### 7.3 Order of unlocks

| # | What opens | Trigger | Expected time | How it is introduced | Tag |
|---|---|---|---|---|---|
| 1 | First open-water run | Leaving the cove after the first bank | 2:00 | Bubble trail for 40 studs, dense krill near the mouth | [MVP] |
| 2 | Daily goals | 5 s into run 2 | 2:05 | Goals chip slides in; each row ticks as it progresses | [MVP] |
| 3 | Colour language | Tier 2 in run 2 | 2:30 | Sardines switch from no outline to green at the tier-up | [MVP] |
| 4 | Picking traits | First trait prey within 40 studs in run 2 | 3:00 | A ring ping on the prey; trait slots 2 and 3 appear on the first one eaten | [MVP] |
| 5 | Real predators | First Gull shadow or Barracuda within 60 studs, after the 45 s predator grace | 3:30 to 5:00 | Red edge glow on that side. No word. | [MVP] |
| 6 | A larger player | First player one or more tiers higher within 40 studs | 3:00 to 8:00 | They carry a red outline (canon). If they bite, the newcomer bubble pops and throws the newcomer clear (section 4). | [MVP] |
| 7 | Being gulped | First death | 4:00 to 7:00 | The creature pops into bubbles. The gulped screen shows who did it (creature icon and tier badge) and the scraps (50%) flying to the counter. Respawn at the cove in under 3 s. **No Revive offer on the account's first death.** | [MVP] |
| 8 | First goal complete | Goal progress | 4:00 to 6:00 | Pearls fly to the counter; the row gets a tick | [MVP] |
| 9 | Second bank | Banking run 2 or 3 | 6:00 to 8:00 | Specimen 2 goes to perch 2. The Codex button appears with a dot and opens to every entry filled so far: usually seven or more (Plankton mote, Krill, Glowfry, Sardine, Glow, and the Minnow's tier 2 and tier 3 stamps). The shop button appears with no ping. | [MVP] |
| 10 | Offline earning | Second bank | 6:00 to 8:00 | A moon icon with a pearl and "8h" appears on the cove wall beside the specimens | [MVP] |
| 11 | First tide event | The clock: 60 s warning before the next quarter hour | 0:00 to 15:00 | The tide clock pulses, `SFX_TideHorn` sounds, a wave sweeps across the top of the screen. At the start, a banner with the event's name (two words at most) shows for 1.5 s and the cove mouth glows in the event's colour. In the first 10 s a ping shows the event's key prey icon. | [MVP] |
| 12 | Revive offer | Second or later death on the account, when the lost creature had 30 mass or more (canon 5.5) | 6:00 onward | On the gulped screen: the creature as a ghost and a "25" Robux button. There is no timer and no ring: the offer stays until the player takes it or chooses to respawn (canon 5.5). Document 05 owns the price. | [MVP] |
| 13 | First species purchase | Pearls reach 500 | 6:00 to 9:00 | The silhouette's ring fills and it lights up in colour wherever the player is (HUD ping with the Pufferfish icon). At the cove, tapping it buys with a 0.6 s hold. The Pufferfish hatches on the Home Stone. | [MVP] |
| 14 | Ability button | First run as Pufferfish | 6:30 to 9:30 | The button appears beside the dash button. It pulses once, the first time a red-outlined creature comes within 30 studs. | [MVP] |
| 15 | Next species | Pufferfish bought | Same | The Eel silhouette replaces it on the wall with a ring at Pearls / 3,500 | [MVP] |
| 16 | Kelp Forest | First time within 80 studs of a current that leads there | 8:00 onward | The current is visible (canon). No prompt. | [MVP] |
| 17 | Server leaderboard | First time at tier 3 in run 2 or later | 4:00 onward | A chip with the player's rank on this server | [MVP] |
| 18 | Visiting coves | First time within 40 studs of another player's cove mouth after the second bank | 8:00 onward | The mouth shows a bubble icon | [L] |

### 7.4 Pearl budget check for the first session

Canon wants the Pufferfish (500 Pearls) by the end of the first session. Every amount below is chapter 05's: banking and scraps (sections 3.1 and 3.2), goal rewards at Reef Rank 1 (3.5) and Codex rewards (3.8). Reef Rank rewards are **[L]** and are left out.

| Source | Banks run 2 | Gulped in run 2 |
|---|---|---|
| Codex in run 1 (plankton, krill, Glowfry, Glow, tier 2) | 195 | 195 |
| First bank (mass 20) and first tick | 66 | 66 |
| Codex in run 2 (Sardine 20, tier 3 50) | 70 | 70 |
| `dg_tier3` | 100 | 100 |
| Run 2 at mass 40 | 120 | 60 (50% scraps) |
| `dg_bank_snapper` | 125 | 125 (run 3) |
| `dg_eat_50` | 100 | 100 |
| All three goals done | 100 | 100 (run 3) |
| Run 3 at mass 60 | 180 | 180 |
| **Total** | **1,056** | **996** |

The banking path passes 500 at the second bank (676 there, before `dg_eat_50`), at about minute 6 to 8. The gulped path passes it when `dg_eat_50` completes early in run 3 (591), at about minute 6 to 9. With every Codex row removed the totals are 791 and 731, so both paths still pass 500 by the end of run 3. If playtests show run masses lower than this, chapter 05 raises the goal rewards before changing the Pufferfish price.

## 8. Second session and day 2

A **session** is one join. For rules that say "second session", a join counts as a new session only if the previous one ended at least 10 minutes earlier **(tune)**; a quicker rejoin continues the old one.

### 8.1 Welcome-back flow

| Step | Time from control | What happens | Tag |
|---|---|---|---|
| 1 | — | Same loading screen. The player spawns as a Fry on the Home Stone of their own cove. No hatch close-up. | [MVP] |
| 2 | 0 to 2 s | Camera sweeps low across the specimens and ends on the Pearl Clam, where everything the cove earned sits in one pile, sized to the total (canon section 11: income collects in one pile; there is no pile beside each specimen). Control is live throughout. | [MVP] |
| 3 | 2 s | The Pearl Clam, left of the Home Stone (chapter 03, section 6.10), opens, full of Pearls, and the welcome-back card shows the amount with a Claim button (chapter 08). Tapping the clam's pile or the card's button collects everything: the pile flies to the counter and it rolls up. Swimming into the clam collects nothing (canon section 11). | [MVP] |
| 4 | With step 3 | Where the player is eligible for rewarded video and has not used today's Cove Boost, a small film-icon button sits beside the clam. Watching gives a Cove Boost: 2 more hours of cove income at once, once a day (canon section 12). It is never the default and collecting normally dismisses it. | [L] |
| 5 | 1 s after collecting, or on leaving the cove if the player did not collect | Streak card: the 7-day calendar with today stamped and today's reward flying to the counter. It closes itself after 2.5 s or on a tap. | [L] |
| 6 | 1 s later | The goals chip shows three new goals (random from day 2 on). | [MVP] |
| 7 | — | The tide clock is already running. The cove mouth pulses. | [MVP] |

Target: collecting and leaving the cove within 12 seconds of control **(tune)**.

| Rule | Value |
|---|---|
| Offline income | Sum of each specimen's hourly income × hours away, capped at 8 hours (canon); 24 with Tide Watcher [L] |
| Away under 10 minutes | No welcome-back card and no camera sweep. The income stays in the pile at the Pearl Clam until the player taps it. Nothing is added by itself. |
| Under 10 Pearls earned | The same: no card, the income waits in the pile for a tap. |
| Player leaves the cove without collecting | Nothing is collected. The income stays in the pile and keeps growing up to the cap; the clam can be tapped on any later visit (canon section 11: claimed by a tap, never automatically). |
| Away 8 hours or more | The clam is visibly overflowing, its bubble reads "Full" and the moon icon reads "8h" in white: the cap was reached. (Amber is kept for home, canon section 5.2.) |

### 8.2 Day 2

| Item | Design |
|---|---|
| Goal of the day | The Eel (3,500 Pearls; canon: day 2). Its silhouette ring is the first thing in view after the clam. |
| Streak [L] | Day 2 stamp. A missed day never sets the calendar back: the next box simply waits (canon section 11). Nothing is sold to protect a streak. |
| Daily goals | Three new goals at 00:00 UTC |
| New this session | Kelp Forest goals can now appear, which sends day-2 players to a new zone |

### 8.3 Starter Pack [L]

| Rule | Value |
|---|---|
| Eligible | Second session or later (canon), at least 2 banks on the account, not yet bought |
| When shown | After the first bank of the session, once the bank sequence has finished and the player has control. Never at login, never during a run, never on the gulped screen. |
| How shown | One card that slides up from the bottom: the Sunrise pattern shown on a Minnow (`pat_minnow_sunrise`), 5,000 Pearls, and the price, 99 Robux (chapter 05, section 8.3 owns contents and price). Two buttons: buy, close. Closing is one tap anywhere outside the card. |
| How often | At most once per session, in the first three eligible sessions only **(tune)**. After that it lives in the shop and never opens by itself. |
| Pressure | No countdown, no "last chance", no fake discount. |

## 9. Returning players and skipping

| Case | What happens |
|---|---|
| New account | Full FTUE |
| Who counts as new | `ftue.completed = false` in the profile. `ftue.version` (currently 1) is stored so a redesigned tutorial does not replay for old players. |
| Skip button | None. The FTUE never blocks input, lasts about 100 seconds, and a fast player finishes it faster. |
| Player ignores the script | They cannot leave the Nursery before `S5`. After that, banking by any route completes the FTUE and plays the section 6 sequence. |
| Shield runs out (240 s of play time used) before the first bank | Normal rules apply. The home marker and trail stay until the first bank. If gulped, they respawn at the cove (canon) and the first bank, whenever it happens, still plays section 6. |
| Disconnect mid-run before the first bank | Canon 5.5 applies, with no exception for a newcomer. The creature stays in the water for 10 s, open to attack by the rule, but the first-run shield still protects it (section 4), so nothing can eat it while any of its 240 s remain; those 10 s are not play time and use none of the shield. The run is then saved as suspended for 5 minutes. Rejoining in that time resumes the run at once, with no choice card, with its mass, traits and trait progress, and the first-time script resumes from the last completed beat (the saved `ftue.stage`, section 3.1): nothing already done is replayed. If the run is not resumed, it is lost and scraps are paid at the first-three-deaths rate of 50% (canon 5.5). |
| No run to resume on the next join (it was lost as above, or the disconnect came before control), first time | Next join restarts the FTUE from the hatch in a fast form: 0.6 s hatch, all idle timers halved, one chase attempt at most. `ftue.attempts` goes up by one. |
| The same, twice or more | From then on: spawn in the Nursery with the kelp curtain open, the home marker on, and no scripted prey or chase. The first-run shield does not restart: only what is left of its 240 s of play time applies. |
| Disconnect after the first bank | The FTUE is complete. Next join uses the welcome-back flow; any cliffhanger items not yet shown are already in the cove. |
| New device, same account | The profile belongs to the account, so there is no tutorial. |
| New input type on any device | The first time an account plays with touch, keyboard and mouse, or gamepad **[L]**, a controls hint for that input shows for 5 s at the start of the first run (`seen_controls[inputType]`). The keyboard and mouse hint shows the arrow keys alongside W (chapter 15, section 3.3). |
| Joining a friend or a private server [L] | Same FTUE. Friends can enter the Nursery; they cannot eat the newcomer's scripted prey. |
| Developer reset | In Studio and for user IDs on the developer list, the developer command `/ftue reset` clears `ftue.*`, and `/ftue overlay` shows T, J and the stage on screen. Text chat is off in the MVP, so these are not chat commands; document 09 owns how developers run them. |

## 10. What we will not do in the first two minutes

1. Sell anything. No shop button, price, pass advert or Robux prompt before the first bank and before T = 120 (canon), and no Revive offer on an account's first death.
2. Show a text box, a dialogue bubble, a narrator or a talking character.
3. Open a modal window or ask for a tap to continue.
4. Take control away for more than 3.5 seconds, or at any moment other than the first bank.
5. Let the player die, be stunned, be hooked or be slowed in run 1.
6. Let another player eat, block or steal food from the newcomer.
7. Give a random first trait, or use an egg, a wheel, a chest or a card flip.
8. Ask the player to choose anything: a name, a species, a control scheme, a graphics setting.
9. Show the avatar, the default Roblox loading screen, the default health bar or backpack, or the chat window.
10. Show a login streak, a daily reward, a starter pack or a rewarded video.
11. Ask for a like, a favourite, a group join, a follow or a notification permission.
12. Show goals, the Codex, a leaderboard or the tide clock before the first bank.
13. Put more than one number on the HUD before the first bank (there are none until the Pearl counter).
14. Point at more than one thing at once.
15. Darken the sea for a Moon Tide during run 1.
16. Make the player wait for a timer or a cooldown other than the dash.
17. Send the player to a separate tutorial place. A teleport costs a second load.
18. Play a "tutorial complete" screen or hand out a completion reward. The bank is the reward.
19. Use a jump scare. The predator is announced by a shadow and a swell first.
20. Explain traits, tiers or tides in words. Each is shown once and named with one word.

## 11. Variants to A/B test

Chapter 10, section 8 has the method and sample sizes. Each test is one config key. The control is the design described above.

| # | Config key | Control | Variant(s) | Hypothesis | Primary metric | Guardrail | Tag |
|---|---|---|---|---|---|---|---|
| 1 | `ftue_chase_mode` | `chase` | `escort`: no predator; trail and Home Current only | The chase raises tension and so raises the share who bank and who are still playing at T = 180. Risk: it scares the youngest players. | `fs_time_mark` = `s180` | Step `13_banked`, day-1 retention | [MVP] |
| 2 | `ftue_home_mode` | `current` | `swim`: bubble trail only, no carrying | Carrying the player removes the commonest way to fail the trip home and raises the first-bank rate. Risk: they do not learn the route, so bank less in runs 2 and 3. | Step `13_banked` | Bank rate in runs 2 and 3 | [MVP] |
| 3 | `ftue_cliffhanger` | `species_tide` | `species_only`; `species_tide_goals` (goals shown in the cove, before run 2) | More open questions give more reasons to start run 2, up to the point where the cove looks cluttered. | Step `17_run2_started` | `fs_time_mark` = `m10` | [MVP] |
| 4 | `ftue_trait_count` | `5` | `3`: the first trait needs three Glowfry (FTUE only) | Getting the trait about 8 s sooner raises the share still playing at T = 60. Risk: players expect three in later runs. | `fs_time_mark` = `s60` | Trait funnel step 2 → 4 in runs 2 to 5 | [MVP] |
| 5 | `ftue_first_trait` | `glow` | `spots`: five Dotted Gobies, big dots, +10% mass | Glow is the most visible change and makes a better first impression than a faster-growth trait. | Step `17_run2_started` | Step `13_banked` | [MVP] |
| 6 | `ftue_prompt_words` | `one_word` | `icons_only`: no HOME, no DASH! | Words help readers and cost non-readers nothing. If icons alone do as well, we remove the words and the localisation risk. | Share of `ftue_chase_result` = `clean` | Step `13_banked` | [MVP] |
| 7 | `ftue_hatch_intro` | `hatch` (1.5 s) | `instant`: control on the first frame | The hatch builds attachment and is worth its 1.5 s. If not, instant control raises first bite within 5 s. | `ftue_milestone` = `bite_le5` | `fs_time_mark` = `s60` | [MVP] |
| 8 | `ftue_first_tick` | `advance` (one hour of the specimen's income, 6 Pearls, after 3 s) | `none` | Seeing a specimen pay out at once makes players understand offline earning and return the next day. | Day-1 retention | Step `17_run2_started` | [MVP] |
| 10 | `run2_aim_assist` | `step_down` (section 4) | `full` (run 1 values kept through run 2); `off` (standard values from run 2) | A gentler step-down gets more players to tier 2 in run 2 without making later runs feel harder. | Step `18_run2_tier2` | Bank rate in runs 3 to 5 | [MVP] |
| 11 | `ftue_loading_toy` | `toy` | `static`: logo and bubbles only | The toy keeps players through a slow load. | Step `02_loading_screen` → `03_control` | `sys_load_time` | [MVP] |
| 12 | `starter_pack_timing` | `s2_after_bank` | `s2_login`; `s3_after_bank` | Offering after a win converts better than offering at login; waiting a session converts no worse and protects retention. | Starter pack funnel step 1 → 5 | Day-7 retention | [L] |

Number 9 (`revive_first_offer`, which showed the Revive offer on the first death) is withdrawn: canon 5.5 rules that the offer is never shown on an account's first death. The other numbers are kept so they still match chapter 10, section 8.

Run order at soft launch, one FTUE test at a time: 1, 2, 3, 4, then by need.

## 12. Build checklist

A tester ticks each item on the reference phone unless it says otherwise. "Fresh account" means a profile with `ftue.*` cleared by `/ftue reset`.

### Load

- [ ] L1. The default Roblox loading screen never appears after `PlayerAdded`; ours shows within 0.5 s.
- [ ] L2. No avatar is visible at any point.
- [ ] L3. The loading toy responds to a drag and the Fry eats dots.
- [ ] L4. Over 10 fresh joins, `PlayerAdded` to control has a median of 5 s or less and no join above 10 s.
- [ ] L5. With the network throttled so the minimum set takes over 8 s, the game starts at J = 8 with flat-colour textures and logs `load_partial`.
- [ ] L6. No geometry is seen popping in during the first 20 s.

### Script

- [ ] S1. Swarm A is on screen in the first frame after the hatch.
- [ ] S2. A tester who drags at once bites within 3 s. A tester who never touches the screen gets a bite by T = 5.
- [ ] S3. The mass bar appears on the first bite and not before.
- [ ] S4. Bite pitch rises on quick consecutive bites and resets after 1.5 s.
- [ ] S5. Following the trail without hurrying, tier 2 arrives between T = 18 and T = 28.
- [ ] S6. The creature grows a little with every bite before the tier-up. At tier-up it does the 0.6 s swell and settles at 1.3×, NIBBLER shows for 1.5 s, and nothing pauses.
- [ ] S7. The dash button appears 1 s after the first tier-up and not before.
- [ ] S8. Five Glowfry appear 1 s after the tier-up banner; each fills one pip.
- [ ] S9. On the fifth Glowfry the body lights up, the Nursery dims for 2 s, GLOW shows for 1.5 s.
- [ ] S10. The first trait is Glow on 10 fresh accounts out of 10.
- [ ] S11. Before the trait, the Gap is closed and the creature bounces off the kelp curtain.
- [ ] S12. The curtain opens 2.5 s after the GLOW banner; the home marker, HOME and the bubble trail appear.
- [ ] S13. A tester who only ever taps (never drags) still reaches tier 2 by T = 45 and Glow by T = 55, with the right `ftue_failsafe` events logged.
- [ ] S14. With no input for 20 s the timers freeze and the music is filtered; both resume on input.
- [ ] S15. Only the words in section 3.3 appear before T = 180.

### Chase

- [ ] C1. A shadow crosses beyond the Gap before the player reaches it.
- [ ] C2. The Barracuda appears as the player crosses the Gap, with a red outline and a red edge glow on its side.
- [ ] C3. The creature responds to input during the 0.8 s look-back.
- [ ] C4. Three lunges at 1.5, 3.5 and 5.5 s; none touches the player; the Barracuda leaves at 6.0 s.
- [ ] C5. In 20 attempts trying to be caught (stopping, swimming at it, hugging walls) the player is never gulped and never loses mass.
- [ ] C6. With no dash input, one automatic dash fires at 1.8 s and the result is logged `assisted`.
- [ ] C7. Retreating into the Nursery makes the Barracuda circle and leave; the second exit runs the chase again; the third has no predator.
- [ ] C8. A second player on the same server does not see the first player's Barracuda, Home Current or scripted prey.
- [ ] C9. A tier 4 test player cannot eat the newcomer anywhere before the newcomer's first bank or the end of the newcomer's 240 s of shielded play time; leaving at 100 s and rejoining leaves 140 s, not 240.

### Bank and cove

- [ ] B1. The Home Current carries a player who gives no input to within 30 studs of their cove mouth.
- [ ] B2. The cove a fresh account is given is the free cove nearest the Gap.
- [ ] B3. The ride from the current mouth to the cove takes 12 s or less.
- [ ] B4. On crossing the cove mouth: flash, BANKED, the Pearl counter appears holding the run's Codex Pearls and rises by 3 Pearls per mass banked.
- [ ] B5. The specimen sits on perch 1 with a plate showing Minnow, tier 2, Glow and 6.6/h.
- [ ] B6. Control returns within 3.5 s of the bank; a touch after 1.3 s returns it sooner.
- [ ] B7. 3 s after placement, +6 Pearls fly from the specimen to the counter.
- [ ] B8. The Pufferfish silhouette shows a ring that reads Pearls owned / 500.
- [ ] B9. The tide clock shows the correct next event for the current UTC quarter hour and counts down to the second.
- [ ] B10. A fresh account banks within T = 120 when played by someone who has never seen the game (5 of 8 playtesters or better).

### After the bank

- [ ] P1. No shop button, price or Robux prompt appears before the second bank or 6 minutes of play.
- [ ] P2. The goals chip appears 5 s into run 2 with the three starter goals.
- [ ] P3. Sardines have no outline at tier 1 and turn green at the moment of tier-up.
- [ ] P4. No computer-controlled predator targets the newcomer in the first 45 s of run 2.
- [ ] P5. The first bite from another player pops the newcomer bubble, throws the newcomer 30 studs and costs nothing; the second bite gulps normally.
- [ ] P6. The first death pays 50% scraps and shows no Revive offer; the second death at mass 30 or more shows it, with no timer; a second death under mass 30 does not.
- [ ] P7. At 500 Pearls the silhouette lights up; a 0.6 s hold buys the Pufferfish; the next run hatches as a Pufferfish with an ability button.
- [ ] P8. During a Moon Tide, a newcomer in run 1 sees no darkening.
- [ ] P9. Pings never overlap and are at least 20 s apart.

### Returning and skipping

- [ ] R1. Leaving at T = 30: nothing can eat the shielded creature in its 10 s in the water. Rejoining within 5 minutes resumes the run and the script from the last completed beat. Rejoining later finds the run lost, with 50% scraps paid, and restarts the FTUE in the fast form.
- [ ] R2. Losing the run that way twice before the first bank gives the short form on the next join.
- [ ] R3. An account that has banked once never sees the hatch or the chase again, on any device.
- [ ] R4. The second session starts in the cove with the clam, and Pearls collected by tapping it equal specimen income × hours away, capped at 8. Leaving without tapping collects nothing.
- [ ] R5. Rejoining after 2 minutes does not count as a second session.

### Analytics and performance

- [ ] A1. One fresh playthrough to the start of run 3 logs onboarding steps 01 to 20 in order, each exactly once (checked in the Studio event buffer; see chapter 10, section 2.4).
- [ ] A2. `ftue_milestone` fires once each for bite, tier 2, trait and bank, with T as the value.
- [ ] A3. Frame rate on the reference phone stays at 30 or more from T = 0 to the first bank.
- [ ] A4. Every tunable in this chapter can be changed in `FtueConfig` without touching other code.

## 13. Proposed canon changes

Canon values are used as written throughout this chapter. These are the suggestions for `01-game-canon.md` that are still open; the ones the canon has adopted or ruled on have been removed.

| # | Canon section | Suggestion | Why |
|---|---|---|---|
| 1 | 12 | Widen "nothing is sold in the first two minutes" to "nothing is sold before the first bank or before two minutes, whichever is later". | A slow player can reach minute 4 without having banked; a price there is the first thing they are asked about. |
| 2 | 17 | Add two measures on the same clock as the rest: first trait within 60 s of control, 70%; first bank within 120 s of control, 50%. | Section 1.2 tracks both as chapter targets; the canon has no measure between tier 2 and the first bank. |
| 3 | 6 | Note that cove assignment prefers coves near the Nursery exit for players who have never banked. | Keeps the first trip home at about 10 seconds. |

**Open points for other chapters**

| # | Chapter | Point |
|---|---|---|
| 1 | 05 | Confirm that Codex Pearls earned before the first bank are credited silently and shown when the Pearl counter first appears (section 6.1). |

Settled since: chapter 03 now has the Glow Grotto, the kelp curtain, the channel and the Home Current on the map and names the first-day goal set, and chapter 05 confirms that set pays 425 Pearls. The canon (sections 7 and 11) has adopted the passive badge and the first-day goal exception.
