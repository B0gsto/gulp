--!strict
-- MomentQueue: the rules of `HUD.MomentSlot` (docs/08 section 4.1) and the motion of its card
-- (08 §11.3). Pure, so it runs in Lune; `client/UI/Hud/MomentSlot` draws what it says.
--
-- One moment shows at a time. A higher priority moment replaces a lower one at once; up to three
-- wait, best priority first; a waiting moment older than 6 s is dropped, except tier-up and
-- trait gained, which always play (a replaced tier-up or trait goes back to the queue). Each card
-- enters in 180 ms (drops 24 rpx with a fade, Back Out) and leaves in 160 ms (Quad In).
local MomentQueue = {}

export type Kind = "tide" | "tierUp" | "trait" | "eventStart" | "eventEnd" | "eventWarning" | "zone"

-- 08 §4.1: 1 is the highest priority.
MomentQueue.PRIORITY = table.freeze({
	tide = 1,
	tierUp = 2,
	trait = 3,
	eventStart = 4,
	eventEnd = 5,
	eventWarning = 6,
	zone = 7,
} :: { [Kind]: number })

-- 08 §4.1 hold times, s. The event end's "then next event" is a second moment of its own.
MomentQueue.HOLD = table.freeze({
	tide = 10,
	tierUp = 1.4,
	tierUpTop = 2.2, -- tier 7
	trait = 2,
	traitRare = 3, -- Epic and Mythic
	eventStart = 2,
	eventEnd = 2,
	eventWarning = 5,
	zone = 1.5,
})

MomentQueue.WAIT_MAX = 3
MomentQueue.STALE = 6
-- 08 §11.3, moment slot card.
MomentQueue.ENTER = 0.18
MomentQueue.LEAVE = 0.16
MomentQueue.DROP = 24
-- `UI_Common_Rays` turns behind the tier 7 badge and Epic and Mythic traits (08 §4.2, §4.3). The
-- bible gives no speed: one turn in 8 s (tune; docs/14 section 4, row 28).
MomentQueue.RAYS_TURN = 45 -- degrees a second

export type Moment = {
	kind: Kind,
	hold: number, -- s on screen between the enter and the leave
	at: number, -- clock when it was pushed
	data: any,
}

export type Queue = {
	current: Moment?,
	startedAt: number, -- clock when `current` began to enter
	waiting: { Moment },
}

--- The hold of a tier-up to `tier` (08 §4.1: 1,400 ms; tier 7: 2,200 ms).
function MomentQueue.tierUpHold(tier: number, top: number): number
	return if tier >= top then MomentQueue.HOLD.tierUpTop else MomentQueue.HOLD.tierUp
end

--- The hold of a trait gained of `rarity` (08 §4.1: 2,000 ms; Epic and Mythic: 3,000 ms).
function MomentQueue.traitHold(rarity: string?): number
	return if rarity == "Epic" or rarity == "Mythic"
		then MomentQueue.HOLD.traitRare
		else MomentQueue.HOLD.trait
end

--- True for the moments that always play (08 §4.1).
function MomentQueue.keeps(kind: Kind): boolean
	return kind == "tierUp" or kind == "trait"
end

function MomentQueue.new(): Queue
	return { current = nil, startedAt = 0, waiting = {} }
end

--- The clock at which `q.current` has fully left.
function MomentQueue.endsAt(q: Queue): number
	local m = q.current
	if m == nil then
		return -math.huge
	end
	return q.startedAt + MomentQueue.ENTER + m.hold + MomentQueue.LEAVE
end

-- Puts `m` among the waiting moments: by priority, then by arrival. Over three, the
-- worst-placed moment that may be dropped goes.
local function enqueue(q: Queue, m: Moment)
	local p = MomentQueue.PRIORITY[m.kind]
	local index = #q.waiting + 1
	for i, w in q.waiting do
		if MomentQueue.PRIORITY[w.kind] > p then
			index = i
			break
		end
	end
	table.insert(q.waiting, index, m)
	if #q.waiting > MomentQueue.WAIT_MAX then
		for i = #q.waiting, 1, -1 do
			if not MomentQueue.keeps(q.waiting[i].kind) then
				table.remove(q.waiting, i)
				break
			end
		end
	end
end

--- Adds a moment at clock `now`. Returns the moment it replaced at once, if any (the caller
--- takes that card off the screen); a replaced tier-up or trait goes back to the queue.
function MomentQueue.push(q: Queue, kind: Kind, hold: number, data: any, now: number): Moment?
	local m: Moment = { kind = kind, hold = hold, at = now, data = data }
	local current = q.current
	if current == nil then
		q.current = m
		q.startedAt = now
		return nil
	end
	if MomentQueue.PRIORITY[kind] < MomentQueue.PRIORITY[current.kind] then
		q.current = m
		q.startedAt = now
		if MomentQueue.keeps(current.kind) then
			enqueue(q, { kind = current.kind, hold = current.hold, at = now, data = current.data })
		end
		return current
	end
	enqueue(q, m)
	return nil
end

--- Advances the queue to clock `now`. Returns the moment that finished (if any) and the moment
--- that starts now (if any). Stale moments are dropped when the next one is picked.
function MomentQueue.step(q: Queue, now: number): (Moment?, Moment?)
	local current = q.current
	if current == nil or now < MomentQueue.endsAt(q) then
		return nil, nil
	end
	local finished = current
	local endedAt = MomentQueue.endsAt(q)
	q.current = nil
	while #q.waiting > 0 do
		local nextMoment = table.remove(q.waiting, 1) :: Moment
		if MomentQueue.keeps(nextMoment.kind) or now - nextMoment.at <= MomentQueue.STALE then
			q.current = nextMoment
			-- The next card starts where the last one left, not later than now.
			q.startedAt = math.min(now, math.max(endedAt, nextMoment.at))
			break
		end
	end
	return finished, q.current
end

export type Pose = {
	phase: "enter" | "hold" | "leave" | "gone",
	alpha: number, -- 0 invisible, 1 fully shown
	dy: number, -- rpx above the resting place (the enter drops from -24 to 0)
	t: number, -- s since the card began to enter
}

-- Back Out, as Roblox's `EasingStyle.Back` (overshoot 1.70158).
local function backOut(x: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

--- The card's pose `t` s after it began to enter, for a hold of `hold` s (08 §11.3).
function MomentQueue.pose(t: number, hold: number): Pose
	local enter, leave = MomentQueue.ENTER, MomentQueue.LEAVE
	if t < 0 then
		return { phase = "enter", alpha = 0, dy = -MomentQueue.DROP, t = t }
	elseif t < enter then
		local x = t / enter
		return {
			phase = "enter",
			alpha = math.clamp(x, 0, 1),
			dy = -MomentQueue.DROP * (1 - backOut(x)),
			t = t,
		}
	elseif t < enter + hold then
		return { phase = "hold", alpha = 1, dy = 0, t = t }
	elseif t < enter + hold + leave then
		local x = (t - enter - hold) / leave
		return { phase = "leave", alpha = 1 - x * x, dy = 0, t = t }
	end
	return { phase = "gone", alpha = 0, dy = 0, t = t }
end

--- Scale of a pop that starts `delay` s into the card (08 §11.3 number pop: 120 ms to 1.15, then
--- 120 ms back, Back Out), 0 before it starts.
function MomentQueue.popScale(t: number, delay: number): number
	local x = t - delay
	if x < 0 then
		return 0
	elseif x < 0.12 then
		return 1.15 * backOut(x / 0.12)
	elseif x < 0.24 then
		return 1.15 - 0.15 * backOut((x - 0.12) / 0.12)
	end
	return 1
end

return table.freeze(MomentQueue)
