-- @module keeper
-- Goalkeeping. The threat test is a parabola-plane intersection against
-- the goal the operator captured or the resolver derived, not a radius.
local Svc  = _R("svc")
local Cfg  = _R("cfg")
local Util = _R("util")
local AM   = _R("amath")
local R    = _R("resolve")
local BE   = _R("backend")
local Notify = _R("notify")

local GK = {}

GK.threat = nil          -- {point = Vector3, t = number}
GK.lastClear = 0
local diving = false

-- Where and when the ball crosses our goal line, if it does at all.
function GK.Predict()
	local goal = R.ownGoal
	local ball = R.Ball()
	if not goal or not ball then return nil end

	local p0 = ball.Position
	local v0 = ball.AssemblyLinearVelocity
	if not AM.Finite(p0) or not AM.Finite(v0) then return nil end

	local n = goal.cf.LookVector
	local t = AM.ParabolaPlaneTime(p0, v0, BE.Gravity(), goal.cf.Position, n)
	if not t then return nil end
	if t > Cfg.s.keeper.predictTime then return nil end

	local point = AM.ParabolaAt(p0, v0, BE.Gravity(), t)
	if not AM.Finite(point) then return nil end
	if not AM.InsideGoal(goal.cf, goal.size, point, 3) then return nil end
	return {point = point, t = t}
end

local function moveToward(point, speed)
	local hrp = Svc.HRP()
	if not hrp then return false end
	local delta = point - hrp.Position
	local flat = AM.Flat(delta)
	local dir = AM.SafeUnit(flat)
	if dir == AM.ZERO then return false end

	local vy = hrp.AssemblyLinearVelocity.Y
	-- an air save needs lift; a ground save keeps the feet down
	if delta.Y > 4 then
		vy = math.sqrt(math.max(2 * BE.Gravity() * math.min(delta.Y, 24), 0))
	end
	local newVel = dir * speed + Vector3.new(0, vy, 0)
	if not AM.Finite(newVel) then return false end
	local ok = pcall(function() hrp.AssemblyLinearVelocity = newVel end)
	return ok
end

local function clearBall()
	local ball = R.Ball()
	local hrp = Svc.HRP()
	if not ball or not hrp then return false end

	local away
	if R.enemyGoal then
		away = AM.SafeUnit(AM.Flat(R.enemyGoal.cf.Position - ball.Position))
	elseif R.ownGoal then
		away = AM.SafeUnit(AM.Flat(ball.Position - R.ownGoal.cf.Position))
	else
		away = AM.SafeUnit(AM.Flat(hrp.CFrame.LookVector))
	end
	if away == AM.ZERO then return false end

	local g = BE.Gravity()
	local speed = BE.SpeedFor(Cfg.s.aim.power)
	local vel = away * speed * 0.8 + AM.UP * math.sqrt(math.max(2 * g * 10, 0))
	BE.TouchPulse()
	local ok = BE.Launch(vel, Cfg.s.aim.power)
	return ok
end

function GK.Step(dt, now)
	local s = Cfg.s.keeper
	local ball = R.Ball()
	local hrp = Svc.HRP()
	if not ball or not hrp or not Svc.Alive() then
		GK.threat = nil
		diving = false
		return
	end

	-- Panic Reach runs whether or not the save logic fires.
	if s.panicReach and R.ownGoal then
		local dToGoal = (ball.Position - R.ownGoal.cf.Position).Magnitude
		if dToGoal <= s.panicRadius then
			BE.TouchPulseRate(20, now)
		end
	end

	if not s.autoGK and not s.autoGS then
		GK.threat = nil
		return
	end

	local threat = GK.Predict()
	GK.threat = threat
	if not threat then
		diving = false
		return
	end

	local airborne = (threat.point.Y - hrp.Position.Y) > 4
	if airborne and not s.autoGK then return end
	if not airborne and not s.autoGS then return end

	diving = true
	moveToward(threat.point, s.diveSpeed)

	local dist = (ball.Position - hrp.Position).Magnitude
	if dist <= s.touchReach and (now - GK.lastClear) > 0.25 then
		GK.lastClear = now
		clearBall()
	end
end

function GK.Toggle()
	Cfg.s.keeper.autoGK = not Cfg.s.keeper.autoGK
	Notify.Info("auto gk", Cfg.s.keeper.autoGK and "on" or "off")
end

function GK.StatusLine()
	if not R.ownGoal then return "own goal not set", "bad" end
	if GK.threat then
		return string.format("incoming in %.2fs", GK.threat.t), "gold"
	end
	return diving and "recovering" or "clear", "good"
end

return GK
