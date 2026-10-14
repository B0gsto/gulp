--!strict
local FtueConfig = require("../../../src/shared/Config/FtueConfig")
local FtuePlan = require("../../../src/shared/Logic/FtuePlan")
local FtuePresent = require("../../../src/shared/Logic/FtuePresent")
local FtueRules = require("../../../src/shared/Logic/FtueRules")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local cfg = FtueConfig
local C = FtuePlan.Code
local S = FtueRules.Stage
local egg = cfg.hatch.egg

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-6)
end

describe("FtuePresent", function()
	it("plays each ftue.cue batch once, in seq order, and drops malformed ones", function()
		local c = FtuePresent.newCues()
		local a, first = FtuePresent.accept(c, { seq = 1, actions = { { kind = "hatch" } } })
		expect(a ~= nil and #(a :: any) == 1 and first).toBe(true)
		expect((FtuePresent.accept(c, { seq = 1, actions = {} }))).toBe(nil) -- a repeat
		local b, again = FtuePresent.accept(c, { seq = 3, actions = { { kind = "x" }, 5 } })
		expect(b ~= nil and #(b :: any) == 1 and not again).toBe(true) -- the bad entry is skipped
		expect((FtuePresent.accept(c, { seq = 2, actions = {} }))).toBe(nil) -- older than 3
		expect((FtuePresent.accept(c, "nope"))).toBe(nil)
		expect((FtuePresent.accept(c, { seq = "4", actions = {} }))).toBe(nil)
		expect(c.last).toBe(3)
	end)

	it("applies the first-run presentation until run 2 ends (04 §3.3, §4)", function()
		expect(FtuePresent.inFtue(nil, nil)).toBe(true) -- before the profile: a new account
		expect(FtuePresent.inFtue(S.S2_FIRST_BITE, false)).toBe(true)
		expect(FtuePresent.inFtue(S.DONE, false)).toBe(false)
		expect(FtuePresent.inFtue(S.S9_COVE, true)).toBe(true)
		expect(FtuePresent.inFtue(S.S10_RUN2, true)).toBe(true)
		expect(FtuePresent.inFtue(S.DONE, true)).toBe(false)
		expect(FtuePresent.inFtue(S.S0_LOADING, true)).toBe(false) -- banked, no script
	end)

	it("reports a tap, a drag and held keys as TutorialStep values", function()
		local s = FtuePresent.newInput()
		local drag = cfg.prompts.ghostHideDrag
		FtuePresent.press(s, 10)
		expect(FtuePresent.sense(cfg, s, 10 + drag / 2, false)).toBe(nil)
		expect(FtuePresent.release(cfg, s, 10 + drag / 2)).toBe(C.TAP)
		FtuePresent.press(s, 20)
		expect(FtuePresent.sense(cfg, s, 20 + drag + 0.01, false)).toBe(C.STEER)
		-- held on: again only once a `steerEvery`
		local every = cfg.director.steerEvery
		expect(FtuePresent.sense(cfg, s, 20.01 + drag + every / 2, false)).toBe(nil)
		expect(FtuePresent.sense(cfg, s, 20.02 + drag + every, false)).toBe(C.STEER)
		expect(FtuePresent.release(cfg, s, 25)).toBe(nil) -- a drag is no tap
		expect(FtuePresent.sense(cfg, s, 30, false)).toBe(nil)
		expect(FtuePresent.sense(cfg, s, 30, true)).toBe(C.STEER) -- a movement key
		expect(FtuePresent.release(cfg, s, 31)).toBe(nil) -- no press was down
	end)

	it("shows one new HUD element at a time, newElementGap apart (04 §1.4, §3.8)", function()
		local r = FtuePresent.newReveals()
		local gap = cfg.prompts.newElementGap
		FtuePresent.reveal(r, "dashButton", nil)
		FtuePresent.reveal(r, "traitSlot", nil)
		FtuePresent.reveal(r, "dashButton", nil) -- once
		expect(FtuePresent.due(cfg, r, 100)).toBe("dashButton")
		expect(FtuePresent.due(cfg, r, 100 + gap / 2)).toBe(nil)
		expect(FtuePresent.due(cfg, r, 100 + gap)).toBe("traitSlot")
		expect(FtuePresent.due(cfg, r, 200)).toBe(nil)
		FtuePresent.reveal(r, "traitSlot", nil) -- already shown
		expect(#r.queue).toBe(0)
		-- a rejoin's batch: at once
		FtuePresent.reveal(r, "massBar", 201)
		expect(r.shown.massBar).toBe(true)
		for id, ids in FtuePresent.HUD_OF do
			for _, hud in ids do
				expect(table.find(FtuePresent.HIDDEN, hud) ~= nil).toBe(true)
			end
			expect(type(id)).toBe("string")
		end
	end)

	it("stages the egg on the clip's frames (14 §5.1)", function()
		local p0 = FtuePresent.eggPose(cfg, 0)
		expect(p0.whole and near(p0.roll, -egg.lean) and near(p0.tall, 1)).toBe(true)
		for _, rock in egg.rocks do
			local peak = FtuePresent.eggPose(cfg, rock[1])
			expect(near(peak.roll, rock[2] - egg.lean)).toBe(true)
			local squash = FtuePresent.eggPose(cfg, rock[1] - egg.squashLead)
			expect(near(squash.tall, egg.squashTall) and near(squash.wide, egg.squashWide)).toBe(
				true
			)
		end
		local crack = FtuePresent.eggPose(cfg, egg.crackFrame)
		expect(crack.whole).toBe(false)
		expect(near(FtuePresent.eggPose(cfg, egg.flipFrame).lift, egg.lift)).toBe(true)
		local opened = FtuePresent.eggPose(cfg, egg.openFrame)
		expect(opened.free and near(opened.open, egg.openAngle)).toBe(true)
		expect(near(opened.topPitch, egg.openAngle)).toBe(true)
		expect(near(opened.bottomRock, egg.bottomRock)).toBe(true)
		-- it starts the arc where the hinge left it: behind the bottom, above the bed
		expect(opened.topF < 0 and opened.topU > 0).toBe(true)
		local landed = FtuePresent.eggPose(cfg, egg.landFrame)
		expect(near(landed.topR, -egg.landLeft) and near(landed.topF, -egg.landBehind)).toBe(true)
		expect(near(landed.topPitch, -180) and near(landed.topYaw, egg.turn)).toBe(true)
		expect(near(landed.topU, (egg.height - egg.split) / 2)).toBe(true)
		local mid = FtuePresent.eggPose(cfg, (egg.openFrame + egg.landFrame) / 2)
		local line = (opened.topU + landed.topU) / 2
		expect(near(mid.topU, line + egg.arc)).toBe(true)
		local rest = FtuePresent.eggPose(cfg, egg.restFrame)
		expect(near(rest.topRock, 0) and near(rest.bottomRock, 0) and near(rest.roll, -egg.lean)).toBe(
			true
		)
		local rolling = FtuePresent.eggPose(cfg, egg.landFrame + 2)
		expect(math.abs(rolling.topRock) > 0).toBe(true)
		expect(near(FtuePresent.clipSeconds(cfg), cfg.hatch.seconds)).toBe(true) -- control at 1.5 s
	end)

	it("eases the camera and shapes B5's dip and push-in", function()
		expect(FtuePresent.ease(-1)).toBe(0)
		expect(FtuePresent.ease(0.5)).toBe(0.5)
		expect(FtuePresent.ease(2)).toBe(1)
		local tr = cfg.trait
		expect(FtuePresent.dimAt(cfg, -0.1)).toBe(0)
		expect(near(FtuePresent.dimAt(cfg, tr.dimSeconds / 2), tr.dimPercent)).toBe(true)
		expect(FtuePresent.dimAt(cfg, tr.dimSeconds + 0.1)).toBe(0)
		expect(near(FtuePresent.pushAt(cfg, tr.pushInSeconds / 2), tr.pushIn)).toBe(true)
		expect(near(FtuePresent.pushAt(cfg, tr.pushInSeconds), 0)).toBe(true)
	end)
end)
