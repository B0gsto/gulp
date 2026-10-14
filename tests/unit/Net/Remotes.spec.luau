--!strict
local Remotes = require("../../../src/shared/Net/Remotes")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- The table of docs/09, section 5.3, copied by hand: name, kind, direction, rate, bucket.
-- C = client to server, S = server to client. "1 per session" is rate 0, bucket 1.
local EXPECTED: { { name: string, kind: string, dir: string, rate: number?, bucket: number? } } = {
	{ name = "ClientReady", kind = "Reliable", dir = "C", rate = 0, bucket = 1 },
	{ name = "Bite", kind = "Reliable", dir = "C", rate = 12, bucket = 20 },
	{ name = "Ability", kind = "Reliable", dir = "C", rate = 4, bucket = 6 },
	{ name = "RunAction", kind = "Reliable", dir = "C", rate = 5, bucket = 8 },
	{ name = "CoveAction", kind = "Reliable", dir = "C", rate = 5, bucket = 8 },
	{ name = "ShopAction", kind = "Reliable", dir = "C", rate = 3, bucket = 5 },
	{ name = "GoalAction", kind = "Reliable", dir = "C", rate = 2, bucket = 4 },
	{ name = "SettingsSet", kind = "Reliable", dir = "C", rate = 2, bucket = 4 },
	{ name = "TutorialStep", kind = "Reliable", dir = "C", rate = 2, bucket = 4 },
	{ name = "EmoteAction", kind = "Reliable", dir = "C", rate = 1 / 3, bucket = 1 },
	{ name = "Telemetry", kind = "Unreliable", dir = "C", rate = 1 / 20, bucket = 2 },
	{ name = "State", kind = "Reliable", dir = "S" },
	{ name = "WorldInfo", kind = "Reliable", dir = "S" },
	{ name = "BiteResult", kind = "Reliable", dir = "S" },
	{ name = "PreyEvent", kind = "Reliable", dir = "S" },
	{ name = "CreatureEvent", kind = "Reliable", dir = "S" },
	{ name = "PredatorEvent", kind = "Reliable", dir = "S" },
	{ name = "TideEvent", kind = "Reliable", dir = "S" },
	{ name = "CoveView", kind = "Reliable", dir = "S" },
	{ name = "PreyState", kind = "Unreliable", dir = "S" },
	{ name = "PredatorState", kind = "Unreliable", dir = "S" },
}

describe("Net/Remotes", function()
	it(
		"lists exactly the remotes of 5.3, in order, with their kind, direction and limits",
		function()
			expect(#Remotes.list).toBe(#EXPECTED)
			for index, row in EXPECTED do
				local def = Remotes.list[index]
				expect(def.name).toBe(row.name)
				expect(def.kind).toBe(row.kind)
				expect(def.direction).toBe(
					if row.dir == "C" then "ClientToServer" else "ServerToClient"
				)
				expect(def.rate).toBe(row.rate)
				expect(def.bucket).toBe(row.bucket)
			end
		end
	)

	it("has the payload sizes 5.3 states", function()
		local function size(name: string): { number? }
			local def = Remotes.get(name)
			return { def.minBytes, def.maxBytes }
		end
		expect(size("Bite")).toEqual({ 8, 40 })
		expect(size("Ability")).toEqual({ 6, 6 })
		expect(size("Telemetry")).toEqual({ 8, 8 })
		expect(size("BiteResult")).toEqual({ 9, 9 })
		expect(size("PredatorEvent")).toEqual({ 14, 14 })
		expect(size("PreyState")).toEqual({ nil, 900 })
		expect(size("PredatorState")).toEqual({ nil, 400 })
		expect(Remotes.get("ShopAction").maxString).toBe(32)
	end)

	it("names are unique PascalCase nouns and byName finds each one", function()
		local seen: { [string]: boolean } = {}
		for _, def in Remotes.list do
			expect(seen[def.name]).toBe(nil)
			seen[def.name] = true
			expect(string.match(def.name, "^%u%a+$") ~= nil).toBe(true)
			expect(Remotes.byName[def.name]).toBe(def)
		end
	end)

	it(
		"every client-to-server remote has a rate of 0 or more and a bucket of at least 1",
		function()
			for _, def in Remotes.list do
				if def.direction == "ClientToServer" then
					expect((def.rate or -1) >= 0).toBe(true)
					expect((def.bucket or 0) >= 1).toBe(true)
				else
					expect(def.rate).toBe(nil)
					expect(def.bucket).toBe(nil)
				end
			end
		end
	)

	it(
		"encodings follow 09 §5.3: eight buffers, ClientReady empty, every other remote plain",
		function()
			local buffers = {
				Bite = true,
				Ability = true,
				Telemetry = true,
				BiteResult = true,
				PreyEvent = true,
				PredatorEvent = true,
				PreyState = true,
				PredatorState = true,
			}
			for _, def in Remotes.list do
				local expected = "scalars"
				if def.name == "ClientReady" then
					expected = "none"
				elseif buffers[def.name] then
					expected = "buffer"
				end
				expect(def.encoding).toBe(expected)
			end
			expect(Remotes.byName.SettingsSet.maxString).toBe(32)
			expect(Remotes.byName.ShopAction.maxString).toBe(32)
		end
	)

	it("size limits are consistent and unreliable payloads fit in one 900-byte packet", function()
		for _, def in Remotes.list do
			if def.minBytes and def.maxBytes then
				expect(def.minBytes <= def.maxBytes).toBe(true)
			end
			if def.minBytes or def.maxBytes then
				expect(def.encoding).toBe("buffer")
			end
			if def.kind == "Unreliable" then
				expect(def.maxBytes ~= nil and (def.maxBytes :: number) <= 900).toBe(true)
			end
		end
	end)

	it("only EmoteAction is of a later scope", function()
		for _, def in Remotes.list do
			expect(def.scope).toBe(if def.name == "EmoteAction" then "L" else "MVP")
		end
	end)

	it("get throws on an unknown remote", function()
		expect(function()
			Remotes.get("Nope")
		end).toThrow("unknown remote")
	end)

	it("NET_VERSION is a whole number of at least 1", function()
		expect(Remotes.NET_VERSION >= 1 and Remotes.NET_VERSION % 1 == 0).toBe(true)
		expect(Remotes.FOLDER).toBe("Net")
	end)
end)
