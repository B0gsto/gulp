--!strict
--!native
--!optimize 2
-- Codec/WorldInfo: the `WorldInfo` remote (docs/09, sections 5.3, 8.7, 9.1 and 17.3), server to
-- client, reliable, sent once after `ClientReady`. Section 5.3 makes it plain Luau arguments, not a
-- buffer, in this order:
--   1  netVersion   number         Remotes.NET_VERSION (17.3); a client with another value rejoins
--   2  serverEpoch  number         ServerEpoch of 8.7: the server start time, seconds on the
--                                  `GetServerTimeNow` clock; every `timeMs` counts from it
--   3  volumes      { WireVolume } the volume table of 9.1, without the revive points (never sent)
-- A wire volume is the `Volume` record of Types as plain tables: kind, shape, inv (12 numbers),
-- hx, hy, hz, attrs (the part's attributes, `Kind` included).
--
-- `encode` gives the three arguments for `Net/Server.send`; `decode` checks what arrived and
-- rebuilds frozen `Volume` records for Logic/VolumeMath. Not a hot path: it runs once per join.
local Remotes = require("../Remotes")
local Types = require("../../Types")
local VolumeMath = require("../../Logic/VolumeMath")

type Volume = Types.Volume
type VolumeAttribute = Types.VolumeAttribute

export type Info = { netVersion: number, serverEpoch: number, volumes: { Volume } }
export type Reason = "version" | "type" | "size" | "range"

local WorldInfo = {}

--- Bounds `decode` holds the table to, well above a full map (section 9.1 lists a few hundred
--- volumes at most), so a malformed table cannot make a client loop or allocate without end.
WorldInfo.MAX_VOLUMES = 1024
WorldInfo.MAX_ATTRIBUTES = 16
WorldInfo.MAX_STRING = 256

local function finite(value: unknown): boolean
	return type(value) == "number" and math.abs(value) < math.huge
end

--- The arguments to send: NET_VERSION, `serverEpoch` and plain copies of `volumes`. Throws on a
--- programmer mistake: a revive point in the list, or more volumes than a client accepts.
function WorldInfo.encode(serverEpoch: number, volumes: { Volume }): (number, number, { Volume })
	if #volumes > WorldInfo.MAX_VOLUMES then
		error(
			`WorldInfo.encode: {#volumes} volumes, the most a client takes is {WorldInfo.MAX_VOLUMES}`,
			2
		)
	end
	local wire: { Volume } = table.create(#volumes)
	for i, v in volumes do
		if v.kind == "RevivePoint" then
			error("WorldInfo.encode: revive points are never sent to clients (09 §9.1)", 2)
		end
		wire[i] = {
			kind = v.kind,
			shape = v.shape,
			inv = table.clone(v.inv),
			hx = v.hx,
			hy = v.hy,
			hz = v.hz,
			attrs = table.clone(v.attrs),
		}
	end
	return Remotes.NET_VERSION, serverEpoch, wire
end

-- The attributes of one wire volume, checked and copied, or nil.
local function decodeAttrs(value: unknown, kind: string): { [string]: VolumeAttribute }?
	if type(value) ~= "table" then
		return nil
	end
	local attrs: { [string]: VolumeAttribute } = {}
	local count = 0
	for key, item in value :: { [unknown]: unknown } do -- safe: type said table
		count += 1
		if
			count > WorldInfo.MAX_ATTRIBUTES
			or type(key) ~= "string"
			or #key > WorldInfo.MAX_STRING
		then
			return nil
		end
		if type(item) == "string" then
			if #item > WorldInfo.MAX_STRING then
				return nil
			end
		elseif type(item) ~= "boolean" and not finite(item) then
			return nil
		end
		attrs[key] = item :: VolumeAttribute -- safe: string, boolean or finite number
	end
	if attrs.Kind ~= kind then
		return nil
	end
	return table.freeze(attrs)
end

-- One wire volume, checked and rebuilt, or nil.
local function decodeVolume(value: unknown): Volume?
	if type(value) ~= "table" then
		return nil
	end
	local v = value :: { [string]: unknown } -- safe: type said table
	local kindName, shapeName = v.kind, v.shape
	local kind = if type(kindName) == "string" then VolumeMath.kindOf(kindName) else nil
	local shape = if type(shapeName) == "string" then VolumeMath.shapeOf(shapeName) else nil
	if kind == nil or kind == "RevivePoint" or shape == nil or type(v.inv) ~= "table" then
		return nil
	end
	local source = v.inv :: { [unknown]: unknown } -- safe: type said table
	local inv = table.create(12)
	local entries = 0
	for _ in source do
		entries += 1
	end
	if entries ~= 12 then
		return nil
	end
	for i = 1, 12 do
		local n = source[i]
		if not finite(n) then
			return nil
		end
		inv[i] = n :: number -- safe: finite said number
	end
	local hx, hy, hz = v.hx, v.hy, v.hz
	if not (finite(hx) and finite(hy) and finite(hz)) then
		return nil
	end
	local x, y, z = hx :: number, hy :: number, hz :: number -- safe: finite said number
	if x < 0 or y < 0 or z < 0 then
		return nil
	end
	local attrs = decodeAttrs(v.attrs, kind)
	if attrs == nil then
		return nil
	end
	return table.freeze({
		kind = kind,
		shape = shape,
		inv = table.freeze(inv),
		hx = x,
		hy = y,
		hz = z,
		attrs = attrs,
	})
end

--- Checks the three arguments as they arrived and returns the info, or nil and why: "version"
--- (another NET_VERSION: rejoin), "type" (an argument of the wrong type), "size" (too many
--- volumes) or "range" (a value out of range or a malformed volume). Never throws.
function WorldInfo.decode(
	netVersion: unknown,
	serverEpoch: unknown,
	volumes: unknown
): (Info?, Reason?)
	if
		type(netVersion) ~= "number"
		or type(serverEpoch) ~= "number"
		or type(volumes) ~= "table"
	then
		return nil, "type"
	end
	if netVersion ~= Remotes.NET_VERSION then
		return nil, "version"
	end
	if not (finite(serverEpoch) and serverEpoch >= 0) then
		return nil, "range"
	end
	local list = volumes :: { [unknown]: unknown } -- safe: type said table
	local count = 0
	for _ in list do
		count += 1
		if count > WorldInfo.MAX_VOLUMES then
			return nil, "size"
		end
	end
	local out: { Volume } = table.create(count)
	for i = 1, count do
		local v = decodeVolume(list[i])
		if v == nil then
			return nil, "range" -- also a table that is not a list: a hole reads as nil
		end
		out[i] = v
	end
	return table.freeze({
		netVersion = netVersion,
		serverEpoch = serverEpoch,
		volumes = table.freeze(out),
	}),
		nil
end

return WorldInfo
