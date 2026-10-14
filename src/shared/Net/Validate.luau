--!strict
-- Validate: the payload checks of docs/09, section 14.2, steps 1 to 3, as pure data and pure
-- functions so they run in Lune. A remote's spec is a list with one entry per argument:
--   count and type  exact argument count; each argument's `typeof` matches its entry
--   size            a buffer's length is one the codec accepts; a string is not too long
--   range           numbers are finite, integers whole and in range; strings in their ID table
-- Checks never throw on what a client sends: they return `(ok, reason)`.

export type Reason = "count" | "type" | "size" | "range"

export type Spec =
	{
		kind: "buffer",
		min: number,
		max: number,
		accepts: ((length: number) -> boolean)?,
		valid: ((value: buffer) -> boolean)?,
	}
	| { kind: "string", maxLength: number, ids: { [string]: boolean }? }
	| { kind: "number", min: number, max: number, integer: boolean }
	| { kind: "boolean" }
	| { kind: "either", options: { Spec } }

local Validate = {}

--- A buffer of `min` to `max` bytes; `accepts`, when given, must also say yes to its length
--- (for `Bite`: 8, or 8 + 4n with n from 1 to 8). `valid`, when given, checks the contents once
--- the size passed (a codec's range check, for `Ability`: a known op); a no is a "range" reject.
function Validate.buffer(
	min: number,
	max: number,
	accepts: ((length: number) -> boolean)?,
	valid: ((value: buffer) -> boolean)?
): Spec
	if not (min >= 0 and max >= min) then
		error(`Validate.buffer: needs 0 <= min <= max, got {min} and {max}`, 2)
	end
	return { kind = "buffer", min = min, max = max, accepts = accepts, valid = valid }
end

--- A string of at most `maxLength` bytes; when `ids` is given, it must be one of its keys.
function Validate.string(maxLength: number, ids: { [string]: boolean }?): Spec
	if not (maxLength >= 0) then
		error(`Validate.string: needs maxLength >= 0, got {maxLength}`, 2)
	end
	return { kind = "string", maxLength = maxLength, ids = ids }
end

--- A finite number from `min` to `max`, both included.
function Validate.number(min: number, max: number): Spec
	if not (max >= min) then
		error(`Validate.number: needs min <= max, got {min} and {max}`, 2)
	end
	return { kind = "number", min = min, max = max, integer = false }
end

--- A whole number from `min` to `max`, both included (a slot is `Validate.int(1, 24)`).
function Validate.int(min: number, max: number): Spec
	if not (max >= min) then
		error(`Validate.int: needs min <= max, got {min} and {max}`, 2)
	end
	return { kind = "number", min = min, max = max, integer = true }
end

--- A boolean.
function Validate.boolean(): Spec
	return { kind = "boolean" }
end

--- A value that passes any one of `options` (for `SettingsSet` values of several types).
function Validate.either(options: { Spec }): Spec
	if #options == 0 then
		error("Validate.either: needs at least one option", 2)
	end
	return { kind = "either", options = options }
end

--- Checks one argument against one spec.
function Validate.value(spec: Spec, value: unknown): (boolean, Reason?)
	local kind = typeof(value)
	if spec.kind == "buffer" then
		if kind ~= "buffer" then
			return false, "type"
		end
		local length = buffer.len(value :: buffer) -- safe: typeof said buffer
		if length < spec.min or length > spec.max then
			return false, "size"
		end
		if spec.accepts and not spec.accepts(length) then
			return false, "size"
		end
		if spec.valid and not spec.valid(value :: buffer) then -- safe: typeof said buffer
			return false, "range"
		end
		return true, nil
	elseif spec.kind == "string" then
		if kind ~= "string" then
			return false, "type"
		end
		local text = value :: string -- safe: typeof said string
		if #text > spec.maxLength then
			return false, "size"
		end
		if spec.ids and spec.ids[text] ~= true then
			return false, "range"
		end
		return true, nil
	elseif spec.kind == "number" then
		if kind ~= "number" then
			return false, "type"
		end
		local number = value :: number -- safe: typeof said number
		-- NaN fails every comparison, so `not (... < huge)` catches it with the infinities.
		if not (math.abs(number) < math.huge) then
			return false, "range"
		end
		if spec.integer and number % 1 ~= 0 then
			return false, "range"
		end
		if number < spec.min or number > spec.max then
			return false, "range"
		end
		return true, nil
	elseif spec.kind == "boolean" then
		if kind ~= "boolean" then
			return false, "type"
		end
		return true, nil
	else
		-- "either": the first option that passes wins; otherwise report the least severe
		-- failure, so a string that is merely too long says "size", not "type".
		local best: Reason = "type"
		for _, option in spec.options do
			local ok, reason = Validate.value(option, value)
			if ok then
				return true, nil
			end
			if reason ~= "type" then
				best = reason :: Reason -- safe: a failed check always gives a reason
			end
		end
		return false, best
	end
end

--- Checks a whole payload: exactly one argument per spec, each passing its spec. Returns the
--- reason of the first failure. Allocates nothing.
function Validate.args(specs: { Spec }, ...: unknown): (boolean, Reason?)
	local count = select("#", ...)
	if count ~= #specs then
		return false, "count"
	end
	for index, spec in specs do
		local ok, reason = Validate.value(spec, (select(index, ...)))
		if not ok then
			return false, reason :: Reason -- safe: Validate.value returns only Reason values
		end
	end
	return true, nil
end

--- The largest buffer any spec in `specs` allows, or nil when none takes a buffer. Net/Server
--- uses it to check a spec against the remote table.
function Validate.largestBuffer(specs: { Spec }): number?
	local largest: number? = nil
	local function visit(spec: Spec)
		if spec.kind == "buffer" then
			largest = math.max(largest or 0, spec.max)
		elseif spec.kind == "either" then
			for _, option in spec.options do
				visit(option)
			end
		end
	end
	for _, spec in specs do
		visit(spec)
	end
	return largest
end

--- The longest string any spec in `specs` allows, or nil when none takes a string.
function Validate.longestString(specs: { Spec }): number?
	local longest: number? = nil
	local function visit(spec: Spec)
		if spec.kind == "string" then
			longest = math.max(longest or 0, spec.maxLength)
		elseif spec.kind == "either" then
			for _, option in spec.options do
				visit(option)
			end
		end
	end
	for _, spec in specs do
		visit(spec)
	end
	return longest
end

return Validate
