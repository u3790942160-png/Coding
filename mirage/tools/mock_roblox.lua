-- Minimal Roblox runtime stand-in, enough to boot the bundle headlessly
-- and exercise the solvers. It is a test rig, not an emulator.
local M = {}

-- ── Vector3 ──────────────────────────────────────────────────────────
local V3 = {}
V3.__index = V3

local function v3(x, y, z)
	return setmetatable({X = x or 0, Y = y or 0, Z = z or 0}, V3)
end

function V3.__add(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
function V3.__sub(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
function V3.__unm(a) return v3(-a.X, -a.Y, -a.Z) end
function V3.__eq(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
function V3.__mul(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
function V3.__div(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
function V3.__tostring(a) return string.format("(%.2f, %.2f, %.2f)", a.X, a.Y, a.Z) end
function V3:Dot(o) return self.X * o.X + self.Y * o.Y + self.Z * o.Z end
function V3:Cross(o)
	return v3(self.Y * o.Z - self.Z * o.Y, self.Z * o.X - self.X * o.Z, self.X * o.Y - self.Y * o.X)
end
function V3:Lerp(o, t) return self + (o - self) * t end
V3.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif key == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		if m == 0 then return v3(0, 0, 0) end
		return v3(self.X / m, self.Y / m, self.Z / m)
	end
	return rawget(V3, key)
end

Vector3 = {new = function(x, y, z) return v3(x, y, z) end, zero = v3(0, 0, 0)}
M.v3 = v3

-- ── Vector2 ──────────────────────────────────────────────────────────
local V2 = {}
local function v2(x, y) return setmetatable({X = x or 0, Y = y or 0}, V2) end
V2.__add = function(a, b) return v2(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return v2(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b)
	if type(b) == "number" then return v2(a.X * b, a.Y * b) end
	return v2(a.X * b.X, a.Y * b.Y)
end
V2.__index = function(self, key)
	if key == "Magnitude" then return math.sqrt(self.X * self.X + self.Y * self.Y) end
	if key == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y)
		if m == 0 then return v2(0, 0) end
		return v2(self.X / m, self.Y / m)
	end
	return rawget(V2, key)
end
Vector2 = {new = function(x, y) return v2(x, y) end}

-- ── CFrame ───────────────────────────────────────────────────────────
-- Stored as position plus the three basis vectors. LookVector is -Z, as
-- in Roblox.
local CF = {}
local function cfRaw(pos, xv, yv, zv)
	return setmetatable({p = pos, xv = xv, yv = yv, zv = zv}, CF)
end

local function cfIdentity(pos)
	return cfRaw(pos or v3(0, 0, 0), v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1))
end

CF.__index = function(self, key)
	if key == "Position" or key == "p" then return rawget(self, "p") end
	if key == "X" then return rawget(self, "p").X end
	if key == "Y" then return rawget(self, "p").Y end
	if key == "Z" then return rawget(self, "p").Z end
	if key == "LookVector" then return -rawget(self, "zv") end
	if key == "RightVector" then return rawget(self, "xv") end
	if key == "UpVector" then return rawget(self, "yv") end
	return rawget(CF, key)
end

function CF.__mul(a, b)
	if getmetatable(b) == V3 then
		local p, xv, yv, zv = rawget(a, "p"), rawget(a, "xv"), rawget(a, "yv"), rawget(a, "zv")
		return p + xv * b.X + yv * b.Y + zv * b.Z
	end
	local ap, ax, ay, az = rawget(a, "p"), rawget(a, "xv"), rawget(a, "yv"), rawget(a, "zv")
	local bp, bx, by, bz = rawget(b, "p"), rawget(b, "xv"), rawget(b, "yv"), rawget(b, "zv")
	local function rot(v) return ax * v.X + ay * v.Y + az * v.Z end
	return cfRaw(ap + rot(bp), rot(bx), rot(by), rot(bz))
end

function CF:VectorToWorldSpace(v)
	return rawget(self, "xv") * v.X + rawget(self, "yv") * v.Y + rawget(self, "zv") * v.Z
end
function CF:VectorToObjectSpace(v)
	return v3(v:Dot(rawget(self, "xv")), v:Dot(rawget(self, "yv")), v:Dot(rawget(self, "zv")))
end
function CF:PointToWorldSpace(v) return rawget(self, "p") + self:VectorToWorldSpace(v) end
function CF:PointToObjectSpace(v) return self:VectorToObjectSpace(v - rawget(self, "p")) end
function CF:ToWorldSpace(other) return self * other end
function CF:Lerp(other, t)
	local p = rawget(self, "p"):Lerp(rawget(other, "p"), t)
	local zv = (rawget(self, "zv"):Lerp(rawget(other, "zv"), t)).Unit
	local up = v3(0, 1, 0)
	local xv = up:Cross(zv)
	if xv.Magnitude < 1e-5 then xv = v3(1, 0, 0) else xv = xv.Unit end
	local yv = zv:Cross(xv)
	return cfRaw(p, xv, yv, zv)
end
function CF:Inverse()
	local p, xv, yv, zv = rawget(self, "p"), rawget(self, "xv"), rawget(self, "yv"), rawget(self, "zv")
	local np = v3(-p:Dot(xv), -p:Dot(yv), -p:Dot(zv))
	return cfRaw(np, v3(xv.X, yv.X, zv.X), v3(xv.Y, yv.Y, zv.Y), v3(xv.Z, yv.Z, zv.Z))
end

CFrame = {}
function CFrame.new(a, b, c)
	if type(a) == "number" then return cfIdentity(v3(a, b or 0, c or 0)) end
	if a == nil then return cfIdentity(v3(0, 0, 0)) end
	return cfIdentity(a)
end
function CFrame.lookAt(from, target, up)
	up = up or v3(0, 1, 0)
	local dir = (target - from)
	if dir.Magnitude < 1e-6 then dir = v3(0, 0, -1) else dir = dir.Unit end
	local zv = -dir
	local xv = up:Cross(zv)
	if xv.Magnitude < 1e-6 then xv = v3(1, 0, 0) else xv = xv.Unit end
	local yv = zv:Cross(xv)
	return cfRaw(from, xv, yv, zv)
end
function CFrame.Angles(rx, ry, rz)
	local function mul(a, b) return a * b end
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)
	local xv = v3(cy * cz, cy * sz, -sy)
	local yv = v3(sx * sy * cz - cx * sz, sx * sy * sz + cx * cz, sx * cy)
	local zv = v3(cx * sy * cz + sx * sz, cx * sy * sz - sx * cz, cx * cy)
	return cfRaw(v3(0, 0, 0), xv, yv, zv)
end
M.cfRaw = cfRaw

-- ── simple value types ───────────────────────────────────────────────
Color3 = {
	new = function(r, g, b) return {R = r or 0, G = g or 0, B = b or 0} end,
	fromRGB = function(r, g, b) return {R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255} end,
	fromHSV = function(h, s, v) return {R = h or 0, G = s or 0, B = v or 0} end,
}
UDim = {new = function(s, o) return {Scale = s or 0, Offset = o or 0} end}
UDim2 = {
	new = function(xs, xo, ys, yo)
		return {X = UDim.new(xs, xo), Y = UDim.new(ys, yo)}
	end,
	fromOffset = function(x, y) return UDim2.new(0, x or 0, 0, y or 0) end,
	fromScale = function(x, y) return UDim2.new(x or 0, 0, y or 0, 0) end,
}
NumberSequenceKeypoint = {new = function(t, v) return {Time = t, Value = v} end}
NumberSequence = {new = function(a, b) return {a, b} end}
ColorSequenceKeypoint = {new = function(t, v) return {Time = t, Value = v} end}
ColorSequence = {new = function(a, b) return {a, b} end}
TweenInfo = {new = function(...) return {...} end}
Random = {
	new = function()
		return {
			NextNumber = function(_, a, b)
				a = a or 0
				b = b or 1
				return a + math.random() * (b - a)
			end,
			NextInteger = function(_, a, b) return math.random(a, b) end,
		}
	end,
}
RaycastParams = {new = function() return {} end}

-- ── Enum ─────────────────────────────────────────────────────────────
local enumItemMt = {__tostring = function(s) return "Enum." .. s.Name end}
local function enumCategory(catName)
	return setmetatable({}, {
		__index = function(tbl, key)
			local item = setmetatable({Name = key, Value = 0, Category = catName}, enumItemMt)
			rawset(tbl, key, item)
			return item
		end,
	})
end
Enum = setmetatable({}, {
	__index = function(tbl, key)
		local cat = enumCategory(key)
		rawset(tbl, key, cat)
		return cat
	end,
})

-- ── Signals ──────────────────────────────────────────────────────────
local Signal = {}
Signal.__index = Signal
local function newSignal(name)
	return setmetatable({name = name, handlers = {}}, Signal)
end
function Signal:Connect(fn)
	local entry = {fn = fn, alive = true}
	table.insert(self.handlers, entry)
	return {
		Disconnect = function() entry.alive = false end,
		Connected = true,
	}
end
Signal.connect = Signal.Connect
function Signal:Fire(...)
	for _, h in ipairs(self.handlers) do
		if h.alive then h.fn(...) end
	end
end
function Signal:Wait() return nil end
M.newSignal = newSignal

-- ── Instance ─────────────────────────────────────────────────────────
local hierarchy = {
	Part = {"BasePart", "PVInstance", "Instance"},
	MeshPart = {"BasePart", "PVInstance", "Instance"},
	Model = {"PVInstance", "Instance"},
	Humanoid = {"Instance"},
	Accessory = {"Instance"},
	RemoteEvent = {"Instance"},
	RemoteFunction = {"Instance"},
	Frame = {"GuiObject", "GuiBase2d", "Instance"},
	TextLabel = {"GuiObject", "GuiBase2d", "Instance"},
	TextButton = {"GuiObject", "GuiBase2d", "Instance"},
	TextBox = {"GuiObject", "GuiBase2d", "Instance"},
	ImageButton = {"GuiObject", "GuiBase2d", "Instance"},
	ImageLabel = {"GuiObject", "GuiBase2d", "Instance"},
	ProximityPrompt = {"Instance"},
	ClickDetector = {"Instance"},
	IntValue = {"ValueBase", "Instance"},
	StringValue = {"ValueBase", "Instance"},
	ScrollingFrame = {"GuiObject", "GuiBase2d", "Instance"},
	ScreenGui = {"LayerCollector", "Instance"},
	Trail = {"Instance"},
	Attachment = {"Instance"},
	Highlight = {"Instance"},
	Motor6D = {"JointInstance", "Instance"},
	Weld = {"JointInstance", "Instance"},
	SpecialMesh = {"Instance"},
}

local InstMt = {}
local allInstances = {}

local function defaultsFor(class)
	local d = {}
	if class == "Part" or class == "MeshPart" then
		d.Position = v3(0, 0, 0)
		d.CFrame = CFrame.new(0, 0, 0)
		d.Size = v3(1, 1, 1)
		d.Anchored = false
		d.CanCollide = true
		d.CanQuery = true
		d.CanTouch = true
		d.Massless = false
		d.Transparency = 0
		d.LocalTransparencyModifier = 0
		d.Color = Color3.new(1, 1, 1)
		d.Material = Enum.Material.Plastic
		d.Shape = Enum.PartType.Block
		d.AssemblyLinearVelocity = v3(0, 0, 0)
		d.AssemblyAngularVelocity = v3(0, 0, 0)
		d.Velocity = v3(0, 0, 0)
		d.CustomPhysicalProperties = nil
	elseif class == "Humanoid" then
		d.Health = 100
		d.MaxHealth = 100
		d.WalkSpeed = 16
		d.MoveDirection = v3(0, 0, 0)
		d.RigType = Enum.HumanoidRigType.R15
	elseif class == "ScreenGui" then
		d.Enabled = true
	elseif class == "Frame" or class == "TextLabel" or class == "TextButton"
		or class == "TextBox" or class == "ScrollingFrame"
		or class == "ImageButton" or class == "ImageLabel" then
		d.Visible = true
		d.Text = ""
		d.LayoutOrder = 0
		d.AbsolutePosition = v2(0, 0)
		d.AbsoluteSize = v2(100, 30)
		d.BackgroundTransparency = 0
	elseif class == "ProximityPrompt" then
		d.ActionText = ""
		d.ObjectText = ""
		d.Enabled = true
	elseif class == "IntValue" or class == "StringValue" then
		d.Value = 0
	end
	return d
end

local function newInstance(class, parent)
	local self = {
		ClassName = class,
		Name = class,
		props = defaultsFor(class),
		children = {},
		attributes = {},
		signals = {},
		Parent = nil,
	}
	setmetatable(self, InstMt)
	allInstances[#allInstances + 1] = self
	if parent then self.Parent = parent end
	return self
end

local instanceMethods = {}

function instanceMethods:IsA(class)
	if self.ClassName == class then return true end
	local chain = hierarchy[self.ClassName]
	if chain then
		for _, c in ipairs(chain) do
			if c == class then return true end
		end
	end
	return class == "Instance"
end

function instanceMethods:GetChildren()
	local out = {}
	for _, c in ipairs(rawget(self, "children")) do out[#out + 1] = c end
	return out
end

function instanceMethods:GetDescendants()
	local out = {}
	local function walk(node)
		for _, c in ipairs(rawget(node, "children")) do
			out[#out + 1] = c
			walk(c)
		end
	end
	walk(self)
	return out
end

function instanceMethods:FindFirstChild(name)
	for _, c in ipairs(rawget(self, "children")) do
		if c.Name == name then return c end
	end
	return nil
end

function instanceMethods:WaitForChild(name) return self:FindFirstChild(name) end

function instanceMethods:FindFirstChildOfClass(class)
	for _, c in ipairs(rawget(self, "children")) do
		if c.ClassName == class then return c end
	end
	return nil
end
instanceMethods.FindFirstChildWhichIsA = function(self, class)
	for _, c in ipairs(rawget(self, "children")) do
		if c:IsA(class) then return c end
	end
	return nil
end

function instanceMethods:FindFirstAncestorOfClass(class)
	local p = rawget(self, "Parent")
	while p do
		if p.ClassName == class then return p end
		p = rawget(p, "Parent")
	end
	return nil
end

function instanceMethods:Destroy()
	local parent = rawget(self, "Parent")
	if parent then
		local kids = rawget(parent, "children")
		for i, c in ipairs(kids) do
			if c == self then table.remove(kids, i) break end
		end
	end
	rawset(self, "Parent", nil)
	rawset(self, "destroyed", true)
end

function instanceMethods:Clone()
	local copy = newInstance(self.ClassName)
	copy.Name = self.Name
	for k, v in pairs(rawget(self, "props")) do copy.props[k] = v end
	return copy
end

function instanceMethods:GetAttribute(name) return rawget(self, "attributes")[name] end
function instanceMethods:SetAttribute(name, v) rawget(self, "attributes")[name] = v end
function instanceMethods:BreakJoints() end
function instanceMethods:GetState() return Enum.HumanoidStateType.Running end
function instanceMethods:Move() end
function instanceMethods:GetPropertyChangedSignal(name)
	local sigs = rawget(self, "signals")
	sigs["prop_" .. name] = sigs["prop_" .. name] or newSignal(name)
	return sigs["prop_" .. name]
end
function instanceMethods:GetBoundingBox()
	local props = rawget(self, "props")
	return props.CFrame or CFrame.new(0, 0, 0), props.Size or v3(4, 4, 4)
end
function instanceMethods:GetNetworkOwner() error("server only") end
function instanceMethods:FireServer() rawset(self, "fired", (rawget(self, "fired") or 0) + 1) end
function instanceMethods:InvokeServer() return nil end
function instanceMethods:GetRankInGroup() return 0 end
function instanceMethods:PivotTo() end
function instanceMethods:GetPivot() return rawget(self, "props").CFrame end

local autoSignals = {
	Changed = true, InputBegan = true, InputEnded = true, InputChanged = true,
	MouseButton1Click = true, MouseEnter = true, MouseLeave = true,
	FocusLost = true, ChildAdded = true, DescendantAdded = true,
	CharacterAdded = true, Idled = true, Touched = true,
}

InstMt.__index = function(self, key)
	local props = rawget(self, "props")
	if props[key] ~= nil then return props[key] end
	local m = instanceMethods[key]
	if m then return m end
	if autoSignals[key] then
		local sigs = rawget(self, "signals")
		sigs[key] = sigs[key] or newSignal(key)
		return sigs[key]
	end
	-- unknown child lookup by name, Roblox style
	for _, c in ipairs(rawget(self, "children")) do
		if c.Name == key then return c end
	end
	return nil
end

InstMt.__newindex = function(self, key, value)
	if key == "Parent" then
		local old = rawget(self, "Parent")
		if old then
			local kids = rawget(old, "children")
			for i, c in ipairs(kids) do
				if c == self then table.remove(kids, i) break end
			end
		end
		rawset(self, "Parent", value)
		if value then table.insert(rawget(value, "children"), self) end
		return
	end
	if key == "Name" or key == "ClassName" then
		rawset(self, key, value)
		return
	end
	local props = rawget(self, "props")
	if key == "CFrame" then
		props.CFrame = value
		props.Position = value.Position
		return
	end
	if key == "Position" then
		props.Position = value
		props.CFrame = CFrame.new(value)
		return
	end
	props[key] = value
end

Instance = {new = function(class, parent) return newInstance(class, parent) end}
M.newInstance = newInstance
M.allInstances = allInstances

-- ── globals ──────────────────────────────────────────────────────────
function typeof(v)
	local mt = getmetatable(v)
	if mt == V3 then return "Vector3" end
	if mt == V2 then return "Vector2" end
	if mt == CF then return "CFrame" end
	if mt == InstMt then return "Instance" end
	return type(v)
end

warn = function(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	M.warnings = M.warnings or {}
	table.insert(M.warnings, table.concat(parts, " "))
end

task = {
	wait = function(t) return t or 0 end,
	spawn = function(fn, ...) local ok, err = pcall(fn, ...) if not ok then warn("task.spawn: " .. tostring(err)) end end,
	delay = function(_, fn, ...)
		M.delayed = M.delayed or {}
		table.insert(M.delayed, {fn = fn, args = table.pack(...)})
	end,
	defer = function(fn, ...) return task.spawn(fn, ...) end,
}
wait = function(t) return t or 0 end

-- executor side globals, enough to drive the hook and touch paths
M.hooks = {}
M.namecallMethod = "FireServer"
M.selfcall = false
M.touches = 0

function hookmetamethod(_, name, fn)
	M.hooks[name] = fn
	return function() return nil end
end
function getnamecallmethod() return M.namecallMethod end
function checkcaller() return M.selfcall end
function firetouchinterest() M.touches = M.touches + 1 end
function fireproximityprompt(p)
	M.prompts = (M.prompts or 0) + 1
	if M.onPrompt then M.onPrompt(p) end
end
function fireclickdetector(c)
	M.clicks = (M.clicks or 0) + 1
	if M.onClick then M.onClick(c) end
end
function getconnections(sig)
	local out = {}
	if type(sig) == "table" and rawget(sig, "handlers") then
		for _, h in ipairs(rawget(sig, "handlers")) do
			if h.alive then
				out[#out + 1] = {Fire = function() return h.fn() end, Function = h.fn}
			end
		end
	end
	return out
end
function getgenv() return _G end

-- Pretend the game fired a remote from its own code.
function M.FireFromGame(remote, ...)
	local hook = M.hooks["__namecall"]
	if not hook then return false end
	local was = M.selfcall
	M.selfcall = false
	local ok = pcall(hook, remote, ...)
	M.selfcall = was
	return ok
end

if math.atan2 == nil then
	math.atan2 = function(y, x) return math.atan(y, x) end
end

M.V3mt = V3
M.CFmt = CF
return M
