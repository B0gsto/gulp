--!strict
local FtueConfig = require("../../../src/shared/Config/FtueConfig")
local FtueRules = require("../../../src/shared/Logic/FtueRules")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type Config = FtueRules.Config
type State = FtueRules.State
type Event = FtueRules.Event
type Action = FtueRules.Action

local S = FtueRules.Stage
local DT = 1 / 16 -- exact in binary, so summed ticks land on the thresholds

-- A writable deep copy of a frozen config.
local function clone<T>(t: T): T
	-- Safe cast: only called on config tables, whose values are numbers, strings or tables.
	local src = t :: any
	local out = {}
	for k, v in src do
		out[k] = if type(v) == "table" then clone(v) else v
	end
	return out :: any
end

-- Feeds events to the rules and keeps every action, with the T at which it came out.
type Run = {
	cfg: Config,
	s: State,
	log: { { a: Action, t: number } },
	send: (self: Run, e: Event) -> { Action },
	wait: (self: Run, seconds: number, hadInput: boolean?) -> { Action },
}

local function collect(run: Run, actions: { Action }): { Action }
	for _, a in actions do
		table.insert(run.log, { a = a, t = run.s.t })
	end
	return actions
end

local function newRun(cfg: Config?, join: FtueRules.Join?): Run
	local c = cfg or FtueConfig
	local s, first =
		FtueRules.new(c, join or { stage = 0, completed = false, attempts = 0, banked = false })
	local run: Run = {
		cfg = c,
		s = s,
		log = {},
		send = function(self: Run, e: Event): { Action }
			local s2, actions = FtueRules.handle(self.cfg, self.s, e)
			self.s = s2
			return collect(self, actions)
		end,
		wait = function(self: Run, seconds: number, hadInput: boolean?): { Action }
			local all: { Action } = {}
			local n = math.floor(seconds / DT + 0.5)
			for _ = 1, n do
				for _, a in self:send({ kind = "tick", dt = DT, hadInput = hadInput == true }) do
					table.insert(all, a)
				end
			end
			return all
		end,
	}
	collect(run, first)
	return run
end

local function find(actions: { Action }, kind: string, id: string?): Action?
	for _, a in actions do
		if a.kind == kind and (id == nil or a.id == id) then
			return a
		end
	end
	return nil
end

local function count(actions: { Action }, kind: string, id: string?): number
	local n = 0
	for _, a in actions do
		if a.kind == kind and (id == nil or a.id == id) then
			n += 1
		end
	end
	return n
end

-- The T at which the first matching action came out, or nil.
local function firstAt(run: Run, kind: string, field: string?, value: unknown?): number?
	for _, row in run.log do
		local a = row.a :: any -- Safe cast: reading one named field of an Action
		if a.kind == kind and (field == nil or a[field] == value) then
			return row.t
		end
	end
	return nil
end

local function steps(run: Run): { number }
	local out = {}
	for _, row in run.log do
		if row.a.kind == "step" then
			table.insert(out, row.a.step :: number)
		end
	end
	return out
end

-- Drives a fresh account to control (T = 0).
local function toControl(run: Run)
	run:send({ kind = "loadingDone" })
	run:wait(run.cfg.hatch.seconds)
	run:send({ kind = "controlGained" })
end

-- Drives an active player (input every tick) through S2 to S5.
local function toCallHome(run: Run)
	toControl(run)
	run:send({ kind = "touch", drag = true })
	run:wait(1, true)
	run:send({ kind = "preyEaten", group = "swarmA" })
	run:send({ kind = "massChanged", mass = 5 })
	run:wait(1, true)
	run:send({ kind = "massChanged", mass = 10 })
	run:send({ kind = "tierReached", tier = 2 })
	run:wait(2, true)
	for _ = 1, 5 do
		run:send({ kind = "preyEaten", group = "glowfry" })
	end
	run:send({ kind = "traitGained", trait = "glow" })
	run:wait(run.cfg.callHome.curtainDelay + 0.1, true)
end

describe("FtueRules (04 §3.1, §3.6, §3.7, §4, §9; 09 §12.2)", function()
	it("numbers the stages as the saved ftue.stage, S0 = 0 to DONE = 11", function()
		expect(S.S0_LOADING).toBe(0)
		expect(S.S5_CALL_HOME).toBe(5)
		expect(S.S10_RUN2).toBe(10)
		expect(S.DONE).toBe(11)
		expect(FtueRules.stageName(4)).toBe("S4_TRAIT")
	end)

	it("starts a fresh account in S0 and logs onboarding step 01", function()
		local run = newRun()
		expect(run.s.stage).toBe(S.S0_LOADING)
		expect(run.s.form).toBe("full")
		expect(steps(run)).toEqual({ 1 })
	end)

	it(
		"S0 → S1 on loadingDone: the hatch plays and Swarm A is already there (S1 of 04 §12)",
		function()
			local run = newRun()
			local a = run:send({ kind = "loadingDone" })
			expect(run.s.stage).toBe(S.S1_HATCH)
			expect((find(a, "hatch") :: Action).seconds).toBe(1.5)
			local swarm = find(a, "spawnSwarmA") :: Action
			expect(swarm.count).toBe(6)
			expect(swarm.distance).toBe(14)
		end
	)

	it("S1 gives control after 1.5 s, or on a touch after 0.4 s but not before", function()
		local run = newRun()
		run:send({ kind = "loadingDone" })
		run:wait(1.4)
		expect(firstAt(run, "giveControl")).toBe(nil)
		run:wait(0.1)
		expect(firstAt(run, "giveControl") ~= nil).toBe(true)

		local early = newRun()
		early:send({ kind = "loadingDone" })
		early:wait(0.3)
		expect(find(early:send({ kind = "touch", drag = false }), "giveControl")).toBe(nil)
		early:wait(0.2)
		expect(find(early:send({ kind = "touch", drag = false }), "giveControl") ~= nil).toBe(true)
	end)

	it("S1 → S2 on controlGained: T = 0, step 03, the ghost thumb shows", function()
		local run = newRun()
		run:send({ kind = "loadingDone" })
		run:wait(1.5)
		local a = run:send({ kind = "controlGained" })
		expect(run.s.stage).toBe(S.S2_FIRST_BITE)
		expect(run.s.t).toBe(0)
		expect(find(a, "step") and (find(a, "step") :: Action).step).toBe(3)
		expect((find(a, "prompt", "ghostThumb") :: Action).show).toBe(true)
	end)

	it("hides the ghost thumb on the first drag and logs step 04, then 05 on the bite", function()
		local run = newRun()
		toControl(run)
		local a = run:send({ kind = "touch", drag = true })
		expect((find(a, "prompt", "ghostThumb") :: Action).show).toBe(false)
		a = run:send({ kind = "preyEaten", group = "swarmA" })
		expect(run.s.stage).toBe(S.S3_GROW)
		expect(find(a, "hud", "massBar") ~= nil).toBe(true)
		expect(find(a, "biteAssist")).toBe(nil)
		expect(find(a, "spawnTrail") ~= nil).toBe(true)
		expect(find(a, "spawnSwarmB") ~= nil).toBe(true)
		expect(steps(run)).toEqual({ 1, 3, 4, 5 })
	end)

	it("replays a longer ghost thumb after three taps without a drag (04 §3.6 B2)", function()
		local run = newRun()
		toControl(run)
		run:send({ kind = "touch", drag = false })
		run:send({ kind = "touch", drag = false })
		local a = run:send({ kind = "touch", drag = false })
		expect((find(a, "prompt", "ghostThumb") :: Action).mode).toBe("long")
	end)

	it(
		"never touched: schedules the Swarm A assist at T = 2.5, which bites by T = 5 (S2)",
		function()
			local cfg = FtueConfig
			local run = newRun()
			toControl(run)
			run:wait(2.4)
			expect(firstAt(run, "homePrey", "id", "swarmA")).toBe(nil)
			run:wait(0.1)
			local at = firstAt(run, "homePrey", "id", "swarmA") :: number
			expect(at).toBeCloseTo(cfg.firstBite.assistAt, 1e-6)
			-- The nearest krill sits at the near edge of the ball; at the drift speed it reaches the
			-- mouth by T = 5.
			local reach = (cfg.layout.swarmA - cfg.layout.swarmAWidth / 2)
				/ cfg.firstBite.assistSpeed
			expect(at + reach <= cfg.firstBite.biteBy).toBe(true)
			-- The bite with no input is logged as the assist, and step 05 waits for the first input.
			local a = run:send({ kind = "preyEaten", group = "swarmA" })
			expect(find(a, "biteAssist") ~= nil).toBe(true)
			expect((find(a, "milestone", "bite") :: Action).t).toBeCloseTo(2.5, 1e-6)
			expect(find(a, "step")).toBe(nil)
			a = run:send({ kind = "touch", drag = true })
			expect(count(a, "step")).toBe(2) -- 04 then 05
		end
	)

	it("S3: mass 5 logs step 06 and the pluck layer; tier 2 enters S4", function()
		local run = newRun()
		toControl(run)
		run:send({ kind = "touch", drag = true })
		run:send({ kind = "preyEaten", group = "swarmA" })
		local a = run:send({ kind = "massChanged", mass = 4 })
		expect(find(a, "step")).toBe(nil)
		a = run:send({ kind = "massChanged", mass = 5 })
		expect((find(a, "step") :: Action).step).toBe(6)
		expect(find(a, "music", "pluck") ~= nil).toBe(true)
		a = run:send({ kind = "tierReached", tier = 2 })
		expect(run.s.stage).toBe(S.S4_TRAIT)
		expect((find(a, "step") :: Action).step).toBe(7)
		expect(find(a, "milestone", "tier2") ~= nil).toBe(true)
	end)

	it(
		"S3 fail-safes: grow_homing at T = 30 and grow_burst at T = 40, only with recent input",
		function()
			local run = newRun()
			toControl(run)
			run:send({ kind = "touch", drag = true })
			run:send({ kind = "preyEaten", group = "swarmA" })
			run:wait(29.8, true)
			expect(firstAt(run, "failsafe", "ctx", "grow_homing")).toBe(nil)
			run:wait(0.3, true)
			expect(firstAt(run, "failsafe", "ctx", "grow_homing") ~= nil).toBe(true)
			local homing = firstAt(run, "homePrey", "id", "krill") :: number
			expect(homing).toBeCloseTo(30, 0.11)
			run:wait(10, true)
			expect(firstAt(run, "spawnBurst") :: number).toBeCloseTo(40, 0.11)
			expect(firstAt(run, "failsafe", "ctx", "grow_burst") ~= nil).toBe(true)

			-- No input in the last 10 s at T = 30: no homing.
			local idle = newRun()
			toControl(idle)
			idle:send({ kind = "touch", drag = true })
			idle:send({ kind = "preyEaten", group = "swarmA" })
			idle:wait(15, true)
			idle:wait(16, false) -- at T = 31 the last input was 16 s ago (the hold has not started)
			expect(firstAt(idle, "homePrey", "id", "krill")).toBe(nil)
			idle:wait(0.1, true)
			expect(firstAt(idle, "homePrey", "id", "krill") ~= nil).toBe(true)
		end
	)

	it(
		"S3: no input for 8 s, the nearest krill swims into the mouth, once per idle spell",
		function()
			local run = newRun()
			toControl(run)
			run:send({ kind = "touch", drag = true })
			run:send({ kind = "preyEaten", group = "swarmA" })
			local a = run:wait(8.05)
			expect(count(a, "feedNearest")).toBe(1)
			expect(find(a, "pulse", "target") ~= nil).toBe(true)
			a = run:wait(4)
			expect(count(a, "feedNearest")).toBe(0)
			run:wait(0.1, true)
			a = run:wait(8.05)
			expect(count(a, "feedNearest")).toBe(1)
		end
	)

	it(
		"S4: the dash button and five Glowfry 1.0 s after the tier-up; step 08 on the first",
		function()
			local run = newRun()
			toControl(run)
			run:send({ kind = "touch", drag = true })
			run:send({ kind = "preyEaten", group = "swarmA" })
			run:send({ kind = "tierReached", tier = 2 })
			local a = run:wait(0.9, true)
			expect(find(a, "spawnGlowfry")).toBe(nil)
			a = run:wait(0.2, true)
			expect(find(a, "hud", "dashButton") ~= nil).toBe(true)
			local g = find(a, "spawnGlowfry") :: Action
			expect(g.count).toBe(5)
			expect(g.speed).toBe(8)
			expect(g.trait).toBe("glow")
			expect(find(a, "hud", "traitSlot") ~= nil).toBe(true)
			a = run:send({ kind = "preyEaten", group = "glowfry" })
			expect((find(a, "step") :: Action).step).toBe(8)
			a = run:send({ kind = "traitGained", trait = "glow" })
			expect(run.s.stage).toBe(S.S5_CALL_HOME)
			expect((find(a, "step") :: Action).step).toBe(9)
		end
	)

	it(
		"S4 fail-safes: home at 14 after 15 s, at 20 from T = 50 (trait_homing), on at T = 70",
		function()
			local run = newRun()
			toControl(run)
			run:send({ kind = "touch", drag = true })
			run:send({ kind = "preyEaten", group = "swarmA" })
			run:wait(20, true)
			run:send({ kind = "tierReached", tier = 2 }) -- S4 from T = 20
			run:wait(15.1, true)
			local slow = firstAt(run, "homePrey", "speed", 14) :: number
			expect(slow).toBeCloseTo(35, 0.11)
			run:wait(15, true)
			expect(firstAt(run, "homePrey", "speed", 20) :: number).toBeCloseTo(50, 0.11)
			expect(firstAt(run, "failsafe", "ctx", "trait_homing") ~= nil).toBe(true)
			run:wait(19.8, true)
			expect(run.s.stage).toBe(S.S4_TRAIT)
			run:wait(0.3, true)
			expect(run.s.stage).toBe(S.S5_CALL_HOME) -- 04 §3.1: T = 70 with input in the last 10 s
		end
	)

	it("S4 does not move on at T = 70 without input in the last 10 s", function()
		local run = newRun()
		toControl(run)
		run:send({ kind = "touch", drag = true })
		run:send({ kind = "preyEaten", group = "swarmA" })
		run:send({ kind = "tierReached", tier = 2 })
		run:wait(60, true)
		run:wait(12, false)
		expect(run.s.stage).toBe(S.S4_TRAIT)
		run:wait(0.1, true)
		expect(run.s.stage).toBe(S.S5_CALL_HOME)
	end)

	it("S5: the curtain opens 2.5 s after the trait, the shadow 1 s later", function()
		local run = newRun()
		toControl(run)
		run:send({ kind = "touch", drag = true })
		run:send({ kind = "preyEaten", group = "swarmA" })
		run:send({ kind = "tierReached", tier = 2 })
		run:send({ kind = "traitGained", trait = "glow" })
		local a = run:wait(2.4, true)
		expect(find(a, "openCurtain")).toBe(nil)
		a = run:wait(0.1, true)
		expect(find(a, "openCurtain") ~= nil).toBe(true)
		expect(find(a, "hud", "homeMarker") ~= nil).toBe(true)
		expect((find(a, "prompt", "homeTrail") :: Action).show).toBe(true)
		a = run:wait(1.0, true)
		expect(find(a, "predatorShadow") ~= nil).toBe(true)
	end)

	it(
		"S5 fail-safes: nudge at 8 s, home_lure at 20 s, home_push at 40 s without progress",
		function()
			local run = newRun()
			toCallHome(run)
			local a = run:wait(7.6, true)
			expect(find(a, "pulse", "homeMarker")).toBe(nil)
			a = run:wait(0.4, true)
			expect(find(a, "pulse", "homeMarker") ~= nil).toBe(true)
			run:send({ kind = "moved", towardGap = true }) -- progress restarts the count
			a = run:wait(19.9, true)
			expect(find(a, "spawnLure", "home")).toBe(nil)
			a = run:wait(0.2, true)
			expect(find(a, "spawnLure", "home") ~= nil).toBe(true)
			expect(find(a, "failsafe") and (find(a, "failsafe") :: Action).ctx).toBe("home_lure")
			a = run:wait(20, true)
			local push = find(a, "pull", "gap") :: Action
			expect(push.speed).toBe(6)
			expect((find(a, "failsafe") :: Action).ctx).toBe("home_push")
		end
	)

	it("S5 → S6 on crossing the Gap: step 10, scripted prey cleared, the chase starts", function()
		local run = newRun()
		toCallHome(run)
		local a = run:send({ kind = "crossedGap" })
		expect(run.s.stage).toBe(S.S6_CHASE)
		expect((find(a, "step") :: Action).step).toBe(10)
		expect(find(a, "clearScripted") ~= nil).toBe(true)
		expect(find(a, "startChase") ~= nil).toBe(true)
	end)

	it("S6: the dash prompt at 0.3 s and one auto-dash at 1.8 s with no dash (C6)", function()
		local run = newRun()
		toCallHome(run)
		run:send({ kind = "crossedGap" })
		local start = run.s.t
		run:wait(0.3)
		expect(firstAt(run, "prompt", "id", "dashPulse") ~= nil).toBe(true)
		run:wait(1.6)
		local auto = firstAt(run, "autoDash") :: number
		expect(auto - start).toBeCloseTo(1.8, 0.11)
		local a = run:send({ kind = "chaseEnded", assisted = false })
		expect(run.s.stage).toBe(S.S7_CURRENT)
		expect((find(a, "chaseResult") :: Action).result).toBe("assisted")
		expect((find(a, "step") :: Action).step).toBe(11)
		expect(find(a, "startCurrent") ~= nil).toBe(true)
	end)

	it("S6: a manual dash is clean and counted; no auto-dash", function()
		local run = newRun()
		toCallHome(run)
		run:send({ kind = "crossedGap" })
		run:wait(0.5)
		run:send({ kind = "dashed", auto = false })
		run:wait(3)
		expect(firstAt(run, "autoDash")).toBe(nil)
		local a = run:send({ kind = "chaseEnded", assisted = false })
		local r = find(a, "chaseResult") :: Action
		expect(r.result).toBe("clean")
		expect(r.value).toBe(1)
	end)

	it("S6 retreat: back to S5, the chase runs once more, then no predator (04 §5.4)", function()
		local run = newRun()
		toCallHome(run)
		run:send({ kind = "crossedGap" })
		local a = run:send({ kind = "retreated" })
		expect(run.s.stage).toBe(S.S5_CALL_HOME)
		expect((find(a, "chaseResult") :: Action).result).toBe("retreated")
		a = run:wait(5.1, true)
		expect(find(a, "pulse", "trail") ~= nil).toBe(true)
		a = run:send({ kind = "crossedGap" })
		expect(find(a, "startChase") ~= nil).toBe(true)
		run:send({ kind = "retreated" })
		a = run:send({ kind = "crossedGap" })
		expect(find(a, "startChase")).toBe(nil)
		expect(run.s.stage).toBe(S.S7_CURRENT)
	end)

	it(
		"S7: step 12 within 120 studs, the cove pull after 12 s near, a re-formed current",
		function()
			local run = newRun()
			toCallHome(run)
			run:send({ kind = "crossedGap" })
			run:send({ kind = "chaseEnded", assisted = false })
			run:send({ kind = "moved", inCurrent = false, coveDistance = 300 })
			local a = run:wait(10.05, true)
			expect(find(a, "reformCurrent") ~= nil).toBe(true)
			a = run:send({ kind = "moved", inCurrent = true, coveDistance = 110 })
			expect((find(a, "step") :: Action).step).toBe(12)
			run:send({ kind = "moved", inCurrent = false, coveDistance = 50 })
			a = run:wait(11.9, true)
			expect(find(a, "pull", "cove")).toBe(nil)
			a = run:wait(0.2, true)
			expect((find(a, "pull", "cove") :: Action).speed).toBe(8)
		end
	)

	it("S7 → S8 → S9 → S10 → DONE: bank, completion, cove items, run 2", function()
		local run = newRun()
		toCallHome(run)
		run:send({ kind = "crossedGap" })
		run:send({ kind = "chaseEnded", assisted = false })
		local a = run:send({ kind = "enteredCoveMouth" })
		expect(run.s.stage).toBe(S.S8_BANK)
		expect((find(a, "step") :: Action).step).toBe(13)
		expect(find(a, "milestone", "bank") ~= nil).toBe(true)
		expect(find(a, "bankSequence") ~= nil).toBe(true)
		run:wait(3.3)
		a = run:send({ kind = "fryHatched" })
		expect(run.s.stage).toBe(S.S9_COVE)
		expect(find(a, "completeFtue") ~= nil).toBe(true)
		a = run:wait(3.1)
		expect(find(a, "coveItem", "firstTick") ~= nil).toBe(true)
		a = run:wait(2)
		expect(find(a, "coveItem", "species") ~= nil).toBe(true)
		expect((find(a, "step") :: Action).step).toBe(16)
		a = run:wait(2)
		expect(find(a, "coveItem", "tide") ~= nil).toBe(true)
		a = run:wait(2)
		expect(find(a, "coveItem", "mouth") ~= nil).toBe(true)
		a = run:send({ kind = "leftCoveMouth" })
		expect(run.s.stage).toBe(S.S10_RUN2)
		expect((find(a, "step") :: Action).step).toBe(17)
		expect((find(a, "denseKrill") :: Action).count).toBe(12)
		a = run:wait(5.05, true)
		expect(find(a, "hud", "goalsChip") ~= nil).toBe(true)
		a = run:send({ kind = "tierReached", tier = 2 })
		expect((find(a, "step") :: Action).step).toBe(18)
		a = run:send({ kind = "runEnded" })
		expect(run.s.stage).toBe(S.DONE)
		expect((find(a, "step") :: Action).step).toBe(19)
		expect(#run:send({ kind = "preyEaten" })).toBe(0)
	end)

	it("logs onboarding steps in order, each once", function()
		local run = newRun()
		toCallHome(run)
		run:send({ kind = "crossedGap" })
		run:send({ kind = "chaseEnded", assisted = false })
		run:send({ kind = "moved", coveDistance = 100 })
		run:send({ kind = "enteredCoveMouth" })
		run:wait(3.3)
		run:send({ kind = "fryHatched" })
		run:wait(10)
		run:send({ kind = "leftCoveMouth" })
		run:send({ kind = "tierReached", tier = 2 })
		run:send({ kind = "runEnded" })
		expect(steps(run)).toEqual({ 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 16, 17, 18, 19 })
	end)

	it("cove items left early fire in order 4 s apart as pings (04 §6.1)", function()
		local run = newRun()
		toCallHome(run)
		run:send({ kind = "crossedGap" })
		run:send({ kind = "chaseEnded", assisted = false })
		run:send({ kind = "enteredCoveMouth" })
		run:wait(3.3)
		run:send({ kind = "fryHatched" })
		run:wait(3.1) -- the first tick has fired at 6.3
		run:send({ kind = "leftCoveMouth" })
		local a = run:wait(2.0, true) -- bank clock 8.4: the species item, as a ping
		local species = find(a, "coveItem", "species") :: Action
		expect(species.ping).toBe(true)
		a = run:wait(3.8, true) -- not yet: the next ping waits 4 s after the species ping
		expect(find(a, "coveItem", "tide")).toBe(nil)
		a = run:wait(0.25, true)
		expect(find(a, "coveItem", "tide") ~= nil).toBe(true)
	end)

	it("S9: 20 s after the tide clock the mouth pulses, 40 s a lure passes", function()
		local run = newRun()
		toCallHome(run)
		run:send({ kind = "crossedGap" })
		run:send({ kind = "chaseEnded", assisted = false })
		run:send({ kind = "enteredCoveMouth" })
		run:wait(3.3)
		run:send({ kind = "fryHatched" })
		run:wait(26.9, true) -- bank clock 30.2
		expect(firstAt(run, "pulse", "id", "coveMouth")).toBe(nil)
		run:wait(0.2, true)
		expect(firstAt(run, "pulse", "id", "coveMouth") ~= nil).toBe(true)
		run:wait(20, true)
		expect(firstAt(run, "spawnLure", "id", "cove") ~= nil).toBe(true)
	end)

	it("S10: run2_homing at 30 s with mass under 5, ended at mass 10", function()
		local run = newRun()
		toCallHome(run)
		run:send({ kind = "crossedGap" })
		run:send({ kind = "chaseEnded", assisted = false })
		run:send({ kind = "enteredCoveMouth" })
		run:send({ kind = "fryHatched" })
		run:send({ kind = "leftCoveMouth" })
		run:send({ kind = "massChanged", mass = 2 })
		local a = run:wait(30.05, true)
		local h = find(a, "homePrey", "krill") :: Action
		expect(h.speed).toBe(4)
		expect((find(a, "failsafe") :: Action).ctx).toBe("run2_homing")
		a = run:send({ kind = "massChanged", mass = 10 })
		expect(find(a, "stopHoming", "krill") ~= nil).toBe(true)
	end)

	it("banking by any route after S5 completes the FTUE (04 §9)", function()
		local run = newRun()
		toCallHome(run)
		run:send({ kind = "crossedGap" })
		local a = run:send({ kind = "enteredCoveMouth" })
		expect(run.s.stage).toBe(S.S8_BANK)
		expect((find(a, "chaseResult") :: Action).result).toBe("skipped")
		-- Before S5 the cove cannot be reached; the event changes nothing.
		local early = newRun()
		toControl(early)
		early:send({ kind = "enteredCoveMouth" })
		expect(early.s.stage).toBe(S.S2_FIRST_BITE)
	end)
end)

describe("FtueRules idle and absence (04 §3.7)", function()
	it("ghost thumb at 4 s, target pulse at 8 s, hold at 20 s; all resume on input", function()
		local run = newRun()
		toControl(run)
		run:send({ kind = "touch", drag = true })
		run:send({ kind = "preyEaten", group = "swarmA" })
		local a = run:wait(4.05)
		expect((find(a, "prompt", "ghostThumb") :: Action).show).toBe(true)
		a = run:wait(4)
		expect(find(a, "pulse", "target") ~= nil).toBe(true)
		a = run:wait(12)
		local hold = find(a, "hold") :: Action
		expect(hold.on).toBe(true)
		expect((find(a, "failsafe") :: Action).ctx).toBe("afk_hold")
		expect(FtueRules.isHeld(run.s)).toBe(true)
		-- Beat timers freeze: the beat clock stands still while T runs on.
		local clock, t = run.s.clock, run.s.t
		a = run:wait(30)
		expect(run.s.clock).toBe(clock)
		expect(run.s.t > t + 29).toBe(true)
		expect(find(a, "homePrey")).toBe(nil) -- grow_homing waits for the beat clock
		a = run:send({ kind = "touch", drag = false })
		expect((find(a, "hold") :: Action).on).toBe(false)
		expect((find(a, "prompt", "ghostThumb") :: Action).show).toBe(false)
		run:wait(0.1, true)
		expect(run.s.clock > clock).toBe(true)
	end)

	it("going to the background holds at once", function()
		local run = newRun()
		toControl(run)
		local a = run:send({ kind = "backgrounded" })
		expect((find(a, "hold") :: Action).on).toBe(true)
		local clock = run.s.clock
		run:wait(5)
		expect(run.s.clock).toBe(clock)
	end)

	it("does not hold during the chase (04 §5.4 owns it)", function()
		local run = newRun()
		toCallHome(run)
		run:send({ kind = "crossedGap" })
		local a = run:wait(25)
		expect(find(a, "hold")).toBe(nil)
	end)
end)

describe("FtueRules joining again (04 §9; 09 §12.5)", function()
	it("an account that has banked is DONE; a bank without the flag completes it", function()
		local s, a =
			FtueRules.new(FtueConfig, { stage = 8, completed = false, attempts = 0, banked = true })
		expect(s.stage).toBe(S.DONE)
		expect(find(a, "completeFtue") ~= nil).toBe(true)
		s, a =
			FtueRules.new(FtueConfig, { stage = 10, completed = true, attempts = 0, banked = true })
		expect(s.stage).toBe(S.DONE)
		expect(#a).toBe(0)
	end)

	it("resumes a suspended run from the saved stage without replaying done beats", function()
		local run = newRun(nil, {
			stage = S.S4_TRAIT,
			completed = false,
			attempts = 0,
			banked = false,
			run = { seconds = 30, mass = 11, tier = 2, traitProgress = 2 },
		})
		expect(run.s.stage).toBe(S.S4_TRAIT)
		expect(run.s.t).toBe(30)
		local first = {}
		for _, row in run.log do
			table.insert(first, row.a)
		end
		expect(find(first, "hatch")).toBe(nil)
		expect(find(first, "spawnSwarmA")).toBe(nil)
		expect(find(first, "restart")).toBe(nil)
		expect(find(first, "hud", "massBar") ~= nil).toBe(true)
		expect(find(first, "hud", "dashButton") ~= nil).toBe(true)
		expect((find(first, "spawnGlowfry") :: Action).count).toBe(3) -- 5 less the 2 eaten
		expect(#steps(run)).toBe(0)
		-- The beat goes on from there: T = 50 still brings the fast homing, on the run's clock.
		run:wait(20.05, true)
		expect(firstAt(run, "failsafe", "ctx", "trait_homing") ~= nil).toBe(true)
		local a = run:send({ kind = "traitGained", trait = "glow" })
		expect((find(a, "step") :: Action).step).toBe(9)
	end)

	it("resumes S5 with the Gap open, and S6 as a skipped chase into S7", function()
		local r5 = newRun(nil, {
			stage = S.S5_CALL_HOME,
			completed = false,
			attempts = 0,
			banked = false,
			run = { seconds = 50, mass = 14, tier = 2, traitProgress = 5 },
		})
		local first = {}
		for _, row in r5.log do
			table.insert(first, row.a)
		end
		expect(find(first, "openCurtain") ~= nil).toBe(true)
		expect(find(first, "predatorShadow")).toBe(nil)
		r5:send({ kind = "crossedGap" })
		expect(r5.s.stage).toBe(S.S6_CHASE)

		local r6 = newRun(nil, {
			stage = S.S6_CHASE,
			completed = false,
			attempts = 0,
			banked = false,
			run = { seconds = 60, mass = 14, tier = 2, traitProgress = 5 },
		})
		expect(r6.s.stage).toBe(S.S7_CURRENT)
		expect(firstAt(r6, "chaseResult", "result", "skipped") ~= nil).toBe(true)
		expect(firstAt(r6, "startCurrent") ~= nil).toBe(true)
	end)

	it("no run to resume: restarts in the fast form, then the short form", function()
		local fast =
			newRun(nil, { stage = S.S3_GROW, completed = false, attempts = 0, banked = false })
		expect(fast.s.stage).toBe(S.S0_LOADING)
		expect(fast.s.form).toBe("fast")
		expect(firstAt(fast, "restart", "value", 1) ~= nil).toBe(true)
		local a = fast:send({ kind = "loadingDone" })
		expect((find(a, "hatch") :: Action).seconds).toBe(0.6)
		-- Idle timers halved: the ghost thumb returns after 2 s.
		fast:wait(0.6)
		fast:send({ kind = "controlGained" })
		fast:send({ kind = "touch", drag = true })
		a = fast:wait(2.05)
		expect((find(a, "prompt", "ghostThumb") :: Action).show).toBe(true)

		local short = newRun(
			nil,
			{ stage = S.S2_FIRST_BITE, completed = false, attempts = 1, banked = false }
		)
		expect(short.s.form).toBe("short")
		a = short:send({ kind = "loadingDone" })
		expect(find(a, "spawnSwarmA")).toBe(nil)
		short:wait(0.6)
		a = short:send({ kind = "controlGained" })
		expect(short.s.stage).toBe(S.S5_CALL_HOME)
		expect(find(a, "openCurtain") ~= nil).toBe(true)
		expect(find(a, "hud", "homeMarker") ~= nil).toBe(true)
		a = short:send({ kind = "crossedGap" })
		expect(find(a, "startChase")).toBe(nil)
		expect(short.s.stage).toBe(S.S7_CURRENT)
	end)

	it("a join that stopped during loading is not a restart", function()
		local run = newRun(nil, { stage = 0, completed = false, attempts = 0, banked = false })
		expect(run.s.form).toBe("full")
		expect(firstAt(run, "restart")).toBe(nil)
	end)
end)

describe(
	"FtueRules reads every number from the config passed in (13 Sprint 6; 04 §12 A4)",
	function()
		it("changing FtueConfig values changes the script with no other edit", function()
			local cfg = clone(FtueConfig)
			cfg.hatch.seconds = 1.0
			cfg.firstBite.assistAt = 1.5
			cfg.feed.swarmACount = 9
			cfg.arms.traitCount = 3
			cfg.trait.glowfryDelay = 2.0
			cfg.callHome.curtainDelay = 1.0
			cfg.idle.holdAfter = 12

			local run = newRun(cfg)
			local a = run:send({ kind = "loadingDone" })
			expect((find(a, "spawnSwarmA") :: Action).count).toBe(9)
			run:wait(0.9)
			expect(firstAt(run, "giveControl")).toBe(nil)
			run:wait(0.1)
			expect(firstAt(run, "giveControl") ~= nil).toBe(true)
			run:send({ kind = "controlGained" })
			run:wait(1.5)
			expect(firstAt(run, "homePrey", "id", "swarmA") :: number).toBeCloseTo(1.5, 1e-6)
			run:send({ kind = "preyEaten", group = "swarmA" })
			run:wait(10.5)
			expect(firstAt(run, "hold") :: number).toBeCloseTo(12, 0.11)
			run:send({ kind = "touch", drag = true })
			run:send({ kind = "tierReached", tier = 2 })
			a = run:wait(1.95, true)
			expect(find(a, "spawnGlowfry")).toBe(nil)
			a = run:wait(0.1, true)
			expect((find(a, "spawnGlowfry") :: Action).count).toBe(3)
			for _ = 1, 3 do
				run:send({ kind = "preyEaten", group = "glowfry" })
			end
			run:send({ kind = "traitGained", trait = "glow" })
			a = run:wait(1.05, true)
			expect(find(a, "openCurtain") ~= nil).toBe(true)
		end)

		it("the escort arm runs S6 with no Barracuda and no auto-dash", function()
			local cfg = clone(FtueConfig)
			cfg.arms.chaseMode = "escort"
			local run = newRun(cfg)
			toCallHome(run)
			local a = run:send({ kind = "crossedGap" })
			expect(run.s.stage).toBe(S.S6_CHASE)
			expect(find(a, "startChase")).toBe(nil)
			run:wait(3)
			expect(firstAt(run, "autoDash")).toBe(nil)
			run:send({ kind = "chaseEnded", assisted = false })
			expect(run.s.stage).toBe(S.S7_CURRENT)
		end)

		it("never changes the state it is given", function()
			local run = newRun()
			toControl(run)
			local before = run.s
			local stage, t = before.stage, before.t
			FtueRules.handle(FtueConfig, before, { kind = "preyEaten", group = "swarmA" })
			FtueRules.handle(FtueConfig, before, { kind = "tick", dt = 5, hadInput = false })
			expect(before.stage).toBe(stage)
			expect(before.t).toBe(t)
			expect(before.fired.milestone_bite).toBe(nil)
		end)
	end
)
