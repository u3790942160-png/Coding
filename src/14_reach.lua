-- @module reach
-- Reach is a touch pulse fired at a distance the game did not intend.
-- Radius is base plus whatever latency buys us, capped.
local Svc  = _R("svc")
local Cfg  = _R("cfg")
local Util = _R("util")
local AM   = _R("amath")
local R    = _R("resolve")
local BE   = _R("backend")
local Notify = _R("notify")

local Reach = {}

Reach.lastRadius = 0
Reach.lastFired = 0
local jitter = 0
local jitterUntil = 0

function Reach.Radius()
	local s = Cfg.s.reach
	local base = s.radius
	if s.adaptHighMs then
		base = AM.AdaptRadius(base, Svc.Ping(), s.adaptPerMs, s.adaptCap)
	end
	Reach.lastRadius = base
	return base
end

function Reach.TriggerRange()
	local s = Cfg.s.reach
	local base = s.triggerRange
	if s.adaptHighMs then
		base = AM.AdaptRadius(base, Svc.Ping(), s.adaptPerMs * 0.6, s.adaptCap * 0.6)
	end
	return base
end

-- Which of our parts should carry the touch. Nearest to the ball wins,
-- so a header reads as a header and a toe poke reads as a toe poke.
function Reach.SourcePart()
	local ball = R.Ball()
	if not ball then return Svc.Foot() end
	local best, bestD = nil, math.huge
	for _, p in ipairs(Svc.Parts()) do
		local d = (p.Position - ball.Position).Magnitude
		if d < bestD then best, bestD = p, d end
	end
	return best or Svc.Foot()
end

local function teammateCloser(ballPos, myDist)
	for _, p in ipairs(R.Teammates()) do
		local hrp = Svc.HRP(p)
		if hrp and (hrp.Position - ballPos).Magnitude < myDist - 2 then return true end
	end
	return false
end

local function improvesAttack(ballPos)
	if not R.enemyGoal then return true end
	local hrp = Svc.HRP()
	if not hrp then return true end
	local now = (ballPos - R.enemyGoal.cf.Position).Magnitude
	local mine = (hrp.Position - R.enemyGoal.cf.Position).Magnitude
	return mine <= now + 4
end

-- Natural mode only reaches for a ball that is actually in front of us and
-- varies its cadence, so the pulse train is not a metronome.
local function naturalGate(ballPos, now)
	local hrp = Svc.HRP()
	if not hrp then return false end
	local to = ballPos - hrp.Position
	local flat = AM.Flat(to)
	if flat.Magnitude > 0.1 then
		local dot = AM.SafeUnit(flat):Dot(hrp.CFrame.LookVector)
		if dot < -0.25 then return false end
	end
	if now > jitterUntil then
		jitter = (math.random() * 0.06) - 0.02
		jitterUntil = now + 0.35
	end
	return true
end

function Reach.Step(dt, now)
	local s = Cfg.s.reach
	if not s.enabled then return end
	local ball = R.Ball()
	if not ball then return end
	local hrp = Svc.HRP()
	if not hrp or not Svc.Alive() then return end

	local ballPos = ball.Position
	if not AM.Finite(ballPos) then return end
	local dist = (ballPos - hrp.Position).Magnitude
	local radius = Reach.Radius()

	if dist > radius then return end

	if s.priority == 3 and teammateCloser(ballPos, dist) then return end
	if s.priority == 2 and not improvesAttack(ballPos) then return end

	local rate = s.pulseRate
	if s.proNatural and not s.controlEasier then
		if not naturalGate(ballPos, now) then return end
		rate = math.max(4, rate * (1 + jitter))
	end

	local src = Reach.SourcePart()
	if BE.TouchPulseRate(rate, now, src) then
		Reach.lastFired = now
	end
end

-- Ball Hold: park the ball at a fixed offset in front of the chest.
function Reach.StepHold(dt)
	local s = Cfg.s.reach
	if not s.ballHold then return end
	local ball = R.Ball()
	local hrp = Svc.HRP()
	if not ball or not hrp then return end
	if ball.Anchored then return end

	local target = hrp.Position
		+ hrp.CFrame.LookVector * s.holdDistance
		+ Vector3.new(0, s.holdHeight, 0)
	local delta = target - ball.Position
	if delta.Magnitude > 80 then return end

	BE.ClaimOwnership()
	local desired = delta * 12 + hrp.AssemblyLinearVelocity
	if AM.Finite(desired) then
		BE.SetVelocity(desired)
	end
end

function Reach.Toggle()
	Cfg.s.reach.enabled = not Cfg.s.reach.enabled
	Notify.Info("reach", Cfg.s.reach.enabled and "on" or "off")
end

return Reach
