--!strict
-- Engine-side spec of PreyService on the CI arena (docs/09, sections 8.4 to 8.6 and 16.3). The
-- interest and spawn rules are covered in Lune (tests/unit/Logic/PreyInterest and PreySpawner);
-- this checks the service in the engine: the arena's rows are filled to their targets from the
-- Zone volumes, no Instance is created for prey, and the PreyState packets that go out are at most
-- 900 bytes and reach a player (the play test's own player when there is one), and scripted prey
-- (04 §3.5) stays with its slot's creature through the service's own API. Open Cloud has no
-- players, so the scripted prey checks give a slot a stand-in creature (`standIn`).
-- In a VM where Main did not start the service (Open Cloud), the spec starts it here after
-- WorldIndexSpec has run WorldIndex.init in this VM; physics does not step there, so the spec drives
-- `PreyService.frame` by hand.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formation = require(ReplicatedStorage.Shared.Sim.Formation)
local PreyInterest = require(ReplicatedStorage.Shared.Logic.PreyInterest)
local PreySim = require(ReplicatedStorage.Shared.Sim.PreySim)
local PreySpawnMath = require(ReplicatedStorage.Shared.Logic.PreySpawnMath)
local PreySpawner = require(ReplicatedStorage.Shared.Logic.PreySpawner)
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

-- The highest slot with no creature (Open Cloud has none; a play test has its own player's).
local function freeSlot(): number
	local slot = 24
	while slot > 2 and CreatureService.get(slot) do
		slot -= 1
	end
	return slot
end

type StandIn = { swap: () -> (), gap: () -> (), done: () -> () }

-- A creature of the spec's own in `slot` (PreyService.setCreatureLookup): a tier 2 creature with
-- an unparented root at `at` and no player, so it gets no packets. `swap` puts a new creature in
-- the slot, `gap` leaves it empty, `done` puts CreatureService.get back.
local function standIn(slot: number, at: Vector3): StandIn
	local function make(): any
		local root = Instance.new("Part")
		root.Position = at
		return { slot = slot, tier = 2, mass = 10, bodyScale = 1, root = root }
	end
	local current: any = make()
	PreyService.setCreatureLookup(function(s: number): any
		if s == slot then
			return current
		end
		return CreatureService.get(s)
	end)
	return {
		swap = function()
			current.root:Destroy()
			current = make()
		end,
		gap = function()
			if current then
				current.root:Destroy()
			end
			current = nil
		end,
		done = function()
			if current then
				current.root:Destroy()
			end
			current = nil
			PreyService.setCreatureLookup(nil)
		end,
	}
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

		it("refuses scripted prey for a slot with no creature", function()
			ensureRunning()
			local slot = freeSlot()
			expect(PreyService.spawnScripted(slot, {
				preyId = "krill",
				count = 6,
				centre = Vector3.new(800, -50, 800),
				spread = 3,
			})).toBe(nil)
			expect(PreyService.stats().scriptedGroups).toBe(0)
		end)

		it("keeps scripted prey to its slot's creature, away from any spawn volume", function()
			ensureRunning()
			local sim, _, spawner = PreyService.internals()
			local slot = freeSlot()
			-- Another slot: the play test's own creature when there is one.
			local other = firstSlot() or slot - 1
			local stand = standIn(slot, Vector3.new(780, -50, 800))
			-- Swarm A and a trail of 10 motes every 4 studs, far outside the arena's volumes.
			local swarm = PreyService.spawnScripted(slot, {
				preyId = "krill",
				count = 6,
				centre = Vector3.new(800, -50, 800),
				spread = 3,
				calm = true,
			})
			local motes = {}
			for k = 0, 9 do
				table.insert(motes, Vector3.new(806 + 4 * k, -50, 800))
			end
			local trail =
				PreyService.spawnScripted(slot, { preyId = "plankton", positions = motes })
			expect(swarm ~= nil and trail ~= nil).toBe(true)
			local stats = PreyService.stats()
			expect(stats.scriptedGroups).toBe(11)
			expect(stats.scriptedMembers).toBe(16)
			local part = spawner.owned[swarm :: number].parts[1]
			expect(PreySim.ownerOf(sim, part.g)).toBe(slot)
			for _ = 1, 12 do
				PreyService.frame()
			end
			expect(PreySim.isLive(sim, part.g, part.gen)).toBe(true) -- the stand-in holds it
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
			-- To another slot it is gone: peek says so, tryEat refuses, even once it has faded in.
			expect((PreyService.peek(other, part.g, 0, part.gen))).toBe(nil)
			expect((PreyService.peek(slot, part.g, 0, part.gen))).toBe(
				Formation.defOf(buffer.readu8(sim.buffers.kind, part.g))
			)
			local later = workspace:GetServerTimeNow() + 1
			expect((PreyService.tryEat(other, part.g, 0, part.gen, later))).toBe(false)
			expect(PreySim.memberAlive(sim, part.g, 0)).toBe(true)
			-- Spark leaves it alone.
			PreyService.stunNear(800, -50, 800, 20, 7, 1)
			expect(bit32.btest(buffer.readu8(sim.buffers.flags, part.g), PreySim.FLAG_STUNNED)).toBe(
				false
			)
			-- Its owner eats it. onScriptedEaten fires once, after the call, so a listener that
			-- throws (one error line in the log, expected) does not reach the caller.
			local heard: { { slot: number, id: number, prey: string } } = {}
			local good = PreyService.onScriptedEaten:connect(function(s, id, prey)
				table.insert(heard, { slot = s, id = id, prey = prey })
			end)
			local bad = PreyService.onScriptedEaten:connect(function()
				error("PreySpec: a listener that throws (expected)")
			end)
			expect((PreyService.tryEat(slot, part.g, 0, part.gen, later))).toBe(true)
			expect(#heard).toBe(0)
			task.wait()
			good:disconnect()
			bad:disconnect()
			expect(#heard).toBe(1)
			expect(heard[1].slot == slot and heard[1].id == swarm and heard[1].prey == "krill").toBe(
				true
			)
			expect(PreySim.memberAlive(sim, part.g, 0)).toBe(false)
			PreyService.clearScripted(slot)
			expect(PreySim.isLive(sim, part.g, part.gen)).toBe(false)
			expect(PreyService.stats().scriptedGroups).toBe(0)
			stand.done()
		end)

		it("steers a scripted group's leash toward its owner, members following", function()
			ensureRunning()
			local sim, _, spawner = PreyService.internals()
			local slot = freeSlot()
			local stand = standIn(slot, Vector3.new(800, -50, 830))
			local id = PreyService.spawnScripted(slot, {
				preyId = "krill",
				count = 6,
				centre = Vector3.new(800, -50, 800),
				spread = 3,
				calm = true,
			}) :: number
			local part = spawner.owned[id].parts[1]
			expect(PreyService.steerScripted(slot + 1, id, Vector3.new(800, -50, 830), 6)).toBe(
				false
			)
			expect(PreyService.steerScripted(slot, id, Vector3.new(800, -50, 830), 0)).toBe(false)
			-- 04 §3.6 B3: inside 25 studs, toward the player at 6 studs/s.
			expect(PreyService.steerScripted(slot, id, Vector3.new(800, -50, 830), 6)).toBe(true)
			for _ = 1, 24 do
				PreyService.frame()
			end
			local _, _, cz = PreySpawner.ownedCentre(spawner, id)
			-- Four ticks of 0.05 to 0.25 s at 6 studs/s.
			expect(cz >= 800 + 4 * 6 * 0.05 - 1e-3 and cz <= 800 + 4 * 6 * 0.25 + 1e-3).toBe(true)
			local home = (PreySim.OWNED_HOME + part.g) * 20
			expect(buffer.readf32(sim.homes, home + 8)).toBeCloseTo(cz, 1e-3)
			local z = buffer.readf32(sim.buffers.posZ, part.g * 4)
			expect(math.abs(z - cz) <= 4.5 + 1e-3).toBe(true)
			expect(bit32.btest(buffer.readu8(sim.buffers.flags, part.g), PreySim.FLAG_FLEEING)).toBe(
				false
			)
			expect(PreyService.steerScripted(slot, id, nil)).toBe(true)
			PreyService.clearScripted(slot)
			stand.done()
		end)

		it("ends a slot's scripted prey when its creature changes or goes", function()
			ensureRunning()
			local sim, _, spawner = PreyService.internals()
			local slot = freeSlot()
			local stand = standIn(slot, Vector3.new(780, -50, 800))
			local function spawnOne(): PreySpawner.OwnedPart
				local id = PreyService.spawnScripted(slot, {
					preyId = "krill",
					count = 3,
					centre = Vector3.new(800, -50, 800),
					spread = 3,
					respawns = true,
				}) :: number
				return spawner.owned[id].parts[1]
			end
			-- A new creature in the slot (a new player, or a new run): gone on the next tick.
			local part = spawnOne()
			stand.swap()
			for _ = 1, 6 do
				PreyService.frame()
			end
			expect(PreySim.isLive(sim, part.g, part.gen)).toBe(false)
			-- No creature (left, or gulped): gone too, and its budget is back.
			part = spawnOne()
			stand.gap()
			for _ = 1, 6 do
				PreyService.frame()
			end
			expect(PreySim.isLive(sim, part.g, part.gen)).toBe(false)
			expect(spawner.ownedBySlot[slot] or 0).toBe(0)
			expect(PreyService.stats().scriptedGroups).toBe(0)
			stand.done()
		end)
	end)
end
