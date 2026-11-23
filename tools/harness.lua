-- Headless test rig: builds a fake pitch, boots the bundle, drives it and
-- asserts on the solvers. Prints a report the build script reads.
local H = {}
local v3 = Vector3.new
local results = {}
local function check(name, ok, detail)
	results[#results + 1] = {name = name, ok = ok and true or false, detail = detail or ""}
end
H.results = results

-- ── service tree ─────────────────────────────────────────────────────
local function sig() return _MOCK.newSignal("s") end

local Workspace = Instance.new("Model")
Workspace.Name = "Workspace"
Workspace.Gravity = 196.2
function Workspace:GetRealPhysicsFPS() return 60 end
function Workspace:Raycast() return nil end

local Camera = Instance.new("Part")
Camera.Name = "Camera"
Camera.ClassName = "Camera"
Camera.CFrame = CFrame.lookAt(v3(0, 20, 60), v3(0, 5, 0))
Camera.ViewportSize = Vector2.new(1280, 720)
Camera.FieldOfView = 70
function Camera:WorldToViewportPoint(pos)
	local rel = self.CFrame:PointToObjectSpace(pos)
	local depth = -rel.Z
	local vp = self.ViewportSize
	if depth <= 0 then return v3(0, 0, depth), false end
	local f = (vp.Y * 0.5) / math.tan(math.rad(self.FieldOfView) / 2)
	return v3(vp.X * 0.5 + rel.X * f / depth, vp.Y * 0.5 - rel.Y * f / depth, depth), true
end
Workspace.CurrentCamera = Camera

-- pitch
local ball = Instance.new("Part", Workspace)
ball.Name = "Ball"
ball.Shape = Enum.PartType.Ball
ball.Size = v3(2, 2, 2)
ball.Position = v3(0, 4, 0)
ball.Anchored = false

local goalA = Instance.new("Model", Workspace)
goalA.Name = "GoalNet_Home"
goalA.CFrame = CFrame.new(v3(0, 8, -120))
goalA.Size = v3(24, 12, 4)

local goalB = Instance.new("Model", Workspace)
goalB.Name = "GoalNet_Away"
goalB.CFrame = CFrame.new(v3(0, 8, 120))
goalB.Size = v3(24, 12, 4)

-- a decoy that must not score as a ball
local decoy = Instance.new("Part", Workspace)
decoy.Name = "Baseplate"
decoy.Size = v3(512, 2, 512)
decoy.Anchored = true
decoy.Position = v3(0, 0, 0)

local function makeChar(name, pos)
	local char = Instance.new("Model", Workspace)
	char.Name = name
	local hum = Instance.new("Humanoid", char)
	hum.Name = "Humanoid"
	local hrp = Instance.new("Part", char)
	hrp.Name = "HumanoidRootPart"
	hrp.Size = v3(2, 2, 1)
	hrp.CFrame = CFrame.lookAt(pos, pos + v3(0, 0, -1))
	local head = Instance.new("Part", char)
	head.Name = "Head"
	head.Size = v3(2, 1, 1)
	head.Position = pos + v3(0, 1.5, 0)
	local foot = Instance.new("Part", char)
	foot.Name = "RightFoot"
	foot.Size = v3(1, 1, 1)
	foot.Position = pos - v3(0, 2.5, 0)
	return char, hrp, hum
end

local function makePlayer(name, pos, team)
	local plr = Instance.new("Model")
	plr.ClassName = "Player"
	plr.Name = name
	plr.DisplayName = name
	plr.UserId = 1000 + #name
	local char = makeChar(name, pos)
	plr.Character = char
	plr.Team = team
	return plr
end

local Teams = Instance.new("Model")
Teams.ClassName = "Teams"
Teams.Name = "Teams"
local red = Instance.new("Model", Teams)
red.ClassName = "Team"
red.Name = "Red"
local blue = Instance.new("Model", Teams)
blue.ClassName = "Team"
blue.Name = "Blue"

local lp = makePlayer("Olivia", v3(0, 3, 20), red)
local mate = makePlayer("Mate1", v3(14, 3, -20), red)
local foe1 = makePlayer("Foe1", v3(-6, 3, -40), blue)
local foe2 = makePlayer("Keeper", v3(0, 3, -112), blue)

local playerList = {lp, mate, foe1, foe2}

local Players = Instance.new("Model")
Players.ClassName = "Players"
Players.Name = "Players"
Players.LocalPlayer = lp
function Players:GetPlayers() return playerList end
function Players:GetCharacterAppearanceAsync() return nil end

local RunService = Instance.new("Model")
RunService.ClassName = "RunService"
RunService.Heartbeat = sig()
RunService.RenderStepped = sig()

local UIS = Instance.new("Model")
UIS.ClassName = "UserInputService"
UIS.TouchEnabled = false
UIS.KeyboardEnabled = true
UIS.GamepadEnabled = false
UIS.InputBegan = sig()
UIS.InputChanged = sig()
UIS.InputEnded = sig()
function UIS:IsKeyDown() return false end
function UIS:GetGamepadState() return {} end

local TweenService = Instance.new("Model")
TweenService.ClassName = "TweenService"
function TweenService:Create() return {Play = function() end} end

local HttpService = Instance.new("Model")
HttpService.ClassName = "HttpService"
function HttpService:JSONEncode() return "{}" end
function HttpService:JSONDecode() return {} end

local Lighting = Instance.new("Model")
Lighting.ClassName = "Lighting"
Lighting.ClockTime = 14

local ReplicatedStorage = Instance.new("Model")
ReplicatedStorage.ClassName = "ReplicatedStorage"
ReplicatedStorage.Name = "ReplicatedStorage"
local kickRemote = Instance.new("RemoteEvent", ReplicatedStorage)
kickRemote.Name = "KickBall"

local StarterGui = Instance.new("Model")
StarterGui.ClassName = "StarterGui"
function StarterGui:SetCore() end

local CoreGui = Instance.new("Model")
CoreGui.ClassName = "CoreGui"
CoreGui.Name = "CoreGui"

local Stats = Instance.new("Model")
Stats.ClassName = "Stats"
Stats.Network = {
	ServerStatsItem = {
		["Data Ping"] = {GetValue = function() return 42 end},
	},
}

local TeleportService = Instance.new("Model")
TeleportService.ClassName = "TeleportService"
function TeleportService:Teleport() end
function TeleportService:TeleportToPlaceInstance() end

local ContextAction = Instance.new("Model")
ContextAction.ClassName = "ContextActionService"

local GuiService = Instance.new("Model")
GuiService.ClassName = "GuiService"

local VirtualUser = Instance.new("Model")
VirtualUser.ClassName = "VirtualUser"
function VirtualUser:CaptureController() end
function VirtualUser:ClickButton2() end

local services = {
	Players = Players, RunService = RunService, UserInputService = UIS,
	ContextActionService = ContextAction, TweenService = TweenService,
	HttpService = HttpService, Lighting = Lighting,
	ReplicatedStorage = ReplicatedStorage, TeleportService = TeleportService,
	StarterGui = StarterGui, Stats = Stats, GuiService = GuiService,
	CoreGui = CoreGui, VirtualUser = VirtualUser, Workspace = Workspace,
}

game = setmetatable({
	PlaceId = 1234567,
	JobId = "job-here",
	GetService = function(_, name)
		local s = services[name]
		if not s then
			s = Instance.new("Model")
			s.ClassName = name
			s.Name = name
			services[name] = s
		end
		return s
	end,
	FindFirstChildOfClass = function(_, class)
		if class == "Teams" then return Teams end
		return nil
	end,
	FindFirstChild = function(_, name)
		if name == "ReplicatedFirst" then return nil end
		return services[name]
	end,
}, {})
workspace = Workspace

H.env = {
	ball = ball, goalA = goalA, goalB = goalB, lp = lp, mate = mate,
	foe1 = foe1, foe2 = foe2, Workspace = Workspace, Camera = Camera,
	RunService = RunService, kickRemote = kickRemote,
}

-- ── run ──────────────────────────────────────────────────────────────
function H.Run(bundleSource)
	_G.LC_TEST = true
	local chunk, loadErr = load(bundleSource, "ollie_tf")
	if not chunk then
		check("bundle loads", false, tostring(loadErr))
		return results
	end
	local ok, err = pcall(chunk)
	check("bundle executes", ok, ok and "" or tostring(err))
	if not ok then return results end

	local bootFailed = nil
	for _, w in ipairs(_MOCK.warnings or {}) do
		if string.find(w, "boot failed", 1, true) then bootFailed = w end
	end
	check("boot clean", bootFailed == nil, bootFailed or "")

	local _R = _G.LC_R
	check("module registry exposed", _R ~= nil)
	if not _R then return results end

	local AM  = _R("amath")
	local Res = _R("resolve")
	local BE  = _R("backend")
	local Aim = _R("aimbot")
	local Pass= _R("aimpass")
	local GK  = _R("keeper")
	local Cfg = _R("cfg")
	local Menu= _R("menu")
	local SP  = _R("special")

	-- resolver
	local found = Res.Ball()
	check("resolver finds the ball", found == ball,
		found and found.Name or "nil")
	check("resolver rejects the baseplate", found ~= decoy)

	Res.ScanGoals(true)
	check("resolver finds both goals", #Res.goals >= 2, tostring(#Res.goals))
	check("own and enemy goal assigned", Res.ownGoal ~= nil and Res.enemyGoal ~= nil)

	check("teams visible", Res.HasTeams())
	check("teammate list correct", #Res.Teammates() == 1, tostring(#Res.Teammates()))
	check("enemy list correct", #Res.Enemies() == 2, tostring(#Res.Enemies()))

	-- ballistics round trip: launch, integrate, land on target
	do
		local g = 196.2
		local p0, p1 = v3(0, 4, 0), v3(10, 9, -80)
		local speed = 160
		local vel = AM.SolveLaunch(p0, p1, speed, g, true)
		local okSolve = vel ~= nil
		local err = -1
		if vel then
			local t = AM.FlightTime(p0, p1, vel)
			local land = AM.ParabolaAt(p0, vel, g, t)
			err = (land - p1).Magnitude
		end
		check("ballistic solve lands on target", okSolve and err < 0.5,
			string.format("error %.4f studs", err))
	end

	do
		local g = 196.2
		local p0, p1 = v3(0, 4, 0), v3(-30, 20, 95)
		local lob = AM.SolveLaunch(p0, p1, 200, g, false)
		local flat = AM.SolveLaunch(p0, p1, 200, g, true)
		local okBoth = lob ~= nil and flat ~= nil
		check("both arcs solve", okBoth, okBoth and string.format("lob vy %.1f, flat vy %.1f", lob.Y, flat.Y) or "nil")
		if okBoth then
			check("lob arcs higher than flat", lob.Y > flat.Y)
		end
	end

	do
		local unreachable = AM.SolveLaunch(v3(0, 0, 0), v3(0, 0, 4000), 20, 196.2, true)
		check("out of range returns nil", unreachable == nil)
	end

	-- plane crossing
	do
		local goalCF = CFrame.lookAt(v3(0, 8, -120), v3(0, 8, 0))
		local p0 = v3(0, 6, -40)
		local vel = v3(0, 10, -120)
		local t = AM.ParabolaPlaneTime(p0, vel, 196.2, goalCF.Position, goalCF.LookVector)
		local okT = t ~= nil and t > 0
		local detail = okT and string.format("t = %.3f s", t) or "nil"
		check("parabola crosses the goal plane", okT, detail)
		if okT then
			local pt = AM.ParabolaAt(p0, vel, 196.2, t)
			check("crossing point sits on the plane",
				math.abs((pt - goalCF.Position):Dot(goalCF.LookVector)) < 0.01,
				string.format("%.5f", (pt - goalCF.Position):Dot(goalCF.LookVector)))
		end
	end

	-- goal corner geometry
	do
		local goalCF = CFrame.lookAt(v3(0, 8, -120), v3(0, 8, 0))
		local size = v3(24, 12, 4)
		local corner = AM.GoalCorner(goalCF, size, 2.2, 1, nil)
		check("top corner falls inside the mouth",
			AM.InsideGoal(goalCF, size, corner, 0.01))
		local l = goalCF:PointToObjectSpace(corner)
		check("top corner is high and wide",
			l.Y > size.Y * 0.25 and math.abs(l.X) > size.X * 0.25,
			string.format("local (%.1f, %.1f)", l.X, l.Y))
	end

	-- backend + shot
	Cfg.s.aim.topCorner = true
	Cfg.s.aim.speed = 220
	ball.AssemblyLinearVelocity = v3(0, 0, 0)
	local shotOk = Aim.Shoot(nil)
	check("shot fires", shotOk, Aim.lastResult)
	do
		local v = ball.AssemblyLinearVelocity
		check("shot wrote a real velocity", v.Magnitude > 10, string.format("%.1f st/s", v.Magnitude))
		local goal = Res.enemyGoal or Res.ownGoal
		if goal and v.Magnitude > 1 then
			local toGoal = (goal.cf.Position - ball.Position)
			local flatDot = v3(v.X, 0, v.Z).Unit:Dot(v3(toGoal.X, 0, toGoal.Z).Unit)
			check("shot points at the goal", flatDot > 0.85, string.format("dot %.3f", flatDot))
		end
	end

	-- pass
	ball.AssemblyLinearVelocity = v3(0, 0, 0)
	ball.Position = v3(0, 4, 10)
	local passOk = Pass.Fire()
	check("pass fires", passOk, Pass.lastResult)

	-- keeper prediction
	do
		Res.ownGoal = Res.ownGoal or Res.goals[1]
		local gcf = Res.ownGoal.cf
		ball.Position = gcf.Position + gcf.LookVector * 50 + v3(0, 2, 0)
		ball.AssemblyLinearVelocity = -gcf.LookVector * 120 + v3(0, 20, 0)
		Cfg.s.keeper.predictTime = 3
		local threat = GK.Predict()
		check("keeper predicts an incoming shot", threat ~= nil,
			threat and string.format("t = %.2f s", threat.t) or "no threat")
	end

	-- kick remote learner
	do
		local Learn = _R("learn")

		local function ev(types, argc)
			return {types = types, argc = argc or #types,
				vector = nil, cframe = nil, number = nil, name = "X"}
		end
		local sh1 = Learn.ShapeOf(ev({"Vector3", "number"}))
		local sh2 = Learn.ShapeOf(ev({"Vector3"}))
		local sh3 = Learn.ShapeOf(ev({"CFrame", "number"}))
		local sh4 = Learn.ShapeOf(ev({}, 0))
		local sh5 = Learn.ShapeOf(ev({"string", "boolean"}))
		check("shape inference reads dir_power", sh1 == "dir_power", sh1)
		check("shape inference reads vector", sh2 == "vector", sh2)
		check("shape inference reads cframe", sh3 == "cframe", sh3)
		check("shape inference reads bare", sh4 == "bare", sh4)
		check("shape inference refuses to guess", sh5 == "", "'" .. sh5 .. "'")

		-- the game fires its kick remote, then the ball jumps
		check("hook installs", Res.InstallHook())
		BE.lastLaunchClock = -1e9
		local armed = Learn.Arm()
		check("watch arms", armed, Learn.result)

		_MOCK.FireFromGame(kickRemote, v3(0, 0, -1), 70)
		check("spy recorded the send", #Res.spyEvents >= 1, tostring(#Res.spyEvents))

		ball.AssemblyLinearVelocity = v3(0, 0, -150)
		RunService.Heartbeat:Fire(1 / 60)
		check("watch adopted the remote", Cfg.target.kickRemote == "KickBall", Cfg.target.kickRemote)
		check("watch read the arg shape", Cfg.target.kickArgShape == "dir_power", Cfg.target.kickArgShape)
		check("watch recorded its source", Cfg.target.kickSource == "watch", Cfg.target.kickSource)
		check("watch disarms itself", Learn.state == "idle", Learn.state)

		-- our own probes must not train it
		Res.spyOn = true
		local beforeSelf = #Res.spyEvents
		_MOCK.selfcall = true
		local hook = _MOCK.hooks["__namecall"]
		pcall(hook, kickRemote, v3(0, 0, -1), 70)
		_MOCK.selfcall = false
		check("own calls are not recorded", #Res.spyEvents == beforeSelf,
			tostring(#Res.spyEvents - beforeSelf) .. " extra")
		Res.spyOn = false

		-- probe: a remote that actually moves the ball gets kept
		Cfg.target.kickRemote = ""
		Cfg.target.kickArgShape = ""
		Cfg.target.kickSource = ""
		kickRemote.FireServer = function(_, ...)
			local b = Res.Ball()
			if b then b.AssemblyLinearVelocity = v3(0, 0, -95) end
		end
		Learn.Probe()
		check("probe found a working remote", Cfg.target.kickRemote == "KickBall", Cfg.target.kickRemote)
		check("probe recorded its source", Cfg.target.kickSource == "probe", Cfg.target.kickSource)

		Learn.Verify()
		check("verify sees the ball move", string.find(Learn.verified, "moved", 1, true) ~= nil, Learn.verified)

		ball.AssemblyLinearVelocity = v3(0, 0, 0)
		Learn.OwnershipProbe()
		check("ownership probe reports a result", Learn.ownership ~= "not tested", Learn.ownership)

		local rows, verdict = Learn.Diagnose()
		check("diagnosis returns five rows", #rows == 5, tostring(#rows))
		check("diagnosis gives a verdict", type(verdict) == "string" and #verdict > 20, verdict)
	end

	-- menu
	check("menu window built", Menu.window ~= nil)
	if Menu.window then
		check("all eleven tabs present", #Menu.window.tabs == 11, tostring(#Menu.window.tabs))
		check("widgets registered refreshers", #Menu.window.refreshers > 80,
			tostring(#Menu.window.refreshers))
		local okRefresh = pcall(function() Menu.window:Refresh() end)
		check("menu refresh runs", okRefresh)
		local okTick = pcall(Menu.Tick)
		check("menu tick runs", okTick)
	end

	-- drive everything at once
	local before = #(_MOCK.warnings or {})
	Cfg.s.reach.enabled = true
	Cfg.s.reach.ballHold = false
	Cfg.s.skills.pokers = true
	Cfg.s.skills.juggle = true
	Cfg.s.skills.sneaky = true
	Cfg.s.aim.aimbot = true
	Cfg.s.aim.aimlock = true
	Cfg.s.aim.curve = true
	Cfg.s.pass.enabled = true
	Cfg.s.keeper.autoGK = true
	Cfg.s.keeper.autoGS = true
	Cfg.s.keeper.panicReach = true
	Cfg.s.special.phase = true
	Cfg.s.special.framePlayer = true
	Cfg.s.special.ballTime = true
	Cfg.s.special.dunk = true
	Cfg.s.special.trickOms = true
	Cfg.s.special.goalFarm = true
	Cfg.s.special.saveFarm = true
	Cfg.s.visuals.ballEsp = true
	Cfg.s.visuals.ballEspTracer = true
	Cfg.s.visuals.ballTrail = true
	Cfg.s.visuals.rgbChar = true
	Cfg.s.visuals.bootTrail = true
	Cfg.s.visuals.timeOfDay = true
	Cfg.s.visuals.spoofMarker = true
	Cfg.s.character.r6 = true
	Cfg.s.settings.panicStaff = true
	Cfg.s.settings.autoQuest = true

	local ticks = 240
	for i = 1, ticks do
		RunService.Heartbeat:Fire(1 / 60)
		RunService.RenderStepped:Fire(1 / 60)
	end
	local after = #(_MOCK.warnings or {})
	local newWarnings = {}
	for i = before + 1, after do
		local w = _MOCK.warnings[i]
		if string.find(w, "heartbeat", 1, true) or string.find(w, "render", 1, true) then
			newWarnings[#newWarnings + 1] = w
		end
	end
	check(ticks .. " frames with every feature on", #newWarnings == 0,
		#newWarnings > 0 and newWarnings[1] or "no driver errors")

	-- phase restored on teardown
	check("phase recorded originals", next(SP.phased) ~= nil)

	-- ball vanishes mid match: every feature has to degrade, not throw
	do
		local keptPos = ball.Position
		ball:Destroy()
		local beforeD = #(_MOCK.warnings or {})
		for i = 1, 90 do
			RunService.Heartbeat:Fire(1 / 60)
			RunService.RenderStepped:Fire(1 / 60)
		end
		local errs = 0
		for i = beforeD + 1, #(_MOCK.warnings or {}) do
			local w = _MOCK.warnings[i]
			if string.find(w, "heartbeat", 1, true) or string.find(w, "render", 1, true) then
				errs = errs + 1
			end
		end
		check("survives the ball being destroyed", errs == 0, tostring(errs) .. " driver errors")
		check("ball reads as unresolved", Res.Ball() == nil)

		local fresh = Instance.new("Part", Workspace)
		fresh.Name = "MatchBall"
		fresh.Shape = Enum.PartType.Ball
		fresh.Size = v3(2, 2, 2)
		fresh.Position = keptPos
		fresh.Anchored = false
		ball = fresh
		H.env.ball = fresh
		RunService.Heartbeat:Fire(1 / 60)
		check("re-resolves a replacement ball", Res.ScanBall(true) == fresh,
			Res.ball and Res.ball.Name or "nil")
	end

	local unloadOk = pcall(function() _G.LC_UNLOAD() end)
	check("unload runs clean", unloadOk)
	check("phase restored after unload", next(SP.phased) == nil)

	return results
end

-- Second boot on a touch device: the mobile layout has to build and run.
function H.RunMobile(bundleSource)
	UIS.TouchEnabled = true
	UIS.KeyboardEnabled = false
	UIS.GamepadEnabled = true

	local chunk = load(bundleSource, "ollie_tf_mobile")
	local ok, err = pcall(chunk)
	check("mobile boot executes", ok, ok and "" or tostring(err))
	if not ok then return results end

	local _R = _G.LC_R
	local TB = _R("touchui")
	local Menu = _R("menu")
	local Theme = _R("theme")
	local Cfg = _R("cfg")

	check("touch buttons built", TB.Count() == 12, tostring(TB.Count()))
	check("rows grow for fingers", Theme.RowHeight() >= 42, tostring(Theme.RowHeight()))
	check("window fits the viewport",
		Menu.window ~= nil and Menu.window.Root.Size.X.Offset <= 1280 * 0.95,
		Menu.window and tostring(Menu.window.Root.Size.X.Offset) or "no window")

	Cfg.s.settings.touchShape = 2
	local okShape = pcall(function() TB.Rebuild() end)
	check("button shape change rebuilds", okShape and TB.Count() == 12, tostring(TB.Count()))
	Cfg.s.settings.touchSize = 80
	local okSize = pcall(function() TB.Rebuild() end)
	check("button size change rebuilds", okSize and TB.Count() == 12, tostring(TB.Count()))

	local before = #(_MOCK.warnings or {})
	for i = 1, 120 do
		RunService.Heartbeat:Fire(1 / 60)
		RunService.RenderStepped:Fire(1 / 60)
	end
	local errs = 0
	for i = before + 1, #(_MOCK.warnings or {}) do
		local w = _MOCK.warnings[i]
		if string.find(w, "heartbeat", 1, true) or string.find(w, "render", 1, true) then
			errs = errs + 1
		end
	end
	check("120 mobile frames clean", errs == 0, tostring(errs) .. " driver errors")

	local okUnload = pcall(function() _G.LC_UNLOAD() end)
	check("mobile unload runs clean", okUnload)
	return results
end

return H
