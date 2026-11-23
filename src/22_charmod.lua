-- @module charmod
-- Local rig and appearance work. The server keeps whatever character it
-- gave you; everything here changes what your client draws.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local AM     = _R("amath")
local Env    = _R("env")
local Notify = _R("notify")

local CM = {}

local rig = nil
local rigJoints = {}
local rigWeld = nil
local hiddenParts = {}
local swingClock = 0
local addedAccessories = {}
local maid = Util.Maid.new()

-- R6 part sizes are engine constants, not anything read from this game.
local R6_SIZES = {
	HumanoidRootPart = Vector3.new(2, 2, 1),
	Torso            = Vector3.new(2, 2, 1),
	Head             = Vector3.new(2, 1, 1),
	["Left Arm"]     = Vector3.new(1, 2, 1),
	["Right Arm"]    = Vector3.new(1, 2, 1),
	["Left Leg"]     = Vector3.new(1, 2, 1),
	["Right Leg"]    = Vector3.new(1, 2, 1),
}

local function skinColour(char, want)
	-- pull the nearest matching colour off the real rig so the clone is you
	local map = {
		Head = {"Head"},
		Torso = {"UpperTorso", "Torso", "LowerTorso"},
		["Left Arm"] = {"LeftUpperArm", "Left Arm", "LeftLowerArm"},
		["Right Arm"] = {"RightUpperArm", "Right Arm", "RightLowerArm"},
		["Left Leg"] = {"LeftUpperLeg", "Left Leg", "LeftLowerLeg"},
		["Right Leg"] = {"RightUpperLeg", "Right Leg", "RightLowerLeg"},
	}
	local names = map[want]
	if names and char then
		for _, n in ipairs(names) do
			local p = char:FindFirstChild(n)
			if p and p:IsA("BasePart") then return p.Color end
		end
	end
	return Color3.fromRGB(205, 165, 125)
end

local function makePart(name, size, colour, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.Parent = parent
	return p
end

local function joint(name, part0, part1, c0, c1)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.Parent = part0
	return m
end

function CM.BuildR6()
	CM.DestroyR6()
	local char = Svc.Char()
	local hrp = Svc.HRP()
	if not char or not hrp then return false, "no character" end

	rig = Instance.new("Model")
	rig.Name = "LC_R6"
	rig.Parent = Svc.Workspace.CurrentCamera or Svc.Workspace

	local root = makePart("HumanoidRootPart", R6_SIZES.HumanoidRootPart, Color3.new(1, 1, 1), rig)
	root.Transparency = 1
	rig.PrimaryPart = root

	local torso = makePart("Torso", R6_SIZES.Torso, skinColour(char, "Torso"), rig)
	local head  = makePart("Head", R6_SIZES.Head, skinColour(char, "Head"), rig)

	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = head

	local la = makePart("Left Arm",  R6_SIZES["Left Arm"],  skinColour(char, "Left Arm"), rig)
	local ra = makePart("Right Arm", R6_SIZES["Right Arm"], skinColour(char, "Right Arm"), rig)
	local ll = makePart("Left Leg",  R6_SIZES["Left Leg"],  skinColour(char, "Left Leg"), rig)
	local rl = makePart("Right Leg", R6_SIZES["Right Leg"], skinColour(char, "Right Leg"), rig)

	joint("RootJoint", root, torso, CFrame.new(0, 0, 0) * CFrame.Angles(-math.pi / 2, 0, math.pi), CFrame.new(0, 0, 0) * CFrame.Angles(-math.pi / 2, 0, math.pi))
	rigJoints.neck = joint("Neck", torso, head, CFrame.new(0, 1, 0) * CFrame.Angles(-math.pi / 2, 0, math.pi), CFrame.new(0, -0.5, 0) * CFrame.Angles(-math.pi / 2, 0, math.pi))
	rigJoints.rs = joint("Right Shoulder", torso, ra, CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0), CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0))
	rigJoints.ls = joint("Left Shoulder",  torso, la, CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0), CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0))
	rigJoints.rh = joint("Right Hip", torso, rl, CFrame.new(1, -1, 0) * CFrame.Angles(0, math.pi / 2, 0), CFrame.new(0.5, 1, 0) * CFrame.Angles(0, math.pi / 2, 0))
	rigJoints.lh = joint("Left Hip",  torso, ll, CFrame.new(-1, -1, 0) * CFrame.Angles(0, -math.pi / 2, 0), CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, -math.pi / 2, 0))

	rigWeld = Instance.new("Weld")
	rigWeld.Part0 = hrp
	rigWeld.Part1 = root
	rigWeld.C0 = CFrame.new(0, 0, 0)
	rigWeld.Parent = hrp

	return true
end

-- The real rig keeps moving underneath; we just stop drawing it.
local function hideReal(state)
	local char = Svc.Char()
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			if state then
				hiddenParts[d] = true
				pcall(function() d.LocalTransparencyModifier = 1 end)
			else
				pcall(function() d.LocalTransparencyModifier = 0 end)
			end
		elseif d:IsA("Decal") then
			pcall(function() d.Transparency = state and 1 or 0 end)
		end
	end
	if not state then hiddenParts = {} end
end

-- Procedural walk. No animation asset ids are used anywhere, because none
-- for this build were ever handed over and inventing one is not on.
function CM.StepR6(dt)
	if not Cfg.s.character.r6 then
		if rig then CM.DestroyR6() end
		return
	end

	local char = Svc.Char()
	local hrp = Svc.HRP()
	local hum = Svc.Hum()
	if not char or not hrp or not hum then return end

	if not rig or not rig.Parent or not rigWeld or rigWeld.Part0 ~= hrp then
		local ok = CM.BuildR6()
		if not ok then return end
	end

	hideReal(true)

	local planar = AM.Flat(hrp.AssemblyLinearVelocity).Magnitude
	local moving = planar > 1.5
	local airborne = hum:GetState() == Enum.HumanoidStateType.Freefall
		or hum:GetState() == Enum.HumanoidStateType.Jumping

	swingClock = swingClock + dt * (moving and math.max(planar * 0.5, 4) or 2)

	local amp = moving and math.min(planar / 16, 1) * 0.9 or 0.0
	local swing = math.sin(swingClock) * amp
	local counter = -swing

	if airborne then
		swing = 1.4
		counter = 1.4
	end

	local function setJoint(j, base, angle)
		if not j then return end
		j.Transform = CFrame.Angles(angle, 0, 0)
	end

	setJoint(rigJoints.rs, nil, swing)
	setJoint(rigJoints.ls, nil, counter)
	setJoint(rigJoints.rh, nil, counter * 0.9)
	setJoint(rigJoints.lh, nil, swing * 0.9)
	if rigJoints.neck then
		rigJoints.neck.Transform = CFrame.Angles(0, 0, 0)
	end
end

function CM.DestroyR6()
	if rigWeld then pcall(function() rigWeld:Destroy() end) rigWeld = nil end
	if rig then pcall(function() rig:Destroy() end) rig = nil end
	rigJoints = {}
	hideReal(false)
end

-- ── Appearance ───────────────────────────────────────────────────────
function CM.StripAccessories()
	local char = Svc.Char()
	if not char then return 0 end
	local removed = 0
	for _, d in ipairs(char:GetChildren()) do
		if d:IsA("Accessory") or d:IsA("Hat") then
			pcall(function() d:Destroy() end)
			removed = removed + 1
		end
	end
	Notify.Info("accessories", removed .. " removed locally")
	return removed
end

function CM.ApplyOwnAvatar()
	local char = Svc.Char()
	local lp = Svc.LP
	if not char or not lp then return false end
	local ok, model = pcall(function()
		return Svc.Players:GetCharacterAppearanceAsync(lp.UserId)
	end)
	if not ok or not model then
		Notify.Warn("own avatar", "the client could not fetch your appearance here")
		return false
	end
	local count = 0
	for _, item in ipairs(model:GetChildren()) do
		if item:IsA("Accessory") then
			local clone = item:Clone()
			clone.Parent = char
			addedAccessories[#addedAccessories + 1] = clone
			count = count + 1
		elseif item:IsA("BodyColors") then
			local existing = char:FindFirstChildOfClass("BodyColors")
			if existing then pcall(function() existing:Destroy() end) end
			local clone = item:Clone()
			clone.Parent = char
		elseif item:IsA("ShirtGraphic") or item:IsA("Shirt") or item:IsA("Pants") then
			local clone = item:Clone()
			clone.Parent = char
			addedAccessories[#addedAccessories + 1] = clone
		end
	end
	pcall(function() model:Destroy() end)
	Notify.Good("own avatar", count .. " items applied locally")
	return true
end

-- Load one asset id and attach whatever accessory it contains.
function CM.WearAsset(assetId, label)
	if assetId == nil or assetId <= 0 then return false end
	local char = Svc.Char()
	if not char then return false end
	if not Env.canAssets then
		Notify.Once("asset_gate", label or "asset",
			"this executor exposes no getobjects, so an asset id cannot be loaded client side.", "warn")
		return false
	end

	local ok, objects = pcall(function()
		return Env.getobjects("rbxassetid://" .. tostring(math.floor(assetId)))
	end)
	if not ok or type(objects) ~= "table" or #objects == 0 then
		Notify.Warn(label or "asset", "asset " .. tostring(assetId) .. " did not load")
		return false
	end

	local worn = 0
	for _, obj in ipairs(objects) do
		if obj:IsA("Accessory") or obj:IsA("Hat") then
			obj.Parent = char
			addedAccessories[#addedAccessories + 1] = obj
			worn = worn + 1
		else
			for _, sub in ipairs(obj:GetDescendants()) do
				if sub:IsA("Accessory") then
					sub.Parent = char
					addedAccessories[#addedAccessories + 1] = sub
					worn = worn + 1
				end
			end
		end
	end

	if worn == 0 then
		Notify.Warn(label or "asset", "no accessory inside asset " .. tostring(assetId))
		return false
	end
	Notify.Good(label or "asset", worn .. " attached locally")
	return true
end

function CM.ClearAdded()
	for _, inst in ipairs(addedAccessories) do
		if inst and inst.Parent then pcall(function() inst:Destroy() end) end
	end
	addedAccessories = {}
end

function CM.Step(dt)
	CM.StepR6(dt)
	if Cfg.s.character.stripAccs then
		local char = Svc.Char()
		if char then
			for _, d in ipairs(char:GetChildren()) do
				if d:IsA("Accessory") or d:IsA("Hat") then
					pcall(function() d:Destroy() end)
				end
			end
		end
	end
end

function CM.Destroy()
	CM.DestroyR6()
	CM.ClearAdded()
	maid:Clean()
end

return CM
