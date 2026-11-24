-- @module svc
-- Service handles, local player plumbing, character accessors.
local Svc = {}

Svc.Players          = game:GetService("Players")
Svc.RunService       = game:GetService("RunService")
Svc.UserInputService = game:GetService("UserInputService")
Svc.ContextAction    = game:GetService("ContextActionService")
Svc.TweenService     = game:GetService("TweenService")
Svc.HttpService      = game:GetService("HttpService")
Svc.Lighting         = game:GetService("Lighting")
Svc.ReplicatedStorage= game:GetService("ReplicatedStorage")
Svc.TeleportService  = game:GetService("TeleportService")
Svc.StarterGui       = game:GetService("StarterGui")
Svc.Stats            = game:GetService("Stats")
Svc.GuiService       = game:GetService("GuiService")
Svc.Workspace        = workspace

Svc.LP = Svc.Players.LocalPlayer
if not Svc.LP then
	Svc.LP = Svc.Players:GetPropertyChangedSignal("LocalPlayer") and Svc.Players.LocalPlayer
end

function Svc.Camera()
	return Svc.Workspace.CurrentCamera
end

function Svc.Char(plr)
	plr = plr or Svc.LP
	if not plr then return nil end
	local c = plr.Character
	if not c or not c.Parent then return nil end
	return c
end

function Svc.Hum(plr)
	local c = Svc.Char(plr)
	if not c then return nil end
	return c:FindFirstChildOfClass("Humanoid")
end

function Svc.HRP(plr)
	local c = Svc.Char(plr)
	if not c then return nil end
	return c:FindFirstChild("HumanoidRootPart")
end

function Svc.Head(plr)
	local c = Svc.Char(plr)
	if not c then return nil end
	return c:FindFirstChild("Head")
end

function Svc.Alive(plr)
	local h = Svc.Hum(plr)
	return h ~= nil and h.Health > 0
end

-- Foot part used as the touch source for reach. R6 and R15 both covered.
function Svc.Foot(plr)
	local c = Svc.Char(plr)
	if not c then return nil end
	local names = {"RightFoot", "LeftFoot", "Right Leg", "Left Leg", "RightLowerLeg", "LeftLowerLeg"}
	for _, n in ipairs(names) do
		local p = c:FindFirstChild(n)
		if p and p:IsA("BasePart") then return p end
	end
	return Svc.HRP(plr)
end

function Svc.Parts(plr)
	local out = {}
	local c = Svc.Char(plr)
	if not c then return out end
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("BasePart") then out[#out + 1] = d end
	end
	return out
end

function Svc.Others()
	local out = {}
	for _, p in ipairs(Svc.Players:GetPlayers()) do
		if p ~= Svc.LP then out[#out + 1] = p end
	end
	return out
end

function Svc.Ping()
	local ok, v = pcall(function()
		return Svc.Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	if ok and type(v) == "number" and v == v then return v end
	return 0
end

function Svc.Fps()
	local ok, v = pcall(function() return Svc.Workspace:GetRealPhysicsFPS() end)
	if ok and type(v) == "number" then return v end
	return 60
end

function Svc.ViewportSize()
	local cam = Svc.Camera()
	if cam then return cam.ViewportSize end
	return Vector2.new(1280, 720)
end

function Svc.PlayerGui()
	local lp = Svc.LP
	if not lp then return nil end
	return lp:FindFirstChildOfClass("PlayerGui")
end

-- Every visible TextLabel / TextButton under the player's own GUI.
function Svc.VisibleTexts()
	local out = {}
	local pg = Svc.PlayerGui()
	if not pg then return out end
	for _, d in ipairs(pg:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local ok, visible = pcall(function()
				return d.Visible and d.Text ~= nil and d.Text ~= ""
			end)
			if ok and visible then out[#out + 1] = d end
		end
	end
	return out
end

-- Walk up from a GuiObject until a ScreenGui, reporting whether the whole
-- chain is visible. A label inside a hidden frame is not on screen.
function Svc.ChainVisible(gui)
	local node = gui
	local hops = 0
	while node and hops < 24 do
		if node:IsA("ScreenGui") then return node.Enabled end
		if node:IsA("GuiObject") and not node.Visible then return false end
		node = node.Parent
		hops = hops + 1
	end
	return false
end

function Svc.Leaderstats()
	local lp = Svc.LP
	if not lp then return nil end
	return lp:FindFirstChild("leaderstats")
end

-- Models in the workspace that carry a Humanoid but no Player: NPCs.
function Svc.Npcs()
	local out = {}
	local taken = {}
	for _, p in ipairs(Svc.Players:GetPlayers()) do
		if p.Character then taken[p.Character] = true end
	end
	for _, d in ipairs(Svc.Workspace:GetDescendants()) do
		if d:IsA("Model") and not taken[d] and d:FindFirstChildOfClass("Humanoid") then
			out[#out + 1] = d
		end
	end
	return out
end

function Svc.ModelPos(model)
	if not model then return nil end
	local ok, cf = pcall(function()
		if model.PrimaryPart then return model.PrimaryPart.CFrame end
		local c = model:GetBoundingBox()
		return c
	end)
	if ok and cf then return cf.Position end
	local part = model:FindFirstChildWhichIsA("BasePart")
	if part then return part.Position end
	return nil
end

function Svc.Teleport(position)
	local hrp = Svc.HRP()
	if not hrp or not position then return false end
	local ok = pcall(function()
		hrp.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
	end)
	return ok
end

function Svc.IsMobile()
	local uis = Svc.UserInputService
	return uis.TouchEnabled and not uis.KeyboardEnabled
end

function Svc.IsGamepad()
	return Svc.UserInputService.GamepadEnabled
end

return Svc
