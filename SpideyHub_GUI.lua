--[[
	Spidey Hub — GUI only
	=====================
	The interface lifted out of the hub script with every game feature removed:
	the window, the webbing, the sidebar, the tabs and the row builders, and
	nothing else. Drop your own logic into the callbacks at the bottom.

	Building a row:

		local page = pages.MOVEMENT

		section(page, "SPEEDS", 1)

		local row, box = textboxRow(page, "Normal Speed", "70", 2)
		box.FocusLost:Connect(function()
			print("speed is now", box.Text)
		end)

		local row, setVisual, button = _G.AceActionToggleRow(page, "Fly", false, 3)
		local on = false
		button.Activated:Connect(function()
			on = not on
			setVisual(on)
			print("fly:", on)
		end)

	Row builders, all of which take (parent, ..., order):

		section(parent, text, order)                  -> label
		baseRow(parent, labelText, order)             -> row
		textboxRow(parent, labelText, value, order)   -> row, TextBox
		toggleRow(parent, labelText, default, order)  -> row, setVisual
		dropdownRow(parent, labelText, value, order)  -> row, TextButton
		_G.AceActionToggleRow(parent, labelText, default, order)
		                                              -> row, setVisual, button

	toggleRow gives you a display-only switch; AceActionToggleRow also hands
	back the button so you can wire the click yourself.

	Tabs live in `tabNames`; edit that list and `tabBlurbs` to change them.
	The minimise button collapses the window to a draggable spider emblem.
--]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

-- Set true to stop the window being dragged.
_G.AceGuiLocked = _G.AceGuiLocked or false

for _, name in ipairs({"SpideyHub"}) do
	local old = PlayerGui:FindFirstChild(name)
	if old then old:Destroy() end
end

-- ---------------------------------------------------------------- helpers and drawing
local COLORS = {
bg = Color3.fromRGB(7, 9, 22),
row = Color3.fromRGB(21, 26, 56),
row2 = Color3.fromRGB(16, 20, 45),
stroke = Color3.fromRGB(52, 62, 116),
strokeSoft = Color3.fromRGB(38, 45, 88),
white = Color3.fromRGB(238, 242, 255),
textDim = Color3.fromRGB(133, 145, 190),
toggleBg = Color3.fromRGB(16, 20, 45),
knob = Color3.fromRGB(238, 242, 255),
accent = Color3.fromRGB(226, 32, 42),
accentDeep = Color3.fromRGB(138, 12, 22),
secondary = Color3.fromRGB(43, 92, 219),
web = Color3.fromRGB(198, 214, 255),
surface = Color3.fromRGB(12, 15, 34),
cardHover = Color3.fromRGB(30, 37, 76),
muted = Color3.fromRGB(88, 98, 138),
}
function corner(parent, radius)
local c = Instance.new("UICorner")
c.CornerRadius = UDim.new(0, radius or 8)
c.Parent = parent
return c
end
function stroke(parent, color, thickness, transparency)
local s = Instance.new("UIStroke")
s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
s.Color = color or COLORS.stroke
s.Thickness = thickness or 1
s.Transparency = transparency or 0.35
s.Parent = parent
local g = Instance.new("UIGradient")
g.Color = ColorSequence.new({
ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
ColorSequenceKeypoint.new(0.5, Color3.fromRGB(155, 160, 185)),
ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
})
g.Transparency = NumberSequence.new({
NumberSequenceKeypoint.new(0, 0.55),
NumberSequenceKeypoint.new(0.5, 0.1),
NumberSequenceKeypoint.new(1, 0.55),
})
g.Parent = s
return s
end
function tween(obj, props, time)
TweenService:Create(obj, TweenInfo.new(time or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end
function aceGradient(parent, colorSequence, rotation, transparency)
local g = Instance.new("UIGradient")
g.Color = colorSequence
g.Rotation = rotation or 0
if transparency then g.Transparency = transparency end
g.Parent = parent
return g
end
function aceStrand(parent, p1, p2, thickness, zindex, transparency)
local delta = p2 - p1
local length = delta.Magnitude
if length < 1 then return nil end
local f = Instance.new("Frame")
f.AnchorPoint = Vector2.new(0.5, 0.5)
f.Position = UDim2.fromOffset((p1.X + p2.X) * 0.5, (p1.Y + p2.Y) * 0.5)
f.Size = UDim2.fromOffset(math.ceil(length) + 1, thickness or 1)
f.Rotation = math.deg(math.atan2(delta.Y, delta.X))
f.BackgroundColor3 = COLORS.web
f.BackgroundTransparency = transparency or 0.8
f.BorderSizePixel = 0
f.ZIndex = zindex or 2
f.Parent = parent
return f
end
function aceWeb(parent, origin, spokes, rings, spacing, inner, startAngle, endAngle, fadeRotation, zindex, radius)
local holder = Instance.new("Frame")
holder.Name = "Web"
holder.Size = UDim2.new(1, 0, 1, 0)
holder.BackgroundTransparency = 1
holder.ClipsDescendants = true
holder.ZIndex = zindex or 2
holder.Parent = parent
corner(holder, radius or 14)
local a0 = math.rad(startAngle)
local a1 = math.rad(endAngle)
local function point(r, s)
local rad = inner + spacing * r
local angle = a0 + (a1 - a0) * (s / spokes)
return origin + Vector2.new(math.cos(angle) * rad, math.sin(angle) * rad)
end
for s = 0, spokes do
aceStrand(holder, point(0, s), point(rings, s), 1, zindex or 2, 0.7)
end
for r = 1, rings do
for s = 0, spokes - 1 do
local p1 = point(r, s)
local p2 = point(r, s + 1)
local mid = origin + ((p1 + p2) * 0.5 - origin) * 0.96
aceStrand(holder, p1, mid, 1, zindex or 2, 0.8)
aceStrand(holder, mid, p2, 1, zindex or 2, 0.8)
end
end
local g = Instance.new("UIGradient")
g.Rotation = fadeRotation or 35
g.Transparency = NumberSequence.new({
NumberSequenceKeypoint.new(0, 0.15),
NumberSequenceKeypoint.new(0.55, 0.6),
NumberSequenceKeypoint.new(1, 1),
})
g.Parent = holder
return holder
end
function aceSpider(parent, size, color, zindex)
color = color or COLORS.accent
zindex = zindex or 8
local holder = Instance.new("Frame")
holder.Name = "Spider"
holder.AnchorPoint = Vector2.new(0.5, 0.5)
holder.Position = UDim2.new(0.5, 0, 0.5, 0)
holder.Size = UDim2.fromOffset(size, size)
holder.BackgroundTransparency = 1
holder.ZIndex = zindex
holder.Parent = parent
local centre = Vector2.new(size / 2, size / 2)
local unit = size / 24
local function limb(p1, p2, thickness)
local line = aceStrand(holder, p1, p2, thickness, zindex, 0)
if line then
line.BackgroundColor3 = color
corner(line, math.max(1, math.floor(thickness / 2)))
end
end
for _, baseAngle in ipairs({-68, -28, 20, 58}) do
for _, side in ipairs({-1, 1}) do
local a = math.rad(baseAngle)
local root = centre + Vector2.new(side * unit * 1.6, unit * 0.4)
local knee = root + Vector2.new(side * math.cos(a) * unit * 5.4, math.sin(a) * unit * 5.4)
local tip = knee + Vector2.new(side * math.cos(a) * unit * 4.4, math.sin(a) * unit * 4.4 + unit * 2.2)
limb(root, knee, math.max(2, unit * 1.05))
limb(knee, tip, math.max(2, unit * 0.9))
end
end
local body = Instance.new("Frame")
body.Name = "Body"
body.AnchorPoint = Vector2.new(0.5, 0.5)
body.Position = UDim2.new(0.5, 0, 0.56, 0)
body.Size = UDim2.fromOffset(math.max(4, unit * 4.6), math.max(6, unit * 9.4))
body.BackgroundColor3 = color
body.BorderSizePixel = 0
body.ZIndex = zindex + 1
body.Parent = holder
corner(body, math.floor(unit * 2.3))
local head = Instance.new("Frame")
head.Name = "Head"
head.AnchorPoint = Vector2.new(0.5, 0.5)
head.Position = UDim2.new(0.5, 0, 0.26, 0)
head.Size = UDim2.fromOffset(math.max(4, unit * 3.4), math.max(4, unit * 3.4))
head.BackgroundColor3 = color
head.BorderSizePixel = 0
head.ZIndex = zindex + 1
head.Parent = holder
corner(head, math.floor(unit * 1.7))
return holder
end
function aceSense(anchor, color)
if not anchor or not anchor.Parent then return end
local ring = Instance.new("Frame")
ring.Name = "Sense"
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.new(0.5, 0, 0.5, 0)
ring.Size = UDim2.new(0.6, 0, 0.6, 0)
ring.BackgroundTransparency = 1
ring.ZIndex = (anchor.ZIndex or 1) + 3
ring.Parent = anchor
corner(ring, 100)
local s = Instance.new("UIStroke")
s.Color = color or COLORS.accent
s.Thickness = 2
s.Transparency = 0.1
s.Parent = ring
TweenService:Create(ring, TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(2.1, 0, 2.6, 0)}):Play()
TweenService:Create(s, TweenInfo.new(0.42), {Transparency = 1}):Play()
task.delay(0.5, function() ring:Destroy() end)
end
-- ---------------------------------------------------------------- drag
function makeDraggable(frame)
local dragging = false
local dragStart
local startPos
local dragInput
frame.InputBegan:Connect(function(input)
if _G.AceGuiLocked == true then return end
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
dragging = true
dragStart = input.Position
startPos = frame.Position
input.Changed:Connect(function()
if input.UserInputState == Enum.UserInputState.End then
dragging = false
end
end)
end
end)
frame.InputChanged:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
dragInput = input
end
end)
UserInputService.InputChanged:Connect(function(input)
if _G.AceGuiLocked == true then return end
if input == dragInput and dragging then
local delta = input.Position - dragStart
frame.Position = UDim2.new(
startPos.X.Scale,
startPos.X.Offset + delta.X,
startPos.Y.Scale,
startPos.Y.Offset + delta.Y
)
end
end)
end
-- ---------------------------------------------------------------- window, backdrop, minimise
local Gui = Instance.new("ScreenGui")
Gui.Name = "SpideyHub"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PlayerGui
local FULL_MAIN_SIZE = UDim2.new(0, 640, 0, 460)
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.AnchorPoint = Vector2.new(0, 0.5)
Main.Size = FULL_MAIN_SIZE
Main.Position = UDim2.new(0, 20, 0.5, 0)
Main.BackgroundColor3 = COLORS.bg
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = false
Main.Parent = Gui
corner(Main, 14)
stroke(Main, COLORS.stroke, 1.1, 0.35)
aceGradient(Main, ColorSequence.new({
ColorSequenceKeypoint.new(0, COLORS.surface),
ColorSequenceKeypoint.new(0.55, COLORS.bg),
ColorSequenceKeypoint.new(1, COLORS.bg),
}), 115)
-- Two quarter-webs pinned to opposite corners. The hub sits exactly on the
-- corner so the spokes converge and read as webbing.
aceWeb(Main, Vector2.new(640, 0), 10, 9, 42, 26, 90, 180, 215, 2, 14)
aceWeb(Main, Vector2.new(0, 460), 8, 6, 38, 22, -90, 0, 35, 2, 14)
local HeaderBloom = Instance.new("Frame")
HeaderBloom.Name = "HeaderBloom"
HeaderBloom.Size = UDim2.new(1, 0, 0, 130)
HeaderBloom.BackgroundColor3 = COLORS.accent
HeaderBloom.BackgroundTransparency = 0.86
HeaderBloom.BorderSizePixel = 0
HeaderBloom.ZIndex = 2
HeaderBloom.Parent = Main
corner(HeaderBloom, 14)
aceGradient(HeaderBloom, ColorSequence.new(COLORS.accent, COLORS.accent), 90, NumberSequence.new({
NumberSequenceKeypoint.new(0, 0.35),
NumberSequenceKeypoint.new(1, 1),
}))
makeDraggable(Main)
local MiniFrame = Instance.new("Frame")
MiniFrame.Name = "MiniFrame"
MiniFrame.AnchorPoint = Vector2.new(0, 0)
MiniFrame.Size = UDim2.new(0, 56, 0, 56)
local MINI_DEFAULT_POSITION = UDim2.new(0, 132, 0, 112)
MiniFrame.Position = MINI_DEFAULT_POSITION
savedMiniPositionTable = nil
MiniFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MiniFrame.BackgroundTransparency = 0
MiniFrame.BorderSizePixel = 0
MiniFrame.Visible = false
MiniFrame.Active = true
MiniFrame.ZIndex = 20
MiniFrame.Parent = Gui
corner(MiniFrame, 28)
local miniStroke = Instance.new("UIStroke")
miniStroke.Color = COLORS.accent
miniStroke.Thickness = 1.5
miniStroke.Transparency = 0.15
miniStroke.Parent = MiniFrame
local MiniButton = Instance.new("TextButton")
MiniButton.Name = "MiniButton"
MiniButton.Size = UDim2.new(1, 0, 1, 0)
MiniButton.BackgroundTransparency = 1
MiniButton.Text = ""
MiniButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MiniButton.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
MiniButton.TextStrokeTransparency = 0.18
MiniButton.TextSize = 17
MiniButton.Font = Enum.Font.GothamBlack
MiniButton.AutoButtonColor = false
MiniButton.ZIndex = 21
MiniButton.Parent = MiniFrame
local MiniShade = Instance.new("Frame")
MiniShade.Name = "MiniShade"
MiniShade.Size = UDim2.new(1, -4, 1, -4)
MiniShade.Position = UDim2.new(0, 2, 0, 2)
MiniShade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MiniShade.BackgroundTransparency = 0.12
MiniShade.BorderSizePixel = 0
MiniShade.ZIndex = 20
MiniShade.Parent = MiniFrame
corner(MiniShade, 26)
aceSpider(MiniButton, 32, COLORS.accent, 22)
do
local miniDragging = false
local miniDragStart = nil
local miniStartPos = nil
local miniMoved = false
local miniHeldInput = nil
local DRAG_DEADZONE = 6
MiniButton.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
miniDragging = true
miniMoved = false
miniHeldInput = input
miniDragStart = input.Position
miniStartPos = MiniFrame.Position
end
end)
UserInputService.InputChanged:Connect(function(input)
if not miniDragging then return end
if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
if not miniDragStart or not miniStartPos then return end
local delta = input.Position - miniDragStart
if math.abs(delta.X) > DRAG_DEADZONE or math.abs(delta.Y) > DRAG_DEADZONE then
miniMoved = true
end
MiniFrame.Position = UDim2.new(
miniStartPos.X.Scale,
miniStartPos.X.Offset + delta.X,
miniStartPos.Y.Scale,
miniStartPos.Y.Offset + delta.Y
)
end)
UserInputService.InputEnded:Connect(function(input)
if input ~= miniHeldInput then return end
local wasDrag = miniMoved
miniDragging = false
miniHeldInput = nil
miniDragStart = nil
miniStartPos = nil
if wasDrag then
return
end
Main.Visible = true
MiniFrame.Visible = false
Main.Size = FULL_MAIN_SIZE
end)
end
-- ---------------------------------------------------------------- chrome and row builders
-- ============================ SPIDEY HUB CHROME ============================
-- Sidebar navigation on the left, page header and scrolling rows on the right.
-- Names used elsewhere in the script (pages, addPage, setTab, Content, Close,
-- AceLockTopButton) are all preserved.

local TAB_H = 42
local TAB_GAP = 6

local EmblemTile = Instance.new("Frame")
EmblemTile.Name = "EmblemTile"
EmblemTile.AnchorPoint = Vector2.new(0, 0.5)
EmblemTile.Position = UDim2.new(0, 18, 0, 27)
EmblemTile.Size = UDim2.new(0, 34, 0, 34)
EmblemTile.BackgroundTransparency = 1
EmblemTile.ZIndex = 6
EmblemTile.Parent = Main
aceSpider(EmblemTile, 30, COLORS.accent, 6)

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(0, 120, 0, 18)
Title.Position = UDim2.new(0, 62, 0, 11)
Title.Text = "SPIDEY"
Title.TextColor3 = COLORS.white
Title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
Title.TextStrokeTransparency = 0.7
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 6
Title.Parent = Main

-- The accent half is its own label: a gradient across the first would put its
-- colour stop at an arbitrary point, since the label is wider than the glyphs.
local TitleAccent = Instance.new("TextLabel")
TitleAccent.Name = "TitleAccent"
TitleAccent.BackgroundTransparency = 1
TitleAccent.Size = UDim2.new(0, 120, 0, 18)
TitleAccent.Position = UDim2.new(0, 122, 0, 11)
TitleAccent.Text = "HUB"
TitleAccent.TextColor3 = COLORS.accent
TitleAccent.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
TitleAccent.TextStrokeTransparency = 0.7
TitleAccent.Font = Enum.Font.GothamBlack
TitleAccent.TextSize = 16
TitleAccent.TextXAlignment = Enum.TextXAlignment.Left
TitleAccent.ZIndex = 6
TitleAccent.Parent = Main
task.defer(function()
TitleAccent.Position = UDim2.new(0, 62 + Title.TextBounds.X + 8, 0, 11)
end)

local Discord = Instance.new("TextLabel")
Discord.Name = "Discord"
Discord.BackgroundTransparency = 1
Discord.Size = UDim2.new(0, 240, 0, 14)
Discord.Position = UDim2.new(0, 62, 0, 30)
Discord.Text = "discord.gg/spideyhub"
Discord.TextColor3 = COLORS.muted
Discord.Font = Enum.Font.Gotham
Discord.TextSize = 11
Discord.TextXAlignment = Enum.TextXAlignment.Left
Discord.ZIndex = 6
Discord.Parent = Main

local Close = Instance.new("TextButton")
Close.Name = "Close"
Close.BackgroundColor3 = COLORS.row
Close.BackgroundTransparency = 0.12
Close.Text = "-"
Close.TextColor3 = COLORS.textDim
Close.TextSize = 20
Close.Font = Enum.Font.GothamBold
Close.Size = UDim2.new(0, 28, 0, 28)
Close.Position = UDim2.new(1, -44, 0, 13)
Close.AutoButtonColor = false
Close.ZIndex = 6
Close.Parent = Main
corner(Close, 8)
stroke(Close, COLORS.strokeSoft, 1, 0.5)
Close.MouseEnter:Connect(function()
tween(Close, {BackgroundColor3 = COLORS.accent, TextColor3 = COLORS.white})
end)
Close.MouseLeave:Connect(function()
tween(Close, {BackgroundColor3 = COLORS.row, TextColor3 = COLORS.textDim})
end)

AceLockTopButton = Instance.new("TextButton")
AceLockTopButton.Name = "LockGUI"
AceLockTopButton.BackgroundColor3 = COLORS.row
AceLockTopButton.BackgroundTransparency = 0.12
AceLockTopButton.TextColor3 = COLORS.textDim
AceLockTopButton.TextSize = 8
AceLockTopButton.Font = Enum.Font.GothamBlack
AceLockTopButton.Size = UDim2.new(0, 46, 0, 28)
AceLockTopButton.Position = UDim2.new(1, -96, 0, 13)
AceLockTopButton.AutoButtonColor = false
AceLockTopButton.ZIndex = 6
AceLockTopButton.Parent = Main
corner(AceLockTopButton, 8)
stroke(AceLockTopButton, COLORS.strokeSoft, 1, 0.5)
function AceUpdateGuiLockVisual()
if AceLockTopButton then
AceLockTopButton.Text = (_G.AceGuiLocked == true) and "UNLOCK" or "LOCK"
AceLockTopButton.BackgroundTransparency = (_G.AceGuiLocked == true) and 0.02 or 0.12
AceLockTopButton.TextColor3 = (_G.AceGuiLocked == true) and COLORS.white or COLORS.textDim
local st = AceLockTopButton:FindFirstChildOfClass("UIStroke")
if st then
st.Transparency = (_G.AceGuiLocked == true) and 0.08 or 0.5
st.Color = (_G.AceGuiLocked == true) and COLORS.accent or COLORS.strokeSoft
end
end
end
AceLockTopButton.Activated:Connect(function()
_G.AceGuiLocked = not (_G.AceGuiLocked == true)
AceUpdateGuiLockVisual()
end)
AceUpdateGuiLockVisual()

local HeaderDivider = Instance.new("Frame")
HeaderDivider.Name = "HeaderDivider"
HeaderDivider.BackgroundColor3 = COLORS.accent
HeaderDivider.BackgroundTransparency = 0.15
HeaderDivider.BorderSizePixel = 0
HeaderDivider.Size = UDim2.new(1, -32, 0, 1)
HeaderDivider.Position = UDim2.new(0, 16, 0, 54)
HeaderDivider.ZIndex = 6
HeaderDivider.Parent = Main
aceGradient(HeaderDivider, ColorSequence.new(COLORS.accent, COLORS.accent), 0, NumberSequence.new({
NumberSequenceKeypoint.new(0, 1),
NumberSequenceKeypoint.new(0.5, 0.25),
NumberSequenceKeypoint.new(1, 1),
}))

-- ------------------------------------------------------------- sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Position = UDim2.new(0, 14, 0, 66)
Sidebar.Size = UDim2.new(0, 178, 1, -80)
Sidebar.BackgroundColor3 = COLORS.surface
Sidebar.BackgroundTransparency = 0.25
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 3
Sidebar.Parent = Main
corner(Sidebar, 12)
stroke(Sidebar, COLORS.strokeSoft, 1, 0.65)

local NavLabel = Instance.new("TextLabel")
NavLabel.Name = "NavLabel"
NavLabel.BackgroundTransparency = 1
NavLabel.Position = UDim2.new(0, 16, 0, 12)
NavLabel.Size = UDim2.new(1, -24, 0, 14)
NavLabel.Text = "NAVIGATION"
NavLabel.TextColor3 = COLORS.muted
NavLabel.Font = Enum.Font.GothamBold
NavLabel.TextSize = 10
NavLabel.TextXAlignment = Enum.TextXAlignment.Left
NavLabel.ZIndex = 4
NavLabel.Parent = Sidebar

local TabWrap = Instance.new("Frame")
TabWrap.Name = "TabWrap"
TabWrap.BackgroundTransparency = 1
TabWrap.Position = UDim2.new(0, 12, 0, 34)
TabWrap.Size = UDim2.new(1, -24, 1, -114)
TabWrap.ZIndex = 4
TabWrap.Parent = Sidebar

local Tabs = Instance.new("ScrollingFrame")
Tabs.Name = "Tabs"
Tabs.BackgroundTransparency = 1
Tabs.BorderSizePixel = 0
Tabs.ScrollBarThickness = 0
Tabs.CanvasSize = UDim2.new(0, 0, 0, 0)
Tabs.AutomaticCanvasSize = Enum.AutomaticSize.Y
Tabs.Size = UDim2.new(1, 0, 1, 0)
Tabs.ZIndex = 4
Tabs.Parent = TabWrap

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Vertical
TabLayout.Padding = UDim.new(0, TAB_GAP)
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Parent = Tabs

local TabIndicator = Instance.new("Frame")
TabIndicator.Name = "TabIndicator"
TabIndicator.Position = UDim2.new(0, 0, 0, 10)
TabIndicator.Size = UDim2.new(0, 3, 0, 22)
TabIndicator.BackgroundColor3 = COLORS.accent
TabIndicator.BorderSizePixel = 0
TabIndicator.ZIndex = 6
TabIndicator.Parent = TabWrap
corner(TabIndicator, 2)

-- Identity card, pinned to the bottom of the sidebar.
local Footer = Instance.new("Frame")
Footer.Name = "Footer"
Footer.AnchorPoint = Vector2.new(0, 1)
Footer.Position = UDim2.new(0, 12, 1, -12)
Footer.Size = UDim2.new(1, -24, 0, 60)
Footer.BackgroundColor3 = COLORS.row
Footer.BorderSizePixel = 0
Footer.ZIndex = 4
Footer.Parent = Sidebar
corner(Footer, 10)
stroke(Footer, COLORS.strokeSoft, 1, 0.5)

local FooterAvatar = Instance.new("ImageLabel")
FooterAvatar.Name = "Avatar"
FooterAvatar.AnchorPoint = Vector2.new(0, 0.5)
FooterAvatar.Position = UDim2.new(0, 10, 0.5, 0)
FooterAvatar.Size = UDim2.new(0, 38, 0, 38)
FooterAvatar.BackgroundColor3 = COLORS.row2
FooterAvatar.BorderSizePixel = 0
FooterAvatar.ZIndex = 5
FooterAvatar.Parent = Footer
corner(FooterAvatar, 19)
local avatarStroke = Instance.new("UIStroke")
avatarStroke.Color = COLORS.accent
avatarStroke.Thickness = 1.4
avatarStroke.Transparency = 0.2
avatarStroke.Parent = FooterAvatar
task.spawn(function()
local ok, content = pcall(function()
return Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
end)
if ok and content then FooterAvatar.Image = content end
end)

local FooterName = Instance.new("TextLabel")
FooterName.Name = "FooterName"
FooterName.BackgroundTransparency = 1
FooterName.Position = UDim2.new(0, 56, 0, 12)
FooterName.Size = UDim2.new(1, -64, 0, 16)
FooterName.Text = LP.DisplayName
FooterName.TextColor3 = COLORS.white
FooterName.Font = Enum.Font.GothamBold
FooterName.TextSize = 12
FooterName.TextXAlignment = Enum.TextXAlignment.Left
FooterName.TextTruncate = Enum.TextTruncate.AtEnd
FooterName.ZIndex = 5
FooterName.Parent = Footer

local FooterSub = Instance.new("TextLabel")
FooterSub.Name = "FooterSub"
FooterSub.BackgroundTransparency = 1
FooterSub.Position = UDim2.new(0, 56, 0, 30)
FooterSub.Size = UDim2.new(1, -64, 0, 14)
FooterSub.Text = "spidey hub"
FooterSub.TextColor3 = COLORS.muted
FooterSub.Font = Enum.Font.Gotham
FooterSub.TextSize = 10
FooterSub.TextXAlignment = Enum.TextXAlignment.Left
FooterSub.TextTruncate = Enum.TextTruncate.AtEnd
FooterSub.ZIndex = 5
FooterSub.Parent = Footer

-- ------------------------------------------------------------- content
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.BackgroundTransparency = 1
ContentArea.Position = UDim2.new(0, 204, 0, 66)
ContentArea.Size = UDim2.new(1, -218, 1, -80)
ContentArea.ZIndex = 3
ContentArea.Parent = Main

local PageTitle = Instance.new("TextLabel")
PageTitle.Name = "PageTitle"
PageTitle.BackgroundTransparency = 1
PageTitle.Position = UDim2.new(0, 2, 0, 0)
PageTitle.Size = UDim2.new(1, -4, 0, 22)
PageTitle.Text = ""
PageTitle.TextColor3 = COLORS.white
PageTitle.Font = Enum.Font.GothamBlack
PageTitle.TextSize = 18
PageTitle.TextXAlignment = Enum.TextXAlignment.Left
PageTitle.ZIndex = 4
PageTitle.Parent = ContentArea

local PageSub = Instance.new("TextLabel")
PageSub.Name = "PageSub"
PageSub.BackgroundTransparency = 1
PageSub.Position = UDim2.new(0, 2, 0, 22)
PageSub.Size = UDim2.new(1, -4, 0, 14)
PageSub.Text = ""
PageSub.TextColor3 = COLORS.muted
PageSub.Font = Enum.Font.Gotham
PageSub.TextSize = 11
PageSub.TextXAlignment = Enum.TextXAlignment.Left
PageSub.ZIndex = 4
PageSub.Parent = ContentArea

local Content = Instance.new("Frame")
Content.Name = "Content"
Content.BackgroundTransparency = 1
Content.Position = UDim2.new(0, 0, 0, 46)
Content.Size = UDim2.new(1, 0, 1, -46)
Content.ClipsDescendants = true
Content.ZIndex = 3
Content.Parent = ContentArea

local pages = {}
local tabButtons = {}
local tabOrder = {}
local tabNames = {"MOVEMENT", "COMBAT", "KEYBINDS", "VISUALS", "SETTINGS"}
local tabBlurbs = {
MOVEMENT = "speeds, teleports and jump",
COMBAT = "steal, aimbot and counters",
KEYBINDS = "bind anything to a key",
VISUALS = "esp, world and lighting",
SETTINGS = "menu, intro and config",
}
local activeTab = "MOVEMENT"

function addPage(name)
local page = Instance.new("ScrollingFrame")
page.Name = name
page.BackgroundTransparency = 1
page.BorderSizePixel = 0
page.ScrollBarThickness = 3
page.ScrollBarImageColor3 = COLORS.accent
page.ScrollBarImageTransparency = 0.2
page.CanvasSize = UDim2.new(0, 0, 0, 0)
page.AutomaticCanvasSize = Enum.AutomaticSize.Y
page.Size = UDim2.new(1, 0, 1, 0)
page.ZIndex = 3
page.Visible = false
page.Parent = Content
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 2)
pad.PaddingBottom = UDim.new(0, 18)
pad.PaddingRight = UDim.new(0, 10)
pad.Parent = page
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 7)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = page
pages[name] = page
return page
end

local function placeTabIndicator(name, instant)
local index = tabOrder[name]
if not index then return end
local y = (index - 1) * (TAB_H + TAB_GAP) - Tabs.CanvasPosition.Y + (TAB_H - 22) / 2
local target = UDim2.new(0, 0, 0, y)
if instant then
TabIndicator.Position = target
else
TweenService:Create(TabIndicator, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = target}):Play()
end
end

function setTab(name)
activeTab = name
for pageName, page in pairs(pages) do
page.Visible = pageName == name
end
for tabName, btn in pairs(tabButtons) do
local on = tabName == name
btn.BackgroundTransparency = on and 0 or 0.45
local lbl = btn:FindFirstChild("TabLabel")
if lbl then
tween(lbl, {TextColor3 = on and COLORS.white or COLORS.textDim})
end
local st = btn:FindFirstChildOfClass("UIStroke")
if st then
st.Transparency = on and 0.15 or 0.6
st.Color = on and COLORS.accent or COLORS.strokeSoft
end
end
PageTitle.Text = name
PageSub.Text = tabBlurbs[name] or ""
placeTabIndicator(name)
end

for index, name in ipairs(tabNames) do
addPage(name)
tabOrder[name] = index
local btn = Instance.new("TextButton")
btn.Name = name
btn.Size = UDim2.new(1, 0, 0, TAB_H)
btn.BackgroundColor3 = COLORS.row
btn.BackgroundTransparency = 0.45
btn.BorderSizePixel = 0
btn.Text = ""
btn.AutoButtonColor = false
btn.LayoutOrder = index
btn.ZIndex = 4
btn.Parent = Tabs
corner(btn, 9)
stroke(btn, COLORS.strokeSoft, 1, 0.6)
local lbl = Instance.new("TextLabel")
lbl.Name = "TabLabel"
lbl.BackgroundTransparency = 1
lbl.Position = UDim2.new(0, 18, 0, 0)
lbl.Size = UDim2.new(1, -24, 1, 0)
lbl.Text = name
lbl.TextColor3 = COLORS.textDim
lbl.Font = Enum.Font.GothamBold
lbl.TextSize = 12
lbl.TextXAlignment = Enum.TextXAlignment.Left
lbl.ZIndex = 5
lbl.Parent = btn
tabButtons[name] = btn
btn.MouseEnter:Connect(function()
if activeTab ~= name then
tween(btn, {BackgroundTransparency = 0.15})
tween(lbl, {TextColor3 = COLORS.white})
end
end)
btn.MouseLeave:Connect(function()
if activeTab ~= name then
tween(btn, {BackgroundTransparency = 0.45})
tween(lbl, {TextColor3 = COLORS.textDim})
end
end)
btn.MouseButton1Click:Connect(function()
setTab(name)
end)
end

Tabs:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
placeTabIndicator(activeTab, true)
end)

function section(parent, text, order)
local label = Instance.new("TextLabel")
label.Name = text
label.BackgroundTransparency = 1
label.Text = text
label.TextColor3 = COLORS.textDim
label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
label.TextStrokeTransparency = 0.22
label.TextSize = 11
label.Font = Enum.Font.GothamBlack
label.TextXAlignment = Enum.TextXAlignment.Left
label.Size = UDim2.new(1, -6, 0, 18)
label.LayoutOrder = order
label.ZIndex = 8
label.Parent = parent
local rule = Instance.new("Frame")
rule.Name = "Rule"
rule.AnchorPoint = Vector2.new(0, 1)
rule.Position = UDim2.new(0, 0, 1, 0)
rule.Size = UDim2.new(1, 0, 0, 1)
rule.BackgroundColor3 = COLORS.accent
rule.BorderSizePixel = 0
rule.ZIndex = 8
rule.Parent = label
aceGradient(rule, ColorSequence.new(COLORS.accent, COLORS.accent), 0, NumberSequence.new({
NumberSequenceKeypoint.new(0, 0.25),
NumberSequenceKeypoint.new(0.4, 0.75),
NumberSequenceKeypoint.new(1, 1),
}))
return label
end
function baseRow(parent, labelText, order)
local row = Instance.new("Frame")
row.Name = labelText
row.BackgroundColor3 = COLORS.row
row.BackgroundTransparency = 0.18
row.Size = UDim2.new(1, -4, 0, 40)
row.BorderSizePixel = 0
row.LayoutOrder = order
row.ZIndex = 4
row.Parent = parent
corner(row, 9)
stroke(row, COLORS.strokeSoft, 1.15, 0.38)
local label = Instance.new("TextLabel")
label.Name = "Label"
label.BackgroundTransparency = 1
label.Text = labelText
label.TextColor3 = Color3.fromRGB(245, 245, 255)
label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
label.TextStrokeTransparency = 0.25
label.TextSize = 13
label.Font = Enum.Font.GothamMedium
label.TextXAlignment = Enum.TextXAlignment.Left
label.Position = UDim2.new(0, 14, 0, 0)
label.Size = UDim2.new(1, -132, 1, 0)
label.ZIndex = 5
label.Parent = row
local rail = Instance.new("Frame")
rail.Name = "Rail"
rail.AnchorPoint = Vector2.new(0, 0.5)
rail.Position = UDim2.new(0, 0, 0.5, 0)
rail.Size = UDim2.new(0, 2, 1, -14)
rail.BackgroundColor3 = COLORS.accent
rail.BackgroundTransparency = 1
rail.BorderSizePixel = 0
rail.ZIndex = 6
rail.Parent = row
row.MouseEnter:Connect(function()
tween(row, {BackgroundTransparency = 0.06, BackgroundColor3 = COLORS.cardHover})
tween(rail, {BackgroundTransparency = 0})
end)
row.MouseLeave:Connect(function()
tween(row, {BackgroundTransparency = 0.18, BackgroundColor3 = COLORS.row})
tween(rail, {BackgroundTransparency = 1})
end)
return row
end
function textboxRow(parent, labelText, value, order)
local row = baseRow(parent, labelText, order)
local box = Instance.new("TextBox")
box.Name = "ValueBox"
box.BackgroundColor3 = COLORS.accentDeep
box.BackgroundTransparency = 0.05
box.Text = tostring(value or "")
box.TextColor3 = COLORS.white
box.TextSize = 12
box.Font = Enum.Font.GothamSemibold
box.ClearTextOnFocus = false
box.Size = UDim2.new(0, 58, 0, 24)
box.Position = UDim2.new(1, -68, 0.5, -12)
box.BorderSizePixel = 0
box.ZIndex = 6
box.Parent = row
corner(box, 7)
local boxStroke = Instance.new("UIStroke")
boxStroke.Color = COLORS.accent
boxStroke.Thickness = 1
boxStroke.Transparency = 0.4
boxStroke.Parent = box
return row, box
end
function toggleRow(parent, labelText, default, order)
local row = baseRow(parent, labelText, order)
local button = Instance.new("TextButton")
button.Name = "ToggleButton"
button.BackgroundTransparency = 1
button.Text = ""
button.Size = UDim2.new(1, 0, 1, 0)
button.Position = UDim2.new(0, 0, 0, 0)
button.AutoButtonColor = false
button.ZIndex = 7
button.Parent = row
local track = Instance.new("Frame")
track.Name = "Track"
track.BackgroundColor3 = COLORS.toggleBg
track.BackgroundTransparency = 0.2
track.Size = UDim2.new(0, 34, 0, 18)
track.Position = UDim2.new(1, -44, 0.5, -9)
track.BorderSizePixel = 0
track.ZIndex = 5
track.Parent = button
corner(track, 9)
stroke(track, COLORS.strokeSoft, 1, 0.45)
local trackFillFrame = Instance.new("Frame")
trackFillFrame.Name = "Fill"
trackFillFrame.Size = UDim2.new(1, 0, 1, 0)
trackFillFrame.BackgroundColor3 = COLORS.accent
trackFillFrame.BackgroundTransparency = 1
trackFillFrame.BorderSizePixel = 0
trackFillFrame.ZIndex = 5
trackFillFrame.Parent = track
corner(trackFillFrame, 9)
aceGradient(trackFillFrame, ColorSequence.new(COLORS.accent, COLORS.accentDeep), 25)
local knob = Instance.new("Frame")
knob.Name = "Knob"
knob.BackgroundColor3 = COLORS.knob
knob.Size = UDim2.new(0, 13, 0, 13)
knob.Position = default and UDim2.new(1, -16, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
knob.BorderSizePixel = 0
knob.ZIndex = 6
knob.Parent = track
corner(knob, 999)
local shine = Instance.new("Frame")
shine.Name = "Shine"
shine.BackgroundColor3 = COLORS.white
shine.BackgroundTransparency = 0.72
shine.Size = UDim2.new(1, -4, 0, 4)
shine.Position = UDim2.new(0, 2, 0, 2)
shine.BorderSizePixel = 0
shine.ZIndex = 7
shine.Parent = knob
corner(shine, 4)
local state = default and true or false
local trackStroke = track:FindFirstChildOfClass("UIStroke")
local trackFill = track:FindFirstChild("Fill")
local rowStroke = row:FindFirstChildOfClass("UIStroke")
local function setVisual(on)
state = on and true or false
tween(knob, {Position = state and UDim2.new(1, -16, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)})
tween(track, {
BackgroundTransparency = state and 0.03 or 0.2,
BackgroundColor3 = state and COLORS.accentDeep or COLORS.toggleBg
})
if trackFill then
tween(trackFill, {BackgroundTransparency = state and 0 or 1})
end
-- Only ping on a real off->on flip, so a config sync does not fire a
-- burst of rings across every enabled toggle at once.
if state and track:GetAttribute("AceOn") ~= true then
aceSense(knob, COLORS.accent)
end
track:SetAttribute("AceOn", state)
if trackStroke then
tween(trackStroke, {
Color = state and COLORS.accent or COLORS.strokeSoft,
Transparency = state and 0.05 or 0.45,
Thickness = state and 1.25 or 1
})
end
if rowStroke then
tween(rowStroke, {
Color = state and COLORS.accent or COLORS.strokeSoft,
Transparency = state and 0.12 or 0.38,
Thickness = state and 1.25 or 1.15
})
end
tween(row, {BackgroundTransparency = state and 0.04 or 0.18})
end
setVisual(state)
button.Activated:Connect(function()
end)
return row, setVisual
end
_G.AceActionToggleRow = function(parent, labelText, default, order)
local row = baseRow(parent, labelText, order)
local button = Instance.new("TextButton")
button.Name = "ToggleButton"
button.BackgroundTransparency = 1
button.Text = ""
button.Size = UDim2.new(1, 0, 1, 0)
button.Position = UDim2.new(0, 0, 0, 0)
button.AutoButtonColor = false
button.ZIndex = 7
button.Parent = row
local track = Instance.new("Frame")
track.Name = "Track"
track.BackgroundColor3 = COLORS.toggleBg
track.BackgroundTransparency = 0.2
track.Size = UDim2.new(0, 34, 0, 18)
track.Position = UDim2.new(1, -44, 0.5, -9)
track.BorderSizePixel = 0
track.ZIndex = 5
track.Parent = button
corner(track, 9)
stroke(track, COLORS.strokeSoft, 1, 0.45)
local trackFillFrame = Instance.new("Frame")
trackFillFrame.Name = "Fill"
trackFillFrame.Size = UDim2.new(1, 0, 1, 0)
trackFillFrame.BackgroundColor3 = COLORS.accent
trackFillFrame.BackgroundTransparency = 1
trackFillFrame.BorderSizePixel = 0
trackFillFrame.ZIndex = 5
trackFillFrame.Parent = track
corner(trackFillFrame, 9)
aceGradient(trackFillFrame, ColorSequence.new(COLORS.accent, COLORS.accentDeep), 25)
local knob = Instance.new("Frame")
knob.Name = "Knob"
knob.BackgroundColor3 = COLORS.knob
knob.Size = UDim2.new(0, 13, 0, 13)
knob.Position = default and UDim2.new(1, -16, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
knob.BorderSizePixel = 0
knob.ZIndex = 6
knob.Parent = track
corner(knob, 999)
local shine = Instance.new("Frame")
shine.Name = "Shine"
shine.BackgroundColor3 = COLORS.white
shine.BackgroundTransparency = 0.72
shine.Size = UDim2.new(1, -4, 0, 4)
shine.Position = UDim2.new(0, 2, 0, 2)
shine.BorderSizePixel = 0
shine.ZIndex = 7
shine.Parent = knob
corner(shine, 4)
local trackStroke = track:FindFirstChildOfClass("UIStroke")
local trackFill = track:FindFirstChild("Fill")
local rowStroke = row:FindFirstChildOfClass("UIStroke")
local function setVisual(on)
local state = on and true or false
tween(knob, {Position = state and UDim2.new(1, -16, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)})
tween(track, {
BackgroundTransparency = state and 0.03 or 0.2,
BackgroundColor3 = state and COLORS.accentDeep or COLORS.toggleBg
})
if trackFill then
tween(trackFill, {BackgroundTransparency = state and 0 or 1})
end
-- Only ping on a real off->on flip, so a config sync does not fire a
-- burst of rings across every enabled toggle at once.
if state and track:GetAttribute("AceOn") ~= true then
aceSense(knob, COLORS.accent)
end
track:SetAttribute("AceOn", state)
if trackStroke then
tween(trackStroke, {
Color = state and COLORS.accent or COLORS.strokeSoft,
Transparency = state and 0.05 or 0.45,
Thickness = state and 1.25 or 1
})
end
if rowStroke then
tween(rowStroke, {
Color = state and COLORS.accent or COLORS.strokeSoft,
Transparency = state and 0.12 or 0.38,
Thickness = state and 1.25 or 1.15
})
end
tween(row, {BackgroundTransparency = state and 0.04 or 0.18})
end
setVisual(default)
return row, setVisual, button
end
function dropdownRow(parent, labelText, value, order)
local row = baseRow(parent, labelText, order)
local select = Instance.new("TextButton")
select.Name = "Dropdown"
select.BackgroundColor3 = COLORS.row2
select.BackgroundTransparency = 0.05
select.Text = tostring(value or "None") .. "  ▼"
select.TextColor3 = COLORS.white
select.TextSize = 11
select.Font = Enum.Font.GothamSemibold
select.Size = UDim2.new(0, 70, 0, 24)
select.Position = UDim2.new(1, -80, 0.5, -12)
select.BorderSizePixel = 0
select.ZIndex = 6
select.Parent = row
corner(select, 7)
stroke(select, COLORS.strokeSoft, 1, 0.45)
return row, select
end
local animationPackValueLabel = nil

-- ---------------------------------------------------------------- demo rows
-- Everything below is an example: delete it and build your own pages.

do
local page = pages.MOVEMENT
section(page, "SPEEDS", 1)

local _, normalBox = textboxRow(page, "Normal Speed", "70", 2)
normalBox.FocusLost:Connect(function()
local value = tonumber(normalBox.Text)
if not value then
normalBox.Text = "70"
return
end
local humanoid = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
if humanoid then humanoid.WalkSpeed = value end
end)

textboxRow(page, "Carry Speed", "34", 3)

section(page, "JUMP", 4)

local _, setInfJump, infJumpButton = _G.AceActionToggleRow(page, "Infinite Jump", false, 5)
local infJump = false
infJumpButton.Activated:Connect(function()
infJump = not infJump
setInfJump(infJump)
end)
UserInputService.JumpRequest:Connect(function()
if not infJump then return end
local humanoid = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

dropdownRow(page, "Walk Style", "Default", 6)
end

setTab("MOVEMENT")
