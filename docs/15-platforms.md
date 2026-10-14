# 15 · Platforms

This chapter says what GULP looks like and how it plays on every device Roblox supports. It consolidates the platform rules that are spread across documents 02, 06, 08 and 09, completes them per platform, and settles the points where they disagree or stay silent.

**This chapter owns:** which platforms are supported and when; the per-platform HUD layout, control map, camera differences, graphics tier and performance targets; fairness across input types; behaviour when the input type or window changes; the device test matrix.
**It does not own:** game rules (02), interface art and text (08), the look (06), the code structure (09). Where this chapter makes a decision that changes one of those, it is listed in section 10, and those changes have been applied to the other chapters (section 10 marks any that have not).

**Conventions**

- **rpx** = reference pixel on the 1280 × 720 canvas of document 08, section 1.2. **px** = real device-independent pixels.
- **(tune)** marks a first guess. **[MVP] [L] [P1] [P2]** are the canon scope tags (canon section 15): [MVP] is the soft-launch build, [L] is added for public launch, [P1] is the first quarter after launch (weeks 1 to 12) and [P2] is later. Xbox and PlayStation are early [P1]: the target is the first month after launch.
- **[V]** = verified on an official Roblox page on 13 October 2026 (reference in section 0). **[U]** = not verified; treat as an assumption until tested.
- "Keys" means keyboard and mouse. "Pad" means any gamepad. Xbox button names are used for pads unless a PlayStation name is given.

## 0. Platform facts: verified and unverified

Checked on 13 October 2026. Pages on `create.roblox.com` were read as `/docs/en-us/<path>.md`. Several `en.help.roblox.com` pages refused the fetch (HTTP 403); facts from those are search-result snippets and are marked **S** (snippet, not read in full).

| Ref | Fact | Status | Source |
|---|---|---|---|
| PF1 | Phones and tablets: iOS and iPadOS 14 or later, Android 8.0 or later. | S | [Mobile system requirements](https://en.help.roblox.com/hc/en-us/articles/203625474-Roblox-Mobile-System-Requirements) |
| PF2 | Computers: 64-bit Windows 10 or 11, macOS 10.13 or later. No Linux client. | S | [Computer requirements](https://en.help.roblox.com/hc/en-us/articles/203312800-Computer-Hardware-Operating-System-Requirements) |
| PF3 | Xbox: the help articles found name Xbox One only. Series X and S are not named on any official page read. | S, partly U | [Xbox One app](https://en.help.roblox.com/hc/en-us/articles/205091984-Xbox-One-App-How-to-Play-a-Roblox-Experience) |
| PF4 | PlayStation 4 and 5, in select countries. | S | [PlayStation FAQ](https://en.help.roblox.com/hc/en-us/articles/19816103303572-PlayStation-FAQ) |
| PF5 | VR: Meta Quest 2, Pro and 3 (S). Roblox VR uses OpenXR, "allowing games to work interchangeably on Quest and PC VR headsets" (V). | S, V | [Meta Quest FAQ](https://en.help.roblox.com/hc/en-us/articles/17810433924628-Meta-Quest-FAQ), [VR guidelines](https://create.roblox.com/docs/production/publishing/vr-guidelines) |
| PF6 | Handheld PCs: Roblox runs "natively on the new Xbox Ally handheld devices: ROG Xbox Ally and ROG Xbox Ally X" since 15 October 2025. The same post adds the Samsung Galaxy Store. | V | [Roblox newsroom, Oct 2025](https://about.roblox.com/newsroom/2025/10/roblox-everywhere-bringing-roblox-two-new-platforms) |
| PF7 | Chromebooks run the Android app from Google Play. No official page was reached; third-party pages agree. | U | None official |
| PF8 | Play in a browser: announced at the 2026 developer conference for "Late 2026": "anyone who clicks can start playing immediately in Chrome, with no app or install required." Not released on the check date. | V (announcement) | [RDC26: What We Announced](https://devforum.roblox.com/t/rdc26-what-we-announced/4865880) |
| PF9 | Standalone game apps: seen only as a quoted line in a reply to the same post ("Distribute your game as a standalone app and on the web"). Terms and date unknown. | U | Same post |
| PF10 | `Enum.Platform` lists Windows, OSX, IOS, Android, XBoxOne, PS4, PS5, MetaOS, Web, AndroidTV, Linux and SteamOS. This is an API list, not a statement of support. | V | [Platform enum](https://create.roblox.com/docs/reference/engine/enums/Platform) |
| PF11 | Nintendo Switch or Switch 2, Steam Deck, Apple Vision Pro, PlayStation VR2, Amazon Fire tablets, smart TVs: no official support statement found. | U | Searched; nothing official |
| PF12 | Devices are switched per game under Experience Settings, Basic Info, "Playable Devices": "Lets you enable each applicable device that supports your game." The page does not list the option names or the defaults. Document 12 (G8) names them Phone, Tablet, Computer, Console, VR. | V, names U | [Experience settings](https://create.roblox.com/docs/studio/experience-settings), [Publish](https://create.roblox.com/docs/production/publishing/publish-experiences-and-places) |
| PF13 | Console guidelines. Required: "Games designed for consoles always need to provide content maturity information." Advised: every interface element reachable with "the four directions, select, and back"; players sit "8–10 feet away"; "put UI elements in TV-safe areas" (no numbers given); disable the chat window on console; `Enum.DisplaySize.Large` "represents most TVs or larger"; `UserInputService:GetImageForKeyCode()` returns platform button icons; use `HapticEffect` sparingly. | V | [Console guidelines](https://create.roblox.com/docs/production/publishing/console-guidelines) |
| PF14 | The console and VR guideline pages state no review, certification or approval step, no minimum text size and no safe-area percentage. | V (absence) | Same pages |
| PF15 | VR guidelines: automatic quality on Quest "aims to maintain a minimum of 72 frames per second"; comfort options are Vignette, Stepped Rotation and 3rd Person Fixed Camera; a custom camera script opts the game out of Roblox's VR camera updates. The page states no age limit. | V | [VR guidelines](https://create.roblox.com/docs/production/publishing/vr-guidelines) |
| PF16 | Progress follows the account across devices: players can "join games on their phone or tablet, then later continue where they left off on their PC or console." | V | [Cross-platform](https://create.roblox.com/docs/projects/cross-platform) |
| PF17 | Matchmaking has a Device Type signal ("mobile device, a computer, a tablet, a console, or a VR device") with **default weight 0**, "so it doesn't affect matchmaking decisions". Default weights: Friends 15, Latency 3, Text Chat 3, Occupancy 2, Play History 2, Language 2, Age 1, Voice Chat 1. A creator "can adjust this weight" in a custom matchmaking configuration. So by default all enabled devices share servers. | V | [Server scoring](https://create.roblox.com/docs/matchmaking/scoring), [Attributes and signals](https://create.roblox.com/docs/matchmaking/attributes-and-signals) |
| PF18 | `UserInputService.PreferredInput` reports "the primary input type a player is likely using": `KeyboardAndMouse`, `Gamepad`, `Touch` (the reference page also lists `MicroGamepad`). Also present: `GetLastInputType()`, `LastInputTypeChanged`, `TouchEnabled`, `KeyboardEnabled`, `MouseEnabled`, `GamepadEnabled`, `GetConnectedGamepads()`, `GetStringForKeyCode()`, `GetImageForKeyCode()`, `MouseBehavior` (`LockCenter`), `MouseDeltaSensitivity`. | V | [UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService) |
| PF19 | `GuiService`: `IsTenFootInterface()` exists, but the page says not to use it to detect consoles; `ViewportDisplaySize` is `Small` (most phones, tablets, handhelds), `Medium` (most laptops and monitors) or `Large` (most TVs); `PreferredTextSize` (Medium, Large, Larger, Largest); `ReducedMotionEnabled`; `TopbarInset`; `SelectedObject`. | V | [GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService), [Cross-platform](https://create.roblox.com/docs/projects/cross-platform) |
| PF20 | There is no documented script API that returns the platform or device model. `GetPlatform`, `GetDeviceType` and similar are not on the reference pages. `VRService.VREnabled` exists (client only). | V (absence) | [VRService](https://create.roblox.com/docs/reference/engine/classes/VRService) |
| PF21 | Orientation: `StarterGui.ScreenOrientation` sets the default; `PlayerGui.ScreenOrientation` changes it at run time; values `LandscapeLeft`, `LandscapeRight`, `LandscapeSensor`, `Portrait`, `Sensor`. The mobile input page says games run in landscape by default (`LandscapeSensor`); the StarterGui reference lists the default as `Sensor`. The two pages conflict, so the value is set explicitly. | V, conflicting | [Mobile input](https://create.roblox.com/docs/input/mobile), [StarterGui](https://create.roblox.com/docs/reference/engine/classes/StarterGui) |
| PF22 | `ScreenGui.ScreenInsets` (default `CoreUISafeInsets`), `ClipToDeviceSafeArea` (default true: content "may be obscured by the camera notch or other screen cutouts" otherwise). `Camera.ViewportSize` "returns the dimensions of the device safe area" in interface offset units, not native pixels. | V | [ScreenGui](https://create.roblox.com/docs/reference/engine/classes/ScreenGui), [Camera](https://create.roblox.com/docs/reference/engine/classes/Camera) |
| PF23 | The Input Action System (`InputAction`, `InputBinding`, `InputContext`) exists and is the recommended cross-platform route. `InputActionLabel` and the Input Action Manager are beta. Player remapping as a built-in feature is not confirmed. | V, partly U | [Input Action System](https://create.roblox.com/docs/input/input-action-system) |
| PF24 | Pad focus: `GuiObject.NextSelectionUp`, `Down`, `Left`, `Right`; `SelectionImageObject`. Roblox also offers a virtual cursor. | V | [GuiObject](https://create.roblox.com/docs/reference/engine/classes/GuiObject), console guidelines |
| PF25 | Roblox graphics quality: `SavedQualitySetting` is Automatic or level 1 to 10. Reading a saved level is documented, but there is "no reliable way" to get the level in use under Automatic (S). No way for a script to set it was found. Shadows are disabled "at quality levels below 4". The engine "automatically starts with lower quality textures and then ramps up quality based on available device memory". | V, partly S | [SavedQualitySetting](https://create.roblox.com/docs/reference/engine/enums/SavedQualitySetting), [Improve performance](https://create.roblox.com/docs/performance-optimization/improve) |
| PF26 | Lighting: `Lighting.Technology` is being retired for `LightingStyle` plus `PrioritizeLightingQuality`. Staff mapping: Future = Realistic + prioritise on; ShadowMap = Soft + prioritise on; Voxel = Soft + prioritise off. How each renders on phones and consoles is not documented. Measured in Sprint 0: scripts cannot read `Lighting.Technology` at all; `LightingStyle` and `PrioritizeLightingQuality` are writable from Edit (plugin) code, so both are set in the project file or the build step (spike S0-A5, F22). | V (staff post, Jan 2025), U; script access measured | [Unified lighting](https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512), [Lighting](https://create.roblox.com/docs/environment/lighting) |
| PF27 | Frame rate: the Windows client has a Maximum Frame Rate setting: "Default (60 FPS, not your refresh rate), 60 FPS, 120 FPS, 144 FPS, and 240 FPS". Caps on Mac, phones, Xbox, PlayStation and handhelds are not confirmed. | V (staff post, May 2024), U | [Maximum Framerate](https://devforum.roblox.com/t/introducing-the-maximum-framerate-setting/2995965) |
| PF28 | Memory: Roblox publishes no numeric client memory limit for any device class. "Lower-end devices, particularly mobile devices, have severe memory limitations." The Studio emulator "isn't accurate for memory usage". | V | [Design for performance](https://create.roblox.com/docs/performance-optimization/design) |
| PF29 | Engine draw distance on weak phones: the RDC26 post says the minimum will rise to 500 studs in "Late 2026", "even on a low-end android device that might be running at quality level 1", and describes this as more than double today's 200. | V (announcement) | [RDC26](https://devforum.roblox.com/t/rdc26-what-we-announced/4865880) |
| PF30 | Studio: the Device Simulator previews "screen dimensions, pixel density, on-screen keyboard, and touch input"; the Controller Emulator covers "gamepads, VR controllers, handhelds, and TV remotes"; Quest headsets can be emulated; real-headset testing is "only supported on Windows"; up to 8 simulated clients; network simulation. None of these reproduce device speed or memory. | V | [Testing modes](https://create.roblox.com/docs/studio/testing-modes) |
| PF31 | Haptics use `HapticEffect`. Phones: "most iPhone, Pixel, and Samsung Galaxy devices". Pads: "PlayStation gamepads, Xbox gamepads, and the Quest Touch controller". The May 2025 release post excluded controllers on macOS 15+, controllers connected to mobile devices and PC VR controllers (may be out of date). `HapticService` is marked deprecated. Effect types seen: `UIClick`, `UIHover`, `UINotification`, `GameplayCollision`, `GameplayExplosion`, `Custom`. | V | [Gamepad input](https://create.roblox.com/docs/input/gamepad), [Mobile input](https://create.roblox.com/docs/input/mobile), [Haptics release](https://devforum.roblox.com/t/full-release-you-can-now-publish-haptic-effects-in-your-experience/3660577) |
| PF32 | Voice chat: "available to all 13+ age-verified users in a specific set of countries". Availability per console and on Quest was not confirmed. | V, partly U | [Voice chat](https://create.roblox.com/docs/chat/voice-chat) |
| PF33 | Experience notifications reach "opted-in users age 13+ through their Roblox notification stream". Whether each platform shows them as a push message is not confirmed. | V, partly U | [Experience notifications](https://create.roblox.com/docs/production/promotion/experience-notifications) |
| PF34 | Store: thumbnails 16:9, ideally 1920 × 1080, up to 10 images or videos. "Xbox, PlayStation, and VR headsets do not currently support video thumbnails." | V | [Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails) |
| PF35 | `Camera.FieldOfView` is vertical, 1 to 120, default 70. `FieldOfViewMode` chooses which axis stays constant; `MaxAxisFieldOfView` exists. In VR the docs advise leaving `VRTiltAndRollEnabled` off to prevent motion sickness. | V | [Camera](https://create.roblox.com/docs/reference/engine/classes/Camera) |
| PF36 | Not confirmed on any official page: how the Roblox purchase prompt behaves with a pad (a 2026 community bug report exists); whether Robux prices differ by platform; which platforms show rewarded video; whether private servers can be bought on console or Quest; whether Captures work on console; the frame rate Roblox runs at on each console; what `PreferredInput` and `ViewportDisplaySize` return on a Chromebook, a handheld PC or a 4K TV; whether `MouseBehavior.LockCenter` works in the Android app on ChromeOS; which DualSense button maps to `ButtonSelect`. | U | Tested on hardware in section 8 |

## 1. Platform policy

One game, one place, one set of servers. A platform is "supported" when its Playable Devices switch is on **and** the checklist for it in section 3 passes.

| Platform | Decision | Tag | Reason | Controlled by |
|---|---|---|---|---|
| iPhone, Android phone | Supported. The primary platform; every design choice is made here first. | [MVP] | Canon: phone first, core audience 9 to 16 on phones | Playable Devices: Phone |
| iPad, Android tablet | Supported, as the phone layout with the tablet scale. | [MVP] | No extra build work; document 12 (G8) lists it for soft launch | Playable Devices: Tablet |
| Windows, macOS | Supported with keys. | [MVP] | Needed for development anyway; document 02 marks the PC scheme [MVP] | Playable Devices: Computer |
| Windows, macOS with a pad | Supported. | [L] | Document 02 marks the pad scheme [L]; it is also the test bed for console | Same switch; the pad scheme is code |
| Chromebook | Supported as a by-product. Treated as a PC when a keyboard and pointer are present: desktop layout, hints follow the last input used, touch always works. | [MVP] touch and keys-only; [L] full check | Runs the Android app (PF7), so it arrives through the Phone or Tablet switch whether we plan for it or not | Whichever of Phone or Tablet Roblox files it under [U]; both are on |
| Handheld gaming PC (ROG Xbox Ally) | Supported as PC with a pad, with the handheld scale. No separate build. | [L] | Runs the Windows client natively (PF6); it is the pad scheme on a small screen | Playable Devices: Computer [U] |
| Xbox | Supported after public launch. The pad scheme and TV layout ship at [L] and are tested on PC; the Console switch is turned on in weeks 2 to 4 after launch, once the checklist in 3.5 passes on a real console. | [P1] | A solo developer cannot test console before launch without risking the launch date; document 12 (G8 and the Q1 roadmap) already says this | Playable Devices: Console |
| PlayStation 4 and 5 | Same as Xbox, same day. One Console switch covers both [U]. | [P1] | Same scheme; needs PlayStation glyphs and one test pass on a PlayStation | Playable Devices: Console |
| Meta Quest and PC VR | **Switched off.** Section 3.8 lists what it would take. Reviewed once, twelve months after launch. | Off ([P2] review) | A third-person creature that pitches, rolls and breaches is a motion-sickness problem; the whole HUD would need rebuilding; 72 fps on a Quest (PF15) against a 30 fps low tier; no headset testing from a Mac (PF30) | Playable Devices: VR, off |
| Browser play in Chrome | No action now. When Roblox releases it, treat it as Computer: the desktop layout and keys scheme should work unchanged. Test within one week of release. | [P1] when available | Announced only (PF8). Share links may open it, so the first minute must work with keys and no install | Not known [U] |
| Standalone game apps | No action. Document 12 already has a Q3 decision point. | [P2] | Terms unknown (PF9) | Not known [U] |
| Nintendo, Steam Deck, Vision Pro, smart TVs, Fire tablets | Not targeted. If Roblox adds one, it inherits the nearest presentation (pad plus TV, or touch). | None | No official support found (PF11) | None |

**Explicit decisions**

| Question | Decision |
|---|---|
| Phone orientation | **Landscape only.** `StarterGui.ScreenOrientation = LandscapeSensor`, set by hand in Studio, and set again on `PlayerGui` by the client at start because the documented default conflicts (PF21). Portrait is not planned: the game is about what is ahead and to the sides, the drag-to-swim thumb needs the wide axis, and one HUD is all a solo developer can keep tested. |
| Tablets | Same orientation rule, same HUD, tablet scale, a wider vertical field of view (section 3.2). |
| VR | Off at every stage in this document. |
| Chromebook | PC presentation with touch as a full fallback. If the pointer cannot be locked (PF36), the keys-only scheme (3.3) is the default there. |
| Handheld PC | PC with a pad, interface scale 0.90 (tune). |
| Servers | All devices share servers (section 4). |
| Console chat | The chat window is never shown on a TV (PF13). |

## 2. One design, four presentations

### 2.1 What is identical everywhere

| Area | Rule |
|---|---|
| Rules | Every number in documents 01, 02 and 05: speeds, turn rates, hit zones, mass, tiers, cooldowns, prices in Pearls. No platform gets a different rule. |
| World | One map, the same prey density, the same predators, the same tide clock on the same UTC quarter hours. |
| Servers | 24 players of any device mix. No platform-only servers (section 4). |
| Account | One save per Roblox account. A run banked on a phone is in the cove on a console (PF16). Settings that describe the device (control scheme, look speeds, graphics choice) are saved **per input type**, not per account, so a phone setting never lands on a PC. |
| Information | Outline colours, outline range (120 studs), threat arrow distances (90, 60, 30 studs), the home marker and the tide clock are the same on every device. No platform sees a threat earlier. |
| Camera distance | The follow distance by tier (document 02, section 3.1) is the same everywhere, so everyone sees the same amount of sea ahead. |
| Selling | Same items, same Robux prices [U: Roblox may price by region or platform], same rule that nothing is sold in the first two minutes. |
| Text and icons | Same strings, same icons. Only control hints differ. |

### 2.2 What changes

Two things are detected and they are independent of each other.

**Screen class** decides scale, margins and which HUD variant is used. It is worked out at join and again whenever the viewport size changes (debounced 250 ms).

| Order | Test | Screen class | deviceFactor (tune) |
|---|---|---|---|
| 1 | `GuiService.ViewportDisplaySize == Large`. (`GuiService:IsTenFootInterface()` is not used: the docs say not to detect consoles with it, PF19.) | **TV** | 0.80 |
| 2 | `ViewportDisplaySize == Small` and a pad is connected and the short side is 700 px or more | **Handheld** | 0.90 |
| 3 | `TouchEnabled` and the short side is under 500 px | **Phone** | 1.00 |
| 4 | `TouchEnabled` and not (`KeyboardEnabled` and `MouseEnabled`) | **Tablet** | 0.65 |
| 5 | Anything else | **Desktop** | 0.60 |

What these properties return on a Chromebook, a handheld PC and a 4K TV is [U] (PF36). The client logs the raw values once per session (`sess_device`, section 4.4) so the table can be corrected from real data in the first week of soft launch.

```
heightScale = (viewportHeight / 720) × deviceFactor × interfaceSize
widthScale  = safeFrameWidth / 1280
scale       = clamp( min(heightScale, widthScale), 0.40, 2.60 )
```

`interfaceSize` is a new setting [L]: 0.8 to 1.3, default 1.0. It covers a PC plugged into a TV, weak eyesight and handhelds without more detection rules. The width term guarantees that 1,280 rpx always fit, which the height-only formula in document 08 does not (a narrow desktop window breaks it).

**Input mode** decides the control scheme, the hints and the assist strength. It is `UserInputService.PreferredInput`, re-read on every change (section 5). Values: `Touch`, `Keys`, `Pad`.

| | Phone | Tablet | Desktop | Handheld | TV |
|---|---|---|---|---|---|
| Usual input mode | Touch | Touch | Keys | Pad | Pad |
| Other modes that must work | Pad [L] | Keys, Pad [L] | Touch (Chromebook, touch laptops), Pad [L] | Touch, Keys | None |
| HUD variant | Touch buttons | Touch buttons, 24 rpx further in | Hint tiles with key caps | Hint tiles with pad glyphs | Hint tiles with pad glyphs, 5% TV margins |
| Scale at a typical size | 0.52 at 375 px tall | 0.69 at 768 px | 0.90 at 1,080 px | 1.35 at 1,080 px; 1.00 at 800 px | 1.20 at 1,080 px |
| Smallest text (22 rpx) becomes | 11 px | 15 px | 20 px | 30 px; 22 px | 26 px |
| Camera | Follows on its own | Follows on its own | Mouse drives it | Follows; right stick looks around | Follows; right stick looks around |
| Vertical field of view (base) | 70° | 70° to 79° by aspect | 70°, lowered past 21:9 | 70° | 70° |
| Starting graphics tier | Smooth | Balanced | Balanced | Balanced | Balanced |
| Frame rate target | 30 (Smooth), 60 above | 60 | 60 or the player's cap | 60 | 60; 30 on older consoles |
| Session we design for (tune) | 15 to 25 min, several a day | 20 to 40 min | 30 to 60 min | 20 to 40 min | 30 to 60 min |
| Chat window (off in the MVP; [L] only if the launch review turns chat on, canon 14) | Shown | Shown | Shown | Shown | Never shown |

Session lengths other than the phone's (canon) are assumptions. They are replaced by measured values from `sys_session_end` split by `sess_input` after two weeks of data.

### 2.3 The four presentations in one line each

| Presentation | Used by | In one line |
|---|---|---|
| **Touch** | Phone, tablet | One thumb drags to swim, two big buttons under the other thumb, the camera does its own work. |
| **Desk** | Windows, Mac, Chromebook with keys | The mouse aims, the hand rests on W, Space and E; the HUD shrinks to hints and a longer leaderboard. |
| **Pad** | PC with a pad, handheld PC | Left stick swims exactly like the phone drag; everything else is a button; hints are glyphs. |
| **Couch** | Xbox, PlayStation, any TV | The Pad presentation with larger scale, 5% TV margins, full focus navigation in menus, no chat. |

## 3. Each platform

### 3.0 Shared tables

These three tables apply to every platform section below.

**Graphics tiers.** The names are the ones in the settings screen (document 08, section 6.7). They equal Low, Mid and High in document 09, section 15.1. The tiers change **GULP's own load only**. Roblox's quality level (1 to 10 or Automatic) belongs to the player and scripts cannot set it (PF25).

| Item | **Smooth** (Low) | **Balanced** (Mid) | **Pretty** (High) |
|---|---|---|---|
| Typical device | Phones with 4 GB of RAM or less, old laptops | Recent phones, tablets, handhelds, most laptops, older consoles | Gaming PCs, current consoles, flagship tablets |
| Frame rate target | 30 fps | 60 fps | 60 fps or the player's cap |
| Lighting | One place-wide setting for everyone: `LightingStyle = Realistic`, `PrioritizeLightingQuality = true` (document 06, section 10.1), set in the project file or the build step, not by game scripts (PF26). It cannot differ per device; the engine lowers it with the player's quality level [U how]. | Same | Same |
| Shadows | Off (`GlobalShadows = false` on this client). Roblox also drops them below quality level 4 (PF25). | On: landmarks, cliffs and floor only | On, same casters |
| Colour correction | On | On | On |
| Bloom | On, intensity 0.4 (tune) | On, 0.6 | On, 0.6 |
| Sun rays | Off | Off | On within 40 studs of the surface |
| Depth of field (cove inspect only) | Off | On | On |
| Blur behind menus | Off; a 60% dark scrim instead | On | On |
| Fog: zone view distance (document 06, section 10.2: legacy fog, which hit its caps exactly in Sprint 0, F21) | Capped at 220 studs (tune). Hides the engine's 200-stud draw limit on weak phones (PF29). | Capped at 350 studs | As authored (200 to 450) |
| Caustic shells | Off | Within 100 studs | Within 150 studs |
| Light shafts visible | 12 | 18 | 24 |
| Prey drawn as meshes (pool size) | 80 | 150 | 250 |
| Prey mesh distance | To 150 studs | To 250 studs | To 350 studs |
| Prey visible in total, including particle clusters and glints | 250 | 400 | 800 |
| Far prey particle emitters | 30 | 60 | 60 |
| Creature rigs fully animated | 8 | 16 | 24 |
| Skinned creatures drawn at LOD0 or LOD1 | 30 | 50 | 120 |
| Best level of detail for other players | LOD1 (LOD0 for your own creature only) | LOD0 for the 4 nearest | Document 06, section 6.4 as written |
| Outlined objects | 12 (8 edible, 4 dangerous) | 30 (20, 10) | 30 (20, 10) |
| Live particles | 400 | 600 | 1,200 |
| Active particle emitters | 40 | 80 | 150 |
| Trails visible | 12 | 20 | 30 |
| Creature point lights | 8 | 12 | 16 |
| Cove specimens | Animated (still meshes from cut step 5) | Animated | Animated |
| Triangles in view | 150,000 | 300,000 | 600,000 |
| Draw calls | 250 | 400 | 700 |
| Our script time per frame | 6 ms | 4 ms | 3 ms |
| Client memory ceiling, total | 900 MB | 1,300 MB | 2,500 MB |
| Texture sizes | Same files on every tier: 256 prey, 512 creatures, 1,024 for five named assets. The engine chooses texture quality from device memory (PF25); we cannot. | Same | Same |

All counts (tune). Where documents 06 and 09 give different numbers for the same budget, this table is the decision (section 10, items 9 and 10).

**Cut order when a device still struggles on Smooth.** One step every 10 s while the average stays under 25 fps. This is document 09, section 15.6, with step 6 changed because streaming radius cannot be set per device (document 09, V4).

| Step | Cut |
|---|---|
| 1 | Prey meshes 80 → 50; the rest of the mid band become particles |
| 2 | Animated rigs 8 → 4; others freeze beyond 60 studs |
| 3 | Particle emitters 40 → 20; far-prey glints off; marine snow off |
| 4 | Outlines on the 6 nearest objects only |
| 5 | Cove specimens drawn as still meshes |
| 6 | Zone view distance capped at 160 studs (fog pulled in). No change to streaming radius. |
| 7 | Prey near band 150 → 110 studs |
| 8 | Bloom and colour correction off |

Never cut on any device: edible and danger outlines on the nearest 6 objects, threat arrows, bite, gulp, tier-up, ink and gull-shadow effects (document 06, section 11.4).

**Performance targets by device class.** Our own numbers (tune); Roblox publishes none (PF28).

| Device class | Starting tier | Target | Floor (worst 10 s average allowed in a test) | Memory ceiling |
|---|---|---|---|---|
| Low phone | Smooth | 30 fps | 25 fps | 900 MB |
| Mid phone | Balanced | 60 fps | 50 fps | 1,300 MB |
| Flagship phone | Balanced, may rise to Pretty | 60 fps | 55 fps | 1,300 MB |
| Tablet | Balanced | 60 fps | 50 fps | 1,300 MB |
| Low-end laptop, Chromebook | Balanced, expected to settle on Smooth | 30 fps on Smooth | 25 fps | 1,300 MB |
| Gaming PC | Balanced, rises to Pretty | 60 fps, up to the player's cap (240 on Windows, PF27) | 60 fps | 2,500 MB |
| Handheld PC | Balanced | 60 fps | 45 fps | 2,500 MB |
| Xbox Series, PlayStation 5 | Balanced, rises to Pretty | 60 fps [U cap] | 55 fps | 2,500 MB |
| Xbox One, PlayStation 4 | Balanced | 30 fps [U cap] | 28 fps | 1,300 MB |

All movement, camera and interface code uses the real frame time, so the game plays the same at 25 fps and at 240 fps. The test for this is in 3.3.

### 3.1 Phone (small and large) [MVP]

**Who plays here.** The core audience (canon: 9 to 16). Phone held sideways in two hands, 25 to 40 cm from the eyes, often with sound off. Sessions of 15 to 25 minutes, several a day, runs of 3 to 8 minutes, frequent interruptions. A "small phone" has a short side under 380 px (667 × 375, 640 × 360); a "large phone" has 380 px or more (932 × 430, 915 × 412).

**Layout, small phone** (667 × 375 px, scale 0.52, canvas 1,283 × 721 rpx). This is the reference layout of document 08, section 3.1; every other platform is described as a change from it.

```
+--------------------------------------------------------------------------------+
|[R][chat]        (T4)[======== 86 ====  >114](T5)          (lag) (TIDE) [gear]  |
| keep-out             ( o 387 x1.5 <fish> )                       0:45          |
|[#1 Mako 412]        [ moment slot 480 x 112 ]                  [ toast 320x64 ]|
|<<                                                                              |
| threat          . . . . . . . . . . . . . . . . . .                  (home)    |
| arrow           .       keep-clear box            .                   120 m    |
|                 .   x 28% to 72%, y 34% to 76%    .                            |
|   ( drag )      .        (the creature)           .                 (emote)    |
|   ( ring )      . . . . . . . . . . . . . . . . . .                            |
|   168 rpx                 [st][st]                                             |
|                    (safe) (tr1)(tr2)(tr3)                 (ABILITY)  ( DASH )  |
|                             80 rpx each                    108 rpx   136 rpx   |
+--------------------------------------------------------------------------------+
```

**Layout, large phone** (932 × 430 px, scale 0.60, canvas about 1,560 × 720 rpx, of which about 1,360 rpx are inside the notch and corner insets). Nothing stretches: the extra width is open water between elements pinned to the edges and the centre.

```
+----+------------------------------------------------------------------------------+----+
| n  |[R][chat]          (T4)[======== 86 ====  >114](T5)        (lag) (TIDE) [gear]| i  |
| o  | keep-out               ( o 387 x1.5 <fish> )                     0:45        | n  |
| t  |[#1 Mako 412]          [ moment slot ]                        [ toast        ]| s  |
| c  |<<             . . . . . . . . . . . . . . . . . . . .              (home)    | e  |
| h  |               .          keep-clear box             .               120 m    | t  |
|    |  ( drag )     .          (the creature)             .             (emote)    |    |
|    |  ( ring )     . . . . . . . . . . . . . . . . . . . .                        |    |
|    |                         (safe) (tr1)(tr2)(tr3)          (ABILITY)   ( DASH ) |    |
+----+------------------------------------------------------------------------------+----+
  water and scrims reach the glass; every HUD element stays inside the device safe area
```

| Item | Rule | Small phone | Large phone |
|---|---|---|---|
| Dash button (136 rpx) | Zone A, bottom right | 71 px | 81 px |
| Ability button (108 rpx) | Zone A | 56 px | 64 px |
| Smallest touch target (88 rpx hit area) | Document 08, section 1.5 | 46 px (about 7 mm) | 53 px |
| Text floor (22 rpx); in-run numbers (28 rpx) | Nothing smaller, ever | 11 px; 15 px | 13 px; 17 px |
| Safe area | `ScreenInsets = DeviceSafeInsets` on every HUD layer; scrims use `None` (PF22) | | |
| Margins inside the safe area | 16 rpx top and sides, 28 rpx bottom; tappable items stay 40 rpx above the bottom (home bar) | | |
| Roblox keep-out | Read `GuiService.TopbarInset` at start and on every rotation; fallback 200 × 58 px, top left | | |
| `HUD.Biggest` | One row; tap for the top 3 for 5 s | | |

**Controls (Touch).** This table is the single source for touch on every device.

| Action | Control | Detail |
|---|---|---|
| Swim | Drag anywhere that is not a button | Floating origin; dead zone 14 px, full at 80 px, clamp 100 px; left and right turn at up to the tier's turn rate, up and down set pitch up to ±70° |
| Look | None. The camera follows. | Two-thumb scheme [L]: drag on the right 60%, 0.35° per px |
| Brake | Lift the thumb | Coasts to a stop. Two-thumb [L]: stick down |
| Dash | `HUD.Dash` | Press; holding repeats on cooldown ("held dash", on by default) |
| Ability | `HUD.Ability` | Press. A badge with no press for Minnow, Eel and Shark Pup |
| Shed a trait | Tap a filled slot, then hold the Shed ring 600 ms | With "Tap instead of hold": tap, then Yes within 3 s |
| Emote wheel [L] | Tap `HUD.Emote` (stays 3 s), or hold it, slide and release | |
| Open menu | Gear: settings side panel, any time. Dock buttons: full menus, in the cove only | |
| Bank | Swim into your own cove mouth. No button. | |
| Home marker | Always shown in a run; display only | |
| Tide schedule; full "biggest" list | Tap the tide clock; tap the strip | |
| Navigate menus | Tap; drag to scroll; swipe the species carousel | |
| Confirm; back | Tap the primary button; tap the close button (top right, 88 rpx) or the scrim | The Android system back gesture is not bound [U what Roblox does with it] |

| Setting | Default | Range |
|---|---|---|
| Scheme | Drag to swim | Drag to swim; Two thumbs [L] |
| Drag sensitivity | 1.0 (full deflection at 80 px) | 0.5 to 1.5 |
| Two-thumb look speed [L] | 1.0 (0.35° per px) | 0.5 to 2.0 |
| Left-handed [L]; flip up and down | Off; off | |
| Assist | Strongest set (section 4.2) | Not adjustable |
| Remapping | None. Left-handed [L] mirrors the buttons. | |

**Camera.** Follow distance `4 + 10 × bodyScale` studs, vertical field of view 70° (113° horizontal on a 19.5:9 phone, 102° on 16:9), plus 6° with speed and 10° on a dash. Automatic follow: yaw smoothing 0.18 s, camera pitch is 0.6 × creature pitch. No free look in the default scheme.

**What it looks like.** Smooth on low phones, Balanced on mid phones, and Pretty only if a flagship holds 60 fps through a probe (section 6). On Smooth the sea is shorter (220-stud fog), has no shadows and no caustics, and other players are drawn one detail level down. Colours, outlines, fog tint and silhouettes are unchanged: document 06, section 10.5 designs the look for this case first.

**Performance.** See 3.0. Low phone 30 fps target, 25 floor, 900 MB. Mid and flagship 60 target, 1,300 MB. A phone that heats up and slows mid-session steps down a tier (section 6) and does not step back up in that session.

**Menus.** Touch only. Full menus open in safe water; in open water only the settings panel and popovers. One close control, top right. Lists scroll by drag. No hint bar and no glyphs.

| Rule | Detail |
|---|---|
| Purchases | The Roblox purchase prompt, which cannot be restyled. The 700 ms input guard on the gulped panel (document 08, D10) matters most here: a steering thumb is already on the glass. |
| Chat and voice | No voice anywhere (`EnableDefaultVoice = false`, document 09). The chat window is off at [MVP] (canon 14). If the launch review turns chat on, the [L] chat panel sits in the left column, 12% to 45% of the height. |
| Notifications | The two cove notifications of document 12 (N6, N7). Opt-in, 13 and over (PF33). |
| Haptics | `HapticEffect` on phones that support it (PF31). Light = `UIClick`, medium = `GameplayCollision`, heavy = `GameplayExplosion` (tune). The millisecond lengths in document 08, section 11.4 are targets; built-in types may not match them [U]. Off with the Vibration setting. |
| Interruptions | A call or app switch may drop the connection [U how fast]. Document 02, sections 16.4 and 16.5 already cover a mid-run disconnect and reconnect. |

**Test checklist**

- [ ] A full run to tier 4 and a bank, two hands, no grip change, on the smallest supported phone (667 × 375).
- [ ] Nothing is under the notch, the rounded corners, the home bar or the Roblox buttons, with the phone turned both ways.
- [ ] Tier, mass, dash state and nearest threat are read in a 0.5 s glance at 40 cm.
- [ ] Holding the phone upright does not rotate the game to portrait.
- [ ] A second thumb on the glass never steals the swim drag; the dash button never starts a drag.
- [ ] Ten minutes in the Sunlit Reef during a Feeding Frenzy on the low phone: 10 s average never under 25 fps, memory under 900 MB, no crash.
- [ ] After 20 minutes of play the device is warm, not hot, and the tier has not dropped below Smooth step 3.
- [ ] Purchase prompt opens, completes and cancels; the game still steers afterwards.
- [ ] Haptics fire on bite, dash, tier-up and gulp, and stop when Vibration is off.

### 3.2 Tablet [MVP]

**Who plays here.** Younger players at home, tablet on a table, a lap or a stand, 35 to 50 cm away; also tablets with a keyboard case. Sessions assumed at 20 to 40 minutes (tune). The screen is big, the thumbs are not: reach matters more than on a phone.

**Layout** (1,024 × 768 px, scale 0.69, canvas 1,484 × 1,113 rpx). The phone HUD with more water. Buttons keep their rpx size, so they cover less of the screen.

```
+----------------------------------------------------------------------------+
|[R][chat]       (T4)[======= 86 ===  >114](T5)        (lag) (TIDE) [gear]   |
| keep-out            ( o 387 x1.5 <fish> )                   0:45           |
|[#1 Mako 412]       [ moment slot ]                      [ toast        ]   |
|                                                                            |
|<<            . . . . . . . . . . . . . . . . . . .                         |
|              .                                   .              (home)     |
|              .        keep-clear box             .               120 m     |
|              .        (the creature)             .                         |
|              . . . . . . . . . . . . . . . . . . .            (emote)      |
|  ( drag )                                                                  |
|  ( ring )              [st][st]                                            |
|                 (safe) (tr1)(tr2)(tr3)              (ABILITY)   ( DASH )   |
|                                                                            |
+----------------------------------------------------------------------------+
```

| Compared with the phone | Change |
|---|---|
| Dash, ability, emote | 24 rpx further from the edges (document 08). Dash is 94 px at this size. |
| Text floor | 22 rpx = 15 px |
| Thumb zones | Same rpx distances; zone A is about 45 mm from each bottom corner on a 10-inch tablet |
| Menus | Same rpx size, centred, so they cover a smaller share of the screen than on a phone |
| Top bar keep-out, safe area | Same rules; most tablets have no notch |
| Split view or a floating window | The width term of the scale formula keeps 1,280 rpx visible. Not otherwise supported. |

**Controls.** The Touch table in 3.1, unchanged. Drag to swim stays the default; the two-thumb scheme [L] is offered in the first-run hint on tablets because both thumbs are already on the glass. With a keyboard case the input mode becomes Keys and the tablet uses the Desk controls in 3.3 at tablet scale; with a paired pad it uses the Pad controls. Defaults, ranges and assists are the same as the phone.

**Camera.** Same distance. A 4:3 screen at 70° vertical shows only 86° across, against 102° on a 16:9 phone, so a tablet player would see less to the sides. Decision: the horizontal field of view is held between **95° and 117°** on every device (tune) by adjusting the vertical one, capped at 90°.

```
vFOV = 70°
if hFOV(vFOV, aspect) < 95°:  vFOV = min(90°, 2 × atan( tan(47.5°) / aspect ))
if hFOV(vFOV, aspect) > 117°: vFOV = 2 × atan( tan(58.5°) / aspect )
```

| Aspect | Example | Vertical | Horizontal |
|---|---|---|---|
| 4:3 | iPad 1,024 × 768 | 79° | 95° |
| 1.44 | iPad 1,180 × 820 | 74° | 95° |
| 16:10 | Android tablets, many laptops | 70° | 97° |
| 16:9 | Phones, monitors, TVs | 70° | 102° |
| 19.5:9 | Large phones | 70° | 113° |
| 21:9 | Ultrawide monitors | 70° | 117° |
| 32:9 | Super-ultrawide | 49° | 117° |

**What it looks like.** Balanced at start. A large screen shows low detail more than a phone does, so tablets hold Balanced and drop frame rate target last: a tablet steps down to Smooth only if it cannot hold 50 fps.

**Performance.** 60 fps target, 50 floor, 1,300 MB. Old tablets with 2 to 3 GB of RAM are treated as low phones.

**Menus and rules.** As the phone. Purchases, chat, notifications and haptics follow 3.1; many tablets have no vibration motor, so nothing may depend on it.

**Test checklist**

- [ ] Held in two hands at the lower corners, the thumbs reach dash, ability and every trait slot without letting go.
- [ ] 4:3 and 16:10 screenshots show at least 95° across (a marker 47° off-centre at 100 studs is on screen).
- [ ] Menus are centred and no element is stretched.
- [ ] Attach a keyboard mid-run: hints change to key caps within 200 ms, the creature keeps swimming, touch still works.
- [ ] Ten-minute Frenzy run holds 50 fps on the test tablet.

### 3.3 PC and Mac [MVP keys] [L pad]

**Who plays here.** The secondary audience (17 and over) and core players at a desk. Seated, 50 to 70 cm from a 13 to 27 inch screen, usually with sound. Sessions assumed at 30 to 60 minutes (tune): more Leviathan runs, more time in the Codex and shop. Many are on laptops with a trackpad and no mouse.

**Layout, keys** (1,920 × 1,080 px, scale 0.90, canvas 2,133 × 1,200 rpx). From document 08, section 3.2.

```
+------------------------------------------------------------------------------------------+
| [R][chat]            (T4)[=========== 86 ====   >114 ](T5)           (lag) (TIDE) [gear] |
|                               ( o 387  x1.5  <fish> )                       0:45   [P]   |
| [#1 Mako    412 ]                                                            [C]         |
| [#2 Pip     388 ]        [ moment slot: banners, tier-up ]              [ toast        ] |
| [#3 You     286 ]                                                                        |
| [#4 Lumo    120 ]                                                                        |
| [#5 Kai      64 ]                                                              (home)    |
|   [Tab]                               .                                         120 m    |
|                                    reticle                                               |
|                                 [st][st]                               (ABIL)  (DASH)    |
|                          (safe) (tr1) (tr2) (tr3)             [T]       [E]    [Space]   |
|                                  [1]   [2]   [3]                                         |
+------------------------------------------------------------------------------------------+
```

**Layout, pad** (same canvas). Key caps become glyphs, the reticle goes, the cursor is hidden.

```
+------------------------------------------------------------------------------------------+
| [R]                  (T4)[=========== 86 ====   >114 ](T5)           (lag) (TIDE) [gear] |
|                               ( o 387  x1.5  <fish> )                 0:45  (R3)  (View) |
| [#1 Mako    412 ]                                                                        |
| ... 5 rows  (L3)         [ moment slot: banners, tier-up ]              [ toast        ] |
|                                                                                (home)    |
|                              (the creature, no reticle)                         120 m    |
|                                 [st][st]                      (emote)  (ABIL)  (DASH)    |
|                          (safe) (tr1) (tr2) (tr3)              (Dv)     (X)     (A)      |
|                                  (D<)  (D^)  (D>)                                        |
+------------------------------------------------------------------------------------------+
```

| Compared with the phone | Change |
|---|---|
| Dash and ability | Hint tiles 80 × 96 rpx (icon with cooldown, key cap or glyph under it); they show state, they are not pressed with the cursor in a run |
| Drag ring, emote button | Gone; the emote hint sits beside the ability tile [L] |
| `HUD.Biggest` | 5 rows; Tab (or L3) shows all 24 |
| Reticle | 32 rpx dot at the centre, keys only |
| Smallest mouse target | 48 × 48 rpx (43 px at 1,080p) |
| Text floor | 22 rpx = 20 px at 1,080p; 14 px at 768p |
| Safe area | No notch. Roblox top-bar keep-out still applies. |
| Hover | Buttons scale 1.04; icon-only elements show a name chip after 400 ms. Nothing needs a hover. |

**Controls (Keys and Pad).** This table is the single source for keys and pads on every device. It settles the differences between documents 02 and 08 (section 10, items 3 to 6).

| Action | Keys | Pad (Xbox names) |
|---|---|---|
| Swim forward | W; R toggles auto-swim | Left stick: how far it is pushed is the throttle |
| Steer | Mouse: 0.20° per px × look speed; the creature turns to face the camera, pitch ±70°. **Arrow keys also steer** [MVP]: left and right turn at the tier's turn rate, up and down pitch at the same rate. | Left stick: left and right turn at up to the tier's turn rate, up and down set pitch up to ±70° (the phone mapping). Dead zone 0.15. |
| Look without steering | None | Right stick: up to ±120° and ±50° at 180° per second; recentres 0.8 s after release. Dead zone 0.20. |
| Brake | S | LT |
| Strafe | A and D | None |
| Dash | Space or left mouse button | A or RT |
| Ability | E or right mouse button | X or RB |
| Shed trait 1, 2, 3 | 1, 2, 3: press for the popover, hold 600 ms to shed | D-pad left, up, right: same press and hold |
| Emote wheel [L] | Hold T, move the mouse or press 1 to 6, release | Hold D-pad down, pick with the right stick, release |
| Settings | P | View button (in the cove: moves focus to the dock) |
| Tide schedule | C | Press the right stick |
| Full "biggest" list | Hold Tab | Press the left stick |
| Free the cursor | Hold Left Alt (Option on a Mac) | Not needed |
| Bank | Swim into your own cove mouth. No button. | Same |
| Home marker | Always shown; display only | Same |
| Navigate menus | Mouse; wheel scrolls; Q and E change tab; 1 to 6 pick a dock button in the cove | D-pad or left stick moves focus; LB and RB change tab; right stick scrolls; LT and RT jump a page |
| Confirm | Enter, or click | A |
| Back or close | Backspace, or click the close button | B |
| Extra action on a screen (Claim all, Bubble, sort) | F | Y |
| Roblox menu (not ours) | Esc | Menu button |
| Unbound in a run | Slash, F9, F11, Print Screen stay with Roblox | LB (reserved) |

| Setting | Default | Range |
|---|---|---|
| Mouse look speed | 1.0 (0.20° per px) | 0.2 to 3.0 |
| Pad look speed | 1.0 (180° per second) | 0.5 to 2.0 |
| Pad stick curve | Exponent 1.4, as the phone drag | Fixed |
| Flip up and down | Off | Per input type |
| Swap sticks [L] | Off | |
| Assist | Keys: weakest set. Pad: same as touch (section 4.2). | Not adjustable |
| Remapping | [MVP] and [L]: none; two inputs per main action already. [P1]: a key rebinding list for desktop (dash, ability, brake, auto-swim, shed 1 to 3, emote, settings, tide, list), saved in the profile. Esc, slash, F9, F11 and Print Screen can never be bound. Pads get no rebinding. | |

**Why arrow keys steer.** Many laptop trackpads ignore movement while a key is held, so "mouse aims, Space dashes" fails on the cheapest machines. Arrow keys turn the look direction, so the game is fully playable with a keyboard alone. They are always active in Keys mode; there is no separate scheme to choose.

**Camera.** Keys: the mouse drives the camera directly (no smoothing) and the creature turns to follow at its tier's turn rate; no auto-level. Pad: automatic follow as on the phone, with the right stick as a temporary look-around. Same distance as every platform. Field of view by the table in 3.2; past 21:9 the vertical angle is lowered so an ultrawide monitor shows no more sea to the sides than a 21:9 one.

**What it looks like.** Balanced at start; Pretty after a successful probe (section 6), which most PCs with a separate graphics card will pass: sun rays near the surface, 350-stud prey meshes, full fog distance, 24 animated rigs. A low-end laptop usually settles on Smooth.

**Performance.** See 3.0. On Windows the player can raise Roblox's cap to 240 fps (PF27); on a Mac the cap is [U]. Frame-rate independence test: at caps of 30, 60 and 240 fps a tier 1 creature at full speed covers 260 studs in 10 s ± 2%, and a 360° turn and a dash each take the same time and cover the same distance at all three caps, within 2%.

**Menus.** Keys: cursor, with key caps on buttons (Enter, Backspace, Q and E, F). The mouse is locked and hidden while swimming and freed whenever a panel is open, on the gulped panel and bank summary, and while Left Alt is held. Pad: full focus navigation as in 3.5, at desktop scale; the hint bar shows glyphs.

| Rule | Detail |
|---|---|
| Purchases | Roblox prompt, by mouse; by pad [U] (checked in 3.5) |
| Chat and voice | Chat window off at [MVP]; the [L] panel is shown only if the launch review turns chat on. Slash stays Roblox's chat key. No voice. |
| Notifications | Arrive in the Roblox notification stream (PF33). No desktop push is assumed. |
| Haptics | Pad only. At the 2025 release, pads on macOS 15 and later did not vibrate (PF31, may be out of date). The Vibration setting shows only in Touch and Pad modes. |
| Mac | Option is the free-cursor key. Function keys are not used for anything, because Mac laptops and Chromebooks do not send them without a modifier. |
| Window | Any size and shape; see section 5. |

**Test checklist**

- [ ] A full run and a bank using the mouse and W, Space, E; another using only the keyboard (arrows); another using only a pad.
- [ ] The cursor is never visible while swimming and always visible when a panel is open; Left Alt frees it; no click falls through a panel into a dash.
- [ ] Every HUD action has a key and its key cap is shown; nothing needs a hover.
- [ ] Esc opens the Roblox menu and nothing of ours; closing it returns the mouse lock.
- [ ] Frame-rate independence test above passes.
- [ ] Windows at 1,366 × 768, 1,920 × 1,080, 2,560 × 1,080 and 3,840 × 2,160; a Mac laptop at its default scaled resolution: no overlap, text at or above the floor.
- [ ] Plug a pad in mid-run and unplug it: hints swap within 200 ms each way, the creature never stops responding.

### 3.4 Chromebook [MVP as touch and keyboard; L full check]

**Who plays here.** School-age players on a family or school laptop: 11.6 to 14 inch screen at 1,366 × 768, a keyboard, a trackpad, often a touchscreen, rarely a mouse, 4 GB of RAM. 40 to 60 cm away. Sessions assumed at 20 to 40 minutes (tune). Roblox here is the Android app (PF7), so the device is slow, and what the engine reports about it is [U].

**Layout.** The Desk HUD of 3.3 at scale 0.64 (text floor 14 px). Because the screen can also be touched, the touch buttons return whenever the input mode is Touch, at the desktop scale: dash 87 px, about 16 mm on an 11.6-inch screen.

```
 Keys mode: exactly the Desk HUD in 3.3.          Touch mode on the same screen:
+---------------------------------------------+  +---------------------------------------------+
| [R][chat]  (T4)[==== 86 ==](T5) (TIDE)[gear]|  | [R][chat]  (T4)[==== 86 ==](T5) (TIDE)[gear]|
| [#1 Mako 412]                    0:45  [P]  |  | [#1 Mako 412]                    0:45       |
| ... 5 rows       [ moment ]      [ toast ]  |  | ... 5 rows       [ moment ]      [ toast ]  |
|   [Tab]              .             (home)   |  |                                   (home)    |
|                   reticle                   |  |  ( drag )     (creature)         (emote)    |
|            (tr1)(tr2)(tr3)   (ABIL) (DASH)  |  |  ( ring )  (tr1)(tr2)(tr3) (ABILITY)(DASH)  |
|             [1]  [2]  [3]     [E]  [Space]  |  |                                             |
+---------------------------------------------+  +---------------------------------------------+
```

**Controls.** Keys column of 3.3 and Touch table of 3.1, switching on the last input used (section 5). Three points are specific to this device:

| Point | Rule |
|---|---|
| Pointer lock | Whether `MouseBehavior.LockCenter` works in the Android app on ChromeOS is [U] (PF36). The client tests it at the first run: if the pointer position still moves after the lock is set, mouse aiming is switched off for the session, the cursor stays visible, and the first-run hint teaches the arrow keys. |
| Trackpad | Arrow keys steer (3.3), so a trackpad is never required. |
| Top-row keys | Not used. Search, Alt and the browser keys are never bound. |

Defaults, look speeds and assists are those of the active input mode. No remapping.

**Camera.** As the active input mode: mouse-driven when the lock works, automatic follow with arrow keys or touch. 16:9 or 16:10, so 70°.

**What it looks like and performance.** Starts on Balanced and is expected to settle on Smooth within the first minute. Target 30 fps, floor 25, memory ceiling 1,300 MB (tune; these devices behave like a low phone with a bigger screen). The cut order in 3.0 applies.

**Menus.** Cursor or touch, whichever was used last. Key caps show only in Keys mode.

**Platform rules.** As the phone for purchases and notifications (it is the Android app). Chat [L] shown. No vibration motor on most models.

**Test checklist**

- [ ] On a 4 GB Chromebook: join, first bite within 10 s, a run to tier 3 and a bank, with keyboard only.
- [ ] The same with touch only, and with trackpad plus keyboard.
- [ ] Record what `PreferredInput`, `ViewportDisplaySize`, `TouchEnabled`, `KeyboardEnabled` and `MouseEnabled` report, and whether the pointer locks. Correct section 2.2 from the result.
- [ ] Touch the screen mid-run: touch buttons appear within 200 ms; press a key: they go.
- [ ] Ten-minute Frenzy run holds 25 fps.
- [ ] Resize the app window and switch to tablet mode on a convertible: the HUD rescales, nothing overlaps.

### 3.5 Xbox [P1]

**Who plays here.** Players on a sofa, 2 to 3.5 m (8 to 10 feet, PF13) from a 40 to 65 inch TV, pad in both hands, sound on, often with someone watching. Sessions assumed at 30 to 60 minutes (tune). No pointing device and no keyboard: everything is focus and buttons.

**Layout** (1,920 × 1,080 px, scale 1.20, canvas 1,600 × 900 rpx; the safe frame is the inner 90%: 1,440 × 810 rpx).

```
+------------------------------------------------------------------------------------------+
|  outer 5% on every side: water and scrims only                                           |
|   +----------------------------------------------------------------------------------+   |
|   |               (T4)[========= 86 ====  >114](T5)             (TIDE) (R3)   (View) |   |
|   |                    ( o 387  x1.5  <fish> )                   0:45         [gear] |   |
|   | [#1 Mako   412]                                                                  |   |
|   | [#2 Pip    388]     [ moment slot ]                          [ toast          ]  |   |
|   | [#3 You    286]                                                                  |   |
|   | [#4 Lumo   120]                                                        (home)    |   |
|   | [#5 Kai     64]             (the creature)                              120 m    |   |
|   |   (L3)                                                                           |   |
|   |                           [st][st]                     (emote) (ABIL)  (DASH)    |   |
|   |                    (safe) (tr1)(tr2)(tr3)               (Dv)    (X)     (A)      |   |
|   |                           (D<) (D^) (D>)                                         |   |
|   +----------------------------------------------------------------------------------+   |
+------------------------------------------------------------------------------------------+
```

| Compared with the phone | Change |
|---|---|
| Margins | 5% of the screen on every side (96 × 54 px at 1,080p), then the normal 16 rpx. Roblox gives no number (PF14); 5% is the usual title-safe figure (tune). |
| Dash, ability, emote | Hint tiles with glyphs, as PC with a pad |
| Drag ring, reticle, top bar | No drag ring, no reticle. Whether Roblox draws a top-bar button on console is [U]; read `TopbarInset` and keep clear of whatever it reports. |
| `HUD.Biggest` | 5 rows; L3 for all 24 |
| Text floor | 22 rpx = 26 px at 1,080p. In-run numbers 28 rpx = 34 px. On a 4K viewport the scale is 2.40 and the same text is 53 px. |
| Focus ring | `UI_Common_FocusRing`, 4 rpx thick, always visible in menus |
| Glyph size | 40 rpx on elements; 56 rpx hint bar across the bottom of every menu |

**Controls.** The Pad column of 3.3, unchanged. Pad look speed 1.0, dead zones 0.15 and 0.20, assists as touch (section 4.2). Glyphs are our own art (`UI_Hint_PadA` and so on). No remapping in the game.

**Camera.** Automatic follow, right stick looks around, 70°, same distance. Nothing else differs: a TV does not get a wider view.

**What it looks like.** Xbox Series consoles: Balanced, rising to Pretty by probe. Xbox One, if Roblox still serves it [U]: Balanced with a 30 fps target. There is no API to tell the two apart (PF20), so the frame-time sample decides.

**Performance.** See 3.0. The frame rate Roblox runs at on each console is [U]; the numbers there are targets to confirm in the first hardware test.

**Menus: focus navigation.** As document 08, section 10.4, which stays the reference for per-screen focus order.

| Rule | Detail |
|---|---|
| Reach | Every element on every screen is reachable with the four directions, A and B (PF13). Neighbours are set by hand; no automatic guessing. |
| Depth | No action is more than 6 presses from the cove HUD (tune) |
| Open | View moves focus to the dock; A opens; LB and RB change tab; B closes and returns focus to where it came from |
| Run HUD | Never focusable; every run action is a button press |
| Virtual cursor | Off. Roblox offers one (PF24); we do not use it. |
| Shop | LB and RB change tab, four-way through cards, A presses the price button, which opens the Roblox prompt |
| Codex and specimen grid | Four-way through the grid; A opens; left and right step through entries; Y sorts |
| Settings | Up and down through rows; left and right change a value; A flips a toggle |
| Text entry | None. GULP has no text field, so the on-screen keyboard never appears. |

| Platform rule | Detail |
|---|---|
| Listing | Content maturity information is required (PF13); document 12, G7 already completes it. No other approval step is documented (PF14). |
| Purchases | The Roblox prompt must open, complete and cancel with the pad and return focus. This is [U] (PF36) and **blocks the Console switch** if it fails. |
| Chat and voice | No chat window on a TV, at any stage (PF13). No voice. The emote wheel [L] is the only signalling. |
| Rewarded video | Shown only when `AdService:GetAdAvailabilityNowAsync` says so (document 09, V21); the button is hidden otherwise. Console eligibility is [U]. |
| Notifications | Through the Roblox notification stream only (PF33) |
| Haptics | `HapticEffect` on Xbox pads (PF31), same mapping as 3.1, at most one every 80 ms |
| Store | Video thumbnails are not shown (PF34); see section 7 |
| Pad lost | If the last pad disconnects, input goes to zero and the creature coasts. A toast says the controller is disconnected. The game does not pause: it is a shared server. |

**Test checklist** (the gate for turning the Console switch on)

- [ ] From a cold start, with only a pad: join, first bite, a run to tier 4, a bank, open every dock menu, change a setting, leave.
- [ ] Every screen in document 08 section 2.1 can be opened, used and closed with directions, A and B. No focus trap, no unreachable element.
- [ ] Nothing but water and scrims in the outer 5%, checked on a TV with overscan switched on.
- [ ] From 3 m on a 40-inch TV: tier, mass, dash state and nearest threat arrow are read in a 0.5 s glance; menu text is read without leaning forward.
- [ ] The Roblox purchase prompt completes and cancels by pad; focus returns to the shop card.
- [ ] No chat window, no chat button of ours.
- [ ] Glyphs are Xbox glyphs everywhere, including the hint bar and the first-run controls hint.
- [ ] Ten-minute Frenzy run: 55 fps floor on a Series console; 28 on an Xbox One if one is available.
- [ ] Pull the pad's batteries mid-run and put them back; send the console to its home screen and return.
- [ ] On a 4K TV: record the viewport size Roblox reports and confirm the scale.

### 3.6 PlayStation [P1]

Everything in 3.5 applies. This section lists only what differs.

**Who plays here.** As Xbox. PlayStation 4 and 5, select countries (PF4).

**Layout.** The Couch HUD of 3.5 with PlayStation glyphs.

```
   |                           [st][st]                     (emote) (ABIL)  (DASH)    |
   |                    (safe) (tr1)(tr2)(tr3)               (Dv)   (Sq)    (X)       |
   |                           (D<) (D^) (D>)                                         |
   +----------------------------------------------------------------------------------+
 Menu hint bar, 56 rpx:   (X) Select    (O) Back    (L1)(R1) Tab    (Tri) Claim all
```

**Controls.** Same actions, PlayStation names.

| Action | PlayStation | Roblox key code |
|---|---|---|
| Swim; look around | Left stick; right stick | `Thumbstick1`; `Thumbstick2` |
| Dash | Cross or R2 | `ButtonA`, `ButtonR2` |
| Ability | Square or R1 | `ButtonX`, `ButtonR1` |
| Brake | L2 | `ButtonL2` |
| Shed trait 1, 2, 3 | D-pad left, up, right | `DPadLeft`, `DPadUp`, `DPadRight` |
| Emote wheel [L] | Hold D-pad down, right stick | `DPadDown` |
| Settings; focus the dock | Create button or touchpad press [U which] | `ButtonSelect` |
| Full list; tide schedule | L3; R3 | `ButtonL3`; `ButtonR3` |
| Confirm; back; extra | Cross; Circle; Triangle | `ButtonA`; `ButtonB`; `ButtonY` |
| Tabs; page | L1 and R1; L2 and R2 | `ButtonL1`, `ButtonR1` |
| Roblox menu | Options | `ButtonStart` |

Cross is always confirm and Circle is always back, in every region. Key code names are the engine's standard pad names, written from memory and not re-read this session [U].

| Point | Rule |
|---|---|
| Choosing glyphs | No platform API exists (PF20). The client asks `UserInputService:GetStringForKeyCode(Enum.KeyCode.ButtonA)`; if the answer names Cross it loads the `UI_Hint_PadCross` set, otherwise the Xbox set. The exact strings returned are [U]: log them in the first test. Fallback if the test fails: `GetImageForKeyCode()` (PF13), which returns Roblox's own icons in Roblox's style. |
| Glyphs on PC | The same test runs on PC, so a DualSense plugged into a computer also gets PlayStation glyphs. |
| Haptics | `HapticEffect` works on PlayStation pads (PF31). Adaptive triggers and the pad's light bar and speaker are not used; no documented API was found [U]. |
| Camera, graphics, performance, menus, rules | As 3.5. PlayStation 5: Balanced rising to Pretty, 60 fps target. PlayStation 4: Balanced, 30 fps target. |

**Test checklist**

- [ ] The whole Xbox checklist, on a PlayStation.
- [ ] Every glyph is a PlayStation shape; no A, B, X or Y letter appears anywhere, including text strings.
- [ ] The button that Roblox maps to `ButtonSelect` is found, written into this table, and shown correctly in the hint.
- [ ] The Roblox menu opens on Options and nothing of ours reacts to it.

### 3.7 Handheld gaming PC [L]

**Who plays here.** Owners of a ROG Xbox Ally or similar Windows handheld: a 7-inch screen at 1,920 × 1,080 or 1,280 × 800, built-in pad, touchscreen, held 30 to 40 cm away, on a sofa, in bed or travelling. Sessions assumed at 20 to 40 minutes, limited by battery (tune). It is a PC, so it arrives through the Computer switch [U].

**Layout** (1,920 × 1,080 px, scale 1.35, canvas 1,422 × 800 rpx). The Pad HUD with phone-like density: a small screen at arm's length needs bigger elements than a monitor.

```
+--------------------------------------------------------------------------------+
| [R]             (T4)[======== 86 ====  >114](T5)          (TIDE)(R3)   (View)  |
|                      ( o 387 x1.5 <fish> )                 0:45                |
| [#1 Mako 412] (L3)  [ moment slot ]                         [ toast         ]  |
|                                                                      (home)    |
|                          (the creature)                               120 m    |
|                            [st][st]                                            |
|                     (safe) (tr1)(tr2)(tr3)           (emote) (ABIL)  (DASH)    |
|                            (D<) (D^) (D>)             (Dv)    (X)     (A)      |
+--------------------------------------------------------------------------------+
```

| Compared with the phone | Change |
|---|---|
| Scale | deviceFactor 0.90 (tune): text floor 30 px at 1,080p, 22 px at 800p; about 2.4 mm tall on a 7-inch screen, against about 1.8 mm on a small phone |
| Buttons | Hint tiles with glyphs; no drag ring |
| `HUD.Biggest` | One row, as the phone; L3 for the full list |
| Margins | No TV margin. 16 rpx as usual. |
| Touch | Touching the screen switches to Touch mode and the phone HUD (section 5) |

**Controls.** The Pad column of 3.3. Xbox glyphs. Back paddles and system buttons are not bound. Assists as touch.

**Camera.** As Pad: automatic follow, right stick looks around, 70° on both 16:9 and 16:10 screens.

**What it looks like and performance.** Balanced at start; 60 fps target, 45 floor, 2,500 MB ceiling (tune). On battery these devices throttle, so the automatic step-down in section 6 is expected to fire; that is acceptable. High-refresh screens are allowed to run above 60 if Roblox lets them [U].

**Menus.** Focus navigation as 3.5, without TV margins. Touch works on every button as well.

**Platform rules.** As PC. Haptics through the built-in pad (PF31). Chat panel [L] shown; typing needs the system keyboard, which we do not depend on.

**Test checklist**

- [ ] Record what `ViewportDisplaySize`, `PreferredInput` and the viewport size report on the device; correct rule 2 of section 2.2.
- [ ] A full run and a bank on the built-in pad; every menu by focus; every menu by touch.
- [ ] Text read comfortably at 35 cm; nothing under 22 px.
- [ ] Ten-minute Frenzy run on battery: floor 45 fps, or a clean step down to Smooth.
- [ ] Without the device: a PC with a pad and the Roblox window at 1,280 × 800 with `interfaceSize` 1.3 is the stand-in.

### 3.8 VR (Meta Quest, PC VR): switched off

**Decision.** The VR switch stays off at every stage in this document. It is reviewed once, twelve months after public launch.

**Who would play here.** Quest 2, Pro and 3 owners (PF5), standing or seated, 10 to 30 minute sessions (assumption). Meta's own age rules for the headset were not confirmed on a Roblox page [U]; the canon's core audience starts at 9.

**Why it is off**

| Problem | Detail |
|---|---|
| Comfort | The creature turns at up to 360° a second, pitches to 70°, breaches and dashes with a field-of-view kick. A camera that follows all of that in a headset makes people ill. Roblox's comfort options (vignette, stepped rotation, fixed third-person camera) are built into its default camera, and "custom VR camera scripts" opt out of them (PF15). GULP's camera is fully scripted. |
| Interface | Every HUD and menu in document 08 is a screen overlay. How those render in a headset is not stated on the VR page [U]; they would need rebuilding as panels in the world. |
| Frame rate | Quest aims for 72 fps minimum (PF15), drawn twice, on phone-class hardware. Our low tier targets 30. |
| Testing | Headset testing in Studio is Windows only (PF30). This project is built on a Mac. |
| Fairness | A head-aimed player in a shared server is a new input type to balance (section 4). |

**What it would take** (about 5 to 7 weeks for one developer, plus a Quest 3 and a Windows PC) (tune)

| Area | Work |
|---|---|
| Camera | A fixed "aquarium" camera: the player's head is a still point 1.4 × the follow distance behind and above the creature; the world never rotates around the head. Turning the view is stepped (30° steps). No roll, no pitch from the creature (`VRTiltAndRollEnabled` off, PF35). No dash kick, no shake. |
| Layout | A curved panel 2 m ahead and below eye level carrying the mass bar, bank chip, traits, tide clock and home arrow; threat arrows become glowing markers in the world. Menus are a panel at 1.5 m. Text no smaller than 1° of view. |
| Controls | Left stick: swim (phone mapping). Right stick: stepped turn. Right trigger: dash. Right grip or A: ability. Left trigger: brake. X and Y: trait popover. Menu: Roblox. Laser pointer plus trigger in menus. |
| Graphics | A fourth tier below Smooth: 50 prey meshes, 4 animated rigs, 200 live particles, no bloom, 160-stud fog. Target 72 fps, floor 72. |
| Rules | VR players join the same servers; assist set as touch. Vignette on while moving, by default. |
| Checklist to pass before switching on | 20 minutes of play by five people with no nausea reported; 72 fps held in a Frenzy on a Quest 2; every screen usable with the pointer; no camera movement the player did not cause. |

## 4. Fairness across devices

### 4.1 Shared servers

Phone, tablet, PC, handheld and console players share the same 24-player servers. This is Roblox's default: the Device Type matchmaking signal has weight 0 (PF17). GULP does not change it at launch. Reasons: friends on different devices must be able to play together (Friends has the largest default weight, 15), and splitting a new game's players by device empties servers.

### 4.2 Where each input has an edge

| Factor | Who gains | How large |
|---|---|---|
| Turning speed | Nobody | Facing turns at the tier's turn rate for every input (document 02, section 1.4). A mouse cannot spin a creature faster than a thumb can. |
| Heading precision | Mouse | The mouse sets a heading directly. Touch drag, pad stick and arrow keys set a turn **rate**, so they overshoot and correct. This is the main real gap, and it shows when lining up a dash. |
| Strafe | Keys, two-thumb touch | A and D give sideways thrust at 0.6 × top speed. Drag-to-swim and the pad have none. It is a dodge the others lack. |
| Looking behind | Pad | The right stick looks around without steering. Touch drag and mouse cannot look away from where they swim. |
| Fingers | Keys, pad | Dash and ability sit under fingers that are not steering. On touch they need the second thumb, which is free in the drag scheme. Small gap. |
| Screen | PC, TV, tablet | Bigger picture, so small prey and distant threats are easier to see. Threat arrows and outlines are the same size in rpx everywhere to offset this. |
| Frame rate and delay | PC | 60 to 240 fps against 30 on a low phone; TVs add display delay. Rules are frame-rate independent (3.3), so this affects reaction time only. |
| View distance | Balanced, Pretty | Smooth caps fog at 220 studs. Outlines (120 studs) and threat arrows (90 studs) are well inside that, so the information that decides a fight is equal. |

### 4.3 Assist strength by input type

Assists help with **computer-controlled prey only**. No assist ever acts on another player at launch. All values (tune).

| Lever | Touch, drag | Touch, two-thumb [L] | Pad [L] | Keys |
|---|---|---|---|---|
| Gulp assist cone, half-angle (document 02, section 4.1) [MVP] | 35° | 30° | 35° | 22° |
| Gulp assist range, × mouth radius [MVP] | 2.5 | 2.25 | 2.5 | 2.0 |
| Gulp assist pull [MVP] | 12 studs/s | 10 | 12 | 6 |
| Steering nudge toward the nearest edible prey within 15° of the nose [L] | Up to 20% of the turn rate | None | Up to 20% | None |
| Dash snap toward edible prey inside the dash's reach [L] | Up to 12° | Up to 8° | Up to 12° | None |
| Dash snap toward an edible **player** | 0° | 0° | 0° | 0° |
| Strafe, × top speed | None | 0.6 | None | 0.6 |
| Held dash repeats | On | On | On | Off |

- The assist set follows the input mode at that moment (section 5). Keys with arrow steering uses the Keys set.
- The nudge and the snap are new in this chapter. They ship at [L] behind the live config flags `assist.nudge` and `assist.dashSnap` (document 09, section 17.4), so they can be turned off without publishing.
- **The server never trusts the stated input type.** It validates every bite against the widest set (the touch column). A client that lies about its input gains at most the touch assist against prey, which is the baseline most players already have. Input type is sent for analytics only.
- Never varied by device: speed, turn rate, mouth radius against players, cooldowns, mass gained, outline range, threat distances.

### 4.4 How to measure it

New analytics events. Each needs a line in document 10, section 4 before it is used. `touch`, `kbm` and `gamepad` are the values `sess_input` already uses.

| Event | Value | `ctx` values | Fired |
|---|---|---|---|
| `sess_device` | 1 | `<class>_<display>_<input>`: class `phone`, `tablet`, `desktop`, `handheld`, `tv`; display `s`, `m`, `l`; input as above (45) | Once, 10 s after control |
| `run_end_input` | Run length in seconds | `<input>_<outcome>`: outcome `bank`, `gulp_player`, `gulp_npc`, `quit` (12) | Every run end, with the input mode used for most of the run |
| `pvp_pair` | 1 | `<eaterInput>_<victimInput>` (9) | Every player-eats-player, on the server, with each side's mode at that moment |
| `perf_tier` | Average fps of the session | `<class>_<tier>`: tier `smooth`, `balanced`, `pretty`, `cut` (20) | Session end |
| `input_switch` | Switches in the session | `<from>_<to>` (6) | Session end, if any |

| Measure | How it is read | Acceptable (tune) |
|---|---|---|
| Bank rate by input | `<input>_bank` ÷ all `run_end_input` for that input | Each input within 5 percentage points of touch |
| Gulped-by-player rate by input | `<input>_gulp_player` per 10 run-minutes | Each input within 15% of touch |
| Pair balance | `kbm_touch` ÷ `touch_kbm` in `pvp_pair`, divided by the ratio of keys run-minutes to touch run-minutes | Between 0.8 and 1.25. The same for `gamepad` against `touch`. |
| Run length by input | Median `run_end_input` value | Reported, no target |

Read weekly, and only when each input has at least 2,000 run ends in the last 7 days. This is a standing balance check, not an experiment; the rule in document 10 against acting on subgroups of an A/B test does not apply to it.

**If keys or pad come out ahead, apply in this order, one per week:**

1. Keys gulp assist pull 6 → 0.
2. Keys strafe 0.6 → 0.45.
3. Dash snap toward edible players for touch and pad: 0° → 8°.
4. Custom matchmaking: Device Type weight 0 → 2 (PF17), so servers lean toward one device type. This costs fill time and separates friends less than a hard split would. Last resort.

**If touch comes out ahead:** nudge 20% → 10%, then dash snap 12° → 6°.

## 5. Dynamic behaviour

### 5.1 The input type changes mid-session

The input mode follows `UserInputService.PreferredInput` (PF18). If that property proves unreliable on a device [U], the fallback is `LastInputTypeChanged` with the same rules.

| What the player does | Result |
|---|---|
| Presses a pad button or moves a stick past its dead zone (PC, phone, tablet, Chromebook) | Mode becomes Pad. Touch buttons or key caps become glyphs, the cursor and reticle hide, the camera eases to automatic follow over 0.3 s. |
| Moves the mouse more than 8 px, or presses a key, while in Pad or Touch mode | Mode becomes Keys. Key caps show; the mouse locks if nothing is open. |
| Touches the screen (Chromebook, touch laptop, handheld, tablet with a keyboard) | Mode becomes Touch. The touch buttons appear at the current scale; the cursor hides. |
| Attaches a keyboard to a tablet | Nothing until a key is pressed; then Keys mode at tablet scale. Mouse aiming only if a pointer exists and locks; otherwise the arrow keys steer. |
| Unplugs the pad, or it loses power | Phone and tablet: Touch. PC: Keys. TV: input zero, the creature coasts, a toast appears; any pad that sends input takes over. |
| Plugs in a second pad | The pad that sent the most recent input drives. There is no split screen. |

| Rule | Value |
|---|---|
| Hint swap time | Within 200 ms (document 08, section 10.1) |
| Screen class | Does **not** change with the input mode. Only the viewport changes it. So plugging a pad into a PC changes hints and controls, not scale. |
| Held inputs | Inputs held in the old mode are released (throttle 0) unless the new mode supplies one in the same frame. Dash cooldown and the input buffer carry over. |
| Camera | Never snaps. Leaving mouse aim, the current look direction becomes the creature's heading target. |
| Assist set | Switches with the mode, at once. Only one set is ever active. |
| Flapping | Three switches inside 10 s (a Chromebook player steering with keys and tapping the dash button) puts the HUD in a mixed state for the rest of the run: touch buttons stay visible and key caps stay on. |
| Settings panel | Shows the rows for the current mode (look speed, scheme, vibration) and re-draws on a switch |
| First use of an input type | The 5-second controls hint of document 04 (`seen_controls[inputType]`) shows at the start of the **next** run, never mid-run |
| Saved per input type | Scheme, look speeds, flip up and down, swap sticks, left-handed, graphics choice, `lastGoodTier` |

### 5.2 The window or screen changes

| Event | Behaviour |
|---|---|
| Desktop or Chromebook window resized, full screen toggled | After 250 ms with no further change: recompute screen class and scale (section 2.2). Edge-pinned elements move with the edges; menus stay centred; a menu taller than the window scrolls. The field of view follows the new aspect in the same frame. |
| Smallest supported window | 1,024 × 576 px. Below it the width term keeps 1,280 rpx visible down to scale 0.40. Below 512 × 288 the HUD hides `HUD.Biggest` and the toast stack; nothing else is promised. |
| Phone turned from one landscape side to the other | Roblox rotates the picture (`LandscapeSensor`). On the change the client re-reads the safe insets and `TopbarInset`, and ends the current swim touch so a drag cannot stick. Listen to both the viewport size and the `PlayerGui` orientation property; the docs name the property two ways (PF21). |
| Phone held upright or laid flat | Nothing. The game stays in landscape. |
| Foldable opened or closed; tablet split view | A viewport change like any other. The class may move between Phone and Tablet; scale and field of view update at once. |
| Ultrawide (wider than 21:9) | The HUD frame is capped at 2.34 × its height and centred, so the dash hint and the leaderboard are never a head-turn apart. Water and scrims fill the full width. The horizontal field of view is capped at 117° (3.2). |
| Very small phone (short side under 340 px) | Scale floors at 0.40 to 0.45. Touch targets fall to about 6 mm. Playable, not comfortable; the supported minimum is 667 × 375. |
| 4K monitor or TV | Desktop scale 1.80 at 2,160 px tall; TV scale 2.40. The upper clamp is 2.60 (document 08 has 2.0, which would shrink a 4K TV's interface). |
| Interface size setting changed [L] | Applies at once; same recompute. |

## 6. Automatic quality scaling

**What the client can know:** the time between frames, its own memory total from the `Stats` service [U exact call], the screen class, and the player's saved Roblox quality level if they set one by hand (PF25). **What it cannot know:** the device model, its RAM, its temperature, or the quality level Roblox's Automatic mode is using (PF20, PF25).

**At start**

1. If the profile holds a `lastGoodTier` for this screen class, start there.
2. Otherwise: Phone starts on Smooth; every other class starts on Balanced.
3. If the player has set Roblox's quality by hand to 3 or lower, start on Smooth and never probe above Balanced.
4. When the loading screen ends, sample 3 s in the cove or Nursery (document 09, section 15.1). On Smooth with an average of 55 fps or more: go to Balanced. On any tier with an average more than 5 under target: step down one.

**During play (Graphics = Auto)**

| Trigger | Action |
|---|---|
| 10 s average more than 5 fps under the tier's target (under 55 on Balanced and Pretty, under 25 on Smooth) | Step down one tier. On Smooth: apply the next step of the cut order in 3.0. |
| Client memory above the tier's ceiling | Step down one tier at once. On Smooth: apply cut steps 1, 2 and 5 together. |
| 60 s at or within 1 fps of target, no step down in the last 5 minutes, no tide event running, no red-outlined creature within 120 studs | Probe: move up one tier for 10 s. If the average holds within 2 fps of target, keep it. If not, go back and treat the lower tier as this session's ceiling. At most 2 probes per session. |
| Session end | Save the tier that was active longest as `lastGoodTier`; send `perf_tier`. |

- A tier change is applied without a hitch: mesh pools shrink from the farthest member inward, fog distance eases over 1.5 s, shadows switch during the next zone blend.
- No step ever removes the items listed under "never cut" in 3.0.
- Every tier number lives in live config (document 09, section 17.4) so a bad value can be fixed without a publish.

**What the player can override**

| Setting (document 08, section 6.7) | Effect |
|---|---|
| Graphics: Auto | Everything above. Default. |
| Graphics: Smooth, Balanced or Pretty | Fixed. No stepping up or down. Two guards remain: memory above the ceiling forces one step down with a toast, and under 20 fps for 20 s on Smooth starts the cut order. |
| Less motion; camera shake | Independent of the tier |
| Roblox's own graphics slider and frame-rate cap | In the Roblox menu. We cannot read them reliably or set them (PF25, PF27). The settings panel says so in one line. |

## 7. Store presentation per platform

Document 11 owns the icon (section 3), thumbnails (section 4) and video (section 5). This section only adds what the device changes.

| Surface | What is known | Design for |
|---|---|---|
| Phone app | Icons are shown scaled down, for example to 150 × 150 px (document 11, F1); thumbnails appear on Home and at the top of the game page (F5). Exact tile sizes per screen are [U]. | The icon must read at 150 px and at half that: one creature and one threat, with no text (chapter 11, section 3 owns the icon; the main icon carries no wordmark). Check it on a real phone at arm's length, not on a monitor. |
| PC app and website | An approved video shows first on the game page and can appear on Home (F7). | The page cut of the video (document 11, section 5.1) is the main pitch here. |
| Xbox and PlayStation | Video thumbnails are **not** shown (PF34). How console Home lays out tiles is [U]. | The first image thumbnail carries the whole pitch, seen from 3 m: large shapes, at most three words, lettering at least 8% of the image height (tune). |
| Every surface | The player-count overlay can cover the bottom edge (F5). Roblox picks between active thumbnails per player group (F6); no per-device thumbnail setting was found [U]. | Every active thumbnail must work on every device. So: no thumb, no touch button, no key cap and no pad glyph in the icon or in thumbnails T1 to T3. A controls picture, if wanted, goes in T4 or later. |
| Game page text | Document 11, line "One thumb on a phone. Works on PC and tablet too." | Add "and with a controller" at [L]; add "and on console" on the day the Console switch goes on. |
| Paid ads | Ads Manager can target by device (F18); document 11, section 10.2 targets phone and computer. | Add console to targeting only after [P1], and only if console day-1 retention is within 5 points of phone. |
| Browser play | Share links may open the game in Chrome once released (PF8). | The first minute must be playable with a keyboard alone (arrow keys, 3.3) on a machine that has never installed Roblox. |

## 8. Device test matrix

**How testing works from this Mac**

| Tool | What it proves | What it cannot prove |
|---|---|---|
| Studio Device Simulator (PF30) | Layout, safe areas, scale, touch input and pixel density for phone and tablet presets | Speed, memory, heat. The emulator "isn't accurate for memory usage" (PF28). |
| A dev-only override `Dev/ForceScreenClass` (Studio and the staging place only) | TV margins, handheld scale and every screen class on the Mac's own screen | What the real device reports to the detection rules |
| Studio Controller Emulator, and a real Xbox pad and a real DualSense paired to the Mac | The Pad scheme, focus navigation on every screen, both glyph sets, input switching | Console system behaviour, TV overscan, the purchase prompt on console |
| The Mac's Roblox client on the staging place | Desk presentation, window resizing, ultrawide shapes (resize the window to 21:9 and 32:9), frame-rate independence at 60 | The Windows frame-rate cap setting, Windows-only bugs |
| Studio multi-client (up to 8, PF30; 2 on this 16 GB Mac, document 09, section 2.5) and network simulation | Mixed-input fights, `pvp_pair`, reconnects | Real cross-device latency |
| A real phone or tablet joined to the staging place | Everything for that device | Other devices |

**Needs hardware, with no substitute:** speed and memory on every class; anything on Xbox or PlayStation; the Chromebook and handheld facts in PF36; Windows-specific behaviour; VR on a headset (Windows only, PF30).

| # | Class | Representative device | Tag | Tested how | Pass criteria |
|---|---|---|---|---|---|
| 1 | Low phone, Android | 4 GB, 2021 to 2023 mid-range chip (Galaxy A13 or A14 class; the reference phone of document 04) | [MVP] | Real device, every week (document 09, section 15.5) | 3.1 checklist. 10-minute Frenzy: 10 s average never under 25 fps, under 900 MB, no crash. First bite within 10 s of load. |
| 2 | Low phone, iOS, smallest screen | iPhone SE (2nd generation) class, 667 × 375 | [MVP] | Real device, before each release | 3.1 checklist; every target at least 46 px; nothing under the home bar |
| 3 | Mid phone | 6 to 8 GB, 2022 or later (Galaxy A5x or iPhone 12 class) | [MVP] | Real device or a tester's, before each release | Holds Balanced at 50 fps floor, under 1,300 MB |
| 4 | Flagship phone, notch, long screen | 932 × 430 class (recent iPhone Pro Max or Galaxy S) | [MVP] | Simulator for layout; real device once per milestone | Layout correct with the notch on either side; reaches Pretty or holds Balanced at 55 fps |
| 5 | Small tablet, 4:3 | iPad (9th or 10th generation) class, or an 8 to 10 inch Android tablet | [MVP] | Simulator for layout; real device once per milestone | 3.2 checklist; 95° across; 50 fps floor |
| 6 | Low-end laptop | Windows, integrated graphics, 8 GB, 1,366 × 768, trackpad only | [MVP] | Borrowed machine, once per milestone | 3.3 checklist with keyboard only; settles on a tier that holds its floor |
| 7 | Mac | The development Mac | [MVP] | Daily | 3.3 checklist |
| 8 | Gaming PC | Windows, separate graphics card, 144 Hz monitor | [L] | Borrowed or a tester's, once before launch | Reaches Pretty; 60 fps floor; frame-rate independence at 30, 60 and 240 |
| 9 | Chromebook | 4 GB, 11.6 inch, touchscreen | [L] | Borrowed, once before launch | 3.4 checklist; PF36 values recorded |
| 10 | Handheld PC | ROG Xbox Ally, or the stand-in in 3.7 | [L] | Stand-in on the Mac; a real device if one can be borrowed | 3.7 checklist |
| 11 | Xbox | Series S (the weakest current model); Xbox One if available | [P1] | Real console on a TV. Gate for the Console switch. | 3.5 checklist, every line |
| 12 | PlayStation | PlayStation 5; PlayStation 4 if available | [P1] | Real console on a TV. Gate for the Console switch. | 3.6 checklist, every line |

Rows 1, 2 and 7 are the minimum set the owner must have in hand. Every other row can be covered by one borrowed session per milestone. Results go into `docs/perf-log.md` with the device row number (document 09, section 15.5).

## 9. Build order

| Stage | Platforms that work | What is built for platforms at this stage |
|---|---|---|
| **First playable** (before [MVP]; the first-week spike S9 of document 09) | The Mac in Studio with keys; touch through the Device Simulator; one real phone by the end of the stage | Drag to swim and the Keys scheme feeding one `SwimInput`; the scripted camera; the scale formula with the width term; landscape lock; Smooth and Balanced as fixed constants, chosen by hand |
| **Soft launch** [MVP] | Phone, tablet, computer with keys (arrow keys included). Chromebook works untested beyond a smoke test. A pad may move the creature but is not supported. | Playable Devices: Phone, Tablet, Computer on; Console and VR off. Screen class and input mode detection; hint swap; per-input settings; the three tiers; start sample, step down, cut order and memory guard; the 3.0 never-cut list; gulp assist per input; `sess_device`, `run_end_input`, `perf_tier`; test rows 1 to 7 |
| **Public launch** [L] | Adds: pad on PC, Mac, phone and tablet; handheld PC; Chromebook checked. The Couch presentation is complete and tested on a PC, but the Console switch is still off. | Pad scheme; focus navigation on every screen; Xbox and PlayStation glyph sets; TV margins and scale; two-thumb scheme; emote wheel on all three inputs; interface size, bigger text, swap sticks; step-up probe and `lastGoodTier`; steering nudge and dash snap behind flags; `pvp_pair`, `input_switch` and the weekly fairness read; haptic mapping; a chat panel only if the launch review turns text chat on (it is off in the MVP, canon 14; never on TV); test rows 8 to 10 |
| **After launch** [P1] (the first quarter after launch, weeks 1 to 12) | Adds: Xbox and PlayStation early in [P1], in weeks 2 to 4, on the day rows 11 and 12 pass. Browser play when Roblox releases it. | Console switch on; game page text and ad targeting updated (section 7); desktop key rebinding; the first fairness levers if section 4.4 calls for them |
| **Later** [P2] | No new platform planned | VR review at twelve months (3.8; scheduled in the Q4 row of 13 §7.2); standalone apps at the document 12 Q3 decision point; anything Roblox adds inherits the nearest presentation |

## 10. Decisions made here; the changes have been applied in other chapters

These changes were applied to the chapters named during reconciliation. The final consistency pass of 13 October 2026 checked every row by search: each is applied unless its last column says **Not applied**. This chapter remains the tie-break for platform questions.

| # | Decision made here | Chapter and section | What was changed (applied unless marked) |
|---|---|---|---|
| 1 | Pad scheme and TV layout are [L]; the Console switch is [P1], weeks 2 to 4, gated on real hardware. Documents 08 and 12 disagreed. | 08 §10.4; 12 G8 and §10 Q1; 01 §1 | 08: retitle "Gamepad [L]; console listing [P1]". 12: add "weeks 2 to 4, gate = 15 §3.5 and §3.6". 01: the Platform line could read "phone, tablet and PC first; controller at launch; console in the first month; VR off". |
| 2 | Screen class by `ViewportDisplaySize` first (the docs say not to use `IsTenFootInterface` to detect consoles), a Handheld class, a width term in the scale formula, clamp 0.40 to 2.60, class recomputed on viewport change. | 08 §1.2, §10.1 | Replace the detection column and formula; change "chosen once at join". |
| 3 | PC keys merged: Space or left mouse dashes, E or right mouse uses the ability, R is auto-swim (from 02); P settings, C tide, Backspace close, Esc is Roblox's (from 08). | 02 §2.3; 08 §10.2 | 02: change the Esc row, add P, C, Backspace. 08: add the mouse buttons and R. |
| 4 | Direct emote keys F1 to F6 are dropped (Mac laptops and Chromebooks do not send them). The wheel takes 1 to 6 while T is held. | 02 §2.3, §17.1; 08 §3.17, §10.2 | Replace F1 to F6. |
| 5 | Pad map merged: traits on D-pad left, up, right and emote on hold D-pad down with the right stick (from 08); RT also dashes, LT brakes (from 02); new: RB also uses the ability, LB reserved. | 02 §2.4, §17.1; 08 §10.4; 01 §5.6 | 02: drop "LB / RB select trait slot; hold Y" and "D-pad up, left stick". 08: add RT, LT, RB. |
| 6 | Arrow keys steer in Keys mode [MVP]. | 02 §2.3; 08 §10.2, §13.12; 07; 04 | Add the rows; add hint image `UI_Hint_KeyArrows`; teach it in the desktop first-run hint. Applied in 02, 04 and 08 (the hint is in 08 §10.2; 04 §3.2 shows the arrow keys alongside W in the PC ghost prompt, and 04 §9 in the controls hint). Chapter 07 lists no interface images, so nothing was needed there. |
| 7 | Look speed is one setting per input type with its own range (drag 0.5 to 1.5, mouse 0.2 to 3.0, pad 0.5 to 2.0). Device-shaped settings are saved per input type. | 08 §6.7; 09 §12.2 | 08: split the "Look speed, All" row. 09: add a per-input settings table and `lastGoodTier` to the save schema. |
| 8 | New settings [L]: Interface size (0.8 to 1.3) and Swap sticks. | 08 §6.7, §14.12 | Add rows and text keys. |
| 9 | Budgets: 06 and 09 give different numbers (triangles in view 200,000 / 350,000 / 800,000 against 150,000 / 300,000 / 600,000; PC draw calls 900 against 700). The 3.0 table uses 09's. | 06 §14.1, §14.2 | Adopt the 3.0 numbers; recompute the busy frame with 80 prey meshes. |
| 10 | "Prey drawn 250 / 400 / 800" (06) and "prey meshes 80 / 150 / 250" (09), and "skinned 30 / 50 / 120" (06) and "animated rigs 8 / 16 / 24" (09), are kept as two separate rows each: total visible, and full meshes or full animation. Tier names Smooth, Balanced, Pretty equal Low, Mid, High. | 06 §11.4, §14.1; 09 §15.1, §8.8 | Use both rows and the three tier names; 06 §11.4 gains a middle column. |
| 11 | The cut "StreamingTargetRadius 512 → 384" cannot be per device: 09's own V4 and V29 say streaming properties are not scriptable. Replaced by a fog cap. | 09 §15.6 step 6 | Replace the step. |
| 12 | Zone view distance is capped at 220 studs on Smooth and 350 on Balanced, because the engine draws only about 200 studs on weak Android phones today (PF29). | 06 §10.2 | Add the two caps; re-check the Nursery and Reef looks at 220. |
| 13 | 06 lists `Technology = ShadowMap` ("middle cost") beside `LightingStyle = Realistic` with `PrioritizeLightingQuality = true`. By Roblox's mapping (PF26) that pair is the old Future, the most expensive; ShadowMap equals Soft, which 06 rejects. | 06 §2.4, §10.1, §18.2 | Remove the ShadowMap row; make "Realistic holds 30 fps on test row 1" a gate in the lighting spike, with Soft + prioritise on as the fallback. Sprint 0 added: `Technology` stays unset and unread; the two properties are set in the project file or build step (PF26). |
| 14 | Horizontal field of view held between 95° and 117° by adjusting the vertical one (cap 90°). | 02 §3.1 | Add the rule and the table from 3.2. |
| 15 | Gulp assist strength varies by input type; steering nudge and dash snap are new [L] assists for touch and pad; the server validates against the widest set. | 02 §4.1, §2.5; 09 §8.9 | 02: add the 4.3 table; note the snap as the one exception to "dash goes along current facing". 09: widen bite validation to the touch set. |
| 16 | Quality scaling adds a step-up probe, a memory guard, `lastGoodTier` and a manual override with two guards. | 09 §15.1, §5.2 | Extend the `UIController` rule or add a `QualityController`. |
| 17 | Five new analytics events with fixed `ctx` lists (92 values). | 10 §2.4, §4 | Add the dictionary lines; check the 300-value and 100-event limits. |
| 18 | Chat: 08 leaves the Roblox chat window on and reserves a top-bar keep-out for its button; 09 and 12 turn it off at [MVP] with a panel at [L]. This chapter follows 09 and 12, and never shows chat on a TV (PF13). | 08 §1.3, §17 E1 and E8 | Align with 09 and 12; add the TV rule. |
| 19 | Haptics use `HapticEffect` types; the millisecond patterns are targets. Known gaps: pads on macOS 15+, pads paired to phones. | 08 §11.4, §17 E13 | Add the type mapping from 3.1; mark E13 verified. |
| 20 | Orientation is set in Studio and again on `PlayerGui` by the client. | 08 §1.2; 09 §15.4 | Add `StarterGui.ScreenOrientation = LandscapeSensor` to the place settings table. |
| 21 | Store: no control pictures in the icon or thumbnails T1 to T3; console gets no video; page text and ad targeting change at [L] and [P1]. | 11 §3.4, §4.1, §6.1, §10.2 | Add the rules and the two text updates. |
| 22 | Low phone is defined as test row 1 (4 GB, the document 04 reference phone) as well as 2 to 3 GB phones. | 09 §15.1; 04 (reference phone definition) | Use the same definition. |
| 23 | PlayStation needs a glyph for the button mapped to `ButtonSelect`, and mouse-button glyphs for dash and ability. | 07; 08 §13.12 | Add the images if they are not listed. Applied in 08 §13.12, which owns interface images; chapter 07 lists none. |
| 24 | Browser play gets a one-week check when Roblox releases it. | 12 §10 | Add to the Q1 or Q2 row. |

**Noticed while reading, now resolved:** emote visibility is 120 studs in chapters 02, 03 and 08, and a late dash press is remembered for 250 ms in chapters 02 and 08 (chapter 02 owns both).

## Sources

Official pages read on 13 October 2026: [Console guidelines](https://create.roblox.com/docs/production/publishing/console-guidelines) · [VR guidelines](https://create.roblox.com/docs/production/publishing/vr-guidelines) · [Cross-platform development](https://create.roblox.com/docs/projects/cross-platform) · [Server scoring](https://create.roblox.com/docs/matchmaking/scoring) · [Attributes and signals](https://create.roblox.com/docs/matchmaking/attributes-and-signals) · [Experience settings](https://create.roblox.com/docs/studio/experience-settings) · [Testing modes](https://create.roblox.com/docs/studio/testing-modes) · [Mobile input](https://create.roblox.com/docs/input/mobile) · [Gamepad input](https://create.roblox.com/docs/input/gamepad) · [Input Action System](https://create.roblox.com/docs/input/input-action-system) · [UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService) · [GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService) · [ScreenGui](https://create.roblox.com/docs/reference/engine/classes/ScreenGui) · [StarterGui](https://create.roblox.com/docs/reference/engine/classes/StarterGui) · [Camera](https://create.roblox.com/docs/reference/engine/classes/Camera) · [Platform enum](https://create.roblox.com/docs/reference/engine/enums/Platform) · [SavedQualitySetting](https://create.roblox.com/docs/reference/engine/enums/SavedQualitySetting) · [Improve performance](https://create.roblox.com/docs/performance-optimization/improve) · [Design for performance](https://create.roblox.com/docs/performance-optimization/design) · [Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails) · [Voice chat](https://create.roblox.com/docs/chat/voice-chat) · [Experience notifications](https://create.roblox.com/docs/production/promotion/experience-notifications)

Roblox staff posts and newsroom: [RDC26: What We Announced](https://devforum.roblox.com/t/rdc26-what-we-announced/4865880) · [Roblox on Xbox Ally and Galaxy Store](https://about.roblox.com/newsroom/2025/10/roblox-everywhere-bringing-roblox-two-new-platforms) · [Unified lighting](https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512) · [Maximum Framerate setting](https://devforum.roblox.com/t/introducing-the-maximum-framerate-setting/2995965) · [Haptic effects release](https://devforum.roblox.com/t/full-release-you-can-now-publish-haptic-effects-in-your-experience/3660577)

Help-centre pages that refused the fetch (facts marked S come from search snippets of these): Mobile system requirements, Computer requirements, Xbox One app, PlayStation FAQ, Meta Quest FAQ.
