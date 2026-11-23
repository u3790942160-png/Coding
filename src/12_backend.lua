-- @module backend
-- Three ways to move the ball. Each one reports whether it can run right
-- now; callers ask for an action, not for a backend.
--
--   remote   authoritative, needs cfg.target.kickRemote + kickArgShape
--   physics  direct assembly write, needs network ownership of the ball
--   touch    firetouchinterest against the game's own kick handler
--
-- Nothing here assumes a Touch Football remote exists. If none is
-- configured the remote backend reports unavailable and stays out of the way.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local AM     = _R("amath")
local Env    = _R("env")
local R      = _R("resolve")
local Notify = _R("notify")

local BE = {}

local activeShots = {}
local lastTouchPulse = 0
local simRadiusApplied = false

-- ── availability ─────────────────────────────────────────────────────
function BE.RemoteReady()
	if Cfg.target.kickRemote == "" then return false, "kick remote unset" end
	if Cfg.target.kickArgShape == "" then return false, "arg shape unset" end
	local rem = R.FindRemote(Cfg.target.kickRemote)
	if not rem then return false, "remote '" .. Cfg.target.kickRemote .. "' not in this place" end
	return true, "ok"
end

function BE.PhysicsReady()
	local b = R.Ball()
	if not b then return false, "no ball resolved" end
	if b.Anchored then return false, "ball anchored" end
	return true, "ok"
end

function BE.TouchReady()
	if not Env.canTouch then return false, "executor has no firetouchinterest" end
	if not R.Ball() then return false, "no ball resolved" end
	if not Svc.Foot() then return false, "no character" end
	return true, "ok"
end

function BE.Report()
	local rows = {}
	local ok, why = BE.RemoteReady()  rows[#rows + 1] = {"remote", ok, why}
	ok, why = BE.PhysicsReady()       rows[#rows + 1] = {"physics", ok, why}
	ok, why = BE.TouchReady()         rows[#rows + 1] = {"touch", ok, why}
	return rows
end

-- ── ownership ────────────────────────────────────────────────────────
function BE.ClaimOwnership()
	if simRadiusApplied then return true end
	local applied = false
	if Env.setsimulationradius then
		applied = pcall(function() Env.setsimulationradius(math.huge) end)
	elseif Env.sethiddenproperty then
		applied = pcall(function()
			Env.sethiddenproperty(Svc.LP, "SimulationRadius", math.huge)
			Env.sethiddenproperty(Svc.LP, "MaximumSimulationRadius", math.huge)
		end)
	end
	simRadiusApplied = applied
	return applied
end

function BE.OwnsBall()
	return R.OwnsBall()
end

-- ── primitives ───────────────────────────────────────────────────────
function BE.SetVelocity(v)
	local b = R.Ball()
	if not b or not AM.Finite(v) then return false end
	local ok = pcall(function()
		b.AssemblyLinearVelocity = v
	end)
	if not ok then
		ok = pcall(function() b.Velocity = v end)
	end
	return ok
end

function BE.AddVelocity(v)
	local b = R.Ball()
	if not b or not AM.Finite(v) then return false end
	return BE.SetVelocity(b.AssemblyLinearVelocity + v)
end

function BE.SetSpin(w)
	local b = R.Ball()
	if not b or not AM.Finite(w) then return false end
	return pcall(function() b.AssemblyAngularVelocity = w end)
end

function BE.SetCFrame(cf)
	local b = R.Ball()
	if not b then return false end
	return pcall(function() b.CFrame = cf end)
end

function BE.Freeze(state)
	local b = R.Ball()
	if not b then return false end
	local ok = pcall(function()
		if state then
			b.AssemblyLinearVelocity = AM.ZERO
			b.AssemblyAngularVelocity = AM.ZERO
		end
		b.Anchored = state and true or false
	end)
	Cfg.s.special.ballFrozen = state and true or false
	return ok
end

-- ── touch pulse: this is what "reach" actually is ────────────────────
function BE.TouchPulse(fromPart)
	if not Env.canTouch then return false end
	local b = R.Ball()
	if not b then return false end
	local src = fromPart or Svc.Foot()
	if not src then return false end
	local ok = pcall(function()
		Env.firetouchinterest(src, b, 0)
		Env.firetouchinterest(src, b, 1)
	end)
	return ok
end

function BE.TouchPulseRate(rate, now, fromPart)
	local interval = 1 / math.max(rate, 1)
	if now - lastTouchPulse < interval then return false end
	lastTouchPulse = now
	return BE.TouchPulse(fromPart)
end

-- ── remote kick ──────────────────────────────────────────────────────
local function fireRemote(velocity, power)
	local rem = R.FindRemote(Cfg.target.kickRemote)
	if not rem then return false end
	local shape = Cfg.target.kickArgShape
	local dir = AM.SafeUnit(velocity)
	local ok = pcall(function()
		if shape == "dir_power" then
			rem:FireServer(dir, power)
		elseif shape == "vector" then
			rem:FireServer(velocity)
		elseif shape == "cframe" then
			local b = R.Ball()
			local origin = b and b.Position or Svc.HRP().Position
			rem:FireServer(CFrame.lookAt(origin, origin + dir), power)
		else
			error("unsupported kickArgShape")
		end
	end)
	return ok
end

-- ── the one call features make ───────────────────────────────────────
-- velocity is the full launch vector from amath. power is the game-facing
-- scalar for the remote path. Returns ok, backendName.
function BE.Launch(velocity, power)
	if not AM.Finite(velocity) then return false, "bad velocity" end

	local remoteOk = BE.RemoteReady()
	if remoteOk then
		if fireRemote(velocity, power or velocity.Magnitude) then
			return true, "remote"
		end
	end

	local physOk = BE.PhysicsReady()
	if physOk then
		BE.ClaimOwnership()
		if BE.SetVelocity(velocity) then
			return true, "physics"
		end
	end

	local touchOk = BE.TouchReady()
	if touchOk then
		if BE.TouchPulse() then
			-- The game's own handler decides the vector here; we can still
			-- bias it by writing velocity immediately after the pulse.
			BE.SetVelocity(velocity)
			return true, "touch"
		end
	end

	return false, "no backend available"
end

-- ── curve controller ─────────────────────────────────────────────────
-- A curve is not baked into the launch. It is lateral acceleration applied
-- each frame while the shot is in the air and we can still write the ball.
function BE.RegisterShot(amount, strength, seconds)
	if math.abs(amount) < 0.01 then return end
	activeShots[#activeShots + 1] = {
		ball = R.Ball(),
		amount = amount,
		strength = strength,
		expires = Util.Now() + (seconds or 2.5),
	}
	local b = R.Ball()
	if b then
		BE.SetSpin(AM.CurveSpin(b.AssemblyLinearVelocity, amount, 18))
	end
end

function BE.StepCurve(dt)
	if #activeShots == 0 then return end
	local now = Util.Now()
	local keep = {}
	for _, shot in ipairs(activeShots) do
		local b = shot.ball
		if b and b.Parent and now < shot.expires then
			local v = b.AssemblyLinearVelocity
			if v.Magnitude > 2 then
				local accel = AM.CurveAccel(v, shot.amount, shot.strength)
				pcall(function()
					b.AssemblyLinearVelocity = v + accel * dt
				end)
				keep[#keep + 1] = shot
			end
		end
	end
	activeShots = keep
end

function BE.ClearShots()
	activeShots = {}
end

-- ── helpers used by several features ─────────────────────────────────
function BE.Gravity()
	local g = Svc.Workspace.Gravity
	if type(g) ~= "number" or g ~= g then return 196.2 end
	return g * Cfg.s.aim.gravityScale
end

-- Launch speed for a power slider reading, using calibration when it has
-- been run and the raw slider when it has not.
function BE.SpeedFor(power)
	if Cfg.calib.done and Cfg.calib.powerToStud > 0 then
		return power * Cfg.calib.powerToStud
	end
	return power
end

function BE.DistanceToBall()
	local b = R.Ball()
	local hrp = Svc.HRP()
	if not b or not hrp then return math.huge end
	return (b.Position - hrp.Position).Magnitude
end

return BE
