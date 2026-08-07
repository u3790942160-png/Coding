--------------------------------------------------------------------------------
-- WOKE — UI layer + wiring
--
-- The layout below is the WOKE hub. Every control is wired to the
-- feature logic that was lifted out of the Ace source (speed modes, drop
-- brainrot, TP down, aimbots, auto steal, counters, ESP, sky, performance,
-- keybinds, config save/load). None of the Ace GUI code is used here.
--
-- This file is concatenated after the extracted logic by tools/build_wokehub.py;
-- everything the logic exposes is a global at that point.
--------------------------------------------------------------------------------
local function WokeHubMain()

local Players            = game:GetService("Players")
local TweenService       = game:GetService("TweenService")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local StatsService       = game:GetService("Stats")
local LocalPlayer        = Players.LocalPlayer
local PlayerGui          = LocalPlayer:WaitForChild("PlayerGui")

-- The Ace config carries a "gui locked" flag that its own menu could toggle.
-- This hub has no such control, so a saved `true` would leave the window
-- permanently unmovable with no way to release it. Always start unlocked.
_G.AceGuiLocked = false

--------------------------------------------------------------------------------
-- SHARED STYLE CONSTANTS
--------------------------------------------------------------------------------
local DARK_BG     = Color3.fromRGB(0, 0, 0)
local DARKER_BG   = Color3.fromRGB(5, 5, 8)
local INPUT_BG    = Color3.fromRGB(8, 8, 12)
local WHITE       = Color3.fromRGB(255, 255, 255)
local MUTED_TEXT  = Color3.fromRGB(190, 187, 202)
local TRAIL_COLOR = Color3.fromRGB(205, 215, 235)

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

local ARROW_GLOW_TRANSPARENCY = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.82, 0),
    NumberSequenceKeypoint.new(0.28, 0.06, 0),
    NumberSequenceKeypoint.new(0.52, 0.22, 0),
    NumberSequenceKeypoint.new(1, 0.82, 0),
})

local BUTTON_NONE_GRADIENT_COLOR = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 22, 25)),
    ColorSequenceKeypoint.new(0.18, Color3.fromRGB(2, 2, 3)),
    ColorSequenceKeypoint.new(0.82, Color3.fromRGB(2, 2, 3)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 22, 25)),
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

local function uiTween(obj, duration, props, style, dir)
    local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function addDarkBorderGradient(strokeInst)
    return new("UIGradient", {
        Color = BORDER_GRAD_DARK.Color,
        Rotation = BORDER_GRAD_DARK.Rotation,
        Transparency = BORDER_GRAD_DARK.Transparency,
        Parent = strokeInst,
    })
end

local function addLightBorderGradient(strokeInst)
    return new("UIGradient", {
        Color = BORDER_GRAD_LIGHT.Color,
        Rotation = BORDER_GRAD_LIGHT.Rotation,
        Transparency = BORDER_GRAD_LIGHT.Transparency,
        Parent = strokeInst,
    })
end

local function addRowBorder(parent, thickness)
    new("UICorner", {CornerRadius = UDim.new(0, 9), Parent = parent})
    local s = new("UIStroke", {
        Color = WHITE,
        Thickness = thickness or 1.25,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
    addDarkBorderGradient(s)
    return s
end

local function addInputBorder(parent, cornerRadius)
    new("UICorner", {CornerRadius = UDim.new(0, cornerRadius or 7), Parent = parent})
    local s = new("UIStroke", {
        Color = WHITE,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
    addDarkBorderGradient(s)
    return s
end

-- Rows are laid out by a UIListLayout in insertion order; give every row an
-- explicit LayoutOrder so the ordering never depends on child-sort fallbacks.
local orderCounters = {}
local function nextOrder(parent)
    local n = (orderCounters[parent] or 0) + 1
    orderCounters[parent] = n
    return n
end

local function addRowLabel(parent, text, fontSize)
    return new("TextLabel", {
        Name = "Label",
        ZIndex = 4,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -132, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = WHITE,
        TextSize = fontSize or 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = parent,
    })
end

local function createRow(name, parent)
    return new("Frame", {
        Name = name,
        ZIndex = 3,
        LayoutOrder = nextOrder(parent),
        Size = UDim2.new(1, -4, 0, 34),
        BackgroundColor3 = DARK_BG,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Parent = parent,
    })
end

local function createSection(name, text, parent)
    return new("TextLabel", {
        Name = "Section_" .. name,
        ZIndex = 4,
        LayoutOrder = nextOrder(parent),
        Size = UDim2.new(1, -6, 0, 15),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = WHITE,
        TextSize = 11,
        Font = Enum.Font.GothamBlack,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = parent,
    })
end

--------------------------------------------------------------------------------
-- COMPONENTS (each returns a handle the wiring section binds behaviour to)
--------------------------------------------------------------------------------
local function createValueRow(name, label, defaultValue, parent)
    local row = createRow(name, parent)
    addRowBorder(row)
    addRowLabel(row, label)

    local box = new("TextBox", {
        Name = "ValueBox",
        ZIndex = 25,
        Position = UDim2.new(1, -68, 0.5, -12),
        Size = UDim2.new(0, 58, 0, 24),
        BackgroundColor3 = INPUT_BG,
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
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

local function createToggle(name, label, parent, hasArrow)
    local row = createRow(name, parent)
    addRowBorder(row)
    addRowLabel(row, label)

    local api = {row = row, state = false}

    if hasArrow then
        local arrow = new("TextButton", {
            Name = "ArrowButton",
            ZIndex = 5,
            Position = UDim2.new(1, -108, 0.5, -13),
            Size = UDim2.new(0, 38, 0, 26),
            BackgroundColor3 = INPUT_BG,
            BackgroundTransparency = 0.18,
            Text = "▼",
            TextColor3 = WHITE,
            TextSize = 22,
            Font = Enum.Font.GothamBlack,
            AutoButtonColor = false,
            Parent = row,
        })
        new("UICorner", {CornerRadius = UDim.new(0, 7), Parent = arrow})

        local border = new("UIStroke", {
            Name = "AnimatedArrowBorder",
            Color = WHITE, Thickness = 1.8,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Transparency = 0.05,
            Parent = arrow,
        })
        new("UIGradient", {Rotation = 135, Transparency = ARROW_GLOW_TRANSPARENCY, Parent = border})

        local glow = new("UIStroke", {
            Name = "AnimatedArrowGlow",
            Color = WHITE, Thickness = 3.6,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Transparency = 0.58,
            Parent = arrow,
        })
        new("UIGradient", {Name = "GlowGradient", Rotation = 180, Transparency = ARROW_GLOW_TRANSPARENCY, Parent = glow})
        api.arrow = arrow
    end

    local toggleBtn = new("TextButton", {
        Name = "ToggleArea",
        Position = UDim2.new(1, -54, 0, 0),
        Size = UDim2.new(0, 54, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = row,
    })

    local track = new("Frame", {
        Name = "Track",
        ZIndex = 5,
        Position = UDim2.new(0.5, -17, 0.5, -9),
        Size = UDim2.new(0, 34, 0, 18),
        BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Parent = toggleBtn,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 9), Parent = track})
    addDarkBorderGradient(new("UIStroke", {
        Color = WHITE,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = track,
    }))

    local knob = new("Frame", {
        Name = "Knob",
        ZIndex = 6,
        Position = UDim2.new(0, 3, 0.5, -6),
        Size = UDim2.new(0, 13, 0, 13),
        BackgroundColor3 = DARK_BG,
        BorderSizePixel = 0,
        Parent = track,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 7), Parent = knob})

    local shine = new("Frame", {
        Name = "Shine",
        ZIndex = 7,
        Position = UDim2.new(0, 2, 0, 2),
        Size = UDim2.new(1, -4, 0, 4),
        BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.72,
        BorderSizePixel = 0,
        Parent = knob,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 4), Parent = shine})

    local catcher = new("TextButton", {
        Name = "ToggleButton",
        ZIndex = 100,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = toggleBtn,
    })

    api.button = catcher
    function api.setVisual(state)
        state = state == true
        api.state = state
        if state then
            uiTween(knob, 0.15, {Position = UDim2.new(1, -16, 0.5, -6), BackgroundColor3 = WHITE})
            uiTween(track, 0.15, {BackgroundTransparency = 0})
        else
            uiTween(knob, 0.15, {Position = UDim2.new(0, 3, 0.5, -6), BackgroundColor3 = DARK_BG})
            uiTween(track, 0.15, {BackgroundTransparency = 0.2})
        end
    end

    return api
end

local function createExpandable(option1, option2, parent)
    local frame = createRow("Expandable", parent)
    frame.Visible = false
    frame.Size = UDim2.new(1, -4, 0, 0)
    addRowBorder(frame)

    local highlight = new("Frame", {
        Name = "Highlight",
        ZIndex = 4,
        Position = UDim2.new(0, 4, 0, 4),
        Size = UDim2.new(0.5, -4, 1, -8),
        BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        Parent = frame,
    })
    new("UICorner", {Parent = highlight})
    addLightBorderGradient(new("UIStroke", {
        Color = WHITE,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = highlight,
    }))

    local b1 = new("TextButton", {
        Name = "Option1",
        ZIndex = 5,
        Size = UDim2.new(0.5, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = option1,
        TextColor3 = WHITE,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
        Parent = frame,
    })

    local b2 = new("TextButton", {
        Name = "Option2",
        ZIndex = 5,
        Position = UDim2.new(0.5, 0, 0, 0),
        Size = UDim2.new(0.5, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = option2,
        TextColor3 = WHITE,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
        Parent = frame,
    })

    local api = {frame = frame, index = 1, expanded = false}

    function api.setIndex(idx, silent)
        api.index = (idx == 2) and 2 or 1
        if api.index == 1 then
            uiTween(highlight, 0.15, {Position = UDim2.new(0, 4, 0, 4)})
        else
            uiTween(highlight, 0.15, {Position = UDim2.new(0.5, 0, 0, 4)})
        end
        if not silent and api.onChange then api.onChange(api.index) end
    end

    b1.MouseButton1Click:Connect(function() api.setIndex(1) end)
    b2.MouseButton1Click:Connect(function() api.setIndex(2) end)

    -- Hook the arrow of the toggle row this selector belongs to.
    function api.linkArrow(toggleApi)
        local arrow = toggleApi and toggleApi.arrow
        if not arrow then return end
        arrow.MouseButton1Click:Connect(function()
            api.expanded = not api.expanded
            if api.expanded then
                frame.Visible = true
                uiTween(frame, 0.2, {Size = UDim2.new(1, -4, 0, 34)})
                uiTween(arrow, 0.15, {Rotation = 180})
            else
                uiTween(arrow, 0.15, {Rotation = 0})
                uiTween(frame, 0.2, {Size = UDim2.new(1, -4, 0, 0)})
                task.delay(0.2, function()
                    if not api.expanded then frame.Visible = false end
                end)
            end
        end)
    end

    return api
end

local function createModeRow(name, label, defaultMode, parent)
    local row = createRow(name, parent)
    addRowBorder(row)
    addRowLabel(row, label, 11)

    local value = new("TextLabel", {
        Name = "ModeValue",
        ZIndex = 6,
        Position = UDim2.new(1, -150, 0, 0),
        Size = UDim2.new(0, 138, 1, 0),
        BackgroundTransparency = 1,
        Text = defaultMode,
        TextColor3 = WHITE,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = row,
    })

    local click = new("TextButton", {
        Name = "ModeClick",
        ZIndex = 30,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = row,
    })

    return {row = row, value = value, button = click}
end

local function createKeybindRow(name, label, defaultKey, parent)
    local row = createRow(name, parent)
    addRowBorder(row)
    addRowLabel(row, label)

    local btn = new("TextButton", {
        Name = "KeybindButton",
        ZIndex = 5,
        Position = UDim2.new(1, -64, 0.5, -11),
        Size = UDim2.new(0, 56, 0, 22),
        BackgroundColor3 = INPUT_BG,
        BackgroundTransparency = 0.18,
        Text = defaultKey,
        TextColor3 = WHITE,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
        Parent = row,
    })
    addInputBorder(btn)

    local clearBtn = new("TextButton", {
        Name = "ClearKeybindButton",
        ZIndex = 5,
        Position = UDim2.new(1, -86, 0.5, -9),
        Size = UDim2.new(0, 18, 0, 18),
        BackgroundColor3 = INPUT_BG,
        BackgroundTransparency = 0.08,
        Text = "",
        TextColor3 = WHITE,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
        Parent = row,
    })
    new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = clearBtn})
    addDarkBorderGradient(new("UIStroke", {
        Color = WHITE,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = clearBtn,
    }))

    return {row = row, button = btn, clear = clearBtn}
end

-- A row whose right-hand side is a wide ENABLED / DISABLED pill. Used by the
-- speed bypass panel, where one big obvious state readout beats a small switch.
local function createStateRow(name, label, parent)
    local row = createRow(name, parent)
    addRowBorder(row)
    addRowLabel(row, label)

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
    local stroke = addInputBorder(btn)
    local strokeGradient = stroke:FindFirstChildWhichIsA("UIGradient")

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
        if strokeGradient then
            local grad = state and BORDER_GRAD_LIGHT or BORDER_GRAD_DARK
            strokeGradient.Color = grad.Color
            strokeGradient.Transparency = grad.Transparency
        end
    end
    return api
end

-- A read-only row: label on the left, a value the wiring keeps up to date on
-- the right. No input of any kind.
local function createReadoutRow(name, label, parent)
    local row = createRow(name, parent)
    addRowBorder(row)
    addRowLabel(row, label)

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

local function createActionButton(name, label, parent)
    local row = createRow(name, parent)
    addRowBorder(row)
    addRowLabel(row, label)

    local btn = new("TextButton", {
        Name = "ActionButton",
        ZIndex = 200,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = row,
    })

    local api = {row = row, button = btn}
    function api.flash()
        uiTween(row, 0.08, {BackgroundTransparency = 0.05})
        task.delay(0.15, function() uiTween(row, 0.15, {BackgroundTransparency = 0.3}) end)
    end
    return api
end

local function createThumbnailGallery(name, thumbImages, parent, prefix)
    prefix = prefix or "Bg"
    local frame = new("Frame", {
        Name = name,
        ZIndex = 3,
        LayoutOrder = nextOrder(parent),
        Size = UDim2.new(1, -4, 0, 52),
        BackgroundColor3 = DARK_BG,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Parent = parent,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 11), Parent = frame})
    addDarkBorderGradient(new("UIStroke", {
        Color = WHITE, Thickness = 1.25,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = frame,
    }))

    local scroll = new("ScrollingFrame", {
        Name = prefix .. "Scroll",
        ZIndex = 5,
        Size = UDim2.new(1, -56, 1, 0),
        Position = UDim2.new(0.5, 0, 0, 0),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        ScrollBarImageTransparency = 1,
        ScrollingDirection = Enum.ScrollingDirection.X,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        Parent = frame,
    })

    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Parent = scroll,
    })
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 4),
        PaddingRight = UDim.new(0, 4),
        Parent = scroll,
    })

    local api = {frame = frame, scroll = scroll, thumbs = {}, selected = nil}

    for i, imageId in ipairs(thumbImages) do
        local thumb = new("ImageButton", {
            Name = prefix .. "Thumb" .. i,
            ZIndex = 5,
            LayoutOrder = i,
            Size = UDim2.new(0, 42, 0, 34),
            BackgroundColor3 = DARK_BG,
            BorderSizePixel = 0,
            Image = imageId or "",
            ImageTransparency = 0.22,
            ScaleType = Enum.ScaleType.Crop,
            AutoButtonColor = false,
            Parent = scroll,
        })
        new("UICorner", {CornerRadius = UDim.new(0, 9), Parent = thumb})
        new("UIStroke", {
            Name = "ThumbStroke",
            Color = Color3.fromRGB(80, 80, 90),
            Transparency = 0.4,
            Parent = thumb,
        })

        if i == 1 then
            new("TextLabel", {
                Name = "NoneLabel",
                ZIndex = 6,
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "NONE",
                TextColor3 = WHITE,
                TextSize = 9,
                Font = Enum.Font.GothamMedium,
                Parent = thumb,
            })
        end

        api.thumbs[i] = thumb
        thumb.MouseButton1Click:Connect(function()
            api.select(i)
        end)
    end

    function api.select(index, silent)
        local thumb = api.thumbs[index]
        if not thumb then return end
        if api.selected and api.selected ~= thumb then
            local oldStroke = api.selected:FindFirstChild("ThumbStroke")
            if oldStroke then
                uiTween(oldStroke, 0.15, {Color = Color3.fromRGB(80, 80, 90), Transparency = 0.4})
            end
            uiTween(api.selected, 0.15, {ImageTransparency = 0.22})
        end
        api.selected = thumb
        api.index = index
        local s = thumb:FindFirstChild("ThumbStroke")
        if s then uiTween(s, 0.15, {Color = WHITE, Transparency = 0}) end
        uiTween(thumb, 0.15, {ImageTransparency = 0})
        if not silent and api.onSelect then api.onSelect(index, thumb.Image) end
    end

    for _, data in ipairs({
        {name = prefix .. "ArrowLeft",  text = "<", pos = UDim2.new(0, 3, 0.5, -17), dir = -1},
        {name = prefix .. "ArrowRight", text = ">", pos = UDim2.new(1, -25, 0.5, -17), dir = 1},
    }) do
        local arrow = new("TextButton", {
            Name = data.name,
            ZIndex = 8,
            Position = data.pos,
            Size = UDim2.new(0, 22, 0, 34),
            BackgroundColor3 = Color3.fromRGB(18, 18, 23),
            BackgroundTransparency = 0.05,
            BorderSizePixel = 0,
            Text = data.text,
            TextColor3 = WHITE,
            TextSize = 18,
            Font = Enum.Font.GothamMedium,
            Parent = frame,
        })
        new("UICorner", {CornerRadius = UDim.new(0, 7), Parent = arrow})
        local dir = data.dir
        arrow.MouseButton1Click:Connect(function()
            local pos = scroll.CanvasPosition
            uiTween(scroll, 0.2, {CanvasPosition = Vector2.new(math.max(0, pos.X + dir * 50), 0)})
        end)
    end

    return api
end

local function createColorThemePicker(parent)
    local row = new("Frame", {
        Name = "ColorThemePicker",
        ZIndex = 3,
        LayoutOrder = nextOrder(parent),
        Size = UDim2.new(1, -4, 0, 30),
        BackgroundColor3 = DARK_BG,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Parent = parent,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 9), Parent = row})
    addDarkBorderGradient(new("UIStroke", {
        Color = WHITE, Thickness = 1.25,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = row,
    }))

    local colors = {
        {"PURPLE", Color3.fromRGB(207, 159, 255), -141},
        {"BLUE",   Color3.fromRGB(58, 128, 245),  -105},
        {"RED",    Color3.fromRGB(232, 52, 68),    -69},
        {"PINK",   Color3.fromRGB(255, 105, 180),  -33},
        {"YELLOW", Color3.fromRGB(255, 214, 0),    3},
        {"GREY",   Color3.fromRGB(13, 13, 13),     39},
        {"WHITE2", Color3.fromRGB(255, 255, 255),  75},
        {"FOREST", Color3.fromRGB(46, 139, 87),    111},
    }

    local api = {row = row, buttons = {}, selected = nil}

    for _, data in ipairs(colors) do
        local btn = new("TextButton", {
            Name = data[1] == "WHITE2" and "WHITE" or data[1],
            ZIndex = 5,
            Position = UDim2.new(0.5, data[3], 0.5, -6),
            Size = UDim2.new(0, 30, 0, 12),
            BackgroundColor3 = data[2],
            Text = "",
            AutoButtonColor = false,
            Parent = row,
        })
        new("UICorner", {CornerRadius = UDim.new(0, 4), Parent = btn})
        new("UIStroke", {Name = "ColorStroke", Color = WHITE, Transparency = 0.5, Parent = btn})
        table.insert(api.buttons, btn)

        btn.MouseButton1Click:Connect(function()
            if api.selected then
                local oldStroke = api.selected:FindFirstChild("ColorStroke")
                if oldStroke then uiTween(oldStroke, 0.1, {Transparency = 0.5, Thickness = 1}) end
            end
            api.selected = btn
            local s = btn:FindFirstChild("ColorStroke")
            if s then uiTween(s, 0.1, {Transparency = 0, Thickness = 2}) end
            if api.onSelect then api.onSelect(btn.BackgroundColor3, btn.Name) end
        end)
    end

    return api
end

local function createPickerRow(name, label, defaultValue, parent)
    local row = new("Frame", {
        Name = name,
        ZIndex = 3,
        LayoutOrder = nextOrder(parent),
        Size = UDim2.new(1, -4, 0, 52),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = parent,
    })

    new("TextLabel", {
        Name = "Label",
        ZIndex = 4,
        Position = UDim2.new(0, 2, 0, 0),
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = WHITE,
        TextSize = 12,
        Font = Enum.Font.GothamBlack,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })

    local prev = new("TextButton", {
        Name = "Prev",
        ZIndex = 5,
        Position = UDim2.new(0, 0, 0, 22),
        Size = UDim2.new(0, 44, 0, 25),
        BackgroundColor3 = INPUT_BG,
        BackgroundTransparency = 0.18,
        Text = "<",
        TextColor3 = WHITE,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
        Parent = row,
    })
    addInputBorder(prev)

    local val = new("TextButton", {
        Name = "Value",
        ZIndex = 5,
        Position = UDim2.new(0, 48, 0, 22),
        Size = UDim2.new(1, -96, 0, 28),
        BackgroundColor3 = INPUT_BG,
        BackgroundTransparency = 0.18,
        Text = defaultValue,
        TextColor3 = WHITE,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
        Parent = row,
    })
    addInputBorder(val)

    local nxt = new("TextButton", {
        Name = "Next",
        ZIndex = 5,
        Position = UDim2.new(1, -44, 0, 22),
        Size = UDim2.new(0, 44, 0, 25),
        BackgroundColor3 = INPUT_BG,
        BackgroundTransparency = 0.18,
        Text = ">",
        TextColor3 = WHITE,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
        Parent = row,
    })
    addInputBorder(nxt)

    local api = {row = row, value = val, options = {defaultValue}, index = 1}

    local function bump(btn)
        uiTween(btn, 0.08, {Size = UDim2.new(0, 40, 0, 23)})
        task.delay(0.08, function() uiTween(btn, 0.08, {Size = UDim2.new(0, 44, 0, 25)}) end)
    end

    function api.setIndex(idx, silent)
        local count = #api.options
        if count == 0 then return end
        if idx < 1 then idx = count end
        if idx > count then idx = 1 end
        api.index = idx
        val.Text = tostring(api.options[idx])
        if not silent and api.onChange then api.onChange(api.options[idx], idx) end
    end

    function api.setOptions(list, current)
        api.options = list
        local idx = 1
        for i, v in ipairs(list) do
            if v == current then idx = i break end
        end
        api.setIndex(idx, true)
    end

    prev.MouseButton1Click:Connect(function() bump(prev) api.setIndex(api.index - 1) end)
    nxt.MouseButton1Click:Connect(function() bump(nxt) api.setIndex(api.index + 1) end)
    val.MouseButton1Click:Connect(function() api.setIndex(api.index + 1) end)

    return api
end

local function createMobileButton(name, text, position, size, parent)
    local btn = new("TextButton", {
        Name = name,
        ClipsDescendants = true,
        Position = position,
        Size = size,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = parent,
    })

    local btnCorner = new("UICorner", {CornerRadius = UDim.new(0, 10), Parent = btn})
    local scale = new("UIScale", {Parent = btn})

    local bg = new("ImageLabel", {
        Name = "Backdrop",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = WHITE,
        Parent = btn,
    })
    local bgCorner = new("UICorner", {CornerRadius = UDim.new(0, 10), Parent = bg})
    new("UIGradient", {
        Name = "ButtonNoneGradient",
        Color = BUTTON_NONE_GRADIENT_COLOR,
        Rotation = 25,
        Parent = bg,
    })

    local overlay = new("ImageLabel", {
        Name = "ImageLabel",
        ZIndex = 2,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = "",
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Crop,
        Parent = btn,
    })
    local overlayCorner = new("UICorner", {CornerRadius = UDim.new(0, 10), Parent = overlay})

    local lbl = new("TextLabel", {
        Name = "Label",
        ZIndex = 3,
        Position = UDim2.new(0, 4, 0, 0),
        Size = UDim2.new(1, -8, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = WHITE,
        TextSize = 10,
        TextScaled = true,
        Font = Enum.Font.GothamBlack,
        TextWrapped = true,
        Parent = btn,
    })
    new("UITextSizeConstraint", {MinTextSize = 6, MaxTextSize = 11, Parent = lbl})
    new("UIStroke", {Thickness = 1.4, Parent = lbl})

    local borderStroke = new("UIStroke", {
        Name = "Border",
        Color = WHITE,
        Thickness = 1.1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Transparency = 0.55,
        Parent = btn,
    })
    addDarkBorderGradient(borderStroke)

    local api = {
        button = btn, overlay = overlay, label = lbl, scale = scale,
        stroke = borderStroke, active = false, sizeScale = 1,
        corners = {btnCorner, bgCorner, overlayCorner},
    }

    function api.setActive(state)
        state = state == true
        if api.active == state then return end
        api.active = state
        uiTween(borderStroke, 0.15, {Transparency = state and 0 or 0.55, Thickness = state and 1.8 or 1.1})
        uiTween(lbl, 0.15, {TextColor3 = state and WHITE or Color3.fromRGB(205, 205, 215)})
        uiTween(overlay, 0.15, {ImageTransparency = (state and overlay.Image ~= "") and 0.15 or 1})
    end

    -- Resizing happens per button rather than on the container: a UIScale on
    -- the full-screen holder would scale the buttons' screen positions too and
    -- drag them away from the edge they are anchored to.
    function api.setScale(s)
        api.sizeScale = s
        scale.Scale = s
    end

    function api.press()
        uiTween(scale, 0.06, {Scale = api.sizeScale * 0.92})
        task.delay(0.06, function() uiTween(scale, 0.1, {Scale = api.sizeScale}) end)
    end

    function api.pulse()
        api.setActive(true)
        task.delay(0.2, function() api.setActive(false) end)
    end

    return api
end

local function createTabButton(name, text, order, isActive, parent)
    local btn = new("TextButton", {
        Name = name,
        ZIndex = 4,
        LayoutOrder = order,
        Size = UDim2.new(0.166667, -5, 1, 0),
        BackgroundColor3 = WHITE,
        BackgroundTransparency = isActive and 0.78 or 1,
        Text = text,
        TextColor3 = isActive and WHITE or MUTED_TEXT,
        TextSize = 11,
        TextScaled = true,
        Font = Enum.Font.GothamBlack,
        TextWrapped = true,
        AutoButtonColor = false,
        Parent = parent,
    })

    new("UITextSizeConstraint", {MinTextSize = 6, MaxTextSize = 12, Parent = btn})
    new("UICorner", {CornerRadius = UDim.new(0, 9), Parent = btn})

    local s = new("UIStroke", {
        Color = WHITE,
        Thickness = 1.2,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = btn,
    })
    if isActive then addLightBorderGradient(s) else addDarkBorderGradient(s) end

    return btn
end

--------------------------------------------------------------------------------
-- COMPONENT: Wordmark — the hub name drawn as logo art rather than a label.
-- Layered the way the old banner read: a dropped shadow, a soft outer glow,
-- the gradient-filled face on top, and a thin accent bar underneath.
--------------------------------------------------------------------------------
local WORDMARK_GRADIENT = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(236, 238, 248)),
    ColorSequenceKeypoint.new(0.62, Color3.fromRGB(150, 156, 186)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(228, 231, 243)),
})

local function createWordmark(name, text, parent, position, size, zIndex, maxTextSize)
    local holder = new("Frame", {
        Name = name,
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
        new("UITextSizeConstraint", {MinTextSize = 14, MaxTextSize = maxTextSize, Parent = lbl})
        return lbl
    end

    -- Shadow, sitting a few pixels low behind everything.
    local shadow = layer("Shadow", 4, 0)
    shadow.TextColor3 = DARKER_BG
    shadow.TextTransparency = 0.35

    -- Outer glow: same glyphs, blown out with a wide soft stroke.
    local glow = layer("Glow", 0, 1)
    glow.TextTransparency = 0.72
    new("UIStroke", {Color = Color3.fromRGB(205, 212, 240), Thickness = 5, Transparency = 0.78, Parent = glow})

    -- The face.
    local face = layer("Face", 0, 2)
    new("UIStroke", {Color = Color3.fromRGB(8, 8, 12), Thickness = 1.8, Transparency = 0.25, Parent = face})
    new("UIGradient", {Color = WORDMARK_GRADIENT, Rotation = 90, Parent = face})

    -- Accent bar, fading out at both ends.
    local bar = new("Frame", {
        Name = "AccentBar",
        ZIndex = zIndex + 2,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, 0),
        Size = UDim2.new(0.52, 0, 0, 2),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        Parent = holder,
    })
    new("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1, 0),
            NumberSequenceKeypoint.new(0.5, 0.25, 0),
            NumberSequenceKeypoint.new(1, 1, 0),
        }),
        Parent = bar,
    })

    return {holder = holder, face = face, glow = glow, shadow = shadow, bar = bar}
end

local function createTabPage(name, parent, visible)
    local page = new("ScrollingFrame", {
        Name = name,
        Visible = visible ~= false,
        ZIndex = 3,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        ScrollBarImageTransparency = 1,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = parent,
    })
    new("UIListLayout", {
        Padding = UDim.new(0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = page,
    })
    return page
end

--------------------------------------------------------------------------------
-- ROOT GUI
--------------------------------------------------------------------------------
-- Clear a hub left over from an earlier execution, otherwise running the
-- script twice stacks two menus on top of each other.
for _, name in ipairs({"WokeHub", "WokeSpeedBypass", "AdaptHubPolished", "AceDuelsAdaptReconstruct", "CyberHub"}) do
    local old = PlayerGui:FindFirstChild(name)
    if old then pcall(function() old:Destroy() end) end
end

local WokeGui = new("ScreenGui", {
    Name = "WokeHub",
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    DisplayOrder = 1000,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = PlayerGui,
})

--------------------------------------------------------------------------------
-- INTRO SCREEN
--------------------------------------------------------------------------------
local WokeIntro = new("Frame", {
    Name = "WokeIntro",
    ZIndex = 1000,
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = DARKER_BG,
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
    Parent = WokeGui,
})

local IntroBackdropImage = new("ImageLabel", {
    Name = "IntroBackdropImage",
    Visible = false,
    ZIndex = 1000,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.42, 0),
    Size = UDim2.new(0.92, 0, 0.5, 0),
    BackgroundTransparency = 1,
    Image = "rbxassetid://98541566010518",
    ImageTransparency = 1,
    ScaleType = Enum.ScaleType.Fit,
    Parent = WokeIntro,
})
new("UIScale", {Parent = IntroBackdropImage})

local ChainSpearStage = new("Frame", {
    Name = "ChainSpearStage",
    ZIndex = 1000,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.42, 0),
    Size = UDim2.new(0.64, 0, 0.64, 0),
    BackgroundTransparency = 1,
    Parent = WokeIntro,
})
new("UIAspectRatioConstraint", {Parent = ChainSpearStage})
new("UISizeConstraint", {MinSize = Vector2.new(200, 200), MaxSize = Vector2.new(280, 280), Parent = ChainSpearStage})

do
    local rotorData = {
        {rot = -1094.822, trans = 0.998}, {rot = -1095.4,   trans = 0.998},
        {rot = -1095.978, trans = 0.996}, {rot = -1096.515, trans = 0.995},
        {rot = -1097.052, trans = 0.993}, {rot = -1097.548, trans = 0.991},
        {rot = -1098.004, trans = 0.988}, {rot = -1098.419, trans = 0.985},
        {rot = -1098.794, trans = 0.982}, {rot = -1099.128, trans = 0.978},
        {rot = -1099.421, trans = 0.973},
    }
    for i, data in ipairs(rotorData) do
        local rotor = new("Frame", {
            Name = "ChainSpearRotor" .. i,
            ZIndex = 1000,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Rotation = data.rot,
            Parent = ChainSpearStage,
        })
        new("ImageLabel", {
            Name = "ChainSpearTrail" .. i,
            ZIndex = 1000,
            AnchorPoint = Vector2.new(0.73, 0.02),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0.553, 0, 0.829, 0),
            BackgroundTransparency = 1,
            Image = "rbxassetid://118963313877514",
            ImageColor3 = TRAIL_COLOR,
            ImageTransparency = data.trans,
            ScaleType = Enum.ScaleType.Fit,
            Parent = rotor,
        })
    end
end

local TojiCutoutStage = new("Frame", {
    Name = "TojiCutoutStage",
    Visible = false,
    ZIndex = 1000,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.42, 0),
    Size = UDim2.new(0.76, 0, 0, 312),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Rotation = -2,
    Parent = WokeIntro,
})
new("UIScale", {Parent = TojiCutoutStage})

new("ImageLabel", {
    Name = "TojiPantsWhiteFill",
    ZIndex = 998,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Image = "rbxassetid://82757811555212",
    ImageTransparency = 1,
    ScaleType = Enum.ScaleType.Fit,
    Parent = TojiCutoutStage,
})

do
    local tojiPieceImages = {
        "rbxassetid://130451097419605", "rbxassetid://129030262345273",
        "rbxassetid://76292842640935",  "rbxassetid://82757811555212",
        "rbxassetid://92910922537368",  "rbxassetid://105960347086002",
        "rbxassetid://116720305084998", "rbxassetid://90341354549871",
        "rbxassetid://72399600208480",  "rbxassetid://81834484116440",
    }
    local seamOffsets = {{x = -1, y = 0}, {x = 1, y = 0}, {x = 0, y = -1}, {x = 0, y = 1}}

    for i, imageId in ipairs(tojiPieceImages) do
        for _, offset in ipairs(seamOffsets) do
            new("ImageLabel", {
                Name = "TojiSeamFill" .. i,
                ZIndex = 999,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, offset.x, 0.5, offset.y),
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Image = imageId,
                ImageColor3 = DARKER_BG,
                ImageTransparency = 1,
                ScaleType = Enum.ScaleType.Fit,
                Parent = TojiCutoutStage,
            })
        end

        new("ImageLabel", {
            Name = "TojiPiece" .. i,
            ZIndex = 1000,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Image = imageId,
            ImageTransparency = 1,
            ScaleType = Enum.ScaleType.Fit,
            Parent = TojiCutoutStage,
        })

        if i == 2 then
            local shine = new("ImageLabel", {
                Name = "TojiSwordShine",
                ZIndex = 1001,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Image = imageId,
                ImageTransparency = 1,
                ScaleType = Enum.ScaleType.Fit,
                Parent = TojiCutoutStage,
            })
            new("UIGradient", {
                Rotation = -25,
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1, 0),
                    NumberSequenceKeypoint.new(0.5, 0.14, 0),
                    NumberSequenceKeypoint.new(1, 1, 0),
                }),
                Parent = shine,
            })
        end

        if i == 6 then
            for k = 1, 4 do
                new("ImageLabel", {
                    Name = "TojiMovingHandWhiteFill" .. (k > 1 and k or ""),
                    ZIndex = 998,
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(0.5, seamOffsets[k].x, 0.5, seamOffsets[k].y),
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Image = imageId,
                    ImageColor3 = WHITE,
                    ImageTransparency = 1,
                    ScaleType = Enum.ScaleType.Fit,
                    Parent = TojiCutoutStage,
                })
            end
        end
    end
end

local IntroBanner = createWordmark("IntroBanner", "WOKE", WokeIntro,
    UDim2.new(0.5, -140, 0.42, -39), UDim2.new(0, 280, 0, 78), 1002, 62)

local TapAnywhere = new("TextLabel", {
    Name = "TapAnywhere",
    ZIndex = 1003,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.42, 58),
    Size = UDim2.new(0.7, 0, 0, 20),
    BackgroundTransparency = 1,
    Text = "TAP ANYWHERE TO SKIP",
    TextColor3 = WHITE,
    TextSize = 11,
    Font = Enum.Font.GothamBlack,
    Parent = WokeIntro,
})

new("TextLabel", {
    Name = "DiscordInvite",
    ZIndex = 1003,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.42, 80),
    Size = UDim2.new(0.7, 0, 0, 18),
    BackgroundTransparency = 1,
    Text = "discord.gg/adaptt",
    TextColor3 = WHITE,
    TextSize = 10,
    Font = Enum.Font.GothamBlack,
    Parent = WokeIntro,
})

local IntroCaptionShield = new("Frame", {
    Name = "IntroCaptionShield",
    Visible = false,
    ZIndex = 1002,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.42, 70),
    Size = UDim2.new(0.58, 0, 0, 48),
    BackgroundColor3 = DARKER_BG,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    Parent = WokeIntro,
})
new("UICorner", {CornerRadius = UDim.new(0, 14), Parent = IntroCaptionShield})
new("UIGradient", {
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.94, 0),
        NumberSequenceKeypoint.new(0.16, 0.14, 0),
        NumberSequenceKeypoint.new(0.84, 0.14, 0),
        NumberSequenceKeypoint.new(1, 0.94, 0),
    }),
    Parent = IntroCaptionShield,
})

local TapCatcher = new("TextButton", {
    Name = "TapCatcher",
    ZIndex = 1004,
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "",
    AutoButtonColor = false,
    Parent = WokeIntro,
})

--------------------------------------------------------------------------------
-- TOP BAR
--------------------------------------------------------------------------------
local TopBar = new("Frame", {
    Name = "TopBar",
    Size = UDim2.new(1, 0, 0, 74),
    BackgroundColor3 = INPUT_BG,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Parent = WokeGui,
})

new("Frame", {Visible = false, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = TopBar})

local PingLabel = new("TextLabel", {
    Name = "PingLabel",
    Visible = false,
    Position = UDim2.new(0, 14, 0, 0),
    Size = UDim2.new(0, 180, 1, 0),
    BackgroundTransparency = 1,
    Text = "PING: 0",
    TextColor3 = WHITE, TextSize = 13,
    Font = Enum.Font.GothamBlack,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = TopBar,
})

local FpsLabel = new("TextLabel", {
    Name = "FpsLabel",
    Visible = false,
    Position = UDim2.new(1, -194, 0, 0),
    Size = UDim2.new(0, 180, 1, 0),
    BackgroundTransparency = 1,
    Text = "FPS: 60",
    TextColor3 = WHITE, TextSize = 13,
    Font = Enum.Font.GothamBlack,
    TextXAlignment = Enum.TextXAlignment.Right,
    Parent = TopBar,
})

local WokeLogo = new("TextButton", {
    Name = "WokeLogo",
    Visible = false,
    Position = UDim2.new(0.5, -23, 0, 12),
    Size = UDim2.new(0, 46, 0, 46),
    BackgroundColor3 = INPUT_BG,
    Text = "", TextColor3 = WHITE, TextSize = 14,
    Font = Enum.Font.GothamBlack,
    AutoButtonColor = false,
    Parent = TopBar,
})
new("UICorner", {CornerRadius = UDim.new(0, 23), Parent = WokeLogo})
new("UIStroke", {Color = Color3.fromRGB(72, 70, 90), Transparency = 0.18, Parent = WokeLogo})
do
    local logoDot = new("Frame", {
        Position = UDim2.new(0.5, -8, 0.5, -8),
        Size = UDim2.new(0, 16, 0, 16),
        BackgroundColor3 = WHITE, BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
        Parent = WokeLogo,
    })
    new("UICorner", {Parent = logoDot})
end

--------------------------------------------------------------------------------
-- MAIN FRAME
--------------------------------------------------------------------------------
local Main = new("Frame", {
    Name = "Main",
    ClipsDescendants = true,
    Active = true,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 20, 0.5, 0),
    Size = UDim2.new(0, 356, 0, 536),
    BackgroundColor3 = DARK_BG,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Parent = WokeGui,
})
new("UICorner", {CornerRadius = UDim.new(0, 14), Parent = Main})
addDarkBorderGradient(new("UIStroke", {
    Color = WHITE, Thickness = 1.2,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    Parent = Main,
}))
local MainScale = new("UIScale", {Scale = 0.85, Parent = Main})

local BackgroundAsset = new("ImageLabel", {
    Name = "BackgroundAsset",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = DARK_BG, BackgroundTransparency = 1,
    Image = "rbxassetid://90453834580322",
    Parent = Main,
})

local LogoAsset = createWordmark("LogoAsset", "WOKE", Main,
    UDim2.new(0.5, -150, 0, 16), UDim2.new(0, 300, 0, 74), 2, 46)

local Close = new("TextButton", {
    Name = "Close",
    ZIndex = 4,
    Position = UDim2.new(1, -46, 0, 9),
    Size = UDim2.new(0, 36, 0, 30),
    BackgroundColor3 = DARK_BG, BackgroundTransparency = 0.28,
    Text = "-", TextColor3 = WHITE, TextSize = 22,
    Font = Enum.Font.GothamMedium,
    AutoButtonColor = false,
    Parent = Main,
})
new("UICorner", {Parent = Close})
addDarkBorderGradient(new("UIStroke", {Color = WHITE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = Close}))

local Content = new("Frame", {
    Name = "Content",
    ZIndex = 3,
    Position = UDim2.new(0, 13, 0, 112),
    Size = UDim2.new(1, -26, 1, -164),
    BackgroundTransparency = 1,
    Parent = Main,
})

--------------------------------------------------------------------------------
-- TAB PAGES + CONTROL REGISTRY
--------------------------------------------------------------------------------
local Movement   = createTabPage("Movement", Content)
local Combat     = createTabPage("Combat", Content, false)
local Keybinds   = createTabPage("Keybinds", Content, false)
local Controller = createTabPage("Controller", Content, false)
local Utility    = createTabPage("Utility", Content, false)
local Settings   = createTabPage("Settings", Content, false)

-- Every control handle lives here so the wiring section can find it by name.
-- `altKey` holds a second row bound to the same keybind id as one in `key`
-- (the speed bypass panel shows its own copy of the bypass bind). Both rows
-- edit and display the one underlying bind.
local UI = {
    toggle = {}, value = {}, mode = {}, key = {}, ctrlKey = {}, altKey = {},
    expand = {}, pick = {}, action = {}, mobile = {}, gallery = {},
}

--------------------------------------------------------------------------------
-- TAB: MOVEMENT
--------------------------------------------------------------------------------
createSection("Speed Configuration", "SPEED CONFIGURATION", Movement)
UI.value["Normal Speed"]        = createValueRow("Normal Speed", "Normal Speed", "59.5", Movement)
UI.value["Carry Speed"]         = createValueRow("Carry Speed", "Carry Speed", "28.8", Movement)
UI.mode["Speed Mode"]           = createModeRow("Speed Mode", "MODE", "NORMAL", Movement)
UI.toggle["Auto Carry Speed"]   = createToggle("Auto Carry Speed", "Auto Carry Speed", Movement, false)

createSection("Speed Bypass", "SPEED BYPASS", Movement)
UI.toggle["Speed Bypass"]       = createToggle("Speed Bypass", "Speed Bypass", Movement, false)
UI.value["Bypass Power"]        = createValueRow("Bypass Power", "Power", "100000", Movement)
UI.toggle["Bypass Panel"]       = createToggle("Bypass Panel", "Show Bypass Panel", Movement, false)

createSection("Lagger Configuration", "LAGGER CONFIGURATION", Movement)
UI.value["Lagger Normal Speed"] = createValueRow("Lagger Normal Speed", "Lagger Normal Speed", "24.5", Movement)
UI.value["Lagger Carry Speed"]  = createValueRow("Lagger Carry Speed", "Lagger Carry Speed", "15", Movement)
UI.mode["Lagger Mode"]          = createModeRow("Lagger Mode Display", "MODE", "LAGGER NORMAL", Movement)

createSection("Drop Brainrot", "DROP BRAINROT", Movement)
UI.toggle["Drop"]               = createToggle("Drop", "Drop", Movement, true)
UI.expand["Drop"]               = createExpandable("JUMP", "STAND", Movement)
UI.expand["Drop"].linkArrow(UI.toggle["Drop"])

createSection("TP Down", "TP DOWN", Movement)
UI.toggle["TP Down"]            = createToggle("TP Down", "TP Down", Movement, false)
UI.toggle["Auto TP Down"]       = createToggle("Auto TP Down", "Auto TP Down", Movement, false)
UI.value["Auto TP Height"]      = createValueRow("Auto TP Height", "Auto TP Height", "20", Movement)

createSection("Jump", "JUMP", Movement)
UI.toggle["Infinite Jump"]      = createToggle("Infinite Jump", "Infinite Jump", Movement, false)
UI.toggle["Anti Ragdoll"]       = createToggle("Anti Ragdoll", "Anti Ragdoll", Movement, false)
UI.toggle["Unwalk"]             = createToggle("Unwalk", "Unwalk", Movement, false)

--------------------------------------------------------------------------------
-- TAB: COMBAT
--------------------------------------------------------------------------------
createSection("Steal Configuration", "STEAL CONFIGURATION", Combat)
UI.value["Radius"]              = createValueRow("Radius", "Radius", "60", Combat)
UI.value["SEMI Range"]          = createValueRow("SEMI Range", "SEMI Range", "9", Combat)
UI.toggle["Auto Steal"]         = createToggle("Auto Steal", "Auto Steal", Combat, true)
UI.expand["Auto Steal"]         = createExpandable("NORMAL", "SEMI", Combat)
UI.expand["Auto Steal"].linkArrow(UI.toggle["Auto Steal"])

createSection("Bat Aimbot", "BAT AIMBOT", Combat)
UI.toggle["Bat Aimbot"]         = createToggle("Bat Aimbot", "Bat Aimbot", Combat, true)
UI.expand["Bat Aimbot"]         = createExpandable("NORMAL", "BYPASS", Combat)
UI.expand["Bat Aimbot"].linkArrow(UI.toggle["Bat Aimbot"])
UI.value["Auto Bat Speed"]      = createValueRow("Auto Bat Speed", "Auto Bat Speed", "58", Combat)
UI.toggle["Auto Swing"]         = createToggle("Auto Swing", "Auto Swing", Combat, false)
UI.toggle["Mirror TP"]          = createToggle("Mirror TP", "Mirror TP", Combat, false)

createSection("TP Bat", "TP BAT", Combat)
UI.toggle["TP Bat"]             = createToggle("TP Bat", "TP Bat", Combat, true)
UI.expand["TP Bat"]             = createExpandable("SWING", "NO SWING", Combat)
UI.expand["TP Bat"].linkArrow(UI.toggle["TP Bat"])

createSection("Auto Path", "AUTO PATH", Combat)
UI.toggle["Auto Left"]          = createToggle("Auto Left", "Auto Left", Combat, false)
UI.toggle["Auto Right"]         = createToggle("Auto Right", "Auto Right", Combat, false)

createSection("Counters", "COUNTERS", Combat)
UI.toggle["Bat Counter"]        = createToggle("Bat Counter", "Bat Counter", Combat, false)
UI.toggle["Medusa Counter"]     = createToggle("Medusa Counter", "Medusa Counter", Combat, false)
UI.toggle["Reset After Med"]    = createToggle("Reset After Med", "Reset After Med", Combat, false)
UI.toggle["Insta Reset"]        = createToggle("Insta Reset On Death", "Insta Reset", Combat, false)
UI.toggle["Safe Mode"]          = createToggle("Safe Mode", "Safe Mode", Combat, false)

createSection("Body Lock", "BODY LOCK", Combat)
UI.toggle["Anti Bodylock"]      = createToggle("Body Lock", "Anti Bodylock", Combat, false)
UI.toggle["No Player Collision"] = createToggle("No Player Collision", "No Player Collision", Combat, false)

--------------------------------------------------------------------------------
-- TAB: KEYBINDS (KBM) + CONTROLLER
--------------------------------------------------------------------------------
local KEYBIND_LAYOUT = {
    {"MOVEMENT KEYBINDS", {
        {"Speed Key", "SpeedToggle"},
        {"Speed Bypass Key", "SpeedBypass"},
        {"Lagger Mode Key", "LaggerToggle"},
        {"Drop Key", "DropBrainrot"},
        {"TP Down Key", "TPDown"},
    }},
    {"COMBAT KEYBINDS", {
        {"Bat Aimbot Key", "Aimbot"},
        {"TP Bat Key", "AntiDesyncAimbot"},
        {"Auto Left Key", "AutoLeft"},
        {"Auto Right Key", "AutoRight"},
        {"Insta Reset Key", "InstantReset"},
    }},
    {"INTERFACE KEYBINDS", {
        {"UI Toggle Key", "ToggleUI"},
    }},
}

for _, sectionData in ipairs(KEYBIND_LAYOUT) do
    createSection(sectionData[1]:gsub(" ", "_"), sectionData[1], Keybinds)
    for _, bind in ipairs(sectionData[2]) do
        UI.key[bind[2]] = createKeybindRow(bind[1], bind[1], "NONE", Keybinds)
    end
end

UI.action["RESET ALL CONTROLLER"] = createActionButton("RESET ALL CONTROLLER", "RESET ALL CONTROLLER", Controller)

for _, sectionData in ipairs(KEYBIND_LAYOUT) do
    createSection(sectionData[1]:gsub("KEYBINDS", "CONTROLLER"):gsub(" ", "_"),
        (sectionData[1]:gsub("KEYBINDS", "CONTROLLER")), Controller)
    for _, bind in ipairs(sectionData[2]) do
        UI.ctrlKey[bind[2]] = createKeybindRow(bind[1], bind[1], "NONE", Controller)
    end
end

--------------------------------------------------------------------------------
-- TAB: UTILITY (VISUAL)
--------------------------------------------------------------------------------
createSection("Players", "PLAYERS", Utility)
UI.toggle["ESP"]                = createToggle("ESP", "ESP", Utility, false)
UI.toggle["Show Tracer"]        = createToggle("Show Tracer", "Show Tracer", Utility, false)
UI.toggle["Ragdoll Countdown"]  = createToggle("Ragdoll Countdown", "Ragdoll Countdown", Utility, false)

createSection("Visual", "VISUAL", Utility)
UI.pick["Custom Sky"]           = createPickerRow("Custom Sky", "Custom Sky", "Off", Utility)
UI.pick["Anim Pack"]            = createPickerRow("Anim Pack", "Anim Pack", "OFF", Utility)
UI.toggle["Try Hard Animation"] = createToggle("Try Hard Animation", "Try Hard Animation", Utility, false)

createSection("Performance", "PERFORMANCE", Utility)
UI.toggle["Stretch Res"]        = createToggle("Stretch Res", "Stretch Res", Utility, false)
UI.toggle["Anti Lag"]           = createToggle("Anti Lag", "Anti-Lag", Utility, false)
UI.toggle["Nuke Optimiser"]     = createToggle("Nuke Optimiser", "Nuke Optimiser", Utility, false)
UI.toggle["FOV Change"]         = createToggle("FOV Change", "FOV Change", Utility, false)
UI.value["FOV Value"]           = createValueRow("FOV Value", "FOV Value", "70", Utility)
UI.toggle["No Cam Collision"]   = createToggle("No Cam Collision", "No Cam Collision", Utility, false)

--------------------------------------------------------------------------------
-- TAB: SETTINGS
--------------------------------------------------------------------------------
createSection("Mobile Buttons", "MOBILE BUTTONS", Settings)
UI.toggle["Circle Buttons"]     = createToggle("Circle Buttons", "Circle Buttons", Settings, false)
UI.toggle["Hide Mob Buttons"]   = createToggle("Hide Mob Buttons", "Hide Mob Buttons", Settings, false)
UI.value["Button Size %"]       = createValueRow("Button Size %", "Button Size %", "100", Settings)
UI.toggle["Move Buttons"]       = createToggle("Move Buttons", "Move Buttons", Settings, false)
UI.action["Reset Buttons"]      = createActionButton("Reset Buttons", "Reset Buttons", Settings)

createSection("Interface", "INTERFACE", Settings)
UI.toggle["Intro Song"]         = createToggle("Intro Song", "Intro Song", Settings, false)
UI.toggle["Intro"]              = createToggle("Intro", "Intro", Settings, false)

createSection("Background", "BACKGROUND", Settings)
UI.gallery.Background = createThumbnailGallery("BackgroundPicker", {
    "",
    "rbxassetid://90631990302263",
    "rbxassetid://109619268613730",
    "rbxassetid://88369503310562",
    "rbxassetid://80708025126373",
    "rbxassetid://102253425322931",
    "rbxassetid://90453834580322",
    "rbxassetid://135181794444219",
}, Settings, "Bg")

createSection("Buttons Image", "BUTTONS IMAGE", Settings)
UI.gallery.Buttons = createThumbnailGallery("ButtonsImagePicker", {
    "",
    "rbxassetid://90631990302263",
    "rbxassetid://111941119745474",
    "rbxassetid://88369503310562",
    "rbxassetid://80708025126373",
    "rbxassetid://102253425322931",
    "rbxassetid://138739435956313",
    "rbxassetid://135181794444219",
}, Settings, "BtnImg")

UI.colorPicker = createColorThemePicker(Settings)
UI.toggle["Background Color"]   = createToggle("Background Color", "Background Color", Settings, false)

createSection("UI Scale", "UI SCALE", Settings)
UI.value["UI Scale"]            = createValueRow("UI Scale", "UI Scale", "85", Settings)
UI.value["Steal Bar Size"]      = createValueRow("Steal Bar Size", "Steal Bar Size", "100", Settings)

UI.action["SAVE SETTINGS"]      = createActionButton("SAVE SETTINGS", "SAVE SETTINGS", Settings)
UI.action["RESET ALL SETTINGS"] = createActionButton("RESET ALL SETTINGS", "RESET ALL SETTINGS", Settings)

--------------------------------------------------------------------------------
-- TABS BAR
--------------------------------------------------------------------------------
local Tabs = new("Frame", {
    Name = "Tabs",
    ZIndex = 3,
    Position = UDim2.new(0, 13, 1, -44),
    Size = UDim2.new(1, -26, 0, 34),
    BackgroundTransparency = 1,
    Parent = Main,
})
new("UIListLayout", {
    Padding = UDim.new(0, 6),
    FillDirection = Enum.FillDirection.Horizontal,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = Tabs,
})

for _, def in ipairs({
    {"Movement",  "MOVEMENT", 1, true},
    {"Combat",    "COMBAT",   2, false},
    {"Keybinds",  "KBM",      3, false},
    {"Controller","CTRL",     4, false},
    {"Utility",   "VISUAL",   5, false},
    {"Settings",  "SETTINGS", 6, false},
}) do
    createTabButton(def[1], def[2], def[3], def[4], Tabs)
end

--------------------------------------------------------------------------------
-- FLOATING OPEN BUTTON
--------------------------------------------------------------------------------
local WokeFloatOpen = new("Frame", {
    Name = "WokeFloatOpen",
    Visible = false,
    Active = true,
    ZIndex = 500,
    Position = UDim2.new(0, 14, 0.4, 0),
    Size = UDim2.new(0, 110, 0, 32),
    BackgroundColor3 = Color3.fromRGB(14, 14, 18),
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,
    Parent = WokeGui,
})
new("UICorner", {Parent = WokeFloatOpen})
new("UIStroke", {Color = WHITE, Transparency = 0.45, Parent = WokeFloatOpen})

local FloatButton = new("ImageButton", {
    Name = "FloatButton",
    ZIndex = 501,
    Position = UDim2.new(0, 4, 0, 4),
    Size = UDim2.new(1, -8, 1, -8),
    BackgroundTransparency = 1,
    Image = "rbxassetid://92966351305582",
    ScaleType = Enum.ScaleType.Fit,
    AutoButtonColor = false,
    Parent = WokeFloatOpen,
})

--------------------------------------------------------------------------------
-- MOBILE BUTTONS
--------------------------------------------------------------------------------
local MobileButtons = new("Frame", {
    Name = "MobileButtons",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Parent = WokeGui,
})

local MOBILE_DEFAULTS = {
    {"Drop Brainrot",  "DROP BRAINROT",  UDim2.new(1, -132, 0.5, -161), UDim2.new(0, 58, 0, 58)},
    {"Auto Right",     "AUTO RIGHT",     UDim2.new(1, -66,  0.5, -161), UDim2.new(0, 58, 0, 58)},
    {"Bat Aimbot",     "BAT AIMBOT",     UDim2.new(1, -132, 0.5, -95),  UDim2.new(0, 58, 0, 58)},
    {"Auto Left",      "AUTO LEFT",      UDim2.new(1, -66,  0.5, -95),  UDim2.new(0, 58, 0, 58)},
    {"TP Down",        "TP DOWN",        UDim2.new(1, -132, 0.5, -29),  UDim2.new(0, 58, 0, 58)},
    {"Lagger Mode",    "LAGGER MODE",    UDim2.new(1, -66,  0.5, -29),  UDim2.new(0, 58, 0, 58)},
    {"TP Bat",         "TP BAT",         UDim2.new(1, -132, 0.5, 37),   UDim2.new(0, 58, 0, 58)},
    {"Carry Speed",    "CARRY SPEED",    UDim2.new(1, -66,  0.5, 37),   UDim2.new(0, 58, 0, 58)},
    {"Instant Reset",  "INSTANT RESET",  UDim2.new(1, -132, 0.5, 103),  UDim2.new(0, 124, 0, 58)},
    {"Speed Bypass",   "SPEED BYPASS",   UDim2.new(1, -132, 0.5, -227), UDim2.new(0, 124, 0, 58)},
}

for _, def in ipairs(MOBILE_DEFAULTS) do
    UI.mobile[def[1]] = createMobileButton(def[1], def[2], def[3], def[4], MobileButtons)
end

--------------------------------------------------------------------------------
-- SPEED BYPASS PANEL
--
-- Its own ScreenGui rather than a frame inside the hub, so it can stay on
-- screen with the main window closed and be dragged wherever it suits.
--------------------------------------------------------------------------------
local BypassGui = new("ScreenGui", {
    Name = "WokeSpeedBypass",
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    DisplayOrder = 1001,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = PlayerGui,
})

local BypassPanel = new("Frame", {
    Name = "Panel",
    Active = true,
    ClipsDescendants = true,
    Position = UDim2.new(0.5, -134, 0, 56),
    Size = UDim2.new(0, 268, 0, 232),
    BackgroundColor3 = DARK_BG,
    BackgroundTransparency = 0.12,
    BorderSizePixel = 0,
    Parent = BypassGui,
})
new("UICorner", {CornerRadius = UDim.new(0, 13), Parent = BypassPanel})
addDarkBorderGradient(new("UIStroke", {
    Color = WHITE, Thickness = 1.2,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    Parent = BypassPanel,
}))
local BypassScale = new("UIScale", {Scale = 0.9, Parent = BypassPanel})

-- The header doubles as the drag handle.
local BypassHeader = new("TextButton", {
    Name = "Header",
    ZIndex = 2,
    Size = UDim2.new(1, 0, 0, 58),
    BackgroundTransparency = 1,
    Text = "",
    AutoButtonColor = false,
    Parent = BypassPanel,
})

createWordmark("BypassTitle", "SPEED BYPASS", BypassHeader,
    UDim2.new(0, 12, 0, 8), UDim2.new(1, -58, 0, 30), 3, 21)

new("TextLabel", {
    Name = "BypassSubtitle",
    ZIndex = 5,
    Position = UDim2.new(0, 14, 0, 36),
    Size = UDim2.new(1, -58, 0, 14),
    BackgroundTransparency = 1,
    Text = "WOKE  ·  discord.gg/adaptt",
    TextColor3 = MUTED_TEXT,
    TextSize = 10,
    Font = Enum.Font.GothamBlack,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = BypassHeader,
})

local BypassClose = new("TextButton", {
    Name = "BypassClose",
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
    Parent = BypassPanel,
})
new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = BypassClose})
addDarkBorderGradient(new("UIStroke", {
    Color = WHITE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = BypassClose,
}))

local BypassRows = new("Frame", {
    Name = "Rows",
    ZIndex = 3,
    Position = UDim2.new(0, 8, 0, 60),
    Size = UDim2.new(1, -16, 1, -68),
    BackgroundTransparency = 1,
    Parent = BypassPanel,
})
new("UIListLayout", {
    Padding = UDim.new(0, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = BypassRows,
})

local BypassState  = createStateRow("Main Feature", "Main Feature", BypassRows)
local BypassPower  = createValueRow("Power", "Power", "100000", BypassRows)
UI.altKey["SpeedBypass"] = createKeybindRow("Keybind", "Keybind", "NONE", BypassRows)
local BypassSpeed  = createReadoutRow("Speed", "Speed", BypassRows)

--============================================================================--
--                                  WIRING                                    --
--============================================================================--

--------------------------------------------------------------------------------
-- Small binding helpers
--------------------------------------------------------------------------------
local function saveSoon()
    task.spawn(function() pcall(saveAceConfig) end)
end

-- Drop brainrot, in the mode the selector under the Drop row is set to.
-- JUMP is the Ace routine: ascend for a moment, then slam down onto the floor.
-- STAND does only the floor snap, so the character never leaves the ground.
local function dropStand()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if _G.AceStopAutoTPForAction then _G.AceStopAutoTPForAction() end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local hit = workspace:Raycast(root.Position, Vector3.new(0, -2000, 0), params)
    if hit then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local offset = (hum and hum.HipHeight or 2) + (root.Size.Y / 2)
        root.CFrame = CFrame.new(root.Position.X, hit.Position.Y + offset, root.Position.Z)
    end
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
end

-- Every drop entry point goes through here: the row, the keybind and the
-- mobile button all have to honour the JUMP/STAND selector.
local function runDrop()
    if _G.WokeDropMode == "Stand" then dropStand() else runDropBrainrot() end
end

-- Toggle bound to a piece of state: read() reports it, apply(state) changes it.
local function bindToggle(api, read, apply)
    if not api then return end
    api.read = read
    api.setVisual(read() == true)
    api.button.MouseButton1Click:Connect(function()
        local nextState = not (read() == true)
        local ok, err = pcall(apply, nextState)
        if not ok then warn("[WOKE] toggle failed: " .. tostring(err)) end
        api.setVisual(read() == true)
        saveSoon()
    end)
end

-- Toggle row used as a momentary button (drop, tp down, insta reset...).
local function bindAction(api, fn)
    if not api then return end
    api.button.MouseButton1Click:Connect(function()
        api.setVisual(true)
        pcall(fn)
        task.delay(0.25, function() api.setVisual(false) end)
    end)
end

local function bindValue(handle, read, apply, minValue, maxValue)
    if not handle then return end
    local box = handle.box
    handle.refresh = function() box.Text = tostring(read()) end
    handle.refresh()
    box.FocusLost:Connect(function()
        local v = tonumber(box.Text)
        if v and v >= minValue and v <= maxValue then
            pcall(apply, v)
        end
        box.Text = tostring(read())
        saveSoon()
    end)
end

local function bindExpandable(api, read, apply)
    if not api then return end
    api.setIndex(read(), true)
    api.onChange = function(idx)
        pcall(apply, idx)
        saveSoon()
    end
    api.refresh = function() api.setIndex(read(), true) end
end

--------------------------------------------------------------------------------
-- SPEED BYPASS
--
-- The speed modes drive the humanoid, so they are limited by how fast the
-- humanoid is allowed to walk — that is why Normal tops out around 59.5. The
-- bypass does not touch that loop. It leaves the humanoid walking at its
-- normal speed and moves the root part the *extra* distance itself, one frame
-- at a time, along whatever direction the player is already holding.
--
-- Each frame's extra distance is walked in short hops with a raycast in front
-- of every hop, so the character slides along the ground instead of punching
-- through walls, and it ramps in and out instead of snapping.
--
-- POWER is the dial: POWER_PER_STUD power buys one extra stud/second, so the
-- default 100000 is +50 studs/s on top of the current speed mode.
--------------------------------------------------------------------------------
local BYPASS_POWER_DEFAULT = 100000
local BYPASS_POWER_MIN     = 1000
local BYPASS_POWER_MAX     = 1000000
local BYPASS_POWER_PER_STUD = 2000
local BYPASS_DEFAULT_KEY   = Enum.KeyCode.CapsLock
local BYPASS_MAX_HOP       = 3.5   -- studs per raycast-checked hop
local BYPASS_MAX_HOPS      = 16
local BYPASS_WALL_SKIN     = 1.6   -- clearance kept in front of the root part
local BYPASS_RAMP          = 7     -- how quickly the boost eases in and out

_G.WokeBypassPower = tonumber(_G.WokeBypassPower) or BYPASS_POWER_DEFAULT
_G.WokeBypassEnabled = _G.WokeBypassEnabled == true
if speedKeybinds.SpeedBypass == nil then
    speedKeybinds.SpeedBypass = BYPASS_DEFAULT_KEY
end

local bypassBoost = 0          -- ramped bonus speed, studs/second
local bypassRayParams = RaycastParams.new()
bypassRayParams.FilterType = Enum.RaycastFilterType.Exclude

local refreshBypassPanel   -- assigned below, once the readouts are bound

local function bypassPower()
    return math.clamp(tonumber(_G.WokeBypassPower) or BYPASS_POWER_DEFAULT,
        BYPASS_POWER_MIN, BYPASS_POWER_MAX)
end

local function bypassBonusSpeed()
    return bypassPower() / BYPASS_POWER_PER_STUD
end

local function bypassBaseSpeed()
    local base = 0
    pcall(function() base = getCurrentSpeedValue() or 0 end)
    return base
end

-- Anything that steers the character itself has to win: running both would
-- tear the root part between two positions on every frame.
local function bypassSuspended()
    if _G.AceNormalAimbotOn == true then return true end
    if _G.AceAntiBypassAimbotOn == true then return true end
    if _G.AceAntiDesyncAimbotOn == true then return true end
    if autoLeftEnabled == true or autoRightEnabled == true then return true end
    if dropBrainrotActive == true then return true end
    -- Safe Mode holds everything else back during a duel countdown or while
    -- carrying, and a sudden speed jump is the loudest thing in this hub.
    if _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then return true end
    return false
end

-- One frame of bypass movement. Exposed so it can be driven directly in tests.
local function bypassStep(dt)
    if not (_G.WokeBypassEnabled == true) then bypassBoost = 0 return end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or (hum.Health or 0) <= 0 then bypassBoost = 0 return end
    if bypassSuspended() then bypassBoost = 0 return end

    local state = hum:GetState()
    if hum.PlatformStand
        or state == Enum.HumanoidStateType.Physics
        or state == Enum.HumanoidStateType.Ragdoll
        or state == Enum.HumanoidStateType.FallingDown
        or state == Enum.HumanoidStateType.Seated then
        bypassBoost = 0
        return
    end

    local move = hum.MoveDirection
    local flat = move and Vector3.new(move.X, 0, move.Z) or Vector3.zero
    if flat.Magnitude < 0.05 then bypassBoost = 0 return end
    local dir = flat.Unit

    local target = bypassBonusSpeed()
    bypassBoost = bypassBoost + (target - bypassBoost) * math.min((dt or 0) * BYPASS_RAMP, 1)

    -- Cap the frame delta: after a hitch, dt can be large enough that one
    -- frame's catch-up would read as a teleport.
    local distance = bypassBoost * math.min(dt or 0, 1 / 30)
    if distance <= 0.001 then return end

    bypassRayParams.FilterDescendantsInstances = {char}
    local hops = math.clamp(math.ceil(distance / BYPASS_MAX_HOP), 1, BYPASS_MAX_HOPS)
    local hop = distance / hops
    for _ = 1, hops do
        if workspace:Raycast(root.Position, dir * (hop + BYPASS_WALL_SKIN), bypassRayParams) then
            break
        end
        root.CFrame = root.CFrame + dir * hop
    end
end

local function setBypass(state)
    state = state == true
    if _G.WokeBypassEnabled == state then return end
    _G.WokeBypassEnabled = state
    if not state then bypassBoost = 0 end
    if refreshBypassPanel then refreshBypassPanel() end
    if UI.toggle["Speed Bypass"] then UI.toggle["Speed Bypass"].setVisual(state) end
    saveSoon()
end

local function setBypassPower(value)
    _G.WokeBypassPower = math.clamp(tonumber(value) or BYPASS_POWER_DEFAULT,
        BYPASS_POWER_MIN, BYPASS_POWER_MAX)
    if refreshBypassPanel then refreshBypassPanel() end
end

_G.WokeSetBypass = setBypass
_G.WokeToggleBypass = function() setBypass(not (_G.WokeBypassEnabled == true)) end
_G.WokeBypassStep = bypassStep
_G.WokeBypassSpeed = function() return bypassBaseSpeed() + (_G.WokeBypassEnabled and bypassBonusSpeed() or 0) end

RunService.RenderStepped:Connect(bypassStep)

-- Panel controls.
do
    refreshBypassPanel = function()
        local on = _G.WokeBypassEnabled == true
        BypassState.setVisual(on)
        -- Never stomp the box the player is typing into.
        if UserInputService:GetFocusedTextBox() ~= BypassPower.box then
            BypassPower.box.Text = tostring(math.floor(bypassPower() + 0.5))
        end
        local base = bypassBaseSpeed()
        BypassSpeed.value.Text = on
            and string.format("%.1f → %.1f", base, base + bypassBonusSpeed())
            or string.format("%.1f", base)
    end

    BypassState.button.MouseButton1Click:Connect(function()
        setBypass(not (_G.WokeBypassEnabled == true))
    end)

    BypassPower.box.FocusLost:Connect(function()
        -- Anything that is not a number leaves the power where it was; the
        -- refresh below puts the old value back in the box.
        local typed = tonumber(BypassPower.box.Text)
        if typed then setBypassPower(typed) else refreshBypassPanel() end
        if UI.value["Bypass Power"] then
            UI.value["Bypass Power"].box.Text = tostring(math.floor(bypassPower() + 0.5))
        end
        saveSoon()
    end)

    BypassClose.MouseButton1Click:Connect(function()
        _G.WokeBypassPanelOpen = false
        BypassPanel.Visible = false
        if UI.toggle["Bypass Panel"] then UI.toggle["Bypass Panel"].setVisual(false) end
        saveSoon()
    end)

    refreshBypassPanel()
end

--------------------------------------------------------------------------------
-- MOVEMENT wiring
--------------------------------------------------------------------------------
do
    bindValue(UI.value["Normal Speed"], function() return NS end, function(v) NS = v end, 1, 250)
    bindValue(UI.value["Carry Speed"], function() return CS end, function(v) CS = v end, 1, 250)
    bindValue(UI.value["Lagger Normal Speed"], function() return LAGGER_SPEED end, function(v) LAGGER_SPEED = v end, 1, 250)
    bindValue(UI.value["Lagger Carry Speed"], function() return LAGGER_CARRY_SPEED end, function(v) LAGGER_CARRY_SPEED = v end, 1, 250)
    bindValue(UI.value["Auto TP Height"], function() return autoTPHeight end, function(v) autoTPHeight = v end, -500, 500)

    -- MODE rows: the speed row flips Normal/Carry, the lagger row cycles the
    -- two lagger modes. refreshSpeedModeRows is the hook setSpeedMode calls.
    local speedRow = UI.mode["Speed Mode"]
    local laggerRow = UI.mode["Lagger Mode"]

    refreshSpeedModeRows = function()
        local mode = currentSpeedMode
        if speedRow then
            speedRow.value.Text = (mode == "Carry") and "CARRY" or "NORMAL"
        end
        if laggerRow then
            if mode == "Lagger" then
                laggerRow.value.Text = "LAGGER NORMAL"
            elseif mode == "Lagger Carry" then
                laggerRow.value.Text = "LAGGER CARRY"
            else
                laggerRow.value.Text = "OFF"
            end
        end
    end

    speedRow.button.MouseButton1Click:Connect(function()
        setSpeedMode(currentSpeedMode == "Carry" and "Normal" or "Carry")
    end)
    laggerRow.button.MouseButton1Click:Connect(function()
        if currentSpeedMode == "Lagger" then
            setSpeedMode("Lagger Carry")
        elseif currentSpeedMode == "Lagger Carry" then
            setSpeedMode("Normal")
        else
            setSpeedMode("Lagger")
        end
    end)
    refreshSpeedModeRows()

    bindToggle(UI.toggle["Auto Carry Speed"],
        function() return autoCarrySpeedEnabled end,
        function(state)
            autoCarrySpeedEnabled = state
            if not state and _G.AutoCarrySpeed and _G.AutoCarrySpeed.Disable then
                _G.AutoCarrySpeed.Disable()
            end
        end)
    setAutoCarrySpeedVisual = function(state) UI.toggle["Auto Carry Speed"].setVisual(state) end

    -- The bypass controls exist twice: here and on the standalone panel. Both
    -- read and write the same globals, and each refreshes the other.
    bindToggle(UI.toggle["Speed Bypass"],
        function() return _G.WokeBypassEnabled == true end,
        function(state) setBypass(state) end)

    bindValue(UI.value["Bypass Power"],
        function() return math.floor(bypassPower() + 0.5) end,
        function(v) setBypassPower(v) end,
        BYPASS_POWER_MIN, BYPASS_POWER_MAX)

    bindToggle(UI.toggle["Bypass Panel"],
        function() return _G.WokeBypassPanelOpen == true end,
        function(state)
            _G.WokeBypassPanelOpen = state
            BypassPanel.Visible = state
        end)

    bindExpandable(UI.expand["Drop"], function() return _G.WokeDropMode == "Stand" and 2 or 1 end,
        function(idx) _G.WokeDropMode = (idx == 2) and "Stand" or "Jump" end)
    bindAction(UI.toggle["Drop"], runDrop)

    bindAction(UI.toggle["TP Down"], runTPFloor)

    bindToggle(UI.toggle["Auto TP Down"],
        function() return autoTPEnabled end,
        function(state) toggleAutoTP(state) end)
    setAutoTPVisual = function(state) UI.toggle["Auto TP Down"].setVisual(state) end

    bindToggle(UI.toggle["Infinite Jump"],
        function() return infJumpEnabled end,
        function(state) setInfJumpInternal(state) end)

    bindToggle(UI.toggle["Anti Ragdoll"],
        function() return antiRagdollEnabled end,
        function(state) setAntiRagdoll(state) end)

    bindToggle(UI.toggle["Unwalk"],
        function() return unwalkEnabled end,
        function(state)
            if state then
                selectedAnimationPack = "Unwalk"
                applyAnimationPack("Unwalk")
            else
                selectedAnimationPack = "OFF"
                disableUnwalk()
                applyAnimationPack("OFF")
            end
            if UI.pick["Anim Pack"] and UI.pick["Anim Pack"].refresh then UI.pick["Anim Pack"].refresh() end
        end)
end

--------------------------------------------------------------------------------
-- COMBAT wiring
--------------------------------------------------------------------------------
do
    bindValue(UI.value["Radius"],
        function() return _G.AceStealRadii.Normal or 62 end,
        function(v)
            _G.AceStealRadii.Normal = v
            if selectedStealMode == "Normal" then autoStealRadius = v end
            if _G.AceNormalAutoStealSetRadius then _G.AceNormalAutoStealSetRadius(v) end
        end, 1, 500)

    bindValue(UI.value["SEMI Range"],
        function() return _G.AceStealRadii.Semi or 9 end,
        function(v)
            _G.AceStealRadii.Semi = v
            if selectedStealMode == "Semi" then autoStealRadius = v end
            if _G.AceSemiAutoStealSetRadius then _G.AceSemiAutoStealSetRadius(v) end
        end, 1, 500)

    bindExpandable(UI.expand["Auto Steal"],
        function() return selectedStealMode == "Semi" and 2 or 1 end,
        function(idx)
            selectedStealMode = (idx == 2) and "Semi" or "Normal"
            autoStealRadius = _G.AceStealRadii[selectedStealMode] or ((selectedStealMode == "Semi") and 9 or 62)
            if _G.AceAutoStealSync then _G.AceAutoStealSync() end
        end)

    bindToggle(UI.toggle["Auto Steal"],
        function() return autoStealEnabled end,
        function(state)
            autoStealEnabled = state
            if _G.AceAutoStealSync then _G.AceAutoStealSync() end
        end)

    -- Bat aimbot: the selector picks Normal / Anti Bypass, the toggle starts it.
    bindExpandable(UI.expand["Bat Aimbot"],
        function() return selectedAimbotMode == "Anti Bypass" and 2 or 1 end,
        function(idx)
            local wasOn = (_G.AceNormalAimbotOn == true) or (_G.AceAntiBypassAimbotOn == true)
            if wasOn then
                if _G.AceStopNormalAimbot then _G.AceStopNormalAimbot() end
                if _G.AceStopAntiBypassAimbot then _G.AceStopAntiBypassAimbot() end
            end
            selectedAimbotMode = (idx == 2) and "Anti Bypass" or "Normal"
            if UI.value["Auto Bat Speed"] and UI.value["Auto Bat Speed"].refresh then
                UI.value["Auto Bat Speed"].refresh()
            end
            if wasOn and _G.AceToggleSelectedAimbot then _G.AceToggleSelectedAimbot() end
        end)

    bindToggle(UI.toggle["Bat Aimbot"],
        function() return (_G.AceNormalAimbotOn == true) or (_G.AceAntiBypassAimbotOn == true) end,
        function()
            if _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
                if _G.AceSafeModeForceStop then _G.AceSafeModeForceStop("SAFE MODE LOCK") end
                return
            end
            if _G.AceToggleSelectedAimbot then _G.AceToggleSelectedAimbot() end
        end)

    -- Let the logic drive the toggle visual when a keybind or mobile button
    -- flips the aimbot on/off.
    _G.AceAimbotSetVisual = function(state) UI.toggle["Bat Aimbot"].setVisual(state) end
    _G.AceMirrorTPDownSetVisual = function(state) UI.toggle["Mirror TP"].setVisual(state) end

    bindValue(UI.value["Auto Bat Speed"],
        function()
            if selectedAimbotMode == "Anti Bypass" then return _G.AceAntiBypassAimbotSpeed or 58 end
            return AIMBOT_SPEED
        end,
        function(v)
            if _G.AceSetSelectedAimbotSpeedValues then
                _G.AceSetSelectedAimbotSpeedValues(v, nil)
            elseif selectedAimbotMode == "Anti Bypass" then
                _G.AceAntiBypassAimbotSpeed = v
            else
                AIMBOT_SPEED = v
            end
        end, 1, 250)

    bindToggle(UI.toggle["Auto Swing"],
        function() return autoSwingEnabled end,
        function(state) autoSwingEnabled = state end)

    bindToggle(UI.toggle["Mirror TP"],
        function() return mirrorTPDownEnabled end,
        function(state)
            if _G.AceSetMirrorTPDown then _G.AceSetMirrorTPDown(state) else mirrorTPDownEnabled = state end
        end)

    bindExpandable(UI.expand["TP Bat"],
        function() return antiDesyncAutoSwingEnabled and 1 or 2 end,
        function(idx) antiDesyncAutoSwingEnabled = (idx == 1) end)

    bindToggle(UI.toggle["TP Bat"],
        function() return _G.AceAntiDesyncAimbotOn == true end,
        function()
            if _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
                if _G.AceSafeModeForceStop then _G.AceSafeModeForceStop("SAFE MODE LOCK") end
                return
            end
            if _G.AceToggleAntiDesyncAimbot then _G.AceToggleAntiDesyncAimbot() end
        end)

    bindToggle(UI.toggle["Auto Left"],
        function() return autoLeftEnabled end,
        function(state) if _G.AceSetAutoLeft then _G.AceSetAutoLeft(state) end end)

    bindToggle(UI.toggle["Auto Right"],
        function() return autoRightEnabled end,
        function(state) if _G.AceSetAutoRight then _G.AceSetAutoRight(state) end end)

    bindToggle(UI.toggle["Bat Counter"],
        function() return batCounterEnabled end,
        function(state)
            batCounterEnabled = state
            if state then
                if _G.AceStartBatCounter then _G.AceStartBatCounter() end
            else
                if _G.AceStopBatCounter then _G.AceStopBatCounter() end
            end
        end)

    bindToggle(UI.toggle["Medusa Counter"],
        function() return medCounterEnabled end,
        function(state)
            medCounterEnabled = state
            if state then
                if _G.AceStartMedCounter then _G.AceStartMedCounter(LocalPlayer.Character) end
            else
                if _G.AceStopMedCounter then _G.AceStopMedCounter() end
            end
        end)

    bindToggle(UI.toggle["Reset After Med"],
        function() return autoResetOnMedEnabled end,
        function(state)
            if _G.AceSetAutoResetOnMed then _G.AceSetAutoResetOnMed(state) else autoResetOnMedEnabled = state end
        end)
    setAutoResetOnMedVisual = function(state) UI.toggle["Reset After Med"].setVisual(state) end

    bindAction(UI.toggle["Insta Reset"], function()
        if _G.AceCursedInstaReset then _G.AceCursedInstaReset() end
    end)

    bindToggle(UI.toggle["Safe Mode"],
        function() return antiKickEnabled end,
        function(state)
            antiKickEnabled = state
            if state and _G.AceSafeModeForceStop then _G.AceSafeModeForceStop("SAFE MODE") end
        end)
    setSafeModeVisual = function(state) UI.toggle["Safe Mode"].setVisual(state) end

    bindToggle(UI.toggle["Anti Bodylock"],
        function() return _G.AceAntiBodylockEnabled == true end,
        function(state)
            if state then enableAntiBodylock() else disableAntiBodylock() end
        end)
    setAntiBodylockVisual = function(state) UI.toggle["Anti Bodylock"].setVisual(state) end

    bindToggle(UI.toggle["No Player Collision"],
        function() return _G.AceNoPlayerCollisionEnabled == true end,
        function(state)
            _G.AceNoPlayerCollisionEnabled = state
            if state then enableNoPlayerCollision() else disableNoPlayerCollision() end
        end)
    _G.AceSetNoPlayerCollisionVisual = function(state) UI.toggle["No Player Collision"].setVisual(state) end
end

--------------------------------------------------------------------------------
-- UTILITY wiring
--------------------------------------------------------------------------------
do
    bindToggle(UI.toggle["ESP"],
        function() return espEnabled end,
        function(state)
            espEnabled = state
            if state then
                if startPlayerESP then startPlayerESP() end
            else
                if stopPlayerESP then stopPlayerESP() end
            end
            if BoxedESPOptions then BoxedESPOptions.box = state end
            if refreshBoxedESP then refreshBoxedESP() end
        end)
    setPlayerESPVisual = function(state) UI.toggle["ESP"].setVisual(state) end

    bindToggle(UI.toggle["Show Tracer"],
        function() return showTracerEnabled end,
        function(state)
            showTracerEnabled = state
            if BoxedESPOptions then
                BoxedESPOptions.tracer = state
                BoxedESPOptions.box = espEnabled == true
            end
            if refreshBoxedESP then refreshBoxedESP() end
        end)
    setTracerESPVisual = function(state) UI.toggle["Show Tracer"].setVisual(state) end

    bindToggle(UI.toggle["Ragdoll Countdown"],
        function() return ragdollCountdownEnabled end,
        function(state)
            ragdollCountdownEnabled = state
            if state then hookRagdollCountdown(LocalPlayer.Character) else stopRagdollCountdown() end
        end)
    setRagdollCountdownVisual = function(state) UI.toggle["Ragdoll Countdown"].setVisual(state) end

    local skyPick = UI.pick["Custom Sky"]
    skyPick.setOptions(SKY_PRESETS_LIST or {"Off"}, skyTheme)
    skyPick.onChange = function(name)
        skyTheme = name
        if type(applyCustomSky) == "function" then pcall(applyCustomSky, name) end
        saveSoon()
    end
    skyPick.refresh = function() skyPick.setOptions(SKY_PRESETS_LIST or {"Off"}, skyTheme) end

    local animPick = UI.pick["Anim Pack"]
    animPick.setOptions(AnimationPackList, selectedAnimationPack)
    animPick.onChange = function(name)
        pcall(applyAnimationPack, name)
        if syncAnimationPackIndex then syncAnimationPackIndex() end
        if UI.toggle["Unwalk"] then UI.toggle["Unwalk"].setVisual(unwalkEnabled == true) end
        if UI.toggle["Try Hard Animation"] then UI.toggle["Try Hard Animation"].setVisual(name == "Hit Harder") end
        saveSoon()
    end
    animPick.refresh = function() animPick.setOptions(AnimationPackList, selectedAnimationPack) end
    refreshAnimationPackRow = animPick.refresh

    bindToggle(UI.toggle["Try Hard Animation"],
        function() return selectedAnimationPack == "Hit Harder" end,
        function(state)
            if state then
                selectedAnimationPack = "Hit Harder"
                applyAnimationPack("Hit Harder")
            else
                selectedAnimationPack = "OFF"
                applyAnimationPack("OFF")
            end
            animPick.refresh()
        end)

    bindToggle(UI.toggle["Stretch Res"],
        function() return fpsBoostEnabled end,
        function(state)
            fpsBoostEnabled = state
            if state then enableStretchRez() else disableStretchRez() end
        end)
    setFPSBoostVisual = function(state) UI.toggle["Stretch Res"].setVisual(state) end

    bindToggle(UI.toggle["Anti Lag"],
        function() return antiLagVisualEnabled end,
        function(state) if state then enableAntiLag() else disableAntiLag() end end)
    setAntiLagVisual = function(state) UI.toggle["Anti Lag"].setVisual(state) end

    bindToggle(UI.toggle["Nuke Optimiser"],
        function() return nukeOptimiserEnabled end,
        function(state) if state then enableNukeOptimizer() else disableNukeOptimizer() end end)
    setNukeOptimiserVisual = function(state) UI.toggle["Nuke Optimiser"].setVisual(state) end

    bindToggle(UI.toggle["FOV Change"],
        function() return fovEnabled end,
        function(state) if state then enableCustomFov() else disableCustomFov() end end)
    setFOVVisual = function(state) UI.toggle["FOV Change"].setVisual(state) end

    bindValue(UI.value["FOV Value"],
        function() return fovValue end,
        function(v)
            fovValue = v
            if fovEnabled and workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = v end
        end, 30, 120)

    bindToggle(UI.toggle["No Cam Collision"],
        function() return noCamCollisionEnabled end,
        function(state) if state then enableNoCamCollision() else disableNoCamCollision() end end)
    setNoCamCollisionVisual = function(state) UI.toggle["No Cam Collision"].setVisual(state) end
end

--------------------------------------------------------------------------------
-- KEYBINDS + CONTROLLER wiring
--------------------------------------------------------------------------------
_G.WokeControllerBinds = _G.WokeControllerBinds or {}

local listeningRow = nil       -- {handle=, keyId=, controller=}

local function keyText(key)
    if not key then return "NONE" end
    return (tostring(key):gsub("Enum.KeyCode.", ""))
end

local function currentBind(keyId, controller)
    if controller then return _G.WokeControllerBinds[keyId] end
    if keyId == "TPDown" then return tpDownKeybind end
    return speedKeybinds[keyId]
end

local function setBind(keyId, key, controller)
    if controller then
        for otherId, bound in pairs(_G.WokeControllerBinds) do
            if otherId ~= keyId and bound == key then _G.WokeControllerBinds[otherId] = nil end
        end
        _G.WokeControllerBinds[keyId] = key
        return
    end
    if key then
        for otherId, bound in pairs(speedKeybinds) do
            if otherId ~= keyId and bound == key then speedKeybinds[otherId] = nil end
        end
        if tpDownKeybind == key and keyId ~= "TPDown" then tpDownKeybind = nil end
    end
    if keyId == "TPDown" then tpDownKeybind = key else speedKeybinds[keyId] = key end
end

local function refreshKeybindButtons()
    for keyId, handle in pairs(UI.key) do
        -- Leave the row that is waiting for a key showing its "..." prompt.
        if not (listeningRow and listeningRow.handle == handle) then
            handle.button.Text = keyText(currentBind(keyId, false))
        end
    end
    for keyId, handle in pairs(UI.altKey) do
        if not (listeningRow and listeningRow.handle == handle) then
            handle.button.Text = keyText(currentBind(keyId, false))
        end
    end
    for keyId, handle in pairs(UI.ctrlKey) do
        if not (listeningRow and listeningRow.handle == handle) then
            handle.button.Text = keyText(currentBind(keyId, true))
        end
    end
end
refreshAllSpeedKeybinds = refreshKeybindButtons
refreshTPDownKeybind = refreshKeybindButtons

do
    local function hookKeyRow(keyId, handle, controller)
        handle.button.MouseButton1Click:Connect(function()
            if listeningRow and listeningRow.handle == handle then
                listeningRow = nil
                refreshKeybindButtons()
                return
            end
            listeningRow = {handle = handle, keyId = keyId, controller = controller}
            keybindListenStartedAt = tick()
            refreshKeybindButtons()
            handle.button.Text = "..."
        end)
        handle.clear.MouseButton1Click:Connect(function()
            if listeningRow and listeningRow.handle == handle then listeningRow = nil end
            setBind(keyId, nil, controller)
            refreshKeybindButtons()
            saveSoon()
        end)
    end

    for keyId, handle in pairs(UI.key) do hookKeyRow(keyId, handle, false) end
    for keyId, handle in pairs(UI.altKey) do hookKeyRow(keyId, handle, false) end
    for keyId, handle in pairs(UI.ctrlKey) do hookKeyRow(keyId, handle, true) end
end

--------------------------------------------------------------------------------
-- SETTINGS wiring
--------------------------------------------------------------------------------
local function applyMobileButtonScale(percent)
    local s = math.clamp(percent, 30, 135) / 100
    for _, api in pairs(UI.mobile) do api.setScale(s) end
end

local function applyMobileButtonCorners(circle)
    for _, api in pairs(UI.mobile) do
        for _, c in ipairs(api.corners) do
            c.CornerRadius = circle and UDim.new(0.5, 0) or UDim.new(0, 10)
        end
    end
end

local function resetMobileButtons()
    for _, def in ipairs(MOBILE_DEFAULTS) do
        local api = UI.mobile[def[1]]
        if api then api.button.Position = def[3] end
    end
    _G.AceMobileButtonPositions = {}
    _G.AceMobileButtonScale = 1
    applyMobileButtonScale(100)
    if UI.value["Button Size %"] and UI.value["Button Size %"].refresh then
        UI.value["Button Size %"].refresh()
    end
end

do
    bindToggle(UI.toggle["Circle Buttons"],
        function() return _G.WokeCircleButtons == true end,
        function(state)
            _G.WokeCircleButtons = state
            applyMobileButtonCorners(state)
        end)

    bindToggle(UI.toggle["Hide Mob Buttons"],
        function() return _G.AceHideMobileButtons == true end,
        function(state)
            _G.AceHideMobileButtons = state
            MobileButtons.Visible = not state
        end)
    _G.AceApplyMobileButtonsHidden = function()
        MobileButtons.Visible = not (_G.AceHideMobileButtons == true)
        UI.toggle["Hide Mob Buttons"].setVisual(_G.AceHideMobileButtons == true)
    end

    -- 135% is the ceiling the saved config clamps to, so the box matches it.
    bindValue(UI.value["Button Size %"],
        function() return math.floor((tonumber(_G.AceMobileButtonScale) or 1) * 100 + 0.5) end,
        function(v)
            _G.AceMobileButtonScale = v / 100
            applyMobileButtonScale(v)
        end, 30, 135)
    _G.AceApplyMobileButtonSize = function()
        applyMobileButtonScale((tonumber(_G.AceMobileButtonScale) or 1) * 100)
    end

    bindToggle(UI.toggle["Move Buttons"],
        function() return _G.WokeMoveButtons == true end,
        function(state) _G.WokeMoveButtons = state end)

    UI.action["Reset Buttons"].button.MouseButton1Click:Connect(function()
        UI.action["Reset Buttons"].flash()
        resetMobileButtons()
        saveSoon()
    end)

    bindToggle(UI.toggle["Intro Song"],
        function() return _G.WokeIntroSongEnabled == true end,
        function(state)
            _G.WokeIntroSongEnabled = state
            if state then
                if playIntroMusic then pcall(playIntroMusic) end
            else
                if stopIntroPlayback then pcall(stopIntroPlayback) end
            end
        end)

    bindToggle(UI.toggle["Intro"],
        function() return _introEnabled == true end,
        function(state) _introEnabled = state end)

    UI.gallery.Background.onSelect = function(index, image)
        _G.WokeBackground = index - 1
        if image == "" then
            BackgroundAsset.ImageTransparency = 1
        else
            BackgroundAsset.Image = image
            BackgroundAsset.ImageTransparency = 0
        end
        saveSoon()
    end

    UI.gallery.Buttons.onSelect = function(_, image)
        _G.WokeButtonImage = image
        for _, api in pairs(UI.mobile) do
            api.overlay.Image = image or ""
            api.overlay.ImageTransparency = (image ~= "" and api.active) and 0.15 or 1
        end
        saveSoon()
    end

    UI.colorPicker.onSelect = function(color)
        _G.WokeThemeColor = color
        uiTween(BackgroundAsset, 0.3, {ImageColor3 = color})
        for _, api in pairs(UI.mobile) do
            uiTween(api.stroke, 0.2, {Color = color})
        end
    end

    bindToggle(UI.toggle["Background Color"],
        function() return _G.WokeBackgroundColorOn == true end,
        function(state)
            _G.WokeBackgroundColorOn = state
            Main.BackgroundTransparency = state and 0 or 1
            if state then Main.BackgroundColor3 = _G.WokeThemeColor or DARK_BG end
        end)

    bindValue(UI.value["UI Scale"],
        function() return math.floor((tonumber(_G.WokeUiScale) or 0.85) * 100 + 0.5) end,
        function(v)
            _G.WokeUiScale = v / 100
            MainScale.Scale = _G.WokeUiScale
            BypassScale.Scale = _G.WokeUiScale
        end, 50, 150)

    bindValue(UI.value["Steal Bar Size"],
        function() return math.floor((tonumber(aceProgressBarScaleValue) or 1) * 100 + 0.5) end,
        function(v)
            aceProgressBarScaleValue = v / 100
            local sg = PlayerGui:FindFirstChild("StealBarGui")
            local bar = sg and sg:FindFirstChild("StealBar")
            if bar then
                local sc = bar:FindFirstChild("AceProgressBarScale") or Instance.new("UIScale")
                sc.Name = "AceProgressBarScale"
                sc.Scale = aceProgressBarScaleValue
                sc.Parent = bar
            end
        end, 50, 200)

    UI.action["SAVE SETTINGS"].button.MouseButton1Click:Connect(function()
        UI.action["SAVE SETTINGS"].flash()
        pcall(saveAceConfig)
    end)

    UI.action["RESET ALL CONTROLLER"].button.MouseButton1Click:Connect(function()
        UI.action["RESET ALL CONTROLLER"].flash()
        _G.WokeControllerBinds = {}
        refreshKeybindButtons()
        saveSoon()
    end)
end

--------------------------------------------------------------------------------
-- MOBILE BUTTON wiring
--------------------------------------------------------------------------------
do
    local actions = {
        ["Drop Brainrot"] = {press = function() runDrop() end, momentary = true},
        ["TP Down"]       = {press = function() runTPFloor() end, momentary = true},
        ["Instant Reset"] = {press = function() if _G.AceCursedInstaReset then _G.AceCursedInstaReset() end end, momentary = true},
        ["Auto Left"]     = {
            press = function() if _G.AceSetAutoLeft then _G.AceSetAutoLeft(not autoLeftEnabled) end end,
            state = function() return autoLeftEnabled == true end,
        },
        ["Auto Right"]    = {
            press = function() if _G.AceSetAutoRight then _G.AceSetAutoRight(not autoRightEnabled) end end,
            state = function() return autoRightEnabled == true end,
        },
        ["Bat Aimbot"]    = {
            press = function()
                if _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
                    if _G.AceSafeModeForceStop then _G.AceSafeModeForceStop("SAFE MODE LOCK") end
                    return
                end
                if _G.AceToggleSelectedAimbot then _G.AceToggleSelectedAimbot() end
            end,
            state = function() return (_G.AceNormalAimbotOn == true) or (_G.AceAntiBypassAimbotOn == true) end,
        },
        ["TP Bat"]        = {
            press = function()
                if _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
                    if _G.AceSafeModeForceStop then _G.AceSafeModeForceStop("SAFE MODE LOCK") end
                    return
                end
                if _G.AceToggleAntiDesyncAimbot then _G.AceToggleAntiDesyncAimbot() end
            end,
            state = function() return _G.AceAntiDesyncAimbotOn == true end,
        },
        ["Carry Speed"]   = {
            press = function() toggleCarryMode() end,
            state = function() return currentSpeedMode == "Carry" end,
        },
        ["Lagger Mode"]   = {
            press = function() toggleLaggerMode() end,
            state = function() return currentSpeedMode == "Lagger" or currentSpeedMode == "Lagger Carry" end,
        },
        ["Speed Bypass"]  = {
            press = function() setBypass(not (_G.WokeBypassEnabled == true)) end,
            state = function() return _G.WokeBypassEnabled == true end,
        },
    }

    for name, api in pairs(UI.mobile) do
        local action = actions[name]
        local btn = api.button
        local pressing, dragging, pressPos, startPos = false, false, nil, nil

        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                pressing = true
                dragging = false
                pressPos = input.Position
                startPos = btn.Position
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if not pressing or not (_G.WokeMoveButtons == true) then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local delta = input.Position - pressPos
            if not dragging and (math.abs(delta.X) > 6 or math.abs(delta.Y) > 6) then dragging = true end
            if dragging then
                btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                         startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)

        btn.InputEnded:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            -- Only act on a press that started on this button: InputEnded also
            -- fires for input that began elsewhere and was released over it.
            if not pressing then return end
            local wasDrag = dragging
            pressing = false
            dragging = false
            if wasDrag then
                saveSoon()
                return
            end
            if not action then return end
            api.press()
            pcall(action.press)
            if action.momentary then
                api.pulse()
            else
                task.delay(0.05, function() api.setActive(action.state()) end)
            end
        end)

        api.stateFn = action and action.state or nil
    end
end

--------------------------------------------------------------------------------
-- TAB SWITCHING / OPEN / CLOSE
--------------------------------------------------------------------------------
local tabPages = {
    Movement = Movement, Combat = Combat, Keybinds = Keybinds,
    Controller = Controller, Utility = Utility, Settings = Settings,
}

local function switchTab(tabName)
    for _, page in pairs(tabPages) do page.Visible = false end
    if tabPages[tabName] then tabPages[tabName].Visible = true end

    for _, btn in ipairs(Tabs:GetChildren()) do
        if btn:IsA("TextButton") then
            local isActive = (btn.Name == tabName)
            btn.BackgroundTransparency = isActive and 0.78 or 1
            btn.TextColor3 = isActive and WHITE or MUTED_TEXT
            local s = btn:FindFirstChildWhichIsA("UIStroke")
            local grad = s and s:FindFirstChildWhichIsA("UIGradient")
            if grad then
                if isActive then
                    grad.Color = BORDER_GRAD_LIGHT.Color
                    grad.Transparency = BORDER_GRAD_LIGHT.Transparency
                else
                    grad.Color = BORDER_GRAD_DARK.Color
                    grad.Transparency = BORDER_GRAD_DARK.Transparency
                end
            end
        end
    end
end

for _, btn in ipairs(Tabs:GetChildren()) do
    if btn:IsA("TextButton") then
        btn.MouseButton1Click:Connect(function() switchTab(btn.Name) end)
    end
end

local function setMenuOpen(open)
    Main.Visible = open
    WokeFloatOpen.Visible = not open
end

Close.MouseButton1Click:Connect(function() setMenuOpen(false) end)

-- Dragging. `handle` is the element that receives the input, which is not
-- always the frame that moves: the float window is completely covered by its
-- button, so input never reaches the frame itself. Returns a "was dragged"
-- probe so a click handler can ignore the release that ends a drag.
local function makeDraggable(frame, handle, onMoved)
    handle = handle or frame
    local dragging, moved, heldInput, startPos, framePos = false, false, nil, nil, nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            heldInput = input
            startPos = input.Position
            framePos = frame.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging or not startPos then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
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
        dragging = false
        heldInput = nil
    end)

    return function() return moved end
end

makeDraggable(Main, Main, function()
    savedMainPositionTable = udim2ToTable(Main.Position)
end)
local floatWasDragged = makeDraggable(WokeFloatOpen, FloatButton)

-- The bypass panel drags by its header, so the rows underneath stay clickable.
makeDraggable(BypassPanel, BypassHeader, function()
    _G.WokeBypassPosition = udim2ToTable(BypassPanel.Position)
end)

FloatButton.MouseButton1Click:Connect(function()
    if floatWasDragged() then return end
    setMenuOpen(true)
end)

--------------------------------------------------------------------------------
-- HOTKEYS (keyboard + controller)
--------------------------------------------------------------------------------
local HOTKEY_ACTIONS = {
    SpeedToggle = function() toggleCarryMode() end,
    SpeedBypass = function() setBypass(not (_G.WokeBypassEnabled == true)) end,
    LaggerToggle = function() toggleLaggerMode() end,
    DropBrainrot = function() runDrop() end,
    TPDown = function() runTPFloor() end,
    Aimbot = function()
        if _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
            if _G.AceSafeModeForceStop then _G.AceSafeModeForceStop("SAFE MODE LOCK") end
            return
        end
        if _G.AceToggleSelectedAimbot then _G.AceToggleSelectedAimbot() end
    end,
    AntiDesyncAimbot = function()
        if _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
            if _G.AceSafeModeForceStop then _G.AceSafeModeForceStop("SAFE MODE LOCK") end
            return
        end
        if _G.AceToggleAntiDesyncAimbot then _G.AceToggleAntiDesyncAimbot() end
    end,
    AutoLeft = function() if _G.AceSetAutoLeft then _G.AceSetAutoLeft(not autoLeftEnabled) end end,
    AutoRight = function() if _G.AceSetAutoRight then _G.AceSetAutoRight(not autoRightEnabled) end end,
    InstantReset = function() if _G.AceCursedInstaReset then _G.AceCursedInstaReset() end end,
    ToggleUI = function() setMenuOpen(not Main.Visible) end,
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    local isController = tostring(input.UserInputType):find("Gamepad") ~= nil
    if input.UserInputType ~= Enum.UserInputType.Keyboard and not isController then return end
    if input.KeyCode == Enum.KeyCode.Unknown then return end

    -- Capturing a new bind for a keybind row.
    if listeningRow then
        if tick() - (keybindListenStartedAt or 0) < 0.18 then return end
        -- Escape always cancels, whatever device it came from, so a row can
        -- never be left waiting for an input kind the player isn't using.
        if input.KeyCode == Enum.KeyCode.Escape then
            listeningRow = nil
            refreshKeybindButtons()
            return
        end
        if listeningRow.controller ~= isController then return end
        local target = listeningRow
        listeningRow = nil
        if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
            setBind(target.keyId, nil, target.controller)
        else
            setBind(target.keyId, input.KeyCode, target.controller)
        end
        refreshKeybindButtons()
        saveSoon()
        return
    end

    if gameProcessed and input.UserInputType == Enum.UserInputType.Keyboard then return end
    if UserInputService:GetFocusedTextBox() then return end

    for keyId, fn in pairs(HOTKEY_ACTIONS) do
        -- A gamepad press only ever matches a controller bind; it must not
        -- fall through to the keyboard binding.
        local bound
        if isController then
            bound = _G.WokeControllerBinds[keyId]
        else
            bound = currentBind(keyId, false)
        end
        if bound and input.KeyCode == bound then
            pcall(fn)
            return
        end
    end
end)

--------------------------------------------------------------------------------
-- STATE SYNC — pull the logic state back into the UI
--------------------------------------------------------------------------------
local function syncAll()
    for _, api in pairs(UI.toggle) do
        if api.read then api.setVisual(api.read() == true) end
    end
    for _, handle in pairs(UI.value) do
        if handle.refresh then handle.refresh() end
    end
    for _, api in pairs(UI.expand) do
        if api.refresh then api.refresh() end
    end
    for _, api in pairs(UI.pick) do
        if api.refresh then api.refresh() end
    end
    if refreshSpeedModeRows then refreshSpeedModeRows() end
    if refreshBypassPanel then refreshBypassPanel() end
    refreshKeybindButtons()
    for _, api in pairs(UI.mobile) do
        if api.stateFn then api.setActive(api.stateFn()) end
    end
end
_G.WokeSyncUI = syncAll

task.spawn(function()
    while task.wait(0.35) do
        for _, api in pairs(UI.mobile) do
            if api.stateFn then api.setActive(api.stateFn()) end
        end
        for _, api in pairs(UI.toggle) do
            if api.read and api.state ~= (api.read() == true) then
                api.setVisual(api.read() == true)
            end
        end
        if refreshSpeedModeRows then refreshSpeedModeRows() end
        -- Keeps the panel's live speed readout moving as the speed mode changes.
        if refreshBypassPanel then refreshBypassPanel() end
    end
end)

-- Top bar ping / fps readout.
task.spawn(function()
    local frames, last = 0, tick()
    RunService.RenderStepped:Connect(function() frames = frames + 1 end)
    while task.wait(1) do
        local now = tick()
        FpsLabel.Text = string.format("FPS: %d", math.floor(frames / math.max(now - last, 0.001) + 0.5))
        frames, last = 0, now
        local ok, ping = pcall(function()
            return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        PingLabel.Text = ok and string.format("PING: %.1f", ping) or "PING: --"
    end
end)

--------------------------------------------------------------------------------
-- RESET ALL SETTINGS
--------------------------------------------------------------------------------
UI.action["RESET ALL SETTINGS"].button.MouseButton1Click:Connect(function()
    UI.action["RESET ALL SETTINGS"].flash()

    NS, CS = 59.5, 28.8
    LAGGER_SPEED, LAGGER_CARRY_SPEED = 29, 15
    autoTPHeight = 20
    fovValue = 70
    _G.AceStealRadii.Normal, _G.AceStealRadii.Semi = 62, 9
    autoStealRadius = 62
    selectedStealMode = "Normal"
    selectedAimbotMode = "Normal"
    AIMBOT_SPEED, LAGGER_AIMBOT_SPEED = 58, 40

    setSpeedMode("Normal")
    if autoTPEnabled then toggleAutoTP(false) end
    if infJumpEnabled then setInfJumpInternal(false) end
    if antiRagdollEnabled then setAntiRagdoll(false) end
    if autoStealEnabled then
        autoStealEnabled = false
        if _G.AceAutoStealSync then _G.AceAutoStealSync() end
    end
    if _G.AceNormalAimbotOn and _G.AceStopNormalAimbot then _G.AceStopNormalAimbot() end
    if _G.AceAntiBypassAimbotOn and _G.AceStopAntiBypassAimbot then _G.AceStopAntiBypassAimbot() end
    if _G.AceAntiDesyncAimbotOn and _G.AceStopAntiDesyncAimbot then _G.AceStopAntiDesyncAimbot() end
    if autoLeftEnabled and _G.AceSetAutoLeft then _G.AceSetAutoLeft(false) end
    if autoRightEnabled and _G.AceSetAutoRight then _G.AceSetAutoRight(false) end
    if batCounterEnabled then batCounterEnabled = false if _G.AceStopBatCounter then _G.AceStopBatCounter() end end
    if medCounterEnabled then medCounterEnabled = false if _G.AceStopMedCounter then _G.AceStopMedCounter() end end
    if autoResetOnMedEnabled and _G.AceSetAutoResetOnMed then _G.AceSetAutoResetOnMed(false) end
    if _G.AceAntiBodylockEnabled then disableAntiBodylock() end
    if _G.AceNoPlayerCollisionEnabled then
        _G.AceNoPlayerCollisionEnabled = false
        disableNoPlayerCollision()
    end
    antiKickEnabled = false
    autoSwingEnabled = false
    antiDesyncAutoSwingEnabled = false
    if mirrorTPDownEnabled and _G.AceSetMirrorTPDown then _G.AceSetMirrorTPDown(false) end
    if espEnabled then espEnabled = false if stopPlayerESP then stopPlayerESP() end end
    showTracerEnabled = false
    if BoxedESPOptions then BoxedESPOptions.box, BoxedESPOptions.tracer = false, false end
    if refreshBoxedESP then refreshBoxedESP() end
    if ragdollCountdownEnabled then ragdollCountdownEnabled = false stopRagdollCountdown() end
    if fpsBoostEnabled then disableStretchRez() end
    if antiLagVisualEnabled then disableAntiLag() end
    if nukeOptimiserEnabled then disableNukeOptimizer() end
    if fovEnabled then disableCustomFov() end
    if noCamCollisionEnabled then disableNoCamCollision() end
    skyTheme = "Off"
    if type(applyCustomSky) == "function" then pcall(applyCustomSky, "Off") end
    selectedAnimationPack = "OFF"
    pcall(applyAnimationPack, "OFF")
    setBypass(false)
    setBypassPower(BYPASS_POWER_DEFAULT)
    _G.WokeBypassPanelOpen = true
    BypassPanel.Visible = true
    BypassPanel.Position = UDim2.new(0.5, -134, 0, 56)
    _G.WokeBypassPosition = nil

    applyDefaultAceKeybinds()
    -- Not in DEFAULT_SPEED_KEYBINDS (that table lives in the Ace source), so
    -- applyDefaultAceKeybinds leaves it alone.
    speedKeybinds.SpeedBypass = BYPASS_DEFAULT_KEY
    _G.WokeControllerBinds = {}
    _G.WokeUiScale = 0.85
    MainScale.Scale = _G.WokeUiScale
    resetMobileButtons()

    syncAll()
    pcall(saveAceConfig)
end)

--------------------------------------------------------------------------------
-- CONFIG: persist the extra UI-side settings alongside the Ace config
--------------------------------------------------------------------------------
do
    local baseCollect = collectAceConfig
    collectAceConfig = function()
        local t = baseCollect()
        local ctrl = {}
        for keyId, key in pairs(_G.WokeControllerBinds) do ctrl[keyId] = keyToString(key) end
        t.wokeControllerKeybinds = ctrl
        t.wokeDropMode = _G.WokeDropMode
        t.wokeButtonImage = _G.WokeButtonImage
        t.wokeCircleButtons = _G.WokeCircleButtons == true
        t.wokeIntroSong = _G.WokeIntroSongEnabled == true
        -- The hub keeps its own scale and background index: the Ace values
        -- describe a different menu (and a different image list), so reusing
        -- them would load this UI at the wrong size with the wrong picture.
        t.wokeUiScale = _G.WokeUiScale
        t.wokeBackground = _G.WokeBackground
        t.wokeBypassEnabled = _G.WokeBypassEnabled == true
        t.wokeBypassPower = bypassPower()
        t.wokeBypassPanel = _G.WokeBypassPanelOpen == true
        t.wokeBypassPosition = _G.WokeBypassPosition
        t.wokeMobilePositions = (function()
            local out = {}
            for name, api in pairs(UI.mobile) do out[name] = udim2ToTable(api.button.Position) end
            return out
        end)()
        return t
    end

    local data = savedConfig or {}
    -- `adapt*` are the keys this hub used before the rename; read them as a
    -- fallback so existing settings survive the upgrade.
    local function saved(key, legacy)
        local v = data[key]
        if v == nil then v = data[legacy] end
        return v
    end

    local binds = saved("wokeControllerKeybinds", "adaptControllerKeybinds")
    if type(binds) == "table" then
        for keyId, name in pairs(binds) do
            _G.WokeControllerBinds[keyId] = stringToKeyCode(name)
        end
    end
    _G.WokeDropMode = saved("wokeDropMode", "adaptDropMode") or "Jump"
    _G.WokeCircleButtons = saved("wokeCircleButtons", "adaptCircleButtons") == true
    _G.WokeIntroSongEnabled = saved("wokeIntroSong", "adaptIntroSong") == true
    _G.WokeButtonImage = saved("wokeButtonImage", "adaptButtonImage") or ""
    _G.WokeUiScale = math.clamp(tonumber(data.wokeUiScale) or 0.85, 0.5, 1.5)
    _G.WokeBackground = tonumber(data.wokeBackground) or 0

    -- Speed bypass. Its keybind lives in the Ace `speedKeybinds` table, but it
    -- is added by this file — the Ace loader had already run by then and
    -- skipped the key, so restore it here. An explicitly cleared bind saves as
    -- "None" and must stay cleared, which is why the nil check comes first.
    _G.WokeBypassEnabled = data.wokeBypassEnabled == true
    _G.WokeBypassPower = math.clamp(tonumber(data.wokeBypassPower) or BYPASS_POWER_DEFAULT,
        BYPASS_POWER_MIN, BYPASS_POWER_MAX)
    _G.WokeBypassPanelOpen = data.wokeBypassPanel ~= false
    _G.WokeBypassPosition = data.wokeBypassPosition
    local savedKeys = type(data.keybinds) == "table" and data.keybinds or nil
    if savedKeys and savedKeys.SpeedBypass ~= nil then
        speedKeybinds.SpeedBypass = stringToKeyCode(savedKeys.SpeedBypass)
    end

    local positions = saved("wokeMobilePositions", "adaptMobilePositions")
    if type(positions) == "table" then
        for name, pos in pairs(positions) do
            local api = UI.mobile[name]
            if api then api.button.Position = tableToUDim2(pos, api.button.Position) end
        end
    end
end

--------------------------------------------------------------------------------
-- APPLY THE LOADED CONFIG TO THE GAME + UI
--------------------------------------------------------------------------------
local function applySavedState()
    pcall(function() if autoTPEnabled then startAutoTP() else stopAutoTP() end end)
    pcall(function() setInfJumpInternal(infJumpEnabled == true) end)
    pcall(function() setAntiRagdoll(antiRagdollEnabled == true) end)
    pcall(function() if _G.AceAutoStealSync then _G.AceAutoStealSync() end end)
    pcall(function()
        if batCounterEnabled then
            if _G.AceStartBatCounter then _G.AceStartBatCounter() end
        elseif _G.AceStopBatCounter then _G.AceStopBatCounter() end
    end)
    pcall(function()
        if medCounterEnabled then
            if _G.AceStartMedCounter then _G.AceStartMedCounter(LocalPlayer.Character) end
        elseif _G.AceStopMedCounter then _G.AceStopMedCounter() end
    end)
    pcall(function()
        if _G.AceNoPlayerCollisionEnabled then enableNoPlayerCollision() else disableNoPlayerCollision() end
    end)
    pcall(function() if _G.AceAntiBodylockEnabled then enableAntiBodylock() end end)
    pcall(function() if _G.AceSetAutoResetOnMed then _G.AceSetAutoResetOnMed(autoResetOnMedEnabled == true, true) end end)
    pcall(function()
        if espEnabled then
            if startPlayerESP then startPlayerESP() end
        elseif stopPlayerESP then stopPlayerESP() end
        if BoxedESPOptions then
            BoxedESPOptions.box = espEnabled == true
            BoxedESPOptions.tracer = showTracerEnabled == true
        end
        if refreshBoxedESP then refreshBoxedESP() end
    end)
    pcall(function()
        if ragdollCountdownEnabled then hookRagdollCountdown(LocalPlayer.Character) else stopRagdollCountdown() end
    end)
    pcall(function() if fpsBoostEnabled then enableStretchRez() else disableStretchRez() end end)
    pcall(function() if antiLagVisualEnabled then enableAntiLag() else disableAntiLag() end end)
    pcall(function() if nukeOptimiserEnabled then enableNukeOptimizer() else disableNukeOptimizer() end end)
    pcall(function() if fovEnabled then enableCustomFov() else disableCustomFov() end end)
    pcall(function() if noCamCollisionEnabled then enableNoCamCollision() else disableNoCamCollision() end end)
    pcall(function() if type(applyCustomSky) == "function" then applyCustomSky(skyTheme or "Off") end end)
    pcall(function()
        if syncAnimationPackIndex then syncAnimationPackIndex() end
        if applySavedAnimationPackToCharacter then applySavedAnimationPackToCharacter(LocalPlayer.Character) end
    end)
    pcall(function()
        BypassPanel.Visible = _G.WokeBypassPanelOpen == true
        if _G.WokeBypassPosition then
            BypassPanel.Position = tableToUDim2(_G.WokeBypassPosition, BypassPanel.Position)
        end
        BypassScale.Scale = math.clamp(tonumber(_G.WokeUiScale) or 0.85, 0.5, 1.5)
    end)
    pcall(function()
        MainScale.Scale = math.clamp(tonumber(_G.WokeUiScale) or 0.85, 0.5, 1.5)
        applyMobileButtonScale((tonumber(_G.AceMobileButtonScale) or 1) * 100)
        applyMobileButtonCorners(_G.WokeCircleButtons == true)
        MobileButtons.Visible = not (_G.AceHideMobileButtons == true)
        if savedMainPositionTable then
            Main.Position = tableToUDim2(savedMainPositionTable, Main.Position)
        end
        local bgIndex = tonumber(_G.WokeBackground) or 0
        if bgIndex > 0 and UI.gallery.Background.thumbs[bgIndex + 1] then
            UI.gallery.Background.select(bgIndex + 1)
        end
        if _G.WokeButtonImage and _G.WokeButtonImage ~= "" then
            for _, api in pairs(UI.mobile) do api.overlay.Image = _G.WokeButtonImage end
        end
    end)
    syncAll()
end

--------------------------------------------------------------------------------
-- INTRO ANIMATION + TAP TO SKIP
--------------------------------------------------------------------------------
local introSkipped = false

local function skipIntro()
    if introSkipped then return end
    introSkipped = true

    -- Stop swallowing input straight away: the catcher covers the screen, so
    -- if anything below went wrong it would leave the game unclickable.
    TapCatcher.Visible = false

    uiTween(WokeIntro, 0.4, {BackgroundTransparency = 1})
    for _, child in ipairs(WokeIntro:GetChildren()) do
        if child:IsA("ImageLabel") then
            uiTween(child, 0.3, {ImageTransparency = 1})
        elseif child:IsA("TextLabel") then
            uiTween(child, 0.3, {TextTransparency = 1})
        elseif child:IsA("Frame") then
            uiTween(child, 0.3, {BackgroundTransparency = 1})
            for _, sub in ipairs(child:GetDescendants()) do
                if sub:IsA("ImageLabel") then
                    uiTween(sub, 0.3, {ImageTransparency = 1})
                elseif sub:IsA("TextLabel") then
                    uiTween(sub, 0.3, {TextTransparency = 1, TextStrokeTransparency = 1})
                elseif sub:IsA("Frame") then
                    uiTween(sub, 0.3, {BackgroundTransparency = 1})
                elseif sub:IsA("UIStroke") then
                    uiTween(sub, 0.3, {Transparency = 1})
                end
            end
        end
    end

    task.delay(0.45, function()
        WokeIntro.Visible = false
        if stopIntroPlayback then pcall(stopIntroPlayback) end
        MainScale.Scale = 0.85
        uiTween(MainScale, 0.35, {Scale = math.clamp(tonumber(_G.WokeUiScale) or 0.85, 0.5, 1.5)}, Enum.EasingStyle.Back)
        PingLabel.Visible = true
        FpsLabel.Visible = true
        WokeLogo.Visible = true
    end)
end

TapCatcher.MouseButton1Click:Connect(skipIntro)

task.spawn(function()
    task.wait(0.2)
    applySavedState()

    if _introEnabled == false then
        skipIntro()
        return
    end

    if _G.WokeIntroSongEnabled and playIntroMusic then pcall(playIntroMusic) end

    IntroBackdropImage.Visible = true
    uiTween(IntroBackdropImage, 0.8, {ImageTransparency = 0.3})

    for i, rotor in ipairs(ChainSpearStage:GetChildren()) do
        if rotor:IsA("Frame") and rotor.Name:match("ChainSpearRotor") then
            local trail = rotor:FindFirstChildWhichIsA("ImageLabel")
            if trail then
                task.delay(i * 0.04, function()
                    if introSkipped then return end
                    uiTween(trail, 0.5, {ImageTransparency = 0.15})
                end)
            end
            task.spawn(function()
                local speed = 0.4 + (i * 0.05)
                while not introSkipped do
                    rotor.Rotation = rotor.Rotation + speed
                    RunService.Heartbeat:Wait()
                end
            end)
        end
    end

    task.wait(0.6)
    if introSkipped then return end

    TojiCutoutStage.Visible = true
    local tojiScale = TojiCutoutStage:FindFirstChildWhichIsA("UIScale")
    if tojiScale then
        tojiScale.Scale = 0.85
        uiTween(tojiScale, 0.6, {Scale = 1}, Enum.EasingStyle.Back)
    end

    for i = 1, 10 do
        if introSkipped then return end
        local piece = TojiCutoutStage:FindFirstChild("TojiPiece" .. i)
        if piece then uiTween(piece, 0.25, {ImageTransparency = 0}) end
        for _, child in ipairs(TojiCutoutStage:GetChildren()) do
            if child.Name == "TojiSeamFill" .. i then
                uiTween(child, 0.25, {ImageTransparency = 0})
            end
        end
        task.wait(0.08)
    end

    task.wait(0.3)
    if introSkipped then return end

    local shine = TojiCutoutStage:FindFirstChild("TojiSwordShine")
    if shine then
        uiTween(shine, 0.4, {ImageTransparency = 0.2})
        task.wait(0.3)
        if not introSkipped then uiTween(shine, 0.3, {ImageTransparency = 0.7}) end
    end

    task.wait(0.5)
    if introSkipped then return end

    IntroCaptionShield.Visible = true
    uiTween(IntroCaptionShield, 0.3, {BackgroundTransparency = 0.08})

    task.spawn(function()
        while not introSkipped do
            uiTween(TapAnywhere, 0.8, {TextTransparency = 0.5})
            task.wait(0.8)
            if introSkipped then return end
            uiTween(TapAnywhere, 0.8, {TextTransparency = 0})
            task.wait(0.8)
        end
    end)

    task.wait(6)
    if not introSkipped then skipIntro() end
end)

-- Re-apply per-character state on respawn.
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    pcall(syncAll)
end)

switchTab("Movement")
task.delay(1.5, function() pcall(syncAll) end)

end

WokeHubMain()
