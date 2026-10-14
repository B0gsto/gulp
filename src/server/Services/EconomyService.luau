--!strict
-- EconomyService: the only place Pearls change (docs/09, sections 4.4, 5.1 and 14; docs/10,
-- section 5; task S5-C1, module B21). Owns nothing persistent: the balance is `pearls` in the
-- profile (09 §12.2), written through `DataService.patch`, so the owner's client hears of it as a
-- `State` patch. Every change logs one economy event through `Analytics.pearls`, so the logged
-- sources minus sinks always match the saved balance (10 §9.2 `wallet_mismatch`).
--
-- `tools/check` fails any other file under src/server that writes the `pearls` path
-- (tools/lib/dependency_rules.luau, `pearlWrites`).
--
-- Both calls are synchronous: the balance is read, checked and written with no yield between,
-- so two spends in one frame cannot both pass the check (09 §14).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyRules = require(ReplicatedStorage.Shared.Logic.EconomyRules)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Types = require(ReplicatedStorage.Shared.Types)

local Analytics = require("./Analytics")
local DataService = require("./DataService")

export type PearlSource = EconomyRules.PearlSource
export type PearlSink = EconomyRules.PearlSink

type Store = {
	get: (player: Player) -> Types.ProfileData?,
	patch: (player: Player, path: string, value: any) -> boolean,
}

local TAG = "Economy"

local EconomyService = {}
EconomyService.name = "EconomyService"

local store: Store = DataService

--- The player's Pearls; 0 while no profile is loaded.
function EconomyService.balance(player: Player): number
	local data = store.get(player)
	return if data then data.pearls else 0
end

local function write(
	player: Player,
	after: number,
	flow: EconomyRules.Flow,
	amount: number,
	kind: string,
	sku: string?
): boolean
	if not store.patch(player, "pearls", after) then
		return false
	end
	Analytics.pearls(player, flow, amount, after, kind, sku)
	return true
end

--- Adds `amount` Pearls from `source` (a 10 §5.1 transaction type; `sku` its item SKU). False,
--- with a log line, when there is no profile or the amount, source or SKU is refused.
function EconomyService.grant(
	player: Player,
	amount: number,
	source: PearlSource,
	sku: string?
): boolean
	local data = store.get(player)
	if not data then
		Log.warn(TAG, `grant {amount} ({source}): no profile for {player.UserId}`)
		return false
	end
	local after, why = EconomyRules.afterGrant(data.pearls, amount, source, sku)
	if not after then
		Log.warn(TAG, `grant refused for {player.UserId}: {why}`)
		return false
	end
	return write(player, after, "Source", amount, source, sku)
end

--- Takes `amount` Pearls for `sink` (a 10 §5.2 transaction type; `sku` what was bought). False
--- when the balance is short (nothing changes), when there is no profile, or when the amount,
--- sink or SKU is refused.
function EconomyService.spend(player: Player, amount: number, sink: PearlSink, sku: string): boolean
	local data = store.get(player)
	if not data then
		Log.warn(TAG, `spend {amount} ({sink}): no profile for {player.UserId}`)
		return false
	end
	local after, why = EconomyRules.afterSpend(data.pearls, amount, sink, sku)
	if not after then
		-- A short balance is an ordinary answer; anything else is a caller's mistake.
		local valid = EconomyRules.checkAmount(amount) and EconomyRules.checkKind("Sink", sink, sku)
		if not valid or amount <= data.pearls then
			Log.warn(TAG, `spend refused for {player.UserId}: {why}`)
		end
		return false
	end
	return write(player, after, "Sink", amount, sink, sku)
end

function EconomyService.init() end

function EconomyService.start() end

-- Engine-spec hooks (src/server/Tests/EconomySpec). Not for game code.
EconomyService._test = table.freeze({
	--- Reads and writes profiles through `fake` instead of DataService (nil restores it), so the
	--- spec can run with stand-in players where no one has joined.
	useStore = function(fake: Store?)
		store = fake or DataService
	end,
})

return EconomyService
