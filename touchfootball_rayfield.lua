--!nocheck
-- touchfootball_rayfield.lua
-- Touch Football (Roblox) feature suite with Rayfield UI.
-- Every value in CFG carries provenance. Game-specific names are UNSET and
-- gated; everything built on engine APIs (Humanoid, CFrame, Camera, workspace)
-- runs without a dump.
-- Executor requirements: loadstring enabled, HttpGet for the Rayfield fetch.
-- Optional-API guards are used for hookfunction/getconnections/setfflag.

----------------------------------------------------------------------
-- CONFIG  (provenance: kind | build | source | verified)
----------------------------------------------------------------------

local CFG = {
    -- [name | unknown | no dump supplied | not verified]
    -- Paste the exact ball Instance name from the DISCOVERY tab.
    BallNameOverride = "",

    -- [name | unknown | no dump supplied | not verified]
    -- Container the ball lives in once in play. Empty = scan whole workspace.
    BallParentOverride = "",

    -- [name | unknown | no dump supplied | not verified]
    -- RemoteEvent used by the game to request a catch. Empty = feature gated off.
    CatchRemoteName = "",

    -- [name | unknown | no dump supplied | not verified]
    -- RemoteEvent used by the game to throw. Empty = feature gated off.
    ThrowRemoteName = "",

    -- [constant | engine | Workspace.Gravity read at runtime | verified live]
    GravityFallback = 196.2,

    -- Name patterns used to GUESS the ball when no override is set.
    -- This is a hypothesis, not a confirmed identity.
    BallPatterns = { "football", "ball", "pigskin", "pball" },
}

local HAS = {
    ball_name   = CFG.BallNameOverride ~= "",
    ball_parent = CFG.BallParentOverride ~= "",
    catch_remote= CFG.CatchRemoteName ~= "",
    throw_remote= CFG.ThrowRemoteName ~= "",
}

----------------------------------------------------------------------
-- SERVICES / STATE
----------------------------------------------------------------------

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local Workspace          = game:GetService("Workspace")
local Lighting           = game:GetService("Lighting")
local TweenService       = game:GetService("TweenService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local StarterGui         = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

local S = {
    -- movement
    SpeedOn = false, SpeedValue = 16,
    JumpOn = false, JumpValue = 50,
    InfJump = false,
    NoClip = false,
    Fly = false, FlySpeed = 60,
    AntiRagdoll = false,

    -- ball
    BallEsp = false,
    BallTracer = false,
    BallPredict = false,
    Magnet = false, MagnetRadius = 25,
    AutoCatch = false, AutoCatchRadius = 60,
    BallFollow = false,

    -- aim
    AimOn = false, AimKeyHeld = false,
    AimFov = 180, AimSmooth = 0.25,
    AimPart = "Head",
    AimTeamCheck = false,
    AimVisibleOnly = false,
    AimTarget = nil,

    -- esp
    EspOn = false, EspName = true, EspDist = true,
    EspBox = true, EspHighlight = false, EspTracer = false,
    EspTeamColor = true, EspMaxDist = 1500,

    -- misc
    FullBright = false, NoFog = false,
    Fov = 70,
    HitboxOn = false, HitboxSize = 6,

    -- bookkeeping
    LastGravity = CFG.GravityFallback,
    Notices = {},
}

local Drawings  = {}   -- [player] = { box = {...}, tracer = ..., text = ... }
local Highlights= {}   -- [player] = Highlight
local OrigHitbox= {}   -- [humanoidRootPart] = Vector3
local BallDraw  = { tracer = nil, dot = nil, path = {} }
local Conns     = {}

local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = dur or 4 })
    end)
    print(("[TF] %s: %s"):format(title, text))
end

local function gateOff(feature, missing)
    if S.Notices[feature] then return end
    S.Notices[feature] = true
    notify("Feature gated", ("%s disabled: %s is UNSET. Use DISCOVERY tab."):format(feature, missing), 6)
end

----------------------------------------------------------------------
-- VALIDATION HELPERS  (a partial/implausible read is a failure, not a zero)
----------------------------------------------------------------------

local function isFiniteNumber(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function isPlausibleVector(v)
    if typeof(v) ~= "Vector3" then return false end
    if not (isFiniteNumber(v.X) and isFiniteNumber(v.Y) and isFiniteNumber(v.Z)) then return false end
    local LIMIT = 1e6
    return math.abs(v.X) < LIMIT and math.abs(v.Y) < LIMIT and math.abs(v.Z) < LIMIT
end

local function alive(plr)
    local ch = plr and plr.Character
    if not ch or not ch.Parent then return nil end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    local root = ch:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return nil end
    if hum.Health <= 0 then return nil end
    return ch, hum, root
end

local function myChar()
    return alive(LocalPlayer)
end

local function partOf(ch, name)
    if not ch then return nil end
    local p = ch:FindFirstChild(name)
    if p and p:IsA("BasePart") then return p end
    return ch:FindFirstChild("HumanoidRootPart")
end

----------------------------------------------------------------------
-- BALL RESOLVER
----------------------------------------------------------------------

local function nameLooksLikeBall(n)
    local low = string.lower(n)
    for _, pat in ipairs(CFG.BallPatterns) do
        if string.find(low, pat, 1, true) then return true end
    end
    return false
end

local function searchRoot()
    if HAS.ball_parent then
        local p = Workspace:FindFirstChild(CFG.BallParentOverride)
        if p then return p end
    end
    return Workspace
end

-- Returns part, tierString
local function getBall()
    local root = searchRoot()
    if HAS.ball_name then
        local b = root:FindFirstChild(CFG.BallNameOverride, true)
        if b and b:IsA("BasePart") then return b, "confirmed" end
        if b and b:IsA("Model") and b.PrimaryPart then return b.PrimaryPart, "confirmed" end
        return nil, "confirmed-missing"
    end
    -- hypothesis path: name heuristic, smallest plausible unanchored round part
    local best, bestScore = nil, math.huge
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("BasePart") and nameLooksLikeBall(inst.Name) then
            if isPlausibleVector(inst.Position) then
                local score = inst.Size.Magnitude
                if score < bestScore then best, bestScore = inst, score end
            end
        end
    end
    if best then return best, "derived" end
    return nil, "unknown"
end

----------------------------------------------------------------------
-- PURE MATH  (checkable without the game)
----------------------------------------------------------------------

-- Roblox: Y-up, studs, degrees for Camera.FieldOfView, Workspace.Gravity in studs/s^2.
-- Linear lead: no drag modelled, no server-side interpolation modelled.
local function leadPosition(targetPos, targetVel, travelTime, gravity)
    if not (isPlausibleVector(targetPos) and isPlausibleVector(targetVel)) then return nil end
    if not isFiniteNumber(travelTime) or travelTime < 0 or travelTime > 10 then return nil end
    local g = isFiniteNumber(gravity) and gravity or CFG.GravityFallback
    local drop = 0.5 * g * travelTime * travelTime
    local out = targetPos + (targetVel * travelTime) - Vector3.new(0, drop, 0)
    if not isPlausibleVector(out) then return nil end
    return out
end

-- Flat-ground ballistic solve for a fixed launch speed. Returns the low arc
-- unit direction, or nil when the target is out of range for that speed.
local function ballisticDirection(fromPos, toPos, speed, gravity)
    if not (isPlausibleVector(fromPos) and isPlausibleVector(toPos)) then return nil end
    if not isFiniteNumber(speed) or speed <= 0 then return nil end
    local g = isFiniteNumber(gravity) and gravity or CFG.GravityFallback
    local delta = toPos - fromPos
    local flat = Vector3.new(delta.X, 0, delta.Z)
    local x = flat.Magnitude
    local y = delta.Y
    if x < 1e-4 then
        return Vector3.new(0, (y >= 0 and 1) or -1, 0)
    end
    local s2 = speed * speed
    local disc = s2 * s2 - g * (g * x * x + 2 * y * s2)
    if disc < 0 then return nil end
    local rootD = math.sqrt(disc)
    local tanTheta = (s2 - rootD) / (g * x)   -- low arc
    local dir = (flat.Unit * 1) + Vector3.new(0, tanTheta, 0)
    if not isPlausibleVector(dir) or dir.Magnitude < 1e-6 then return nil end
    return dir.Unit
end

-- Predicted path of a free body, used for the prediction trail.
local function samplePath(pos, vel, gravity, steps, dt)
    local pts = {}
    if not (isPlausibleVector(pos) and isPlausibleVector(vel)) then return pts end
    local g = isFiniteNumber(gravity) and gravity or CFG.GravityFallback
    for i = 1, steps do
        local t = dt * i
        local p = pos + vel * t - Vector3.new(0, 0.5 * g * t * t, 0)
        if not isPlausibleVector(p) then break end
        pts[#pts + 1] = p
    end
    return pts
end

local function worldToScreen(pos)
    if not isPlausibleVector(pos) then return nil, false end
    local v, onScreen = Camera:WorldToViewportPoint(pos)
    if v.Z <= 0 then return nil, false end
    if not (isFiniteNumber(v.X) and isFiniteNumber(v.Y)) then return nil, false end
    return Vector2.new(v.X, v.Y), onScreen
end

----------------------------------------------------------------------
-- DRAWING WRAPPERS  (Drawing API when present, Frame fallback otherwise)
----------------------------------------------------------------------

local HasDrawing = (typeof(Drawing) == "table") or (type(Drawing) == "table")
local FallbackGui = nil

local function ensureFallbackGui()
    if FallbackGui and FallbackGui.Parent then return FallbackGui end
    local sg = Instance.new("ScreenGui")
    sg.Name = "TF_ESP"
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local parent = (gethui and gethui()) or game:GetService("CoreGui")
    local ok = pcall(function() sg.Parent = parent end)
    if not ok then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    FallbackGui = sg
    return sg
end

local Shape = {}
Shape.__index = Shape

function Shape.newLine()
    local self = setmetatable({ kind = "line" }, Shape)
    if HasDrawing then
        self.obj = Drawing.new("Line")
        self.obj.Thickness = 1
        self.obj.Visible = false
        self.obj.Color = Color3.fromRGB(255, 255, 255)
    else
        local f = Instance.new("Frame")
        f.BorderSizePixel = 0
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        f.Visible = false
        f.Parent = ensureFallbackGui()
        self.obj = f
    end
    return self
end

function Shape.newBox()
    local self = setmetatable({ kind = "box" }, Shape)
    if HasDrawing then
        self.obj = Drawing.new("Square")
        self.obj.Thickness = 1
        self.obj.Filled = false
        self.obj.Visible = false
        self.obj.Color = Color3.fromRGB(255, 255, 255)
    else
        local f = Instance.new("Frame")
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 2
        f.BorderColor3 = Color3.fromRGB(255, 255, 255)
        f.Visible = false
        f.Parent = ensureFallbackGui()
        self.obj = f
    end
    return self
end

function Shape.newText()
    local self = setmetatable({ kind = "text" }, Shape)
    if HasDrawing then
        self.obj = Drawing.new("Text")
        self.obj.Size = 14
        self.obj.Center = true
        self.obj.Outline = true
        self.obj.Visible = false
        self.obj.Color = Color3.fromRGB(255, 255, 255)
    else
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.Code
        l.TextSize = 14
        l.TextStrokeTransparency = 0
        l.TextColor3 = Color3.fromRGB(255, 255, 255)
        l.Size = UDim2.fromOffset(200, 16)
        l.AnchorPoint = Vector2.new(0.5, 0.5)
        l.Visible = false
        l.Parent = ensureFallbackGui()
        self.obj = l
    end
    return self
end

function Shape:setColor(c)
    if HasDrawing then
        self.obj.Color = c
    elseif self.kind == "box" then
        self.obj.BorderColor3 = c
    elseif self.kind == "text" then
        self.obj.TextColor3 = c
    else
        self.obj.BackgroundColor3 = c
    end
end

function Shape:hide()
    self.obj.Visible = false
end

function Shape:line(a, b)
    if HasDrawing then
        self.obj.From = a
        self.obj.To = b
        self.obj.Visible = true
    else
        local d = b - a
        local mag = d.Magnitude
        if mag < 1 then self.obj.Visible = false return end
        self.obj.Size = UDim2.fromOffset(mag, 1)
        self.obj.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
        self.obj.Rotation = math.deg(math.atan2(d.Y, d.X))
        self.obj.Visible = true
    end
end

function Shape:box(topLeft, size)
    if HasDrawing then
        self.obj.Position = topLeft
        self.obj.Size = size
        self.obj.Visible = true
    else
        self.obj.Position = UDim2.fromOffset(topLeft.X, topLeft.Y)
        self.obj.Size = UDim2.fromOffset(size.X, size.Y)
        self.obj.Visible = true
    end
end

function Shape:text(str, pos)
    if HasDrawing then
        self.obj.Text = str
        self.obj.Position = pos
        self.obj.Visible = true
    else
        self.obj.Text = str
        self.obj.Position = UDim2.fromOffset(pos.X, pos.Y)
        self.obj.Visible = true
    end
end

function Shape:destroy()
    pcall(function()
        if HasDrawing then self.obj:Remove() else self.obj:Destroy() end
    end)
end

----------------------------------------------------------------------
-- ESP
----------------------------------------------------------------------

local function teamColorFor(plr)
    if S.EspTeamColor and plr.Team and LocalPlayer.Team then
        if plr.Team == LocalPlayer.Team then
            return Color3.fromRGB(90, 220, 120)
        end
        return Color3.fromRGB(240, 80, 80)
    end
    return Color3.fromRGB(235, 235, 235)
end

local function getBundle(plr)
    local b = Drawings[plr]
    if b then return b end
    b = {
        box = Shape.newBox(),
        tracer = Shape.newLine(),
        text = Shape.newText(),
    }
    Drawings[plr] = b
    return b
end

local function clearBundle(plr)
    local b = Drawings[plr]
    if not b then return end
    b.box:destroy(); b.tracer:destroy(); b.text:destroy()
    Drawings[plr] = nil
end

local function clearAllEsp()
    for plr in pairs(Drawings) do clearBundle(plr) end
    for plr, hl in pairs(Highlights) do
        pcall(function() hl:Destroy() end)
        Highlights[plr] = nil
    end
end

local function applyHighlight(plr, ch, on)
    local hl = Highlights[plr]
    if not on then
        if hl then pcall(function() hl:Destroy() end) Highlights[plr] = nil end
        return
    end
    if hl and hl.Parent == ch then
        hl.FillColor = teamColorFor(plr)
        return
    end
    if hl then pcall(function() hl:Destroy() end) end
    hl = Instance.new("Highlight")
    hl.Name = "TF_HL"
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0
    hl.FillColor = teamColorFor(plr)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = ch
    hl.Parent = ch
    Highlights[plr] = hl
end

local function espStep()
    if not S.EspOn then
        for plr, b in pairs(Drawings) do
            b.box:hide(); b.tracer:hide(); b.text:hide()
        end
        for plr in pairs(Highlights) do applyHighlight(plr, nil, false) end
        return
    end

    local _, _, myRoot = myChar()
    local vp = Camera.ViewportSize

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local ch, hum, root = alive(plr)
            local b = getBundle(plr)
            local shown = false

            if ch and root then
                local dist = myRoot and (root.Position - myRoot.Position).Magnitude or 0
                if dist <= S.EspMaxDist then
                    local head = ch:FindFirstChild("Head") or root
                    local topV, topOn = worldToScreen(head.Position + Vector3.new(0, 1.2, 0))
                    local botV = worldToScreen(root.Position - Vector3.new(0, 3.2, 0))
                    if topV and botV and topOn then
                        shown = true
                        local col = teamColorFor(plr)
                        local height = math.max(8, botV.Y - topV.Y)
                        local width = height * 0.5
                        local tl = Vector2.new(topV.X - width / 2, topV.Y)

                        if S.EspBox then
                            b.box:setColor(col)
                            b.box:box(tl, Vector2.new(width, height))
                        else
                            b.box:hide()
                        end

                        if S.EspTracer then
                            b.tracer:setColor(col)
                            b.tracer:line(Vector2.new(vp.X / 2, vp.Y), Vector2.new(topV.X, botV.Y))
                        else
                            b.tracer:hide()
                        end

                        if S.EspName or S.EspDist then
                            local parts = {}
                            if S.EspName then parts[#parts + 1] = plr.Name end
                            if S.EspDist then parts[#parts + 1] = ("%dm"):format(math.floor(dist)) end
                            b.text:setColor(col)
                            b.text:text(table.concat(parts, "  "), Vector2.new(topV.X, topV.Y - 16))
                        else
                            b.text:hide()
                        end

                        applyHighlight(plr, ch, S.EspHighlight)
                    end
                end
            end

            if not shown then
                b.box:hide(); b.tracer:hide(); b.text:hide()
                applyHighlight(plr, nil, false)
            end
        end
    end
end

----------------------------------------------------------------------
-- BALL VISUALS
----------------------------------------------------------------------

local function ensureBallDraw()
    if not BallDraw.tracer then BallDraw.tracer = Shape.newLine() end
    if not BallDraw.dot then BallDraw.dot = Shape.newText() end
    if #BallDraw.path == 0 then
        for i = 1, 20 do BallDraw.path[i] = Shape.newLine() end
    end
end

local function hideBallDraw()
    if BallDraw.tracer then BallDraw.tracer:hide() end
    if BallDraw.dot then BallDraw.dot:hide() end
    for _, l in ipairs(BallDraw.path) do l:hide() end
end

local function ballStep()
    if not (S.BallEsp or S.BallTracer or S.BallPredict) then
        hideBallDraw()
        return
    end
    ensureBallDraw()
    local ball, tier = getBall()
    if not ball then
        hideBallDraw()
        return
    end

    local vp = Camera.ViewportSize
    local col = (tier == "confirmed") and Color3.fromRGB(255, 190, 60) or Color3.fromRGB(255, 120, 200)
    local scr, onScreen = worldToScreen(ball.Position)

    if S.BallEsp and scr and onScreen then
        local _, _, myRoot = myChar()
        local d = myRoot and (ball.Position - myRoot.Position).Magnitude or 0
        BallDraw.dot:setColor(col)
        BallDraw.dot:text(("BALL %dm%s"):format(math.floor(d), tier == "derived" and " ?" or ""), scr)
    else
        BallDraw.dot:hide()
    end

    if S.BallTracer and scr and onScreen then
        BallDraw.tracer:setColor(col)
        BallDraw.tracer:line(Vector2.new(vp.X / 2, vp.Y), scr)
    else
        BallDraw.tracer:hide()
    end

    if S.BallPredict then
        local vel = ball.AssemblyLinearVelocity
        local pts = samplePath(ball.Position, vel, S.LastGravity, #BallDraw.path, 0.06)
        local prev = ball.Position
        for i, l in ipairs(BallDraw.path) do
            local p = pts[i]
            if p then
                local a = worldToScreen(prev)
                local bb = worldToScreen(p)
                if a and bb then
                    l:setColor(Color3.fromRGB(120, 200, 255))
                    l:line(a, bb)
                else
                    l:hide()
                end
                prev = p
            else
                l:hide()
            end
        end
    else
        for _, l in ipairs(BallDraw.path) do l:hide() end
    end
end

----------------------------------------------------------------------
-- BALL ACTIONS
----------------------------------------------------------------------

local function handPosition(ch)
    local h = ch:FindFirstChild("RightHand") or ch:FindFirstChild("Right Arm")
        or ch:FindFirstChild("RightUpperArm") or ch:FindFirstChild("HumanoidRootPart")
    return h and h.Position
end

local function magnetStep()
    if not S.Magnet then return end
    local ch, hum, root = myChar()
    if not ch then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    if ball:IsDescendantOf(ch) then return end
    local target = handPosition(ch)
    if not isPlausibleVector(target) then return end
    local d = (ball.Position - target).Magnitude
    if not isFiniteNumber(d) or d > S.MagnetRadius then return end
    pcall(function()
        ball.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        ball.CFrame = CFrame.new(target)
    end)
end

local function autoCatchStep()
    if not S.AutoCatch then return end
    local ch, hum, root = myChar()
    if not ch then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    if ball:IsDescendantOf(ch) then return end
    local target = handPosition(ch)
    if not isPlausibleVector(target) then return end
    local d = (ball.Position - target).Magnitude
    if not isFiniteNumber(d) or d > S.AutoCatchRadius then return end

    if HAS.catch_remote then
        local rem = ReplicatedStorage:FindFirstChild(CFG.CatchRemoteName, true)
        if rem and rem:IsA("RemoteEvent") then
            pcall(function() rem:FireServer(ball) end)
            return
        end
    else
        gateOff("Auto Catch (remote path)", "CFG.CatchRemoteName")
    end
    -- physics path always available
    pcall(function()
        ball.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        ball.CFrame = CFrame.new(target)
    end)
end

local function ballFollowStep()
    if not S.BallFollow then return end
    local ch, hum, root = myChar()
    if not ch or not root then return end
    local ball = getBall()
    if not ball or ball:IsDescendantOf(ch) then return end
    local vel = ball.AssemblyLinearVelocity
    local land = leadPosition(ball.Position, vel, 0.6, S.LastGravity) or ball.Position
    local dir = Vector3.new(land.X - root.Position.X, 0, land.Z - root.Position.Z)
    if dir.Magnitude < 2 then return end
    hum:Move(dir.Unit, false)
end

local function teleportToBall()
    local ch, hum, root = myChar()
    if not ch then notify("Teleport", "No live character.", 3) return end
    local ball, tier = getBall()
    if not ball then notify("Teleport", "Ball unresolved. Run DISCOVERY > Scan ball candidates.", 5) return end
    pcall(function()
        root.CFrame = CFrame.new(ball.Position + Vector3.new(0, 4, 0))
    end)
end

local function throwAtNearest(speed)
    local ch, hum, root = myChar()
    if not ch then return end
    local ball = getBall()
    if not ball then notify("Throw", "Ball unresolved.", 4) return end

    local bestPlr, bestD = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if not (S.AimTeamCheck and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team) then
                local _, _, r = alive(plr)
                if r then
                    local d = (r.Position - root.Position).Magnitude
                    if d < bestD then bestPlr, bestD = plr, d end
                end
            end
        end
    end
    if not bestPlr then notify("Throw", "No target.", 3) return end
    local _, _, tRoot = alive(bestPlr)
    if not tRoot then return end

    local travel = bestD / math.max(1, speed)
    local lead = leadPosition(tRoot.Position, tRoot.AssemblyLinearVelocity, travel, S.LastGravity) or tRoot.Position
    local dir = ballisticDirection(ball.Position, lead, speed, S.LastGravity)
    if not dir then
        notify("Throw", ("Out of range for %d studs/s."):format(speed), 4)
        return
    end

    if HAS.throw_remote then
        local rem = ReplicatedStorage:FindFirstChild(CFG.ThrowRemoteName, true)
        if rem and rem:IsA("RemoteEvent") then
            pcall(function() rem:FireServer(dir * speed, bestPlr) end)
            return
        end
    else
        gateOff("Throw (remote path)", "CFG.ThrowRemoteName")
    end
    pcall(function()
        ball.AssemblyLinearVelocity = dir * speed
    end)
end

----------------------------------------------------------------------
-- AIM
----------------------------------------------------------------------

local function visibleTo(part, ignoreChar)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { ignoreChar, Camera }
    local origin = Camera.CFrame.Position
    local dir = part.Position - origin
    if dir.Magnitude < 1e-3 then return true end
    local hit = Workspace:Raycast(origin, dir, params)
    if not hit then return true end
    return hit.Instance:IsDescendantOf(part.Parent)
end

local function pickAimTarget()
    local ch = myChar()
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local best, bestD = nil, S.AimFov

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if not (S.AimTeamCheck and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team) then
                local tch, thum, troot = alive(plr)
                if tch then
                    local part = partOf(tch, S.AimPart)
                    if part then
                        local scr, onScreen = worldToScreen(part.Position)
                        if scr and onScreen then
                            local d = (scr - center).Magnitude
                            if d < bestD then
                                if (not S.AimVisibleOnly) or visibleTo(part, ch) then
                                    best, bestD = plr, d
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function aimStep(dt)
    if not S.AimOn or not S.AimKeyHeld then
        S.AimTarget = nil
        return
    end
    if UserInputService:GetFocusedTextBox() then return end

    -- revalidate immediately before moving the camera
    local tgt = S.AimTarget
    local tch = tgt and alive(tgt)
    if not tch then
        tgt = pickAimTarget()
        S.AimTarget = tgt
        tch = tgt and alive(tgt)
        if not tch then return end
    end

    local part = partOf(tch, S.AimPart)
    if not part then return end
    local aimAt = part.Position
    local hum = tch:FindFirstChildOfClass("Humanoid")
    local root = tch:FindFirstChild("HumanoidRootPart")
    if root then
        local travel = (aimAt - Camera.CFrame.Position).Magnitude / 1000
        local lead = leadPosition(aimAt, root.AssemblyLinearVelocity, travel, 0)
        if lead then aimAt = lead end
    end
    if not isPlausibleVector(aimAt) then return end

    local want = CFrame.new(Camera.CFrame.Position, aimAt)
    local alpha = math.clamp(1 - S.AimSmooth, 0.02, 1)
    Camera.CFrame = Camera.CFrame:Lerp(want, alpha)
end

----------------------------------------------------------------------
-- MOVEMENT
----------------------------------------------------------------------

local FlyBody = { part = nil, vel = nil, gyro = nil }

local function stopFly()
    S.Fly = false
    if FlyBody.vel then pcall(function() FlyBody.vel:Destroy() end) end
    if FlyBody.gyro then pcall(function() FlyBody.gyro:Destroy() end) end
    FlyBody.vel, FlyBody.gyro, FlyBody.part = nil, nil, nil
    local ch, hum = myChar()
    if hum then pcall(function() hum.PlatformStand = false end) end
end

local function startFly()
    local ch, hum, root = myChar()
    if not root then S.Fly = false return end
    stopFly()
    S.Fly = true
    local v = Instance.new("BodyVelocity")
    v.Name = "TF_FlyVel"
    v.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    v.Velocity = Vector3.new(0, 0, 0)
    v.P = 2000
    v.Parent = root
    local g = Instance.new("BodyGyro")
    g.Name = "TF_FlyGyro"
    g.MaxTorque = Vector3.new(4e5, 4e5, 4e5)
    g.P = 6000
    g.D = 100
    g.CFrame = Camera.CFrame
    g.Parent = root
    FlyBody.part, FlyBody.vel, FlyBody.gyro = root, v, g
    pcall(function() hum.PlatformStand = true end)
end

local function flyStep()
    if not S.Fly then return end
    local ch, hum, root = myChar()
    if not root or not FlyBody.vel or FlyBody.vel.Parent ~= root then
        if S.Fly then startFly() end
        return
    end
    local dir = Vector3.new(0, 0, 0)
    local cf = Camera.CFrame
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
    if dir.Magnitude > 0 then
        FlyBody.vel.Velocity = dir.Unit * S.FlySpeed
    else
        FlyBody.vel.Velocity = Vector3.new(0, 0, 0)
    end
    FlyBody.gyro.CFrame = cf
end

local function noclipStep()
    local ch = myChar()
    if not ch then return end
    for _, p in ipairs(ch:GetDescendants()) do
        if p:IsA("BasePart") then
            if S.NoClip then
                if p.CanCollide then p.CanCollide = false end
            else
                if p.Name ~= "HumanoidRootPart" and not p.CanCollide then
                    -- only restore parts we know are normally solid
                    if p:IsA("MeshPart") or p:IsA("Part") then p.CanCollide = true end
                end
            end
        end
    end
end

local function statsStep()
    local ch, hum = myChar()
    if not hum then return end
    if S.SpeedOn then
        if math.abs(hum.WalkSpeed - S.SpeedValue) > 0.01 then hum.WalkSpeed = S.SpeedValue end
    end
    if S.JumpOn then
        if hum.UseJumpPower then
            if math.abs(hum.JumpPower - S.JumpValue) > 0.01 then hum.JumpPower = S.JumpValue end
        else
            local h = S.JumpValue * 0.14
            if math.abs(hum.JumpHeight - h) > 0.01 then hum.JumpHeight = h end
        end
    end
    if S.AntiRagdoll then
        for _, st in ipairs({
            Enum.HumanoidStateType.FallingDown,
            Enum.HumanoidStateType.Ragdoll,
            Enum.HumanoidStateType.Physics,
        }) do
            pcall(function() hum:SetStateEnabled(st, false) end)
        end
        if hum:GetState() == Enum.HumanoidStateType.FallingDown
            or hum:GetState() == Enum.HumanoidStateType.Ragdoll then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
    end
end

local function hitboxStep()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local ch, hum, root = alive(plr)
            if root then
                if S.HitboxOn then
                    if not OrigHitbox[root] then OrigHitbox[root] = root.Size end
                    local want = Vector3.new(S.HitboxSize, S.HitboxSize, S.HitboxSize)
                    if (root.Size - want).Magnitude > 0.05 then
                        pcall(function()
                            root.Size = want
                            root.Transparency = 0.7
                            root.CanCollide = false
                        end)
                    end
                else
                    local orig = OrigHitbox[root]
                    if orig then
                        pcall(function()
                            root.Size = orig
                            root.Transparency = 1
                        end)
                        OrigHitbox[root] = nil
                    end
                end
            end
        end
    end
end

----------------------------------------------------------------------
-- LIGHTING / CAMERA
----------------------------------------------------------------------

local LightSave = nil

local function applyLighting()
    if S.FullBright then
        if not LightSave then
            LightSave = {
                Brightness = Lighting.Brightness,
                ClockTime = Lighting.ClockTime,
                GlobalShadows = Lighting.GlobalShadows,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                FogEnd = Lighting.FogEnd,
                FogStart = Lighting.FogStart,
            }
        end
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
    elseif LightSave then
        Lighting.Brightness = LightSave.Brightness
        Lighting.ClockTime = LightSave.ClockTime
        Lighting.GlobalShadows = LightSave.GlobalShadows
        Lighting.Ambient = LightSave.Ambient
        Lighting.OutdoorAmbient = LightSave.OutdoorAmbient
        Lighting.FogEnd = LightSave.FogEnd
        Lighting.FogStart = LightSave.FogStart
        LightSave = nil
    end

    if S.NoFog then
        Lighting.FogEnd = 1e6
        Lighting.FogStart = 1e6 - 1
        for _, d in ipairs(Lighting:GetChildren()) do
            if d:IsA("Atmosphere") then pcall(function() d.Density = 0 end) end
        end
    end
end

----------------------------------------------------------------------
-- DISCOVERY  (produces the values CFG is missing)
----------------------------------------------------------------------

local function dumpRemotes()
    local lines = { "=== TF REMOTE DUMP ===" }
    local roots = { ReplicatedStorage, Workspace, LocalPlayer }
    for _, r in ipairs(roots) do
        local ok, desc = pcall(function() return r:GetDescendants() end)
        if ok then
            for _, inst in ipairs(desc) do
                if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent") then
                    lines[#lines + 1] = ("%s | %s | %s"):format(inst.ClassName, inst.Name, inst:GetFullName())
                end
            end
        end
    end
    lines[#lines + 1] = ("total: %d"):format(#lines - 2)
    local out = table.concat(lines, "\n")
    print(out)
    if setclipboard then pcall(function() setclipboard(out) end) end
    notify("Discovery", ("Remotes dumped (%d). Copied to clipboard if supported."):format(#lines - 2), 6)
    return out
end

local function dumpBallCandidates()
    local lines = { "=== TF BALL CANDIDATES ===" }
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("BasePart") and nameLooksLikeBall(inst.Name) then
            lines[#lines + 1] = ("%s | size=%s | anchored=%s | path=%s"):format(
                inst.Name, tostring(inst.Size), tostring(inst.Anchored), inst:GetFullName())
        end
    end
    if #lines == 1 then
        lines[#lines + 1] = "no name match. Hold the ball in game, then run 'Dump held objects'."
    end
    local out = table.concat(lines, "\n")
    print(out)
    if setclipboard then pcall(function() setclipboard(out) end) end
    notify("Discovery", "Ball candidates printed to console.", 6)
    return out
end

local function dumpHeld()
    local ch = myChar()
    local lines = { "=== TF CHARACTER / HELD DUMP ===" }
    if not ch then
        lines[#lines + 1] = "no live character"
    else
        for _, inst in ipairs(ch:GetDescendants()) do
            lines[#lines + 1] = ("%s | %s | %s"):format(inst.ClassName, inst.Name, inst:GetFullName())
        end
    end
    local out = table.concat(lines, "\n")
    print(out)
    if setclipboard then pcall(function() setclipboard(out) end) end
    notify("Discovery", "Character tree printed to console.", 6)
    return out
end

local function dumpAttributes()
    local ch, hum = myChar()
    local lines = { "=== TF ATTRIBUTE / VALUE DUMP ===" }
    local targets = { LocalPlayer, ch, hum }
    for _, t in ipairs(targets) do
        if t then
            lines[#lines + 1] = ("-- %s"):format(t:GetFullName())
            local ok, attrs = pcall(function() return t:GetAttributes() end)
            if ok and attrs then
                for k, v in pairs(attrs) do
                    lines[#lines + 1] = ("attr %s = %s"):format(k, tostring(v))
                end
            end
            for _, c in ipairs(t:GetChildren()) do
                if c:IsA("ValueBase") then
                    lines[#lines + 1] = ("%s %s = %s"):format(c.ClassName, c.Name, tostring(c.Value))
                end
            end
        end
    end
    local out = table.concat(lines, "\n")
    print(out)
    if setclipboard then pcall(function() setclipboard(out) end) end
    notify("Discovery", "Attributes printed to console.", 6)
    return out
end

local function selfTestMath()
    local lines = { "=== TF MATH SELF TEST ===" }
    local g = 196.2
    local d1 = ballisticDirection(Vector3.new(0, 0, 0), Vector3.new(100, 0, 0), 150, g)
    lines[#lines + 1] = "ballistic 100 studs @150: " .. (d1 and tostring(d1) or "nil (out of range)")
    local d2 = ballisticDirection(Vector3.new(0, 0, 0), Vector3.new(5000, 0, 0), 150, g)
    lines[#lines + 1] = "ballistic 5000 studs @150: " .. (d2 and tostring(d2) or "nil (out of range)")
    local l1 = leadPosition(Vector3.new(0, 10, 0), Vector3.new(20, 0, 0), 0.5, g)
    lines[#lines + 1] = "lead 0.5s: " .. (l1 and tostring(l1) or "nil")
    local bad = leadPosition(Vector3.new(0 / 0, 0, 0), Vector3.new(0, 0, 0), 0.5, g)
    lines[#lines + 1] = "lead with NaN input rejected: " .. tostring(bad == nil)
    local pts = samplePath(Vector3.new(0, 50, 0), Vector3.new(0, 0, 60), g, 5, 0.1)
    lines[#lines + 1] = ("path samples: %d, last=%s"):format(#pts, #pts > 0 and tostring(pts[#pts]) or "none")
    local out = table.concat(lines, "\n")
    print(out)
    notify("Self test", "Math results in console.", 6)
    return out
end

----------------------------------------------------------------------
-- MAIN LOOP
----------------------------------------------------------------------

local function frame(dt)
    pcall(function()
        Camera = Workspace.CurrentCamera or Camera
        local okG, g = pcall(function() return Workspace.Gravity end)
        if okG and isFiniteNumber(g) and g > 0 then S.LastGravity = g end

        statsStep()
        if S.NoClip then noclipStep() end
        flyStep()
        magnetStep()
        autoCatchStep()
        ballFollowStep()
        aimStep(dt)
        hitboxStep()
        espStep()
        ballStep()
        if Camera and math.abs(Camera.FieldOfView - S.Fov) > 0.01 then
            Camera.FieldOfView = S.Fov
        end
    end)
end

Conns[#Conns + 1] = RunService.RenderStepped:Connect(frame)

Conns[#Conns + 1] = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2
        or input.KeyCode == Enum.KeyCode.ButtonL2 then
        S.AimKeyHeld = true
    end
    if input.KeyCode == Enum.KeyCode.E then
        if S.AutoCatch then autoCatchStep() end
    end
    if input.KeyCode == Enum.KeyCode.T then
        teleportToBall()
    end
end)

Conns[#Conns + 1] = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2
        or input.KeyCode == Enum.KeyCode.ButtonL2 then
        S.AimKeyHeld = false
        S.AimTarget = nil
    end
end)

Conns[#Conns + 1] = UserInputService.WindowFocusReleased:Connect(function()
    S.AimKeyHeld = false
    S.AimTarget = nil
end)

Conns[#Conns + 1] = UserInputService.JumpRequest:Connect(function()
    if not S.InfJump then return end
    local ch, hum = myChar()
    if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
end)

Conns[#Conns + 1] = Players.PlayerRemoving:Connect(function(plr)
    clearBundle(plr)
    local hl = Highlights[plr]
    if hl then pcall(function() hl:Destroy() end) Highlights[plr] = nil end
end)

Conns[#Conns + 1] = LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.6)
    if S.Fly then startFly() end
end)

local function teardown()
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    Conns = {}
    stopFly()
    S.EspOn = false
    clearAllEsp()
    hideBallDraw()
    if BallDraw.tracer then BallDraw.tracer:destroy() end
    if BallDraw.dot then BallDraw.dot:destroy() end
    for _, l in ipairs(BallDraw.path) do l:destroy() end
    BallDraw = { tracer = nil, dot = nil, path = {} }
    S.HitboxOn = false
    hitboxStep()
    S.FullBright = false
    applyLighting()
    if FallbackGui then pcall(function() FallbackGui:Destroy() end) FallbackGui = nil end
    local ch, hum = myChar()
    if hum then
        pcall(function() hum.WalkSpeed = 16 end)
        pcall(function()
            if hum.UseJumpPower then hum.JumpPower = 50 else hum.JumpHeight = 7.2 end
        end)
    end
    if Camera then Camera.FieldOfView = 70 end
    notify("Touch Football", "Unloaded.", 4)
end

----------------------------------------------------------------------
-- RAYFIELD UI
----------------------------------------------------------------------

local okFetch, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not okFetch or type(Rayfield) ~= "table" then
    notify("Touch Football", "Rayfield fetch failed. Features are live, UI is not.", 8)
    getgenv().TF_Teardown = teardown
    getgenv().TF_Dump = { remotes = dumpRemotes, ball = dumpBallCandidates, held = dumpHeld, attrs = dumpAttributes }
    return
end

local Window = Rayfield:CreateWindow({
    Name = "Touch Football — bench build",
    Icon = 0,
    LoadingTitle = "Touch Football",
    LoadingSubtitle = "olliE",
    Theme = "Default",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "TouchFootball",
        FileName = "tf_main",
    },
    Discord = { Enabled = false, Invite = "", RememberJoins = false },
    KeySystem = false,
})

----------------------------------------------------------------------
local TabMove = Window:CreateTab("MOVEMENT", 0)

TabMove:CreateToggle({
    Name = "WalkSpeed override",
    CurrentValue = false,
    Flag = "speed_on",
    Callback = function(v)
        S.SpeedOn = v
        if not v then
            local _, hum = myChar()
            if hum then hum.WalkSpeed = 16 end
        end
    end,
})

TabMove:CreateSlider({
    Name = "WalkSpeed",
    Range = { 16, 300 },
    Increment = 1,
    Suffix = " studs/s",
    CurrentValue = 16,
    Flag = "speed_val",
    Callback = function(v) S.SpeedValue = v end,
})

TabMove:CreateToggle({
    Name = "Jump override",
    CurrentValue = false,
    Flag = "jump_on",
    Callback = function(v)
        S.JumpOn = v
        if not v then
            local _, hum = myChar()
            if hum then
                if hum.UseJumpPower then hum.JumpPower = 50 else hum.JumpHeight = 7.2 end
            end
        end
    end,
})

TabMove:CreateSlider({
    Name = "Jump power",
    Range = { 50, 500 },
    Increment = 5,
    Suffix = "",
    CurrentValue = 50,
    Flag = "jump_val",
    Callback = function(v) S.JumpValue = v end,
})

TabMove:CreateToggle({
    Name = "Infinite jump",
    CurrentValue = false,
    Flag = "infjump",
    Callback = function(v) S.InfJump = v end,
})

TabMove:CreateToggle({
    Name = "NoClip",
    CurrentValue = false,
    Flag = "noclip",
    Callback = function(v)
        S.NoClip = v
        noclipStep()
    end,
})

TabMove:CreateToggle({
    Name = "Fly (WASD + Space/Ctrl)",
    CurrentValue = false,
    Flag = "fly",
    Callback = function(v)
        if v then startFly() else stopFly() end
    end,
})

TabMove:CreateSlider({
    Name = "Fly speed",
    Range = { 20, 400 },
    Increment = 5,
    Suffix = " studs/s",
    CurrentValue = 60,
    Flag = "fly_speed",
    Callback = function(v) S.FlySpeed = v end,
})

TabMove:CreateToggle({
    Name = "Anti-ragdoll (state block)",
    CurrentValue = false,
    Flag = "antiragdoll",
    Callback = function(v)
        S.AntiRagdoll = v
        if not v then
            local _, hum = myChar()
            if hum then
                for _, st in ipairs({
                    Enum.HumanoidStateType.FallingDown,
                    Enum.HumanoidStateType.Ragdoll,
                    Enum.HumanoidStateType.Physics,
                }) do
                    pcall(function() hum:SetStateEnabled(st, true) end)
                end
            end
        end
    end,
})

----------------------------------------------------------------------
local TabBall = Window:CreateTab("BALL", 0)

TabBall:CreateParagraph({
    Title = "Ball identity",
    Content = HAS.ball_name
        and ("Override set: " .. CFG.BallNameOverride .. " (tier: confirmed)")
        or "No override. The ball is guessed by name pattern — tier: derived, shown with '?'. Set it in CONFIG after running DISCOVERY.",
})

TabBall:CreateToggle({
    Name = "Ball ESP (label + distance)",
    CurrentValue = false,
    Flag = "ball_esp",
    Callback = function(v) S.BallEsp = v end,
})

TabBall:CreateToggle({
    Name = "Ball tracer",
    CurrentValue = false,
    Flag = "ball_tracer",
    Callback = function(v) S.BallTracer = v end,
})

TabBall:CreateToggle({
    Name = "Ball prediction trail",
    CurrentValue = false,
    Flag = "ball_predict",
    Callback = function(v) S.BallPredict = v end,
})

TabBall:CreateToggle({
    Name = "Ball magnet",
    CurrentValue = false,
    Flag = "magnet",
    Callback = function(v) S.Magnet = v end,
})

TabBall:CreateSlider({
    Name = "Magnet radius",
    Range = { 5, 150 },
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 25,
    Flag = "magnet_r",
    Callback = function(v) S.MagnetRadius = v end,
})

TabBall:CreateToggle({
    Name = "Auto catch",
    CurrentValue = false,
    Flag = "autocatch",
    Callback = function(v) S.AutoCatch = v end,
})

TabBall:CreateSlider({
    Name = "Auto catch radius",
    Range = { 10, 400 },
    Increment = 5,
    Suffix = " studs",
    CurrentValue = 60,
    Flag = "autocatch_r",
    Callback = function(v) S.AutoCatchRadius = v end,
})

TabBall:CreateToggle({
    Name = "Walk to predicted landing",
    CurrentValue = false,
    Flag = "ball_follow",
    Callback = function(v) S.BallFollow = v end,
})

TabBall:CreateButton({
    Name = "Teleport to ball  [T]",
    Callback = teleportToBall,
})

local throwSpeed = 180
TabBall:CreateSlider({
    Name = "Throw speed",
    Range = { 60, 600 },
    Increment = 10,
    Suffix = " studs/s",
    CurrentValue = 180,
    Flag = "throw_speed",
    Callback = function(v) throwSpeed = v end,
})

TabBall:CreateButton({
    Name = "Throw at nearest (ballistic solve)",
    Callback = function() throwAtNearest(throwSpeed) end,
})

----------------------------------------------------------------------
local TabAim = Window:CreateTab("AIMBOT", 0)

TabAim:CreateParagraph({
    Title = "Units and limits",
    Content = "FOV is a screen-space radius in pixels. Smoothing 0 = instant snap, 0.95 = heavy drag. Lead uses linear velocity only — no server interpolation delay, no drag, no tick rate modelled. Treat smoothing and FOV as uncalibrated until you tune them in game.",
})

TabAim:CreateToggle({
    Name = "Camera aim (hold Right Mouse / L2)",
    CurrentValue = false,
    Flag = "aim_on",
    Callback = function(v) S.AimOn = v end,
})

TabAim:CreateSlider({
    Name = "FOV radius",
    Range = { 20, 900 },
    Increment = 10,
    Suffix = " px",
    CurrentValue = 180,
    Flag = "aim_fov",
    Callback = function(v) S.AimFov = v end,
})

TabAim:CreateSlider({
    Name = "Smoothing",
    Range = { 0, 95 },
    Increment = 1,
    Suffix = " %",
    CurrentValue = 25,
    Flag = "aim_smooth",
    Callback = function(v) S.AimSmooth = v / 100 end,
})

TabAim:CreateDropdown({
    Name = "Aim part",
    Options = { "Head", "UpperTorso", "HumanoidRootPart", "LowerTorso" },
    CurrentOption = { "Head" },
    MultipleOptions = false,
    Flag = "aim_part",
    Callback = function(opt)
        S.AimPart = (type(opt) == "table") and opt[1] or opt
    end,
})

TabAim:CreateToggle({
    Name = "Team check",
    CurrentValue = false,
    Flag = "aim_team",
    Callback = function(v) S.AimTeamCheck = v end,
})

TabAim:CreateToggle({
    Name = "Visible only (raycast)",
    CurrentValue = false,
    Flag = "aim_vis",
    Callback = function(v) S.AimVisibleOnly = v end,
})

TabAim:CreateToggle({
    Name = "Hitbox expander (other players)",
    CurrentValue = false,
    Flag = "hitbox_on",
    Callback = function(v)
        S.HitboxOn = v
        hitboxStep()
    end,
})

TabAim:CreateSlider({
    Name = "Hitbox size",
    Range = { 2, 30 },
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 6,
    Flag = "hitbox_size",
    Callback = function(v) S.HitboxSize = v end,
})

----------------------------------------------------------------------
local TabEsp = Window:CreateTab("ESP", 0)

TabEsp:CreateToggle({
    Name = "Player ESP",
    CurrentValue = false,
    Flag = "esp_on",
    Callback = function(v)
        S.EspOn = v
        if not v then clearAllEsp() end
    end,
})

TabEsp:CreateToggle({ Name = "Boxes", CurrentValue = true, Flag = "esp_box",
    Callback = function(v) S.EspBox = v end })
TabEsp:CreateToggle({ Name = "Names", CurrentValue = true, Flag = "esp_name",
    Callback = function(v) S.EspName = v end })
TabEsp:CreateToggle({ Name = "Distance", CurrentValue = true, Flag = "esp_dist",
    Callback = function(v) S.EspDist = v end })
TabEsp:CreateToggle({ Name = "Tracers", CurrentValue = false, Flag = "esp_tracer",
    Callback = function(v) S.EspTracer = v end })
TabEsp:CreateToggle({ Name = "Highlight fill", CurrentValue = false, Flag = "esp_hl",
    Callback = function(v)
        S.EspHighlight = v
        if not v then
            for plr in pairs(Highlights) do applyHighlight(plr, nil, false) end
        end
    end })
TabEsp:CreateToggle({ Name = "Team colour", CurrentValue = true, Flag = "esp_teamcol",
    Callback = function(v) S.EspTeamColor = v end })

TabEsp:CreateSlider({
    Name = "Max distance",
    Range = { 100, 5000 },
    Increment = 50,
    Suffix = " studs",
    CurrentValue = 1500,
    Flag = "esp_maxdist",
    Callback = function(v) S.EspMaxDist = v end,
})

TabEsp:CreateParagraph({
    Title = "Renderer",
    Content = HasDrawing and "Drawing API detected — using native shapes."
        or "No Drawing API — using ScreenGui frames. Slightly heavier, same output.",
})

----------------------------------------------------------------------
local TabMisc = Window:CreateTab("MISC", 0)

TabMisc:CreateToggle({
    Name = "Fullbright",
    CurrentValue = false,
    Flag = "fullbright",
    Callback = function(v)
        S.FullBright = v
        applyLighting()
    end,
})

TabMisc:CreateToggle({
    Name = "No fog",
    CurrentValue = false,
    Flag = "nofog",
    Callback = function(v)
        S.NoFog = v
        applyLighting()
    end,
})

TabMisc:CreateSlider({
    Name = "Field of view",
    Range = { 40, 120 },
    Increment = 1,
    Suffix = " deg",
    CurrentValue = 70,
    Flag = "fov",
    Callback = function(v) S.Fov = v end,
})

TabMisc:CreateButton({
    Name = "Reset character stats",
    Callback = function()
        local _, hum = myChar()
        if not hum then return end
        hum.WalkSpeed = 16
        if hum.UseJumpPower then hum.JumpPower = 50 else hum.JumpHeight = 7.2 end
        notify("Misc", "WalkSpeed 16, jump reset.", 3)
    end,
})

TabMisc:CreateButton({
    Name = "Unload everything",
    Callback = function()
        teardown()
        pcall(function() Rayfield:Destroy() end)
    end,
})

----------------------------------------------------------------------
local TabDisc = Window:CreateTab("DISCOVERY", 0)

TabDisc:CreateParagraph({
    Title = "What this is for",
    Content = "These dumps produce the four UNSET values in CFG: ball name, ball parent, catch remote, throw remote. Hold the ball in game before running 'Dump character tree' — that is the fastest way to get the exact ball Instance name.",
})

TabDisc:CreateButton({ Name = "Dump remotes (RS + Workspace + Player)", Callback = dumpRemotes })
TabDisc:CreateButton({ Name = "Scan ball candidates (name heuristic)", Callback = dumpBallCandidates })
TabDisc:CreateButton({ Name = "Dump character tree (hold the ball first)", Callback = dumpHeld })
TabDisc:CreateButton({ Name = "Dump attributes and values", Callback = dumpAttributes })
TabDisc:CreateButton({ Name = "Run math self test", Callback = selfTestMath })

TabDisc:CreateButton({
    Name = "Report resolver state",
    Callback = function()
        local ball, tier = getBall()
        local lines = {
            ("ball_name override: %s"):format(HAS.ball_name and CFG.BallNameOverride or "UNSET"),
            ("ball_parent override: %s"):format(HAS.ball_parent and CFG.BallParentOverride or "UNSET"),
            ("catch remote: %s"):format(HAS.catch_remote and CFG.CatchRemoteName or "UNSET (physics path only)"),
            ("throw remote: %s"):format(HAS.throw_remote and CFG.ThrowRemoteName or "UNSET (physics path only)"),
            ("resolved ball: %s (tier %s)"):format(ball and ball:GetFullName() or "none", tier),
            ("gravity read live: %.3f"):format(S.LastGravity),
            ("drawing api: %s"):format(tostring(HasDrawing)),
        }
        local out = table.concat(lines, "\n")
        print(out)
        notify("Resolver", out, 10)
    end,
})

----------------------------------------------------------------------
local TabCfg = Window:CreateTab("CONFIG", 0)

TabCfg:CreateInput({
    Name = "Ball Instance name",
    CurrentValue = CFG.BallNameOverride,
    PlaceholderText = "exact name from DISCOVERY",
    RemoveTextAfterFocusLost = false,
    Flag = "cfg_ball_name",
    Callback = function(txt)
        CFG.BallNameOverride = txt or ""
        HAS.ball_name = CFG.BallNameOverride ~= ""
        notify("Config", ("Ball name = %s"):format(HAS.ball_name and CFG.BallNameOverride or "UNSET"), 4)
    end,
})

TabCfg:CreateInput({
    Name = "Ball parent (workspace child)",
    CurrentValue = CFG.BallParentOverride,
    PlaceholderText = "blank = whole workspace",
    RemoveTextAfterFocusLost = false,
    Flag = "cfg_ball_parent",
    Callback = function(txt)
        CFG.BallParentOverride = txt or ""
        HAS.ball_parent = CFG.BallParentOverride ~= ""
    end,
})

TabCfg:CreateInput({
    Name = "Catch RemoteEvent name",
    CurrentValue = CFG.CatchRemoteName,
    PlaceholderText = "blank = physics path only",
    RemoveTextAfterFocusLost = false,
    Flag = "cfg_catch",
    Callback = function(txt)
        CFG.CatchRemoteName = txt or ""
        HAS.catch_remote = CFG.CatchRemoteName ~= ""
        S.Notices = {}
    end,
})

TabCfg:CreateInput({
    Name = "Throw RemoteEvent name",
    CurrentValue = CFG.ThrowRemoteName,
    PlaceholderText = "blank = physics path only",
    RemoveTextAfterFocusLost = false,
    Flag = "cfg_throw",
    Callback = function(txt)
        CFG.ThrowRemoteName = txt or ""
        HAS.throw_remote = CFG.ThrowRemoteName ~= ""
        S.Notices = {}
    end,
})

TabCfg:CreateInput({
    Name = "Extra ball name pattern",
    CurrentValue = "",
    PlaceholderText = "lowercase substring",
    RemoveTextAfterFocusLost = true,
    Flag = "cfg_pattern",
    Callback = function(txt)
        if txt and txt ~= "" then
            CFG.BallPatterns[#CFG.BallPatterns + 1] = string.lower(txt)
            notify("Config", ("Pattern added: %s"):format(txt), 4)
        end
    end,
})

Rayfield:LoadConfiguration()

getgenv().TF_Teardown = teardown
getgenv().TF_Dump = { remotes = dumpRemotes, ball = dumpBallCandidates, held = dumpHeld, attrs = dumpAttributes }
getgenv().TF_Math = { lead = leadPosition, ballistic = ballisticDirection, path = samplePath }

notify("Touch Football", "Loaded. INSERT toggles Rayfield.", 5)
