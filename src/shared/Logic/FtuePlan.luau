--!strict
-- FtuePlan: the pure helpers of the server's tutorial director (task S6-C2, module B31; docs/04,
-- sections 3.5, 3.6 and 4; docs/09, sections 5.1 and 5.3 `TutorialStep`). Services/TutorialService
-- reads them; tests/unit/Logic/FtuePlan checks them. Numbers and tables only, so it runs in Lune.
--
--   Code, eventOf     the `TutorialStep` values a client sends (09 §5.3) and the FtueRules event
--                     each one is
--   routePoint        a point on the first-run route at a distance from the Hatch Bed, at the
--                     depth of data:NurseryPath (03 §6.2), so FtueConfig's 04 §3.5 distances place
--                     the scripted prey
--   trailPoints       the plankton trail's motes
--   followTarget      Swarm A's target: the player, held within the follow limit of the hatch
--                     point (04 §3.6 B2)
--   gapDistance       how far a point is from the Gap, across the water
--   crossedGap        whether a `NurseryPath` PointId lies past the Gap (04 §3.1: S5 ends)
--   traitPreyFor      the trait prey that gives a trait (the Glowfry for `glow`, 04 §3.6 B5)
local FtueRules = require("./FtueRules")
local Index = require("../Data/Index")
local NurseryPath = require("../Data/Generated/NurseryPath")
local NurseryRoute = require("./NurseryRoute")

type Config = FtueRules.Config
type Event = FtueRules.Event

local FtuePlan = {}

--- The prey IDs of the scripted krill and the plankton trail (04 §3.5).
FtuePlan.KRILL = "krill"
FtuePlan.PLANKTON = "plankton"

--- The `TutorialStep` values (09 §5.3), one integer per message. 2 is onboarding step 02 itself
--- (10 §3.1, the step the client reports); the others are reports the stage machine needs and
--- only the client sees (04 §3.1, §3.7).
FtuePlan.Code = table.freeze({
	LOADING_SHOWN = 2, -- the first frame of the loading screen (10 §3.1 step 02)
	LOADED = 101, -- the loading screen exits (`LoadDone`): S0_LOADING ends (04 §3.1)
	TAP = 102, -- a tap that is not a drag
	STEER = 103, -- a steering input (a drag of 0.2 s or more, a movement key, a stick); again
	-- at most once a second while it lasts, so the server sees the input continue
	BACKGROUND = 104, -- the app went to the background (04 §3.7)
})
--- The range `TutorialStep` accepts (Net/Server's int check); unknown values inside it are ignored.
FtuePlan.CODE_MIN = 2
FtuePlan.CODE_MAX = 104

local C = FtuePlan.Code

--- The FtueRules event a `TutorialStep` value stands for, nil for none (step 02, unknown values).
function FtuePlan.eventOf(code: number): Event?
	if code == C.LOADED then
		return { kind = "loadingDone" }
	elseif code == C.TAP then
		return { kind = "touch", drag = false }
	elseif code == C.STEER then
		return { kind = "touch", drag = true }
	elseif code == C.BACKGROUND then
		return { kind = "backgrounded" }
	end
	return nil
end

--- Whether a `TutorialStep` value is an input (it restarts the idle clock, 04 §3.7).
function FtuePlan.isInput(code: number): boolean
	return code == C.TAP or code == C.STEER
end

-- The route's depth: one (distance, Y) sample at each row's start and end, in distance order. A
-- floor row sits on the floor (Y = −bottom), any other at the middle of its band.
local samples: { { number } } = {}
for _, def in NurseryPath do
	local function y(bottom: number): number
		return if def.floor then -bottom else -(def.top + bottom) / 2
	end
	table.insert(samples, { def.at, y(def.bottom) })
	if def.to > def.at then
		table.insert(samples, { def.to, y(def.toBottom) })
	end
end
table.sort(samples, function(a, b)
	return a[1] < b[1]
end)

--- The route's Y at distance `s` from the Hatch Bed: linear between the data:NurseryPath rows,
--- held at the ends.
function FtuePlan.depthAt(s: number): number
	if s <= samples[1][1] then
		return samples[1][2]
	end
	for k = 2, #samples do
		local a, b = samples[k - 1], samples[k]
		if s <= b[1] then
			local span = b[1] - a[1]
			if span <= 0 then
				return b[2]
			end
			return a[2] + (b[2] - a[2]) * (s - a[1]) / span
		end
	end
	return samples[#samples][2]
end

--- The point of the route at distance `s` from the Hatch Bed (clamped to the route).
function FtuePlan.routePoint(s: number): (number, number, number)
	local x, z = NurseryRoute.pointAt(s)
	return x, FtuePlan.depthAt(s), z
end

--- The plankton trail's motes (04 §3.5): `count` points from distance `first`, `spacing` apart,
--- each as { x, y, z }.
function FtuePlan.trailPoints(first: number, count: number, spacing: number): { { number } }
	local out = table.create(math.max(count, 0))
	for k = 0, count - 1 do
		local x, y, z = FtuePlan.routePoint(first + k * spacing)
		table.insert(out, { x, y, z })
	end
	return out
end

--- Swarm A's target (04 §3.6 B2: it follows the player up to `limit` studs from the hatch point):
--- the player's point (px, py, pz), pulled back onto the sphere of radius `limit` round the hatch
--- point (hx, hy, hz) when it is farther.
function FtuePlan.followTarget(
	px: number,
	py: number,
	pz: number,
	hx: number,
	hy: number,
	hz: number,
	limit: number
): (number, number, number)
	local dx, dy, dz = px - hx, py - hy, pz - hz
	local d = math.sqrt(dx * dx + dy * dy + dz * dz)
	if d <= limit or d < 1e-6 then
		return px, py, pz
	end
	local k = limit / d
	return hx + dx * k, hy + dy * k, hz + dz * k
end

--- Studs across the water (x, z) from the point to the Gap (`layout.gap` along the route).
function FtuePlan.gapDistance(cfg: Config, x: number, z: number): number
	local gx, gz = NurseryRoute.pointAt(cfg.layout.gap)
	return math.sqrt((x - gx) ^ 2 + (z - gz) ^ 2)
end

local atOf: { [string]: number } = {}
for _, def in NurseryPath do
	atOf[def.id] = def.at
end

--- Whether route place `pointId` (WorldIndex.nurseryPathAt) is past the Gap: its data:NurseryPath
--- stretch starts at `layout.gap` or farther (the channel, 04 §3.5). False for nil.
function FtuePlan.crossedGap(cfg: Config, pointId: string?): boolean
	if pointId == nil then
		return false
	end
	local at = atOf[pointId]
	return at ~= nil and at >= cfg.layout.gap
end

--- The ID of the MVP trait prey that gives `traitId` (data:TraitPrey `givesTrait`), nil for none.
function FtuePlan.traitPreyFor(traitId: string): string?
	for _, def in Index.TraitPrey.list do
		if def.givesTrait == traitId and def.scope == "MVP" then
			return def.id
		end
	end
	return nil
end

return table.freeze(FtuePlan)
