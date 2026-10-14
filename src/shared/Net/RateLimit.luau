--!strict
-- RateLimit: the pure core of the rate limiter (docs/09, section 14.2, step 4): one token
-- bucket per key per remote, with the rates and bucket sizes of the table in section 5.3. The
-- key is whatever identifies a sender: a Player on the server, any value in tests.
-- Net/RateLimiter (server) wraps it for players and forgets a player when they leave.
--
-- No clock: the caller passes the time, so tests are deterministic. A key's buckets are made on
-- its first message and start full.
local TokenBucket = require("../Util/TokenBucket")

local Remotes = require("./Remotes")

type TokenBucket = TokenBucket.TokenBucket

export type Limit = { rate: number, size: number }

export type RateLimit<K> = {
	limits: { [string]: Limit },
	buckets: { [K]: { [string]: TokenBucket } },
}

local RateLimit = {}

--- The limits of every client-to-server remote in the table of section 5.3, by name.
function RateLimit.limitsFromRemotes(): { [string]: Limit }
	local limits: { [string]: Limit } = {}
	for _, def in Remotes.list do
		if def.direction == "ClientToServer" then
			local rate, size = def.rate, def.bucket
			if rate == nil or size == nil then
				error(`RateLimit: remote "{def.name}" has no rate limit in the remote table`, 2)
			end
			limits[def.name] = { rate = rate, size = size }
		end
	end
	return limits
end

--- A limiter over `limits` (by remote name); the table of section 5.3 when nil.
function RateLimit.new<K>(limits: { [string]: Limit }?): RateLimit<K>
	return { limits = limits or RateLimit.limitsFromRemotes(), buckets = {} }
end

--- Takes one token from `key`'s bucket for `remote` at time `now`. Returns whether the message
--- may pass. A remote with no limit is a programmer mistake and throws.
function RateLimit.allow<K>(self: RateLimit<K>, key: K, remote: string, now: number): boolean
	local perKey = self.buckets[key]
	if perKey == nil then
		perKey = {}
		self.buckets[key] = perKey
	end
	local bucket = perKey[remote]
	if bucket == nil then
		local limit = self.limits[remote]
		if limit == nil then
			error(`RateLimit: no limit for remote "{remote}"`, 2)
		end
		bucket = TokenBucket.new(limit.rate, limit.size, now)
		perKey[remote] = bucket
	end
	return TokenBucket.take(bucket, now)
end

--- Drops every bucket of `key` (a player left). A key that comes back starts full again.
function RateLimit.forget<K>(self: RateLimit<K>, key: K)
	self.buckets[key] = nil
end

--- How many keys hold buckets. Tests use it to prove that leaving cleans up.
function RateLimit.keyCount<K>(self: RateLimit<K>): number
	local count = 0
	for _ in self.buckets do
		count += 1
	end
	return count
end

return RateLimit
