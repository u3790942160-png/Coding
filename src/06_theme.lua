-- @module theme
-- Lord's Court palette and metrics. Ornaments are built from rotated
-- frames, not glyphs, so nothing depends on a font having the codepoint.
local Svc = _R("svc")

local T = {}

local function c3(r, g, b) return Color3.fromRGB(r, g, b) end

T.col = {
	bg0      = c3(11, 9, 15),
	bg1      = c3(19, 16, 27),
	bg2      = c3(28, 23, 40),
	bg3      = c3(38, 31, 54),
	stroke   = c3(84, 62, 118),
	strokeLo = c3(48, 38, 68),
	gold     = c3(214, 174, 94),
	goldHi   = c3(248, 226, 163),
	goldLo   = c3(132, 105, 54),
	text     = c3(237, 230, 215),
	textDim  = c3(154, 144, 130),
	crimson  = c3(158, 38, 52),
	good     = c3(112, 184, 124),
	bad      = c3(198, 76, 76),
	warn     = c3(224, 168, 72),
}

T.font = {
	title = Enum.Font.Garamond,
	body  = Enum.Font.Garamond,
	mono  = Enum.Font.Code,
}

T.metric = {
	corner      = 6,
	pad         = 10,
	rowH        = 34,
	rowHMobile  = 42,
	sliderH     = 46,
	sliderHMob  = 56,
	tabH        = 34,
	headerH     = 46,
	stroke      = 1,
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
	if kind == "title" then return mob and 22 or 20 end
	if kind == "small" then return mob and 14 or 13 end
	if kind == "tab"   then return mob and 16 or 15 end
	return mob and 17 or 16
end

-- Window size that fits the device.
function T.WindowSize()
	local vp = Svc.ViewportSize()
	if Svc.IsMobile() then
		local w = math.min(vp.X * 0.94, 600)
		local h = math.min(vp.Y * 0.80, 520)
		return UDim2.fromOffset(math.floor(w), math.floor(h))
	end
	return UDim2.fromOffset(620, 430)
end

-- ── builders ─────────────────────────────────────────────────────────
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

function T.GoldGradient(parent, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, T.col.goldLo),
		ColorSequenceKeypoint.new(0.45, T.col.goldHi),
		ColorSequenceKeypoint.new(1.0, T.col.goldLo),
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

-- Rotated square used as a heraldic lozenge.
function T.Lozenge(parent, size, color)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color or T.col.gold
	f.BorderSizePixel = 0
	f.Size = UDim2.fromOffset(size, size)
	f.Rotation = 45
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Parent = parent
	return f
end

-- A crown drawn from five lozenges and a bar. Scales with height h.
function T.Crown(parent, h, color)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(h * 1.6, h)
	holder.Name = "Crown"
	holder.Parent = parent

	local col = color or T.col.gold
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = col
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.fromScale(0.5, 1)
	bar.Size = UDim2.new(1, 0, 0, math.max(2, math.floor(h * 0.22)))
	bar.Parent = holder
	T.Corner(bar, 2)

	local peaks = {0.12, 0.5, 0.88}
	for i, px in ipairs(peaks) do
		local spike = Instance.new("Frame")
		spike.BackgroundColor3 = col
		spike.BorderSizePixel = 0
		spike.AnchorPoint = Vector2.new(0.5, 1)
		spike.Position = UDim2.new(px, 0, 1, -math.floor(h * 0.18))
		local sh = (i == 2) and h * 0.78 or h * 0.58
		spike.Size = UDim2.fromOffset(math.max(2, math.floor(h * 0.16)), math.floor(sh))
		spike.Parent = holder
		T.Corner(spike, 1)

		local gem = T.Lozenge(holder, math.max(4, math.floor(h * 0.26)), T.col.goldHi)
		gem.Position = UDim2.new(px, 0, 1, -math.floor(h * 0.18 + sh))
		gem.Parent = holder
	end
	return holder
end

-- Thin gold rule with a centre lozenge.
function T.Divider(parent, width)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 10)
	holder.Parent = parent

	local line = Instance.new("Frame")
	line.BackgroundColor3 = T.col.goldLo
	line.BorderSizePixel = 0
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale(0.5, 0.5)
	line.Size = UDim2.new(width or 1, 0, 0, 1)
	line.Parent = holder
	T.GoldGradient(line, 0)

	local dot = T.Lozenge(holder, 6, T.col.gold)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Parent = holder
	return holder
end

return T
