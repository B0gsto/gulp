--!strict
-- LoadTime: the value and ctx of `sys_load_time` (docs/10, section 4.2). Pure.
-- J is seconds since the server saw the player join (`PlayerAdded`; chapter 10's clocks). The
-- event fires when control is granted, every session: chapter 04, section 2.1, phases B to E.
local LoadTime = {}

export type Bucket = "le5" | "le10" | "le20" | "gt20"

--- The ctx of a load that took `seconds` from `PlayerAdded` to control: `le5` for 5 or less,
--- `le10` for 10 or less, `le20` for 20 or less, `gt20` above that (10 §4.2).
function LoadTime.bucket(seconds: number): Bucket
	if seconds <= 5 then
		return "le5"
	elseif seconds <= 10 then
		return "le10"
	elseif seconds <= 20 then
		return "le20"
	end
	return "gt20"
end

--- The event value: `seconds` to one decimal place, never negative.
function LoadTime.value(seconds: number): number
	return math.round(math.max(seconds, 0) * 10) / 10
end

return LoadTime
