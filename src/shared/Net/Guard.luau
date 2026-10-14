--!strict
-- Guard: the validation wrapper of docs/09, section 14.2, without the engine. Net/Server feeds
-- it every client-to-server message; it runs, in order:
--   1-3. count, type, size and range against the remote's spec (Net/Validate)
--   4.   rate: one token bucket per sender per remote (Net/RateLimit); over the limit, dropped
--   6.   isolation: the handler runs under pcall; an error is logged with the remote name
-- Step 5 (is the action legal now) belongs to the handler. Every reject is counted by remote and
-- reason. Rejects the sender caused are also fired on `rejected`, which MovementValidator turns
-- into suspicion (14.2: malformed +5, flooding +3 a second); a handler error is ours, so it is
-- counted as "error" but not fired.
--
-- Generic over the sender key, so specs drive it in Lune with plain values for players.
local Log = require("../Util/Log")
local Signal = require("../Util/Signal")

local RateLimit = require("./RateLimit")
local Remotes = require("./Remotes")
local Validate = require("./Validate")

export type Reason = Validate.Reason | "rate" | "error"
export type Spec = Validate.Spec

type Route<K> = {
	name: string,
	specs: { Spec },
	handler: (K, ...unknown) -> (),
}

export type Guard<K> = {
	limiter: RateLimit.RateLimit<K>,
	routes: { [string]: Route<K> },
	passed: { [string]: number },
	rejects: { [string]: { [string]: number } },
	--- Fires (sender, remote name, reason) for every rejected message.
	rejected: Signal.Signal<K, string, Reason>,
}

local TAG = "Net"

local Guard = {}

--- A guard that rate-limits through `limiter` (a new one with the limits of section 5.3 when
--- nil). Net/Server passes the per-player limiter of Net/RateLimiter.
function Guard.new<K>(limiter: RateLimit.RateLimit<K>?): Guard<K>
	return {
		limiter = limiter or RateLimit.new(),
		routes = {},
		passed = {},
		rejects = {},
		rejected = Signal.new(),
	}
end

-- A spec must fit the remote's row in 5.3. A mismatch is a programmer mistake.
local function checkFits(def: Remotes.RemoteDef, specs: { Spec })
	local name = def.name
	local buffers = 0
	for _, spec in specs do
		if spec.kind == "buffer" then
			buffers += 1
			if def.minBytes and spec.min < def.minBytes then
				error(
					`Net: "{name}" spec allows {spec.min} bytes, the table's minimum is {def.minBytes}`,
					3
				)
			end
		end
	end
	if def.encoding == "none" and #specs ~= 0 then
		error(`Net: "{name}" carries no payload, so its spec must be empty`, 3)
	elseif def.encoding == "buffer" and (#specs ~= 1 or buffers ~= 1) then
		error(`Net: "{name}" carries one buffer, so its spec must be one Validate.buffer`, 3)
	elseif def.encoding == "scalars" and (#specs == 0 or buffers ~= 0) then
		error(`Net: "{name}" carries scalars, so its spec must list them and take no buffer`, 3)
	end
	local largest = Validate.largestBuffer(specs)
	if largest and def.maxBytes and largest > def.maxBytes then
		error(`Net: "{name}" spec allows {largest} bytes, the table's maximum is {def.maxBytes}`, 3)
	end
	local longest = Validate.longestString(specs)
	if longest and def.maxString and longest > def.maxString then
		error(
			`Net: "{name}" spec allows {longest} chars, the table's maximum is {def.maxString}`,
			3
		)
	end
end

--- Registers the one handler of the client-to-server remote `name`. `specs` lists one check per
--- argument. Throws on an unknown remote, a server-to-client remote, a second handler, or a spec
--- that does not fit the remote table.
function Guard.route<K>(self: Guard<K>, name: string, specs: { Spec }, handler: (K, ...unknown) -> ())
	local def = Remotes.byName[name]
	if def == nil then
		error(`Net: unknown remote "{name}"`, 2)
	end
	if def.direction ~= "ClientToServer" then
		error(`Net: "{name}" goes from server to client; it cannot have a server handler`, 2)
	end
	if self.routes[name] then
		error(`Net: "{name}" already has a handler`, 2)
	end
	checkFits(def, specs)
	self.routes[name] = { name = name, specs = table.clone(specs), handler = handler }
	self.passed[name] = 0
	self.rejects[name] = {}
end

--- Whether `name` has a handler.
function Guard.isRouted<K>(self: Guard<K>, name: string): boolean
	return self.routes[name] ~= nil
end

local function count<K>(self: Guard<K>, name: string, reason: Reason)
	local byReason = self.rejects[name]
	byReason[reason] = (byReason[reason] or 0) + 1
end

-- The sender's fault: counted, logged once per remote and reason (a flood must not flood the
-- log) and fired on `rejected`.
local function reject<K>(self: Guard<K>, key: K, name: string, reason: Reason): (boolean, Reason?)
	count(self, name, reason)
	Log.once("info", TAG, `first "{reason}" reject on {name}`)
	-- Safe cast: `fire` returns nothing, so the only second result is what a listener raised.
	local fire =
		self.rejected.fire :: (Signal.Signal<K, string, Reason>, K, string, Reason) -> unknown
	local ok, problem = pcall(fire, self.rejected, key, name, reason)
	if not ok then
		Log.warn(TAG, `a rejected listener failed on {name}: {problem}`)
	end
	return false, reason
end

--- Runs one message from `key` on remote `name` at time `now` (seconds) through every check and
--- then the handler. Returns whether the handler ran and returned without error; otherwise the
--- reason it was refused. Never throws.
function Guard.handle<K>(
	self: Guard<K>,
	key: K,
	name: string,
	now: number,
	...: unknown
): (boolean, Reason?)
	local route = self.routes[name]
	if route == nil then
		-- Net/Server only listens to routed remotes, so this is a stray call: count nothing.
		Log.once("warn", TAG, `a message on {name}, which has no handler`)
		return false, "error"
	end
	local valid, reason = Validate.args(route.specs, ...)
	if not valid then
		return reject(self, key, name, reason :: Reason) -- safe: a failed check always gives a reason
	end
	if not RateLimit.allow(self.limiter, key, name, now) then
		return reject(self, key, name, "rate")
	end
	-- Safe cast: a handler returns nothing, so the only second result is what it raised.
	local ok, problem = pcall(route.handler :: (K, ...unknown) -> unknown, key, ...)
	if not ok then
		-- Our fault, not the sender's: counted and logged, but not fired as a reject.
		count(self, name, "error")
		Log.warn(TAG, `{name} handler failed: {problem}`)
		return false, "error"
	end
	self.passed[name] += 1
	return true, nil
end

--- A copy of the counters: messages handled and rejects by reason, per routed remote.
function Guard.counters<K>(
	self: Guard<K>
): { [string]: { passed: number, rejects: { [string]: number } } }
	local out: { [string]: { passed: number, rejects: { [string]: number } } } = {}
	for name, passed in self.passed do
		out[name] = { passed = passed, rejects = table.clone(self.rejects[name]) }
	end
	return out
end

return Guard
