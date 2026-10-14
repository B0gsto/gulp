--!strict
-- Hud/MomentArt (task S6-C5): code-drawn stand-ins for the images on the S07 and S08 cards
-- (docs/08 sections 4.2, 4.3 and 13), in the Kit's style (06 §12.4: flat fill, navy outline, one
-- white highlight): the `UI_Common_Ribbon` tails, the `UI_Common_Rays` burst, a glyph for each
-- [MVP] trait (`UI_Icon_Trait{Name}`) and a silhouette for each [MVP] prey
-- (`UI_Icon_Prey{Name}`). Each glyph carries the empty image slot named after its 08 §13 image,
-- so the interface art of Sprint 10 drops in without layout changes (Kit/Draw). Colours are the
-- signature and Mid colours of 06 §4.3 and §8.2.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)

local Draw = require("../Kit/Draw")
local Icons = require("../Kit/Icons")
local Theme = require("../Kit/Theme")

local MomentArt = {}

local hex = Color3.fromHex

-- `zebra_darter` → `ZebraDarter` (08 §13.1 asset names).
local function pascal(id: string): string
	local parts: { string } = {}
	for _, word in string.split(id, "_") do
		table.insert(parts, string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2))
	end
	return table.concat(parts)
end

local function rect(parent: Instance, r: HudLayout.Rect, props: Draw.Props?): Frame
	local f = Draw.new("Frame", {
		Position = UDim2.fromOffset(r.x, r.y),
		Size = UDim2.fromOffset(r.width, r.height),
		Parent = parent,
	}) :: Frame
	if props then
		for k, v in pairs(props) do
			(f :: any)[k] = v
		end
	end
	return f
end

-- A canvas of `s` rpx: parts are placed in shares of it (0 to 1), from z up. `line` is the
-- navy outline in rpx.
type Canvas = { root: Frame, s: number, z: number, line: number }
type Part = {
	x: number,
	y: number,
	w: number,
	h: number,
	colour: Color3,
	rot: number?,
	radius: number?, -- share of `s`; nil for a pill or disc
	square: boolean?, -- no rounding at all
	alpha: number?,
	stroke: Color3?, -- an own outline (not merged with its neighbours)
	strokeWidth: number?,
	dz: number?,
}

local function canvas(parent: Instance, s: number, z: number, line: number): Canvas
	local root = Draw.new("Frame", {
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(s, s),
		ZIndex = z,
		Parent = parent,
	}) :: Frame
	return { root = root, s = s, z = z, line = line }
end

local function put(c: Canvas, p: Part, grow: number?, colour: Color3?, dz: number?): Frame
	local g = grow or 0
	local f = Draw.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(p.x * c.s, p.y * c.s),
		Size = UDim2.fromOffset(p.w * c.s + 2 * g, p.h * c.s + 2 * g),
		Rotation = p.rot or 0,
		BackgroundColor3 = colour or p.colour,
		BackgroundTransparency = p.alpha or 0,
		ZIndex = c.z + (dz or p.dz or 0),
		Parent = c.root,
	}) :: Frame
	if not p.square then
		Draw.corner(if p.radius then p.radius * c.s + g else nil).Parent = f
	end
	if p.stroke and grow == nil then
		Draw.stroke(p.strokeWidth or c.line, p.stroke).Parent = f
	end
	return f
end

-- One shape made of `parts`: a navy copy of each, `line` larger, under all the fills, so the
-- union has one outline and no seams (06 §12.2).
local function shape(c: Canvas, parts: { Part }, dz: number)
	for _, p in parts do
		put(c, p, c.line, Theme.INK, dz)
	end
	for _, p in parts do
		put(c, p, nil, nil, dz + 1)
	end
end

local function highlight(c: Canvas, x: number, y: number, d: number, dz: number)
	put(c, { x = x, y = y, w = d, h = d, colour = Theme.WHITE, alpha = 0.15, dz = dz })
end

-- Spines around a body: `n` diamonds pointing out, with tips in `tip`.
local function spines(
	n: number,
	x: number,
	y: number,
	reach: number,
	size: number,
	body: Color3,
	tip: Color3
): ({ Part }, { Part })
	local out: { Part } = {}
	local tips: { Part } = {}
	for i = 1, n do
		local a = (i - 1) * 2 * math.pi / n - math.pi / 2
		local deg = math.deg(a) + 45
		table.insert(out, {
			x = x + math.cos(a) * reach,
			y = y + math.sin(a) * reach,
			w = size,
			h = size,
			colour = body,
			rot = deg,
			radius = size * 0.12,
		})
		table.insert(tips, {
			x = x + math.cos(a) * (reach + size * 0.32),
			y = y + math.sin(a) * (reach + size * 0.32),
			w = size * 0.42,
			h = size * 0.42,
			colour = tip,
			rot = deg,
			radius = size * 0.05,
		})
	end
	return out, tips
end

--------------------------------------------------------------------------------------------------
-- Trait glyphs (`UI_Icon_Trait{Name}`, 08 §13.4), drawn on the cream inset of the rarity frame.
--------------------------------------------------------------------------------------------------

local TRAIT: { [string]: (c: Canvas) -> () } = {}

-- Glow (06 §8.2 `#FFE98A`): a lit lure with a bold four-point sparkle and a halo, one outlined
-- shape so it holds up at phone size.
TRAIT.glow = function(c)
	local glow, spark = hex("#FFE98A"), hex("#FFD23D")
	put(c, { x = 0.5, y = 0.5, w = 0.98, h = 0.98, colour = glow, alpha = 0.55 })
	shape(c, {
		{ x = 0.5, y = 0.5, w = 0.9, h = 0.17, colour = spark },
		{ x = 0.5, y = 0.5, w = 0.17, h = 0.9, colour = spark },
		{ x = 0.5, y = 0.5, w = 0.66, h = 0.14, colour = spark, rot = 45 },
		{ x = 0.5, y = 0.5, w = 0.66, h = 0.14, colour = spark, rot = -45 },
	}, 1)
	shape(c, { { x = 0.5, y = 0.5, w = 0.48, h = 0.48, colour = glow } }, 3)
	put(c, { x = 0.5, y = 0.5, w = 0.26, h = 0.26, colour = Theme.WHITE, alpha = 0.2, dz = 5 })
	highlight(c, 0.41, 0.39, 0.12, 6)
end

-- Stripes (`#1E2A4A` on `#FFFFFF`): a white fish with three bold bands.
TRAIT.stripes = function(c)
	local navy = hex("#1E2A4A")
	shape(c, {
		{ x = 0.15, y = 0.38, w = 0.24, h = 0.13, colour = Theme.WHITE, rot = -35 },
		{ x = 0.15, y = 0.62, w = 0.24, h = 0.13, colour = Theme.WHITE, rot = 35 },
		{ x = 0.55, y = 0.5, w = 0.74, h = 0.5, colour = Theme.WHITE },
	}, 0)
	for _, b in { { 0.41, 0.42 }, { 0.54, 0.48 }, { 0.67, 0.44 } } do
		put(c, { x = b[1], y = 0.5, w = 0.08, h = b[2], colour = navy, radius = 0.03, dz = 2 })
	end
	put(c, { x = 0.8, y = 0.44, w = 0.07, h = 0.07, colour = navy, dz = 3 })
	highlight(c, 0.5, 0.33, 0.1, 3)
end

-- Spots (`#FFF3D1` dots ringed `#3A2A4A`): a round aqua body with five ringed dots.
TRAIT.spots = function(c)
	local ring = hex("#3A2A4A")
	shape(c, { { x = 0.5, y = 0.5, w = 0.86, h = 0.86, colour = Theme.SECONDARY } }, 0)
	for _, d in
		{
			{ 0.34, 0.36, 0.22 },
			{ 0.63, 0.3, 0.17 },
			{ 0.68, 0.6, 0.24 },
			{ 0.4, 0.66, 0.18 },
			{ 0.5, 0.49, 0.12 },
		}
	do
		put(c, {
			x = d[1],
			y = d[2],
			w = d[3],
			h = d[3],
			colour = hex("#FFF3D1"),
			stroke = ring,
			strokeWidth = c.line * 0.9,
			dz = 2,
		})
	end
	highlight(c, 0.28, 0.24, 0.1, 3)
end

-- Plated (`#B8C4CC`, edge `#6B7A85`): a shield of overlapping plates.
TRAIT.plated = function(c)
	local plate, edge = hex("#B8C4CC"), hex("#6B7A85")
	shape(c, {
		{ x = 0.5, y = 0.36, w = 0.74, h = 0.44, colour = plate, radius = 0.1 },
		{ x = 0.5, y = 0.56, w = 0.52, h = 0.52, colour = plate, rot = 45, radius = 0.08 },
	}, 0)
	for i, y in { 0.42, 0.6 } do
		put(c, {
			x = 0.5,
			y = y,
			w = if i == 1 then 0.6 else 0.4,
			h = 0.06,
			colour = edge,
			dz = 2,
		})
	end
	put(c, { x = 0.5, y = 0.5, w = 0.06, h = 0.5, colour = edge, dz = 2 })
	highlight(c, 0.3, 0.26, 0.11, 3)
end

-- Spiny (`#F2E6C9`, tips `#C2491D`): a round body bristling with eight spines.
TRAIT.spiny = function(c)
	local body, tip = hex("#F2E6C9"), hex("#C2491D")
	local out, tips = spines(8, 0.5, 0.5, 0.3, 0.2, body, tip)
	shape(c, out, 0)
	for _, t in tips do
		put(c, t, nil, nil, 2)
	end
	shape(c, { { x = 0.5, y = 0.5, w = 0.56, h = 0.56, colour = body } }, 3)
	put(c, { x = 0.58, y = 0.46, w = 0.08, h = 0.08, colour = Theme.INK, dz = 5 })
	highlight(c, 0.4, 0.36, 0.11, 5)
end

-- Longfin (species accent fading to `#FFFFFF`): a long flowing tail fin.
TRAIT.longfin = function(c)
	local fins: { Part } = {}
	for i, rot in { -28, 0, 28 } do
		table.insert(fins, {
			x = 0.42 + math.cos(math.rad(rot)) * 0.16,
			y = 0.5 + math.sin(math.rad(rot)) * 0.16,
			w = if i == 2 then 0.66 else 0.58,
			h = 0.16,
			colour = Theme.SECONDARY,
			rot = rot,
		})
	end
	shape(c, fins, 0)
	for _, f in fins do
		local over = put(c, f, nil, Theme.WHITE, 2)
		Draw.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.45, 1),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Parent = over,
		})
	end
	shape(c, { { x = 0.24, y = 0.5, w = 0.26, h = 0.26, colour = Theme.SECONDARY_SHADE } }, 3)
	highlight(c, 0.2, 0.45, 0.07, 5)
end

-- Ink (`#2A1F3D`): a cloud of ink.
TRAIT.ink = function(c)
	local ink = hex("#2A1F3D")
	shape(c, {
		{ x = 0.36, y = 0.6, w = 0.44, h = 0.44, colour = ink },
		{ x = 0.62, y = 0.62, w = 0.38, h = 0.38, colour = ink },
		{ x = 0.5, y = 0.38, w = 0.36, h = 0.36, colour = ink },
		{ x = 0.72, y = 0.34, w = 0.2, h = 0.2, colour = ink },
	}, 0)
	put(c, { x = 0.24, y = 0.24, w = 0.12, h = 0.12, colour = ink, dz = 2 })
	highlight(c, 0.44, 0.32, 0.1, 3)
	highlight(c, 0.3, 0.54, 0.08, 3)
end

-- Crystal (`#FF9BE6`, `#9BD6FF`, `#FFFFFF`): a cluster of three shards.
TRAIT.crystal = function(c)
	local shards: { Part } = {
		{ x = 0.3, y = 0.58, w = 0.22, h = 0.5, colour = hex("#9BD6FF"), rot = -24, radius = 0.05 },
		{ x = 0.7, y = 0.58, w = 0.22, h = 0.5, colour = hex("#FF9BE6"), rot = 24, radius = 0.05 },
		{ x = 0.5, y = 0.46, w = 0.26, h = 0.72, colour = Theme.WHITE, radius = 0.06 },
	}
	shape(c, { shards[1], shards[2] }, 0)
	shape(c, { shards[3] }, 2)
	put(c, { x = 0.5, y = 0.48, w = 0.13, h = 0.6, colour = hex("#FF9BE6"), dz = 4 })
	put(c, { x = 0.44, y = 0.3, w = 0.07, h = 0.22, colour = Theme.WHITE, dz = 5 })
	highlight(c, 0.26, 0.48, 0.07, 4)
end

-- Moonlit (`#D9D6FF`, glow `#7DF9FF`): a full moon in a cyan halo.
TRAIT.moonlit = function(c)
	local moon, glow = hex("#D9D6FF"), hex("#7DF9FF")
	put(c, { x = 0.5, y = 0.5, w = 0.96, h = 0.96, colour = glow, alpha = 0.6 })
	shape(c, { { x = 0.5, y = 0.5, w = 0.68, h = 0.68, colour = moon } }, 1)
	for _, d in { { 0.6, 0.6, 0.18 }, { 0.38, 0.62, 0.1 }, { 0.62, 0.36, 0.1 } } do
		put(c, { x = d[1], y = d[2], w = d[3], h = d[3], colour = hex("#B4AEF2"), dz = 3 })
	end
	highlight(c, 0.38, 0.36, 0.12, 4)
end

--- `UI_Icon_Trait{Name}` drawn `size` rpx inside `parent` (centred), from ZIndex `zIndex` up.
--- Traits with no glyph yet ([L] ones) fall back to Kit/Icons' disc.
function MomentArt.trait(traitId: string, size: number, parent: Instance, zIndex: number): GuiObject
	local draw = TRAIT[traitId]
	if draw == nil then
		return Icons.trait(traitId, size, parent, nil, zIndex)
	end
	-- 4 rpx at the 56 rpx S08 size: about 2.4 px on a phone (06 §12.2's icon weight).
	local c = canvas(parent, size, zIndex, math.max(3, size * 0.075))
	c.root.Name = "Trait"
	draw(c)
	Draw.slot(`UI_Icon_Trait{pascal(traitId)}`, c.root, zIndex + 8)
	return c.root
end

--------------------------------------------------------------------------------------------------
-- Prey silhouettes (`UI_Icon_Prey{Name}`, 08 §13.4), facing right.
--------------------------------------------------------------------------------------------------

type Fish = {
	body: Color3,
	back: Color3?,
	len: number,
	depth: number,
	bands: Color3?,
	dots: boolean?,
	halo: Color3?,
	rim: Color3?,
	fin: Color3?,
}

-- A fish at icon size: body, V tail and a big eye, plus one mark (bands, dots, a halo or a rim)
-- and a two-tone back; nothing finer than a phone can show.
local function fish(c: Canvas, f: Fish)
	local x0 = 0.54 - f.len / 2 -- tail end of the body
	if f.halo then
		put(c, { x = 0.5, y = 0.5, w = 0.96, h = 0.96, colour = f.halo, alpha = 0.45 })
	end
	local tail = f.back or f.body
	local parts: { Part } = {
		{ x = x0 - 0.02, y = 0.39, w = 0.26, h = 0.16, colour = tail, rot = -38 },
		{ x = x0 - 0.02, y = 0.61, w = 0.26, h = 0.16, colour = tail, rot = 38 },
		{ x = 0.54, y = 0.5, w = f.len, h = f.depth, colour = f.body },
	}
	if f.fin then
		table.insert(parts, 1, {
			x = 0.5,
			y = 0.5 - f.depth / 2,
			w = 0.24,
			h = 0.16,
			colour = f.fin,
			rot = -12,
		})
	end
	shape(c, parts, 1)
	if f.rim then
		put(c, {
			x = 0.54,
			y = 0.5,
			w = f.len,
			h = f.depth,
			colour = f.body,
			stroke = f.rim,
			strokeWidth = c.line,
			alpha = 1,
			dz = 3,
		})
	end
	local back = f.back
	if back then
		put(c, {
			x = 0.52,
			y = 0.5 - f.depth * 0.2,
			w = f.len * 0.7,
			h = f.depth * 0.32,
			colour = back,
			dz = 3,
		})
	end
	local bands = f.bands
	if bands then
		for i = -1, 1, 2 do
			put(c, {
				x = 0.5 + i * f.len * 0.14,
				y = 0.5,
				w = 0.11,
				h = f.depth * 0.86,
				colour = bands,
				radius = 0.03,
				dz = 3,
			})
		end
	end
	if f.dots then
		put(c, {
			x = 0.48,
			y = 0.52,
			w = 0.17,
			h = 0.17,
			colour = hex("#FFF3D1"),
			stroke = hex("#3A2A4A"),
			strokeWidth = c.line * 0.8,
			dz = 3,
		})
	end
	local front = 0.54 + f.len / 2
	put(c, { x = front - 0.11, y = 0.46, w = 0.12, h = 0.12, colour = Theme.INK, dz = 4 })
end

-- A curled crustacean at icon size: three segments on an arc, a tail fan, two thick feelers and
-- a big eye.
local function crustacean(c: Canvas, body: Color3, edge: Color3?)
	for i = 1, 2 do
		put(c, {
			x = 0.8,
			y = 0.22 + i * 0.07,
			w = 0.34,
			h = 0.06,
			colour = Theme.INK,
			rot = -30 - i * 12,
			dz = 0,
		})
	end
	shape(c, {
		{ x = 0.2, y = 0.76, w = 0.22, h = 0.22, colour = body, rot = 45, radius = 0.05 },
		{ x = 0.62, y = 0.42, w = 0.38, h = 0.38, colour = body },
		{ x = 0.44, y = 0.55, w = 0.32, h = 0.32, colour = body },
		{ x = 0.3, y = 0.67, w = 0.24, h = 0.24, colour = body },
	}, 1)
	if edge then
		put(c, {
			x = 0.5,
			y = 0.5,
			w = 0.06,
			h = 0.3,
			colour = edge,
			rot = 40,
			dz = 3,
		})
	end
	put(c, { x = 0.7, y = 0.36, w = 0.12, h = 0.12, colour = Theme.INK, dz = 4 })
end

local PREY: { [string]: (c: Canvas) -> () } = {
	plankton = function(c)
		local mote = hex("#D9FFE8")
		for _, d in { { 0.36, 0.4, 0.3 }, { 0.64, 0.46, 0.24 }, { 0.46, 0.68, 0.2 } } do
			put(
				c,
				{ x = d[1], y = d[2], w = d[3] * 1.6, h = d[3] * 1.6, colour = mote, alpha = 0.6 }
			)
			shape(c, { { x = d[1], y = d[2], w = d[3], h = d[3], colour = mote } }, 1)
		end
	end,
	krill = function(c)
		crustacean(c, hex("#FF8C7A"))
	end,
	shrimp = function(c)
		crustacean(c, hex("#FFB48A"), hex("#C2693D"))
	end,
	armor_shrimp = function(c)
		crustacean(c, hex("#B8C4CC"), hex("#6B7A85"))
	end,
	sardine = function(c)
		fish(c, { body = hex("#BFD9E8"), back = hex("#5C9AD9"), len = 0.62, depth = 0.26 })
	end,
	darter = function(c)
		fish(c, {
			body = hex("#FFD23D"),
			back = hex("#2F7F8C"),
			fin = hex("#FF7A5C"),
			len = 0.56,
			depth = 0.32,
		})
	end,
	mackerel = function(c)
		fish(c, {
			body = hex("#2FA89A"),
			back = hex("#16574F"),
			bands = hex("#16574F"),
			len = 0.66,
			depth = 0.28,
		})
	end,
	bonito = function(c)
		fish(c, { body = hex("#6F8FD9"), back = hex("#23366B"), len = 0.64, depth = 0.36 })
	end,
	tuna = function(c)
		fish(c, {
			body = hex("#4F6FD0"),
			back = hex("#162657"),
			len = 0.68,
			depth = 0.42,
		})
	end,
	glowfry = function(c)
		fish(c, { body = hex("#FFE98A"), halo = hex("#FFE98A"), len = 0.46, depth = 0.3 })
	end,
	zebra_darter = function(c)
		fish(c, { body = Theme.WHITE, bands = hex("#1E2A4A"), len = 0.56, depth = 0.34 })
	end,
	dotted_goby = function(c)
		fish(c, { body = hex("#FFB48A"), dots = true, len = 0.52, depth = 0.36 })
	end,
	lunar_fry = function(c)
		fish(c, {
			body = hex("#D9D6FF"),
			halo = hex("#7DF9FF"),
			rim = hex("#7DF9FF"),
			len = 0.46,
			depth = 0.3,
		})
	end,
	urchin_puff = function(c)
		local body, tip = hex("#F2E6C9"), hex("#C2491D")
		local out, tips = spines(8, 0.5, 0.52, 0.26, 0.2, body, tip)
		shape(c, out, 0)
		for _, t in tips do
			put(c, t, nil, nil, 2)
		end
		shape(c, { { x = 0.5, y = 0.52, w = 0.56, h = 0.52, colour = hex("#FFE08A") } }, 3)
		put(c, { x = 0.64, y = 0.46, w = 0.09, h = 0.09, colour = Theme.INK, dz = 5 })
		highlight(c, 0.4, 0.4, 0.1, 5)
	end,
	ribbonfish = function(c)
		local body = hex("#BFE9F0")
		shape(c, {
			{ x = 0.24, y = 0.6, w = 0.3, h = 0.14, colour = body, rot = -24 },
			{ x = 0.47, y = 0.5, w = 0.3, h = 0.16, colour = body, rot = 14 },
			{ x = 0.7, y = 0.52, w = 0.3, h = 0.18, colour = body, rot = -10 },
		}, 1)
		put(c, { x = 0.48, y = 0.43, w = 0.5, h = 0.05, colour = Theme.SECONDARY, rot = 6, dz = 3 })
		put(c, { x = 0.78, y = 0.5, w = 0.07, h = 0.07, colour = Theme.INK, dz = 4 })
	end,
	inklet = function(c)
		local body = hex("#FF6FA3")
		local parts: { Part } = {
			{ x = 0.56, y = 0.38, w = 0.4, h = 0.46, colour = body, radius = 0.18 },
		}
		for i = -1, 1 do
			table.insert(parts, {
				x = 0.56 + i * 0.12,
				y = 0.68,
				w = 0.08,
				h = 0.28,
				colour = body,
				rot = i * 14,
			})
		end
		shape(c, parts, 1)
		put(c, { x = 0.22, y = 0.62, w = 0.22, h = 0.22, colour = hex("#2A1F3D"), dz = 1 })
		put(c, { x = 0.5, y = 0.42, w = 0.07, h = 0.07, colour = Theme.INK, dz = 4 })
		put(c, { x = 0.64, y = 0.42, w = 0.07, h = 0.07, colour = Theme.INK, dz = 4 })
		highlight(c, 0.5, 0.26, 0.08, 4)
	end,
	crystal_jelly = function(c)
		local bell = hex("#FF9BE6")
		for i = -1, 1 do
			put(c, {
				x = 0.5 + i * 0.13,
				y = 0.66,
				w = 0.05,
				h = 0.34,
				colour = hex("#9BD6FF"),
				rot = i * 8,
				dz = 0,
			})
		end
		shape(c, { { x = 0.5, y = 0.42, w = 0.6, h = 0.42, colour = bell, radius = 0.2 } }, 1)
		put(c, { x = 0.5, y = 0.54, w = 0.5, h = 0.08, colour = hex("#9BD6FF"), dz = 3 })
		highlight(c, 0.38, 0.34, 0.1, 4)
	end,
}

local function genericFish(c: Canvas)
	fish(c, { body = hex("#E6EEF5"), back = hex("#8FA9C4"), len = 0.6, depth = 0.32 })
end

--- `UI_Icon_Prey{Name}` in an edible-colour ring (08 §4.2), `size` rpx, inside `parent`.
function MomentArt.prey(preyId: string, size: number, parent: Instance, zIndex: number): Frame
	local holder = Draw.new("Frame", {
		Name = "Prey",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		ZIndex = zIndex,
		Parent = parent,
	}) :: Frame
	-- Navy rim, lime ring, deep-water face: the edible outline of 08 §3.11 read on cream.
	local ring = math.max(3, size * 0.09)
	Draw.disc(size + 3, Theme.INK, nil, { ZIndex = zIndex, Parent = holder })
	local face = Draw.disc(
		size - 2 * ring,
		Theme.INK:Lerp(Theme.SECONDARY_SHADE, 0.45),
		nil,
		{ Name = "Ring", ZIndex = zIndex + 1, Parent = holder }
	)
	Draw.stroke(ring, Theme.EDIBLE).Parent = face
	local c = canvas(holder, (size - 2 * ring) * 0.96, zIndex + 2, math.max(2, size * 0.08))
	local draw = PREY[preyId] or genericFish
	draw(c)
	Draw.slot(`UI_Icon_Prey{pascal(preyId)}`, holder, zIndex + 8)
	return holder
end

--------------------------------------------------------------------------------------------------
-- `UI_Common_Ribbon` tails and `UI_Common_Rays`.
--------------------------------------------------------------------------------------------------

-- The side of the line p1 → p2 that holds `towards`, inside the clip rect `clip` of `parent`,
-- filled with `colour`. `shift` moves the line away from `towards`. Rotated children clip inside
-- an unrotated frame, so a big turned square makes a straight cut.
local function halfPlane(
	parent: Instance,
	clip: HudLayout.Rect,
	p1: Vector2,
	p2: Vector2,
	towards: Vector2,
	shift: number,
	colour: Color3,
	z: number
)
	local box = rect(parent, clip, { ClipsDescendants = true, ZIndex = z })
	local dir = (p2 - p1).Unit
	local n = Vector2.new(-dir.Y, dir.X)
	local mid = (p1 + p2) / 2
	if (towards - mid):Dot(n) < 0 then
		n = -n
	end
	local side = 4 * math.max(clip.width, clip.height) + 4 * shift
	local centre = mid - n * shift + n * side / 2 - Vector2.new(clip.x, clip.y)
	Draw.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(centre.X, centre.Y),
		Size = UDim2.fromOffset(side, side),
		Rotation = math.deg(math.atan2(dir.Y, dir.X)),
		BackgroundColor3 = colour,
		BackgroundTransparency = 0,
		ZIndex = z,
		Parent = box,
	})
end

--- One ribbon tail in card-local rect `r`, with a V notch `notch` deep cut into its outer end
--- (`left`: the outer end is at the left); the band covers it from `shown` rpx in from that end.
--- Navy outline `line` rpx, from ZIndex `z` up.
function MomentArt.tail(
	parent: Instance,
	r: HudLayout.Rect,
	left: boolean,
	notch: number,
	shown: number,
	colour: Color3,
	line: number,
	z: number
): Frame
	local holder = rect(parent, r, { Name = if left then "TailLeft" else "TailRight", ZIndex = z })
	local w, h, t = r.width, r.height, line
	-- Built with the outer end at x = 0, then mirrored for the right tail.
	local function X(x: number): number
		return if left then x else w - x
	end
	local function span(x0: number, x1: number, y0: number, y1: number): HudLayout.Rect
		local a, b = X(x0), X(x1)
		return { x = math.min(a, b), y = y0, width = math.abs(b - a), height = y1 - y0 }
	end
	local function pt(x: number, y: number): Vector2
		return Vector2.new(X(x), y)
	end
	for pass = 1, 2 do
		local ink = pass == 1
		local g = if ink then t else 0
		local c = if ink then Theme.INK else colour
		local zz = z + pass - 1
		rect(holder, span(notch, w + g, -g, h + g), {
			BackgroundColor3 = c,
			BackgroundTransparency = 0,
			ZIndex = zz,
		})
		halfPlane(
			holder,
			span(-g, notch, -g, h / 2),
			pt(0, 0),
			pt(notch, h / 2),
			pt(notch, 0),
			g,
			c,
			zz
		)
		halfPlane(
			holder,
			span(-g, notch, h / 2, h + g),
			pt(0, h),
			pt(notch, h / 2),
			pt(notch, h),
			g,
			c,
			zz
		)
	end
	-- The fold: a darker strip where the tail turns under the band.
	rect(holder, span(shown - 8, shown, 0, h), {
		BackgroundColor3 = colour:Lerp(Theme.INK, 0.25),
		BackgroundTransparency = 0,
		ZIndex = z + 2,
	})
	return holder
end

-- `UI_Common_Rays`: 16 wedges, light and dark in turn.
local RAY_WEDGES = 16
-- A hard step at the middle of a UIGradient: transparent before, opaque after.
local CUT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 1),
	NumberSequenceKeypoint.new(0.501, 0),
	NumberSequenceKeypoint.new(1, 0),
})

--- `UI_Common_Rays` stand-in (08 §13.2: a ray burst that turns behind rewards): a disc of
--- `dark` under eight crisp `light` wedges, so every second spoke is light, filling `rays`
--- (card-local) and shown only inside `clip`. Turn the returned frame by setting `Rotation`.
function MomentArt.rays(
	parent: Instance,
	rays: HudLayout.Rect,
	clip: HudLayout.Rect,
	light: Color3,
	dark: Color3,
	z: number
): Frame
	local box = rect(parent, clip, { Name = "RaysClip", ClipsDescendants = true, ZIndex = z })
	local d = rays.width
	local r = d / 2
	local holder = Draw.new("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(r + rays.x - clip.x, rays.y + rays.height / 2 - clip.y),
		Size = UDim2.fromOffset(d, d),
		ZIndex = z,
		Parent = box,
	}) :: Frame
	Draw.disc(d, dark, nil, { Name = "Base", ZIndex = z, Parent = holder })
	-- Each light wedge is two right triangles about its axis, from the centre out to `r`: a
	-- rect `r` × `h` cut along its diagonal by a UIGradient step. A gradient turns in pixels
	-- and steps through the rect's centre, which is on that diagonal.
	local half = math.pi / RAY_WEDGES
	local h = r * math.tan(half)
	for i = 0, RAY_WEDGES / 2 - 1 do
		local spoke = Draw.new("Frame", {
			Name = `Wedge{i + 1}`,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(d, d),
			Rotation = i * 720 / RAY_WEDGES,
			ZIndex = z,
			Parent = holder,
		})
		for side = -1, 1, 2 do
			-- side -1: above the axis, apex at its bottom left; 1: below, apex at its top left.
			local tri = Draw.new("Frame", {
				Position = UDim2.fromOffset(r, if side < 0 then r - h else r),
				Size = UDim2.fromOffset(r, h),
				BackgroundColor3 = light,
				BackgroundTransparency = 0,
				ZIndex = z + 1,
				Parent = spoke,
			})
			Draw.new("UIGradient", {
				Transparency = CUT,
				Rotation = math.deg(math.atan2(-side * r, h)),
				Parent = tri,
			})
		end
	end
	Draw.slot("UI_Common_Rays", holder, z + 1)
	return holder
end

return table.freeze(MomentArt)
