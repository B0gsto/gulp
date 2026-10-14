# 02 · Mechanics

This chapter owns the rules and systems of GULP: how every creature, hazard, ability and meta system behaves. It expands document 01 (the canon) and never overrides it.

What this chapter does not own, and where to look:

| Topic | Owner |
|---|---|
| Per-entity stats (prey mass and radius, species multipliers), zone layouts, spawn region placement, cove dimensions | Document 03 |
| The scripted first two minutes | Document 04 |
| Prices, reward amounts, rank thresholds, economy balance | Document 05 |
| Screens, HUD layout, button positions | Document 08 |
| Per-platform control maps, layouts and assist strength by input type | Document 15 |
| Code architecture, replication, save format, anti-cheat plumbing | Document 09 |

**Number policy.** Values copied from the canon are exact. Every other number in this chapter is a first guess and is **(tune)** even where the mark is not repeated; table headers carry the mark where a whole column is a guess. Nothing here is left undefined.

---

## 0. Shared definitions

These terms are used by every later section.

### 0.1 Units and clocks

- Distances in studs, time in seconds, angles in degrees, speed in studs/s.
- The water surface is the plane `Y = 0`. Depth is `−Y`.
- **Server tick:** 20 Hz (50 ms). All rule checks run on the server tick unless stated.
- **Server time:** UTC seconds from the Roblox server clock. Clients never supply time for any rule.
- **Day boundary:** 00:00 UTC for every daily system (goals, Bubbles, streak, rewarded-video caps). **Week boundary:** Monday 00:00 UTC.
- **Active players `n`:** players on the server who are not flagged AFK (section 16.3).

### 0.2 Body dimensions

Derived from the canon body scale. `species.*Mult` values live in document 03. The six launch species stay within 0.75 to 1.25; post-launch species may go as far as 0.70 to 1.30 (document 03, section 1.4: Anglerfish mouth 1.30, Seahorse mouth 0.70 and turn 1.30). `dashMult` is separate (section 1.2).

**Body scale follows mass, not tier** (canon 5.1). The table gives the scale at each tier's threshold mass. Between two thresholds the scale is a straight-line blend by mass, so every bite makes the creature slightly bigger:

```
t         = current tier;  need[t] = its "mass needed";  scaleAt[t] = its canon body scale
bodyScale = scaleAt[t] + (scaleAt[t+1] − scaleAt[t]) × (mass − need[t]) / (need[t+1] − need[t])    tiers 1 to 6
bodyScale = 6.5                                                                                    tier 7, whatever the mass
```

Example: a Fry at mass 8 has scale `1.0 + 0.3 × 8 / 10 = 1.24`. Body length, collision radius and mouth radius are multiples of `bodyScale`, so they grow with it on the server and on every client. Only swim speed and turn rate change in a step at a tier-up.

| Tier | Body scale at the threshold | Body length (3.0 × scale) | Collision radius (0.9 × scale) | Mouth radius (1.2 × scale) |
|---|---|---|---|---|
| 1 | 1.0 | 3.0 | 0.90 | 1.20 |
| 2 | 1.3 | 3.9 | 1.17 | 1.56 |
| 3 | 1.7 | 5.1 | 1.53 | 2.04 |
| 4 | 2.3 | 6.9 | 2.07 | 2.76 |
| 5 | 3.2 | 9.6 | 2.88 | 3.84 |
| 6 | 4.5 | 13.5 | 4.05 | 5.40 |
| 7 | 6.5 | 19.5 | 5.85 | 7.80 |

- **Centre:** the root part position. Every "inside a volume" test uses the centre point only.
- **Collision body:** one sphere at the centre, radius `0.9 × bodyScale × species.radiusMult` (the Collision radius column of document 03, section 1.1).
- **Nose:** `centre + facing × (length × species.lengthMult / 2)`.

### 0.3 Tier is derived from mass

`tier = highest tier whose "mass needed" ≤ current mass`. Mass can fall (hook, vent, revive), so tier can fall too. The Codex records the peak tier of a run; a specimen records the tier at the moment of banking. Mass has no upper limit; tier stops at 7.

### 0.4 The eat rule

One function decides every bite in the game.

```
canEat(eater, target):
    if target is prey or trait prey:
        return target.tier <= eater.tier
    # target is a player, a wild creature or a predator
    if target.inSafeVolume or target.protected or target.tucked:
        return false
    # wild creatures (section 9.7) count as players on both sides of this test
    if eater.isPlayer and target.isPlayer and target.tier == 1:
        return false
    defenceTier = target.tier + (1 if target.puffed else 0)
    gap         = 2 if target.hasTrait("spiny") else 1
    return eater.tier >= defenceTier + gap
```

- Predators call the same function with their own tier. The Gull uses tier 3 (it eats tiers 1 and 2). Old Scar uses tier 7.
- Players can eat a predator under the same rule (one full tier higher). Eating a Barracuda gives 25 mass and eating a Grouper gives 60 mass, the same as prey of their tier (canon 5.2). Exceptions: the Gull, Old Scar and a Moray are never edible.
- Plated is applied after `canEat` returns true (section 8.4).
- A new player's first-run shield is a protection window (`target.protected`, section 6.3), so nothing can eat a new player before the first bank. The newcomer bubble (the first bite an account ever takes from another player is absorbed once) is applied after `canEat` returns true and before Plated. Chapter 04 owns the detail of both.

### 0.5 Safe volumes

| Volume | Who is safe inside | Who may enter |
|---|---|---|
| `NurserySafe` | Everyone, from players and predators | Tier 1 and 2 only (section 6.5) |
| `CoveSafe` (one per cove) | Everyone | Owner always. Others: section 13.4 |

No bite of any kind on a player happens while the victim's centre is inside a safe volume. Eating prey inside a safe volume is allowed.

### 0.6 Player states

Exactly one base state at a time, plus any number of overlays.

| Base state | Meaning | Can steer | Can bite | Can be eaten |
|---|---|---|---|---|
| `InCove` | In own cove, no run in progress | Yes | Prey only | No |
| `Swimming` | In a run, in water | Yes | Yes | Yes |
| `Airborne` | Above the surface after a breach | Reduced | Yes | Yes |
| `Stunned` | Jelly sting | No | No | Yes |
| `Hooked` | Being yanked by a hook | No | No | No |
| `Transit` | Inside an eel hole | No | No | No |
| `Banking` | Bank sequence playing | No | No | No |
| `Gulped` | Eaten; gulp card and revive offer | No | No | No |
| `Visiting` | Inside another player's cove **[L]** | Yes | No | No |

Overlays: `Dashing`, `Puffed`, `Tucked`, `Jetting`, `Rampaging`, `Slowed`, `Camo`, `Protected(kind)`, `TierUp`, `Bumped`, `Swallowing`, `InCurrent`.

### 0.7 Run lifecycle

1. A run **starts** when the centre leaves the owner's `CoveSafe` (`InCove` → `Swimming`). The run timer starts.
2. A run is **armed for banking** once mass ≥ 1.
3. Re-entering the own cove with mass < 1 cancels the run silently (back to `InCove`; not counted in any statistic).
4. A run **ends** by banking (section 11), by being gulped without a revive (section 12), or by a suspended run expiring (section 16.5).

---

## 1. Movement model [MVP]

No Humanoid. The root part is simulated on the owning client and checked by the server (section 1.9).

### 1.1 Inputs to the model

Every control scheme (section 2) reduces to four values each frame:

| Value | Range | Meaning |
|---|---|---|
| `throttle` | 0 to 1 | Forward thrust |
| `strafe` | −1 to 1 | Sideways thrust (PC and two-thumb only) |
| `yawTarget` or `yawRate` | — | Desired heading, or a turn rate |
| `pitchTarget` | −70° to +70° | Desired pitch |

### 1.2 Speed

```
topSpeed = tierSpeed × species.speedMult
           × 1.08 (Stripes) × 1.25 (Rampaging) × 0.40 (Puffed)
           × 0.50 (Slowed)  × 0.60 (Swallowing)
dashSpeed = topSpeed × species.dashMult     (2.2 by canon; Sea Turtle 2.0, Squid 2.6: document 03, section 1.1)
```

Multipliers apply only when their condition is active and they multiply together. A current adds `0.6 × tierSpeed` along the stream after everything else (section 10.6).

### 1.3 Thrust, drag and coasting

Velocity is split into a forward part (along facing) and a lateral part (everything else).

```
targetForward = topSpeed × throttle         (dashSpeed while Dashing)
forward += (targetForward − forward) × (1 − e^(−k × dt))
           k = accel when throttle > 0, coast when throttle = 0, brake when braking
lateral += (strafeTarget − lateral) × (1 − e^(−grip × dt))
           strafeTarget = topSpeed × 0.6 × strafe
if speed < 0.5 and throttle = 0: speed = 0
```

| Tier | accel (1/s) | coast (1/s) | brake (1/s) | grip (1/s) | Time to 90% speed (s) | Coast distance from top speed (studs) |
|---|---|---|---|---|---|---|
| 1 | 9.0 | 2.6 | 7.8 | 12 | 0.26 | 10.0 |
| 2 | 8.5 | 2.5 | 7.5 | 11 | 0.27 | 11.2 |
| 3 | 8.0 | 2.4 | 7.2 | 10 | 0.29 | 12.5 |
| 4 | 7.0 | 2.2 | 6.6 | 9 | 0.33 | 14.5 |
| 5 | 6.0 | 2.0 | 6.0 | 8 | 0.38 | 17.0 |
| 6 | 5.0 | 1.8 | 5.4 | 7 | 0.46 | 20.0 |
| 7 | 4.0 | 1.6 | 4.8 | 6 | 0.58 | 23.8 |

All values (tune), multiplied by `species.accelMult` (document 03, section 1.1, Acceleration column; 1.0 for every launch species, the default for any species that does not set it). Low grip at high tiers makes big creatures slide wide in turns. There is no reverse thrust; braking only stops.

### 1.4 Turning and pitch

- Facing rotates toward the target at `turnRate = tierTurnRate × species.turnMult` (canon table), for yaw and pitch alike.
- Angular speed is `clamp(error × 10, ±turnRate)`, so turns ease out over the last few degrees.
- Turning works at zero speed (a creature can turn on the spot).
- Turn rate is ×0.5 while `Dashing`, ×0.3 while `Airborne` or `Jetting`, 0 while `Stunned`, `Tucked` or `Hooked`.
- **Pitch limit:** ±70° on every control scheme. A creature can never point straight up or down.
- **Roll** is cosmetic: the body banks up to 25° in proportion to yaw rate. It has no effect on physics.

### 1.5 Buoyancy

None. Under water there is no gravity and no lift. A creature with no input stops and holds its depth.

### 1.6 Terrain collision

- The collision sphere slides along terrain: the velocity component into the surface is removed, the rest is kept. No bounce, no damage, no stun. Friction 0, elasticity 0.
- **Stuck recovery:** if throttle > 0.5 and speed < 1 for 1.5 s while touching terrain, push the creature along the average contact normal at 20 studs/s. If still stuck after 3 s, move it to the newest point on its position trail (one sample every 0.5 s, kept for 10 s) where the sphere fits.
- **World edge:** inside 24 studs of the map boundary an inward push of 30 studs/s applies. The boundary itself is an invisible wall.
- **Eel holes** are solid to every species except the Eel (section 7.4).

### 1.7 Surface and breaching

| Item | Rule |
|---|---|
| Surface skim | If the centre reaches `Y = −0.5 × collision radius` with upward speed < 8, upward velocity is zeroed. The creature rides with its back out of the water. |
| Breach | If the centre crosses `Y = 0` with upward speed ≥ 8, state becomes `Airborne`. |
| In the air | No thrust. Gravity 80 studs/s² (tune). No drag. Turn rate ×0.3. Minimum 0.2 s. |
| Re-entry | When the centre is below `Y = 0` again: state `Swimming`, velocity ×0.8, `FX_Splash` scaled by body scale, splash sound heard within 150 studs. |
| Blocked in the air | Starting a dash, starting Jet. A dash that began under water carries into the air as plain momentum. Puff and Shell can start in the air. |
| Biting in the air | Normal rules. |

Jump height is `vy² / 160`. Reference values at 70° pitch:

| Tier | Swim breach height / air time | Dash breach height / air time |
|---|---|---|
| 1 | 3.7 studs / 0.61 s | 18.1 studs / 1.34 s |
| 4 | 5.7 studs / 0.75 s | 27.4 studs / 1.65 s |
| 7 | 8.0 studs / 0.89 s | 38.6 studs / 1.96 s |

A creature is **at the surface** (for Gulls) when it is `Airborne` or its depth is under 6 studs.

### 1.8 Scale change as mass changes

- **Every bite:** the server recomputes `bodyScale` from mass (section 0.2) and uses the new collision radius and mouth radius at once. The client eases the mesh scale and the collision sphere radius to the new value over 0.15 s. Size never jumps at a tier-up.
- **Tier-up:** the server uses the new tier's speed and turn rate from the instant of tier-up (T+0.00, section 5). The client plays a **scale pop** on the mesh only: a 0.6 s back-out pulse that overshoots to 112% of the current scale and settles back on it. The pop is a flourish, not the size change, and does not touch the collision sphere.
- **Large jumps** (eating a player, a revive at 70% mass, a hook): growth eases linearly over 0.6 s, shrinking over 0.4 s, with no overshoot.
- If the larger sphere overlaps terrain, push out along the contact normal at up to 20 studs/s. If no free space exists (for example a tunnel narrower than the new diameter), move the creature to the newest fitting point on its 10 s position trail.
- **Tier-down:** speed and turn rate switch at once. There is no pop.
- **Leviathan crest** (canon 5.1): a creature that reaches tier 7 grows a crest, so the top tier is recognisable by silhouette. The crest grows in during the tier-up scale pop and pops off as bubbles on a tier-down to 6. It is part of the mesh only: it does not change the collision sphere, the mouth zone or any rule. Chapter 06, section 3.6 defines the crest shape for each body family and species; chapter 07 lists the crest meshes (`M_Species_<Name>_Crest`).

### 1.9 Server movement check

Every 0.5 s the server compares distance travelled against the legal maximum:

```
maxLegal = tierSpeed × species.speedMult × 1.08 (if Stripes) × 1.25 (if Rampaging)
           × species.dashMult (if a dash overlapped the window) or × 3.0 (if a Jet did)
         + 0.6 × tierSpeed (if a current was touched)
         + external (bump 30, Grouper 22, shoo 30, hook 50, eel transit 60)
allowed  = maxLegal × 0.5 × 1.15 + 3 studs
```

Over the limit: the server sends the client back to the last accepted position. Three violations in 10 s flag the run (section 15.5).

---

## 2. Controls

All schemes feed the model in section 1.1. Screen measurements are in rpx, document 08's unit (its section 1.2: a pixel of the 1280 × 720 reference canvas, scaled with the interface). The drag numbers were first written in offset pixels and are kept 1:1 as rpx **(tune)**: on a phone at scale 0.52 they are about half their earlier device-pixel size, so they are tuned on device row 1 (task S2-D1). Button placement belongs to document 08.

### 2.1 Phone: drag to swim [MVP] (default)

| Parameter | Value |
|---|---|
| Swim touch | The first touch that does not start on a button. Later non-button touches are ignored until it lifts. |
| Origin | The touch-down point (floating origin, anywhere on screen) |
| Dead zone | 14 rpx radius (document 08's unit, its section 1.2). Inside it: throttle 0, no turn. |
| Full deflection | 80 rpx from origin **(tune)**; the 168 rpx `HUD.DragRing` (radius 84) frames it |
| Clamp | 100 rpx **(tune)**. Past this the origin trails the finger so reversing direction is instant. |
| Sensitivity setting | 0.5 to 1.5, divides the 80 rpx full-deflection distance. Default 1.0. |

Mapping, with `d` the drag vector and `m = clamp((|d| − 14) / (80 − 14), 0, 1)`:

```
x = (d.x / |d|) × m          screen right is positive
y = (−d.y / |d|) × m         screen up is positive
curve(v) = sign(v) × |v|^1.4
throttle    = m
yawRate     = turnRate × curve(x)        (rate control: hold left to keep turning left)
pitchTarget = 70° × curve(y)             (position control: hold up to climb, centre to level)
```

- **Auto-level:** because pitch is position-controlled, any drag with `|y| < 0.15` levels the creature. With no touch, pitch returns to 0° at 90°/s after a 0.4 s delay.
- **Release:** throttle 0, yaw rate 0. The creature coasts to a stop (section 1.3).
- The camera turns with the creature (section 3), so "screen left" always means "turn left".
- **Dash button:** press to dash. Holding it re-fires the dash each time the cooldown ends ("held dash", on by default, setting to turn off).
- **Ability button:** press to activate. Hidden for species with a passive ability (Minnow, Eel, Shark Pup show a passive icon instead).
- **Trait slots:** tap a filled slot, then hold 0.6 s on the confirm ring to shed (section 8.3).

### 2.2 Phone: two-thumb scheme [L] (optional, in settings)

| Zone | Control |
|---|---|
| Left 40% of the screen | Floating stick, dead zone 14 rpx, full at 70 rpx **(tune)**. Up = throttle. Down = brake. Left/right = strafe. |
| Right 60% (not on a button) | Look drag: 0.35° per rpx × sensitivity **(tune)**, yaw and pitch. The creature turns to face where the camera looks. |

No auto-level in this scheme. Buttons are the same as 2.1.

### 2.3 Keys: PC, Mac, Chromebook and keyboard cases [MVP]

Chapter 15, section 3.3 holds the single key and pad map for every device, including the menu keys (P settings, C tide schedule, hold Tab for the full "biggest" list, Backspace to close). This section keeps only how the in-run inputs feed the model.

The cursor is locked to screen centre while the base state is `Swimming` or `Airborne` and no panel is open. Opening any panel, or holding Left Alt (Option on a Mac), frees it. Esc belongs to Roblox: it opens the Roblox menu, not ours.

| Input | Effect on the model |
|---|---|
| Mouse move | Camera look, 0.20° per pixel × look speed (0.2 to 3.0), pitch clamped ±70°. Facing target = camera look direction. |
| Arrow keys | Turn the look direction: left and right at the tier's turn rate, up and down pitch at the same rate, clamped ±70°. Always active in Keys mode, so the game is fully playable without a mouse. |
| W | Throttle 1 |
| S | Brake |
| A / D | Strafe −1 / +1 |
| Space or left mouse | Dash |
| E or right mouse | Ability |
| R | Toggle auto-swim (throttle held at 1 until W, S or R is pressed) |
| 1 / 2 / 3 | Trait slot 1 / 2 / 3: press for the popover, hold 0.6 s to shed |
| T (hold) | Emote wheel **[L]**: pick with the mouse or with 1 to 6, release to send (section 17). There are no direct emote keys. |

No auto-level in Keys mode: the creature holds whatever pitch the camera has.

### 2.4 Gamepad [L]

Button assignments are those of chapter 15, section 3.3. The pad scheme ships at [L] for PC and handheld PCs; consoles follow at [P1].

| Input | Effect on the model |
|---|---|
| Left stick | Swim, using the phone mapping in 2.1 (x = yaw rate, y = pitch target, magnitude = throttle). Radial dead zone 0.15. |
| Right stick | Look around: camera offset up to ±120° yaw and ±50° pitch at 180°/s. Dead zone 0.20. The camera recentres 0.8 s after release. It does not steer. |
| A or RT | Dash |
| X or RB | Ability |
| LT | Brake |
| D-pad left / up / right | Trait slot 1 / 2 / 3: press for the popover, hold 0.6 s to shed |
| D-pad down (hold) | Emote wheel: pick with the right stick, release to send |

LB is reserved. A pad has no strafe.

### 2.5 Input buffering [MVP]

| Rule | Value |
|---|---|
| Buffer window | 0.25 s |
| What is buffered | One dash press and one ability press, separately |
| When it applies | The press arrives while the action is blocked by cooldown, `Stunned`, `Airborne`, `Bumped` or the 0.10 s tier-up hit-stop |
| Result | If the block ends within 0.25 s of the press, the action fires on that frame. Otherwise the press is dropped. |
| Dash direction | Along current facing at the moment it fires, not along the input direction. The one exception is the dash snap toward prey **[L]** (section 4.1). |

---

## 3. Camera [MVP]

A scripted camera. The Roblox default camera is never used.

### 3.1 Follow distance and field of view

```
distance   = 4 + 10 × bodyScale          (studs behind the creature)
height     = 0.25 × distance             (above the creature centre)
lookAt     = centre + facing × (0.5 × body length)
baseFOV    = 70° vertical
speedFOV   = +6° × (forward speed / topSpeed), capped at +6°
```

| Tier | Distance | Height |
|---|---|---|
| 1 | 14 | 3.5 |
| 2 | 17 | 4.3 |
| 3 | 21 | 5.3 |
| 4 | 27 | 6.8 |
| 5 | 36 | 9.0 |
| 6 | 49 | 12.3 |
| 7 | 69 | 17.3 |

The distance follows `bodyScale` continuously (section 0.2); the table gives the values at each tier's threshold mass. The creature fills about the same share of the screen at every size; the world appears to shrink.

**Field-of-view clamp** (chapter 15, section 3.2). The horizontal field of view is held between 95° and 117° on every screen shape by adjusting the vertical one, capped at 90° (tune). The result replaces `baseFOV`; the speed, dash and tight-space offsets are added after it.

```
vFOV = 70°
if hFOV(vFOV, aspect) < 95°:  vFOV = min(90°, 2 × atan( tan(47.5°) / aspect ))
if hFOV(vFOV, aspect) > 117°: vFOV = 2 × atan( tan(58.5°) / aspect )
```

A 16:10, 16:9 or 21:9 screen keeps 70°. A 4:3 tablet rises to 79°. A 32:9 monitor falls to 49°. The full table by aspect ratio is in chapter 15, section 3.2.

### 3.2 Lag and smoothing

All smoothing is exponential: `value += (target − value) × (1 − e^(−dt / τ))`.

| Channel | τ (s) | Note |
|---|---|---|
| Position | 0.12 | The creature pulls ahead slightly when it accelerates |
| Yaw (phone, gamepad) | 0.18 | Camera yaw follows creature yaw |
| Pitch (phone, gamepad) | 0.25 | Camera pitch = 0.6 × creature pitch, so the horizon stays readable |
| Rotation (PC, two-thumb) | 0 | Input drives the camera directly; the creature turns to follow |
| Distance change | 0.25 | Used for every distance change except tier-up |

### 3.3 Tier-up pull-back

Starts at T+0.10 of the tier-up sequence. Distance eases to 115% of the current follow distance by T+0.70, then settles to 100% by T+1.20. Tier-down eases straight to the new distance over 0.4 s. Both use smoothstep, `3u² − 2u³` over the segment's time `u` from 0 to 1 (tune), so the camera neither jumps at the start nor bumps at the end.

### 3.4 Dash kick

FOV +10° over 0.08 s, held for the dash, back over 0.35 s. No screen shake on dash. A bite shakes the camera 0.15 studs for 0.10 s; a tier-up shakes 0.5 studs for 0.25 s. A "camera shake" setting turns all shake off. Shake shape (tune): every frame the camera is offset by a random vector inside a sphere of the shake's size, scaled down linearly from full to zero over the shake's time; shakes do not stack (a new one replaces a weaker one).

### 3.5 Obstacles, kelp and caves

| Case | Rule |
|---|---|
| Solid terrain between camera and creature | Sphere-cast (radius 1.0) from `lookAt` to the desired camera position. On a hit, place the camera 0.5 studs in front of the hit. Moving in is instant; moving back out uses τ = 0.40 s. |
| Minimum distance | `1.2 × collision radius + 2` studs |
| Camera closer than 60% of the desired distance | The player's own creature fades to 40% opacity (local only) so the view ahead stays clear |
| Kelp fronds and soft plants | Tagged `CameraIgnore`: never block the camera. Fronds within 6 studs of the camera-to-creature line fade to 30% opacity locally. |
| Tight-space mode (caves, dense kelp) | Enter when the clear distance is under 60% of desired for 0.3 s. Height drops to `0.05 × distance`, FOV +5°. Exit when the clear distance is above 85% for 0.5 s. Height and FOV move to the new values and back with τ = 0.25 s (3.2) (tune). |
| Surface | The camera stays below `Y = 0` unless the creature is `Airborne`; then it follows the creature's height with τ = 0.30 s. |
| Eel hole transit | Camera rides the spline 6 studs behind the eel, FOV 60°. |

### 3.6 Camera when gulped

| Time | Camera |
|---|---|
| T+0.00 | Follow stops. 0.15 s hit-stop. |
| T+0.15 to T+0.65 | Moves to a side view of the eater: `1.2 ×` the eater's own follow distance, level with its mouth |
| T+0.65 onward | Tracks the eater until the gulp card is dismissed |
| On respawn | 0.3 s fade to black, cut to the cove, 0.3 s fade in |

If the eater leaves replication range, the camera holds its last position.

### 3.7 Camera when banking

At T+0.00 the camera eases over 0.6 s to the cove's `BankCam` point (placed by document 03), looking at the creature. It stays there until the results card closes, then eases back to follow over 0.5 s.

---

## 4. Biting and eating [MVP]

### 4.1 Mouth zone

A sphere in front of the nose.

```
mouthRadius = 1.2 × bodyScale × species.mouthMult × (1.25 while Dashing)
mouthCentre = nose + facing × (0.5 × mouthRadius)
hit         = distance(mouthCentre, targetCentre) ≤ mouthRadius + targetRadius
```

For a player, wild creature or predator target, `targetRadius` is its collision radius and the target must also lie within 75° of the eater's facing.

**Gulp assist:** prey the player can eat, inside a cone from the nose, is pulled toward the mouth centre. This applies to prey and trait prey only, never to players. It makes near misses land on a phone. Its strength follows the input type in use at that moment (all tune; chapter 15, section 4.3 owns the full assist table):

| Lever | Touch, drag | Touch, two-thumb [L] | Pad [L] | Keys |
|---|---|---|---|---|
| Cone half-angle | 35° | 30° | 35° | 22° |
| Range, × `mouthRadius` | 2.5 | 2.25 | 2.5 | 2.0 |
| Pull (studs/s) | 12 | 10 | 12 | 6 |

Two more assists ship at **[L]** behind live config flags and act on computer-controlled prey only: a **steering nudge** toward the nearest edible prey within 15° of the nose (up to 20% of the turn rate, on drag and pad), and a **dash snap** that bends a dash toward edible prey inside its reach (up to 12° on drag and pad, 8° on two-thumb, none on keys). The dash snap is the one exception to "a dash goes along the current facing" (section 7.1). No assist ever acts on another player.

### 4.2 Check order

Checks run in this order. The first failure decides the result.

| # | Check | On failure |
|---|---|---|
| 1 | Eater's base state allows biting (section 0.6) and it is not `Tucked` | Nothing |
| 2 | Target exists and has not already been eaten | Nothing |
| 3 | Geometry hit (4.1) within the tolerance in 4.6 | Nothing |
| 4 | Target is outside every safe volume (players, wild creatures, predators only) | Nothing; no collision inside safe volumes |
| 5 | Target has no protection window (the first-run shield is one) and is not `Tucked` | Bump (section 6.2) |
| 6 | `canEat` tier test, including tier 1 immunity, Puff and Spiny (section 0.4) | Bump. Prey too big for the eater also bumps. |
| 7 | Repeat guard: the eater did not gulp this same player in the last 90 s | Bump |
| 8 | Newcomer bubble available on the target and the eater is a player (section 6.3) | The bubble pops; no eat |
| 9 | Plated save available on the target | Plated triggers (section 8.4); no eat |
| 10 | — | **Eat** |

### 4.3 Eat timing

| Time | What happens |
|---|---|
| Before contact | The jaw opens over 0.08 s when an edible target is within `2 × mouthRadius` |
| T+0.00 | The owning client hides the prey and adds the mass at once (prediction) and sends the claim |
| T+0.00 to T+0.10 | Prey mesh is pulled into the mouth and scaled to zero; jaw snaps shut in 0.06 s |
| T+0.10 | `FX_BubblePop`, bite sound, floating "+mass" number |
| On server reject | The prey fades back in over 0.15 s and the mass is removed. No error is shown. |

Eating prey has no cooldown and never slows the eater. Eating a player, wild creature or predator adds the `Swallowing` overlay: speed ×0.6 for 0.5 s (tune). The eater can be eaten while swallowing.

### 4.4 Mass gain

```
prey, trait prey:   gain = prey.mass × (1 + 0.10 Spots + 0.25 Bonefed)
player, wild:       gain = 0.30 × victim.mass × (1 + 0.25 Bonefed) × feedGuard
predator:           gain = predator.mass (document 03) × (1 + 0.25 Bonefed)
```

- Spots applies to prey and trait prey only. Bonefed applies to every gain.
- `feedGuard` (section 6.6) halves the gain for the second and third time the same victim is eaten inside 10 minutes, and is 0 from the fourth time: 1, 0.5, 0.25, then 0.
- **Nursery prey** (document 05, section 2.1): prey eaten inside `NurserySafe` gives 100% of its mass to a tier 1 creature, 50% to a tier 2 creature and nothing to tier 3 or higher (possible only during the 10 s exit prompt, section 6.5).
- Mass is a decimal number. Display: one decimal below 10, whole numbers from 10.
- Tier-up is checked after every gain (section 5).

### 4.5 Chain counter

- Every accepted eat (prey, trait prey, player, predator) adds 1 to the chain. The chain resets 2.0 s after the last eat.
- The chain gives **no mass bonus**. It is feedback only: the bite sound rises one semitone per step up to 12 steps, and the HUD shows "×N" from ×3.
- The best chain of a run is kept on the run record. No daily goal reads it: chapter 03's goal list (section 9) has no chain goal, and one would be added there first (section 15.3).
- A rejected eat removes its chain step.

### 4.6 Schools

Each member of a school or swarm is its own prey item. One pass through a school can eat many members; the limit is 12 prey eats per second per player. School reactions are in section 9.2.

### 4.7 Server validation

| Kind of bite | Who detects it | Tolerance |
|---|---|---|
| Player eats prey or trait prey | The client claims; the server checks | Accept if `distance ≤ (mouthRadius + preyRadius) × 1.5 + 2 studs`, using the eater's last accepted position and the prey's server position rewound by the eater's latency, at most 0.25 s |
| Player eats player, wild creature or predator | The server, on its own tick. Clients never claim these. | Exact geometry on server positions, swept between ticks so a dash cannot skip past a target |
| Predator eats player | The server | Exact geometry, swept |

- **Victim grace:** a detected bite on a player is held for 100 ms before it is committed. If a position or ability update from the victim, stamped before the bite tick, shows it entered a safe volume, began `Banking`, or activated Shell or Puff, the bite is cancelled. Stamps more than 150 ms in the past are clamped.
- **Input type is never trusted.** Gulp assist differs by input type (section 4.1); the server validates every prey claim against the widest set (touch). Input type is sent for analytics only (chapter 15, section 4.3).
- **Rate limits:** 12 prey eats per second; one player eat per 0.5 s.
- More than 20 rejected claims in 60 s flags the run (section 15.5).

---

## 5. Growth [MVP]

### 5.1 Tier-up sequence

Triggered on the server the moment mass ≥ the next tier's threshold. Size does not jump here: the body has been growing with every bite (section 0.2). The sequence is the celebration, and the moment speed, turn rate and who-eats-whom change.

| Time | Server | Owning client | Other clients |
|---|---|---|---|
| T+0.00 | Tier changes. Speed, turn rate and `canEat` use the new tier at once (the radii already follow mass). `Protected(tierUp)` starts, 1.0 s. Codex tier stamp saved. | 0.10 s hit-stop: creature animation and camera freeze, input is still read and buffered. `SFX_TierUp_Start`. | Outline colours recompute |
| T+0.10 | — | Scale pop starts (0.6 s, section 1.8). White body flash 0.15 s. `FX_TierUp_Burst`: bubble ring, radius `3 × bodyScale`. Camera pull-back starts. | Same burst and pop; sound heard within 120 studs |
| T+0.30 | — | Tier name banner for 1.5 s. Sting. Medium haptic on phone. | — |
| T+0.70 | — | Scale pop settled. Camera at 115%. | — |
| T+1.00 | Protection ends. | Shield outline off. | Outline back to normal |
| T+1.20 | — | Camera at 100%. | — |
| T+1.80 | — | Banner gone. | — |

- There is no pause of the world and no loss of control beyond the 0.10 s hit-stop.
- During `Protected(tierUp)` the creature cannot be eaten by anyone. It can still eat. Eating a player does not end this window.
- **Several tiers at once** (for example after eating a large player): one sequence, straight to the final tier. The banner shows the final tier. The Codex gets every tier passed.
- **Reaching tier 7:** the Leviathan crest grows in during the scale pop (T+0.10 to T+0.70, section 1.8; canon 5.1).
- **Tier-down:** no banner, no protection, no pop, `SFX_TierDown`. The body shrinks with the mass that was lost (section 1.8).

### 5.2 Juvenile to adult swap at tier 4

Added to the sequence above when the new tier is 4 or higher and the old tier was 3 or lower.

| Time | Event |
|---|---|
| T+0.10 | Scale pop starts on the juvenile mesh |
| T+0.25 | `FX_Metamorph` bubble cloud covers the body (fully opaque for 0.20 s) |
| T+0.35 | Under the cloud: juvenile mesh hidden, adult mesh shown at the current scale of the pop. Trait visuals re-attach to the adult attachment points. Pattern colours carry over. Animations keep playing (same rig). |
| T+0.45 | Cloud clears |
| T+0.70 | Scale pop settled |
| T+0.30 to T+2.30 | Banner shows the tier name plus a second line, "All grown up", for 2.0 s |

A tier-down from 4 or higher to 3 or lower swaps back under the same cloud during the 0.4 s shrink.

---

## 6. Player versus player [MVP]

### 6.1 Rules in full

1. A player eats another player only if `canEat` is true: at least one full tier higher than the victim's defence tier, or two with Spiny.
2. Tier 1 players are never eaten by players.
3. Nobody is eaten inside `NurserySafe` or any `CoveSafe`.
4. Nobody is eaten during a protection window (6.3).
5. A new player cannot be eaten by anything before their first bank (for up to 240 s), and the first bite an account ever takes from another player is absorbed once (6.3; chapter 04, section 4 owns the detail).
6. The eater gains 30% of the victim's mass (section 4.4). The victim's traits are not passed on.
7. The same eater cannot gulp the same victim again for 90 s (repeat guard).
8. Every other contact between two players is a bump (6.2).
9. Wild creatures (section 9.7) follow rules 1 to 8 as if they were players.

### 6.2 Bump physics

A bump happens when two collision spheres overlap outside safe volumes and no eat occurs.

| Item | Rule |
|---|---|
| Direction | Along the line between the two centres |
| Separation speed | `max(0.5 × closing speed, 6)` studs/s, capped at 30 |
| Split | Each creature receives a share equal to the other's `scale²` divided by the sum of both `scale²`. The smaller creature moves more. |
| Dash bump | If one creature is `Dashing`, its dash ends and the other's share is ×1.5 |
| `Bumped` overlay | 0.25 s for both: no thrust, coast drag only. No stun, no mass loss. |
| Pair cooldown | The same pair cannot bump again for 0.5 s |
| Softness | Player-to-player contact is a push, never a solid wall. A creature can always squeeze past. |
| Safe volumes | No player-to-player collision at all inside `NurserySafe` or `CoveSafe` |

### 6.3 Protection windows

A protected creature shows a white bubble-shield outline to everyone and no red or green outline.

| Window | Length | Protects against | Ends early when |
|---|---|---|---|
| Tier 1 | Always | Players only | Reaching tier 2 |
| First-run shield | From first control until the account's first bank, at most 240 s of play time (it does not restart on a rejoin) | Players and predators. Chapter 04, section 4 lists the hazard effects it also blocks and how the shield looks. | Never |
| Newcomer bubble | One use per account: the first bite by another player that would eat this account's creature | That one bite. The bubble pops, the newcomer is thrown 30 studs clear and gets 3 s of protection. Nothing is lost. | When used (chapter 04 owns any expiry) |
| Spawn | 5 s after leaving the own cove | Players and predators | The creature eats a player |
| Revive | 3 s | Players and predators | The creature eats a player |
| Reconnect | 3 s after resuming a suspended run | Players and predators | The creature eats a player |
| Tier-up | 1.0 s | Players and predators | Never |
| Plated save | 1.5 s | Players and predators | Never |
| Eel hole exit | 0.5 s | Players and predators | Never |
| Hook | Until re-entry + 1.0 s | Players and predators | Never |

### 6.4 Anti-grief rules

| Problem | Rule |
|---|---|
| **Cove-mouth camping** | Each cove mouth has a 50-stud loiter radius. A non-owner of tier 2 or higher builds loiter time while inside it; the timer clears after 10 s outside. At 12 s the cove's current pushes the loiterer outward at 30 studs/s for 2 s and marks it `Shooed` for 60 s: it cannot eat players within 80 studs of that cove mouth. Chasing a player home is allowed; waiting at the door is not. |
| **Predators at the door** | No predator spawns within 80 studs of a cove mouth or enters within 60 studs. A predator drops its target at that line. |
| **Spawn killing** | Tier 1 immunity, the first-run shield and newcomer bubble, the 5 s spawn window, the 3 s of protection after a revive and the 90 s repeat guard. |
| **Nursery hiding** | Creatures of tier 3 or higher cannot enter `NurserySafe` (6.5). |
| **Body blocking** | Bumps are soft pushes; there is no player collision inside safe volumes. |
| **Pushing into danger** | Bump speed is capped at 30 studs/s for 0.25 s (about 4 studs of travel). |
| **Teaming and feeding** | See 6.6. |

### 6.5 Nursery entry

- Tiers 1 and 2 enter freely.
- A tier 3 or higher creature that reaches the inlet is pushed back at 20 studs/s by a visible outflow.
- A creature that reaches tier 3 while inside gets a 10 s "Time to leave" prompt, then an outflow carries it to the inlet at 30 studs/s. It keeps `NurserySafe` protection until it crosses the inlet, then gets a normal 5 s spawn window.

### 6.6 Teaming and feeding

There are no teams and no shared protection. Friends bump like anyone else.

- **Feed guard:** each time a player eats the same victim again within 10 minutes, the mass gained is halved, and from the fourth time it is nothing (30%, 15%, 7.5%, then 0).
- **Leaderboard mass:** mass gained from eating players who are on the eater's Roblox friends list is tracked separately and subtracted from the mass submitted to the weekly leaderboard (section 15.5). It still counts for Pearls.
- Feeding is always a loss overall: the victim loses 100%, the eater gains at most 30%.

### 6.7 What each side sees

| | Eater | Victim | Bystanders within 150 studs |
|---|---|---|---|
| T+0.00 | Jaw snap, victim pulled into the mouth, `FX_BubblePop` (large), heavy bite sound, light haptic | 0.15 s hit-stop, heavy haptic, own creature pulled into the eater's mouth | The pop and the sound |
| T+0.10 | "+mass" number; `Swallowing` for 0.5 s | Camera moves to the eater (section 3.6) | — |
| T+0.30 | Feed line: victim's species icon, name and tier | — | The same feed line (creature icons only, never avatars) |
| T+1.20 | — | Gulp card (section 12) | — |

No blood and no body parts: the victim always turns into bubbles.

### 6.8 Outline colours

Computed per viewer, updated on every tier or state change and at least five times a second.

| Outline | Condition |
|---|---|
| Green | `canEat(viewer, target)` is true right now |
| Red | `canEat(target, viewer)` is true right now |
| White shield | The target has a protection window |
| None | Neither can eat the other; or the target is in a safe volume, in `Camo`, or inside an ink cloud |

Puff, Shell and Spiny change the result live, because they change `canEat`.

---

## 7. Dash and signature abilities

### 7.1 Dash [MVP]

| State | Length | Rules |
|---|---|---|
| `Ready` | — | A dash press (or buffered press) moves to `Dashing` |
| `Dashing` | `0.35 × (1 + 0.3 Longfin + 0.3 Eel)` s | Forward speed target = `topSpeed × species.dashMult` (2.2; Sea Turtle 2.0, Squid 2.6), acceleration constant 30/s. Turn rate ×0.5. Mouth radius ×1.25. |
| `Cooldown` | Until 2.5 s after the dash **started** (2.0 s for the Minnow, 3.0 s for the Sea Turtle) | Normal swimming. Speed falls back to `topSpeed` under normal drag. |

- Per-species dash values are document 03's (section 1.1).
- A dash goes along the current facing and needs no throttle. The one exception is the dash snap toward prey **[L]** (section 4.1).
- A dash cannot be cancelled by the player.
- A dash ends early on: `Stunned`, a bump with a player, being gulped, `Banking`, `Hooked`, activating Puff or Shell. The cooldown still runs from the dash start.
- A dash does not end on terrain contact (the creature slides) or on breaching.
- Cannot start a dash while: `Airborne`, `Stunned`, `Hooked`, `Transit`, `Banking`, `Gulped`, `Puffed`, `Tucked`, `Bumped`.
- Dash distance at tier 1 with no modifiers: about 20 studs. With Longfin: 26. Eel: 26. Eel with Longfin: 32.

### 7.2 Minnow · Dart [MVP]

Passive. Dash cooldown is 2.0 s instead of 2.5 s. No button.

### 7.3 Pufferfish · Puff [MVP]

| State | Time from activation | Rules |
|---|---|---|
| `Ready` | — | Press to activate. Any dash in progress ends. |
| `Puffed` | 0.00 to 2.00 s | Defence tier +1 from the first frame. Speed ×0.40. Mesh inflates over 0.20 s into a sphere 1.5 times the normal height (visual; document 03, section 1.2); collision radius ×1.3. Cannot dash. Can steer and bite. |
| `Deflating` | 2.00 to 2.30 s | No bonus, no slow. Mesh returns to normal. |
| `Cooldown` | Until 10.0 s | — |

- Cannot be cancelled early.
- Works against players and predators alike.
- Can be activated while `Airborne`. Cannot be activated while `Stunned`, `Hooked`, `Banking` or `Gulped`.
- A sting during Puff stuns the puffer; the Puff timer keeps running and the defence bonus stays.

### 7.4 Eel · Slip [MVP]

Passive. Two parts.

1. **Longer dash:** dash length ×1.3 (stacks by addition with Longfin).
2. **Eel holes:** scripted tunnels placed by document 03, each a spline with two mouths.

| State | Length | Rules |
|---|---|---|
| `Outside` | — | An eel whose centre touches a hole mouth while facing within 60° of the tunnel direction enters. Any eel tier fits. |
| `Entering` | 0.15 s | Body is pulled to the spline start |
| `Transit` | Spline length ÷ 60 studs/s (document 03 keeps every hole under 3 s) | Cannot be targeted, cannot bite, cannot steer. Moonlit pull, Glow markers and loiter timers pause. |
| `Exiting` | Instant | Leaves the far mouth at `1.2 × topSpeed` along the exit direction. `Protected` for 0.5 s. |
| Lockout | 4 s | That eel cannot enter either mouth of the same hole |

Other species bump off a hole mouth. Predators never enter.

### 7.5 Sea Turtle · Shell [L]

| State | Time from activation | Rules |
|---|---|---|
| `Ready` | — | Press to activate |
| `Tucked` | 0.00 to 2.50 s | Cannot be eaten by anything, including Old Scar. No thrust, no turn, no dash, no bite. Velocity decays with a drag constant of 6/s. Immune to jelly stings and anemone slow. The camera can still look around. |
| Early untuck | From 1.00 s | Pressing the button again ends `Tucked` |
| `Untucking` | 0.20 s | Vulnerable. Still cannot move. |
| `Cooldown` | Until 14.0 s after activation | — |

- External movement still applies in full while tucked: currents, Grouper suction, bumps.
- Vent burn still applies while tucked (it is not a bite).
- Can be activated while `Airborne`. Cannot be activated while `Stunned`, `Hooked`, `Banking` or `Gulped`.

### 7.6 Squid · Jet [L]

| State | Time from activation | Rules |
|---|---|---|
| `Ready` | — | Press to activate. Not while `Airborne`, `Stunned`, `Hooked`, `Banking` or `Gulped`. |
| `Jetting` | 0.00 to 0.50 s | Velocity is set to `−facing × topSpeed × 3.0` (document 03, section 1.2). Facing does not change (the squid keeps looking at the threat). Turn rate ×0.3. |
| `Cooldown` | Until 6.0 s | — |

- At T+0.00 an **ink puff** appears at the start position: radius `2 + 2 × bodyScale` studs (8 studs wide at body scale 1.0, as in document 03), lasts 2.0 s. It follows the ink cloud rules in section 8.4.
- Jet and dash have separate cooldowns. A dash can follow a Jet at once.
- Traits that say "dash" do not trigger on Jet. The one exception is Ink (section 8.5).

### 7.7 Shark Pup · Rampage [L]

Passive, plus a start bonus. The ability is called Rampage (ID `rampage`); "Frenzy" and `frenzy` mean only the Feeding Frenzy tide event (canon 7).

| State | Rules |
|---|---|
| `Counting` | The game keeps the times of the last three eats of tier 1 or higher prey, trait prey, players or predators. Plankton does not count. When three fall inside any 4.0 s span, go to `Rampaging`. |
| `Rampaging` | 5.0 s. Speed ×1.25. Red trail. Eating during Rampage does not extend it. |
| Lockout | 3.0 s after Rampage ends. The counter is cleared and ignores eats. |

- The Shark Pup starts every run at tier 2 with mass 10. It never has the tier 1 protection from other players, which canon 7 names as the species' intended drawback, so the 5 s spawn window matters for it.
- The HUD shows three pips for the counter in place of the ability button.

### 7.8 What blocks an ability

| Condition | Dash | Puff | Shell | Jet |
|---|---|---|---|---|
| `Stunned` | Blocked (buffer applies) | Blocked | Blocked | Blocked |
| `Airborne` | Blocked (buffer applies) | Allowed | Allowed | Blocked |
| `Slowed` | Allowed, at half speed | Allowed | Allowed | Allowed, at half speed |
| `Bumped` | Blocked (buffer applies) | Allowed | Allowed | Allowed |
| `Protected` | Allowed | Allowed | Allowed | Allowed |
| `Hooked`, `Transit`, `Banking`, `Gulped` | Blocked, no buffer | Blocked | Blocked | Blocked |
| Tier-up hit-stop (0.10 s) | Buffered | Buffered | Buffered | Buffered |

---

## 8. Traits

### 8.1 Progress pips [MVP]

- Each trait needs **5 pips** in one run (4 with the Keen Nose pass **[L]**).
- Eating one trait prey gives one pip toward its trait, plus its mass.
- Any number of traits can be in progress at once.
- Pips are per run. They reset on banking and are lost when gulped. A revive restores them.
- Prey of a trait the creature already holds gives mass only.
- While all three slots are full, trait prey gives mass only and **no pips**. Pips already collected for other traits are kept, frozen, and continue after a shed.
- If Keen Nose is bought mid-run, any trait already at 4 pips is granted at once if a slot is free.

### 8.2 Gaining a trait [MVP]

| Time | Event |
|---|---|
| T+0.00 | The last pip is eaten with a slot free. The trait takes the lowest-numbered free slot. Codex "found" stamp saved. |
| T+0.00 to T+0.50 | The trait's body feature grows in. Banner with the trait name and rarity colour, 1.5 s. |
| T+0.50 | The effect becomes active |

### 8.3 Slots and shedding [MVP]

- Three slots. No duplicate traits.
- **Shed:** tap a filled slot, then hold the confirm ring 0.6 s. The trait is removed at once, its body feature pops off as bubbles, and its pips reset to 0.
- Shedding is free, has no cooldown and gives nothing back.
- Cannot shed while `Stunned`, `Hooked`, `Transit`, `Banking` or `Gulped`.
- A shed trait can be regained in the same run by eating its prey again from 0 pips.
- **Trait Lock [L]:** offered on the gulp card only (canon 12). Nothing with a price is shown during a run. When bought, the lost run's held traits (not loose pips) are stored on the profile and applied to the next run at its start, in the same slots. One use per purchase. No expiry. Document 05 owns the price and when the button is shown.

### 8.4 Effect definitions

| ID | Scope | Exact effect |
|---|---|---|
| `glow` | [MVP] | Trait prey within 60 studs of the centre, through terrain, get a marker: a ring when on screen, an edge arrow when off screen, coloured by rarity. Six nearest at most. Prey of traits already held show dimmed. The body emits light, radius 20 studs (visible in Moon Tide). |
| `stripes` | [MVP] | `topSpeed` ×1.08. Because dash and Jet multiply `topSpeed`, they gain 8% too. |
| `spots` | [MVP] | +10% mass from prey and trait prey. Not from players or predators. |
| `plated` | [MVP] | Once per run, the first bite that would eat the creature is cancelled. The plates crack, the creature is thrown 20 studs/s away from the biter and gets `Protected` for 1.5 s. The biter cannot bite players for 0.6 s. Works against players and every predator. After use the cracked plates stay on the body with no effect. A Plated regained after shedding arrives already cracked. |
| `spiny` | [MVP] | The `canEat` gap is 2 instead of 1, for players and predators. A biter stopped only by spines gets a bump at ×1.5 strength. |
| `longfin` | [MVP] | Dash length +30% (same speed, so 30% further). |
| `ink` | [MVP] | Each dash leaves an **ink cloud** at the dash start point: radius `6 + 3 × bodyScale` studs, lasts 3.0 s, fades over the last 0.5 s. At most two clouds per player. No cloud forms inside a safe volume. |
| `spark` | [L] | At the start of each dash, prey and trait prey of the creature's tier or lower within 12 studs of the centre are stunned for 1.5 s: they stop and drift. Players and predators are not affected. |
| `camo` | [L] | After 1.5 s with speed under 2 studs/s and zero throttle, the creature gains `Camo`: 85% transparent to others, no outline, no name tag, and predators cannot detect it (a predator already chasing loses it after 1.0 s). `Camo` ends when speed passes 4 studs/s, or on dash, bite, ability, emote, bump or sting; the body fades back in 0.3 s. A camouflaged creature can still be eaten if a legal eater's mouth touches it. |
| `crystal` | [MVP] | Bank Pearls ×1.5. Must be held at the moment of banking. Also counts in the scraps calculation. |
| `ember` | [L] | No mass loss from vents. No stun from jelly blooms. Does not stop anemone slow. |
| `moonlit` | [MVP] | Prey and trait prey of the creature's tier or lower within 40 studs gain an extra velocity of 4 studs/s toward the creature, added after their own behaviour. Fleeing prey still outrun it. With two Moonlit creatures in range, prey is pulled to the nearer one. |
| `bonefed` | [L] | +25% mass from every source. |

**Ink cloud rules** (shared by the Ink trait and the Squid's ink puff):

- A creature whose centre is inside a cloud is hidden from everyone outside it: no outline, no name tag, no marker. The cloud itself is opaque.
- A predator loses its target if the target is inside a cloud or the cloud lies on the line between them. The predator searches for 2 s, then gives up.
- The cloud's owner sees it at 50% opacity. Other players inside it get a 60% dark vignette while inside. Nobody is stunned or slowed.
- Clouds do not move.

### 8.5 Stacking rules

- Speed multipliers multiply. Mass bonuses add: Spots with Bonefed is +35% on prey and +25% on players.
- Dash length bonuses add: Eel with Longfin is +60%.
- All three held traits render on the body together; each trait uses a different visual layer (documents 06 and 07).
- A specimen's cove income bonus is the sum of its traits' rarity bonuses (canon section 9).

### 8.6 Trait and ability interaction table

"—" means no interaction: both simply work side by side.

| Trait | Dash (all species) | Dart (Minnow) | Puff (Pufferfish) | Slip (Eel) | Shell (Sea Turtle) | Jet (Squid) | Rampage (Shark Pup) |
|---|---|---|---|---|---|---|---|
| `glow` | — | — | Light scales with the puffed body | Markers pause in transit | Markers stay on | — | — |
| `stripes` | Dash speed +8% | — | Multiplies: ×0.40 × 1.08 | Transit speed stays 60 | No effect while tucked | Jet speed +8% | Multiplies: ×1.35 total |
| `spots` | — | — | — | — | — | — | — |
| `plated` | — | — | Tier test first; plates are used only if the bite would still succeed | Cannot be bitten in transit | Never used while tucked | — | — |
| `spiny` | — | — | Stacks: an eater needs 3 tiers more | — | No effect while tucked | — | — |
| `longfin` | Length ×1.3 | 0.455 s dash, 2.0 s cooldown | Cannot dash while puffed | Adds: length ×1.6 (0.56 s) | — | No effect on Jet | — |
| `ink` | Cloud at dash start | Up to two clouds alive | No dash, no cloud | No cloud at hole mouths | — | The Jet puff becomes a full ink cloud (trait radius, 3.0 s) | — |
| `spark` | Pulse at dash start | Pulses every 2.0 s | No dash, no pulse | — | — | No pulse on Jet | Stunned prey count toward the three eats |
| `camo` | Dash ends camo | — | Puffing ends camo; it can re-form while puffed and still | Camo ends on entry | Tucking does not end camo; a still, tucked turtle gains camo after 1.5 s | Jet ends camo | Bites end camo |
| `crystal` | — | — | — | — | — | — | — |
| `ember` | — | — | A puffed puffer still ignores stings | — | Blocks vent burn while tucked | — | — |
| `moonlit` | — | — | Pull continues | Pull pauses in transit | Pull continues (the turtle cannot bite) | — | Pulled prey count |
| `bonefed` | — | — | — | — | — | — | — |

### 8.7 Trait and trait interactions

Every pair not listed here has no interaction.

| Pair | Ruling |
|---|---|
| `spots` + `bonefed` | Add: +35% on prey and trait prey, +25% on players and predators |
| `plated` + `spiny` | Spiny is part of the tier test and runs first. Plates are spent only when the eater is two or more tiers higher. |
| `longfin` + `ink` | The cloud still forms at the dash start; the longer dash ends further from it |
| `longfin` + `spark` | One pulse at the dash start; radius unchanged |
| `ink` + `spark` | Both trigger on the same dash |
| `ink` + `camo` | The camo timer runs normally inside a cloud |
| `ink` + `glow` | The body light is not visible from outside the cloud |
| `camo` + `glow` | The body light is off while camouflaged. The owner still sees markers. |
| `camo` + `moonlit` | The pull continues while camouflaged. Biting ends camo. |
| `spark` + `moonlit` | Stunned prey is still pulled at 4 studs/s |
| `ember` + `plated` | Independent: Ember stops hazards, Plated stops one bite |
| `crystal` + `spots` / `bonefed` | No direct link. More mass means more Pearls, which Crystal then multiplies. |
| `stripes` + any speed effect | Multiplies with Rampage, Puff, slow and currents |

---

## 9. Computer-controlled creatures

Prey are data on the server and drawn by clients (canon section 14). The server owns each prey position for bite checks. Mass, radius and art are in document 03.

### 9.1 Shared prey rules [MVP]

- **Threat:** the nearest creature inside the prey's detect radius for which `canEat(creature, prey)` is true. Prey ignore creatures too small to eat them, so prey that does not react to a player is prey that player cannot eat.
- Prey do not detect a creature in `Camo` or inside an ink cloud.
- Prey never leave their zone. At a zone edge they turn back, even while fleeing.
- Prey never harm a player. Prey too big to eat bump.
- **Simulation rate:** a prey group with a player within 700 studs updates at 10 Hz. That is beyond the 600 studs at which any player can see prey, so every prey a player sees behaves in full. Others update once a second as a single group point. Chapter 09, section 8.4 owns this mechanism and its budget.
- "Speed ×" in the tables below is relative to the canon swim speed of a player **of the prey's own tier** (tier 0 uses tier 1). A player always out-swims lower-tier prey, roughly matches same-tier prey, and closes the gap with a dash.

### 9.2 Prey behaviours [MVP]

| Prey | Calm state | Detect radius | Flee | Flee speed × (studs/s) | End of flee |
|---|---|---|---|---|---|
| `plankton` | **Drift:** 2 studs/s in a slowly changing direction; carried by currents | None | Never flees | — | — |
| `krill` | **Swarm** of 12 to 20 around a moving centre, 5.6 studs/s | 10 | **Scatter:** each member flees straight away from the threat | 0.55 (14) | After 2 s, regroups to the swarm centre over 3 s |
| `shrimp` | **Hop:** every 1.2 s, a 6-stud hop along the floor (arc 2 studs high) | 8 | Hops away every 0.5 s, 6 studs per hop | 0.45 (12) | After 1.5 s |
| `sardine` | **School** of 8 to 14, tight, 8.4 studs/s | 18 | The whole school turns away together. Members within 6 studs of the threat scatter for 1 s, then rejoin. | 0.75 (21) | Tires after 3 s: cruise speed for 2 s |
| `darter` | Solo or pairs, 10.2 studs/s, short stops | 20 | Flees with a sharp turn of 60° to 110° every 0.6 s | 0.85 (25.5) | Tires after 3 s: cruise speed for 2 s |
| `mackerel` | Straight runs along set lanes, 12.2 studs/s | 28 | Straight line away; turn rate only 120°/s | 0.95 (30.4) | Tires after 4 s: cruise speed for 2 s |
| `bonito` | Packs of 3 to 5, 13.6 studs/s | 34 | The pack splits; each member takes a different heading | 1.00 (34) | Tires after 5 s: cruise speed for 2 s |
| `tuna` | Solo, 15.8 studs/s, wide loops | 50 | Flees early in a straight line; turn rate 90°/s | 1.10 (39.6) | Tires after 6 s: cruise speed for 2 s |

- Flee speed, turn rate, detect radius and the length of a flee are copies of document 03, section 2.1, which owns every per-prey number. Calm speed is its **cruise speed**: 40% of flee speed. After a flee burst every prey is tired for 2 s and moves at cruise speed, which is the catch window for prey as fast as the player.
- **School break-up:** when a school or swarm falls to two members or fewer, the rest become stragglers. Stragglers despawn after 10 s with no player within 80 studs. The school respawns whole (9.5).
- A Spark stun freezes a prey in place for 1.5 s whatever its state.

### 9.3 Trait prey behaviours

| Trait prey | Scope | Uses the behaviour of | Differences |
|---|---|---|---|
| `glowfry` | [MVP] | `darter` | Hides in the nearest cave or kelp clump when fleeing |
| `dotted_goby` | [MVP] | `shrimp` | Sits on sand; buries itself (cannot be eaten) for 2 s after each flee |
| `zebra_darter` | [MVP] | `darter` | No differences |
| `armor_shrimp` | [MVP] | `shrimp` | Hops 5 studs; never tires |
| `urchin_puff` | [MVP] | `plankton` | Stays inside crevices; does not flee. Hard to reach, not hard to catch. |
| `ribbonfish` | [MVP] | `mackerel` | Lives in the kelp canopy and flees upward |
| `inklet` | [MVP] | `darter` | Leaves a 6-stud ink puff (2 s) when it starts to flee |
| `leaf_drifter` | [L] | `plankton` | Looks like a kelp leaf; no outline until a player is within 15 studs |
| `spark_eel` | [L] | `darter` | Lives inside the wreck; detect 24 |
| `vent_snail` | [L] | `shrimp` | Crawls around a vent rim, inside the burn area while the vent is on. Grab it while the vent is off; taking one from a vent that is on costs the burn (section 10.3). Does not flee. |
| `crystal_jelly` | [MVP] | See below | — |
| `lunar_fry` | [MVP] | `sardine` | Four to a moonbeam, circling inside it; a beam never holds more than 4. Moon Tide only (section 14.5). |
| `marrow` | [L] | `plankton` | Whale Fall only (section 14.6) |

Flee speed, flee distance, depth and spawn place for each trait prey are in document 03, sections 3.1 and 3.2.

**Crystal Jelly:** roams as a **drift of five** (canon 8.2), so one drift can give one player the Crystal trait. A new drift appears every 300 s (tune), counted from the moment the previous drift appeared, at a random point on the jelly route (document 03, section 3.2) that is at least 100 studs from every player. The five stay within 12 studs of each other and drift along the route through the Reef, Kelp and Drop-off (canon 8.2; never the Nursery) at 6 studs/s. They do not flee. A soft chime is heard within 150 studs. Jellies not eaten leave 240 s after the drift appeared, so at most one drift is alive at a time. Speed and lifetime are document 03's values.

### 9.4 Predators

Shared rules:

- A predator targets only creatures for which `canEat(predator, creature)` is true. It re-checks every tick. A target that stops being legal (tier-up, Puff, protection, safe volume, `Camo`, ink) is dropped at once.
- Predators never enter `NurserySafe`, any `CoveSafe`, or the 60 studs around a cove mouth.
- Predators do not eat prey and do not grow.
- A predator eaten by a player gives its fixed mass (Barracuda 25, Grouper 60) and respawns 45 s later at its home point, out of sight.
- Predators ignore jelly blooms, anemones, vents and currents.
- During Moon Tide every detect radius is ×0.75.
- Counts, speeds, detect ranges and rest times are document 03's (section 5.1). The state machines below are this chapter's; where one of their numbers differs from document 03, document 03 wins.

**Barracuda** [MVP] (tier 4)

| State | Rules | Leaves when |
|---|---|---|
| `Patrol` | Follows a loop at 18 studs/s | A legal target is within 45 studs, inside a 120° forward cone, with a clear line → `Telegraph` |
| `Telegraph` | 0.8 s. Stops, shakes, flashes red, "!" sound. | Always → `Chase` |
| `Chase` | Straight charges: 0.8 s at 36 studs/s with direction locked, then a 0.25 s pause to re-aim (turn rate 80°/s). Average closing speed is about 27 studs/s. | 6 s total, or the target is lost or over 90 studs away, or the leash (150 studs from the loop) is reached → `Return`. Mouth contact → eat, then `Return`. |
| `Return` | Swims back at 18 studs/s; ignores all targets for 5 s | Back on the loop → `Patrol` |

Counterplay: turn. A straight-line swimmer is caught; anything that turns during a charge is missed.

**Moray** [MVP] (tier 4, never edible)

| State | Rules | Leaves when |
|---|---|---|
| `Hidden` | In its hole. Eyes glint. Eyes glow brighter when a legal target (tier 3 or lower) is within 30 studs. | A legal target is within 14 studs of the hole mouth, inside a 100° cone → `WindUp` |
| `WindUp` | 0.6 s. Head comes out 2 studs, hiss. The aim point is fixed at the end of this state. | → `Lunge` |
| `Lunge` | Extends 18 studs at 70 studs/s (0.26 s) toward the aim point. Does not track. Mouth radius 2.76. | → `Hold` |
| `Hold` | 0.4 s extended | → `Retract` |
| `Retract` | 0.8 s | → `Cooldown` |
| `Cooldown` | 6 s in the hole; cannot trigger | → `Hidden` |

Counterplay: stay over 14 studs from holes (marked with bones), move sideways at the hiss, or pass during the cooldown.

**Gull** [MVP] (acts as tier 3; never edible)

| State | Rules | Leaves when |
|---|---|---|
| `Idle` | Not in the world | A legal target (defence tier 2 or lower) has been at the surface in the Sunlit Reef for 2.0 s without a break, and fewer than the allowed number of gulls are active → `Shadow` |
| `Shadow` | 1.5 s. A round shadow, radius 5 studs, follows the target at up to 20 studs/s; a ring closes in on it; screech at 1.0 s. | → `Strike` |
| `Strike` | Hits the shadow's position: a cylinder of radius 5 studs from the surface to 12 studs deep. The legal creature nearest the middle is gulped. Others are untouched. | → `Leave` |
| `Leave` | Flies off | The same target cannot be shadowed for 8 s → `Idle` |

Active gulls allowed: 3 at once, 5 during a Feeding Frenzy (document 03). Gulls do not hunt in the Nursery or during Moon Tide. Counterplay: dive below 12 studs or swim out of the shadow.

**Grouper** [L] (tier 5)

| State | Rules | Leaves when |
|---|---|---|
| `Patrol` | 12 studs/s along a ledge | A legal target is within 32 studs inside a 90° forward cone → `Inhale` |
| `Inhale` | 1.0 s. Mouth opens wide, streak lines converge. | → `Suck` |
| `Suck` | 2.5 s. Legal targets inside a cone 60° wide (30° half-angle) and 32 studs long are pulled toward the mouth: 22 studs/s at the mouth, falling linearly to 8 at 32 studs. Anything legal that reaches the mouth (radius 3.84) is eaten. Prey in the cone is pulled in for show. | → `Rest` |
| `Rest` | 6 s, mouth shut, no suction | → `Patrol` |

Counterplay: leave the cone sideways, or dash straight out (every tier's swim speed beats the pull). Creatures of tier 5 or higher are not pulled.

**Old Scar** [MVP] (tier 7, one per server, never edible)

| State | Rules | Leaves when |
|---|---|---|
| `Roam` | Follows Drop-off waypoints at 22 studs/s | A legal target (defence tier 6 or lower; Spiny tier 6 is safe) is within 90 studs (document 03's detect range), inside a 120° forward cone. If several, he picks the highest tier. → `Stalk` |
| `Stalk` | 1.0 s. Turns to face the target. The target hears a sting and gets a red screen edge. | → `Chase` |
| `Chase` | 40 studs/s, turn rate 70°/s | Target within 25 studs and within 20° of facing → `Lunge`. After 8 s, target lost, or the Drop-off edge + 30 studs is reached → `GiveUp`. |
| `Lunge` | 0.4 s wind-up (jaw opens), then 45 studs straight at 70 studs/s (0.65 s), no turning. Mouth radius 7.8. | → `Recover` |
| `Recover` | 1.2 s at 10 studs/s | Target still legal and under 8 s of chase used → `Chase`; otherwise → `GiveUp` |
| `GiveUp` | Returns to the route. Ignores everyone for 10 s and the last target for 20 s. | → `Roam` |

He cannot fit through gaps under 14 studs. Counterplay: turn hard, use gaps, leave the Drop-off, or be tier 7.

### 9.5 Spawn and despawn [MVP]

- The server runs a spawn pass every 1.0 s.
- For each zone and prey type: if the count is below target, spawn one individual or one whole group at a spawn region (document 03) with no player within 60 studs. If no region qualifies for three passes in a row, use the region furthest from all players.
- New prey fade in over 0.5 s and cannot be eaten until fully in.
- **Respawn delay.** Each spawn row (one prey in one zone) has its prey's respawn delay, document 03's "Respawn (s)" (sections 2.1 and 3.1). When a group of that row is eaten or removed, the row may not spawn again until the delay has run; a pass then spawns at most one group for it (three in a Feeding Frenzy, section 14.4). For normal prey the delay is divided by the running tide's prey spawn rate (canon data:Tides). This per-prey delay replaces the earlier single 8 s slot refill, which no longer applies.
- Prey have no lifetime. Only stragglers, event prey and the Crystal Jelly despawn.
- If a zone holds more than 150% of its target (after a Feeding Frenzy), the extra prey with no player within 80 studs despawn, 10 per second.

### 9.6 Density targets [MVP]

```
target(zone, type) = base(zone, type) × playerScale(n) × eventScale × areaScale
playerScale(n)     = clamp(0.6 + 0.4 × n / 24, 0.6, 1.0)
eventScale         = 2.0 for normal prey while the Feeding Frenzy tide (`frenzy`) runs, else 1.0
areaScale          = 1 on the real map; see "Smaller spawn areas" below
```

Base counts at 24 players (tune; documents 03 and 05 may rebalance). Plankton and tuna are counted as individuals; every other ordinary prey is counted in the groups document 03 uses (section 2.3). A target is never above document 03's live cap for that zone; if the two ever differ, the cap wins. Trait prey rows copy document 03's "alive per server" (section 3.1) and are generated to `TraitPreySpawns` (chapter 09, section 3.2).

<!-- data:PreyTargets -->
Soft-launch slice (chapter 13, section 3.2): `plankton`, `krill`, `shrimp`, `sardine`, `darter`, `mackerel`, `glowfry`, `dotted_goby`, `zebra_darter`, `urchin_puff`, `armor_shrimp`.

| ID | Tag | Counted as | Nursery | Sunlit Reef | Kelp Forest | Drop-off |
|---|---|---|---|---|---|---|
| `plankton` | [MVP] | Motes | 6 patches + 2 per player inside | 300 | 200 | 150 |
| `krill` | [MVP] | Swarms | 2 + 1 per player inside | 8 | — | — |
| `shrimp` | [MVP] | Groups of 1 to 3 | — | 30 | 35 | — |
| `sardine` | [MVP] | Schools | — | 6 | 5 | — |
| `darter` | [MVP] | Groups of 1 or 2 | — | 14 | 16 | — |
| `mackerel` | [MVP] | Groups of 1 to 3 | — | — | 12 | 14 |
| `bonito` | [MVP] | Packs | — | — | — | 5 |
| `tuna` | [MVP] | Animals | — | — | — | 3 |
| `glowfry` | [MVP] | Animals | — | 6 | 4 | — |
| `dotted_goby` | [MVP] | Animals | — | 10 | — | — |
| `zebra_darter` | [MVP] | Animals | — | 8 | — | — |
| `urchin_puff` | [MVP] | Animals | — | 6 | — | — |
| `armor_shrimp` | [MVP] | Animals | — | — | 6 | — |
| `ribbonfish` | [MVP] | Animals | — | — | 6 | — |
| `leaf_drifter` | [L] | Animals | — | — | 5 | — |
| `inklet` | [MVP] | Animals | — | — | — | 5 |
| `spark_eel` | [L] | Animals | — | — | — | 5 |
| `vent_snail` | [L] | Animals | — | — | — | 4 |

<!-- /data -->

- **Nursery** scales with the players inside it, not with `n`: the base in its column, plus the stated number per player inside, up to document 03's caps of 12 patches and 5 swarms (24 and 10 in a Feeding Frenzy). It is not affected by `playerScale`.
- **Individuals to groups.** A count of motes becomes patches at the mean patch size of document 03, section 2.1 (8 motes): 300 motes are 37.5 patches. Tuna swim alone, so animals are groups.
- **Smaller spawn areas (tune).** A spawn area that is not the whole zone (a test arena, a cut map) multiplies every base count, every Nursery per-player count and every cap by `areaScale = area ÷ zone area`, both measured from above (document 03, section 6.1, data:ZoneAreas). On the real map `areaScale` is 1. Each scaled target and cap rounds to the nearest whole group, and every prey the zone allows keeps at least 1 group.
- Trait prey targets ignore `playerScale` and `eventScale`.

Predators and hazards per server:

| Entity | Count |
|---|---|
| Barracuda | 3 (1 Sunlit Reef, 2 Kelp Forest) |
| Moray | One per moray hole (8 holes, document 03) |
| Grouper [L] | 4 (6 during Whale Fall) |
| Old Scar | 1 |
| Gull | On demand, up to 3 dives at once (5 during a Feeding Frenzy) |
| Jelly bloom | 6 (4 Kelp, 2 Drop-off) |
| Hook | 8 |
| Vent [L] | 9 (3 always on, 6 cycling; section 10.3) |
| Anemone [L], current | Fixed by the zone layout (document 03: 24 anemones, 6 named currents) |

### 9.7 Keeping a quiet server lively

| Measure | Scope | Rule |
|---|---|---|
| Density floor | [MVP] | `playerScale` never drops below 0.6, so one player still finds a full-looking sea |
| Fixed predators | [MVP] | Old Scar, Morays and blooms do not scale down |
| The clock | [MVP] | Tide events run on every server whatever its population |
| Wild creatures | [L] | See below |
| Busier reef prompt | [L] | After a bank on a server that has had `n < 4` for 5 minutes, the results card offers "Find a busier reef" (teleport to another public server). Never forced. |

**Wild creatures [L]:** computer-controlled creatures that use the player species meshes.

- Count: `max(0, 10 − n)`, at most 8. When a player joins, one wild creature swims off and despawns out of sight.
- Spawn at tier 1 to 3, out of sight. They eat prey and gain about 0.5 mass per second, up to tier 5. Each despawns out of sight after 6 to 10 minutes and a new one spawns.
- They follow every player rule: `canEat` in both directions, safe volumes, protection windows, bumps. They have no cove.
- **Hunting:** only players at least one tier lower, within 35 studs. They chase for at most 5 s at 0.9 × their swim speed with no dash, then leave that player alone for 15 s. They never hunt a tier 1 player, a protected player, or an account with fewer than 3 lifetime banks. They never go within 80 studs of a cove mouth.
- **Fleeing:** from any creature that can eat them, within 40 studs, with one dash.
- Name tag: "Wild" plus the species name and a leaf icon. They are never presented as players and never appear on a leaderboard.
- Eating one gives 30% of its mass, like a player.

---

## 10. Hazards and helpers

| ID | Scope | Affects | Never affects |
|---|---|---|---|
| `jelly_bloom` | [MVP] | All players and wild creatures | Ember, `Tucked`, predators, prey |
| `anemone` | [L] | All players and wild creatures | `Tucked`, predators, prey |
| `vent` | [L] | All players and wild creatures | Ember, predators, prey |
| `hook` | [MVP] | All players | Wild creatures, predators, prey |
| `current` | [MVP] | Players, wild creatures, plankton | Predators, other prey |

### 10.1 Jelly bloom

- **Shape:** 8 to 12 jellies drifting at 3 studs/s inside a fixed region. Each bell is 2 studs across (document 03, section 5.2).
- **Effect:** touching a bell gives `Stunned` for 1.5 s: no thrust, no turn, no dash, no ability, no bite; velocity decays at 4/s. The creature can be eaten.
- **After:** 3.0 s of sting immunity when the stun ends. The jelly that stung goes dim and harmless for 3 s.
- **Telegraph:** pink pulsing glow visible from 60 studs; soft tingle sound within 20 studs.
- **Counterplay:** steer around; lead a chaser through it (players who chase are stung too); Ember; Shell.

### 10.2 Anemone

- **Shape:** floor patches, radius 5 studs, height 3 studs.
- **Effect:** `Slowed` (`topSpeed` ×0.5) while touching and for 2.0 s after leaving. Touching again restarts the 2.0 s; it does not stack.
- **Telegraph:** waving tentacles in a colour used by nothing else in the Reef.
- **Counterplay:** swim more than 3 studs above the floor; Shell.

### 10.3 Thermal vent

Document 03 (sections 5.1 and 5.2) owns the vents, and the rule below is a copy of it: 9 vents at the Chimneys. The **three centre vents are always erupting**. The **six outer vents cycle** `Dormant` 4 s → `Rumble` 1 s → `Erupting` 3 s (8 s in all: 3 s on, 5 s off), each from its own fixed offset, so the six never all erupt together. This section adds only how the burn is ticked and the upward push.

| State | Length | Rules |
|---|---|---|
| `Dormant` (outer vents only) | 4 s | Harmless. No column. Vent Snails on the rim can be grabbed. |
| `Rumble` (outer vents only) | 1 s | Harmless. The warning: the rim glows brighter, a burst of small bubbles rises, a low rumble plays. |
| `Erupting` | 3 s for an outer vent; without end for a centre vent | The column is 10 studs wide (radius 5) and 40 studs tall, rising from the chimney top, the same size for all 9. A creature whose centre is inside loses 5% of its current mass per second, taken as 1.25% every 0.25 s, and is pushed up at 15 studs/s. |

- A centre vent never leaves `Erupting` and has no `Rumble`.
- Mass loss can cause a tier-down and can reduce mass to 0, but a vent never gulps.
- Ember stops the mass loss, not the push.
- **Counterplay:** at an outer vent, wait for `Dormant` or cross during `Rumble`; swim around a centre vent; Ember.

### 10.4 Fishing hook

- **Shape:** a bait on a visible line from the surface, hanging 8 to 20 studs deep in the Sunlit Reef. The hook glints. The bait has **no outline** (it is neither food nor a predator), so the colour language stays honest.
- **Effect:** touching the bait with the mouth gives `Hooked`: yanked 30 studs straight up at 50 studs/s (0.6 s), out of the water, then released into `Airborne`. The creature loses 20% of its mass, which can cause a tier-down. Comic reel sound, squeak and splash.
- **Protection:** from the bite until 1.0 s after re-entry.
- **After:** that bait is gone for 45 s, then reappears at another hook point.
- The bait gives no mass, no chain step and no Rampage count. The first hooking on an account stamps a Codex entry.
- **Counterplay:** see the line; do not touch.

### 10.5 Surface

The surface is a hazard only through the Gull (section 9.4).

### 10.6 Current

- **Shape:** a tube along a spline, 16 studs wide (radius 8), drawn as bright streaks. One direction per current.
- **Effect:** a creature whose centre is inside gains `0.6 × its canon tier speed` along the stream, added to its own velocity, blended in over 0.3 s on entry and out over 0.3 s on exit. Swimming with it gives +60%; swimming against it leaves 40%.
- Dash and all speed multipliers work normally inside.
- Predators are not carried, so a current is an escape route.

---

## 11. Banking [MVP]

### 11.1 The cove mouth and "inside"

- Each cove has one volume, `CoveSafe`: the cove interior up to the flat plane of the mouth opening. There is no porch outside it.
- A creature is **inside** when its centre is inside `CoveSafe` on the server.
- Safety and banking start at the same instant: the tick on which the owner's centre crosses the mouth plane.
- Requirement on document 03: every mouth opening is at least 30 studs across, so a tier 7 creature fits.
- **Membrane:** a thin bubble film across each mouth. The owner passes freely. Others: section 13.4.

### 11.2 When a bank triggers

All must be true: the creature is the cove's owner; the base state is `Swimming` or `Airborne`; the run is armed (mass ≥ 1). There is no confirm prompt.

- With mass < 1 the creature simply enters and returns to `InCove` (section 0.7).
- If a bank and a bite on the same creature fall on the same server tick, the bank wins.
- `Stunned` creatures can drift in and bank. `Hooked` and `Transit` creatures cannot be at a cove mouth.

### 11.3 The bank sequence

| Time | Event |
|---|---|
| T+0.00 | Server: state `Banking`. Mass, tier and traits are final. Payout is computed and added to the profile. Controls lock. Any dash, Puff or stun ends. |
| T+0.00 to T+1.20 | The creature auto-swims along the cove's entry path to the bank spot. Camera eases to `BankCam` (0.6 s). |
| T+1.20 to T+2.70 | Pearl count-up, 1.5 s. Lines shown in order: base Pearls, Crystal ×1.5, Deep Pockets ×2. |
| T+2.70 to T+3.70 | Specimen step (11.4) |
| T+3.70 to T+4.50 | Up to three toasts (Codex, daily goal, Reef Rank), 0.5 s apart |
| T+4.50 | Results card: "Swim again" (default), "Change species", "Cove" |

- Tapping anywhere after T+1.20 skips to the next step. The shortest full sequence is 1.5 s.
- Leaving the results card spawns a new Fry at the cove spawn point in state `InCove`.

```
basePearls = 3 × min(mass, 1200) + 1 × clamp(mass − 1200, 0, 1800)
bankPearls = floor(basePearls × (1.5 if Crystal) × (2 if Deep Pockets))
```

Canon 5.4: 3 Pearls per mass up to 1,200 mass, 1 per mass from 1,200 to 3,000, nothing above 3,000, so the largest base bank is 5,400. Document 05, section 3.1 owns the formula. Mass above 3,000 still counts in full for the leaderboards.

### 11.4 The specimen step

| Case | Result |
|---|---|
| Tier 1 at banking | No specimen. The creature turns into Pearls. Line: "Too small to keep. Reach Nibbler." |
| Tier 2 or higher, free slot | The creature swims to the lowest free slot (1.0 s) and becomes a specimen. A card shows species, tier, mass, traits and Pearls per hour. |
| Tier 2 or higher, cove full | The full-cove choice (11.5) |

A specimen stores: species, pattern, tier, final mass, up to three trait IDs, Plated cracked or not, and the UTC date.

### 11.5 The full-cove choice

- A modal panel shows the new creature beside every specimen, sorted by Pearls per hour, lowest first.
- The player picks one to release: either the new creature or one specimen. Releasing needs a 0.8 s hold.
- The released one pays a refund: `max(5, floor(one hour of its income))` Pearls (document 05, section 3.10 owns the amount).
- A specimen marked as locked **[L]** cannot be picked.
- There is no timer. The player is safe in the cove and cannot start a new run until the choice is made.
- If the player disconnects with the panel open, the new creature is saved as `pendingSpecimen`. The panel opens again on the next join, before anything else.

### 11.6 Interrupted banking

| Interruption | Ruling |
|---|---|
| Another player or predator arrives | No effect. `Banking` is inside a safe volume. |
| Disconnect after T+0.00 | Pearls are already on the profile. With a free slot, the specimen is created anyway. With a full cove, it is saved as `pendingSpecimen`. |
| Server shutdown | Same as a disconnect |
| A tide event starts | Its banner waits until the results card closes |
| Save failure | Document 09 defines retries. The payout is never granted twice. |

---

## 12. Getting gulped [MVP]

### 12.1 The sequence

| Time | Event |
|---|---|
| T+0.00 | Server commits the bite. Victim state `Gulped`; its creature leaves the simulation. The eater gains its mass. Victim client: 0.15 s hit-stop, heavy haptic. |
| T+0.00 to T+0.25 | The victim's creature is pulled into the eater's mouth and scaled to zero. Large `FX_BubblePop`. Gulp sound. |
| T+0.15 to T+1.20 | Camera on the eater (section 3.6) with its name, species and tier. For a predator, the predator's name. |
| T+1.20 | Gulp card: who gulped you, run time, peak tier, mass, the lost traits popping one by one, and the scraps amount. Buttons depend on 12.3. The card has no timer of any kind: it waits for a tap. |
| On "Swim again" | Scraps are paid. Respawn (12.4). |

"Swim again" can be tapped from T+1.20, so the shortest time from being gulped to having control again is 2.0 s.

### 12.2 Scraps

```
scraps = floor(bankPearls(at the moment of the gulp) × rate)
rate   = 0.50 for the account's first three gulps, 0.10 after
```

- `bankPearls` includes Crystal and Deep Pockets.
- Scraps are paid when the player taps "Swim again" or disconnects. A revive pays no scraps.
- Scraps count toward Reef Rank at their value before Deep Pockets (section 15.2). They do not count on any leaderboard.

### 12.3 The revive offer

| Rule | Value |
|---|---|
| Offered when | The run has not been revived yet; mass at the gulp was 30 or more (tier 3 or higher); it is not the account's first death; the player is past the scripted intro of document 04 |
| Not offered | The card shows "Swim again" and no Revive button. It still waits for a tap. |
| Options | Revive for Robux **[MVP]**; a free Revive by rewarded video **[L]** where the game and the player are eligible, at most 3 per UTC day; Trait Lock **[L]** as a separate button |
| Timer | None (canon 5.5). The offer stays until the player taps Revive or "Swim again". |
| Result | The creature returns with 70% of its mass at the gulp (tier recomputed), all traits and pips, and the same Plated state |
| Where | At the gulp position if nothing that can eat the revived creature is within 60 studs. Otherwise at the nearest revive point (document 03 places at least 12) that passes the same test. |
| Protection | 3 s (section 6.3) |
| The eater | Keeps the mass it gained. The 90 s repeat guard applies. |
| Failed delivery | If the purchase completes but the revive cannot be applied (the server is closing, or the player has already swum again), the player gets one Revive Token, used automatically at the next offer |

### 12.4 Respawn

- 0.3 s fade out, 0.3 s fade in. The player appears at the own cove spawn point as a tier 1 Fry with mass 0 (Shark Pup: tier 2, mass 10), same species, state `InCove`.
- Respawn finishes within 0.8 s of the tap, under the canon limit of 3 s.
- The species can be changed from the cove before leaving.

---

## 13. The cove

### 13.1 Specimen display [MVP]

- Each slot is a perch (document 03, section 6.10 owns the name). Its specimen swims a short idle loop there.
- Display scale is `0.8 + 0.35 × tier` (tier 2: 1.5, tier 7: 3.25), not the in-run body scale. Document 03, section 6.10 owns this value.
- Traits and pattern are shown on the specimen. Tapping one opens its card.
- The owner can swap two specimens' slots in edit mode (only in state `InCove`).
- **Mouth plaque:** owner's display name, Reef Rank **[L]**, Bubble count **[L]**, and the **best specimen**: highest tier, then highest mass, then newest. The owner can pin a different one **[L]**. If the pinned specimen is released, the plaque returns to the default.

### 13.2 Income accrual and claim [MVP]

```
base(tier)     = 6 / 10 / 18 / 30 / 50 / 80 Pearls per hour for tiers 2 to 7   (a table, not a formula)
rate(specimen) = base(tier) × (1 + sum of trait rarity bonuses)
                 bonuses: Common +10%, Uncommon +20%, Rare +35%, Epic +60%, Mythic +100%
totalRate      = sum over all specimens
pending       += totalRate × Δt / 3600, counted only while (now − lastClaim) < cap
cap            = 8 hours (24 with Tide Watcher [L])
```

- Document 05, section 3.3 owns the base table and the trait bonuses.
- There is one cap and one pile. The pile fills at the same rate online and offline and stops when the time since the last claim reaches the cap.
- When the set of specimens changes (a bank or a release), the server first adds income up to that moment at the old rate, then switches to the new rate.
- **Claim:** the owner touches or taps the Pearl clam in the cove. All of `pending` (rounded down) moves to Pearls and `lastClaim = now`.
- **The one automatic payment** (canon 11): a new player's first specimen pays one hour of its income by itself, once per account, as a first-bank reward. Nothing else in the cove ever pays without a tap. Chapter 04, section 6.2 owns the amount and the timing.
- The clam shows the pile and updates every 10 s. It shows "Full" at the cap.
- All times are server UTC. If `now < lastClaim`, elapsed time is 0.
- Income does not count toward Reef Rank.

### 13.3 Offline calculation [MVP]

- On join the server brings `pending` up to date, subject to the cap.
- If the player was away 10 minutes or more and earned 10 Pearls or more in that time, a "While you were away" card shows the amount earned since the last leave and a Claim button.
- **Cove Boost [L]:** adds 2 hours of the cove's current income to Pearls at once, once per UTC day. It is a product sold for Robux and, where the game and the player are eligible, free by rewarded video. It is offered on this card and at the clam. Document 05 owns the price and limits.
- The card is not shown during the scripted intro (document 04).

### 13.4 Visiting [L]

Until this ships, every cove membrane blocks non-owners (bump).

| Rule | Value |
|---|---|
| Whose coves | Only players on the same server. An unassigned cove is closed and reads "Vacant". |
| Swim in | Only a **tier 1** creature passes another player's membrane. Tier 2 or higher bumps off. This stops other coves being used as safe rooms. |
| Visit button | From `InCove`, the cove list offers "Visit": the player's creature is moved to the chosen cove's spawn point |
| State | `Visiting`: can steer, look, open specimen cards, leave a Bubble, emote. Cannot bite, claim, edit or bank. |
| Leaving | Through the mouth. This starts a normal run with the 5 s spawn window. |
| Limit | 6 visitors per cove at once. More bump with a "Full" icon. |
| The owner | Sees visitors' creatures. Nothing can be taken or moved by a visitor. |

### 13.5 Bubbles [L]

| Rule | Value |
|---|---|
| Give | In `Visiting`, after 5 s inside, tap the Bubble button |
| Limit | One per visitor per cove per UTC day, and 10 given per visitor per day in total |
| Giver must have | At least 1 lifetime bank, and an account not flagged by anti-cheat |
| Self | A player cannot Bubble their own cove |
| Effect | Owner's lifetime Bubble count +1. A bubble with the visitor's species icon floats in the cove for 60 s. The owner gets a toast if online. |
| Reward | None. Bubbles buy nothing. |
| Private servers | Bubbles can be given but are not added to the lifetime count |

### 13.6 Decorations [L]

- Each cove has **29 decoration spots** in five classes: 10 small floor, 6 medium floor, 3 large floor, 6 wall and 4 ceiling. Counts and positions are fixed by document 03 (section 6.10).
- A decoration has one class. It fits a spot of the same class only. One decoration per spot.
- It can be rotated in 45° steps. There is no free placement.
- Edit mode is open to the owner in state `InCove` only. Changes save at once and appear for visitors at once.
- Removing a decoration returns it to the inventory. Decorations are owned for good; each purchase is one copy.
- Decorations are cosmetic only. They never change income, safety or any rule.
- Unlock conditions and prices are in document 05.

---

## 14. Tide events

### 14.1 The clock [MVP]

```
c     = serverTimeUTC mod 900          (seconds into the 15-minute cycle)
slot  = floor(serverTimeUTC / 900) mod 4
        0 → frenzy (:00)   1 → moon_tide (:15)   2 → frenzy (:30)   3 → whale_fall (:45)
```

| Phase | `c` | Length |
|---|---|---|
| `Active` | 0 to 240 | 4 minutes |
| `Calm` | 240 to 840 | 10 minutes |
| `Warning` | 840 to 900 | 60 seconds, for the next slot |

- Every server computes the phase from the wall clock. Servers do not message each other.
- Clients receive the event ID and its start time and count down with the synced server clock, never the device clock.
- **Until Whale Fall ships [L], slot 3 runs Moon Tide.**

### 14.2 Warning, start and end [MVP]

| Time | Event |
|---|---|
| T−60 | Horn. Banner with the event name and a countdown, shown 4 s, then a small HUD timer. |
| T−10 | Countdown ticks. Lighting and music start to blend toward the event look. |
| T+0 | Event rules switch on. Start sting. |
| T+230 | "Tide is going out" cue. Lighting blends back over 10 s. |
| T+240 | Event rules switch off. Event prey fade out over 3 s. |

Tide Watcher **[L]** adds an in-game tide board that shows the next three tides, and a marker on the HUD edge that points to the event while a tide runs (canon 12; document 05 owns the pass). It gives no earlier alert and sends nothing outside the game: every player gets the same T−60 warning, and every player sees the clock and the next tide for free.

### 14.3 Joining mid-event [MVP]

- The client gets the current phase and start time on join and blends to the event look over 2 s.
- The player takes part with no restriction.
- A player in the scripted intro (document 04) gets no event banner, lighting or music until the intro ends. Event prey still exist in the world.

### 14.4 Feeding Frenzy [MVP]

| Rule | Value |
|---|---|
| Density target | ×2.0 for normal prey in every zone, including the Nursery |
| Refill | Three spawns per pass instead of one, and every respawn delay of normal prey divided by 3 (a 12 s `krill` delay becomes 4 s; section 9.5). Both come from the tide's prey spawn rate, ×3 (canon section 10, data:Tides) |
| Trait prey | Unchanged. The Crystal Jelly timer is unchanged. |
| Which tide | Only the `frenzy` tide doubles the density target and the caps. The spawn rate and the density are two rules: a tide's prey spawn rate (canon data:Tides) divides respawn delays and sets spawns per pass for any tide, and a future tide with a rate above ×1 does not double the density unless this chapter says so for that tide |
| Predators and hazards | Unchanged |
| Look | Warm water tint, faster music, spawn regions bubble visibly |
| End | No prey is removed at T+240. The surplus is eaten or trimmed by the 150% rule (section 9.5). |

### 14.5 Moon Tide [MVP]

| Rule | Value |
|---|---|
| Light | Ambient light falls to 25% over 10 s. Fog end distance 400 → 140 studs. Prey and creatures gain a soft glow. Outline colours are unchanged. |
| Lunar Fry | 40 per server per event, enough for 8 players to gain Moonlit (document 05, section 2.1 owns the count). They appear inside the three visible moonbeams, one per zone, which document 03 places (section 7.2). Each beam starts with 4, so 12 at T+0. |
| Refill | One more Lunar Fry appears every 7 s, at the beam with the fewest alive, until the 40 have been released. A beam never holds more than 4 at once. These are document 03's numbers. |
| Predators | Detect radii ×0.75. Gulls do not hunt. |
| End | Remaining Lunar Fry fade out over 3 s. Pips already collected are kept for the rest of the run. |

Lunar Fry are tier 2, so a tier 1 Fry must grow first.

### 14.6 Whale Fall [L]

| Time | Event |
|---|---|
| T−60 | Whale song. A large shadow crosses the surface toward the Drop-off and shows every player where the site is. The HUD-edge marker to the site is the Tide Watcher perk (section 14.2) and appears for pass owners while the tide runs. |
| T+0 | The whale skeleton (clean white bones, about 60 studs long) appears at the surface over the site and sinks at 20 studs/s |
| On landing | The first Marrow chunks drift out of the ribs. Old Scar leaves his route for the site. The Groupers move to within 50 studs and two more appear (6 in all). |
| After landing | More Marrow in bursts until 60 chunks have been released in the event (document 05, section 2.1 owns the count; document 03 owns the burst times). Chunks drift up and outward. |
| T+240 | Uneaten Marrow fades in 3 s. Predators return to their routes and the two extra Groupers leave. The skeleton stays as scenery until the next event's warning, then breaks into bubbles over 5 s. |

- **The skeleton cannot be bitten.** It is bare bone. The mass at a Whale Fall is the Marrow (60 chunks of mass 40, so 2,400 per event whatever the player count) and the extra prey document 03 places around the site.
- **Old Scar at the site:** circles at 90 studs. He starts a chase only on a legal target within 45 studs of him, and returns to the circle after `GiveUp`.
- Marrow is tier 3 trait prey. Pips are kept after the event.

### 14.7 Call the Tide [L]

A product that starts a Feeding Frenzy on the buyer's server only.

| Rule | Value |
|---|---|
| Purchase | Can be bought at any time. Every purchase grants one **Tide Token** on the buyer's profile (document 09, section 11.2). The token is held, never spent by the purchase itself: it joins the server's queue in the order bought and is spent only when its own called tide starts. A player can hold up to three Tide Tokens; the buy button is closed while they hold three. |
| Length | 10 s warning, then 240 s with the rules of 14.4 |
| The clock | Never shifted. A called tide never interrupts or overlaps a scheduled tide or its warning (canon 10). |
| Starts with no wait | The 10 s warning begins straight away when the token is first in the queue, the phase is `Calm`, at least 250 s remain before the next `Warning` (`240 ≤ c ≤ 590`) and no called tide has run in this `Calm` phase |
| Waits | In every other case the token stays held and its called tide starts, after the 10 s warning, when the current (or next) scheduled tide ends. The tide clock shows "Tide called" with the time left. |
| Limit | Up to three tokens per player. When several players hold tokens, the called tides start one at a time in the order the tokens were bought, each after its own 10 s warning, and only when no tide is running (no scheduled tide or warning, and no other called tide). One called tide per `Calm` phase per server, so each later token waits for the next `Calm` phase. |
| Unused token | If the buyer leaves or the server closes before the tide starts, the token stays on the profile and is used free on a later server |
| Credit | Banner for everyone: "<display name> called the tide!" with the buyer's species icon |
| Private servers | Allowed |

---

## 15. Meta systems

### 15.1 Codex [MVP]

| Page | Entry is found when | Extra state |
|---|---|---|
| Species | The player starts a run as the species (document 03, section 8.1). Others show as a silhouette once seen within 60 studs. | — |
| Tiers (seven stamps per species) | That species reaches the tier in any run. Saved at tier-up; banking is not needed. The Shark Pup starts at tier 2, so its Fry stamp is filled the first time it is played. | — |
| Traits | The trait is gained in a run | "Banked" once a specimen carries it |
| Prey and trait prey | Eaten once | Count eaten; stars at 10, 100 and 1,000 **[L]** |
| Dangers **[L]** | The player comes within 30 studs of the predator or hazard, or is caught by it | Flags: "gulped by", "ate one", "hooked" |
| Places **[L]** | The player swims within 40 studs of the landmark | — |
| Tides **[L]** | The player eats 10 prey during the event | — |

- Completion per page = found ÷ total entries in the current build. Only content that has shipped counts.
- A page completed once keeps its completion badge when new content is added.
- Stamps save the moment they are earned. A later gulp or disconnect does not remove them.
- The Codex is account-wide and also fills in private servers.
- The pages are Species, Tiers, Traits and Prey at [MVP], plus Dangers, Places and Tides at [L] (canon 11). Document 03, section 8 owns the entry lists and how each entry is filled; the table above copies it.
- Rewards per entry and per page are in document 05.

### 15.2 Reef Rank [L]

- Levels 1 to 50. It never goes down.
- **Rank points** = lifetime Pearls from banking and from scraps, both counted **before** pass multipliers (canon 11): `floor(basePearls × (1.5 if Crystal))` for a bank (section 11.3), and the scraps of a gulp at their value without Deep Pockets. Deep Pockets does not speed up rank.
- Cove income, goal rewards, streak rewards, Codex rewards and bought Pearls give no rank points.
- Thresholds are document 05's (section 7): points needed for rank `r` = `100 × (r − 1)^2.2`, rounded as in its table. Rank 50 needs 523,000.
- Rank shows on the name tag and the cove plaque. Unlocks are in document 05.

### 15.3 Daily goals [MVP]

| Rule | Value |
|---|---|
| Count | Three per UTC day |
| Selection | Seeded by user ID and UTC day number. One Easy, one Medium and one Hard goal from chapter 03's list (canon 11); the one exception is an account's first day, which uses the fixed set `dg_eat_50`, `dg_tier3` and `dg_bank_snapper` (Easy, Easy, Medium). Where the list allows, the three also come from three different pools: **Eat** (eat N of a prey type; eat N prey in a zone), **Grow and bank** (reach tier N; bank with mass ≥ M; bank holding a trait), **World** (eat N prey during a tide event; ride a current; breach N times; dodge a predator; visit other coves **[L]**). Chapter 03, section 9 owns the list: it has no chain goal and no Bubble goal. |
| Fit to the player | A tier goal is never above the account's best tier + 1. A goal never needs content that has not shipped, a species the player does not own, or a purchase. At most one goal a day needs eating players, and only on a server with 6 or more players. |
| Progress | Counts from the moment the goal is given. Carries across servers and sessions. |
| Completion | Automatic. The reward is paid the moment the goal completes: the Pearls fly to the counter and there is no claim button (chapter 04, section 7.2), so nothing is left unpaid at reset. Document 05, section 3.5 owns the amounts. |
| All three done | A bonus reward (document 05). **[L]** The lifetime count of days with all three done gives four free decorations, at 3, 7, 14 and 28 days (chapter 03, section 13). |
| Reset | 00:00 UTC. A player online at reset gets the new goals at once with a toast; old progress is dropped. |
| Reroll | One free reroll per day on any unfinished goal **[MVP]**. One more per day by rewarded video where eligible **[L]**; the same Goal Reroll is also sold as a product (document 05 owns the price and limits). The new goal has the same difficulty, differs from the current three, and starts at 0. |
| Private servers | Goals progress normally |

### 15.4 Login streak [L]

- A 7-day calendar. The day counter moves forward one box on the first join of each UTC day.
- The day's reward is granted automatically the first time the cove loads that day, with a card. It is not shown during the scripted intro.
- **Missed days:** a missed day never resets the calendar. The next box simply waits for the next day the player joins (canon 11).
- After day 7 the calendar starts again at day 1 and a cycle counter goes up by one.
- Rewards are in document 05.

### 15.5 Leaderboards

| Board | Scope | What is ranked | Reset | Shows |
|---|---|---|---|---|
| Biggest right now | [MVP] | Current mass of every player in a run on this server | Live, updated every 1 s, not saved | Top 5 and the player's own place. First place wears a crown that everyone can see. |
| Biggest banked creature | [L] | Each player's highest **leaderboard mass** for one banked creature this week, across all public servers | Monday 00:00 UTC. The top 100 are archived. | Top 100 and the player's own place |
| Most Bubbles | [L] | Lifetime Bubbles received | Never | Top 100 and the player's own place |

**Leaderboard mass** = final mass − mass gained from eating Roblox friends (section 6.6).

A banked run is left out of the weekly board if any of these is true:

| Exclusion | Rule |
|---|---|
| Private server | The run was banked on a private server |
| Too short | The run lasted under 60 s |
| Too fast | Final mass ÷ run seconds is above 25 |
| Movement flags | Three or more speed violations in any 10 s of the run |
| Bite flags | More than 20 rejected bite claims in any 60 s of the run |
| Account | The account is banned or under review (document 09) |

Excluded runs still pay Pearls and still create specimens. Wild creatures never appear on any board.

---

## 16. Server and session rules

### 16.1 Server fill [MVP]

- 24 players per server, 24 coves. Fill uses the Roblox default ("Roblox optimises server fill"). No slots are held back.
- **Cove assignment** (chapter 04, section 5.5 owns the rule; chapter 03, section 6.7 names the coves): a new player (an account that has never banked) gets the free cove nearest the Nursery gap, measured from Little Arch: C16, C17, C15, C18, then the next nearest, so its first trip home is short. A returning player (an account that has banked before) gets the free cove farthest from Little Arch among the 20 coves nearest to it, so the four closest stay free for newcomers where possible **(tune)**. If the player joined a friend **[L]**, the nearest free cove to that friend's is used instead.
- A cove is kept for 120 s after its owner disconnects. If a new player joins and no other cove is free, the kept cove is given up at once.

### 16.2 Joining friends [L]

- Roblox friend-join is on. A friend joins if the server has space.
- A returning player always spawns in their own cove. A first-session player goes to the scripted intro (document 04), and so does an account that disconnected before its first bank (section 16.4).
- There are no parties and no shared rewards.

### 16.3 AFK [MVP]

| Time with no input | Result |
|---|---|
| 120 s | Flagged AFK. Not counted in `n`. A "zzz" icon appears over the creature. |
| Any input | The flag clears at once |
| 20 minutes | Roblox disconnects the player (platform rule). This is treated as a disconnect (16.4). |

- An AFK creature in open water gets no protection. It can be eaten under the normal rules.
- There is no automatic bank for AFK players.
- Cove income is time-based, so it accrues whether or not the player is AFK.

### 16.4 Disconnect mid-run [MVP]

| Base state at disconnect | Ruling |
|---|---|
| `InCove`, `Visiting` | Nothing at stake. The profile saves. |
| `Banking` | Section 11.6 |
| `Gulped` | Treated as a declined revive. Scraps are paid. |
| `Swimming`, `Airborne`, `Stunned`, `Hooked`, `Transit` | The creature stays in the world for **10 s**, drifting with no input and open to attack. If it is gulped in that time, scraps are paid. If it survives, it is removed and the run is saved as a **suspended run**. |

The 10 s rule stops players escaping a chase by quitting.

**An account that has never banked** follows the same rule (canon 5.5). During the 10 s its first-run shield still protects it, so nothing can eat it while any of its 240 s remain. The run is then suspended for 300 s. If the player rejoins in time, the run resumes at once with no "Continue your run" card (chapter 08, screen S36, is shown only to accounts that have banked at least once), and the first-time script resumes from the last completed beat. If not, the run is lost, scraps are paid at the first-three-deaths rate of 50%, and the next join restarts the scripted intro, in its fast form the first time and as a plain Nursery start after that. The first-run shield does not restart; only what is left of its 240 s applies. Chapter 04, section 9 owns these rules.

**Always saved on disconnect:** Pearls, specimens, `pendingSpecimen`, pending cove income and `lastClaim`, Codex stamps, daily goal progress, streak, Reef Rank points, tokens, and any suspended run.

### 16.5 Reconnect mid-run [MVP]

| Rule | Value |
|---|---|
| Suspended run stores | Species, pattern, mass, traits, pips, Plated state, revive used or not, run time, feed-guard list, position, leaderboard flags |
| Lifetime | 300 s, measured from the disconnect to the moment the player rejoins. The check is made once, at join. Time spent looking at the card is not counted: the card has no timer and the run cannot expire while it is open. |
| Offer | On joining any server within that time, a card (chapter 08, screen S36) offers "Continue your run" or "Start fresh". It is shown only to an account that has banked at least once. An account that has never banked gets no card: its run resumes at once and the first-time script carries on from the last completed beat (section 16.4). |
| Continue | The creature appears at the stored position (the map is the same on every server) if nothing that can eat it is within 60 studs; otherwise at the nearest revive point. `Protected(reconnect)` for 3 s. |
| Start fresh, or the time runs out | The run is paid as scraps at the normal rate |
| Leaving again with the card open | Nothing is chosen. The run stays suspended with its original expiry time. |
| Server shutdown | Every run in progress is suspended with a 900 s lifetime. If it runs out, it pays the full `bankPearls` and creates no specimen. |

### 16.6 Private servers [L]

| Rule | Value |
|---|---|
| Features | Everything works: tide clock, events, Call the Tide, goals, Codex, Pearls, specimens, cove income |
| Left out | Weekly leaderboard entries; Bubbles toward the lifetime count |
| Owner settings | "Friendly reef" (player-versus-player eating off; players only bump) and "Wild creatures" (on or off). Both default to the public rules. |
| Feed guard | Applies as on public servers |
| Minimum players | None |

---

## 17. Quick emotes and other communication

### 17.1 Emotes [L]

Six icon bubbles. No text. Chapter 03, section 14 owns the set, the IDs, the labels and the pictures; this table repeats them and adds the body animation.

| ID | Label | Icon | Body animation |
|---|---|---|---|
| `em_hi` | Hi! | Waving fin | Quick fin wave |
| `em_this_way` | This way! | Arrow along the sender's facing | Nod forward |
| `em_look_out` | Look out! | Red "!" in a spiky bubble | Flinch |
| `em_thanks` | Thanks! | Pink heart | Small happy spin |
| `em_ha_ha` | Ha ha! | Laughing fish face | Body shake |
| `em_oops` | Oops! | Fish face with a sweat drop | Small sheepish dip |

| Rule | Value |
|---|---|
| Display | A bubble over the creature for 2.5 s, visible to creatures within 120 studs. Sound heard within 60 studs. |
| Animation | 0.6 s, additive. It never changes movement or the hitbox. |
| Cooldown | 3 s. More than 8 emotes in 30 s locks emotes for 20 s. |
| Open | Phone: hold the emote button, slide to an icon, release. Keys: hold T, move the mouse or press 1 to 6, release. Gamepad: hold D-pad down, pick with the right stick, release. (Chapter 15, section 3.3.) |
| Allowed in | `InCove`, `Swimming`, `Airborne`, `Visiting`, and while `Puffed` or `Tucked` |
| Gulp card | The victim may send one emote from the gulp card. It shows on the eater's feed line. |
| Not allowed in | `Stunned`, `Hooked`, `Transit`, `Banking` |
| Camo | Sending an emote ends `Camo` |
| Muting | A setting hides all emotes. Tapping a name on the leaderboard mutes that player's emotes. |

### 17.2 Other non-chat communication

| Channel | Scope | Rule |
|---|---|---|
| Outline colours | [MVP] | Section 6.8 |
| Name tag | [MVP] | Display name and tier pips over each player creature within 80 studs; Reef Rank added at **[L]**. Hidden in `Camo` and inside ink. |
| Crown | [MVP] | On the server's biggest creature |
| Feed line | [MVP] | Player gulps and tier 5+ tier-ups, shown as creature icons |
| Shield outline | [MVP] | Shows that a creature is protected |
| Bubbles | [L] | Section 13.5 |
| Cove plaque | [MVP] | Section 13.1 |

The game has no feature that needs text chat. Roblox text chat is switched off in the MVP and reviewed for launch (canon 14). If it ships at [L], document 08 owns where its window sits.

---

## 18. Edge cases and rulings

| # | Case | Ruling |
|---|---|---|
| 1 | Two players bite the same prey in the same frame | The claim the server processes first wins. The other is rejected and rolled back (section 4.3). |
| 2 | Two players can both eat the same player on the same tick | The one whose mouth centre is nearer the victim's centre wins. If equal, the one with more mass. |
| 3 | Two same-tier players meet head on | Bump. Neither is eaten. |
| 4 | A player is bitten on the tick it crosses its own cove mouth | The bank wins (section 11.2). |
| 5 | A bite is detected, then a victim update stamped earlier shows it was already inside a cove | Cancelled by the victim grace (section 4.7). |
| 6 | Tier-up while a player is chasing you | The new tier applies at once. If the chaser no longer has the tier gap, its outline to you changes and contact bumps. You also get 1.0 s of protection. |
| 7 | Tier-up while a predator is chasing you | The predator re-checks `canEat` every tick and goes to its give-up state if you are no longer legal. |
| 8 | Growing inside a tunnel too narrow for the new size | The creature is moved to the newest fitting point on its 10 s trail (section 1.8). |
| 9 | Reaching tier 3 inside the Nursery | 10 s prompt, then the outflow carries the creature out (section 6.5). |
| 10 | An ability button is pressed during a stun | Ignored, unless the stun ends within 0.25 s; then it fires (section 2.5). |
| 11 | Stung while puffed or tucked | Puffed: stunned, but Puff keeps running. Tucked: no stun. |
| 12 | Stung during a dash | The dash ends. The cooldown keeps running from the dash start. |
| 13 | Puff ends while a one-tier-higher eater's mouth is on the puffer | The puffer is eaten on the next tick. `Deflating` gives no cover. |
| 14 | Shell ends while inside a Grouper's mouth zone | The turtle is eaten when `Untucking` begins. |
| 15 | A bite lands on a Plated creature that is also Spiny | The tier test with Spiny runs first. Plates are spent only if the bite would still succeed. |
| 16 | A Plated creature is revived | The plates stay as they were: cracked if already used. |
| 17 | The fifth trait prey is eaten with all slots full | Mass only, no pip. The trait stays at 4 pips. |
| 18 | Two traits finish on the same tick with one free slot | Eats are processed in order. The first takes the slot. The second eat finds the slots full and gives no pip. |
| 19 | A trait is shed and its prey is eaten again | Pips restart from 0. |
| 20 | A hook or vent drops a tier 4 creature to tier 3 | Tier-down with the mesh swap back to juvenile (section 5.2). |
| 21 | A vent burns mass to 0 | The creature stays alive at tier 1. Vents never gulp. |
| 22 | A hooked tier 1 or 2 creature falls back at the surface | Protected until 1.0 s after re-entry. After that the Gull's 2.0 s linger timer starts from zero. |
| 23 | Dashing into the own cove mouth | The bank triggers and the dash ends. |
| 24 | Bumped toward another player's cove | Tier 2 or higher bounces off the membrane. Nobody can be pushed inside. |
| 25 | A non-eel is bumped into an eel hole mouth | It bounces off. The hole is solid to it. |
| 26 | Old Scar or another predator reaches an eel in transit | The eel cannot be targeted. The predator loses it and gives up. |
| 27 | A predator chases a player who breaches | Predators stay in the water. The chase timer keeps running. Only a Gull can take an airborne creature. |
| 28 | Two airborne players collide | Normal bite and bump rules. |
| 29 | Disconnect during the full-cove choice | The new creature is saved as `pendingSpecimen`; the panel reopens on the next join. |
| 30 | Disconnect at the instant of being gulped | The gulp stands. Scraps are paid. |
| 31 | The eater disconnects right after a gulp | The victim's gulp card shows normally. The camera holds its last position. |
| 32 | A revive is bought but the server closes before it applies | The player gets a Revive Token (section 12.3). |
| 33 | The gulp card is left open with no input | It waits. There is no timer on the card or the revive offer (canon 5.5). The AFK rules apply (section 16.3); a disconnect pays scraps. |
| 34 | Keen Nose is bought mid-run with a trait at 4 pips | The trait is granted at once if a slot is free. |
| 35 | Two players buy Call the Tide at the same moment | Both get a Tide Token. Tokens start one at a time in the order bought: the receipt processed first starts after its 10 s warning (or is first in the queue), and the other is held and starts after its own 10 s warning in the next `Calm` phase, when no tide is running (section 14.7). |
| 36 | A tide event starts during a bank sequence | The banner waits for the results card to close. The rules apply from T+0 regardless. |
| 37 | Joining 5 s before an event ends | Treated as joining mid-event. The player sees the last 5 s. |
| 38 | The daily reset happens mid-run | New goals are given at once. Progress for them counts from that moment. |
| 39 | Mass is exactly on a tier threshold | The tier is reached (≥). |
| 40 | One eat crosses two thresholds | One tier-up sequence to the final tier. The Codex stamps both. |
| 41 | A tier 7 creature keeps eating | Mass keeps rising with no limit. Tier stays 7. |
| 42 | A camouflaged creature is touched by a legal eater | It is eaten. Camo hides; it does not protect. |
| 43 | A player stands in its own ink cloud | Hidden from players outside and from predators. Its camo timer runs normally. |
| 44 | A Moonlit creature pulls prey that another player is chasing | Allowed. Both the pull and the flee apply. |
| 45 | A player returns to its cove with mass under 1 | No bank. The run is cancelled silently. |
| 46 | A player tries to change species mid-run | Not possible. Species changes only in state `InCove`. |
| 47 | The pinned showcase specimen is released | The plaque returns to the default best specimen. |
| 48 | A wild creature and a player bite the same prey | The player wins. |
| 49 | A Shark Pup's third eat in 4 s is rejected by the server | The Rampage and the chain step are rolled back. |
| 50 | The creature is stuck in terrain for 3 s | Moved to the newest free point on its trail (section 1.6). |

---

## 19. Proposed canon changes

Canon values are used as written throughout this chapter. The canon has adopted every proposal from this chapter; none is open. The last one is kept below for the record.

| # | Canon section | Issue | Suggestion | Status |
|---|---|---|---|---|
| 1 | 7, `shark` | Starting at tier 2 removes the Shark Pup's tier 1 immunity from players. | Keep it, and note it in the canon as an intended drawback. | **Closed: adopted.** Canon 7 now says the tier 2 start is the species' drawback: it never has the tier 1 protection from other players (section 7.7). |
