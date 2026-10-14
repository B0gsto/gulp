--!strict
-- SaveSchema: the save of docs/09, section 12.2, version 1 (task S4-C6, module B20). The type
-- lives in Types.ProfileData; this module builds the template a new account starts from and checks
-- the rules every saved value follows: dictionary keys are strings, arrays have no holes, no NaN
-- or infinity, no Instances, buffers, functions or other engine values. Pure, so it runs in Lune.
--
-- Fields tagged [L] are in the template from the start with empty defaults, so shipping them
-- needs no migration (section 12.2). Optional fields (`run`, `traitLock`, `cove.pendingSpecimen`,
-- `cove.lastClaim`, `rank.title`, `settings.reduceMotion`) are absent from the template.
local Defaults = require("../Config/Defaults")
local Types = require("../Types")

type ProfileData = Types.ProfileData
type InputSettings = Types.InputSettings

local SaveSchema = {}

local S = Defaults.save

SaveSchema.STORE_NAME = "Player_v1" -- section 12.1
SaveSchema.MAX_BYTES = S.maxBytes

--- The profile key of a user (section 12.1): `u_<userId>`.
function SaveSchema.keyFor(userId: number): string
	return `u_{userId}`
end

--- The control scheme IDs each input mode may save (section 12.2 `InputSettings.scheme`;
--- chapter 15, section 2.2). The left-handed layout is a setting of a scheme, not a scheme.
local SCHEMES: { [string]: { [string]: boolean } } = {
	touch = table.freeze({ drag = true, two_thumb = true }), -- drag to swim [MVP]; two-thumb [L]
	-- mouse and keyboard [MVP]: free cursor (the default) or locked mouse look (02 §2.3, 15 §3.3)
	keys = table.freeze({ keys = true, keys_locked = true }),
	pad = table.freeze({ pad = true }), -- [L]
}
SaveSchema.SCHEMES = table.freeze(SCHEMES)

--- Whether every input mode in `input` (a profile's `settings.input`) saves one of its own scheme
--- IDs, with the first offending path when not.
function SaveSchema.checkSchemes(input: unknown): (boolean, string?)
	if type(input) ~= "table" then
		return false, "settings.input: not a table"
	end
	local modes = input :: { [string]: any }
	for mode, ids in SCHEMES do
		local entry = modes[mode]
		local scheme = if type(entry) == "table" then entry.scheme else nil
		if type(scheme) ~= "string" or not ids[scheme] then
			return false, `settings.input.{mode}.scheme: {tostring(scheme)} is not a {mode} scheme`
		end
	end
	return true, nil
end

local function inputSettings(scheme: string): InputSettings
	return {
		scheme = scheme,
		lookSpeed = S.lookSpeed,
		twoThumbLookSpeed = S.twoThumbLookSpeed,
		flipY = false, -- 15 §3.1, §3.3: flip is off
		graphics = "auto", -- 08 §6.7: Graphics Auto
	}
end

--- A fresh copy of the version 1 template. `createdAt`, `lastSeenAt` and `accruedAt` are 0 here;
--- Migrations stamps them when it fills a new profile.
function SaveSchema.template(): ProfileData
	return {
		v = 1,
		createdAt = 0,
		lastSeenAt = 0,
		sessions = 0,
		playSeconds = 0,
		pearls = 0, -- 05 §3: a new profile starts with 0 Pearls; there is no starting grant
		rank = { points = 0, claimed = 0 },
		species = {
			owned = { [S.starterSpecies] = true },
			selected = S.starterSpecies,
			patterns = {},
			equipped = {},
		},
		cove = {
			slots = S.coveSlots,
			specimens = {},
			pending = 0,
			accruedAt = 0,
			boostDay = 0,
			bubbles = 0,
			decorOwned = {},
			decor = {},
		},
		codex = {
			species = {},
			traits = {},
			prey = {},
			dangers = {},
			places = {},
			tides = {},
			rewards = {},
		},
		goals = {
			day = 0,
			list = {},
			rerolls = 0,
			paidRerolls = 0,
			bonusClaimed = false,
			fullDays = 0,
		},
		streak = { day = 0, count = 0 },
		stats = {
			runs = 0,
			banks = 0,
			deaths = 0,
			bites = 0,
			playersEaten = 0,
			bestMass = 0,
			bestTier = 0,
			gullDodges = 0,
			breaches = 0,
			bubblesGiven = 0,
			events = {},
		},
		newcomer = { firstDeath = false, biteAbsorbed = false, runsCompleted = 0, shieldUsed = 0 },
		passes = {},
		tokens = { revive = 0, trait_lock = 0, call_tide = 0, goal_reroll = 0 }, -- 05 §3: 0 of each
		purchases = {
			receipts = {},
			starterPack = false,
			robuxSpent = 0,
			packDay = 0,
			packsToday = 0,
		},
		ads = { day = 0, counts = {} },
		offers = {},
		social = { bubbleDay = 0, bubbledUserIds = {} },
		board = { week = 0, weekBest = 0 },
		ftue = { stage = 0, completed = false, version = S.ftueVersion, attempts = 0 },
		ab = {},
		settings = {
			sfx = S.sfx,
			music = S.music,
			colourBlind = false, -- 08 §6.7: Off
			vibration = true, -- 08 §6.7: On
			tapNotHold = false, -- 08 §6.7: Off
			leftHanded = false,
			biggerText = false,
			language = "", -- 08 §6.7: same as Roblox
			interfaceSize = S.interfaceSize,
			swapSticks = false,
			hideEmotes = false,
			-- 15 §2.2 scheme IDs (SCHEMES above): touch starts on "drag", keys on "keys", pad on "pad".
			input = {
				touch = inputSettings("drag"),
				keys = inputSettings("keys"),
				pad = inputSettings("pad"),
			},
			lastGoodTier = {},
		},
		moderation = { kicks = 0, flags = 0 },
	}
end

-- The shape of a table: an array (keys 1..n, n >= 0) or a dictionary (string keys only).
local function shapeOf(t: { [unknown]: unknown }): ("array" | "dictionary" | "mixed", number)
	local count, strings = 0, 0
	for key in t do
		count += 1
		if type(key) == "string" then
			strings += 1
		end
	end
	if strings == count then
		return if count == 0 then "array" else "dictionary", count
	end
	if strings == 0 and #t == count then
		return "array", count
	end
	return "mixed", count
end

local function check(value: unknown, path: string, seen: { [unknown]: boolean }): (boolean, string?)
	local kind = type(value)
	if kind == "number" then
		local n = value :: number
		if n ~= n or n == math.huge or n == -math.huge then
			return false, `{path}: not a finite number`
		end
		return true, nil
	elseif kind == "string" or kind == "boolean" or kind == "nil" then
		return true, nil
	elseif kind ~= "table" then
		return false, `{path}: {kind} cannot be saved`
	end
	local t = value :: { [unknown]: unknown }
	if seen[t] then
		return false, `{path}: a table appears twice`
	end
	seen[t] = true
	local shape = shapeOf(t)
	if shape == "mixed" then
		return false, `{path}: keys must be all strings or an array with no holes`
	end
	for key, child in t do
		local ok, reason = check(child, `{path}.{tostring(key)}`, seen)
		if not ok then
			return false, reason
		end
	end
	return true, nil
end

--- Whether `value` follows the save rules of section 12.2, with the first offending path.
function SaveSchema.check(value: unknown, path: string?): (boolean, string?)
	return check(value, path or "data", {})
end

-- JSON length of a string body: quotes, plus escapes for quote, backslash and control bytes.
local function stringSize(s: string): number
	local size = #s + 2
	for _ in string.gmatch(s, '[%c"\\]') do
		size += 1 -- `\n`; control bytes other than the common ones take 6, close enough here
	end
	return size
end

local function numberSize(n: number): number
	if n == math.floor(n) and math.abs(n) < 2 ^ 53 then
		return #string.format("%d", n)
	end
	return #string.format("%.14g", n)
end

--- The JSON size, in bytes, of a value that passes `check`: what DataStore stores (V8). An
--- estimate within a few bytes per escaped character, enough for the 200 kB refusal.
function SaveSchema.encodedSize(value: unknown): number
	local kind = type(value)
	if kind == "number" then
		return numberSize(value :: number)
	elseif kind == "string" then
		return stringSize(value :: string)
	elseif kind == "boolean" then
		return if value then 4 else 5
	elseif kind ~= "table" then
		return 4 -- null
	end
	local t = value :: { [unknown]: unknown }
	local shape, count = shapeOf(t)
	local size = 2 + math.max(count - 1, 0) -- brackets and commas
	for key, child in t do
		if shape == "dictionary" then
			size += stringSize(key :: string) + 1 -- "key":
		end
		size += SaveSchema.encodedSize(child)
	end
	return size
end

--- A deep copy of a saveable value (tables copied, everything else as is).
function SaveSchema.copy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, child in value :: any do
		out[key] = SaveSchema.copy(child)
	end
	return out :: any
end

return table.freeze(SaveSchema)
