local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "British Railway",
    Icon = 0,
    LoadingTitle = "British Railway Hub",
    LoadingSubtitle = "by Ritmada",
    Theme = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "BritishRailwayHub",
        FileName = "config"
    },
    KeySystem = false,
})

-- services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local lp = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

-- state
local noclipEnabled = false
local speedEnabled = false
local speedValue = 16
local espEnabled = false
local freecamEnabled = false
local freecamSpeed = 1
local espObjects = {}

-- refresh char refs on respawn
lp.CharacterAdded:Connect(function(newChar)
    char = newChar
    hrp = char:WaitForChild("HumanoidRootPart")
    humanoid = char:WaitForChild("Humanoid")
end)

-------------------------------------------------------------------
-- PLAYER TAB
-------------------------------------------------------------------
local PlayerTab = Window:CreateTab("Player", 0)

PlayerTab:CreateSlider({
    Name = "Walk Speed",
    Range = {16, 200},
    Increment = 1,
    Suffix = "speed",
    CurrentValue = 16,
    Flag = "WalkSpeed",
    Callback = function(val)
        speedValue = val
        if speedEnabled then
            humanoid.WalkSpeed = val
        end
    end,
})

PlayerTab:CreateToggle({
    Name = "Speed Enabled",
    CurrentValue = false,
    Flag = "SpeedToggle",
    Callback = function(val)
        speedEnabled = val
        if val then
            humanoid.WalkSpeed = speedValue
        else
            humanoid.WalkSpeed = 16
        end
    end,
})

PlayerTab:CreateSlider({
    Name = "Jump Power",
    Range = {50, 300},
    Increment = 5,
    Suffix = "power",
    CurrentValue = 50,
    Flag = "JumpPower",
    Callback = function(val)
        humanoid.JumpPower = val
    end,
})

PlayerTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Flag = "NoclipToggle",
    Callback = function(val)
        noclipEnabled = val
    end,
})

RunService.Stepped:Connect(function()
    if noclipEnabled and char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

PlayerTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Flag = "InfJump",
    Callback = function(val)
        if val then
            _G.InfJump = true
            UserInputService.JumpRequest:Connect(function()
                if _G.InfJump then
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
        else
            _G.InfJump = false
        end
    end,
})

-------------------------------------------------------------------
-- TELEPORT TAB
-------------------------------------------------------------------
local TeleportTab = Window:CreateTab("Teleport", 0)

local function getStations()
    local stations = {}
    -- scan workspace for station models/parts
    for _, obj in pairs(Workspace:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("Part")) and
           (obj.Name:lower():find("station") or obj.Name:lower():find("platform") or obj.Name:lower():find("depot")) then
            if not table.find(stations, obj.Name) then
                table.insert(stations, obj.Name)
            end
        end
    end
    table.sort(stations)
    if #stations == 0 then
        table.insert(stations, "No stations found")
    end
    return stations
end

local selectedStation = nil

TeleportTab:CreateDropdown({
    Name = "Select Station",
    Options = getStations(),
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "StationSelect",
    Callback = function(opt)
        selectedStation = opt
    end,
})

TeleportTab:CreateButton({
    Name = "Teleport to Station",
    Callback = function()
        if not selectedStation or selectedStation == "No stations found" then
            Rayfield:Notify({Title = "Teleport", Content = "pick a station first", Duration = 3})
            return
        end
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj.Name == selectedStation then
                local pos
                if obj:IsA("Model") and obj.PrimaryPart then
                    pos = obj.PrimaryPart.Position
                elseif obj:IsA("Model") then
                    pos = obj:GetBoundingBox().Position
                elseif obj:IsA("BasePart") then
                    pos = obj.Position
                end
                if pos then
                    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
                    Rayfield:Notify({Title = "Teleport", Content = "sent to " .. selectedStation, Duration = 3})
                    break
                end
            end
        end
    end,
})

TeleportTab:CreateButton({
    Name = "Teleport to Nearest Train",
    Callback = function()
        local closest = nil
        local closestDist = math.huge
        for _, obj in pairs(Workspace:GetDescendants()) do
            if (obj:IsA("Model") or obj:IsA("Part")) and
               (obj.Name:lower():find("train") or obj.Name:lower():find("loco") or
                obj.Name:lower():find("carriage") or obj.Name:lower():find("cab") or
                obj.Name:lower():find("class")) then
                local pos
                if obj:IsA("Model") and obj.PrimaryPart then
                    pos = obj.PrimaryPart.Position
                elseif obj:IsA("BasePart") then
                    pos = obj.Position
                end
                if pos then
                    local dist = (pos - hrp.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closest = pos
                    end
                end
            end
        end
        if closest then
            hrp.CFrame = CFrame.new(closest + Vector3.new(0, 5, 0))
            Rayfield:Notify({Title = "Teleport", Content = "sent to nearest train", Duration = 3})
        else
            Rayfield:Notify({Title = "Teleport", Content = "no trains found", Duration = 3})
        end
    end,
})

TeleportTab:CreateButton({
    Name = "Refresh Station List",
    Callback = function()
        Rayfield:Notify({Title = "Stations", Content = "re-open menu to see updated list", Duration = 3})
    end,
})

-------------------------------------------------------------------
-- ESP TAB
-------------------------------------------------------------------
local ESPTab = Window:CreateTab("ESP", 0)

local function clearESP()
    for _, v in pairs(espObjects) do
        if v and v.Parent then v:Destroy() end
    end
    espObjects = {}
end

local function createHighlight(target, color, label)
    local highlight = Instance.new("Highlight")
    highlight.Adornee = target
    highlight.FillColor = color
    highlight.FillTransparency = 0.7
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0
    highlight.Parent = target
    table.insert(espObjects, highlight)

    if label then
        local bb = Instance.new("BillboardGui")
        bb.Adornee = target:IsA("Model") and (target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")) or target
        bb.Size = UDim2.new(0, 200, 0, 30)
        bb.StudsOffset = Vector3.new(0, 4, 0)
        bb.AlwaysOnTop = true
        bb.Parent = target

        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(1, 0, 1, 0)
        tl.BackgroundTransparency = 1
        tl.Text = label
        tl.TextColor3 = color
        tl.TextStrokeTransparency = 0.5
        tl.TextScaled = true
        tl.Font = Enum.Font.GothamBold
        tl.Parent = bb

        table.insert(espObjects, bb)
    end
end

local function runESP()
    clearESP()
    if not espEnabled then return end

    for _, obj in pairs(Workspace:GetDescendants()) do
        local name = obj.Name:lower()
        -- stations
        if (obj:IsA("Model") or obj:IsA("Part")) and (name:find("station") or name:find("platform")) then
            createHighlight(obj, Color3.fromRGB(0, 170, 255), obj.Name)
        end
        -- trains
        if (obj:IsA("Model") or obj:IsA("Part")) and
           (name:find("train") or name:find("loco") or name:find("class") or name:find("cab")) then
            createHighlight(obj, Color3.fromRGB(255, 85, 0), obj.Name)
        end
        -- signals
        if (obj:IsA("Model") or obj:IsA("Part")) and (name:find("signal")) then
            createHighlight(obj, Color3.fromRGB(255, 255, 0), "Signal")
        end
    end
end

ESPTab:CreateToggle({
    Name = "ESP (Stations / Trains / Signals)",
    CurrentValue = false,
    Flag = "ESPToggle",
    Callback = function(val)
        espEnabled = val
        runESP()
    end,
})

ESPTab:CreateButton({
    Name = "Refresh ESP",
    Callback = function()
        runESP()
    end,
})

-------------------------------------------------------------------
-- FREECAM TAB
-------------------------------------------------------------------
local FreecamTab = Window:CreateTab("Freecam", 0)

FreecamTab:CreateSlider({
    Name = "Freecam Speed",
    Range = {1, 10},
    Increment = 1,
    Suffix = "x",
    CurrentValue = 1,
    Flag = "FreecamSpeed",
    Callback = function(val)
        freecamSpeed = val
    end,
})

FreecamTab:CreateToggle({
    Name = "Freecam",
    CurrentValue = false,
    Flag = "FreecamToggle",
    Callback = function(val)
        freecamEnabled = val
        local cam = Workspace.CurrentCamera
        if val then
            cam.CameraType = Enum.CameraType.Scriptable
        else
            cam.CameraType = Enum.CameraType.Custom
        end
    end,
})

RunService.RenderStepped:Connect(function(dt)
    if not freecamEnabled then return end
    local cam = Workspace.CurrentCamera
    local move = Vector3.new(0, 0, 0)
    local spd = freecamSpeed * 50 * dt

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        move = move + cam.CFrame.LookVector * spd
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        move = move - cam.CFrame.LookVector * spd
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        move = move - cam.CFrame.RightVector * spd
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        move = move + cam.CFrame.RightVector * spd
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.E) then
        move = move + Vector3.new(0, spd, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
        move = move - Vector3.new(0, spd, 0)
    end

    cam.CFrame = cam.CFrame + move
end)

-------------------------------------------------------------------
-- MISC TAB
-------------------------------------------------------------------
local MiscTab = Window:CreateTab("Misc", 0)

MiscTab:CreateButton({
    Name = "Rejoin Server",
    Callback = function()
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, lp)
    end,
})

MiscTab:CreateButton({
    Name = "Server Hop",
    Callback = function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, lp)
    end,
})

MiscTab:CreateButton({
    Name = "Copy Server ID",
    Callback = function()
        setclipboard(game.JobId)
        Rayfield:Notify({Title = "Copied", Content = "server id in clipboard", Duration = 3})
    end,
})

MiscTab:CreateButton({
    Name = "Anti AFK",
    Callback = function()
        local vu = game:GetService("VirtualUser")
        lp.Idled:Connect(function()
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
        Rayfield:Notify({Title = "Anti AFK", Content = "enabled", Duration = 3})
    end,
})

Rayfield:Notify({
    Title = "British Railway Hub",
    Content = "loaded — by Ritmada",
    Duration = 5,
})
