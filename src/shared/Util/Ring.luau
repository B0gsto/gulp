--!strict
-- Ring: a fixed-capacity ring of values. Pushing into a full ring drops the oldest value.
-- Plain Luau, so it runs in Lune. `push`, `get`, `newest` and `size` allocate nothing.

export type Ring<T> = {
	capacity: number,
	count: number,
	head: number, -- index in `items` of the newest value; 0 while the ring is empty
	items: { T },
}

local Ring = {}

--- A new empty ring that holds at most `capacity` values (a whole number, 1 or more).
function Ring.new<T>(capacity: number): Ring<T>
	if capacity < 1 or capacity % 1 ~= 0 then
		error(`Ring.new: capacity must be a whole number of 1 or more, got {capacity}`, 2)
	end
	return { capacity = capacity, count = 0, head = 0, items = table.create(capacity) }
end

--- Adds `value` as the newest. Returns the value it pushed out, or nil while there was room.
function Ring.push<T>(ring: Ring<T>, value: T): T?
	local index = ring.head % ring.capacity + 1
	local dropped: T? = nil
	if ring.count == ring.capacity then
		dropped = ring.items[index]
	else
		ring.count += 1
	end
	ring.items[index] = value
	ring.head = index
	return dropped
end

--- How many values the ring holds now.
function Ring.size<T>(ring: Ring<T>): number
	return ring.count
end

--- The value at `index`, where 1 is the oldest and `Ring.size(ring)` the newest; nil outside.
function Ring.get<T>(ring: Ring<T>, index: number): T?
	if index < 1 or index > ring.count then
		return nil
	end
	return ring.items[(ring.head - ring.count + index - 1) % ring.capacity + 1]
end

--- The newest value, or the one `back` pushes before it; nil when the ring does not reach that far.
function Ring.newest<T>(ring: Ring<T>, back: number?): T?
	return Ring.get(ring, ring.count - (back or 0))
end

--- Empties the ring and keeps its capacity.
function Ring.clear<T>(ring: Ring<T>)
	table.clear(ring.items)
	ring.count = 0
	ring.head = 0
end

--- A new array of the values, oldest first. It allocates: not for hot paths.
function Ring.toArray<T>(ring: Ring<T>): { T }
	local values: { T } = table.create(ring.count)
	for index = 1, ring.count do
		values[index] = ring.items[(ring.head - ring.count + index - 1) % ring.capacity + 1]
	end
	return values
end

return Ring
