--!strict
-- The full tier and protection matrix of canon 5.2 and the bite effects of canon 9 (09 §16.1).
local BiteRules = require("../../../src/shared/Logic/BiteRules")
local Index = require("../../../src/shared/Data/Index")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type PlayerBite = BiteRules.PlayerBite

local function player(tier: number): BiteRules.Target
	return { kind = "player", tier = tier }
end

-- A legal bite: tier 5 eats tier 3, in range, nothing saves the victim.
local function legal(): PlayerBite
	return {
		eaterInRun = true,
		eaterStunned = false,
		eaterFlagged = false,
		victimInRun = true,
		eaterTier = 5,
		victimTier = 3,
		victimInSafeVolume = false,
		victimProtected = false,
		victimTucked = false,
		victimPuffed = false,
		victimSpiny = false,
		inRange = true,
		recentlyGulped = false,
		bubbleAvailable = false,
		platedAvailable = false,
	}
end

describe("BiteRules: prey (canon 5.2: prey of your tier or lower)", function()
	it("matches the whole eater tier × prey tier matrix, plankton (tier 0) included", function()
		for eater = 1, 7 do
			for prey = 0, 7 do
				expect(BiteRules.canEatPrey(eater, prey)).toBe(prey <= eater)
				local ok, reason = BiteRules.canEat(eater, true, { kind = "prey", tier = prey })
				expect(ok).toBe(prey <= eater)
				expect(reason).toBe(if prey <= eater then nil else "tier")
			end
		end
	end)

	it(
		"lets prey be eaten inside a safe volume (02 §0.5) and ignores every target flag",
		function()
			local ok = BiteRules.canEat(1, true, {
				kind = "prey",
				tier = 1,
				inSafeVolume = true,
				protected = true,
				tucked = true,
				puffed = true,
				spiny = true,
			})
			expect(ok).toBe(true)
		end
	)

	it("agrees with every prey row: each is edible from its own tier up", function()
		for _, def in Index.Prey.list do
			expect(BiteRules.canEatPrey(def.tier, def.tier)).toBe(true)
			if def.tier >= 1 then
				expect(BiteRules.canEatPrey(def.tier - 1, def.tier)).toBe(false)
			end
		end
	end)
end)

describe("BiteRules: player eats player (canon 5.2)", function()
	it("needs at least one full tier more, never eats tier 1, and same tiers bump", function()
		for eater = 1, 7 do
			for victim = 1, 7 do
				local expected = victim >= 2 and eater >= victim + 1
				local ok, reason = BiteRules.canEat(eater, true, player(victim))
				expect(ok).toBe(expected)
				expect(reason).toBe(if expected then nil else "tier")
			end
		end
	end)

	it(
		"Puff adds one defence tier, Spiny one more, both stack to three tiers (02 §8.6)",
		function()
			for eater = 1, 7 do
				for victim = 2, 7 do
					local puffed = BiteRules.canEat(
						eater,
						true,
						{ kind = "player", tier = victim, puffed = true }
					)
					local spiny = BiteRules.canEat(
						eater,
						true,
						{ kind = "player", tier = victim, spiny = true }
					)
					local both = BiteRules.canEat(
						eater,
						true,
						{ kind = "player", tier = victim, puffed = true, spiny = true }
					)
					expect(puffed).toBe(eater >= victim + 2)
					expect(spiny).toBe(eater >= victim + 2)
					expect(both).toBe(eater >= victim + 3)
				end
			end
			expect(BiteRules.defenceTier(3, false, false)).toBe(3)
			expect(BiteRules.defenceTier(3, true, false)).toBe(4)
			expect(BiteRules.defenceTier(3, false, true)).toBe(4)
			expect(BiteRules.defenceTier(3, true, true)).toBe(5)
		end
	)

	it("never eats a creature in a safe volume, protected, or in Shell, at any tier", function()
		for victim = 2, 6 do
			expect(
				select(
					2,
					BiteRules.canEat(
						7,
						true,
						{ kind = "player", tier = victim, inSafeVolume = true }
					)
				)
			).toBe("safe zone")
			expect(
				select(
					2,
					BiteRules.canEat(7, true, { kind = "player", tier = victim, protected = true })
				)
			).toBe("protected")
			expect(
				select(
					2,
					BiteRules.canEat(7, true, { kind = "player", tier = victim, tucked = true })
				)
			).toBe("protected")
		end
	end)

	it("tierAllows is the bare test, tier 1 immunity only between players", function()
		expect(BiteRules.tierAllows(2, true, 1, true, false, false)).toBe(false)
		expect(BiteRules.tierAllows(2, false, 1, true, false, false)).toBe(true) -- predator on a Fry
		expect(BiteRules.tierAllows(2, true, 1, false, false, false)).toBe(true) -- player on a tier 1 non-player
		expect(BiteRules.tierAllows(4, true, 3, true, false, false)).toBe(true)
		expect(BiteRules.tierAllows(4, true, 4, true, false, false)).toBe(false)
	end)
end)

describe("BiteRules: predators (canon 5.2, 02 §0.4)", function()
	it(
		"each predator eats exactly the player tiers up to its eatsMaxTier, tier 1 included",
		function()
			for _, def in Index.Predators.list do
				for victim = 1, 7 do
					local ok = BiteRules.predatorCanEat(def.id, player(victim))
					expect(ok).toBe(victim <= def.eatsMaxTier)
				end
			end
			expect(BiteRules.predatorCanEat("gull", player(2))).toBe(true)
			expect(BiteRules.predatorCanEat("gull", player(3))).toBe(false)
			expect(BiteRules.predatorCanEat("old_scar", player(6))).toBe(true)
		end
	)

	it(
		"needs two tiers on a Spiny player, and stops at safe volumes and every protection",
		function()
			expect(
				BiteRules.predatorCanEat("old_scar", { kind = "player", tier = 6, spiny = true })
			).toBe(false)
			expect(
				BiteRules.predatorCanEat("old_scar", { kind = "player", tier = 5, spiny = true })
			).toBe(true)
			expect(
				BiteRules.predatorCanEat("gull", { kind = "player", tier = 1, inSafeVolume = true })
			).toBe(false)
			-- The first-run shield is a protection window: nothing eats a new player before the first bank.
			expect(
				BiteRules.predatorCanEat(
					"old_scar",
					{ kind = "player", tier = 1, protected = true }
				)
			).toBe(false)
			expect(BiteRules.predatorCanEat("gull", { kind = "player", tier = 2, tucked = true })).toBe(
				false
			)
			expect(BiteRules.predatorCanEat("nobody", player(1))).toBe(false)
		end
	)

	it(
		"a player one tier higher eats a Barracuda or a Grouper, never the Gull, Moray or Old Scar",
		function()
			for eater = 1, 7 do
				expect(BiteRules.canEatPredator(eater, "barracuda")).toBe(eater >= 5)
				expect(BiteRules.canEatPredator(eater, "grouper")).toBe(eater >= 6)
				for _, id in { "gull", "moray", "old_scar" } do
					local ok, reason = BiteRules.canEatPredator(eater, id)
					expect(ok).toBe(false)
					expect(reason).toBe("inedible")
				end
			end
			expect(BiteRules.predatorEdible("barracuda")).toBe(true)
			expect(BiteRules.predatorEdible("old_scar")).toBe(false)
			expect(BiteRules.predatorEdible("nobody")).toBe(false)
		end
	)

	it("pays 25 for a Barracuda and 60 for a Grouper; Bonefed adds 25%, Spots nothing", function()
		expect(BiteRules.predatorGain("barracuda", {})).toBe(25)
		expect(BiteRules.predatorGain("grouper", {})).toBe(60)
		expect(BiteRules.predatorGain("barracuda", { "spots" })).toBe(25)
		expect(BiteRules.predatorGain("grouper", { "bonefed", "spots" })).toBeCloseTo(75, 1e-9)
		expect(BiteRules.predatorGain("gull", {})).toBe(0)
		expect(BiteRules.predatorGain("nobody", {})).toBe(0)
	end)
end)

describe("BiteRules.playerBite (09 §10.2, in order)", function()
	it("gulps a legal bite", function()
		local ok, reason, save = BiteRules.playerBite(legal())
		expect(ok).toBe(true)
		expect(reason).toBe(nil)
		expect(save).toBe(nil)
	end)

	it("gives each rule's reject reason", function()
		local cases: { { set: (PlayerBite) -> (), reason: string, save: string? } } = {
			{
				set = function(b)
					b.eaterInRun = false
				end,
				reason = "state",
			},
			{
				set = function(b)
					b.victimInRun = false
				end,
				reason = "state",
			},
			{
				set = function(b)
					b.eaterStunned = true
				end,
				reason = "state",
			},
			{
				set = function(b)
					b.eaterFlagged = true
				end,
				reason = "state",
			},
			{
				set = function(b)
					b.victimTier = 1
				end,
				reason = "tier",
			},
			{
				set = function(b)
					b.victimInSafeVolume = true
				end,
				reason = "safe zone",
			},
			{
				set = function(b)
					b.victimProtected = true
				end,
				reason = "protected",
			},
			{
				set = function(b)
					b.victimTucked = true
				end,
				reason = "protected",
			},
			{
				set = function(b)
					b.victimTier = 4
					b.victimPuffed = true
				end,
				reason = "tier",
			},
			{
				set = function(b)
					b.victimTier = 4
					b.victimSpiny = true
				end,
				reason = "tier",
			},
			{
				set = function(b)
					b.inRange = false
				end,
				reason = "range",
			},
			{
				set = function(b)
					b.recentlyGulped = true
				end,
				reason = "repeat",
			},
			{
				set = function(b)
					b.bubbleAvailable = true
				end,
				reason = "protected",
				save = "bubble",
			},
			{
				set = function(b)
					b.platedAvailable = true
				end,
				reason = "protected",
				save = "plated",
			},
		}
		for _, case in cases do
			local b = legal()
			case.set(b)
			local ok, reason, save = BiteRules.playerBite(b)
			expect(ok).toBe(false)
			expect(reason).toBe(case.reason)
			expect(save).toBe(case.save)
		end
	end)

	it("takes the first failing rule when several fail", function()
		local b = legal()
		b.victimTier, b.victimInSafeVolume = 1, true -- rule 2 before rule 3
		expect(select(2, BiteRules.playerBite(b))).toBe("tier")
		b = legal()
		b.victimInSafeVolume, b.victimProtected = true, true -- rule 3 before rule 4
		expect(select(2, BiteRules.playerBite(b))).toBe("safe zone")
		b = legal()
		b.victimProtected, b.eaterTier = true, 2 -- rule 4 before rule 5
		expect(select(2, BiteRules.playerBite(b))).toBe("protected")
		b = legal()
		b.eaterTier, b.inRange = 3, false -- rule 5 before rule 6
		expect(select(2, BiteRules.playerBite(b))).toBe("tier")
		b = legal()
		b.inRange, b.bubbleAvailable = false, true -- out of range spends no bubble
		expect(select(3, BiteRules.playerBite(b))).toBe(nil)
	end)

	it(
		"pops the newcomer bubble before the plates, and spends neither on a bite the tier test stops",
		function()
			local b = legal()
			b.bubbleAvailable, b.platedAvailable = true, true
			expect(select(3, BiteRules.playerBite(b))).toBe("bubble")
			-- Plated + Spiny (02 §8.7): spines run first; plates go only when the eater is two tiers up.
			b = legal()
			b.eaterTier, b.victimTier, b.victimSpiny, b.platedAvailable = 4, 3, true, true
			local ok, reason, save = BiteRules.playerBite(b)
			expect(ok).toBe(false)
			expect(reason).toBe("tier")
			expect(save).toBe(nil)
			b.eaterTier = 5
			expect(select(3, BiteRules.playerBite(b))).toBe("plated")
		end
	)

	it("covers the whole tier matrix like canEat", function()
		for eater = 1, 7 do
			for victim = 1, 7 do
				local b = legal()
				b.eaterTier, b.victimTier = eater, victim
				expect((BiteRules.playerBite(b))).toBe(
					(BiteRules.canEat(eater, true, player(victim)))
				)
			end
		end
	end)
end)

describe("BiteRules: guards and gains", function()
	it("holds the repeat guard for 90 s", function()
		expect(BiteRules.repeatBlocked(nil, 1000)).toBe(false)
		expect(BiteRules.repeatBlocked(1000, 1000)).toBe(true)
		expect(BiteRules.repeatBlocked(1000, 1089.9)).toBe(true)
		expect(BiteRules.repeatBlocked(1000, 1090)).toBe(false)
	end)

	it("halves the feed guard twice, then pays nothing (30%, 15%, 7.5%, 0)", function()
		expect(BiteRules.feedGuard(0)).toBe(1)
		expect(BiteRules.feedGuard(1)).toBe(0.5)
		expect(BiteRules.feedGuard(2)).toBe(0.25)
		expect(BiteRules.feedGuard(3)).toBe(0)
		expect(BiteRules.feedGuard(10)).toBe(0)
		expect(BiteRules.playerGain(100, {}, 0)).toBeCloseTo(30, 1e-9)
		expect(BiteRules.playerGain(100, {}, 1)).toBeCloseTo(15, 1e-9)
		expect(BiteRules.playerGain(100, {}, 2)).toBeCloseTo(7.5, 1e-9)
		expect(BiteRules.playerGain(100, {}, 3)).toBe(0)
	end)

	it("applies Bonefed but not Spots to eating players (canon 9)", function()
		expect(BiteRules.playerGain(100, { "spots" }, 0)).toBeCloseTo(30, 1e-9)
		expect(BiteRules.playerGain(100, { "bonefed" }, 0)).toBeCloseTo(37.5, 1e-9)
		expect(BiteRules.playerGain(100, { "spots", "bonefed" }, 0)).toBeCloseTo(37.5, 1e-9)
	end)

	it("adds Spots and Bonefed on prey, and applies the Nursery share by tier", function()
		expect(BiteRules.preyGain(2, {}, 3, false)).toBe(2)
		expect(BiteRules.preyGain(10, { "spots" }, 3, false)).toBeCloseTo(11, 1e-9)
		expect(BiteRules.preyGain(10, { "bonefed" }, 3, false)).toBeCloseTo(12.5, 1e-9)
		expect(BiteRules.preyGain(10, { "spots", "bonefed" }, 3, false)).toBeCloseTo(13.5, 1e-9)
		expect(BiteRules.preyGain(10, {}, 1, true)).toBe(10)
		expect(BiteRules.preyGain(10, {}, 2, true)).toBe(5)
		expect(BiteRules.preyGain(10, {}, 3, true)).toBe(0)
		expect(BiteRules.nurseryShare(1)).toBe(1)
		expect(BiteRules.nurseryShare(2)).toBe(0.5)
		expect(BiteRules.nurseryShare(7)).toBe(0)
	end)

	it("keeps tier 3 and higher out of the Nursery", function()
		for tier = 1, 7 do
			expect(BiteRules.mayEnterNursery(tier)).toBe(tier <= 2)
		end
	end)
end)
