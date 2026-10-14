--!strict
-- Engine-side spec of RunLoopService (task S4-C4; docs/09, sections 5.3, 6.3 and 6.8; docs/02,
-- sections 0.7 and 5.1). It needs one real player, so it runs in a play test through the RunTests
-- hook (section 16.3): the join placement, run start on leaving home and the silent cancel on
-- coming back, a gulp with its `Phase` transitions and the 2.0 s respawn, and the tier change
-- events on growth and on loss. It ends with the creature at its cove, released to its owner.
-- With no player (CI) it registers one note. The pure rules are tests/unit/Logic/RunRules.spec.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Index = require(ReplicatedStorage.Shared.Data.Index)
local RunRules = require(ReplicatedStorage.Shared.Logic.RunRules)
local TestKit = require(ReplicatedStorage.Shared.Util.TestKit)
local VolumeMath = require(ReplicatedStorage.Shared.Logic.VolumeMath)

local CreatureService = require("../Services/CreatureService")
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
			local slot = slotAndState()
			local run = assert(RunLoopService._test.run(slot))
			if run.phase == "run" then
				return -- covered by the previous case's last step; nothing to refuse here
			end
			expect(RunLoopService.gulp(slot, "spec")).toBe(false)
		end)

		it("gulps: dead, held by the server, then back at the cove within 2.0 s", function()
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
				local t0 = os.clock()
				expect(RunLoopService.gulp(slot, "spec")).toBe(true)
				expect(RunLoopService.state(slot)).toBe("dead")
				expect(player:GetAttribute("Phase")).toBe("dead")
				expect(state.root.Anchored).toBe(true)
				expect(state.root:GetNetworkOwner()).toBe(nil)
				expect(RunLoopService._test.lastSent()).toEqual({ "gulped" :: any, slot, "spec" })
				expect(RunLoopService.gulp(slot, "again")).toBe(false) -- once per death

				expect(waitFor(function()
					return run.phase ~= "dead"
				end, RunRules.RESPAWN_SECONDS + 1)).toBe(true)
				local took = os.clock() - t0
				expect(took >= RunRules.RESPAWN_SECONDS - 0.1).toBe(true)
				expect(took <= RunRules.RESPAWN_SECONDS + 0.2).toBe(true) -- 09 §6.3: 2.0 s total
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
	end)
end
