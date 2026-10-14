--!strict
-- Render/Pools (task S3-C4; docs/09, sections 3 and 8.8): reusable client-made objects, handed out
-- afresh every frame. A pool belongs to one look (PreyRenderer keeps one per prey kind, so every
-- part in it shares a mesh and the engine can instance the draw, 8.8 and V32).
--
-- Each frame: `begin`, then `take` once per object drawn (it hands back the same objects in the
-- same order as last frame, and makes a new one only past the end, up to the cap), then `finish`,
-- which returns the range of objects that were used last frame and are not now, so the caller
-- can hide them. No allocation once the pool has grown.

export type Pool<T> = {
	items: { T },
	used: number, -- taken this frame
	lastUsed: number, -- taken last frame
	cap: number,
	make: () -> T,
}

local Pools = {}

--- An empty pool that makes objects with `make`, at most `cap` of them.
function Pools.new<T>(make: () -> T, cap: number): Pool<T>
	return { items = {}, used = 0, lastUsed = 0, cap = cap, make = make }
end

--- Starts a frame.
function Pools.begin<T>(pool: Pool<T>)
	pool.lastUsed = pool.used
	pool.used = 0
end

--- The next object for this frame, and whether it was hidden until now (new, or unused last
--- frame). Nil when the cap is reached.
function Pools.take<T>(pool: Pool<T>): (T?, boolean)
	local n = pool.used + 1
	local item = pool.items[n]
	if item == nil then
		if n > pool.cap then
			return nil, false
		end
		item = pool.make()
		pool.items[n] = item
	end
	pool.used = n
	return item, n > pool.lastUsed
end

--- Ends a frame: the objects `from` to `to` (inclusive; empty when from > to) were drawn last
--- frame and are not now.
function Pools.finish<T>(pool: Pool<T>): (number, number)
	return pool.used + 1, pool.lastUsed
end

--- The object at `index` (1-based).
function Pools.at<T>(pool: Pool<T>, index: number): T
	return pool.items[index]
end

--- Objects made so far.
function Pools.size<T>(pool: Pool<T>): number
	return #pool.items
end

--- Sets the cap; objects past it are passed to `destroy` and forgotten.
function Pools.setCap<T>(pool: Pool<T>, cap: number, destroy: (T) -> ())
	pool.cap = cap
	local items = pool.items
	for n = #items, cap + 1, -1 do
		destroy(items[n])
		items[n] = nil
	end
	pool.used = math.min(pool.used, cap)
	pool.lastUsed = math.min(pool.lastUsed, cap)
end

return table.freeze(Pools)
