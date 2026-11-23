-- @module learn
-- Finds the kick remote instead of being told it, and says which of the
-- three ball paths is actually dead when a feature does nothing.
--
-- Two ways in:
--   Watch   arm it, kick the ball yourself, it correlates the remote send
--           with the velocity jump and reads the argument shape off the
--           real call. This is the one that produces a confirmed value.
--   Probe   fires named candidates and every remote whose name contains
--           kick / shoot / ball at the server, keeping only one that moves
--           the ball. Discovery, with a live test attached.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local AM     = _R("amath")
local Env    = _R("env")
local R      = _R("resolve")
local BE     = _R("backend")
local Notify = _R("notify")

local L = {}

L.state      = "idle"      -- idle | watching | probing
L.result     = "not run"
L.ownership  = "not tested"
L.verified   = "not verified"
L.lastSignature = ""

L.KICK_DV      = 25        -- studs/s of velocity change in one frame
L.KICK_MIN     = 12        -- studs/s the ball must end up doing
L.MATCH_WINDOW = 0.45      -- seconds to look back through the spy log
L.WATCH_LIMIT  = 25        -- seconds before the watch gives up
L.PROBE_CAP    = 12        -- most remotes a probe run will touch

local lastVel = AM.ZERO
local watchStart = 0
local autoFeaturesWere = nil

local SHAPE_ORDER = {"dir_power", "vector", "cframe", "bare"}

-- ── shape inference ──────────────────────────────────────────────────
-- Reads the argument signature off a call the game actually made.
function L.ShapeOf(ev)
	local t = ev.types or {}
	local first, second = t[1], t[2]
	if first == "Vector3" then
		if second == "number" then return "dir_power", "Vector3 + number" end
		if ev.argc == 1 then return "vector", "Vector3" end
		return "vector", "Vector3 + " .. tostring(second)
	end
	if first == "CFrame" then
		if second == "number" then return "cframe", "CFrame + number" end
		return "cframe", "CFrame"
	end
	-- a vector further along the list still tells us the call carries one
	for i = 1, #t do
		if t[i] == "Vector3" then return "", "vector at arg " .. i .. ", map it by hand" end
		if t[i] == "CFrame" then return "", "cframe at arg " .. i .. ", map it by hand" end
	end
	if ev.argc == 0 then return "bare", "no arguments" end
	return "", table.concat(t, ", ")
end

local function scoreEvent(ev)
	local score = 0
	local lower = string.lower(ev.name)
	if string.find(lower, "kick", 1, true) then score = score + 40 end
	if string.find(lower, "shoot", 1, true) then score = score + 35 end
	if string.find(lower, "ball", 1, true) then score = score + 25 end
	if string.find(lower, "strike", 1, true) then score = score + 20 end
	if ev.vector ~= nil then score = score + 30 end
	if ev.cframe ~= nil then score = score + 20 end
	if ev.number ~= nil then score = score + 10 end
	return score
end

-- ── watch ────────────────────────────────────────────────────────────
local function autoFeaturesOn()
	local s = Cfg.s
	return s.reach.enabled or s.aim.aimbot or s.aim.autoNero or s.aim.autoHeader
		or s.skills.juggle or s.skills.pokers or s.skills.sneaky
		or s.pass.enabled or s.special.dunk or s.special.goalFarm
		or s.special.trickOms or s.keeper.autoGK or s.keeper.autoGS
end

function L.Arm()
	if L.state ~= "idle" then
		Notify.Warn("learn", "already running")
		return false
	end
	if not R.InstallHook() then
		L.result = "executor cannot hook namecall"
		Notify.Bad("learn", "this executor cannot hook namecall, so the send cannot be seen. Use Probe instead.")
		return false
	end
	if not R.Ball() then
		L.result = "no ball resolved"
		Notify.Warn("learn", "no ball resolved. Pin it on this tab first.")
		return false
	end
	if autoFeaturesOn() then
		Notify.Warn("learn", "auto features are on; their kicks will be ignored, but a clean manual kick reads better.")
	end

	R.spyOn = true
	R.ClearSpy()
	L.state = "watching"
	L.result = "watching, kick the ball"
	watchStart = Util.Now()
	lastVel = R.BallVel()
	Notify.Info("learn", "armed. kick the ball once.")
	return true
end

function L.Disarm(reason)
	L.state = "idle"
	if reason then L.result = reason end
end

local function adopt(ev, how)
	local shape, signature = L.ShapeOf(ev)
	Cfg.target.kickRemote = ev.name
	Cfg.target.kickSource = how
	L.lastSignature = signature
	if shape ~= "" then
		Cfg.target.kickArgShape = shape
		L.result = ev.name .. "  [" .. shape .. "]  from " .. how
		Notify.Good("learn", ev.name .. " taking " .. signature)
	else
		Cfg.target.kickArgShape = ""
		L.result = ev.name .. "  shape unclear: " .. signature
		Notify.Warn("learn", ev.name .. " found, but its arguments are " .. signature)
	end
end

function L.Step(dt, now)
	if L.state ~= "watching" then return end

	if now - watchStart > L.WATCH_LIMIT then
		R.spyOn = false
		L.Disarm("nothing seen in " .. L.WATCH_LIMIT .. "s")
		Notify.Warn("learn", "no kick seen. Either the game does not send a remote for it, or the hook missed it.")
		return
	end

	local ball = R.Ball()
	if not ball then return end
	local v = ball.AssemblyLinearVelocity
	if not AM.Finite(v) then return end

	local dv = (v - lastVel).Magnitude
	lastVel = v

	if dv < L.KICK_DV or v.Magnitude < L.KICK_MIN then return end
	-- our own launch, not the game's
	if (now - BE.lastLaunchClock) < 0.4 then return end

	local sends = R.RecentSends(L.MATCH_WINDOW)
	if #sends == 0 then
		L.result = "ball moved but no remote send in the window"
		R.spyOn = false
		L.Disarm()
		Notify.Warn("learn",
			"the ball moved with no remote send behind it. This build kicks through physics or a touch, so the touch backend is the right path and no remote is needed.")
		return
	end

	local best, bestScore = nil, -1
	for _, ev in ipairs(sends) do
		local sc = scoreEvent(ev)
		if sc > bestScore then best, bestScore = ev, sc end
	end

	adopt(best, "watch")
	R.spyOn = false
	L.Disarm()
end

-- ── probe ────────────────────────────────────────────────────────────
local function candidateNames()
	local seen, out = {}, {}
	for _, n in ipairs(Cfg.List(Cfg.target.kickCandidates)) do
		if not seen[n] then
			seen[n] = true
			out[#out + 1] = n
		end
	end
	R.IndexRemotes()
	for _, rem in ipairs(R.remoteIndex) do
		local lower = string.lower(rem.Name)
		if (string.find(lower, "kick", 1, true)
			or string.find(lower, "shoot", 1, true)
			or string.find(lower, "ball", 1, true)
			or string.find(lower, "strike", 1, true)) and not seen[rem.Name] then
			seen[rem.Name] = true
			out[#out + 1] = rem.Name
		end
	end
	while #out > L.PROBE_CAP do table.remove(out) end
	return out
end

function L.Probe()
	if L.state ~= "idle" then
		Notify.Warn("probe", "learner is busy")
		return false
	end
	local ball = R.Ball()
	if not ball then
		L.result = "no ball resolved"
		Notify.Warn("probe", "no ball resolved")
		return false
	end

	local names = candidateNames()
	if #names == 0 then
		L.result = "no candidate remotes in this place"
		Notify.Warn("probe", "nothing in this place is named like a kick remote")
		return false
	end

	L.state = "probing"
	L.result = "probing " .. #names .. " remotes"

	task.spawn(function()
		local hrp = Svc.HRP()
		local dir = hrp and hrp.CFrame.LookVector or Vector3.new(0, 0, -1)
		local probeVel = dir * 70
		local winner, winnerShape, winnerSpeed = nil, nil, 0

		for _, name in ipairs(names) do
			for _, shape in ipairs(SHAPE_ORDER) do
				local live = R.Ball()
				if not live then break end
				local restoreCF = live.CFrame
				local restoreVel = live.AssemblyLinearVelocity
				BE.SetVelocity(AM.ZERO)
				task.wait(0.05)

				local sent = BE.FireRemoteNamed(name, shape, probeVel, 70)
				if sent then
					task.wait(0.10)
					local after = R.Ball()
					local speed = after and after.AssemblyLinearVelocity.Magnitude or 0
					if speed > 10 and speed > winnerSpeed then
						winner, winnerShape, winnerSpeed = name, shape, speed
					end
				end

				pcall(function()
					local b = R.Ball()
					if b then
						b.CFrame = restoreCF
						b.AssemblyLinearVelocity = restoreVel
					end
				end)
				if winner then break end
			end
			if winner then break end
		end

		if winner then
			Cfg.target.kickRemote = winner
			Cfg.target.kickArgShape = winnerShape
			Cfg.target.kickSource = "probe"
			L.lastSignature = winnerShape
			L.result = string.format("%s  [%s]  moved the ball at %.0f st/s", winner, winnerShape, winnerSpeed)
			Notify.Good("probe", L.result)
		else
			L.result = "no candidate moved the ball"
			Notify.Warn("probe",
				"none of " .. #names .. " candidates moved the ball. Use Watch, or accept that this build has no client kick remote.")
		end
		L.state = "idle"
	end)
	return true
end

-- ── verify ───────────────────────────────────────────────────────────
function L.Verify()
	if Cfg.target.kickRemote == "" then
		L.verified = "no remote set"
		Notify.Warn("verify", "no kick remote set")
		return false
	end
	local ball = R.Ball()
	if not ball then
		L.verified = "no ball"
		return false
	end

	task.spawn(function()
		local restoreCF = ball.CFrame
		local restoreVel = ball.AssemblyLinearVelocity
		local hrp = Svc.HRP()
		local dir = hrp and hrp.CFrame.LookVector or Vector3.new(0, 0, -1)

		BE.SetVelocity(AM.ZERO)
		task.wait(0.05)
		local sent, why = BE.FireRemoteNamed(Cfg.target.kickRemote, Cfg.target.kickArgShape, dir * 70, 70)
		if not sent then
			L.verified = "send failed: " .. tostring(why)
			Notify.Bad("verify", L.verified)
		else
			task.wait(0.12)
			local b = R.Ball()
			local speed = b and b.AssemblyLinearVelocity.Magnitude or 0
			if speed > 10 then
				L.verified = string.format("ball moved at %.0f st/s", speed)
				Notify.Good("verify", L.verified)
			else
				L.verified = string.format("sent, ball barely moved (%.1f st/s)", speed)
				Notify.Warn("verify", L.verified)
			end
		end

		pcall(function()
			local b = R.Ball()
			if b then
				b.CFrame = restoreCF
				b.AssemblyLinearVelocity = restoreVel
			end
		end)
	end)
	return true
end

-- ── ownership probe: does a velocity write survive the server? ───────
function L.OwnershipProbe()
	local ball = R.Ball()
	if not ball then
		L.ownership = "no ball"
		return false
	end
	if ball.Anchored then
		L.ownership = "ball anchored"
		return false
	end
	if ball.AssemblyLinearVelocity.Magnitude > 4 then
		L.ownership = "ball is moving, retry when it is still"
		Notify.Warn("ownership", "let the ball settle, then run this again")
		return false
	end

	task.spawn(function()
		BE.ClaimOwnership()
		local probe = Vector3.new(18, 0, 0)
		BE.SetVelocity(probe)
		task.wait(0.14)
		local b = R.Ball()
		local kept = b and Vector3.new(b.AssemblyLinearVelocity.X, 0, b.AssemblyLinearVelocity.Z).Magnitude or 0
		if kept > 5 then
			L.ownership = string.format("writes stick (%.1f st/s held)", kept)
		else
			L.ownership = "writes reverted by the server"
		end
		pcall(function()
			local live = R.Ball()
			if live then live.AssemblyLinearVelocity = AM.ZERO end
		end)
		Notify.Info("ownership", L.ownership)
	end)
	return true
end

-- ── diagnosis ────────────────────────────────────────────────────────
-- Why a given feature does nothing, named rather than guessed at.
function L.Diagnose()
	local rows = {}
	local ball = R.Ball()
	rows[#rows + 1] = {"ball", ball and (ball.Name .. " [" .. R.ballTier .. "]") or "not resolved", ball ~= nil}
	rows[#rows + 1] = {"touch backend (reach)", Env.canTouch and "firetouchinterest present" or "executor has none", Env.canTouch}
	rows[#rows + 1] = {"physics writes (sneaky, juggle)", L.ownership, string.find(L.ownership, "stick", 1, true) ~= nil}

	local remoteOk, why = BE.RemoteReady()
	rows[#rows + 1] = {"kick remote", remoteOk and (Cfg.target.kickRemote .. " [" .. Cfg.target.kickArgShape .. "]") or why, remoteOk}
	rows[#rows + 1] = {"remote verified", L.verified, string.find(L.verified, "moved", 1, true) ~= nil}

	local verdict
	if not ball then
		verdict = "nothing can run: no ball resolved. Pin it on this tab."
	elseif Env.canTouch and not remoteOk then
		verdict = "reach works through touch. Sneaky and juggle need either physics writes that stick or a kick remote."
	elseif not Env.canTouch and not remoteOk then
		verdict = "reach has no path at all: no firetouchinterest and no kick remote. Learn or probe the remote."
	elseif remoteOk and not Env.canTouch then
		verdict = "all three run through the remote. Reach will pulse through it rather than a touch."
	else
		verdict = "touch and remote are both live; all three features have a path."
	end
	return rows, verdict
end

function L.Status()
	if L.state == "watching" then
		return "watching for a kick", "gold"
	elseif L.state == "probing" then
		return L.result, "gold"
	end
	local good = Cfg.target.kickRemote ~= ""
	return L.result, good and "good" or "dim"
end

return L
