# 12 · Launch, live operations and compliance

This chapter defines how GULP is released, run and kept within the rules by one person. Document 01 (game canon) wins wherever this chapter disagrees with it. Document 05 owns prices, document 09 owns the technical design, and document 11 owns the store page and marketing.

Numbers marked **(tune)** are first guesses. `S` is soft-launch day and `P` is public-launch day. All clock times are UTC.

## 0. Platform facts this chapter relies on

Checked on 13 October 2026. Status key: **V** = read on an official page this session. **R** = verified earlier in `docs/research/`. **S** = secondary source only. **U** = could not be verified.

| # | Fact | Status | Source |
|---|---|---|---|
| L1 | Account tiers: Roblox Kids (5 to 8), Roblox Select (9 to 15), Roblox (age-checked 16 and over). Kids can play Minimal and Mild games. Select can play Minimal, Mild and Moderate. | V | [Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select), [Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity) |
| L2 | To reach Kids and Select, the creator needs: an account in good standing, an age check (ID if 18 or over), 2-step verification, a complete questionnaire rated Minimal, Mild or Moderate, and either Roblox Plus or Premium for 2 consecutive months or a one-time refundable fee per game. The fee is 1,000 Robux according to the staff announcement; the docs page gives no amount. It is refunded 90 days after the game becomes eligible, or 90 days after payment if it never does, and is lost only if the game is permanently removed. | V | Same page, [staff announcement, June to July 2026](https://devforum.roblox.com/t/roblox-kids-and-select-global-launch-upcoming-updates-to-eligibility-ads-manager-and-expedited-review/4685717) |
| L3 | Evaluation: a new game is first available only to age-checked users of 16 and over. It passes after 250 unique plays by highly engaged, age-checked players within 60 days (docs page). The staff announcement gave 500 to enter and 25 to stay. "Highly engaged" depends on account age, playtime in the game and platform spend. Progress is on the Audience Reach dashboard. | V (the two sources differ) | Same two sources |
| L4 | Expedited review: a refundable fee (50,000 Robux on the docs page, 100,000 in the staff announcement) that replaces the play threshold, with review in up to 48 hours. | V (the two sources differ) | Same two sources |
| L5 | A parent can allow a specific game for a child with the Approved Experience control. | V | [Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select) |
| L6 | Roblox Plus costs 4.99 US dollars a month. | V | [Roblox newsroom](https://about.roblox.com/en-au/newsroom/2026/04/introducing-roblox-plus-subscription) |
| L7 | Maturity labels come from the Maturity & Compliance Questionnaire (Creator Dashboard, Configurations, Content Rating). Answer for the most extreme content a player can meet. Minimal: occasional mild violence. Mild: repeated mild violence, mild fear, mild crude humour. A game with no label is restricted for all players. A content change that alters an answer requires resubmission. | V | [Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity) |
| L8 | Access settings: a new game is private. Early testers: up to 10 invited friends. A Playtest list. A "Friends" switch. Public. "Exclude from recommendations" is under Audience, Advanced Settings. At most 5 first-time releases a day. | V | [Publish games](https://create.roblox.com/docs/production/publishing/publish-experiences-and-places) |
| L9 | Benchmarks against similar games appear at 100 or more daily users and update daily. Roblox advises getting day-1 retention and session time right first, then day 7 and day 30, then payer conversion. | V, R | [Analytics](https://create.roblox.com/docs/en-us/production/analytics) |
| L10 | Publishing does not move players. Restart servers from Configurations, Server management: "only outdated servers", with a delay of 1 to 60 minutes. `ServerRestartScheduled` fires in the game first. To stop players rejoining, revoke public access. | V | [Update games](https://create.roblox.com/docs/projects/update-games) |
| L11 | Place Version History: "Restore" creates a new version and does not publish it. The place must then be published from Studio and the servers restarted. | V | [Version history](https://create.roblox.com/docs/en-us/projects/version-history) |
| L12 | Configs: key-value settings read with `ConfigService`, changed without publishing. "Publish now" reaches servers in about 15 seconds to 1 minute. Up to 1,000 configs. Values can differ by country, language, new or returning, and payer status. | V | [Configs](https://create.roblox.com/docs/production/configs) |
| L13 | Data store versioning: the first write to a key in each UTC hour creates a backup that is kept for 30 days after it is overwritten. `ListVersionsAsync` and `GetVersionAsync` read old versions. A snapshot of all data stores can be taken once a day through Open Cloud, and Roblox advises taking one before an update that changes how data is stored. | V | [Data store versioning](https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching) |
| L14 | Experience notifications: only for opted-in users of 13 and over. One per user per day per game. Text up to 99 characters. The game needs 100 visits. Content must relate to the player's own activity and must not use false time pressure or disguised ads. Under-13s receive only update announcements. | V | [Experience notifications](https://create.roblox.com/docs/production/promotion/experience-notifications) |
| L15 | Update announcements: 60 characters, once every three days. Events: up to 10 ongoing or upcoming, with a "Notify Me" button. Featuring submissions must be made 7 days ahead, and Roblox says the best events run 7 to 30 days. | V | [Events and updates](https://create.roblox.com/docs/production/promotion/experience-events) |
| L16 | Community announcements can notify all members once every 7 days. Polls, forums and announcement analytics are live. Player Support Tickets were "coming soon" in May 2026; their current state was not checked. | V | [Community tools post](https://devforum.roblox.com/t/new-tools-to-engage-your-communities-on-roblox-polls-analytics-support-tickets-and-more/4657552) |
| L17 | Badges: 5 free per game per 24 hours (GMT), then 100 Robux each. 512×512 image, cropped to a circle. | V | [Badges](https://create.roblox.com/docs/production/publishing/badges) |
| L18 | Passes: icon up to 512×512 in .jpg, .png or .bmp, cropped to a circle. Passes sold in other games were switched off from 30 May 2026. | V | [Passes](https://create.roblox.com/docs/production/monetization/game-passes) |
| L19 | Private servers: switched on under Audience, Access Settings, with a monthly Robux price or free. They cannot be combined with paid access. Changing the price cancels every active subscription. | V | [Private servers](https://create.roblox.com/docs/production/monetization/private-servers) |
| L20 | Rewarded video: the game must be public, have no free-form user creation, have an approved questionnaire and average 2,000 unique visitors a month. The publisher must be 13 or over with 2-step verification and a verified ID. Availability is checked per player with `AdService:GetAdAvailabilityNowAsync`. A reward must be a developer product that is normally sold for Robux, must not be random, and must not gate progress. Roblox suggests rewards worth about 3 to 10 Robux. | V | [Rewarded video ads](https://create.roblox.com/docs/production/promotion/rewarded-video-ads) |
| L21 | Paid random items: every outcome and its odds must be shown as percentages that total 100%, including when bought with in-game currency. `ArePaidRandomItemsRestricted` must be checked per player. Every outcome must have some value. | V, R | [Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items), [Community Standards](https://about.roblox.com/community-standards) |
| L22 | Chat needs an age check and is limited to nearby age groups (January 2026). Chat is off by default for Kids and for Select users who have not been age-checked. | R, V | [Staff post](https://devforum.roblox.com/t/age-check-requirement-to-chat-now-live-globally/4226101), [Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select) |
| L23 | Community Standards: off-platform links only through Social Links; no calls from the game to third-party advertising or measurement services; no personalised activity profiles of users; misleading metadata is prohibited; compensated content is advertising; contests with real-money prizes are not allowed without Roblox. | V | [Community Standards](https://about.roblox.com/community-standards) |
| L24 | Social links are visible only to age-checked users of 16 and over. At most three. None inside the game. | V | [Social links](https://create.roblox.com/docs/production/promotion/social-media-links) |
| L25 | Right to erasure: Roblox sends a daily inbox message listing pending requests and the affected games. Deletion templates and a webhook can automate it. The creator stays responsible for deleting all personal data. | V | [Right to erasure](https://create.roblox.com/docs/production/publishing/about-GDPR-and-CCPA) |
| L26 | Audio: Creator Store audio is free to use on Roblox. An ID-verified account can import 2,000 audio files per 30 days at no charge. Files up to 20 MB and 7 minutes. Uploaded audio must be owned or licensed. | V | [Audio assets](https://create.roblox.com/docs/en-us/audio/assets) |
| L27 | Automatic translation: 18 languages, with character quotas. It fills only blank entries. Automatic Text Capture collects interface strings. | V | [Automatic translations](https://create.roblox.com/docs/production/localization/automatic-translations) |
| L28 | Developer Exchange: 0.0038 US dollars per Earned Robux, a 30,000 Robux minimum, one cash-out a month. | R | [Developer Exchange](https://create.roblox.com/docs/en-us/production/monetization/developer-exchange.md) |
| L29 | Ads Manager and Creator Rewards: see document 11, facts F18 and F19. | V, R | Document 11 |
| L30 | Real-time performance alerts and custom error reports were announced on 24 August 2026. | S | [GamesBeat](https://gamesbeat.com/roblox-announces-new-creator-tools-for-analytics-a-b-testing-and-live-ops-exclusive/) |
| L31 | Roblox's refund process for in-game purchases, and whether refunded Robux are taken back from the creator. | U | No official page found |
| L32 | `Players:BanAsync` exists (verified in document 09). The names of the Game Settings security switches were not checked. | R, U | Document 09 |

## 1. Release stages

### 1.1 Overview

| | 1. Private test | 2. Friends-and-family test | 3. Soft launch | 4. Public launch |
|---|---|---|---|---|
| **Goal** | The loop works on a phone and saves are safe | Strangers to the design get through the first session without help; servers work with real players | Pass Roblox's evaluation, reach 100 daily users, and read the benchmarks | Release the full launch content to everyone and begin weekly updates |
| **Who can play** | The developer and up to 10 invited early testers (L8) | People on the Playtest list and the developer's Roblox friends (L8). 30 to 60 people (tune). | Public. In practice **3a:** only age-checked users of 16 and over until evaluation passes (L3). **3b:** everyone the maturity label allows. | Everyone the maturity label allows |
| **Build** | The soft-launch slice (chapter 13, section 3), in GULP Staging | The slice, in GULP Staging | The slice at `S`, in the live game. The rest of [MVP] is added during soft launch (canon section 15): the Eel, Moon Tide, the Gull and the Codex before the go/no-go, the remainder after a "go" (chapter 13, sections 3.4 and 6.2). | The full [MVP] plus everything tagged [L] |
| **How long** | 2 weeks after the slice is feature-complete (tune) | 2 weeks (tune) | 8 to 12 weeks to the go/no-go (tune). Hard limit 20 weeks. After a "go" the game stays live while the launch content is built. | The launch period is 4 weeks, then live operations |
| **Base-case dates** (chapter 13, section 4.1; they move if chapter 13 re-dates) | Mon 1 Mar to Sun 14 Mar 2027 | Mon 15 Mar to Sun 28 Mar 2027 | `S` is Thu 1 Apr 2027, 15:00 UTC. 3b is estimated for Thu 22 Apr 2027. Go/no-go on Mon 21 Jun 2027. Full [MVP] live on Thu 12 Aug 2027. | `P` is Thu 20 Jan 2028, or Thu 9 Dec 2027 if the cut candidates are removed |
| **Entry criteria** | Every item of the soft-launch slice (chapter 13, section 3.2) exists and is playable on a phone | Stage 1 exit met | Stage 2 exit met. Account requirements in L2 met. The soft-launch store set (rows G4 to G6) approved by moderation. | The canon go/no-go is passed. The [L] content has been through a one-week private test. |
| **Exit criteria** | 10 sessions in a row with no severity 1 bug (section 8.2). No save loss in 100 test saves. First bite within 10 seconds for 9 of 10 testers. | With 30 or more first-time players, each canon success measure is within 10 points of its target (tune). Two sessions with 12 or more players on one server. No save loss. | **Go:** with 100 or more daily users, day-1 retention and session time are at or above the median for similar games (canon section 17). | None. Section 9 sets the decision points. |
| **What we measure** | Crashes, script errors, save round-trips, frame rate on the reference phone, time to first bite | The canon section 17 funnel, session length, where players die, server performance with 12 to 24 players, written feedback | Qualified play-through rate, first-play bounce, the section 17 funnel, day-1 and day-7 retention, session time, highly engaged plays, daily users, purchase success rate | All of stage 3, plus day-30 retention, payer conversion, revenue per paying user, play days per user |

### 1.2 Four experiences, not one

Document 09, section 17.1 owns this list. Data stores belong to an experience, so test saves and player saves never mix.

| Game | Purpose | Access | Saves |
|---|---|---|---|
| **GULP Dev** | Daily development in Studio | The developer only | Mock saves by default |
| **GULP CI** | Automated checks | Nobody | Mock saves |
| **GULP Staging** | Stages 1 and 2, and the test of every later update | Private, early testers, Playtest list | Its own real data stores, safe to wipe |
| **GULP** | Stages 3 and 4 | Public from `S` | Player saves. Never wiped. |

A build is always published to GULP Staging first. The same commit is then published to GULP. Saves made during stages 1 and 2 do not carry over, and testers are told so before they start.

### 1.3 Stage 2: younger testers

GULP's core audience is 9 to 16, and a new game cannot be played by Kids or Select accounts (L3). A parent can allow a specific game with Approved Experience (L5). Whether that works for a game that is not yet public is unverified. Plan for at least 10 testers aged 9 to 15 (tune). If Approved Experience does not work for a private game, run those sessions in person on the developer's own account and device, with a parent present.

### 1.4 Stage 3 in two parts

| | 3a. Trial phase | 3b. All ages |
|---|---|---|
| Starts | `S` | The day the Audience Reach dashboard shows evaluation passed |
| Players | Age-checked, 16 and over | Kids, Select and 16 and over, as the label allows |
| Main task | Collect the highly engaged plays needed (250 on the docs page, 500 in the staff post; read the dashboard). Fix the first-session funnel. | Reach 100 daily users and hold it for 14 days. Read the benchmarks. |
| Traffic | Short videos, the Roblox community, the Engagement ad objective (document 11, section 10) | The same, plus Home recommendations to the core audience, plus the Plays ad objective |
| Target length | 2 to 4 weeks (tune). The evaluation window is 60 days. | 6 to 8 weeks (tune) |
| If stuck | After 30 days below half the threshold, treat it as a retention problem: fix the first session and do not buy more traffic. Expedited review (L4) is not in the budget. | See the rule below |

### 1.5 The go/no-go rule

The canon rule: once the game has 100 or more daily users, continue to public launch only if day-1 retention and session time are at or above the median for similar games.

How it is applied:

1. Read the benchmark scorecards only in stage 3b, because 3a measures players aged 16 and over, who are not the core audience.
2. The read is taken at the first weekly review after the game has had 100 or more daily users for 14 days, as document 10 sets out. Use the 7-day average of each measure (tune).
3. **Go:** both measures are at or above the 50th percentile.
4. **Not yet:** one or both are below. Run one more four-week cycle on the weakest numbers, in the priority order in document 10, then read again. At most two extra cycles (tune).
5. **No-go:** after two extra cycles, or at the 20-week limit, either measure is still below the median. Follow the "stop" action in section 9.
6. Paid traffic may be used to hold 100 daily users. Day-1 retention is then read for organic players and ad players separately, and the organic figure decides.

## 2. Launch checklist

### 2.1 Account and ownership (A5 and A6 in Sprint 0; the rest before `S−4`)

| # | Item | Value | Status |
|---|---|---|---|
| A1 | Developer account age-checked with ID | Required for Kids and Select (L2), social links (L24), rewarded video (L20) and Audience Expansion rewards | V |
| A2 | 2-step verification on | Required (L2, L20) | V |
| A3 | Verified email | Required for Ads Manager | V |
| A4 | Publishing requirement | **Decided by the owner on 14 Oct 2026 (decision D12 (a), on the agent's recommendation): the one-time refundable fee**, paid in Sprint 22 (task S22-M1); it needs no lead time. The alternative was to hold Roblox Plus. Plus must have been active for 2 consecutive months, so if that route is chosen, subscribe by `S−9` weeks. | V (L2); confirm the price in Audience, Reach |
| A5 | Roblox community "GULP" created | **Deferred.** The owner decided on 14 Oct 2026 not to create the community until the game has real users (decision D11 changed to (b) for now, see A6). When it is created it is opened and promoted to players at `S−4` at the earliest (document 11, section 9.4). 100 Robux (document 11, F23). | S |
| A6 | Owner of the game | **The owner's personal account owns the game for now.** Decided by the owner on 14 Oct 2026 (decision D11 changed from (a) to (b) until the game has real users). GULP Dev (universe 10770882807), GULP CI (10770882319) and GULP Staging (10770883054) were created that day under the personal account, all private; their IDs live in `Config/Defaults.luau` (document 09, section 17.1). Moving the game to a community later depends on whether Roblox allows transferring an experience, which is unverified (R46): check it before the community is created. | U |
| A7 | Developer Exchange eligibility checked | Needed to cash out and for Audience Expansion rewards | R |
| A8 | Open Cloud keys | One key for data store snapshots and one for the place publish script, each with the smallest scope that works. Stored outside the repository. | Our rule |

### 2.2 Game page and dashboard settings

| # | Setting | Where | Value at `S` | Change at `P` |
|---|---|---|---|---|
| G1 | Name | Game details | `GULP 🐟 Eat. Grow. Get Home.` | Add `[NEW 🦈]` for 7 days |
| G2 | Description | Game details | Document 11, section 6.1: the soft-launch text with the slice numbers (2 creatures, 5 traits). The numbers change with each update that adds content. | Launch version |
| G3 | Genre and subgenre | Game details | Document 11, section 6.3 | No change |
| G4 | Icon | Configurations, Places, start place, Icon | **Soft-launch set:** icon A in its soft-launch version (the Barracuda; document 11, section 3.2). No text on the icon. Icon D is tested against it from Sprint 31. | **Public-launch set** [L]: icon A in its public-launch version (Old Scar), or icon D if it won the soft-launch test. Icons B, C and E are tested from `P+4` (document 11, section 7.3). |
| G5 | Thumbnails | Same, Thumbnails | **Soft-launch set:** T1, T2, T3 and T5 uploaded, with T3 and T5 in their soft-launch versions (document 11, section 4.2). T1, T2 and T3 active for Home personalisation. T4 and T6 are added in Sprint 31. Nothing shows Old Scar, the Moray, Tuna, the Drop-off or Whale Fall. | **Public-launch set** [L]: add T7 and T8, and replace T3, T4 and T5 with their public-launch versions |
| G6 | Video | Same, Videos | None at `S`. The soft-launch page cut is uploaded in Sprint 31 (document 11, section 5). | The public-launch page cut [L] |
| G7 | Maturity & Compliance Questionnaire | Configurations, Content Rating | Complete. See section 2.4. | Resubmit if [L] content changes any answer (L7) |
| G8 | Playable devices | Game settings | Phone, tablet, computer. Console and VR off. | No change at `P`: the gamepad scheme ships at [L] on computer, phone and tablet, and the Console switch stays off. Console (Xbox and PlayStation) goes on early in [P1], target weeks 2 to 4, on the day both pass their real-hardware checklists (gate: document 15, sections 3.5 and 3.6). VR stays off. |
| G9 | Maximum players per server | Place settings | 24 (canon) | No change |
| G10 | Access | Audience, Access Settings | Public at `S`. "Friends" off. | No change |
| G11 | Exclude from recommendations | Audience, Advanced Settings | **Off** (we need the play-through data). Switch on only as part of the rollback plan in section 2.7. | Off |
| G12 | Audience Reach | Audience, Reach | Fee paid or Plus active. Check progress daily in 3a. | Evaluation passed |
| G13 | Private servers | Audience, Access Settings | Off | On, 99 Robux a month [L]. Set the price once; a change cancels every subscription (L19). |
| G14 | Paid access | Audience | Off, always. It cannot be combined with private servers (L19). | Off |
| G15 | Social links | Engagement, Social Links | The GULP community only | Add YouTube. Add Discord at [P1]. |
| G16 | Notification strings | Engagement, Notifications | One string: N6 in section 2.5 | Two strings: N6 and N7 [L]. Tides never use notifications (section 3.4). |
| G17 | Events and updates | Engagement, Events & Updates | None | "Launch Week" event, created at `P−7` days and submitted for featuring (L15) |
| G18 | Share links | Creations, Share Links | One each for TikTok, YouTube, Instagram, the community and creators (document 11) | One per creator |
| G19 | Localisation | Localisation settings | Source language English. Automatic Text Capture off: the game translates by key only (document 09, section 18.1). "Use Translated Content" on. All 17 other languages enabled for game information and for strings (L27). | Read Spanish, Portuguese and one more top language by hand (tune); lock corrected entries |
| G20 | Configs | Configs | The switches in section 2.6, all at safe values | Launch values |
| G21 | Erasure automation | Right to erasure templates | Templates for every data store that holds per-player keys (L25) | Add any new stores |
| G22 | Security switches | Game settings, Security | Third-party sales off. Third-party teleports off. HTTP requests off unless document 09 needs them. Studio access to API services off on GULP and on only on GULP Dev. | No change. Switch names unverified (L32). |
| G23 | Collaborators and roles | Community roles | Only the developer can edit, publish, manage events, announce, create share links and spend group funds | Add a helper role with forum moderation only, if needed |
| G24 | Avatar settings | Game settings | Not used. The avatar is never loaded (canon). | No change |
| G25 | Text chat | Place settings (document 09) | **Off.** Roblox text chat is switched off in the MVP (canon section 14). | Reviewed for launch: decide before the launch build is frozen whether it stays off. If it is switched on, it is a panel on Roblox's own `TextChatService`, never shown on a TV (document 15), and the questionnaire answers (G7) are re-checked first. |

### 2.3 Passes, products and badges

Document 05 owns the prices and the purchase IDs (`pass_*`, `prod_*`, `ad_*`). The prices below are its current values (tune); if they ever differ, document 05 wins and this table is corrected.

| Type | Item | Price (Robux) | Created by | Icon |
|---|---|---|---|---|
| Pass | Deep Pockets | 299 | `S` | 512×512, circle-safe (L18) |
| Pass | Bigger Cove | 349 | `S` | Same |
| Product | Revive | 25 | `S` | Same |
| Product | Pearl packs (four) | 49 / 149 / 399 / 999 | `S` | Same |
| Pass | Tide Watcher | 249 | `P` | Same |
| Pass | Keen Nose | 199 | `P` | Same |
| Pass | Shark Pup | 499 | `P` | Same |
| Product | Trait Lock | 19 | `P` | Same |
| Product | Call the Tide | 99 | `P` | Same |
| Product | Cove Boost | 29 | `P` | Same |
| Product | Goal Reroll | 19 | `P` | Same |
| Product | Patterns | 79 to 199 | `P` | Same |
| Product | Starter Pack | 99 | `P` | Same |
| Private server | Monthly | 99 | `P` | None |
| Rewarded video [L] | A free Revive, Cove Boost or Goal Reroll. Each is one of the products above, also sold for Robux (L20). No other video reward. | Free | When the game is eligible (2,000 unique visitors a month, L20) and only for players Roblox reports as eligible. Not on day one. | None |

Checks for every purchasable item: the name and description say exactly what it does; the purchase is granted through one receipt handler that is safe to run twice; a test purchase has been made in GULP Staging; nothing is offered in a new player's first two minutes (canon).

Badges. Document 03, section 12 owns the badge names, descriptions and unlock conditions: 29 badges, 20 tagged [MVP] and 9 tagged [L]. This chapter only schedules their creation. Five are free per 24 hours (L17), so create them five a day and pay nothing. A badge is created only when the live build can award it, so the 20 [MVP] badges follow the soft-launch slice (chapter 13, section 3): five exist at `S`, and the other fifteen are created as their content ships.

| Batch | Badges (numbers and names from document 03, section 12) | Create on | Tag |
|---|---|---|---|
| 1 | 1 to 5: Welcome to GULP, First Gulp, Home Safe, Gulped!, Growing Up | `S−4` days. These are the five badges at `S`. | [MVP] |
| 2 | 6, 7, 10, 11 and 15: Big Fish, Titan, You Are What You Eat, Triple Treat, Full House | In soft launch, on the day of the first update whose code awards them. The slice content already supports all five. | [MVP] |
| 3 | 12, 17 and 19 to 21: Moon Child; Not Today, Gull; Flying Fish; Frenzy Feeder; Big Bite | In soft launch, after Moon Tide and the Gull have shipped (Thu 13 May 2027 in chapter 13's base case) | [MVP] |
| 4 | 8, 9, 13, 16 and 18: Leviathan, Giant at Home, Gem of the Sea, Close Shave, Hooked | After a "go", when the full [MVP] is live (Thu 12 Aug 2027 in the base case). They need the Drop-off, Old Scar, the hook and Crystal. | [MVP] |
| 5 | 14 and 22 to 25: Bone Deep, Whole Family, Safe in the Shell, Tide Tourist, Good Neighbour | `P−2` days | [L] |
| 6 | 26 to 29: Popular Cove, Seven Days of Sea, Know-It-All, Reef Legend | `P−1` day | [L] |

If document 03 changes its list, the batches follow it; no badge is named here that is not in that list.

### 2.4 The maturity questionnaire

| Question area | GULP's answer | Reason |
|---|---|---|
| Violence | Mild, repeated | Creatures eat each other constantly. They are swallowed whole and pop into bubbles. |
| Blood | None | Canon |
| Fear | None, or mild if the reviewer counts a predator chase (the Barracuda at `S`; Old Scar once it is in the build) | Answer for the most extreme content (L7) |
| Crude humour | None | |
| Gambling content | None | |
| Paid random items | No | Canon: none at launch |
| Paid item trading | No | Trading is post-launch. Resubmit before it ships. |
| Social hangout | No | The game needs no chat, and text chat is switched off in the MVP (G25). The title and description never use hangout wording. |
| Free-form user creation | No | Cove decoration places ready-made 3D assets, which does not count (L7) |
| Strong language, romance, alcohol, sensitive issues | None | |

**Expected label: Mild** (repeated mild violence, L7). Minimal is possible only if the reviewer treats eating as occasional. Both labels reach Kids and Select (L1), so the canon target of "the lowest label that fits" is met either way. Answer truthfully and do not aim for a label. Redo the questionnaire before any update that adds trading, paid random items, a new kind of predator behaviour or any text input, and re-check it if the launch review switches text chat on.

### 2.5 Analytics, notifications and localisation checks

Document 10 owns the event names and the funnel definitions. This table is only the pre-launch check that they arrive.

| # | Check | Pass |
|---|---|---|
| N1 | Funnel events for the first session arrive in the dashboard: loaded, first bite, tier 2, 60 seconds, 180 seconds, first bank, second run started | Each step shows a count after a test session |
| N2 | Economy events for Pearls earned and spent, by source and sink | Totals match a hand count from one test session |
| N3 | Custom events: gulped (by what, at which tier, in which zone), trait gained, tide event joined, purchase prompt shown, purchase completed, purchase failed | Visible in the dashboard |
| N4 | Launch data from ads and share links is read on join and stored with the session | A test link shows up in the events |
| N5 | No call leaves the game to any third-party measurement or advertising service (L23) | Code search finds none |
| N6 | Notification string 1: "Your cove is full of Pearls. Swim in and collect them." Sent when the offline cap is reached. | 53 characters, under the 99 limit (L14) |
| N7 | Notification string 2: "{displayName} left a Bubble on your cove. Come and see." [L] | Parameter filled; sent at most once a day |
| N8 | The opt-in prompt is shown only after the first bank, never in the first session's first two minutes, and never to block play (L14) | Checked on a test account |
| N9 | Every interface string appears in the localisation table and has a translation in the enabled languages | No English text on a device set to Spanish |
| N10 | No text is baked into an in-game image | Interface review |

### 2.6 Config switches

Read through `ConfigService` (L12). Document 09 owns the implementation and the final key names; the names below are proposals.

| Key | Type | Safe value | Used for |
|---|---|---|---|
| `purchases_enabled` | boolean | true | Hides every purchase button and stops prompts |
| `revive_offer_enabled` | boolean | true | Hides the revive offer |
| `rewarded_video_enabled` | boolean | false | Shows rewarded video buttons where the player is eligible |
| `tide_events_enabled` | boolean | true | Stops the tide clock from starting events |
| `limited_tide_id` | string | "" | The limited-time tide that replaces the :30 slot (section 3.4) |
| `limited_tide_start` / `limited_tide_end` | string (UTC time) | "" | Its window |
| `cove_visits_enabled` | boolean | true | Turns off visits and Bubbles |
| `leaderboards_enabled` | boolean | true | Hides the global leaderboards |
| `new_player_shop_delay_s` | number | 120 | The canon rule that nothing is sold in the first two minutes |
| `saves_read_only` | boolean | false | Stops all writes to player saves (section 8.4) |
| `notice_text_key` | string | "" | A localised message shown on the cove notice board |
| `min_place_version` | number | 0 | Servers older than this show a restart notice and stop new runs |

### 2.7 Day-of-launch runbook

Launch time `T` is **Thursday 15:00 UTC** (tune). A Thursday leaves a working day to fix problems before the weekend. The same runbook is used for `S` and `P`. In chapter 13's base case `S` is Thursday 1 April 2027 and `P` is Thursday 20 January 2028.

| When | Step |
|---|---|
| T−7 days | `S`: upload the soft-launch store set for moderation (rows G4 and G5: icon A in its soft-launch version, and T1, T2, T3 and T5). No video. `P`: create the public Launch Week event, 7 days long, and submit it for featuring (L15). Upload the public-launch set for moderation (rows G4 to G6: the new icon, the new thumbnails and the public-launch page cut). |
| T−48 h | Submit the ad campaign so that review is finished (document 11). Freeze the build; the release candidate has been in GULP Staging since the Sunday before (chapter 13). Only fixes for severity 1 and 2 bugs after this point. |
| T−24 h | Publish the frozen build to GULP Staging. Play one full session on a phone and one on a computer. Make one test purchase of each new item. Confirm the questionnaire is current. |
| T−3 h | Take a data store snapshot through Open Cloud (L13). Tag the commit in the repository. Check every config value against section 2.6. |
| T−1 h | Publish the build to GULP. Join a fresh server and check the version number on the settings screen. |
| T | `S`: set access to public, with the soft-launch set on the page. `P`: restart outdated servers with a 5-minute delay (L10); change the name, description, icon, thumbnails and video to the public-launch set; send the update announcement (60 characters) and the community announcement with notification. |
| T to T+2 h | Stay in the game and on the dashboard. Every 15 minutes read the error count, the purchase failures, the server count, and the funnel steps "first bite" and "60 seconds". |
| T+2 h | First go-ahead check: fewer than 1 in 200 sessions with a script error that reaches the player (tune), no save failures, purchases completing. If it fails, go to the rollback plan. |
| T+6 h | Post the first short video. Reply to the first community posts. |
| T+24 h | Read day-zero numbers: sessions, the section 17 funnel, first-play bounce, purchase success rate. Write the bug list. Publish a hotfix only for severity 1 or 2. |
| T+3 days | First weekend check on Saturday and Sunday, 15 minutes twice a day. No publishing unless severity 1. |
| T+7 days | Read day-1 and day-7 retention for the launch-day cohort. `P` only: remove the title tag. |

### 2.8 Rollback plan

| Trigger | Action, in this order | Time to take effect |
|---|---|---|
| A single feature is broken (a product, an event, cove visits) | Turn it off with its config switch (section 2.6). Fix in the next update. | About 1 minute (L12) |
| The new build is broken but saves are safe | Check out the previous tagged commit. Publish it to GULP. Restart outdated servers with a 1-minute delay (L10). If the repository cannot produce the build, use Version History, Restore, then open in Studio and publish (L11). | 10 to 20 minutes |
| Saves are being damaged | Set `saves_read_only` to true at once. Then follow section 8.4. | About 1 minute |
| The game cannot be made safe quickly | Revoke public access so that no one can join (L10). Post the notice in the community. | Minutes |
| The first minute is broken and bounce is very high | Fix it or roll back. While it is broken, "Exclude from recommendations" may be switched on so that Home traffic does not meet the broken build (tune; its effect on later ranking is unverified). | Unknown |

Rules that make rollback possible: every save format change can be read by the previous build (document 09); a snapshot is taken before every update that touches saved data (L13); each published build has a commit tag; and no update is published after 18:00 UTC on a Friday.

## 3. Live operations after launch

### 3.1 The weekly rhythm

One update a week, published on **Thursday at 15:00 UTC** (tune).

| Day | Work | Time |
|---|---|---|
| Monday | Read the weekend's numbers. Triage bugs. Choose this week's fixes and balance changes. Write the update note first. | Half a day |
| Tuesday | Build | Full day |
| Wednesday | Build. Content freeze at 18:00 UTC. Publish to GULP Staging and play it on a phone. | Full day |
| Thursday | Snapshot if saved data changes. Publish at 15:00. Restart outdated servers with a 5-minute delay. Announce. Watch for 2 hours. | Half a day |
| Friday | Hotfix window until 15:00. A limited-time tide starts at 15:00 if one is scheduled. Record short videos. | Half a day |
| Saturday and Sunday | Two 15-minute checks a day. No publishing unless severity 1. | 1 hour in total |

The rest of the week is for the next headline feature. If a headline is not ready by the Wednesday freeze, it moves to the next week and the update ships with fixes and a small item. A headline is never published late in the week to catch up.

### 3.2 What goes into a normal weekly update

| Part | Rule |
|---|---|
| One headline | **A weeks:** a species, a zone or a feature. **B weeks:** a limited-time tide, a pattern set or cove decorations. A and B alternate. |
| One to three balance changes | Each one names the number that caused it (for example "62% of deaths in the Kelp Forest were to Morays") |
| Fixes | Every severity 2 bug older than a week |
| One "you asked" item | A small change that came from the community, credited in the note |
| Page text | The "LATEST UPDATE" line in the description, in the same hour as the publish |
| Announcements | The update announcement (60 characters) and the community post, as in section 3.4 |
| Size limit | At most 3 days of build work. Anything larger is split or hidden behind a config switch until it is finished. |
| Not included | A purchase that is not in the canon or in document 05; any paid random item; a save format change without a snapshot |

### 3.3 Content calendar for the first 12 weeks

Weeks are counted from `P`. Weeks 1 to 12 are the canon's [P1] (the first quarter after launch), so everything in this calendar after launch week is tagged [P1]. Species, events and features are from the canon post-launch lists, in the canon order (Anglerfish, Manta Ray, Seahorse, Axolotl, Orca Calf, Narwhal); what each event does is defined in document 03, section 7.4. Neither the canon nor document 03 names a post-launch trait, so this calendar adds none (section 13). This is the pace for the "double down" case in section 9. In the "keep steady" case, each A week becomes two weeks. The estimate of 5 working days per species is a guess (tune).

| Week | Type | Headline | Also in the update | Limited-time tide that weekend | Tag |
|---|---|---|---|---|---|
| 1 | Fix | Hotfixes only. Launch Week event runs all week. | Balance from launch data | None | [L] |
| 2 | A | **Anglerfish** (Lure) | Two Anglerfish patterns | None | [P1] |
| 3 | B | **Storm** tide, first run. Lightning leaves Spark Eels in shallow water, so Spark can be gained in the Reef (document 03). | Pattern set "Tempest" (working name) | Storm | [P1] |
| 4 | A | **Manta Ray** (Glide) | New Reef Rank titles. **Xbox and PlayStation** are switched on in weeks 2 to 4, on the day both pass their real-hardware checks (document 15, sections 3.5 and 3.6). | None | [P1] |
| 5 | B | Cove decoration set "Wreck" (working name) | Changes from the first month's data; daily goal variety | Storm returns | [P1] |
| 6 | B | **Red Tide**, first run. Prey inside the cloud gives double mass, with extra predators (document 03). | Pattern set "Crimson" (working name) | Red Tide | [P1] |
| 7 | A | **Seahorse** | Codex page for limited-time tides | None | [P1] |
| 8 | A | **Pearlescent variants**, first version | Pearlescent column in the Codex | None | [P1] |
| 9 | B | Quality-of-life update chosen by a community poll | Pattern set chosen by the same poll | Storm | [P1] |
| 10 | A | **Axolotl** (Regrow) | Two Axolotl patterns | None | [P1] |
| 11 | B | Cove decoration set "Deep" (working name) | Changes from the second month's data | Red Tide returns | [P1] |
| 12 | B | **Great Migration**, first run. One river of prey crosses the map (document 03). A 7-day event submitted for featuring. | Great Migration cove decoration (document 03) | Great Migration (7 days) | [P1] |

**Working names.** The content sets named in this calendar that chapter 03 does not define (the pattern sets "Tempest" and "Crimson", the cove decoration sets "Wreck" and "Deep", the per-species pattern pairs, the new Reef Rank titles and the poll-chosen pattern set) are working names only. Chapter 03 owns content names and lists: each set is added to chapter 03, with its items and IDs, when that content is designed, and the name here changes to match.

Orca Calf, Narwhal, trading, Migration (the prestige reset), the Trench and The Trench Opens are after week 12, so they are [P2] (section 10).

Why the Trench is not in this calendar: the canon tags the Trench zone and The Trench Opens [P2]. A new zone with its own landmarks, spawns and event is the largest single item on the list, and one person cannot build and test it in the same quarter as four species and three new tides while also handling launch fixes. It opens in Q2 (section 10), and building it can start earlier in the "double down" case.

### 3.4 How limited-time tides are scheduled and announced

The canon rotation is fixed so that players can learn it: :00 Feeding Frenzy, :15 Moon Tide, :30 Feeding Frenzy, :45 Whale Fall. In the MVP, before Whale Fall ships at launch, the :45 slot runs a second Moon Tide. At `S` the slice runs a Feeding Frenzy on all four slots until Moon Tide ships during soft launch (chapter 13, section 3.4). After launch the :30 slot is the flexible one (canon section 10).

Scheduling rules:

1. A limited-time tide **replaces the :30 slot only**, which the canon names as the flexible slot after launch. The other three slots never change, so the learned rotation holds.
2. A weekend run lasts from **Friday 15:00 UTC to Monday 15:00 UTC**: 72 hours, so 72 occurrences.
3. One limited-time tide at a time. At most two weekends in any four (tune).
4. Every limited-time tide returns within 6 weeks of its first run and at least four times a year. A trait that comes only from a limited-time tide is never gone for good. This is a fairness rule for a young audience (section 7).
5. A seasonal event (section 4) uses the same slot for 7 to 14 days.
6. The window is set with the `limited_tide_*` config keys, so it starts and ends on every server without a publish.
7. Call the Tide (the canon product) always starts a Feeding Frenzy. It never interrupts a scheduled or limited-time tide: it is held as a token and starts, after a 10-second warning, when no tide is running (canon).
8. After an event has had its first run and one return, it can join a permanent hourly rotation of the :30 slot, as document 03 proposes (section 16, item 11). The Trench Opens [P2] must join it within a week of the Trench shipping, because the canon says the Trench opens only during a tide event.

Announcement plan for one limited-time tide. Each channel has a limit, so each is used once.

| When | Channel | Content | Limit |
|---|---|---|---|
| 7 days before | A Roblox event with "Notify Me". Submit for featuring only if the event runs 7 days or more. | Title, dates in UTC, event thumbnail | 10 events at once (L15) |
| Tuesday | The cove notice board in the game (`notice_text_key`) and a marker on the tide clock | "Storm tides from Friday" | Ours |
| Thursday, with the update | Update announcement to followers | "Storm tides this weekend. Spark Eels in the shallows." | 60 characters, once per 3 days (L15) |
| Thursday | Community announcement with notification, and a forum post | The update template (document 11, section 6.2) | Once per 7 days (L16) |
| Friday 15:00 | The event starts. Roblox notifies players who pressed "Notify Me". | Automatic | L15 |
| During | The 60-second in-game warning before each occurrence, as for every tide | Canon | None |
| Monday | Community post | What happened: how many players gained the trait, the largest creature banked | None |

Experience notifications (L14) are **not** used to announce tides. They must relate to the player's own activity, they reach only opted-in players of 13 and over, and each player can receive one a day. They are kept for "your cove is full". The Tide Watcher pass does not change this: it is an in-game tide board and marker, and nothing promises a push notification or an alarm for a tide.

## 4. Seasonal and special events for a year

Each event uses the limited-time slot for 7 to 14 days, adds one pattern set and one cove decoration set, and is submitted for featuring 7 days ahead. None has paid random items. All names are original and avoid other companies' event names. The event names below, and the pattern and decoration sets each event adds, are working names that chapter 03 does not define yet; they are added to chapter 03 when that content is designed.

| Month | Event | One line |
|---|---|---|
| January | **New Tide** | A calm week: double scraps for everyone and a fresh 7-day calendar |
| February | **Lantern Tide** | A Moon Tide variant with drifting lantern jellies that light a path to rare trait prey |
| March | **Spawning Season** | Krill and Sardine schools are twice as large in the Nursery and the Reef |
| April | **Egg Drift** | Harmless fish eggs drift on currents; carry them home in one run for a decoration |
| May | **Whale Song** | Whale Fall comes with a living whale passing overhead, and Marrow is doubled |
| June | **Clean Reef** (World Oceans Day, 8 June) | Fishing hooks are replaced by drifting litter; clearing it as a server unlocks a shared reward |
| July | **Fin Fest** | Shark Pup and Old Scar week: a free Shark Pup trial run each day, and Old Scar has a rival |
| August | **Great Migration** returns | The canon [P1] event, first run in week 12 (section 3.3), back for a longer stay: huge schools cross the map on a route that changes daily |
| September | **School's In** | Sardine schools form shapes; swim through a whole school without breaking it for a bonus |
| October | **Ghost Tide** | A dark tide with see-through ghost fish and a Bonefed spotlight. Kept within the maturity label. |
| November | **Feast** | Feeding Frenzy at :00 and :30 lasts 6 minutes instead of 4 |
| December | **Frost Tide** | Ice forms at the surface of the Reef, and the Narwhal arrives if it has not shipped earlier |
| Launch anniversary | **Homecoming** | Every player's first banked specimen is shown in the Nursery for a week |

## 5. Community management for one person

### 5.1 Where announcements go

| Channel | What goes there | How often | Limit |
|---|---|---|---|
| Update announcement (game followers) | The weekly headline | Weekly | 60 characters, once per 3 days (L15) |
| Roblox community announcement | The weekly update note, polls | Weekly | Notification once per 7 days (L16) |
| Roblox community forum | Full notes, the known-issues thread, the suggestions thread | As needed | None stated |
| Roblox events | Limited-time tides and seasonal events | Per event | 10 at once (L15) |
| Game description | The "LATEST UPDATE" line | Weekly | One line |
| Cove notice board in the game | The next tide event and restart notices | As needed | Localised keys only, no free text |
| Short-video accounts | Clips of the update | Document 11 | |
| Discord [P1] | A copy of the community post | Weekly | 13 and over |

The Roblox community post is the master copy. Everything else is cut from it.

### 5.2 How feedback is collected

| Source | What it gives | How it is captured |
|---|---|---|
| Analytics funnels and events | What players do | Dashboard, read on Monday |
| The suggestions thread in the community forum | What players ask for | One pinned thread per month |
| A community poll | A choice between two or three options | At most two a month |
| An in-game one-tap rating after the third bank: a happy, neutral or sad fish, then one of five reason chips. No typed text. [L] | Mood, and a reason, from players who never post | A custom analytics event |
| Player Support Tickets, if available (L16) | Bug reports with screenshots | The Creator Hub queue |
| Discord bug channel [P1] | Detailed reports from older players | A form with fixed fields |

Typed text is avoided in the game on purpose. It would need filtering, could collect personal data, and adds moderation work.

### 5.3 Bug triage

| Severity | Meaning | Examples | Response |
|---|---|---|---|
| 1 | Loss of saves, loss of purchases, the game cannot be played, or a safety problem | Specimens vanish; a paid pass is not granted; servers crash on join | Stop other work. Use the rollback plan. Fix the same day. Post a notice within 1 hour. |
| 2 | A core loop is broken for many players, or an exploit affects other players | Banking fails in one cove; a speed exploit lets a player eat everyone | Hotfix within 48 hours. Turn the feature off if a switch exists. |
| 3 | A feature is wrong but there is a way round it | A trait effect is weaker than stated; a pattern shows the wrong colour | The next weekly update |
| 4 | Cosmetic, or rare | A clipping fin; a typo | When convenient; batch monthly |

Every report is logged in one tracker (a plain file or a free issue tracker) with: date, severity, device, what happened, how often, and the fix version. One line per bug.

### 5.4 The daily routine (under 30 minutes)

| Minutes | Task |
|---|---|
| 5 | Dashboard: errors, daily users, server count, purchase failures, any alert. Compare with yesterday. |
| 10 | Roblox community: read new forum posts and announcement replies. Answer up to 10. Log bugs. Hide rule-breaking posts. |
| 5 | Support: the ticket queue if available, and the Roblox inbox, including the daily erasure message (L25) |
| 5 | Discord [P1]: the bug channel only |
| 5 | Tracker: set severities, pick one "you asked" item for the week, note one clip idea |

Rules: answer once a day at a fixed time, not all day. Never argue. Never promise a date for anything but next Thursday's update. Never discuss a ban in public. If the routine runs over 30 minutes for three days in a row, reduce the channels, starting with Discord.

Once a week, on Monday, spend 60 minutes on the weekly review: numbers, the bug list, the top five requests, and the update note.

## 6. Player support and moderation

### 6.1 Who handles what

| Problem | Roblox handles | We handle |
|---|---|---|
| A player reports another player's behaviour or name | The in-app report, review and account action | Nothing, unless it is a cheat in our game |
| Chat content | Filtering, the age rules and chat access (L22) | Text chat is off in the MVP and reviewed for launch (G25). If it is switched on, the panel uses Roblox's `TextChatService` (document 09). Any other text we ever show from a player goes through Roblox's text filter. |
| Payment, a charge or a refund request | Billing and refunds through Roblox Support (L31, unverified) | We say so, and we fix what the game got wrong (section 6.3) |
| Account theft or a hacked account | Roblox Support | We do not move items between accounts |
| Age checks and parental controls | Roblox | We respect what the policy checks return |
| Moderation of our icon, thumbnails, names and descriptions | Review and appeals | We fix and resubmit |
| A cheat in our game | Nothing | Detection and bans (section 6.2) |
| A bug, a lost save or a missing item | Nothing | Sections 5.3 and 8.4 |
| An erasure request | Notifies us daily (L25) | We delete the data |

### 6.2 Exploiters

Detection and the automatic response are defined in document 09: the server checks movement and every bite, keeps a suspicion score, and moves through five levels (accept, correct, rubber-band, flag, kick). A flagged run is marked untrusted and is kept off the leaderboards. There is no automatic ban.

This chapter adds the human part.

| Task | Rule |
|---|---|
| Daily | Read the count of `cheat_flag` events and kicks. Document 09's target is fewer than 0.5% of sessions reaching level 2. If it is higher, suspect a false positive first and widen the tolerance in live config before acting on players. |
| Ban | By hand only, with `Players:BanAsync`, after reading the logged reasons for that account. Never on another player's report alone. 7 days for a first ban, 30 days for a second, permanent for a third (tune). |
| Leaderboards | Cleaned every Monday. A value that looks impossible, such as a tier 7 creature in under 5 minutes, is held back from the global boards until checked. |
| Messages | The kick message stays neutral, as in document 09. A ban is never discussed in public. |
| Appeals | One appeal per ban, through the community support thread, answered in private within 7 days. |
| A new exploit affecting other players | Severity 2 (section 5.3). Switch off the affected feature if a switch exists, then fix. |

### 6.3 Refunds and purchase problems

We cannot send Robux back from the game. Refund requests go to Roblox Support (L31, unverified). What we can do is make sure the game delivered what was paid for.

| Problem | What we do | Reply |
|---|---|---|
| Paid, item not received | Check the purchase log for the receipt. Grant the item again. The receipt handler is safe to run twice. | "Thanks for telling us. Your Deep Pockets pass is now on your account. Rejoin to see it." |
| Bought by mistake | We cannot refund Robux. Point to Roblox Support. | "We cannot return Robux from inside the game. Roblox Support handles refund requests." |
| A parent says a child bought without permission | The same, plus point to Roblox's parental spending controls | The same, with no questions about the child |
| A revive was used and the run was still lost to a bug | Grant one free revive token and log the bug | "That one was our fault. A free revive is waiting for you." |
| A widespread purchase bug | Set `purchases_enabled` to false. Fix. Grant what was missed to everyone affected, from the log. Post a notice. | A public notice |

A purchase log is kept per player: receipt ID, product, time and whether it was granted. It holds nothing that is not needed to answer these cases.

## 7. Compliance checklist

"Verified" means the rule was read on the linked page this session or in the project research. "To be verified" means it must be read in full before the stage shown.

| # | Area | What GULP does | Source | Status |
|---|---|---|---|---|
| C1 | Maturity questionnaire | Completed before `S` with the answers in section 2.4. Redone before any update that changes an answer. | [Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity) | Verified |
| C2 | Kids and Select publishing requirements | Age check, 2-step verification, fee or subscription, evaluation (L2, L3) | [Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select) | Verified. The threshold number differs between sources; read the dashboard. |
| C3 | Paid random items | None at launch (canon). If ever added: all outcomes and odds as percentages totalling 100%, the same for Pearl-bought random items, a per-player `ArePaidRandomItemsRestricted` check with another route, and a new questionnaire. | [Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items) | Verified |
| C4 | Nothing important from chance | The Crystal Jelly's appearance is random but free. No purchase has a random result. Pearl packs, patterns and the Starter Pack have fixed contents. | Same, and canon pillar 2 | Verified |
| C5 | Rewarded video eligibility | Switched on only when the game averages 2,000 unique visitors a month and the account requirements are met. Shown only when `GetAdAvailabilityNowAsync` says the player is eligible. Never required to progress. | [Rewarded video ads](https://create.roblox.com/docs/production/promotion/rewarded-video-ads) | Verified |
| C6 | Rewarded video rewards | Each reward must be a developer product that is normally sold for Robux and is not random. The canon's three rewards qualify: Revive, Cove Boost and Goal Reroll are each a visible product also sold for Robux (document 05). No other reward and no hidden product is offered. Roblox suggests rewards worth about 3 to 10 Robux (L20) and Revive is 25, so read that guidance again before switching the feature on. | Same | Verified |
| C7 | Advertising to children | No ads of our own inside the game. No brand integrations. Ads are not personalised for under-18s (L23). The rule that advertising must not be shown to under-13s is from secondary sources. | [Community Standards](https://about.roblox.com/community-standards), [BBB decision](https://bbbprograms.org/media/newsroom/decisions/roblox-advertising) | Part verified. Read the Advertising Standards before switching on rewarded video. |
| C8 | Paid creators and disclosure | No paid creators in the first six months. Early access is disclosed in the video (document 11, section 9.3). | [Community Standards](https://about.roblox.com/community-standards), [FTC guidance](https://www.ftc.gov/business-guidance/resources/ftcs-endorsement-guides-what-people-are-asking) | Verified |
| C9 | Chat and age checks | The game needs no chat. Roblox text chat is switched off in the MVP and reviewed for launch (canon section 14; G25). If the review switches it on, it is a panel built on Roblox's own `TextChatService` (document 09), never shown on a TV (document 15), which keeps Roblox's filtering and age rules in force. We never build a separate chat system, and nothing in the game depends on chat. | [Staff post](https://devforum.roblox.com/t/age-check-requirement-to-chat-now-live-globally/4226101), [TechCrunch](https://techcrunch.com/2026/01/07/roblox-now-requires-all-users-globally-to-complete-age-checks-to-access-chat) | Verified in research |
| C10 | Player-entered text | None at launch. Cove names use the Roblox display name. If text input is ever added, it goes through Roblox's text filter and the questionnaire is redone. | [Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity) | Verified (free-form creation rule) |
| C11 | Personal data | Saves are keyed by Roblox user ID and hold only game state. No email, age, real name, location or device ID is collected. No call to a third-party measurement service. No profile of a player's behaviour for targeting. | [Community Standards](https://about.roblox.com/community-standards) | Verified |
| C12 | Erasure requests | Deletion templates cover every per-player data store. The daily inbox message is read in the daily routine. Global leaderboard entries and the purchase log for that user are deleted too. | [Right to erasure](https://create.roblox.com/docs/production/publishing/about-GDPR-and-CCPA) | Verified. No deadline is stated; we act within 7 days (tune). |
| C13 | Off-platform links | Only the Social Links on the game page. No link, handle, code or QR code in the game or the description. | [Social links](https://create.roblox.com/docs/production/promotion/social-media-links), [Community Standards](https://about.roblox.com/community-standards) | Verified |
| C14 | Notifications | Only messages about the player's own cove. Opt-in only. Never needed to progress. No false time pressure. | [Experience notifications](https://create.roblox.com/docs/production/promotion/experience-notifications) | Verified |
| C15 | Tide Watcher pass | The pass is the 24-hour pile cap plus an in-game tide board (the next three tides and a marker to the event). It sends no push notification and its store text promises no alarm: Roblox notifications reach only opted-in players of 13 and over, once a day, so nothing paid depends on them. Every player sees the clock and the next tide for free. | Same | Verified |
| C16 | Honest store page | The name, icon, thumbnails, video and description show only what is in the live build at that stage: the soft-launch set from `S` (slice content only) and the public-launch set from `P` (rows G2 and G4 to G6) | [Community Standards](https://about.roblox.com/community-standards), [Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails) | Verified |
| C17 | Contests and giveaways | None with real-money value. No Robux prizes. | [Community Standards](https://about.roblox.com/community-standards) | Verified |
| C18 | Original creatures | Every species, predator and name is original. No licensed or meme characters (canon). Old Scar is a named great white of our own design. Search each new name before use. | Canon section 3 | Our rule |
| C19 | Music | Either Creator Store music (free to use on Roblox, L26) or music commissioned or licensed with a written licence that covers the Roblox game, the store-page video and social video worldwide. Whether Creator Store audio may be used in videos posted outside Roblox is unverified, so off-platform videos use only music we hold a licence for. | [Audio assets](https://create.roblox.com/docs/en-us/audio/assets) | Part verified. Read the Audio Terms of Use before `S`. |
| C20 | Sound effects | Made by us, or from a library whose licence allows use in a commercial game and its videos. No default Roblox sounds (canon). | Licence file per source | To be verified per source |
| C21 | Fonts | A licence that covers a game, images and video. Licence files are kept in `docs/licences/`. | The licence file | To be verified at download |
| C22 | Trading (post-launch) | Before it ships: redo the questionnaire, check `IsPaidItemTradingAllowed` per player, and decide whether patterns bought with Robux can be traded at all (default: no). | [Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity) | Verified that the check exists; the design is not yet written |
| C23 | Private servers | Price set once. Under-13s may be unable to join depending on their settings; the game never requires a private server. | [Private servers](https://create.roblox.com/docs/production/monetization/private-servers) | Verified |
| C24 | Consumer fairness for a young audience | The rules in section 7.1 | Roblox rules above; national consumer law | Roblox parts verified. Law outside Roblox is to be verified with advice before any spend above the high-case budget. |

### 7.1 Fairness rules for a young audience

These are GULP's own rules. They go further than the Roblox rules we could verify.

1. Nothing is sold in the first two minutes of a new player's first session (canon).
2. Every purchase is made through Roblox's own prompt, which shows the Robux price. We add no confirmation tricks and no pre-selected options.
3. Every offer has a clear "No thanks" button of the same size as the buy button. Declining never triggers a sad animation, a guilt message or a second prompt.
4. No countdown on any purchase unless the limit is real and stated in UTC. The Starter Pack is offered once per account and says so.
5. The revive offer appears at most once per run and has no countdown timer. It is not shown on an account's first death, and only when the lost creature had 30 mass or more (canon). Declining has no penalty.
6. What a pass or product does is stated in one sentence with its numbers ("×2 Pearls from banking").
7. No purchase has a random result (C4).
8. A limited-time trait always returns (section 3.4, rule 4).
9. Spending never makes another player lose something they had banked. Call the Tide helps the whole server.
10. Pearl packs show the Pearl amount and the Robux price together, with no "best value" badge unless the price per Pearl is in fact the lowest.
11. The login streak rewards returning and takes nothing away: a missed day never resets the calendar, and the next box simply waits (canon).
12. No message tells a child to ask a parent to buy something.

## 8. Operations

### 8.1 Monitoring

| What | Where | Check | Act when (tune) |
|---|---|---|---|
| Script errors reaching players | Creator Hub error reports; alerts if available (L30) | Daily; every 15 minutes on launch day | More than 1 in 200 sessions, or a new error in the top three |
| Server health: memory, heartbeat, crashes | Creator Hub performance pages | Daily | Any server crash; server frame time above the document 09 budget |
| Client frame rate on phones | Our own custom event sampled once per session | Weekly | The median on low-end devices is below the document 09 target |
| Save failures | Custom event on every load and save failure | Daily | Any failure rate above 0.1% of saves |
| Purchases prompted, completed, failed | Custom events | Daily | Completion drops by a third against the 7-day average |
| The first-session funnel | Funnel events (section 2.5) | Daily in soft launch, weekly after | Any step falls 5 points below its 7-day average |
| Daily users, retention, session time, benchmarks | Creator Hub analytics | Daily look, weekly decision | Section 9 |
| Play-through rate and bounce | Analytics, Acquisition, Home Recommendations | Weekly | A fall of 20% week on week with no thumbnail or icon change |
| Reduced-exposure banner | Creator Dashboard | Daily | Present |
| Exploit flags | The `cheat_flag` event (document 09) | Daily | More than 0.5% of sessions reach level 2 of the ladder in document 09 |
| Roblox platform status | Roblox's status page | When something looks wrong | Wait; do not publish during a platform incident |

Monitoring uses Roblox's own analytics and data stores only. Sending data from the game to an outside service must be checked against L23 first.

### 8.2 Incident response

| Step | Action | Target time |
|---|---|---|
| 1. Notice | An alert, the daily check, or a player report | |
| 2. Classify | Severity 1 to 4 (section 5.3) | 5 minutes |
| 3. Contain | Severity 1 or 2: use a config switch, roll back, or revoke access (section 2.8). Contain first, diagnose second. | 15 minutes for severity 1 |
| 4. Tell players | One short notice in the community and on the cove notice board: what is wrong, what is safe, when the next message will come | 1 hour for severity 1 |
| 5. Diagnose | Reproduce in GULP Staging, or in Studio on GULP Dev. Find the commit. | |
| 6. Fix | The smallest change that works. Test in GULP Staging on a phone. | Same day for severity 1, 48 hours for severity 2 |
| 7. Release | Publish. Restart outdated servers. Restore the switches. | |
| 8. Make good | Grant what players lost, from logs (section 6.3 and 8.4) | Within 3 days |
| 9. Write up | Five lines in the tracker: what happened, how many were affected, the cause, the fix, and what will stop it happening again | Within a week |

### 8.3 Backups and data recovery

| Layer | What it gives | Limit |
|---|---|---|
| Session-locked profile store (canon section 14) | Stops two servers writing one save | Document 09 |
| Data store versioning (L13) | The first write per key in each UTC hour is kept for 30 days after being overwritten | At most one restore point per hour, and 30 days back |
| Daily snapshot through Open Cloud (L13) | A known restore point for all keys | Once a day. Taken before every update that touches saved data. |
| A save-format version number in each save | Old builds can read new saves; new builds migrate old ones | Document 09 |
| A purchase log per player | Purchases can be granted again after a restore | |
| The repository | Every published build can be rebuilt from its tag | |

A restore is tested before `S`: damage a test save in GULP Staging on purpose and bring back the version from the hour before, using `ListVersionsAsync`, `GetVersionAsync` and a write-back. The time it takes is written down.

### 8.4 If a save bug ships

| Step | Action |
|---|---|
| 1 | Set `saves_read_only` to true. Players can keep playing, and a notice says progress is paused. Publishing a fix can wait; stopping the damage cannot. |
| 2 | Post the notice: "We found a problem with saves. Nothing more can be lost now. We are restoring what was affected." |
| 3 | Find the window: the publish time of the bad build to the time of step 1. Find which keys were written in that window, from the save events. |
| 4 | Roll the build back to the previous tag (section 2.8). |
| 5 | For each affected player, on their next join: read the latest version from before the window (L13), compare it with the current save, and keep the better one by rule (more lifetime Pearls banked, more specimens). Restore passes and products from the purchase log. Log every restore. |
| 6 | Set `saves_read_only` to false once a test account has passed step 5 in the live game. |
| 7 | Make good: every affected player receives Pearls equal to 24 hours of their cove income (tune) and one free revive. Say so in the notice. |
| 8 | Write up. Add a test that would have caught it. If the snapshot from before the publish was missing, the rule in section 2.8 is now a publish blocker. |

A restore can go back at most 30 days and to the nearest hour (L13). Progress made in the damaged window may be lost for some players. Say this plainly in the notice.

## 9. Decision points after launch

Roblox publishes no fixed targets. The benchmark percentiles in the dashboard are the yardstick (L9). They appear only at 100 or more daily users.

Read the numbers at three points: the go/no-go in soft launch (section 1.5), `P` + 4 weeks, and `P` + 12 weeks. After that, read them on the first Monday of each quarter. Use 7-day averages. Monthly earnings are in Earned Robux; 263,000 a month is about 1,000 US dollars at the rate in L28.

| | Double down | Keep steady | Stop |
|---|---|---|---|
| Day-1 retention and session time against similar games | Both at or above the 75th percentile (tune) | Both between the 50th and 75th | Either below the 50th for 4 weeks in a row, after the two extra cycles in section 1.5 |
| Daily users | Rising in 3 of the last 4 weeks | Flat, within 15% | Below 100 for 4 weeks in a row, so the benchmarks are gone |
| Play-through rate from impressions | Steady or rising | Steady | Falling for 4 weeks with no cause found |
| "Still playing at 60 seconds" (canon target 80%) | 80% or more | 70% to 80% | Below 70% after two extra cycles |
| Earned Robux per month | 263,000 or more (tune) | 30,000 to 263,000 | Below 30,000 for 3 months in a row, which is under the cash-out minimum |
| **Action** | Run the 12-week calendar at full pace. Keep ads on at up to 300 US dollars a month while cost per play holds. Start building the Trench early (it still ships in [P2]). Consider paying for one outside artist. Submit every 7-day event for featuring. | A headline every two weeks instead of every week. No ads. Put the freed time into the weakest funnel step. Read again in 4 weeks. | Move to maintenance. |

A column applies when the first two rows are both true. If the rows disagree, choose "keep steady".

**Maintenance means:** one fix-only update a month; tide events keep running on the clock; seasonal events re-run from config with no new art; all purchases stay honoured and saves are kept; one honest community post explains the change; the Discord is closed or handed to volunteers; ads stop. The swim controller, camera and interface are reused for the next game, as the viability report suggests.

**Two further rules.** If the daily routine and the weekly update together take more than 45 hours a week for four weeks, drop to the "keep steady" pace whatever the numbers say. And paid random items stay out unless the game is in "double down" for two readings in a row and the compliance work in C3 has been costed.

## 10. Roadmap for the first year

Quarters are counted from `P`. The canon's [P1] is weeks 1 to 12, so the content of Q1 is [P1] (it all ships by week 12; week 13 adds nothing new) and everything from Q2 on is [P2]. Content is from the canon post-launch lists. The pace assumes "double down"; in "keep steady" each quarter's list takes about twice as long.

| Quarter | Species (canon order) | Events | Features | Other |
|---|---|---|---|---|
| **Q1** (weeks 1 to 13; weeks 1 to 12 are [P1]) | Anglerfish, Manta Ray, Seahorse, Axolotl | Storm, Red Tide, Great Migration | Pearlescent variants (first version) | Xbox and PlayStation switched on in weeks 2 to 4, on the day both pass their real-hardware checks (gate: document 15, sections 3.5 and 3.6). Hand-check of the top three translations. Rewarded video when the game and the player are eligible. A one-week check of browser play when Roblox releases it (document 15). |
| **Q2** (weeks 14 to 26) [P2] | Orca Calf | **The Trench Opens**; Storm, Red Tide and Great Migration return; seasonal events from section 4 | **The Trench** zone opens, with its predators, trait prey and a deepest-bank leaderboard. **Trading specimens**, with the compliance work in C22. | Second round of Pearlescent variants. The first reading of whether paid random items are worth their compliance cost; the default is no. |
| **Q3** (weeks 27 to 39) | Narwhal | Seasonal events | **Migration**: the prestige reset for a permanent bonus and a new cove biome | Follow Roblox's announced standalone game apps (reported in September 2026; terms not researched) and decide whether GULP should apply. |
| **Q4** (weeks 40 to 52) | The next species, chosen by a community poll (not in the canon; needs a canon entry first) | The Homecoming anniversary event; seasonal events | A second cove biome through Migration. Quality and performance work based on a year of data. | The year-two decision using section 9: continue, hold, or reuse the technology for the next game. |

Dependencies: trading comes after Pearlescent variants, so that there is something rare to trade. Migration comes after trading, so that a reset does not destroy trade value without warning. The Trench ships before Orca Calf, so that large species have somewhere to go.

## 11. Costs for the first six months

From the start of the private test to about `P` + 3 months. All amounts are US dollars. Robux costs use 1,000 Robux for about 12.50 US dollars at retail, which is unverified; check the purchase page. Every "high" figure that is not a Roblox price is a guess (tune).

| Item | Low case | High case | Notes |
|---|---|---|---|
| Publishing requirement for Kids and Select | 12.50 | 29.94 | Low: the one-time 1,000 Robux fee, refunded after 90 days (L2). High: Roblox Plus for six months at 4.99 (L6). |
| Roblox community | 1.25 | 1.25 | 100 Robux (S) |
| Badges | 0 | 12.50 | 5 a day are free (L17). High: 10 extra at 100 Robux each. |
| Uploads: images, meshes, audio, video | 0 | 0 | Images and video thumbnails are free. Audio is free within the monthly allowance (L26). Mesh upload fees were not researched. |
| Ad tests | 30 | 470 | Low: step 1 only. High: all three steps (document 11, section 10). |
| Extra Engagement ads to reach the evaluation threshold | 0 | 300 | Only if organic traffic is too slow (tune) |
| Music | 0 | 600 | Low: Creator Store music, or tracks made by the developer. High: a commissioned theme and three loops with a written licence. |
| Sound effects | 0 | 150 | Low: made by the developer. High: one licensed library. |
| Fonts | 0 | 100 | Low: an open licence. High: one commercial licence. |
| Image and video tools | 0 | 70 | Low: Blender and free editors. High: one paid image editor. |
| Low-end test phone | 0 | 120 | High: a used low-end Android phone, because the game is phone first |
| Domain and a one-page site | 0 | 15 | Optional |
| Paid creators | 0 | 0 | None in the first six months (document 11) |
| **Subtotal** | **43.75** | **1,868.69** | |
| Contingency, 15% | 6.56 | 280.30 | |
| **Total** | **about 50** | **about 2,150** | |

Not in the budget: expedited review (50,000 Robux or more, L4); a trademark filing; the developer's time; subscriptions the developer already pays for; anything Roblox charges that was not found in research.

To cover the high case at the rate in L28, the game must earn about 566,000 Earned Robux. To cover the low case it needs about 13,200, which is below the 30,000 minimum for a cash-out.

Spending rule: the low case is committed. Each high-case item is bought only when its stage is reached and the stop rules in document 11, section 10.3 allow it. Music and sound are paid for only after the go/no-go is passed.

**Budget decided by the owner on 14 Oct 2026** (decision D2 (a), on the agent's recommendation): the low case is committed now, plus a used low-end test phone of up to 120 US dollars (task S0-M3), about 170 US dollars in all. Paid tests are decided step by step by document 11, section 10.3. Money for music and sound is decided only after a "go" at the go/no-go. A contract artist is not budgeted.

## 12. What was verified and what was not

**Verified on official pages this session:** the Kids and Select tiers, publishing requirements, trial phase and evaluation (with two different threshold numbers between the docs page and the staff post); Roblox Plus price; the questionnaire, label definitions and resubmission rule; access settings and the early tester limit; the 100 daily user benchmark rule; server restart options; Version History restore behaviour; Configs; data store versioning and snapshots; experience notification rules; update and event limits; community announcement limits; badge costs; pass icon specifications; private server rules; rewarded video eligibility and reward rules; the Community Standards on links, data, advertising and contests; erasure handling; audio import allowances and formats; automatic translation.

**Verified in the project research:** the recommendation signals; Ads Manager basics; paid random item rules; the January 2026 chat age checks; the Developer Exchange rate; Creator Rewards.

**Not verified:** the exact evaluation threshold (250 or 500) and the expedited fee (50,000 or 100,000 Robux); the publishing fee amount on an official docs page; whether Approved Experience works for a game that is not public; whether a game can change owner later; Roblox's refund process and any claw-back from creators; the security switch names; the Advertising Standards text and the under-13 advertising rule; which players are shown rewarded video by age; whether Creator Store audio can be used in videos outside Roblox; the current state of Player Support Tickets and performance alerts; mesh upload fees; the retail price of Robux; consumer law outside Roblox's own rules; any cost per play.

## 13. Proposed canon changes

The canon values are used unchanged above. These are the suggestions that are still open. The ones the canon has adopted have been removed: the 16-and-over evaluation phase before the go/no-go reading, the three rewarded video rewards, Tide Watcher as an in-game tide board, the expected Mild label, Moon Tide at :45 in the MVP, :30 as the flexible slot, and the [P2] tag for the Trench.

1. **Go/no-go limits (section 17).** Add the limits used here and in document 10: 100 daily users for 14 days, at most two extra four-week cycles, and a 20-week cap on soft launch.
2. **Limited-time tides (section 10).** Add that a limited-time tide runs Friday 15:00 UTC to Monday 15:00 UTC, and that it always returns.
3. **Post-launch traits (section 4.4).** The canon promises new traits week to week, but neither the canon nor document 03 names one. Either name at least two post-launch traits (Red Tide [P1] and the Trench [P2] are the natural sources) or remove "new traits" from section 4.4. The 12-week calendar here ships none.
4. **Game ownership.** Record that the game is owned by the GULP community, which is created in Sprint 0 (row A5), since ownership may be hard to change later.
