--[[
	SpiderUI  ·  a Spider-Man themed interface library for Roblox
	----------------------------------------------------------------
	Everything is drawn procedurally (webbing, spider emblem, glows) so the
	library has zero asset dependencies and works in any executor.

		local SpiderUI = loadstring(game:HttpGet("<url>/SpiderUI.lua"))()

		local Window = SpiderUI:CreateWindow({
			Title    = "SPIDER",
			Accent   = "VERSE",
			Subtitle = "v1.0",
			Theme    = "Classic",     -- Classic | Miles | Noir | Symbiote | 2099
			Size     = UDim2.fromOffset(720, 470),
			ToggleKey = Enum.KeyCode.RightControl,
		})

		local Tab = Window:CreateTab("SPEED")
		Tab:CreateSection("SPEEDS")
		Tab:CreateSlider({ Text = "Normal Speed", Min = 16, Max = 200, Default = 70,
			Flag = "NormalSpeed", Callback = function(v) end })
		Tab:CreateToggle({ Text = "Carry Mode", Default = false,
			Flag = "CarryMode", Callback = function(on) end })

	Values live in SpiderUI.Flags[flag] once a Flag is given.
--]]

local Players            = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local CoreGui            = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local TAB_HEIGHT  = 42
local TAB_PADDING = 6

local SpiderUI = {
	Version  = "1.0.0",
	Flags    = {},
	Windows  = {},
}

----------------------------------------------------------------------
-- THEMES
----------------------------------------------------------------------

local Themes = {
	-- The suit: red, blue, black, white webbing.
	Classic = {
		Backdrop    = Color3.fromRGB(7, 9, 22),
		Surface     = Color3.fromRGB(12, 15, 34),
		SurfaceAlt  = Color3.fromRGB(16, 20, 45),
		Card        = Color3.fromRGB(21, 26, 56),
		CardHover   = Color3.fromRGB(30, 37, 76),
		Stroke      = Color3.fromRGB(52, 62, 116),
		StrokeSoft  = Color3.fromRGB(38, 45, 88),
		Accent      = Color3.fromRGB(226, 32, 42),
		AccentDeep  = Color3.fromRGB(138, 12, 22),
		Secondary   = Color3.fromRGB(43, 92, 219),
		Web         = Color3.fromRGB(198, 214, 255),
		Text        = Color3.fromRGB(238, 242, 255),
		SubText     = Color3.fromRGB(133, 145, 190),
		Muted       = Color3.fromRGB(88, 98, 138),
	},
	-- Miles Morales: black suit, red spray-paint, that neon spider-sense pop.
	Miles = {
		Backdrop    = Color3.fromRGB(6, 6, 10),
		Surface     = Color3.fromRGB(11, 11, 17),
		SurfaceAlt  = Color3.fromRGB(15, 15, 23),
		Card        = Color3.fromRGB(20, 20, 30),
		CardHover   = Color3.fromRGB(31, 31, 45),
		Stroke      = Color3.fromRGB(58, 58, 78),
		StrokeSoft  = Color3.fromRGB(38, 38, 52),
		Accent      = Color3.fromRGB(255, 42, 60),
		AccentDeep  = Color3.fromRGB(122, 8, 20),
		Secondary   = Color3.fromRGB(0, 224, 255),
		Web         = Color3.fromRGB(226, 232, 255),
		Text        = Color3.fromRGB(245, 246, 255),
		SubText     = Color3.fromRGB(140, 144, 168),
		Muted       = Color3.fromRGB(92, 96, 118),
	},
	-- Spider-Man Noir: ink, newsprint, one shot of colour.
	Noir = {
		Backdrop    = Color3.fromRGB(10, 10, 11),
		Surface     = Color3.fromRGB(16, 16, 18),
		SurfaceAlt  = Color3.fromRGB(21, 21, 24),
		Card        = Color3.fromRGB(27, 27, 31),
		CardHover   = Color3.fromRGB(40, 40, 46),
		Stroke      = Color3.fromRGB(70, 70, 78),
		StrokeSoft  = Color3.fromRGB(46, 46, 52),
		Accent      = Color3.fromRGB(206, 206, 214),
		AccentDeep  = Color3.fromRGB(96, 96, 104),
		Secondary   = Color3.fromRGB(150, 24, 32),
		Web         = Color3.fromRGB(180, 180, 190),
		Text        = Color3.fromRGB(240, 240, 244),
		SubText     = Color3.fromRGB(138, 138, 148),
		Muted       = Color3.fromRGB(96, 96, 106),
	},
	-- Venom / symbiote: oily black and sickly white.
	Symbiote = {
		Backdrop    = Color3.fromRGB(6, 8, 10),
		Surface     = Color3.fromRGB(10, 13, 16),
		SurfaceAlt  = Color3.fromRGB(14, 18, 22),
		Card        = Color3.fromRGB(19, 24, 29),
		CardHover   = Color3.fromRGB(29, 36, 43),
		Stroke      = Color3.fromRGB(62, 74, 84),
		StrokeSoft  = Color3.fromRGB(40, 48, 56),
		Accent      = Color3.fromRGB(232, 238, 240),
		AccentDeep  = Color3.fromRGB(120, 130, 136),
		Secondary   = Color3.fromRGB(126, 62, 198),
		Web         = Color3.fromRGB(200, 212, 216),
		Text        = Color3.fromRGB(236, 242, 244),
		SubText     = Color3.fromRGB(126, 138, 148),
		Muted       = Color3.fromRGB(84, 94, 102),
	},
	-- 2099: cyber red on deep teal.
	["2099"] = {
		Backdrop    = Color3.fromRGB(4, 18, 28),
		Surface     = Color3.fromRGB(7, 28, 42),
		SurfaceAlt  = Color3.fromRGB(10, 38, 54),
		Card        = Color3.fromRGB(13, 50, 68),
		CardHover   = Color3.fromRGB(20, 70, 92),
		Stroke      = Color3.fromRGB(32, 108, 134),
		StrokeSoft  = Color3.fromRGB(22, 76, 98),
		Accent      = Color3.fromRGB(255, 46, 78),
		AccentDeep  = Color3.fromRGB(138, 12, 40),
		Secondary   = Color3.fromRGB(0, 234, 214),
		Web         = Color3.fromRGB(150, 240, 255),
		Text        = Color3.fromRGB(232, 250, 255),
		SubText     = Color3.fromRGB(118, 172, 190),
		Muted       = Color3.fromRGB(80, 124, 144),
	},
}

SpiderUI.Themes = Themes

----------------------------------------------------------------------
-- SMALL HELPERS
----------------------------------------------------------------------

local TI = {
	Snap  = TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	Sway  = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Swing = TweenInfo.new(0.45, Enum.EasingStyle.Back,  Enum.EasingDirection.Out),
	Slow  = TweenInfo.new(0.6,  Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
}

local function tween(inst, info, props)
	local t = TweenService:Create(inst, info, props)
	t:Play()
	return t
end

local function new(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(inst, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = inst })
end

local function padding(inst, t, b, l, r)
	return new("UIPadding", {
		PaddingTop    = UDim.new(0, t or 0),
		PaddingBottom = UDim.new(0, b or t or 0),
		PaddingLeft   = UDim.new(0, l or 0),
		PaddingRight  = UDim.new(0, r or l or 0),
		Parent        = inst,
	})
end

local function lerp(a, b, t) return a + (b - a) * t end

local function round(value, increment)
	if not increment or increment <= 0 then return value end
	return math.floor(value / increment + 0.5) * increment
end

-- Trims float noise so sliders read "34" and not "34.000000001".
local function fmt(value, increment)
	if increment and increment < 1 then
		local decimals, scaled = 0, increment
		while scaled < 1 and decimals < 4 do
			scaled = scaled * 10
			decimals = decimals + 1
		end
		return string.format("%." .. decimals .. "f", value)
	end
	return tostring(math.floor(value + 0.5))
end

local function isMobile()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Best-effort protected parent so the GUI survives CoreGui-only environments.
local function safeParent(gui)
	local ok = pcall(function()
		if syn and syn.protect_gui then
			syn.protect_gui(gui)
			gui.Parent = CoreGui
		elseif gethui then
			gui.Parent = gethui()
		else
			gui.Parent = CoreGui
		end
	end)
	if not ok or not gui.Parent then
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
end

----------------------------------------------------------------------
-- THEME REGISTRY
--   Every themed property is registered so SetTheme() can repaint live.
----------------------------------------------------------------------

local Registry = {}

local function paint(window, inst, prop, resolver)
	local entry = { inst = inst, prop = prop, resolver = resolver, window = window }
	Registry[#Registry + 1] = entry
	local theme = window and window.Theme or Themes.Classic
	inst[prop] = (type(resolver) == "function") and resolver(theme) or theme[resolver]
	return inst
end

local function repaint(window)
	for i = #Registry, 1, -1 do
		local e = Registry[i]
		if e.window == window then
			if typeof(e.inst) ~= "Instance" or not e.inst.Parent then
				table.remove(Registry, i)
			else
				local value = (type(e.resolver) == "function")
					and e.resolver(window.Theme)
					or window.Theme[e.resolver]
				tween(e.inst, TI.Sway, { [e.prop] = value })
			end
		end
	end
end

----------------------------------------------------------------------
-- PROCEDURAL ART: webbing + spider emblem
----------------------------------------------------------------------

-- Draws a 1px line between two pixel points using a rotated frame.
local function strand(parent, p1, p2, thickness, zindex)
	local delta = p2 - p1
	local length = delta.Magnitude
	if length < 1 then return nil end
	return new("Frame", {
		AnchorPoint            = Vector2.new(0.5, 0.5),
		Position               = UDim2.fromOffset((p1.X + p2.X) * 0.5, (p1.Y + p2.Y) * 0.5),
		Size                   = UDim2.fromOffset(math.ceil(length) + 1, thickness or 1),
		Rotation               = math.deg(math.atan2(delta.Y, delta.X)),
		BorderSizePixel        = 0,
		BackgroundTransparency = 0.82,
		ZIndex                 = zindex or 1,
		Parent                 = parent,
	})
end

--[[
	A real orb web: radial spokes from an origin, and rings whose chords sag
	back toward the centre. Drawn once into a clipped container, then faded
	with a gradient so it reads as texture rather than decoration.
--]]
local function buildWeb(window, parent, cfg)
	local origin  = cfg.Origin
	local spokes  = cfg.Spokes or 11
	local rings   = cfg.Rings or 7
	local spacing = cfg.Spacing or 62
	local inner   = cfg.Inner or 34
	local a0      = math.rad(cfg.StartAngle or 0)
	local a1      = math.rad(cfg.EndAngle or 360)
	-- Chords are pulled only slightly toward the hub: a deeper sag turns the
	-- rings into a visible zigzag instead of reading as a curve.
	local sag     = cfg.Sag or 0.96
	local zindex  = cfg.ZIndex or 1

	local holder = new("Frame", {
		Name                   = "Web",
		Size                   = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants       = true,
		ZIndex                 = zindex,
		Parent                 = parent,
	})

	local function point(ringIndex, spokeIndex)
		local radius = inner + spacing * ringIndex
		local angle  = a0 + (a1 - a0) * (spokeIndex / spokes)
		return origin + Vector2.new(math.cos(angle) * radius, math.sin(angle) * radius)
	end

	-- Spokes.
	for s = 0, spokes do
		local line = strand(holder, point(0, s), point(rings, s), 1, zindex)
		if line then
			paint(window, line, "BackgroundColor3", "Web")
			line.BackgroundTransparency = 0.7
		end
	end

	-- Rings, two sagging segments per cell.
	for r = 1, rings do
		for s = 0, spokes - 1 do
			local p1 = point(r, s)
			local p2 = point(r, s + 1)
			local mid = (p1 + p2) * 0.5
			mid = origin + (mid - origin) * sag
			for _, pair in ipairs({ { p1, mid }, { mid, p2 } }) do
				local line = strand(holder, pair[1], pair[2], 1, zindex)
				if line then
					paint(window, line, "BackgroundColor3", "Web")
					line.BackgroundTransparency = 0.8
				end
			end
		end
	end

	-- Fade the web out away from its origin corner.
	new("UIGradient", {
		Rotation = cfg.FadeRotation or 35,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.55, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = holder,
	})

	return holder
end

--[[
	The emblem: an eight-legged spider built from rotated frames. Legs are two
	segments each with a knee, so the silhouette bends like the suit's logo
	instead of looking like an asterisk.
--]]
local function buildSpider(window, parent, size, colorKey, zindex)
	colorKey = colorKey or "Accent"
	zindex = zindex or 5

	local holder = new("Frame", {
		Name                   = "Spider",
		Size                   = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex                 = zindex,
		Parent                 = parent,
	})

	local centre = Vector2.new(size / 2, size / 2)
	local unit   = size / 24
	local parts  = {}

	local function limb(p1, p2, thickness)
		local line = strand(holder, p1, p2, thickness, zindex)
		if line then
			line.BackgroundTransparency = 0
			corner(line, math.max(1, math.floor(thickness / 2)))
			paint(window, line, "BackgroundColor3", colorKey)
			parts[#parts + 1] = line
		end
		return line
	end

	-- Four legs per side, mirrored, each with a raised knee.
	local legAngles = { -68, -28, 20, 58 }
	for _, baseAngle in ipairs(legAngles) do
		for _, side in ipairs({ -1, 1 }) do
			local a    = math.rad(baseAngle)
			local root = centre + Vector2.new(side * unit * 1.6, unit * 0.4)
			local knee = root + Vector2.new(side * math.cos(a) * unit * 5.4, math.sin(a) * unit * 5.4)
			-- The trailing drop is kept under unit*2.4 so the rear legs stay
			-- inside the holder instead of clipping at large sizes.
			local tip  = knee + Vector2.new(side * math.cos(a) * unit * 4.4,
				math.sin(a) * unit * 4.4 + unit * 2.2)
			limb(root, knee, math.max(2, unit * 1.05))
			limb(knee, tip, math.max(2, unit * 0.9))
		end
	end

	-- Abdomen and thorax.
	local body = new("Frame", {
		AnchorPoint     = Vector2.new(0.5, 0.5),
		Position        = UDim2.fromScale(0.5, 0.56),
		Size            = UDim2.fromOffset(math.max(4, unit * 4.6), math.max(6, unit * 9.4)),
		BorderSizePixel = 0,
		ZIndex          = zindex + 1,
		Parent          = holder,
	})
	corner(body, math.floor(unit * 2.3))
	paint(window, body, "BackgroundColor3", colorKey)
	parts[#parts + 1] = body

	local head = new("Frame", {
		AnchorPoint     = Vector2.new(0.5, 0.5),
		Position        = UDim2.fromScale(0.5, 0.26),
		Size            = UDim2.fromOffset(math.max(4, unit * 3.4), math.max(4, unit * 3.4)),
		BorderSizePixel = 0,
		ZIndex          = zindex + 1,
		Parent          = holder,
	})
	corner(head, math.floor(unit * 1.7))
	paint(window, head, "BackgroundColor3", colorKey)
	parts[#parts + 1] = head

	return holder, parts
end

----------------------------------------------------------------------
-- INTERACTION HELPERS
----------------------------------------------------------------------

local function makeDraggable(handle, target)
	local dragging, dragInput, dragStart, startPos = false, nil, nil, nil

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging  = true
			dragStart = input.Position
			startPos  = target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	handle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input == dragInput and dragStart then
			local delta = input.Position - dragStart
			target.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

-- Expanding ring: the "spider-sense" tingle fired on state changes.
local function spiderSense(window, anchor, colorKey)
	if not anchor or not anchor.Parent then return end
	local ring = new("Frame", {
		AnchorPoint            = Vector2.new(0.5, 0.5),
		Position               = UDim2.fromScale(0.5, 0.5),
		Size                   = UDim2.fromScale(0.6, 0.6),
		BackgroundTransparency = 1,
		ZIndex                 = (anchor.ZIndex or 1) + 4,
		Parent                 = anchor,
	})
	corner(ring, 100)
	local stroke = new("UIStroke", { Thickness = 2, Transparency = 0.1, Parent = ring })
	paint(window, stroke, "Color", colorKey or "Accent")

	tween(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(2.1, 2.6),
	})
	tween(stroke, TweenInfo.new(0.45), { Transparency = 1 })
	task.delay(0.5, function() ring:Destroy() end)
end

----------------------------------------------------------------------
-- CONTROL PRIMITIVES
----------------------------------------------------------------------

local Tab = {}
Tab.__index = Tab

-- Base row: the card every control sits inside.
function Tab:_card(height, interactive)
	local window = self.Window
	self._order = (self._order or 0) + 1
	self._controls = (self._controls or 0) + 1
	if window.Active == self and not self.Description then
		window.HeaderSub.Text = self._controls .. (self._controls == 1 and " control" or " controls")
	end

	local card = new("Frame", {
		Name            = "Card",
		Size            = UDim2.new(1, 0, 0, height),
		BorderSizePixel = 0,
		LayoutOrder     = self._order,
		ClipsDescendants = true,
		Parent          = self.Page,
	})
	corner(card, 10)
	paint(window, card, "BackgroundColor3", "Card")

	local stroke = new("UIStroke", { Thickness = 1, Transparency = 0.55, Parent = card })
	paint(window, stroke, "Color", "StrokeSoft")

	-- A thin accent rail on the left edge, revealed on hover.
	local rail = new("Frame", {
		Name                   = "Rail",
		Size                   = UDim2.new(0, 2, 1, -18),
		Position               = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint            = Vector2.new(0, 0.5),
		BorderSizePixel        = 0,
		BackgroundTransparency = 1,
		ZIndex                 = 3,
		Parent                 = card,
	})
	paint(window, rail, "BackgroundColor3", "Accent")

	if interactive ~= false then
		card.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				tween(card, TI.Snap, { BackgroundColor3 = window.Theme.CardHover })
				tween(stroke, TI.Snap, { Transparency = 0.2 })
				tween(rail, TI.Snap, { BackgroundTransparency = 0 })
			end
		end)
		card.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				tween(card, TI.Snap, { BackgroundColor3 = window.Theme.Card })
				tween(stroke, TI.Snap, { Transparency = 0.55 })
				tween(rail, TI.Snap, { BackgroundTransparency = 1 })
			end
		end)
	end

	return card
end

local function cardTitle(window, card, text, sub)
	local title = new("TextLabel", {
		Name                   = "Title",
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 16, 0, sub and 9 or 0),
		Size                   = sub and UDim2.new(1, -140, 0, 18) or UDim2.new(1, -140, 1, 0),
		Font                   = Enum.Font.GothamMedium,
		Text                   = text,
		TextSize               = 14,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 3,
		Parent                 = card,
	})
	paint(window, title, "TextColor3", "Text")

	if sub then
		local subtitle = new("TextLabel", {
			Name                   = "Sub",
			BackgroundTransparency = 1,
			Position               = UDim2.new(0, 16, 0, 27),
			Size                   = UDim2.new(1, -140, 0, 14),
			Font                   = Enum.Font.Gotham,
			Text                   = sub,
			TextSize               = 11,
			TextXAlignment         = Enum.TextXAlignment.Left,
			ZIndex                 = 3,
			Parent                 = card,
		})
		paint(window, subtitle, "TextColor3", "SubText")
	end

	return title
end

function Tab:CreateSection(text)
	local window = self.Window
	self._order = (self._order or 0) + 1

	local holder = new("Frame", {
		Name                   = "Section",
		Size                   = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		LayoutOrder            = self._order,
		Parent                 = self.Page,
	})

	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 4, 0, 6),
		Size                   = UDim2.new(1, -8, 0, 16),
		Font                   = Enum.Font.GothamBold,
		Text                   = string.upper(text),
		TextSize               = 12,
		TextXAlignment         = Enum.TextXAlignment.Left,
		Parent                 = holder,
	})
	paint(window, label, "TextColor3", "SubText")

	-- Divider that bleeds from accent into nothing, like a strand of web.
	local line = new("Frame", {
		Position        = UDim2.new(0, 4, 0, 28),
		Size            = UDim2.new(1, -8, 0, 1),
		BorderSizePixel = 0,
		Parent          = holder,
	})
	paint(window, line, "BackgroundColor3", "Accent")
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(0.4, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = line,
	})

	return holder
end

function Tab:CreateLabel(text)
	local window = self.Window
	local card = self:_card(38, false)
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 16, 0, 0),
		Size                   = UDim2.new(1, -32, 1, 0),
		Font                   = Enum.Font.Gotham,
		Text                   = text,
		TextSize               = 13,
		TextXAlignment         = Enum.TextXAlignment.Left,
		TextWrapped            = true,
		ZIndex                 = 3,
		Parent                 = card,
	})
	paint(window, label, "TextColor3", "SubText")

	return {
		Set = function(_, value)
			label.Text = value
		end,
	}
end

function Tab:CreateParagraph(title, body)
	local window = self.Window
	local card = self:_card(64, false)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.Size = UDim2.new(1, 0, 0, 0)
	padding(card, 12, 12, 16, 16)

	local heading = new("TextLabel", {
		BackgroundTransparency = 1,
		Size                   = UDim2.new(1, 0, 0, 18),
		Font                   = Enum.Font.GothamBold,
		Text                   = title,
		TextSize               = 13,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 3,
		Parent                 = card,
	})
	paint(window, heading, "TextColor3", "Text")

	local text = new("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 0, 0, 22),
		Size                   = UDim2.new(1, 0, 0, 0),
		AutomaticSize          = Enum.AutomaticSize.Y,
		Font                   = Enum.Font.Gotham,
		Text                   = body,
		TextSize               = 12,
		TextXAlignment         = Enum.TextXAlignment.Left,
		TextYAlignment         = Enum.TextYAlignment.Top,
		TextWrapped            = true,
		ZIndex                 = 3,
		Parent                 = card,
	})
	paint(window, text, "TextColor3", "SubText")

	return { Set = function(_, value) text.Text = value end }
end

function Tab:CreateButton(cfg)
	cfg = cfg or {}
	local window = self.Window
	local card = self:_card(46)
	cardTitle(window, card, cfg.Text or "Button", cfg.Description)

	local button = new("TextButton", {
		AnchorPoint     = Vector2.new(1, 0.5),
		Position        = UDim2.new(1, -12, 0.5, 0),
		Size            = UDim2.fromOffset(96, 28),
		Font            = Enum.Font.GothamBold,
		Text            = cfg.ButtonText or "RUN",
		TextSize        = 12,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex          = 4,
		Parent          = card,
	})
	corner(button, 7)
	paint(window, button, "BackgroundColor3", "Accent")
	paint(window, button, "TextColor3", function(t)
		return t == Themes.Noir and Color3.fromRGB(16, 16, 18) or Color3.fromRGB(255, 255, 255)
	end)

	local gradient = new("UIGradient", { Rotation = 90, Parent = button })
	paint(window, gradient, "Color", function(t)
		return ColorSequence.new(t.Accent, t.AccentDeep)
	end)

	button.MouseButton1Click:Connect(function()
		spiderSense(window, button)
		tween(button, TI.Snap, { Size = UDim2.fromOffset(90, 25) })
		task.delay(0.1, function()
			tween(button, TI.Swing, { Size = UDim2.fromOffset(96, 28) })
		end)
		if cfg.Callback then
			task.spawn(cfg.Callback)
		end
	end)

	return card
end

function Tab:CreateToggle(cfg)
	cfg = cfg or {}
	local window = self.Window
	local card = self:_card(cfg.Description and 52 or 46)
	cardTitle(window, card, cfg.Text or "Toggle", cfg.Description)

	local state = cfg.Default and true or false

	local track = new("TextButton", {
		AnchorPoint     = Vector2.new(1, 0.5),
		Position        = UDim2.new(1, -14, 0.5, 0),
		Size            = UDim2.fromOffset(46, 24),
		Text            = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex          = 4,
		Parent          = card,
	})
	corner(track, 12)
	paint(window, track, "BackgroundColor3", "SurfaceAlt")

	local trackStroke = new("UIStroke", { Thickness = 1, Transparency = 0.4, Parent = track })
	paint(window, trackStroke, "Color", "Stroke")

	local fill = new("Frame", {
		Size                   = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		ZIndex                 = 4,
		Parent                 = track,
	})
	corner(fill, 12)
	paint(window, fill, "BackgroundColor3", "Accent")
	local fillGradient = new("UIGradient", { Rotation = 25, Parent = fill })
	paint(window, fillGradient, "Color", function(t)
		return ColorSequence.new(t.Accent, t.AccentDeep)
	end)

	local knob = new("Frame", {
		AnchorPoint     = Vector2.new(0, 0.5),
		Position        = UDim2.new(0, 3, 0.5, 0),
		Size            = UDim2.fromOffset(18, 18),
		BorderSizePixel = 0,
		ZIndex          = 6,
		Parent          = track,
	})
	corner(knob, 9)
	paint(window, knob, "BackgroundColor3", function(t) return t.Text end)

	local api = {}

	local function apply(value, silent)
		state = value and true or false
		if cfg.Flag then SpiderUI.Flags[cfg.Flag] = state end

		tween(knob, TI.Swing, { Position = UDim2.new(0, state and 25 or 3, 0.5, 0) })
		tween(fill, TI.Sway, { BackgroundTransparency = state and 0 or 1 })
		tween(trackStroke, TI.Sway, {
			Color = state and window.Theme.Accent or window.Theme.Stroke,
			Transparency = state and 0.15 or 0.4,
		})

		if not silent then
			spiderSense(window, knob)
			if cfg.Callback then
				task.spawn(cfg.Callback, state)
			end
		end
	end

	track.MouseButton1Click:Connect(function() apply(not state) end)

	function api:Set(value) apply(value) end
	function api:Get() return state end

	apply(state, true)

	if cfg.Flag then
		self.Window.Elements[cfg.Flag] = api
	end
	return api
end

function Tab:CreateSlider(cfg)
	cfg = cfg or {}
	local window    = self.Window
	local min       = cfg.Min or 0
	local max       = cfg.Max or 100
	local increment = cfg.Increment or 1
	local suffix    = cfg.Suffix or ""
	local value     = math.clamp(cfg.Default or min, min, max)

	local card = self:_card(56)

	local title = new("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 16, 0, 8),
		Size                   = UDim2.new(1, -110, 0, 16),
		Font                   = Enum.Font.GothamMedium,
		Text                   = cfg.Text or "Slider",
		TextSize               = 14,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 3,
		Parent                 = card,
	})
	paint(window, title, "TextColor3", "Text")

	-- Value pill, styled after the reference's red number chips.
	local pill = new("Frame", {
		AnchorPoint     = Vector2.new(1, 0),
		Position        = UDim2.new(1, -14, 0, 6),
		Size            = UDim2.fromOffset(62, 22),
		BorderSizePixel = 0,
		ZIndex          = 4,
		Parent          = card,
	})
	corner(pill, 6)
	paint(window, pill, "BackgroundColor3", function(t) return t.AccentDeep end)
	local pillStroke = new("UIStroke", { Thickness = 1, Transparency = 0.45, Parent = pill })
	paint(window, pillStroke, "Color", "Accent")

	local valueLabel = new("TextLabel", {
		BackgroundTransparency = 1,
		Size                   = UDim2.fromScale(1, 1),
		Font                   = Enum.Font.GothamBold,
		Text                   = fmt(value, increment) .. suffix,
		TextSize               = 12,
		ZIndex                 = 5,
		Parent                 = pill,
	})
	paint(window, valueLabel, "TextColor3", "Text")

	local track = new("TextButton", {
		Position        = UDim2.new(0, 16, 0, 38),
		Size            = UDim2.new(1, -32, 0, 6),
		Text            = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex          = 4,
		Parent          = card,
	})
	corner(track, 3)
	paint(window, track, "BackgroundColor3", "SurfaceAlt")

	local fill = new("Frame", {
		Size            = UDim2.fromScale(0, 1),
		BorderSizePixel = 0,
		ZIndex          = 5,
		Parent          = track,
	})
	corner(fill, 3)
	paint(window, fill, "BackgroundColor3", "Accent")
	local fillGradient = new("UIGradient", { Parent = fill })
	paint(window, fillGradient, "Color", function(t)
		return ColorSequence.new(t.Secondary, t.Accent)
	end)

	local grip = new("Frame", {
		AnchorPoint     = Vector2.new(0.5, 0.5),
		Position        = UDim2.new(0, 0, 0.5, 0),
		Size            = UDim2.fromOffset(12, 12),
		BorderSizePixel = 0,
		ZIndex          = 6,
		Parent          = track,
	})
	corner(grip, 6)
	paint(window, grip, "BackgroundColor3", function(t) return t.Text end)
	local gripStroke = new("UIStroke", { Thickness = 2, Transparency = 0.25, Parent = grip })
	paint(window, gripStroke, "Color", "Accent")

	local api = {}
	local dragging = false

	local function render(animated)
		local alpha = (max > min) and (value - min) / (max - min) or 0
		local info = animated and TI.Sway or TweenInfo.new(0.05)
		tween(fill, info, { Size = UDim2.fromScale(alpha, 1) })
		tween(grip, info, { Position = UDim2.new(alpha, 0, 0.5, 0) })
		valueLabel.Text = fmt(value, increment) .. suffix
	end

	local function apply(raw, silent)
		local clamped = math.clamp(round(raw, increment), min, max)
		local changed = clamped ~= value
		value = clamped
		if cfg.Flag then SpiderUI.Flags[cfg.Flag] = value end
		render(not dragging)
		if changed and not silent and cfg.Callback then
			task.spawn(cfg.Callback, value)
		end
	end

	local function fromInput(position)
		local alpha = math.clamp((position.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		apply(lerp(min, max, alpha))
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			tween(grip, TI.Snap, { Size = UDim2.fromOffset(16, 16) })
			fromInput(input.Position)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			fromInput(input.Position)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			tween(grip, TI.Swing, { Size = UDim2.fromOffset(12, 12) })
			spiderSense(window, grip)
		end
	end)

	function api:Set(v) apply(v) end
	function api:Get() return value end

	apply(value, true)

	if cfg.Flag then
		self.Window.Elements[cfg.Flag] = api
	end
	return api
end

function Tab:CreateDropdown(cfg)
	cfg = cfg or {}
	local window  = self.Window
	local options = cfg.Options or {}
	local multi   = cfg.Multi and true or false
	local selected = multi and (cfg.Default or {}) or cfg.Default

	local ROW = 46
	local OPTION_HEIGHT = 28
	local card = self:_card(ROW)
	card.ClipsDescendants = true
	cardTitle(window, card, cfg.Text or "Dropdown", cfg.Description)

	local function displayText()
		if multi then
			local names = {}
			for _, option in ipairs(options) do
				if table.find(selected, option) then names[#names + 1] = option end
			end
			return #names > 0 and table.concat(names, ", ") or "None"
		end
		return tostring(selected or "None")
	end

	local button = new("TextButton", {
		AnchorPoint     = Vector2.new(1, 0),
		Position        = UDim2.new(1, -12, 0, 10),
		Size            = UDim2.fromOffset(132, 26),
		Font            = Enum.Font.GothamMedium,
		Text            = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex          = 4,
		Parent          = card,
	})
	corner(button, 7)
	paint(window, button, "BackgroundColor3", "SurfaceAlt")
	local buttonStroke = new("UIStroke", { Thickness = 1, Transparency = 0.45, Parent = button })
	paint(window, buttonStroke, "Color", "Stroke")

	local buttonLabel = new("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 10, 0, 0),
		Size                   = UDim2.new(1, -30, 1, 0),
		Font                   = Enum.Font.GothamMedium,
		Text                   = displayText(),
		TextSize               = 12,
		TextXAlignment         = Enum.TextXAlignment.Left,
		TextTruncate           = Enum.TextTruncate.AtEnd,
		ZIndex                 = 5,
		Parent                 = button,
	})
	paint(window, buttonLabel, "TextColor3", "Text")

	local arrow = new("TextLabel", {
		AnchorPoint            = Vector2.new(1, 0.5),
		Position               = UDim2.new(1, -9, 0.5, 0),
		Size                   = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		Font                   = Enum.Font.GothamBold,
		Text                   = "v",
		TextSize               = 11,
		ZIndex                 = 5,
		Parent                 = button,
	})
	paint(window, arrow, "TextColor3", "Accent")

	local list = new("Frame", {
		Position               = UDim2.new(0, 12, 0, ROW),
		Size                   = UDim2.new(1, -24, 0, 0),
		BackgroundTransparency = 1,
		ZIndex                 = 4,
		Parent                 = card,
	})
	new("UIListLayout", {
		Padding   = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent    = list,
	})

	local api = {}
	local open = false
	local optionButtons = {}

	local function isSelected(option)
		if multi then return table.find(selected, option) ~= nil end
		return selected == option
	end

	local function refresh()
		buttonLabel.Text = displayText()
		for option, entry in pairs(optionButtons) do
			local on = isSelected(option)
			tween(entry.button, TI.Snap, {
				BackgroundColor3 = on and window.Theme.AccentDeep or window.Theme.SurfaceAlt,
			})
			tween(entry.stroke, TI.Snap, {
				Color = on and window.Theme.Accent or window.Theme.Stroke,
				Transparency = on and 0.25 or 0.6,
			})
		end
	end

	local function setOpen(value)
		open = value
		local height = ROW + (open and (#options * (OPTION_HEIGHT + 4) + 10) or 0)
		tween(card, TI.Sway, { Size = UDim2.new(1, 0, 0, height) })
		tween(list, TI.Sway, { Size = UDim2.new(1, -24, 0, open and (#options * (OPTION_HEIGHT + 4)) or 0) })
		tween(arrow, TI.Sway, { Rotation = open and 180 or 0 })
	end

	local function buildOptions()
		for _, entry in pairs(optionButtons) do entry.button:Destroy() end
		optionButtons = {}

		for index, option in ipairs(options) do
			local optionButton = new("TextButton", {
				Size            = UDim2.new(1, 0, 0, OPTION_HEIGHT),
				Font            = Enum.Font.Gotham,
				Text            = tostring(option),
				TextSize        = 12,
				AutoButtonColor = false,
				BorderSizePixel = 0,
				LayoutOrder     = index,
				ZIndex          = 5,
				Parent          = list,
			})
			corner(optionButton, 6)
			paint(window, optionButton, "BackgroundColor3", "SurfaceAlt")
			paint(window, optionButton, "TextColor3", "Text")
			local optionStroke = new("UIStroke", { Thickness = 1, Transparency = 0.6, Parent = optionButton })
			paint(window, optionStroke, "Color", "Stroke")

			optionButton.MouseButton1Click:Connect(function()
				if multi then
					local at = table.find(selected, option)
					if at then table.remove(selected, at) else table.insert(selected, option) end
				else
					selected = option
					setOpen(false)
				end
				if cfg.Flag then SpiderUI.Flags[cfg.Flag] = selected end
				refresh()
				spiderSense(window, optionButton)
				if cfg.Callback then task.spawn(cfg.Callback, selected) end
			end)

			optionButtons[option] = { button = optionButton, stroke = optionStroke }
		end
		refresh()
	end

	button.MouseButton1Click:Connect(function() setOpen(not open) end)

	function api:Set(value)
		selected = value
		if cfg.Flag then SpiderUI.Flags[cfg.Flag] = selected end
		refresh()
		if cfg.Callback then task.spawn(cfg.Callback, selected) end
	end

	function api:Refresh(newOptions)
		options = newOptions or {}
		buildOptions()
		if open then setOpen(true) end
	end

	function api:Get() return selected end

	buildOptions()
	if cfg.Flag then
		SpiderUI.Flags[cfg.Flag] = selected
		self.Window.Elements[cfg.Flag] = api
	end
	return api
end

function Tab:CreateKeybind(cfg)
	cfg = cfg or {}
	local window = self.Window
	local card = self:_card(46)
	cardTitle(window, card, cfg.Text or "Keybind", cfg.Description)

	local key = cfg.Default
	local listening = false

	local button = new("TextButton", {
		AnchorPoint     = Vector2.new(1, 0.5),
		Position        = UDim2.new(1, -12, 0.5, 0),
		Size            = UDim2.fromOffset(96, 26),
		Font            = Enum.Font.GothamBold,
		Text            = key and key.Name or "NONE",
		TextSize        = 11,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex          = 4,
		Parent          = card,
	})
	corner(button, 7)
	paint(window, button, "BackgroundColor3", "SurfaceAlt")
	paint(window, button, "TextColor3", "Text")
	local buttonStroke = new("UIStroke", { Thickness = 1, Transparency = 0.45, Parent = button })
	paint(window, buttonStroke, "Color", "Stroke")

	button.MouseButton1Click:Connect(function()
		listening = true
		button.Text = "..."
		tween(buttonStroke, TI.Snap, { Color = window.Theme.Accent, Transparency = 0.1 })
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if listening and input.UserInputType == Enum.UserInputType.Keyboard then
			listening = false
			key = (input.KeyCode == Enum.KeyCode.Backspace) and nil or input.KeyCode
			button.Text = key and key.Name or "NONE"
			tween(buttonStroke, TI.Snap, { Color = window.Theme.Stroke, Transparency = 0.45 })
			if cfg.Flag then SpiderUI.Flags[cfg.Flag] = key end
			if cfg.Changed then task.spawn(cfg.Changed, key) end
			return
		end

		if not processed and key and input.KeyCode == key then
			spiderSense(window, button)
			if cfg.Callback then task.spawn(cfg.Callback, key) end
		end
	end)

	local api = {}
	function api:Set(value)
		key = value
		button.Text = key and key.Name or "NONE"
		if cfg.Flag then SpiderUI.Flags[cfg.Flag] = key end
	end
	function api:Get() return key end

	if cfg.Flag then
		SpiderUI.Flags[cfg.Flag] = key
		self.Window.Elements[cfg.Flag] = api
	end
	return api
end

function Tab:CreateInput(cfg)
	cfg = cfg or {}
	local window = self.Window
	local card = self:_card(46)
	cardTitle(window, card, cfg.Text or "Input", cfg.Description)

	local box = new("TextBox", {
		AnchorPoint        = Vector2.new(1, 0.5),
		Position           = UDim2.new(1, -12, 0.5, 0),
		Size               = UDim2.fromOffset(132, 26),
		Font               = Enum.Font.Gotham,
		Text               = cfg.Default or "",
		PlaceholderText    = cfg.Placeholder or "type here",
		TextSize           = 12,
		ClearTextOnFocus   = false,
		BorderSizePixel    = 0,
		ZIndex             = 4,
		Parent             = card,
	})
	corner(box, 7)
	padding(box, 0, 0, 8, 8)
	paint(window, box, "BackgroundColor3", "SurfaceAlt")
	paint(window, box, "TextColor3", "Text")
	paint(window, box, "PlaceholderColor3", "Muted")
	local boxStroke = new("UIStroke", { Thickness = 1, Transparency = 0.45, Parent = box })
	paint(window, boxStroke, "Color", "Stroke")

	box.Focused:Connect(function()
		tween(boxStroke, TI.Snap, { Color = window.Theme.Accent, Transparency = 0.1 })
	end)

	box.FocusLost:Connect(function(enter)
		tween(boxStroke, TI.Snap, { Color = window.Theme.Stroke, Transparency = 0.45 })
		if cfg.Flag then SpiderUI.Flags[cfg.Flag] = box.Text end
		if cfg.Callback then task.spawn(cfg.Callback, box.Text, enter) end
	end)

	local api = {}
	function api:Set(value)
		box.Text = tostring(value)
		if cfg.Flag then SpiderUI.Flags[cfg.Flag] = box.Text end
	end
	function api:Get() return box.Text end

	if cfg.Flag then
		SpiderUI.Flags[cfg.Flag] = box.Text
		self.Window.Elements[cfg.Flag] = api
	end
	return api
end

----------------------------------------------------------------------
-- WINDOW
----------------------------------------------------------------------

local Window = {}
Window.__index = Window

function Window:CreateTab(name, description)
	local index = #self.Tabs + 1

	local button = new("TextButton", {
		Name            = "Tab_" .. name,
		Size            = UDim2.new(1, 0, 0, TAB_HEIGHT),
		Text            = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder     = index,
		Parent          = self.TabList,
	})
	corner(button, 9)
	paint(self, button, "BackgroundColor3", "Card")
	button.BackgroundTransparency = 0.35

	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 18, 0, 0),
		Size                   = UDim2.new(1, -24, 1, 0),
		Font                   = Enum.Font.GothamBold,
		Text                   = string.upper(name),
		TextSize               = 12,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 2,
		Parent                 = button,
	})
	paint(self, label, "TextColor3", "SubText")

	local page = new("ScrollingFrame", {
		Name                   = "Page_" .. name,
		Size                   = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		ScrollBarThickness     = 3,
		CanvasSize             = UDim2.new(),
		AutomaticCanvasSize    = Enum.AutomaticSize.Y,
		ScrollingDirection     = Enum.ScrollingDirection.Y,
		Visible                = false,
		Parent                 = self.Content,
	})
	paint(self, page, "ScrollBarImageColor3", "Accent")
	padding(page, 4, 20, 2, 12)
	new("UIListLayout", {
		Padding   = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent    = page,
	})

	local tab = setmetatable({
		Window      = self,
		Name        = name,
		Description = description,
		Index       = index,
		Button      = button,
		Label       = label,
		Page        = page,
		_order      = 0,
		_controls   = 0,
	}, Tab)

	button.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end)

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and self.Active ~= tab then
			tween(button, TI.Snap, { BackgroundTransparency = 0.1 })
			tween(label, TI.Snap, { TextColor3 = self.Theme.Text })
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and self.Active ~= tab then
			tween(button, TI.Snap, { BackgroundTransparency = 0.35 })
			tween(label, TI.Snap, { TextColor3 = self.Theme.SubText })
		end
	end)

	self.Tabs[index] = tab
	if not self.Active then
		self:SelectTab(tab, true)
	end
	return tab
end

-- Indicator sits in the wrapper, not the scrolling list, so its offset is
-- derived from the tab index and corrected for the list's scroll position.
function Window:_placeIndicator(tab, instant)
	if not tab then return end
	local y = (tab.Index - 1) * (TAB_HEIGHT + TAB_PADDING) - self.TabList.CanvasPosition.Y
	local target = UDim2.new(0, 0, 0, y + (TAB_HEIGHT - 22) / 2)
	if instant then
		self.Indicator.Position = target
	else
		tween(self.Indicator, TI.Swing, { Position = target })
	end
end

function Window:SelectTab(tab, instant)
	if self.Active == tab then return end
	local previous = self.Active
	self.Active = tab

	self:_placeIndicator(tab, instant)

	if previous then
		tween(previous.Button, TI.Sway, { BackgroundTransparency = 0.35 })
		tween(previous.Label, TI.Sway, { TextColor3 = self.Theme.SubText })
		previous.Page.Visible = false
	end

	tween(tab.Button, TI.Sway, { BackgroundTransparency = 0 })
	tween(tab.Label, TI.Sway, { TextColor3 = self.Theme.Text })

	self.Header.Text = string.upper(tab.Name)
	self.HeaderSub.Text = tab.Description
		or (tab._controls .. (tab._controls == 1 and " control" or " controls"))

	tab.Page.Visible = true
	if not instant then
		-- Slide the page in as if it swung into frame.
		tab.Page.Position = UDim2.fromOffset(18, 0)
		tween(tab.Page, TI.Sway, { Position = UDim2.fromOffset(0, 0) })
	end
end

function Window:SetTheme(name)
	local theme = Themes[name]
	if not theme then return end
	self.Theme = theme
	self.ThemeName = name
	repaint(self)

	-- Hover/selection states are driven imperatively, so refresh them here.
	for _, tab in ipairs(self.Tabs) do
		tab.Button.BackgroundTransparency = (self.Active == tab) and 0 or 0.35
		tab.Label.TextColor3 = (self.Active == tab) and theme.Text or theme.SubText
	end
end

function Window:Notify(cfg)
	return SpiderUI:Notify(cfg, self)
end

function Window:Toggle(visible)
	if visible == nil then visible = not self.Visible end
	self.Visible = visible

	if visible then
		self.Root.Visible = true
		tween(self.Scale, TI.Swing, { Scale = self.BaseScale })
		tween(self.Root, TI.Sway, { BackgroundTransparency = 0 })
	else
		tween(self.Scale, TI.Sway, { Scale = self.BaseScale * 0.9 })
		tween(self.Root, TI.Sway, { BackgroundTransparency = 1 })
		task.delay(0.28, function()
			if not self.Visible then self.Root.Visible = false end
		end)
	end
end

function Window:Minimize()
	self:Toggle(false)
	self.Emblem.Visible = true
	self.EmblemScale.Scale = 0.2
	tween(self.EmblemScale, TI.Swing, { Scale = 1 })
end

function Window:Destroy()
	if self.Gui then self.Gui:Destroy() end
	for i = #Registry, 1, -1 do
		if Registry[i].window == self then table.remove(Registry, i) end
	end
end

----------------------------------------------------------------------
-- WINDOW CONSTRUCTION
----------------------------------------------------------------------

function SpiderUI:CreateWindow(cfg)
	cfg = cfg or {}

	local themeName = cfg.Theme or "Classic"
	local theme = Themes[themeName] or Themes.Classic

	local self = setmetatable({
		Theme     = theme,
		ThemeName = themeName,
		Tabs      = {},
		Elements  = {},
		Visible   = true,
	}, Window)

	local size = cfg.Size or UDim2.fromOffset(720, 470)
	local mobile = isMobile()
	self.BaseScale = cfg.Scale or (mobile and 0.78 or 1)

	local gui = new("ScreenGui", {
		Name             = cfg.Name or "SpiderUI",
		ResetOnSpawn     = false,
		IgnoreGuiInset   = true,
		ZIndexBehavior   = Enum.ZIndexBehavior.Sibling,
		DisplayOrder     = 999,
	})
	safeParent(gui)
	self.Gui = gui

	----------------------------------------------------------------
	-- Root
	----------------------------------------------------------------
	local root = new("Frame", {
		Name            = "Root",
		AnchorPoint     = Vector2.new(0.5, 0.5),
		Position        = cfg.Position or UDim2.fromScale(0.5, 0.5),
		Size            = size,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active          = true,
		Parent          = gui,
	})
	corner(root, 16)
	paint(self, root, "BackgroundColor3", "Backdrop")
	self.Root = root

	local rootStroke = new("UIStroke", { Thickness = 1.4, Transparency = 0.35, Parent = root })
	paint(self, rootStroke, "Color", "Stroke")

	self.Scale = new("UIScale", { Scale = self.BaseScale, Parent = root })

	-- Backdrop gradient: deep blue up top bleeding to near-black.
	local backdropGradient = new("UIGradient", { Rotation = 115, Parent = root })
	paint(self, backdropGradient, "Color", function(t)
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, t.Surface),
			ColorSequenceKeypoint.new(0.55, t.Backdrop),
			ColorSequenceKeypoint.new(1, t.Backdrop),
		})
	end)

	-- Web geometry is baked in pixels, so scale-based sizes fall back to the
	-- default dimensions rather than collapsing to a point.
	local webWidth  = size.X.Offset > 0 and size.X.Offset or 720
	local webHeight = size.Y.Offset > 0 and size.Y.Offset or 470

	-- Two quarter-webs pinned to opposite corners. Anchoring the hub exactly on
	-- the corner is what makes the spokes converge and read as webbing; move
	-- the origin off-frame and it degrades into random diagonals.
	buildWeb(self, root, {
		Origin = Vector2.new(webWidth, 0),
		Spokes = 10, Rings = 9, Spacing = 44, Inner = 26,
		StartAngle = 90, EndAngle = 180, FadeRotation = 215, ZIndex = 1,
	})
	buildWeb(self, root, {
		Origin = Vector2.new(0, webHeight),
		Spokes = 8, Rings = 6, Spacing = 40, Inner = 22,
		StartAngle = -90, EndAngle = 0, FadeRotation = 35, ZIndex = 1,
	})

	-- Accent bloom behind the header.
	local bloom = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, 160),
		BackgroundTransparency = 0.88,
		BorderSizePixel        = 0,
		ZIndex                 = 1,
		Parent                 = root,
	})
	paint(self, bloom, "BackgroundColor3", "Accent")
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = bloom,
	})

	----------------------------------------------------------------
	-- Title bar
	----------------------------------------------------------------
	local topBar = new("Frame", {
		Name                   = "TopBar",
		Size                   = UDim2.new(1, 0, 0, 54),
		BackgroundTransparency = 1,
		ZIndex                 = 4,
		Active                 = true,
		Parent                 = root,
	})
	makeDraggable(topBar, root)

	local emblemHolder = new("Frame", {
		AnchorPoint            = Vector2.new(0, 0.5),
		Position               = UDim2.new(0, 18, 0.5, 0),
		Size                   = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		ZIndex                 = 5,
		Parent                 = topBar,
	})
	buildSpider(self, emblemHolder, 30, "Accent", 5)

	local title = new("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 58, 0, 12),
		Size                   = UDim2.new(0, 300, 0, 18),
		Font                   = Enum.Font.GothamBlack,
		Text                   = cfg.Title or "SPIDER",
		TextSize               = 16,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 5,
		Parent                 = topBar,
	})
	paint(self, title, "TextColor3", "Text")

	local accentWord = new("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 58 + title.TextBounds.X + 8, 0, 12),
		Size                   = UDim2.new(0, 220, 0, 18),
		Font                   = Enum.Font.GothamBlack,
		Text                   = cfg.Accent or "VERSE",
		TextSize               = 16,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 5,
		Parent                 = topBar,
	})
	paint(self, accentWord, "TextColor3", "Accent")
	-- TextBounds is only known after the label renders, so re-place once.
	task.defer(function()
		accentWord.Position = UDim2.new(0, 58 + title.TextBounds.X + 8, 0, 12)
	end)

	local subtitle = new("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 58, 0, 30),
		Size                   = UDim2.new(0, 300, 0, 14),
		Font                   = Enum.Font.Gotham,
		Text                   = cfg.Subtitle or ("v" .. SpiderUI.Version),
		TextSize               = 11,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 5,
		Parent                 = topBar,
	})
	paint(self, subtitle, "TextColor3", "Muted")

	local function windowButton(order, glyph, colorKey, callback)
		local button = new("TextButton", {
			AnchorPoint     = Vector2.new(1, 0.5),
			Position        = UDim2.new(1, -16 - (order - 1) * 34, 0.5, 0),
			Size            = UDim2.fromOffset(28, 28),
			Font            = Enum.Font.GothamBold,
			Text            = glyph,
			TextSize        = 14,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex          = 6,
			Parent          = topBar,
		})
		corner(button, 8)
		paint(self, button, "BackgroundColor3", "Card")
		paint(self, button, "TextColor3", "SubText")
		local stroke = new("UIStroke", { Thickness = 1, Transparency = 0.6, Parent = button })
		paint(self, stroke, "Color", "StrokeSoft")

		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				tween(button, TI.Snap, {
					BackgroundColor3 = self.Theme[colorKey],
					TextColor3       = self.Theme.Text,
				})
			end
		end)
		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				tween(button, TI.Snap, {
					BackgroundColor3 = self.Theme.Card,
					TextColor3       = self.Theme.SubText,
				})
			end
		end)
		button.MouseButton1Click:Connect(callback)
		return button
	end

	windowButton(1, "X", "Accent", function()
		self:Destroy()
	end)
	windowButton(2, "—", "Secondary", function()
		self:Minimize()
	end)

	local topDivider = new("Frame", {
		Position        = UDim2.new(0, 16, 0, 54),
		Size            = UDim2.new(1, -32, 0, 1),
		BorderSizePixel = 0,
		ZIndex          = 4,
		Parent          = root,
	})
	paint(self, topDivider, "BackgroundColor3", "Accent")
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = topDivider,
	})

	----------------------------------------------------------------
	-- Sidebar
	----------------------------------------------------------------
	local sidebar = new("Frame", {
		Name            = "Sidebar",
		Position        = UDim2.new(0, 14, 0, 66),
		Size            = UDim2.new(0, 178, 1, -80),
		BorderSizePixel = 0,
		BackgroundTransparency = 0.25,
		ZIndex          = 3,
		Parent          = root,
	})
	corner(sidebar, 12)
	paint(self, sidebar, "BackgroundColor3", "Surface")
	local sidebarStroke = new("UIStroke", { Thickness = 1, Transparency = 0.7, Parent = sidebar })
	paint(self, sidebarStroke, "Color", "StrokeSoft")

	local navLabel = new("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 16, 0, 12),
		Size                   = UDim2.new(1, -24, 0, 14),
		Font                   = Enum.Font.GothamBold,
		Text                   = "NAVIGATION",
		TextSize               = 10,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 4,
		Parent                 = sidebar,
	})
	paint(self, navLabel, "TextColor3", "Muted")

	local tabWrapper = new("Frame", {
		Position               = UDim2.new(0, 12, 0, 34),
		Size                   = UDim2.new(1, -24, 1, -114),
		BackgroundTransparency = 1,
		ZIndex                 = 4,
		Parent                 = sidebar,
	})

	local tabList = new("ScrollingFrame", {
		Name                   = "Tabs",
		Size                   = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		ScrollBarThickness     = 0,
		CanvasSize             = UDim2.new(),
		AutomaticCanvasSize    = Enum.AutomaticSize.Y,
		ZIndex                 = 4,
		Parent                 = tabWrapper,
	})
	new("UIListLayout", {
		Padding   = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent    = tabList,
	})
	self.TabList = tabList

	local indicator = new("Frame", {
		Name            = "Indicator",
		AnchorPoint     = Vector2.new(0, 0),
		Position        = UDim2.new(0, 0, 0, 10),
		Size            = UDim2.fromOffset(3, 22),
		BorderSizePixel = 0,
		ZIndex          = 6,
		Parent          = tabWrapper,
	})
	corner(indicator, 2)
	paint(self, indicator, "BackgroundColor3", "Accent")
	self.Indicator = indicator

	tabList:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		self:_placeIndicator(self.Active, true)
	end)

	-- Footer identity card, mirroring the reference's "Made By" chip.
	local footer = new("Frame", {
		AnchorPoint     = Vector2.new(0, 1),
		Position        = UDim2.new(0, 12, 1, -12),
		Size            = UDim2.new(1, -24, 0, 60),
		BorderSizePixel = 0,
		ZIndex          = 4,
		Parent          = sidebar,
	})
	corner(footer, 10)
	paint(self, footer, "BackgroundColor3", "Card")
	local footerStroke = new("UIStroke", { Thickness = 1, Transparency = 0.5, Parent = footer })
	paint(self, footerStroke, "Color", "StrokeSoft")

	local avatar = new("ImageLabel", {
		AnchorPoint     = Vector2.new(0, 0.5),
		Position        = UDim2.new(0, 10, 0.5, 0),
		Size            = UDim2.fromOffset(38, 38),
		BorderSizePixel = 0,
		ZIndex          = 5,
		Parent          = footer,
	})
	corner(avatar, 19)
	paint(self, avatar, "BackgroundColor3", "SurfaceAlt")
	local avatarStroke = new("UIStroke", { Thickness = 1.4, Transparency = 0.2, Parent = avatar })
	paint(self, avatarStroke, "Color", "Accent")

	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(
				LocalPlayer.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
		end)
		if ok and content then avatar.Image = content end
	end)

	local footerName = new("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 56, 0, 12),
		Size                   = UDim2.new(1, -64, 0, 16),
		Font                   = Enum.Font.GothamBold,
		Text                   = cfg.FooterTitle or LocalPlayer.DisplayName,
		TextSize               = 12,
		TextXAlignment         = Enum.TextXAlignment.Left,
		TextTruncate           = Enum.TextTruncate.AtEnd,
		ZIndex                 = 5,
		Parent                 = footer,
	})
	paint(self, footerName, "TextColor3", "Text")

	local footerSub = new("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 56, 0, 30),
		Size                   = UDim2.new(1, -64, 0, 14),
		Font                   = Enum.Font.Gotham,
		Text                   = cfg.FooterSubtitle or "friendly neighborhood",
		TextSize               = 10,
		TextXAlignment         = Enum.TextXAlignment.Left,
		TextTruncate           = Enum.TextTruncate.AtEnd,
		ZIndex                 = 5,
		Parent                 = footer,
	})
	paint(self, footerSub, "TextColor3", "Muted")

	----------------------------------------------------------------
	-- Content
	----------------------------------------------------------------
	local contentArea = new("Frame", {
		Name                   = "ContentArea",
		Position               = UDim2.new(0, 204, 0, 66),
		Size                   = UDim2.new(1, -218, 1, -80),
		BackgroundTransparency = 1,
		ZIndex                 = 3,
		Parent                 = root,
	})

	local header = new("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 2, 0, 0),
		Size                   = UDim2.new(1, -4, 0, 22),
		Font                   = Enum.Font.GothamBlack,
		Text                   = "",
		TextSize               = 18,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 4,
		Parent                 = contentArea,
	})
	paint(self, header, "TextColor3", "Text")
	self.Header = header

	local headerSub = new("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 2, 0, 22),
		Size                   = UDim2.new(1, -4, 0, 14),
		Font                   = Enum.Font.Gotham,
		Text                   = "",
		TextSize               = 11,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 4,
		Parent                 = contentArea,
	})
	paint(self, headerSub, "TextColor3", "Muted")
	self.HeaderSub = headerSub

	local content = new("Frame", {
		Name                   = "Content",
		Position               = UDim2.new(0, 0, 0, 46),
		Size                   = UDim2.new(1, 0, 1, -46),
		BackgroundTransparency = 1,
		ClipsDescendants       = true,
		ZIndex                 = 3,
		Parent                 = contentArea,
	})
	self.Content = content

	----------------------------------------------------------------
	-- Minimised emblem
	----------------------------------------------------------------
	local emblemButton = new("TextButton", {
		Name            = "SpiderEmblem",
		AnchorPoint     = Vector2.new(0, 0),
		Position        = cfg.EmblemPosition or UDim2.new(0, 24, 0, 120),
		Size            = UDim2.fromOffset(52, 52),
		Text            = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Visible         = false,
		Active          = true,
		ZIndex          = 20,
		Parent          = gui,
	})
	corner(emblemButton, 26)
	paint(self, emblemButton, "BackgroundColor3", "Surface")
	local emblemStroke = new("UIStroke", { Thickness = 1.5, Transparency = 0.15, Parent = emblemButton })
	paint(self, emblemStroke, "Color", "Accent")
	self.Emblem = emblemButton
	self.EmblemScale = new("UIScale", { Scale = 1, Parent = emblemButton })

	local emblemInner = new("Frame", {
		AnchorPoint            = Vector2.new(0.5, 0.5),
		Position               = UDim2.fromScale(0.5, 0.5),
		Size                   = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		ZIndex                 = 21,
		Parent                 = emblemButton,
	})
	buildSpider(self, emblemInner, 30, "Accent", 21)
	makeDraggable(emblemButton, emblemButton)

	do
		-- Click to restore, drag to reposition: separate the two by distance.
		local pressPosition, moved
		emblemButton.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				pressPosition, moved = input.Position, false
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if pressPosition and (input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch) then
				if (input.Position - pressPosition).Magnitude > 6 then moved = true end
			end
		end)
		emblemButton.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				if pressPosition and not moved then
					emblemButton.Visible = false
					self:Toggle(true)
				end
				pressPosition = nil
			end
		end)
	end

	----------------------------------------------------------------
	-- Behaviour
	----------------------------------------------------------------
	local toggleKey = cfg.ToggleKey or Enum.KeyCode.RightControl
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == toggleKey then
			if self.Visible then
				self:Toggle(false)
			else
				emblemButton.Visible = false
				self:Toggle(true)
			end
		end
	end)

	-- The spider-sense idle pulse on the title emblem.
	task.spawn(function()
		while gui.Parent do
			task.wait(4)
			if self.Visible and emblemHolder.Parent then
				spiderSense(self, emblemHolder)
			end
		end
	end)

	-- Entrance: snap in like the window was pulled by a web line.
	root.Visible = true
	self.Scale.Scale = self.BaseScale * 0.86
	root.BackgroundTransparency = 1
	tween(self.Scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = self.BaseScale,
	})
	tween(root, TI.Slow, { BackgroundTransparency = 0 })

	SpiderUI.Windows[#SpiderUI.Windows + 1] = self
	return self
end

----------------------------------------------------------------------
-- NOTIFICATIONS
----------------------------------------------------------------------

function SpiderUI:Notify(cfg, window)
	cfg = cfg or {}
	window = window or SpiderUI.Windows[1]
	local theme = window and window.Theme or Themes.Classic

	if not SpiderUI._notifyGui or not SpiderUI._notifyGui.Parent then
		local gui = new("ScreenGui", {
			Name           = "SpiderUINotifications",
			ResetOnSpawn   = false,
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder   = 1000,
		})
		safeParent(gui)

		local holder = new("Frame", {
			AnchorPoint            = Vector2.new(1, 1),
			Position               = UDim2.new(1, -18, 1, -18),
			Size                   = UDim2.fromOffset(280, 400),
			BackgroundTransparency = 1,
			Parent                 = gui,
		})
		new("UIListLayout", {
			Padding             = UDim.new(0, 8),
			SortOrder           = Enum.SortOrder.LayoutOrder,
			VerticalAlignment   = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Parent              = holder,
		})

		SpiderUI._notifyGui = gui
		SpiderUI._notifyHolder = holder
	end

	local card = new("Frame", {
		Size             = UDim2.new(1, 0, 0, 62),
		BackgroundColor3 = theme.Surface,
		BorderSizePixel  = 0,
		ClipsDescendants = true,
		Parent           = SpiderUI._notifyHolder,
	})
	corner(card, 10)
	new("UIStroke", { Color = theme.Stroke, Thickness = 1, Transparency = 0.35, Parent = card })

	local spider = new("Frame", {
		AnchorPoint            = Vector2.new(0, 0.5),
		Position               = UDim2.new(0, 14, 0.5, 0),
		Size                   = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		Parent                 = card,
	})
	buildSpider(window, spider, 24, "Accent", 3)

	new("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 48, 0, 12),
		Size                   = UDim2.new(1, -60, 0, 16),
		Font                   = Enum.Font.GothamBold,
		Text                   = cfg.Title or "SPIDER-SENSE",
		TextColor3             = theme.Text,
		TextSize               = 12,
		TextXAlignment         = Enum.TextXAlignment.Left,
		Parent                 = card,
	})

	new("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 48, 0, 30),
		Size                   = UDim2.new(1, -60, 0, 22),
		Font                   = Enum.Font.Gotham,
		Text                   = cfg.Text or "",
		TextColor3             = theme.SubText,
		TextSize               = 11,
		TextXAlignment         = Enum.TextXAlignment.Left,
		TextYAlignment         = Enum.TextYAlignment.Top,
		TextWrapped            = true,
		Parent                 = card,
	})

	-- Countdown bar along the bottom edge.
	local duration = cfg.Duration or 4
	local timer = new("Frame", {
		AnchorPoint      = Vector2.new(0, 1),
		Position         = UDim2.new(0, 0, 1, 0),
		Size             = UDim2.fromScale(1, 0),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel  = 0,
		Parent           = card,
	})
	timer.Size = UDim2.new(1, 0, 0, 2)
	tween(timer, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) })

	card.Position = UDim2.fromOffset(320, 0)
	tween(card, TI.Swing, { Position = UDim2.fromOffset(0, 0) })

	task.delay(duration, function()
		tween(card, TI.Sway, { Position = UDim2.fromOffset(320, 0) })
		task.delay(0.3, function() card:Destroy() end)
	end)

	return card
end

function SpiderUI:DestroyAll()
	for _, window in ipairs(SpiderUI.Windows) do
		pcall(function() window:Destroy() end)
	end
	SpiderUI.Windows = {}
	if SpiderUI._notifyGui then SpiderUI._notifyGui:Destroy() end
end

return SpiderUI
