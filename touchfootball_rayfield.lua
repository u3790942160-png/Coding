--!nocheck
-- touchfootball_rayfield.lua  --  v2.0
-- Touch Football (Roblox) feature suite with Rayfield UI.
-- v2 changes: metre-based reach (hard cap 6.00 m), reach grant for another
-- player, SNEAKY mode, JUGGLE, multi-strategy ball resolver with a learn
-- button, ball network-ownership probe, per-feature watchdog + diagnostics,
-- modern constraint fly, exact NoClip restore, throttled pooled ESP.
-- Every build-dependent name is still UNSET and gated; engine-level features
-- run without a dump.
-- Executor requirements: loadstring + HttpGet for the Rayfield fetch.
-- Optional APIs guarded: Drawing, gethui, setclipboard, writefile/readfile.

local VERSION = "v2.0"

----------------------------------------------------------------------
-- CONFIG  (provenance: kind | build | source | verified)
----------------------------------------------------------------------

local CFG = {
    -- [name | unknown | no dump supplied | not verified]
    BallNameOverride = "",
    -- [name | unknown | no dump supplied | not verified]
    BallParentOverride = "",
    -- [name | unknown | no dump supplied | not verified]
    CatchRemoteName = "",
    -- [name | unknown | no dump supplied | not verified]
    ThrowRemoteName = "",

    -- [constant | engine | Workspace.Gravity read live each frame | verified live]
    GravityFallback = 196.2,

    -- [constant | engine docs | Roblox 1 stud = 0.28 m | not verified against this build's scale]
    StudsPerMetre = 1 / 0.28,

    -- Hard ceiling requested for local reach, in metres.
    ReachMaxM = 6.0,
    -- Ceiling for the reach granted to another player, in metres.
    BoostMaxM = 30.0,
    -- SNEAKY clamps local reach to this, in metres.
    SneakyReachCapM = 2.5,
    -- SNEAKY floors aim reaction delay and ceils turn rate.
    SneakyReactionMs = 90,
    SneakyTurnCapDeg = 220,

    -- Name patterns used only when no override and no learned name exist.
    BallPatterns = { "football", "ball", "pigskin", "pball", "oval" },

    -- Where the learn button persists what it found, when the executor has file IO.
    LearnFile = "TouchFootball/learned_v2.json",
}

local STUDS_PER_M = CFG.StudsPerMetre

local HAS = {
    ball_name    = CFG.BallNameOverride ~= "",
    ball_parent  = CFG.BallParentOverride ~= "",
    catch_remote = CFG.CatchRemoteName ~= "",
    throw_remote = CFG.ThrowRemoteName ~= "",
    learned      = false,
}

----------------------------------------------------------------------
-- SERVICES / STATE
----------------------------------------------------------------------

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local StarterGui       = game:GetService("StarterGui")

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

    -- reach (metres is the authority, studs derived)
    ReachOn = false, ReachM = 2.0, ReachMode = "Nudge",
    ReachRing = false, ReachPullPower = 0.55,
    AutoCatch = false, AutoCatchM = 6.0,

    -- juggle
    Juggle = false, JuggleHeightM = 2.0, JuggleTempo = 2.0,
    JuggleStyle = "Vertical", JuggleCentering = 0.8,
    JuggleTaps = 0, JuggleLastTap = 0, JuggleSide = 1,

    -- reach grant for another player
    BoostOn = false, BoostTargetName = "All others",
    BoostM = 12.0, BoostMagnet = true,
    BoostResize = false, BoostStuds = 18, BoostVisual = true,
    BoostLocalOnly = nil,

    -- ball visuals
    BallEsp = false, BallTracer = false, BallPredict = false, BallFollow = false,

    -- aim
    AimOn = false, AimKeyHeld = false,
    AimFov = 180, AimSmooth = 0.25,
    AimReactionMs = 0, AimTurnCapDeg = 1080,
    AimPart = "Head", AimTeamCheck = false, AimVisibleOnly = false,
    AimTarget = nil, AimLockedAt = 0,

    -- esp
    EspOn = false, EspName = true, EspDist = true,
    EspBox = true, EspHighlight = false, EspTracer = false,
    EspTeamColor = true, EspMaxDist = 1500, EspRateHz = 60,
    EspLast = 0,

    -- misc
    FullBright = false, NoFog = false, Fov = 70,

    -- sneaky
    Sneaky = false,

    -- bookkeeping
    LastGravity = CFG.GravityFallback,
    Ownership = nil,          -- true / false / nil = not probed
    OwnershipAt = 0,
    BallTier = "unknown",
    Notices = {},
    FrameId = 0,
    Err = {},
    Disabled = {},
    ThrowSpeed = 180,
}

local Drawings   = {}   -- [player] = { box, tracer, text }
local Highlights = {}   -- [player] = Highlight
local OrigSize   = {}   -- [BasePart] = Vector3
local OrigCollide= {}   -- [BasePart] = boolean
local OrigMassless = {} -- [BasePart] = boolean
local BoostBoxes = {}   -- [player] = SelectionBox
local BallDraw   = { tracer = nil, dot = nil, ring = nil, path = {} }
local Conns      = {}
local Learned    = { ball_name = "", ball_path = "" }

----------------------------------------------------------------------
-- UTIL
----------------------------------------------------------------------

local function notify(title, text, dur)
    if S.Sneaky then return end
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = dur or 4 })
    end)
    print(("[TF %s] %s: %s"):format(VERSION, title, text))
end

-- Console-only report; still printed in SNEAKY because it draws nothing on screen.
local function report(text)
    print(text)
end

local function gateOff(feature, missing)
    if S.Notices[feature] then return end
    S.Notices[feature] = true
    notify("Feature gated", ("%s: %s is UNSET. Use DISCOVERY."):format(feature, missing), 6)
end

local function isFiniteNumber(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function isPlausibleVector(v)
    if typeof(v) ~= "Vector3" then return false end
    if not (isFiniteNumber(v.X) and isFiniteNumber(v.Y) and isFiniteNumber(v.Z)) then return false end
    local LIMIT = 1e6
    return math.abs(v.X) < LIMIT and math.abs(v.Y) < LIMIT and math.abs(v.Z) < LIMIT
end

local function metresToStuds(m)
    if not isFiniteNumber(m) then return 0 end
    return m * STUDS_PER_M
end

local function studsToMetres(s)
    if not isFiniteNumber(s) then return 0 end
    return s / STUDS_PER_M
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

local function handPart(ch)
    if not ch then return nil end
    return ch:FindFirstChild("RightHand") or ch:FindFirstChild("Right Arm")
        or ch:FindFirstChild("RightUpperArm") or ch:FindFirstChild("HumanoidRootPart")
end

local function handPosition(ch)
    local h = handPart(ch)
    return h and h.Position
end

-- Watchdog: a feature that throws is counted, reported once, and switched off
-- after a sustained failure run. It never takes the rest of the loop with it.
local function guard(name, fn)
    if S.Disabled[name] then return end
    local ok, err = pcall(fn)
    if ok then return end
    local e = S.Err[name]
    if not e then e = { n = 0, last = "" } S.Err[name] = e end
    e.n = e.n + 1
    e.last = tostring(err)
    if e.n == 1 then
        report(("[TF] %s errored: %s"):format(name, e.last))
    end
    if e.n > 240 then
        S.Disabled[name] = true
        report(("[TF] %s auto-disabled after %d errors. Last: %s"):format(name, e.n, e.last))
        notify("Watchdog", ("%s auto-disabled. See DIAGNOSTICS."):format(name), 8)
    end
end

----------------------------------------------------------------------
-- REACH / SNEAKY DERIVED VALUES
----------------------------------------------------------------------

local function reachMetres()
    local m = math.clamp(S.ReachM, 0, CFG.ReachMaxM)
    if S.Sneaky then m = math.min(m, CFG.SneakyReachCapM) end
    return m
end

local function reachStuds()
    return metresToStuds(reachMetres())
end

local function reachModeEffective()
    if S.Sneaky then return "Nudge" end
    return S.ReachMode
end

local function aimReactionMs()
    if S.Sneaky then return math.max(S.AimReactionMs, CFG.SneakyReactionMs) end
    return S.AimReactionMs
end

local function aimTurnCapDeg()
    if S.Sneaky then return math.min(S.AimTurnCapDeg, CFG.SneakyTurnCapDeg) end
    return S.AimTurnCapDeg
end

----------------------------------------------------------------------
-- LEARNED VALUES (file IO when the executor has it)
----------------------------------------------------------------------

local function saveLearned()
    if not (writefile and isfolder and makefolder) then return false end
    local ok = pcall(function()
        if not isfolder("TouchFootball") then makefolder("TouchFootball") end
        writefile(CFG.LearnFile, HttpService:JSONEncode(Learned))
    end)
    return ok
end

local function loadLearned()
    if not (readfile and isfile) then return false end
    local ok, data = pcall(function()
        if not isfile(CFG.LearnFile) then return nil end
        return HttpService:JSONDecode(readfile(CFG.LearnFile))
    end)
    if ok and type(data) == "table" and type(data.ball_name) == "string" and data.ball_name ~= "" then
        Learned.ball_name = data.ball_name
        Learned.ball_path = type(data.ball_path) == "string" and data.ball_path or ""
        HAS.learned = true
        return true
    end
    return false
end

----------------------------------------------------------------------
-- BALL RESOLVER v2
-- Strategy order: override -> learned -> held by any character -> name
-- pattern -> loose small unanchored part with motion. Tier is reported, never
-- promoted. Result is cached for one frame so a heavy scan runs once.
----------------------------------------------------------------------

local BallCache = { part = nil, tier = "unknown", stamp = -1 }

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

local function asBasePart(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") and inst.PrimaryPart then return inst.PrimaryPart end
    if inst:IsA("Tool") then
        local h = inst:FindFirstChild("Handle")
        if h and h:IsA("BasePart") then return h end
        local any = inst:FindFirstChildWhichIsA("BasePart")
        if any then return any end
    end
    return nil
end

local function findByName(root, name)
    local hit = root:FindFirstChild(name, true)
    return asBasePart(hit)
end

-- Any character currently holding something that reads as the ball.
local function findHeld()
    for _, plr in ipairs(Players:GetPlayers()) do
        local ch = plr.Character
        if ch then
            for _, inst in ipairs(ch:GetChildren()) do
                if inst:IsA("Tool") then
                    local p = asBasePart(inst)
                    if p and (nameLooksLikeBall(inst.Name) or nameLooksLikeBall(p.Name)) then
                        return p
                    end
                end
            end
            for _, inst in ipairs(ch:GetDescendants()) do
                if inst:IsA("BasePart") and nameLooksLikeBall(inst.Name) then return inst end
            end
        end
    end
    return nil
end

local function findByPattern(root)
    local best, bestScore = nil, math.huge
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("BasePart") and nameLooksLikeBall(inst.Name) and isPlausibleVector(inst.Position) then
            local score = inst.Size.Magnitude
            if score < bestScore then best, bestScore = inst, score end
        end
    end
    return best
end

-- Last resort: a small unanchored part that is moving or is a ball mesh.
local function findLoose(root)
    local best, bestScore = nil, math.huge
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("BasePart") and not inst.Anchored and isPlausibleVector(inst.Position) then
            local sz = inst.Size.Magnitude
            if sz < 6 then
                local moving = inst.AssemblyLinearVelocity.Magnitude > 1
                local round = (inst:IsA("Part") and inst.Shape == Enum.PartType.Ball)
                    or inst:FindFirstChildOfClass("SpecialMesh") ~= nil
                if moving or round then
                    local score = sz - (moving and 2 or 0) - (round and 2 or 0)
                    if score < bestScore then best, bestScore = inst, score end
                end
            end
        end
    end
    return best
end

local function getBall()
    -- Cached for the current frame: several features resolve the ball per frame
    -- and the pattern/loose strategies walk the whole workspace.
    local stamp = S.FrameId
    if BallCache.stamp == stamp and BallCache.part and BallCache.part.Parent then
        return BallCache.part, BallCache.tier
    end

    local root = searchRoot()
    local part, tier = nil, "unknown"

    if HAS.ball_name then
        part = findByName(root, CFG.BallNameOverride)
        tier = part and "confirmed" or "confirmed-missing"
    end
    if not part and HAS.learned then
        part = findByName(root, Learned.ball_name)
        if part then tier = "learned" end
    end
    if not part then
        part = findHeld()
        if part then tier = "derived-held" end
    end
    if not part then
        part = findByPattern(root)
        if part then tier = "derived-name" end
    end
    if not part then
        part = findLoose(root)
        if part then tier = "derived-loose" end
    end

    BallCache.part, BallCache.tier, BallCache.stamp = part, tier, stamp
    S.BallTier = tier
    return part, tier
end

local function learnBall()
    local ch = myChar()
    local found = nil
    if ch then
        for _, inst in ipairs(ch:GetChildren()) do
            if inst:IsA("Tool") then
                local p = asBasePart(inst)
                if p then found = p break end
            end
        end
        if not found then
            -- Only a part that reads as the ball, never a limb or an accessory.
            for _, inst in ipairs(ch:GetDescendants()) do
                if inst:IsA("BasePart") and inst.Parent ~= ch and nameLooksLikeBall(inst.Name) then
                    found = inst
                    break
                end
            end
        end
    end
    if not found then
        found = findHeld() or findLoose(searchRoot())
    end
    if not found then
        notify("Learn", "Nothing to learn. Hold the ball, then press again.", 6)
        return nil
    end
    Learned.ball_name = found.Name
    Learned.ball_path = found:GetFullName()
    HAS.learned = true
    BallCache.stamp = -1
    local saved = saveLearned()
    report(("[TF] learned ball: %s  (%s)  persisted=%s"):format(Learned.ball_name, Learned.ball_path, tostring(saved)))
    notify("Learn", ("Ball = %s%s"):format(Learned.ball_name, saved and " (saved)" or ""), 6)
    return found
end

----------------------------------------------------------------------
-- NETWORK OWNERSHIP PROBE
-- Reach, magnet, juggle and the physics throw all write to the ball. If the
-- server owns it, those writes are reverted and the feature does nothing.
-- This measures it instead of guessing.
----------------------------------------------------------------------

local function probeOwnership()
    local ball = getBall()
    if not ball then
        S.Ownership = nil
        report("[TF] ownership probe: no ball resolved")
        return nil
    end
    local before = ball.Position
    if not isPlausibleVector(before) then
        S.Ownership = nil
        return nil
    end
    local wanted = before + Vector3.new(0, 0.35, 0)
    local ok = pcall(function() ball.CFrame = CFrame.new(wanted) end)
    if not ok then
        S.Ownership = false
        report("[TF] ownership probe: CFrame write threw -> server owned")
        return false
    end
    task.wait(0.12)
    local after = ball.Position
    local held = isPlausibleVector(after) and (after - wanted).Magnitude < 0.9
    pcall(function()
        if (ball.Position - wanted).Magnitude < 2 then ball.CFrame = CFrame.new(before) end
    end)
    S.Ownership = held and true or false
    S.OwnershipAt = os.clock()
    report(("[TF] ownership probe: %s (moved %.3f studs, kept=%s)"):format(
        held and "CLIENT can move the ball" or "SERVER owns the ball",
        (after - before).Magnitude, tostring(held)))
    return S.Ownership
end

----------------------------------------------------------------------
-- PURE MATH  (checkable without the game)
-- Roblox: Y-up, studs, Workspace.Gravity in studs/s^2, FieldOfView in degrees.
----------------------------------------------------------------------

local function leadPosition(targetPos, targetVel, travelTime, gravity)
    if not (isPlausibleVector(targetPos) and isPlausibleVector(targetVel)) then return nil end
    if not isFiniteNumber(travelTime) or travelTime < 0 or travelTime > 10 then return nil end
    local g = isFiniteNumber(gravity) and gravity or CFG.GravityFallback
    local drop = 0.5 * g * travelTime * travelTime
    local out = targetPos + (targetVel * travelTime) - Vector3.new(0, drop, 0)
    if not isPlausibleVector(out) then return nil end
    return out
end

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
    local tanTheta = (s2 - math.sqrt(disc)) / (g * x)   -- low arc
    local dir = flat.Unit + Vector3.new(0, tanTheta, 0)
    if not isPlausibleVector(dir) or dir.Magnitude < 1e-6 then return nil end
    return dir.Unit
end

-- Launch speed that reaches apex h above the release point.
local function apexVelocity(h, gravity)
    local g = isFiniteNumber(gravity) and gravity or CFG.GravityFallback
    if not isFiniteNumber(h) or h <= 0 or g <= 0 then return 0 end
    return math.sqrt(2 * g * h)
end

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

-- Rotate a CFrame toward a target with a hard angular rate cap (deg/s).
local function cappedLook(current, targetPos, maxDeg, dt, smooth)
    if not isPlausibleVector(targetPos) then return current end
    local want = CFrame.new(current.Position, targetPos)
    local alpha = math.clamp(1 - smooth, 0.02, 1)
    local stepped = current:Lerp(want, alpha)
    local dot = math.clamp(current.LookVector:Dot(stepped.LookVector), -1, 1)
    local angle = math.deg(math.acos(dot))
    local allowed = maxDeg * math.max(dt, 1 / 240)
    if angle > allowed and angle > 1e-4 then
        stepped = current:Lerp(stepped, allowed / angle)
    end
    return stepped
end

local function worldToScreen(pos)
    if not isPlausibleVector(pos) then return nil, false end
    local v, onScreen = Camera:WorldToViewportPoint(pos)
    if v.Z <= 0 then return nil, false end
    if not (isFiniteNumber(v.X) and isFiniteNumber(v.Y)) then return nil, false end
    return Vector2.new(v.X, v.Y), onScreen
end

----------------------------------------------------------------------
-- DRAWING WRAPPERS  (Drawing API when present, ScreenGui otherwise)
----------------------------------------------------------------------

local HasDrawing = (type(Drawing) == "table")
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
        l.Size = UDim2.fromOffset(220, 16)
        l.AnchorPoint = Vector2.new(0.5, 0.5)
        l.Visible = false
        l.Parent = ensureFallbackGui()
        self.obj = l
    end
    return self
end

function Shape.newCircle()
    local self = setmetatable({ kind = "circle" }, Shape)
    if HasDrawing then
        self.obj = Drawing.new("Circle")
        self.obj.Thickness = 1
        self.obj.Filled = false
        self.obj.NumSides = 48
        self.obj.Visible = false
        self.obj.Color = Color3.fromRGB(255, 255, 255)
    else
        local f = Instance.new("Frame")
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 2
        f.BorderColor3 = Color3.fromRGB(255, 255, 255)
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Visible = false
        f.Parent = ensureFallbackGui()
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
        c.Parent = f
        self.obj = f
    end
    return self
end

function Shape:setColor(c)
    if HasDrawing then
        self.obj.Color = c
    elseif self.kind == "box" or self.kind == "circle" then
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

function Shape:circle(centre, radiusPx)
    if radiusPx < 2 or radiusPx > 4096 then self.obj.Visible = false return end
    if HasDrawing then
        self.obj.Position = centre
        self.obj.Radius = radiusPx
        self.obj.Visible = true
    else
        self.obj.Size = UDim2.fromOffset(radiusPx * 2, radiusPx * 2)
        self.obj.Position = UDim2.fromOffset(centre.X, centre.Y)
        self.obj.Visible = true
    end
end

function Shape:destroy()
    pcall(function()
        if HasDrawing then self.obj:Remove() else self.obj:Destroy() end
    end)
end

----------------------------------------------------------------------
-- ESP v2  (throttled, pooled, distance-culled)
----------------------------------------------------------------------

local function teamColorFor(plr)
    if S.EspTeamColor and plr.Team and LocalPlayer.Team then
        if plr.Team == LocalPlayer.Team then return Color3.fromRGB(90, 220, 120) end
        return Color3.fromRGB(240, 80, 80)
    end
    return Color3.fromRGB(235, 235, 235)
end

local function getBundle(plr)
    local b = Drawings[plr]
    if b then return b end
    b = { box = Shape.newBox(), tracer = Shape.newLine(), text = Shape.newText() }
    Drawings[plr] = b
    return b
end

local function clearBundle(plr)
    local b = Drawings[plr]
    if not b then return end
    b.box:destroy(); b.tracer:destroy(); b.text:destroy()
    Drawings[plr] = nil
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

local function clearAllEsp()
    for plr in pairs(Drawings) do clearBundle(plr) end
    for plr in pairs(Highlights) do applyHighlight(plr, nil, false) end
end

local function espStep()
    if not S.EspOn then
        for _, b in pairs(Drawings) do b.box:hide(); b.tracer:hide(); b.text:hide() end
        for plr in pairs(Highlights) do applyHighlight(plr, nil, false) end
        return
    end

    local now = os.clock()
    local interval = 1 / math.clamp(S.EspRateHz, 5, 240)
    if now - S.EspLast < interval then return end
    S.EspLast = now

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
                        else b.box:hide() end

                        if S.EspTracer then
                            b.tracer:setColor(col)
                            b.tracer:line(Vector2.new(vp.X / 2, vp.Y), Vector2.new(topV.X, botV.Y))
                        else b.tracer:hide() end

                        if S.EspName or S.EspDist then
                            local parts = {}
                            if S.EspName then parts[#parts + 1] = plr.Name end
                            if S.EspDist then parts[#parts + 1] = ("%.1fm"):format(studsToMetres(dist)) end
                            if S.BoostOn and (S.BoostTargetName == "All others" or S.BoostTargetName == plr.Name) then
                                parts[#parts + 1] = "[REACH]"
                            end
                            b.text:setColor(col)
                            b.text:text(table.concat(parts, "  "), Vector2.new(topV.X, topV.Y - 16))
                        else b.text:hide() end

                        applyHighlight(plr, ch, S.EspHighlight and not S.Sneaky)
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
-- BALL VISUALS v2  (+ reach ring in screen space)
----------------------------------------------------------------------

local function ensureBallDraw()
    if not BallDraw.tracer then BallDraw.tracer = Shape.newLine() end
    if not BallDraw.dot then BallDraw.dot = Shape.newText() end
    if not BallDraw.ring then BallDraw.ring = Shape.newCircle() end
    if #BallDraw.path == 0 then
        for i = 1, 20 do BallDraw.path[i] = Shape.newLine() end
    end
end

local function hideBallDraw()
    if BallDraw.tracer then BallDraw.tracer:hide() end
    if BallDraw.dot then BallDraw.dot:hide() end
    if BallDraw.ring then BallDraw.ring:hide() end
    for _, l in ipairs(BallDraw.path) do l:hide() end
end

local function tierColor(tier)
    if tier == "confirmed" then return Color3.fromRGB(255, 190, 60) end
    if tier == "learned" then return Color3.fromRGB(140, 255, 170) end
    return Color3.fromRGB(255, 120, 200)
end

local function ringStep()
    if not (S.ReachRing and S.ReachOn) or S.Sneaky then
        if BallDraw.ring then BallDraw.ring:hide() end
        return
    end
    ensureBallDraw()
    local ch = myChar()
    local hand = handPosition(ch)
    if not hand then BallDraw.ring:hide() return end
    local centre, onScreen = worldToScreen(hand)
    if not (centre and onScreen) then BallDraw.ring:hide() return end
    local edge = worldToScreen(hand + Camera.CFrame.RightVector * reachStuds())
    if not edge then BallDraw.ring:hide() return end
    BallDraw.ring:setColor(Color3.fromRGB(120, 220, 255))
    BallDraw.ring:circle(centre, (edge - centre).Magnitude)
end

local function ballStep()
    if not (S.BallEsp or S.BallTracer or S.BallPredict) then
        if BallDraw.tracer then BallDraw.tracer:hide() end
        if BallDraw.dot then BallDraw.dot:hide() end
        for _, l in ipairs(BallDraw.path) do l:hide() end
        return
    end
    ensureBallDraw()
    local ball, tier = getBall()
    if not ball then hideBallDraw() return end

    local vp = Camera.ViewportSize
    local col = tierColor(tier)
    local scr, onScreen = worldToScreen(ball.Position)

    if S.BallEsp and scr and onScreen then
        local _, _, myRoot = myChar()
        local d = myRoot and (ball.Position - myRoot.Position).Magnitude or 0
        local mark = (tier == "confirmed" or tier == "learned") and "" or " ?"
        BallDraw.dot:setColor(col)
        BallDraw.dot:text(("BALL %.1fm%s"):format(studsToMetres(d), mark), scr)
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
        local pts = samplePath(ball.Position, ball.AssemblyLinearVelocity, S.LastGravity, #BallDraw.path, 0.06)
        local prev = ball.Position
        for i, l in ipairs(BallDraw.path) do
            local p = pts[i]
            if p then
                local a = worldToScreen(prev)
                local bb = worldToScreen(p)
                if a and bb then
                    l:setColor(Color3.fromRGB(120, 200, 255))
                    l:line(a, bb)
                else l:hide() end
                prev = p
            else l:hide() end
        end
    else
        for _, l in ipairs(BallDraw.path) do l:hide() end
    end
end

----------------------------------------------------------------------
-- REACH v2  (metres in, studs out, hard cap 6.00 m)
-- Snap writes CFrame. Nudge writes velocity toward the hand, which looks like
-- a normal catch and is what SNEAKY forces.
----------------------------------------------------------------------

local function pullBall(ball, target, mode, power)
    if not (isPlausibleVector(target) and isPlausibleVector(ball.Position)) then return false end
    if mode == "Snap" then
        return pcall(function()
            ball.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            ball.CFrame = CFrame.new(target)
        end)
    end
    local delta = target - ball.Position
    local d = delta.Magnitude
    if d < 0.05 then return true end
    local speed = math.clamp(d * (8 * math.clamp(power, 0.05, 1)), 2, 220)
    return pcall(function()
        ball.AssemblyLinearVelocity = delta.Unit * speed
    end)
end

local function reachStep()
    if not S.ReachOn then return end
    local ch = myChar()
    if not ch then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    if ball:IsDescendantOf(ch) then return end
    local hand = handPosition(ch)
    if not hand then return end
    local d = (ball.Position - hand).Magnitude
    if not isFiniteNumber(d) or d > reachStuds() then return end
    pullBall(ball, hand, reachModeEffective(), S.ReachPullPower)
end

local function autoCatchStep()
    if not S.AutoCatch then return end
    local ch = myChar()
    if not ch then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    if ball:IsDescendantOf(ch) then return end
    local hand = handPosition(ch)
    if not hand then return end
    local limit = metresToStuds(math.clamp(S.AutoCatchM, 0, 60))
    local d = (ball.Position - hand).Magnitude
    if not isFiniteNumber(d) or d > limit then return end

    if HAS.catch_remote then
        local rem = ReplicatedStorage:FindFirstChild(CFG.CatchRemoteName, true)
        if rem and rem:IsA("RemoteEvent") then
            pcall(function() rem:FireServer(ball) end)
            return
        end
    else
        gateOff("Auto catch remote path", "CFG.CatchRemoteName")
    end
    pullBall(ball, hand, reachModeEffective(), S.ReachPullPower)
end

local function ballFollowStep()
    if not S.BallFollow then return end
    local ch, hum, root = myChar()
    if not ch or not root or not hum then return end
    local ball = getBall()
    if not ball or ball:IsDescendantOf(ch) then return end
    local land = leadPosition(ball.Position, ball.AssemblyLinearVelocity, 0.6, S.LastGravity) or ball.Position
    local dir = Vector3.new(land.X - root.Position.X, 0, land.Z - root.Position.Z)
    if dir.Magnitude < 2 then return end
    hum:Move(dir.Unit, false)
end

local function teleportToBall()
    if S.Sneaky then
        notify("Teleport", "Blocked by SNEAKY.", 4)
        return
    end
    local ch, hum, root = myChar()
    if not ch then notify("Teleport", "No live character.", 3) return end
    local ball = getBall()
    if not ball then notify("Teleport", "Ball unresolved. Run DISCOVERY.", 5) return end
    pcall(function() root.CFrame = CFrame.new(ball.Position + Vector3.new(0, 4, 0)) end)
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
        notify("Throw", ("Out of range at %d studs/s."):format(speed), 4)
        return
    end

    if HAS.throw_remote then
        local rem = ReplicatedStorage:FindFirstChild(CFG.ThrowRemoteName, true)
        if rem and rem:IsA("RemoteEvent") then
            pcall(function() rem:FireServer(dir * speed, bestPlr) end)
            return
        end
    else
        gateOff("Throw remote path", "CFG.ThrowRemoteName")
    end
    pcall(function() ball.AssemblyLinearVelocity = dir * speed end)
end

----------------------------------------------------------------------
-- JUGGLE
-- Keeps the ball airborne over the hand by tapping it upward each time it
-- starts falling. Apex comes from the pure solve, not a guessed impulse.
----------------------------------------------------------------------

local function juggleStep()
    if not S.Juggle then return end
    local ch = myChar()
    if not ch then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    if ball:IsDescendantOf(ch) then return end
    local hand = handPosition(ch)
    if not hand then return end

    local apexStuds = metresToStuds(math.clamp(S.JuggleHeightM, 0.3, 8))
    if S.Sneaky then apexStuds = math.min(apexStuds, metresToStuds(1.5)) end

    local keepRadius = math.max(reachStuds(), apexStuds) * 2.0
    local flat = Vector3.new(ball.Position.X - hand.X, 0, ball.Position.Z - hand.Z)
    if flat.Magnitude > keepRadius then return end

    local now = os.clock()
    local minInterval = 1 / math.clamp(S.JuggleTempo, 0.2, 8)
    if now - S.JuggleLastTap < minInterval then return end

    local vel = ball.AssemblyLinearVelocity
    if not isPlausibleVector(vel) then return end
    local falling = vel.Y <= 0
    local lowEnough = ball.Position.Y <= hand.Y + apexStuds * 0.55
    if not (falling and lowEnough) then return end

    local wantTarget = hand
    if S.JuggleStyle == "Hand to hand" then
        local right = Camera.CFrame.RightVector * (reachStuds() * 0.45 * S.JuggleSide)
        wantTarget = hand + Vector3.new(right.X, 0, right.Z)
        S.JuggleSide = -S.JuggleSide
    end

    local up = apexVelocity(apexStuds, S.LastGravity)
    if up <= 0 then return end

    local centre = Vector3.new(wantTarget.X - ball.Position.X, 0, wantTarget.Z - ball.Position.Z)
    local lateral = centre * math.clamp(S.JuggleCentering, 0, 2)

    if S.JuggleStyle == "Orbit" then
        local radial = Vector3.new(ball.Position.X - hand.X, 0, ball.Position.Z - hand.Z)
        if radial.Magnitude > 0.3 then
            local tangent = Vector3.new(-radial.Z, 0, radial.X).Unit
            lateral = lateral + tangent * math.max(4, apexStuds * 0.8)
        else
            lateral = lateral + Camera.CFrame.RightVector * 6
        end
    end

    local out = Vector3.new(lateral.X, up, lateral.Z)
    if not isPlausibleVector(out) then return end
    local ok = pcall(function() ball.AssemblyLinearVelocity = out end)
    if ok then
        S.JuggleLastTap = now
        S.JuggleTaps = S.JuggleTaps + 1
    end
end

----------------------------------------------------------------------
-- REACH GRANT FOR ANOTHER PLAYER
-- Two independent parts: a magnet that pulls the ball to his hand inside his
-- granted radius (this is the reach itself), and an optional root resize.
-- The resize only holds where the client may write that part; boostProbe
-- measures it and says so rather than pretending.
----------------------------------------------------------------------

local function boostTargets()
    local out = {}
    if S.BoostTargetName == "All others" then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then out[#out + 1] = plr end
        end
    else
        local p = Players:FindFirstChild(S.BoostTargetName)
        if p and p ~= LocalPlayer then out[1] = p end
    end
    return out
end

local function boostVisualFor(plr, root, on)
    local box = BoostBoxes[plr]
    if not on then
        if box then pcall(function() box:Destroy() end) BoostBoxes[plr] = nil end
        return
    end
    if box and box.Adornee == root then return end
    if box then pcall(function() box:Destroy() end) end
    box = Instance.new("SelectionBox")
    box.Name = "TF_REACH"
    box.LineThickness = 0.03
    box.SurfaceTransparency = 0.85
    box.Color3 = Color3.fromRGB(255, 140, 60)
    box.SurfaceColor3 = Color3.fromRGB(255, 140, 60)
    box.Adornee = root
    box.Parent = root
    BoostBoxes[plr] = box
end

local function boostRestoreOne(plr)
    local ch, hum, root = alive(plr)
    if root then
        local sz = OrigSize[root]
        if sz then
            pcall(function() root.Size = sz end)
            OrigSize[root] = nil
        end
        local ms = OrigMassless[root]
        if ms ~= nil then
            pcall(function() root.Massless = ms end)
            OrigMassless[root] = nil
        end
    end
    boostVisualFor(plr, root, false)
end

local function boostRestoreAll()
    for _, plr in ipairs(Players:GetPlayers()) do boostRestoreOne(plr) end
    for part, sz in pairs(OrigSize) do
        pcall(function() part.Size = sz end)
        OrigSize[part] = nil
    end
    for plr in pairs(BoostBoxes) do boostVisualFor(plr, nil, false) end
end

local function boostResizeStep()
    if not (S.BoostOn and S.BoostResize) then return end
    local want = Vector3.new(S.BoostStuds, S.BoostStuds, S.BoostStuds)
    for _, plr in ipairs(boostTargets()) do
        local ch, hum, root = alive(plr)
        if root then
            if not OrigSize[root] then OrigSize[root] = root.Size end
            if OrigMassless[root] == nil then OrigMassless[root] = root.Massless end
            if (root.Size - want).Magnitude > 0.05 then
                pcall(function()
                    root.Size = want
                    root.Massless = true
                    root.CanCollide = false
                end)
            end
            boostVisualFor(plr, root, S.BoostVisual and not S.Sneaky)
        end
    end
end

local function boostMagnetStep()
    if not (S.BoostOn and S.BoostMagnet) then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    local myCh = myChar()
    if myCh and ball:IsDescendantOf(myCh) then return end

    local radius = metresToStuds(math.clamp(S.BoostM, 0, CFG.BoostMaxM))
    local bestPlr, bestD, bestHand = nil, math.huge, nil
    for _, plr in ipairs(boostTargets()) do
        local ch = alive(plr)
        if ch and not ball:IsDescendantOf(ch) then
            local hand = handPosition(ch)
            if hand then
                local d = (ball.Position - hand).Magnitude
                if isFiniteNumber(d) and d <= radius and d < bestD then
                    bestPlr, bestD, bestHand = plr, d, hand
                end
            end
        end
    end
    if not bestHand then return end
    pullBall(ball, bestHand, S.Sneaky and "Nudge" or S.ReachMode, S.ReachPullPower)
end

local function boostProbe()
    if not S.BoostResize then
        report("[TF] boost probe: resize is off, nothing to measure. The magnet half needs no probe.")
        return nil
    end
    local targets = boostTargets()
    local plr = targets[1]
    if not plr then
        report("[TF] boost probe: no target resolved")
        return nil
    end
    local ch, hum, root = alive(plr)
    if not root then
        report("[TF] boost probe: target has no live root")
        return nil
    end
    local want = Vector3.new(S.BoostStuds, S.BoostStuds, S.BoostStuds)
    if not OrigSize[root] then OrigSize[root] = root.Size end
    pcall(function() root.Size = want end)
    task.wait(0.25)
    local kept = (root.Size - want).Magnitude < 0.05
    S.BoostLocalOnly = not kept
    report(("[TF] boost probe on %s: size %s -> %s, kept=%s%s"):format(
        plr.Name, tostring(OrigSize[root]), tostring(root.Size), tostring(kept),
        kept and "" or "  (server rewrote it: the resize is local only, use the magnet half)"))
    return kept
end

----------------------------------------------------------------------
-- AIM v2  (reaction delay, angular rate cap, sticky target)
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
    local centre = Vector2.new(vp.X / 2, vp.Y / 2)
    local best, bestD = nil, S.AimFov

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if not (S.AimTeamCheck and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team) then
                local tch = alive(plr)
                if tch then
                    local part = partOf(tch, S.AimPart)
                    if part then
                        local scr, onScreen = worldToScreen(part.Position)
                        if scr and onScreen then
                            local d = (scr - centre).Magnitude
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

    local tgt = S.AimTarget
    local tch = tgt and alive(tgt)
    if not tch then
        tgt = pickAimTarget()
        if not tgt then return end
        S.AimTarget = tgt
        S.AimLockedAt = os.clock()
        tch = alive(tgt)
        if not tch then return end
    end

    if (os.clock() - S.AimLockedAt) * 1000 < aimReactionMs() then return end

    local part = partOf(tch, S.AimPart)
    if not part then return end
    local aimAt = part.Position
    local root = tch:FindFirstChild("HumanoidRootPart")
    if root then
        local travel = (aimAt - Camera.CFrame.Position).Magnitude / 1000
        local lead = leadPosition(aimAt, root.AssemblyLinearVelocity, travel, 0)
        if lead then aimAt = lead end
    end
    if not isPlausibleVector(aimAt) then return end

    Camera.CFrame = cappedLook(Camera.CFrame, aimAt, aimTurnCapDeg(), dt, S.AimSmooth)
end

----------------------------------------------------------------------
-- MOVEMENT v2
----------------------------------------------------------------------

local FlyRig = { att = nil, lin = nil, ori = nil, vel = nil, gyro = nil, modern = false }

local function stopFly()
    S.Fly = false
    for _, k in ipairs({ "lin", "ori", "att", "vel", "gyro" }) do
        local inst = FlyRig[k]
        if inst then pcall(function() inst:Destroy() end) end
        FlyRig[k] = nil
    end
    local ch, hum = myChar()
    if hum then pcall(function() hum.PlatformStand = false end) end
end

local function startFly()
    local ch, hum, root = myChar()
    if not root then S.Fly = false return end
    stopFly()
    S.Fly = true

    local okModern = pcall(function()
        local att = Instance.new("Attachment")
        att.Name = "TF_FlyAtt"
        att.Parent = root
        local lin = Instance.new("LinearVelocity")
        lin.Name = "TF_FlyLin"
        lin.Attachment0 = att
        lin.MaxForce = 1e6
        lin.RelativeTo = Enum.ActuatorRelativeTo.World
        lin.VectorVelocity = Vector3.new(0, 0, 0)
        lin.Parent = root
        local ori = Instance.new("AlignOrientation")
        ori.Name = "TF_FlyOri"
        ori.Attachment0 = att
        ori.Mode = Enum.OrientationAlignmentMode.OneAttachment
        ori.RigidityEnabled = false
        ori.MaxTorque = 1e6
        ori.Responsiveness = 60
        ori.CFrame = Camera.CFrame
        ori.Parent = root
        FlyRig.att, FlyRig.lin, FlyRig.ori, FlyRig.modern = att, lin, ori, true
    end)

    if not okModern then
        FlyRig.modern = false
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
        FlyRig.vel, FlyRig.gyro = v, g
    end

    pcall(function() hum.PlatformStand = true end)
    report(("[TF] fly rig: %s"):format(FlyRig.modern and "LinearVelocity + AlignOrientation" or "BodyVelocity + BodyGyro"))
end

local function flyWishDir()
    local dir = Vector3.new(0, 0, 0)
    local cf = Camera.CFrame
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
    return dir
end

local function flyStep()
    if not S.Fly then return end
    local ch, hum, root = myChar()
    if not root then return end
    local live = FlyRig.modern and (FlyRig.lin and FlyRig.lin.Parent == root)
        or ((not FlyRig.modern) and FlyRig.vel and FlyRig.vel.Parent == root)
    if not live then startFly() return end

    local dir = flyWishDir()
    local v = (dir.Magnitude > 0) and (dir.Unit * S.FlySpeed) or Vector3.new(0, 0, 0)
    if FlyRig.modern then
        FlyRig.lin.VectorVelocity = v
        FlyRig.ori.CFrame = Camera.CFrame
    else
        FlyRig.vel.Velocity = v
        FlyRig.gyro.CFrame = Camera.CFrame
    end
end

local function noclipEnable()
    local ch = myChar()
    if not ch then return end
    for _, p in ipairs(ch:GetDescendants()) do
        if p:IsA("BasePart") then
            if OrigCollide[p] == nil then OrigCollide[p] = p.CanCollide end
        end
    end
end

local function noclipRestore()
    for p, was in pairs(OrigCollide) do
        pcall(function() if p.Parent then p.CanCollide = was end end)
        OrigCollide[p] = nil
    end
end

local function noclipStep()
    if not S.NoClip then return end
    local ch = myChar()
    if not ch then return end
    for _, p in ipairs(ch:GetDescendants()) do
        if p:IsA("BasePart") then
            if OrigCollide[p] == nil then OrigCollide[p] = p.CanCollide end
            if p.CanCollide then p.CanCollide = false end
        end
    end
end

local function statsStep()
    local ch, hum = myChar()
    if not hum then return end
    if S.SpeedOn then
        local want = S.SpeedValue
        if S.Sneaky then want = math.min(want, 28) end
        if math.abs(hum.WalkSpeed - want) > 0.01 then hum.WalkSpeed = want end
    end
    if S.JumpOn then
        local want = S.JumpValue
        if S.Sneaky then want = math.min(want, 70) end
        if hum.UseJumpPower then
            if math.abs(hum.JumpPower - want) > 0.01 then hum.JumpPower = want end
        else
            local h = want * 0.14
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
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.FallingDown or st == Enum.HumanoidStateType.Ragdoll then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
    end
end

----------------------------------------------------------------------
-- LIGHTING
----------------------------------------------------------------------

local LightSave = nil

local function applyLighting()
    if S.FullBright then
        if not LightSave then
            LightSave = {
                Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
                GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
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
-- SNEAKY
-- One switch that makes every feature behave like a good player instead of a
-- script: velocity pulls only, reach capped, aim gets a reaction delay and a
-- turn-rate cap, teleport blocked, overlays and notifications suppressed.
----------------------------------------------------------------------

local function applySneaky()
    if S.Sneaky then
        for plr in pairs(Highlights) do applyHighlight(plr, nil, false) end
        for plr in pairs(BoostBoxes) do boostVisualFor(plr, nil, false) end
        if BallDraw.ring then BallDraw.ring:hide() end
        report(("[TF] SNEAKY on: reach capped %.2f m, pulls=Nudge, reaction>=%d ms, turn<=%d deg/s, teleport blocked."):format(
            CFG.SneakyReachCapM, CFG.SneakyReactionMs, CFG.SneakyTurnCapDeg))
    else
        report("[TF] SNEAKY off: caps lifted.")
    end
end

----------------------------------------------------------------------
-- DISCOVERY
----------------------------------------------------------------------

local function emit(lines, title)
    local out = table.concat(lines, "\n")
    print(out)
    if setclipboard then pcall(function() setclipboard(out) end) end
    notify("Discovery", title, 6)
    return out
end

local function dumpRemotes()
    local lines = { "=== TF REMOTE DUMP ===" }
    for _, r in ipairs({ ReplicatedStorage, Workspace, LocalPlayer }) do
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
    return emit(lines, ("Remotes dumped (%d)."):format(#lines - 3))
end

local function dumpBallCandidates()
    local lines = { "=== TF BALL CANDIDATES ===" }
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("BasePart") and nameLooksLikeBall(inst.Name) then
            lines[#lines + 1] = ("name %s | size=%s | anchored=%s | %s"):format(
                inst.Name, tostring(inst.Size), tostring(inst.Anchored), inst:GetFullName())
        end
    end
    local loose = findLoose(searchRoot())
    if loose then
        lines[#lines + 1] = ("loose %s | size=%s | vel=%.1f | %s"):format(
            loose.Name, tostring(loose.Size), loose.AssemblyLinearVelocity.Magnitude, loose:GetFullName())
    end
    if #lines == 1 then lines[#lines + 1] = "nothing matched. Hold the ball and press Learn ball." end
    return emit(lines, "Ball candidates printed.")
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
    return emit(lines, "Character tree printed.")
end

local function dumpAttributes()
    local ch, hum = myChar()
    local lines = { "=== TF ATTRIBUTE / VALUE DUMP ===" }
    for _, t in ipairs({ LocalPlayer, ch, hum }) do
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
    return emit(lines, "Attributes printed.")
end

local function selfTestMath()
    local g = 196.2
    local lines = { "=== TF MATH SELF TEST ===" }
    lines[#lines + 1] = ("1 m = %.4f studs, 6 m = %.2f studs"):format(STUDS_PER_M, metresToStuds(6))
    local d1 = ballisticDirection(Vector3.new(0, 0, 0), Vector3.new(100, 0, 0), 150, g)
    lines[#lines + 1] = "ballistic 100 studs @150: " .. (d1 and tostring(d1) or "nil (out of range)")
    local d2 = ballisticDirection(Vector3.new(0, 0, 0), Vector3.new(5000, 0, 0), 150, g)
    lines[#lines + 1] = "ballistic 5000 studs @150: " .. (d2 and tostring(d2) or "nil (out of range)")
    lines[#lines + 1] = ("apex 2 m needs %.2f studs/s up"):format(apexVelocity(metresToStuds(2), g))
    local l1 = leadPosition(Vector3.new(0, 10, 0), Vector3.new(20, 0, 0), 0.5, g)
    lines[#lines + 1] = "lead 0.5s: " .. (l1 and tostring(l1) or "nil")
    local bad = leadPosition(Vector3.new(0 / 0, 0, 0), Vector3.new(0, 0, 0), 0.5, g)
    lines[#lines + 1] = "NaN input rejected: " .. tostring(bad == nil)
    local pts = samplePath(Vector3.new(0, 50, 0), Vector3.new(0, 0, 60), g, 5, 0.1)
    lines[#lines + 1] = ("path samples: %d, last=%s"):format(#pts, #pts > 0 and tostring(pts[#pts]) or "none")
    local cf = cappedLook(CFrame.new(Vector3.new(0, 0, 0), Vector3.new(0, 0, -1)), Vector3.new(1, 0, 0), 90, 1 / 60, 0)
    local turned = math.deg(math.acos(math.clamp(Vector3.new(0, 0, -1):Dot(cf.LookVector), -1, 1)))
    lines[#lines + 1] = ("turn cap 90 deg/s over 1/60 s produced %.3f deg (<=1.5 expected)"):format(turned)
    local out = table.concat(lines, "\n")
    print(out)
    notify("Self test", "Math results in console.", 6)
    return out
end

-- The answer to "feature X does nothing": state, gates, tier, ownership, errors.
local function diagnostics()
    local ball, tier = getBall()
    local lines = {
        ("=== TF DIAGNOSTICS %s ==="):format(VERSION),
        ("ball: %s  tier=%s"):format(ball and ball:GetFullName() or "UNRESOLVED", tier),
        ("ball ownership: %s"):format(
            S.Ownership == true and "client can write (reach/juggle/throw work)"
            or S.Ownership == false and "SERVER owns it - CFrame and velocity writes are reverted"
            or "not probed - press 'Probe ball ownership'"),
        ("reach: on=%s  %.2f m (%.2f studs)  mode=%s  sneaky_cap=%s"):format(
            tostring(S.ReachOn), reachMetres(), reachStuds(), reachModeEffective(), tostring(S.Sneaky)),
        ("auto catch: on=%s  %.2f m  remote=%s"):format(
            tostring(S.AutoCatch), S.AutoCatchM, HAS.catch_remote and CFG.CatchRemoteName or "UNSET (physics path)"),
        ("juggle: on=%s  style=%s  apex=%.2f m  tempo=%.2f/s  taps=%d"):format(
            tostring(S.Juggle), S.JuggleStyle, S.JuggleHeightM, S.JuggleTempo, S.JuggleTaps),
        ("boost: on=%s  target=%s  %.2f m  magnet=%s  resize=%s(%d studs)  local_only=%s"):format(
            tostring(S.BoostOn), S.BoostTargetName, S.BoostM, tostring(S.BoostMagnet),
            tostring(S.BoostResize), S.BoostStuds,
            S.BoostLocalOnly == nil and "not probed" or tostring(S.BoostLocalOnly)),
        ("aim: on=%s  fov=%d px  smooth=%.2f  reaction=%d ms  turn cap=%d deg/s"):format(
            tostring(S.AimOn), S.AimFov, S.AimSmooth, aimReactionMs(), aimTurnCapDeg()),
        ("throw remote: %s"):format(HAS.throw_remote and CFG.ThrowRemoteName or "UNSET (physics path)"),
        ("fly rig: %s"):format(S.Fly and (FlyRig.modern and "constraints" or "legacy bodies") or "off"),
        ("drawing api: %s   gravity live: %.3f"):format(tostring(HasDrawing), S.LastGravity),
        ("learned ball: %s"):format(HAS.learned and Learned.ball_name or "none"),
        "-- watchdog --",
    }
    local any = false
    for name, e in pairs(S.Err) do
        any = true
        lines[#lines + 1] = ("%s: %d errors%s | last: %s"):format(
            name, e.n, S.Disabled[name] and " (AUTO-DISABLED)" or "", e.last)
    end
    if not any then lines[#lines + 1] = "no feature has thrown this session" end
    local out = table.concat(lines, "\n")
    print(out)
    if setclipboard then pcall(function() setclipboard(out) end) end
    notify("Diagnostics", "Full report in console.", 8)
    return out
end

----------------------------------------------------------------------
-- MAIN LOOP
----------------------------------------------------------------------

local function frame(dt)
    S.FrameId = S.FrameId + 1
    Camera = Workspace.CurrentCamera or Camera
    local okG, g = pcall(function() return Workspace.Gravity end)
    if okG and isFiniteNumber(g) and g > 0 then S.LastGravity = g end

    guard("stats", statsStep)
    guard("noclip", noclipStep)
    guard("fly", flyStep)
    guard("reach", reachStep)
    guard("autocatch", autoCatchStep)
    guard("juggle", juggleStep)
    guard("boost_magnet", boostMagnetStep)
    guard("boost_resize", boostResizeStep)
    guard("ball_follow", ballFollowStep)
    guard("aim", function() aimStep(dt) end)
    guard("esp", espStep)
    guard("ball_visuals", ballStep)
    guard("reach_ring", ringStep)
    guard("fov", function()
        if Camera and math.abs(Camera.FieldOfView - S.Fov) > 0.01 then Camera.FieldOfView = S.Fov end
    end)
end

Conns[#Conns + 1] = RunService.RenderStepped:Connect(frame)

Conns[#Conns + 1] = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2
        or input.KeyCode == Enum.KeyCode.ButtonL2 then
        S.AimKeyHeld = true
        S.AimLockedAt = os.clock()
    end
    if input.KeyCode == Enum.KeyCode.E then guard("autocatch", autoCatchStep) end
    if input.KeyCode == Enum.KeyCode.T then teleportToBall() end
    if input.KeyCode == Enum.KeyCode.J then
        S.Juggle = not S.Juggle
        notify("Juggle", S.Juggle and "on" or "off", 3)
    end
    if input.KeyCode == Enum.KeyCode.L then learnBall() end
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
    applyHighlight(plr, nil, false)
    boostRestoreOne(plr)
end)

Conns[#Conns + 1] = LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.6)
    OrigCollide = {}
    BallCache.stamp = -1
    if S.Fly then startFly() end
    if S.NoClip then noclipEnable() end
end)

local function teardown()
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    Conns = {}
    stopFly()
    noclipRestore()
    boostRestoreAll()
    S.EspOn = false
    clearAllEsp()
    hideBallDraw()
    if BallDraw.tracer then BallDraw.tracer:destroy() end
    if BallDraw.dot then BallDraw.dot:destroy() end
    if BallDraw.ring then BallDraw.ring:destroy() end
    for _, l in ipairs(BallDraw.path) do l:destroy() end
    BallDraw = { tracer = nil, dot = nil, ring = nil, path = {} }
    S.FullBright = false
    S.NoFog = false
    applyLighting()
    if FallbackGui then pcall(function() FallbackGui:Destroy() end) FallbackGui = nil end
    local ch, hum = myChar()
    if hum then
        pcall(function() hum.WalkSpeed = 16 end)
        pcall(function()
            if hum.UseJumpPower then hum.JumpPower = 50 else hum.JumpHeight = 7.2 end
        end)
        for _, st in ipairs({
            Enum.HumanoidStateType.FallingDown,
            Enum.HumanoidStateType.Ragdoll,
            Enum.HumanoidStateType.Physics,
        }) do
            pcall(function() hum:SetStateEnabled(st, true) end)
        end
    end
    if Camera then Camera.FieldOfView = 70 end
    print(("[TF %s] unloaded."):format(VERSION))
end

loadLearned()

----------------------------------------------------------------------
-- RAYFIELD UI
----------------------------------------------------------------------

local okFetch, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not okFetch or type(Rayfield) ~= "table" then
    print(("[TF %s] Rayfield fetch failed. Features are live, UI is not."):format(VERSION))
    getgenv().TF_Teardown = teardown
    getgenv().TF_State = S
    getgenv().TF_Diag = diagnostics
    getgenv().TF_Learn = learnBall
    getgenv().TF_Probe = probeOwnership
    return
end

local Window = Rayfield:CreateWindow({
    Name = ("Touch Football %s — bench build"):format(VERSION),
    Icon = 0,
    LoadingTitle = ("Touch Football %s"):format(VERSION),
    LoadingSubtitle = "olliE",
    Theme = "Default",
    ConfigurationSaving = { Enabled = true, FolderName = "TouchFootball", FileName = "tf_main_v2" },
    Discord = { Enabled = false, Invite = "", RememberJoins = false },
    KeySystem = false,
})

----------------------------------------------------------------------
local TabReach = Window:CreateTab("REACH", 0)

TabReach:CreateParagraph({
    Title = "Units",
    Content = ("Reach is set in metres and capped at %.2f m. 1 stud = 0.28 m, so %.2f m = %.2f studs. Snap writes the ball's CFrame; Nudge writes velocity toward the hand and reads as a normal catch. If the server owns the ball neither does anything — run DISCOVERY > Probe ball ownership."):format(
        CFG.ReachMaxM, CFG.ReachMaxM, metresToStuds(CFG.ReachMaxM)),
})

TabReach:CreateToggle({ Name = "Reach (catch assist)", CurrentValue = false, Flag = "reach_on",
    Callback = function(v) S.ReachOn = v end })

TabReach:CreateSlider({ Name = "Reach", Range = { 0.25, CFG.ReachMaxM }, Increment = 0.05,
    Suffix = " m", CurrentValue = 2.0, Flag = "reach_m",
    Callback = function(v) S.ReachM = math.clamp(v, 0, CFG.ReachMaxM) end })

TabReach:CreateDropdown({ Name = "Pull mode", Options = { "Nudge", "Snap" }, CurrentOption = { "Nudge" },
    MultipleOptions = false, Flag = "reach_mode",
    Callback = function(opt) S.ReachMode = (type(opt) == "table") and opt[1] or opt end })

TabReach:CreateSlider({ Name = "Pull power", Range = { 5, 100 }, Increment = 5, Suffix = " %",
    CurrentValue = 55, Flag = "reach_power",
    Callback = function(v) S.ReachPullPower = v / 100 end })

TabReach:CreateToggle({ Name = "Show reach ring", CurrentValue = false, Flag = "reach_ring",
    Callback = function(v) S.ReachRing = v end })

TabReach:CreateToggle({ Name = "Auto catch", CurrentValue = false, Flag = "autocatch",
    Callback = function(v) S.AutoCatch = v end })

TabReach:CreateSlider({ Name = "Auto catch range", Range = { 1, 30 }, Increment = 0.5, Suffix = " m",
    CurrentValue = 6.0, Flag = "autocatch_m",
    Callback = function(v) S.AutoCatchM = v end })

TabReach:CreateParagraph({
    Title = "Reach for another player",
    Content = "The magnet half is the actual grant: inside his radius the ball is pulled to his hand. The resize half enlarges his root locally and only holds where the client may write that part — press Probe below and it will tell you which half is doing the work.",
})

TabReach:CreateToggle({ Name = "Grant reach to another player", CurrentValue = false, Flag = "boost_on",
    Callback = function(v)
        S.BoostOn = v
        if not v then boostRestoreAll() end
    end })

local boostDropdown = TabReach:CreateDropdown({
    Name = "Who gets it", Options = { "All others" }, CurrentOption = { "All others" },
    MultipleOptions = false, Flag = "boost_target",
    Callback = function(opt)
        local pick = (type(opt) == "table") and opt[1] or opt
        if pick and pick ~= S.BoostTargetName then
            boostRestoreAll()
            S.BoostTargetName = pick
        end
    end })

local function refreshBoostList()
    local opts = { "All others" }
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then opts[#opts + 1] = plr.Name end
    end
    pcall(function() boostDropdown:Refresh(opts, false) end)
end

TabReach:CreateButton({ Name = "Refresh player list", Callback = refreshBoostList })

TabReach:CreateSlider({ Name = "His reach", Range = { 1, CFG.BoostMaxM }, Increment = 0.5, Suffix = " m",
    CurrentValue = 12.0, Flag = "boost_m",
    Callback = function(v) S.BoostM = math.clamp(v, 0, CFG.BoostMaxM) end })

TabReach:CreateToggle({ Name = "His magnet (the real grant)", CurrentValue = true, Flag = "boost_magnet",
    Callback = function(v) S.BoostMagnet = v end })

TabReach:CreateToggle({ Name = "Resize his root", CurrentValue = false, Flag = "boost_resize",
    Callback = function(v)
        S.BoostResize = v
        if not v then boostRestoreAll() end
    end })

TabReach:CreateSlider({ Name = "His root size", Range = { 2, 60 }, Increment = 1, Suffix = " studs",
    CurrentValue = 18, Flag = "boost_studs",
    Callback = function(v) S.BoostStuds = v end })

TabReach:CreateToggle({ Name = "Outline him", CurrentValue = true, Flag = "boost_visual",
    Callback = function(v)
        S.BoostVisual = v
        if not v then for plr in pairs(BoostBoxes) do boostVisualFor(plr, nil, false) end end
    end })

TabReach:CreateButton({ Name = "Probe his resize (does it stick?)", Callback = function() boostProbe() end })

----------------------------------------------------------------------
local TabBall = Window:CreateTab("BALL", 0)

TabBall:CreateParagraph({
    Title = "Ball identity",
    Content = HAS.ball_name
        and ("Override: " .. CFG.BallNameOverride .. " (tier confirmed)")
        or "No override. v2 resolves in order: learned name, held by any character, name pattern, small moving part. Tier is shown on the ball label; a '?' means it is a guess. Hold the ball and press Learn ball [L] to pin it.",
})

TabBall:CreateButton({ Name = "Learn ball from hand  [L]", Callback = function() learnBall() end })
TabBall:CreateButton({ Name = "Forget learned ball", Callback = function()
    Learned.ball_name, Learned.ball_path = "", ""
    HAS.learned = false
    BallCache.stamp = -1
    if writefile then pcall(function() writefile(CFG.LearnFile, HttpService:JSONEncode(Learned)) end) end
    notify("Learn", "Learned ball cleared.", 4)
end })

TabBall:CreateToggle({ Name = "Ball ESP (label + distance)", CurrentValue = false, Flag = "ball_esp",
    Callback = function(v) S.BallEsp = v end })
TabBall:CreateToggle({ Name = "Ball tracer", CurrentValue = false, Flag = "ball_tracer",
    Callback = function(v) S.BallTracer = v end })
TabBall:CreateToggle({ Name = "Ball prediction trail", CurrentValue = false, Flag = "ball_predict",
    Callback = function(v) S.BallPredict = v end })
TabBall:CreateToggle({ Name = "Walk to predicted landing", CurrentValue = false, Flag = "ball_follow",
    Callback = function(v) S.BallFollow = v end })

TabBall:CreateButton({ Name = "Teleport to ball  [T]", Callback = teleportToBall })

TabBall:CreateSlider({ Name = "Throw speed", Range = { 60, 600 }, Increment = 10, Suffix = " studs/s",
    CurrentValue = 180, Flag = "throw_speed",
    Callback = function(v) S.ThrowSpeed = v end })

TabBall:CreateButton({ Name = "Throw at nearest (ballistic solve)",
    Callback = function() throwAtNearest(S.ThrowSpeed) end })

----------------------------------------------------------------------
local TabJuggle = Window:CreateTab("JUGGLE", 0)

TabJuggle:CreateParagraph({
    Title = "How it works",
    Content = "Each time the ball starts falling inside the keep radius it gets one upward tap, sized from the apex you ask for: v = sqrt(2 g h) against live Workspace.Gravity. Tempo is the ceiling on taps per second. Needs client ownership of the ball, same as reach.",
})

TabJuggle:CreateToggle({ Name = "Juggle  [J]", CurrentValue = false, Flag = "juggle_on",
    Callback = function(v) S.Juggle = v end })

TabJuggle:CreateSlider({ Name = "Apex height", Range = { 0.3, 8 }, Increment = 0.1, Suffix = " m",
    CurrentValue = 2.0, Flag = "juggle_h",
    Callback = function(v) S.JuggleHeightM = v end })

TabJuggle:CreateSlider({ Name = "Tempo", Range = { 0.2, 8 }, Increment = 0.1, Suffix = " taps/s",
    CurrentValue = 2.0, Flag = "juggle_tempo",
    Callback = function(v) S.JuggleTempo = v end })

TabJuggle:CreateSlider({ Name = "Centering", Range = { 0, 200 }, Increment = 10, Suffix = " %",
    CurrentValue = 80, Flag = "juggle_centre",
    Callback = function(v) S.JuggleCentering = v / 100 end })

TabJuggle:CreateDropdown({ Name = "Style", Options = { "Vertical", "Orbit", "Hand to hand" },
    CurrentOption = { "Vertical" }, MultipleOptions = false, Flag = "juggle_style",
    Callback = function(opt) S.JuggleStyle = (type(opt) == "table") and opt[1] or opt end })

TabJuggle:CreateButton({ Name = "Reset tap counter", Callback = function()
    S.JuggleTaps = 0
    notify("Juggle", "Tap counter reset.", 3)
end })

----------------------------------------------------------------------
local TabMove = Window:CreateTab("MOVEMENT", 0)

TabMove:CreateToggle({ Name = "WalkSpeed override", CurrentValue = false, Flag = "speed_on",
    Callback = function(v)
        S.SpeedOn = v
        if not v then local _, hum = myChar() if hum then hum.WalkSpeed = 16 end end
    end })

TabMove:CreateSlider({ Name = "WalkSpeed", Range = { 16, 300 }, Increment = 1, Suffix = " studs/s",
    CurrentValue = 16, Flag = "speed_val", Callback = function(v) S.SpeedValue = v end })

TabMove:CreateToggle({ Name = "Jump override", CurrentValue = false, Flag = "jump_on",
    Callback = function(v)
        S.JumpOn = v
        if not v then
            local _, hum = myChar()
            if hum then
                if hum.UseJumpPower then hum.JumpPower = 50 else hum.JumpHeight = 7.2 end
            end
        end
    end })

TabMove:CreateSlider({ Name = "Jump power", Range = { 50, 500 }, Increment = 5, Suffix = "",
    CurrentValue = 50, Flag = "jump_val", Callback = function(v) S.JumpValue = v end })

TabMove:CreateToggle({ Name = "Infinite jump", CurrentValue = false, Flag = "infjump",
    Callback = function(v) S.InfJump = v end })

TabMove:CreateToggle({ Name = "NoClip", CurrentValue = false, Flag = "noclip",
    Callback = function(v)
        S.NoClip = v
        if v then noclipEnable() else noclipRestore() end
    end })

TabMove:CreateToggle({ Name = "Fly (WASD + Space/Ctrl)", CurrentValue = false, Flag = "fly",
    Callback = function(v) if v then startFly() else stopFly() end end })

TabMove:CreateSlider({ Name = "Fly speed", Range = { 20, 400 }, Increment = 5, Suffix = " studs/s",
    CurrentValue = 60, Flag = "fly_speed", Callback = function(v) S.FlySpeed = v end })

TabMove:CreateToggle({ Name = "Anti-ragdoll (state block)", CurrentValue = false, Flag = "antiragdoll",
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
    end })

----------------------------------------------------------------------
local TabAim = Window:CreateTab("AIMBOT", 0)

TabAim:CreateParagraph({
    Title = "Units and limits",
    Content = "FOV is a screen-space radius in pixels. Smoothing 0 snaps, 95 drags. Reaction delay holds the camera still after a new lock; turn cap limits degrees per second. Lead is linear velocity only — no drag, no interpolation delay, no tick rate modelled. Treat all four as uncalibrated until you tune them in game.",
})

TabAim:CreateToggle({ Name = "Camera aim (hold RMB / L2)", CurrentValue = false, Flag = "aim_on",
    Callback = function(v) S.AimOn = v end })
TabAim:CreateSlider({ Name = "FOV radius", Range = { 20, 900 }, Increment = 10, Suffix = " px",
    CurrentValue = 180, Flag = "aim_fov", Callback = function(v) S.AimFov = v end })
TabAim:CreateSlider({ Name = "Smoothing", Range = { 0, 95 }, Increment = 1, Suffix = " %",
    CurrentValue = 25, Flag = "aim_smooth", Callback = function(v) S.AimSmooth = v / 100 end })
TabAim:CreateSlider({ Name = "Reaction delay", Range = { 0, 400 }, Increment = 10, Suffix = " ms",
    CurrentValue = 0, Flag = "aim_react", Callback = function(v) S.AimReactionMs = v end })
TabAim:CreateSlider({ Name = "Turn rate cap", Range = { 90, 1440 }, Increment = 30, Suffix = " deg/s",
    CurrentValue = 1080, Flag = "aim_turn", Callback = function(v) S.AimTurnCapDeg = v end })
TabAim:CreateDropdown({ Name = "Aim part",
    Options = { "Head", "UpperTorso", "HumanoidRootPart", "LowerTorso" }, CurrentOption = { "Head" },
    MultipleOptions = false, Flag = "aim_part",
    Callback = function(opt) S.AimPart = (type(opt) == "table") and opt[1] or opt end })
TabAim:CreateToggle({ Name = "Team check", CurrentValue = false, Flag = "aim_team",
    Callback = function(v) S.AimTeamCheck = v end })
TabAim:CreateToggle({ Name = "Visible only (raycast)", CurrentValue = false, Flag = "aim_vis",
    Callback = function(v) S.AimVisibleOnly = v end })

----------------------------------------------------------------------
local TabEsp = Window:CreateTab("ESP", 0)

TabEsp:CreateToggle({ Name = "Player ESP", CurrentValue = false, Flag = "esp_on",
    Callback = function(v)
        S.EspOn = v
        if not v then clearAllEsp() end
    end })
TabEsp:CreateToggle({ Name = "Boxes", CurrentValue = true, Flag = "esp_box",
    Callback = function(v) S.EspBox = v end })
TabEsp:CreateToggle({ Name = "Names", CurrentValue = true, Flag = "esp_name",
    Callback = function(v) S.EspName = v end })
TabEsp:CreateToggle({ Name = "Distance (metres)", CurrentValue = true, Flag = "esp_dist",
    Callback = function(v) S.EspDist = v end })
TabEsp:CreateToggle({ Name = "Tracers", CurrentValue = false, Flag = "esp_tracer",
    Callback = function(v) S.EspTracer = v end })
TabEsp:CreateToggle({ Name = "Highlight fill", CurrentValue = false, Flag = "esp_hl",
    Callback = function(v)
        S.EspHighlight = v
        if not v then for plr in pairs(Highlights) do applyHighlight(plr, nil, false) end end
    end })
TabEsp:CreateToggle({ Name = "Team colour", CurrentValue = true, Flag = "esp_teamcol",
    Callback = function(v) S.EspTeamColor = v end })
TabEsp:CreateSlider({ Name = "Max distance", Range = { 100, 5000 }, Increment = 50, Suffix = " studs",
    CurrentValue = 1500, Flag = "esp_maxdist", Callback = function(v) S.EspMaxDist = v end })
TabEsp:CreateSlider({ Name = "Update rate", Range = { 10, 240 }, Increment = 10, Suffix = " Hz",
    CurrentValue = 60, Flag = "esp_hz", Callback = function(v) S.EspRateHz = v end })
TabEsp:CreateParagraph({ Title = "Renderer",
    Content = HasDrawing and "Drawing API detected — native shapes."
        or "No Drawing API — ScreenGui frames. Heavier, same output." })

----------------------------------------------------------------------
local TabSneaky = Window:CreateTab("SNEAKY", 0)

TabSneaky:CreateParagraph({
    Title = "What SNEAKY changes",
    Content = ("One switch over every feature: reach capped to %.2f m, every pull forced to Nudge so nothing teleports, aim given at least %d ms reaction and at most %d deg/s turn, ball teleport blocked, juggle apex capped at 1.50 m, WalkSpeed capped at 28 and jump at 70, highlights and outlines off, notifications silenced. Console reports still print."):format(
        CFG.SneakyReachCapM, CFG.SneakyReactionMs, CFG.SneakyTurnCapDeg),
})

TabSneaky:CreateToggle({ Name = "SNEAKY", CurrentValue = false, Flag = "sneaky",
    Callback = function(v)
        S.Sneaky = v
        applySneaky()
    end })

TabSneaky:CreateSlider({ Name = "Sneaky reach cap", Range = { 0.5, CFG.ReachMaxM }, Increment = 0.05,
    Suffix = " m", CurrentValue = 2.5, Flag = "sneaky_cap",
    Callback = function(v) CFG.SneakyReachCapM = v end })

TabSneaky:CreateSlider({ Name = "Sneaky reaction floor", Range = { 0, 400 }, Increment = 10, Suffix = " ms",
    CurrentValue = 90, Flag = "sneaky_react",
    Callback = function(v) CFG.SneakyReactionMs = v end })

TabSneaky:CreateSlider({ Name = "Sneaky turn ceiling", Range = { 90, 900 }, Increment = 10, Suffix = " deg/s",
    CurrentValue = 220, Flag = "sneaky_turn",
    Callback = function(v) CFG.SneakyTurnCapDeg = v end })

TabSneaky:CreateButton({ Name = "Print effective caps now", Callback = function()
    report(("[TF] effective: reach %.2f m (%.2f studs), mode %s, reaction %d ms, turn %d deg/s, sneaky=%s"):format(
        reachMetres(), reachStuds(), reachModeEffective(), aimReactionMs(), aimTurnCapDeg(), tostring(S.Sneaky)))
end })

----------------------------------------------------------------------
local TabMisc = Window:CreateTab("MISC", 0)

TabMisc:CreateToggle({ Name = "Fullbright", CurrentValue = false, Flag = "fullbright",
    Callback = function(v) S.FullBright = v applyLighting() end })
TabMisc:CreateToggle({ Name = "No fog", CurrentValue = false, Flag = "nofog",
    Callback = function(v) S.NoFog = v applyLighting() end })
TabMisc:CreateSlider({ Name = "Field of view", Range = { 40, 120 }, Increment = 1, Suffix = " deg",
    CurrentValue = 70, Flag = "fov", Callback = function(v) S.Fov = v end })

TabMisc:CreateButton({ Name = "Reset character stats", Callback = function()
    local _, hum = myChar()
    if not hum then return end
    hum.WalkSpeed = 16
    if hum.UseJumpPower then hum.JumpPower = 50 else hum.JumpHeight = 7.2 end
    notify("Misc", "WalkSpeed 16, jump reset.", 3)
end })

TabMisc:CreateButton({ Name = "Re-enable watchdog-disabled features", Callback = function()
    local n = 0
    for name in pairs(S.Disabled) do
        S.Disabled[name] = nil
        n = n + 1
    end
    S.Err = {}
    notify("Watchdog", ("%d feature(s) re-armed."):format(n), 4)
end })

TabMisc:CreateButton({ Name = "Unload everything", Callback = function()
    teardown()
    pcall(function() Rayfield:Destroy() end)
end })

----------------------------------------------------------------------
local TabDisc = Window:CreateTab("DISCOVERY", 0)

TabDisc:CreateParagraph({
    Title = "Start here when something does nothing",
    Content = "Probe ball ownership first. If the server owns the ball, reach, juggle, the magnets and the physics throw are all writing into a value the server overwrites — that is one cause, not five broken features. Then run Diagnostics for the per-feature state.",
})

TabDisc:CreateButton({ Name = "Probe ball ownership", Callback = function() probeOwnership() end })
TabDisc:CreateButton({ Name = "Diagnostics report", Callback = function() diagnostics() end })
TabDisc:CreateButton({ Name = "Dump remotes (RS + Workspace + Player)", Callback = dumpRemotes })
TabDisc:CreateButton({ Name = "Scan ball candidates", Callback = dumpBallCandidates })
TabDisc:CreateButton({ Name = "Dump character tree (hold the ball first)", Callback = dumpHeld })
TabDisc:CreateButton({ Name = "Dump attributes and values", Callback = dumpAttributes })
TabDisc:CreateButton({ Name = "Run math self test", Callback = selfTestMath })

----------------------------------------------------------------------
local TabCfg = Window:CreateTab("CONFIG", 0)

TabCfg:CreateInput({ Name = "Ball Instance name", CurrentValue = CFG.BallNameOverride,
    PlaceholderText = "exact name from DISCOVERY", RemoveTextAfterFocusLost = false, Flag = "cfg_ball_name",
    Callback = function(txt)
        CFG.BallNameOverride = txt or ""
        HAS.ball_name = CFG.BallNameOverride ~= ""
        BallCache.stamp = -1
        notify("Config", ("Ball name = %s"):format(HAS.ball_name and CFG.BallNameOverride or "UNSET"), 4)
    end })

TabCfg:CreateInput({ Name = "Ball parent (workspace child)", CurrentValue = CFG.BallParentOverride,
    PlaceholderText = "blank = whole workspace", RemoveTextAfterFocusLost = false, Flag = "cfg_ball_parent",
    Callback = function(txt)
        CFG.BallParentOverride = txt or ""
        HAS.ball_parent = CFG.BallParentOverride ~= ""
        BallCache.stamp = -1
    end })

TabCfg:CreateInput({ Name = "Catch RemoteEvent name", CurrentValue = CFG.CatchRemoteName,
    PlaceholderText = "blank = physics path only", RemoveTextAfterFocusLost = false, Flag = "cfg_catch",
    Callback = function(txt)
        CFG.CatchRemoteName = txt or ""
        HAS.catch_remote = CFG.CatchRemoteName ~= ""
        S.Notices = {}
    end })

TabCfg:CreateInput({ Name = "Throw RemoteEvent name", CurrentValue = CFG.ThrowRemoteName,
    PlaceholderText = "blank = physics path only", RemoveTextAfterFocusLost = false, Flag = "cfg_throw",
    Callback = function(txt)
        CFG.ThrowRemoteName = txt or ""
        HAS.throw_remote = CFG.ThrowRemoteName ~= ""
        S.Notices = {}
    end })

TabCfg:CreateInput({ Name = "Extra ball name pattern", CurrentValue = "",
    PlaceholderText = "lowercase substring", RemoveTextAfterFocusLost = true, Flag = "cfg_pattern",
    Callback = function(txt)
        if txt and txt ~= "" then
            CFG.BallPatterns[#CFG.BallPatterns + 1] = string.lower(txt)
            BallCache.stamp = -1
            notify("Config", ("Pattern added: %s"):format(txt), 4)
        end
    end })

TabCfg:CreateParagraph({ Title = "Tiers",
    Content = "confirmed = your override. learned = pinned with the Learn button. derived-held / derived-name / derived-loose = the resolver guessing, shown with a '?' on the ball label. Nothing is promoted automatically." })

Rayfield:LoadConfiguration()
refreshBoostList()

Conns[#Conns + 1] = Players.PlayerAdded:Connect(function() refreshBoostList() end)
Conns[#Conns + 1] = Players.PlayerRemoving:Connect(function() task.defer(refreshBoostList) end)

getgenv().TF_Teardown = teardown
getgenv().TF_State = S
getgenv().TF_Diag = diagnostics
getgenv().TF_Learn = learnBall
getgenv().TF_Probe = probeOwnership
getgenv().TF_Dump = { remotes = dumpRemotes, ball = dumpBallCandidates, held = dumpHeld, attrs = dumpAttributes }
getgenv().TF_Math = { lead = leadPosition, ballistic = ballisticDirection, path = samplePath, apex = apexVelocity, look = cappedLook }

notify("Touch Football", ("%s loaded. INSERT toggles the menu."):format(VERSION), 5)
