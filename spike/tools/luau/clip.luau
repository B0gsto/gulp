-- Builds the stand-in swim clip (S0-A2/S8) as a KeyframeSequence for the imported RIG_Fish skeleton.
-- Runs unchanged in Lune (offline, to upload as an Animation asset) and in Studio (RegisterAnimationClip fallback).
-- R = { Instance, CFrame, Vector3, Enum }; rootPart = the imported RootPart holding the bones.
-- A sideways body wave on Spine2, Spine1, Spine3, Spine4 and TailFin; 16 frames at 30 fps; last frame = first.
-- Jaw and the Girth bones get no pose, so code can own them (the Bone.Transform test).
return function(R, rootPart)
	local AMP = { Spine1 = 0.10, Spine2 = 0.06, Spine3 = 0.16, Spine4 = 0.26, TailFin = 0.36 }
	local PHASE = { Spine1 = -0.6, Spine2 = 0, Spine3 = 0.7, Spine4 = 1.4, TailFin = 2.1 }
	local SKIP = { Jaw = true, Girth_Top = true, Girth_Bot = true, Girth_L = true, Girth_R = true }
	local period, frames = 16 / 30, 16
	local world = {}
	local function rest(b, parentWorld)
		world[b] = parentWorld * b.CFrame
		for _, c in b:GetChildren() do
			if c.ClassName == "Bone" then rest(c, world[b]) end
		end
	end
	for _, c in rootPart:GetChildren() do
		if c.ClassName == "Bone" then rest(c, R.CFrame.new()) end
	end
	local kfs = R.Instance.new("KeyframeSequence")
	kfs.Name = "A_Fish_Swim_Stand"
	kfs.Loop = true
	kfs.Priority = R.Enum.AnimationPriority.Core
	for i = 0, frames do
		local t = i / 30
		local kf = R.Instance.new("Keyframe")
		kf.Time = t
		kf.Parent = kfs
		local rp = R.Instance.new("Pose")
		rp.Name = rootPart.Name
		rp.Weight = 0
		rp.Parent = kf
		local function pose(b, parentPose)
			if SKIP[b.Name] then return end
			local p = R.Instance.new("Pose")
			p.Name = b.Name
			local a = AMP[b.Name]
			if a then
				local axis = world[b]:VectorToObjectSpace(R.Vector3.new(0, 1, 0))
				p.CFrame = R.CFrame.fromAxisAngle(axis, a * math.sin(2 * math.pi * t / period - PHASE[b.Name]))
				p.Weight = 1
			else
				p.Weight = 0
			end
			p.Parent = parentPose
			for _, c in b:GetChildren() do
				if c.ClassName == "Bone" then pose(c, p) end
			end
		end
		for _, c in rootPart:GetChildren() do
			if c.ClassName == "Bone" then pose(c, rp) end
		end
	end
	return kfs
end
