--!strict
-- Render/Outlines (task S3-C6; docs/06 section 13.2, docs/09 section 8.8, canon 5.2): the outline
-- colours, the shell material and the red pulse, shared by every renderer that draws shells (creature rigs now,
-- PreyRenderer and PredatorController later). Which thing gets which kind is
-- `Shared.Logic.OutlineRules`; the shells themselves belong to each rig.
--
-- The colour-blind swap (yellow and hot pink) is a switch here; S10-C4 wires it to the setting.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OutlineRules = require(ReplicatedStorage.Shared.Logic.OutlineRules)

local Outlines = {}

local WHITE = Color3.new(1, 1, 1)

local normal = {
	edible = Color3.fromHex(OutlineRules.COLOURS.edible),
	dangerous = Color3.fromHex(OutlineRules.COLOURS.dangerous),
}
local colourBlind = {
	edible = Color3.fromHex(OutlineRules.COLOURS_COLOURBLIND.edible),
	dangerous = Color3.fromHex(OutlineRules.COLOURS_COLOURBLIND.dangerous),
}
local palette = normal
-- `HUD.Outlines` (docs/08 sections 3.3 and 3.11): chapter 04 shows and hides every outline at
-- once through `HUD.setVisible("HUD.Outlines", on)`. The renderers read it when they pick shells.
local visible = true

--- The shell material: 06 §13.2's matte fallback. Measured in Studio for S3-C6, `Neon` clips the
--- lime #A6FF3D to about (254, 255, 26), which reads as the colour-blind yellow, and pushes the red
--- toward pink, so the colour coding is lost. A matte shell keeps the palette hue; it casts no
--- shadow (every shell is a visual part).
Outlines.MATERIAL = Enum.Material.SmoothPlastic

function Outlines.setColourBlind(on: boolean)
	palette = if on then colourBlind else normal
end

--- `HUD.Outlines`: false hides every edible and danger outline until it is shown again.
function Outlines.setVisible(on: boolean)
	visible = on
end

--- True unless `HUD.Outlines` is hidden.
function Outlines.visible(): boolean
	return visible
end

--- The steady colour of `kind` ("none" reads as white and is never drawn).
function Outlines.colour(kind: OutlineRules.Kind): Color3
	if kind == "edible" then
		return palette.edible
	elseif kind == "dangerous" then
		return palette.dangerous
	end
	return WHITE
end

--- The colour of `kind` at clock time `t`: red pulses to white twice a second (06 §13.2).
function Outlines.colourAt(kind: OutlineRules.Kind, t: number): Color3
	local c = Outlines.colour(kind)
	if kind == "dangerous" then
		return c:Lerp(WHITE, OutlineRules.pulse(t))
	end
	return c
end

return Outlines
