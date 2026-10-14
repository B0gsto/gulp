# 01 · Game canon

This file is the single source of truth for GULP. Every other document in `docs/` expands one part of it. If another document disagrees with this one, this one wins until it is changed here first.

Numbers marked **(tune)** are starting values that we expect to adjust from playtest data. Document 05 owns all prices and balance tables; where it differs from the anchors below, document 05 wins and this file gets updated.

## 1. Identity

| | |
|---|---|
| **Name** | **GULP** |
| **Store title** | `GULP 🐟 Eat. Grow. Get Home.` |
| **Tagline** | Eat. Grow. Get home. |
| **One-line pitch** | You are a tiny sea creature: eat what is smaller, flee what is bigger, become what you eat, and get home before something gulps you. |
| **Platform** | Roblox (phone first, then PC, tablet, console) |
| **Genre** | Eat-and-grow arena with a collection and an idle home base |
| **Players per server** | 24 |
| **Audience** | Core 9 to 16, phone players, short sessions. Secondary 17+. |
| **Content rating target** | The lowest Roblox maturity label that fits (expected: Mild, to be confirmed by the questionnaire). No blood, no gore, no realistic violence. Creatures are swallowed whole and pop into bubbles. |
| **Run length** | 3 to 8 minutes typical, 20 minutes for a full Leviathan run |
| **Session target** | 15 to 25 minutes |

**Why the name:** one syllable, a sound effect and a verb at once ("I got gulped", "gulp it"), readable at icon size, and easy for a nine-year-old to say and spell. A web check on 13 October 2026 found no Roblox, Steam or mobile game using it (only a 2019 board game and a 1982 ZX81 game).

**The player is never a Roblox avatar.** The avatar is not loaded, not shown in the world, and not shown in the interface. The player's identity is their creature and their cove.

## 2. Design pillars

Every feature must serve at least one pillar. A feature that serves none is cut.

1. **Eating in five seconds.** A new player bites something within five seconds of the game loading and is visibly bigger within thirty.
2. **You are what you eat.** Traits come from prey, appear on your body, and change how you play. Nothing important comes from a random egg.
3. **Home is safe, open water is not.** Every run is a choice between swimming home to keep what you have and staying out for more.
4. **The cove is your trophy shelf.** What you bank lives in your cove, earns while you are away, and is on show to visitors.
5. **The sea runs on a clock.** Tide events happen at fixed real-world times on every server, so players know when to come back.
6. **Readable at a glance on a phone.** A player can tell what is food and what is danger from colour and silhouette alone, with no text.

## 3. What GULP is not

- Not a base-stealing game. Players cannot take anything from another player's cove.
- Not a meme-character game. No brainrot characters, no licensed characters.
- Not a loot-box game at launch. No paid random items until after public launch, and only if the data supports it.
- Not a roleplay sim. It needs no text chat to be fun.
- Not a Roblox-looking game. No avatars, no default interface, no studs, no default sounds.

## 4. The loops

### 4.1 Second-to-second (the bite loop)

Steer → line up prey → dash → bite (automatic on contact) → grow → look for the next bite while watching for anything bigger.

### 4.2 Minute-to-minute (the run loop)

1. Leave your cove as a tier 1 Fry.
2. Eat prey, grow through seven size tiers.
3. Eat five of the same trait prey to gain that trait (up to three traits).
4. Decide: swim home and **bank**, or push into a richer, more dangerous zone.
5. The run ends when you bank (keep everything) or get gulped (lose the creature, keep a small consolation).

### 4.3 Day-to-day (the cove loop)

1. Banked creatures become **specimens** in your cove and earn Pearls every hour, including while you are offline (capped).
2. Spend Pearls on new species, more cove slots and decorations.
3. Fill the **Codex** by discovering species, tiers and traits.
4. Return for daily goals, the login streak and the next tide event.

### 4.4 Week-to-week

New species, new traits, new tide events and limited-time tides on a fixed update cadence (document 12).

## 5. Core rules

### 5.1 Size tiers

Mass is the in-run size number. It resets every run.

<!-- data:Tiers -->
Soft-launch slice (chapter 13, section 3.2): every row.

| Tier | Name | Mass needed | Body scale | Swim speed (studs/s) | Turn rate (°/s) |
|---|---|---|---|---|---|
| 1 | Fry | 0 | 1.0 | 26 | 360 |
| 2 | Nibbler | 10 | 1.3 | 28 | 320 |
| 3 | Snapper | 30 | 1.7 | 30 | 280 |
| 4 | Hunter | 80 | 2.3 | 32 | 240 |
| 5 | Brute | 200 | 3.2 | 34 | 200 |
| 6 | Titan | 500 | 4.5 | 36 | 170 |
| 7 | Leviathan | 1,200 | 6.5 | 38 | 140 |

<!-- /data -->

All values **(tune)**. Bigger creatures are faster in a straight line and worse at turning, so a small creature escapes by turning.

Tier is derived from mass, so it can fall if mass is lost (hook, vent, revive). Body scale grows smoothly with mass between the tier values, so every bite makes the creature slightly bigger; speed and turn rate change only at a tier step. A Leviathan also grows a crest, so the top tier is recognisable by silhouette.

Target time to reach each tier for an average player: tier 2 in 30 seconds, tier 3 in 2 minutes, tier 4 in 4 minutes, tier 5 in 7 minutes, tier 6 in 12 minutes, tier 7 in 20 minutes.

### 5.2 Who can eat whom

- Every creature, prey item and predator has a tier.
- **You can eat prey of your tier or lower.**
- **A player can eat another player only if they are at least one full tier higher.** Same-tier players bump off each other harmlessly.
- **Tier 1 players cannot be eaten by players**, only by computer-controlled predators.
- **A new player cannot be eaten by anything before their first bank** (for up to 240 seconds), and the first bite a player ever takes from another player is absorbed once (chapter 04).
- Nobody can be eaten inside the Nursery or inside any cove. Creatures of tier 3 or higher cannot enter the Nursery.
- A player one tier higher can eat a Barracuda or a Grouper. Eating a Barracuda gives 25 mass and eating a Grouper gives 60 mass, the same as prey of their tier **(tune)**. Old Scar, the Gull and the Moray cannot be eaten.
- Eating a player gives the eater 30% of the victim's mass **(tune)**.
- Colour language, always on: **green outline = you can eat it, red outline = it can eat you (it pulses), no outline = neither.** Plankton and hook bait have no outline. Amber is reserved for "home" (your cove and the marker pointing to it). A colour-blind mode swaps green and red for yellow and hot pink. Outlines are drawn as mesh shells, not with Roblox's Highlight effect, which is unreliable on phones.

### 5.3 Dash and bite

- Biting is automatic when prey touches the mouth zone at the front of the creature.
- Dash: a burst of 2.2× speed for 0.35 seconds, 2.5 second cooldown measured from the start of the dash **(tune)**.
- Each species has one signature ability (section 7).

### 5.4 Banking

- Swim into your own cove mouth to bank. Banking happens at once, with no confirmation. Once inside you are safe.
- Banking converts the run into Pearls, plus a **specimen** if you reached tier 2 or higher and have a free cove slot.
- Pearls from banking **(tune)**: 3 per mass up to 1,200 mass, 1 per mass from 1,200 to 3,000, nothing above 3,000 (the table below is the authority). The limit exists because a Leviathan is very hard to eat.
- A specimen stores species, tier, final mass, up to three traits, and the date.
- If the cove is full, the player chooses a specimen to release (for a small Pearl refund) or releases the new one.

<!-- data:BankRates -->
Soft-launch slice (chapter 13, section 3.2): every row.

| Mass from | Mass up to | Pearls per mass |
|---|---|---|
| 0 | 1,200 | 3 |
| 1,200 | 3,000 | 1 |
| 3,000 | No limit | 0 |

<!-- /data -->

Each band pays its rate for the mass inside it, and the bands add up: 2,000 mass pays 3 × 1,200 + 1 × 800 = 4,400 Pearls (chapter 05, section 3.1).

### 5.5 Getting gulped

- The creature and its unbanked traits are lost.
- The player receives 10% of the Pearls they would have banked ("scraps") **(tune)**. For the first three deaths on an account this is 50% (the table at the end of this section is the authority).
- One revive per run: paid, or by watching a rewarded video where eligible. A revive returns the creature with its traits at 70% mass and 3 seconds of protection. The offer has no countdown timer, is not shown on an account's first death, and appears only when the lost creature had 30 mass or more (tier 3).
- Respawn as a Fry at the cove in under 3 seconds. Only a new player's very first run starts in the Nursery; every later run starts at the cove.
- **Disconnecting mid-run:** the creature stays in the water and can be eaten for 10 seconds, then the run is saved as suspended for 5 minutes. Rejoining in that time resumes it; after that it is lost with scraps paid.

<!-- data:Scraps -->
Soft-launch slice (chapter 13, section 3.2): every row.

| Death on the account | Scraps (share of the Pearls the run would have banked) |
|---|---|
| 1st to 3rd | 50% |
| 4th and later | 10% |

<!-- /data -->

### 5.6 Controls principle

- **Phone (default, "drag to swim"):** one thumb. Touch and drag anywhere: the creature swims in the dragged direction (screen up = up, screen left/right = turn). Release to coast to a stop. A dash button and an ability button sit under the right thumb. The camera follows on its own.
- **PC (default, "free cursor"):** the mouse is never locked. The cursor's distance left or right of screen centre turns the creature; Space swims up, Shift swims down. W swims forward, S brakes, A/D strafe, Q or the left mouse button dashes, E or the right mouse button uses the ability. The camera follows on its own. Locked mouse look (swim where you look) is in settings.
- **Gamepad:** left stick swims, right stick looks, A dashes, X uses the ability.
- An optional two-thumb phone scheme (move stick plus look drag) is in settings.

## 6. The world

One shared map per server: a disc of water with a radius of about 1,000 studs and up to 600 studs deep **(tune)**. The Sunlit Reef is a basin in the centre, ringed by a wall of rock (the Rim) that holds all 24 coves. The sea surface is at height 0 and is a custom surface, not Roblox Terrain water. Chapter 03 has the map with coordinates.

<!-- data:Zones -->
Soft-launch slice (chapter 13, section 3.2): `nursery`, `reef`, `kelp`, `cove`.

| ID | Zone | Where | Prey tiers | Danger | Purpose | Tag | Lighting preset (chapter 06, section 10.2) |
|---|---|---|---|---|---|---|---|
| `nursery` | **Nursery Lagoon** | Sheltered pool beside the reef | 0 to 1 | None. No player can be eaten here. | First two minutes for new players; safe start for every Fry | [MVP] | Nursery Lagoon |
| `reef` | **Sunlit Reef** | Shallow centre, bright | 0 to 3 | Gulls at the surface, a Barracuda on the east side away from cove mouths | Early growth, common traits | [MVP] | Sunlit Reef |
| `kelp` | **Kelp Forest** | West and north ring, dim green | 1 to 4 | Morays in holes, jelly blooms | Mid growth, uncommon traits, hiding places | [MVP] | Kelp Forest |
| `dropoff` | **The Drop-off** | East and south wall into deep water, dark | 3 to 6 | Groupers, vents, Old Scar | Late growth, rare and epic traits, Whale Fall site | [MVP] | Drop-off, upper; blends to Drop-off, deep from 150 to 300 studs down (chapter 06, section 10.3) |
| `trench` | **The Trench** | Below the Drop-off | 5 to 6 | Everything | Opens only during a tide event. [P2] | [P2] | The Trench |
| `cove` | **Coves** | 24 cave mouths around the reef rim, one per player | None | None | Banking, specimens, visitors | [MVP] | Cove interior |

<!-- /data -->

The surface is playable: creatures can breach and splash. Gulls dive on tier 1 and 2 creatures that linger at the surface in the Sunlit Reef.

Each cove mouth shows the owner's name and their best specimen. Entering your own banks the run. You can enter someone else's cove only as a tier 1 Fry (so coves cannot be used as safe rooms mid-run); inside you can look and leave one **Bubble** (a like) per cove per day.

There is no tier 7 prey. A Titan becomes a Leviathan by eating Tuna, other players and Marrow.

## 7. Playable species

Six at launch. Each is one rig with a juvenile mesh (tiers 1 to 3) and an adult mesh (tiers 4 to 7).

| ID | Species | Unlock (Pearls, **tune**) | Feel | Signature ability |
|---|---|---|---|---|
| `minnow` | **Minnow** (starter) | Free | Balanced | **Dart:** dash cooldown is 2.0 s instead of 2.5 s |
| `puffer` | **Pufferfish** | 500 | Slow, safe | **Puff:** inflate for 2 s; counts as one tier higher for defence, 60% slower. 10 s cooldown |
| `eel` | **Eel** | 3,500 | Fast, thin, tight turns | **Slip:** can pass through eel holes (shortcuts only eels fit); dash is 30% longer |
| `turtle` | **Sea Turtle** | 12,000 | Slow, tanky | **Shell:** tuck in for 2.5 s; cannot be eaten, cannot move. 14 s cooldown |
| `squid` | **Squid** | 45,000 | Bursty, poor turning | **Jet:** fast backwards jet that leaves a small ink puff. 6 s cooldown |
| `shark` | **Shark Pup** | 250,000, or a game pass | Aggressive | **Rampage:** eating 3 prey within 4 s gives +25% speed for 5 s; starts each run at tier 2 |

The Shark Pup's tier 2 start is also its drawback: it never has the tier 1 protection from other players.

Dart, Slip and Rampage are passive: nothing to press. Those species show a passive badge where the ability button would be. Puff, Shell and Jet are pressed. The Shark Pup's ability is called Rampage (ID `rampage`) so it is never confused with the Feeding Frenzy event (ID `frenzy`).

Unlock pacing targets: Pufferfish by the end of the first session, Eel on day 2, Sea Turtle on day 4 or 5, Squid around day 10, Shark Pup around day 30 for a non-paying daily player.

Post-launch species, in planned order: Anglerfish (Lure), Manta Ray (Glide), Seahorse, Axolotl (Regrow), Orca Calf, Narwhal.

## 8. Computer-controlled creatures

### 8.1 Prey

| ID | Prey | Tier | Mass | Where | Behaviour |
|---|---|---|---|---|---|
| `plankton` | Plankton mote | 0 | 0.2 | Everywhere | Drifts |
| `krill` | Krill | 1 | 1 | Nursery, Reef | Swarms of 12 to 20, scatter when approached |
| `shrimp` | Tiny Shrimp | 1 | 1.5 | Reef floor, Kelp floor | Hops along the bottom |
| `sardine` | Sardine | 2 | 4 | Reef, Kelp | Tight schools of 8 to 14, flee as a group |
| `darter` | Reef Darter | 3 | 10 | Reef, Kelp | Solo or pairs, quick turns |
| `mackerel` | Mackerel | 4 | 25 | Kelp, Drop-off | Fast, straight-line runs |
| `bonito` | Bonito | 5 | 60 | Drop-off | Fast packs of 3 to 5 |
| `tuna` | Tuna | 6 | 150 | Drop-off (rare) | Very fast, flees early |

### 8.2 Trait prey

Eat five of the same trait prey in one run to gain that trait.

| ID | Trait prey | Tier | Gives trait | Where |
|---|---|---|---|---|
| `glowfry` | Glowfry | 1 | Glow | Reef caves, Kelp; five scripted ones in the Nursery during a new player's first run only |
| `zebra_darter` | Zebra Darter | 2 | Stripes | Reef |
| `dotted_goby` | Dotted Goby | 1 | Spots | Reef sand |
| `armor_shrimp` | Armor Shrimp | 2 | Plated | Kelp floor |
| `urchin_puff` | Urchin Puff | 2 | Spiny | Reef crevices |
| `ribbonfish` | Ribbonfish | 3 | Longfin | Kelp canopy |
| `inklet` | Inklet | 3 | Ink | Drop-off |
| `spark_eel` | Spark Eel | 4 | Spark | Drop-off wreck |
| `leaf_drifter` | Leaf Drifter | 3 | Camo | Kelp |
| `crystal_jelly` | Crystal Jelly | 3 | Crystal | Roams the Reef, Kelp and Drop-off as a drift of five, about one drift per server every 5 minutes |
| `vent_snail` | Vent Snail | 4 | Ember | Drop-off vents |
| `lunar_fry` | Lunar Fry | 2 | Moonlit | Moon Tide event only |
| `marrow` | Marrow chunk | 3 | Bonefed | Whale Fall event only |

### 8.3 Predators and hazards

| ID | Name | Tier | Where | Behaviour |
|---|---|---|---|---|
| `gull` | Gull | Acts as tier 3 (chapter 02, section 9.4); eats tiers 1 to 2 | Reef surface | Shadow appears, then dives after 1.5 s |
| `moray` | Moray | 4 | Kelp holes | Lunges from a hole when a creature of tier 3 or lower passes |
| `barracuda` | Barracuda | 4 | Reef edge, Kelp | Patrols, chases in straight lines, gives up after 6 s |
| `grouper` | Grouper | 5 | Drop-off | Slow; sucks nearby smaller creatures toward its mouth |
| `old_scar` | Old Scar (great white) | 7 | Drop-off | One per server. Roams. Eats tier 6 and below. |
| `jelly_bloom` | Jelly bloom | Hazard | Kelp, Drop-off | Touch stuns for 1.5 s |
| `anemone` | Anemone | Hazard | Reef | Touch slows by 50% for 2 s |
| `vent` | Thermal vent | Hazard | Drop-off | Burns 5% of mass per second while inside |
| `hook` | Fishing hook | Hazard | Reef, near the surface | Eating the bait yanks you up: lose 20% of mass. Played for laughs. |
| `current` | Current | Helper | Between zones | A visible stream that carries creatures at +60% speed |

## 9. Traits

A creature holds up to three traits. When all three slots are full, trait prey gives only mass until the player sheds a trait by tapping its slot and then holding for 0.6 seconds.

| ID | Trait | Rarity | Look | Effect during a run |
|---|---|---|---|---|
| `glow` | Glow | Common | Soft light along the body | Trait prey within 60 studs show as edge markers |
| `stripes` | Stripes | Common | Bold bands | +8% swim speed |
| `spots` | Spots | Common | Large dots | +10% mass from all prey (not from eating players) |
| `plated` | Plated | Uncommon | Armour plates | Survive one bite per run; plates crack |
| `spiny` | Spiny | Uncommon | Spines | A predator needs to be two tiers higher to eat you |
| `longfin` | Longfin | Uncommon | Long trailing fins | Dash travels 30% further |
| `ink` | Ink | Rare | Dark mottling | Dash leaves a 3 s ink cloud that hides you |
| `spark` | Spark | Rare | Crackling lines | Dash stuns prey of your tier or lower within 12 studs for 1.5 s |
| `camo` | Camo | Rare | Leafy frills | Hold still 1.5 s to turn see-through with no outline |
| `crystal` | Crystal | Epic | Faceted, gem-like | ×1.5 Pearls when this run is banked |
| `ember` | Ember | Epic | Glowing cracks | Immune to vents and jelly stings |
| `moonlit` | Moonlit | Mythic | Silver glow | Prey within 40 studs drifts slowly toward you |
| `bonefed` | Bonefed | Mythic | Skeleton markings | +25% mass from everything |

**Cove income bonus by rarity (added together across a specimen's traits):** Common +10%, Uncommon +20%, Rare +35%, Epic +60%, Mythic +100% **(tune)**.

## 10. Tide events

- An event starts every 15 minutes on the real-world quarter hour (UTC), on every server at once.
- Each lasts 4 minutes, with a 60-second warning.
- The rotation is fixed so players can learn it: **:00 Feeding Frenzy, :15 Moon Tide, :30 Feeding Frenzy, :45 Whale Fall.**

<!-- data:Tides -->
Soft-launch slice (chapter 13, section 3.2): `frenzy`.

| ID | Event | What happens | Reward | Tag | Prey spawn rate | Fallback | Event prey |
|---|---|---|---|---|---|---|---|
| `frenzy` | Feeding Frenzy | Prey spawns at three times the normal rate everywhere | Fast growth | [MVP] | ×3 | None | None |
| `moon_tide` | Moon Tide | The sea goes dark and glows; Lunar Fry appear | Moonlit trait | [MVP] | ×1 **(tune)** | `frenzy` | `lunar_fry` |
| `whale_fall` | Whale Fall | A clean whale skeleton sinks into the Drop-off; Marrow chunks; Old Scar and Groupers gather | Bonefed trait, huge mass | [L] | ×1 **(tune)** | `moon_tide` | `marrow` |

<!-- /data -->

Until Whale Fall ships at launch, the :45 slot in the MVP runs a second Moon Tide. The soft-launch slice has no Moon Tide (chapter 13, section 3.2), so there `moon_tide` falls back to `frenzy` and all four slots run a Feeding Frenzy; the fallback is never used in the MVP build, where Moon Tide is in. After launch, the :30 slot is the flexible one: limited-time and new tides replace its Feeding Frenzy.

A purchased Call the Tide never interrupts a scheduled tide: it can always be bought, is held as a token (up to three per player), and starts after a 10-second warning when no tide is running. If several players hold tokens, they start one at a time in the order they were bought.

Post-launch events: Storm, Red Tide, Great Migration [P1]; The Trench Opens [P2].

## 11. Currencies and progression

| Thing | What it is | Earned by | Spent on |
|---|---|---|---|
| **Mass** | In-run size | Eating | Nothing; converts to Pearls on banking |
| **Pearls** | The only persistent currency | Banking, cove income, daily goals, streak | Species, cove slots, decorations |
| **Bubbles** | Likes on a cove | Visitors | Nothing; shown on the cove and a leaderboard |

There is no premium currency. Robux purchases are made directly.

**Cove income (tune):** income is claimed by tapping the pile in the cove (or the welcome-back card), never automatically. The one exception is a new player's first specimen, which pays one hour of income by itself as a first-bank reward (chapter 04). A specimen earns 6 / 10 / 18 / 30 / 50 / 80 Pearls per hour at tiers 2 to 7, multiplied by its trait bonus. Income collects in one pile that stops growing after 8 hours unclaimed, online or offline.

**Cove slots:** 6 at the start, up to 30 with Pearls, 40 with the Bigger Cove pass.

**Reef Rank counts only base banking and scraps**, before any pass multiplier, so it cannot be bought.

**Meta progression:**
- **Codex:** every species, every tier reached per species, every trait, every prey eaten [MVP]; plus Dangers, Places and Tides [L]. Chapter 03 has the full list.
- **Reef Rank:** account level 1 to 50 from lifetime Pearls banked. Unlocks titles and cove decorations.
- **Daily goals:** three per day: one Easy, one Medium, one Hard. The one allowed exception is an account's first day, which always uses the fixed set `dg_eat_50`, `dg_tier3` and `dg_bank_snapper` (Easy, Easy, Medium; chapters 03 and 04).
- **Login streak:** a 7-day calendar. Each day played opens the next box. A missed day never resets it; the next box simply waits. Rewards are Pearls only (chapter 05).
- **Leaderboards:** biggest creature on this server right now; global weekly biggest banked creature; global most Bubbles.

Post-launch: trading specimens, Pearlescent (shiny) variants, and Migration (a prestige reset for a permanent bonus and a new cove biome).

## 12. How it makes money

Direct Robux purchases only. Prices are anchors **(tune)**; document 05 owns them.

| Type | Item | What it does | Anchor price (Robux) |
|---|---|---|---|
| Game pass | Deep Pockets | ×2 Pearls from banking | 299 |
| Game pass | Bigger Cove | +10 cove slots (40 maximum) | 349 |
| Game pass | Tide Watcher | Income pile cap 24 hours; an in-game tide board showing the next three tides and a marker to the event. (Every player sees the clock and the next tide for free.) | 249 |
| Game pass | Keen Nose | Traits need 4 trait prey instead of 5 | 199 |
| Game pass | Shark Pup | Unlocks the species at once | 499 |
| Product | Revive | Continue the run at 70% mass (once per run) | 25 |
| Product | Trait Lock | Offered on the gulped screen: the next run starts with the lost run's traits | 19 |
| Product | Call the Tide | Starts a Feeding Frenzy for the whole server | 99 |
| Product | Cove Boost | Adds 2 hours of cove income at once (once a day) | 29 |
| Product | Goal Reroll | Swaps one daily goal | 19 |
| Product | Pearl packs | Four sizes | 49 / 149 / 399 / 999 |
| Product | Patterns | Colour patterns for a species | 79 to 199 |
| Product | Starter Pack | One-time: pattern + Pearls, offered from the second session | 99 |
| Private server | Monthly | A reef for friends | 99 |
| Rewarded video [L] | — | Where the game and the player are eligible: a free Revive, Cove Boost or Goal Reroll. Roblox requires each video reward to be a product that is also sold for Robux. | Free |

Chapter 05 also sells three decorations for Robux (49, 99 and 149), includes a Golden Chest decoration in the Starter Pack, and gives six patterns free through the Codex (one per species, for filling its Codex page).

Nothing is sold in the first two minutes of a new player's first session.

## 13. Look and sound, in one paragraph

A bright, chunky, hand-painted sea that reads like a toy box: rounded shapes, big eyes, three clear colour values per creature, saturated but not neon. Animation is snappy with strong squash and stretch. Nothing uses default Roblox parts, materials, interface or sounds. One exception: the built-in Neon material is allowed for outline shells and small glow caps only. Document 06 defines the style and its references; document 07 lists every asset.

## 14. Technology, in one paragraph

Luau in strict mode, source on disk synced with Rojo, packages with Wally, Roblox Studio driven through the official Studio MCP server. The character has no Humanoid: a physics-driven root part owned by the player's client, with the server checking speed, position and every bite. Prey are plain data on the server and are drawn by each client, never one Instance per prey on the server. Saves use a session-locked profile store. Roblox's Server Authority feature is evaluated in the Sprint 0 spike but the design does not depend on it. Roblox text chat is switched off in the MVP and reviewed for launch. Document 09 defines the architecture.

## 15. Scope tags

Every feature, asset and screen in the other documents carries one of these tags.

| Tag | Meaning |
|---|---|
| **[MVP]** | The core game. The soft launch starts with the smaller slice defined in chapter 13, section 3; the rest of [MVP] is added during soft launch and on the way to public launch, in the order chapter 13 sets. |
| **[L]** | Added for public launch |
| **[P1]** | First quarter after launch (weeks 1 to 12) |
| **[P2]** | Later |

**Platforms:** phone, tablet and PC or Mac with keyboard and mouse in the MVP (Chromebooks are treated as PC); gamepad on PC and handheld PCs at launch [L]; Xbox and PlayStation early in [P1] (target: the first month after launch), once they pass checks on real hardware; VR switched off. Phones are landscape only. Players on all devices share servers. Chapter 15 has the detail.

**MVP contents:** Nursery, Sunlit Reef, Kelp Forest, the Drop-off, coves; Minnow, Pufferfish, Eel; all eight prey; trait prey and traits for Glow, Stripes, Spots, Plated, Spiny, Longfin, Ink, Crystal, Moonlit; Gull, Moray, Barracuda, Old Scar, jelly bloom, hook, currents; Feeding Frenzy and Moon Tide; banking, specimens, cove income, cove slots; Codex; daily goals; the "biggest on this server" strip; Revive, Deep Pockets, Bigger Cove, Pearl packs; analytics funnels.

**Added for launch [L]:** Sea Turtle, Squid, Shark Pup; Spark, Camo, Ember, Bonefed; Grouper, anemone, vents; Whale Fall; login streak, Reef Rank, global leaderboards, cove visits and Bubbles, decorations; remaining passes and products; rewarded video; private servers; quick emotes; gamepad and the two-thumb phone scheme; a left-handed phone layout; computer-controlled "wild" creatures, clearly labelled as wild, that keep servers with fewer than 10 players lively.

## 16. Identifiers and naming

- Code identifiers are the lowercase IDs in the tables above (`minnow`, `glow`, `whale_fall`).
- Meshes `M_<Category>_<Name>`, textures `T_<Name>_<Map>`, animations `A_<Rig>_<Action>`, effects `FX_<Name>`, interface images `UI_<Screen>_<Name>`, sounds `SFX_<Name>`, music `MUS_<Name>`.
- Categories: `Species`, `Prey`, `Pred`, `Hazard`, `Env`, `Cove`, `Prop`, `Trait`.
- Further prefixes: rigs `RIG_`, lighting presets `LGT_`, skies `SKY_`, store-art scenes `SCN_`. Mesh suffixes: `_Juv`, `_Adult`, `_LOD1`, `_LOD2`, `_Shell` (eat outline), `_ShellThick` (danger outline; made for juvenile and adult forms). Chapter 07 owns the full asset naming rules and chapter 08 owns the interface image groups.
- Zone IDs: `nursery`, `reef`, `kelp`, `dropoff`, `trench`, `cove`.
- Purchase IDs are owned by chapter 05: game passes `pass_<name>`, developer products `prod_<name>`, rewarded video placements `ad_<name>`. Chapters 08, 09 and 10 use those IDs unchanged. Patterns (`pat_*`) and Robux decorations (`deco_buy_*`) are sold under their own content IDs, without the `prod_` prefix.
- Post-launch species IDs: `anglerfish`, `manta`, `seahorse`, `axolotl`, `orca`, `narwhal`.

## 17. Success measures

These are our own targets, not Roblox benchmarks **(tune)**. Every clock starts when the player first has control of the creature.

| Measure | Target |
|---|---|
| First bite within 10 seconds of control | 90% of new players |
| Reach tier 2 within 45 seconds | 75% |
| Still playing at 60 seconds | 80% |
| Still playing at 180 seconds | 65% |
| Bank the first creature | 60% |
| Start a second run in the first session | 50% |
| Still playing at 10 minutes in the first session | 50% |

**Go/no-go after soft launch:** once the game has 100 or more daily users, Roblox shows how its retention and session time compare with similar games. We continue to public launch only if day-1 retention and session time are at or above the median for similar games. Roblox shows a new game only to age-checked players aged 16 and over until it passes an evaluation, so this is read after younger players can play (chapter 12).

## 18. Glossary

| Term | Meaning |
|---|---|
| **Run** | One life, from leaving the cove to banking or being gulped |
| **Bank** | Swim home to keep the run |
| **Gulped** | Eaten. The run is lost. |
| **Tier** | One of seven size steps |
| **Mass** | The in-run size number |
| **Specimen** | A banked creature living in a cove |
| **Cove** | A player's safe home and collection |
| **Trait** | A visible body feature with an effect, gained from trait prey |
| **Trait prey** | Prey that gives progress toward one trait |
| **Tide event** | A timed server-wide event |
| **Pearls** | The persistent currency |
| **Bubble** | A like left on someone's cove |
| **Codex** | The collection log |
| **Scraps** | The small Pearl payout after being gulped |
