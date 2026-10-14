--!strict
-- smoke: the play-test smoke check (docs/09-technical-architecture.md, section 16.4; task S2-C7).
-- The `execute_luau` snippet an agent runs through the Studio MCP server, Server data model, during
-- a play test of the CI place (`rojo build ci.project.json -o build/ci.rbxl`). `tools/studio/smoke.py`
-- runs the whole routine with no click; by hand, follow the steps below and set STEP each time.
--
-- The routine of 16.4 and who does each step:
--   1. driver: `start_stop_play` (start); poll `get_studio_state` until the client data model
--      exists (a Client `execute_luau` sees the LocalPlayer).
--   2. this snippet, STEP = "owner": one player has a slot, a profile and a creature whose root's
--      network owner is that player. Prints a `POSE x y z` line for step 3.
--   3. driver: `user_keyboard_input` (Client) holds W for 2 s; then this snippet, STEP = "moved"
--      with FROM set to step 2's pose: the pose moved more than 30 studs and suspicion is 0.
--   4, 5. this snippet, STEP = "later": reported PENDING with the sprint and module that enables
--      each, until they are written here.
--   6. driver: `get_console_output` has no line at error level.
--   7. driver: `screen_capture` to disk, then `start_stop_play` (stop).
--
-- Each report's first line is the verdict: "smoke <step>: PASS", "FAIL", "WAIT" (the join is not
-- complete yet: the driver asks again) or "PENDING" (nothing in it can run yet). The other lines are "PASS name: detail", "FAIL ...",
-- "PENDING ...". Checks not built yet are PENDING, never PASS: suspicion needs MovementValidator.
--
-- MCP code runs in its own Luau VM (16.3), so the running services cannot be required here: the
-- snippet reads what they publish (the Slot attribute of PlayerLifecycle, the Creatures folder and
-- the Character of CreatureService, the root's network owner).

local STEP = "owner" -- "owner" (step 2), "moved" (step 3) or "later" (steps 4 and 5)
local FROM: Vector3? = nil -- step 3: the POSE of step 2, e.g. Vector3.new(0, -50, 0)

local MIN_MOVE = 30 -- studs in the 2 s hold of W (docs/13, Sprint 2 acceptance)

local Players = game:GetService("Players")

local lines: { string } = {}
local counts = { PASS = 0, FAIL = 0, WAIT = 0, PENDING = 0 }

local function report(status: string, name: string, detail: string)
	table.insert(lines, `{status} {name}: {detail}`)
	counts[status] += 1
end

local function check(ok: boolean, name: string, detail: string)
	report(if ok then "PASS" else "FAIL", name, detail)
end

local function fmt(v: Vector3): string
	return string.format("%.2f %.2f %.2f", v.X, v.Y, v.Z)
end

-- The one player of the play test, its slot and its creature's root, as far as they exist.
local function find(): (Player?, number?, Model?, BasePart?)
	local player = Players:GetPlayers()[1]
	if not player then
		return nil, nil, nil, nil
	end
	local slot = player:GetAttribute("Slot")
	local folder = workspace:FindFirstChild("Creatures")
	local model = folder and folder:FindFirstChild(`Creature_{player.UserId}`)
	if not (model and model:IsA("Model")) then
		return player, if type(slot) == "number" then slot else nil, nil, nil
	end
	local root = model:FindFirstChild("Root")
	return player,
		if type(slot) == "number" then slot else nil,
		model,
		if root and root:IsA("BasePart") then root else nil
end

local function owner()
	local players = Players:GetPlayers()
	local player, slot, model, root = find()
	if not (player and slot and model and root) then
		report(
			"WAIT",
			"join",
			`players {#players}, slot {slot or "none"}, creature {if model then "yes" else "no"}, `
				.. `root {if root then "yes" else "no"}`
		)
		return
	end
	check(#players == 1, "one player", `{#players} in the server ({player.Name})`)
	check(
		slot >= 1 and slot <= 24 and slot == math.floor(slot),
		"slot",
		`Slot attribute {slot} (1 to 24)`
	)
	report("PENDING", "profile", "DataService (B20, S4-C6, Sprint 4)")
	check(player.Character == model, "creature", `{model:GetFullName()} is the Character`)
	local netOwner = root:GetNetworkOwner()
	check(
		netOwner == player,
		"network owner",
		`Root's owner is {if netOwner then netOwner.Name else "the server"}`
	)
	table.insert(lines, `POSE {fmt(root.Position)}`)
end

local function moved()
	local _, _, _, root = find()
	if not root then
		report("FAIL", "creature", "no root part to measure")
		return
	end
	if not FROM then
		report("FAIL", "pose", "FROM is not set: copy step 2's POSE into it")
		return
	end
	local distance = (root.Position - FROM).Magnitude
	check(
		distance > MIN_MOVE,
		"moved",
		string.format(
			"%.1f studs (more than %d), %s to %s",
			distance,
			MIN_MOVE,
			fmt(FROM),
			fmt(root.Position)
		)
	)
	report("PENDING", "suspicion 0", "MovementValidator (B14, S8-C2, Sprint 8)")
	table.insert(lines, `POSE {fmt(root.Position)}`)
end

local function later()
	report(
		"PENDING",
		"step 4",
		"PreyRenderer knows more than 10 groups, frame time under 16.7 ms: PreyRenderer (B17, S3-C4, Sprint 3)"
	)
	report(
		"PENDING",
		"step 5",
		"a krill group in front of the creature, mass above 0 after 1 s: "
			.. "PreyService (B16, S3-C3, Sprint 3) and prey bites in BiteService (B18, S4-C2, Sprint 4)"
	)
end

local stepNumber: string
if STEP == "owner" then
	stepNumber = "step 2"
	owner()
elseif STEP == "moved" then
	stepNumber = "step 3"
	moved()
elseif STEP == "later" then
	stepNumber = "steps 4-5"
	later()
else
	stepNumber = STEP
	report("FAIL", "STEP", `unknown step "{STEP}"`)
end

local verdict = if counts.FAIL > 0
	then "FAIL"
	elseif counts.WAIT > 0 then "WAIT"
	elseif counts.PASS == 0 then "PENDING"
	else "PASS"
table.insert(lines, 1, `smoke {stepNumber}: {verdict}`)
return table.concat(lines, "\n")
