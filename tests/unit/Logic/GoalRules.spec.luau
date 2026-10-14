--!strict
local GoalRules = require("../../../src/shared/Logic/GoalRules")
local Index = require("../../../src/shared/Data/Index")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local DAY = 20_400
local VETERAN: GoalRules.Context = { bestTier = 7, speciesOwned = 3, players = 24 }
local NEW: GoalRules.Context = { bestTier = 1, speciesOwned = 1, players = 1 }

local function difficulty(id: string): string
	return (Index.Goals.byId[id] :: any).difficulty
end

describe("GoalRules: rewards (05 §3.5, §3.7, §3.12)", function()
	it("pays the band × the rank multiplier", function()
		expect(GoalRules.reward("dg_eat_50", 1)).toBe(100)
		expect(GoalRules.reward("dg_tier4", 1)).toBe(125)
		expect(GoalRules.reward("dg_tier5", 1)).toBe(175)
		expect(GoalRules.allDoneBonus(1)).toBe(100)
		expect(GoalRules.reward("dg_eat_50", 5)).toBe(140)
		expect(GoalRules.reward("dg_tier5", 10)).toBe(332) -- 175 × 1.9 = 332.5
		expect(GoalRules.reward("nothing", 1)).toBe(0)
	end)

	it("pays a full day of 500, and 425 on the first day (05 §3.5)", function()
		local function total(ids: { string }): number
			local sum = GoalRules.allDoneBonus(1)
			for _, id in ids do
				sum += GoalRules.reward(id, 1)
			end
			return sum
		end
		expect(total(GoalRules.FIRST_DAY)).toBe(425)
		expect(total(GoalRules.pick(42, DAY, VETERAN, false, nil))).toBe(500)
	end)

	it("matches the rank multiplier table and stops at rank 50", function()
		local table_ = {
			[1] = 1.0,
			[5] = 1.4,
			[10] = 1.9,
			[15] = 2.4,
			[20] = 2.9,
			[30] = 3.9,
			[40] = 4.9,
			[50] = 5.9,
		}
		for rank, mult in table_ do
			expect(GoalRules.rankMultiplier(rank)).toBeCloseTo(mult, 1e-9)
		end
		expect(GoalRules.rankMultiplier(80)).toBeCloseTo(5.9, 1e-9)
		expect(GoalRules.rankMultiplier(0)).toBe(1)
	end)
end)

describe("GoalRules: fit (02 §15.3, 03 §9)", function()
	it("reads tier goals and player-eating goals from the data", function()
		expect(GoalRules.goalTier("dg_tier3")).toBe(3)
		expect(GoalRules.goalTier("dg_tier6")).toBe(6)
		expect(GoalRules.goalTier("dg_eat_50")).toBe(nil)
		expect(GoalRules.eatsPlayers("dg_player_1")).toBe(true)
		expect(GoalRules.eatsPlayers("dg_players_3")).toBe(true)
		expect(GoalRules.eatsPlayers("dg_visit_3")).toBe(false)
		expect(GoalRules.eatsPlayers("nothing")).toBe(false)
	end)

	it("checks scope, needs and the best tier + 1 limit", function()
		expect(GoalRules.eligible("dg_eat_50", NEW)).toBe(true)
		expect(select(2, GoalRules.eligible("dg_visit_3", VETERAN))).toBe("scope") -- [L]
		expect(
			GoalRules.eligible(
				"dg_visit_3",
				{ bestTier = 7, speciesOwned = 3, players = 4, shipped = { MVP = true, L = true } }
			)
		).toBe(true)
		expect(select(2, GoalRules.eligible("dg_species_2", NEW))).toBe("needs")
		expect(GoalRules.eligible("dg_species_2", { bestTier = 1, speciesOwned = 2, players = 1 })).toBe(
			true
		)
		expect(
			select(
				2,
				GoalRules.eligible("dg_player_1", { bestTier = 7, speciesOwned = 1, players = 5 })
			)
		).toBe("needs")
		expect(GoalRules.eligible("dg_player_1", { bestTier = 7, speciesOwned = 1, players = 6 })).toBe(
			true
		)
		expect(
			select(
				2,
				GoalRules.eligible("dg_tier6", { bestTier = 4, speciesOwned = 1, players = 1 })
			)
		).toBe("needs")
		expect(GoalRules.eligible("dg_tier6", { bestTier = 5, speciesOwned = 1, players = 1 })).toBe(
			true
		)
		expect(select(2, GoalRules.eligible("dg_tier3", NEW))).toBe("tier")
		expect(GoalRules.eligible("dg_tier3", { bestTier = 2, speciesOwned = 1, players = 1 })).toBe(
			true
		)
		expect(
			select(
				2,
				GoalRules.eligible("dg_tier5", { bestTier = 3, speciesOwned = 1, players = 1 })
			)
		).toBe("tier")
		expect(select(2, GoalRules.eligible("nothing", NEW))).toBe("unknown")
	end)
end)

describe("GoalRules.pick", function()
	it("gives the fixed set on the first day", function()
		expect(GoalRules.pick(7, DAY, NEW, true, nil)).toEqual({
			"dg_eat_50",
			"dg_tier3",
			"dg_bank_snapper",
		})
	end)

	it("is deterministic and gives one Easy, one Medium, one Hard that fit", function()
		for user = 1, 60 do
			local ctx = if user % 2 == 0
				then VETERAN
				else { bestTier = 3, speciesOwned = 1, players = 8 }
			local goals = GoalRules.pick(user * 1_000_003, DAY + user, ctx, false, nil)
			expect(goals).toEqual(GoalRules.pick(user * 1_000_003, DAY + user, ctx, false, nil))
			expect(#goals).toBe(3)
			expect(difficulty(goals[1])).toBe("Easy")
			expect(difficulty(goals[2])).toBe("Medium")
			expect(difficulty(goals[3])).toBe("Hard")
			local eating = 0
			for _, id in goals do
				expect((GoalRules.eligible(id, ctx))).toBe(true)
				if GoalRules.eatsPlayers(id) then
					eating += 1
				end
			end
			expect(eating <= 1).toBe(true)
		end
	end)

	it("varies by user and by day", function()
		local seen: { [string]: boolean } = {}
		for n = 1, 20 do
			seen[table.concat(GoalRules.pick(n, DAY, VETERAN, false, nil), ",")] = true
			seen[table.concat(GoalRules.pick(99, DAY + n, VETERAN, false, nil), ",")] = true
		end
		local count = 0
		for _ in seen do
			count += 1
		end
		expect(count > 10).toBe(true)
	end)

	it("never repeats yesterday's goals while another fits", function()
		for n = 1, 40 do
			local yesterday = GoalRules.pick(n, DAY - 1, VETERAN, false, nil)
			local today = GoalRules.pick(n, DAY, VETERAN, false, yesterday)
			for _, id in today do
				expect(table.find(yesterday, id)).toBe(nil)
			end
		end
	end)
end)

describe("GoalRules: rerolls, progress and reset", function()
	it("rerolls to another goal of the same difficulty, none of the current three", function()
		for n = 1, 30 do
			local current = GoalRules.pick(n, DAY, VETERAN, false, nil)
			for index = 1, 3 do
				local new = GoalRules.reroll(n, DAY, current, index, VETERAN, 0) :: string
				expect(new ~= nil).toBe(true)
				expect(difficulty(new)).toBe(difficulty(current[index]))
				expect(table.find(current, new)).toBe(nil)
				expect((GoalRules.eligible(new, VETERAN))).toBe(true)
			end
		end
		expect(GoalRules.reroll(1, DAY, { "nothing" }, 1, VETERAN, 0)).toBe(nil)
	end)

	it("never rerolls into a second player-eating goal", function()
		for used = 0, 30 do
			local new = GoalRules.reroll(
				5,
				DAY,
				{ "dg_eat_50", "dg_player_1", "dg_tier5" },
				3,
				VETERAN,
				used
			)
			expect(GoalRules.eatsPlayers(new :: string)).toBe(false)
		end
	end)

	it("allows one free reroll a day, one by video and three bought", function()
		expect(GoalRules.canReroll({}, "free")).toBe(true)
		expect(GoalRules.canReroll({ free = 1 }, "free")).toBe(false)
		expect(GoalRules.canReroll({ free = 1 }, "video")).toBe(true)
		expect(GoalRules.canReroll({ video = 1 }, "video")).toBe(false)
		expect(GoalRules.canReroll({ product = 2 }, "product")).toBe(true)
		expect(GoalRules.canReroll({ product = 3 }, "product")).toBe(false)
	end)

	it("advances to the target and completes once", function()
		local p, done = GoalRules.advance("dg_eat_50", 0, 30)
		expect(p).toBe(30)
		expect(done).toBe(false)
		p, done = GoalRules.advance("dg_eat_50", p, 30)
		expect(p).toBe(50)
		expect(done).toBe(true)
		p, done = GoalRules.advance("dg_eat_50", p, 5)
		expect(p).toBe(50)
		expect(done).toBe(false)
		expect(select(2, GoalRules.advance("dg_eat_50", 10, 0))).toBe(false)
		expect(select(2, GoalRules.advance("nothing", 0, 5))).toBe(false)
	end)

	it("resets at 00:00 UTC", function()
		local midnight = DAY * 86400
		expect(GoalRules.day(midnight)).toBe(DAY)
		expect(GoalRules.day(midnight - 1)).toBe(DAY - 1)
		expect(GoalRules.needsReset(DAY - 1, midnight)).toBe(true)
		expect(GoalRules.needsReset(DAY, midnight + 86399)).toBe(false)
	end)
end)
