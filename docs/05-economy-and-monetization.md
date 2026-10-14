# 05 · Economy and monetisation

This chapter owns every price and every balance number in GULP. Where it differs from an anchor in `01-game-canon.md`, this chapter wins and the canon is updated to match. The canon has already adopted every number here; section 15 records what moved from its first draft. This chapter changes numbers only. Rules, names, IDs and structure stay as the canon defines them.

How to read it:

- Every number is a starting value. Numbers marked **(tune)** are first guesses that playtest data will move. Nothing here is a Roblox benchmark unless it says so.
- The tables in sections 2, 5, 6, 7 and 11 come from one small model (a foraging model, a run-value model and a day-by-day simulation). The inputs are listed next to each table so a reader can redo the arithmetic.
- Scope tags follow the canon: **[MVP]**, **[L]**, **[P1]**, **[P2]**.
- "Pearls/h" means Pearls per hour. "R$" means Robux.

## 1. Economy principles

### 1.1 What Pearls are for

Pearls are the only persistent currency. They do three jobs:

1. **Unlock variety.** New species change how a run plays.
2. **Grow the cove.** More slots mean more specimens on show and more income.
3. **Decorate.** Decorations are the long-term sink and the way a cove shows status.

Pearls never buy power inside a run. There is no shop item that adds mass, speed, traits or protection for Pearls.

The cove is the growth engine. A player's banking income is roughly flat from week to week, because the time it takes to reach each tier is fixed by the canon. The species price ladder (500 → 3,000 → 12,000 → 45,000 → 250,000) rises about fivefold per step, so only an income that grows can pay for it. That growing income is the cove: more slots, holding better specimens. A bank therefore pays twice: a modest Pearl payout now, and a specimen that earns every hour afterwards. Over the first 30 days more than two thirds of a regular player's Pearls come from the cove (68%), and 78% on day 30 itself (section 5.6). This is intended.

### 1.2 What can never be bought

Not with Robux, and not with Pearls:

| Never for sale | Why |
|---|---|
| Mass, tiers or a bigger start (other than the Shark Pup's tier 2 start, which is a species ability the canon defines) | Size is the game. It must come from eating. |
| Traits | "You are what you eat." Trait Lock only keeps traits the player already earned. Keen Nose only shortens the hunt. |
| Specimens | A specimen proves a run happened. |
| Reef Rank | Rank counts base banking and scraps only, before Deep Pockets (section 7). Deep Pockets, Pearl packs, cove income and rewards do not move it. |
| Codex entries | Discovery cannot be skipped. |
| Leaderboard places and Bubbles | Bubbles never pay Pearls and cannot be bought or traded. |
| Protection in open water | No shields, no "safe mode", no predator-off switch. |
| Anything random | No paid random items at launch (canon section 3). |

Pearls themselves can be bought (Pearl packs), which means species, slots and decorations can be reached faster with Robux. That is the full extent of paying to progress.

### 1.3 Fairness rules for a young audience

1. Nothing is sold in the first two minutes of a new player's first session, and nothing with a price is visible in that time.
2. Every purchase states exactly what it gives, in numbers, before the Roblox purchase prompt opens.
3. No countdown timers on offers, no fake scarcity, no "last chance" wording, no messages that shame a player for declining.
4. A purchase prompt opens only after the player taps a button that shows the Robux price. The game never opens a prompt by itself.
5. No purchase is needed to finish anything. Every species, slot, trait and Codex entry is reachable for free at a pace section 5 measures.
6. No streak or reward is lost by missing a day. The login calendar pauses; it does not reset.
7. Consumables are capped: one revive per run, five Pearl packs per account per day, one Cove Boost per account per day, three paid Goal Rerolls per account per day, one called tide per gap between tide events (a player can hold up to three Call the Tide tokens).
8. Rewards behind a rewarded video are small, and everything they give is also reachable without one, because many young players will not be eligible to see ads.
9. Prices sit in the 19 to 499 R$ band for single items. The only item above that is the largest Pearl pack at 999 R$.

### 1.4 Player-versus-player limits

The canon allows these purchases to touch a fight between two players. Nothing else may.

| Item | What it does in a fight | Limit that keeps it fair |
|---|---|---|
| Revive | The victim returns at 70% mass with 3 seconds of protection | Once per run. The eater keeps the mass they gained. The price never rises with use. |
| Trait Lock | The next run starts with the lost traits | Traits were earned by play. No mass is kept. One use per purchase. |
| Keen Nose | Traits arrive after 4 trait prey instead of 5 | Shortens a hunt by 20%. Gives no trait a free player cannot get. |
| Shark Pup pass | A species with a tier 2 start and Rampage | The same species is free at about day 30. Starting at tier 2 is also its drawback: a Shark Pup never has the tier 1 protection from other players (canon section 7). |
| Call the Tide | A Feeding Frenzy | Every player on the server gets it, not only the buyer. |
| Patterns | Nothing | Patterns never change silhouette, size, hitbox or the green and red outlines, and never imitate a trait's look. |

Deep Pockets, Bigger Cove, Tide Watcher, Pearl packs, Cove Boost, Goal Reroll, Robux decorations and the Starter Pack have no effect inside a run.

## 2. Mass economy inside a run

### 2.1 Mass per prey

Standard prey masses are the canon's. Trait prey masses were not in the canon and are set here: a trait prey gives the same mass as standard prey of its tier, except the Marrow chunk, which is tier 3 and gives 40.

| Prey | Tier | Mass | | Trait prey | Tier | Mass (tune) |
|---|---|---|---|---|---|---|
| Plankton mote | 0 | 0.2 | | Glowfry, Dotted Goby | 1 | 1 |
| Krill | 1 | 1 | | Zebra Darter, Armor Shrimp, Urchin Puff, Lunar Fry | 2 | 4 |
| Tiny Shrimp | 1 | 1.5 | | Ribbonfish, Inklet, Leaf Drifter, Crystal Jelly | 3 | 10 |
| Sardine | 2 | 4 | | Spark Eel, Vent Snail | 4 | 25 |
| Reef Darter | 3 | 10 | | Marrow chunk (Whale Fall) | 3 | 40 |
| Mackerel | 4 | 25 | | | | |
| Bonito | 5 | 60 | | | | |
| Tuna | 6 | 150 | | | | |

Other mass rules, all **(tune)**:

| Rule | Value |
|---|---|
| Eating a player | 30% of the victim's mass (canon) |
| Eating a Barracuda / a Grouper | 25 / 60, the same as prey of their tier (canon 5.2) |
| Spots trait | +10% mass from all prey (canon) |
| Bonefed trait | +25% mass from everything (canon) |
| Thermal vent | −5% of mass per second inside (canon) |
| Fishing hook | −20% of mass (canon) |
| Revive | Return at 70% of mass (canon) |
| Nursery prey eaten by a tier 1 creature | 100% of mass |
| Nursery prey eaten by a tier 2 creature | 50% of mass |
| Nursery prey eaten by a tier 3 or larger creature | 0% of mass. Tier 3 and above cannot enter the Nursery (canon 5.2), so this applies only in the 10 seconds a creature has to leave after it reaches tier 3 inside (chapter 02, section 6.5). |
| Marrow chunks per Whale Fall | 60 per server per event (2,400 mass in total; enough for 12 players to gain Bonefed) |
| Lunar Fry per Moon Tide | 40 per server per event (enough for 8 players to gain Moonlit) |
| Crystal Jellies | A drift of five, about one drift per server every 5 minutes (canon 8.2): at most 12 drifts an hour, so at most 12 creatures per server-hour can gain Crystal |

The Nursery rule closes a safe-farming exploit: without it, a tier 2 creature could feed in the one zone where nothing can eat it (section 6.3).

**Mythic supply in the MVP.** Until Whale Fall ships at launch, the :45 slot runs a second Moon Tide (canon section 10). Each Moon Tide keeps its 40 Lunar Fry, so an MVP server offers 80 Lunar Fry an hour: up to 16 Moonlit creatures. At launch the hour offers 8 Moonlit and 12 Bonefed, 20 Mythic traits in all. The second Moon Tide therefore puts no more Mythic income into the MVP than launch will have, and the supply per event is left unchanged.

### 2.2 Foraging model

The model gives an average player a number of useful seconds per minute in each zone, a number of seconds each catch costs, and a ceiling on how many of each prey one player can find per minute on a full server. The player eats the most profitable prey first until the minute is used up.

**Useful foraging seconds per minute** (the rest goes to dodging, travelling and missing):

| Zone | Useful seconds per minute |
|---|---|
| Nursery Lagoon | 54 |
| Sunlit Reef | 42 |
| Kelp Forest | 39 |
| The Drop-off | 36 |

**Seconds per catch** for prey one tier below the eater. Prey of the eater's own tier costs 1.6 times as long (it is about as fast as the eater). Prey two or more tiers below costs 0.8 times as long.

| Prey | Plankton | Krill | Tiny Shrimp | Sardine | Reef Darter | Mackerel | Bonito | Tuna |
|---|---|---|---|---|---|---|---|---|
| Seconds per catch | 1.0 | 1.7 | 4.0 | 9.0 | 11.0 | 16.0 | 24.0 | 45.0 |

**Available catches per player per minute** on a full 24-player server. These are the targets the spawn system must deliver; the chapter that owns spawning sets the spawn counts that produce them.

| Zone | Plankton | Krill | Tiny Shrimp | Sardine | Reef Darter | Mackerel | Bonito | Tuna |
|---|---|---|---|---|---|---|---|---|
| Nursery Lagoon | 20 | 18 | — | — | — | — | — | — |
| Sunlit Reef | 20 | 4 | 1.5 | 3 | 1.6 | — | — | — |
| Kelp Forest | 15 | — | 2 | 3.5 | 2.0 | 1.1 | — | — |
| The Drop-off | 10 | — | — | — | — | 1.8 | 1.1 | 0.25 |

**Result: what an average player eats in a minute in the zone that suits their tier.**

| Tier | Home zone | Catches per minute (average player) | Arithmetic | Mass/min |
|---|---|---|---|---|
| 1 Fry | Nursery Lagoon | 18 krill, 5.04 plankton | 18×1 + 5.04×0.2 | **19.0** |
| 2 Nibbler | Sunlit Reef | 4 krill, 1.5 shrimp, 2.03 sardine | 4×1 + 1.5×1.5 + 2.03×4 | **14.4** |
| 3 Snapper | Sunlit Reef | 4 krill, 1.6 darter, 1.5 shrimp, 0.4 sardine | 4×1 + 1.6×10 + 1.5×1.5 + 0.4×4 | **23.8** |
| 4 Hunter | Kelp Forest | 1.1 mackerel, 0.99 darter | 1.1×25 + 0.99×10 | **37.4** |
| 5 Brute | The Drop-off | 1.8 mackerel, 0.19 bonito | 1.8×25 + 0.19×60 | **56.2** |
| 6 Titan | The Drop-off | 1.1 bonito, 0.13 tuna | 1.1×60 + 0.13×150 | **86.0** |
| 7 Leviathan | The Drop-off | 0.25 tuna, 1.1 bonito, 0.28 mackerel | 0.25×150 + 1.1×60 + 0.28×25 | **110.6** |

Worked example, tier 2 in the Sunlit Reef (42 useful seconds):

- Krill is one tier below: 1.7 s each, 0.59 mass per second. Take all 4 available: 6.8 s, 4 mass.
- Tiny Shrimp: 4.0 s each, 0.375 mass per second. Take all 1.5: 6.0 s, 2.25 mass.
- Sardine is the eater's own tier: 9.0 × 1.6 = 14.4 s each, 0.28 mass per second. Time left is 42 − 6.8 − 6.0 = 29.2 s, which is 2.03 sardines, 8.1 mass.
- Total: 4 + 2.25 + 8.1 = **14.4 mass per minute**.

### 2.3 Expected mass per minute by tier and zone

Bold marks the best zone for that tier. A player in a zone too deep for them finds almost nothing they can eat. A large player in a shallow zone is capped by small prey.

| Tier | Nursery Lagoon | Sunlit Reef | Kelp Forest | The Drop-off | Home zone during Feeding Frenzy |
|---|---|---|---|---|---|
| 1 Fry | **19.0** | 10.2 | 6.0 | 2.0 | 28.4 |
| 2 Nibbler | 11.0 | **14.4** | 11.6 | 2.0 | 24.8 |
| 3 Snapper | 0.0 | **23.8** | 21.8 | 2.0 | 36.8 |
| 4 Hunter | 0.0 | 30.5 | **37.4** | 35.2 | 54.4 |
| 5 Brute | 0.0 | 32.4 | 49.6 | **56.2** | 80.4 |
| 6 Titan | 0.0 | 32.4 | 51.6 | **86.0** | 128.6 |
| 7 Leviathan | 0.0 | 32.4 | 51.6 | **110.6** | 167.7 |

The Reef Darter lives in the Sunlit Reef and the Kelp Forest only (canon 8.1), so the Drop-off has no standard tier 3 prey: a Snapper there finds only plankton (10 × 0.2 = 2.0). A Hunter in the Drop-off spends all 36 useful seconds on mackerel (36 ÷ 25.6 = 1.41 catches, 35.2 mass), so its cell never depended on the darter.

During a Feeding Frenzy the model assumes three times the available catches per minute and 30% fewer seconds per catch (less searching) **(tune)**. This is the canon's "three times the normal rate" read as catches per minute. Chapters 02 and 03 deliver it as twice the live prey (caps and density × 2) refilled three times as fast (respawn ÷ 3). That lifts mass per minute by roughly half for the four minutes (43% to 72% depending on tier). Frenzies run for 8 minutes in every hour, so the average uplift over time is about 7%.

### 2.4 Check against the canon's time-to-tier targets

Required mass per minute in each band = mass needed ÷ minutes the canon allows for that band. For example, tier 4 to tier 5 needs 200 − 80 = 120 mass in 7 − 4 = 3 minutes, which is 40 mass per minute.

| Reach tier | Mass band | Mass needed | Canon target (min) | Required mass/min | Model mass/min | Band time (min) | Cumulative, no events (min) | Cumulative, with average Frenzy uplift (min) | Difference vs target |
|---|---|---|---|---|---|---|---|---|---|
| 2 Nibbler | 0 → 10 | 10 | 0.5 | 20.0 | 19.0 | 0.53 | 0.53 | 0.49 | -1% |
| 3 Snapper | 10 → 30 | 20 | 2 | 13.3 | 14.4 | 1.39 | 1.92 | 1.76 | -12% |
| 4 Hunter | 30 → 80 | 50 | 4 | 25.0 | 23.8 | 2.10 | 4.02 | 3.72 | -7% |
| 5 Brute | 80 → 200 | 120 | 7 | 40.0 | 37.4 | 3.21 | 7.23 | 6.75 | -4% |
| 6 Titan | 200 → 500 | 300 | 12 | 60.0 | 56.2 | 5.33 | 12.56 | 11.79 | -2% |
| 7 Leviathan | 500 → 1200 | 700 | 20 | 87.5 | 86.0 | 8.14 | 20.70 | 19.43 | -3% |

All six tiers land within 12% of the target once the average Frenzy uplift is counted, and within 5% from tier 5 upwards. The canon's mass thresholds and prey masses are kept unchanged. The numbers that had to be set to get here are the catch times and availability ceilings in section 2.2.

Two things the table does not include, both of which make a real run a little faster than the model: mass from eating other players, and mass from trait prey. Both are small for an average player and are left as margin.

### 2.5 Event mass

| Event | Extra mass for a taking-part player (tune) | Arithmetic |
|---|---|---|
| Feeding Frenzy | +43% to +72% for 4 minutes. A tier 5 player gains about 322 mass instead of 225. | 80.4 × 4 against 56.2 × 4 |
| Moon Tide | None directly. 5 Lunar Fry give 20 mass and the Moonlit trait. | 5 × 4 |
| Whale Fall | 2,400 mass shared by everyone at the whale skeleton. With 8 players there, 300 mass each. | 60 × 40 ÷ 8 |

Whale Fall injects a fixed amount of mass per server no matter how many players come, so it cannot be farmed harder by a crowd.

## 3. Pearl sources

**A new profile starts with 0 Pearls and 0 of every token** (revive, Trait Lock, Call the Tide, Goal Reroll). There is no starting grant: the first Pearls come from the first bank (3.1, chapter 04, section 6) and the first-day goals (3.5; chapter 04, section 7.2), and the first income tick (canon 11) pays one hour of the first specimen's income.

### 3.1 Banking **[MVP]**

```
basePearls = 3 × min(mass, 1200) + 1 × clamp(mass − 1200, 0, 1800)
bankPearls = floor(basePearls × crystal × deepPockets)
    crystal     = 1.5 if the creature holds the Crystal trait, else 1
    deepPockets = 2 if the player owns Deep Pockets, else 1
```

The mass bands and their rates (3, 1 and 0 Pearls per mass) are canon 5.4's table (`data:BankRates`), which the code is generated from; the formula above restates it. The table below is worked examples of it.

| Mass at bank | Tier | Base Pearls | With Crystal | With Deep Pockets | With both |
|---|---|---|---|---|---|
| 10 | 2 | 30 | 45 | 60 | 90 |
| 30 | 3 | 90 | 135 | 180 | 270 |
| 80 | 4 | 240 | 360 | 480 | 720 |
| 200 | 5 | 600 | 900 | 1,200 | 1,800 |
| 500 | 6 | 1,500 | 2,250 | 3,000 | 4,500 |
| 1,200 | 7 | 3,600 | 5,400 | 7,200 | 10,800 |
| 2,000 | 7 | 4,400 | 6,600 | 8,800 | 13,200 |
| 3,000 or more | 7 | 5,400 | 8,100 | 10,800 | 16,200 |

The canon's rate of 3 Pearls per mass is kept up to 1,200 mass. Above that the rate drops, and it stops at 3,000 mass. The reason is in section 6.1: a Leviathan is very hard to eat (canon 5.4), so without a ceiling the best move is to stay out forever. Mass still counts in full for the leaderboards.

### 3.2 Scraps **[MVP]**

```
scraps = floor(rate × bankPearls the run would have paid)
    rate = 0.50 for the first three deaths on the account, then 0.10
```

The two rates are canon 5.5's table (`data:Scraps`), which the code is generated from.

A creature gulped at 88 mass would have banked 264 Pearls, so it pays 26 (or 132 during the first three deaths).

### 3.3 Cove income **[MVP]**

```
specimenPearlsPerHour = base[tier] × (1 + sum of trait bonuses)
covePearlsPerHour     = sum over all specimens in slots
```

<!-- data:CoveIncome -->
Soft-launch slice (chapter 13, section 3.2): every row.

| Tier | Base Pearls/h | Pearls per 16 hours | Pearls per 24 hours | First-draft canon anchor (Pearls/h) |
|---|---|---|---|---|
| 1 Fry | Not applicable: a specimen needs tier 2 | — | — | 10 |
| 2 Nibbler | 6 | 96 | 144 | 20 |
| 3 Snapper | 10 | 160 | 240 | 40 |
| 4 Hunter | 18 | 288 | 432 | 80 |
| 5 Brute | 30 | 480 | 720 | 160 |
| 6 Titan | 50 | 800 | 1,200 | 320 |
| 7 Leviathan | 80 | 1,280 | 1,920 | 640 |

<!-- /data -->

The base rises about 1.67 times per tier (close to 6 × 1.68^(tier − 2)). The table is the authority, not the formula.

<!-- data:TraitIncome -->
Soft-launch slice (chapter 13, section 3.2): `Common`, `Uncommon`.

| Trait rarity | Traits | Bonus per trait | First-draft canon anchor |
|---|---|---|---|
| Common | Glow, Stripes, Spots | +10% | +25% |
| Uncommon | Plated, Spiny, Longfin | +20% | +50% |
| Rare | Ink, Spark, Camo | +35% | +100% |
| Epic | Crystal, Ember | +60% | +200% |
| Mythic | Moonlit, Bonefed | +100% | +400% |

<!-- /data -->

Examples:

| Specimen | Arithmetic | Pearls/h |
|---|---|---|
| Tier 3, no traits | 10 × 1.00 | 10 |
| Tier 4, Stripes | 18 × 1.10 | 19.8 |
| Tier 5, Spots + Plated | 30 × 1.30 | 39 |
| Tier 6, Stripes + Spiny + Ink | 50 × 1.65 | 82.5 |
| Tier 7, Ink + Longfin + Glow | 80 × 1.65 | 132 |
| Tier 7, Moonlit + Ink + Plated | 80 × 2.55 | 204 |
| Tier 7, Moonlit + Bonefed + Crystal (the best possible) | 80 × 3.60 | 288 |

Income is stored as a decimal and rounded down when claimed. Final mass does not change income; it decides leaderboard place and bragging rights only.

On an account's first bank only, one hour of that specimen's income is paid at once, three seconds after it is placed (6 Pearls for a tier 2 Minnow with Glow), so a new player sees the cove pay (chapter 04, section 6). This first-bank reward is the only cove income that is ever paid by itself (canon section 11); all other cove income waits in the pile for a claim (section 3.4).

Section 5.5 shows why both tables moved: with the first-draft canon anchors a regular player buys the Shark Pup on day 11, not day 30. The canon now carries the values in this section.

### 3.4 Uncollected income cap and offline income **[MVP]**

- Income collects in one pile whether the player is online or offline (canon section 11). Being online gives no extra.
- The pile stops growing 8 hours after the last claim (canon): income counts only while less than 8 hours have passed since then, each period at the rate the cove had at the time. After a rate change the pile can therefore hold more or less than 8 hours of the current rate. Tide Watcher raises the window to 24 hours.
- The pile is paid into the player's Pearls only when the player claims it: by tapping the pile at the Pearl clam in the cove, or by tapping the welcome-back card. It is never claimed automatically: not at login, not on a bank, not on leaving the cove and not on a timer (canon section 11). The one exception is the first-bank reward in section 3.3.
- When the cove changes (a bank, a release, a new slot), the server first adds the income earned so far to the pile at the old rate, then switches to the new rate. Nothing is paid out at that moment. A specimen never earns for hours before it was banked.
- Maximum per day without the pass: 24 hours of income, by claiming three times at least 8 hours apart. Tide Watcher does not raise that ceiling; it removes the need to log in three times.
- **Cove Boost [L]** pays 2 hours of the cove's current income straight to the player's Pearls, once per account per UTC day, for Robux or by rewarded video (section 8.3). It does not pass through the pile, so the cap does not limit it and it does not empty the pile. With it the daily ceiling is 26 hours of income.

| Sessions a day, evenly spread | Hours of income collected per day | With Tide Watcher |
|---|---|---|
| 1 | 8 | 24 |
| 2 | 16 | 24 |
| 3 or more | 24 | 24 |

The table assumes the player claims once in every session, on entering the cove. Income from a session with no claim stays in the pile and is paid at the next claim, unless the pile reaches its cap first.

### 3.5 Daily goals **[MVP]**

Three goals a day: one easy, one medium, one hard. They reset at 00:00 UTC. The progression chapter owns the list of goals; this chapter owns what they pay.

| Goal | Base Pearls | Example |
|---|---|---|
| Easy | 100 | Bank one creature |
| Medium | 125 | Bank a tier 4 or larger creature |
| Hard | 175 | Bank a creature with two traits |
| All three done | +100 | — |
| **Full day** | **500** | |

Paid amount = base × rank multiplier (section 3.7), rounded down to a whole Pearl: a Medium goal at Reef Rank 2 pays `floor(125 × 1.1) = 137`, a Hard one `floor(175 × 1.1) = 192`. The all-three bonus is rounded the same way, on its own. In chapter 03's bands (section 3.12) Easy is R1, Medium is R2, Hard is R3 and the all-three bonus is R1.

An account's first day uses a fixed starter set of two Easy goals and one Medium (`dg_eat_50`, `dg_tier3`, `dg_bank_snapper`; chapter 04, section 7.2), the one exception canon 11 allows to "one Easy, one Medium, one Hard", so that day pays 425 in full, not 500.

Every player gets one free reroll of one goal per day. More rerolls come from the Goal Reroll product **[L]** (section 8.3): for Robux, at most three a day, or by rewarded video where the player is eligible, at most one a day (section 10).

### 3.6 Login streak **[L]**

A 7-box calendar. One box opens on each day the player logs in. A missed day does not reset the calendar; the next box simply waits. After box 7 the calendar starts again.

| Box | 1 | 2 | 3 | 4 | 5 | 6 | 7 | Total |
|---|---|---|---|---|---|---|---|---|
| Base Pearls | 100 | 100 | 150 | 150 | 200 | 300 | 500 | 1,500 |

Paid amount = base × rank multiplier.

The streak gives Pearls only (canon 11): every box holds Pearls, and no box holds a decoration, an item, or a Revive or Trait Lock token. The four decorations Sun Shell, Week Wheel, Lucky Starfish and Message in a Bottle are not streak rewards: they are free daily-goal milestones, given when all three daily goals have been finished on 3, 7, 14 and 28 days (lifetime count), as chapter 03, section 13 lists them.

### 3.7 Rank multiplier

```
rankMultiplier = 1 + 0.1 × (Reef Rank − 1)
```

| Reef Rank | 1 | 5 | 10 | 15 | 20 | 30 | 40 | 50 |
|---|---|---|---|---|---|---|---|---|
| Multiplier | 1.0 | 1.4 | 1.9 | 2.4 | 2.9 | 3.9 | 4.9 | 5.9 |

It applies to daily goals, the login streak and the tide bonus, and to nothing else. It keeps the fixed daily rewards worth collecting as income grows, and it is the main way a short-session player keeps up: a player with one 15-minute session a day gets the same goals as a player with 90 minutes. The multiplier stops at rank 50, so the most these three rewards can ever pay is (500 + 214 average streak box + 120) × 5.9 ≈ 4,900 Pearls a day.

The rank number is calculated from the first MVP build because goals need it. The Reef Rank screen, titles and decorations arrive at **[L]**.

### 3.8 Codex rewards **[MVP]**

Paid once per account, at the moment of discovery.

| Entry | Pearls each | Count at launch | Total |
|---|---|---|---|
| Standard prey first eaten | 20 | 8 | 160 |
| Trait prey first eaten | 30 | 13 | 390 |
| Common trait first gained | 100 | 3 | 300 |
| Uncommon trait first gained | 200 | 3 | 600 |
| Rare trait first gained | 400 | 3 | 1,200 |
| Epic trait first gained | 800 | 2 | 1,600 |
| Mythic trait first gained | 1,500 | 2 | 3,000 |
| Tier first reached with a species: tier 2 / 3 / 4 / 5 / 6 / 7 | 25 / 50 / 100 / 200 / 400 / 800 (1,575 per species) | 6 species | 9,450 |
| Species page complete (all tiers with that species) | 500, plus that species' free Codex pattern (section 8.5) | 6 | 3,000 |
| All six species pages complete (chapter 03: Growth) | 5,000 (band R5) | 1 | 5,000 |
| Species category complete (a run started as each of the six) | 175 (band R3) | 1 | 175 |
| Prey category complete | 175 (band R3) | 1 | 175 |
| Traits category complete | 2,500 (band R4) | 1 | 2,500 |
| Dangers category complete **[L]** | 175 (band R3) | 1 | 175 |
| Places category complete **[L]** | 175 (band R3) | 1 | 175 |
| Tides category complete **[L]** | 125 (band R2) | 1 | 125 |
| Whole Codex complete | 5,000 (band R5) | 1 | 5,000 |
| **All Codex rewards** | | | **33,025** |

The categories are chapter 03's (section 8.1). Single entries in Species, Dangers, Places and Tides pay nothing; tier 1 of a species page is filled by starting a run and pays nothing. Completing the Species, Prey, Traits, Dangers, Places or Tides category also gives that category's free decoration (section 4.3). The Codex rewards are never multiplied by the rank multiplier.

The Codex is front-loaded on purpose. It pays about 250 to 550 Pearls on a first day and almost nothing after the first month. The category rewards are small on purpose: the decoration is the prize.

### 3.9 Reef Rank and event rewards **[L]**

| Source | Pearls | Limit |
|---|---|---|
| Reaching a new Reef Rank | 25 × the new rank (rank 2 pays 50, rank 50 pays 1,250; 31,850 in total) | Once per rank |
| Tide bonus: take part in a tide event | 40 × rank multiplier | 3 a day |
| Limited-time tide **[P1]** | A Pearl budget of at most 10% of one week of a regular player's income at that player's rank; the rest of the reward is cosmetic | Per event |

"Taking part" means: eat 15 prey during a Feeding Frenzy, or 3 Lunar Fry during a Moon Tide, or 3 Marrow chunks during a Whale Fall **(tune)**.

### 3.10 Release refund **[MVP]**

```
refund = max(5, floor(1 hour of that specimen's income))
```

A tier 5 specimen with Spots and Plated refunds 39 Pearls. The refund is small on purpose: banking and at once releasing must never beat keeping a specimen.

### 3.11 Things that never pay Pearls

Bubbles, visiting a cove, being visited, leaderboard places, time spent online, and eating another player. Each of these could be farmed with a second account.

### 3.12 Reward bands R1 to R5 (for chapter 03)

Chapter 03 tags rewards with a band and leaves the amount to this chapter. These are the amounts, all **(tune)**. They are base amounts: the rank multiplier applies only where section 3.7 says it does.

**Table: reward band amounts**

<!-- data:RewardBands -->
Soft-launch slice (chapter 13, section 3.2): every row.

| Band | Pearls | Where chapter 03 uses it |
|---|---|---|
| R1 | 100 | Easy daily goal; the bonus for finishing all three goals |
| R2 | 125 | Medium daily goal; Tides category of the Codex |
| R3 | 175 | Hard daily goal; Species, Prey, Dangers and Places categories of the Codex |
| R4 | 2,500 | Traits category of the Codex |
| R5 | 5,000 | All six species pages of the Codex; the whole Codex |

<!-- /data -->

Chapter 03 now copies this chapter's amounts for the four rewards that once differed: the bonus for all three daily goals (R1, 100; section 3.5), the seven login streak boxes (section 3.6; Pearls only, no tokens), the Pearl gift for a new Reef Rank (25 × the new rank, section 3.9) and each Codex entry added after launch (the per-entry amounts in section 3.8). The 30-day model in section 5 is built on these amounts.

Decoration price bands D1 to D4 are in section 4.3.

## 4. Pearl sinks

### 4.1 Species

<!-- data:SpeciesPrices -->
Soft-launch slice (chapter 13, section 3.2): `minnow`, `puffer`.

| ID | Species | Price (Pearls) | Tag | Changed from canon? |
|---|---|---|---|---|
| `minnow` | Minnow | Free | [MVP] | No |
| `puffer` | Pufferfish | 500 | [MVP] | No |
| `eel` | Eel | 3,000 | [MVP] | No |
| `turtle` | Sea Turtle | 12,000 | [L] | No |
| `squid` | Squid | 45,000 | [L] | No |
| `shark` | Shark Pup | 250,000 (or the game pass) | [L] | No |
| | **All five** | **310,500** | | |

<!-- /data -->

The canon's species prices fit the pacing targets once cove income is retuned (section 5), so none of them changed.

### 4.2 Cove slots **[MVP]**

Slots 1 to 6 are free. Slot 7 costs 1,200 Pearls and each later slot costs about 1.25 times the one before, rounded to a tidy number. The table is the authority.

<!-- data:SlotPrices -->
Soft-launch slice (chapter 13, section 3.2): every row.

| Slot | Price (Pearls) | Running total |
|---|---|---|
| 7 | 1,200 | 1,200 |
| 8 | 1,500 | 2,700 |
| 9 | 1,900 | 4,600 |
| 10 | 2,400 | 7,000 |
| 11 | 3,000 | 10,000 |
| 12 | 3,750 | 13,750 |
| 13 | 4,500 | 18,250 |
| 14 | 5,750 | 24,000 |
| 15 | 7,250 | 31,250 |
| 16 | 9,000 | 40,250 |
| 17 | 11,000 | 51,250 |
| 18 | 14,000 | 65,250 |
| 19 | 17,500 | 82,750 |
| 20 | 22,000 | 104,750 |
| 21 | 27,500 | 132,250 |
| 22 | 34,000 | 166,250 |
| 23 | 43,000 | 209,250 |
| 24 | 54,000 | 263,250 |
| 25 | 67,000 | 330,250 |
| 26 | 84,000 | 414,250 |
| 27 | 105,000 | 519,250 |
| 28 | 130,000 | 649,250 |
| 29 | 165,000 | 814,250 |
| 30 | 205,000 | 1,019,250 |

<!-- /data -->

All 24 slots cost **1,019,250 Pearls**.

Why this curve: one more tier 5 specimen with two traits earns about 39 Pearls/h, or 624 Pearls over a 16-hour day. Slot 7 pays for itself in 2 days, slot 12 in 6 days, slot 20 in 35 days and slot 30 in 328 days. Early slots are an obvious buy. Late slots are a trophy shelf more than an investment. That rising payback time is the diminishing return on cove size.

Bigger Cove adds 10 slots on top, for a maximum of 40. It does not change any Pearl price: a pass owner's next Pearl slot costs the same as anyone's.

### 4.3 Decorations **[L]**

Decorations change how a cove looks. They give no income and no gameplay effect. Chapter 03, section 13 owns the list of 50 decorations, their names and which band and shop shelf each sits in. This chapter owns the prices. Document 07 lists the assets.

**Table: decoration price bands D1 to D4** (one price per band, all **(tune)**)

| Band | Price each (Pearls) | Items in chapter 03 | Shop shelves they sit on (Reef Rank that opens the shelf) | Band total |
|---|---|---|---|---|
| D1 | 200 | 5 | Shelf 1 (rank 1), shelf 2 (rank 6) | 1,000 |
| D2 | 4,500 | 6 | Shelf 2 (rank 6), shelf 3 (rank 11), shelf 4 (rank 16) | 27,000 |
| D3 | 30,000 | 4 | Shelf 4 (rank 16), shelf 5 (rank 21), shelf 6 (rank 26) | 120,000 |
| D4 | 360,000 | 3 | Shelf 6 (rank 26), shelf 7 (rank 31), shelf 8 (rank 36) | 1,080,000 |
| **All Pearl decorations at launch** | | **18** | | **1,228,000** |

Chapter 03 lists 18 Pearl decorations where the first draft of this chapter assumed 40. The Pearl total is kept at 1,228,000 on purpose, so the sinks in section 4.4 and the day 60 and day 90 checks in section 6.4 still hold. That is why D4 is high: three trophies carry the late-game sink. A D1 decoration costs about four minutes of play, so a new player can place one in the first session.

**Where all 50 decorations come from**

| Source | Count | Of which at launch | Price or how it is earned |
|---|---|---|---|
| Pearl shop, bands D1 to D4 | 18 | 18 | The table above |
| Reef Rank, free | 11 | 11 | One each at ranks 3, 6, 11, 16, 21, 26, 31, 36, 41, 46 and 50 (section 7) |
| Codex, free | 6 | 6 | Completing the Species, Prey, Traits, Dangers, Places or Tides category (section 3.8) |
| Daily-goal milestones, free | 4 | 4 | Sun Shell, Week Wheel, Lucky Starfish and Message in a Bottle: all three daily goals done on 3, 7, 14 and 28 days, lifetime count (chapter 03, section 13). The login streak gives no decoration. |
| Tide events, free | 7 | 3 | Lifetime event tasks set in chapter 03. At launch: Dinner Bell, Moon Lamp, Whale Rib Arch. The other four arrive with their tides: Storm, Red Tide and Great Migration at [P1], the Trench at [P2] (canon section 10). |
| Starter Pack | 1 | 1 | Golden Chest, part of the 99 R$ pack (section 8.3) |
| Robux | 3 | 3 | Jelly Lamp 49 R$, Disco Clam 99 R$, Mini Tin Pickle 149 R$ (section 8.5) |
| **Total** | **50** | **46** | |

The count matches chapter 03: 50 decorations, 46 of them at launch.

**Planned after launch [P1], not yet in chapter 03's list:** four Monument decorations at 500,000 to 1,500,000 Pearls each (about 4,000,000 in total), sold from shelf 7 (rank 31). Section 6.4 says why they are needed. Chapter 03 names them when they are scheduled.

### 4.4 Other sinks

There are no other Pearl sinks at launch. These deliberately cost nothing: releasing a specimen, shedding a trait, switching species, renaming a cove, the free daily goal reroll, visiting. There is no repair cost, upkeep, entry fee or tax.

| Launch sink | Pearls |
|---|---|
| Species | 310,500 |
| Cove slots | 1,019,250 |
| Decorations | 1,228,000 |
| **Everything a Pearl can buy at launch** | **2,557,750** |

In the MVP build only Pufferfish, Eel and slots exist (1,022,750 Pearls). That is enough for a soft launch that measures the first two weeks.

## 5. Progression model

### 5.1 The three players

| | Casual | Regular | Heavy |
|---|---|---|---|
| Play per day | One 15-minute session | Two 20-minute sessions | 90 minutes in three sessions |
| Share of session spent in runs | 85% | 85% | 85% |
| Run minutes per day | 12.75 | 34 | 76.5 |
| Hours of cove income collected per day | 8 | 16 | 18 |
| Daily goals completed (share of the full 500) | 60% | 90% | 100% |
| Tide bonuses per day | 0.7 | 2 | 3 |
| Codex rewards collected over time (of 33,025) | 3,500 | 7,000 | 14,000 |

The canon's pacing targets are for "a non-paying daily player". This chapter reads that as the **regular** player.

### 5.2 Assumptions

All are assumptions to replace with data from the soft launch.

1. The player logs in every day and buys nothing with Robux. No rewarded video, no passes, no Crystal multiplier.
2. Time to each tier follows the canon targets (section 2.4).
3. A run is one of four types. Each has a length, a chance to end in a bank, and a time of death if it does not. The run-value table in 5.3 gives the arithmetic.
4. A specimen banked today starts earning tomorrow. This slightly understates day 1 and day 2.
5. The cove always keeps its best specimens. When it is full, the worst one is released for the refund in 3.10.
6. Codex rewards arrive as `total × (1 − e^(−day ÷ 12))`: fast at first, then slowing.
7. Spending rule: buy the next species the moment it is affordable. Spend up to 20% of all Pearls earned so far on slots, but only when the cove is full and after the Pufferfish is bought. Spend 5% on decorations from day 5. After the Shark Pup, spend 70% on slots and 30% on decorations.
8. Fractions are carried over: "0.49 tier 6 specimens a day" becomes one tier 6 specimen every two days.
9. The player claims the cove pile on entering the cove: on the welcome-back card at the start of a session, and at the pile after a bank. Income is never claimed for them (section 3.4). That is what gives the 8, 16 and 18 hours collected per day in section 5.1.

### 5.3 What a run is worth

Mass at a given minute comes from the canon targets, with straight lines between them. A gulped run is assumed to end 60% of the way through. The first-days hop (A0) is the one exception to the straight line: a new player turns for home just short of the Hunter line, at 79 mass, so its specimen is a tier 3 Snapper (80 mass would be tier 4, canon 5.1).

| Run type | Length (min) | Mass at bank | Pearls at bank | Bank chance | Gulped at (min) | Mass when gulped | Scraps | Expected Pearls per run | Expected minutes per run | **Pearls/min** | Specimen | Avg trait bonus |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| A0 Reef hop, first days | 4 | 79 | 237 | 65% | 2.4 | 40 | 12.0 | 158.3 | 3.44 | **46.0** | Tier 3 | +0% |
| A Reef hop | 4 | 80 | 240 | 80% | 2.4 | 40 | 12.0 | 194.4 | 3.68 | **52.8** | Tier 4 | +10% |
| B Kelp run | 7 | 200 | 600 | 65% | 4.2 | 88 | 26.4 | 399.2 | 6.02 | **66.3** | Tier 5 | +25% |
| C Drop-off run | 12 | 500 | 1,500 | 45% | 7.2 | 212 | 63.6 | 710.0 | 9.36 | **75.9** | Tier 6 | +45% |
| D Leviathan run | 20 | 1,200 | 3,600 | 25% | 12.0 | 500 | 150.0 | 1012.5 | 14.00 | **72.3** | Tier 7 | +65% |
| A+ Reef hop, skilled | 4 | 80 | 240 | 90% | 2.4 | 40 | 12.0 | 217.2 | 3.84 | **56.6** | Tier 4 | +10% |
| B+ Kelp run, skilled | 7 | 200 | 600 | 78% | 4.2 | 88 | 26.4 | 473.8 | 6.38 | **74.2** | Tier 5 | +30% |
| C+ Drop-off run, skilled | 12 | 500 | 1,500 | 60% | 7.2 | 212 | 63.6 | 925.4 | 10.08 | **91.8** | Tier 6 | +55% |
| D+ Leviathan run, skilled | 20 | 1,200 | 3,600 | 40% | 12.0 | 500 | 150.0 | 1530.0 | 15.20 | **100.7** | Tier 7 | +90% |

How to read a row, using the Kelp run (B): a 7-minute run banks 200 mass for 600 Pearls 65% of the time. The other 35% of the time it ends at 4.2 minutes with 88 mass and pays 26.4 in scraps. Expected Pearls = 0.65 × 600 + 0.35 × 26.4 = 399.2. Expected minutes = 0.65 × 7 + 0.35 × 4.2 = 6.02. That is 66.3 Pearls a minute.

The four standard run types all return 53 to 76 Pearls a minute. A longer run pays more per bank and is lost more often, so the expected value stays in a narrow band. A better player is paid for surviving, not for a hidden multiplier: the skilled rows (+) differ only in the chance to bank and in the traits collected.

Each player's mix of runs, and the banking income that follows:

| Player | Days | Run-time mix | Pearls per run-minute | Run minutes/day | Banking Pearls/day |
|---|---|---|---|---|---|
| Casual | 1 to 3 | A0 100% | 46.0 | 12.75 | 587 |
| Casual | 4 to 10 | A 80%, B 20% | 55.5 | 12.75 | 708 |
| Casual | 11 to 30 | A 60%, B 40% | 58.2 | 12.75 | 742 |
| Regular | 1 | A0 100% | 46.0 | 34.00 | 1,564 |
| Regular | 2 | A 100% | 52.8 | 34.00 | 1,796 |
| Regular | 3 to 7 | A 50%, B 50% | 59.6 | 34.00 | 2,025 |
| Regular | 8 to 14 | A 25%, B 50%, C 25% | 65.3 | 34.00 | 2,221 |
| Regular | 15 to 30 | A 15%, B 40%, C 35%, D 10% | 68.2 | 34.00 | 2,320 |
| Heavy | 1 | A0 50%, A 50% | 49.4 | 76.50 | 3,780 |
| Heavy | 2 to 4 | A 30%, B 50%, C 20% | 64.2 | 76.50 | 4,910 |
| Heavy | 5 to 10 | A+ 10%, B+ 35%, C+ 40%, D+ 15% | 83.5 | 76.50 | 6,384 |
| Heavy | 11 to 30 | B+ 25%, C+ 40%, D+ 35% | 90.5 | 76.50 | 6,924 |

### 5.4 Day-by-day tables

The three tables are the simulation's output and were not re-run after run A0 was corrected from 80 to 79 mass (section 5.3). On the days that use A0 the Banking column still shows the old rate: 594 where the mix table now gives 587 (casual, days 1 to 3), 1,583 for 1,564 (regular, day 1) and 3,802 for 3,780 (heavy, day 1). From then on every Cumulative and Balance figure is high by about 22 Pearls (casual), 19 (regular) and 22 (heavy). Section 5.5 records what that moves: no unlock day, and one rank day for the casual player.

Columns: **Banking** includes scraps. **Cove** is yesterday's closing cove income per hour × hours collected. **Daily rewards** are goals, streak and tide bonuses. **One-time** is Codex, Reef Rank rewards and release refunds. **Balance** is Pearls in hand after the day's purchases. **Cove/h** is the cove's income per hour at the end of the day.

**Casual: one 15-minute session a day**

| Day | Banking | Cove | Daily rewards | One-time | Total | Cumulative | Balance | Slots | Cove/h | Rank | Unlocks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 594 | 0 | 428 | 405 | 1,427 | 1,427 | 927 | 6 | 20 | 3 | **Pufferfish** |
| 2 | 594 | 160 | 514 | 357 | 1,625 | 3,051 | 2,551 | 6 | 40 | 4 |  |
| 3 | 594 | 320 | 621 | 247 | 1,782 | 4,833 | 1,333 | 6 | 60 | 4 | **Eel** |
| 4 | 708 | 480 | 621 | 363 | 2,172 | 7,006 | 2,306 | 7 | 80 | 5 | Slot 7 |
| 5 | 708 | 637 | 739 | 211 | 2,294 | 9,300 | 4,600 | 7 | 109 | 5 |  |
| 6 | 708 | 874 | 879 | 354 | 2,815 | 12,115 | 6,810 | 7 | 129 | 6 |  |
| 7 | 708 | 1,030 | 1,242 | 220 | 3,200 | 15,316 | 8,510 | 8 | 156 | 6 | Slot 8 |
| 8 | 708 | 1,250 | 642 | 371 | 2,972 | 18,287 | 11,481 | 8 | 176 | 7 |  |
| 9 | 708 | 1,409 | 685 | 184 | 2,985 | 21,272 | 2,466 | 8 | 176 | 7 | **Sea Turtle** |
| 10 | 708 | 1,409 | 765 | 172 | 3,054 | 24,326 | 3,010 | 9 | 176 | 7 | Slot 9 |
| 11 | 742 | 1,409 | 765 | 362 | 3,278 | 27,604 | 6,287 | 9 | 214 | 8 |  |
| 12 | 742 | 1,709 | 898 | 152 | 3,501 | 31,104 | 9,788 | 9 | 231 | 8 |  |
| 13 | 742 | 1,850 | 1,068 | 143 | 3,803 | 34,907 | 13,062 | 9 | 231 | 8 |  |
| 14 | 742 | 1,850 | 1,408 | 380 | 4,380 | 39,288 | 15,042 | 10 | 249 | 9 | Slot 10 |
| 15 | 742 | 1,992 | 770 | 87 | 3,592 | 42,879 | 18,634 | 10 | 269 | 9 |  |
| 16 | 742 | 2,150 | 770 | 140 | 3,803 | 46,683 | 21,849 | 10 | 287 | 9 |  |
| 17 | 742 | 2,292 | 860 | 114 | 4,009 | 50,691 | 22,857 | 11 | 287 | 9 | Slot 11 |
| 18 | 742 | 2,292 | 860 | 338 | 4,233 | 54,924 | 27,090 | 11 | 324 | 10 |  |
| 19 | 742 | 2,592 | 1,003 | 102 | 4,440 | 59,364 | 30,896 | 11 | 324 | 10 |  |
| 20 | 742 | 2,592 | 1,193 | 117 | 4,645 | 64,009 | 35,541 | 11 | 342 | 10 |  |
| 21 | 742 | 2,734 | 1,573 | 73 | 5,122 | 69,131 | 36,913 | 12 | 342 | 10 | Slot 12 |
| 22 | 742 | 2,734 | 813 | 89 | 4,378 | 73,509 | 40,583 | 12 | 379 | 10 |  |
| 23 | 742 | 3,034 | 813 | 380 | 4,969 | 78,478 | 552 | 12 | 397 | 11 | **Squid** |
| 24 | 742 | 3,175 | 956 | 61 | 4,935 | 83,412 | 5,487 | 12 | 397 | 11 |  |
| 25 | 742 | 3,175 | 956 | 98 | 4,971 | 88,384 | 9,714 | 12 | 415 | 11 |  |
| 26 | 742 | 3,317 | 1,056 | 75 | 5,190 | 93,574 | 10,404 | 13 | 415 | 11 | Slot 13 |
| 27 | 742 | 3,317 | 1,256 | 52 | 5,367 | 98,941 | 15,244 | 13 | 452 | 11 |  |
| 28 | 742 | 3,617 | 1,656 | 369 | 6,385 | 105,325 | 21,628 | 13 | 452 | 12 |  |
| 29 | 742 | 3,617 | 899 | 87 | 5,345 | 110,671 | 26,387 | 13 | 470 | 12 |  |
| 30 | 742 | 3,758 | 899 | 45 | 5,445 | 116,115 | 31,832 | 13 | 470 | 12 |  |

**Regular: two 20-minute sessions a day**

| Day | Banking | Cove | Daily rewards | One-time | Total | Cumulative | Balance | Slots | Cove/h | Rank | Unlocks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1,583 | 0 | 630 | 785 | 2,998 | 2,998 | 2,498 | 6 | 60 | 4 | **Pufferfish** |
| 2 | 1,796 | 960 | 819 | 720 | 4,295 | 7,293 | 2,593 | 7 | 119 | 5 | **Eel**, Slot 7 |
| 3 | 2,025 | 1,901 | 952 | 879 | 5,757 | 13,050 | 8,350 | 7 | 156 | 7 |  |
| 4 | 2,025 | 2,501 | 1,088 | 736 | 6,350 | 19,400 | 1,200 | 8 | 192 | 8 | **Sea Turtle**, Slot 8 |
| 5 | 2,025 | 3,067 | 1,241 | 501 | 6,835 | 26,235 | 4,823 | 9 | 247 | 8 | Slot 9 |
| 6 | 2,025 | 3,950 | 1,411 | 694 | 8,081 | 34,316 | 12,904 | 9 | 302 | 9 |  |
| 7 | 2,025 | 4,834 | 1,854 | 689 | 9,403 | 43,718 | 19,032 | 10 | 338 | 10 | Slot 10 |
| 8 | 2,221 | 5,400 | 1,197 | 390 | 9,209 | 52,927 | 25,241 | 11 | 375 | 10 | Slot 11 |
| 9 | 2,221 | 6,000 | 1,197 | 602 | 10,021 | 62,947 | 34,300 | 11 | 412 | 11 |  |
| 10 | 2,221 | 6,600 | 1,360 | 718 | 10,900 | 73,847 | 0 | 11 | 448 | 12 | **Squid** |
| 11 | 2,221 | 7,160 | 1,428 | 359 | 11,168 | 85,015 | 6,515 | 12 | 448 | 12 | Slot 12 |
| 12 | 2,221 | 7,160 | 1,533 | 665 | 11,579 | 96,594 | 13,015 | 13 | 520 | 13 | Slot 13 |
| 13 | 2,221 | 8,320 | 1,826 | 264 | 12,631 | 109,225 | 25,014 | 13 | 558 | 13 |  |
| 14 | 2,221 | 8,920 | 2,266 | 655 | 14,063 | 123,288 | 32,624 | 14 | 558 | 14 | Slot 14 |
| 15 | 2,320 | 8,920 | 1,449 | 232 | 12,921 | 136,209 | 44,899 | 14 | 630 | 14 |  |
| 16 | 2,320 | 10,080 | 1,449 | 651 | 14,500 | 150,710 | 58,674 | 14 | 665 | 15 |  |
| 17 | 2,320 | 10,640 | 1,632 | 244 | 14,835 | 165,545 | 65,518 | 15 | 665 | 15 | Slot 15 |
| 18 | 2,320 | 10,640 | 1,632 | 194 | 14,786 | 180,331 | 79,564 | 15 | 738 | 15 |  |
| 19 | 2,320 | 11,800 | 1,752 | 621 | 16,493 | 196,823 | 95,232 | 15 | 738 | 16 |  |
| 20 | 2,320 | 11,800 | 2,075 | 211 | 16,406 | 213,229 | 101,818 | 16 | 772 | 16 | Slot 16 |
| 21 | 2,320 | 12,360 | 2,575 | 589 | 17,844 | 231,073 | 118,769 | 16 | 810 | 17 |  |
| 22 | 2,320 | 12,960 | 1,638 | 193 | 17,111 | 248,184 | 135,025 | 16 | 845 | 17 |  |
| 23 | 2,320 | 13,520 | 1,638 | 223 | 17,701 | 265,885 | 140,841 | 17 | 880 | 17 | Slot 17 |
| 24 | 2,320 | 14,080 | 1,768 | 552 | 18,720 | 284,605 | 158,625 | 17 | 918 | 18 |  |
| 25 | 2,320 | 14,680 | 1,836 | 210 | 19,046 | 303,651 | 176,719 | 17 | 952 | 18 |  |
| 26 | 2,320 | 15,240 | 1,971 | 148 | 19,679 | 323,330 | 195,413 | 17 | 952 | 18 |  |
| 27 | 2,320 | 15,240 | 2,241 | 673 | 20,474 | 343,804 | 200,863 | 18 | 988 | 19 | Slot 18 |
| 28 | 2,320 | 15,800 | 2,884 | 79 | 21,083 | 364,887 | 220,892 | 18 | 1,025 | 19 |  |
| 29 | 2,320 | 16,400 | 1,764 | 188 | 20,672 | 385,559 | 240,531 | 18 | 1,060 | 19 |  |
| 30 | 2,320 | 16,960 | 1,764 | 646 | 21,690 | 407,249 | 0 | 18 | 1,095 | 20 | **Shark Pup** |

**Heavy: 90 minutes a day**

| Day | Banking | Cove | Daily rewards | One-time | Total | Cumulative | Balance | Slots | Cove/h | Rank | Unlocks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 3,802 | 0 | 720 | 1,729 | 6,251 | 6,251 | 1,551 | 7 | 119 | 6 | **Pufferfish**, **Eel**, Slot 7 |
| 2 | 4,910 | 2,138 | 1,080 | 1,565 | 9,693 | 15,944 | 9,744 | 8 | 209 | 8 | Slot 8 |
| 3 | 4,910 | 3,769 | 1,309 | 1,621 | 11,608 | 27,552 | 7,452 | 9 | 335 | 10 | **Sea Turtle**, Slot 9 |
| 4 | 4,910 | 6,030 | 1,463 | 1,399 | 13,801 | 41,354 | 18,854 | 10 | 408 | 11 | Slot 10 |
| 5 | 6,384 | 7,335 | 1,640 | 1,561 | 16,920 | 58,274 | 29,861 | 11 | 490 | 13 | Slot 11 |
| 6 | 6,384 | 8,811 | 2,024 | 1,280 | 18,499 | 76,773 | 2,435 | 11 | 612 | 14 | **Squid** |
| 7 | 6,384 | 11,007 | 2,576 | 1,289 | 21,256 | 98,030 | 18,878 | 12 | 688 | 15 | Slot 12 |
| 8 | 6,384 | 12,393 | 1,728 | 1,299 | 21,804 | 119,834 | 35,092 | 13 | 918 | 16 | Slot 13 |
| 9 | 6,384 | 16,515 | 1,800 | 1,176 | 25,875 | 145,709 | 53,923 | 14 | 1,034 | 17 | Slot 14 |
| 10 | 6,384 | 18,603 | 2,002 | 1,136 | 28,125 | 173,834 | 73,392 | 15 | 1,111 | 18 | Slot 15 |
| 11 | 6,924 | 19,998 | 2,079 | 1,150 | 30,151 | 203,985 | 93,036 | 16 | 1,306 | 19 | Slot 16 |
| 12 | 6,924 | 23,517 | 2,296 | 1,215 | 33,951 | 237,937 | 125,290 | 16 | 1,464 | 20 |  |
| 13 | 6,924 | 26,343 | 2,668 | 1,171 | 37,106 | 275,042 | 149,540 | 17 | 1,464 | 21 | Slot 17 |
| 14 | 6,924 | 26,343 | 3,360 | 1,163 | 37,790 | 312,832 | 185,441 | 17 | 1,616 | 22 |  |
| 15 | 6,924 | 29,079 | 2,232 | 1,275 | 39,509 | 352,342 | 208,975 | 18 | 1,690 | 23 | Slot 18 |
| 16 | 6,924 | 30,420 | 2,304 | 477 | 40,125 | 392,466 | 247,093 | 18 | 1,842 | 23 |  |
| 17 | 6,924 | 33,156 | 2,464 | 1,129 | 43,673 | 436,139 | 0 | 19 | 1,842 | 24 | **Shark Pup**, Slot 19 |
| 18 | 6,924 | 33,156 | 2,541 | 1,169 | 43,790 | 479,930 | 0 | 20 | 1,994 | 25 | Slot 20 |
| 19 | 6,924 | 35,892 | 2,788 | 1,134 | 46,738 | 526,667 | 0 | 21 | 2,146 | 26 | Slot 21 |
| 20 | 6,924 | 38,628 | 3,220 | 386 | 49,158 | 575,825 | 0 | 22 | 2,224 | 26 | Slot 22 |
| 21 | 6,924 | 40,023 | 3,920 | 1,081 | 51,948 | 627,773 | 0 | 23 | 2,376 | 27 | Slot 23 |
| 22 | 6,924 | 42,759 | 2,592 | 429 | 52,703 | 680,477 | 0 | 23 | 2,528 | 27 |  |
| 23 | 6,924 | 45,495 | 2,592 | 1,152 | 56,163 | 736,640 | 0 | 24 | 2,528 | 28 | Slot 24 |
| 24 | 6,924 | 45,495 | 2,849 | 1,124 | 56,392 | 793,031 | 0 | 24 | 2,680 | 29 |  |
| 25 | 6,924 | 48,231 | 2,926 | 463 | 58,544 | 851,576 | 22,353 | 24 | 2,754 | 29 |  |
| 26 | 6,924 | 49,572 | 3,116 | 1,240 | 60,852 | 912,428 | 0 | 25 | 2,828 | 30 | Slot 25 |
| 27 | 6,924 | 50,913 | 3,588 | 206 | 61,631 | 974,059 | 41,091 | 25 | 2,906 | 30 |  |
| 28 | 6,924 | 52,308 | 4,368 | 1,205 | 64,805 | 1,038,864 | 2,455 | 26 | 2,980 | 31 | Slot 26 |
| 29 | 6,924 | 53,649 | 2,880 | 382 | 63,834 | 1,102,698 | 47,139 | 26 | 3,132 | 31 |  |
| 30 | 6,924 | 56,385 | 2,880 | 1,134 | 67,323 | 1,170,021 | 0 | 27 | 3,132 | 32 | Slot 27 |

### 5.5 Milestones and the check against the canon

| Milestone | Canon target (non-paying daily player) | Casual | Regular | Heavy |
|---|---|---|---|---|
| Pufferfish (500) | End of first session | Day 1 | Day 1 | Day 1 |
| Eel (3,000) | Day 2 | Day 3 | Day 2 | Day 1 |
| Sea Turtle (12,000) | Day 4 or 5 | Day 9 | Day 4 | Day 3 |
| Squid (45,000) | About day 10 | Day 23 | Day 10 | Day 6 |
| Shark Pup (250,000) | About day 30 | Day 71 | Day 30 | Day 17 |
| Slot 7 | — | Day 4 | Day 2 | Day 1 |
| Slot 10 | — | Day 14 | Day 7 | Day 4 |
| Slot 12 | — | Day 21 | Day 11 | Day 7 |
| Slot 15 | — | Day 37 | Day 17 | Day 10 |
| Slot 20 | — | Day 96 | Day 32 | Day 18 |
| Slot 25 | — | After day 120 | Day 48 | Day 26 |
| Slot 30 | — | After day 120 | Day 73 | Day 40 |

The regular player meets every canon target: Pufferfish in the first session, Eel on day 2, Sea Turtle on day 4, Squid on day 10, Shark Pup on day 30. The casual player takes about 2.3 times as many days and the heavy player a little over half as many.

**The first session in detail.** An average new player, with all values (tune):

| Time | What happens | Pearls | Running total |
|---|---|---|---|
| 0:00 to about 1:45 | Run 1, the scripted Nursery run of chapter 04. Codex: plankton 20, krill 20, Glowfry 30, Glow 100, tier 2 as a Minnow 25. First bank at about 20 mass (60) and the first income tick (6). Nothing is for sale, and no number is shown until the bank. | 261 | 261 |
| About 2:00 to the second bank, at 6:00 to 8:00 | Run 2, Sunlit Reef. Codex: sardine 20, tier 3 50. Starter goal "grow into a Snapper" (Easy, 100). Banks at about 40 mass (120), which completes "bank a Snapper or bigger" (Medium, 125). | 415 | 676 |
| Run 3 | Starter goal "eat 50 prey" (Easy, 100) completes early in the run; all three goals done (100). Banks at about 60 mass (180). | 380 | 1,056 |

The masses, goals and times are chapter 04's (sections 6.2, 7.2 and 7.4); the amounts are this chapter's. Reef Rank rewards arrive at **[L]** and add 50 here (rank 2 at 100 lifetime banked Pearls).

The Pufferfish (500) is affordable at the second bank, with 676 Pearls, six to eight minutes in. Run 1 cannot be lost, because nothing can eat a new player before the first bank (canon 5.2). If run 2 is gulped at 40 mass, the 50% scraps rule pays 60 where the bank would have paid 120, "bank a Snapper" waits for run 3, and the total passes 500 early in run 3 when "eat 50 prey" completes (591). That path ends run 3 with 996. The canon wants half of new players still playing at 10 minutes, so the Pufferfish arrives inside a typical first session.

The starter set pays 425 for a full day against the 450 the model assumes for a regular player's day 1 (90% of 500). The 25-Pearl gap moves nothing: the regular player still ends day 1 short of the Eel and buys it on day 2.

**What the first-draft canon anchors did.** The same simulation with the first-draft canon's cove formula (10 × 2^(tier − 1)) and trait bonuses (+25% to +400%):

| Regular player | Canon target | With first-draft anchors | With this chapter's numbers (now the canon's) |
|---|---|---|---|
| Sea Turtle | Day 4 or 5 | Day 3 | Day 4 |
| Squid | About day 10 | Day 5 | Day 10 |
| Shark Pup | About day 30 | Day 11 | Day 30 |
| All 30 slots | — | Day 27 | Day 73 |
| Pearls per day on day 30 | — | 203,974 | 21,690 |

The anchors gave the Shark Pup away 19 days early and left a regular player owning every species and every slot before the end of week four. Cutting the cove base and the trait bonuses fixed the pacing without touching a single species price.

**Adjustments made to reach the fit**, in order:

1. Cove base per tier cut from 20 / 40 / 80 / 160 / 320 / 640 to 6 / 10 / 18 / 30 / 50 / 80.
2. Trait bonuses cut from +25 / 50 / 100 / 200 / 400% to +10 / 20 / 35 / 60 / 100%.
3. Slot prices set so that a 20% slot budget buys slot 12 by about day 11 and slot 18 by day 27.
4. Daily goal, streak and Reef Rank rewards trimmed so that a regular player ends day 1 with 2,498 Pearls, short of the Eel's 3,000. The Eel then lands early on day 2.

**Re-check after the consistency pass (13 October 2026).** The simulation was not re-run; each change was checked by hand against the day tables above. No species unlock day moved.

| Change | Effect on the 30-day model |
|---|---|
| Decorations now follow chapter 03: 18 Pearl items in bands D1 to D4, on eight shelves opened by Reef Rank | None. The Pearl total is still 1,228,000. The regular player's 31,499 of decoration spending by day 30 fits what is open by then: shelves 1 to 4 (shelf 4 opens at rank 16, reached on day 19) hold 58,000 Pearls of decorations. Buying the three D1 on shelf 1 on day 1 (600 Pearls) still leaves the Eel on day 2 and the Sea Turtle on day 4. |
| Codex: Prey category 250 → 175; new category rewards (650) and 5,000 for all six species pages | None. The amounts each player is assumed to collect (3,500, 7,000, 14,000) are unchanged; the new rewards are late completions and one needs the Shark Pup. |
| First-day starter goals pay 425, not 450 | None (25 Pearls on day 1). |
| Revive offered from 30 mass, not 80 | None. The model buys nothing. |
| Cove Boost and Goal Reroll | None in the base model, which uses no Robux and no video. A regular player who takes a Cove Boost every day (free by video where eligible) gains 12.5% more cove Pearls, about 30,000 by day 28, and reaches the Shark Pup about one day sooner (day 29). This is an estimate from the regular table, not a simulation run. |
| Crystal Jelly as a drift of five | None in the base model, which leaves the ×1.5 out. At the supply ceiling in section 2.1 a full server gives half a Crystal creature per player-hour. For a regular player that is at most one run in twenty, which adds at most about 5% to their banking and under 1% to their Pearls by day 30. |
| Second Moon Tide at :45 in the MVP | None. Frenzy time is still 8 minutes an hour; Mythic supply is checked in section 2.1. |
| Cove income is claimed by a tap, never automatically (canon section 11; section 3.4) | None. Hours collected per day were always an input (8, 16 and 18; section 5.1), and the model now states that the player claims on entering the cove (assumption 9). Check: the casual player's one session follows a gap of 23.75 hours, so the pile is at its 8-hour cap: 8 hours. The regular player's two sessions follow gaps of about 11.7 hours, both over the cap: 2 × 8 = 16 hours. The heavy player's three sessions follow gaps that total 22.5 hours, for example 5, 5 and 12.5: 5 + 5 + 8 = 18 hours. Income earned during a session and not tapped stays in the pile for the next claim; the day tables never counted it. No unlock day moves. |
| Run A0 banks at 79 mass (237 Pearls), not 80 (240), so that its tier 3 specimen agrees with the canon tier table (section 5.3) | Not re-run; the day tables keep the old figures (section 5.4). Banking on A0 days falls by 1.2%: 7 Pearls a day on the casual player's days 1 to 3, 19 on the regular player's day 1 and 22 on the heavy player's day 1. The regular player ends day 1 with about 2,479 Pearls, not 2,498. The tightest unlock is the regular player's Squid on day 10, bought with 200 Pearls to spare, so no species day and no slot day moves. One rank day moves: the casual player's lifetime banked Pearls on day 14 fall from 9,706 to 9,685, under the 9,700 that rank 9 needs, so rank 9 and its 225 Pearls arrive on day 15, not day 14. The cove columns are unchanged: the simulation always counted an A0 specimen as tier 3 at 10 Pearls/h, which gives the casual player's 20, 40 and 60 Pearls/h on days 1 to 3 and the regular player's 60 on day 1. |
| The Reef Darter is no longer counted in the Drop-off (section 2.2) | None. Only the tier 3 Drop-off cell in section 2.3 changed (17.0 to 2.0), and no player in the model feeds there at tier 3: time to tier uses each tier's home zone (section 2.4). |

### 5.6 Where the Pearls come from

| Player | Day | Pearls/day | Banking | Cove | Daily rewards | One-time | Cumulative earned | Slots | Cove Pearls/h | Rank |
|---|---|---|---|---|---|---|---|---|---|---|
| Casual | 1 | 1,427 | 41% | 0% | 30% | 28% | 1,427 | 6 | 20 | 3 |
| Casual | 10 | 3,054 | 23% | 46% | 25% | 5% | 24,326 | 9 | 176 | 7 |
| Casual | 30 | 5,445 | 13% | 69% | 16% | 0% | 116,115 | 13 | 470 | 12 |
| Regular | 1 | 2,998 | 52% | 0% | 21% | 26% | 2,998 | 6 | 60 | 4 |
| Regular | 10 | 10,900 | 20% | 60% | 12% | 6% | 73,847 | 11 | 448 | 12 |
| Regular | 30 | 21,690 | 10% | 78% | 8% | 2% | 407,249 | 18 | 1,095 | 20 |
| Heavy | 1 | 6,251 | 60% | 0% | 11% | 27% | 6,251 | 7 | 119 | 6 |
| Heavy | 10 | 28,125 | 22% | 66% | 7% | 4% | 173,834 | 15 | 1,111 | 18 |
| Heavy | 30 | 67,323 | 10% | 83% | 4% | 1% | 1,170,021 | 27 | 3,132 | 32 |

Over the first 30 days a regular player earns 407,249 Pearls: 277,893 from the cove (68%), 66,173 from banking (16%), 48,870 from daily rewards (12%) and 14,312 from one-time rewards (4%). They spend 310,500 on species, 65,250 on 12 slots and 31,499 on decorations.

The share from banking falls from about half on day 1 to a tenth on day 30. That is the price ladder at work (section 1.1), and it has one consequence worth stating plainly: **Deep Pockets is worth most in the first two weeks.** Section 8.2 prices it with that in mind.

## 6. Inflation and exploit checks

### 6.1 The most a perfect player can bank in an hour

A perfect player is modelled as losing no time (60 useful seconds a minute), catching 40% faster, finding 50% more prey, and never being gulped.

| Tier | Average player (mass/min) | Perfect player (mass/min) | Perfect player reaches the next tier at (min) |
|---|---|---|---|
| 1 | 19.0 | 32.3 | 0.31 |
| 2 | 14.4 | 31.4 | 0.95 |
| 3 | 23.8 | 51.9 | 1.91 |
| 4 | 37.4 | 85.0 | 3.32 |
| 5 | 56.2 | 156.2 | 5.24 |
| 6 | 86.0 | 220.5 | 8.42 |
| 7 | 110.6 | 241.9 | — |

| Loop | Arithmetic | Pearls per hour |
|---|---|---|
| Reach 1,200 mass, bank, repeat | 3,600 Pearls every 8.42 + 0.5 minutes | 24,200 |
| The same with the Shark Pup (tier 2 start saves 0.31 minutes) | 3,600 every 8.61 minutes | **25,100** |
| Reach 3,000 mass, bank, repeat | 5,400 every 8.42 + 7.44 + 0.5 minutes | 19,800 |
| Reach 3,000 mass with Crystal (one whole drift of five jellies), bank, repeat | 8,100 every 16.36 minutes | 29,700 |
| Reach 1,200 mass with Crystal, bank, repeat | 5,400 every 8.92 minutes | 36,300 |
| The same with the Shark Pup | 5,400 every 8.61 minutes | **37,600** |
| The same with the Shark Pup and Deep Pockets | 10,800 every 8.61 minutes | **75,300** |

Crystal Jellies roam as a drift of five, about one drift per server every five minutes (canon 8.2), so one player can gain Crystal from a single drift. The Crystal rows assume the perfect player finds a drift on every run and eats all five jellies; Keen Nose lowers that to four of the five and does not raise the ceiling.

So the ceiling without Crystal is about **25,000 Pearls an hour** for a free player and about 50,000 with Deep Pockets. A player who also wins a whole drift on every run reaches about **38,000**, or about **75,000** with Deep Pockets. An average player earns 3,200 to 4,600 an hour of run time (section 5.3). The gap without Crystal is about sevenfold and is all skill and survival.

Crystal is capped by supply, not by skill: at most 12 drifts an hour per server. The ×1.5 adds at most 2,700 Pearls to one bank (5,400 base at 3,000 mass), so it can add at most 32,400 base Pearls an hour to a whole server, whatever its players do.

**Without the cap in 3.1** a Leviathan would earn 241.9 × 3 = 726 Pearls a minute, 43,500 an hour, for as long as it liked. Old Scar eats tier 6 and below, players of the same tier bump off each other, and there is no tier 8. A Leviathan is very hard to eat (canon 5.4): it can be gulped only after vents or a hook pull it back under 1,200 mass, because tier follows mass (canon 5.1). Unlimited reward at almost no risk breaks pillar 3 ("home is safe, open water is not"). With the cap, the extra 1,800 mass is worth 1,800 Pearls over about 16 minutes for an average Leviathan. That is about 110 Pearls a minute against about 72 for a fresh run, so the lap of honour is worth swimming, but it ends: after 3,000 mass there is nothing left to gain but leaderboard place.

### 6.2 The most a cove can earn

| Cove | Arithmetic | Pearls/h | Per 8-hour claim | Per day (24 h) |
|---|---|---|---|---|
| 30 slots of the best possible specimen | 30 × 288 | 8,640 | 69,120 | 207,360 |
| 40 slots (Bigger Cove) of the best possible specimen | 40 × 288 | 11,520 | 92,160 | 276,480 |
| Heavy player at day 90 in the model | 30 slots, average 152 | 4,560 | 36,480 | 82,080 at 18 h |
| Regular player at day 90 in the model | 30 slots, average 80 | 2,413 | 19,304 | 38,608 at 16 h |

The best possible specimen needs Moonlit (Moon Tide, :15), Bonefed (Whale Fall, :45) and Crystal (a drift of five jellies, about one drift per server every five minutes) on one tier 7 creature, banked alive. That is a run of 35 minutes or more through the two most dangerous events. Thirty of them is a theoretical limit, not a forecast.

A daily Cove Boost (section 3.4) adds two more hours of income to any row: at most 8.3% on top of the 24-hour figure.

The point of the table: **cove income has a hard ceiling.** Slots stop at 30 (40 with the pass) and no specimen can pass 288 Pearls/h. Income grows quickly for a month and then flattens, as the heavy player's rows in section 6.4 show from day 45. After that, inflation is a straight line, and new sinks can be priced against a known daily income.

### 6.3 Exploits considered and the guard rail for each

| Exploit | Guard rail |
|---|---|
| A Leviathan farms forever at almost no risk | Banking pays 1 Pearl per mass above 1,200 and nothing above 3,000 (3.1) |
| A tier 2 or larger creature feeds in the Nursery where nothing can eat it | Tier 3 and above cannot enter the Nursery (canon 5.2). Nursery prey gives 50% mass to tier 2 and none to a creature that has just reached tier 3 inside (2.1). Model: tier 2 gets 11.0 mass/min in the Nursery against 14.4 in the Reef. |
| Staying online all night to earn | One pile for online and offline, capped at 8 hours (3.4) |
| Banking a great specimen just before a claim so it earns for hours it was not there | Income earned so far is added to the pile at the old rate before the cove changes (3.4) |
| Bank and release in a loop for refunds | Refund is one hour of income; a tier 2 specimen refunds 6 Pearls for a 30-second run (3.10) |
| Dying on purpose for scraps | Scraps are 10%. The 50% rate is three deaths per account, ever (3.2) |
| A second account feeds mass to the first | Eating a player gives 30% of its mass; 70% is destroyed. Feeding always loses to eating prey. |
| A second account gives Bubbles or visits | Bubbles and visits never pay Pearls (3.11) |
| Rerunning one-time rewards | Codex and Reef Rank rewards are keyed to the account and paid once |
| Private or empty servers with no player predators | Allowed. If survival improves by 15 to 20 points, a run pays roughly 15% to 25% more Pearls per minute. Banks on private servers do not count for the global weekly leaderboard. |
| A buyer chains Call the Tide into a permanent Frenzy | One called tide per gap between scheduled tides (a player can hold up to three Tide tokens, but only one starts at a time), so at most 4 an hour per server; Frenzy time can rise from 8 to 24 minutes an hour (8.3) |
| Buying or watching Cove Boosts without limit | One Cove Boost per account per UTC day, whether paid or by video (8.3). It pays the cove's own income, so a new or empty cove gains almost nothing. |
| Rerolling goals until only easy ones are left | A reroll gives a goal of the same difficulty. One free, one by video and three paid a day (3.5). |
| Whale Fall farmed by a crowd | 60 Marrow chunks per event per server, whatever the turnout (2.1) |
| Speed, teleport or forged bites | The server checks speed, position and every bite (canon section 14). Banking uses server mass only. |
| Clock changes on the device | All timers use server time |
| Buying Pearls without limit | Five Pearl packs per account per UTC day (8.4) |
| Daily rewards scaling without end | The rank multiplier stops at 5.9 (3.7) |

### 6.4 Day 60 and day 90

| Player | Day | Pearls earned that day | Cove Pearls/h | Slots | Species owned (of 6) | Cumulative Pearls earned | Pearls earned beyond the launch catalogue |
|---|---|---|---|---|---|---|---|
| Casual | 30 | 5,445 | 470 | 13 | 5 | 116,115 | 0 |
| Casual | 45 | 6,369 | 600 | 16 | 5 | 211,136 | 0 |
| Casual | 60 | 7,097 | 638 | 17 | 5 | 317,529 | 0 |
| Casual | 90 | 8,004 | 675 | 18 | 6 | 548,434 | 0 |
| Regular | 30 | 21,690 | 1,095 | 18 | 6 | 407,249 | 0 |
| Regular | 45 | 31,680 | 1,657 | 24 | 6 | 814,620 | 0 |
| Regular | 60 | 38,126 | 2,076 | 28 | 6 | 1,355,172 | 0 |
| Regular | 90 | 45,306 | 2,413 | 30 | 6 | 2,628,967 | 71,217 |
| Heavy | 30 | 67,323 | 3,132 | 27 | 6 | 1,170,021 | 0 |
| Heavy | 45 | 87,234 | 4,262 | 30 | 6 | 2,344,539 | 0 |
| Heavy | 60 | 93,479 | 4,560 | 30 | 6 | 3,733,684 | 1,175,934 |
| Heavy | 90 | 94,819 | 4,560 | 30 | 6 | 6,564,249 | 4,006,499 |

| Player | Day all launch slots are owned | Day the whole launch catalogue (2,557,750 Pearls) is paid for | Reef Rank 50 |
|---|---|---|---|
| Casual | After day 120 | After day 120 | After day 120 |
| Regular | Day 73 | Day 89 | About day 225 |
| Heavy | Day 40 | Day 48 | Day 78 |

Reading it:

- **Day 60.** A regular player owns every species and 28 slots, earns about 38,000 Pearls a day and still has slots and D4 decorations to buy. A heavy player paid for the whole launch catalogue 12 days ago and is holding more than a million spare Pearls. A casual player is 11 days from the Shark Pup.
- **Day 90.** A regular player has earned enough for everything on sale. A heavy player has about 4 million spare Pearls. A casual player owns every species and 18 slots.
- **Shelves open by rank, not by Pearls.** The "paid for" days above count Pearls earned. The three D4 decorations sit on shelves 6, 7 and 8 (ranks 26, 31 and 36), which a regular player reaches at about day 53, day 79 and day 109, and a heavy player before day 40. So a regular player's last purchase, the Golden Minnow, waits for rank 36 until about day 109.

Income by then is flat (6.2), so the problem is a missing sink, not runaway growth. Fixed-size Pearl packs lose value as income grows: the 999 R$ pack is 9.5 days of a regular player's income on day 5 and 1.7 days on day 60. That is accepted. Packs are a first-month product; later revenue comes from patterns and passes.

**New sinks needed, and when:**

| Needed by | Sink | Pearls (tune) | Tag |
|---|---|---|---|
| Day 45 after public launch | Monument decorations, Reef Rank 31 | 4 at 500,000 to 1,500,000; about 4,000,000 in total | [P1] |
| Day 45 | Anglerfish | 400,000 | [P1] |
| Day 60 | Manta Ray | 600,000 | [P1] |
| Day 90 | Seahorse | 800,000 | [P2] |
| Day 120 | Axolotl | 1,000,000 | [P2] |
| Later | Orca Calf, Narwhal | 1,500,000 and 2,000,000 | [P2] |
| Day 90 to 120 | Migration: a reset of Pearls, purchased slots and specimens in exchange for +10% cove income for good (up to five times) and a new cove biome. Requires all six launch species and Reef Rank 30. | Removes every Pearl the player holds | [P2] |
| With trading | A Pearl fee on every trade (section 13) | 10% of a specimen's 24-hour income, per side | [P2] |

The six post-launch species add 6,300,000 Pearls of sink. At the heavy player's 95,000 a day that is 66 days of saving; at the regular player's 45,000 it is 140 days. The top few percent of players will always outrun the sinks. The target is that the regular player always has something worth buying that is no more than 14 days away.

## 7. Reef Rank **[L]**

Reef Rank runs from 1 to 50 and is driven by **lifetime banked Pearls**: the base Pearls from every bank (including the Crystal multiplier) plus scraps, counted before Deep Pockets. Cove income, daily rewards, Codex rewards and Pearl packs do not count. Rank therefore measures play and cannot be bought or idled.

```
threshold(rank) = 100 × (rank − 1)^2.2
rounded to the nearest 10 below 1,000, 50 below 10,000, 500 below 100,000, and 1,000 above
```

The table is the authority.

| Rank | Lifetime banked Pearls | Reward (Pearls) | Rank | Lifetime banked Pearls | Reward (Pearls) |
|---|---|---|---|---|---|
| 1 | 0 | — | 26 | 119,000 | 650 |
| 2 | 100 | 50 | 27 | 130,000 | 675 |
| 3 | 460 | 75 | 28 | 141,000 | 700 |
| 4 | 1,100 | 100 | 29 | 153,000 | 725 |
| 5 | 2,100 | 125 | 30 | 165,000 | 750 |
| 6 | 3,450 | 150 | 31 | 178,000 | 775 |
| 7 | 5,150 | 175 | 32 | 191,000 | 800 |
| 8 | 7,250 | 200 | 33 | 205,000 | 825 |
| 9 | 9,700 | 225 | 34 | 219,000 | 850 |
| 10 | 12,500 | 250 | 35 | 234,000 | 875 |
| 11 | 16,000 | 275 | 36 | 249,000 | 900 |
| 12 | 19,500 | 300 | 37 | 265,000 | 925 |
| 13 | 23,500 | 325 | 38 | 282,000 | 950 |
| 14 | 28,000 | 350 | 39 | 299,000 | 975 |
| 15 | 33,000 | 375 | 40 | 316,000 | 1,000 |
| 16 | 38,500 | 400 | 41 | 335,000 | 1,025 |
| 17 | 44,500 | 425 | 42 | 353,000 | 1,050 |
| 18 | 51,000 | 450 | 43 | 373,000 | 1,075 |
| 19 | 58,000 | 475 | 44 | 392,000 | 1,100 |
| 20 | 65,000 | 500 | 45 | 413,000 | 1,125 |
| 21 | 73,000 | 525 | 46 | 434,000 | 1,150 |
| 22 | 81,000 | 550 | 47 | 455,000 | 1,175 |
| 23 | 90,000 | 575 | 48 | 477,000 | 1,200 |
| 24 | 99,000 | 600 | 49 | 500,000 | 1,225 |
| 25 | 109,000 | 625 | 50 | 523,000 | 1,250 |

| Reward | When |
|---|---|
| Pearls: 25 × the new rank | Every rank |
| A title | On entering each band of five ranks (ranks 1, 6, 11, 16, 21, 26, 31, 36, 41, 46) and at rank 50. Chapter 03, section 11 owns the names. |
| One free rank-only decoration | Ranks 3, 6, 11, 16, 21, 26, 31, 36, 41, 46 and 50: 11 in all (chapter 03, section 13) |
| Decoration shop shelves 1 to 8 open (prices in section 4.3) | Ranks 1, 6, 11, 16, 21, 26, 31 and 36 |
| Monument decorations can be bought [P1] | Rank 31, on shelf 7 |
| +0.1 to the rank multiplier (3.7) | Every rank |

The rank thresholds in the table above are the authority. Chapter 03's "lifetime Pearls banked to enter" column for each band of ranks should read from it: rank 6 = 3,450, rank 11 = 16,000, rank 16 = 38,500, rank 21 = 73,000, rank 26 = 119,000, rank 31 = 178,000, rank 36 = 249,000, rank 41 = 335,000, rank 46 = 434,000, rank 50 = 523,000.

Pace in the model:

| Player | Rank on day 1 | Day 10 | Day 30 | Day 90 | Rank 50 |
|---|---|---|---|---|---|
| Casual | 3 | 7 | 12 | 20 | More than a year |
| Regular | 4 | 12 | 20 | 33 | About day 225 |
| Heavy | 6 | 18 | 32 | 50 | Day 78 |

A new player gains two or three ranks in the first session, which is the point of the 2.2 exponent: early ranks are quick, and each later rank costs more than the one before.

## 8. Monetisation catalogue

### 8.1 What Roblox keeps

The Creator Hub page "Earning on Roblox" (create.roblox.com/docs/production/earning-on-roblox) was read on 13 October 2026 through an automated page summary. It says creators "generally earn 70% of anything they sell in Robux" in their game, and 30% of what they sell in the Marketplace (avatar items). **What could be verified:** the 70% general figure for sales inside a game. **What could not:** a per-item breakdown. The page does not name game passes, developer products or private servers one by one; the game pass page states no percentage; and the Marketplace fees page covers avatar items only. This chapter uses 70% for passes, products and private servers, and treats the private server share as an assumption.

```
earnedRobux = price × 0.70
US dollars  = earnedRobux × 0.0038
```

A 299 R$ pass earns 209 Robux, which is 0.80 US dollars.

All prices must be read at run time with `MarketplaceService:GetProductInfo`, never typed into the interface. Roblox's own price testing tool requires this (section 12).

### 8.2 Game passes

The **Grant** column uses chapter 09's vocabulary (section 3.2, `ProductDef.grant`): `flag` (a pass the server reads), `token` (one use kept on the profile), `pearls`, `pattern`, `decoration`, or `bundle` (several of these, listed in the cell).

<!-- data:Passes -->
Soft-launch slice (chapter 13, section 3.2): `pass_deep_pockets`, `pass_bigger_cove`.

| ID | Tag | Exact effect | Price (R$) | Earned per sale | Why this price | Where and when it is offered | Rule that keeps it fair | Grant |
|---|---|---|---|---|---|---|---|---|
| `pass_deep_pockets` | [MVP] | Every bank and every scraps payout pays ×2, applied after Crystal. No effect on cove income, Reef Rank, mass or leaderboards. | 299 | 209 R$, $0.80 | The first draft of the canon said 399. The model gives +31% Pearls over a regular player's first 10 days and +20% over 30, the smallest long-run gain of the three income passes. It is the easiest pass to understand and the first one shown, so it should not carry the highest price. | One line on the bank summary from the third bank onward: "With Deep Pockets: 1,200". Once per session at most. One small non-blocking card, once, after the tenth bank on the account: it sits at the edge of the cove screen, never covers a menu, and the pass panel opens only if the player taps it (chapter 08, rule O-R8). Always in the shop. | Reef Rank ignores it. It changes nothing in a run. | `flag` |
| `pass_bigger_cove` | [MVP] | +10 cove slots at once, on top of Pearl slots. Maximum 40. Pearl slot prices do not change. | 349 | 244 R$, $0.93 | The first draft of the canon said 249. The model gives +39% Pearls over a regular player's 30 days, and unlike Deep Pockets the gain does not fade: at the 30-slot ceiling it is still +33%. It is the strongest permanent pass, so it sits above Deep Pockets. | A button in the "cove is full" dialog, and beside the next-slot button. One small non-blocking card, once, the third time the cove is full: the pass panel opens only if the player taps the card (chapter 08, rule O-R8). Always in the shop. | The extra slots only hold specimens the player banked. No effect in a run. | `flag` |
| `pass_tide_watcher` | [L] | Uncollected income cap 24 hours instead of 8. An in-game tide board that shows the next three tides, and a marker that points to the event while a tide runs (canon section 12). Everything is inside the game: the pass sends no push notifications. | 249 | 174 R$, $0.66 | The first draft of the canon said 299. It is worth +123% to a one-session player and nothing to a three-session player, and it does not raise the 24-hour ceiling any free player can reach. A convenience pass belongs below the two passes that add something new. | One line on the welcome-back panel when the cap was hit: "Your cove was full for 6 hours." Once a day at most. Always in the shop. | It only removes the need to log in three times a day. | `flag` |
| `pass_keen_nose` | [L] | A trait is gained after 4 of its trait prey instead of 5. | 199 | 139 R$, $0.53 | The first draft of the canon said 349. The effect is a 20% shorter hunt and no Pearls. It is the smallest effect of the five, so it is the entry price. | A small button on the trait bar tooltip in the cove, and in the shop. Never shown during a run. | Every trait stays reachable without it. It grants no trait by itself. | `flag` |
| `pass_shark_pup` | [L] | Unlocks the `shark` species at once. | 499 | 349 R$, $1.33 | Canon anchor kept. The Pearl route is 250,000 Pearls, which would cost about 3,840 R$ in Pearl packs, so the pass is the clear way to pay. It is the top of the pass ladder. | On the Shark Pup card in the species screen, beside the Pearl price. Hidden once the species is owned either way. | The species is free at about day 30. Its tier 2 start means it never has the tier 1 protection from other players (canon section 7). | `flag` |

<!-- /data -->

All five passes together cost 1,595 R$ and earn the developer 4.24 US dollars.

What the three income passes do in the model (pass owned from day 1, nothing else bought):

| Player | Pass owned from day 1 | Pearls earned by day 10 | Change | Pearls earned by day 30 | Change | Squid day | Shark Pup day |
|---|---|---|---|---|---|---|---|
| Casual | None | 24,326 | — | 116,115 | — | 23 | 71 |
| Casual | Deep Pockets | 31,440 | +29% | 140,293 | +21% | 20 | 63 |
| Casual | Bigger Cove | 28,287 | +16% | 153,935 | +33% | 19 | 57 |
| Casual | Tide Watcher | 40,394 | +66% | 259,463 | +123% | 15 | 39 |
| Casual | All three | 58,913 | +142% | 402,064 | +246% | 12 | 30 |
| Regular | None | 73,847 | — | 407,249 | — | 10 | 30 |
| Regular | Deep Pockets | 96,447 | +31% | 489,013 | +20% | 9 | 27 |
| Regular | Bigger Cove | 97,581 | +32% | 564,283 | +39% | 9 | 24 |
| Regular | Tide Watcher | 93,266 | +26% | 575,831 | +41% | 9 | 24 |
| Regular | All three | 147,350 | +100% | 886,954 | +118% | 7 | 19 |
| Heavy | None | 173,834 | — | 1,170,021 | — | 6 | 17 |
| Heavy | Deep Pockets | 232,737 | +34% | 1,404,246 | +20% | 5 | 14 |
| Heavy | Bigger Cove | 219,707 | +26% | 1,508,083 | +29% | 5 | 14 |
| Heavy | Tide Watcher | 205,470 | +18% | 1,518,610 | +30% | 6 | 15 |
| Heavy | All three | 320,832 | +85% | 2,148,234 | +84% | 4 | 11 |

### 8.3 Developer products

<!-- data:Products -->
Soft-launch slice (chapter 13, section 3.2): `prod_revive`.

| ID | Tag | Exact effect | Price (R$) | Earned per sale | Why this price | Where and when it is offered | Rule that keeps it fair | Grant |
|---|---|---|---|---|---|---|---|---|
| `prod_revive` | [MVP] | The gulped creature returns where it died with all traits, 70% of its mass and 3 seconds of protection. | 25 | 17.5 R$, $0.07 | Canon anchor kept. A tier 5 run holds about 600 Pearls and a specimen; 25 R$ is small enough to be an impulse and is the lowest price that still earns something after the platform share. | A button on the gulped screen. The screen has no countdown: it stays until the player picks Revive, Trait Lock or "Swim again". Offered only when the creature had 30 mass or more (tier 3), never on an account's first death, and never in the first two minutes of the first session (canon 5.5). | Once per run. The price never rises. The eater keeps what they gained. A free route exists by rewarded video for eligible players. | `token` |
| `prod_trait_lock` | [L] | The player's next run starts with the traits the gulped creature held. One use. | 19 | 13.3 R$, $0.05 | The first draft of the canon said 35. Revive at 25 R$ returns the traits and 70% of the mass. Trait Lock returns the traits only, so it must cost less or nobody should pick it. | A second button on the gulped screen (canon section 12), only when the creature held an Uncommon or better trait. This chapter owns that condition (chapter 02, section 8.3 leaves "when the button is shown" to it; chapter 08, offer O3 copies it). It is the only paid option when the run's revive is already used. | Returns only what the player earned. No mass. | `token` |
| `prod_call_tide` | [L] | Gives one Tide token. The token starts a 4-minute Feeding Frenzy for the whole server after a 10-second warning that names the buyer. It never interrupts a scheduled tide: if a tide or its warning is running, or the next warning is too close for a full Frenzy to fit, the token is held and starts when that tide ends (canon section 10). | 99 | 69 R$, $0.26 | The first draft of the canon said 149. For the buyer alone a Frenzy is worth about 100 extra mass, a few hundred Pearls; 149 R$ buys 7,000 Pearls as a pack. This is a gift to the server, bought to be seen, and 99 R$ is the price a young player will pay for that. | A button on the tide clock. When the token would be held, the button says so before the purchase. | Everyone on the server benefits. One called tide per gap between scheduled tides per server; a player can hold up to three tokens; one starts at a time, when no tide is running, and tokens are used in the order they were bought. Chapter 02 owns the exact timing. | `token` |
| `prod_starter_pack` | [L] | Once per account: the `pat_minnow_sunrise` pattern, the Golden Chest decoration (`deco_buy_gold_chest`, chapter 03) and 5,000 Pearls. | 99 | 69 R$, $0.26 | Canon anchor kept. The pattern and the Pearls are worth about 185 R$ at catalogue prices (a 79 R$ pattern plus 5,000 Pearls at the medium pack's rate of 47 per R$), before counting the decoration, so it is the best deal in the game and a first purchase. 5,000 Pearls buys the Eel and slot 7 on day 2 and nothing a free player lacks on day 3. | One small non-blocking card after the first bank of a session, once the bank sequence has finished. The pack's purchase panel opens only if the player taps the card (section 9; chapter 08, rule O-R8). Only from the second session on and once the account has two banks. Never at login, during a run or on the gulped screen. The card appears in at most three sessions, then the pack lives only in the shop (chapter 04, section 8.3). | One per account. No timer. It never expires. | `bundle`: 5,000 Pearls, `pat_minnow_sunrise`, `deco_buy_gold_chest` |
| `prod_cove_boost` | [L] | Pays 2 hours of the cove's current income at once, straight to the player's Pearls: `floor(2 × covePearlsPerHour)`. It does not touch the income pile or Reef Rank. The button shows the exact number, for example "+2,190 Pearls". | 29 | 20.3 R$, $0.08 | New in the canon, priced here. Two hours of income is about 900 Pearls for a regular player on day 10 and 2,190 on day 30. At the small pack's rate 29 R$ buys 1,184 Pearls, so the boost is the worse deal until the cove earns about 590 Pearls/h (about day 15 for a regular player) and the better one after that. That is accepted because it is one a day and cannot stack. | A button beside the Pearl clam in the cove and on the welcome-back panel. Hidden in a player's first session and while the boost would pay under 200 Pearls (a cove earning under 100 Pearls/h). Where a rewarded video is available, the video button comes first. | One per account per UTC day, whether bought or earned by video. The amount is the player's own cove income, so it gives nothing a cove would not earn in two more hours. | `pearls` |
| `prod_goal_reroll` | [L] | Swaps one unfinished daily goal for another of the same difficulty. The new goal starts at 0. | 19 | 13.3 R$, $0.05 | New in the canon, priced here at the lowest price in the catalogue. A reroll is worth at most one goal's Pearls (175 × the rank multiplier, about 500 at rank 20). It is a convenience, and it exists as a product because Roblox requires a video reward to be one. | A button on the daily goals panel, shown only after the day's free reroll is used. Where a rewarded video is available, the video button comes first. | Every player keeps one free reroll a day. At most three paid rerolls and one video reroll per account per UTC day. No goal needs a reroll to be finished. | `token` |

<!-- /data -->

### 8.4 Pearl packs **[MVP]**

<!-- data:PearlPacks -->
Soft-launch slice (chapter 13, section 3.2): every row.

| ID | Price (R$) | Pearls | Pearls per R$ | Bonus over the small pack | Earned per sale | Days of a regular player's income: day 5 / day 10 / day 30 | Tag | Grant |
|---|---|---|---|---|---|---|---|---|
| `prod_pearls_s` | 49 | 2,000 | 40.8 | — | 34 R$, $0.13 | 0.3 / 0.2 / 0.1 | [MVP] | `pearls` |
| `prod_pearls_m` | 149 | 7,000 | 47.0 | +15% | 104 R$, $0.40 | 1.0 / 0.6 / 0.3 | [MVP] | `pearls` |
| `prod_pearls_l` | 399 | 22,000 | 55.1 | +35% | 279 R$, $1.06 | 3.2 / 2.0 / 1.0 | [MVP] | `pearls` |
| `prod_pearls_xl` | 999 | 65,000 | 65.1 | +60% | 699 R$, $2.66 | 9.5 / 6.0 / 3.0 | [MVP] | `pearls` |

<!-- /data -->

- **Why these amounts:** prices are the canon anchors. The small pack buys the Pufferfish four times over; the medium pack buys the Eel twice; the large pack buys about half a Squid; the extra-large pack buys the Squid with 20,000 to spare. Buying the Shark Pup this way takes about 3,840 R$ against 499 R$ for the pass, which is deliberate: passes are the good deal, packs are for impatience.
- **Where and when:** in the shop, and as one "Get Pearls" button on a species or slot card when the player is short. Never as a panel that opens by itself.
- **Fairness rule:** amounts are fixed and shown as numbers. At most five packs per account per UTC day. Pearls bought do not count toward Reef Rank or any leaderboard.

### 8.5 Patterns and Robux decorations **[L]**

A pattern recolours one species. Chapter 03, section 1.3 owns the list of 18 launch patterns (three per species), their IDs, names and looks: base colours only, no markings. This chapter decides how each one is obtained and what it costs.

- **Free, by Codex (6):** one per species, given for completing that species' page, which means reaching all seven tiers with it (section 3.8).
- **Starter Pack (1):** Sunrise, only in the pack (section 8.3).
- **Robux (11):** developer products whose ownership is saved to the profile; the buy button is replaced by "Owned" after purchase. Three price steps: Classic 79 R$, Bold 129 R$, Showpiece 199 R$. The step is a price, not an art rule.

No pattern is sold for Pearls: the canon lists patterns as Robux products and Pearls as spent on species, slots and decorations. Every species has a free pattern through the Codex (canon 12).

**Purchase IDs.** A pattern or a Robux decoration is sold under its chapter 03 content ID (`pat_<species>_<name>`, `deco_buy_<name>`), unchanged: the item and its developer product share one ID, and chapters 08 and 10 use it as the SKU. These are the only developer products without the `prod_` prefix of canon section 16, which should record the exception.

| ID | Species | Name | How it is obtained | Price (R$) | Earned per sale |
|---|---|---|---|---|---|
| `pat_minnow_sunrise` | Minnow | Sunrise | Starter Pack only | — | — |
| `pat_minnow_blueberry` | Minnow | Blueberry | Robux, Classic | 79 | 55 R$, $0.21 |
| `pat_minnow_mint` | Minnow | Mint | Free: Codex, all 7 Minnow tiers | — | — |
| `pat_puffer_lemon` | Pufferfish | Lemon Drop | Robux, Classic | 79 | 55 R$, $0.21 |
| `pat_puffer_bubblegum` | Pufferfish | Bubblegum | Robux, Bold | 129 | 90 R$, $0.34 |
| `pat_puffer_midnight` | Pufferfish | Midnight | Free: Codex, all 7 Pufferfish tiers | — | — |
| `pat_eel_seafoam` | Eel | Seafoam | Robux, Classic | 79 | 55 R$, $0.21 |
| `pat_eel_liquorice` | Eel | Liquorice | Robux, Bold | 129 | 90 R$, $0.34 |
| `pat_eel_sunset` | Eel | Sunset | Free: Codex, all 7 Eel tiers | — | — |
| `pat_turtle_mossback` | Sea Turtle | Mossback | Robux, Classic | 79 | 55 R$, $0.21 |
| `pat_turtle_terracotta` | Sea Turtle | Terracotta | Robux, Bold | 129 | 90 R$, $0.34 |
| `pat_turtle_royal` | Sea Turtle | Royal | Free: Codex, all 7 Sea Turtle tiers | — | — |
| `pat_squid_peach` | Squid | Peach Fizz | Robux, Classic | 79 | 55 R$, $0.21 |
| `pat_squid_deepsea` | Squid | Deep Sea | Robux, Showpiece | 199 | 139 R$, $0.53 |
| `pat_squid_cherry` | Squid | Cherry | Free: Codex, all 7 Squid tiers | — | — |
| `pat_shark_sandbar` | Shark Pup | Sandbar | Robux, Classic | 79 | 55 R$, $0.21 |
| `pat_shark_storm` | Shark Pup | Storm | Robux, Showpiece | 199 | 139 R$, $0.53 |
| `pat_shark_bubble` | Shark Pup | Bubble Blue | Free: Codex, all 7 Shark Pup tiers | — | — |

That is 18 patterns: 6 free, 1 in the Starter Pack, 11 for Robux (six Classic, three Bold, two Showpiece). All 11 together cost 1,259 R$.

- **Why these prices:** the canon range is 79 to 199. Three steps give a cheap first cosmetic, a middle most buyers land on, and a showpiece that makes the middle look reasonable. Chapters 03 and 06 own the look; document 07 lists the assets.
- **Where and when:** on the species screen, as swatches under each species. A pattern for a species the player does not own can be previewed but not bought.
- **Fairness rule:** a pattern never changes silhouette, size, hitbox, outline colours or trait visuals, and never looks like a trait. The Camo trait's see-through effect overrides any pattern.

**Robux decorations.** Chapter 03 lists three decorations bought with Robux. Like patterns they are one-time developer products saved to the profile, sold on the decoration shelf beside the Pearl items, with no effect on income or play.

| ID | Decoration | Size | Price (R$) | Earned per sale |
|---|---|---|---|---|
| `deco_buy_jelly_lamp` | Jelly Lamp | Small | 49 | 34 R$, $0.13 |
| `deco_buy_disco_clam` | Disco Clam | Medium | 99 | 69 R$, $0.26 |
| `deco_buy_mini_pickle` | Mini Tin Pickle | Large | 149 | 104 R$, $0.40 |

The prices follow size and sit below the pattern of the same step, because a decoration is seen only in the cove and a pattern is seen in every run. The fourth "purchase" decoration, the Golden Chest, comes only in the Starter Pack.

### 8.6 Private server **[L]**

| ID | Effect | Price (R$) | Earned per month | Why this price | Where offered | Fairness rule |
|---|---|---|---|---|---|---|
| `private_server` | A reef for the owner and invited friends. Same map, clock, tide events and saves as a public server. | 99 a month | 69 R$, $0.26 (assuming the 70% share applies) | Canon anchor kept. Playing with friends is a discovery signal for Roblox, so the price is kept low; it still needs to be above zero because a private reef has no player predators. | The Roblox game page only. Never advertised inside the game. | Progress is identical. Banks on a private server do not count for the global weekly leaderboard. |

`private_server` is a label for this table and for reports only. A private server is a Roblox setting on the game page, not a game pass or a developer product, so it has no purchase ID in code and the `pass_` and `prod_` prefixes of canon section 16 do not apply.

## 9. Offer timing and placement

**Definitions.** A *proactive offer* is a small, non-blocking card the player did not ask for; its purchase panel opens only when the player taps the card. No purchase panel ever opens by itself (chapter 08, section 9 owns the offer rules, and they win). A *contextual line* is one line of text or one button on a screen the player is already looking at. The *Roblox prompt* is Roblox's own purchase dialog.

| Rule | Value |
|---|---|
| First two minutes of the first session | Nothing is sold. The shop button is hidden. No price, no Robux icon and no Revive button appear anywhere. |
| Rest of the first session | The shop button appears at the second bank or after 6 minutes of account play, whichever comes first, and never in the first two minutes (chapter 04, section 3.8). Contextual lines are allowed from then. No proactive offers. No rewarded video. |
| First proactive offer | The Starter Pack card, after the first bank of the second session. Never at login. |
| Cooldown between proactive offers | 10 minutes |
| Proactive offers per session | At most 2 |
| Proactive offers per day | At most 4 |
| Same item after it is dismissed | Not again for 48 hours. After three dismissals, never proactively again. |
| Contextual lines | Each at most once per session; the Tide Watcher line at most once a day |
| During a run | No proactive offers and no shop. The only buttons with a price are Revive and Trait Lock on the gulped screen. |
| During a tide event or its warning | No proactive offers |
| After a bank | No offer for 3 seconds, so the celebration is not covered |
| Roblox prompt | Opens only after the player taps a button that shows the Robux price. Never opened by a timer, by swimming into something or by closing another panel. |
| Tap safety | A panel ignores input for 0.5 seconds after it opens. Buy buttons never sit in the dash and ability area or where a drag-to-swim touch usually starts. |
| Gulped screen | No countdown and no emptying ring: the screen stays until the player chooses (canon 5.5). Order of buttons: free revive by video (if available), Revive, Trait Lock, "Swim again". The revive buttons are absent on an account's first death, when the creature had under 30 mass, and when the run's revive is used. |
| Closing a panel | Every panel has a visible close button from the first frame. Closing never needs a second confirmation. |
| A failed or cancelled purchase | Returns the player to where they were with no message beyond "Purchase cancelled" |

Which proactive offers exist at all, each as a small card the player can tap and never as a panel that opens on its own: the Starter Pack (after a bank, in at most three sessions from the second on), Deep Pockets (once, after the tenth bank on the account) and Bigger Cove (once, the third time the cove is full). Everything else is contextual or in the shop.

## 10. Rewarded video **[L]**

A rewarded video is an advertisement the player chooses to watch for a reward. It arrives at public launch, and only if the game is eligible and only for players who are eligible (canon section 12). It is shown through `AdService`. Before showing any video button the game calls `AdService:GetAdAvailabilityNowAsync` for that player; if no advertisement is available the button is not shown at all (never greyed out). The reward is granted on the server when the video completes, through a reward created with `AdService:CreateAdRewardFromDevProductId`.

Roblox requires each video reward to be a developer product that is also sold for Robux. So the three video rewards are the three products in section 8.3: Revive, Cove Boost and Goal Reroll. Each one is on sale in the game at its listed price, with its own button. There are no hidden products, and no reward exists only as a video reward.

| ID | Placement | Reward: one unit of this product | Limit per player per day |
|---|---|---|---|
| `ad_revive` | Gulped screen, whenever the paid Revive is offered: not on the account's first death, creature of 30 mass or more, revive not yet used this run | `prod_revive` (25 R$). Counts as the run's one revive. | 3 |
| `ad_cove_boost` | Beside the Pearl clam and on the welcome-back panel | `prod_cove_boost` (29 R$): 2 hours of the cove's income at once. The button shows the exact number: "Watch: +1,240 Pearls". It uses the day's one Cove Boost. | 1 |
| `ad_goal_reroll` | Daily goals panel, after the free reroll is used | `prod_goal_reroll` (19 R$): swaps one daily goal | 1 |
| | **All placements together** | | **5** |

Other limits: at least 3 minutes between videos; never during a run except on the gulped screen; never in the first session.

**Eligibility notes.** The rewarded video documentation page could not be opened on 13 October 2026 (the address returned "not found"), so eligibility is unverified. The `AdService` reference describes these as mobile video advertisements and leaves the decision to Roblox per player. This chapter assumes that many players will not be eligible, including most under-13 players and possibly all players off phones. For that reason nothing important sits behind a video: every player gets one free goal reroll a day, and a Cove Boost is 2 hours of income, 12.5% on top of the 16 hours a regular player collects in a day.

**Expected earnings.** The only figure available is a third-party estimate of about 2 to 4 US dollars per 1,000 views to the creator. It is not confirmed by Roblox.

| Scenario | Views per daily user (assumption) | US dollars per 1,000 views (third-party estimate) | Per 12,000 daily users, per month |
|---|---|---|---|
| Weak | 0.10 | 2 | 36,000 views, $72 |
| Base | 0.25 | 3 | 90,000 views, $270 |
| Strong | 0.50 | 4 | 180,000 views, $720 |

Rewarded video is a small line. Its main value is to give players who will never pay a way to revive.

## 11. Revenue model

### 11.1 Assumptions

**No official Roblox benchmark was found for any of these.** Each is an assumption and is marked so.

| Input | Weak | Base | Strong | Status |
|---|---|---|---|---|
| Daily users per average concurrent player | 60 | 60 | 60 | Assumption. Follows from 24 minutes of play per daily user per day: 1,440 ÷ 24 = 60. |
| Share of daily users who buy something that day | 0.4% | 0.8% | 1.6% | Assumption |
| Robux spent per buyer per day | 90 | 130 | 190 | Assumption |
| Robux spent per daily user per day (the two rows above multiplied) | 0.36 | 1.04 | 3.04 | Derived |
| Creator share of Robux spent | 70% | 70% | 70% | Read from the Creator Hub on 13 October 2026 as a general figure (section 8.1) |
| Developer Exchange rate | $0.0038 per earned Robux | same | same | Verified platform fact. Minimum cash-out 30,000 earned Robux. |
| Share of daily users who qualify for Creator Rewards that day | 2% | 5% | 8% | Assumption. A qualifying user is an active spender on Roblox who plays 10 minutes or more. The rate of 5 Robux per qualifying user per day is a verified platform fact. |
| Rewarded video views per daily user per day | 0.10 | 0.25 | 0.50 | Assumption |
| US dollars per 1,000 rewarded views | 2 | 3 | 4 | Third-party estimate, not confirmed |
| Days in a month | 30 | 30 | 30 | — |

**A cross-check on spend.** Roblox reported 1,557 million US dollars of bookings and 29 billion hours for the second quarter of 2026. That is about 0.054 dollars per hour of play across the whole platform, avatar shop included. A daily user who plays GULP for 24 minutes would then be "worth" about 0.021 dollars a day, or roughly 1.7 Robux at about 0.0125 dollars per Robux bought (the retail price of Robux is an assumption here). The base case of 1.04 Robux is 60% of that platform average, the weak case 21% and the strong case 177%. This is our own arithmetic, not a Roblox figure. Roblox's letter for that quarter also says newer games earn less per hour than older ones, which is why the base case sits below the average.

### 11.2 Scenarios

```
dailyUsers       = averageConcurrent × 60
robuxSpentMonth  = dailyUsers × robuxPerDailyUser × 30
earnedRobuxMonth = robuxSpentMonth × 0.70
purchaseDollars  = earnedRobuxMonth × 0.0038
rewardsRobux     = dailyUsers × qualifyingShare × 5 × 30      (paid as earned Robux, no platform share taken)
videoDollars     = dailyUsers × viewsPerUser × 30 ÷ 1,000 × dollarsPer1000
```

| Average CCU | Scenario | DAU | Payers/day | Robux spent/day | Robux spent/month | Earned Robux/month (70%) | Purchases USD/month | Creator Rewards Robux/month | Creator Rewards USD/month | Rewarded video USD/month | **Total USD/month** | Total USD/year |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 20 | Weak | 1,200 | 5 | 432 | 12,960 | 9,072 | $34 | 3,600 | $14 | $7 | **$55** | $664 |
| 20 | Base | 1,200 | 10 | 1,248 | 37,440 | 26,208 | $100 | 9,000 | $34 | $27 | **$161** | $1,929 |
| 20 | Strong | 1,200 | 19 | 3,648 | 109,440 | 76,608 | $291 | 14,400 | $55 | $72 | **$418** | $5,014 |
| 200 | Weak | 12,000 | 48 | 4,320 | 129,600 | 90,720 | $345 | 36,000 | $137 | $72 | **$554** | $6,642 |
| 200 | Base | 12,000 | 96 | 12,480 | 374,400 | 262,080 | $996 | 90,000 | $342 | $270 | **$1,608** | $19,295 |
| 200 | Strong | 12,000 | 192 | 36,480 | 1,094,400 | 766,080 | $2,911 | 144,000 | $547 | $720 | **$4,178** | $50,140 |
| 1,000 | Weak | 60,000 | 240 | 21,600 | 648,000 | 453,600 | $1,724 | 180,000 | $684 | $360 | **$2,768** | $33,212 |
| 1,000 | Base | 60,000 | 480 | 62,400 | 1,872,000 | 1,310,400 | $4,980 | 450,000 | $1,710 | $1,350 | **$8,040** | $96,474 |
| 1,000 | Strong | 60,000 | 960 | 182,400 | 5,472,000 | 3,830,400 | $14,556 | 720,000 | $2,736 | $3,600 | **$20,892** | $250,698 |
| 5,000 | Weak | 300,000 | 1,200 | 108,000 | 3,240,000 | 2,268,000 | $8,618 | 900,000 | $3,420 | $1,800 | **$13,838** | $166,061 |
| 5,000 | Base | 300,000 | 2,400 | 312,000 | 9,360,000 | 6,552,000 | $24,898 | 2,250,000 | $8,550 | $6,750 | **$40,198** | $482,371 |
| 5,000 | Strong | 300,000 | 4,800 | 912,000 | 27,360,000 | 19,152,000 | $72,778 | 3,600,000 | $13,680 | $18,000 | **$104,458** | $1,253,491 |

Per average concurrent player, per month: about **2.77 US dollars (weak), 8.04 (base) and 20.89 (strong)**.

### 11.3 What this means

- **Most Roblox creators earn little.** The median creator enrolled in the Developer Exchange was reported to have earned about 1,500 US dollars in the 12 months to 30 June 2026, which is 125 dollars a month. In the base case that is the income of a game averaging about **16 concurrent players**. The same report puts the top 1,000 creators at an average of 1.4 million dollars. The spread is extreme and the expected outcome for a new game is near the bottom of it.
- **200 average concurrent players is already a good result**, well above the median creator. It pays about 550 to 4,200 dollars a month in this model, most likely about 1,600.
- **A living wage needs about 1,000 average concurrent players** at base-case spending (about 8,000 dollars a month before tax and before any spending on advertising).
- The 20-player row is there because it is the most likely outcome for any new game. In the weak case it takes more than two months to reach the 30,000 Robux cash-out minimum.
- Creator Rewards are held for 60 days before they can be cashed out.
- Not modelled: money spent on Roblox advertising, taxes, tools and assets, the higher exchange rate that applies to some sales to verified adult players in the United States, and Roblox's Audience Expansion reward.
- Retention drives all of it. Roblox's discovery system gives more impressions to games players return to. Section 5 exists so that a free player always has a reason to come back tomorrow; that matters more to revenue than any price in section 8.

## 12. Price testing plan

**Tools.** Roblox's price optimisation tool tests prices for passes and developer products by itself: it shows different players different prices for about three weeks, recommends a price, and then reviews it for four more weeks. It needs about 60,000 transactions in the previous 30 days and prices read at run time (Creator Hub, read 13 October 2026). GULP will not qualify until it is large; in the base case that is roughly 4,000 average concurrent players. Until then tests are run by hand.

**Method by hand.**

- One item at a time. One price change, held for 14 days, compared with the 14 days before. No game update that touches the economy during a test.
- A test needs at least 200 purchases of the item in each period. Below that, keep the price and wait.
- Split tests (two product IDs at two prices, players assigned by user ID) are used only for consumable developer products, and only after checking that Roblox's current rules allow it. Passes are tested one price after another, never split, so two friends never see different prices for the same permanent item.
- Never raise the price of something a player was shown at a lower price in the same session.

**The measure that decides:** Robux earned from that item per 1,000 daily users per day. Conversion alone does not decide, because a lower price nearly always converts better. A change is kept only if this measure rises by 10% or more **and** day-1 retention, day-7 retention and median session length are each no more than one percentage point (or 5% for session length) worse.

| Order | Item | Prices to test (R$) | Why in this place | Extra thing to watch |
|---|---|---|---|---|
| 1 | Revive | 19, 25, 35 | The most purchases per day, so the fastest answer. Consumable, so a split test is possible. | Share of gulped screens that end in a revive |
| 2 | Starter Pack | 79, 99, 149 | The first purchase most payers make; it sets how many players ever pay | Share of players who buy anything within 7 days |
| 3 | Deep Pockets | 249, 299, 399 | The first pass shown. 399 was the first-draft canon anchor, so the test also checks the change made here. | Share of new players who buy a pass within 3 days |
| 4 | Bigger Cove | 299, 349, 449 | The strongest permanent pass | Purchases at the "cove is full" dialog |
| 5 | Small and medium Pearl packs | Same prices; Pearl amounts −20%, as listed, +20% | Tests the amount, which is easier to change than the price | Spend per buyer over 14 days |
| 6 | Shark Pup pass | 399, 499, 599 | Needs players who have seen the Shark Pup, so it waits for public launch | Share of players at Squid or beyond who buy |
| 7 | Tide Watcher, Keen Nose, Call the Tide, Trait Lock, Cove Boost, Goal Reroll | 199 / 249 / 299; 149 / 199 / 249; 79 / 99 / 149; 15 / 19 / 25; 19 / 29 / 39; 15 / 19 / 25 | Lower volume; test when the first six are settled | For Cove Boost and Goal Reroll: paid uses against video uses |
| 8 | Patterns | Move one pattern between bands | Last: cosmetic demand depends on how many players own each species | Patterns owned per payer |

Every test result is written into this chapter and the canon table is updated.

## 13. Post-launch monetisation options

**Season pass ("Tide Pass") [P1].** A 28-day track of about 30 steps earned by play, with a free row for everyone and a paid row at about 399 R$. The paid row would hold patterns, decorations and a modest amount of Pearls (no more than one extra-large pack over the season); the free row would hold Pearls and one decoration. It gives a repeat purchase that packs and passes cannot, and it gives the weekly update cadence a spine. It also adds a monthly content bill of at least four patterns and six decorations, which is heavy for one developer. **Recommendation:** build it in the first month after launch only if day-7 retention is at or above the median for similar games, and never let it end with a countdown that takes earned rewards away; unclaimed steps stay claimable for a week after the season.

**Subscriptions [P2].** Roblox supports monthly subscriptions inside a game, priced in real currency. A "Cove Club" at the lowest price tier could bundle the 24-hour cap, one free Call the Tide a week and a monthly pattern. Subscriptions were not researched for this chapter and their terms are unverified. They also ask a young player, or a parent, for a recurring payment, and they would overlap with Tide Watcher. **Recommendation:** do not build before the game holds 1,000 average concurrent players for a month. If built, it must not include anything already sold as a pass, and cancelling must be as easy as joining.

**Paid random items [P2].** A "mystery shell" that gives a random pattern would probably earn more than fixed-price patterns. The canon rules it out at launch, and it conflicts with pillar 2 ("nothing important comes from a random egg"). If it is ever built, the compliance work is: show every possible outcome and its odds as percentages that total exactly 100% on the purchase screen itself, not behind an information icon; do the same when the item is bought with Pearls that were bought with Robux; call `PolicyService:GetPolicyInfoForPlayerAsync` for every player and hide the item entirely when `ArePaidRandomItemsRestricted` is true; give restricted players another route to the same items (direct purchase or free earning); log every roll on the server; keep the odds in one server-side table that the interface reads, so the shown odds can never differ from the real ones; and re-check the questionnaire answers for the maturity label. **Recommendation:** do not build it. If revenue forces the question, limit it to cosmetics, add a guaranteed pick after a fixed number of rolls, and sell every item directly as well.

**Trading fees [P2].** When specimen trading arrives, each trade can charge both sides a Pearl fee of 10% of the specimen's 24-hour income (58 Pearls for a 24 Pearls/h specimen, 691 for the best possible one). The fee is a Pearl sink, not a Robux product: charging Robux to trade invites scams aimed at children and turns specimens into something with a cash value. The compliance work is to check `IsPaidItemTradingAllowed` from `PolicyService` for both players, to add a two-step confirmation that shows both sides of the trade, a cooling-off delay, and a trade log, and to block trading of anything bought with Robux. **Recommendation:** ship trading with a Pearl fee only, and only after the Pearlescent variants give players something worth trading.

**Limited patterns [P1].** Seasonal patterns sold for a set window (for example two weeks around a real-world holiday) at the Bold or Showpiece price, returning every year. They cost little to make and give lapsed players a reason to return. The risk is pressure on young players. **Recommendation:** do it, with three rules: the end date is shown as a plain date, not a ticking timer; the pattern is promised to return the next year; and there is never a numbered stock or a "only 50 left" counter.

## 14. Compliance checklist for selling to a young audience on Roblox

Selling and prompts:

- [ ] Nothing is sold, priced or prompted in the first two minutes of a first session.
- [ ] Every Roblox prompt follows a tap on a button that shows the price in Robux.
- [ ] Every item's description states exactly what it gives, in numbers, and matches what the server grants.
- [ ] All prices and names come from `MarketplaceService:GetProductInfo` at run time.
- [ ] No timers, numbered stock, "last chance" wording or decline-shaming on any offer.
- [ ] Buy buttons are away from swim, dash and ability touch areas; panels ignore input for 0.5 seconds after opening.
- [ ] The prompt limits in section 9 are enforced in code and logged.
- [ ] Only Roblox's purchase flow is used. No links, codes or references to buying anything outside Roblox.

Granting and records:

- [ ] `ProcessReceipt` grants each developer product exactly once, saves the purchase ID with the profile before returning "granted", and returns "not processed yet" on any save failure.
- [ ] Game pass ownership is checked on the server at join and after a purchase, never trusted from the client.
- [ ] One-time products (Starter Pack, patterns, Robux decorations) are refused on the server if already owned, and the buy button is hidden.
- [ ] The daily limits are enforced on the server: five Pearl packs, one Cove Boost (paid or video), three paid Goal Rerolls.
- [ ] A purchase that fails because of a parental spending limit or account restriction ends quietly with no retry prompt.
- [ ] Every purchase, grant and refusal is logged with player, item, price and time.

Random items, trading and policy:

- [ ] The game contains no paid random items. Nothing bought with Robux, or with Pearls, has a random result.
- [ ] If that ever changes: all outcomes and odds shown as percentages totalling exactly 100%, and `ArePaidRandomItemsRestricted` checked per player (section 13).
- [ ] No trading at launch. When it arrives: `IsPaidItemTradingAllowed` checked per player.
- [ ] `PolicyService:GetPolicyInfoForPlayerAsync` is called once per player at join and its answers are stored for the session.

Advertising:

- [ ] Rewarded video is shown only through `AdService`, only after an availability check for that player, and only when the player taps a button that says it is a video.
- [ ] Every video reward is a developer product that is also on sale for Robux in the game (Revive, Cove Boost, Goal Reroll). No hidden products.
- [ ] No video plays automatically. No reward is granted unless the video completes. The limits in section 10 are enforced on the server.
- [ ] Nothing needed for progress sits behind a video.
- [ ] Eligibility rules for rewarded video are re-read on the Creator Hub before the feature ships (they could not be verified for this chapter).

Content and audience:

- [ ] The Maturity and Compliance questionnaire is answered for the most mature thing a player can meet, and re-answered after any content change. Target: the lowest label that fits (canon section 1).
- [ ] The game needs no chat. No offer, goal or reward asks a player to chat, add friends, join a group or leave the platform.
- [ ] No personal information is asked for or stored. Saves hold game data only.
- [ ] The store page, icon and thumbnails show nothing that is only available by paying without saying so.
- [ ] Rewards never depend on real-money spend elsewhere, and no reward is taken away for missing a day.

Review:

- [ ] This list is checked before the soft launch, before the public launch and before every update that touches the shop.
- [ ] Roblox's monetisation rules have changed several times in the last year. The pages named in sections 8.1, 10 and 12 are re-read before each of those checks.

## 15. Numbers that differ from the first draft of the canon (now adopted)

The canon was updated after this chapter was written and now carries every value in the first table. Nothing in it is an open difference. It is kept as a short record of what moved and why.

| Item | First draft of the canon | Now, in the canon and here | Reason |
|---|---|---|---|
| Cove income per hour, tiers 2 to 7 | 20, 40, 80, 160, 320, 640 | 6, 10, 18, 30, 50, 80 | The first draft gave the Shark Pup on day 11, not day 30 (section 5.5) |
| Trait bonus to cove income | +25%, +50%, +100%, +200%, +400% | +10%, +20%, +35%, +60%, +100% | Same pacing miss |
| Banking | Mass × 3, no limit | × 3 to 1,200 mass, × 1 to 3,000, nothing above | A Leviathan is very hard to eat (section 6.1) |
| Deep Pockets / Bigger Cove / Tide Watcher / Keen Nose | 399 / 249 / 299 / 349 R$ | 299 / 349 / 249 / 199 R$ | Priced by what each adds in the model (section 8.2) |
| Trait Lock / Call the Tide | 35 / 149 R$ | 19 / 99 R$ | Section 8.3 |
| Video reward "double an offline claim" | Doubled the claim | Replaced by Cove Boost: 2 hours of cove income, once a day, also sold for 29 R$ | Roblox requires a video reward to be a product; a full double was too much |
| Reef Rank input | "Lifetime Pearls banked" | Base banking and scraps, before any pass multiplier | So rank cannot be bought or idled |
| Bigger Cove limit | Not stated | 40 slots | Defines the cove's income ceiling |

Details this chapter sets that the canon leaves to it, so they are not differences: the prices of Cove Boost (29 R$) and Goal Reroll (19 R$); Nursery prey mass by the eater's tier (100%, 50%, 0%); trait prey masses; 60 Marrow chunks and 40 Lunar Fry per event; the amounts for Codex rewards, Reef Rank rewards, the tide bonus and the release refund; reward bands R1 to R5 (section 3.12) and decoration bands D1 to D4 (section 4.3).

**Open points.** One: canon section 16 should note that patterns and Robux decorations are sold under their content IDs, without the `prod_` prefix (section 8.5). The two earlier points are settled: canon section 12 now notes the three Robux decorations, the Golden Chest in the Starter Pack and the six free Codex patterns, and chapter 03, section 1.3 copies this chapter's pattern sources (no pattern is sold for Pearls).

Where chapter 03's reward bands, shelf ranks and tags differ from this chapter, section 3.12, section 4.3 and section 7 say which value applies.
