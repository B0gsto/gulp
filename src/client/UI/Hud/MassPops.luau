--!strict
-- HUD.MassPops (docs/08 section 3.16): "+4" (`hud.plus_mass`, Number 28) rises 48 rpx from the
-- creature's mouth and fades over 500 ms; at most 4 at once; fast bites merge into one number.
-- Live pops stack: an older one stays `HudMath.POP_GAP` above the next newer (HudMath.popStack).
-- On the full-screen `GulpWorld` layer; the bookkeeping is `Shared.Logic.HudMath.pushPop`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudMath = require(ReplicatedStorage.Shared.Logic.HudMath)

local Draw = require("../Kit/Draw")
local Loc = require("../Loc")
local Theme = require("../Kit/Theme")

local MassPops = {}

export type MassPops = {
	root: Frame,
	push: (amount: number, now: number) -> (),
	-- `mouthX`, `mouthY`: the mouth in full-screen rpx, or nil when it is off screen.
	update: (now: number, mouthX: number?, mouthY: number?) -> (),
}

type Live = { pop: HudMath.Pop, label: TextLabel, scale: UIScale, x: number, y: number }

function MassPops.new(parent: Instance): MassPops
	local root = Draw.new(
		"Frame",
		{ Name = "HUD.MassPops", Size = UDim2.fromScale(1, 1), Parent = parent }
	) :: Frame
	local pops: { HudMath.Pop } = {}
	local live: { Live } = {}
	local lastX, lastY = 0, 0

	local function labelFor(pop: HudMath.Pop): Live?
		for _, l in live do
			if l.pop == pop then
				return l
			end
		end
		return nil
	end

	return {
		root = root,
		push = function(amount: number, now: number)
			local pop = HudMath.pushPop(pops, now, amount)
			local entry = labelFor(pop)
			if entry == nil then
				local label = Draw.text({
					Name = "Pop",
					AnchorPoint = Vector2.new(0.5, 1),
					Size = UDim2.fromOffset(120, 36),
					TextColor3 = Theme.WHITE,
					Parent = root,
				}, Theme.TEXT.number, "display", Theme.STROKE_TEXT)
				local scale = Draw.new("UIScale", { Parent = label }) :: UIScale
				entry = { pop = pop, label = label, scale = scale, x = lastX, y = lastY }
				table.insert(live, entry :: Live)
			end
			local e = entry :: Live
			e.label.Text = Loc.t("hud.plus_mass", { Mass = math.floor(pop.amount + 0.5) })
			-- 06 §12.3: numbers pop to 120% when they rise.
			e.scale.Scale = 1.2
			Draw.tween(e.scale, TweenInfo.new(0.07), { Scale = 1 })
			e.x, e.y = lastX, lastY
		end,
		update = function(now: number, mouthX: number?, mouthY: number?)
			if mouthX and mouthY then
				lastX, lastY = mouthX, mouthY
			end
			for i = #live, 1, -1 do
				local e = live[i]
				local age = now - e.pop.born
				local alive = table.find(pops, e.pop) ~= nil and age < HudMath.POP_LIFE
				if not alive then
					e.label:Destroy()
					table.remove(live, i)
				end
			end
			-- Oldest first (a merged pop restarts its life, so it counts as the newest).
			table.sort(live, function(a: Live, b: Live): boolean
				return a.pop.born < b.pop.born
			end)
			local ys = table.create(#live)
			for k, e in live do
				local rise = HudMath.popPose(now - e.pop.born)
				ys[k] = e.y - 8 - rise
			end
			ys = HudMath.popStack(ys)
			for k, e in live do
				local _, fade = HudMath.popPose(now - e.pop.born)
				e.label.Position = UDim2.fromOffset(e.x, ys[k])
				e.label.TextTransparency = fade
				local stroke = e.label:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Transparency = fade
				end
			end
		end,
	}
end

return MassPops
