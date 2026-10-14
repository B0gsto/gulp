--!strict
-- Net/RunAction: the client's `RunAction` sends (docs/09, section 5.3; task S4-C4). One function
-- per op, so screens do not build op numbers themselves.
--
-- TODO(B23, S4-C5, PR #143): the S11 gulped panel's "Swim again" button calls `swimAgain` once
-- the HUD lands; the panel ignores input for its first 700 ms (13, S12 checks). The server
-- accepts the tap only while `Phase = dead` and the gulp card is up (02 §12.1), then the client
-- plays the 0.3 s fade out and 0.3 s fade in of 02 §12.4 while the server respawns it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunRules = require(ReplicatedStorage.Shared.Logic.RunRules)

local Client = require("./Client")

local RunAction = {}

--- Op 1, "Swim again": no numbers. Returns false when the rate limit held it back.
function RunAction.swimAgain(): boolean
	return Client.send("RunAction", RunRules.Op.swimAgain)
end

return RunAction
