--[[
    VOID ANTI TP-BAT v2 – Neon Edition (Fixed)
    No bat needed. Detects TP-bat attackers → voids them for ~3s.
    Uses walkfling (collision-based) instead of direct fling.
    Self-protection: user never gets respawned.
    Toggle: click or press V
]]

-- ============================================================
--  SERVICES
-- ============================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local LP               = Players.LocalPlayer

-- ============================================================
--  CONFIG
-- ============================================================
local CONFIG = {
    DETECT_RANGE       = 40,
    VOID_Y             = -3500,
    FLING_FORCE        = 14000,
    WALKFLING_DURATION = 0.6,
    VOID_DURATION      = 3,
    VOID_PUSH_VEL      = -6000,
    RECHECK_INTERVAL   = 0.15,
    MAX_VOID_ATTEMPTS  = 6,
    SIM_RADIUS         = 9e9,
    KEYBIND            = Enum.KeyCode.V,
}

local VOID_FRAMES     = math.floor(CONFIG.VOID_DURATION * 60)
local WALKFLING_FRAMES = math.floor(CONFIG.WALKFLING_DURATION * 60)

-- ============================================================
--  STATE
-- ============================================================
local enabled          = false
local mainConn         = nil
local selfProtectConn  = nil
local voidAttempts     = {}
local voidedPlayers    = {}
local activeVoids      = 0
local myHRP, myHum, myChar
local safeCFrame       = nil

-- ============================================================
--  CHARACTER SETUP
-- ============================================================
local function setupChar(char)
    myChar = char
    myHRP  = char and char:WaitForChild("HumanoidRootPart", 5)
    myHum  = char and char:WaitForChild("Humanoid", 5)
    if myHRP and myHRP.Position.Y > -100 then
        safeCFrame = myHRP.CFrame
    end
end

LP.CharacterAdded:Connect(function(c)
    task.wait(0.15)
    setupChar(c)
end)
if LP.Character then task.spawn(function() setupChar(LP.Character) end) end

Players.PlayerRemoving:Connect(function(p)
    voidAttempts[p]  = nil
    voidedPlayers[p] = nil
end)

-- ============================================================
--  SELF PROTECTION – keeps user at surface, never in void
-- ============================================================
local function snapSelfBack()
    if not myHRP or not safeCFrame then return end
    pcall(function()
        myHRP.CFrame = safeCFrame
        myHRP.AssemblyLinearVelocity  = Vector3.zero
        myHRP.AssemblyAngularVelocity = Vector3.zero
    end)
    pcall(function()
        if myHum then
            myHum.Health        = myHum.MaxHealth
            myHum.PlatformStand = false
            myHum.AutoRotate    = true
        end
    end)
end

local function startSelfProtect()
    if selfProtectConn then return end
    selfProtectConn = RunService.Heartbeat:Connect(function()
        if not enabled or not myHRP or not myChar then return end
        if activeVoids == 0 and myHRP.Position.Y > -100 then
            safeCFrame = myHRP.CFrame
        end
        if myHRP.Position.Y < -100 then
            snapSelfBack()
        end
    end)
end

local function stopSelfProtect()
    if selfProtectConn then selfProtectConn:Disconnect(); selfProtectConn = nil end
end

-- ============================================================
--  EXPAND SIMULATION RADIUS
-- ============================================================
local function expandSimRadius()
    pcall(function()
        if setsimulationradius then
            setsimulationradius(CONFIG.SIM_RADIUS)
        end
    end)
    pcall(function()
        if sethiddenproperty and LP then
            sethiddenproperty(LP, "SimulationRadius", CONFIG.SIM_RADIUS)
            sethiddenproperty(LP, "MaximumSimulationRadius", CONFIG.SIM_RADIUS)
        end
    end)
end

-- ============================================================
--  CLAIM / RELEASE PHYSICS REP
-- ============================================================
local function claimPhysicsRep(targetHRP)
    pcall(function()
        if sethiddenproperty and myHRP then
            sethiddenproperty(myHRP, "PhysicsRepRootPart", targetHRP)
        end
    end)
end

local function releasePhysicsRep()
    pcall(function()
        if sethiddenproperty and myHRP then
            sethiddenproperty(myHRP, "PhysicsRepRootPart", myHRP)
        end
    end)
end

-- ============================================================
--  STRIP PARTS – disable target's movement
-- ============================================================
local function stripChar(char)
    if not char then return end
    pcall(function()
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed     = 0
            hum.JumpPower     = 0
            hum.JumpHeight    = 0
            hum.AutoRotate    = false
            hum.PlatformStand = true
        end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
                part.Anchored  = false
            end
        end
    end)
end

-- ============================================================
--  SUSTAINED VOID PUSH – keeps target in void for 3 seconds
-- ============================================================
local function sustainedVoidPush(targetHRP, targetChar)
    for i = 1, VOID_FRAMES do
        if not targetHRP or not targetHRP.Parent then break end
        pcall(function()
            stripChar(targetChar)
            local voidY = CONFIG.VOID_Y - (i * 50)
            targetHRP.CFrame = CFrame.new(targetHRP.Position.X, voidY, targetHRP.Position.Z)
            targetHRP.AssemblyLinearVelocity  = Vector3.new(0, CONFIG.VOID_PUSH_VEL, 0)
            targetHRP.AssemblyAngularVelocity = Vector3.zero
            for _, part in ipairs(targetChar:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CFrame = CFrame.new(part.Position.X, voidY, part.Position.Z)
                    part.AssemblyLinearVelocity = Vector3.new(0, CONFIG.VOID_PUSH_VEL, 0)
                end
            end
        end)
        if myHRP and safeCFrame and myHRP.Position.Y < -100 then
            snapSelfBack()
        end
        RunService.Heartbeat:Wait()
    end
end

-- ============================================================
--  VOID METHODS
-- ============================================================

-- Method 1: PhysicsRep + sustained CFrame slam (3s)
local function voidViaPhysicsRep(targetHRP)
    if not myHRP or not targetHRP then return end
    local targetChar = targetHRP.Parent

    claimPhysicsRep(targetHRP)
    expandSimRadius()

    task.spawn(function()
        activeVoids = activeVoids + 1
        sustainedVoidPush(targetHRP, targetChar)
        releasePhysicsRep()
        snapSelfBack()
        activeVoids = activeVoids - 1
    end)
end

-- Method 2: Direct CFrame + Velocity (no PhysicsRep, 3s)
local function voidViaDirect(targetHRP)
    if not targetHRP then return end
    local targetChar = targetHRP.Parent

    task.spawn(function()
        activeVoids = activeVoids + 1
        sustainedVoidPush(targetHRP, targetChar)
        activeVoids = activeVoids - 1
    end)
end

-- Method 3: Re-claim physics rep each frame + slam (3s)
local function voidViaDrag(targetHRP)
    if not myHRP or not targetHRP then return end
    local targetChar = targetHRP.Parent

    expandSimRadius()

    task.spawn(function()
        activeVoids = activeVoids + 1
        for i = 1, VOID_FRAMES do
            if not targetHRP or not targetHRP.Parent then break end
            pcall(function()
                claimPhysicsRep(targetHRP)
                stripChar(targetChar)
                local voidY = CONFIG.VOID_Y - (i * 50)
                targetHRP.CFrame = CFrame.new(targetHRP.Position.X, voidY, targetHRP.Position.Z)
                targetHRP.AssemblyLinearVelocity = Vector3.new(
                    math.random(-60, 60),
                    CONFIG.VOID_PUSH_VEL,
                    math.random(-60, 60)
                )
            end)
            if myHRP and safeCFrame and myHRP.Position.Y < -100 then
                snapSelfBack()
            end
            RunService.Heartbeat:Wait()
        end
        releasePhysicsRep()
        snapSelfBack()
        activeVoids = activeVoids - 1
    end)
end

-- Method 4: WALKFLING – spin own character into target via collision, then void (3s)
local function walkFlingPlayer(targetHRP)
    if not myHRP or not targetHRP then return end
    local targetChar = targetHRP.Parent
    local preFlingCFrame = safeCFrame or myHRP.CFrame

    expandSimRadius()
    claimPhysicsRep(targetHRP)

    task.spawn(function()
        activeVoids = activeVoids + 1

        -- Phase 1: Walkfling – spin ourselves and ram into target
        stripChar(targetChar)
        for i = 1, WALKFLING_FRAMES do
            if not targetHRP or not targetHRP.Parent then break end
            if not myHRP or not myHRP.Parent then break end
            pcall(function()
                local targetPos = targetHRP.Position
                myHRP.CFrame = CFrame.new(targetPos + Vector3.new(
                    math.random(-3, 3), 0, math.random(-3, 3)
                ))
                myHRP.AssemblyAngularVelocity = Vector3.new(
                    CONFIG.FLING_FORCE,
                    CONFIG.FLING_FORCE,
                    CONFIG.FLING_FORCE
                )
                myHRP.AssemblyLinearVelocity = Vector3.new(
                    math.random(-300, 300), 0, math.random(-300, 300)
                )
            end)
            RunService.Heartbeat:Wait()
        end

        -- Snap back to safe position immediately after walkfling phase
        pcall(function()
            if myHRP then
                myHRP.CFrame = preFlingCFrame
                myHRP.AssemblyLinearVelocity  = Vector3.zero
                myHRP.AssemblyAngularVelocity = Vector3.zero
            end
            if myHum then
                myHum.PlatformStand = false
                myHum.AutoRotate    = true
                myHum.Health        = myHum.MaxHealth
            end
        end)

        -- Phase 2: Sustained void push for 3 seconds
        sustainedVoidPush(targetHRP, targetChar)

        releasePhysicsRep()
        snapSelfBack()
        activeVoids = activeVoids - 1
    end)
end

-- Method 5: All-parts scatter void (last resort, 3s)
local function scatterVoid(targetChar)
    if not targetChar then return end
    task.spawn(function()
        activeVoids = activeVoids + 1
        for i = 1, VOID_FRAMES do
            if not targetChar.Parent then break end
            pcall(function()
                for _, part in ipairs(targetChar:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                        part.Anchored  = false
                        part.CFrame    = CFrame.new(
                            math.random(-500, 500),
                            CONFIG.VOID_Y - (i * 50),
                            math.random(-500, 500)
                        )
                        part.AssemblyLinearVelocity = Vector3.new(0, CONFIG.VOID_PUSH_VEL, 0)
                    end
                end
            end)
            if myHRP and safeCFrame and myHRP.Position.Y < -100 then
                snapSelfBack()
            end
            RunService.Heartbeat:Wait()
        end
        activeVoids = activeVoids - 1
    end)
end

-- ============================================================
--  COMBINED VOID PIPELINE
-- ============================================================
local function voidTarget(player)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local attempts = (voidAttempts[player] or 0) + 1
    voidAttempts[player] = attempts

    stripChar(char)

    if attempts <= 2 then
        voidViaPhysicsRep(hrp)
    elseif attempts <= 4 then
        voidViaDrag(hrp)
    elseif attempts <= CONFIG.MAX_VOID_ATTEMPTS then
        voidViaDirect(hrp)
    elseif attempts <= CONFIG.MAX_VOID_ATTEMPTS + 2 then
        walkFlingPlayer(hrp)
    else
        scatterVoid(char)
        voidAttempts[player] = 0
    end

    voidedPlayers[player] = tick()
end

-- ============================================================
--  MAIN LOOP – Detect & Counter
-- ============================================================
local function getAttackers()
    local attackers = {}
    if not myHRP then return attackers end
    local myPos = myHRP.Position

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (myPos - hrp.Position).Magnitude
                if dist <= CONFIG.DETECT_RANGE then
                    table.insert(attackers, { player = p, dist = dist, hrp = hrp })
                end
            end
        end
    end

    table.sort(attackers, function(a, b) return a.dist < b.dist end)
    return attackers
end

local function mainLoop()
    mainConn = RunService.Heartbeat:Connect(function()
        if not enabled then return end
        if not myHRP or not myChar then return end

        expandSimRadius()

        local attackers = getAttackers()

        for _, attacker in ipairs(attackers) do
            local p = attacker.player

            if voidedPlayers[p] and (tick() - voidedPlayers[p]) < CONFIG.RECHECK_INTERVAL then
                pcall(function()
                    if attacker.hrp and attacker.hrp.Parent then
                        attacker.hrp.AssemblyLinearVelocity = Vector3.new(0, CONFIG.VOID_PUSH_VEL, 0)
                    end
                end)
            else
                voidTarget(p)
            end
        end
    end)
end

local function startAntiTPBat()
    if mainConn then return end
    enabled = true
    voidAttempts  = {}
    voidedPlayers = {}
    activeVoids   = 0
    if LP.Character then setupChar(LP.Character) end
    expandSimRadius()
    startSelfProtect()
    mainLoop()
end

local function stopAntiTPBat()
    enabled = false
    if mainConn then mainConn:Disconnect(); mainConn = nil end
    stopSelfProtect()
    voidAttempts  = {}
    voidedPlayers = {}
    activeVoids   = 0
    pcall(function()
        if myHRP then
            myHRP.AssemblyLinearVelocity  = Vector3.zero
            myHRP.AssemblyAngularVelocity = Vector3.zero
        end
        if myHum then
            myHum.AutoRotate    = true
            myHum.PlatformStand = false
        end
        releasePhysicsRep()
    end)
end

-- ============================================================
--  NEON PALETTE
-- ============================================================
local C = {
    CYAN    = Color3.fromRGB(0, 255, 255),
    MAGENTA = Color3.fromRGB(255, 0, 200),
    PURPLE  = Color3.fromRGB(150, 0, 255),
    GREEN   = Color3.fromRGB(0, 255, 120),
    RED     = Color3.fromRGB(255, 40, 80),
    BG      = Color3.fromRGB(8, 8, 18),
    BAR     = Color3.fromRGB(12, 12, 28),
    PANEL   = Color3.fromRGB(16, 16, 35),
    DIM     = Color3.fromRGB(140, 140, 180),
}

-- ============================================================
--  GUI
-- ============================================================
local function getGuiParent()
    if typeof(gethui) == "function" then
        local ok, r = pcall(gethui)
        if ok and r then return r end
    end
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then return core end
    return LP:WaitForChild("PlayerGui")
end

local guiParent = getGuiParent()
local existing  = guiParent:FindFirstChild("VoidAntiTPBatGui")
if existing then existing:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name              = "VoidAntiTPBatGui"
gui.ResetOnSpawn      = false
gui.IgnoreGuiInset    = false
gui.ZIndexBehavior    = Enum.ZIndexBehavior.Global

if type(syn) == "table" and type(syn.protect_gui) == "function" then
    pcall(syn.protect_gui, gui)
elseif typeof(protectgui) == "function" then
    pcall(protectgui, gui)
end

pcall(function() gui.Parent = guiParent end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

-- Main Frame
local frame = Instance.new("Frame")
frame.Name             = "Main"
frame.Active           = true
frame.BackgroundColor3 = C.BG
frame.BorderSizePixel  = 0
frame.ClipsDescendants = true
frame.Position         = UDim2.new(0.5, -150, 0, 80)
frame.Size             = UDim2.new(0, 300, 0, 125)
frame.Parent           = gui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 14)
    mainCorner.Parent = frame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    mainStroke.Color           = C.CYAN
    mainStroke.Thickness       = 2
    mainStroke.Parent          = frame

    local strokeGrad = Instance.new("UIGradient")
    strokeGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, C.CYAN),
        ColorSequenceKeypoint.new(0.5, C.MAGENTA),
        ColorSequenceKeypoint.new(1, C.PURPLE),
    }
    strokeGrad.Rotation = 135
    strokeGrad.Parent   = mainStroke

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Name             = "TitleBar"
titleBar.Active           = true
titleBar.BackgroundColor3 = C.BAR
titleBar.BorderSizePixel  = 0
titleBar.Size             = UDim2.new(1, 0, 0, 42)
titleBar.Parent           = frame

    local tbCorner = Instance.new("UICorner")
    tbCorner.CornerRadius = UDim.new(0, 14)
    tbCorner.Parent = titleBar

    local tbFill = Instance.new("Frame")
    tbFill.BackgroundColor3 = C.BAR
    tbFill.BorderSizePixel  = 0
    tbFill.Position         = UDim2.new(0, 0, 0, 28)
    tbFill.Size             = UDim2.new(1, 0, 0, 14)
    tbFill.Parent           = titleBar

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position         = UDim2.new(0, 14, 0, 0)
    titleLabel.Size             = UDim2.new(1, -60, 1, 0)
    titleLabel.Font             = Enum.Font.GothamBlack
    titleLabel.Text             = "VOID ANTI TP-BAT v2"
    titleLabel.TextColor3       = C.CYAN
    titleLabel.TextSize         = 13
    titleLabel.TextXAlignment   = Enum.TextXAlignment.Left
    titleLabel.TextYAlignment   = Enum.TextYAlignment.Center
    titleLabel.Parent           = titleBar

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.BackgroundColor3   = Color3.fromRGB(30, 30, 50)
    closeBtn.BorderSizePixel    = 0
    closeBtn.Position           = UDim2.new(1, -36, 0.5, -13)
    closeBtn.Size               = UDim2.new(0, 26, 0, 26)
    closeBtn.ZIndex             = 2
    closeBtn.AutoButtonColor    = false
    closeBtn.Font               = Enum.Font.GothamBlack
    closeBtn.Text               = "X"
    closeBtn.TextColor3         = C.RED
    closeBtn.TextSize           = 14
    closeBtn.Parent             = titleBar

        Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

        local closeBtnStroke = Instance.new("UIStroke")
        closeBtnStroke.Color        = C.RED
        closeBtnStroke.Thickness    = 1
        closeBtnStroke.Transparency = 0.5
        closeBtnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
        closeBtnStroke.Parent       = closeBtn

-- Divider (neon gradient line)
local divider = Instance.new("Frame")
divider.BackgroundColor3 = Color3.new(1,1,1)
divider.BorderSizePixel  = 0
divider.Position         = UDim2.new(0, 0, 0, 42)
divider.Size             = UDim2.new(1, 0, 0, 1)
divider.Parent           = frame

    local divGrad = Instance.new("UIGradient")
    divGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, C.CYAN),
        ColorSequenceKeypoint.new(0.5, C.MAGENTA),
        ColorSequenceKeypoint.new(1, C.PURPLE),
    }
    divGrad.Parent = divider

-- Content area
local content = Instance.new("Frame")
content.BackgroundTransparency = 1
content.BorderSizePixel  = 0
content.Position         = UDim2.new(0, 0, 0, 43)
content.Size             = UDim2.new(1, 0, 1, -43)
content.Parent           = frame

    -- Inner panel
    local panel = Instance.new("Frame")
    panel.BackgroundColor3 = C.PANEL
    panel.BorderSizePixel  = 0
    panel.Position         = UDim2.new(0, 8, 0.5, -24)
    panel.Size             = UDim2.new(1, -16, 0, 48)
    panel.Parent           = content

        Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

        local panelStroke = Instance.new("UIStroke")
        panelStroke.Color        = C.PURPLE
        panelStroke.Thickness    = 1
        panelStroke.Transparency = 0.4
        panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
        panelStroke.Parent       = panel

        -- Keybind badge
        local keyBadge = Instance.new("TextButton")
        keyBadge.BackgroundColor3 = Color3.fromRGB(20, 20, 45)
        keyBadge.BorderSizePixel  = 0
        keyBadge.Position         = UDim2.new(0, 6, 0.5, -14)
        keyBadge.Size             = UDim2.new(0, 28, 0, 28)
        keyBadge.ZIndex           = 2
        keyBadge.AutoButtonColor  = false
        keyBadge.Font             = Enum.Font.GothamBlack
        keyBadge.Text             = "V"
        keyBadge.TextColor3       = C.MAGENTA
        keyBadge.TextSize         = 11
        keyBadge.Parent           = panel

            Instance.new("UICorner", keyBadge).CornerRadius = UDim.new(0, 6)
            local keyStroke = Instance.new("UIStroke")
            keyStroke.Color        = C.MAGENTA
            keyStroke.Thickness    = 1
            keyStroke.Transparency = 0.3
            keyStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
            keyStroke.Parent       = keyBadge

        -- Status label
        local statusLabel = Instance.new("TextLabel")
        statusLabel.BackgroundTransparency = 1
        statusLabel.Position       = UDim2.new(0, 42, 0, 0)
        statusLabel.Size           = UDim2.new(1, -130, 1, 0)
        statusLabel.Font           = Enum.Font.GothamBlack
        statusLabel.Text           = "VOID : OFF"
        statusLabel.TextColor3     = C.DIM
        statusLabel.TextSize       = 13
        statusLabel.TextXAlignment = Enum.TextXAlignment.Left
        statusLabel.TextYAlignment = Enum.TextYAlignment.Center
        statusLabel.Parent         = panel

        -- Toggle track
        local track = Instance.new("Frame")
        track.BackgroundColor3 = Color3.fromRGB(40, 40, 65)
        track.BorderSizePixel  = 0
        track.Position         = UDim2.new(1, -54, 0.5, -12)
        track.Size             = UDim2.new(0, 46, 0, 24)
        track.ZIndex           = 2
        track.Parent           = panel

            Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

            local trackStroke = Instance.new("UIStroke")
            trackStroke.Color        = C.PURPLE
            trackStroke.Thickness    = 1
            trackStroke.Transparency = 0.4
            trackStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
            trackStroke.Parent       = track

            -- Knob
            local knob = Instance.new("Frame")
            knob.BackgroundColor3 = C.DIM
            knob.BorderSizePixel  = 0
            knob.Position         = UDim2.new(0, 3, 0.5, -9)
            knob.Size             = UDim2.new(0, 18, 0, 18)
            knob.ZIndex           = 3
            knob.Parent           = track

                Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

            -- Invisible click target
            local toggleBtn = Instance.new("TextButton")
            toggleBtn.BackgroundTransparency = 1
            toggleBtn.BorderSizePixel = 0
            toggleBtn.Size            = UDim2.new(1, 0, 1, 0)
            toggleBtn.ZIndex          = 4
            toggleBtn.AutoButtonColor = false
            toggleBtn.Text            = ""
            toggleBtn.Parent          = track

-- ============================================================
--  TOGGLE WIRING
-- ============================================================
local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local OFF_TRACK = Color3.fromRGB(40, 40, 65)
local ON_TRACK  = C.CYAN
local OFF_KNOB  = C.DIM
local ON_KNOB   = Color3.fromRGB(255, 255, 255)
local OFF_POS   = UDim2.new(0, 3, 0.5, -9)
local ON_POS    = UDim2.new(0, 25, 0.5, -9)

local isToggled = false

local function setToggle(state)
    isToggled = state

    TweenService:Create(knob, tweenInfo, {
        Position         = state and ON_POS or OFF_POS,
        BackgroundColor3 = state and ON_KNOB or OFF_KNOB,
    }):Play()

    TweenService:Create(track, tweenInfo, {
        BackgroundColor3 = state and ON_TRACK or OFF_TRACK,
    }):Play()

    TweenService:Create(trackStroke, tweenInfo, {
        Color        = state and C.CYAN or C.PURPLE,
        Transparency = state and 0 or 0.4,
    }):Play()

    statusLabel.Text       = state and "VOID : ON" or "VOID : OFF"
    statusLabel.TextColor3 = state and C.GREEN or C.DIM

    if state then
        startAntiTPBat()
    else
        stopAntiTPBat()
    end
end

local function flipToggle()
    setToggle(not isToggled)
end

toggleBtn.MouseButton1Click:Connect(flipToggle)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == CONFIG.KEYBIND then flipToggle() end
end)

-- ============================================================
--  CLOSE BUTTON
-- ============================================================
closeBtn.MouseButton1Click:Connect(function()
    stopAntiTPBat()
    gui:Destroy()
end)

closeBtn.MouseEnter:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = C.RED,
        TextColor3       = Color3.new(1,1,1),
    }):Play()
    TweenService:Create(closeBtnStroke, TweenInfo.new(0.15), {
        Transparency = 0,
    }):Play()
end)

closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(30, 30, 50),
        TextColor3       = C.RED,
    }):Play()
    TweenService:Create(closeBtnStroke, TweenInfo.new(0.15), {
        Transparency = 0.5,
    }):Play()
end)

-- ============================================================
--  DRAGGING
-- ============================================================
local dragging  = false
local dragStart, startPos

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging  = true
        dragStart = input.Position
        startPos  = frame.Position
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

-- ============================================================
print("VOID ANTI TP-BAT v2 loaded - walkfling + 3s void, press V or click toggle.")
