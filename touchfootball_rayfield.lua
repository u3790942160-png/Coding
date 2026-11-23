--!nocheck
-- touchfootball_rayfield.lua  --  v3.0
-- Touch Football (Roblox) feature suite with Rayfield UI.
-- v3 replaces the v1/v2 feature set entirely with the requested groups:
-- SETTINGS, REACH, SKILLS, AIMBOT, AIMPASS, GOALKEEPER, SPECIAL, VISUALS,
-- CHARACTER, KEYBINDS.
--
-- Ground rules kept from the bench:
--   * no invented build-dependent value. Remote names, group ids and the
--     game's marker GUI path are UNSET in CFG and each gates exactly one
--     feature; everything else runs on engine APIs.
--   * ball and goal identity are resolved in tiers and reported, never
--     promoted. Learn buttons pin them.
--   * one arbiter owns writes to the ball, so two features never fight.
--
-- Executor requirements: loadstring + HttpGet (Rayfield, server list).
-- Optional APIs guarded: Drawing, gethui, setclipboard, writefile/readfile,
-- queue_on_teleport, hookmetamethod/getnamecallmethod, getgenv.

local VERSION = "v3.0"

----------------------------------------------------------------------
-- CONFIG  (provenance: kind | build | source | verified)
----------------------------------------------------------------------

local CFG = {
    -- [name | unknown | no dump supplied | not verified] ball identity
    BallNameOverride = "",
    BallParentOverride = "",

    -- [name | unknown | no dump supplied | not verified] one feature each
    CatchRemoteName = "",     -- gates: remote-path catch
    ShootRemoteName = "",     -- gates: remote-path shot / pass
    QuestRemoteName = "",     -- gates: Auto Complete Quest
    RespawnRemoteName = "",   -- gates: server-side Force Respawn
    R6RemoteName = "",        -- gates: R6 request
    MarkerGuiPath = "",       -- gates: Spoof Marker (PlayerGui path to the label holder)

    -- [number | unknown | operator supplied | not verified] gates: Panic Staff group check
    StaffGroupId = 0,
    StaffMinRank = 100,
    -- Names are operator-supplied data, not derived from the game.
    StaffNames = {},

    -- [name | unknown | no dump supplied | not verified] gates: Block Kick Deny Events
    DenyEventNames = {},

    -- [constant | engine | Workspace.Gravity read live each frame | verified live]
    GravityFallback = 196.2,
    -- [constant | engine docs | Roblox 1 stud = 0.28 m | not verified against this build's scale]
    StudsPerMetre = 1 / 0.28,

    ReachMaxM = 6.0,
    PokeMaxM = 8.0,
    GkReachMaxM = 12.0,

    BallPatterns = { "football", "ball", "pigskin", "pball", "oval" },
    GoalPatterns = { "goal", "net", "hoop", "post", "endzone", "touchline" },

    LearnFile = "TouchFootball/learned_v3.json",
    ServerApi = "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
}

local STUDS_PER_M = CFG.StudsPerMetre

local HAS = {
    ball_name = CFG.BallNameOverride ~= "",
    ball_parent = CFG.BallParentOverride ~= "",
    catch = CFG.CatchRemoteName ~= "",
    shoot = CFG.ShootRemoteName ~= "",
    quest = CFG.QuestRemoteName ~= "",
    respawn = CFG.RespawnRemoteName ~= "",
    r6 = CFG.R6RemoteName ~= "",
    marker = CFG.MarkerGuiPath ~= "",
    staff_group = CFG.StaffGroupId > 0,
    deny = #CFG.DenyEventNames > 0,
    learned_ball = false,
    learned_goals = false,
}

----------------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------------

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui       = game:GetService("StarterGui")
local VirtualUser      = game:GetService("VirtualUser")
local Stats            = game:GetService("Stats")
local TweenService     = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

----------------------------------------------------------------------
-- STATE
----------------------------------------------------------------------

local S = {
    -- settings
    AntiAfk = true, AutoBestServer = false, PanicStaff = false,
    Notifications = true, AutoQuest = false,
    Buttons = false, ButtonSize = 56, ButtonShape = "Circle",
    HopMaxPing = 120, LastHop = 0,

    -- reach
    ProReach = false, ControlReach = false,
    ReachM = 3.0, ControlReachM = 4.5, ReachPriority = "Reach",
    BallHold = false, HoldOffsetM = 0.9,
    AdaptHighMs = false, AdaptPerMs = 0.012, AdaptTriggerPerMs = 0.02,
    ReachPower = 0.55,

    -- skills
    Sneaky = false, SneakyAirOnly = true, SneakyAutoAdapt = true,
    SneakyPower = 55, SneakyRangeM = 4.0,
    Pokers = false, PokeSpeed = 2.5, PokeRangeM = 3.0,
    AutoJuggle = false, JuggleReachM = 2.5, JuggleHeightM = 2.0, JuggleSticky = true,
    JuggleTaps = 0, JuggleLast = 0,
    GroundShots = false, GroundShotPower = 140,

    -- aimbot
    Aimbot = false, Aimlock = false,
    CurveAimbot = false, AutoAdaptCurve = true, RandomCurve = false,
    TopCorner = false, AutoDetectGoal = true,
    ShotPower = 170, ShotSpeed = 1.0, ShotGravity = 1.0,
    MissChance = 0, CurveAmount = 35, CurveRandomPct = 20,
    AutoNero = false, ManualNero = false, AutoHeader = false,
    NeroPower = 210, HeaderPower = 150,

    -- aimpass
    AimPass = false, TeammatesOnly = true, ThroughBalls = false,
    CurveAimPass = false, PassMin = 90, PassMax = 220, LobMaxM = 8.0,

    -- goalkeeper
    AutoGk = false, AutoGs = false, DiveSpeed = 90,
    GkReachM = 6.0, BlockDeny = false, PanicReach = false,
    PanicReachM = 9.0,

    -- special
    PhaseEnemy = false, PhaseMode = "Look At", PhaseTargetName = "",
    GoalFarm = false, SaveFarm = false, Dunk = false, DunkRangeM = 12.0,
    AntiPhase = false, TrickOms = false, TrickTempo = 3.0, TrickLast = 0,
    BallTime = false, BallTimeMul = 1.0,
    FramePlayer = false, FrameTargetName = "",
    BallFrozen = false,

    -- visuals
    BallEsp = false, BallTrail = false, RgbChar = false, BootTrail = false,
    TimeOfDay = false, TimeValue = 14, SpoofMarker = false,
    SpoofPing = 42, SpoofCpu = 3, SpoofSent = 12,

    -- character
    UseOwnAvatar = false, HatAssetId = 0, HairAssetId = 0,

    -- bookkeeping
    FrameId = 0, LastGravity = CFG.GravityFallback,
    LastQuest = 0, PokeLast = 0, LastHopCheck = 0, RgbWasOn = false,
    Ping = 0, BallTier = "unknown", GoalTier = "unknown",
    Ownership = nil, Err = {}, Disabled = {}, Notices = {},
    Binding = nil,
}

-- Defaults taken from the requested bind list; every one is rebindable.
local KEYS = {
    Reach    = { kb = Enum.KeyCode.R, pad = Enum.KeyCode.ButtonR1 },
    Sneaky   = { kb = Enum.KeyCode.X, pad = Enum.KeyCode.ButtonL1 },
    Aimbot   = { kb = Enum.KeyCode.T, pad = Enum.KeyCode.ButtonY },
    AimPass  = { kb = Enum.KeyCode.G, pad = Enum.KeyCode.ButtonX },
    AutoGk   = { kb = Enum.KeyCode.V, pad = Enum.KeyCode.ButtonB },
    Phase    = { kb = Enum.KeyCode.F, pad = Enum.KeyCode.ButtonL3 },
    Juggle   = { kb = Enum.KeyCode.J, pad = Enum.KeyCode.DPadUp },
    Poke     = { kb = Enum.KeyCode.C, pad = Enum.KeyCode.DPadLeft },
    Nero     = { kb = Enum.KeyCode.N, pad = Enum.KeyCode.DPadRight },
    Dunk     = { kb = Enum.KeyCode.B, pad = Enum.KeyCode.DPadDown },
    BringBall= { kb = Enum.KeyCode.H, pad = Enum.KeyCode.ButtonSelect },
    Freeze   = { kb = Enum.KeyCode.K, pad = Enum.KeyCode.ButtonR3 },
    PanicEject = { kb = Enum.KeyCode.P, pad = Enum.KeyCode.ButtonStart },
    LearnBall  = { kb = Enum.KeyCode.L, pad = Enum.KeyCode.Unknown },
}

local Learned = { ball_name = "", ball_path = "", goal_own = nil, goal_enemy = nil }

local Conns = {}
local Trails = {}        -- [instance] = Trail
local OrigCollide = {}   -- [BasePart] = boolean
local PhaseSaved = {}    -- [BasePart] = boolean
local BallCache = { part = nil, tier = "unknown", stamp = -1 }
local GoalCache = { own = nil, enemy = nil, tier = "unknown", stamp = -1 }
local BallDraw = { dot = nil, tracer = nil }
local Buttons = { gui = nil, items = {} }
local MarkerSaved = {}

----------------------------------------------------------------------
-- UTIL
----------------------------------------------------------------------

local function report(text) print(text) end

local function notify(title, text, dur)
    if not S.Notifications then return end
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = dur or 4 })
    end)
    report(("[TF %s] %s: %s"):format(VERSION, title, text))
end

local function gateOff(feature, missing)
    if S.Notices[feature] then return end
    S.Notices[feature] = true
    notify("Gated", ("%s needs %s. It is UNSET."):format(feature, missing), 6)
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
    if e.n > 240 then
        S.Disabled[name] = true
        report(("[TF] %s auto-disabled after %d errors. Last: %s"):format(name, e.n, e.last))
        notify("Watchdog", ("%s auto-disabled. See DIAGNOSTICS."):format(name), 8)
    end
end

local function readPing()
    local ok, v = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and isFiniteNumber(v) and v >= 0 then S.Ping = v end
    return S.Ping
end

-- Adapt High MS: ping buys extra reach and an earlier trigger, both bounded.
local function adaptBonusM()
    if not S.AdaptHighMs then return 0 end
    local over = math.max(0, S.Ping - 80)
    return math.clamp(over * S.AdaptPerMs, 0, 3.0)
end

local function adaptTriggerBonusM()
    if not S.AdaptHighMs then return 0 end
    local over = math.max(0, S.Ping - 80)
    return math.clamp(over * S.AdaptTriggerPerMs, 0, 4.0)
end

local function reachMetres()
    local base = S.ControlReach and math.max(S.ReachM, S.ControlReachM) or S.ReachM
    return math.clamp(base + adaptBonusM(), 0, CFG.ReachMaxM + 3.0)
end

local function reachStuds() return metresToStuds(reachMetres()) end

----------------------------------------------------------------------
-- LEARNED VALUES
----------------------------------------------------------------------

local function saveLearned()
    if not (writefile and isfolder and makefolder) then return false end
    local payload = {
        ball_name = Learned.ball_name,
        ball_path = Learned.ball_path,
        goal_own = Learned.goal_own and { Learned.goal_own.X, Learned.goal_own.Y, Learned.goal_own.Z } or nil,
        goal_enemy = Learned.goal_enemy and { Learned.goal_enemy.X, Learned.goal_enemy.Y, Learned.goal_enemy.Z } or nil,
    }
    return (pcall(function()
        if not isfolder("TouchFootball") then makefolder("TouchFootball") end
        writefile(CFG.LearnFile, HttpService:JSONEncode(payload))
    end))
end

local function loadLearned()
    if not (readfile and isfile) then return false end
    local ok, data = pcall(function()
        if not isfile(CFG.LearnFile) then return nil end
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
    if inst:IsA("Model") and inst.PrimaryPart then return inst.PrimaryPart end
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
                    if p and (nameLooksLikeBall(inst.Name) or nameLooksLikeBall(p.Name)) then return p end
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

local function findLoose(root)
    local best, bestScore = nil, math.huge
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("BasePart") and not inst.Anchored and isPlausibleVector(inst.Position) and inst.Size.Magnitude < 6 then
            local moving = inst.AssemblyLinearVelocity.Magnitude > 1
            local round = (inst:IsA("Part") and inst.Shape == Enum.PartType.Ball)
                or inst:FindFirstChildOfClass("SpecialMesh") ~= nil
            if moving or round then
                local score = inst.Size.Magnitude - (moving and 2 or 0) - (round and 2 or 0)
                if score < bestScore then best, bestScore = inst, score end
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
    if not found then found = findHeld() end
    if not found then
        local ball = getBall()
        local foot = footPosition(ch)
        if ball and foot and (ball.Position - foot).Magnitude < metresToStuds(5) then found = ball end
    end
    if not found then found = findLoose(searchRoot()) end
    if not found then
        notify("Learn", "Nothing close enough. Stand on the ball and press again.", 6)
        return nil
    end
    Learned.ball_name = found.Name
    Learned.ball_path = found:GetFullName()
    HAS.learned_ball = true
    BallCache.stamp = -1
    local saved = saveLearned()
    report(("[TF] learned ball: %s (%s) persisted=%s"):format(Learned.ball_name, Learned.ball_path, tostring(saved)))
    notify("Learn", ("Ball = %s"):format(Learned.ball_name), 5)
    return found
end

----------------------------------------------------------------------
-- GOAL RESOLVER
-- Derived from parts whose name matches a goal pattern, split into two
-- clusters by distance along the dominant axis. Learned positions win.
----------------------------------------------------------------------

local function goalCandidates()
    local out = {}
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("BasePart") and nameMatches(inst.Name, CFG.GoalPatterns) and isPlausibleVector(inst.Position) then
            out[#out + 1] = inst
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
    if root then
        if (root.Position - b).Magnitude < (root.Position - a).Magnitude then mine, theirs = b, a end
    end
    return mine, theirs, "derived-name"
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
    if not root then notify("Learn goal", "No live character.", 4) return end
    local cands = goalCandidates()
    local best, bestD = nil, math.huge
    for _, p in ipairs(cands) do
        local d = (p.Position - root.Position).Magnitude
        if d < bestD then best, bestD = p, d end
    end
    local pos = best and best.Position or root.Position
    if which == "enemy" then Learned.goal_enemy = pos else Learned.goal_own = pos end
    HAS.learned_goals = Learned.goal_enemy ~= nil
    GoalCache.stamp = -1
    saveLearned()
    report(("[TF] learned %s goal at %s (%s)"):format(which, tostring(pos), best and best:GetFullName() or "your position"))
    notify("Learn goal", ("%s goal pinned."):format(which), 4)
end

-- Goal mouth size, used by Top Corner. Derived from the nearest goal part's
-- bounding size when one exists, otherwise a conservative default.
local function goalMouth(pos)
    local best, bestD = nil, math.huge
    for _, p in ipairs(goalCandidates()) do
        local d = (p.Position - pos).Magnitude
        if d < bestD then best, bestD = p, d end
    end
    if best then
        return math.max(best.Size.X, best.Size.Z), math.max(best.Size.Y, 6)
    end
    return 24, 10
end

----------------------------------------------------------------------
-- OWNERSHIP PROBE
----------------------------------------------------------------------

local function probeOwnership()
    local ball = getBall()
    if not ball then
        S.Ownership = nil
        report("[TF] ownership probe: no ball resolved")
        return nil
    end
    local before = ball.Position
    if not isPlausibleVector(before) then S.Ownership = nil return nil end
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
    report(("[TF] ownership probe: %s (moved %.3f studs)"):format(
        held and "CLIENT can write the ball" or "SERVER owns the ball", (after - before).Magnitude))
    return S.Ownership
end

----------------------------------------------------------------------
-- MATH  (pure, checkable without the game)
-- Roblox: Y up, studs, Workspace.Gravity in studs/s^2, FOV in degrees.
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

-- Spin that bends a shot sideways. Side is +1 right, -1 left; amount is the
-- UI value in percent of the shot's own speed.
local function curveSpin(dir, amountPct, side)
    if not isPlausibleVector(dir) or dir.Magnitude < 1e-6 then return Vector3.new() end
    local axis = Vector3.new(0, 1, 0)
    local lateral = dir.Unit:Cross(axis)
    if lateral.Magnitude < 1e-6 then return Vector3.new() end
    local scale = math.clamp(amountPct, 0, 100) / 100
    return lateral.Unit * (scale * 60 * (side >= 0 and 1 or -1))
end

-- Point on a straight ball path closest to a target position, and when.
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
-- Every feature that wants the ball submits a request with a priority. The
-- highest priority request of the frame is the only one applied, so Reach,
-- GK, Juggle and the farms never fight for the same assembly.
----------------------------------------------------------------------

local PRIORITY = {
    PanicReach = 100, Freeze = 95, Bring = 90, Dunk = 85, GoalFarm = 80,
    Gk = 75, SaveFarm = 70, Shot = 65, Pass = 60, Nero = 58, Header = 56,
    Poke = 50, Sneaky = 48, Trick = 46, Hold = 40, Reach = 35,
    Juggle = 30, Frame = 25, BallTime = 10,
}

local Pending = nil

local function requestBall(tag, apply)
    local prio = PRIORITY[tag] or 1
    -- Reach Priority promotes one family above the rest.
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
    if not ok then
        local e = S.Err["ball:" .. req.tag]
        if not e then e = { n = 0, last = "" } S.Err["ball:" .. req.tag] = e end
        e.n = e.n + 1
        e.last = tostring(err)
    end
end

-- Primitive writes. Every one validates before it touches the assembly.
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
    local speed = math.clamp(d * (8 * math.clamp(power, 0.05, 1)), 2, 240)
    return setBallVelocity(ball, delta.Unit * speed)
end

local function kickBall(ball, dir, power, curvePct, side)
    if not (ball and isPlausibleVector(dir) and dir.Magnitude > 1e-6) then return false end
    local v = dir.Unit * math.clamp(power, 1, 2000)
    if not setBallVelocity(ball, v) then return false end
    -- A straight shot clears the spin, or it inherits the last curve.
    if curvePct and curvePct > 0 then
        setBallSpin(ball, curveSpin(dir, curvePct, side or 1))
    else
        setBallSpin(ball, Vector3.new(0, 0, 0))
    end
    return true
end

----------------------------------------------------------------------
-- SETTINGS: session, servers, staff, quests
----------------------------------------------------------------------

local function doRejoin()
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
    if not ok then pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end) end
    notify("Rejoin", "Teleport requested.", 4)
end

local function fetchServers()
    local url = string.format(CFG.ServerApi, game.PlaceId)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok then
        report("[TF] server list fetch failed: " .. tostring(body))
        return nil
    end
    local ok2, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not (ok2 and type(data) == "table" and type(data.data) == "table") then
        report("[TF] server list decode failed")
        return nil
    end
    return data.data
end

-- Lowest reported ping with a free slot, never the server we are already on.
local function pickServer(maxPing)
    local list = fetchServers()
    if not list then return nil end
    local best, bestPing = nil, math.huge
    for _, srv in ipairs(list) do
        local id = srv.id
        local playing = tonumber(srv.playing) or 0
        local cap = tonumber(srv.maxPlayers) or 0
        local ping = tonumber(srv.ping) or 9999
        if type(id) == "string" and id ~= game.JobId and playing < cap then
            if ping <= (maxPing or 9999) and ping < bestPing then best, bestPing = id, ping end
        end
    end
    return best, bestPing
end

local function hopServer(maxPing)
    if os.clock() - S.LastHop < 8 then
        notify("Hop", "Cooling down.", 3)
        return
    end
    S.LastHop = os.clock()
    local id, ping = pickServer(maxPing)
    if not id then
        notify("Hop", "No server under the ping limit.", 5)
        return
    end
    report(("[TF] hopping to %s (reported ping %d)"):format(id, ping or -1))
    if queue_on_teleport then
        pcall(function() queue_on_teleport("-- TouchFootball: re-execute your loader here after the hop") end)
    end
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, id, LocalPlayer) end)
end

local function autoBestServerStep()
    if not S.AutoBestServer then return end
    if os.clock() - S.LastHop < 45 then return end
    readPing()
    if S.Ping <= S.HopMaxPing then return end
    report(("[TF] auto best server: local ping %.0f ms over limit %d"):format(S.Ping, S.HopMaxPing))
    hopServer(S.HopMaxPing)
end

local function isStaff(plr)
    for _, n in ipairs(CFG.StaffNames) do
        if string.lower(plr.Name) == string.lower(n) then return true, "name list" end
    end
    if HAS.staff_group then
        local ok, rank = pcall(function() return plr:GetRankInGroup(CFG.StaffGroupId) end)
        if ok and type(rank) == "number" and rank >= CFG.StaffMinRank then return true, "group rank " .. rank end
    end
    return false, nil
end

local function panicLeave(why)
    report("[TF] panic leave: " .. tostring(why))
    pcall(function() LocalPlayer:Kick("TF panic: " .. tostring(why)) end)
end

local function panicStaffStep()
    if not S.PanicStaff then return end
    if not (HAS.staff_group or #CFG.StaffNames > 0) then
        gateOff("Panic Staff", "CFG.StaffGroupId or CFG.StaffNames")
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local hit, why = isStaff(plr)
            if hit then
                panicLeave(("%s (%s)"):format(plr.Name, why))
                return
            end
        end
    end
end

local function antiAfkSetup()
    local conn = LocalPlayer.Idled:Connect(function()
        if not S.AntiAfk then return end
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
        end)
        report("[TF] anti-afk tick")
    end)
    Conns[#Conns + 1] = conn
end

local function autoQuestStep()
    if not S.AutoQuest then return end
    if not HAS.quest then
        gateOff("Auto Complete Quest", "CFG.QuestRemoteName")
        S.AutoQuest = false
        return
    end
    local rem = ReplicatedStorage:FindFirstChild(CFG.QuestRemoteName, true)
    if not rem then return end
    if os.clock() - (S.LastQuest or 0) < 5 then return end
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
            notify("Respawn", "Remote fired.", 4)
            return
        end
    end
    local ch, hum = myChar()
    if hum then
        pcall(function() hum.Health = 0 end)
        notify("Respawn", "Health zeroed (no respawn remote set).", 5)
    end
end

local function panicEject()
    local ch, hum, root = myChar()
    -- Every assist off, in one stroke.
    for _, k in ipairs({
        "ProReach", "ControlReach", "BallHold", "Sneaky", "Pokers", "AutoJuggle", "GroundShots",
        "Aimbot", "Aimlock", "CurveAimbot", "AutoNero", "AutoHeader", "AimPass",
        "AutoGk", "AutoGs", "PanicReach", "PhaseEnemy", "GoalFarm", "SaveFarm",
        "Dunk", "TrickOms", "BallTime", "FramePlayer", "BallEsp", "BallTrail",
    }) do
        S[k] = false
    end
    if hum then
        pcall(function()
            hum.Sit = false
            hum.PlatformStand = false
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
    local ball = getBall()
    if ball then pcall(function() ball.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end) end
    report("[TF] PANIC EJECT: every assist disabled, seat released.")
    notify("Panic", "All assists off.", 5)
end

----------------------------------------------------------------------
-- REACH
-- Pro Reach is the natural profile: velocity pulls only, trigger scaled by
-- approach speed. Control Reach is the easy profile: bigger radius, direct
-- placement, sticky once held.
----------------------------------------------------------------------

local function reachTriggerStuds()
    local base = reachStuds()
    local extra = metresToStuds(adaptTriggerBonusM())
    return base + extra
end

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
    -- Approach speed widens the natural trigger, which is what makes Pro
    -- Reach meet a fast ball instead of trailing it.
    if S.ProReach then
        local closing = (foot - ball.Position).Unit:Dot(ball.AssemblyLinearVelocity)
        if closing > 0 then trigger = trigger + math.clamp(closing * 0.06, 0, 8) end
    end
    if d > trigger then return end

    local natural = S.ProReach and not S.ControlReach
    requestBall("Reach", function()
        pullBall(ball, foot, natural, S.ReachPower)
    end)
end

local function ballHoldStep()
    if not S.BallHold then return end
    local ch, hum, root = myChar()
    if not ch or not root then return end
    local ball = getBall()
    if not ball or not ball.Parent or ball:IsDescendantOf(ch) then return end
    local foot = footPosition(ch) or root.Position
    local d = (ball.Position - foot).Magnitude
    if d > reachTriggerStuds() * 1.4 then return end
    local ahead = root.CFrame.LookVector * metresToStuds(S.HoldOffsetM)
    local target = foot + Vector3.new(ahead.X, 0, ahead.Z)
    requestBall("Hold", function()
        pullBall(ball, target, not S.ControlReach, math.max(S.ReachPower, 0.7))
    end)
end

----------------------------------------------------------------------
-- SKILLS: sneaky, pokers, auto juggle, ground shots
----------------------------------------------------------------------

-- An opponent is anyone not on your team. When the game has no teams at
-- all, everyone but you counts.
local function nearestOpponent(fromPos, maxStuds)
    local best, bestD = nil, maxStuds or math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if not (plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team) then
                local ch, hum, root = alive(plr)
                if root then
                    local d = (root.Position - fromPos).Magnitude
                    if d < bestD then best, bestD = plr, d end
                end
            end
        end
    end
    return best, bestD
end

-- Sneaky: lift the ball over the man in front. Air Only waits until the ball
-- is already off the ground; Auto Adapt sizes the lift by his distance.
local function sneakyStep()
    if not S.Sneaky then return end
    local ch, hum, root = myChar()
    if not ch or not root then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    local foot = footPosition(ch) or root.Position
    local d = (ball.Position - foot).Magnitude
    if d > metresToStuds(S.SneakyRangeM) then return end

    local airborne = ball.Position.Y > foot.Y + 1.2
    if S.SneakyAirOnly and not airborne then return end

    local opp, oppD = nearestOpponent(root.Position, metresToStuds(14))
    local lift = S.SneakyPower
    local forward = root.CFrame.LookVector
    if S.SneakyAutoAdapt and opp then
        -- Closer man, higher and shorter lift; distant man, flatter and longer.
        local f = math.clamp(1 - (oppD / metresToStuds(14)), 0, 1)
        lift = S.SneakyPower * (0.7 + 0.8 * f)
    end
    local over = Vector3.new(forward.X, 0, forward.Z)
    if over.Magnitude < 1e-4 then over = Vector3.new(0, 0, -1) else over = over.Unit end
    local v = over * (lift * 0.9) + Vector3.new(0, apexVelocity(metresToStuds(2.2), S.LastGravity), 0)
    requestBall("Sneaky", function() setBallVelocity(ball, v) end)
end

-- Pokers: short jabs at a controlled tempo, speed slider drives both the
-- tempo and the touch strength.
local function pokersStep()
    if not S.Pokers then return end
    local ch, hum, root = myChar()
    if not ch or not root then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    local foot = footPosition(ch) or root.Position
    if (ball.Position - foot).Magnitude > metresToStuds(math.min(S.PokeRangeM, CFG.PokeMaxM)) then return end
    local now = os.clock()
    local interval = 1 / math.clamp(S.PokeSpeed, 0.2, 10)
    if now - (S.PokeLast or 0) < interval then return end
    local fwd = root.CFrame.LookVector
    local flat = Vector3.new(fwd.X, 0, fwd.Z)
    if flat.Magnitude < 1e-4 then return end
    local v = flat.Unit * (18 + S.PokeSpeed * 9) + Vector3.new(0, 6, 0)
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

    local centring = S.JuggleSticky and 1.4 or 0.6
    local back = Vector3.new(foot.X - ball.Position.X, 0, foot.Z - ball.Position.Z) * centring
    local v = Vector3.new(back.X, apexVelocity(apex, S.LastGravity), back.Z)
    requestBall("Juggle", function()
        if setBallVelocity(ball, v) then
            S.JuggleLast = now
            S.JuggleTaps = S.JuggleTaps + 1
        end
    end)
end

-- Ground Shots: flat drive at the enemy goal, no loft at all.
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
    requestBall("Shot", function() setBallVelocity(ball, v) end)
end

----------------------------------------------------------------------
-- AIMBOT: shots at the enemy goal
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
        local side = 1
        if root and root.Position.X > enemy.X then side = -1 end
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
    -- Bend away from the side the keeper-side approach came from.
    return (facing.Unit:Cross(toGoal.Unit).Y >= 0) and 1 or -1
end

local function curveAmountFor()
    local amt = S.CurveAmount
    if S.RandomCurve then
        local jitter = amt * (S.CurveRandomPct / 100)
        amt = amt + (math.random() * 2 - 1) * jitter
    end
    return math.clamp(amt, 0, 100)
end

local function takeShot(tag, power)
    local ch = myChar()
    if not ch then return false end
    local ball = getBall()
    if not ball or not ball.Parent then return false end
    local foot = footPosition(ch)
    if not foot or (ball.Position - foot).Magnitude > reachTriggerStuds() * 1.6 then return false end
    local target = shotTarget()
    if not target then return false end

    local speed = math.clamp(power * math.clamp(S.ShotSpeed, 0.2, 3), 20, 2000)
    local grav = S.LastGravity * math.clamp(S.ShotGravity, 0.1, 3)
    local dir = ballisticDirection(ball.Position, target, speed, grav)
    if not dir then
        dir = (target - ball.Position)
        if dir.Magnitude < 1e-4 then return false end
        dir = dir.Unit
    end

    local curve = (S.CurveAimbot or S.RandomCurve) and curveAmountFor() or 0
    local side = curveSideFor(ball, target)

    if HAS.shoot then
        local rem = ReplicatedStorage:FindFirstChild(CFG.ShootRemoteName, true)
        if rem and rem:IsA("RemoteEvent") then
            requestBall(tag, function() pcall(function() rem:FireServer(dir * speed, target) end) end)
            return true
        end
    end
    requestBall(tag, function() kickBall(ball, dir, speed, curve, side) end)
    return true
end

local function aimbotStep()
    if not S.Aimbot then return end
    takeShot("Shot", S.ShotPower)
end

-- Aimlock: camera stays on the ball, nothing else.
local function aimlockStep(dt)
    if not S.Aimlock then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    Camera.CFrame = cappedLook(Camera.CFrame, ball.Position, 1080, dt, 0.35)
end

-- Nero: the rising power strike. Auto fires when the ball sits in the strike
-- window; Manual is bound to a key.
local function neroWindow()
    local ch = myChar()
    if not ch then return nil end
    local ball = getBall()
    if not ball or not ball.Parent then return nil end
    local foot = footPosition(ch)
    local head = headPosition(ch)
    if not (foot and head) then return nil end
    local d = (ball.Position - foot).Magnitude
    if d > reachTriggerStuds() * 1.3 then return nil end
    if ball.Position.Y < foot.Y + 1.0 then return nil end
    if ball.Position.Y > head.Y + 6 then return nil end
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
    local curve = S.CurveAimbot and curveAmountFor() or 0
    requestBall("Nero", function() kickBall(ball, dir, S.NeroPower, curve, curveSideFor(ball, target)) end)
    return true
end

local function autoNeroStep()
    if not S.AutoNero then return end
    fireNero()
end

local function autoHeaderStep()
    if not S.AutoHeader then return end
    local ch = myChar()
    if not ch then return end
    local head = headPosition(ch)
    if not head then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    local d = (ball.Position - head).Magnitude
    if d > metresToStuds(2.2) then return end
    if ball.Position.Y < head.Y - 0.5 then return end
    local target = shotTarget()
    if not target then return end
    local dir = ballisticDirection(ball.Position, target, S.HeaderPower, S.LastGravity)
        or (target - ball.Position).Unit
    requestBall("Header", function() kickBall(ball, dir, S.HeaderPower, 0, 1) end)
end

----------------------------------------------------------------------
-- AIMPASS
----------------------------------------------------------------------

local function teammates()
    local out = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local same = plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team
            if (S.TeammatesOnly and same) or (not S.TeammatesOnly) then
                if alive(plr) then out[#out + 1] = plr end
            end
        end
    end
    return out
end

-- Best receiver: ahead of the ball, clear of the nearest opponent, closest to
-- the enemy goal. Through Balls aims at where he will be, not where he is.
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
            if d > 4 and d < metresToStuds(60) then
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

local function aimPassStep()
    if not S.AimPass then return end
    local ch = myChar()
    if not ch then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    local foot = footPosition(ch)
    if not foot or (ball.Position - foot).Magnitude > reachTriggerStuds() * 1.4 then return end

    local rec, pos = pickReceiver(ball.Position)
    if not (rec and pos) then return end

    local dist = (pos - ball.Position).Magnitude
    local span = math.max(1, metresToStuds(60))
    local power = math.clamp(S.PassMin + (S.PassMax - S.PassMin) * (dist / span), S.PassMin, S.PassMax)

    -- Lob height is capped, so a short pass stays on the deck.
    local lobCap = metresToStuds(S.LobMaxM)
    local target = pos
    local dir = ballisticDirection(ball.Position, target, power, S.LastGravity)
    if dir then
        local apex = (dir.Y * power) ^ 2 / (2 * math.max(S.LastGravity, 1))
        if apex > lobCap then
            local flat = Vector3.new(target.X - ball.Position.X, 0, target.Z - ball.Position.Z)
            if flat.Magnitude > 1e-4 then
                dir = (flat.Unit + Vector3.new(0, math.sqrt(2 * S.LastGravity * lobCap) / math.max(power, 1), 0)).Unit
            end
        end
    else
        local flat = target - ball.Position
        if flat.Magnitude < 1e-4 then return end
        dir = flat.Unit
    end

    local curve = S.CurveAimPass and curveAmountFor() or 0
    requestBall("Pass", function() kickBall(ball, dir, power, curve, curveSideFor(ball, target)) end)
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

local function diveTo(point, speedPct)
    local ch, hum, root = myChar()
    if not root or not isPlausibleVector(point) then return end
    local delta = point - root.Position
    local d = delta.Magnitude
    if d < 1 then return end
    local speed = math.clamp(speedPct, 10, 200)
    pcall(function()
        root.AssemblyLinearVelocity = delta.Unit * speed
    end)
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

    local intercept = leadPosition(ball.Position, ball.AssemblyLinearVelocity, math.min(t, 0.6), S.LastGravity)
        or point
    diveTo(intercept, S.DiveSpeed)

    -- GK touch reach: once it is inside the keeper's hands, stop it dead.
    local hands = (ch and ch:FindFirstChild("RightHand") and ch.RightHand.Position) or root.Position
    if (ball.Position - hands).Magnitude <= metresToStuds(math.min(S.GkReachM, CFG.GkReachMaxM)) then
        requestBall("Gk", function() setBallVelocity(ball, Vector3.new(0, 0, 0)) end)
    end
end

-- Panic Reach: last-ditch, widest radius, snaps the ball to the keeper.
local function panicReachStep()
    if not S.PanicReach then return end
    local ch, hum, root = myChar()
    if not root then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    local hands = (ch:FindFirstChild("RightHand") and ch.RightHand.Position) or root.Position
    if (ball.Position - hands).Magnitude > metresToStuds(S.PanicReachM) then return end
    requestBall("PanicReach", function()
        setBallVelocity(ball, Vector3.new(0, 0, 0))
        setBallCFrame(ball, hands)
    end)
end

-- Block Kick Deny Events: drops the named remotes before they leave the
-- client. Needs an executor with namecall hooking; without one it says so.
local DenyHook = { installed = false, old = nil }

local function installDenyHook()
    if DenyHook.installed then return true end
    if not (hookmetamethod and getnamecallmethod and checkcaller) then
        gateOff("Block Kick Deny Events", "an executor with hookmetamethod")
        return false
    end
    if not HAS.deny then
        gateOff("Block Kick Deny Events", "CFG.DenyEventNames")
        return false
    end
    local ok = pcall(function()
        DenyHook.old = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if not checkcaller() and S.BlockDeny
                and (method == "FireServer" or method == "InvokeServer") then
                for _, n in ipairs(CFG.DenyEventNames) do
                    if self.Name == n then return nil end
                end
            end
            return DenyHook.old(self, ...)
        end)
    end)
    DenyHook.installed = ok
    report("[TF] deny hook installed=" .. tostring(ok))
    return ok
end

----------------------------------------------------------------------
-- SPECIAL
----------------------------------------------------------------------

local function phaseTargetPlayer()
    if S.PhaseMode == "Select" then
        local p = Players:FindFirstChild(S.PhaseTargetName)
        if p and p ~= LocalPlayer then return p end
        return nil
    end
    -- Look At: whoever the camera is pointed closest to.
    local best, bestAng = nil, 0.93
    local look = Camera.CFrame.LookVector
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local ch, hum, root = alive(plr)
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

-- Anti-Phase: keep our own parts solid every frame, so a phase run by
-- somebody else on our client is undone as fast as it is applied.
local function antiPhaseStep()
    if not S.AntiPhase then return end
    local ch = myChar()
    if not ch then return end
    for _, p in ipairs(ch:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            if not p.CanCollide then p.CanCollide = true end
        end
    end
end

local function bringBall()
    local ch, hum, root = myChar()
    if not root then return end
    local ball = getBall()
    if not ball then notify("Bring ball", "Ball unresolved.", 4) return end
    local foot = footPosition(ch) or root.Position
    requestBall("Bring", function()
        setBallVelocity(ball, Vector3.new(0, 0, 0))
        setBallCFrame(ball, foot + Vector3.new(0, 1, 0))
    end)
end

local function deleteBall()
    local ball = getBall()
    if not ball then return end
    local name = ball:GetFullName()
    pcall(function() ball:Destroy() end)
    BallCache.stamp = -1
    report("[TF] ball destroyed locally: " .. name)
    notify("Delete ball", "Local only. The server still has it.", 6)
end

local function toggleFreeze()
    local ball = getBall()
    if not ball then return end
    S.BallFrozen = not S.BallFrozen
    pcall(function()
        ball.Anchored = S.BallFrozen
        if S.BallFrozen then ball.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
    end)
    notify("Ball", S.BallFrozen and "Frozen." or "Unfrozen.", 4)
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
    -- Put it on the line, then take it: one save per cycle.
    local onLine = own + Vector3.new(0, 2, 0)
    local cycle = (math.floor(os.clock() * 2) % 2 == 0)
    requestBall("SaveFarm", function()
        setBallVelocity(ball, Vector3.new(0, 0, 0))
        setBallCFrame(ball, cycle and onLine or hands)
    end)
end

-- Trick Oms: a repeating touch pattern around the body. The pattern itself is
-- our own, not a copy of any in-game animation, and the tempo is yours.
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
    if (ball.Position - foot).Magnitude > reachTriggerStuds() * 1.5 then return end
    local step = math.floor(now / interval) % 4
    local right = root.CFrame.RightVector
    local fwd = root.CFrame.LookVector
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

-- Ball Time: scale the ball's speed without changing its direction.
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

-- Frame Player: keep driving the ball onto the named player so the server
-- sees the ball living at his feet.
local function framePlayerStep()
    if not S.FramePlayer then return end
    local plr = Players:FindFirstChild(S.FrameTargetName)
    if not plr or plr == LocalPlayer then return end
    local ch, hum, root = alive(plr)
    if not root then return end
    local ball = getBall()
    if not ball or not ball.Parent then return end
    local foot = footPosition(ch) or root.Position
    requestBall("Frame", function() pullBall(ball, foot, true, 0.9) end)
end

----------------------------------------------------------------------
-- VISUALS
----------------------------------------------------------------------

local HasDrawing = (type(Drawing) == "table")
local FallbackGui = nil

local function ensureFallbackGui()
    if FallbackGui and FallbackGui.Parent then return FallbackGui end
    local sg = Instance.new("ScreenGui")
    sg.Name = "TF_VIS"
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    local parent = (gethui and gethui()) or game:GetService("CoreGui")
    local ok = pcall(function() sg.Parent = parent end)
    if not ok then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    FallbackGui = sg
    return sg
end

local function newText()
    if HasDrawing then
        local d = Drawing.new("Text")
        d.Size = 14 d.Center = true d.Outline = true d.Visible = false
        d.Color = Color3.fromRGB(255, 255, 255)
        return { kind = "draw", obj = d }
    end
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Code
    l.TextSize = 14
    l.TextStrokeTransparency = 0
    l.TextColor3 = Color3.fromRGB(255, 255, 255)
    l.Size = UDim2.fromOffset(240, 16)
    l.AnchorPoint = Vector2.new(0.5, 0.5)
    l.Visible = false
    l.Parent = ensureFallbackGui()
    return { kind = "gui", obj = l }
end

local function setText(h, str, pos, colour)
    if not h then return end
    if h.kind == "draw" then
        h.obj.Text = str
        h.obj.Position = pos
        h.obj.Color = colour
        h.obj.Visible = true
    else
        h.obj.Text = str
        h.obj.Position = UDim2.fromOffset(pos.X, pos.Y)
        h.obj.TextColor3 = colour
        h.obj.Visible = true
    end
end

local function hideHandle(h)
    if not h then return end
    h.obj.Visible = false
end

local function destroyHandle(h)
    if not h then return end
    pcall(function()
        if h.kind == "draw" then h.obj:Remove() else h.obj:Destroy() end
    end)
end

local function ballEspStep()
    if not S.BallEsp then
        hideHandle(BallDraw.dot)
        return
    end
    if not BallDraw.dot then BallDraw.dot = newText() end
    local ball, tier = getBall()
    if not ball then hideHandle(BallDraw.dot) return end
    local scr, on = worldToScreen(ball.Position)
    if not (scr and on) then hideHandle(BallDraw.dot) return end
    local _, _, root = myChar()
    local d = root and (ball.Position - root.Position).Magnitude or 0
    local sure = (tier == "confirmed" or tier == "learned")
    setText(BallDraw.dot, ("BALL %.1fm%s"):format(studsToMetres(d), sure and "" or " ?"),
        scr, sure and Color3.fromRGB(255, 190, 60) or Color3.fromRGB(255, 120, 200))
end

local function attachTrail(part, c0, c1, life)
    if not part or Trails[part] then return end
    local a0 = Instance.new("Attachment")
    a0.Name = "TF_T0"
    a0.Position = Vector3.new(0, part.Size.Y * 0.25, 0)
    a0.Parent = part
    local a1 = Instance.new("Attachment")
    a1.Name = "TF_T1"
    a1.Position = Vector3.new(0, -part.Size.Y * 0.25, 0)
    a1.Parent = part
    local tr = Instance.new("Trail")
    tr.Name = "TF_TRAIL"
    tr.Attachment0 = a0
    tr.Attachment1 = a1
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

local function ballTrailStep()
    local ball = getBall()
    if not S.BallTrail then
        if ball then detachTrail(ball) end
        return
    end
    if ball then attachTrail(ball, Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 80, 160), 0.8) end
end

local function rainbow(t)
    return Color3.fromHSV((t * 0.25) % 1, 1, 1)
end

local function rgbCharStep()
    local ch = myChar()
    if not ch then return end
    if not S.RgbChar then
        if S.RgbWasOn then
            for _, p in ipairs(ch:GetDescendants()) do
                if p:IsA("BasePart") then
                    pcall(function() p.Material = Enum.Material.Plastic end)
                end
            end
            S.RgbWasOn = false
        end
        return
    end
    S.RgbWasOn = true
    local c = rainbow(os.clock())
    for _, p in ipairs(ch:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
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
    local feet = { ch:FindFirstChild("RightFoot") or ch:FindFirstChild("Right Leg"),
                   ch:FindFirstChild("LeftFoot") or ch:FindFirstChild("Left Leg") }
    for _, f in ipairs(feet) do
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
    if math.abs(Lighting.ClockTime - S.TimeValue) > 0.01 then
        Lighting.ClockTime = S.TimeValue
    end
end

-- Spoof Marker: rewrites the text of the game's own performance labels.
-- The path to them is build-specific, so it is UNSET until you set it.
local function spoofMarkerStep()
    if not S.SpoofMarker then
        if next(MarkerSaved) then
            for lbl, txt in pairs(MarkerSaved) do
                pcall(function() if lbl.Parent then lbl.Text = txt end end)
                MarkerSaved[lbl] = nil
            end
        end
        return
    end
    if not HAS.marker then
        gateOff("Spoof Marker", "CFG.MarkerGuiPath")
        S.SpoofMarker = false
        return
    end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    local holder = pg
    for seg in string.gmatch(CFG.MarkerGuiPath, "[^%.]+") do
        holder = holder and holder:FindFirstChild(seg)
    end
    if not holder then return end
    for _, lbl in ipairs(holder:GetDescendants()) do
        if lbl:IsA("TextLabel") then
            if MarkerSaved[lbl] == nil then MarkerSaved[lbl] = lbl.Text end
            local low = string.lower(lbl.Name .. " " .. MarkerSaved[lbl])
            if string.find(low, "ping", 1, true) then
                lbl.Text = ("%d ms"):format(S.SpoofPing)
            elseif string.find(low, "cpu", 1, true) then
                lbl.Text = ("%d%%"):format(S.SpoofCpu)
            elseif string.find(low, "sent", 1, true) then
                lbl.Text = ("%d kb/s"):format(S.SpoofSent)
            end
        end
    end
end

----------------------------------------------------------------------
-- CHARACTER
----------------------------------------------------------------------

local function removeAccessories()
    local ch = myChar()
    if not ch then return end
    local n = 0
    for _, a in ipairs(ch:GetChildren()) do
        if a:IsA("Accessory") or a:IsA("Hat") then
            pcall(function() a:Destroy() end)
            n = n + 1
        end
    end
    notify("Character", ("%d accessories removed locally."):format(n), 4)
end

local function applyOwnAvatar()
    local ch, hum = myChar()
    if not hum then return end
    local ok, desc = pcall(function()
        return Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId)
    end)
    if not ok or not desc then
        notify("Character", "Could not fetch your description.", 5)
        return
    end
    local applied = pcall(function() hum:ApplyDescription(desc) end)
    report("[TF] own avatar applied=" .. tostring(applied))
    notify("Character", applied and "Your avatar applied locally." or "ApplyDescription refused on this client.", 5)
end

local function wearAsset(assetId, label)
    if not isFiniteNumber(assetId) or assetId <= 0 then
        notify("Character", ("Set a %s asset id first."):format(label), 4)
        return
    end
    local ch = myChar()
    if not ch then return end
    local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(math.floor(assetId))) end)
    if not ok or type(objs) ~= "table" or #objs == 0 then
        notify("Character", ("Asset %d would not load on this client."):format(assetId), 6)
        return
    end
    local worn = 0
    for _, obj in ipairs(objs) do
        if obj:IsA("Accessory") or obj:IsA("Hat") then
            pcall(function()
                obj.Parent = ch
                worn = worn + 1
            end)
        else
            pcall(function() obj:Destroy() end)
        end
    end
    report(("[TF] %s asset %d worn=%d (local only)"):format(label, assetId, worn))
    notify("Character", ("%s applied locally (%d part(s))."):format(label, worn), 5)
end

local function requestR6()
    if not HAS.r6 then
        gateOff("R6 Character", "CFG.R6RemoteName")
        notify("Character", "Rig type is server-owned. Set the game's rig remote in CONFIG.", 7)
        return
    end
    local rem = ReplicatedStorage:FindFirstChild(CFG.R6RemoteName, true)
    if not rem then
        notify("Character", "R6 remote not found by that name.", 5)
        return
    end
    pcall(function()
        if rem:IsA("RemoteEvent") then rem:FireServer("R6") else rem:InvokeServer("R6") end
    end)
    notify("Character", "R6 requested.", 4)
end

----------------------------------------------------------------------
-- ON-SCREEN TOGGLE BUTTONS
----------------------------------------------------------------------

local BUTTON_SPEC = {
    { label = "RCH", key = "ProReach" },
    { label = "SNK", key = "Sneaky" },
    { label = "AIM", key = "Aimbot" },
    { label = "PAS", key = "AimPass" },
    { label = "GK",  key = "AutoGk" },
    { label = "JUG", key = "AutoJuggle" },
    { label = "PHS", key = "PhaseEnemy" },
    { label = "DNK", key = "Dunk" },
}

local function destroyButtons()
    if Buttons.gui then pcall(function() Buttons.gui:Destroy() end) end
    Buttons.gui = nil
    Buttons.items = {}
end

local function buildButtons()
    destroyButtons()
    if not S.Buttons then return end
    local sg = Instance.new("ScreenGui")
    sg.Name = "TF_BUTTONS"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = false
    local parent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")
    local ok = pcall(function() sg.Parent = parent end)
    if not ok then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local holder = Instance.new("Frame")
    holder.Name = "Holder"
    holder.BackgroundTransparency = 1
    holder.Position = UDim2.new(0, 12, 0.32, 0)
    holder.Size = UDim2.fromOffset(S.ButtonSize + 8, (S.ButtonSize + 8) * #BUTTON_SPEC)
    holder.Active = true
    holder.Draggable = true
    holder.Parent = sg

    for i, spec in ipairs(BUTTON_SPEC) do
        local b = Instance.new("TextButton")
        b.Name = spec.key
        b.Size = UDim2.fromOffset(S.ButtonSize, S.ButtonSize)
        b.Position = UDim2.fromOffset(0, (i - 1) * (S.ButtonSize + 8))
        b.BackgroundColor3 = S[spec.key] and Color3.fromRGB(60, 170, 90) or Color3.fromRGB(40, 40, 46)
        b.BackgroundTransparency = 0.15
        b.BorderSizePixel = 0
        b.Text = spec.label
        b.TextColor3 = Color3.fromRGB(240, 240, 240)
        b.Font = Enum.Font.GothamBold
        b.TextSize = math.max(10, math.floor(S.ButtonSize * 0.28))
        b.AutoButtonColor = true
        b.Parent = holder
        local corner = Instance.new("UICorner")
        if S.ButtonShape == "Circle" then
            corner.CornerRadius = UDim.new(1, 0)
        elseif S.ButtonShape == "Rounded" then
            corner.CornerRadius = UDim.new(0, math.floor(S.ButtonSize * 0.22))
        else
            corner.CornerRadius = UDim.new(0, 0)
        end
        corner.Parent = b
        b.MouseButton1Click:Connect(function()
            S[spec.key] = not S[spec.key]
            b.BackgroundColor3 = S[spec.key] and Color3.fromRGB(60, 170, 90) or Color3.fromRGB(40, 40, 46)
            notify("Toggle", ("%s %s"):format(spec.label, S[spec.key] and "on" or "off"), 2)
        end)
        Buttons.items[spec.key] = b
    end
    Buttons.gui = sg
end

local function refreshButtonColours()
    for key, b in pairs(Buttons.items) do
        if b.Parent then
            b.BackgroundColor3 = S[key] and Color3.fromRGB(60, 170, 90) or Color3.fromRGB(40, 40, 46)
        end
    end
end

----------------------------------------------------------------------
-- KEYBINDS
----------------------------------------------------------------------

local BIND_ACTIONS = {
    Reach = function()
        S.ProReach = not S.ProReach
        notify("Bind", "Pro Reach " .. (S.ProReach and "on" or "off"), 2)
    end,
    Sneaky = function()
        S.Sneaky = not S.Sneaky
        notify("Bind", "Sneaky " .. (S.Sneaky and "on" or "off"), 2)
    end,
    Aimbot = function()
        S.Aimbot = not S.Aimbot
        notify("Bind", "Aimbot " .. (S.Aimbot and "on" or "off"), 2)
    end,
    AimPass = function()
        S.AimPass = not S.AimPass
        notify("Bind", "AimPass " .. (S.AimPass and "on" or "off"), 2)
    end,
    AutoGk = function()
        S.AutoGk = not S.AutoGk
        notify("Bind", "Auto GK " .. (S.AutoGk and "on" or "off"), 2)
    end,
    Phase = function()
        S.PhaseEnemy = not S.PhaseEnemy
        notify("Bind", "Phase " .. (S.PhaseEnemy and "on" or "off"), 2)
    end,
    Juggle = function()
        S.AutoJuggle = not S.AutoJuggle
        notify("Bind", "Juggle " .. (S.AutoJuggle and "on" or "off"), 2)
    end,
    Poke = function()
        S.Pokers = not S.Pokers
        notify("Bind", "Pokers " .. (S.Pokers and "on" or "off"), 2)
    end,
    Nero = function()
        local hit = fireNero()
        notify("Bind", hit and "Nero struck." or "Nero: ball not in the window.", 2)
    end,
    Dunk = function()
        S.Dunk = not S.Dunk
        notify("Bind", "Dunk " .. (S.Dunk and "on" or "off"), 2)
    end,
    BringBall = function() bringBall() end,
    Freeze = function() toggleFreeze() end,
    PanicEject = function() panicEject() end,
    LearnBall = function() learnBall() end,
}

local BIND_ORDER = {
    "Reach", "Sneaky", "Aimbot", "AimPass", "AutoGk", "Phase", "Juggle",
    "Poke", "Nero", "Dunk", "BringBall", "Freeze", "PanicEject", "LearnBall",
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
    return string.sub(n, 1, 6) == "Button" or string.sub(n, 1, 4) == "DPad"
        or string.sub(n, 1, 5) == "Thumb"
end

local function handleBindInput(code)
    if S.Binding then
        local slot = S.Binding
        S.Binding = nil
        if isGamepadKey(code) then KEYS[slot].pad = code else KEYS[slot].kb = code end
        report(("[TF] %s rebound to %s"):format(slot, code.Name))
        notify("Keybinds", ("%s = %s"):format(slot, bindLabel(slot)), 4)
        return true
    end
    for name, b in pairs(KEYS) do
        if code == b.kb or code == b.pad then
            local fn = BIND_ACTIONS[name]
            if fn then
                fn()
                refreshButtonColours()
            end
            return true
        end
    end
    return false
end

----------------------------------------------------------------------
-- DIAGNOSTICS / DISCOVERY
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
    return emit(lines, "Remotes dumped.")
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
    if loose then
        lines[#lines + 1] = ("loose %s | vel=%.1f | %s"):format(loose.Name,
            loose.AssemblyLinearVelocity.Magnitude, loose:GetFullName())
    end
    if #lines == 1 then lines[#lines + 1] = "nothing matched. Stand on the ball and press Learn ball." end
    return emit(lines, "Ball candidates printed.")
end

local function dumpGoalCandidates()
    local lines = { "=== TF GOAL CANDIDATES ===" }
    for _, p in ipairs(goalCandidates()) do
        lines[#lines + 1] = ("%s | pos=%s | size=%s | %s"):format(
            p.Name, tostring(p.Position), tostring(p.Size), p:GetFullName())
    end
    local own, enemy, tier = getGoals()
    lines[#lines + 1] = ("derived own=%s enemy=%s tier=%s"):format(
        own and tostring(own) or "none", enemy and tostring(enemy) or "none", tier)
    if #lines == 2 then lines[#lines + 1] = "nothing matched. Stand in each goal and press the learn buttons." end
    return emit(lines, "Goal candidates printed.")
end

local function dumpPlayerGui()
    local lines = { "=== TF PLAYERGUI TREE (for Spoof Marker path) ===" }
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then
        lines[#lines + 1] = "no PlayerGui"
    else
        for _, inst in ipairs(pg:GetDescendants()) do
            if inst:IsA("TextLabel") or inst:IsA("ScreenGui") or inst:IsA("Frame") then
                lines[#lines + 1] = ("%s | %s"):format(inst.ClassName, inst:GetFullName())
            end
        end
    end
    return emit(lines, "PlayerGui tree printed.")
end

local function selfTestMath()
    local g = 196.2
    local lines = { "=== TF MATH SELF TEST ===" }
    lines[#lines + 1] = ("1 m = %.4f studs, 6 m = %.2f studs"):format(STUDS_PER_M, metresToStuds(6))
    local d1 = ballisticDirection(Vector3.new(0, 0, 0), Vector3.new(100, 0, 0), 150, g)
    lines[#lines + 1] = "ballistic 100 studs @150: " .. (d1 and tostring(d1) or "nil (out of range)")
    local d2 = ballisticDirection(Vector3.new(0, 0, 0), Vector3.new(5000, 0, 0), 150, g)
    lines[#lines + 1] = "ballistic 5000 studs @150: " .. (d2 and tostring(d2) or "nil (out of range)")
    lines[#lines + 1] = ("apex 2 m needs %.2f studs/s"):format(apexVelocity(metresToStuds(2), g))
    local p, t = closestApproach(Vector3.new(0, 0, 0), Vector3.new(0, 0, -50), Vector3.new(0, 0, -100))
    lines[#lines + 1] = ("closest approach: %s at t=%.3f"):format(tostring(p), t)
    local spin = curveSpin(Vector3.new(0, 0, -1), 50, 1)
    lines[#lines + 1] = ("curve spin at 50%%: %s"):format(tostring(spin))
    local bad = leadPosition(Vector3.new(0 / 0, 0, 0), Vector3.new(0, 0, 0), 0.5, g)
    lines[#lines + 1] = "NaN input rejected: " .. tostring(bad == nil)
    local cf = cappedLook(CFrame.new(Vector3.new(0, 0, 0), Vector3.new(0, 0, -1)), Vector3.new(1, 0, 0), 90, 1 / 60, 0)
    local turned = math.deg(math.acos(math.clamp(Vector3.new(0, 0, -1):Dot(cf.LookVector), -1, 1)))
    lines[#lines + 1] = ("turn cap 90 deg/s over 1/60 s gave %.3f deg"):format(turned)
    local out = table.concat(lines, "\n")
    print(out)
    notify("Self test", "Results in console.", 6)
    return out
end

local function diagnostics()
    local ball, bTier = getBall()
    local own, enemy, gTier = getGoals()
    readPing()
    local lines = {
        ("=== TF DIAGNOSTICS %s ==="):format(VERSION),
        ("ball: %s  tier=%s"):format(ball and ball:GetFullName() or "UNRESOLVED", bTier),
        ("goals: own=%s enemy=%s tier=%s"):format(
            own and tostring(own) or "none", enemy and tostring(enemy) or "none", gTier),
        ("ownership: %s"):format(
            S.Ownership == true and "client can write the ball"
            or S.Ownership == false and "SERVER owns the ball - every ball write is reverted"
            or "not probed"),
        ("ping: %.0f ms   reach: %.2f m (%.2f studs, +%.2f m adapt)   trigger: %.2f studs"):format(
            S.Ping, reachMetres(), reachStuds(), adaptBonusM(), reachTriggerStuds()),
        ("priority: %s"):format(S.ReachPriority),
        "-- gated on UNSET config --",
        ("catch remote: %s"):format(HAS.catch and CFG.CatchRemoteName or "UNSET (physics path used)"),
        ("shoot remote: %s"):format(HAS.shoot and CFG.ShootRemoteName or "UNSET (physics path used)"),
        ("quest remote: %s"):format(HAS.quest and CFG.QuestRemoteName or "UNSET (Auto Quest off)"),
        ("respawn remote: %s"):format(HAS.respawn and CFG.RespawnRemoteName or "UNSET (health zero used)"),
        ("R6 remote: %s"):format(HAS.r6 and CFG.R6RemoteName or "UNSET (R6 unavailable)"),
        ("marker gui path: %s"):format(HAS.marker and CFG.MarkerGuiPath or "UNSET (Spoof Marker off)"),
        ("staff group: %s  names: %d"):format(HAS.staff_group and CFG.StaffGroupId or "UNSET", #CFG.StaffNames),
        ("deny events: %d  hook installed: %s"):format(#CFG.DenyEventNames, tostring(DenyHook.installed)),
        "-- watchdog --",
    }
    local any = false
    for name, e in pairs(S.Err) do
        any = true
        lines[#lines + 1] = ("%s: %d errors%s | last: %s"):format(
            name, e.n, S.Disabled[name] and " (AUTO-DISABLED)" or "", e.last)
    end
    if not any then lines[#lines + 1] = "nothing has thrown this session" end
    local out = table.concat(lines, "\n")
    print(out)
    if setclipboard then pcall(function() setclipboard(out) end) end
    notify("Diagnostics", "Report in console.", 8)
    return out
end

----------------------------------------------------------------------
-- MAIN LOOP
----------------------------------------------------------------------

local SlowLast = 0

local function frame(dt)
    S.FrameId = S.FrameId + 1
    Camera = Workspace.CurrentCamera or Camera
    local okG, g = pcall(function() return Workspace.Gravity end)
    if okG and isFiniteNumber(g) and g > 0 then S.LastGravity = g end

    -- ball writers, highest priority wins
    guard("panic_reach", panicReachStep)
    guard("goal_farm", goalFarmStep)
    guard("save_farm", saveFarmStep)
    guard("dunk", dunkStep)
    guard("gk", autoGkStep)
    guard("aimbot", aimbotStep)
    guard("ground_shot", groundShotStep)
    guard("nero", autoNeroStep)
    guard("header", autoHeaderStep)
    guard("aimpass", aimPassStep)
    guard("poke", pokersStep)
    guard("sneaky", sneakyStep)
    guard("trick", trickOmsStep)
    guard("hold", ballHoldStep)
    guard("reach", reachStep)
    guard("juggle", juggleStep)
    guard("frame_player", framePlayerStep)
    guard("ball_time", ballTimeStep)
    flushBall()

    -- non-ball work
    guard("aimlock", function() aimlockStep(dt) end)
    guard("phase", phaseStep)
    guard("anti_phase", antiPhaseStep)
    guard("ball_esp", ballEspStep)
    guard("ball_trail", ballTrailStep)
    guard("rgb", rgbCharStep)
    guard("boot_trail", bootTrailStep)
    guard("tod", timeOfDayStep)

    local now = os.clock()
    if now - SlowLast > 0.5 then
        SlowLast = now
        guard("ping", readPing)
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
    handleBindInput(input.KeyCode)
end)

Conns[#Conns + 1] = Players.PlayerRemoving:Connect(function(plr)
    local ch = plr.Character
    if ch then
        for _, p in ipairs(ch:GetDescendants()) do
            if PhaseSaved[p] ~= nil then PhaseSaved[p] = nil end
            detachTrail(p)
        end
    end
end)

Conns[#Conns + 1] = LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.6)
    OrigCollide = {}
    BallCache.stamp = -1
    GoalCache.stamp = -1
    S.RgbWasOn = false
end)

antiAfkSetup()
loadLearned()

local function teardown()
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    Conns = {}
    phaseRestore()
    detachAllTrails()
    destroyButtons()
    destroyHandle(BallDraw.dot)
    BallDraw.dot = nil
    for lbl, txt in pairs(MarkerSaved) do
        pcall(function() if lbl.Parent then lbl.Text = txt end end)
        MarkerSaved[lbl] = nil
    end
    local ch = myChar()
    if ch then
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") then pcall(function() p.Material = Enum.Material.Plastic end) end
        end
    end
    if FallbackGui then pcall(function() FallbackGui:Destroy() end) FallbackGui = nil end
    local ball = getBall()
    if ball and S.BallFrozen then pcall(function() ball.Anchored = false end) end
    print(("[TF %s] unloaded."):format(VERSION))
end

----------------------------------------------------------------------
-- RAYFIELD UI  (spec-driven: one builder, ten tabs)
----------------------------------------------------------------------

local okFetch, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not okFetch or type(Rayfield) ~= "table" then
    print(("[TF %s] Rayfield fetch failed. Features are live, UI is not."):format(VERSION))
    getgenv().TF = { S = S, KEYS = KEYS, teardown = teardown, diag = diagnostics,
        learnBall = learnBall, learnGoal = learnGoal, probe = probeOwnership, hop = hopServer }
    return
end

local Window = Rayfield:CreateWindow({
    Name = ("Touch Football %s"):format(VERSION),
    Icon = 0,
    LoadingTitle = ("Touch Football %s"):format(VERSION),
    LoadingSubtitle = "olliE",
    Theme = "Default",
    ConfigurationSaving = { Enabled = true, FolderName = "TouchFootball", FileName = "tf_v3" },
    Discord = { Enabled = false, Invite = "", RememberJoins = false },
    KeySystem = false,
})

-- spec kinds: p paragraph, t toggle, s slider, d dropdown, b button, i input
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
                    refreshButtonColours()
                end,
            })
        elseif e.kind == "s" then
            tab:CreateSlider({
                Name = e.name, Range = e.range, Increment = e.step, Suffix = e.suffix or "",
                CurrentValue = e.current, Flag = e.flag or e.key,
                Callback = function(v)
                    if e.scale then v = v * e.scale end
                    S[e.key] = v
                    if e.after then e.after(v) end
                end,
            })
        elseif e.kind == "d" then
            tab:CreateDropdown({
                Name = e.name, Options = e.options, CurrentOption = { e.current },
                MultipleOptions = false, Flag = e.flag or e.key,
                Callback = function(opt)
                    local pick = (type(opt) == "table") and opt[1] or opt
                    S[e.key] = pick
                    if e.after then e.after(pick) end
                end,
            })
        elseif e.kind == "b" then
            tab:CreateButton({ Name = e.name, Callback = e.run })
        elseif e.kind == "i" then
            tab:CreateInput({
                Name = e.name, CurrentValue = e.current or "", PlaceholderText = e.hint or "",
                RemoveTextAfterFocusLost = e.clear and true or false, Flag = e.flag,
                Callback = e.run,
            })
        end
    end
end

local TabSettings = Window:CreateTab("SETTINGS", 0)
build(TabSettings, {
    { kind = "t", name = "Anti-AFK", key = "AntiAfk" },
    { kind = "t", name = "Notifications", key = "Notifications" },
    { kind = "t", name = "Auto Best Server (hops when your ping is over the limit)", key = "AutoBestServer" },
    { kind = "s", name = "Ping limit", key = "HopMaxPing", range = { 40, 400 }, step = 10, suffix = " ms", current = 120 },
    { kind = "b", name = "Hop Server (lowest ping)", run = function() hopServer(S.HopMaxPing) end },
    { kind = "b", name = "Rejoin this server", run = doRejoin },
    { kind = "t", name = "Panic Staff (auto-leave)", key = "PanicStaff" },
    { kind = "t", name = "Auto Complete Quest", key = "AutoQuest" },
    { kind = "b", name = "Force Respawn", run = forceRespawn },
    { kind = "b", name = "Panic Eject (all assists off)", run = panicEject },
    { kind = "t", name = "On-screen toggle buttons", key = "Buttons", after = function() buildButtons() end },
    { kind = "s", name = "Button size", key = "ButtonSize", range = { 32, 110 }, step = 2, suffix = " px",
      current = 56, after = function() buildButtons() end },
    { kind = "d", name = "Button shape", key = "ButtonShape", options = { "Circle", "Rounded", "Square" },
      current = "Circle", after = function() buildButtons() end },
})

local TabReach = Window:CreateTab("REACH", 0)
build(TabReach, {
    { kind = "p", title = "Profiles", text = ("Pro Reach is the natural profile: velocity pulls only, and the trigger widens with the ball's closing speed. Control Reach is the easy profile: larger radius and direct placement. Both are in metres; 1 stud = 0.28 m, so %.2f m = %.2f studs."):format(CFG.ReachMaxM, metresToStuds(CFG.ReachMaxM)) },
    { kind = "t", name = "Pro Reach (Natural)", key = "ProReach" },
    { kind = "t", name = "Control Reach (Easier)", key = "ControlReach" },
    { kind = "s", name = "Reach", key = "ReachM", range = { 0.5, CFG.ReachMaxM }, step = 0.1, suffix = " m", current = 3.0 },
    { kind = "s", name = "Control Reach radius", key = "ControlReachM", range = { 0.5, CFG.ReachMaxM }, step = 0.1, suffix = " m", current = 4.5 },
    { kind = "s", name = "Pull power", key = "ReachPower", range = { 5, 100 }, step = 5, suffix = " %", current = 55, scale = 0.01 },
    { kind = "d", name = "Reach Priority (wins the frame)", key = "ReachPriority",
      options = { "Reach", "Hold", "Gk", "Shot", "Pass", "Juggle", "Poke", "Sneaky" }, current = "Reach" },
    { kind = "t", name = "Ball Hold (keep it at your feet)", key = "BallHold" },
    { kind = "s", name = "Hold offset ahead", key = "HoldOffsetM", range = { 0.2, 3 }, step = 0.1, suffix = " m", current = 0.9 },
    { kind = "t", name = "Adapt High MS (reach boost + trigger range)", key = "AdaptHighMs" },
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
    { kind = "b", name = "Reset juggle counter", run = function() S.JuggleTaps = 0 end },
})

local TabAim = Window:CreateTab("AIMBOT", 0)
build(TabAim, {
    { kind = "p", title = "Targeting", text = "Shots solve a low-arc trajectory to the enemy goal against live gravity, then apply spin for curve. Goal identity comes from the goal resolver: learned positions beat derived ones, and DISCOVERY shows which is in use." },
    { kind = "t", name = "Aimbot (shoot at goal)", key = "Aimbot" },
    { kind = "t", name = "Aimlock (camera to ball)", key = "Aimlock" },
    { kind = "t", name = "Curve Aimbot", key = "CurveAimbot" },
    { kind = "t", name = "Auto Adapt Curve", key = "AutoAdaptCurve" },
    { kind = "t", name = "Random Curve", key = "RandomCurve" },
    { kind = "t", name = "Top Corner Mode", key = "TopCorner" },
    { kind = "t", name = "Auto Detect Goal", key = "AutoDetectGoal", after = function() GoalCache.stamp = -1 end },
    { kind = "s", name = "Power", key = "ShotPower", range = { 40, 800 }, step = 10, suffix = "", current = 170 },
    { kind = "s", name = "Speed multiplier", key = "ShotSpeed", range = { 20, 300 }, step = 5, suffix = " %", current = 100, scale = 0.01 },
    { kind = "s", name = "Gravity multiplier", key = "ShotGravity", range = { 10, 300 }, step = 5, suffix = " %", current = 100, scale = 0.01 },
    { kind = "s", name = "Curve amount", key = "CurveAmount", range = { 0, 100 }, step = 5, suffix = " %", current = 35 },
    { kind = "s", name = "Random curve spread", key = "CurveRandomPct", range = { 0, 100 }, step = 5, suffix = " %", current = 20 },
    { kind = "s", name = "Miss chance", key = "MissChance", range = { 0, 100 }, step = 1, suffix = " %", current = 0 },
    { kind = "t", name = "Auto Nero", key = "AutoNero" },
    { kind = "s", name = "Nero power", key = "NeroPower", range = { 60, 900 }, step = 10, suffix = "", current = 210 },
    { kind = "b", name = "Manual Nero (also bound to a key)", run = function()
        local hit = fireNero()
        notify("Nero", hit and "Struck." or "Ball not in the strike window.", 3)
    end },
    { kind = "t", name = "Auto Header", key = "AutoHeader" },
    { kind = "s", name = "Header power", key = "HeaderPower", range = { 40, 600 }, step = 10, suffix = "", current = 150 },
})

local TabPass = Window:CreateTab("AIMPASS", 0)
build(TabPass, {
    { kind = "p", title = "Receiver choice", text = "The receiver is scored on distance from the ball, distance to the enemy goal and how much space he has from the nearest opponent. Through Balls aims where he will be in 0.6 s instead of where he stands." },
    { kind = "t", name = "AimPass", key = "AimPass" },
    { kind = "t", name = "Teammates Only", key = "TeammatesOnly" },
    { kind = "t", name = "Through Balls", key = "ThroughBalls" },
    { kind = "t", name = "Curve AimPass", key = "CurveAimPass" },
    { kind = "s", name = "Min pass power", key = "PassMin", range = { 20, 400 }, step = 10, suffix = "", current = 90 },
    { kind = "s", name = "Max pass power", key = "PassMax", range = { 40, 800 }, step = 10, suffix = "", current = 220 },
    { kind = "s", name = "Max lob height", key = "LobMaxM", range = { 0.5, 20 }, step = 0.5, suffix = " m", current = 8.0 },
})

local TabGk = Window:CreateTab("GOALKEEPER", 0)
build(TabGk, {
    { kind = "p", title = "Interception", text = "A shot counts as a threat when the ball is moving toward your own goal above 4 studs/s. The dive goes to the closest approach point on that path, led by up to 0.6 s. Air saves are Auto GK, ground saves are Auto GS." },
    { kind = "t", name = "Auto GK (air saves)", key = "AutoGk" },
    { kind = "t", name = "Auto GS (ground saves)", key = "AutoGs" },
    { kind = "s", name = "Dive speed", key = "DiveSpeed", range = { 20, 200 }, step = 5, suffix = " studs/s", current = 90 },
    { kind = "s", name = "GK touch reach", key = "GkReachM", range = { 1, CFG.GkReachMaxM }, step = 0.25, suffix = " m", current = 6.0 },
    { kind = "t", name = "Panic Reach", key = "PanicReach" },
    { kind = "s", name = "Panic Reach radius", key = "PanicReachM", range = { 2, 20 }, step = 0.5, suffix = " m", current = 9.0 },
    { kind = "t", name = "Block Kick Deny Events", key = "BlockDeny", after = function(v)
        if v then installDenyHook() end
    end },
})

local TabSpecial = Window:CreateTab("SPECIAL", 0)
build(TabSpecial, {
    { kind = "t", name = "Phase Enemy", key = "PhaseEnemy", after = function(v) if not v then phaseRestore() end end },
    { kind = "d", name = "Phase mode", key = "PhaseMode", options = { "Look At", "Select" }, current = "Look At" },
    { kind = "i", name = "Phase target (Select mode)", hint = "exact player name", flag = "phase_target",
      run = function(txt) S.PhaseTargetName = txt or "" end },
    { kind = "t", name = "Anti-Phase", key = "AntiPhase" },
    { kind = "t", name = "Goal Farm", key = "GoalFarm" },
    { kind = "t", name = "Save Farm", key = "SaveFarm" },
    { kind = "t", name = "Dunk (auto score near goal)", key = "Dunk" },
    { kind = "s", name = "Dunk range", key = "DunkRangeM", range = { 2, 40 }, step = 1, suffix = " m", current = 12.0 },
    { kind = "t", name = "Trick Oms", key = "TrickOms" },
    { kind = "s", name = "Trick tempo", key = "TrickTempo", range = { 0.3, 10 }, step = 0.1, suffix = " /s", current = 3.0 },
    { kind = "t", name = "Ball Time (speed)", key = "BallTime" },
    { kind = "s", name = "Ball Time multiplier", key = "BallTimeMul", range = { 10, 300 }, step = 5, suffix = " %", current = 100, scale = 0.01 },
    { kind = "t", name = "Frame Player", key = "FramePlayer" },
    { kind = "i", name = "Frame target", hint = "exact player name", flag = "frame_target",
      run = function(txt) S.FrameTargetName = txt or "" end },
    { kind = "b", name = "Bring Ball", run = bringBall },
    { kind = "b", name = "Delete Ball (local)", run = deleteBall },
    { kind = "b", name = "Freeze / Unfreeze Ball", run = toggleFreeze },
})

local TabVis = Window:CreateTab("VISUALS", 0)
build(TabVis, {
    { kind = "t", name = "Ball ESP", key = "BallEsp" },
    { kind = "t", name = "Ball Trail", key = "BallTrail", after = function(v)
        if not v then local b = getBall() if b then detachTrail(b) end end
    end },
    { kind = "t", name = "RGB Character (Neon)", key = "RgbChar" },
    { kind = "t", name = "Rainbow Boot Trail", key = "BootTrail" },
    { kind = "t", name = "Time of Day", key = "TimeOfDay" },
    { kind = "s", name = "Clock time", key = "TimeValue", range = { 0, 24 }, step = 0.5, suffix = " h", current = 14 },
    { kind = "t", name = "Spoof Marker", key = "SpoofMarker" },
    { kind = "s", name = "Spoof ping", key = "SpoofPing", range = { 5, 300 }, step = 1, suffix = " ms", current = 42 },
    { kind = "s", name = "Spoof CPU", key = "SpoofCpu", range = { 1, 99 }, step = 1, suffix = " %", current = 3 },
    { kind = "s", name = "Spoof sent", key = "SpoofSent", range = { 1, 200 }, step = 1, suffix = " kb/s", current = 12 },
    { kind = "p", title = "Renderer", text = HasDrawing and "Drawing API detected." or "No Drawing API: ball label uses a ScreenGui." },
})

local TabChar = Window:CreateTab("CHARACTER", 0)
build(TabChar, {
    { kind = "p", title = "Scope", text = "Avatar, hats and hair apply on your client. Rig type is owned by the server, so R6 only works through the game's own rig remote, set in CONFIG." },
    { kind = "b", name = "R6 Character (needs the rig remote)", run = requestR6 },
    { kind = "b", name = "Use Own Avatar", run = applyOwnAvatar },
    { kind = "i", name = "Hat asset id", hint = "numbers only", flag = "hat_id",
      run = function(txt) S.HatAssetId = tonumber(txt) or 0 end },
    { kind = "b", name = "Wear hat", run = function() wearAsset(S.HatAssetId, "Hat") end },
    { kind = "i", name = "Hair asset id", hint = "numbers only", flag = "hair_id",
      run = function(txt) S.HairAssetId = tonumber(txt) or 0 end },
    { kind = "b", name = "Wear hair", run = function() wearAsset(S.HairAssetId, "Hair") end },
    { kind = "b", name = "Remove All Accessories", run = removeAccessories },
})

local TabKeys = Window:CreateTab("KEYBINDS", 0)
TabKeys:CreateParagraph({
    Title = "Rebinding",
    Content = "Press a bind button, then press any key or controller button. Keyboard keys go to the keyboard slot, controller buttons to the controller slot. Defaults: Reach R/R1, Sneaky X/L1, Aimbot T/Y, AimPass G/X, Auto GK V/B, Phase F/L3.",
})
local bindButtons = {}
for _, name in ipairs(BIND_ORDER) do
    local btn
    btn = TabKeys:CreateButton({
        Name = ("%s  [%s]"):format(name, bindLabel(name)),
        Callback = function()
            S.Binding = name
            notify("Keybinds", ("Press a key for %s"):format(name), 5)
            task.spawn(function()
                local t0 = os.clock()
                while S.Binding == name and os.clock() - t0 < 8 do task.wait(0.1) end
                if S.Binding == name then
                    S.Binding = nil
                    notify("Keybinds", "Rebind timed out.", 3)
                end
                pcall(function()
                    bindButtons[name]:Set(("%s  [%s]"):format(name, bindLabel(name)))
                end)
            end)
        end,
    })
    bindButtons[name] = btn
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
    { kind = "p", title = "Start here when a feature does nothing", text = "Probe ball ownership first. If the server owns the ball, every ball write in this script is being reverted, which is one cause and not twenty broken features. Then read Diagnostics for the gated list." },
    { kind = "b", name = "Probe ball ownership", run = function() probeOwnership() end },
    { kind = "b", name = "Diagnostics report", run = function() diagnostics() end },
    { kind = "b", name = "Learn ball from feet", run = function() learnBall() end },
    { kind = "b", name = "Learn OWN goal (stand in it)", run = function() learnGoal("own") end },
    { kind = "b", name = "Learn ENEMY goal (stand in it)", run = function() learnGoal("enemy") end },
    { kind = "b", name = "Forget learned ball and goals", run = function()
        Learned.ball_name, Learned.ball_path = "", ""
        Learned.goal_own, Learned.goal_enemy = nil, nil
        HAS.learned_ball, HAS.learned_goals = false, false
        BallCache.stamp, GoalCache.stamp = -1, -1
        saveLearned()
        notify("Learn", "Cleared.", 4)
    end },
    { kind = "b", name = "Dump remotes", run = dumpRemotes },
    { kind = "b", name = "Scan ball candidates", run = dumpBallCandidates },
    { kind = "b", name = "Scan goal candidates", run = dumpGoalCandidates },
    { kind = "b", name = "Dump PlayerGui (Spoof Marker path)", run = dumpPlayerGui },
    { kind = "b", name = "Run math self test", run = selfTestMath },
    { kind = "b", name = "Re-arm watchdog-disabled features", run = function()
        local n = 0
        for name in pairs(S.Disabled) do S.Disabled[name] = nil n = n + 1 end
        S.Err = {}
        notify("Watchdog", ("%d re-armed."):format(n), 4)
    end },
})

local TabCfg = Window:CreateTab("CONFIG", 0)
build(TabCfg, {
    { kind = "p", title = "Gated values", text = "Each field below is UNSET until you fill it and gates exactly one feature. Nothing here is guessed for you." },
    { kind = "i", name = "Ball Instance name", current = CFG.BallNameOverride, hint = "exact name", flag = "cfg_ball",
      run = function(t) CFG.BallNameOverride = t or "" HAS.ball_name = CFG.BallNameOverride ~= "" BallCache.stamp = -1 end },
    { kind = "i", name = "Ball parent (workspace child)", current = CFG.BallParentOverride, hint = "blank = whole workspace", flag = "cfg_ballparent",
      run = function(t) CFG.BallParentOverride = t or "" HAS.ball_parent = CFG.BallParentOverride ~= "" BallCache.stamp = -1 end },
    { kind = "i", name = "Catch RemoteEvent", current = CFG.CatchRemoteName, hint = "blank = physics path", flag = "cfg_catch",
      run = function(t) CFG.CatchRemoteName = t or "" HAS.catch = CFG.CatchRemoteName ~= "" S.Notices = {} end },
    { kind = "i", name = "Shoot/Pass RemoteEvent", current = CFG.ShootRemoteName, hint = "blank = physics path", flag = "cfg_shoot",
      run = function(t) CFG.ShootRemoteName = t or "" HAS.shoot = CFG.ShootRemoteName ~= "" S.Notices = {} end },
    { kind = "i", name = "Quest remote", current = CFG.QuestRemoteName, hint = "gates Auto Complete Quest", flag = "cfg_quest",
      run = function(t) CFG.QuestRemoteName = t or "" HAS.quest = CFG.QuestRemoteName ~= "" S.Notices = {} end },
    { kind = "i", name = "Respawn remote", current = CFG.RespawnRemoteName, hint = "blank = zero health", flag = "cfg_respawn",
      run = function(t) CFG.RespawnRemoteName = t or "" HAS.respawn = CFG.RespawnRemoteName ~= "" end },
    { kind = "i", name = "R6 rig remote", current = CFG.R6RemoteName, hint = "gates R6 Character", flag = "cfg_r6",
      run = function(t) CFG.R6RemoteName = t or "" HAS.r6 = CFG.R6RemoteName ~= "" end },
    { kind = "i", name = "Marker GUI path under PlayerGui", current = CFG.MarkerGuiPath, hint = "e.g. HUD.Stats.Frame", flag = "cfg_marker",
      run = function(t) CFG.MarkerGuiPath = t or "" HAS.marker = CFG.MarkerGuiPath ~= "" S.Notices = {} end },
    { kind = "i", name = "Staff group id", current = tostring(CFG.StaffGroupId), hint = "numbers only", flag = "cfg_group",
      run = function(t) CFG.StaffGroupId = tonumber(t) or 0 HAS.staff_group = CFG.StaffGroupId > 0 end },
    { kind = "i", name = "Staff min rank", current = tostring(CFG.StaffMinRank), hint = "numbers only", flag = "cfg_rank",
      run = function(t) CFG.StaffMinRank = tonumber(t) or 100 end },
    { kind = "i", name = "Add staff name", hint = "one name, then enter", clear = true, flag = "cfg_staffname",
      run = function(t)
          if t and t ~= "" then
              CFG.StaffNames[#CFG.StaffNames + 1] = t
              notify("Config", ("Staff list: %d"):format(#CFG.StaffNames), 4)
          end
      end },
    { kind = "i", name = "Add deny event name", hint = "remote name to block", clear = true, flag = "cfg_deny",
      run = function(t)
          if t and t ~= "" then
              CFG.DenyEventNames[#CFG.DenyEventNames + 1] = t
              HAS.deny = true
              notify("Config", ("Deny list: %d"):format(#CFG.DenyEventNames), 4)
          end
      end },
    { kind = "i", name = "Add ball name pattern", hint = "lowercase substring", clear = true, flag = "cfg_pattern",
      run = function(t)
          if t and t ~= "" then
              CFG.BallPatterns[#CFG.BallPatterns + 1] = string.lower(t)
              BallCache.stamp = -1
          end
      end },
    { kind = "i", name = "Add goal name pattern", hint = "lowercase substring", clear = true, flag = "cfg_goalpattern",
      run = function(t)
          if t and t ~= "" then
              CFG.GoalPatterns[#CFG.GoalPatterns + 1] = string.lower(t)
              GoalCache.stamp = -1
          end
      end },
    { kind = "b", name = "Unload everything", run = function()
        teardown()
        pcall(function() Rayfield:Destroy() end)
    end },
})

Rayfield:LoadConfiguration()
buildButtons()

getgenv().TF = {
    S = S, CFG = CFG, KEYS = KEYS, teardown = teardown, diag = diagnostics,
    learnBall = learnBall, learnGoal = learnGoal, probe = probeOwnership,
    hop = hopServer, rejoin = doRejoin, panic = panicEject,
    math = { lead = leadPosition, ballistic = ballisticDirection, apex = apexVelocity,
             spin = curveSpin, closest = closestApproach, look = cappedLook },
}

notify("Touch Football", ("%s loaded. INSERT toggles the menu."):format(VERSION), 5)
