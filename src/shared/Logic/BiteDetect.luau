--!strict
--!native
--!optimize 2
-- BiteDetect: the client's local bite test of one prey member against its own mouth, with the
-- gulp assist (task S4-C1; module B17, second part; docs/02, section 4.1; docs/09, section 8.9;
-- docs/15, section 4.3). Pure, so it runs in Lune; Render/PreyRenderer calls it every frame with
-- the mouth of `CreatureController.localMouth()` (the smoothed rig, 09 §6.7) and the drawn
-- (dead-reckoned) member positions.
--
--   Hit     02 §4.1: |mouthCentre − member| ≤ mouthRadius + preyRadius.
--   Assist  02 §4.1 and 15 §4.3: edible prey inside a cone from the nose (the mouth centre minus
--           half a mouth radius along the facing) and within `range × mouthRadius` of the mouth
--           centre is pulled toward the mouth centre at `pull` studs/s. The pull is kept per
--           member as a distance already covered; a member whose remaining gap closes is a hit.
--           A member that leaves the cone or the range loses its pull. Prey only, never players.
--           The set follows the input mode of the moment (15 §4.3): Touch is the drag column.
--
-- Members are keyed `groupId × 32 + member` (24 members at most, 8.7). The pull tables are
-- swapped every frame, so a member not tested this frame is forgotten; nothing allocates once
-- the tables have grown.

export type AssistSet = { cone: number, range: number, pull: number } -- degrees, × mouthRadius, studs/s
export type InputMode = "Touch" | "Keys" | "Pad"

export type State = {
	pull: { [number]: number }, -- studs covered by the assist, this frame
	last: { [number]: number }, -- last frame's
}

local BiteDetect = {}

BiteDetect.NONE = 0
BiteDetect.ASSIST = 1 -- inside the assist cone and range, not yet a hit
BiteDetect.HIT = 2

--- 15 §4.3 (tune), the [MVP] columns: Touch (drag), Pad and Keys. Two-thumb (30°, 2.25, 10) is [L].
BiteDetect.ASSIST_SETS = table.freeze({
	Touch = table.freeze({ cone = 35, range = 2.5, pull = 12 }),
	Pad = table.freeze({ cone = 35, range = 2.5, pull = 12 }),
	Keys = table.freeze({ cone = 22, range = 2.0, pull = 6 }),
} :: { [string]: AssistSet })

--- The assist set for an input mode (15 §4.3); an unknown mode gets the Keys set, the narrowest.
function BiteDetect.assistSet(mode: string): AssistSet
	return BiteDetect.ASSIST_SETS[mode] or BiteDetect.ASSIST_SETS.Keys
end

--- The member key of member `member` of group `groupId`.
function BiteDetect.key(groupId: number, member: number): number
	return groupId * 32 + member
end

function BiteDetect.new(): State
	return { pull = {}, last = {} }
end

--- Starts a frame: this frame's pulls start empty, last frame's are kept to grow from.
function BiteDetect.beginFrame(s: State)
	local last = s.last
	s.last = s.pull
	s.pull = last
	table.clear(last)
end

--- Studs the assist has pulled member `key` toward the mouth (0 when none), as of this frame.
function BiteDetect.pulled(s: State, key: number): number
	return s.pull[key] or 0
end

--- Tests one member of an edible prey kind at (px, py, pz), `preyRadius` studs, against the mouth
--- centred on (mx, my, mz) with radius `r`, facing the unit vector (fx, fy, fz), `dt` seconds
--- after the last frame, with assist set `set` (nil: no assist). Returns HIT, ASSIST or NONE and
--- the remaining gap in studs between the two spheres (≤ 0 for a hit).
function BiteDetect.test(
	s: State,
	key: number,
	dt: number,
	mx: number,
	my: number,
	mz: number,
	r: number,
	fx: number,
	fy: number,
	fz: number,
	px: number,
	py: number,
	pz: number,
	preyRadius: number,
	set: AssistSet?
): (number, number)
	local ax, ay, az = px - mx, py - my, pz - mz
	local d = math.sqrt(ax * ax + ay * ay + az * az)
	local gap = d - (r + preyRadius)
	if gap <= 0 then
		return BiteDetect.HIT, gap
	end
	if set == nil or d > set.range * r then
		return BiteDetect.NONE, gap
	end
	-- The cone's apex is the nose, half a mouth radius behind the mouth centre (02 §4.1).
	local h = 0.5 * r
	local nx, ny, nz = ax + fx * h, ay + fy * h, az + fz * h
	local nd = math.sqrt(nx * nx + ny * ny + nz * nz)
	if nd > 1e-6 and (nx * fx + ny * fy + nz * fz) / nd < math.cos(math.rad(set.cone)) then
		return BiteDetect.NONE, gap
	end
	local covered = (s.last[key] or 0) + set.pull * math.max(dt, 0)
	if covered > gap then
		covered = gap
	end
	s.pull[key] = covered
	gap -= covered
	if gap <= 0 then
		return BiteDetect.HIT, gap
	end
	return BiteDetect.ASSIST, gap
end

return table.freeze(BiteDetect)
