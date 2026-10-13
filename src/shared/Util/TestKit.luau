--!strict
-- TestKit: describe, it and expect in plain Luau (docs/09, section 16.1). It runs unchanged in
-- Lune (tools/test/runner.luau) and in Roblox (server/Tests/RunAll.luau).
--
-- A spec file calls `describe` and `it` at the top level, which only registers cases. The front
-- end then calls `TestKit.run()`, which runs and clears every registered case.

export type Expectation = {
	toBe: (expected: unknown) -> (),
	toEqual: (expected: unknown) -> (),
	toBeCloseTo: (expected: number, tolerance: number?) -> (),
	toThrow: (messagePart: string?) -> (),
}
export type Failure = { name: string, message: string }
export type Summary = { passed: number, failed: number, failures: { Failure } }

type Case = { name: string, body: () -> () }

local DEFAULT_TOLERANCE = 1e-6

local TestKit = {}

local scope: { string } = {}
local cases: { Case } = {}

local function show(value: unknown): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

-- Returns nil when the two values are deeply equal, else where and how they differ.
local function difference(actual: unknown, expected: unknown, path: string): string?
	if actual == expected then
		return nil
	end
	if type(actual) == "buffer" and type(expected) == "buffer" then
		if buffer.tostring(actual) == buffer.tostring(expected) then
			return nil
		end
		return `{path}: buffers differ`
	end
	if type(actual) ~= "table" or type(expected) ~= "table" then
		return `{path}: expected {show(expected)}, got {show(actual)}`
	end
	-- Safe casts: both values were just checked to be tables.
	local actualTable = actual :: { [unknown]: unknown }
	local expectedTable = expected :: { [unknown]: unknown }
	for key, expectedValue in expectedTable do
		local found = difference(actualTable[key], expectedValue, `{path}[{show(key)}]`)
		if found then
			return found
		end
	end
	for key, actualValue in actualTable do
		if expectedTable[key] == nil then
			return `{path}[{show(key)}]: expected nil, got {show(actualValue)}`
		end
	end
	return nil
end

-- Runs `body`. Returns nil when it finishes, else what it raised as text.
local function failureOf(body: () -> (), withTraceback: boolean): string?
	local raised: string? = nil
	xpcall(body, function(problem: unknown)
		local text = tostring(problem)
		raised = if withTraceback then debug.traceback(text, 2) else text
	end)
	return raised
end

--- Groups the cases registered inside `body` under `name`. Groups nest.
function TestKit.describe(name: string, body: () -> ())
	table.insert(scope, name)
	local problem = failureOf(body, true)
	table.remove(scope)
	if problem then
		-- A group that fails while registering becomes one failing case, so it is reported.
		TestKit.it(`{name} (registering)`, function()
			error(problem, 0)
		end)
	end
end

--- Registers one case. It passes unless `body` throws.
function TestKit.it(name: string, body: () -> ())
	local parts = table.clone(scope)
	table.insert(parts, name)
	table.insert(cases, { name = table.concat(parts, " > "), body = body })
end

--- Starts an assertion about `actual`. A failed matcher throws, which fails the case.
function TestKit.expect(actual: unknown): Expectation
	return {
		toBe = function(expected: unknown)
			if actual ~= expected then
				error(`expected {show(expected)}, got {show(actual)}`, 0)
			end
		end,
		toEqual = function(expected: unknown)
			local found = difference(actual, expected, "value")
			if found then
				error(found, 0)
			end
		end,
		toBeCloseTo = function(expected: number, tolerance: number?)
			local allowed = tolerance or DEFAULT_TOLERANCE
			if type(actual) ~= "number" or not (math.abs(actual - expected) <= allowed) then
				error(`expected {show(expected)} within {allowed}, got {show(actual)}`, 0)
			end
		end,
		toThrow = function(messagePart: string?)
			if type(actual) ~= "function" then
				error(`toThrow needs a function, got {show(actual)}`, 0)
			end
			-- Safe cast: checked to be a function on the line above.
			local problem = failureOf(actual :: () -> (), false)
			if not problem then
				error("expected the function to throw, it returned", 0)
			end
			if messagePart and not string.find(problem, messagePart, 1, true) then
				error(`expected an error containing {show(messagePart)}, got {show(problem)}`, 0)
			end
		end,
	}
end

--- Runs every registered case, clears the registry and returns the counts and failures.
function TestKit.run(): Summary
	local pending = cases
	cases = {}
	scope = {}
	local summary: Summary = { passed = 0, failed = 0, failures = {} }
	for _, case in pending do
		local problem = failureOf(case.body, true)
		if problem then
			summary.failed += 1
			table.insert(summary.failures, { name = case.name, message = problem })
		else
			summary.passed += 1
		end
	end
	return summary
end

--- One block of text: a first line starting with PASS or FAIL, then one entry per failure.
function TestKit.report(summary: Summary): string
	local verdict = if summary.failed == 0 then "PASS" else "FAIL"
	local lines = { `{verdict}: {summary.passed} passed, {summary.failed} failed` }
	for _, failure in summary.failures do
		table.insert(lines, `  {failure.name}`)
		table.insert(lines, `    {(string.gsub(failure.message, "\n", "\n    "))}`)
	end
	return table.concat(lines, "\n")
end

return TestKit
