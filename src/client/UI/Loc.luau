--!strict
-- Loc: text by key (docs/09 section 18.1; docs/08 section 14.0). Code asks for text by key and
-- never contains player-facing words.
--
-- TODO(B33): this is the stage 1 stand-in. B33 adds `assets/loc/strings.csv`, generates
-- `Data/Generated/Strings.luau` from it and makes `t` use `LocalizationService`'s translator
-- (`GetTranslatorForPlayerAsync` in `pcall`, `FormatByKey`) with the generated English table as
-- the fallback. Until then the English text of the keys the HUD stage 1 shows is copied here,
-- word for word from docs/08 section 14, and any other key falls back to the key itself.
local Log = require(game:GetService("ReplicatedStorage").Shared.Util.Log)

local Loc = {}

local ENGLISH: { [string]: string } = table.freeze({
	-- 08 §14.1
	["common.continue"] = "Continue",
	["common.max"] = "MAX",
	["common.pearls"] = "Pearls",
	["common.mass"] = "Mass",
	["common.thousand"] = "{Value}K",
	["common.million"] = "{Value}M",
	-- 08 §14.2
	["tier.1"] = "Fry",
	["tier.2"] = "Nibbler",
	["tier.3"] = "Snapper",
	["tier.4"] = "Hunter",
	["tier.5"] = "Brute",
	["tier.6"] = "Titan",
	["tier.7"] = "Leviathan",
	-- 08 §14.3 and §14.10: the multiplier rows of the bank summary
	["trait.crystal"] = "Crystal",
	["pass.deep_pockets"] = "Deep Pockets",
	-- 08 §14.5
	["hud.next_tier"] = "{Mass} to {Tier}",
	["hud.plus_mass"] = "+{Mass}",
	["hud.home_dist"] = "{Dist} m",
	-- 08 §14.6
	["gulped.title"] = "GULPED!",
	["gulped.again"] = "Swim again",
	["bank.title"] = "Home safe!",
	["bank.best"] = "New best!",
})

--- The text of `key` with its `{Name}` parameters filled from `args`. Unknown keys return the
--- key itself (logged once), so a missing string is visible but never breaks the screen.
function Loc.t(key: string, args: { [string]: any }?): string
	local text = ENGLISH[key]
	if text == nil then
		Log.once("warn", "Loc", `no text for key "{key}" (TODO B33: generated strings)`)
		return key
	end
	if args then
		text = string.gsub(text, "{(%w+)}", function(name: string): string
			local value = args[name]
			return if value == nil then `\{{name}\}` else tostring(value)
		end)
	end
	return text
end

return Loc
