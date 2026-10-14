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

local function writes(source: string): { string }
	local found = {}
	for _, violation in DependencyRules.pearlWrites(source) do
		table.insert(found, `{violation.line}:{violation.token}`)
	end
	return found
end

describe("DependencyRules.pearlWrites (09 §4.4: only EconomyService changes Pearls)", function()
	it("flags field writes, compound writes and string-index writes", function()
		local source = table.concat({
			"local data = DataService.get(player)",
			"data.pearls = 10",
			"data.pearls += 5",
			"profile.Data . pearls -= 1",
			'data["pearls"] = 3',
			"data['pearls'] //= 2",
		}, "\n")
		expect(writes(source)).toEqual({
			"2:.pearls =",
			"3:.pearls =",
			"4:.pearls =",
			'5:["pearls"] =',
			'6:["pearls"] =',
		})
	end)

	it("flags the pearls path in patch and rawset calls, split over lines or nested", function()
		local source = table.concat({
			'DataService.patch(player, "pearls", 10)',
			"DataService.patch(",
			"\tplayer,",
			"\t'pearls',",
			"\tmath.max(0, n)",
			")",
			"log(DataService.patch(player, `pearls`, 1))",
			'rawset(data, "pearls", 0)',
		}, "\n")
		expect(writes(source)).toEqual({
			'1:patch(..., "pearls", ...)',
			'4:patch(..., "pearls", ...)',
			'7:patch(..., "pearls", ...)',
			'8:rawset(..., "pearls", ...)',
		})
	end)

	it("passes reads, comparisons, other names, comments and string text", function()
		local source = table.concat({
			"local n = data.pearls",
			"if data.pearls == 0 or data.pearls >= 5 or data.pearls ~= 3 then end",
			"result.pearlsPaid = 4",
			"local t = { pearls = 1 }",
			'-- data.pearls = 1, DataService.patch(player, "pearls", 1)',
			'Log.warn("Economy", "data.pearls = 1")',
			'DataService.patch(player, "settings.music", 4)',
			'DataService.patch(player, "pearlsX", 4)',
			'mypatch(player, "pearls", 4)',
			'local s = data.pearls .. "="',
		}, "\n")
		expect(writes(source)).toEqual({})
	end)
end)

describe("DependencyRules.pearlRuleApplies", function()
	it("covers server files except EconomyService and the engine specs", function()
		expect(DependencyRules.pearlRuleApplies("src/server/Services/RunLoopService.luau")).toBe(
			true
		)
		expect(DependencyRules.pearlRuleApplies("src/server/Services/DataService.luau")).toBe(true)
		expect(DependencyRules.pearlRuleApplies("src/server/Dev/Cheats.luau")).toBe(true)
		expect(DependencyRules.pearlRuleApplies("src/server/Services/EconomyService.luau")).toBe(
			false
		)
		expect(DependencyRules.pearlRuleApplies("src/server/Tests/DataSpec.luau")).toBe(false)
		expect(DependencyRules.pearlRuleApplies("src/shared/Logic/SaveSchema.luau")).toBe(false)
		expect(DependencyRules.pearlRuleApplies("src/client/Controllers/StateStore.luau")).toBe(
			false
		)
	end)
end)
