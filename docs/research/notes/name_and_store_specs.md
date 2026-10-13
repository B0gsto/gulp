# Name collisions and Roblox store specs (checked 2026-10-13)

Search method: web search only, one query per name ("<name> roblox game"). Search results are noisy and low-quality on some names, so "clear" means no hit found, not a confirmed absence. Facts only, no pick.

## 1. Name collisions

| Name | Roblox experience with same/near name | Other well-known product with name | Verdict |
|---|---|---|---|
| Gulp | None found. | Gulp! (puzzle game, itch.io PC/web); Gulp: A Gas Station Simulator (itch.io, in dev); Gulp (Timex Sinclair retro game); Berkley Gulp (fishing lures, widely sold). | crowded |
| GULP! | None found. | Same as "Gulp" (Gulp! puzzle game on itch.io and LaunchBox). | crowded |
| Gulp Reef | None found. Closest: "The Reef" (roblox.com/games/15073773912, also 14820294138). | Berkley Gulp fishing soft plastics (reef fishing). | clear |
| Glub | None found. | Glub, a Funkey in UB Funkeys; Fight Glub (Global Game Jam 2025, Godot). | clear |
| Reef Raiders | None found. Closest: "Reef Rush Mastery Mode" (roblox.com/games/17090138985), "The Reef". | None notable found. | clear |
| Nestnappers | None found. Only an unnamed Rolimons group tagged "(NEST)" (rolimons.com/group/855220, 2,498 members, no description). Not confirmed as related. | None found. | clear |
| Chomp Reef | None found. Closest: "Chomped" (roblox.com/games/77339851249060), not reef-themed. | None found. | clear |
| Brood | None found. Closest: "Morbus" (roblox.com/games/156120160, 2017, alien theme, sequel "Incursion"). | Broodstar (Xbox/Microsoft Store game). | crowded |
| Egg Tide | None found. Closest generic egg games (Adopt Me!, Dungeon Quest) and an "Eg" egg-avatar social experience (unnamed URL). | None found. | clear |
| Snatch Reef | None found. Closest: "The Reef". | Snatch a Seed (Roblox farming/stealing game); Snatch Squad (voxel co-op heist, PC). | crowded |
| Big Gulp Reef | None found. "The Reef" (roblox.com/games/15073773912) about 18M+ visits per a profile page. Oceanic (same group, stopped development). | Big Gulp is a common drink brand name (not searched in depth). | clear |
| Gobblefin | None found. | Gobfin (Palworld Pal); Gobble (Fancade on Poki). | clear |

Note: "The Reef" (MajorGalah, SharkingAround, IrritatingFish) is a large, similar-theme Roblox experience, relevant to any reef-themed name.

## 2. Roblox store asset specs (Creator Hub)

| Fact | Value | Source | Status |
|---|---|---|---|
| Icon size | Use 512x512 template; square, at least 512x512 | https://create.roblox.com/docs/production/publishing/experience-icons | Verified |
| Icon format | Not stated | same | Not verified |
| Icon file size limit | Not stated | same | Not verified |
| Icons per locale | One per locale; supplementary image/video thumbnails allowed | same | Verified |
| Icon text/misleading rules | Not explicit. Advice: show relevant imagery; ambiguous graphics may confuse. All icons pass moderation. | same | Partly verified |
| Icon testing tools | None described; preview step, check at 150x150 | same | Verified |
| Thumbnail size | 16:9, ideally 1920x1080; non-16:9 is stretched | https://create.roblox.com/docs/production/publishing/thumbnails | Verified |
| Thumbnail formats | .jpg, .gif, .png, .tga, .bmp | same | Verified |
| Thumbnail file size limit (standard) | Not stated (3 MB limit applies only to personalization images) | same | Not verified |
| Thumbnail max count | Up to 10 images or videos per game detail page | same | Verified |
| Video thumbnails | Must show actual gameplay; no UI or mechanics not in the game; no real-life footage, voice-over, narration, or lyric music; no ads/promotions/subjective claims. Free upload quota 3 per month (rejected uploads count). Not on Xbox, PlayStation, VR. | same | Verified |
| Video length/format/size | Not stated | same | Not verified |
| Trailer-specific rules | Not stated | same | Not verified |
| Text rules on thumbnails | Avoid essential text or elements at bottom of thumbnail. All uploads moderated. | same | Verified |
| Name length limit | Not stated | https://create.roblox.com/docs/production/publishing/publish-experiences-and-places | Not verified (no limit found) |
| Description length limit | Not stated | same | Not verified |
| Name/description rules | Keep name consistent (renames hurt findability); avoid repeated words (demotion risk); emojis sparingly. Description: summarize in first sentence; keywords without repetition. | same | Verified |
| Personalization (thumbnail) | Home page thumbnail personalization; activate 2-5 thumbnails (needs 2+ to start); winner gets more impressions per user group; Thumbnail Performance analytics; experimental Cloud API endpoints; docs cite +8.5% average qualified play-through rate. Image limits: under 3 MB, 1920x1080. | https://create.roblox.com/docs/production/publishing/thumbnails and https://create.roblox.com/docs/marketplace/custom-thumbnails (search result only) | Verified (thumbnails page); the +8.5% and API details come from search snippet, not fetched directly |
| Separate A/B test feature | None described beyond personalization | thumbnails page | Verified (absent) |

Not verified: experience name and description character limits (not stated on the pages checked); icon file formats and size; standard thumbnail file size; trailer rules.
Note: https://create.roblox.com/docs/production/publishing/publish-experiences-and-places states no character limits. The custom-thumbnails page covers Accessory thumbnails only and is not the experience store spec.
