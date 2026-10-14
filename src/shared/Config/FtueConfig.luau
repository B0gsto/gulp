--!strict
-- FtueConfig: every tunable of the first-time experience in one table (docs/04, section 3.1:
-- "All tunables live in one config module"; checklist A4 of 04 §12; task S6-C7). Its place,
-- `shared/Config`, is set by docs/09, section 3. Logic/FtueRules reads its numbers only from a
-- table of this shape passed in, so changing a value here changes the script with no other edit.
--
-- Clocks (04, short names): J is seconds since `PlayerAdded`; T is seconds since control. Every
-- distance is in studs, every speed in studs per second, every time in seconds unless named.
-- Values marked (tune) in chapter 04 are first guesses; S7-D1 retunes them from recordings.
-- Not here: canon values the game already reads elsewhere (tier masses, the Barracuda's 6 s,
-- 3 Pearls per mass, the 50% scraps rate, the Home Current's +60%), which chapter 04 only quotes.
-- Tables only and frozen, so it runs in Lune.

export type Arms = {
	chaseMode: string,
	homeMode: string,
	cliffhanger: string,
	traitCount: number,
	firstTrait: string,
	promptWords: string,
	hatchIntro: string,
	firstTick: string,
	run2AimAssist: string,
	loadingToy: string,
}

local function freeze<T>(t: T): T
	-- Safe cast: only tables are passed; nested tables are frozen first.
	local tbl = t :: any
	for _, v in tbl do
		if type(v) == "table" and not table.isfrozen(v) then
			freeze(v)
		end
	end
	table.freeze(tbl)
	return t
end

local FtueConfig = freeze({
	-- 04 §2.1: load phases and budgets, reference phone.
	load = {
		screenWithin = 0.5, -- 04 §2.1 phase B: our loading screen's first frame (L1)
		profileMedian = 1.5, -- 04 §2.1 phase C
		profileP90 = 4, -- 04 §2.1 phase C
		streamMedian = 3, -- 04 §2.1 phase D
		streamP90 = 8, -- 04 §2.1 phase D
		controlMedian = 5, -- 04 §2.1, §1.2: J at T = 0, median (tune)
		controlP90 = 10, -- 04 §2.1, §1.2: J at T = 0, 90% (tune)
		-- 04 §2.4: the slow-load ladder, on J.
		partialAt = 8, -- 04 §2.4: start with flat colours (`load_partial`)
		minimalAt = 15, -- 04 §2.4: Minnow mesh and krill only, no hatch animation (`load_minimal`)
		profileDimAt = 20, -- 04 §2.4: the bubble row dims to pale grey
		slowIconAt = 30, -- 04 §2.4: spinner with the weak-signal icon
		profileFailAt = 45, -- 04 §2.4: chapter 09's profile-failure rule
	},
	-- 04 §2.2: the loading toy.
	loadingToy = {
		logoWidth = 0.30, -- 04 §2.2: logo at 30% of screen width
		growPerDot = 0.03, -- 04 §2.2: each dot makes the 2D Fry 3% bigger
		growMax = 0.60, -- 04 §2.2: up to +60%
		bubbles = 5, -- 04 §2.2: five bubbles, one per 20% of phase D
		musicFadeIn = 1.0, -- 04 §2.2: `MUS_Nursery` fades in over 1 s
		exitSplit = 0.4, -- 04 §2.2: the screen splits into bubbles in 0.4 s
	},
	-- 04 §2.3: what streams first, and the Nursery fog.
	streaming = {
		minimumRadius = 90, -- 04 §2.3: Nursery floor and walls within 90 studs of the hatch point
		minimumMegabytes = 4, -- 04 §2.3 (tune)
		minimumAssets = 25, -- 04 §2.3: assets in the preload list (tune)
		firstMinuteMegabytes = 8, -- 04 §2.3 (tune)
		firstMinuteBy = 40, -- 04 §2.3: the first-minute set loads during T = 0 to 40
		fogNear = 90, -- 04 §2.3: the view is 90 studs until T = 20
		fogFar = 160, -- 04 §2.3: then opens to 160 studs
		fogOpenAt = 20, -- 04 §2.3: at T = 20
		fogOpenSeconds = 3, -- 04 §2.3: over 3 s
	},
	-- 04 §3.6 B1, §2.1 phase E, §9: the hatch.
	hatch = {
		seconds = 1.5, -- 04 §3.6 B1, §2.1 E: control at 1.5 s
		skipAfter = 0.4, -- 04 §3.6 B1: any touch after 0.4 s gives control at once
		fastSeconds = 0.6, -- 04 §9: the fast form's 0.6 s hatch
		cameraStart = 8, -- 04 §3.6 B1: camera starts 8 studs from the egg
		cameraFollow = 14, -- 04 §3.6 B1: the tier 1 follow distance (chapter 02 §3.1 owns it) (tune)
		-- The director's opening camera (14 §5.1, task S6-C2): behind the egg and to its side, low.
		cameraYaw = 35, -- degrees off the egg's back, toward the Fry's right (tune)
		cameraHeight = 0.5, -- studs above the egg's centre (tune)
		-- The staging of `M_Prop_HatchEgg` and `A_Fish_Hatch` (14 §5.1, tasks S6-A2 and S6-C2), on
		-- the clip's frames at 30 fps. The egg's base is `fryAhead` behind the Fry's model and
		-- `fryUp` below it; the clip carries the body out, the code never moves the model.
		egg = {
			width = 2.6, -- 07 §2.0: 2.6 across ...
			height = 3.3, -- ... and 3.3 tall (tune)
			lean = 4, -- degrees, leaning to its left
			split = 2.1, -- studs up from the base where the two halves part (tune)
			fryAhead = 3.0, -- 07 §2.1: the Fry's model 3.0 ahead of the egg's base ...
			fryUp = 2.6, -- ... and 2.6 up (tune)
			-- studs: a Fry that moved this far during the hatch was teleported (the Hatch Bed's
			-- teleport can land after the hatch cue): the director stages the egg again (14 §5.1)
			restage = 1.0,
			fps = 30, -- 07 §2.1: the clip's 45 frames at 30 fps
			frames = 45,
			rollRadius = 1.42, -- the round base it rocks on
			squashTall = 0.86, -- each rock after a squash to 86% tall ...
			squashWide = 1.07, -- ... and 107% wide
			squashLead = 2.5, -- frames from the deepest squash to the rock's peak (tune)
			rocks = { { 5, 15 }, { 12, -18 } }, -- frame of the peak, degrees (+ to its right)
			rockRise = 2, -- frames from upright to the peak (tune)
			rockFall = 3, -- frames from the peak back to upright (tune)
			crackFrame = 8, -- the whole egg swaps for its two closed halves
			lift = 0.15, -- studs the top lifts between the crack and the flip (tune)
			flipFrame = 15, -- the top flips open backwards about its back edge ...
			openFrame = 18, -- ... to `openAngle` by here
			openAngle = -118, -- degrees
			landFrame = 26, -- one gravity arc, landing open side up ...
			landLeft = 0.9, -- ... this far to the Fry's left ...
			landBehind = 2.9, -- ... and this far behind the egg's base
			arc = 1.2, -- studs the arc rises above the straight line at its middle (tune)
			turn = 50, -- degrees it turns on its axis in flight
			restFrame = 40, -- it rolls on its round tip to rest by here
			landRock = 20, -- degrees of the first roll after landing (tune)
			bottomRock = 5, -- degrees: the bottom springs and rocks once, at `openFrame`
			placeholderColour = "F2ECDC", -- 07 §16: the stand-in's flat pale shell until the mesh is in
		},
	},
	-- 04 §3.5: the Nursery distances along the path, from the hatch point (tune).
	layout = {
		swarmA = 14, -- 04 §3.5: Swarm A
		swarmAWidth = 6, -- 04 §3.5: a ball 6 studs wide
		trailFrom = 20, -- 04 §3.5: the plankton trail runs from 20 ...
		trailTo = 56, -- 04 §3.5: ... to 56 studs
		swarmB = 60, -- 04 §3.5: Swarm B
		grotto = 90, -- 04 §3.5: the Glow Grotto
		gap = 135, -- 04 §3.5: the Gap (Little Arch)
		gapWidth = 50, -- 04 §3.5
		gapTunnel = 25, -- 04 §3.5: a 25-stud tunnel
		channelEnd = 335, -- 04 §3.5: the channel runs 135 to 335; the Home Current mouth
		channelWidth = 36, -- 04 §3.5
		channelBend = 40, -- 04 §3.5: one bend of about 40 degrees at its midpoint
	},
	-- 04 §3.5, §3.6 B2 and B3: the scripted krill and plankton of run 1.
	feed = {
		swarmACount = 6, -- 04 §3.5: 6 krill in Swarm A
		trailMotes = 10, -- 04 §3.5: 10 motes
		trailSpacing = 4, -- 04 §3.5, §3.2: one every 4 studs
		swarmBCount = 14, -- 04 §3.5: 14 krill in Swarm B
		driftRadius = 25, -- 04 §3.6 B3, §4: inside 25 studs scripted krill drift toward the player
		driftSpeed = 6, -- 04 §3.6 B3, §4: at 6 studs/s, and never scatter
		keepCount = 8, -- 04 §3.6 B3: at least 8 scripted krill ...
		keepRadius = 40, -- 04 §3.6 B3: ... within 40 studs until S5
		massStep = 5, -- 04 §3.4 and 10 §3.1: onboarding step 06 and the music's pluck layer at mass 5
		feedAfterIdle = 8, -- 04 §3.6 B3: no input for 8 s, the nearest krill swims into the mouth
	},
	-- 04 §3.6 B2: the first-bite fail-safes.
	firstBite = {
		assistAt = 2.5, -- 04 §3.6 B2: T = 2.5 with no bite, Swarm A drifts toward the Fry ...
		assistSpeed = 6, -- 04 §3.6 B2: ... at 6 studs/s, so a krill reaches the mouth by T = 5
		biteBy = 5, -- 04 §3.6 B2, §12 S2: the bite every tester gets by T = 5
		followSpeed = 6, -- 04 §3.6 B2: swimming away, the swarm follows at 6 studs/s ...
		followLimit = 60, -- 04 §3.6 B2: ... up to 60 studs from the hatch point
		tapsForReplay = 3, -- 04 §3.6 B2: three taps without a drag replay the ghost thumb, longer
		gulpPulse = 0.15, -- 04 §3.6 B2: the 0.15 s gulp pulse ...
		gulpScale = 1.12, -- 04 §3.6 B2: ... to 1.12x and back
		massBarStart = 0.10, -- 04 §3.6 B2: the mass bar appears already 10% full
		pitchWindow = 1.5, -- 04 §3.6 B2: a bite within 1.5 s of the last plays a semitone higher
		pitchMax = 7, -- 04 §3.6 B2: up to +7 semitones
	},
	-- 04 §3.6 B4: tier up.
	grow = {
		homingAt = 30, -- 04 §3.6 B4: T = 30 below tier 2 (`grow_homing`) ...
		homingRadius = 30, -- 04 §3.6 B4: ... every krill within 30 studs ...
		homingSpeed = 14, -- 04 §3.6 B4: ... homes on the mouth at 14 studs/s
		burstAt = 40, -- 04 §3.6 B4: T = 40 below tier 2 (`grow_burst`) ...
		burstCount = 10, -- 04 §3.6 B4: ... ten krill spawn ...
		burstAhead = 8, -- 04 §3.6 B4: ... 8 studs ahead and swim into the mouth
		needInputWithin = 10, -- 04 §3.6 B4: both need input in the last 10 s
		dashButtonDelay = 1.0, -- 04 §3.6 B4, §3.8: the dash button 1.0 s after the tier-up banner
		swellSeconds = 0.6, -- 04 §3.6 B4: the 0.6 s swell (chapter 02 §5.1)
		swellOvershoot = 1.12, -- 04 §3.6 B4: overshoots to 112% of the new scale
		cameraFollow = 17, -- 04 §3.6 B4: follow distance 14 → 17 studs (tune)
		cameraSeconds = 0.6, -- 04 §3.6 B4: over 0.6 s (tune)
		hitStop = 0.10, -- 04 §3.6 B4: the Fry's own animation freezes for 0.10 s
	},
	-- 04 §3.6 B5: the first trait.
	trait = {
		glowfryDelay = 1.0, -- 04 §3.6 B5, §12 S8: five Glowfry 1.0 s after the tier-up banner
		speed = 8, -- 04 §3.6 B5, §4: Glowfry swim at 8 studs/s ...
		circleRadius = 12, -- 04 §3.6 B5: ... and circle within 12 studs of the player
		homingAfter = 15, -- 04 §3.6 B5: 15 s in the stage with fewer than five eaten ...
		homingSpeed = 14, -- 04 §3.6 B5: ... the rest home on the mouth at 14 studs/s
		fastHomingAt = 50, -- 04 §3.6 B5: T = 50 (`trait_homing`) ...
		fastHomingSpeed = 20, -- 04 §3.6 B5: ... they home at 20 studs/s
		traitBy = 55, -- 04 §3.6 B5, §12 S13: so the trait arrives by T = 55
		moveOnAt = 70, -- 04 §3.1, §3.6 B5: T = 70 without the trait, S5 starts anyway ...
		moveOnNeedInputWithin = 10, -- 04 §3.1: ... with input in the last 10 s
		dimPercent = 0.20, -- 04 §3.6 B5: the Nursery's ambient light drops 20% ...
		dimSeconds = 2, -- 04 §3.6 B5: ... for 2 s
		pushIn = 3, -- 04 §3.6 B5: a 0.5 s push-in of 3 studs on the fifth pip
		pushInSeconds = 0.5, -- 04 §3.6 B5
	},
	-- 04 §3.6 B6: call home.
	callHome = {
		curtainDelay = 2.5, -- 04 §3.6 B6, §12 S12: the curtain parts 2.5 s after the GLOW banner
		shadowDelay = 1.0, -- 04 §3.6 B6: one second later a shadow slides past beyond the Gap
		nudgeAfter = 8, -- 04 §3.6 B6: 8 s without moving toward the Gap, marker pulses
		lureAfter = 20, -- 04 §3.6 B6: 20 s, a krill swarm drifts along the trail (`home_lure`)
		pushAfter = 40, -- 04 §3.6 B6: 40 s, a Nursery current pushes toward the Gap (`home_push`) ...
		pushSpeed = 6, -- 04 §3.6 B6: ... at 6 studs/s
		fovFrom = 70, -- 04 §3.6 B6: field of view widens from 70 degrees ...
		fovTo = 76, -- 04 §3.6 B6: ... to 76 ...
		fovSeconds = 0.6, -- 04 §3.6 B6: ... in 0.6 s, then back
	},
	-- 04 §5.3 and §5.4: the scripted chase (B7).
	chase = {
		spawnBehind = 50, -- 04 §5.3: the Barracuda bursts out 50 studs behind ...
		spawnRight = 20, -- 04 §5.3: ... and 20 studs to the right
		lookBackYaw = 35, -- 04 §5.3, §3.6 B7: the camera yaws 35 degrees ...
		lookBackSeconds = 0.8, -- 04 §5.3: ... during 0.0 to 0.8 s
		promptAt = 0.3, -- 04 §5.3: the dash button pulses with DASH! at 0.3 s
		promptMax = 6, -- 04 §3.3: DASH! shows up to 6 s
		autoDashAfter = 1.5, -- 04 §5.4, §4: one automatic dash 1.5 s after the prompt (C6: 1.8 s)
		lunges = { 1.5, 3.5, 5.5 }, -- 04 §5.3, §12 C4: the three lunges
		lungeWarning = 0.4, -- 04 §5.3: red edge flash 0.4 s before each lunge
		lungeStop = 3, -- 04 §5.3: a lunge closes to 3 studs behind the tail
		fallBack = 14, -- 04 §5.3: then it falls back to 14 studs
		keepBehind = 12, -- 04 §3.6 B7: it keeps 12 studs behind
		minGap = 5, -- 04 §5.3: never closer than 5 studs except during a lunge
		giveUpAt = 6.0, -- 04 §5.3: it gives up at 6.0 s (canon: 6 s)
		fadeSeconds = 0.5, -- 04 §5.3: the red outline and edge glow fade over 0.5 s
		speedWindow = 0.5, -- 04 §5.3: the player's average speed over the last 0.5 s ...
		speedMin = 10, -- 04 §5.3: ... times a factor, clamped to 10 ...
		speedMax = 40, -- 04 §5.3: ... to 40 studs/s (tune)
		nearGap = 12, -- 04 §5.3: under 12 studs ...
		nearFactor = 0.90, -- 04 §5.3: ... factor 0.90
		midFactor = 1.00, -- 04 §5.3: 12 to 25 studs, 1.00
		farGap = 25, -- 04 §5.3: over 25 studs ...
		farFactor = 1.25, -- 04 §5.3: ... factor 1.25
		perfectDodge = 0.6, -- 04 §5.3: a dash in the 0.6 s before a snap sparkles
		fov = 78, -- 04 §3.6 B7: field of view 78 degrees for the chase
		shakeSeconds = 0.2, -- 04 §3.6 B7, §5.3: a 0.2 s shake on each snap
		shove = 20, -- 04 §5.4: the bow wave shoves a stopped player 20 studs along the trail
		shovesBeforeExtend = 2, -- 04 §5.4: after two shoves the Home Current reaches back
		fling = 20, -- 04 §5.4: swimming at it flings the player 20 studs down the trail ...
		flingSeconds = 0.4, -- 04 §5.4: ... with a 0.4 s impulse
		stuckSpeed = 5, -- 04 §5.4: under 5 studs/s ...
		stuckSeconds = 1, -- 04 §5.4: ... for 1 s counts as stopping
		circleSeconds = 4, -- 04 §5.4: on a retreat it circles outside the Gap for 4 s
		retreatPulseAfter = 5, -- 04 §5.4: after 5 s back in the Nursery the trail pulses
		maxRuns = 2, -- 04 §5.4: the second exit runs the chase again, the third has no predator
		fastMaxRuns = 1, -- 04 §9: the fast form has one chase attempt at most
		reachCurrentBy = 8.0, -- 04 §5.3: the player reaches the Home Current mouth by 6.0 to 8.0 s
	},
	-- 04 §3.6 B8 and §5.5: the Home Current.
	current = {
		endShort = 30, -- 04 §3.6 B8, §12 B1: it ends 30 studs short of the cove mouth
		reformAfter = 10, -- 04 §3.6 B8: 10 s outside the current ...
		reformBeyond = 80, -- 04 §3.6 B8: ... and more than 80 studs from the cove re-forms it
		coveInSight = 120, -- 10 §3.1 step 12: within 120 studs of the own cove mouth
		fovFrom = 70, -- 04 §3.6 B8: field of view opens from 70 ...
		fovTo = 80, -- 04 §3.6 B8: ... to 80 degrees for the ride ...
		fovReturn = 2, -- 04 §3.6 B8: ... and returns over the last 2 s
		followExtra = 4, -- 04 §3.6 B8: follow distance +4 studs
		maxRoute = 450, -- 04 §5.5: route from the current mouth to the cove, at most (tune)
		rideSeconds = 10, -- 04 §5.5: about a 10 s ride
		longRoute = 600, -- 04 §5.5: past 600 studs the current speeds up ...
		longRideSeconds = 12, -- 04 §5.5, §12 B3: ... so the ride takes 12 s
		returnerSearch = 20, -- 04 §5.5: a returner gets the farthest free cove of the nearest 20 ...
		keepFreeNearest = 4, -- 04 §5.5: ... so the four nearest stay free for newcomers (tune)
	},
	-- 04 §3.6 B9 and §6.1: the first bank, on seconds since the cove mouth was crossed.
	bank = {
		pullAfter = 12, -- 04 §3.6 B9: 12 s within 60 studs of the cove mouth without entering ...
		pullRadius = 60, -- 04 §3.6 B9
		pullSpeed = 8, -- 04 §3.6 B9: ... a slow current pulls toward the mouth at 8 studs/s
		flashSeconds = 0.15, -- 04 §6.1: white flash
		stampSeconds = 0.8, -- 04 §6.1, §3.3: BANKED for 0.8 s
		counterAt = 0.3, -- 04 §6.1: the mass bar empties into the Pearl counter
		orbitAt = 0.8, -- 04 §6.1: the camera orbits the cove ...
		orbitSeconds = 2.5, -- 04 §6.1, §3.6 B9: ... for 2.5 s
		touchEndsOrbitAt = 1.3, -- 04 §6.1, §12 B6: from here any touch ends the orbit
		fryAt = 3.3, -- 04 §6.1: a new Fry hatches on the Home Stone
		controlBy = 3.5, -- 04 §1.4, §6.1: control returns 3.5 s at the latest
		firstTickAt = 6.3, -- 04 §6.1: the first income tick, 3 s after placement
		speciesAt = 8.3, -- 04 §6.1: cliffhanger 1, the Pufferfish silhouette
		tideAt = 10.3, -- 04 §6.1: cliffhanger 2, the tide clock
		mouthAt = 12.3, -- 04 §6.1: the cove mouth pulses and a bubble trail leads out
		pingGap = 4, -- 04 §6.1: left early, the rest fire 4 s apart as HUD pings
		speciesPrice = 500, -- 04 §6.1: the ring reads Pearls owned / 500 (the Pufferfish's price)
		tideFarMinutes = 10, -- 04 §6.4: a countdown over 10 minutes ...
		tideShortPing = 0.6, -- 04 §6.4: ... shortens the tide clock ping to 0.6 s ...
		ringHoldExtra = 1, -- 04 §6.4: ... and holds the Pufferfish ring 1 s longer
	},
	-- 04 §3.6 B12: the cove after the first bank, on seconds since the tide clock appeared.
	cove = {
		exitNudgeAfter = 20, -- 04 §3.6 B12: 20 s in the cove, the mouth pulses, a trail leads out
		exitLureAfter = 40, -- 04 §3.6 B12: 40 s, a krill swarm drifts past the mouth
	},
	-- 04 §3.6 B12 and B13, §3.8, §4: run 2.
	run2 = {
		goalsChipDelay = 5, -- 04 §3.6 B12, §3.8: the goals chip 5 s into run 2
		denseCount = 12, -- 04 §3.6 B12: at least 12 krill ...
		denseRadius = 50, -- 04 §3.6 B12: ... within 50 studs ...
		denseSeconds = 30, -- 04 §3.6 B12: ... for the first 30 s of the run
		exitTrail = 40, -- 04 §3.6 B12: a bubble trail for the first 40 studs only
		musicFade = 2, -- 04 §3.6 B12: `MUS_Reef` fades in over 2 s
		homingAt = 30, -- 04 §3.6 B13: 30 s into run 2 (`run2_homing`) ...
		homingBelow = 5, -- 04 §3.6 B13: ... with mass under 5 ...
		homingRadius = 30, -- 04 §3.6 B13: ... krill within 30 studs ...
		homingSpeed = 4, -- 04 §3.6 B13: ... drift toward the player at 4 studs/s ...
		homingUntil = 10, -- 04 §3.6 B13: ... until mass reaches 10
	},
	-- 04 §3.7: idle and absence, and 04 §9's fast form.
	idle = {
		ghostAfter = 4, -- 04 §3.7: no input for 4 s (S2 to S5), the ghost thumb returns
		pulseAfter = 8, -- 04 §3.7: 8 s, the beat's target pulses and its fail-safe starts early
		holdAfter = 20, -- 04 §3.7, §12 S14: 20 s, hold: beat timers freeze (`afk_hold`)
		holdHighGain = -30, -- dB: the hold's low-pass on the music, the treble band (14 §5.1) (tune)
		holdMidGain = -10, -- dB: and the middle band (tune)
		fastScale = 0.5, -- 04 §9: the fast form halves every idle timer
	},
	-- 04 §3.2, §1.4, §3.3: prompts.
	prompts = {
		ghostLoop = 1.6, -- 04 §3.2: the ghost thumb loops every 1.6 s
		ghostHideDrag = 0.2, -- 04 §3.6 B2: it hides on the first drag of 0.2 s or more
		outlineThicken = 0.30, -- 04 §3.2, §4: the food outline is 30% thicker in the FTUE (tune)
		homeTrailSpacing = 6, -- 04 §3.2: the bubble trail, one bubble every 6 studs
		dashPulseScale = 1.3, -- 04 §3.2: the dash button swells to 1.3x ...
		dashPulseRate = 2, -- 04 §3.2: ... and back twice a second
		bannerSeconds = 1.5, -- 04 §3.3: NIBBLER and GLOW show for 1.5 s
		wordLetters = 8, -- 04 §1.4: a prompt word has at most 8 letters
		newElementGap = 4, -- 04 §1.4: one new interface element at a time, at least 4 s apart
		gearOpacity = 0.40, -- 04 §3.8: the settings gear at 40% opacity
		controlsHintSeconds = 5, -- 04 §9: a controls hint for a new input type shows for 5 s
	},
	-- 04 §4: first-run assists. The standard values belong to the controls chapter.
	assists = {
		run1Pull = 0.60, -- 04 §4: heading bends up to 60% toward green prey ...
		run1Cone = 35, -- 04 §4: ... inside a 35 degree half-angle cone ...
		run1Range = 30, -- 04 §4: ... within 30 studs
		run2Pull = 0.40, -- 04 §4: run 2 value
		run1Mouth = 1.6, -- 04 §4: mouth zone radius x1.6 in run 1 ...
		run2Mouth = 1.3, -- 04 §4: ... x1.3 in run 2
		shieldSeconds = 240, -- 04 §4: the first-run shield ends after 240 s of play time (tune)
		shieldFlicker = 10, -- 04 §4: the bubble sheen flickers for the last 10 s
		predatorGrace = 45, -- 04 §4, §12 P4: no computer predator targets the newcomer for 45 s
		bubbleThrow = 30, -- 04 §4: the newcomer bubble throws the newcomer 30 studs clear ...
		bubbleProtect = 3, -- 04 §4: ... with 3 s of protection
	},
	-- 04 §9: returning players.
	returning = {
		fastFromAttempt = 1, -- 04 §9: the first restart before the first bank is the fast form
		shortFromAttempt = 2, -- 04 §9: from the second on, the short form
	},
	-- 04 §8: second session and day 2.
	session = {
		newSessionGap = 600, -- 04 §8: a join is a new session 10 minutes after the last ended (tune)
		sweepSeconds = 2, -- 04 §8.1 step 2: the camera sweep, 0 to 2 s
		cardAt = 2, -- 04 §8.1 step 3: the clam opens and the welcome-back card shows at 2 s
		streakDelay = 1, -- 04 §8.1 step 5 [L]: the streak card 1 s after collecting ...
		streakSeconds = 2.5, -- 04 §8.1 step 5 [L]: ... closes itself after 2.5 s
		goalsDelay = 1, -- 04 §8.1 step 6: the goals chip 1 s later
		leaveTarget = 12, -- 04 §8.1: collect and leave within 12 s of control (tune)
		cardMinAway = 600, -- 04 §8.1: away under 10 minutes, no card and no sweep
		cardMinPearls = 10, -- 04 §8.1: under 10 Pearls earned, no card
		starterPackSessions = 3, -- 04 §8.3 [L]: shown in the first three eligible sessions (tune)
		starterPackMinBanks = 2, -- 04 §8.3 [L]: at least 2 banks on the account
	},
	-- 04 §3.8: when the shop button may first appear.
	shop = {
		playSeconds = 360, -- 04 §3.8: second bank or 6 minutes of account play time (tune) ...
		notBeforeT = 120, -- 04 §3.8, §10 item 1: ... never before T = 120
	},
	-- The server's tutorial director (Services/TutorialService). Chapter 04 gives no rate; these
	-- are 14 §5.1's readings for task S6-C2.
	director = {
		tick = 0.1, -- s: the stage machine's tick (its timers are 0.4 s and longer)
		every = 1.0, -- s: the `keepKrill` top-up and the `moved` report toward the Gap (B3, B6)
		steerEvery = 1.0, -- s: the client's steering report while it lasts (FtuePlan.Code.STEER)
		stickDeadZone = 0.15, -- 02 §2.4: the left stick's radial dead zone; past it, steering
	},
	-- 04 §11: the control arm of each A/B test. The director passes a copy with the player's arm.
	arms = {
		chaseMode = "chase", -- 04 §11 test 1 `ftue_chase_mode`: "chase" or "escort"
		homeMode = "current", -- 04 §11 test 2 `ftue_home_mode`: "current" or "swim"
		cliffhanger = "species_tide", -- 04 §11 test 3 `ftue_cliffhanger`
		-- The director spawns as many Glowfry as TraitService needs pips for the player (5, or 4
		-- with Keen Nose), so the script cannot stall; this value is checked against it.
		traitCount = 5, -- 04 §3.6 B5, §11 test 4 `ftue_trait_count`: Glowfry to eat, 5 or 3
		firstTrait = "glow", -- 04 §3.6 B5, §11 test 5 `ftue_first_trait`: "glow" or "spots"
		promptWords = "one_word", -- 04 §11 test 6 `ftue_prompt_words`: or "icons_only"
		hatchIntro = "hatch", -- 04 §11 test 7 `ftue_hatch_intro`: or "instant"
		firstTick = "advance", -- 04 §11 test 8 `ftue_first_tick`: or "none"
		run2AimAssist = "step_down", -- 04 §11 test 10 `run2_aim_assist`: or "full", "off"
		loadingToy = "toy", -- 04 §11 test 11 `ftue_loading_toy`: or "static"
	} :: Arms,
})

export type Config = typeof(FtueConfig)

return FtueConfig
