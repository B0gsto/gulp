--!strict
-- Engine-side spec of CoveService (docs/09, sections 5.1, 5.3 and 13; task S5-C2). Stand-in
-- players (plain tables) run anywhere, CI included: CoveService and EconomyService share one fake
-- profile store, the clock is injected so hours pass at once, and CoveView is caught by the send
-- hook. With a real player in a play test, the last case checks the cove PlayerLifecycle opened.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoveIncome = require(ReplicatedStorage.Shared.Logic.CoveIncome)
local CoveRules = require(ReplicatedStorage.Shared.Logic.CoveRules)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local SaveSchema = require(ReplicatedStorage.Shared.Logic.SaveSchema)
local StatePatch = require(ReplicatedStorage.Shared.Logic.StatePatch)
local TestKit = require(ReplicatedStorage.Shared.Util.TestKit)
local Types = require(ReplicatedStorage.Shared.Types)

local Analytics = require("../Services/Analytics")
local CoveService = require("../Services/CoveService")
local EconomyService = require("../Services/EconomyService")
local PlayerLifecycle = require("../Services/PlayerLifecycle")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local HOUR = 3600
local T0 = 1_800_000_000
-- The stand-in's cove: the highest one nobody holds (a play test's real player keeps theirs).
local SLOT = 24

local nextId = -9500

type Sent = { player: Player, name: string, value: any }

-- Runs `body` with a stand-in player whose profile (a fresh save with `pearls`) is shared by
-- CoveService and EconomyService, a clock set by `at(t)`, and the sends recorded.
local function withCove(
	pearls: number,
	body: (
		player: Player,
		data: Types.ProfileData,
		at: (number) -> (),
		sent: { Sent }
	) -> ()
)
	nextId -= 1
	local player = (
		{ UserId = nextId, Name = `cove{-nextId}`, DisplayName = "Spec Owner" } :: any
	) :: Player
	local data = SaveSchema.template() :: any
	data.pearls = pearls
	local store = {
		get = function(who: Player): Types.ProfileData?
			return if who == player then data else nil
		end,
		patch = function(who: Player, path: string, value: any): boolean
			if who ~= player or (path ~= "cove" and path ~= "pearls") then
				return false
			end
			data[path] = StatePatch.copy(value)
			return true
		end,
	}
	local now = T0
	local sent: { Sent } = {}
	SLOT = 24
	while CoveService.ownerOf(SLOT) ~= nil do
		SLOT -= 1
	end
	CoveService._test.useStore(store)
	EconomyService._test.useStore(store)
	CoveService._test.useClock(function()
		return now
	end)
	CoveService._test.onSend(function(who: Player, name: string, value: any)
		table.insert(sent, { player = who, name = name, value = value })
	end)
	local ok, problem = pcall(function()
		CoveService.open(player, SLOT)
		body(player, data, function(t: number)
			now = t
		end, sent)
	end)
	CoveService.close(player)
	CoveService._test.useStore(nil)
	CoveService._test.useClock(nil)
	CoveService._test.onSend(nil)
	EconomyService._test.useStore(nil)
	Analytics.forget(player)
	if not ok then
		error(problem, 0)
	end
end

local function rec(tier: number, traits: { string }?): Types.SpecimenRecord
	return { id = "", sp = "minnow", tier = tier, mass = 123.45, traits = traits or {}, at = 0 }
end

local function quietly(body: () -> ())
	Log.setSink(function() end)
	local ok, problem = pcall(body :: () -> unknown)
	Log.setSink(nil)
	if not ok then
		error(problem, 0)
	end
end

return function()
	describe("CoveService (engine)", function()
		it("fills the free slots, then keeps the new one waiting (cove full)", function()
			withCove(0, function(player, data)
				for _ = 1, 6 do
					expect(CoveService.addSpecimen(player, rec(2))).toBe("added")
				end
				expect(#data.cove.specimens).toBe(6)
				local first = data.cove.specimens[1]
				expect(#first.id).toBe(8)
				expect(first.mass).toBe(123.5)
				expect(first.at).toBe(T0)
				expect(CoveService.addSpecimen(player, rec(3))).toBe("full")
				expect((data.cove.pendingSpecimen :: Types.SpecimenRecord).tier).toBe(3)
				quietly(function()
					expect(CoveService.addSpecimen(player, rec(3))).toBe("refused")
					expect(CoveService.addSpecimen(player, rec(1))).toBe("refused")
				end)
				expect(#data.cove.specimens).toBe(6)
			end)
		end)

		it("claims the pile through EconomyService after 10 minutes, to the Pearl", function()
			withCove(100, function(player, data, at)
				local traits = { "spots", "plated" }
				CoveService.addSpecimen(player, rec(5, traits))
				expect((data.cove.lastClaim :: any).at).toBe(T0)
				at(T0 + 600)
				local length = #Analytics.buffer()
				local want = math.floor(CoveIncome.specimenRate(5, traits) * 600 / HOUR)
				expect(CoveService.claimIncome(player)).toBe(want)
				expect(data.pearls).toBe(100 + want)
				expect((data.cove.lastClaim :: any).at).toBe(T0 + 600)
				expect(data.cove.pending).toBeCloseTo(0.5, 1e-9)
				local logged = 0
				for i, r in Analytics.buffer() do
					if i > length and r.userId == player.UserId then
						logged += 1
					end
				end
				expect(logged).toBe(1)
			end)
		end)

		it(
			"stops the pile 8 hours after the last claim; the CoveAction claim op pays it",
			function()
				withCove(0, function(player, data, at)
					CoveService.addSpecimen(player, rec(3)) -- 10 Pearls/h
					at(T0 + 30 * HOUR)
					CoveService._test.action(player, CoveRules.Op.claim, 0)
					expect(data.pearls).toBe(80)
					expect(CoveService.claimIncome(player)).toBe(0)
					expect(data.pearls).toBe(80)
				end)
			end
		)

		it(
			"buys slot 7 for 1,200 Pearls; the waiting specimen moves in; a short balance buys nothing",
			function()
				withCove(1500, function(player, data)
					for _ = 1, 7 do
						CoveService.addSpecimen(player, rec(2))
					end
					expect(CoveService.buySlot(player)).toBe(true)
					expect(data.pearls).toBe(300)
					expect(data.cove.slots).toBe(7)
					expect(#data.cove.specimens).toBe(7)
					expect(data.cove.pendingSpecimen).toBe(nil)
					expect(CoveService.buySlot(player)).toBe(false) -- slot 8 costs 1,500
					expect(data.cove.slots).toBe(7)
					expect(data.pearls).toBe(300)
				end)
			end
		)

		it("releases a specimen for its refund through the release op", function()
			withCove(0, function(player, data)
				CoveService.addSpecimen(player, rec(5, { "spots", "plated" }))
				local id = data.cove.specimens[1].id
				CoveService._test.action(player, CoveRules.Op.release, id)
				expect(#data.cove.specimens).toBe(0)
				expect(data.pearls).toBe(39)
				expect(CoveService.release(player, id)).toBe(false)
			end)
		end)

		it("sends the CoveView of a cove to the viewer", function()
			withCove(0, function(player, _data, _at, sent)
				CoveService.addSpecimen(player, rec(4, { "glow" }))
				expect(CoveService.ownerOf(SLOT)).toBe(player)
				expect(CoveService.view(player, SLOT)).toBe(true)
				expect(#sent).toBe(1)
				expect(sent[1].player).toBe(player)
				expect(sent[1].name).toBe("CoveView")
				local view = sent[1].value :: CoveRules.View
				expect(view.slot).toBe(SLOT)
				expect(view.owner).toBe("Spec Owner")
				expect(view.slots).toBe(6)
				expect(view.specimens[1].tier).toBe(4)
			end)
			expect(CoveService.ownerOf(SLOT)).toBe(nil)
		end)

		it("opens the cove of a joined player and sends them its CoveView (play test)", function()
			local player = Players:GetPlayers()[1]
			if not player then
				return -- no player in CI's Luau execution
			end
			local slot = PlayerLifecycle.getSlot(player)
			expect(slot ~= nil).toBe(true)
			expect(CoveService.ownerOf(slot :: number)).toBe(player)
			expect(CoveService.view(player, slot :: number)).toBe(true)
		end)
	end)
end
