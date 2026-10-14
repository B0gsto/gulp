--!strict
-- Runs every engine-side spec and returns TestKit's report: a first line starting with PASS or
-- FAIL, then one entry per failure (docs/09, section 16.3).
--   Play test, through MCP:  return game.ServerScriptService.Server.RunTests:Invoke()
--   (Main's hook runs this module inside the server's VM, where the running services live.)
--   CI: the same line through Open Cloud Luau execution (tools/cloud/run_engine_tests.luau).
-- Physics does not step in Luau execution, so specs call service functions directly and step
-- simulations by hand.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestKit = require(ReplicatedStorage.Shared.Util.TestKit)

-- Each spec module returns a function that registers its cases. A module body runs only once
-- per session, and RunAll may be called several times in one play test.
local SPECS: { () -> () } = {
	-- Each task that writes an engine spec adds it here, one require per line.
	require("./NetSpec"),
	require("./WorldIndexSpec"),
	require("./CreatureSpec"),
	require("./PreySpec"),
	require("./BiteSpec"),
	require("./RunLoopSpec"),
}

local function runAll(): string
	for _, register in SPECS do
		register()
	end
	return TestKit.report(TestKit.run())
end

return runAll
