--!strict
-- FtuePresent: the pure helpers of the client's TutorialDirector (task S6-C2; docs/04, sections
-- 1.4, 3.2, 3.6 B1 to B5, 3.7 and 3.8; docs/09, sections 5.2 and 5.3; chapter 14, section 5.1 for
-- the hatch's staging). Controllers/TutorialDirector reads them; tests/unit/Logic/FtuePresent
-- checks them. Every number comes from the config table passed in (Config/FtueConfig's shape).
--
--   newCues, accept        the `ftue.cue` batches: a batch plays only when its `seq` is above the
--                          last one played (TutorialService's header)
--   inFtue                 whether the first-run presentation applies (run 1 and run 2: the
--                          thicker outline of 04 §4 and the 1.5 s banners of 04 §3.3)
--   newInput, press,       the `TutorialStep` input reports: a tap, or a steering input (a drag
--   release, sense         of 0.2 s or more, a movement key, a stick), again at most once a
--                          `director.steerEvery` while it lasts (FtuePlan.Code)
--   stickSteers            the left stick out of its dead zone (02 §2.4) is steering
--   newOutbox, post, flush the reports that must arrive (101, 104): kept while the rate limit
--                          holds them back and sent again next frame, in order
--   newReveals, reveal,    04 §3.8's first appearances, at most one new element every
--   due, revealNow, HUD_OF `prompts.newElementGap` seconds (04 §1.4), the one needed at once (B5:
--                          the trait arrives before slot 1's turn), and the HUD IDs of each
--   eggPose                the egg at a frame of the hatch clip (14 §5.1), in the egg's frame:
--                          r to the Fry's right, u up, f toward the Fry, from the egg's base
--   ease, dimAt, pushAt    the hatch camera's blend; B5's ambient dip and camera push-in
--   dipBase                the light the dip darkens: its own base, or the tide's new value
-- Numbers and tables only, so it runs in Lune.

local FtueConfig = require("../Config/FtueConfig")
local FtuePlan = require("./FtuePlan")
local FtueRules = require("./FtueRules")

type Config = FtueConfig.Config
type Action = FtueRules.Action

local C = FtuePlan.Code
local S = FtueRules.Stage

local FtuePresent = {}

-- Cues ------------------------------------------------------------------------------------------

export type Cues = { last: number, played: number }

function FtuePresent.newCues(): Cues
	return { last = 0, played = 0 }
end

--- The actions of an `ftue.cue` value to play now, in order, or nil when it is malformed or not
--- newer than the last batch played. `first` is true for the first batch this client plays.
function FtuePresent.accept(c: Cues, value: unknown): ({ Action }?, boolean)
	if type(value) ~= "table" then
		return nil, false
	end
	local v = value :: { [any]: any }
	local seq, actions = v.seq, v.actions
	if type(seq) ~= "number" or type(actions) ~= "table" or seq <= c.last then
		return nil, false
	end
	c.last = seq
	c.played += 1
	local out: { Action } = {}
	for _, a in actions :: { any } do
		if type(a) == "table" and type(a.kind) == "string" then
			table.insert(out, a :: Action)
		end
	end
	return out, c.played == 1
end

--- Whether the first-run presentation applies: from the start of the script to the end of run 2
--- (04 §4: the thicker outline ends when run 2 ends; 04 §3.3: NIBBLER in run 1 and run 2). An
--- account that has banked is in it only at S9 or S10 (TutorialService keeps those stages).
function FtuePresent.inFtue(stage: number?, completed: boolean?): boolean
	if completed == true then
		return stage == S.S9_COVE or stage == S.S10_RUN2
	end
	return stage ~= S.DONE
end

-- Input reports ---------------------------------------------------------------------------------

export type Input = { downAt: number?, lastSteer: number }

function FtuePresent.newInput(): Input
	return { downAt = nil, lastSteer = -math.huge }
end

--- A touch or mouse button went down at `now`.
function FtuePresent.press(s: Input, now: number)
	s.downAt = now
end

--- It came up: `TAP` when it was shorter than a drag (04 §3.6 B2: 0.2 s), else nil.
function FtuePresent.release(cfg: Config, s: Input, now: number): number?
	local at = s.downAt
	s.downAt = nil
	if at and now - at < cfg.prompts.ghostHideDrag then
		return C.TAP
	end
	return nil
end

--- Once a frame: `STEER` when the player is steering (a press held as a drag, or `held`: a
--- movement key or a stick this frame) and the last report is `director.steerEvery` old.
function FtuePresent.sense(cfg: Config, s: Input, now: number, held: boolean): number?
	local at = s.downAt
	local dragging = at ~= nil and now - at >= cfg.prompts.ghostHideDrag
	if (held or dragging) and now - s.lastSteer >= cfg.director.steerEvery then
		s.lastSteer = now
		return C.STEER
	end
	return nil
end

--- The left stick at (x, y), each -1 to 1, steers once it is past `director.stickDeadZone`.
function FtuePresent.stickSteers(cfg: Config, x: number, y: number): boolean
	return math.sqrt(x * x + y * y) > cfg.director.stickDeadZone
end

export type Outbox = { codes: { number } }

function FtuePresent.newOutbox(): Outbox
	return { codes = {} }
end

--- Queues report `code` to be sent (after any still waiting).
function FtuePresent.post(o: Outbox, code: number)
	table.insert(o.codes, code)
end

--- Sends the waiting reports in order through `send` until it refuses one (it returns false: the
--- rate limit); that one and the rest wait for the next call. Returns how many went.
function FtuePresent.flush(o: Outbox, send: (number) -> boolean): number
	local sent = 0
	while o.codes[1] ~= nil do
		if not send(o.codes[1]) then
			break
		end
		table.remove(o.codes, 1)
		sent += 1
	end
	return sent
end

-- First appearances (04 §3.8, §1.4) -------------------------------------------------------------

--- The HUD IDs (08 §3.3) each `hud` cue reveals. The mass pops belong to the mass bar.
FtuePresent.HUD_OF = table.freeze({
	massBar = { "HUD.MassBar", "HUD.MassPops" },
	dashButton = { "HUD.Dash" },
	traitSlot = { "HUD.Traits" },
	homeMarker = { "HUD.Home" },
	goalsChip = {}, -- TODO(S7): the goals chip is not built yet
} :: { [string]: { string } })

--- Every HUD ID the script hides until its cue.
FtuePresent.HIDDEN =
	table.freeze({ "HUD.MassBar", "HUD.MassPops", "HUD.Dash", "HUD.Traits", "HUD.Home" })

export type Reveals = { shown: { [string]: boolean }, queue: { string }, lastAt: number }

function FtuePresent.newReveals(): Reveals
	return { shown = {}, queue = {}, lastAt = -math.huge }
end

--- Asks for element `id` (a `hud` cue). `now` set: it shows at once (a rejoin's batch puts back
--- what the player already saw, so it is not new), else it waits its turn in `due`.
function FtuePresent.reveal(r: Reveals, id: string, now: number?)
	if r.shown[id] or table.find(r.queue, id) then
		return
	end
	if now then
		r.shown[id] = true
		r.lastAt = now
	else
		table.insert(r.queue, id)
	end
end

--- The next element to show at `now`, or nil: one at a time, `prompts.newElementGap` apart.
function FtuePresent.due(cfg: Config, r: Reveals, now: number): string?
	local id = r.queue[1]
	if id == nil or now - r.lastAt < cfg.prompts.newElementGap then
		return nil
	end
	table.remove(r.queue, 1)
	r.shown[id] = true
	r.lastAt = now
	return id
end

--- Element `id`, still waiting its turn, is needed now (B5: the trait fills slot 1 before the
--- slot's turn came): it leaves the queue and counts as shown. True when it was waiting.
function FtuePresent.revealNow(r: Reveals, id: string, now: number): boolean
	local at = table.find(r.queue, id)
	if at == nil then
		return false
	end
	table.remove(r.queue, at)
	r.shown[id] = true
	r.lastAt = now
	return true
end

-- The hatch (14 §5.1) ---------------------------------------------------------------------------

local function smooth(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

--- 0 to 1 over the hatch: the camera's blend from the egg to the follow pose (04 §3.6 B1).
function FtuePresent.ease(u: number): number
	return smooth(u)
end

-- A rock of `deg` peaking at frame `peak`: up over `rise` frames, back over `fall`.
local function bump(f: number, peak: number, deg: number, rise: number, fall: number): number
	if f >= peak - rise and f <= peak then
		return deg * smooth((f - (peak - rise)) / rise)
	elseif f > peak and f <= peak + fall then
		return deg * (1 - smooth((f - peak) / fall))
	end
	return 0
end

export type EggPose = {
	whole: boolean, -- the whole egg; false: the two halves
	roll: number, -- degrees, + to its right, on the round base (the lean included)
	tall: number, -- squash of the whole egg: height and width factors
	wide: number,
	lift: number, -- studs the top has lifted off the bottom
	open: number, -- degrees the top has turned about its back edge (negative: backwards)
	free: boolean, -- the top flies or lies on the bed: its pose is `top*`
	topR: number, -- its centre, from the egg's base
	topU: number,
	topF: number,
	topPitch: number, -- degrees about the right axis (−180: open side up)
	topYaw: number, -- degrees about up
	topRock: number, -- degrees of its roll on the round tip after landing
	bottomRock: number, -- degrees of the bottom's one rock
}

--- The egg at clip frame `f` (fractional; 30 fps). Before the crack it is whole; then two halves,
--- closed, the top lifting; it flips open backwards about its back edge, flies one arc and lands
--- open side up, rocking to rest; the bottom rocks once and stays (14 §5.1).
function FtuePresent.eggPose(cfg: Config, f: number): EggPose
	local e = cfg.hatch.egg
	local roll = -e.lean
	local k = 0 -- the squash, 0 to 1
	for _, rock in e.rocks do
		local peak, deg = rock[1], rock[2]
		roll += bump(f, peak, deg, e.rockRise, e.rockFall)
		local from = peak - 2 * e.squashLead
		if f > from and f < peak then
			k = math.max(k, math.sin(math.pi * (f - from) / (2 * e.squashLead)))
		end
	end
	local pose: EggPose = {
		whole = f < e.crackFrame,
		roll = roll,
		tall = 1 - (1 - e.squashTall) * k,
		wide = 1 + (e.squashWide - 1) * k,
		lift = 0,
		open = 0,
		free = false,
		topR = 0,
		topU = 0,
		topF = 0,
		topPitch = 0,
		topYaw = 0,
		topRock = 0,
		bottomRock = bump(f, e.openFrame, e.bottomRock, e.rockRise, e.rockFall),
	}
	if f < e.crackFrame then
		return pose
	end
	pose.lift = e.lift * smooth((f - e.crackFrame) / (e.flipFrame - e.crackFrame))
	pose.open = e.openAngle * smooth((f - e.flipFrame) / (e.openFrame - e.flipFrame))
	if f < e.openFrame then
		return pose
	end
	-- Free: from the opened pose about the hinge to the bed, on one arc.
	local capHalf = (e.height - e.split) / 2
	local hingeU, hingeF = e.split + e.lift, -e.width / 2
	local a = math.rad(e.openAngle)
	-- The cap's centre sits `capHalf` up and `width / 2` toward the Fry from the hinge; turning by
	-- θ toward the Fry maps (f, u) to (f cos θ + u sin θ, u cos θ − f sin θ).
	local vf, vu = e.width / 2, capHalf
	local fromF = hingeF + vf * math.cos(a) + vu * math.sin(a)
	local fromU = hingeU + vu * math.cos(a) - vf * math.sin(a)
	local toR, toU, toF = -e.landLeft, capHalf, -e.landBehind
	local u = math.clamp((f - e.openFrame) / (e.landFrame - e.openFrame), 0, 1)
	pose.free = true
	pose.topR = toR * u
	pose.topU = fromU + (toU - fromU) * u + 4 * e.arc * u * (1 - u)
	pose.topF = fromF + (toF - fromF) * u
	pose.topPitch = e.openAngle + (-180 - e.openAngle) * u
	pose.topYaw = e.turn * u
	if f > e.landFrame then
		local v = math.clamp((f - e.landFrame) / (e.restFrame - e.landFrame), 0, 1)
		pose.topRock = e.landRock * (1 - v) * (1 - v) * math.sin(3 * math.pi * v)
	end
	return pose
end

--- The clip's length in seconds (07 §2.1: 45 frames at 30 fps).
function FtuePresent.clipSeconds(cfg: Config): number
	return cfg.hatch.egg.frames / cfg.hatch.egg.fps
end

--- 04 §3.6 B5: the share the Nursery's ambient light is down by, `t` seconds after the trait.
function FtuePresent.dimAt(cfg: Config, t: number): number
	local tr = cfg.trait
	if t < 0 or t > tr.dimSeconds then
		return 0
	end
	return tr.dimPercent * math.sin(math.pi * t / tr.dimSeconds)
end

--- The value B5's dip darkens this frame: `base` while the light still holds what the dip last
--- wrote (`same(current, written)`), else `current`: TideController set a new value, and the
--- dip goes on from it rather than from a stale snapshot. With no base yet, `current`.
function FtuePresent.dipBase<T>(base: T?, written: T?, current: T, same: (T, T) -> boolean): T
	if base ~= nil and written ~= nil and same(current, written) then
		return base
	end
	return current
end

--- 04 §3.6 B5: studs the camera has pushed in, `t` seconds after the fifth pip, in and back.
function FtuePresent.pushAt(cfg: Config, t: number): number
	local tr = cfg.trait
	if t < 0 or t > tr.pushInSeconds then
		return 0
	end
	return tr.pushIn * math.sin(math.pi * t / tr.pushInSeconds)
end

return FtuePresent
