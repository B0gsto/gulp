--!strict
-- BiteService: validates bite claims and applies their results (docs/09, sections 5.1 and 8.9;
-- docs/02, section 4). Prey bites only for now; player bites are S12-C2 (B25), predator bites
-- come with PredatorService.
--
-- A `Bite` message passes Net/Server's wrapper first (14.2: size, range, 12 claims/s, bucket 20).
-- Each prey target of the claim then runs 8.9's checks in order; the first failure decides it:
--   1 rate    12 prey eats a second per player, bucket 20 (02 §4.6), one token per target
--   2 state   the claimant has a creature, not gulped (02 §0.6: InCove bites prey too), not
--             stunned, not flagged (TODOs below)
--   3 gone    the group is live at the claimed gen and the member is alive (PreyService.peek)
--   4 tier    canon 5.2: prey tier ≤ eater tier (BiteRules.canEatPrey)
--   5 time    tc = clamp(claimTime, now − 0.4 s, now) (Logic/BiteMath); a group still fading in
--             at tc is refused as "time"
--   6 range   |mouth − prey| ≤ reach at tc (Logic/BiteMath): 02 §4.1's mouth centre and radius
--             with the dash factor always on, reach = 2.5 × r + prey radius + wobble + 3.0
--             + 0.15 × (eater + prey speed)
--   7 apply   PreyService.tryEat clears the member and sends PreyEvent; mass and tier follow
-- Player bites (B25, S12-C2) will run 09 §10.2's ten rules in order through
-- BiteRules.playerBite, the 90 s repeat guard (rule 7, reason 9 "repeat") included; prey has no
-- repeat guard (02 §4.2 check 7 is about players).
-- One `BiteResult` answers each claim: the accepted targets' bits, the first reject reason, the
-- new mass and tier. Rejects are counted by reason (section 20, R5: target under 2%) and range
-- misses are written to the server log with their distance and reach. Nothing is logged per bite
-- to analytics (chapter 10, section 2.4).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bite = require(ReplicatedStorage.Shared.Net.Codec.Bite)
local BiteMath = require(ReplicatedStorage.Shared.Logic.BiteMath)
local BiteResult = require(ReplicatedStorage.Shared.Net.Codec.BiteResult)
local BiteRules = require(ReplicatedStorage.Shared.Logic.BiteRules)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local RateLimit = require(ReplicatedStorage.Shared.Net.RateLimit)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local VolumeMath = require(ReplicatedStorage.Shared.Logic.VolumeMath)

local CreatureService = require("./CreatureService")
local PreyService = require("./PreyService")
local RunLoopService = require("./RunLoopService")
local Server = require("../Net/Server")
local WorldIndex = require("./WorldIndex")

type Slot = Types.Slot
type Volume = Types.Volume

local TAG = "Bite"
local EAT_BUCKET = "PreyEat"
local EAT_LIMIT = { rate = 12, size = 20 } -- 02 §4.6 and §4.7: 12 prey eats a second (tune)
local LOG_INTERVAL = 1 -- s: at most one range-miss line per player per second

-- BiteResult's reason codes by name, for the counters.
local REASON_NAME: { [number]: string } = {
	[BiteResult.REASON_GONE] = "gone",
	[BiteResult.REASON_RANGE] = "range",
	[BiteResult.REASON_TIER] = "tier",
	[BiteResult.REASON_TIME] = "time",
	[BiteResult.REASON_RATE] = "rate",
	[BiteResult.REASON_STATE] = "state",
	[BiteResult.REASON_SAFE_ZONE] = "safeZone",
	[BiteResult.REASON_PROTECTED] = "protected",
	[BiteResult.REASON_REPEAT] = "repeat",
}

--- Prey bite claims since the server started (or the last `resetCounters`), section 20 R5.
export type Counters = {
	claims: number, -- Bite messages handled
	targets: number, -- prey targets in them
	accepted: number,
	rejects: { [string]: number }, -- by reason: gone, range, tier, time, rate, state
	far: number, -- range misses beyond 3 × reach (8.9: +2 suspicion each)
	worstRange: number, -- the largest distance ÷ reach of a range miss
}

local BiteService = {}
BiteService.name = "BiteService"

--- Fires (eater slot, victim slot) when a player eats a player. TODO(B25, S12-C2): player bites.
BiteService.onPlayerEaten = Signal.new() :: Types.Signal<Slot, Slot>

local eatLimit = RateLimit.new({ [EAT_BUCKET] = EAT_LIMIT }) :: RateLimit.RateLimit<Player>
local loggedAt: { [Player]: number } = {}
local nurseries: { Volume } = {}
local counters: Counters

local function freshCounters(): Counters
	return { claims = 0, targets = 0, accepted = 0, rejects = {}, far = 0, worstRange = 0 }
end
counters = freshCounters()

local function reject(reason: number)
	local name = REASON_NAME[reason]
	counters.rejects[name] = (counters.rejects[name] or 0) + 1
end

local function inNursery(x: number, y: number, z: number): boolean
	return VolumeMath.firstContaining(nurseries, x, y, z) ~= nil
end

-- One range miss to the server log (R5), at most once a second per player.
local function logMiss(player: Player, slot: Slot, g: number, i: number, d: number, reach: number)
	local now = os.clock()
	if now - (loggedAt[player] or -math.huge) < LOG_INTERVAL then
		return
	end
	loggedAt[player] = now
	Log.info(
		TAG,
		string.format(
			"range miss: slot %d group %d member %d distance %.2f reach %.2f",
			slot,
			g,
			i,
			d,
			reach
		)
	)
end

--- Validates prey bite claim `payload` (a buffer `Bite.valid` accepted) from `player` and applies
--- what passes. Returns the `BiteResult` payload to send back. `now` is the server time on the
--- `GetServerTimeNow` clock (tests may pass one).
function BiteService.claim(player: Player, payload: buffer, now: number?): buffer
	local t = now or workspace:GetServerTimeNow()
	local op, count, seq, claimMs = Bite.header(payload)
	counters.claims += 1
	local slot = player:GetAttribute("Slot")
	local state = if type(slot) == "number" then CreatureService.get(slot) else nil
	if
		state == nil
		or state.player ~= player
		or op ~= Bite.OP_PREY
		or RunLoopService.state(state.slot) == "dead"
	then
		-- No creature, a gulped one, or a player or predator bite. TODO(B25, S12-C2): op 2 (player bites; 02 §4.7
		-- has the server detect them). TODO(B24): op 3 (predators and wild creatures, 9.3).
		local n = if op == Bite.OP_PREY then count else 1
		counters.targets += n
		for _ = 1, n do
			reject(BiteResult.REASON_STATE)
		end
		local mass, tier = if state then state.mass else 0, if state then state.tier else 1
		return BiteResult.encode(seq, 0, BiteResult.REASON_STATE, mass, tier)
	end
	-- TODO(B24): not stunned; TODO(B14, S8-C2): not flagged (7.3, level 3 rejects bites for 10 s). These are "state".
	local tc = BiteMath.claimTime(Server.fromTimeMs(claimMs), t)
	-- TODO(B14, S8-C2): the pose at tc from MovementValidator.poseAt(slot, tc), the pose ring of
	-- 09 §7. Until B14 exists the current root pose stands in for it.
	local root = state.root
	local pos, look = root.Position, root.CFrame.LookVector
	local eaterSpeed = root.AssemblyLinearVelocity.Magnitude
	-- TODO(B20, S4-C6): the first-run mouth factor from the profile (BiteMath.firstRunMouth).
	local firstRun = 1
	-- TODO(B19): species.mouthMult and species.lengthMult once the species data carries them.
	local mouthMult, lengthMult = 1, 1
	-- TODO(B19, S6-C3): TraitService.massMult(slot) (Spots, Bonefed).
	local massMult = 1
	local mask, firstReason = 0, BiteResult.REASON_NONE
	local clock = os.clock()
	for k = 0, count - 1 do
		counters.targets += 1
		local g, i, gen = Bite.readPrey(payload, k)
		local reason = BiteResult.REASON_NONE
		if not RateLimit.allow(eatLimit, player, EAT_BUCKET, clock) then
			reason = BiteResult.REASON_RATE
		else
			local def, preySpeed = PreyService.peek(state.slot, g, i, gen)
			if def == nil then
				reason = BiteResult.REASON_GONE
			elseif not BiteRules.canEatPrey(state.tier, def.tier) then
				reason = BiteResult.REASON_TIER
			else
				-- bodyScale is read per target: an accepted bite earlier in the claim grows the mouth.
				local r = BiteMath.serverRadius(state.bodyScale, mouthMult, firstRun)
				local mx, my, mz = BiteMath.mouth(
					pos.X,
					pos.Y,
					pos.Z,
					look.X,
					look.Y,
					look.Z,
					state.bodyScale,
					lengthMult,
					r
				)
				local px, py, pz = PreyService.memberPosAt(g, i, tc)
				local reach = BiteMath.reach(r, def.radius, def.wobble, eaterSpeed, preySpeed)
				local ok, d = BiteMath.within(mx, my, mz, px, py, pz, reach)
				if not ok then
					reason = BiteResult.REASON_RANGE
					counters.worstRange = math.max(counters.worstRange, d / reach)
					if BiteMath.isFar(d, reach) then
						counters.far += 1
						-- TODO(B14, S8-C2): MovementValidator.flag(slot, 2, "bite_far") (8.9).
					end
					logMiss(player, state.slot, g, i, d, reach)
				elseif not PreyService.tryEat(state.slot, g, i, gen, tc) then
					-- peek and the tier passed, so the group was still fading in at tc.
					reason = BiteResult.REASON_TIME
				else
					local nursery = if inNursery(px, py, pz)
						then BiteMath.nurseryMult(state.tier)
						else 1
					CreatureService.addMass(state.slot, BiteMath.gain(def.mass, massMult, nursery))
					mask = bit32.bor(mask, bit32.lshift(1, k))
					counters.accepted += 1
					-- TODO(B19, S6-C3): TraitService.onTraitPreyEaten for trait prey; TODO(B19):
					-- CodexService.discover and GoalsService.progress; the run's chain and accepted
					-- and rejected counts for the run-end events (8.9). TODO(B32): the Shark Pup's
					-- rampage, 3 prey within 4 s (7.1).
				end
			end
		end
		if reason ~= BiteResult.REASON_NONE then
			reject(reason)
			if firstReason == BiteResult.REASON_NONE then
				firstReason = reason
			end
		end
	end
	-- TODO(B14, S8-C2): more than 20 rejected claims in 60 s flags the run (02 §4.7, 15.5).
	return BiteResult.encode(seq, mask, firstReason, state.mass, state.tier)
end

local function onBite(player: Player, payload: buffer)
	Server.send(player, "BiteResult", BiteService.claim(player, payload))
end

--- A copy of the counters (R5). Rejects over targets is the reject rate to keep under 2%.
function BiteService.counters(): Counters
	local copy = table.clone(counters)
	copy.rejects = table.clone(counters.rejects)
	return copy
end

function BiteService.resetCounters()
	counters = freshCounters()
end

--- Drops `player`'s eat bucket and log throttle (on leave; the engine spec uses it too).
function BiteService.forget(player: Player)
	RateLimit.forget(eatLimit, player)
	loggedAt[player] = nil
end

function BiteService.init()
	counters = freshCounters()
end

function BiteService.start()
	nurseries = WorldIndex.volumesOf("SafeNursery")
	Server.on("Bite", {
		Server.Validate.buffer(Bite.MIN_BYTES, Bite.MAX_BYTES, Bite.accepts, Bite.valid),
	}, onBite)
	Players.PlayerRemoving:Connect(BiteService.forget)
end

return BiteService
