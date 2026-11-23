-- @module aimbot
-- Shot solving. Everything here is arithmetic on live reads: ball position,
-- live gravity, the goal the resolver found or the operator captured.
local Svc  = _R("svc")
local Cfg  = _R("cfg")
local Util = _R("util")
local AM   = _R("amath")
local R    = _R("resolve")
local BE   = _R("backend")
local Skills = _R("skills")
local Notify = _R("notify")

local Aim = {}

local lastShot = 0
local rng = Random.new()
Aim.lastResult = "idle"

-- ── goal choice ──────────────────────────────────────────────────────
function Aim.AttackGoal()
	if Cfg.s.aim.autoDetectGoal then
		R.ScanGoals(false)
		-- the goal we are facing is the one we are shooting at
		local hrp = Svc.HRP()
		if hrp and #R.goals >= 2 then
			local best, bestDot = nil, -2
			for _, g in ipairs(R.goals) do
				local to = AM.Flat(g.cf.Position - hrp.Position)
				if to.Magnitude > 1 then
					local dot = AM.SafeUnit(to):Dot(hrp.CFrame.LookVector)
					if dot > bestDot then best, bestDot = g, dot end
				end
			end
			if best and bestDot > 0 then return best end
		end
	end
	return R.enemyGoal
end

function Aim.TargetPoint(goal)
	if not goal then return nil end
	local s = Cfg.s.aim
	local keeper = R.EnemyKeeper()
	local keeperPos = nil
	if keeper then
		local hrp = Svc.HRP(keeper)
		if hrp then keeperPos = hrp.Position end
	end

	local point
	if s.topCorner then
		point = AM.GoalCorner(goal.cf, goal.size, s.cornerInset, 0, keeperPos)
	else
		point = AM.GoalCentre(goal.cf, goal.size)
	end

	local lift = Skills.GroundLift()
	if lift then
		-- ground shots: drop the aim point to just above the line
		local l = goal.cf:PointToObjectSpace(point)
		point = goal.cf:PointToWorldSpace(Vector3.new(l.X, goal.size.Y * lift, l.Z))
	end

	local missed = false
	point, missed = AM.ApplyMiss(point, goal.cf, goal.size, s.missChance, rng)
	return point, missed, keeperPos
end

-- ── curve choice ─────────────────────────────────────────────────────
function Aim.CurveAmount(origin, target, keeperPos)
	local s = Cfg.s.aim
	if not s.curve then return 0 end
	if s.curveRandom then
		return rng:NextNumber(-s.curveAmount, s.curveAmount)
	end
	if s.curveAuto then
		local auto = AM.AutoCurve(origin, target, keeperPos, s.curveAmount)
		if math.abs(auto) > 0.01 then return auto end
	end
	-- fixed bend away from the keeper's side
	local sign = 1
	if keeperPos then
		local toT = AM.Flat(target - origin)
		if toT.Magnitude > 0.1 then
			local dir = AM.SafeUnit(toT)
			local side = dir:Cross(AM.UP):Dot(AM.Flat(keeperPos - origin))
			if side < 0 then sign = -1 end
		end
	end
	return sign * s.curveAmount
end

-- ── the shot ─────────────────────────────────────────────────────────
-- profile: nil for a normal shot, "nero" for the lifted power shot,
-- "header" for a head-height contact.
function Aim.Shoot(profile)
	local s = Cfg.s.aim
	local ball = R.Ball()
	if not ball then
		Aim.lastResult = "no ball"
		return false
	end
	local goal = Aim.AttackGoal()
	if not goal then
		Aim.lastResult = "no goal"
		return false
	end

	local origin = ball.Position
	local target, missed, keeperPos = Aim.TargetPoint(goal)
	if not target then
		Aim.lastResult = "no target"
		return false
	end

	local power = s.power
	local speed = BE.SpeedFor(s.speed)
	local lowArc = true

	if profile == "nero" then
		power = s.neroPower
		speed = BE.SpeedFor(s.neroPower)
		lowArc = false
		target = target + Vector3.new(0, goal.size.Y * s.neroLift, 0)
	elseif profile == "header" then
		power = s.headerPower
		speed = BE.SpeedFor(s.headerPower)
		lowArc = true
	end

	local g = BE.Gravity()
	local dist = (target - origin).Magnitude
	speed = AM.DragCompensate(speed, dist, Cfg.calib.dragK)

	local minimum = AM.MinSpeed(origin, target, g)
	if speed < minimum then speed = minimum * 1.05 end

	local vel = AM.SolveLaunch(origin, target, speed, g, lowArc)
	if not vel then
		vel = AM.SolveLaunch(origin, target, speed, g, false)
	end
	if not vel then
		Aim.lastResult = "out of range at this power"
		return false
	end

	local ok, backend = BE.Launch(vel, power)
	if not ok then
		Aim.lastResult = backend
		return false
	end

	local amount = Aim.CurveAmount(origin, target, keeperPos)
	if math.abs(amount) > 0.01 then
		local flight = AM.FlightTime(origin, target, vel)
		BE.RegisterShot(amount, speed * 1.4, math.max(flight, 0.4))
	end
	if profile == "nero" then
		BE.SetSpin(AM.CurveSpin(vel, s.neroSpin, 26))
	end

	lastShot = Util.Now()
	Aim.lastResult = (missed and "miss (by design) via " or "struck via ") .. backend
	return true
end

function Aim.Nero() return Aim.Shoot("nero") end

-- ── auto triggers ────────────────────────────────────────────────────
local function canFire(now)
	local interval = 1 / math.max(Cfg.s.aim.fireRate, 0.2)
	return (now - lastShot) >= interval
end

local function inFov(point)
	local cam = Svc.Camera()
	if not cam then return true end
	local ok = AM.InFov(cam, point, Cfg.s.aim.fovDeg)
	return ok
end

function Aim.Step(dt, now)
	local s = Cfg.s.aim
	local ball = R.Ball()
	local hrp = Svc.HRP()
	if not ball or not hrp or not Svc.Alive() then return end

	local dist = (ball.Position - hrp.Position).Magnitude

	if s.autoHeader and dist <= s.headerRange then
		local head = Svc.Head()
		if head and ball.Position.Y >= head.Position.Y - 1.5 and canFire(now) then
			Aim.Shoot("header")
			return
		end
	end

	if s.autoNero and dist <= Cfg.s.reach.triggerRange and canFire(now) then
		Aim.Shoot("nero")
		return
	end

	if not s.aimbot then return end
	if dist > Cfg.s.reach.triggerRange then return end
	if not canFire(now) then return end
	if not inFov(ball.Position) then return end

	Aim.Shoot(nil)
end

-- ── Aimlock: camera follows the ball ─────────────────────────────────
function Aim.StepCamera(dt)
	if not Cfg.s.aim.aimlock then return end
	local cam = Svc.Camera()
	local ball = R.Ball()
	if not cam or not ball then return end
	local target = CFrame.lookAt(cam.CFrame.Position, ball.Position)
	cam.CFrame = AM.SmoothCFrame(cam.CFrame, target, Cfg.s.aim.aimlockSpeed * 20, dt)
end

function Aim.Toggle()
	Cfg.s.aim.aimbot = not Cfg.s.aim.aimbot
	Notify.Info("aimbot", Cfg.s.aim.aimbot and "on" or "off")
end

return Aim
