-- @module theme
-- Mirage palette: night indigo, sand, and the teal of the island showing
-- through the fog. Ornaments are frames, not glyphs, so nothing depends on
-- a font carrying the codepoint.
local Svc = _R("svc")

local T = {}

local function c3(r, g, b) return Color3.fromRGB(r, g, b) end

T.col = {
	bg0      = c3(9, 11, 19),
	bg1      = c3(17, 21, 33),
	bg2      = c3(25, 31, 47),
	bg3      = c3(35, 44, 64),
	stroke   = c3(58, 92, 104),
	strokeLo = c3(33, 47, 61),
	accent   = c3(222, 190, 132),
	accentHi = c3(249, 228, 178),
	accentLo = c3(138, 114, 70),
	teal     = c3(86, 196, 190),
	tealHi   = c3(152, 232, 224),
	text     = c3(231, 234, 241),
	textDim  = c3(138, 149, 166),
	good     = c3(104, 196, 140),
	bad      = c3(206, 86, 86),
	warn     = c3(228, 172, 80),
}

T.font = {
	title = Enum.Font.GothamMedium,
	body  = Enum.Font.Gotham,
	mono  = Enum.Font.Code,
}

T.metric = {
	corner     = 6,
	pad        = 10,
	rowH       = 34,
	rowHMobile = 42,
	sliderH    = 46,
	sliderHMob = 56,
	tabH       = 34,
	headerH    = 46,
	stroke     = 1,
}

function T.RowHeight()
	if Svc.IsMobile() then return T.metric.rowHMobile end
	return T.metric.rowH
end

function T.SliderHeight()
	if Svc.IsMobile() then return T.metric.sliderHMob end
	return T.metric.sliderH
end

function T.TextSize(kind)
	local mob = Svc.IsMobile()
	if kind == "title" then return mob and 20 or 18 end
	if kind == "small" then return mob and 14 or 13 end
	if kind == "tab"   then return mob and 15 or 14 end
	return mob and 16 or 15
end

function T.WindowSize()
	local vp = Svc.ViewportSize()
	if Svc.IsMobile() then
		local w = math.min(vp.X * 0.94, 600)
		local h = math.min(vp.Y * 0.82, 540)
		return UDim2.fromOffset(math.floor(w), math.floor(h))
	end
	return UDim2.fromOffset(640, 450)
end

function T.Corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or T.metric.corner)
	c.Parent = parent
	return c
end

function T.Stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or T.col.strokeLo
	s.Thickness = thickness or T.metric.stroke
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function T.Pad(parent, l, r, t, b)
	local p = Instance.new("UIPadding")
	p.PaddingLeft   = UDim.new(0, l or T.metric.pad)
	p.PaddingRight  = UDim.new(0, r or l or T.metric.pad)
	p.PaddingTop    = UDim.new(0, t or T.metric.pad)
	p.PaddingBottom = UDim.new(0, b or t or T.metric.pad)
	p.Parent = parent
	return p
end

function T.List(parent, padding, dir)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding or 6)
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

function T.AccentGradient(parent, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, T.col.accentLo),
		ColorSequenceKeypoint.new(0.42, T.col.accentHi),
		ColorSequenceKeypoint.new(0.72, T.col.teal),
		ColorSequenceKeypoint.new(1.0, T.col.accentLo),
	})
	g.Rotation = rotation or 0
	g.Parent = parent
	return g
end

function T.PanelGradient(parent)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, T.col.bg2),
		ColorSequenceKeypoint.new(1, T.col.bg0),
	})
	g.Rotation = 90
	g.Parent = parent
	return g
end

function T.Lozenge(parent, size, color)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color or T.col.accent
	f.BorderSizePixel = 0
	f.Size = UDim2.fromOffset(size, size)
	f.Rotation = 45
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Parent = parent
	return f
end

-- A low sun over a dune: disc, three rays, and a bar for the horizon.
function T.Sigil(parent, h, color)
	local holder = Instance.new("Frame")
	holder.Name = "Sigil"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(h * 1.5, h)
	holder.Parent = parent

	local col = color or T.col.accent
	local disc = Instance.new("Frame")
	disc.BackgroundColor3 = col
	disc.BorderSizePixel = 0
	disc.AnchorPoint = Vector2.new(0.5, 1)
	disc.Position = UDim2.new(0.5, 0, 1, -math.floor(h * 0.22))
	local d = math.max(6, math.floor(h * 0.56))
	disc.Size = UDim2.fromOffset(d, d)
	disc.Parent = holder
	T.Corner(disc, math.floor(d / 2))

	for i = -1, 1 do
		local ray = Instance.new("Frame")
		ray.BackgroundColor3 = T.col.accentHi
		ray.BorderSizePixel = 0
		ray.AnchorPoint = Vector2.new(0.5, 1)
		ray.Position = UDim2.new(0.5 + i * 0.33, 0, 1, -math.floor(h * 0.62))
		ray.Size = UDim2.fromOffset(2, math.floor(h * 0.26))
		ray.Rotation = i * 22
		ray.Parent = holder
		T.Corner(ray, 1)
	end

	local horizon = Instance.new("Frame")
	horizon.BackgroundColor3 = T.col.teal
	horizon.BorderSizePixel = 0
	horizon.AnchorPoint = Vector2.new(0.5, 1)
	horizon.Position = UDim2.new(0.5, 0, 1, 0)
	horizon.Size = UDim2.new(1, 0, 0, 2)
	horizon.Parent = holder
	T.Corner(horizon, 1)
	return holder
end

function T.Divider(parent, width)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 10)
	holder.Parent = parent

	local line = Instance.new("Frame")
	line.BackgroundColor3 = T.col.accentLo
	line.BorderSizePixel = 0
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale(0.5, 0.5)
	line.Size = UDim2.new(width or 1, 0, 0, 1)
	line.Parent = holder
	T.AccentGradient(line, 0)

	local dot = T.Lozenge(holder, 6, T.col.teal)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Parent = holder
	return holder
end

return T
