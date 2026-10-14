--!strict
-- LoadTime: the value and ctx of `sys_load_time` (docs/10, section 4.2). Pure.
-- J is seconds since the server saw the player join (`PlayerAdded`; chapter 10's clocks). The
-- event fires when control is granted, every session: chapter 04, section 2.1, phases B to E.
-- Also the load mode `ClientReady` carries (09 §5.3; 04 §2.4's slow-load rule) and the
-- `ftue_failsafe` it stands for.
local LoadTime = {}

--- `ClientReady`'s one integer (09 §5.3): how the loading screen started (04 §2.4). `full` is the
--- whole minimum set; `partial` started at J = 8 without it (`load_partial`); `minimal` at J = 15
--- on the essentials alone (`load_minimal`).
LoadTime.MODE = table.freeze({ full = 1, partial = 2, minimal = 3 })
LoadTime.MODE_MIN = 1
LoadTime.MODE_MAX = 3

--- The `ClientReady` integer for the loading screen's `LoadMode` attribute; `full` for anything
--- else (no loading screen in the place, so nothing was cut).
function LoadTime.modeCode(mode: unknown): number
	if mode == "partial" or mode == "minimal" then
		return LoadTime.MODE[mode]
	end
	return LoadTime.MODE.full
end

--- The `ftue_failsafe` ctx of a load mode (10 §4.2), nil for `full`.
function LoadTime.failsafe(code: number): string?
	if code == LoadTime.MODE.partial then
		return "load_partial"
	elseif code == LoadTime.MODE.minimal then
		return "load_minimal"
	end
	return nil
end

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
