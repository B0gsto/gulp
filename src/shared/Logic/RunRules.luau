--!strict
-- RunRules: the pure parts of the run loop (task S4-C4, module B19; canon 5.5; docs/02, sections
-- 0.7, 12.1 and 12.4; docs/09, sections 5.1 and 6.3). RunLoopService runs them on the server.
--
--   phase   cove ──leave home──▶ run ──gulped──▶ dead ──respawned──▶ cove
--                ◀─enter home, mass < 1 (cancel)
--           In a run, entering the own cove armed (mass ≥ 1) banks (02 §0.7, §11; S5-C3).
--   home    where the run starts: the Nursery for an account that has never banked (its first
--           run, canon 5.5), the own cove for every later run, a respawn included.
--   respawn gulped at t: the creature returns to the cove at t + 2.0 s (09 §6.3), after the
--           client's 0.8 s gulp effect.
--   return  the return rule of 09 §6.3 for a revive or a resume: the place the creature was if
--           nothing that can eat it is within 60 studs, else the nearest clear revive point, else
--           the nearest revive point.
-- Numbers from Config/Defaults.run. Pure: no `game`, no Instances, so it runs in Lune.
local BankMath = require("./BankMath")
local Defaults = require("../Config/Defaults")

local RunRules = {}

local D = Defaults.run
RunRules.RESPAWN_SECONDS = D.respawnSeconds
RunRules.GULP_EFFECT_SECONDS = D.gulpEffectSeconds
RunRules.RESPAWN_GRACE_SECONDS = D.respawnGraceSeconds
RunRules.TIER_GRACE_SECONDS = D.tierGraceSeconds
RunRules.TIER_UP_PROTECT_SECONDS = D.tierUpProtectSeconds
RunRules.RETURN_PROTECT_SECONDS = D.returnProtectSeconds
RunRules.RETURN_CLEAR_RADIUS = D.returnClearRadius

--- The `Phase` attribute (09 §5.3). 02 §0.6's base states map onto it: `InCove` is cove, every
--- in-run state is run, `Gulped` is dead.
export type Phase = "cove" | "run" | "dead"
--- Where the current run starts and where it may be cancelled.
export type Home = "cove" | "nursery"
--- What happened to the creature.
export type Event = "leftHome" | "enteredCove" | "enteredNursery" | "gulped" | "respawned"
--- What the caller must do about a transition; nil when the event changes nothing.
export type Outcome = "start" | "cancel" | "bank" | "gulp" | "respawn"

export type Point = { x: number, y: number, z: number }

--- The home of the run an account starts on joining (09 §6.3 Join row; canon 5.5): the Nursery
--- until the account has banked once, else its cove.
function RunRules.joinHome(hasBanked: boolean): Home
	return if hasBanked then "cove" else "nursery"
end

--- The home after a respawn (02 §12.4; canon 5.5: every later run starts at the cove).
function RunRules.respawnHome(): Home
	return "cove"
end

--- The next phase after `event`, and what the caller must do. `mass` is the creature's mass when
--- it happens. "leftHome" is the centre leaving the run's home volume; "enteredCove" is the centre
--- inside the own cove; "enteredNursery" is the centre inside the Nursery for a run whose home is
--- the Nursery. Events that do not apply leave the phase as it is.
function RunRules.transition(phase: Phase, event: Event, mass: number): (Phase, Outcome?)
	if phase == "cove" then
		if event == "leftHome" then
			return "run", "start"
		end
	elseif phase == "run" then
		if event == "gulped" then
			return "dead", "gulp"
		elseif event == "enteredCove" or event == "enteredNursery" then
			if BankMath.armed(mass) then
				-- Banking happens only at the own cove (02 §11); the Nursery keeps the run going.
				return "run", if event == "enteredCove" then "bank" else nil
			end
			return "cove", "cancel" -- 02 §0.7 item 3: silently, counted nowhere
		end
	elseif phase == "dead" then
		if event == "respawned" then
			return "cove", "respawn"
		end
	end
	return phase, nil
end

--- Server time at which a creature gulped at `gulpedAt` is released at its cove (09 §6.3), and
--- the time the client's gulp effect ends (when the creature is moved and reset).
function RunRules.respawnTimes(gulpedAt: number): (number, number)
	return gulpedAt + RunRules.RESPAWN_SECONDS, gulpedAt + RunRules.GULP_EFFECT_SECONDS
end

-- Whether no threat is within `radius` of (x, y, z).
local function clear(x: number, y: number, z: number, threats: { Point }, radius: number): boolean
	local r2 = radius * radius
	for _, t in threats do
		local dx, dy, dz = t.x - x, t.y - y, t.z - z
		if dx * dx + dy * dy + dz * dz <= r2 then
			return false
		end
	end
	return true
end

--- 09 §6.3's return rule. `origin` is where the creature was (the gulp position for a revive,
--- the stored run position for a resume); `points` are the revive points (WorldIndex order);
--- `threats` are the positions of everything that can eat the creature at its new mass (the
--- caller filters them with BiteRules). Returns the chosen point and its index in `points`, 0
--- for the origin. With no points and a threatened origin, the origin is used anyway.
function RunRules.returnPoint(
	origin: Point,
	points: { Point },
	threats: { Point },
	radius: number?
): (Point, number)
	local r = radius or RunRules.RETURN_CLEAR_RADIUS
	if clear(origin.x, origin.y, origin.z, threats, r) or #points == 0 then
		return origin, 0
	end
	local order = table.create(#points)
	local d2: { number } = table.create(#points)
	for i, p in points do
		local dx, dy, dz = p.x - origin.x, p.y - origin.y, p.z - origin.z
		order[i] = i
		d2[i] = dx * dx + dy * dy + dz * dz
	end
	table.sort(order, function(a: number, b: number): boolean
		if d2[a] ~= d2[b] then
			return d2[a] < d2[b]
		end
		return a < b -- equal distances: the lower index, so the choice is stable
	end)
	for _, i in order do
		local p = points[i]
		if clear(p.x, p.y, p.z, threats, r) then
			return p, i
		end
	end
	local nearest = order[1]
	return points[nearest], nearest -- none clear: the nearest anyway; protection covers it
end

return RunRules
