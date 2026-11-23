--!nocheck
-- touchfootball_rayfield.lua  --  v4.0
-- Touch Football (Roblox) feature suite. Rayfield menu + custom mobile HUD.
--
-- v4 rebuilds the part that decides whether anything happens at all:
--   1. ownership  - simulation radius is pushed every frame, so loose parts
--      near you become client-simulated and velocity/CFrame writes stick.
--   2. touch      - contact is fired directly into the game's own
--      TouchInterest, so the server runs its normal catch/kick path.
--   3. self-move  - your own character always replicates, so reach, GK and
--      tackles move YOU to the ball as well as the ball to you.
-- Every feature routes through those three channels instead of hoping a
-- raw ball write replicates.
--
-- Build-dependent names still live in CFG and are never guessed.

local VERSION = "v4.0"

----------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------

local CFG = {
    BallNameOverride = "",
    BallParentOverride = "",
    CatchRemoteName = "",
    ShootRemoteName = "",
    QuestRemoteName = "",
    RespawnRemoteName = "",
    MarkerGuiPath = "",
    StaffGroupId = 0,
    StaffMinRank = 100,
    StaffNames = {},
    DenyEventNames = {},

    GravityFallback = 196.2,
    StudsPerMetre = 1 / 0.28,

    ReachMaxM = 12.0,
    PokeMaxM = 8.0,
    GkReachMaxM = 14.0,
    TackleMaxM = 10.0,

    BallPatterns = { "football", "ball", "pigskin", "pball", "oval", "soccer" },
    GoalPatterns = { "goal", "net", "hoop", "post", "endzone", "touchline", "score" },

    LearnFile = "TouchFootball/learned_v4.json",
    ServerApi = "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",

    Accent = Color3.fromRGB(0, 225, 160),
    Accent2 = Color3.fromRGB(120, 90, 255),
    Panel = Color3.fromRGB(16, 17, 22),
}

local STUDS_PER_M = CFG.StudsPerMetre

local HAS = {
    ball_name = false, ball_parent = false, catch = false, shoot = false,
    quest = false, respawn = false, marker = false, staff_group = false,
    deny = false, learned_ball = false, learned_goals = false,
}

local function refreshHas()
    HAS.ball_name = CFG.BallNameOverride ~= ""
    HAS.ball_parent = CFG.BallParentOverride ~= ""
    HAS.catch = CFG.CatchRemoteName ~= ""
    HAS.shoot = CFG.ShootRemoteName ~= ""
    HAS.quest = CFG.QuestRemoteName ~= ""
    HAS.respawn = CFG.RespawnRemoteName ~= ""
    HAS.marker = CFG.MarkerGuiPath ~= ""
    HAS.staff_group = CFG.StaffGroupId > 0
    HAS.deny = #CFG.DenyEventNames > 0
end
refreshHas()

----------------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------------

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")
local TeleportService    = game:GetService("TeleportService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local StarterGui       = game:GetService("StarterGui")
local VirtualUser      = game:GetService("VirtualUser")
local Stats            = game:GetService("Stats")
local GuiService       = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

----------------------------------------------------------------------
-- EXECUTOR CAPABILITIES
-- Measured once. The HUD shows them, so a dead channel is visible instead
-- of looking like a dead feature.
----------------------------------------------------------------------

local CAP = {
    touch   = type(firetouchinterest) == "function",
    hidden  = type(sethiddenproperty) == "function",
    simrad  = type(setsimulationradius) == "function",
    drawing = type(Drawing) == "table",
    hui     = type(gethui) == "function",
    clip    = type(setclipboard) == "function",
    files   = type(writefile) == "function" and type(readfile) == "function",
    hook    = type(hookmetamethod) == "function" and type(getnamecallmethod) == "function",
    queue   = type(queue_on_teleport) == "function",
}

----------------------------------------------------------------------
-- STATE
----------------------------------------------------------------------

local S = {
    -- core channels
    TakeOwnership = true, UseTouch = true, SelfMove = true,

    -- settings
    AntiAfk = true, AutoBestServer = false, PanicStaff = false,
    Notifications = true, AutoQuest = false,
    Hud = true, HudScale = 100, HudCollapsed = false,
    Buttons = true, ButtonSize = 64, ButtonShape = "Rounded", ButtonColumns = 2,
    HopMaxPing = 120, LastHop = 0, FpsBoost = false,

    -- reach
    ProReach = true, ControlReach = false,
    ReachM = 4.0, ControlReachM = 7.0, ReachPriority = "Reach",
    BallHold = false, HoldOffsetM = 1.0,
    AdaptHighMs = true, AdaptPerMs = 0.012, AdaptTriggerPerMs = 0.02,
    ReachPower = 0.6, SnapSelf = false, HitboxExtender = false, HitboxM = 3.0,

    -- skills
    Sneaky = false, SneakyAirOnly = true, SneakyAutoAdapt = true,
    SneakyPower = 55, SneakyRangeM = 4.0,
    Pokers = false, PokeSpeed = 2.5, PokeRangeM = 3.0,
    AutoJuggle = false, JuggleReachM = 2.5, JuggleHeightM = 2.0, JuggleSticky = true,
    JuggleTaps = 0, JuggleLast = 0,
    GroundShots = false, GroundShotPower = 140,
    SpinFlick = false, FlickPower = 90,

    -- aimbot
    Aimbot = false, Aimlock = false,
    CurveAimbot = true, AutoAdaptCurve = true, RandomCurve = false,
    TopCorner = false, AutoDetectGoal = true,
    ShotPower = 190, ShotSpeed = 1.0, ShotGravity = 1.0,
    MissChance = 0, CurveAmount = 35, CurveRandomPct = 20,
    AutoNero = false, AutoHeader = false, ShotCharge = false, ChargeMax = 1.5,
    NeroPower = 210, HeaderPower = 150,

    -- aimpass
    AimPass = false, TeammatesOnly = true, ThroughBalls = false,
    CurveAimPass = false, PassMin = 90, PassMax = 220, LobMaxM = 8.0,
    AutoPassPressure = false, PressureM = 4.0,

    -- goalkeeper
    AutoGk = false, AutoGs = false, DiveSpeed = 110,
    GkReachM = 7.0, BlockDeny = false, PanicReach = false, PanicReachM = 10.0,
    KeeperRush = false, RushM = 18.0,

    -- defending
    AutoTackle = false, TackleM = 5.0, AutoIntercept = false,
    AutoPosition = false, PositionM = 8.0,

    -- movement
    SpeedOn = false, SpeedValue = 16, JumpOn = false, JumpValue = 50,
    InfJump = false, AutoSprint = false, SprintValue = 28,
    AntiStun = false, NoClip = false,

    -- special
    PhaseEnemy = false, PhaseMode = "Look At", PhaseTargetName = "",
    GoalFarm = false, SaveFarm = false, Dunk = false, DunkRangeM = 14.0,
    AntiPhase = false, TrickOms = false, TrickTempo = 3.0, TrickLast = 0,
    BallTime = false, BallTimeMul = 1.0,
    FramePlayer = false, FrameTargetName = "", BallFrozen = false,

    -- visuals
    BallEsp = false, PlayerEsp = false, BallTrail = false, PredictLine = false,
    RgbChar = false, BootTrail = false, TimeOfDay = false, TimeValue = 14,
    SpoofMarker = false, SpoofPing = 42, SpoofCpu = 3, SpoofSent = 12,

    -- bookkeeping
    FrameId = 0, LastGravity = CFG.GravityFallback, Ping = 0, Fps = 0,
    BallTier = "unknown", GoalTier = "unknown", Ownership = nil,
    Touches = 0, Writes = 0, SelfMoves = 0,
    Err = {}, Disabled = {}, Notices = {}, Binding = nil,
    LastQuest = 0, PokeLast = 0, ChargeStart = 0, RgbWasOn = false,
    TouchHz = 20, TouchLast = 0, FlickLast = 0, PressLast = 0, TackleLast = 0,
}

local KEYS = {
    Reach    = { kb = Enum.KeyCode.R, pad = Enum.KeyCode.ButtonR1 },
    Sneaky   = { kb = Enum.KeyCode.X, pad = Enum.KeyCode.ButtonL1 },
    Aimbot   = { kb = Enum.KeyCode.T, pad = Enum.KeyCode.ButtonY },
    AimPass  = { kb = Enum.KeyCode.G, pad = Enum.KeyCode.ButtonX },
    AutoGk   = { kb = Enum.KeyCode.V, pad = Enum.KeyCode.ButtonB },
    Phase    = { kb = Enum.KeyCode.F, pad = Enum.KeyCode.ButtonL3 },
    Juggle   = { kb = Enum.KeyCode.J, pad = Enum.KeyCode.DPadUp },
    Tackle   = { kb = Enum.KeyCode.Q, pad = Enum.KeyCode.DPadLeft },
    Nero     = { kb = Enum.KeyCode.N, pad = Enum.KeyCode.DPadRight },
    Dunk     = { kb = Enum.KeyCode.B, pad = Enum.KeyCode.DPadDown },
    BringBall= { kb = Enum.KeyCode.H, pad = Enum.KeyCode.ButtonSelect },
    Freeze   = { kb = Enum.KeyCode.K, pad = Enum.KeyCode.ButtonR3 },
    PanicEject = { kb = Enum.KeyCode.P, pad = Enum.KeyCode.ButtonStart },
    LearnBall  = { kb = Enum.KeyCode.L, pad = Enum.KeyCode.Unknown },
    HudToggle  = { kb = Enum.KeyCode.RightShift, pad = Enum.KeyCode.ButtonL2 },
}

local Learned = { ball_name = "", ball_path = "", goal_own = nil, goal_enemy = nil }

local Conns = {}
local Trails = {}
local PhaseSaved = {}
local CollideSaved = {}
local BallCache = { part = nil, tier = "unknown", stamp = -1 }
local GoalCache = { own = nil, enemy = nil, tier = "unknown", stamp = -1 }
local Hitbox = { part = nil, weld = nil }
local MarkerSaved = {}
local EspPool = {}

----------------------------------------------------------------------
-- UTIL
----------------------------------------------------------------------

local function report(text) print(text) end

local function notify(title, text, dur)
    if not S.Notifications then return end
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = dur or 3 })
    end)
end

-- Console only. Nothing about a missing config ever reaches the screen.
local function noteOnce(key, text)
    if S.Notices[key] then return end
    S.Notices[key] = true
    report("[TF] " .. text)
end

local function isFiniteNumber(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function isPlausibleVector(v)
    if typeof(v) ~= "Vector3" then return false end
    if not (isFiniteNumber(v.X) and isFiniteNumber(v.Y) and isFiniteNumber(v.Z)) then return false end
    return math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end

local function metresToStuds(m) return isFiniteNumber(m) and m * STUDS_PER_M or 0 end
local function studsToMetres(s) return isFiniteNumber(s) and s / STUDS_PER_M or 0 end

local function alive(plr)
    local ch = plr and plr.Character
    if not ch or not ch.Parent then return nil end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    local root = ch:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return nil end
    return ch, hum, root
end

local function myChar() return alive(LocalPlayer) end

local function footPart(ch)
    if not ch then return nil end
    return ch:FindFirstChild("RightFoot") or ch:FindFirstChild("Right Leg")
        or ch:FindFirstChild("RightLowerLeg") or ch:FindFirstChild("HumanoidRootPart")
end

local function footPosition(ch)
    local p = footPart(ch)
    return p and p.Position
end

local function headPosition(ch)
    local h = ch and ch:FindFirstChild("Head")
    return h and h.Position
end

local function guard(name, fn)
    if S.Disabled[name] then return end
    local ok, err = pcall(fn)
    if ok then return end
    local e = S.Err[name]
    if not e then e = { n = 0, last = "" } S.Err[name] = e end
    e.n = e.n + 1
    e.last = tostring(err)
    if e.n == 1 then report(("[TF] %s errored: %s"):format(name, e.last)) end
    if e.n > 400 then
        S.Disabled[name] = true
        report(("[TF] %s auto-disabled after %d errors. Last: %s"):format(name, e.n, e.last))
    end
end

local function readPing()
    local ok, v = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and isFiniteNumber(v) and v >= 0 then S.Ping = v end
    return S.Ping
end

local function adaptBonusM()
    if not S.AdaptHighMs then return 0 end
    return math.clamp(math.max(0, S.Ping - 80) * S.AdaptPerMs, 0, 4.0)
end

local function adaptTriggerBonusM()
    if not S.AdaptHighMs then return 0 end
    return math.clamp(math.max(0, S.Ping - 80) * S.AdaptTriggerPerMs, 0, 5.0)
end

local function reachMetres()
    local base = S.ControlReach and math.max(S.ReachM, S.ControlReachM) or S.ReachM
    return math.clamp(base + adaptBonusM(), 0, CFG.ReachMaxM + 4.0)
end

local function reachStuds() return metresToStuds(reachMetres()) end
local function reachTriggerStuds() return reachStuds() + metresToStuds(adaptTriggerBonusM()) end

----------------------------------------------------------------------
-- CHANNEL 1: OWNERSHIP
-- Pushing the simulation radius every frame is what hands the client
-- physics authority over loose parts near it. Without this, velocity and
-- CFrame writes on the ball are reverted by the server on the next step,
-- which is indistinguishable from "the feature does nothing".
----------------------------------------------------------------------

local function pushSimulationRadius()
    if not S.TakeOwnership then return end
    if CAP.simrad then
        pcall(function() setsimulationradius(math.huge, math.huge) end)
    end
    if CAP.hidden then
        pcall(function()
            sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
            sethiddenproperty(LocalPlayer, "MaximumSimulationRadius", math.huge)
        end)
    end
end

local function relaxPhysics()
    pcall(function() settings().Physics.AllowSleep = false end)
end

----------------------------------------------------------------------
-- CHANNEL 2: TOUCH
-- The server's own catch, kick and tackle handlers hang off TouchInterest.
-- Firing it directly makes the server run that handler with no remote name
-- needed, which is why this channel works where raw writes do not.
----------------------------------------------------------------------

local function fireTouch(a, b)
    if not (S.UseTouch and CAP.touch) then return false end
    if not (a and b and a.Parent and b.Parent) then return false end
    local ok = pcall(function()
        firetouchinterest(a, b, 0)
        firetouchinterest(a, b, 1)
    end)
    if ok then S.Touches = S.Touches + 1 end
    return ok
end

-- Touch with every limb that plausibly counts as a kick or a catch.
-- Rate limited: twelve limbs at frame rate is thousands of calls a second
-- and costs more than it buys, on a phone most of all.
local function touchBallWithBody(ch, ball)
    if not (ch and ball) then return false end
    local now = os.clock()
    if now - S.TouchLast < 1 / math.clamp(S.TouchHz, 1, 60) then return false end
    S.TouchLast = now
    local any = false
    for _, name in ipairs({
        "RightFoot", "LeftFoot", "Right Leg", "Left Leg",
        "RightLowerLeg", "LeftLowerLeg", "RightHand", "LeftHand",
        "Right Arm", "Left Arm", "Head", "HumanoidRootPart",
    }) do
        local p = ch:FindFirstChild(name)
        if p and p:IsA("BasePart") then
            if fireTouch(p, ball) then any = true end
        end
    end
    if Hitbox.part and Hitbox.part.Parent then
        if fireTouch(Hitbox.part, ball) then any = true end
    end
    return any
end

----------------------------------------------------------------------
-- CHANNEL 3: SELF MOVEMENT
-- Your own character always replicates. Moving yourself onto the ball is
-- the channel that cannot be refused, so reach, tackle and GK all use it.
----------------------------------------------------------------------

local function moveSelfTo(pos, keepY)
    local ch, hum, root = myChar()
    if not root or not isPlausibleVector(pos) then return false end
    local target = pos
    if keepY then target = Vector3.new(pos.X, root.Position.Y, pos.Z) end
    local ok = pcall(function()
        root.CFrame = CFrame.new(target, target + root.CFrame.LookVector)
    end)
    if ok then S.SelfMoves = S.SelfMoves + 1 end
    return ok
end

local function glideSelfTo(pos, speed)
    local ch, hum, root = myChar()
    if not root or not isPlausibleVector(pos) then return false end
    local delta = pos - root.Position
    if delta.Magnitude < 0.5 then return true end
    return (pcall(function()
        root.AssemblyLinearVelocity = delta.Unit * math.clamp(speed, 10, 260)
    end))
end

----------------------------------------------------------------------
-- LEARNED VALUES
----------------------------------------------------------------------

local function saveLearned()
    if not CAP.files then return false end
    local payload = {
        ball_name = Learned.ball_name, ball_path = Learned.ball_path,
        goal_own = Learned.goal_own and { Learned.goal_own.X, Learned.goal_own.Y, Learned.goal_own.Z } or nil,
        goal_enemy = Learned.goal_enemy and { Learned.goal_enemy.X, Learned.goal_enemy.Y, Learned.goal_enemy.Z } or nil,
    }
    return (pcall(function()
        if isfolder and makefolder and not isfolder("TouchFootball") then makefolder("TouchFootball") end
        writefile(CFG.LearnFile, HttpService:JSONEncode(payload))
    end))
end

local function loadLearned()
    if not CAP.files then return false end
    local ok, data = pcall(function()
        if isfile and not isfile(CFG.LearnFile) then return nil end
        return HttpService:JSONDecode(readfile(CFG.LearnFile))
    end)
    if not (ok and type(data) == "table") then return false end
    if type(data.ball_name) == "string" and data.ball_name ~= "" then
        Learned.ball_name = data.ball_name
        Learned.ball_path = type(data.ball_path) == "string" and data.ball_path or ""
        HAS.learned_ball = true
    end
    local function vec(t)
        if type(t) == "table" and #t == 3 then return Vector3.new(t[1], t[2], t[3]) end
        return nil
    end
    Learned.goal_own = vec(data.goal_own)
    Learned.goal_enemy = vec(data.goal_enemy)
    HAS.learned_goals = Learned.goal_enemy ~= nil
    return true
end

----------------------------------------------------------------------
-- BALL RESOLVER
-- v4 widens the net: a held Tool, a name match, a part inside a model that
-- matches, a BallMesh, or the nearest small unanchored part in play. The
-- resolver also scores by closeness to any player, because in a football
-- game the ball is nearly always near somebody.
----------------------------------------------------------------------

local function nameMatches(n, patterns)
    local low = string.lower(n)
    for _, pat in ipairs(patterns) do
        if string.find(low, pat, 1, true) then return true end
    end
    return false
end

local function nameLooksLikeBall(n) return nameMatches(n, CFG.BallPatterns) end

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
    if inst:IsA("Model") then
        if inst.PrimaryPart then return inst.PrimaryPart end
        return inst:FindFirstChildWhichIsA("BasePart")
    end
    if inst:IsA("Tool") then
        local h = inst:FindFirstChild("Handle")
        if h and h:IsA("BasePart") then return h end
        return inst:FindFirstChildWhichIsA("BasePart")
    end
    return nil
end

local function findByName(root, name)
    return asBasePart(root:FindFirstChild(name, true))
end

local function findHeld()
    for _, plr in ipairs(Players:GetPlayers()) do
        local ch = plr.Character
        if ch then
            for _, inst in ipairs(ch:GetChildren()) do
                if inst:IsA("Tool") then
                    local p = asBasePart(inst)
                    if p then return p end
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
        if inst:IsA("BasePart") and isPlausibleVector(inst.Position) then
            local hit = nameLooksLikeBall(inst.Name)
                or (inst.Parent and inst.Parent:IsA("Model") and nameLooksLikeBall(inst.Parent.Name))
            if hit then
                local score = inst.Size.Magnitude
                if score < bestScore then best, bestScore = inst, score end
            end
        end
    end
    return best
end

-- Nearest small part in play to any character, moving or round.
local function findLoose(root)
    local anchors = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        local _, _, r = alive(plr)
        if r then anchors[#anchors + 1] = r.Position end
    end
    local best, bestScore = nil, math.huge
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("BasePart") and isPlausibleVector(inst.Position) and inst.Size.Magnitude < 9 then
            local round = (inst:IsA("Part") and inst.Shape == Enum.PartType.Ball)
                or inst:FindFirstChildOfClass("SpecialMesh") ~= nil
                or inst:IsA("MeshPart")
            local moving = inst.AssemblyLinearVelocity.Magnitude > 0.5
            if round or moving or not inst.Anchored then
                local near = math.huge
                for _, a in ipairs(anchors) do
                    near = math.min(near, (inst.Position - a).Magnitude)
                end
                if near < 400 then
                    local score = inst.Size.Magnitude + near * 0.02
                        - (round and 3 or 0) - (moving and 3 or 0) - (inst.Anchored and 0 or 2)
                    if score < bestScore then best, bestScore = inst, score end
                end
            end
        end
    end
    return best
end

local function getBall()
    if BallCache.stamp == S.FrameId and BallCache.part and BallCache.part.Parent then
        return BallCache.part, BallCache.tier
    end
    local root = searchRoot()
    local part, tier = nil, "unknown"
    if HAS.ball_name then
        part = findByName(root, CFG.BallNameOverride)
        tier = part and "confirmed" or "confirmed-missing"
    end
    if not part and HAS.learned_ball then
        part = findByName(root, Learned.ball_name)
        if part then tier = "learned" end
    end
    if not part then
        part = findHeld()
        if part then tier = "held" end
    end
    if not part then
        part = findByPattern(root)
        if part then tier = "name" end
    end
    if not part then
        part = findLoose(root)
        if part then tier = "loose" end
    end
    BallCache.part, BallCache.tier, BallCache.stamp = part, tier, S.FrameId
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
    end
    if not found then
        -- Closest loose part to your feet wins; stand on the ball.
        local foot = footPosition(ch)
        if foot then
            local best, bestD = nil, metresToStuds(8)
            for _, inst in ipairs(searchRoot():GetDescendants()) do
                if inst:IsA("BasePart") and inst.Size.Magnitude < 9 and not inst:IsDescendantOf(ch or game) then
                    local d = (inst.Position - foot).Magnitude
                    if d < bestD then best, bestD = inst, d end
                end
            end
            found = best
        end
    end
    if not found then found = findHeld() or findLoose(searchRoot()) end
    if not found then
        notify("Learn", "Stand on the ball and press again.", 4)
        return nil
    end
    Learned.ball_name = found.Name
    Learned.ball_path = found:GetFullName()
    HAS.learned_ball = true
    BallCache.stamp = -1
    saveLearned()
    report(("[TF] learned ball: %s (%s)"):format(Learned.ball_name, Learned.ball_path))
    notify("Learn", ("Ball = %s"):format(Learned.ball_name), 4)
    return found
end

----------------------------------------------------------------------
-- GOAL RESOLVER
----------------------------------------------------------------------

local function goalCandidates()
    local out = {}
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("BasePart") and isPlausibleVector(inst.Position) then
            if nameMatches(inst.Name, CFG.GoalPatterns)
                or (inst.Parent and inst.Parent:IsA("Model") and nameMatches(inst.Parent.Name, CFG.GoalPatterns)) then
                out[#out + 1] = inst
            end
        end
    end
    return out
end

local function deriveGoals()
    local cands = goalCandidates()
    if #cands < 2 then return nil, nil, "unknown" end
    local sumX, sumZ = 0, 0
    for _, p in ipairs(cands) do sumX = sumX + p.Position.X sumZ = sumZ + p.Position.Z end
    local centre = Vector3.new(sumX / #cands, 0, sumZ / #cands)
    local spreadX, spreadZ = 0, 0
    for _, p in ipairs(cands) do
        spreadX = math.max(spreadX, math.abs(p.Position.X - centre.X))
        spreadZ = math.max(spreadZ, math.abs(p.Position.Z - centre.Z))
    end
    local useX = spreadX >= spreadZ
    local lowSum, lowN, highSum, highN = Vector3.new(), 0, Vector3.new(), 0
    for _, p in ipairs(cands) do
        local v = useX and (p.Position.X - centre.X) or (p.Position.Z - centre.Z)
        if v < 0 then lowSum = lowSum + p.Position lowN = lowN + 1
        else highSum = highSum + p.Position highN = highN + 1 end
    end
    if lowN == 0 or highN == 0 then return nil, nil, "unknown" end
    local a, b = lowSum / lowN, highSum / highN
    local _, _, root = myChar()
    local mine, theirs = a, b
    if root and (root.Position - b).Magnitude < (root.Position - a).Magnitude then mine, theirs = b, a end
    return mine, theirs, "derived"
end

local function getGoals()
    if GoalCache.stamp == S.FrameId and GoalCache.enemy then
        return GoalCache.own, GoalCache.enemy, GoalCache.tier
    end
    local own, enemy, tier = nil, nil, "unknown"
    if Learned.goal_enemy then
        own, enemy, tier = Learned.goal_own, Learned.goal_enemy, "learned"
    elseif S.AutoDetectGoal then
        own, enemy, tier = deriveGoals()
    end
    GoalCache.own, GoalCache.enemy, GoalCache.tier, GoalCache.stamp = own, enemy, tier, S.FrameId
    S.GoalTier = tier
    return own, enemy, tier
end

local function learnGoal(which)
    local _, _, root = myChar()
    if not root then return end
    local best, bestD = nil, math.huge
    for _, p in ipairs(goalCandidates()) do
        local d = (p.Position - root.Position).Magnitude
        if d < bestD then best, bestD = p, d end
    end
    local pos = best and best.Position or root.Position
    if which == "enemy" then Learned.goal_enemy = pos else Learned.goal_own = pos end
    HAS.learned_goals = Learned.goal_enemy ~= nil
    GoalCache.stamp = -1
    saveLearned()
    notify("Learn", ("%s goal pinned."):format(which), 3)
end

local function goalMouth(pos)
    local best, bestD = nil, math.huge
    for _, p in ipairs(goalCandidates()) do
        local d = (p.Position - pos).Magnitude
        if d < bestD then best, bestD = p, d end
    end
    if best then return math.max(best.Size.X, best.Size.Z), math.max(best.Size.Y, 6) end
    return 24, 10
end

----------------------------------------------------------------------
-- MATH
----------------------------------------------------------------------

local function leadPosition(pos, vel, t, gravity)
    if not (isPlausibleVector(pos) and isPlausibleVector(vel)) then return nil end
    if not isFiniteNumber(t) or t < 0 or t > 10 then return nil end
    local g = isFiniteNumber(gravity) and gravity or CFG.GravityFallback
    local out = pos + vel * t - Vector3.new(0, 0.5 * g * t * t, 0)
    return isPlausibleVector(out) and out or nil
end

local function ballisticDirection(fromPos, toPos, speed, gravity)
    if not (isPlausibleVector(fromPos) and isPlausibleVector(toPos)) then return nil end
    if not isFiniteNumber(speed) or speed <= 0 then return nil end
    local g = isFiniteNumber(gravity) and gravity or CFG.GravityFallback
    local delta = toPos - fromPos
    local flat = Vector3.new(delta.X, 0, delta.Z)
    local x, y = flat.Magnitude, delta.Y
    if x < 1e-4 then return Vector3.new(0, (y >= 0 and 1) or -1, 0) end
    local s2 = speed * speed
    local disc = s2 * s2 - g * (g * x * x + 2 * y * s2)
    if disc < 0 then return nil end
    local tanTheta = (s2 - math.sqrt(disc)) / (g * x)
    local dir = flat.Unit + Vector3.new(0, tanTheta, 0)
    if not isPlausibleVector(dir) or dir.Magnitude < 1e-6 then return nil end
    return dir.Unit
end

local function apexVelocity(h, gravity)
    local g = isFiniteNumber(gravity) and gravity or CFG.GravityFallback
    if not isFiniteNumber(h) or h <= 0 or g <= 0 then return 0 end
    return math.sqrt(2 * g * h)
end

local function curveSpin(dir, amountPct, side)
    if not isPlausibleVector(dir) or dir.Magnitude < 1e-6 then return Vector3.new() end
    local lateral = dir.Unit:Cross(Vector3.new(0, 1, 0))
    if lateral.Magnitude < 1e-6 then return Vector3.new() end
    return lateral.Unit * ((math.clamp(amountPct, 0, 100) / 100) * 60 * (side >= 0 and 1 or -1))
end

local function closestApproach(pos, vel, target)
    if not (isPlausibleVector(pos) and isPlausibleVector(vel) and isPlausibleVector(target)) then return nil, 0 end
    local v2 = vel:Dot(vel)
    if v2 < 1e-6 then return pos, 0 end
    local t = math.clamp((target - pos):Dot(vel) / v2, 0, 6)
    return pos + vel * t, t
end

local function worldToScreen(pos)
    if not isPlausibleVector(pos) then return nil, false end
    local v, on = Camera:WorldToViewportPoint(pos)
    if v.Z <= 0 then return nil, false end
    if not (isFiniteNumber(v.X) and isFiniteNumber(v.Y)) then return nil, false end
    return Vector2.new(v.X, v.Y), on
end

local function cappedLook(current, targetPos, maxDeg, dt, smooth)
    if not isPlausibleVector(targetPos) then return current end
    local want = CFrame.new(current.Position, targetPos)
    local stepped = current:Lerp(want, math.clamp(1 - smooth, 0.02, 1))
    local dot = math.clamp(current.LookVector:Dot(stepped.LookVector), -1, 1)
    local angle = math.deg(math.acos(dot))
    local allowed = maxDeg * math.max(dt, 1 / 240)
    if angle > allowed and angle > 1e-4 then stepped = current:Lerp(stepped, allowed / angle) end
    return stepped
end

----------------------------------------------------------------------
-- BALL WRITE ARBITER
----------------------------------------------------------------------

local PRIORITY = {
    PanicReach = 100, Freeze = 95, Bring = 90, Dunk = 85, GoalFarm = 80,
    Gk = 75, SaveFarm = 70, Tackle = 68, Shot = 65, Pass = 60, Nero = 58,
    Header = 56, Flick = 52, Poke = 50, Sneaky = 48, Trick = 46, Hold = 40,
    Reach = 35, Juggle = 30, Frame = 25, BallTime = 10,
}

local Pending = nil

local function requestBall(tag, apply)
    local prio = PRIORITY[tag] or 1
    if S.ReachPriority == tag then prio = prio + 50 end
    if Pending and Pending.prio >= prio then return false end
    Pending = { tag = tag, prio = prio, apply = apply }
    return true
end

local function flushBall()
    local req = Pending
    Pending = nil
    if not req then return end
    local ok, err = pcall(req.apply)
    if ok then
        S.Writes = S.Writes + 1
    else
        local e = S.Err["ball:" .. req.tag]
        if not e then e = { n = 0, last = "" } S.Err["ball:" .. req.tag] = e end
        e.n = e.n + 1
        e.last = tostring(err)
    end
end

local function setBallVelocity(ball, v)
    if not (ball and ball.Parent and isPlausibleVector(v)) then return false end
    ball.AssemblyLinearVelocity = v
    return true
end

local function setBallSpin(ball, w)
    if not (ball and ball.Parent and isPlausibleVector(w)) then return false end
    ball.AssemblyAngularVelocity = w
    return true
end

local function setBallCFrame(ball, pos)
    if not (ball and ball.Parent and isPlausibleVector(pos)) then return false end
    ball.CFrame = CFrame.new(pos)
    return true
end

local function pullBall(ball, target, natural, power)
    if not (ball and isPlausibleVector(target) and isPlausibleVector(ball.Position)) then return false end
    if not natural then
        setBallVelocity(ball, Vector3.new(0, 0, 0))
        return setBallCFrame(ball, target)
    end
    local delta = target - ball.Position
    local d = delta.Magnitude
    if d < 0.05 then return true end
    return setBallVelocity(ball, delta.Unit * math.clamp(d * (8 * math.clamp(power, 0.05, 1)), 2, 240))
end

local function kickBall(ball, dir, power, curvePct, side)
    if not (ball and isPlausibleVector(dir) and dir.Magnitude > 1e-6) then return false end
    if not setBallVelocity(ball, dir.Unit * math.clamp(power, 1, 2000)) then return false end
    if curvePct and curvePct > 0 then
        setBallSpin(ball, curveSpin(dir, curvePct, side or 1))
    else
        setBallSpin(ball, Vector3.new(0, 0, 0))
    end
    return true
end

-- Remote paths are used when they exist and are silent when they do not.
local function fireCatchRemote(ball)
    if not HAS.catch then return false end
    local rem = ReplicatedStorage:FindFirstChild(CFG.CatchRemoteName, true)
    if not (rem and rem:IsA("RemoteEvent")) then return false end
    return (pcall(function() rem:FireServer(ball) end))
end

local function fireShootRemote(vec, target)
    if not HAS.shoot then return false end
    local rem = ReplicatedStorage:FindFirstChild(CFG.ShootRemoteName, true)
    if not (rem and rem:IsA("RemoteEvent")) then return false end
    return (pcall(function() rem:FireServer(vec, target) end))
end

----------------------------------------------------------------------
-- HITBOX EXTENDER
-- A real part welded to the foot. It gives the game's own touch logic a
-- bigger thing to collide with, which is the honest version of reach.
----------------------------------------------------------------------

local function destroyHitbox()
    if Hitbox.weld then pcall(function() Hitbox.weld:Destroy() end) end
    if Hitbox.part then pcall(function() Hitbox.part:Destroy() end) end
    Hitbox.part, Hitbox.weld = nil, nil
end

local function ensureHitbox()
    if not S.HitboxExtender then
        if Hitbox.part then destroyHitbox() end
        return
    end
    local ch = myChar()
    local anchor = footPart(ch)
    if not anchor then return end
    local size = metresToStuds(math.clamp(S.HitboxM, 0.5, CFG.ReachMaxM))
    if Hitbox.part and Hitbox.part.Parent and Hitbox.weld and Hitbox.weld.Part1 == anchor then
        if math.abs(Hitbox.part.Size.X - size) > 0.1 then
            pcall(function() Hitbox.part.Size = Vector3.new(size, size, size) end)
        end
        return
    end
    destroyHitbox()
    local p = Instance.new("Part")
    p.Name = "TF_Reach"
    p.Shape = Enum.PartType.Ball
    p.Size = Vector3.new(size, size, size)
    p.Transparency = 0.86
    p.Color = CFG.Accent
    p.Material = Enum.Material.ForceField
    p.CanCollide = false
    p.CanQuery = false
    p.Massless = true
    p.CFrame = anchor.CFrame
    p.Parent = anchor.Parent
    local w = Instance.new("WeldConstraint")
    w.Part0 = p
    w.Part1 = anchor
    w.Parent = p
    Hitbox.part, Hitbox.weld = p, w
end

----------------------------------------------------------------------
-- REACH  (all three channels, in order of reliability)
----------------------------------------------------------------------

local function reachStep()
    if not (S.ProReach or S.ControlReach) then return end
    local ch = myChar()
    if not ch then return end
    local ball = getBall()
    if not ball or not ball.Parent or ball:IsDescendantOf(ch) then return end
    local foot = footPosition(ch)
    if not foot then return end

    local d = (ball.Position - foot).Magnitude
    if not isFiniteNumber(d) then return end

    local trigger = reachTriggerStuds()
    if S.ProReach then
        local closing = (foot - ball.Position).Unit:Dot(ball.AssemblyLinearVelocity)
        if closing > 0 then trigger = trigger + math.clamp(closing * 0.06, 0, 10) end
    end
    if d > trigger then return end

    -- 1. touch: the server's own handler runs.
    touchBallWithBody(ch, ball)
    -- 2. remote, when one is configured.
    fireCatchRemote(ball)
    -- 3. self move: close the last gap with your own body, which replicates.
    if S.SnapSelf and d > metresToStuds(1.2) then
        local stand = ball.Position - (ball.Position - foot).Unit * metresToStuds(0.8)
        moveSelfTo(stand, true)
    end
    -- 4. ball write, now that ownership is being pushed every frame.
    local natural = S.ProReach and not S.ControlReach
    requestBall("Reach", function() pullBall(ball, foot, natural, S.ReachPower) end)
end

local function ballHoldStep()
    if not S.BallHold then return end
    local ch, hum, root = myChar()
    if not ch or not root then return end
    local ball = getBall()
    if not ball or not ball.Parent or ball:IsDescendantOf(ch) then return end
    local foot = footPosition(ch) or root.Position
    if (ball.Position - foot).Magnitude > reachTriggerStuds() * 1.5 then return end
    local ahead = root.CFrame.LookVector * metresToStuds(S.HoldOffsetM)
    local target = foot + Vector3.new(ahead.X, 0, ahead.Z)
    touchBallWithBody(ch, ball)
    requestBall("Hold", function() pullBall(ball, target, not S.ControlReach, math.max(S.ReachPower, 0.75)) end)
end

----------------------------------------------------------------------
-- OPPONENTS / TEAMMATES
----------------------------------------------------------------------

local function sameTeam(plr)
    return plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team
end

local function nearestOpponent(fromPos, maxStuds)
    local best, bestD = nil, maxStuds or math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not sameTeam(plr) then
            local _, _, root = alive(plr)
            if root then
                local d = (root.Position - fromPos).Magnitude
                if d < bestD then best, bestD = plr, d end
            end
        end
    end
    return best, bestD
end

local function teammates()
    local out = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if (S.TeammatesOnly and sameTeam(plr)) or not S.TeammatesOnly then
                if alive(plr) then out[#out + 1] = plr end
            end
        end
    end
    return out
end

-- Who is carrying the ball right now: nearest character to it inside a
-- normal dribbling distance.
local function ballCarrier()
    local ball = getBall()
    if not ball then return nil, nil end
    local best, bestD = nil, metresToStuds(3.5)
    for _, plr in ipairs(Players:GetPlayers()) do
        local ch, hum, root = alive(plr)
        if root then
            local foot = footPosition(ch) or root.Position
            local d = (ball.Position - foot).Magnitude
            if d < bestD then best, bestD = plr, d end
        end
    end
    return best, bestD
end

----------------------------------------------------------------------
-- SKILLS
----------------------------------------------------------------------

local function sneakyStep()
    if not S.Sneaky then return end
    local ch, hum, root = myChar()
    if not ch or not root then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    local foot = footPosition(ch) or root.Position
    if (ball.Position - foot).Magnitude > metresToStuds(S.SneakyRangeM) then return end
    if S.SneakyAirOnly and ball.Position.Y <= foot.Y + 1.2 then return end

    local lift = S.SneakyPower
    if S.SneakyAutoAdapt then
        local opp, oppD = nearestOpponent(root.Position, metresToStuds(14))
        if opp then
            local f = math.clamp(1 - (oppD / metresToStuds(14)), 0, 1)
            lift = S.SneakyPower * (0.7 + 0.8 * f)
        end
    end
    local fwd = root.CFrame.LookVector
    local flat = Vector3.new(fwd.X, 0, fwd.Z)
    flat = flat.Magnitude < 1e-4 and Vector3.new(0, 0, -1) or flat.Unit
    local v = flat * (lift * 0.9) + Vector3.new(0, apexVelocity(metresToStuds(2.2), S.LastGravity), 0)
    touchBallWithBody(ch, ball)
    requestBall("Sneaky", function() setBallVelocity(ball, v) end)
end

local function pokersStep()
    if not S.Pokers then return end
    local ch, hum, root = myChar()
    if not ch or not root then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    local foot = footPosition(ch) or root.Position
    if (ball.Position - foot).Magnitude > metresToStuds(math.min(S.PokeRangeM, CFG.PokeMaxM)) then return end
    local now = os.clock()
    if now - S.PokeLast < 1 / math.clamp(S.PokeSpeed, 0.2, 10) then return end
    local fwd = root.CFrame.LookVector
    local flat = Vector3.new(fwd.X, 0, fwd.Z)
    if flat.Magnitude < 1e-4 then return end
    local v = flat.Unit * (18 + S.PokeSpeed * 9) + Vector3.new(0, 6, 0)
    touchBallWithBody(ch, ball)
    requestBall("Poke", function()
        if setBallVelocity(ball, v) then S.PokeLast = now end
    end)
end

local function juggleStep()
    if not S.AutoJuggle then return end
    local ch = myChar()
    if not ch then return end
    local ball = getBall()
    if not ball or not ball.Parent or ball:IsDescendantOf(ch) then return end
    local foot = footPosition(ch)
    if not foot then return end
    local apex = metresToStuds(math.clamp(S.JuggleHeightM, 0.3, 8))
    local keep = metresToStuds(math.clamp(S.JuggleReachM, 0.5, 8))
    local flat = Vector3.new(ball.Position.X - foot.X, 0, ball.Position.Z - foot.Z)
    if flat.Magnitude > keep then return end
    local vel = ball.AssemblyLinearVelocity
    if not isPlausibleVector(vel) then return end
    if not (vel.Y <= 0 and ball.Position.Y <= foot.Y + apex * 0.55) then return end
    local now = os.clock()
    if now - S.JuggleLast < 0.12 then return end
    local back = Vector3.new(foot.X - ball.Position.X, 0, foot.Z - ball.Position.Z) * (S.JuggleSticky and 1.4 or 0.6)
    local v = Vector3.new(back.X, apexVelocity(apex, S.LastGravity), back.Z)
    touchBallWithBody(ch, ball)
    requestBall("Juggle", function()
        if setBallVelocity(ball, v) then
            S.JuggleLast = now
            S.JuggleTaps = S.JuggleTaps + 1
        end
    end)
end

local function groundShotStep()
    if not S.GroundShots then return end
    local ch, hum, root = myChar()
    if not ch or not root then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    local foot = footPosition(ch) or root.Position
    if (ball.Position - foot).Magnitude > reachTriggerStuds() then return end
    local _, enemy = getGoals()
    if not enemy then return end
    local flat = Vector3.new(enemy.X - ball.Position.X, 0, enemy.Z - ball.Position.Z)
    if flat.Magnitude < 1e-4 then return end
    local v = flat.Unit * math.clamp(S.GroundShotPower, 20, 1200)
    touchBallWithBody(ch, ball)
    fireShootRemote(v, enemy)
    requestBall("Shot", function() setBallVelocity(ball, v) end)
end

-- Spin Flick: lift and spin the ball sideways past the man in front.
local function spinFlickStep()
    if not S.SpinFlick then return end
    local ch, hum, root = myChar()
    if not ch or not root then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    local foot = footPosition(ch) or root.Position
    if (ball.Position - foot).Magnitude > reachTriggerStuds() then return end
    local now = os.clock()
    if now - S.FlickLast < 0.6 then return end
    local right = root.CFrame.RightVector
    local fwd = root.CFrame.LookVector
    local dir = (Vector3.new(fwd.X, 0, fwd.Z).Unit * 0.7 + Vector3.new(right.X, 0, right.Z).Unit * 0.7
        + Vector3.new(0, 0.5, 0))
    requestBall("Flick", function()
        if kickBall(ball, dir, S.FlickPower, 70, 1) then S.FlickLast = now end
    end)
end

----------------------------------------------------------------------
-- AIMBOT
----------------------------------------------------------------------

local function missOffset(target, widthStuds)
    if S.MissChance <= 0 then return target end
    if math.random(1, 100) > S.MissChance then return target end
    local side = (math.random(0, 1) == 0) and -1 or 1
    local push = widthStuds * (0.55 + math.random() * 0.5) * side
    return target + Vector3.new(push, math.random() * 3, push * 0.3)
end

local function shotTarget()
    local _, enemy, tier = getGoals()
    if not enemy then return nil, tier end
    local w, h = goalMouth(enemy)
    local aim = enemy
    if S.TopCorner then
        local _, _, root = myChar()
        local side = (root and root.Position.X > enemy.X) and -1 or 1
        aim = enemy + Vector3.new(w * 0.34 * side, h * 0.38, 0)
    end
    return missOffset(aim, w), tier
end

local function curveSideFor(ball, target)
    if S.RandomCurve then return (math.random(0, 1) == 0) and -1 or 1 end
    if not S.AutoAdaptCurve then return 1 end
    local _, _, root = myChar()
    if not root then return 1 end
    local toGoal = Vector3.new(target.X - ball.Position.X, 0, target.Z - ball.Position.Z)
    local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
    if toGoal.Magnitude < 1e-4 or facing.Magnitude < 1e-4 then return 1 end
    return (facing.Unit:Cross(toGoal.Unit).Y >= 0) and 1 or -1
end

local function curveAmountFor()
    local amt = S.CurveAmount
    if S.RandomCurve then
        amt = amt + (math.random() * 2 - 1) * (amt * (S.CurveRandomPct / 100))
    end
    return math.clamp(amt, 0, 100)
end

local function chargeMultiplier()
    if not S.ShotCharge then return 1 end
    if S.ChargeStart <= 0 then return 1 end
    local held = os.clock() - S.ChargeStart
    return 1 + math.clamp(held / math.max(S.ChargeMax, 0.2), 0, 1) * 0.8
end

local function takeShot(tag, power)
    local ch = myChar()
    if not ch then return false end
    local ball = getBall()
    if not ball or not ball.Parent then return false end
    local foot = footPosition(ch)
    if not foot or (ball.Position - foot).Magnitude > reachTriggerStuds() * 1.8 then return false end
    local target = shotTarget()
    if not target then return false end

    local speed = math.clamp(power * math.clamp(S.ShotSpeed, 0.2, 3) * chargeMultiplier(), 20, 2000)
    local grav = S.LastGravity * math.clamp(S.ShotGravity, 0.1, 3)
    local dir = ballisticDirection(ball.Position, target, speed, grav)
    if not dir then
        local d = target - ball.Position
        if d.Magnitude < 1e-4 then return false end
        dir = d.Unit
    end
    local curve = (S.CurveAimbot or S.RandomCurve) and curveAmountFor() or 0
    local side = curveSideFor(ball, target)

    touchBallWithBody(ch, ball)
    fireShootRemote(dir * speed, target)
    requestBall(tag, function() kickBall(ball, dir, speed, curve, side) end)
    return true
end

local function aimbotStep()
    if S.Aimbot then takeShot("Shot", S.ShotPower) end
end

local function aimlockStep(dt)
    if not S.Aimlock then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    Camera.CFrame = cappedLook(Camera.CFrame, ball.Position, 1080, dt, 0.35)
end

local function neroWindow()
    local ch = myChar()
    if not ch then return nil end
    local ball = getBall()
    if not ball or not ball.Parent then return nil end
    local foot, head = footPosition(ch), headPosition(ch)
    if not (foot and head) then return nil end
    if (ball.Position - foot).Magnitude > reachTriggerStuds() * 1.5 then return nil end
    if ball.Position.Y < foot.Y + 0.8 or ball.Position.Y > head.Y + 8 then return nil end
    return ball
end

local function fireNero()
    local ball = neroWindow()
    if not ball then return false end
    local target = shotTarget()
    if not target then return false end
    local lifted = target + Vector3.new(0, 4, 0)
    local dir = ballisticDirection(ball.Position, lifted, S.NeroPower, S.LastGravity)
        or (lifted - ball.Position).Unit
    local ch = myChar()
    touchBallWithBody(ch, ball)
    fireShootRemote(dir * S.NeroPower, target)
    requestBall("Nero", function()
        kickBall(ball, dir, S.NeroPower, S.CurveAimbot and curveAmountFor() or 0, curveSideFor(ball, target))
    end)
    return true
end

local function autoNeroStep()
    if S.AutoNero then fireNero() end
end

local function autoHeaderStep()
    if not S.AutoHeader then return end
    local ch = myChar()
    if not ch then return end
    local head = headPosition(ch)
    if not head then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    if (ball.Position - head).Magnitude > metresToStuds(2.6) then return end
    if ball.Position.Y < head.Y - 0.5 then return end
    local target = shotTarget()
    if not target then return end
    local dir = ballisticDirection(ball.Position, target, S.HeaderPower, S.LastGravity)
        or (target - ball.Position).Unit
    local hp = ch:FindFirstChild("Head")
    if hp then fireTouch(hp, ball) end
    requestBall("Header", function() kickBall(ball, dir, S.HeaderPower, 0, 1) end)
end

----------------------------------------------------------------------
-- AIMPASS
----------------------------------------------------------------------

local function pickReceiver(ballPos)
    local _, enemy = getGoals()
    local best, bestScore, bestPos = nil, -math.huge, nil
    for _, plr in ipairs(teammates()) do
        local ch, hum, root = alive(plr)
        if root then
            local pos = root.Position
            if S.ThroughBalls then
                local lead = leadPosition(pos, root.AssemblyLinearVelocity, 0.6, 0)
                if lead then pos = lead end
            end
            local d = (pos - ballPos).Magnitude
            if d > 4 and d < metresToStuds(70) then
                local score = -d * 0.25
                if enemy then score = score - (pos - enemy).Magnitude * 0.6 end
                local opp, oppD = nearestOpponent(pos, metresToStuds(20))
                if opp then score = score + math.min(oppD, metresToStuds(20)) * 0.4 end
                if score > bestScore then best, bestScore, bestPos = plr, score, pos end
            end
        end
    end
    return best, bestPos
end

local function doPass()
    local ch = myChar()
    if not ch then return false end
    local ball = getBall()
    if not ball or not ball.Parent then return false end
    local foot = footPosition(ch)
    if not foot or (ball.Position - foot).Magnitude > reachTriggerStuds() * 1.6 then return false end
    local rec, pos = pickReceiver(ball.Position)
    if not (rec and pos) then return false end

    local dist = (pos - ball.Position).Magnitude
    local power = math.clamp(S.PassMin + (S.PassMax - S.PassMin) * (dist / math.max(1, metresToStuds(70))),
        S.PassMin, S.PassMax)
    local lobCap = metresToStuds(S.LobMaxM)
    local dir = ballisticDirection(ball.Position, pos, power, S.LastGravity)
    if dir then
        local apex = (dir.Y * power) ^ 2 / (2 * math.max(S.LastGravity, 1))
        if apex > lobCap then
            local flat = Vector3.new(pos.X - ball.Position.X, 0, pos.Z - ball.Position.Z)
            if flat.Magnitude > 1e-4 then
                dir = (flat.Unit + Vector3.new(0, math.sqrt(2 * S.LastGravity * lobCap) / math.max(power, 1), 0)).Unit
            end
        end
    else
        local flat = pos - ball.Position
        if flat.Magnitude < 1e-4 then return false end
        dir = flat.Unit
    end
    touchBallWithBody(ch, ball)
    fireShootRemote(dir * power, pos)
    requestBall("Pass", function()
        kickBall(ball, dir, power, S.CurveAimPass and curveAmountFor() or 0, curveSideFor(ball, pos))
    end)
    return true
end

local function aimPassStep()
    if S.AimPass then doPass() end
end

-- Auto pass when an opponent closes on you while you have the ball.
local function pressurePassStep()
    if not S.AutoPassPressure then return end
    local ch, hum, root = myChar()
    if not root then return end
    local carrier = ballCarrier()
    if carrier ~= LocalPlayer then return end
    local opp = nearestOpponent(root.Position, metresToStuds(S.PressureM))
    if not opp then return end
    local now = os.clock()
    if now - S.PressLast < 1.2 then return end
    if doPass() then S.PressLast = now end
end

----------------------------------------------------------------------
-- GOALKEEPER
----------------------------------------------------------------------

local function ballThreatensOwnGoal()
    local own = select(1, getGoals())
    if not own then return nil, nil end
    local ball = getBall()
    if not ball or not ball.Parent then return nil, nil end
    local vel = ball.AssemblyLinearVelocity
    if not isPlausibleVector(vel) or vel.Magnitude < 4 then return nil, nil end
    local toGoal = own - ball.Position
    if toGoal.Magnitude < 1e-4 then return nil, nil end
    if vel.Unit:Dot(toGoal.Unit) < 0.25 then return nil, nil end
    local point, t = closestApproach(ball.Position, vel, own)
    return point, t
end

local function autoGkStep()
    if not (S.AutoGk or S.AutoGs) then return end
    local point, t = ballThreatensOwnGoal()
    if not point then return end
    local ch, hum, root = myChar()
    if not root then return end
    local ball = getBall()
    if not ball then return end

    local airborne = ball.Position.Y > root.Position.Y + 2.5
    if airborne and not S.AutoGk then return end
    if (not airborne) and not S.AutoGs then return end

    local intercept = leadPosition(ball.Position, ball.AssemblyLinearVelocity, math.min(t, 0.6), S.LastGravity) or point
    -- Self movement is the dive: it always replicates.
    glideSelfTo(intercept, S.DiveSpeed)

    local hands = (ch:FindFirstChild("RightHand") and ch.RightHand.Position) or root.Position
    if (ball.Position - hands).Magnitude <= metresToStuds(math.min(S.GkReachM, CFG.GkReachMaxM)) then
        touchBallWithBody(ch, ball)
        fireCatchRemote(ball)
        requestBall("Gk", function() setBallVelocity(ball, Vector3.new(0, 0, 0)) end)
    end
end

-- Keeper Rush: come off the line at an attacker inside the box.
local function keeperRushStep()
    if not S.KeeperRush then return end
    local own = select(1, getGoals())
    if not own then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    if (ball.Position - own).Magnitude > metresToStuds(S.RushM) then return end
    local carrier = ballCarrier()
    if carrier == LocalPlayer then return end
    glideSelfTo(ball.Position, S.DiveSpeed)
    local ch = myChar()
    touchBallWithBody(ch, ball)
end

local function panicReachStep()
    if not S.PanicReach then return end
    local ch, hum, root = myChar()
    if not root then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    local hands = (ch:FindFirstChild("RightHand") and ch.RightHand.Position) or root.Position
    if (ball.Position - hands).Magnitude > metresToStuds(S.PanicReachM) then return end
    touchBallWithBody(ch, ball)
    fireCatchRemote(ball)
    requestBall("PanicReach", function()
        setBallVelocity(ball, Vector3.new(0, 0, 0))
        setBallCFrame(ball, hands)
    end)
end

local DenyHook = { installed = false, old = nil }

local function installDenyHook()
    if DenyHook.installed then return true end
    if not (CAP.hook and HAS.deny) then
        noteOnce("deny", "deny hook needs CFG.DenyEventNames and an executor with hookmetamethod")
        return false
    end
    local ok = pcall(function()
        DenyHook.old = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if not checkcaller() and S.BlockDeny and (method == "FireServer" or method == "InvokeServer") then
                for _, n in ipairs(CFG.DenyEventNames) do
                    if self.Name == n then return nil end
                end
            end
            return DenyHook.old(self, ...)
        end)
    end)
    DenyHook.installed = ok
    return ok
end

----------------------------------------------------------------------
-- DEFENDING
----------------------------------------------------------------------

-- Auto Tackle: step into the carrier and touch the ball off him.
local function autoTackleStep()
    if not S.AutoTackle then return end
    local ch, hum, root = myChar()
    if not root then return end
    local carrier = ballCarrier()
    if not carrier or carrier == LocalPlayer or sameTeam(carrier) then return end
    local cch, chum, croot = alive(carrier)
    if not croot then return end
    local d = (croot.Position - root.Position).Magnitude
    if d > metresToStuds(math.min(S.TackleM, CFG.TackleMaxM)) then return end
    local ball = getBall()
    if not ball then return end
    local now = os.clock()
    if now - S.TackleLast < 0.25 then return end
    S.TackleLast = now

    if S.SelfMove and d > metresToStuds(1.5) then
        local stand = croot.Position - (croot.Position - root.Position).Unit * metresToStuds(1.2)
        moveSelfTo(stand, true)
    end
    touchBallWithBody(ch, ball)
    fireCatchRemote(ball)
    requestBall("Tackle", function() pullBall(ball, footPosition(ch) or root.Position, true, 0.9) end)
end

-- Auto Intercept: stand on the line of a pass that is crossing near you.
local function autoInterceptStep()
    if not S.AutoIntercept then return end
    local ch, hum, root = myChar()
    if not root then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    local vel = ball.AssemblyLinearVelocity
    if not isPlausibleVector(vel) or vel.Magnitude < 8 then return end
    local point, t = closestApproach(ball.Position, vel, root.Position)
    if not point then return end
    local reachable = metresToStuds(S.PositionM)
    if (point - root.Position).Magnitude > reachable then return end
    glideSelfTo(point, 120)
    touchBallWithBody(ch, ball)
end

-- Auto Position: hold a sensible spot relative to the ball instead of
-- standing still.
local function autoPositionStep()
    if not S.AutoPosition then return end
    local ch, hum, root = myChar()
    if not root or not hum then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    local carrier = ballCarrier()
    if carrier == LocalPlayer then return end
    local want = metresToStuds(S.PositionM)
    local delta = ball.Position - root.Position
    local flat = Vector3.new(delta.X, 0, delta.Z)
    if flat.Magnitude <= want then return end
    hum:Move(flat.Unit, false)
end

----------------------------------------------------------------------
-- MOVEMENT
----------------------------------------------------------------------

local function statsStep()
    local ch, hum = myChar()
    if not hum then return end
    if S.SpeedOn and math.abs(hum.WalkSpeed - S.SpeedValue) > 0.01 then
        hum.WalkSpeed = S.SpeedValue
    end
    if S.AutoSprint and not S.SpeedOn then
        local moving = hum.MoveDirection.Magnitude > 0.1
        local want = moving and S.SprintValue or 16
        if math.abs(hum.WalkSpeed - want) > 0.01 then hum.WalkSpeed = want end
    end
    if S.JumpOn then
        if hum.UseJumpPower then
            if math.abs(hum.JumpPower - S.JumpValue) > 0.01 then hum.JumpPower = S.JumpValue end
        else
            local h = S.JumpValue * 0.14
            if math.abs(hum.JumpHeight - h) > 0.01 then hum.JumpHeight = h end
        end
    end
    if S.AntiStun then
        for _, st in ipairs({
            Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll,
            Enum.HumanoidStateType.Physics, Enum.HumanoidStateType.Seated,
        }) do
            pcall(function() hum:SetStateEnabled(st, false) end)
        end
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.FallingDown or st == Enum.HumanoidStateType.Ragdoll then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
        if hum.PlatformStand then hum.PlatformStand = false end
    end
end

local function noclipStep()
    if not S.NoClip then return end
    local ch = myChar()
    if not ch then return end
    for _, p in ipairs(ch:GetDescendants()) do
        if p:IsA("BasePart") then
            if CollideSaved[p] == nil then CollideSaved[p] = p.CanCollide end
            if p.CanCollide then p.CanCollide = false end
        end
    end
end

local function noclipRestore()
    for p, was in pairs(CollideSaved) do
        pcall(function() if p.Parent then p.CanCollide = was end end)
        CollideSaved[p] = nil
    end
end

----------------------------------------------------------------------
-- SPECIAL
----------------------------------------------------------------------

local function phaseTargetPlayer()
    if S.PhaseMode == "Select" then
        local p = Players:FindFirstChild(S.PhaseTargetName)
        return (p and p ~= LocalPlayer) and p or nil
    end
    local best, bestAng = nil, 0.93
    local look = Camera.CFrame.LookVector
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local _, _, root = alive(plr)
            if root then
                local to = root.Position - Camera.CFrame.Position
                if to.Magnitude > 1e-3 then
                    local dot = look:Dot(to.Unit)
                    if dot > bestAng then best, bestAng = plr, dot end
                end
            end
        end
    end
    return best
end

local function phaseRestore()
    for part, was in pairs(PhaseSaved) do
        pcall(function() if part.Parent then part.CanCollide = was end end)
        PhaseSaved[part] = nil
    end
end

local function phaseStep()
    if not S.PhaseEnemy then
        if next(PhaseSaved) then phaseRestore() end
        return
    end
    local plr = phaseTargetPlayer()
    if not plr then
        if next(PhaseSaved) then phaseRestore() end
        return
    end
    local ch = alive(plr)
    if not ch then return end
    for _, p in ipairs(ch:GetDescendants()) do
        if p:IsA("BasePart") then
            if PhaseSaved[p] == nil then PhaseSaved[p] = p.CanCollide end
            if p.CanCollide then p.CanCollide = false end
        end
    end
end

local function antiPhaseStep()
    if not S.AntiPhase then return end
    local ch = myChar()
    if not ch then return end
    for _, p in ipairs(ch:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and not p.CanCollide then
            p.CanCollide = true
        end
    end
end

local function bringBall()
    local ch, hum, root = myChar()
    if not root then return end
    local ball = getBall()
    if not ball then return end
    local foot = footPosition(ch) or root.Position
    touchBallWithBody(ch, ball)
    requestBall("Bring", function()
        setBallVelocity(ball, Vector3.new(0, 0, 0))
        setBallCFrame(ball, foot + Vector3.new(0, 1, 0))
    end)
end

local function deleteBall()
    local ball = getBall()
    if not ball then return end
    pcall(function() ball:Destroy() end)
    BallCache.stamp = -1
    notify("Ball", "Removed on your client.", 3)
end

local function toggleFreeze()
    local ball = getBall()
    if not ball then return end
    S.BallFrozen = not S.BallFrozen
    pcall(function()
        ball.Anchored = S.BallFrozen
        if S.BallFrozen then ball.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
    end)
    notify("Ball", S.BallFrozen and "Frozen" or "Unfrozen", 2)
end

local function dunkStep()
    if not S.Dunk then return end
    local ch, hum, root = myChar()
    if not root then return end
    local _, enemy = getGoals()
    if not enemy then return end
    if (root.Position - enemy).Magnitude > metresToStuds(S.DunkRangeM) then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    local foot = footPosition(ch) or root.Position
    if (ball.Position - foot).Magnitude > reachTriggerStuds() * 2 then return end
    touchBallWithBody(ch, ball)
    requestBall("Dunk", function()
        setBallVelocity(ball, Vector3.new(0, 0, 0))
        setBallCFrame(ball, enemy)
    end)
end

local function goalFarmStep()
    if not S.GoalFarm then return end
    local _, enemy = getGoals()
    if not enemy then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    local ch = myChar()
    touchBallWithBody(ch, ball)
    requestBall("GoalFarm", function()
        setBallVelocity(ball, Vector3.new(0, 0, 0))
        setBallCFrame(ball, enemy)
    end)
end

local function saveFarmStep()
    if not S.SaveFarm then return end
    local own = select(1, getGoals())
    if not own then return end
    local ch, hum, root = myChar()
    if not root then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    local hands = (ch:FindFirstChild("RightHand") and ch.RightHand.Position) or root.Position
    local cycle = (math.floor(os.clock() * 2) % 2 == 0)
    requestBall("SaveFarm", function()
        setBallVelocity(ball, Vector3.new(0, 0, 0))
        setBallCFrame(ball, cycle and (own + Vector3.new(0, 2, 0)) or hands)
    end)
end

local function trickOmsStep()
    if not S.TrickOms then return end
    local ch, hum, root = myChar()
    if not root then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    local now = os.clock()
    local interval = 1 / math.clamp(S.TrickTempo, 0.3, 10)
    if now - S.TrickLast < interval then return end
    local foot = footPosition(ch) or root.Position
    if (ball.Position - foot).Magnitude > reachTriggerStuds() * 1.6 then return end
    local step = math.floor(now / interval) % 4
    local right, fwd = root.CFrame.RightVector, root.CFrame.LookVector
    local offsets = {
        right * 2.2 + Vector3.new(0, 1.0, 0),
        -right * 2.2 + Vector3.new(0, 1.0, 0),
        fwd * 2.4 + Vector3.new(0, 2.2, 0),
        Vector3.new(0, 3.0, 0),
    }
    local target = foot + offsets[step + 1]
    requestBall("Trick", function()
        if pullBall(ball, target, true, 0.9) then S.TrickLast = now end
    end)
end

local function ballTimeStep()
    if not S.BallTime then return end
    local mul = math.clamp(S.BallTimeMul, 0.1, 3)
    if math.abs(mul - 1) < 0.01 then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    local v = ball.AssemblyLinearVelocity
    if not isPlausibleVector(v) or v.Magnitude < 1 then return end
    requestBall("BallTime", function() setBallVelocity(ball, v * mul) end)
end

local function framePlayerStep()
    if not S.FramePlayer then return end
    local plr = Players:FindFirstChild(S.FrameTargetName)
    if not plr or plr == LocalPlayer then return end
    local ch, hum, root = alive(plr)
    if not root then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    requestBall("Frame", function() pullBall(ball, footPosition(ch) or root.Position, true, 0.9) end)
end

----------------------------------------------------------------------
-- SESSION / SERVERS
----------------------------------------------------------------------

local function doRejoin()
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
    if not ok then pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end) end
end

local function fetchServers()
    local ok, body = pcall(function() return game:HttpGet(string.format(CFG.ServerApi, game.PlaceId)) end)
    if not ok then return nil end
    local ok2, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not (ok2 and type(data) == "table" and type(data.data) == "table") then return nil end
    return data.data
end

local function pickServer(maxPing)
    local list = fetchServers()
    if not list then return nil end
    local best, bestPing = nil, math.huge
    for _, srv in ipairs(list) do
        local playing = tonumber(srv.playing) or 0
        local cap = tonumber(srv.maxPlayers) or 0
        local ping = tonumber(srv.ping) or 9999
        if type(srv.id) == "string" and srv.id ~= game.JobId and playing < cap then
            if ping <= (maxPing or 9999) and ping < bestPing then best, bestPing = srv.id, ping end
        end
    end
    return best, bestPing
end

local function hopServer(maxPing)
    if os.clock() - S.LastHop < 8 then return end
    S.LastHop = os.clock()
    local id, ping = pickServer(maxPing)
    if not id then
        notify("Hop", "No server under that ping.", 3)
        return
    end
    if CAP.queue then
        pcall(function() queue_on_teleport("-- re-execute your TouchFootball loader here") end)
    end
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, id, LocalPlayer) end)
end

local function autoBestServerStep()
    if not S.AutoBestServer then return end
    if os.clock() - S.LastHop < 45 then return end
    if readPing() <= S.HopMaxPing then return end
    hopServer(S.HopMaxPing)
end

local function isStaff(plr)
    for _, n in ipairs(CFG.StaffNames) do
        if string.lower(plr.Name) == string.lower(n) then return true end
    end
    if HAS.staff_group then
        local ok, rank = pcall(function() return plr:GetRankInGroup(CFG.StaffGroupId) end)
        if ok and type(rank) == "number" and rank >= CFG.StaffMinRank then return true end
    end
    return false
end

local function panicStaffStep()
    if not S.PanicStaff then return end
    if not (HAS.staff_group or #CFG.StaffNames > 0) then
        noteOnce("staff", "Panic Staff idle: set a staff group id or staff names in CONFIG")
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isStaff(plr) then
            pcall(function() LocalPlayer:Kick("left") end)
            return
        end
    end
end

local function antiAfkSetup()
    Conns[#Conns + 1] = LocalPlayer.Idled:Connect(function()
        if not S.AntiAfk then return end
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
        end)
    end)
end

local function autoQuestStep()
    if not S.AutoQuest then return end
    if not HAS.quest then
        noteOnce("quest", "Auto Quest idle: set the quest remote in CONFIG")
        return
    end
    local rem = ReplicatedStorage:FindFirstChild(CFG.QuestRemoteName, true)
    if not rem or os.clock() - S.LastQuest < 5 then return end
    S.LastQuest = os.clock()
    pcall(function()
        if rem:IsA("RemoteEvent") then rem:FireServer() else rem:InvokeServer() end
    end)
end

local function forceRespawn()
    if HAS.respawn then
        local rem = ReplicatedStorage:FindFirstChild(CFG.RespawnRemoteName, true)
        if rem then
            pcall(function()
                if rem:IsA("RemoteEvent") then rem:FireServer() else rem:InvokeServer() end
            end)
            return
        end
    end
    local _, hum = myChar()
    if hum then pcall(function() hum.Health = 0 end) end
end

local function panicEject()
    for _, k in ipairs({
        "ProReach", "ControlReach", "BallHold", "Sneaky", "Pokers", "AutoJuggle",
        "GroundShots", "SpinFlick", "Aimbot", "Aimlock", "CurveAimbot", "AutoNero",
        "AutoHeader", "AimPass", "AutoPassPressure", "AutoGk", "AutoGs", "KeeperRush",
        "PanicReach", "AutoTackle", "AutoIntercept", "AutoPosition", "PhaseEnemy",
        "GoalFarm", "SaveFarm", "Dunk", "TrickOms", "BallTime", "FramePlayer",
        "HitboxExtender", "NoClip", "SpeedOn", "JumpOn", "AutoSprint",
    }) do
        S[k] = false
    end
    destroyHitbox()
    noclipRestore()
    phaseRestore()
    local _, hum = myChar()
    if hum then
        pcall(function()
            hum.Sit = false
            hum.PlatformStand = false
            hum.WalkSpeed = 16
        end)
    end
    notify("Panic", "Everything off.", 3)
end

local function applyFpsBoost()
    if not S.FpsBoost then return end
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e6
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("BloomEffect")
                or e:IsA("DepthOfFieldEffect") or e:IsA("ColorCorrectionEffect") then
                e.Enabled = false
            end
        end
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") then
                if d.Name ~= "TF_TRAIL" then d.Enabled = false end
            elseif d:IsA("Explosion") then
                d.BlastPressure = 0
            end
        end
        if settings and settings() and settings().Rendering then
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end
    end)
end

----------------------------------------------------------------------
-- VISUALS
----------------------------------------------------------------------

local VisGui = nil

local function ensureVisGui()
    if VisGui and VisGui.Parent then return VisGui end
    local sg = Instance.new("ScreenGui")
    sg.Name = "TF_VIS"
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    local parent = (CAP.hui and gethui()) or game:GetService("CoreGui")
    local ok = pcall(function() sg.Parent = parent end)
    if not ok then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    VisGui = sg
    return sg
end

local function newLabel()
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamBold
    l.TextSize = 14
    l.TextStrokeTransparency = 0.2
    l.TextColor3 = Color3.fromRGB(255, 255, 255)
    l.Size = UDim2.fromOffset(240, 18)
    l.AnchorPoint = Vector2.new(0.5, 0.5)
    l.Visible = false
    l.Parent = ensureVisGui()
    return l
end

local function poolLabel(key)
    local l = EspPool[key]
    if l and l.Parent then return l end
    l = newLabel()
    EspPool[key] = l
    return l
end

local function ballEspStep()
    local l = poolLabel("ball")
    if not S.BallEsp then l.Visible = false return end
    local ball, tier = getBall()
    if not ball then l.Visible = false return end
    local scr, on = worldToScreen(ball.Position)
    if not (scr and on) then l.Visible = false return end
    local _, _, root = myChar()
    local d = root and (ball.Position - root.Position).Magnitude or 0
    l.Text = ("● BALL  %.1fm"):format(studsToMetres(d))
    l.TextColor3 = CFG.Accent
    l.Position = UDim2.fromOffset(scr.X, scr.Y)
    l.Visible = true
end

local function playerEspStep()
    if not S.PlayerEsp then
        for key, l in pairs(EspPool) do
            if key ~= "ball" and key ~= "pred" then l.Visible = false end
        end
        return
    end
    local _, _, myRoot = myChar()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local l = poolLabel("p_" .. plr.Name)
            local ch, hum, root = alive(plr)
            if root then
                local head = (ch:FindFirstChild("Head") or root).Position + Vector3.new(0, 2.2, 0)
                local scr, on = worldToScreen(head)
                if scr and on then
                    local d = myRoot and (root.Position - myRoot.Position).Magnitude or 0
                    l.Text = ("%s  %.0fm"):format(plr.Name, studsToMetres(d))
                    l.TextColor3 = sameTeam(plr) and Color3.fromRGB(110, 230, 150) or Color3.fromRGB(255, 110, 110)
                    l.Position = UDim2.fromOffset(scr.X, scr.Y)
                    l.Visible = true
                else
                    l.Visible = false
                end
            else
                l.Visible = false
            end
        end
    end
end

local function predictLineStep()
    local l = poolLabel("pred")
    if not S.PredictLine then l.Visible = false return end
    local ball = getBall()
    if not ball then l.Visible = false return end
    local land = leadPosition(ball.Position, ball.AssemblyLinearVelocity, 0.8, S.LastGravity)
    if not land then l.Visible = false return end
    local scr, on = worldToScreen(land)
    if not (scr and on) then l.Visible = false return end
    l.Text = "✕ landing"
    l.TextColor3 = CFG.Accent2
    l.Position = UDim2.fromOffset(scr.X, scr.Y)
    l.Visible = true
end

local function attachTrail(part, c0, c1, life)
    if not part or Trails[part] then return end
    local a0 = Instance.new("Attachment")
    a0.Position = Vector3.new(0, part.Size.Y * 0.25, 0)
    a0.Parent = part
    local a1 = Instance.new("Attachment")
    a1.Position = Vector3.new(0, -part.Size.Y * 0.25, 0)
    a1.Parent = part
    local tr = Instance.new("Trail")
    tr.Name = "TF_TRAIL"
    tr.Attachment0, tr.Attachment1 = a0, a1
    tr.Lifetime = life or 0.6
    tr.LightEmission = 1
    tr.Color = ColorSequence.new(c0, c1)
    tr.Parent = part
    Trails[part] = { trail = tr, a0 = a0, a1 = a1 }
end

local function detachTrail(part)
    local t = Trails[part]
    if not t then return end
    pcall(function() t.trail:Destroy() t.a0:Destroy() t.a1:Destroy() end)
    Trails[part] = nil
end

local function detachAllTrails()
    for part in pairs(Trails) do detachTrail(part) end
end

local function rainbow(t) return Color3.fromHSV((t * 0.25) % 1, 1, 1) end

local function ballTrailStep()
    local ball = getBall()
    if not S.BallTrail then
        if ball then detachTrail(ball) end
        return
    end
    if ball then attachTrail(ball, CFG.Accent, CFG.Accent2, 0.8) end
end

local function rgbCharStep()
    local ch = myChar()
    if not ch then return end
    if not S.RgbChar then
        if S.RgbWasOn then
            for _, p in ipairs(ch:GetDescendants()) do
                if p:IsA("BasePart") then pcall(function() p.Material = Enum.Material.Plastic end) end
            end
            S.RgbWasOn = false
        end
        return
    end
    S.RgbWasOn = true
    local c = rainbow(os.clock())
    for _, p in ipairs(ch:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Name ~= "TF_Reach" then
            pcall(function()
                p.Material = Enum.Material.Neon
                p.Color = c
            end)
        end
    end
end

local function bootTrailStep()
    local ch = myChar()
    if not ch then return end
    for _, name in ipairs({ "RightFoot", "LeftFoot", "Right Leg", "Left Leg" }) do
        local f = ch:FindFirstChild(name)
        if f then
            if S.BootTrail then
                attachTrail(f, rainbow(os.clock()), rainbow(os.clock() + 0.5), 1.0)
                local t = Trails[f]
                if t then t.trail.Color = ColorSequence.new(rainbow(os.clock()), rainbow(os.clock() + 0.4)) end
            else
                detachTrail(f)
            end
        end
    end
end

local function timeOfDayStep()
    if not S.TimeOfDay then return end
    if math.abs(Lighting.ClockTime - S.TimeValue) > 0.01 then Lighting.ClockTime = S.TimeValue end
end

local function spoofMarkerStep()
    if not S.SpoofMarker then
        for lbl, txt in pairs(MarkerSaved) do
            pcall(function() if lbl.Parent then lbl.Text = txt end end)
            MarkerSaved[lbl] = nil
        end
        return
    end
    if not HAS.marker then
        noteOnce("marker", "Spoof Marker idle: set the marker GUI path in CONFIG")
        return
    end
    local holder = LocalPlayer:FindFirstChild("PlayerGui")
    for seg in string.gmatch(CFG.MarkerGuiPath, "[^%.]+") do
        holder = holder and holder:FindFirstChild(seg)
    end
    if not holder then return end
    for _, lbl in ipairs(holder:GetDescendants()) do
        if lbl:IsA("TextLabel") then
            if MarkerSaved[lbl] == nil then MarkerSaved[lbl] = lbl.Text end
            local low = string.lower(lbl.Name .. " " .. MarkerSaved[lbl])
            if string.find(low, "ping", 1, true) then lbl.Text = ("%d ms"):format(S.SpoofPing)
            elseif string.find(low, "cpu", 1, true) then lbl.Text = ("%d%%"):format(S.SpoofCpu)
            elseif string.find(low, "sent", 1, true) then lbl.Text = ("%d kb/s"):format(S.SpoofSent) end
        end
    end
end

----------------------------------------------------------------------
-- MOBILE HUD
-- Rounded glass panel, gradient header, live status row, chip grid. Sized
-- off the viewport so it reads the same on a phone as on a desktop.
----------------------------------------------------------------------

local HUD = { gui = nil, panel = nil, chips = {}, status = nil, body = nil, toggle = nil }

local CHIPS = {
    { label = "REACH", key = "ProReach" },
    { label = "HOLD", key = "BallHold" },
    { label = "AIM", key = "Aimbot" },
    { label = "PASS", key = "AimPass" },
    { label = "GK", key = "AutoGk" },
    { label = "TACKLE", key = "AutoTackle" },
    { label = "JUGGLE", key = "AutoJuggle" },
    { label = "SNEAKY", key = "Sneaky" },
    { label = "DUNK", key = "Dunk" },
    { label = "PHASE", key = "PhaseEnemy" },
    { label = "HITBOX", key = "HitboxExtender" },
    { label = "ESP", key = "BallEsp" },
}

local function destroyHud()
    if HUD.gui then pcall(function() HUD.gui:Destroy() end) end
    HUD.gui, HUD.panel, HUD.status, HUD.body, HUD.toggle = nil, nil, nil, nil, nil
    HUD.chips = {}
end

local function hudScale()
    local vp = Camera.ViewportSize
    local phone = math.min(vp.X, vp.Y) < 600
    local base = (S.HudScale / 100) * (phone and 1.15 or 1.0)
    return math.clamp(base, 0.6, 2.0)
end

local function buildHud()
    destroyHud()
    if not S.Hud then return end

    local sc = hudScale()
    local chipW = math.floor(132 * sc)
    local chipH = math.floor(42 * sc)
    local cols = math.clamp(S.ButtonColumns, 1, 3)
    local pad = math.floor(8 * sc)
    local rows = math.ceil(#CHIPS / cols)
    local bodyH = rows * (chipH + pad) + pad
    local width = cols * (chipW + pad) + pad

    local sg = Instance.new("ScreenGui")
    sg.Name = "TF_HUD"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 999
    local parent = (CAP.hui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")
    local ok = pcall(function() sg.Parent = parent end)
    if not ok then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.fromOffset(width, math.floor(86 * sc) + bodyH)
    panel.Position = UDim2.new(0, 14, 0.18, 0)
    panel.BackgroundColor3 = CFG.Panel
    panel.BackgroundTransparency = 0.12
    panel.BorderSizePixel = 0
    panel.Active = true
    panel.Draggable = true
    panel.Parent = sg
    local pc = Instance.new("UICorner")
    pc.CornerRadius = UDim.new(0, math.floor(18 * sc))
    pc.Parent = panel
    local stroke = Instance.new("UIStroke")
    stroke.Color = CFG.Accent
    stroke.Transparency = 0.55
    stroke.Thickness = 1.5
    stroke.Parent = panel

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, math.floor(46 * sc))
    header.BackgroundColor3 = Color3.fromRGB(26, 28, 36)
    header.BorderSizePixel = 0
    header.Parent = panel
    local hc = Instance.new("UICorner")
    hc.CornerRadius = UDim.new(0, math.floor(18 * sc))
    hc.Parent = header
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new(CFG.Accent, CFG.Accent2)
    grad.Rotation = 20
    grad.Transparency = NumberSequence.new(0.78)
    grad.Parent = header

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -math.floor(60 * sc), 1, 0)
    title.Position = UDim2.fromOffset(math.floor(14 * sc), 0)
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextSize = math.floor(17 * sc)
    title.TextColor3 = Color3.fromRGB(240, 245, 255)
    title.Text = "TOUCH FOOTBALL " .. VERSION
    title.Parent = header

    local collapse = Instance.new("TextButton")
    collapse.Size = UDim2.fromOffset(math.floor(34 * sc), math.floor(34 * sc))
    collapse.Position = UDim2.new(1, -math.floor(40 * sc), 0, math.floor(6 * sc))
    collapse.BackgroundColor3 = Color3.fromRGB(40, 44, 54)
    collapse.BorderSizePixel = 0
    collapse.Font = Enum.Font.GothamBold
    collapse.TextSize = math.floor(18 * sc)
    collapse.TextColor3 = CFG.Accent
    collapse.Text = S.HudCollapsed and "+" or "–"
    collapse.Parent = header
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(1, 0)
    cc.Parent = collapse

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.BackgroundTransparency = 1
    status.Size = UDim2.new(1, -math.floor(20 * sc), 0, math.floor(32 * sc))
    status.Position = UDim2.fromOffset(math.floor(14 * sc), math.floor(48 * sc))
    status.Font = Enum.Font.Code
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextSize = math.floor(12 * sc)
    status.TextColor3 = Color3.fromRGB(170, 180, 200)
    status.Text = "booting"
    status.Parent = panel

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.BackgroundTransparency = 1
    body.Position = UDim2.fromOffset(pad, math.floor(84 * sc))
    body.Size = UDim2.new(1, -pad * 2, 0, bodyH)
    body.Visible = not S.HudCollapsed
    body.Parent = panel

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.fromOffset(chipW, chipH)
    grid.CellPadding = UDim2.fromOffset(pad, pad)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = body

    for i, chip in ipairs(CHIPS) do
        local b = Instance.new("TextButton")
        b.Name = chip.key
        b.LayoutOrder = i
        b.BackgroundColor3 = Color3.fromRGB(32, 35, 44)
        b.BorderSizePixel = 0
        b.AutoButtonColor = true
        b.Font = Enum.Font.GothamBold
        b.TextSize = math.floor(13 * sc)
        b.TextColor3 = Color3.fromRGB(205, 212, 228)
        b.Text = chip.label
        b.Parent = body
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, math.floor(S.ButtonShape == "Circle" and chipH / 2 or (S.ButtonShape == "Square" and 2 or 12) * sc))
        bc.Parent = b
        local bs = Instance.new("UIStroke")
        bs.Color = CFG.Accent
        bs.Transparency = 0.8
        bs.Thickness = 1
        bs.Parent = b
        b.MouseButton1Click:Connect(function()
            S[chip.key] = not S[chip.key]
            if chip.key == "HitboxExtender" and not S[chip.key] then destroyHitbox() end
            if chip.key == "PhaseEnemy" and not S[chip.key] then phaseRestore() end
        end)
        HUD.chips[chip.key] = { btn = b, stroke = bs }
    end

    collapse.MouseButton1Click:Connect(function()
        S.HudCollapsed = not S.HudCollapsed
        body.Visible = not S.HudCollapsed
        collapse.Text = S.HudCollapsed and "+" or "–"
        panel.Size = S.HudCollapsed and UDim2.fromOffset(width, math.floor(86 * sc))
            or UDim2.fromOffset(width, math.floor(86 * sc) + bodyH)
    end)

    HUD.gui, HUD.panel, HUD.status, HUD.body, HUD.toggle = sg, panel, status, body, collapse
end

local function hudRefresh()
    if not (S.Hud and HUD.status and HUD.status.Parent) then return end
    for key, c in pairs(HUD.chips) do
        local on = S[key] and true or false
        c.btn.BackgroundColor3 = on and Color3.fromRGB(0, 92, 70) or Color3.fromRGB(32, 35, 44)
        c.btn.TextColor3 = on and CFG.Accent or Color3.fromRGB(205, 212, 228)
        c.stroke.Transparency = on and 0.1 or 0.8
    end
    local ballMark = (S.BallTier == "unknown") and "none" or S.BallTier
    HUD.status.Text = ("ball %s · goal %s · %d ms · %d fps\ntouch %s · own %s · reach %.1fm"):format(
        ballMark, S.GoalTier, math.floor(S.Ping), math.floor(S.Fps),
        CAP.touch and "on" or "off",
        (CAP.simrad or CAP.hidden) and "on" or "off",
        reachMetres())
end

----------------------------------------------------------------------
-- KEYBINDS
----------------------------------------------------------------------

local function toggleKey(key, label)
    S[key] = not S[key]
    if key == "HitboxExtender" and not S[key] then destroyHitbox() end
    if key == "PhaseEnemy" and not S[key] then phaseRestore() end
    notify(label, S[key] and "on" or "off", 2)
end

local BIND_ACTIONS = {
    Reach = function() toggleKey("ProReach", "Reach") end,
    Sneaky = function() toggleKey("Sneaky", "Sneaky") end,
    Aimbot = function() toggleKey("Aimbot", "Aimbot") end,
    AimPass = function() doPass() end,
    AutoGk = function() toggleKey("AutoGk", "Auto GK") end,
    Phase = function() toggleKey("PhaseEnemy", "Phase") end,
    Juggle = function() toggleKey("AutoJuggle", "Juggle") end,
    Tackle = function() toggleKey("AutoTackle", "Tackle") end,
    Nero = function() fireNero() end,
    Dunk = function() toggleKey("Dunk", "Dunk") end,
    BringBall = function() bringBall() end,
    Freeze = function() toggleFreeze() end,
    PanicEject = function() panicEject() end,
    LearnBall = function() learnBall() end,
    HudToggle = function()
        S.Hud = not S.Hud
        buildHud()
    end,
}

local BIND_ORDER = {
    "Reach", "Sneaky", "Aimbot", "AimPass", "AutoGk", "Phase", "Juggle", "Tackle",
    "Nero", "Dunk", "BringBall", "Freeze", "PanicEject", "LearnBall", "HudToggle",
}

local function bindLabel(name)
    local b = KEYS[name]
    if not b then return "unbound" end
    local kb = (b.kb and b.kb ~= Enum.KeyCode.Unknown) and b.kb.Name or "-"
    local pad = (b.pad and b.pad ~= Enum.KeyCode.Unknown) and b.pad.Name or "-"
    return ("%s / %s"):format(kb, pad)
end

local function isGamepadKey(code)
    local n = code.Name
    return string.sub(n, 1, 6) == "Button" or string.sub(n, 1, 4) == "DPad" or string.sub(n, 1, 5) == "Thumb"
end

local function handleBindInput(code)
    if S.Binding then
        local slot = S.Binding
        S.Binding = nil
        if isGamepadKey(code) then KEYS[slot].pad = code else KEYS[slot].kb = code end
        notify("Keybinds", ("%s = %s"):format(slot, bindLabel(slot)), 3)
        return true
    end
    for name, b in pairs(KEYS) do
        if code == b.kb or code == b.pad then
            local fn = BIND_ACTIONS[name]
            if fn then fn() end
            return true
        end
    end
    return false
end

----------------------------------------------------------------------
-- DIAGNOSTICS
----------------------------------------------------------------------

local function emit(lines, title)
    local out = table.concat(lines, "\n")
    print(out)
    if CAP.clip then pcall(function() setclipboard(out) end) end
    notify("Discovery", title, 4)
    return out
end

local function dumpRemotes()
    local lines = { "=== TF REMOTES ===" }
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
    return emit(lines, "Remotes copied.")
end

local function dumpBallCandidates()
    local lines = { "=== TF BALL CANDIDATES ===" }
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("BasePart") and nameLooksLikeBall(inst.Name) then
            lines[#lines + 1] = ("%s | size=%s | anchored=%s | %s"):format(
                inst.Name, tostring(inst.Size), tostring(inst.Anchored), inst:GetFullName())
        end
    end
    local loose = findLoose(searchRoot())
    if loose then lines[#lines + 1] = ("loose %s | %s"):format(loose.Name, loose:GetFullName()) end
    return emit(lines, "Ball candidates copied.")
end

local function dumpGoalCandidates()
    local lines = { "=== TF GOAL CANDIDATES ===" }
    for _, p in ipairs(goalCandidates()) do
        lines[#lines + 1] = ("%s | %s | %s"):format(p.Name, tostring(p.Position), p:GetFullName())
    end
    local own, enemy, tier = getGoals()
    lines[#lines + 1] = ("own=%s enemy=%s tier=%s"):format(tostring(own), tostring(enemy), tier)
    return emit(lines, "Goal candidates copied.")
end

local function dumpPlayerGui()
    local lines = { "=== TF PLAYERGUI ===" }
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, inst in ipairs(pg:GetDescendants()) do
            if inst:IsA("TextLabel") or inst:IsA("ScreenGui") or inst:IsA("Frame") then
                lines[#lines + 1] = ("%s | %s"):format(inst.ClassName, inst:GetFullName())
            end
        end
    end
    return emit(lines, "PlayerGui copied.")
end

local function probeOwnership()
    local ball = getBall()
    if not ball then
        S.Ownership = nil
        return nil
    end
    pushSimulationRadius()
    local before = ball.Position
    if not isPlausibleVector(before) then return nil end
    local wanted = before + Vector3.new(0, 0.35, 0)
    local ok = pcall(function() ball.CFrame = CFrame.new(wanted) end)
    if not ok then S.Ownership = false return false end
    task.wait(0.12)
    local after = ball.Position
    local held = isPlausibleVector(after) and (after - wanted).Magnitude < 0.9
    pcall(function()
        if (ball.Position - wanted).Magnitude < 2 then ball.CFrame = CFrame.new(before) end
    end)
    S.Ownership = held and true or false
    return S.Ownership
end

local function diagnostics()
    local ball, bTier = getBall()
    local own, enemy, gTier = getGoals()
    readPing()
    local lines = {
        ("=== TF %s DIAGNOSTICS ==="):format(VERSION),
        ("channels: ownership=%s touch=%s selfmove=%s"):format(
            tostring(S.TakeOwnership and (CAP.simrad or CAP.hidden)),
            tostring(S.UseTouch and CAP.touch), tostring(S.SelfMove)),
        ("executor: firetouchinterest=%s sethiddenproperty=%s setsimulationradius=%s hook=%s files=%s"):format(
            tostring(CAP.touch), tostring(CAP.hidden), tostring(CAP.simrad), tostring(CAP.hook), tostring(CAP.files)),
        ("counters: touches=%d ball writes=%d self moves=%d"):format(S.Touches, S.Writes, S.SelfMoves),
        ("ball: %s tier=%s"):format(ball and ball:GetFullName() or "none", bTier),
        ("goals: own=%s enemy=%s tier=%s"):format(tostring(own), tostring(enemy), gTier),
        ("ownership probe: %s"):format(S.Ownership == nil and "not run" or tostring(S.Ownership)),
        ("ping %.0f ms, reach %.2f m (%.1f studs), trigger %.1f studs"):format(
            S.Ping, reachMetres(), reachStuds(), reachTriggerStuds()),
        ("config set: catch=%s shoot=%s quest=%s respawn=%s marker=%s staff=%s deny=%d"):format(
            tostring(HAS.catch), tostring(HAS.shoot), tostring(HAS.quest), tostring(HAS.respawn),
            tostring(HAS.marker), tostring(HAS.staff_group), #CFG.DenyEventNames),
        "-- errors --",
    }
    local any = false
    for name, e in pairs(S.Err) do
        any = true
        lines[#lines + 1] = ("%s: %d | %s"):format(name, e.n, e.last)
    end
    if not any then lines[#lines + 1] = "none" end
    return emit(lines, "Diagnostics copied.")
end

----------------------------------------------------------------------
-- MAIN LOOP
----------------------------------------------------------------------

local SlowLast, FpsAcc, FpsN = 0, 0, 0

local function frame(dt)
    S.FrameId = S.FrameId + 1
    Camera = Workspace.CurrentCamera or Camera
    local okG, g = pcall(function() return Workspace.Gravity end)
    if okG and isFiniteNumber(g) and g > 0 then S.LastGravity = g end

    FpsAcc = FpsAcc + dt
    FpsN = FpsN + 1
    if FpsAcc >= 0.5 then
        S.Fps = FpsN / FpsAcc
        FpsAcc, FpsN = 0, 0
    end

    guard("ownership", pushSimulationRadius)
    guard("hitbox", ensureHitbox)

    guard("panic_reach", panicReachStep)
    guard("goal_farm", goalFarmStep)
    guard("save_farm", saveFarmStep)
    guard("dunk", dunkStep)
    guard("gk", autoGkStep)
    guard("keeper_rush", keeperRushStep)
    guard("tackle", autoTackleStep)
    guard("intercept", autoInterceptStep)
    guard("aimbot", aimbotStep)
    guard("ground_shot", groundShotStep)
    guard("nero", autoNeroStep)
    guard("header", autoHeaderStep)
    guard("aimpass", aimPassStep)
    guard("pressure_pass", pressurePassStep)
    guard("flick", spinFlickStep)
    guard("poke", pokersStep)
    guard("sneaky", sneakyStep)
    guard("trick", trickOmsStep)
    guard("hold", ballHoldStep)
    guard("reach", reachStep)
    guard("juggle", juggleStep)
    guard("frame_player", framePlayerStep)
    guard("ball_time", ballTimeStep)
    flushBall()

    guard("position", autoPositionStep)
    guard("stats", statsStep)
    guard("noclip", noclipStep)
    guard("aimlock", function() aimlockStep(dt) end)
    guard("phase", phaseStep)
    guard("anti_phase", antiPhaseStep)
    guard("ball_esp", ballEspStep)
    guard("predict", predictLineStep)
    guard("ball_trail", ballTrailStep)
    guard("rgb", rgbCharStep)
    guard("boot_trail", bootTrailStep)
    guard("tod", timeOfDayStep)

    local now = os.clock()
    if now - SlowLast > 0.4 then
        SlowLast = now
        guard("ping", readPing)
        guard("player_esp", playerEspStep)
        guard("hud", hudRefresh)
        guard("panic_staff", panicStaffStep)
        guard("auto_quest", autoQuestStep)
        guard("auto_server", autoBestServerStep)
        guard("spoof_marker", spoofMarkerStep)
    end
end

Conns[#Conns + 1] = RunService.RenderStepped:Connect(frame)

Conns[#Conns + 1] = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe and not S.Binding then return end
    if input.KeyCode == Enum.KeyCode.Unknown then return end
    if UserInputService:GetFocusedTextBox() then return end
    if S.ShotCharge and input.KeyCode == KEYS.Aimbot.kb then S.ChargeStart = os.clock() end
    handleBindInput(input.KeyCode)
end)

Conns[#Conns + 1] = UserInputService.InputEnded:Connect(function(input)
    if S.ShotCharge and input.KeyCode == KEYS.Aimbot.kb then
        if S.ChargeStart > 0 then takeShot("Shot", S.ShotPower) end
        S.ChargeStart = 0
    end
end)

Conns[#Conns + 1] = UserInputService.JumpRequest:Connect(function()
    if not S.InfJump then return end
    local _, hum = myChar()
    if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
end)

Conns[#Conns + 1] = LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.8)
    CollideSaved = {}
    BallCache.stamp, GoalCache.stamp = -1, -1
    S.RgbWasOn = false
    destroyHitbox()
end)

Conns[#Conns + 1] = Players.PlayerRemoving:Connect(function(plr)
    local l = EspPool["p_" .. plr.Name]
    if l then
        pcall(function() l:Destroy() end)
        EspPool["p_" .. plr.Name] = nil
    end
end)

antiAfkSetup()
relaxPhysics()
loadLearned()

local function teardown()
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    Conns = {}
    destroyHitbox()
    destroyHud()
    noclipRestore()
    phaseRestore()
    detachAllTrails()
    for _, l in pairs(EspPool) do pcall(function() l:Destroy() end) end
    EspPool = {}
    for lbl, txt in pairs(MarkerSaved) do
        pcall(function() if lbl.Parent then lbl.Text = txt end end)
        MarkerSaved[lbl] = nil
    end
    local ch, hum = myChar()
    if ch then
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") then pcall(function() p.Material = Enum.Material.Plastic end) end
        end
    end
    if hum then pcall(function() hum.WalkSpeed = 16 end) end
    if VisGui then pcall(function() VisGui:Destroy() end) VisGui = nil end
    print(("[TF %s] unloaded."):format(VERSION))
end

buildHud()

----------------------------------------------------------------------
-- RAYFIELD UI
----------------------------------------------------------------------

local okFetch, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not okFetch or type(Rayfield) ~= "table" then
    print(("[TF %s] Rayfield unavailable; HUD and features are live."):format(VERSION))
    getgenv().TF = { S = S, CFG = CFG, KEYS = KEYS, teardown = teardown, diag = diagnostics,
        learnBall = learnBall, learnGoal = learnGoal, probe = probeOwnership, hop = hopServer }
    return
end

local Window = Rayfield:CreateWindow({
    Name = ("Touch Football %s"):format(VERSION),
    Icon = 0,
    LoadingTitle = "Touch Football",
    LoadingSubtitle = VERSION .. " · olliE",
    Theme = "Amethyst",
    ConfigurationSaving = { Enabled = true, FolderName = "TouchFootball", FileName = "tf_v4" },
    Discord = { Enabled = false, Invite = "", RememberJoins = false },
    KeySystem = false,
})

local function build(tab, spec)
    for _, e in ipairs(spec) do
        if e.kind == "p" then
            tab:CreateParagraph({ Title = e.title, Content = e.text })
        elseif e.kind == "t" then
            tab:CreateToggle({
                Name = e.name, CurrentValue = S[e.key] and true or false, Flag = e.flag or e.key,
                Callback = function(v)
                    S[e.key] = v
                    if e.after then e.after(v) end
                end,
            })
        elseif e.kind == "s" then
            tab:CreateSlider({
                Name = e.name, Range = e.range, Increment = e.step, Suffix = e.suffix or "",
                CurrentValue = e.current, Flag = e.flag or e.key,
                Callback = function(v)
                    S[e.key] = e.scale and (v * e.scale) or v
                    if e.after then e.after(v) end
                end,
            })
        elseif e.kind == "d" then
            tab:CreateDropdown({
                Name = e.name, Options = e.options, CurrentOption = { e.current },
                MultipleOptions = false, Flag = e.flag or e.key,
                Callback = function(opt)
                    S[e.key] = (type(opt) == "table") and opt[1] or opt
                    if e.after then e.after(S[e.key]) end
                end,
            })
        elseif e.kind == "b" then
            tab:CreateButton({ Name = e.name, Callback = e.run })
        elseif e.kind == "i" then
            tab:CreateInput({
                Name = e.name, CurrentValue = e.current or "", PlaceholderText = e.hint or "",
                RemoveTextAfterFocusLost = e.clear and true or false, Flag = e.flag, Callback = e.run,
            })
        end
    end
end

local TabMain = Window:CreateTab("MAIN", 0)
build(TabMain, {
    { kind = "t", name = "Take ball ownership (simulation radius)", key = "TakeOwnership" },
    { kind = "t", name = "Fire touch events", key = "UseTouch" },
    { kind = "s", name = "Touch rate", key = "TouchHz", range = { 2, 60 }, step = 1, suffix = " /s", current = 20 },
    { kind = "t", name = "Self movement assists", key = "SelfMove" },
    { kind = "b", name = "Run channel test", run = function()
        pushSimulationRadius()
        local ball = getBall()
        local ch = myChar()
        local touched = (ball and ch) and touchBallWithBody(ch, ball) or false
        local owned = probeOwnership()
        local moved = false
        local _, _, root = myChar()
        if root then
            local p = root.Position
            moved = moveSelfTo(p + Vector3.new(0, 0.2, 0), false)
            moveSelfTo(p, false)
        end
        local msg = ("touch=%s own=%s selfmove=%s ball=%s"):format(
            tostring(touched), tostring(owned), tostring(moved), ball and ball.Name or "none")
        print("[TF] channel test: " .. msg)
        notify("Channel test", msg, 8)
    end },
    { kind = "b", name = "Learn ball (stand on it)", run = function() learnBall() end },
    { kind = "b", name = "Learn their goal (stand in it)", run = function() learnGoal("enemy") end },
    { kind = "b", name = "Learn your goal (stand in it)", run = function() learnGoal("own") end },
    { kind = "b", name = "Diagnostics", run = function() diagnostics() end },
    { kind = "b", name = "Panic Eject", run = panicEject },
})

local TabReach = Window:CreateTab("REACH", 0)
build(TabReach, {
    { kind = "t", name = "Pro Reach (Natural)", key = "ProReach" },
    { kind = "t", name = "Control Reach (Easier)", key = "ControlReach" },
    { kind = "s", name = "Reach", key = "ReachM", range = { 0.5, CFG.ReachMaxM }, step = 0.25, suffix = " m", current = 4.0 },
    { kind = "s", name = "Control Reach radius", key = "ControlReachM", range = { 0.5, CFG.ReachMaxM }, step = 0.25, suffix = " m", current = 7.0 },
    { kind = "s", name = "Pull power", key = "ReachPower", range = { 5, 100 }, step = 5, suffix = " %", current = 60, scale = 0.01 },
    { kind = "t", name = "Step to the ball (self move)", key = "SnapSelf" },
    { kind = "t", name = "Hitbox Extender (welded reach ball)", key = "HitboxExtender",
      after = function(v) if not v then destroyHitbox() end end },
    { kind = "s", name = "Hitbox size", key = "HitboxM", range = { 0.5, CFG.ReachMaxM }, step = 0.25, suffix = " m", current = 3.0 },
    { kind = "d", name = "Reach Priority", key = "ReachPriority",
      options = { "Reach", "Hold", "Gk", "Shot", "Pass", "Tackle", "Juggle", "Poke", "Sneaky" }, current = "Reach" },
    { kind = "t", name = "Ball Hold", key = "BallHold" },
    { kind = "s", name = "Hold offset ahead", key = "HoldOffsetM", range = { 0.2, 3 }, step = 0.1, suffix = " m", current = 1.0 },
    { kind = "t", name = "Adapt High MS", key = "AdaptHighMs" },
    { kind = "s", name = "Reach per ms over 80", key = "AdaptPerMs", range = { 0, 40 }, step = 1, suffix = " mm", current = 12, scale = 0.001 },
    { kind = "s", name = "Trigger per ms over 80", key = "AdaptTriggerPerMs", range = { 0, 60 }, step = 1, suffix = " mm", current = 20, scale = 0.001 },
})

local TabSkills = Window:CreateTab("SKILLS", 0)
build(TabSkills, {
    { kind = "t", name = "Sneaky", key = "Sneaky" },
    { kind = "t", name = "Sneaky: Air Only", key = "SneakyAirOnly" },
    { kind = "t", name = "Sneaky: Auto Adapt", key = "SneakyAutoAdapt" },
    { kind = "s", name = "Sneaky power", key = "SneakyPower", range = { 10, 160 }, step = 5, suffix = "", current = 55 },
    { kind = "s", name = "Sneaky range", key = "SneakyRangeM", range = { 1, 8 }, step = 0.25, suffix = " m", current = 4.0 },
    { kind = "t", name = "Pokers", key = "Pokers" },
    { kind = "s", name = "Poke speed", key = "PokeSpeed", range = { 0.2, 10 }, step = 0.2, suffix = " /s", current = 2.5 },
    { kind = "s", name = "Poke range", key = "PokeRangeM", range = { 0.5, CFG.PokeMaxM }, step = 0.25, suffix = " m", current = 3.0 },
    { kind = "t", name = "Auto Juggle", key = "AutoJuggle" },
    { kind = "s", name = "Juggle reach", key = "JuggleReachM", range = { 0.5, 8 }, step = 0.25, suffix = " m", current = 2.5 },
    { kind = "s", name = "Juggle height", key = "JuggleHeightM", range = { 0.3, 8 }, step = 0.1, suffix = " m", current = 2.0 },
    { kind = "t", name = "Juggle sticky", key = "JuggleSticky" },
    { kind = "t", name = "Ground Shots", key = "GroundShots" },
    { kind = "s", name = "Ground shot power", key = "GroundShotPower", range = { 40, 600 }, step = 10, suffix = "", current = 140 },
    { kind = "t", name = "Spin Flick", key = "SpinFlick" },
    { kind = "s", name = "Flick power", key = "FlickPower", range = { 30, 300 }, step = 10, suffix = "", current = 90 },
})

local TabAim = Window:CreateTab("AIMBOT", 0)
build(TabAim, {
    { kind = "t", name = "Aimbot", key = "Aimbot" },
    { kind = "t", name = "Aimlock (camera to ball)", key = "Aimlock" },
    { kind = "t", name = "Curve Aimbot", key = "CurveAimbot" },
    { kind = "t", name = "Auto Adapt Curve", key = "AutoAdaptCurve" },
    { kind = "t", name = "Random Curve", key = "RandomCurve" },
    { kind = "t", name = "Top Corner Mode", key = "TopCorner" },
    { kind = "t", name = "Auto Detect Goal", key = "AutoDetectGoal", after = function() GoalCache.stamp = -1 end },
    { kind = "t", name = "Shot Charge (hold the aim key)", key = "ShotCharge" },
    { kind = "s", name = "Charge time", key = "ChargeMax", range = { 0.3, 4 }, step = 0.1, suffix = " s", current = 1.5 },
    { kind = "s", name = "Power", key = "ShotPower", range = { 40, 800 }, step = 10, suffix = "", current = 190 },
    { kind = "s", name = "Speed", key = "ShotSpeed", range = { 20, 300 }, step = 5, suffix = " %", current = 100, scale = 0.01 },
    { kind = "s", name = "Gravity", key = "ShotGravity", range = { 10, 300 }, step = 5, suffix = " %", current = 100, scale = 0.01 },
    { kind = "s", name = "Curve amount", key = "CurveAmount", range = { 0, 100 }, step = 5, suffix = " %", current = 35 },
    { kind = "s", name = "Random curve spread", key = "CurveRandomPct", range = { 0, 100 }, step = 5, suffix = " %", current = 20 },
    { kind = "s", name = "Miss chance", key = "MissChance", range = { 0, 100 }, step = 1, suffix = " %", current = 0 },
    { kind = "t", name = "Auto Nero", key = "AutoNero" },
    { kind = "s", name = "Nero power", key = "NeroPower", range = { 60, 900 }, step = 10, suffix = "", current = 210 },
    { kind = "b", name = "Manual Nero", run = function() fireNero() end },
    { kind = "t", name = "Auto Header", key = "AutoHeader" },
    { kind = "s", name = "Header power", key = "HeaderPower", range = { 40, 600 }, step = 10, suffix = "", current = 150 },
})

local TabPass = Window:CreateTab("AIMPASS", 0)
build(TabPass, {
    { kind = "t", name = "AimPass", key = "AimPass" },
    { kind = "t", name = "Teammates Only", key = "TeammatesOnly" },
    { kind = "t", name = "Through Balls", key = "ThroughBalls" },
    { kind = "t", name = "Curve AimPass", key = "CurveAimPass" },
    { kind = "t", name = "Auto pass under pressure", key = "AutoPassPressure" },
    { kind = "s", name = "Pressure distance", key = "PressureM", range = { 1, 12 }, step = 0.5, suffix = " m", current = 4.0 },
    { kind = "s", name = "Min pass power", key = "PassMin", range = { 20, 400 }, step = 10, suffix = "", current = 90 },
    { kind = "s", name = "Max pass power", key = "PassMax", range = { 40, 800 }, step = 10, suffix = "", current = 220 },
    { kind = "s", name = "Max lob height", key = "LobMaxM", range = { 0.5, 20 }, step = 0.5, suffix = " m", current = 8.0 },
    { kind = "b", name = "Pass now", run = function() doPass() end },
})

local TabGk = Window:CreateTab("GOALKEEPER", 0)
build(TabGk, {
    { kind = "t", name = "Auto GK (air saves)", key = "AutoGk" },
    { kind = "t", name = "Auto GS (ground saves)", key = "AutoGs" },
    { kind = "s", name = "Dive speed", key = "DiveSpeed", range = { 20, 260 }, step = 5, suffix = " studs/s", current = 110 },
    { kind = "s", name = "GK touch reach", key = "GkReachM", range = { 1, CFG.GkReachMaxM }, step = 0.25, suffix = " m", current = 7.0 },
    { kind = "t", name = "Keeper Rush", key = "KeeperRush" },
    { kind = "s", name = "Rush radius", key = "RushM", range = { 4, 40 }, step = 1, suffix = " m", current = 18.0 },
    { kind = "t", name = "Panic Reach", key = "PanicReach" },
    { kind = "s", name = "Panic Reach radius", key = "PanicReachM", range = { 2, 20 }, step = 0.5, suffix = " m", current = 10.0 },
    { kind = "t", name = "Block Kick Deny Events", key = "BlockDeny", after = function(v) if v then installDenyHook() end end },
})

local TabDef = Window:CreateTab("DEFENDING", 0)
build(TabDef, {
    { kind = "t", name = "Auto Tackle", key = "AutoTackle" },
    { kind = "s", name = "Tackle range", key = "TackleM", range = { 1, CFG.TackleMaxM }, step = 0.25, suffix = " m", current = 5.0 },
    { kind = "t", name = "Auto Intercept", key = "AutoIntercept" },
    { kind = "t", name = "Auto Position", key = "AutoPosition" },
    { kind = "s", name = "Hold distance from ball", key = "PositionM", range = { 2, 30 }, step = 0.5, suffix = " m", current = 8.0 },
})

local TabMove = Window:CreateTab("MOVEMENT", 0)
build(TabMove, {
    { kind = "t", name = "WalkSpeed override", key = "SpeedOn",
      after = function(v) if not v then local _, h = myChar() if h then h.WalkSpeed = 16 end end end },
    { kind = "s", name = "WalkSpeed", key = "SpeedValue", range = { 16, 200 }, step = 1, suffix = " studs/s", current = 16 },
    { kind = "t", name = "Auto Sprint", key = "AutoSprint" },
    { kind = "s", name = "Sprint speed", key = "SprintValue", range = { 16, 120 }, step = 1, suffix = " studs/s", current = 28 },
    { kind = "t", name = "Jump override", key = "JumpOn" },
    { kind = "s", name = "Jump power", key = "JumpValue", range = { 50, 300 }, step = 5, suffix = "", current = 50 },
    { kind = "t", name = "Infinite jump", key = "InfJump" },
    { kind = "t", name = "Anti Stun", key = "AntiStun" },
    { kind = "t", name = "NoClip", key = "NoClip", after = function(v) if not v then noclipRestore() end end },
})

local TabSpecial = Window:CreateTab("SPECIAL", 0)
build(TabSpecial, {
    { kind = "t", name = "Phase Enemy", key = "PhaseEnemy", after = function(v) if not v then phaseRestore() end end },
    { kind = "d", name = "Phase mode", key = "PhaseMode", options = { "Look At", "Select" }, current = "Look At" },
    { kind = "i", name = "Phase target", hint = "player name", flag = "phase_target",
      run = function(t) S.PhaseTargetName = t or "" end },
    { kind = "t", name = "Anti-Phase", key = "AntiPhase" },
    { kind = "t", name = "Goal Farm", key = "GoalFarm" },
    { kind = "t", name = "Save Farm", key = "SaveFarm" },
    { kind = "t", name = "Dunk", key = "Dunk" },
    { kind = "s", name = "Dunk range", key = "DunkRangeM", range = { 2, 40 }, step = 1, suffix = " m", current = 14.0 },
    { kind = "t", name = "Trick Oms", key = "TrickOms" },
    { kind = "s", name = "Trick tempo", key = "TrickTempo", range = { 0.3, 10 }, step = 0.1, suffix = " /s", current = 3.0 },
    { kind = "t", name = "Ball Time", key = "BallTime" },
    { kind = "s", name = "Ball Time speed", key = "BallTimeMul", range = { 10, 300 }, step = 5, suffix = " %", current = 100, scale = 0.01 },
    { kind = "t", name = "Frame Player", key = "FramePlayer" },
    { kind = "i", name = "Frame target", hint = "player name", flag = "frame_target",
      run = function(t) S.FrameTargetName = t or "" end },
    { kind = "b", name = "Bring Ball", run = bringBall },
    { kind = "b", name = "Delete Ball", run = deleteBall },
    { kind = "b", name = "Freeze / Unfreeze Ball", run = toggleFreeze },
})

local TabVis = Window:CreateTab("VISUALS", 0)
build(TabVis, {
    { kind = "t", name = "Ball ESP", key = "BallEsp" },
    { kind = "t", name = "Player ESP", key = "PlayerEsp" },
    { kind = "t", name = "Landing marker", key = "PredictLine" },
    { kind = "t", name = "Ball Trail", key = "BallTrail",
      after = function(v) if not v then local b = getBall() if b then detachTrail(b) end end end },
    { kind = "t", name = "RGB Character (Neon)", key = "RgbChar" },
    { kind = "t", name = "Rainbow Boot Trail", key = "BootTrail" },
    { kind = "t", name = "Time of Day", key = "TimeOfDay" },
    { kind = "s", name = "Clock time", key = "TimeValue", range = { 0, 24 }, step = 0.5, suffix = " h", current = 14 },
    { kind = "t", name = "FPS Boost", key = "FpsBoost", after = function(v) if v then applyFpsBoost() end end },
    { kind = "t", name = "Spoof Marker", key = "SpoofMarker" },
    { kind = "s", name = "Spoof ping", key = "SpoofPing", range = { 5, 300 }, step = 1, suffix = " ms", current = 42 },
    { kind = "s", name = "Spoof CPU", key = "SpoofCpu", range = { 1, 99 }, step = 1, suffix = " %", current = 3 },
    { kind = "s", name = "Spoof sent", key = "SpoofSent", range = { 1, 200 }, step = 1, suffix = " kb/s", current = 12 },
})

local TabHud = Window:CreateTab("HUD", 0)
build(TabHud, {
    { kind = "t", name = "Show HUD panel", key = "Hud", after = function() buildHud() end },
    { kind = "s", name = "HUD scale", key = "HudScale", range = { 60, 200 }, step = 5, suffix = " %",
      current = 100, after = function() buildHud() end },
    { kind = "s", name = "Chip columns", key = "ButtonColumns", range = { 1, 3 }, step = 1, suffix = "",
      current = 2, after = function() buildHud() end },
    { kind = "d", name = "Chip shape", key = "ButtonShape", options = { "Rounded", "Circle", "Square" },
      current = "Rounded", after = function() buildHud() end },
    { kind = "t", name = "Notifications", key = "Notifications" },
    { kind = "b", name = "Rebuild HUD", run = buildHud },
})

local TabSet = Window:CreateTab("SETTINGS", 0)
build(TabSet, {
    { kind = "t", name = "Anti-AFK", key = "AntiAfk" },
    { kind = "t", name = "Auto Best Server", key = "AutoBestServer" },
    { kind = "s", name = "Ping limit", key = "HopMaxPing", range = { 40, 400 }, step = 10, suffix = " ms", current = 120 },
    { kind = "b", name = "Hop Server (low ping)", run = function() hopServer(S.HopMaxPing) end },
    { kind = "b", name = "Rejoin", run = doRejoin },
    { kind = "t", name = "Panic Staff (auto-leave)", key = "PanicStaff" },
    { kind = "t", name = "Auto Complete Quest", key = "AutoQuest" },
    { kind = "b", name = "Force Respawn", run = forceRespawn },
    { kind = "b", name = "Panic Eject", run = panicEject },
})

local TabKeys = Window:CreateTab("KEYBINDS", 0)
local bindButtons = {}
for _, name in ipairs(BIND_ORDER) do
    bindButtons[name] = TabKeys:CreateButton({
        Name = ("%s  [%s]"):format(name, bindLabel(name)),
        Callback = function()
            S.Binding = name
            notify("Keybinds", ("Press a key or pad button for %s"):format(name), 4)
            task.spawn(function()
                local t0 = os.clock()
                while S.Binding == name and os.clock() - t0 < 8 do task.wait(0.1) end
                if S.Binding == name then S.Binding = nil end
                pcall(function()
                    bindButtons[name]:Set(("%s  [%s]"):format(name, bindLabel(name)))
                end)
            end)
        end,
    })
end
TabKeys:CreateButton({ Name = "Print all binds", Callback = function()
    local lines = { "=== TF BINDS ===" }
    for _, name in ipairs(BIND_ORDER) do
        lines[#lines + 1] = ("%-10s %s"):format(name, bindLabel(name))
    end
    print(table.concat(lines, "\n"))
end })

local TabDisc = Window:CreateTab("DISCOVERY", 0)
build(TabDisc, {
    { kind = "b", name = "Channel test", run = function()
        pushSimulationRadius()
        local owned = probeOwnership()
        notify("Channels", ("touch=%s own=%s"):format(tostring(CAP.touch), tostring(owned)), 6)
    end },
    { kind = "b", name = "Diagnostics", run = function() diagnostics() end },
    { kind = "b", name = "Dump remotes", run = dumpRemotes },
    { kind = "b", name = "Scan ball candidates", run = dumpBallCandidates },
    { kind = "b", name = "Scan goal candidates", run = dumpGoalCandidates },
    { kind = "b", name = "Dump PlayerGui", run = dumpPlayerGui },
    { kind = "b", name = "Forget learned ball and goals", run = function()
        Learned.ball_name, Learned.ball_path = "", ""
        Learned.goal_own, Learned.goal_enemy = nil, nil
        HAS.learned_ball, HAS.learned_goals = false, false
        BallCache.stamp, GoalCache.stamp = -1, -1
        saveLearned()
    end },
    { kind = "b", name = "Re-arm disabled features", run = function()
        for n in pairs(S.Disabled) do S.Disabled[n] = nil end
        S.Err = {}
    end },
})

local TabCfg = Window:CreateTab("CONFIG", 0)
build(TabCfg, {
    { kind = "i", name = "Ball Instance name", current = CFG.BallNameOverride, hint = "exact name", flag = "cfg_ball",
      run = function(t) CFG.BallNameOverride = t or "" refreshHas() BallCache.stamp = -1 end },
    { kind = "i", name = "Ball parent", current = CFG.BallParentOverride, hint = "workspace child", flag = "cfg_ballparent",
      run = function(t) CFG.BallParentOverride = t or "" refreshHas() BallCache.stamp = -1 end },
    { kind = "i", name = "Catch remote", current = CFG.CatchRemoteName, hint = "RemoteEvent name", flag = "cfg_catch",
      run = function(t) CFG.CatchRemoteName = t or "" refreshHas() end },
    { kind = "i", name = "Shoot remote", current = CFG.ShootRemoteName, hint = "RemoteEvent name", flag = "cfg_shoot",
      run = function(t) CFG.ShootRemoteName = t or "" refreshHas() end },
    { kind = "i", name = "Quest remote", current = CFG.QuestRemoteName, hint = "RemoteEvent name", flag = "cfg_quest",
      run = function(t) CFG.QuestRemoteName = t or "" refreshHas() end },
    { kind = "i", name = "Respawn remote", current = CFG.RespawnRemoteName, hint = "RemoteEvent name", flag = "cfg_respawn",
      run = function(t) CFG.RespawnRemoteName = t or "" refreshHas() end },
    { kind = "i", name = "Marker GUI path", current = CFG.MarkerGuiPath, hint = "HUD.Stats.Frame", flag = "cfg_marker",
      run = function(t) CFG.MarkerGuiPath = t or "" refreshHas() end },
    { kind = "i", name = "Staff group id", current = tostring(CFG.StaffGroupId), hint = "numbers", flag = "cfg_group",
      run = function(t) CFG.StaffGroupId = tonumber(t) or 0 refreshHas() end },
    { kind = "i", name = "Staff min rank", current = tostring(CFG.StaffMinRank), hint = "numbers", flag = "cfg_rank",
      run = function(t) CFG.StaffMinRank = tonumber(t) or 100 end },
    { kind = "i", name = "Add staff name", hint = "one name", clear = true, flag = "cfg_staffname",
      run = function(t) if t and t ~= "" then CFG.StaffNames[#CFG.StaffNames + 1] = t end end },
    { kind = "i", name = "Add deny event", hint = "remote name", clear = true, flag = "cfg_deny",
      run = function(t) if t and t ~= "" then CFG.DenyEventNames[#CFG.DenyEventNames + 1] = t refreshHas() end end },
    { kind = "i", name = "Add ball pattern", hint = "lowercase", clear = true, flag = "cfg_pattern",
      run = function(t) if t and t ~= "" then CFG.BallPatterns[#CFG.BallPatterns + 1] = string.lower(t) BallCache.stamp = -1 end end },
    { kind = "i", name = "Add goal pattern", hint = "lowercase", clear = true, flag = "cfg_goalpattern",
      run = function(t) if t and t ~= "" then CFG.GoalPatterns[#CFG.GoalPatterns + 1] = string.lower(t) GoalCache.stamp = -1 end end },
    { kind = "b", name = "Unload", run = function()
        teardown()
        pcall(function() Rayfield:Destroy() end)
    end },
})

Rayfield:LoadConfiguration()
buildHud()

getgenv().TF = {
    S = S, CFG = CFG, KEYS = KEYS, CAP = CAP,
    teardown = teardown, diag = diagnostics, learnBall = learnBall, learnGoal = learnGoal,
    probe = probeOwnership, hop = hopServer, rejoin = doRejoin, panic = panicEject,
    pass = doPass, nero = fireNero, bring = bringBall, freeze = toggleFreeze,
    math = { lead = leadPosition, ballistic = ballisticDirection, apex = apexVelocity,
             spin = curveSpin, closest = closestApproach, look = cappedLook },
}

task.spawn(function()
    task.wait(1.5)
    pushSimulationRadius()
    local ball, tier = getBall()
    report(("[TF %s] boot: ball=%s tier=%s touch=%s simrad=%s"):format(
        VERSION, ball and ball.Name or "none", tier, tostring(CAP.touch),
        tostring(CAP.simrad or CAP.hidden)))
end)

notify("Touch Football", VERSION .. " loaded", 4)
