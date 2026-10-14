--!strict
-- CoveService: cove assignment, specimens, slots, income from timestamps and the claim (task
-- S5-C2, module B22; docs/09, sections 5.1, 5.3, 12.2 and 13; docs/02, sections 11.4, 11.5 and
-- 13; docs/05, sections 3.3, 3.4, 3.10 and 4.2; canon 5.4 and 11). The rules are
-- shared/Logic/CoveRules and CoveIncome; this module holds who owns which cove, reads and writes
-- `cove` in the profile through DataService, and moves Pearls only through EconomyService.
--
-- Owns `coveOwner[Slot]`: PlayerLifecycle opens the cove once the slot is given (and picks the
-- slot with `CoveRules.preference`, 09 §13.1) and closes it before the profile is released.
-- Opening and closing bring the pile up to date (09 §13.2: at session start and end). Income
-- leaves the pile only on the owner's tap (`CoveAction` claim ops, canon 11): never at join, on a
-- bank or at leave.
--
-- `now` is the server's `os.time()` (09 §13.3); no client time is read.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoveIncome = require(ReplicatedStorage.Shared.Logic.CoveIncome)
local CoveRules = require(ReplicatedStorage.Shared.Logic.CoveRules)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local StatePatch = require(ReplicatedStorage.Shared.Logic.StatePatch)
local Types = require(ReplicatedStorage.Shared.Types)

local DataService = require("./DataService")
local EconomyService = require("./EconomyService")
local Server = require("../Net/Server")

type Slot = Types.Slot
type Cove = CoveRules.Cove
export type AddResult = CoveRules.AddResult

type Store = {
	get: (player: Player) -> Types.ProfileData?,
	patch: (player: Player, path: string, value: any) -> boolean,
}

local TAG = "Cove"

local CoveService = {}
CoveService.name = "CoveService"
CoveService.Op = CoveRules.Op

local store: Store = DataService
local clock: () -> number = os.time
local sendHook: ((Player, string, any) -> ())? = nil
local random = Random.new()

local coveOwner: { [Slot]: Player } = {}
local slotOf: { [Player]: Slot } = {}

local function pick(n: number): number
	return random:NextInteger(1, n)
end

-- TODO(B23, S10-C2): ShopService.owns(player, "pass_bigger_cove") and "pass_tide_watcher".
local function biggerCove(_player: Player): boolean
	return false
end

local function capHours(_player: Player): number
	return CoveIncome.capHours(false)
end

local function capacity(player: Player, cove: Cove): number
	return CoveRules.capacity(cove.slots, biggerCove(player))
end

-- A copy of the player's cove to change, or nil without a profile.
local function editable(player: Player): Cove?
	local data = store.get(player)
	if not data then
		return nil
	end
	return StatePatch.copy(data.cove) :: any
end

local function write(player: Player, cove: Cove): boolean
	return store.patch(player, "cove", cove)
end

local function send(player: Player, name: string, value: any)
	if sendHook then
		sendHook(player, name, value)
		return
	end
	Server.send(player, name, value)
end

--- The owner of cove `slot`, or nil when nobody holds it.
function CoveService.ownerOf(slot: Slot): Player?
	return coveOwner[slot]
end

--- Gives `player` cove `slot` (09 §13.1: slot = cove number) and brings the pile up to date. Called
--- by PlayerLifecycle once the profile is loaded and the slot taken.
function CoveService.open(player: Player, slot: Slot)
	coveOwner[slot], slotOf[player] = player, slot
	local cove = editable(player)
	if cove then
		CoveRules.settle(cove, clock(), capHours(player))
		write(player, cove)
	end
	-- TODO(B22, S17-C1): the "While you were away" card (02 §13.3, CoveIncome.showAwayCard).
	-- TODO(B22, [L]): repeat the decoration and badge checks of 09 §12.2 at join.
end

--- Settles the pile and frees the player's cove (09 §13.1: after settlement). Called by
--- PlayerLifecycle before the profile is released.
function CoveService.close(player: Player)
	local slot = slotOf[player]
	local cove = editable(player)
	if cove then
		CoveRules.settle(cove, clock(), capHours(player))
		write(player, cove)
	end
	if slot and coveOwner[slot] == player then
		coveOwner[slot] = nil
	end
	slotOf[player] = nil
end

--- Adds a banked specimen to the player's cove (02 §11.4, 09 §13.4 step 4): settles the pile at
--- the old rate, gives `rec` a fresh ID, rounds its mass to 1 decimal and stamps it banked now.
--- `full` keeps it as `pendingSpecimen` for the release choice (02 §11.5).
function CoveService.addSpecimen(player: Player, rec: Types.SpecimenRecord): AddResult
	local cove = editable(player)
	if not cove then
		Log.warn(TAG, `addSpecimen: no profile for {player.UserId}`)
		return "refused"
	end
	local now = clock()
	local stored = table.clone(rec)
	stored.id = CoveRules.newId(cove, pick)
	stored.mass = math.round(rec.mass * 10) / 10
	stored.traits = table.clone(rec.traits)
	stored.at = now
	local result: AddResult =
		CoveRules.add(cove, stored, now, capacity(player, cove), capHours(player))
	if result == "refused" then
		local _, why = CoveRules.checkRecord(stored)
		Log.warn(
			TAG,
			`addSpecimen refused for {player.UserId}: {why or "a release choice is waiting"}`
		)
		return result
	end
	if not write(player, cove) then
		return "refused"
	end
	return result
end

--- Releases specimen `specimenId`, or the waiting new one (02 §11.5), and pays the refund (05
--- §3.10) through EconomyService. False when there is no such specimen.
function CoveService.release(player: Player, specimenId: string): boolean
	local cove = editable(player)
	if not cove then
		return false
	end
	local refund = CoveRules.release(cove, specimenId, clock(), capHours(player))
	if refund == nil or not write(player, cove) then
		return false
	end
	EconomyService.grant(player, refund, "Refund", "release_refund")
	return true
end

-- A claim (09 §13.2): the whole Pearls of the pile through EconomyService, the fraction kept,
-- `lastClaim` recorded. The grant comes first: a refused grant leaves the pile as it was.
local function claim(player: Player, sku: string): number
	local cove = editable(player)
	if not cove then
		return 0
	end
	local pearls = CoveRules.claim(cove, clock(), capHours(player))
	if pearls > 0 and not EconomyService.grant(player, pearls, "CoveIncome", sku) then
		return 0
	end
	write(player, cove)
	return pearls
end

--- The owner's tap on the Pearl clam (02 §13.2): returns the Pearls paid.
function CoveService.claimIncome(player: Player): number
	return claim(player, "claim_pile")
end

--- Buys the next cove slot with Pearls (05 §4.2); a waiting new specimen moves into it. False
--- when all 30 are bought or the balance is short.
function CoveService.buySlot(player: Player): boolean
	local cove = editable(player)
	if not cove then
		return false
	end
	local slot, price, sku = CoveRules.nextSlot(cove.slots)
	if slot == nil or price == nil or sku == nil then
		return false
	end
	if not EconomyService.spend(player, price, "CoveSlot", sku) then
		return false
	end
	CoveRules.addSlot(cove, clock(), capHours(player))
	return write(player, cove)
end

--- Sends `viewer` the `CoveView` of cove `ownerSlot` (09 §13.1). False when nobody owns it.
function CoveService.view(viewer: Player, ownerSlot: Slot): boolean
	local owner = coveOwner[ownerSlot]
	local data = if owner then store.get(owner) else nil
	if not owner or not data then
		return false
	end
	local cove = data.cove :: any
	send(
		viewer,
		"CoveView",
		CoveRules.view(ownerSlot, owner.DisplayName, cove, capacity(owner, cove))
	)
	return true
end

--- Cove Boost [L] (05 §3.4, 09 §13.2): two hours of income straight to Pearls, once per UTC day.
function CoveService.boost(_player: Player): boolean
	-- TODO(B22, [L]): CoveIncome.boost through EconomyService; cove.boostDay.
	return false
end

--- Leaves one Bubble on cove `ownerSlot` [L] (09 §13.1).
function CoveService.leaveBubble(_viewer: Player, _ownerSlot: Slot): boolean
	-- TODO(B22, [L]): visits and Bubbles (02 §13.4, §13.5).
	return false
end

local function onCoveAction(player: Player, op: number, arg: string | number)
	if slotOf[player] == nil then
		return
	end
	if op == CoveRules.Op.claim then
		CoveService.claimIncome(player)
	elseif op == CoveRules.Op.claimWelcome then
		claim(player, "claim_welcome")
	elseif op == CoveRules.Op.buySlot then
		CoveService.buySlot(player)
	elseif op == CoveRules.Op.release and type(arg) == "string" then
		CoveService.release(player, arg)
	end
end

function CoveService.init() end

function CoveService.start()
	local V = Server.Validate
	Server.on("CoveAction", {
		V.int(1, CoveRules.OP_MAX),
		V.either({ V.string(CoveRules.ID_LENGTH), V.int(0, 0) }),
	}, onCoveAction)
end

-- Engine-spec hooks (src/server/Tests/CoveSpec). Not for game code.
CoveService._test = table.freeze({
	--- Reads and writes profiles through `fake` instead of DataService (nil restores it).
	useStore = function(fake: Store?)
		store = fake or DataService
	end,
	--- Reads the time from `fake` instead of `os.time` (nil restores it).
	useClock = function(fake: (() -> number)?)
		clock = fake or os.time
	end,
	--- Hands every remote this service sends to `hook` instead of the network (nil restores it).
	onSend = function(hook: ((Player, string, any) -> ())?)
		sendHook = hook
	end,
	action = onCoveAction,
})

return CoveService
