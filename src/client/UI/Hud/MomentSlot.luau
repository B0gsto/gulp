--!strict
-- HUD.MomentSlot (docs/08 sections 3.3 and 4.1; task S6-C5): the one in-run moment at a time,
-- top centre on the `GulpMoments` layer. `Shared.Logic.MomentQueue` holds the priorities, holds
-- and the card motion (08 §11.3: 180 ms in, dropping 24 rpx with a fade; 160 ms out); this module
-- builds each card when it starts and moves it every frame. Cards never take input (08 §4.2).
-- The tier-up (S07, `TierUp`) and trait gained (S08, `TraitGained`) cards come first; the tide
-- timer, event and zone moments plug in the same way when their tasks build them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MomentQueue = require(ReplicatedStorage.Shared.Logic.MomentQueue)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

local Draw = require("../Kit/Draw")

local MomentSlot = {}

--- A built card: `root` is placed in the slot by its rect; `update(t)` (optional) runs the card's
--- own motion every frame, `t` s after it began to enter.
export type Card = {
	root: Frame,
	rect: { x: number, y: number, width: number, height: number },
	update: ((t: number) -> ())?,
}
export type Build = (parent: Frame, slot: { width: number, height: number }) -> Card

export type Slot = {
	root: Frame,
	layout: (x: number, y: number, width: number, height: number) -> (),
	push: (kind: MomentQueue.Kind, hold: number, build: Build, data: any) -> (),
	update: (now: number) -> (),
	clear: () -> (), -- drops every card and the queue at once (Dev/HudHarness)
	--- Fired as a card begins to enter, and after it has left (or was replaced), with its kind
	--- and data: chapter 04 times its beats from here (B4: the dash button 1.0 s after the
	--- tier-up banner; B5: the curtain 2.5 s after the trait banner).
	shown: Types.Signal<MomentQueue.Kind, any>,
	ended: Types.Signal<MomentQueue.Kind, any>,
}

-- Each fading property and its value when fully shown.
type Fade = { object: Instance, prop: string, base: number }

local FADE_PROPS: { [string]: { string } } = {
	Frame = { "BackgroundTransparency" },
	TextLabel = { "TextTransparency", "BackgroundTransparency" },
	ImageLabel = { "ImageTransparency", "BackgroundTransparency" },
	UIStroke = { "Transparency" },
}

local function collectFades(root: Instance): { Fade }
	local out: { Fade } = {}
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, object in list do
		local props = FADE_PROPS[object.ClassName]
		if props then
			for _, prop in props do
				local base = (object :: any)[prop] :: number
				if base < 1 then
					table.insert(out, { object = object, prop = prop, base = base })
				end
			end
		end
	end
	return out
end

local function applyFades(fades: { Fade }, alpha: number)
	local hidden = 1 - math.clamp(alpha, 0, 1)
	for _, f in fades do
		(f.object :: any)[f.prop] = f.base + (1 - f.base) * hidden
	end
end

--- `UI_Common_Rays` stand-in (08 §13.2: a ray burst that turns behind rewards): `count` soft bars
--- through the centre, `size` rpx across, centred at `centre` in `parent`. Turn it by setting
--- `Rotation`.
function MomentSlot.rays(
	parent: Instance,
	size: number,
	colour: Color3,
	centre: UDim2,
	zIndex: number
): Frame
	local holder = Draw.new("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = centre,
		Size = UDim2.fromOffset(size, size),
		ZIndex = zIndex,
		Parent = parent,
	}) :: Frame
	local count = 6
	for i = 1, count do
		local bar = Draw.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, size * 0.12),
			Rotation = (i - 1) * 180 / count,
			BackgroundColor3 = colour,
			BackgroundTransparency = 0.25,
			ZIndex = zIndex,
			Parent = holder,
		}, { Draw.corner() }) :: Frame
		-- Strong at the centre, gone at the tips.
		Draw.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = bar,
		})
	end
	Draw.slot("UI_Common_Rays", holder, zIndex)
	return holder
end

-- A card on screen: the moment it shows, when it began and what fades with it.
type Live = { moment: MomentQueue.Moment, card: Card, fades: { Fade }, startedAt: number }

function MomentSlot.new(parent: Instance): Slot
	local root = Draw.new("Frame", {
		Name = "HUD.MomentSlot",
		Size = UDim2.fromOffset(480, 112),
		Active = false,
		Parent = parent,
	}) :: Frame
	local queue = MomentQueue.new()
	local live: Live? = nil
	local leaving: { Live } = {} -- replaced at once: fade out over the leave time
	local slotSize = { width = 480, height = 112 }
	local shown = Signal.new() :: Types.Signal<MomentQueue.Kind, any>
	local ended = Signal.new() :: Types.Signal<MomentQueue.Kind, any>

	local function place(l: Live, dy: number)
		local r = l.card.rect
		l.card.root.Position = UDim2.fromOffset(r.x, r.y + dy)
	end

	local function start(m: MomentQueue.Moment, at: number)
		local entry = m.data :: { build: Build, data: any }
		local card = entry.build(root, slotSize)
		card.root.Active = false
		local l = { moment = m, card = card, fades = collectFades(card.root), startedAt = at }
		applyFades(l.fades, 0)
		place(l, -MomentQueue.DROP)
		live = l
		shown:fire(m.kind, entry.data)
	end

	local function finish(l: Live)
		l.card.root:Destroy()
		ended:fire(l.moment.kind, (l.moment.data :: any).data)
	end

	-- The queue's current moment and the card on screen must agree.
	local function sync()
		local current = queue.current
		local l = live
		if l and l.moment ~= current then
			finish(l)
			live = nil
		end
		if current and live == nil then
			start(current, queue.startedAt)
		end
	end

	local slot: Slot = {
		root = root,
		shown = shown,
		ended = ended,
		layout = function(x: number, y: number, width: number, height: number)
			root.Position = UDim2.fromOffset(x, y)
			root.Size = UDim2.fromOffset(width, height)
			slotSize = { width = width, height = height }
		end,
		push = function(kind: MomentQueue.Kind, hold: number, build: Build, data: any)
			local now = os.clock()
			local replaced =
				MomentQueue.push(queue, kind, hold, { build = build, data = data }, now)
			local l = live
			if replaced and l and l.moment == replaced then
				-- 08 §4.1: a higher priority moment replaces a lower one at once.
				table.insert(
					leaving,
					{ moment = l.moment, card = l.card, fades = l.fades, startedAt = now }
				)
				live = nil
				ended:fire(l.moment.kind, (l.moment.data :: any).data)
			end
			sync()
		end,
		clear = function()
			local l = live
			if l then
				l.card.root:Destroy()
				live = nil
			end
			for _, g in leaving do
				g.card.root:Destroy()
			end
			table.clear(leaving)
			queue = MomentQueue.new()
		end,
		update = function(now: number)
			MomentQueue.step(queue, now)
			sync()
			local l = live
			if l then
				local t = now - l.startedAt
				local pose = MomentQueue.pose(t, l.moment.hold)
				applyFades(l.fades, pose.alpha)
				place(l, pose.dy)
				local u = l.card.update
				if u then
					u(t)
				end
			end
			for i = #leaving, 1, -1 do
				local g = leaving[i]
				local x = (now - g.startedAt) / MomentQueue.LEAVE
				if x >= 1 then
					g.card.root:Destroy()
					table.remove(leaving, i)
				else
					applyFades(g.fades, 1 - x * x)
				end
			end
		end,
	}
	return slot
end

return table.freeze(MomentSlot)
