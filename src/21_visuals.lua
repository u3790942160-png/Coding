-- @module visuals
-- Everything cosmetic. All of it is local: nothing here is replicated and
-- nothing here changes what the server sees.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local AM     = _R("amath")
local R      = _R("resolve")
local Theme  = _R("theme")
local Notify = _R("notify")
local Env    = _R("env")

local V = {}

local maid = Util.Maid.new()
local gui, tracer, distLabel
local highlight = nil
local ballTrail, ballA0, ballA1 = nil, nil, nil
local bootTrails = {}
local rgbOriginal = {}
local hue = 0
local spoofPanel, spoofLines
local statsHookInstalled = false

local function ensureGui()
	if gui and gui.Parent then return end
	gui = Instance.new("ScreenGui")
	gui.Name = "LC_Visuals"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 940
	gui.Parent = _R("notify").GuiParent()
	maid:Give(gui)

	tracer = Instance.new("Frame")
	tracer.BackgroundColor3 = Theme.col.gold
	tracer.BorderSizePixel = 0
	tracer.AnchorPoint = Vector2.new(0, 0.5)
	tracer.Size = UDim2.fromOffset(0, 2)
	tracer.Visible = false
	tracer.Parent = gui

	distLabel = Instance.new("TextLabel")
	distLabel.BackgroundTransparency = 1
	distLabel.Font = Theme.font.mono
	distLabel.TextSize = 13
	distLabel.TextColor3 = Theme.col.goldHi
	distLabel.TextStrokeTransparency = 0.4
	distLabel.Size = UDim2.fromOffset(120, 16)
	distLabel.AnchorPoint = Vector2.new(0.5, 1)
	distLabel.Visible = false
	distLabel.Text = ""
	distLabel.Parent = gui
end

-- ── Ball ESP ─────────────────────────────────────────────────────────
local function clearBallEsp()
	if highlight then pcall(function() highlight:Destroy() end) highlight = nil end
	if tracer then tracer.Visible = false end
	if distLabel then distLabel.Visible = false end
end

function V.StepBallEsp()
	local s = Cfg.s.visuals
	if not s.ballEsp then
		clearBallEsp()
		return
	end
	ensureGui()
	local ball = R.Ball()
	if not ball then
		clearBallEsp()
		return
	end

	if s.ballEspBox then
		if not highlight or highlight.Adornee ~= ball or not highlight.Parent then
			if highlight then pcall(function() highlight:Destroy() end) end
			highlight = Instance.new("Highlight")
			highlight.FillColor = Theme.col.gold
			highlight.FillTransparency = 0.6
			highlight.OutlineColor = Theme.col.goldHi
			highlight.OutlineTransparency = 0
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Adornee = ball
			highlight.Parent = gui
		end
	elseif highlight then
		pcall(function() highlight:Destroy() end)
		highlight = nil
	end

	local cam = Svc.Camera()
	if not cam then return end
	local screen, visible = AM.WorldToScreen(cam, ball.Position)

	if s.ballEspTracer and visible then
		local vp = cam.ViewportSize
		local origin = Vector2.new(vp.X * 0.5, vp.Y)
		local delta = screen - origin
		tracer.Visible = true
		tracer.Position = UDim2.fromOffset(origin.X, origin.Y)
		tracer.Size = UDim2.fromOffset(delta.Magnitude, 2)
		tracer.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	else
		tracer.Visible = false
	end

	if s.ballEspDist and visible then
		local hrp = Svc.HRP()
		local d = hrp and (ball.Position - hrp.Position).Magnitude or 0
		distLabel.Visible = true
		distLabel.Position = UDim2.fromOffset(screen.X, screen.Y - 14)
		distLabel.Text = string.format("BALL  %dm", math.floor(d))
	else
		distLabel.Visible = false
	end
end

-- ── Ball trail ───────────────────────────────────────────────────────
local function clearBallTrail()
	for _, inst in ipairs({ballTrail, ballA0, ballA1}) do
		if inst then pcall(function() inst:Destroy() end) end
	end
	ballTrail, ballA0, ballA1 = nil, nil, nil
end

function V.StepBallTrail()
	local s = Cfg.s.visuals
	local ball = R.Ball()
	if not s.ballTrail or not ball then
		if ballTrail then clearBallTrail() end
		return
	end
	if ballTrail and ballTrail.Parent == ball then return end
	clearBallTrail()

	ballA0 = Instance.new("Attachment")
	ballA0.Position = Vector3.new(0, R.BallRadius(), 0)
	ballA0.Parent = ball
	ballA1 = Instance.new("Attachment")
	ballA1.Position = Vector3.new(0, -R.BallRadius(), 0)
	ballA1.Parent = ball

	ballTrail = Instance.new("Trail")
	ballTrail.Attachment0 = ballA0
	ballTrail.Attachment1 = ballA1
	ballTrail.Lifetime = 0.55
	ballTrail.MinLength = 0.1
	ballTrail.LightEmission = 1
	ballTrail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	ballTrail.Color = ColorSequence.new(Theme.col.goldHi, Theme.col.crimson)
	ballTrail.Parent = ball
end

-- ── RGB character ────────────────────────────────────────────────────
local function restoreRgb()
	for part, data in pairs(rgbOriginal) do
		if part and part.Parent then
			pcall(function()
				part.Color = data.color
				part.Material = data.material
			end)
		end
	end
	rgbOriginal = {}
end

function V.StepRgb(dt)
	local s = Cfg.s.visuals
	if not s.rgbChar then
		if next(rgbOriginal) ~= nil then restoreRgb() end
		return
	end
	hue = (hue + dt * 0.12 * math.max(s.rgbSpeed, 0.05)) % 1
	local colour = Color3.fromHSV(hue, 1, 1)
	for _, part in ipairs(Svc.Parts()) do
		if rgbOriginal[part] == nil then
			rgbOriginal[part] = {color = part.Color, material = part.Material}
		end
		pcall(function()
			part.Color = colour
			if s.rgbNeon then part.Material = Enum.Material.Neon end
		end)
	end
end

-- ── Boot trail ───────────────────────────────────────────────────────
local function clearBootTrails()
	for _, set in pairs(bootTrails) do
		for _, inst in ipairs(set) do
			if inst then pcall(function() inst:Destroy() end) end
		end
	end
	bootTrails = {}
end

function V.StepBootTrail(dt)
	local s = Cfg.s.visuals
	if not s.bootTrail then
		if next(bootTrails) ~= nil then clearBootTrails() end
		return
	end
	local char = Svc.Char()
	if not char then return end

	local footNames = {"RightFoot", "LeftFoot", "Right Leg", "Left Leg"}
	for _, name in ipairs(footNames) do
		local part = char:FindFirstChild(name)
		if part and part:IsA("BasePart") and not bootTrails[part] then
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, part.Size.Y * 0.4, 0)
			a0.Parent = part
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -part.Size.Y * 0.4, 0)
			a1.Parent = part
			local tr = Instance.new("Trail")
			tr.Attachment0 = a0
			tr.Attachment1 = a1
			tr.Lifetime = 0.5
			tr.LightEmission = 1
			tr.MinLength = 0.05
			tr.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(1, 1),
			})
			tr.Parent = part
			bootTrails[part] = {a0, a1, tr}
		end
	end

	local c1 = Color3.fromHSV(hue, 1, 1)
	local c2 = Color3.fromHSV((hue + 0.25) % 1, 1, 1)
	for part, set in pairs(bootTrails) do
		if part and part.Parent and set[3] then
			pcall(function() set[3].Color = ColorSequence.new(c1, c2) end)
		else
			bootTrails[part] = nil
		end
	end
end

-- ── Time of day ──────────────────────────────────────────────────────
local savedClock = nil
function V.StepClock()
	local s = Cfg.s.visuals
	if s.timeOfDay then
		if savedClock == nil then savedClock = Svc.Lighting.ClockTime end
		if math.abs(Svc.Lighting.ClockTime - s.clockTime) > 0.01 then
			pcall(function() Svc.Lighting.ClockTime = s.clockTime end)
		end
	elseif savedClock ~= nil then
		pcall(function() Svc.Lighting.ClockTime = savedClock end)
		savedClock = nil
	end
end

-- ── Spoof marker ─────────────────────────────────────────────────────
-- Two parts. The overlay always works. The hook into the engine stats
-- readout only exists where the executor has hookfunction.
local function ensureSpoofPanel()
	if spoofPanel and spoofPanel.Parent then return end
	ensureGui()
	spoofPanel = Instance.new("Frame")
	spoofPanel.BackgroundColor3 = Theme.col.bg0
	spoofPanel.BackgroundTransparency = 0.25
	spoofPanel.BorderSizePixel = 0
	spoofPanel.Position = UDim2.fromOffset(10, 10)
	spoofPanel.Size = UDim2.fromOffset(150, 58)
	spoofPanel.Parent = gui
	Theme.Corner(spoofPanel, 5)
	Theme.Stroke(spoofPanel, Theme.col.goldLo, 1)

	spoofLines = {}
	for i = 1, 3 do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Theme.font.mono
		l.TextSize = 13
		l.TextColor3 = Theme.col.goldHi
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Position = UDim2.fromOffset(8, 4 + (i - 1) * 17)
		l.Size = UDim2.new(1, -16, 0, 16)
		l.Text = ""
		l.Parent = spoofPanel
		spoofLines[i] = l
	end
end

local function installStatsHook()
	if statsHookInstalled or not Env.hookfunction then return end
	local ok = pcall(function()
		local item = Svc.Stats.Network.ServerStatsItem["Data Ping"]
		local original
		original = Env.hookfunction(item.GetValue, function(self)
			if Cfg.s.visuals.spoofMarker and self == item then
				return Cfg.s.visuals.spoofPing
			end
			return original(self)
		end)
	end)
	statsHookInstalled = ok
end

function V.StepSpoof()
	local s = Cfg.s.visuals
	if not s.spoofMarker then
		if spoofPanel then spoofPanel.Visible = false end
		return
	end
	ensureSpoofPanel()
	installStatsHook()
	spoofPanel.Visible = true
	spoofLines[1].Text = string.format("PING  %d ms", s.spoofPing)
	spoofLines[2].Text = string.format("CPU   %d %%", s.spoofCpu)
	spoofLines[3].Text = string.format("SENT  %d kb/s", s.spoofSent)
end

-- ── driver ───────────────────────────────────────────────────────────
function V.Step(dt)
	V.StepBallEsp()
	V.StepBallTrail()
	V.StepRgb(dt)
	V.StepBootTrail(dt)
	V.StepClock()
	V.StepSpoof()
end

function V.Destroy()
	clearBallEsp()
	clearBallTrail()
	clearBootTrails()
	restoreRgb()
	if savedClock ~= nil then
		pcall(function() Svc.Lighting.ClockTime = savedClock end)
		savedClock = nil
	end
	maid:Clean()
	gui, tracer, distLabel, spoofPanel, spoofLines = nil, nil, nil, nil, nil
end

return V
