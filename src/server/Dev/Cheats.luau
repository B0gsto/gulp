--!strict
-- Dev/Cheats: developer commands (docs/09, section 3: `server/Dev`, dev places only; task S6-C7).
-- Main loads it only where the environment of Config/Defaults has dev cheats on (GULP Dev and
-- Studio) and exposes it as the `DevCommand` BindableFunction under ServerScriptService.Server.
-- Text chat is off in the MVP (09 §17.4), so a developer runs a command from the server's command
-- line (Studio's command bar in server mode, the Developer Console's server tab, or MCP
-- `execute_luau` on the server):
--   game.ServerScriptService.Server.DevCommand:Invoke(userId, "/ftue reset")
-- Commands:
--   /ftue reset   04 §9: clears the player's `ftue` fields and starts the first-time script again
--                 from the hatch (TutorialService.reset, which checks Config/Defaults' dev cheats
--                 again itself)
--   TODO(S6-C6 or later): /ftue overlay (04 §9: T, J and the stage on screen) is a client command.
local Players = game:GetService("Players")

local TutorialService = require("../Services/TutorialService")

local Cheats = {}

-- The words of a command line, lower-cased.
local function words(text: string): { string }
	local out = {}
	for word in string.gmatch(string.lower(text), "%S+") do
		table.insert(out, word)
	end
	return out
end

--- Runs one command line for `player`. Returns whether it ran and a line saying what happened.
function Cheats.run(player: Player, text: string): (boolean, string)
	local w = words(text)
	if w[1] == "/ftue" and w[2] == "reset" and #w == 2 then
		local ok, reason = TutorialService.reset(player)
		if ok then
			return true, `ftue reset for {player.UserId}: the script starts again from the hatch`
		elseif reason == "devCheats" then
			return false, `ftue reset for {player.UserId}: refused, dev cheats are off here`
		end
		return false, `ftue reset for {player.UserId}: no profile or creature yet`
	end
	return false, `unknown command: {text}`
end

--- `DevCommand:Invoke(userId, text)`: runs `text` for the player with that user ID.
function Cheats.invoke(userId: number, text: string): string
	local player = Players:GetPlayerByUserId(userId)
	if player == nil then
		return `no player {userId} on this server`
	end
	local _, line = Cheats.run(player, text)
	return line
end

return Cheats
