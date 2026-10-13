# 11 · Store page and marketing

This chapter defines how GULP is presented on Roblox and off it: the name, icon, thumbnails, video, page text, brand rules, free marketing, paid tests and the calendar. Document 01 (game canon) wins wherever this chapter disagrees with it. Document 06 owns the palette, the creature designs and the typefaces; the colours and fonts in section 8 are taken from it, and document 06 wins if they ever differ.

Numbers marked **(tune)** are first guesses. `S` means soft-launch day and `P` means public-launch day (document 12 defines both).

## 0. Platform facts this chapter relies on

Checked on 13 October 2026. Status key: **V** = read on an official page this session. **R** = verified earlier in `docs/research/`. **S** = secondary source only (forum post by a non-staff user, press, or a search snippet). **U** = could not be verified; treat as a guess.

| # | Fact | Status | Source |
|---|---|---|---|
| F1 | Icon: square, at least 512×512 pixels, one icon per locale, image only. It is scaled down to sizes such as 150×150 pixels. It must pass moderation before others see it. | V | [Experience icons](https://create.roblox.com/docs/production/publishing/experience-icons) |
| F2 | Icon file formats are not listed on the icon page. | U | Same page. Use PNG. |
| F3 | Roblox has no built-in split test for icons. A feature request from November 2024 had no staff reply by July 2026, and the August 2026 Open Cloud release has no icon endpoint. | V (absence) | [DevForum request](https://devforum.roblox.com/t/icon-ab-testing/3274267), [Open Cloud APIs post](https://devforum.roblox.com/t/new-opencloud-apis-for-analytics-events-experiments-and-thumbnail-personalization/4828676) |
| F4 | Thumbnails: up to 10 images or videos per game page. Images are 16:9, ideally 1920×1080, in .jpg, .gif, .png, .tga or .bmp. Other shapes are stretched to 16:9. Images are free. For personalisation keep each under 3 MB. | V | [Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails), [Promotional thumbnails](https://create.roblox.com/docs/production/promotion/promotional-thumbnails) |
| F5 | Thumbnails appear on the Home page and at the top of the game page. The player-count overlay can cover the bottom edge, so keep text away from it. | V | Same pages |
| F6 | Home page thumbnail personalisation: turn on 2 to 5 active thumbnails. Roblox shows each to random users, measures qualified play-through rate per group, and gives the winner more impressions. Roblox reports an average +8.5% in qualified play-through rate, and up to +50% for some games. The Thumbnail Performance table (Impressions, Qualified Plays, Average Playtime, Qualified Play Through Rate, Winning Segment) fills in after a few hours. Roblox advises keeping several active and changing them only with major updates. | V | Same pages |
| F7 | Video thumbnails: free, 3 uploads per month, and a rejected video still uses one of the three. An approved video appears first on the game page and can appear on Home. Not shown on Xbox, PlayStation or VR. | V | Same pages |
| F8 | Video content rules: real current gameplay only. Allowed: camera work, minor brightness or contrast changes, a logo overlay, in-game interface text, music from the Roblox catalogue. Not allowed: cinematic or enhanced footage, real-life footage, voice-over or narration, music with lyrics, promotional text or claims. Staff describe it as a "gameplay preview", not a trailer. | V | Same pages, [staff reply, July 2026](https://devforum.roblox.com/t/roblox-game-page-trailer-keeps-getting-rejected/4768090) |
| F9 | Video length, file size and file format limits for video thumbnails. | U | Not stated on either page |
| F10 | Name and description: Roblox advises a stable name, few emojis, no repeated words, a first sentence that summarises the game, and relevant keywords without repetition. Repetitive or spammy text can be demoted. Titles that lead with monetary rewards are not prioritised. Metadata that does not match the game is less visible in search. Search is semantic. | V | [Publish games](https://create.roblox.com/docs/production/publishing/publish-experiences-and-places), [Discovery](https://create.roblox.com/docs/en-us/discovery) |
| F11 | Character limits for the name and the description. | U | Not stated in the docs. Read the counter in the dashboard field. |
| F12 | Genre and an optional Subgenre are set from dropdowns in the Game details window. | V | [Publish games](https://create.roblox.com/docs/production/publishing/publish-experiences-and-places) |
| F13 | Recommendation signals: play-through rate from impressions, first-play bounce (under 60 s and 61 to 180 s), play days per user, playtime per user (capped at 60 minutes per user per game per day). Players who arrive from ads are not counted in the "Recommended for You" ranking stage. | V, R | [Discovery](https://create.roblox.com/docs/en-us/discovery) |
| F14 | Social links: at most three on the game page (Facebook, Twitter, YouTube, Twitch, Discord, Guilded, a Roblox community). They are visible only to users age-checked as 16 or older, and only a creator age-checked as 16 or older can add them. No link, invite code or email address may appear inside the game. The phrase "Links on our game's page" is allowed. | V | [Social links](https://create.roblox.com/docs/production/promotion/social-media-links) |
| F15 | Off-platform links are allowed only through the Social Links feature. Content published for compensation counts as advertising and must follow Roblox's Advertising Standards. Ads may not be personalised for users under 18. Off-platform commercial promotions bundled with on-platform rewards need a contract with Roblox. Users may not independently run contests with real-money prizes. | V | [Community Standards](https://about.roblox.com/community-standards) |
| F16 | The Advertising Standards themselves (including the rule, reported in 2023, that advertising must not be shown to under-13s). The help-centre page refused the fetch. | S | [BBB National Programs decision](https://bbbprograms.org/media/newsroom/decisions/roblox-advertising) |
| F17 | A new game is first playable only by age-checked users aged 16 or older. It reaches Roblox Kids (5 to 8) and Roblox Select (9 to 15) only after the creator meets the publishing requirements and the game passes evaluation: 250 unique plays by highly engaged, age-checked players within 60 days. A staff post from June and July 2026 gave 500, so read the live number on the Audience Reach dashboard. | V | [Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select), [DevForum announcement](https://devforum.roblox.com/t/roblox-kids-and-select-global-launch-upcoming-updates-to-eligibility-ads-manager-and-expedited-review/4685717) |
| F18 | Ads Manager: ads run on Home and in search results. Creative is thumbnails only, up to 10 per campaign, shown evenly. Objectives: Plays, Earnings (limited), Engagement. Daily or lifetime budget, automatic bidding. No stated minimum budget beyond a 5 US dollar first card charge. Card payment needs age 18+. Targeting: location, age, gender, genre, device. Recent Players audience needs 10,000 players. Ad review within about 24 hours, assets within 48 hours. Plays and earnings can take 48 hours to appear, with attribution up to 30 days. | V, R | [Ads Manager](https://create.roblox.com/docs/production/promotion/ads-manager) |
| F19 | Creator Rewards: 5 Robux per Active Spender who plays 10 minutes or more when the game is one of their first three that day. 35% of a new or returning user's first 100 US dollars of purchases when they arrive by share link, direct link or name search and play 10 minutes, if the game averages 100 or more daily users. | V, R | [Creator Rewards](https://create.roblox.com/docs/en-us/creator-rewards) |
| F20 | Share links: unlimited trackable links per game, one per channel is advised, with optional launch data. | V | [Share links](https://create.roblox.com/docs/production/promotion/share-links) |
| F21 | Update announcements: 60 characters, once every three days, sent to players who follow the game. Events: up to 10 ongoing or upcoming, a "Notify Me" button, and an optional submission for featuring that must be made 7 days before the start. | V | [Events and updates](https://create.roblox.com/docs/production/promotion/experience-events) |
| F22 | Community announcements can notify all members once every 7 days. Polls, forum and announcement analytics exist. | V | [Community tools post](https://devforum.roblox.com/t/new-tools-to-engage-your-communities-on-roblox-polls-analytics-support-tickets-and-more/4657552) |
| F23 | Creating a Roblox community costs 100 Robux. | S | [Help centre](https://en.help.roblox.com/hc/en-us/articles/203313730) (search snippet only) |
| F24 | Discord requires users to be at least 13. | V | [Discord terms](https://discord.com/terms) |
| F25 | US endorsement rules: a creator who receives payment, free items or early access must disclose it clearly inside the video itself. The brand is also responsible. Disclosures may not work for young children, so extra care is needed. | V | [FTC guidance](https://www.ftc.gov/business-guidance/resources/ftcs-endorsement-guides-what-people-are-asking) |
| F26 | Automatic translation covers 18 languages and translates the game name, description, in-game strings and products. | V | [Automatic translations](https://create.roblox.com/docs/production/localization/automatic-translations) |
| F27 | Advice on what gets clicked. Roblox: unique imagery that matches the game, colour and contrast that signal the theme, sharp images, no ambiguous graphics. Developers: show what the game is and a moment the player wants to try; brightness helps. | V (Roblox), S (developers) | Icon and thumbnail pages above, [DevForum thread, August 2026](https://devforum.roblox.com/t/how-to-get-playthrough-rate-up/4772142) |
| F28 | Third-party claims: on phones a tile is shown at about 110×110 pixels; one large subject, a clear silhouette and warm colours stand out against the Roblox interface. No data source is cited. | S | [RoWatcher article](https://rowatcher.com/news/why-your-roblox-thumbnail-works-on-desktop-and-fails-on-mobile) |
| F29 | Roblox Moments, a short-video feed inside Roblox for users aged 13 and over, was announced in September 2025. Its status in 2026 was not checked. | S | [TechCrunch](https://techcrunch.com/2025/09/05/roblox-announces-short-form-video-feed-for-gameplay-clips-new-ai-tools-for-creators-and-more) |

**The fact that shapes this chapter most is F17.** GULP's core audience is 9 to 16. Almost all of it is in Roblox Select, which cannot see a new game until it passes evaluation. Early marketing therefore has to bring in age-checked players aged 16 and over first. Section 10 and document 12 plan around this.

## 1. Positioning

### 1.1 The promise

> You are a tiny fish. Eat what is smaller, flee what is bigger, and get home before something gulps you.

This is the canon pitch shortened for a store page. Every asset must show at least one of its three verbs: eat, flee, get home.

### 1.2 Who it is for

| Group | Age | What they want | What we show them |
|---|---|---|---|
| Core | 9 to 16, on a phone | A game that starts at once and can be played in five minutes | Eating within seconds, fast growth, a near miss |
| Collectors | 9 to 14 | Something to own and show | The cove, traits on the body, the Codex |
| Secondary | 17 and over | A skill game with risk | The bank-or-push choice. At soft launch the Barracuda chase; Old Scar and the Drop-off only once they are in the live build. |
| First reachable (F17) | Age-checked 16 and over | Something that does not look like a typical Roblox game | The art style, the risk loop |

### 1.3 What is different on a page of Roblox icons

| On most icons | On GULP |
|---|---|
| A Roblox avatar | A sea creature. No avatar anywhere. |
| Several characters, effects, arrows and a price tag | One creature and one threat |
| Neon colours and text banners | A hand-painted look with three colour values per creature |
| A face that shouts | A face that has just noticed something behind it |

The research found no evidence that a non-Roblox look raises clicks or retention (viability report). Treat the look as a way to be recognised, and let the test in section 7 decide what gets clicked.

### 1.4 Message pillars

| # | Pillar | Proof in the game | Canon pillar it comes from |
|---|---|---|---|
| M1 | **Eat and grow in seconds** | First bite within five seconds, seven size tiers (five reachable in the soft-launch slice, so soft-launch art and text say five) | 1 |
| M2 | **Become what you eat** | Five trait prey give a visible trait with an effect | 2 |
| M3 | **Get home or get gulped** | Bank at the cove to keep the run; the cove shows what you kept | 3 and 4 |

Tide events (canon pillar 5) are a reason to return and are used in update and event messages. They are a supporting message, not a pillar.

## 2. The name

### 2.1 Why GULP

The canon gives the reasons: one syllable, a sound and a verb, readable at icon size, easy for a nine-year-old to say and spell. For marketing it adds two more. Players can use it in a sentence about what happened to them ("I got gulped by Old Scar"), and it gives the game its own end-of-video sound.

### 2.2 How it is written

| Context | Form |
|---|---|
| The name, everywhere | **GULP** in capitals |
| As a verb or event in copy | lower case: "gulp", "gulped", "got gulped" |
| Tagline | Eat. Grow. Get home. |
| Never | "Gulp!", "G.U.L.P.", "Gulp Simulator", "GULP.io", "Big Gulp" |

"Big Gulp" is a drinks brand name owned by another company (unverified in this session; check a trademark register). Do not use the two words together in any copy.

### 2.3 Store title options

Roblox convention is a name, one or more emojis, a short description of the loop, and sometimes a bracketed tag for a current update. Roblox's own guidance is to keep the name stable and use emojis sparingly (F10).

| # | Title | Use |
|---|---|---|
| 1 | `GULP 🐟 Eat. Grow. Get Home.` | **Default (canon).** |
| 2 | `GULP 🐟 Eat. Grow. Get Home. [🌙 Moon Tide]` | Bracket tag for a named event, 7 days at most |
| 3 | `GULP 🐟 Eat. Grow. Get Home. [NEW 🦈]` | Bracket tag for a new species, 7 days at most |
| 4 | `GULP 🐟 Eat Fish. Grow. Get Home.` | Fallback if name search shows people typing "fish" and missing us (tune) |
| 5 | `GULP 🐟` | Fallback if the name limit (F11) turns out shorter than option 1 |

Title rules:

1. `GULP` is always the first word and always in capitals.
2. The base title has exactly one emoji, the fish.
3. At most one bracket tag, always at the end, removed within 7 days. At most two tagged periods a month (tune).
4. Never put "free", "Robux", "UGC", "codes" or a number of rewards in the title (F10).
5. The words before the bracket never change without a canon change.

### 2.4 Name-collision check to repeat before launch

The canon records a web check on 13 October 2026. A search in this session also found no Roblox game named GULP. Repeat the full check three times: four weeks before `S` (check 1), one week before `S` (check 2) and two weeks before `P` (check 3). The calendar in section 11 and chapter 13 schedule all three.

| Step | Where | Pass condition |
|---|---|---|
| 1 | Roblox search in the app and on the web for "gulp", "GULP", "gulp fish", "gulp game" | No game named GULP with more than 100 concurrent players (tune) and none in the eat-and-grow genre |
| 2 | Roblox community search for "GULP" | The community name we need is free, or we already own it |
| 3 | Steam, App Store, Google Play, itch.io | No fish or eat-and-grow game named Gulp |
| 4 | Trademark registers (USPTO, EUIPO) for GULP in classes 9 and 41 | No live mark for video games |
| 5 | YouTube and TikTok search for "gulp roblox" | No existing game or series owns the phrase |
| 6 | Handle check for `@playgulp` (first choice) and `@gulpgame` | Free on the platforms in section 9 |

If step 1 or 4 fails, move to a backup name and change the canon first.

### 2.5 Backup names

None of these has been collision-checked. Run section 2.4 on any of them before use.

| # | Name | Reason |
|---|---|---|
| 1 | **BIGGER FISH** | The whole rule set in a phrase everyone already knows |
| 2 | **SMALL FRY** | Describes the start of every run and uses the canon tier name |
| 3 | **GLUB** | One syllable, a sound like GULP, reads at icon size |
| 4 | **TIDEBITE** | Joins the two systems players return for, tides and eating |
| 5 | **LITTLE LEVIATHAN** | States the journey from tier 1 to tier 7; longer, so weaker at icon size |

## 3. The icon

### 3.1 Technical base

| Item | Value |
|---|---|
| Master | 2048×2048 pixels, layered source kept in the repository |
| Export | 512×512 PNG (F1, F2) |
| Proof sizes | 150×150 (F1), 110×110 (F28) and 64×64 (our own stricter check) |
| Safe area | Everything that must be read sits inside the central 80%. Assume the corners are rounded by the client (unverified). |
| Source | Posed and lit with the real game models in Studio or Blender, then painted over. No element that is not in the build. |
| Text | None on any icon. No icon carries the name or any other word. |
| Stage | Every icon is tagged **soft launch** or **public launch**. A soft-launch icon uses only content of the soft-launch slice (chapter 13, section 3.2). No icon goes live before everything in it is in the live build. |

### 3.2 Main icon: A, "Behind you"

**Idea in one line:** a small fish that has just eaten, and the mouth that is about to eat it.

Icon A has two versions. The Minnow, the layout, the colours and the checks are the same; only the predator changes.

| Version | Predator | Live | Tag |
|---|---|---|---|
| **A, soft launch** | The Barracuda. It is in the slice, and it chases every new player in the first two minutes (chapter 04). | From `S` until `P` | [MVP] |
| **A, public launch** | Old Scar. It is not in the build at `S`; it returns in Sprint 40 (chapter 13). | From `P`, and never before Old Scar is in the live build | [L] |

| Element | Brief |
|---|---|
| Composition | Two shapes only. The Minnow sits at the centre, slightly below the middle, filling about 45% of the icon width. Behind it, the open mouth of the predator fills the frame: upper jaw across the top third, lower jaw across the bottom fifth. **Soft launch:** the long jaws of the Barracuda, seen from the front and slightly to one side, so its two rows of teeth close in from the top and the bottom. **Public launch:** the mouth of Old Scar fills the whole frame like a ring. |
| Minnow | Juvenile mesh, three-quarter front view, body angled 20° to the right, swimming toward the viewer. A krill tail sticks out of its mouth. |
| Minnow expression | Eyes very large (each about 20% of body length). Pupils turned back and up toward the jaw behind. A small closed smile that has started to wobble. Cheeks full. It reads as "I ate. Uh-oh." |
| Predator | Only the mouth is in frame, on-model from document 06. Simple clean teeth drawn as toy-like shapes with no detail: the Barracuda's row of small pointed teeth in the soft-launch version; about nine above and seven below for Old Scar in the public-launch version. No eyes, no gum detail, no red inside the mouth. Public-launch version only: the pale healed scar line crosses the upper lip. |
| Colours | Minnow in Minnow Tangerine with a lighter belly and Sun Yellow fin tips (three values). Mouth interior from Deep Blue to near black. Teeth in Cream. A band of Reef Blue water with two soft light rays sits between the Minnow and the mouth so the two shapes separate. Colour names are from section 8.2. |
| Light | Warm key light from top left. A thin Surface Aqua rim on the Minnow's back edge. |
| Background | The mouth is the background. Three Cream bubbles rise from the Minnow. Nothing else. |
| Outline language | No green or red outlines on the icon. The outlines are an in-game aid and add noise at small size. |
| Must read at 110×110 | (1) a small orange fish with big eyes, (2) teeth closing around it (a full ring in the public-launch version). If either is lost, the icon fails. |
| Must read at 64×64 | A warm shape inside a dark mouth with a light toothed edge |
| Maturity check | No blood, no wound, no realistic detail, no fear on the face beyond comic worry. It must fit the maturity label in document 12. |

**Hypothesis:** one cute face plus one clear threat tells the genre (eat or be eaten) faster than any gameplay scene, and a warm subject inside a dark ring separates from a row of bright, busy icons.

### 3.3 Four alternatives to test

| ID | Name | Composition | Characters and expression | Colours and background | Text | Hypothesis |
|---|---|---|---|---|---|---|
| B | **Teeth frame** | The camera is inside the predator's mouth looking out. Teeth frame the top and bottom edges. The Minnow is centred in bright open water beyond, about 35% of the width, facing the camera. | Minnow with wide eyes and a tiny open mouth, fins spread in a braking pose. | Deep Blue frame, bright Reef Blue centre, Minnow Tangerine fish. Strongest light-to-dark contrast of the five. | None | A strong frame is the most recognisable shape in a grid, and the point of view puts the viewer in the danger. Risk: at 64×64 the fish is small. |
| C | **Food chain** | A diagonal from bottom left to top right: Krill, then Minnow with mouth open behind it, then Barracuda with mouth open behind the Minnow. Each is about twice the size of the one before. | Krill unaware. Minnow focused and hungry. Barracuda grinning. | Surface Aqua to Reef Blue gradient, no scenery. Each creature in its document 06 colours. | None | Showing the mechanic itself brings players who want an eat-and-grow game, so more of the clicks become real sessions. Risk: three shapes may blur at small size. |
| D | **Puffed** | One Pufferfish face fills 85% of the icon, fully inflated, facing the camera. | Huge eyes, cheeks full, a Sardine tail sticking out of its lips, pleased with itself. | The Pufferfish in its document 06 yellow on Reef Blue. No other object. | None | A single large face is the safest read at the smallest size and appeals most to players aged 9 to 12. Risk: it says nothing about danger or growth. |
| E | **Mouth mark** | The mouth shape from the logo's U (section 8.1), drawn on its own with no letters, fills 80% of the width. A small Minnow is half inside it. | Minnow tail and one worried eye visible. | A Cream shape with an Ink Navy outline on Reef Blue. | None | A clean graphic mark stands apart from character icons and matches the logo players see elsewhere. Risk: weakest emotional pull. |

Icon E used to carry the wordmark. No icon has text, so it is now the mouth shape alone. Its scene ID is `SCN_Icon_E_MouthMark` (chapters 07 and 13 use the same name).

Production order and stage:

| Icon | Finished | Stage | Tag |
|---|---|---|---|
| A, soft-launch version (Barracuda) | Before `S` | Live at `S` | [MVP] |
| D | During soft launch, in Sprint 31 (chapter 13). It is not on the page at `S`. | Tested against A in soft launch (section 7.3) | [MVP] |
| A, public-launch version (Old Scar) | `P−4` | Live at `P` | [L] |
| B, C and E | `P−4` | Tested from `P+4` (section 7.3) | [L] |

B shows only teeth and C shows the Barracuda, so neither depends on Old Scar.

### 3.4 What the icon must never do

1. Show a Roblox avatar, a stud, a default part or any default interface.
2. Carry any text. No icon shows the name GULP or any other word.
3. Show more than three creatures.
4. Use arrows, circles, price tags, "NEW" or "UPDATE" stickers, sparkle bursts or fake buttons.
5. Show blood, a wound, realistic teeth or gums, a dead creature or a creature in pain.
6. Show a creature, zone, trait or event that is not in the current build (F10). At soft launch that means slice content only: no Old Scar, Moray, Tuna, Drop-off or Whale Fall, and no creature above tier 5 (no Titan, no Leviathan).
7. Use a shocked open-mouth face on the hero. The GULP face is worried or pleased, never screaming.
8. Imitate the layout, character or colours of another game's icon, or use any licensed or meme character.
9. Put key shapes outside the central 80% safe area.
10. Use a photo, a real animal or a realistic render.
11. Change more than once every 14 days outside a planned test (section 7).
12. Ship without passing the 110×110 and greyscale checks in section 7.1.
13. Show a thumb, a touch button, a key cap or a gamepad glyph. One icon is shown on every device (document 15, section 7).

## 4. Thumbnails

### 4.1 Technical base and shared rules

| Item | Value |
|---|---|
| Size | 1920×1080, PNG or JPG, under 3 MB (F4) |
| Source | Staged with real game assets in Studio using the free camera, then painted over lightly. Nothing that is not in the build. |
| Stage | Every thumbnail is tagged in section 4.2 with the stage it is live in. The soft-launch set uses only content of the soft-launch slice (chapter 13, section 3.2). |
| Caption | At most three words, in the wordmark typeface, top left or top centre. Never in the bottom 20% (F5). |
| Logo | Small GULP wordmark in the top right corner of every thumbnail except T1, about 12% of the width |
| Outlines | The green and red outlines may appear where they explain the rules (T1, T3) |
| Phone check | Each must read at 320 pixels wide |
| Controls | No thumb, touch button, key cap or gamepad glyph in T1 to T3. Roblox picks between the active thumbnails per player group, not per device, so every active thumbnail must work on every device (document 15, section 7). A controls picture, if wanted, goes in T4 or later. |
| Console | Video thumbnails are not shown on Xbox or PlayStation (F7), so from the day the Console switch goes on [P1] the first image thumbnail carries the whole pitch, seen from 3 metres: large shapes, at most three words, lettering at least 8% of the image height (tune). |

### 4.2 The thumbnails in order

| # | Name | The single idea | Composition | Characters | Caption | Pillar | Tag |
|---|---|---|---|---|---|---|---|
| T1 | **The chase** (lead) | You eat what is smaller while something bigger chases you | Side view, action moving left to right. Left third: a Barracuda with a red outline, mouth opening. Centre: the Minnow at full dash with a speed trail. Right third: a Krill swarm with green outlines scattering. Sunlit Reef behind, soft focus. | Barracuda, Minnow, 12 Krill | None | M1 | [MVP]. Soft launch, live at `S`; kept at public launch. |
| T2 | **Become what you eat** | Prey changes your body | Split in three vertical panels joined by arrows drawn as bubble trails. Each panel: trait prey on the left, the same Minnow on the right now wearing the trait. Glowfry gives Glow, Zebra Darter gives Stripes, Urchin Puff gives Spiny. The last panel's Minnow wears all three. | Minnow ×3, Glowfry, Zebra Darter, Urchin Puff | "BECOME WHAT YOU EAT" (four words; the one allowed exception) | M2 | [MVP]. Soft launch, live at `S`; kept at public launch. |
| T3 | **Get home** | Safety is a place you have to reach | Three-quarter view from behind and above the player. A Minnow with Glow races toward a lit cove mouth in the right third. A predator enters from the left edge with a red outline. A Pearl counter above the Minnow shows a large unbanked number. **Soft-launch version:** the Minnow is Nibbler-tier and the predator is a Barracuda, a little under twice the Minnow's size (the canon body scales for tier 4 and tier 2). This is the chase of the first two minutes (chapter 04). **Public-launch version:** the Minnow is Snapper-tier and the predator is Old Scar's head, about four times the Minnow's size (tier 7 and tier 3). | Soft launch: Minnow, Barracuda. Public launch: Minnow, Old Scar. | "GET HOME" | M3 | Soft-launch version [MVP], live at `S`. Public-launch version [L], live at `P`. |
| T4 | **Five sizes** (soft launch), **Seven sizes** (public launch) | You grow a long way | A line-up on a plain Reef Blue gradient, smallest at left, the same species at rising tiers, each with its tier name under it in small type placed above the bottom 20%. The biggest creature breaks the top and right edges of the frame. **Soft-launch version:** tiers 1, 2, 3, 4 and 5 (Fry, Nibbler, Snapper, Hunter, Brute), the sizes reached in normal play in the slice (chapter 13, section 3.2: no prey above tier 4, tier 6 only with effort, tier 7 out of reach). No Titan, no Leviathan and no crest. **Public-launch version:** tiers 1, 3, 5 and 7, with the Leviathan and its crest breaking the frame. | Soft launch: Minnow at five tiers. Public launch: Minnow at four tiers. Adult mesh from tier 4 in both. | Soft launch: "FRY TO BRUTE". Public launch: "FRY TO LEVIATHAN". | M1 | Soft-launch version [MVP], added during soft launch, in Sprint 31; not on the page at `S`. Public-launch version [L], live at `P`. |
| T5 | **Your cove** | What you bank is kept and shown | Inside a cove, warm light. Six specimens of mixed tier and trait float in their slots. Pearls drift up from each. In the foreground a small Minnow swims in through the mouth. | **Soft-launch version:** six specimens, Minnow and Pufferfish only, with the five slice traits. **Public-launch version:** six specimens, Minnow, Pufferfish and Eel with traits. | "KEEP WHAT YOU BANK" | M3 | Soft-launch version [MVP], live at `S`. Public-launch version [L], live at `P`. |
| T6 | **Moon Tide** | The sea changes on a clock | The reef at night in deep blue with glowing edges. A school of Lunar Fry crosses the frame. A Pufferfish with the silver Moonlit glow sits in the centre. The moon's disc shows through the surface at the top. | Pufferfish, Lunar Fry | "MOON TIDE" | Supports M2 and return visits | [MVP]. Added during soft launch, in Sprint 31, after Moon Tide ships (Sprint 28); not on the page at `S`. |
| T7 | **Pick your creature** | Six creatures that play differently | Six species in a shallow arc facing the camera, each in its ability pose: Minnow darting, Pufferfish puffed, Eel coiled, Sea Turtle tucked, Squid jetting with ink, Shark Pup grinning. | All six playable species | "SIX CREATURES" | M2 | [L]. Public launch. |
| T8 | **Whale Fall** | A big shared event with a big risk | Wide shot of the Drop-off. A clean whale skeleton sinks through the centre as a pale shape. Small player creatures swarm the Marrow chunks. Old Scar and a Grouper circle at the edges with red outlines. | Old Scar, Grouper, six small player creatures | "WHALE FALL" | M3 | [L]. Public launch. |

Before public launch, an MVP-only version of T7 with three species and the caption "PICK YOUR CREATURE" may be used, but not before the Eel is in the live build (Sprint 26 in chapter 13). It must be replaced, not edited, when the other three species ship.

The two sets, and what a launch checklist asks for at each stage (document 12, rows G5 and G6):

| Stage | On the game page | Active for Home |
|---|---|---|
| **Soft launch**, at `S` | T1, T2, T3 (Barracuda) and T5 (Minnow and Pufferfish). No video. | T1, T2 and T3 |
| **Soft launch**, from Sprint 31 | Add T4 (five sizes) and T6, and the soft-launch page cut (section 5) | Decided by section 7.2 |
| **Public launch** [L], at `P` | T1, T2, T3 (Old Scar), T4 (seven sizes), T5 (with the Eel), T6, T7 and T8, and the public-launch page cut | Round 2 in section 7.2 |

### 4.3 Which is the lead and why

**T1, The chase, is the lead.** It is first in the list on the game page and one of the active Home thumbnails.

- It shows the whole rule set in one frame with no text: something to eat in front, something that eats you behind.
- It uses the in-game colour language (green and red), so what the player sees in the first five seconds matches what they clicked. A match between the picture and the first minute protects the first-play bounce signal (F13).
- It has one clear subject in the centre, which the developer advice in F27 and F28 favours.
- It needs no translation.

The icon and T1 are deliberately different pictures of the same idea. The icon is a face and a threat. T1 is the action.

Active Home thumbnails at soft launch: T1, T2 and T3, in their soft-launch versions (section 7). T5 is on the page from `S` but is not active.

## 5. Video

### 5.1 Two cuts from one edit

Roblox accepts a gameplay preview, not a trailer (F8). We make one edit and export two versions.

| Version | Where | Text | Audio |
|---|---|---|---|
| **Page cut** | Roblox game page (first item) | Only the in-game interface and the GULP logo at the end | Game music and game sounds only. No voice, no lyrics. |
| **Social cut** | TikTok, YouTube, Reels, creator kits | Captions as listed below | Same music; captions land on the beat |

Both are 24 seconds, 1920×1080 at 60 frames per second, recorded from the live build on the highest graphics setting the build ships with. No colour grade beyond a small brightness and contrast lift. Every shot is recorded gameplay with the real interface visible. The social cut is also exported at 1080×1920 with the action re-framed.

The edit is recorded twice. There is no video on the game page at `S` (chapter 13, section 3.2).

| Recording | Recorded | Shows | Tag |
|---|---|---|---|
| **Soft-launch cut** | Sprint 31 (24 to 30 May 2027 in chapter 13's base case), from the live soft-launch build | Only what is in the live build that week | [MVP] |
| **Public-launch cut** | Sprint 63 (`P−2`), from the launch build; uploaded at `P−1` | The full shot list in section 5.2 | [L] |

Length, size and format limits for the page cut are unverified (F9). Export H.264 MP4 and keep it under 30 seconds. Each upload uses one of three monthly slots, even if rejected (F7), so check the list in F8 before uploading. An earlier research note (`research/notes/name_and_store_specs.md`) also says a video may not show interface or mechanics that are not in the game. The page cut shows only the real interface; check the end logo overlay against the live page before the first upload.

### 5.2 Shot list (24 seconds)

The first table is the **public-launch cut** [L]. Shots 1, 2, 3, 5 and 8 are the same in both cuts. Shots 4, 6 and 7 need the Moray, the Drop-off and Old Scar, so the **soft-launch cut** replaces them with the three shots in the second table.

| # | Time | Shot (all recorded gameplay) | Social-cut text | Page-cut text | Sound and music |
|---|---|---|---|---|---|
| 1 | 0.0 to 2.0 | A Fry leaves the cove mouth and bites a Krill inside the first second. Three more bites. | "EAT." | None | A single soft "gulp" on the first bite. Music starts on bite two: marimba and plucked strings. |
| 2 | 2.0 to 5.0 | Three fast cuts: through a Krill swarm, into a Sardine school, the tier-up pop to Nibbler and then Snapper with the tier banner on screen. | "GROW." | Tier banner (in-game) | A rising note on each tier-up. Add hand claps. |
| 3 | 5.0 to 8.0 | The fifth Glowfry is eaten in a reef cave. The body lights up. The Glow slot fills on the interface. | "BECOME WHAT YOU EAT." | Trait slot (in-game) | Shimmer on the trait gain. Bass enters. |
| 4 | 8.0 to 11.0 | Kelp Forest. A Moray lunges from a hole and misses as the player dashes. | None | None | Sharp whoosh, the music drops out for half a beat, then returns. |
| 5 | 11.0 to 14.0 | The 60-second tide warning ends and Moon Tide begins: the sea goes dark and glows, Lunar Fry appear. | "THE SEA RUNS ON A CLOCK." | Tide banner (in-game) | The key shifts down. Add a soft pad and a bell. |
| 6 | 14.0 to 18.0 | The Drop-off. Old Scar turns toward the player. Red outline. The player dashes away, with the unbanked Pearl number visible. | "GET HOME." | None | Low pulse. The tempo feels faster because the claps double. |
| 7 | 18.0 to 21.0 | The player reaches the cove mouth a body length ahead of Old Scar. Bank. Pearls count up. The specimen settles into a slot. | None | Bank summary (in-game) | Full band on the bank. Coin-like pearl ticks. |
| 8 | 21.0 to 24.0 | Slow orbit inside the cove with the GULP logo over it. | "GULP. Play free on Roblox." | Logo only | The music ends on one note, then the signature "gulp" and a bubble pop. |

Soft-launch cut, replacement shots:

| # | Time | Shot (all recorded gameplay) | Social-cut text | Page-cut text | Sound and music |
|---|---|---|---|---|---|
| 4 | 8.0 to 11.0 | The Reef surface. A Gull's shadow grows over the player. The Gull dives and misses as the player dashes down. | None | None | As shot 4 above |
| 6 | 14.0 to 18.0 | The east side of the Reef. A Barracuda turns toward the player. Red outline. The player dashes away, with the unbanked Pearl number visible. | "GET HOME." | None | As shot 6 above |
| 7 | 18.0 to 21.0 | The player reaches the cove mouth a body length ahead of the Barracuda. Bank. Pearls count up. The specimen settles into a slot. | None | Bank summary (in-game) | As shot 7 above |

The soft-launch cut uses only content that is in the live build when it is recorded in Sprint 31: the slice, plus Moon Tide (shipped Thursday 6 May 2027 in chapter 13's base case) for shot 5 and the Gull (Thursday 13 May 2027) for shot 4. If either has slipped, shot 5 shows a Feeding Frenzy starting and shot 4 shows a Barracuda charge in the Kelp Forest. The soft-launch cut never shows the Moray, Tuna, Old Scar, the Drop-off or Whale Fall. The public-launch cut cannot be recorded before the Drop-off, Old Scar and the Moray are in the build (Sprints 39 to 41).

### 5.3 Music direction

| Item | Direction |
|---|---|
| Mood | Playful, light on its feet, a little cheeky. Never epic, never tense for more than three seconds. |
| Tempo | 124 beats per minute (tune) |
| Instruments | Marimba, kalimba, plucked strings, hand claps, a round sub-bass, water percussion |
| Structure | It adds one layer per tier, as the game music does (the audio chapter owns this) |
| Signature | The video ends on the "gulp" sound and a bubble pop, with silence before it |
| Vocals | None (F8) |
| Source | **Soft-launch cut:** music from the Roblox catalogue, the same licensed or Creator Store track the slice plays in the Reef (chapter 13, section 3.2). `MUS_Theme` does not exist yet. **Public-launch cut** [L]: the game's own theme `MUS_Theme` if it has been composed (a cut candidate in chapter 13, Sprint 59); otherwise catalogue music again. The social cut carries music only if the track's licence covers social video; otherwise it uses game sounds only (document 12, C19). |

Whether music we upload ourselves counts as "music from the Roblox catalogue" for the page cut is unverified (F8). If the first upload is rejected for audio, re-export with game sounds only.

### 5.4 Six-second cut for social video

1080×1920, sound on, captions burned in. The soft-launch version is posted at `S` and the public-launch version [L] at `P`. Only the third shot differs.

| Time | Shot | Text | Sound |
|---|---|---|---|
| 0.0 to 1.5 | A tiny Fry bites a Krill, close camera | "EAT" | "gulp" |
| 1.5 to 3.5 | Three jump cuts of tier-ups, the creature filling more of the frame each time | "GROW" | Three rising notes |
| 3.5 to 5.0 | A predator's mouth closes over the camera. Cut to black. Soft launch: the Barracuda. Public launch: Old Scar. | None | A deep "gulp" |
| 5.0 to 6.0 | Logo on Reef Blue | "GULP. Free on Roblox." | Bubble pop |

## 6. Game page text

### 6.1 Description

Final copy for soft launch, with the real numbers of the slice at `S` (chapter 13, section 3.2): 2 creatures, 5 traits and 5 sizes. The slice has no Drop-off, Bonito or Tuna, so tier 5 (Brute) is the biggest size reached in normal play; tier 6 takes unusual effort and tier 7 is out of reach. The first two lines carry the hook because Roblox advises summarising the game in the first sentence (F10). The length limit is unverified (F11); this text is about 750 characters.

```
You are a tiny fish. Eat what is smaller, flee what is bigger, and get home before something gulps you.
Become what you eat: five Glowfry make you glow, five Urchin Puffs give you spines.

🐟 EAT AND GROW through 5 sizes, from Fry to Brute
✨ BECOME WHAT YOU EAT: 5 traits that change how you look and play
🏠 GET HOME: swim into your cove to keep your creature. Get gulped and you lose it.
🐚 YOUR COVE: banked creatures live there and earn Pearls, even while you are away
🌙 TIDES ON THE CLOCK: a tide event starts every 15 minutes on every server
🐡 2 CREATURES to unlock: Minnow, Pufferfish

One thumb on a phone. Works on PC and tablet too.
No avatars. No eggs. Just fish.

LATEST UPDATE (v0.9.0, 1 Apr): Soft launch. Tell us what breaks.
```

Changes during soft launch, each made in the same change as the build (rule 1). Dates are chapter 13's base case.

| When | Line that changes |
|---|---|
| The Eel ships (Thursday 22 April 2027) | "🐡 3 CREATURES to unlock: Minnow, Pufferfish, Eel" |
| Moon Tide and Moonlit ship (Thursday 6 May 2027) | "6 traits" |
| Longfin, Ink and Crystal ship, so the full [MVP] is live (Thursday 12 August 2027). The Drop-off, Bonito and Tuna are back by then (Sprints 35 to 39), so tiers 6 and 7 can be reached. | "9 traits", and "🐟 EAT AND GROW through 7 sizes, from Fry to Leviathan" |

Changes for public launch **[L]**: the size line reads "7 sizes, from Fry to Leviathan" (already changed if the Drop-off shipped on plan; it must not read 7 before tier 7 can be reached), "13 traits", "6 CREATURES to unlock: Minnow, Pufferfish, Eel, Sea Turtle, Squid, Shark Pup", add "and with a controller" to the controls line (document 15, section 7), and add the line "🐋 WHALE FALL at :45 every hour". The date in the last line is `S` in chapter 13's base case (Thursday 1 April 2027) and moves with it.

Change in **[P1]**: add "and on console" to the controls line on the day the Console switch goes on for Xbox and PlayStation (target weeks 2 to 4 after `P`, gated on the real-hardware checks in document 15), not before.

Description rules:

1. Every number in the description is true in the live build. Update the description in the same change as the build.
2. No links, no invite codes, no handles (F14, F15).
3. No "free Robux", "codes", "UGC" or prize wording (F10, F15).
4. No keyword lists. Each search word appears once, inside a sentence.
5. Only the latest update is listed. History lives in the community.
6. Never name the :45 slot or Whale Fall before Whale Fall ships at [L]. In the MVP the :45 slot runs a second Moon Tide (canon section 10), so the soft-launch text says only that a tide starts every 15 minutes. That is also true at `S`, when the slice runs a Feeding Frenzy on all four slots until Moon Tide ships (chapter 13, section 3.2).

### 6.2 Update-log format

Three places carry update text, each with its own limit.

| Place | Limit | Format | Example |
|---|---|---|---|
| Last line of the description | One line | `LATEST UPDATE (v<major.minor.patch>, <day> <month>): <headline>. <one more thing>.` | `LATEST UPDATE (v1.2.0, 7 May): Anglerfish is here. Lure prey with your light.` |
| Update announcement to followers | 60 characters, once every three days (F21) | `<New thing>. <What to do>.` | `Anglerfish is here. Lure prey with your light.` (45) |
| Community announcement and forum post | No stated limit; notification once every 7 days (F22) | Template below | |

Community post template:

```
GULP v1.2.0 · 7 May

NEW
- Anglerfish: a new creature to unlock with Pearls. Its Lure pulls small prey toward you.

CHANGED
- Moray lunge has a clearer warning.

FIXED
- Cove income no longer stops after a server restart.

NEXT TIDE EVENT
- Storm, Friday 15:00 UTC to Monday 15:00 UTC.
```

Version numbers: major for a public launch or a reset of saved data format, minor for a weekly update, patch for a hotfix. "Bug fixes" alone is never a headline (F21 advises against it).

### 6.3 Keywords and genre settings

Roblox search is semantic and penalises repeated or irrelevant keywords (F10). There is no keyword field. Each word below appears once in natural sentences in the description.

| Priority | Words | Where they appear |
|---|---|---|
| Must | fish, eat, grow | Line 1 and bullet 1 |
| Should | sea, creature, cove, collect, shark | Bullets; "shark" from public launch only, when Shark Pup ships |
| Never | simulator, io, brainrot, tycoon, obby, another game's name | Nowhere |

| Setting | Value | Status |
|---|---|---|
| Genre | **Roleplay & Avatar Sim** with subgenre **Animal Sim** as first choice (tune). Fallback: **Survival** with no subgenre. | The dropdowns exist (F12). The option names come from third-party trackers and were not read from the live dropdown, so they are unverified. |
| How to choose | Pick the option whose top games are closest to GULP. The benchmark scorecards compare us with "similar games", and the Animal Sim group contains the creature games in the viability report. | Whether genre decides the benchmark peer group is unverified. |
| Change rule | Set once before `S`. Change only between soft launch and public launch, and only once. | Our rule |

### 6.4 Social links policy

1. The game page carries at most three links (F14): the GULP Roblox community, YouTube, and Discord once the server exists.
2. The links are visible only to age-checked users of 16 and over (F14). Most of our core audience will never see them. The Roblox community is therefore the main channel, and the page links are a convenience for older players and creators.
3. Nothing inside the game names an off-platform service, shows a link, a handle, an invite code or a QR code (F14).
4. The only allowed in-game pointer is the phrase "Links on our game's page" (F14). GULP does not use even this at launch. Decide again after public launch.
5. The developer account must be age-checked as 16 or over to add links (F14).

## 7. Test plan for the icon and thumbnails

The deciding measure is **play-through rate from impressions**, the first recommendation signal (F13). In the dashboard it is shown as qualified play-through rate: qualified plays divided by Home recommendation impressions (F6).

### 7.1 Before any traffic (free, one hour per asset)

| Check | How | Pass |
|---|---|---|
| Small size | Scale to 110×110 and 64×64. Look for three seconds. | A person who has not seen it names "small fish" and "big mouth" (icon A) |
| Greyscale | Remove colour | The subject still separates from the background |
| Row test | Paste it into a phone screenshot of a Roblox Home row at true size | It is found within two seconds |
| Five-person check | Show five people in the target age range the row test, with a parent present for anyone under 13. Ask "which would you tap?" and "what do you do in that game?" | At least three of five describe eating or being eaten |

These checks come from third-party advice (F28) and our own judgment. They filter out weak art; they do not predict the play-through rate.

### 7.2 Thumbnails first

Thumbnails go first because Roblox has a tool that measures them on the surface that drives the first signal (F6), and it has none for icons (F3).

| Item | Plan |
|---|---|
| Tool | Home page thumbnail personalisation in the Creator Dashboard (F6) |
| Round 1 | T1, T2 and T3, in their soft-launch versions, active from `S` |
| Minimum run | 14 days and 2,000 impressions per thumbnail (tune), with no icon change and no new thumbnail during the run |
| Read | Thumbnail Performance table: Qualified Play Through Rate and Average Playtime per thumbnail |
| Decision | Keep every thumbnail whose rate is at least 70% of the best one (tune). Replace any below that with the next in line. When round 1 is read (Sprint 29 in chapter 13), T5 is the only spare. T4 and T6 join the line when they are finished in Sprint 31: then T4 (the five-size soft-launch version) first, then T6. |
| Guard | A thumbnail with the best rate but an Average Playtime more than 25% below the others (tune) is bringing the wrong players. Replace it. |
| Round 2 | Starts with the public-launch build. Add T7 and T8, and swap T3, T4 and T5 to their public-launch versions (T4 from five sizes to seven). Roblox advises changing thumbnails with major updates and leaving them alone in between (F6). |
| Never | Reduce to one active thumbnail. With one active, personalisation stops (F6). |

A second, cleaner comparison comes free with any paid test: Ads Manager shows up to 10 thumbnails evenly (F18). Whether it reports plays per thumbnail is unverified. If it reports only views per thumbnail, run one small campaign per thumbnail with equal budgets.

### 7.3 Icon second

Roblox has no icon split test (F3), so icons are tested one after another. This is weaker than a split test because traffic changes from week to week. The rules below reduce that problem; they do not remove it.

| Item | Plan |
|---|---|
| Start | After thumbnail round 1 has settled, and only once the game has 100 or more daily users, so that a week holds enough impressions. Not before icon D is finished (Sprint 31 in chapter 13). |
| Order | In soft launch: A in its soft-launch version (baseline), then D. At `P` the live icon changes to the public-launch version of A, unless D won; that is a launch change, not a test. From `P+4`: B, then C, then E, each against the icon that is live then. |
| Run length | 7 full days each, Monday 00:00 UTC to Sunday 24:00 UTC, so each icon sees one full week |
| Freeze | No update announcement, event, ad change or thumbnail change in a test week. If one is unavoidable, the week does not count. |
| Read | Analytics, Acquisition page: impressions and plays by source for the week. Which per-source breakdowns exist is unverified; if only Home is broken out, use total plays divided by total impressions. |
| Minimum data | 5,000 impressions per icon (tune) |
| Decision | A challenger replaces the baseline only if its play-through rate is at least 15% higher in relative terms (tune) and its first-play bounce is no worse. A smaller difference counts as no difference; keep the baseline. |
| Confirm | Run the winner and the old baseline one more week each. Adopt it only if it wins twice. |
| Stop | After all five, the winner stays until the next major update. |

If Roblox ships an icon test tool, replace this section with it.

## 8. Brand kit

### 8.1 Logo treatment

| Item | Rule |
|---|---|
| Wordmark | "GULP" in capitals, heavy rounded letters, tight spacing, on a slight upward arc of 3° |
| The U | The inside of the U is a mouth: darker fill, and a small Minnow tail or a single bubble leaving the top. This is the only illustrated letter. |
| Colours | Cream letters, Ink Navy outline at 8% of letter height, Sun Yellow highlight on the top left of each letter |
| One-colour version | Cream on dark, Ink Navy on light. No gradients. |
| Clear space | Half the height of the G on all sides |
| Minimum size | 96 pixels wide. Below that use the icon. |
| Never | Stretch, rotate past the 3° arc, add a drop shadow longer than the outline, place on a busy area without the outline, or redraw it in another typeface |
| Files | `UI_Brand_Logo.svg`, plus `UI_Brand_Logo_Cream.png` and `UI_Brand_Logo_Navy.png` at 2048 pixels wide with a transparent background |

### 8.2 Colours

All values are from document 06 (sections 4.2, 4.3, 4.5 and 4.6). Marketing adds no colours of its own.

| Name used in this chapter | Hex | Where it comes from in document 06 | Use in marketing |
|---|---|---|---|
| Reef Blue | `#1E9FD0` | Sunlit Reef mid water | Main background, open water |
| Surface Aqua | `#6FDDEE` | Sunlit Reef surface band | Light rays, rim light, gradients |
| Deep Blue | `#0B2A66` | The Drop-off, deep | Predator mouths, night scenes |
| Ink Navy | `#14213D` | Interface ink | Outlines, the logo outline, text on light |
| Minnow Tangerine | `#FF9A3D`, with light `#FFE2A8` and dark `#C2491D` | `minnow` mid, light and dark | The hero creature |
| Sun Yellow | `#FFC93D` | Primary button; the `minnow` accent is `#FFD23D` | Highlights, the logo highlight, calls to action |
| Cream | `#FFF8E7` | Interface panel | Text on dark, logo letters, teeth, bubbles |
| Home Amber | `#FFC46B` | The "home" signal | Only the glow of a cove mouth (T3, T5) |
| Can-eat Lime | `#A6FF3D` | The "you can eat it" signal | Only that outline |
| Can-eat-you Red | `#FF3B4E` | The "it can eat you" signal | Only that outline |

The canon calls the two outlines green and red; document 06 sets the green to this lime. The three signal colours keep their in-game meaning everywhere and are never used as decoration. Every creature in marketing art keeps its three colour values from document 06. Nothing is neon.

### 8.3 Typeface direction

Marketing uses the two game typefaces chosen in document 06, section 12.3, so that the store page and the game match.

| Use | Typeface | Rule |
|---|---|---|
| Wordmark | Drawn by hand as a logo, based on the letterforms of **Fredoka One**: heavy, round, with soft corners | The U is redrawn as a mouth (section 8.1) |
| Captions on thumbnails and videos | **Fredoka One**, capitals | Cream with an Ink Navy outline |
| Body text in marketing images and the fact sheet | **Nunito**, Bold or ExtraBold | Ink Navy on Cream, or Cream on Deep Blue |
| Never | Script, pixel, horror or stencil faces, or the default Roblox faces listed in document 06 | Two typefaces at most |

Both fonts are built into Roblox (document 06). Using them in images and video made outside Roblox needs a licence that covers that use. Both are published under open licences as far as we know (unverified): download them from their official source, read the licence file, and keep it in `docs/licences/`.

### 8.4 Tone of voice

GULP talks like a friendly older sibling who finds the food chain funny. Sentences are short. Verbs come first. The player is "you". At most one sea pun per message. We never mock a player for being gulped, never use capital letters to shout outside captions, never use countdown pressure for purchases, and never write "epic", "insane" or "OMG".

| # | Context | Example line |
|---|---|---|
| 1 | Update note headline | "Anglerfish is here. Lure prey with your light." |
| 2 | Update note, balance change | "Morays now twitch before they lunge. You asked. They agreed." |
| 3 | Update note, fix | "Fixed: coves that forgot to pay out after a restart. Your Pearls are back." |
| 4 | Event announcement | "Whale Fall at :45. Big food. Bigger company." |
| 5 | Event announcement, limited time | "Storm tides this weekend only. Friday 15:00 UTC to Monday 15:00 UTC." |
| 6 | In-game tide warning | "Moon Tide in 60 seconds. Lunar Fry are coming up." |
| 7 | Getting gulped | "Gulped by a Barracuda. You kept 12 Pearls of scraps. Go again?" |
| 8 | Error, save not loaded | "We could not load your cove. Nothing is lost. We are trying again." |
| 9 | Error, purchase did not complete | "That purchase did not go through. You were not charged." (shown only when the purchase callback confirms no charge) |
| 10 | Error, server shutting down for an update | "New tide coming in. This reef restarts in 5 minutes. Swim home and bank." |

### 8.5 How creatures are posed in marketing

1. **On-model.** Use the real game meshes and rigs. No redesigns, no added limbs, no human hands, no clothing.
2. **Always doing something.** Eating, fleeing, dashing, banking, or noticing. No creature floats idle facing the camera, except the species line-up in T7.
3. **Eyes tell the story.** Pupils point at the thing that matters: the food or the threat.
4. **Expressions allowed:** hungry, pleased, worried, determined, smug. **Not allowed:** screaming, crying, angry, dead, in pain.
5. **Predators are big, sharp and fast, and never gory.** They are on-model from document 06: no blood, no wounds, no realistic detail, no glowing red eyes. Old Scar always shows the pale healed scar line, and the notched fin when the fin is in frame.
6. **Size is truthful.** Relative sizes follow the canon body scales. A tier 7 creature is 6.5 times a Fry, never more.
7. **The hero is the Minnow** unless the asset is about another species. The Shark Pup is never the main hero, because most players will not own it for weeks.
8. **Traits shown are real.** At most three traits on one creature, with the looks in the canon trait table.
9. **Eating is shown before or after, not during.** A tail sticking out of a mouth is the standard "just ate" pose. Being eaten ends in bubbles.
10. **No avatars, ever.** No Roblox character appears in any asset, including creator kits.

## 9. Off-platform marketing with no budget

### 9.1 What these channels can and cannot do

| Limit | Consequence |
|---|---|
| Until evaluation passes, only age-checked users of 16 and over can play (F17) | Before that point, aim videos and outreach at older Roblox players and at people who like fish and arcade games |
| Page links are hidden from under-16s (F14) | Videos must say the name so viewers can search "GULP" on Roblox |
| A share link that brings a new or returning Roblox user can pay 35% of their first 100 US dollars of purchases, once the game averages 100 daily users (F19) | Put a different share link (F20) in the profile of each platform so the best channel is known |
| Most short-video platforms set a minimum age of 13 (unverified here) | We do not design content for under-13s off-platform, and we never ask a viewer's age or collect anything from viewers |

### 9.2 Short-video plan

Platforms: TikTok, YouTube Shorts and Instagram Reels, with the same file posted to all three. Roblox Moments is an option for players aged 13 and over if it is still available (F29).

Formats that suit this game:

| Format | Why it suits GULP | Length |
|---|---|---|
| **Tiny to huge** | Growth is visible and fast; the last frame pays off the first | 15 to 30 s |
| **Near miss** | The bank-or-push choice produces real tension without any setup | 8 to 15 s |
| **What happens if** | Traits are cause and effect: eat five of something, see the change | 10 to 20 s |
| **Clock** | Tide events happen at real times, so "it is :45" is a hook that is always true | 10 to 20 s |
| **Devlog** | A game with no avatars built by one person is an unusual story on Roblox | 20 to 45 s |
| **Loop** | Krill swarms and schools are satisfying to watch on repeat | 6 to 10 s |

Twenty specific videos. A video is recorded gameplay, so it can show only what is in the build in the week it is recorded. The hooks below use slice content (chapter 13, section 3.2) for every video due before the rest of [MVP] returns; the fuller versions are the remakes in the second table.

| # | Title or hook | Format | Earliest |
|---|---|---|---|
| 1 | "From Fry to Brute in 30 seconds" (a slice run sped up; tier 5 is the highest tier reached in normal play at `S`) | Tiny to huge | S−2 |
| 2 | "I ate five glowing fish and this happened" | What happens if | S−3 |
| 3 | "Three body lengths from home" (Barracuda chase that ends in a bank) | Near miss | S−2 |
| 4 | "Three body lengths from home" (the same chase that ends in a gulp) | Near miss | S−2 |
| 5 | "This Roblox game has no avatars" | Devlog | S−4 |
| 6 | "Every fish you can eat, smallest to biggest" (Plankton to Mackerel) | Tiny to huge | S−3 |
| 7 | "It is :15. Watch the sea." (a Feeding Frenzy starting on the quarter hour, in real time) | Clock | S−1 |
| 8 | "Do not touch the jelly" (the jelly bloom stun, and what finds you while you cannot move) | What happens if | S−1 |
| 9 | "The Barracuda always gets someone" (three charges, three victims, one escape) | Near miss | S |
| 10 | "Pufferfish versus Barracuda" (Puff used at the last moment) | Near miss | S |
| 11 | "Eel shortcuts only Eels can use" | What happens if | S+3, the week the Eel ships (Thursday 22 April 2027) |
| 12 | "My cove after 7 days" (slow pan across specimens) | Tiny to huge | S+1 |
| 13 | "One Krill swarm, one bite at a time" (a loop with only game sound) | Loop | S−2 |
| 14 | "How I made a fish swim with one thumb" | Devlog | S−4 |
| 15 | "Rating every way to get gulped" | What happens if | S+2 |
| 16 | "Crystal Jelly spotted. The whole server stopped." | Near miss | After Crystal ships (Sprint 42) |
| 17 | "Bank now or go deeper?" (freeze at the choice, the result in the next video) | Near miss, two parts | S+3 |
| 18 | "Six creatures, six ways to escape" | What happens if | P−1 |
| 19 | "Whale Fall, :45, everyone shows up" | Clock | P |
| 20 | "A viewer's cove tour" (a public cove, recorded in-game, shown with the owner's agreement and, for under-18s, without their username) | Tiny to huge | P+2 |

Remakes, recorded when the content is in the live build (sprints from chapter 13's base case):

| Remake of | Title or hook | Format | Earliest |
|---|---|---|---|
| 7 | "It is :15. Watch the sea." (Moon Tide starting in real time) | Clock | After Moon Tide ships (Thursday 6 May 2027) |
| 6 | "Every fish you can eat, smallest to biggest" (Plankton to Tuna) | Tiny to huge | After Bonito and Tuna ship (Sprint 36) |
| 1 | "From Fry to Leviathan in 30 seconds" (a 20-minute run sped up) | Tiny to huge | After the Drop-off opens (Sprint 39) |
| 3 and 4 | "Three body lengths from home" (Old Scar chase, ending in a bank and in a gulp) | Near miss | After Old Scar ships (Sprint 40) |
| 8 | "Do not eat the worm" (the fishing hook yank) | What happens if | After the hook ships (Sprint 41) |
| 9 | "The Moray always gets someone" (three lunges, three victims, one escape) | Near miss | After the Moray ships (Sprint 41) |

Rules for every video: recorded gameplay only; the first frame already contains movement; the name GULP is said or shown in the first three seconds and on the end card; game sound is audible; the last sound is the "gulp"; no claim about rewards; no call for viewers to give personal details.

Posting rhythm:

| Period | Posts per week | Recording time |
|---|---|---|
| S−4 to S−1 | 3 | One 2-hour session a week |
| S to P−1 | 4 | One 2-hour session a week; reuse gameplay from testing |
| P−1 to P+4 | 5 | Two 90-minute sessions a week |
| After P+4 | 3, or stop if a channel has brought under 1% of new players for 4 weeks (tune) | One session a week |

Each week review the share-link clicks (F20) and the top video. Make two more in the top video's format the next week.

### 9.3 Creator outreach

**Who to approach**

| Tier | Who | Count to contact | Why |
|---|---|---|---|
| 1 | Roblox creators with 1,000 to 50,000 subscribers who cover new or unusual Roblox games | 30 | They answer messages and need new material |
| 2 | Creators who cover animal and creature games on Roblox | 15 | Their audience already accepts playing without an avatar |
| 3 | Short-video creators who post fish, ocean or eat-and-grow game clips on any platform | 15 | The loop is familiar to them |
| Not now | Creators above 500,000 subscribers | 0 | They expect payment, and a spike before retention is proven wastes the traffic |

Start outreach only after the go/no-go in document 12 is passed. A creator video sends a burst of players, and they should meet the build that retains.

**What to offer (no money)**

| Offer | Notes |
|---|---|
| Early access to the next update through a private server | Allowed. It is still a benefit, so the creator must disclose it (F25). |
| A press kit: logo, six screenshots, 60 seconds of clean gameplay footage, a fact sheet | Section 12 |
| Their name on a cove decoration ("Reef sign") for one month | Cosmetic, not sold, not random |
| A direct line for bug reports and a reply within a day | |
| Not offered | Robux, a share of revenue, exclusive codes tied to buying anything, or giveaways with real-money value (F15) |

Free in-game reward codes handed out through creators are common on Roblox. The Community Standards restrict off-platform commercial promotions bundled with on-platform rewards (F15), and it is unverified whether a free code with no purchase counts. GULP ships no code system at launch.

**Template message**

```
Subject: A Roblox game with no avatars: you are a fish (early access)

Hi <name>,

I am a solo developer. I made GULP, a Roblox game where you are a small
sea creature instead of an avatar. You eat what is smaller, run from
what is bigger, and swim home to keep what you grew. A run takes about
five minutes.

I watched your video on <specific video> and thought of it because
<one specific reason>.

It is live now: search "GULP" on Roblox or use <share link>.
I can set up a private server for you and give you the next update a
few days early. There is no payment and no script. Say what you think.

If you do post about it, please tell viewers in the video that the
developer gave you early access.

A press kit with footage and screenshots is here: <link>.

Thanks for reading,
<name>, developer of GULP
```

**Rules on paid promotion and disclosure**

| Rule | Status |
|---|---|
| Content a creator publishes for compensation is advertising under Roblox's Community Standards and must follow the Advertising Standards (F15) | V |
| Early access and free items are a material connection and must be disclosed clearly in the video itself, not only in the description. The brand shares responsibility (F25). | V |
| Roblox agreed in 2023 to ask creators with child-directed content to use the word "paid" in disclosures (F16) | S |
| Advertising must not be shown to under-13s on Roblox (F16) | S |
| Our rule: GULP pays no creator in the first six months. If that changes, read the Advertising Standards in full first and use a written agreement that requires the words "paid by the developer of GULP" spoken and on screen at the start. | Our rule |

### 9.4 Community

| Channel | Purpose | Age rule | Tag |
|---|---|---|---|
| **Roblox community "GULP"** | The main home. Announcements, polls, forum, bug reports. It is on-platform and moderated by Roblox. | Open to Roblox users under Roblox's own age rules | [MVP]. Created in Sprint 0; opened and promoted to players at `S−4`. |
| **Roblox game follow** | Update announcements and event notices | Under-13s can receive update announcements; personalised notifications are for 13 and over | [MVP] |
| **Discord server "GULP"** | Older players, testers and creators. Faster conversation. | 13 and over (F24). The Roblox page link is visible only to age-checked users of 16 and over (F14). | [P1] |

Community rules:

1. Create the Roblox community in Sprint 0 (100 Robux, F23), before the first experience is created. The community owns the game (document 12, rows A5 and A6; chapter 14, decision D11), and ownership is hard to change later. It is not linked, promoted or posted in until `S−4`, four weeks before soft launch, when it is opened and promoted to players (section 11).
2. A community announcement with a notification goes out at most once every 7 days (F22). Use it for the weekly update.
3. The Discord server opens only after public launch. One person cannot moderate two live spaces during a launch.
4. Discord set-up: rules screen on join, a statement that the server is for ages 13 and over, no direct-message promotion, no channel for trading or giveaways, no collection of Roblox usernames beyond what a bug report needs, and slow mode on public channels.
5. No Discord invite is promoted in the game or in the description (F14).
6. Anyone who says they are under 13 in the Discord is removed, with a note pointing them to the Roblox community, and reported through Discord's own tools.

## 10. Paid user acquisition

### 10.1 What paid traffic is for

Paid traffic buys data and daily users. It does not buy ranking: players who arrive from ads are not counted in the "Recommended for You" ranking stage (F13). The three uses are:

1. Reaching the evaluation threshold so that under-16s can play (F17).
2. Holding 100 or more daily users so that the benchmark scorecards open (canon go/no-go).
3. Comparing thumbnails on equal impressions (F18).

No cost-per-play figure for Roblox was found in research. The stop rules below use placeholder costs marked (tune). Replace them after step 1.

### 10.2 Set-up

| Item | Setting |
|---|---|
| Access | Ads Manager needs an account of 13 or over with a verified email. Card payment needs 18 or over. The first campaign triggers a 5 US dollar charge that counts toward the bill (F18). |
| Objective | **Engagement** while the game is still in the 16-and-over trial phase (it targets players who count toward the threshold and costs more per play). **Plays** after evaluation passes. Never **Earnings** in the first six months. |
| Audience | All Players. The Recent and Lapsed audiences need 10,000 and 20,000 players (F18). |
| Targeting | Device: phone and computer. Add console only after the Console switch is on [P1], and only if console day-1 retention is within 5 points of phone (document 15, section 7). Age and location left open for step 1 so the result is not narrowed before there is data. |
| Budget type | Daily budget. It cannot be changed after publishing (F18). |
| Creative | T1, T2 and T3 (soft-launch versions) in step 1. Step 2 starts before T4 and T6 exist, so it adds T5 first, then T4 and T6 once they are finished in Sprint 31. Step 3 uses the public-launch set and adds T7 and T8. |
| Lead time | Submit 48 hours before the start to allow for review (F18). |

### 10.3 Budget ladder

| Step | When | Spend | Goal | Go to the next step if | Stop if |
|---|---|---|---|---|---|
| **0** | Before any spend | 0 | At least 50 organic or invited players have passed through the first-session funnel | "Still playing at 60 seconds" is 70% or more and "bank the first creature" is 45% or more (tune; the canon targets are 80% and 60%) | Below those values. Fix the first session first. |
| **1** | Soft launch, trial phase | 30 US dollars: 10 a day for 3 days | Learn the cost per play. Add highly engaged plays toward the threshold. Compare T1, T2 and T3. | Cost per play is 0.15 US dollars or less (tune) and ad players' 60-second survival is 60% or more (tune) | Cost per play is above 0.30 (tune), or 60-second survival is below 50%. Pause at once; do not wait for day 3. |
| **2** | Soft launch, after under-16s can play | 140 US dollars: 10 a day for 14 days | Hold 100 or more daily users for the 14 days that the go/no-go read needs (document 10) | Daily users reach 100, and day-1 retention of ad players is at least half that of organic players (tune) | Daily users stay under 50 after 3 days, or cost per play rises above twice the step 1 figure |
| **3** | Public-launch week | 300 US dollars: 30 a day for 10 days | Keep the 100-user average for Audience Expansion (F19) and bring a launch-week crowd so servers feel full | Only if the go/no-go in document 12 was passed | Either go/no-go measure fell below the median during soft launch. Spend nothing. |

Total across the ladder: 470 US dollars. The Engagement objective does not pause when the threshold is reached (F18), so check the Audience Reach dashboard daily during step 1 and pause by hand.

### 10.4 How to read the result

| Number | Where | Meaning |
|---|---|---|
| Cost per play | Ads Manager: spend divided by plays | The price of one session. Plays can take 48 hours to appear, so read it on day 3, not day 1 (F18). |
| Impressions to clicks to plays, per thumbnail | Ads Manager campaign details | Which thumbnail earns the click and the play |
| 60-second and 180-second survival of ad players | Our own funnel events, split by the ad launch data (F18) | Whether the picture and the first minute match. Low survival means the creative promises something the game does not deliver in time. |
| Day-1 retention and session time, ad players against organic | Creator analytics, by acquisition source | Whether ad players are real players |
| Highly engaged unique plays | Audience Reach dashboard | Progress toward under-16 access (F17) |
| Daily users | Creator analytics | Whether the benchmark scorecards open |
| Earnings attributed to ads | Ads Manager | Read after 30 days. Do not judge a 3-day test on it. |

One sentence decides each step: if ad players leave in the first minute at a much higher rate than organic players, fix the creative or the first minute before spending again; if they stay but the cost per play is high, try the other thumbnails once, and stop if the cost does not fall.

## 11. Marketing calendar

Dates are chapter 13's base case (section 4.1): `S` is Thursday 1 April 2027 and `P` is Thursday 20 January 2028 (Thursday 9 December 2027 if the cut candidates are removed). If chapter 13 re-dates a milestone, the weeks below move with it. "Soft-launch set" and "public-launch set" are the icon, thumbnail and video versions tagged in sections 3, 4 and 5.

| Week | Game state | Store page | Video and social | Community and creators | Paid |
|---|---|---|---|---|---|
| Sprint 0 (19–25 Oct 2026) | Spikes | None | None | Create the Roblox community "GULP" (100 Robux, F23) before the first experience is created, so that it owns the game. Not promoted yet. | None |
| S−4 (1–7 Mar 2027) | Private test | Collision check 1 (section 2.4). Reserve handles. | Open the accounts. Post videos 5 and 14. | Open the Roblox community (created in Sprint 0) to players and start promoting it. | None |
| S−3 (8–14 Mar) | Private test | Icon A, soft-launch version, finished. T1 to T3, soft-launch versions, finished. Checks in section 7.1. (Icon D waits for Sprint 31.) | Videos 2 and 6, plus one devlog | First community post: what GULP is | None |
| S−2 (15–21 Mar) | Friends-and-family test | T5, soft-launch version, finished. Description written with the slice numbers. (T4 and T6 wait for Sprint 31.) | Videos 1, 3, 4 and 13 | Poll: which creature first, Pufferfish or Eel? | None |
| S−1 (22–28 Mar) | Friends-and-family test | Collision check 2. Upload the soft-launch set for moderation: icon A and T1, T2, T3 and T5. No video yet. | Videos 7 and 8, plus one more | Announce the soft-launch date in the community | Ads Manager account set up; payment method verified |
| **S** (Thu 1 Apr 2027) | **Soft launch** (16 and over until evaluation passes), with the slice of chapter 13, section 3 | T1 to T3 active with personalisation on. T5 on the page. No video. | Videos 9 and 10. Post the six-second cut, soft-launch version. | Community announcement with notification | Step 1 from day 2, if step 0 is passed |
| S+1 to S+2 (5–18 Apr) | Soft launch | No changes. Thumbnail round 1 is running. | 4 a week, including videos 12 and 15 | Weekly update post. Reply daily. | Read step 1. Fix or continue. |
| S+3 to go/no-go (19 Apr–20 Jun; go/no-go on Mon 21 Jun) | Soft launch, under-16s unlocked when evaluation passes (estimate Thu 22 Apr). The Eel, Moon Tide, the Gull and the Codex ship. | Change the description numbers when the Eel and Moon Tide ship (section 6.1). Replace weak thumbnails after round 1; T5 is the only spare until Sprint 31. In Sprint 31 (24–30 May): icon D, T4 and T6 finished; the soft-launch page cut recorded and uploaded; icon tests (A against D) start once daily users pass 100. | 4 a week, including videos 11 and 17 and the remake of 7. Post the social cut in Sprint 31. | Weekly update post. Poll on the most wanted launch species. | Step 2 |
| Go to P−5 (21 Jun–19 Dec 2027) | Go decided. The rest of [MVP] returns to the live game (the Drop-off, Old Scar, the Moray, the hook; full [MVP] on Thu 12 Aug 2027). Then the [L] content is built behind flags. | Change the description numbers with each update (section 6.1). The icon, thumbnails and video stay on the soft-launch set. | One recording session a week: the remakes of videos 1, 3, 4, 6, 8 and 9, and video 16, each after its content ships | Weekly update post | None |
| P−4 (20–26 Dec 2027) | Go decided. Launch build feature-frozen. | The public-launch set finished: icon A with Old Scar, icons B, C and E, T7 and T8, and the public-launch versions of T3, T4 (seven sizes) and T5. | 4 a week. Start teasing Whale Fall. | Begin creator outreach to tiers 1 and 2 (45 messages over two weeks) | None |
| P−3 (27 Dec–2 Jan 2028) | Launch build in test | Launch description drafted. Launch event created as private. | 4 a week | Send press kits. Set up private servers for creators. | None |
| P−2 (3–9 Jan 2028) | Launch build in test | Collision check 3, for the title. Record the public-launch page cut. | 5 a week. Video 18. | Creators receive early access. | None |
| P−1 (10–16 Jan) | Launch build frozen | Create the public "Launch Week" event and submit it for featuring at least 7 days ahead (F21). Upload the public-launch set for moderation: the new icon, the new thumbnails and the new page cut. | 5 a week. Countdown posts. | Announce the launch date. Community poll. | Step 3 campaign submitted 48 hours ahead |
| **P** (Thu 20 Jan 2028) | **Public launch** | Launch description live. Title tag `[NEW 🦈]` for 7 days. The public-launch set goes live: icon A with Old Scar (unless D won the soft-launch test), T3, T4 (seven sizes) and T5 swapped, T7 and T8 active (round 2), the public-launch page cut. | Video 19. A new social cut and six-second cut with launch content. | Update announcement (60 characters). Community announcement with notification. | Step 3 running |
| P+1 (24–30 Jan) | Live, hotfixes only | Remove the title tag on day 7. | 5 a week. Clip the best creator moments, with their permission. | Thank-you post. Bug list published. | Step 3 ends. Read it. |
| P+2 (31 Jan–6 Feb) | Live, first content week | No changes, except: on the day the Console switch goes on (weeks 2 to 4, document 15), add "and on console" to the description | 5 a week. Video 20. | Open the Discord server [P1]. Weekly update post. | None, unless step 3 met its goal and cost per play held |
| P+3 (7–13 Feb) | Live | Read thumbnail round 2. Replace weak ones. | 5 a week | Weekly update post. Second creator round to tier 3 (15 messages). | None |
| P+4 (14–20 Feb) | Live | Resume the icon tests with B, C and E. | 5 a week, then move to the after-launch rhythm | Monthly community summary: what changed because of feedback | Decide on always-on spend using document 12, section 9 |

## 12. Marketing assets to produce

| # | Asset | Size and format | Count | Tag |
|---|---|---|---|---|
| 1 | Icon A "Behind you": the soft-launch version (Barracuda) and the public-launch version (Old Scar) | 2048×2048 master, 512×512 PNG | 2 | Soft-launch version [MVP], live at `S`. Public-launch version [L]. |
| 2 | Icon D "Puffed" | Same | 1 | [MVP], made during soft launch (Sprint 31); not at `S` |
| 3 | Icons B, C and E | Same | 3 | [L] |
| 4 | Thumbnails T1 to T6, with T3, T4 (five sizes) and T5 in their soft-launch versions | 1920×1080 PNG or JPG under 3 MB | 6 | [MVP]. Slice: T1, T2, T3 and T5 at `S`; T4 and T6 during soft launch (Sprint 31). |
| 5 | Thumbnails T7 and T8, and the public-launch versions of T3, T4 (seven sizes) and T5 | Same | 5 | [L] |
| 6 | Thumbnail T7, three-species version | Same | 1 | [MVP] optional; not before the Eel ships |
| 7 | Page cut, gameplay preview | 1920×1080, 24 s, H.264 MP4 (format unverified) | 1 | [MVP]: the soft-launch cut, recorded in Sprint 31; no video at `S`. Re-cut at [L]. |
| 8 | Social cut | 1920×1080 and 1080×1920, 24 s, captions burned in | 2 | [MVP]: the soft-launch cut, with the page cut in Sprint 31. Re-cut at [L]. |
| 9 | Six-second cut | 1080×1920 | 1 | [MVP]: the soft-launch version at `S`. Re-cut at [L]. |
| 10 | Logo | SVG, plus Cream and Navy PNG at 2048 wide, transparent | 3 files | [MVP] |
| 11 | End card for short videos | 1080×1920 and 1920×1080 PNG, plus a 1-second animated version | 3 | [MVP] |
| 12 | Game pass icons: Deep Pockets, Bigger Cove | 512×512, key content inside the circle (pass spec verified in document 12) | 2 | [MVP] |
| 13 | Game pass icons: Tide Watcher, Keen Nose, Shark Pup | Same | 3 | [L] |
| 14 | Product icons: Revive, four Pearl packs | 512×512 (product icon spec unverified; use the pass spec) | 5 | [MVP] |
| 15 | Product icons: Trait Lock, Call the Tide, Cove Boost, Goal Reroll, Starter Pack, Patterns (Cove Boost and Goal Reroll are also the rewarded-video rewards) | Same | 6 or more | [L] |
| 16 | Badge icons, soft-launch set: every [MVP] badge in document 03, section 12, which owns the list | 512×512, key content inside the circle | 20 | [MVP]. Five are needed at `S`; the rest when their batch is created (document 12, section 2.3). |
| 17 | Badge icons, launch set: every [L] badge in the same list | Same | 9 | [L] |
| 18 | Roblox community emblem | 512×512 PNG (spec unverified) | 1 | [MVP]. The community is created in Sprint 0; the finished emblem is in place before it opens to players at `S−4`. |
| 19 | Event thumbnails: Launch Week, Storm, Red Tide, Great Migration, The Trench Opens | 1920×1080 (the event page states no size; 16:9 assumed) | 5 | [L] for Launch Week; [P1] for Storm, Red Tide and Great Migration; [P2] for The Trench Opens |
| 20 | Social profile pictures | 800×800 PNG, a crop of icon A (the soft-launch version until `P`) | 1 | [MVP] |
| 21 | Channel banner | 2560×1440 with the logo inside the central 1546×423 (platform spec unverified) | 1 | [MVP] |
| 22 | Screenshot set for the press kit | 1920×1080 PNG, clean gameplay with the interface | 6 | [L] |
| 23 | Clean gameplay footage for creators | 1920×1080, 60 s, no captions, no music | 1 | [L] |
| 24 | Fact sheet | One-page PDF: pitch, what is different, controls, developer contact, disclosure request | 1 | [L] |
| 25 | Short videos 1 to 20, and the seven remakes in section 9.2 | 1080×1920, 6 to 45 s | 27 | [MVP] for 1 to 17 and the remakes, each recorded only when its content is in the live build; [L] for 18 and 19; [P1] for 20 |
| 26 | Discord server icon and banner | 512×512 and 960×540 (spec unverified) | 2 | [P1] |
| 27 | Localised caption versions of T2 to T6 for the three largest non-English audiences in the analytics | 1920×1080 | Up to 15 | [P2] |
| 28 | Seasonal icon variant (icon A with one seasonal prop) | 512×512 | 1 per major season | [P2] |

All source files live in the repository under a marketing folder, named with the canon prefix `UI_Brand_` or `UI_Store_` (for example `UI_Store_Icon_A.png`, `UI_Store_Thumb_T1.png`).

## 13. What was verified and what was not

**Verified on official pages this session:** icon and thumbnail sizes and counts; thumbnail formats; video thumbnail quota and content rules; Home thumbnail personalisation and its performance table; the absence of an icon test tool; naming and description guidance; the recommendation signals and that ad players are excluded from the recommendation ranking stage; the social links rules and the 16-and-over visibility; the Community Standards on off-platform links, compensated content and contests; the Kids and Select publishing and evaluation rules; Ads Manager objectives, creative, targeting and audiences; Creator Rewards; share links; update and event limits; community announcement limits; automatic translation languages; Discord's minimum age; the US endorsement guidance.

**Not verified:** icon file formats; video length, size and format limits; whether our own uploaded music is accepted in the page cut; name and description character limits; the genre dropdown option names and whether genre sets the benchmark peer group; which acquisition breakdowns exist for icon tests; whether Ads Manager reports plays per thumbnail; the Advertising Standards text and the under-13 advertising rule (secondary sources only); the community creation fee (search snippet only); whether free reward codes given through creators are allowed; any cost per play; platform specs for off-Roblox banners and minimum ages on short-video platforms; the "Big Gulp" trademark; font licences.

## 14. Proposed canon changes

The canon values are used unchanged above. These are the suggestions that are still open; the one the canon has adopted (the 16-and-over evaluation phase before the go/no-go reading, canon section 17) has been removed.

1. **Tagline capitalisation (section 1).** The store title has "Get Home." and the tagline has "Get home." Keep both, and state that the capital H is used only in the title.
2. **Colour wording (section 5.2).** The canon says "green outline"; document 06 sets that colour to lime `#A6FF3D`. Keep the word "green" in the canon and add the hex, so that marketing, interface and art use one value.
3. **Species count in page text.** The soft-launch slice has two species, the full MVP has three and the launch build has six. Add a rule that every public number (species, traits, events) is taken from the live build, so marketing text is never ahead of the game.
4. **Reward codes.** Add "no code system at launch" to section 3, until the rule in F15 on off-platform promotions with on-platform rewards has been read in full.
