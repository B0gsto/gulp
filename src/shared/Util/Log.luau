--!strict
-- Log: tagged logging (docs/09, section 4.6). Every engine call that can fail logs its fallback
-- through here with a tag, usually the module name.
--
-- The module is engine-free so it runs in Lune. Two hooks are injected from outside:
--   the sink     where lines go. The default prints them; a test or a dev console replaces it.
--   the counter  called for every warn and error, so error spikes show on the dashboard. The
--                Analytics wrapper installs it when it starts; until then nothing is counted.

export type Level = "info" | "warn" | "error"
export type Sink = (level: Level, tag: string, message: string) -> ()
export type Counter = (level: Level, tag: string) -> ()

local Log = {}

local function defaultSink(level: Level, tag: string, message: string)
	if level == "info" then
		print(`[{tag}] {message}`)
	else
		warn(`[{tag}] {string.upper(level)}: {message}`)
	end
end

local sink: Sink = defaultSink
local counter: Counter? = nil
local counting = false
local seen: { [string]: boolean } = {}

local function write(level: Level, tag: string, message: string)
	sink(level, tag, message)
	-- The counter may log a failure of its own: that line is written but not counted again.
	local count = counter
	if count and level ~= "info" and not counting then
		counting = true
		-- Safe cast: a counter returns nothing, so the only second result is what it raised.
		local ok, problem = pcall(count :: (Level, string) -> unknown, level, tag)
		counting = false
		if not ok then
			sink("warn", "Log", `the counter failed: {problem}`)
		end
	end
end

--- Something worth a line in the output. Not counted.
function Log.info(tag: string, message: string)
	write("info", tag, message)
end

--- A fallback was taken and play goes on. Counted.
function Log.warn(tag: string, message: string)
	write("warn", tag, message)
end

--- Something is broken for this player or this server. Counted. It does not throw.
function Log.error(tag: string, message: string)
	write("error", tag, message)
end

--- Like `info`, `warn` or `error`, but a given level, tag and message is written only the first
--- time. Returns whether it was written.
function Log.once(level: Level, tag: string, message: string): boolean
	local key = `{level}\0{tag}\0{message}`
	if seen[key] then
		return false
	end
	seen[key] = true
	write(level, tag, message)
	return true
end

--- Replaces where lines go; nil restores the default, which prints them.
function Log.setSink(newSink: Sink?)
	sink = newSink or defaultSink
end

--- Sets the function called for every warn and error; nil stops counting.
function Log.setCounter(newCounter: Counter?)
	counter = newCounter
end

--- Forgets what `once` has written, so the next call writes again.
function Log.resetOnce()
	table.clear(seen)
end

return Log
