--!strict
-- Migrations and SaveSchema (docs/09, sections 12.2, 12.3 and 16.1: "Migrations (every
-- fixture)"). Every file in tests/fixtures/profiles/ loads, migrates to the current version, keeps
-- its values, passes the save rules and survives a JSON save and load unchanged.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Migrations = require("../../../src/shared/Logic/Migrations")
local SaveSchema = require("../../../src/shared/Logic/SaveSchema")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local FIXTURES = "tests/fixtures/profiles"
local NOW = 1792100000

local function load(name: string): { [string]: any }
	return serde.decode("json", fs.readFile(`{FIXTURES}/{name}`))
end

-- Every key path of a table whose leaves are not tables, as "a.b.c".
local function leaves(t: { [any]: any }, prefix: string, out: { [string]: any })
	for key, value in t do
		local path = if prefix == "" then tostring(key) else `{prefix}.{key}`
		if type(value) == "table" then
			leaves(value, path, out)
		else
			out[path] = value
		end
	end
end

describe("SaveSchema", function()
	it("builds a fresh version 1 template that follows the save rules", function()
		local a, b = SaveSchema.template(), SaveSchema.template()
		expect(a.v).toBe(Migrations.SCHEMA_VERSION)
		expect(a ~= b and a.cove ~= b.cove).toBe(true)
		expect(a).toEqual(b)
		expect(SaveSchema.check(a)).toBe(true)
		expect(a.species.selected).toBe("minnow")
		expect(a.species.owned.minnow).toBe(true)
		expect(a.cove.slots).toBe(6)
		expect(a.settings.input.touch.scheme).toBe("drag")
		expect(a.settings.input.keys.scheme).toBe("keys")
		expect(a.settings.input.pad.scheme).toBe("pad")
		expect(a.run).toBe(nil)
		-- 05 §3: 0 Pearls and 0 of every token, no starting grant.
		expect(a.pearls).toBe(0)
		expect(a.tokens).toEqual({ revive = 0, trait_lock = 0, call_tide = 0, goal_reroll = 0 })
		-- 09 §5.3: profile keys are the State roots next to `config`, so none may be named so.
		expect((a :: any).config).toBe(nil)
	end)

	it("knows the scheme IDs of each input mode (15 §2.2)", function()
		expect(SaveSchema.SCHEMES.touch).toEqual({ drag = true, two_thumb = true })
		expect(SaveSchema.SCHEMES.keys).toEqual({ keys = true, keys_locked = true })
		expect(SaveSchema.SCHEMES.pad).toEqual({ pad = true })
		local input = SaveSchema.template().settings.input
		expect(SaveSchema.checkSchemes(input)).toBe(true)
		input.touch.scheme = "two_thumb"
		expect(SaveSchema.checkSchemes(input)).toBe(true)
		input.keys.scheme = "keys_locked"
		expect(SaveSchema.checkSchemes(input)).toBe(true)
		input.keys.scheme = "drag"
		local ok, why = SaveSchema.checkSchemes(input)
		expect(ok).toBe(false)
		expect(why).toBe("settings.input.keys.scheme: drag is not a keys scheme")
		input.keys.scheme = "keys"
		input.pad.scheme = "gamepad"
		expect(SaveSchema.checkSchemes(input)).toBe(false)
		expect(SaveSchema.checkSchemes(nil)).toBe(false)
	end)

	it("refuses NaN, infinity, holes, mixed tables, non-string keys and engine values", function()
		local function reason(value: unknown): string?
			local ok, why = SaveSchema.check({ x = value })
			return if ok then nil else why
		end
		expect(reason(0 / 0)).toBe("data.x: not a finite number")
		expect(reason(math.huge)).toBe("data.x: not a finite number")
		expect(reason({ 1, nil, 3 }) ~= nil).toBe(true)
		expect(reason({ 1, a = 2 }) ~= nil).toBe(true)
		expect(reason({ [true] = 1 } :: any) ~= nil).toBe(true)
		expect(reason(function() end)).toBe("data.x: function cannot be saved")
		expect(reason(buffer.create(1))).toBe("data.x: buffer cannot be saved")
		expect(reason({ 1, 2, { a = "b" } })).toBe(nil)
		local shared = {}
		expect(reason({ shared, shared })).toBe("data.x.2: a table appears twice")
	end)

	it("measures the JSON size exactly for plain data", function()
		for _, value in
			{ SaveSchema.template(), load("v1.json"), { 1, 2.5, -3 }, { a = 'q"b\\' } } :: { any }
		do
			expect(SaveSchema.encodedSize(value)).toBe(#serde.encode("json", value))
		end
	end)

	it("keeps a full profile far below the 200 kB refusal", function()
		local data = load("v1.json")
		for i = #data.cove.specimens + 1, 40 do
			data.cove.specimens[i] = table.clone(data.cove.specimens[2])
		end
		expect(SaveSchema.encodedSize(data) < 20000).toBe(true) -- section 12.2: under 20 kB
		expect(SaveSchema.MAX_BYTES).toBe(200000)
	end)

	it("keys a profile by user ID", function()
		expect(SaveSchema.keyFor(42)).toBe("u_42")
		expect(SaveSchema.STORE_NAME).toBe("Player_v1")
	end)
end)

describe("Migrations", function()
	it("fills a new (empty) profile from the template and stamps the times", function()
		local data: { [string]: any } = {}
		expect(Migrations.upgrade(data, NOW)).toBe("new")
		local want = SaveSchema.template() :: any
		want.createdAt, want.lastSeenAt, want.cove.accruedAt = NOW, NOW, NOW
		expect(data).toEqual(want)
	end)

	it("migrates every fixture to the current version and saves it unchanged", function()
		local names = fs.readDir(FIXTURES)
		table.sort(names)
		local count = 0
		for _, name in names do
			local version = tonumber(string.match(name, "^v(%d+)%.json$"))
			if version then
				count += 1
				local data = load(name)
				local before: { [string]: any } = {}
				leaves(data, "", before)
				expect(data.v).toBe(version)
				local outcome = Migrations.upgrade(data, NOW)
				expect(outcome).toBe(
					if version == Migrations.SCHEMA_VERSION then "current" else "upgraded"
				)
				expect(data.v).toBe(Migrations.SCHEMA_VERSION)
				expect(SaveSchema.check(data)).toBe(true)
				expect(SaveSchema.checkSchemes(data.settings.input)).toBe(true)
				-- Every template field is present, and no saved value of the current version changed.
				local have: { [string]: any } = {}
				leaves(data, "", have)
				local template: { [string]: any } = {}
				leaves(SaveSchema.template(), "", template)
				for path in template do
					expect(have[path] ~= nil or string.find(path, "%.%d+$") ~= nil).toBe(true)
				end
				if version == Migrations.SCHEMA_VERSION then
					expect(have).toEqual(before)
				end
				-- Save and load: a JSON round trip gives the same table back.
				expect(serde.decode("json", serde.encode("json", data))).toEqual(data)
			end
		end
		expect(count >= Migrations.SCHEMA_VERSION).toBe(true) -- one fixture per version
	end)

	it("fills fields a saved profile lacks without touching the ones it has", function()
		local data = load("v1.json")
		data.streak = nil
		data.settings.hideEmotes = nil
		data.settings.music = 2
		expect(Migrations.upgrade(data, NOW)).toBe("current")
		expect(data.streak).toEqual({ day = 0, count = 0 })
		expect(data.settings.hideEmotes).toBe(false)
		expect(data.settings.music).toBe(2)
		expect(data.run.onExpiry).toBe("scraps")
	end)

	it("runs each step in order up to the target version", function()
		local seen: { number } = {}
		local steps = {
			function(d: { [string]: any })
				table.insert(seen, d.v)
				d.renamed = d.old
				d.old = nil
			end,
			function(d: { [string]: any })
				table.insert(seen, d.v)
			end,
		}
		local data: { [string]: any } = { v = 1, old = "x" }
		expect(Migrations.upgrade(data, NOW, steps, 3)).toBe("upgraded")
		expect(seen).toEqual({ 1, 2 })
		expect(data.v).toBe(3)
		expect(data.renamed).toBe("x")
		expect(data.pearls).toBe(0) -- reconciled after the steps
	end)

	it("changes nothing in newer data, and refuses data it cannot read", function()
		local newer: { [string]: any } = { v = Migrations.SCHEMA_VERSION + 1, pearls = 5 }
		expect(Migrations.upgrade(newer, NOW)).toBe("newer")
		expect(newer).toEqual({ v = Migrations.SCHEMA_VERSION + 1, pearls = 5 })
		expect(Migrations.upgrade({ pearls = 5 }, NOW)).toBe("invalid")
		expect(Migrations.upgrade({ v = "1" }, NOW)).toBe("invalid")
		expect(Migrations.upgrade({ v = 0 }, NOW)).toBe("invalid")
		expect(Migrations.upgrade({ v = 1 }, NOW, {}, 2)).toBe("invalid") -- a missing step
	end)

	it("reconciles into nested tables and copies what it fills", function()
		local template = { a = { b = 1, c = { 1, 2 } }, d = "x" }
		local data: { [string]: any } = { a = { b = 5 } }
		Migrations.reconcile(data, template)
		expect(data).toEqual({ a = { b = 5, c = { 1, 2 } }, d = "x" })
		expect(data.a.c ~= template.a.c).toBe(true)
	end)
end)
