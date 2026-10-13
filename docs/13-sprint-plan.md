# 13 · Sprint plan

This chapter turns chapters 01 to 12 and 15 into a week-by-week build. The canon (`01-game-canon.md`) wins any disagreement. Module names come from chapter 09, asset names and hours from chapter 07, screen IDs from chapter 08, funnels and events from chapter 10, release stages from chapter 12 and device rows from chapter 15.

Written on Tuesday 13 October 2026. Sprint 0 starts on Monday 19 October 2026.

**The short version.** Everything tagged [MVP] needs about 1,016 first-pass hours of art and audio (chapter 07, section 14.2), before code and before the 30% review allowance. One person cannot do that in three months. This plan therefore soft-launches a smaller build, the **soft-launch slice** (section 3), which needs 566 of those hours. The canon (section 15) names this slice as the build the soft launch starts with. At 30 owner hours a week the slice reaches soft launch on **Thursday 1 April 2027**, which is 23 weeks and not three months. Even at about 45 hours a week the slice takes three and a half months (Thursday 4 February 2027). Every date in this chapter is an estimate that Sprint 0 to Sprint 2 will correct.

## 1. How to read the plan

### 1.1 Terms and IDs

| Term | Meaning |
|---|---|
| **WH** (work hours) | Hours of work as the bible estimates them. For art and audio: the first-pass hours in chapter 07. For code: the task sizes below. WH is what an unassisted person would spend. |
| **OH** (owner hours) | Hours of the owner's own time: briefing, reviewing, Studio checks, device tests, art direction, publishing. Capacity is counted in OH. |
| **Size** | **S** under 2 hours (1.5 WH), **M** half a day (4 WH), **L** one day (8 WH), **XL** two days or more (12 to 16 WH). Code sizes include one review round. |
| **Who** | **Agent**: an agent finishes it from the bible and the headless gate; the owner reads a summary. **Agent + owner**: the owner must check it in Studio or on a device. **Owner**: done by hand. |
| **Task ID** | `S<sprint>-C<n>` code, `-A<n>` art and audio, `-D<n>` design, data and tuning, `-T<n>` test, `-M<n>` marketing and operations. |
| **Module ID** | `B00` to `B42` are the rows of chapter 09, section 19. |
| **Spike item** | "Spike S1" to "spike S18" are the rows of chapter 09, section 6.11. |
| **Screen** | "Screen S01" to "screen S36" are the rows of chapter 08, section 2.1. |
| **`S` day, `P` day** | Soft-launch day and public-launch day, as in chapters 11 and 12. `S−4` means four weeks before soft launch. |
| **Device row** | A row of the test matrix in chapter 15, section 8. Row 1 is the low Android phone, row 2 the small iPhone, row 7 the development Mac. |
| **Reference** | "09 §6.11" means chapter 09, section 6.11. |

The letter S is used for four things in the bible (sprints here, spike items in chapter 09, screens in chapter 08, the soft-launch day in chapters 11 and 12). This chapter always writes the word in front of the number, except in task IDs, which always contain a hyphen.

### 1.2 Capacity assumption

The owner's weekly hours are not confirmed (chapter 14, decision D1). The base case is:

| Input | Base case | Status |
|---|---|---|
| Owner time | 30 OH a week | Assumption, to be confirmed by the owner before Sprint 0 |
| Fixed weekly rhythm | 4 OH (section 1.4) | Fixed |
| Time left for tasks | 26 OH a week | Derived |
| Holidays and illness | None planned. Sprints 9 and 10 cover 21 December 2026 to 3 January 2027. Each week off moves every later date by one week. | Assumption |
| Share of code time agents save | 70%. The owner spends 0.30 OH per code WH. | Unproven. Measured in Sprints 1 and 2. |
| Share of art time agents save | 60% on average. The owner spends 0.52 OH per art WH (0.40 share × 1.30 review allowance from chapter 07, section 14.3). | Unproven. Measured on the Minnow in Sprints 0 to 2. |
| Owner share by kind of art work | Scripts and placeholders 25%, kit meshes and textures 30%, creatures 45%, Studio look work (assembly, lighting, water, effects) 60%, sound 50%, music selection 100%, store art 50% | Unproven |
| Design, tuning, device tests, publishing, marketing | Agents save nothing. 1.00 OH per hour. | Assumption |
| Heavy jobs on the Mac | At most two at once (Studio play test, Blender bake). Headless agents are not limited. | Fixed (09 §2.5) |

**How the assumption is tested.** Every task records its WH estimate and the OH actually spent. At the Friday review of Sprint 2 the two ratios (code and art) are recomputed from Sprints 0 to 2 and every date in section 4 is recalculated. If the art ratio is above 0.60 OH per WH or the code ratio is above 0.35, gate G1 in section 9 applies.

**Totals for the slice, base case (estimates).**

| Work | WH | OH |
|---|---|---|
| Sprint 0 spikes (all of Sprint 0, including its 18 WH of art spikes) | — | 30 |
| Art and audio in the slice (chapter 07 hours), Sprints 1 to 22 | 566 | 273 |
| Interface images in the slice (no hours in chapter 08; estimated here at 0.4 WH a drawing for about 110 drawings) | 45 | 17 |
| Code in the slice (sum of task sizes in section 5; OH is 0.30 × WH plus the device tuning named in the tasks) | about 535 | 171 |
| Design, data and tuning | — | 35 |
| Device, multi-client and playtest work beyond the Friday slot | — | 30 |
| Marketing and operations before `S` | — | 47 |
| Weekly rhythm, 22 sprints × 4 (Sprint 0 is all spikes) | — | 88 |
| **Total to soft launch** | | **about 690 OH (691), 23 sprints** |

The code, art, rhythm and total figures are the sums of the "Hours" lines of Sprints 1 to 22 in section 5 (code 171, art and audio with interface images 290, other 112, rhythm 88), plus the 30 OH of Sprint 0. The split of the 112 "other" hours into the three rows above is an estimate.

### 1.3 The three pace scenarios

All three use the same slice and the same agent assumptions. Soft launch itself lasts about 11.5 weeks in every case because Roblox's evaluation and the 100-daily-user rule set its length, not the owner's hours (12 §1.4, §1.5).

| Milestone | 15 OH a week | **30 OH a week (base)** | 45 OH a week |
|---|---|---|---|
| Spike decision | Fri 23 Oct 2026 | **Fri 23 Oct 2026** | Fri 23 Oct 2026 |
| First playable | Sprint 9, Fri 25 Dec 2026 | **Sprint 4, Fri 20 Nov 2026** | Sprint 3, Fri 13 Nov 2026 |
| First-two-minutes build, grey-box | Sprint 15, Fri 5 Feb 2027 | **Sprint 7, Fri 11 Dec 2026** | Sprint 5, Fri 27 Nov 2026 |
| First-two-minutes build, finished art | Sprint 29, Fri 14 May 2027 | **Sprint 13, Fri 22 Jan 2027** | Sprint 9, Fri 25 Dec 2026 |
| Soft launch (`S`) | Sprint 49, Thu 30 Sep 2027 | **Sprint 23, Thu 1 Apr 2027** | Sprint 15, Thu 4 Feb 2027 |
| Go/no-go read | Mon 20 Dec 2027 | **Mon 21 Jun 2027** | Mon 26 Apr 2027 |
| Public launch (`P`), canon scope | 2029. Not a workable plan. | **Sprint 65, Thu 20 Jan 2028** | Thu 2 Sep 2027 |
| Public launch with the cut candidates removed (section 6.3) | Early 2029 | **Sprint 59, Thu 9 Dec 2027** | Thu 5 Aug 2027 |
| Console switch on | — | **`P` + 3 weeks: Thu 10 Feb 2028** | Thu 23 Sep 2027 |

What this table says plainly:

- **At 15 hours a week the project does not work as designed.** Soft launch is a year away and the launch scope cannot be built. At that pace the only sensible plan is the slice alone, with the decision to raise hours or stop taken at the go/no-go.
- **At 30 hours a week the slice takes five and a half months**, and the full launch scope takes another seven months after a "go".
- **At 45 hours a week the slice takes three and a half months.**

**Sensitivity to the agent assumption (30 OH a week).**

| If | Change in OH to soft launch | Soft launch moves to |
|---|---|---|
| Agents save 75% of art time instead of 60% | −115 | About Thu 4 Mar 2027 |
| Agents save 40% of art time instead of 60% | +160 | About Thu 13 May 2027 |
| Agents save 50% of code time instead of 70% | +100 | About Thu 29 Apr 2027 |
| Agent-made creatures fail the quality bar and the owner models them by hand (creature share 100%) | +60 | About Thu 15 Apr 2027 |

### 1.4 Working method

- **One-week sprints, Monday to Sunday.** Sprint 0 is 19 to 25 October 2026. Weekends are not planned work.
- **Fixed weekly rhythm (4 OH).**

| When | What | Time |
|---|---|---|
| Monday | Sprint planning: close last sprint's milestone, move unfinished issues, confirm this sprint's tasks, start the first agents. Once the game is live: the 30-minute numbers review of 10 §11, done first. | 1 h |
| Daily, once live | The 5-minute alarm check (10 §9.1) and the daily routine (12 §5.4). Counted under operations, not rhythm. | — |
| Thursday, once live | Publish at 15:00 UTC (12 §3.1). Never after 18:00 UTC on a Friday. | Counted under operations |
| Friday | Playtest the sprint's demo on device row 1 and row 7, tick the acceptance list, record the demo clip, write five lines of review in the sprint milestone. | 2 h |
| Friday | Tracker and bible upkeep: burn-down row, WH and OH actuals, bible edits for anything that changed. | 1 h |

- **A sprint is done when its acceptance list is ticked.** A task that is not done moves to the next sprint; the list of "what gets cut first" in each sprint says which tasks move without discussion.
- **Float.** Tasks marked *(float)* can slide one sprint without moving a milestone.

**Definition of done**

| Kind | Done when |
|---|---|
| **Code** | `lune run tools/check` passes (format, lint, types, unit and simulation tests; 09 §2.4). Every new function in `shared/Logic` and every codec has specs (09 §16.1). The module follows the dependency rules of 09 §4.4. CI is green on `main`. If it runs in the engine: the smoke test of 09 §16.4 passes through the Studio MCP server. If it changes feel or frame rate: checked by the owner on device row 1. Tunable numbers are in `Config/Defaults.luau` or the content tables, not in code. |
| **Art** | `build.py` reproduces the asset from source (06 §15.4). The `validate` and `palette` steps pass. A contact sheet exists (06 §15.5). A reviewer agent has passed all applicable lines of the 18-line checklist (06 §16.1). The owner has signed off the contact sheet. The asset is imported, shown in the game on device row 1, and its row in `manifest.csv` is flipped from placeholder to final. Budgets of 06 §6.3 hold. |
| **Audio** | Exported as OGG at the levels set by the audio batch tool. Loops are checked for clicks. The licence or source is recorded (12 §7, C19 and C20). Heard in the game on phone speakers and on headphones by the owner. Manifest row flipped. |
| **Design change** | The canon is edited first if a rule, name, number or scope tag changes. Then the owning chapter. Then the content tables (`tools/gen/content` reads the documents' tables, 09 §3.2), regenerated and committed in the same change. If a balance number changed, `tests/sim/economy.sim.luau` is re-run. |
| **Release** | The steps of 09 §17.2 and the runbook of 12 §2.7. No row needed by the build is still a placeholder (07 §16). |

**Keeping the bible true.** The rule of the README holds: change the canon first, then the chapter that owns the detail. Every change is one commit that touches the document and the generated data together, with the task ID in the message. The Friday upkeep hour catches anything that drifted. Chapter 14 holds the open questions; an answered question is removed from chapter 14 and written into the chapter that owns it. Results of spikes and device tests replace the "not verified" marks in the chapter that made the claim.

## 2. How work is run with AI agents

### 2.1 Roles

| Who | Does |
|---|---|
| **Owner** | Confirms the sprint's tasks. Starts agents. Opens Studio and connects Rojo once per session (09 §2.4). Checks feel, frame rate and looks on real devices. Signs off art. Imports meshes where the importer needs a click. Places landmarks and judges zone composition. Listens to all audio. Publishes to Roblox. Reads the numbers. Makes every decision in chapter 14. |
| **Builder agents** (Opus, high effort) | Write Luau modules, specs, simulations and tools. Write and run Blender `build.py` scripts. Write Studio scripts that assemble zones from layout tables. Generate placeholder assets. Each returns a summary under 300 words with file paths and open issues. |
| **Reviewer agents** (Sonnet, high effort, read-only) | Review a diff against chapter 09, section 5 before merge. Review a contact sheet against 06 §16.1. Return a verdict and a short list of findings. They do not explore the codebase. |
| **Fetch-and-check agents** (Haiku) | Run the headless gate, triage build output, re-fetch Roblox documentation pages for the unverified-facts table in chapter 14. They report; they do not decide. |

### 2.2 Rules for agent tasks

1. **One task, one deliverable, about 40 turns.** A task is one row of a sprint table. Anything larger is split before it starts.
2. **The bible is the brief.** A task issue names the module or asset, the bible section, the acceptance checks and the files it may touch. It does not restate the design.
3. **Parallel streams work on disjoint files.** Each sprint's code table is arranged so that tasks with no dependency between them touch different files. Typical streams: `src/shared/Sim`, `src/shared/Logic`, `src/server/Services`, `src/client/Controllers`, `src/client/UI`, `tools/`, `assets/blender/<category>`.
4. **Headless first.** An agent finishes with `lune run tools/check` green before it asks for Studio. Up to 20 headless agents may run at once.
5. **One agent holds Studio.** The lock is `mkdir .locks/studio`, held only for sync, play, capture and stop (09 §2.5, rule 4).
6. **Two heavy jobs at most.** A Studio play test and a Blender bake are heavy jobs. With Studio open, one Blender job runs at a time. Two Blender jobs run together only with Studio closed, usually overnight. Multi-client tests run with Blender closed (09 §2.5).
7. **Disk is the source of truth.** Agents never edit scripts inside Studio (09 §2.4).
8. **Hand-offs are short.** The next agent gets the summary and the file paths, never a transcript.
9. **A sign-off review per feature, not per task.** Routine checks read only the diff. One Sonnet review happens when a module row of 09 §19 is complete.

### 2.3 What the owner does by hand, every sprint

- Studio session start, Rojo connect, and any importer step that needs a click.
- The Friday playtest on device rows 1 and 7; device rows 2 to 6 on the schedule in the test tasks.
- The weekly multi-client routine (09 §16.5) from Sprint 9 and the weekly profiling routine (09 §15.5) from Sprint 8.
- Art direction sign-off on every contact sheet, and the in-game look on a phone.
- All audio listening.
- Every publish to GULP Staging and GULP, every dashboard setting, every purchase test.

### 2.4 How art review works

1. A builder agent edits `build.py` or the `.blend`, runs `validate, bake, export, preview` headless, and returns the validation report and the contact sheet path. It does not look at the image.
2. A fresh reviewer agent receives one contact sheet (1536 × 1536, read at 768) and the checklist of 06 §16.1. It returns pass or fail with line numbers. Several assets are combined into one sheet where possible.
3. On a fail the builder gets the findings and the fix table of 06 §16.2. At most three loops. After three fails the asset goes to the owner with both sheets.
4. On a pass the owner looks at the sheet (about 5 minutes for a kit piece, 15 to 30 for a creature) and accepts or sends one note back.
5. The asset is imported, checked in the game on device row 1 under its zone's lighting, and the manifest row is flipped.
6. Screenshots from Studio are saved to disk and downscaled before any agent reads them (09 §2.5, rule 5).

Animation is reviewed as a pose strip and a 2-second clip (06 §15.5). Zones are reviewed with the zone sheet and then by swimming through them on a phone.

## 3. The soft-launch slice

### 3.1 What the slice has to prove

The canon's go/no-go is day-1 retention and session time at or above the median for similar games, read once the game has 100 daily users and under-16s can play (01 §17, 12 §1.5). The measures behind it are the first-session funnel of 01 §17. A build can test these honestly if a new player can: eat within five seconds, grow, gain a trait from prey, be hunted, bank, see a specimen earn, be gulped, come back for an unlock and a tide event, and be offered a fair purchase. Breadth beyond that does not change the read enough to justify its cost before the decision.

### 3.2 Exactly what is in the slice

| Area | In the slice at `S` | Canon [MVP] items left out |
|---|---|---|
| Zones | Nursery Lagoon, Sunlit Reef, Kelp Forest (reduced), 24 coves, the Rim. East and south of the Reef and Kelp end in `M_Env_Blue_Haze` with a current that turns creatures back. | The Drop-off |
| Landmarks | Little Arch (Nursery); Noggin Rock, The Hoop (Reef); Old Anchor, Peekaboo Ridge (Kelp) | 13 others (list in 3.3) |
| Kit pieces | About a third fewer variants of floor, rock, coral and kelp pieces (07 §17.1) | The remaining variants |
| Playable species | Minnow, Pufferfish | Eel (returns during soft launch, section 3.4) |
| Prey | Plankton, Krill, Tiny Shrimp, Sardine, Reef Darter, Mackerel (tiers 0 to 4) | Bonito, Tuna |
| Trait prey and traits | Glow (Glowfry), Stripes (Zebra Darter), Spots (Dotted Goby), Plated (Armor Shrimp), Spiny (Urchin Puff). Five traits, three slots. | Longfin, Ink, Crystal, Moonlit and their prey |
| Predators and hazards | Barracuda (Reef edge and Kelp), jelly bloom, currents | Gull, Moray, Old Scar, hook, cold vents |
| Tide events | Feeding Frenzy on all four quarter-hour slots, through `TideDef.fallback` (09 §11.1) | Moon Tide |
| Run loop | Seven tiers in data; tiers 1 to 5 reachable in normal play, tier 6 with effort. Dash, bite, player-versus-player rules and protections, banking, scraps, respawn, mid-run disconnect. | Nothing |
| First two minutes | All of chapter 04: load, hatch, trail, tier 2, Glow, scripted Barracuda chase, Home Current, first bank, both cliffhangers, starter goals, minutes 2 to 15 | The Gull in unlock row 5; the Codex button in row 9; the Eel silhouette in row 15 until the Eel ships |
| Cove | Specimens, income, the 8-hour cap, offline claim, cove slots with Pearls, cove-full choice | Codex stone, perch net, trophy rock |
| Meta | Daily goals (starter set on day one, then three a day), the "biggest on this server" strip. Codex discoveries are recorded in the save from day one. | Codex screens |
| Purchases | Revive, Deep Pockets, Bigger Cove, four Pearl packs | Nothing |
| Screens | 24 of the 28 [MVP] screens: S01 to S04, S07 to S16, S18, S19, S22, S25, S27, S28, S31, S33, S35, S36 | S05 tide popover, S17 specimen detail, S23 and S24 Codex |
| Platforms | Phone, tablet, PC and Mac with keys (15 §9, soft-launch stage) | Nothing |
| Analytics | Funnels 1 to 7 of 10 §3, the first-session and return funnels, economy events, the guard rules of 10 §9.2 | Events for content that is not in the slice |
| Audio | About 90 of the 132 [MVP] sound rows. All music from the Roblox Creator Store or a licensed pack: Nursery, Reef, Kelp, Cove, Chase, Current, Frenzy, Warning and two stingers. | Composed music; sounds for content that is not in the slice |
| Store page | Icon A, thumbnails T1, T2, T3 and T5, description, no video at `S`. Store art shows only what is in the build: in these soft-launch versions the threat in icon A and in T3 is the Barracuda (as it already is in T1), and T5 shows Minnow and Pufferfish specimens only. | Icon D, T4 (its soft-launch version, five sizes), T6, the page-cut video (all return during soft launch); the public-launch versions of icon A and T3 (with Old Scar), of T4 (seven sizes, with the Leviathan and its crest) and of T5 (with the Eel), which are [L] rows in chapter 07 and are made in Sprint 61, after Old Scar ships in Sprint 40 |

### 3.3 The deferral list, with hours

Hours are first-pass WH from chapter 07, section 14.2, split row by row for this plan. Each cell is rounded to a whole hour, so columns add up to within three hours of the totals.

| Category (07 section) | [MVP] WH | In the slice | Deferred | What is deferred |
|---|---|---|---|---|
| Species (2) | 114 | 70 | 44 | The Eel, `M_Species_Base_Eel`, `RIG_Eel`, the 13 `A_Eel_*` clips, Eel ability clips (43); the three Leviathan crests (2) |
| Traits (3) | 38 | 20 | 18 | Eel overlays and placement (8); Longfin pieces, Ink, Crystal and Moonlit overlays, Crystal shards (10) |
| Prey (4) | 44 | 28 | 16 | Bonito, Tuna (4); Ribbonfish, Inklet, Crystal Jelly, Lunar Fry (6); `RIG_PreyRibbon4`, `RIG_PreyBlob4`, `T_TraitPrey_02_Alb`, `_03_Alb`, their shells (6) |
| Predators and hazards (5) | 75 | 19 | 56 | Old Scar (22), Moray (16), Gull (9), cold vents (5), hook set (4) |
| Environment (6) | 337 | 173 | 164 | The Drop-off (90); 13 landmarks (42); a third of the kit variants and the matching assembly time (25); eel holes (4); Codex stone, perch net, trophy rock (4) |
| Water and sky (7) | 26 | 23 | 3 | `SKY_MoonTide`, `T_Sky_Moon_Alb` |
| Tide events (8) | 10 | 0 | 10 | Moon Tide glow masks, night tints and the Moon Tide switch test |
| Visual effects (9) | 62 | 46 | 16 | Effects for deferred traits, predators and Moon Tide |
| Lighting (10) | 22 | 15 | 7 | `LGT_DropOff`, `LGT_Event_MoonTide`, part of the low-end variants |
| Sound effects (11) | 66 | 45 | 21 | Eel voice; sounds for deferred traits, predators, events and screens |
| Music (12) | 79 | 15 | 64 | All composing. The 15 hours are for choosing, licensing, trimming and looping ten tracks. |
| Store-page source art (13) | 54 | 37 | 17 | `SCN_Icon_D_Puffed`, `SCN_Thumb_T4_FiveSizes`, `SCN_Thumb_T6_MoonTide`, `SCN_Thumb_T7_PickYourCreature_3`, `SCN_Brand_Banner`, part of the pose set (the Eel poses) and the capture set-ups |
| Placeholders (16) | 26 | 18 | 8 | Stand-ins for rows no slice code loads |
| Pipeline (14.1) | 65 | 59 | 6 | The part of the soft-launch import pass that belongs to deferred rows |
| **Total** | **1,016** | **566** | **450** | |

The same deferrals as choices, largest first:

| # | Choice | WH saved before `S` | Effect on the test | Returns |
|---|---|---|---|---|
| 1 | No Drop-off (zone, landmarks, lighting, ambience) | 90 + 3 + about 6 of sound and effects | No prey above tier 4. Tier 6 is slow and tier 7 is out of reach. Day-7 retention will read lower than the full game; day-1 and session time are little affected. | Sprints 35 to 39 |
| 2 | Licensed music instead of composed | 64 | None measurable. The shared-tune design of 07 §12 waits. | Cut candidate, Sprints 59 and 60 |
| 3 | The Eel and its family | 55 | The day-2 unlock (01 §7) is missing at `S`. It must exist before under-16s arrive. | Soft launch, Sprints 24 to 26 |
| 4 | 13 landmarks: Bubble Fountain, Coral Ring, Sleepy Clam; Honeycomb Caves, Crackles, Stripe Alley, Snooze, Gull Rock; Ribbon Roof, Lookout Stack, Root Ball, Glow Stalk, Hush Hollow | 42 | Zones are harder to navigate by sight; some trait prey sites are plain kit pieces | Sprints 43 and 44 |
| 5 | A third fewer kit variants | 25 | More visible repetition in Reef and Kelp | Cut candidate, Sprint 57 |
| 6 | Old Scar | 22 | No computer predator threatens tiers 4 to 6. Bank rate for big creatures will be high. Watched in the weekly review (section 5, Sprint 27). | Sprint 40, or earlier if the watch triggers |
| 7 | Moray, Gull, hook, cold vents | 34 | Less variety of danger. The Barracuda and jelly blooms carry it. | Gull in Sprint 29; the rest in Sprints 36 and 41 |
| 8 | Moon Tide and Moonlit | 10 + 3 + 3 + about 8 | One event type at `S`. The tide-pull measure (10 §7) is still testable. | Soft launch, Sprints 27 and 28 |
| 9 | Longfin, Ink, Crystal; Bonito, Tuna | 20 | Five traits instead of nine | Sprints 36 and 42 |
| 10 | Other sounds and effects for deferred content | 24 | None | With their content |
| 11 | Store art: icon D, T4, T6, T7 (three species), banner | 17 | No icon test until 100 daily users, which is when chapter 11 starts it anyway | Soft launch, Sprint 31 |
| 12 | Codex screens and stone, small cove pieces, crests | 6 + interface work | Discoveries are recorded but not shown | Codex in Sprint 30; the rest in Sprint 44 |
| 13 | Pipeline and placeholders for deferred rows | 14 | None | With their content |
| | **Total** | **about 450** | | |

### 3.4 The soft-launch top-up queue

Soft launch runs for about 11.5 weeks and the owner keeps working. Funnel fixes come first (10 §11, priority order). Spare hours go to this fixed queue and nowhere else. Nothing from the big deferrals (Drop-off, Old Scar, composed music, landmarks) starts before a "go", with one exception: task S32-C1 in Sprint 32, which is code only, done by agents behind flags, and costs at most 3 OH of owner time. No art for those deferrals starts before a "go".

| Order | Item | WH | Why it is in the queue | Ships |
|---|---|---|---|---|
| 1 | Eel, `RIG_Eel`, clips, Eel overlays for the five slice traits, eel holes, Slip | 55 art + 8 code | The day-2 goal; row 15 of 04 §7.3. Must be live before the read window. | Thu 22 Apr 2027 |
| 2 | Moon Tide, Lunar Fry, Moonlit, night sky, `LGT_Event_MoonTide`. Rotation becomes the canon's MVP rotation (:00 Feeding Frenzy, :15 Moon Tide, :30 Feeding Frenzy, :45 a second Moon Tide until Whale Fall ships). | 24 art + 8 code | The second event and the Mythic trait; the main test of pillar 5 | Thu 6 May 2027 |
| 3 | Gull | 11 art + 4 code | A second threat in the Reef for tiers 1 and 2 | Thu 13 May 2027 |
| 4 | Codex screens S23 and S24, `M_Cove_CodexStone` | 2 art + 6 interface art + 8 code | A reason to try every prey and trait | Thu 20 May 2027 |
| 5 | Icon D, thumbnails T4 and T6, the page-cut video | 10 art + 6 OH of editing | Icon and thumbnail tests of 11 §7 | Thu 27 May 2027 |

### 3.5 The quality bar the slice ships at

The owner wants top-quality visuals. The slice cuts breadth and keeps finish.

**Finished, no exceptions:** the Minnow, the Pufferfish, the Barracuda and every prey in the slice; the water surface, sky, caustics and light shafts; the Nursery; the cove; every effect, sound and interface element a player meets in the first two minutes; the HUD. Each passes every applicable line of 06 §16.1 and the owner's sign-off. The release check of 07 §16 fails the build if any row the slice loads is still a placeholder.

**Finished but thinner than the full game:**

- The Reef and the Kelp Forest are built from finished kit pieces with fewer variants, so repetition is visible to a careful eye. Kelp has two landmarks.
- The map ends in haze where the Drop-off will be.
- Music is licensed or from the Creator Store. It will be well chosen but it will not share one tune.
- The sound set is complete for what is in the build and nothing more.
- The store page has one icon and four thumbnails and no video on day one.

**Not acceptable in the slice:** a default Roblox part, material, interface element, sound or avatar anywhere (01 §3); a placeholder; a creature that fails the 48-pixel silhouette test; a frame rate under 30 on device row 1 from load to first bank (04 §12, A3).

## 4. Milestone map

### 4.1 Milestones, base case

| # | Milestone | Sprint | Date | Proves |
|---|---|---|---|---|
| M0 | Spike decision: go, change or stop | 0 | Fri 23 Oct 2026 | The character with no Humanoid and the Blender-to-Roblox pipeline work |
| M1 | First swim on a phone | 2 | Fri 6 Nov 2026 | Pillar 6; movement feel |
| M2 | First playable | 4 | Fri 20 Nov 2026 | Pillar 1; the prey pipeline; one finished fish |
| M3 | First-two-minutes build, grey-box, played by 5 new players | 7 | Fri 11 Dec 2026 | Chapter 04's script and timings, before the wider world is built |
| M4 | First-two-minutes build, finished art, played by 8 new players | 13 | Fri 22 Jan 2027 | The first two minutes at ship quality; 04 §12 checklist |
| M5 | Slice feature-complete | 18 | Fri 26 Feb 2027 | Everything in section 3.2 exists and plays on a phone |
| M6 | Private test (release stage 1) | 19 and 20 | Mon 1 Mar to Sun 14 Mar 2027 | The loop works on a phone and saves are safe (12 §1.1) |
| M7 | Friends-and-family test (stage 2) | 21 and 22 | Mon 15 Mar to Sun 28 Mar 2027 | 30 or more first-time players get through the first session |
| M8 | Soft launch, phase 3a (age-checked 16 and over) | 23 | Thu 1 Apr 2027, 15:00 UTC | The live game; Roblox's evaluation begins |
| M9 | Soft launch, phase 3b (all ages) | 26 | Thu 22 Apr 2027 (estimate; Roblox decides the day) | The core audience can play |
| M10 | Go/no-go | 35 | Mon 21 Jun 2027 | Day-1 retention and session time against the median |
| M11 | Full [MVP] live | 42 | Thu 12 Aug 2027 | Every deferred [MVP] item is back |
| M12 | Public launch (`P`) | 65, or 59 with the cut candidates removed | Thu 20 Jan 2028, or Thu 9 Dec 2027 | [MVP] plus [L] |
| M13 | Console switch on | 68 | Thu 10 Feb 2028 (`P` + 3 weeks) | Device rows 11 and 12 pass on real hardware |

### 4.2 Every sprint in one table

| Sprint | Dates | Theme | Demo at the end |
|---|---|---|---|
| 0 | 19–25 Oct 2026 | Technical and art spikes | A written go, change or stop decision |
| 1 | 26 Oct–1 Nov | Repository, toolchain, art pipeline, placeholders | The headless gate is green; a place built entirely from named placeholders |
| 2 | 2–8 Nov | First swim | The finished Minnow juvenile swims on a phone (M1) |
| 3 | 9–15 Nov | Prey pipeline | 250 prey groups simulated; krill swarms scatter on a phone |
| 4 | 16–22 Nov | First bite and growth | First playable (M2) |
| 5 | 23–29 Nov | Saves, banking, cove in grey-box | Bank a creature; it is there after a rejoin |
| 6 | 30 Nov–6 Dec | First two minutes, part 1 | Load to GLOW on a fresh account |
| 7 | 7–13 Dec | First two minutes, part 2 | Load to first bank, played by 5 new players (M3) |
| 8 | 14–20 Dec | Fixes from the test; water and sky; movement validation | The Nursery under finished water at 30 fps on a low phone |
| 9 | 21–27 Dec | Cove and Barracuda at final quality | The finished cove and the finished Barracuda in the chase |
| 10 | 28 Dec–3 Jan 2027 | First-two-minutes effects and interface art | Every effect and HUD element of the first two minutes is final |
| 11 | 4–10 Jan | First-two-minutes sound; Minnow adult; the first session after the bank | Run 2 with goals, and the Pufferfish silhouette filling |
| 12 | 11–17 Jan | Danger: predators, player bites, being gulped; first Reef pieces | Two players: one eats the other; the gulped panel |
| 13 | 18–24 Jan | First-two-minutes build at finished quality | Played by 8 new players (M4) |
| 14 | 25–31 Jan | Pufferfish; Revive and the receipt handler | Unlock the Pufferfish, puff, buy a Revive in the test game |
| 15 | 1–7 Feb | Traits and trait prey; remaining prey | Stripes, Spots, Plated and Spiny on both species |
| 16 | 8–14 Feb | The Reef; tide events; shop | A Feeding Frenzy on the quarter hour; a pass bought in the test game |
| 17 | 15–21 Feb | Kelp Forest kit; cove screens; goals | Specimen grid, slot upgrade and daily goals working |
| 18 | 22–28 Feb | Kelp assembled; settings, reconnect, analytics, performance | Slice feature-complete (M5) |
| 19 | 1–7 Mar | Private test week 1; remaining effects | 10 clean sessions by invited testers |
| 20 | 8–14 Mar | Private test week 2; remaining sound; thumbnails | Private test exit criteria met |
| 21 | 15–21 Mar | Friends-and-family week 1 | First funnel from 30 first-time players |
| 22 | 22–28 Mar | Friends-and-family week 2; launch checklist; freeze | Frozen build in GULP Staging; store page approved |
| 23 | 29 Mar–4 Apr | Soft-launch week | The game is public (M8) |
| 24 | 5–11 Apr | Funnel fixes; Eel 1 | Update 1 |
| 25 | 12–18 Apr | Funnel fixes; Eel 2 | Update 2 |
| 26 | 19–25 Apr | Eel ships; evaluation expected to pass | Update 3: the Eel (M9) |
| 27 | 26 Apr–2 May | Moon Tide 1; first A/B test | Update 4 |
| 28 | 3–9 May | Moon Tide ships | Update 5: Moon Tide and Moonlit |
| 29 | 10–16 May | Gull; reach 100 daily users | Update 6: the Gull |
| 30 | 17–23 May | Codex screens | Update 7: the Codex |
| 31 | 24–30 May | Icon and thumbnail tests; page video | Update 8; video live |
| 32 | 31 May–6 Jun | Hold 100 daily users; second A/B test | Update 9 |
| 33 | 7–13 Jun | Read window, week 1 | Update 10, fixes only |
| 34 | 14–20 Jun | Read window, week 2; go/no-go pack | The numbers pack for Monday |
| 35 | 21–27 Jun | Go/no-go; Drop-off kit 1 | The decision (M10) |
| 36 | 28 Jun–4 Jul | Drop-off kit 2; Bonito, Tuna, cold vents | Drop-off block-out with finished cliffs |
| 37 | 5–11 Jul | Drop-off landmarks | Ink Pots, Overbite, Slipstone Slope, The Crack |
| 38 | 12–18 Jul | The Tin Pickle | The wreck on its shelf |
| 39 | 19–25 Jul | Drop-off assembly | Update: the Drop-off opens |
| 40 | 26 Jul–1 Aug | Old Scar | Update: Old Scar |
| 41 | 2–8 Aug | Moray, hook | Update: Moray and hooks |
| 42 | 9–15 Aug | Longfin, Ink, Crystal | Update: full [MVP] live (M11) |
| 43 | 16–22 Aug | Deferred Reef and Nursery landmarks; gamepad scheme | Update: landmarks |
| 44 | 23–29 Aug | Deferred Kelp landmarks; focus navigation | Update: landmarks |
| 45 | 30 Aug–5 Sep | Sea Turtle 1 | Turtle meshes on `RIG_Turtle` |
| 46 | 6–12 Sep | Sea Turtle 2 | The Sea Turtle playable behind a flag |
| 47 | 13–19 Sep | Shark Pup | The Shark Pup playable behind a flag |
| 48 | 20–26 Sep | Spark, Camo, Ember, Bonefed | Four launch traits on Fish and Eel |
| 49 | 27 Sep–3 Oct | Turtle overlays; patterns; wild creatures 1 | The launch combination sheet passes |
| 50 | 4–10 Oct | Grouper, anemone, lit vents; wild creatures 2 | The Grouper's pull in the Drop-off |
| 51 | 11–17 Oct | Whale Fall | A Whale Fall at :45 behind a flag |
| 52 | 18–24 Oct | Cove visits, Bubbles, decorations | Visit a cove, leave a Bubble, place a decoration |
| 53 | 25–31 Oct | Launch effects and sound; streak, Reef Rank, global boards | Login calendar and Ranks screens |
| 54 | 1–7 Nov | Remaining passes and products; launch import | Every launch purchase tested in the test game |
| 55 | 8–14 Nov | Cut candidate: Squid 1 | Squid meshes on `RIG_Squid` |
| 56 | 15–21 Nov | Cut candidate: Squid 2 | The Squid playable behind a flag |
| 57 | 22–28 Nov | Cut candidate: Squid overlays; six more patterns; kit variants | The Squid wears every trait |
| 58 | 29 Nov–5 Dec | Cut candidate: seven more patterns; 26 more decorations | 18 patterns and 46 decorations |
| 59 | 6–12 Dec | Cut candidate: original music 1; chat panel | `MUS_Theme` and `MUS_Nursery` |
| 60 | 13–19 Dec | Cut candidate: original music 2 | `MUS_Cove`, `MUS_Reef` and the stingers |
| 61 | 20–26 Dec | Launch preparation, `P−4` | Launch build feature-frozen |
| 62 | 27 Dec–2 Jan 2028 | Launch preparation, `P−3`: private test of the launch build | One week of [L] content in the test game |
| 63 | 3–9 Jan | Launch preparation, `P−2` | Device rows 8 to 10 pass |
| 64 | 10–16 Jan | Launch preparation, `P−1` | Release candidate ready (the freeze is Tue 18 Jan, in Sprint 65); Launch Week event submitted |
| 65 | 17–23 Jan | Public launch | `P`: Thu 20 Jan 2028 (M12) |
| 66 | 24–30 Jan | Week 1 after launch: hotfixes | Fix update |
| 67 | 31 Jan–6 Feb | Week 2: Anglerfish; console checks | Update A |
| 68 | 7–13 Feb | Week 3: Storm tide; console switch | Update B (M13) |
| 69 | 14–20 Feb | Week 4: Manta Ray; the `P` + 4 numbers | Update A; the numbers for gate G8, which is read on Mon 21 Feb 2028, the Monday after this sprint |

If the owner removes the cut candidates (chapter 14, decisions D4 to D7), Sprints 55 to 60 disappear and Sprints 61 to 69 move six weeks earlier.

## 5. Sprints 0 to 34: from the spike to the go/no-go

Each sprint lists hours as **rhythm + code + art and audio + other = total OH**, against a capacity of 30. Ten sprints are planned at 31 OH (Sprints 2, 8, 11, 12, 15, 18, 19, 21, 46 and 49) and three at 32 OH (Sprints 52, 53 and 54). That is inside the error of the estimates and is not extra owner time: the plan holds at 30 OH worked, and when a sprint reaches 30, the first item under "Cut first" moves to the next sprint (in Sprints 46 to 54, which have no such list, the interface images named in the art row move). Code OH is 0.30 × WH plus any device tuning named in the task. Art OH uses the shares in section 1.2. Art tables give the chapter 07 hours (WH) and the placeholder that code uses until the asset is final; every placeholder is the stand-in of 07 §16 with the final name.

### Sprint 0 · 19–25 October 2026 · Spikes and decision

**Goal.** Find out in one week whether the two riskiest assumptions hold: a character with no Humanoid, and finished art made in scripted Blender arriving correctly in Roblox.
**Demo (Friday 23 October).** `docs/spike-report.md`: one line per spike item with pass or fail and the measurement, then a go, change or stop decision signed by the owner.

All work is in one throwaway place and a `spike/` folder. Nothing from it is kept except the report and the measured numbers.

**Technical spike (09 §6.11)**

| ID | Task | Spike items | Size | Depends on | Who |
|---|---|---|---|---|---|
| S0-C1 | Install Rokit and Wally, pin the toolchain, make Rokit's shims win over Homebrew, enable the Studio MCP server, create the throwaway place | 09 §2.2 | M | — | Owner + agent |
| S0-C2 | Character with no Humanoid: `Player.Character` set to a plain `Model`, 10 joins in a row on Mac and phone; stub `PlayerModule`; scriptable camera; core GUI off and a list of what is still drawn | S1, S9, S10 | L | S0-C1 | Agent + owner (phone) |
| S0-C3 | Swim feel: drag-to-swim on `LinearVelocity` and `AlignOrientation` at all seven tier scales; `Model:ScaleTo` from 1.0 to 6.5 on an animated skinned rig | S2, S18 | L | S0-C2 | Agent + owner (device rows 1 and 3) |
| S0-C4 | Two clients at 100 and 200 ms: smoothing of the other player; server `CFrame` write on a client-owned root; anchor after `SetNetworkOwner(nil)` | S3, S4 | M | S0-C3 | Owner (two-client test is manual until S15 is answered) |
| S0-C5 | Streaming: persistent collision shell, `PauseOutsideLoadedArea`, `GameplayPaused` | S5 | M | S0-C2 | Agent + owner |
| S0-C6 | Prey bench: 250 groups and 1,300 members on the server (server step 2.0 ms or less per 100 ms tick; 6 kB/s or less per player), 24 bots, a 900-byte `buffer` through `UnreliableRemoteEvent`, 80 pooled prey moved with `BulkMoveTo` on the low phone | S6, S7 | L | S0-C1 | Agent + owner (device row 1) |
| S0-C7 | Skinned rigs: `AnimationController` and `Animator` on a client-made rig, two MeshParts on one skeleton, 24 rigs on screen | S8 | M | S0-A2 | Agent + owner (device row 1) |
| S0-C8 | One `src/shared` module in Roblox, Lune and luau-lsp; ProfileStore session start, autosave, end and refusal of a second session; clock agreement; one engine spec run through Open Cloud | S11, S13, S14, S17 | M | S0-C1 | Agent |
| S0-C9 | Server Authority, time-boxed to 6 hours | S12 | L | S0-C3 | Agent + owner |
| S0-C10 | Agent loop through MCP three times with no human click; whether MCP can start a two-client test; `DisplayBubble` on a plain Part | S15, S16 | S | S0-C1 | Agent |
| S0-C11 | Measure Studio, play-test and Blender memory with Activity Monitor (09 §2.5, U15) | — | S | — | Owner |

**Art spikes (06 §18.2)**

| ID | Spike | Chapter 07 rows used | WH | What it uses meanwhile |
|---|---|---|---|---|
| S0-A1 | Calibration: `M_Prop_ScaleCube` through export and import; FBX scale factor; vertex-colour space | (tool) Export and validate script, first version | 3 | — |
| S0-A2 | Rig: flipped-face shell as an outline on a skinned mesh; code writing `Bone.Transform` beside a playing clip; bone-spread stretch; a rigid piece on a socket bone; 32 bones accepted | (test) Rig test and trait test, half | 4 | A capsule fish on the real `RIG_Fish` bone names |
| S0-A3 | Surface: vertex colour under a `SurfaceAppearance`; flat roughness against plastic shine; emissive mask on a game mesh | Same row | 1 | Same capsule |
| S0-A4 | Trait: overlay option A, B or C of 06 §8.4 | (test) Rig test and trait test, half | 3 | A flat tint with the trait name |
| S0-A5 | Lighting: Atmosphere or legacy fog; `LightingStyle` Realistic against Soft with `PrioritizeLightingQuality`; whether the Nursery, Reef and upper Drop-off looks hold at the 220-stud Smooth cap; the real ranges for every value in 06 §10.2; cost of beams and of 16 swapped caustic frames | (test) Surface, caustics and fog on a phone, half | 2 | Flat water sheet |
| S0-A6 | Phone: the busy frame of 06 §14.2 on device row 1 (low phone) on Smooth and device row 3 (mid phone) on Balanced, the tiers of 15 §3.0 | — | 2 | Placeholder creatures |
| S0-A7 | Agent art trial: one builder agent takes the Minnow juvenile from black silhouette to a first textured mesh through `build.py`, the contact sheet and a reviewer agent. Time-boxed to 4 OH. Record WH and OH. | `M_Species_Base_Fish`, start | 3 | — |

**Other tasks**

| ID | Type | Task | Who |
|---|---|---|---|
| S0-D1 | Decision | Answer chapter 14 decisions D1 (hours), D2 (budget), D3 (the slice), D11 (who owns the game) and D12 (fee or Roblox Plus) | Owner |
| S0-M1 | Operations | Create the GitHub repository, labels and the first three milestones (section 10). If D11 chooses the community (chapter 14's recommendation), create the Roblox community GULP first (100 Robux, 11 F23): ownership is hard to change later (chapter 14, R46). It is not opened or promoted until `S−4` (task S19-M2). Then create the experiences GULP Dev, GULP CI and GULP Staging (09 §17.1) under the owner chosen in D11; the production experience GULP is created later under the same owner. | Owner |
| S0-M2 | Operations | Account checks A1 to A3 of 12 §2.1: ID age check, 2-step verification, verified email | Owner |
| S0-M3 | Operations | Have device row 1 (low Android phone, 4 GB) and device row 2 or 3 in hand. Buy a used phone if needed (12 §11, up to 120 US dollars). | Owner |
| S0-T1 | Test | Every spike item is run on the Mac; S1, S2, S6, S8 and the phone spike also on device row 1; S2 also on device row 3 | Owner |

**The decision and the fallbacks**

| Result | Decision | What changes |
|---|---|---|
| Spikes S1 to S11, S13 to S15, S17, S18 and all six art spikes pass | **Go** | Nothing. Sprint 1 starts as planned. |
| S1, S9 or S10 fails (core scripts break without a Humanoid) | **Change** | Keep a Humanoid in the model with its state machine and name display off, and still drive the root ourselves (09 §20, R1). Add 2 OH to Sprint 2. |
| S2 fails on frame rate only | **Change** | Apply the cut order of 09 §15.6 and measure again in Sprint 2. |
| S2 fails on feel (input to motion is not same-frame on a phone) and S12 passes | **Change** | Raise a canon change to section 14, which says the design does not depend on Server Authority, and plan movement on Server Authority. Add one sprint. |
| S3 fails | **Change** | Longer interpolation delay for other players; accept up to 4-stud pops in a dash. |
| S4 fails | **Change** | Correction becomes a reliable "snap" request that the client must apply, with a kick on refusal. |
| S5 fails | **Change** | Larger streaming radii, or streaming off (09 §20, R7). |
| S6 or S7 fails | **Change** | Halve the send rate, shrink the bands, cap live prey at 1,000 (09 §20, R4). |
| S8 fails (skinned rigs without a Humanoid) | **Change** | Rigid segmented creatures with code-driven sway and no skinning. Chapter 06, section 7 and the clip rows of chapter 07 are redone. Add one sprint. |
| S11 fails | **Change** | Pure-logic specs run in the engine only (R14). |
| S13 fails | **Change** | Write our own session lock on `UpdateAsync`. Add one sprint. |
| S15 fails | **Change** | Play tests are run by hand. Raise the code share from 0.30 to 0.40 and re-date. |
| S17 fails | **Change** | Engine specs run locally through MCP only. |
| S18 fails | **Change** | Scale bones, or swap meshes per tier. |
| S12 passes | Note | Record the result against canon section 14 (Server Authority is evaluated in the spike; the design does not depend on it). No schedule change. |
| S16 fails | Note | The chat plan for launch is a custom panel with no bubbles (decision D7). |
| Outline shell does not draw on a skinned mesh | **Change** | Outlines become a ring sprite behind each creature; all `_Shell` rows are dropped (07 §17.5, about −25 WH). |
| Decal overlays do not follow a skinned mesh | **Change** | Overlays move to a second shell per creature or are combined at run time (07 §17.5). |
| Emissive masks fail on a target device | **Change** | Glow uses small `Neon` caps and brighter paint. |
| Realistic lighting misses 30 fps on device row 1 | **Change** | Soft with `PrioritizeLightingQuality` on (15 §10, item 13). |
| Calibration fails | **Change** | Fix the scale factor in the export script; if FBX skinning is unreliable, export glTF. |
| The agent art trial cannot reach a reviewer pass in three loops | **Change** | Creatures are modelled by hand by the owner (creature share 100%, about +60 OH to soft launch), or a contract artist is budgeted (decision D2). |
| Two or more of S1, S2, S6 and S8 fail with no fallback that holds 30 fps on device row 1 | **Stop** | The no-Humanoid phone-first design does not work on this engine today. Stop condition 1 in chapter 14. |

**Acceptance criteria**

- [ ] `docs/spike-report.md` has a pass or fail and a number for each of spike S1 to S18 and each of the six art spikes.
- [ ] Every "U" row of 09 §21.2 that a spike settles is marked settled in chapter 14, section 2.
- [ ] The report states the measured memory of Studio, a play test and Blender on this Mac.
- [ ] The report states WH and OH for the agent art trial.
- [ ] The owner has written "go", "change" (with the rows above that apply) or "stop".
- [ ] Decisions D1, D2, D3, D11 and D12 are answered in chapter 14, and the three experiences exist under the owner D11 chose (the community, if chosen, was created first).

**Risks.** A phone is not in hand by Wednesday (then S2, S6 and S8 slip to Sprint 1 and the decision is provisional). Server Authority eats the week (hard stop at 6 hours). **Cut first:** S16, then S12.
**Hours.** 30 OH, all owner-led.

### Sprint 1 · 26 October–1 November 2026 · Repository, toolchain, art pipeline, placeholders

**Goal.** Make every later task startable by an agent: a repository with a green headless gate, and an art pipeline that turns a script into a named asset in the game.
**Demo.** `lune run tools/check` passes locally and in CI. The world place opens with every slice asset loaded by name from `manifest.csv`, all placeholders.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S1-C1 | Repository scaffold, `rokit.toml`, `default.project.json`, `ci.project.json`, `.luaurc`, `selene.toml`, `stylua.toml`, `.mcp.json`, `.gitattributes` for LFS | B01 | 09 §2, §3 | M | Sprint 0 go | Agent |
| S1-C2 | `tools/check.luau` and `.github/workflows/ci.yml` (lint, types, gen, unit, sim, build) | B01 | 09 §2.4, §16.6 | M | S1-C1 | Agent |
| S1-C3 | `TestKit` and `tools/test/runner.luau` | B02 | 09 §16.1 | M | S1-C1 | Agent |
| S1-C4 | `Types`, `Config/Version`, `Config/Defaults`, `Config/Flags`, `Util` (Signal, Ring, TokenBucket, Rng, Log, Assert) | B03 | 09 §3, §4 | M | S1-C1 | Agent |
| S1-C5 | `tools/gen/content.luau`, `Data/Generated` for the slice rows, `Data/Index` | B04 | 09 §3.2 | L | S1-C4, S1-D1 | Agent |
| S1-C6 | `Net/Remotes`, `Net/Server`, `Net/Client`, `RateLimiter` | B05 | 09 §5.3, §14.2 | M | S1-C4 | Agent |
| S1-C7 | Asset manifest loader: `manifest.csv` to asset IDs, placeholder flag per row, release check | `shared/Data`, `tools/` | 07 §16 | M | S1-C4 | Agent |
| S1-C8 | World place created with the settings of 09 §15.4 and `StarterGui.ScreenOrientation = LandscapeSensor`; `tools/studio/check_place.luau` | Place, `tools/studio` | 09 §15.4, 15 §1 | S | S1-C1 | Owner + agent |

| ID | Art and audio task | Chapter 07 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S1-A1 | Pipeline tools | (tool) Export and validate (rest), Shell and distance-version, UV layout and atlas, Clip tools, Placeholder generator, Upload and manifest routine, Review contact sheets, Audio batch | 31 | — |
| S1-A2 | Placeholders for every slice row | The 13 rows of 07 §16, limited to slice assets | 18 | They are the placeholders |
| S1-A3 | Fish family base | `M_Species_Base_Fish`, `RIG_Fish` | 6 | Capsule on the real skeleton |
| S1-A4 | Blender scene template, palette files, `_lib` shared Python | 06 §15.2, §15.3 (inside the tool hours) | — | — |

| ID | Type | Task | Who |
|---|---|---|---|
| S1-D1 | Data | Mark slice rows in the content tables of chapters 01, 03 and 05 so `tools/gen/content` can emit a slice build and a full build from the same documents | Owner + agent |
| S1-D2 | Design | Settle the naming style for effects and sounds (07 §17.3) and write it into canon §16 | Owner |
| S1-T1 | Test | Device row 1 joins the dev place with placeholders; record join-to-control time | Owner |

**Acceptance criteria**

- [ ] `lune run tools/check` exits 0; CI is green on `main`.
- [ ] `git diff --exit-code src/shared/Data/Generated` is clean after `lune run tools/gen/content`.
- [ ] One command builds a placeholder for a named row and one command exports, validates and previews `M_Species_Base_Fish`.
- [ ] The manifest lists every slice row with status placeholder or final, and the release check fails as expected.
- [ ] `check_place.luau` passes through MCP.
- [ ] The scale cube arrives in Studio at 4 studs, facing forward, with no manual fix.

**Risks.** Tool versions or config keys differ from chapter 09 (U16, U17). **Cut first:** S1-A2 for sound and music placeholders (slide to Sprint 2), then S1-C7's release check.
**Hours.** 4 + 9 + 15 + 2 = 30 OH.

### Sprint 2 · 2–8 November 2026 · First swim

**Goal.** The creature moves under a thumb on a phone and feels right.
**Demo (M1, Friday 6 November).** On device row 1, drag-to-swim steers the finished Minnow juvenile around a grey arena at 30 fps or better; on the Mac the keys scheme does the same.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S2-C1 | `SwimModel` (pure step function, tier speed and turn tables, dash) with specs | B08 | 09 §6.5, 02 §1 | L | S1-C5 | Agent |
| S2-C2 | `WorldIndex`, `CollisionGroups`, `VolumeReader`, `HeightField` on a test arena | B09 | 09 §9.1 | M | S1-C4 | Agent |
| S2-C3 | `PlayerLifecycle` and `CreatureService`: slot, build, assign, own, spawn | B10 | 09 §6.1–6.4 | L | S1-C6, S2-C2 | Agent + owner |
| S2-C4 | `InputController` (drag to swim, keys, one `SwimInput`) and `MovementController` | B11 | 09 §5.2, 02 §2, 15 §3.1, §3.3 | XL | S2-C1, S2-C3 | Agent + owner (feel on device row 1) |
| S2-C5 | `CameraController`: scriptable follow, zoom by tier, field-of-view rule | B12 | 02 §3, 15 §10 item 14 | L | S2-C3 | Agent + owner |
| S2-C6 | Screen class, landscape lock and the scale formula | `client/UI/Kit` | 15 §9, 08 §1.2 | M | S1-C4 | Agent |
| S2-C7 | `tools/studio/smoke.luau`, steps 1 to 3 | `tools/studio` | 09 §16.4 | S | S2-C3 | Agent |

| ID | Art and audio task | Chapter 07 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S2-A1 | Minnow juvenile | `M_Species_Minnow_Juv`, (fit) Minnow on `RIG_Fish`, `T_Minnow_Juv_Alb`, `T_Shared_Rgh*`, `M_Prop_EyeX`, `T_Shared_EyeRing_Emi` | 9.5 | Capsule Minnow |
| S2-A2 | Minnow shells and distance versions | `M_Species_Minnow_*_Shell`, `_LOD1`, `_LOD2` (juvenile half) | 1 | Script-made from the capsule |
| S2-A3 | First five family clips | `A_Fish_Swim`, `A_Fish_SwimFast`, `A_Fish_Idle`, `A_Fish_Dash`, `A_Fish_Bite` | 4.9 | Procedural moves of the right length |

| ID | Type | Task | Who |
|---|---|---|---|
| S2-D1 | Tuning | First pass of swim feel on device row 1: turn rates, coast, dash burst (01 §5.1, §5.3) | Owner |
| S2-T1 | Test | Device rows 1 and 7 for the demo; device row 3 if in hand; frame rate and input delay filmed at 240 fps | Owner |
| S2-T2 | Measure | Recompute the code and art OH-per-WH ratios from Sprints 0 to 2 and re-date section 4 (gate G1) | Owner |

**Acceptance criteria**

- [ ] Ten joins in a row on device row 1 give a creature owned by the player with no console errors.
- [ ] Input to motion is in the same frame; 30 fps or more on device row 1 at all seven tier scales.
- [ ] The Minnow juvenile passes 06 §16.1 with a reviewer agent and the owner, and is final in the manifest.
- [ ] The smoke test moves the creature more than 30 studs with suspicion 0.
- [ ] The measured ratios and the new dates are written into section 1.2 and section 4.

**Risks.** Feel tuning has no end; time-box S2-D1 to 3 OH and carry a list. **Cut first:** S2-C6 (use a fixed scale), then S2-A2.
**Hours.** 4 + 16 + 9 + 2 = 31 OH.

### Sprint 3 · 9–15 November 2026 · Prey pipeline

**Goal.** Prey exists as data on the server and as pooled meshes on each client, inside the byte and frame budgets.
**Demo.** 250 groups simulate on the server; krill swarms and plankton are visible on device row 1 and scatter when approached; `prey_soak.sim` passes in CI.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S3-C1 | `Quantize` and codecs `PreyState`, `PreyEvent`, `Bite`, `BiteResult`, `WorldInfo` with round-trip specs | B06 | 09 §8.7 | L | S1-C3 | Agent |
| S3-C2 | `PreySim`, `Formation`, `SpatialGrid` | B15 | 09 §8.1–8.4 | XL | S1-C5, S3-C1 | Agent |
| S3-C3 | `PreyService`: spawner, interest management, send | B16 | 09 §8.5, §8.6 | XL | S1-C6, S2-C2, S3-C2 | Agent |
| S3-C4 | `PreyRenderer` part 1: decode, dead reckoning, pools, `BulkMoveTo` | B17 | 09 §8.8 | L | S3-C1, S3-C2 | Agent + owner (device row 1) |
| S3-C5 | `tests/sim/prey_soak.sim.luau` | `tests/sim` | 09 §16.2 | M | S3-C2 | Agent |
| S3-C6 | `CreatureController` and `CreatureRig`, first part: rig per creature, smooth scale with mass, outline shells | B13 | 09 §6.7, §6.8, 06 §13.2 | L | S2-C3 | Agent + owner |

| ID | Art and audio task | Chapter 07 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S3-A1 | First prey | `M_Prey_Plankton`, `M_Prey_Krill`, `T_PreySmall_Alb`, `RIG_Prey3`, (data) Prey motion table, `M_Prey_*_Shell`, `M_Prey_*_LOD2` (first half) | 9 | Flat ellipsoids sized by tier |
| S3-A2 | Reef lighting | `LGT_Reef` | 3 | Neutral preset with the Reef fog colour |

| ID | Type | Task | Who |
|---|---|---|---|
| S3-D1 | Data | Prey spawn tables for a test arena from 03 §2 and 05 §2.1 | Agent |
| S3-T1 | Test | Device row 1: 80 pooled prey at 30 fps; bytes received per second read from the Developer Console | Owner |

**Acceptance criteria**

- [ ] Server prey step is 2.0 ms or less per 100 ms tick with 250 groups and 1,300 members (09 §15.2).
- [ ] `prey_soak.sim` passes: bytes per player under 9,000 peak and 4,500 average; no packet over 900 bytes.
- [ ] Device row 1 draws 80 prey meshes at 30 fps.
- [ ] Krill scatter when the creature comes close; no prey Instance exists on the server.
- [ ] The creature shows a green outline shell on edible prey groups.

**Risks.** The packet layout needs a second pass once real phones show loss. **Cut first:** S3-C6 outlines (slide to Sprint 4).
**Hours.** 4 + 15 + 6 + 2 = 27 OH.

### Sprint 4 · 16–22 November 2026 · First bite and growth

**Goal.** The bite loop works: steer, dash, bite, grow, tier up.
**Demo (M2, Friday 20 November).** First playable. On device row 1: hatch as the Minnow, eat plankton and krill, grow with every bite, reach tier 2 at 10 mass with a tier-up effect, dash. Played by the owner and two people who have not seen it.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S4-C1 | `PreyRenderer` part 2: far groups as particles, local bite detection | B17 | 09 §8.8, §8.9 | L | S3-C4 | Agent + owner |
| S4-C2 | `BiteService`, prey bites: the handshake, validation, results | B18 | 09 §8.9, 02 §4 | M | S3-C3 | Agent |
| S4-C3 | `shared/Logic`: `TierMath`, `BiteRules`, `BankMath`, `TraitRules`, `CoveIncome`, `TideClock`, `GoalRules`, with the full spec list of 09 §16.1 | B07 | 01 §5, 09 §16.1 | L | S1-C5 | Agent |
| S4-C4 | `RunLoopService`, first part: start, respawn, tier change events | B19 | 09 §6.3, 02 §5 | M | S4-C2 | Agent |
| S4-C5 | `UI/Kit` base and HUD stage 1: layers, safe frame, `HUD.DragRing`, `HUD.Dash`, `HUD.MassBar`, `HUD.MassPops`, `HUD.Outlines`, `HUD.Home`; screen S11 with Swim again only; screen S12 with the Pearls table only | B23 | 08 §15 stage 1, §3 | L | S2-C4 | Agent + owner |
| S4-C6 | `DataService` on `ProfileStore.Mock` and real stores, save schema version 1, `Migrations`, fixtures; `StateStore` | B20 | 09 §12.1–12.4 | L | S1-C6, S4-C3 | Agent |

| ID | Art and audio task | Chapter 07 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S4-A1 | First effects | `FX_BiteChomp`, `FX_BubblePop_T0`, `FX_BubblePop_T1T2`, their two textures | 2.5 | White dot bursts |
| S4-A2 | First sounds | Three eating sounds from 07 §11.2 | 1.5 | Script-made tones |
| S4-A3 | More family clips | `A_Fish_Gulp`, `A_Fish_Hit`, `A_Fish_Stunned`, `A_Fish_TierUp`, `A_Fish_Gulped` | 3.7 | Procedural moves |

| ID | Type | Task | Who |
|---|---|---|---|
| S4-D1 | Tuning | Bite radius, gulp assist and dash numbers from 02 §4 on device row 1 | Owner |
| S4-T1 | Test | First-playable playtest: device rows 1 and 7, owner plus two outside players; time to first bite and to tier 2 written down | Owner |
| S4-T2 | Test | 4 OH held for fixes found in the playtest | Owner + agent |

**Acceptance criteria**

- [ ] A bite on device row 1 is confirmed by the server and the mass bar moves within 100 ms.
- [ ] `bite_reject` is under 2% in a 10-minute session on home Wi-Fi.
- [ ] Body scale grows on every bite; tier 2 arrives at 10 mass with the tier-up clip and effect.
- [ ] The `BiteRules` spec covers the full tier and protection matrix of 01 §5.2.
- [ ] A fixture profile of schema version 1 loads and saves; a second session on the same key is refused.
- [ ] Both outside players bite within 10 seconds without being told how.

**Risks.** Honest bites rejected too often (09 §20, R5). **Cut first:** S4-C6 slides to Sprint 5; screen S12 stub.
**Hours.** 4 + 13 + 4 + 7 = 28 OH.

### Sprint 5 · 23–29 November 2026 · Saves, banking and the cove in grey-box

**Goal.** A run can end by banking, and what was banked is still there tomorrow.
**Demo.** Swim into the cove mouth: Pearls are added, a specimen appears, and after a rejoin the specimen and its accrued income are there.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S5-C1 | `EconomyService` and the `Analytics` wrapper (typed, no-op in Studio, event enum) | B21 | 09 §5.1, 10 §2.4 | M | S4-C6 | Agent |
| S5-C2 | `CoveService`: cove assignment, slots, specimens, income from timestamps, claim, `CoveView` | B22 | 09 §13, 02 §13 | L | S2-C2, S5-C1 | Agent |
| S5-C3 | `RunLoopService` bank and settle; `BankMath` wired; cove mouth volumes for 24 coves | B19 | 01 §5.4, 02 §11 | M | S4-C4, S5-C2 | Agent |
| S5-C4 | Screen S12 bank summary and screen S14 cove HUD, first version (Pearls, slots, Claim all) | `client/UI/Screens` | 08 §4.5, §5.1 | M | S4-C5 | Agent + owner |
| S5-C5 | `LiveConfig`, flags, `Loc`, `tools/gen/strings.luau`, `assets/loc/strings.csv` | B33 | 09 §17.4, §18.1 | M | S1-C6 | Agent |
| S5-C6 | `tests/sim/economy.sim.luau`, first version on the slice tables | `tests/sim` | 09 §16.2, 05 §5 | M | S4-C3 | Agent |

| ID | Art and audio task | Chapter 07 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S5-A1 | Ground textures and shared look | The four `T_Tile_*` textures, `T_EnvShared_Alb` | 8.5 | "PH" stamped flats |
| S5-A2 | The Rim and the edge of the map | `M_Env_Rim_Wall_01–03`, `M_Env_Rim_Pass`, `M_Env_Blue_Haze`, `T_Haze_Mask` | 9 | Grey wedges |
| S5-A3 | Cove structure | `M_Cove_Mouth`, `M_Cove_Interior`, `T_Cove_Alb` | 17 | Block-out mouth and chamber with the 40 perches marked |

| ID | Type | Task | Who |
|---|---|---|---|
| S5-D1 | Data | Banking, scraps, cove income, slot prices and species prices from 05 §3 and §4 into the content tables | Agent + owner |
| S5-T1 | Test | 100 test saves with no loss; kill the server mid-run and check settlement (09 §12.5) | Agent + owner |

**Acceptance criteria**

- [ ] Banking a tier 2 Minnow adds mass × 3 Pearls (the first step of canon 5.4: × 3 up to 1,200 mass, × 1 from 1,200 to 3,000, nothing above) and one specimen; a tier 1 bank adds Pearls only.
- [ ] After 10 minutes away the specimen's income matches `CoveIncome` to the Pearl; the pile stops at 8 hours in a spec.
- [ ] 100 saves, 0 losses; a second server cannot open the same profile.
- [ ] Pearls change only inside `EconomyService` (checked by the dependency rule in `tools/check`).
- [ ] `economy.sim` runs and prints time to each tier and days to the Pufferfish.

**Risks.** Data store behaviour in Studio differs from live (settled in Sprint 19 on GULP Staging). **Cut first:** S5-C6, then S5-A2.
**Hours.** 4 + 8 + 13 + 4 = 29 OH.

### Sprint 6 · 30 November–6 December 2026 · The first two minutes, part 1

**Goal.** Chapter 04's script runs from the loading screen to the first trait, with the real Minnow and placeholder scenery.
**Demo.** A fresh account: loading toy, hatch, first bite within 5 seconds, tier 2 by about 25 seconds, five Glowfry, GLOW.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S6-C1 | `first/Loading.client.luau`: screen S01, the loading toy, the minimum set, slow-load rule | `src/first` | 04 §2, 08 §8.1 | L | S4-C5 | Agent + owner |
| S6-C2 | `TutorialDirector` core: stages, saved step, per-player scripted prey (Swarm A, plankton trail, Swarm B, Glowfry), fail-safes, idle rule | B31 | 04 §3, §4 | XL | S4-C4, S4-C5 | Agent + owner |
| S6-C3 | `TraitService`: progress, three slots, Glow's effect; `HUD.Traits`, `HUD.TraitMarkers` | B19 | 01 §9, 02 §8, 08 §3.6, §3.10 | M | S4-C2 | Agent |
| S6-C4 | Guide kit, screen S33, all nine parts | `client/UI/Kit` | 08 §7 | M | S4-C5 | Agent |
| S6-C5 | Screens S07 tier-up and S08 trait gained | `client/UI/Hud` | 08 §4.2, §4.3 | M | S4-C5 | Agent |
| S6-C6 | Onboarding funnel steps and `ftue_milestone`, `ftue_failsafe`, `fs_time_mark`, `sys_load_time` | `Analytics`, B31 | 10 §3.1, §4.2 | M | S5-C1 | Agent |
| S6-C7 | `FtueConfig`: every tunable of chapter 04 in one table; `/ftue reset` dev command | `shared/Config`, `server/Dev` | 04 §12, A4 | S | S6-C2 | Agent |

| ID | Art and audio task | Chapter 07 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S6-A1 | The first trait | `M_Prey_Glowfry`, `T_TraitPrey_01_Alb`, `T_TraitPrey_Emi`, `T_Trait_Glow_Fish_Emi`, (tool) Trait overlay bake | 12.4 | Ellipsoid with a ring; flat tint overlay |
| S6-A2 | The hatch | `M_Prop_HatchEgg`, `A_Fish_Hatch` | 2.2 | Sphere; spin |
| S6-A3 | Nursery kit, first half | `M_Env_Nursery_Floor_01–04`, `M_Env_Nursery_Rim_01–02`, `T_EnvNursery_Alb` | 9.5 | Grey slabs with the Nursery tint |

| ID | Type | Task | Who |
|---|---|---|---|
| S6-D1 | Design | Lay out the Nursery path of 04 §3.5 as tagged volumes in the dev place: Hatch Bed, swarms, trail, Glow Grotto, the Gap, the channel | Owner + agent |
| S6-T1 | Test | Three fresh-account run-throughs on device row 1; checklist items L1 to L3 and S1 to S10 of 04 §12 | Owner |

**Acceptance criteria**

- [ ] Checklist items L1, L2, L3 and S1 to S10 of 04 §12 pass on device row 1 (art may be placeholder).
- [ ] A tester who never touches the screen gets a bite by T = 5 and the fail-safe is logged.
- [ ] The first trait is Glow on 10 fresh accounts out of 10.
- [ ] Onboarding steps log in order in the Studio event buffer.
- [ ] Changing a number in `FtueConfig` changes the script with no other edit.

**Risks.** Per-player scripted prey fights the shared prey pipeline. **Cut first:** S6-C1's loading toy (static screen for now), then S6-A3.
**Hours.** 4 + 12 + 10 + 4 = 30 OH.

### Sprint 7 · 7–13 December 2026 · The first two minutes, part 2

**Goal.** The script runs to the first bank, and people who have never seen the game get through it.
**Demo (M3, Friday 11 December).** Five new players each play a fresh account on device row 1 from load to first bank. Scenery is grey-box; the Minnow, prey and Glow are final.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S7-C1 | `PredatorSim`, `PredatorService`, `PredatorController` for one Barracuda; the scripted, per-player chase with its guarantee | B24 | 04 §5, 09 §9 | L | S3-C3 | Agent + owner |
| S7-C2 | Currents as volumes; the Home Current that carries a newcomer to their cove; cove choice nearest the Gap | `WorldIndex`, B31 | 04 §5.5, 02 §10 | M | S5-C2 | Agent |
| S7-C3 | The first bank sequence, the first income tick, the Pufferfish silhouette ring, the tide clock on the cove wall and on the HUD (`TideClock` logic only) | B31, B22 | 04 §6 | M | S5-C3, S6-C2 | Agent + owner |
| S7-C4 | First-run shield and newcomer bubble in `BiteRules` and `CreatureService` | B07, B10 | 01 §5.2, 04 §4 | S | S4-C3 | Agent |
| S7-C5 | `HUD.Threats`, `HUD.BankChip`, `HUD.SafeBadge`, `HUD.Status` | `client/UI/Hud` | 08 §3.5, §3.9, §3.15 | M | S4-C5 | Agent |
| S7-C6 | Kelp curtain gate at the Gap; returning and skipping rules | B31 | 04 §3.6, §9 | M | S6-C2 | Agent |

| ID | Art and audio task | Chapter 07 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S7-A1 | Nursery kit, second half | `M_Env_Nursery_Coral_01–03`, `M_Env_Nursery_GrassTuft_01–02`, `M_Env_Nursery_GlowBuoy`, `M_Env_Nursery_LM_LittleArch`, `M_Prop_Nursery_ShellSign` | 8.8 | Labelled blocks |
| S7-A2 | Nursery assembly | (assembly) Nursery Lagoon | 6 | Block-out |

| ID | Type | Task | Who |
|---|---|---|---|
| S7-T1 | Playtest | Five new players, at least two aged 9 to 15 with a parent present, on device row 1. Record the screen. Note time to bite, tier 2, Glow, bank, and every place someone stalls. | Owner |
| S7-T2 | Test | Checklist items C1 to C9, B1 to B9, R1 to R3 and A1, A2 of 04 §12 | Owner + agent |
| S7-D1 | Tuning | Retune `FtueConfig` from the five recordings | Owner |

**Acceptance criteria**

- [ ] In 20 attempts trying to be caught in the chase, the player is never gulped and never loses mass (C5).
- [ ] The Home Current carries a player who gives no input to within 30 studs of their cove (B1).
- [ ] One fresh playthrough logs onboarding steps 01 to 17 in order, each once (A1).
- [ ] At least 3 of the 5 new players bank within T = 120 without help.
- [ ] A second player on the server does not see the first player's Barracuda or scripted prey (C8).
- [ ] A list of every stall seen in the playtest exists as issues for Sprint 8.

**Risks.** Fewer than five testers turn up (run the rest in Sprint 8). **Cut first:** S7-C6 returning rules, then S7-A2.
**Hours.** 4 + 9 + 8 + 8 = 29 OH.

### Sprint 8 · 14–20 December 2026 · Fixes from the test; water and sky; movement validation

**Goal.** Fix what the five players stumbled on, make the water look finished, and start checking movement on the server.
**Demo.** The Nursery under the finished surface, sky, caustics and light shafts at 30 fps on device row 1. A scripted speed cheat is flagged within 5 seconds.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S8-C1 | Fixes from the Sprint 7 playtest | B31 | 04 | M | S7-T1 | Agent + owner |
| S8-C2 | `MovementValidator`: allowed speed, per-tick checks, response ladder, pose history, lag fairness | B14 | 09 §7 | XL | S2-C1, S2-C3 | Agent |
| S8-C3 | `tests/sim/movement_fuzz.sim.luau` | `tests/sim` | 09 §16.2 | M | S8-C2 | Agent |
| S8-C4 | Desktop: keys including arrow keys, cursor rules, key hints, hint swap on input change | `InputController`, `client/UI` | 08 §10.2, 15 §3.3, §5.1 | M | S2-C4 | Agent |
| S8-C5 | `Telemetry` remote; quality tiers Smooth and Balanced as constants; the 3-second start sample and one step down | `UIController` | 09 §15.1, 15 §6 | M | S4-C5 | Agent + owner |
| S8-C6 | Water surface, caustic and light-shaft drivers (frame swapping, shell projection, blending by depth) | `client/Render/Fx`, `TideController` stub | 06 §9.4, §10.4 | M | S0-A5 | Agent + owner |

| ID | Art and audio task | Chapter 07 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S8-A1 | Water surface | `M_Env_Surface_Under`, `M_Env_Surface_Top`, `T_Surface_Under_01–08_Alb`, `T_Surface_Top_Alb`, `M_Env_SunPool`, `T_SunPool_Mask`, (tool) Flipbook and frame-set render | 11.5 | Flat semi-clear sheet |
| S8-A2 | Sky | `SKY_Day`, `T_Sky_Sun_Alb`, `M_Env_HorizonIsland_01–03` | 6 | Two-colour skybox |
| S8-A3 | Caustics and shafts | `M_Env_CausticShell_*`, `T_Caustics_01–16_Mask`, `T_FX_GodRay_Mask` | 5.4 | None |
| S8-A4 | Phone test of the water look | (test) Surface, caustics and fog on a phone, second half | 2 | — |
| S8-A5 | Lighting | `LGT_Nursery`, `LGT_Surface` | 4 | Neutral preset |

| ID | Type | Task | Who |
|---|---|---|---|
| S8-T1 | Test | First run of the profiling routine of 09 §15.5 (phone run and leak check) on device row 1; first line in `docs/perf-log.md` | Owner |
| S8-T2 | Test | Device row 7: the keys scheme through the whole first two minutes | Owner |

**Acceptance criteria**

- [ ] Every stall issue from Sprint 7 is closed or has a written reason.
- [ ] `movement_fuzz.sim` passes: no honest trace reaches suspicion 10; a 1.3× speed trace is flagged within 5 seconds.
- [ ] The water, sky, caustics and shafts pass the owner's sign-off on device row 1 and hold 30 fps there.
- [ ] The first two minutes can be played with arrow keys alone.
- [ ] `perf-log.md` has memory, frame rate and network numbers for a 10-minute run.

**Risks.** Sixteen caustic frames cost too much memory on the low phone (fallback: fewer frames or two scrolling layers, 07 §17.5). **Cut first:** S8-C5 (fixed tier), then `M_Env_HorizonIsland_01–03`.
**Hours.** 4 + 9 + 15 + 3 = 31 OH.

### Sprint 9 · 21–27 December 2026 · The cove and the Barracuda at final quality

**Goal.** The two things a new player remembers from minute two, the hunter and the home, are finished.
**Demo.** The scripted chase with the finished Barracuda, ending in the finished cove with lantern, clam, perches and tide clock.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S9-C1 | `CreatureRig` second part: smoothing of other players, pooled nameplates, juvenile-to-adult mesh swap under `FX_Metamorph` | B13 | 09 §6.7, §6.9, §6.10 | L | S3-C6 | Agent + owner |
| S9-C2 | `AudioController`: music states, pooled one-shots, underwater filter, pitch by tier | B30 | 09 §5.2, 07 §12 | M | S3-C6 | Agent |
| S9-C3 | Specimens shown in the cove on perches (still or idling, 12 live at most), name shell, trophy bubble | `CoveService`, `CreatureController` | 02 §13, 08 §5.2 | M | S5-C2 | Agent + owner |

| ID | Art and audio task | Chapter 07 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S9-A1 | Cove fixtures | `M_Cove_NameShell`, `M_Cove_TrophyBubbleMount`, `M_Cove_DoorLantern`, `M_Cove_KelpCurtain`, `M_Cove_HomeStone`, `M_Cove_PearlClam`, `A_PearlClam_Open`, `M_Prop_Pearl_01–03`, `M_Cove_Perch`, `M_Cove_TideClock`, `M_Cove_SpeciesWall` | 13.8 | Labelled boxes |
| S9-A2 | Cove assembly and light | (assembly) Cove template and Rim, `LGT_Cove` | 8.5 | Block-out |
| S9-A3 | Barracuda | `M_Pred_Barracuda`, `RIG_Barracuda`, `T_Barracuda_Alb`, `M_Pred_Barracuda_LOD1, _LOD2, _Shell`, `A_Barracuda_Burst`, `A_Barracuda_Bite`, `A_Barracuda_GiveUp` | 13.4 | Red wedge |

| ID | Type | Task | Who |
|---|---|---|---|
| S9-T1 | Test | First weekly multi-client routine (09 §16.5, step 1): two local clients, with and without 150 ms simulated latency, Blender closed | Owner |
| S9-T2 | Test | Device row 2 (small iPhone) or the Device Simulator at 667 × 375: HUD stage 1 and 2 layout, nothing under the home bar | Owner |

**Acceptance criteria**

- [ ] The Barracuda passes 06 §16.1, including "friend or foe" from shape alone, and reads as danger at 20 pixels.
- [ ] The cove passes the owner's sign-off on device row 1 under `LGT_Cove`; 24 coves sit in the Rim from one template.
- [ ] A second player's creature shows no pop larger than 2 studs at 38 studs per second with 150 ms latency.
- [ ] Checklist items B4 to B9 of 04 §12 pass with final cove art.
- [ ] No default Roblox sound plays anywhere.

**Risks.** This is a holiday week (section 1.2). If it is taken off, every later date moves one week. **Cut first:** S9-C3's idle animation (still meshes), then `M_Cove_KelpCurtain`.
**Hours.** 4 + 5 + 19 + 2 = 30 OH.

### Sprint 10 · 28 December 2026–3 January 2027 · First-two-minutes effects and interface art

**Goal.** Everything a new player sees on screen in the first two minutes is final.
**Demo.** The first two minutes with every effect and every HUD element at final quality (scenery beyond the Nursery and cove is still grey).

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S10-C1 | `Render/Fx`: named effects pooled and played by ID; hooks for every effect in A1 | `client/Render/Fx` | 06 §11, 07 §9 | M | S3-C6 | Agent + owner |
| S10-C2 | `UiSprites` table generated from the atlas plan; nine-slice kit; button states and the 100 ms rule | `client/UI/Kit`, `tools/gen` | 08 §13.13, §11.2 | M | S4-C5 | Agent |
| S10-C3 | Sound and haptic hooks on HUD and moments; bite pitch streak | `client/UI`, `AudioController` | 08 §11.4, §11.5, 04 §12 S4 | M | S9-C2 | Agent |
| S10-C4 | Colour-blind outline colours and "less motion" switches wired (settings screen comes later) | `Outlines`, `client/UI/Kit` | 01 §5.2, 08 §12 | S | S3-C6 | Agent |

| ID | Art and audio task | Chapter 07 and 08 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S10-A1 | First-two-minutes effects | From 07 §9: `FX_TierUp_T2`, `FX_TierUp_T3`, dash, bubble trail, `FX_GulpPop`, hatch, bank, cove membrane and beacon, home trail, Pearl flight, currents, light shafts, the Glow gain; the effect textures they need | 22 | White dot bursts with final names |
| S10-A2 | Interface art for build stages 1 and 2 | 08 §13: `UI_Atlas_Glyphs1`, `UI_Atlas_Content1`, `UI_Atlas_Parts1`, the nine-sliced HUD pieces, `UI_Guide_*`, `UI_Load_*`, the `UI_HUD_*` and `UI_Moment_*` rows used by stages 1 and 2 (about 70 drawings) | 18 (estimate; chapter 08 gives none) | Flat-colour shapes with final names and sizes |

| ID | Type | Task | Who |
|---|---|---|---|
| S10-D1 | Data | Every word of 04 §3.3 and 08 §14.11 into `strings.csv`; check that only those words appear before T = 180 (S15) | Agent + owner |
| S10-T1 | Test | Checks of 08 §16.1 for the HUD on device rows 1, 2 and 7: hit areas 88 rpx, response within 100 ms filmed at 240 fps | Owner |

**Acceptance criteria**

- [ ] Every effect in S10-A1 is final in the manifest and holds the particle budget of 09 §15.1 on device row 1.
- [ ] Icons are rendered from the real models (06 §17).
- [ ] No HUD element sits under the notch, the home bar or the Roblox buttons on device rows 1 and 2.
- [ ] First response to every press is within 100 ms.
- [ ] Only the words of 04 §3.3 appear before T = 180.

**Risks.** A holiday week. Flipbooks are switched off on low-memory phones (06 §2.4), so no effect may depend on one. **Cut first:** cove beacon and home trail polish, then the `UI_Load_*` art.
**Hours.** 4 + 4 + 20 + 2 = 30 OH.

### Sprint 11 · 4–10 January 2027 · First-two-minutes sound; Minnow adult; the session after the bank

**Goal.** The first two minutes sound finished, and minutes 2 to 15 give the player goals and a creature to save for.
**Demo.** Run 2 on a fresh account: goals chip at 5 seconds, sardines turn green at tier 2, a first goal completes, the Pufferfish silhouette fills toward 500.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S11-C1 | `GoalsService` with the fixed starter set; goals chip; goal completion flight | B28 | 04 §7.2, 03 §9 | M | S4-C6 | Agent |
| S11-C2 | Minutes 2 to 15: the introduction queue (pings 20 s apart), run-2 assist step-down, 45-second predator grace, unlock rows 1 to 4, 8 and 10 of 04 §7.3 | B31 | 04 §7 | M | S7-C3 | Agent + owner |
| S11-C3 | Screens S22 species select, S19 confirm, S35 species unlocked; `ShopService.buyWithPearls` | B27, `client/UI/Screens` | 08 §6.1, 05 §4.1 | L | S5-C1, S10-C2 | Agent + owner |
| S11-C4 | Dart (the Minnow's passive ability shown as a badge) | B32 | 01 §7, 08 §3.8 | S | S2-C1 | Agent |

| ID | Art and audio task | Chapter 07 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S11-A1 | First-session sounds, about 45 rows | From 07 §11: the Minnow voice (11.1); eating, movement and growth (11.2); the Barracuda rows of 11.4; bank, Pearls and the interface sounds the first session calls (11.5); Nursery and cove ambience (11.6) | 20 | Script-made tones |
| S11-A2 | Minnow adult | `M_Species_Minnow_Adult`, `T_Minnow_Adult_Alb`, adult shells and distance versions, `A_Minnow_Dart`, `A_Minnow_Fidget`, `A_Fish_Bank`, `A_Fish_Breach` | 12.2 | Longer capsule |

| ID | Type | Task | Who |
|---|---|---|---|
| S11-D1 | Tuning | Pearl budget for the first session against 04 §7.4: the Pufferfish must be affordable in 9 to 13 minutes | Owner + agent (`economy.sim`) |
| S11-T1 | Test | Checklist items P1 to P3, P7 and P9 of 04 §12 on device row 1 | Owner |

**Acceptance criteria**

- [ ] Every sound of S11-A1 has a recorded source or licence and is heard in the game on phone speakers.
- [ ] The goals chip appears 5 seconds into run 2 with the three starter goals (P2).
- [ ] At 500 Pearls the silhouette lights up and a 0.6-second hold buys the Pufferfish (P7, with a placeholder Pufferfish).
- [ ] The Minnow changes form at tier 4 under `FX_Metamorph` with no visible pop.
- [ ] `economy.sim` puts the Pufferfish inside the first session for the "regular" player of 05 §5.1.

**Risks.** Sound sourcing takes longer than making meshes because every file must be listened to. **Cut first:** `A_Minnow_Fidget`, `A_Fish_Breach`, then cove ambience.
**Hours.** 4 + 5 + 20 + 2 = 31 OH.

### Sprint 12 · 11–17 January 2027 · Danger

**Goal.** A run can end badly: predators patrol, bigger players bite, and being gulped is quick and fair.
**Demo.** Two players on one server: same-tier bump, a tier 3 eats a tier 2, a bite in the Nursery fails, the gulped panel shows who did it and pays scraps, respawn in under 3 seconds.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S12-C1 | Barracuda patrol, chase and give-up in the open world; jelly bloom; attack validation; `PredatorState` and `PredatorEvent` codecs | B24 | 09 §9, 02 §9, §10 | L | S7-C1, S8-C2 | Agent + owner |
| S12-C2 | `BiteService` player bites: rules in order, lag compensation, tie-breaks, safe zones, first-run shield, newcomer bubble | B25 | 09 §10, 01 §5.2 | L | S4-C2, S8-C2 | Agent |
| S12-C3 | `RunLoopService.gulp`, scraps (10%, 50% for the first three deaths), respawn; screen S11 gulped panel; death camera | B19, `client/UI/Screens` | 01 §5.5, 08 §4.4 | M | S5-C3 | Agent + owner |
| S12-C4 | Mid-run disconnect by the canon rule: 10 s in the water, then suspended for 5 minutes | B19, B20 | 01 §5.5, 09 §12.5 | M | S5-C3 | Agent |

| ID | Art and audio task | Chapter 07 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S12-A1 | Music, first five | Licensed or Creator Store tracks standing in for `MUS_Nursery`, `MUS_Chase`, `MUS_Current`, `MUS_Sting_Victory`, `MUS_Sting_Gulped`: choose, record the licence, trim, loop, level | 7.5 | Mallet loop |
| S12-A2 | Shared small pieces | `M_Env_Rock_01–04`, `M_Env_Pebble_01–03`, `M_Env_Shell_01–02`, `M_Env_SeaGrass_01–03`, `LGT_Gulped` | 5.9 | Grey boxes |
| S12-A3 | Reef kit, first part | `M_Env_Reef_Floor_01–05`, `M_Env_Reef_RockBlock_01–04`, `M_Env_Reef_Coral_Brain_01–03`, `M_Env_Reef_Coral_Staghorn_01–03`, `T_EnvReef_Alb` | 18.5 | Slabs and boxes with the Reef tint |

| ID | Type | Task | Who |
|---|---|---|---|
| S12-T1 | Test | Multi-client routine with the full list of 09 §16.5 step 1, at 0 and 150 ms | Owner |
| S12-T2 | Test | Checklist items C9, P4, P5 and P6 of 04 §12 | Owner |
| S12-D1 | Check | No decision is needed: mid-run disconnect and the Revive offer (30 mass or more, no countdown, not on the first death) are set by canon §5.5. The owner confirms S12-C4 and S14-C1 use the canon rules. | Owner |

**Acceptance criteria**

- [ ] A player can eat another only when a full tier higher; tier 1 players cannot be eaten by players; nobody is eaten in the Nursery or a cove.
- [ ] The first bite from another player pops the newcomer bubble and costs nothing; the second gulps (P5).
- [ ] The gulped panel ignores input for 700 ms and has no countdown; Swim again reaches the cove in under 3 seconds.
- [ ] A Barracuda gives up after 6 seconds and never enters the Nursery or a cove.
- [ ] Quitting to avoid a bite does not save the creature.

**Risks.** Lag compensation tuned on two local clients will be wrong on real networks; settled on GULP Staging in Sprint 19. **Cut first:** jelly bloom to Sprint 15; `M_Env_Reef_Coral_Staghorn_01–03`.
**Hours.** 4 + 8 + 16 + 3 = 31 OH.

### Sprint 13 · 18–24 January 2027 · The first-two-minutes build at finished quality

**Goal.** A new player's first two minutes look, sound and play as they will at soft launch.
**Demo (M4, Friday 22 January).** Eight people who have never seen the game each play a fresh account on device row 1 for 10 minutes. The build checklist of 04 §12 is ticked in full.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S13-C1 | Polish and fixes against the full 04 §12 checklist | B31 and others | 04 §12 | L | — | Agent + owner |
| S13-C2 | Load budget: minimum set contents, atlas preload, streaming order; `load_partial` path | `src/first`, place | 04 §2 | M | S6-C1 | Agent + owner |
| S13-C3 | A/B plumbing: `ConfigService:GetConfigForPlayerAsync`, `ab.<key>` in the profile, `exp` custom field, `ab_exposed`; keys `ftue_chase_mode` and `ftue_home_mode` built | `LiveConfig`, B31 | 10 §8.1, 04 §11 | M | S5-C5 | Agent |

| ID | Art and audio task | Chapter 07 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S13-A1 | The Reef's main landmark | `M_Env_Reef_LM_NogginRock`, `T_Reef_NogginRock_Alb` | 10.5 | Coloured block with its key letter |
| S13-A2 | Kelp plants for the Gap's curtain and the kelp patch | `M_Env_Kelp_Plant_01–03` | 4 | Poles |
| S13-A3 | Channel and first open water dressed | (assembly) Sunlit Reef, first third | 4 | Block-out |
| S13-A4 | Music, next two | Tracks for `MUS_Cove` and `MUS_Reef` | 3 | Mallet loop |

| ID | Type | Task | Who |
|---|---|---|---|
| S13-T1 | Playtest | Eight new players, at least four aged 9 to 15 with a parent present. Device row 1, and device row 2 or 3 for two of them. Record time to first bite, tier 2, Glow and bank; whether they start run 2; whether they are still playing at 10 minutes. | Owner |
| S13-T2 | Test | The whole 04 §12 checklist, Load to Analytics, on device row 1; L4 over 10 fresh joins | Owner + agent |
| S13-M1 | Operations | Start a tester list for the friends-and-family stage: 30 to 60 names, at least 10 aged 9 to 15 (12 §1.3) | Owner |

**Acceptance criteria**

- [ ] Every item of 04 §12 passes, except P7's Pufferfish art and P8 (Moon Tide is not in the slice).
- [ ] Median join-to-control is 5 seconds or less over 10 fresh joins on device row 1 (L4).
- [ ] Frame rate on device row 1 stays at 30 or more from T = 0 to the first bank (A3).
- [ ] 5 of 8 new players bank within T = 120 (B10); 7 of 8 bite within 10 seconds.
- [ ] No placeholder is visible between load and the end of run 2.
- [ ] Gate G2 (section 9) is read and written down.

**Risks.** The eight-player result is below the gate. That is what the gate is for: Sprint 14 becomes a fix sprint and later dates move one week. **Cut first:** S13-C3's second key; `MUS_Reef`.
**Hours.** 4 + 5 + 12 + 9 = 30 OH.

### Sprint 14 · 25–31 January 2027 · Pufferfish; Revive and the receipt handler

**Goal.** The first unlock is worth saving for, and the first Robux product is granted safely.
**Demo.** Buy the Pufferfish with 500 Pearls, hatch as one, puff to survive a Barracuda. Buy a Revive in GULP Staging and come back at 70% mass.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S14-C1 | `ShopService`: `ProcessReceipt` (granted once, repeat receipt not granted twice, purchase waits for a confirmed save), the two-minute rule, `canSell`, policy check; Revive on the gulped panel | B27 | 09 §12.6, §18.4, 05 §8.3, §9 | L | S5-C1, S12-C3 | Agent + owner |
| S14-C2 | Puff: inflate 2 s, one tier higher for defence, 60% slower, 10 s cooldown; `HUD.Ability` with cooldown wedge; unlock row 14 of 04 §7.3 | B32 | 01 §7, 02 §7, 08 §3.8 | M | S8-C2, S12-C2 | Agent + owner |
| S14-C3 | `revive_offer` and `species_unlock` funnels | `Analytics` | 10 §3.5, §3.9 | S | S5-C1 | Agent |
| S14-C4 | Fixes from the Sprint 13 playtest | — | 04 | M | S13-T1 | Agent + owner |

| ID | Art and audio task | Chapter 07 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S14-A1 | Pufferfish meshes | `M_Species_Puffer_Juv`, `_Adult`, `_Juv_Puffed`, `_Adult_Puffed`, `_LOD1`, `_LOD2`, `_Shell`, (fit) Pufferfish on `RIG_Fish` | 20.5 | Capsule; sphere when puffed |
| S14-A2 | Pufferfish textures and clips | `T_Puffer_Juv_Alb`, `T_Puffer_Adult_Alb`, (check) Fish clips on the Pufferfish, `A_Puffer_FinWhir`, `A_Puffer_PuffIn`, `A_Puffer_PuffHold`, `A_Puffer_PuffOut`, `A_Puffer_Fidget` | 9.9 | Flat colour; procedural moves |

| ID | Type | Task | Who |
|---|---|---|---|
| S14-T1 | Test | A simulated receipt in an engine spec; a real test purchase of Revive in GULP Staging on device row 1 (a test build is published there for it; GULP Dev runs on `ProfileStore.Mock`, 09 §17.1); a cancelled purchase returns to the panel | Owner + agent |
| S14-T2 | Test | Pufferfish on the roster sheet beside the Minnow and Barracuda (06 §15.5); device row 1 | Owner |

**Acceptance criteria**

- [ ] The Pufferfish passes 06 §16.1 and cannot be confused with the Minnow at 48 pixels.
- [ ] A puffed tier 2 Pufferfish is not eaten by a tier 3 player or by the Barracuda's first bite.
- [ ] One Revive receipt is granted exactly once across a forced rejoin; the engine spec for the repeated receipt passes.
- [ ] No Revive offer on an account's first death, in the first two minutes, or when the lost creature had under 30 mass (canon §5.5).
- [ ] Nothing is sold, priced or prompted before the later of the first bank and two minutes.

**Risks.** `ProcessReceipt` details not re-verified (U20). **Cut first:** `A_Puffer_Fidget`, `A_Puffer_FinWhir`.
**Hours.** 4 + 6 + 18 + 2 = 30 OH.

### Sprint 15 · 1–7 February 2027 · Traits, trait prey and the remaining prey

**Goal.** "You are what you eat" works beyond the scripted Glow: five traits, three slots, visible on both species.
**Demo.** One run on each species collecting Stripes, Spots and Plated; shed one; Plated survives a bite and cracks.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S15-C1 | Trait rules for Stripes, Spots, Plated and Spiny in `TraitRules`, `TraitService`, `BiteRules`; screen S04 trait popover with the 0.6-second shed hold | B19, B07 | 01 §9, 02 §8, 08 §3.6 | M | S6-C3 | Agent |
| S15-C2 | Trait visuals on the rig: overlays by the option chosen in spike S0-A4, socketed kit pieces, three-trait combination rules | `CreatureRig` | 06 §8 | M | S9-C1 | Agent + owner |
| S15-C3 | Prey behaviours in `PreySim`: shrimp hop, sardine schools that flee as a group, darter turns, mackerel runs; zone spawn tables | B15, B16 | 01 §8.1, 03 §2 | M | S3-C2 | Agent |
| S15-C4 | Trait prey spawn sites; `trait` funnel | B16, `Analytics` | 03 §3, 10 §3.6 | S | S15-C3 | Agent |

| ID | Art and audio task | Chapter 07 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S15-A1 | Trait overlays on the Fish family | `T_Trait_Stripes_Fish_Alb`, `T_Trait_Spots_Fish_Alb`, `T_Trait_Plated_Fish_Alb` | 6.5 | Flat tint with the trait name |
| S15-A2 | Trait kit pieces | `M_Trait_Plated_Plate`, `_PlateCracked`, `_Helmet`, `M_Trait_Spiny_Spine`, `T_Trait_Pieces_Alb` | 4.7 | Boxes and cones on the real sockets |
| S15-A3 | Placement and checks | (placement) Trait pieces on the Minnow and on the Pufferfish; (check) Trait combination sheet, soft launch | 6 | — |
| S15-A4 | Trait prey | `M_Prey_ZebraDarter`, `M_Prey_DottedGoby`, `M_Prey_ArmorShrimp`, `M_Prey_UrchinPuff`, their shells and `_LOD2` | 5.7 | Ellipsoids with a ring |
| S15-A5 | Remaining prey | `M_Prey_Shrimp`, `M_Prey_Sardine`, `M_Prey_Darter`, `M_Prey_Mackerel`, `T_PreyLarge_Alb`, remaining shells | 8.9 | Ellipsoids |
| S15-A6 | Store stage *(float)* | `SCN_Stage_Reef` | 6 | — |

| ID | Type | Task | Who |
|---|---|---|---|
| S15-D1 | Tuning | Run `economy.sim` on the slice tables: time to each tier within 25% of 01 §5.1 for tiers 2 to 5; Pufferfish in session one | Owner + agent |
| S15-D2 | Design | Write the slice's temporary rules into chapter 03: where Armor Shrimp and Urchin Puff spawn, and what closes the map to the east and south | Owner |
| S15-T1 | Test | Combination sheet reviewed; the five traits told apart at 48 pixels on both species; device row 1 | Owner |

**Acceptance criteria**

- [ ] Five of the same trait prey give the trait; with three slots full, trait prey gives only mass until one is shed.
- [ ] Stripes gives +8% speed and the validator allows it; Spots gives +10% mass from prey only; Spiny needs a predator two tiers higher; Plated saves once and shows cracked.
- [ ] The combination sheet passes rule 7 of 06 §8.3 for all ten triples.
- [ ] All six prey and five trait prey are final in the manifest.
- [ ] `economy.sim` passes its tier-time check for tiers 2 to 5.

**Risks.** The overlay method chosen in Sprint 0 looks wrong with three traits at once. **Cut first:** S15-A6, then Spiny (pieces only, cheap to return).
**Hours.** 4 + 4 + 18 + 5 = 31 OH.

### Sprint 16 · 8–14 February 2027 · The Reef; tide events; shop

**Goal.** The first open-water zone is finished, the sea runs on a clock, and the shop sells the slice's passes and packs.
**Demo.** A Feeding Frenzy starts on the quarter hour on two devices at once, with a 60-second warning. Deep Pockets bought in GULP Staging doubles the next bank.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S16-C1 | `TideService` and `TideController`: phase from the UTC clock, Frenzy on all four slots through `TideDef.fallback`, `PreyService.setSpawnRate`, lighting preset | B26 | 09 §11.1, 02 §14 | M | S4-C3, S3-C3 | Agent |
| S16-C2 | `HUD.TideClock` and screen S09 event banners (warning, start, end) | `client/UI/Hud` | 08 §3.13, §4.7 | M | S16-C1 | Agent |
| S16-C3 | `LeaderboardService` server board and `HUD.Biggest` | B29 | 08 §3.14 | S | S2-C3 | Agent |
| S16-C4 | `ShopService` passes (Deep Pockets, Bigger Cove) and the four Pearl packs with the five-a-day limit; prices read with `GetProductInfo` | B27 | 05 §8.2, §8.4, §14 | L | S14-C1 | Agent + owner |
| S16-C5 | Screen S27 shop (Passes and Pearls tabs), screen S28 purchase result, offers O1, O4, O5 and O10 with the rules O-R1 to O-R13 | `client/UI/Screens` | 08 §6.4, §9 | M | S16-C4 | Agent + owner |

| ID | Art and audio task | Chapter 07 and 08 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S16-A1 | Reef kit, second part | `M_Env_Reef_Arch_01–03`, `M_Env_Reef_Coral_Table_01–02`, `M_Env_Reef_Sponge_01–02`, `M_Env_Reef_SoftCoral_01–03`, `M_Env_Reef_LM_Hoop` | 12.1 | Blocks |
| S16-A2 | Reef assembly, rest | (assembly) Sunlit Reef, remaining slice share | 5 | Block-out |
| S16-A3 | Frenzy look | `LGT_Event_Frenzy` | 1 | Reef preset |
| S16-A4 | Interface art for stage 3, first half | `UI_Shop_*` rows for the slice, tide clock and banner parts, pass and product icons for Deep Pockets, Bigger Cove, Revive and the four packs, `UI_Atlas_Content2` (about 35 drawings) | 13.5 (estimate) | Flat shapes |

| ID | Type | Task | Who |
|---|---|---|---|
| S16-D1 | Data | Offer timing and limits of 05 §9 into `Data/Generated/Products`; create the two passes and five products in GULP Staging and put their IDs in that environment's table in `Config/Defaults` | Owner + agent |
| S16-T1 | Test | Tide clock on device rows 1 and 7 side by side: same phase within 1 second | Owner |
| S16-T2 | Test | One test purchase of each pass and pack in GULP Staging; a cancelled prompt; a sixth pack in one day refused | Owner |

**Acceptance criteria**

- [ ] Warning at 60 seconds, start and end banners each show once; prey spawns at three times the rate for 4 minutes.
- [ ] Every price on screen equals the price in the Roblox prompt.
- [ ] Deep Pockets doubles banking and scraps after Crystal's place in the order, and does not change Reef Rank input.
- [ ] No offer appears in open water; every offer has a way out; no timers (08 §9).
- [ ] The Reef passes the zone sheet review and the owner's swim-through on device row 1 at 30 fps.

**Risks.** A Frenzy pushes the low phone under 30 fps with 2,250 prey. **Cut first:** offers O4 and O10 (shop only), then `M_Env_Reef_Coral_Table_01–02`.
**Hours.** 4 + 7 + 15 + 4 = 30 OH.

### Sprint 17 · 15–21 February 2027 · Kelp Forest kit; cove screens; goals

**Goal.** The cove is a place to manage a collection, and there is a second zone to push into.
**Demo.** Specimen grid with sorting, a slot bought with Pearls, an offline claim after a simulated 3 hours, three daily goals with the real reset.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S17-C1 | Screens S16 specimen grid and card, S18 slot upgrade, S15 offline claim, S13 cove-full choice with release refund | `client/UI/Screens`, B22 | 08 §4.6, §5.2, §5.4, §5.5, 05 §3.10, §4.2 | L | S5-C2, S10-C2 | Agent + owner |
| S17-C2 | `GoalsService` daily rotation after day one; screen S25 goals tab | B28 | 03 §9, 05 §3.5, 08 §6.3 | M | S11-C1 | Agent |
| S17-C3 | `CodexService.discover` records every species, tier, trait and prey in the profile (no screen) | B28 | 01 §11 | S | S4-C6 | Agent |
| S17-C4 | Kelp Forest volumes, spawn tables and currents; lighting blend by position | `WorldIndex`, `TideController` | 03 §6, 06 §10.3 | M | S2-C2 | Agent |
| S17-C5 | Analytics, first half: `run` and `shop_purchase` funnels, economy events for every Pearl source and sink | `Analytics` | 10 §3.2, §3.8, §5 | M | S5-C1 | Agent |

| ID | Art and audio task | Chapter 07 and 08 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S17-A1 | Kelp kit | `M_Env_Kelp_Floor_01–04`, `M_Env_Kelp_MossBoulder_01–03`, `M_Env_Kelp_RootMound_01–02`, `M_Env_Kelp_CanopyCard_01–02`, `M_Env_Kelp_Fern_01–02`, `M_Env_Kelp_Log_01`, `T_EnvKelp_Alb` | 15.6 | Poles and slabs with the Kelp tint |
| S17-A2 | Kelp landmarks | `M_Env_Kelp_LM_OldAnchor`, `M_Env_Kelp_LM_PeekabooRidge_01–03` | 11 | Coloured blocks |
| S17-A3 | Interface art for stage 3, second half | `UI_Cove_*`, `UI_Daily_*`, `UI_Settings_*`, `UI_Species_*` rows for the slice, `UI_Atlas_Glyphs2` (about 35 drawings) | 13.5 (estimate) | Flat shapes |
| S17-A4 | Store poses *(float)* | (pose) Marketing pose set, soft launch, without the Eel poses (the Eel does not exist yet); it includes the Barracuda's open jaws for icon A | 3.5 | — |

| ID | Type | Task | Who |
|---|---|---|---|
| S17-T1 | Test | Per-screen checks of 08 §16.2 for S13 to S16, S18, S25 on device rows 1, 2 and 7 | Owner |
| S17-T2 | Test | Economy events of one test session hand-counted against the dashboard (12 §2.5, N2) once events arrive from GULP Staging | Owner |

**Acceptance criteria**

- [ ] Each specimen card shows the right creature, tier, traits and income; at most 12 live renders.
- [ ] A slot price equals chapter 05; the new slot appears at once.
- [ ] The offline claim equals income × hours away, capped at 8, and is never shown in a new player's first two minutes.
- [ ] Three goals; the countdown matches the real reset; a completed goal pays once.
- [ ] A fresh save contains Codex discoveries after one run.

**Risks.** Live 3D renders in cards cost too much on the low phone (fallback: still meshes, 09 §15.6 step 5). **Cut first:** S17-A4, then sorting on screen S16.
**Hours.** 4 + 7 + 17 + 2 = 30 OH.

### Sprint 18 · 22–28 February 2027 · Kelp assembled; settings, reconnect, analytics, performance

**Goal.** Everything in the slice exists and plays on a phone.
**Demo (M5, Friday 26 February).** A full session on device row 1 in GULP Staging with 22 bots: first two minutes, three runs across Reef and Kelp, a Frenzy, a death, a purchase, settings changed, a reconnect.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S18-C1 | Screen S31 settings (every slice setting, saved per input type), screen S02 reconnect and screen S36 Continue your run (a dialog from existing parts, no new image; shown only to accounts that have banked) | `client/UI/Screens` | 08 §6.7, §8.2, §8.3, 15 §10 item 7 | L | S10-C2 | Agent + owner |
| S18-C2 | Analytics, second half: `tide_event` funnel, first-session and return funnels, the slice's custom events, `sess_device`, `perf_tier`, `cheat_flag`; the guard rules of 10 §9.2 | `Analytics`, services | 10 §3.3, §3.4, §3.7, §4.2, §9.2 | L | S17-C5 | Agent |
| S18-C3 | `Dev/BotPlayers`, the soak routine, first performance pass, the ordered cuts of 09 §15.6 behind quality switches, memory guard | B34, `UIController` | 09 §15.5, §15.6, 15 §6 | L | S8-C2, S3-C3 | Agent + owner (device row 1) |
| S18-C4 | Tablet scale and field of view; gulp assist strength per input type; input-mode detection finished | `InputController`, `CameraController` | 15 §3.2, §4.3, §5 | M | S8-C4 | Agent + owner |

| ID | Art and audio task | Chapter 07 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S18-A1 | Kelp assembly and light | (assembly) Kelp Forest, slice share; `LGT_Kelp` | 10.5 | Block-out |
| S18-A2 | Jelly bloom and current markers | `M_Hazard_Jelly_Open, _Squeezed`, `T_Jelly_Alb`, `T_Jelly_Emi`, `M_Env_SeaGrass_Bent_01–02` | 5.2 | Sphere; bent poles |
| S18-A3 | Low-end lighting variants | (variant) Low-end device variants, for the slice presets | 1.5 | — |
| S18-A4 | Main icon *(float)* | `SCN_Icon_A_BehindYou`, soft-launch version: the open mouth behind the Minnow is the Barracuda's, because Old Scar is not in the slice. No text on the icon. | 5 | — |

| ID | Type | Task | Who |
|---|---|---|---|
| S18-T1 | Test | Server soak: 24 bots, 10 minutes with one Frenzy; MicroProfiler numbers against 09 §15.2 | Agent + owner |
| S18-T2 | Test | Phone run on device row 1 during a Frenzy; leak check; device row 5 (tablet) layout in the simulator | Owner |
| S18-T3 | Test | Slice feature list of section 3.2 ticked line by line | Owner |

**Acceptance criteria**

- [ ] Every line of section 3.2 exists in the build and was played on device row 1.
- [ ] Server heartbeat averages 58 or more with 24 bots; script time is within 09 §15.2.
- [ ] Device row 1: 10-minute Frenzy, 10-second average never under 25 fps, memory under 900 MB, no crash (15 §8, row 1).
- [ ] Every setting applies at once and survives a rejoin.
- [ ] `guard_flag` fires for each rule of 10 §9.2 in a scripted test and for none in honest play.
- [ ] The Kelp Forest passes the zone sheet review and the swim-through.

**Risks.** The performance pass finds a budget miss that needs art changes. **Cut first:** S18-A4, S18-A3, then per-input saved settings.
**Hours.** 4 + 10 + 13 + 4 = 31 OH.

### Sprint 19 · 1–7 March 2027 · Private test, week 1 (`S−4`)

**Goal.** The build runs for invited testers on real devices and real data stores.
**Demo.** Ten sessions by invited testers in GULP Staging with no severity 1 bug.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S19-C1 | Security pass: remote validation and rate limits against 09 §14.2; the likely exploits of 09 §14.3 tried by an agent with dev cheats | `Net/Server`, services | 09 §14 | M | — | Agent |
| S19-C2 | Release tooling: version bump and change list, `check_place`, the full smoke test, the placeholder release check | `tools/` | 09 §17.2, §17.3 | M | — | Agent |
| S19-C3 | Bug fixes from testers | — | — | L | S19-T1 | Agent + owner |

| ID | Art and audio task | Chapter 07 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S19-A1 | Remaining slice effects | From 07 §9: tier-ups T4 to T6, Puff, Plated crack, Spiny, Stripes and Spots gain, Barracuda lunge, jelly sting, Frenzy start and end, remaining cove and Pearl effects | 21.5 | White dot bursts |

| ID | Type | Task | Who |
|---|---|---|---|
| S19-M1 | Operations | Publish to GULP Staging by the steps of 09 §17.2. Invite up to 10 early testers (12 §1.1). Tell them saves will be wiped. | Owner |
| S19-T1 | Test | Staging routine of 09 §16.5 steps 2 and 3: device row 1 and the Mac with 22 bots for 10 minutes; a 30-minute soak | Owner |
| S19-T2 | Test | Device rows 2, 3 and 6 (small iPhone, mid phone, low laptop): one full session each | Owner, borrowed devices |
| S19-M2 | Marketing | Name-collision check 1 (11 §2.4). Reserve `@playgulp`. Open the Roblox community (created in Sprint 0, task S0-M1) and start promoting it. Post short videos 5 and 14 (11 §9.2). | Owner |

**Acceptance criteria**

- [ ] `bite_reject` under 2% and `cheat_flag` zero in the staging run (09 §16.5).
- [ ] No exploit in 09 §14.3 succeeds.
- [ ] A release can be produced by following 09 §17.2 with no step improvised.
- [ ] Device rows 2, 3 and 6 complete a session; findings are filed.
- [ ] All six steps of the name check pass.

**Risks.** Real data stores or real networks expose a save or bite problem that Studio hid. **Cut first:** half of S19-A1 slides to Sprint 20.
**Hours.** 4 + 7 + 13 + 7 = 31 OH.

### Sprint 20 · 8–14 March 2027 · Private test, week 2 (`S−3`)

**Goal.** Meet the private-test exit criteria of 12 §1.1.
**Demo.** The exit criteria, each with its evidence.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S20-C1 | Bug fixes from the private test | — | — | L | S19-T1 | Agent + owner |
| S20-C2 | Launch data from share links and ads read on join and stored with the session (12 §2.5, N4) | `PlayerLifecycle`, `Analytics` | 10 §2.4, 11 F20 | S | S18-C2 | Agent |

| ID | Art and audio task | Chapter 07 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S20-A1 | Remaining slice sounds, first half | From 07 §11: Pufferfish voice, Puff, trait sounds for the five traits, jelly, remaining interface sounds for shop, goals and settings | 12 | Script-made tones |
| S20-A2 | Lead thumbnails | `SCN_Thumb_T1_Chase`, `SCN_Thumb_T2_BecomeWhatYouEat`, `SCN_Thumb_T3_GetHome` in its soft-launch version (the Barracuda's head enters the frame, not Old Scar's), then the paint-over of 11 §4. Only slice assets are used. | 12 + 3 OH | — |

| ID | Type | Task | Who |
|---|---|---|---|
| S20-T1 | Test | Exit criteria: 10 sessions in a row with no severity 1 bug; no save loss in 100 test saves on real stores; first bite within 10 seconds for 9 of 10 testers | Owner |
| S20-T2 | Test | Device rows 4 and 5 (long phone with a notch, tablet): layout in the simulator and one real session each if a device can be borrowed | Owner |
| S20-M1 | Marketing | The free checks of 11 §7.1 on icon A and T1 to T3 (one hour each): squint test at 150 px and at 75 px on a real phone. Videos 2 and 6 and one devlog. First community post. | Owner |

**Acceptance criteria**

- [ ] All three private-test exit criteria are met and written down.
- [ ] Icon A reads at 150 px on device row 1 at arm's length: one creature, one threat (the Barracuda), and no text.
- [ ] Icon A and T1 to T3 contain no control pictures (15 §7) and nothing that is not in the build (12 §7, C16): the threat is the Barracuda in all of them, and Old Scar appears in none.
- [ ] A test share link shows up in the events.

**Risks.** A severity 1 bug appears late in the week (the stage is extended by one week and `S` moves). **Cut first:** `SCN_Thumb_T3_GetHome`, then S20-C2.
**Hours.** 4 + 4 + 15 + 7 = 30 OH.

### Sprint 21 · 15–21 March 2027 · Friends-and-family test, week 1 (`S−2`)

**Goal.** People who know nothing about the design get through the first session, and a server holds real players.
**Demo.** The first funnel from at least 30 first-time players, read in the Roblox dashboard.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S21-C1 | Funnel fixes: the weakest onboarding step from the first 30 players | B31 | 10 §11 | M | S21-T1 | Agent + owner |
| S21-C2 | Bug fixes | — | — | M | — | Agent + owner |

| ID | Art and audio task | Chapter 07 assets | WH | Placeholder meanwhile |
|---|---|---|---|---|
| S21-A1 | Remaining slice sounds, second half | From 07 §11: Frenzy horn and warning bell, Kelp ambience, remaining ambience and transitions | 11 | Script-made tones |
| S21-A2 | Music, last three | Tracks for `MUS_Kelp`, `MUS_Event_Frenzy`, `MUS_Event_Warning` | 4.5 | Mallet loop |
| S21-A3 | Cove thumbnail and end card | `SCN_Thumb_T5_YourCove` (Minnow and Pufferfish specimens with slice traits only), `SCN_Brand_EndCard` | 6 | — |
| S21-A4 | Import pass | (import) Studio import and fixes, soft launch, slice share | 8 | — |

| ID | Type | Task | Who |
|---|---|---|---|
| S21-T1 | Test | Stage 2 opens: Playtest list and Roblox friends, 30 to 60 people. At least 10 testers aged 9 to 15: first try Approved Experience on the private game; if it does not work, in person on the owner's account with a parent present (12 §1.3). | Owner |
| S21-T2 | Test | One scheduled session with 12 or more players on one server; server numbers against 09 §15.2 | Owner |
| S21-T3 | Test | Analytics checks N1 to N5 of 12 §2.5 | Owner |
| S21-M1 | Marketing | Game page description written (11 §6.1) with the slice's real numbers: 2 creatures, 5 traits. Videos 1, 3, 4 and 13. | Owner |

**Acceptance criteria**

- [ ] 30 or more first-time players have passed through the funnel.
- [ ] Funnel events for loaded, first bite, tier 2, 60 seconds, 180 seconds, first bank and second run each show a count (N1).
- [ ] A 12-player session ran with heartbeat at 58 or more and no save loss.
- [ ] No call leaves the game to a third-party service (N5).
- [ ] The release check finds no placeholder among slice rows.

**Risks.** Too few testers, or too few young ones, to read the funnel. **Cut first:** `SCN_Brand_EndCard`; S21-A2's `MUS_Event_Warning`.
**Hours.** 4 + 4 + 14 + 9 = 31 OH.

### Sprint 22 · 22–28 March 2027 · Friends-and-family test, week 2; launch checklist (`S−1`)

**Goal.** Meet the stage 2 exit criteria and have everything on the launch checklist ready.
**Demo.** A release candidate in GULP Staging, and the store page approved by moderation.

| ID | Code task | Module or file | Bible | Size | Depends on | Who |
|---|---|---|---|---|---|---|
| S22-C1 | Funnel and bug fixes | — | 10 §11 | M | S21-T1 | Agent + owner |
| S22-C2 | The config switches of 12 §2.6 mapped to `flag.*`, `kill.*` and `tune.*` keys with defaults; `min_place_version` notice | `LiveConfig` | 12 §2.6, 09 §17.4 | S | S5-C5 | Agent |
| S22-C3 | Notification string 1 and the opt-in prompt after the first bank (N6, N8); awards for the [MVP] badges the slice can earn (03 §12). The other [MVP] badges are awarded from the update that ships their content. | `CoveService`, `PlayerLifecycle` | 12 §2.3, §2.5 | M | S5-C2 | Agent |

| ID | Type | Task | Who |
|---|---|---|---|
| S22-M1 | Operations | 12 §2.1: pay the publishing fee or confirm Roblox Plus (decision D12); Developer Exchange eligibility; Open Cloud keys | Owner |
| S22-M2 | Operations | 12 §2.2: every setting G1 to G25 at its `S` value (G25 is Roblox text chat, off); private servers off; playable devices phone, tablet, computer | Owner |
| S22-M3 | Operations | 12 §2.3: create Deep Pockets, Bigger Cove, Revive and the four Pearl packs in GULP at chapter 05 prices, with icons; create [MVP] badge batch 1 (five badges) on Sun 28 March, `S−4` days. Batches 2 to 4 follow on Mon 29, Tue 30 and Wed 31 March in Sprint 23, five free a day (12 §2.3: 20 [MVP] badges in four batches). | Owner |
| S22-M4 | Operations | 12 §2.4: the maturity questionnaire, answered for the most extreme content | Owner |
| S22-M5 | Operations | Erasure templates (G21); the compliance checklists of 05 §14 and 12 §7 read line by line; licences filed in `docs/licences/` | Owner |
| S22-M6 | Marketing | Name-collision check 2. Upload icon A and T1, T2, T3, T5 for moderation. Set up the Ads Manager account. Announce the date in the community. Videos 7 and 8. | Owner |
| S22-T1 | Test | Stage 2 exit: each canon measure within 10 points of its target on 30 or more first-time players; a second 12-player session; no save loss | Owner |
| S22-T2 | Test | Device rows 1 to 7, one full session each on the release candidate | Owner |

**Acceptance criteria**

- [ ] With 30 or more first-time players: first bite within 10 seconds at 80% or more, still playing at 60 seconds at 70% or more, first bank at 50% or more (gate G3).
- [ ] The icon and four thumbnails are approved.
- [ ] A test purchase of every item has been made in GULP Staging and granted once.
- [ ] The questionnaire is complete and a label is shown.
- [ ] Every line of 05 §14 that applies to the slice is ticked.

**Risks.** Moderation rejects an image (allow 48 hours and one retry). The funnel misses gate G3. **Cut first:** nothing is cut; a miss on G3 moves `S` by two weeks.
**Hours.** 4 + 4 + 0 + 22 = 30 OH.

### Sprint 23 · 29 March–4 April 2027 · Soft-launch week

**Goal.** Make the game public without breaking it.
**Demo (M8).** GULP is public on **Thursday 1 April 2027 at 15:00 UTC** and passes the T+2 hours check.

| ID | Type | When | Task (the runbook of 12 §2.7) | Who |
|---|---|---|---|---|
| S23-M1 | Operations | Tue 30 Mar, T−48 h | Freeze the build. Only severity 1 and 2 fixes from here. Create [MVP] badge batch 3 (batch 2 was created on Mon 29 Mar). | Owner |
| S23-M2 | Operations | Wed 31 Mar, T−24 h | Publish the frozen build to GULP Staging. One full session on device row 1 and one on the Mac. One test purchase of each item. Create [MVP] badge batch 4, the last. | Owner |
| S23-M3 | Operations | Thu 1 Apr, T−3 h | Data store snapshot through Open Cloud. Tag the commit. Check every config value. | Owner + agent |
| S23-M4 | Operations | T−1 h | Publish to GULP. Join a fresh server; check the version in settings. | Owner |
| S23-M5 | Operations | T | Set access to public. | Owner |
| S23-M6 | Operations | T to T+2 h | Stay in the game and on the dashboard. Every 15 minutes: errors, purchase failures, server count, "first bite" and "60 seconds". | Owner |
| S23-M7 | Operations | T+2 h | Go-ahead check: fewer than 1 in 200 sessions with a player-facing error, no save failures, purchases completing. Otherwise the rollback plan of 12 §2.8. | Owner |
| S23-M8 | Marketing | T+6 h onward | T1, T2 and T3 active with personalisation on. First short video. Community announcement with notification. Videos 9 and 10. | Owner |
| S23-M9 | Operations | Fri 2 Apr, T+24 h | Day-zero numbers: sessions, the 01 §17 funnel, first-play bounce, purchase success. Write the bug list. Hotfix only for severity 1 or 2. | Owner |
| S23-M10 | Marketing | From Fri 2 Apr | Paid step 0 of 11 §10.3 is read from the stage 2 funnel. If it passed, step 1 starts: 10 US dollars a day for 3 days, Engagement objective. | Owner |
| S23-C1 | Code | All week | Hotfixes, size M reserve | Agent + owner |

**Acceptance criteria**

- [ ] The T+2 hours check passes.
- [ ] The Audience Reach dashboard shows the evaluation counting.
- [ ] No publish after 18:00 UTC on Friday; two 15-minute checks on Saturday and on Sunday.
- [ ] Day-zero numbers and the bug list are in the Sprint 23 milestone.

**Risks.** The first minute is broken for real players in a way testers did not hit. Use the rollback rows of 12 §2.8 in order.
**Hours.** 4 + 3 + 0 + 23 = 30 OH.

### Sprints 24 to 34 · 5 April–20 June 2027 · Soft launch

**Phase 3a** (Sprints 23 to 26, estimate) is the trial with age-checked players of 16 and over. **Phase 3b** starts on the day the Audience Reach dashboard shows the evaluation passed. The plan assumes Thursday 22 April 2027; Roblox decides the real day.

**Every soft-launch sprint has the same frame.**

| Part | What | OH |
|---|---|---|
| Rhythm | Monday planning with the weekly numbers review of 10 §11 first; Friday playtest of the update on GULP Staging; tracker | 4 |
| Live operations | Daily routine (12 §5.4) and alarm check (10 §9.1); Thursday 15:00 UTC publish by 09 §17.2; hotfix reserve; weekly profiling routine | 8 |
| Marketing | Four short videos a week from one 2-hour session; weekly community post; replies | 4 |
| Funnel work | The weakest number in the priority order of 10 §11 (1, then 3, then 5, then 6, then 9). One change at a time. | 4 to 8 |
| Top-up queue | Section 3.4, in order. Only after the week's funnel work is done. | 6 to 10 |

A/B tests follow 10 §8 and 04 §11 in the order 1, 2, 3, 4. A test needs about 150 new players a day per arm to finish in two weeks (10 §8.2). Below that volume, changes are made one at a time and read before and after.

| Sprint | Dates | Funnel and operations | Top-up task (chapter 07 assets, WH) | Ships Thursday | Acceptance |
|---|---|---|---|---|---|
| 24 | 5–11 Apr | Read day-1 and day-7 retention of the launch-day cohort (T+7 days). Read paid step 1 on its day 3: cost per play and 60-second survival of ad players. Fix the weakest onboarding step. | S24-A1 Eel meshes: `M_Species_Base_Eel`, `RIG_Eel`, `M_Species_Eel_Juv`, `_Adult`, shells and distance versions (18) | Update 1: fixes | The onboarding step fixed last week moved in the right direction or is reverted |
| 25 | 12–18 Apr | Second funnel fix. Check evaluation progress daily; pause the Engagement campaign by hand when the threshold is reached (11 §10.3). | S25-A1 (fit) Eel on `RIG_Eel`, `T_Eel_Juv_Alb`, `T_Eel_Adult_Alb`, the 13 `A_Eel_*` clips, `A_Eel_Slip`, `A_Eel_Fidget` (24). S25-C1 Slip, eel-hole volumes (M). | Update 2: fixes | Eel contact sheet passes 06 §16.1 |
| 26 | 19–25 Apr | Phase 3b expected. Switch the ad objective to Plays. Start A/B test 1 (`ftue_chase_mode`) if volume allows. | S26-A1 Eel overlays for Glow, Stripes, Spots, Plated; placement; `M_Env_EelHole_Ring_01–02`, `M_Env_EelHole_Tunnel_01–03`; Eel voice (11). S26-C1 unlock row 15 of 04 §7.3 (S). | **Update 3: the Eel** (Thu 22 Apr) | The Eel is unlockable at 3,000 Pearls; Slip passes eel holes; M9 recorded with its real date |
| 27 | 26 Apr–2 May | First read with under-16s. **Old Scar watch:** if creatures of tier 5 and above bank more than 80% of their runs and are more than 15% of all runs, Old Scar moves into the queue after Moon Tide. | S27-A1 `SKY_MoonTide`, `T_Sky_Moon_Alb`, `T_EnvReef_Emi`, `T_EnvKelp_Emi`, `T_EnvNursery_Emi`, (data) Night tints, `LGT_Event_MoonTide` (12). S27-C1 night switch in `TideController`, Lunar Fry spawns, Moonlit rule (M + M). | Update 4: fixes | Moon Tide runs behind `flag.moonTide` in GULP Staging |
| 28 | 3–9 May | Paid step 2 starts once under-16s can play: 10 US dollars a day for 14 days, to reach and hold 100 daily users. It runs on the thumbnails that exist (T1, T2, T3 and T5); T4 and T6 are not made until Sprint 31, after the 14 days. | S28-A1 (test) Moon Tide switch, `M_Prey_LunarFry`, `T_Trait_Moonlit_Fish_Emi`, `T_Trait_Moonlit_Eel_Emi`, Moon Tide effects and sounds, a track for `MUS_Event_MoonTide` (13) | **Update 5: Moon Tide** (Thu 6 May). Rotation becomes :00 Frenzy, :15 Moon Tide, :30 Frenzy, :45 Moon Tide. | P8 of 04 §12 passes: a newcomer in run 1 sees no darkening. Outlines stay readable at night on device row 1. |
| 29 | 10–16 May | Tide pull read for the first time (10 §7). Replace the weakest thumbnail after round 1 with T5, the only spare until T4 and T6 are made in Sprint 31 (11 §7.2). | S29-A1 `M_Pred_Gull_Glide`, `_Dive`, `_Shell`, `T_Gull_Alb`, `T_Gull_Shadow_Mask`, Gull effects and sounds (11). S29-C1 Gull state machine: shadow, 1.5-second dive (M). | **Update 6: the Gull** (Thu 13 May) | The Gull targets only tiers 1 and 2 lingering at the Reef surface, never a newcomer in the predator grace |
| 30 | 17–23 May | Second A/B test if the first has ended on its planned date. | S30-A1 `M_Cove_CodexStone`; `UI_Codex_*` rows, about 15 drawings (2 + 6). S30-C1 screens S23 and S24, Codex rewards of 05 §3.8, unlock row 9 of 04 §7.3 (L). | **Update 7: the Codex** (Thu 20 May) | Counts per tab are right; discoveries recorded since `S` are all shown |
| 31 | 24–30 May | Start the icon test once daily users pass 100 (11 §7.3). | S31-A1 `SCN_Icon_D_Puffed`, `SCN_Thumb_T4_FiveSizes` (the soft-launch T4: tiers 1 to 5, no crest), `SCN_Thumb_T6_MoonTide`, (staging) Gameplay preview capture set-ups (16). S31-M1 record and edit the page cut, real gameplay only and only content that is live that week, so no Drop-off, Old Scar, Moray or hook shots (11 §5), 6 OH. T4 and T6 become the spares for any later thumbnail replacement. | Update 8: fixes; the video and T6 go live | The video is approved (three uploads a month; a rejection uses one) |
| 32 | 31 May–6 Jun | Hold 100 daily users. From here no change that touches the economy. | S32-C1 agent-only code for deferred [MVP] systems behind flags: `PredatorSim` states for Old Scar and Moray, trait rules for Longfin, Ink and Crystal (L, 3 OH of owner time at most) | Update 9: fixes | 100 daily users on each of the last 7 days, or the reason why not is written down |
| 33 | 7–13 Jun | Read window, week 1. Fixes only. | None | Update 10: fixes only | Nothing shipped that could move retention or session time |
| 34 | 14–20 Jun | Read window, week 2. Build the go/no-go pack: 7-day averages of day-1 retention and session time against the benchmark, organic and ad players apart; the 01 §17 funnel; earnings; the measured OH-per-WH ratios; the re-dated plan for both outcomes. | None. Decisions D4 to D8 answered. | No update unless severity 1 | The pack is complete by Sunday 20 June |

**Hours.** Every sprint: 4 + 8 live operations + 4 marketing + 14 funnel and top-up = 30 OH. Top-up art across the eleven sprints: about 105 WH.

**Risks for the whole soft launch.** The evaluation takes longer than three weeks, so the core audience arrives late (gate G5). Daily users never reach 100, so there is no benchmark (gate G6). The owner spends the hours on top-up content while the funnel is under target; the frame above forbids it. **Cut first:** queue items 5, then 4, then 3.

## 6. Sprints 35 to 65: from the go/no-go to public launch

This section applies only after a "go" at gate G7. It is written in less detail because the measured ratios from Sprints 0 to 34 will re-size every row. Hours are chapter 07 first-pass WH unless marked.

### 6.1 The frame of a post-go sprint

| Part | What | OH |
|---|---|---|
| Rhythm | As section 1.4 | 4 |
| Live operations | The soft-launch game stays public. Daily routine; a Thursday 15:00 UTC update in every week that finishes deferred [MVP] content (each week from Sprint 39 to Sprint 44) and otherwise a fix update about every two weeks; hotfix reserve. | 4 (average) |
| Marketing | One video session a week; community post | 2 |
| Build | About 25 WH of art (13 OH) and about 14 WH of code (4 OH), plus checks | 20 |

Deferred [MVP] content ships to the live game as it is finished. [L] content is built behind `flag.*` keys, tested in GULP Staging, and released together on `P` day (12 §1.1). Interface art for [L] (120 rows and 130 drawings in 08 §13.13, estimated here at 0.4 WH a drawing, about 52 WH) is spread across the sprints that need it. Sprints 43 to 54 name 45 WH of it; the other 7 WH or so are not yet placed in a sprint and are assigned when this section is re-sized at gate G7.

### 6.2 When each deferred item returns

| Deferred item | Returns in sprint | Reaches players |
|---|---|---|
| Eel, Slip, eel holes | 24 to 26 | Thu 22 Apr 2027 |
| Moon Tide, Lunar Fry, Moonlit | 27 and 28 | Thu 6 May 2027 |
| Gull | 29 | Thu 13 May 2027 |
| Codex screens and stone | 30 | Thu 20 May 2027 |
| Icon D, T4, T6, page video | 31 | Thu 27 May 2027 |
| The Drop-off, Bonito, Tuna, cold vents, `LGT_DropOff` | 35 to 39 | Thu 22 Jul 2027 |
| Old Scar | 40 | Thu 29 Jul 2027 |
| Moray, hook | 41 | Thu 5 Aug 2027 |
| Longfin, Ink, Crystal and their prey; crests; screens S05 and S17 | 36 and 42 | Thu 12 Aug 2027 (full [MVP]) |
| 13 landmarks; perch net, trophy rock | 43 and 44 | Thu 19 and Thu 26 Aug 2027 |
| A third of the kit variants | 57 (cut candidate) | `P` day, or never if cut |
| Composed music | 59 and 60 for the theme, Nursery, Cove, Reef and stingers (cut candidate). The other zone and event tracks stay licensed until revenue pays for them (decision D6). | `P` day, or later |

### 6.3 Core build, Sprints 35 to 54

**Sprint 35 · 21–27 June 2027 · Go/no-go; Drop-off kit 1**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S35-D1 | Gate G7 on Monday 21 June. On "go": re-size Sprints 35 to 65 with the measured ratios; answer D4 to D8; publish the dates. | Section 9 | 3 OH | Owner |
| S35-A1 | Drop-off cliffs and shelves | `M_Env_DropOff_Cliff_01–08`, `M_Env_DropOff_Ledge_01–04`, `M_Env_DropOff_Overhang_01–03`, `M_Env_DropOff_FloorShelf_01–02`, `T_EnvDropOff_Alb` | 22 | Agent + owner |
| S35-C1 | Drop-off volumes, zone data, spawn tables, depth-blended lighting | `WorldIndex`, `TideController`, `Data/Generated/Zones` | M + S | Agent |

Acceptance: the decision and the new dates are written in section 4; a Drop-off block-out with finished cliffs loads on device row 1 at 30 fps. Hours: 4 + 4 + 2 + 20 = 30 OH.

**Sprint 36 · 28 June–4 July 2027 · Drop-off kit 2; Bonito, Tuna, cold vents**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S36-A1 | Deep floor and dressing | `M_Env_DropOff_DeepFloor_01–04`, `_WallCrack_01–02`, `_DarkSponge_01–04`, `_SeaWhip_01–03`, `_TubeWorm_01–02`, `_Bones_01–03` | 14 | Agent + owner |
| S36-A2 | Late prey and cold chimneys | `M_Prey_Bonito`, `M_Prey_Tuna`, `M_Hazard_Vent_01–03`, `T_Vent_Alb` | 9.5 | Agent + owner |
| S36-C1 | Bonito packs and Tuna flee behaviour in `PreySim`; screens S05 tide popover and S17 specimen detail | B15, `client/UI/Screens` | M + M + M | Agent |

Acceptance: Bonito and Tuna pass 06 §16.1; `economy.sim` reaches tier 6 within 25% of the 12-minute target of 01 §5.1. Hours: 30 OH.

**Sprint 37 · 5–11 July 2027 · Drop-off landmarks**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S37-A1 | Four landmarks and the deep light | `M_Env_DropOff_LM_InkPots_01–02`, `_LM_Overbite`, `_LM_SlipstoneSlope_01–03`, `_LM_Crack_01–03`, `T_Decal_ScarScrape_Mask`, `LGT_DropOff`, `T_EnvDropOff_Emi` | 20.3 | Agent + owner |
| S37-C1 | Old Scar, Moray and hook wired from the Sprint 32 pre-work into `PredatorService`; telegraphs in `PredatorController` | B24 | L | Agent + owner |

Acceptance: each landmark is told from the others at 48 pixels on the zone sheet; Old Scar eats tier 6 and below and cannot be eaten, in an engine spec. Hours: 30 OH.

**Sprint 38 · 12–18 July 2027 · The Tin Pickle**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S38-A1 | The wreck | `M_Env_DropOff_LM_TinPickle_Bow`, `_Stern`, `_Cabin`, `_Debris_01–03`, `M_Env_DropOff_LM_TinPickle_Shelf`, `T_EnvWreck_Alb` | 23 | Agent + owner |
| S38-C1 | `economy.sim` on the full [MVP] tables; retune; analytics events for the returning content | `tests/sim`, `Analytics` | M + S | Agent + owner |

Acceptance: the wreck follows chapter 03's brief (a pickle-green tugboat); species unlock days are within 30% of 01 §7 in the simulation. Hours: 30 OH.

**Sprint 39 · 19–25 July 2027 · Drop-off assembly**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S39-A1 | Assemble and light the zone; ambience and a licensed track for `MUS_DropOff` | (assembly) The Drop-off; Drop-off rows of 07 §11.6 | 20.5 | Owner + agent |
| S39-C1 | Remove the haze boundary; currents into the Drop-off; soak test on the full map | `WorldIndex`, B34 | M | Agent + owner |

Acceptance: **update on Thu 22 July: the Drop-off opens.** Device row 1 holds 30 fps in the Drop-off; server budgets of 09 §15.2 hold with 24 bots. Hours: 30 OH.

**Sprint 40 · 26 July–1 August 2027 · Old Scar**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S40-A1 | Old Scar | `M_Pred_OldScar`, `RIG_OldScar`, `T_OldScar_Alb`, `M_Pred_OldScar_LOD1, _LOD2, _Shell`, `A_OldScar_Alert`, `A_OldScar_Bite`, its sounds and effects | 25 | Agent + owner |
| S40-C1 | Old Scar's own threat arrow (08 §3.9); tuning of roam and alert | `client/UI/Hud`, B24 | M | Agent + owner |

Acceptance: **update on Thu 29 July.** Old Scar is recognised from its silhouette alone; bank rate for tier 5 and above falls inside the 35% to 60% band within two weeks. Hours: 30 OH.

**Sprint 41 · 2–8 August 2027 · Moray and hook**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S41-A1 | Moray | `M_Pred_Moray`, `RIG_Moray`, `T_Moray_Alb`, LOD and shell, `A_Moray_Lurk`, `_Warn`, `_Lunge`, `_Catch`, `_Retract` | 15.8 | Agent + owner |
| S41-A2 | Hook set, sounds and effects for both | `M_Hazard_Hook`, `M_Hazard_Bait_01–02`, `M_Hazard_Bobber`, `T_HookSet_Alb`, `T_FishingLine_Mask` | 7.9 | Agent + owner |

Acceptance: **update on Thu 5 August.** The Moray warns before it lunges; the hook costs 20% of mass and is played for laughs. Hours: 30 OH.

**Sprint 42 · 9–15 August 2027 · Longfin, Ink, Crystal**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S42-A1 | Three traits on Fish and Eel | `M_Trait_Longfin_RibbonTail`, `_RibbonFin`, `T_Trait_Ink_Fish_Alb`, `_Eel_Alb`, `T_Trait_Crystal_Fish_Alb`, `_Eel_Alb`, `M_Trait_Crystal_Shard_01–03` | 9.4 | Agent + owner |
| S42-A2 | Their prey; crests | `M_Prey_Ribbonfish`, `M_Prey_Inklet`, `M_Prey_CrystalJelly`, `RIG_PreyRibbon4`, `RIG_PreyBlob4`, `T_TraitPrey_02_Alb`, `T_TraitPrey_03_Alb`, shells; `M_Species_Minnow_Crest`, `_Puffer_Crest`, `_Eel_Crest`; effects and sounds | 17.5 | Agent + owner |
| S42-C1 | Rules switched on from the pre-work; the Crystal drift (one drift per server every 5 minutes); gamepad scheme started | B19, B16, B41 (`InputController`) | M + M | Agent |

Acceptance: **update on Thu 12 August: full [MVP] live (M11).** The release check finds no placeholder among [MVP] rows. Gate G7a is read on Monday 16 August, the first day of Sprint 43. Hours: 30 OH.

**Sprint 43 · 16–22 August 2027 · Reef and Nursery landmarks; gamepad**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S43-A1 | Eight landmarks | `M_Env_Reef_LM_HoneycombCaves`, `_LM_Crackles_01–03`, `_LM_StripeAlley_01–02`, `_LM_Snooze`, `_LM_GullRock`; `M_Env_Nursery_LM_BubbleFountain`, `_LM_CoralRing`, `_LM_SleepyClam`, `A_SleepyClam_Snore` | 25.1 | Agent + owner |
| S43-C1 | Pad scheme in `InputController`; `UI_Atlas_Hints1` (27 glyphs, 5 WH) | B41; 08 §10.4, 15 §3.3 | L | Agent + owner (real Xbox pad and DualSense on the Mac) |

Acceptance: update on Thu 19 August; a pad drives the same `SwimInput` as touch and keys. Hours: 30 OH.

**Sprint 44 · 23–29 August 2027 · Kelp landmarks; focus navigation**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S44-A1 | Five landmarks and small cove pieces; last [MVP] sounds and effects | `M_Env_Kelp_LM_RibbonRoof_01–02`, `_LM_LookoutStack`, `_LM_RootBall`, `_LM_GlowStalk_01–02`, `_LM_HushHollow`; `M_Cove_PerchNet`, `M_Cove_TrophyRock` | 25 | Agent + owner |
| S44-C1 | Focus navigation and the hint bar on every screen | `client/UI/Kit`, all screens | L + M | Agent + owner |

Acceptance: update on Thu 26 August; every screen can be used with the four directions, select and back (15 §0, PF13). Hours: 30 OH.

**Sprint 45 · 30 August–5 September 2027 · Sea Turtle 1**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S45-A1 | Turtle family base and meshes | `M_Species_Base_Turtle`, `RIG_Turtle`, `M_Species_Turtle_Juv`, `_Adult`, `_Juv_Tucked`, `_Adult_Tucked` | 24 | Agent + owner |
| S45-C1 | Two-thumb phone scheme; left-handed layout; handheld scale; TV margins | B41 (`InputController`), `client/UI/Kit` | M + M | Agent + owner |

Acceptance: the Turtle passes the roster sheet beside the three [MVP] species; the HUD mirrors correctly. Hours: 30 OH.

**Sprint 46 · 6–12 September 2027 · Sea Turtle 2**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S46-A1 | Fit, textures, clips | `M_Species_Turtle_*_LOD1, _LOD2`, `_Shell`, `_Crest`, (fit) Sea Turtle on `RIG_Turtle`, `T_Turtle_Juv_Alb`, `T_Turtle_Adult_Alb`, the 14 `A_Turtle_*` clips, `A_Turtle_ShellIn`, `_ShellHold`, `_ShellOut`, `_Fidget` | 29.7 | Agent + owner |
| S46-C1 | Shell ability; emote wheel, screen S06, with its nine `UI_Emote_*` images (4 WH) and the Hide emotes setting (08 §6.7) | B38 (Shell), B42 (`EmoteService`, emote wheel), `client/UI` | M + M | Agent |

Acceptance: a tucked Turtle cannot be eaten and cannot move for 2.5 seconds; playable behind `flag.turtle`. Hours: 31 OH.

**Sprint 47 · 13–19 September 2027 · Shark Pup**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S47-A1 | Shark Pup, cove-notice clips, voices | `M_Species_Shark_Juv`, `_Adult`, LOD, shell, crest, (fit) Shark Pup on `RIG_Fish`, `T_Shark_Juv_Alb`, `T_Shark_Adult_Alb`, (check) Fish clips on the Shark Pup, `A_Shark_RampageStart`, `A_Shark_Fidget`, `A_Fish_CoveNotice`, `A_Eel_CoveNotice`, the [L] voice rows of 07 §11.1 | 27.9 | Agent + owner |
| S47-C1 | Rampage ability; tier 2 start; the Shark Pup pass on its species card | B38, B37 | M + S | Agent |

Acceptance: eating 3 prey within 4 seconds gives +25% speed for 5 seconds and the validator allows it; playable behind a flag. Hours: 30 OH.

**Sprint 48 · 20–26 September 2027 · Spark, Camo, Ember, Bonefed**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S48-A1 | Four launch traits on Fish and Eel | `T_Trait_Spark_Fish_Emi`, `_Eel_Emi`, `T_Trait_Camo_Fish_Alb`, `_Eel_Alb`, `T_Trait_Ember_Fish_Emi`, `_Eel_Emi`, `T_Trait_Bonefed_Fish_Alb`, `_Eel_Alb`, `M_Trait_Camo_Leaf_01–02` | 16.6 | Agent + owner |
| S48-A2 | Launch trait prey | `M_Prey_SparkEel`, `M_Prey_LeafDrifter`, `M_Prey_VentSnail`, `M_Prey_Marrow_01–03`, (update) `T_TraitPrey_03_Alb` launch cells, `T_TraitPrey_04_Alb`, shells | 10.3 | Agent + owner |
| S48-C1 | Rules for the four traits | B38 | M + M | Agent |

Acceptance: Camo hides the outline after 1.5 seconds still; Ember ignores vents and stings; all behind flags. Hours: 30 OH.

**Sprint 49 · 27 September–3 October 2027 · Turtle overlays; patterns; wild creatures 1**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S49-A1 | All eleven overlay traits on the Turtle family; placement; the launch combination sheet | The eleven `T_Trait_*_Turtle_*` rows, (placement) Trait pieces on the Sea Turtle and on the Shark Pup, (check) Trait combination sheet, launch | 17.7 | Agent + owner |
| S49-A2 | One pattern for each of five species, with interface images (6 WH) | `T_Minnow_PatSunrise_*`, `T_Puffer_PatLemon_*`, `T_Eel_PatSeafoam_*`, `T_Turtle_PatMossback_*`, `T_Shark_PatStorm_*` (final choice by decision D5) | 16 | Agent + owner |
| S49-C1 | Patterns tab and ownership; wild creatures, first half | B37, B42 (wild creatures: `Dev/BotPlayers` promoted to a service) | M + L | Agent |

Acceptance: the combination sheet passes for every launch species; a pattern never changes silhouette or outline. Hours: 31 OH.

**Sprint 50 · 4–10 October 2027 · Grouper, anemone, lit vents; wild creatures 2**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S50-A1 | Grouper, anemones, vent glow, Old Scar's feeding clip, sounds and effects | `M_Pred_Grouper`, `RIG_Grouper`, `T_Grouper_Alb`, LOD and shell, the four `A_Grouper_*` clips, `M_Hazard_Anemone_01–03`, `T_Anemone_Alb`, `T_Vent_Emi`, `A_OldScar_Feed` | 26.5 | Agent + owner |
| S50-C1 | Grouper pull, anemone slow, vent burn; wild creatures labelled "wild" that fill servers under 10 players | B39, B42 (wild creatures) | M + L | Agent + owner |

Acceptance: a wild creature is always labelled and never appears on a leaderboard; the Grouper can be eaten by a player one tier higher and gives 60 mass (canon 5.2). Hours: 30 OH.

**Sprint 51 · 11–17 October 2027 · Whale Fall**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S51-A1 | The skeleton and its light | `M_Env_WhaleFall_Skull`, `_Ribcage`, `_Tail`, `T_WhaleFall_Alb`, `T_WhaleFall_Emi`, `T_Whale_Shadow_Mask`, (test) Whale Fall staging, `LGT_Event_WhaleFall` | 26.5 | Agent + owner |
| S51-C1 | The event: sinking, 60 Marrow chunks, `PredatorService.gather`, `flag.whaleFall` on the :45 slot | B39, B26 | L | Agent + owner |

Acceptance: a Whale Fall runs at :45 in GULP Staging; device row 1 holds 30 fps at the site with 12 players. Hours: 30 OH.

**Sprint 52 · 18–24 October 2027 · Cove visits, Bubbles, decorations**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S52-A1 | Bubble pieces, 20 decorations, the Drop-off launch pass, interface images (8 WH) | `M_Cove_BubbleCount`, `M_Cove_BubbleJar`, 20 rows of 07 §6.7 chosen by decision D5, (assembly) The Drop-off, launch pass | 37 | Agent + owner |
| S52-C1 | Cove visits and Bubbles with screen S21; decoration mode, screen S20 | B36, `CoveService` | L + L | Agent + owner |

Acceptance: a visitor enters only as a tier 1 Fry, takes nothing, and leaves one Bubble per cove per day; every decoration drop is saved. Hours: 32 OH.

**Sprint 53 · 25–31 October 2027 · Launch effects and sound; streak, Reef Rank, global boards**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S53-A1 | All [L] effects; half the [L] sounds; interface images for Daily, Ranks and Reef Rank (8 WH) | The [L] rows of 07 §9 and §11 | 36.5 | Agent + owner |
| S53-C1 | Login streak with screen S26; Reef Rank with screen S30; global leaderboards with screen S29 | B36 | M + M + M | Agent |

Acceptance: a missed day never takes a reward away (05 §14); Reef Rank counts base banking and scraps only; global boards refuse private-server banks with fewer than 4 players. Hours: 32 OH.

**Sprint 54 · 1–7 November 2027 · Remaining passes and products; launch import**

| ID | Task | Assets or module | WH | Who |
|---|---|---|---|---|
| S54-A1 | Remaining [L] sounds; licensed tracks for `MUS_Event_WhaleFall`, `MUS_Tier7`, `MUS_Sting_Leviathan`; launch import pass; shop and content icons (14 WH) | 07 §11, §12, (import) Studio import and fixes, launch | 35 | Agent + owner |
| S54-C1 | Tide Watcher, Keen Nose; Trait Lock, Call the Tide, Starter Pack with screen S34, Cove Boost, Goal Reroll; rewarded video behind `flag.rewardedVideo`; private servers with screen S32; notification string 2; awards for the nine [L] badges (03 §12), behind their flags; funnels 8 to 10 | B37, `Analytics` | L + L + M | Agent + owner |

Acceptance: every [L] purchase is tested once in GULP Staging and granted once; Call the Tide never interrupts a scheduled tide; rewarded video stays off unless the eligibility rule has been re-read and met. Hours: 32 OH.

### 6.4 Cut candidates, Sprints 55 to 60

Each block can be removed whole. Removing all four moves `P` from Thursday 20 January 2028 to Thursday 9 December 2027.

| Sprint | Dates | Block | Assets or module | WH | Decision | Acceptance if kept |
|---|---|---|---|---|---|---|
| 55 | 8–14 Nov 2027 | Squid 1 | `M_Species_Base_Squid`, `RIG_Squid`, `M_Species_Squid_Juv`, `_Adult`, LOD, shell, crest | 24.8 | D4 | Squid passes the roster sheet |
| 56 | 15–21 Nov | Squid 2 | (fit) Squid on `RIG_Squid`, `T_Squid_Juv_Alb`, `T_Squid_Adult_Alb`, the 14 `A_Squid_*` clips, `A_Squid_Jet`, `A_Squid_Fidget`; Jet ability (M) | 29 | D4 | Jet leaves an ink puff; 6-second cooldown |
| 57 | 22–28 Nov | Squid overlays; six more patterns; kit variants | The eleven `T_Trait_*_Squid_*` rows, placement on the Squid; six `T_*_Pat*` rows; the variants left out in section 3.2 and their assembly | 49 | D4, D5 | The Squid wears every trait; no zone sheet shows the same piece three times in one view |
| 58 | 29 Nov–5 Dec | Seven more patterns; 26 more decorations | The remaining `T_*_Pat*` rows; the remaining rows of 07 §6.7 | 45 | D5 | 18 patterns and 46 decorations, each priced in chapter 05 |
| 59 | 6–12 Dec | Original music 1; chat panel | `MUS_Theme`, `MUS_Nursery`; chat panel on `TextChatService` (B40, L) | 11 + 8 | D6, D7 | The first two minutes add the four `MUS_Nursery` stems one at a time |
| 60 | 13–19 Dec | Original music 2 | `MUS_Cove`, `MUS_Reef`, `MUS_Sting_Victory`, `MUS_Sting_Gulped` | 20 | D6 | The four tracks share one tune and one tempo (07 §12) |

Music is the one block where agents save little: if the owner composes, these 31 WH are about 31 OH. Composing every track in chapter 07 (94 WH) is not in this plan.

### 6.5 Launch preparation and launch, Sprints 61 to 65

These follow the marketing calendar of 11 §11 (`P−4` to `P`) and the runbook of 12 §2.7.

| Sprint | Dates | Tasks | Acceptance |
|---|---|---|---|
| 61 (`P−4`) | 20–26 Dec 2027 | Feature-freeze the launch build. Store art: `SCN_Icon_B_TeethFrame`, `SCN_Icon_C_FoodChain`, `SCN_Icon_E_MouthMark` (no text: the mouth shape alone, 11 §3.3), `SCN_Thumb_T7_PickYourCreature`, `SCN_Thumb_T8_WhaleFall`, (pose) Marketing pose set, launch (19 WH); the four public-launch versions, each a re-stage of its soft-launch scene: `SCN_Icon_A_BehindYou_Launch` (Old Scar, with its open-mouth pose, in the build since Sprint 40; 2.5), `SCN_Thumb_T3_GetHome_Launch` (Old Scar; 1.5), `SCN_Thumb_T4_SevenSizes` (tiers 1, 3, 5 and 7, with the Leviathan crest of Sprint 42; 1.5) and `SCN_Thumb_T5_YourCove_Launch` (specimens now include the Eel; 1) (6.5 WH, chapter 07 §13). Store art in this sprint: 25.5 WH. Start creator outreach to tiers 1 and 2: 45 messages over two weeks (11 §9.3). Four videos a week; tease Whale Fall. Gate G7b, first half. | Every [L] flag can be turned on in GULP Staging with no error |
| 62 (`P−3`) | 27 Dec 2027–2 Jan 2028 | One-week private test of the [L] content in GULP Staging (the entry criterion of 12 §1.1). Launch description drafted. Launch Week event created as private. Press kit: six screenshots, clean footage, fact sheet. | 10 sessions in a row with no severity 1 bug; no save loss; saves from the soft-launch schema load in the launch build |
| 63 (`P−2`) | 3–9 Jan 2028 | Fixes. Device rows 8, 9 and 10 (gaming PC, Chromebook, handheld or its stand-in). Pad on every screen. `SCN_Event_LaunchWeek`, (staging) Gameplay preview, launch re-cut (6 WH). Hand-read Spanish, Portuguese and one more language. Name check for the title. Creators get early access, disclosed in their videos. Redo the questionnaire if any answer changed. | 15 §3.3, §3.4 and §3.7 checklists pass; no English text on a device set to Spanish |
| 64 (`P−1`) | 10–16 Jan 2028 | Release candidate by Sunday 16 January (the T−48 h freeze is Tuesday 18 January). Create the public Launch Week event and submit it for featuring by Thursday 13 January (7 days ahead). Upload the public-launch set for moderation: T7, T8, the public-launch versions of icon A, T3, T4 and T5, and the new page cut. Create Tide Watcher, Keen Nose, Shark Pup, Trait Lock, Call the Tide, Cove Boost (`prod_cove_boost`), Goal Reroll (`prod_goal_reroll`), Starter Pack, the pattern products and the three Robux decorations at chapter 05 prices. Compliance lists of 05 §14 and 12 §7. Submit the paid step 3 campaign 48 hours ahead, only if both go/no-go measures are still at or above the median (11 §10.3). Gate G7b, second half. | The launch checklist of 12 §2 is ticked in full |
| 65 (`P`) | 17–23 Jan 2028 | **Public launch on Thursday 20 January 2028 at 15:00 UTC.** Snapshot, tag, publish, restart outdated servers with a 5-minute delay. Before the day: the freeze on Tue 18 January (T−48 h) and the two [L] badge batches of 12 §2.3 (batches 5 and 6, nine badges) on Tue 18 and Wed 19 January, `P−2` and `P−1` days. On the day: turn the [L] flags on. Name gains `[NEW 🦈]` for 7 days; launch description; T7 and T8 active; icon A (unless icon D won the soft-launch test), T3, T4 and T5 switch to their public-launch versions; private servers on at 99 Robux. Update announcement and community announcement. Watch for 2 hours; T+2 h check; T+24 h numbers. Paid step 3: 30 US dollars a day for 10 days. Video 19. | T+2 h check passes; every purchase completes; no save failure |

Hours in each of Sprints 61 to 64: 4 + 4 + 6 marketing + 16 build and checks = 30 OH. Sprint 65: 4 + 20 operations + 6 marketing = 30 OH.

**Risks from the go/no-go to launch.** The measured art ratio is worse than assumed and the 20 core sprints become 30 (re-date at gate G7a). Live operations take more than 4 OH a week because the soft-launch game grows (a good problem: move to the "double down" rules of 12 §9 and buy help). Sprints 61 and 62 fall on the year-end holidays. **Cut first, in order:** Sprints 59 and 60, Sprint 58, Sprints 55 to 57, then wild creatures, then decoration mode.

## 7. After launch

### 7.1 The first four weekly updates

Weeks are counted from `P`, as in 12 §3.3. A post-launch week has 30 OH: rhythm 4, live operations 10, marketing 5 (five videos a week), and **11 OH for the headline**.

That is less than chapter 12's calendar needs. The Anglerfish is 33 WH of art (07 §2.8), Storm about 25 WH with its preset and music, and the Manta Ray 64 WH because it needs a new body family. Together that is about 122 WH, or 63 OH, against 33 OH available in weeks 2 to 4. Chapter 12 estimates five working days per species and marks it as a guess. So one of two things must be true (decision D14):

- **Banked.** Three extra build sprints before launch preparation make the Anglerfish, Storm and the Manta Ray ahead of time. `P` moves three weeks later.
- **Keep steady from day one.** Each A week becomes two weeks, as 12 §3.3 allows. The Anglerfish ships in week 3, Storm in week 5 and the Manta Ray in week 8.

The four sprints below show chapter 12's calendar and, in the last column, the keep-steady version, which is the base case of this plan.

| Sprint | Dates | Week | Chapter 12 headline | Also in the update | Hours needed for the headline | Base case (keep steady) |
|---|---|---|---|---|---|---|
| 66 | 24–30 Jan 2028 | 1 | Hotfixes only. The Launch Week event runs all week. | Balance from launch data, each change naming the number behind it. Remove the title tag on Thursday 27 January. Read day-1 and day-7 retention of the launch cohort. Paid step 3 ends; read it. | None | The same. Spare hours start the Anglerfish: `M_Species_Anglerfish_*` (12 WH). |
| 67 | 31 Jan–6 Feb | 2 | **Anglerfish** (Lure) | Two Anglerfish patterns. Console checks begin if the hardware is in hand: device rows 11 and 12, the checklists of 15 §3.5 and §3.6. | 33 WH art + Lure (M) = about 18 OH | Fix update with one "you asked" item. Anglerfish continues: `T_Anglerfish_*`, (rig) Anglerfish, `A_Anglerfish_*` (15 WH). |
| 68 | 7–13 Feb | 3 | **Storm** tide, first run, Friday 15:00 UTC to Monday 15:00 UTC | Pattern set "Tempest". **Console switch on Thursday 10 February** if rows 11 and 12 pass (M13); page text gains "and on console". | (bundle) Storm 20 WH + `SKY_Storm` preset and a track = about 13 OH | **Anglerfish ships.** Storm art starts. |
| 69 | 14–20 Feb | 4 | **Manta Ray** (Glide) | New Reef Rank titles. Read thumbnail round 2. | 64 WH + Glide (M) = about 34 OH | Fix update; Storm continues and ships in week 5. Gate G8 is read at the Monday review of 21 February 2028. |

Acceptance for each of the four: published by Thursday 15:00 UTC or moved a week, never published late in the week (12 §3.1); the update note names the number behind every balance change; the weekly review of 10 §11 is written down; total time for the daily routine and the update stays under 45 hours a week (12 §9).

### 7.2 Quarter by quarter

Quarters are counted from `P` (12 §10). Dates are for `P` = Thursday 20 January 2028. The content is chapter 12's; the pace is "keep steady" unless gate G8 says "double down", in which case the left column of dates applies.

| Quarter | Dates | Species (canon order) | Events | Features | Other | At keep-steady pace |
|---|---|---|---|---|---|---|
| Q1, weeks 1 to 13 ([P1] is weeks 1 to 12 of it) | 20 Jan–19 Apr 2028 | Anglerfish, Manta Ray, Seahorse, Axolotl | Storm, Red Tide, Great Migration (week 12) | Pearlescent variants, first version | Console once the pad test passes; hand-check of three translations; rewarded video when eligible; browser play checked within a week of Roblox releasing it | Anglerfish, Storm, Manta Ray, Red Tide. Seahorse, Axolotl and Great Migration move to Q2. |
| Q2, weeks 14 to 26 ([P2] from here on) | 20 Apr–19 Jul 2028 | Orca Calf | The Trench Opens; Storm, Red Tide and Great Migration return; seasonal events | The Trench zone; trading specimens with the compliance work of 12 §7, C22 | Second round of Pearlescent variants; first reading of whether paid random items are worth their compliance cost (default: no) | Seahorse, Axolotl, Pearlescent variants, Great Migration. The Trench and trading move to Q3. |
| Q3, weeks 27 to 39 | 20 Jul–18 Oct 2028 | Narwhal | Seasonal events | Migration (prestige reset, new cove biome) | Decide whether to apply for standalone game apps | The Trench and The Trench Opens, Orca Calf, trading |
| Q4, weeks 40 to 52 | 19 Oct 2028–17 Jan 2029 | The next species, chosen by a community poll (needs a canon entry first) | The Homecoming anniversary event | A second cove biome | The year-two decision by 12 §9: continue, hold, or reuse the technology. The one VR review that 15 §3.8 promises twelve months after launch (January 2029). | Narwhal, Migration |

Order that must hold at either pace: Pearlescent variants before trading; trading before Migration; the Trench before the Orca Calf (12 §10).

## 8. Critical path and parallel work

### 8.1 Critical path

```text
Sprint 0 spikes ──go──► B01 scaffold ─► B03 ─► B04 data ─► B08 SwimModel ─► B10 ─► B11 input and movement
                                                                                        │
     pipeline tools ─► RIG_Fish ─► Minnow juvenile ────────────────────────────────────►│  M1 first swim (Sprint 2)
                                                                                        ▼
                      B06 codecs ─► B15 PreySim ─► B16 PreyService ─► B17 PreyRenderer ─► B18 bites
                                                                                        │  M2 first playable (Sprint 4)
                                                                                        ▼
                      B20 saves ─► B21 economy ─► B22 cove ─► B19 run loop ─► B31 TutorialDirector
                                                                                        │  M3 first two minutes, grey-box (Sprint 7)
                                                                                        ▼
   ART: Nursery ─► water and sky ─► cove ─► Barracuda ─► effects ─► interface art ─► sounds ─► first Reef pieces
                                                                                        │  M4 first two minutes, finished (Sprint 13)
                                                                                        ▼
   ART: Pufferfish ─► traits and prey ─► Reef ─► Kelp          CODE: B24, B25, B27, B26, B28, B35, B34 (has slack)
                                                                                        │  M5 slice feature-complete (Sprint 18)
                                                                                        ▼
        private test (2 weeks) ─► friends-and-family test (2 weeks) ─► moderation of icon and thumbnails (48 h)
                                                                                        │  M8 soft launch (Thu 1 Apr 2027)
                                                                                        ▼
        Roblox evaluation (2 to 4 weeks, 60-day window) ─► under-16s arrive ─► 100 daily users held 14 days
                                                                                        │  M10 go/no-go (Mon 21 Jun 2027)
                                                                                        ▼
   ART: Drop-off ─► Old Scar ─► Moray ─► traits ─► landmarks ─► Turtle ─► Shark Pup ─► launch traits ─► Grouper ─► Whale Fall
        ─► cove social ─► launch sound and effects ─► [cut candidates] ─► launch build private test (1 week)
        ─► Launch Week event submitted 7 days ahead                                     │  M12 public launch
                                                                                        ▼
        gamepad scheme tested on PC ─► real Xbox and PlayStation checks ─► M13 console switch
```

**From Sprint 5 onward the critical path is art, not code.** Art and audio are about 290 of the 690 OH to soft launch and every milestone after M3 waits on a finished asset. Code has slack in most sprints from 9 onward; that slack is what absorbs art overruns, and it is why code tasks for deferred systems can be done early behind flags at low cost.

**Waits that no amount of work shortens.**

| Wait | Length | Where |
|---|---|---|
| Image and video moderation | Up to 48 hours | Sprints 22, 31, 64 |
| Roblox evaluation in the trial phase | 250 highly engaged plays (docs) or 500 (staff post) within 60 days | Sprints 23 to 26 |
| 100 daily users held for 14 days | 14 days after the day it is reached | Sprints 32 to 34 |
| Day-7 retention of any cohort | 8 days | Every read |
| Ad review | About 24 to 48 hours | Sprints 23, 28, 64 |
| Featuring submission for an event | 7 days ahead | Sprint 64 |
| Roblox Plus, if chosen instead of the fee | 2 consecutive months before `S` | Decide in Sprint 0 (D12) |
| Free badges | 5 a day | Sprints 22 and 23 (four [MVP] batches), Sprint 65 (two [L] batches) |
| Video thumbnail uploads | 3 a month, rejections count | Sprints 31, 64 |
| A staging soak before a release with a save migration | 24 hours | Any release that changes the schema |

### 8.2 What can run in parallel

| Stream | Can run beside | Limit |
|---|---|---|
| Headless code agents on disjoint folders (`shared/Sim`, `shared/Logic`, `server/Services`, `client/Controllers`, `client/UI`, `tools`, `tests`) | Each other, and any art work | Up to 20; one module row each |
| Blender builds of different assets | Code agents; one Studio session | One Blender job with Studio open, two with Studio closed |
| Studio play tests through MCP | Headless agents; one Blender job | One agent holds `.locks/studio` |
| Reviewer agents on contact sheets or diffs | Everything | Read-only |
| Interface art and screen code for the same screen | Each other (code uses flat shapes with final names) | — |
| Sound sourcing | Everything | Owner's ears only |
| Store art | Any build work after the creatures it shows are final | Blender slot |
| Zone kit meshes for two zones | Each other | Blender slot |
| Zone assembly | Not beside a play test in the same place | One Studio session |
| Device tests | Agents working headless | The owner's attention |
| Code for [L] systems behind flags | Deferred [MVP] art | — |
| Marketing videos, community posts, dashboard settings | Any agent work | Owner's time |

Not parallel: two tasks that edit the same module; the content generator and anything that edits `Data/Generated`; a multi-client test and Blender; publishing and anything else.

## 9. Decision gates

| Gate | When (base case) | What is looked at | Pass | Near miss | Fail |
|---|---|---|---|---|---|
| **G0 Spike** | Fri 23 Oct 2026 | The pass or fail of spikes S1 to S18 and the six art spikes | Go: Sprint 1 as planned | Change: apply the fallback rows in Sprint 0; add the sprints they name; re-date | Stop: two or more of S1, S2, S6, S8 fail with no fallback that holds 30 fps on device row 1 |
| **G1 Capacity** | Fri 6 Nov 2026 | Measured OH per WH for code and for art over Sprints 0 to 2; OH actually worked per week | Code at or under 0.35 and art at or under 0.60: keep the plan | Art between 0.60 and 0.80, or hours between 20 and 26 a week: re-date; drop the two Kelp landmarks, Spiny and `SCN_Thumb_T5_YourCove`; tell the owner the new `S` date | Art above 0.80 or under 20 hours a week: `S` is past June 2027. The owner chooses one: raise hours, pay an artist (D2), cut to Nursery and Reef only, or stop. |
| **G2 First two minutes** | Fri 22 Jan 2027 | Eight new players on a fresh account, finished art | 7 of 8 bite within 10 s; 6 of 8 reach tier 2 within 45 s; 5 of 8 bank within T = 120; 4 of 8 start run 2 and are playing at 10 minutes | One measure misses by one player: Sprint 14 becomes a fix sprint; re-test with 5 new players; later dates move one week | Fewer than 4 of 8 bank at all, or fewer than 4 are playing at 3 minutes: stop building breadth; two sprints of redesign on chapter 04; a second fail is stop condition 2 |
| **G3 Friends-and-family exit** | Sun 28 Mar 2027 | 30 or more first-time players; the 01 §17 funnel; two 12-player sessions; saves | Every canon measure within 10 points of its target; no save loss | One or two measures 10 to 20 points under: extend the stage two weeks, fix the weakest step, `S` moves to Thu 15 Apr 2027 | Still playing at 60 seconds under 60%, or first bank under 40%: no soft launch. Back to gate G2's fail path. |
| **G4 Launch day** | Thu 1 Apr 2027, T+2 h | Player-facing errors, save failures, purchases | Fewer than 1 in 200 sessions with an error; no save failure; purchases complete | One feature broken: turn it off with its switch; fix in the next update | Saves damaged or the first minute broken: rollback plan of 12 §2.8; revoke public access if it cannot be made safe quickly |
| **G5 Evaluation** | Sat 1 May 2027 (`S` + 30 days, in Sprint 27; read at that day's routine check and acted on at the Monday review of 3 May) | Highly engaged plays on the Audience Reach dashboard against the live threshold | Evaluation passed | Above half the threshold: continue; Engagement ads up to the 300 US dollars in 12 §11 | Below half the threshold: it is a retention problem. Fix the first session; buy no more traffic. If the 60-day window closes on Mon 31 May 2027 without a pass, stop condition 5. |
| **G6 Daily users** | Mon 31 May 2027 | Daily users over the last 7 days; cost per play; ad players' day-1 retention against organic | 100 or more on each of 7 days: the level is held through Sprint 32, the week in which the economy is frozen, and the 14-day read window then runs from Mon 7 Jun to Sun 20 Jun 2027 (Sprints 33 and 34), so gate G7 is read on Mon 21 Jun | 50 to 100: paid step 2 continues to its 140 US dollar limit; the go/no-go moves by the weeks lost | Under 50 after step 2 is spent, or cost per play above twice step 1: no benchmark can be read. One four-week cycle on the store page and first session, then stop condition 6. |
| **G7 Go/no-go** | Mon 21 Jun 2027 | 7-day averages of day-1 retention and average session time against the similar-game median, organic players deciding (12 §1.5) | Both at or above the 50th percentile: **go**. Section 6 starts. | One or both below: **not yet**. One four-week cycle on numbers 1 to 5 of 10 §11, then read again (Mon 19 Jul). A second cycle at most (Mon 16 Aug). The Drop-off may start in the second cycle only. | Below the median after two extra cycles, or at the 20-week limit (Thu 19 Aug 2027): **no-go**. Maintenance as 12 §9 defines it. Stop condition 7. |
| **G7a Launch scope** | Mon 16 Aug 2027 | Day-7 retention and session time with the full [MVP] live; measured ratios; earnings to date | Ratios hold: keep the dates | Art ratio 20% worse than planned: remove cut candidates in the order of section 6.5 until `P` is before 1 March 2028 | `P` would be after 1 June 2028 even with every cut candidate removed: launch with five species and no decorations, or pay for help if gate G8's "double down" row would apply |
| **G7b Launch readiness** | Mon 20 Dec 2027 and Mon 10 Jan 2028 | The private test of [L] content; the launch checklist of 12 §2; both go/no-go measures during the build | Checklist ticked; measures at or above the median: launch on the date, with paid step 3 | A severity 2 bug open, or one device row not checked: `P` moves one week | Either measure fell below the median for 4 weeks: no paid traffic and no featuring request; launch quietly or hold and fix |
| **G8 `P` + 4 weeks** | Mon 21 Feb 2028 (the Monday review after Sprint 69, the last planned sprint) | The table of 12 §9 | Double down: both measures at or above the 75th percentile and daily users rising in 3 of 4 weeks. Run the 12-week calendar at full pace; ads up to 300 US dollars a month. | Keep steady: a headline every two weeks; no ads | Stop: either measure below the 50th for 4 weeks after two extra cycles, or daily users under 100 for 4 weeks. Maintenance. |
| **G9 Console** | Thu 10 Feb 2028 | Device rows 11 and 12 on real hardware; the checklists of 15 §3.5 and §3.6 | Every line passes: Console switch on | A line fails: fix and re-test the next week | No hardware: the switch stays off (decision D8) |
| **G10 `P` + 12 weeks** | Mon 17 Apr 2028 (a Monday review; no sprint is planned this far ahead) | The table of 12 §9 again; Earned Robux per month | As G8 | As G8 | Under 30,000 Earned Robux a month for 3 months: maintenance |

One rule applies between gates: if the daily routine and the weekly update together take more than 45 hours a week for four weeks, drop to the keep-steady pace whatever the numbers say (12 §9).

## 10. Tracking

### 10.1 Issues, labels and milestones

Tasks are GitHub issues in the game's repository.

| Thing | Convention |
|---|---|
| Issue title | The task ID and a short name: `S7-C1 Scripted Barracuda chase` |
| Issue body | Bible reference; module or asset names; acceptance checks copied from the sprint; files it may touch; WH estimate. Nothing else. |
| Milestone | One per sprint: `Sprint 07 (7–13 Dec 2026)`, due on the Friday. The milestone description holds the goal, the demo and the Friday review. |
| Labels: sprint | `sprint:00` to `sprint:69` |
| Labels: scope | `scope:slice`, `scope:topup`, `scope:MVP`, `scope:L`, `scope:P1`, `scope:P2` |
| Labels: type | `type:code`, `type:art`, `type:audio`, `type:design`, `type:test`, `type:ops`, `type:marketing` |
| Labels: size | `size:S`, `size:M`, `size:L`, `size:XL` |
| Labels: who | `who:agent`, `who:agent+owner`, `who:owner` |
| Labels: state | `blocked`, `float`, `cut-candidate`, `carried-over`, `bug:sev1` to `bug:sev4` |
| Branch and commit | Branch `s7-c1-barracuda-chase`; commits start with the task ID; one pull request per task; CI must be green |
| Art status | `manifest.csv` holds the status of every asset row (07 §1.5). The issue closes when the row is final. |
| Decisions | One issue per open decision in chapter 14, labelled `decision`, with the date it blocks work |
| Actuals | On closing, a comment with OH spent. A script sums WH and OH per sprint into the burn-down. |

Issues for Sprints 0 to 3 are created in Sprint 0. After that, the next two sprints' issues are created each Friday from this chapter, so the plan is corrected before it becomes issues.

### 10.2 Burn-down template

One row per sprint in `docs/burndown.md`, filled in on Friday.

| Sprint | Dates | OH planned | OH worked | Tasks planned | Tasks done | Carried over | Code WH done | Code OH | Code ratio | Art WH done | Art OH | Art ratio | Slice WH remaining (of 610) | Projected `S` date | Acceptance ticked | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | 19–25 Oct 2026 | 30 | | 23 | | | — | | — | 18 | | | 592 | Thu 1 Apr 2027 | 0 of 6 | |
| 1 | 26 Oct–1 Nov 2026 | 30 | | 15 | | | 31 | | | 55 | | | 537 | | 0 of 6 | |
| 2 | 2–8 Nov 2026 | 31 | | 13 | | | 48 | | | 15 | | | 522 | | 0 of 5 | |

How the projection is made: `weeks left = (slice art WH remaining × art ratio + slice code WH remaining × code ratio + other OH remaining) ÷ (OH worked per week, 3-sprint average − 4)`. The projected `S` date is the Thursday after that many weeks. If it moves by more than two weeks in one sprint, the owner looks at the next gate early.

A second table tracks the product once live, one row per Monday review, with the 14 numbers of 10 §11 and the previous four weeks beside them.

