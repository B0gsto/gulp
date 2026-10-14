--!strict
-- Engine-side spec of TutorialService (task S6-C2, module B31; docs/04, sections 3.1, 3.5 and 3.6;
-- docs/09, section 5.1). Open Cloud has no players, so one slot gets a stand-in creature
-- (PreyService.setCreatureLookup and the TraitService and TutorialService stubs) and a stand-in
-- session that the spec ticks by hand. A fresh profile is driven from the loading screen through
-- S1 to S5 with the service's own scripted prey, eaten through PreyService.tryEat and
-- TraitService.onTraitPreyEaten as BiteService does: the prey belongs to that slot alone, every
-- stage is saved, and the first trait is Glow. The stage machine's rules are
-- tests/unit/Logic/FtueRules; the route helpers tests/unit/Logic/FtuePlan.
-- Analytics (task S6-C6; docs/10, sections 3.1 and 4.2; Sprint 6 acceptance "onboarding steps log
-- in order in the Studio event buffer"): the stand-in reports as STAND_IN, and the spec reads
-- Analytics' buffer (nothing is sent outside a live server) for its records.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FtueConfig = require(ReplicatedStorage.Shared.Config.FtueConfig)
local FtuePlan = require(ReplicatedStorage.Shared.Logic.FtuePlan)
local FtueRules = require(ReplicatedStorage.Shared.Logic.FtueRules)
local Index = require(ReplicatedStorage.Shared.Data.Index)
local PreySim = require(ReplicatedStorage.Shared.Sim.PreySim)
local TestKit = require(ReplicatedStorage.Shared.Util.TestKit)

local Analytics = require("../Services/Analytics")
local AnalyticsRules = require(ReplicatedStorage.Shared.Logic.AnalyticsRules)
local CreatureService = require("../Services/CreatureService")
local PreyService = require("../Services/PreyService")
local TraitService = require("../Services/TraitService")
local TutorialService = require("../Services/TutorialService")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type CreatureState = CreatureService.CreatureState

local SLOT = 21 -- a slot no real player of a play test holds
local OTHER = 20
local S = FtueRules.Stage
local C = FtuePlan.Code
local T = TutorialService._test
-- The player the stand-in sessions report to Analytics as (Analytics reads only `UserId`).
local STAND_IN: Player = ({ UserId = -9801, Name = "StandIn" } :: any) :: Player

local function ensureRunning()
	if not PreyService.isRunning() then
		PreyService.init()
		PreyService.start()
	end
	if not TutorialService.isRunning() then
		TutorialService.init()
		TutorialService.start()
	end
	Analytics._test.ensureInit()
end

-- STAND_IN's records in the Analytics buffer, oldest first.
local function reported(): { Analytics.Record }
	local out = {}
	for _, r in Analytics.buffer() do
		if r.userId == STAND_IN.UserId then
			table.insert(out, r)
		end
	end
	return out
end

-- STAND_IN's custom events called `name`, as their ctx values, in order.
local function eventsNamed(name: string): { string }
	local out = {}
	for _, r in reported() do
		if r.kind == "event" and r.name == name then
			table.insert(out, r.ctx)
		end
	end
	return out
end

type World = {
	body: any, -- the creature PreyService and TutorialService read
	traits: CreatureState, -- the view TraitService reads
	saves: { { path: string, value: any } },
	cues: { FtueRules.Action },
	done: () -> (),
}

-- A stand-in Fry on the Hatch Bed in SLOT, with every save and cue recorded.
local function world(): World
	local hx, hy, hz = FtuePlan.routePoint(0)
	local root = Instance.new("Part")
	root.Position = Vector3.new(hx, hy, hz)
	local body: any = { slot = SLOT, tier = 1, mass = 0, bodyScale = 1, root = root }
	local attributes: { [string]: any } = { Phase = "run", Traits = "" }
	local player = {
		UserId = -9800,
		SetAttribute = function(_self: any, name: string, value: any)
			attributes[name] = value
		end,
		GetAttribute = function(_self: any, name: string): any
			return attributes[name]
		end,
	}
	-- Safe cast: TraitService reads only `player` (attributes) and the trait fields.
	local traits = (
		{ slot = SLOT, player = player, traits = {}, progress = {}, traitGainedAt = {} } :: any
	) :: CreatureState
	local w: World = { body = body, traits = traits, saves = {}, cues = {}, done = function() end }
	local function find(slot: number): any
		if slot == SLOT then
			return body
		end
		return CreatureService.get(slot)
	end
	PreyService.setCreatureLookup(find)
	TutorialService._test.stub(find, function(kind: string, path: string, value: any)
		if kind == "save" then
			table.insert(w.saves, { path = path, value = value })
		else
			for _, a in value.actions do
				table.insert(w.cues, a)
			end
		end
	end)
	TraitService._test.stub(function(slot: number): CreatureState?
		return if slot == SLOT then traits else nil
	end, function() end)
	T.clearLog()
	T.reporter(STAND_IN)
	Analytics.forget(STAND_IN)
	Analytics.clearBuffer()
	w.done = function()
		T.reporter(nil)
		Analytics.forget(STAND_IN)
		T.finish(SLOT)
		PreyService.clearScripted(SLOT)
		TutorialService._test.stub(nil, nil)
		TraitService._test.stub(nil, nil)
		PreyService.setCreatureLookup(nil)
		root:Destroy()
	end
	return w
end

local function run(body: (w: World) -> ())
	ensureRunning()
	local w = world()
	local ok, err = xpcall(function()
		body(w)
	end, function(e: any): string
		return `{tostring(e)}\n{debug.traceback()}`
	end)
	w.done()
	if not ok then
		error(err, 0)
	end
end

local function ticks(seconds: number)
	for _ = 1, math.round(seconds / 0.1) do
		T.tick(SLOT, 0.1)
	end
end

local function stage(): number
	local state = T.state(SLOT)
	return if state then state.stage else -1
end

local function lastSaved(path: string, saves: { { path: string, value: any } }): any
	for k = #saves, 1, -1 do
		if saves[k].path == path then
			return saves[k].value
		end
	end
	return nil
end

local function cued(cues: { FtueRules.Action }, kind: string): boolean
	for _, a in cues do
		if a.kind == kind then
			return true
		end
	end
	return false
end

local function logged(kind: string, value: any): boolean
	for _, entry in T.log() do
		if entry.kind == kind and entry.value == value then
			return true
		end
	end
	return false
end

-- Scripted IDs of SLOT's groups called `name`.
local function groupsNamed(name: string): { number }
	local out = {}
	for id, n in T.groups(SLOT) do
		if n == name then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

-- Eats every live member of scripted group `id` as BiteService would (tryEat, then the trait
-- pip); returns the prey IDs eaten.
local function eatAll(w: World, id: number): { string }
	local sim, _, spawner = PreyService.internals()
	local eaten = {}
	local owned = spawner.owned[id]
	if owned == nil then
		return eaten
	end
	local later = workspace:GetServerTimeNow() + 1 -- faded in
	for _, part in owned.parts do
		if part.g < 0 then
			continue
		end
		for m = 0, PreySim.MAX_MEMBERS - 1 do
			if PreySim.memberAlive(sim, part.g, m) then
				local ok, def = PreyService.tryEat(SLOT, part.g, m, part.gen, later)
				if ok and def then
					w.body.mass += def.mass
					table.insert(eaten, def.id)
					if def.givesTrait then
						TraitService.onTraitPreyEaten(SLOT, def.givesTrait)
					end
				end
			end
		end
	end
	task.wait() -- onScriptedEaten and onGained are deferred
	return eaten
end

-- Every scripted run on the server, by owner.
local function ownersOf(): { [number]: number }
	local _, _, spawner = PreyService.internals()
	local out = {}
	for _, owned in spawner.owned do
		out[owned.owner] = (out[owned.owner] or 0) + 1
	end
	return out
end

return function()
	describe("TutorialService", function()
		it("never starts the script for an account that finished it or banked", function()
			run(function(w)
				expect(
					T.begin(SLOT, { stage = S.DONE, completed = true, attempts = 0, banked = true })
				).toBe(false)
				expect(T.state(SLOT)).toBe(nil)
				expect(ownersOf()[SLOT]).toBe(nil)
				expect(#w.saves).toBe(0)
				-- Banked but not marked complete (04 §9): marked, still no script.
				expect(
					T.begin(
						SLOT,
						{ stage = S.S3_GROW, completed = false, attempts = 0, banked = true }
					)
				).toBe(false)
				expect(lastSaved("ftue.completed", w.saves)).toBe(true)
				expect(lastSaved("ftue.stage", w.saves)).toBe(nil) -- no stage for a DONE join
				expect(ownersOf()[SLOT]).toBe(nil)
			end)
		end)

		it("keeps S10 for a finished account that rejoins mid run 2, saving nothing", function()
			run(function(w)
				expect(
					T.begin(
						SLOT,
						{ stage = S.S10_RUN2, completed = true, attempts = 0, banked = true }
					)
				).toBe(true)
				expect(stage()).toBe(S.S10_RUN2)
				ticks(1)
				expect(stage()).toBe(S.S10_RUN2)
				expect(#w.saves).toBe(0)
				expect(cued(w.cues, "hatch")).toBe(false)
			end)
		end)

		it("drives a fresh profile from the hatch to the call home, first trait Glow", function()
			run(function(w)
				local before = ownersOf()
				expect(
					T.begin(SLOT, { stage = 0, completed = false, attempts = 0, banked = false })
				).toBe(true)
				expect(stage()).toBe(S.S0_LOADING)
				expect(logged("step", 1)).toBe(true)
				T.signal(SLOT, C.LOADING_SHOWN)
				expect(logged("step", 2)).toBe(true)

				-- S1: the hatch, and Swarm A for this slot alone.
				T.signal(SLOT, C.LOADED)
				expect(stage()).toBe(S.S1_HATCH)
				expect(lastSaved("ftue.stage", w.saves)).toBe(S.S1_HATCH)
				expect(cued(w.cues, "hatch")).toBe(true)
				local swarmA = groupsNamed("swarmA")
				expect(#swarmA).toBe(1)
				local after = ownersOf()
				expect(after[SLOT]).toBe(1)
				for owner, n in after do
					if owner ~= SLOT then
						expect(n).toBe(before[owner] or 0) -- no other slot got any
					end
				end
				local alive, centre = PreyService.scriptedAlive(SLOT, swarmA[1])
				expect(alive).toBe(FtueConfig.feed.swarmACount)
				expect((PreyService.scriptedAlive(OTHER, swarmA[1]))).toBe(0)
				local _, _, spawner = PreyService.internals()
				local part = spawner.owned[swarmA[1]].parts[1]
				expect((PreyService.peek(OTHER, part.g, 0, part.gen))).toBe(nil)
				expect((PreyService.peek(SLOT, part.g, 0, part.gen)) ~= nil).toBe(true)

				-- S2 at the end of the hatch; Swarm A stays where it is (04 §3.6 B2) ...
				ticks(FtueConfig.hatch.seconds + 0.1)
				expect(stage()).toBe(S.S2_FIRST_BITE)
				expect(cued(w.cues, "giveControl")).toBe(true)
				expect(lastSaved("ftue.stage", w.saves)).toBe(S.S2_FIRST_BITE)
				expect(logged("step", 3)).toBe(true)
				for _ = 1, 12 do
					PreyService.frame()
				end
				local _, still = PreyService.scriptedAlive(SLOT, swarmA[1])
				expect(((still :: Vector3) - (centre :: Vector3)).Magnitude < 0.01).toBe(true)
				-- ... until the Fry swims away from it: then it follows.
				local hatch = w.body.root.Position
				local back = hatch - ((centre :: Vector3) - hatch).Unit * 20
				w.body.root.Position = back
				local start = ((centre :: Vector3) - back).Magnitude
				T.tick(SLOT, 0.1)
				for _ = 1, 12 do
					PreyService.frame()
				end
				local _, moved = PreyService.scriptedAlive(SLOT, swarmA[1])
				expect(((moved :: Vector3) - back).Magnitude < start).toBe(true)
				w.body.root.Position = hatch
				-- A mass rise that is no bite (a cheat, a pickup) does not end S2.
				w.body.mass = 1
				T.tick(SLOT, 0.1)
				expect(stage()).toBe(S.S2_FIRST_BITE)

				-- S3 on the first bite: the trail and Swarm B.
				T.signal(SLOT, C.STEER)
				expect(logged("step", 4)).toBe(true)
				expect(#eatAll(w, swarmA[1])).toBe(FtueConfig.feed.swarmACount)
				expect(stage()).toBe(S.S3_GROW)
				expect(logged("step", 5)).toBe(true)
				local trail = groupsNamed("trail")
				expect(#trail).toBe(1) -- one scripted ID, a group per mote
				expect((PreyService.scriptedAlive(SLOT, trail[1]))).toBe(FtueConfig.feed.trailMotes)
				expect(#groupsNamed("swarmB")).toBe(1)
				ticks(0.2)
				expect(logged("step", 6)).toBe(true) -- mass 6 ≥ 5

				-- S4 at tier 2: five Glowfry 1.0 s after.
				w.body.mass, w.body.tier = 10, 2
				CreatureService.onTierChanged:fire(SLOT, 2)
				task.wait()
				expect(stage()).toBe(S.S4_TRAIT)
				-- Another trait first (a wild Dotted Goby) does not end S4 (04 §3.6 B5).
				TraitService.onGained:fire(SLOT, "spots", 1)
				task.wait()
				expect(stage()).toBe(S.S4_TRAIT)
				expect(lastSaved("ftue.stage", w.saves)).toBe(S.S4_TRAIT)
				ticks(FtueConfig.trait.glowfryDelay + 0.2)
				local glowfry = groupsNamed("glowfry")
				expect(#glowfry).toBe(1)
				expect(spawner.owned[glowfry[1]].prey).toBe(FtuePlan.traitPreyFor("glow"))
				expect((PreyService.scriptedAlive(SLOT, glowfry[1]))).toBe(
					FtueConfig.arms.traitCount
				)

				-- Eating them gains Glow, the first trait, and starts S5.
				local eaten = eatAll(w, glowfry[1])
				expect(#eaten).toBe(FtueConfig.arms.traitCount)
				expect(Index.TraitPrey.byId[eaten[1]].givesTrait).toBe("glow")
				expect(w.traits.traits[1]).toBe("glow")
				expect(#w.traits.traits).toBe(1)
				task.wait()
				expect(stage()).toBe(S.S5_CALL_HOME)
				expect(lastSaved("ftue.stage", w.saves)).toBe(S.S5_CALL_HOME)
				expect(logged("step", 8) and logged("step", 9)).toBe(true)
				ticks(FtueConfig.callHome.curtainDelay + 0.2)
				expect(cued(w.cues, "openCurtain")).toBe(true)
				expect(ownersOf()[OTHER] == (before[OTHER] or nil)).toBe(true)

				-- TODO(S7-C1) CHASE_PASS_THROUGH: across the Gap, S6 passes straight into S7.
				table.clear(w.cues)
				T.feed(SLOT, { kind = "crossedGap" })
				expect(stage()).toBe(S.S7_CURRENT)
				expect(lastSaved("ftue.stage", w.saves)).toBe(S.S7_CURRENT)
				expect(cued(w.cues, "startChase")).toBe(false)
				expect(cued(w.cues, "startCurrent")).toBe(true)
				expect(logged("step", 10) and logged("step", 11)).toBe(true)

				-- Analytics: every step the rules emitted for S0 to S5 is in the buffer, on the
				-- onboarding funnel, in order and once each (10 §3.1).
				local hooked, buffered = {}, {}
				for _, entry in T.log() do
					if entry.kind == "step" then
						table.insert(hooked, entry.value)
					end
				end
				for _, r in reported() do
					if r.kind == "step" then
						expect(r.name).toBe("onboarding")
						expect(r.sessionId).toBe(nil)
						table.insert(buffered, r.value)
					end
				end
				expect(table.concat(buffered, ",")).toBe("1,2,3,4,5,6,7,8,9,10,11")
				expect(table.concat(hooked, ",")).toBe(table.concat(buffered, ","))
				expect(reported()[1].stepName).toBe("01_joined")
				-- ftue_milestone once each for the first bite, tier 2 and the first trait.
				local milestones = eventsNamed("ftue_milestone")
				expect(#milestones).toBe(3)
				expect(string.sub(milestones[1], 1, 5)).toBe("bite_")
				expect(string.sub(milestones[2], 1, 6)).toBe("tier2_")
				expect(string.sub(milestones[3], 1, 6)).toBe("trait_")
				expect(#eventsNamed("ftue_chase_result")).toBe(1) -- skipped, until S7-C1
				expect(#eventsNamed("ftue_bite_assist")).toBe(0) -- the input came first
			end)
		end)

		it("sends a fail-safe once per account, across a rejoin", function()
			run(function(w)
				local fresh = { stage = 0, completed = false, attempts = 0, banked = false }
				T.begin(SLOT, fresh)
				T.signal(SLOT, C.LOADED)
				ticks(FtueConfig.hatch.seconds + 0.1)
				expect(stage()).toBe(S.S2_FIRST_BITE)
				T.signal(SLOT, C.BACKGROUND) -- 04 §3.7: the hold at once
				expect(table.concat(eventsNamed("ftue_failsafe"), ",")).toBe("afk_hold")
				local mask = lastSaved("ftue.logged", w.saves)
				expect(AnalyticsRules.isLogged(mask, "failsafe_afk_hold")).toBe(true)
				-- The next session reads the saved bits: the hold is not sent again.
				T.finish(SLOT)
				T.begin(SLOT, fresh, false, mask)
				T.signal(SLOT, C.LOADED)
				ticks(FtueConfig.hatch.seconds + 0.1)
				T.signal(SLOT, C.BACKGROUND)
				expect((T.state(SLOT) :: FtueRules.State).held).toBe(true)
				expect(table.concat(eventsNamed("ftue_failsafe"), ",")).toBe("afk_hold")
				-- A fresh account (nothing saved) sends it.
				T.finish(SLOT)
				T.begin(SLOT, fresh, false, 0)
				T.signal(SLOT, C.LOADED)
				ticks(FtueConfig.hatch.seconds + 0.1)
				T.signal(SLOT, C.BACKGROUND)
				expect(table.concat(eventsNamed("ftue_failsafe"), ",")).toBe("afk_hold,afk_hold")
			end)
		end)

		it("counts a wild bite as the first bite, and only a bite", function()
			run(function(_w)
				T.begin(SLOT, { stage = 0, completed = false, attempts = 0, banked = false })
				T.signal(SLOT, C.LOADED)
				ticks(FtueConfig.hatch.seconds + 0.1)
				expect(stage()).toBe(S.S2_FIRST_BITE)
				PreyService.onWildEaten:fire(OTHER, "krill") -- another slot's bite
				task.wait()
				expect(stage()).toBe(S.S2_FIRST_BITE)
				PreyService.onWildEaten:fire(SLOT, "krill")
				task.wait()
				expect(stage()).toBe(S.S3_GROW)
			end)
		end)

		it("keeps seq rising across sessions and opens a reset with a `reset` cue", function()
			run(function(w)
				local seqs: { number } = {}
				local firsts: { string } = {}
				T.stub(function(slot: number): any
					return if slot == SLOT then w.body else CreatureService.get(slot)
				end, function(kind: string, _path: string, value: any)
					if kind == "cue" then
						table.insert(seqs, value.seq)
						table.insert(firsts, value.actions[1].kind)
					end
				end)
				T.begin(SLOT, { stage = 0, completed = false, attempts = 0, banked = false })
				T.signal(SLOT, C.LOADED)
				local before = #seqs
				expect(before > 0).toBe(true)
				T.begin(SLOT, { stage = 0, completed = false, attempts = 0, banked = false }, true)
				T.signal(SLOT, C.LOADED)
				expect(#seqs > before).toBe(true)
				for k = 2, #seqs do
					expect(seqs[k]).toBe(seqs[k - 1] + 1)
				end
				expect(firsts[before + 1]).toBe("reset")
			end)
		end)

		it("spawns as many Glowfry as TraitService needs pips", function()
			run(function(_w)
				T.begin(SLOT, { stage = 0, completed = false, attempts = 0, banked = false })
				local config = T.config(SLOT) :: FtueRules.Config
				expect(config.arms.traitCount).toBe(TraitService.pipsNeeded(SLOT))
			end)
		end)

		it("gives a never-touching tester the first bite through the fail-safe", function()
			run(function(w)
				T.begin(SLOT, { stage = 0, completed = false, attempts = 0, banked = false })
				T.signal(SLOT, C.LOADED)
				ticks(FtueConfig.hatch.seconds + 0.1)
				expect(stage()).toBe(S.S2_FIRST_BITE)
				ticks(FtueConfig.firstBite.assistAt + 0.1)
				-- Swarm A homes on the mouth (04 §3.6 B2); the bite still moves the script on.
				local swarmA = groupsNamed("swarmA")
				expect(#eatAll(w, swarmA[1]) > 0).toBe(true)
				expect(stage()).toBe(S.S3_GROW)
				expect(logged("step", 5)).toBe(false) -- held until the first input (10 §3.1)
				T.signal(SLOT, C.TAP)
				T.signal(SLOT, C.STEER)
				expect(logged("step", 5)).toBe(true)
				expect(#eventsNamed("ftue_bite_assist")).toBe(1) -- the bite came before any input
			end)
		end)

		it("restarts a script left before control in the fast form, attempts + 1", function()
			run(function(w)
				T.begin(
					SLOT,
					{ stage = S.S1_HATCH, completed = false, attempts = 0, banked = false }
				)
				expect(stage()).toBe(S.S0_LOADING)
				expect(lastSaved("ftue.attempts", w.saves)).toBe(1)
				expect(lastSaved("ftue.stage", w.saves)).toBe(S.S0_LOADING)
				local state = T.state(SLOT) :: FtueRules.State
				expect(state.form).toBe("fast")
				expect(logged("step", 1)).toBe(false)
			end)
		end)
	end)
end
