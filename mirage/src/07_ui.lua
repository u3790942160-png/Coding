-- @module ui
-- Retained-mode widget library in the Lord's Court style. Touch and mouse
-- share every path; nothing is keyboard-only.
local Svc   = _R("svc")
local Theme = _R("theme")
local Util  = _R("util")
local Notify= _R("notify")
local Env   = _R("env")
local Cfg   = _R("cfg")

local UI = {}

local UIS = Svc.UserInputService

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

local function hoverTint(frame, base, lit)
	frame.MouseEnter:Connect(function() frame.BackgroundColor3 = lit end)
	frame.MouseLeave:Connect(function() frame.BackgroundColor3 = base end)
end

-- ── Window ───────────────────────────────────────────────────────────
local Window = {}
Window.__index = Window

function UI.Window(opts)
	local self = setmetatable({}, Window)
	self.maid = Util.Maid.new()
	self.refreshers = {}
	self.tabs = {}
	self.activeTab = nil

	local gui = Instance.new("ScreenGui")
	gui.Name = "LC_Main"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 1000
	gui.Parent = Notify.GuiParent()
	if Env.protectgui then pcall(Env.protectgui, gui) end
	self.Gui = gui
	self.maid:Give(gui)

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = gui
	self.scale = scale

	local size = Theme.WindowSize()
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = size
	root.BackgroundColor3 = Theme.col.bg0
	root.BorderSizePixel = 0
	root.Active = true
	root.Parent = gui
	self.Root = root
	Theme.Corner(root, 8)
	Theme.Stroke(root, Theme.col.stroke, 1)
	Theme.PanelGradient(root)

	-- header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundColor3 = Theme.col.bg1
	header.BorderSizePixel = 0
	header.Size = UDim2.new(1, 0, 0, Theme.metric.headerH)
	header.Parent = root
	Theme.Corner(header, 8)
	self.Header = header

	local headerFill = Instance.new("Frame")
	headerFill.BackgroundColor3 = Theme.col.bg1
	headerFill.BorderSizePixel = 0
	headerFill.Position = UDim2.new(0, 0, 1, -8)
	headerFill.Size = UDim2.new(1, 0, 0, 8)
	headerFill.Parent = header

	local crown = Theme.Sigil(header, 18)
	crown.Position = UDim2.new(0, 12, 0.5, -9)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Theme.font.title
	title.TextSize = Theme.TextSize("title")
	title.TextColor3 = Theme.col.accentHi
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = opts.title or "olliE"
	title.Position = UDim2.new(0, 48, 0, 4)
	title.Size = UDim2.new(1, -140, 0, 24)
	title.Parent = header
	Theme.AccentGradient(title, 90)

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Font = Theme.font.body
	sub.TextSize = Theme.TextSize("small")
	sub.TextColor3 = Theme.col.textDim
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Text = opts.subtitle or ""
	sub.Position = UDim2.new(0, 48, 0, 25)
	sub.Size = UDim2.new(1, -140, 0, 16)
	sub.Parent = header
	self.Subtitle = sub

	local function headerButton(text, offsetX, color, cb)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.BackgroundColor3 = Theme.col.bg2
		b.BorderSizePixel = 0
		b.Font = Theme.font.body
		b.TextSize = Theme.TextSize("body")
		b.TextColor3 = color
		b.Text = text
		b.Size = UDim2.fromOffset(28, 28)
		b.Position = UDim2.new(1, offsetX, 0.5, -14)
		b.Parent = header
		Theme.Corner(b, 5)
		Theme.Stroke(b, Theme.col.strokeLo, 1)
		hoverTint(b, Theme.col.bg2, Theme.col.bg3)
		b.MouseButton1Click:Connect(cb)
		return b
	end

	headerButton("-", -74, Theme.col.text, function() self:SetMinimised(not self.minimised) end)
	headerButton("x", -40, Theme.col.bad, function() self:SetVisible(false) end)

	local divider = Theme.Divider(root, 0.96)
	divider.Position = UDim2.new(0, 0, 0, Theme.metric.headerH)

	-- tab strip
	local strip = Instance.new("ScrollingFrame")
	strip.Name = "Tabs"
	strip.BackgroundColor3 = Theme.col.bg1
	strip.BackgroundTransparency = 0.35
	strip.BorderSizePixel = 0
	strip.Position = UDim2.new(0, 6, 0, Theme.metric.headerH + 10)
	strip.Size = UDim2.new(1, -12, 0, Theme.metric.tabH + 6)
	strip.ScrollBarThickness = 2
	strip.ScrollBarImageColor3 = Theme.col.accentLo
	strip.ScrollingDirection = Enum.ScrollingDirection.X
	strip.CanvasSize = UDim2.new(0, 0, 0, 0)
	strip.AutomaticCanvasSize = Enum.AutomaticSize.X
	strip.ElasticBehavior = Enum.ElasticBehavior.Never
	strip.Parent = root
	Theme.Corner(strip, 5)
	self.Strip = strip

	local stripList = Instance.new("UIListLayout")
	stripList.FillDirection = Enum.FillDirection.Horizontal
	stripList.Padding = UDim.new(0, 4)
	stripList.SortOrder = Enum.SortOrder.LayoutOrder
	stripList.VerticalAlignment = Enum.VerticalAlignment.Center
	stripList.Parent = strip

	local stripPad = Instance.new("UIPadding")
	stripPad.PaddingLeft = UDim.new(0, 4)
	stripPad.PaddingRight = UDim.new(0, 4)
	stripPad.Parent = strip

	-- body
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.new(0, 6, 0, Theme.metric.headerH + Theme.metric.tabH + 20)
	body.Size = UDim2.new(1, -12, 1, -(Theme.metric.headerH + Theme.metric.tabH + 28))
	body.Parent = root
	self.Body = body

	-- status line
	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Font = Theme.font.mono
	status.TextSize = Theme.TextSize("small")
	status.TextColor3 = Theme.col.textDim
	status.TextXAlignment = Enum.TextXAlignment.Right
	status.Text = ""
	status.AnchorPoint = Vector2.new(1, 1)
	status.Position = UDim2.new(1, -10, 1, -2)
	status.Size = UDim2.new(0.8, 0, 0, 14)
	status.Parent = root
	self.Status = status

	self:MakeDraggable(header)
	self:MakeDraggable(title)
	self.minimised = false
	self.fullSize = size

	return self
end

function Window:MakeDraggable(handle)
	local root = self.Root
	local dragging, dragInput, startPos, startMouse = false, nil, nil, nil
	handle.Active = true

	handle.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		dragging = true
		startPos = root.Position
		startMouse = input.Position
		dragInput = input
		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				if conn then conn:Disconnect() end
			end
		end)
	end)

	UIS.InputChanged:Connect(function(input)
		if not dragging or not isMove(input) then return end
		if dragInput and input.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then return end
		local delta = input.Position - startMouse
		root.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end)
end

function Window:SetMinimised(state)
	self.minimised = state
	if state then
		self.Root.Size = UDim2.new(self.fullSize.X.Scale, self.fullSize.X.Offset, 0, Theme.metric.headerH)
		self.Strip.Visible = false
		self.Body.Visible = false
		self.Status.Visible = false
	else
		self.Root.Size = self.fullSize
		self.Strip.Visible = true
		self.Body.Visible = true
		self.Status.Visible = true
	end
end

function Window:SetVisible(state)
	self.Gui.Enabled = state
end

function Window:Visible()
	return self.Gui.Enabled
end

function Window:ToggleVisible()
	self.Gui.Enabled = not self.Gui.Enabled
end

function Window:SetScale(s)
	self.scale.Scale = Util.Clamp(s, 0.6, 1.6)
end

function Window:SetStatus(text)
	self.Status.Text = text
end

function Window:Refresh()
	for _, fn in ipairs(self.refreshers) do
		pcall(fn)
	end
end

function Window:Destroy()
	self.maid:Clean()
end

-- ── Tab ──────────────────────────────────────────────────────────────
local Tab = {}
Tab.__index = Tab

function Window:Tab(name)
	local self_ = self
	local tab = setmetatable({}, Tab)
	tab.window = self
	tab.name = name

	local btn = Instance.new("TextButton")
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = Theme.col.bg2
	btn.BorderSizePixel = 0
	btn.Font = Theme.font.title
	btn.TextSize = Theme.TextSize("tab")
	btn.TextColor3 = Theme.col.textDim
	btn.Text = name
	btn.AutomaticSize = Enum.AutomaticSize.X
	btn.Size = UDim2.new(0, 0, 0, Theme.metric.tabH)
	btn.LayoutOrder = #self.tabs + 1
	btn.Parent = self.Strip
	Theme.Corner(btn, 4)
	local bstroke = Theme.Stroke(btn, Theme.col.strokeLo, 1)

	local bpad = Instance.new("UIPadding")
	bpad.PaddingLeft = UDim.new(0, 12)
	bpad.PaddingRight = UDim.new(0, 12)
	bpad.Parent = btn

	local page = Instance.new("ScrollingFrame")
	page.Name = name
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.Size = UDim2.fromScale(1, 1)
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = Theme.col.accentLo
	page.ScrollingDirection = Enum.ScrollingDirection.Y
	page.Visible = false
	page.Parent = self.Body

	local pageList = Instance.new("UIListLayout")
	pageList.Padding = UDim.new(0, 8)
	pageList.SortOrder = Enum.SortOrder.LayoutOrder
	pageList.Parent = page

	local pagePad = Instance.new("UIPadding")
	pagePad.PaddingTop = UDim.new(0, 2)
	pagePad.PaddingBottom = UDim.new(0, 10)
	pagePad.PaddingRight = UDim.new(0, 6)
	pagePad.Parent = page

	tab.button = btn
	tab.page = page
	tab.stroke = bstroke

	btn.MouseButton1Click:Connect(function()
		self_:Select(name)
	end)

	self.tabs[#self.tabs + 1] = tab
	if not self.activeTab then self:Select(name) end
	return tab
end

function Window:Select(name)
	for _, t in ipairs(self.tabs) do
		local on = (t.name == name)
		t.page.Visible = on
		t.button.TextColor3 = on and Theme.col.accentHi or Theme.col.textDim
		t.button.BackgroundColor3 = on and Theme.col.bg3 or Theme.col.bg2
		t.stroke.Color = on and Theme.col.accent or Theme.col.strokeLo
		if on then self.activeTab = t end
	end
end

-- ── Section ──────────────────────────────────────────────────────────
local Section = {}
Section.__index = Section

function Tab:Section(title)
	local sec = setmetatable({}, Section)
	sec.window = self.window

	local card = Instance.new("Frame")
	card.BackgroundColor3 = Theme.col.bg1
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1, 0, 0, 40)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.LayoutOrder = #self.page:GetChildren()
	card.Parent = self.page
	Theme.Corner(card, 6)
	Theme.Stroke(card, Theme.col.strokeLo, 1)

	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.new(1, 0, 0, 0)
	inner.AutomaticSize = Enum.AutomaticSize.Y
	inner.Parent = card
	Theme.Pad(inner, 10, 10, 8, 10)

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 5)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = inner

	local head = Instance.new("TextLabel")
	head.BackgroundTransparency = 1
	head.Font = Theme.font.title
	head.TextSize = Theme.TextSize("body")
	head.TextColor3 = Theme.col.accent
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.Text = title
	head.Size = UDim2.new(1, 0, 0, 20)
	head.LayoutOrder = 0
	head.Parent = inner

	local rule = Instance.new("Frame")
	rule.BackgroundColor3 = Theme.col.accentLo
	rule.BorderSizePixel = 0
	rule.Size = UDim2.new(1, 0, 0, 1)
	rule.LayoutOrder = 1
	rule.Parent = inner
	Theme.AccentGradient(rule, 0)

	sec.frame = inner
	sec.order = 2
	return sec
end

function Section:next()
	self.order = self.order + 1
	return self.order
end

local function baseRow(sec, height)
	local row = Instance.new("Frame")
	row.BackgroundColor3 = Theme.col.bg2
	row.BackgroundTransparency = 0.25
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, height or Theme.RowHeight())
	row.LayoutOrder = sec:next()
	row.Parent = sec.frame
	Theme.Corner(row, 5)
	return row
end

local function rowLabel(row, text, widthOffset)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Theme.font.body
	l.TextSize = Theme.TextSize("body")
	l.TextColor3 = Theme.col.text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = text
	l.Position = UDim2.new(0, 10, 0, 0)
	l.Size = UDim2.new(1, widthOffset or -70, 1, 0)
	l.Parent = row
	return l
end

-- ── Label ────────────────────────────────────────────────────────────
function Section:Label(text, tone)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Theme.font.body
	l.TextSize = Theme.TextSize("small")
	l.TextColor3 = tone == "dim" and Theme.col.textDim or Theme.col.text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text
	l.Size = UDim2.new(1, 0, 0, 16)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.LayoutOrder = self:next()
	l.Parent = self.frame
	return {
		Set = function(_, t) l.Text = t end,
		SetColor = function(_, c) l.TextColor3 = c end,
		instance = l,
	}
end

-- ── Toggle ───────────────────────────────────────────────────────────
function Section:Toggle(o)
	local row = baseRow(self, nil)
	rowLabel(row, o.text, -76)

	local track = Instance.new("TextButton")
	track.AutoButtonColor = false
	track.Text = ""
	track.BackgroundColor3 = Theme.col.bg0
	track.BorderSizePixel = 0
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, -10, 0.5, 0)
	track.Size = UDim2.fromOffset(46, 22)
	track.Parent = row
	Theme.Corner(track, 11)
	local tstroke = Theme.Stroke(track, Theme.col.strokeLo, 1)

	local knob = Instance.new("Frame")
	knob.BackgroundColor3 = Theme.col.textDim
	knob.BorderSizePixel = 0
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Position = UDim2.new(0, 3, 0.5, 0)
	knob.Size = UDim2.fromOffset(16, 16)
	knob.Parent = track
	Theme.Corner(knob, 8)

	local function paint(state)
		local goal = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		Svc.TweenService:Create(knob, TweenInfo.new(0.12), {
			Position = goal,
			BackgroundColor3 = state and Theme.col.accentHi or Theme.col.textDim,
		}):Play()
		tstroke.Color = state and Theme.col.accent or Theme.col.strokeLo
		track.BackgroundColor3 = state and Theme.col.bg3 or Theme.col.bg0
	end

	local function refresh()
		paint(o.get() and true or false)
	end

	track.MouseButton1Click:Connect(function()
		local nv = not o.get()
		o.set(nv)
		paint(nv)
	end)

	refresh()
	table.insert(self.window.refreshers, refresh)
	return {Refresh = refresh, Set = function(_, v) o.set(v) paint(v) end}
end

-- ── Slider ───────────────────────────────────────────────────────────
function Section:Slider(o)
	local height = Theme.SliderHeight()
	local row = baseRow(self, height)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Theme.font.body
	label.TextSize = Theme.TextSize("body")
	label.TextColor3 = Theme.col.text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = o.text
	label.Position = UDim2.new(0, 10, 0, 4)
	label.Size = UDim2.new(1, -90, 0, 18)
	label.Parent = row

	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Font = Theme.font.mono
	value.TextSize = Theme.TextSize("small")
	value.TextColor3 = Theme.col.accentHi
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.new(1, -10, 0, 5)
	value.Size = UDim2.fromOffset(78, 16)
	value.Parent = row

	local track = Instance.new("Frame")
	track.BackgroundColor3 = Theme.col.bg0
	track.BorderSizePixel = 0
	track.AnchorPoint = Vector2.new(0, 1)
	track.Position = UDim2.new(0, 10, 1, -10)
	track.Size = UDim2.new(1, -20, 0, 6)
	track.Parent = row
	Theme.Corner(track, 3)
	Theme.Stroke(track, Theme.col.strokeLo, 1)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Theme.col.accent
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	Theme.Corner(fill, 3)
	Theme.AccentGradient(fill, 0)

	local knob = Instance.new("Frame")
	knob.BackgroundColor3 = Theme.col.accentHi
	knob.BorderSizePixel = 0
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0, 0.5)
	knob.Size = UDim2.fromOffset(Svc.IsMobile() and 20 or 14, Svc.IsMobile() and 20 or 14)
	knob.ZIndex = 3
	knob.Parent = track
	Theme.Corner(knob, 10)
	Theme.Stroke(knob, Theme.col.accentLo, 1)

	-- Fat invisible hit area so a thumb can grab the 6px track.
	local hit = Instance.new("TextButton")
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.AnchorPoint = Vector2.new(0.5, 0.5)
	hit.Position = UDim2.fromScale(0.5, 0.5)
	hit.Size = UDim2.new(1, 24, 0, 34)
	hit.ZIndex = 4
	hit.Parent = track

	local minV, maxV = o.min, o.max
	local step = o.step or 1
	local suffix = o.suffix or ""

	local function quantise(v)
		local snapped = math.floor((v - minV) / step + 0.5) * step + minV
		return Util.Clamp(snapped, minV, maxV)
	end

	local function format(v)
		if step < 1 then return string.format("%.2f%s", v, suffix) end
		return string.format("%d%s", math.floor(v + 0.5), suffix)
	end

	local function paint(v)
		local alpha = 0
		if maxV > minV then alpha = (v - minV) / (maxV - minV) end
		alpha = Util.Clamp(alpha, 0, 1)
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		value.Text = format(v)
	end

	local function refresh() paint(o.get()) end

	local dragging = false
	local function applyFromX(x)
		local left = track.AbsolutePosition.X
		local width = math.max(track.AbsoluteSize.X, 1)
		local alpha = Util.Clamp((x - left) / width, 0, 1)
		local v = quantise(minV + alpha * (maxV - minV))
		o.set(v)
		paint(v)
	end

	hit.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		dragging = true
		applyFromX(input.Position.X)
	end)
	hit.InputEnded:Connect(function(input)
		if isPress(input) then dragging = false end
	end)
	UIS.InputChanged:Connect(function(input)
		if dragging and isMove(input) then applyFromX(input.Position.X) end
	end)
	UIS.InputEnded:Connect(function(input)
		if isPress(input) then dragging = false end
	end)

	refresh()
	table.insert(self.window.refreshers, refresh)
	return {Refresh = refresh}
end

-- ── Dropdown (inline expansion, no overlay) ──────────────────────────
function Section:Dropdown(o)
	local row = baseRow(self, nil)
	rowLabel(row, o.text, -150)

	local btn = Instance.new("TextButton")
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = Theme.col.bg0
	btn.BorderSizePixel = 0
	btn.Font = Theme.font.body
	btn.TextSize = Theme.TextSize("small")
	btn.TextColor3 = Theme.col.accentHi
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, -10, 0.5, 0)
	btn.Size = UDim2.fromOffset(136, Theme.RowHeight() - 12)
	btn.Text = "..."
	btn.Parent = row
	Theme.Corner(btn, 4)
	Theme.Stroke(btn, Theme.col.strokeLo, 1)

	local panel = Instance.new("Frame")
	panel.BackgroundColor3 = Theme.col.bg0
	panel.BorderSizePixel = 0
	panel.Size = UDim2.new(1, 0, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Visible = false
	panel.LayoutOrder = self:next()
	panel.Parent = self.frame
	Theme.Corner(panel, 5)
	Theme.Stroke(panel, Theme.col.strokeLo, 1)

	local plist = Instance.new("UIListLayout")
	plist.Padding = UDim.new(0, 2)
	plist.SortOrder = Enum.SortOrder.LayoutOrder
	plist.Parent = panel
	Theme.Pad(panel, 4, 4, 4, 4)

	local optionButtons = {}

	local function labelFor(v)
		for i, name in ipairs(o.options) do
			if i == v or name == v then return name end
		end
		return tostring(v)
	end

	local function refresh()
		local cur = o.get()
		btn.Text = labelFor(cur)
		for i, b in ipairs(optionButtons) do
			local on = (o.byIndex and i == cur) or (not o.byIndex and o.options[i] == cur)
			b.TextColor3 = on and Theme.col.accentHi or Theme.col.textDim
			b.BackgroundColor3 = on and Theme.col.bg3 or Theme.col.bg1
		end
	end

	for i, name in ipairs(o.options) do
		local ob = Instance.new("TextButton")
		ob.AutoButtonColor = false
		ob.BackgroundColor3 = Theme.col.bg1
		ob.BorderSizePixel = 0
		ob.Font = Theme.font.body
		ob.TextSize = Theme.TextSize("small")
		ob.TextColor3 = Theme.col.textDim
		ob.Text = name
		ob.Size = UDim2.new(1, 0, 0, Svc.IsMobile() and 34 or 26)
		ob.LayoutOrder = i
		ob.Parent = panel
		Theme.Corner(ob, 4)
		optionButtons[i] = ob
		ob.MouseButton1Click:Connect(function()
			if o.byIndex then o.set(i) else o.set(name) end
			panel.Visible = false
			refresh()
		end)
	end

	btn.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
	end)

	refresh()
	table.insert(self.window.refreshers, refresh)
	return {Refresh = refresh}
end

-- ── Button ───────────────────────────────────────────────────────────
function Section:Button(o)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = Theme.col.bg3
	b.BorderSizePixel = 0
	b.Font = Theme.font.title
	b.TextSize = Theme.TextSize("body")
	b.TextColor3 = o.tone == "bad" and Theme.col.bad or Theme.col.accentHi
	b.Text = o.text
	b.Size = UDim2.new(1, 0, 0, Theme.RowHeight())
	b.LayoutOrder = self:next()
	b.Parent = self.frame
	Theme.Corner(b, 5)
	Theme.Stroke(b, o.tone == "bad" and Theme.col.bad or Theme.col.accentLo, 1)
	hoverTint(b, Theme.col.bg3, Theme.col.bg2)
	b.MouseButton1Click:Connect(function()
		local ok, err = pcall(o.callback)
		if not ok then Notify.Bad("fault", tostring(err)) end
	end)
	return {instance = b, SetText = function(_, t) b.Text = t end}
end

-- ── TextBox ──────────────────────────────────────────────────────────
function Section:TextBox(o)
	local row = baseRow(self, nil)
	rowLabel(row, o.text, -170)

	local box = Instance.new("TextBox")
	box.BackgroundColor3 = Theme.col.bg0
	box.BorderSizePixel = 0
	box.Font = Theme.font.mono
	box.TextSize = Theme.TextSize("small")
	box.TextColor3 = Theme.col.text
	box.PlaceholderText = o.placeholder or ""
	box.PlaceholderColor3 = Theme.col.textDim
	box.ClearTextOnFocus = false
	box.AnchorPoint = Vector2.new(1, 0.5)
	box.Position = UDim2.new(1, -10, 0.5, 0)
	box.Size = UDim2.fromOffset(156, Theme.RowHeight() - 12)
	box.Text = ""
	box.Parent = row
	Theme.Corner(box, 4)
	Theme.Stroke(box, Theme.col.strokeLo, 1)

	local function refresh() box.Text = tostring(o.get()) end

	box.FocusLost:Connect(function()
		o.set(box.Text)
		refresh()
	end)

	refresh()
	table.insert(self.window.refreshers, refresh)
	return {Refresh = refresh}
end

-- ── Keybind (keyboard + gamepad in one row) ──────────────────────────
local padNames = {
	"ButtonA", "ButtonB", "ButtonX", "ButtonY",
	"ButtonL1", "ButtonR1", "ButtonL2", "ButtonR2",
	"ButtonL3", "ButtonR3", "ButtonSelect", "ButtonStart",
	"DPadUp", "DPadDown", "DPadLeft", "DPadRight",
}
UI.PadNames = padNames

function Section:Keybind(o)
	local row = baseRow(self, nil)
	rowLabel(row, o.text, -170)

	local function mkBtn(xOffset, width)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.BackgroundColor3 = Theme.col.bg0
		b.BorderSizePixel = 0
		b.Font = Theme.font.mono
		b.TextSize = Theme.TextSize("small")
		b.TextColor3 = Theme.col.accentHi
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, xOffset, 0.5, 0)
		b.Size = UDim2.fromOffset(width, Theme.RowHeight() - 12)
		b.Text = "-"
		b.Parent = row
		Theme.Corner(b, 4)
		Theme.Stroke(b, Theme.col.strokeLo, 1)
		return b
	end

	local keyBtn = mkBtn(-92, 72)
	local padBtn = mkBtn(-10, 78)

	local function refresh()
		local k, p = o.get()
		keyBtn.Text = (k ~= nil and k ~= "") and k or "-"
		padBtn.Text = (p ~= nil and p ~= "") and p or "-"
	end

	local listening = false
	keyBtn.MouseButton1Click:Connect(function()
		if listening then return end
		listening = true
		keyBtn.Text = "..."
		local conn
		conn = UIS.InputBegan:Connect(function(input, gpe)
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			conn:Disconnect()
			listening = false
			local name = input.KeyCode.Name
			if name == "Backspace" or name == "Escape" then name = "" end
			o.set(name, nil)
			refresh()
		end)
	end)

	local padIndex = 0
	padBtn.MouseButton1Click:Connect(function()
		-- Cycling is the only reliable way to set a pad bind on a phone.
		padIndex = padIndex + 1
		if padIndex > #padNames then
			padIndex = 0
			o.set(nil, "")
		else
			o.set(nil, padNames[padIndex])
		end
		refresh()
	end)

	refresh()
	table.insert(self.window.refreshers, refresh)
	return {Refresh = refresh}
end

-- ── Dynamic sections ─────────────────────────────────────────────────
-- Drops every widget added after the heading and rule, so a list can be
-- rebuilt in place without rebuilding the window.
function Section:Clear()
	for _, child in ipairs(self.frame:GetChildren()) do
		if child:IsA("GuiObject") and child.LayoutOrder >= 2 then
			child:Destroy()
		end
	end
	self.order = 2
end

-- A row carrying a label, a right aligned value, and one action button.
-- This is what a stock line is.
function Section:ActionRow(o)
	local row = baseRow(self, nil)

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Font = Theme.font.body
	name.TextSize = Theme.TextSize("body")
	name.TextColor3 = o.tone == "watched" and Theme.col.accentHi or Theme.col.text
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = o.text
	name.Position = UDim2.new(0, 10, 0, 0)
	name.Size = UDim2.new(1, -190, 1, 0)
	name.Parent = row

	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Font = Theme.font.mono
	value.TextSize = Theme.TextSize("small")
	value.TextColor3 = Theme.col.textDim
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextTruncate = Enum.TextTruncate.AtEnd
	value.Text = o.value or ""
	value.AnchorPoint = Vector2.new(1, 0.5)
	value.Position = UDim2.new(1, -96, 0.5, 0)
	value.Size = UDim2.fromOffset(150, Theme.RowHeight() - 10)
	value.Parent = row

	local btn = Instance.new("TextButton")
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = Theme.col.bg3
	btn.BorderSizePixel = 0
	btn.Font = Theme.font.body
	btn.TextSize = Theme.TextSize("small")
	btn.TextColor3 = Theme.col.accentHi
	btn.Text = o.button or "BUY"
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, -8, 0.5, 0)
	btn.Size = UDim2.fromOffset(82, Theme.RowHeight() - 10)
	btn.Parent = row
	Theme.Corner(btn, 4)
	Theme.Stroke(btn, Theme.col.accentLo, 1)
	hoverTint(btn, Theme.col.bg3, Theme.col.bg2)
	btn.MouseButton1Click:Connect(function()
		local ok, err = pcall(o.callback)
		if not ok then Notify.Bad("fault", tostring(err)) end
	end)

	-- a second, optional button on the left of the first
	local alt = nil
	if o.altButton then
		alt = Instance.new("TextButton")
		alt.AutoButtonColor = false
		alt.BackgroundColor3 = Theme.col.bg2
		alt.BorderSizePixel = 0
		alt.Font = Theme.font.body
		alt.TextSize = Theme.TextSize("small")
		alt.TextColor3 = o.altOn and Theme.col.accentHi or Theme.col.textDim
		alt.Text = o.altButton
		alt.AnchorPoint = Vector2.new(1, 0.5)
		alt.Position = UDim2.new(1, -94, 0.5, 0)
		alt.Size = UDim2.fromOffset(36, Theme.RowHeight() - 10)
		alt.Parent = row
		Theme.Corner(alt, 4)
		Theme.Stroke(alt, o.altOn and Theme.col.accent or Theme.col.strokeLo, 1)
		alt.MouseButton1Click:Connect(function()
			local ok, err = pcall(o.altCallback)
			if not ok then Notify.Bad("fault", tostring(err)) end
		end)
		value.Position = UDim2.new(1, -134, 0.5, 0)
		value.Size = UDim2.fromOffset(120, Theme.RowHeight() - 10)
		name.Size = UDim2.new(1, -266, 1, 0)
	end

	return {
		row = row,
		SetValue = function(_, text) value.Text = text end,
		SetTone = function(_, c) name.TextColor3 = c end,
	}
end

-- ── Read-only value row, driven by a poller ──────────────────────────
function Section:Readout(o)
	local row = baseRow(self, nil)
	rowLabel(row, o.text, -170)

	local v = Instance.new("TextLabel")
	v.BackgroundTransparency = 1
	v.Font = Theme.font.mono
	v.TextSize = Theme.TextSize("small")
	v.TextColor3 = Theme.col.textDim
	v.TextXAlignment = Enum.TextXAlignment.Right
	v.TextTruncate = Enum.TextTruncate.AtEnd
	v.AnchorPoint = Vector2.new(1, 0.5)
	v.Position = UDim2.new(1, -10, 0.5, 0)
	v.Size = UDim2.fromOffset(170, Theme.RowHeight() - 10)
	v.Text = "-"
	v.Parent = row

	return {
		Set = function(_, text, tone)
			v.Text = tostring(text)
			if tone == "good" then v.TextColor3 = Theme.col.good
			elseif tone == "bad" then v.TextColor3 = Theme.col.bad
			elseif tone == "accent" then v.TextColor3 = Theme.col.accentHi
			else v.TextColor3 = Theme.col.textDim end
		end,
	}
end

UI.Section = Section
UI.Tab = Tab
UI.WindowClass = Window

return UI
