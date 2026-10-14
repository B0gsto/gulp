--!strict
-- Signal: the one signal class of the game (docs/09, section 2.3). Plain Luau, so it runs in Lune.
--
-- Handlers run synchronously, in the order they were connected, on the caller's thread. A handler
-- that throws stops the fire and the error reaches the caller: it is a programmer mistake
-- (section 4.6). Connecting or disconnecting during a fire is safe: a handler connected during a
-- fire is first called by the next one, and a disconnected handler is never called again.
-- `fire` allocates nothing, so it may be used from a hot path.

export type Connection = {
	connected: boolean,
	disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	fire: (self: Signal<T...>, T...) -> (),
	disconnectAll: (self: Signal<T...>) -> (),
}

type Handler = (...unknown) -> ()
type Link = {
	connected: boolean,
	disconnect: (self: Link) -> (),
	handler: Handler,
	once: boolean,
	owner: State,
}
-- `links` is replaced, never changed in place, so a running fire keeps the list it started with.
type State = { links: { Link } }

local Signal = {}

local function disconnect(link: Link)
	if not link.connected then
		return
	end
	link.connected = false
	local owner = link.owner
	local kept: { Link } = table.create(#owner.links)
	for _, other in owner.links do
		if other ~= link then
			table.insert(kept, other)
		end
	end
	owner.links = kept
end

local function add(self: State, handler: Handler, once: boolean): Link
	local link: Link = {
		connected = true,
		disconnect = disconnect,
		handler = handler,
		once = once,
		owner = self,
	}
	local links = table.clone(self.links)
	table.insert(links, link)
	self.links = links
	return link
end

local function connect(self: State, handler: Handler): Link
	return add(self, handler, false)
end

local function once(self: State, handler: Handler): Link
	return add(self, handler, true)
end

local function fire(self: State, ...: unknown)
	for _, link in self.links do
		if link.connected then
			if link.once then
				disconnect(link)
			end
			link.handler(...)
		end
	end
end

local function disconnectAll(self: State)
	for _, link in self.links do
		link.connected = false
	end
	self.links = {}
end

--- A new signal with no handlers. `signal:connect(fn)` and `signal:once(fn)` return a connection
--- with `connected` and `:disconnect()`; `signal:fire(...)` calls every handler;
--- `signal:disconnectAll()` drops them all.
function Signal.new<T...>(): Signal<T...>
	local state = {
		links = {},
		connect = connect,
		once = once,
		fire = fire,
		disconnectAll = disconnectAll,
	}
	-- Safe cast: the four functions take the state as `self` and pass the fired values through
	-- unchanged, so the only thing the public type hides is the private `links` field.
	return (state :: any) :: Signal<T...>
end

return Signal
