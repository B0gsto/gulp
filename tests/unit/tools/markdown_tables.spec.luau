--!strict
local MarkdownTables = require("../../../tools/lib/markdown_tables")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local FIXTURE = table.concat({
	"# Prose before the table is ignored",
	"",
	"<!-- data:Fish -->",
	"Soft-launch slice (chapter 13, section 3.2): `krill`, `tuna`.",
	"",
	"| ID | Tag | Mass |",
	"|---|---|---|",
	"| `plankton` | [MVP] | 0.2 |",
	"| `krill` | [MVP] | 1,200 |",
	"| `tuna` | [L] | −60 |",
	"| | **Total** | 1,260.2 |",
	"",
	"<!-- /data -->",
	"",
	"<!-- data:Ranks -->",
	"Soft-launch slice (chapter 13, section 3.2): every row.",
	"",
	"| Rarity | Bonus |",
	"|---|---|",
	"| Common | +10% |",
	"<!-- /data -->",
}, "\n")

local function block(slice: string, rows: { string }): string
	local lines = { "<!-- data:T -->", slice, "", "| ID | Value |", "|---|---|" }
	for _, row in rows do
		table.insert(lines, row)
	end
	table.insert(lines, "<!-- /data -->")
	return table.concat(lines, "\n")
end

describe("MarkdownTables.parse", function()
	local tables = MarkdownTables.parse(FIXTURE)

	it("reads every marked table by name", function()
		expect(tables.Fish.header).toEqual({ "ID", "Tag", "Mass" })
		expect(#tables.Fish.rows).toBe(3)
		expect(#tables.Ranks.rows).toBe(1)
	end)

	it("keys rows by their plain first cell and numbers them from 1 in canon order", function()
		local keys, positions = {}, {}
		for _, row in tables.Fish.rows do
			table.insert(keys, row.key)
			table.insert(positions, row.position)
		end
		expect(keys).toEqual({ "plankton", "krill", "tuna" })
		expect(positions).toEqual({ 1, 2, 3 })
		expect(tables.Fish.rows[3].cells.Tag).toBe("[L]")
	end)

	it("marks the slice rows, or every row", function()
		local inSlice = {}
		for _, row in tables.Fish.rows do
			table.insert(inSlice, row.inSlice)
		end
		expect(inSlice).toEqual({ false, true, true })
		expect(tables.Ranks.rows[1].inSlice).toBe(true)
		local none = MarkdownTables.parse(
			block("Soft-launch slice (x): no rows (not shipped).", { "| `a` | 1 |" })
		)
		expect(none.T.rows[1].inSlice).toBe(false)
	end)

	it("rejects broken markup", function()
		expect(function()
			MarkdownTables.parse("<!-- data:T -->\n| A |\n|---|\n| 1 |")
		end).toThrow("never closed")
		expect(function()
			MarkdownTables.parse(block("", { "| `a` | 1 |" }))
		end).toThrow('no "Soft-launch slice" line')
		expect(function()
			MarkdownTables.parse(block("Soft-launch slice (x): `b`.", { "| `a` | 1 |" }))
		end).toThrow("not a row")
		expect(function()
			MarkdownTables.parse(block("Soft-launch slice (x): every row.", { "| `a` | 1 | 2 |" }))
		end).toThrow("has 3 cells")
		expect(function()
			MarkdownTables.parse(
				block("Soft-launch slice (x): every row.", {})
					.. "\n"
					.. block("Soft-launch slice (x): every row.", {})
			)
		end).toThrow("marked twice")
	end)
end)

describe("MarkdownTables.number", function()
	it("reads commas, a Unicode minus and percent signs", function()
		expect(MarkdownTables.number("1,200")).toBe(1200)
		expect(MarkdownTables.number("−60")).toBe(-60)
		expect(MarkdownTables.number("+10%")).toBe(10)
		expect(MarkdownTables.number("0.455")).toBe(0.455)
		expect(MarkdownTables.number("`3`")).toBe(3)
	end)

	it("gives nil for text that is not one number", function()
		expect(MarkdownTables.number("Free")).toBe(nil)
		expect(MarkdownTables.number("2.0 s (Dart)")).toBe(nil)
		expect(MarkdownTables.number("")).toBe(nil)
	end)
end)
