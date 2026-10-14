--!strict
-- Kit/Theme: the look every screen shares. Colours, fonts and shapes are docs/06's (sections 4.5,
-- 4.6 and 12); sizes and timings are docs/08's (sections 1.5 and 11). Lengths are rpx.
--
-- docs/06 section 12.2 gives strokes and shadows in px on a 1920 x 1080 reference; on the
-- 720 rpx canvas that is x 2/3: a 5 px panel stroke is 3.3 rpx, 4 px on icons 2.7, 3 px on chips 2.

local Theme = {}

local hex = Color3.fromHex

-- 06 §4.6 interface colours.
Theme.INK = hex("#14213D") -- navy: outlines and text
Theme.PANEL = hex("#FFF8E7") -- cream
Theme.PANEL_SHADE = hex("#F2E3C4")
Theme.PRIMARY = hex("#FFC93D") -- sun yellow
Theme.PRIMARY_SHADE = hex("#E09A1F")
Theme.SECONDARY = hex("#3DD6D0") -- aqua
Theme.SECONDARY_SHADE = hex("#1FA3A8")
Theme.DECLINE = hex("#FF6B5E") -- coral, navy text
Theme.TEXT_ON_DARK = hex("#FFFFFF")
Theme.DISABLED = hex("#B8C4CC")
Theme.DIM = hex("#0B1530") -- screen dim at 55%, hard shadow at 35%
Theme.DIM_TRANSPARENCY = 0.45
Theme.SHADOW_TRANSPARENCY = 0.65

-- 06 §4.5 reserved signal colours.
Theme.EDIBLE = hex("#A6FF3D")
Theme.DANGER = hex("#FF3B4E")
Theme.HOME = hex("#FFC46B") -- lantern amber: the player's own home only
Theme.PEARL = hex("#FFE9F2")
Theme.PEARL_SHADE = hex("#FFB8D9")
-- 06 §4.4 / §4.5: rarity gold, the mass bar fill at tier 7 (08 §3.4 "full and gold").
Theme.GOLD = hex("#FFB01F")
Theme.WHITE = Color3.new(1, 1, 1)
-- 06 §12.4 tier badge rings, tier 1 to 7.
Theme.TIER_RING = table.freeze({
	hex("#9FE7FF"),
	hex("#3DD6D0"),
	hex("#5FD08A"),
	hex("#4C8DFF"),
	hex("#9A6BFF"),
	hex("#FF7AB8"),
	Theme.GOLD,
})
-- 06 §4.4 rarity frames.
Theme.RARITY = table.freeze({
	Common = hex("#C9D6DF"),
	Uncommon = hex("#2ED3C6"),
	Rare = hex("#4D8DFF"),
	Epic = hex("#A862FF"),
	Mythic = hex("#FFB01F"),
})

-- 06 §12.3 type.
Theme.FONT_DISPLAY = Font.fromEnum(Enum.Font.FredokaOne) -- titles, buttons, numbers
Theme.FONT_BODY = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold)

-- 08 §1.5 text sizes.
Theme.TEXT = table.freeze({ small = 22, body = 24, number = 28, title = 40, hero = 64 })

-- 06 §12.2 in rpx (see the header).
Theme.STROKE_PANEL = 3.3
Theme.STROKE_ICON = 2.7
Theme.STROKE_CHIP = 2
Theme.STROKE_TEXT = 2 -- 08 §1.5: text over the 3D world has a 2 rpx dark stroke
Theme.SHADOW_OFFSET = 5.3 -- hard shadow, offset 0, 8 px
Theme.LIP = 4 -- the darker 6 px lip under buttons
Theme.PANEL_RADIUS = 18.7 -- about 28 px

-- 08 §11.2 button states and 06 §12.5 motion.
Theme.MOTION = table.freeze({
	hover = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	press = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	release = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	disabled = TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
	fadeHud = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	panelIn = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	slam = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
})
Theme.PRESS_SCALE = 0.94
Theme.HOVER_SCALE = 1.04

return table.freeze(Theme)
