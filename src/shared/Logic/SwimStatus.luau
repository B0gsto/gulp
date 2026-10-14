--!strict
-- SwimStatus: which states and overlays change movement, and how (docs/02, sections 0.6, 1.2,
-- 1.4 and 7.1). MovementController's `setStatus(effect, seconds)` (docs/09, section 5.2) keeps
-- the active set; this module turns that set into the SwimModel mods. Numbers only, so it runs
-- in Lune. Airborne and Dashing are applied by SwimModel itself; Stripes is a trait (TraitService).

--- The base states and overlays of 02 §0.6 that change movement.
export type Status =
	"Stunned"
	| "Hooked"
	| "Transit"
	| "Banking"
	| "Gulped"
	| "Tucked"
	| "Bumped"
	| "Puffed"
	| "Jetting"
	| "Rampaging"
	| "Slowed"
	| "Swallowing"

--- The part of `SwimModel.SwimMods` that statuses set.
export type Mods = {
	speedMult: number,
	turnMult: number,
	canThrust: boolean,
	dashBlocked: boolean,
}

local SwimStatus = {}

--- Every status, in a fixed order, so callers can loop without building a list.
SwimStatus.ALL = table.freeze({
	"Stunned",
	"Hooked",
	"Transit",
	"Banking",
	"Gulped",
	"Tucked",
	"Bumped",
	"Puffed",
	"Jetting",
	"Rampaging",
	"Slowed",
	"Swallowing",
} :: { Status })

-- 02 §1.2: the speed multipliers that multiply together.
local SPEED: { [string]: number } = table.freeze({
	Rampaging = 1.25,
	Puffed = 0.40,
	Slowed = 0.50,
	Swallowing = 0.60,
} :: { [string]: number })

-- 02 §0.6 "Can steer: No" and §1.4: turn rate 0 while Stunned, Tucked or Hooked (and in the
-- base states that cannot steer); × 0.3 while Jetting.
local TURN: { [string]: number } = table.freeze({
	Stunned = 0,
	Hooked = 0,
	Transit = 0,
	Banking = 0,
	Gulped = 0,
	Tucked = 0,
	Jetting = 0.3,
} :: { [string]: number })

-- No thrust: the base states that cannot steer (02 §0.6) and Tucked (Shell).
local NO_THRUST: { [string]: boolean } = table.freeze({
	Stunned = true,
	Hooked = true,
	Transit = true,
	Banking = true,
	Gulped = true,
	Tucked = true,
} :: { [string]: boolean })

-- 02 §7.1: no dash while Stunned, Hooked, Transit, Banking, Gulped, Puffed, Tucked or Bumped.
local NO_DASH: { [string]: boolean } = table.freeze({
	Stunned = true,
	Hooked = true,
	Transit = true,
	Banking = true,
	Gulped = true,
	Puffed = true,
	Tucked = true,
	Bumped = true,
} :: { [string]: boolean })

--- True for a name in `ALL`.
function SwimStatus.isStatus(name: string): boolean
	return table.find(SwimStatus.ALL, name :: Status) ~= nil
end

--- Writes the mods for the statuses that are `true` in `active` into `mods`. Allocates nothing.
function SwimStatus.apply(mods: Mods, active: { [string]: boolean })
	local speed, turn, thrust, dashBlocked = 1, 1, true, false
	for status, on in active do
		if on then
			speed *= SPEED[status] or 1
			local t = TURN[status]
			if t and t < turn then
				turn = t
			end
			if NO_THRUST[status] then
				thrust = false
			end
			if NO_DASH[status] then
				dashBlocked = true
			end
		end
	end
	mods.speedMult = speed
	mods.turnMult = turn
	mods.canThrust = thrust
	mods.dashBlocked = dashBlocked
end

return table.freeze(SwimStatus)
