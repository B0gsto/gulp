--!strict
-- Analytics: the typed front for Roblox `AnalyticsService` (docs/09, sections 5.1, 17.1 and 20 R13;
-- docs/10, section 2.4; task S5-C1, module B21). The only code that calls `AnalyticsService`.
--
--   Calls:    `step` (a funnel step), `event` (a custom event), `pearls` (an economy event in
--             `Pearls`). Each is checked against Logic/AnalyticsRules (the event and funnel enum,
--             the context values, 10 §2.3's limits) and refused with a log line when it does not fit.
--   Fields:   all three custom fields on every call: `exp` (no experiments yet, so `none`),
--             `cohort` (from the profile), `ctx`.
--   Budget:   16 events per player per minute; when short, P2 goes first, then P1, never P0. Drops
--             are reported once a minute per player as `guard_flag` with ctx `analytics_drop`.
--   Repeats:  a funnel step at or below the highest already sent in its session is dropped.
--   Studio:   `AnalyticsService` accepts nothing from Studio, and section 17.1 turns analytics off in
--             development and CI, so there every call goes to a buffer of the last 2,000 records
--             instead (printed as it is written when `Analytics.debugPrint` is true). Engine specs
--             and the chapter 04 checklist read it with `Analytics.buffer()`.
--   Log:      installs the counter of Util/Log (09 §4.6): every `Log.warn` and `Log.error` is
--             counted by level and tag (`Analytics.logCounts()`). Chapter 10 has no event to carry
--             these counts yet, so they are not sent.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnalyticsRules = require(ReplicatedStorage.Shared.Logic.AnalyticsRules)
local Defaults = require(ReplicatedStorage.Shared.Config.Defaults)
local EconomyRules = require(ReplicatedStorage.Shared.Logic.EconomyRules)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Ring = require(ReplicatedStorage.Shared.Util.Ring)
local TokenBucket = require(ReplicatedStorage.Shared.Util.TokenBucket)

local DataService = require("./DataService")

type Priority = AnalyticsRules.Priority
type Flow = EconomyRules.Flow

--- One call as it would have been sent. `name` is the event, funnel or transaction type; `value`
--- the event value, step number or Pearl amount.
export type Record = {
	kind: "step" | "event" | "pearls",
	userId: number,
	name: string,
	value: number,
	ctx: string,
	cohort: string,
	exp: string,
	at: number, -- os.time()
	stepName: string?,
	sessionId: string?,
	flow: Flow?,
	balance: number?,
	sku: string?,
}

type PlayerState = {
	bucket: TokenBucket.TokenBucket,
	steps: AnalyticsRules.StepMemory,
	drops: number,
}

local TAG = "Analytics"
local LIMITS = AnalyticsRules.LIMITS
local REPORT_EVERY = 60 -- seconds between drop reports

local Analytics = {}
Analytics.name = "Analytics"
--- In Studio and tests: print every record as it is buffered.
Analytics.debugPrint = false

local sending = false
local buffer: Ring.Ring<Record> = Ring.new(LIMITS.bufferSize)
local states: { [Player]: PlayerState } = {}
local logCounts: { [string]: number } = {}

local function stateOf(player: Player): PlayerState
	local state = states[player]
	if not state then
		local perSecond = LIMITS.eventsPerPlayerPerMinute / 60
		state = {
			bucket = TokenBucket.new(perSecond, LIMITS.eventsPerPlayerPerMinute, os.clock()),
			steps = AnalyticsRules.newStepMemory(),
			drops = 0,
		}
		states[player] = state
	end
	return state
end

-- 10 §2.4 rate budget. False when the event is dropped (and counted).
local function admit(player: Player, priority: Priority): boolean
	local state = stateOf(player)
	local now = os.clock()
	if not AnalyticsRules.admits(priority, TokenBucket.available(state.bucket, now)) then
		state.drops += 1
		return false
	end
	TokenBucket.take(state.bucket, now)
	return true
end

local function cohortOf(player: Player): string
	local data = DataService.get(player)
	if not data then
		return "s1" -- no profile yet: nothing older is known
	end
	return AnalyticsRules.cohort(data.sessions, data.createdAt, os.time())
end

local function fields(record: Record): { [string]: string }
	return {
		[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = record.exp,
		[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = record.cohort,
		[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = record.ctx,
	}
end

-- Sends the record, or buffers it where nothing may be sent. Engine calls are inside pcall (4.6).
local function emit(player: Player, record: Record)
	if not sending then
		Ring.push(buffer, record)
		if Analytics.debugPrint then
			print(
				`[{TAG}] {record.kind} {record.name} {record.value} ctx={record.ctx} cohort={record.cohort}`
			)
		end
		return
	end
	local ok, problem = pcall(function()
		if record.kind == "event" then
			AnalyticsService:LogCustomEvent(player, record.name, record.value, fields(record))
		elseif record.kind == "step" and record.name == "onboarding" then
			AnalyticsService:LogOnboardingFunnelStepEvent(
				player,
				record.value,
				record.stepName :: string,
				fields(record)
			)
		elseif record.kind == "step" then
			AnalyticsService:LogFunnelStepEvent(
				player,
				record.name,
				record.sessionId :: string,
				record.value,
				record.stepName :: string,
				fields(record)
			)
		else
			local flow = if record.flow == "Sink"
				then Enum.AnalyticsEconomyFlowType.Sink
				else Enum.AnalyticsEconomyFlowType.Source
			AnalyticsService:LogEconomyEvent(
				player,
				flow,
				EconomyRules.CURRENCY,
				record.value,
				record.balance :: number,
				record.name,
				record.sku or "",
				fields(record)
			)
		end
	end)
	if not ok then
		Log.warn(TAG, `{record.kind} {record.name} not sent: {problem}`)
	end
end

local function record(
	player: Player,
	kind: "step" | "event" | "pearls",
	name: string,
	value: number,
	ctx: string?
): Record
	return {
		kind = kind,
		userId = player.UserId,
		name = name,
		value = value,
		ctx = ctx or AnalyticsRules.NONE,
		cohort = cohortOf(player),
		exp = AnalyticsRules.NONE,
		at = os.time(),
	}
end

--- A funnel step of 10 §3 (`stepNumber` from 1). `sessionId` is nil for the one-time onboarding
--- funnel. `ctx` is the funnel's context value where 10 §3 gives one (species, trait, tide event,
--- product type, tier or `paid`). Returns whether it was sent (or buffered); a repeat, a refused
--- or a dropped step returns false.
function Analytics.step(
	player: Player,
	funnel: string,
	sessionId: string?,
	stepNumber: number,
	ctx: string?
): boolean
	local stepName, why = AnalyticsRules.checkStep(funnel, sessionId, stepNumber, ctx)
	if not stepName then
		Log.warn(TAG, `step refused: {why}`)
		return false
	end
	local def = AnalyticsRules.FUNNELS[funnel]
	local state = stateOf(player)
	if not AnalyticsRules.isNewStep(state.steps, funnel, sessionId, stepNumber) then
		return false
	end
	if not admit(player, def.priority) then
		return false
	end
	AnalyticsRules.firstTime(state.steps, funnel, sessionId, stepNumber)
	local r = record(player, "step", funnel, stepNumber, ctx)
	r.stepName = stepName
	r.sessionId = sessionId
	emit(player, r)
	return true
end

--- A custom event of 10 §4.2. `value` defaults to 1; `ctx` is nil for an event without one.
function Analytics.event(player: Player, name: string, value: number?, ctx: string?): boolean
	local amount = if value == nil then 1 else value
	local ok, why = AnalyticsRules.checkEvent(name, amount, ctx)
	if not ok then
		Log.warn(TAG, `event refused: {why}`)
		return false
	end
	if not admit(player, AnalyticsRules.EVENTS[name].priority) then
		return false
	end
	emit(player, record(player, "event", name, amount, ctx))
	return true
end

--- An economy event in `Pearls` (10 §5). EconomyService calls it on every balance change; nothing
--- else should. `amount` is positive for sources and sinks alike; `balance` is the ending balance.
function Analytics.pearls(
	player: Player,
	flow: Flow,
	amount: number,
	balance: number,
	transactionType: string,
	sku: string?
): boolean
	local ok, why = AnalyticsRules.checkPearls(flow, amount, balance, transactionType, sku)
	if not ok then
		Log.warn(TAG, `pearls refused: {why}`)
		return false
	end
	if not admit(player, "P0") then
		return false
	end
	local r = record(player, "pearls", transactionType, amount, sku)
	r.flow = flow
	r.balance = balance
	r.sku = sku
	emit(player, r)
	return true
end

--- A fresh GUID for the funnels whose session is one (10 §3: a run, a shop visit or offer).
function Analytics.newSessionId(): string
	return game:GetService("HttpService"):GenerateGUID(false)
end

--- Whether calls reach `AnalyticsService` (staging and production outside Studio).
function Analytics.isSending(): boolean
	return sending
end

--- The buffered records, oldest first (a copy).
function Analytics.buffer(): { Record }
	return Ring.toArray(buffer)
end

function Analytics.clearBuffer()
	Ring.clear(buffer)
end

--- `Log.warn` and `Log.error` lines counted since start, keyed `<level>:<tag>` (a copy).
function Analytics.logCounts(): { [string]: number }
	return table.clone(logCounts)
end

--- Forgets a player's budget, funnel memory and drops (on leave; specs with stand-in players).
function Analytics.forget(player: Player)
	states[player] = nil
end

-- Sends each player's drop count of the last minute as `guard_flag` / `analytics_drop` (P0).
local function reportDrops()
	for player, state in states do
		if state.drops > 0 then
			local drops = state.drops
			state.drops = 0
			emit(player, record(player, "event", "guard_flag", drops, "analytics_drop"))
		end
	end
end

function Analytics.init()
	local environment = Defaults.forGame(game.GameId)
	sending = environment.analytics and not RunService:IsStudio()
	Log.setCounter(function(level: Log.Level, tag: string)
		local key = `{level}:{tag}`
		logCounts[key] = (logCounts[key] or 0) + 1
	end)
end

function Analytics.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		local state = states[player]
		if state and state.drops > 0 then
			reportDrops()
		end
		Analytics.forget(player)
	end)
	task.spawn(function()
		while true do
			task.wait(REPORT_EVERY)
			reportDrops()
		end
	end)
end

-- Engine-spec hooks (src/server/Tests/EconomySpec). Not for game code.
Analytics._test = table.freeze({
	--- The drops counted for a player since the last report.
	drops = function(player: Player): number
		local state = states[player]
		return if state then state.drops else 0
	end,
	reportDrops = reportDrops,
})

return Analytics
