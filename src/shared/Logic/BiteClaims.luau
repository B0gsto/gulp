--!strict
-- BiteClaims: the client's side of the prey bite handshake (task S4-C1; module B17, second part;
-- docs/09, section 8.9; docs/02, sections 4.3, 4.6 and 4.7). Pure, so it runs in Lune.
--
--   Claim     members the mouth reached this frame are `add`ed; each takes one token from the
--             eat bucket and is hidden at once (optimistic, 02 §4.3 T+0.00). `flush` packs them
--             into one `Bite` payload (op 1, `seq`, `claimTimeMs`, (g, i, gen)…, 8 at most; the
--             codec of 8.7) and records it as pending under its `seq`.
--   Bucket    the `Bite` row of 09 §5.3 (12/s, bucket 20; Shared.Net.RateLimit): one token per
--             member claimed, so the client never claims more than the 12 prey eats a second of
--             02 §4.6 the server allows, and a member over the limit is simply not claimed yet
--             (it stays drawn and is tried again next frame).
--   Reconcile `result` (a `BiteResult`: seq, acceptedMask) settles a pending claim: accepted
--             members are handed back to be marked eaten in the mirror, rejected ones are shown
--             again (02 §4.3: the prey fades back in over 0.15 s; 8.9: a "miss" puff).
--             The reason byte covers every rejected target of the claim: `gone` (someone else
--             ate it first) is not a miss, so those members stay gone with no puff and the
--             caller clears their alive bits; every other reason (range, tier, time, rate,
--             state, safe zone, protected) shows them again with the fade and puff.
--   Time-out  a claim the server's Net guard dropped (flooding) gets no `BiteResult` at all, so
--             every claim has a deadline: `timeout(rtt)` = clamp(2 × rtt + 0.25 s, 0.5 s, 2 s)
--             (tune), rtt the measured round trip. Past it the claim counts as rejected (shown
--             again with the fade and puff) and a late result for it is ignored.
--   Hidden    a member stays hidden while its claim is pending. A hide is for one `gen`: when the
--             group ID is reused for a new group, the old hide does not apply.
--
-- Times are the caller's clock in seconds (os.clock on the client).
local Bite = require("../Net/Codec/Bite")
local RateLimit = require("../Net/RateLimit")

export type Target = { groupId: number, member: number, gen: number }

type Pending = { targets: { Target }, deadline: number }

export type Claims = {
	seq: number, -- the next claim's seq, u16
	tokens: number,
	refilled: number, -- clock of the last refill
	rate: number, -- tokens a second
	size: number, -- bucket size
	open: { Target }, -- added this frame, not yet flushed
	pending: { [number]: Pending }, -- by seq
	hidden: { [number]: number }, -- member key → gen
	restoredAt: { [number]: number }, -- member key → clock when shown again after a reject
}

local BiteClaims = {}

--- 8.9: a claim with no `BiteResult` after `timeout(rtt)` is treated as rejected (tune).
BiteClaims.TIMEOUT_MIN = 0.5 -- seconds
BiteClaims.TIMEOUT_MAX = 2.0 -- seconds; also the deadline when no round trip is known
BiteClaims.TIMEOUT_MARGIN = 0.25 -- seconds over twice the round trip (server tick, frame)
--- `BiteResult` reason 1 (Codec/BiteResult).
BiteClaims.REASON_GONE = 1
--- 02 §4.3: a rejected member fades back in over this long.
BiteClaims.FADE_IN = 0.15 -- seconds

--- The time-out for a claim when the measured round trip is `rtt` seconds (nil: unknown).
function BiteClaims.timeout(rtt: number?): number
	if rtt == nil or not (rtt >= 0) then
		return BiteClaims.TIMEOUT_MAX
	end
	return math.clamp(
		2 * rtt + BiteClaims.TIMEOUT_MARGIN,
		BiteClaims.TIMEOUT_MIN,
		BiteClaims.TIMEOUT_MAX
	)
end

local function keyOf(groupId: number, member: number): number
	return groupId * 32 + member
end

--- A claim state with the `Bite` bucket of 09 §5.3 (full at `now`).
function BiteClaims.new(now: number): Claims
	local limit = RateLimit.limitsFromRemotes().Bite
	return {
		seq = 0,
		tokens = limit.size,
		refilled = now,
		rate = limit.rate,
		size = limit.size,
		open = {},
		pending = {},
		hidden = {},
		restoredAt = {},
	}
end

local function refill(c: Claims, now: number)
	local elapsed = now - c.refilled
	if elapsed > 0 then
		c.tokens = math.min(c.size, c.tokens + elapsed * c.rate)
		c.refilled = now
	end
end

--- True when member `member` of group `groupId` at generation `gen` is hidden by a claim.
function BiteClaims.isHidden(c: Claims, groupId: number, member: number, gen: number): boolean
	return c.hidden[keyOf(groupId, member)] == gen
end

--- Members hidden by claims.
function BiteClaims.hiddenCount(c: Claims): number
	local n = 0
	for _ in c.hidden do
		n += 1
	end
	return n
end

--- Adds a member the mouth reached at `now` to this frame's claim and hides it. False, and
--- nothing changes, when it is already hidden, the claim already holds 8 targets, or the eat
--- bucket is empty.
function BiteClaims.add(
	c: Claims,
	groupId: number,
	member: number,
	gen: number,
	now: number
): boolean
	local key = keyOf(groupId, member)
	if c.hidden[key] == gen or #c.open >= Bite.MAX_TARGETS then
		return false
	end
	refill(c, now)
	if c.tokens < 1 then
		return false
	end
	c.tokens -= 1
	c.hidden[key] = gen
	c.restoredAt[key] = nil
	table.insert(c.open, { groupId = groupId, member = member, gen = gen })
	return true
end

--- Packs this frame's targets into one `Bite` payload stamped `claimTimeMs` (the client's
--- server-time estimate at contact, 8.7) and records it as pending at `now`, for `timeout`
--- seconds (`BiteClaims.timeout`; TIMEOUT_MAX when nil). Returns the payload
--- and its seq, or nil when nothing was added.
function BiteClaims.flush(
	c: Claims,
	claimTimeMs: number,
	now: number,
	timeout: number?
): (buffer?, number)
	local open = c.open
	local n = #open
	if n == 0 then
		return nil, -1
	end
	local seq = c.seq
	c.seq = (seq + 1) % 65536
	local b = Bite.encodePrey(seq, claimTimeMs, n)
	for k, t in open do
		Bite.writePrey(b, k - 1, t.groupId, t.member, t.gen)
	end
	c.pending[seq] = { targets = open, deadline = now + (timeout or BiteClaims.TIMEOUT_MAX) }
	c.open = {}
	return b, seq
end

local function show(c: Claims, t: Target, now: number)
	local key = keyOf(t.groupId, t.member)
	if c.hidden[key] == t.gen then
		c.hidden[key] = nil
		c.restoredAt[key] = now
	end
end

--- Settles pending claim `seq` with a `BiteResult`'s `acceptedMask` (bit k = target k accepted)
--- at `now`. Accepted targets are appended to `accepted` (the caller clears their alive bits)
--- and stop being hidden; rejected ones are appended to `gone` when `reason` is REASON_GONE
--- (eaten by someone else: the caller clears them too, no puff), else to `rejected` and shown
--- again with the fade. False when
--- `seq` is not pending (a late or duplicate result).
function BiteClaims.result(
	c: Claims,
	seq: number,
	mask: number,
	reason: number,
	now: number,
	accepted: { Target },
	rejected: { Target },
	gone: { Target }
): boolean
	local p = c.pending[seq]
	if p == nil then
		return false
	end
	c.pending[seq] = nil
	for k, t in p.targets do
		if bit32.btest(mask, bit32.lshift(1, k - 1)) then
			c.hidden[keyOf(t.groupId, t.member)] = nil
			table.insert(accepted, t)
		elseif reason == BiteClaims.REASON_GONE then
			c.hidden[keyOf(t.groupId, t.member)] = nil
			table.insert(gone, t)
		else
			show(c, t, now)
			table.insert(rejected, t)
		end
	end
	return true
end

--- A claim the transport refused to send (`Client.send` returned false): its targets are shown
--- again at once with no puff, and their tokens are not given back.
function BiteClaims.unsent(c: Claims, seq: number)
	local p = c.pending[seq]
	if p == nil then
		return
	end
	c.pending[seq] = nil
	for _, t in p.targets do
		local key = keyOf(t.groupId, t.member)
		if c.hidden[key] == t.gen then
			c.hidden[key] = nil
		end
	end
end

--- Treats every claim past its deadline at `now` as rejected; appends their
--- targets to `rejected`. Returns how many claims expired.
function BiteClaims.expire(c: Claims, now: number, rejected: { Target }): number
	local n = 0
	for seq, p in c.pending do
		if now > p.deadline then
			c.pending[seq] = nil
			n += 1
			for _, t in p.targets do
				show(c, t, now)
				table.insert(rejected, t)
			end
		end
	end
	for key, at in c.restoredAt do
		if now - at > BiteClaims.FADE_IN then
			c.restoredAt[key] = nil
		end
	end
	return n
end

--- 02 §4.3: how visible a member shown again after a reject is at `now`, 0 to 1 (1 when it was
--- never hidden or has finished fading in).
function BiteClaims.fadeIn(c: Claims, groupId: number, member: number, now: number): number
	local at = c.restoredAt[keyOf(groupId, member)]
	if at == nil then
		return 1
	end
	return math.clamp((now - at) / BiteClaims.FADE_IN, 0, 1)
end

--- True when some member is fading in (the renderer skips the per-member check otherwise).
function BiteClaims.fading(c: Claims): boolean
	return next(c.restoredAt) ~= nil
end

--- Claims waiting for their `BiteResult`.
function BiteClaims.pendingCount(c: Claims): number
	local n = 0
	for _ in c.pending do
		n += 1
	end
	return n
end

return table.freeze(BiteClaims)
