--!strict
-- Data/Index: lookups over the generated content tables (docs/09, section 3.2). Rows are found
-- by ID and by wire index (the row's 1-based position in its canon table, sent in packets), and
-- tiers by tier number. Works on the full build and on the soft-launch build, whose wire indices
-- have gaps. Pure Luau: no `game`, no Instances (section 4.4).
local RevivePoints = require("./Generated/RevivePoints")
local Tiers = require("./Generated/Tiers")
local Traits = require("./Generated/Traits")
local Types = require("../Types")

export type Lookup<T> = {
	list: { T }, -- canon order
	byId: { [string]: T },
	byWire: { [number]: T },
}

local function lookup<T>(name: string, rows: { T }, key: (T) -> (string, number)): Lookup<T>
	local byId: { [string]: T } = {}
	local byWire: { [number]: T } = {}
	for _, row in rows do
		local id, wire = key(row)
		if byId[id] ~= nil then
			error(`Data/Index: {name} has the ID {id} twice`)
		end
		if byWire[wire] ~= nil then
			error(`Data/Index: {name} has the wire index {wire} twice`)
		end
		byId[id] = row
		byWire[wire] = row
	end
	return table.freeze({ list = rows, byId = table.freeze(byId), byWire = table.freeze(byWire) })
end

local tierByNumber: { [number]: Types.TierDef } = {}
for _, def in Tiers do
	tierByNumber[def.tier] = def
end

local Index = {
	Tiers = table.freeze({ list = Tiers, byTier = table.freeze(tierByNumber) }),
	Traits = lookup("Traits", Traits, function(def: Types.TraitDef): (string, number)
		return def.id, def.wire
	end),
	RevivePoints = lookup(
		"RevivePoints",
		RevivePoints,
		function(def: Types.RevivePointDef): (string, number)
			return def.id, def.wire
		end
	),
}

return table.freeze(Index)
