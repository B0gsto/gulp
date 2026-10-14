--!strict
-- Remotes: the remote table of docs/09, section 5.3, and the net protocol version of section
-- 17.3. Pure data: Net/Server creates one remote per entry under ReplicatedStorage.Net, and
-- Net/Client waits for them. Nothing else creates remotes (section 4.4).
--
-- `encoding` follows the rule above the table in 5.3: every payload is one `buffer` except
-- `State` and the low-rate `*Action` remotes, which carry a small array of scalars. `ClientReady`
-- carries nothing.
local Types = require("../Types")

export type Kind = "Reliable" | "Unreliable"
export type Direction = "ClientToServer" | "ServerToClient"
export type Encoding = "none" | "buffer" | "scalars"

export type RemoteDef = {
	name: string,
	kind: Kind,
	direction: Direction,
	encoding: Encoding,
	payload: string, -- the payload column of 5.3, for people
	minBytes: number?, -- a buffer payload: the shortest length 5.3 allows
	maxBytes: number?, -- a buffer payload: the longest length 5.3 allows, where it states one
	maxString: number?, -- the longest string argument 5.3 allows, where it states one
	rate: number?, -- client to server only: tokens a second; 0 never refills ("1 per session")
	bucket: number?, -- client to server only: the bucket size
	scope: Types.Scope, -- "L" for remotes of a later scope (EmoteAction)
}

local Remotes = {}

--- The net protocol version (section 17.3). Bump it with any packet layout change; it is sent
--- in `WorldInfo`, and a client with a different value is told to rejoin.
Remotes.NET_VERSION = 1

--- The folder under ReplicatedStorage that holds every remote.
Remotes.FOLDER = "Net"

local function c2s(
	name: string,
	kind: Kind,
	encoding: Encoding,
	payload: string,
	rate: number,
	bucket: number,
	scope: Types.Scope
): RemoteDef
	return {
		name = name,
		kind = kind,
		direction = "ClientToServer",
		encoding = encoding,
		payload = payload,
		rate = rate,
		bucket = bucket,
		scope = scope,
	}
end

local function s2c(name: string, kind: Kind, encoding: Encoding, payload: string): RemoteDef
	return {
		name = name,
		kind = kind,
		direction = "ServerToClient",
		encoding = encoding,
		payload = payload,
		scope = "MVP",
	}
end

local function sized(def: RemoteDef, minBytes: number?, maxBytes: number?): RemoteDef
	def.minBytes = minBytes
	def.maxBytes = maxBytes
	return def
end

local function withString(def: RemoteDef, maxString: number): RemoteDef
	def.maxString = maxString
	return def
end

--- Every remote, in the order of the table in 5.3.
Remotes.list = {
	-- Client to server. Rate limit per player (bucket size).
	c2s("ClientReady", "Reliable", "none", "none", 0, 1, "MVP"), -- 1 per session
	sized(c2s("Bite", "Reliable", "buffer", "8 to 40 bytes (8.9)", 12, 20, "MVP"), 8, 40),
	sized(c2s("Ability", "Reliable", "buffer", "6 bytes: op, seq, time", 4, 6, "MVP"), 6, 6),
	c2s("RunAction", "Reliable", "scalars", "op + up to 2 numbers", 5, 8, "MVP"),
	c2s("CoveAction", "Reliable", "scalars", "op + up to 2 scalars", 5, 8, "MVP"),
	withString(
		c2s("ShopAction", "Reliable", "scalars", "op + sku string <= 32 chars", 3, 5, "MVP"),
		32
	),
	c2s("GoalAction", "Reliable", "scalars", "op + index", 2, 4, "MVP"),
	c2s("SettingsSet", "Reliable", "buffer", "key + value", 2, 4, "MVP"),
	c2s("TutorialStep", "Reliable", "buffer", "step number", 2, 4, "MVP"),
	c2s("EmoteAction", "Reliable", "scalars", "emote index 1 to 6", 1 / 3, 1, "L"), -- 1 per 3 s
	sized(
		c2s(
			"Telemetry",
			"Unreliable",
			"buffer",
			"8 bytes: fps bucket, graphics tier, memory bucket, screen class, display size, input mode",
			1 / 20, -- 1 per 20 s
			2,
			"MVP"
		),
		8,
		8
	),

	-- Server to client.
	s2c("State", "Reliable", "scalars", "path string, value"),
	s2c("WorldInfo", "Reliable", "buffer", "volume table, once after ClientReady"),
	sized(s2c("BiteResult", "Reliable", "buffer", "9 bytes"), 9, 9),
	s2c("PreyEvent", "Reliable", "buffer", "1 + 6n bytes"),
	s2c(
		"CreatureEvent",
		"Reliable",
		"buffer",
		"gulped, revived, status, tier change, bite absorbed, emote [L]"
	),
	sized(s2c("PredatorEvent", "Reliable", "buffer", "14 bytes"), 14, 14),
	s2c("TideEvent", "Reliable", "buffer", "override start and end only"),
	s2c("CoveView", "Reliable", "buffer", "specimen list of one cove"),
	sized(s2c("PreyState", "Unreliable", "buffer", "<= 900 bytes, 10 Hz"), nil, 900),
	sized(s2c("PredatorState", "Unreliable", "buffer", "<= 400 bytes, 10 Hz"), nil, 400),
} :: { RemoteDef }

--- Every remote by name.
Remotes.byName = {} :: { [string]: RemoteDef }
for _, def in Remotes.list do
	Remotes.byName[def.name] = def
end

--- The remote called `name`. Asking for one that does not exist is a programmer mistake.
function Remotes.get(name: string): RemoteDef
	local def = Remotes.byName[name]
	if def == nil then
		error(`Remotes: unknown remote "{name}". Add it to the table of docs/09, section 5.3.`, 2)
	end
	return def
end

return Remotes
