--[[
    SPEED BYPASS — standalone

    Run this on its own. It does not need WOKE or any other script, and it
    stays out of their way if they are running: it never touches WalkSpeed,
    never writes velocity, and never replaces anyone's movement loop.

    How it works
    ------------
    A duel script that runs you at 59 drives the humanoid, so it is limited by
    how fast the humanoid is allowed to walk — that is the cap you hit. This
    leaves that loop completely alone. Every frame it takes whatever direction
    you are already holding and moves the root part the *extra* distance
    itself, in short hops with a raycast in front of each one, so you cover
    more ground without the humanoid ever reporting a higher speed and without
    punching through walls.

    POWER is the dial: POWER_PER_STUD power buys one extra stud/second, so the
    default 100000 is +50 studs/s on top of whatever you were already running.
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- Running the script twice would stack two panels.
for _, name in ipairs({"SpeedBypassGui", "WokeSpeedBypass"}) do
    local old = PlayerGui:FindFirstChild(name)
    if old then pcall(function() old:Destroy() end) end
end

--------------------------------------------------------------------------------
-- TUNING
--------------------------------------------------------------------------------
local POWER_DEFAULT   = 100000
local POWER_MIN       = 1000
local POWER_MAX       = 1000000
local POWER_PER_STUD  = 2000    -- power units per bonus stud/second
local DEFAULT_KEY     = Enum.KeyCode.CapsLock

local MAX_HOP         = 3.5     -- studs covered per raycast-checked hop
local MAX_HOPS        = 16
local WALL_SKIN       = 1.6     -- clearance kept in front of the root part
local RAMP            = 7       -- how quickly the boost eases in and out
local MAX_FRAME       = 1 / 30  -- cap on one frame's catch-up after a hitch

local CONFIG_FILE     = "SpeedBypass.json"

--------------------------------------------------------------------------------
-- STYLE
--------------------------------------------------------------------------------
local DARK_BG    = Color3.fromRGB(0, 0, 0)
local DARKER_BG  = Color3.fromRGB(5, 5, 8)
local INPUT_BG   = Color3.fromRGB(8, 8, 12)
local WHITE      = Color3.fromRGB(255, 255, 255)
local MUTED_TEXT = Color3.fromRGB(190, 187, 202)

local BORDER_GRAD_DARK = {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 40, 40)),
        ColorSequenceKeypoint.new(0.25, Color3.fromRGB(25, 25, 25)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(40, 40, 40)),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(20, 20, 20)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 40, 40)),
    }),
    Rotation = 135,
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.92, 0),
        NumberSequenceKeypoint.new(0.25, 0.65, 0),
        NumberSequenceKeypoint.new(0.5, 0.38, 0),
        NumberSequenceKeypoint.new(0.75, 0.72, 0),
        NumberSequenceKeypoint.new(1, 0.92, 0),
    }),
}

local BORDER_GRAD_LIGHT = {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.25, Color3.fromRGB(180, 185, 210)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(160, 165, 200)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
    }),
    Rotation = 135,
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5, 0),
        NumberSequenceKeypoint.new(0.25, 0.2, 0),
        NumberSequenceKeypoint.new(0.5, 0, 0),
        NumberSequenceKeypoint.new(0.75, 0.2, 0),
        NumberSequenceKeypoint.new(1, 0.5, 0),
    }),
}

local WORDMARK_GRADIENT = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(236, 238, 248)),
    ColorSequenceKeypoint.new(0.62, Color3.fromRGB(150, 156, 186)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(228, 231, 243)),
})

--------------------------------------------------------------------------------
-- BUILD HELPERS
--------------------------------------------------------------------------------
local function new(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then inst[k] = v end
    end
    if props.Parent then inst.Parent = props.Parent end
    return inst
end

local function uiTween(obj, duration, props)
    local t = TweenService:Create(obj,
        TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function addDarkBorderGradient(stroke)
    return new("UIGradient", {
        Color = BORDER_GRAD_DARK.Color,
        Rotation = BORDER_GRAD_DARK.Rotation,
        Transparency = BORDER_GRAD_DARK.Transparency,
        Parent = stroke,
    })
end

local function addInputBorder(parent, cornerRadius)
    new("UICorner", {CornerRadius = UDim.new(0, cornerRadius or 7), Parent = parent})
    local stroke = new("UIStroke", {
        Color = WHITE, Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
    addDarkBorderGradient(stroke)
    return stroke
end

local function nextOrder(parent)
    local n = 0
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("GuiObject") then n = n + 1 end
    end
    return n
end

local function createRow(name, parent)
    local row = new("Frame", {
        Name = name,
        LayoutOrder = nextOrder(parent),
        Size = UDim2.new(1, -4, 0, 34),
        BackgroundColor3 = DARKER_BG,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Parent = parent,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 9), Parent = row})
    addDarkBorderGradient(new("UIStroke", {
        Color = WHITE, Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = row,
    }))

    -- The accent tick on the left edge of every row.
    new("Frame", {
        Name = "Accent",
        ZIndex = 4,
        Position = UDim2.new(0, 0, 0.5, -9),
        Size = UDim2.new(0, 3, 0, 18),
        BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Parent = row,
    })

    new("TextLabel", {
        Name = "Label",
        ZIndex = 4,
        Position = UDim2.new(0, 12, 0, 0),
        -- Stops short of the widest control on the right (the keybind row's
        -- clear button), so no label can ever run underneath one.
        Size = UDim2.new(1, -146, 1, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = WHITE,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })

    return row
end

-- A row whose right-hand side is a wide ENABLED / DISABLED pill.
local function createStateRow(name, parent)
    local row = createRow(name, parent)
    local btn = new("TextButton", {
        Name = "StateButton",
        ZIndex = 25,
        Position = UDim2.new(1, -104, 0.5, -12),
        Size = UDim2.new(0, 94, 0, 24),
        BackgroundColor3 = INPUT_BG,
        BackgroundTransparency = 0.18,
        Text = "DISABLED",
        TextColor3 = MUTED_TEXT,
        TextSize = 11,
        Font = Enum.Font.GothamBlack,
        AutoButtonColor = false,
        Parent = row,
    })
    local gradient = addInputBorder(btn):FindFirstChildWhichIsA("UIGradient")

    local api = {row = row, button = btn, state = false}
    function api.setVisual(state)
        state = state == true
        if api.state == state then return end
        api.state = state
        btn.Text = state and "ENABLED" or "DISABLED"
        uiTween(btn, 0.15, {
            BackgroundTransparency = state and 0 or 0.18,
            TextColor3 = state and WHITE or MUTED_TEXT,
        })
        if gradient then
            local grad = state and BORDER_GRAD_LIGHT or BORDER_GRAD_DARK
            gradient.Color = grad.Color
            gradient.Transparency = grad.Transparency
        end
    end
    return api
end

local function createValueRow(name, defaultValue, parent)
    local row = createRow(name, parent)
    local box = new("TextBox", {
        Name = "ValueBox",
        ZIndex = 25,
        Position = UDim2.new(1, -104, 0.5, -12),
        Size = UDim2.new(0, 94, 0, 24),
        BackgroundColor3 = INPUT_BG,
        BackgroundTransparency = 0.18,
        Text = tostring(defaultValue),
        TextColor3 = WHITE,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        ClearTextOnFocus = false,
        Parent = row,
    })
    addInputBorder(box)
    return {row = row, box = box}
end

local function createKeybindRow(name, parent)
    local row = createRow(name, parent)
    local btn = new("TextButton", {
        Name = "KeybindButton",
        ZIndex = 25,
        Position = UDim2.new(1, -104, 0.5, -12),
        Size = UDim2.new(0, 94, 0, 24),
        BackgroundColor3 = INPUT_BG,
        BackgroundTransparency = 0.18,
        Text = "NONE",
        TextColor3 = WHITE,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
        Parent = row,
    })
    addInputBorder(btn)

    local clear = new("TextButton", {
        Name = "ClearKeybindButton",
        ZIndex = 25,
        Position = UDim2.new(1, -126, 0.5, -9),
        Size = UDim2.new(0, 18, 0, 18),
        BackgroundColor3 = INPUT_BG,
        BackgroundTransparency = 0.08,
        Text = "",
        AutoButtonColor = false,
        Parent = row,
    })
    new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = clear})
    addDarkBorderGradient(new("UIStroke", {
        Color = WHITE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = clear,
    }))

    return {row = row, button = btn, clear = clear}
end

local function createReadoutRow(name, parent)
    local row = createRow(name, parent)
    local value = new("TextLabel", {
        Name = "ReadoutValue",
        ZIndex = 5,
        Position = UDim2.new(1, -142, 0, 0),
        Size = UDim2.new(0, 130, 1, 0),
        BackgroundTransparency = 1,
        Text = "--",
        TextColor3 = WHITE,
        TextSize = 12,
        Font = Enum.Font.GothamBlack,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = row,
    })
    return {row = row, value = value}
end

-- The title, drawn as layered art: dropped shadow, soft outer glow, a
-- gradient-filled face and an accent bar that fades out at both ends.
local function createWordmark(text, parent, position, size, zIndex, maxTextSize)
    local holder = new("Frame", {
        Name = "Wordmark",
        ZIndex = zIndex,
        Position = position,
        Size = size,
        BackgroundTransparency = 1,
        Parent = parent,
    })

    local function layer(layerName, offsetY, dz)
        local lbl = new("TextLabel", {
            Name = layerName,
            ZIndex = zIndex + dz,
            Position = UDim2.new(0, 0, 0, offsetY),
            Size = UDim2.new(1, 0, 1, -6),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = WHITE,
            TextScaled = true,
            Font = Enum.Font.GothamBlack,
            Parent = holder,
        })
        new("UITextSizeConstraint", {MinTextSize = 10, MaxTextSize = maxTextSize, Parent = lbl})
        return lbl
    end

    local shadow = layer("Shadow", 3, 0)
    shadow.TextColor3 = DARKER_BG
    shadow.TextTransparency = 0.35

    local glow = layer("Glow", 0, 1)
    glow.TextTransparency = 0.72
    new("UIStroke", {Color = Color3.fromRGB(205, 212, 240), Thickness = 4, Transparency = 0.78, Parent = glow})

    local face = layer("Face", 0, 2)
    new("UIStroke", {Color = Color3.fromRGB(8, 8, 12), Thickness = 1.6, Transparency = 0.25, Parent = face})
    new("UIGradient", {Color = WORDMARK_GRADIENT, Rotation = 90, Parent = face})

    local bar = new("Frame", {
        Name = "AccentBar",
        ZIndex = zIndex + 2,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(0.6, 0, 0, 2),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        Parent = holder,
    })
    new("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.25, 0),
            NumberSequenceKeypoint.new(1, 1, 0),
        }),
        Parent = bar,
    })

    return holder
end

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------
local Gui = new("ScreenGui", {
    Name = "SpeedBypassGui",
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    DisplayOrder = 1001,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = PlayerGui,
})

local Panel = new("Frame", {
    Name = "Panel",
    Active = true,
    ClipsDescendants = true,
    Position = UDim2.new(0.5, -134, 0, 56),
    Size = UDim2.new(0, 268, 0, 232),
    BackgroundColor3 = DARK_BG,
    BackgroundTransparency = 0.12,
    BorderSizePixel = 0,
    Parent = Gui,
})
new("UICorner", {CornerRadius = UDim.new(0, 13), Parent = Panel})
addDarkBorderGradient(new("UIStroke", {
    Color = WHITE, Thickness = 1.2,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    Parent = Panel,
}))
-- The header doubles as the drag handle, so the rows below stay clickable.
local Header = new("TextButton", {
    Name = "Header",
    ZIndex = 2,
    Size = UDim2.new(1, 0, 0, 58),
    BackgroundTransparency = 1,
    Text = "",
    AutoButtonColor = false,
    Parent = Panel,
})

createWordmark("SPEED BYPASS", Header, UDim2.new(0, 12, 0, 8), UDim2.new(1, -58, 0, 30), 3, 21)

new("TextLabel", {
    Name = "Subtitle",
    ZIndex = 5,
    Position = UDim2.new(0, 13, 0, 37),
    Size = UDim2.new(1, -58, 0, 14),
    BackgroundTransparency = 1,
    Text = "drag here  ·  standalone",
    TextColor3 = MUTED_TEXT,
    TextSize = 10,
    Font = Enum.Font.GothamBlack,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = Header,
})

local CloseButton = new("TextButton", {
    Name = "CloseButton",
    ZIndex = 6,
    Position = UDim2.new(1, -38, 0, 12),
    Size = UDim2.new(0, 26, 0, 26),
    BackgroundColor3 = DARK_BG,
    BackgroundTransparency = 0.28,
    Text = "×",
    TextColor3 = WHITE,
    TextSize = 18,
    Font = Enum.Font.GothamBlack,
    AutoButtonColor = false,
    Parent = Panel,
})
new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = CloseButton})
addDarkBorderGradient(new("UIStroke", {
    Color = WHITE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = CloseButton,
}))

local Rows = new("Frame", {
    Name = "Rows",
    ZIndex = 3,
    Position = UDim2.new(0, 8, 0, 60),
    Size = UDim2.new(1, -16, 1, -68),
    BackgroundTransparency = 1,
    Parent = Panel,
})
new("UIListLayout", {
    Padding = UDim.new(0, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = Rows,
})

local StateRow   = createStateRow("Main Feature", Rows)
local PowerRow   = createValueRow("Power", POWER_DEFAULT, Rows)
local KeybindRow = createKeybindRow("Keybind", Rows)
local SpeedRow   = createReadoutRow("Speed", Rows)

-- Closing the panel has to leave a way back, so it collapses to a small pill.
local FloatOpen = new("TextButton", {
    Name = "FloatOpen",
    Visible = false,
    Active = true,
    ZIndex = 500,
    Position = UDim2.new(0, 14, 0.55, 0),
    Size = UDim2.new(0, 118, 0, 32),
    BackgroundColor3 = Color3.fromRGB(14, 14, 18),
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,
    Text = "SPEED BYPASS",
    TextColor3 = WHITE,
    TextSize = 11,
    Font = Enum.Font.GothamBlack,
    AutoButtonColor = false,
    Parent = Gui,
})
new("UICorner", {Parent = FloatOpen})
local FloatStroke = new("UIStroke", {Color = WHITE, Transparency = 0.45, Parent = FloatOpen})

--------------------------------------------------------------------------------
-- STATE + CONFIG
--------------------------------------------------------------------------------
local enabled     = false
local power       = POWER_DEFAULT
local bindKey     = DEFAULT_KEY
local panelOpen   = true
local panelPos    = nil       -- {xs, xo, ys, yo}
local floatPos    = nil

local function clampPower(v)
    return math.clamp(tonumber(v) or POWER_DEFAULT, POWER_MIN, POWER_MAX)
end

local function udim2ToTable(u)
    return {u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset}
end

local function tableToUDim2(t, fallback)
    if type(t) ~= "table" or #t ~= 4 then return fallback end
    return UDim2.new(t[1], t[2], t[3], t[4])
end

local function keyToString(key)
    if not key then return "None" end
    return (tostring(key):gsub("Enum%.KeyCode%.", ""))
end

local function stringToKeyCode(value)
    if type(value) ~= "string" or value == "" or value == "None" then return nil end
    local ok, key = pcall(function() return Enum.KeyCode[value] end)
    return ok and key or nil
end

-- File IO is executor-provided and may be missing entirely; every call is
-- guarded so a missing writefile just means settings do not persist.
local function saveConfig()
    if type(writefile) ~= "function" then return end
    pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode({
            enabled = enabled,
            power = power,
            keybind = keyToString(bindKey),
            panelOpen = panelOpen,
            panelPos = panelPos,
            floatPos = floatPos,
        }))
    end)
end

local function loadConfig()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
    local ok, data = pcall(function()
        if not isfile(CONFIG_FILE) then return nil end
        return HttpService:JSONDecode(readfile(CONFIG_FILE))
    end)
    if not ok or type(data) ~= "table" then return end

    enabled = data.enabled == true
    power = clampPower(data.power)
    -- A cleared bind saves as "None" and has to stay cleared, so only an
    -- absent key falls back to the default.
    if data.keybind ~= nil then bindKey = stringToKeyCode(data.keybind) end
    panelOpen = data.panelOpen ~= false
    if type(data.panelPos) == "table" then panelPos = data.panelPos end
    if type(data.floatPos) == "table" then floatPos = data.floatPos end
end

local saveQueued = false
local function saveSoon()
    if saveQueued then return end
    saveQueued = true
    task.delay(0.5, function()
        saveQueued = false
        saveConfig()
    end)
end

--------------------------------------------------------------------------------
-- ENGINE
--------------------------------------------------------------------------------
local boost = 0                       -- ramped bonus speed, studs/second
local liveSpeed = 0                   -- measured horizontal speed, for the readout
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function bonusSpeed()
    return power / POWER_PER_STUD
end

-- Anything that steers the character itself has to win: running both would
-- tear the root part between two positions on every frame. WOKE publishes
-- these globals; standalone they are all nil and the checks cost nothing.
local function suspended()
    if _G.SpeedBypassSuspend == true then return true end
    if _G.AceNormalAimbotOn == true then return true end
    if _G.AceAntiBypassAimbotOn == true then return true end
    if _G.AceAntiDesyncAimbotOn == true then return true end
    if _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then return true end
    return false
end

-- One frame of bypass movement.
local function step(dt)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then
        boost, liveSpeed = 0, 0
        return
    end

    local vel = root.AssemblyLinearVelocity
    liveSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude

    if not enabled or hum.Health <= 0 or suspended() then boost = 0 return end

    local state = hum:GetState()
    if hum.PlatformStand
        or state == Enum.HumanoidStateType.Physics
        or state == Enum.HumanoidStateType.Ragdoll
        or state == Enum.HumanoidStateType.FallingDown
        or state == Enum.HumanoidStateType.Seated then
        boost = 0
        return
    end

    local move = hum.MoveDirection
    local flat = move and Vector3.new(move.X, 0, move.Z) or Vector3.zero
    if flat.Magnitude < 0.05 then boost = 0 return end
    local dir = flat.Unit

    -- Ease in and out instead of snapping, which would read as a teleport.
    boost = boost + (bonusSpeed() - boost) * math.min((dt or 0) * RAMP, 1)

    -- Cap the frame delta: after a hitch, dt can be large enough that one
    -- frame's catch-up would fling the character across the map.
    local distance = boost * math.min(dt or 0, MAX_FRAME)
    if distance <= 0.001 then return end

    rayParams.FilterDescendantsInstances = {char}
    local hops = math.clamp(math.ceil(distance / MAX_HOP), 1, MAX_HOPS)
    local hop = distance / hops
    for _ = 1, hops do
        if workspace:Raycast(root.Position, dir * (hop + WALL_SKIN), rayParams) then
            break
        end
        root.CFrame = root.CFrame + dir * hop
    end
end

RunService.RenderStepped:Connect(step)

--------------------------------------------------------------------------------
-- WIRING
--------------------------------------------------------------------------------
local listening = false
local listenStartedAt = 0

local function refresh()
    StateRow.setVisual(enabled)
    if UserInputService:GetFocusedTextBox() ~= PowerRow.box then
        PowerRow.box.Text = tostring(math.floor(power + 0.5))
    end
    KeybindRow.button.Text = listening and "..." or keyToString(bindKey)
    SpeedRow.value.Text = enabled
        and string.format("%.1f  (+%.1f)", liveSpeed, bonusSpeed())
        or string.format("%.1f", liveSpeed)
    -- Assigned rather than tweened: refresh runs five times a second.
    FloatStroke.Transparency = enabled and 0.05 or 0.45
end

local function setEnabled(state)
    state = state == true
    if enabled == state then return end
    enabled = state
    if not state then boost = 0 end
    refresh()
    saveSoon()
end

local function setPanelOpen(open)
    panelOpen = open == true
    Panel.Visible = panelOpen
    FloatOpen.Visible = not panelOpen
    saveSoon()
end

StateRow.button.MouseButton1Click:Connect(function()
    setEnabled(not enabled)
end)

PowerRow.box.FocusLost:Connect(function()
    -- Anything that is not a number leaves the power where it was; the refresh
    -- puts the old value back in the box.
    local typed = tonumber(PowerRow.box.Text)
    if typed then power = clampPower(typed) end
    refresh()
    saveSoon()
end)

KeybindRow.button.MouseButton1Click:Connect(function()
    listening = true
    listenStartedAt = tick()
    refresh()
end)

KeybindRow.clear.MouseButton1Click:Connect(function()
    listening = false
    bindKey = nil
    refresh()
    saveSoon()
end)

CloseButton.MouseButton1Click:Connect(function() setPanelOpen(false) end)

-- Dragging. `handle` is the element that receives the input, which is not
-- always the frame that moves. Returns a "was dragged" probe so a click
-- handler can ignore the release that ends a drag.
local function makeDraggable(frame, handle, onMoved)
    handle = handle or frame
    local dragging, moved, heldInput, startPos, framePos = false, false, nil, nil, nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging, moved, heldInput = true, false, input
            startPos, framePos = input.Position, frame.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging or not startPos then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - startPos
        if not moved and (math.abs(delta.X) > 4 or math.abs(delta.Y) > 4) then moved = true end
        if moved then
            frame.Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X,
                                       framePos.Y.Scale, framePos.Y.Offset + delta.Y)
            if onMoved then onMoved() end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input ~= heldInput then return end
        dragging, heldInput = false, nil
    end)

    return function() return moved end
end

makeDraggable(Panel, Header, function()
    panelPos = udim2ToTable(Panel.Position)
    saveSoon()
end)

local floatWasDragged = makeDraggable(FloatOpen, FloatOpen, function()
    floatPos = udim2ToTable(FloatOpen.Position)
    saveSoon()
end)

FloatOpen.MouseButton1Click:Connect(function()
    if floatWasDragged() then return end
    setPanelOpen(true)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    local isController = tostring(input.UserInputType):find("Gamepad") ~= nil
    if input.UserInputType ~= Enum.UserInputType.Keyboard and not isController then return end
    if input.KeyCode == Enum.KeyCode.Unknown then return end

    if listening then
        -- The click that opened the row can arrive as a key event on the same
        -- frame, so ignore anything in the first moments.
        if tick() - listenStartedAt < 0.18 then return end
        listening = false
        if input.KeyCode == Enum.KeyCode.Escape then
            refresh()                                    -- cancelled, bind unchanged
        elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
            bindKey = nil
            refresh()
            saveSoon()
        else
            bindKey = input.KeyCode
            refresh()
            saveSoon()
        end
        return
    end

    if gameProcessed and input.UserInputType == Enum.UserInputType.Keyboard then return end
    if UserInputService:GetFocusedTextBox() then return end
    if bindKey and input.KeyCode == bindKey then setEnabled(not enabled) end
end)

--------------------------------------------------------------------------------
-- STARTUP
--------------------------------------------------------------------------------
loadConfig()

power = clampPower(power)
Panel.Position = tableToUDim2(panelPos, Panel.Position)
FloatOpen.Position = tableToUDim2(floatPos, FloatOpen.Position)
setPanelOpen(panelOpen)
refresh()

-- Keeps the live speed readout moving without repainting text every frame.
task.spawn(function()
    while task.wait(0.2) do
        if Panel.Visible then refresh() end
    end
end)

_G.SpeedBypassEnabled = function() return enabled end
_G.SpeedBypassSetEnabled = setEnabled
_G.SpeedBypassStep = step
_G.SpeedBypassBonus = bonusSpeed
