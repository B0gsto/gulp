--!strict
-- SlotPool: the 24 player slots of a server (docs/09, section 5.1). A slot is a number 1 to 24
-- given at join; it is the player's index in every buffer and their cove number, so it is
-- unique among the players present and free again once its player has left. Numbers and tables
-- only, so it runs in Lune. PlayerLifecycle owns the one pool of a server.
export type Pool = {
	size: number,
	used: { [number]: boolean },
	count: number,
}

local SlotPool = {}

--- Slots per server: 24 players, 24 coves (docs/09, sections 5 and 13.1).
SlotPool.SIZE = 24

--- An empty pool of `size` slots (default 24).
function SlotPool.new(size: number?): Pool
	local n = size or SlotPool.SIZE
	assert(n >= 1 and n == math.floor(n), "SlotPool.new: size must be a whole number ≥ 1")
	return { size = n, used = {}, count = 0 }
end

--- True when `slot` is a slot of this pool and nobody holds it.
function SlotPool.isFree(pool: Pool, slot: number): boolean
	return slot >= 1 and slot <= pool.size and slot == math.floor(slot) and not pool.used[slot]
end

--- Takes a free slot and returns it, or nil when the pool is full. The first free slot of
--- `preference` wins; with no preference (or none of it free) the lowest free slot is taken.
--- The cove rule of docs/09, section 13.1 (nearest the Nursery for a new account, farthest from
--- Little Arch among the 20 nearest for a returning one) is passed in as `preference`.
function SlotPool.take(pool: Pool, preference: { number }?): number?
	if pool.count >= pool.size then
		return nil
	end
	local chosen: number? = nil
	if preference then
		for _, slot in preference do
			if SlotPool.isFree(pool, slot) then
				chosen = slot
				break
			end
		end
	end
	if not chosen then
		for slot = 1, pool.size do
			if not pool.used[slot] then
				chosen = slot
				break
			end
		end
	end
	local slot = chosen :: number -- safe: count < size, so the scan found one
	pool.used[slot] = true
	pool.count += 1
	return slot
end

--- Frees `slot`. Returns false (and changes nothing) when it was not held.
function SlotPool.free(pool: Pool, slot: number): boolean
	if not pool.used[slot] then
		return false
	end
	pool.used[slot] = nil
	pool.count -= 1
	return true
end

--- Slots in use.
function SlotPool.count(pool: Pool): number
	return pool.count
end

return table.freeze(SlotPool)
