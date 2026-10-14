--!strict
-- Migrations: brings a loaded save up to the current schema (docs/09, section 12.3; task S4-C6,
-- module B20). `STEPS[n]` upgrades version n to n + 1; each is a pure function of the table.
-- Pure, so it runs in Lune; DataService calls `upgrade` right after the session starts.
--
--   1. `data.v == nil`: the profile is new; fill it from the template.
--   2. While `data.v < SCHEMA_VERSION`, run `STEPS[data.v]` and add 1.
--   3. Reconcile: fill every field the template has and the data lacks (the same rule as
--      ProfileStore's `Profile:Reconcile`, done here because DataService opens the store with no
--      template, so a new profile arrives empty and step 1 can tell it apart).
--   4. `data.v > SCHEMA_VERSION` (an old server met newer data after a rollback): change nothing;
--      the caller ends the session and kicks.
--
-- Changes within a release are additive. A field is never reused for a new meaning; removing or
-- reshaping one takes two releases. Every version has a fixture in tests/fixtures/profiles/.
local SaveSchema = require("./SaveSchema")

export type Outcome = "new" | "upgraded" | "current" | "newer" | "invalid"
export type Step = (data: { [string]: any }) -> ()

local Migrations = {}

Migrations.SCHEMA_VERSION = 1

-- Entry n upgrades version n to n + 1. Empty while version 1 is the only version.
Migrations.STEPS = table.freeze({}) :: { Step }

--- Fills every key `template` has and `data` lacks, with a deep copy; recurses where both are
--- tables. Never changes a value `data` already has, and never touches arrays' contents.
function Migrations.reconcile(data: { [any]: any }, template: { [any]: any })
	for key, value in template do
		local have = data[key]
		if have == nil then
			data[key] = SaveSchema.copy(value)
		elseif type(have) == "table" and type(value) == "table" and type(key) == "string" then
			Migrations.reconcile(have, value)
		end
	end
end

--- Runs steps 1 to 4 on `data` in place. `now` is Unix seconds; it stamps a new profile.
--- `steps` and `version` default to this module's; specs pass their own to test the loop.
function Migrations.upgrade(
	data: { [string]: any },
	now: number,
	steps: { Step }?,
	version: number?
): Outcome
	local useSteps = steps or Migrations.STEPS
	local target = version or Migrations.SCHEMA_VERSION
	local v = data.v
	if v == nil then
		if next(data) ~= nil then
			return "invalid" -- data with no version is not a profile this game wrote
		end
		Migrations.reconcile(data, SaveSchema.template())
		data.v = target
		data.createdAt = now
		data.lastSeenAt = now
		data.cove.accruedAt = now
		return "new"
	end
	if type(v) ~= "number" or v ~= math.floor(v) or v < 1 then
		return "invalid"
	end
	if v > target then
		return "newer"
	end
	local outcome: Outcome = "current"
	while data.v < target do
		local step = useSteps[data.v]
		if not step then
			return "invalid" -- a missing step is a programmer mistake; the caller refuses the save
		end
		step(data)
		data.v += 1
		outcome = "upgraded"
	end
	Migrations.reconcile(data, SaveSchema.template())
	return outcome
end

return table.freeze(Migrations)
