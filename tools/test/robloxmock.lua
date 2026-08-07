-- Minimal Roblox API mock, enough to execute a client script's load-time code
-- under plain Lua 5.1 and surface nil-index / typo errors.

local M = {}

local function signal()
    local s = {handlers = {}}
    function s:Connect(fn) table.insert(self.handlers, fn); return {Disconnect = function() end, disconnect = function() end} end
    function s:connect(fn) return self:Connect(fn) end
    function s:Wait()
        if coroutine.running() then return coroutine.yield() end
        return nil
    end
    function s:Fire(...) for _, h in ipairs(self.handlers) do h(...) end end
    return s
end
M.signal = signal

local Instance = {}
local instMeta

local function newInstance(class)
    return setmetatable({
        ClassName = class,
        Name = class,
        _children = {},
        _props = {},
        _signals = {},
        _attributes = {},
    }, instMeta)
end

local methods = {}

function methods:IsA(class)
    if self.ClassName == class then return true end
    local groups = {
        GuiObject = {Frame=1, TextButton=1, TextLabel=1, TextBox=1, ImageLabel=1, ImageButton=1, ScrollingFrame=1},
        GuiBase2d = {Frame=1, TextButton=1, TextLabel=1, TextBox=1, ImageLabel=1, ImageButton=1, ScrollingFrame=1, ScreenGui=1},
    }
    local g = groups[class]
    return (g and g[self.ClassName]) and true or false
end

function methods:GetChildren()
    local out = {}
    for i, c in ipairs(self._children) do out[i] = c end
    return out
end

function methods:GetDescendants()
    local out = {}
    local function walk(node)
        for _, c in ipairs(node._children) do
            table.insert(out, c)
            walk(c)
        end
    end
    walk(self)
    return out
end

function methods:FindFirstChild(name)
    for _, c in ipairs(self._children) do if c.Name == name then return c end end
    return nil
end

function methods:WaitForChild(name)
    local found = self:FindFirstChild(name)
    if found then return found end
    local c = newInstance("Folder")
    c.Name = name
    c.Parent = self
    return c
end

function methods:FindFirstChildOfClass(class)
    for _, c in ipairs(self._children) do if c.ClassName == class then return c end end
    return nil
end

function methods:FindFirstChildWhichIsA(class)
    for _, c in ipairs(self._children) do if c:IsA(class) or c.ClassName == class then return c end end
    return nil
end

function methods:FindFirstAncestor() return nil end
function methods:IsDescendantOf() return false end
function methods:Destroy()
    local p = rawget(self, "_parent")
    if p then
        for i, c in ipairs(p._children) do
            if c == self then table.remove(p._children, i) break end
        end
    end
    rawset(self, "_parent", nil)
end
function methods:Clone() return newInstance(self.ClassName) end
function methods:GetPropertyChangedSignal(prop)
    self._signals[prop] = self._signals[prop] or signal()
    return self._signals[prop]
end
function methods:SetAttribute(k, v) self._attributes[k] = v end
function methods:GetAttribute(k) return self._attributes[k] end
function methods:GetAttributeChangedSignal() return signal() end
function methods:TweenSize() end
function methods:TweenPosition() end
function methods:ApplyImpulse() end
function methods:Move() end
function methods:ChangeState() end
function methods:GetState()
    return self._props.State or M.Enum.HumanoidStateType.Running
end
function methods:BreakJoints() end
function methods:PivotTo() end
function methods:GetPivot() return M.CFrame.new() end
function methods:SetPrimaryPartCFrame() end
function methods:GetPlayers() return {} end
function methods:GetService(name) return M.services[name] end

local eventNames = {
    "Changed", "AncestryChanged", "ChildAdded", "ChildRemoved", "DescendantAdded",
    "DescendantRemoving", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up",
    "MouseEnter", "MouseLeave", "Activated", "InputBegan", "InputChanged", "InputEnded",
    "FocusLost", "Focused", "Touched", "TouchEnded", "Died", "CharacterAdded",
    "CharacterRemoving", "PlayerAdded", "PlayerRemoving", "StateChanged", "Heartbeat",
    "RenderStepped", "Stepped", "JumpRequest", "Ended", "Completed", "Triggered",
    "PromptButtonHoldBegan", "PromptButtonHoldEnded", "OnClientEvent", "Equipped",
    "Unequipped", "ChildRemoving", "SelectionChanged",
}
local isEvent = {}
for _, n in ipairs(eventNames) do isEvent[n] = true end

instMeta = {
    __index = function(t, k)
        if methods[k] then return methods[k] end
        if isEvent[k] then
            t._signals[k] = t._signals[k] or signal()
            return t._signals[k]
        end
        if k == "Parent" then return rawget(t, "_parent") end
        return rawget(t, "_props")[k]
    end,
    __newindex = function(t, k, v)
        if k == "Parent" then
            local old = rawget(t, "_parent")
            if old then
                for i, c in ipairs(old._children) do
                    if c == t then table.remove(old._children, i) break end
                end
            end
            rawset(t, "_parent", v)
            if v and v._children then table.insert(v._children, t) end
            return
        end
        rawget(t, "_props")[k] = v
        local s = rawget(t, "_signals")[k]
        if s then s:Fire() end
    end,
    __tostring = function(t) return t.Name end,
}

function Instance.new(class, parent)
    local i = newInstance(class)
    if parent then i.Parent = parent end
    return i
end
M.Instance = Instance

-- Value types -----------------------------------------------------------------
local function vec2(x, y) return {X = x or 0, Y = y or 0} end
M.Vector2 = {new = vec2, zero = vec2(0, 0)}

local Vector3mt = {}
Vector3mt.__index = Vector3mt
Vector3mt.__add = function(a, b) return M.Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3mt.__sub = function(a, b) return M.Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3mt.__mul = function(a, b)
    if type(b) == "number" then return M.Vector3.new(a.X * b, a.Y * b, a.Z * b) end
    return M.Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3mt.__div = function(a, b) return M.Vector3.new(a.X / b, a.Y / b, a.Z / b) end
Vector3mt.__unm = function(a) return M.Vector3.new(-a.X, -a.Y, -a.Z) end
function Vector3mt:Dot() return 0 end
function Vector3mt:Cross() return M.Vector3.new() end
function Vector3mt:Lerp() return self end
M.Vector3 = {
    new = function(x, y, z)
        local v = setmetatable({X = x or 0, Y = y or 0, Z = z or 0}, Vector3mt)
        local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
        v.Magnitude = m
        -- Built directly rather than through Vector3.new, which would recurse.
        if m > 0 then
            v.Unit = setmetatable({X = v.X / m, Y = v.Y / m, Z = v.Z / m, Magnitude = 1}, Vector3mt)
        else
            v.Unit = setmetatable({X = 0, Y = 0, Z = 0, Magnitude = 0}, Vector3mt)
        end
        v.Unit.Unit = v.Unit
        return v
    end,
}
M.Vector3.zero = M.Vector3.new(0, 0, 0)
M.Vector3.one = M.Vector3.new(1, 1, 1)

local CFramemt = {}
CFramemt.__index = CFramemt
CFramemt.__mul = function(a) return a end
function CFramemt:ToEulerAnglesYXZ() return 0, 0, 0 end
function CFramemt:ToWorldSpace() return self end
function CFramemt:ToObjectSpace() return self end
function CFramemt:Lerp() return self end
function CFramemt:Inverse() return self end
-- CFrame + Vector3 has to produce a real translation: the speed bypass walks
-- the root part forward that way, and the test asserts on where it ends up.
CFramemt.__add = function(a, v) return M.CFrame.new(a.Position + v) end
CFramemt.__sub = function(a, v) return M.CFrame.new(a.Position - v) end
M.CFrame = {
    new = function(x, y, z)
        local pos
        if type(x) == "table" then pos = x else pos = M.Vector3.new(x, y, z) end
        return setmetatable({p = pos, Position = pos,
            LookVector = M.Vector3.new(), RightVector = M.Vector3.new(), UpVector = M.Vector3.new()}, CFramemt)
    end,
    Angles = function() return M.CFrame.new() end,
    lookAt = function() return M.CFrame.new() end,
    fromEulerAnglesYXZ = function() return M.CFrame.new() end,
}

M.UDim = {new = function(s, o) return {Scale = s or 0, Offset = o or 0} end}
M.UDim2 = {
    new = function(xs, xo, ys, yo)
        return {X = M.UDim.new(xs, xo), Y = M.UDim.new(ys, yo)}
    end,
    fromScale = function(x, y) return M.UDim2.new(x, 0, y, 0) end,
    fromOffset = function(x, y) return M.UDim2.new(0, x, 0, y) end,
}
M.Color3 = {
    new = function(r, g, b) return {R = r or 0, G = g or 0, B = b or 0} end,
    fromRGB = function(r, g, b) return {R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255} end,
    fromHSV = function() return M.Color3.new() end,
}
M.ColorSequenceKeypoint = {new = function(t, c) return {Time = t, Value = c} end}
M.NumberSequenceKeypoint = {new = function(t, v, e) return {Time = t, Value = v, Envelope = e} end}
M.ColorSequence = {new = function(a) return {Keypoints = a} end}
M.NumberSequence = {new = function(a) return {Keypoints = a} end}
M.NumberRange = {new = function(a, b) return {Min = a, Max = b or a} end}
M.TweenInfo = {new = function(...) return {...} end}
M.Rect = {new = function(...) return {...} end}
M.Random = {new = function()
    return {NextNumber = function(_, a) return a or 0 end, NextInteger = function(_, a) return a or 0 end}
end}
M.RaycastParams = {new = function() return {} end}

-- Enum ------------------------------------------------------------------------
local enumItemMeta = {__tostring = function(t) return "Enum." .. t._enum .. "." .. t._name end}
local function enumNamespace(name)
    return setmetatable({}, {__index = function(t, k)
        local item = setmetatable({_enum = name, _name = k, Name = k, Value = 0}, enumItemMeta)
        rawset(t, k, item)
        return item
    end})
end
M.Enum = setmetatable({}, {__index = function(t, k)
    local ns = enumNamespace(k)
    rawset(t, k, ns)
    return ns
end})

-- Services --------------------------------------------------------------------
M.services = {}
local function service(name, class)
    local s = Instance.new(class or name)
    s.Name = name
    M.services[name] = s
    return s
end

local Players = service("Players")
local LocalPlayer = Instance.new("Player")
LocalPlayer.Name = "TestPlayer"
LocalPlayer.UserId = 1
Players.LocalPlayer = LocalPlayer
function Players:GetPlayers() return {LocalPlayer} end
local PlayerGui = Instance.new("PlayerGui")
PlayerGui.Name = "PlayerGui"
PlayerGui.Parent = LocalPlayer

local UIS = service("UserInputService")
function UIS:GetFocusedTextBox() return nil end
function UIS:IsKeyDown() return false end
function UIS:GetMouseLocation() return vec2(0, 0) end
UIS.TouchEnabled = true

local TweenService = service("TweenService")
-- Playing a tween snaps straight to its end state. Nothing here models time,
-- and the end state is what a test wants to assert on.
function TweenService:Create(obj, _, props)
    return {
        Play = function()
            if obj and type(props) == "table" then
                for k, v in pairs(props) do obj[k] = v end
            end
        end,
        Cancel = function() end,
        Completed = signal(),
    }
end

local RunService = service("RunService")
function RunService:IsStudio() return false end
function RunService:BindToRenderStep() end

-- A real (if minimal) JSON round trip, so config save/load is testable.
local Http = service("HttpService")

local function isArray(t)
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" then return false end
        n = n + 1
    end
    return n == #t
end

local function encode(v)
    local kind = type(v)
    if v == nil then return "null" end
    if kind == "boolean" or kind == "number" then return tostring(v) end
    if kind == "string" then return '"' .. v:gsub('[\\"]', '\\%0') .. '"' end
    if kind ~= "table" then return "null" end
    local parts = {}
    if isArray(v) then
        for _, item in ipairs(v) do table.insert(parts, encode(item)) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    -- Sorted so the output is stable between runs.
    local keys = {}
    for k in pairs(v) do table.insert(keys, tostring(k)) end
    table.sort(keys)
    for _, k in ipairs(keys) do
        table.insert(parts, encode(k) .. ":" .. encode(v[k]))
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local decodeValue

local function skipSpace(s, i)
    while i <= #s and s:sub(i, i):match("%s") do i = i + 1 end
    return i
end

local function decodeString(s, i)
    local out, j = {}, i + 1
    while j <= #s do
        local c = s:sub(j, j)
        if c == "\\" then
            table.insert(out, s:sub(j + 1, j + 1))
            j = j + 2
        elseif c == '"' then
            return table.concat(out), j + 1
        else
            table.insert(out, c)
            j = j + 1
        end
    end
    error("unterminated string in JSON")
end

function decodeValue(s, i)
    i = skipSpace(s, i)
    local c = s:sub(i, i)
    if c == '"' then return decodeString(s, i) end
    if c == "{" then
        local obj = {}
        i = skipSpace(s, i + 1)
        if s:sub(i, i) == "}" then return obj, i + 1 end
        while true do
            local key, val
            key, i = decodeString(s, skipSpace(s, i))
            i = skipSpace(s, i) + 1                     -- the ':'
            val, i = decodeValue(s, i)
            obj[key] = val
            i = skipSpace(s, i)
            if s:sub(i, i) == "," then i = i + 1 else return obj, i + 1 end
        end
    end
    if c == "[" then
        local arr = {}
        i = skipSpace(s, i + 1)
        if s:sub(i, i) == "]" then return arr, i + 1 end
        while true do
            local val
            val, i = decodeValue(s, i)
            table.insert(arr, val)
            i = skipSpace(s, i)
            if s:sub(i, i) == "," then i = i + 1 else return arr, i + 1 end
        end
    end
    local literal = s:match("^%a+", i)
    if literal == "true" then return true, i + 4 end
    if literal == "false" then return false, i + 5 end
    if literal == "null" then return nil, i + 4 end
    local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
    if num then return tonumber(num), i + #num end
    error("unexpected JSON at position " .. i)
end

function Http:JSONEncode(v) return encode(v) end
function Http:JSONDecode(s) return (decodeValue(s, 1)) end
function Http:GenerateGUID() return "guid" end

service("Lighting")
service("Workspace")
service("MaterialService")
service("ReplicatedStorage")
service("SoundService")
service("TeleportService")
service("ProximityPromptService")
service("CoreGui")
service("VirtualUser")
service("GuiService")
service("PhysicsService")
local StarterGui = service("StarterGui")
function StarterGui:SetCore() end
local Debris = service("Debris")
function Debris:AddItem() end
local CAS = service("ContextActionService")
function CAS:BindAction() end

local Stats = service("Stats")
local network = Instance.new("Folder")
network.Name = "Network"
network.Parent = Stats
Stats.Network = network
network.ServerStatsItem = setmetatable({}, {__index = function()
    return {GetValue = function() return 0 end}
end})

local Workspace = M.services.Workspace
Workspace.CurrentCamera = Instance.new("Camera")
Workspace.CurrentCamera.FieldOfView = 70
Workspace.CurrentCamera.CFrame = M.CFrame.new()
function Workspace:Raycast() return nil end
function Workspace:GetPartBoundsInRadius() return {} end

M.game = setmetatable({
    PlaceId = 1,
    JobId = "job",
    GetService = function(_, name)
        if not M.services[name] then service(name) end
        return M.services[name]
    end,
    IsLoaded = function() return true end,
    Loaded = signal(),
}, {__index = function(_, k) return M.services[k] end})

-- task / scheduler -------------------------------------------------------------
-- Deferred work runs on coroutines: task.wait yields, and M.pump() resumes a
-- bounded number of times so `while task.wait() do` loops can't hang the test.
M.deferred = 0
M.threads = {}
M.errors = {}

local function schedule(fn, ...)
    if type(fn) ~= "function" then return end
    M.deferred = M.deferred + 1
    local co = coroutine.create(fn)
    table.insert(M.threads, co)
    local ok, err = coroutine.resume(co, ...)
    if not ok then table.insert(M.errors, tostring(err)) end
end

M.task = {
    spawn = function(fn, ...) schedule(fn, ...) end,
    defer = function(fn, ...) schedule(fn, ...) end,
    delay = function(_, fn, ...) schedule(fn, ...) end,
    wait = function()
        if coroutine.running() then return coroutine.yield() or 0 end
        return 0
    end,
    cancel = function() end,
    synchronize = function() end,
}

function M.pump(rounds)
    for _ = 1, rounds or 3 do
        local live = {}
        for _, co in ipairs(M.threads) do
            if coroutine.status(co) == "suspended" then
                local ok, err = coroutine.resume(co, 0)
                if not ok then
                    table.insert(M.errors, tostring(err))
                elseif coroutine.status(co) == "suspended" then
                    table.insert(live, co)
                end
            end
        end
        M.threads = live
    end
    return M.errors
end

return M
