# Solo developer economics and launch mechanics for a new Roblox game (as of 2026-10-13)

Scope note: Discovery signals, Q2 2026 DAU (123M) and the DevEx rate (0.0038 USD per Earned Robux) are excluded per the brief.

Source labels: [OR] = official Roblox, [3P] = third-party estimate, [DA] = developer anecdote. Retrieval: [F] = fetched page, [S] = search snippet only (page not opened). Age: flagged if older than 12 months before 2026-10-13 (i.e. before 2025-10-13).

Fetch failures: create.roblox.com/docs/production/analytics/analytics-benchmarks, /docs/production/monetization/creator-rewards and /docs/production/monetization/paid-access returned HTTP 404 and were not read. Roblox's IR shareholder letters (Q1/Q2 2026) were not fetched in this pass.

---

## Earnings benchmarks (revenue per visit, per DAU, payer conversion, creator distribution)

### Takeaway
No official Roblox figure for Robux per visit, ARPDAU or payer conversion was found. The only official-sourced distribution figures are DevEx payouts from the 2026 developer conference (rounded, 12 months to 30 Jun 2026, [OR] via secondary reporting) and 2020 SEC-filed threshold counts. Treat the median creator figure as the most useful number for a solo developer.

### Cited Findings
- Creators earned roughly USD 1.7B through the Developer Exchange program in the 12 months to 30 Jun 2026, up about 50% year over year; top 10 creators averaged USD 65.7M, top 100 averaged USD 10.8M, top 1,000 averaged USD 1.4M; median enrolled DevEx creator (of 42,000+) earned roughly USD 1,500 in the same period. [OR, reported via secondary] — [S: says.com "Roblox Reveals Its Top 10 Creators..." https://says.com/my/tech/roblox-creators-earn-1-7-billion-developer-payouts]. Date: 12 months to 30 Jun 2026 (current). Not fetched; figures are as reported in the snippet and should be checked against the developer conference material or IR letter before publication.
- 2020 SEC filing (12 months to 30 Sep 2020): over 960,000 developers/creators earned Robux; over 1,050 earned USD 10,000+ and nearly 250 earned USD 100,000+ — [OR, SEC] — [S: SEC S-1/A FY2020/FY2021 pages, https://www.sec.gov/Archives/edgar/data/1315098/000119312520307391/d87104ds1a.htm]. Date: 2020 (older than 12 months; flagged as stale).
- 2022 DevEx: over 11,000 qualified developers/creators earned USD 623.9M (2021: 7,000+ earned USD 538.3M) — [OR, SEC 10-K FY2022] — [S: https://www.sec.gov/Archives/edgar/data/1315098/000131509823000035/rblx-20221231.htm]. Date: 2022 (stale).
- 2025 total DevEx payout: sources conflict. One report says about USD 1.5B; another says "over a billion dollars." — [3P] — [S: secondary press]. Do not use without checking the Roblox 10-K FY2025.
- 2023 developer payout reported at USD 740M — [3P, secondary] — [S: https://wnhub.io/news/other/item-42962]. Stale (2023).
- Benchmark for USD 10K / 100K / 1M creator counts in 2026: none found. The "1M" threshold is not supported by any source found.
- Revenue per visit / per CCU / ARPDAU / payer conversion for Roblox games: not found from any official or fetched source in this pass.

### Inferences
- Median enrolled DevEx creator earning about USD 1,500/yr (2026, reported) implies the typical creator is far below USD 10K/yr. Top-1,000 averages (USD 1.4M) show the distribution is extremely skewed; the expected earnings of a new solo game are closer to the median than to the top tier.
- Earnings are concentrated among a small number of large experiences, so a solo developer should plan around low-five to low-four-figure USD per year unless the game reaches top-1,000 scale.

### Gaps
- No official ARPDAU, Robux-per-visit or payer conversion benchmark found. Roblox Creator Hub analytics pages did not expose these in search results. Next step: fetch the Creator Hub "Monetization" and "Analytics > Revenue" pages once the 404 paths are resolved, or read the Roblox FY2025 10-K.
- No official USD 10K / 100K / 1M creator count for 2025-2026.

---

## Roblox benchmarks for a healthy game (retention, session, play-through, payer conversion)

### Takeaway
Roblox's Creator Hub does not publish fixed day-1/day-7/day-30 "good" numbers. It states benchmarks are shown in the Analytics Dashboard as similar-experience percentiles (50th to 90th), updated daily, with a 100+ DAU threshold to see them. Use the dashboard, not external numbers.

### Cited Findings
- Retention definitions: Day 1 = % of new users returning after first visit; Day 7 is counted on the 8th calendar day; Day 30 on the 31st — [OR] — [F: https://create.roblox.com/docs/production/analytics/retention].
- Benchmark tiers are shown per KPI against similar experiences, using percentile ranges; the example reads a Day 1 retention range of 12.4% to 24.1%, where the 50th percentile is the median peer; the pool is top experiences by playtime — [OR] — [S: https://create.roblox.com/docs/en-us/production/analytics]. Note: the example figure is an illustration in the docs search snippet, not a current benchmark. Not fetched in full.
- Scorecards need 100+ DAU to compare against similar experiences — [OR] — [S: same Analytics page].
- Roblox advises prioritising Day 1 retention and session time, then Day 7 and Day 30, before buying user acquisition — [OR] — [S: analytics docs snippet].
- Third-party benchmark report: low-engagement titles (0-3 min sessions) show Day 1 below 5% and Day 7 below 2%. Source title says 2025 but page updated 10 Jun 2026; figures are not Roblox-published — [3P] — [S: https://gameindustrylibrary.com/documents/the-2025-roblox-benchmark-report].
- Payer conversion at p50 and p90, and average session length benchmarks: not found in any fetched or snippet source.

### Inferences
- Because the dashboard only compares within the peer pool and requires 100+ DAU, a new game cannot see its benchmark percentile until it has some scale. Early soft-launch targets should be set from the third-party figure with explicit caution, then replaced with dashboard percentiles once available.

### Gaps
- Official p50/p90 values for day-1/7/30 retention, session length, play-through rate and payer conversion were not obtained. The analytics benchmark page (/docs/production/analytics/analytics-benchmarks) returned 404 and the expected retention-benchmark page did not contain numbers. Next step: open the Analytics Dashboard inside Creator Hub for a live game with 100+ DAU.

---

## Advertising a new game (Ads Manager / Sponsored Experiences, budgets, CPP, ad credits)

### Takeaway
Ads Manager is live in 2026 with Plays and Engagement objectives, daily or lifetime budgets, and ad credits; a USD 5 first-card charge and a USD 1 temporary hold apply. No official minimum budget amount or typical cost per play was found. Small paid tests are the common approach but the minimum test spend was not sourced.

### Cited Findings
- Budget types: daily budget (maximum per day) or lifetime budget (maximum for the campaign); campaigns use one or the other, not both — [OR] — [F: https://create.roblox.com/docs/production/promotion/ads-manager].
- Cost per play (CPP) = total campaign spend divided by plays. Engagement objective "Expect a higher cost per play (CPP)." No amount given — [OR] — [F: ads-manager].
- Minimum ad credit purchase is 1 ad credit; 1 ad credit = 263 Robux (conversion rate as stated in the docs snippet) — [OR] — [F: ads-manager and S: https://create.roblox.com/docs/cloud/guides/advertising]. Converting Robux to ad credits is irreversible.
- Card charges and "Spent" column use USD. A first-time card charge of USD 5 is made at campaign submission; a temporary USD 1 hold is refunded within 7 business days — [OR] — [F: ads-manager].
- Eligibility: Ads Manager requires age 13+ and a verified email; adding a card requires age 18+; Robux-to-ad-credit conversion for ages 13+ — [OR] — [F: ads-manager].
- Recent Players audience requires 10,000+ recent players; Lapsed Players requires 20,000+ lapsed players. A new game will not qualify for these audiences at launch — [OR] — [F: ads-manager]. This is the most important constraint for a new game.
- Cancellation allowed up to 6 hours before scheduled start; ad moderation within 24 hours; asset moderation within 48 hours; reporting delay up to 48 hours; attribution window up to 30 days — [OR] — [F: ads-manager].
- Auto-bidding: set a budget and duration; Roblox calculates the bid for most plays at lowest cost — [OR] — [S: ads-manager/sponsoring-experiences snippet].
- Minimum budget amount and typical CPP / CPC: not stated on the fetched page — [OR] — [F: ads-manager shows no figures]. Cloud API rejects budgets below minimum with the amount in the error message — [OR] — [S: advertising guide].

### Inferences
- Because the Recent Players audience gate is 10,000 players, a new game will likely run Plays-goal campaigns on broad audiences first. Small paid tests (a few USD per day) appear to be the normal seeding method, but this is inferred from the presence of daily budgets and the lack of a required minimum, not sourced.

### Gaps
- No official minimum daily or lifetime budget in USD found.
- No official or third-party typical CPP or CPC figure found for 2025-2026. Next step: Ads Manager UI estimate for a test campaign, or Cloud API error message for the minimum.
- Whether small paid tests are the normal method: developer anecdote not searched in this pass.

---

## Other earning routes without avatar items

### 1. Creator Rewards (replacement for engagement-based payouts)

#### Takeaway
Creator Rewards has two parts: Daily Engagement (5 Robux per qualifying Active Spender per day) and Audience Expansion (35% share on a new or reactivated user's first USD 100 of qualifying purchases over 60 days). Awards go into Earned Robux with a 60-day hold.

#### Cited Findings
- Daily Engagement began 24 Jul 2025 with no enrollment required. Creators earn 5 Robux for each Active Spender who plays for 10+ minutes in a day, if the experience is one of the first three the user launches that day. Active Spender = at least USD 9.99 in Qualifying Purchases in the past 60 days — [OR] — [F: https://create.roblox.com/docs/en-us/creator-rewards] (fetched, dated 2026 copyright only; no "last updated" date shown).
- Audience Expansion: creators earn 35% of a New or Reactivated User's first USD 100 of Qualifying Purchases in first 60 days; requires 10+ minutes on joining day and average 100+ DAU over the 60 days — [OR] — [F: creator-rewards page].
- Awards are credited as Earned Robux with a 60-day holding period; no minimum payout threshold stated on page; cash-out is subject to DevEx terms — [OR] — [F: creator-rewards page].
- Paid access experiences are eligible for Creator Rewards — [OR] — [F: creator-rewards page].
- Third-party estimate: community estimates of 5-15 Robux per qualifying user per day; sources contradict each other on payout timing (daily vs monthly). Not verified — [3P] — [S: https://rolearn.dev/insights/roblox-creator-rewards-payout-guide].

#### Inferences
- Per-user Daily Engagement value is small (5 Robux per qualifying user per day, about USD 0.02 at the DevEx rate in the brief). Real value depends on Active Spender traffic. Audience Expansion requires 100+ average DAU, so it is out of reach for a new game until it reaches that scale.

#### Gaps
- Per-visit or per-hour Creator Rewards economics not in official sources. Payout timing conflicts between sources.

### 2. Rewarded Video and Immersive Ads

#### Takeaway
Rewarded video launched with Google in April 2025 and is available to developers; Roblox-published eCPM was not found. A third-party trend source gives USD 6-12 per 1,000 views, and creators report Roblox keeps 70% of ad revenue. Immersive Ads eligibility not found.

#### Cited Findings
- Rewarded video: up to 30-second full-screen ads for extra lives or in-game currency; launched in April 2025 with Google — [OR, via press] — [S: https://www.emarketer.com/content/roblox-expands-rewarded-video-tools-creators-advertisers] and [S: https://ppc.land/roblox-expands-google-advertising-partnership-with-rewarded-video-launch/]. Date: April 2025 (older than 12 months, relevant as context).
- Developers can use rewarded videos across the platform from 11 Nov (year not stated in snippet; likely 2025) — [3P] — [S: https://www.mexc.com/news/177474].
- Average eCPM USD 6-12 per 1,000 views, varies by region and advertiser demand — [3P] — [S: https://rolearn.dev/trend-reports/roblox-monetization-trends-devex-creator-rewards]. Not confirmed by Roblox.
- Roblox keeps 70% of ad revenue, creator keeps 30% — [DA/3P] — [S: rolearn/press snippet]. Not verified.
- A top game (Brookhaven) reportedly earns five figures per month in ad money — [DA] — [S: rolearn guidance].
- Upcoming: Studio plug-in for rewarded video templates expected Q4 2026; pre-gameplay rewarded video surface; multi-reward option. Stated as planned — [OR, DevConf coverage] — [S: mediapost / emarketer snippet]. Planned, not confirmed as shipped.
- Immersive Ads eligibility and eCPM: no findings.

#### Inferences
- Rewarded video at USD 6-12 eCPM with a 30% creator share implies roughly USD 2-4 per 1,000 rewarded views to the creator, if the third-party figures are accurate. That is a range to test, not a planning number.

#### Gaps
- Official rewarded video eligibility rules and creator revenue share not fetched.
- Immersive Ads not researched.

### 3. Subscriptions, private servers, paid access

#### Takeaway
Paid access pricing and private server rules could not be fetched (404). Snippet-level info only; treat as unverified.

#### Gaps
- Paid access Robux range, local-currency pricing availability and revenue share: not found in fetched source (paid-access page returned 404). Search snippet not obtained.
- Private server fees and revenue share: not found.
- Subscriptions (experience subscriptions): not researched in this pass.
- Next step: locate the current paid access and private server doc page via search, then fetch.

---

## Player attitudes to avatar replacement and skin/species sales

### Takeaway
Search found broad player backlash to Roblox's own avatar forced migration (Classic Faces 2023; Classic Heads and Faces retirement Jan-Feb 2026), but no DevForum or community discussion about a game replacing the player's avatar was found. No price points for animal or vehicle skins found.

### Cited Findings
- Classic Faces removal in 2023 drew complaints that Roblox had promised those faces would stay; Roblox's January 2026 retirement of Classic Heads and Faces met resistance on Reddit and X, and a later DevForum follow-up set a February 2026 conversion date with a facial-animation off setting — [OR/community mix] — [S: https://www.dexerto.com/roblox/roblox-under-fire-for-removing-classic-avatars-2226960/; https://www.lodj.ma/Roblox-retires-Classic-Faces-official-conversion-sparks-community-pushback_a166718.html]. Note: these are secondary press, not fetched; the 2026 event is within 12 months.
- Roblox's avatar item store is the main avatar monetisation route; no fetched source on animal-sim or vehicle skin pricing.

### Inferences
- Avatar-replacement is not a researched norm; the backlash is about Roblox's own avatar changes, which is adjacent evidence only.

### Gaps
- No DevForum thread or community discussion specifically on games replacing the avatar was found.
- No price points for animal-sim species or vehicle skins found. Next step: search Roblox animal simulator game pages or Roblox Store for named titles.

---

## Experience guidelines: maturity/content label, paid random items, age checks for chat, ages 9-16

### Takeaway
Maturity label is set through the Maturity & Compliance Questionnaire and the result drives audience access; paid random items require disclosed odds as percentages summing to 100% and can be restricted by region per user; chat is gated by age checks across all regions since January 2026, with chat limited to adjacent age groups and under-9s off by default. A game aimed at 9-16 will be inside the age-group chat rules.

### Cited Findings
- Maturity: questionnaire generates a label plus content descriptors. Minimal/Mild games reach Roblox Kids and Select users; Moderate reaches Select and standard users; Restricted limited to age-verified 18+. Kids and Select audiences require extra publishing requirements. Unlabeled experiences are treated as Moderate and may be restricted — [OR] — [S: https://create.roblox.com/docs/en-us/production/promotion/content-maturity].
- The questionnaire asks the developer to base answers on the most mature content players can encounter; it covers developer-created content, not UGC avatar items. Account must be at least 30 days old to fill it — [OR] — [S: content-maturity page snippet].
- Paid random items: must show every possible outcome and numerical odds; odds as percentages totalling exactly 100%; a standalone (i) icon is not enough. Indirect purchases (e.g. spending in-game currency) also require disclosure before spend — [OR] — [F: https://create.roblox.com/docs/production/monetization/paid-random-items].
- Paid random items regional restriction: per user via PolicyService:GetPolicyInfoForPlayerAsync() returning ArePaidRandomItemsRestricted and IsPaidItemTradingAllowed. When restricted, users cannot interact with paid random item generators; creators must offer a listed alternative (free earnable path, direct guaranteed purchase, or block). Specific countries not named on the page — [OR] — [F: paid-random-items].
- Paid random items: no age requirements stated; no penalties described; page has no last-updated date. A search snippet says the policy was updated in August 2026 (not confirmed on page) — [3P] — [S: search result].
- Age checks for chat: from 7 Jan 2026 (announced), every user globally must complete facial age estimation or ID verification to access chat. Six age groups: under 9, 9-12, 13-15, 16-17, 18-20, 21+. Chat is limited to adjacent groups. Under-9 experience chat is off by default unless parent consents — [OR] — [S: https://techcrunch.com/2026/01/07/roblox-now-requires-all-users-globally-to-complete-age-checks-to-access-chat; https://corp.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat; https://devforum.roblox.com/t/age-check-requirement-to-chat-now-live-globally/4226101]. Users who decline lose chat. Roblox says it will reduce impact on social games but gave no specific developer API in the snippet.
- Developer concern noted about chat-dependent and social games — [3P] — [S: thecapitolforum paywalled snippet].

### Inferences
- A 9-16 audience will fall across the under-9, 9-12, 13-15 and 16-17 age groups. Chat in a game for this audience will be limited to neighbouring age groups, which reduces social reach. Social-dependent design should be checked against this.
- Paid random items disclosure is required regardless of target age; the age rule is not stated in the fetched page.

### Gaps
- Maturity label specific rules for ages 9-16 (e.g., whether a Kids label is available and what publishing requirements apply) not fetched in full.
- Exact list of regions where paid random items are restricted: not published on the fetched page.
- Developer-side APIs for chat-eligibility detection: not confirmed.

---

## Launch practice (soft launch, thumbnail/icon A/B tests, localisation, update cadence)

### Takeaway
Not researched in this pass. No fetched or snippet source for soft-launch practice, Creator Hub thumbnail/icon A/B testing or automatic translation was obtained.

### Gaps
- Soft-launch practice: no source.
- Creator Hub thumbnail/icon A/B testing tools: not verified in any fetched source.
- Automatic translation / localisation: not verified.
- Update cadence reported by small teams: no source.
- Next step: search DevForum "soft launch" and "A/B test thumbnail" threads and fetch them.

---

## Summary of open items
1. No official Roblox ARPDAU, Robux per visit, payer conversion or p50/p90 retention figures obtained. Analytics benchmark page returned 404.
2. Creator distribution: 2026 median (about USD 1,500/yr) is reported in press, not fetched from an official page. Verify against Roblox FY2025 10-K or the developer conference material.
3. Ads Manager: no minimum budget or CPP figures. Recent Players audience gate (10,000 players) blocks targeting for new games.
4. Creator Rewards: official daily mechanic confirmed (fetched); per-user rate and payout timing are third-party only.
5. Paid access, private servers, subscriptions: not obtained (paid-access page returned 404).
6. Launch practice and player-attitude questions: not researched successfully.
