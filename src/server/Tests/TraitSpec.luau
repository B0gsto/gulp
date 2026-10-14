--!strict
-- Engine-side spec of TraitService (task S6-C3; docs/02, section 8; docs/09, sections 5.1 and
-- 5.3). A stand-in creature (a plain table with a stand-in player that keeps attributes) runs
-- anywhere, CI included: `_test.stub` points the service at it and records every send. With a real
-- player in a play test, the last case checks that the real creature carries the trait fields and
-- the `Traits` attribute. The rules' arithmetic is tests/unit/Logic/TraitRules.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Index = require(ReplicatedStorage.Shared.Data.Index)
local TestKit = require(ReplicatedStorage.Shared.Util.TestKit)
local TraitRules = require(ReplicatedStorage.Shared.Logic.TraitRules)

local CreatureService = require("../Services/CreatureService")
local TraitService = require("../Services/TraitService")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type CreatureState = CreatureService.CreatureState

local SLOT = 23 -- a slot no real player of a play test holds

type Sent = { name: string, args: { any } }

-- Runs `body` with a stand-in creature in SLOT (Phase `run`) and the sends recorded.
local function withCreature(body: (state: CreatureState, sent: { Sent }) -> ())
	local attributes: { [string]: any } = { Phase = "run", Traits = "" }
	local player = {
		UserId = -9700,
		SetAttribute = function(_self: any, name: string, value: any)
			attributes[name] = value
		end,
		GetAttribute = function(_self: any, name: string): any
			return attributes[name]
		end,
	}
	-- Safe cast: TraitService reads only `player` (attributes) and the trait fields.
	local state = (
		{
			slot = SLOT,
			player = player,
			traits = {},
			progress = {},
			traitGainedAt = {},
		} :: any
	) :: CreatureState
	local sent: { Sent } = {}
	TraitService._test.stub(function(slot: number): CreatureState?
		return if slot == SLOT then state else nil
	end, function(name: string, ...: any)
		table.insert(sent, { name = name, args = { ... } })
	end)
	local ok, err = pcall(function()
		body(state, sent)
	end)
	TraitService._test.stub(nil, nil)
	if not ok then
		error(err, 0)
	end
end

local function lastState(sent: { Sent }, path: string): any
	for i = #sent, 1, -1 do
		local s = sent[i]
		if s.name == "State" and s.args[1] == path then
			return s.args[2]
		end
	end
	return nil
end

local function eat(id: string, times: number): TraitRules.PipResult
	local result: TraitRules.PipResult = "unknown"
	for _ = 1, times do
		result = TraitService.onTraitPreyEaten(SLOT, id)
	end
	return result
end

return function()
	describe("TraitService (engine)", function()
		it("gives defaults for a slot with no creature", function()
			expect(TraitService.has(99, "glow")).toBe(false)
			expect(TraitService.speedMult(99)).toBe(1)
			expect(TraitService.massMult(99)).toBe(1)
			expect(TraitService.defenceTierBonus(99)).toBe(0)
			expect(TraitService.onTraitPreyEaten(99, "glow")).toBe("unknown")
			expect((TraitService.shed(99, 1))).toBe(false)
			expect(#TraitService.traits(99)).toBe(0)
		end)

		it("five Glowfry gain Glow: pips, the slot, the attribute, State and the event", function()
			withCreature(function(state, sent)
				expect(eat("glow", 4)).toBe("pip")
				expect(state.progress.glow).toBe(4)
				expect(lastState(sent, "run.progress").glow).toBe(4)
				expect(state.player:GetAttribute("Traits")).toBe("")
				expect(eat("glow", 1)).toBe("gained")
				expect(state.traits).toEqual({ "glow" })
				expect(state.progress.glow).toBe(nil)
				expect(state.player:GetAttribute("Traits")).toBe("glow")
				expect(lastState(sent, "run.traits")).toEqual({ "glow" })
				local event = TraitService._test.lastEvent() :: { any }
				expect(event).toEqual({ "traitGained", SLOT, "glow", 1 } :: { any })
				local last = sent[#sent]
				expect(last.name).toBe("CreatureEvent")
				-- A sixth Glowfry gives mass only.
				expect(eat("glow", 1)).toBe("held")
			end)
		end)

		it("activates an effect 0.5 s after the last pip (02 §8.2)", function()
			withCreature(function()
				eat("stripes", 5)
				expect(TraitService.speedMult(SLOT)).toBe(1)
				expect(TraitService.has(SLOT, "stripes")).toBe(false)
				expect(TraitService.traits(SLOT)).toEqual({ "stripes" })
				TraitService._test.activate(SLOT)
				expect(TraitService.has(SLOT, "stripes")).toBe(true)
				expect(TraitService.speedMult(SLOT)).toBe(TraitRules.STRIPES_SPEED)
			end)
		end)

		it("applies Spots and Spiny once active", function()
			withCreature(function()
				eat("spots", 5)
				eat("spiny", 5)
				TraitService._test.activate(SLOT)
				expect(TraitService.massMult(SLOT)).toBeCloseTo(1 + TraitRules.SPOTS_MASS, 1e-9)
				expect(TraitService.massMult(SLOT, "player")).toBe(1)
				expect(TraitService.defenceTierBonus(SLOT)).toBe(TraitRules.SPINY_DEFENCE)
			end)
		end)

		it("three full slots give no pips; a shed closes up and frozen pips continue", function()
			withCreature(function(state, sent)
				eat("ink", 2)
				eat("glow", 5)
				eat("spots", 5)
				eat("spiny", 5)
				expect(eat("plated", 1)).toBe("full")
				expect(state.progress.plated).toBe(nil)
				expect(state.progress.ink).toBe(2)
				local ok = TraitService.shed(SLOT, 1)
				expect(ok).toBe(true)
				expect(state.traits).toEqual({ "spots", "spiny" })
				expect(state.player:GetAttribute("Traits")).toBe("spots,spiny")
				expect(TraitService._test.lastEvent()).toEqual(
					{ "traitShed", SLOT, "glow", 1 } :: { any }
				)
				expect(lastState(sent, "run.traits")).toEqual({ "spots", "spiny" })
				expect(eat("ink", 3)).toBe("gained")
				expect(state.traits).toEqual({ "spots", "spiny", "ink" })
				local refused, reason = TraitService.shed(SLOT, 3 + 1)
				expect(refused).toBe(false)
				expect(reason).toBe("empty")
			end)
		end)

		it("refuses a shed while gulped (02 §8.3)", function()
			withCreature(function(state)
				eat("glow", 5)
				state.player:SetAttribute("Phase", "dead")
				local ok, reason = TraitService.shed(SLOT, 1)
				expect(ok).toBe(false)
				expect(reason).toBe("state")
				expect(state.traits).toEqual({ "glow" })
			end)
		end)

		it("reset clears traits and pips and tells the owner", function()
			withCreature(function(state, sent)
				eat("glow", 5)
				eat("spots", 2)
				TraitService.reset(SLOT)
				expect(#state.traits).toBe(0)
				expect((next(state.progress))).toBe(nil)
				expect(state.player:GetAttribute("Traits")).toBe("")
				expect(lastState(sent, "run.traits")).toEqual({})
				expect(lastState(sent, "run.progress")).toEqual({})
				local count = #sent
				TraitService.reset(SLOT) -- nothing to clear: nothing sent
				expect(#sent).toBe(count)
			end)
		end)

		it("every MVP trait prey names a known trait", function()
			for _, def in Index.TraitPrey.list do
				if def.scope == "MVP" then
					expect(Index.Traits.byId[def.givesTrait or ""] ~= nil).toBe(true)
				end
			end
		end)

		local player = Players:GetPlayers()[1]
		if not player then
			it(
				"(no player in this session: the live creature case runs in a play test)",
				function() end
			)
			return
		end

		it("the live creature carries the trait fields and the Traits attribute", function()
			local slot = player:GetAttribute("Slot")
			local state = if type(slot) == "number" then CreatureService.get(slot) else nil
			expect(state ~= nil).toBe(true)
			local s = state :: CreatureState
			expect(type(s.traits) == "table" and type(s.progress) == "table").toBe(true)
			expect(player:GetAttribute("Traits")).toBe(TraitRules.joinIds(s.traits))
		end)
	end)
end
