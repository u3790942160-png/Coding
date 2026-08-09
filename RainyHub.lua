--[[
	═══════════════════════════════════════════════════════════════
	  R A I N Y   H U B
	  Rainy-themed interface — storm backdrop, live rainfall,
	  and a procedurally drawn blue skull in the sidebar.
	═══════════════════════════════════════════════════════════════
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

-- Tear down any previous instance of the hub before rebuilding.
if _G.RainyHubCleanup then pcall(_G.RainyHubCleanup) end
for _, oldName in ipairs({"RainyHub", "RainyHubMobile"}) do
	local old = PlayerGui:FindFirstChild(oldName)
	if old then old:Destroy() end
end

local RH = {
	Flags = {},      -- boolean feature switches
	Values = {},     -- numeric / string settings
	Keys = {},       -- keybinds
	Speeds = {},     -- speed presets
	Refs = {},       -- instance references
	Conns = {},      -- connections owned by this session
	Visuals = {},    -- setter callbacks so state changes repaint the UI
	Hooks = {},      -- external logic bound to a flag, see RH.Hook below
}
_G.RainyHub = RH

-- Bind your own logic to any switch in the interface:
--   RH.Hook("autoSwing", function(on) ... end)
-- The callback fires whenever that switch changes, and once immediately
-- with the value restored from the saved config.
function RH.Hook(flagName, callback)
	RH.Hooks[flagName] = callback
	if RH.Flags[flagName] ~= nil then
		task.spawn(function() pcall(callback, RH.Flags[flagName]) end)
	end
end

local function track(conn)
	table.insert(RH.Conns, conn)
	return conn
end

_G.RainyHubCleanup = function()
	for _, conn in ipairs(RH.Conns or {}) do
		pcall(function() conn:Disconnect() end)
	end
	RH.Conns = {}
	RH.Dead = true
end

-- ═══════════════════════════════════════════════════════════════
-- THEME — cold rain palette
-- ═══════════════════════════════════════════════════════════════
local THEME = {
	bg          = Color3.fromRGB(6, 10, 20),
	panel       = Color3.fromRGB(9, 15, 28),
	card        = Color3.fromRGB(13, 21, 38),
	sidebar     = Color3.fromRGB(5, 9, 18),
	accent      = Color3.fromRGB(56, 138, 255),
	accentDim   = Color3.fromRGB(26, 74, 152),
	accentGlow  = Color3.fromRGB(126, 186, 255),
	bone        = Color3.fromRGB(92, 162, 255),
	boneCore    = Color3.fromRGB(190, 224, 255),
	boneDeep    = Color3.fromRGB(28, 70, 148),
	rain        = Color3.fromRGB(158, 202, 255),
	white       = Color3.fromRGB(240, 246, 255),
	text        = Color3.fromRGB(226, 234, 248),
	textDim     = Color3.fromRGB(136, 156, 188),
	stroke      = Color3.fromRGB(40, 66, 110),
	strokeSoft  = Color3.fromRGB(23, 39, 70),
	toggleOff   = Color3.fromRGB(60, 68, 84),
	knob        = Color3.fromRGB(236, 243, 255),
	good        = Color3.fromRGB(64, 214, 132),
}

local WIN_W, WIN_H = 560, 580
local SIDE_W = 206
local FULL_SIZE = UDim2.new(0, WIN_W, 0, WIN_H)

-- ═══════════════════════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════════════════════
local CONFIG_FILE = "RainyHub_config.json"

RH.Flags = {
	autoCarrySpeed    = false,
	autoBypassOnSteal = true,
	infJump           = true,
	autoLaggerSpeed   = true,
	antiBodylock      = false,
	noClip            = false,
	aimbot            = false,
	targetHighlight   = false,
	autoSwing         = false,
	batCounter        = false,
	autoResetOnMed    = false,
	playerESP         = false,
	tracers           = false,
	stormFlashes      = true,
	skullGlow          = true,
	rainOnHud         = true,
	customAnims       = false,
	ragdollCountdown  = false,
}

RH.Values = {
	carryVersion   = "v1",
	rainIntensity  = "Heavy",
	windowOpacity  = "Solid",
	aimbotSpeed    = 58,
	stealRadius    = 62,
	fov            = 70,
	animPack       = "OFF",
	animSpeed      = 1,
	accentName     = "Storm",
}

RH.Keys = {
	carrySpeed   = "Mouse3",
	tpDown       = "E",
	aimbot       = "Q",
	instantReset = "T",
	toggleUI     = "LeftControl",
}

RH.Speeds = {
	{name = "Normal Speed", key = "Four",  walk = 61, carry = 28, locked = true},
	{name = "Lagger Speed", key = "Three", walk = 35, carry = 23, locked = true},
}
RH.ActiveSpeed = 1

local function saveConfig()
	if not (writefile and HttpService) then return end
	pcall(function()
		writefile(CONFIG_FILE, HttpService:JSONEncode({
			flags  = RH.Flags,
			values = RH.Values,
			keys   = RH.Keys,
			speeds = RH.Speeds,
			active = RH.ActiveSpeed,
			speedOn = RH.SpeedOn == true,
			pos    = RH.SavedPos,
		}))
	end)
end
RH.Save = saveConfig

do
	local ok, data = pcall(function()
		if isfile and readfile and isfile(CONFIG_FILE) then
			return HttpService:JSONDecode(readfile(CONFIG_FILE))
		end
	end)
	if ok and type(data) == "table" then
		for k, v in pairs(data.flags or {}) do
			if RH.Flags[k] ~= nil then RH.Flags[k] = v == true end
		end
		for k, v in pairs(data.values or {}) do
			if RH.Values[k] ~= nil then RH.Values[k] = v end
		end
		for k, v in pairs(data.keys or {}) do
			if RH.Keys[k] ~= nil then RH.Keys[k] = tostring(v) end
		end
		if type(data.speeds) == "table" and #data.speeds > 0 then
			RH.Speeds = {}
			for _, s in ipairs(data.speeds) do
				table.insert(RH.Speeds, {
					name   = tostring(s.name or "Custom Speed"),
					key    = tostring(s.key or "None"),
					walk   = tonumber(s.walk) or 16,
					carry  = tonumber(s.carry) or 16,
					locked = s.locked == true,
				})
			end
		end
		RH.ActiveSpeed = math.clamp(tonumber(data.active) or 1, 1, #RH.Speeds)
		RH.SpeedOn = data.speedOn == true
		RH.SavedPos = data.pos
	end
end

-- ═══════════════════════════════════════════════════════════════
-- BUILD HELPERS
-- ═══════════════════════════════════════════════════════════════
local function corner(obj, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = obj
	return c
end

local function stroke(obj, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color or THEME.stroke
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.35
	s.Parent = obj
	return s
end

local function gradient(obj, c1, c2, rotation, t1, t2)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = rotation or 90
	if t1 or t2 then
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, t1 or 0),
			NumberSequenceKeypoint.new(1, t2 or 0),
		})
	end
	g.Parent = obj
	return g
end

local function tween(obj, props, time, style)
	return TweenService:Create(
		obj,
		TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	):Play()
end

local function newFrame(parent, size, position, color, z)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Size = size
	f.Position = position or UDim2.new(0, 0, 0, 0)
	f.BackgroundColor3 = color or THEME.card
	f.ZIndex = z or 2
	f.Parent = parent
	return f
end

local function newLabel(parent, text, size, position, textSize, color, font, z)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.Size = size
	l.Position = position or UDim2.new(0, 0, 0, 0)
	l.TextSize = textSize or 13
	l.TextColor3 = color or THEME.text
	l.Font = font or Enum.Font.GothamSemibold
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.ZIndex = z or 4
	l.Parent = parent
	return l
end

local rng = Random.new(tick())

-- ═══════════════════════════════════════════════════════════════
-- ROOT
-- ═══════════════════════════════════════════════════════════════
local Gui = Instance.new("ScreenGui")
Gui.Name = "RainyHub"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.DisplayOrder = 999
Gui.Parent = PlayerGui
RH.Refs.Gui = Gui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.AnchorPoint = Vector2.new(0, 0.5)
Main.Size = FULL_SIZE
Main.Position = UDim2.new(0, 26, 0.5, 0)
if type(RH.SavedPos) == "table" and RH.SavedPos.xo then
	Main.Position = UDim2.new(RH.SavedPos.xs or 0, RH.SavedPos.xo, RH.SavedPos.ys or 0.5, RH.SavedPos.yo or 0)
end
Main.BackgroundColor3 = THEME.bg
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = Gui
corner(Main, 16)
RH.Refs.Main = Main

do
	local outline = stroke(Main, THEME.accent, 1.6, 0.15)
	local og = Instance.new("UIGradient")
	og.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.accentGlow),
		ColorSequenceKeypoint.new(0.5, THEME.accent),
		ColorSequenceKeypoint.new(1, THEME.accentGlow),
	})
	og.Rotation = 90
	og.Parent = outline
	RH.Refs.Outline = outline
end

-- Storm sky behind everything: dark blue vertical wash.
do
	local sky = newFrame(Main, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(10, 17, 34), 1)
	corner(sky, 16)
	gradient(sky, Color3.fromRGB(15, 26, 52), Color3.fromRGB(4, 7, 15), 90)
	RH.Refs.Sky = sky

	-- Slow-drifting cloud bands.
	for i = 1, 5 do
		local band = newFrame(
			Main,
			UDim2.new(1.6, 0, 0, rng:NextInteger(40, 90)),
			UDim2.new(0, -rng:NextInteger(0, 200), 0, rng:NextInteger(-20, WIN_H - 60)),
			Color3.fromRGB(28, 44, 84),
			1
		)
		band.BackgroundTransparency = rng:NextNumber(0.86, 0.94)
		corner(band, 40)
		local drift = rng:NextNumber(9, 20)
		local dir = (i % 2 == 0) and 1 or -1
		task.spawn(function()
			while not RH.Dead and band.Parent do
				local target = band.Position.X.Offset + dir * rng:NextInteger(60, 140)
				tween(band, {Position = UDim2.new(band.Position.X.Scale, target, band.Position.Y.Scale, band.Position.Y.Offset)}, drift, Enum.EasingStyle.Sine)
				task.wait(drift)
				dir = -dir
			end
		end)
	end
end

-- ═══════════════════════════════════════════════════════════════
-- RAINFALL ENGINE
-- ═══════════════════════════════════════════════════════════════
local RainLayer = newFrame(Main, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), THEME.bg, 3)
RainLayer.Name = "Rainfall"
RainLayer.BackgroundTransparency = 1
RainLayer.ClipsDescendants = true
corner(RainLayer, 16)
RH.Refs.RainLayer = RainLayer

local INTENSITY = {
	Light  = {count = 26, speed = 380, tilt = 8,  alpha = 0.72},
	Medium = {count = 48, speed = 480, tilt = 10, alpha = 0.62},
	Heavy  = {count = 78, speed = 620, tilt = 13, alpha = 0.54},
	Storm  = {count = 118, speed = 780, tilt = 17, alpha = 0.46},
}

RH.Drops = {}

local function resetDrop(d, spawnAbove)
	local cfg = INTENSITY[RH.Values.rainIntensity] or INTENSITY.Heavy
	d.x = rng:NextNumber(-40, WIN_W + 20)
	-- on first fill scatter drops through the window so it is already raining
	d.y = spawnAbove and rng:NextNumber(-260, -8) or rng:NextNumber(-WIN_H, WIN_H)
	d.len = rng:NextInteger(12, 30)
	d.vy = cfg.speed * rng:NextNumber(0.75, 1.35)
	d.vx = math.tan(math.rad(cfg.tilt)) * d.vy
	d.frame.Size = UDim2.new(0, rng:NextNumber(0.9, 2.1), 0, d.len)
	d.frame.Rotation = cfg.tilt
	d.frame.BackgroundTransparency = cfg.alpha + rng:NextNumber(-0.1, 0.18)
end

local function buildRain()
	for _, d in ipairs(RH.Drops) do
		if d.frame then d.frame:Destroy() end
	end
	RH.Drops = {}
	local cfg = INTENSITY[RH.Values.rainIntensity] or INTENSITY.Heavy
	for _ = 1, cfg.count do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = THEME.rain
		f.AnchorPoint = Vector2.new(0.5, 0)
		f.ZIndex = 9
		f.Parent = RainLayer
		corner(f, 2)
		local d = {frame = f}
		resetDrop(d, false)
		f.Position = UDim2.new(0, d.x, 0, d.y)
		table.insert(RH.Drops, d)
	end
end
RH.BuildRain = buildRain
buildRain()

-- Splash ripples pooling along the bottom edge.
local function splash(x, y)
	local r = Instance.new("Frame")
	r.BorderSizePixel = 0
	r.BackgroundTransparency = 1
	r.BackgroundColor3 = THEME.rain
	r.AnchorPoint = Vector2.new(0.5, 0.5)
	r.Size = UDim2.new(0, 3, 0, 2)
	r.Position = UDim2.new(0, x, 0, y)
	r.ZIndex = 9
	r.Parent = RainLayer
	corner(r, 999)
	local rs = stroke(r, THEME.accentGlow, 1, 0.35)
	tween(r, {Size = UDim2.new(0, rng:NextInteger(18, 34), 0, rng:NextInteger(5, 10))}, 0.45)
	tween(rs, {Transparency = 1}, 0.45)
	task.delay(0.5, function()
		if r and r.Parent then r:Destroy() end
	end)
end

local splashAccum = 0
track(RunService.RenderStepped:Connect(function(dt)
	if RH.Dead then return end
	if not RH.Flags.rainOnHud then return end
	if not Main.Visible then return end
	dt = math.min(dt, 0.05)
	for _, d in ipairs(RH.Drops) do
		d.y = d.y + d.vy * dt
		d.x = d.x + d.vx * dt
		if d.y > WIN_H + 24 or d.x > WIN_W + 60 then
			resetDrop(d, true)
		end
		d.frame.Position = UDim2.new(0, d.x, 0, d.y)
	end
	splashAccum = splashAccum + dt
	local cfg = INTENSITY[RH.Values.rainIntensity] or INTENSITY.Heavy
	local every = 0.42 - (cfg.count / 400)
	if splashAccum >= every then
		splashAccum = 0
		splash(rng:NextInteger(12, WIN_W - 12), rng:NextInteger(WIN_H - 46, WIN_H - 8))
	end
end))

-- A thin layer of rain in FRONT of everything. The main rainfall sits
-- behind the sidebar and the content rows, so without this the window
-- never actually looks rained on.
do
	local front = newFrame(Main, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), THEME.bg, 35)
	front.Name = "RainfallFront"
	front.BackgroundTransparency = 1
	front.ClipsDescendants = true
	corner(front, 16)
	RH.Refs.RainFront = front

	local drops = {}
	for _ = 1, 18 do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = THEME.rain
		f.BackgroundTransparency = 0.78
		f.AnchorPoint = Vector2.new(0.5, 0)
		f.Size = UDim2.new(0, 2.6, 0, rng:NextInteger(34, 64))
		f.Rotation = 14
		f.ZIndex = 36
		f.Parent = front
		corner(f, 2)
		table.insert(drops, {
			frame = f,
			x = rng:NextNumber(-40, WIN_W),
			y = rng:NextNumber(-WIN_H, WIN_H),
			vy = rng:NextNumber(1100, 1800),
		})
	end
	track(RunService.RenderStepped:Connect(function(dt)
		if RH.Dead or not RH.Flags.rainOnHud or not Main.Visible then return end
		dt = math.min(dt, 0.05)
		for _, d in ipairs(drops) do
			d.y = d.y + d.vy * dt
			d.x = d.x + d.vy * 0.25 * dt
			if d.y > WIN_H + 30 or d.x > WIN_W + 40 then
				d.y = rng:NextNumber(-200, -30)
				d.x = rng:NextNumber(-60, WIN_W)
				d.vy = rng:NextNumber(1100, 1800)
			end
			d.frame.Position = UDim2.new(0, d.x, 0, d.y)
		end
	end))
end

-- Wet glass sheen across the whole window.
do
	local sheen = newFrame(Main, UDim2.new(1, 0, 0, 120), UDim2.new(0, 0, 1, -120), Color3.fromRGB(20, 44, 92), 3)
	sheen.BackgroundTransparency = 0.82
	gradient(sheen, Color3.fromRGB(40, 84, 160), Color3.fromRGB(6, 12, 26), 90, 1, 0.55)
end

-- ═══════════════════════════════════════════════════════════════
-- LIGHTNING / STORM FLASHES
-- ═══════════════════════════════════════════════════════════════
-- ZIndexBehavior is Sibling, so the flash has to out-rank every other
-- child of Main for the strike to wash across the whole window.
local FlashOverlay = newFrame(Main, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(150, 190, 255), 40)
FlashOverlay.Name = "StormFlash"
FlashOverlay.BackgroundTransparency = 1
corner(FlashOverlay, 16)
RH.Refs.Flash = FlashOverlay

local function stormFlash()
	if not RH.Flags.stormFlashes or RH.Dead then return end
	local peak = rng:NextNumber(0.86, 0.94)
	FlashOverlay.BackgroundTransparency = peak
	if RH.Refs.SkullFlash then RH.Refs.SkullFlash.BackgroundTransparency = 0.62 end
	if RH.Refs.Outline then RH.Refs.Outline.Transparency = 0 end
	task.wait(0.05)
	tween(FlashOverlay, {BackgroundTransparency = 1}, 0.12)
	if rng:NextNumber() > 0.45 then
		task.wait(0.09)
		FlashOverlay.BackgroundTransparency = peak + 0.04
		task.wait(0.04)
		tween(FlashOverlay, {BackgroundTransparency = 1}, 0.3)
	end
	if RH.Refs.SkullFlash then tween(RH.Refs.SkullFlash, {BackgroundTransparency = 1}, 0.7) end
	if RH.Refs.Outline then tween(RH.Refs.Outline, {Transparency = 0.15}, 0.7) end
end

task.spawn(function()
	while not RH.Dead do
		task.wait(rng:NextNumber(5, 14))
		pcall(stormFlash)
	end
end)

-- ═══════════════════════════════════════════════════════════════
-- SIDEBAR
-- ═══════════════════════════════════════════════════════════════
local Sidebar = newFrame(Main, UDim2.new(0, SIDE_W, 1, -24), UDim2.new(0, 12, 0, 12), THEME.sidebar, 5)
Sidebar.Name = "Sidebar"
Sidebar.BackgroundTransparency = 0.12
Sidebar.ClipsDescendants = true
corner(Sidebar, 13)
stroke(Sidebar, THEME.stroke, 1.2, 0.4)
RH.Refs.Sidebar = Sidebar

local SIDE_H = WIN_H - 24
local ArtLayer = newFrame(Sidebar, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), THEME.sidebar, 5)
ArtLayer.Name = "SkullArt"
ArtLayer.BackgroundTransparency = 1
ArtLayer.ClipsDescendants = true
corner(ArtLayer, 13)

-- Deep-water wash behind the bones.
do
	local wash = newFrame(ArtLayer, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(11, 22, 46), 5)
	wash.BackgroundTransparency = 0.25
	corner(wash, 13)
	gradient(wash, Color3.fromRGB(18, 38, 78), Color3.fromRGB(4, 8, 18), 90)
end

-- ═══════════════════════════════════════════════════════════════
-- SKULL ART — detailed blue skull, drawn from primitives
-- ═══════════════════════════════════════════════════════════════
local SkullRoot = newFrame(ArtLayer, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), THEME.sidebar, 6)
SkullRoot.Name = "Skull"
SkullRoot.BackgroundTransparency = 1
SkullRoot.ClipsDescendants = true

local CX = SIDE_W / 2

-- The skull is laid out in the sidebar's own 206-wide space.
--
-- The silhouette is one continuous profile — half-width sampled down the
-- skull and stamped as thin overlapping bars — so the cranium, cheeks and
-- jaw come out as a single smooth outline. Everything that reads as
-- structure sits inside that outline: the cheekbone is shading rather
-- than added geometry, because anything protruding out there just looks
-- like an ear. Orbits, nasal aperture, teeth and sutures go on top.
--
-- Each bar carries the same cross-axis light ramp, so the vault reads as
-- domed. It is all opaque and composited by a CanvasGroup, which is what
-- keeps the overlapping pieces from seaming; the group transparency is
-- what makes the skull glassy.

local SKULL_COLORS = {
	fill       = Color3.fromRGB(58, 116, 196),
	light      = Color3.fromRGB(126, 182, 244),
	lighter    = Color3.fromRGB(186, 222, 255),
	shade      = Color3.fromRGB(28, 64, 124),
	deep       = Color3.fromRGB(16, 40, 86),
	socket     = Color3.fromRGB(6, 15, 36),
	socketEdge = Color3.fromRGB(10, 26, 58),
	tooth      = Color3.fromRGB(198, 228, 255),
	toothShade = Color3.fromRGB(116, 162, 218),
	crease     = Color3.fromRGB(12, 32, 72),
	void       = Color3.fromRGB(2, 5, 16),
}

-- dark edge -> lit centre -> darker edge, across the short axis
local BARREL = ColorSequence.new({
	ColorSequenceKeypoint.new(0, SKULL_COLORS.deep),
	ColorSequenceKeypoint.new(0.12, SKULL_COLORS.shade),
	ColorSequenceKeypoint.new(0.30, SKULL_COLORS.fill),
	ColorSequenceKeypoint.new(0.46, SKULL_COLORS.light),
	ColorSequenceKeypoint.new(0.54, SKULL_COLORS.lighter),
	ColorSequenceKeypoint.new(0.72, SKULL_COLORS.fill),
	ColorSequenceKeypoint.new(0.90, SKULL_COLORS.shade),
	ColorSequenceKeypoint.new(1, SKULL_COLORS.deep),
})
local HOLLOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, SKULL_COLORS.socketEdge),
	ColorSequenceKeypoint.new(0.5, SKULL_COLORS.socket),
	ColorSequenceKeypoint.new(1, SKULL_COLORS.socketEdge),
})

-- half-width of the skull at a given y, crown through chin
local SKULL_PROFILE = {
	{61, 9}, {64, 18}, {68, 27}, {72, 35}, {77, 43}, {82, 49}, {88, 55},
	{100, 64}, {112, 69}, {126, 71}, {140, 71}, {152, 69}, {162, 66}, {172, 62},
	{180, 60}, {188, 60}, {196, 62}, {204, 63}, {212, 61}, {220, 56}, {228, 51},
	{236, 46}, {244, 45}, {252, 46}, {262, 45}, {272, 42}, {282, 37}, {290, 30},
	{298, 21}, {304, 11},
}

local ORBIT = {dx = 34, y = 180, w = 44, h = 42, r = 17, rot = 7}

local function skullHalfWidth(y)
	local first, last = SKULL_PROFILE[1], SKULL_PROFILE[#SKULL_PROFILE]
	if y <= first[1] then return first[2] end
	if y >= last[1] then return last[2] end
	for i = 1, #SKULL_PROFILE - 1 do
		local a, b = SKULL_PROFILE[i], SKULL_PROFILE[i + 1]
		if y >= a[1] and y <= b[1] then
			return a[2] + (b[2] - a[2]) * (y - a[1]) / (b[1] - a[1])
		end
	end
	return last[2]
end

local function paint(obj, sequence, rotation)
	local g = Instance.new("UIGradient")
	g.Color = sequence
	g.Rotation = rotation or 0
	g.Parent = obj
	return g
end

local function piece(parent, x, y, w, h, radius, rot, color, transparency, z)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.new(0, w, 0, h)
	f.Position = UDim2.new(0, x, 0, y)
	f.Rotation = rot or 0
	f.BackgroundColor3 = color or SKULL_COLORS.fill
	f.BackgroundTransparency = transparency or 0
	f.ZIndex = z
	f.Parent = parent
	corner(f, radius)
	return f
end

local function boneBar(parent, y, w, h, z, alpha)
	local f = piece(parent, CX, y, w, h, h / 2, 0, SKULL_COLORS.fill, alpha, z)
	paint(f, BARREL, 0)
	return f
end

local function boneBox(parent, x, y, w, h, radius, rot, z, alpha)
	local f = piece(parent, x, y, w, h, radius, rot, SKULL_COLORS.fill, alpha, z)
	paint(f, BARREL, 0)
	return f
end

-- shading blob that fades out along its long axis, so nothing it covers
-- picks up a hard border
local function softShade(parent, x, y, w, h, rot, color, transparency, z)
	local f = piece(parent, x, y, w, h, 999, rot, color, transparency, z)
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
	return f
end

-- hairline that fades out at both ends: sutures, rims, creases
local function hairline(parent, x, y, len, thick, rot, color, transparency, z)
	local f = piece(parent, x, y, len, thick, thick, rot, color, transparency, z)
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.24, 0),
		NumberSequenceKeypoint.new(0.76, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
	return f
end

-- CanvasGroup composites the whole skull as one layer, so overlapping
-- opaque pieces never seam. Older clients without it fall back to a plain
-- Frame, where the transparency has to go on each piece instead.
local function newLayer(parent, name, groupTransparency, z)
	local ok, layer = pcall(function() return Instance.new("CanvasGroup") end)
	if not ok or not layer then
		layer = Instance.new("Frame")
	end
	layer.Name = name
	layer.BackgroundTransparency = 1
	layer.BorderSizePixel = 0
	layer.Size = UDim2.new(1, 0, 1, 0)
	layer.Position = UDim2.new(0, 0, 0, 0)
	layer.ZIndex = z
	layer.Parent = parent
	local grouped = layer:IsA("CanvasGroup")
	if grouped then
		layer.GroupTransparency = groupTransparency
	end
	return layer, grouped
end

local function buildSkull()
	SkullRoot:ClearAllChildren()

	-- halo behind the skull
	if RH.Flags.skullGlow then
		local bloom = newFrame(SkullRoot, UDim2.new(0, 182, 0, 300), UDim2.new(0, 12, 0, 44), THEME.accent, 5)
		bloom.BackgroundTransparency = 0.86
		corner(bloom, 91)
		gradient(bloom, THEME.accentGlow, THEME.accent, 90, 0.62, 1)

		local halo, grouped = newLayer(SkullRoot, "SkullHalo", 0.5, 6)
		RH.Refs.SkullHalo = grouped and halo or nil
		local haloAlpha = grouped and 0 or 0.6
		for y = 61, 305, 4 do
			piece(halo, CX, y, skullHalfWidth(y) * 2 + 7, 10, 5, 0, THEME.accent, haloAlpha, 6)
		end
	else
		RH.Refs.SkullHalo = nil
	end

	local body, grouped = newLayer(SkullRoot, "SkullBody", 0.26, 8)
	local a = grouped and 0 or 0.26

	-- ── silhouette ────────────────────────────────────────────────
	for y = 61, 305, 2 do
		boneBar(body, y, skullHalfWidth(y) * 2, 6, 8, a)
	end
	-- brow ridges standing proud over each orbit, glabella between them
	for _, s in ipairs({-1, 1}) do
		boneBox(body, CX + s * 33, 159, 54, 16, 8, s * -6, 9, a)
	end
	boneBox(body, CX, 163, 20, 14, 7, 0, 9, a)

	-- ── form shading ──────────────────────────────────────────────
	softShade(body, CX - 26, 106, 70, 78, 0, SKULL_COLORS.light, 0.66, 10)   -- frontal highlight
	softShade(body, CX + 46, 128, 44, 100, 0, SKULL_COLORS.shade, 0.6, 10)   -- far side of the vault
	softShade(body, CX - 58, 172, 32, 46, 0, SKULL_COLORS.shade, 0.5, 10)    -- temporal fossa
	softShade(body, CX + 58, 172, 32, 46, 0, SKULL_COLORS.shade, 0.42, 10)
	softShade(body, CX - 62, 204, 20, 34, 0, SKULL_COLORS.shade, 0.5, 10)    -- hollow behind the arch
	softShade(body, CX + 62, 204, 20, 34, 0, SKULL_COLORS.shade, 0.45, 10)
	softShade(body, CX, 210, 46, 30, 0, SKULL_COLORS.shade, 0.58, 10)        -- under the nasal root
	softShade(body, CX, 244, 84, 22, 0, SKULL_COLORS.shade, 0.6, 10)         -- above the tooth row
	softShade(body, CX, 286, 60, 32, 0, SKULL_COLORS.light, 0.68, 10)        -- chin catch
	softShade(body, CX, 302, 70, 22, 0, SKULL_COLORS.shade, 0.55, 10)        -- jaw falls away
	-- cheekbones: read as light and shadow, never as extra geometry
	softShade(body, CX - 45, 199, 42, 20, -20, SKULL_COLORS.lighter, 0.55, 10)
	softShade(body, CX + 45, 199, 42, 20, 20, SKULL_COLORS.light, 0.66, 10)
	for _, s in ipairs({-1, 1}) do
		softShade(body, CX + s * 44, 214, 40, 16, s * 16, SKULL_COLORS.shade, 0.5, 10)
		hairline(body, CX + s * 44, 208, 40, 2, s * -16, SKULL_COLORS.lighter, 0.7, 10)
	end

	-- ── orbits ────────────────────────────────────────────────────
	for _, s in ipairs({-1, 1}) do
		local ox = CX + s * ORBIT.dx
		piece(body, ox, ORBIT.y, ORBIT.w, ORBIT.h, ORBIT.r, s * ORBIT.rot, SKULL_COLORS.socketEdge, 0, 11)
		local inner = piece(body, ox + s * 1.5, ORBIT.y + 2, ORBIT.w - 8, ORBIT.h - 8,
			ORBIT.r - 4, s * ORBIT.rot, SKULL_COLORS.socket, 0, 12)
		paint(inner, HOLLOW, 120)
		softShade(body, ox - s * 8, ORBIT.y + 8, 14, 12, 0, SKULL_COLORS.void, 0.3, 13) -- optic canal
		-- lit rims: bright along the top, softer down the outer edge
		hairline(body, ox, ORBIT.y - ORBIT.h / 2 + 1.5, ORBIT.w - 8, 2.4, s * ORBIT.rot, SKULL_COLORS.lighter, 0.55, 13)
		hairline(body, ox + s * (ORBIT.w / 2 - 2), ORBIT.y + 3, ORBIT.h - 14, 2.2, 90 + s * ORBIT.rot, SKULL_COLORS.light, 0.7, 13)
		hairline(body, ox, ORBIT.y + ORBIT.h / 2 - 1, ORBIT.w - 14, 1.8, s * ORBIT.rot, SKULL_COLORS.light, 0.78, 13)
		softShade(body, ox - s * 7, ORBIT.y - ORBIT.h / 2 + 2, 8, 5, 0, SKULL_COLORS.crease, 0.55, 13) -- supraorbital notch
		softShade(body, ox + s * 2, ORBIT.y + ORBIT.h / 2 + 9, 6, 5, 0, SKULL_COLORS.crease, 0.5, 13)  -- infraorbital foramen
	end

	-- ── nasal aperture ────────────────────────────────────────────
	for y = 198, 236, 2 do
		local t = (y - 198) / 38
		local w = 6 + 24 * (t ^ 1.8)
		local n = piece(body, CX, y, w, 5, 2.5, 0, SKULL_COLORS.socket, 0, 12)
		paint(n, HOLLOW, 0)
	end
	hairline(body, CX, 222, 20, 2.2, 90, SKULL_COLORS.light, 0.74, 13)      -- vomer
	for _, s in ipairs({-1, 1}) do
		hairline(body, CX + s * 7, 200, 16, 2, s * 74, SKULL_COLORS.lighter, 0.7, 13) -- nasal bones
	end
	piece(body, CX, 240, 10, 7, 3, 0, SKULL_COLORS.lighter, 0.5, 13)        -- nasal spine

	-- ── teeth ─────────────────────────────────────────────────────
	local UPPER = {-31, -23.5, -16, -8.5, -1.5, 5.5, 13, 20.5, 28, 34.5}
	local LOWER = {-29, -22, -15, -8, -1.5, 5, 12, 19, 26, 32}
	local function toothRow(row, yBase, heightAtCentre, upper)
		for _, dx in ipairs(row) do
			local k = math.abs(dx) / 32
			local t = piece(body, CX + dx, yBase - k * k * 3.5,
				8.6 - k * 3.0, heightAtCentre - k * 4, 3, dx * 0.16,
				SKULL_COLORS.tooth, k * 0.35, 13)
			paint(t, ColorSequence.new(
				upper and SKULL_COLORS.tooth or SKULL_COLORS.toothShade,
				upper and SKULL_COLORS.toothShade or SKULL_COLORS.tooth
			), 90)
		end
	end
	toothRow(UPPER, 251, 15, true)
	toothRow(LOWER, 266, 13, false)
	hairline(body, CX + 1, 258.5, 70, 2.4, 0, SKULL_COLORS.crease, 0.45, 14) -- bite line

	-- ── sutures and fine detail ───────────────────────────────────
	for i = 0, 16 do
		local t = i / 16
		local x = CX - 60 + t * 120
		local y = 110 + ((math.abs(t - 0.5) * 2) ^ 2) * 18 + (i % 2 == 1 and 1.4 or -1.4)
		hairline(body, x, y, 10, 1.7, (t - 0.5) * 52, SKULL_COLORS.crease, 0.6, 13)
	end
	hairline(body, CX, 86, 40, 1.7, 90, SKULL_COLORS.crease, 0.7, 13)        -- sagittal
	for _, s in ipairs({-1, 1}) do
		hairline(body, CX + s * 55, 148, 44, 1.7, s * 60, SKULL_COLORS.crease, 0.7, 13)  -- temporal line
		hairline(body, CX + s * 60, 184, 28, 1.6, s * 14, SKULL_COLORS.crease, 0.74, 13) -- squamosal
		hairline(body, CX + s * 40, 228, 24, 1.6, s * 66, SKULL_COLORS.crease, 0.76, 13) -- zygomaticomaxillary
		hairline(body, CX + s * 41, 258, 42, 1.8, s * 66, SKULL_COLORS.crease, 0.7, 13)  -- jaw line
		softShade(body, CX + s * 26, 282, 7, 6, 0, SKULL_COLORS.crease, 0.55, 13)        -- mental foramen
	end
	hairline(body, CX, 292, 20, 1.8, 90, SKULL_COLORS.crease, 0.72, 13)      -- mental symphysis
end
RH.BuildSkull = buildSkull
buildSkull()

-- Bloom over the skull that flares with the storm.
local SkullFlash = newFrame(ArtLayer, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), THEME.accentGlow, 14)
SkullFlash.Name = "SkullFlash"
SkullFlash.BackgroundTransparency = 1
corner(SkullFlash, 13)
RH.Refs.SkullFlash = SkullFlash

-- Slow breathing pulse on the glow behind the skull.
task.spawn(function()
	local up = true
	while not RH.Dead do
		local halo = RH.Refs.SkullHalo
		if halo and halo.Parent then
			tween(halo, {GroupTransparency = up and 0.4 or 0.62}, 1.9, Enum.EasingStyle.Sine)
		end
		up = not up
		task.wait(2)
	end
end)

-- Foreground rain inside the sidebar for parallax depth.
do
	local sideRain = newFrame(ArtLayer, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), THEME.sidebar, 15)
	sideRain.BackgroundTransparency = 1
	sideRain.ClipsDescendants = true
	corner(sideRain, 13)
	RH.Refs.SideRain = sideRain

	local drops = {}
	for _ = 1, 16 do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = THEME.rain
		f.BackgroundTransparency = 0.55
		f.AnchorPoint = Vector2.new(0.5, 0)
		f.Size = UDim2.new(0, 2.4, 0, rng:NextInteger(26, 52))
		f.Rotation = 11
		f.ZIndex = 16
		f.Parent = sideRain
		corner(f, 2)
		table.insert(drops, {
			frame = f,
			x = rng:NextNumber(0, SIDE_W),
			y = rng:NextNumber(-SIDE_H, 0),
			vy = rng:NextNumber(900, 1500),
		})
	end
	track(RunService.RenderStepped:Connect(function(dt)
		if RH.Dead or not RH.Flags.rainOnHud or not Main.Visible then return end
		dt = math.min(dt, 0.05)
		for _, d in ipairs(drops) do
			d.y = d.y + d.vy * dt
			d.x = d.x + d.vy * 0.19 * dt
			if d.y > SIDE_H + 20 or d.x > SIDE_W + 20 then
				d.y = rng:NextNumber(-160, -20)
				d.x = rng:NextNumber(-20, SIDE_W)
				d.vy = rng:NextNumber(900, 1500)
			end
			d.frame.Position = UDim2.new(0, d.x, 0, d.y)
		end
	end))

	-- droplets crawling down the glass
	for _ = 1, 5 do
		task.spawn(function()
			while not RH.Dead do
				task.wait(rng:NextNumber(1.5, 6))
				if RH.Flags.rainOnHud then
					local bead = Instance.new("Frame")
					bead.BorderSizePixel = 0
					bead.BackgroundColor3 = THEME.rain
					bead.BackgroundTransparency = 0.42
					bead.AnchorPoint = Vector2.new(0.5, 0)
					bead.Size = UDim2.new(0, rng:NextInteger(3, 6), 0, rng:NextInteger(6, 12))
					bead.Position = UDim2.new(0, rng:NextInteger(10, SIDE_W - 10), 0, -14)
					bead.ZIndex = 17
					bead.Parent = sideRain
					corner(bead, 999)
					local trail = Instance.new("Frame")
					trail.BorderSizePixel = 0
					trail.BackgroundColor3 = THEME.rain
					trail.BackgroundTransparency = 0.86
					trail.AnchorPoint = Vector2.new(0.5, 1)
					trail.Size = UDim2.new(0, 1.4, 0, 0)
					trail.Position = UDim2.new(0.5, 0, 0, 0)
					trail.ZIndex = 16
					trail.Parent = bead
					local dur = rng:NextNumber(2.4, 4.6)
					tween(bead, {Position = UDim2.new(0, bead.Position.X.Offset, 0, SIDE_H + 20)}, dur, Enum.EasingStyle.Quad)
					tween(trail, {Size = UDim2.new(0, 1.4, 0, 70), BackgroundTransparency = 1}, dur)
					task.delay(dur + 0.1, function()
						if bead and bead.Parent then bead:Destroy() end
					end)
				end
			end
		end)
	end
end

-- Vignette so the sidebar text stays readable over the art.
do
	local vig = newFrame(ArtLayer, UDim2.new(1, 0, 0, 150), UDim2.new(0, 0, 0, 0), Color3.fromRGB(3, 6, 14), 18)
	vig.BackgroundTransparency = 0.15
	gradient(vig, Color3.fromRGB(3, 6, 14), Color3.fromRGB(3, 6, 14), 90, 0.05, 1)
	-- kept light so the forearm still glows up through the tab column
	local vig2 = newFrame(ArtLayer, UDim2.new(1, 0, 0, 260), UDim2.new(0, 0, 1, -260), Color3.fromRGB(3, 6, 14), 18)
	vig2.BackgroundTransparency = 0.35
	gradient(vig2, Color3.fromRGB(3, 6, 14), Color3.fromRGB(3, 6, 14), 90, 1, 0.25)
end

-- ═══════════════════════════════════════════════════════════════
-- SIDEBAR HEADER
-- ═══════════════════════════════════════════════════════════════
local TitleLabel = newLabel(Sidebar, "RAINY HUB", UDim2.new(1, -60, 0, 32), UDim2.new(0, 16, 0, 14), 23, THEME.white, Enum.Font.GothamBlack, 22)
TitleLabel.TextStrokeColor3 = Color3.fromRGB(0, 8, 30)
TitleLabel.TextStrokeTransparency = 0.2
RH.Refs.Title = TitleLabel

local StatLabel = newLabel(Sidebar, "FPS: -- | PING: --ms", UDim2.new(1, -34, 0, 18), UDim2.new(0, 17, 0, 47), 13, THEME.accentGlow, Enum.Font.GothamSemibold, 22)
StatLabel.TextStrokeColor3 = Color3.fromRGB(0, 6, 22)
StatLabel.TextStrokeTransparency = 0.35

local MiniBtn = Instance.new("TextButton")
MiniBtn.Name = "Minimize"
MiniBtn.Size = UDim2.new(0, 30, 0, 27)
MiniBtn.Position = UDim2.new(1, -42, 0, 15)
MiniBtn.BackgroundColor3 = Color3.fromRGB(10, 18, 34)
MiniBtn.BackgroundTransparency = 0.2
MiniBtn.Text = "-"
MiniBtn.TextColor3 = THEME.white
MiniBtn.TextSize = 22
MiniBtn.Font = Enum.Font.GothamBold
MiniBtn.AutoButtonColor = false
MiniBtn.ZIndex = 23
MiniBtn.Parent = Sidebar
corner(MiniBtn, 8)
stroke(MiniBtn, THEME.stroke, 1, 0.35)

-- ═══════════════════════════════════════════════════════════════
-- TABS
-- ═══════════════════════════════════════════════════════════════
local TAB_NAMES = {"Movement", "Combat", "Visuals", "Animations"}
local TabHolder = newFrame(Sidebar, UDim2.new(1, -28, 0, 165), UDim2.new(0, 14, 0, 330), THEME.sidebar, 20)
TabHolder.BackgroundTransparency = 1
do
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 7)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = TabHolder
end

local Pages = {}
local TabButtons = {}
RH.ActiveTab = "Movement"

local Content = Instance.new("Frame")
Content.Name = "Content"
Content.BackgroundTransparency = 1
Content.Position = UDim2.new(0, SIDE_W + 26, 0, 16)
Content.Size = UDim2.new(1, -(SIDE_W + 40), 1, -32)
Content.ZIndex = 5
Content.Parent = Main

-- Vertical rain-slick divider between sidebar and content.
do
	local div = newFrame(Main, UDim2.new(0, 1, 1, -60), UDim2.new(0, SIDE_W + 19, 0, 30), THEME.accent, 5)
	div.BackgroundTransparency = 0.55
	gradient(div, THEME.accentGlow, THEME.accent, 90, 1, 0.2)
end

local function addPage(name)
	local page = Instance.new("ScrollingFrame")
	page.Name = name
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 2
	page.ScrollBarImageColor3 = THEME.accent
	page.ScrollBarImageTransparency = 0.4
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Size = UDim2.new(1, 0, 1, 0)
	page.Visible = false
	page.ZIndex = 6
	page.Parent = Content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = page
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.Parent = page
	Pages[name] = page
	return page
end

local function setTab(name)
	RH.ActiveTab = name
	for pageName, page in pairs(Pages) do
		page.Visible = (pageName == name)
	end
	for tabName, btn in pairs(TabButtons) do
		local on = (tabName == name)
		tween(btn, {BackgroundTransparency = on and 0 or 0.62, BackgroundColor3 = on and THEME.accent or THEME.card}, 0.18)
		tween(btn.Label, {TextColor3 = on and THEME.white or THEME.textDim}, 0.18)
		btn.Label.Font = on and Enum.Font.GothamBlack or Enum.Font.GothamSemibold
		local st = btn:FindFirstChildOfClass("UIStroke")
		if st then
			tween(st, {Transparency = on and 0.1 or 0.62}, 0.18)
			st.Color = on and THEME.accentGlow or THEME.stroke
		end
		btn.Glow.Visible = on
	end
end
RH.SetTab = setTab

for i, name in ipairs(TAB_NAMES) do
	addPage(name)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(1, 0, 0, 36)
	btn.BackgroundColor3 = THEME.card
	btn.BackgroundTransparency = 0.62
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.LayoutOrder = i
	btn.ZIndex = 21
	btn.Parent = TabHolder
	corner(btn, 9)
	stroke(btn, THEME.stroke, 1.1, 0.62)

	local glow = newFrame(btn, UDim2.new(0, 3, 0, 18), UDim2.new(0, -1, 0.5, -9), THEME.accentGlow, 22)
	glow.Name = "Glow"
	glow.Visible = false
	corner(glow, 2)

	local label = newLabel(btn, name, UDim2.new(1, -22, 1, 0), UDim2.new(0, 16, 0, 0), 15, THEME.textDim, Enum.Font.GothamSemibold, 23)
	label.Name = "Label"
	label.TextStrokeColor3 = Color3.fromRGB(0, 6, 22)
	label.TextStrokeTransparency = 0.55

	TabButtons[name] = btn
	btn.MouseButton1Click:Connect(function() setTab(name) end)
	btn.MouseEnter:Connect(function()
		if RH.ActiveTab ~= name then tween(btn, {BackgroundTransparency = 0.42}, 0.14) end
	end)
	btn.MouseLeave:Connect(function()
		if RH.ActiveTab ~= name then tween(btn, {BackgroundTransparency = 0.62}, 0.14) end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- STATUS PILL
-- ═══════════════════════════════════════════════════════════════
local Status = newFrame(Sidebar, UDim2.new(1, -28, 0, 38), UDim2.new(0, 14, 1, -52), THEME.card, 20)
Status.BackgroundTransparency = 0.22
corner(Status, 9)
stroke(Status, THEME.stroke, 1.1, 0.45)

local Dot = newFrame(Status, UDim2.new(0, 9, 0, 9), UDim2.new(0, 14, 0.5, -4), THEME.good, 21)
corner(Dot, 999)
local DotGlow = newFrame(Dot, UDim2.new(1, 8, 1, 8), UDim2.new(0.5, 0, 0.5, 0), THEME.good, 20)
DotGlow.AnchorPoint = Vector2.new(0.5, 0.5)
DotGlow.BackgroundTransparency = 0.6
corner(DotGlow, 999)
newLabel(Status, "Connected", UDim2.new(1, -34, 1, 0), UDim2.new(0, 32, 0, 0), 14, THEME.text, Enum.Font.GothamSemibold, 21)

task.spawn(function()
	while not RH.Dead do
		tween(DotGlow, {BackgroundTransparency = 0.9, Size = UDim2.new(1, 16, 1, 16)}, 1.1, Enum.EasingStyle.Sine)
		task.wait(1.15)
		tween(DotGlow, {BackgroundTransparency = 0.55, Size = UDim2.new(1, 6, 1, 6)}, 1.1, Enum.EasingStyle.Sine)
		task.wait(1.15)
	end
end)

-- ═══════════════════════════════════════════════════════════════
-- CONTROL BUILDERS
-- ═══════════════════════════════════════════════════════════════
local function sectionLabel(parent, text, order)
	local l = newLabel(parent, string.upper(text), UDim2.new(1, 0, 0, 20), nil, 12, THEME.accent, Enum.Font.GothamBlack, 6)
	l.LayoutOrder = order or 1
	l.Name = "Section_" .. text
	return l
end

local function divider(parent, order)
	local d = newFrame(parent, UDim2.new(1, -6, 0, 1), nil, THEME.stroke, 6)
	d.BackgroundTransparency = 0.35
	d.LayoutOrder = order or 1
	gradient(d, THEME.accent, THEME.stroke, 0, 0.1, 0.85)
	return d
end

local function baseRow(parent, labelText, order, height)
	local row = newFrame(parent, UDim2.new(1, 0, 0, height or 38), nil, THEME.card, 6)
	row.Name = labelText
	row.BackgroundTransparency = 0.24
	row.LayoutOrder = order or 1
	corner(row, 10)
	local st = stroke(row, THEME.strokeSoft, 1.15, 0.42)

	local label = newLabel(row, labelText, UDim2.new(1, -150, 1, 0), UDim2.new(0, 13, 0, 0), 13.5, THEME.text, Enum.Font.GothamSemibold, 7)
	label.Name = "Label"
	label.TextTruncate = Enum.TextTruncate.AtEnd

	row.MouseEnter:Connect(function()
		if not row:GetAttribute("Selected") then tween(row, {BackgroundTransparency = 0.12}, 0.14) end
	end)
	row.MouseLeave:Connect(function()
		if not row:GetAttribute("Selected") then tween(row, {BackgroundTransparency = 0.24}, 0.14) end
	end)
	return row, label, st
end

local function chipButton(parent, text, width, xOffset, z)
	local b = Instance.new("TextButton")
	b.BorderSizePixel = 0
	b.Size = UDim2.new(0, width, 0, 25)
	b.Position = UDim2.new(1, xOffset, 0.5, -12.5)
	b.BackgroundColor3 = Color3.fromRGB(9, 17, 33)
	b.BackgroundTransparency = 0.1
	b.Text = text
	b.TextColor3 = THEME.text
	b.TextSize = 12
	b.Font = Enum.Font.GothamSemibold
	b.AutoButtonColor = false
	b.ZIndex = z or 8
	b.Parent = parent
	corner(b, 7)
	stroke(b, THEME.stroke, 1, 0.4)
	b.MouseEnter:Connect(function() tween(b, {BackgroundColor3 = THEME.accentDim}, 0.14) end)
	b.MouseLeave:Connect(function() tween(b, {BackgroundColor3 = Color3.fromRGB(9, 17, 33)}, 0.14) end)
	return b
end

local function numberBox(parent, value, width, xOffset, z)
	local box = Instance.new("TextBox")
	box.BorderSizePixel = 0
	box.Size = UDim2.new(0, width, 0, 25)
	box.Position = UDim2.new(1, xOffset, 0.5, -12.5)
	box.BackgroundColor3 = Color3.fromRGB(9, 17, 33)
	box.BackgroundTransparency = 0.1
	box.Text = tostring(value)
	box.TextColor3 = THEME.white
	box.TextSize = 13
	box.Font = Enum.Font.GothamBold
	box.ClearTextOnFocus = false
	box.ZIndex = z or 8
	box.Parent = parent
	corner(box, 7)
	stroke(box, THEME.stroke, 1, 0.4)
	return box
end

local function toggleRow(parent, labelText, flagKey, order, callback)
	local row = baseRow(parent, labelText, order)
	local btn = Instance.new("TextButton")
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.AutoButtonColor = false
	btn.ZIndex = 9
	btn.Parent = row

	local track_ = newFrame(row, UDim2.new(0, 42, 0, 21), UDim2.new(1, -55, 0.5, -10.5), THEME.toggleOff, 8)
	corner(track_, 999)
	local tstroke = stroke(track_, THEME.strokeSoft, 1, 0.45)
	local knob = newFrame(track_, UDim2.new(0, 16, 0, 16), UDim2.new(0, 3, 0.5, -8), THEME.knob, 9)
	corner(knob, 999)

	local function paint(on, instant)
		local t = instant and 0.01 or 0.16
		tween(track_, {BackgroundColor3 = on and THEME.accent or THEME.toggleOff}, t)
		tween(knob, {Position = on and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)}, t)
		tween(tstroke, {Transparency = on and 0.1 or 0.45}, t)
		tstroke.Color = on and THEME.accentGlow or THEME.strokeSoft
		row.Label.TextColor3 = on and THEME.white or THEME.text
		row.Label.Font = on and Enum.Font.GothamBold or Enum.Font.GothamSemibold
	end
	paint(RH.Flags[flagKey] == true, true)

	btn.MouseButton1Click:Connect(function()
		RH.Flags[flagKey] = not (RH.Flags[flagKey] == true)
		paint(RH.Flags[flagKey], false)
		saveConfig()
		if callback then pcall(callback, RH.Flags[flagKey]) end
		if RH.Hooks and RH.Hooks[flagKey] then pcall(RH.Hooks[flagKey], RH.Flags[flagKey]) end
	end)

	RH.Visuals[flagKey] = function(on)
		RH.Flags[flagKey] = on == true
		paint(RH.Flags[flagKey], false)
	end
	return row
end

local function numberRow(parent, labelText, valueKey, order, callback)
	local row = baseRow(parent, labelText, order)
	local box = numberBox(row, RH.Values[valueKey], 58, -70)
	box.FocusLost:Connect(function()
		local n = tonumber(box.Text)
		if n then
			RH.Values[valueKey] = n
			saveConfig()
			if callback then pcall(callback, n) end
		end
		box.Text = tostring(RH.Values[valueKey])
	end)
	return row, box
end

local function cycleRow(parent, labelText, valueKey, options, order, callback)
	local row = baseRow(parent, labelText, order)
	local chip = chipButton(row, tostring(RH.Values[valueKey]), 90, -124)
	chip.TextColor3 = THEME.accentGlow
	chip.Font = Enum.Font.GothamBold
	local function indexOf(v)
		for i, o in ipairs(options) do if o == v then return i end end
		return 1
	end
	local function step(dir)
		local i = indexOf(RH.Values[valueKey]) + dir
		if i > #options then i = 1 elseif i < 1 then i = #options end
		RH.Values[valueKey] = options[i]
		chip.Text = tostring(options[i])
		saveConfig()
		if callback then pcall(callback, options[i]) end
	end
	chip.MouseButton1Click:Connect(function() step(1) end)
	chip.MouseButton2Click:Connect(function() step(-1) end)

	local left = chipButton(row, "<", 22, -150)
	local right = chipButton(row, ">", 22, -30)
	left.MouseButton1Click:Connect(function() step(-1) end)
	right.MouseButton1Click:Connect(function() step(1) end)
	return row, chip
end

-- keybind capture -------------------------------------------------
RH.Capture = nil

local function keyChip(parent, currentKey, xOffset, width, onSet)
	local chip = chipButton(parent, currentKey, width or 64, xOffset)
	local bound = currentKey
	chip.TextColor3 = THEME.accentGlow
	chip.MouseButton1Click:Connect(function()
		if RH.Capture then return end
		chip.Text = "..."
		tween(chip, {BackgroundColor3 = THEME.accentDim}, 0.12)
		RH.Capture = function(keyName)
			tween(chip, {BackgroundColor3 = Color3.fromRGB(9, 17, 33)}, 0.12)
			if keyName then
				bound = keyName
				chip.Text = keyName
				onSet(keyName)
				saveConfig()
			else
				chip.Text = bound -- Escape cancels, keep whatever was bound
			end
		end
	end)
	return chip
end

local function keybindRow(parent, labelText, keyField, order)
	local row = baseRow(parent, labelText, order)
	keyChip(row, RH.Keys[keyField] or "None", -74, 62, function(k)
		RH.Keys[keyField] = k
	end)
	return row
end

local function buttonRow(parent, text, order, callback)
	local b = Instance.new("TextButton")
	b.BorderSizePixel = 0
	b.Size = UDim2.new(1, 0, 0, 36)
	b.BackgroundColor3 = THEME.accentDim
	b.BackgroundTransparency = 0.55
	b.Text = text
	b.TextColor3 = THEME.accentGlow
	b.TextSize = 14
	b.Font = Enum.Font.GothamBold
	b.AutoButtonColor = false
	b.LayoutOrder = order or 1
	b.ZIndex = 7
	b.Parent = parent
	corner(b, 10)
	stroke(b, THEME.accent, 1.1, 0.55)
	b.MouseEnter:Connect(function() tween(b, {BackgroundTransparency = 0.32}, 0.14) end)
	b.MouseLeave:Connect(function() tween(b, {BackgroundTransparency = 0.55}, 0.14) end)
	b.MouseButton1Click:Connect(function()
		if callback then pcall(callback) end
	end)
	return b
end

-- ═══════════════════════════════════════════════════════════════
-- SPEED PRESETS
-- ═══════════════════════════════════════════════════════════════
local MovePage = Pages["Movement"]
sectionLabel(MovePage, "Speed", 1)

local SpeedHolder = newFrame(MovePage, UDim2.new(1, 0, 0, 0), nil, THEME.card, 6)
SpeedHolder.BackgroundTransparency = 1
SpeedHolder.AutomaticSize = Enum.AutomaticSize.Y
SpeedHolder.LayoutOrder = 2
do
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = SpeedHolder
end

local renderSpeeds

local function selectSpeed(index, toggleOff)
	if RH.ActiveSpeed == index and toggleOff then
		RH.SpeedOn = not RH.SpeedOn
	else
		RH.ActiveSpeed = index
		RH.SpeedOn = true
	end
	saveConfig()
	renderSpeeds()
	if RH.ApplySpeed then RH.ApplySpeed() end
end

renderSpeeds = function()
	for _, child in ipairs(SpeedHolder:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	for index, preset in ipairs(RH.Speeds) do
		local custom = not preset.locked
		local row = newFrame(SpeedHolder, UDim2.new(1, 0, 0, 42), nil, THEME.card, 6)
		row.Name = "Preset" .. index
		row.BackgroundTransparency = 0.24
		row.LayoutOrder = index
		corner(row, 10)
		local st = stroke(row, THEME.strokeSoft, 1.2, 0.42)

		local selected = (RH.ActiveSpeed == index) and RH.SpeedOn
		row:SetAttribute("Selected", selected)
		if selected then
			st.Color = THEME.accent
			st.Thickness = 1.9
			st.Transparency = 0.02
			row.BackgroundTransparency = 0.1
		elseif RH.ActiveSpeed == index then
			st.Color = THEME.accentDim
			st.Transparency = 0.25
		end

		local hit = Instance.new("TextButton")
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.Size = UDim2.new(1, 0, 1, 0)
		hit.AutoButtonColor = false
		hit.ZIndex = 7
		hit.Parent = row
		hit.MouseButton1Click:Connect(function() selectSpeed(index, true) end)

		-- custom presets give up 24px on the right for the delete chip
		local shift = custom and -24 or 0
		local nameW = (custom and 115 or 139)
		if custom then
			local nameBox = Instance.new("TextBox")
			nameBox.BackgroundTransparency = 1
			nameBox.Text = preset.name
			nameBox.Size = UDim2.new(0, nameW, 1, 0)
			nameBox.Position = UDim2.new(0, 13, 0, 0)
			nameBox.TextSize = 13.5
			nameBox.TextColor3 = THEME.text
			nameBox.Font = Enum.Font.GothamSemibold
			nameBox.TextXAlignment = Enum.TextXAlignment.Left
			nameBox.ClearTextOnFocus = false
			nameBox.ZIndex = 9
			nameBox.Parent = row
			nameBox.FocusLost:Connect(function()
				preset.name = (nameBox.Text ~= "" and nameBox.Text) or "Custom Speed"
				nameBox.Text = preset.name
				saveConfig()
			end)
		else
			local nl = newLabel(row, preset.name, UDim2.new(0, nameW, 1, 0), UDim2.new(0, 13, 0, 0), 13.5, selected and THEME.white or THEME.text, selected and Enum.Font.GothamBold or Enum.Font.GothamSemibold, 8)
			nl.TextTruncate = Enum.TextTruncate.AtEnd
		end

		keyChip(row, preset.key, -154 + shift, 46, function(k)
			preset.key = k
		end)

		local walkBox = numberBox(row, preset.walk, 44, -102 + shift, 8)
		walkBox.FocusLost:Connect(function()
			preset.walk = tonumber(walkBox.Text) or preset.walk
			walkBox.Text = tostring(preset.walk)
			saveConfig()
			if RH.ApplySpeed then RH.ApplySpeed() end
		end)

		local carryBox = numberBox(row, preset.carry, 44, -52 + shift, 8)
		carryBox.FocusLost:Connect(function()
			preset.carry = tonumber(carryBox.Text) or preset.carry
			carryBox.Text = tostring(preset.carry)
			saveConfig()
			if RH.ApplySpeed then RH.ApplySpeed() end
		end)

		if custom then
			local del = chipButton(row, "X", 20, -28, 9)
			del.TextColor3 = Color3.fromRGB(255, 128, 128)
			del.MouseButton1Click:Connect(function()
				table.remove(RH.Speeds, index)
				if RH.ActiveSpeed > #RH.Speeds then RH.ActiveSpeed = math.max(#RH.Speeds, 1) end
				saveConfig()
				renderSpeeds()
			end)
		end

		row.MouseEnter:Connect(function()
			if not row:GetAttribute("Selected") then tween(row, {BackgroundTransparency = 0.12}, 0.14) end
		end)
		row.MouseLeave:Connect(function()
			if not row:GetAttribute("Selected") then tween(row, {BackgroundTransparency = 0.24}, 0.14) end
		end)
	end
end
renderSpeeds()

buttonRow(MovePage, "+ Add Custom Speed", 3, function()
	table.insert(RH.Speeds, {
		name = "Custom Speed",
		key = "None",
		walk = 45,
		carry = 22,
		locked = false,
	})
	saveConfig()
	renderSpeeds()
end)

-- Carry / steal behaviour ---------------------------------------
toggleRow(MovePage, "Auto Carry Speed", "autoCarrySpeed", 4, function()
	if RH.ApplySpeed then RH.ApplySpeed() end
end)
toggleRow(MovePage, "Auto Bypass On Steal", "autoBypassOnSteal", 5)

do
	local row = baseRow(MovePage, "Carry Speed", 6)
	row.Label.Size = UDim2.new(0, 128, 1, 0)
	local verChip = chipButton(row, RH.Values.carryVersion, 70, -160)
	verChip.TextColor3 = THEME.accentGlow
	verChip.Font = Enum.Font.GothamBold
	local versions = {"v1", "v2", "v3"}
	verChip.MouseButton1Click:Connect(function()
		local i = 1
		for k, v in ipairs(versions) do if v == RH.Values.carryVersion then i = k end end
		i = (i % #versions) + 1
		RH.Values.carryVersion = versions[i]
		verChip.Text = versions[i]
		saveConfig()
	end)
	keyChip(row, RH.Keys.carrySpeed, -84, 72, function(k)
		RH.Keys.carrySpeed = k
	end)
end

divider(MovePage, 7)
sectionLabel(MovePage, "Movement", 8)

-- ═══════════════════════════════════════════════════════════════
-- MOVEMENT FEATURES
-- ═══════════════════════════════════════════════════════════════
local function getHumanoid()
	local char = LP.Character
	return char and char:FindFirstChildOfClass("Humanoid"), char
end

RH.IsCarrying = function()
	local _, char = getHumanoid()
	if not char then return false end
	return char:FindFirstChildOfClass("Tool") ~= nil
end

local DEFAULT_WALKSPEED = 16
RH.SpeedOn = RH.SpeedOn == true

RH.ApplySpeed = function()
	local hum = getHumanoid()
	if not hum then return end
	if not RH.SpeedOn then
		if hum.WalkSpeed ~= DEFAULT_WALKSPEED then hum.WalkSpeed = DEFAULT_WALKSPEED end
		return
	end
	local preset = RH.Speeds[RH.ActiveSpeed] or RH.Speeds[1]
	if not preset then return end
	local carrying = RH.Flags.autoCarrySpeed and RH.IsCarrying()
	local target = carrying and preset.carry or preset.walk
	if math.abs(hum.WalkSpeed - target) > 0.01 then
		hum.WalkSpeed = target
	end
end

task.spawn(function()
	while not RH.Dead do
		pcall(RH.ApplySpeed)
		task.wait(0.3)
	end
end)

toggleRow(MovePage, "Inf Jump", "infJump", 9)
track(UserInputService.JumpRequest:Connect(function()
	if RH.Dead or not RH.Flags.infJump then return end
	local hum = getHumanoid()
	if hum then
		pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
	end
end))

keybindRow(MovePage, "TP Down", "tpDown", 10)

toggleRow(MovePage, "Auto lagger speed", "autoLaggerSpeed", 11)

toggleRow(MovePage, "No Clip", "noClip", 12, function(on)
	if not on then
		local _, char = getHumanoid()
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					pcall(function() part.CanCollide = true end)
				end
			end
		end
	end
end)
track(RunService.Stepped:Connect(function()
	if RH.Dead or not RH.Flags.noClip then return end
	local _, char = getHumanoid()
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			part.CanCollide = false
		end
	end
end))

toggleRow(MovePage, "Anti Bodylock", "antiBodylock", 13)
task.spawn(function()
	while not RH.Dead do
		if RH.Flags.antiBodylock then
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LP and plr.Character then
					for _, part in ipairs(plr.Character:GetDescendants()) do
						if part:IsA("BasePart") and part.CanCollide then
							pcall(function() part.CanCollide = false end)
						end
					end
				end
			end
		end
		task.wait(0.45)
	end
end)

keybindRow(MovePage, "Instant Reset", "instantReset", 14)

-- keep speed applied through respawns
track(LP.CharacterAdded:Connect(function()
	task.wait(1.2)
	pcall(RH.ApplySpeed)
	if RH.Flags.customAnims and RH.ApplyPack then
		task.wait(0.8)
		pcall(RH.ApplyPack, RH.Values.animPack)
	end
end))

-- Auto lagger speed: fall back to the lagger preset when the
-- connection degrades, and climb back out when it recovers.
local function getPing()
	local ok, value = pcall(function()
		return Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
	end)
	if ok and value then
		return math.floor((tonumber(string.match(value, "[%d%.]+")) or 0) + 0.5)
	end
	return 0
end

task.spawn(function()
	local laggerIndex
	while not RH.Dead do
		task.wait(2)
		if RH.Flags.autoLaggerSpeed and RH.SpeedOn then
			laggerIndex = nil
			for i, p in ipairs(RH.Speeds) do
				if string.find(string.lower(p.name), "lagger") then laggerIndex = i break end
			end
			if laggerIndex then
				local ping = getPing()
				if ping >= 130 and RH.ActiveSpeed ~= laggerIndex then
					RH.ActiveSpeed = laggerIndex
					renderSpeeds()
					pcall(RH.ApplySpeed)
				elseif ping > 0 and ping <= 85 and RH.ActiveSpeed == laggerIndex then
					RH.ActiveSpeed = 1
					renderSpeeds()
					pcall(RH.ApplySpeed)
				end
			end
		end
	end
end)

-- ═══════════════════════════════════════════════════════════════
-- COMBAT PAGE
-- ═══════════════════════════════════════════════════════════════
local CombatPage = Pages["Combat"]

local function infoRow(parent, labelText, order)
	local row = baseRow(parent, labelText, order)
	row.Label.Size = UDim2.new(0, 118, 1, 0)
	local value = newLabel(row, "--", UDim2.new(0, 150, 1, 0), UDim2.new(1, -163, 0, 0), 13, THEME.accentGlow, Enum.Font.GothamBold, 8)
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextTruncate = Enum.TextTruncate.AtEnd
	return row, value
end

sectionLabel(CombatPage, "Targeting", 1)
toggleRow(CombatPage, "Aimbot", "aimbot", 2)
keybindRow(CombatPage, "Aimbot Key", "aimbot", 3)
numberRow(CombatPage, "Aimbot Speed", "aimbotSpeed", 4)
toggleRow(CombatPage, "Target Highlight", "targetHighlight", 5)
local _, NearestValue = infoRow(CombatPage, "Nearest Target", 6)
divider(CombatPage, 7)
sectionLabel(CombatPage, "Automation", 8)
toggleRow(CombatPage, "Auto Swing", "autoSwing", 9)
toggleRow(CombatPage, "Bat Counter", "batCounter", 10)
toggleRow(CombatPage, "Auto Reset On Med", "autoResetOnMed", 11)
numberRow(CombatPage, "Steal Radius", "stealRadius", 12)

local function nearestPlayer()
	local _, char = getHumanoid()
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil, 0 end
	local best, bestDist
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP and plr.Character then
			local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
			local hum = plr.Character:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local d = (hrp.Position - root.Position).Magnitude
				if not bestDist or d < bestDist then
					best, bestDist = plr, d
				end
			end
		end
	end
	return best, bestDist or 0
end
RH.NearestPlayer = nearestPlayer

local function clearMark(name)
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local mark = char and char:FindFirstChild(name)
		if mark then mark:Destroy() end
	end
end

task.spawn(function()
	while not RH.Dead do
		task.wait(0.4)
		local target, dist = nearestPlayer()
		if NearestValue then
			NearestValue.Text = target and string.format("%s  -  %d studs", target.Name, math.floor(dist)) or "none"
		end
		if RH.Flags.targetHighlight then
			for _, plr in ipairs(Players:GetPlayers()) do
				local char = plr.Character
				if char then
					local mark = char:FindFirstChild("RainyTarget")
					if plr == target then
						if not mark then
							local h = Instance.new("Highlight")
							h.Name = "RainyTarget"
							h.FillColor = THEME.accent
							h.FillTransparency = 0.6
							h.OutlineColor = THEME.accentGlow
							h.OutlineTransparency = 0
							h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
							h.Parent = char
						end
					elseif mark then
						mark:Destroy()
					end
				end
			end
		else
			clearMark("RainyTarget")
		end
	end
end)

-- ═══════════════════════════════════════════════════════════════
-- VISUALS PAGE
-- ═══════════════════════════════════════════════════════════════
local VisualPage = Pages["Visuals"]

sectionLabel(VisualPage, "Storm", 1)
cycleRow(VisualPage, "Rain Intensity", "rainIntensity", {"Light", "Medium", "Heavy", "Storm"}, 2, function()
	buildRain()
end)
toggleRow(VisualPage, "Rain On HUD", "rainOnHud", 3, function(on)
	if RH.Refs.RainLayer then RH.Refs.RainLayer.Visible = on end
	if RH.Refs.SideRain then RH.Refs.SideRain.Visible = on end
	if RH.Refs.RainFront then RH.Refs.RainFront.Visible = on end
end)
toggleRow(VisualPage, "Storm Flashes", "stormFlashes", 4, function(on)
	if not on and RH.Refs.Flash then RH.Refs.Flash.BackgroundTransparency = 1 end
end)
toggleRow(VisualPage, "Skull Glow", "skullGlow", 5, function()
	buildSkull()
end)
cycleRow(VisualPage, "Window Opacity", "windowOpacity", {"Solid", "Glass", "Ghost"}, 6, function(mode)
	local map = {Solid = 0, Glass = 0.16, Ghost = 0.34}
	local t = map[mode] or 0
	Main.BackgroundTransparency = t
	if RH.Refs.Sky then RH.Refs.Sky.BackgroundTransparency = t end
	if RH.Refs.Sidebar then RH.Refs.Sidebar.BackgroundTransparency = 0.12 + t end
end)

divider(VisualPage, 7)
sectionLabel(VisualPage, "World", 8)

toggleRow(VisualPage, "Player ESP", "playerESP", 9, function(on)
	if not on then clearMark("RainyESP") end
end)
task.spawn(function()
	while not RH.Dead do
		task.wait(0.9)
		if RH.Flags.playerESP then
			for _, plr in ipairs(Players:GetPlayers()) do
				local char = plr.Character
				if plr ~= LP and char and not char:FindFirstChild("RainyESP") then
					local h = Instance.new("Highlight")
					h.Name = "RainyESP"
					h.FillColor = THEME.boneDeep
					h.FillTransparency = 0.75
					h.OutlineColor = THEME.rain
					h.OutlineTransparency = 0.1
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h.Parent = char
				end
			end
		end
	end
end)

-- Tracers drawn on their own full-screen layer.
local TracerLayer = Instance.new("Frame")
TracerLayer.Name = "Tracers"
TracerLayer.BackgroundTransparency = 1
TracerLayer.Size = UDim2.new(1, 0, 1, 0)
TracerLayer.ZIndex = 0 -- sits under the hub window
TracerLayer.Visible = RH.Flags.tracers
TracerLayer.Parent = Gui

toggleRow(VisualPage, "Tracers", "tracers", 10, function(on)
	TracerLayer.Visible = on
	if not on then TracerLayer:ClearAllChildren() end
end)

do
	local lines = {}
	track(RunService.RenderStepped:Connect(function()
		if RH.Dead or not RH.Flags.tracers then return end
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local vp = cam.ViewportSize
		local ox, oy = vp.X / 2, vp.Y
		local seen = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if plr ~= LP and hrp then
				local pos, onScreen = cam:WorldToViewportPoint(hrp.Position)
				local line = lines[plr]
				if onScreen then
					if not line then
						line = Instance.new("Frame")
						line.BorderSizePixel = 0
						line.BackgroundColor3 = THEME.rain
						line.BackgroundTransparency = 0.35
						line.AnchorPoint = Vector2.new(0, 0.5)
						line.ZIndex = 1
						line.Parent = TracerLayer
						lines[plr] = line
					end
					local dx, dy = pos.X - ox, pos.Y - oy
					line.Size = UDim2.new(0, math.sqrt(dx * dx + dy * dy), 0, 1.4)
					line.Position = UDim2.new(0, ox, 0, oy)
					line.Rotation = math.deg(math.atan2(dy, dx))
					line.Visible = true
					seen[plr] = true
				elseif line then
					line.Visible = false
				end
			end
		end
		for plr, line in pairs(lines) do
			if not seen[plr] and (not plr.Parent or not plr.Character) then
				line:Destroy()
				lines[plr] = nil
			end
		end
	end))
end

numberRow(VisualPage, "FOV", "fov", 11, function(n)
	local cam = Workspace.CurrentCamera
	if cam then cam.FieldOfView = math.clamp(n, 1, 120) end
end)

divider(VisualPage, 12)
sectionLabel(VisualPage, "Interface", 13)
keybindRow(VisualPage, "Toggle UI", "toggleUI", 14)
buttonRow(VisualPage, "Reset Window Position", 15, function()
	Main.Position = UDim2.new(0, 26, 0.5, 0)
	RH.SavedPos = nil
	saveConfig()
end)
buttonRow(VisualPage, "Unload Rainy Hub", 16, function()
	saveConfig()
	if _G.RainyHubCleanup then _G.RainyHubCleanup() end
	clearMark("RainyESP")
	clearMark("RainyTarget")
	if TracerLayer then TracerLayer:Destroy() end
	if Gui then Gui:Destroy() end
end)

-- ═══════════════════════════════════════════════════════════════
-- ANIMATIONS PAGE
-- ═══════════════════════════════════════════════════════════════
local AnimPage = Pages["Animations"]

local PACKS = {
	Zombie    = {idle = "616158929",  walk = "616168032",  run = "616163682",  jump = "616161997",  fall = "616157476",  climb = "616156119"},
	Ninja     = {idle = "656117400",  walk = "656121766",  run = "656118852",  jump = "656117878",  fall = "656115606",  climb = "656114359"},
	Knight    = {idle = "657595757",  walk = "657552124",  run = "657564596",  jump = "658409194",  fall = "657600338",  climb = "658360781"},
	Elder     = {idle = "845397899",  walk = "845403856",  run = "845386501",  jump = "845398858",  fall = "845397673",  climb = "845392038"},
	Levitate  = {idle = "616006778",  walk = "616013216",  run = "616013216",  jump = "616008936",  fall = "616005863",  climb = "616003713"},
	Astronaut = {idle = "891621366",  walk = "891636393",  run = "891636393",  jump = "891627522",  fall = "891617961",  climb = "891609353"},
	Pirate    = {idle = "750781874",  walk = "750785693",  run = "750783738",  jump = "750782230",  fall = "750780242",  climb = "750779899"},
	Vampire   = {idle = "1083445855", walk = "1083473930", run = "1083462077", jump = "1083455352", fall = "1083443587", climb = "1083439238"},
	Werewolf  = {idle = "1083195517", walk = "1083178339", run = "1083216690", jump = "1083218792", fall = "1083189019", climb = "1083182000"},
	Rthro     = {idle = "2510196951", walk = "2510202577", run = "2510198475", jump = "2510197830", fall = "2510195892", climb = "2510192778"},
}
local PACK_ORDER = {"OFF", "Zombie", "Ninja", "Knight", "Elder", "Levitate", "Astronaut", "Pirate", "Vampire", "Werewolf", "Rthro"}

local originalAnims = nil

local function animateScript()
	local char = LP.Character
	return char and char:FindFirstChild("Animate") or nil
end

local function animNode(animate, group, child)
	local g = animate and animate:FindFirstChild(group)
	return g and g:FindFirstChild(child) or nil
end

local function setAnimId(node, id)
	if node and id then pcall(function() node.AnimationId = id end) end
end

local function reloadAnimate(animate)
	if not animate then return end
	pcall(function()
		animate.Disabled = true
		task.wait()
		animate.Disabled = false
	end)
end

local function stopTracks()
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
		pcall(function() t:Stop(0) end)
	end
end

RH.ApplyPack = function(packName)
	local animate = animateScript()
	if not animate then return end
	if not originalAnims then
		originalAnims = {
			idle1 = animNode(animate, "idle", "Animation1") and animNode(animate, "idle", "Animation1").AnimationId,
			idle2 = animNode(animate, "idle", "Animation2") and animNode(animate, "idle", "Animation2").AnimationId,
			walk  = animNode(animate, "walk", "WalkAnim") and animNode(animate, "walk", "WalkAnim").AnimationId,
			run   = animNode(animate, "run", "RunAnim") and animNode(animate, "run", "RunAnim").AnimationId,
			jump  = animNode(animate, "jump", "JumpAnim") and animNode(animate, "jump", "JumpAnim").AnimationId,
			fall  = animNode(animate, "fall", "FallAnim") and animNode(animate, "fall", "FallAnim").AnimationId,
			climb = animNode(animate, "climb", "ClimbAnim") and animNode(animate, "climb", "ClimbAnim").AnimationId,
		}
	end
	stopTracks()
	if packName == "OFF" or not PACKS[packName] then
		if originalAnims then
			setAnimId(animNode(animate, "idle", "Animation1"), originalAnims.idle1)
			setAnimId(animNode(animate, "idle", "Animation2"), originalAnims.idle2)
			setAnimId(animNode(animate, "walk", "WalkAnim"), originalAnims.walk)
			setAnimId(animNode(animate, "run", "RunAnim"), originalAnims.run)
			setAnimId(animNode(animate, "jump", "JumpAnim"), originalAnims.jump)
			setAnimId(animNode(animate, "fall", "FallAnim"), originalAnims.fall)
			setAnimId(animNode(animate, "climb", "ClimbAnim"), originalAnims.climb)
		end
		reloadAnimate(animate)
		return
	end
	local pack = PACKS[packName]
	setAnimId(animNode(animate, "idle", "Animation1"), "rbxassetid://" .. pack.idle)
	setAnimId(animNode(animate, "idle", "Animation2"), "rbxassetid://" .. pack.idle)
	setAnimId(animNode(animate, "walk", "WalkAnim"), "rbxassetid://" .. pack.walk)
	setAnimId(animNode(animate, "run", "RunAnim"), "rbxassetid://" .. pack.run)
	setAnimId(animNode(animate, "jump", "JumpAnim"), "rbxassetid://" .. pack.jump)
	setAnimId(animNode(animate, "fall", "FallAnim"), "rbxassetid://" .. pack.fall)
	setAnimId(animNode(animate, "climb", "ClimbAnim"), "rbxassetid://" .. pack.climb)
	reloadAnimate(animate)
end

sectionLabel(AnimPage, "Animation Pack", 1)
cycleRow(AnimPage, "Pack", "animPack", PACK_ORDER, 2, function(name)
	pcall(RH.ApplyPack, name)
end)
buttonRow(AnimPage, "Reapply Pack", 3, function()
	pcall(RH.ApplyPack, RH.Values.animPack)
end)
numberRow(AnimPage, "Animation Speed", "animSpeed", 4, function(n)
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
		pcall(function() t:AdjustSpeed(math.clamp(n, 0.1, 6)) end)
	end
end)
divider(AnimPage, 5)
sectionLabel(AnimPage, "Extras", 6)
toggleRow(AnimPage, "Reapply On Respawn", "customAnims", 7)
toggleRow(AnimPage, "Ragdoll Countdown", "ragdollCountdown", 8)

-- ═══════════════════════════════════════════════════════════════
-- INPUT
-- ═══════════════════════════════════════════════════════════════
local MOUSE_NAMES = {
	[Enum.UserInputType.MouseButton1] = "Mouse1",
	[Enum.UserInputType.MouseButton2] = "Mouse2",
	[Enum.UserInputType.MouseButton3] = "Mouse3",
}

local function inputName(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		return input.KeyCode.Name
	end
	return MOUSE_NAMES[input.UserInputType]
end

local function instantReset()
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		local ok = pcall(function() hum.Health = 0 end)
		if not ok then pcall(function() char:BreakJoints() end) end
	end
end

local function tpDown()
	local char = LP.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		pcall(function() hrp.CFrame = hrp.CFrame + Vector3.new(0, -14, 0) end)
	end
end

local MiniPill -- forward declared, built below
local function setHubVisible(show)
	Main.Visible = show
	if MiniPill then MiniPill.Visible = not show end
end

track(UserInputService.InputBegan:Connect(function(input, processed)
	if RH.Dead then return end
	local name = inputName(input)

	if RH.Capture then
		if not name then return end
		local fn = RH.Capture
		RH.Capture = nil
		if name == "Escape" then fn(nil) else fn(name) end
		return
	end
	if processed or not name then return end

	if name == RH.Keys.toggleUI then
		setHubVisible(not Main.Visible)
		return
	end
	if name == RH.Keys.tpDown then tpDown() return end
	if name == RH.Keys.instantReset then instantReset() return end
	if name == RH.Keys.carrySpeed then
		local on = not (RH.Flags.autoCarrySpeed == true)
		if RH.Visuals.autoCarrySpeed then RH.Visuals.autoCarrySpeed(on) end
		saveConfig()
		pcall(RH.ApplySpeed)
		return
	end
	if name == RH.Keys.aimbot then
		local on = not (RH.Flags.aimbot == true)
		if RH.Visuals.aimbot then RH.Visuals.aimbot(on) end
		saveConfig()
		if RH.Hooks.aimbot then pcall(RH.Hooks.aimbot, on) end
		return
	end
	for index, preset in ipairs(RH.Speeds) do
		if preset.key ~= "None" and name == preset.key then
			selectSpeed(index, true)
			return
		end
	end
end))

-- ═══════════════════════════════════════════════════════════════
-- FPS / PING READOUT
-- ═══════════════════════════════════════════════════════════════
do
	local frames, elapsed = 0, 0
	local fps = 60
	track(RunService.RenderStepped:Connect(function(dt)
		frames = frames + 1
		elapsed = elapsed + dt
		if elapsed >= 0.5 then
			fps = math.floor(frames / elapsed + 0.5)
			frames, elapsed = 0, 0
			StatLabel.Text = string.format("FPS: %d | PING: %dms", fps, getPing())
		end
	end))
end

-- ═══════════════════════════════════════════════════════════════
-- DRAGGING / MINIMISE
-- ═══════════════════════════════════════════════════════════════
local function makeDraggable(frame, onDrop)
	local dragging, dragStart, startPos, held = false, nil, nil, nil
	local moved = false
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			moved = false
			held = input
			dragStart = input.Position
			startPos = frame.Position
		end
	end)
	track(UserInputService.InputChanged:Connect(function(input)
		if not dragging or not dragStart then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local delta = input.Position - dragStart
		if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then moved = true end
		frame.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end))
	track(UserInputService.InputEnded:Connect(function(input)
		if input ~= held then return end
		dragging = false
		held = nil
		if onDrop then onDrop(moved) end
	end))
end

makeDraggable(Main, function()
	RH.SavedPos = {
		xs = Main.Position.X.Scale, xo = Main.Position.X.Offset,
		ys = Main.Position.Y.Scale, yo = Main.Position.Y.Offset,
	}
	saveConfig()
end)

MiniPill = newFrame(Gui, UDim2.new(0, 104, 0, 36), UDim2.new(0, 26, 0.5, 0), THEME.panel, 30)
MiniPill.Name = "MiniPill"
MiniPill.AnchorPoint = Vector2.new(0, 0.5)
MiniPill.Visible = false
MiniPill.Active = true
corner(MiniPill, 10)
stroke(MiniPill, THEME.accent, 1.4, 0.15)
do
	local pillDot = newFrame(MiniPill, UDim2.new(0, 8, 0, 8), UDim2.new(0, 12, 0.5, -4), THEME.accentGlow, 31)
	corner(pillDot, 999)
	newLabel(MiniPill, "RAINY", UDim2.new(1, -30, 1, 0), UDim2.new(0, 28, 0, 0), 14, THEME.white, Enum.Font.GothamBlack, 31)
	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.new(1, 0, 1, 0)
	hit.AutoButtonColor = false
	hit.ZIndex = 32
	hit.Parent = MiniPill
	local pillMoved = false
	makeDraggable(MiniPill, function(moved) pillMoved = moved end)
	hit.MouseButton1Click:Connect(function()
		if pillMoved then pillMoved = false return end
		setHubVisible(true)
	end)
	-- a few drops falling inside the pill so it still reads as "rainy"
	task.spawn(function()
		while not RH.Dead do
			task.wait(0.35)
			if MiniPill.Visible and RH.Flags.rainOnHud then
				local d = newFrame(MiniPill, UDim2.new(0, 1.6, 0, 8), UDim2.new(0, rng:NextInteger(6, 98), 0, -8), THEME.rain, 31)
				d.BackgroundTransparency = 0.4
				corner(d, 2)
				tween(d, {Position = UDim2.new(0, d.Position.X.Offset + 6, 0, 40), BackgroundTransparency = 1}, 0.75)
				task.delay(0.85, function() if d and d.Parent then d:Destroy() end end)
			end
		end
	end)
end

MiniBtn.MouseButton1Click:Connect(function()
	MiniPill.Position = Main.Position
	setHubVisible(false)
end)

-- ═══════════════════════════════════════════════════════════════
-- SCALING + BOOT
-- ═══════════════════════════════════════════════════════════════
local UiScale = Instance.new("UIScale")
UiScale.Parent = Main

local function updateScale()
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	if vp.X < 10 then return end
	UiScale.Scale = math.clamp(math.min(vp.X / 760, vp.Y / 700), 0.6, 1)
end
updateScale()
if Workspace.CurrentCamera then
	track(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))
end

setTab("Movement")
if RH.Refs.RainLayer then RH.Refs.RainLayer.Visible = RH.Flags.rainOnHud end
if RH.Refs.SideRain then RH.Refs.SideRain.Visible = RH.Flags.rainOnHud end
if RH.Refs.RainFront then RH.Refs.RainFront.Visible = RH.Flags.rainOnHud end
do
	local map = {Solid = 0, Glass = 0.16, Ghost = 0.34}
	local t = map[RH.Values.windowOpacity] or 0
	Main.BackgroundTransparency = t
	if RH.Refs.Sky then RH.Refs.Sky.BackgroundTransparency = t end
	if RH.Refs.Sidebar then RH.Refs.Sidebar.BackgroundTransparency = 0.12 + t end
end

-- opening flourish: the window rolls in under a lightning flash
do
	local startPos = Main.Position
	Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset - 40, startPos.Y.Scale, startPos.Y.Offset)
	UiScale.Scale = UiScale.Scale * 0.94
	local finalScale = math.clamp(math.min((Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize.X or 1280) / 760, 1), 0.6, 1)
	tween(Main, {Position = startPos}, 0.45, Enum.EasingStyle.Quint)
	tween(UiScale, {Scale = finalScale}, 0.45, Enum.EasingStyle.Quint)
	task.delay(0.18, function() pcall(stormFlash) end)
end

if RH.Values.fov and Workspace.CurrentCamera then
	pcall(function() Workspace.CurrentCamera.FieldOfView = math.clamp(RH.Values.fov, 1, 120) end)
end
if RH.Flags.customAnims and RH.Values.animPack ~= "OFF" then
	task.delay(1.5, function() pcall(RH.ApplyPack, RH.Values.animPack) end)
end

print("[Rainy Hub] loaded — press " .. tostring(RH.Keys.toggleUI) .. " to hide or show the window.")
