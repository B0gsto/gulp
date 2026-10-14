--!strict
local Defaults = require("../../../src/shared/Config/Defaults")
local TestKit = require("../../../src/shared/Util/TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Defaults.environments", function()
	it("has the four environments of section 17.1, each under its own name", function()
		local names = {}
		for name, environment in Defaults.environments do
			expect(environment.name).toBe(name)
			table.insert(names, name)
		end
		table.sort(names)
		expect(names).toEqual({ "ci", "development", "production", "staging" })
	end)

	it("keeps dev cheats out of staging and production", function()
		expect(Defaults.environments.development.devCheats).toBe(true)
		expect(Defaults.environments.staging.devCheats).toBe(false)
		expect(Defaults.environments.production.devCheats).toBe(false)
	end)

	it("sends analytics only from staging and production", function()
		expect(Defaults.environments.development.analytics).toBe(false)
		expect(Defaults.environments.ci.analytics).toBe(false)
		expect(Defaults.environments.staging.analytics).toBe(true)
		expect(Defaults.environments.production.analytics).toBe(true)
	end)

	it("is frozen", function()
		expect(function()
			-- Safe cast: the write is the thing under test.
			(Defaults.environments.production :: { [string]: unknown }).devCheats = true
		end).toThrow()
		expect(function()
			(Defaults.environments.production.productIds :: { [string]: unknown }).prod_revive = 1
		end).toThrow()
	end)
end)

describe("Defaults.forGame", function()
	it("gives an unknown GameId the development table with all purchases disabled", function()
		for _, gameId in { 0, 123456789 } do
			local environment = Defaults.forGame(gameId)
			expect(environment.name).toBe("development")
			expect(environment.purchases).toBe(false)
			expect(environment.analytics).toBe(false)
			expect(next(environment.productIds)).toBe(nil)
			expect(next(environment.passIds)).toBe(nil)
		end
	end)

	it("gives every listed GameId its own environment", function()
		for gameId, name in Defaults.GAME_IDS do
			expect(Defaults.forGame(gameId)).toBe(Defaults.environments[name])
		end
	end)
end)

describe("Defaults.live", function()
	it(
		"holds only flag, kill, live, assist and tune keys with a boolean, number or string",
		function()
			local kinds = { boolean = true, number = true, string = true }
			for key, value in Defaults.live do
				local prefix = string.match(key, "^(%l+)%.%a[%w%.]*$")
				expect({ key, prefix ~= nil }).toEqual({ key, true })
				local known = prefix == "flag"
					or prefix == "kill"
					or prefix == "live"
					or prefix == "assist"
					or prefix == "tune"
				expect({ key, known }).toEqual({ key, true })
				expect({ key, kinds[type(value)] }).toEqual({ key, true })
			end
		end
	)

	it("makes every flag, kill and assist key a boolean", function()
		for key, value in Defaults.live do
			local prefix = string.match(key, "^(%l+)%.")
			if prefix == "flag" or prefix == "kill" or prefix == "assist" then
				expect({ key, type(value) }).toEqual({ key, "boolean" })
			end
		end
	end)

	it("starts with no kill switch thrown", function()
		for key, value in Defaults.live do
			if string.sub(key, 1, 5) == "kill." then
				expect({ key, value }).toEqual({ key, false })
			end
		end
	end)

	it("carries the bible's values", function()
		-- Chapter 12, section 2.6 and chapter 09, sections 8.9, 17.4 and 18.3.
		expect(Defaults.live["flag.rewardedVideo"]).toBe(false)
		expect(Defaults.live["flag.textChat"]).toBe(false)
		expect(Defaults.live["flag.reviveOffer"]).toBe(true)
		expect(Defaults.live["flag.tideEvents"]).toBe(true)
		expect(Defaults.live["flag.coveVisits"]).toBe(true)
		expect(Defaults.live["flag.globalBoards"]).toBe(true)
		expect(Defaults.live["live.shopDelaySeconds"]).toBe(120)
		expect(Defaults.live["live.minPlaceVersion"]).toBe(0)
		expect(Defaults.live["live.limitedTideId"]).toBe("")
		expect(Defaults.live["tune.bite.baseTolerance"]).toBe(3)
	end)

	it("is frozen", function()
		expect(function()
			-- Safe cast: the write is the thing under test.
			(Defaults.live :: { [string]: unknown })["kill.saves"] = true
		end).toThrow()
	end)
end)
