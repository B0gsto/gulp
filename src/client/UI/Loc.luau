--!strict
-- Loc: text by key (docs/09, section 18.1, V30; docs/08, section 14; task S5-C5, module B33).
-- Code asks for text by key and never contains player-facing words.
--
--   * Every key and its English are in `assets/loc/strings.csv`, generated into
--     Data/Generated/Strings by `lune run tools/gen/strings`; the CSV is also the cloud
--     localisation table.
--   * `t` asks Roblox's translator first: `LocalizationService:GetTranslatorForPlayerAsync` runs
--     once, inside `pcall`, in its own thread, and `Translator:FormatByKey` runs inside `pcall`.
--     Until the translator arrives, or when either call fails, the English table is used.
--   * Parameters are `{Name}` (a dictionary of arguments) or `{1:int}` (an array); no text is
--     built by concatenation. Automatic text capture is off on our text objects (UI/Kit/Draw).
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local English = require(ReplicatedStorage.Shared.Data.Generated.Strings)
local LocFormat = require(ReplicatedStorage.Shared.Logic.LocFormat)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local TAG = "Loc"

local Loc = {}

local translator: Translator? = nil
local asked = false

local function askTranslator()
	asked = true
	local player = Players.LocalPlayer
	if player == nil then
		return -- not a client: English only
	end
	task.spawn(function()
		local ok, result = pcall(function()
			return LocalizationService:GetTranslatorForPlayerAsync(player)
		end)
		if ok then
			translator = result
		else
			Log.once("warn", TAG, `no translator ({result}); using English`)
		end
	end)
end

--- The text of `key` with its parameters filled from `args` (`{Name}` from a dictionary,
--- `{1:int}` from an array). A key with no text anywhere returns the key itself (logged once),
--- so a missing string is visible but never breaks the screen.
function Loc.t(key: string, args: LocFormat.Args?): string
	if not asked then
		askTranslator()
	end
	local current = translator
	if current then
		local ok, text = pcall(current.FormatByKey, current, key, args or {})
		if ok and type(text) == "string" then
			return text
		end
		-- Until the cloud table holds the key (or always, for a malformed call): English.
		Log.once("info", TAG, "the translator has no entry for some keys; using English")
	end
	local english = English[key]
	if english == nil then
		Log.once("warn", TAG, `no text for key "{key}"`)
		return key
	end
	return LocFormat.format(english, args)
end

return Loc
