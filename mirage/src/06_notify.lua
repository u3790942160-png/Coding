-- @module notify
-- Toast stack in the court palette plus the Roblox core notification as a
-- fallback when our ScreenGui cannot be parented.
local Svc   = _R("svc")
local Theme = _R("theme")
local Util  = _R("util")
local Cfg   = _R("cfg")
local Env   = _R("env")

local N = {}

local root = nil
local holder = nil
local active = {}
local MAX = 5

-- Where a ScreenGui can live on this executor.
function N.GuiParent()
	if Env.gethui then
		local ok, h = pcall(Env.gethui)
		if ok and h then return h end
	end
	local ok, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok and cg then
		local can = pcall(function() local t = cg:GetChildren() return t end)
		if can then return cg end
	end
	local lp = Svc.LP
	if lp then
		local pg = lp:FindFirstChildOfClass("PlayerGui")
		if pg then return pg end
	end
	return Svc.Workspace
end

local function build()
	if root and root.Parent then return end
	root = Instance.new("ScreenGui")
	root.Name = "LC_Toast"
	root.ResetOnSpawn = false
	root.IgnoreGuiInset = true
	root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	root.DisplayOrder = 999
	root.Parent = N.GuiParent()
	if Env.protectgui then pcall(Env.protectgui, root) end

	holder = Instance.new("Frame")
	holder.Name = "Stack"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	if Svc.IsMobile() then
		holder.AnchorPoint = Vector2.new(0.5, 0)
		holder.Position = UDim2.new(0.5, 0, 0, 12)
		holder.Size = UDim2.new(0, math.floor(math.min(Svc.ViewportSize().X * 0.9, 420)), 1, -24)
	else
		holder.AnchorPoint = Vector2.new(1, 1)
		holder.Position = UDim2.new(1, -16, 1, -16)
		holder.Size = UDim2.fromOffset(330, 400)
	end
	holder.Parent = root

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Svc.IsMobile() and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = holder
end

local function toneColor(tone)
	if tone == "bad"  then return Theme.col.bad end
	if tone == "good" then return Theme.col.good end
	if tone == "warn" then return Theme.col.warn end
	return Theme.col.accent
end

local function dismiss(card)
	if not card or not card.Parent then return end
	local tw = Svc.TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	})
	tw:Play()
	for _, d in ipairs(card:GetDescendants()) do
		if d:IsA("TextLabel") then
			Svc.TweenService:Create(d, TweenInfo.new(0.18), {TextTransparency = 1}):Play()
		elseif d:IsA("Frame") then
			Svc.TweenService:Create(d, TweenInfo.new(0.18), {BackgroundTransparency = 1}):Play()
		elseif d:IsA("UIStroke") then
			Svc.TweenService:Create(d, TweenInfo.new(0.18), {Transparency = 1}):Play()
		end
	end
	task.delay(0.22, function()
		pcall(function() card:Destroy() end)
	end)
end

-- tone: "info" | "good" | "warn" | "bad"
function N.Push(title, body, tone, seconds)
	if not Cfg.s.settings.notifications then return end
	local ok = pcall(build)
	if not ok or not holder then
		pcall(function()
			Svc.StarterGui:SetCore("SendNotification", {
				Title = tostring(title), Text = tostring(body), Duration = seconds or 4,
			})
		end)
		return
	end

	while #active >= MAX do
		local oldest = table.remove(active, 1)
		dismiss(oldest)
	end

	local accent = toneColor(tone)
	local mobile = Svc.IsMobile()

	local card = Instance.new("Frame")
	card.BackgroundColor3 = Theme.col.bg1
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1, 0, 0, mobile and 62 or 56)
	card.LayoutOrder = math.floor(os.clock() * 1000) % 100000
	card.Parent = holder
	Theme.Corner(card, 6)
	Theme.Stroke(card, Theme.col.strokeLo, 1)
	Theme.PanelGradient(card)

	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = accent
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(0, 3, 1, -10)
	bar.Position = UDim2.new(0, 5, 0, 5)
	bar.Parent = card
	Theme.Corner(bar, 2)

	local head = Instance.new("TextLabel")
	head.BackgroundTransparency = 1
	head.Font = Theme.font.title
	head.TextSize = Theme.TextSize("body")
	head.TextColor3 = accent
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.Text = tostring(title)
	head.Position = UDim2.new(0, 16, 0, 6)
	head.Size = UDim2.new(1, -24, 0, 20)
	head.Parent = card

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = Theme.font.body
	text.TextSize = Theme.TextSize("small")
	text.TextColor3 = Theme.col.textDim
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.TextWrapped = true
	text.Text = tostring(body or "")
	text.Position = UDim2.new(0, 16, 0, 25)
	text.Size = UDim2.new(1, -24, 1, -30)
	text.Parent = card

	active[#active + 1] = card

	task.delay(seconds or 4.5, function()
		for i, c in ipairs(active) do
			if c == card then table.remove(active, i) break end
		end
		dismiss(card)
	end)
end

function N.Info(title, body) N.Push(title, body, "info") end
function N.Good(title, body) N.Push(title, body, "good") end
function N.Warn(title, body) N.Push(title, body, "warn") end
function N.Bad(title, body)  N.Push(title, body, "bad") end

-- Printed once per key so a gated feature cannot spam the stack.
local saidOnce = {}
function N.Once(key, title, body, tone)
	if saidOnce[key] then return end
	saidOnce[key] = true
	N.Push(title, body, tone or "warn", 6)
end

function N.ResetOnce(key)
	if key then saidOnce[key] = nil else saidOnce = {} end
end

function N.Destroy()
	active = {}
	if root then pcall(function() root:Destroy() end) end
	root, holder = nil, nil
end

return N
