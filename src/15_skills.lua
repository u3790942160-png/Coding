-- @module skills
-- Touch-level moves: flicks, pokes, juggling. All of them go through the
-- backend, so they work on whichever path the executor and build allow.
local Svc  = _R("svc")
local Cfg  = _R("cfg")
local Util = _R("util")
local AM   = _R("amath")
local R    = _R("resolve")
local BE   = _R("backend")
local Notify = _R("notify")

local Skills = {}

local lastPoke = 0
local lastJuggle = 0
local lastSneaky = 0

local function ballAirborne(ball, hrp)
	return (ball.Position.Y - hrp.Position.Y) > 2
end

-- ── Sneaky ───────────────────────────────────────────────────────────
-- A lifted flick. Air Only holds it back until the ball is off the deck,
-- Auto Adapt scales the power to the distance left to the goal.
function Skills.Sneaky(force)
	local s = Cfg.s.skills
	local ball = R.Ball()
	local hrp = Svc.HRP()
	if not ball or not hrp then return false end

	local now = Util.Now()
	if not force and (now - lastSneaky) < 0.25 then return false end
	lastSneaky = now

	if s.sneakyAirOnly and not force and not ballAirborne(ball, hrp) then return false end

	local power = s.sneakyPower
	if s.sneakyAuto then
		local goal = R.enemyGoal
		local reference = goal and (goal.cf.Position - ball.Position).Magnitude or 60
		power = Util.Clamp(reference * 0.55, s.sneakyPower * 0.5, s.sneakyPower * 2.0)
	end

	local look = hrp.CFrame.LookVector
	local lift = Util.Clamp(s.sneakyLift, 0, 1)
	local vel = look * (power * (1 - lift)) + AM.UP * (power * lift * 2.2)
	if not AM.Finite(vel) then return false end

	local ok = BE.Launch(vel, power)
	return ok
end

function Skills.StepSneaky(dt, now)
	local s = Cfg.s.skills
	if not s.sneaky then return end
	local ball = R.Ball()
	local hrp = Svc.HRP()
	if not ball or not hrp then return end
	if (ball.Position - hrp.Position).Magnitude > Cfg.s.reach.radius then return end
	if s.sneakyAirOnly and not ballAirborne(ball, hrp) then return end
	Skills.Sneaky(false)
end

-- ── Pokers ───────────────────────────────────────────────────────────
-- Many small touches a second instead of one big one. Speed is the rate,
-- power is how hard each nudge pushes.
function Skills.StepPokers(dt, now)
	local s = Cfg.s.skills
	if not s.pokers then return end
	local ball = R.Ball()
	local hrp = Svc.HRP()
	if not ball or not hrp then return end
	if (ball.Position - hrp.Position).Magnitude > Cfg.s.reach.radius then return end

	local interval = 1 / math.max(s.pokerSpeed, 1)
	if now - lastPoke < interval then return end
	lastPoke = now

	BE.TouchPulse()
	local dir = AM.SafeUnit(AM.Flat(hrp.CFrame.LookVector))
	if dir ~= AM.ZERO then
		BE.AddVelocity(dir * s.pokerPower)
	end
end

-- ── Auto Juggle ──────────────────────────────────────────────────────
-- Keep the ball bouncing above the head. Height is solved from the live
-- gravity, not from a magic impulse number.
function Skills.StepJuggle(dt, now)
	local s = Cfg.s.skills
	if not s.juggle then return end
	local ball = R.Ball()
	local hrp = Svc.HRP()
	if not ball or not hrp or ball.Anchored then return end

	local delta = ball.Position - hrp.Position
	if AM.Flat(delta).Magnitude > s.juggleReach then return end
	if delta.Y > s.juggleHeight then return end

	local vel = ball.AssemblyLinearVelocity
	if vel.Y > 1 then return end            -- still rising, leave it
	if now - lastJuggle < 0.16 then return end
	lastJuggle = now

	local g = BE.Gravity()
	local vy = math.sqrt(math.max(2 * g * math.max(s.juggleHeight, 1), 0))

	-- sticky pulls the ball back over the head instead of letting it drift
	local overhead = hrp.Position + Vector3.new(0, s.juggleHeight * 0.6, 0)
	local pull = AM.Flat(overhead - ball.Position) * (s.juggleSticky * 4)

	local newVel = Vector3.new(pull.X, vy, pull.Z)
	if AM.Finite(newVel) then
		BE.ClaimOwnership()
		BE.SetVelocity(newVel)
		BE.TouchPulse()
	end
end

-- ── Ground Shots ─────────────────────────────────────────────────────
-- Not a loop. It is a flag the aim solver reads so every shot stays low.
function Skills.GroundLift()
	if Cfg.s.skills.groundShots then return Cfg.s.skills.groundLift end
	return nil
end

function Skills.Step(dt, now)
	Skills.StepSneaky(dt, now)
	Skills.StepPokers(dt, now)
	Skills.StepJuggle(dt, now)
end

return Skills
