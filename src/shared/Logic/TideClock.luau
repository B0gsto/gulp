--!strict
-- TideClock: the scheduled tide as a pure function of Unix time (task S4-C3, module B07; canon 10;
-- docs/02, section 14.1; docs/09, section 11.1). Every server and every client evaluates the same
-- function, so all servers agree without a message. Pure numbers, so it runs in Lune.
--
--   slot     = 15 minutes on the UTC quarter hour; rotation :00 frenzy, :15 moon_tide,
--              :30 frenzy, :45 whale_fall
--   phase    = active for the first 240 s of a slot, warning for the last 60 s (naming the next
--              slot's tide), calm in between (naming the next slot's tide too)
--   fallback = a tide whose row is not in this build, or whose scope tag the build does not ship,
--              runs its `TideDef.fallback` (whale_fall → moon_tide until Whale Fall ships)
--   :30      = after launch a limited-time tide from live config replaces its Feeding Frenzy
--              while the slot start lies inside the configured window (09 §11.1, §17.4)
--
-- The timings and the rotation are canon 10 prose, so they live in Config/Defaults.tides.
local Defaults = require("../Config/Defaults")
local Index = require("../Data/Index")
local Types = require("../Types")

local TideClock = {}

TideClock.SLOT = Defaults.tides.slot
TideClock.ACTIVE = Defaults.tides.active
TideClock.WARN = Defaults.tides.warn
TideClock.ROTATION = Defaults.tides.rotation
TideClock.FLEX_SLOT = Defaults.tides.flexSlot

--- The scope tags the MVP build ships (canon 15): the default when no `shipped` set is given.
TideClock.MVP = table.freeze({ MVP = true } :: { [string]: boolean })

export type Options = {
	shipped: { [string]: boolean }?, -- scope tags in this build; default TideClock.MVP
	limitedId: string?, -- live.limitedTideId; nil or "" for none
	limitedStart: number?, -- live.limitedTideStart as Unix seconds (inclusive)
	limitedEnd: number?, -- live.limitedTideEnd as Unix seconds (exclusive)
}

local function playable(id: string, shipped: { [string]: boolean }): boolean
	local def = Index.Tides.byId[id]
	return def ~= nil and shipped[def.scope] == true
end

--- The tide that actually runs for `id` in a build shipping `shipped`: `id` itself, or the first
--- playable tide down its `fallback` chain. When the chain ends with nothing playable (the
--- soft-launch slice has only `frenzy`, and data:Tides gives `moon_tide` no fallback) it is the
--- :00 tide, `frenzy`, which every build ships (13 S16-C1: Frenzy on all four slots there).
function TideClock.resolve(id: string, shipped: { [string]: boolean }?): string
	local scopes = shipped or TideClock.MVP
	local current: string? = id
	for _ = 1, #Index.Tides.list + 1 do -- a chain can visit each row at most once
		if current == nil then
			break
		end
		if playable(current, scopes) then
			return current
		end
		local def = Index.Tides.byId[current]
		current = if def then def.fallback else nil
	end
	return TideClock.ROTATION[1]
end

--- The tide of the slot that starts at `slotStart` (a multiple of SLOT), after the limited-tide
--- swap and the fallback.
function TideClock.slotTide(slotStart: number, opts: Options?): string
	local index = (slotStart // TideClock.SLOT) % #TideClock.ROTATION + 1
	local id = TideClock.ROTATION[index]
	local shipped = if opts then opts.shipped else nil
	if opts and index == TideClock.FLEX_SLOT then
		local limited = opts.limitedId
		local from, to = opts.limitedStart, opts.limitedEnd
		if limited and limited ~= "" and from and to and slotStart >= from and slotStart < to then
			if playable(limited, shipped or TideClock.MVP) then
				id = limited
			end
		end
	end
	return TideClock.resolve(id, shipped)
end

--- The scheduled tide state at Unix time `unix` (09 §11.1): the running tide while active,
--- otherwise the next slot's tide with phase "warning" in the last 60 s and "calm" before it.
function TideClock.at(unix: number, opts: Options?): Types.TideState
	local slotStart = unix - unix % TideClock.SLOT
	if unix < slotStart + TideClock.ACTIVE then
		return {
			phase = "active",
			id = TideClock.slotTide(slotStart, opts),
			startsAt = slotStart,
			endsAt = slotStart + TideClock.ACTIVE,
		}
	end
	local nextStart = slotStart + TideClock.SLOT
	return {
		phase = if unix >= nextStart - TideClock.WARN then "warning" else "calm",
		id = TideClock.slotTide(nextStart, opts),
		startsAt = nextStart,
		endsAt = nextStart + TideClock.ACTIVE,
	}
end

return table.freeze(TideClock)
