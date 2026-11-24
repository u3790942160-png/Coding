-- @module touchui
-- Draggable on-screen action buttons. Size and shape come from settings;
-- positions persist per button id. Works with a finger or a mouse.
local Svc   = _R("svc")
local Cfg   = _R("cfg")
local Theme = _R("theme")
local Util  = _R("util")
local Notify= _R("notify")
local Binds = _R("binds")

local TB = {}

local UIS = Svc.UserInputService
local gui = nil
local buttons = {}     -- id -> {frame, label, glow, state}
local maid = Util.Maid.new()
local DRAG_SLOP = 6

-- id, caption, settings path to light the button from (or nil)
TB.layout = {
	{id = "direct",  caption = "DIR", lit = function() return Cfg.s.direct.enabled end},
	{id = "refresh", caption = "RD",  lit = function() return Cfg.s.stock.autoRefresh end},
	{id = "buytop",  caption = "BUY", lit = function() return false end},
	{id = "auto",    caption = "AUT", lit = function() return Cfg.s.auto.enabled end},
	{id = "open",    caption = "OPN", lit = function() return Cfg.s.stock.autoOpen end},
	{id = "hop",     caption = "HOP", lit = function() return Cfg.s.island.hopUntilFound end},
	{id = "menu",    caption = "MS",  lit = function() return true end},
}

local function shapeButton(frame, size, shape)
	for _, c in ipairs(frame:GetChildren()) do
		if c.Name == "ShapeBit" then c:Destroy() end
	end
	local corner = frame:FindFirstChildOfClass("UICorner")
	if not corner then corner = Theme.Corner(frame, 6) end

	if shape == 2 then
		corner.CornerRadius = UDim.new(0, math.floor(size / 2))
	elseif shape == 3 then
		corner.CornerRadius = UDim.new(0, 6)
	else
		-- shield: rounded top, pointed bottom from a rotated square behind
		corner.CornerRadius = UDim.new(0, math.floor(size * 0.32))
		local point = Instance.new("Frame")
		point.Name = "ShapeBit"
		point.BackgroundColor3 = frame.BackgroundColor3
		point.BackgroundTransparency = frame.BackgroundTransparency
		point.BorderSizePixel = 0
		point.AnchorPoint = Vector2.new(0.5, 0.5)
		point.Position = UDim2.new(0.5, 0, 1, -math.floor(size * 0.18))
		point.Size = UDim2.fromOffset(math.floor(size * 0.66), math.floor(size * 0.66))
		point.Rotation = 45
		point.ZIndex = frame.ZIndex - 1
		point.Parent = frame
		Theme.Corner(point, 4)
	end
end

local function defaultPosition(index)
	local vp = Svc.ViewportSize()
	local size = Cfg.s.settings.touchSize
	local gap = 8
	local perColumn = math.max(math.floor((vp.Y - 160) / (size + gap)), 1)
	local col = math.floor((index - 1) / perColumn)
	local rowIndex = (index - 1) % perColumn
	local x = vp.X - (size + gap) * (col + 1) - 8
	local y = 90 + rowIndex * (size + gap)
	return x, y
end

local function makeButton(def, index)
	local size = Cfg.s.settings.touchSize
	local frame = Instance.new("TextButton")
	frame.Name = "TB_" .. def.id
	frame.AutoButtonColor = false
	frame.Text = ""
	frame.BackgroundColor3 = Theme.col.bg1
	frame.BackgroundTransparency = Cfg.s.settings.touchAlpha
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromOffset(size, size)
	frame.ZIndex = 5
	frame.Parent = gui

	local saved = Cfg.s.settings.touchPos[def.id]
	local x, y
	if type(saved) == "table" and saved.x and saved.y then
		x, y = saved.x, saved.y
	else
		x, y = defaultPosition(index)
	end
	local vp = Svc.ViewportSize()
	x = Util.Clamp(x, 0, math.max(vp.X - size, 0))
	y = Util.Clamp(y, 0, math.max(vp.Y - size, 0))
	frame.Position = UDim2.fromOffset(x, y)

	local stroke = Theme.Stroke(frame, Theme.col.accentLo, 1)
	shapeButton(frame, size, Cfg.s.settings.touchShape)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Theme.font.title
	label.TextSize = math.max(12, math.floor(size * 0.30))
	label.TextColor3 = Theme.col.text
	label.Size = UDim2.fromScale(1, 1)
	label.ZIndex = 7
	label.Text = def.caption
	label.Parent = frame

	local entry = {frame = frame, label = label, stroke = stroke, def = def}
	buttons[def.id] = entry

	-- drag with press-through: a short press fires, a long move drags.
	local dragging, moved, startPos, startInput = false, false, nil, nil

	frame.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then return end
		dragging = true
		moved = false
		startInput = input
		startPos = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
		local origin = Vector2.new(input.Position.X, input.Position.Y)
		entry.origin = origin
	end)

	frame.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if dragging and not moved then
			Binds.Fire(def.id)
			TB.Repaint()
		end
		if dragging and moved then
			Cfg.s.settings.touchPos[def.id] = {
				x = frame.Position.X.Offset,
				y = frame.Position.Y.Offset,
			}
		end
		dragging = false
		moved = false
	end)

	maid:Give(UIS.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if startInput and input.UserInputType == Enum.UserInputType.Touch and input ~= startInput then return end
		local now = Vector2.new(input.Position.X, input.Position.Y)
		local delta = now - entry.origin
		if delta.Magnitude > DRAG_SLOP then moved = true end
		if not moved then return end
		local vpz = Svc.ViewportSize()
		local nx = Util.Clamp(startPos.X + delta.X, 0, math.max(vpz.X - frame.AbsoluteSize.X, 0))
		local ny = Util.Clamp(startPos.Y + delta.Y, 0, math.max(vpz.Y - frame.AbsoluteSize.Y, 0))
		frame.Position = UDim2.fromOffset(nx, ny)
	end))

	return entry
end

function TB.Repaint()
	for _, entry in pairs(buttons) do
		local on = false
		local ok, v = pcall(entry.def.lit)
		if ok then on = v and true or false end
		entry.stroke.Color = on and Theme.col.accentHi or Theme.col.accentLo
		entry.label.TextColor3 = on and Theme.col.accentHi or Theme.col.textDim
		entry.frame.BackgroundColor3 = on and Theme.col.bg3 or Theme.col.bg1
		local bit = entry.frame:FindFirstChild("ShapeBit")
		if bit then bit.BackgroundColor3 = entry.frame.BackgroundColor3 end
	end
end

function TB.Rebuild()
	TB.Destroy()
	if not Cfg.s.settings.touchButtons then return end

	gui = Instance.new("ScreenGui")
	gui.Name = "LC_Touch"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 998
	gui.Parent = Notify.GuiParent()
	maid:Give(gui)

	for i, def in ipairs(TB.layout) do
		makeButton(def, i)
	end
	TB.Repaint()
end

function TB.Destroy()
	maid:Clean()
	buttons = {}
	gui = nil
end

-- Live button count, used by the headless rig and by nothing else.
function TB.Count()
	local n = 0
	for _ in pairs(buttons) do n = n + 1 end
	return n
end

function TB.Visible(state)
	if gui then gui.Enabled = state end
end

return TB
