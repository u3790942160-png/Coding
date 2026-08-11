--!nocheck
--[==[
	Veltrex — Interface
	-------------------
	A complete replacement for the interface that shipped with the original
	script. Nothing in here knows how any feature works: it renders state that
	lives in Core and calls Core's public API.

	Pieces
	  Window   tabbed panel, sidebar, live search, drag, scale, minimise
	  HUD      compact status bar: steal progress, fps, ping, speed, profile
	  Pad      touch button grid that mirrors the panel's state
	  Toasts   transient notifications

	Controls are built from small factories (toggle / slider / segmented /
	keybind / button) so every row looks and behaves the same way.
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

default("accent",     { 88, 132, 255 })
default("menuScale",  1)
default("hudScale",   1)
default("padScale",   0.8)
default("locked",     false)
default("showHud",    true)
default("showPad",    UIS.TouchEnabled)
default("windowPos",  { xs = 0, xo = 40, ys = 0.5, yo = -220 })
default("hudPos",     { xs = 0.5, xo = -150, ys = 0, yo = 24 })
default("padPos",     { xs = 1, xo = -150, ys = 0.5, yo = -190 })

local function savePrefs()
	Core.save()
end

--==============================================================================
-- Theme
--==============================================================================

local Theme = {
	backdrop = Color3.fromRGB(9, 10, 14),
	panel    = Color3.fromRGB(15, 17, 22),
	panelAlt = Color3.fromRGB(20, 23, 30),
	row      = Color3.fromRGB(23, 26, 34),
	rowHover = Color3.fromRGB(30, 34, 44),
	stroke   = Color3.fromRGB(42, 47, 60),
	text     = Color3.fromRGB(238, 241, 248),
	sub      = Color3.fromRGB(134, 143, 163),
	dim      = Color3.fromRGB(88, 95, 112),
	good     = Color3.fromRGB(70, 205, 140),
	warn     = Color3.fromRGB(246, 190, 80),
	bad      = Color3.fromRGB(242, 95, 95),
	accent   = Color3.fromRGB(prefs.accent[1], prefs.accent[2], prefs.accent[3]),
}

local ACCENTS = {
	{ name = "Indigo", color = Color3.fromRGB(88, 132, 255) },
	{ name = "Mint",   color = Color3.fromRGB(56, 214, 166) },
	{ name = "Rose",   color = Color3.fromRGB(255, 94, 132) },
	{ name = "Amber",  color = Color3.fromRGB(255, 176, 58) },
	{ name = "Violet", color = Color3.fromRGB(167, 110, 255) },
	{ name = "Cyan",   color = Color3.fromRGB(56, 196, 235) },
}

-- Anything tinted with the accent registers itself so the colour can change
-- live when the user picks a different one.
local accentTargets = {}

local function accented(inst, prop, transform)
	table.insert(accentTargets, { inst = inst, prop = prop, transform = transform })
	inst[prop] = transform and transform(Theme.accent) or Theme.accent
	return inst
end

local function setAccent(color)
	Theme.accent = color
	prefs.accent = { math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255) }
	for _, target in ipairs(accentTargets) do
		if target.inst and target.inst.Parent then
			local value = target.transform and target.transform(color) or color
			pcall(function() target.inst[target.prop] = value end)
		end
	end
	savePrefs()
end

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

local function corner(inst, radius)
	new("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = inst })
	return inst
end

local function stroke(inst, color, thickness, transparency)
	return new("UIStroke", {
		Color            = color or Theme.stroke,
		Thickness        = thickness or 1,
		Transparency     = transparency or 0,
		ApplyStrokeMode  = Enum.ApplyStrokeMode.Border,
		Parent           = inst,
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
		Padding       = UDim.new(0, spacing or 6),
		Parent        = inst,
	})
end

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font          = props.Font or Enum.Font.GothamMedium
	props.TextColor3    = props.TextColor3 or Theme.text
	props.TextSize      = props.TextSize or 13
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return new("TextLabel", props)
end

local function tween(inst, time, goal, style)
	local info = TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local t = TS:Create(inst, info, goal)
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

local function wipeOldGuis()
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
end

wipeOldGuis()

local function screen(name, order)
	return new("ScreenGui", {
		Name             = name,
		ResetOnSpawn     = false,
		IgnoreGuiInset   = true,
		ZIndexBehavior   = Enum.ZIndexBehavior.Sibling,
		DisplayOrder     = order or 100,
		Parent           = root,
	})
end

local screenMain  = screen("VeltrexUI", 1000)
local screenHud   = screen("VeltrexHUD", 990)
local screenPad   = screen("VeltrexPad", 995)

-- Declared here so the settings page (built before them) can close over the
-- HUD and pad without reaching for globals.
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
-- Toasts
--==============================================================================

local toastHolder = new("Frame", {
	Name                   = "Toasts",
	AnchorPoint            = Vector2.new(1, 0),
	Position               = UDim2.new(1, -16, 0, 16),
	Size                   = UDim2.new(0, 260, 1, -32),
	BackgroundTransparency = 1,
	Parent                 = screenMain,
})
new("UIListLayout", {
	SortOrder            = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment  = Enum.HorizontalAlignment.Right,
	VerticalAlignment    = Enum.VerticalAlignment.Top,
	Padding              = UDim.new(0, 8),
	Parent               = toastHolder,
})

local TOAST_COLORS = {
	info = function() return Theme.accent end,
	good = function() return Theme.good end,
	warn = function() return Theme.warn end,
	bad  = function() return Theme.bad end,
}

function UI.toast(text, kind)
	local color = (TOAST_COLORS[kind or "info"] or TOAST_COLORS.info)()

	local card = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, 38),
		BackgroundColor3       = Theme.panel,
		BackgroundTransparency = 0.05,
		BorderSizePixel        = 0,
		Position               = UDim2.new(1, 20, 0, 0),
		Parent                 = toastHolder,
	})
	corner(card, 10)
	stroke(card, Theme.stroke, 1, 0.3)

	local bar = new("Frame", {
		Size             = UDim2.new(0, 3, 1, -14),
		Position         = UDim2.new(0, 8, 0, 7),
		BackgroundColor3 = color,
		BorderSizePixel  = 0,
		Parent           = card,
	})
	corner(bar, 2)

	label({
		Text     = text,
		Position = UDim2.new(0, 20, 0, 0),
		Size     = UDim2.new(1, -28, 1, 0),
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = Theme.text,
		Parent   = card,
	})

	tween(card, 0.22, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)

	task.delay(3, function()
		if not card.Parent then return end
		tween(card, 0.2, { Position = UDim2.new(1, 20, 0, 0), BackgroundTransparency = 1 })
		task.delay(0.25, function() card:Destroy() end)
	end)
end

--==============================================================================
-- State fan-out: Core events -> registered widgets
--==============================================================================

local featureWatchers = {}
local valueWatchers   = {}
local modeWatchers    = {}
local profileWatchers = {}

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

-- Core restores saved features quietly during start-up; "sync" is how it tells
-- the interface to re-read everything once that is done.
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
Core.on("notify", function(text, kind) UI.toast(text, kind) end)

--==============================================================================
-- Window shell
--==============================================================================

local WINDOW_W, WINDOW_H = 620, 430
local SIDEBAR_W = 138

local shadow = new("ImageLabel", {
	Name                   = "Shadow",
	AnchorPoint            = Vector2.new(0.5, 0.5),
	Position               = UDim2.new(0.5, 0, 0.5, 0),
	Size                   = UDim2.new(1, 70, 1, 70),
	BackgroundTransparency = 1,
	Image                  = "rbxassetid://6014261993",
	ImageColor3            = Color3.fromRGB(0, 0, 0),
	ImageTransparency      = 0.45,
	ScaleType              = Enum.ScaleType.Slice,
	SliceCenter            = Rect.new(49, 49, 450, 450),
	ZIndex                 = 0,
})

local window = new("Frame", {
	Name             = "Window",
	Size             = UDim2.new(0, WINDOW_W, 0, WINDOW_H),
	Position         = udim2From(prefs.windowPos, UDim2.new(0, 40, 0.5, -WINDOW_H / 2)),
	BackgroundColor3 = Theme.panel,
	BorderSizePixel  = 0,
	Active           = true,
	Parent           = screenMain,
})
corner(window, 14)
stroke(window, Theme.stroke, 1, 0.15)
shadow.Parent = window

local windowScale = new("UIScale", { Scale = prefs.menuScale, Parent = window })

new("UIGradient", {
	Rotation = 90,
	Color    = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.panel),
		ColorSequenceKeypoint.new(1, Theme.backdrop),
	}),
	Parent = window,
})

-- Header ---------------------------------------------------------------------

local header = new("Frame", {
	Name                   = "Header",
	Size                   = UDim2.new(1, 0, 0, 46),
	BackgroundTransparency = 1,
	Parent                 = window,
})

local logo = new("Frame", {
	Size             = UDim2.new(0, 10, 0, 10),
	Position         = UDim2.new(0, 18, 0, 18),
	BackgroundColor3 = Theme.accent,
	BorderSizePixel  = 0,
	Parent           = header,
})
corner(logo, 3)
accented(logo, "BackgroundColor3")

label({
	Text     = "VELTREX",
	Font     = Enum.Font.GothamBlack,
	TextSize = 15,
	Position = UDim2.new(0, 36, 0, 12),
	Size     = UDim2.new(0, 120, 0, 20),
	Parent   = header,
})

label({
	Text       = "Steal a Brainrot",
	TextSize   = 11,
	TextColor3 = Theme.sub,
	Position   = UDim2.new(0, 118, 0, 13),
	Size       = UDim2.new(0, 160, 0, 18),
	Parent     = header,
})

local function headerButton(text, offset, onClick)
	local btn = new("TextButton", {
		Size             = UDim2.new(0, 26, 0, 26),
		Position         = UDim2.new(1, offset, 0, 10),
		BackgroundColor3 = Theme.panelAlt,
		BorderSizePixel  = 0,
		AutoButtonColor  = false,
		Text             = text,
		TextColor3       = Theme.sub,
		Font             = Enum.Font.GothamBold,
		TextSize         = 14,
		Parent           = header,
	})
	corner(btn, 8)
	stroke(btn, Theme.stroke, 1, 0.4)

	track(btn.MouseEnter:Connect(function()
		tween(btn, 0.12, { BackgroundColor3 = Theme.rowHover, TextColor3 = Theme.text })
	end))
	track(btn.MouseLeave:Connect(function()
		tween(btn, 0.12, { BackgroundColor3 = Theme.panelAlt, TextColor3 = Theme.sub })
	end))
	track(btn.MouseButton1Click:Connect(onClick))
	return btn
end

new("Frame", {
	Size             = UDim2.new(1, -36, 0, 1),
	Position         = UDim2.new(0, 18, 0, 45),
	BackgroundColor3 = Theme.stroke,
	BackgroundTransparency = 0.4,
	BorderSizePixel  = 0,
	Parent           = header,
})

draggable(window, header, function(position)
	prefs.windowPos = udim2To(position)
	savePrefs()
end)

-- Sidebar --------------------------------------------------------------------

local sidebar = new("Frame", {
	Name                   = "Sidebar",
	Position               = UDim2.new(0, 12, 0, 54),
	Size                   = UDim2.new(0, SIDEBAR_W, 1, -66),
	BackgroundColor3       = Theme.panelAlt,
	BackgroundTransparency = 0.35,
	BorderSizePixel        = 0,
	Parent                 = window,
})
corner(sidebar, 10)
pad(sidebar, 8, 8, 8, 8)
list(sidebar, 4)

local selector = new("Frame", {
	Name             = "Selector",
	Size             = UDim2.new(0, 3, 0, 18),
	Position         = UDim2.new(0, 12, 0, 62),
	BackgroundColor3 = Theme.accent,
	BorderSizePixel  = 0,
	ZIndex           = 5,
	Parent           = window,
})
corner(selector, 2)
accented(selector, "BackgroundColor3")

-- Content --------------------------------------------------------------------

local contentArea = new("Frame", {
	Name                   = "Content",
	Position               = UDim2.new(0, SIDEBAR_W + 22, 0, 54),
	Size                   = UDim2.new(1, -(SIDEBAR_W + 34), 1, -88),
	BackgroundTransparency = 1,
	Parent                 = window,
})

local searchWrap = new("Frame", {
	Size             = UDim2.new(1, 0, 0, 28),
	BackgroundColor3 = Theme.row,
	BorderSizePixel  = 0,
	Parent           = contentArea,
})
corner(searchWrap, 8)
stroke(searchWrap, Theme.stroke, 1, 0.5)

-- Magnifier drawn from two frames: fonts cannot be relied on for glyphs.
local searchGlass = new("Frame", {
	Size                   = UDim2.new(0, 9, 0, 9),
	Position               = UDim2.new(0, 11, 0.5, -6),
	BackgroundTransparency = 1,
	Parent                 = searchWrap,
})
corner(searchGlass, 5)
stroke(searchGlass, Theme.dim, 1.5, 0)

new("Frame", {
	Size             = UDim2.new(0, 1, 0, 4),
	Position         = UDim2.new(0, 19, 0.5, 3),
	Rotation         = -45,
	BackgroundColor3 = Theme.dim,
	BorderSizePixel  = 0,
	Parent           = searchWrap,
})

local searchBox = new("TextBox", {
	Size                   = UDim2.new(1, -34, 1, 0),
	Position               = UDim2.new(0, 26, 0, 0),
	BackgroundTransparency = 1,
	Text                   = "",
	PlaceholderText        = "Search settings",
	PlaceholderColor3      = Theme.dim,
	TextColor3             = Theme.text,
	Font                   = Enum.Font.GothamMedium,
	TextSize               = 12,
	TextXAlignment         = Enum.TextXAlignment.Left,
	ClearTextOnFocus       = false,
	Parent                 = searchWrap,
})

local pageHolder = new("Frame", {
	Position               = UDim2.new(0, 0, 0, 36),
	Size                   = UDim2.new(1, 0, 1, -36),
	BackgroundTransparency = 1,
	Parent                 = contentArea,
})

-- Footer ---------------------------------------------------------------------

local footer = new("Frame", {
	Position               = UDim2.new(0, 18, 1, -30),
	Size                   = UDim2.new(1, -36, 0, 20),
	BackgroundTransparency = 1,
	Parent                 = window,
})

local footerLeft = label({
	Text       = "",
	TextSize   = 11,
	TextColor3 = Theme.dim,
	Size       = UDim2.new(0.6, 0, 1, 0),
	Parent     = footer,
})

local footerRight = label({
	Text           = "",
	TextSize       = 11,
	TextColor3     = Theme.dim,
	TextXAlignment = Enum.TextXAlignment.Right,
	Position       = UDim2.new(0.4, 0, 0, 0),
	Size           = UDim2.new(0.6, 0, 1, 0),
	Parent         = footer,
})

--==============================================================================
-- Tabs / sections / rows
--==============================================================================

local tabs, activeTab = {}, nil

-- Tab captions live in a child label, so selection colour is applied here
-- rather than on the button itself.
local function paintTabs()
	for _, tab in ipairs(tabs) do
		local caption = tab.button:FindFirstChildOfClass("TextLabel")
		if caption then
			caption.TextColor3 = (activeTab == tab) and Theme.text or Theme.sub
		end
	end
end

local function selectTab(tab)
	if activeTab == tab then return end
	for _, other in ipairs(tabs) do
		other.page.Visible = other == tab
		tween(other.button, 0.15, { BackgroundTransparency = other == tab and 0 or 1 })
	end
	activeTab = tab
	paintTabs()
	tween(selector, 0.22, {
		Position = UDim2.new(0, 12, 0, 67 + (tab.index - 1) * 32),
	}, Enum.EasingStyle.Back)
end

local function addTab(name)
	local index = #tabs + 1

	local button = new("TextButton", {
		Size                   = UDim2.new(1, 0, 0, 28),
		BackgroundColor3       = Theme.row,
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		AutoButtonColor        = false,
		Text                   = "",
		LayoutOrder            = index,
		Parent                 = sidebar,
	})
	corner(button, 7)

	label({
		Text     = name,
		Font     = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Theme.sub,
		Position = UDim2.new(0, 12, 0, 0),
		Size     = UDim2.new(1, -16, 1, 0),
		Parent   = button,
	})

	local page = new("ScrollingFrame", {
		Size                   = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		Visible                = false,
		CanvasSize             = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize    = Enum.AutomaticSize.Y,
		ScrollBarThickness     = 3,
		ScrollBarImageColor3   = Theme.stroke,
		ScrollingDirection     = Enum.ScrollingDirection.Y,
		Parent                 = pageHolder,
	})
	list(page, 8)
	pad(page, 0, 8, 0, 12)

	local tab = { name = name, index = index, button = button, page = page, sections = {} }
	tabs[index] = tab

	track(button.MouseButton1Click:Connect(function() selectTab(tab) end))
	track(button.MouseEnter:Connect(function()
		if activeTab ~= tab then tween(button, 0.12, { BackgroundTransparency = 0.6 }) end
	end))
	track(button.MouseLeave:Connect(function()
		if activeTab ~= tab then tween(button, 0.12, { BackgroundTransparency = 1 }) end
	end))

	return tab
end

local function addSection(tab, title)
	local section = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, 0),
		AutomaticSize          = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder            = #tab.sections + 1,
		Parent                 = tab.page,
	})
	list(section, 6)

	label({
		Text       = string.upper(title),
		Font       = Enum.Font.GothamBold,
		TextSize   = 10,
		TextColor3 = Theme.dim,
		Size       = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 0,
		Parent     = section,
	})

	local entry = { frame = section, rows = {}, tab = tab }
	table.insert(tab.sections, entry)
	return entry
end

-- Base row: label on the left, control slot on the right.
local function addRow(section, text, hint, height)
	height = height or (hint and 44 or 36)

	local row = new("Frame", {
		Size             = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Theme.row,
		BorderSizePixel  = 0,
		LayoutOrder      = #section.rows + 1,
		Parent           = section.frame,
	})
	corner(row, 8)
	stroke(row, Theme.stroke, 1, 0.55)

	label({
		Text     = text,
		TextSize = 13,
		Position = UDim2.new(0, 12, 0, hint and 6 or 0),
		Size     = UDim2.new(1, -110, 0, hint and 16 or height),
		Parent   = row,
	})

	if hint then
		label({
			Text       = hint,
			TextSize   = 10,
			TextColor3 = Theme.dim,
			Position   = UDim2.new(0, 12, 0, 23),
			Size       = UDim2.new(1, -110, 0, 14),
			Parent     = row,
		})
	end

	track(row.MouseEnter:Connect(function() tween(row, 0.12, { BackgroundColor3 = Theme.rowHover }) end))
	track(row.MouseLeave:Connect(function() tween(row, 0.12, { BackgroundColor3 = Theme.row }) end))

	table.insert(section.rows, { frame = row, text = (text .. " " .. (hint or "")):lower() })
	return row
end

--==============================================================================
-- Controls
--==============================================================================

local function makeToggle(section, opts)
	local row = addRow(section, opts.label, opts.hint)

	local trackFrame = new("Frame", {
		Size             = UDim2.new(0, 40, 0, 22),
		Position         = UDim2.new(1, -52, 0.5, -11),
		BackgroundColor3 = Theme.panelAlt,
		BorderSizePixel  = 0,
		Parent           = row,
	})
	corner(trackFrame, 11)
	local trackStroke = stroke(trackFrame, Theme.stroke, 1, 0.2)

	local knob = new("Frame", {
		Size             = UDim2.new(0, 16, 0, 16),
		Position         = UDim2.new(0, 3, 0.5, -8),
		BackgroundColor3 = Theme.dim,
		BorderSizePixel  = 0,
		Parent           = trackFrame,
	})
	corner(knob, 8)

	local button = new("TextButton", {
		Size                   = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text                   = "",
		Parent                 = row,
	})

	local function render(on)
		tween(trackFrame, 0.18, { BackgroundColor3 = on and Theme.accent or Theme.panelAlt })
		tween(trackStroke, 0.18, { Transparency = on and 1 or 0.2 })
		tween(knob, 0.18, {
			Position         = on and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
			BackgroundColor3 = on and Color3.fromRGB(255, 255, 255) or Theme.dim,
		}, Enum.EasingStyle.Back)
	end

	track(button.MouseButton1Click:Connect(function()
		if opts.feature then
			Core.toggleFeature(opts.feature)
		elseif opts.get and opts.set then
			opts.set(not opts.get())
			render(opts.get())
		end
	end))

	if opts.feature then
		watchFeature(opts.feature, render)
	else
		render(opts.get and opts.get() or false)
	end

	return row
end

local function makeButton(section, opts)
	local row = addRow(section, opts.label, opts.hint)

	local button = new("TextButton", {
		Size             = UDim2.new(0, opts.width or 84, 0, 24),
		Position         = UDim2.new(1, -(opts.width or 84) - 12, 0.5, -12),
		BackgroundColor3 = opts.danger and Theme.bad or Theme.accent,
		BorderSizePixel  = 0,
		AutoButtonColor  = false,
		Text             = opts.button or "Run",
		TextColor3       = Color3.fromRGB(255, 255, 255),
		Font             = Enum.Font.GothamBold,
		TextSize         = 12,
		Parent           = row,
	})
	corner(button, 7)
	if not opts.danger then accented(button, "BackgroundColor3") end

	track(button.MouseEnter:Connect(function() tween(button, 0.12, { BackgroundTransparency = 0.15 }) end))
	track(button.MouseLeave:Connect(function() tween(button, 0.12, { BackgroundTransparency = 0 }) end))
	track(button.MouseButton1Click:Connect(function()
		tween(button, 0.08, { Size = UDim2.new(0, (opts.width or 84) - 6, 0, 22) })
		task.delay(0.09, function()
			tween(button, 0.12, { Size = UDim2.new(0, opts.width or 84, 0, 24) })
		end)
		if opts.action then Core.runAction(opts.action) end
		if opts.onClick then opts.onClick() end
	end))

	return row
end

local function makeSegmented(section, opts)
	local row = addRow(section, opts.label, opts.hint)

	local count  = #opts.options
	local width  = opts.width or 62
	local total  = count * width + (count - 1) * 4

	local holder = new("Frame", {
		Size                   = UDim2.new(0, total, 0, 24),
		Position               = UDim2.new(1, -total - 12, 0.5, -12),
		BackgroundTransparency = 1,
		Parent                 = row,
	})

	local buttons = {}
	for index, option in ipairs(opts.options) do
		local btn = new("TextButton", {
			Size             = UDim2.new(0, width, 1, 0),
			Position         = UDim2.new(0, (index - 1) * (width + 4), 0, 0),
			BackgroundColor3 = Theme.panelAlt,
			BorderSizePixel  = 0,
			AutoButtonColor  = false,
			Text             = option.label,
			TextColor3       = Theme.sub,
			Font             = Enum.Font.GothamBold,
			TextSize         = 11,
			Parent           = holder,
		})
		corner(btn, 7)
		stroke(btn, Theme.stroke, 1, 0.5)
		buttons[index] = btn

		track(btn.MouseButton1Click:Connect(function() opts.onSelect(option.value) end))
	end

	local function render(value)
		for index, option in ipairs(opts.options) do
			local on = option.value == value
			tween(buttons[index], 0.15, {
				BackgroundColor3 = on and Theme.accent or Theme.panelAlt,
				TextColor3       = on and Color3.fromRGB(255, 255, 255) or Theme.sub,
			})
		end
	end

	return row, render
end

-- Drives either a Core numeric setting (opts.key) or an arbitrary value pair
-- (opts.get / opts.set), used by the interface's own scale controls.
local function makeSlider(section, opts)
	local limits  = (opts.key and Core.limits[opts.key]) or { opts.min or 0, opts.max or 100 }
	local minimum = opts.min or limits[1]
	local maximum = opts.max or limits[2]
	local step    = opts.step or 1
	local decimals = opts.decimals or (step < 1 and 2 or 0)

	local row = addRow(section, opts.label, opts.hint, 52)

	local valueBox = new("TextBox", {
		Size             = UDim2.new(0, 54, 0, 20),
		Position         = UDim2.new(1, -66, 0, 8),
		BackgroundColor3 = Theme.panelAlt,
		BorderSizePixel  = 0,
		Text             = "0",
		TextColor3       = Theme.text,
		Font             = Enum.Font.GothamBold,
		TextSize         = 11,
		ClearTextOnFocus = false,
		Parent           = row,
	})
	corner(valueBox, 6)
	stroke(valueBox, Theme.stroke, 1, 0.5)

	local trackFrame = new("Frame", {
		Size             = UDim2.new(1, -24, 0, 4),
		Position         = UDim2.new(0, 12, 1, -14),
		BackgroundColor3 = Theme.panelAlt,
		BorderSizePixel  = 0,
		Parent           = row,
	})
	corner(trackFrame, 2)

	local fill = new("Frame", {
		Size             = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme.accent,
		BorderSizePixel  = 0,
		Parent           = trackFrame,
	})
	corner(fill, 2)
	accented(fill, "BackgroundColor3")

	local knob = new("Frame", {
		Size             = UDim2.new(0, 12, 0, 12),
		Position         = UDim2.new(0, -6, 0.5, -6),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel  = 0,
		ZIndex           = 3,
		Parent           = trackFrame,
	})
	corner(knob, 6)

	local hit = new("TextButton", {
		Size                   = UDim2.new(1, 0, 0, 20),
		Position               = UDim2.new(0, 0, 0.5, -10),
		BackgroundTransparency = 1,
		Text                   = "",
		Parent                 = trackFrame,
	})

	local function format(value)
		if decimals > 0 then
			return string.format("%." .. decimals .. "f", value)
		end
		return tostring(math.floor(value + 0.5))
	end

	local function render(value)
		local alpha = (value - minimum) / math.max(maximum - minimum, 0.0001)
		alpha = math.clamp(alpha, 0, 1)
		fill.Size    = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, -6, 0.5, -6)
		if not valueBox:IsFocused() then valueBox.Text = format(value) end
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
		if opts.onChange then opts.onChange(value) end
	end

	local dragging = false

	local function fromInput(input)
		local alpha = (input.Position.X - trackFrame.AbsolutePosition.X) / math.max(trackFrame.AbsoluteSize.X, 1)
		commit(minimum + math.clamp(alpha, 0, 1) * (maximum - minimum))
	end

	track(hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromInput(input)
		end
	end))
	track(hit.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
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

	track(valueBox.FocusLost:Connect(function()
		local typed = tonumber(valueBox.Text)
		if typed then commit(typed) else render(current()) end
	end))

	if opts.key then
		watchValue(opts.key, render)
	else
		render(current())
	end
	return row
end

local function makeKeybind(section, bind)
	local row = addRow(section, bind.label)

	local button = new("TextButton", {
		Size             = UDim2.new(0, 90, 0, 24),
		Position         = UDim2.new(1, -102, 0.5, -12),
		BackgroundColor3 = Theme.panelAlt,
		BorderSizePixel  = 0,
		AutoButtonColor  = false,
		Text             = Core.bindLabel(bind.id),
		TextColor3       = Theme.text,
		Font             = Enum.Font.GothamBold,
		TextSize         = 11,
		Parent           = row,
	})
	corner(button, 7)
	local buttonStroke = stroke(button, Theme.stroke, 1, 0.4)

	local listening, listener = false, nil

	local function stopListening()
		listening = false
		Core.captureInput(false)
		if listener then
			listener:Disconnect()
			listener = nil
		end
		button.Text = Core.bindLabel(bind.id)
		tween(buttonStroke, 0.15, { Color = Theme.stroke, Transparency = 0.4 })
	end

	track(button.MouseButton1Click:Connect(function()
		if listening then
			stopListening()
			return
		end

		listening = true
		Core.captureInput(true)
		button.Text = "press a key"
		tween(buttonStroke, 0.15, { Color = Theme.accent, Transparency = 0 })

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
		if id == bind.id then button.Text = Core.bindLabel(bind.id) end
	end)

	return row
end

--==============================================================================
-- Pages
--==============================================================================

local tabDashboard = addTab("Dashboard")
local tabSpeed     = addTab("Speed")
local tabCombat    = addTab("Combat")
local tabSteal     = addTab("Steal")
local tabMovement  = addTab("Movement")
local tabKeybinds  = addTab("Keybinds")
local tabSettings  = addTab("Settings")

-- Dashboard ------------------------------------------------------------------

local statCards = {}

do
	local section = addSection(tabDashboard, "Live")

	local grid = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, 58),
		BackgroundTransparency = 1,
		LayoutOrder            = 1,
		Parent                 = section.frame,
	})
	table.insert(section.rows, { frame = grid, text = "fps ping speed profile status" })

	local names = { "FPS", "PING", "SPEED", "PROFILE" }
	for index, name in ipairs(names) do
		local card = new("Frame", {
			Size             = UDim2.new(0.25, -6, 1, 0),
			Position         = UDim2.new(0.25 * (index - 1), index > 1 and 6 or 0, 0, 0),
			BackgroundColor3 = Theme.row,
			BorderSizePixel  = 0,
			Parent           = grid,
		})
		corner(card, 8)
		stroke(card, Theme.stroke, 1, 0.55)

		label({
			Text       = name,
			TextSize   = 9,
			TextColor3 = Theme.dim,
			Font       = Enum.Font.GothamBold,
			Position   = UDim2.new(0, 10, 0, 9),
			Size       = UDim2.new(1, -12, 0, 12),
			Parent     = card,
		})

		statCards[name] = label({
			Text     = "-",
			TextSize = 15,
			Font     = Enum.Font.GothamBold,
			Position = UDim2.new(0, 10, 0, 24),
			Size     = UDim2.new(1, -14, 0, 22),
			Parent   = card,
		})
	end
end

do
	local section = addSection(tabDashboard, "Quick actions")

	local row = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder            = 1,
		Parent                 = section.frame,
	})
	table.insert(section.rows, { frame = row, text = "drop tp down instant reset rescan plots" })

	local quick = {
		{ text = "Drop",     action = "drop" },
		{ text = "TP Down",  action = "tpFloor" },
		{ text = "Reset",    action = "instaReset" },
		{ text = "Rescan",   action = "rescan" },
	}

	for index, item in ipairs(quick) do
		local btn = new("TextButton", {
			Size             = UDim2.new(0.25, -6, 1, 0),
			Position         = UDim2.new(0.25 * (index - 1), index > 1 and 6 or 0, 0, 0),
			BackgroundColor3 = Theme.row,
			BorderSizePixel  = 0,
			AutoButtonColor  = false,
			Text             = item.text,
			TextColor3       = Theme.text,
			Font             = Enum.Font.GothamBold,
			TextSize         = 12,
			Parent           = row,
		})
		corner(btn, 8)
		stroke(btn, Theme.stroke, 1, 0.5)

		track(btn.MouseEnter:Connect(function()
			tween(btn, 0.12, { BackgroundColor3 = Theme.rowHover })
		end))
		track(btn.MouseLeave:Connect(function()
			tween(btn, 0.12, { BackgroundColor3 = Theme.row })
		end))
		track(btn.MouseButton1Click:Connect(function() Core.runAction(item.action) end))
	end
end

do
	local section = addSection(tabDashboard, "Favourites")
	makeToggle(section, { label = "Auto Steal",   feature = "autoSteal",   hint = "Steal from every plot in range" })
	makeToggle(section, { label = "Auto Bat",     feature = "autoBat",     hint = "Chase and hit the nearest player" })
	makeToggle(section, { label = "Anti-Desync",  feature = "antiDesync",  hint = "Pin to the target and negate damage" })
	makeToggle(section, { label = "Anti Ragdoll", feature = "antiRagdoll", hint = "Stand back up the instant you fall" })
	makeToggle(section, { label = "Infinite Jump", feature = "infiniteJump" })
end

-- Speed ----------------------------------------------------------------------

do
	local section = addSection(tabSpeed, "Profile")

	local _, renderProfile = makeSegmented(section, {
		label   = "Speed Profile",
		hint    = "Which speed the mover applies",
		width   = 58,
		options = {
			{ label = "Normal", value = "normal" },
			{ label = "Carry",  value = "carry" },
			{ label = "Lagger", value = "lagger" },
			{ label = "L.Carry", value = "laggerCarry" },
		},
		onSelect = function(value) Core.setSpeedProfile(value) end,
	})
	watchProfile(renderProfile)

	makeToggle(section, {
		label   = "Auto Switch Speed",
		hint    = "Detect carrying and pick the speed for you",
		feature = "autoSwitchSpeed",
	})
end

do
	local section = addSection(tabSpeed, "Values")
	makeSlider(section, { label = "Normal Speed",  key = "normalSpeed" })
	makeSlider(section, { label = "Carry Speed",   key = "carrySpeed" })
	makeSlider(section, { label = "Lagger Speed",  key = "laggerSpeed" })
	makeSlider(section, { label = "Lagger Carry",  key = "laggerCarrySpeed", step = 0.5, decimals = 1 })
end

-- Combat ---------------------------------------------------------------------

do
	local section = addSection(tabCombat, "Aimbots")
	makeToggle(section, { label = "Auto Bat",   feature = "autoBat",  hint = "Chase, face and swing at the closest player" })
	makeToggle(section, { label = "Auto Swing", feature = "autoSwing", hint = "Keep swinging while Auto Bat chases" })
	makeToggle(section, { label = "Bat Aimbot V2", feature = "batV2", hint = "Swings only once inside hit range" })
	makeToggle(section, { label = "Anti-Desync", feature = "antiDesync", hint = "Root pinning, damage negation, auto revive" })
end

do
	local section = addSection(tabCombat, "Counters")
	makeToggle(section, { label = "Bat Counter",    feature = "batCounter",    hint = "Swing back the moment you get ragdolled" })
	makeToggle(section, { label = "Medusa Counter", feature = "medusaCounter", hint = "Activate medusa when a grab lands" })
end

do
	local section = addSection(tabCombat, "Tuning")
	makeSlider(section, { label = "Chase Speed",   key = "aimbotSpeed" })
	makeSlider(section, { label = "Hover Height",  key = "aimbotHeight", step = 0.1, decimals = 1 })
	makeSlider(section, { label = "Turn Rate",     key = "aimbotTurn" })
	makeSlider(section, { label = "Hit Distance",  key = "batHitDistance" })
	makeSlider(section, { label = "Swing Cooldown", key = "swingCooldown", step = 0.05, decimals = 2 })
end

-- Steal ----------------------------------------------------------------------

local stealInfoLabel

do
	local section = addSection(tabSteal, "Auto steal")
	makeToggle(section, { label = "Auto Steal", feature = "autoSteal", hint = "Fires the podium prompt for you" })

	local _, renderStealMode = makeSegmented(section, {
		label   = "Mode",
		hint    = "Normal holds in range, semi primes from far away",
		width   = 70,
		options = {
			{ label = "Normal", value = "normal" },
			{ label = "Semi",   value = "semi" },
		},
		onSelect = function(value) Core.setMode("stealMode", value) end,
	})
	watchMode("stealMode", renderStealMode)

	makeButton(section, { label = "Rescan Podiums", hint = "Rebuild the plot cache now", button = "Rescan", action = "rescan" })

	local infoRow = addRow(section, "Cached podiums", "Updated every 3 seconds while auto steal runs")
	stealInfoLabel = label({
		Text           = "0",
		TextSize       = 13,
		Font           = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position       = UDim2.new(1, -60, 0, 0),
		Size           = UDim2.new(0, 48, 1, 0),
		Parent         = infoRow,
	})
end

do
	local section = addSection(tabSteal, "Ranges")
	makeSlider(section, { label = "Grab Radius",       key = "grabRadius",      hint = "Normal mode" })
	makeSlider(section, { label = "Hold Duration",     key = "stealHold",       hint = "Normal mode", step = 0.05, decimals = 2 })
	makeSlider(section, { label = "Prime Steal Range", key = "primeStealRange", hint = "Semi mode: distance that starts the hold" })
	makeSlider(section, { label = "Steal Range",       key = "semiStealRadius", hint = "Semi mode: distance that fires the trigger" })
end

-- Movement -------------------------------------------------------------------

do
	local section = addSection(tabMovement, "Paths")
	makeToggle(section, { label = "Auto Left",  feature = "autoLeft",  hint = "Walk the left steal path, then stop" })
	makeToggle(section, { label = "Auto Right", feature = "autoRight", hint = "Walk the right steal path, then stop" })
end

do
	local section = addSection(tabMovement, "Drop and teleport")

	makeButton(section, { label = "Drop Brainrot", hint = "Fling drop or jump drop", button = "Drop", action = "drop" })

	local _, renderDropMode = makeSegmented(section, {
		label   = "Drop Mode",
		width   = 70,
		options = {
			{ label = "Stand", value = "stand" },
			{ label = "Jump",  value = "jump" },
		},
		onSelect = function(value) Core.setMode("dropMode", value) end,
	})
	watchMode("dropMode", renderDropMode)

	makeButton(section, { label = "TP Down", hint = "Snap to the floor level below", button = "TP", action = "tpFloor" })
	makeToggle(section, { label = "Auto TP Down", feature = "autoTP", hint = "Repeat TP Down ten times a second" })
	makeSlider(section, { label = "TP Y Level", key = "tpY", hint = "World height TP Down snaps to", step = 0.5, decimals = 1 })
end

do
	local section = addSection(tabMovement, "Character")
	makeToggle(section, { label = "Infinite Jump", feature = "infiniteJump" })
	makeToggle(section, { label = "Anti Ragdoll",  feature = "antiRagdoll" })
	makeToggle(section, { label = "No Collide",    feature = "noCollide", hint = "Walk through other players" })
	makeToggle(section, { label = "Unwalk",        feature = "unwalk",    hint = "Strips the Animate script" })
	makeButton(section, { label = "Instant Reset", hint = "Fire the reset remote until you respawn", button = "Reset", action = "instaReset" })
end

-- Keybinds -------------------------------------------------------------------

do
	local section = addSection(tabKeybinds, "Bindings")
	for _, bind in ipairs(Core.binds) do
		makeKeybind(section, bind)
	end
end

-- Settings -------------------------------------------------------------------

do
	local section = addSection(tabSettings, "Appearance")

	local accentRow = addRow(section, "Accent", "Colour used across the interface")
	local swatches = new("Frame", {
		Size                   = UDim2.new(0, #ACCENTS * 24, 0, 20),
		Position               = UDim2.new(1, -(#ACCENTS * 24) - 12, 0.5, -10),
		BackgroundTransparency = 1,
		Parent                 = accentRow,
	})

	for index, entry in ipairs(ACCENTS) do
		local swatch = new("TextButton", {
			Size             = UDim2.new(0, 20, 0, 20),
			Position         = UDim2.new(0, (index - 1) * 24, 0, 0),
			BackgroundColor3 = entry.color,
			BorderSizePixel  = 0,
			AutoButtonColor  = false,
			Text             = "",
			Parent           = swatches,
		})
		corner(swatch, 10)
		stroke(swatch, Theme.stroke, 1, 0.4)

		track(swatch.MouseButton1Click:Connect(function()
			setAccent(entry.color)
			UI.toast(entry.name .. " accent applied", "good")
		end))
	end

	makeSlider(section, {
		label = "Menu Scale", hint = "Size of this panel",
		min = 0.6, max = 1.4, step = 0.05, decimals = 2,
		get = function() return prefs.menuScale end,
		set = function(value)
			prefs.menuScale = value
			windowScale.Scale = value
			savePrefs()
		end,
	})
	makeSlider(section, {
		label = "HUD Scale", min = 0.6, max = 1.6, step = 0.05, decimals = 2,
		get = function() return prefs.hudScale end,
		set = function(value)
			prefs.hudScale = value
			if hudScaleObj then hudScaleObj.Scale = value end
			savePrefs()
		end,
	})
	makeSlider(section, {
		label = "Touch Pad Scale", min = 0.5, max = 1.4, step = 0.05, decimals = 2,
		get = function() return prefs.padScale end,
		set = function(value)
			prefs.padScale = value
			if padScaleObj then padScaleObj.Scale = value end
			savePrefs()
		end,
	})
end

do
	local section = addSection(tabSettings, "Interface")

	makeToggle(section, {
		label = "Lock Positions",
		hint  = "Stops the panel, HUD and pad from being dragged",
		get   = function() return prefs.locked end,
		set   = function(on) prefs.locked = on savePrefs() end,
	})
	makeToggle(section, {
		label = "Show HUD",
		hint  = "Steal progress, fps, ping and speed",
		get   = function() return prefs.showHud end,
		set   = function(on)
			prefs.showHud = on
			screenHud.Enabled = on
			savePrefs()
		end,
	})
	makeToggle(section, {
		label = "Show Touch Pad",
		hint  = "Floating buttons for mobile",
		get   = function() return prefs.showPad end,
		set   = function(on)
			prefs.showPad = on
			screenPad.Enabled = on
			savePrefs()
		end,
	})
	makeButton(section, {
		label  = "Reset Layout",
		hint   = "Move every window back to its default position",
		button = "Reset",
		onClick = function() UI.resetLayout() end,
	})
	makeButton(section, {
		label  = "Unload Veltrex",
		hint   = "Stop every feature and remove the interface",
		button = "Unload",
		danger = true,
		onClick = function() UI.unload() end,
	})
end

--==============================================================================
-- HUD
--==============================================================================

hud = new("Frame", {
	Name             = "Status",
	Size             = UDim2.new(0, 300, 0, 66),
	Position         = udim2From(prefs.hudPos, UDim2.new(0.5, -150, 0, 24)),
	BackgroundColor3 = Theme.panel,
	BorderSizePixel  = 0,
	Active           = true,
	Parent           = screenHud,
})
corner(hud, 12)
stroke(hud, Theme.stroke, 1, 0.25)
hudScaleObj = new("UIScale", { Scale = prefs.hudScale, Parent = hud })
screenHud.Enabled = prefs.showHud

draggable(hud, hud, function(position)
	prefs.hudPos = udim2To(position)
	savePrefs()
end)

local hudBadge = new("Frame", {
	Size             = UDim2.new(0, 34, 0, 34),
	Position         = UDim2.new(0, 12, 0.5, -17),
	BackgroundColor3 = Theme.accent,
	BorderSizePixel  = 0,
	Parent           = hud,
})
corner(hudBadge, 10)
accented(hudBadge, "BackgroundColor3")

label({
	Text           = "V",
	Font           = Enum.Font.GothamBlack,
	TextSize       = 16,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size           = UDim2.new(1, 0, 1, 0),
	Parent         = hudBadge,
})

local hudTitle = label({
	Text     = "Idle",
	Font     = Enum.Font.GothamBold,
	TextSize = 12,
	Position = UDim2.new(0, 56, 0, 10),
	Size     = UDim2.new(1, -120, 0, 14),
	Parent   = hud,
})

local hudPercent = label({
	Text           = "0%",
	Font           = Enum.Font.GothamBold,
	TextSize       = 12,
	TextColor3     = Theme.sub,
	TextXAlignment = Enum.TextXAlignment.Right,
	Position       = UDim2.new(1, -58, 0, 10),
	Size           = UDim2.new(0, 46, 0, 14),
	Parent         = hud,
})

local hudBarBg = new("Frame", {
	Size             = UDim2.new(1, -68, 0, 6),
	Position         = UDim2.new(0, 56, 0, 28),
	BackgroundColor3 = Theme.panelAlt,
	BorderSizePixel  = 0,
	Parent           = hud,
})
corner(hudBarBg, 3)

local hudBarFill = new("Frame", {
	Size             = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = Theme.accent,
	BorderSizePixel  = 0,
	Parent           = hudBarBg,
})
corner(hudBarFill, 3)
accented(hudBarFill, "BackgroundColor3")

local hudStats = label({
	Text       = "",
	TextSize   = 10,
	TextColor3 = Theme.dim,
	Position   = UDim2.new(0, 56, 0, 40),
	Size       = UDim2.new(1, -68, 0, 16),
	Parent     = hud,
})

-- Steal progress ticks up to fifty times a second, so this is written straight
-- to the frame instead of spawning a tween per update.
Core.on("progress", function(progress)
	hudBarFill.Size = UDim2.new(progress, 0, 1, 0)
	hudPercent.Text = string.format("%d%%", math.floor(progress * 100 + 0.5))
end)

--==============================================================================
-- Touch pad
--==============================================================================

local PAD_ITEMS = {
	{ kind = "feature", id = "autoLeft",    label = "AUTO\nLEFT" },
	{ kind = "feature", id = "autoRight",   label = "AUTO\nRIGHT" },
	{ kind = "feature", id = "autoBat",     label = "BAT\nAIM" },
	{ kind = "feature", id = "batV2",       label = "BAT\nV2" },
	{ kind = "feature", id = "antiDesync",  label = "ANTI\nDESYNC" },
	{ kind = "feature", id = "autoSteal",   label = "AUTO\nSTEAL" },
	{ kind = "profile", id = "lagger",      label = "LAGGER" },
	{ kind = "profile", id = "laggerCarry", label = "LAGGER\nCARRY" },
	{ kind = "profile", id = "carry",       label = "CARRY" },
	{ kind = "action",  id = "drop",        label = "DROP" },
	{ kind = "action",  id = "tpFloor",     label = "TP\nDOWN" },
	{ kind = "action",  id = "instaReset",  label = "INSTA\nRESET" },
}

local PAD_COLS, PAD_BTN, PAD_GAP = 2, 62, 6
local padRows = math.ceil(#PAD_ITEMS / PAD_COLS)

padFrame = new("Frame", {
	Name             = "Pad",
	Size             = UDim2.new(0, PAD_COLS * PAD_BTN + (PAD_COLS - 1) * PAD_GAP + 16,
		0, padRows * PAD_BTN + (padRows - 1) * PAD_GAP + 34),
	Position         = udim2From(prefs.padPos, UDim2.new(1, -150, 0.5, -190)),
	BackgroundColor3 = Theme.panel,
	BackgroundTransparency = 0.15,
	BorderSizePixel  = 0,
	Active           = true,
	Parent           = screenPad,
})
corner(padFrame, 12)
stroke(padFrame, Theme.stroke, 1, 0.4)
padScaleObj = new("UIScale", { Scale = prefs.padScale, Parent = padFrame })
screenPad.Enabled = prefs.showPad

local padHandle = new("Frame", {
	Size             = UDim2.new(1, 0, 0, 26),
	BackgroundTransparency = 1,
	Parent           = padFrame,
})

label({
	Text           = "VELTREX",
	Font           = Enum.Font.GothamBold,
	TextSize       = 10,
	TextColor3     = Theme.dim,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size           = UDim2.new(1, 0, 1, 0),
	Parent         = padHandle,
})

draggable(padFrame, padHandle, function(position)
	prefs.padPos = udim2To(position)
	savePrefs()
end)

local function padButton(item, index)
	local column = (index - 1) % PAD_COLS
	local rowIndex = math.floor((index - 1) / PAD_COLS)

	local btn = new("TextButton", {
		Size             = UDim2.new(0, PAD_BTN, 0, PAD_BTN),
		Position         = UDim2.new(0, 8 + column * (PAD_BTN + PAD_GAP), 0, 26 + rowIndex * (PAD_BTN + PAD_GAP)),
		BackgroundColor3 = Theme.row,
		BorderSizePixel  = 0,
		AutoButtonColor  = false,
		Text             = item.label,
		TextColor3       = Theme.sub,
		Font             = Enum.Font.GothamBold,
		TextSize         = 10,
		LineHeight       = 1.2,
		Parent           = padFrame,
	})
	corner(btn, 10)
	local btnStroke = stroke(btn, Theme.stroke, 1, 0.45)

	local function render(on)
		tween(btn, 0.15, {
			BackgroundColor3 = on and Theme.accent or Theme.row,
			TextColor3       = on and Color3.fromRGB(255, 255, 255) or Theme.sub,
		})
		tween(btnStroke, 0.15, { Transparency = on and 1 or 0.45 })
	end

	track(btn.MouseButton1Click:Connect(function()
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
	padButton(item, index)
end

--==============================================================================
-- Minimised pill
--==============================================================================

local pill = new("TextButton", {
	Name             = "Pill",
	Size             = UDim2.new(0, 92, 0, 32),
	Position         = udim2From(prefs.windowPos, UDim2.new(0, 40, 0.5, -16)),
	BackgroundColor3 = Theme.panel,
	BorderSizePixel  = 0,
	AutoButtonColor  = false,
	Text             = "",
	Visible          = false,
	Active           = true,
	Parent           = screenMain,
})
corner(pill, 10)
stroke(pill, Theme.stroke, 1, 0.25)

local pillDot = new("Frame", {
	Size             = UDim2.new(0, 8, 0, 8),
	Position         = UDim2.new(0, 12, 0.5, -4),
	BackgroundColor3 = Theme.accent,
	BorderSizePixel  = 0,
	Parent           = pill,
})
corner(pillDot, 4)
accented(pillDot, "BackgroundColor3")

label({
	Text     = "VELTREX",
	Font     = Enum.Font.GothamBold,
	TextSize = 11,
	Position = UDim2.new(0, 28, 0, 0),
	Size     = UDim2.new(1, -32, 1, 0),
	Parent   = pill,
})

draggable(pill, pill)

local windowVisible = true

local function setWindowVisible(visible)
	windowVisible = visible
	if visible then
		window.Visible = true
		pill.Visible = false
		window.Size = UDim2.new(0, WINDOW_W * 0.94, 0, WINDOW_H * 0.94)
		tween(window, 0.18, { Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H) }, Enum.EasingStyle.Back)
	else
		tween(window, 0.14, { Size = UDim2.new(0, WINDOW_W * 0.92, 0, WINDOW_H * 0.92) })
		task.delay(0.15, function()
			if not windowVisible then
				window.Visible = false
				window.Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H)
				pill.Position = window.Position
				pill.Visible = true
			end
		end)
	end
end

headerButton("-", -40, function() setWindowVisible(false) end)

-- Closing tears the whole hub down, so it asks once before doing it.
local closeArmed = false
headerButton("x", -70, function()
	if closeArmed then
		UI.unload()
		return
	end
	closeArmed = true
	UI.toast("Click x again to unload Veltrex", "warn")
	task.delay(3, function() closeArmed = false end)
end)

track(pill.MouseButton1Click:Connect(function() setWindowVisible(true) end))

Core.registerAction("toggleUI", "Toggle Menu", function()
	setWindowVisible(not windowVisible)
end)

--==============================================================================
-- Search
--==============================================================================

local function applySearch(query)
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

		local text = tab.button:FindFirstChildOfClass("TextLabel")
		if text then
			text.TextTransparency = (query ~= "" and matches == 0) and 0.65 or 0
		end
		tab.matches = matches
	end

	if query ~= "" and activeTab and activeTab.matches == 0 then
		for _, tab in ipairs(tabs) do
			if tab.matches > 0 then
				selectTab(tab)
				paintTabs()
				break
			end
		end
	end
end

track(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	applySearch(searchBox.Text)
end))

--==============================================================================
-- Layout reset / unload
--==============================================================================

function UI.resetLayout()
	prefs.windowPos = { xs = 0, xo = 40, ys = 0.5, yo = -WINDOW_H / 2 }
	prefs.hudPos    = { xs = 0.5, xo = -150, ys = 0, yo = 24 }
	prefs.padPos    = { xs = 1, xo = -150, ys = 0.5, yo = -190 }

	window.Position   = udim2From(prefs.windowPos)
	pill.Position     = udim2From(prefs.windowPos)
	hud.Position      = udim2From(prefs.hudPos)
	padFrame.Position = udim2From(prefs.padPos)

	savePrefs()
	UI.toast("Layout reset", "good")
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

local function profileText()
	return Core.speedProfileLabel()
end

task.spawn(function()
	while not Core.unloaded do
		local state = Core.state

		if statCards.FPS then
			statCards.FPS.Text     = tostring(Core.fps)
			statCards.PING.Text    = tostring(Core.ping) .. "ms"
			statCards.SPEED.Text   = string.format("%.0f", state.speed)
			statCards.PROFILE.Text = profileText()
		end

		if stealInfoLabel then
			stealInfoLabel.Text = tostring(#(Core.Steal.animals or {}))
		end

		hudTitle.Text = state.stealing and ("Stealing " .. tostring(state.stealLabel))
			or (state.aimTarget and ("Target " .. state.aimTarget))
			or profileText()

		hudStats.Text = string.format("%d FPS   %d ms   %.0f spd", Core.fps, Core.ping, state.speed)

		local activeCount = 0
		for _, def in ipairs(Core.features) do
			if Core.isOn(def.id) then activeCount = activeCount + 1 end
		end

		footerLeft.Text  = activeCount .. " feature" .. (activeCount == 1 and "" or "s") .. " active"
		footerRight.Text = string.format("%d fps   %d ms   %s", Core.fps, Core.ping, profileText())

		task.wait(0.25)
	end
end)

-- Animated accent sweep on the header logo.
task.spawn(function()
	local gradient = new("UIGradient", {
		Rotation = 0,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Theme.accent),
		}),
		Parent = logo,
	})
	while not Core.unloaded and gradient.Parent do
		gradient.Rotation = (gradient.Rotation + 2) % 360
		task.wait(0.04)
	end
end)

--==============================================================================
-- Boot
--==============================================================================

selectTab(tabs[1])
paintTabs()
applySearch("")

Core.on("feature", function(id, on)
	local def = Core.featureById[id]
	if def then
		UI.toast(def.label .. (on and " enabled" or " disabled"), on and "good" or "info")
	end
end)

UI.window = window
UI.hud    = hud
UI.pad    = padFrame
UI.Theme  = Theme

return UI
