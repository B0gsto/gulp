--!strict
local RunRules = require("../../../src/shared/Logic/RunRules")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type Point = RunRules.Point

local function p(x: number, y: number, z: number): Point
	return { x = x, y = y, z = z }
end

describe("RunRules (canon 5.5; 02 §0.7, §12; 09 §6.3)", function()
	it(
		"starts the first run of a never-banked account in the Nursery, every other at the cove",
		function()
			expect(RunRules.joinHome(false)).toBe("nursery")
			expect(RunRules.joinHome(true)).toBe("cove")
			expect(RunRules.respawnHome()).toBe("cove")
		end
	)

	it("walks cove → run → dead → cove", function()
		local phase, outcome = RunRules.transition("cove", "leftHome", 0)
		expect(phase).toBe("run")
		expect(outcome).toBe("start")
		phase, outcome = RunRules.transition(phase, "gulped", 40)
		expect(phase).toBe("dead")
		expect(outcome).toBe("gulp")
		phase, outcome = RunRules.transition(phase, "respawned", 0)
		expect(phase).toBe("cove")
		expect(outcome).toBe("respawn")
	end)

	it("cancels a run silently on re-entering home under mass 1 (02 §0.7 item 3)", function()
		local phase, outcome = RunRules.transition("run", "enteredCove", 0.9)
		expect(phase).toBe("cove")
		expect(outcome).toBe("cancel")
		phase, outcome = RunRules.transition("run", "enteredNursery", 0)
		expect(phase).toBe("cove")
		expect(outcome).toBe("cancel")
	end)

	it("banks an armed run at the own cove, and only there", function()
		local phase, outcome = RunRules.transition("run", "enteredCove", 1)
		expect(phase).toBe("run")
		expect(outcome).toBe("bank")
		phase, outcome = RunRules.transition("run", "enteredNursery", 25)
		expect(phase).toBe("run")
		expect(outcome).toBe(nil)
	end)

	it("ignores events that do not apply", function()
		local cases: { { any } } = {
			{ "cove", "gulped" },
			{ "cove", "respawned" },
			{ "cove", "enteredCove" },
			{ "run", "leftHome" },
			{ "run", "respawned" },
			{ "dead", "leftHome" },
			{ "dead", "gulped" },
			{ "dead", "enteredCove" },
		}
		for _, c in cases do
			local phase, outcome = RunRules.transition(c[1], c[2], 50)
			expect(phase).toBe(c[1])
			expect(outcome).toBe(nil)
		end
	end)

	it("accepts Swim again only while dead and once the gulp card is up (02 §12.1)", function()
		expect(RunRules.Op.swimAgain).toBe(1) -- 09 §5.3
		expect(RunRules.GULP_CARD_SECONDS).toBe(1.2)
		expect(RunRules.canSwimAgain("dead", 100, 101.2)).toBe(true)
		expect(RunRules.canSwimAgain("dead", 100, 101.19)).toBe(false)
		expect(RunRules.canSwimAgain("dead", 100, 100 + 3600)).toBe(true) -- no timeout
		expect(RunRules.canSwimAgain("dead", nil, 200)).toBe(false)
		expect(RunRules.canSwimAgain("run", 100, 102)).toBe(false)
		expect(RunRules.canSwimAgain("cove", 100, 102)).toBe(false)
	end)

	it("respawns from the tap: moved after the fade out, released after the fade in", function()
		local release, move = RunRules.respawnTimes(100)
		expect(move).toBeCloseTo(100.3, 1e-9)
		expect(release).toBeCloseTo(100.6, 1e-9)
		-- 02 §12.4: within 0.8 s of the tap; 09 §6.3: budget 2.0 s; canon 5.5: 3 s.
		expect(release - 100 <= RunRules.RESPAWN_TARGET_SECONDS).toBe(true)
		expect(RunRules.RESPAWN_TARGET_SECONDS <= RunRules.RESPAWN_SECONDS).toBe(true)
		expect(RunRules.RESPAWN_SECONDS <= 3).toBe(true)
		-- 02 §12.1: the shortest gulp-to-control time is 2.0 s (card at 1.2 s, then 0.8 s).
		expect(RunRules.GULP_CARD_SECONDS + RunRules.RESPAWN_TARGET_SECONDS).toBeCloseTo(2.0, 1e-9)
	end)

	describe("the return rule", function()
		local points = { p(0, 0, 0), p(100, 0, 0), p(200, 0, 0), p(-300, 0, 0) }

		it("keeps the origin when nothing that can eat it is within 60 studs", function()
			local at, index = RunRules.returnPoint(p(90, 0, 0), points, { p(151, 0, 0) })
			expect(index).toBe(0)
			expect(at.x).toBe(90)
		end)

		it("counts a threat at exactly 60 studs", function()
			local _, index = RunRules.returnPoint(p(90, 0, 0), points, { p(150, 0, 0) })
			expect(index ~= 0).toBe(true)
		end)

		it("takes the nearest clear revive point by distance from the origin", function()
			-- Origin at 90 is threatened; point 2 (100) is nearest but threatened too; point 1 (0)
			-- is next and clear.
			local at, index = RunRules.returnPoint(p(90, 0, 0), points, { p(110, 0, 0) })
			expect(index).toBe(1)
			expect(at.x).toBe(0)
		end)

		it("uses the nearest point anyway when none is clear", function()
			local threats = { p(0, 0, 0), p(100, 0, 0), p(200, 0, 0), p(-300, 0, 0), p(90, 0, 0) }
			local _, index = RunRules.returnPoint(p(90, 0, 0), points, threats)
			expect(index).toBe(2)
		end)

		it("keeps the origin with no revive points", function()
			local _, index = RunRules.returnPoint(p(5, 0, 0), {}, { p(5, 0, 0) })
			expect(index).toBe(0)
		end)

		it("measures in three dimensions and honours a custom radius", function()
			local _, index = RunRules.returnPoint(p(0, 0, 0), points, { p(0, 50, 0) }, 40)
			expect(index).toBe(0)
			local _, index2 = RunRules.returnPoint(p(0, 0, 0), points, { p(0, 30, 30) }, 50)
			expect(index2).toBe(2)
		end)
	end)
end)
