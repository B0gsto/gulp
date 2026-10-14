--!strict
-- OutlineRules: who gets which outline shell, as seen by one viewer (task S3-C6; canon 5.2;
-- docs/02, section 0.1 `canEat`; docs/06, section 13.2; docs/09, section 8.8). Pure, so it runs
-- in Lune. Render/Outlines turns a Kind into a coloured shell.
--
-- `BiteRules` (09 §3) does not exist yet. Until it does, the tier test of 02 §0.1 lives here for
-- outlines only; when BiteRules lands, `canEatPlayer` should call `BiteRules.canEat` instead.
-- Not modelled yet (no replicated state): Puff (+1 defence tier), Spiny (gap 2), the eel's tuck,
-- Camo hiding and the Nursery safe volume. Each one only removes or shifts a colour.

export type Kind = "none" | "edible" | "dangerous"

local OutlineRules = {}

--- 06 §13.2 table "Can eat" / "Can eat you", and the colour-blind swap (S10-C4 wires the switch).
OutlineRules.COLOURS = table.freeze({
	edible = "#A6FF3D", -- lime
	dangerous = "#FF3B4E", -- red, pulses to white
} :: { [string]: string })
OutlineRules.COLOURS_COLOURBLIND = table.freeze({
	edible = "#FFF23D", -- yellow
	dangerous = "#FF3DC8", -- hot pink
} :: { [string]: string })

OutlineRules.THICK_RATIO = 0.06 -- 06 §13.2: players and predators, share of body height (tune)
OutlineRules.THICK_RATIO_PREY = 0.10 -- 06 §13.2: prey
OutlineRules.THICK_MIN = 0.12 -- studs (06 §13.2)
OutlineRules.DANGER_THICK = 1.5 -- 06 §13.2: "Can eat you" is 1.5× thicker
OutlineRules.PULSE_HZ = 2 -- 06 §13.2: pulses to white twice a second

--- 09 §8.8: nearest first, at most this many of each colour (Smooth tier: 8 and 4; 15 §3.0).
OutlineRules.CAP = table.freeze({ edible = 20, dangerous = 10 })
OutlineRules.CAP_SMOOTH = table.freeze({ edible = 8, dangerous = 4 })

--- 02 §0.1 for a player eating a player: the target is not shielded (protected, in a safe
--- volume, not in a run), tier 1 players cannot be eaten by players, and the eater must be at
--- least one full tier higher.
function OutlineRules.canEatPlayer(
	eaterTier: number,
	targetTier: number,
	targetShielded: boolean
): boolean
	if targetShielded or targetTier <= 1 then
		return false
	end
	return eaterTier >= targetTier + 1
end

--- The outline another player's creature gets on the viewer's screen (canon 5.2: green = you can
--- eat it, red = it can eat you, none = neither). `*Shielded` is true for a creature that cannot be
--- eaten right now: `Protected`, or `Phase` not "run" (in a cove, gulped). A shielded creature
--- gets no shell at all (09 §8.8), and a shielded viewer sees no red, since nothing can eat it.
function OutlineRules.creature(
	viewerTier: number,
	viewerShielded: boolean,
	otherTier: number,
	otherShielded: boolean
): Kind
	if otherShielded then
		return "none"
	end
	if OutlineRules.canEatPlayer(viewerTier, otherTier, false) then
		return "edible"
	end
	if OutlineRules.canEatPlayer(otherTier, viewerTier, viewerShielded) then
		return "dangerous"
	end
	return "none"
end

--- The outline of a prey kind (02 §0.1: prey of the eater's tier or lower). Plankton (tier 0) and
--- hook bait never get one (canon 5.2, 06 §13.2). Prey is never dangerous.
function OutlineRules.prey(viewerTier: number, preyTier: number, isBait: boolean): Kind
	if isBait or preyTier < 1 then
		return "none"
	end
	return if preyTier <= viewerTier then "edible" else "none"
end

--- Shell thickness in studs for a body `height` studs tall (06 §13.2).
function OutlineRules.thickness(height: number, kind: Kind, isPrey: boolean): number
	local t = math.max(
		OutlineRules.THICK_MIN,
		height * (if isPrey then OutlineRules.THICK_RATIO_PREY else OutlineRules.THICK_RATIO)
	)
	return if kind == "dangerous" then t * OutlineRules.DANGER_THICK else t
end

--- How far toward white the red shell is at time `t` seconds: 0..1, twice a second.
function OutlineRules.pulse(t: number): number
	return 0.5 - 0.5 * math.cos(2 * math.pi * OutlineRules.PULSE_HZ * t)
end

--- Picks which outlines draw: nearest first, up to `capEdible` edible and `capDangerous`
--- dangerous. `kinds[i]` and `distances[i]` describe candidate i of `count`; `order` is a scratch
--- array the caller keeps; `shown[i]` is written for every i. Allocates nothing once `order` has
--- grown to `count`.
function OutlineRules.select(
	kinds: { Kind },
	distances: { number },
	count: number,
	capEdible: number,
	capDangerous: number,
	order: { number },
	shown: { boolean }
)
	for i = 1, count do
		order[i] = i
		shown[i] = false
	end
	for i = #order, count + 1, -1 do
		order[i] = nil
	end
	-- Insertion sort: a server holds a few dozen creatures, and the order barely changes between
	-- calls.
	for i = 2, count do
		local v = order[i]
		local d = distances[v]
		local j = i - 1
		while j >= 1 and distances[order[j]] > d do
			order[j + 1] = order[j]
			j -= 1
		end
		order[j + 1] = v
	end
	local edible, dangerous = 0, 0
	for n = 1, count do
		local i = order[n]
		local kind = kinds[i]
		if kind == "edible" and edible < capEdible then
			edible += 1
			shown[i] = true
		elseif kind == "dangerous" and dangerous < capDangerous then
			dangerous += 1
			shown[i] = true
		end
	end
end

return table.freeze(OutlineRules)
