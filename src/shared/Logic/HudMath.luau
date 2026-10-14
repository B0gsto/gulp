--!strict
-- HudMath: the numbers the run HUD shows (docs/08, sections 3.4, 3.12, 3.16 and 4.2). Pure,
-- so it runs in Lune. Text is never built here: callers pass the parts to `Loc.t`.
local Index = require("../Data/Index")
local TierMath = require("./TierMath")

local HudMath = {}

local tiers = Index.Tiers.list
local TOP = #tiers

-- 08 §3.4: the next badge pulses from 85% fill.
HudMath.NEAR = 0.85
-- 08 §3.12: distance rounded to 5, updated 5 times a second.
HudMath.HOME_ROUND = 5
HudMath.HOME_HZ = 5
-- 08 §3.16: at most 4 pops at once; "fast bites merge into one number". The merge window is not
-- in the bible: one sixth of a second, the bite haptic cap of 08 §11.4 (tune).
HudMath.POPS_MAX = 4
HudMath.POP_MERGE = 1 / 6
HudMath.POP_LIFE = 0.5
HudMath.POP_RISE = 48
-- 08 §3.16 does not say how live pops share the mouth: each older pop keeps at least this many
-- rpx above the next newer one (the Number 28 line and 2 to spare), so they stack and never
-- overlap (task S6-C2; 14 §5.1) (tune).
HudMath.POP_GAP = 30

export type ShortKind = "plain" | "thousand" | "million"

local function oneDecimal(value: number): string
	local text = string.format("%.1f", math.floor(value * 10) / 10)
	return (string.gsub(text, "%.0$", ""))
end

--- A whole number for the HUD (08 §3.4: above 9,999 shown as 12.4K): the digits and which key
--- wraps them (`common.thousand`, `common.million`; "plain" needs no key). Rounds down, so the
--- shown value is never more than the real one.
function HudMath.short(n: number): (string, ShortKind)
	local whole = math.max(0, math.floor(n))
	if whole <= 9999 then
		return tostring(whole), "plain"
	elseif whole < 1e6 then
		return oneDecimal(whole / 1e3), "thousand"
	end
	return oneDecimal(whole / 1e6), "million"
end

--- A whole number with its thousands grouped (08 §5.1 wireframe: "12,480"), rounded down. The
--- cove balance shows every Pearl, so a price can be compared with it digit for digit.
function HudMath.grouped(n: number): string
	local digits = tostring(math.max(0, math.floor(n)))
	local out = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1,")))
	return (string.gsub(out, "^,", ""))
end

export type MassBar = {
	tier: number,
	nextTier: number?, -- nil at the top tier
	fill: number, -- 0 to 1 between this tier's threshold and the next
	toGo: number, -- whole mass still needed (0 at the top)
	near: boolean, -- fill at 85% or more
	max: boolean,
}

--- The state of `HUD.MassBar` at `mass` (08 §3.4).
function HudMath.massBar(mass: number): MassBar
	local m = math.max(0, mass)
	local tier = TierMath.tier(m)
	if tier >= TOP then
		return { tier = TOP, nextTier = nil, fill = 1, toGo = 0, near = false, max = true }
	end
	local from = tiers[tier].massNeeded
	local to = tiers[tier + 1].massNeeded
	local fill = math.clamp((m - from) / (to - from), 0, 1)
	return {
		tier = tier,
		nextTier = tier + 1,
		fill = fill,
		toGo = math.max(0, math.ceil(to - m)),
		near = fill >= HudMath.NEAR,
		max = false,
	}
end

--- Distance to home for `hud.home_dist` (08 §3.12): studs shown as metres (one stud reads as one
--- metre), rounded to the nearest 5.
function HudMath.homeDistance(studs: number): number
	return math.max(0, math.floor(studs / HudMath.HOME_ROUND + 0.5) * HudMath.HOME_ROUND)
end

-- 08 §4.2: the tier-up card shows up to three prey that just became edible.
HudMath.NEW_FOOD_MAX = 3

--- The prey that became edible on a rise from `from` to `to` (08 §4.2; canon 5.2: a prey of
--- tier n is edible from tier n): MVP prey first, then trait prey, in table order, event-only
--- prey left out, at most three IDs.
function HudMath.newFood(from: number, to: number): { string }
	local out: { string } = {}
	for _, list in { Index.Prey.list, Index.TraitPrey.list } do
		for _, def in list do
			if #out >= HudMath.NEW_FOOD_MAX then
				return out
			end
			if
				def.tier > from
				and def.tier <= to
				and def.scope == "MVP"
				and def.eventOnly == nil
			then
				table.insert(out, def.id)
			end
		end
	end
	return out
end

export type Pop = { amount: number, born: number, lastHit: number }

--- Adds a bite of `amount` to the live pops at clock `now` (08 §3.16). A bite within the merge
--- window of the newest pop adds to it and restarts its life; otherwise a new pop starts, and the
--- oldest is dropped when 4 are live. Expired pops are removed first. Returns the pop changed.
function HudMath.pushPop(pops: { Pop }, now: number, amount: number): Pop
	for i = #pops, 1, -1 do
		if now - pops[i].born >= HudMath.POP_LIFE then
			table.remove(pops, i)
		end
	end
	local newest = pops[#pops]
	if newest and now - newest.lastHit < HudMath.POP_MERGE then
		newest.amount += amount
		newest.lastHit = now
		newest.born = now
		return newest
	end
	if #pops >= HudMath.POPS_MAX then
		table.remove(pops, 1)
	end
	local pop = { amount = amount, born = now, lastHit = now }
	table.insert(pops, pop)
	return pop
end

--- How far a pop of age `age` has risen (rpx) and its transparency (0 to 1).
function HudMath.popPose(age: number): (number, number)
	local t = math.clamp(age / HudMath.POP_LIFE, 0, 1)
	local rise = HudMath.POP_RISE * (1 - (1 - t) * (1 - t)) -- quad out
	local fade = if t < 0.4 then 0 else (t - 0.4) / 0.6
	return rise, fade
end

--- Stacks live pops (08 §3.16): `ys` are their screen Ys (rpx, down is +), oldest first. Each is
--- raised to at least `POP_GAP` above the next newer one; the newest stays where it is.
function HudMath.popStack(ys: { number }): { number }
	local out = table.clone(ys)
	for i = #out - 1, 1, -1 do
		out[i] = math.min(out[i], out[i + 1] - HudMath.POP_GAP)
	end
	return out
end

return table.freeze(HudMath)
