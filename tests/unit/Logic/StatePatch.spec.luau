--!strict
-- StatePatch: the paths of the State remote (docs/09, sections 5.1 to 5.3).
local SaveSchema = require("../../../src/shared/Logic/SaveSchema")
local StatePatch = require("../../../src/shared/Logic/StatePatch")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("StatePatch", function()
	it("splits paths, with digit segments as indexes, and refuses malformed ones", function()
		expect(StatePatch.split("cove.slots")).toEqual({ "cove", "slots" })
		expect(StatePatch.split("goals.list.2.progress")).toEqual({ "goals", "list", 2, "progress" })
		expect(StatePatch.split("a.01")).toEqual({ "a", "01" })
		expect(StatePatch.split("")).toBe(nil)
		expect(StatePatch.split("a..b")).toBe(nil)
		expect(StatePatch.split("a.")).toBe(nil)
		expect(StatePatch.split(string.rep("a.", 9) .. "a")).toBe(nil)
		expect(StatePatch.split(string.rep("x", 129))).toBe(nil)
	end)

	it("reads paths, treating digit keys of dictionaries as strings", function()
		local root = { a = { list = { "x", "y" }, guard = { ["1234"] = 3 } } }
		expect(StatePatch.get(root, "a.list.2")).toBe("y")
		expect(StatePatch.get(root, "a.guard.1234")).toBe(3)
		expect(StatePatch.get(root, "a.missing.deeper")).toBe(nil)
		expect(StatePatch.get(root, "a.list.2.deeper")).toBe(nil)
	end)

	it("applies patches to a mirror, creating tables on the way", function()
		local mirror: { [any]: any } = {}
		expect(StatePatch.apply(mirror, "cove.slots", 7)).toBe(true)
		expect(StatePatch.apply(mirror, "stats", { runs = 1 })).toBe(true)
		expect(StatePatch.apply(mirror, "stats.runs", 2)).toBe(true)
		expect(StatePatch.apply(mirror, "cove.slots.x", 1)).toBe(false)
		expect(mirror).toEqual({ cove = { slots = 7 }, stats = { runs = 2 } })
		expect(StatePatch.apply(mirror, "stats.runs", nil)).toBe(true)
		expect(mirror.stats).toEqual({})
	end)

	it("sets profile values only where the template allows", function()
		local data = SaveSchema.template() :: any
		local template = SaveSchema.template() :: any
		local function set(path: string, value: any): string?
			local ok, why = StatePatch.set(data, template, path, value)
			return if ok then nil else why
		end
		expect(set("pearls", 120)).toBe(nil)
		expect(data.pearls).toBe(120)
		expect(set("pearls", "lots")).toBe("pearls: wants a number, got string")
		expect(set("pearls", nil)).toBe("pearls: wants a number, got nil")
		expect(set("pearls", 0 / 0)).toBe("pearls: not a finite number")
		expect(set("codex.prey.krill", 3)).toBe(nil) -- a new dictionary key
		expect(set("run", { sp = "minnow" })).toBe(nil) -- an optional field
		expect(set("run.feedGuard", {})).toBe(nil)
		expect(set("run.feedGuard.1234567", 1)).toBe(nil) -- a user ID key stays a string
		expect(data.run.feedGuard).toEqual({ ["1234567"] = 1 })
		expect(set("run", nil)).toBe(nil)
		expect(set("nope.deeper", 1)).toBe("nope.deeper: no table at step 1")
		expect(set("a..b", 1)).toBe("malformed path")
		expect(set("config.flag.tideEvents", true)).toBe(
			'config.flag.tideEvents: "config" is the live-config root, not a profile key'
		)
		expect(set("config", {})).toBe(
			'config: "config" is the live-config root, not a profile key'
		)
		-- Arrays: append at #+1, change in place, remove only the last; never a hole.
		local spec = { id = "a1B2c3D4", sp = "minnow", tier = 2, mass = 12.5, traits = {}, at = 1 }
		expect(set("cove.specimens.1", spec)).toBe(nil)
		expect(set("cove.specimens.3", spec)).toBe("cove.specimens.3: would leave a hole")
		expect(set("cove.specimens.2", table.clone(spec))).toBe(nil)
		expect(set("cove.specimens.1", nil)).toBe("cove.specimens.1: would leave a hole")
		expect(set("cove.specimens.2", nil)).toBe(nil)
		expect(set("cove.specimens.x", 1)).toBe("cove.specimens.x: an array takes an index")
		expect(#data.cove.specimens).toBe(1)
	end)

	it("diffs dictionaries key by key and sends arrays whole", function()
		local old = {
			pearls = 5,
			cove = { slots = 6, specimens = { 1 } },
			codex = { prey = { krill = 1 } },
		}
		local new =
			{ pearls = 5, cove = { slots = 7, specimens = { 1, 2 } }, codex = { prey = {} } }
		local patches = StatePatch.diff("save", old, new)
		table.sort(patches, function(a, b)
			return a.path < b.path
		end)
		expect(patches).toEqual({
			{ path = "save.codex.prey", value = {} },
			{ path = "save.cove.slots", value = 7 },
			{ path = "save.cove.specimens", value = { 1, 2 } },
		})
		expect(StatePatch.diff("x", { a = { b = 1 } }, { a = { b = 1 } })).toEqual({})
		expect(StatePatch.diff("x", { a = 1, b = 2 }, { a = 1 })).toEqual({
			{ path = "x.b", value = nil },
		})
		expect(StatePatch.diff("x", 1, "1")).toEqual({ { path = "x", value = "1" } })
	end)

	it("applying a diff to a copy of the old value gives the new value", function()
		local old =
			{ a = { b = 1, c = { d = true } }, e = { 1, 2 }, guard = { ["77"] = 1, ["88"] = 2 } }
		local new = { a = { b = 2, c = {} }, e = { 3 }, f = "new", guard = { ["77"] = 4 } }
		local mirror = { root = StatePatch.copy(old) }
		for _, patch in StatePatch.diff("root", old, new) do
			expect(StatePatch.apply(mirror, patch.path, patch.value)).toBe(true)
		end
		expect(mirror.root).toEqual(new)
	end)

	it("tells which observers a change touches", function()
		expect(StatePatch.touches("cove.slots", "cove.slots")).toBe(true)
		expect(StatePatch.touches("cove", "cove.slots")).toBe(true)
		expect(StatePatch.touches("cove.slots", "cove")).toBe(true)
		expect(StatePatch.touches("cove.slots", "")).toBe(true)
		expect(StatePatch.touches("cove.slotsX", "cove.slots")).toBe(false)
		expect(StatePatch.touches("codex", "cove")).toBe(false)
	end)
end)
