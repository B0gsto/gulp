--!strict
-- TraitService (task S6-C3, module B19; canon 9; docs/02, section 8; docs/09, section 5.1): trait
-- progress, the three slots, shedding and the traits' effects on the rules. The rules themselves
-- are the pure Logic/TraitRules; this service applies them to each slot's `CreatureState`
-- (`traits`, `progress`, `traitGainedAt`), which no other module writes.
--
-- Progress  BiteService calls `onTraitPreyEaten(slot, traitId)` for every trait prey it accepts
--           (data:TraitPrey `givesTrait`). Five pips gain the trait, four with `pass_keen_nose`
--           (02 §8.1); a trait already held, or three full slots, gives mass only.
--           TODO(B23, S10-C2): Keen Nose bought mid-run grants what is ready (TraitRules.grantReady).
-- Gain      the trait takes the first free slot (02 §8.2) and its effect is active 0.5 s later
--           (`has` and the multipliers read it through TraitRules.isActive).
-- Shed      `shed(slot, index)`: removed at once, its pips reset, the traits after it close up
--           (02 §8.3). Refused while gulped. TODO(B24): also while Stunned or Hooked; TODO(B32):
--           Transit (Eel); TODO(B19, S7-C3): Banking, once the bank sequence exists.
-- Reset     `reset(slot)` clears traits and pips: RunLoopService calls it when a bank starts the
--           creature again and when a gulped creature respawns (02 §8.1: pips reset on banking
--           and are lost when gulped; held traits go with the specimen or are lost).
--
-- What the clients hear:
--   `Traits` attribute   the held IDs comma-joined (09 §5.3), for every client's rig (Glow's light).
--   `State` to the owner `run.traits` (the list) and `run.progress` (trait ID → pips), the paths of
--                        the profile's `RunSnapshot` (09 §12.2), for HUD.Traits. The live run is
--                        not saved here: the profile's `run` record is S12-C4's.
--   `CreatureEvent`      to everyone: "traitGained", slot, traitId, index (the S08 card and the
--                        slot's Just gained flash on the owner; the body feature grows in on every
--                        client) and "traitShed", slot, traitId, index (the feature pops off).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local TraitRules = require(ReplicatedStorage.Shared.Logic.TraitRules)
local Types = require(ReplicatedStorage.Shared.Types)

local CreatureService = require("./CreatureService")
local DataService = require("./DataService")
local Server = require("../Net/Server")

type Slot = Types.Slot
type CreatureState = CreatureService.CreatureState

local TAG = "Trait"

local TraitService = {}
TraitService.name = "TraitService"

--- Fires (slot, trait ID, slot index) when a trait is gained (02 §8.2). CodexService and
--- GoalsService connect here when they exist.
TraitService.onGained = Signal.new() :: Types.Signal<Slot, string, number>

local lastEvent: { any }? = nil -- the last CreatureEvent sent, for the engine spec
-- Where creatures and sends come from; the engine spec swaps both for stand-ins (`_test.stub`).
local lookup: (Slot) -> CreatureState? = CreatureService.get
local sendTo: (Player, string, ...any) -> () = Server.send
local sendAll: (string, ...any) -> () = Server.sendAll

local function sendEvent(...: any)
	lastEvent = { ... }
	sendAll("CreatureEvent", ...)
end

-- The `Traits` attribute for everyone and the owner's `run.traits` and `run.progress`.
local function publish(state: CreatureState)
	state.player:SetAttribute("Traits", TraitRules.joinIds(state.traits))
	sendTo(state.player, "State", "run.traits", table.clone(state.traits))
	sendTo(state.player, "State", "run.progress", table.clone(state.progress))
end

-- 05 §4.5: the Keen Nose pass [L]. TODO(B23, S10-C2): ShopService.owns(player, "pass_keen_nose");
-- until then the profile's last answer from Roblox (`passes`, 09 §12.2), as Deep Pockets reads it.
local function keenNose(player: Player): boolean
	local profile = DataService.get(player)
	return profile ~= nil and profile.passes.pass_keen_nose == true
end

-- The base state of 02 §0.6 that TraitRules.canShed reads, from what the server keeps so far.
local function baseState(state: CreatureState): string
	local phase = state.player:GetAttribute("Phase")
	if phase == "dead" then
		return "Gulped"
	elseif phase == "cove" then
		return "InCove"
	end
	-- TODO(B24): Stunned, Hooked; TODO(B32): Transit; TODO(B19, S7-C3): Banking.
	return "Swimming"
end

-- The traits of `slot` whose effect is active now (02 §8.2), or nil when it has no creature.
local function activeTraits(slot: Slot): { string }?
	local state = lookup(slot)
	if state == nil then
		return nil
	end
	local now = os.clock()
	local active: { string } = {}
	for _, id in state.traits do
		if TraitRules.isActive(state.traitGainedAt[id] or -math.huge, now) then
			table.insert(active, id)
		end
	end
	return active
end

--- One trait prey of `traitId` was eaten by `slot` (02 §8.1, §8.2): adds its pip, or gains the
--- trait on the last one. Returns TraitRules' result ("unknown" also for a slot with no creature).
--- The mass is BiteService's.
function TraitService.onTraitPreyEaten(slot: Slot, traitId: string): TraitRules.PipResult
	local state = lookup(slot)
	if state == nil then
		return "unknown"
	end
	local result: TraitRules.PipResult, index: number? =
		TraitRules.eatTraitPrey(state.traits, state.progress, traitId, keenNose(state.player))
	if result == "pip" then
		publish(state)
	elseif result == "gained" then
		state.traitGainedAt[traitId] = os.clock()
		publish(state)
		-- TODO(B29, S9): CodexService.discover(player, "trait", traitId), the "found" stamp.
		sendEvent("traitGained", slot, traitId, index)
		TraitService.onGained:fire(slot, traitId, index :: number) -- safe: "gained" has its index
	elseif result == "unknown" then
		Log.once("warn", TAG, `trait prey for an unknown trait {traitId}`)
	end
	-- TODO(S6-C5 or later): "full" shows the owner the `hud.traits_full` chip (08 §3.6).
	return result
end

--- Sheds the trait in slot `index` (1 to 3) of `slot` (02 §8.3). Returns false and the reason
--- ("state", "empty", or "none" with no creature) when refused.
--- TODO(S04 popover): the shed button's `RunAction` op reaches this; 09 §5.3 lists it then.
function TraitService.shed(slot: Slot, index: number): (boolean, string?)
	local state = lookup(slot)
	if state == nil then
		return false, "none"
	end
	local id = state.traits[index]
	local ok, reason = TraitRules.shed(state.traits, state.progress, index, baseState(state))
	if not ok then
		return false, reason
	end
	state.traitGainedAt[id] = nil
	publish(state)
	sendEvent("traitShed", slot, id, index)
	return true, nil
end

--- Whether `slot` holds `traitId` with its effect active (02 §8.2: 0.5 s after the last pip).
function TraitService.has(slot: Slot, traitId: string): boolean
	local active = activeTraits(slot)
	return active ~= nil and TraitRules.has(active, traitId)
end

--- The held trait IDs of `slot` in slot order (a copy; empty with no creature), effects active or
--- not: what a bank keeps on the specimen.
function TraitService.traits(slot: Slot): { string }
	local state = lookup(slot)
	return if state then table.clone(state.traits) else {}
end

--- The swim speed multiplier of `slot` (Stripes, 02 §8.4).
function TraitService.speedMult(slot: Slot): number
	return TraitRules.speedMult(activeTraits(slot) or {})
end

--- The mass gain multiplier of one eat by `slot` from `source` ("prey" by default, which covers
--- trait prey; 02 §4.4, §8.5).
function TraitService.massMult(slot: Slot, source: TraitRules.MassSource?): number
	return TraitRules.massMult(activeTraits(slot) or {}, source or "prey")
end

--- Tiers added to `slot`'s defence tier in the eat test (Spiny, 02 §8.4; 09 §10.2 rule 5).
function TraitService.defenceTierBonus(slot: Slot): number
	return TraitRules.defenceTierBonus(activeTraits(slot) or {})
end

--- Clears the traits and pips of `slot` (a bank's new start, a respawn after a gulp). Sends the
--- change only when there was something to clear.
function TraitService.reset(slot: Slot)
	local state = lookup(slot)
	if state == nil or (#state.traits == 0 and next(state.progress) == nil) then
		return
	end
	table.clear(state.traits)
	table.clear(state.progress)
	table.clear(state.traitGainedAt)
	publish(state)
end

function TraitService.init()
	lastEvent = nil
end

function TraitService.start() end

-- Engine-spec hook (src/server/Tests/TraitSpec). Not for game code.
TraitService._test = table.freeze({
	lastEvent = function(): { any }?
		return lastEvent
	end,
	-- Reads creatures from `find` and hands every send to `sink` (nil for both: the real ones).
	stub = function(find: ((Slot) -> CreatureState?)?, sink: ((string, ...any) -> ())?)
		lookup = find or CreatureService.get
		sendTo = if sink
			then function(_player: Player, name: string, ...: any)
				sink(name, ...)
			end
			else Server.send
		sendAll = sink or Server.sendAll
	end,
	-- Makes every held trait of `slot` active now, as if 0.5 s had passed.
	activate = function(slot: Slot)
		local state = lookup(slot)
		if state then
			for id, at in state.traitGainedAt do
				state.traitGainedAt[id] = at - TraitRules.ACTIVATE_DELAY
			end
		end
	end,
})

return TraitService
