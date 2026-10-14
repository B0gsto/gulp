--!strict
-- TokenBucket: the rate limit of docs/09, section 5.3, written there as "12/s (20)": `rate` tokens
-- come back each second, up to `size`. The caller passes the time, so the module has no clock,
-- runs in Lune and is deterministic in tests. Nothing here allocates after `new`.

export type TokenBucket = {
	rate: number, -- tokens per second; 0 never refills ("1 per session")
	size: number, -- the most tokens it holds
	tokens: number,
	at: number, -- the time of the last refill, in the caller's seconds
}

-- Refilling in many small steps can leave 0.9999999 of a token where the arithmetic says 1.
local EPSILON = 1e-9

local TokenBucket = {}

local function refill(bucket: TokenBucket, now: number)
	-- A clock that steps back gives nothing and does not move `at` back.
	if now > bucket.at then
		bucket.tokens = math.min(bucket.size, bucket.tokens + (now - bucket.at) * bucket.rate)
		bucket.at = now
	end
end

--- A full bucket: `rate` tokens a second (0 or more), holding at most `size` (more than 0).
function TokenBucket.new(rate: number, size: number, now: number): TokenBucket
	if not (rate >= 0) or not (size > 0) then
		error(`TokenBucket.new: needs rate >= 0 and size > 0, got {rate} and {size}`, 2)
	end
	return { rate = rate, size = size, tokens = size, at = now }
end

--- Takes `cost` tokens (default 1) when the bucket holds them at time `now`. Returns whether it did.
function TokenBucket.take(bucket: TokenBucket, now: number, cost: number?): boolean
	refill(bucket, now)
	local needed = cost or 1
	if bucket.tokens + EPSILON < needed then
		return false
	end
	bucket.tokens = math.max(0, bucket.tokens - needed)
	return true
end

--- The tokens the bucket holds at time `now`, without taking any.
function TokenBucket.available(bucket: TokenBucket, now: number): number
	refill(bucket, now)
	return bucket.tokens
end

--- Fills the bucket again, as of time `now`.
function TokenBucket.reset(bucket: TokenBucket, now: number)
	bucket.tokens = bucket.size
	bucket.at = now
end

return TokenBucket
