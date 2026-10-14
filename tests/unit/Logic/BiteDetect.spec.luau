--!strict
local BiteDetect = require("../../../src/shared/Logic/BiteDetect")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- A mouth at the origin, radius 1.2, facing +Z.
local function test(
	s: BiteDetect.State,
	key: number,
	dt: number,
	px: number,
	py: number,
	pz: number,
	set: BiteDetect.AssistSet?
)
	return BiteDetect.test(s, key, dt, 0, 0, 0, 1.2, 0, 0, 1, px, py, pz, 0.3, set)
end

describe("BiteDetect.test (02 §4.1)", function()
	it("hits when the spheres touch, in any direction, with or without assist", function()
		local s = BiteDetect.new()
		BiteDetect.beginFrame(s)
		expect((test(s, 1, 0, 0, 0, 1.5, nil))).toBe(BiteDetect.HIT)
		expect((test(s, 2, 0, 0, 0, -1.4, nil))).toBe(BiteDetect.HIT)
		expect((test(s, 3, 0, 1.6, 0, 0, nil))).toBe(BiteDetect.NONE)
		local result, gap = test(s, 4, 0, 0, 0, 2.5, nil)
		expect(result).toBe(BiteDetect.NONE)
		expect(gap).toBeCloseTo(1.0, 1e-9)
	end)

	it(
		"pulls a near miss in the cone toward the mouth until it lands (Touch: 12 studs/s)",
		function()
			local s = BiteDetect.new()
			local set = BiteDetect.assistSet("Touch")
			-- 2.5 studs ahead: gap 1.0; inside 2.5 × 1.2 = 3 studs; pulled 0.2 a frame at 60 fps.
			local results = {}
			for frame = 1, 6 do
				BiteDetect.beginFrame(s)
				results[frame] = (test(s, 7, 1 / 60, 0, 0, 2.5, set))
			end
			expect(results[1]).toBe(BiteDetect.ASSIST)
			expect(results[4]).toBe(BiteDetect.ASSIST)
			expect(results[5]).toBe(BiteDetect.HIT)
			expect(BiteDetect.pulled(s, 7)).toBeCloseTo(1.0, 1e-9)
		end
	)

	it("never pulls outside the cone or the range, or with the Keys set past 2 radii", function()
		local s = BiteDetect.new()
		BiteDetect.beginFrame(s)
		local touch = BiteDetect.assistSet("Touch")
		-- 40° off the nose: outside the 35° cone.
		local a = math.rad(40)
		expect((test(s, 1, 1, 2.6 * math.sin(a), 0, 2.6 * math.cos(a) - 0.6, touch))).toBe(
			BiteDetect.NONE
		)
		-- 30° off the nose: inside.
		a = math.rad(30)
		expect((test(s, 2, 0, 2.6 * math.sin(a), 0, 2.6 * math.cos(a) - 0.6, touch))).toBe(
			BiteDetect.ASSIST
		)
		expect((test(s, 3, 1, 0, 0, 3.1, touch))).toBe(BiteDetect.NONE) -- past 3 studs
		-- Keys: 2 radii, 2.4 studs.
		expect((test(s, 4, 0, 0, 0, 2.5, BiteDetect.assistSet("Keys")))).toBe(BiteDetect.NONE)
		expect((test(s, 5, 0, 0, 0, 2.3, BiteDetect.assistSet("Keys")))).toBe(BiteDetect.ASSIST)
		expect((test(s, 6, 0, 0, 0, 2.5, BiteDetect.assistSet("Nope")))).toBe(BiteDetect.NONE)
		expect(BiteDetect.assistSet("Keys").cone).toBe(22)
	end)

	it("forgets a member's pull when it was not tested last frame", function()
		local s = BiteDetect.new()
		local set = BiteDetect.assistSet("Touch")
		BiteDetect.beginFrame(s)
		test(s, 9, 0.05, 0, 0, 2.5, set)
		expect(BiteDetect.pulled(s, 9)).toBeCloseTo(0.6, 1e-9)
		BiteDetect.beginFrame(s)
		BiteDetect.beginFrame(s)
		expect(BiteDetect.pulled(s, 9)).toBe(0)
		test(s, 9, 0.05, 0, 0, 2.5, set)
		expect(BiteDetect.pulled(s, 9)).toBeCloseTo(0.6, 1e-9)
		expect(BiteDetect.key(3, 5)).toBe(101)
	end)
end)
