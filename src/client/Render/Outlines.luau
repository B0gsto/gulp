--!strict
-- Render/Outlines (task S3-C6; docs/06 section 13.2, docs/09 section 8.8, canon 5.2): the outline
-- colours and the red pulse, shared by every renderer that draws shells (creature rigs now,
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

function Outlines.setColourBlind(on: boolean)
	palette = if on then colourBlind else normal
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

--- 09 §8.8 caps, nearest first. `smooth` is the Smooth graphics tier (QualityController, later).
function Outlines.caps(smooth: boolean): (number, number)
	local cap = if smooth then OutlineRules.CAP_SMOOTH else OutlineRules.CAP
	return cap.edible, cap.dangerous
end

return Outlines
