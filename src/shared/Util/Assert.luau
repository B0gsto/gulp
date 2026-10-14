--!strict
-- Assert: checks for programmer mistakes (docs/09, section 4.6). `error()` is only for those;
-- anything a player or the network can cause is refused with `(ok, reason)` instead.
--
-- The checks are behind one flag so production can run hot paths without them. Luau cannot
-- remove a call across modules, so a hot loop tests the flag once and skips its checks:
--     local checked = Assert.isEnabled()
--     for ... do if checked then Assert.finite(x, "x") end ... end
-- Elsewhere just call the check: a disabled check costs one call and one branch. Pass a
-- constant message on hot paths (section 4.7: no string building). Plain Luau, runs in Lune.

local Assert = {}

local enabled = true

--- Turns every check in this module on or off. On by default.
function Assert.setEnabled(on: boolean)
	enabled = on
end

--- Whether the checks run.
function Assert.isEnabled(): boolean
	return enabled
end

--- Throws `message`. Not behind the flag: use it for a branch that must never be reached.
function Assert.fail(message: string): never
	error(message, 2)
end

--- Throws `message` unless `condition` is true.
function Assert.that(condition: boolean, message: string)
	if enabled and not condition then
		error(message, 2)
	end
end

--- Throws unless `value` is a number that is neither NaN nor infinite. `name` goes in the message.
function Assert.finite(value: number, name: string)
	if enabled and not (type(value) == "number" and math.abs(value) < math.huge) then
		error(`{name} must be a finite number, got {value}`, 2)
	end
end

--- Throws unless `value` is a whole number from `min` to `max`, both included.
function Assert.intInRange(value: number, min: number, max: number, name: string)
	if
		enabled
		and not (type(value) == "number" and value % 1 == 0 and value >= min and value <= max)
	then
		error(`{name} must be a whole number from {min} to {max}, got {value}`, 2)
	end
end

return Assert
