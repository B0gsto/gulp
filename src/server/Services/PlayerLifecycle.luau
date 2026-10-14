--!strict
-- PlayerLifecycle: the join and leave sequence (docs/09, sections 4.5, 5.1, 6.2, 6.3 and 18.2).
-- It starts last, so every service is ready before the first join, and replays the players who
-- joined during start-up.
--
-- Join:  profile (DataService.load; no profile, no play: the player is kicked), slot (and the
--        `Slot` attribute; the cove rule of 13.1), policy, cove (CoveService.open); then, once the
--        client has sent ClientReady (it waits for `workspace.PersistentLoaded` first, spike F4),
--        the creature, then `onReady`. ClientReady may arrive before the join steps finish; it is kept.
-- Load:  `sys_load_time` (10 §4.2) is J, seconds from `PlayerAdded` to control. Control comes at
--        the spawn for an account that has finished the FTUE (the loading screen fades straight
--        into the water, 08 §8.1); for one that has not, the hatch comes first (04 §3.1 S1_HATCH)
--        and the tutorial calls `controlGranted` when it ends. In the account's first session
--        control also starts T for `fs_time_mark` (10 §3.3): each mark fires once if the player
--        is still here. `ClientReady` carries the load mode (09 §5.3, Logic/LoadTime), kept with
--        J at that moment for the tutorial's `load_partial` and `load_minimal` (`loadMode`).
-- Leave: `onLeaving` (settlement), the creature is removed, the cove closed, then the slot is
--        freed.
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnalyticsRules = require(ReplicatedStorage.Shared.Logic.AnalyticsRules)
local CoveRules = require(ReplicatedStorage.Shared.Logic.CoveRules)
local LoadTime = require(ReplicatedStorage.Shared.Logic.LoadTime)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local PolicyRules = require(ReplicatedStorage.Shared.Logic.PolicyRules)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local SlotPool = require(ReplicatedStorage.Shared.Logic.SlotPool)
local Types = require(ReplicatedStorage.Shared.Types)

local Analytics = require("./Analytics")
local CoveService = require("./CoveService")
local CreatureService = require("./CreatureService")
local DataService = require("./DataService")
local LiveConfig = require("./LiveConfig")
local RunLoopService = require("./RunLoopService")
local Server = require("../Net/Server")
local WorldIndex = require("./WorldIndex")

type Slot = Types.Slot
type Policy = PolicyRules.Policy

-- Where a player is in the join sequence.
type Stage = "joining" | "joined" | "spawned"

local TAG = "Lifecycle"

local PlayerLifecycle = {}
PlayerLifecycle.name = "PlayerLifecycle"

--- Fires (player, slot) once the player's creature is in the world and theirs.
PlayerLifecycle.onReady = Signal.new() :: Types.Signal<Player, Slot>
--- Fires (player, slot) when the player leaves, before the creature is removed and the slot freed.
PlayerLifecycle.onLeaving = Signal.new() :: Types.Signal<Player, Slot>

local pool = SlotPool.new()
local slotOf: { [Player]: Slot } = {}
local playerAt: { [Slot]: Player } = {}
local stageOf: { [Player]: Stage } = {}
local readyAsked: { [Player]: boolean } = {}
local policyOf: { [Player]: Policy } = {}
local joinedAt: { [Player]: number } = {} -- os.clock() at PlayerAdded: J = 0 (10, the clocks)
local controlReported: { [Player]: boolean } = {}
-- `ClientReady`'s load mode (LoadTime.MODE) and J when it came.
local loadOf: { [Player]: { code: number, j: number } } = {}

--- The player's slot, or nil when they hold none.
function PlayerLifecycle.getSlot(player: Player): Slot?
	return slotOf[player]
end

--- The player in `slot`, or nil when the slot is free.
function PlayerLifecycle.getPlayer(slot: Slot): Player?
	return playerAt[slot]
end

--- The PolicyService answer stored at join (section 18.2): the most restrictive values until it
--- arrives, and when the call failed.
function PlayerLifecycle.policy(player: Player): Policy
	return policyOf[player] or PolicyRules.MOST_RESTRICTIVE
end

--- Control granted (04 §2.1, end of phase E): sends `sys_load_time` with J (10 §4.2), once a
--- session. PlayerLifecycle calls it at the spawn for an account that has finished the FTUE; the
--- tutorial calls it when the hatch ends (04 §3.1: S1_HATCH to S2_FIRST_BITE).
function PlayerLifecycle.controlGranted(player: Player)
	local at = joinedAt[player]
	if not at or controlReported[player] then
		return
	end
	controlReported[player] = true
	local j = os.clock() - at
	Analytics.event(player, "sys_load_time", LoadTime.value(j), LoadTime.bucket(j))
	-- 10 §3.3: the time marks run on T in the account's first session only (`sessions` counts
	-- this one), so each fires at most once per account.
	local data = DataService.get(player)
	if data and data.sessions <= 1 then
		for _, mark in AnalyticsRules.TIME_MARKS do
			task.delay(mark.at, function()
				if joinedAt[player] == at then -- still in this session
					Analytics.event(player, "fs_time_mark", 1, mark.ctx)
				end
			end)
		end
	end
end

--- `ClientReady`'s load mode (LoadTime.MODE: full, partial, minimal) and J in seconds when it
--- came; nil before it.
function PlayerLifecycle.loadMode(player: Player): (number?, number?)
	local load = loadOf[player]
	if not load then
		return nil, nil
	end
	return load.code, load.j
end

local function spawnCreature(player: Player)
	local slot = slotOf[player]
	stageOf[player] = "spawned"
	WorldIndex.sendWorldInfo(player) -- once, after ClientReady (09 §5.3, §9.1)
	CreatureService.spawn(player, RunLoopService.join(player, slot)) -- Nursery or cove (6.3)
	DataService.pushAll(player) -- the first state push, before onReady
	LiveConfig.pushAll(player) -- the `config.*` root of the same push (09 §5.3, §17.4)
	PlayerLifecycle.onReady:fire(player, slot)
	local data = DataService.get(player)
	if data and data.ftue.completed then
		PlayerLifecycle.controlGranted(player) -- no hatch: control as the loading screen fades
	end
end

local function join(player: Player)
	if slotOf[player] or player.Parent ~= Players then
		return -- replayed twice, or already gone
	end
	joinedAt[player] = joinedAt[player] or os.clock()
	-- The profile first (09 §12.4: without one there is no creature); section 13.1 gives the
	-- slot once it is loaded. `load` yields, and kicks when there is no profile.
	if not DataService.load(player) then
		return
	end
	if slotOf[player] or player.Parent ~= Players then
		DataService.release(player) -- replayed twice while loading, or gone
		return
	end
	-- The cove rule of section 13.1 (chapter 04, section 5.5): nearest the Gap for an account that
	-- has never banked, the farthest of the 20 nearest for a returning one.
	local data = DataService.get(player)
	local banks = if data then data.stats.banks else 0
	local slot = SlotPool.take(pool, CoveRules.preference(banks))
	if not slot then
		Log.error(TAG, `no free slot for {player.UserId}`)
		DataService.release(player)
		player:Kick("This server is full.") -- TODO(B33): through Loc
		return
	end
	slotOf[player], playerAt[slot], stageOf[player] = slot, player, "joining"
	player:SetAttribute("Slot", slot)

	local ok, result = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if not ok then
		Log.warn(TAG, `policy lookup failed for {player.UserId}; most restrictive assumed`)
	end
	if slotOf[player] ~= slot then
		return -- left while the call yielded
	end
	policyOf[player] = PolicyRules.from(ok, result)
	CoveService.open(player, slot) -- slot = cove number; the pile is brought up to date (13.2)

	stageOf[player] = "joined"
	if readyAsked[player] then
		spawnCreature(player)
	end
end

local function onClientReady(player: Player, mode: number)
	if readyAsked[player] then
		return
	end
	readyAsked[player] = true
	local at = joinedAt[player]
	loadOf[player] = { code = mode, j = if at then os.clock() - at else 0 }
	if stageOf[player] == "joined" then
		spawnCreature(player)
	end
end

local function leave(player: Player)
	readyAsked[player], joinedAt[player], controlReported[player] = nil, nil, nil
	loadOf[player] = nil
	local slot = slotOf[player]
	if not slot then
		DataService.release(player) -- left between the profile and the slot
		return
	end
	-- Leave settlement: the run first (called directly: RunLoopService cannot require this module,
	-- which requires it), then onLeaving; section 13.1 frees the slot only after it. The profile is
	-- released after settlement (12.5).
	RunLoopService.suspendOnLeave(player)
	PlayerLifecycle.onLeaving:fire(player, slot)
	CreatureService.remove(slot)
	CoveService.close(player) -- the pile settled at session end (13.2); the cove freed (13.1)
	DataService.release(player)
	slotOf[player], playerAt[slot], stageOf[player], policyOf[player] = nil, nil, nil, nil
	SlotPool.free(pool, slot)
end

function PlayerLifecycle.init()
	Players.CharacterAutoLoads = false -- also set in the project files (section 6.2)
end

function PlayerLifecycle.start()
	Server.on(
		"ClientReady",
		{ Server.Validate.int(LoadTime.MODE_MIN, LoadTime.MODE_MAX) },
		onClientReady
	)
	Players.PlayerAdded:Connect(join)
	Players.PlayerRemoving:Connect(leave)
	-- TODO(B19, B20): shutdown settlement through game:BindToClose (section 12.5).
	for _, player in Players:GetPlayers() do
		task.spawn(join, player) -- anyone who joined during start-up
	end
end

-- Engine-spec hooks (src/server/Tests/CreatureSpec): run the real sequence for a player who is
-- already in the server. Not for game code.
PlayerLifecycle._test = table.freeze({
	join = join,
	leave = leave,
	clientReady = function(player: Player)
		readyAsked[player] = nil
		onClientReady(player, LoadTime.MODE.full)
	end,
})

return PlayerLifecycle
