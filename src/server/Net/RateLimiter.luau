--!strict
-- Net/RateLimiter: per-player token buckets keyed by remote (docs/09, sections 5.3 and 14.2,
-- step 4). The logic is the pure Shared.Net.RateLimit, unit-tested in Lune; this module only
-- binds it to players and the server clock, and forgets a player's buckets when they leave.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RateLimit = require(ReplicatedStorage.Shared.Net.RateLimit)

local RateLimiter = {}

--- The one limiter of the server: every client-to-server remote of the table in 5.3, by player.
RateLimiter.limiter = RateLimit.new() :: RateLimit.RateLimit<Player>

--- Takes one token from `player`'s bucket for `remote`. Returns whether the message may pass.
function RateLimiter.allow(player: Player, remote: string): boolean
	return RateLimit.allow(RateLimiter.limiter, player, remote, os.clock())
end

--- Drops every bucket of `player`. Called on leave; a rejoin starts with full buckets.
function RateLimiter.forget(player: Player)
	RateLimit.forget(RateLimiter.limiter, player)
end

--- How many players hold buckets (engine specs check that leaving cleans up).
function RateLimiter.playerCount(): number
	return RateLimit.keyCount(RateLimiter.limiter)
end

Players.PlayerRemoving:Connect(RateLimiter.forget)

return RateLimiter
