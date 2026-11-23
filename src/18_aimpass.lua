-- @module aimpass
-- Passing. Picks a receiver by score, then solves the same ballistics the
-- shot uses with the pass power window and lob ceiling applied.
local Svc  = _R("svc")
local Cfg  = _R("cfg")
local Util = _R("util")
local AM   = _R("amath")
local R    = _R("resolve")
local BE   = _R("backend")
local Notify = _R("notify")

local Pass = {}

local lastPass = 0
Pass.lastResult = "idle"
Pass.lastTarget = nil

-- How close an enemy gets to the pass lane before it counts as blocked.
local LANE_WIDTH = 7

local function laneClear(from, to)
	local seg = to - from
	local len = seg.Magnitude
	if len < 1 then return true, 0 end
	local dir = seg / len
	local worst = math.huge
	for _, enemy in ipairs(R.Enemies()) do
		local hrp = Svc.HRP(enemy)
		if hrp then
			local rel = hrp.Position - from
			local along = rel:Dot(dir)
			if along > 1 and along < len - 1 then
				local lateral = (rel - dir * along).Magnitude
				if lateral < worst then worst = lateral end
			end
		end
	end
	if worst == math.huge then return true, LANE_WIDTH * 2 end
	return worst >= LANE_WIDTH, worst
end

function Pass.Candidates()
	local s = Cfg.s.pass
	local list
	if s.teammatesOnly then
		list = R.Teammates()
		if #list == 0 and not R.HasTeams() then
			Notify.Once("pass_noteams", "aimpass",
				"this place exposes no teams to the client. Teammates Only has nothing to filter on; turn it off to pass to the best open player.", "warn")
		end
	else
		list = {}
		for _, p in ipairs(Svc.Others()) do
			if Svc.Alive(p) then list[#list + 1] = p end
		end
	end
	return list
end

function Pass.Pick()
	local s = Cfg.s.pass
	local ball = R.Ball()
	local hrp = Svc.HRP()
	if not ball or not hrp then return nil end

	local origin = ball.Position
	local goalPos = R.enemyGoal and R.enemyGoal.cf.Position or nil

	local best, bestScore = nil, -math.huge
	for _, p in ipairs(Pass.Candidates()) do
		local theirHrp = Svc.HRP(p)
		if theirHrp then
			local to = theirHrp.Position - origin
			local dist = to.Magnitude
			if dist > 6 and dist <= s.range then
				local score = 0
				local clear, margin = laneClear(origin, theirHrp.Position)
				if s.smartScore then
					score = score + math.min(margin, 20) * 2
					if not clear then score = score - 45 end
					if goalPos then
						local ballToGoal = (goalPos - origin).Magnitude
						local themToGoal = (goalPos - theirHrp.Position).Magnitude
						score = score + (ballToGoal - themToGoal) * 0.8
					end
					score = score - dist * 0.12
				else
					score = -dist
				end
				if score > bestScore then best, bestScore = p, score end
			end
		end
	end
	return best, bestScore
end

-- Aim point for the receiver, with through-ball lead into space.
function Pass.AimPoint(receiver)
	local s = Cfg.s.pass
	local hrp = Svc.HRP(receiver)
	if not hrp then return nil end
	local point = hrp.Position

	if s.throughBalls then
		local vel = hrp.AssemblyLinearVelocity
		local lead = vel * s.throughLead
		if R.enemyGoal then
			local toGoal = AM.Flat(R.enemyGoal.cf.Position - hrp.Position)
			if toGoal.Magnitude > 1 then
				lead = lead + AM.SafeUnit(toGoal) * (vel.Magnitude * s.throughLead + 6)
			end
		end
		if AM.Finite(lead) then point = point + Vector3.new(lead.X, 0, lead.Z) end
	end
	return point
end

-- Solve a pass that stays under the lob ceiling where it can.
local function solvePass(origin, target)
	local s = Cfg.s.pass
	local g = BE.Gravity()
	local minSpeed = AM.MinSpeed(origin, target, g)
	local loSpeed = BE.SpeedFor(s.minPower)
	local hiSpeed = BE.SpeedFor(s.maxPower)

	local speed = Util.Clamp(math.max(minSpeed * 1.05, loSpeed), loSpeed, hiSpeed)
	if speed < minSpeed then return nil, "receiver out of range at max pass power" end
	speed = AM.DragCompensate(speed, (target - origin).Magnitude, Cfg.calib.dragK)

	local vel = AM.SolveLaunch(origin, target, speed, g, true)
	if vel then
		local apex = (vel.Y * vel.Y) / (2 * math.max(g, 0.01))
		if apex <= s.maxLobHeight then return vel, "flat", speed end
		-- too high for the ceiling: push the speed up to flatten it
		local flatter = AM.SolveLaunch(origin, target, hiSpeed, g, true)
		if flatter then
			local apex2 = (flatter.Y * flatter.Y) / (2 * math.max(g, 0.01))
			if apex2 <= s.maxLobHeight then return flatter, "flattened", hiSpeed end
		end
		return vel, "over ceiling", speed
	end

	local lob = AM.SolveLaunch(origin, target, speed, g, false)
	if lob then return lob, "lob", speed end
	return nil, "no solution at this power window"
end

function Pass.Fire()
	local s = Cfg.s.pass
	local ball = R.Ball()
	if not ball then Pass.lastResult = "no ball" return false end

	local receiver = Pass.Pick()
	if not receiver then
		Pass.lastResult = "no receiver in range"
		return false
	end

	local target = Pass.AimPoint(receiver)
	if not target then Pass.lastResult = "receiver vanished" return false end

	local origin = ball.Position
	local vel, note, speed = solvePass(origin, target)
	if not vel then
		Pass.lastResult = note
		return false
	end

	local ok, backend = BE.Launch(vel, s.maxPower)
	if not ok then
		Pass.lastResult = backend
		return false
	end

	if s.curve and math.abs(s.curveAmount) > 0.01 then
		local flight = AM.FlightTime(origin, target, vel)
		local keeperPos = nil
		local blocker = R.NearestTo(origin, R.Enemies())
		if blocker then
			local bh = Svc.HRP(blocker)
			if bh then keeperPos = bh.Position end
		end
		local amount = AM.AutoCurve(origin, target, keeperPos, s.curveAmount)
		if math.abs(amount) < 0.01 then amount = s.curveAmount end
		BE.RegisterShot(amount, (speed or 60) * 1.2, math.max(flight, 0.35))
	end

	Pass.lastTarget = receiver
	Pass.lastResult = receiver.Name .. " (" .. note .. ") via " .. backend
	lastPass = Util.Now()
	return true
end

function Pass.Step(dt, now)
	if not Cfg.s.pass.enabled then return end
	local ball = R.Ball()
	local hrp = Svc.HRP()
	if not ball or not hrp then return end
	if (ball.Position - hrp.Position).Magnitude > Cfg.s.reach.triggerRange then return end
	if now - lastPass < 0.6 then return end
	Pass.Fire()
end

function Pass.Toggle()
	Cfg.s.pass.enabled = not Cfg.s.pass.enabled
	Notify.Info("aimpass", Cfg.s.pass.enabled and "on" or "off")
end

return Pass
