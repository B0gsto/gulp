--!strict
-- Hud/CoveHud: screen S14, the cove HUD, at build stage 2 (docs/08 sections 5.1, 5.4 and 15):
-- the Pearls chip (balance that counts up, plus button), the Pearls an hour chip, the slots chip,
-- Claim all (shown only while Pearls wait in the pile), the Creatures dock button and the Pearl
-- pile bubble over the Pearl Clam. Geometry is `HudLayout.cove`; values come from UIController.
-- Code-drawn stand-ins carry the empty image slots of 08 §13.6.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)
local HudMath = require(ReplicatedStorage.Shared.Logic.HudMath)

local Draw = require("../Kit/Draw")
local Icons = require("../Kit/Icons")
local Loc = require("../Loc")
local Screen = require("../Kit/Screen")
local Theme = require("../Kit/Theme")

local CoveHud = {}

export type DockId = "species"
export type Callbacks = {
	claim: () -> (), -- Claim all, or a tap on the pile (CoveAction op 1)
	plus: () -> (), -- the Pearls chip's plus: the shop's Pearls tab
	slots: () -> (), -- the slots chip: S16
	dock: (id: DockId) -> (),
}
export type State = {
	pearls: number,
	rate: number, -- Pearls an hour from every specimen
	used: number,
	capacity: number,
	pile: number, -- whole Pearls waiting in the pile
	pileFull: boolean, -- the pile has stopped growing (cap reached)
}

-- 08 §5.1: stage 2 builds the Creatures button; Codex, Daily and Shop follow with their menus.
local DOCK: { { id: DockId, key: string, image: string } } = {
	{ id = "species", key = "dock.species", image = "UI_Cove_DockSpecies" },
}
local C = HudLayout.COVE
local COUNT_TIME = 0.5 -- 08 §5.4: the balance counts up while the Pearls fly in
local FADE = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- 08 §5.1

type Built = {
	root: Frame,
	pearls: Frame,
	balance: TextLabel,
	plusHit: TextButton,
	income: Frame,
	incomeText: TextLabel,
	slots: Frame,
	slotsText: TextLabel,
	slotsHit: TextButton,
	claim: Draw.Button,
	claimAmount: TextLabel,
	dock: { Frame },
	bubble: BillboardGui,
	bubbleText: TextLabel,
	bubbleBody: Frame,
}

local built: Built? = nil
local shown = false
local state: State = { pearls = 0, rate = 0, used = 0, capacity = 0, pile = 0, pileFull = false }
local shownBalance = 0
local pileAnchor: BasePart? = nil
local hideClaimUntil = 0 -- after a tap, until the claim's State lands (08 §5.4)
local countToken = 0

local function shortText(n: number): string
	local digits, kind = HudMath.short(n)
	if kind == "thousand" then
		return Loc.t("common.thousand", { Value = digits })
	elseif kind == "million" then
		return Loc.t("common.million", { Value = digits })
	end
	return digits
end

-- `UI_Common_Chip`: the cream pill behind HUD numbers, with the navy stroke and hard shadow.
local function chip(name: string, parent: Instance): Frame
	local frame = Draw.new("Frame", {
		Name = name,
		BackgroundColor3 = Theme.PANEL,
		BackgroundTransparency = 0,
		ZIndex = 2,
		Parent = parent,
	}, { Draw.corner(), Draw.stroke(Theme.STROKE_PANEL) }) :: Frame
	Draw.slot("UI_Common_Chip", frame, 3)
	return frame
end

local function hitButton(name: string, parent: Instance, onActivate: () -> ()): TextButton
	local hit = Draw.new("TextButton", {
		Name = name,
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutoButtonColor = false,
		ZIndex = 9,
		Parent = parent,
	}) :: TextButton
	local scale = Draw.new("UIScale", { Parent = parent }) :: UIScale
	Draw.bindPress(hit, scale, {
		darken = function() end,
		onRelease = onActivate,
		enabled = function()
			return true
		end,
	})
	return hit
end

-- `UI_Cove_PerHour` stand-in: a Pearl with a small clock face on its lower right.
local function perHourIcon(size: number, parent: Instance)
	local holder = Draw.new("Frame", {
		Name = "UI_Cove_PerHour",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 8 + size / 2, 0.5, 0),
		Size = UDim2.fromOffset(size, size),
		ZIndex = 3,
		Parent = parent,
	}) :: Frame
	Icons.pearl(size * 0.86, holder, UDim2.fromScale(0.43, 0.43), 4)
	local clock = Draw.disc(size * 0.5, Theme.SECONDARY, UDim2.fromScale(0.78, 0.78), {
		ZIndex = 7,
		Parent = holder,
	})
	Draw.stroke(Theme.STROKE_CHIP).Parent = clock
	for i, rot in { 0, 90 } do
		Draw.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(3, size * (if i == 1 then 0.18 else 0.14)),
			Rotation = rot,
			BackgroundColor3 = Theme.INK,
			BackgroundTransparency = 0,
			ZIndex = 8,
			Parent = clock,
		})
	end
	Draw.slot("UI_Cove_PerHour", holder, 9)
end

-- `UI_Cove_DockSpecies` stand-in: a little fish on an aqua disc.
local function speciesGlyph(parent: Instance)
	local disc = Draw.disc(C.dock.icon, Theme.SECONDARY, UDim2.new(0.5, 0, 0, C.dock.icon / 2), {
		Name = "Icon",
		ZIndex = 3,
		Parent = parent,
	})
	Draw.stroke(Theme.STROKE_ICON).Parent = disc
	Draw.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.32, 0.5),
		Size = UDim2.fromOffset(14, 14),
		Rotation = 45,
		BackgroundColor3 = Theme.PRIMARY,
		BackgroundTransparency = 0,
		ZIndex = 4,
		Parent = disc,
	}, { Draw.corner(3), Draw.stroke(Theme.STROKE_CHIP) })
	local body = Draw.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.56, 0.5),
		Size = UDim2.fromOffset(30, 20),
		BackgroundColor3 = Theme.PRIMARY,
		BackgroundTransparency = 0,
		ZIndex = 5,
		Parent = disc,
	}, { Draw.corner(), Draw.stroke(Theme.STROKE_CHIP) }) :: Frame
	Draw.disc(5, Theme.INK, UDim2.fromScale(0.72, 0.4), { ZIndex = 6, Parent = body })
	Draw.slot("UI_Cove_DockSpecies", disc, 7)
end

local function buildBubble(callbacks: Callbacks): (BillboardGui, Frame, TextLabel)
	-- 08 §5.1: `UI_Cove_IncomeBubble` (72 rpx) over the Pearl Clam with the amount; tapping it
	-- claims. A BillboardGui in PlayerGui so it takes input; sized in pixels on relayout.
	local gui = Draw.new("BillboardGui", {
		Name = "Cove.PearlPile",
		AlwaysOnTop = true,
		Active = true,
		ResetOnSpawn = false,
		LightInfluence = 0,
		StudsOffsetWorldSpace = Vector3.new(0, 3, 0),
		Enabled = false,
	}) :: BillboardGui
	local body =
		Draw.new("Frame", { Name = "Body", Size = UDim2.fromScale(1, 1), Parent = gui }) :: Frame
	Draw.new("UIScale", { Name = "Fit", Parent = body })
	local bubble = Draw.disc(C.bubble, Theme.WHITE, UDim2.new(0.5, 0, 0, C.bubble / 2 + 4), {
		Name = "UI_Cove_IncomeBubble",
		BackgroundTransparency = 0.35,
		ZIndex = 2,
		Parent = body,
	})
	Draw.stroke(Theme.STROKE_ICON, Theme.SECONDARY_SHADE).Parent = bubble
	Draw.new("UIGradient", {
		Color = ColorSequence.new(Theme.WHITE, Theme.SECONDARY),
		Rotation = 70,
		Parent = bubble,
	})
	Icons.pearl(40, bubble, UDim2.fromScale(0.5, 0.54), 3)
	Draw.disc(14, Theme.WHITE, UDim2.fromScale(0.28, 0.24), { ZIndex = 6, Parent = bubble })
	Draw.slot("UI_Cove_IncomeBubble", bubble, 7)
	local press = Draw.new("UIScale", { Name = "Press", Parent = bubble }) :: UIScale
	local label = Draw.text({
		Name = "Amount",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, C.bubble + 8),
		Size = UDim2.new(1, 0, 0, 34),
		Text = "0",
		TextColor3 = Theme.TEXT_ON_DARK,
		ZIndex = 4,
		Parent = body,
	}, C.text.balance, "display", Theme.STROKE_TEXT * 1.5)
	local hit = Draw.new("TextButton", {
		Name = "Hit",
		Text = "",
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		ZIndex = 9,
		Parent = body,
	}) :: TextButton
	Draw.bindPress(hit, press, {
		darken = function() end,
		onRelease = callbacks.claim,
		enabled = function()
			return state.pile >= 1
		end,
	})
	return gui, body, label
end

--- Builds S14 under `parent` (the GulpHUD layer root). Hidden until `setShown(true)`.
function CoveHud.build(parent: Frame, callbacks: Callbacks)
	if built then
		return
	end
	local root = Draw.new("Frame", {
		Name = "S14.CoveHud",
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = parent,
	}) :: Frame

	local pearls = chip("Cove.Pearls", root)
	Icons.pearl(40, pearls, UDim2.new(0, 30, 0.5, 0), 4)
	local balance = Draw.text({
		Name = "Balance",
		Position = UDim2.fromOffset(58, 0),
		Size = UDim2.new(1, -58 - C.plus - 14, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0",
		TextColor3 = Theme.INK,
		ZIndex = 4,
		Parent = pearls,
	}, C.text.balance, "display")
	local plus = Icons.plus(C.plus, pearls, UDim2.new(1, -(C.chipHeight / 2), 0.5, 0), 4)
	local plusHit = hitButton("PlusHit", plus, callbacks.plus)

	local income = chip("Cove.Income", root)
	perHourIcon(38, income)
	local incomeText = Draw.text({
		Name = "PerHour",
		Position = UDim2.fromOffset(52, 0),
		Size = UDim2.new(1, -60, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		TextColor3 = Theme.INK,
		ZIndex = 4,
		Parent = income,
	}, C.text.income, "display")

	local slots = chip("Cove.Slots", root)
	local slotsText = Draw.text({
		Name = "Count",
		Size = UDim2.fromScale(1, 1),
		Text = "0/0",
		TextColor3 = Theme.INK,
		ZIndex = 4,
		Parent = slots,
	}, C.text.slots, "display")
	local slotsHit = hitButton("SlotsHit", slots, callbacks.slots)

	local a = C.claimAll
	local claim =
		Draw.button("Primary", a.width, a.height, Loc.t("common.claim_all"), 0, callbacks.claim)
	claim.root.Name = "Cove.ClaimAll"
	claim.root.Parent = root
	claim.label.Size = UDim2.new(1, -120, 1, 0)
	claim.label.Position = UDim2.fromOffset(18, 0)
	claim.label.TextXAlignment = Enum.TextXAlignment.Left
	claim.label:SetAttribute(Screen.TEXT_RPX, C.text.claim)
	claim.label.TextSize = Screen.textSize(C.text.claim)
	local amountBox = Draw.new("Frame", {
		Name = "Amount",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(104, 48),
		BackgroundColor3 = Theme.PANEL,
		BackgroundTransparency = 0,
		ZIndex = 6,
		Parent = claim.face,
	}, { Draw.corner(), Draw.stroke(Theme.STROKE_CHIP) }) :: Frame
	Icons.pearl(30, amountBox, UDim2.new(0, 22, 0.5, 0), 7)
	local claimAmount = Draw.text({
		Name = "Value",
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -46, 1, 0),
		Text = "0",
		TextColor3 = Theme.INK,
		ZIndex = 8,
		Parent = amountBox,
	}, C.text.claim, "display")

	local dock: { Frame } = {}
	for _, d in DOCK do
		local button = Draw.new("Frame", {
			Name = "Dock." .. d.id,
			Size = UDim2.fromOffset(C.dock.size, C.dock.size),
			ZIndex = 2,
			Parent = root,
		}) :: Frame
		speciesGlyph(button)
		Draw.text({
			Name = "Label",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 2),
			Size = UDim2.new(1, 40, 0, 30),
			Text = Loc.t(d.key),
			TextColor3 = Theme.TEXT_ON_DARK,
			ZIndex = 4,
			Parent = button,
		}, C.text.dock, "display", Theme.STROKE_TEXT)
		local hit = hitButton("Hit", button, function()
			callbacks.dock(d.id)
		end)
		hit.Size = UDim2.fromScale(1, 1)
		hit.Position = UDim2.fromScale(0.5, 0.5)
		table.insert(dock, button)
	end

	local bubble, bubbleBody, bubbleText = buildBubble(callbacks)
	bubble.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	built = {
		root = root,
		pearls = pearls,
		balance = balance,
		plusHit = plusHit,
		income = income,
		incomeText = incomeText,
		slots = slots,
		slotsText = slotsText,
		slotsHit = slotsHit,
		claim = claim,
		claimAmount = claimAmount,
		dock = dock,
		bubble = bubble,
		bubbleText = bubbleText,
		bubbleBody = bubbleBody,
	}
	CoveHud.layout(Screen.layout())
	Screen.changed:connect(CoveHud.layout)
	CoveHud.set(state, true)
end

local function place(o: GuiObject, r: HudLayout.Rect)
	o.Position = UDim2.fromOffset(r.x, r.y)
	o.Size = UDim2.fromOffset(r.width, r.height)
end

function CoveHud.layout(layout: Screen.Layout)
	local b = built
	if not b then
		return
	end
	local r = HudLayout.cove(layout.screenClass, layout.contentSize, #b.dock)
	place(b.pearls, r.pearls)
	b.plusHit.Size = UDim2.fromOffset(r.plusHit.width, r.plusHit.height)
	b.plusHit.Position = UDim2.fromScale(0.5, 0.5)
	place(b.income, r.income)
	place(b.slots, r.slots)
	b.slotsHit.Size = UDim2.fromOffset(r.slotsHit.width, r.slotsHit.height)
	b.slotsHit.Position = UDim2.fromScale(0.5, 0.5)
	b.claim.root.Position = UDim2.fromOffset(r.claimAll.x, r.claimAll.y)
	b.claim.hit.Size = UDim2.fromOffset(r.claimAllHit.width, r.claimAllHit.height)
	for i, d in b.dock do
		place(d, r.dock[i])
	end
	-- The pile bubble: 160 x 120 rpx (bubble, amount under it) in pixels at this scale.
	local s = layout.scale
	b.bubble.Size = UDim2.fromOffset(160 * s, 120 * s)
	b.bubbleBody.Size = UDim2.fromOffset(160, 120)
	local uiScale = b.bubbleBody:FindFirstChild("Fit")
	if uiScale and uiScale:IsA("UIScale") then
		uiScale.Scale = s
	end
end

local function render(instant: boolean?)
	local b = built
	if not b then
		return
	end
	b.incomeText.Text = Loc.t("common.per_hour", { Amount = HudMath.grouped(state.rate) })
	b.slotsText.Text = `{state.used}/{state.capacity}`
	local pile = if os.clock() < hideClaimUntil then 0 else math.floor(state.pile)
	-- 08 §5.1: Claim all shows when at least 1 Pearl is in the pile.
	b.claim.root.Visible = pile >= 1
	b.claimAmount.Text = shortText(pile)
	b.bubbleText.Text = if state.pileFull then Loc.t("cove.pile_full") else shortText(pile)
	b.bubble.Enabled = shown and pileAnchor ~= nil and pile >= 1

	local target = math.floor(state.pearls)
	if instant or target <= shownBalance then
		countToken += 1
		shownBalance = target
		b.balance.Text = HudMath.grouped(target)
		return
	end
	-- Counts up over 500 ms (08 §5.4), eased out.
	countToken += 1
	local my = countToken
	local from = shownBalance
	task.spawn(function()
		local t0 = os.clock()
		while countToken == my do
			local k = math.min(1, (os.clock() - t0) / COUNT_TIME)
			shownBalance = math.floor(from + (target - from) * (1 - (1 - k) ^ 3))
			b.balance.Text = HudMath.grouped(shownBalance)
			if k >= 1 then
				break
			end
			task.wait()
		end
	end)
end

--- New values; the balance counts up unless `instant`.
function CoveHud.set(s: State, instant: boolean?)
	state = s
	render(instant)
end

--- Shows or hides S14 (08 §5.1: a 250 ms cross-fade with the run HUD).
function CoveHud.setShown(on: boolean)
	local b = built
	if not b or shown == on then
		return
	end
	shown = on
	b.root.Visible = on
	if on then
		for _, child in b.root:GetChildren() do
			if child:IsA("GuiObject") then
				local scale = child:FindFirstChildOfClass("UIScale")
					or Draw.new("UIScale", { Parent = child })
				scale.Scale = 0.85
				Draw.tween(scale, FADE, { Scale = 1 })
			end
		end
	end
	render(true)
end

function CoveHud.isShown(): boolean
	return shown
end

--- The part the Pearl pile bubble floats over (the Pearl Clam), or nil to hide it.
function CoveHud.setPileAnchor(part: BasePart?)
	local b = built
	if not b then
		return
	end
	pileAnchor = part
	b.bubble.Adornee = part :: any
	render(true)
end

--- 08 §5.4: after a claim tap the button hides until more is ready.
function CoveHud.claimed()
	hideClaimUntil = os.clock() + 2
	render(true)
end

--- Screen pixels the claimed Pearls fly from: the pile bubble when it is up, else Claim all.
function CoveHud.claimFrom(): Vector2?
	local b = built
	if not b then
		return nil
	end
	local from: GuiObject = if b.bubble.Enabled then b.bubbleBody else b.claim.face
	return from.AbsolutePosition + from.AbsoluteSize / 2
end

--- 08 §4.5 step 7 and §5.4: `count` Pearls fly from `from` (screen pixels) to the Pearls chip in
--- 500 ms, ahead of the balance counting up.
function CoveHud.flyPearls(from: Vector2, count: number)
	local b = built
	if not b or not shown then
		return
	end
	local scale = Screen.scale()
	local origin = b.root.AbsolutePosition
	local start = (from - origin) / scale
	local target = (
		b.pearls.AbsolutePosition
		+ Vector2.new(30 * scale, b.pearls.AbsoluteSize.Y / 2)
		- origin
	) / scale
	for i = 1, count do
		task.delay((i - 1) * 0.04, function()
			local holder = Draw.new("Frame", {
				Name = "Flying",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(
					start.X + math.random(-40, 40),
					start.Y + math.random(-24, 24)
				),
				Size = UDim2.fromOffset(36, 36),
				ZIndex = 20,
				Parent = b.root,
			}) :: Frame
			Icons.pearl(36, holder, nil, 21)
			local tween = Draw.tween(
				holder,
				TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(24, 24) }
			)
			tween.Completed:Once(function()
				holder:Destroy()
			end)
		end)
	end
end

return CoveHud
