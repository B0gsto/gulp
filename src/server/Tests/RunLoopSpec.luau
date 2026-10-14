--!strict
-- Engine-side spec of RunLoopService (task S4-C4; docs/09, sections 5.3, 6.3 and 6.8; docs/02,
-- sections 0.7 and 5.1). It needs one real player, so it runs in a play test through the RunTests
-- hook (section 16.3): the join placement (from the profile's `stats.banks`), run start on leaving home and the silent cancel on
-- coming back, a gulp with its `Phase` transitions, no respawn before "Swim again" (`RunAction`
-- op 1), the tap refused before the gulp card is up, the respawn within 0.8 s of the tap, and
-- the tier change events on growth and on loss. It ends with the creature at its cove, released to its owner.
-- Banking (task S5-C3; 09 §13.4, 12.5): a tier 2 bank pays mass × 3 Pearls and keeps one
-- specimen, a tier 1 bank pays Pearls only, a full cove keeps the new one as `pendingSpecimen`,
-- and an expired saved run is settled at join (scraps or the full bank, no specimen). The store is
-- ProfileStore.Mock in Studio, so the profile changes here are never saved.
-- With no player (CI) it registers one note. The pure rules are tests/unit/Logic/RunRules.spec.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BankMath = require(ReplicatedStorage.Shared.Logic.BankMath)
local Index = require(ReplicatedStorage.Shared.Data.Index)
local RunRules = require(ReplicatedStorage.Shared.Logic.RunRules)
local TestKit = require(ReplicatedStorage.Shared.Util.TestKit)
local VolumeMath = require(ReplicatedStorage.Shared.Logic.VolumeMath)

local CreatureService = require("../Services/CreatureService")
local DataService = require("../Services/DataService")
local EconomyService = require("../Services/EconomyService")
local PlayerLifecycle = require("../Services/PlayerLifecycle")
local RunLoopService = require("../Services/RunLoopService")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local WAIT = 10

local function waitFor(ready: () -> boolean, seconds: number?): boolean
	local from = os.clock()
	while not ready() do
		if os.clock() - from > (seconds or WAIT) then
			return false
		end
		task.wait()
	end
	return true
end

-- A point in open water outside the Nursery and outside the slot's cove.
local function outside(slot: number, from: Vector3): Vector3
	local nurseries = RunLoopService._test.nurseries()
	local cove = RunLoopService._test.coveVolumes(slot)
	for k = 1, 40 do
		for _, dir in { Vector3.xAxis, Vector3.zAxis, -Vector3.xAxis, -Vector3.zAxis } do
			local p = from + dir * (k * 25)
			if
				VolumeMath.firstContaining(nurseries, p.X, p.Y, p.Z) == nil
				and VolumeMath.firstContaining(cove, p.X, p.Y, p.Z) == nil
			then
				return p
			end
		end
	end
	error("no open water found near the spawn")
end

return function()
	describe("RunLoopService (engine)", function()
		local player = Players:GetPlayers()[1]
		if not player then
			it("(no player in this session: run it in a play test)", function() end)
			return
		end

		local function slotAndState(): (number, CreatureService.CreatureState)
			assert(
				waitFor(function()
					local s = PlayerLifecycle.getSlot(player)
					return s ~= nil and CreatureService.get(s) ~= nil
				end),
				"the player never spawned"
			)
			local slot = PlayerLifecycle.getSlot(player) :: number
			return slot, assert(CreatureService.get(slot))
		end

		local function goTo(slot: number, p: Vector3)
			CreatureService.teleport(slot, CFrame.new(p))
			RunLoopService._test.scan()
		end

		it(
			"keeps a RunState for the joined player, and its phase is the Phase attribute",
			function()
				local slot = slotAndState()
				local run = assert(RunLoopService._test.run(slot))
				expect(run.player).toBe(player)
				expect(player:GetAttribute("Phase")).toBe(RunLoopService.state(slot))
				-- Canon 5.5: never banked (`stats.banks == 0`) hatches in the Nursery, else the cove;
				-- the cove too on a map with no Nursery. Only the first run of the session counts.
				local profile = assert(DataService.get(player), "no profile for the player")
				if run.generation == 1 then
					local expected = RunRules.joinHome(profile.stats.banks > 0)
					if #RunLoopService._test.nurseries() == 0 then
						expected = "cove"
					end
					expect(run.home).toBe(expected)
				end
				-- A first run hatches at the HatchBed (09 §9.1) when the map has one.
				local beds = RunLoopService._test.hatchBeds()
				if run.home == "nursery" and #beds > 0 then
					expect(#beds).toBe(1) -- exactly one per place with a Nursery
				end
			end
		)

		it(
			"starts a run on leaving home and cancels it silently on coming back under mass 1",
			function()
				local slot, state = slotAndState()
				local run = assert(RunLoopService._test.run(slot))
				if run.phase == "dead" then
					expect(waitFor(function()
						return run.phase ~= "dead"
					end)).toBe(true)
				end
				-- Home for the test: the Nursery when this run started there and the map has one.
				local nurseries = RunLoopService._test.nurseries()
				local homeList = if run.home == "nursery"
					then nurseries
					else RunLoopService._test.coveVolumes(slot)
				if #homeList == 0 then
					return -- a map with no home volume for this slot: nothing to come back to
				end
				local home = Vector3.new(VolumeMath.centre(homeList[1]))
				CreatureService.addMass(slot, -state.mass) -- mass 0: under the armed mass
				goTo(slot, home)
				expect(run.phase).toBe("cove")
				expect(player:GetAttribute("Phase")).toBe("cove")

				goTo(slot, outside(slot, home))
				expect(run.phase).toBe("run")
				expect(player:GetAttribute("Phase")).toBe("run")
				expect(run.startedAt ~= nil).toBe(true)

				goTo(slot, home)
				expect(run.phase).toBe("cove")
				expect(run.startedAt).toBe(nil)

				goTo(slot, outside(slot, home))
				expect(run.phase).toBe("run")
			end
		)

		it(
			"sends the tier events on growth and loss, with 1.0 s of protection on a rise",
			function()
				local slot, state = slotAndState()
				local startTier = Index.Species.byId[state.species].startTier
				CreatureService.addMass(slot, Index.Tiers.byTier[startTier].massNeeded - state.mass)
				local need = Index.Tiers.byTier[startTier + 1].massNeeded
				CreatureService.addMass(slot, need - state.mass)
				expect(state.tier).toBe(startTier + 1)
				local sent = RunLoopService._test.lastSent()
				expect(sent).toEqual({ "tier" :: any, slot, startTier + 1, startTier })
				expect(player:GetAttribute("Protected")).toBe(true)
				expect(CreatureService.isProtected(slot)).toBe(true)

				CreatureService.addMass(slot, Index.Tiers.byTier[startTier].massNeeded - state.mass)
				expect(RunLoopService._test.lastSent()).toEqual({
					"tier" :: any,
					slot,
					startTier,
					startTier + 1,
				})
				expect(waitFor(function()
					return player:GetAttribute("Protected") == false
				end, RunRules.TIER_UP_PROTECT_SECONDS + 0.5)).toBe(true)
			end
		)

		it("refuses a gulp outside a run", function()
			local slot, state = slotAndState()
			local run = assert(RunLoopService._test.run(slot))
			local homeList = if run.home == "nursery"
				then RunLoopService._test.nurseries()
				else RunLoopService._test.coveVolumes(slot)
			if #homeList == 0 then
				return -- no home volume on this map: the creature is always in a run
			end
			CreatureService.addMass(slot, -state.mass)
			goTo(slot, Vector3.new(VolumeMath.centre(homeList[1])))
			expect(run.phase).toBe("cove")
			expect(RunLoopService.gulp(slot, "spec")).toBe(false)
			expect(run.phase).toBe("cove")
		end)

		it("gulps: dead and held until Swim again, then back at the cove within 0.8 s", function()
			local slot, state = slotAndState()
			local run = assert(RunLoopService._test.run(slot))
			if run.phase ~= "run" then
				goTo(slot, outside(slot, state.root.Position))
			end
			expect(run.phase).toBe("run")
			CreatureService.addMass(slot, 12) -- something to lose
			local phases: { string } = {}
			local watch = player:GetAttributeChangedSignal("Phase"):Connect(function()
				table.insert(phases, player:GetAttribute("Phase") :: string)
			end)
			local ok, problem = pcall(function()
				expect(RunLoopService._test.swimAgain(player)).toBe(false) -- not dead
				expect(RunLoopService.gulp(slot, "spec")).toBe(true)
				expect(RunLoopService.state(slot)).toBe("dead")
				expect(player:GetAttribute("Phase")).toBe("dead")
				-- Held: anchored, so the server simulates it (the ownership API errors on an
				-- anchored part, so the owner is not read here).
				expect(state.root.Anchored).toBe(true)
				expect(RunLoopService._test.lastSent()).toEqual({ "gulped" :: any, slot, "spec" })
				expect(RunLoopService.gulp(slot, "again")).toBe(false) -- once per death
				expect(RunLoopService._test.swimAgain(player)).toBe(false) -- the card is not up

				-- No timeout (02 §12.1): well past the old 2.0 s, still dead and held.
				task.wait(RunRules.RESPAWN_SECONDS + 0.5)
				expect(run.phase).toBe("dead")
				expect(state.root.Anchored).toBe(true)

				local t0 = os.clock()
				expect(RunLoopService._test.swimAgain(player)).toBe(true)
				expect(RunLoopService._test.swimAgain(player)).toBe(false) -- one tap respawns
				expect(waitFor(function()
					return run.phase ~= "dead"
				end, RunRules.RESPAWN_SECONDS + 1)).toBe(true)
				local took = os.clock() - t0
				-- 02 §12.4: within 0.8 s of the tap (09 §6.3 budget 2.0 s).
				expect(took <= RunRules.RESPAWN_TARGET_SECONDS + 0.1).toBe(true)
				expect(state.root.Anchored).toBe(false)
				expect(state.root:GetNetworkOwner()).toBe(player)
				local def = Index.Species.byId[state.species]
				expect(state.tier).toBe(def.startTier)
				expect(state.mass).toBe(Index.Tiers.byTier[def.startTier].massNeeded)
				expect(run.home).toBe("cove")
				local spawnAt = CreatureService.coveSpawnCFrame(slot).Position
				expect((state.root.Position - spawnAt).Magnitude < 3).toBe(true)
				task.wait() -- deferred attribute signals
				expect(phases[1]).toBe("dead")
				expect(phases[2]).toBe("cove")
			end)
			watch:Disconnect()
			assert(ok, problem)
		end)

		-- Banks a run at `mass` from open water into the own cove mouth; returns the Pearls paid,
		-- the specimen and pending counts before and after, or nil on a map with no own cove.
		local function bankAt(mass: number): RunLoopService.Banked?
			local slot, state = slotAndState()
			local run = assert(RunLoopService._test.run(slot))
			if run.phase == "dead" then
				expect(waitFor(function()
					return run.phase ~= "dead"
				end)).toBe(true)
			end
			local cove = RunLoopService._test.coveVolumes(slot)
			if #cove == 0 then
				return nil
			end
			local mouthAt: Vector3? = nil
			for _, v in cove do
				if v.kind == "CoveMouth" then
					mouthAt = Vector3.new(VolumeMath.centre(v))
				end
			end
			local inMouth = mouthAt or Vector3.new(VolumeMath.centre(cove[1]))
			goTo(slot, outside(slot, inMouth))
			if run.phase == "cove" then
				goTo(slot, outside(slot, inMouth)) -- left its Nursery or cove: a run
			end
			expect(run.phase).toBe("run")
			CreatureService.addMass(slot, mass - state.mass)
			goTo(slot, inMouth)
			expect(run.phase).toBe("cove")
			expect(player:GetAttribute("Phase")).toBe("cove")
			expect(run.home).toBe("cove") -- every later run starts at the cove
			return RunLoopService._test.lastBanked()
		end

		it("banks a tier 2 Minnow: mass × 3 Pearls and one specimen (Sprint 5)", function()
			local profile = assert(DataService.get(player))
			if #profile.cove.specimens >= profile.cove.slots or profile.cove.pendingSpecimen then
				return -- a full cove: the pending case below covers it
			end
			local pearls, specimens, banks =
				profile.pearls, #profile.cove.specimens, profile.stats.banks
			local deep = profile.passes.pass_deep_pockets == true
			local banked = bankAt(12)
			if banked == nil then
				return
			end
			expect(banked.tier).toBe(2)
			expect(banked.pearls).toBe(BankMath.bank(12, false, deep))
			if not deep then
				expect(banked.pearls).toBe(12 * 3)
			end
			profile = assert(DataService.get(player))
			expect(EconomyService.balance(player) - pearls).toBe(banked.pearls)
			expect(#profile.cove.specimens).toBe(specimens + 1)
			expect(banked.specimen).toBe("added")
			local rec = profile.cove.specimens[#profile.cove.specimens]
			expect(rec.sp).toBe(assert(CreatureService.get(banked.slot)).species)
			expect(rec.tier).toBe(2)
			expect(rec.mass).toBe(12)
			expect(profile.stats.banks).toBe(banks + 1)
			expect(profile.run).toBe(nil)
			-- The new Fry: back to the species' start mass at the cove spawn.
			local state = assert(CreatureService.get(banked.slot))
			local start = Index.Tiers.byTier[Index.Species.byId[state.species].startTier].massNeeded
			expect(state.mass).toBe(start)
			local sent = assert(RunLoopService._test.lastSent())
			-- The tier fall to the Fry follows the "banked" event.
			expect(sent[1] == "tier" or sent[1] == "banked").toBe(true)
		end)

		it("banks a tier 1 run for Pearls only", function()
			local profile = assert(DataService.get(player))
			local pearls, specimens = profile.pearls, #profile.cove.specimens
			local banked = bankAt(5)
			if banked == nil then
				return
			end
			expect(banked.tier).toBe(1)
			expect(banked.pearls).toBe(BankMath.bank(5, false, banked.deepPockets))
			expect(banked.specimen).toBe("none")
			profile = assert(DataService.get(player))
			expect(EconomyService.balance(player) - pearls).toBe(banked.pearls)
			expect(#profile.cove.specimens).toBe(specimens)
		end)

		it("keeps the new specimen as pendingSpecimen when the cove is full (02 §11.5)", function()
			local profile = assert(DataService.get(player))
			local saved = table.clone(profile.cove)
			saved.specimens = table.clone(profile.cove.specimens)
			local full = table.clone(profile.cove.specimens)
			while #full < profile.cove.slots do
				table.insert(full, {
					id = `spec{#full}`,
					sp = "minnow",
					tier = 2,
					mass = 10,
					traits = {},
					at = os.time(),
				})
			end
			DataService.patch(player, "cove.specimens", full)
			local ok: boolean, problem: any = pcall(function(): ()
				local banked = bankAt(15)
				if banked == nil then
					return
				end
				expect(banked.specimen).toBe("full")
				local now = assert(DataService.get(player))
				expect(#now.cove.specimens).toBe(#full)
				local pending = assert(now.cove.pendingSpecimen, "no pendingSpecimen")
				expect(pending.tier).toBe(2)
				expect(pending.mass).toBe(15)
			end)
			DataService.patch(player, "cove", saved) -- the cove as it was
			assert(ok, problem)
		end)

		it("settles an expired saved run at join: scraps or the full bank, no specimen", function()
			local profile = assert(DataService.get(player))
			local specimens = #profile.cove.specimens
			local function saveRun(fields: { [string]: any })
				local run: { [string]: any } = {
					sp = "minnow",
					mass = 40,
					tier = 3,
					traits = {},
					progress = {},
					startedAt = os.time() - 600,
					runSeconds = 300,
					platedUsed = false,
					reviveUsed = false,
					untrusted = false,
					x = 0,
					y = -30,
					z = 0,
					feedGuard = {},
				}
				for k, v in fields do
					run[k] = v
				end
				expect(DataService.patch(player, "run", run)).toBe(true)
			end
			local deep = profile.passes.pass_deep_pockets == true
			-- A disconnect that expired: scraps.
			local pearls, done = profile.pearls, profile.newcomer.runsCompleted
			local deaths = profile.stats.deaths
			saveRun({
				suspendedAt = os.time() - 400,
				expiresAt = os.time() - 100,
				onExpiry = "scraps",
			})
			expect(RunLoopService.settleExpired(player)).toBe(true)
			profile = assert(DataService.get(player))
			expect(profile.pearls - pearls).toBe(BankMath.scraps(40, false, deep, deaths))
			expect(profile.run).toBe(nil)
			expect(profile.newcomer.runsCompleted).toBe(done + 1)
			-- A shutdown that expired: the full bank in Pearls.
			pearls = profile.pearls
			saveRun({
				suspendedAt = os.time() - 1000,
				expiresAt = os.time() - 100,
				onExpiry = "bank_pearls",
			})
			expect(RunLoopService.settleExpired(player)).toBe(true)
			profile = assert(DataService.get(player))
			expect(profile.pearls - pearls).toBe(BankMath.bank(40, false, deep))
			-- Still inside its window: left for resume (S12-C4); nothing paid.
			pearls = profile.pearls
			saveRun({
				suspendedAt = os.time() - 10,
				expiresAt = os.time() + 290,
				onExpiry = "scraps",
			})
			expect(RunLoopService.settleExpired(player)).toBe(false)
			profile = assert(DataService.get(player))
			expect(profile.pearls).toBe(pearls)
			expect(profile.run ~= nil).toBe(true)
			DataService.patch(player, "run", nil)
			expect(#assert(DataService.get(player)).cove.specimens).toBe(specimens) -- no specimen
		end)
	end)
end
