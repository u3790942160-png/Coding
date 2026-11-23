-- @module special
-- Target selection, phase, farms, ball handling and the trick macros.
--
-- Frame Player is the selector the other features read: it picks one
-- player, draws a frame on them, and Phase / AimPass "selected" mode act
-- on whoever is framed.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local AM     = _R("amath")
local R      = _R("resolve")
local BE     = _R("backend")
local Aim    = _R("aimbot")
local Theme  = _R("theme")
local Notify = _R("notify")
local Env    = _R("env")

local SP = {}

SP.selected = nil
SP.phased = {}            -- part -> original CanCollide
local frameGui, frameBox, frameLabel
local lastFarm = 0
local lastSaveFarm = 0
local trickRunning = false
local maid = Util.Maid.new()

-- ── target selection ─────────────────────────────────────────────────
function SP.LookTarget()
	local cam = Svc.Camera()
	if not cam then return nil end
	local best, bestPx = nil, math.huge
	local vp = cam.ViewportSize
	local centre = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
	for _, p in ipairs(R.Enemies()) do
		local hrp = Svc.HRP(p)
		if hrp then
			local screen, visible = AM.WorldToScreen(cam, hrp.Position)
			if visible then
				local px = (screen - centre).Magnitude
				if px < bestPx then best, bestPx = p, px end
			end
		end
	end
	return best
end

function SP.CurrentTarget()
	if Cfg.s.special.phaseMode == 2 then return SP.selected end
	return SP.LookTarget()
end

function SP.SelectUnderCrosshair()
	SP.selected = SP.LookTarget()
	if SP.selected then
		Notify.Info("framed", SP.selected.Name)
	else
		Notify.Warn("framed", "nobody under the crosshair")
	end
	return SP.selected
end

-- ── Frame Player overlay ─────────────────────────────────────────────
local function ensureFrameGui()
	if frameGui and frameGui.Parent then return end
	frameGui = Instance.new("ScreenGui")
	frameGui.Name = "LC_Frame"
	frameGui.ResetOnSpawn = false
	frameGui.IgnoreGuiInset = true
	frameGui.DisplayOrder = 950
	frameGui.Parent = _R("notify").GuiParent()
	maid:Give(frameGui)

	frameBox = Instance.new("Frame")
	frameBox.BackgroundTransparency = 1
	frameBox.BorderSizePixel = 0
	frameBox.AnchorPoint = Vector2.new(0.5, 0.5)
	frameBox.Size = UDim2.fromOffset(60, 90)
	frameBox.Visible = false
	frameBox.Parent = frameGui
	Theme.Stroke(frameBox, Theme.col.gold, 2)
	Theme.Corner(frameBox, 4)

	frameLabel = Instance.new("TextLabel")
	frameLabel.BackgroundTransparency = 1
	frameLabel.Font = Theme.font.title
	frameLabel.TextSize = 14
	frameLabel.TextColor3 = Theme.col.goldHi
	frameLabel.TextStrokeTransparency = 0.4
	frameLabel.Size = UDim2.new(1, 40, 0, 16)
	frameLabel.Position = UDim2.new(0, -20, 0, -20)
	frameLabel.Text = ""
	frameLabel.Parent = frameBox
end

function SP.StepFrame()
	if not Cfg.s.special.framePlayer then
		if frameBox then frameBox.Visible = false end
		return
	end
	ensureFrameGui()
	local target = SP.CurrentTarget()
	if not target then
		frameBox.Visible = false
		return
	end
	local hrp = Svc.HRP(target)
	local cam = Svc.Camera()
	if not hrp or not cam then
		frameBox.Visible = false
		return
	end
	local head = Svc.Head(target) or hrp
	local topPos, topVis = AM.WorldToScreen(cam, head.Position + Vector3.new(0, 1.6, 0))
	local botPos, botVis = AM.WorldToScreen(cam, hrp.Position - Vector3.new(0, 3.2, 0))
	if not (topVis or botVis) then
		frameBox.Visible = false
		return
	end
	local height = math.max(math.abs(botPos.Y - topPos.Y), 20)
	local width = height * 0.6
	frameBox.Visible = true
	frameBox.Position = UDim2.fromOffset((topPos.X + botPos.X) * 0.5, (topPos.Y + botPos.Y) * 0.5)
	frameBox.Size = UDim2.fromOffset(width, height)
	local dist = (hrp.Position - (Svc.HRP() and Svc.HRP().Position or hrp.Position)).Magnitude
	frameLabel.Text = string.format("%s  %dm", target.Name, math.floor(dist))
end

-- ── Phase / Anti-Phase ───────────────────────────────────────────────
local function setCollide(plr, state)
	for _, part in ipairs(Svc.Parts(plr)) do
		if SP.phased[part] == nil then SP.phased[part] = part.CanCollide end
		pcall(function() part.CanCollide = state end)
	end
end

function SP.RestorePhase()
	for part, original in pairs(SP.phased) do
		if part and part.Parent then
			pcall(function() part.CanCollide = original end)
		end
	end
	SP.phased = {}
end

function SP.StepPhase()
	local s = Cfg.s.special

	if s.antiPhase then
		for _, p in ipairs(R.Enemies()) do
			for _, part in ipairs(Svc.Parts(p)) do
				if part.Name ~= "HumanoidRootPart" then
					pcall(function() part.CanCollide = true end)
				end
			end
		end
	end

	if not s.phase then
		if next(SP.phased) ~= nil then SP.RestorePhase() end
		return
	end

	local target = SP.CurrentTarget()
	if not target then return end
	setCollide(target, false)
	-- our own parts too, otherwise the server still wedges us on theirs
	for _, part in ipairs(Svc.Parts()) do
		if SP.phased[part] == nil then SP.phased[part] = part.CanCollide end
		pcall(function() part.CanCollide = false end)
	end
end

function SP.TogglePhase()
	Cfg.s.special.phase = not Cfg.s.special.phase
	if not Cfg.s.special.phase then SP.RestorePhase() end
	Notify.Info("phase", Cfg.s.special.phase and "on" or "off")
end

-- ── Ball handling ────────────────────────────────────────────────────
function SP.BringBall()
	local ball = R.Ball()
	local hrp = Svc.HRP()
	if not ball or not hrp then
		Notify.Warn("bring ball", "no ball or no character")
		return false
	end
	BE.ClaimOwnership()
	local target = hrp.Position + hrp.CFrame.LookVector * Cfg.s.special.bringDistance + Vector3.new(0, 3, 0)
	local ok = BE.SetCFrame(CFrame.new(target))
	BE.SetVelocity(hrp.AssemblyLinearVelocity)
	if not ok then
		-- no write permission: pull it with velocity instead
		local delta = target - ball.Position
		BE.SetVelocity(delta * 6)
	end
	return true
end

function SP.DeleteBall()
	local ball = R.Ball()
	if not ball then return false end
	-- local only: the server still has it, this clears your own render
	local ok = pcall(function() ball:Destroy() end)
	if ok then
		R.ball = nil
		R.ballTier = "unknown"
		Notify.Warn("delete ball", "removed locally; the server copy is untouched")
	end
	return ok
end

function SP.ToggleFreeze()
	local state = not Cfg.s.special.ballFrozen
	BE.Freeze(state)
	Notify.Info("ball", state and "frozen" or "released")
end

function SP.StepBallTime(dt)
	local s = Cfg.s.special
	if not s.ballTime then return end
	local ball = R.Ball()
	if not ball or ball.Anchored then return end
	local v = ball.AssemblyLinearVelocity
	if v.Magnitude < 1 then return end
	local scaled = v * s.ballTimeScale
	if scaled.Magnitude > 2000 then return end
	BE.SetVelocity(scaled)
end

-- ── Dunk ─────────────────────────────────────────────────────────────
function SP.StepDunk(dt, now)
	local s = Cfg.s.special
	if not s.dunk then return end
	local goal = R.enemyGoal
	local ball = R.Ball()
	local hrp = Svc.HRP()
	if not goal or not ball or not hrp then return end

	local toGoal = (goal.cf.Position - hrp.Position).Magnitude
	if toGoal > s.dunkRange then return end
	if (ball.Position - hrp.Position).Magnitude > Cfg.s.reach.radius then return end

	local mouth = AM.GoalCentre(goal.cf, goal.size)
	local dir = AM.SafeUnit(mouth - ball.Position)
	if dir == AM.ZERO then return end
	BE.TouchPulse()
	BE.Launch(dir * math.max(toGoal * 3, 60), Cfg.s.aim.power)
end

-- ── Farms ────────────────────────────────────────────────────────────
function SP.StepGoalFarm(dt, now)
	local s = Cfg.s.special
	if not s.goalFarm then return end
	if now - lastFarm < s.goalFarmDelay then return end
	if not R.enemyGoal then
		Notify.Once("farm_nogoal", "goal farm",
			"no enemy goal resolved. CONFIG tab: stand in the goal and press Capture Enemy Goal.", "warn")
		return
	end
	lastFarm = now
	SP.BringBall()
	task.delay(0.12, function()
		Aim.Shoot(nil)
	end)
end

function SP.StepSaveFarm(dt, now)
	local s = Cfg.s.special
	if not s.saveFarm then return end
	if now - lastSaveFarm < s.saveFarmDelay then return end
	if not R.ownGoal then
		Notify.Once("savefarm_nogoal", "save farm",
			"no own goal resolved. CONFIG tab: stand in your goal and press Capture Own Goal.", "warn")
		return
	end
	lastSaveFarm = now

	-- put the ball on a line into our own goal, then clear it on the next tick
	local ball = R.Ball()
	local hrp = Svc.HRP()
	if not ball or not hrp then return end
	BE.ClaimOwnership()
	local mouth = AM.GoalCentre(R.ownGoal.cf, R.ownGoal.size)
	local start = mouth + R.ownGoal.cf.LookVector * 26 + Vector3.new(0, 6, 0)
	BE.SetCFrame(CFrame.new(start))
	local vel = AM.SafeUnit(mouth - start) * 70
	BE.SetVelocity(vel)
end

-- ── Trick macros ─────────────────────────────────────────────────────
-- Each step is an impulse in character-local space plus a wait. They are
-- built from the same primitives as everything else, no special casing.
SP.tricks = {
	{
		name = "Rainbow Flick",
		steps = {
			{vel = Vector3.new(0, 1.0, -0.25), power = 46, wait = 0.12, spin = 14},
			{vel = Vector3.new(0, 0.45, -1.0), power = 54, wait = 0.18, spin = 8},
		},
	},
	{
		name = "Sombrero",
		steps = {
			{vel = Vector3.new(0, 1.15, 0.1), power = 40, wait = 0.22, spin = 6},
			{vel = Vector3.new(0, 0.2, -1.0), power = 62, wait = 0.10, spin = 0},
		},
	},
	{
		name = "Fake Shot",
		steps = {
			{vel = Vector3.new(0.6, 0.12, -0.8), power = 30, wait = 0.14, spin = 10},
			{vel = Vector3.new(-0.9, 0.08, -0.6), power = 58, wait = 0.12, spin = -10},
		},
	},
}

function SP.RunTrick(index)
	if trickRunning then return false end
	local trick = SP.tricks[index or Cfg.s.special.trickIndex]
	if not trick then return false end
	local hrp = Svc.HRP()
	if not hrp or not R.Ball() then
		Notify.Warn("trick", "need a character and a resolved ball")
		return false
	end

	trickRunning = true
	task.spawn(function()
		for _, step in ipairs(trick.steps) do
			local root = Svc.HRP()
			if not root then break end
			local world = root.CFrame:VectorToWorldSpace(step.vel)
			local vel = AM.SafeUnit(world) * step.power
			if AM.Finite(vel) then
				BE.TouchPulse()
				BE.Launch(vel, step.power)
				if step.spin ~= 0 then
					BE.SetSpin(AM.CurveSpin(vel, step.spin / 20, 20))
				end
			end
			task.wait(step.wait)
		end
		trickRunning = false
	end)
	Notify.Info("trick", trick.name)
	return true
end

function SP.StepTricks(dt, now)
	if not Cfg.s.special.trickOms then return end
	if trickRunning then return end
	local ball = R.Ball()
	local hrp = Svc.HRP()
	if not ball or not hrp then return end
	if (ball.Position - hrp.Position).Magnitude > Cfg.s.reach.radius then return end
	SP.RunTrick(Cfg.s.special.trickIndex)
end

function SP.Step(dt, now)
	SP.StepPhase()
	SP.StepFrame()
	SP.StepBallTime(dt)
	SP.StepDunk(dt, now)
	SP.StepGoalFarm(dt, now)
	SP.StepSaveFarm(dt, now)
	SP.StepTricks(dt, now)
end

function SP.Destroy()
	SP.RestorePhase()
	maid:Clean()
	frameGui, frameBox, frameLabel = nil, nil, nil
end

return SP
