# Keeping new players through the first 1-2 minutes of a Roblox game (as of 2026-10-13)

Labels: **[OFFICIAL]** = Roblox Creator Docs / DevForum staff; **[3P]** = third-party; **[OPINION]** = blog or community view. Pages fetched on 2026-10-13 are undated unless stated.

## 1. Roblox official guidance on onboarding / FTUE

- **[OFFICIAL]** FTUE (first-time user experience) = "the first few minutes of gameplay." Success is judged by **Day 1 retention** and **onboarding goals**. Three practices: teach the essentials, get to the fun quickly, leave players wanting more. No numeric timing targets on the page. Source: https://create.roblox.com/docs/en-us/production/game-design/onboarding
  - Tutorial content: teach navigation/interaction controls and the core loop ("what to do and why"); show value quickly via progression, social motivators, starter items/currency; end onboarding with visible short/mid/long-term goals and a deliberate "moment of joy."
  - Tactics named: free starter equipment or soft currency; low early XP thresholds; A/B tests of tutorial steps (e.g., "a shorter dialogue sequence versus a guided arrow") via Experiments.
  - Not covered on that page: tutorials-by-doing, skip buttons.
- **[OFFICIAL]** Analytics retention page: "Avoid long tutorials to help users get to the fun as quickly as possible"; use "a brief tutorial or contextual info like tooltips"; "Deliver a joyful moment after users complete your core loop for the first time"; "Identify and fix big drop-offs." Source: https://create.roblox.com/docs/en-us/production/analytics/retention
- **[OFFICIAL]** Engagement page: fun should happen "within the first five minutes of joining." Source: https://create.roblox.com/docs/en-us/production/analytics/engagement
- **[OFFICIAL]** Discovery page: "first play bounce rate" = "the rate at which users leave your game after a short play session"; a negative signal. Reported as average rates for **under 60 seconds** and **61-180 seconds**. No target values; benchmarks are only shown relative to similar games on the analytics page. Also: play-through rate (top-priority, "Recommended for You" sort, no time segments); playtime capped at 60 min/user/game/day; "qualified play" filters accidental clicks. Play-days windows: Day 1, Days 2-7, Days 8-28. Source: https://create.roblox.com/docs/discovery.md
- **[3P]** A June 2026 video summary says bounce rate replaced QPTR. Unverified against Roblox announcements. Source: https://sozai.app/transcript/roblox-algorithm-changes-june-2026/
- **[3P]** DevForum thread reports Open Cloud API keys cannot read the internal endpoints that serve bounce/discovery data; a .ROBLOSECURITY cookie is needed (called unstable). Source: https://devforum.roblox.com/t/endpoints-for-first-play-bounce-rate-and-creator-rewards/4752572
- **[OFFICIAL] Retention/Day 1 levers:** core loop, first-time user experience, and performance. If "New User First Session Retention" drops, check onboarding friction from recent updates. Sources: https://create.roblox.com/docs/en-us/production/analytics/retention ; https://create.roblox.com/docs/en-us/production/analytics (search snippet; not fully fetched)

## 2. Funnel analytics (AnalyticsService)

- **[OFFICIAL]** `LogOnboardingFunnelStepEvent(player, stepNumber, stepName, customFields?)` — one-time funnel (once per user), e.g., tutorial steps.
- **[OFFICIAL]** `LogFunnelStepEvent(player, funnelName, funnelSessionId, stepNumber, stepName, customFields?)` — recurring funnel (e.g., shop checkout); session ID via GUID or `<playerId>-<itemId>`.
- **[OFFICIAL]** Limits/rules from the funnel-events page:
  - Dashboard Funnel page appears once a game sends funnel events; up to **10 funnels** can be tabbed.
  - Analytics tracks each user's **10 most recent session IDs** per funnel.
  - Repeated steps count once but still use the global rate limit; skipping a step auto-completes earlier steps.
  - Events are **server-only** and only in **published** games. Validate step numbers server-side.
  - A funnel starts at its first logged step (log step 1 on `PlayerAdded` to start at join).
  - Saved step expires after **180 days** without events for that funnel.
  - Filters (player, device, custom) apply only to the first step; cohorts are by entry date.
  - No published limits on step count, name length, or custom-field count (only a global rate limit is mentioned).
  - Source: https://create.roblox.com/docs/en-us/production/analytics/funnel-events.md
- **[OFFICIAL, Roblox staff-category DevForum post, 2024-07-12]** "Improving Onboarding through Funnel Events" (BreakfastCandy): Plant example: Step 1 "In Farm" 100% → Step 2 "Plant Seed" 29.52%, fewer than 3% reach the final step. Biggest fix: an icon over player pots showing where seeds go. Tactics: name locations in quest objectives, in-world price displays, clearer shop flows, fix earliest drop-offs first, monitor funnel for a few days after changes. Source: https://devforum.roblox.com/t/improving-onboarding-through-funnel-events/3064458

## 3. Concrete tactics (documented or widely cited)

- **[OFFICIAL]** Time-to-fun: avoid long tutorials; tooltips and contextual info over text walls (retention page, above).
- **[OFFICIAL]** Early rewards: free starter items/currency; low early XP levels (onboarding page).
- **[OFFICIAL]** Joyful moment after first core-loop completion (retention page).
- **[OFFICIAL]** Quest objectives that name the location (funnel DevForum post, above).
- **[OPINION/3P]** Contextual teaching (introduce mechanics when needed) beats long tutorials; the first 30-60 seconds matter most. Source: https://www.creation.dev/glossary/onboarding (generic, not Roblox-specific)
- **[OPINION/3P]** Unity guidance: introduce mechanics gradually, starting with the most engaging. Source: https://unity.com/how-to/10-first-time-user-experience-tips-games
- **[OPINION/3P]** Early-win guarantees, bots/easy opponents in first match, time-to-first-reward targets, and "come back tomorrow" hooks: no Roblox-official source found in this pass.

## 4. What top games do in the first 2 minutes (fan guides only; not verified)

No developer source found. Fan guides are low-quality SEO content; treat as weak.
- **Grow a Garden** [3P]: join, walk to an open plot, claim it as a free starting garden; start with ~20 Cash to buy Carrot seeds; loop is plant, wait, harvest, sell; multi-harvest crops give passive income early. Sources: https://avergames.com/games/grow-a-garden/beginners-guide ; https://sportskeeda.com/roblox-news/grow-garden-a-beginner-s-guide
- **Steal a Brainrot** [3P]: buy a few cheap Common Brainrots for early income, practice stealing from weak bases, buy base-lock/shield when available; warning that rebirth resets brainrots and money. Source: https://fandomwire.com/14-effective-stealing-tips-in-steal-a-brainrot-that-all-pros-are-abusing/ (weak)
- **99 Nights in the Forest** [3P, fan wiki]: find the campfire (safe zone), gather wood, return to the campfire at night; spend day 1 on crafting. Source: https://99nightsintheforest.tomolingo.com/99-nights-in-the-forest-tutorials ; https://www.sportskeeda.com/roblox-news/99-nights-forest-a-beginner-s-guide
- **Fisch**: no usable source found in this pass.

## 5. Loading, join time, and streaming

- **[OFFICIAL]** StreamingEnabled: enabled by default for new Studio places; applies only to Workspace descendants (not ReplicatedStorage/ReplicatedFirst). Defaults: StreamingMinRadius 64, StreamingTargetRadius 1024 (keep target > min; equal values remove the buffer). Join benefit: "Players can start playing in one part of the world while more of the world loads in the background." StreamingIntegrityMode PauseOutsideLoadedArea recommended. Persistent models: wait for Workspace.PersistentLoaded. Source: https://create.roblox.com/docs/en-us/workspace/streaming
- **[OFFICIAL]** ContentProvider docs: preload only essentials (loading-screen, UI, starting-area assets), not the whole Workspace; occasional pop-in is an acceptable trade-off; allow skipping the loading screen or auto-skip after a set time. Source: https://create.roblox.com/docs/en-us/reference/engine/classes/ContentProvider.md
- **[OFFICIAL]** StreamingEnabled page gives no place-size guidance and no join-time numbers.
- **[3P]** Waiting on `game.Loaded` is not enough for Decals; PreloadAsync closes the gap. Third-party tutorials show a `wait(2)` pattern; verify against official docs.

## 6. Load-time tolerances (mobile/app)

- **[3P, 2026]** Atomik Research for the State of Web Gaming Report: 46% of web gamers stopped playing a mobile game because it took too long to open or load; 32% of console/PC players quit over start time. Sample is web gamers. Source: https://www.sentinelassam.com/cities/guwahati-city/web-gamers-quit-slow-apps-as-browser-play-gains-on-social-media (search snippet only; original report not fetched; treat as secondary)
- **[3P, 2017]** CA Technologies survey (6,770 consumers, 18 countries): 68% have left an app over load times; most want apps to open in about 4 seconds; over half want under 3 seconds. Source: https://thisisglance.com/learning-centre/whats-normal-when-it-comes-to-app-loading-times (secondary)
- **[3P, vendor]** Top-up abandonment: 89% abandon if over 30 seconds (buffhub press release, April 2026). Commercial source; not game-load data.
- Unsourced "70% abandon" and "53% leave after 3 s" figures circulate; do not cite.

## 7. Benchmarks: Day 1 / Day 7 retention and session length

**Roblox official:** No published Roblox benchmark numbers for D1/D7 or session length. Roblox defines D1 (return next day), D7 (day 8), D30 (day 31), and "average session time" = total time / number of sessions (Creator Docs, undated). Source: https://create.roblox.com/docs/en-us/production/analytics/retention ; https://create.roblox.com/docs/en-us/production/analytics/engagement

**Third-party (mobile, not Roblox-specific):**
- **[3P, GameAnalytics 2026 report, covering 2025 data, 16,262 titles with 1,000+ MAU]:** median D1 ~22%; top 10% ~40%; top 1% 64-68%; median D7 just under 4%; median D30 ~0.7%. Session length: 5.2 min top quartile, up to 22 min for top 1%. Report says value unclear in the first 5-15 minutes causes churn. Source: https://gamedevreports.substack.com/p/gameanalytics-mobile-and-pc-game (sponsored by PWN Games) ; https://gameindustrylibrary.com/documents/gameanalytics-mobile-and-pc-game-benchmarks-in-2026-sponsored-by-pwn-games
- **[3P]** Vendor blog (Adjust 2025 data): average ~27% D1, 8-14% D7, 3-7% D30. Source: https://blog.playio.co/d1-d7-d30-retention-benchmarks-2026 (one of several vendor blogs)
- **[3P/OPINION]** Playio "good" target D1/D7/D30 = 35/15/5 (a target, not an observed average).
- **[3P, unverified]** RoLearn guide claims most Roblox games lose more than half of new players before Day 2. Source: https://rolearn.dev/guidance/first-week-retention-optimization
- No dated Roblox-specific D1/D7 benchmark was found. Roblox's Creator Dashboard shows similar-game benchmarks but those numbers were not accessible in this pass.

## Gaps
- Could not verify Fisch first-session design.
- Could not find official Roblox guidance on early-win guarantees, skip menus, or time-to-first-reward targets.
- Could not find a Roblox DevForum best-practices thread on FTUE.
