--[[
	A deliberately small Roblox API stand-in so the hub can be executed under
	plain Lua 5.4. It is not an emulator: it exists to prove the script loads,
	builds its interface, restores config and survives being poked, without a
	single nil-index or ordering mistake.
]]

local mock = {}

--==============================================================================
-- Signals
--==============================================================================

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ connections = {} }, Signal)
end

function Signal:Connect(fn)
	local connection = { Connected = true, Function = fn }
	function connection:Disconnect() self.Connected = false end
	table.insert(self.connections, connection)
	return connection
end

function Signal:Once(fn) return self:Connect(fn) end

-- Yields like the real thing: scripts that loop on Signal:Wait() must give the
-- scheduler a chance to run, otherwise they spin forever.
function Signal:Wait()
	if coroutine.isyieldable() then coroutine.yield() end
	return nil
end

function Signal:Fire(...)
	for _, connection in ipairs(self.connections) do
		if connection.Connected then
			local ok, err = pcall(connection.Function, ...)
			if not ok then error(err, 0) end
		end
	end
end

mock.Signal = Signal

--==============================================================================
-- Scheduler: task.* backed by coroutines that the harness steps manually
--==============================================================================

local threads = {}

local task = {}

function task.spawn(fn, ...)
	local co = coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then error(err, 0) end
	if coroutine.status(co) ~= "dead" then table.insert(threads, co) end
	return co
end

function task.defer(fn, ...) return task.spawn(fn, ...) end

function task.delay(_, fn, ...) return task.spawn(fn, ...) end

function task.wait(_)
	if coroutine.isyieldable() then coroutine.yield() end
	return 0
end

function task.cancel() end

function mock.step(times)
	for _ = 1, times or 1 do
		local alive = {}
		for _, co in ipairs(threads) do
			if coroutine.status(co) == "suspended" then
				local ok, err = coroutine.resume(co)
				if not ok then error(err, 0) end
				if coroutine.status(co) ~= "dead" then table.insert(alive, co) end
			end
		end
		threads = alive
	end
end

mock.task = task

--==============================================================================
-- Datatypes
--==============================================================================

local function enumClass(name)
	return setmetatable({}, {
		__index = function(class, key)
			local item = { Name = key, Value = 0, EnumType = name }
			rawset(class, key, item)
			return item
		end,
	})
end

local Enum = setmetatable({}, {
	__index = function(t, key)
		local class = enumClass(key)
		rawset(t, key, class)
		return class
	end,
})

local Vector3 = {}
Vector3.__index = Vector3

local function vec3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end

Vector3.new = function(x, y, z) return vec3(x, y, z) end
Vector3.__add = function(a, b) return vec3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3.__sub = function(a, b) return vec3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3.__mul = function(a, b)
	if type(b) == "number" then return vec3(a.X * b, a.Y * b, a.Z * b) end
	return vec3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
	elseif key == "Unit" then
		local m = math.max(math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2), 1e-6)
		return vec3(self.X / m, self.Y / m, self.Z / m)
	end
	return rawget(Vector3, key)
end
Vector3.Lerp = function(_, goal) return goal end
Vector3.zero = vec3(0, 0, 0)

local CFrameMT = {}
CFrameMT.__index = function(self, key)
	if key == "LookVector" then return vec3(0, 0, -1) end
	if key == "Position" then return rawget(self, "_position") end
	return rawget(CFrameMT, key)
end
CFrameMT.__mul = function(a) return a end

function CFrameMT:ToEulerAnglesYXZ() return 0, 0, 0 end
function CFrameMT:ToEulerAnglesXYZ() return 0, 0, 0 end
function CFrameMT:Inverse() return self end
function CFrameMT:VectorToWorldSpace(v) return v end

local Vector2 = { new = function(x, y) return { X = x or 0, Y = y or 0 } end }

local UDim  = { new = function(scale, offset) return { Scale = scale or 0, Offset = offset or 0 } end }
local UDim2 = {
	new = function(xs, xo, ys, yo)
		return {
			X = { Scale = xs or 0, Offset = xo or 0 },
			Y = { Scale = ys or 0, Offset = yo or 0 },
		}
	end,
}

local Color3 = {
	fromRGB = function(r, g, b)
		return { R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255 }
	end,
	new = function(r, g, b) return { R = r or 0, G = g or 0, B = b or 0 } end,
}

local Rect              = { new = function(...) return { ... } end }
local TweenInfo         = { new = function(...) return { ... } end }
local ColorSequence     = { new = function(...) return { ... } end }
local ColorSequenceKeypoint = { new = function(...) return { ... } end }
local function cframe(position)
	local self = setmetatable({}, CFrameMT)
	rawset(self, "_position", position or vec3(0, 0, 0))
	return self
end

local CFrame = {
	new = function(a, b, c)
		if type(a) == "number" then return cframe(vec3(a, b, c)) end
		return cframe(a)
	end,
	Angles = function() return cframe() end,
	lookAt = function(from) return cframe(from) end,
}

local RaycastParams = { new = function() return {} end }

--==============================================================================
-- Instances
--==============================================================================

local Instance = {}
local instanceMethods = {}

local function fireChanged(self, property)
	local signals = rawget(self, "_changed")
	if signals and signals[property] then signals[property]:Fire() end
end

local InstanceMT = {
	__index = function(self, key)
		local method = instanceMethods[key]
		if method then return method end

		local props = rawget(self, "_props")
		if props[key] ~= nil then return props[key] end

		for _, child in ipairs(rawget(self, "_children")) do
			if rawget(child, "_props").Name == key then return child end
		end
		return nil
	end,

	__newindex = function(self, key, value)
		if key == "Parent" then
			local previous = rawget(self, "_props").Parent
			if previous then
				local siblings = rawget(previous, "_children")
				for index, child in ipairs(siblings) do
					if child == self then table.remove(siblings, index) break end
				end
			end
			rawget(self, "_props").Parent = value
			if value then table.insert(rawget(value, "_children"), self) end
			return
		end
		rawget(self, "_props")[key] = value
		fireChanged(self, key)
	end,
}

local DEFAULTS = {
	Name = "Instance",
	Text = "",
	Visible = true,
	Rotation = 0,
	Health = 100,
	MaxHealth = 100,
	TextTransparency = 0,
	BackgroundTransparency = 0,
	Transparency = 0,
	Scale = 1,
	Enabled = true,
	AutoRotate = true,
	WalkSpeed = 16,
	Anchored = false,
}

function Instance.new(className, parent)
	local self = setmetatable({}, InstanceMT)
	rawset(self, "_props", {})
	rawset(self, "_children", {})
	rawset(self, "_changed", {})
	rawset(self, "_class", className)

	for key, value in pairs(DEFAULTS) do rawget(self, "_props")[key] = value end
	rawget(self, "_props").Name = className
	rawget(self, "_props").Position = UDim2.new(0, 0, 0, 0)
	rawget(self, "_props").Size = UDim2.new(0, 100, 0, 100)
	rawget(self, "_props").AbsolutePosition = Vector2.new(0, 0)
	rawget(self, "_props").AbsoluteSize = Vector2.new(200, 20)

	for _, event in ipairs({
		"MouseButton1Click", "MouseEnter", "MouseLeave", "InputBegan",
		"InputChanged", "InputEnded", "FocusLost", "Changed",
		"DescendantAdded", "AncestryChanged", "Died", "ChildAdded",
		"PromptButtonHoldBegan", "Triggered",
	}) do
		rawget(self, "_props")[event] = Signal.new()
	end

	if parent then self.Parent = parent end
	return self
end

function instanceMethods:IsA(className)
	local class = rawget(self, "_class")
	if class == className then return true end
	local guiClasses = {
		Frame = { "GuiObject" }, TextLabel = { "GuiObject" },
		TextButton = { "GuiObject" }, TextBox = { "GuiObject" },
	}
	for _, parentClass in ipairs(guiClasses[class] or {}) do
		if parentClass == className then return true end
	end
	return false
end

function instanceMethods:GetChildren()
	local copy = {}
	for _, child in ipairs(rawget(self, "_children")) do table.insert(copy, child) end
	return copy
end

function instanceMethods:GetDescendants()
	local out = {}
	for _, child in ipairs(rawget(self, "_children")) do
		table.insert(out, child)
		for _, sub in ipairs(child:GetDescendants()) do table.insert(out, sub) end
	end
	return out
end

function instanceMethods:FindFirstChild(name)
	for _, child in ipairs(rawget(self, "_children")) do
		if rawget(child, "_props").Name == name then return child end
	end
	return nil
end

function instanceMethods:FindFirstChildOfClass(className)
	for _, child in ipairs(rawget(self, "_children")) do
		if rawget(child, "_class") == className then return child end
	end
	return nil
end

instanceMethods.FindFirstChildWhichIsA = instanceMethods.FindFirstChildOfClass
instanceMethods.WaitForChild = function(self, name)
	return self:FindFirstChild(name) or Instance.new("Folder", self)
end

function instanceMethods:Destroy()
	self.Parent = nil
	rawget(self, "_children")
	for _, child in ipairs(self:GetChildren()) do child:Destroy() end
end

function instanceMethods:Clone() return Instance.new(rawget(self, "_class")) end

function instanceMethods:GetPropertyChangedSignal(property)
	local signals = rawget(self, "_changed")
	signals[property] = signals[property] or Signal.new()
	return signals[property]
end

function instanceMethods:IsFocused() return false end
function instanceMethods:GetPlayingAnimationTracks() return {} end
function instanceMethods:ChangeState() end
function instanceMethods:Move() end
function instanceMethods:EquipTool() end
function instanceMethods:Activate() end
function instanceMethods:FireServer() end
function instanceMethods:GetState() return Enum.HumanoidStateType.Running end
function instanceMethods:GetPivot() return { Position = Vector3.new(0, 0, 0) } end
function instanceMethods:SetAttribute() end
function instanceMethods:GetAttribute() return nil end

mock.Instance = Instance

--==============================================================================
-- Services
--==============================================================================

local playerGui = Instance.new("PlayerGui")
playerGui.Name = "PlayerGui"

local localPlayer = Instance.new("Player")
localPlayer.Name = "TestPlayer"
localPlayer.DisplayName = "TestPlayer"
localPlayer.UserId = 1
playerGui.Parent = localPlayer
localPlayer.CharacterAdded = Signal.new()

local services = {}

services.Players = Instance.new("Players")
services.Players.LocalPlayer = localPlayer
services.Players.GetPlayers = function() return { localPlayer } end

services.RunService = Instance.new("RunService")
services.RunService.Heartbeat     = Signal.new()
services.RunService.RenderStepped = Signal.new()
services.RunService.Stepped       = Signal.new()

services.UserInputService = Instance.new("UserInputService")
services.UserInputService.InputBegan   = Signal.new()
services.UserInputService.InputChanged = Signal.new()
services.UserInputService.InputEnded   = Signal.new()
services.UserInputService.TouchEnabled = false
services.UserInputService.IsKeyDown = function() return false end
services.UserInputService.GetFocusedTextBox = function() return nil end

services.TweenService = Instance.new("TweenService")
services.TweenService.Create = function(_, instance, _, goal)
	return {
		Play = function()
			for key, value in pairs(goal) do instance[key] = value end
		end,
		Cancel = function() end,
		Completed = Signal.new(),
	}
end

services.HttpService = Instance.new("HttpService")
services.HttpService.JSONEncode = function(_, value) return mock.encode(value) end
services.HttpService.JSONDecode = function(_, text) return mock.decode(text) end

services.Stats = Instance.new("Stats")
services.Lighting = Instance.new("Lighting")
services.CoreGui = Instance.new("CoreGui")

local game = Instance.new("DataModel")
game.GetService = function(_, name)
	services[name] = services[name] or Instance.new(name)
	return services[name]
end
game.IsLoaded = function() return true end
game.GetDescendants = function() return {} end

mock.game        = game
mock.services    = services
mock.localPlayer = localPlayer
mock.playerGui   = playerGui

--==============================================================================
-- World fixtures: a character, an opponent and a plot with a steal prompt
--==============================================================================

local players = { localPlayer }
services.Players.GetPlayers = function() return players end

local function makePart(name, parent, position)
	local part = Instance.new("Part", parent)
	part.Name                    = name
	part.Position                = position or Vector3.new(0, 0, 0)
	part.Size                    = Vector3.new(2, 2, 1)
	part.Velocity                = Vector3.new(0, 0, 0)
	part.RotVelocity             = Vector3.new(0, 0, 0)
	part.AssemblyLinearVelocity  = Vector3.new(0, 0, 0)
	part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	part.CFrame                  = CFrame.new(position or Vector3.new(0, 0, 0))
	part.CanCollide              = true
	part.IsA = function(_, className)
		return className == "BasePart" or className == "Part"
	end
	return part
end

function mock.spawnCharacter(player, position)
	local character = Instance.new("Model")
	character.Name = player.Name

	makePart("HumanoidRootPart", character, position)
	makePart("Head", character, position)

	local humanoid = Instance.new("Humanoid", character)
	humanoid.Name          = "Humanoid"
	humanoid.MoveDirection = Vector3.new(1, 0, 0)
	humanoid.HipHeight     = 2
	humanoid.Jump          = false
	humanoid.PlatformStand = false

	local tool = Instance.new("Tool", character)
	tool.Name = "Bat"
	tool.IsA  = function(_, className) return className == "Tool" end

	player.Character = character
	return character
end

function mock.addOpponent(name, position)
	local player = Instance.new("Player")
	player.Name        = name
	player.DisplayName = name
	table.insert(players, player)
	mock.spawnCharacter(player, position)
	return player
end

function mock.buildPlots()
	local plots = Instance.new("Model")
	plots.Name = "Plots"

	for index = 1, 2 do
		local plot = Instance.new("Model", plots)
		plot.Name = "Plot" .. index
		plot.IsA  = function(_, className) return className == "Model" end

		local sign    = Instance.new("Part", plot)
		sign.Name     = "PlotSign"
		local surface = Instance.new("SurfaceGui", sign)
		surface.Name  = "SurfaceGui"
		local frame   = Instance.new("Frame", surface)
		frame.Name    = "Frame"
		local text    = Instance.new("TextLabel", frame)
		text.Name     = "TextLabel"
		text.Text     = "Rival" .. index .. "'s Base"

		local podiums = Instance.new("Model", plot)
		podiums.Name  = "AnimalPodiums"

		for slot = 1, 2 do
			local podium = Instance.new("Model", podiums)
			podium.Name  = "Podium" .. slot
			podium.IsA   = function(_, className) return className == "Model" end

			local base  = makePart("Base", podium)
			local spawn = makePart("Spawn", base)
			local attachment = Instance.new("Attachment", spawn)
			attachment.Name  = "PromptAttachment"

			local prompt = Instance.new("ProximityPrompt", attachment)
			prompt.Name  = "Prompt"
			prompt.IsA   = function(_, className) return className == "ProximityPrompt" end

			-- Give the prompt the client callbacks the steal engine copies out.
			prompt.PromptButtonHoldBegan:Connect(function() end)
			prompt.Triggered:Connect(function() end)
		end
	end

	return plots
end

--==============================================================================
-- Minimal JSON (config round-trip only)
--==============================================================================

function mock.encode(value)
	local t = type(value)
	if t == "table" then
		local isArray = #value > 0
		local parts = {}
		if isArray then
			for _, item in ipairs(value) do table.insert(parts, mock.encode(item)) end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		for key, item in pairs(value) do
			table.insert(parts, string.format("%q", tostring(key)) .. ":" .. mock.encode(item))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif t == "string" then
		return string.format("%q", value)
	elseif t == "number" or t == "boolean" then
		return tostring(value)
	end
	return "null"
end

function mock.decode() return {} end

--==============================================================================
-- Globals installed into the sandbox
--==============================================================================

function mock.install(env)
	local workspace = Instance.new("Workspace")

	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.new(Vector3.new(0, 10, 0))
	workspace.CurrentCamera = camera
	workspace.Raycast = function(_, origin)
		return { Position = Vector3.new(origin.X, -8, origin.Z), Instance = nil }
	end
	mock.workspace = workspace

	env.game      = game
	env.workspace = workspace
	env.Instance  = Instance
	env.Enum      = Enum
	env.Vector2   = Vector2
	env.Vector3   = Vector3
	env.UDim      = UDim
	env.UDim2     = UDim2
	env.Color3    = Color3
	env.Rect      = Rect
	env.TweenInfo = TweenInfo
	env.CFrame    = CFrame
	env.ColorSequence = ColorSequence
	env.ColorSequenceKeypoint = ColorSequenceKeypoint
	env.RaycastParams = RaycastParams
	env.task      = task
	env.tick      = os.clock
	env.warn      = function(...) print("[warn]", ...) end
	env.typeof    = function(value)
		if type(value) == "table" then
			if getmetatable(value) == InstanceMT then return "Instance" end
			if getmetatable(value) == Signal then return "RBXScriptSignal" end
			if type(value.Disconnect) == "function" then return "RBXScriptConnection" end
		end
		return type(value)
	end

	math.clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end
	env._G = env._G or {}
	return env
end

return mock
