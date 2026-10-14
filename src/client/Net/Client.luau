--!strict
-- Net/Client: the client side of the remote table (docs/09, section 5.3). Requiring it waits for
-- ReplicatedStorage.Net and every remote in it, which Net/Server creates; it never creates one.
--
-- `send` keeps to the same token buckets the server enforces (Shared.Net.RateLimit), so an honest
-- client that taps fast drops its own extra messages instead of earning flood suspicion.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local RateLimit = require(ReplicatedStorage.Shared.Net.RateLimit)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local TAG = "Net"

local Client = {}

-- ServerEpoch (8.7), from the Net folder until WorldInfo carries it (see Net/Server).
local epoch = 0

--- The client's estimate of server time now as a packet's `timeMs` (8.7): ms since ServerEpoch.
function Client.timeMs(): number
	return math.floor((workspace:GetServerTimeNow() - epoch) * 1000)
end

--- The net protocol version this client was built with; compare it with the one in `WorldInfo`.
Client.NET_VERSION = Remotes.NET_VERSION

local reliable: { [string]: RemoteEvent } = {}
local unreliable: { [string]: UnreliableRemoteEvent } = {}

do
	local folder = ReplicatedStorage:WaitForChild(Remotes.FOLDER)
	local value = folder:GetAttribute("ServerEpoch")
	if type(value) == "number" then
		epoch = value
	else
		Log.warn(TAG, "ReplicatedStorage.Net has no ServerEpoch; timeMs counts from 0")
	end
	for _, def in Remotes.list do
		local remote = folder:WaitForChild(def.name)
		if def.kind == "Reliable" and remote:IsA("RemoteEvent") then
			reliable[def.name] = remote
		elseif def.kind == "Unreliable" and remote:IsA("UnreliableRemoteEvent") then
			unreliable[def.name] = remote
		else
			error(`Net: {def.name} is a {remote.ClassName}, the remote table says {def.kind}`)
		end
	end
end

-- One sender, so one key.
local limiter: RateLimit.RateLimit<boolean> = RateLimit.new()

--- Sends client-to-server remote `name` with `...` as its payload. Returns false, and sends
--- nothing, when it would go over the remote's rate limit. Throws on an unknown remote or a
--- server-to-client one.
function Client.send(name: string, ...: unknown): boolean
	local def = Remotes.get(name)
	if def.direction ~= "ClientToServer" then
		error(`Net: "{name}" goes from server to client; the client cannot send it`, 2)
	end
	if not RateLimit.allow(limiter, true, name, os.clock()) then
		Log.once("info", TAG, `holding back {name}: over its rate limit`)
		return false
	end
	if def.kind == "Reliable" then
		reliable[name]:FireServer(...)
	else
		unreliable[name]:FireServer(...)
	end
	return true
end

--- Calls `handler` with the payload of every server-to-client message on `name`. Throws on an
--- unknown remote or a client-to-server one.
function Client.on<T...>(name: string, handler: (T...) -> ()): RBXScriptConnection
	local def = Remotes.get(name)
	if def.direction ~= "ServerToClient" then
		error(`Net: "{name}" goes from client to server; the client cannot listen to it`, 2)
	end
	-- Safe cast: the server is trusted, and its codec for `name` sends what the caller's T...
	-- describes. Packets are decoded and range-checked by the Codec modules, not here.
	local listener = (handler :: unknown) :: (...unknown) -> ()
	if def.kind == "Reliable" then
		return reliable[name].OnClientEvent:Connect(listener)
	end
	return unreliable[name].OnClientEvent:Connect(listener)
end

return Client
