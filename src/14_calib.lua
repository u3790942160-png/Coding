-- @module calib
-- Measures what the config refuses to guess: gravity in force here, the
-- velocity decay the game applies to the ball, and how many studs/s one
-- unit of the power slider actually produces.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local AM     = _R("amath")
local R      = _R("resolve")
local BE     = _R("backend")
local Notify = _R("notify")

local C = {}

C.running = false
C.lastError = ""

local function sampleSpeed()
	local b = R.Ball()
	if not b then return nil end
	local v = b.AssemblyLinearVelocity
	if not AM.Finite(v) then return nil end
	return v.Magnitude
end

-- Fit v(t) = v0 * exp(-k t) from two samples.
local function fitDecay(v1, t1, v2, t2)
	if v1 <= 0.5 or v2 <= 0.5 then return 0 end
	if t2 <= t1 then return 0 end
	local ratio = v1 / v2
	if ratio <= 0 then return 0 end
	local k = math.log(ratio) / (t2 - t1)
	if k ~= k or k < 0 or k > 8 then return 0 end
	return k
end

function C.Run()
	if C.running then return end
	local ball = R.Ball()
	if not ball then
		C.lastError = "no ball resolved"
		Notify.Warn("calibration", "no ball resolved. open CONFIG and pin one.")
		return
	end
	if ball.Anchored then
		C.lastError = "ball anchored"
		Notify.Warn("calibration", "ball is anchored. unfreeze it first.")
		return
	end

	C.running = true
	task.spawn(function()
		local okAll = true
		local gravity = Svc.Workspace.Gravity
		local samples = 0

		BE.ClaimOwnership()
		local wasFrozen = Cfg.s.special.ballFrozen
		if wasFrozen then BE.Freeze(false) end

		-- 1. decay constant from a flat launch
		local launch = Vector3.new(90, 0, 0)
		local hrp = Svc.HRP()
		if hrp then
			launch = hrp.CFrame.LookVector * 90 + Vector3.new(0, 6, 0)
		end
		if not BE.SetVelocity(launch) then
			okAll = false
			C.lastError = "cannot write ball velocity (no ownership, no physics backend)"
		else
			task.wait(0.12)
			local v1 = sampleSpeed()
			local t1 = 0.12
			task.wait(0.28)
			local v2 = sampleSpeed()
			local t2 = 0.40
			if v1 and v2 then
				local k = fitDecay(v1, t1, v2, t2)
				Cfg.calib.dragK = k
				samples = samples + 2
			else
				okAll = false
				C.lastError = "velocity sample failed"
			end
		end

		-- 2. power scale. Only meaningful where the game decides the kick;
		--    on the physics backend one power unit is one stud/s by build.
		local remoteOk = BE.RemoteReady()
		local touchOk = BE.TouchReady()
		if remoteOk or touchOk then
			BE.SetVelocity(AM.ZERO)
			task.wait(0.1)
			local probePower = 50
			local dir = Vector3.new(0, 0, -1)
			if hrp then dir = hrp.CFrame.LookVector end
			BE.Launch(dir * probePower, probePower)
			task.wait(0.08)
			local v3 = sampleSpeed()
			if v3 and v3 > 1 then
				Cfg.calib.powerToStud = v3 / probePower
				samples = samples + 1
			else
				Cfg.calib.powerToStud = 1
			end
		else
			Cfg.calib.powerToStud = 1
		end

		Cfg.calib.gravity = gravity
		Cfg.calib.sampleCount = samples
		Cfg.calib.stamp = Util.Stamp()
		Cfg.calib.done = okAll and samples > 0

		if wasFrozen then BE.Freeze(true) end
		C.running = false

		if Cfg.calib.done then
			Notify.Good("calibration", string.format(
				"g=%.1f  drag k=%.3f  power=%.2f studs/unit",
				Cfg.calib.gravity, Cfg.calib.dragK, Cfg.calib.powerToStud))
		else
			Notify.Bad("calibration", C.lastError ~= "" and C.lastError or "no usable samples")
		end
	end)
end

function C.Reset()
	Cfg.calib.done = false
	Cfg.calib.dragK = 0
	Cfg.calib.powerToStud = 0
	Cfg.calib.gravity = 0
	Cfg.calib.sampleCount = 0
	Cfg.calib.stamp = ""
end

function C.Line()
	if not Cfg.calib.done then return "uncalibrated", "bad" end
	return string.format("g %.0f | k %.3f | %.2f s/u | %s",
		Cfg.calib.gravity, Cfg.calib.dragK, Cfg.calib.powerToStud, Cfg.calib.stamp), "good"
end

return C
