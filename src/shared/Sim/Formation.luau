--!strict
--!native
--!optimize 2
-- Formation: where each member of a prey group sits relative to the group (docs/09, section 8.1).
-- Server and client compute identical offsets from (kind, seed, member index), so only group state
-- is ever simulated or sent:
--
--   memberPos(i) = groupPos + rotateY(heading) × offset(kind, seed, i) × (1 + scatter × scatterGain)
--   heading      = atan2(velX, velZ): 0 faces +Z, π/2 faces +X; kept from the last non-zero velocity
--   rotateY(h)   : (ox, oy, oz) → (ox cos h + oz sin h, oy, −ox sin h + oz cos h), so local +Z is
--                  the group's forward
--
-- The offset is a 32-bit integer hash (no trigonometry, no `math.random`), so it is the same in
-- Roblox and in Lune. Member 0 is the group's leader and sits on the group point, so a group of one
-- is exactly where the group is. Every other member lies inside an ellipsoid of horizontal radius
-- `radius(kind)` and half that height (groups of fish are flatter than they are wide):
--
--   radius(kind) = 2 + 1.5 × PreyDef.radius × √groupMax      studs (tune)
--
-- `wobble` is the client's cosmetic shake, at most `PreyDef.wobble` studs (≤ 1.5), which the bite
-- tolerance covers (8.9).
--
-- Kind codes. The group buffers keep one u8 `kind` per group (8.2). data:Prey and data:TraitPrey
-- number their wire indices separately, both from 1, so a trait prey's kind is
-- `TRAIT_BASE + TraitPreyDef.wire`. `kindOf` and `defOf` are the only places that mapping lives.
local Index = require("../Data/Index")
local Types = require("../Types")

type PreyDef = Types.PreyDef

local Formation = {}

--- Kind codes of trait prey start here: kind = TRAIT_BASE + wire.
Formation.TRAIT_BASE = 128
--- The formation's height is this share of its radius.
Formation.FLATTEN = 0.5
--- No client wobble is ever larger than this (8.1).
Formation.WOBBLE_CAP = 1.5

local BASE_RADIUS = 2 -- studs (tune)
local SPACING = 1.5 -- studs per unit of PreyDef.radius per √member (tune)

local defByKind: { [number]: PreyDef } = {}
local kindById: { [string]: number } = {}
-- Per-kind numbers read on the hot path, indexed by kind code; 0 for an unused code.
local radiusOf = table.create(256, 0) :: { number }
local gainOf = table.create(256, 0) :: { number }
local wobbleOf = table.create(256, 0) :: { number }

local function register(def: PreyDef, kind: number)
	if kind < 1 or kind > 255 then
		error(`Formation: {def.id} gets the kind code {kind}, outside 1 to 255`)
	end
	if defByKind[kind] ~= nil then
		error(`Formation: kind code {kind} is used twice`)
	end
	defByKind[kind] = def
	kindById[def.id] = kind
	radiusOf[kind + 1] = BASE_RADIUS + SPACING * def.radius * math.sqrt(def.groupMax)
	gainOf[kind + 1] = def.scatterGain
	wobbleOf[kind + 1] = math.min(def.wobble, Formation.WOBBLE_CAP)
end

for _, def in Index.Prey.list do
	if def.wire >= Formation.TRAIT_BASE then
		error(`Formation: prey {def.id} has wire {def.wire}, which collides with trait prey kinds`)
	end
	register(def, def.wire)
end
for _, def in Index.TraitPrey.list do
	register(def, Formation.TRAIT_BASE + def.wire)
end

--- The kind code of a prey or trait prey ID; nil for an unknown ID.
function Formation.kindOf(id: string): number?
	return kindById[id]
end

--- The PreyDef of a kind code; nil for 0 or an unused code.
function Formation.defOf(kind: number): PreyDef?
	return defByKind[kind]
end

--- Every kind code in use, ascending.
function Formation.kinds(): { number }
	local list = {}
	for kind in defByKind do
		table.insert(list, kind)
	end
	table.sort(list)
	return list
end

--- Horizontal radius of the formation at rest (scatter 0), studs. 0 for an unused code.
function Formation.radius(kind: number): number
	return radiusOf[kind + 1] or 0
end

--- How far full scatter spreads the formation: 1 doubles it.
function Formation.scatterGain(kind: number): number
	return gainOf[kind + 1] or 0
end

--- The largest cosmetic wobble of a member, studs.
function Formation.wobbleCap(kind: number): number
	return wobbleOf[kind + 1] or 0
end

local TWO_32 = 0x100000000

-- (a × b) mod 2^32 for two 32-bit values, in halves so no product passes 2^53.
local function multiply(a: number, b: number): number
	local low = (a % 0x10000) * b
	local high = (a // 0x10000) * b % 0x10000
	return (low + high * 0x10000) % TWO_32
end

-- A 32-bit avalanche of (kind, seed, member, salt) mapped to [0, 1).
local function hash01(kind: number, seed: number, member: number, salt: number): number
	local key = ((kind * 32 + member) * 8 + salt) * 0x10000 + seed % 0x10000
	local z = multiply(bit32.bxor(key, 0x9E3779B9), 0x85EBCA6B)
	z = multiply(bit32.bxor(z, bit32.rshift(z, 13)), 0xC2B2AE35)
	z = bit32.bxor(z, bit32.rshift(z, 16))
	z = multiply(z, 0x27D4EB2F)
	z = bit32.bxor(z, bit32.rshift(z, 15))
	return z / TWO_32
end

--- The local offset of member `member` (0 to 23) in the group's frame, before heading and scatter.
--- Deterministic in (kind, seed, member). Member 0 is (0, 0, 0).
function Formation.offset(kind: number, seed: number, member: number): (number, number, number)
	if member == 0 then
		return 0, 0, 0
	end
	local radius = radiusOf[kind + 1] or 0
	-- A direction from three hashed values in [−1, 1], then a radius that fills the ball evenly.
	local dx = hash01(kind, seed, member, 0) * 2 - 1
	local dy = hash01(kind, seed, member, 1) * 2 - 1
	local dz = hash01(kind, seed, member, 2) * 2 - 1
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	if length < 1e-6 then
		dx, dy, dz, length = 1, 0, 0, 1
	end
	local r = radius * (0.25 + 0.75 * hash01(kind, seed, member, 3) ^ (1 / 3)) / length
	return dx * r, dy * r * Formation.FLATTEN, dz * r
end

--- World position of a member, given the group point, heading (radians) and scatter (0 to 1).
function Formation.memberPos(
	kind: number,
	seed: number,
	member: number,
	gx: number,
	gy: number,
	gz: number,
	heading: number,
	scatter: number
): (number, number, number)
	local ox, oy, oz = Formation.offset(kind, seed, member)
	local spread = 1 + scatter * (gainOf[kind + 1] or 0)
	local c, s = math.cos(heading), math.sin(heading)
	return gx + (ox * c + oz * s) * spread, gy + oy * spread, gz + (oz * c - ox * s) * spread
end

local INV_SQRT3 = 1 / math.sqrt(3)

--- The client's cosmetic shake of a member at time `t` (seconds). Each axis is a sine of amplitude
--- cap/√3 with a hashed phase and rate, so the length never exceeds `wobbleCap(kind)`.
function Formation.wobble(
	kind: number,
	seed: number,
	member: number,
	t: number
): (number, number, number)
	local amplitude = (wobbleOf[kind + 1] or 0) * INV_SQRT3
	if amplitude == 0 then
		return 0, 0, 0
	end
	local tau = 2 * math.pi
	local px, py, pz =
		hash01(kind, seed, member, 4), hash01(kind, seed, member, 5), hash01(kind, seed, member, 6)
	local rate = 0.6 + 0.8 * hash01(kind, seed, member, 7) -- cycles per second (tune)
	return amplitude * math.sin(tau * (rate * t + px)),
		amplitude * math.sin(tau * (rate * 1.3 * t + py)),
		amplitude * math.sin(tau * (rate * 0.8 * t + pz))
end

return table.freeze(Formation)
