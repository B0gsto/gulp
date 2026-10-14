--!strict
-- Data/Index: lookups over the generated content tables (docs/09, section 3.2). Rows are found
-- by ID and by wire index (the row's 1-based position in its canon table, sent in packets),
-- tiers by tier number and products (which have no wire index) by ID only. Works on the full build and on the soft-launch build, whose wire indices
-- have gaps. Pure Luau: no `game`, no Instances (section 4.4).
local Codex = require("./Generated/Codex")
local Goals = require("./Generated/Goals")
local Hazards = require("./Generated/Hazards")
local Predators = require("./Generated/Predators")
local Prey = require("./Generated/Prey")
local Products = require("./Generated/Products")
local RevivePoints = require("./Generated/RevivePoints")
local Species = require("./Generated/Species")
local Tides = require("./Generated/Tides")
local Tiers = require("./Generated/Tiers")
local TraitPrey = require("./Generated/TraitPrey")
local Traits = require("./Generated/Traits")
local Types = require("../Types")
local Zones = require("./Generated/Zones")

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

local productById: { [string]: Types.ProductDef } = {}
for _, def in Products do
	if productById[def.id] ~= nil then
		error(`Data/Index: Products has the ID {def.id} twice`)
	end
	productById[def.id] = def
end

local Index = {
	Products = table.freeze({ list = Products, byId = table.freeze(productById) }),
	Tiers = table.freeze({ list = Tiers, byTier = table.freeze(tierByNumber) }),
	Codex = lookup("Codex", Codex, function(def: Types.CodexCategoryDef): (string, number)
		return def.id, def.wire
	end),
	Goals = lookup("Goals", Goals, function(def: Types.GoalDef): (string, number)
		return def.id, def.wire
	end),
	Hazards = lookup("Hazards", Hazards, function(def: Types.HazardDef): (string, number)
		return def.id, def.wire
	end),
	Predators = lookup("Predators", Predators, function(def: Types.PredatorDef): (string, number)
		return def.id, def.wire
	end),
	Prey = lookup("Prey", Prey, function(def: Types.PreyDef): (string, number)
		return def.id, def.wire
	end),
	RevivePoints = lookup(
		"RevivePoints",
		RevivePoints,
		function(def: Types.RevivePointDef): (string, number)
			return def.id, def.wire
		end
	),
	Species = lookup("Species", Species, function(def: Types.SpeciesDef): (string, number)
		return def.id, def.wire
	end),
	Tides = lookup("Tides", Tides, function(def: Types.TideDef): (string, number)
		return def.id, def.wire
	end),
	TraitPrey = lookup("TraitPrey", TraitPrey, function(def: Types.PreyDef): (string, number)
		return def.id, def.wire
	end),
	Traits = lookup("Traits", Traits, function(def: Types.TraitDef): (string, number)
		return def.id, def.wire
	end),
	Zones = lookup("Zones", Zones, function(def: Types.ZoneDef): (string, number)
		return def.id, def.wire
	end),
}

return table.freeze(Index)
