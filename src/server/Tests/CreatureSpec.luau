--!strict
-- Engine-side spec of PlayerLifecycle and CreatureService (docs/09, sections 5.1 and 6.1 to 6.8).
-- It needs one real player, so it runs in a play test through the RunTests hook (section 16.3):
-- it checks the join that already happened (slot, the 6.1 tree, Character, ownership,
-- ReplicationFocus, attributes), mass and tier, then runs the leave and a fresh join for the same
-- player, which leaves the session as it found it. With no player (CI) it registers one note.
-- The pure parts (SlotPool, TierMath, PolicyRules) are covered in Lune by tests/unit/Logic.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Index = require(ReplicatedStorage.Shared.Data.Index)
local TestKit = require(ReplicatedStorage.Shared.Util.TestKit)
local TierMath = require(ReplicatedStorage.Shared.Logic.TierMath)

local CreatureService = require("../Services/CreatureService")
local PlayerLifecycle = require("../Services/PlayerLifecycle")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local WAIT = 10 -- seconds a join may take (policy call, ClientReady)

-- Waits until `ready()` holds or WAIT seconds pass; returns whether it held.
local function waitFor(ready: () -> boolean): boolean
	local from = os.clock()
	while not ready() do
		if os.clock() - from > WAIT then
			return false
		end
		task.wait(0.05)
	end
	return true
end

local function spawned(player: Player): boolean
	local slot = PlayerLifecycle.getSlot(player)
	return slot ~= nil and CreatureService.get(slot) ~= nil and player.Character ~= nil
end

local function child(parent: Instance, name: string, class: string): Instance
	local found = parent:FindFirstChild(name)
	assert(found and found:IsA(class), `{parent.Name}.{name} should be a {class}`)
	return found
end

return function()
	describe("PlayerLifecycle and CreatureService (engine)", function()
		local player = Players:GetPlayers()[1]
		if not player then
			it("(no player in this session: run it in a play test)", function() end)
			return
		end

		it("joined the player: a slot, both lookups and the Slot attribute", function()
			expect(waitFor(function()
				return spawned(player)
			end)).toBe(true)
			local slot = PlayerLifecycle.getSlot(player) :: number
			expect(slot >= 1 and slot <= 24 and slot == math.floor(slot)).toBe(true)
			expect(PlayerLifecycle.getPlayer(slot)).toBe(player)
			expect(player:GetAttribute("Slot")).toBe(slot)
		end)

		it("built the tree of 6.1 in workspace.Creatures", function()
			local slot = PlayerLifecycle.getSlot(player) :: number
			local state = assert(CreatureService.get(slot))
			local model, root = state.model, state.root
			expect(model.Name).toBe(`Creature_{player.UserId}`)
			expect(model.Parent).toBe(workspace:FindFirstChild("Creatures"))
			expect(model.PrimaryPart).toBe(root)
			expect(model.ModelStreamingMode).toBe(Enum.ModelStreamingMode.Atomic)
			expect(#model:GetChildren()).toBe(1)
			expect(model:FindFirstChildWhichIsA("Humanoid", true)).toBe(nil)
			expect(model:FindFirstChildWhichIsA("AnimationController", true)).toBe(nil)

			expect(root.Name).toBe("Root")
			expect(root.Shape).toBe(Enum.PartType.Ball)
			expect(root.Transparency).toBe(1)
			expect(root.CanCollide).toBe(true)
			expect(root.CanTouch).toBe(false)
			expect(root.CanQuery).toBe(true)
			expect(root.CastShadow).toBe(false)
			expect(root.Anchored).toBe(false)
			expect(root.CollisionGroup).toBe("Creature")
			local physics = root.CustomPhysicalProperties :: PhysicalProperties
			expect(physics.Density).toBeCloseTo(1, 1e-6)
			expect(physics.Friction).toBeCloseTo(0, 1e-6)
			expect(physics.Elasticity).toBeCloseTo(0.2, 1e-6)
			local radiusMult = Index.Species.byId[state.species].radiusMult
			expect(root.Size.X).toBeCloseTo(1.8 * state.bodyScale * radiusMult, 1e-4)
			expect(root.Size.Y).toBeCloseTo(root.Size.X, 1e-4)
			expect(#root:GetChildren()).toBe(3)

			local attachment = child(root, "RootAttachment", "Attachment")
			local move = child(root, "Move", "LinearVelocity") :: LinearVelocity
			expect(move.Attachment0).toBe(attachment)
			expect(move.VelocityConstraintMode).toBe(Enum.VelocityConstraintMode.Vector)
			expect(move.RelativeTo).toBe(Enum.ActuatorRelativeTo.World)
			expect(move.MaxForce).toBe(1e6)
			local turn = child(root, "Turn", "AlignOrientation") :: AlignOrientation
			expect(turn.Attachment0).toBe(attachment)
			expect(turn.Mode).toBe(Enum.OrientationAlignmentMode.OneAttachment)
			expect(turn.Responsiveness).toBe(40)
			expect(turn.MaxTorque).toBe(1e6)
		end)

		it("assigned it: Character, owner, ReplicationFocus, the public attributes", function()
			local slot = PlayerLifecycle.getSlot(player) :: number
			local state = assert(CreatureService.get(slot))
			expect(player.Character).toBe(state.model)
			expect(state.root:GetNetworkOwner()).toBe(player)
			expect(player.ReplicationFocus).toBe(state.root)
			expect(player:GetAttribute("Phase")).toBe("cove")
			expect(player:GetAttribute("Species")).toBe(state.species)
			expect(player:GetAttribute("Tier")).toBe(state.tier)
			expect(state.tier).toBe(TierMath.tier(state.mass))
			expect(state.bodyScale).toBeCloseTo(TierMath.bodyScale(state.mass), 1e-9)
			expect(PlayerLifecycle.policy(player).AreAdsAllowed ~= nil).toBe(true)
		end)

		it(
			"returns it to the cove spawn, and the owner's MovementController keeps it there",
			function()
				-- The owner swims from the moment it spawns (MovementController, S2-C4), so the spawn
				-- point is checked through a server teleport, which the owner's copy obeys (spike S4).
				local slot = PlayerLifecycle.getSlot(player) :: number
				local state = assert(CreatureService.get(slot))
				local want = CreatureService.coveSpawnCFrame(slot).Position
				CreatureService.teleport(slot, CreatureService.coveSpawnCFrame(slot))
				task.wait(0.5)
				expect((state.root.Position - want).Magnitude < 2).toBe(true)
			end
		)

		it("derives tier and size from mass: Root.Size by the 3% rule, onTierChanged", function()
			local slot = PlayerLifecycle.getSlot(player) :: number
			local state = assert(CreatureService.get(slot))
			local startMass = state.mass
			local heard: { number } = {}
			local connection = CreatureService.onTierChanged:connect(function(s: number, t: number)
				if s == slot then
					table.insert(heard, t)
				end
			end)
			local ok, problem = pcall(function()
				CreatureService.addMass(slot, 10 - startMass) -- to mass 10: tier 2
				expect(state.tier).toBe(2)
				expect(player:GetAttribute("Tier")).toBe(2)
				expect(state.root.Size.X).toBeCloseTo(1.8 * 1.3, 1e-4)
				CreatureService.addMass(slot, 0.2) -- scale 1.3 to 1.304: under 3%, no write
				expect(state.bodyScale).toBeCloseTo(1.304, 1e-9)
				expect(state.root.Size.X).toBeCloseTo(1.8 * 1.3, 1e-4)
				CreatureService.addMass(slot, 5) -- scale 1.404: 8% more, a write
				expect(state.root.Size.X).toBeCloseTo(1.8 * 1.404, 1e-4)
				CreatureService.addMass(slot, startMass - state.mass) -- back down: tier 1
				expect(state.tier).toBe(TierMath.tier(startMass))
				expect(heard).toEqual({ 2, state.tier })
				expect(state.root.Size.X).toBeCloseTo(1.8 * state.bodyScale, 1e-4)
			end)
			connection:disconnect()
			assert(ok, problem)
		end)

		it("frees the slot on leave, and a fresh join builds the creature again", function()
			local slot = PlayerLifecycle.getSlot(player) :: number
			local oldModel = assert(CreatureService.get(slot)).model
			local left, ready = 0, 0
			local leaving = PlayerLifecycle.onLeaving:connect(function(p: Player, s: number)
				if p == player and s == slot then
					left += 1
				end
			end)
			local readied = PlayerLifecycle.onReady:connect(function(p: Player)
				if p == player then
					ready += 1
				end
			end)
			local ok, problem = pcall(function()
				PlayerLifecycle._test.leave(player)
				expect(left).toBe(1)
				expect(PlayerLifecycle.getSlot(player)).toBe(nil)
				expect(PlayerLifecycle.getPlayer(slot)).toBe(nil)
				expect(CreatureService.get(slot)).toBe(nil)
				expect(oldModel.Parent).toBe(nil)
				expect(player.Character).toBe(nil)

				PlayerLifecycle._test.join(player)
				PlayerLifecycle._test.clientReady(player)
				expect(waitFor(function()
					return spawned(player)
				end)).toBe(true)
				expect(ready).toBe(1)
				local again = PlayerLifecycle.getSlot(player) :: number
				expect(again).toBe(slot) -- the lowest free slot, the one just freed
				local state = assert(CreatureService.get(again))
				expect(player.Character).toBe(state.model)
				expect(state.root:GetNetworkOwner()).toBe(player)
				expect(player.ReplicationFocus).toBe(state.root)
			end)
			leaving:disconnect()
			readied:disconnect()
			assert(ok, problem)
		end)
	end)
end
