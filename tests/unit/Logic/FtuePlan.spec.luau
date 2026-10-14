--!strict
local BiteMath = require("../../../src/shared/Logic/BiteMath")
local FtueConfig = require("../../../src/shared/Config/FtueConfig")
local FtuePlan = require("../../../src/shared/Logic/FtuePlan")
local Index = require("../../../src/shared/Data/Index")
local NurseryPath = require("../../../src/shared/Data/Generated/NurseryPath")
local NurseryRoute = require("../../../src/shared/Logic/NurseryRoute")
local TestKit = require("../../../src/shared/Util/TestKit")
local TierMath = require("../../../src/shared/Logic/TierMath")
local VolumeMath = require("../../../src/shared/Logic/VolumeMath")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local C = FtuePlan.Code

local function row(id: string): any
	for _, def in NurseryPath do
		if def.id == id then
			return def
		end
	end
	error(`no row {id}`)
end

describe("FtuePlan", function()
	it("maps each TutorialStep value to its FtueRules event (09 §5.3)", function()
		expect((FtuePlan.eventOf(C.LOADED) :: any).kind).toBe("loadingDone")
		local tap = FtuePlan.eventOf(C.TAP) :: any
		expect(tap.kind == "touch" and tap.drag == false).toBe(true)
		local steer = FtuePlan.eventOf(C.STEER) :: any
		expect(steer.kind == "touch" and steer.drag == true).toBe(true)
		expect((FtuePlan.eventOf(C.BACKGROUND) :: any).kind).toBe("backgrounded")
		expect(FtuePlan.eventOf(C.LOADING_SHOWN)).toBe(nil) -- step 02 only
		expect(FtuePlan.eventOf(50)).toBe(nil)
		expect(FtuePlan.isInput(C.TAP) and FtuePlan.isInput(C.STEER)).toBe(true)
		expect(FtuePlan.isInput(C.LOADED) or FtuePlan.isInput(C.BACKGROUND)).toBe(false)
		for _, code in C do
			expect(code >= FtuePlan.CODE_MIN and code <= FtuePlan.CODE_MAX and code % 1 == 0).toBe(
				true
			)
		end
		expect(C.LOADING_SHOWN).toBe(2) -- 10 §3.1: onboarding step 02 is its own number
	end)

	it("places FtueConfig's distances on the route at data:NurseryPath's depths", function()
		-- Swarm A, Swarm B and the Glow Grotto are rows of their own: the distance lands on them.
		for _, pair in
			{ { FtueConfig.layout.swarmA, "swarm_a" }, { FtueConfig.layout.swarmB, "swarm_b" } }
		do
			local def = row(pair[2])
			local x, y, z = FtuePlan.routePoint(pair[1])
			expect(x).toBeCloseTo(def.x, 1.5)
			expect(z).toBeCloseTo(def.z, 1.5)
			expect(y).toBeCloseTo(-(def.top + def.bottom) / 2, 1e-6)
		end
		local hatch = row("hatch_bed")
		local hx, hy, hz = FtuePlan.routePoint(0)
		expect(hx).toBeCloseTo(hatch.x, 1e-6)
		expect(hz).toBeCloseTo(hatch.z, 1e-6)
		expect(hy).toBe(-hatch.bottom) -- the Hatch Bed sits on the floor
		-- Between rows the depth runs straight; past the ends it holds.
		expect(FtuePlan.depthAt(7)).toBeCloseTo((-24 + -18) / 2, 1e-6)
		expect(FtuePlan.depthAt(-5)).toBe(FtuePlan.depthAt(0))
		expect(FtuePlan.depthAt(10000)).toBe(FtuePlan.depthAt(NurseryRoute.LENGTH + 1))
	end)

	it("lays the plankton trail from its first mote, one every spacing studs", function()
		local f = FtueConfig.feed
		local motes =
			FtuePlan.trailPoints(FtueConfig.layout.trailFrom, f.trailMotes, f.trailSpacing)
		expect(#motes).toBe(f.trailMotes)
		local lx, _, lz = FtuePlan.routePoint(FtueConfig.layout.trailTo)
		local last = motes[#motes]
		expect(last[1]).toBeCloseTo(lx, 1e-6) -- 20 + 9 × 4 = 56, the trail's end (04 §3.5)
		expect(last[3]).toBeCloseTo(lz, 1e-6)
		for k = 2, #motes do
			local a, b = motes[k - 1], motes[k]
			local d = math.sqrt((a[1] - b[1]) ^ 2 + (a[3] - b[3]) ^ 2)
			expect(d).toBeCloseTo(f.trailSpacing, 0.05)
		end
		expect(#FtuePlan.trailPoints(20, 0, 4)).toBe(0)
	end)

	it("holds Swarm A's target within the follow limit of the hatch point", function()
		local x, y, z = FtuePlan.followTarget(10, 0, 0, 0, 0, 0, 60)
		expect(x == 10 and y == 0 and z == 0).toBe(true)
		x, y, z = FtuePlan.followTarget(0, 0, 100, 0, 0, 0, 60)
		expect(x).toBe(0)
		expect(y).toBe(0)
		expect(z).toBeCloseTo(60, 1e-9)
		x, y, z = FtuePlan.followTarget(3, 4, 0, 3, 4, 0, 60)
		expect(x == 3 and y == 4 and z == 0).toBe(true)
	end)

	it("knows the Gap: distance across the water and the places past it", function()
		local cfg = FtueConfig
		local gx, gz = NurseryRoute.pointAt(cfg.layout.gap)
		expect(FtuePlan.gapDistance(cfg, gx, gz)).toBeCloseTo(0, 1e-9)
		expect(FtuePlan.gapDistance(cfg, gx + 3, gz + 4)).toBeCloseTo(5, 1e-9)
		expect(FtuePlan.crossedGap(cfg, "elbow_leg_1")).toBe(true)
		expect(FtuePlan.crossedGap(cfg, "home_current_mouth")).toBe(true)
		expect(FtuePlan.crossedGap(cfg, "little_arch")).toBe(false)
		expect(FtuePlan.crossedGap(cfg, "glow_grotto")).toBe(false)
		expect(FtuePlan.crossedGap(cfg, nil)).toBe(false)
		expect(FtuePlan.crossedGap(cfg, "nowhere")).toBe(false)
	end)

	it("feeds a fresh run below tier 3 by the end of B5 (02 §4.4, 04 §3.5, §6)", function()
		-- The script's own prey at its places, eaten in order as BiteService scores it: Nursery prey
		-- (inside the Lagoon's SafeNursery, NurseryRoute.lagoon) gives a tier 1 Fry all its mass and
		-- a tier 2 Nibbler half. Without the share the same prey gives 27, and three of B3's top-up
		-- krill then make tier 3 (30) inside the Nursery (task S6-C2).
		local cfg = FtueConfig
		local v = NurseryRoute.lagoon()
		local lagoon = VolumeMath.new(
			v.kind,
			v.shape,
			v.frame,
			v.size[1],
			v.size[2],
			v.size[3],
			{ Kind = v.kind }
		)
		local mass, tierUpAt, eaten = 0, nil :: number?, 0
		local function eat(preyId: string, x: number, y: number, z: number)
			local def = Index.Prey.byId[preyId] or Index.TraitPrey.byId[preyId]
			expect(VolumeMath.contains(lagoon, x, y, z)).toBe(true)
			local before = TierMath.tier(mass)
			mass += BiteMath.gain(def.mass, 1, BiteMath.nurseryMult(before))
			eaten += 1
			if before == 1 and TierMath.tier(mass) == 2 then
				tierUpAt = eaten
			end
		end
		local function swarm(preyId: string, count: number, s: number)
			local x, y, z = FtuePlan.routePoint(s)
			for _ = 1, count do
				eat(preyId, x, y, z)
			end
		end
		local f = cfg.feed
		swarm(FtuePlan.KRILL, f.swarmACount, cfg.layout.swarmA)
		for _, p in FtuePlan.trailPoints(cfg.layout.trailFrom, f.trailMotes, f.trailSpacing) do
			eat(FtuePlan.PLANKTON, p[1], p[2], p[3])
		end
		swarm(FtuePlan.KRILL, f.swarmBCount, cfg.layout.swarmB)
		local glowfry = FtuePlan.traitPreyFor(cfg.arms.firstTrait) :: string
		swarm(glowfry, cfg.arms.traitCount, cfg.layout.grotto)
		-- 04 §3.6 B3: Swarm A 6 and the trail 2, so tier 2 arrives two krill into Swarm B.
		expect(tierUpAt).toBe(f.swarmACount + f.trailMotes + 2)
		-- 04 §6: 10 + 12 krill at half (6) + 5 Glowfry at half (2.5) = 18.5, inside 15 to 23.
		expect(mass).toBeCloseTo(18.5, 1e-9)
		expect(mass <= 23).toBe(true)
		-- The margin to tier 3, in B3's top-up krill at the tier 2 share: 23 more must be eaten.
		local krill = Index.Prey.byId[FtuePlan.KRILL].mass * BiteMath.nurseryMult(2)
		expect(math.ceil((TierMath.def(3).massNeeded - mass) / krill)).toBe(23)
		expect(TierMath.tier(mass)).toBe(2)
	end)

	it(
		"lays the Lagoon's SafeNursery over the route to Little Arch, not the Elbow (03 §6.2)",
		function()
			local v = NurseryRoute.lagoon()
			local lagoon = VolumeMath.new(
				v.kind,
				v.shape,
				v.frame,
				v.size[1],
				v.size[2],
				v.size[3],
				{ Kind = v.kind }
			)
			for s = 0, 130 do
				local x, y, z = FtuePlan.routePoint(s)
				expect(VolumeMath.contains(lagoon, x, y, z)).toBe(true)
			end
			local inLagoon =
				{ hatch_bed = true, swarm_a = true, swarm_b = true, glow_grotto = true }
			for _, def in NurseryPath do
				if inLagoon[def.id] then
					local x, z = def.markX or def.x, def.markZ or def.z
					expect(VolumeMath.contains(lagoon, x, -18, z)).toBe(true)
				end
			end
			local x, y, z = FtuePlan.routePoint(140)
			expect(VolumeMath.contains(lagoon, x, y, z)).toBe(false) -- the Elbow, past the Nursery
			expect(VolumeMath.contains(lagoon, -361, 1, 361)).toBe(false) -- above the surface
		end
	)

	it("finds the trait prey of the first trait: Glowfry for Glow", function()
		local id = FtuePlan.traitPreyFor(FtueConfig.arms.firstTrait)
		expect(id).toBe("glowfry")
		expect(Index.TraitPrey.byId[id :: string].givesTrait).toBe("glow")
		expect(FtuePlan.traitPreyFor("nothing")).toBe(nil)
	end)
end)
