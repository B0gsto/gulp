--!strict
-- Engine-side spec of PreyService on the CI arena (docs/09, sections 8.4 to 8.6 and 16.3). The
-- interest and spawn rules are covered in Lune (tests/unit/Logic/PreyInterest and PreySpawner);
-- this checks the service in the engine: the arena's rows are filled to their targets from the
-- Zone volumes, no Instance is created for prey, and the PreyState packets that go out are at most
-- 900 bytes and reach a player (the play test's own player when there is one), and scripted prey
-- (04 §3.5) stays with its slot through the service's own API.
-- In a VM where Main did not start the service (Open Cloud), the spec starts it here after
-- WorldIndexSpec has run WorldIndex.init in this VM; physics does not step there, so the spec drives
-- `PreyService.frame` by hand.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PreyInterest = require(ReplicatedStorage.Shared.Logic.PreyInterest)
local PreySim = require(ReplicatedStorage.Shared.Sim.PreySim)
local PreySpawnMath = require(ReplicatedStorage.Shared.Logic.PreySpawnMath)
local PreyState = require(ReplicatedStorage.Shared.Net.Codec.PreyState)
local TestKit = require(ReplicatedStorage.Shared.Util.TestKit)

local CreatureService = require("../Services/CreatureService")
local PreyService = require("../Services/PreyService")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function ensureRunning()
	if not PreyService.isRunning() then
		PreyService.init()
		PreyService.start()
	end
end

-- The first slot with a creature, if any.
local function firstSlot(): number?
	for slot = 1, 24 do
		if CreatureService.get(slot) then
			return slot
		end
	end
	return nil
end

return function()
	describe("PreyService", function()
		it(
			"fills the arena's zones to their targets (Reef, Nursery, Kelp; trait prey too)",
			function()
				ensureRunning()
				local sim, _, spawner = PreyService.internals()
				local zones: { [string]: number } = {}
				for _, row in spawner.rows do
					zones[row.zone] = (zones[row.zone] or 0) + row.count
					-- At most one group short (one may have been eaten or culled since the fill).
					expect(row.count >= row.target - 1 and row.count <= math.ceil(row.target * 1.5)).toBe(
						true
					)
				end
				expect((zones.reef or 0) > 0 and (zones.nursery or 0) > 0 and (zones.kelp or 0) > 0).toBe(
					true
				)
				-- The reef's krill row: data:PreySpawns through PreySpawnMath at the arena's areaScale.
				local reefScale = 512 * 512 / 502655
				for _, row in spawner.rows do
					if row.zone == "reef" and row.prey == "krill" and row.spawnDef then
						local want = PreySpawnMath.target(row.spawnDef, {
							players = spawner.players,
							area = reefScale * row.spawnDef.zoneArea,
							frenzy = spawner.rate > 1,
						})
						expect(row.target).toBe(want)
					end
				end
				expect(sim.liveGroups > 20).toBe(true)
			end
		)

		it("creates no Instance for prey while stepping, spawning and despawning", function()
			ensureRunning()
			local before = #workspace:GetDescendants() + #ReplicatedStorage:GetDescendants()
			for _ = 1, 12 do
				PreyService.frame()
			end
			PreyService.spawnEventPrey("moon_tide")
			PreyService.clearEventPrey()
			PreyService.stunNear(0, -50, 0, 50, 7, 1)
			local after = #workspace:GetDescendants() + #ReplicatedStorage:GetDescendants()
			expect(after).toBe(before)
		end)

		it("builds packets of at most 900 bytes, and sends them to a player", function()
			ensureRunning()
			local sim = PreyService.internals()
			-- Pure check from the middle of the arena, with a fresh send state.
			local state = PreyInterest.new(1)
			local payload = PreyInterest.updatePlayer(state, sim, 1, 0, -50, 0)
			expect(payload ~= nil).toBe(true)
			local p = payload :: buffer
			expect(buffer.len(p) <= PreyState.MAX_BYTES and PreyState.valid(p)).toBe(true)
			local slot = firstSlot()
			if slot then
				-- A player is here (play test): the service has sent it packets, none over 900 bytes.
				PreyService.resetStats()
				for _ = 1, 12 do
					PreyService.frame()
				end
				local stats = PreyService.stats()
				expect(stats.packets > 0).toBe(true)
				expect(stats.maxPacket <= PreyState.MAX_BYTES).toBe(true)
				expect(sim.tick > 0 and PreySim.MAX_GROUPS == PreyState.MAX_GROUPS).toBe(true)
			end
		end)

		it("keeps scripted prey to its slot, away from any spawn volume, until cleared", function()
			ensureRunning()
			local sim, _, spawner = PreyService.internals()
			local slot = 24
			while slot > 2 and CreatureService.get(slot) do
				slot -= 1
			end
			-- Another slot: the play test's own creature when there is one.
			local other = firstSlot() or slot - 1
			-- Swarm A and a trail of 10 motes every 4 studs, far outside the arena's volumes.
			local swarm = PreyService.spawnScripted(slot, {
				preyId = "krill",
				count = 6,
				centre = Vector3.new(800, -50, 800),
				spread = 3,
			})
			local motes = {}
			for k = 0, 9 do
				table.insert(motes, Vector3.new(806 + 4 * k, -50, 800))
			end
			local trail =
				PreyService.spawnScripted(slot, { preyId = "plankton", positions = motes })
			expect(swarm ~= nil and trail ~= nil).toBe(true)
			expect(PreyService.stats().scriptedGroups).toBe(11)
			local part = spawner.owned[swarm :: number].parts[1]
			expect(PreySim.ownerOf(sim, part.g)).toBe(slot)
			for _ = 1, 12 do
				PreyService.frame()
			end
			-- Interest from the swarm's own point: the owner is sent it, another slot never is.
			local state = PreyInterest.new(24)
			local function sent(s: number): boolean
				local payload = PreyInterest.updatePlayer(state, sim, s, 800, -50, 800)
				if payload == nil then
					return false
				end
				local _, _, f = PreyState.header(payload)
				local full = PreyState.newFull()
				for k = 0, f - 1 do
					PreyState.readFull(payload, k, full)
					if full.groupId == part.g then
						return true
					end
				end
				return false
			end
			expect(sent(other)).toBe(false)
			expect(sent(slot)).toBe(true)
			-- Another slot cannot eat it, even once it has faded in.
			local later = workspace:GetServerTimeNow() + 1
			expect((PreyService.tryEat(other, part.g, 0, part.gen, later))).toBe(false)
			expect(PreySim.memberAlive(sim, part.g, 0)).toBe(true)
			PreyService.clearScripted(slot)
			expect(PreySim.isLive(sim, part.g, part.gen)).toBe(false)
			expect(PreyService.stats().scriptedGroups).toBe(0)
		end)
	end)
end
