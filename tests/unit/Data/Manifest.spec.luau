--!strict
local fs = require("@lune/fs")

local Defaults = require("../../../src/shared/Config/Defaults")
local Manifest = require("../../../src/shared/Data/Manifest")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local HEADER = "name,tag,status,asset_id,placeholder,note\n"

local function names(problems: { Manifest.Problem }): { string }
	local found = {}
	for _, problem in problems do
		table.insert(found, `{problem.line}:{problem.name}:{problem.reason}`)
	end
	return found
end

describe("Manifest.parse", function()
	it("reads every column into a lookup by name", function()
		local manifest = Manifest.parse(
			HEADER
				.. "M_Prey_Krill,MVP,done,123,no,\r\n"
				.. 'SFX_Gulp,MVP,blocked,,yes,"waits for the audio batch script, S1-A1"\n'
		)
		expect(#manifest.entries).toBe(2)
		local krill = Manifest.get(manifest, "M_Prey_Krill")
		expect(krill and krill.id).toBe(123)
		expect(krill and krill.placeholder).toBe(false)
		expect(krill and krill.status).toBe("done")
		local gulp = Manifest.get(manifest, "SFX_Gulp")
		expect(gulp and gulp.id).toBe(nil)
		expect(gulp and gulp.placeholder).toBe(true)
		expect(gulp and gulp.note).toBe("waits for the audio batch script, S1-A1")
		expect(gulp and gulp.line).toBe(3)
		expect(Manifest.get(manifest, "M_Prey_Tuna")).toBe(nil)
	end)

	it("round-trips through encode", function()
		local text = HEADER .. 'A_Fish_Bite,MVP,in review,77,no,"say ""hi"", twice"\n'
		local manifest = Manifest.parse(text)
		expect(Manifest.encode(manifest.entries)).toBe(text)
	end)

	it("rejects bad rows with their line", function()
		local function parse(row: string): () -> ()
			return function()
				Manifest.parse(HEADER .. row .. "\n")
			end
		end
		expect(parse("M_Prey_Krill,MVP,finished,,yes,")).toThrow(
			"line 2: M_Prey_Krill: unknown status"
		)
		expect(parse("M_Prey_Krill,Launch,done,1,no,")).toThrow("unknown tag")
		expect(parse("M_Prey_Krill,MVP,done,abc,no,")).toThrow("not a positive whole number")
		expect(parse("M_Prey_Krill,MVP,done,1,maybe,")).toThrow("placeholder must be yes or no")
		expect(parse("M_Prey_Krill,MVP,done,1,yes,")).toThrow("placeholder removed")
		expect(parse("FX_BiteChomp,MVP,done,5,no,")).toThrow("has no Roblox asset ID")
		expect(parse("M_Prey-Krill,MVP,done,1,no,")).toThrow("is not an asset name")
		expect(parse("SCN_Icon_A_BehindYou,MVP,done,1,no,")).toThrow("is not an asset name")
		expect(parse("M_Prey_Krill,MVP,done,1,no")).toThrow("expected 6 fields")
		expect(parse("M_Prey_Krill,MVP,done,1,no,\nM_Prey_Krill,MVP,done,1,no,")).toThrow(
			"line 3: M_Prey_Krill is already on line 2"
		)
		expect(function()
			Manifest.parse("name,tag,status\n")
		end).toThrow("header must be")
	end)
end)

describe("Manifest.releaseProblems", function()
	it("passes a manifest where every row is final", function()
		local manifest = Manifest.parse(fs.readFile("tests/fixtures/manifest/all_final.csv"))
		expect(names(Manifest.releaseProblems(manifest))).toEqual({})
	end)

	it("lists placeholders and final rows without an asset ID", function()
		local manifest = Manifest.parse(fs.readFile("tests/fixtures/manifest/some_placeholder.csv"))
		expect(names(Manifest.releaseProblems(manifest))).toEqual({
			"3:T_Minnow_Juv_Alb:placeholder",
			"4:A_Fish_Bite:placeholder",
			"5:SFX_Gulp:final but no asset ID",
		})
	end)

	it("reports every placeholder of the shipped manifest", function()
		local manifest = Manifest.load()
		local reported: { [string]: boolean } = {}
		for _, problem in Manifest.releaseProblems(manifest) do
			reported[problem.name] = true
		end
		for _, entry in manifest.entries do
			if entry.placeholder then
				expect(reported[entry.name]).toBe(true)
			end
		end
	end)
end)

describe("Manifest.load", function()
	it("ships exactly the rows of assets/manifest.csv", function()
		local fromCsv = Manifest.parse(fs.readFile("assets/manifest.csv"))
		expect(Manifest.encode(Manifest.load().entries)).toBe(Manifest.encode(fromCsv.entries))
	end)

	it("feeds every environment's asset IDs in Config/Defaults", function()
		local ids = Manifest.assetIds(Manifest.load())
		for _, environment in Defaults.environments do
			expect(environment.assetIds).toEqual(ids)
		end
		expect(Defaults.unknown.assetIds).toEqual(ids)
	end)

	it("knows which kinds carry one asset ID", function()
		expect(Manifest.needsAssetId("M_Prey_Krill")).toBe(true)
		expect(Manifest.needsAssetId("MUS_Reef")).toBe(true)
		expect(Manifest.needsAssetId("FX_BiteChomp")).toBe(false)
		expect(Manifest.needsAssetId("LGT_Reef")).toBe(false)
		expect(Manifest.needsAssetId("SKY_Day")).toBe(false)
	end)
end)
