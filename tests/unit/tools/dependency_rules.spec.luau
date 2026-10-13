--!strict
local DependencyRules = require("../../../tools/lib/dependency_rules")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function tokens(source: string): { string }
	local found = {}
	for _, violation in DependencyRules.check(source) do
		table.insert(found, `{violation.line}:{violation.token}`)
	end
	return found
end

describe("DependencyRules.check", function()
	it("accepts pure Luau", function()
		local source = table.concat({
			"--!strict",
			'local Tiers = require("../Data/Generated/Tiers")',
			"local scratch = buffer.create(16)",
			"local function canEat(eater: number, prey: number): boolean",
			"\treturn prey <= eater and math.floor(eater) == eater",
			"end",
			"return { canEat = canEat, scratch = scratch, tiers = Tiers }",
		}, "\n")
		expect(tokens(source)).toEqual({})
	end)

	it("flags each banned name with its line", function()
		local source = table.concat({
			'local Players = game:GetService("Players")',
			"local part = Instance.new('Part')",
			"part.Parent = workspace",
			"local where: Vector3 = Vector3.zero",
			"local frame = CFrame.new()",
			"task.wait(1)",
		}, "\n")
		expect(tokens(source)).toEqual({
			"1:game",
			"2:Instance.new",
			"3:workspace",
			"4:Vector3",
			"4:Vector3",
			"5:CFrame",
			"6:task.wait",
		})
	end)

	it("ignores comments and string text", function()
		local source = table.concat({
			"-- the game calls this every tick; no Vector3 here",
			"--[[ workspace and CFrame",
			"     and task.wait() ]]",
			"--[==[ game ]==]",
			'local a = "game over"',
			"local b = 'workspace'",
			"local c = [[Instance.new]]",
			"local d = `CFrame {a} task.wait`",
			'local e = "an escaped \\" quote, then game"',
			"return { a, b, c, d, e }",
		}, "\n")
		expect(tokens(source)).toEqual({})
	end)

	it("still sees code after a comment or string, and inside string interpolation", function()
		local source = table.concat({
			'local a = "safe" .. game.Name -- game',
			"local b = `tier {workspace.Name} of {`{CFrame}`}`",
			"local c = [[x]] .. tostring(Vector3)",
		}, "\n")
		expect(tokens(source)).toEqual({ "1:game", "2:workspace", "2:CFrame", "3:Vector3" })
	end)

	it("allows fields and members that only share a name", function()
		local source = table.concat({
			"local state = { phase = 1 }",
			"local a = state.game",
			"local b = state.workspace.Vector3",
			"local c = task.spawn",
			"local d = Instance",
			"local wait = state.task.wait",
			"local gameOver, myCFrame = 1, 2",
			"return { a, b, c, d, wait, gameOver, myCFrame }",
		}, "\n")
		expect(tokens(source)).toEqual({})
	end)

	it("sees a member access split by spaces", function()
		expect(tokens("local x = Instance . new\ntask .wait()")).toEqual({
			"1:Instance.new",
			"2:task.wait",
		})
	end)
end)

describe("DependencyRules.applies", function()
	it("covers the four pure roots and nothing else", function()
		expect(DependencyRules.applies("src/shared/Logic/BiteRules.luau")).toBe(true)
		expect(DependencyRules.applies("src/shared/Sim/PreySim.luau")).toBe(true)
		expect(DependencyRules.applies("src/shared/Net/Codec/Bite.luau")).toBe(true)
		expect(DependencyRules.applies("src/shared/Data/Generated/Tiers.luau")).toBe(true)
		expect(DependencyRules.applies("src/shared/Net/Remotes.luau")).toBe(false)
		expect(DependencyRules.applies("src/shared/Util/Signal.luau")).toBe(false)
		expect(DependencyRules.applies("src/shared/LogicExtra/X.luau")).toBe(false)
		expect(DependencyRules.applies("src/server/Services/PreyService.luau")).toBe(false)
	end)
end)
