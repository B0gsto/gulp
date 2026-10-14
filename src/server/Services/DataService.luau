--!strict
-- DataService: loads, migrates, session-locks, autosaves and releases profiles, and pushes state
-- patches to their owner (docs/09, sections 4.4, 5.1, 12.1 to 12.4, 17.1 and 17.4; task S4-C6,
-- module B20). The only module that touches ProfileStore.
--
--   Stores:  ProfileStore.Mock in development and CI (unknown GameIds included), the real
--            `Player_v1` store in staging and production (section 17.1). Real-store behaviour
--            was not verified by spike S13 (the experiences do not exist yet).
--   Join:    PlayerLifecycle calls `load` before the creature exists; false means the player was
--            kicked (section 12.4: no play without a profile). `pushAll` is the first State push.
--   Leave:   PlayerLifecycle calls `release` after `onLeaving`, so settlement can still write.
--            Server shutdown: ProfileStore itself saves and ends every session on BindToClose.
--   Patches: `patch` writes one path of `Profile.Data` and sends what changed as `State` (path,
--            value) to the owner, whose client StateStore mirrors it.
--   Saves:   ProfileStore autosaves every 300 s. Before each save (`OnSave`) the data is checked
--            against the rules of section 12.2 and the 200 kB limit, and `kill.saves` (section
--            17.4, 12 §2.6 `saves_read_only`) is read; a refused save writes the last accepted
--            data instead, so nothing new reaches the store while play continues.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Defaults = require(ReplicatedStorage.Shared.Config.Defaults)
local Flags = require(ReplicatedStorage.Shared.Config.Flags)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Migrations = require(ReplicatedStorage.Shared.Logic.Migrations)
local SaveSchema = require(ReplicatedStorage.Shared.Logic.SaveSchema)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local StatePatch = require(ReplicatedStorage.Shared.Logic.StatePatch)
local Types = require(ReplicatedStorage.Shared.Types)

local Server = require("../Net/Server")

type ProfileData = Types.ProfileData

-- The part of ProfileStore's API this service uses (its own types wrap Data in an intersection
-- and leave `Cancel` out of the session parameters).
type Connection = { Disconnect: (self: Connection) -> () }
type Event<T...> = { Connect: (self: Event<T...>, listener: (T...) -> ()) -> Connection }
type Profile = {
	Data: { [string]: any },
	Key: string,
	OnSave: Event<>,
	OnSessionEnd: Event<>,
	IsActive: (self: Profile) -> boolean,
	EndSession: (self: Profile) -> (),
	AddUserId: (self: Profile, userId: number) -> (),
	Save: (self: Profile) -> (),
}
type SessionParams = { Cancel: (() -> boolean)? }
type Store = {
	StartSessionAsync: (self: Store, key: string, params: SessionParams?) -> Profile?,
	Mock: Store,
}
type ProfileStoreModule = {
	New: (name: string, template: { [string]: any }?) -> Store,
	OnError: Event<string, string, string>,
	OnCriticalToggle: Event<boolean>,
}

-- One open session.
type Entry = {
	profile: Profile,
	player: Player?, -- nil for a session opened by the engine spec
	live: { [string]: any }, -- the data the game reads and patches
	good: { [string]: any }, -- a copy of the last data accepted for saving
	stampedAt: number, -- os.clock() when playSeconds was last brought up to date
	forcedAt: number, -- os.clock() of the last forced save; -inf before the first
	queued: boolean, -- a forced save waits for the 30 s gap to pass
	releasing: boolean,
}

local TAG = "Data"
local S = Defaults.save
-- TODO(B33): these three through Loc. Section 12.3 and 12.4 give the text.
local KICK_NO_PROFILE = "Could not load your save. Please rejoin."
local KICK_STOLEN = "Your save was opened on another server."
local KICK_NEWER = "GULP is updating. Please rejoin."

local DataService = {}
DataService.name = "DataService"

--- Fires (player) once their profile is loaded and migrated, before the creature exists.
DataService.onLoaded = Signal.new() :: Types.Signal<Player>

local TEMPLATE = SaveSchema.template()
local store: Store? = nil
local mocked = true
local byKey: { [string]: Entry | true } = {} -- true while a session is starting
local byPlayer: { [Player]: Entry } = {}
local sendHook: ((Player, string, any) -> ())? = nil -- engine spec only

local function send(player: Player, path: string, value: any)
	if sendHook then
		sendHook(player, path, value)
	end
	Server.send(player, "State", path, value)
end

-- Section 12.2's checks and `kill.saves`: nil when the data may be written, else why not.
local function refusal(data: { [string]: any }): string?
	if Flags.bool("kill.saves") then
		return "kill.saves is on"
	end
	local ok, reason = SaveSchema.check(data)
	if not ok then
		return reason
	end
	local size = SaveSchema.encodedSize(data)
	if size > SaveSchema.MAX_BYTES then
		return `{size} bytes is over {SaveSchema.MAX_BYTES}`
	end
	return nil
end

-- Runs before every save ProfileStore makes: stamps the times, then hands it either the live data
-- or, when the save is refused, the last accepted copy.
local function beforeSave(entry: Entry)
	local live = entry.live
	local now = os.clock()
	live.playSeconds += math.floor(now - entry.stampedAt)
	entry.stampedAt = now - (now - entry.stampedAt) % 1
	live.lastSeenAt = os.time()
	local why = refusal(live)
	if why then
		entry.profile.Data = entry.good
		if why == "kill.saves is on" then
			Log.once("warn", TAG, "kill.saves is on: saves keep their last accepted data")
		else
			Log.error(TAG, `save of {entry.profile.Key} refused: {why}`)
		end
	else
		entry.profile.Data = live
		entry.good = SaveSchema.copy(live)
	end
end

-- Starts a session on `key`. A second session on a key this server already holds or is opening
-- is refused at once (ProfileStore would throw); across servers ProfileStore's session lock
-- decides (section 12.4).
local function openSession(key: string, cancel: (() -> boolean)?): (Profile?, string?)
	if not store then
		return nil, "no store"
	end
	if byKey[key] then
		return nil, "a session on this key is already open on this server"
	end
	byKey[key] = true
	local ok, result = pcall(function()
		return (store :: Store):StartSessionAsync(key, { Cancel = cancel })
	end)
	if not ok or result == nil then
		byKey[key] = nil
		if not ok then
			Log.error(TAG, `StartSessionAsync({key}) failed: {result}`)
		end
		return nil, if ok then "no session (cancelled, timed out or closing)" else "error"
	end
	return result, nil
end

local function track(profile: Profile, player: Player?): Entry
	local entry: Entry = {
		profile = profile,
		player = player,
		live = profile.Data,
		good = SaveSchema.copy(profile.Data),
		stampedAt = os.clock(),
		forcedAt = -math.huge,
		queued = false,
		releasing = false,
	}
	byKey[profile.Key] = entry
	profile.OnSave:Connect(function()
		beforeSave(entry)
	end)
	profile.OnSessionEnd:Connect(function()
		if byKey[profile.Key] == entry then
			byKey[profile.Key] = nil
		end
		if player and byPlayer[player] == entry then
			byPlayer[player] = nil
		end
		if player and not entry.releasing and player.Parent == Players then
			Log.warn(TAG, `session of {profile.Key} ended by another server`)
			player:Kick(KICK_STOLEN)
		end
	end)
	return entry
end

local function close(profile: Profile)
	local ok, err = pcall(function()
		profile:EndSession()
	end)
	if not ok then
		Log.error(TAG, `EndSession({profile.Key}) failed: {err}`)
	end
	if byKey[profile.Key] then
		byKey[profile.Key] = nil
	end
end

--- Loads, migrates and locks the player's profile (sections 12.3 and 12.4). Yields. Returns false
--- when there is no profile: the player has been kicked (or has already left).
function DataService.load(player: Player): boolean
	local key = SaveSchema.keyFor(player.UserId)
	local deadline = os.clock() + S.joinTimeout
	local profile, why = openSession(key, function()
		return player.Parent ~= Players or os.clock() > deadline
	end)
	if not profile then
		if player.Parent == Players then
			Log.warn(TAG, `no profile for {key}: {why}`)
			player:Kick(KICK_NO_PROFILE)
		end
		return false
	end
	if player.Parent ~= Players then
		close(profile) -- left while the session started
		return false
	end
	local original = SaveSchema.copy(profile.Data)
	local outcome = Migrations.upgrade(profile.Data, os.time())
	if outcome == "newer" or outcome == "invalid" then
		-- Change nothing; end the session saving only what was loaded (section 12.3, step 4).
		Log.error(TAG, `{key}: data is {outcome} (v = {tostring(original.v)})`)
		profile.Data = original
		close(profile)
		player:Kick(if outcome == "newer" then KICK_NEWER else KICK_NO_PROFILE)
		return false
	end
	profile.Data.sessions += 1
	local ok = pcall(function()
		profile:AddUserId(player.UserId) -- GDPR erasure (section 18)
	end)
	if not ok then
		Log.warn(TAG, `AddUserId({key}) failed`)
	end
	byPlayer[player] = track(profile, player)
	Log.info(TAG, `{key} loaded ({outcome}, {if mocked then "mock" else "real"} store)`)
	DataService.onLoaded:fire(player)
	return true
end

--- Ends the player's session: ProfileStore makes the final save and releases the lock.
function DataService.release(player: Player)
	local entry = byPlayer[player]
	if not entry then
		return
	end
	entry.releasing = true
	byPlayer[player] = nil
	close(entry.profile)
end

--- The player's live profile data, or nil before it is loaded and after release. Write through
--- `patch` so the client hears about it.
function DataService.get(player: Player): ProfileData?
	local entry = byPlayer[player]
	return if entry then entry.live :: any else nil
end

--- Writes `value` at `path` (StatePatch path rules, checked against the template; a control
--- scheme must be one of its input mode's IDs) and sends what changed to the owner as `State`.
--- Tables are copied. False, with a log line, when refused.
function DataService.patch(player: Player, path: string, value: any): boolean
	local entry = byPlayer[player]
	if not entry then
		Log.warn(TAG, `patch {path}: no profile for {player.UserId}`)
		return false
	end
	local data = entry.live
	local new = StatePatch.copy(value)
	if StatePatch.touches(path, "settings.input") then
		-- Scheme IDs (section 12.2, chapter 15 section 2.2): tried on a copy before the real write.
		local probe = { settings = { input = StatePatch.copy(data.settings.input) } }
		local fits = StatePatch.set(probe, TEMPLATE :: any, path, StatePatch.copy(value))
		local ok, why = SaveSchema.checkSchemes(probe.settings.input)
		if fits and not ok then
			Log.warn(TAG, `patch refused: {why}`)
			return false
		end
	end
	local old = StatePatch.copy(StatePatch.get(data, path))
	local ok, why = StatePatch.set(data, TEMPLATE :: any, path, new)
	if not ok then
		Log.warn(TAG, `patch refused: {why}`)
		return false
	end
	for _, change in StatePatch.diff(path, old, new) do
		send(player, change.path, change.value)
	end
	return true
end

--- Sends the whole profile to its owner, one State per top-level key (`pearls`, `cove` ...: the
--- profile keys are the State roots, next to `config`, section 5.3): the first state push of the
--- join (PlayerLifecycle, after ClientReady).
function DataService.pushAll(player: Player)
	local entry = byPlayer[player]
	if not entry then
		return
	end
	for key, value in entry.live do
		send(player, key, value)
	end
end

--- A forced save (section 12.4: after Robux receipts and banks of tier 5 or higher). At most one
--- per player per 30 s: a later call queues one save for the end of the gap. False when there is
--- no active profile or the save would be refused (kill.saves, the rules or the size limit).
function DataService.saveNow(player: Player): boolean
	local entry = byPlayer[player]
	if not entry or not entry.profile:IsActive() then
		return false
	end
	local why = refusal(entry.live)
	if why then
		Log.warn(TAG, `saveNow refused: {why}`)
		return false
	end
	local wait = entry.forcedAt + S.forcedSaveGap - os.clock()
	if wait <= 0 then
		entry.forcedAt = os.clock()
		entry.profile:Save()
	elseif not entry.queued then
		entry.queued = true
		task.delay(wait, function()
			entry.queued = false
			if byPlayer[player] == entry and entry.profile:IsActive() then
				entry.forcedAt = os.clock()
				entry.profile:Save()
			end
		end)
	end
	return true
end

function DataService.init()
	local environment = Defaults.forGame(game.GameId)
	mocked = environment.name ~= "staging" and environment.name ~= "production"
	local ok, result = pcall(function()
		local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore) :: any
		local module = ProfileStore :: ProfileStoreModule
		-- No template: a new profile arrives empty, so Migrations can tell it is new (12.3).
		local real = module.New(SaveSchema.STORE_NAME)
		module.OnError:Connect(function(message: string, storeName: string, key: string)
			Log.warn(TAG, `ProfileStore error ({storeName}/{key}): {message}`)
		end)
		module.OnCriticalToggle:Connect(function(critical: boolean)
			-- Section 12.4 and R6: play continues and autosaves keep retrying.
			Log.error(TAG, `ProfileStore critical state: {critical}`)
		end)
		return if mocked then real.Mock else real
	end)
	if ok then
		store = result
	else
		Log.error(TAG, `ProfileStore failed to start: {result}; every join will be refused`)
	end
end

function DataService.start() end

-- Engine-spec hooks (src/server/Tests/DataSpec). Not for game code.
DataService._test = table.freeze({
	--- Opens a session on any key with no player, as `load` does; returns the profile or nil and why.
	open = function(key: string): (Profile?, string?)
		local profile, why = openSession(key, nil)
		if profile then
			Migrations.upgrade(profile.Data, os.time())
			track(profile, nil)
		end
		return profile, why
	end,
	--- Ends a session opened by `open`.
	close = function(profile: Profile)
		local entry = byKey[profile.Key]
		if type(entry) == "table" then
			entry.releasing = true
		end
		close(profile)
	end,
	--- Runs the save check of OnSave on a session opened by `open`.
	beforeSave = function(profile: Profile)
		local entry = byKey[profile.Key]
		if type(entry) == "table" then
			beforeSave(entry)
		end
	end,
	--- Records every State this service sends (nil to stop).
	onSend = function(hook: ((Player, string, any) -> ())?)
		sendHook = hook
	end,
	isMock = function(): boolean
		return mocked
	end,
})

return DataService
