--!nocheck
--[==[
	Veltrex — Interface
	-------------------
	A console, not a settings panel. Nothing in here knows how any feature
	works: it renders state that lives in Core and calls Core's public API.

	Visual language
	  no rounded corners anywhere, no filled cards
	  monospace throughout (Enum.Font.Code)
	  tabs run across the top; content gets the full width
	  toggles are ON/OFF cells with a channel LED in the gutter
	  numbers are segmented meters, not sliders with knobs
	  sections are a label and a rule to the right edge
	  notifications are log lines in the corner, not floating cards

	Pieces
	  Window   top tab strip, command-line filter, dense rows
	  HUD      one 420x26 strip: status, meter, percentage, telemetry
	  Pad      3x4 key grid for touch
	  Log      terminal-style notifications
]==]

local Core = ...

local TS  = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local LP  = Core.LP
local cfg = Core.cfg

local UI = {}

--==============================================================================
-- Persisted interface preferences
--==============================================================================

local prefs = cfg.ui
if type(prefs) ~= "table" then
	prefs = {}
	cfg.ui = prefs
end

local function default(key, value)
	if prefs[key] == nil then prefs[key] = value end
end

default("accent",    { 255, 176, 32 })
default("menuScale", 1)
default("hudScale",  1)
default("padScale",  0.8)
default("locked",    false)
default("showHud",   true)
default("showPad",   UIS.TouchEnabled)
default("windowPos", { xs = 0, xo = 36, ys = 0.5, yo = -186 })
default("hudPos",    { xs = 0.5, xo = -210, ys = 0, yo = 18 })
default("padPos",    { xs = 1, xo = -206, ys = 0.5, yo = -126 })

local function savePrefs()
	Core.save()
end

--==============================================================================
-- Palette
--==============================================================================

local Theme = {
	shell   = Color3.fromRGB(12, 11, 9),    -- window ground, warm black
	inset   = Color3.fromRGB(21, 19, 15),   -- inputs and cells
	wash    = Color3.fromRGB(30, 27, 21),   -- hover
	rule    = Color3.fromRGB(43, 38, 32),   -- hairlines
	ink     = Color3.fromRGB(237, 228, 210),
	sub     = Color3.fromRGB(154, 144, 120),
	dim     = Color3.fromRGB(94, 87, 74),
	danger  = Color3.fromRGB(229, 72, 77),
	accent  = Color3.fromRGB(prefs.accent[1], prefs.accent[2], prefs.accent[3]),
}

-- Console phosphors rather than product hues.
local ACCENTS = {
	{ name = "Amber",    color = Color3.fromRGB(255, 176, 32) },
	{ name = "Phosphor", color = Color3.fromRGB(111, 224, 122) },
	{ name = "Ice",      color = Color3.fromRGB(88, 198, 255) },
	{ name = "Signal",   color = Color3.fromRGB(255, 77, 77) },
	{ name = "Violet",   color = Color3.fromRGB(176, 124, 255) },
	{ name = "Bone",     color = Color3.fromRGB(232, 228, 220) },
}

local accentTargets = {}

local function accented(inst, prop)
	table.insert(accentTargets, { inst = inst, prop = prop })
	inst[prop] = Theme.accent
	return inst
end

local function setAccent(color)
	Theme.accent = color
	prefs.accent = { math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255) }
	for _, target in ipairs(accentTargets) do
		if target.inst and target.inst.Parent then
			pcall(function() target.inst[target.prop] = color end)
		end
	end
	savePrefs()
end

local FONT = Enum.Font.Code

--==============================================================================
-- Instance helpers
--==============================================================================

local function new(class, props, children)
	local inst = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	for key, value in pairs(props) do
		inst[key] = value
	end
	if children then
		for _, child in ipairs(children) do child.Parent = inst end
	end
	if parent then inst.Parent = parent end
	return inst
end

local function stroke(inst, color, transparency)
	return new("UIStroke", {
		Color           = color or Theme.rule,
		Thickness       = 1,
		Transparency    = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent          = inst,
	})
end

local function pad(inst, left, right, top, bottom)
	return new("UIPadding", {
		PaddingLeft   = UDim.new(0, left or 0),
		PaddingRight  = UDim.new(0, right or left or 0),
		PaddingTop    = UDim.new(0, top or 0),
		PaddingBottom = UDim.new(0, bottom or top or 0),
		Parent        = inst,
	})
end

local function list(inst, spacing, direction)
	return new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder     = Enum.SortOrder.LayoutOrder,
		Padding       = UDim.new(0, spacing or 0),
		Parent        = inst,
	})
end

local function text(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font           = props.Font or FONT
	props.TextColor3     = props.TextColor3 or Theme.ink
	props.TextSize       = props.TextSize or 12
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return new("TextLabel", props)
end

-- A one pixel hairline. Everything in this interface is separated by these
-- rather than by card edges.
local function rule(parent, y, transparency, inset)
	inset = inset or 0
	return new("Frame", {
		Size                   = UDim2.new(1, -inset * 2, 0, 1),
		Position               = UDim2.new(0, inset, 0, y or 0),
		BackgroundColor3       = Theme.rule,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel        = 0,
		Parent                 = parent,
	})
end

local function tween(inst, time, goal, style)
	local t = TS:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function udim2From(t, fallback)
	if type(t) ~= "table" then return fallback end
	return UDim2.new(tonumber(t.xs) or 0, tonumber(t.xo) or 0, tonumber(t.ys) or 0, tonumber(t.yo) or 0)
end

local function udim2To(u)
	return { xs = u.X.Scale, xo = u.X.Offset, ys = u.Y.Scale, yo = u.Y.Offset }
end

local function spaced(word)
	return (word:gsub("(.)", "%1 "):gsub(" $", ""))
end

--==============================================================================
-- GUI root
--==============================================================================

local OLD_GUIS = {
	"VeltrexUI", "VeltrexHUD", "VeltrexPad",
	"VeltrexHub", "VeltrexMobileButtons", "StealBarGui",
}

local function guiParent()
	local ok, hidden = pcall(function() return gethui() end)
	if ok and typeof(hidden) == "Instance" then return hidden end
	return LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")
end

local root = guiParent()

for _, container in ipairs({ root, LP:FindFirstChildOfClass("PlayerGui") }) do
	if container then
		for _, name in ipairs(OLD_GUIS) do
			local old = container:FindFirstChild(name)
			while old do
				old:Destroy()
				old = container:FindFirstChild(name)
			end
		end
	end
end

local function screen(name, order)
	return new("ScreenGui", {
		Name           = name,
		ResetOnSpawn   = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder   = order or 100,
		Parent         = root,
	})
end

local screenMain = screen("VeltrexUI", 1000)
local screenHud  = screen("VeltrexHUD", 990)
local screenPad  = screen("VeltrexPad", 995)

local hud, hudScaleObj
local padFrame, padScaleObj

--==============================================================================
-- Dragging
--==============================================================================

local uiConns = {}

local function track(conn)
	table.insert(uiConns, conn)
	return conn
end

local function draggable(frame, handle, onFinished)
	handle = handle or frame
	local dragging, origin, startPos = false, nil, nil

	track(handle.InputBegan:Connect(function(input)
		if prefs.locked then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then return end

		dragging = true
		origin   = input.Position
		startPos = frame.Position

		local ended
		ended = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				ended:Disconnect()
				if onFinished then onFinished(frame.Position) end
			end
		end)
	end))

	track(UIS.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then return end

		local delta = input.Position - origin
		frame.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end))
end

--==============================================================================
-- Log lines (notifications)
--==============================================================================

local logHolder = new("Frame", {
	Name                   = "Log",
	AnchorPoint            = Vector2.new(0, 1),
	Position               = UDim2.new(0, 16, 1, -16),
	Size                   = UDim2.new(0, 320, 0, 120),
	BackgroundTransparency = 1,
	Parent                 = screenMain,
})
new("UIListLayout", {
	SortOrder         = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	Padding           = UDim.new(0, 2),
	Parent            = logHolder,
})

function UI.toast(message, kind)
	local color = Theme.accent
	if kind == "warn" then color = Color3.fromRGB(246, 190, 80) end
	if kind == "bad"  then color = Theme.danger end

	local line = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, 18),
		BackgroundColor3       = Theme.shell,
		BackgroundTransparency = 0.15,
		BorderSizePixel        = 0,
		Parent                 = logHolder,
	})

	new("Frame", {
		Size             = UDim2.new(0, 2, 1, 0),
		BackgroundColor3 = color,
		BorderSizePixel  = 0,
		Parent           = line,
	})

	local label = text({
		Text     = "> " .. string.upper(message),
		TextSize = 10,
		TextColor3 = Theme.sub,
		Position = UDim2.new(0, 8, 0, 0),
		Size     = UDim2.new(1, -10, 1, 0),
		Parent   = line,
	})

	task.delay(3, function()
		if not line.Parent then return end
		tween(line, 0.25, { BackgroundTransparency = 1 })
		tween(label, 0.25, { TextTransparency = 1 })
		task.delay(0.3, function() line:Destroy() end)
	end)
end

--==============================================================================
-- State fan-out
--==============================================================================

local featureWatchers, valueWatchers, modeWatchers, profileWatchers = {}, {}, {}, {}

local function watchFeature(id, fn)
	featureWatchers[id] = featureWatchers[id] or {}
	table.insert(featureWatchers[id], fn)
	fn(Core.isOn(id))
end

local function watchValue(key, fn)
	valueWatchers[key] = valueWatchers[key] or {}
	table.insert(valueWatchers[key], fn)
	fn(cfg[key])
end

local function watchMode(key, fn)
	modeWatchers[key] = modeWatchers[key] or {}
	table.insert(modeWatchers[key], fn)
	fn(cfg[key])
end

local function watchProfile(fn)
	table.insert(profileWatchers, fn)
	fn(cfg.speedProfile)
end

local function refreshAll()
	for id, watchers in pairs(featureWatchers) do
		for _, fn in ipairs(watchers) do pcall(fn, Core.isOn(id)) end
	end
	for key, watchers in pairs(valueWatchers) do
		for _, fn in ipairs(watchers) do pcall(fn, cfg[key]) end
	end
	for key, watchers in pairs(modeWatchers) do
		for _, fn in ipairs(watchers) do pcall(fn, cfg[key]) end
	end
	for _, fn in ipairs(profileWatchers) do pcall(fn, cfg.speedProfile) end
end

Core.on("sync", refreshAll)
Core.on("feature", function(id, on)
	for _, fn in ipairs(featureWatchers[id] or {}) do pcall(fn, on) end
end)
Core.on("value", function(key, value)
	for _, fn in ipairs(valueWatchers[key] or {}) do pcall(fn, value) end
end)
Core.on("mode", function(key, value)
	for _, fn in ipairs(modeWatchers[key] or {}) do pcall(fn, value) end
end)
Core.on("speedProfile", function(name)
	for _, fn in ipairs(profileWatchers) do pcall(fn, name) end
end)
Core.on("notify", function(message, kind) UI.toast(message, kind) end)

--==============================================================================
-- Window shell
--==============================================================================

local WINDOW_W, WINDOW_H = 640, 372
local HEADER_H, TABS_H, FOOTER_H = 34, 28, 24

local window = new("Frame", {
	Name             = "Console",
	Size             = UDim2.new(0, WINDOW_W, 0, WINDOW_H),
	Position         = udim2From(prefs.windowPos, UDim2.new(0, 36, 0.5, -WINDOW_H / 2)),
	BackgroundColor3 = Theme.shell,
	BorderSizePixel  = 0,
	Active           = true,
	Parent           = screenMain,
})
stroke(window, Theme.rule, 0)

local windowScale = new("UIScale", { Scale = prefs.menuScale, Parent = window })

-- Corner brackets: the console's only ornament. Each corner is an L drawn
-- from two 9x1 bars, inset five pixels from the edge.
for _, corner in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
	local sx, sy = corner[1], corner[2]
	local nearX = sx == 0 and 5 or -14   -- start of a horizontal bar
	local nearY = sy == 0 and 5 or -6    -- the edge the bar sits on

	accented(new("Frame", {
		Size             = UDim2.new(0, 9, 0, 1),
		Position         = UDim2.new(sx, nearX, sy, nearY),
		BackgroundColor3 = Theme.accent,
		BorderSizePixel  = 0,
		Parent           = window,
	}), "BackgroundColor3")

	accented(new("Frame", {
		Size             = UDim2.new(0, 1, 0, 9),
		Position         = UDim2.new(sx, sx == 0 and 5 or -6, sy, sy == 0 and 5 or -14),
		BackgroundColor3 = Theme.accent,
		BorderSizePixel  = 0,
		Parent           = window,
	}), "BackgroundColor3")
end

-- Header ---------------------------------------------------------------------

local header = new("Frame", {
	Name                   = "Header",
	Size                   = UDim2.new(1, 0, 0, HEADER_H),
	BackgroundTransparency = 1,
	Parent                 = window,
})

accented(text({
	Text     = spaced("VELTREX"),
	TextSize = 13,
	Position = UDim2.new(0, 16, 0, 0),
	Size     = UDim2.new(0, 120, 1, 0),
	Parent   = header,
}), "TextColor3")

new("Frame", {
	Size             = UDim2.new(0, 1, 0, 12),
	Position         = UDim2.new(0, 118, 0, 11),
	BackgroundColor3 = Theme.rule,
	BorderSizePixel  = 0,
	Parent           = header,
})

text({
	Text       = "STEAL A BRAINROT",
	TextSize   = 10,
	TextColor3 = Theme.dim,
	Position   = UDim2.new(0, 128, 0, 0),
	Size       = UDim2.new(0, 160, 1, 0),
	Parent     = header,
})

local headerStats = text({
	Text           = "",
	TextSize       = 10,
	TextColor3     = Theme.sub,
	TextXAlignment = Enum.TextXAlignment.Right,
	Position       = UDim2.new(1, -230, 0, 0),
	Size           = UDim2.new(0, 180, 1, 0),
	Parent         = header,
})

local function headerButton(glyph, offset, onClick)
	local button = new("TextButton", {
		Size                   = UDim2.new(0, 18, 0, 18),
		Position               = UDim2.new(1, offset, 0, 8),
		BackgroundColor3       = Theme.inset,
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		AutoButtonColor        = false,
		Text                   = glyph,
		TextColor3             = Theme.dim,
		Font                   = FONT,
		TextSize               = 11,
		Parent                 = header,
	})
	stroke(button, Theme.rule, 0.35)

	track(button.MouseEnter:Connect(function()
		tween(button, 0.1, { BackgroundTransparency = 0, TextColor3 = Theme.ink })
	end))
	track(button.MouseLeave:Connect(function()
		tween(button, 0.1, { BackgroundTransparency = 1, TextColor3 = Theme.dim })
	end))
	track(button.MouseButton1Click:Connect(onClick))
	return button
end

rule(header, HEADER_H - 1)

draggable(window, header, function(position)
	prefs.windowPos = udim2To(position)
	savePrefs()
end)

-- Tab strip ------------------------------------------------------------------

local tabStrip = new("Frame", {
	Name                   = "Tabs",
	Position               = UDim2.new(0, 0, 0, HEADER_H),
	Size                   = UDim2.new(1, 0, 0, TABS_H),
	BackgroundTransparency = 1,
	Parent                 = window,
})
pad(tabStrip, 12, 12, 0, 0)
list(tabStrip, 2, Enum.FillDirection.Horizontal)

rule(window, HEADER_H + TABS_H - 1)

-- Content --------------------------------------------------------------------

local CONTENT_Y = HEADER_H + TABS_H + 8
local CONTENT_H = WINDOW_H - CONTENT_Y - FOOTER_H - 4

local contentArea = new("Frame", {
	Name                   = "Content",
	Position               = UDim2.new(0, 14, 0, CONTENT_Y),
	Size                   = UDim2.new(1, -28, 0, CONTENT_H),
	BackgroundTransparency = 1,
	Parent                 = window,
})

accented(text({
	Text     = ">",
	TextSize = 12,
	Size     = UDim2.new(0, 10, 0, 20),
	Parent   = contentArea,
}), "TextColor3")

local searchBox = new("TextBox", {
	Position               = UDim2.new(0, 16, 0, 0),
	Size                   = UDim2.new(1, -16, 0, 20),
	BackgroundTransparency = 1,
	Text                   = "",
	PlaceholderText        = "filter",
	PlaceholderColor3      = Theme.dim,
	TextColor3             = Theme.ink,
	Font                   = FONT,
	TextSize               = 12,
	TextXAlignment         = Enum.TextXAlignment.Left,
	ClearTextOnFocus       = false,
	Parent                 = contentArea,
})

rule(contentArea, 22, 0.4)

local pageHolder = new("Frame", {
	Position               = UDim2.new(0, 0, 0, 30),
	Size                   = UDim2.new(1, 0, 1, -30),
	BackgroundTransparency = 1,
	Parent                 = contentArea,
})

-- Footer ---------------------------------------------------------------------

rule(window, WINDOW_H - FOOTER_H)

local footerLeft = text({
	Text       = "",
	TextSize   = 10,
	TextColor3 = Theme.dim,
	Position   = UDim2.new(0, 16, 1, -FOOTER_H),
	Size       = UDim2.new(0.5, 0, 0, FOOTER_H),
	Parent     = window,
})

local footerRight = text({
	Text           = "",
	TextSize       = 10,
	TextColor3     = Theme.dim,
	TextXAlignment = Enum.TextXAlignment.Right,
	Position       = UDim2.new(0.5, -16, 1, -FOOTER_H),
	Size           = UDim2.new(0.5, 0, 0, FOOTER_H),
	Parent         = window,
})

--==============================================================================
-- Tabs, sections, rows
--==============================================================================

local tabs, activeTab = {}, nil

local function selectTab(tab)
	if activeTab == tab then return end
	for _, other in ipairs(tabs) do
		other.page.Visible = other == tab
		other.underline.BackgroundTransparency = other == tab and 0 or 1
		other.label.TextColor3 = other == tab and Theme.ink or Theme.dim
	end
	activeTab = tab
end

local function addTab(name)
	local index = #tabs + 1
	local width = #name * 7 + 18

	local button = new("TextButton", {
		Size                   = UDim2.new(0, width, 1, 0),
		BackgroundColor3       = Theme.wash,
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		AutoButtonColor        = false,
		Text                   = "",
		LayoutOrder            = index,
		Parent                 = tabStrip,
	})

	local caption = text({
		Text           = name,
		TextSize       = 11,
		TextColor3     = Theme.dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size           = UDim2.new(1, 0, 1, 0),
		Parent         = button,
	})

	local underline = new("Frame", {
		Size                   = UDim2.new(1, -8, 0, 2),
		Position               = UDim2.new(0, 4, 1, -3),
		BackgroundColor3       = Theme.accent,
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		Parent                 = button,
	})
	accented(underline, "BackgroundColor3")

	local page = new("ScrollingFrame", {
		Size                   = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		Visible                = false,
		CanvasSize             = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize    = Enum.AutomaticSize.Y,
		ScrollBarThickness     = 2,
		ScrollBarImageColor3   = Theme.rule,
		ScrollingDirection     = Enum.ScrollingDirection.Y,
		Parent                 = pageHolder,
	})
	list(page, 10)
	pad(page, 0, 10, 0, 14)

	local tab = {
		name = name, index = index, button = button, label = caption,
		underline = underline, page = page, sections = {},
	}
	tabs[index] = tab

	track(button.MouseButton1Click:Connect(function() selectTab(tab) end))
	track(button.MouseEnter:Connect(function()
		if activeTab ~= tab then caption.TextColor3 = Theme.sub end
	end))
	track(button.MouseLeave:Connect(function()
		if activeTab ~= tab then caption.TextColor3 = Theme.dim end
	end))

	return tab
end

-- Section header: a label, then a rule out to the right edge.
local function addSection(tab, title)
	local section = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, 0),
		AutomaticSize          = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder            = #tab.sections + 1,
		Parent                 = tab.page,
	})
	list(section, 0)

	local head = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		LayoutOrder            = 0,
		Parent                 = section,
	})

	accented(text({
		Text     = string.upper(title),
		TextSize = 10,
		Size     = UDim2.new(0, 120, 1, 0),
		Parent   = head,
	}), "TextColor3")

	new("Frame", {
		Size                   = UDim2.new(1, -126, 0, 1),
		Position               = UDim2.new(0, 126, 0.5, 0),
		BackgroundColor3       = Theme.rule,
		BackgroundTransparency = 0.25,
		BorderSizePixel        = 0,
		Parent                 = head,
	})

	local entry = { frame = section, rows = {}, tab = tab }
	table.insert(tab.sections, entry)
	return entry
end

-- Rows are flush lines: a gutter LED, a label, a control, a hairline below.
local function addRow(section, label, hint, height)
	height = height or (hint and 40 or 30)

	local row = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, height),
		BackgroundColor3       = Theme.wash,
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		LayoutOrder            = #section.rows + 1,
		Parent                 = section.frame,
	})

	local led = new("Frame", {
		Size                   = UDim2.new(0, 5, 0, 5),
		Position               = UDim2.new(0, 2, 0, hint and 12 or 13),
		BackgroundColor3       = Theme.rule,
		BorderSizePixel        = 0,
		Visible                = false,
		Parent                 = row,
	})

	text({
		Text     = label,
		TextSize = 12,
		Position = UDim2.new(0, 16, 0, hint and 6 or 0),
		Size     = UDim2.new(1, -200, 0, hint and 14 or height),
		Parent   = row,
	})

	if hint then
		text({
			Text       = hint,
			TextSize   = 10,
			TextColor3 = Theme.dim,
			Position   = UDim2.new(0, 16, 0, 21),
			Size       = UDim2.new(1, -200, 0, 12),
			Parent     = row,
		})
	end

	rule(row, height - 1, 0.55)

	track(row.MouseEnter:Connect(function() tween(row, 0.1, { BackgroundTransparency = 0.5 }) end))
	track(row.MouseLeave:Connect(function() tween(row, 0.1, { BackgroundTransparency = 1 }) end))

	table.insert(section.rows, { frame = row, text = (label .. " " .. (hint or "")):lower() })
	return row, led
end

--==============================================================================
-- Controls
--==============================================================================

-- ON / OFF cell plus the channel LED in the gutter.
local function makeToggle(section, opts)
	local row, led = addRow(section, opts.label, opts.hint)
	led.Visible = true

	local cell = new("TextButton", {
		Size                   = UDim2.new(0, 46, 0, 18),
		Position               = UDim2.new(1, -46, 0.5, -9),
		BackgroundColor3       = Theme.accent,
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		AutoButtonColor        = false,
		Text                   = "OFF",
		TextColor3             = Theme.dim,
		Font                   = FONT,
		TextSize               = 10,
		Parent                 = row,
	})
	local cellStroke = stroke(cell, Theme.rule, 0)
	accented(cell, "BackgroundColor3")

	local hit = new("TextButton", {
		Size                   = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text                   = "",
		Parent                 = row,
	})

	local function render(on)
		cell.Text = on and "ON" or "OFF"
		tween(cell, 0.12, {
			BackgroundTransparency = on and 0 or 1,
			TextColor3             = on and Theme.shell or Theme.dim,
		})
		tween(cellStroke, 0.12, { Color = on and Theme.accent or Theme.rule })
		tween(led, 0.12, { BackgroundColor3 = on and Theme.accent or Theme.rule })
	end

	local function flip()
		if opts.feature then
			Core.toggleFeature(opts.feature)
		elseif opts.get and opts.set then
			opts.set(not opts.get())
			render(opts.get())
		end
	end

	track(cell.MouseButton1Click:Connect(flip))
	track(hit.MouseButton1Click:Connect(flip))

	if opts.feature then
		watchFeature(opts.feature, render)
	else
		render(opts.get and opts.get() or false)
	end

	return row
end

local function makeButton(section, opts)
	local row = addRow(section, opts.label, opts.hint)
	local width = opts.width or 74
	local color = opts.danger and Theme.danger or Theme.accent

	local button = new("TextButton", {
		Size                   = UDim2.new(0, width, 0, 18),
		Position               = UDim2.new(1, -width, 0.5, -9),
		BackgroundColor3       = color,
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		AutoButtonColor        = false,
		Text                   = string.upper(opts.button or "RUN"),
		TextColor3             = color,
		Font                   = FONT,
		TextSize               = 10,
		Parent                 = row,
	})
	local buttonStroke = stroke(button, color, 0.3)
	if not opts.danger then
		accented(button, "BackgroundColor3")
		accented(button, "TextColor3")
		accented(buttonStroke, "Color")
	end

	track(button.MouseEnter:Connect(function()
		tween(button, 0.1, { BackgroundTransparency = 0.85 })
	end))
	track(button.MouseLeave:Connect(function()
		tween(button, 0.1, { BackgroundTransparency = 1 })
	end))
	track(button.MouseButton1Click:Connect(function()
		button.BackgroundTransparency = 0
		button.TextColor3 = Theme.shell
		task.delay(0.12, function()
			button.BackgroundTransparency = 1
			button.TextColor3 = opts.danger and Theme.danger or Theme.accent
		end)
		if opts.action then Core.runAction(opts.action) end
		if opts.onClick then opts.onClick() end
	end))

	return row
end

local function makeSegmented(section, opts)
	local row = addRow(section, opts.label, opts.hint)

	local count = #opts.options
	local width = opts.width or 58
	local total = count * width + (count - 1) * 2

	local holder = new("Frame", {
		Size                   = UDim2.new(0, total, 0, 18),
		Position               = UDim2.new(1, -total, 0.5, -9),
		BackgroundTransparency = 1,
		Parent                 = row,
	})

	local cells = {}
	for index, option in ipairs(opts.options) do
		local cell = new("TextButton", {
			Size                   = UDim2.new(0, width, 1, 0),
			Position               = UDim2.new(0, (index - 1) * (width + 2), 0, 0),
			BackgroundColor3       = Theme.accent,
			BackgroundTransparency = 1,
			BorderSizePixel        = 0,
			AutoButtonColor        = false,
			Text                   = string.upper(option.label),
			TextColor3             = Theme.dim,
			Font                   = FONT,
			TextSize               = 10,
			Parent                 = holder,
		})
		local cellStroke = stroke(cell, Theme.rule, 0)
		accented(cell, "BackgroundColor3")
		cells[index] = { cell = cell, stroke = cellStroke }

		track(cell.MouseButton1Click:Connect(function() opts.onSelect(option.value) end))
	end

	local function render(value)
		for index, option in ipairs(opts.options) do
			local on = option.value == value
			tween(cells[index].cell, 0.12, {
				BackgroundTransparency = on and 0 or 1,
				TextColor3             = on and Theme.shell or Theme.dim,
			})
			cells[index].stroke.Color = on and Theme.accent or Theme.rule
		end
	end

	return row, render
end

-- Numbers are segmented meters. Twenty cells, click or drag anywhere on them.
local METER_CELLS = 20
local CELL_W, CELL_GAP = 5, 1

local function makeMeter(section, opts)
	local limits   = (opts.key and Core.limits[opts.key]) or { opts.min or 0, opts.max or 100 }
	local minimum  = opts.min or limits[1]
	local maximum  = opts.max or limits[2]
	local step     = opts.step or 1
	local decimals = opts.decimals or (step < 1 and 2 or 0)

	local row = addRow(section, opts.label, opts.hint)

	local readout = new("TextBox", {
		Size                   = UDim2.new(0, 46, 0, 18),
		Position               = UDim2.new(1, -46, 0.5, -9),
		BackgroundTransparency = 1,
		Text                   = "0",
		TextColor3             = Theme.ink,
		Font                   = FONT,
		TextSize               = 11,
		TextXAlignment         = Enum.TextXAlignment.Right,
		ClearTextOnFocus       = false,
		Parent                 = row,
	})

	local meterW = METER_CELLS * CELL_W + (METER_CELLS - 1) * CELL_GAP
	local meter = new("Frame", {
		Size                   = UDim2.new(0, meterW, 0, 10),
		Position               = UDim2.new(1, -(meterW + 56), 0.5, -5),
		BackgroundTransparency = 1,
		Parent                 = row,
	})

	local cells = {}
	for index = 1, METER_CELLS do
		cells[index] = new("Frame", {
			Size             = UDim2.new(0, CELL_W, 1, 0),
			Position         = UDim2.new(0, (index - 1) * (CELL_W + CELL_GAP), 0, 0),
			BackgroundColor3 = Theme.rule,
			BorderSizePixel  = 0,
			Parent           = meter,
		})
	end

	local hit = new("TextButton", {
		Size                   = UDim2.new(1, 0, 0, 22),
		Position               = UDim2.new(0, 0, 0.5, -11),
		BackgroundTransparency = 1,
		Text                   = "",
		Parent                 = meter,
	})

	local function format(value)
		if decimals > 0 then return string.format("%." .. decimals .. "f", value) end
		return tostring(math.floor(value + 0.5))
	end

	local function render(value)
		local alpha = math.clamp((value - minimum) / math.max(maximum - minimum, 0.0001), 0, 1)
		local lit = math.floor(alpha * METER_CELLS + 0.5)
		for index = 1, METER_CELLS do
			cells[index].BackgroundColor3 = index <= lit and Theme.accent or Theme.rule
		end
		if not readout:IsFocused() then readout.Text = format(value) end
	end

	local function commit(value)
		value = math.clamp(value, minimum, maximum)
		value = math.floor(value / step + 0.5) * step
		if opts.key then
			value = Core.setValue(opts.key, value) or value
		elseif opts.set then
			opts.set(value)
		end
		render(value)
	end

	local dragging = false

	local function fromInput(input)
		local alpha = (input.Position.X - meter.AbsolutePosition.X) / math.max(meter.AbsoluteSize.X, 1)
		commit(minimum + math.clamp(alpha, 0, 1) * (maximum - minimum))
	end

	track(hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromInput(input)
		end
	end))
	track(UIS.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			fromInput(input)
		end
	end))
	track(UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	local function current()
		if opts.key then return cfg[opts.key] end
		return opts.get and opts.get() or minimum
	end

	track(readout.FocusLost:Connect(function()
		local typed = tonumber(readout.Text)
		if typed then commit(typed) else render(current()) end
	end))

	if opts.key then watchValue(opts.key, render) else render(current()) end
	return row
end

local function makeKeybind(section, bind)
	local row = addRow(section, bind.label)

	local button = new("TextButton", {
		Size                   = UDim2.new(0, 96, 0, 18),
		Position               = UDim2.new(1, -96, 0.5, -9),
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		AutoButtonColor        = false,
		Text                   = "[ " .. string.upper(Core.bindLabel(bind.id)) .. " ]",
		TextColor3             = Theme.sub,
		Font                   = FONT,
		TextSize               = 10,
		Parent                 = row,
	})

	local listening, listener, blink = false, nil, nil

	local function stopListening()
		listening = false
		blink = nil
		Core.captureInput(false)
		if listener then
			listener:Disconnect()
			listener = nil
		end
		button.Text = "[ " .. string.upper(Core.bindLabel(bind.id)) .. " ]"
		button.TextColor3 = Theme.sub
	end

	track(button.MouseButton1Click:Connect(function()
		if listening then
			stopListening()
			return
		end

		listening = true
		Core.captureInput(true)
		button.TextColor3 = Theme.accent

		blink = task.spawn(function()
			local shown = true
			while listening do
				button.Text = shown and "[ ... ]" or "[     ]"
				shown = not shown
				task.wait(0.4)
			end
		end)

		listener = UIS.InputBegan:Connect(function(input)
			local isGamepad = input.UserInputType.Name:match("^Gamepad") ~= nil
			if input.UserInputType ~= Enum.UserInputType.Keyboard and not isGamepad then return end

			if input.KeyCode == Enum.KeyCode.Escape then
				stopListening()
				return
			end
			if input.KeyCode == Enum.KeyCode.Unknown then return end

			Core.setKeybind(bind.id, input.KeyCode, isGamepad)
			stopListening()
		end)
	end))

	Core.on("keybind", function(id)
		if id == bind.id and not listening then
			button.Text = "[ " .. string.upper(Core.bindLabel(bind.id)) .. " ]"
		end
	end)

	return row
end

--==============================================================================
-- Pages
--==============================================================================

local tabDashboard = addTab("STATUS")
local tabSpeed     = addTab("SPEED")
local tabCombat    = addTab("COMBAT")
local tabSteal     = addTab("STEAL")
local tabMovement  = addTab("MOVE")
local tabKeybinds  = addTab("KEYS")
local tabSettings  = addTab("CONFIG")

-- Status ---------------------------------------------------------------------

local statCells = {}

do
	local section = addSection(tabDashboard, "Telemetry")

	local block = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		LayoutOrder            = 1,
		Parent                 = section.frame,
	})
	stroke(block, Theme.rule, 0.35)
	table.insert(section.rows, { frame = block, text = "fps ping speed profile telemetry" })

	local names = { "FPS", "PING", "SPEED", "PROFILE" }
	for index, name in ipairs(names) do
		local column = new("Frame", {
			Size                   = UDim2.new(0.25, 0, 1, 0),
			Position               = UDim2.new(0.25 * (index - 1), 0, 0, 0),
			BackgroundTransparency = 1,
			Parent                 = block,
		})

		if index > 1 then
			new("Frame", {
				Size                   = UDim2.new(0, 1, 1, -16),
				Position               = UDim2.new(0, 0, 0, 8),
				BackgroundColor3       = Theme.rule,
				BackgroundTransparency = 0.35,
				BorderSizePixel        = 0,
				Parent                 = column,
			})
		end

		text({
			Text       = name,
			TextSize   = 9,
			TextColor3 = Theme.dim,
			Position   = UDim2.new(0, 12, 0, 8),
			Size       = UDim2.new(1, -14, 0, 12),
			Parent     = column,
		})

		statCells[name] = text({
			Text     = "--",
			TextSize = 14,
			Position = UDim2.new(0, 12, 0, 22),
			Size     = UDim2.new(1, -14, 0, 16),
			Parent   = column,
		})
	end
end

do
	local section = addSection(tabDashboard, "Commands")

	local row = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		LayoutOrder            = 1,
		Parent                 = section.frame,
	})
	table.insert(section.rows, { frame = row, text = "drop tp down instant reset rescan podiums" })

	local commands = {
		{ text = "DROP",   action = "drop" },
		{ text = "TP DOWN", action = "tpFloor" },
		{ text = "RESET",  action = "instaReset" },
		{ text = "RESCAN", action = "rescan" },
	}

	for index, item in ipairs(commands) do
		local button = new("TextButton", {
			Size                   = UDim2.new(0.25, -6, 1, 0),
			Position               = UDim2.new(0.25 * (index - 1), index > 1 and 6 or 0, 0, 0),
			BackgroundColor3       = Theme.accent,
			BackgroundTransparency = 1,
			BorderSizePixel        = 0,
			AutoButtonColor        = false,
			Text                   = item.text,
			TextColor3             = Theme.sub,
			Font                   = FONT,
			TextSize               = 10,
			Parent                 = row,
		})
		local buttonStroke = stroke(button, Theme.rule, 0)
		accented(button, "BackgroundColor3")

		track(button.MouseEnter:Connect(function()
			buttonStroke.Color = Theme.accent
			button.TextColor3 = Theme.ink
		end))
		track(button.MouseLeave:Connect(function()
			buttonStroke.Color = Theme.rule
			button.TextColor3 = Theme.sub
		end))
		track(button.MouseButton1Click:Connect(function()
			button.BackgroundTransparency = 0.8
			task.delay(0.12, function() button.BackgroundTransparency = 1 end)
			Core.runAction(item.action)
		end))
	end
end

do
	local section = addSection(tabDashboard, "Channels")
	makeToggle(section, { label = "Auto Steal",    feature = "autoSteal" })
	makeToggle(section, { label = "Auto Bat",      feature = "autoBat" })
	makeToggle(section, { label = "Anti-Desync",   feature = "antiDesync" })
	makeToggle(section, { label = "Anti Ragdoll",  feature = "antiRagdoll" })
	makeToggle(section, { label = "Infinite Jump", feature = "infiniteJump" })
end

-- Speed ----------------------------------------------------------------------

do
	local section = addSection(tabSpeed, "Profile")

	local _, renderProfile = makeSegmented(section, {
		label   = "Active Profile",
		hint    = "Which speed the mover applies",
		width   = 56,
		options = {
			{ label = "Norm",  value = "normal" },
			{ label = "Carry", value = "carry" },
			{ label = "Lag",   value = "lagger" },
			{ label = "LagC",  value = "laggerCarry" },
		},
		onSelect = function(value) Core.setSpeedProfile(value) end,
	})
	watchProfile(renderProfile)

	makeToggle(section, {
		label   = "Auto Switch",
		hint    = "Detect carrying and pick the speed for you",
		feature = "autoSwitchSpeed",
	})
end

do
	local section = addSection(tabSpeed, "Rates")
	makeMeter(section, { label = "Normal",       key = "normalSpeed" })
	makeMeter(section, { label = "Carry",        key = "carrySpeed" })
	makeMeter(section, { label = "Lagger",       key = "laggerSpeed" })
	makeMeter(section, { label = "Lagger Carry", key = "laggerCarrySpeed", step = 0.5, decimals = 1 })
end

-- Combat ---------------------------------------------------------------------

do
	local section = addSection(tabCombat, "Aimbots")
	makeToggle(section, { label = "Auto Bat",    feature = "autoBat",    hint = "Chase, face and swing at the closest player" })
	makeToggle(section, { label = "Auto Swing",  feature = "autoSwing",  hint = "Keep swinging while Auto Bat chases" })
	makeToggle(section, { label = "Bat V2",      feature = "batV2",      hint = "Swings only once inside hit range" })
	makeToggle(section, { label = "Anti-Desync", feature = "antiDesync", hint = "Root pinning, damage negation, auto revive" })
end

do
	local section = addSection(tabCombat, "Counters")
	makeToggle(section, { label = "Bat Counter",    feature = "batCounter",    hint = "Swing back the moment you get ragdolled" })
	makeToggle(section, { label = "Medusa Counter", feature = "medusaCounter", hint = "Activate medusa when a grab lands" })
end

do
	local section = addSection(tabCombat, "Tuning")
	makeMeter(section, { label = "Chase Speed",  key = "aimbotSpeed" })
	makeMeter(section, { label = "Hover Height", key = "aimbotHeight", step = 0.1, decimals = 1 })
	makeMeter(section, { label = "Turn Rate",    key = "aimbotTurn" })
	makeMeter(section, { label = "Hit Range",    key = "batHitDistance" })
	makeMeter(section, { label = "Swing Delay",  key = "swingCooldown", step = 0.05, decimals = 2 })
end

-- Steal ----------------------------------------------------------------------

local podiumReadout

do
	local section = addSection(tabSteal, "Engine")
	makeToggle(section, { label = "Auto Steal", feature = "autoSteal", hint = "Fires the podium prompt for you" })

	local _, renderStealMode = makeSegmented(section, {
		label   = "Mode",
		hint    = "Normal holds in range, semi primes from far away",
		width   = 66,
		options = {
			{ label = "Normal", value = "normal" },
			{ label = "Semi",   value = "semi" },
		},
		onSelect = function(value) Core.setMode("stealMode", value) end,
	})
	watchMode("stealMode", renderStealMode)

	makeButton(section, { label = "Rescan Podiums", button = "Rescan", action = "rescan" })

	local row = addRow(section, "Cached Podiums", "Refreshed every 3 seconds while the engine runs")
	podiumReadout = text({
		Text           = "0",
		TextSize       = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position       = UDim2.new(1, -46, 0.5, -9),
		Size           = UDim2.new(0, 46, 0, 18),
		Parent         = row,
	})
end

do
	local section = addSection(tabSteal, "Ranges")
	makeMeter(section, { label = "Grab Radius",  key = "grabRadius",      hint = "Normal mode" })
	makeMeter(section, { label = "Hold Time",    key = "stealHold",       hint = "Normal mode", step = 0.05, decimals = 2 })
	makeMeter(section, { label = "Prime Range",  key = "primeStealRange", hint = "Semi mode: distance that starts the hold" })
	makeMeter(section, { label = "Steal Range",  key = "semiStealRadius", hint = "Semi mode: distance that fires the trigger" })
end

-- Movement -------------------------------------------------------------------

do
	local section = addSection(tabMovement, "Paths")
	makeToggle(section, { label = "Auto Left",  feature = "autoLeft",  hint = "Walk the left steal path, then stop" })
	makeToggle(section, { label = "Auto Right", feature = "autoRight", hint = "Walk the right steal path, then stop" })
end

do
	local section = addSection(tabMovement, "Drop and teleport")
	makeButton(section, { label = "Drop Brainrot", button = "Drop", action = "drop" })

	local _, renderDropMode = makeSegmented(section, {
		label   = "Drop Mode",
		width   = 66,
		options = {
			{ label = "Stand", value = "stand" },
			{ label = "Jump",  value = "jump" },
		},
		onSelect = function(value) Core.setMode("dropMode", value) end,
	})
	watchMode("dropMode", renderDropMode)

	makeButton(section, { label = "TP Down", button = "TP", action = "tpFloor" })
	makeToggle(section, { label = "Auto TP", feature = "autoTP", hint = "Repeat TP Down ten times a second" })
	makeMeter(section, { label = "TP Y Level", key = "tpY", step = 0.5, decimals = 1 })
end

do
	local section = addSection(tabMovement, "Character")
	makeToggle(section, { label = "Infinite Jump", feature = "infiniteJump" })
	makeToggle(section, { label = "Anti Ragdoll",  feature = "antiRagdoll" })
	makeToggle(section, { label = "No Collide",    feature = "noCollide", hint = "Walk through other players" })
	makeToggle(section, { label = "Unwalk",        feature = "unwalk",    hint = "Strips the Animate script" })
	makeButton(section, { label = "Instant Reset", button = "Reset", action = "instaReset" })
end

-- Keys -----------------------------------------------------------------------

do
	local section = addSection(tabKeybinds, "Bindings")
	for _, bind in ipairs(Core.binds) do
		makeKeybind(section, bind)
	end
end

-- Config ---------------------------------------------------------------------

do
	local section = addSection(tabSettings, "Phosphor")

	local row = addRow(section, "Colour", "Applies to every surface at once")
	local holder = new("Frame", {
		Size                   = UDim2.new(0, #ACCENTS * 22, 0, 14),
		Position               = UDim2.new(1, -(#ACCENTS * 22), 0.5, -7),
		BackgroundTransparency = 1,
		Parent                 = row,
	})

	local swatches = {}
	for index, entry in ipairs(ACCENTS) do
		local swatch = new("TextButton", {
			Size             = UDim2.new(0, 18, 0, 14),
			Position         = UDim2.new(0, (index - 1) * 22, 0, 0),
			BackgroundColor3 = entry.color,
			BorderSizePixel  = 0,
			AutoButtonColor  = false,
			Text             = "",
			Parent           = holder,
		})
		local swatchStroke = stroke(swatch, Theme.shell, 0)
		swatches[index] = swatchStroke

		if entry.color == Theme.accent then swatchStroke.Color = Theme.ink end

		track(swatch.MouseButton1Click:Connect(function()
			setAccent(entry.color)
			for _, other in ipairs(swatches) do other.Color = Theme.shell end
			swatchStroke.Color = Theme.ink
			UI.toast(entry.name .. " palette")
		end))
	end

	makeMeter(section, {
		label = "Console Scale", min = 0.6, max = 1.4, step = 0.05, decimals = 2,
		get = function() return prefs.menuScale end,
		set = function(value)
			prefs.menuScale = value
			windowScale.Scale = value
			savePrefs()
		end,
	})
	makeMeter(section, {
		label = "Strip Scale", min = 0.6, max = 1.6, step = 0.05, decimals = 2,
		get = function() return prefs.hudScale end,
		set = function(value)
			prefs.hudScale = value
			if hudScaleObj then hudScaleObj.Scale = value end
			savePrefs()
		end,
	})
	makeMeter(section, {
		label = "Keypad Scale", min = 0.5, max = 1.4, step = 0.05, decimals = 2,
		get = function() return prefs.padScale end,
		set = function(value)
			prefs.padScale = value
			if padScaleObj then padScaleObj.Scale = value end
			savePrefs()
		end,
	})
end

do
	local section = addSection(tabSettings, "Surfaces")

	makeToggle(section, {
		label = "Lock Positions",
		hint  = "Stops the console, strip and keypad from being dragged",
		get   = function() return prefs.locked end,
		set   = function(on) prefs.locked = on savePrefs() end,
	})
	makeToggle(section, {
		label = "Status Strip",
		get   = function() return prefs.showHud end,
		set   = function(on)
			prefs.showHud = on
			screenHud.Enabled = on
			savePrefs()
		end,
	})
	makeToggle(section, {
		label = "Touch Keypad",
		get   = function() return prefs.showPad end,
		set   = function(on)
			prefs.showPad = on
			screenPad.Enabled = on
			savePrefs()
		end,
	})
	makeButton(section, { label = "Reset Layout", button = "Reset", onClick = function() UI.resetLayout() end })
	makeButton(section, { label = "Unload", button = "Unload", danger = true, onClick = function() UI.unload() end })
end

--==============================================================================
-- Status strip
--==============================================================================

local HUD_W, HUD_H = 420, 26
local HUD_CELLS = 16

hud = new("Frame", {
	Name                   = "Strip",
	Size                   = UDim2.new(0, HUD_W, 0, HUD_H),
	Position               = udim2From(prefs.hudPos, UDim2.new(0.5, -HUD_W / 2, 0, 18)),
	BackgroundColor3       = Theme.shell,
	BackgroundTransparency = 0.08,
	BorderSizePixel        = 0,
	Active                 = true,
	Parent                 = screenHud,
})
stroke(hud, Theme.rule, 0)
hudScaleObj = new("UIScale", { Scale = prefs.hudScale, Parent = hud })
screenHud.Enabled = prefs.showHud

draggable(hud, hud, function(position)
	prefs.hudPos = udim2To(position)
	savePrefs()
end)

accented(new("Frame", {
	Size             = UDim2.new(0, 3, 1, 0),
	BackgroundColor3 = Theme.accent,
	BorderSizePixel  = 0,
	Parent           = hud,
}), "BackgroundColor3")

local hudStatus = text({
	Text     = "IDLE",
	TextSize = 11,
	Position = UDim2.new(0, 12, 0, 0),
	Size     = UDim2.new(0, 140, 1, 0),
	Parent   = hud,
})

local hudMeterW = HUD_CELLS * CELL_W + (HUD_CELLS - 1) * CELL_GAP
local hudMeter = new("Frame", {
	Size                   = UDim2.new(0, hudMeterW, 0, 8),
	Position               = UDim2.new(0, 160, 0.5, -4),
	BackgroundTransparency = 1,
	Parent                 = hud,
})

local hudCells = {}
for index = 1, HUD_CELLS do
	hudCells[index] = new("Frame", {
		Size             = UDim2.new(0, CELL_W, 1, 0),
		Position         = UDim2.new(0, (index - 1) * (CELL_W + CELL_GAP), 0, 0),
		BackgroundColor3 = Theme.rule,
		BorderSizePixel  = 0,
		Parent           = hudMeter,
	})
end

local hudPercent = text({
	Text           = "0%",
	TextSize       = 11,
	TextColor3     = Theme.sub,
	TextXAlignment = Enum.TextXAlignment.Right,
	Position       = UDim2.new(0, 262, 0, 0),
	Size           = UDim2.new(0, 40, 1, 0),
	Parent         = hud,
})

local hudTelemetry = text({
	Text           = "",
	TextSize       = 10,
	TextColor3     = Theme.dim,
	TextXAlignment = Enum.TextXAlignment.Right,
	Position       = UDim2.new(1, -104, 0, 0),
	Size           = UDim2.new(0, 96, 1, 0),
	Parent         = hud,
})

Core.on("progress", function(progress)
	local lit = math.floor(progress * HUD_CELLS + 0.5)
	for index = 1, HUD_CELLS do
		hudCells[index].BackgroundColor3 = index <= lit and Theme.accent or Theme.rule
	end
	hudPercent.Text = string.format("%d%%", math.floor(progress * 100 + 0.5))
end)

--==============================================================================
-- Touch keypad
--==============================================================================

local PAD_ITEMS = {
	{ kind = "feature", id = "autoLeft",    label = "AUTO\nLEFT" },
	{ kind = "feature", id = "autoRight",   label = "AUTO\nRGHT" },
	{ kind = "feature", id = "autoBat",     label = "BAT\nAIM" },
	{ kind = "feature", id = "batV2",       label = "BAT\nV2" },
	{ kind = "feature", id = "antiDesync",  label = "ANTI\nDSYN" },
	{ kind = "feature", id = "autoSteal",   label = "AUTO\nSTEAL" },
	{ kind = "profile", id = "lagger",      label = "LAG" },
	{ kind = "profile", id = "laggerCarry", label = "LAG\nCRY" },
	{ kind = "profile", id = "carry",       label = "CARRY" },
	{ kind = "action",  id = "drop",        label = "DROP" },
	{ kind = "action",  id = "tpFloor",     label = "TP\nDOWN" },
	{ kind = "action",  id = "instaReset",  label = "RSET" },
}

local PAD_COLS, PAD_KEY, PAD_GAP = 3, 52, 5
local padRows = math.ceil(#PAD_ITEMS / PAD_COLS)

padFrame = new("Frame", {
	Name                   = "Keypad",
	Size                   = UDim2.new(
		0, PAD_COLS * PAD_KEY + (PAD_COLS - 1) * PAD_GAP + 16,
		0, padRows * PAD_KEY + (padRows - 1) * PAD_GAP + 30),
	Position               = udim2From(prefs.padPos, UDim2.new(1, -206, 0.5, -126)),
	BackgroundColor3       = Theme.shell,
	BackgroundTransparency = 0.12,
	BorderSizePixel        = 0,
	Active                 = true,
	Parent                 = screenPad,
})
stroke(padFrame, Theme.rule, 0)
padScaleObj = new("UIScale", { Scale = prefs.padScale, Parent = padFrame })
screenPad.Enabled = prefs.showPad

local padHandle = new("Frame", {
	Size                   = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	Parent                 = padFrame,
})

accented(text({
	Text     = spaced("VELTREX"),
	TextSize = 9,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size     = UDim2.new(1, 0, 1, 0),
	Parent   = padHandle,
}), "TextColor3")

rule(padFrame, 22, 0.5, 8)

draggable(padFrame, padHandle, function(position)
	prefs.padPos = udim2To(position)
	savePrefs()
end)

local function padKey(item, index)
	local column   = (index - 1) % PAD_COLS
	local rowIndex = math.floor((index - 1) / PAD_COLS)

	local key = new("TextButton", {
		Size                   = UDim2.new(0, PAD_KEY, 0, PAD_KEY),
		Position               = UDim2.new(0, 8 + column * (PAD_KEY + PAD_GAP), 0, 30 + rowIndex * (PAD_KEY + PAD_GAP)),
		BackgroundColor3       = Theme.accent,
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		AutoButtonColor        = false,
		Text                   = item.label,
		TextColor3             = Theme.sub,
		Font                   = FONT,
		TextSize               = 10,
		LineHeight             = 1.15,
		Parent                 = padFrame,
	})
	local keyStroke = stroke(key, Theme.rule, 0)
	accented(key, "BackgroundColor3")

	-- Status bar across the top of the key, lit while the channel is active.
	local lamp = new("Frame", {
		Size                   = UDim2.new(1, -12, 0, 2),
		Position               = UDim2.new(0, 6, 0, 6),
		BackgroundColor3       = Theme.rule,
		BorderSizePixel        = 0,
		Parent                 = key,
	})

	local function render(on)
		tween(key, 0.12, {
			BackgroundTransparency = on and 0.88 or 1,
			TextColor3             = on and Theme.ink or Theme.sub,
		})
		keyStroke.Color = on and Theme.accent or Theme.rule
		lamp.BackgroundColor3 = on and Theme.accent or Theme.rule
	end

	track(key.MouseButton1Click:Connect(function()
		if item.kind == "feature" then
			Core.toggleFeature(item.id)
		elseif item.kind == "profile" then
			Core.toggleSpeedProfile(item.id)
		else
			Core.runAction(item.id)
			render(true)
			task.delay(0.15, function() render(false) end)
		end
	end))

	if item.kind == "feature" then
		watchFeature(item.id, render)
	elseif item.kind == "profile" then
		watchProfile(function(profile) render(profile == item.id) end)
	end
end

for index, item in ipairs(PAD_ITEMS) do
	padKey(item, index)
end

--==============================================================================
-- Collapsed tab
--==============================================================================

local stub = new("TextButton", {
	Name                   = "Stub",
	Size                   = UDim2.new(0, 108, 0, 22),
	Position               = udim2From(prefs.windowPos, UDim2.new(0, 36, 0.5, -11)),
	BackgroundColor3       = Theme.shell,
	BackgroundTransparency = 0.08,
	BorderSizePixel        = 0,
	AutoButtonColor        = false,
	Text                   = "",
	Visible                = false,
	Active                 = true,
	Parent                 = screenMain,
})
stroke(stub, Theme.rule, 0)

accented(new("Frame", {
	Size             = UDim2.new(0, 2, 1, 0),
	BackgroundColor3 = Theme.accent,
	BorderSizePixel  = 0,
	Parent           = stub,
}), "BackgroundColor3")

accented(text({
	Text     = spaced("VELTREX"),
	TextSize = 10,
	Position = UDim2.new(0, 10, 0, 0),
	Size     = UDim2.new(1, -12, 1, 0),
	Parent   = stub,
}), "TextColor3")

draggable(stub, stub)

local windowVisible = true

local function setWindowVisible(visible)
	windowVisible = visible
	window.Visible = visible
	if visible then
		stub.Visible = false
	else
		stub.Position = window.Position
		stub.Visible = true
	end
end

headerButton("_", -32, function() setWindowVisible(false) end)

local closeArmed = false
headerButton("X", -54, function()
	if closeArmed then
		UI.unload()
		return
	end
	closeArmed = true
	UI.toast("confirm unload", "warn")
	task.delay(3, function() closeArmed = false end)
end)

track(stub.MouseButton1Click:Connect(function() setWindowVisible(true) end))

Core.registerAction("toggleUI", "Toggle Menu", function()
	setWindowVisible(not windowVisible)
end)

--==============================================================================
-- Filter
--==============================================================================

local function applyFilter(query)
	query = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

	for _, tab in ipairs(tabs) do
		local matches = 0
		for _, section in ipairs(tab.sections) do
			local visible = 0
			for _, row in ipairs(section.rows) do
				local hit = query == "" or row.text:find(query, 1, true) ~= nil
				row.frame.Visible = hit
				if hit then visible = visible + 1 end
			end
			section.frame.Visible = visible > 0
			matches = matches + visible
		end

		tab.matches = matches
		tab.label.TextTransparency = (query ~= "" and matches == 0) and 0.6 or 0
	end

	if query ~= "" and activeTab and activeTab.matches == 0 then
		for _, tab in ipairs(tabs) do
			if tab.matches > 0 then
				selectTab(tab)
				break
			end
		end
	end
end

track(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	applyFilter(searchBox.Text)
end))

--==============================================================================
-- Layout reset / unload
--==============================================================================

function UI.resetLayout()
	prefs.windowPos = { xs = 0, xo = 36, ys = 0.5, yo = -WINDOW_H / 2 }
	prefs.hudPos    = { xs = 0.5, xo = -HUD_W / 2, ys = 0, yo = 18 }
	prefs.padPos    = { xs = 1, xo = -206, ys = 0.5, yo = -126 }

	window.Position   = udim2From(prefs.windowPos)
	stub.Position     = udim2From(prefs.windowPos)
	hud.Position      = udim2From(prefs.hudPos)
	padFrame.Position = udim2From(prefs.padPos)

	savePrefs()
	UI.toast("layout reset")
end

function UI.unload()
	for _, conn in ipairs(uiConns) do
		pcall(function() conn:Disconnect() end)
	end
	uiConns = {}

	screenMain:Destroy()
	screenHud:Destroy()
	screenPad:Destroy()

	Core.unload()
end

--==============================================================================
-- Live refresh
--==============================================================================

task.spawn(function()
	while not Core.unloaded do
		local state = Core.state
		local profile = Core.speedProfileLabel()

		if statCells.FPS then
			statCells.FPS.Text     = tostring(Core.fps)
			statCells.PING.Text    = tostring(Core.ping) .. "ms"
			statCells.SPEED.Text   = string.format("%.0f", state.speed)
			statCells.PROFILE.Text = string.upper(profile)
		end

		if podiumReadout then
			podiumReadout.Text = tostring(#(Core.Steal.animals or {}))
		end

		hudStatus.Text = string.upper(
			state.stealing and ("STEALING " .. tostring(state.stealLabel))
			or (state.aimTarget and ("TARGET " .. state.aimTarget))
			or profile
		)
		hudTelemetry.Text = string.format("%dF %dMS %.0fSPD", Core.fps, Core.ping, state.speed)

		local active = 0
		for _, def in ipairs(Core.features) do
			if Core.isOn(def.id) then active = active + 1 end
		end

		headerStats.Text = string.format("%d FPS   %d MS   %d ACTIVE", Core.fps, Core.ping, active)
		footerLeft.Text  = string.format("CH %02d ACTIVE", active)
		footerRight.Text = string.upper(profile) .. "   " .. string.format("%.0f SPD", state.speed)

		task.wait(0.25)
	end
end)

--==============================================================================
-- Boot
--==============================================================================

selectTab(tabs[1])
applyFilter("")

Core.on("feature", function(id, on)
	local def = Core.featureById[id]
	if def then
		UI.toast(def.label .. (on and " on" or " off"))
	end
end)

UI.window = window
UI.hud    = hud
UI.pad    = padFrame
UI.Theme  = Theme

return UI
