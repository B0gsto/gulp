--!strict
-- PlayerLifecycle: the join and leave sequence (docs/09, sections 4.5, 5.1, 6.2, 6.3 and 18.2).
-- It starts last, so every service is ready before the first join, and replays the players who
-- joined during start-up.
--
-- Join:  profile (DataService.load; no profile, no play: the player is kicked), slot (and the
--        `Slot` attribute), policy, cove; then, once the client has sent
--        ClientReady (it waits for `workspace.PersistentLoaded` first, spike F4), the creature,
--        then `onReady`. ClientReady may arrive before the join steps finish; it is kept.
-- Leave: `onLeaving` (settlement), the creature is removed, then the slot is freed.
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local PolicyRules = require(ReplicatedStorage.Shared.Logic.PolicyRules)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local SlotPool = require(ReplicatedStorage.Shared.Logic.SlotPool)
local Types = require(ReplicatedStorage.Shared.Types)

local CreatureService = require("./CreatureService")
local DataService = require("./DataService")
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

local function spawnCreature(player: Player)
	local slot = slotOf[player]
	stageOf[player] = "spawned"
	WorldIndex.sendWorldInfo(player) -- once, after ClientReady (09 §5.3, §9.1)
	CreatureService.spawn(player)
	DataService.pushAll(player) -- the first state push, before onReady
	PlayerLifecycle.onReady:fire(player, slot)
end

local function join(player: Player)
	if slotOf[player] or player.Parent ~= Players then
		return -- replayed twice, or already gone
	end
	-- The profile first (09 §12.4: without one there is no creature); section 13.1 gives the
	-- slot once it is loaded. `load` yields, and kicks when there is no profile.
	if not DataService.load(player) then
		return
	end
	if slotOf[player] or player.Parent ~= Players then
		DataService.release(player) -- replayed twice while loading, or gone
		return
	end
	-- TODO(B22, S5-C2): pass the cove rule of section 13.1 to SlotPool.take as the preference.
	local slot = SlotPool.take(pool)
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

	stageOf[player] = "joined"
	if readyAsked[player] then
		spawnCreature(player)
	end
end

local function onClientReady(player: Player)
	if readyAsked[player] then
		return
	end
	readyAsked[player] = true
	if stageOf[player] == "joined" then
		spawnCreature(player)
	end
end

local function leave(player: Player)
	readyAsked[player] = nil
	local slot = slotOf[player]
	if not slot then
		DataService.release(player) -- left between the profile and the slot
		return
	end
	-- TODO(B19): leave settlement (RunLoopService.suspendOnLeave) runs from onLeaving; section
	-- 13.1 frees the slot only after it. The profile is released after settlement (12.5).
	PlayerLifecycle.onLeaving:fire(player, slot)
	CreatureService.remove(slot)
	DataService.release(player)
	slotOf[player], playerAt[slot], stageOf[player], policyOf[player] = nil, nil, nil, nil
	SlotPool.free(pool, slot)
end

function PlayerLifecycle.init()
	Players.CharacterAutoLoads = false -- also set in the project files (section 6.2)
end

function PlayerLifecycle.start()
	Server.on("ClientReady", {}, onClientReady)
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
		onClientReady(player)
	end,
})

return PlayerLifecycle
