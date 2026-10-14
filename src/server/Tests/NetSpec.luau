--!strict
-- Engine-side spec of Net/Server and Net/RateLimiter (docs/09, sections 5.3 and 14.2). The pure
-- parts (remote table, Validate, RateLimit, Guard) are covered in Lune by tests/unit/Net; this
-- checks what only the engine can: the remotes Net/Server built, and its refusals. It registers
-- no handler, so the services of the running place are left alone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local TestKit = require(ReplicatedStorage.Shared.Util.TestKit)

local RateLimiter = require("../Net/RateLimiter")
local Server = require("../Net/Server")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

return function()
	describe("Net/Server (engine)", function()
		it(
			"built ReplicatedStorage.Net with one remote of the right class per row of 5.3",
			function()
				local folder = ReplicatedStorage:FindFirstChild(Remotes.FOLDER)
				expect(folder ~= nil and folder:IsA("Folder")).toBe(true)
				local net = folder :: Folder -- safe: checked just above
				expect(#net:GetChildren()).toBe(#Remotes.list)
				for _, def in Remotes.list do
					local remote = net:FindFirstChild(def.name)
					local class = if def.kind == "Reliable"
						then "RemoteEvent"
						else "UnreliableRemoteEvent"
					expect(remote and remote.ClassName).toBe(class)
				end
			end
		)

		it("refuses handlers for server-to-client and unknown remotes", function()
			expect(function()
				Server.on("PreyState", { Server.Validate.buffer(0, 900) }, function() end)
			end).toThrow("server to client")
			expect(function()
				Server.on("Nope", {}, function() end)
			end).toThrow("unknown remote")
		end)

		it("refuses to send client-to-server and unknown remotes", function()
			expect(function()
				Server.sendAll("Bite", buffer.create(8))
			end).toThrow("client to server")
			expect(function()
				Server.sendAll("Nope")
			end).toThrow("unknown remote")
		end)

		it("exposes counters and a player-keyed limiter", function()
			expect(type(Server.counters())).toBe("table")
			expect(RateLimiter.playerCount() >= 0).toBe(true)
		end)
	end)
end
