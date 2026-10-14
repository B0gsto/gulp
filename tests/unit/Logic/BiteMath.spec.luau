--!strict
local BiteDetect = require("../../../src/shared/Logic/BiteDetect")
local BiteMath = require("../../../src/shared/Logic/BiteMath")
local Index = require("../../../src/shared/Data/Index")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("BiteMath", function()
	it("clamps the claim time to [now − 0.4 s, now] (09 §8.9, step 5)", function()
		local tc, clamped = BiteMath.claimTime(99.9, 100)
		expect(tc).toBe(99.9)
		expect(clamped).toBe(false)
		tc, clamped = BiteMath.claimTime(99.6, 100)
		expect(tc).toBe(99.6)
		expect(clamped).toBe(false)
		tc, clamped = BiteMath.claimTime(90, 100)
		expect(tc).toBeCloseTo(99.6, 1e-9)
		expect(clamped).toBe(true)
		tc, clamped = BiteMath.claimTime(105, 100)
		expect(tc).toBe(100)
		expect(clamped).toBe(true)
		tc = BiteMath.claimTime(0 / 0, 100)
		expect(tc).toBe(100)
		tc = BiteMath.claimTime(math.huge, 100)
		expect(tc).toBe(100)
	end)

	it(
		"sizes the mouth per 02 §4.1: 1.2 × bodyScale × mouthMult, × 1.25 dashing, × firstRun",
		function()
			expect(BiteMath.mouthRadius(1, 1, false, 1)).toBeCloseTo(1.2, 1e-9)
			expect(BiteMath.mouthRadius(2, 1, true, 1)).toBeCloseTo(3.0, 1e-9)
			expect(BiteMath.mouthRadius(1, 1.5, false, 1.6)).toBeCloseTo(1.2 * 1.5 * 1.6, 1e-9)
			-- The server's radius always has the dash factor (09 §8.9).
			expect(BiteMath.serverRadius(6.5, 1, 1)).toBeCloseTo(9.75, 1e-9)
			expect(BiteMath.serverRadius(1, 1, 1.3)).toBeCloseTo(1.2 * 1.25 * 1.3, 1e-9)
		end
	)

	it(
		"puts the mouth centre half a body length ahead, then half a mouth radius (02 §0.2, §4.1)",
		function()
			expect(BiteMath.mouthAhead(1, 1, 1.2)).toBeCloseTo(1.5 + 0.6, 1e-9)
			expect(BiteMath.mouthAhead(2, 1.2, 3)).toBeCloseTo(3.6 + 1.5, 1e-9)
			local x, y, z = BiteMath.mouth(10, 20, 30, 0, 0, -1, 2, 1, 2)
			expect(x).toBe(10)
			expect(y).toBe(20)
			expect(z).toBeCloseTo(30 - 4, 1e-9)
			-- A look vector that is not a unit vector is normalised.
			x, y, z = BiteMath.mouth(0, 0, 0, 3, 0, 4, 1, 1, 0)
			expect(x).toBeCloseTo(0.9, 1e-9)
			expect(z).toBeCloseTo(1.2, 1e-9)
			-- A zero look vector leaves the mouth at the centre.
			x, y, z = BiteMath.mouth(1, 2, 3, 0, 0, 0, 5, 1, 1)
			expect(x + y + z).toBe(6)
		end
	)

	it(
		"computes reach from the server's radius, the widest assist, the prey and the motion",
		function()
			-- 2.5 × 1.5 + 0.3 + 0.2 + 3 + 0.15 × (10 + 4) = 3.75 + 0.5 + 3 + 2.1 = 9.35
			expect(BiteMath.reach(1.5, 0.3, 0.2, 10, 4)).toBeCloseTo(9.35, 1e-9)
			-- A negative speed (never expected) counts as its size.
			expect(BiteMath.reach(1, 0, 0, -10, 0)).toBeCloseTo(2.5 + 3 + 1.5, 1e-9)
			-- 09 §8.9's worked tier-7 rows (bodyScale 6.5): 27.4 at rest, 39.9 in a 38 × 2.2 dash.
			local r = BiteMath.serverRadius(6.5, 1, 1)
			expect(BiteMath.reach(r, 0, 0, 0, 0)).toBeCloseTo(27.375, 1e-9)
			expect(BiteMath.reach(r, 0, 0, 38 * 2.2, 0)).toBeCloseTo(39.915, 1e-9)
		end
	)

	it("lets a client claim at most max(r + preyRadius, range × r) (02 §4.1)", function()
		expect(BiteMath.claimLimit(1.2, 0.3, 2.5)).toBeCloseTo(3.0, 1e-9)
		expect(BiteMath.claimLimit(1.2, 3, 2.5)).toBeCloseTo(4.2, 1e-9)
		expect(BiteMath.claimLimit(1.2, 0.3, 0)).toBeCloseTo(1.5, 1e-9)
	end)

	-- 09 §8.9, "Every honest claim is inside the reach": every claim BiteDetect allows, with any
	-- assist set, any prey radius, in any direction, is within the server's reach measured from
	-- the server's centre, at tiers 1 to 7, swimming and dashing, with no speed or wobble credit.
	it("keeps every claim BiteDetect allows inside the server's reach, tiers 1 to 7", function()
		local radii: { [number]: boolean } = {}
		for _, list in { Index.Prey.list, Index.TraitPrey.list } do
			for _, def in list do
				radii[def.radius] = true
			end
		end
		local sets = {
			BiteDetect.assistSet("Touch"),
			BiteDetect.assistSet("Pad"),
			BiteDetect.assistSet("Keys"),
		}
		local worstMargin = math.huge
		local tier7RestMargin = math.huge
		for tier = 1, 7 do
			local bodyScale = Index.Tiers.list[tier].bodyScale
			local r = BiteMath.serverRadius(bodyScale, 1, 1)
			local serverAhead = BiteMath.mouthAhead(bodyScale, 1, r)
			for _, dashing in { false, true } do
				local rc = BiteMath.mouthRadius(bodyScale, 1, dashing, 1)
				local clientAhead = BiteMath.mouthAhead(bodyScale, 1, rc)
				expect(serverAhead - clientAhead).toBeCloseTo(
					BiteMath.CENTRE_AHEAD * (r - rc),
					1e-9
				)
				for preyRadius in radii do
					local reach = BiteMath.reach(r, preyRadius, 0, 0, 0)
					for _, set in sets do
						local limit = BiteDetect.claimLimit(rc, preyRadius, set)
						for deg = 0, 180, 5 do
							local a = math.rad(deg)
							local sx, sz = math.sin(a), math.cos(a)
							local d = 0
							while d <= limit + 0.5 do
								local s = BiteDetect.new()
								BiteDetect.beginFrame(s)
								-- Body at the origin facing +Z; the client's mouth centre is at
								-- clientAhead, the prey d studs from it.
								local px, pz = sx * d, clientAhead + sz * d
								local result = BiteDetect.test(
									s,
									1,
									10,
									0,
									0,
									clientAhead,
									rc,
									0,
									0,
									1,
									px,
									0,
									pz,
									preyRadius,
									set
								)
								if result == BiteDetect.HIT then
									expect(d <= limit + 1e-9).toBe(true)
									local dz = pz - serverAhead
									local margin = reach - math.sqrt(px * px + dz * dz)
									worstMargin = math.min(worstMargin, margin)
									if tier == 7 and not dashing then
										tier7RestMargin =
											math.min(tier7RestMargin, margin - preyRadius)
									end
								end
								d += 0.02 * rc
							end
						end
						-- The bound itself: the widest claim plus the centre shift is inside.
						local shift = BiteMath.CENTRE_AHEAD * (r - rc)
						expect(limit + shift <= reach).toBe(true)
					end
				end
			end
		end
		expect(worstMargin > 0 and worstMargin < math.huge).toBe(true)
		-- 09 §8.9's table: at least 6.9 studs (plus the prey radius) at tier 7 at rest.
		expect(tier7RestMargin >= 6.9 - 0.01).toBe(true)
	end)

	it("accepts a prey within reach and rejects one past it, with the distance", function()
		local ok, d = BiteMath.within(0, 0, 0, 3, 4, 0, 5)
		expect(ok).toBe(true)
		expect(d).toBeCloseTo(5, 1e-9)
		ok, d = BiteMath.within(0, 0, 0, 3, 4, 0.01, 5)
		expect(ok).toBe(false)
		expect(d > 5).toBe(true)
	end)

	it("calls a miss far beyond three reaches", function()
		expect(BiteMath.isFar(15, 5)).toBe(false)
		expect(BiteMath.isFar(15.01, 5)).toBe(true)
	end)

	it("gives the first-run mouth factor and the Nursery share (04 §4, 02 §4.4)", function()
		expect(BiteMath.firstRunMouth(1)).toBe(1.6)
		expect(BiteMath.firstRunMouth(2)).toBe(1.3)
		expect(BiteMath.firstRunMouth(3)).toBe(1)
		expect(BiteMath.nurseryMult(1)).toBe(1)
		expect(BiteMath.nurseryMult(2)).toBe(0.5)
		expect(BiteMath.nurseryMult(3)).toBe(0)
		expect(BiteMath.nurseryMult(7)).toBe(0)
	end)

	it("gains prey mass × trait multiplier × Nursery share, never below 0", function()
		expect(BiteMath.gain(2, 1, 1)).toBe(2)
		expect(BiteMath.gain(2, 1.1, 0.5)).toBeCloseTo(1.1, 1e-9)
		expect(BiteMath.gain(2, 1, 0)).toBe(0)
		expect(BiteMath.gain(-1, 1, 1)).toBe(0)
	end)
end)
