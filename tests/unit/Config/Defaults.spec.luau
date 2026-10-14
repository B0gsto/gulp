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

	it("uses Mock data in development and CI only", function()
		expect(Defaults.environments.development.mockData).toBe(true)
		expect(Defaults.environments.ci.mockData).toBe(true)
		expect(Defaults.environments.staging.mockData).toBe(false)
		expect(Defaults.environments.production.mockData).toBe(false)
		expect(Defaults.unknown.mockData).toBe(true)
	end)

	it("gives an unknown GameId Mock data, and the dev cheats only in Studio", function()
		expect(Defaults.forGame(0).mockData).toBe(true)
		expect(Defaults.forGame(0).devCheats).toBe(false)
		expect(Defaults.forGame(123456789, false).devCheats).toBe(false)
		expect(Defaults.forGame(0, true)).toBe(Defaults.studio)
		expect(Defaults.forGame(0, true).devCheats).toBe(true)
		expect(Defaults.forGame(0, true).mockData).toBe(true)
		expect(Defaults.forGame(0, true).purchases).toBe(false)
		expect(Defaults.forGame(0, true).analytics).toBe(false)
	end)

	it("never gives a listed GameId the Studio table", function()
		for gameId, name in Defaults.GAME_IDS do
			expect(Defaults.forGame(gameId, true)).toBe(Defaults.environments[name])
		end
		expect(Defaults.forGame(10770882319, true).devCheats).toBe(false) -- CI
	end)

	it("knows GULP CI: Mock data, analytics off, no purchases, no dev cheats", function()
		local environment = Defaults.forGame(10770882319)
		expect(environment).toBe(Defaults.environments.ci)
		expect(environment.name).toBe("ci")
		expect(environment.mockData).toBe(true)
		expect(environment.analytics).toBe(false)
		expect(environment.purchases).toBe(false)
		expect(environment.devCheats).toBe(false)
	end)

	it("knows GULP Dev: Mock data, analytics off, dev cheats on", function()
		local environment = Defaults.forGame(10770882807)
		expect(environment).toBe(Defaults.environments.development)
		expect(environment.mockData).toBe(true)
		expect(environment.analytics).toBe(false)
		expect(environment.devCheats).toBe(true)
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
