--!strict
-- Engine-side spec of BiteService, prey bites (docs/09, sections 8.9 and 14.2; section 20, R5).
-- It needs the play test's player and creature, so it runs through the RunTests hook (16.3). It
-- places the creature's mouth on a live prey member with CreatureService.teleport and calls
-- BiteService.claim synchronously (nothing steps in between), then puts the creature and its mass
-- back. The claim arithmetic (reach, time window, clamp) is covered in Lune by
-- tests/unit/Logic/BiteMath. With no player (CI) it registers one note.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bite = require(ReplicatedStorage.Shared.Net.Codec.Bite)
local BiteMath = require(ReplicatedStorage.Shared.Logic.BiteMath)
local BiteResult = require(ReplicatedStorage.Shared.Net.Codec.BiteResult)
local Formation = require(ReplicatedStorage.Shared.Sim.Formation)
local PreySim = require(ReplicatedStorage.Shared.Sim.PreySim)
local PreySpawner = require(ReplicatedStorage.Shared.Logic.PreySpawner)
local TestKit = require(ReplicatedStorage.Shared.Util.TestKit)
local Types = require(ReplicatedStorage.Shared.Types)

local BiteService = require("../Services/BiteService")
local CreatureService = require("../Services/CreatureService")
local PreyService = require("../Services/PreyService")
local Server = require("../Net/Server")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type CreatureState = CreatureService.CreatureState
type PreyDef = Types.PreyDef

local WAIT = 10

local function creatureOf(player: Player): CreatureState?
	local from = os.clock()
	while os.clock() - from < WAIT do
		local slot = player:GetAttribute("Slot")
		local state = if type(slot) == "number" then CreatureService.get(slot) else nil
		if state and state.player == player then
			return state
		end
		task.wait(0.05)
	end
	return nil
end

type Target = { g: number, i: number, gen: number, def: PreyDef }

-- The first alive, faded-in member of a live group whose PreyDef passes `want`.
local function findMember(now: number, want: (PreyDef) -> boolean): Target?
	local sim, _, spawner = PreyService.internals()
	for g = 0, PreySim.MAX_GROUPS - 1 do
		if
			not PreySim.isLive(sim, g) or not PreySpawner.edibleAt(spawner, g, now - Server.EPOCH)
		then
			continue
		end
		local def = Formation.defOf(buffer.readu8(sim.buffers.kind, g))
		if def == nil or not want(def) then
			continue
		end
		for i = 0, PreySim.MAX_MEMBERS - 1 do
			if PreySim.memberAlive(sim, g, i) then
				return { g = g, i = i, gen = buffer.readu8(sim.buffers.gen, g), def = def }
			end
		end
	end
	return nil
end

-- Puts the creature's mouth (BiteMath.mouth) on the member's position at `now`, or `offset`
-- studs past it.
local function placeMouth(state: CreatureState, target: Target, now: number, offset: number)
	local px, py, pz = PreyService.memberPosAt(target.g, target.i, now)
	local prey = Vector3.new(px, py, pz)
	-- The server's mouth (09 §8.9): dash factor on, mouthMult, lengthMult and firstRun 1.
	local r = BiteMath.serverRadius(state.bodyScale, 1, 1)
	local back = BiteMath.mouthAhead(state.bodyScale, 1, r) + offset
	local at = prey - Vector3.new(0, 0, -1) * back
	CreatureService.teleport(state.slot, CFrame.lookAt(at, at + Vector3.new(0, 0, -1)))
end

local function claimOne(player: Player, seq: number, now: number, t: Target, gen: number?)
	local payload = Bite.encodePrey(seq, (now - Server.EPOCH) * 1000, 1)
	Bite.writePrey(payload, 0, t.g, t.i, gen or t.gen)
	return BiteResult.decode(BiteService.claim(player, payload, now))
end

return function()
	describe("BiteService (engine)", function()
		local player = Players:GetPlayers()[1]
		if not player then
			it("(no player in this session: run it in a play test)", function() end)
			return
		end

		it("routes Bite and keeps reject counters by reason (R5)", function()
			expect(Server.isRouted("Bite")).toBe(true)
			local c = BiteService.counters()
			expect(type(c.claims) == "number" and type(c.rejects) == "table").toBe(true)
			expect(type(c.far) == "number" and type(c.worstRange) == "number").toBe(true)
		end)

		it("accepts a claim on a member at the mouth, and the mass grows", function()
			local state = creatureOf(player) :: CreatureState
			expect(state ~= nil).toBe(true)
			BiteService.forget(player)
			local home = state.root.CFrame
			local now = workspace:GetServerTimeNow()
			local target = findMember(now, function(def)
				return def.tier <= state.tier and def.mass > 0
			end)
			expect(target ~= nil).toBe(true)
			local t = target :: Target
			local mass0, accepted0 = state.mass, BiteService.counters().accepted
			placeMouth(state, t, now, 0)
			local seq, mask, reason, newMass, newTier = claimOne(player, 7, now, t)
			-- The same member again: gone.
			local _, mask2, reason2 = claimOne(player, 8, now, t)
			CreatureService.teleport(state.slot, home)
			local gained = state.mass - mass0
			CreatureService.addMass(state.slot, -gained)
			expect(seq).toBe(7)
			expect(mask).toBe(1)
			expect(reason).toBe(BiteResult.REASON_NONE)
			expect(gained > 0).toBe(true)
			expect(newMass).toBeCloseTo(mass0 + gained, 1e-3)
			expect(newTier >= 1).toBe(true)
			expect(BiteService.counters().accepted).toBe(accepted0 + 1)
			local sim = PreyService.internals()
			expect(PreySim.memberAlive(sim, t.g, t.i)).toBe(false)
			expect(mask2).toBe(0)
			expect(reason2).toBe(BiteResult.REASON_GONE)
		end)

		it("rejects far, stale-generation and wrong-tier claims with their reasons", function()
			local state = creatureOf(player) :: CreatureState
			BiteService.forget(player)
			local home = state.root.CFrame
			local now = workspace:GetServerTimeNow()
			local before = BiteService.counters()
			local near = findMember(now, function(def)
				return def.tier <= state.tier
			end) :: Target
			local big = findMember(now, function(def)
				return def.tier > state.tier
			end)
			expect(near ~= nil).toBe(true)
			-- Far: the mouth 200 studs from the member.
			placeMouth(state, near, now, 200)
			local _, farMask, farReason = claimOne(player, 1, now, near)
			-- Stale generation: the mouth on the member, the gen one off.
			placeMouth(state, near, now, 0)
			local _, staleMask, staleReason = claimOne(player, 2, now, near, (near.gen + 1) % 256)
			local tierMask, tierReason = 0, BiteResult.REASON_TIER
			if big then
				placeMouth(state, big, now, 0)
				_, tierMask, tierReason = claimOne(player, 3, now, big)
			end
			CreatureService.teleport(state.slot, home)
			local after = BiteService.counters()
			expect(farMask).toBe(0)
			expect(farReason).toBe(BiteResult.REASON_RANGE)
			expect(after.rejects.range).toBe((before.rejects.range or 0) + 1)
			expect(after.far).toBe(before.far + 1)
			expect(after.worstRange > BiteMath.FAR_FACTOR).toBe(true)
			expect(staleMask).toBe(0)
			expect(staleReason).toBe(BiteResult.REASON_GONE)
			expect(big ~= nil).toBe(true) -- the arena has prey above the starting tier
			expect(tierMask).toBe(0)
			expect(tierReason).toBe(BiteResult.REASON_TIER)
			-- The member survived every rejected claim.
			local sim = PreyService.internals()
			expect(PreySim.memberAlive(sim, near.g, near.i)).toBe(true)
		end)

		it("rejects a flood past 20 prey targets with reason rate (02 §4.6)", function()
			local state = creatureOf(player) :: CreatureState
			BiteService.forget(player)
			local now = workspace:GetServerTimeNow()
			local before = BiteService.counters()
			local sim = PreyService.internals()
			local empty = PreySim.MAX_GROUPS - 1
			while PreySim.isLive(sim, empty) do
				empty -= 1
			end
			local reasons = {}
			for seq = 1, 4 do
				local payload = Bite.encodePrey(seq, (now - Server.EPOCH) * 1000, 8)
				for k = 0, 7 do
					Bite.writePrey(payload, k, empty, k, 0) -- not a live group: gone, until the rate
				end
				local _, mask, reason = BiteResult.decode(BiteService.claim(player, payload, now))
				expect(mask).toBe(0)
				reasons[seq] = reason
			end
			BiteService.forget(player)
			local after = BiteService.counters()
			expect(reasons[1]).toBe(BiteResult.REASON_GONE)
			expect(reasons[3]).toBe(BiteResult.REASON_GONE) -- 4 gone, then 4 rate: the first decides
			expect(reasons[4]).toBe(BiteResult.REASON_RATE)
			expect(after.rejects.rate).toBe((before.rejects.rate or 0) + 12)
			expect(after.rejects.gone).toBe((before.rejects.gone or 0) + 20)
			expect(state.mass >= 0).toBe(true)
		end)
	end)
end
