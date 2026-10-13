# Roblox market trade-offs for a non-avatar, non-Roblox-looking game (as of 2026-10-13)

Confidence labels: [OFFICIAL] = Roblox primary document (SEC exhibit, Creator Hub). [SECONDARY] = press or analytics coverage. [OPINION] = commentary. Items older than 12 months are flagged [STALE].

## Discovery and recommendation algorithm

### Takeaway
Roblox's own docs and the Q2 2026 letter say discovery rewards retention and engaged play over raw clicks. The company states it deliberately favours highly retentive games. Nothing found says the algorithm penalises a genre or art style. The docs don't mention art style, fidelity or avatar use at all.

### Cited Findings
- Creator Hub lists play-through rate as the single most important discovery signal. Next are play days per user (D1, D2-7, D8-28), playtime per user (capped at 60 min per user, per game, per day), and first-play bounce rate (negative, measured at <60s and 61-180s). Important signals: intentional co-play days, qualified play sessions per user, spend days per user, Robux spent per user. [OFFICIAL, undated page, copyright 2026] — https://create.roblox.com/docs/en-us/discovery
- Qualified play-through rate (qPTR) is engaging plays divided by impressions from "Recommended for You". Creators see it under Analytics > Acquisition > Home Recommendations. Impression spikes can temporarily lower qPTR. No benchmark numbers were published. [OFFICIAL, 2026 page versions] — https://create.roblox.com/docs/discovery
- Q2 2026 shareholder letter (quarter ended June 30, 2026): "intentionally provides more impressions for highly retentive games at the expense of near term monetization." [OFFICIAL, SEC 8-K Ex. 99.1] — https://www.sec.gov/Archives/edgar/data/0001315098/000162828026051059/ex991-robloxq22026earnin.htm
- Same letter: engagement shifted "from high monetizing, 2025-vintage viral games" to new and evergreen games with lower hourly monetization. The effect was larger than expected for younger cohorts in US and Canada. Management says longer retention should offset lower hourly monetisation over time. Monetisation softness is expected to continue into Q3 2026. [OFFICIAL] — same SEC URL
- RDC 2026 (held 11 Sept 2026 per Invenglobal): discovery rankings will use data beyond the first 28 days rather than just the first week. Roblox is testing ways to measure new-user acquisition per game. [SECONDARY, reporting RDC keynote] — https://www.invenglobal.com/articles/25918/roblox-unveils-expansions-to-play-creation-and-monetization-at-rdc and https://www.91mobiles.com/gaming/roblox-announces-standalone-game-apps-at-rdc-2026/
- Genre or art-style bias: no official statement found either way. [GAP]

### Inferences
- A game with a strong retention curve and healthy session length should rank well regardless of look. Visual style is not a documented input.
- Because the letter says the algorithm now prioritises retention over monetisation, a non-avatar game that holds players could get more impressions than a high-spend monetisation-first title.

### Gaps
- No official data on genre or art-style weighting, or on the distribution of qPTR by genre.
- No public benchmarks for a "good" qPTR, D1 or D7 retention, or session length.

## Platform size and demographics (2026)

### Takeaway
DAUs peaked at about 152M in Q3 2025 per secondary coverage and were about 123M in Q2 2026 (+10% YoY). Roughly two-thirds of age-checked users are 13+. The company's own letter reports US and Canada growth slowed. Regional DAU totals, the device split and spend-by-age were not found in primary sources.

### Cited Findings
- Q2 2026 DAUs: 123M, up 10% YoY. The letter also says "over 120 million DAUs in the quarter." [OFFICIAL, SEC Ex. 99.1]. Q2 2026 is also cited by secondary press as 123M. [SECONDARY] — https://interspacemusic.com/blog/roblox-daily-active-users-fall-to-123-million-in-q2-2026/
- Q3 2025 DAU peak of 152M and three quarters of decline to Q2 2026 — [SECONDARY] — https://www.shacknews.com/article/150205/roblox-rblx-q2-2026-earnings-results . One secondary source gives Q1 2026 as 132M [SECONDARY, unverified]. One gameindustrylibrary summary gives 152M for Q2 2026, which conflicts with the letter and is probably an error. Source: https://gameindustrylibrary.com/documents/roblox-fy2026-q2-earnings-release/read
- Q2 2026 regional: US and Canada DAUs +6% YoY, Japan +67%, India +64%. Hours engaged 29B (+5% YoY). US and Canada hours +1%, Japan +61%, India +59%. Totals for Europe, APAC and RoW not given in the letter. [OFFICIAL, SEC Ex. 99.1]
- Q2 2026 bookings $1,557M (+8% YoY from $1,438M), at the low end of guidance. Average bookings per DAU is not reported by Roblox. Our calculation, not a company figure: about $12.66 per DAU per quarter. [OFFICIAL bookings; calculation is ours]
- Age-checked data (Q4 2025 letter, through 31 Jan 2026): 45% of DAUs age-checked. Of those, 35% U13, 38% aged 13-17, 27% 18+. That implies about 65% are 13+. [SECONDARY summary of OFFICIAL letter; the Q4 2025 PDF was not fetched directly] — https://s27.q4cdn.com/984876518/files/doc_financials/2025/q4/Q4-2025-Shareholder-Letter.pdf (listed in search results, not opened)
- Self-reported Q3 2025 split (about 49.8M under 13, 101.3M 13+). Secondary, method differs from age-checked data. Roblox says age-checked data shows a younger base. [SECONDARY, Q3 2025, about 12-13 months old as of Oct 2026: treat as STALE-borderline] — https://www.tikr.com/blog/roblox-jumped-10-on-older-user-growth-why-the-stock-could-hit-115-in-2026
- 17-24 is the fastest-growing cohort per TIKR coverage of Q4 2025 call. [SECONDARY]

### Inferences
- The audience is majority 13+ on age-checked data, so a game aimed at teens and young adults fits the base. The 17-24 growth and the younger-cohort monetisation softness both point the same way.
- The US and Canada slowdown (DAU +6%, hours +1%) versus strong Japan and India growth suggests international growth is where new users come from.

### Gaps
- No official 2026 device split (mobile, PC, console) or regional DAU totals found. The letter gives only partial regional growth.
- No official spend-by-age breakdown found.
- The 13+ share figures come from secondary summaries of letters and were not checked against the primary PDFs.

## Monetisation options (no avatar items)

### Takeaway
DevEx is 0.0038 USD per Earned Robux (standard), with 0.0054 for certain sales to verified US 18+ players. Minimum cashout is 30,000 Earned Robux. No revenue-share percentage is listed on the DevEx page. Roblox is moving creator payouts to a wallet, and cross-experience game-pass sales were disabled. Ads and brand-integration pricing are on a CPM basis, but no cost-per-play for Sponsored Experiences was found.

### Cited Findings
- DevEx standard rate: 0.0038 USD per Earned Robux (about $114 per 30,000). Higher rate 0.0054 applies only to certain Earned Robux from developer products, passes, subscriptions and private servers bought by US players verified 18+ (facial age estimation or ID). Minimum cashout 30,000 Earned Robux; one cashout per calendar month. No revenue-share % or processing fee listed. Balances from before 5 Sept 2025 cash out at 0.0035. Page last updated 12 Oct 2026. [OFFICIAL] — https://create.roblox.com/docs/en-us/production/monetization/developer-exchange.md
- Several third-party guides still say 0.0035 for 2026. Those predate the Sept 2025 change. Ignore them. [SECONDARY, outdated] — https://rolearn.dev/guidance/roblox-devex-requirements-2026
- Q2 2026: cross-experience game-pass sales were disabled; this weighed on monetisation "to a lesser degree." [OFFICIAL, SEC Ex. 99.1]
- RDC 2026: Roblox Wallet for creators' real-currency earnings, rolling out late 2026 for US creators aged 18+, global in 2027. Roblox Card to follow in 2027. Roblox says creators earned more than $5bn through DevEx since 2013. [SECONDARY, RDC coverage] — https://www.pocketgamer.biz/roblox-unveils-new-play-creation-and-monetisation-tools-at-rdc-2026/ ; https://www.91mobiles.com/gaming/roblox-announces-standalone-game-apps-at-rdc-2026/
- Brand integrations: from 1 Jan 2027, billed by CPM instead of a percentage. US $1.50 CPM; UK, Canada, Australia, NZ, Nordics $0.75; Western Europe, Japan, South Korea $0.20; rest of world $0.05. After 28 days, flat $0.10 CPM. [OFFICIAL-ish, reported 21 Jun 2026 by Outlook Respawn quoting Roblox] — https://respawn.outlookindia.com/gaming/gaming-news/roblox-reveals-2027-pricing-model-for-brand-integrations
- CES 2026: CPM-based homepage ad unit in closed beta, planned to go always-on later in 2026. [SECONDARY] — https://respawn.outlookindia.com/gaming/gaming-news/roblox-unveils-homepage-ad-format-and-expands-buying-at-ces-2026
- Rewarded video CPM $5-15 and brand ROI benchmarks come from a third-party blog. Not verified. [SECONDARY, unverified] — https://rolearn.dev/insights/rewarded-video-ads-new-revenue-stream
- Not verified in this session: Premium payouts, subscriptions and paid-access pricing. These need a Creator Hub check.

### Inferences
- With no avatar-item sales, revenue comes from passes, developer products, private servers and possibly subscriptions. The 18+ rate premium applies only to a narrow US-verified buyer slice, so most players will earn the standard 0.0038 rate.
- Disabling cross-experience passes and the shift to wallets mean monetisation rules are still changing. Plan for revenue volatility.

### Gaps
- Sponsored Experiences / Ads Manager cost-per-play and CPM figures for games were not found.
- Premium payout formula and Creator Rewards details were not found.
- Paid-access pricing rules and any revenue share on paid access were not found.

## What is lost by dropping the avatar

### Takeaway
No data found on whether players dislike not seeing their avatar in a non-Roblox game. Player backlash to avatar changes in 2025 shows the community cares about avatar identity. Avatar-item commissions are the main lost revenue line, but no figure was found for their size.

### Cited Findings
- Backlash to forced Dynamic Heads and removal of classic faces: a Change.org petition argues players lose self-expression. Advocacy source, not neutral. [OPINION] — https://www.change.org/p/bring-back-2024-2025-roblox-avatar-features and https://www.change.org/NoChoiceGiven
- Dexerto reports Roblox discontinued classic avatar faces; players felt betrayed. [SECONDARY] — https://www.dexerto.com/roblox/roblox-under-fire-for-removing-classic-avatars-2226960/
- No primary data on avatar-free game performance or on what share of revenue comes from avatar commissions found. [GAP]

### Inferences
- Community sentiment is strongly attached to avatars. This suggests the avatar is a strong identity hook. A game without one gives up that hook, but may gain a distinct look that stands out in discovery.

### Gaps
- No quantified data on in-experience avatar item sales or commission rates.
- No data on whether players dislike avatar-free experiences.

## Evidence on stylised and non-Roblox-looking games

### Takeaway
The biggest 2025 hits were UGC-style, Roblox-looking games with strong social and viral mechanics (Grow a Garden, Steal a Brainrot). Roblox says hits from that wave have lower hourly monetisation. No verified evidence was found on how visually distinct games perform. Dress to Impress 2025 numbers were not found.

### Cited Findings
- Grow a Garden: launched 26 Mar 2025; peak about 22.3M CCU during the Aug 2025 event; fastest to 1B visits (33 days); dropped out of the top 10 by Dec 2025. [SECONDARY, Wikipedia cites; peak figure from one source] — https://en.wikipedia.org/wiki/Grow_a_Garden
- Steal a Brainrot: Wikipedia says the only game to pass 25M CCU. August peaks conflict across sources (15M to 20M); another source says 25.4M of about 47M platform CCU in Oct 2025. Visits fell about 30% from the Aug peak by Dec. [SECONDARY, conflicting] — https://en.wikipedia.org/wiki/Steal_a_Brainrot
- Newzoo: Q2 2025 first quarter with a game over 10M peak CCU. Platform record 47.3M in Aug 2025. Those two games were nearly 80% of traffic at the peak. Brookhaven RP and Blox Fruits were in the top 10 every month of 2025. [SECONDARY, Newzoo summary] — https://gamedevreports.substack.com/p/newzoo-top-roblox-games-in-2025
- Dress to Impress: 11.5M peak CCU around Dec 2024 (Winter update). No 2025 figure found. [SECONDARY, out of date for 2025 analysis, flag STALE] — no reliable URL found in this session.
- Dead Rails, 99 Nights in the Forest, Frontlines and "doesn't look like Roblox" showcases: NOT RESEARCHED in this session. [GAP]
- The hit games above are all Roblox-looking UGC. None found showed a stylised non-Roblox look.

### Inferences
- The top 2025 hits are social and virality-driven, not art-led. Visual distinctiveness is not shown in the data to be a driver of CCU.
- Hits that drive engagement but have low hourly monetisation are exactly what Roblox now says it is down-ranking in favour of retention. A retention-first game with a distinct look may be better placed than a viral one.

### Gaps
- No direct comparison of stylised versus Roblox-looking titles on CCU, retention or monetisation.
- Dead Rails, 99 Nights and Frontlines evidence not gathered.

## Genre saturation and opportunity (2026)

### Takeaway
No official Roblox genre-opportunity report or third-party genre analysis for 2026 was found in this session. This question is open.

### Gaps
- Not researched. Suggest a follow-up search of Roblox Creator Hub analytics pages and Naavik / Deconstructor of Fun for 2026 genre trends.

## Solo developer economics

### Takeaway
Economics data was not gathered in this session. Known inputs are the DevEx rate and minimum cashout. CCU needed to earn a target income can be estimated from these only with assumed conversion rates, which are not sourced here.

### Cited Findings
- Minimum DevEx cashout is 30,000 Earned Robux, which is about $114 at the standard rate. [OFFICIAL] — https://create.roblox.com/docs/en-us/production/monetization/developer-exchange.md
- Sponsored Experiences cost-per-play: not found. Brand-integration CPM rates above are for brands, not for ads a solo dev buys. [GAP]

### Gaps
- No sourced CCU-to-income figure.
- No sourced cost-per-play for solo developers buying traffic.

## Scope gaps and data caveats

- Device split, regional DAU totals and spend-by-age not found in primary sources.
- Premium payouts, Creator Rewards and paid-access pricing not verified.
- Genre saturation, avatar-dislike data and solo-dev economics not found.
- Several figures come from secondary summaries and conflict (Steal a Brainrot CCU, Q2 2026 DAU figure in one summary). Prefer the SEC letter.
- Third-party DevEx guides still list 0.0035; the official page (updated 12 Oct 2026) lists 0.0038.
- Items older than 12 months: Dress to Impress Dec 2024 figure; Q3 2025 self-reported age split is borderline.
