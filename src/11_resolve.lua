-- @module resolve
-- Runtime discovery of everything the config does not know. Nothing here
-- hardcodes a Touch Football path. Every result carries a tier:
--   "confirmed"  captured by the operator in this session
--   "derived"    scored from engine-visible structure
--   "unknown"    not found; the caller gates its feature
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local AM     = _R("amath")
local Env    = _R("env")
local Notify = _R("notify")

local R = {}

R.ball = nil
R.ballTier = "unknown"
R.goals = {}            -- array of {cf = CFrame, size = Vector3, inst = Instance?, tier = string}
R.ownGoal = nil
R.enemyGoal = nil
R.fieldCentre = Vector3.new(0, 0, 0)

local lastBallScan = 0
local lastGoalScan = 0
local BALL_RESCAN = 1.0
local GOAL_RESCAN = 6.0

-- ── Ball ─────────────────────────────────────────────────────────────
local NAME_HINTS = {"ball", "football", "soccer", "pelota", "sphere", "matchball"}

local function nameScore(lower)
	local score = 0
	for _, hint in ipairs(NAME_HINTS) do
		if string.find(lower, hint, 1, true) then score = score + 40 end
	end
	for _, extra in ipairs(Cfg.List(Cfg.target.ballNames)) do
		if lower == string.lower(extra) then score = score + 200 end
	end
	return score
end

local function isCharacterPart(inst)
	local model = inst:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then return true end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return false
end

local function ballScore(part)
	if not part:IsA("BasePart") then return -1 end
	if part.Anchored then return -1 end
	if isCharacterPart(part) then return -1 end
	local size = part.Size
	local maxAxis = math.max(size.X, size.Y, size.Z)
	local minAxis = math.min(size.X, size.Y, size.Z)
	if maxAxis > 12 or maxAxis < 0.4 then return -1 end
	if minAxis <= 0 then return -1 end
	if maxAxis / minAxis > 1.6 then return -1 end

	local score = 10
	if part:IsA("Part") and part.Shape == Enum.PartType.Ball then score = score + 60 end
	if part:IsA("MeshPart") then score = score + 15 end
	score = score + nameScore(string.lower(part.Name))
	if part:GetAttribute("Ball") ~= nil then score = score + 60 end
	if part:FindFirstChildOfClass("BodyVelocity") or part:FindFirstChildOfClass("LinearVelocity") then
		score = score + 10
	end
	if part.CustomPhysicalProperties ~= nil then score = score + 5 end
	if part.AssemblyLinearVelocity.Magnitude > 0.5 then score = score + 12 end

	-- near a player is a strong hint on a pitch
	local hrp = Svc.HRP()
	if hrp then
		local d = (part.Position - hrp.Position).Magnitude
		if d < 400 then score = score + math.floor((400 - d) / 20) end
	end
	return score
end

function R.ScanBall(force)
	local now = Util.Now()
	if not force and R.ball and R.ball.Parent and (now - lastBallScan) < BALL_RESCAN then
		return R.ball
	end
	lastBallScan = now

	local best, bestScore = nil, 45
	local descendants = Svc.Workspace:GetDescendants()
	for i = 1, #descendants do
		local d = descendants[i]
		if d:IsA("BasePart") then
			local ok, s = pcall(ballScore, d)
			if ok and s > bestScore then
				best, bestScore = d, s
			end
		end
	end

	if best then
		if best ~= R.ball then
			R.ball = best
			R.ballTier = bestScore >= 150 and "confirmed" or "derived"
		end
		return R.ball
	end

	if R.ball and not R.ball.Parent then
		R.ball = nil
		R.ballTier = "unknown"
	end
	return R.ball
end

function R.Ball()
	if R.ball and R.ball.Parent then return R.ball end
	return R.ScanBall(true)
end

function R.BallPos()
	local b = R.Ball()
	if not b then return nil end
	local p = b.Position
	if not AM.Finite(p) then return nil end
	return p
end

function R.BallVel()
	local b = R.Ball()
	if not b then return AM.ZERO end
	local v = b.AssemblyLinearVelocity
	if not AM.Finite(v) then return AM.ZERO end
	return v
end

function R.BallRadius()
	local b = R.Ball()
	if not b then return 1 end
	return math.max(b.Size.X, b.Size.Y, b.Size.Z) * 0.5
end

-- True when the client can write this ball's physics, i.e. we own it.
function R.OwnsBall()
	local b = R.Ball()
	if not b then return false end
	local ok, owner = pcall(function() return b:GetNetworkOwner() end)
	if ok then return owner == Svc.LP end
	-- GetNetworkOwner is server-only on most builds; fall back to a write test.
	local ok2, result = pcall(function()
		return b.ReceiveAge == 0
	end)
	if ok2 then return result end
	return false
end

function R.PinBall(part)
	if part and part:IsA("BasePart") then
		R.ball = part
		R.ballTier = "confirmed"
		return true
	end
	return false
end

-- ── Goals ────────────────────────────────────────────────────────────
local GOAL_HINTS = {"goal", "net", "scorepart", "goalzone", "goalpart", "posts"}

local function goalNameScore(lower)
	local score = 0
	for _, hint in ipairs(GOAL_HINTS) do
		if string.find(lower, hint, 1, true) then score = score + 30 end
	end
	for _, extra in ipairs(Cfg.List(Cfg.target.goalNames)) do
		if string.find(lower, string.lower(extra), 1, true) then score = score + 150 end
	end
	return score
end

local function boundsOf(inst)
	if inst:IsA("BasePart") then return inst.CFrame, inst.Size end
	if inst:IsA("Model") then
		local ok, cf, size = pcall(function()
			local c, s = inst:GetBoundingBox()
			return c, s
		end)
		if ok and cf and size then return cf, size end
	end
	return nil, nil
end

function R.ScanGoals(force)
	local now = Util.Now()
	if not force and #R.goals >= 2 and (now - lastGoalScan) < GOAL_RESCAN then return R.goals end
	lastGoalScan = now

	local found = {}
	local seen = {}
	local descendants = Svc.Workspace:GetDescendants()
	for i = 1, #descendants do
		local d = descendants[i]
		local lower = string.lower(d.Name)
		local s = goalNameScore(lower)
		if s > 0 and not seen[d] and (d:IsA("BasePart") or d:IsA("Model")) then
			-- prefer the outermost match so we take the whole frame, not a post
			local parent = d.Parent
			local parentScore = parent and goalNameScore(string.lower(parent.Name)) or 0
			if parentScore <= 0 then
				local cf, size = boundsOf(d)
				if cf and size and size.Magnitude > 4 then
					seen[d] = true
					found[#found + 1] = {cf = cf, size = size, inst = d, score = s, tier = "derived"}
				end
			end
		end
	end

	-- keep manual captures, they outrank anything scanned
	local manual = {}
	for _, g in ipairs(R.goals) do
		if g.tier == "confirmed" then manual[#manual + 1] = g end
	end

	table.sort(found, function(a, b) return a.score > b.score end)
	local merged = {}
	for _, g in ipairs(manual) do merged[#merged + 1] = g end
	for _, g in ipairs(found) do
		if #merged >= 4 then break end
		merged[#merged + 1] = g
	end
	R.goals = merged
	R.OrientGoals()
	return R.goals
end

-- A goal's mouth must face the pitch. With two goals each looks at the
-- other; with one we look at the crowd centroid. Both are derived, not read.
function R.OrientGoals()
	local list = R.goals
	if #list == 0 then
		R.ownGoal, R.enemyGoal = nil, nil
		return
	end

	if #list >= 2 then
		R.fieldCentre = (list[1].cf.Position + list[2].cf.Position) * 0.5
	else
		local sum, count = Vector3.new(0, 0, 0), 0
		for _, p in ipairs(Svc.Players:GetPlayers()) do
			local hrp = Svc.HRP(p)
			if hrp then sum = sum + hrp.Position count = count + 1 end
		end
		if count > 0 then R.fieldCentre = sum / count else R.fieldCentre = list[1].cf.Position end
	end

	for _, g in ipairs(list) do
		local toCentre = R.fieldCentre - g.cf.Position
		if toCentre.Magnitude > 1 then
			g.cf = CFrame.lookAt(g.cf.Position, g.cf.Position + Vector3.new(toCentre.X, 0, toCentre.Z).Unit)
		end
		-- express size in the new frame: width across, height up, depth along
		local s = g.size
		local width = math.max(s.X, s.Z)
		local depth = math.min(s.X, s.Z)
		g.size = Vector3.new(width, s.Y, depth)
	end

	-- own goal is the one nearer to us when we are behind it; otherwise the
	-- nearer of the two at kickoff. Enemy goal is the other.
	local hrp = Svc.HRP()
	if hrp and #list >= 2 then
		local d1 = (list[1].cf.Position - hrp.Position).Magnitude
		local d2 = (list[2].cf.Position - hrp.Position).Magnitude
		if d1 <= d2 then
			R.ownGoal, R.enemyGoal = list[1], list[2]
		else
			R.ownGoal, R.enemyGoal = list[2], list[1]
		end
	elseif #list == 1 then
		R.ownGoal, R.enemyGoal = nil, list[1]
	end
end

-- Operator capture: stand in the mouth, face the pitch, press the button.
function R.CaptureGoal(which)
	local hrp = Svc.HRP()
	if not hrp then return false, "no character" end
	local cf = CFrame.lookAt(hrp.Position, hrp.Position + hrp.CFrame.LookVector * 10)
	local record = {
		cf = cf,
		size = Vector3.new(24, 12, 4),
		inst = nil,
		score = 1000,
		tier = "confirmed",
	}
	local replaced = false
	for i, g in ipairs(R.goals) do
		if g.capturedAs == which then
			record.capturedAs = which
			R.goals[i] = record
			replaced = true
			break
		end
	end
	if not replaced then
		record.capturedAs = which
		R.goals[#R.goals + 1] = record
	end
	if which == "own" then R.ownGoal = record else R.enemyGoal = record end
	R.OrientGoals()
	if which == "own" then R.ownGoal = record else R.enemyGoal = record end
	return true
end

function R.SwapGoals()
	R.ownGoal, R.enemyGoal = R.enemyGoal, R.ownGoal
end

function R.SetGoalSize(width, height)
	for _, g in ipairs(R.goals) do
		if g.tier == "confirmed" then
			g.size = Vector3.new(width, height, g.size.Z)
		end
	end
end

-- ── Teams ────────────────────────────────────────────────────────────
function R.HasTeams()
	local teams = game:FindFirstChildOfClass("Teams")
	if teams and #teams:GetChildren() > 1 then return true end
	for _, p in ipairs(Svc.Players:GetPlayers()) do
		if p.Team ~= nil then return true end
	end
	return false
end

function R.SameTeam(plr)
	local me = Svc.LP
	if not me or not plr then return false end
	if me.Team ~= nil or plr.Team ~= nil then
		return me.Team == plr.Team and me.Team ~= nil
	end
	return false
end

function R.Teammates()
	local out = {}
	if not R.HasTeams() then return out end
	for _, p in ipairs(Svc.Others()) do
		if R.SameTeam(p) and Svc.Alive(p) then out[#out + 1] = p end
	end
	return out
end

function R.Enemies()
	local out = {}
	local teams = R.HasTeams()
	for _, p in ipairs(Svc.Others()) do
		if Svc.Alive(p) then
			if not teams or not R.SameTeam(p) then out[#out + 1] = p end
		end
	end
	return out
end

function R.NearestTo(pos, list)
	local best, bestD = nil, math.huge
	for _, p in ipairs(list) do
		local hrp = Svc.HRP(p)
		if hrp then
			local d = (hrp.Position - pos).Magnitude
			if d < bestD then best, bestD = p, d end
		end
	end
	return best, bestD
end

-- Enemy nearest to our own goal line: the keeper for aim purposes.
function R.EnemyKeeper()
	if not R.enemyGoal then return nil end
	return R.NearestTo(R.enemyGoal.cf.Position, R.Enemies())
end

-- ── Remote index ─────────────────────────────────────────────────────
R.remoteIndex = {}

function R.IndexRemotes()
	local out = {}
	local roots = {Svc.ReplicatedStorage, Svc.Workspace}
	local rc = game:FindFirstChild("ReplicatedFirst")
	if rc then roots[#roots + 1] = rc end
	for _, root in ipairs(roots) do
		local ok, children = pcall(function() return root:GetDescendants() end)
		if ok then
			for _, d in ipairs(children) do
				if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
					out[#out + 1] = d
				end
			end
		end
	end
	R.remoteIndex = out
	return out
end

function R.FindRemote(name)
	if type(name) ~= "string" or name == "" then return nil end
	if #R.remoteIndex == 0 then R.IndexRemotes() end
	for _, rem in ipairs(R.remoteIndex) do
		if rem.Name == name then return rem end
	end
	-- a second pass in case it appeared after the index was built
	R.IndexRemotes()
	for _, rem in ipairs(R.remoteIndex) do
		if rem.Name == name then return rem end
	end
	return nil
end

-- ── Remote spy + deny, one namecall hook for both ────────────────────
R.spyOn = false
R.spyLog = {}
R.SPY_MAX = 60
local hookInstalled = false
local oldNamecall = nil

local function summarise(value)
	local t = typeof(value)
	if t == "Instance" then return value.ClassName .. "(" .. value.Name .. ")" end
	if t == "Vector3" then
		return string.format("V3(%.1f,%.1f,%.1f)", value.X, value.Y, value.Z)
	end
	if t == "CFrame" then
		local p = value.Position
		return string.format("CF(%.1f,%.1f,%.1f)", p.X, p.Y, p.Z)
	end
	if t == "number" then return string.format("%.3f", value) end
	if t == "boolean" then return tostring(value) end
	if t == "string" then
		if #value > 24 then return '"' .. string.sub(value, 1, 24) .. '..."' end
		return '"' .. value .. '"'
	end
	if t == "table" then return "table" end
	return t
end

-- Structured record for the learner, plus the readable line for the UI.
R.spyEvents = {}
R.SPY_EVENTS_MAX = 120

local function record(name, method, args)
	local parts = {}
	local types = {}
	local firstVector, firstCFrame, firstNumber = nil, nil, nil
	for i = 1, args.n or #args do
		local v = args[i]
		parts[#parts + 1] = summarise(v)
		local t = typeof(v)
		types[#types + 1] = t
		if t == "Vector3" and firstVector == nil then firstVector = v end
		if t == "CFrame" and firstCFrame == nil then firstCFrame = v end
		if t == "number" and firstNumber == nil then firstNumber = v end
	end
	local line = method .. " " .. name .. "(" .. table.concat(parts, ", ") .. ")"
	table.insert(R.spyLog, 1, {t = Util.Stamp(), name = name, text = line})
	while #R.spyLog > R.SPY_MAX do table.remove(R.spyLog) end

	table.insert(R.spyEvents, 1, {
		clock = Util.Now(),
		name = name,
		method = method,
		types = types,
		argc = args.n or #args,
		vector = firstVector,
		cframe = firstCFrame,
		number = firstNumber,
		text = line,
	})
	while #R.spyEvents > R.SPY_EVENTS_MAX do table.remove(R.spyEvents) end
end

local function denied(name)
	if not Cfg.s.keeper.blockDeny then return false end
	for _, n in ipairs(Cfg.List(Cfg.target.denyRemotes)) do
		if n == name then return true end
	end
	return false
end

-- A namecall is a remote send when the method says so, or when the method
-- cannot be read on this executor and the receiver is a remote anyway.
function R.IsRemoteCall(self, method)
	if typeof(self) ~= "Instance" then return false end
	if method == "FireServer" or method == "InvokeServer" then return true end
	if method == "" or method == nil then
		local ok, isRemote = pcall(function()
			return self:IsA("RemoteEvent") or self:IsA("RemoteFunction")
		end)
		return ok and isRemote
	end
	return false
end

-- True when the call came from our own thread, so the learner does not
-- train on its own probes.
function R.SelfCall()
	if not Env.checkcaller then return false end
	local ok, mine = pcall(Env.checkcaller)
	return ok and mine == true
end

function R.InstallHook()
	if hookInstalled then return true end
	if not Env.canHook then return false end

	local ok = pcall(function()
		if Env.hookmetamethod then
			oldNamecall = Env.hookmetamethod(game, "__namecall", function(self, ...)
				local method = Env.getnamecallmethod and Env.getnamecallmethod() or ""
				if R.IsRemoteCall(self, method) then
					if R.spyOn and not R.SelfCall() then
						local args = table.pack(...)
						pcall(record, self.Name, method, args)
					end
					if denied(self.Name) then
						return nil
					end
				end
				return oldNamecall(self, ...)
			end)
		else
			local mt = Env.getrawmetatable(game)
			Env.setreadonly(mt, false)
			oldNamecall = mt.__namecall
			mt.__namecall = function(self, ...)
				local method = Env.getnamecallmethod and Env.getnamecallmethod() or ""
				if R.IsRemoteCall(self, method) then
					if R.spyOn and not R.SelfCall() then
						local args = table.pack(...)
						pcall(record, self.Name, method, args)
					end
					if denied(self.Name) then return nil end
				end
				return oldNamecall(self, ...)
			end
			Env.setreadonly(mt, true)
		end
	end)

	hookInstalled = ok
	return ok
end

function R.HookInstalled() return hookInstalled end

function R.ClearSpy()
	R.spyLog = {}
	R.spyEvents = {}
end

-- Remote sends seen in the last `seconds`, newest first.
function R.RecentSends(seconds)
	local cutoff = Util.Now() - (seconds or 0.5)
	local out = {}
	for _, ev in ipairs(R.spyEvents) do
		if ev.clock >= cutoff then out[#out + 1] = ev else break end
	end
	return out
end

function R.SpyLines(count)
	local out = {}
	for i = 1, math.min(count or 8, #R.spyLog) do
		out[#out + 1] = R.spyLog[i].text
	end
	return out
end

-- ── Status for the CONFIG tab ────────────────────────────────────────
function R.Status()
	local b = R.Ball()
	return {
		ball      = b and (b.Name .. " [" .. R.ballTier .. "]") or "not found",
		goals     = #R.goals,
		ownGoal   = R.ownGoal and R.ownGoal.tier or "none",
		enemyGoal = R.enemyGoal and R.enemyGoal.tier or "none",
		teams     = R.HasTeams() and "yes" or "no",
		remotes   = #R.remoteIndex,
		hook      = hookInstalled and "installed" or "none",
	}
end

return R
