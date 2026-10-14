--!strict
local process = require("@lune/process")

local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function releaseCheck(args: { string }): (number, string)
	local result =
		process.exec("lune", table.move(args, 1, #args, 3, { "run", "tools/release_check" }))
	return result.code, result.stdout
end

describe("tools/release_check", function()
	it("passes when every row is final", function()
		local code, out = releaseCheck({ "--", "tests/fixtures/manifest/all_final.csv" })
		expect(code).toBe(0)
		expect(string.find(out, "RELEASE CHECK PASS: all 6 rows are final", 1, true) ~= nil).toBe(
			true
		)
	end)

	it("fails with the offending rows", function()
		local code, out = releaseCheck({ "--", "tests/fixtures/manifest/some_placeholder.csv" })
		expect(code).toBe(1)
		for _, expected in
			{
				"some_placeholder.csv:3  T_Minnow_Juv_Alb  placeholder",
				"some_placeholder.csv:4  A_Fish_Bite  placeholder",
				"some_placeholder.csv:5  SFX_Gulp  final but no asset ID",
				"RELEASE CHECK FAIL: 3 of 5 rows are not final",
			}
		do
			expect(string.find(out, expected, 1, true) ~= nil).toBe(true)
		end
	end)

	it("fails the shipped all-placeholder manifest", function()
		local code, out = releaseCheck({})
		expect(code).toBe(1)
		expect(string.find(out, "M_Species_Minnow_Juv  placeholder", 1, true) ~= nil).toBe(true)
	end)

	it("refuses a missing file", function()
		local code = releaseCheck({ "--", "tests/fixtures/manifest/missing.csv" })
		expect(code).toBe(2)
	end)
end)
