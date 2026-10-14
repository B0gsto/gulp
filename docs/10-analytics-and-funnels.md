# 10 · Analytics and funnels

This chapter says what GULP measures, with which tool, under which event name, and what we do with each number. It serves canon section 17 (success measures) and the canon's go/no-go rule. Names, IDs and numbers come from `01-game-canon.md`. The first-time experience it measures is scripted in `04-first-two-minutes.md`.

Numbers marked **(tune)** are first guesses. Every target in this chapter is our own target, not a Roblox benchmark, unless it says otherwise. Everything is **[MVP]** unless a tag says otherwise.

**Clocks:** **T** is seconds since the player first had control of the creature. Every success measure and every time mark in this chapter runs on T (canon section 17). **J** is seconds since the server saw the player join (`PlayerAdded`); it is used only to measure load time (`sys_load_time`). A **day** is a UTC calendar day.

## 1. What we measure and why

### 1.1 The questions

| # | Question | Why it matters | Where the answer comes from |
|---|---|---|---|
| 1 | Do new players get through the first two minutes? | Roblox counts a first play that ends in under 60 seconds, or at 61 to 180 seconds, as a bounce, and bounces reduce recommendations. | Onboarding funnel, `fs_time_mark`, Roblox's "New User First Session Retention" chart |
| 2 | Do they come back? | Play days per user is a discovery signal, and day-1 retention is half of our go/no-go rule. | Roblox Retention page, `ret_day` |
| 3 | How long do they play each day? | Playtime per user is a discovery signal, counted up to 60 minutes per user per game per day. Session time is the other half of the go/no-go rule. | Roblox Engagement page, `sess_day_mark` |
| 4 | Is the run loop fair? | A run that is too deadly loses players; one that is too safe has no tension. | Run funnel, `run_banked`, `run_gulped`, `run_gulped_by` |
| 5 | Is the Pearl economy inflating? | Species prices pace the first 30 days (canon section 7). If Pearls come too fast, the pacing collapses. | Economy events |
| 6 | Does it earn? | Revenue pays for the project. Creator Rewards also pays for each spender who plays 10 minutes or more. | Roblox Monetization page, purchase funnels, `sess_day_mark` = `m10` |
| 7 | Do tide events bring players back on the clock? | Pillar 5. | Tide funnel, concurrent players by minute of the hour |
| 8 | Does the store page convert impressions into plays? | Play-through rate from impressions is the first discovery signal Roblox names. | Roblox Acquisition page (Home Recommendations). No in-game event can measure this. |

### 1.2 Canon success measures and their events

| Canon measure (section 17) | Target | Measured by | Formula |
|---|---|---|---|
| First bite within 10 seconds of control | 90% | `ftue_milestone` with ctx `bite_le5` or `bite_le10` | Unique users with either ÷ unique users at onboarding step `03_control` |
| Reach tier 2 within 45 seconds | 75% | `ftue_milestone` with ctx `tier2_le30` or `tier2_le45` | Same form |
| Still playing at 60 seconds | 80% | `fs_time_mark` with ctx `s60` (T = 60) | Unique users ÷ unique users at step `03_control` |
| Still playing at 180 seconds | 65% | `fs_time_mark` with ctx `s180` (T = 180) | Same form |
| Bank the first creature | 60% | Onboarding step `13_banked` | Step 13 ÷ step 03 |
| Start a second run in the first session | 50% | Onboarding step `17_run2_started` | Step 17 ÷ step 03, first session only (cohort `s1`) |
| Still playing at 10 minutes in the first session | 50% | `fs_time_mark` with ctx `m10` (T = 600) | Same form |

Every share is of players who reached control, because every clock starts there. Players lost before control are outside these measures; they show in onboarding steps 1 to 3 and in `sys_load_time`.

### 1.3 Roblox's discovery signals and what we can see

| Signal (from Roblox's discovery documentation, as recorded in our research notes) | Where we read it | Our lever |
|---|---|---|
| Play-through rate from impressions | Acquisition → Home Recommendations | Icon, thumbnails, title. Outside this chapter. |
| Play days per user | Retention page; `ret_day` | Cove income, daily goals, streak, tide clock |
| Playtime per user, capped at 60 minutes a day | Engagement page; `sess_day_mark` = `m10`, `m30`, `m60` | Run length, tide events every 15 minutes |
| First-play bounce under 60 s, and at 61 to 180 s | "New User First Session Retention" chart; `fs_time_mark` = `s60`, `s180` | Chapter 04 |

Our T clock starts at control, later than Roblox's session clock: we cannot see the time between the tap on Play and `PlayerAdded`, and the load time (`sys_load_time`) comes on top of it. So our `s60` and `s180` shares will read better than Roblox's own bounce figures, by about the load time. Roblox's chart is the one that counts for discovery; ours checks the canon targets and lets us split by experiment and by funnel step.

**Go/no-go (canon):** once the game has 100 or more daily users, Roblox shows percentile benchmarks against similar games. We go to public launch only if day-1 retention and average session time are at or above the similar-game median on Roblox's own pages. Roblox shows a new game only to age-checked players aged 16 and over until it passes an evaluation, so the go/no-go is read only after younger players can play (chapter 12, stage 3b). Numbers from the evaluation phase (stage 3a) describe players of 16 and over, who are not the core audience: we use them to find bugs and broken funnel steps, not to judge targets.

## 2. Tooling

### 2.1 What we use

| Tool | Used for | Tag |
|---|---|---|
| Roblox analytics dashboard (Creator Hub) | Retention, engagement, acquisition, monetisation, benchmarks, performance | [MVP] |
| `AnalyticsService` funnel events | The onboarding funnel and nine recurring funnels | [MVP] |
| `AnalyticsService` economy events | Every Pearl source and sink | [MVP] |
| `AnalyticsService` custom events | Everything else (61 event names) | [MVP] |
| Creator Hub "Explore" | Our own charts built from custom events | [MVP] |
| Roblox Experiments with `ConfigService` | A/B tests | [MVP] |
| Roblox Alerts (beta) | Crash and frame-rate alarms | [L] (needs 100 or more daily users, per a DevForum post) |
| A spreadsheet | Weekly review log, manual significance tests | [MVP] |

We use no third-party analytics service and send no player data outside Roblox.

### 2.2 API, as verified on 13 October 2026

Signatures are as listed on the `AnalyticsService` class reference on create.roblox.com.

```luau
AnalyticsService:LogOnboardingFunnelStepEvent(player: Player, step: number, stepName: string, customFields: Dictionary = nil)
AnalyticsService:LogFunnelStepEvent(player: Player, funnelName: string, funnelSessionId: string, step: number = 1, stepName: string, customFields: Dictionary = nil)
AnalyticsService:LogEconomyEvent(player: Player, flowType: Enum.AnalyticsEconomyFlowType, currencyType: string, amount: number, endingBalance: number, transactionType: string, itemSku: string, customFields: Dictionary = nil)
AnalyticsService:LogCustomEvent(player: Player, eventName: string, value: number = 1, customFields: Dictionary = nil)
```

`flowType` is `Enum.AnalyticsEconomyFlowType.Source` or `.Sink`. `itemSku` is optional; without it the dashboard shows "N/A".

Custom fields are a dictionary keyed by `Enum.AnalyticsCustomFieldKeys.CustomField01.Name`, `CustomField02.Name` and `CustomField03.Name`. Values must be strings. Any other key is ignored.

A/B tests read values with `ConfigService:GetConfigForPlayerAsync(player)` and then `snapshot:GetValue(key)`. `ConfigService:GetConfigAsync()` does not apply experiments.

### 2.3 Limits

| Limit | Value | Status | How GULP stays inside it |
|---|---|---|---|
| Where events can be sent from | Server only, published games only. Not the client, not Studio. | Verified | All logging goes through one server module (2.4) |
| Request rate | 120 + (20 × concurrent players) requests per minute across funnel, economy and custom events | Verified. Whether it is counted per game or per server is not stated; we assume per game. | Budget of 16 events per player per minute per server (2.4). Expected use: about 12 per minute in the FTUE, about 4 per minute afterwards. |
| Funnels | 10 | Verified. Whether the onboarding funnel counts as one of the 10 is not stated; we assume it does. | Exactly 10 (section 3) |
| Steps per funnel | 100 | Verified | Longest is 20 |
| Skipped steps | Logging a later step completes all earlier steps automatically | Verified | Funnels contain only steps that always happen in order. Time marks and unordered milestones are custom events. |
| Repeated steps | Only the first instance counts; repeats still use the rate limit | Verified | The module remembers the highest step sent per funnel session and drops repeats |
| Recurring funnel sessions | The 10 most recent `funnelSessionId` values per user per funnel are tracked; an older ID counts as a new session | Verified | Session IDs are never reused |
| Saved funnel step expiry | 180 days with no events for that funnel | Verified | No action |
| Custom event names | 100 | Verified | 61 used; 39 spare |
| Custom fields | 3 | Verified | Fixed meaning for each (2.4) |
| Custom field values | 8,000 unique combinations across the three fields; beyond that, values are grouped as "Other" | Verified | Worst case 6,368 (2.4) |
| Currencies | 10 on the limits page; 5 on the economy events page | The two pages disagree | We use 1 (`Pearls`) |
| Transaction types | Unlimited; beyond 20 grouped as "Other" | Verified | 16 |
| Item SKUs | Unlimited; beyond 100 grouped as "Other" | Verified | 70 at launch (section 5) |
| Economy amount | Always positive, for sources and sinks alike | Verified | Enforced in the module |
| Data delay, custom events | Aggregated daily; up to 24 hours | Verified | Nothing in this chapter depends on same-day custom-event data |
| Data delay, funnel and economy events | — | Not stated on the pages read | Assume 24 hours |
| Data lifetime | Events roll off 90 days after the last data received; limits reset daily | Verified | Weekly figures are copied into the review spreadsheet |
| Dashboard access | More than 10 daily users and 10 play hours for 7 consecutive days for all KPIs | Verified | — |
| Benchmarks | Shown against similar games with at least 100 daily users | Verified | Go/no-go waits for this, and for Roblox's evaluation to pass (1.3) |
| Experiments | Up to 2 variants plus a control; 14 to 60 days; one running experiment per config key; early-harm checks need 10,000 players across the arms; games under 1,000 daily users "might struggle to get useful data" | Verified | Section 8 |
| Alerts | Beta; up to 20 per game; performance metrics such as client crash rate and client frame rate; delivered by webhook | Seen in search summaries of the Alerts page, page not read in full | Section 9 |

### 2.4 The Analytics module

One server module (`Analytics`; document 09 owns its location) is the only code that calls `AnalyticsService`. Everything else calls the module.

| Call | Sends |
|---|---|
| `Analytics.step(player, funnel, sessionId, stepNumber)` | A funnel step. `funnel = "onboarding"` uses `LogOnboardingFunnelStepEvent`. Step names come from the tables in section 3. |
| `Analytics.event(player, name, value, ctx)` | A custom event |
| `Analytics.pearls(player, flow, amount, balance, transactionType, sku)` | An economy event with currency `Pearls` |

**Custom fields.** The module fills all three on every call.

| Field | Name here | Contents | Distinct values |
|---|---|---|---|
| `CustomField01` | `exp` | The player's experiment arms, for example `chase=escort`. Attached only to events listed for that experiment; otherwise `none`. | 5 at most at one time |
| `CustomField02` | `cohort` | `s1` (first session), `d0` (first day, later session), `d1_6` (1 to 6 days after the first play day), `d7p` (7 or more) | 4 |
| `CustomField03` | `ctx` | The event's one context value, as given in the event dictionary (section 4) | 392 at most: 300 across the events that can carry an experiment arm, and 92 on the five device and input events (4.2), which never carry one |

Worst case 300 × 4 × 5 + 92 × 4 = 6,368 combinations, under the 8,000 limit: the device and input events always send `exp` = `none`, so their 92 values multiply only by the 4 cohorts. A new `ctx` value needs a line in section 4 first.

**What never goes in a custom field:** user IDs, user names, display names, chat text, free text of any kind, or any number with more than a handful of possible values. Numbers go in `value`.

**Rate budget.** Each server keeps a token bucket of 16 events per player per minute. When it is empty the module drops events by priority: P2 first (settings, Codex, hazard hits, `sess_device`, `perf_tier`, `input_switch`), then P1 (run events, including `run_end_input` and `pvp_pair`), never P0 (onboarding steps, purchases, economy). Drops are counted and reported once a minute as `guard_flag` with ctx `analytics_drop`.

**Studio and tests.** `AnalyticsService` does not accept events from Studio, so in Studio the module writes each call to an in-memory buffer of the last 2,000 events and prints it when `Analytics.debugPrint = true`. Automated tests and the chapter 04 checklist read this buffer.

**No per-bite events.** Bites, dashes and position are never logged one by one. They are counted on the server and sent as a value on a run-end event.

### 2.5 What was and was not verified

"Verified" means the create.roblox.com page was fetched on 13 October 2026 and the detail was on it. The pages were read through an automated fetch-and-summarise tool, not by eye, so re-check any limit on the live page before code depends on it.

| Detail | Status |
|---|---|
| The four method signatures in 2.2 | Verified on the class reference page |
| `LogProgressionEvent`, `LogProgressionStartEvent`, `LogProgressionCompleteEvent`, `LogProgressionFailEvent`, `GetPlayerSegmentsAsync` exist and are not deprecated | Verified on the class reference page. The progression guide page returned "not found" and no limits were found, so GULP does not use them in the MVP. |
| `LogJourneyEvent` | Listed in the class reference page's summary; a separate search did not confirm it. Not used. |
| Every row marked "Verified" in 2.3 | Verified on the funnel events, economy events, custom events, custom fields, event limits, analytics dashboard and Experiments pages |
| Default transaction types: `IAP`, `TimedReward`, `Onboarding`, `Shop`, `Gameplay`, `ContextualPurchase`; custom names allowed | Verified |
| Retention: day 1 is the share of a day's new users who return the next day; the day-7 and day-30 sections describe return "on the 8th day" and "on the 31st day"; daily cohort charts cover 10 days | Verified. The time zone is not stated. |
| Average session time = total time in the game ÷ number of sessions | Verified |
| Conversion rate = share of daily users who are paying users; ARPPU and ARPDAU named | Verified. Formulas and time windows are not stated. |
| Experiments report day-1 retention, day-7 retention, playtime, ARPU, ARPPU, payer conversion rate and session time, as a percent change with a confidence interval | Verified. The confidence level is not stated. |
| Alerts feature | Search summary only (2.3) |
| Rewarded video calls (`AdService:GetAdAvailabilityNowAsync`, `AdService:CreateAdRewardFromDevProductId`, `AdService:ShowRewardedVideoAdAsync`) | Seen in search summaries of translated reference pages; the English page was not read |
| Rewarded video eligibility | Not verified. The last official statement found (August 2025, DevForum) limited it to games averaging 100,000 or more daily users, with wider access "planned". |
| `MarketplaceService` and `PolicyService` details used in sections 3 and 10 | From memory, not re-checked for this chapter |
| Roblox's discovery signals | Not re-checked for this chapter; taken from `research/viability-report.md` |

## 3. Funnels

**How to read the tables.** "Sent as" is the step number in a Roblox funnel, or the custom event that carries the step. "Target" is the conversion from the previous step unless a column says cumulative. All targets are **(tune)** except those copied from canon section 17.

**The ten Roblox funnels**

| # | Funnel name | Type | `funnelSessionId` | Section | Tag |
|---|---|---|---|---|---|
| 1 | Onboarding | One-time | — | 3.1 | [MVP] |
| 2 | `run` | Recurring | Run ID (a GUID made at hatch) | 3.2 | [MVP] |
| 3 | `species_unlock` | Recurring | `<userId>-<speciesId>` | 3.5 | [MVP] |
| 4 | `trait` | Recurring | `<runId>-<traitId>` | 3.6 | [MVP] |
| 5 | `tide_event` | Recurring | `<userId>-<eventStartUnix>` | 3.7 | [MVP] |
| 6 | `shop_purchase` | Recurring | A GUID per shop visit or offer | 3.8 | [MVP] |
| 7 | `revive_offer` | Recurring | Run ID | 3.9 | [MVP] |
| 8 | `rewarded_video` | Recurring | A GUID per placement shown | 3.10 | [L] |
| 9 | `cove_visit` | Recurring | `<visitorId>-<ownerId>-<utcDate>` | 3.11 | [L] |
| 10 | `starter_pack` | Recurring | `<userId>-sp` | 3.12 | [L] |

The first-session funnel (3.3) and the return funnel (3.4) are built from custom events, because their steps do not happen in a fixed order.

### 3.1 First-time experience funnel (onboarding, one-time)

Steps match the beats in chapter 04, section 3.4. Each fires once per account.

| Step | Step name | Fires when | Target from previous | Cumulative from step 03 |
|---|---|---|---|---|
| 1 | `01_joined` | Profile loaded and `ftue.completed = false` | — | — |
| 2 | `02_loading_screen` | The client reports the first frame of our loading screen | 97% | — |
| 3 | `03_control` | Control granted (T = 0) | 95% | 100% |
| 4 | `04_first_input` | First drag of 0.2 s or more, or first movement key or stick input | 97% | 97% |
| 5 | `05_first_bite` | First prey eaten. If the bite came before any input, the step is held until the first input. | 98% | 95% |
| 6 | `06_mass_5` | Mass reaches 5 | 96% | 91% |
| 7 | `07_tier2` | Tier 2 (Nibbler) reached | 95% | 87% |
| 8 | `08_glowfry_1` | First scripted trait prey eaten | 96% | 83% |
| 9 | `09_trait_gained` | First trait gained | 96% | 80% |
| 10 | `10_left_nursery` | Player crosses the Gap | 95% | 76% |
| 11 | `11_channel_cleared` | The chase ends, or in the `escort` variant the player reaches the end of the channel | 96% | 73% |
| 12 | `12_cove_in_sight` | Player comes within 120 studs of their own cove mouth | 94% | 69% |
| 13 | `13_banked` | First bank confirmed by the server | 93% | 64% (canon: 60% or more) |
| 14 | `14_specimen_placed` | The specimen is created in slot 1 | 99% | 63% |
| 15 | `15_first_tick` | The first income tick is paid | 99% | 62% |
| 16 | `16_cliffhanger_seen` | The Pufferfish silhouette is shown, in the cove or as a HUD ping | 99% | 62% |
| 17 | `17_run2_started` | Player leaves the cove mouth for the second run | 85% | 53% (canon: 50% or more) |
| 18 | `18_run2_tier2` | Tier 2 reached in run 2 | 90% | 47% |
| 19 | `19_run2_ended` | Run 2 ends by bank or gulp | 92% | 44% |
| 20 | `20_run3_started` | Player leaves the cove mouth for the third run | 80% | 35% |

Timed versions of these steps (bite within 10 s, tier 2 within 45 s, and so on) are carried by `ftue_milestone`, because a funnel step has no time limit.

A drop of 10 points or more at one step from one day to the next, on 200 or more new users, almost always means a bug in that beat rather than a design problem.

### 3.2 Run funnel (`run`, recurring)

One funnel session per run. Run 1 of an account is not logged here; the onboarding funnel covers it.

| Step | Step name | Fires when | Target from previous | Cumulative |
|---|---|---|---|---|
| 1 | `01_hatched` | A Fry gets control | — | 100% |
| 2 | `02_left_safe` | First exit from a cove or the Nursery | 95% | 95% |
| 3 | `03_first_bite` | First prey eaten | 98% | 93% |
| 4 | `04_tier2` | Tier 2 reached (Shark Pup fires steps 1 to 4 at hatch) | 85% | 79% |
| 5 | `05_tier3` | Tier 3 reached | 65% | 51% |
| 6 | `06_tier4` | Tier 4 reached | 50% | 26% |
| 7 | `07_tier5` | Tier 5 reached | 40% | 10% |
| 8 | `08_tier6` | Tier 6 reached | 35% | 3.6% |
| 9 | `09_tier7` | Tier 7 reached | 30% | 1.1% |

The funnel shows how far runs get. How they end is carried by three custom events, because a run can end at any tier.

| Outcome | Event | Value | ctx | Target share of ended runs |
|---|---|---|---|---|
| Banked | `run_banked` | Final mass | `t1` to `t7` (tier at the end) | 45%, acceptable band 35% to 60% |
| Gulped | `run_gulped` | Final mass | `t1` to `t7` | 45% |
| Gulped, cause | `run_gulped_by` | Tier at death | Killer: `player`, `gull`, `moray`, `barracuda`, `grouper`, `old_scar` | No single killer above 40% of deaths |
| Abandoned (left the game mid-run) | `run_abandoned` | Final mass | `t1` to `t7` | 10% or less |

Target share banked among runs that end at each tier: tier 1, 10%; tier 2, 35%; tier 3, 45%; tier 4, 50%; tier 5, 55%; tier 6, 60%; tier 7, 70%.

The same outcomes split by input type are carried by `run_end_input` (4.2). It feeds the bank rate and the gulped-by-player rate by input type in section 7.

### 3.3 First-session funnel (custom events)

Each fires at most once per account, in the first session only. Time marks run on T. The share is of users at onboarding step `03_control`; players lost before control show in onboarding steps 1 to 3.

| Order | Sent as | Fires when | Target share of new players |
|---|---|---|---|
| 1 | Onboarding step `03_control` | Control granted (T = 0) | 100% |
| 2 | `fs_time_mark` ctx `s60` | T = 60 | 80% (canon) |
| 3 | `fs_time_mark` ctx `s180` | T = 180 | 65% (canon) |
| 4 | Onboarding step `13_banked` | First bank | 60% (canon) |
| 5 | Onboarding step `17_run2_started` | Leaves the cove for run 2 | 50% (canon). This is the one measure of run 2 starts; the step targets in 3.1 multiply to 53%, which is above the canon floor, not a second target. |
| 6 | `fs_time_mark` ctx `m5` | T = 300 | 57% |
| 7 | `fs_milestone` ctx `goal_first` | First daily goal completed | 45% |
| 8 | `fs_time_mark` ctx `m10` | T = 600 | 50% (canon) |
| 9 | `fs_milestone` ctx `bank2` | Second bank | 40% |
| 10 | `fs_milestone` ctx `tide_first` | First tide event the player ate in | 35% |
| 11 | `fs_time_mark` ctx `m15` | T = 900 | 35% |
| 12 | `fs_milestone` ctx `species_first` | First species bought | 30% |
| 13 | `fs_time_mark` ctx `m25` | T = 1,500 | 15% |

Other `fs_milestone` values, logged for timing and not part of the funnel: `run2_start` (it carries the time of the run 2 start; the share is read from onboarding step 17), `gulped_first`, `player_scare_first` (newcomer bubble popped), `run3_start`, `codex_open`. The value on every `fs_milestone` is T.

### 3.4 Return funnel (custom events)

`ret_day` fires on a player's first join of each UTC day after their first play day.

| Step | Sent as | Fires when | Target |
|---|---|---|---|
| 1 | Onboarding step `01_joined` | First play day | 100% of the day's new users |
| 2 | `ret_day` ctx `d1` | First join on the day after the first play day | 20% of the cohort |
| 3 | `ret_day` ctx `d3` | First join three days after | 11% |
| 4 | `ret_day` ctx `d7` | First join seven days after | 6% |
| 5 | `ret_day` ctx `d30p` | First join 30 or more days after | 2% |

Other `ret_day` values, for the cohort curve: `d2`, `d4_6`, `d8_13`, `d14`, `d15_29`.

Inside a return session:

| Step | Sent as | Fires when | Target from previous |
|---|---|---|---|
| 1 | `ret_day` | As above | — |
| 2 | `ret_welcome` ctx `shown` | The welcome-back card appears (10 or more Pearls in the pile, away 10 minutes or more) | 90% |
| 3 | `ret_welcome` ctx `claimed` | The player taps the welcome-back card, or taps the pile at the Pearl clam before leaving the cove, and the pile is paid. Leaving the cove without a tap claims nothing: the income stays in the pile (canon section 11). | 90% **(tune)** |
| 4 | `run` funnel step `02_left_safe` | Leaves the cove | 95% |
| 5 | `run_banked` | Banks at least once in the session | 60% |

Roblox's Retention page is the official figure and the one used for go/no-go. Ours can differ slightly because Roblox does not state its day boundary. The retention targets above are placeholders until the game has 100 daily users; from then on the target is the similar-game median that Roblox shows.

### 3.5 Species unlock funnel (`species_unlock`, recurring)

One funnel session per player per species.

| Step | Step name | Fires when | Target from previous (Pufferfish) |
|---|---|---|---|
| 1 | `01_silhouette_seen` | The species' silhouette is first shown to the player | — |
| 2 | `02_affordable` | Pearls first reach the price | 55% |
| 3 | `03_card_opened` | The species card is opened | 90% |
| 4 | `04_bought` | Purchase confirmed (Pearls or game pass) | 85% |
| 5 | `05_hatched_as` | First run started as the species | 97% |
| 6 | `06_banked_as` | First bank as the species | 70% |

ctx is the species ID on every step. Step 1 → 2 targets for later species: Eel 45%, Sea Turtle 40%, Squid 30%, Shark Pup 15%. Days from step 1 to step 4 should match canon pacing: Pufferfish in session 1, Eel on day 2, Sea Turtle on day 4 or 5, Squid about day 10, Shark Pup about day 30.

### 3.6 Trait funnel (`trait`, recurring)

One funnel session per run per trait.

| Step | Step name | Fires when | Target from previous |
|---|---|---|---|
| 1 | `01_prey_seen` | That trait's prey first comes within 40 studs in this run (checked once a second on the server) | — |
| 2 | `02_first_eaten` | 1 of 5 eaten | 60% |
| 3 | `03_third_eaten` | 3 of 5 eaten | 65% |
| 4 | `04_gained` | Trait gained (5 of 5; 4 with Keen Nose) | 75% |
| 5 | `05_banked_with` | The run is banked with the trait held | 45% |

ctx is the trait ID. The scripted first Glow is not logged here. Related custom events: `trait_shed`, `trait_lost`, `trait_slots_full`.

### 3.7 Tide event funnel (`tide_event`, recurring)

One funnel session per player per event.

| Step | Step name | Fires when | Target from previous |
|---|---|---|---|
| 1 | `01_warned` | The player is online at the 60-second warning | — |
| 2 | `02_present_at_start` | Still online when the event starts | 92% |
| 3 | `03_in_open_water` | Outside every cove and the Nursery at any moment of the event | 75% |
| 4 | `04_engaged` | Took part, as chapter 05, section 3.9 defines it: ate 15 or more prey during a Feeding Frenzy, or 3 or more Lunar Fry, or 3 or more Marrow chunks | 80% |
| 5 | `05_reward` | Feeding Frenzy: gained a tier during the event. Moon Tide: gained Moonlit. Whale Fall [L]: gained Bonefed. | Frenzy 60%, Moon Tide 25%, Whale Fall 10% |
| 6 | `06_banked_after` | The run that was alive during the event is banked | 50% |

ctx is the event ID. The headline number for pillar 5 is separate: concurrent players in the 2 minutes before each quarter hour ÷ concurrent players at the midpoint between events (minutes 7, 22, 37, 52), read from Roblox's real-time chart. Target 1.10 or more **(tune)**.

### 3.8 Shop and purchase funnel (`shop_purchase`, recurring)

One funnel session per shop visit or contextual offer. ctx is the product type: a group name (`pass`, `pearl_pack`, `pattern`) or, for a single product, its chapter 05 ID.

| Step | Step name | Fires when |
|---|---|---|
| 1 | `01_surface_seen` | The shop is opened, or a contextual offer card is displayed |
| 2 | `02_item_viewed` | A product card is tapped |
| 3 | `03_prompt_shown` | The Roblox purchase prompt is requested |
| 4 | `04_purchased` | Roblox confirms the purchase (the receipt callback for products; the pass-purchase callback plus an ownership check for passes) |
| 5 | `05_granted` | The item is applied and the profile is saved |

Targets by product type:

| ctx | Products (canon section 12) | 1 → 2 | 2 → 3 | 3 → 4 | 4 → 5 | Tag |
|---|---|---|---|---|---|---|
| `pass` | Deep Pockets, Bigger Cove | 35% | 20% | 25% | 99.5% | [MVP] |
| `pass` | Tide Watcher, Keen Nose, Shark Pup | 35% | 20% | 25% | 99.5% | [L] |
| `pearl_pack` | Four sizes | 30% | 15% | 30% | 99.5% | [MVP] |
| `pattern` | Colour patterns | 40% | 10% | 30% | 99.5% | [L] |
| `prod_trait_lock` | Trait Lock (the button shows only when the lost creature held an Uncommon or better trait; chapter 05, section 8.3) | Offer only: 1 → 3 at 5% | — | 35% | 99.5% | [L] |
| `prod_call_tide` | Call the Tide | 20% | 10% | 35% | 99.5% | [L] |
| `prod_cove_boost` | Cove Boost (2 hours of cove income, once a day) | 20% | 10% | 35% | 99.5% | [L] |
| `prod_goal_reroll` | Goal Reroll (after the free daily reroll is used) | 20% | 10% | 35% | 99.5% | [L] |

Revive and the Starter Pack have their own funnels (3.9, 3.12). Private servers [L] are bought on the Roblox game page, not in the game, so they have no in-game funnel; sales are read from Roblox's Monetization page and use is counted with `sess_private_server`.

Cove Boost and Goal Reroll can also be earned by rewarded video where the player is eligible (3.10). A video grant is counted at `rewarded_video` step `05_reward_granted` and never as a purchase.

The SKU of each sale is carried by the custom event `shop_purchased` (ctx = SKU, value = Robux price). Every purchase SKU is the chapter 05 ID, unchanged (canon section 16). Any `shop_grant_failed` is a critical alarm (section 9).

### 3.9 Revive offer funnel (`revive_offer`, recurring)

One funnel session per run (one revive per run, canon 5.5).

| Step | Step name | Fires when | ctx | Target from previous |
|---|---|---|---|---|
| 1 | `01_gulped_eligible` | A gulp where an offer is allowed: not the account's first death, mass 30 or more (tier 3), no revive used this run (canon 5.5; chapter 04, section 7.3) | `t3` to `t7` | — |
| 2 | `02_offer_shown` | The offer appears on the gulped screen | `t3` to `t7` | 99% |
| 3 | `03_option_tapped` | The player taps the paid button or the video button | `paid` or `video` | 8% (MVP, paid only); 20% with video [L] |
| 4 | `04_started` | The purchase prompt is shown, or the video starts | `paid` or `video` | 95% |
| 5 | `05_revived` | The creature is returned at 70% mass | `paid` or `video` | Paid 45%, video 85% |
| 6 | `06_banked_after` | The revived run is banked | `paid` or `video` | 50% |

Overall target, revived ÷ eligible: 3% with paid only, 15% with video [L]. `revive_declined` (ctx = tier, value = mass) fires when the player closes the offer without reviving. The offer has no countdown (canon 5.5), so it never times out.

### 3.10 Rewarded video funnel (`rewarded_video`, recurring) [L]

Built only if GULP is eligible for rewarded video at launch (2.5). The rewards are a free Revive, Cove Boost or Goal Reroll, each a product that is also sold for Robux (canon section 12).

| Step | Step name | Fires when | Target from previous |
|---|---|---|---|
| 1 | `01_placement_shown` | A video button is displayed (only when a video is available) | — |
| 2 | `02_tapped` | The button is tapped | Revive 20%, Cove Boost 35%, Goal Reroll 15% |
| 3 | `03_ad_started` | The video starts | 90% |
| 4 | `04_ad_completed` | The video finishes | 85% |
| 5 | `05_reward_granted` | The reward is applied | 99.5% |

ctx is the placement ID from chapter 05: `ad_revive`, `ad_cove_boost`, `ad_goal_reroll`. `rv_unavailable` fires when a placement would have shown but no video was available; `rv_failed` carries the failure reason.

### 3.11 Cove visit and Bubble funnel (`cove_visit`, recurring) [L]

One funnel session per visitor per owner per day.

| Step | Step name | Fires when | Target from previous |
|---|---|---|---|
| 1 | `01_mouth_approached` | The visitor comes within 40 studs of another player's cove mouth (first time that day for that owner) | — |
| 2 | `02_entered` | The visitor crosses the mouth | 30% |
| 3 | `03_specimen_inspected` | The visitor taps a specimen | 50% |
| 4 | `04_bubble_left` | The visitor leaves a Bubble | 40% |

Headline: share of daily users who leave at least one Bubble, target 15%. `cove_bubble_received` fires for the owner.

### 3.12 Starter pack funnel (`starter_pack`, recurring) [L]

One funnel session per player.

| Step | Step name | Fires when | Target from previous |
|---|---|---|---|
| 1 | `01_eligible` | Second session or later, 2 or more banks, not owned | — |
| 2 | `02_card_shown` | The offer card appears after the first bank of a session | 90% |
| 3 | `03_buy_tapped` | The buy button is tapped | 8% |
| 4 | `04_prompt_shown` | The Roblox purchase prompt is requested | 98% |
| 5 | `05_purchased` | Roblox confirms the purchase | 40% |
| 6 | `06_granted` | The Sunrise pattern, the Golden Chest decoration and 5,000 Pearls applied, profile saved (chapter 05, section 8.3) | 99.5% |

Overall target, step 5 ÷ step 1: 3%. There is no separate dismissal event: a card closed without a tap is step 2 without step 3.

## 4. Event dictionary

### 4.1 Naming scheme

- Lowercase with underscores: `<domain>_<what_happened>`.
- Domains: `ftue`, `fs` (first session), `sess`, `ret`, `run`, `species`, `trait`, `tide`, `shop`, `revive`, `rv` (rewarded video), `cove`, `goal`, `codex`, `settings`, `social`, `guard`, `ab`, `sys`, `pvp`, `perf`, `input`.
- Funnel step names are `NN_what_happened`, numbered from 01.
- IDs inside ctx are canon IDs (`minnow`, `glow`, `moon_tide`). Tiers are `t1` to `t7`.
- Every custom event has one number (`value`) and one context string (`ctx`). An event that needs two contexts is split into two events.
- All events fire on the server.

### 4.2 Custom events (61)

**First-time experience**

| Event | Value | ctx | Fires when | Tag |
|---|---|---|---|---|
| `ftue_milestone` | T in seconds | `bite_le5`, `bite_le10`, `bite_le20`, `bite_gt20`; `tier2_le30`, `tier2_le45`, `tier2_le60`, `tier2_gt60`; `trait_le45`, `trait_le60`, `trait_le90`, `trait_gt90`; `bank_le90`, `bank_le120`, `bank_le180`, `bank_gt180` | Once each for first bite, tier 2, first trait and first bank in run 1 | [MVP] |
| `ftue_bite_assist` | T | — | The first bite happened with no player input before it | [MVP] |
| `ftue_first_dash` | T | `manual` or `auto` | First dash on the account | [MVP] |
| `ftue_failsafe` | T | `load_partial`, `load_minimal`, `grow_homing`, `grow_burst`, `trait_homing`, `afk_hold`, `run2_homing`, `home_lure`, `home_push` | A fail-safe from chapter 04 starts (once each per account) | [MVP] |
| `ftue_chase_result` | Manual dashes during the chase | `clean`, `assisted`, `retreated`, `skipped` | The chase ends | [MVP] |
| `ftue_shield_end` | T | `banked` or `timeout` | The first-run shield ends | [MVP] |
| `ftue_end` | T | `completed`, or `left_s0` to `left_s10` (the stage at disconnect) | The first bank completes the FTUE, or the player leaves before it | [MVP] |

**System and session**

| Event | Value | ctx | Fires when | Tag |
|---|---|---|---|---|
| `sys_load_time` | Seconds from `PlayerAdded` to control | `le5`, `le10`, `le20`, `gt20` | Control is granted, every session | [MVP] |
| `sys_profile_fail` | 1 | `timeout`, `locked`, `error` | The profile fails to load | [MVP] |
| `sys_session_end` | Session length in seconds | `ftue`, `cove`, `nursery`, `run_safe`, `run_open`, `gulped_screen`, `shop` (where the player was) | The player leaves | [MVP] |
| `sess_start` | 1 | `1`, `2`, `3`, `4_9`, `10p` (session number on the account) | Control is granted | [MVP] |
| `sess_input` | 1 | `touch`, `kbm`, `gamepad` | 10 s after control, from the input type in use | [MVP]; `gamepad` [L] |
| `sess_day_mark` | 1 | `m10`, `m30`, `m60` | The player's total play time today passes 10, 30 and 60 minutes (once each per day) | [MVP] |
| `sess_private_server` | 1 | — | A session starts on a private server | [L] |
| `social_friend_join` | Friends on the server | — | A session starts on a server that holds one or more of the player's friends | [MVP] |

**First session and return**

| Event | Value | ctx | Fires when | Tag |
|---|---|---|---|---|
| `fs_time_mark` | 1 | `s60`, `s180`, `m5`, `m10`, `m15`, `m25` | T reaches the mark in the account's first session | [MVP] |
| `fs_milestone` | T in seconds | `run2_start`, `goal_first`, `gulped_first`, `tide_first`, `bank2`, `run3_start`, `player_scare_first`, `species_first`, `codex_open` | Once each, first session only | [MVP] |
| `fs_end` | First-session length in seconds | `r1`, `r2`, `r3`, `r4p` (runs started) | The first session ends | [MVP] |
| `ret_day` | 1 | `d1`, `d2`, `d3`, `d4_6`, `d7`, `d8_13`, `d14`, `d15_29`, `d30p` | First join of a UTC day after the first play day | [MVP] |
| `ret_welcome` | Pearls in the pile | `shown`, `claimed` | The welcome-back card is shown; the player taps to claim the pile (chapter 04, section 8.1). Never fired by leaving the cove. | [MVP] |
| `ret_streak` | Streak length | `d1` to `d7` (the box opened; a missed day never resets the streak) | The streak card is shown | [L] |

**Run**

| Event | Value | ctx | Fires when | Tag |
|---|---|---|---|---|
| `run_banked` | Final mass | `t1` to `t7` | A run is banked | [MVP] |
| `run_gulped` | Final mass | `t1` to `t7` | A run ends by gulp (after any revive is declined) | [MVP] |
| `run_gulped_by` | Tier at death | `player`, `gull`, `moray`, `barracuda`, `grouper`, `old_scar` | With `run_gulped` | [MVP] |
| `run_abandoned` | Final mass | `t1` to `t7` | The player leaves the game mid-run | [MVP] |
| `run_duration` | Seconds | `banked`, `gulped`, `abandoned` | A run ends | [MVP] |
| `run_species` | Final mass | Species ID | A run ends | [MVP] |
| `run_zone_enter` | Seconds into the run | `reef`, `kelp`, `dropoff` | First entry to the zone in this run | [MVP] |
| `run_pvp_eat` | Mass gained | `t2` to `t7` (the eater's tier) | A player eats a player | [MVP] |
| `run_hazard_hit` | Seconds into the run | `jelly_bloom`, `hook`, `anemone`, `vent`, `plated_break` | First hit by that hazard in this run (`plated_break`: the Plated trait absorbed a bite) | [MVP]; `anemone`, `vent` [L] |

**Species, traits, tide**

| Event | Value | ctx | Fires when | Tag |
|---|---|---|---|---|
| `species_ability_use` | Uses in the run | Species ID | A run ends, for species with an active ability | [MVP] |
| `trait_shed` | Seconds into the run | Trait ID | The player sheds a trait | [MVP] |
| `trait_lost` | Mass at death | Trait ID | A run is gulped while the trait is held (one event per trait) | [MVP] |
| `trait_slots_full` | Seconds into the run | — | The third slot fills | [MVP] |
| `tide_call_used` | Players on the server | `frenzy` | Call the Tide starts an event | [L] |

**Shop, revive, rewarded video**

| Event | Value | ctx | Fires when | Tag |
|---|---|---|---|---|
| `shop_open` | 1 | `hud`, `gulped_screen`, `cove`, `offer` (how it was opened) | The shop opens | [MVP] |
| `shop_purchased` | Robux price | SKU (the chapter 05 ID): `pass_deep_pockets`, `pass_bigger_cove`, `prod_pearls_s`, `prod_pearls_m`, `prod_pearls_l`, `prod_pearls_xl`, `prod_revive`; [L] `pass_tide_watcher`, `pass_keen_nose`, `pass_shark_pup`, `prod_trait_lock`, `prod_call_tide`, `prod_cove_boost`, `prod_goal_reroll`, `prod_starter_pack`, the pattern ID `pat_<species>_<name>`, the Robux decoration ID `deco_buy_<name>` | A Robux purchase is granted | [MVP] |
| `shop_prompt_cancelled` | 1 | Product type (as in 3.8, plus `prod_revive`, `prod_starter_pack`) | A Roblox purchase prompt closes without a purchase | [MVP] |
| `shop_grant_failed` | Robux price | SKU | A confirmed purchase could not be applied or saved | [MVP] |
| `revive_declined` | Mass at death | `t3` to `t7` | The player closes the Revive offer without reviving (the offer has no countdown) | [MVP] |
| `rv_unavailable` | 1 | `ad_revive`, `ad_cove_boost`, `ad_goal_reroll` | A placement had no video to show | [L] |
| `rv_failed` | 1 | Roblox's failure result name | A video fails or is closed early | [L] |

**Cove, goals, Codex, settings**

| Event | Value | ctx | Fires when | Tag |
|---|---|---|---|---|
| `cove_time` | Seconds in own cove | `after_bank`, `after_gulp`, `login` | The player leaves their cove | [MVP] |
| `cove_specimen_released` | Pearl refund | `t2` to `t7` | A specimen is released | [MVP] |
| `cove_full_choice` | 1 | `released_old`, `released_new` | The player banks with a full cove and chooses | [MVP] |
| `cove_bubble_received` | Total Bubbles on the cove | — | The cove receives a Bubble | [L] |
| `cove_deco_placed` | 1 | How the decoration was obtained (decorations have no rarity; chapter 03, section 13): `pearls`, `rank`, `codex`, `goals`, `tide`, `robux` (the Starter Pack's Golden Chest counts as `robux`) | A decoration is placed | [L] |
| `goal_completed` | Seconds since the goal was given | Goal ID | A daily goal completes | [MVP] |
| `goal_all3` | 1 | — | All three of the day's goals are complete | [MVP] |
| `goal_rerolled` | 1 | `free`, `video`, `paid` | A goal is rerolled: by the free daily reroll, by rewarded video, or by the Goal Reroll product | [MVP]; `video`, `paid` [L] |
| `codex_entry` | Total entries on the account | `species`, `tier`, `trait`, `prey`; [L] `danger`, `place`, `tide` | A new Codex entry is discovered | [MVP]; `danger`, `place`, `tide` [L] |
| `codex_opened` | 1 | — | The Codex is opened (once per session) | [MVP] |
| `settings_changed` | 1 | `two_thumb_on`, `music_off`, `sfx_off`, `low_graphics_on`, `invert_y_on`, `haptics_off` | A setting leaves its default | [MVP]; `two_thumb_on` [L] |

**Device and input** (defined in chapter 15, section 4.4)

| Event | Value | ctx | Fires when | Tag |
|---|---|---|---|---|
| `sess_device` | 1 | `<class>_<display>_<input>`: class `phone`, `tablet`, `desktop`, `handheld`, `tv`; display `s`, `m`, `l`; input `touch`, `kbm`, `gamepad` (45 fixed values) | Once per session, 10 s after control | [MVP]; `handheld`, `tv` and `gamepad` values [L] |
| `run_end_input` | Run length in seconds | `<input>_<outcome>`: input as above; outcome `bank`, `gulp_player`, `gulp_npc`, `quit` (12) | Every run end, with the input type used for most of the run | [MVP]; `gamepad` values [L] |
| `pvp_pair` | 1 | `<eaterInput>_<victimInput>` (9) | A player eats a player (with `run_pvp_eat`), with each side's input type at that moment | [L] |
| `perf_tier` | Average frames per second over the session | `<class>_<tier>`: class as above; tier `smooth`, `balanced`, `pretty`, `cut` (20) | The session ends | [MVP] |
| `input_switch` | Input-type switches in the session | `<from>_<to>` (6) | The session ends, if the input type changed at least once | [L] |

These five events add 92 `ctx` values and never carry an experiment arm (2.4). The client reports its screen class, input type and frame rate; the server sends the event and accepts only values from the fixed lists. The input type is used for analytics only, never for validation (chapter 15, section 4.3).

**Guards and experiments**

| Event | Value | ctx | Fires when | Tag |
|---|---|---|---|---|
| `guard_flag` | The measured value | Rule ID (section 9.2), or `analytics_drop` | A server-side sanity rule trips | [MVP] |
| `guard_action` | 1 | `clamp`, `rollback`, `kick` | The server acts on a flag | [MVP] |
| `ab_exposed` | 1 | `<key>=<variant>` | The first time in a session that a player's experiment value is read | [MVP] |

### 4.3 Funnel steps

Funnel steps are listed in section 3 and are not custom events. They do not count toward the 100-name limit.

## 5. Economy tracking

One currency: `Pearls`. Every change to a player's Pearl balance goes through one server function, and that function calls `Analytics.pearls`. A balance change with no economy event is a bug, and the guard rule `wallet_mismatch` (9.2) catches it.

Mass is not tracked as a currency: it resets every run and converts to Pearls only on banking. Bubbles are not tracked as a currency: they cannot be spent.

### 5.1 Sources

| Source | transactionType | itemSku | Amount | Fires when | Tag |
|---|---|---|---|---|---|
| Banking, base | `Bank` | `bank_t1` to `bank_t7` | 3 per mass up to 1,200 mass, 1 per mass from 1,200 to 3,000, nothing above 3,000 (canon 5.4) | A run is banked. A run suspended by a server shutdown that then expires pays its full bank value through the same SKUs (chapter 09, section 12.5). | [MVP] |
| Banking, Crystal trait | `Bank` | `bank_crystal` | The extra Pearls from the ×1.5 | With the base event | [MVP] |
| Banking, Deep Pockets | `Bank` | `bank_deep_pockets` | The extra Pearls from the ×2 | With the base event | [MVP] |
| Scraps | `Scraps` | `scraps_50` (first three deaths), `scraps_10` | 50% or 10% of what the bank would have paid | A run is gulped, or a suspended run expires or is given up with Start fresh (chapter 09, section 12.5) | [MVP] |
| Cove income, claimed at the pile | `CoveIncome` | `claim_pile` | Pearls claimed, rounded down. The pile stops growing after 8 hours unclaimed (24 with Tide Watcher), online or offline. | The player taps the pile at the Pearl clam in the cove. Income is never credited automatically: not at login, on a bank, on leaving the cove or on a timer (canon section 11). | [MVP] |
| First income tick | `Onboarding` | `income_first_tick` | One hour of the first specimen's income | 3 s after the first specimen is placed. The one cove payment made without a tap: the first-bank reward (canon section 11). | [MVP] |
| Cove income, claimed on the welcome-back card | `CoveIncome` | `claim_welcome` | The same pile and the same cap | The player taps the welcome-back card | [MVP] |
| Cove Boost, bought | `IAP` | `prod_cove_boost` | 2 hours of the cove's income | The Cove Boost product is granted (once a day, canon section 12) | [L] |
| Cove Boost, by rewarded video | `AdReward` | `ad_cove_boost` | 2 hours of the cove's income | After a rewarded video, where the player is eligible | [L] |
| Daily goal | `Goal` | `goal_slot1`, `goal_slot2`, `goal_slot3` | The goal's reward (base × rank multiplier) | A goal completes | [MVP] |
| Daily goals, all-three bonus | `Goal` | `goal_all3` | 100 × rank multiplier (chapter 05, section 3.5) | The third goal of the day completes, with custom event `goal_all3` | [MVP] |
| Login streak | `Streak` | `streak_d1` to `streak_d7` | The day's reward (base × rank multiplier) | The streak card | [L] |
| Codex, single entry | `Codex` | `cdx_entry_prey`, `cdx_entry_trait`, `cdx_entry_tier` | Prey 20 or 30; trait 100 to 1,500 by rarity; tier 25 to 800 (chapter 05, section 3.8). Entries in Species, Dangers, Places and Tides pay nothing and log no economy event. | The entry is discovered, with custom event `codex_entry`. Once per account. | [MVP] |
| Codex, one species' Tiers page complete | `Codex` | `cdx_page` | 500 | The seventh tier of a species is filled | [MVP] |
| Codex, category complete | `Codex` | `cdx_category` | 125, 175, 2,500 or 5,000 by category (chapter 05, section 3.8): Species, Prey, Traits, all Tiers pages; [L] Dangers, Places, Tides, the whole Codex | The last entry of the category is filled. Once per account. | [MVP]; Dangers, Places, Tides and the whole Codex [L] |
| Reef Rank reward | `Rank` | `rank_up` | 25 × the new rank (chapter 05, section 3.9) | A new Reef Rank is reached. Once per rank. | [L] |
| Tide bonus | `Tide` | `tide_bonus_frenzy`, `tide_bonus_moon_tide`, `tide_bonus_whale_fall` | 40 × rank multiplier (chapter 05, section 3.9) | The player takes part in a tide event (15 prey in a Feeding Frenzy, 3 Lunar Fry, or 3 Marrow chunks). At most 3 a day. | [L] |
| Limited-time tide reward | `Tide` | `tide_limited` | The event's Pearl budget (chapter 05, section 3.9) | The limited-time tide's reward is paid | [P1] |
| Specimen release refund | `Refund` | `release_refund` | The refund | A specimen is released | [MVP] |
| Pearl pack | `IAP` | `prod_pearls_s`, `prod_pearls_m`, `prod_pearls_l`, `prod_pearls_xl` | Pearls granted | Purchase granted | [MVP] |
| Starter Pack Pearls | `IAP` | `prod_starter_pack` | Pearls granted | Purchase granted | [L] |
| Support or developer grant | `Admin` | `admin_grant` | Pearls granted | A manual grant | [MVP] |

### 5.2 Sinks

| Sink | transactionType | itemSku | Amount | Fires when | Tag |
|---|---|---|---|---|---|
| Species unlock | `Species` | Species ID (`puffer`, `eel`; [L] `turtle`, `squid`, `shark`) | The price | The species is bought with Pearls | [MVP] |
| Cove slot | `CoveSlot` | `slots_07_12`, `slots_13_20`, `slots_21_30` | The slot's price | A slot is bought | [MVP] |
| Decoration | `Decoration` | The decoration's chapter 03 ID, `deco_<name>`: the 18 Pearl decorations at launch (chapter 05, section 4.3). The other 32 of the 50 decorations are not bought with Pearls and have no sink. | The price | A decoration is bought with Pearls | [L] |
| Correction | `Admin` | `admin_remove` | Pearls removed | A rollback after an exploit | [MVP] |

That is 16 transaction types (limit before grouping: 20) and 70 SKUs at launch: 43 on sources and 27 on sinks (limit before grouping: 100). In [P1] the four Monument decorations and `tide_limited` would make it 75. Economy events are not custom events: the custom event names stay at 61 of 100 (section 4.2).

**Check against chapter 05.** Every Pearl source in chapter 05, section 3 has a row in 5.1: banking (3.1), scraps (3.2), cove income and the first-bank reward (3.3), the pile and Cove Boost (3.4), daily goals and the all-three bonus (3.5), the login streak (3.6), Codex rewards (3.8), Reef Rank rewards, tide bonuses and limited-time tides (3.9), the release refund (3.10), and the Pearl packs and Starter Pack (sections 8.4 and 8.5). The rank multiplier (3.7) is not a source of its own: it is inside the amount of the goal, streak and tide bonus events. Every Pearl sink in chapter 05, section 4 has a row in 5.2: species (4.1), cove slots (4.2) and decorations (4.3); section 4.4 confirms there are no others at launch.

### 5.3 How inflation shows up

| Measure | Formula | Healthy (tune) | Read from |
|---|---|---|---|
| Pearls created per daily user | Sum of all sources in a day ÷ daily users | Flat or slowly rising week to week; a rise of 30% or more with no content change is an alarm | Economy page, "Total sources and sinks" |
| Sink-to-source ratio | Sum of sinks ÷ sum of sources, trailing 7 days | 0.6 to 0.9. Below 0.5 means Pearls are piling up. | Same |
| Average wallet balance | Roblox's wallet chart, split by cohort | A `d7p` player's average balance stays under the price of their next species | Economy page, "Average wallet balance" |
| Source mix | Each transaction type's share of sources | It depends on account age, so it is read by cohort (chapter 05, section 5.6). First day (`s1`, `d0`): banking and scraps 40% to 60%, cove income near 0%, daily rewards (goals, streak [L] and tide bonuses [L]) 10% to 30%, one-time rewards (Codex, Reef Rank [L] and release refunds) 25% to 30%. From day 7 (`d7p`): banking and scraps 10% to 25%, cove income 45% to 85%, daily rewards 5% to 25%, one-time rewards 6% or less. Purchased Pearls (packs, Starter Pack, Cove Boost) 5% or less at any age. | Economy page, "Top sources" |
| Days to each species | Days from funnel step `01_silhouette_seen` to `04_bought` | Canon pacing: session 1, day 2, day 4 or 5, day 10, day 30 | Species unlock funnel |

**The pacing line.** Canon section 7's unlock days fix what a non-paying daily player spends on species. The player earns more than that, because slots and decorations are bought too, so the line is the regular player in chapter 05, section 5.4. If a cohort earns well above this line, prices are too low or a source is too generous.

| Account age | Cumulative Pearls spent on species by then (canon) | Regular player's Pearls earned that day (chapter 05, section 5.4) | Cumulative Pearls earned |
|---|---|---|---|
| Day 1 | 500 | 3,661 | 3,661 |
| Day 2 | 4,000 | 4,873 | 8,534 |
| Day 5 | 16,000 | 7,950 | 29,904 |
| Day 10 | 61,000 | 11,756 | 81,667 |
| Day 30 | 311,000 | 23,356 | 445,835 |

The MVP has two sinks (species and cove slots) and both are one-off purchases. Once a player owns everything their balance can only grow. This is expected at soft launch; see "Proposed canon changes".

## 6. Dashboards

"Built-in" means a page Roblox provides. "Explore" means a chart we build in Creator Hub's Explore section from our events.

| Dashboard | Where | What is on it | Question it answers |
|---|---|---|---|
| **Daily health** | Built-in Overview, Retention, Engagement; Explore | Daily users and new users; day-1, day-7, day-30 retention with similar-game benchmarks; average session time; `sess_day_mark` shares at 10, 30 and 60 minutes; `sys_load_time` average and `gt20` share; `sys_session_end` by ctx | Is the game healthy today, and where do people quit? |
| **Onboarding** | Built-in Funnels (Onboarding tab); "New User First Session Retention" chart; Explore | The 20-step funnel, by day and by `exp`; `ftue_milestone` shares; `fs_time_mark` shares; `ftue_failsafe` counts by ctx; `ftue_chase_result` mix; `ftue_end` by stage | Where in the first two minutes do we lose people, and is it a bug or the design? |
| **Runs and balance** | Built-in Funnels (`run`, `trait`); Explore | Run funnel by tier; bank rate by tier; `run_gulped_by` mix; average `run_duration` by outcome; `run_species` counts and average mass; trait funnel by trait | Is each tier, predator, species and trait pulling its weight? |
| **Economy** | Built-in Economy; Funnels (`species_unlock`) | Sources and sinks by transaction type; average wallet balance by cohort; top SKUs; days to each species | Are Pearls inflating, and is the pacing on the canon line? |
| **Monetisation** | Built-in Monetization; Funnels (`shop_purchase`, `revive_offer`, `starter_pack`, `rewarded_video`); Explore | Revenue by product; conversion rate, ARPPU, ARPDAU with benchmarks; each purchase funnel by product type; `shop_purchased` by SKU; `shop_prompt_cancelled`; share of spenders reaching `sess_day_mark` = `m10` | What sells, where do buyers drop out, and how many spenders qualify for Creator Rewards? |
| **Live events** | Built-in Funnels (`tide_event`); Roblox real-time concurrent players; Explore | Tide funnel by event; concurrent players by minute of the hour; `tide_call_used` [L] | Do tide events pull players in on the clock, and which event do they prefer? |
| **Experiments** | Roblox Experiments; Onboarding funnel filtered by `exp` | Each running test's arms, sample so far, primary metric and guardrails | Can we call the test yet, and which way? |
| **Devices and inputs** | Explore | `sess_device` and `sess_input` mix; bank rate and gulped-by-player rate by input type from `run_end_input`; `pvp_pair` balance [L]; average `perf_tier` frame rate by class and tier; `input_switch` [L] | Is any input type at an advantage, and does each device class hold its frame rate? |
| **Guards** | Explore | `guard_flag` by rule; `guard_action` by ctx; `shop_grant_failed`; `sys_profile_fail` | Is anyone cheating, and is anything broken that costs players Pearls or Robux? |

## 7. Key measures

Roblox's own figures are used wherever Roblox publishes them. "Ours" means computed from our events.

| Measure | Definition and formula | Source | Target |
|---|---|---|---|
| Day-N retention | New users of day D who play again on day D + N ÷ new users of day D | Roblox Retention page (official); `ret_day` (ours) | Day 1: 20%; day 3: 11%; day 7: 6%; day 30: 2% **(tune)**, replaced by the similar-game median once shown |
| Gone by 60 s of control | 1 − (`fs_time_mark` `s60` users ÷ `03_control` users) | Ours. Roblox's first-session chart counts from the start of the session and is the official bounce figure. | 20% or less (canon) |
| Gone by 180 s of control | 1 − (`fs_time_mark` `s180` users ÷ `03_control` users) | Ours | 35% or less (canon) |
| Average session time | Total time in the game ÷ number of sessions | Roblox Engagement page | 12 minutes **(tune)**; at or above the similar-game median for go/no-go |
| Still playing at 10 minutes | `fs_time_mark` `m10` users ÷ `03_control` users | Ours | 50% or more (canon) |
| Play time per daily user | Total play time in a day ÷ daily users | Roblox Engagement page | 24 minutes **(tune)**, the figure chapter 05, section 11.1 assumes |
| Ten-minute days | Users with `sess_day_mark` `m10` ÷ daily users | Ours | 55% **(tune)** |
| Runs per session | `run` funnel step `01_hatched` count ÷ `sess_start` count | Ours | 3.5 **(tune)** |
| Bank rate | `run_banked` ÷ (`run_banked` + `run_gulped` + `run_abandoned`) | Ours | 45%; band 35% to 60% **(tune)** |
| Bank rate by input type | `run_end_input` `<input>_bank` ÷ all `run_end_input` for that input | Ours | Each input within 5 percentage points of `touch` **(tune)** |
| Gulped-by-player rate by input type | `run_end_input` `<input>_gulp_player` count per 10 run-minutes (run-minutes = the sum of `run_end_input` values for that input ÷ 60) | Ours | Each input within 15% of `touch` **(tune)** |
| Pair balance by input type [L] | `pvp_pair` `kbm_touch` ÷ `touch_kbm`, divided by keys run-minutes ÷ touch run-minutes; the same for `gamepad` against `touch` | Ours | 0.8 to 1.25 **(tune)** |
| First-bank rate | Onboarding step 13 ÷ step 03 | Ours | 60% or more (canon) |
| Average run length | Average `run_duration` | Ours | 3 to 8 minutes (canon) |
| Payer conversion | Paying users in a day ÷ daily users | Roblox Monetization page ("Conversion rate") | 0.8% **(tune)**: the base case of chapter 05, section 11.1 (strong case 1.6%) |
| Revenue per paying user (ARPPU) | Robux revenue in a day ÷ paying users that day | Roblox Monetization page | 130 Robux **(tune)**: base case (strong case 190) |
| Revenue per daily user (ARPDAU) | Robux revenue in a day ÷ daily users (= payer conversion × ARPPU) | Roblox Monetization page | 1.04 Robux **(tune)**: base case, 0.8% × 130 (strong case 3.04) |
| First-week payer conversion | New users who buy anything within 7 days ÷ new users | Roblox cohort chart ("7-day player conversion rate") | 2.5% **(tune)** |
| Revive take rate | `revive_offer` step 5 ÷ step 1 | Ours | 3% paid only; 15% with video [L] **(tune)** |
| Starter pack conversion [L] | `starter_pack` step 5 ÷ step 1 | Ours | 3% **(tune)** |
| Qualified spenders | Spenders with `sess_day_mark` `m10` that day ÷ spenders that day | Ours | 85% **(tune)** |
| Tide pull | Concurrent players in the 2 minutes before each quarter hour ÷ concurrent players at minutes 7, 22, 37 and 52 | Roblox real-time chart | 1.10 or more **(tune)** |
| Sink-to-source ratio | Section 5.3 | Roblox Economy page | 0.6 to 0.9 **(tune)** |
| Load time | Average `sys_load_time`; share in `gt20` | Ours | 6 s average across all devices; 3% or less in `gt20` **(tune)** |
| Frame rate by device class | Average `perf_tier` value by ctx; share of sessions ending in `cut` | Ours | The per-platform targets in chapter 15 |

Roblox does not publish formulas or time windows for conversion rate, ARPPU or ARPDAU on the pages we read; the formulas above are the standard ones and match Roblox's descriptions.

The three by-input measures and their limits come from chapter 15, section 4.4. They are read weekly, and only when each input has at least 2,000 run ends in the last 7 days. In the MVP the inputs are `touch` and `kbm`; `gamepad` joins at [L] and consoles at [P1].

## 8. A/B testing

### 8.1 How players are split

1. **Primary method: Roblox Experiments.** Each test is one config key (chapter 04, section 11). The server calls `ConfigService:GetConfigForPlayerAsync(player)` once per join and `snapshot:GetValue(key)` when the value is first needed. Roblox assigns the arm at random on the first `GetValue` call and returns the same arm for the life of the experiment.
2. **Who is enrolled.** For FTUE tests the server reads the key only for players with `ftue.completed = false`, at profile load, so players who have already finished the tutorial are never enrolled. The arm is copied into the profile (`ab.<key>`) so the same player keeps the same tutorial if they reconnect.
3. **Tagging.** The arm goes into custom field `exp` on the events listed for that test, and `ab_exposed` fires once per session. This lets us read funnel steps by arm, which Roblox's experiment report does not include.
4. **Fallback.** If Experiments is unavailable for the game, the server splits by itself: `variant = hash(userId .. key) mod 100`, with fixed ranges per arm. The two methods are never used for the same key.
5. **Arms.** Two arms where possible. Roblox allows a control and up to two variants.
6. **Concurrency.** At most one FTUE test and one non-FTUE test at the same time.
7. **Rollout.** 100% of eligible players, split evenly.

### 8.2 Sample sizes

Per-arm sample for a two-sided test at 5% significance and 80% power:

`n per arm = 7.85 × [p1(1 − p1) + p2(1 − p2)] ÷ (p2 − p1)²`

"Days" assumes 300 new players a day **(tune)**, so 150 per arm per day with two arms and 100 with three. To rescale: days = n per arm × arms ÷ new players per day. Roblox's minimum run is 14 days, so no test is shorter than that.

| # | Config key | Arms | Primary metric | Baseline → smallest change worth detecting | n per arm | Days at 300 new/day | Planned run |
|---|---|---|---|---|---|---|---|
| 1 | `ftue_chase_mode` | 2 | Still playing at T = 180 | 65% → 70% | 1,374 | 9.2 | 14 days |
| 2 | `ftue_home_mode` | 2 | First bank | 60% → 65% | 1,468 | 9.8 | 14 days |
| 3 | `ftue_cliffhanger` | 3 | Run 2 started | 50% → 55% | 1,562 | 15.6 | 16 days |
| 4 | `ftue_trait_count` | 2 | Still playing at T = 60 | 80% → 85% | 903 | 6.0 | 14 days |
| 5 | `ftue_first_trait` | 2 | Run 2 started | 50% → 55% | 1,562 | 10.4 | 14 days |
| 6 | `ftue_prompt_words` | 2 | Clean chase share | 60% → 65% (baseline is a guess) | 1,468 | 9.8 | 14 days |
| 7 | `ftue_hatch_intro` | 2 | First bite within 5 s | 75% → 80% | 1,091 | 7.3 | 14 days |
| 8 | `ftue_first_tick` | 2 | Day-1 retention | 20% → 23% | 2,940 | 19.6 | 21 days |
| 10 | `run2_aim_assist` | 3 | Tier 2 in run 2, among those who start run 2 | 90% → 94% | 719 | 14.4 (half of new players start run 2) | 16 days |
| 11 | `ftue_loading_toy` | 2 | Loading screen → control | 95% → 97% | 1,504 | 10.0 | 14 days |
| 12 | `starter_pack_timing` [L] | 3 | Starter pack conversion among eligible players | 3% → 5% | 1,504 | Sized at launch: 18 days at 250 eligible players a day | 21 days |

There is no number 9. It was `revive_first_offer`, which showed the Revive offer on an account's first death; it is withdrawn because canon 5.5 never shows the offer on a first death. The other tests keep their numbers so they match chapter 04, section 11.

Smaller changes need far more players: detecting day-1 retention moving from 20% to 22% needs 6,507 per arm. At soft-launch volumes we can only see large effects, so we test large changes.

### 8.3 How results are read

1. **Before the test starts,** write one line in the review spreadsheet: key, arms, primary metric, guardrail, smallest change worth detecting, planned end date.
2. **Daily during the test,** check only the guardrail and the sample split. Roblox's automatic early-harm check needs 10,000 players across the arms, which we will not have, so this manual check replaces it. Stop the test if the guardrail is worse in the variant by 8 points or more on 400 or more players per arm.
3. **Sample split check.** Roblox raises a sample-ratio alert. For the fallback method, run a chi-square test on the arm counts and treat p below 0.001 as a broken split.
4. **At the planned end and not before,** read the primary metric. For day-1 retention, day-7 retention, playtime, session time, ARPU, ARPPU and payer conversion, use Roblox's report: the result is significant when the confidence interval does not include 0%. For funnel steps and custom events, take unique users per arm from the funnel filtered by `exp` and run a two-proportion z-test in the spreadsheet (significant at p below 0.05).
5. **Decision rule.** Ship the variant if the primary metric is significantly better and no guardrail is significantly worse. Keep the control if the variant is significantly worse. If the result is not significant, keep whichever arm is simpler to maintain, and do not rerun the same test without a larger change.
6. **After shipping,** remove the losing branch from the code within one update and delete the config key.
7. **Do not** stop early because a result looks good, read more than one primary metric, or split results by platform or age after the fact and act on a subgroup. The weekly read of bank rate and gulped rate by input type (section 7) is a standing balance check on all players, not an experiment, so this rule does not apply to it.

## 9. Alerts

### 9.1 What raises an alarm

Custom, funnel and economy events arrive up to 24 hours late, so only performance alarms and server-side guards are real-time. The rest are read at the daily check.

| Alarm | Source | Trigger (tune) | Speed | First action |
|---|---|---|---|---|
| Crash spike | Roblox Alerts, client crash rate [L]; before that, the built-in Performance page | Above 3% for 15 minutes | Real-time [L]; daily [MVP] | Roll back the last publish |
| Frame-rate drop | Roblox Alerts, client frame rate [L] | Average under 30 for 30 minutes | Real-time [L] | Check the last content change; lower prey draw counts |
| Load regression | `sys_load_time` | Average above 9 s, or `gt20` share above 8% | Daily | Check the minimum set's size against chapter 04, section 2.3 |
| Bounce spike | `fs_time_mark` `s60`; Roblox's first-session chart | `s60` share under 72%, or 6 points under the trailing 7-day average, on 200 or more new users | Daily | Open the onboarding funnel and find the step that moved |
| First-bite failure | `ftue_milestone` | `bite_le5` + `bite_le10` under 85% | Daily | Test the hatch and Swarm A on the reference phone |
| Funnel break | Onboarding funnel | Any step's conversion falls 10 points or more day over day, on 200 or more new users | Daily | Treat as a bug in that beat |
| Fail-safe overuse | `ftue_failsafe` | Any one fail-safe fires for more than 25% of new players | Daily | The beat it protects is too hard; retune it |
| Day-1 retention drop | Roblox Retention page | 3 points under the trailing 14-day average, 2 days running | Daily | Check what shipped two days earlier |
| Economy exploit | `guard_flag` | More than 5 flags per 1,000 daily users, or any one rule above 20 a day | Real-time action in the server; daily count | 9.2 |
| Inflation | Economy page | Pearls created per daily user up 30% or more week over week with no content change; or sink-to-source ratio under 0.5 for 3 days | Daily | Find the source that grew (source mix, top SKUs) |
| Purchase not delivered | `shop_grant_failed` | Any | Daily; the server also retries the grant at once and on next join | Fix before anything else ships |
| Purchase funnel break | `shop_purchase` step 4 → 5 | Under 99% | Daily | Same |
| Profile failures | `sys_profile_fail` | Above 0.5% of sessions | Daily | Document 09's save-failure procedure |
| Analytics dropping events | `guard_flag` `analytics_drop` | Dropped events above 1% of events sent | Daily | Cut P2 events or batch more |

### 9.2 Server-side guard rules

These run on the server in real time. They act first and log second. Thresholds are **(tune)** and sit well above what honest play can reach.

| Rule ID | Trips when | Honest maximum, for reference | Server action |
|---|---|---|---|
| `bite_rate` | More than 15 bites a second for 3 seconds | About 6 a second inside a dense swarm | Ignore the excess bites (`clamp`) |
| `speed` | Above 1.3 × the allowed speed (tier speed, dash, current, traits) for 2 seconds | 1.0 × | Snap back to the last valid position (`rollback`) |
| `mass_rate` | Mass gained in 60 seconds exceeds 3 × the current tier's "mass needed" (minimum 60) | About 1 × during a Feeding Frenzy | Hold mass at the cap; flag |
| `run_pearls` | One bank pays more than 24,000 Pearls | 16,200 (the largest base bank is 5,400, at 3,000 mass or more; × 1.5 for Crystal and × 2 for Deep Pockets) | Pay the cap; flag |
| `hour_pearls` | More than 110,000 Pearls from gameplay in 60 minutes | About 75,300: a perfect Shark Pup player with Crystal on every run and Deep Pockets (chapter 05, section 6.1). The trip level is about 1.5 times that, the same margin as `run_pearls`. | Pay nothing further that hour; flag |
| `bank_teleport` | A bank from a position more than 150 studs from the cove mouth one second earlier | — | Reject the bank |
| `wallet_mismatch` | The saved Pearl balance differs from the previous balance plus logged sources minus logged sinks | 0 | Keep the lower figure; flag |
| `income_clock` | A claim of the pile for more hours than the cap, or for a negative time | 8 hours (24 with Tide Watcher) | Clamp to the cap |

Three flags on one account in a day kicks the player from the server with Roblox's standard message (`kick`). Nothing in this chapter bans an account automatically; bans are a manual decision.

## 10. Privacy and policy

| Rule | Detail |
|---|---|
| No personal data | We collect no name, age, gender, location, contact detail, device identifier or chat text. We do not ask players for any of these. |
| Roblox only | All analytics go to Roblox's own services through `AnalyticsService`. No third-party analytics, advertising or tracking code. No player data is sent to any outside server. |
| Demographics | Age group, gender, country and platform breakdowns are read only as the aggregates Roblox shows on its dashboard. We never compute or store them per player. |
| User IDs | Used as the key of the player's save, and inside `funnelSessionId` values (Roblox's own documentation suggests this). Never placed in a custom field, an event name or an item SKU. |
| Custom fields | Fixed lists of values only (2.4). No free text. |
| Alert webhooks [L] | If Roblox Alerts posts to a webhook, the endpoint is private and receives only Roblox's alert payload (metric, threshold, time). |
| Saved data | The profile stores only game state: Pearls, specimens, Codex, goals, streak, `ftue.*`, `ab.*`, counters. |
| Deletion requests | When Roblox forwards a request to erase a user's data, we delete that user's profile from the data store. Document 09 owns the procedure. (From memory of Roblox's process; not re-checked for this chapter.) |
| Purchases | Robux purchases use Roblox's own prompts. We never show a price in real money and never imply a purchase is free. |
| Paid random items | None at launch (canon section 3). If ever added, Roblox's per-player policy check must gate them. |
| Rewarded video [L] | Shown only where Roblox's ad availability check says a video is allowed for that player. A video is always optional and never the default button. |
| Experiments | Players are not told which arm they are in. No arm sells something the other arm gets free, and no arm changes a Robux price. |
| Children | The audience is 9 to 16 (canon). No dark patterns: no countdown pressure on offers, no fake scarcity, no pop-up that hides its close button (chapter 04, section 8.3). |

## 11. Weekly review

Every Monday, 30 minutes, same order. Each number is copied into the review spreadsheet with the previous four weeks beside it. The daily check is a 5-minute look at the alarms in 9.1.

| # | Number | Where | If it is under target | If it is on target |
|---|---|---|---|---|
| 1 | Still playing at T = 60 and T = 180 (targets 80%, 65%) | Onboarding dashboard | Find the weakest onboarding step and fix that beat first. Nothing else gets work until this is on target. | Move to number 2 |
| 2 | First-bank rate (60%) and run 2 start (50%) | Onboarding funnel steps 13 and 17 | Retune the trip home or the cliffhanger; start the matching A/B test | Move on |
| 3 | Day-1 retention (20%, then the similar-game median) | Roblox Retention | Work on reasons to return: first income tick, the welcome-back claim, day-2 goal, tide clock | Look at day 7 |
| 4 | Day-7 retention (6%, then the median) | Roblox Retention | Work on mid-term goals: species pacing, Codex, new traits | Hold the content cadence in document 12 |
| 5 | Average session time (12 minutes) and 10-minute days (55%) | Roblox Engagement; `sess_day_mark` | Look at `sys_session_end` by ctx to see where sessions end; shorten the gap between a gulp and the next run | Move on |
| 6 | Bank rate (band 35% to 60%) and the killer mix | Runs dashboard | Under 35%: weaken the top killer or add currents home. Over 60%: add danger near coves. One killer above 40% of deaths: retune it. | No change |
| 7 | Run funnel by tier against the cumulative targets | Run funnel | A tier with a conversion 10 points under target: raise prey of that tier or lower the next tier's mass requirement (document 05) | No change |
| 8 | Days to each species against canon pacing; sink-to-source ratio (0.6 to 0.9) | Economy dashboard | Too slow: raise goal rewards before lowering prices. Too fast or ratio under 0.5: cut the fastest-growing source. | No change |
| 9 | Payer conversion (0.8%), ARPPU (130 Robux), ARPDAU (1.04 Robux) | Roblox Monetization | Find the purchase funnel with the worst step 1 → 2 (nobody looks) or 3 → 4 (looks, will not pay) and change placement or price | Do not add offers; protect retention |
| 10 | Revive take rate (3%) and what buyers do next | Revive funnel | Under target at step 2 → 3: the offer is not noticed or the price is wrong. Low step 5 → 6: revived players die again; lengthen protection. | No change |
| 11 | Tide pull (1.10) and tide funnel step 3 → 4 | Live events dashboard | Make the warning louder, or the reward clearer; compare events and give the weaker one a better reward | Add the next event in document 12's order |
| 12 | Guard flags per 1,000 daily users; `shop_grant_failed`; `sys_profile_fail` | Guards dashboard | Any grant failure: fix this week. Rising flags on one rule: read the rule's values and tighten validation. | No change |
| 13 | Running experiment: sample so far against plan | Experiments dashboard | Behind plan: extend the end date now, not at the end | Read it on the planned date (8.3) |
| 14 | Store page play-through rate | Roblox Acquisition | Test a new icon or thumbnail | No change |
| 15 | Bank rate and gulped-by-player rate by input type (within 5 points, and within 15%, of touch) | Devices and inputs dashboard | Only with 2,000 or more run ends per input in the last 7 days: apply the next lever in chapter 15, section 4.4, one a week | No change |

**Order of priority when several numbers are under target:** 1, then 3, then 5, then 6, then 9. Retention before session length, and both before money. This matches Roblox's own advice to get day-1 retention and session time right before spending on traffic, and the canon's go/no-go rule.

**The go/no-go read** happens at the first weekly review after the game has passed Roblox's evaluation, so that players under 16 can play (chapter 12, stage 3b), and has then had 100 or more daily users for 14 days: day-1 retention and average session time, each against the similar-game median on Roblox's pages. While only age-checked players of 16 and over can play (stage 3a), the weekly review still runs, but its numbers are not read against targets. Both at or above the median: proceed to public launch work. Either below: one more four-week cycle on numbers 1 to 5, then read again.

## 12. Proposed canon changes

Canon values are used as written throughout this chapter. These are suggestions for `01-game-canon.md`.

| # | Canon section | Suggestion | Why |
|---|---|---|---|
| 1 | 17 | Say that each share is of players who reached control, not of players who joined. | Every clock starts at control, so a player lost while loading never starts one. This chapter divides by onboarding step `03_control`; load losses are tracked separately. |
| 2 | 17 | Add our own targets for day-1, day-3 and day-7 retention (20%, 11%, 6%), bank rate (45%), payer conversion (0.8%) and ARPDAU (1.04 Robux), each marked (tune). | The canon has first-session targets only. The weekly review needs the rest. |
| 3 | 11 and 12 | Ask document 05 for at least one repeatable Pearl sink. | The only sinks are species, cove slots and decorations, all one-off. A player who owns everything can only accumulate, and the MVP has just two of the three. |
| 4 | 12 | Note that private server sales cannot be tracked by in-game events and are read from Roblox's Monetization page. | They are bought on the game page, outside the game. |
| 5 | 10 | Record the tide-pull measure (players online just before the quarter hour ÷ players online between events) as the test of pillar 5. | Pillar 5 has no success measure in section 17. |
