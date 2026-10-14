--!strict
local fs = require("@lune/fs")

local AssetList = require("../../../tools/lib/asset_list")
local Manifest = require("../../../src/shared/Data/Manifest")
local ManifestFiles = require("../../../tools/lib/manifest_files")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function table07(section: string, rows: { string }): string
	local lines = {
		`### {section} Some heading`,
		"",
		"| Asset | Tag | Description | Size / budget (tune) | Hours (tune) | Status |",
		"|---|---|---|---|---|---|",
	}
	for _, row in rows do
		table.insert(lines, row)
	end
	table.insert(lines, "")
	return table.concat(lines, "\n")
end

local function sliceNames(markdown: string): { string }
	local found = {}
	for _, item in AssetList.slice(AssetList.rows(markdown)).names do
		table.insert(found, item.name)
	end
	return found
end

describe("AssetList.expand", function()
	it("expands suffix lists and numbered ranges", function()
		expect(AssetList.expand("M_Hazard_Jelly_Open, _Squeezed")).toEqual({
			"M_Hazard_Jelly_Open",
			"M_Hazard_Jelly_Squeezed",
		})
		expect(AssetList.expand("T_Minnow_PatMint_Juv_Alb, _Adult_Alb")).toEqual({
			"T_Minnow_PatMint_Juv_Alb",
			"T_Minnow_PatMint_Adult_Alb",
		})
		expect(AssetList.expand("M_Env_SunPool, T_SunPool_Mask")).toEqual({
			"M_Env_SunPool",
			"T_SunPool_Mask",
		})
		expect(AssetList.expand("T_Surface_Under_01–03_Alb")).toEqual({
			"T_Surface_Under_01_Alb",
			"T_Surface_Under_02_Alb",
			"T_Surface_Under_03_Alb",
		})
	end)

	it("names every shell with its distance versions (07 §1.2 suffix order)", function()
		local names = AssetList.expand("M_Pred_Barracuda_LOD1, _LOD2, _Shell, _ShellThick")
		expect(#names).toBe(8)
		expect(table.find(names, "M_Pred_Barracuda_LOD2_ShellThick") ~= nil).toBe(true)
	end)
end)

describe("AssetList.slice", function()
	it("keeps [MVP] files and drops tasks, sources, rigs and later tags", function()
		local markdown = table07("2.2", {
			"| `M_Species_Minnow_Juv` | [MVP] | Body | 1,500 tris | 4 | not started |",
			"| `M_Species_Base_Fish` | [MVP] | Source only, not uploaded. | — | 3 | not started |",
			"| `RIG_Fish` | [MVP] | Skeleton | 18 bones | 3 | not started |",
			"| (fit) Minnow on RIG_Fish | [MVP] | Fit | — | 2.5 | not started |",
			"| `T_Minnow_PatMint_Juv_Alb, _Adult_Alb` | [L] | Pattern | 256² | 2 | not started |",
		})
		expect(sliceNames(markdown)).toEqual({ "M_Species_Minnow_Juv" })
	end)

	it("drops content the slice defers (13 §3.2)", function()
		local markdown = table07("9.5", {
			"| `FX_GlowAura` | [MVP] | Glow | 20 | 1 | not started |",
			"| `FX_InkCloud` | [MVP] | Ink | 40 | 1 | not started |",
			"| `FX_SlipHole` | [MVP] | Eel | 20 | 1 | not started |",
			"| `SFX_OldScarNear` | [MVP] | Old Scar | 1 s | 1 | not started |",
		}) .. table07("6.3", {
			"| `M_Env_Reef_LM_Hoop` | [MVP] | Landmark | 2,000 tris | 3 | not started |",
			"| `M_Env_Reef_LM_Snooze` | [MVP] | Landmark | 2,000 tris | 3 | not started |",
		}) .. table07("6.5", {
			"| `M_Env_DropOff_Cliff_01–02` | [MVP] | Cliff | 6,000 tris | 3 | not started |",
		})
		expect(sliceNames(markdown)).toEqual({ "FX_GlowAura", "M_Env_Reef_LM_Hoop" })
	end)

	it("keeps two thirds of the floor, rock, coral and kelp variants", function()
		local markdown = table07("6.3", {
			"| `M_Env_Reef_Floor_01–06` | [MVP] | Floor | 1,000 tris | 3 | not started |",
			"| `M_Env_Reef_Sponge_01–03` | [MVP] | Sponge | 300 tris | 1 | not started |",
		})
		expect(sliceNames(markdown)).toEqual({
			"M_Env_Reef_Floor_01",
			"M_Env_Reef_Floor_02",
			"M_Env_Reef_Floor_03",
			"M_Env_Reef_Floor_04",
			"M_Env_Reef_Sponge_01",
			"M_Env_Reef_Sponge_02",
			"M_Env_Reef_Sponge_03",
		})
	end)

	it("refuses a grouped row it cannot name", function()
		local markdown = table07("4.1", {
			"| `M_Prey_*_LOD1` | [MVP] | Something new | half | 1 | not started |",
		})
		expect(function()
			AssetList.slice(AssetList.rows(markdown))
		end).toThrow("add it to EXPAND")
	end)
end)

describe("assets/manifest.csv", function()
	it("lists exactly the slice rows of docs/07, in order", function()
		local result = AssetList.slice(AssetList.rows(fs.readFile(ManifestFiles.ASSET_LIST)))
		local fromDocs = {}
		for _, item in result.names do
			table.insert(fromDocs, item.name)
		end
		local inCsv = {}
		for _, entry in Manifest.parse(fs.readFile(ManifestFiles.CSV)).entries do
			table.insert(inCsv, entry.name)
		end
		expect(inCsv).toEqual(fromDocs)
	end)

	it("matches its run-time copy (run `lune run tools/gen/manifest` after editing)", function()
		local csv = fs.readFile(ManifestFiles.CSV)
		expect(fs.readFile(ManifestFiles.MODULE) == ManifestFiles.moduleSource(csv)).toBe(true)
	end)
end)
