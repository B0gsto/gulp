--!strict
-- StatePatch: the paths of the `State` remote (docs/09, sections 5.1 to 5.3; task S4-C6, module
-- B20). A path is dot-separated keys into a table, such as `cove.slots` or `goals.list.2.progress`;
-- a segment of digits indexes an array. The server uses `set` to patch a profile and `diff` to
-- send only what changed; the client's StateStore uses `apply` to keep its mirror and `touches`
-- to pick the observers to call. Pure, so it runs in Lune.
local SaveSchema = require("./SaveSchema")

export type Key = string | number
export type Patch = { path: string, value: any }

local StatePatch = {}

StatePatch.MAX_PATH = 128 -- characters; ours: the longest real path is under 60
StatePatch.MAX_DEPTH = 8

--- The keys of `path`, or nil when it is malformed (empty, an empty segment, too long or deep).
--- A segment of digits with no leading zero becomes an array index.
function StatePatch.split(path: string): { Key }?
	if #path == 0 or #path > StatePatch.MAX_PATH then
		return nil
	end
	local keys: { Key } = {}
	for segment in string.gmatch(path .. ".", "([^.]*)%.") do
		if segment == "" then
			return nil
		end
		local index = if string.match(segment, "^[1-9]%d*$") then tonumber(segment) else nil
		table.insert(keys, index or segment)
	end
	if #keys > StatePatch.MAX_DEPTH then
		return nil
	end
	return keys
end

-- Whether `parent` is an array: arrays are addressed by index, dictionaries by string key.
local function isArray(parent: { [any]: any }): boolean
	return next(parent) == nil or parent[1] ~= nil
end

-- The real key of a segment in `node`. Dictionary keys are always strings (section 12.2), and
-- some are digits (`run.feedGuard` is keyed by user ID), so a digit segment is an array index
-- only where it can be one: in an array, or as the first entry of an empty table.
local function keyIn(node: { [any]: any }, key: Key): Key
	if type(key) == "number" and not (isArray(node) and (next(node) ~= nil or key == 1)) then
		return tostring(key)
	end
	return key
end

--- The value at `path` in `root`, or nil when any step is missing.
function StatePatch.get(root: { [any]: any }, path: string): any
	local keys = StatePatch.split(path)
	if not keys then
		return nil
	end
	local node: any = root
	for _, key in keys do
		if type(node) ~= "table" then
			return nil
		end
		node = node[keyIn(node, key)]
	end
	return node
end

--- Sets `path` in a client mirror, creating missing tables on the way (as dictionaries; arrays
--- arrive whole, see `diff`). Returns false only for a
--- malformed path or a step through a non-table.
function StatePatch.apply(root: { [any]: any }, path: string, value: any): boolean
	local keys = StatePatch.split(path)
	if not keys then
		return false
	end
	local node: any = root
	for i = 1, #keys - 1 do
		local key = keyIn(node, keys[i])
		local child = node[key]
		if child == nil then
			child = {}
			node[key] = child
		elseif type(child) ~= "table" then
			return false
		end
		node = child
	end
	node[keyIn(node, keys[#keys])] = value
	return true
end

--- Sets `path` in a saved profile, checked against `template` (SaveSchema.template()):
---   * every step but the last must already be a table in `data`;
---   * an array takes indexes 1 to #array + 1 (append), and nil only at its last index (no
---     holes); a digit segment in a dictionary is its string key;
---   * where the template has a value at the same path, the new value has its type (a nil only
---     where the template has none, so a required field cannot be deleted);
---   * the value follows the save rules (SaveSchema.check).
--- The value is stored as given; copy it first if the caller keeps a reference.
function StatePatch.set(
	data: { [any]: any },
	template: { [any]: any },
	path: string,
	value: any
): (boolean, string?)
	local keys = StatePatch.split(path)
	if not keys then
		return false, "malformed path"
	end
	local node: any, model: any = data, template
	for i = 1, #keys - 1 do
		local key = keyIn(node, keys[i])
		local child = node[key]
		if type(child) ~= "table" then
			return false, `{path}: no table at step {i}`
		end
		node = child
		model = if type(model) == "table" then model[key] else nil
	end
	local last = keyIn(node, keys[#keys])
	if isArray(node) and next(node) ~= nil or type(last) == "number" then
		if type(last) ~= "number" then
			return false, `{path}: an array takes an index`
		end
		local length = #node
		if last > length + 1 or (value == nil and last ~= length) then
			return false, `{path}: would leave a hole`
		end
	end
	local expected = if type(model) == "table" then model[last] else nil
	if expected ~= nil and type(value) ~= type(expected) then
		return false, `{path}: wants a {type(expected)}, got {type(value)}`
	end
	local ok, reason = SaveSchema.check(value, path)
	if not ok then
		return false, reason
	end
	node[last] = value
	return true, nil
end

local function same(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in a do
		if not same(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function diffInto(out: { Patch }, path: string, old: any, new: any)
	if same(old, new) then
		return
	end
	-- Descend only into two dictionaries; an array or a changed type is sent whole, so the
	-- client never sees an array with a hole between two patches.
	if type(old) == "table" and type(new) == "table" and not isArray(old) and not isArray(new) then
		for key, value in new do
			diffInto(out, `{path}.{key}`, old[key], value)
		end
		for key in old do
			if new[key] == nil then
				table.insert(out, { path = `{path}.{key}`, value = nil })
			end
		end
		return
	end
	table.insert(out, { path = path, value = new })
end

--- The patches that turn `old` into `new` at `path`: one per changed dictionary key, whole arrays
--- and whole values otherwise. Empty when nothing changed.
function StatePatch.diff(path: string, old: any, new: any): { Patch }
	local out: { Patch } = {}
	diffInto(out, path, old, new)
	return out
end

--- Whether a change at `changed` can change what an observer of `observed` sees: the same path,
--- one inside the other, or either one the root ("").
function StatePatch.touches(changed: string, observed: string): boolean
	if changed == observed or changed == "" or observed == "" then
		return true
	end
	local a, b = changed .. ".", observed .. "."
	return string.sub(b, 1, #a) == a or string.sub(a, 1, #b) == b
end

--- A deep copy, for values handed across the boundary (SaveSchema.copy).
StatePatch.copy = SaveSchema.copy

return table.freeze(StatePatch)
