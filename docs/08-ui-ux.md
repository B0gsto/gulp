# 08 · Interface (UI and UX)

This chapter defines every screen, overlay, interface element, interface image and line of interface text in GULP. It expands document 01 (canon) and uses its names, IDs and scope tags.

**This chapter owns:** layout, flow, behaviour, every interface image and icon, all interface text.
**It does not own:** game rules (02), the scripted first two minutes (04), prices (05), colours, fonts and shapes (06). Where a price would appear this chapter writes "price from chapter 05".

**Conventions**

- **rpx** = reference pixel, a pixel on the 1280 × 720 reference canvas (section 1.2). All sizes are in rpx unless marked "px" (real device-independent pixels).
- **Position** is written as a Roblox `UDim2` inside the safe frame: `{xScale, xOffset},{yScale, yOffset}`. Scale is the share of the safe frame (0.5 = 50%); offset is in rpx.
- **Anchor** is the element's `AnchorPoint` (0,0 = top left, 1,1 = bottom right).
- Values marked **(tune)** are first guesses.
- Text is never written into a screen spec as a literal. Specs name a text key (for example `bank.title`); the English text is in section 14.
- Images are named `UI_<Screen>_<Name>`; all are listed in section 13.

## 1. Principles and layout grid

### 1.1 Principles

| # | Principle | Rule | How to test it |
|---|---|---|---|
| P1 | One thumb | Steering needs one thumb anywhere on the screen. Every in-run button sits in a thumb-reach zone (1.4). Nothing in a run needs two-finger gestures. | Play a full run holding the phone in two hands without shifting grip. |
| P2 | Glanceable | Every in-run element can be read in under 0.5 s: a shape, a colour, a number of at most 5 characters. | Flash a screenshot for 0.5 s; the tester names tier, mass and nearest threat. |
| P3 | Almost no text | The run HUD has no words, only numbers and icons. Words appear only in moments that last under 3 s and in menus. | Count words on the run HUD: zero. |
| P4 | Nothing covers the creature | No persistent element enters the keep-clear box (1.4). Moment overlays stay above it. Only screens shown after the run has ended (gulped, bank summary) may cover the centre. | Overlay the keep-clear box on screenshots of every in-run state. |
| P5 | Feedback within 100 ms | Every tap gives a visual change and a sound on the press (not the release), from the client, without waiting for the server. Slow results show a pending state within 100 ms. | Film at 240 fps; count frames from touch to first change. |
| P6 | Does not look like Roblox | All default interface is off (section 17). No avatar pictures, no default fonts, buttons, sounds or cursors. | No default Roblox element is visible except the Roblox menu button in the top bar. |
| P7 | Safe to open | Full-screen menus open only in safe water (own cove, another cove, Nursery Lagoon). In open water only side panels and popovers that leave the creature visible may open. | Try every dock key in open water: nothing opens. |
| P8 | Honest selling | Section 9 rules apply to every purchase prompt. | Section 16 offers checklist. |

### 1.2 Reference canvas and scaling

- **Orientation:** landscape only. Set `StarterGui.ScreenOrientation = LandscapeSensor` in the place settings, and the client sets it again on `PlayerGui` (chapter 15).
- **Reference canvas:** 1280 × 720 rpx (16:9 phone in landscape).
- **One scale factor per ScreenGui** (a `UIScale` on the root frame). No `TextScaled`, no per-element scaling.

```
heightScale = (viewportHeight / 720) x deviceFactor x interfaceSize
widthScale  = safeFrameWidth / 1280
scale       = clamp( min(heightScale, widthScale), 0.40, 2.60 )
```

`safeFrameWidth` is the width of the device safe area after the TV margins (5% of the screen on each side, TV only) and the ultrawide cap (chapter 15), and before the 16 and 28 rpx margins of 1.3, which are in rpx and so come after the scale.

`interfaceSize` is the Interface size setting [L] (6.7): 0.8 to 1.3, default 1.0. The width term guarantees that 1280 rpx always fit, even in a narrow desktop window.

Chapter 15, section 2.2 owns the screen classes, the order of the detection tests and the device factors. The summary below is for reading this chapter; if it differs from chapter 15, chapter 15 wins.

| Screen class | Scope | How it is detected (first match wins) | deviceFactor (tune) | Example viewport height | scale | An 88 rpx target becomes |
|---|---|---|---|---|---|---|
| TV | [P1] | `GuiService.ViewportDisplaySize == Large` | 0.80 | 1080 px | 1.20 | 106 px |
| Handheld | [L] | `ViewportDisplaySize == Small`, a gamepad connected, short side 700 px or more | 0.90 | 1080 px | 1.35 | 119 px |
| Phone | [MVP] | Touch, short side under 500 px | 1.00 | 375 px | 0.52 | 46 px (about 7 mm) |
| Tablet | [MVP] | Touch, no keyboard and mouse | 0.65 | 768 px | 0.69 | 61 px |
| Desktop | [MVP] | Anything else | 0.60 | 1080 px | 0.90 | 79 px |

- The screen class is worked out at join and again whenever the viewport size changes (after 250 ms with no further change). It does not change when the player changes input: plugging a gamepad into a PC changes hints and controls, not scale.
- Roblox reports phone screens in device-independent pixels, so a phone viewport is roughly 320 to 430 px tall (check on a real device before tuning).
- **Width:** nothing stretches. Elements are pinned to an edge or to the centre; extra width on long phones (19.5:9 gives about 1560 rpx) becomes empty space between them. The layout must work from 1280 rpx wide (16:9) to 1720 rpx wide (21:9).
- **Image export:** every image is drawn at 2 × its rpx size (a 96 rpx icon is a 192 px file) so it stays sharp on phones with 3 × pixel density. No single image or atlas is larger than 1024 × 1024 px.

### 1.3 Safe areas

| Rule | Value |
|---|---|
| HUD, moments, menus, guide and toast layers | `ScreenGui.ScreenInsets = DeviceSafeInsets` (clear of notches and rounded corners, but allowed beside the Roblox top bar buttons) |
| Scrims and full-screen backgrounds | A separate ScreenGui with `ScreenInsets = None` so they reach the physical edges |
| Safe frame margins inside the device safe area | 16 rpx top, 16 rpx left and right, 28 rpx bottom |
| Bottom edge | Tappable elements keep at least 40 rpx from the bottom of the device safe area (the iOS home bar is not covered by the device inset, per a Roblox bug report) |
| **Roblox keep-out (top left)** | The Roblox menu button cannot be removed. Roblox text chat is switched off in the MVP (canon 14), so there is no chat button; if chat ships at [L] its button appears beside the menu button and the same rule covers it. The Hud is laid out outside `GuiService.TopbarInset`, read at run time: no element enters the area it reserves, whether or not anything is drawn there. In the Sprint 0 spike (F11) it reserved x 0 to 120 px, y 0 to 58 px with every core GUI element turned off, even where Mac Studio drew no menu button. Fallback when the value is not ready: a box 200 px wide × 58 px tall at the top left of the device safe area (about 385 × 112 rpx on a phone) (tune). |
| Roblox chat window [L] | Off in the MVP: nothing is reserved for it. If chat ships at [L], the window opens below the top bar on the left, and only display-only elements may sit in the left column from 12% to 45% of the height. It is never shown on a TV (chapter 15). |
| If the mass bar would overlap the keep-out | Shrink the mass bar from 440 to 360 rpx wide, then shift it right until it clears by 16 rpx |

### 1.4 Thumb-reach zones (phone held in landscape, two hands)

Measured from each bottom corner of the safe frame.

| Zone | Distance from a bottom corner | Use |
|---|---|---|
| A, easy | 0 to 340 rpx | Dash, ability, claim, primary menu buttons |
| B, stretch | 340 to 520 rpx | Emote button, trait slots, dock buttons, secondary buttons |
| C, no reach | Everything else | Display only. The only tappable items allowed here are rare ones: settings, tide clock, close buttons, toasts. |

**Keep-clear box:** x from 28% to 72% and y from 34% to 76% of the safe frame. The creature sits at its centre. No persistent element may enter it.

```
+--------------------------------------------------------------------------+
| Roblox  |            C: display only (bars, clock, banners)              |
| keep-out|                                                                |
|---------+           +------------------------------+                     |
|                     |                              |                     |
|  B                  |      keep-clear box          |                  B  |
|     . . .           |      (the creature)          |           . . .     |
|  .        .         |                              |         .        .  |
| .   A      .        +------------------------------+        .      A   . |
| .  (steer) .           B: trait slots, dock                 . (dash,   . |
|            .                                                .  ability)  |
+--------------------------------------------------------------------------+
```

### 1.5 Touch targets, spacing and type sizes

| Item | Value |
|---|---|
| Minimum touch target (phone and tablet) | 88 × 88 rpx hit area, even when the visible icon is smaller |
| Minimum gap between two hit areas | 16 rpx |
| Minimum mouse target (desktop) | 48 × 48 rpx |
| Spacing unit | 8 rpx; all margins and gaps are multiples of 8 (4 allowed inside chips) |
| Text sizes | Small 22 (the floor), Body 24, Number 28, Title 40, Hero 64 |
| Room for translation | Every text box fits a string 40% longer than the English one without clipping; if it still does not fit, the text shrinks to no less than 22 and then wraps to a second line |
| Text over the 3D world | Always on a chip or panel, or with a 2 rpx dark stroke |

### 1.6 Layers

All ScreenGuis: `ResetOnSpawn = false`, `ZIndexBehavior = Sibling`.

| ScreenGui | DisplayOrder | Holds |
|---|---|---|
| `GulpWorld` | 5 | Screen-space markers that track world positions (threats, home, trait prey, mass pops). `ScreenInsets = None`, so a marker sits exactly over its world position; edge arrows are clamped into the safe frame by code |
| `GulpHUD` | 10 | Run HUD, cove HUD, visit HUD, decoration HUD |
| `GulpMoments` | 20 | Moment slot, gulped panel, bank summary, cove-full choice |
| `GulpMenus` | 30 | Dock menus, settings, popovers, confirm dialog |
| `GulpGuide` | 40 | First-time prompts (section 7) |
| `GulpToasts` | 50 | Toast stack |
| `GulpSystem` | 100 | Loading, reconnect, scrims (`ScreenInsets = None`) |

## 2. Screen map

### 2.1 List of screens and overlays

| ID | Screen or overlay | Tag | Kind | Covers the creature? | Where it may open |
|---|---|---|---|---|---|
| S01 | Loading | [MVP] | System | Yes | On join and on teleport |
| S02 | Reconnect | [MVP] | System | Yes | Any time |
| S03 | Run HUD | [MVP] | HUD | No | Open water, Nursery |
| S04 | Trait popover (shed) | [MVP] | Popover | No | Run |
| S05 | Tide popover (next tide; the tide board for Tide Watcher owners [L]) | [MVP] | Popover | No | Run, cove |
| S06 | Emote wheel | [L] | Popover | No | Run, cove, visit |
| S07 | Tier-up | [MVP] | Moment | No | Run |
| S08 | Trait gained | [MVP] | Moment | No | Run |
| S09 | Event banners (warning, start, end) | [MVP] | Moment | No | Run, cove |
| S10 | Toasts | [MVP] | Toast | No | Any time |
| S11 | Gulped panel (with the revive offer; Trait Lock offer [L]) | [MVP] | Panel | Yes (run is over) | After being gulped |
| S12 | Bank summary | [MVP] | Panel | Yes (safe) | On banking |
| S13 | Cove-full choice | [MVP] | Panel | Yes (safe) | Inside the bank summary; alone, on join, when a specimen is pending (4.6) |
| S14 | Cove HUD | [MVP] | HUD | No | Own cove |
| S15 | Offline claim | [MVP] | Dialog | Yes (safe) | Own cove, on arrival |
| S16 | Specimen grid | [MVP] | Menu | Yes (safe) | Own cove, visit (read only) |
| S17 | Specimen detail | [MVP] | Menu | Yes (safe) | Own cove, visit (read only) |
| S18 | Slot upgrade | [MVP] | Dialog | Yes (safe) | Own cove |
| S19 | Confirm dialog | [MVP] | Dialog | Yes (safe) | Any menu |
| S20 | Decoration mode | [L] | HUD | No | Own cove |
| S21 | Visit HUD | [L] | HUD | No | Another player's cove |
| S22 | Species select | [MVP] | Menu | Yes (safe) | Own cove |
| S23 | Codex | [MVP] | Menu | Yes (safe) | Own cove |
| S24 | Codex entry page | [MVP] | Menu | Yes (safe) | From the Codex, from a toast |
| S25 | Daily: Goals tab | [MVP] | Menu | Yes (safe) | Own cove |
| S26 | Daily: Gifts tab (login streak) | [L] | Menu | Yes (safe) | Own cove |
| S27 | Shop | [MVP] | Menu | Yes (safe) | Own cove |
| S28 | Purchase result | [MVP] | Moment | Yes (safe) | After a purchase |
| S29 | Ranks (leaderboards) | [L] | Menu | Yes (safe) | Own cove |
| S30 | Reef Rank track | [L] | Menu | Yes (safe) | Own cove |
| S31 | Settings | [MVP] | Side panel | No | Any time |
| S32 | Private reef info | [L] | Dialog | Yes (safe) | From settings, in safe water |
| S33 | Guide layer (first-time prompts) | [MVP] | Overlay | No | Driven by chapter 04 |
| S34 | Starter Pack card | [L] | Offer card | No | Own cove |
| S35 | Species unlocked | [MVP] | Moment | Yes (safe) | Species select |
| S36 | Continue your run (a suspended run, on rejoin) | [MVP] | Dialog | Yes (safe: the creature has not appeared yet) | On join, after loading (8.3) |

36 screens and overlays: 28 [MVP], 8 [L].

### 2.2 Flow

There is no title screen and no main menu. The cove HUD is the hub.

```
JOIN
 |
 v
[S01 Loading] --first session--> Nursery Lagoon: [S03 Run HUD] + [S33 Guide] (chapter 04 script)
      |
      +--suspended run (left mid-run, back in time)--> [S36 Continue your run]
      |        |-- Continue your run --> [S03 Run HUD], where the run stopped
      |        \-- Start fresh --> own cove, as a returning player (next line)
      |
      +--returning player--> own cove: ([S13 Cove-full choice], only if a specimen is pending)
                             -> [S15 Offline claim] -> [S26 Gifts, once a day] -> [S14 Cove HUD]

[S14 Cove HUD]
 |-- dock: Creatures -> [S22 Species select] -> [S19 Confirm] -> [S35 Species unlocked]
 |                                  \-> Shark Pup pass -> Roblox purchase prompt -> [S28]
 |-- dock: Codex ----> [S23 Codex] -> [S24 Entry page]
 |-- dock: Daily ----> [S25 Goals] <-tab-> [S26 Gifts]
 |-- dock: Shop -----> [S27 Shop] -> Roblox purchase prompt -> [S28 Purchase result]
 |-- dock: Ranks ----> [S29 Ranks]
 |-- dock: Decorate -> [S20 Decoration mode] -> Done -> [S14]
 |-- slots chip -----> [S16 Specimen grid] -> [S17 Specimen detail] -> [S19 Confirm release]
 |                            \-> Add a slot -> [S18 Slot upgrade] -> [S19 Confirm]
 |-- rank badge -----> [S30 Reef Rank track]
 |-- tide clock -----> [S05 Tide popover] -> Call the Tide -> Roblox purchase prompt
 |-- Species Wall ---> [S22 Species select], on the next species' card
 |-- gear -----------> [S31 Settings] -> [S32 Private reef info]
 |-- offer card -----> [S34 Starter Pack card] -> Roblox purchase prompt -> [S28]
 \-- swim out of the cove mouth --> [S03 Run HUD]

[S03 Run HUD]
 |-- overlays that never block: [S07 Tier-up] [S08 Trait gained] [S09 Event banners] [S10 Toasts]
 |-- popovers: [S04 Trait popover] [S05 Tide popover] [S06 Emote wheel] [S31 Settings]
 |-- swim into another cove --> [S21 Visit HUD] -> [S16]/[S17] read only -> swim out -> [S03]
 |-- swim into own cove ------> [S12 Bank summary] -> ([S13 Cove-full choice]) -> [S14 Cove HUD]
 \-- gulped -------------------> [S11 Gulped panel] -- Revive --> [S03 Run HUD]
                                        \-- Keep traits [L] (Trait Lock) --> stays on the panel
                                        \-- Swim again --> [S14 Cove HUD] (as a Fry)

ANY TIME: [S02 Reconnect], [S10 Toasts]
```

**Back and close rules**

- Every menu, dialog and popover has one close control in the same place (top right of the panel, 88 rpx hit area). Tapping the scrim outside the panel also closes it. Esc is taken by the Roblox menu, so on desktop the close key is **Backspace**; on a gamepad [L] it is **B**.
- Menus do not stack more than two deep (menu, then dialog). Closing a dialog returns to the menu under it; closing a menu returns to the cove HUD.
- The gulped panel, bank summary, cove-full choice, offline claim and the Continue your run card (S36) have no close control; each ends with a button that moves the player on.
- If the player's safe state ends while a menu is open (for example the cove owner leaves during a visit), the menu closes in 150 ms.

## 3. The in-run HUD (S03)

### 3.1 Wireframe: phone landscape (1280 × 720 rpx)

```
+------------------------------------------------------------------------------------------+
| [R]                  (T4)[=========== 86 ====   >114 ](T5)           (lag) (TIDE) [gear] |
|  keep-out                     ( o 387  x1.5  <fish> )                       0:45         |
|                                                                                          |
| [#1 Mako   412 ]         [ moment slot: banners, tier-up ]              [ toast        ] |
|                                                                         [ toast        ] |
|<<                                                                                        |
| threat              . . . . . . . . . . . . . . . . . . . .                              |
| arrow               .                                     .                    (home)    |
|                     .          keep-clear box             .                     120 m    |
|                     .           (the creature)            .                              |
|                     .                                     .                   (emote)    |
|    ( drag  )        . . . . . . . . . . . . . . . . . . . .                              |
|    ( ring  )                    [st][st]                                                 |
|                         (safe) (tr1) (tr2) (tr3)                    (ABILITY)  ( DASH )  |
+------------------------------------------------------------------------------------------+
```

### 3.2 Wireframe: PC (1920 × 1080, scale 0.90)

Chapter 15, section 3.3 owns the PC layout and its key map. This wireframe shows how the shared components rearrange; the `[T]` emote tile is [L].

```
+------------------------------------------------------------------------------------------+
| [R]                  (T4)[=========== 86 ====   >114 ](T5)           (lag) (TIDE) [gear] |
|                               ( o 387  x1.5  <fish> )                       0:45   [P]   |
| [#1 Mako    412 ]                                                            [C]         |
| [#2 Pip     388 ]        [ moment slot: banners, tier-up ]              [ toast        ] |
| [#3 You     286 ]                                                                        |
| [#4 Lumo    120 ]                                                                        |
| [#5 Kai      64 ]                                                              (home)    |
|   [Tab]                               .                                         120 m    |
|                                    reticle                                               |
|                                                                                          |
|                                 [st][st]                               (ABIL)  (DASH)    |
|                          (safe) (tr1) (tr2) (tr3)             [T]       [E]    [Space]   |
|                                  [1]   [2]   [3]                                         |
+------------------------------------------------------------------------------------------+
```

### 3.3 Element table (phone layout)

Each element has an ID that chapter 04 and the code use to show, hide or point at it: `HUD.setVisible(id, bool)`.

| ID | Tag | Anchor | Position | Size (rpx) | Shows |
|---|---|---|---|---|---|
| `HUD.MassBar` | [MVP] | 0.5, 0 | `{0.5, 0},{0, 12}` | 440 × 64 | Tier badge, mass bar, mass number, next-tier goal |
| `HUD.BankChip` | [MVP] | 0.5, 0 | `{0.5, 0},{0, 82}` | 168 to 240 × 40 | Pearls this run would bank now, multipliers, specimen light |
| `HUD.MomentSlot` | [MVP] | 0.5, 0 | `{0.5, 0},{0, 130}` | up to 480 × 112 | One moment at a time: event banner, tier-up, trait gained, zone name |
| `HUD.Biggest` | [MVP] | 0, 0 | `{0, 16},{0, 124}` | 208 × 44 (one row) | Server "biggest now" strip |
| `HUD.TideClock` | [MVP] | 1, 0 | `{1, -112},{0, 12}` | 80 × 104 | Ring countdown, next event icon, time |
| `HUD.Settings` | [MVP] | 1, 0 | `{1, -12},{0, 8}` | 88 hit, 56 visible | Gear button |
| `HUD.Lag` | [MVP] | 1, 0 | `{1, -204},{0, 32}` | 40 × 40 | Weak-connection icon, only when needed |
| `HUD.Toasts` | [MVP] | 1, 0 | `{1, -16},{0, 124}` | 320 × 64 each, 2 max | Toast stack |
| `HUD.Traits` | [MVP] | 0.5, 1 | `{0.5, 0},{1, -28}` | 272 × 80 | Three trait slots, 80 each, 16 gap |
| `HUD.Status` | [MVP] | 0.5, 1 | `{0.5, 0},{1, -120}` | up to 216 × 48 | Up to four status icons |
| `HUD.SafeBadge` | [MVP] | 0.5, 1 | `{0.5, -176},{1, -40}` | 56 × 56 | "Nobody can eat you here" badge |
| `HUD.Dash` | [MVP] | 1, 1 | `{1, -40},{1, -44}` | 136 × 136 | Dash button |
| `HUD.Ability` | [MVP] | 1, 1 | `{1, -196},{1, -36}` | 108 × 108 | Ability button |
| `HUD.Emote` | [L] | 1, 1 | `{1, -64},{1, -200}` | 88 hit, 72 visible | Opens the emote wheel |
| `HUD.TideMarker` | [L] | Edge | Clamped 72 rpx inside | 56 | Tide Watcher: direction to the tide's site (3.13) |
| `HUD.WildTag` | [L] | World | Above a wild creature | Text 22 + leaf 28 | "Wild" name tag (3.16) |
| `HUD.Threats` | [MVP] | Edge | Clamped 56 rpx inside the safe frame | 56 to 88 | Arrows toward off-screen creatures that can eat you |
| `HUD.TraitMarkers` | [MVP] | Edge | Clamped 40 rpx inside | 44 | Trait prey markers (Glow trait only) |
| `HUD.Home` | [MVP] | Edge or world | Clamped 72 rpx inside, or above the cove mouth | 72 + label | Home direction and distance |
| `HUD.DragRing` | [MVP] | At the touch | Under the steering thumb | Ring 168, knob 72 | Steering feedback |
| `HUD.MassPops` | [MVP] | World | At the creature's mouth | Text 28 | "+4" numbers on each bite |
| `HUD.Reticle` | [MVP] | 0.5, 0.5 | `{0.5, 0},{0.5, 0}` | 32 × 32 | Desktop only: aim dot |
| `HUD.Outlines` | [MVP] | World | On creatures | n/a | Edible and danger outlines (3.11) |

**Layout switches**

Chapter 15 owns the layout of each platform (sections 3.1 to 3.7). This table lists only what each switch does to the shared components.

| Switch | Tag | Change |
|---|---|---|
| Left-handed (settings) | [L] | `HUD.Dash`, `HUD.Ability`, `HUD.Emote` mirror to the bottom left (anchor 0,1 with the same offsets, sign flipped). `HUD.Biggest` stays. |
| Two-thumb scheme (settings) | [L] | `HUD.DragRing` becomes a fixed move stick at anchor 0,1 `{0, 56},{1, -56}`. Dragging on the right side of the screen (outside buttons) turns the camera; chapter 15, section 3.1 owns the drag area and speed. |
| Tablet | [MVP] | Dash, ability and emote move 24 rpx further from the edges. |
| Desktop | [MVP] | Dash and ability become hint tiles 80 × 96 (icon 64 with cooldown, key cap under it) at anchor 1,1 `{1, -32},{1, -32}` and `{1, -128},{1, -32}`. `HUD.Biggest` shows 5 rows. Key caps appear under trait slots. |
| Gamepad (PC and handheld PC) | [L] | Same as desktop with gamepad glyphs instead of key caps; the reticle and the cursor are hidden. |
| TV (Xbox, PlayStation) | [P1] | The gamepad HUD at the TV scale with 5% margins on every side. Chapter 15, sections 3.5 and 3.6. |

### 3.4 Mass and tier bar (`HUD.MassBar`) [MVP]

```
(T4) [#################--------------  86            >114 ] (T5)
 ^badge 64      bar 300 x 28, fill        ^mass   ^to go     ^next badge 44, dimmed
```

| Part | Detail |
|---|---|
| Current tier badge | `UI_Icon_Tier1` to `UI_Icon_Tier7`, 64 rpx, left end |
| Bar | Fill runs from the current tier's mass threshold (0%) to the next tier's (100%) |
| Mass number | Left inside the bar, Number 28, whole numbers; above 9,999 shown as 12.4K |
| Next-tier goal | Right inside the bar: a small arrow and the mass still needed. Then the next tier's badge at 44 rpx, 50% opacity. |
| Tap (phone) or hover (desktop) | Shows `hud.next_tier` in a chip under the bar for 2 s |

| State | Behaviour |
|---|---|
| Normal | As above |
| Gain | Fill tweens to the new value in 150 ms; number pops to 1.15 × for 120 ms |
| Near | Fill at 85% or more: the next badge pulses at 1 Hz and rises to 100% opacity |
| Tier-up | Bar flashes white for 80 ms, the next badge slides left to become the current badge (300 ms), a new next badge fades in; triggers S07 |
| Loss | Mass lost (hook, vent, revive at 70%): fill flashes the danger colour, bar shakes 6 rpx for 200 ms. If the tier drops, badges swap back with no moment overlay. |
| Max | Tier 7: fill is full and gold, the next badge is replaced by `UI_HUD_Crown`, the goal reads `common.max`; the mass number keeps counting |
| Hidden | Fades out in 150 ms when chapter 04 hides it |

### 3.5 Pearl preview (`HUD.BankChip`) [MVP]

| Part | Detail |
|---|---|
| Pearl icon and number | Pearls the player would receive by banking right now, with every multiplier applied (value from chapter 02 rules) |
| Multiplier tags | One small tag per active multiplier: trait icon with "×1.5" for Crystal, pass icon with "×2" for Deep Pockets |
| Specimen light | A small fish icon (`UI_HUD_SpecimenLight`): dim at tier 1, lit from tier 2 (banking would create a specimen) |

| State | Behaviour |
|---|---|
| Normal | Number rolls to the new value in 200 ms on each bite |
| Best | The preview is higher than the player's best banked run: the chip turns gold and the home marker gains a gold rim |
| Nursery first run | Hidden until chapter 04 shows it |

### 3.6 Trait slots (`HUD.Traits`) and the shed action [MVP]

Three slots in a row. Each slot is an 80 rpx circle with an 88 rpx hit area.

```
   o o o . .          <- 5 progress pips on an arc above the slot (4 with Keen Nose)
  ( trait icon )      <- 56 rpx icon inside a rarity frame
```

**What a slot shows:** owned traits fill slots from the left in the order gained. Each free slot then shows the in-progress trait with the most pips (ties: the most recent). Progress on other traits is kept but not shown.

| State | Look and behaviour |
|---|---|
| Empty | `UI_HUD_TraitSlotEmpty` (dashed ring), no pips |
| In progress | Trait icon at 45% opacity, no rarity frame, pips lit for prey eaten. Each new pip pops to 1.4 × (180 ms) with `SFX_UI_TraitPip`. |
| Owned | Trait icon in its rarity frame (`UI_Common_RarityCommon` and so on), pips hidden |
| Just gained | Slot flashes for 600 ms; triggers S08 |
| Used up | Plated after it has saved the player: the icon swaps to `UI_Icon_TraitPlatedCracked` |
| Traits full | All three owned and the player eats trait prey: the row shakes 8 rpx for 250 ms and a chip with `hud.traits_full` shows for 2 s (first 3 times per session only) |
| Locked | Trait Lock was bought on the gulped panel after the last run [L]: this run starts with that run's traits already Owned, and a small `UI_HUD_TraitLockTag` sits on the row's left end |

**Trait popover (S04) and shed.** Canon 9: a trait is shed by tapping its slot and then holding for 0.6 seconds. The tap opens a popover and the hold is on its Shed button.

```
        +------------------------------+
        | (icon) Spiny        Uncommon |
        | Harder to eat                |
        |        [ (shed)  Shed ]      |   <- hold 600 ms; a ring fills around the button
        +--------------v---------------+
                     (tr2)
```

| Item | Detail |
|---|---|
| Open | Tap an owned or in-progress slot. Popover 320 × 168, anchored 12 rpx above the slot. It is the one in-run element allowed to overlap the lower part of the keep-clear box, because the player opened it and it closes itself. |
| Content | Trait icon, trait name, rarity name, effect line. In-progress slots show the pips and `hud.trait_progress` instead of the shed button. |
| Shed | Owned slots only. Hold the button for 600 ms; `UI_Common_RingHalf` fills around it. Releasing early cancels and drains the ring in 150 ms. With "Tap instead of hold" on (section 12): tap Shed, then tap `common.yes` within 3 s. |
| After shedding | Slot plays a 300 ms drop-away, `SFX_UI_TraitShed`, becomes Empty; popover closes |
| Close | Tap outside, tap the slot again, or 4 s with no input |
| Input while open | Steering, dash and ability keep working. The popover never covers the dash or ability button. |

### 3.7 Dash button (`HUD.Dash`) [MVP]

| State | Look and behaviour |
|---|---|
| Ready | `UI_HUD_DashButton` normal, full colour |
| Pressed | Pressed sprite, scale 0.94 in 60 ms; `SFX_UI_Dash` and a light haptic on the press |
| Cooldown | A dark wedge (`UI_HUD_CooldownHalf`, two halves) sweeps clockwise from full to empty over the cooldown (2.5 s; 2.0 s for Minnow). No number: the cooldown is under 3 s. |
| Ready again | Ring pulse (`UI_Common_RingPulse`, 250 ms) and `SFX_UI_DashReady` at low volume |
| Disabled | Stunned or tucked in Shell: 40% opacity, taps play `SFX_UI_Locked` |
| Queued | A press in the last 250 ms of the cooldown is remembered and fires when ready (chapter 02, section 2.5 owns the window) |

### 3.8 Ability button (`HUD.Ability`) [MVP]

The button shows the species' ability icon (`UI_Icon_AbilityDart` and so on) on `UI_HUD_AbilityButton`.

| State | Look and behaviour |
|---|---|
| Ready | Full colour |
| Pressed | Pressed sprite, scale 0.94; `SFX_UI_Ability` |
| Active | While a pressed ability lasts (Puff 2 s, Shell 2.5 s) a bright ring drains around the button |
| Cooldown | Dark wedge sweep plus the seconds left as a whole number (Number 28) in the centre |
| Ready again | Ring pulse and `SFX_UI_AbilityReady` |
| Disabled | 40% opacity; taps play `SFX_UI_Locked` |
| Passive | Minnow (Dart), Eel (Slip) and Shark Pup (Rampage) have nothing to press (canon 7): the button is replaced by `UI_HUD_AbilityPassive`, a 72 rpx badge that does not react to taps. Shark Pup's badge shows three pips for prey eaten in the 4 s window, and a bright ring drains around the badge for the 5 s that Rampage runs. |

### 3.9 Threat indicators (`HUD.Threats`) [MVP]

An arrow on the screen edge points at each off-screen creature that can eat the player right now (rules from chapter 02, including Spiny and Puff). Distances are first guesses for chapter 02 to confirm.

| Distance to threat (studs) (tune) | Arrow size | Opacity | Pulse | Extra |
|---|---|---|---|---|
| 90 to 60 | 56 rpx | 50% | 1 Hz | None |
| 60 to 30 | 72 rpx | 80% | 2 Hz | None |
| Under 30 | 88 rpx | 100% | 4 Hz | Red edge vignette (`UI_HUD_ThreatVignette`, 35% opacity), two short haptic pulses, `SFX_UI_ThreatNear` (at most once per threat every 5 s) |

- Each arrow carries the threat's tier badge at 32 rpx. Predators show their icon instead (`UI_Icon_PredBarracuda` and so on).
- At most three arrows, nearest first. Old Scar always gets one inside 150 studs and uses `UI_HUD_ThreatArrowBoss`.
- A gull that has targeted the player shows an arrow on the top edge for the 1.5 s before it dives.
- A threat that is on screen has no arrow (its red outline does the job) but still triggers the vignette under 30 studs.
- Arrows slide along the edge and never overlap the dash, ability or emote buttons; they stop at the button's edge.
- Hidden in safe water.

### 3.10 Trait prey markers (`HUD.TraitMarkers`) [MVP]

Only while the player owns Glow: trait prey within 60 studs and off screen show as a 44 rpx marker (`UI_HUD_TraitMarker`, tinted by rarity) with the prey's trait icon at 28 rpx. At most four markers.

### 3.11 Edible and danger outlines (`HUD.Outlines`): what gets one [MVP]

Outlines are not an interface effect. They are mesh shells drawn by the world on each creature (canon 5.2; chapter 06, section 13.2), coloured per viewer on the client. Roblox's `Highlight` is not used anywhere. Chapter 06 owns the colours and the shells; this chapter owns only which creatures get one, and the ID `HUD.Outlines`, which chapter 04 uses to show or hide them.

| Target | Outline | Rule |
|---|---|---|
| Prey, players and wild creatures [L] the player can eat now. Also the two predators that can be eaten: a Barracuda, and a Grouper [L], when the player is at least one tier above it (canon 5.2). | Edible (green) | Within 120 studs (tune). The Gull, the Moray and Old Scar can never be eaten and never show green. |
| Players, wild creatures [L] and predators that can eat the player now | Danger (red, pulsing to white twice a second and 1.5 × thicker, in every mode) | Always when on screen, at any distance |
| Plankton and hook bait | None | Always (canon 5.2) |
| Everything else | None | Same-tier players, tier 1 players, anything in safe water |
| The player's own creature | None | |

- Amber is never an outline on a creature: it is reserved for home (the player's cove and the home marker, 3.12).
- Outlines update within 100 ms of a tier change on either side.
- A creature under Camo (still for 1.5 s) or inside an ink cloud has no outline.
- Colour-blind outline mode (section 12) swaps green and red for yellow and hot pink (canon 5.2) and changes nothing else about the shells. As an extra cue that this chapter owns, it adds a screen-space marker above each creature: `UI_HUD_MarkDanger` (40 rpx) and `UI_HUD_MarkEdible` (32 rpx, players and trait prey only).

### 3.12 Home marker (`HUD.Home`) [MVP]

| Item | Detail |
|---|---|
| Look | `UI_HUD_HomeMarker` (72 rpx) with a small pointer (`UI_HUD_HomePointer`) that orbits it and points home; distance under it using `hud.home_dist` (Small 22) |
| Off screen | Clamped to an ellipse 72 rpx inside the safe frame; slides around the dash and ability buttons |
| On screen | Floats 40 rpx above the player's cove mouth; the pointer hides |
| Distance | Studs shown as metres, rounded to 5, updated 5 times a second |
| Best state | Gold rim when the Pearl preview beats the player's best run (3.5) |
| Hidden | Inside the player's own cove; and until chapter 04 shows it in the first run |

### 3.13 Tide clock (`HUD.TideClock`) and event warning [MVP]

| State | Look and behaviour |
|---|---|
| Waiting (more than 60 s to the next event) | Ring (`UI_HUD_TideClockFrame` plus `UI_Common_RingHalf`) drains clockwise toward the start. Next event's icon at 48 rpx, 70% opacity. Time to start below, m:ss. |
| Warning (60 s or less) | Ring takes the event colour and pulses at 1 Hz. S09 warning banner shows in the moment slot. `SFX_UI_EventWarn` once. |
| Running (4 minutes) | Icon at full colour with a glow; ring shows the time left in the event; time below counts down |
| Tide called [L] | The player holds a Call the Tide token that has not started yet: a small `UI_HUD_TideToken` tag sits on the clock's lower edge and the line under the time reads `tide.called` (canon 10; chapter 02, section 14.7) |
| Tap | Opens S05 Tide popover |

**Tide popover (S05).** A popover 360 wide under the clock. Closes on a tap outside or after 6 s.

| Part | Tag | Who sees it | Detail |
|---|---|---|---|
| Next tide | [MVP] | Everyone | One row: event icon, event name, start time in the player's local clock. A running tide is shown instead, marked with `tide.now`. Height 132. |
| Tide board | [L] | Tide Watcher owners | The row becomes three rows under `tide.board`: the next three tides. Height 300. |
| Tide marker | [L] | Tide Watcher owners | During a tide and its 60 s warning, `HUD.TideMarker` (`UI_HUD_TideMarker`, 56 rpx with the event icon at 32) sits on the screen edge and points to the event site, clamped like the home marker and never over a button. A tide with no single site (Feeding Frenzy) shows none. Chapter 02 names the site of each tide. |
| Tide Watcher row | [L] | Players without the pass | One line `tide.board_locked` with the pass icon; tapping it opens the pass card in the shop (offer O14, section 9). Never shown in a run. |
| Call the Tide | [L] | Everyone | Button `product.call_tide`, offer O9 (section 9). It can be bought whatever the tide clock shows. If the token would be held (a tide or its warning is running, or the next one is too close), the button says so before the purchase with the line `tide.will_wait`. A player can hold up to three tokens (chapter 02, section 14.7); one starts at a time, when no tide is running. While a token has not started, the held-token chip (`UI_HUD_TideToken`, `tide.called_wait` or `tide.called_soon`) shows the number held beside the button; at three tokens the chip replaces the button. |

The pass adds no sound, bell or notification for tides: it shows more of the schedule and where to go, nothing else (canon 12).

### 3.14 Server "biggest now" strip (`HUD.Biggest`) [MVP]

| Item | Detail |
|---|---|
| Row | Rank number (crown for 1), species icon 32, tier badge 28, display name cut to 10 characters, mass. Row height 36 rpx, text Small 22. No avatar pictures. Wild creatures [L] never appear in the strip. |
| Phone | One row: the server's biggest creature. If that is the player, the row uses the self highlight (`UI_HUD_RowSelf`). Tap to show the top 3 plus the player's own row for 5 s. |
| Desktop; gamepad [L]; TV [P1] | Top 5 always. Hold Tab (or press the left stick) for all 24. |
| Update | Once a second; rows that change place slide in 200 ms |
| Tier 7 | A player reaching Leviathan sends a toast to everyone (`toast.leviathan`) |

### 3.15 Status icons (`HUD.Status`) [MVP]

A centred row of 48 rpx icons, each with a ring that drains over the effect's length. Newest on the right. No text.

| Icon | Tag | When |
|---|---|---|
| `UI_HUD_StatusStun` | [MVP] | Jelly sting, Spark stun |
| `UI_HUD_StatusShield` | [MVP] | 3 s protection after a revive or after continuing a suspended run (8.3); Shell and Puff while active |
| `UI_HUD_StatusHidden` | [MVP] | Inside an ink cloud, Camo active |
| `UI_HUD_StatusSlow` | [L] | Anemone |
| `UI_HUD_StatusBurn` | [L] | Inside a thermal vent |
| `UI_HUD_StatusSpeed` | [L] | Rampage (Shark Pup), current |

### 3.16 Other HUD elements

| Element | Tag | Behaviour |
|---|---|---|
| `HUD.DragRing` | [MVP] | A touch that starts anywhere except on a button shows `UI_HUD_DragRing` at 35% opacity at the touch point (fade in 80 ms) and `UI_HUD_DragKnob` under the thumb, held within 84 rpx of the centre. Dead zone 14 rpx (chapter 02, section 2.1). A touch near an edge nudges the ring fully on screen. A second finger can press dash or ability at the same time. |
| `HUD.SafeBadge` | [MVP] | `UI_HUD_SafeBadge` fades in (200 ms) in the Nursery and inside any cove; on first show per session a chip with `hud.safe` appears for 2 s |
| `HUD.MassPops` | [MVP] | "+4" rises 48 rpx from the mouth and fades over 500 ms. At most 4 at once; fast bites merge into one number. |
| `HUD.Settings` | [MVP] | Opens S31. In open water the panel is the 360 rpx side panel only. |
| `HUD.Lag` | [MVP] | `UI_HUD_Lag` shows when the round trip is over 300 ms for 3 s (tune); hides when it recovers |
| `HUD.Reticle` | [MVP] | Desktop only, 50% opacity; hidden while the cursor is free |
| Zone name | [MVP] | On entering a zone, its name shows in the moment slot for 1.5 s (lowest priority) |
| `HUD.Emote` | [L] | Opens S06 |
| `HUD.WildTag` | [L] | Name tag above every computer-controlled wild creature within 60 studs (tune): `UI_HUD_WildTag` (a leaf, 28 rpx) and `hud.wild` with the species name, Small 22 on a chip. It is never styled like a player's name, and wild creatures get outlines by tier like any creature (3.11). Canon 15: they are clearly labelled as wild. |

### 3.17 Emote wheel (S06) [L]

Six icon emotes, no text. Roblox text chat is off in the MVP and the game never depends on it; from [L] this wheel is the built-in way to signal. Chapter 03, section 14 owns the six emotes, their pictures, and how far away they can be seen.

| Item | Detail |
|---|---|
| Open | Tap `HUD.Emote` (wheel stays for 3 s) or hold it and slide to an emote, then release |
| Layout | Ring 360 rpx (`UI_Emote_Wheel`) centred at anchor 1,1 `{1, -230},{1, -230}`; six slots of 96 rpx on a 132 rpx radius |
| Emotes | In chapter 03's order: `UI_Emote_Hi`, `UI_Emote_ThisWay`, `UI_Emote_LookOut`, `UI_Emote_Thanks`, `UI_Emote_HaHa`, `UI_Emote_Oops` (IDs `em_hi`, `em_this_way`, `em_look_out`, `em_thanks`, `em_ha_ha`, `em_oops`) |
| Result | The icon shows in a bubble (`UI_Emote_WorldBubble`) above the creature for 2.5 s, visible to creatures within the distance chapter 03 sets (120 studs, tune); `SFX_UI_Emote` |
| Limit | One emote every 3 s; the button shows a cooldown wedge |
| Hidden | A player who turns on "Hide emotes" in settings (6.7) sees no emote bubble above other creatures and hears no `SFX_UI_Emote` from them. Their own wheel still works. |
| Desktop and gamepad | Desktop: hold T, move the mouse toward a slot or press 1 to 6, release. Gamepad: hold D-pad down, pick with the right stick, release. There are no direct emote keys (F1 to F6 are not sent by Mac laptops and Chromebooks). Chapter 15, section 3.3 owns the bindings. |

## 4. Moment overlays

### 4.1 Moment slot rules

All in-run moments share `HUD.MomentSlot` (top centre, above the keep-clear box). One shows at a time.

| Priority | Moment | Hold time |
|---|---|---|
| 1 | Tide start timer (last 10 s before a tide) | 10,000 ms |
| 2 | Tier-up (S07) | 1,400 ms (tier 7: 2,200 ms) |
| 3 | Trait gained (S08) | 2,000 ms (Epic, Mythic: 3,000 ms) |
| 4 | Event start | 2,000 ms |
| 5 | Event end, then next event | 2,000 ms + 2,000 ms |
| 6 | Event warning (60 s before) | 5,000 ms |
| 7 | Zone name | 1,500 ms |

A higher priority moment replaces a lower one at once. Up to three wait in a queue; a waiting moment older than 6 s is dropped, except tier-up and trait gained, which always play. Each enters in 180 ms and leaves in 160 ms.

Chapter 04's first-run banners (NIBBLER and GLOW, 1.5 s, 04 §3.3) pass their own hold in place of the times above. Chapter 14, section 4, row 28 lists what is still open between this section, chapter 04 and the keep-clear box.

### 4.2 Tier-up (S07) [MVP]

```
      +------------------------------------------------+
      | (T4 badge 96)   You grew!                      |
      |                 HUNTER                         |
      |                 New food: (icon)(icon)(icon)   |
      +------------------------------------------------+
```

| Item | Detail |
|---|---|
| Size | 460 × 112 on `UI_Common_Ribbon` |
| Content | New tier badge, `moment.tier_up`, tier name (`tier.1` to `tier.7`), `moment.new_food` with up to three icons of prey that just became edible, each with an edible-colour ring |
| Tier 7 | 2,200 ms, `UI_Common_Rays` turning behind the badge, `toast.leviathan` sent to the whole server |
| Feedback | `SFX_UI_TierUp`, two haptic pulses. The creature's own growth effect belongs to chapter 06. |
| Never | Blocks input, or covers the keep-clear box |

### 4.3 Trait gained (S08) [MVP]

Card 420 × 112: trait icon (80 rpx) in its rarity frame, `moment.trait_gained`, trait name, effect line (`trait.<id>.fx`). Epic and Mythic add `UI_Common_Rays`. `SFX_UI_TraitGain`. At the same time the slot plays its Just gained state.

### 4.4 Gulped panel (S11) [MVP]

```
+------------------------------------------------------------------------------------------+
|                                    G U L P E D !                                         |
|                              by (icon) Barracuda (T4)                                    |
|                                                                                          |
|    +---------- what you lost ----------+     +---------- keep going ------------+        |
|    | (T4) Hunter            mass 86    |     | [ (video)  Watch to revive ] [L] |        |
|    | (tr) (tr) (tr)   greyed out       |     | [ (revive) Revive      R$ price ]|        |
|    | Scraps    o +129  Beginner bonus  |     | [ (lock)   Keep traits R$ ]  [L] |        |
|    +-----------------------------------+     +----------------------------------+        |
|                                                                                          |
|                                                                       [ Swim again ]     |
+------------------------------------------------------------------------------------------+
```

| Time after the gulp | What happens |
|---|---|
| 0 ms | Creature pops into bubbles (chapter 06). HUD fades out in 150 ms. `SFX_UI_Gulped`, heavy haptic (200 ms). |
| 0 to 1,000 ms | Camera follows whoever ate the player. Screen edges lose colour over 300 ms. |
| 400 ms | Title art `UI_Moment_GulpedSplat` with `gulped.title` slams in (250 ms). Under it `gulped.by` with the eater's icon, name (player display name or predator name) and tier badge. |
| 900 ms | Panel slides up (220 ms) |
| 1,600 ms | Buttons start accepting input (700 ms guard against taps meant for dash) |

| Part | Detail |
|---|---|
| What you lost | Tier badge and name, final mass, trait icons greyed out. Scraps row: `UI_Moment_Scraps`, Pearls counted up over 400 ms. For the first three deaths on the account the row adds `gulped.beginner`. (The wireframe shows such a death: 86 mass would bank 258 Pearls, and the beginner rate of 50% pays 129; the normal 10% would pay 26.) |
| Order of the "keep going" column | Top to bottom, as chapter 05 (section 9) sets it: Watch to revive [L] when a video is available, then Revive, then Keep traits [L]. The free way back is never below the paid one. |
| Swim again | Primary button, 280 × 96, bottom right (zone A). Always present. Leads to the cove as a Fry in under 3 s. |
| Revive | Offer O1, product `prod_revive`. Secondary size (360 × 80). Icon `UI_Moment_Revive`, `gulped.revive`, `gulped.revive_note`, live Robux price (price from chapter 05). Opens the Roblox purchase prompt. Shown only when all three are true (canon 5.5): the revive has not been used this run; this is not the account's first death; the lost creature had 30 mass or more (tier 3). |
| Watch to revive [L] | Offer O2, placement `ad_revive`. Same size, `UI_Common_Video` icon, `gulped.revive_video`. Shown under the same three conditions as Revive, and only when a rewarded video is available for this player. It counts as the run's one revive. |
| Keep traits [L] | Offer O3, product `prod_trait_lock` (Trait Lock). This panel is the only place it is sold (canon 12). Same size, icon `UI_Moment_TraitLock`, `gulped.keep_traits`, live Robux price. Shown when the lost creature held at least one Uncommon or better trait (chapter 05, section 8.3); it stays when the revive was already used, and is then the only paid button. After the purchase the button becomes a tick, the lost trait icons return to full colour and the row shows `gulped.traits_kept`: the next run starts with those traits. Buying a revive afterwards is still allowed; the traits come back either way. |
| Hidden offers | Nothing is sold during the first two minutes of a new player's first session (canon 12), and the two revive buttons are never shown on an account's first death (canon 5.5). When no button qualifies, the "keep going" column is hidden and the panel centres the left column. |
| No timer | Canon 5.5: the offer has no timer of any kind. It stays until the player presses Swim again. |
| After a revive | Panel closes in 150 ms, the creature returns at 70% mass with its traits, `HUD.Status` shows the 3 s shield, `SFX_UI_Revive`. A cancelled purchase returns to the panel unchanged. |

### 4.5 Bank summary (S12) [MVP]

```
+------------------------------------------------------------------------------------------+
|                              (shell art)   Home safe!                                    |
|  +---------------------- Pearls ------------------------+   +------ specimen -------+    |
|  | Mass                                   86            |   |   [ 3D creature ]     |    |
|  | (trait) Crystal                        x1.5          |   |   (T4) Hunter         |    |
|  | (pass)  Deep Pockets                   x2            |   |   (tr) (tr) (tr)      |    |
|  | ---------------------------------------------        |   |   o 32 an hour        |    |
|  |  o  774                          New best!           |   |   New specimen!       |    |
|  +------------------------------------------------------+   +-----------------------+    |
|  New in Codex (icon)(icon)(icon)     Reef Rank [=====---] 12      goals (g) (g) (g)      |
|                                                                        [ Continue ]      |
+------------------------------------------------------------------------------------------+
```

| Step | Starts at | What happens |
|---|---|---|
| 1 | 0 ms | HUD fades (150 ms). Panel in (220 ms) with `UI_Moment_BankShell` and `bank.title`. `SFX_UI_BankStart`. Continue is visible and active from the start. |
| 2 | 300 ms | Mass row appears |
| 3 | 600 ms | One row per multiplier, 300 ms apart (Crystal, Deep Pockets) |
| 4 | after step 3 | Pearl total counts up over 1,000 ms with `SFX_UI_PearlTick` every 60 ms, ends with `SFX_UI_PearlBurst`. `bank.best` and `UI_Moment_PersonalBest` if it is the player's best run. |
| 5 | +200 ms | Specimen card flips in (400 ms, `SFX_UI_BankCard`): 3D render, tier, traits, Pearls an hour, `bank.new_specimen`. (In the wireframe a Hunter earns 18 an hour; Crystal and two Common traits add 80%, which gives 32.) |
| 6 | +300 ms | Bottom row: Codex entries found this run (150 ms apart, `SFX_UI_CodexNew`), Reef Rank bar [L], the three daily goal icons with any progress made |
| 7 | on Continue | Pearls fly to the cove HUD Pearl chip (500 ms). Panel out (150 ms). Cove HUD in (250 ms). |

- The whole sequence is under 3.5 s. A tap anywhere jumps to the end state; a second tap on Continue closes.
- **Tier 1 run:** no specimen. The right column shows the tier 2 badge and `bank.too_small`.
- **Cove full:** after step 4 the cove-full choice (S13) replaces the right column.
- **Deep Pockets not owned:** from the player's third bank onward (chapter 05, section 8.2), at most once per session, one greyed row `bank.pass_row` sits where the pass row would be. Tapping it opens the pass in the shop. Section 9 rules apply.

### 4.6 Cove-full choice (S13) [MVP]

```
|  New:  +---------+     Your cove (lowest earners first, scrolls)                |
|        | 3D      |     +------+ +------+ +------+ +------+ +------+             |
|        | (T4)    |     | card | | card | |[card]| | card | | card |             |
|        | o 32/h  |     | o 10 | | o 20 | | o 40 | | o 40 | | o 80 |             |
|        +---------+     +------+ +------+ +------+ +------+ +------+             |
|  Cove is full. Pick one to release.                                             |
|  [ Release new one  o +refund ]   [ Release picked  o +refund ]   [ More slots ]|
```

| Item | Detail |
|---|---|
| Cards | Current specimens at 120 × 156, sorted by Pearls an hour, lowest first. Tap one to pick it (ring and scale 1.05). |
| Release new one | Releases the creature just banked. Refund shown on the button (amount from chapter 05). |
| Release picked | Disabled until a card is picked. Hold 600 ms to confirm (or tap, then `common.yes`). |
| More slots | Opens S18. Returning with a free slot keeps the new specimen without releasing anything. |
| No close, no timer | The player must choose, and leaving never chooses for them. If the player disconnects here, nothing is released and nothing is refunded: the new creature is saved as a pending specimen (`pendingSpecimen`; chapter 02, sections 11.5 and 11.6; chapter 09, section 12.2) and this choice is shown again on return. |
| On return | On the next join the choice opens by itself in the cove before anything else: before the offline claim (S15), the gifts (S26) and the cove HUD. It uses the bank summary's frame without the Pearls table (those Pearls were paid when the run was banked): `full.title`, `full.pick`, the waiting creature under `full.new`, the cards and the same three buttons. It stays until the player chooses, however many times they leave. |
| Feedback | The released creature swims out of the cove mouth (chapter 06); `SFX_UI_Release` |

### 4.7 Event banners (S09) [MVP]

| Banner | When | Size | Content | Sound |
|---|---|---|---|---|
| Warning | 60 s before the start | 380 × 52 | Event icon, `event.in` | `SFX_UI_EventWarn` |
| Last 10 s | Last 10 s before the start | 380 × 52 | Event icon, `event.in` with seconds ticking | `SFX_UI_Countdown` at 3, 2, 1 |
| Start | At the start | 480 × 112 | Art (`UI_Moment_EventFrenzy`, `UI_Moment_EventMoonTide` [MVP]; `UI_Moment_EventWhaleFall` [L]), event name, one line (`event.<id>.line`) | `SFX_UI_EventStart` |
| End | At the end | 380 × 52 | `event.over`, then `event.next` | `SFX_UI_EventEnd` |
| Called [L] | A called tide's 10 s warning starts (it never overlaps a scheduled tide; canon 10) | 480 × 52 | `event.called` with the buyer's display name and species icon | `SFX_UI_EventStart` |

Banners also show in the cove, so a player at home knows when to swim out.

### 4.8 Toasts (S10)

Toasts stack at `HUD.Toasts` (two visible, five queued, same kind merges into one with a count). Each is 320 × 64: icon 48, one line of text. In 200 ms, out 180 ms. In open water a toast cannot be tapped.

| Toast | Tag | Icon | Text key | Tap (safe water only) | Shown in a run? | Hold |
|---|---|---|---|---|---|---|
| Goal completed | [MVP] | Goal icon with `UI_Moment_GoalStamp` | `toast.goal_done` | Opens Daily | Yes | 2,500 ms |
| New species affordable | [MVP] | Species icon | `toast.afford` | Opens Species select on that card | No, held until safe water | 4,000 ms |
| New in Codex | [MVP] | Entry icon with `UI_Moment_CodexStamp` | `toast.codex` | Opens the entry | Yes | 1,500 ms |
| Leviathan on the server | [MVP] | `UI_Icon_Tier7` | `toast.leviathan` | None | Yes | 3,000 ms |
| Something failed | [MVP] | `UI_Common_Info` | `toast.error` or `toast.buy_failed` | None | Yes | 3,000 ms |
| Bubble received | [L] | `UI_Common_Bubble` | `toast.bubble` | None | Yes | 2,500 ms |
| Reef Rank up | [L] | `UI_Rank_Badge` | `toast.rank_up` | Opens the rank track | No, held until safe water | 3,000 ms |
| Called tide waiting | [L] | `UI_HUD_TideToken` | `toast.tide_held` | None | Yes | 3,000 ms |

"New species affordable" fires the first time the player's Pearls reach the price of a locked species (price from chapter 05). It also puts a badge on the Creatures dock button until the screen is opened. "Goal completed" puts a badge on the Daily dock button until the reward is claimed.

### 4.9 Species unlocked (S35) and purchase result (S28) [MVP]

| Moment | Detail |
|---|---|
| Species unlocked | Over species select, 1,200 ms: the silhouette fills with colour from left to right, `UI_Common_Rays` behind, `species.unlocked` with the species name, `SFX_UI_SpeciesUnlock`. The card becomes Picked. Any tap ends it. |
| Purchase result | Over the shop, 1,500 ms: the item's art at 192 rpx (a live render for a pattern or a decoration [L]), `shop.thanks`, `SFX_UI_Purchase`. Any tap ends it. The item card then shows its new state. A decoration bought from the tray plays it over decoration mode (5.6). |

## 5. Cove screens

### 5.1 Cove HUD (S14) [MVP]

```
+------------------------------------------------------------------------------------------+
| [R]        (rank 12)   [ o 12,480 (+) ]   [ o 340 an hour ]   [ 7/12 ]       (TIDE)[gear]|
|                                                                               0:45       |
|        back wall (3D):  [Species Wall: next species]   (Trophy Rock)   [tide clock]      |
|                       specimens swim around the cove (3D)                                |
|                    (o) one Pearl pile at the Pearl Clam: tap it to claim                 |
|                                                                                          |
|                                                                     [ Claim all  o 412 ] |
|      (Creatures) (Codex) (Daily) (Shop) (Ranks) (Decorate)                      ( DASH ) |
+------------------------------------------------------------------------------------------+
```

In the cove the player is a Fry and can still swim and dash. The run HUD's mass bar, bank chip, trait slots, status row, threats, home marker and ability button are hidden. The switch between run HUD and cove HUD is a 250 ms cross-fade.

| ID | Tag | Anchor | Position | Size (rpx) | Detail |
|---|---|---|---|---|---|
| `Cove.Pearls` | [MVP] | 0.5, 0 | `{0.5, -150},{0, 12}` | 240 × 56 | Pearl icon, balance (counts up on change), plus button that opens the shop's Pearls tab |
| `Cove.Income` | [MVP] | 0.5, 0 | `{0.5, 90},{0, 12}` | 200 × 56 | `UI_Cove_PerHour`, total Pearls an hour from all specimens |
| `Cove.Slots` | [MVP] | 0.5, 0 | `{0.5, 270},{0, 12}` | 120 × 56 | Slots used and total. Opens S16. |
| `Cove.Rank` | [L] | 0.5, 0 | `{0.5, -330},{0, 8}` | 72 × 72 | `UI_Rank_Badge` with the Reef Rank number. Opens S30. |
| `Cove.Dock` | [MVP] | 0.5, 1 | `{0.5, -60},{1, -28}` | 88 each, 16 gap | Buttons: Creatures, Codex, Daily, Shop [MVP]; Ranks, Decorate [L]. Icon 56 with a one-word label under it (Small 22). |
| `Cove.ClaimAll` | [MVP] | 1, 1 | `{1, -40},{1, -208}` | 260 × 88 | Shown when at least 1 Pearl is in the pile. Sits 208 rpx above the bottom so its hit area clears `HUD.Dash`'s by at least 16 rpx (section 1.5) on every screen class (task S5-C4). `common.claim_all` and the amount. A thumb-reach shortcut for tapping the pile. |
| `HUD.Dash`, `HUD.TideClock`, `HUD.Settings`, `HUD.Toasts`, `HUD.SafeBadge` | [MVP] | | As in the run HUD | | Unchanged |

**Badges.** A red dot (`UI_Common_Badge`) with a count sits on a dock button only when something free is waiting: Daily (goal reward or gift to claim), Creatures (a species became affordable), Codex (new entries). The Shop button never carries a badge.

**In the world (BillboardGuis, and SurfaceGuis on the back wall)**

| Element | Tag | Detail |
|---|---|---|
| Cove nameplate | [MVP] | At every cove mouth: `UI_Cove_Nameplate` with the owner's display name and a 3D render of their best specimen. [L] adds the Bubble count. Readable from 80 studs. |
| Specimen tag | [MVP] | Tier badge (32 rpx) above each specimen within 60 studs |
| Pearl pile | [MVP] | Cove income collects in one pile at the Pearl Clam (canon 11). `UI_Cove_IncomeBubble` (72 rpx) floats above the clam with the amount, and reads `cove.pile_full` when the pile has stopped growing. Tapping the pile or the bubble claims it. Nothing is claimed by swimming past: income is never claimed automatically. |
| Species Wall | [MVP] | On the back wall, left of the Trophy Rock (chapter 03, section 6.10). A SurfaceGui 256 × 256 rpx on the wall patch (`M_Cove_SpeciesWall`, chapter 07) shows the next species the player can unlock: its portrait (`UI_Species_PortraitPuffer` and so on) tinted to a flat dark silhouette, inside a progress ring made of two `UI_Common_RingHalf` that fills to Pearls owned out of the price, with `species.need` under it. When the price is reached the ring is full, `UI_Common_RingPulse` beats at 1 Hz and the label is `species.unlock`. Tapping the wall (it is far larger than 88 rpx on screen from the Home Stone) opens species select (S22) on that species' card. Hidden until chapter 04 lights it at the first bank; empty once every species is owned. No new image. |
| Tide clock | [MVP] | On the back wall, right of the Trophy Rock: the shell clock every cove has for free (`M_Cove_TideClock`, chapter 07). The mesh has the hand and the four picture plates; the interface adds only the countdown under it (m:ss, Number 28, the same value as `HUD.TideClock`), readable from 60 studs. It shows the next tide and its countdown and nothing more (chapter 03): the tide board [L] and Call the Tide stay in the tide popover (S05), which opens from `HUD.TideClock`. Hidden until chapter 04 reveals it at the first bank. |
| Cove Boost bubble | [L] | Offer O12. A second bubble beside the Pearl Clam: `UI_Shop_CoveBoost` at 56 rpx in an 88 rpx hit area, with `cove.boost` and the exact Pearls. Tapping it opens the Cove Boost dialog (5.4). Shown under the O12 conditions only. |
| Leaving | [MVP] | No button. The player swims out of the cove mouth to start a run. |

### 5.2 Specimen grid (S16) and specimen card [MVP]

Menu frame (6.0). Grid of cards, five columns, scrolls vertically.

```
+----------------+
|(T4)        (*) |   tier badge top left; best star top right
|                |
|   3D render    |   static ViewportFrame of the real creature with its traits
|                |
| (tr)(tr)(tr)   |   up to three trait icons, 32 rpx
|  o 32 an hour  |
+----------------+   150 x 196, frame by highest trait rarity
```

| Item | Detail |
|---|---|
| Frame | `UI_Cove_CardPlain` (no traits), `UI_Cove_CardCommon`, `UI_Cove_CardUncommon`, `UI_Cove_CardRare`, `UI_Cove_CardEpic`, `UI_Cove_CardMythic` |
| Best | The specimen with the highest Pearls an hour carries `UI_Cove_StarBest`; it is the one shown at the cove mouth |
| Sort | One button cycles `spec.sort_income`, `spec.sort_new`, `spec.sort_tier` |
| Empty slots | `UI_Cove_SlotEmpty`. After the last slot, one card with `UI_Common_Plus` and `slot.add` opens S18. |
| Card states | Normal; Pressed (scale 0.96); New (`UI_Common_New` until first opened); Picked (ring, in S13) |
| Performance | At most 12 live 3D renders at once; cards that scroll out release theirs. Renders are static (drawn once). |

### 5.3 Specimen detail (S17) [MVP]

Dialog 880 × 560.

| Area | Content |
|---|---|
| Left, 360 × 360 | 3D render that turns slowly; drag to spin it |
| Right, top | Species name, tier badge and tier name, mass, `spec.banked` with the date |
| Right, middle | `spec.traits`: one row per trait with icon, name, rarity and cove income bonus (for example +35% for a Rare trait). `spec.no_traits` when there are none. |
| Right, bottom | Pearls an hour (`common.per_hour`), `spec.best` tag if it is the best |
| Release | Secondary button, bottom right, `spec.release` with the refund (amount from chapter 05). Hold 600 ms, then S19 asks `spec.release_ask` with `spec.release_note`. |
| Read-only mode | In another player's cove: no Release button; the title shows the owner's name |

### 5.4 Income claim and offline claim (S15) [MVP]

| Item | Detail |
|---|---|
| Claim all | Pearl sprites fly from the pile to `Cove.Pearls` (500 ms), the balance counts up, `SFX_UI_Claim`, light haptic. The button hides until more is ready. |
| Offline claim (the welcome-back card) | On arriving in the cove after joining, if 10 or more Pearls (tune) are waiting in the pile: dialog 640 × 420 with `UI_Cove_OfflineArt`, `offline.title`, `offline.away` (time away), one total, and `common.claim` as the primary button. The total is everything waiting in the cove's one pile, shown as a single Pearl number that counts up over 600 ms; there is no list per specimen. Income is never claimed without a tap (canon 11): a smaller amount shows no dialog and waits in the pile for Claim all. |
| Capped | If the pile stopped growing the dialog adds `offline.cap` (8 hours, or 24 with Tide Watcher). [L]: one line `offline.pass_row` for players without Tide Watcher, from the second session on. |
| Cove Boost [L] | Offer O12 (chapter 05, section 8.3). A second, smaller button on the offline claim: `cove.boost` with the exact amount, which is 2 hours of the cove's income paid at once (canon 12). It opens the Cove Boost dialog. If the Tide Watcher line also qualifies, only the Cove Boost button shows (O-R6). |
| Cove Boost dialog [L] | 520 × 320, S19 frame: `UI_Shop_CoveBoost`, `product.cove_boost`, the exact Pearls. Buttons, in this order: `cove.boost_video` with `UI_Common_Video` (placement `ad_cove_boost`, only when a video is available), then `cove.boost_buy` with the live Robux price (product `prod_cove_boost`), then the close cross. One Cove Boost a day, bought or by video. |
| Never | Shown to a new player during the first session's first two minutes |

### 5.5 Slot upgrade (S18) [MVP]

Dialog 640 × 420: `UI_Cove_SlotArt`, `slot.title`, slots now and after (for example 12, then 13), Pearl price (price from chapter 05) on the primary button `common.buy`.

| State | Behaviour |
|---|---|
| Can afford | Buy opens S19; on yes the new slot appears in the cove with `SFX_UI_SlotUnlock` |
| Cannot afford | Buy looks disabled; tapping it shows `shop.need_more` and a `shop.get_pearls` button |
| All slots open | `slot.max`, no Buy button |
| Bigger Cove row | Under the Pearl offer, from the second session on: pass art at 96 rpx, `pass.bigger_cove.desc`, live Robux price. Hidden once owned. |

### 5.6 Decoration mode (S20) [L]

```
+------------------------------------------------------------------------------------------+
| [R]                               Decorate                                    [ Done ]   |
|                                                                                          |
|                 the cove from a pulled-back camera; grid cells light up                  |
|                          [item]   (Move) (Turn) (Put away)                               |
|                                                                                          |
| [ tray: (deco x2) (deco) (deco: Rank 8) (deco: o price) (deco: R$ price) ...  scrolls  ] |
+------------------------------------------------------------------------------------------+
```

| Item | Detail |
|---|---|
| Enter | Dock button Decorate. Camera pulls back (400 ms). The player's creature is hidden and cannot move. Dock and dash hide. |
| Tray | Full width × 136 rpx at the bottom. Items 104 rpx: live 3D render of the decoration (`M_Prop_*`), count owned. No images are needed per decoration. |
| Place | Drag an item from the tray into the cove. Cells show `UI_Cove_DecoCell` in the valid or invalid tint. Dropping on an invalid cell returns the item and shows `deco.cant`. |
| Edit | Tap a placed item: three 88 rpx buttons appear above it: `UI_Cove_DecoMove` (drag), `UI_Cove_DecoTurn` (45° per tap), `UI_Cove_DecoStore` (back to the tray) |
| Locked items | Shown dimmed, with what is needed to get them. That depends on how chapter 03 says the decoration is obtained: the table below has every case. Buying with Pearls uses S19; buying with Robux is offer O15 (section 9). |
| Done | Top right, 200 × 88. Every drop is saved at once, so leaving or disconnecting loses nothing. |

**Tray item states, by how the decoration is obtained.** The 50 decorations, their IDs and their names are chapter 03's (section 13); the prices are chapter 05's (sections 4.3 and 8.5). All of it is [L].

| Group (ID pattern) | Count | State in the tray while locked | How it becomes owned |
|---|---|---|---|
| Pearl items (`deco_<name>`) | 18 | Pearl icon and Pearl price (price from chapter 05). Before the Reef Rank that opens its shelf: `deco.rank` in place of the price. | A tap, then S19 |
| Reef Rank (`deco_rank_*`) | 11 | `deco.rank` | Free at that rank (6.6) |
| Codex (`deco_cdx_*`) | 6 | `UI_Common_Lock`; a tap shows the line `decoitem.<id>.how` (14.13) in a chip above the item for 3 s | Free for completing that Codex category (6.2) |
| Daily-goal milestones (`deco_goals_*`) | 4 | `UI_Common_Lock` and a bar of days done out of 3, 7, 14 or 28; a tap shows `decoitem.<id>.how` | Free when all three daily goals have been done on that many days (6.3) |
| Tide events (`deco_evt_*`) | 7 (3 at launch) | `UI_Common_Lock`; a tap shows `decoitem.<id>.how` | Free for the event task chapter 03 sets |
| Starter Pack (`deco_buy_gold_chest`, the Golden Chest) | 1 | `deco.starter`. From the second session on, a tap opens the shop at the Starter Pack banner (6.4). It is never sold on its own. | Comes with `prod_starter_pack` |
| Robux (`deco_buy_jelly_lamp`, `deco_buy_disco_clam`, `deco_buy_mini_pickle`) | 3 | The Robux glyph and the live Robux price under the render. A tap opens a dialog (S19 frame, 520 × 420) holding the decoration's item card (6.4); only the price button on that card opens the Roblox purchase prompt. | One purchase, kept for good (offer O15) |

- Chapter 05 (section 8.5) sells the Robux decorations "on the decoration shelf beside the Pearl items": in the tray they sit straight after the Pearl items. They never carry a badge (O-R4), and nothing with a Robux price shows in the first two minutes of a first session (O-R7).
- A decoration that has just become owned, by any route, carries `UI_Common_New` in the tray until it is first placed.

### 5.7 Visiting another cove (S21) and leaving a Bubble [L]

Swimming into another player's cove mouth starts a visit. Only a tier 1 Fry can enter (canon 6); a bigger creature is turned back at the mouth and a chip shows `visit.fry_only` for 2 s. A visit does not bank or end the run; the run HUD's mass bar, bank chip and trait slots stay visible, threats and home marker hide, and the safe badge shows.

| Element | Anchor and position | Size | Detail |
|---|---|---|---|
| Arrival banner | Moment slot | 380 × 52 | `visit.title` for 2 s |
| Visit chip | 0.5, 0 at `{0.5, 0},{0, 130}` | 300 × 48 | `UI_Cove_VisitEye`, `visit.look`, the cove's Bubble count |
| Bubble button | 1, 1 at `{1, -40},{1, -196}` | 120 × 120 | `UI_Cove_BubbleButton`. States: Ready; Pressed; Done (tick, 50% opacity; a tap shows `visit.tomorrow`). |
| Swim out button | 0, 1 at `{0, 16},{1, -40}` | 220 × 88 | `visit.leave`. Carries the creature to the cove mouth in 600 ms. Swimming out by hand also works. |
| Specimens | World | | Tap one for S17 in read-only mode |

**Leaving a Bubble:** on the tap a bubble sprite rises from the creature to the nameplate (600 ms), the count pops up by one, `SFX_UI_Bubble`, light haptic, the button goes to Done, a chip shows `visit.bubble_done` for 2 s. The owner, if online, gets `toast.bubble`. Canon 6: one Bubble per cove per day.

## 6. Menus

### 6.0 Menu frame (shared) [MVP]

```
+--------------------------------------------------------------------------+
| (icon) Title                              [ o 12,480 ]              [X]  |  title bar 72
|------+-------------------------------------------------------------------|
| tab  |                                                                   |
| tab  |                       content 1000 x 528                          |
| tab  |                       (scrolls vertically)                        |
| tab  |                                                    [ Primary ]    |
+--------------------------------------------------------------------------+
   ^ tabs 96 wide, each 96 x 88: icon 48 and a label         panel 1120 x 624, centred
```

- Scrim behind: 60% dark, fades in 150 ms, reaches the physical screen edges.
- Tabs are on the left edge so the left thumb reaches them; the primary button is bottom right for the right thumb.
- The Pearl chip in the title bar shows on every menu where Pearls can be spent.
- Dialogs use the same frame without tabs, at the sizes given per screen.

### 6.1 Species select (S22) [MVP]

```
+--------------------------------------------------------------------------------------+
| (icon) Creatures                                    [ o 12,480 ]                [X]  |
|  +---------+  +=========+  +---------+  +---------+  +---------+  +---------+        |
|  | picture |  | picture |  | ####### |  | ####### |  | ####### |  | ####### |        |
|  |         |  |         |  | shadow  |  | shadow  |  | shadow  |  | shadow  |        |
|  | Minnow  |  | Puffer- |  | Eel     |  | Sea     |  | Squid   |  | Shark   |        |
|  | Picked  |  | fish    |  | (lock)  |  | Turtle  |  | (lock)  |  | Pup     |        |
|  | ooooo.. |  | ooo.... |  | [===--] |  | [=----] |  | [-----] |  | [-----] |        |
|  +---------+  +=========+  +---------+  +---------+  +---------+  +---------+        |
|  (Puff) Puff: Puff up. Hard to eat.            Slow and safe            [ Pick ]     |
+--------------------------------------------------------------------------------------+
```

Six cards of 164 × 380 with 12 rpx gaps fit without scrolling. Later species scroll sideways.

| Card state | Look |
|---|---|
| Owned | Painted portrait (`UI_Species_PortraitMinnow` and so on), name, seven tier pips lit for tiers reached with this species, `species.best` |
| Picked | Owned plus a tick and `species.picked` |
| Locked | The same portrait tinted to a flat dark silhouette (no second image), name visible, `UI_Common_Lock`, Pearl price (price from chapter 05), progress bar: Pearls owned out of the price |
| Locked, affordable | Silhouette pulses at 1 Hz, bar full, `UI_Common_New` tag |
| Selected | `UI_Species_Card` selected sprite, scale 1.05; the bottom strip shows this species |

| Bottom strip | Detail |
|---|---|
| Left | Ability icon, ability name and description (`ability.<id>`, `ability.<id>.desc`), feel line (`species.<id>.feel`) |
| Primary button | `species.pick` (owned), `species.picked` (disabled), or `species.unlock` with the Pearl price |
| Cannot afford | The unlock button looks disabled and shows `species.need` (Pearls still needed) |
| Shark Pup [L] | A second button with the live Robux price and `UI_Species_PassTag` opens the Roblox purchase prompt for the pass |
| Patterns [L] | For an owned species: a row of 72 rpx swatches (`UI_Species_PatternFrame`, live render inside). States: owned, picked, for sale with live Robux price. |

**Unlock flow:** unlock button, then S19 (price, balance after), then S35. **Pick:** the creature in the cove changes at once with a puff of bubbles and `SFX_UI_Pick`.

### 6.2 Codex (S23) and entry page (S24) [MVP]

One tab per category of chapter 03 (section 8.1), in its order: `codex.tab_species` (`cdx_species`), `codex.tab_tiers` (`cdx_tiers`), `codex.tab_traits` (`cdx_traits`), `codex.tab_prey` (`cdx_prey`) [MVP]; `codex.tab_dangers` (`cdx_dangers`), `codex.tab_places` (`cdx_places`), `codex.tab_tides` (`cdx_tides`) [L] (canon 11). Chapter 03, section 8 owns the categories, the entries, how each is filled and what each pays. The Tiers tab has one page per species; the same seven tiers also show as pips on each species card (6.1). The header shows a progress bar and `codex.found` for the open tab.

Grid: cells of 128 × 148 (icon 96, name), seven columns.

| Cell state | Look |
|---|---|
| Found | Icon in colour, name |
| Unknown | Icon as a flat silhouette, `codex.unknown`. Trait cells keep their rarity frame so the player can see how rare the missing trait is. |
| New | Found but never opened: `UI_Common_New` tag |

Tapping a cell opens the entry page (dialog 760 × 520). Arrows on its left and right edges step to the previous and next entry.

| Tab | Entry page content |
|---|---|
| Creatures [MVP] (3 in the MVP, 6 at launch) | Portrait 256, name, feel line, ability icon with name and description, seven tier badges (lit when reached with this species), `codex.banked` count, `codex.best_mass` |
| Tiers [MVP] (3 pages of 7 in the MVP, 6 pages at launch) | The grid has one cell per species: its head icon and seven pips of `UI_Common_Pip`, one lit for each tier reached with it. The page: the species name, then under `codex.sizes` the seven tier badges at 96 in a row, each with its tier name and the Pearls it pays the first time it is reached (tiers 2 to 7; amounts from chapter 05). A tier not reached yet is a silhouette. Under the row, `codex.page_reward` with the Pearls for filling the page and, [L], a live render of that species' Codex pattern in `UI_Species_PatternFrame`. Every reward is paid once per account. |
| Traits [MVP] (9 in the MVP, 13 at launch) | Icon 128 in its rarity frame, name, rarity, effect line, `codex.from` with the trait prey's icon (shown as unknown until that prey is found), cove income bonus, `codex.gained` count |
| Prey [MVP] (8 prey + 9 trait prey in the MVP, 13 trait prey at launch) | Icon 128, name, tier badge, zone icons (`UI_Codex_ZoneNursery`, `UI_Codex_ZoneReef`, `UI_Codex_ZoneKelp`, `UI_Codex_ZoneDropoff`) under `codex.where`, `codex.eaten` count, and for trait prey `codex.gives` with the trait icon |
| Dangers [L] (9) | Predator or hazard icon 128 (`UI_Icon_PredGull` and so on, `UI_Icon_HazardJellyBloom` and so on), name, the tier it eats up to or its effect line (text from chapter 03), zone icons under `codex.where`, `codex.met` count |
| Places [L] (30) | The zone icon of the landmark's zone at 128, the landmark's name and one line (text from chapter 03), `codex.visited` with the date. No picture per landmark is needed. |
| Tides [L] (3) | Event icon 128 (`UI_Icon_EventFrenzy`, `UI_Icon_EventMoonTide`, `UI_Icon_EventWhaleFall`), name, the event's one line, `codex.tide_when` with its place in the hourly rotation |
| Unknown entry | Silhouette, `codex.unknown`, and the hint: zone icons, or `codex.event_only` with the event icon. The hint tells the player where to look. |

### 6.3 Daily: Goals (S25) [MVP] and Gifts (S26) [L]

```
| (icon) Daily                                   [ o 12,480 ]               [X] |
| [Goals]  Easy   (eat)  Eat 30 Sardine  [=========---] 21/30  o reward  (swap)  |
| [Gifts]  Medium (bank) Bank 2 times    [======------] 1/2    o reward  (swap)  |
|          Hard   (grow) Reach Hunter    [============]        o reward [Claim]  |
|          New goals in 5:12:09                       1 free swap left today     |
```

| Goals item | Detail |
|---|---|
| Row | 1000 × 120: difficulty tag, goal icon 72, goal text (from a `goal.*` template), progress bar and count, Pearl reward (amount from chapter 05) |
| Difficulty | Always three rows in this order: one Easy, one Medium, one Hard (canon 11). The one exception is an account's first day, whose fixed set is Easy, Easy, Medium (`dg_eat_50`, `dg_tier3`, `dg_bank_snapper`). The tag is a chip with `goals.easy`, `goals.medium` or `goals.hard` (Small 22) and one, two or three pips of `UI_Common_Pip`. |
| States | In progress; Ready (row glows, `common.claim` button); Claimed (`UI_Moment_GoalStamp`, 60% opacity) |
| Claim | Pearls fly to the title bar chip, `SFX_UI_GoalClaim` |
| Reset | `goals.reset` counts down to the real daily reset |
| Swap | An 88 rpx button `UI_Daily_Swap` on each unfinished row replaces that goal with another of the same difficulty. The line under the list says what the next swap costs. |
| Swap: free [MVP] | One free swap a day for every player (chapter 05, section 3.5): `goals.swap_free`. After it is used, the swap buttons hide in the MVP. |
| Swap: Goal Reroll [L] | Offer O13, after the free swap is used. Tapping a swap button opens a small dialog (S19 frame) with up to two buttons: `goals.swap_video` with `UI_Common_Video` (placement `ad_goal_reroll`, only when a video is available, once a day) and `goals.swap_buy` with the live Robux price (product `prod_goal_reroll`, up to three a day; limits from chapter 05). |
| Milestone [L] | One row under the reset line, 1000 × 88, for the four daily-goal milestone decorations (`deco_goals_sun_shell`, `deco_goals_week_wheel`, `deco_goals_lucky_starfish`, `deco_goals_message_bottle`; chapter 03, section 13). It shows a live render of the next one at 72 rpx, a progress bar, and `goals.milestone` with the days on which all three goals were done and the days it needs (3, 7, 14 or 28; a lifetime count that a missed day never resets). When the bar fills, the decoration is given free and waits in the decoration tray with `UI_Common_New` (5.6); the row moves to the next one and hides after the fourth. Nothing is sold on this row. |

```
| [Goals]   +------+ +------+ +------+ +------+ +------+ +------+ +-----------+ |
| [Gifts]   | Day 1| | Day 2| | Day 3| | Day 4| | Day 5| | Day 6| |   Day 7   | |
|           |  ok  | |  ok  | |Today | |      | |      | |      | |  big gift | |
|           | o    | | o    | |[Claim]| | o   | | o    | | o    | |           | |
|           +------+ +------+ +------+ +------+ +------+ +------+ +-----------+ |
|           Miss a day? Your next gift waits.                                   |
```

| Gifts item | Detail |
|---|---|
| Cell | 128 × 176 (`UI_Streak_Cell`); day 7 is 200 × 176 with `UI_Streak_GiftBig`. Every reward is Pearls (canon 11): the Pearl icon and the amount from chapter 05. |
| States | Claimed (tick, dim); Today (glow, `common.claim`); Later (plain) |
| Auto-open | Once a day, on the first arrival in the cove, from the second session on, after any offline claim |
| Rule line | `streak.rule`. Each day played opens the next box. A missed day never sends the player back to day 1: the next box simply waits (canon 11). After day 7 the calendar starts again at day 1. Nothing is sold on this tab. |
| Day count | `UI_Streak_Flame` in the title bar with the number of the box that opens next (1 to 7). It never drops. |

### 6.4 Shop (S27) [MVP]

```
| (icon) Shop                                     [ o 12,480 ]                [X] |
| [Passes]  +-----------+ +-----------+ +-----------+ +-----------+               |
| [Pearls]  |    art    | |    art    | |    art    | |    art    |               |
| [Boosts]  | Deep      | | Bigger    | | Tide      | | Keen Nose |               |
| [Pattern] | Pockets   | | Cove      | | Watcher   | |           |               |
| [Decor.]  | 2x Pearls | | +10 slots | | Tide board| | 4, not 5  |               |
|           | [R$ price]| | [ Owned ] | | [R$ price]| | [R$ price]|               |
|           +-----------+ +-----------+ +-----------+ +-----------+               |
```

| Tab | Tag | Items |
|---|---|---|
| Passes | [MVP] | `pass_deep_pockets`, `pass_bigger_cove` [MVP]; `pass_tide_watcher`, `pass_keen_nose`, `pass_shark_pup` [L]. From the second session until bought, the Starter Pack banner (`prod_starter_pack`, 1000 × 140) sits above the cards [L]. It names what is inside with `starter.what` and shows it: the Pearls, the `pat_minnow_sunrise` pattern and the Golden Chest decoration (`deco_buy_gold_chest`), the last two as live renders at 96 rpx. |
| Pearls | [MVP] | Four Pearl packs: `prod_pearls_s`, `prod_pearls_m`, `prod_pearls_l`, `prod_pearls_xl` |
| Boosts | [L] | Cove Boost (`prod_cove_boost`), Goal Reroll (`prod_goal_reroll`), Call the Tide (`prod_call_tide`). Trait Lock is not here: it is sold only on the gulped panel (4.4). |
| Patterns | [L] | Patterns grouped by species (IDs `pat_*`, chapter 05, section 8.5) |
| Decorations | [L] | The three Robux decorations (chapter 05, section 8.5): `deco_buy_jelly_lamp`, `deco_buy_disco_clam`, `deco_buy_mini_pickle`. Each is an item card with a live 3D render in place of art, its name (`decoitem.<id>`, 14.13) and the line `deco.desc`. The same three also sit in the decoration tray (5.6). The Golden Chest (`deco_buy_gold_chest`) has no card: it comes only in the Starter Pack. Pearl decorations are bought in the tray, not here. The tab uses the dock's `UI_Cove_DockDeco` as its icon and `shop.tab_decorations` as its label. |

Purchase IDs are owned by chapter 05 (canon 16) and are used here unchanged. Text keys are formed from them: `pass.<name>` for `pass_<name>` and `product.<name>` for `prod_<name>`. The Robux decorations keep chapter 05's IDs (`deco_buy_<name>`) and take their names from chapter 03 like every other decoration (`decoitem.<id>`, 14.13).

**Item card** 232 × 340 (`UI_Shop_Card`): art 192, name (Body 24), one line of description (Small 22, two lines at most), price button 200 × 72 (`UI_Common_ButtonRobux`, Robux glyph, live price). Every price is "price from chapter 05" and is read from Roblox at run time, never typed into the interface, because Roblox may show a different regional price.

| Card state | Look |
|---|---|
| For sale | As above |
| Pending | After the tap: spinner in the button until the Roblox prompt closes |
| Owned (passes, patterns, decorations) | Owned sprite, tick, `common.owned`; no button. An owned decoration waits in the decoration tray (5.6); after the Starter Pack is bought, the Golden Chest is there too. |
| Held (Call the Tide) | The player holds a token that has not started: the held-token chip with `tide.called_wait` shows the number held beside the price button, and replaces it at three tokens, the most a player can hold (chapter 02, section 14.7) |
| Used today (Cove Boost, Goal Reroll) | The daily limit from chapter 05 is reached: `shop.tomorrow`, button disabled |
| Unavailable | The price could not be loaded: `shop.unavailable`, button disabled |

**Robux purchase flow:** tap the price button; Roblox shows its own purchase prompt (it cannot be restyled or replaced); on success S28 plays and the card updates; on cancel the card returns to For sale with no message; on an error `toast.buy_failed`.

**Pearl purchase flow (S19 confirm dialog)** for species, slots and Pearl decorations: dialog 520 × 320 with the item picture and name, `shop.cost`, `shop.after` (balance after), buttons `common.cancel` and `common.buy`. If the player cannot afford it: `shop.need_more` and `shop.get_pearls` (opens the Pearls tab; it never opens a Robux prompt directly).

### 6.5 Ranks (S29) [L]

| Tab | Rows | Value | Notes |
|---|---|---|---|
| `ranks.tab_here` | All players on this server, live (once a second) | Current mass | Tapping a row shows `ranks.show_way`: a second home-style marker points to that player's cove for 60 s |
| `ranks.tab_week` | Top 100 worldwide plus the player's own row | Biggest banked mass this week | `ranks.new_week` shows the real time the week ends |
| `ranks.tab_bubbles` | Top 100 worldwide plus the player's own row | Bubbles | |

Row 1000 × 64: rank (`UI_Rank_Medal1` to `UI_Rank_Medal3` for the top three, a number after), species icon 48, tier badge 40, display name, value. The player's own row is pinned at the bottom with `UI_HUD_RowSelf`. Empty list: `ranks.empty`. No avatar pictures anywhere.

### 6.6 Reef Rank track (S30) [L]

Dialog 1000 × 420. Left: `UI_Rank_Badge` at 128 rpx with the rank number, `rank.level`, a progress bar and `rank.next`. Right: a track of 50 nodes (`UI_Rank_Node`: reached, next, locked) that scrolls sideways and opens centred on the current rank. Under each node sits its reward: a title (`UI_Rank_Title`) or a decoration (live 3D render). Reward names come from the chapters that define them (section 14.13).

### 6.7 Settings (S31) [MVP]

A side panel 360 rpx wide and the full safe height, docked to the right edge, sliding in over 200 ms. It never covers the creature, so it can open in open water. The game does not pause; touches left of the panel still steer.

| Setting | Tag | Control | Values | Default | Devices |
|---|---|---|---|---|---|
| Controls | [L] | Two pictures to choose from (`UI_Settings_SchemeDrag`, `UI_Settings_SchemeTwoThumb`) | Drag to swim, Two thumbs | Drag to swim | Phone, tablet. In the MVP there is one scheme, Drag to swim, and this row is absent. |
| Left-handed | [L] | Toggle | Off, on | Off | Phone, tablet |
| Drag sensitivity | [MVP] | Slider | 0.5 to 1.5, step 0.1 | 1.0 | Touch |
| Mouse look speed | [MVP] | Slider | 0.2 to 3.0, step 0.1 | 1.0 | Keys and mouse |
| Two-thumb look speed | [L] | Slider | 0.5 to 2.0, step 0.1 | 1.0 | Touch, Two thumbs scheme only |
| Gamepad look speed | [L] | Slider | 0.5 to 2.0, step 0.1 | 1.0 | Gamepad |
| Swap sticks | [L] | Toggle | Off, on | Off | Gamepad |
| Flip up and down | [MVP] | Toggle | Off, on | Off | All; saved per input type |
| Interface size | [L] | Slider | 0.8 to 1.3, step 0.1 | 1.0 | All (feeds the scale formula, 1.2) |
| Sounds | [MVP] | Slider | 0 to 10 | 8 | All |
| Music | [MVP] | Slider | 0 to 10 | 6 | All |
| Graphics | [MVP] | Four-way picker | Auto, Smooth, Balanced, Pretty | Auto | All |
| Colour-blind outlines | [MVP] | Toggle | Off, on | Off | All |
| Less motion | [MVP] | Toggle | Off, on | On if the device asks for reduced motion, otherwise off | All |
| Vibration | [MVP] | Toggle | Off, on | On | Phone; gamepad [L] |
| Tap instead of hold | [MVP] | Toggle | Off, on | Off | All |
| Bigger text | [L] | Toggle | Off, on | Off | All |
| Hide emotes | [L] | Toggle (`settings.hide_emotes`). The row icon is `UI_Emote_Hi` drawn at 48 rpx, so no new image is needed. | Off, on | Off | All. It arrives with the emote wheel (S06); in the MVP there are no emotes and this row is absent. |
| Language | [L] | List | Same as Roblox, then each supported language in its own name | Same as Roblox | All |
| Private reef | [L] | Row that opens S32 | | | All |
| Reset settings | [MVP] | Button, then S19 with `settings.reset_ask` | | | All |
| Version | [MVP] | Text `settings.version` | | | All |

- Chapter 15 owns the ranges and defaults of the control settings (sections 3.1 and 3.3). The panel shows only the rows for the input in use, and settings that describe the device (scheme, look speeds, flip, swap sticks, graphics) are saved per input type, so a phone setting never lands on a PC.
- Drag sensitivity and Two-thumb look speed [L] are two saved values, not one: they mean different things (how far the thumb moves for full speed; how fast the view turns) and chapter 15 (section 3.1) gives them different ranges. Chapter 09's save has one `lookSpeed` per input type, so the touch type needs a second field when the two-thumb scheme arrives (section 19).
- Each row is 328 × 88: icon 48, label above, control below. A change applies at once and is saved to the profile; sliders play `SFX_UI_Tap` at the new volume.
- "Hide emotes" [L] is the setting chapter 02 (section 17.1) defines: while it is on, this player sees no emote bubble (`UI_Emote_WorldBubble`) above any other creature and hears no `SFX_UI_Emote` from them. The player's own emote button and wheel stay, and other players still see what this player sends. It is saved as `hideEmotes` in the profile's settings (chapter 09, section 12.2) and, like every setting that describes the player and not the device, it follows the account to every device.
- "Graphics" changes GULP's own effects only (particle counts, prey draw distance, water effects, outline quality). Roblox's own graphics quality lives in the Roblox menu and scripts cannot change it.

### 6.8 Private reef info (S32) [L]

Dialog 640 × 420.

| Where the player is | Content |
|---|---|
| In a private server | `private.title`, `private.owner`, `private.players`, `private.events`, and an `private.invite` button that opens Roblox's invite prompt |
| In a public server | `UI_Shop_PrivateServer` art, `private.title`, `private.desc`, the price (price from chapter 05), `private.where`. Private servers are bought on the game's Roblox page; this screen only explains. |

## 7. First-time prompts: component kit (S33) [MVP]

Chapter 04 scripts the first two minutes and uses only these parts. All sit on the `GulpGuide` layer.

| ID | Component | Image | Size (rpx) | Behaviour |
|---|---|---|---|---|
| G1 | Arrow | `UI_Guide_Arrow` | 96 | Points at a HUD element (by ID) or a world position; bobs 12 rpx at 1.5 Hz along its own direction |
| G2 | Curved arrow | `UI_Guide_ArrowCurved` | 128 | Joins a text bubble to its target when they are apart |
| G3 | Hand | `UI_Guide_Hand` (up and down sprites) | 112 | Three loops. Tap: down 120 ms, up 380 ms, pause 500 ms. Hold: down for the hold length with a ring filling. Drag: down, moves along a path for 800 ms leaving a fading trail, up. |
| G4 | Trail marker | `UI_Guide_TrailDot`, `UI_Guide_TrailChevron` | 48, 64 | A glowing line of dots in the world from the creature to a target, one every 12 studs, at most 12. Chevrons flow along it at two dots a second. Dots fade as the creature passes. If the target is off screen an edge arrow (G1) leads to it. |
| G5 | Highlight ring | `UI_Guide_Ring` | 160, nine-sliced | Sits around a HUD element or a world target; pulses 1.0 to 1.15 at 1 Hz |
| G6 | Cut-out scrim | `UI_Guide_Cutout` | Nine-sliced | Dims the screen by 50% except a rounded hole around the target. Taps reach only the target. Never used in open water. |
| G7 | Text bubble | `UI_Guide_Bubble`, `UI_Common_BubbleTail` | Up to 420 wide | At most two lines and 28 English characters, Body 24. Sits above its target; when the target is the creature it uses the moment slot instead. |
| G8 | Input hint | Hand, key cap or gamepad glyph | 64 | Shows the right picture for the input in use and swaps within 200 ms when the player changes input |
| G9 | Step tick | `UI_Common_Check` | 64 | Pops on the bubble for 400 ms when the step is done, with `SFX_UI_GuideStep` |

**Calls chapter 04 can make**

```
Guide.point(target, { pointer = "arrow" | "tap" | "hold" | "drag", textKey = "guide.dash", ring = true, cutout = false })
Guide.trail(worldPosition)
Guide.done()        -- plays the step tick, then clears
Guide.clear()
HUD.setVisible(elementId, visible)
```

**Rules**

- At most one bubble and one pointer on screen at a time.
- A prompt appears in 200 ms and clears within 100 ms of the player doing the action.
- If the player does nothing for 6 s the pointer replays with a bounce. It never escalates to a blocking screen.
- Prompts never block steering, never cover the keep-clear box, and never show while an unrelated menu is open.
- Text comes only from `guide.*` keys (section 14.11). Chapter 04 may ask for more keys; it does not write its own text.
- With "Less motion" on, bobbing and pulsing become a slow fade (0.5 Hz).

## 8. Loading and reconnect

### 8.1 Loading (S01) [MVP]

```
+--------------------------------------------------------------------------+
|                         painted sea (UI_Load_Background)                 |
|                                                                          |
|                            G U L P   (UI_Load_Logo)                      |
|                                                                          |
|                   ><>  (UI_Load_Mascot swims along the bar)              |
|                 [=======================-----------]                     |
|                          Green means food.                               |
+--------------------------------------------------------------------------+
```

| Item | Detail |
|---|---|
| Replaces | The default Roblox loading screen is removed (`ReplicatedFirst:RemoveDefaultLoadingScreen()`); ours lives in `ReplicatedFirst` and shows on the first frame |
| Bar | Real progress of the needed assets only: HUD atlases, the player's species, the Nursery or the cove. Everything else streams in afterwards. |
| No minimum time | The screen leaves the moment the needed assets and the player's save are ready (pillar 1). Target: under 5 s on a mid-range phone (tune). |
| Tips | One of `load.tip1` to `load.tip6`, changed every 3 s |
| Slow | After 10 s the tip is replaced by `load.slow` |
| End | 400 ms fade straight into the water. Steering works during the fade. |
| Teleports | The same screen is used between servers (`TeleportService:SetTeleportGui`) |

### 8.2 Reconnect (S02) [MVP]

Full screen: dimmed `UI_Load_Background`, `UI_Load_Reconnect` art (192 rpx), a title, one line, and at most one button.

| Case | Trigger | Text | Action |
|---|---|---|---|
| Save not loaded | The player's save could not be opened | `reconnect.save_title`, `reconnect.save_body`, spinner | Retries every 5 s, three times, then shows `common.retry` (rejoins) |
| Server update | The server is closing for a new version | `reconnect.update_title`, `reconnect.update_body` | Moves the player by itself. A run that was in progress is offered back on arrival (8.3). |
| Connection lost | Roblox drops the connection | Roblox shows its own dialog on top; it cannot be replaced. Behind it: `reconnect.lost_title` and, only if the last save was confirmed, `reconnect.saved`. | Roblox's own button |
| Weak connection | No server reply for 5 s | `HUD.Lag` icon, then `reconnect.weak` in the moment slot | None; play continues |

### 8.3 Continue your run (S36) [MVP]

Canon 5.5: a player who leaves in the middle of a run and comes back within 5 minutes can pick the run up again. Chapter 02 (section 16.5) and chapter 09 (section 12.5) own the rule; this is the card it needs.

```
+----------------------------------------------------------------------+
|                         Your run is waiting                          |
|                                                                      |
|   +--------------+     (T4) Hunter                 mass 86           |
|   |  3D creature |     (tr) (tr) (tr)                                |
|   |  240 x 240   |     Starting fresh ends this run.                 |
|   +--------------+                                                   |
|                                                                      |
|   [ Start fresh  o +26 ]                    [ Continue your run ]    |
+----------------------------------------------------------------------+
```

| Item | Detail |
|---|---|
| When | On joining any server, straight after loading (S01) and before the creature appears, if the save holds a suspended run that has not run out: 300 s after a disconnect, 900 s after a server shutdown or update. A run that has already run out shows no card: it was settled before the first spawn. |
| Who sees it | Only an account that has banked at least once. An account that has never banked gets no card: its run resumes at once and chapter 04's first-time script carries on from the last completed beat (chapter 02, sections 16.4 and 16.5). |
| The 5-minute window | It is measured from the disconnect to the moment the player rejoins, and it is checked once, at join. Time spent on the card is not counted: the run cannot run out while the card is open, however long the player takes to choose. The same holds for the 15 minutes after a server shutdown. |
| Frame | Dialog 760 × 420 (the 6.0 frame without tabs) over a dimmed `UI_Load_Background`, so nothing can reach the player while they read. `SFX_UI_Open`. |
| Content | `resume.title`; a live 3D render of the saved creature (240 × 240, with its pattern and traits); tier badge and tier name; mass; trait icons at 48 rpx; `resume.fresh_note`. No new image is needed. |
| Continue your run | Primary button, 320 × 96, bottom right (zone A), `resume.continue`. The card leaves in 150 ms and the run HUD comes in; the creature is at its saved place, or at the nearest revive point if a danger is close (chapter 02), with 3 s of protection shown on `HUD.Status`. `SFX_UI_Revive`. |
| Start fresh | Secondary button, 280 × 88, bottom left, `resume.fresh` with the Pearl icon and the Pearls the saved run pays when it is given up: scraps at the normal rate after a disconnect, the full bank value with no specimen after a server shutdown (chapter 09, section 12.5). The number comes from the server. Hold 600 ms to confirm (or tap, then `common.yes`), because it cannot be undone. The Pearls fly to the Pearl chip and the player arrives in the cove as a Fry, as any returning player does. |
| No close, no timer, nothing sold | The player must choose one of the two. The card carries no countdown and no offer of any kind. |
| Order | It comes before everything else on join. It can never meet a pending cove-full choice (4.6), because that one follows a finished bank. After Start fresh the offline claim and the gifts follow as usual; after Continue they wait until the player is next in the cove. |
| Leaving again | If the player disconnects with the card open, nothing is chosen: the run stays suspended with its original expiry time (chapter 02, section 16.5), which is checked again at the next join. |

## 9. Offers

### 9.1 Rules for every purchase prompt

| # | Rule | Detail |
|---|---|---|
| O-R1 | Never during play | No offer, price button or purchase prompt appears in open water. Roblox's purchase prompt covers the middle of the screen, so a Robux purchase can start only in safe water or on the gulped panel (the run is already over). |
| O-R2 | Always a clear way out | Every offer has a close or decline control with an 88 rpx hit area, visible from the first frame, in the same place every time (top right of a card or dialog), at full contrast. It is never delayed, shrunk or hidden. |
| O-R3 | No fake timers | A timer appears only for something real: the tide clock and the daily reset. No "offer ends in", no timer of any kind on the revive (canon 5.5), no limited stock. |
| O-R4 | No pressure wording | Declining is a plain button (`common.no_thanks` or a close cross). No guilt text, no "best value" or "popular" tags, no crossed-out prices, no red dots on paid things. |
| O-R5 | Price first | The live Robux price is on the button before the player taps. Robux buttons use `UI_Common_ButtonRobux` and the Robux glyph; Pearl buttons use the Pearl icon. One button never shows both. |
| O-R6 | One offer per moment | A screen the player did not open to shop shows at most one offer. The gulped panel may show up to three rows about the same loss; none is larger than Swim again, which always has the best position (zone A). |
| O-R7 | Not too early | Nothing is sold in the first two minutes of a new player's first session (canon 12). The revive offer is never shown on an account's first death (canon 5.5). Also, from chapter 05: no Deep Pockets row before the third bank; the Starter Pack card, Bigger Cove row and Tide Watcher rows start in the second session. |
| O-R8 | Not too often | An offer card that was closed does not return in the same session. A contextual row shows at most once per screen visit. An offer is never a toast and never opens by itself over a menu. |
| O-R9 | No accident taps | Offer buttons accept input 700 ms after they appear. None sits where the dash or ability button was. The free action is always the biggest button and sits in zone A. |
| O-R10 | Roblox confirms | The Roblox purchase prompt is the confirmation step. The game never opens it without a tap on a button that shows the price. |
| O-R11 | Rewarded video is optional [L] | A video button shows only when a video is available for this player. It carries `UI_Common_Video` and a "Watch" label. When no video is available the button is absent, not greyed. Declining never takes away something the player already had. There are exactly three placements, each a product that is also sold for Robux (canon 12): `ad_revive` (Revive), `ad_cove_boost` (Cove Boost) and `ad_goal_reroll` (Goal Reroll). |
| O-R12 | Honest results | After a purchase the item is granted, or a pending spinner shows, within 2 s. A failure says so (`toast.buy_failed`) and never claims success. |
| O-R13 | Nothing random for Robux | No paid random items (canon). |

### 9.2 Layout of each offer type

| ID | Offer | Tag | Where | Layout | Shown when | Way out |
|---|---|---|---|---|---|---|
| O1 | Revive (`prod_revive`) | [MVP] | Gulped panel, right column | Row 360 × 80: icon 56, `gulped.revive`, `gulped.revive_note`, Robux price. No timer. | Revive not used this run; not the account's first death; the lost creature had 30 mass or more; not in the first two minutes | Swim again |
| O2 | Watch to revive (`ad_revive`) | [L] | Gulped panel, above O1 | Row 360 × 80: video icon, `gulped.revive_video` | The O1 conditions, and a video is available | Swim again |
| O3 | Keep traits (Trait Lock, `prod_trait_lock`) | [L] | Gulped panel, under O1. Sold nowhere else. | Row 360 × 80: `UI_Moment_TraitLock` at 56, `gulped.keep_traits`, Robux price | The lost creature held an Uncommon or better trait; shown even when the revive is used; not in the first two minutes | Swim again |
| O4 | Deep Pockets row (`pass_deep_pockets`) | [MVP] | Bank summary, Pearls table | Greyed row 520 × 48: pass art at 40, `bank.pass_row` | Pass not owned; third bank or later; once per session | Continue |
| O5 | Bigger Cove row (`pass_bigger_cove`) | [MVP] | Slot upgrade dialog | Row 560 × 112: pass art at 96, `pass.bigger_cove.desc`, Robux price button 200 × 72 | Pass not owned; second session or later | Dialog close |
| O6 | Tide Watcher row (`pass_tide_watcher`) | [L] | Offline claim, only when the cap was hit | One line 520 × 48: `offline.pass_row` | Pass not owned; second session or later | Claim |
| O7 | Starter Pack card (S34, `prod_starter_pack`) | [L] | Cove HUD, anchor 1,0 at `{1, -16},{0, 270}` | Card 360 × 168: `UI_Shop_StarterPack` art, `product.starter_pack`, `starter.what`, `starter.once`, Robux price button 200 × 88, close cross | Chapter 05, section 8.3: after the first bank of a session, once the bank summary has closed; from the second session on and once the account has two banks; not bought; it opens by itself in at most three sessions, then lives only in the shop | Close cross; also leaves when the player swims out |
| O8 | Shark Pup pass (`pass_shark_pup`) | [L] | Species select, bottom strip | Second button 260 × 88 beside the Pearl unlock button | Shark Pup locked and selected | Menu close |
| O9 | Call the Tide (`prod_call_tide`) | [L] | Tide popover; shop, Boosts tab | Button 320 × 72: `UI_Shop_CallTide` at 48, `product.call_tide`, Robux price | It can always be bought, whatever the tide clock shows (canon 10). The one limit is O-R1: in open water the button is greyed with `tide.go_home`. If the tide cannot start at once, the button carries `tide.will_wait` before the purchase. After the purchase the token is held (up to three per player, one starting at a time): the held-token chip shows beside the button and replaces it at three tokens (`tide.called_wait` while a tide or its warning is running, `tide.called_soon` in the 10 s before it starts) and the tide clock shows the Tide called state (3.13). | Popover close |
| O10 | Pearl packs (`prod_pearls_s`, `_m`, `_l`, `_xl`) | [MVP] | Shop, Pearls tab | Item cards (6.4) | Always in the shop | Menu close |
| O11 | Patterns | [L] | Species select and shop | Swatch or item card with Robux price | Always there | Menu close |
| O12 | Cove Boost (`prod_cove_boost`, `ad_cove_boost`) | [L] | A bubble beside the Pearl Clam; a second button on the offline claim; shop, Boosts tab | Button 260 × 72: `UI_Shop_CoveBoost` at 48, `cove.boost` with the exact Pearls. It opens the Cove Boost dialog (5.4): the video button first when a video is available, then the Robux price button. | Second session or later; the boost would pay 200 Pearls or more; today's Cove Boost is unused | Dialog close; Claim |
| O13 | Goal Reroll (`ad_goal_reroll`, `prod_goal_reroll`) | [L] | Daily, Goals tab, in the swap dialog; shop, Boosts tab | Up to two buttons 260 × 88: video icon with `goals.swap_video`; `goals.swap_buy` with the Robux price | The day's free swap is used. Video: one is available, once a day. Robux: up to three a day. | Dialog close |
| O14 | Tide board row (`pass_tide_watcher`) | [L] | Tide popover, in safe water only | One line 328 × 48: pass art at 40, `tide.board_locked`; tapping it opens the pass card in the shop | Pass not owned; second session or later | Popover close |
| O15 | Robux decorations (`deco_buy_jelly_lamp`, `deco_buy_disco_clam`, `deco_buy_mini_pickle`) | [L] | Decoration tray (5.6); shop, Decorations tab | Item card (6.4): live 3D render at 192, the name (`decoitem.<id>`), `deco.desc`, Robux price button 200 × 72. In the tray the item shows the Robux glyph and the live price, and a tap opens the same card as a dialog. | Not owned. Always there, like patterns (O11). | Dialog close; menu close; Done |

```
Starter Pack card (O7), 360 x 168                 Gulped panel row (O1), 360 x 80
+---------------------------------------[x]+      +----------------------------------------+
| +--------+  Starter Pack                 |      | (icon)  Revive                R$ price |
| |  art   |  Pearls, pattern, decoration  |      |         Keep your traits               |
| |  120   |  One time only                |      +----------------------------------------+
| +--------+           [ R$ price ]        |
+------------------------------------------+
```

## 10. PC, tablet, gamepad and console differences

Chapter 15 owns the per-platform layouts, control maps, camera differences and test checklists. This section keeps only the rules for the shared interface components: where hints sit, how the cursor behaves and how focus moves. Where it and chapter 15 differ, chapter 15 wins.

| Platform | Tag | Chapter 15 section |
|---|---|---|
| Phone | [MVP] | 3.1 (the touch control table, including the two-thumb scheme [L] and the left-handed layout [L]) |
| Tablet | [MVP] | 3.2 |
| PC and Mac, keys and mouse | [MVP] | 3.3 (the single key map) |
| Chromebook | [MVP] | 3.4 |
| Gamepad on PC | [L] | 3.3 (the single gamepad map) |
| Handheld gaming PC | [L] | 3.7 |
| Xbox, PlayStation | [P1] | 3.5, 3.6 |

### 10.1 Input detection

Two things are detected and they are independent (chapter 15, section 2.2).

- **Screen class** (phone, tablet, desktop, handheld, TV) sets scale, margins and the HUD variant. It is read from `GuiService.ViewportDisplaySize` and the viewport, at join and again whenever the viewport changes (1.2). `IsTenFootInterface` is not used on its own to detect a console.
- **Input mode** (`UserInputService.PreferredInput`: touch, keys, gamepad) sets the control scheme and the hint style (touch hand, key caps, gamepad glyphs). Hints follow the last input the player used and swap within 200 ms. Changing input never changes the scale.
- Every action is reachable with each input type. Nothing needs a hover.

### 10.2 Desktop: hints and cursor

The key map is chapter 15, section 3.3 and is not repeated here. What it changed in this chapter: Space or the left mouse button dashes; E or the right mouse button uses the ability; R toggles auto-swim; the arrow keys also steer [MVP]; there are no direct emote keys (no F1 to F6), the wheel takes 1 to 6 while T is held [L]. Esc, slash, F9, F11 and Print Screen stay with Roblox and are never bound.

This chapter owns where each key cap is drawn.

| Element | Key cap shown (keys from chapter 15) |
|---|---|
| Dash tile, ability tile | Under the tile: the key, with the mouse-button glyph beside it (`UI_Hint_MouseLeft`, `UI_Hint_MouseRight`) |
| Trait slots | Under each slot |
| Emote icon [L] | Beside the icon |
| "Biggest now" strip, tide clock, gear | Under the element |
| Close button, primary button | On the button |
| Tab column | At its two ends |
| Dock buttons, Claim all, Bubble button | On the button |
| Swim and steer | Guide layer only: four `UI_Hint_Key` caps (W, A, S, D) with `UI_Hint_MouseMove`, or `UI_Hint_KeyArrows` when the player steers with the arrow keys. The desktop first-run hint (chapter 04) teaches both. |

| Cursor rule | Detail |
|---|---|
| In a run and in the cove with nothing open | The mouse is locked to the centre and hidden; the reticle shows. All HUD actions have keys. |
| Freed | When any menu, dialog, popover or side panel is open, on the gulped panel and bank summary, in decoration mode, or while Left Alt is held |
| Cursor image | `UI_Hint_Cursor` (normal and pressed); never the Roblox arrow |
| Hover | Buttons scale to 1.04 and brighten in 80 ms with `SFX_UI_Hover`. Icon-only elements (trait, status, tier, zone) show their name in a chip after 400 ms. |
| Scroll | Mouse wheel scrolls lists; dragging also works |

### 10.3 Tablet

Phone layout with the tablet scale factor. Dash, ability and emote sit 24 rpx further from the edges. Menus keep their rpx size, so they cover a smaller share of the screen. From [L] both control schemes are offered. Chapter 15, section 3.2 has the rest.

### 10.4 Gamepad [L]; console listing [P1]

A gamepad is supported on PC and handheld PCs at [L]. Xbox and PlayStation, with the TV layout, follow at [P1] once they pass the checks on real hardware (canon 15; chapter 15, sections 3.5 and 3.6). In the MVP a gamepad may move the creature but is not supported.

The button map is chapter 15, section 3.3 (Pad column) and is not repeated here. In short: left stick swims, right stick looks, A or RT dashes, X or RB uses the ability, LT brakes, B goes back, Y is the screen's extra action, the D-pad opens trait slots and the emote wheel, LB and RB change tab in menus.

This chapter stays the reference for focus order on each screen and for on-screen prompts.

**Focus navigation**

- Uses Roblox selection (`GuiService.SelectedObject`). Every focusable element has its four neighbours set by hand (`NextSelectionUp` and so on). Nothing is left to automatic guessing.
- The focus ring is `UI_Common_FocusRing`; it moves in 80 ms and plays `SFX_UI_Focus`.
- When a screen opens, focus goes to its default. Focus cannot leave the top panel. B closes it and focus returns to the element that opened it.
- The run HUD is never focusable; every run action is a button press.
- On a TV [P1], safe frame margins grow by 5% of the screen on every side, and the Roblox chat window is never shown, whatever is decided for chat at [L] (chapter 15).

| Screen | Default focus | Order |
|---|---|---|
| Cove HUD (after View) | Creatures | Left and right along the dock. Up: Claim all. Up again: Pearls, income, slots, tide clock, settings. |
| Species select | The picked card | Left and right through cards. Down: patterns row [L], then the primary button, then the pass button. |
| Codex | First cell | LB and RB change tab. Four-way through the grid. A opens an entry; in an entry left and right step through entries. |
| Daily | First goal that can be claimed, else the first row | Up and down through rows; A claims; right or Y: swap. Gifts: left and right through days. |
| Shop | First card | LB and RB change tab. Four-way through cards. A presses the price button. |
| Specimen grid | First card | Four-way. A opens the detail. Y cycles the sort. |
| Specimen detail | Close | Down: Release (hold A). |
| Ranks | The player's own row | Up and down. A: show the way. |
| Settings | First row | Up and down through rows. Left and right change a value. A flips a toggle. |
| Gulped panel | Swim again | Up, from the bottom: Keep traits, Revive, Watch to revive. |
| Bank summary | Continue | None. In the cove-full choice: four-way through cards, down to the three buttons. |
| Confirm dialog | Cancel for release and reset; Buy for a Pearl purchase | Left and right |
| Offline claim | Claim | Right: Cove Boost |
| Continue your run (S36) | Continue your run | Left: Start fresh (hold A). |
| Tide popover | Call the Tide | Up: the Tide board row (players without Tide Watcher). The tide rows are display only. |

**On-screen prompts**

- Every focusable action shows its button glyph at 40 rpx in the element's top left corner.
- Menus add a hint bar across the bottom (full width × 56 rpx): glyph and word pairs using `pad.select`, `pad.back`, `pad.tab` and the screen's Y action.
- Xbox-style glyphs by default (`UI_Hint_PadA` and so on) [L]. A PlayStation controller gets the shape glyphs (`UI_Hint_PadCross` and so on); they are [L] too, because a PlayStation controller plugged into a PC must show them (chapter 15, section 3.6). The TV layout that uses them on a console is [P1].

## 11. Motion and feedback

### 11.1 Global rules

- Feedback starts on the press, on the client, in the same frame. Target: under 50 ms; limit: 100 ms.
- Anything that waits for the server shows a pending state (a spinner in the button) within 100 ms.
- No transition is longer than 400 ms unless it is a reward (bank summary, species unlocked).
- Easing names are Roblox `EasingStyle` and `EasingDirection` values.

### 11.2 Button states

| State | Change | Time | Easing |
|---|---|---|---|
| Hover (desktop) or focus (gamepad) | Scale 1.04, 10% brighter | 80 ms | Quad Out |
| Press | Scale 0.94, pressed sprite or 15% darker; sound and haptic fire here | 60 ms | Quad Out |
| Release | Back to scale 1.0 | 120 ms | Back Out |
| Disabled | 50% opacity, grey tint; a tap shakes it 6 rpx and plays `SFX_UI_Locked` | 160 ms | Sine InOut |
| Pending | Label swaps to `UI_Common_Spinner` turning once a second | 100 ms fade | Linear |
| Hold to confirm | Ring fills while held; early release drains it | 600 ms fill, 150 ms drain | Linear |
| Toggle | Knob slides, track changes tint | 120 ms | Quad Out |
| Slider | Knob follows the finger at once; value chip pops | 0 ms, 80 ms | Quad Out |
| Tab | Indicator slides to the new tab; content cross-fades | 160 ms, 120 ms | Quad Out |

### 11.3 Transitions

| Transition | In | Out | Easing |
|---|---|---|---|
| Scrim | 150 ms fade | 120 ms | Linear |
| Menu or dialog panel | 220 ms, scale 0.9 to 1.0 with fade | 140 ms, scale to 0.95 with fade | Back Out in, Quad In out |
| Side panel (settings) | 200 ms slide | 150 ms | Quint Out in, Quad In out |
| Popover (trait, tide) | 120 ms, scale 0.8 to 1.0 from its anchor | 90 ms | Back Out in, Quad In out |
| Emote wheel | 120 ms | 90 ms | Back Out in, Quad In out |
| Moment slot card | 180 ms, drops 24 rpx with fade | 160 ms | Back Out in, Quad In out |
| Toast | 200 ms, slides 40 rpx from the right | 180 ms | Back Out in, Quad In out |
| Run HUD to cove HUD and back | 250 ms cross-fade | | Quad InOut |
| HUD hide on gulp or bank | | 150 ms fade | Quad In |
| Mass bar fill | 150 ms | | Quad Out |
| Number pop (mass, Pearls) | 120 ms to 1.15, 120 ms back | | Back Out |
| Count-up (Pearls) | 1,000 ms (bank), 400 ms (scraps) | | Quad Out |
| Pearl sprites flying to a counter | 500 ms, 6 to 10 sprites, 40 ms apart | | Quad In |
| Tier badge swap | 300 ms | | Back Out |
| Trait pip | 180 ms pop to 1.4 | | Back Out |
| Cooldown wedge | Length of the cooldown | | Linear |
| Ready pulse | 250 ms, ring 1.0 to 1.4 with fade | | Quad Out |
| Threat arrow | 120 ms appear; pulses at 1, 2 or 4 Hz | 120 ms | Sine InOut |
| Edge marker movement | Follows its target with 100 ms smoothing | | Linear |
| Gulped title | 250 ms, scale 1.6 to 1.0 | | Back Out |
| Specimen card flip | 400 ms | | Quint Out |
| Carousel snap (species) | 220 ms | | Quint Out |
| Species unlocked fill | 1,200 ms | | Quad InOut |
| Loading screen end | | 400 ms fade | Quad Out |
| Focus ring move | 80 ms | | Quad Out |
| Guide pointer | 200 ms in; bob at 1.5 Hz | 100 ms | Sine InOut |

**Less motion (section 12):** scales and slides become 120 ms fades; no shakes; rays do not turn; nothing pulses faster than 1 Hz; count-ups jump to the final number; the gulped camera follow is cut to a fade.

### 11.4 Haptics (phones [MVP] and gamepads [L])

Off when "Vibration" is off. No haptic repeats more often than every 80 ms.

Haptics are played with Roblox `HapticEffect` types (chapter 15, section 3.1): Light = `UIClick`, Medium = `GameplayCollision`, Heavy = `GameplayExplosion` (tune). The millisecond lengths below are targets; a built-in type may not match them exactly. Known gaps: gamepads on macOS 15 and later, and gamepads paired to phones, may not vibrate.

| Event | Pattern |
|---|---|
| Any button press | Light, 10 ms |
| Dash | Medium, 30 ms |
| Bite | Light tick, 10 ms; fast bites are capped at 6 a second |
| Trait pip | Light, 10 ms |
| Trait gained | Medium, 30 ms, twice, 80 ms apart |
| Tier-up | Medium, 40 ms, twice, 100 ms apart |
| Threat under 30 studs | Light, 20 ms, twice, 120 ms apart; at most once every 2 s |
| Stunned or bitten (Plated saved you) | Heavy, 80 ms |
| Gulped | Heavy, 200 ms |
| Bank: Pearl total lands | Rising: light, medium, heavy, 80 ms apart |
| Claim, Bubble left, goal claimed | Light, 20 ms |
| Hold to confirm completes | Medium, 30 ms |
| Disabled button | Light, 10 ms, twice |

### 11.5 Sound hooks

Chapter 07 lists the sound assets; these are the names the interface calls. All are short (under 600 ms unless noted) and none is a default Roblox sound.

| Sound | Played when |
|---|---|
| `SFX_UI_Tap` | Any button press without its own sound |
| `SFX_UI_Hover` | Desktop hover (very quiet) |
| `SFX_UI_Focus` | Gamepad focus moves |
| `SFX_UI_Back` | Close or back |
| `SFX_UI_Open` | A menu, dialog or side panel opens |
| `SFX_UI_Tab` | Tab change |
| `SFX_UI_Toggle` | Toggle or picker change |
| `SFX_UI_Locked` | Tap on a disabled or locked control |
| `SFX_UI_Toast` | A toast arrives |
| `SFX_UI_Dash` | Dash pressed |
| `SFX_UI_DashReady` | Dash cooldown ends (quiet) |
| `SFX_UI_Ability` | Ability pressed |
| `SFX_UI_AbilityReady` | Ability cooldown ends |
| `SFX_UI_TraitPip` | A trait progress pip fills (pitch rises with each pip) |
| `SFX_UI_TraitGain` | Trait gained |
| `SFX_UI_TraitShed` | Trait shed |
| `SFX_UI_TraitsFull` | Trait prey eaten with three traits held |
| `SFX_UI_TierUp` | Tier-up (a longer version for tier 7, up to 1,500 ms) |
| `SFX_UI_ThreatNear` | A threat comes within 30 studs |
| `SFX_UI_Gulped` | The player is gulped |
| `SFX_UI_Revive` | A revive succeeds; a suspended run is continued (8.3) |
| `SFX_UI_BankStart` | Bank summary opens |
| `SFX_UI_PearlTick` | Each step of a Pearl count-up |
| `SFX_UI_PearlBurst` | A Pearl count-up ends |
| `SFX_UI_BankCard` | The specimen card flips in |
| `SFX_UI_CodexNew` | A new Codex entry shows |
| `SFX_UI_Release` | A specimen is released |
| `SFX_UI_Claim` | Cove income claimed |
| `SFX_UI_SlotUnlock` | A cove slot is added |
| `SFX_UI_Pick` | A species is picked |
| `SFX_UI_SpeciesUnlock` | A species is unlocked |
| `SFX_UI_GoalDone` | A goal is completed (toast) |
| `SFX_UI_GoalClaim` | A goal reward is claimed |
| `SFX_UI_StreakClaim` | A daily gift is claimed |
| `SFX_UI_Purchase` | A purchase succeeds |
| `SFX_UI_EventWarn` | Event warning banner |
| `SFX_UI_Countdown` | 3, 2, 1 before an event |
| `SFX_UI_EventStart` | An event starts |
| `SFX_UI_EventEnd` | An event ends |
| `SFX_UI_Emote` | An emote is sent or seen nearby |
| `SFX_UI_Bubble` | A Bubble is left |
| `SFX_UI_RankUp` | Reef Rank goes up |
| `SFX_UI_DecoPlace` | A decoration is placed |
| `SFX_UI_DecoStore` | A decoration is put away |
| `SFX_UI_GuideStep` | A first-time prompt step is done |
| `SFX_UI_Error` | An error toast |

## 12. Accessibility

| Area | Rule |
|---|---|
| Text size floor | 22 rpx (about 11 pt on a small phone). Nothing smaller, including legal and version text. "Bigger text" [L] multiplies all text by 1.2 and lets rows grow taller. |
| Readable at arm's length | Checked on a 4.7 inch phone held 40 cm away: tier, mass, dash state and the nearest threat arrow must be readable in a 0.5 s glance. In-run numbers are at least 28 rpx. |
| Contrast floor | Text against its background at least 4.5 to 1; icons and large numbers (28 rpx and up) at least 3 to 1. Text over the 3D world sits on a chip or has a 2 rpx dark stroke. Chapter 06 picks colours that pass. |
| Never colour alone | Every state that uses colour also changes shape, icon or position: danger has arrows and a pulse, edible has no arrow; rarity frames differ in shape as well as colour (chapter 06); a claimable row has a button, not just a glow. |
| Colour-blind outline mode | One toggle. Swaps green and red for yellow and hot pink on the outline shells (canon 5.2; chapter 06 owns the exact values) and adds `UI_HUD_MarkDanger` and `UI_HUD_MarkEdible` above creatures. The danger outline pulses in every mode, so the toggle changes colours only. Threat arrows and the vignette use hot pink too. |
| Less motion | One toggle, on by default when the device asks for reduced motion. Effects listed in 11.3. No screen shake, no flashes above 3 a second in any mode. |
| Hold or tap | Every hold has a tap alternative when "Tap instead of hold" is on: shed, release and reset become tap, then `common.yes` within 3 s. The emote wheel always works by tap. Dash and ability are taps; nothing in the game needs a held button to play. |
| One hand | Drag to swim works anywhere on the screen. Left-handed mode [L] mirrors the action buttons. |
| No time pressure in menus | No menu, offer or dialog closes by itself while the player is choosing, apart from in-run popovers that close after 4 to 6 s of no input. |
| Sound not required | Every sound cue has a visual twin (threat arrow, banner, pulse). The game is fully playable muted. |
| No chat needed | Roblox text chat is switched off in the MVP and reviewed for launch (canon 14). No instruction or feature depends on reading or typing chat. |
| Language | All text goes through Roblox localisation (section 14). Icons carry meaning wherever possible so untranslated players can still play. |
| Player names | Shown as Roblox display names, cut to 10 characters on the HUD and 16 in menus. A name enters a sentence only through a `{Name}` parameter so translators can move it. |

## 13. The complete interface image list

### 13.1 How to read the table

- **Size** is in rpx on the reference canvas. The file is exported at 2 × that size.
- **9-slice:** "Yes" means the image stretches with fixed corners (`ScaleType = Slice`). Nine-sliced images are small standalone files and are never put in an atlas, which avoids colour bleeding at the slice edges.
- **Art states** lists only states that need their own drawing. "1" means one drawing; pressed, hover and disabled are then made in code (scale, tint, opacity, section 11.2).
- **Atlas:** `Glyphs` (square cells up to 72 rpx), `Content` (96 rpx cells), `Parts` (mixed sizes), `Hints` (48 rpx cells: gamepad glyphs, plus two small [L] HUD glyphs that would not fit the third `Glyphs` sheet), or `No` (standalone file).
- **Silhouettes** (locked species, unknown Codex entries) are the normal image tinted flat dark in code. They need no extra images.
- **Asset name from an ID:** `UI_Icon_` + group + the canon ID in PascalCase. `puffer` gives `UI_Icon_SpeciesPuffer`; `zebra_darter` gives `UI_Icon_PreyZebraDarter`; `moon_tide` gives `UI_Icon_EventMoonTide`.
- `Common` and `Icon` are not screens; they hold images shared by many screens. `Hint` holds control hints.
- **No image needed for:** 3D renders of specimens, decorations and patterns (live `ViewportFrame`), scrims and dividers (plain frames), the Robux symbol (Roblox's own glyph), player pictures (never shown).

### 13.2 Shared kit (`UI_Common_`)

| Asset | Tag | Shows | Size (rpx) | 9-slice | Art states | Atlas |
|---|---|---|---|---|---|---|
| `UI_Common_PanelLarge` | [MVP] | Menu and dialog panel background | 96x96 | Yes | 1 | No |
| `UI_Common_PanelSmall` | [MVP] | Popover, toast, card and row background | 64x64 | Yes | 1 | No |
| `UI_Common_PanelInset` | [MVP] | Sunken well inside a panel (lists, tables) | 48x48 | Yes | 1 | No |
| `UI_Common_Chip` | [MVP] | Pill behind HUD numbers and short labels | 48x40 | Yes | 1 | No |
| `UI_Common_Ribbon` | [MVP] | Title ribbon for moments | 160x72 | Yes | 1 | No |
| `UI_Common_ButtonPrimary` | [MVP] | Main action button | 96x88 | Yes | normal, pressed, disabled | No |
| `UI_Common_ButtonSecondary` | [MVP] | Second-rank button | 96x88 | Yes | normal, pressed, disabled | No |
| `UI_Common_ButtonRobux` | [MVP] | Robux purchase button | 96x72 | Yes | normal, pressed, disabled | No |
| `UI_Common_ButtonVideo` | [L] | Rewarded video button | 96x72 | Yes | normal, pressed | No |
| `UI_Common_ButtonRound` | [MVP] | Round button base (dock, decoration tools) | 88x88 | No | normal, pressed | Parts |
| `UI_Common_TabActive` | [MVP] | Selected tab background | 96x88 | Yes | 1 | No |
| `UI_Common_TabIdle` | [MVP] | Unselected tab background | 96x88 | Yes | 1 | No |
| `UI_Common_BarTrack` | [MVP] | Progress bar track | 32x28 | Yes | 1 | No |
| `UI_Common_BarFill` | [MVP] | Progress bar fill, tinted in code | 32x28 | Yes | 1 | No |
| `UI_Common_SliderTrack` | [MVP] | Slider track | 32x16 | Yes | 1 | No |
| `UI_Common_ScrollBar` | [MVP] | Scroll bar thumb | 12x32 | Yes | 1 | No |
| `UI_Common_FocusRing` | [L] | Gamepad focus ring | 64x64 | Yes | 1 | No |
| `UI_Common_Close` | [MVP] | Close cross | 56x56 | No | normal, pressed | Glyphs |
| `UI_Common_Arrow` | [MVP] | Step arrow (flipped in code) | 48x48 | No | 1 | Glyphs |
| `UI_Common_Pip` | [MVP] | Progress pip | 20x20 | No | empty, full | Glyphs |
| `UI_Common_Badge` | [MVP] | Red dot for free things waiting | 32x32 | No | 1 | Glyphs |
| `UI_Common_Lock` | [MVP] | Padlock | 48x48 | No | 1 | Glyphs |
| `UI_Common_Check` | [MVP] | Tick | 64x64 | No | 1 | Glyphs |
| `UI_Common_New` | [MVP] | Burst behind the word "New!" | 56x56 | No | 1 | Glyphs |
| `UI_Common_Plus` | [MVP] | Plus sign | 40x40 | No | 1 | Glyphs |
| `UI_Common_Info` | [MVP] | Information mark | 48x48 | No | 1 | Glyphs |
| `UI_Common_Video` | [L] | Rewarded video mark | 48x48 | No | 1 | Glyphs |
| `UI_Common_Spinner` | [MVP] | Ring of bubbles that turns while waiting | 48x48 | No | 1 | Glyphs |
| `UI_Common_SliderKnob` | [MVP] | Slider knob | 48x48 | No | normal, pressed | Glyphs |
| `UI_Common_Toggle` | [MVP] | Toggle track with knob | 96x48 | No | off, on | Parts |
| `UI_Common_BubbleTail` | [MVP] | Tail for speech bubbles and popovers | 24x16 | No | 1 | Glyphs |
| `UI_Common_Timer` | [MVP] | Small clock beside countdown text | 32x32 | No | 1 | Glyphs |
| `UI_Common_Mass` | [MVP] | Mass symbol | 48x48 | No | 1 | Glyphs |
| `UI_Common_Bubble` | [L] | Bubble (a like) | 64x64 | No | 1 | Glyphs |
| `UI_Common_Pearl` | [MVP] | Pearl, the currency | 96x96 | No | 1 | Content |
| `UI_Common_PearlPile` | [MVP] | Pile of Pearls for rewards | 96x96 | No | 1 | Content |
| `UI_Common_RingHalf` | [MVP] | Half a progress ring; two make a round fill | 48x96 | No | 1 | Parts |
| `UI_Common_RingPulse` | [MVP] | Ring that expands when something is ready | 128x128 | No | 1 | Parts |
| `UI_Common_Glow` | [MVP] | Soft round glow, tinted in code | 128x128 | No | 1 | Parts |
| `UI_Common_Shine` | [MVP] | Diagonal shine that sweeps across buttons | 64x128 | No | 1 | Parts |
| `UI_Common_Sparkle` | [MVP] | Sheet of four bubble and sparkle particles | 64x64 | No | 1 | Parts |
| `UI_Common_Rays` | [MVP] | Ray burst that turns behind rewards | 384x384 | No | 1 | No |
| `UI_Common_RarityCommon` | [MVP] | Trait frame, Common | 88x88 | No | 1 | Parts |
| `UI_Common_RarityUncommon` | [MVP] | Trait frame, Uncommon | 88x88 | No | 1 | Parts |
| `UI_Common_RarityRare` | [MVP] | Trait frame, Rare | 88x88 | No | 1 | Parts |
| `UI_Common_RarityEpic` | [MVP] | Trait frame, Epic | 88x88 | No | 1 | Parts |
| `UI_Common_RarityMythic` | [MVP] | Trait frame, Mythic | 88x88 | No | 1 | Parts |

### 13.3 Content icons (`UI_Icon_`)

All 96x96 rpx, not nine-sliced, one art state, `Content` atlas.

| Asset | Tag | Shows | Size (rpx) | 9-slice | Art states | Atlas |
|---|---|---|---|---|---|---|
| `UI_Icon_Tier1` | [MVP] | Tier badge: Fry | 96x96 | No | 1 | Content |
| `UI_Icon_Tier2` | [MVP] | Tier badge: Nibbler | 96x96 | No | 1 | Content |
| `UI_Icon_Tier3` | [MVP] | Tier badge: Snapper | 96x96 | No | 1 | Content |
| `UI_Icon_Tier4` | [MVP] | Tier badge: Hunter | 96x96 | No | 1 | Content |
| `UI_Icon_Tier5` | [MVP] | Tier badge: Brute | 96x96 | No | 1 | Content |
| `UI_Icon_Tier6` | [MVP] | Tier badge: Titan | 96x96 | No | 1 | Content |
| `UI_Icon_Tier7` | [MVP] | Tier badge: Leviathan | 96x96 | No | 1 | Content |
| `UI_Icon_SpeciesMinnow` | [MVP] | Minnow head | 96x96 | No | 1 | Content |
| `UI_Icon_SpeciesPuffer` | [MVP] | Pufferfish head | 96x96 | No | 1 | Content |
| `UI_Icon_SpeciesEel` | [MVP] | Eel head | 96x96 | No | 1 | Content |
| `UI_Icon_SpeciesTurtle` | [L] | Sea Turtle head | 96x96 | No | 1 | Content |
| `UI_Icon_SpeciesSquid` | [L] | Squid head | 96x96 | No | 1 | Content |
| `UI_Icon_SpeciesShark` | [L] | Shark Pup head | 96x96 | No | 1 | Content |
| `UI_Icon_AbilityDart` | [MVP] | Ability: Dart | 96x96 | No | 1 | Content |
| `UI_Icon_AbilityPuff` | [MVP] | Ability: Puff | 96x96 | No | 1 | Content |
| `UI_Icon_AbilitySlip` | [MVP] | Ability: Slip | 96x96 | No | 1 | Content |
| `UI_Icon_AbilityShell` | [L] | Ability: Shell | 96x96 | No | 1 | Content |
| `UI_Icon_AbilityJet` | [L] | Ability: Jet | 96x96 | No | 1 | Content |
| `UI_Icon_AbilityRampage` | [L] | Ability: Rampage (Shark Pup) | 96x96 | No | 1 | Content |
| `UI_Icon_TraitGlow` | [MVP] | Trait: Glow | 96x96 | No | 1 | Content |
| `UI_Icon_TraitStripes` | [MVP] | Trait: Stripes | 96x96 | No | 1 | Content |
| `UI_Icon_TraitSpots` | [MVP] | Trait: Spots | 96x96 | No | 1 | Content |
| `UI_Icon_TraitPlated` | [MVP] | Trait: Plated | 96x96 | No | 1 | Content |
| `UI_Icon_TraitPlatedCracked` | [MVP] | Trait: Plated after it has been used | 96x96 | No | 1 | Content |
| `UI_Icon_TraitSpiny` | [MVP] | Trait: Spiny | 96x96 | No | 1 | Content |
| `UI_Icon_TraitLongfin` | [MVP] | Trait: Longfin | 96x96 | No | 1 | Content |
| `UI_Icon_TraitInk` | [MVP] | Trait: Ink | 96x96 | No | 1 | Content |
| `UI_Icon_TraitCrystal` | [MVP] | Trait: Crystal | 96x96 | No | 1 | Content |
| `UI_Icon_TraitMoonlit` | [MVP] | Trait: Moonlit | 96x96 | No | 1 | Content |
| `UI_Icon_TraitSpark` | [L] | Trait: Spark | 96x96 | No | 1 | Content |
| `UI_Icon_TraitCamo` | [L] | Trait: Camo | 96x96 | No | 1 | Content |
| `UI_Icon_TraitEmber` | [L] | Trait: Ember | 96x96 | No | 1 | Content |
| `UI_Icon_TraitBonefed` | [L] | Trait: Bonefed | 96x96 | No | 1 | Content |
| `UI_Icon_PreyPlankton` | [MVP] | Prey: Plankton mote | 96x96 | No | 1 | Content |
| `UI_Icon_PreyKrill` | [MVP] | Prey: Krill | 96x96 | No | 1 | Content |
| `UI_Icon_PreyShrimp` | [MVP] | Prey: Tiny Shrimp | 96x96 | No | 1 | Content |
| `UI_Icon_PreySardine` | [MVP] | Prey: Sardine | 96x96 | No | 1 | Content |
| `UI_Icon_PreyDarter` | [MVP] | Prey: Reef Darter | 96x96 | No | 1 | Content |
| `UI_Icon_PreyMackerel` | [MVP] | Prey: Mackerel | 96x96 | No | 1 | Content |
| `UI_Icon_PreyBonito` | [MVP] | Prey: Bonito | 96x96 | No | 1 | Content |
| `UI_Icon_PreyTuna` | [MVP] | Prey: Tuna | 96x96 | No | 1 | Content |
| `UI_Icon_PreyGlowfry` | [MVP] | Trait prey: Glowfry | 96x96 | No | 1 | Content |
| `UI_Icon_PreyZebraDarter` | [MVP] | Trait prey: Zebra Darter | 96x96 | No | 1 | Content |
| `UI_Icon_PreyDottedGoby` | [MVP] | Trait prey: Dotted Goby | 96x96 | No | 1 | Content |
| `UI_Icon_PreyArmorShrimp` | [MVP] | Trait prey: Armor Shrimp | 96x96 | No | 1 | Content |
| `UI_Icon_PreyUrchinPuff` | [MVP] | Trait prey: Urchin Puff | 96x96 | No | 1 | Content |
| `UI_Icon_PreyRibbonfish` | [MVP] | Trait prey: Ribbonfish | 96x96 | No | 1 | Content |
| `UI_Icon_PreyInklet` | [MVP] | Trait prey: Inklet | 96x96 | No | 1 | Content |
| `UI_Icon_PreyCrystalJelly` | [MVP] | Trait prey: Crystal Jelly | 96x96 | No | 1 | Content |
| `UI_Icon_PreyLunarFry` | [MVP] | Trait prey: Lunar Fry | 96x96 | No | 1 | Content |
| `UI_Icon_PreySparkEel` | [L] | Trait prey: Spark Eel | 96x96 | No | 1 | Content |
| `UI_Icon_PreyLeafDrifter` | [L] | Trait prey: Leaf Drifter | 96x96 | No | 1 | Content |
| `UI_Icon_PreyVentSnail` | [L] | Trait prey: Vent Snail | 96x96 | No | 1 | Content |
| `UI_Icon_PreyMarrow` | [L] | Trait prey: Marrow chunk | 96x96 | No | 1 | Content |
| `UI_Icon_PredGull` | [MVP] | Predator: Gull | 96x96 | No | 1 | Content |
| `UI_Icon_PredMoray` | [MVP] | Predator: Moray | 96x96 | No | 1 | Content |
| `UI_Icon_PredBarracuda` | [MVP] | Predator: Barracuda | 96x96 | No | 1 | Content |
| `UI_Icon_PredOldScar` | [MVP] | Predator: Old Scar | 96x96 | No | 1 | Content |
| `UI_Icon_PredGrouper` | [L] | Predator: Grouper | 96x96 | No | 1 | Content |
| `UI_Icon_HazardJellyBloom` | [L] | Hazard: Jelly bloom (Codex Dangers tab) | 96x96 | No | 1 | Content |
| `UI_Icon_HazardHook` | [L] | Hazard: Fishing hook (Codex Dangers tab) | 96x96 | No | 1 | Content |
| `UI_Icon_HazardAnemone` | [L] | Hazard: Anemone (Codex Dangers tab) | 96x96 | No | 1 | Content |
| `UI_Icon_HazardVent` | [L] | Hazard: Thermal vent (Codex Dangers tab) | 96x96 | No | 1 | Content |
| `UI_Icon_EventFrenzy` | [MVP] | Event: Feeding Frenzy | 96x96 | No | 1 | Content |
| `UI_Icon_EventMoonTide` | [MVP] | Event: Moon Tide | 96x96 | No | 1 | Content |
| `UI_Icon_EventWhaleFall` | [L] | Event: Whale Fall | 96x96 | No | 1 | Content |

### 13.4 Run HUD (`UI_HUD_`) and emote wheel (`UI_Emote_`)

| Asset | Tag | Shows | Size (rpx) | 9-slice | Art states | Atlas |
|---|---|---|---|---|---|---|
| `UI_HUD_MassBarFrame` | [MVP] | Mass bar frame | 96x40 | Yes | 1 | No |
| `UI_HUD_MassBarFill` | [MVP] | Mass bar fill, tinted in code (gold at tier 7) | 32x28 | Yes | 1 | No |
| `UI_HUD_GoalArrow` | [MVP] | Small arrow before the mass still needed | 20x20 | No | 1 | Glyphs |
| `UI_HUD_Crown` | [MVP] | Crown: tier 7 reached; rank 1 on the strip | 44x44 | No | 1 | Glyphs |
| `UI_HUD_SpecimenLight` | [MVP] | Small fish: this run would become a specimen | 32x32 | No | dim, lit | Glyphs |
| `UI_HUD_TraitSlotEmpty` | [MVP] | Empty trait slot (dashed ring) | 80x80 | No | 1 | Parts |
| `UI_HUD_Shed` | [MVP] | Shed symbol on the Shed button | 48x48 | No | 1 | Glyphs |
| `UI_HUD_TraitLockTag` | [L] | Small lock: this run started with kept traits (Trait Lock) | 40x40 | No | 1 | Glyphs |
| `UI_HUD_DashButton` | [MVP] | Dash button with its symbol | 136x136 | No | normal, pressed | Parts |
| `UI_HUD_AbilityButton` | [MVP] | Ability button base (icon added in code) | 108x108 | No | normal, pressed | Parts |
| `UI_HUD_AbilityPassive` | [MVP] | Badge base for abilities with nothing to press | 72x72 | No | 1 | Parts |
| `UI_HUD_CooldownHalf` | [MVP] | Half of the dark cooldown wedge | 68x136 | No | 1 | Parts |
| `UI_HUD_HintTile` | [MVP] | Desktop tile behind the dash and ability hints | 80x96 | Yes | 1 | No |
| `UI_HUD_ThreatArrow` | [MVP] | Edge arrow toward a threat | 88x88 | No | 1 | Parts |
| `UI_HUD_ThreatArrowBoss` | [MVP] | Edge arrow for Old Scar | 96x96 | No | 1 | Parts |
| `UI_HUD_ThreatVignette` | [MVP] | Edge vignette, stretched over the screen | 320x180 | No | 1 | No |
| `UI_HUD_TraitMarker` | [MVP] | Edge marker for trait prey (Glow) | 44x44 | No | 1 | Glyphs |
| `UI_HUD_HomeMarker` | [MVP] | Home marker | 72x72 | No | normal, best | Glyphs |
| `UI_HUD_HomePointer` | [MVP] | Pointer that orbits the home marker | 24x24 | No | 1 | Glyphs |
| `UI_HUD_MarkDanger` | [MVP] | Colour-blind mode: mark above a threat | 40x40 | No | 1 | Glyphs |
| `UI_HUD_MarkEdible` | [MVP] | Colour-blind mode: mark above edible players and trait prey | 32x32 | No | 1 | Glyphs |
| `UI_HUD_TideClockFrame` | [MVP] | Tide clock face | 80x80 | No | 1 | Parts |
| `UI_HUD_TideMarker` | [L] | Edge marker pointing to the tide's site (Tide Watcher) | 56x56 | No | 1 | Glyphs |
| `UI_HUD_TideToken` | [L] | Token: a called tide is held and waiting | 40x40 | No | 1 | Hints |
| `UI_HUD_WildTag` | [L] | Leaf on the name tag of a wild creature | 28x28 | No | 1 | Hints |
| `UI_HUD_RowSelf` | [MVP] | Highlight behind the player's own row | 32x36 | Yes | 1 | No |
| `UI_HUD_Settings` | [MVP] | Gear button | 56x56 | No | normal, pressed | Glyphs |
| `UI_HUD_Lag` | [MVP] | Weak connection | 40x40 | No | 1 | Glyphs |
| `UI_HUD_SafeBadge` | [MVP] | Safe water badge | 56x56 | No | 1 | Glyphs |
| `UI_HUD_StatusStun` | [MVP] | Status: stunned | 48x48 | No | 1 | Glyphs |
| `UI_HUD_StatusShield` | [MVP] | Status: protected | 48x48 | No | 1 | Glyphs |
| `UI_HUD_StatusHidden` | [MVP] | Status: hidden | 48x48 | No | 1 | Glyphs |
| `UI_HUD_StatusSlow` | [L] | Status: slowed | 48x48 | No | 1 | Glyphs |
| `UI_HUD_StatusBurn` | [L] | Status: burning | 48x48 | No | 1 | Glyphs |
| `UI_HUD_StatusSpeed` | [L] | Status: sped up | 48x48 | No | 1 | Glyphs |
| `UI_HUD_DragRing` | [MVP] | Ring under the steering thumb | 168x168 | No | 1 | Parts |
| `UI_HUD_DragKnob` | [MVP] | Knob that follows the steering thumb | 72x72 | No | 1 | Glyphs |
| `UI_HUD_Reticle` | [MVP] | Desktop aim dot | 32x32 | No | 1 | Glyphs |
| `UI_HUD_EmoteButton` | [L] | Emote button | 72x72 | No | normal, pressed | Glyphs |
| `UI_Emote_Wheel` | [L] | Emote wheel ring | 360x360 | No | 1 | No |
| `UI_Emote_Slot` | [L] | Emote slot | 96x96 | No | normal, selected | Parts |
| `UI_Emote_WorldBubble` | [L] | Bubble above a creature that holds an emote | 112x104 | No | 1 | Parts |
| `UI_Emote_Hi` | [L] | Emote `em_hi`: a waving fin | 72x72 | No | 1 | Glyphs |
| `UI_Emote_ThisWay` | [L] | Emote `em_this_way`: an arrow | 72x72 | No | 1 | Glyphs |
| `UI_Emote_LookOut` | [L] | Emote `em_look_out`: a red exclamation mark in a spiky bubble | 72x72 | No | 1 | Glyphs |
| `UI_Emote_Thanks` | [L] | Emote `em_thanks`: a pink heart | 72x72 | No | 1 | Glyphs |
| `UI_Emote_HaHa` | [L] | Emote `em_ha_ha`: a laughing fish face | 72x72 | No | 1 | Glyphs |
| `UI_Emote_Oops` | [L] | Emote `em_oops`: a fish face with a sweat drop | 72x72 | No | 1 | Glyphs |

### 13.5 Moments (`UI_Moment_`)

| Asset | Tag | Shows | Size (rpx) | 9-slice | Art states | Atlas |
|---|---|---|---|---|---|---|
| `UI_Moment_GulpedSplat` | [MVP] | Bubble burst behind the gulped title (no lettering) | 512x200 | No | 1 | No |
| `UI_Moment_Scraps` | [MVP] | Scraps: a few scattered Pearls | 64x64 | No | 1 | Glyphs |
| `UI_Moment_Revive` | [MVP] | Revive symbol | 64x64 | No | 1 | Glyphs |
| `UI_Moment_TraitLock` | [L] | Keep traits symbol (Trait Lock): a lock on a trait frame | 64x64 | No | 1 | Glyphs |
| `UI_Moment_BankShell` | [MVP] | Open shell full of Pearls for the bank summary | 256x144 | No | 1 | No |
| `UI_Moment_PersonalBest` | [MVP] | Medal for a best run | 64x64 | No | 1 | Glyphs |
| `UI_Moment_CodexStamp` | [MVP] | "New in Codex" stamp | 64x64 | No | 1 | Glyphs |
| `UI_Moment_GoalStamp` | [MVP] | Goal done stamp | 72x72 | No | 1 | Glyphs |
| `UI_Moment_Release` | [MVP] | Release symbol (creature swimming out) | 48x48 | No | 1 | Glyphs |
| `UI_Moment_EventFrenzy` | [MVP] | Event start art: Feeding Frenzy | 480x112 | No | 1 | No |
| `UI_Moment_EventMoonTide` | [MVP] | Event start art: Moon Tide | 480x112 | No | 1 | No |
| `UI_Moment_EventWhaleFall` | [L] | Event start art: Whale Fall | 480x112 | No | 1 | No |

### 13.6 Cove (`UI_Cove_`)

| Asset | Tag | Shows | Size (rpx) | 9-slice | Art states | Atlas |
|---|---|---|---|---|---|---|
| `UI_Cove_DockSpecies` | [MVP] | Dock and menu title: Creatures | 56x56 | No | 1 | Glyphs |
| `UI_Cove_DockCodex` | [MVP] | Dock and menu title: Codex | 56x56 | No | 1 | Glyphs |
| `UI_Cove_DockDaily` | [MVP] | Dock and menu title: Daily | 56x56 | No | 1 | Glyphs |
| `UI_Cove_DockShop` | [MVP] | Dock and menu title: Shop | 56x56 | No | 1 | Glyphs |
| `UI_Cove_DockRanks` | [L] | Dock and menu title: Ranks | 56x56 | No | 1 | Glyphs |
| `UI_Cove_DockDeco` | [L] | Dock: Decorate. Also the shop tab: Decorations | 56x56 | No | 1 | Glyphs |
| `UI_Cove_CardPlain` | [MVP] | Specimen card frame, no traits | 96x128 | Yes | 1 | No |
| `UI_Cove_CardCommon` | [MVP] | Specimen card frame, Common | 96x128 | Yes | 1 | No |
| `UI_Cove_CardUncommon` | [MVP] | Specimen card frame, Uncommon | 96x128 | Yes | 1 | No |
| `UI_Cove_CardRare` | [MVP] | Specimen card frame, Rare | 96x128 | Yes | 1 | No |
| `UI_Cove_CardEpic` | [MVP] | Specimen card frame, Epic | 96x128 | Yes | 1 | No |
| `UI_Cove_CardMythic` | [MVP] | Specimen card frame, Mythic | 96x128 | Yes | 1 | No |
| `UI_Cove_SlotEmpty` | [MVP] | Empty cove slot | 96x128 | Yes | 1 | No |
| `UI_Cove_Nameplate` | [MVP] | Plate at a cove mouth | 128x64 | Yes | 1 | No |
| `UI_Cove_StarBest` | [MVP] | Star on the best specimen | 40x40 | No | 1 | Glyphs |
| `UI_Cove_PerHour` | [MVP] | Pearl with a small clock (Pearls an hour) | 40x40 | No | 1 | Glyphs |
| `UI_Cove_IncomeBubble` | [MVP] | Bubble with a Pearl inside, above the Pearl pile | 72x72 | No | 1 | Glyphs |
| `UI_Cove_OfflineArt` | [MVP] | Sleeping creature beside a heap of Pearls | 256x160 | No | 1 | No |
| `UI_Cove_SlotArt` | [MVP] | A new shelf opening in the cove wall | 256x160 | No | 1 | No |
| `UI_Cove_DecoCell` | [L] | Grid cell highlight, tinted valid or invalid | 64x64 | Yes | 1 | No |
| `UI_Cove_DecoMove` | [L] | Decoration tool: move | 56x56 | No | 1 | Glyphs |
| `UI_Cove_DecoTurn` | [L] | Decoration tool: turn | 56x56 | No | 1 | Glyphs |
| `UI_Cove_DecoStore` | [L] | Decoration tool: put away | 56x56 | No | 1 | Glyphs |
| `UI_Cove_VisitEye` | [L] | Eye: you are visiting | 40x40 | No | 1 | Glyphs |
| `UI_Cove_BubbleButton` | [L] | Leave a Bubble button | 120x120 | No | ready, pressed, done | Parts |

### 13.7 Species select (`UI_Species_`) and Codex (`UI_Codex_`)

| Asset | Tag | Shows | Size (rpx) | 9-slice | Art states | Atlas |
|---|---|---|---|---|---|---|
| `UI_Species_PortraitMinnow` | [MVP] | Painted portrait: Minnow | 256x256 | No | 1 | No |
| `UI_Species_PortraitPuffer` | [MVP] | Painted portrait: Pufferfish | 256x256 | No | 1 | No |
| `UI_Species_PortraitEel` | [MVP] | Painted portrait: Eel | 256x256 | No | 1 | No |
| `UI_Species_PortraitTurtle` | [L] | Painted portrait: Sea Turtle | 256x256 | No | 1 | No |
| `UI_Species_PortraitSquid` | [L] | Painted portrait: Squid | 256x256 | No | 1 | No |
| `UI_Species_PortraitShark` | [L] | Painted portrait: Shark Pup | 256x256 | No | 1 | No |
| `UI_Species_Card` | [MVP] | Species card frame | 96x128 | Yes | normal, selected | No |
| `UI_Species_PassTag` | [L] | Tag: can be bought as a game pass | 48x48 | No | 1 | Glyphs |
| `UI_Species_PatternFrame` | [L] | Pattern swatch frame | 72x72 | Yes | normal, picked | No |
| `UI_Codex_TabSpecies` | [MVP] | Tab: Creatures | 48x48 | No | 1 | Glyphs |
| `UI_Codex_TabTiers` | [MVP] | Tab: Tiers (a row of badges that grow) | 48x48 | No | 1 | Glyphs |
| `UI_Codex_TabTraits` | [MVP] | Tab: Traits | 48x48 | No | 1 | Glyphs |
| `UI_Codex_TabPrey` | [MVP] | Tab: Prey | 48x48 | No | 1 | Glyphs |
| `UI_Codex_TabDangers` | [L] | Tab: Dangers | 48x48 | No | 1 | Glyphs |
| `UI_Codex_TabPlaces` | [L] | Tab: Places | 48x48 | No | 1 | Glyphs |
| `UI_Codex_TabTides` | [L] | Tab: Tides | 48x48 | No | 1 | Glyphs |
| `UI_Codex_Cell` | [MVP] | Codex grid cell | 64x72 | Yes | 1 | No |
| `UI_Codex_ZoneNursery` | [MVP] | Zone: Nursery Lagoon | 48x48 | No | 1 | Glyphs |
| `UI_Codex_ZoneReef` | [MVP] | Zone: Sunlit Reef | 48x48 | No | 1 | Glyphs |
| `UI_Codex_ZoneKelp` | [MVP] | Zone: Kelp Forest | 48x48 | No | 1 | Glyphs |
| `UI_Codex_ZoneDropoff` | [MVP] | Zone: The Drop-off | 48x48 | No | 1 | Glyphs |
| `UI_Codex_ZoneTrench` | [P2] | Zone: The Trench | 48x48 | No | 1 | Glyphs |

### 13.8 Daily (`UI_Daily_`, `UI_Streak_`), Ranks and Reef Rank (`UI_Rank_`, one group for the leaderboard and the rank track)

| Asset | Tag | Shows | Size (rpx) | 9-slice | Art states | Atlas |
|---|---|---|---|---|---|---|
| `UI_Daily_TabGoals` | [MVP] | Tab: Goals | 48x48 | No | 1 | Glyphs |
| `UI_Daily_TabGifts` | [L] | Tab: Gifts | 48x48 | No | 1 | Glyphs |
| `UI_Daily_GoalEat` | [MVP] | Goal type: eat | 72x72 | No | 1 | Glyphs |
| `UI_Daily_GoalGrow` | [MVP] | Goal type: reach a tier | 72x72 | No | 1 | Glyphs |
| `UI_Daily_GoalBank` | [MVP] | Goal type: bank | 72x72 | No | 1 | Glyphs |
| `UI_Daily_GoalTrait` | [MVP] | Goal type: gain a trait | 72x72 | No | 1 | Glyphs |
| `UI_Daily_GoalEvent` | [MVP] | Goal type: join a tide event | 72x72 | No | 1 | Glyphs |
| `UI_Daily_GoalExplore` | [MVP] | Goal type: visit a zone | 72x72 | No | 1 | Glyphs |
| `UI_Daily_GoalBubble` | [L] | Goal type: leave a Bubble | 72x72 | No | 1 | Glyphs |
| `UI_Daily_Swap` | [MVP] | Swap this goal (two curved arrows) | 48x48 | No | 1 | Glyphs |
| `UI_Streak_Cell` | [L] | Gift calendar cell | 64x88 | Yes | later, today, claimed | No |
| `UI_Streak_GiftBig` | [L] | Day 7 gift | 128x128 | No | 1 | Parts |
| `UI_Streak_Flame` | [L] | Gift calendar day count symbol | 48x48 | No | 1 | Glyphs |
| `UI_Rank_TabHere` | [L] | Tab: Here now | 48x48 | No | 1 | Glyphs |
| `UI_Rank_TabWeek` | [L] | Tab: This week | 48x48 | No | 1 | Glyphs |
| `UI_Rank_TabBubbles` | [L] | Tab: Most Bubbles | 48x48 | No | 1 | Glyphs |
| `UI_Rank_Medal1` | [L] | Medal: first | 48x48 | No | 1 | Glyphs |
| `UI_Rank_Medal2` | [L] | Medal: second | 48x48 | No | 1 | Glyphs |
| `UI_Rank_Medal3` | [L] | Medal: third | 48x48 | No | 1 | Glyphs |
| `UI_Rank_Badge` | [L] | Reef Rank badge (number added in code) | 128x128 | No | 1 | Parts |
| `UI_Rank_Node` | [L] | Node on the rank track | 48x48 | No | reached, next, locked | Glyphs |
| `UI_Rank_Title` | [L] | Reward type: title | 48x48 | No | 1 | Glyphs |

### 13.9 Shop (`UI_Shop_`)

| Asset | Tag | Shows | Size (rpx) | 9-slice | Art states | Atlas |
|---|---|---|---|---|---|---|
| `UI_Shop_TabPasses` | [MVP] | Tab: Passes | 48x48 | No | 1 | Glyphs |
| `UI_Shop_TabPearls` | [MVP] | Tab: Pearls | 48x48 | No | 1 | Glyphs |
| `UI_Shop_TabBoosts` | [L] | Tab: Boosts | 48x48 | No | 1 | Glyphs |
| `UI_Shop_TabPatterns` | [L] | Tab: Patterns | 48x48 | No | 1 | Glyphs |
| `UI_Shop_Card` | [MVP] | Item card frame | 96x128 | Yes | normal, owned | No |
| `UI_Shop_PassDeepPockets` | [MVP] | Pass art: Deep Pockets | 192x192 | No | 1 | No |
| `UI_Shop_PassBiggerCove` | [MVP] | Pass art: Bigger Cove | 192x192 | No | 1 | No |
| `UI_Shop_PassTideWatcher` | [L] | Pass art: Tide Watcher | 192x192 | No | 1 | No |
| `UI_Shop_PassKeenNose` | [L] | Pass art: Keen Nose | 192x192 | No | 1 | No |
| `UI_Shop_PassSharkPup` | [L] | Pass art: Shark Pup | 192x192 | No | 1 | No |
| `UI_Shop_PearlsS` | [MVP] | Pearl pack `prod_pearls_s`: small | 192x192 | No | 1 | No |
| `UI_Shop_PearlsM` | [MVP] | Pearl pack `prod_pearls_m`: medium | 192x192 | No | 1 | No |
| `UI_Shop_PearlsL` | [MVP] | Pearl pack `prod_pearls_l`: large | 192x192 | No | 1 | No |
| `UI_Shop_PearlsXL` | [MVP] | Pearl pack `prod_pearls_xl`: extra large | 192x192 | No | 1 | No |
| `UI_Shop_CallTide` | [L] | Product art: Call the Tide | 192x192 | No | 1 | No |
| `UI_Shop_CoveBoost` | [L] | Product art: Cove Boost | 192x192 | No | 1 | No |
| `UI_Shop_GoalReroll` | [L] | Product art: Goal Reroll | 192x192 | No | 1 | No |
| `UI_Shop_StarterPack` | [L] | Starter Pack art | 192x192 | No | 1 | No |
| `UI_Shop_PrivateServer` | [L] | Private reef art | 192x192 | No | 1 | No |

### 13.10 Settings (`UI_Settings_`)

| Asset | Tag | Shows | Size (rpx) | 9-slice | Art states | Atlas |
|---|---|---|---|---|---|---|
| `UI_Settings_Controls` | [L] | Row icon: controls | 48x48 | No | 1 | Glyphs |
| `UI_Settings_LeftHand` | [L] | Row icon: left-handed | 48x48 | No | 1 | Glyphs |
| `UI_Settings_LookSpeed` | [MVP] | Row icon: drag sensitivity and every look speed row | 48x48 | No | 1 | Glyphs |
| `UI_Settings_Flip` | [MVP] | Row icon: flip up and down | 48x48 | No | 1 | Glyphs |
| `UI_Settings_Sound` | [MVP] | Row icon: sounds | 48x48 | No | 1 | Glyphs |
| `UI_Settings_Music` | [MVP] | Row icon: music | 48x48 | No | 1 | Glyphs |
| `UI_Settings_Graphics` | [MVP] | Row icon: graphics | 48x48 | No | 1 | Glyphs |
| `UI_Settings_Outline` | [MVP] | Row icon: colour-blind outlines | 48x48 | No | 1 | Glyphs |
| `UI_Settings_Motion` | [MVP] | Row icon: less motion | 48x48 | No | 1 | Glyphs |
| `UI_Settings_Vibration` | [MVP] | Row icon: vibration | 48x48 | No | 1 | Glyphs |
| `UI_Settings_HoldTap` | [MVP] | Row icon: tap instead of hold | 48x48 | No | 1 | Glyphs |
| `UI_Settings_TextSize` | [L] | Row icon: bigger text | 48x48 | No | 1 | Glyphs |
| `UI_Settings_Language` | [L] | Row icon: language | 48x48 | No | 1 | Glyphs |
| `UI_Settings_PrivateReef` | [L] | Row icon: private reef | 48x48 | No | 1 | Glyphs |
| `UI_Settings_InterfaceSize` | [L] | Row icon: interface size | 48x48 | No | 1 | Glyphs |
| `UI_Settings_SwapSticks` | [L] | Row icon: swap sticks | 48x48 | No | 1 | Glyphs |
| `UI_Settings_SchemeDrag` | [L] | Picture of the drag-to-swim scheme (the picker arrives with the second scheme) | 280x160 | No | 1 | No |
| `UI_Settings_SchemeTwoThumb` | [L] | Picture of the two-thumb scheme | 280x160 | No | 1 | No |

### 13.11 Guide kit (`UI_Guide_`) and loading (`UI_Load_`)

| Asset | Tag | Shows | Size (rpx) | 9-slice | Art states | Atlas |
|---|---|---|---|---|---|---|
| `UI_Guide_Arrow` | [MVP] | Pointing arrow | 96x96 | No | 1 | Parts |
| `UI_Guide_ArrowCurved` | [MVP] | Curved arrow from a bubble to its target | 128x128 | No | 1 | Parts |
| `UI_Guide_Hand` | [MVP] | Hand with one finger out | 112x112 | No | up, down | Parts |
| `UI_Guide_TrailDot` | [MVP] | Glowing trail dot | 48x48 | No | 1 | Glyphs |
| `UI_Guide_TrailChevron` | [MVP] | Chevron that flows along the trail | 64x64 | No | 1 | Glyphs |
| `UI_Guide_Ring` | [MVP] | Highlight ring around a target | 96x96 | Yes | 1 | No |
| `UI_Guide_Cutout` | [MVP] | Soft-edged hole for the cut-out scrim | 96x96 | Yes | 1 | No |
| `UI_Guide_Bubble` | [MVP] | Text bubble | 64x64 | Yes | 1 | No |
| `UI_Load_Background` | [MVP] | Painted sea, soft enough to stretch | 1280x720 | No | 1 | No |
| `UI_Load_Logo` | [MVP] | GULP wordmark (not translated) | 560x240 | No | 1 | No |
| `UI_Load_Mascot` | [MVP] | Minnow that swims along the loading bar | 128x128 | No | 1 | No |
| `UI_Load_Reconnect` | [MVP] | Minnow looking for the reef | 192x192 | No | 1 | No |

`UI_Load_Background` is the one image exported below 2 ×: its file is 1024 × 576 px.

### 13.12 Control hints (`UI_Hint_`)

Key letters are text on a blank key cap, so one image serves every key. Gamepad glyphs, Xbox and PlayStation, are [L]: a PlayStation controller on a PC needs its own set. Only the TV layout is [P1], and it needs no extra images.

| Asset | Tag | Shows | Size (rpx) | 9-slice | Art states | Atlas |
|---|---|---|---|---|---|---|
| `UI_Hint_Key` | [MVP] | Blank key cap (stretches for Space) | 48x48 | Yes | normal, pressed | No |
| `UI_Hint_MouseMove` | [MVP] | Mouse with move arrows | 48x48 | No | 1 | Glyphs |
| `UI_Hint_MouseLeft` | [MVP] | Mouse, left button lit (dash) | 48x48 | No | 1 | Glyphs |
| `UI_Hint_MouseRight` | [MVP] | Mouse, right button lit (ability) | 48x48 | No | 1 | Glyphs |
| `UI_Hint_KeyArrows` | [MVP] | The four arrow keys (steering) | 72x48 | No | 1 | Glyphs |
| `UI_Hint_Cursor` | [MVP] | Desktop cursor | 32x32 | No | normal, pressed | No |
| `UI_Hint_PadA` | [L] | Gamepad: A | 48x48 | No | 1 | Hints |
| `UI_Hint_PadB` | [L] | Gamepad: B | 48x48 | No | 1 | Hints |
| `UI_Hint_PadX` | [L] | Gamepad: X | 48x48 | No | 1 | Hints |
| `UI_Hint_PadY` | [L] | Gamepad: Y | 48x48 | No | 1 | Hints |
| `UI_Hint_PadLB` | [L] | Gamepad: left bumper | 48x48 | No | 1 | Hints |
| `UI_Hint_PadRB` | [L] | Gamepad: right bumper | 48x48 | No | 1 | Hints |
| `UI_Hint_PadLT` | [L] | Gamepad: left trigger | 48x48 | No | 1 | Hints |
| `UI_Hint_PadRT` | [L] | Gamepad: right trigger | 48x48 | No | 1 | Hints |
| `UI_Hint_PadLStick` | [L] | Gamepad: left stick | 48x48 | No | 1 | Hints |
| `UI_Hint_PadRStick` | [L] | Gamepad: right stick | 48x48 | No | 1 | Hints |
| `UI_Hint_PadLStickPress` | [L] | Gamepad: press the left stick | 48x48 | No | 1 | Hints |
| `UI_Hint_PadRStickPress` | [L] | Gamepad: press the right stick | 48x48 | No | 1 | Hints |
| `UI_Hint_PadDpad` | [L] | Gamepad: D-pad | 48x48 | No | 1 | Hints |
| `UI_Hint_PadDpadUp` | [L] | Gamepad: D-pad up | 48x48 | No | 1 | Hints |
| `UI_Hint_PadDpadDown` | [L] | Gamepad: D-pad down | 48x48 | No | 1 | Hints |
| `UI_Hint_PadDpadLeft` | [L] | Gamepad: D-pad left | 48x48 | No | 1 | Hints |
| `UI_Hint_PadDpadRight` | [L] | Gamepad: D-pad right | 48x48 | No | 1 | Hints |
| `UI_Hint_PadView` | [L] | Gamepad: View button | 48x48 | No | 1 | Hints |
| `UI_Hint_PadCross` | [L] | PlayStation: cross | 48x48 | No | 1 | Hints |
| `UI_Hint_PadCircle` | [L] | PlayStation: circle | 48x48 | No | 1 | Hints |
| `UI_Hint_PadSquare` | [L] | PlayStation: square | 48x48 | No | 1 | Hints |
| `UI_Hint_PadTriangle` | [L] | PlayStation: triangle | 48x48 | No | 1 | Hints |
| `UI_Hint_PadL1` | [L] | PlayStation: L1 | 48x48 | No | 1 | Hints |
| `UI_Hint_PadR1` | [L] | PlayStation: R1 | 48x48 | No | 1 | Hints |
| `UI_Hint_PadL2` | [L] | PlayStation: L2 | 48x48 | No | 1 | Hints |
| `UI_Hint_PadR2` | [L] | PlayStation: R2 | 48x48 | No | 1 | Hints |
| `UI_Hint_PadTouchpad` | [L] | PlayStation: touchpad button | 48x48 | No | 1 | Hints |
| `UI_Hint_PadCreate` | [L] | PlayStation: Create button (whichever of this and the touchpad Roblox maps to `ButtonSelect`; chapter 15, section 3.6) | 48x48 | No | 1 | Hints |

### 13.13 Totals and atlas plan

**By scope tag**

| Tag | Table rows (images) | Drawings (rows × art states) |
|---|---|---|
| [MVP] | 204 | 225 |
| [L] | 120 | 130 |
| [P1] | 0 | 0 |
| [P2] | 1 | 1 |
| **Total** | **325** | **356** |

**By group**

| Group | Rows | Group | Rows |
|---|---|---|---|
| `UI_Common_` | 47 | `UI_Daily_` and `UI_Streak_` | 13 |
| `UI_Icon_` | 66 | `UI_Rank_` | 9 |
| `UI_HUD_` | 39 | `UI_Shop_` | 19 |
| `UI_Emote_` | 9 | `UI_Settings_` | 18 |
| `UI_Moment_` | 12 | `UI_Guide_` | 8 |
| `UI_Cove_` | 25 | `UI_Load_` | 4 |
| `UI_Species_` and `UI_Codex_` | 22 | `UI_Hint_` | 34 |

38 rows are nine-sliced. 75 rows (89 drawings) are standalone files; the other 250 rows (267 drawings) sit in atlases. The TV layout [P1] needs no image of its own.

[P1] is 0 because the images for [P1] content are not listed yet, not because there are none: the Storm, Red Tide and Great Migration tides and the first post-launch species (Anglerfish, Manta Ray) each bring images by the per-item rule in section 15, stage 5 (an event icon and its start art; a head icon, a portrait and an ability icon). Their rows are added here when chapter 12 schedules them.

**Atlas plan.** Sheets are 1024 × 1024 px unless noted. [MVP] drawings fill the lowest-numbered sheets, so a soft-launch sheet is never rebuilt when [L] art arrives.

| Sheet | Cell | Capacity | Holds | Tag |
|---|---|---|---|---|
| `UI_Atlas_Glyphs1` | 144 px (72 rpx) + 2 px gap | 49 | Run HUD glyphs first: status, markers, pips, close, gear, home, drag knob | [MVP] |
| `UI_Atlas_Glyphs2` | same | 49 | The other 34 [MVP] glyphs: dock, tabs, goals, settings, zones, stamps (15 cells free) | [MVP] |
| `UI_Atlas_Glyphs3` | same | 49 | 48 [L] glyphs and the 1 [P2] glyph (full; the next new glyph starts `UI_Atlas_Glyphs4`) | [L] |
| `UI_Atlas_Content1` | 192 px (96 rpx) + 12 px gap | 25 | Tiers, Pearl, Pearl pile, [MVP] species, abilities and predators, six prey | [MVP] |
| `UI_Atlas_Content2` | same | 25 | The other 23 [MVP] content icons: two prey, traits, trait prey, events (2 cells free) | [MVP] |
| `UI_Atlas_Content3` | same | 25 | 20 [L] content icons (5 cells free for new species and traits) | [L] |
| `UI_Atlas_Parts1` | Mixed, packed by hand, 4 px gap | n/a | Run HUD parts: dash, ability, cooldown half, rings, drag ring, threat arrows, tide clock, trait slot, rarity frames | [MVP] |
| `UI_Atlas_Parts2` | Mixed | n/a | Round button, toggle, glow, shine, sparkle, guide arrow, curved arrow, hand | [MVP] |
| `UI_Atlas_Parts3` | Mixed | n/a | Emote slot and bubble, Bubble button, day 7 gift, Reef Rank badge | [L] |
| `UI_Atlas_Hints1` (1024 × 512 px) | 96 px (48 rpx) + 6 px gap | 50 | 28 gamepad glyphs and 2 small [L] HUD glyphs (20 cells free) | [L] |

| Uploads | [MVP] | [L] and later | Total |
|---|---|---|---|
| Atlas sheets | 6 | 4 | 10 |
| Standalone files (one per drawing) | 65 | 24 | 89 |
| **Total image uploads** | **71** | **28** | **99** |

- The loading screen preloads only `UI_Atlas_Glyphs1`, `UI_Atlas_Content1`, `UI_Atlas_Parts1` and the nine-sliced HUD pieces; every other sheet loads after play has started.
- Each atlas sprite is addressed with `ImageRectOffset` and `ImageRectSize` from one generated Luau table (`UiSprites`), keyed by asset name, so code never contains pixel offsets.
- Roblox store listings also need a square icon for each game pass and product; reuse the `UI_Shop_` art for those uploads.

## 14. The complete text list

### 14.0 Rules for text

- All strings live in one Roblox localisation table (`GulpStrings`). The source language is English. Code asks for text by key and never contains player-facing words.
- `AutoLocalize` is off on every text object; text is set from the table by key, so Roblox's automatic text capture does not collect half-built strings.
- `{Name}`-style parts are parameters. Translators may move them. Numbers, times and dates are formatted in code for the player's locale before being inserted.
- Player display names, the word GULP and the logo are never translated.
- Tone: short, friendly, plain words a nine-year-old reads easily. Sentence case. No slang, no idioms, no jokes that depend on English.
- Game terms keep their capital letter and must be translated the same way everywhere: Pearls, Bubble, Codex, Reef Rank, Mass, cove, and every tier, species, trait, prey and event name.
- Strings are [MVP] unless the note starts with [L], [P1] or [P2].
- The source uses British spelling ("colour"); an American English entry may change spelling only.

### 14.1 Common (`common.`)

| Key | English | Note for translators |
|---|---|---|
| `common.ok` | OK | Button |
| `common.yes` | Yes | Button; confirms an action |
| `common.no` | No | Button |
| `common.cancel` | Cancel | Button |
| `common.close` | Close | Label read out for the close cross; also a gamepad hint |
| `common.back` | Back | Button |
| `common.done` | Done | Button; finishes a mode |
| `common.continue` | Continue | Button; moves on after a summary |
| `common.buy` | Buy | Button; spends Pearls |
| `common.claim` | Claim | Button; collects a free reward |
| `common.claim_all` | Claim all | Button; collects the whole Pearl pile in the cove |
| `common.owned` | Owned | Tag on something the player already has |
| `common.locked` | Locked | Tag |
| `common.new` | New! | Tag on something just found |
| `common.free` | Free | Price tag for the starter species |
| `common.max` | MAX | Top tier reached; keep to 3 or 4 letters |
| `common.retry` | Try again | Button |
| `common.no_thanks` | No thanks | Button; declines an offer. Keep it neutral. |
| `common.you` | You | Marks the player's own row in a list |
| `common.pearls` | Pearls | The currency; plural noun |
| `common.mass` | Mass | The size number in a run |
| `common.per_hour` | {Amount} an hour | Pearls earned each hour, for example "120 an hour" |
| `common.thousand` | {Value}K | Short number: 12.4K means 12,400 |
| `common.million` | {Value}M | Short number: 1.2M means 1,200,000 |
| `common.hours_min` | {Hours} h {Minutes} min | A length of time |

### 14.2 Names: tiers, species and abilities (`tier.`, `species.`, `ability.`)

| Key | English | Note for translators |
|---|---|---|
| `tier.1` | Fry | Size tier 1 of 7: a baby fish |
| `tier.2` | Nibbler | Tier 2: takes small bites |
| `tier.3` | Snapper | Tier 3: snaps at food. Not the fish species. |
| `tier.4` | Hunter | Tier 4 |
| `tier.5` | Brute | Tier 5: big and strong |
| `tier.6` | Titan | Tier 6: huge |
| `tier.7` | Leviathan | Tier 7: a sea giant, the top size |
| `species.minnow` | Minnow | Playable creature |
| `species.puffer` | Pufferfish | Playable creature |
| `species.eel` | Eel | Playable creature |
| `species.turtle` | Sea Turtle | [L] Playable creature |
| `species.squid` | Squid | [L] Playable creature |
| `species.shark` | Shark Pup | [L] Playable creature: a baby shark |
| `species.minnow.feel` | Good at everything | How it plays, one short line |
| `species.puffer.feel` | Slow and safe | How it plays |
| `species.eel.feel` | Fast and bendy | How it plays |
| `species.turtle.feel` | Slow and tough | [L] How it plays |
| `species.squid.feel` | Quick bursts | [L] How it plays |
| `species.shark.feel` | Always hungry | [L] How it plays |
| `ability.dart` | Dart | Minnow's power |
| `ability.puff` | Puff | Pufferfish's power: it blows up like a ball |
| `ability.slip` | Slip | Eel's power: slips through narrow holes |
| `ability.shell` | Shell | [L] Sea Turtle's power |
| `ability.jet` | Jet | [L] Squid's power: shoots backwards |
| `ability.rampage` | Rampage | [L] Shark Pup's power: a hungry charge. Not the Feeding Frenzy event. |
| `ability.dart.desc` | Dash more often | Short effect line |
| `ability.puff.desc` | Puff up. Hard to eat. | Short effect line |
| `ability.slip.desc` | Fits through eel holes | Short effect line |
| `ability.shell.desc` | Hide in your shell | [L] Short effect line |
| `ability.jet.desc` | Jet back. Leave ink. | [L] Short effect line |
| `ability.rampage.desc` | Eat fast to speed up | [L] Short effect line |

### 14.3 Names: traits and rarities (`trait.`, `rarity.`)

| Key | English | Note for translators |
|---|---|---|
| `trait.glow` | Glow | Trait name: a body feature gained by eating |
| `trait.stripes` | Stripes | Trait name |
| `trait.spots` | Spots | Trait name |
| `trait.plated` | Plated | Trait name: armour plates |
| `trait.spiny` | Spiny | Trait name: covered in spines |
| `trait.longfin` | Longfin | Trait name: long trailing fins |
| `trait.ink` | Ink | Trait name |
| `trait.crystal` | Crystal | Trait name |
| `trait.moonlit` | Moonlit | Trait name: silver glow |
| `trait.spark` | Spark | [L] Trait name: electric |
| `trait.camo` | Camo | [L] Trait name: camouflage |
| `trait.ember` | Ember | [L] Trait name: glowing hot cracks |
| `trait.bonefed` | Bonefed | [L] Trait name: made-up word, "fed on bones" |
| `trait.glow.fx` | Shows trait prey nearby | Effect line |
| `trait.stripes.fx` | Swim faster | Effect line |
| `trait.spots.fx` | More mass per bite | Effect line |
| `trait.plated.fx` | Survive one bite | Effect line |
| `trait.spiny.fx` | Harder to eat | Effect line |
| `trait.longfin.fx` | Dash goes further | Effect line |
| `trait.ink.fx` | Dash leaves ink | Effect line |
| `trait.crystal.fx` | More Pearls at home | Effect line |
| `trait.moonlit.fx` | Prey drifts to you | Effect line |
| `trait.spark.fx` | Dash stuns prey | [L] Effect line |
| `trait.camo.fx` | Stay still to hide | [L] Effect line |
| `trait.ember.fx` | Vents and jellies can't hurt | [L] Effect line |
| `trait.bonefed.fx` | More mass from everything | [L] Effect line |
| `rarity.common` | Common | How rare a trait is, lowest |
| `rarity.uncommon` | Uncommon | Rarity |
| `rarity.rare` | Rare | Rarity |
| `rarity.epic` | Epic | Rarity |
| `rarity.mythic` | Mythic | Rarity, highest |

### 14.4 Names: prey, predators, hazards, zones and events (`prey.`, `pred.`, `hazard.`, `zone.`, `event.`)

| Key | English | Note for translators |
|---|---|---|
| `prey.plankton` | Plankton | Food |
| `prey.krill` | Krill | Food |
| `prey.shrimp` | Tiny Shrimp | Food |
| `prey.sardine` | Sardine | Food. Used after a number ("Eat 30 Sardine"); pick a form that reads well there. |
| `prey.darter` | Reef Darter | Food: a quick little reef fish |
| `prey.mackerel` | Mackerel | Food |
| `prey.bonito` | Bonito | Food |
| `prey.tuna` | Tuna | Food |
| `prey.glowfry` | Glowfry | Trait prey; made-up name: a glowing baby fish |
| `prey.zebra_darter` | Zebra Darter | Trait prey: striped |
| `prey.dotted_goby` | Dotted Goby | Trait prey: spotted |
| `prey.armor_shrimp` | Armor Shrimp | Trait prey: armoured |
| `prey.urchin_puff` | Urchin Puff | Trait prey: spiny ball |
| `prey.ribbonfish` | Ribbonfish | Trait prey: long and thin |
| `prey.inklet` | Inklet | Trait prey; made-up name: a tiny ink squid |
| `prey.crystal_jelly` | Crystal Jelly | Trait prey: a jellyfish like a gem |
| `prey.lunar_fry` | Lunar Fry | Trait prey: baby fish seen only in the Moon Tide |
| `prey.spark_eel` | Spark Eel | [L] Trait prey: electric |
| `prey.leaf_drifter` | Leaf Drifter | [L] Trait prey: looks like a leaf |
| `prey.vent_snail` | Vent Snail | [L] Trait prey: lives on hot vents |
| `prey.marrow` | Marrow | [L] Trait prey: a chunk from whale bones |
| `pred.gull` | Gull | Predator: a sea bird |
| `pred.moray` | Moray | Predator: an eel that hides in holes |
| `pred.barracuda` | Barracuda | Predator |
| `pred.old_scar` | Old Scar | Predator: the name of one huge shark |
| `pred.grouper` | Grouper | [L] Predator |
| `hazard.jelly_bloom` | Jelly bloom | [L] Codex Dangers entry: a cloud of stinging jellyfish |
| `hazard.hook` | Fishing hook | [L] Codex Dangers entry: a baited hook |
| `hazard.anemone` | Anemone | [L] Codex Dangers entry: it slows whoever touches it |
| `hazard.vent` | Thermal vent | [L] Codex Dangers entry: hot water from the sea floor |
| `zone.nursery` | Nursery Lagoon | Place: the safe starting pool |
| `zone.reef` | Sunlit Reef | Place |
| `zone.kelp` | Kelp Forest | Place |
| `zone.dropoff` | The Drop-off | Place: where the sea floor falls away |
| `zone.trench` | The Trench | [P2] Place: the deepest water |
| `event.frenzy` | Feeding Frenzy | Timed event: food everywhere |
| `event.moon_tide` | Moon Tide | Timed event: the sea goes dark and glows |
| `event.whale_fall` | Whale Fall | [L] Timed event: a clean whale skeleton sinks to the sea floor |
| `event.frenzy.line` | Food everywhere! | One line under the event name |
| `event.moon_tide.line` | Find the Lunar Fry | One line under the event name |
| `event.whale_fall.line` | Big food. Big danger. | [L] One line under the event name |

### 14.5 Run HUD, moments and toasts (`hud.`, `tide.`, `moment.`, `event.`, `toast.`)

| Key | English | Note for translators |
|---|---|---|
| `hud.next_tier` | {Mass} to {Tier} | Mass still needed for the next tier: "114 to Brute" |
| `hud.plus_mass` | +{Mass} | Number that pops up on a bite |
| `hud.traits_full` | Traits full | All three trait slots are taken |
| `hud.trait_progress` | {Count} of {Total} | Trait prey eaten so far: "3 of 5" |
| `hud.shed` | Shed | Button: drop a trait to free its slot |
| `hud.shed_hold` | Hold to shed | Hint under the Shed button |
| `hud.home_dist` | {Dist} m | Distance to home in metres |
| `hud.safe` | Safe here | Nobody can eat the player in this water |
| `hud.biggest` | Biggest now | Title of the list of the biggest creatures on the server |
| `hud.wild` | Wild {Species} | [L] Name tag on a computer-controlled creature, so nobody takes it for a player: "Wild Eel" |
| `tide.title` | Tides | Title of the tide popover |
| `tide.now` | Now | Marks the event that is running |
| `tide.board` | Tide board | [L] Header above the next three tides; a Tide Watcher benefit |
| `tide.board_locked` | See 3 tides with Tide Watcher | [L] "Tide Watcher" is a game pass name |
| `tide.go_home` | Go home first | [L] Shown when a purchase can only be made in safe water |
| `tide.will_wait` | Starts after this tide | [L] On the Call the Tide button before buying, when the tide cannot start at once |
| `tide.called` | Tide called | [L] Under the tide clock: the player's bought tide is waiting to start |
| `tide.called_wait` | Your tide starts after this one | [L] A bought tide never interrupts the tide that is running |
| `tide.called_soon` | Your tide starts in {Time} | [L] The 10 seconds before a bought tide |
| `moment.tier_up` | You grew! | Shown above the new tier's name |
| `moment.new_food` | New food: | Followed by pictures of prey the player can now eat |
| `moment.trait_gained` | New trait! | Shown above the trait's name |
| `event.in` | {Event} in {Time} | Warning before an event: "Moon Tide in 0:45" |
| `event.over` | {Event} is over | Banner when an event ends |
| `event.next` | Next: {Event} | Names the event that comes next |
| `event.called` | {Name} called the tide! | [L] A player started a Feeding Frenzy for everyone |
| `toast.goal_done` | Goal done! | A daily goal was completed |
| `toast.afford` | You can get {Species}! | The player has enough Pearls for a new creature |
| `toast.codex` | New in Codex | Something was found for the first time |
| `toast.leviathan` | {Name} is a Leviathan! | A player reached the top size |
| `toast.error` | Something went wrong | General error |
| `toast.buy_failed` | That did not work. Try again. | A purchase did not go through |
| `toast.bubble` | {Name} left a Bubble! | [L] Another player liked your cove |
| `toast.rank_up` | Reef Rank {Level}! | [L] The player's account level went up |
| `toast.tide_held` | Tide called! It waits its turn. | [L] The player bought a tide while another was running |

### 14.6 Gulped panel and bank summary (`gulped.`, `bank.`, `full.`)

| Key | English | Note for translators |
|---|---|---|
| `gulped.title` | GULPED! | You were eaten. Playful, not scary. Capitals in English. |
| `gulped.by` | by {Name} | Who ate the player; follows the title |
| `gulped.lost` | You lost | Header above the lost creature |
| `gulped.scraps` | Scraps | The small Pearl payout after being eaten |
| `gulped.beginner` | Beginner bonus | Extra scraps for a new player's first three losses |
| `gulped.again` | Swim again | Button: start a new run |
| `gulped.keep_going` | Keep going | Header above the revive choices |
| `gulped.revive` | Revive | Button: come back to life in this run |
| `gulped.revive_note` | Keep your traits | Second line on the Revive button |
| `gulped.revive_video` | Watch to revive | [L] Button: watch a video to come back |
| `gulped.keep_traits` | Keep traits | [L] Button: buy a Trait Lock, so the next run starts with these traits |
| `gulped.traits_kept` | Traits kept for your next run! | [L] Shown after a Trait Lock is bought |
| `bank.title` | Home safe! | The player got home and keeps everything |
| `bank.best` | New best! | This run beat the player's record |
| `bank.new_specimen` | New specimen! | The creature now lives in the cove |
| `bank.too_small` | Reach Nibbler to keep it | Creatures below tier 2 are not kept. "Nibbler" is the tier 2 name. |
| `bank.codex` | New in Codex | Header before pictures of things found this run |
| `bank.pass_row` | ×2 with Deep Pockets | Greyed row; "Deep Pockets" is a game pass name |
| `full.title` | Cove is full | Every cove slot is taken |
| `full.pick` | Pick one to release | Instruction: choose a creature to let go |
| `full.new` | New | Label on the creature just brought home |
| `full.release_new` | Release new one | Button: let the new creature go |
| `full.release_picked` | Release picked | Button: let the chosen old creature go |
| `full.more_slots` | More slots | Button: buy room instead |

### 14.7 Cove (`dock.`, `cove.`, `spec.`, `slot.`, `offline.`, `deco.`, `visit.`)

| Key | English | Note for translators |
|---|---|---|
| `dock.species` | Creatures | Dock button and menu title: choose what to play as |
| `dock.codex` | Codex | Dock button and menu title: the collection book |
| `dock.daily` | Daily | Dock button and menu title: daily goals and gifts |
| `dock.shop` | Shop | Dock button and menu title |
| `dock.ranks` | Ranks | [L] Dock button and menu title: leaderboards |
| `dock.deco` | Decorate | [L] Dock button and mode title |
| `cove.pile_full` | Full | On the Pearl pile when it has stopped growing |
| `cove.boost` | Cove Boost: +{Pearls} | [L] Button: 2 hours of cove Pearls at once |
| `cove.boost_video` | Watch: +{Pearls} Pearls | [L] Button: watch a video for today's Cove Boost |
| `cove.boost_buy` | Get +{Pearls} Pearls | [L] Button beside a Robux price: buy today's Cove Boost |
| `spec.title` | Specimens | Menu title: creatures kept in the cove |
| `spec.sort_income` | Top earners | Sort button |
| `spec.sort_new` | Newest | Sort button |
| `spec.sort_tier` | Biggest | Sort button |
| `spec.banked` | Banked {Date} | The day the creature was brought home |
| `spec.traits` | Traits | Header |
| `spec.no_traits` | No traits | This creature has no traits |
| `spec.best` | Your best | Tag on the top-earning specimen |
| `spec.release` | Release | Button: let a creature go for a small refund |
| `spec.release_ask` | Release {Species}? | Confirm question |
| `spec.release_note` | It swims away for good. | Warning under the question |
| `spec.owner` | {Name}'s specimen | [L] Title when looking at another player's creature |
| `slot.add` | Add a slot | Card that opens the slot shop |
| `slot.title` | More room | Dialog title: one more place for a creature |
| `slot.max` | All slots open | Nothing more to buy |
| `offline.title` | While you were away | Dialog title |
| `offline.away` | Away for {Time} | {Time} is a length such as "3 h 20 min" |
| `offline.cap` | Full after {Hours} hours | The cove stops earning after this long |
| `offline.pass_row` | 24 hours with Tide Watcher | [L] "Tide Watcher" is a game pass name |
| `deco.cant` | Can't go there | [L] A decoration cannot be placed here |
| `deco.rank` | Reef Rank {Level} | [L] Account level needed for this decoration |
| `deco.move` | Move | [L] Tool label |
| `deco.turn` | Turn | [L] Tool label: rotate |
| `deco.store` | Put away | [L] Tool label: back to the tray |
| `deco.starter` | In the Starter Pack | [L] On a decoration that comes only with the Starter Pack |
| `deco.desc` | For your cove. Just for looks. | [L] Line on a decoration card in the shop: it changes nothing but the look of the cove |
| `visit.title` | {Name}'s cove | [L] Banner on entering another player's cove |
| `visit.look` | Just looking | [L] Visitors cannot take anything |
| `visit.bubble` | Leave a Bubble | [L] Button label: like this cove |
| `visit.bubble_done` | Bubble left! | [L] |
| `visit.tomorrow` | One a day. Back tomorrow! | [L] The player already left a Bubble here today |
| `visit.leave` | Swim out | [L] Button: leave the cove |
| `visit.fry_only` | Only a Fry fits in here | [L] A bigger creature cannot enter another player's cove. "Fry" is the tier 1 name. |

### 14.8 Species select and Codex (`species.`, `codex.`)

| Key | English | Note for translators |
|---|---|---|
| `species.pick` | Pick | Button: play as this creature |
| `species.picked` | Picked | Tag: this is the creature in use |
| `species.unlock` | Unlock | Button: spend Pearls to get this creature |
| `species.need` | {Pearls} more | Pearls still needed |
| `species.best` | Best: {Tier} | Highest tier reached with this creature |
| `species.unlocked` | {Species} unlocked! | Shown when a creature is bought with Pearls |
| `species.patterns` | Patterns | [L] Header: colour patterns for a creature |
| `species.pass` | Get it now | [L] Button beside a Robux price |
| `codex.tab_species` | Creatures | Tab |
| `codex.tab_tiers` | Tiers | Tab: the seven sizes reached with each creature |
| `codex.tab_traits` | Traits | Tab |
| `codex.tab_prey` | Prey | Tab: everything that can be eaten |
| `codex.tab_dangers` | Dangers | [L] Tab: predators and hazards |
| `codex.tab_places` | Places | [L] Tab: landmarks |
| `codex.tab_tides` | Tides | [L] Tab: tide events |
| `codex.found` | {Found} of {Total} found | Progress |
| `codex.unknown` | ??? | Not found yet |
| `codex.sizes` | Sizes reached | Header above the seven tier badges |
| `codex.page_reward` | Fill the page: {Pearls} Pearls | Reward for reaching all seven tiers with one creature |
| `codex.banked` | Banked {Count} times | How many times this creature was brought home |
| `codex.best_mass` | Best mass {Mass} | Highest mass reached with this creature |
| `codex.from` | From {Prey} | Which prey gives this trait |
| `codex.gives` | Gives {Trait} | Which trait this prey gives |
| `codex.gained` | Gained {Count} times | How many times the player got this trait |
| `codex.eaten` | Eaten {Count} | How many of this prey the player has eaten |
| `codex.where` | Where | Header above zone pictures |
| `codex.event_only` | Only in {Event} | This prey appears only during one event |
| `codex.bonus` | +{Percent}% cove Pearls | How much a trait raises a specimen's earnings |
| `codex.met` | Met {Count} times | [L] How often the player came close to this danger |
| `codex.visited` | Visited {Date} | [L] The day the player first found this place |
| `codex.tide_when` | Every hour at {Times} | [L] When this tide runs: "Every hour at :00 and :30" |

### 14.9 Daily, Ranks and Reef Rank (`goals.`, `goal.`, `streak.`, `ranks.`, `rank.`)

Chapter 03 lists the goals, chapter 02 picks them and chapter 05 sets what they pay. These are the sentence templates the interface offers.

| Key | English | Note for translators |
|---|---|---|
| `goals.tab` | Goals | Tab |
| `goals.reset` | New goals in {Time} | Countdown to the daily reset |
| `goals.easy` | Easy | Difficulty tag on a goal |
| `goals.medium` | Medium | Difficulty tag on a goal |
| `goals.hard` | Hard | Difficulty tag on a goal |
| `goals.swap` | Swap | Label read out for the swap button on a goal; title of the swap dialog |
| `goals.swap_free` | {Count} free swap left today | Every player may change one goal a day for free |
| `goals.swap_video` | Watch to swap | [L] Button: watch a video for one more swap (Goal Reroll) |
| `goals.swap_buy` | Swap now | [L] Button beside a Robux price (Goal Reroll) |
| `goals.milestone` | All 3 done on {Count} of {Total} days | [L] Progress toward a free decoration: days on which all three goals were finished |
| `goal.eat` | Eat {Count} {Prey} | Goal template: "Eat 30 Sardine" |
| `goal.eat_any` | Eat {Count} things | Goal template |
| `goal.tier` | Reach {Tier} | Goal template: "Reach Hunter" |
| `goal.bank` | Bank {Count} times | Goal template; to bank is to get home safely |
| `goal.pearls` | Bank {Pearls} Pearls | Goal template |
| `goal.trait` | Get {Trait} | Goal template: "Get Glow" |
| `goal.trait_any` | Get {Count} traits | Goal template |
| `goal.event` | Join a {Event} | Goal template: "Join a Moon Tide" |
| `goal.zone` | Visit {Zone} | Goal template |
| `goal.bubble` | Leave a Bubble | [L] Goal template |
| `streak.tab` | Gifts | [L] Tab: the seven-day login calendar |
| `streak.day` | Day {Day} | [L] |
| `streak.today` | Today | [L] |
| `streak.count` | Gift {Day} of 7 | [L] Which box of the seven-day calendar opens next |
| `streak.rule` | Miss a day? Your next gift waits. | [L] A missed day never sends the player back to day 1 |
| `ranks.tab_here` | Here now | [L] Tab: players on this server |
| `ranks.tab_week` | This week | [L] Tab: world list for the week |
| `ranks.tab_bubbles` | Most Bubbles | [L] Tab |
| `ranks.show_way` | Show the way | [L] Button: point me to this player's cove |
| `ranks.new_week` | New week in {Time} | [L] Time left before the weekly list starts again |
| `ranks.empty` | Nobody yet. Be first! | [L] |
| `rank.title` | Reef Rank | [L] The player's account level |
| `rank.level` | Rank {Level} | [L] |
| `rank.next` | {Pearls} to next rank | [L] Pearls still to bank |
| `rank.reward_title` | Title | [L] Reward type: a name shown with the player |
| `rank.reward_deco` | Decoration | [L] Reward type |

### 14.10 Shop and offers (`shop.`, `pass.`, `product.`, `starter.`)

Prices are never part of a string; they come from Roblox at run time (price from chapter 05). Keys follow chapter 05's purchase IDs: `pass.<name>` for `pass_<name>`, `product.<name>` for `prod_<name>`. Chapter 05 gives the Pearl packs no display names, so they are named by size.

| Key | English | Note for translators |
|---|---|---|
| `shop.tab_passes` | Passes | Tab: things bought once and kept |
| `shop.tab_pearls` | Pearls | Tab |
| `shop.tab_boosts` | Boosts | [L] Tab: things that are used up |
| `shop.tab_patterns` | Patterns | [L] Tab |
| `shop.tab_decorations` | Decorations | [L] Tab: cove decorations sold for Robux |
| `shop.thanks` | Thank you! | After a purchase |
| `shop.tomorrow` | Back tomorrow | [L] The daily limit for this item is reached |
| `shop.unavailable` | Not for sale now | The price could not be loaded |
| `shop.cost` | Costs {Pearls} | In the Pearl confirm dialog |
| `shop.after` | You will have {Pearls} | Balance after buying |
| `shop.need_more` | You need {Pearls} more | Pearls still missing for a purchase |
| `shop.get_pearls` | Get Pearls | Button: opens the Pearl packs |
| `shop.forever` | Yours forever | Under a game pass |
| `shop.one_use` | One use | [L] Under a use-once item |
| `pass.deep_pockets` | Deep Pockets | Game pass name |
| `pass.deep_pockets.desc` | 2× Pearls when you bank | To bank is to get home safely |
| `pass.bigger_cove` | Bigger Cove | Game pass name |
| `pass.bigger_cove.desc` | +10 cove slots | Ten more places for creatures |
| `pass.tide_watcher` | Tide Watcher | [L] Game pass name |
| `pass.tide_watcher.desc` | 24-hour Pearl pile. See 3 tides ahead. | [L] The cove keeps earning for 24 hours unclaimed; a tide board shows the next three tides and points to them |
| `pass.keen_nose` | Keen Nose | [L] Game pass name: good at sniffing out traits |
| `pass.keen_nose.desc` | Traits need 4, not 5 | [L] |
| `pass.shark_pup` | Shark Pup | [L] Game pass name; the same as the species name |
| `pass.shark_pup.desc` | Unlock Shark Pup now | [L] |
| `product.revive` | Revive | Product name, shown on the purchase result |
| `product.trait_lock` | Trait Lock | [L] Product name, shown on the purchase result |
| `product.trait_lock.desc` | Start your next run with these traits | [L] |
| `product.call_tide` | Call the Tide | [L] Product name |
| `product.call_tide.desc` | Feeding Frenzy for everyone | [L] "Feeding Frenzy" is the tide event |
| `product.cove_boost` | Cove Boost | [L] Product name |
| `product.cove_boost.desc` | 2 hours of cove Pearls, right now | [L] Once a day |
| `product.goal_reroll` | Goal Reroll | [L] Product name |
| `product.goal_reroll.desc` | Swap one daily goal | [L] |
| `product.pearls_s` | Small Pearl pack | Smallest pack |
| `product.pearls_m` | Medium Pearl pack | Second pack |
| `product.pearls_l` | Large Pearl pack | Third pack |
| `product.pearls_xl` | Extra-large Pearl pack | Largest pack |
| `product.pearls_amount` | {Pearls} Pearls | How many Pearls a pack gives |
| `product.starter_pack` | Starter Pack | [L] Product name |
| `starter.what` | {Pearls} Pearls, a pattern, a decoration | [L] What is inside |
| `starter.once` | One time only | [L] It can be bought once. Not a time limit. |

### 14.11 First-time prompts (`guide.`)

At most 28 characters in English; keep translations under 40.

| Key | English | Note for translators |
|---|---|---|
| `guide.drag` | Drag to swim | Touch |
| `guide.mouse` | Move the mouse to aim | Desktop |
| `guide.swim_key` | Hold {Button} to swim | Desktop; {Button} is a key picture |
| `guide.arrows` | Arrow keys steer too | Desktop; for players without a mouse |
| `guide.stick` | Push the stick to swim | [L] Gamepad |
| `guide.eat` | Eat the green ones | Things with a green outline are food |
| `guide.avoid` | Red ones eat you! | Things with a red outline are dangerous |
| `guide.grow` | Eat to grow | Eating makes the creature bigger |
| `guide.dash` | Tap to dash | Touch |
| `guide.dash_press` | Press {Button} to dash | Desktop and gamepad; {Button} is a picture |
| `guide.ability` | Tap for your power | Touch; the species ability |
| `guide.ability_press` | Press {Button} for power | Desktop and gamepad |
| `guide.trait` | Eat 5 to get a trait | Five of the same special prey |
| `guide.follow` | Follow the lights | A glowing trail leads the way |
| `guide.home` | Swim home to keep it | Getting home keeps the creature and its Pearls |
| `guide.safe` | You're safe here | Said inside the cove |
| `guide.cove` | Your cove earns Pearls | Creatures in the cove earn Pearls over time |
| `guide.claim` | Tap to claim | Touch; collect the Pearls |
| `guide.pick` | Pick a new creature | Points at the Creatures button |
| `guide.out` | Swim out for more | Leave the cove to start a new run |

### 14.12 Settings, private reef, loading, reconnect, emotes and gamepad hints

| Key | English | Note for translators |
|---|---|---|
| `settings.title` | Settings | Panel title |
| `settings.controls` | Controls | [L] Header for the control choices |
| `settings.scheme_drag` | Drag to swim | [L] One thumb steers |
| `settings.scheme_two` | Two thumbs | [L] One thumb moves, the other looks |
| `settings.left_hand` | Left-handed | [L] Buttons move to the left side |
| `settings.drag_speed` | Drag sensitivity | Touch: how far the thumb must move to swim at full speed |
| `settings.mouse_speed` | Mouse look speed | Desktop: how fast the view turns |
| `settings.two_thumb_speed` | Look speed | [L] Touch, two-thumb scheme: how fast the view turns |
| `settings.pad_speed` | Stick look speed | [L] Gamepad: how fast the view turns |
| `settings.swap_sticks` | Swap sticks | [L] Gamepad: swim with the right stick, look with the left |
| `settings.interface_size` | Interface size | [L] Makes every button and text bigger or smaller |
| `settings.flip` | Flip up and down | Invert the vertical direction |
| `settings.sound` | Sounds | Volume of sound effects |
| `settings.music` | Music | Volume of music |
| `settings.graphics` | Graphics | How many visual effects to draw |
| `settings.g_auto` | Auto | Graphics choice: the game decides |
| `settings.g_low` | Smooth | Graphics choice: fewer effects, runs best |
| `settings.g_mid` | Balanced | Graphics choice |
| `settings.g_high` | Pretty | Graphics choice: most effects |
| `settings.outline` | Colour-blind outlines | Changes the food and danger outline colours |
| `settings.motion` | Less motion | Fewer moving effects |
| `settings.vibration` | Vibration | Phone or gamepad vibration |
| `settings.hold_tap` | Tap instead of hold | Replace press-and-hold actions with two taps |
| `settings.text_size` | Bigger text | [L] |
| `settings.hide_emotes` | Hide emotes | [L] Toggle: stop showing other players' emote bubbles |
| `settings.language` | Language | [L] |
| `settings.lang_auto` | Same as Roblox | [L] Use the language of the player's Roblox account |
| `settings.private` | Private reef | [L] |
| `settings.reset` | Reset settings | Button: put every setting back to its default |
| `settings.reset_ask` | Reset all settings? | Confirm question |
| `settings.version` | Version {Version} | Build number of the game |
| `private.title` | Private reef | [L] A private server |
| `private.desc` | A reef just for friends | [L] |
| `private.owner` | Owner: {Name} | [L] |
| `private.players` | {Count} of 24 here | [L] |
| `private.events` | Tide events run here too | [L] |
| `private.invite` | Invite friends | [L] |
| `private.where` | Get one on the GULP page | [L] Bought on the game's Roblox page |
| `load.tip1` | Green means food. | Loading tip |
| `load.tip2` | Red means run! | Loading tip |
| `load.tip3` | Swim home to keep your Pearls. | Loading tip |
| `load.tip4` | Eat 5 of a kind for a trait. | Loading tip |
| `load.tip5` | A new tide comes every 15 minutes. | Loading tip |
| `load.tip6` | Small creatures turn faster. | Loading tip |
| `load.slow` | Still loading. Hang on! | After 10 s |
| `reconnect.save_title` | Finding your cove | The player's save is still loading |
| `reconnect.save_body` | This is taking a while… | Second line under "Finding your cove" |
| `reconnect.update_title` | New tide coming! | The server is restarting for an update |
| `reconnect.update_body` | Moving you to a fresh reef… | Second line under "New tide coming!" |
| `reconnect.lost_title` | Lost the reef | Connection lost |
| `reconnect.saved` | Your cove is safe. | Shown only when the save was confirmed |
| `reconnect.weak` | Weak connection | The connection is slow but still working |
| `resume.title` | Your run is waiting | Card title: the player left during a run and came back in time |
| `resume.continue` | Continue your run | Button: go back into the saved run |
| `resume.fresh` | Start fresh | Button: give up the saved run and begin a new one. A Pearl amount follows. |
| `resume.fresh_note` | Starting fresh ends this run. | Warning beside the two buttons |
| `emote.hi` | Hi! | [L] Emote label for hints, focus and screen readers (labels from chapter 03) |
| `emote.this_way` | This way! | [L] |
| `emote.look_out` | Look out! | [L] |
| `emote.thanks` | Thanks! | [L] |
| `emote.ha_ha` | Ha ha! | [L] |
| `emote.oops` | Oops! | [L] |
| `pad.select` | Select | [L] Gamepad hint bar |
| `pad.back` | Back | [L] Gamepad hint bar |
| `pad.tab` | Switch tab | [L] Gamepad hint bar |

### 14.13 Reserved keys (text supplied by other chapters)

Chapter 03 owns these content lists and supplies the English. The interface has the space and the key pattern ready.

| Key pattern | What | Owner |
|---|---|---|
| `title.<id>` | Reef Rank titles | Chapter 03 |
| `decoitem.<id>` | [L] Decoration names (all 50, the four `deco_buy_*` purchase decorations included) | Chapter 03 |
| `decoitem.<id>.how` | [L] One line on how an earned decoration is obtained (the Codex, daily-goal milestone and tide event decorations), from chapter 03's "How obtained" column | Chapter 03 |
| `pattern.<id>` | Pattern names | Chapter 03 |
| `place.<id>`, `place.<id>.line` | [L] Landmark names and one line each, for the Codex Places tab | Chapter 03 |
| `danger.<id>.line` | [L] One line per predator and hazard, for the Codex Dangers tab | Chapter 03 |
| Language names | Each language in its own name; not translated | Set when languages are chosen |

**String count:** 423 strings in sections 14.1 to 14.12: 275 [MVP], 147 [L], 0 [P1], 1 [P2]. 38 strings (9%) are longer than four words.

## 15. Build order

Every stage uses the final asset names, sizes and text keys from the start. Art may be flat-colour placeholders until the stage that needs it finished; names and sizes do not change.

| Stage | Goal | Screens and elements built | Art level |
|---|---|---|---|
| 1. First playable | The bite loop works on a phone | Layers, scaling, safe frame and keep-out (section 1); localisation table and key lookup; `HUD.DragRing`, `HUD.Dash`, `HUD.MassBar`, `HUD.MassPops`, `HUD.Outlines`, `HUD.Home`; S11 with Swim again only; S12 with the Pearls table only; button states and the 100 ms rule | Placeholder shapes |
| 2. First-two-minutes build | Chapter 04's script runs end to end | S01 Loading; S33 Guide kit (all nine parts); `HUD.Traits` and S04; `HUD.Ability`; `HUD.Threats`; `HUD.BankChip`; `HUD.SafeBadge`; `HUD.Status` (stun, shield); S07; S08; S10 toasts (species affordable, Codex); S14 with Pearls, slots, Claim all and the Creatures dock button; S22 with S19 and S35; specimen card on S12; desktop keys, cursor rules and key hints | Final art for everything in this stage |
| 3. Soft launch | Everything tagged [MVP] | `HUD.TideClock`, S05, S09; `HUD.Biggest`; `HUD.TraitMarkers`; `HUD.Lag`; S13; S15; S16; S17; S18; S23; S24; S25; S27 (Passes, Pearls) and S28; offers O1, O4, O5, O10; S31 with every [MVP] setting; S02; S36; the Species Wall and the cove tide clock; sound and haptic hooks; an analytics event on every screen open and close, and on every offer shown, tapped, bought or closed | Final |
| 4. Launch | Everything tagged [L] | S06; S20; S21; S26; S29; S30; S32; S34; icons and portraits for Sea Turtle, Squid, Shark Pup, Spark, Camo, Ember, Bonefed, Grouper, Whale Fall; gamepad focus order, hint bar and glyphs (Xbox and PlayStation sets) on PC and handheld PCs; the two-thumb scheme and the left-handed layout with their settings rows; Interface size and Swap sticks; Codex tabs Dangers, Places and Tides; the tide board, the tide marker and the Call the Tide held-token state; the wild creature name tag; rewarded video buttons (O2, O12, O13); Boosts, Patterns and Decorations tabs; O3, O6, O7, O8, O9, O11, O14, O15; the decoration tray states and the daily-goal milestone row; Bigger text; Hide emotes; Language | Final |
| 5. After launch | [P1] and later | [P1]: the TV layout for Xbox and PlayStation (5% margins, TV scale; no new images), once the consoles pass chapter 15's hardware checks. [P2]: the Trench zone icon. Each new species needs three images (head icon, portrait, ability icon) and five strings; each new trait needs two images (trait, trait prey) and three strings; each new event needs two images (icon, start art) and two strings. | Final |

## 16. Acceptance checklist

A tester ticks the box when every check in the row passes on a small phone (4.7 inch, 16:9), a long phone (19.5:9 with a notch), a tablet and a desktop at 1080p. [L] rows are also checked with a gamepad on a PC. [P1]: the console checks are chapter 15's (sections 3.5 and 3.6).

### 16.1 Checks that apply to every screen

| Tick | Check |
|---|---|
| [ ] | Nothing sits under the notch, the rounded corners, the home bar or the Roblox buttons at the top left |
| [ ] | Every tappable thing has a hit area of 88 rpx or more and 16 rpx or more between hit areas |
| [ ] | First visible and audible response to a press is within 100 ms (filmed at 240 fps) |
| [ ] | No text is smaller than 22 rpx; no text is clipped in English or in the longest test language |
| [ ] | No English words appear when the language is switched; every string comes from a key in section 14 |
| [ ] | No default Roblox interface, font, sound, cursor or avatar picture is visible |
| [ ] | The screen works with touch, with mouse and keys, and [L] with a gamepad, and shows the right hints for each |
| [ ] | With "Less motion" on, nothing slides, shakes or pulses faster than 1 Hz |
| [ ] | Timings match section 11 within 20 ms |

### 16.2 Per screen

| Tick | Screen | Passes when |
|---|---|---|
| [ ] | S01 Loading | Shows on the first frame; the bar moves with real progress; it leaves as soon as the game is ready; steering works during the fade; a tip is readable |
| [ ] | S02 Reconnect | Each of the four cases shows its own text; "Your cove is safe." appears only after a confirmed save; retry works |
| [ ] | S03 Run HUD: layout | No persistent element enters the keep-clear box on any device; every element sits at its table position; [L] left-handed and two-thumb layouts mirror correctly |
| [ ] | S03 Mass bar | Fill, number and next-tier goal are right at every tier; Near, Tier-up, Loss and Max states play; the bar never overlaps the Roblox buttons |
| [ ] | S03 Pearl preview | Matches the Pearls actually banked, including Crystal and Deep Pockets; the specimen light turns on at tier 2 |
| [ ] | S03 Trait slots | Pips match prey eaten (5, or 4 with Keen Nose); owned traits show their rarity frame; the row shakes when full; Plated shows cracked after use |
| [ ] | S04 Trait popover | Opens on a tap; shedding needs a 600 ms hold (or tap and Yes); early release cancels; steering and dash still work while it is open |
| [ ] | S03 Dash and ability | Cooldown wedge matches the real cooldown within 50 ms; a press in the last 250 ms is queued; passive species show a badge, not a button; disabled state plays the locked sound |
| [ ] | S03 Threat indicators | An arrow shows for every off-screen creature that can eat the player, never for one that cannot; size and pulse follow distance; at most three; Old Scar uses its own arrow; arrows never cover dash or ability |
| [ ] | S03 Outlines | Edible and danger outlines are right after every tier change on either side within 100 ms; none in safe water; plankton and hook bait never have one; a Barracuda, or a Grouper [L], turns green for a player at least one tier above it, and the Gull, the Moray and Old Scar never do; the danger outline pulses in every mode; colour-blind mode shows yellow and hot pink and adds marks |
| [ ] | S03 Home marker | Points home from anywhere; distance is right within 5 m; sits above the cove mouth when on screen; gold rim on a best run |
| [ ] | S03 Tide clock, S05, S09 | Clock matches the real quarter-hour schedule within 1 s on two devices side by side; warning at 60 s, the 10 s timer, start and end banners all show once; the popover shows the next tide in local time. [L]: with Tide Watcher the tide board lists the next three tides and the marker points to the tide's site; without it the board is absent; a bought Call the Tide shows the held-token state until it starts and never interrupts a scheduled tide; no tide notification exists |
| [ ] | S03 Biggest strip | Shows the true biggest creature within 1 s; the player's own row is highlighted; no avatar pictures; desktop shows five rows |
| [ ] | S03 Status, safe badge, lag icon | Each status icon shows for the full length of its effect and no longer; the safe badge shows in the Nursery and in coves only; the lag icon appears on a throttled connection |
| [ ] | S06 Emote wheel [L] | Opens by tap and by hold-and-slide; all six emotes show above the creature to a second player; the 3 s limit holds; with "Hide emotes" on, the second player sees no bubble and hears no emote sound, and can still send their own |
| [ ] | S07 Tier-up | Plays at every tier change; shows the right new food; never blocks input; tier 7 sends the server toast |
| [ ] | S08 Trait gained | Shows the right name, rarity frame and effect line; Epic and Mythic hold for 3 s |
| [ ] | S10 Toasts | At most two visible; same kinds merge; "species affordable" waits for safe water; toasts cannot be tapped in open water |
| [ ] | S11 Gulped panel | Buttons ignore input for the first 700 ms; Swim again reaches the cove in under 3 s; there is no timer anywhere on the panel; the revive buttons are absent on the account's first death, when the lost creature had under 30 mass, and after a revive was used; [L] Keep traits shows only after losing an Uncommon or better trait, still shows after a revive was used, and the next run starts with those traits; nothing is offered in the first two minutes of a first session; a cancelled purchase returns to the panel |
| [ ] | S12 Bank summary | The total equals the Pearls added to the balance; a tap skips to the end; Continue works from the first frame; a tier 1 run shows the "too small" note; the whole sequence is under 3.5 s |
| [ ] | S13 Cove-full choice | Appears only when no slot is free; refunds shown equal refunds paid; release needs a hold; More slots returns with the new specimen kept; after a disconnect on the choice nothing is released or refunded, and the choice shows again on the next join before anything else |
| [ ] | S14 Cove HUD | Balance, income and slots are right; there is one Pearl pile; Claim all appears only when Pearls are in the pile; nothing is claimed without a tap; the Species Wall shows the next species with the right progress and opens its card; the cove tide clock matches `HUD.TideClock`; both stay hidden before the first bank; badges appear only for free things and never on Shop; swimming out starts a run |
| [ ] | S15 Offline claim | One total is shown, and it matches time away and the cap; not shown under the threshold, and then nothing is claimed until the player taps the pile; never shown in a new player's first two minutes; [L] the Cove Boost button shows the exact Pearls, offers the video first, and works at most once a day |
| [ ] | S16, S17 Specimens | Every card shows the right creature, tier, traits and income; sort cycles three ways; at most 12 live renders; Release needs a hold and a confirm; read-only on a visit |
| [ ] | S18 Slot upgrade | Price matches chapter 05; cannot-afford and all-open states show; the new slot appears at once |
| [ ] | S19 Confirm dialog | Shows the item, the price and the balance after; Cancel is the default for release and reset |
| [ ] | S20 Decoration mode [L] | Items place only on valid cells; every drop is saved; move, turn and put away work; locked items show what is needed for each of the seven groups in 5.6; a Robux decoration shows the live price, and only the price button on its card opens the Roblox prompt; the Golden Chest appears only through the Starter Pack |
| [ ] | S21 Visit HUD [L] | Only a tier 1 Fry can enter; the run is not banked; nothing can be taken; one Bubble per cove per day; the owner sees the toast; Swim out works |
| [ ] | S22 Species select, S35 | Locked creatures are silhouettes with name, price and progress; affordable ones pulse; unlock asks for confirmation; Pick changes the creature at once; Shark Pup shows both ways to get it [L] |
| [ ] | S23, S24 Codex | The tabs match chapter 03's categories (Creatures, Tiers, Traits, Prey; [L] Dangers, Places, Tides); counts are right per tab; a Tiers page shows the seven tiers, what each pays and the page reward; unknown entries show a silhouette and a where-to-look hint; new entries carry the tag until opened; arrows step through entries; [L] the Dangers, Places and Tides tabs show chapter 03's entries |
| [ ] | S25 Goals | Three goals tagged Easy, Medium and Hard, in that order (Easy, Easy, Medium on an account's first day); progress and rewards are right; the timer matches the real daily reset; one free swap a day keeps the goal's difficulty; Claim pays once; [L] the milestone row counts days with all three goals done and gives each decoration once |
| [ ] | S26 Gifts [L] | Today's cell can be claimed once; opens by itself once a day and not in the first session; after a missed day the next box still opens next and nothing goes back to day 1; every reward is Pearls |
| [ ] | S27 Shop, S28 | Every price shown equals the price in the Roblox prompt; owned passes, patterns and decorations show Owned and cannot be bought again; [L] the Decorations tab holds the three Robux decorations and no Golden Chest; cancel leaves no message; a failure shows the failure toast |
| [ ] | S29 Ranks [L] | Three tabs load; the player's own row is pinned; Show the way points to the right cove for 60 s |
| [ ] | S30 Reef Rank [L] | Rank, progress and rewards are right; the track opens on the current rank |
| [ ] | S31 Settings | Opens in open water without covering the creature; every setting applies at once and survives a rejoin; steering still works beside the panel |
| [ ] | S32 Private reef [L] | Shows the right content in private and public servers; Invite opens the Roblox prompt |
| [ ] | S33 Guide kit | Each of the nine parts can be shown on a HUD element and on a world position; a prompt clears within 100 ms of the action; never more than one bubble and one pointer |
| [ ] | S36 Continue your run | Shows on rejoining within 5 minutes of leaving mid-run (15 minutes after a server shutdown) and never for an account that has not banked; shows the right creature, mass and traits; Continue returns to the run with 3 s of protection; Start fresh needs a hold and pays exactly the Pearls on its button; no close, no timer, no offer; a card left open for longer than 5 minutes still offers Continue (time on the card is not counted); leaving with the card open keeps the run suspended |
| [ ] | Section 9 offers | Every rule O-R1 to O-R13 holds for every offer O1 to O15; no offer appears in open water; every offer has its way out; no timers; nothing paid carries a badge |
| [ ] | Section 12 accessibility | Contrast measured on screenshots passes 4.5 to 1 for text and 3 to 1 for icons; the game can be played start to bank with sound off; every hold has its tap alternative |

## 17. Engine facts and what was checked

Checked against create.roblox.com/docs on 13 October 2026 unless marked.

| # | Fact | Status | How this chapter uses it |
|---|---|---|---|
| E1 | `StarterGui:SetCoreGuiEnabled(type, false)` turns off default interface. `Enum.CoreGuiType` has PlayerList, Health, Backpack, Chat, EmotesMenu, SelfView, Captures, AvatarSwitcher, ExperienceShop and All. | Verified (CoreGuiType enum page; "disable default UI" page) | Follow chapter 09 (section 6.10): `SetCoreGuiEnabled(Enum.CoreGuiType.All, false)`. This also turns the Roblox chat window off, which is what the canon asks for in the MVP. |
| E2 | Default touch controls (thumbstick, jump button) are hidden with `GuiService.TouchControlsEnabled = false` | Verified (same page) | Hidden; GULP draws its own steering ring and buttons |
| E3 | `ScreenGui.ScreenInsets` has None, DeviceSafeInsets, CoreUISafeInsets, TopbarSafeInsets. The default, CoreUISafeInsets, keeps content clear of the top bar buttons and screen cut-outs; DeviceSafeInsets uses more of the screen. | Verified (ScreenInsets enum page; "on-screen UI containers" page, via search summary) | Section 1.3 |
| E4 | `GuiService.TopbarInset` and `GuiService:GetInsetArea()` report the free area of the top bar | Verified that they exist (GuiService reference). Measured in the Sprint 0 spike (F11): with all core GUI off, `TopbarInset` still reserves x 0 to 120 px, y 0 to 58 px | Keep-out box in 1.3: the Hud is laid out outside `TopbarInset` |
| E5 | The Roblox menu button and top bar cannot be removed | Not found in the docs this session; long-standing platform behaviour. Mac Studio drew no menu button in the spike, but the inset was still reserved; a real client is still to be checked | Keep-out box in 1.3 |
| E6 | The top bar is 58 px tall | Developer forum; matched by the spike's `TopbarInset` height (58 px, Mac Studio) | Fallback value only; read the inset at run time |
| E7 | `DeviceSafeInsets` does not cover the iOS home bar | Developer forum bug report only | 40 rpx bottom rule in 1.3 |
| E8 | Text chat runs through `TextChatService`; `ChatWindowConfiguration.Enabled` can hide the default window | Verified (text chat overview page) | Text chat is off in the MVP (canon 14) and nothing depends on it. If the launch review turns it on, it is chapter 09's chat panel in the left column (1.3), never on a TV (chapter 15). |
| E9 | Roblox offers automatic translation, a translation table per game, and `AutoLocalize` can be turned off per object | Verified (localisation page) | Section 14.0 |
| E10 | Looking text up by key in code (`Translator:FormatByKey`) | From memory; not checked this session | Section 14.0 |
| E11 | The docs warn that default mobile controls use the bottom corners and that reach differs between phone and tablet | Verified ("position and size" page) | Thumb zones in 1.4 follow the same idea |
| E12 | `ReplicatedFirst:RemoveDefaultLoadingScreen()`, `TeleportService:SetTeleportGui()` | From memory; not checked | Section 8 |
| E13 | Haptics on phones and gamepads (`HapticEffect`), reduced-motion flag (`GuiService.ReducedMotionEnabled`), platform-specific gamepad button names (`UserInputService:GetStringForKeyCode`) | Verified in chapter 15 (its facts PF19 and PF31). Still unverified there: the exact strings `GetStringForKeyCode` returns, and whether the built-in haptic types match the target lengths in 11.4. | Sections 10 to 12 |
| E14 | Images larger than 1024 × 1024 px are scaled down on upload | From memory; not checked | Atlas plan in 13.13 |
| E15 | Phone viewports are reported in device-independent pixels | From memory; check on a device | Scale table in 1.2 |
| E19 | `GuiService.ViewportDisplaySize` (Small, Medium, Large) and `UserInputService.PreferredInput`; the docs say not to use `IsTenFootInterface` to detect consoles | Verified in chapter 15 (PF19). What they return on a Chromebook, a handheld PC and a 4K TV is unverified. | Sections 1.2 and 10.1 |
| E16 | `MarketplaceService:GetProductInfo` returns the live price; Roblox may show regional prices | From memory; not checked | Prices are never typed into the interface |
| E17 | There is no in-game call to sell a private server | From memory; not checked | S32 only explains |
| E18 | The Roblox purchase prompt and the Roblox disconnect dialog cannot be restyled or replaced | From memory; not checked | Sections 6.4, 8.2 and 9 |

## 18. Decisions made beyond the canon

| # | Decision | Where |
|---|---|---|
| D1 | No title screen or main menu; the cove HUD is the hub | 2.2 |
| D2 | Full menus open only in safe water; in open water only the settings side panel and popovers | 1.1 P7 |
| D5 | Threat arrow distances (90, 60, 30 studs), outline range (120 studs), at most three arrows | 3.9, 3.11 |
| D6 | A status icon row, a weak-connection icon and a safe-water badge on the HUD | 3.15, 3.16 |
| D7 | The Pearl preview carries a "specimen light" and the home marker turns gold on a best run | 3.5, 3.12 |
| D10 | A 700 ms input guard on the gulped panel | 4.4 |
| D11 | Pass and offer timing beyond the canon's rules (third bank, second session); chapter 05 owns the numbers | 9.1 O-R7 |
| D13 | The login streak is a tab of the Daily screen, not its own dock button | 6.3 |
| D14 | Specimens, decorations and patterns are shown as live 3D renders, not images | 5.2, 13.1 |
| D15 | A Reef Rank track screen and a tide popover | 6.6, 3.13 |
| D16 | Desktop: the mouse is locked while swimming, Left Alt frees it, Backspace closes | 10.2 |
| D17 | Separate PlayStation glyphs, shipped with gamepad support at [L]. Chapter 15 owns the button map. | 10.4, 13.12 |
| D18 | Settings beyond the canon list: flip up and down, less motion, vibration, tap instead of hold, bigger text. Chapter 15 adds interface size, swap sticks and one look speed per input type. | 6.7 |
| D19 | Asset groups `UI_Common_`, `UI_Icon_` and `UI_Hint_` that are not screens | 13.1 |
| D20 | Text keys follow chapter 05's purchase IDs. The four Pearl packs are named by size, because chapter 05 gives them no display names. | 6.4, 14.10 |
| D21 | Distance is shown as studs labelled "m" | 3.12 |
| D22 | Goal types and their sentence templates; goal icons; a swap button on each goal row | 6.3, 13.8, 14.9 |
| D23 | The Tide Watcher marker is an edge marker like the home marker, shown only for a tide with one site | 3.13 |
| D24 | Codex Places entries use their zone's icon, so no picture is needed per landmark; Dangers adds four hazard icons | 6.2, 13.3 |
| D25 | The wild creature name tag shows within 60 studs | 3.16 |
| D26 | Cove Boost and Goal Reroll also have cards in the shop's Boosts tab, beside the places chapter 05 names; the Cove Boost button opens one dialog with the video first; the cove's one Pearl pile is claimed by tapping it or the Claim all button | 6.4, 5.4, 5.1 |
| D27 | The Robux decorations are sold in two places: the decoration tray, beside the Pearl items, and a Decorations tab in the shop. The Golden Chest shows in the tray as part of the Starter Pack and is never sold alone. | 5.6, 6.4, 9.2 |
| D28 | The Continue your run card has no countdown, shows what Start fresh pays on the button, and asks for a hold before giving the run up | 8.3 |
| D29 | The Codex has a Tiers tab, one page per species, so its tabs match chapter 03's categories one for one; the Prey tab replaces "Food" | 6.2 |
| D30 | The Species Wall is drawn by the interface (a SurfaceGui that reuses the species portrait and the shared ring); the cove tide clock gets only a countdown from the interface | 5.1 |
| D31 | A milestone row on the Goals tab shows progress toward the four daily-goal decorations | 6.3 |
| D32 | "Hide emotes" hides other players' emote bubbles and sounds only; the player's own wheel stays. Its row reuses `UI_Emote_Hi` as its icon | 6.7, 3.17 |

## 19. Open questions for other chapters

| For | Question |
|---|---|
| 02 | Confirm the threat warning distances |
| 02 | When progress exists on more trait prey kinds than there are free slots, is all progress kept? (The interface assumes yes.) |
| 02 | Which point the Tide Watcher marker leads to for each tide. (Assumed: the whale skeleton in a Whale Fall, the nearest Lunar Fry shoal in a Moon Tide, nothing in a Feeding Frenzy.) |
| 05 | Every price, refund, goal reward, gift reward and Pearl pack size. This chapter only reserves the space. |
| 03 | Lists and names of Reef Rank titles, decorations, patterns, landmarks, the one-line texts for the Codex Dangers and Places tabs, and one "how to get it" line for each earned decoration (14.13) |
| 06 | Rarity frame shapes that differ without colour; colours that meet the contrast floors in section 12 |
| 07 | Add every `SFX_UI_` name in 11.5 and every image in section 13 to the asset list |
| 06 | Chapter 06 allows one interface atlas in the MVP; the plan in 13.13 needs six sheets. Chapter 06 owns the budget. |
| 09 | One `UIScale` per ScreenGui; the 12-render limit for live 3D cards |
| 09 | A second saved touch speed for the two-thumb scheme [L]: the save has one `lookSpeed` per input type, and touch has two sliders with different ranges (6.7) |

## 20. Proposed canon changes

This chapter follows the canon as written. The canon has since adopted the earlier proposals on shedding by tap and hold, one Bubble per cove per day, the "biggest now" strip in the MVP, no timer on the revive offer, the left-handed layout, quick emotes, purchase and zone IDs, the Tide Watcher tide board, Trait Lock on the gulped screen and passive abilities. These remain open and are suggestions only.

| # | Canon section | Suggestion | Why |
|---|---|---|---|
| 1 | 5.5 Getting gulped | Say that "respawn in under 3 seconds" is measured from the player pressing Swim again | The gulped panel has no timer, so the three seconds cannot start at the gulp |
| 2 | 5.6 Controls | Consider "tap twice to dash" as an option, so the game can be played with one thumb only | "One thumb" is a stated principle, but dash and ability currently need a second thumb or a pause in steering |
| 3 | 12 How it makes money | Give the four Pearl packs display names, or confirm that they are named by size | Chapter 05 lists only their IDs; the shop cards need a name |
