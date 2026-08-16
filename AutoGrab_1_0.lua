-- Auto Grab 1.0 — Standalone auto-grab logic extracted from Crate Hub
-- V1 (Normal) mode only. Clean, minimal, self-contained.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- ============================================================
-- CONFIG
-- ============================================================
local Config = {
    Enabled = false,
    Radius = 60,
    Duration = 1.0,
    AutoRadius = false,
    NormalSpeed = 60,
    BarWidth = 300,
}

-- ============================================================
-- STATE
-- ============================================================
local State = {
    isStealing = false,
    stealStartTime = 0,
    stealConn = nil,
    progressConn = nil,
    animalCache = {},
    promptCache = {},
    stealCache = {},
    statusGui = nil,
    statusFill = nil,
    statusPctLbl = nil,
    statusRadiusLbl = nil,
    statusFpsLbl = nil,
    statusMain = nil,
    _fpsValue = 0,
    _statusInfoWatch = false,
    _persistentConns = {},
}

-- ============================================================
-- FIREPROXIMITYPROMPT POLYFILL
-- ============================================================
if not fireproximityprompt then
    fireproximityprompt = (getgenv and getgenv().fireproximityprompt)
        or (genv and genv().fireproximityprompt)
        or function(prompt)
            pcall(function()
                prompt:InputHoldBegin()
                task.wait(0.05)
                prompt:InputHoldEnd()
            end)
        end
end

-- ============================================================
-- RADIUS
-- ============================================================
local function getAutoRadius()
    local radius = math.clamp((tonumber(Config.NormalSpeed) or 60) + 1, 1, 500)
    return math.floor(radius * 10 + 0.5) / 10
end

local function getActiveRadius()
    return Config.AutoRadius and getAutoRadius() or Config.Radius
end

-- ============================================================
-- PING
-- ============================================================
local function getPingMs()
    local ok, ms = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and type(ms) == "number" and ms > 0 then return ms end
    return nil
end

-- ============================================================
-- STATUS BAR UI
-- ============================================================
local ACCENT = Color3.fromRGB(255, 255, 255)
local BG_DARK = Color3.fromRGB(11, 5, 8)
local TRACK_BG = Color3.fromRGB(52, 29, 40)

local function updateProgress(progress, label)
    progress = math.clamp(progress or 0, 0, 1)
    local pct = math.floor(progress * 100 + 0.5)
    if State.statusFill then
        State.statusFill.Size = UDim2.fromScale(progress, 1)
        State.statusFill.BackgroundColor3 = ACCENT
    end
    if State.statusPctLbl then
        if type(label) == "string" and label ~= "" then
            State.statusPctLbl.Text = label
        elseif progress > 0 then
            State.statusPctLbl.Text = pct .. "%"
        else
            State.statusPctLbl.Text = Config.Enabled and "READY" or "IDLE"
        end
    end
end

local function updateRadiusDisplay()
    if State.statusRadiusLbl then
        State.statusRadiusLbl.Text = "Radius: " .. tostring(getActiveRadius())
    end
end

local function buildStatusUI()
    if State.statusGui then
        pcall(function() State.statusGui:Destroy() end)
        State.statusGui = nil
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "AutoGrabStatusUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 5

    do
        local ok = false
        if gethui then
            ok = pcall(function() gui.Parent = gethui() end)
        elseif syn and syn.protect_gui then
            ok = pcall(function()
                syn.protect_gui(gui)
                gui.Parent = game:GetService("CoreGui")
            end)
        end
        if not ok then
            gui.Parent = player:WaitForChild("PlayerGui")
        end
    end

    for _, v in ipairs(gui.Parent:GetChildren()) do
        if v ~= gui and v:IsA("ScreenGui") and v.Name == gui.Name then
            pcall(function() v:Destroy() end)
        end
    end

    local barW = math.clamp(tonumber(Config.BarWidth) or 300, 240, 600)

    local frame = Instance.new("Frame")
    frame.Name = "GrabBar"
    frame.Size = UDim2.new(0, barW, 0, 62)
    frame.Position = UDim2.new(0.5, -math.floor(barW / 2), 0.68, 0)
    frame.BackgroundColor3 = BG_DARK
    frame.BackgroundTransparency = 0.12
    frame.BorderSizePixel = 0
    frame.Active = false
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)

    local stroke = Instance.new("UIStroke")
    stroke.Color = ACCENT
    stroke.Thickness = 1.2
    stroke.Transparency = 0.72
    stroke.Parent = frame

    local pctLbl = Instance.new("TextLabel")
    pctLbl.Name = "StatusLabel"
    pctLbl.Size = UDim2.new(0.4, 0, 0, 18)
    pctLbl.Position = UDim2.new(0, 22, 0, 9)
    pctLbl.BackgroundTransparency = 1
    pctLbl.Text = "IDLE"
    pctLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    pctLbl.TextSize = 14
    pctLbl.Font = Enum.Font.GothamBold
    pctLbl.TextXAlignment = Enum.TextXAlignment.Left
    pctLbl.TextTruncate = Enum.TextTruncate.AtEnd
    pctLbl.Parent = frame
    State.statusPctLbl = pctLbl

    local radiusLbl = Instance.new("TextLabel")
    radiusLbl.Name = "RadiusLbl"
    radiusLbl.AnchorPoint = Vector2.new(1, 0)
    radiusLbl.Size = UDim2.new(0.5, 0, 0, 18)
    radiusLbl.Position = UDim2.new(1, -22, 0, 9)
    radiusLbl.BackgroundTransparency = 1
    radiusLbl.Text = "Radius: " .. tostring(getActiveRadius())
    radiusLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    radiusLbl.TextSize = 13
    radiusLbl.Font = Enum.Font.GothamBold
    radiusLbl.TextXAlignment = Enum.TextXAlignment.Right
    radiusLbl.Parent = frame
    State.statusRadiusLbl = radiusLbl

    local infoLbl = Instance.new("TextLabel")
    infoLbl.Name = "InfoLbl"
    infoLbl.Size = UDim2.new(1, -20, 0, 14)
    infoLbl.Position = UDim2.new(0, 10, 0, 27)
    infoLbl.BackgroundTransparency = 1
    infoLbl.Text = "FPS: -- PING: --ms"
    infoLbl.TextColor3 = Color3.fromRGB(228, 228, 235)
    infoLbl.TextSize = 11
    infoLbl.Font = Enum.Font.GothamMedium
    infoLbl.TextXAlignment = Enum.TextXAlignment.Center
    infoLbl.TextTruncate = Enum.TextTruncate.AtEnd
    infoLbl.Parent = frame
    State.statusFpsLbl = infoLbl

    local barBg = Instance.new("Frame")
    barBg.Name = "Track"
    barBg.Size = UDim2.new(1, -44, 0, 14)
    barBg.Position = UDim2.new(0, 22, 1, -20)
    barBg.BackgroundColor3 = TRACK_BG
    barBg.BackgroundTransparency = 0.25
    barBg.BorderSizePixel = 0
    barBg.ClipsDescendants = true
    barBg.Parent = frame
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)

    local barStroke = Instance.new("UIStroke")
    barStroke.Color = ACCENT
    barStroke.Thickness = 1
    barStroke.Transparency = 0.75
    barStroke.Parent = barBg

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = ACCENT
    fill.BackgroundTransparency = 0
    fill.BorderSizePixel = 0
    fill.Parent = barBg
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    State.statusFill = fill

    State.statusGui = gui
    State.statusMain = frame
end

-- FPS / ping readout
local function startStatusInfoWatch()
    if State._statusInfoWatch then return end
    State._statusInfoWatch = true
    task.spawn(function()
        local frames, last = 0, tick()
        local conn = RunService.RenderStepped:Connect(function()
            frames = frames + 1
            local now = tick()
            if now - last >= 1 then
                State._fpsValue = math.floor(frames / (now - last) + 0.5)
                frames, last = 0, now
            end
        end)
        table.insert(State._persistentConns, conn)
        while State._statusInfoWatch do
            task.wait(1)
            local lbl = State.statusFpsLbl
            if lbl and lbl.Parent then
                local ms = getPingMs()
                lbl.Text = string.format("FPS: %d  PING: %sms",
                    State._fpsValue,
                    ms and tostring(math.floor(ms + 0.5)) or "--")
            end
        end
    end)
end

-- ============================================================
-- PLOT / ANIMAL SCANNING
-- ============================================================
local function isMyPlot(plotName)
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return false end
    local plot = plots:FindFirstChild(plotName)
    if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yb = sign:FindFirstChild("YourBase")
        if yb and yb:IsA("BillboardGui") then return yb.Enabled == true end
    end
    return false
end

local function scanPlot(plot)
    if not plot or not plot:IsA("Model") then return end
    if isMyPlot(plot.Name) then return end
    local podiums = plot:FindFirstChild("AnimalPodiums")
    if not podiums then return end
    for _, pod in ipairs(podiums:GetChildren()) do
        if pod:IsA("Model") and pod:FindFirstChild("Base") then
            local uid = plot.Name .. "_" .. pod.Name
            for _, ex in ipairs(State.animalCache) do
                if ex.uid == uid then return end
            end
            table.insert(State.animalCache, {
                name = pod.Name,
                plot = plot.Name,
                slot = pod.Name,
                worldPosition = pod:GetPivot().Position,
                uid = uid,
            })
        end
    end
end

local function scanAllPlots()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return end
    State.animalCache = {}
    for _, plot in ipairs(plots:GetChildren()) do
        scanPlot(plot)
    end
end

-- ============================================================
-- PROMPT FINDING
-- ============================================================
local function findPrompt(ad)
    if not ad then return nil end
    local cp = State.promptCache[ad.uid]
    if cp and cp.Parent then return cp end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    local plot = plots:FindFirstChild(ad.plot)
    if not plot then return nil end
    local pods = plot:FindFirstChild("AnimalPodiums")
    if not pods then return nil end
    local pod = pods:FindFirstChild(ad.slot)
    if not pod then return nil end
    local base = pod:FindFirstChild("Base")
    if not base then return nil end
    local spawn = base:FindFirstChild("Spawn")
    if not spawn then return nil end
    local att = spawn:FindFirstChild("PromptAttachment")
    local prompt = nil
    if att then
        for _, p in ipairs(att:GetChildren()) do
            if p:IsA("ProximityPrompt") then prompt = p; break end
        end
    end
    if not prompt then
        for _, obj in ipairs(spawn:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then prompt = obj; break end
        end
    end
    if prompt then State.promptCache[ad.uid] = prompt end
    return prompt
end

-- ============================================================
-- NEAREST ANIMAL
-- ============================================================
local function nearestAnimal()
    local char = player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
    if not hrp then return nil end
    local best, bestD = nil, math.huge
    for _, ad in ipairs(State.animalCache) do
        if not isMyPlot(ad.plot) and ad.worldPosition then
            local d = (hrp.Position - ad.worldPosition).Magnitude
            if d < bestD then bestD = d; best = ad end
        end
    end
    return best, bestD
end

-- ============================================================
-- CALLBACK BUILDER & EXECUTOR
-- ============================================================
local function buildCallbacks(prompt)
    if State.stealCache[prompt] then return end
    local data = { holdCallbacks = {}, triggerCallbacks = {}, ready = true }
    local ok1, c1 = pcall(getconnections, prompt.PromptButtonHoldBegan)
    if ok1 and type(c1) == "table" then
        for _, conn in ipairs(c1) do
            if type(conn.Function) == "function" then
                table.insert(data.holdCallbacks, conn.Function)
            end
        end
    end
    local ok2, c2 = pcall(getconnections, prompt.Triggered)
    if ok2 and type(c2) == "table" then
        for _, conn in ipairs(c2) do
            if type(conn.Function) == "function" then
                table.insert(data.triggerCallbacks, conn.Function)
            end
        end
    end
    if #data.holdCallbacks > 0 or #data.triggerCallbacks > 0 then
        State.stealCache[prompt] = data
    end
end

local function execGrab(prompt, animalName)
    local data = State.stealCache[prompt]
    if not data or not data.ready then return false end
    data.ready = false
    State.isStealing = true
    State.stealStartTime = tick()
    updateProgress(0.1)

    if State.progressConn then State.progressConn:Disconnect() end
    State.progressConn = RunService.Heartbeat:Connect(function()
        if not State.isStealing then
            State.progressConn:Disconnect()
            State.progressConn = nil
            return
        end
        local prog = math.clamp((tick() - State.stealStartTime) / Config.Duration, 0, 1)
        updateProgress(prog)
    end)

    task.spawn(function()
        for _, fn in ipairs(data.holdCallbacks) do task.spawn(fn) end
        local elapsed = 0
        while elapsed < Config.Duration do elapsed = elapsed + task.wait() end
        for _, fn in ipairs(data.triggerCallbacks) do task.spawn(fn) end
        task.wait(0.01)
        if State.progressConn then State.progressConn:Disconnect(); State.progressConn = nil end
        State.isStealing = false
        updateProgress(0)
        data.ready = true
    end)
    return true
end

-- ============================================================
-- AUTO GRAB LOOP (V1 / Normal)
-- ============================================================
local function startAutoGrab()
    if State.stealConn then return end
    scanAllPlots()
    if State.statusGui then State.statusGui.Enabled = true end
    State.stealConn = RunService.Heartbeat:Connect(function()
        if not Config.Enabled or State.isStealing then return end
        local target, dist = nearestAnimal()
        if not target then return end
        if dist > getActiveRadius() then return end
        local prompt = State.promptCache[target.uid]
        if not prompt or not prompt.Parent then
            prompt = findPrompt(target)
        end
        if prompt then
            buildCallbacks(prompt)
            execGrab(prompt, target.name)
        end
    end)
end

local function stopAutoGrab()
    if State.stealConn then
        State.stealConn:Disconnect()
        State.stealConn = nil
    end
    State.isStealing = false
    if State.progressConn then State.progressConn:Disconnect(); State.progressConn = nil end
    updateProgress(0)
end

-- ============================================================
-- PUBLIC API
-- ============================================================
local AutoGrab = {}

function AutoGrab.SetEnabled(enabled)
    Config.Enabled = enabled
    if enabled then
        startAutoGrab()
    else
        stopAutoGrab()
    end
end

function AutoGrab.SetRadius(radius)
    Config.Radius = math.clamp(tonumber(radius) or 60, 1, 500)
    updateRadiusDisplay()
end

function AutoGrab.SetDuration(duration)
    Config.Duration = math.max(tonumber(duration) or 1.4, 0.05)
end

function AutoGrab.SetAutoRadius(enabled)
    Config.AutoRadius = enabled
    updateRadiusDisplay()
end

function AutoGrab.SetBarWidth(width)
    Config.BarWidth = math.clamp(tonumber(width) or 300, 240, 600)
    buildStatusUI()
    startStatusInfoWatch()
end

function AutoGrab.RescanPlots()
    scanAllPlots()
end

function AutoGrab.IsGrabbing()
    return State.isStealing
end

function AutoGrab.GetConfig()
    return Config
end

function AutoGrab.Destroy()
    stopAutoGrab()
    State._statusInfoWatch = false
    for _, conn in ipairs(State._persistentConns) do
        pcall(function() conn:Disconnect() end)
    end
    State._persistentConns = {}
    if State.statusGui then
        pcall(function() State.statusGui:Destroy() end)
        State.statusGui = nil
    end
end

-- ============================================================
-- INIT
-- ============================================================
buildStatusUI()
startStatusInfoWatch()
updateProgress(0)

-- Rescan when new plots appear
pcall(function()
    local plots = workspace:WaitForChild("Plots", 10)
    if plots then
        plots.ChildAdded:Connect(function(child)
            task.wait(0.5)
            scanPlot(child)
        end)
    end
end)

-- Expose globally
_G.AutoGrab = AutoGrab

return AutoGrab
