--!strict
-- Net/Server: the only module that creates remotes (docs/09, section 4.4). Requiring it makes
-- one remote per row of the table in section 5.3 under ReplicatedStorage.Net, so Main requires
-- it before any service.
--
-- Every client-to-server handler is registered through `on(name, specs, handler)` and runs inside
-- the validation wrapper of section 14.2 (Shared.Net.Guard): count, type, size and range checks,
-- a per-player token bucket, then the handler under pcall. Rejects are counted by remote and
-- reason; the ones a player caused fire `rejected` for MovementValidator's suspicion.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assert = require(ReplicatedStorage.Shared.Util.Assert)
local Guard = require(ReplicatedStorage.Shared.Net.Guard)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Validate = require(ReplicatedStorage.Shared.Net.Validate)

local RateLimiter = require("./RateLimiter")

export type Spec = Validate.Spec
export type Reason = Guard.Reason
export type Counters = { [string]: { passed: number, rejects: { [string]: number } } }

local TAG = "Net"

local Server = {}

--- The spec builders (`Validate.int(1, 24)`, `Validate.buffer(8, 40, accepts)`, ...), here so a
--- service needs one require.
Server.Validate = Validate

local guard: Guard.Guard<Player> = Guard.new(RateLimiter.limiter)

--- Fires (player, remote name, reason) for every message a player caused to be rejected:
--- "count", "type", "size", "range" (malformed) or "rate" (flooding).
Server.rejected = guard.rejected :: Signal.Signal<Player, string, Reason>

local reliable: { [string]: RemoteEvent } = {}
local unreliable: { [string]: UnreliableRemoteEvent } = {}

-- Create every remote. A folder already in the place (saved from an old session) is replaced,
-- because nothing but this module may own remotes.
do
	local stale = ReplicatedStorage:FindFirstChild(Remotes.FOLDER)
	if stale then
		Log.warn(TAG, `replacing a ReplicatedStorage.{Remotes.FOLDER} that was already there`)
		stale:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = Remotes.FOLDER
	for _, def in Remotes.list do
		if def.kind == "Reliable" then
			local remote = Instance.new("RemoteEvent")
			remote.Name = def.name
			remote.Parent = folder
			reliable[def.name] = remote
		else
			local remote = Instance.new("UnreliableRemoteEvent")
			remote.Name = def.name
			remote.Parent = folder
			unreliable[def.name] = remote
		end
	end
	-- Parented last, so a client that finds the folder finds every remote in it.
	folder.Parent = ReplicatedStorage
end

--- Registers the handler of the client-to-server remote `name`. `specs` has one entry per
--- argument (built with `Server.Validate`); the handler runs only for messages that pass them and
--- the player's rate limit, and gets the player then the checked arguments. One handler per
--- remote. Throws on a programmer mistake: unknown remote, wrong direction, a second handler, or
--- a spec that does not fit the remote table.
function Server.on<T...>(name: string, specs: { Spec }, handler: (Player, T...) -> ())
	-- Safe cast: Guard calls the handler only with arguments that passed `specs`, and the caller
	-- writes `specs` to describe T... (one entry per argument, same types).
	local checked = (handler :: unknown) :: (Player, ...unknown) -> ()
	Guard.route(guard, name, specs, checked)
	local function onEvent(player: Player, ...: unknown)
		Guard.handle(guard, player, name, os.clock(), ...)
	end
	local remote = reliable[name]
	if remote then
		remote.OnServerEvent:Connect(onEvent)
	else
		unreliable[name].OnServerEvent:Connect(onEvent)
	end
end

-- The row of a server-to-client remote, checking the outgoing payload in dev builds.
local function outgoing(name: string, ...: unknown): Remotes.RemoteDef
	local def = Remotes.get(name)
	if def.direction ~= "ServerToClient" then
		error(`Net: "{name}" goes from client to server; the server cannot send it`, 3)
	end
	-- Messages are built only on failure: sends run every tick (section 4.7, no string building).
	if Assert.isEnabled() and def.encoding == "buffer" then
		local payload = ...
		if typeof(payload) ~= "buffer" then
			Assert.fail(`Net: "{name}" sends one buffer, got a {typeof(payload)}`)
		end
		local length = buffer.len(payload :: buffer) -- safe: checked to be a buffer just above
		if def.maxBytes and length > def.maxBytes then
			Assert.fail(`Net: "{name}" payload is {length} bytes, the table allows {def.maxBytes}`)
		end
	end
	return def
end

local function fire(def: Remotes.RemoteDef, player: Player, ...: unknown)
	if def.kind == "Reliable" then
		reliable[def.name]:FireClient(player, ...)
	else
		unreliable[def.name]:FireClient(player, ...)
	end
end

--- Sends server-to-client remote `name` to one player. A player who has left is skipped.
function Server.send(player: Player, name: string, ...: unknown)
	local def = outgoing(name, ...)
	if player.Parent == Players then
		fire(def, player, ...)
	end
end

--- Sends server-to-client remote `name` to every player in `players` who is still here (the
--- interest lists of section 8.5).
function Server.sendTo(players: { Player }, name: string, ...: unknown)
	local def = outgoing(name, ...)
	for _, player in players do
		if player.Parent == Players then
			fire(def, player, ...)
		end
	end
end

--- Sends server-to-client remote `name` to every player.
function Server.sendAll(name: string, ...: unknown)
	local def = outgoing(name, ...)
	if def.kind == "Reliable" then
		reliable[name]:FireAllClients(...)
	else
		unreliable[name]:FireAllClients(...)
	end
end

--- Sends server-to-client remote `name` to every player except `except`.
function Server.sendExcept(except: Player, name: string, ...: unknown)
	local def = outgoing(name, ...)
	for _, player in Players:GetPlayers() do
		if player ~= except then
			fire(def, player, ...)
		end
	end
end

--- Whether client-to-server remote `name` has a handler.
function Server.isRouted(name: string): boolean
	return Guard.isRouted(guard, name)
end

--- A copy of the counters: messages handled and rejects by reason, per routed remote.
function Server.counters(): Counters
	return Guard.counters(guard)
end

return Server
