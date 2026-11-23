--[[
	olliE / Lord's Court  --  Touch Football toolkit
	Built from src/ by tools/build.py. Edit the modules, not this file.

	Ground truth note: this build ships with NO Touch Football offsets,
	remote names or instance paths. Every game specific value is unset in
	the cfg module and is either discovered by the resolver at runtime or
	filled in by hand on the CONFIG tab. A feature whose value is still
	unset prints one line and disables itself. Nothing else stops.
]]

local __src, __cache = {}, {}
local __LOADING = newproxy and newproxy(false) or {}

local function _R(name)
	local hit = __cache[name]
	if hit ~= nil then
		if hit == __LOADING then
			error("[olliE] dependency cycle at module: " .. tostring(name), 2)
		end
		return hit
	end
	local factory = __src[name]
	if factory == nil then
		error("[olliE] missing module: " .. tostring(name), 2)
	end
	__cache[name] = __LOADING
	local value = factory(_R)
	if value == nil then
		error("[olliE] module returned nil: " .. tostring(name), 2)
	end
	__cache[name] = value
	return value
end

-- ===== env  (src/01_env.lua) =====
__src["env"] = function(_R)
-- @module env
-- Executor capability probe. Every optional global is tested exactly once here.
-- No other module touches an exploit global directly; they ask Env.

local Env = {}

local function probe(name)
	local ok, v = pcall(function() return getfenv(0)[name] end)
	if ok and type(v) == "function" then return v end
	ok, v = pcall(function() return getgenv()[name] end)
	if ok and type(v) == "function" then return v end
	return nil
end

local function probeTable(name)
	local ok, v = pcall(function() return getfenv(0)[name] end)
	if ok and type(v) == "table" then return v end
	return nil
end

Env.hookmetamethod    = probe("hookmetamethod")
Env.getrawmetatable   = probe("getrawmetatable")
Env.setreadonly       = probe("setreadonly") or probe("make_writeable")
Env.checkcaller       = probe("checkcaller")
Env.newcclosure       = probe("newcclosure")
Env.hookfunction      = probe("hookfunction") or probe("replaceclosure")
Env.getnamecallmethod = probe("getnamecallmethod")
Env.getconnections    = probe("getconnections")
Env.firetouchinterest = probe("firetouchinterest")
Env.fireproximity     = probe("fireproximityprompt")
Env.fireclickdetector = probe("fireclickdetector")
Env.sethiddenproperty = probe("sethiddenproperty")
Env.gethiddenproperty = probe("gethiddenproperty")
Env.setsimulationradius = probe("setsimulationradius")
Env.getcustomasset    = probe("getcustomasset")
Env.setfpscap         = probe("setfpscap")
Env.cloneref          = probe("cloneref") or function(x) return x end
Env.getobjects        = probe("getobjects")
Env.identifyexecutor  = probe("identifyexecutor") or probe("getexecutorname")
Env.queueteleport     = probe("queue_on_teleport") or probe("queueonteleport")

Env.writefile = probe("writefile")
Env.readfile  = probe("readfile")
Env.isfile    = probe("isfile")
Env.delfile   = probe("delfile")
Env.makefolder = probe("makefolder")
Env.isfolder   = probe("isfolder")
Env.listfiles  = probe("listfiles")

local syn = probeTable("syn")
Env.request = probe("request") or probe("http_request") or (syn and type(syn.request) == "function" and syn.request) or nil

Env.httpGet = nil
do
	local ok, kind = pcall(function() return type(game.HttpGet) end)
	if ok and kind == "function" then
		Env.httpGet = function(url)
			local good, body = pcall(function() return game:HttpGet(url, true) end)
			if good then return body end
			return nil
		end
	end
end

Env.name = "unknown"
if Env.identifyexecutor then
	local ok, n = pcall(Env.identifyexecutor)
	if ok and type(n) == "string" and #n > 0 then Env.name = n end
end

Env.gethui           = probe("gethui")
Env.protectgui       = probe("protect_gui") or probe("protectgui")

-- Capability groups the features gate on.
Env.canHook      = (Env.hookmetamethod ~= nil) or (Env.getrawmetatable ~= nil and Env.setreadonly ~= nil)
Env.canTouch     = Env.firetouchinterest ~= nil
Env.canFiles     = (Env.writefile ~= nil and Env.readfile ~= nil and Env.isfile ~= nil)
Env.canHttp      = (Env.httpGet ~= nil) or (Env.request ~= nil)
Env.canAssets    = (Env.getobjects ~= nil)
Env.canSimRadius = (Env.setsimulationradius ~= nil) or (Env.sethiddenproperty ~= nil)

function Env.Summary()
	local rows = {
		{"executor", Env.name},
		{"metamethod hooks", Env.canHook and "yes" or "no"},
		{"firetouchinterest", Env.canTouch and "yes" or "no"},
		{"file io", Env.canFiles and "yes" or "no"},
		{"http", Env.canHttp and "yes" or "no"},
		{"asset load", Env.canAssets and "yes" or "no"},
		{"sim radius", Env.canSimRadius and "yes" or "no"},
		{"queue on teleport", Env.queueteleport and "yes" or "no"},
	}
	return rows
end

return Env
end

-- ===== cfg  (src/02_cfg.lua) =====
__src["cfg"] = function(_R)
-- @module cfg
-- Settings store + the single place every build-dependent value lives.

local Cfg = {}

Cfg.VERSION   = "1.0.0"
Cfg.NAME      = "olliE / Lord's Court"
Cfg.SHORT     = "olliE"
Cfg.FOLDER    = "ollie_tf"
Cfg.CFG_EXT   = ".json"

-- =====================================================================
-- TARGET DATA  -- build dependent, ALL UNSET.
--
-- Nothing below was read from a dump, a disassembly, a log or a live
-- session. There is no Touch Football ground truth in this project. The
-- resolver discovers what it can at runtime; anything it cannot discover
-- stays unset and the feature that needs it prints one line and turns
-- itself off. Nothing else stops.
--
-- provenance tag format on every line:
--   [kind | build | source | state]
--     kind   : instance-path / remote-name / arg-shape / number
--     build  : the game build the value came from
--     source : dump / remote spy / manual / resolver
--     state  : live / stale / unset
-- =====================================================================

Cfg.target = {
	-- [number | build unset | source unset | unset]
	-- 0 means "use the running place". Set only if you want hop locked to
	-- one place id.
	placeId = 0,

	-- [remote-name | build unset | source unset | unset]
	-- Fired by the game when you kick. Fill from CONFIG -> Remote Spy:
	-- arm the spy, kick the ball once, copy the name it logs.
	kickRemote = "",

	-- [arg-shape | build unset | source unset | unset]
	-- How kickRemote takes its arguments. One of:
	--   "dir_power"  FireServer(Vector3 unitDirection, number power)
	--   "vector"     FireServer(Vector3 velocity)
	--   "cframe"     FireServer(CFrame aimCFrame, number power)
	--   ""           unset -> remote backend stays off
	kickArgShape = "",

	-- [remote-name | build unset | source third-party page | UNVERIFIED]
	-- Names to try when you press Probe on the CONFIG tab. These are
	-- candidates, not values: each one is fired at the server with a probe
	-- vector and kept only if the ball actually moves. KickBall and
	-- GoalEvent come from a public Touch Football script dump of unknown
	-- date (scriptrb.com post 2279), not from a dump of your build, so
	-- neither is trusted until the probe proves it here.
	-- The prober also sweeps every RemoteEvent in the place whose name
	-- contains kick, shoot or ball, which is discovery rather than guesswork.
	kickCandidates = "KickBall,GoalEvent",

	-- [string | build unset | source resolver | unset]
	-- Written by the learner: how kickRemote was obtained.
	kickSource = "",

	-- [remote-name | build unset | source unset | unset]
	-- Fired to claim / complete a quest. Needed by Auto Complete Quest.
	questRemote = "",

	-- [remote-name | build unset | source unset | unset]
	-- Names to swallow when "Block Kick Deny Events" is on. Comma separated.
	denyRemotes = "",

	-- [instance-path | build unset | source unset | unset]
	-- Extra ball name candidates, comma separated. The resolver already
	-- scores every unanchored ball-shaped part; this just pins a name.
	ballNames = "",

	-- [instance-path | build unset | source unset | unset]
	-- Extra goal name candidates, comma separated. You can also walk into
	-- each goal and press "Capture Goal" on the CONFIG tab.
	goalNames = "",

	-- [number | build unset | source resolver | unset]
	-- Group id checked by Panic Staff. 0 disables the rank check and falls
	-- back to the manual staff name list.
	staffGroupId = 0,
	staffMinRank = 100,
	staffNames = "",
}

-- Measured at runtime by the calibration routine, never guessed.
Cfg.calib = {
	done        = false,
	gravity     = 0,     -- read from workspace at calibrate time
	dragK       = 0,     -- exponential velocity decay constant, 1/s
	powerToStud = 0,     -- studs/s produced per 1.0 power unit
	sampleCount = 0,
	stamp       = "",
}

-- =====================================================================
-- SETTINGS -- these are ours, not the game's. Safe to ship with values.
-- =====================================================================

Cfg.s = {
	reach = {
		enabled       = false,
		proNatural    = true,
		controlEasier = false,
		radius        = 14,
		priority      = 2,       -- 1 nearest, 2 ball-to-goal, 3 teammate-safe
		ballHold      = false,
		holdDistance  = 4.5,
		holdHeight    = 2.0,
		adaptHighMs   = true,
		adaptPerMs    = 0.045,   -- studs of extra radius per ms of ping
		adaptCap      = 12,
		triggerRange  = 9,
		pulseRate     = 22,      -- touch pulses per second
	},

	skills = {
		sneaky        = false,
		sneakyAirOnly = true,
		sneakyAuto    = true,
		sneakyPower   = 42,
		sneakyLift    = 0.35,

		pokers        = false,
		pokerSpeed    = 12,      -- pokes per second
		pokerPower    = 18,

		juggle        = false,
		juggleReach   = 10,
		juggleHeight  = 14,
		juggleSticky  = 0.55,

		groundShots   = false,
		groundLift    = 0.08,
	},

	aim = {
		aimbot        = false,
		aimlock       = false,
		aimlockSpeed  = 0.35,
		fovDeg        = 0,       -- 0 = unlimited
		power         = 70,
		speed         = 95,
		gravityScale  = 1.0,
		missChance    = 0,       -- percent
		curve         = false,
		curveAmount   = 0.35,
		curveAuto     = true,
		curveRandom   = false,
		topCorner     = false,
		cornerInset   = 2.2,
		autoDetectGoal = true,
		autoNero      = false,
		neroPower     = 88,
		neroLift      = 0.22,
		neroSpin      = 0.6,
		autoHeader    = false,
		headerRange   = 7,
		headerPower   = 55,
		fireRate      = 4,       -- shots per second cap
	},

	pass = {
		enabled       = false,
		teammatesOnly = true,
		throughBalls  = false,
		throughLead   = 0.85,
		curve         = false,
		curveAmount   = 0.25,
		minPower      = 25,
		maxPower      = 80,
		maxLobHeight  = 18,
		smartScore    = true,
		range         = 180,
	},

	keeper = {
		autoGK        = false,
		autoGS        = false,
		diveSpeed     = 70,
		touchReach    = 16,
		blockDeny     = false,
		panicReach    = false,
		panicRadius   = 26,
		predictTime   = 1.4,
	},

	special = {
		phase         = false,
		phaseMode     = 1,       -- 1 look-at, 2 selected
		antiPhase     = false,
		goalFarm      = false,
		goalFarmDelay = 1.5,
		saveFarm      = false,
		saveFarmDelay = 1.5,
		dunk          = false,
		dunkRange     = 22,
		trickOms      = false,
		trickIndex    = 1,
		ballTime      = false,
		ballTimeScale = 1.6,
		framePlayer   = false,
		bringBall     = false,
		bringDistance = 6,
		ballFrozen    = false,
	},

	visuals = {
		ballEsp       = false,
		ballEspBox    = true,
		ballEspTracer = false,
		ballEspDist   = true,
		ballTrail     = false,
		rgbChar       = false,
		rgbSpeed      = 1.0,
		rgbNeon       = true,
		bootTrail     = false,
		timeOfDay     = false,
		clockTime     = 14,
		spoofMarker   = false,
		spoofPing     = 12,
		spoofCpu      = 4,
		spoofSent     = 6,
	},

	character = {
		r6            = false,
		ownAvatar     = false,
		hatId         = 0,
		hairId        = 0,
		stripAccs     = false,
	},

	settings = {
		antiAfk       = true,
		autoBestServer= false,
		panicStaff    = false,
		notifications = true,
		autoQuest     = false,
		hopMaxPing    = 120,
		hopMinSlots   = 1,
		touchButtons  = true,
		touchSize     = 54,
		touchShape    = 1,       -- 1 shield, 2 circle, 3 square
		touchAlpha    = 0.15,
		menuKey       = "Insert",
		configName    = "default",
		touchPos      = {},   -- id -> {x, y} in pixels, written by the drag handler
	},

	binds = {
		reach    = {key = "R",    pad = "ButtonR1"},
		sneaky   = {key = "X",    pad = "ButtonL1"},
		aimbot   = {key = "T",    pad = "ButtonY"},
		aimpass  = {key = "G",    pad = "ButtonX"},
		autogk   = {key = "V",    pad = "ButtonL2"},
		phase    = {key = "F",    pad = "ButtonR2"},
		juggle   = {key = "J",    pad = "DPadUp"},
		pokers   = {key = "P",    pad = "DPadRight"},
		nero     = {key = "N",    pad = "DPadDown"},
		bring    = {key = "B",    pad = "DPadLeft"},
		freeze   = {key = "H",    pad = "ButtonSelect"},
		panic    = {key = "End",  pad = ""},
	},
}

Cfg.defaults = nil  -- filled by util at boot with a deep copy of Cfg.s

-- Comma list -> array of trimmed non-empty strings.
function Cfg.List(str)
	local out = {}
	if type(str) ~= "string" then return out end
	for piece in string.gmatch(str, "([^,]+)") do
		local t = string.match(piece, "^%s*(.-)%s*$")
		if t ~= "" then out[#out + 1] = t end
	end
	return out
end

-- A target value is usable only when it is non-empty / non-zero.
function Cfg.Has(path)
	local v = Cfg.target[path]
	if type(v) == "string" then return v ~= "" end
	if type(v) == "number" then return v ~= 0 end
	return v ~= nil
end

return Cfg
end

-- ===== util  (src/03_util.lua) =====
__src["util"] = function(_R)
-- @module util
local Env = _R("env")
local Cfg = _R("cfg")

local Util = {}

function Util.Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

function Util.Lerp(a, b, t) return a + (b - a) * t end

function Util.Round(v, places)
	local m = 10 ^ (places or 0)
	return math.floor(v * m + 0.5) / m
end

function Util.Approach(current, target, rate, dt)
	local d = target - current
	local step = rate * dt
	if math.abs(d) <= step then return target end
	if d > 0 then return current + step end
	return current - step
end

function Util.DeepCopy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = Util.DeepCopy(v) end
	return out
end

function Util.DeepMerge(dst, src)
	if type(dst) ~= "table" or type(src) ~= "table" then return dst end
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" then
			Util.DeepMerge(dst[k], v)
		elseif dst[k] ~= nil or type(v) ~= "table" then
			dst[k] = v
		end
	end
	return dst
end

function Util.Split(str, sep)
	local out = {}
	if type(str) ~= "string" then return out end
	local pattern = "([^" .. sep .. "]+)"
	for piece in string.gmatch(str, pattern) do out[#out + 1] = piece end
	return out
end

function Util.Trim(s)
	if type(s) ~= "string" then return "" end
	return (string.match(s, "^%s*(.-)%s*$"))
end

-- ── Signal ───────────────────────────────────────────────────────────
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({handlers = {}}, Signal)
end

function Signal:Connect(fn)
	local entry = {fn = fn, alive = true}
	self.handlers[#self.handlers + 1] = entry
	return {
		Disconnect = function()
			entry.alive = false
		end,
	}
end

function Signal:Fire(...)
	local list = self.handlers
	local keep = {}
	for i = 1, #list do
		local entry = list[i]
		if entry.alive then
			keep[#keep + 1] = entry
			local ok, err = pcall(entry.fn, ...)
			if not ok then
				warn("[olliE] signal handler error: " .. tostring(err))
			end
		end
	end
	self.handlers = keep
end

function Signal:Clear()
	self.handlers = {}
end

Util.Signal = Signal

-- ── Maid ─────────────────────────────────────────────────────────────
local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({items = {}}, Maid)
end

function Maid:Give(item)
	self.items[#self.items + 1] = item
	return item
end

local function destroyItem(item)
	if item == nil then return end
	local t = type(item)
	if t == "function" then
		pcall(item)
		return
	end
	if t == "table" then
		if type(item.Disconnect) == "function" then pcall(item.Disconnect, item) return end
		if type(item.Destroy) == "function" then pcall(item.Destroy, item) return end
		return
	end
	local ok = pcall(function() item:Disconnect() end)
	if ok then return end
	pcall(function() item:Destroy() end)
end

function Maid:Clean()
	local list = self.items
	self.items = {}
	for i = #list, 1, -1 do
		destroyItem(list[i])
	end
end

Util.Maid = Maid

-- ── Rate limiter ─────────────────────────────────────────────────────
function Util.Throttle(perSecond)
	local interval = 1 / math.max(perSecond, 0.0001)
	local last = -1e9
	return function(now)
		if now - last >= interval then
			last = now
			return true
		end
		return false
	end
end

-- ── File io (all gated, never assumed) ───────────────────────────────
local folderReady = false

local function ensureFolder()
	if folderReady then return true end
	if not Env.canFiles then return false end
	if Env.isfolder and Env.makefolder then
		local ok = pcall(function()
			if not Env.isfolder(Cfg.FOLDER) then Env.makefolder(Cfg.FOLDER) end
		end)
		if not ok then return false end
	end
	folderReady = true
	return true
end

function Util.ConfigPath(name)
	return Cfg.FOLDER .. "/" .. tostring(name) .. Cfg.CFG_EXT
end

function Util.SaveJson(name, tbl)
	if not ensureFolder() then return false, "no file io in this executor" end
	local HttpService = game:GetService("HttpService")
	local ok, encoded = pcall(function() return HttpService:JSONEncode(tbl) end)
	if not ok then return false, "encode failed" end
	local wrote = pcall(function() Env.writefile(Util.ConfigPath(name), encoded) end)
	if not wrote then return false, "write failed" end
	return true
end

function Util.LoadJson(name)
	if not ensureFolder() then return nil, "no file io in this executor" end
	local path = Util.ConfigPath(name)
	local exists = false
	pcall(function() exists = Env.isfile(path) end)
	if not exists then return nil, "no such config" end
	local body
	local ok = pcall(function() body = Env.readfile(path) end)
	if not ok or type(body) ~= "string" then return nil, "read failed" end
	local HttpService = game:GetService("HttpService")
	local good, decoded = pcall(function() return HttpService:JSONDecode(body) end)
	if not good then return nil, "decode failed" end
	return decoded
end

function Util.ListConfigs()
	local out = {}
	if not ensureFolder() or not Env.listfiles then return out end
	local ok, files = pcall(function() return Env.listfiles(Cfg.FOLDER) end)
	if not ok or type(files) ~= "table" then return out end
	for _, full in ipairs(files) do
		local base = string.match(full, "([^/\\]+)%" .. Cfg.CFG_EXT .. "$")
		if base then out[#out + 1] = base end
	end
	return out
end

-- ── misc ─────────────────────────────────────────────────────────────
-- getgenv where the executor has it, the plain global table where it does
-- not. Never nil, so callers do not need a branch.
function Util.Genv()
	local ok, g = pcall(function() return getgenv() end)
	if ok and type(g) == "table" then return g end
	return _G
end

function Util.Now()
	return os.clock()
end

function Util.Stamp()
	return os.date("!%Y-%m-%d %H:%M:%S")
end

function Util.SafeCall(fn, ...)
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil, a
end

Cfg.defaults = Util.DeepCopy(Cfg.s)

return Util
end

-- ===== svc  (src/04_svc.lua) =====
__src["svc"] = function(_R)
-- @module svc
-- Service handles, local player plumbing, character accessors.
local Svc = {}

Svc.Players          = game:GetService("Players")
Svc.RunService       = game:GetService("RunService")
Svc.UserInputService = game:GetService("UserInputService")
Svc.ContextAction    = game:GetService("ContextActionService")
Svc.TweenService     = game:GetService("TweenService")
Svc.HttpService      = game:GetService("HttpService")
Svc.Lighting         = game:GetService("Lighting")
Svc.ReplicatedStorage= game:GetService("ReplicatedStorage")
Svc.TeleportService  = game:GetService("TeleportService")
Svc.StarterGui       = game:GetService("StarterGui")
Svc.Stats            = game:GetService("Stats")
Svc.GuiService       = game:GetService("GuiService")
Svc.Workspace        = workspace

Svc.LP = Svc.Players.LocalPlayer
if not Svc.LP then
	Svc.LP = Svc.Players:GetPropertyChangedSignal("LocalPlayer") and Svc.Players.LocalPlayer
end

function Svc.Camera()
	return Svc.Workspace.CurrentCamera
end

function Svc.Char(plr)
	plr = plr or Svc.LP
	if not plr then return nil end
	local c = plr.Character
	if not c or not c.Parent then return nil end
	return c
end

function Svc.Hum(plr)
	local c = Svc.Char(plr)
	if not c then return nil end
	return c:FindFirstChildOfClass("Humanoid")
end

function Svc.HRP(plr)
	local c = Svc.Char(plr)
	if not c then return nil end
	return c:FindFirstChild("HumanoidRootPart")
end

function Svc.Head(plr)
	local c = Svc.Char(plr)
	if not c then return nil end
	return c:FindFirstChild("Head")
end

function Svc.Alive(plr)
	local h = Svc.Hum(plr)
	return h ~= nil and h.Health > 0
end

-- Foot part used as the touch source for reach. R6 and R15 both covered.
function Svc.Foot(plr)
	local c = Svc.Char(plr)
	if not c then return nil end
	local names = {"RightFoot", "LeftFoot", "Right Leg", "Left Leg", "RightLowerLeg", "LeftLowerLeg"}
	for _, n in ipairs(names) do
		local p = c:FindFirstChild(n)
		if p and p:IsA("BasePart") then return p end
	end
	return Svc.HRP(plr)
end

function Svc.Parts(plr)
	local out = {}
	local c = Svc.Char(plr)
	if not c then return out end
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("BasePart") then out[#out + 1] = d end
	end
	return out
end

function Svc.Others()
	local out = {}
	for _, p in ipairs(Svc.Players:GetPlayers()) do
		if p ~= Svc.LP then out[#out + 1] = p end
	end
	return out
end

function Svc.Ping()
	local ok, v = pcall(function()
		return Svc.Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	if ok and type(v) == "number" and v == v then return v end
	return 0
end

function Svc.Fps()
	local ok, v = pcall(function() return Svc.Workspace:GetRealPhysicsFPS() end)
	if ok and type(v) == "number" then return v end
	return 60
end

function Svc.ViewportSize()
	local cam = Svc.Camera()
	if cam then return cam.ViewportSize end
	return Vector2.new(1280, 720)
end

function Svc.IsMobile()
	local uis = Svc.UserInputService
	return uis.TouchEnabled and not uis.KeyboardEnabled
end

function Svc.IsGamepad()
	return Svc.UserInputService.GamepadEnabled
end

return Svc
end

-- ===== amath  (src/05_amath.lua) =====
__src["amath"] = function(_R)
-- @module amath
-- Pure aim / prediction math. No game reads in here, no Instance touched.
-- Every function takes its world constants as arguments so it can be
-- checked without the game running.
--
-- Coordinate system: Roblox. Y up, right handed, studs, CFrame is
-- row-vector style via CFrame.lookAt. Angles in radians unless the name
-- says Deg.

local AM = {}

local V3 = Vector3.new
local ZERO = Vector3.new(0, 0, 0)
local UP = Vector3.new(0, 1, 0)

AM.ZERO = ZERO
AM.UP = UP

function AM.Finite(v)
	if typeof(v) == "Vector3" then
		return v.X == v.X and v.Y == v.Y and v.Z == v.Z
			and math.abs(v.X) < 1e9 and math.abs(v.Y) < 1e9 and math.abs(v.Z) < 1e9
	end
	return type(v) == "number" and v == v and math.abs(v) < 1e12
end

function AM.Flat(v)
	return V3(v.X, 0, v.Z)
end

function AM.SafeUnit(v)
	local m = v.Magnitude
	if m < 1e-5 or not AM.Finite(v) then return ZERO end
	return v / m
end

function AM.Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

-- ── Ballistics ───────────────────────────────────────────────────────
-- Launch velocity that carries a projectile from p0 to p1 at fixed speed
-- under gravity g (studs/s^2, positive magnitude, acting -Y).
-- lowArc true picks the flat trajectory, false the lob.
-- Returns Vector3 velocity, or nil when the target is out of range.
function AM.SolveLaunch(p0, p1, speed, g, lowArc)
	if speed <= 0 then return nil end
	local delta = p1 - p0
	local flat = AM.Flat(delta)
	local d = flat.Magnitude
	local y = delta.Y

	if g <= 1e-6 then
		local dir = AM.SafeUnit(delta)
		if dir == ZERO then return nil end
		return dir * speed
	end

	if d < 1e-4 then
		-- Straight up or straight down.
		local need = math.sqrt(math.max(2 * g * math.abs(y), 0))
		if need > speed then return nil end
		if y >= 0 then return V3(0, speed, 0) end
		return V3(0, -speed, 0)
	end

	local s2 = speed * speed
	local disc = s2 * s2 - g * (g * d * d + 2 * y * s2)
	if disc < 0 then return nil end
	local root = math.sqrt(disc)
	local numer
	if lowArc then numer = s2 - root else numer = s2 + root end
	local angle = math.atan2(numer, g * d)

	local dirFlat = flat / d
	local vy = speed * math.sin(angle)
	local vxz = speed * math.cos(angle)
	local vel = dirFlat * vxz + V3(0, vy, 0)
	if not AM.Finite(vel) then return nil end
	return vel
end

-- Minimum launch speed that can reach p1 from p0 under gravity g.
function AM.MinSpeed(p0, p1, g)
	if g <= 1e-6 then return 1 end
	local delta = p1 - p0
	local d = AM.Flat(delta).Magnitude
	local y = delta.Y
	local inner = y + math.sqrt(math.max(y * y + d * d, 0))
	if inner <= 0 then return 1 end
	return math.sqrt(math.max(g * inner, 0))
end

-- Projectile position at time t.
function AM.ParabolaAt(p0, v0, g, t)
	return p0 + v0 * t - V3(0, 0.5 * g * t * t, 0)
end

-- Flight time for a launch solved by SolveLaunch.
function AM.FlightTime(p0, p1, vel)
	local flat = AM.Flat(p1 - p0)
	local vflat = AM.Flat(vel)
	local vm = vflat.Magnitude
	if vm < 1e-4 then
		if math.abs(vel.Y) < 1e-4 then return 0 end
		return math.abs((p1.Y - p0.Y) / vel.Y)
	end
	return flat.Magnitude / vm
end

-- ── Lead ─────────────────────────────────────────────────────────────
-- Iterative intercept of a target moving at constant velocity.
function AM.Lead(origin, targetPos, targetVel, speed, g, iters)
	iters = iters or 4
	local aim = targetPos
	local vel = nil
	for _ = 1, iters do
		local v = AM.SolveLaunch(origin, aim, speed, g, true)
		if not v then
			v = AM.SolveLaunch(origin, aim, speed, g, false)
		end
		if not v then return nil, aim end
		vel = v
		local t = AM.FlightTime(origin, aim, v)
		aim = targetPos + targetVel * t
		if not AM.Finite(aim) then return nil, targetPos end
	end
	return vel, aim
end

-- Exponential drag correction. k is the decay constant from calibration.
-- Returns the launch speed to use so the projectile still arrives.
function AM.DragCompensate(speed, distance, k)
	if k <= 1e-6 or speed <= 0 then return speed end
	local t = distance / speed
	local scale = math.exp(k * t * 0.5)
	return speed * AM.Clamp(scale, 1, 3)
end

-- ── Plane / goal geometry ────────────────────────────────────────────
-- First time the parabola crosses the plane (point q, unit normal n).
-- Returns t or nil.
function AM.ParabolaPlaneTime(p0, v0, g, q, n)
	-- 0.5*g*n.Y*t^2 - (v0.n)*t - (p0-q).n = 0   (sign set below)
	local a = -0.5 * g * n.Y
	local b = v0:Dot(n)
	local c = (p0 - q):Dot(n)
	if math.abs(a) < 1e-9 then
		if math.abs(b) < 1e-9 then return nil end
		local t = -c / b
		if t >= 0 then return t end
		return nil
	end
	local disc = b * b - 4 * a * c
	if disc < 0 then return nil end
	local root = math.sqrt(disc)
	local t1 = (-b + root) / (2 * a)
	local t2 = (-b - root) / (2 * a)
	local best = nil
	if t1 >= 0 then best = t1 end
	if t2 >= 0 and (best == nil or t2 < best) then best = t2 end
	return best
end

-- Goal described by a CFrame (look vector points out of the mouth) and a
-- Vector3 size in that frame's local axes (X width, Y height, Z depth).
-- Returns an aim point near a top corner, insetting from post and bar.
-- side: -1 left, 1 right, 0 auto from keeperPos.
function AM.GoalCorner(goalCF, goalSize, inset, side, keeperPos)
	local halfW = math.max(goalSize.X * 0.5 - inset, 0.25)
	local halfH = math.max(goalSize.Y * 0.5 - inset, 0.25)
	if side == 0 then
		side = 1
		if keeperPos then
			local local_ = goalCF:PointToObjectSpace(keeperPos)
			if local_.X > 0 then side = -1 else side = 1 end
		end
	end
	local offset = Vector3.new(side * halfW, halfH, 0)
	return goalCF:PointToWorldSpace(offset)
end

-- Centre-of-mouth aim point, slightly inside the line.
function AM.GoalCentre(goalCF, goalSize)
	return goalCF:PointToWorldSpace(Vector3.new(0, goalSize.Y * 0.25, 0))
end

-- Is a world point inside the goal mouth box?
function AM.InsideGoal(goalCF, goalSize, point, pad)
	pad = pad or 0
	local l = goalCF:PointToObjectSpace(point)
	return math.abs(l.X) <= goalSize.X * 0.5 + pad
		and math.abs(l.Y) <= goalSize.Y * 0.5 + pad
		and math.abs(l.Z) <= goalSize.Z * 0.5 + pad
end

-- ── Curve ────────────────────────────────────────────────────────────
-- Lateral acceleration that bends a shot. amount in [-1, 1], left negative.
-- Applied per frame by the shot controller, not baked into the launch.
function AM.CurveAccel(velocity, amount, strength)
	local dir = AM.SafeUnit(velocity)
	if dir == ZERO then return ZERO end
	local lateral = dir:Cross(UP)
	if lateral.Magnitude < 1e-4 then return ZERO end
	lateral = lateral.Unit
	return lateral * (amount * strength)
end

-- Spin vector for the visual ball rotation that matches a curve amount.
function AM.CurveSpin(velocity, amount, rate)
	local dir = AM.SafeUnit(velocity)
	if dir == ZERO then return ZERO end
	return UP * (-amount * rate) + dir * (amount * rate * 0.25)
end

-- Auto curve: how much bend is needed to get round an obstacle that sits
-- between origin and target. blockerPos is the nearest blocking body.
function AM.AutoCurve(origin, target, blockerPos, maxAmount)
	if not blockerPos then return 0 end
	local toT = target - origin
	local flatT = AM.Flat(toT)
	local len = flatT.Magnitude
	if len < 1e-3 then return 0 end
	local dir = flatT / len
	local toB = AM.Flat(blockerPos - origin)
	local along = toB:Dot(dir)
	if along <= 0 or along >= len then return 0 end
	local lateral = toB - dir * along
	local side = dir:Cross(UP):Dot(lateral)
	local dist = lateral.Magnitude
	if dist > 12 then return 0 end
	local need = (12 - dist) / 12
	local sign = 1
	if side > 0 then sign = -1 end
	return AM.Clamp(sign * need, -maxAmount, maxAmount)
end

-- ── Scatter ──────────────────────────────────────────────────────────
-- Deliberate miss. chancePct in [0,100]. Returns the displaced aim point.
function AM.ApplyMiss(aimPoint, goalCF, goalSize, chancePct, rng)
	if chancePct <= 0 then return aimPoint, false end
	local roll = rng and rng:NextNumber(0, 100) or math.random() * 100
	if roll > chancePct then return aimPoint, false end
	local l = goalCF:PointToObjectSpace(aimPoint)
	local pushX = (goalSize.X * 0.5 + 2.5) * (l.X >= 0 and 1 or -1)
	local pushY = goalSize.Y * 0.5 + 2.0
	local pick = rng and rng:NextInteger(1, 2) or math.random(1, 2)
	local out
	if pick == 1 then
		out = Vector3.new(pushX, l.Y, l.Z)
	else
		out = Vector3.new(l.X, pushY, l.Z)
	end
	return goalCF:PointToWorldSpace(out), true
end

-- ── Smoothing ────────────────────────────────────────────────────────
-- Framerate independent exponential smoothing toward a target CFrame.
function AM.SmoothCFrame(current, target, speed, dt)
	local alpha = 1 - math.exp(-math.max(speed, 0.0001) * 60 * dt / 60)
	alpha = AM.Clamp(alpha, 0, 1)
	return current:Lerp(target, alpha)
end

function AM.SmoothNumber(current, target, speed, dt)
	local alpha = AM.Clamp(1 - math.exp(-math.max(speed, 0.0001) * dt * 60 / 60), 0, 1)
	return current + (target - current) * alpha
end

-- ── Latency adaptation ───────────────────────────────────────────────
-- Extra reach radius earned by ping, capped. perMs is studs per ms.
function AM.AdaptRadius(baseRadius, pingMs, perMs, cap)
	local extra = AM.Clamp(pingMs * perMs, 0, cap)
	return baseRadius + extra
end

-- Where a body will be after one round trip of latency.
function AM.LatencyLead(pos, vel, pingMs)
	return pos + vel * (pingMs / 1000)
end

-- ── Screen helpers (need a camera, so they take one) ─────────────────
-- Returns Vector2, onScreen, depth. Handles points behind the camera.
function AM.WorldToScreen(camera, worldPos)
	local vec, onScreen = camera:WorldToViewportPoint(worldPos)
	return Vector2.new(vec.X, vec.Y), onScreen and vec.Z > 0, vec.Z
end

function AM.InFov(camera, worldPos, fovDeg)
	if fovDeg <= 0 then return true, 0 end
	local screen, visible = AM.WorldToScreen(camera, worldPos)
	if not visible then return false, math.huge end
	local vp = camera.ViewportSize
	local centre = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
	local px = (screen - centre).Magnitude
	local radiusPx = (fovDeg / math.max(camera.FieldOfView, 1)) * vp.Y * 0.5
	return px <= radiusPx, px
end

return AM
end

-- ===== theme  (src/06_theme.lua) =====
__src["theme"] = function(_R)
-- @module theme
-- Lord's Court palette and metrics. Ornaments are built from rotated
-- frames, not glyphs, so nothing depends on a font having the codepoint.
local Svc = _R("svc")

local T = {}

local function c3(r, g, b) return Color3.fromRGB(r, g, b) end

T.col = {
	bg0      = c3(11, 9, 15),
	bg1      = c3(19, 16, 27),
	bg2      = c3(28, 23, 40),
	bg3      = c3(38, 31, 54),
	stroke   = c3(84, 62, 118),
	strokeLo = c3(48, 38, 68),
	gold     = c3(214, 174, 94),
	goldHi   = c3(248, 226, 163),
	goldLo   = c3(132, 105, 54),
	text     = c3(237, 230, 215),
	textDim  = c3(154, 144, 130),
	crimson  = c3(158, 38, 52),
	good     = c3(112, 184, 124),
	bad      = c3(198, 76, 76),
	warn     = c3(224, 168, 72),
}

T.font = {
	title = Enum.Font.Garamond,
	body  = Enum.Font.Garamond,
	mono  = Enum.Font.Code,
}

T.metric = {
	corner      = 6,
	pad         = 10,
	rowH        = 34,
	rowHMobile  = 42,
	sliderH     = 46,
	sliderHMob  = 56,
	tabH        = 34,
	headerH     = 46,
	stroke      = 1,
}

function T.RowHeight()
	if Svc.IsMobile() then return T.metric.rowHMobile end
	return T.metric.rowH
end

function T.SliderHeight()
	if Svc.IsMobile() then return T.metric.sliderHMob end
	return T.metric.sliderH
end

function T.TextSize(kind)
	local mob = Svc.IsMobile()
	if kind == "title" then return mob and 22 or 20 end
	if kind == "small" then return mob and 14 or 13 end
	if kind == "tab"   then return mob and 16 or 15 end
	return mob and 17 or 16
end

-- Window size that fits the device.
function T.WindowSize()
	local vp = Svc.ViewportSize()
	if Svc.IsMobile() then
		local w = math.min(vp.X * 0.94, 600)
		local h = math.min(vp.Y * 0.80, 520)
		return UDim2.fromOffset(math.floor(w), math.floor(h))
	end
	return UDim2.fromOffset(620, 430)
end

-- ── builders ─────────────────────────────────────────────────────────
function T.Corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or T.metric.corner)
	c.Parent = parent
	return c
end

function T.Stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or T.col.strokeLo
	s.Thickness = thickness or T.metric.stroke
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function T.Pad(parent, l, r, t, b)
	local p = Instance.new("UIPadding")
	p.PaddingLeft   = UDim.new(0, l or T.metric.pad)
	p.PaddingRight  = UDim.new(0, r or l or T.metric.pad)
	p.PaddingTop    = UDim.new(0, t or T.metric.pad)
	p.PaddingBottom = UDim.new(0, b or t or T.metric.pad)
	p.Parent = parent
	return p
end

function T.List(parent, padding, dir)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding or 6)
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

function T.GoldGradient(parent, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, T.col.goldLo),
		ColorSequenceKeypoint.new(0.45, T.col.goldHi),
		ColorSequenceKeypoint.new(1.0, T.col.goldLo),
	})
	g.Rotation = rotation or 0
	g.Parent = parent
	return g
end

function T.PanelGradient(parent)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, T.col.bg2),
		ColorSequenceKeypoint.new(1, T.col.bg0),
	})
	g.Rotation = 90
	g.Parent = parent
	return g
end

-- Rotated square used as a heraldic lozenge.
function T.Lozenge(parent, size, color)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color or T.col.gold
	f.BorderSizePixel = 0
	f.Size = UDim2.fromOffset(size, size)
	f.Rotation = 45
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Parent = parent
	return f
end

-- A crown drawn from five lozenges and a bar. Scales with height h.
function T.Crown(parent, h, color)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(h * 1.6, h)
	holder.Name = "Crown"
	holder.Parent = parent

	local col = color or T.col.gold
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = col
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.fromScale(0.5, 1)
	bar.Size = UDim2.new(1, 0, 0, math.max(2, math.floor(h * 0.22)))
	bar.Parent = holder
	T.Corner(bar, 2)

	local peaks = {0.12, 0.5, 0.88}
	for i, px in ipairs(peaks) do
		local spike = Instance.new("Frame")
		spike.BackgroundColor3 = col
		spike.BorderSizePixel = 0
		spike.AnchorPoint = Vector2.new(0.5, 1)
		spike.Position = UDim2.new(px, 0, 1, -math.floor(h * 0.18))
		local sh = (i == 2) and h * 0.78 or h * 0.58
		spike.Size = UDim2.fromOffset(math.max(2, math.floor(h * 0.16)), math.floor(sh))
		spike.Parent = holder
		T.Corner(spike, 1)

		local gem = T.Lozenge(holder, math.max(4, math.floor(h * 0.26)), T.col.goldHi)
		gem.Position = UDim2.new(px, 0, 1, -math.floor(h * 0.18 + sh))
		gem.Parent = holder
	end
	return holder
end

-- Thin gold rule with a centre lozenge.
function T.Divider(parent, width)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 10)
	holder.Parent = parent

	local line = Instance.new("Frame")
	line.BackgroundColor3 = T.col.goldLo
	line.BorderSizePixel = 0
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale(0.5, 0.5)
	line.Size = UDim2.new(width or 1, 0, 0, 1)
	line.Parent = holder
	T.GoldGradient(line, 0)

	local dot = T.Lozenge(holder, 6, T.col.gold)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Parent = holder
	return holder
end

return T
end

-- ===== notify  (src/07_notify.lua) =====
__src["notify"] = function(_R)
-- @module notify
-- Toast stack in the court palette plus the Roblox core notification as a
-- fallback when our ScreenGui cannot be parented.
local Svc   = _R("svc")
local Theme = _R("theme")
local Util  = _R("util")
local Cfg   = _R("cfg")
local Env   = _R("env")

local N = {}

local root = nil
local holder = nil
local active = {}
local MAX = 5

-- Where a ScreenGui can live on this executor.
function N.GuiParent()
	if Env.gethui then
		local ok, h = pcall(Env.gethui)
		if ok and h then return h end
	end
	local ok, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok and cg then
		local can = pcall(function() local t = cg:GetChildren() return t end)
		if can then return cg end
	end
	local lp = Svc.LP
	if lp then
		local pg = lp:FindFirstChildOfClass("PlayerGui")
		if pg then return pg end
	end
	return Svc.Workspace
end

local function build()
	if root and root.Parent then return end
	root = Instance.new("ScreenGui")
	root.Name = "LC_Toast"
	root.ResetOnSpawn = false
	root.IgnoreGuiInset = true
	root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	root.DisplayOrder = 999
	root.Parent = N.GuiParent()
	if Env.protectgui then pcall(Env.protectgui, root) end

	holder = Instance.new("Frame")
	holder.Name = "Stack"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	if Svc.IsMobile() then
		holder.AnchorPoint = Vector2.new(0.5, 0)
		holder.Position = UDim2.new(0.5, 0, 0, 12)
		holder.Size = UDim2.new(0, math.floor(math.min(Svc.ViewportSize().X * 0.9, 420)), 1, -24)
	else
		holder.AnchorPoint = Vector2.new(1, 1)
		holder.Position = UDim2.new(1, -16, 1, -16)
		holder.Size = UDim2.fromOffset(330, 400)
	end
	holder.Parent = root

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Svc.IsMobile() and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = holder
end

local function toneColor(tone)
	if tone == "bad"  then return Theme.col.bad end
	if tone == "good" then return Theme.col.good end
	if tone == "warn" then return Theme.col.warn end
	return Theme.col.gold
end

local function dismiss(card)
	if not card or not card.Parent then return end
	local tw = Svc.TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	})
	tw:Play()
	for _, d in ipairs(card:GetDescendants()) do
		if d:IsA("TextLabel") then
			Svc.TweenService:Create(d, TweenInfo.new(0.18), {TextTransparency = 1}):Play()
		elseif d:IsA("Frame") then
			Svc.TweenService:Create(d, TweenInfo.new(0.18), {BackgroundTransparency = 1}):Play()
		elseif d:IsA("UIStroke") then
			Svc.TweenService:Create(d, TweenInfo.new(0.18), {Transparency = 1}):Play()
		end
	end
	task.delay(0.22, function()
		pcall(function() card:Destroy() end)
	end)
end

-- tone: "info" | "good" | "warn" | "bad"
function N.Push(title, body, tone, seconds)
	if not Cfg.s.settings.notifications then return end
	local ok = pcall(build)
	if not ok or not holder then
		pcall(function()
			Svc.StarterGui:SetCore("SendNotification", {
				Title = tostring(title), Text = tostring(body), Duration = seconds or 4,
			})
		end)
		return
	end

	while #active >= MAX do
		local oldest = table.remove(active, 1)
		dismiss(oldest)
	end

	local accent = toneColor(tone)
	local mobile = Svc.IsMobile()

	local card = Instance.new("Frame")
	card.BackgroundColor3 = Theme.col.bg1
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1, 0, 0, mobile and 62 or 56)
	card.LayoutOrder = math.floor(os.clock() * 1000) % 100000
	card.Parent = holder
	Theme.Corner(card, 6)
	Theme.Stroke(card, Theme.col.strokeLo, 1)
	Theme.PanelGradient(card)

	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = accent
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(0, 3, 1, -10)
	bar.Position = UDim2.new(0, 5, 0, 5)
	bar.Parent = card
	Theme.Corner(bar, 2)

	local head = Instance.new("TextLabel")
	head.BackgroundTransparency = 1
	head.Font = Theme.font.title
	head.TextSize = Theme.TextSize("body")
	head.TextColor3 = accent
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.Text = tostring(title)
	head.Position = UDim2.new(0, 16, 0, 6)
	head.Size = UDim2.new(1, -24, 0, 20)
	head.Parent = card

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = Theme.font.body
	text.TextSize = Theme.TextSize("small")
	text.TextColor3 = Theme.col.textDim
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.TextWrapped = true
	text.Text = tostring(body or "")
	text.Position = UDim2.new(0, 16, 0, 25)
	text.Size = UDim2.new(1, -24, 1, -30)
	text.Parent = card

	active[#active + 1] = card

	task.delay(seconds or 4.5, function()
		for i, c in ipairs(active) do
			if c == card then table.remove(active, i) break end
		end
		dismiss(card)
	end)
end

function N.Info(title, body) N.Push(title, body, "info") end
function N.Good(title, body) N.Push(title, body, "good") end
function N.Warn(title, body) N.Push(title, body, "warn") end
function N.Bad(title, body)  N.Push(title, body, "bad") end

-- Printed once per key so a gated feature cannot spam the stack.
local saidOnce = {}
function N.Once(key, title, body, tone)
	if saidOnce[key] then return end
	saidOnce[key] = true
	N.Push(title, body, tone or "warn", 6)
end

function N.ResetOnce(key)
	if key then saidOnce[key] = nil else saidOnce = {} end
end

function N.Destroy()
	active = {}
	if root then pcall(function() root:Destroy() end) end
	root, holder = nil, nil
end

return N
end

-- ===== ui  (src/08_ui.lua) =====
__src["ui"] = function(_R)
-- @module ui
-- Retained-mode widget library in the Lord's Court style. Touch and mouse
-- share every path; nothing is keyboard-only.
local Svc   = _R("svc")
local Theme = _R("theme")
local Util  = _R("util")
local Notify= _R("notify")
local Env   = _R("env")
local Cfg   = _R("cfg")

local UI = {}

local UIS = Svc.UserInputService

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

local function hoverTint(frame, base, lit)
	frame.MouseEnter:Connect(function() frame.BackgroundColor3 = lit end)
	frame.MouseLeave:Connect(function() frame.BackgroundColor3 = base end)
end

-- ── Window ───────────────────────────────────────────────────────────
local Window = {}
Window.__index = Window

function UI.Window(opts)
	local self = setmetatable({}, Window)
	self.maid = Util.Maid.new()
	self.refreshers = {}
	self.tabs = {}
	self.activeTab = nil

	local gui = Instance.new("ScreenGui")
	gui.Name = "LC_Main"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 1000
	gui.Parent = Notify.GuiParent()
	if Env.protectgui then pcall(Env.protectgui, gui) end
	self.Gui = gui
	self.maid:Give(gui)

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = gui
	self.scale = scale

	local size = Theme.WindowSize()
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = size
	root.BackgroundColor3 = Theme.col.bg0
	root.BorderSizePixel = 0
	root.Active = true
	root.Parent = gui
	self.Root = root
	Theme.Corner(root, 8)
	Theme.Stroke(root, Theme.col.stroke, 1)
	Theme.PanelGradient(root)

	-- header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundColor3 = Theme.col.bg1
	header.BorderSizePixel = 0
	header.Size = UDim2.new(1, 0, 0, Theme.metric.headerH)
	header.Parent = root
	Theme.Corner(header, 8)
	self.Header = header

	local headerFill = Instance.new("Frame")
	headerFill.BackgroundColor3 = Theme.col.bg1
	headerFill.BorderSizePixel = 0
	headerFill.Position = UDim2.new(0, 0, 1, -8)
	headerFill.Size = UDim2.new(1, 0, 0, 8)
	headerFill.Parent = header

	local crown = Theme.Crown(header, 18)
	crown.Position = UDim2.new(0, 12, 0.5, -9)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Theme.font.title
	title.TextSize = Theme.TextSize("title")
	title.TextColor3 = Theme.col.goldHi
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = opts.title or "olliE"
	title.Position = UDim2.new(0, 48, 0, 4)
	title.Size = UDim2.new(1, -140, 0, 24)
	title.Parent = header
	Theme.GoldGradient(title, 90)

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Font = Theme.font.body
	sub.TextSize = Theme.TextSize("small")
	sub.TextColor3 = Theme.col.textDim
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Text = opts.subtitle or ""
	sub.Position = UDim2.new(0, 48, 0, 25)
	sub.Size = UDim2.new(1, -140, 0, 16)
	sub.Parent = header
	self.Subtitle = sub

	local function headerButton(text, offsetX, color, cb)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.BackgroundColor3 = Theme.col.bg2
		b.BorderSizePixel = 0
		b.Font = Theme.font.body
		b.TextSize = Theme.TextSize("body")
		b.TextColor3 = color
		b.Text = text
		b.Size = UDim2.fromOffset(28, 28)
		b.Position = UDim2.new(1, offsetX, 0.5, -14)
		b.Parent = header
		Theme.Corner(b, 5)
		Theme.Stroke(b, Theme.col.strokeLo, 1)
		hoverTint(b, Theme.col.bg2, Theme.col.bg3)
		b.MouseButton1Click:Connect(cb)
		return b
	end

	headerButton("-", -74, Theme.col.text, function() self:SetMinimised(not self.minimised) end)
	headerButton("x", -40, Theme.col.bad, function() self:SetVisible(false) end)

	local divider = Theme.Divider(root, 0.96)
	divider.Position = UDim2.new(0, 0, 0, Theme.metric.headerH)

	-- tab strip
	local strip = Instance.new("ScrollingFrame")
	strip.Name = "Tabs"
	strip.BackgroundColor3 = Theme.col.bg1
	strip.BackgroundTransparency = 0.35
	strip.BorderSizePixel = 0
	strip.Position = UDim2.new(0, 6, 0, Theme.metric.headerH + 10)
	strip.Size = UDim2.new(1, -12, 0, Theme.metric.tabH + 6)
	strip.ScrollBarThickness = 2
	strip.ScrollBarImageColor3 = Theme.col.goldLo
	strip.ScrollingDirection = Enum.ScrollingDirection.X
	strip.CanvasSize = UDim2.new(0, 0, 0, 0)
	strip.AutomaticCanvasSize = Enum.AutomaticSize.X
	strip.ElasticBehavior = Enum.ElasticBehavior.Never
	strip.Parent = root
	Theme.Corner(strip, 5)
	self.Strip = strip

	local stripList = Instance.new("UIListLayout")
	stripList.FillDirection = Enum.FillDirection.Horizontal
	stripList.Padding = UDim.new(0, 4)
	stripList.SortOrder = Enum.SortOrder.LayoutOrder
	stripList.VerticalAlignment = Enum.VerticalAlignment.Center
	stripList.Parent = strip

	local stripPad = Instance.new("UIPadding")
	stripPad.PaddingLeft = UDim.new(0, 4)
	stripPad.PaddingRight = UDim.new(0, 4)
	stripPad.Parent = strip

	-- body
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.new(0, 6, 0, Theme.metric.headerH + Theme.metric.tabH + 20)
	body.Size = UDim2.new(1, -12, 1, -(Theme.metric.headerH + Theme.metric.tabH + 28))
	body.Parent = root
	self.Body = body

	-- status line
	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Font = Theme.font.mono
	status.TextSize = Theme.TextSize("small")
	status.TextColor3 = Theme.col.textDim
	status.TextXAlignment = Enum.TextXAlignment.Right
	status.Text = ""
	status.AnchorPoint = Vector2.new(1, 1)
	status.Position = UDim2.new(1, -10, 1, -2)
	status.Size = UDim2.new(0.8, 0, 0, 14)
	status.Parent = root
	self.Status = status

	self:MakeDraggable(header)
	self:MakeDraggable(title)
	self.minimised = false
	self.fullSize = size

	return self
end

function Window:MakeDraggable(handle)
	local root = self.Root
	local dragging, dragInput, startPos, startMouse = false, nil, nil, nil
	handle.Active = true

	handle.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		dragging = true
		startPos = root.Position
		startMouse = input.Position
		dragInput = input
		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				if conn then conn:Disconnect() end
			end
		end)
	end)

	UIS.InputChanged:Connect(function(input)
		if not dragging or not isMove(input) then return end
		if dragInput and input.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then return end
		local delta = input.Position - startMouse
		root.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end)
end

function Window:SetMinimised(state)
	self.minimised = state
	if state then
		self.Root.Size = UDim2.new(self.fullSize.X.Scale, self.fullSize.X.Offset, 0, Theme.metric.headerH)
		self.Strip.Visible = false
		self.Body.Visible = false
		self.Status.Visible = false
	else
		self.Root.Size = self.fullSize
		self.Strip.Visible = true
		self.Body.Visible = true
		self.Status.Visible = true
	end
end

function Window:SetVisible(state)
	self.Gui.Enabled = state
end

function Window:Visible()
	return self.Gui.Enabled
end

function Window:ToggleVisible()
	self.Gui.Enabled = not self.Gui.Enabled
end

function Window:SetScale(s)
	self.scale.Scale = Util.Clamp(s, 0.6, 1.6)
end

function Window:SetStatus(text)
	self.Status.Text = text
end

function Window:Refresh()
	for _, fn in ipairs(self.refreshers) do
		pcall(fn)
	end
end

function Window:Destroy()
	self.maid:Clean()
end

-- ── Tab ──────────────────────────────────────────────────────────────
local Tab = {}
Tab.__index = Tab

function Window:Tab(name)
	local self_ = self
	local tab = setmetatable({}, Tab)
	tab.window = self
	tab.name = name

	local btn = Instance.new("TextButton")
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = Theme.col.bg2
	btn.BorderSizePixel = 0
	btn.Font = Theme.font.title
	btn.TextSize = Theme.TextSize("tab")
	btn.TextColor3 = Theme.col.textDim
	btn.Text = name
	btn.AutomaticSize = Enum.AutomaticSize.X
	btn.Size = UDim2.new(0, 0, 0, Theme.metric.tabH)
	btn.LayoutOrder = #self.tabs + 1
	btn.Parent = self.Strip
	Theme.Corner(btn, 4)
	local bstroke = Theme.Stroke(btn, Theme.col.strokeLo, 1)

	local bpad = Instance.new("UIPadding")
	bpad.PaddingLeft = UDim.new(0, 12)
	bpad.PaddingRight = UDim.new(0, 12)
	bpad.Parent = btn

	local page = Instance.new("ScrollingFrame")
	page.Name = name
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.Size = UDim2.fromScale(1, 1)
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = Theme.col.goldLo
	page.ScrollingDirection = Enum.ScrollingDirection.Y
	page.Visible = false
	page.Parent = self.Body

	local pageList = Instance.new("UIListLayout")
	pageList.Padding = UDim.new(0, 8)
	pageList.SortOrder = Enum.SortOrder.LayoutOrder
	pageList.Parent = page

	local pagePad = Instance.new("UIPadding")
	pagePad.PaddingTop = UDim.new(0, 2)
	pagePad.PaddingBottom = UDim.new(0, 10)
	pagePad.PaddingRight = UDim.new(0, 6)
	pagePad.Parent = page

	tab.button = btn
	tab.page = page
	tab.stroke = bstroke

	btn.MouseButton1Click:Connect(function()
		self_:Select(name)
	end)

	self.tabs[#self.tabs + 1] = tab
	if not self.activeTab then self:Select(name) end
	return tab
end

function Window:Select(name)
	for _, t in ipairs(self.tabs) do
		local on = (t.name == name)
		t.page.Visible = on
		t.button.TextColor3 = on and Theme.col.goldHi or Theme.col.textDim
		t.button.BackgroundColor3 = on and Theme.col.bg3 or Theme.col.bg2
		t.stroke.Color = on and Theme.col.gold or Theme.col.strokeLo
		if on then self.activeTab = t end
	end
end

-- ── Section ──────────────────────────────────────────────────────────
local Section = {}
Section.__index = Section

function Tab:Section(title)
	local sec = setmetatable({}, Section)
	sec.window = self.window

	local card = Instance.new("Frame")
	card.BackgroundColor3 = Theme.col.bg1
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1, 0, 0, 40)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.LayoutOrder = #self.page:GetChildren()
	card.Parent = self.page
	Theme.Corner(card, 6)
	Theme.Stroke(card, Theme.col.strokeLo, 1)

	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.new(1, 0, 0, 0)
	inner.AutomaticSize = Enum.AutomaticSize.Y
	inner.Parent = card
	Theme.Pad(inner, 10, 10, 8, 10)

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 5)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = inner

	local head = Instance.new("TextLabel")
	head.BackgroundTransparency = 1
	head.Font = Theme.font.title
	head.TextSize = Theme.TextSize("body")
	head.TextColor3 = Theme.col.gold
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.Text = title
	head.Size = UDim2.new(1, 0, 0, 20)
	head.LayoutOrder = 0
	head.Parent = inner

	local rule = Instance.new("Frame")
	rule.BackgroundColor3 = Theme.col.goldLo
	rule.BorderSizePixel = 0
	rule.Size = UDim2.new(1, 0, 0, 1)
	rule.LayoutOrder = 1
	rule.Parent = inner
	Theme.GoldGradient(rule, 0)

	sec.frame = inner
	sec.order = 2
	return sec
end

function Section:next()
	self.order = self.order + 1
	return self.order
end

local function baseRow(sec, height)
	local row = Instance.new("Frame")
	row.BackgroundColor3 = Theme.col.bg2
	row.BackgroundTransparency = 0.25
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, height or Theme.RowHeight())
	row.LayoutOrder = sec:next()
	row.Parent = sec.frame
	Theme.Corner(row, 5)
	return row
end

local function rowLabel(row, text, widthOffset)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Theme.font.body
	l.TextSize = Theme.TextSize("body")
	l.TextColor3 = Theme.col.text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = text
	l.Position = UDim2.new(0, 10, 0, 0)
	l.Size = UDim2.new(1, widthOffset or -70, 1, 0)
	l.Parent = row
	return l
end

-- ── Label ────────────────────────────────────────────────────────────
function Section:Label(text, tone)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Theme.font.body
	l.TextSize = Theme.TextSize("small")
	l.TextColor3 = tone == "dim" and Theme.col.textDim or Theme.col.text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text
	l.Size = UDim2.new(1, 0, 0, 16)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.LayoutOrder = self:next()
	l.Parent = self.frame
	return {
		Set = function(_, t) l.Text = t end,
		SetColor = function(_, c) l.TextColor3 = c end,
		instance = l,
	}
end

-- ── Toggle ───────────────────────────────────────────────────────────
function Section:Toggle(o)
	local row = baseRow(self, nil)
	rowLabel(row, o.text, -76)

	local track = Instance.new("TextButton")
	track.AutoButtonColor = false
	track.Text = ""
	track.BackgroundColor3 = Theme.col.bg0
	track.BorderSizePixel = 0
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, -10, 0.5, 0)
	track.Size = UDim2.fromOffset(46, 22)
	track.Parent = row
	Theme.Corner(track, 11)
	local tstroke = Theme.Stroke(track, Theme.col.strokeLo, 1)

	local knob = Instance.new("Frame")
	knob.BackgroundColor3 = Theme.col.textDim
	knob.BorderSizePixel = 0
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Position = UDim2.new(0, 3, 0.5, 0)
	knob.Size = UDim2.fromOffset(16, 16)
	knob.Parent = track
	Theme.Corner(knob, 8)

	local function paint(state)
		local goal = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		Svc.TweenService:Create(knob, TweenInfo.new(0.12), {
			Position = goal,
			BackgroundColor3 = state and Theme.col.goldHi or Theme.col.textDim,
		}):Play()
		tstroke.Color = state and Theme.col.gold or Theme.col.strokeLo
		track.BackgroundColor3 = state and Theme.col.bg3 or Theme.col.bg0
	end

	local function refresh()
		paint(o.get() and true or false)
	end

	track.MouseButton1Click:Connect(function()
		local nv = not o.get()
		o.set(nv)
		paint(nv)
	end)

	refresh()
	table.insert(self.window.refreshers, refresh)
	return {Refresh = refresh, Set = function(_, v) o.set(v) paint(v) end}
end

-- ── Slider ───────────────────────────────────────────────────────────
function Section:Slider(o)
	local height = Theme.SliderHeight()
	local row = baseRow(self, height)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Theme.font.body
	label.TextSize = Theme.TextSize("body")
	label.TextColor3 = Theme.col.text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = o.text
	label.Position = UDim2.new(0, 10, 0, 4)
	label.Size = UDim2.new(1, -90, 0, 18)
	label.Parent = row

	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Font = Theme.font.mono
	value.TextSize = Theme.TextSize("small")
	value.TextColor3 = Theme.col.goldHi
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.new(1, -10, 0, 5)
	value.Size = UDim2.fromOffset(78, 16)
	value.Parent = row

	local track = Instance.new("Frame")
	track.BackgroundColor3 = Theme.col.bg0
	track.BorderSizePixel = 0
	track.AnchorPoint = Vector2.new(0, 1)
	track.Position = UDim2.new(0, 10, 1, -10)
	track.Size = UDim2.new(1, -20, 0, 6)
	track.Parent = row
	Theme.Corner(track, 3)
	Theme.Stroke(track, Theme.col.strokeLo, 1)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Theme.col.gold
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	Theme.Corner(fill, 3)
	Theme.GoldGradient(fill, 0)

	local knob = Instance.new("Frame")
	knob.BackgroundColor3 = Theme.col.goldHi
	knob.BorderSizePixel = 0
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0, 0.5)
	knob.Size = UDim2.fromOffset(Svc.IsMobile() and 20 or 14, Svc.IsMobile() and 20 or 14)
	knob.ZIndex = 3
	knob.Parent = track
	Theme.Corner(knob, 10)
	Theme.Stroke(knob, Theme.col.goldLo, 1)

	-- Fat invisible hit area so a thumb can grab the 6px track.
	local hit = Instance.new("TextButton")
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.AnchorPoint = Vector2.new(0.5, 0.5)
	hit.Position = UDim2.fromScale(0.5, 0.5)
	hit.Size = UDim2.new(1, 24, 0, 34)
	hit.ZIndex = 4
	hit.Parent = track

	local minV, maxV = o.min, o.max
	local step = o.step or 1
	local suffix = o.suffix or ""

	local function quantise(v)
		local snapped = math.floor((v - minV) / step + 0.5) * step + minV
		return Util.Clamp(snapped, minV, maxV)
	end

	local function format(v)
		if step < 1 then return string.format("%.2f%s", v, suffix) end
		return string.format("%d%s", math.floor(v + 0.5), suffix)
	end

	local function paint(v)
		local alpha = 0
		if maxV > minV then alpha = (v - minV) / (maxV - minV) end
		alpha = Util.Clamp(alpha, 0, 1)
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		value.Text = format(v)
	end

	local function refresh() paint(o.get()) end

	local dragging = false
	local function applyFromX(x)
		local left = track.AbsolutePosition.X
		local width = math.max(track.AbsoluteSize.X, 1)
		local alpha = Util.Clamp((x - left) / width, 0, 1)
		local v = quantise(minV + alpha * (maxV - minV))
		o.set(v)
		paint(v)
	end

	hit.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		dragging = true
		applyFromX(input.Position.X)
	end)
	hit.InputEnded:Connect(function(input)
		if isPress(input) then dragging = false end
	end)
	UIS.InputChanged:Connect(function(input)
		if dragging and isMove(input) then applyFromX(input.Position.X) end
	end)
	UIS.InputEnded:Connect(function(input)
		if isPress(input) then dragging = false end
	end)

	refresh()
	table.insert(self.window.refreshers, refresh)
	return {Refresh = refresh}
end

-- ── Dropdown (inline expansion, no overlay) ──────────────────────────
function Section:Dropdown(o)
	local row = baseRow(self, nil)
	rowLabel(row, o.text, -150)

	local btn = Instance.new("TextButton")
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = Theme.col.bg0
	btn.BorderSizePixel = 0
	btn.Font = Theme.font.body
	btn.TextSize = Theme.TextSize("small")
	btn.TextColor3 = Theme.col.goldHi
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, -10, 0.5, 0)
	btn.Size = UDim2.fromOffset(136, Theme.RowHeight() - 12)
	btn.Text = "..."
	btn.Parent = row
	Theme.Corner(btn, 4)
	Theme.Stroke(btn, Theme.col.strokeLo, 1)

	local panel = Instance.new("Frame")
	panel.BackgroundColor3 = Theme.col.bg0
	panel.BorderSizePixel = 0
	panel.Size = UDim2.new(1, 0, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Visible = false
	panel.LayoutOrder = self:next()
	panel.Parent = self.frame
	Theme.Corner(panel, 5)
	Theme.Stroke(panel, Theme.col.strokeLo, 1)

	local plist = Instance.new("UIListLayout")
	plist.Padding = UDim.new(0, 2)
	plist.SortOrder = Enum.SortOrder.LayoutOrder
	plist.Parent = panel
	Theme.Pad(panel, 4, 4, 4, 4)

	local optionButtons = {}

	local function labelFor(v)
		for i, name in ipairs(o.options) do
			if i == v or name == v then return name end
		end
		return tostring(v)
	end

	local function refresh()
		local cur = o.get()
		btn.Text = labelFor(cur)
		for i, b in ipairs(optionButtons) do
			local on = (o.byIndex and i == cur) or (not o.byIndex and o.options[i] == cur)
			b.TextColor3 = on and Theme.col.goldHi or Theme.col.textDim
			b.BackgroundColor3 = on and Theme.col.bg3 or Theme.col.bg1
		end
	end

	for i, name in ipairs(o.options) do
		local ob = Instance.new("TextButton")
		ob.AutoButtonColor = false
		ob.BackgroundColor3 = Theme.col.bg1
		ob.BorderSizePixel = 0
		ob.Font = Theme.font.body
		ob.TextSize = Theme.TextSize("small")
		ob.TextColor3 = Theme.col.textDim
		ob.Text = name
		ob.Size = UDim2.new(1, 0, 0, Svc.IsMobile() and 34 or 26)
		ob.LayoutOrder = i
		ob.Parent = panel
		Theme.Corner(ob, 4)
		optionButtons[i] = ob
		ob.MouseButton1Click:Connect(function()
			if o.byIndex then o.set(i) else o.set(name) end
			panel.Visible = false
			refresh()
		end)
	end

	btn.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
	end)

	refresh()
	table.insert(self.window.refreshers, refresh)
	return {Refresh = refresh}
end

-- ── Button ───────────────────────────────────────────────────────────
function Section:Button(o)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = Theme.col.bg3
	b.BorderSizePixel = 0
	b.Font = Theme.font.title
	b.TextSize = Theme.TextSize("body")
	b.TextColor3 = o.tone == "bad" and Theme.col.bad or Theme.col.goldHi
	b.Text = o.text
	b.Size = UDim2.new(1, 0, 0, Theme.RowHeight())
	b.LayoutOrder = self:next()
	b.Parent = self.frame
	Theme.Corner(b, 5)
	Theme.Stroke(b, o.tone == "bad" and Theme.col.bad or Theme.col.goldLo, 1)
	hoverTint(b, Theme.col.bg3, Theme.col.bg2)
	b.MouseButton1Click:Connect(function()
		local ok, err = pcall(o.callback)
		if not ok then Notify.Bad("fault", tostring(err)) end
	end)
	return {instance = b, SetText = function(_, t) b.Text = t end}
end

-- ── TextBox ──────────────────────────────────────────────────────────
function Section:TextBox(o)
	local row = baseRow(self, nil)
	rowLabel(row, o.text, -170)

	local box = Instance.new("TextBox")
	box.BackgroundColor3 = Theme.col.bg0
	box.BorderSizePixel = 0
	box.Font = Theme.font.mono
	box.TextSize = Theme.TextSize("small")
	box.TextColor3 = Theme.col.text
	box.PlaceholderText = o.placeholder or ""
	box.PlaceholderColor3 = Theme.col.textDim
	box.ClearTextOnFocus = false
	box.AnchorPoint = Vector2.new(1, 0.5)
	box.Position = UDim2.new(1, -10, 0.5, 0)
	box.Size = UDim2.fromOffset(156, Theme.RowHeight() - 12)
	box.Text = ""
	box.Parent = row
	Theme.Corner(box, 4)
	Theme.Stroke(box, Theme.col.strokeLo, 1)

	local function refresh() box.Text = tostring(o.get()) end

	box.FocusLost:Connect(function()
		o.set(box.Text)
		refresh()
	end)

	refresh()
	table.insert(self.window.refreshers, refresh)
	return {Refresh = refresh}
end

-- ── Keybind (keyboard + gamepad in one row) ──────────────────────────
local padNames = {
	"ButtonA", "ButtonB", "ButtonX", "ButtonY",
	"ButtonL1", "ButtonR1", "ButtonL2", "ButtonR2",
	"ButtonL3", "ButtonR3", "ButtonSelect", "ButtonStart",
	"DPadUp", "DPadDown", "DPadLeft", "DPadRight",
}
UI.PadNames = padNames

function Section:Keybind(o)
	local row = baseRow(self, nil)
	rowLabel(row, o.text, -170)

	local function mkBtn(xOffset, width)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.BackgroundColor3 = Theme.col.bg0
		b.BorderSizePixel = 0
		b.Font = Theme.font.mono
		b.TextSize = Theme.TextSize("small")
		b.TextColor3 = Theme.col.goldHi
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, xOffset, 0.5, 0)
		b.Size = UDim2.fromOffset(width, Theme.RowHeight() - 12)
		b.Text = "-"
		b.Parent = row
		Theme.Corner(b, 4)
		Theme.Stroke(b, Theme.col.strokeLo, 1)
		return b
	end

	local keyBtn = mkBtn(-92, 72)
	local padBtn = mkBtn(-10, 78)

	local function refresh()
		local k, p = o.get()
		keyBtn.Text = (k ~= nil and k ~= "") and k or "-"
		padBtn.Text = (p ~= nil and p ~= "") and p or "-"
	end

	local listening = false
	keyBtn.MouseButton1Click:Connect(function()
		if listening then return end
		listening = true
		keyBtn.Text = "..."
		local conn
		conn = UIS.InputBegan:Connect(function(input, gpe)
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			conn:Disconnect()
			listening = false
			local name = input.KeyCode.Name
			if name == "Backspace" or name == "Escape" then name = "" end
			o.set(name, nil)
			refresh()
		end)
	end)

	local padIndex = 0
	padBtn.MouseButton1Click:Connect(function()
		-- Cycling is the only reliable way to set a pad bind on a phone.
		padIndex = padIndex + 1
		if padIndex > #padNames then
			padIndex = 0
			o.set(nil, "")
		else
			o.set(nil, padNames[padIndex])
		end
		refresh()
	end)

	refresh()
	table.insert(self.window.refreshers, refresh)
	return {Refresh = refresh}
end

-- ── Read-only value row, driven by a poller ──────────────────────────
function Section:Readout(o)
	local row = baseRow(self, nil)
	rowLabel(row, o.text, -170)

	local v = Instance.new("TextLabel")
	v.BackgroundTransparency = 1
	v.Font = Theme.font.mono
	v.TextSize = Theme.TextSize("small")
	v.TextColor3 = Theme.col.textDim
	v.TextXAlignment = Enum.TextXAlignment.Right
	v.TextTruncate = Enum.TextTruncate.AtEnd
	v.AnchorPoint = Vector2.new(1, 0.5)
	v.Position = UDim2.new(1, -10, 0.5, 0)
	v.Size = UDim2.fromOffset(170, Theme.RowHeight() - 10)
	v.Text = "-"
	v.Parent = row

	return {
		Set = function(_, text, tone)
			v.Text = tostring(text)
			if tone == "good" then v.TextColor3 = Theme.col.good
			elseif tone == "bad" then v.TextColor3 = Theme.col.bad
			elseif tone == "gold" then v.TextColor3 = Theme.col.goldHi
			else v.TextColor3 = Theme.col.textDim end
		end,
	}
end

UI.Section = Section
UI.Tab = Tab
UI.WindowClass = Window

return UI
end

-- ===== binds  (src/09_binds.lua) =====
__src["binds"] = function(_R)
-- @module binds
-- One input listener for the whole tool. Keyboard and gamepad resolve to
-- the same action id, so every feature has both without duplicate code.
local Svc   = _R("svc")
local Cfg   = _R("cfg")
local Util  = _R("util")
local Notify= _R("notify")

local B = {}

local UIS = Svc.UserInputService
local actions = {}      -- id -> {fn = function, label = string}
local maid = Util.Maid.new()
local suspended = false

function B.Register(id, label, fn)
	actions[id] = {fn = fn, label = label}
end

function B.Labels()
	local out = {}
	for id, a in pairs(actions) do out[#out + 1] = {id = id, label = a.label} end
	table.sort(out, function(x, y) return x.id < y.id end)
	return out
end

function B.Suspend(state)
	suspended = state
end

local function fire(id)
	local a = actions[id]
	if not a then return end
	local ok, err = pcall(a.fn)
	if not ok then
		Notify.Bad("bind fault", id .. ": " .. tostring(err))
	end
end

local function matchKeyboard(name)
	for id, bind in pairs(Cfg.s.binds) do
		if bind.key ~= nil and bind.key ~= "" and bind.key == name then return id end
	end
	return nil
end

local function matchPad(name)
	for id, bind in pairs(Cfg.s.binds) do
		if bind.pad ~= nil and bind.pad ~= "" and bind.pad == name then return id end
	end
	return nil
end

function B.Init()
	maid:Clean()
	maid:Give(UIS.InputBegan:Connect(function(input, processed)
		if suspended then return end
		if processed then return end
		local t = input.UserInputType
		if t == Enum.UserInputType.Keyboard then
			local id = matchKeyboard(input.KeyCode.Name)
			if id then fire(id) end
			if input.KeyCode.Name == Cfg.s.settings.menuKey then fire("menu") end
		elseif t == Enum.UserInputType.Gamepad1
			or t == Enum.UserInputType.Gamepad2
			or t == Enum.UserInputType.Gamepad3
			or t == Enum.UserInputType.Gamepad4 then
			local id = matchPad(input.KeyCode.Name)
			if id then fire(id) end
		end
	end))
end

-- Held state for binds that act while down rather than toggling.
function B.IsHeld(id)
	local bind = Cfg.s.binds[id]
	if not bind then return false end
	if bind.key and bind.key ~= "" then
		local ok, code = pcall(function() return Enum.KeyCode[bind.key] end)
		if ok and code and UIS:IsKeyDown(code) then return true end
	end
	if bind.pad and bind.pad ~= "" then
		local ok, code = pcall(function() return Enum.KeyCode[bind.pad] end)
		if ok and code then
			for _, state in ipairs(UIS:GetGamepadState(Enum.UserInputType.Gamepad1)) do
				if state.KeyCode == code then
					if state.UserInputState == Enum.UserInputState.Begin then return true end
					if type(state.Position) == "userdata" and state.Position.Z > 0.5 then return true end
				end
			end
		end
	end
	return false
end

function B.Fire(id) fire(id) end

function B.Destroy()
	maid:Clean()
	actions = {}
end

return B
end

-- ===== touchui  (src/10_touchui.lua) =====
__src["touchui"] = function(_R)
-- @module touchui
-- Draggable on-screen action buttons. Size and shape come from settings;
-- positions persist per button id. Works with a finger or a mouse.
local Svc   = _R("svc")
local Cfg   = _R("cfg")
local Theme = _R("theme")
local Util  = _R("util")
local Notify= _R("notify")
local Binds = _R("binds")

local TB = {}

local UIS = Svc.UserInputService
local gui = nil
local buttons = {}     -- id -> {frame, label, glow, state}
local maid = Util.Maid.new()
local DRAG_SLOP = 6

-- id, caption, settings path to light the button from (or nil)
TB.layout = {
	{id = "reach",   caption = "RCH", lit = function() return Cfg.s.reach.enabled end},
	{id = "sneaky",  caption = "SNK", lit = function() return Cfg.s.skills.sneaky end},
	{id = "aimbot",  caption = "AIM", lit = function() return Cfg.s.aim.aimbot end},
	{id = "aimpass", caption = "PAS", lit = function() return Cfg.s.pass.enabled end},
	{id = "autogk",  caption = "GK",  lit = function() return Cfg.s.keeper.autoGK end},
	{id = "phase",   caption = "PHS", lit = function() return Cfg.s.special.phase end},
	{id = "juggle",  caption = "JGL", lit = function() return Cfg.s.skills.juggle end},
	{id = "pokers",  caption = "POK", lit = function() return Cfg.s.skills.pokers end},
	{id = "nero",    caption = "NER", lit = function() return false end},
	{id = "bring",   caption = "BRG", lit = function() return false end},
	{id = "freeze",  caption = "FRZ", lit = function() return Cfg.s.special.ballFrozen end},
	{id = "menu",    caption = "LC",  lit = function() return true end},
}

local function shapeButton(frame, size, shape)
	for _, c in ipairs(frame:GetChildren()) do
		if c.Name == "ShapeBit" then c:Destroy() end
	end
	local corner = frame:FindFirstChildOfClass("UICorner")
	if not corner then corner = Theme.Corner(frame, 6) end

	if shape == 2 then
		corner.CornerRadius = UDim.new(0, math.floor(size / 2))
	elseif shape == 3 then
		corner.CornerRadius = UDim.new(0, 6)
	else
		-- shield: rounded top, pointed bottom from a rotated square behind
		corner.CornerRadius = UDim.new(0, math.floor(size * 0.32))
		local point = Instance.new("Frame")
		point.Name = "ShapeBit"
		point.BackgroundColor3 = frame.BackgroundColor3
		point.BackgroundTransparency = frame.BackgroundTransparency
		point.BorderSizePixel = 0
		point.AnchorPoint = Vector2.new(0.5, 0.5)
		point.Position = UDim2.new(0.5, 0, 1, -math.floor(size * 0.18))
		point.Size = UDim2.fromOffset(math.floor(size * 0.66), math.floor(size * 0.66))
		point.Rotation = 45
		point.ZIndex = frame.ZIndex - 1
		point.Parent = frame
		Theme.Corner(point, 4)
	end
end

local function defaultPosition(index)
	local vp = Svc.ViewportSize()
	local size = Cfg.s.settings.touchSize
	local gap = 8
	local perColumn = math.max(math.floor((vp.Y - 160) / (size + gap)), 1)
	local col = math.floor((index - 1) / perColumn)
	local rowIndex = (index - 1) % perColumn
	local x = vp.X - (size + gap) * (col + 1) - 8
	local y = 90 + rowIndex * (size + gap)
	return x, y
end

local function makeButton(def, index)
	local size = Cfg.s.settings.touchSize
	local frame = Instance.new("TextButton")
	frame.Name = "TB_" .. def.id
	frame.AutoButtonColor = false
	frame.Text = ""
	frame.BackgroundColor3 = Theme.col.bg1
	frame.BackgroundTransparency = Cfg.s.settings.touchAlpha
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromOffset(size, size)
	frame.ZIndex = 5
	frame.Parent = gui

	local saved = Cfg.s.settings.touchPos[def.id]
	local x, y
	if type(saved) == "table" and saved.x and saved.y then
		x, y = saved.x, saved.y
	else
		x, y = defaultPosition(index)
	end
	local vp = Svc.ViewportSize()
	x = Util.Clamp(x, 0, math.max(vp.X - size, 0))
	y = Util.Clamp(y, 0, math.max(vp.Y - size, 0))
	frame.Position = UDim2.fromOffset(x, y)

	local stroke = Theme.Stroke(frame, Theme.col.goldLo, 1)
	shapeButton(frame, size, Cfg.s.settings.touchShape)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Theme.font.title
	label.TextSize = math.max(12, math.floor(size * 0.30))
	label.TextColor3 = Theme.col.text
	label.Size = UDim2.fromScale(1, 1)
	label.ZIndex = 7
	label.Text = def.caption
	label.Parent = frame

	local entry = {frame = frame, label = label, stroke = stroke, def = def}
	buttons[def.id] = entry

	-- drag with press-through: a short press fires, a long move drags.
	local dragging, moved, startPos, startInput = false, false, nil, nil

	frame.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then return end
		dragging = true
		moved = false
		startInput = input
		startPos = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
		local origin = Vector2.new(input.Position.X, input.Position.Y)
		entry.origin = origin
	end)

	frame.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if dragging and not moved then
			Binds.Fire(def.id)
			TB.Repaint()
		end
		if dragging and moved then
			Cfg.s.settings.touchPos[def.id] = {
				x = frame.Position.X.Offset,
				y = frame.Position.Y.Offset,
			}
		end
		dragging = false
		moved = false
	end)

	maid:Give(UIS.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if startInput and input.UserInputType == Enum.UserInputType.Touch and input ~= startInput then return end
		local now = Vector2.new(input.Position.X, input.Position.Y)
		local delta = now - entry.origin
		if delta.Magnitude > DRAG_SLOP then moved = true end
		if not moved then return end
		local vpz = Svc.ViewportSize()
		local nx = Util.Clamp(startPos.X + delta.X, 0, math.max(vpz.X - frame.AbsoluteSize.X, 0))
		local ny = Util.Clamp(startPos.Y + delta.Y, 0, math.max(vpz.Y - frame.AbsoluteSize.Y, 0))
		frame.Position = UDim2.fromOffset(nx, ny)
	end))

	return entry
end

function TB.Repaint()
	for _, entry in pairs(buttons) do
		local on = false
		local ok, v = pcall(entry.def.lit)
		if ok then on = v and true or false end
		entry.stroke.Color = on and Theme.col.goldHi or Theme.col.goldLo
		entry.label.TextColor3 = on and Theme.col.goldHi or Theme.col.textDim
		entry.frame.BackgroundColor3 = on and Theme.col.bg3 or Theme.col.bg1
		local bit = entry.frame:FindFirstChild("ShapeBit")
		if bit then bit.BackgroundColor3 = entry.frame.BackgroundColor3 end
	end
end

function TB.Rebuild()
	TB.Destroy()
	if not Cfg.s.settings.touchButtons then return end

	gui = Instance.new("ScreenGui")
	gui.Name = "LC_Touch"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 998
	gui.Parent = Notify.GuiParent()
	maid:Give(gui)

	for i, def in ipairs(TB.layout) do
		makeButton(def, i)
	end
	TB.Repaint()
end

function TB.Destroy()
	maid:Clean()
	buttons = {}
	gui = nil
end

-- Live button count, used by the headless rig and by nothing else.
function TB.Count()
	local n = 0
	for _ in pairs(buttons) do n = n + 1 end
	return n
end

function TB.Visible(state)
	if gui then gui.Enabled = state end
end

return TB
end

-- ===== resolve  (src/11_resolve.lua) =====
__src["resolve"] = function(_R)
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
end

-- ===== backend  (src/12_backend.lua) =====
__src["backend"] = function(_R)
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
BE.lastLaunchClock = -1e9
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
-- Fire one named remote with one explicit shape. The learner uses this to
-- probe candidates; the normal path goes through fireRemote below.
function BE.FireRemoteNamed(name, shape, velocity, power)
	if type(name) ~= "string" or name == "" then return false, "no name" end
	local rem = R.FindRemote(name)
	if not rem then return false, "not in this place" end
	local dir = AM.SafeUnit(velocity)
	local ok, err = pcall(function()
		if shape == "dir_power" then
			rem:FireServer(dir, power)
		elseif shape == "vector" then
			rem:FireServer(velocity)
		elseif shape == "cframe" then
			local b = R.Ball()
			local origin = b and b.Position or (Svc.HRP() and Svc.HRP().Position) or AM.ZERO
			rem:FireServer(CFrame.lookAt(origin, origin + dir), power)
		elseif shape == "bare" then
			rem:FireServer()
		else
			error("unsupported kickArgShape '" .. tostring(shape) .. "'")
		end
	end)
	if not ok then return false, tostring(err) end
	return true, "sent"
end

local function fireRemote(velocity, power)
	local ok = BE.FireRemoteNamed(Cfg.target.kickRemote, Cfg.target.kickArgShape, velocity, power)
	return ok
end

-- ── the one call features make ───────────────────────────────────────
-- velocity is the full launch vector from amath. power is the game-facing
-- scalar for the remote path. Returns ok, backendName.
function BE.Launch(velocity, power)
	if not AM.Finite(velocity) then return false, "bad velocity" end
	BE.lastLaunchClock = Util.Now()

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
end

-- ===== learn  (src/13_learn.lua) =====
__src["learn"] = function(_R)
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
end

-- ===== calib  (src/14_calib.lua) =====
__src["calib"] = function(_R)
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
end

-- ===== reach  (src/15_reach.lua) =====
__src["reach"] = function(_R)
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
end

-- ===== skills  (src/16_skills.lua) =====
__src["skills"] = function(_R)
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
end

-- ===== aimbot  (src/17_aimbot.lua) =====
__src["aimbot"] = function(_R)
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
end

-- ===== aimpass  (src/18_aimpass.lua) =====
__src["aimpass"] = function(_R)
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
end

-- ===== keeper  (src/19_keeper.lua) =====
__src["keeper"] = function(_R)
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
end

-- ===== special  (src/20_special.lua) =====
__src["special"] = function(_R)
-- @module special
-- Target selection, phase, farms, ball handling and the trick macros.
--
-- Frame Player is the selector the other features read: it picks one
-- player, draws a frame on them, and Phase / AimPass "selected" mode act
-- on whoever is framed.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local AM     = _R("amath")
local R      = _R("resolve")
local BE     = _R("backend")
local Aim    = _R("aimbot")
local Theme  = _R("theme")
local Notify = _R("notify")
local Env    = _R("env")

local SP = {}

SP.selected = nil
SP.phased = {}            -- part -> original CanCollide
local frameGui, frameBox, frameLabel
local lastFarm = 0
local lastSaveFarm = 0
local trickRunning = false
local maid = Util.Maid.new()

-- ── target selection ─────────────────────────────────────────────────
function SP.LookTarget()
	local cam = Svc.Camera()
	if not cam then return nil end
	local best, bestPx = nil, math.huge
	local vp = cam.ViewportSize
	local centre = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
	for _, p in ipairs(R.Enemies()) do
		local hrp = Svc.HRP(p)
		if hrp then
			local screen, visible = AM.WorldToScreen(cam, hrp.Position)
			if visible then
				local px = (screen - centre).Magnitude
				if px < bestPx then best, bestPx = p, px end
			end
		end
	end
	return best
end

function SP.CurrentTarget()
	if Cfg.s.special.phaseMode == 2 then return SP.selected end
	return SP.LookTarget()
end

function SP.SelectUnderCrosshair()
	SP.selected = SP.LookTarget()
	if SP.selected then
		Notify.Info("framed", SP.selected.Name)
	else
		Notify.Warn("framed", "nobody under the crosshair")
	end
	return SP.selected
end

-- ── Frame Player overlay ─────────────────────────────────────────────
local function ensureFrameGui()
	if frameGui and frameGui.Parent then return end
	frameGui = Instance.new("ScreenGui")
	frameGui.Name = "LC_Frame"
	frameGui.ResetOnSpawn = false
	frameGui.IgnoreGuiInset = true
	frameGui.DisplayOrder = 950
	frameGui.Parent = _R("notify").GuiParent()
	maid:Give(frameGui)

	frameBox = Instance.new("Frame")
	frameBox.BackgroundTransparency = 1
	frameBox.BorderSizePixel = 0
	frameBox.AnchorPoint = Vector2.new(0.5, 0.5)
	frameBox.Size = UDim2.fromOffset(60, 90)
	frameBox.Visible = false
	frameBox.Parent = frameGui
	Theme.Stroke(frameBox, Theme.col.gold, 2)
	Theme.Corner(frameBox, 4)

	frameLabel = Instance.new("TextLabel")
	frameLabel.BackgroundTransparency = 1
	frameLabel.Font = Theme.font.title
	frameLabel.TextSize = 14
	frameLabel.TextColor3 = Theme.col.goldHi
	frameLabel.TextStrokeTransparency = 0.4
	frameLabel.Size = UDim2.new(1, 40, 0, 16)
	frameLabel.Position = UDim2.new(0, -20, 0, -20)
	frameLabel.Text = ""
	frameLabel.Parent = frameBox
end

function SP.StepFrame()
	if not Cfg.s.special.framePlayer then
		if frameBox then frameBox.Visible = false end
		return
	end
	ensureFrameGui()
	local target = SP.CurrentTarget()
	if not target then
		frameBox.Visible = false
		return
	end
	local hrp = Svc.HRP(target)
	local cam = Svc.Camera()
	if not hrp or not cam then
		frameBox.Visible = false
		return
	end
	local head = Svc.Head(target) or hrp
	local topPos, topVis = AM.WorldToScreen(cam, head.Position + Vector3.new(0, 1.6, 0))
	local botPos, botVis = AM.WorldToScreen(cam, hrp.Position - Vector3.new(0, 3.2, 0))
	if not (topVis or botVis) then
		frameBox.Visible = false
		return
	end
	local height = math.max(math.abs(botPos.Y - topPos.Y), 20)
	local width = height * 0.6
	frameBox.Visible = true
	frameBox.Position = UDim2.fromOffset((topPos.X + botPos.X) * 0.5, (topPos.Y + botPos.Y) * 0.5)
	frameBox.Size = UDim2.fromOffset(width, height)
	local dist = (hrp.Position - (Svc.HRP() and Svc.HRP().Position or hrp.Position)).Magnitude
	frameLabel.Text = string.format("%s  %dm", target.Name, math.floor(dist))
end

-- ── Phase / Anti-Phase ───────────────────────────────────────────────
local function setCollide(plr, state)
	for _, part in ipairs(Svc.Parts(plr)) do
		if SP.phased[part] == nil then SP.phased[part] = part.CanCollide end
		pcall(function() part.CanCollide = state end)
	end
end

function SP.RestorePhase()
	for part, original in pairs(SP.phased) do
		if part and part.Parent then
			pcall(function() part.CanCollide = original end)
		end
	end
	SP.phased = {}
end

function SP.StepPhase()
	local s = Cfg.s.special

	if s.antiPhase then
		for _, p in ipairs(R.Enemies()) do
			for _, part in ipairs(Svc.Parts(p)) do
				if part.Name ~= "HumanoidRootPart" then
					pcall(function() part.CanCollide = true end)
				end
			end
		end
	end

	if not s.phase then
		if next(SP.phased) ~= nil then SP.RestorePhase() end
		return
	end

	local target = SP.CurrentTarget()
	if not target then return end
	setCollide(target, false)
	-- our own parts too, otherwise the server still wedges us on theirs
	for _, part in ipairs(Svc.Parts()) do
		if SP.phased[part] == nil then SP.phased[part] = part.CanCollide end
		pcall(function() part.CanCollide = false end)
	end
end

function SP.TogglePhase()
	Cfg.s.special.phase = not Cfg.s.special.phase
	if not Cfg.s.special.phase then SP.RestorePhase() end
	Notify.Info("phase", Cfg.s.special.phase and "on" or "off")
end

-- ── Ball handling ────────────────────────────────────────────────────
function SP.BringBall()
	local ball = R.Ball()
	local hrp = Svc.HRP()
	if not ball or not hrp then
		Notify.Warn("bring ball", "no ball or no character")
		return false
	end
	BE.ClaimOwnership()
	local target = hrp.Position + hrp.CFrame.LookVector * Cfg.s.special.bringDistance + Vector3.new(0, 3, 0)
	local ok = BE.SetCFrame(CFrame.new(target))
	BE.SetVelocity(hrp.AssemblyLinearVelocity)
	if not ok then
		-- no write permission: pull it with velocity instead
		local delta = target - ball.Position
		BE.SetVelocity(delta * 6)
	end
	return true
end

function SP.DeleteBall()
	local ball = R.Ball()
	if not ball then return false end
	-- local only: the server still has it, this clears your own render
	local ok = pcall(function() ball:Destroy() end)
	if ok then
		R.ball = nil
		R.ballTier = "unknown"
		Notify.Warn("delete ball", "removed locally; the server copy is untouched")
	end
	return ok
end

function SP.ToggleFreeze()
	local state = not Cfg.s.special.ballFrozen
	BE.Freeze(state)
	Notify.Info("ball", state and "frozen" or "released")
end

function SP.StepBallTime(dt)
	local s = Cfg.s.special
	if not s.ballTime then return end
	local ball = R.Ball()
	if not ball or ball.Anchored then return end
	local v = ball.AssemblyLinearVelocity
	if v.Magnitude < 1 then return end
	local scaled = v * s.ballTimeScale
	if scaled.Magnitude > 2000 then return end
	BE.SetVelocity(scaled)
end

-- ── Dunk ─────────────────────────────────────────────────────────────
function SP.StepDunk(dt, now)
	local s = Cfg.s.special
	if not s.dunk then return end
	local goal = R.enemyGoal
	local ball = R.Ball()
	local hrp = Svc.HRP()
	if not goal or not ball or not hrp then return end

	local toGoal = (goal.cf.Position - hrp.Position).Magnitude
	if toGoal > s.dunkRange then return end
	if (ball.Position - hrp.Position).Magnitude > Cfg.s.reach.radius then return end

	local mouth = AM.GoalCentre(goal.cf, goal.size)
	local dir = AM.SafeUnit(mouth - ball.Position)
	if dir == AM.ZERO then return end
	BE.TouchPulse()
	BE.Launch(dir * math.max(toGoal * 3, 60), Cfg.s.aim.power)
end

-- ── Farms ────────────────────────────────────────────────────────────
function SP.StepGoalFarm(dt, now)
	local s = Cfg.s.special
	if not s.goalFarm then return end
	if now - lastFarm < s.goalFarmDelay then return end
	if not R.enemyGoal then
		Notify.Once("farm_nogoal", "goal farm",
			"no enemy goal resolved. CONFIG tab: stand in the goal and press Capture Enemy Goal.", "warn")
		return
	end
	lastFarm = now
	SP.BringBall()
	task.delay(0.12, function()
		Aim.Shoot(nil)
	end)
end

function SP.StepSaveFarm(dt, now)
	local s = Cfg.s.special
	if not s.saveFarm then return end
	if now - lastSaveFarm < s.saveFarmDelay then return end
	if not R.ownGoal then
		Notify.Once("savefarm_nogoal", "save farm",
			"no own goal resolved. CONFIG tab: stand in your goal and press Capture Own Goal.", "warn")
		return
	end
	lastSaveFarm = now

	-- put the ball on a line into our own goal, then clear it on the next tick
	local ball = R.Ball()
	local hrp = Svc.HRP()
	if not ball or not hrp then return end
	BE.ClaimOwnership()
	local mouth = AM.GoalCentre(R.ownGoal.cf, R.ownGoal.size)
	local start = mouth + R.ownGoal.cf.LookVector * 26 + Vector3.new(0, 6, 0)
	BE.SetCFrame(CFrame.new(start))
	local vel = AM.SafeUnit(mouth - start) * 70
	BE.SetVelocity(vel)
end

-- ── Trick macros ─────────────────────────────────────────────────────
-- Each step is an impulse in character-local space plus a wait. They are
-- built from the same primitives as everything else, no special casing.
SP.tricks = {
	{
		name = "Rainbow Flick",
		steps = {
			{vel = Vector3.new(0, 1.0, -0.25), power = 46, wait = 0.12, spin = 14},
			{vel = Vector3.new(0, 0.45, -1.0), power = 54, wait = 0.18, spin = 8},
		},
	},
	{
		name = "Sombrero",
		steps = {
			{vel = Vector3.new(0, 1.15, 0.1), power = 40, wait = 0.22, spin = 6},
			{vel = Vector3.new(0, 0.2, -1.0), power = 62, wait = 0.10, spin = 0},
		},
	},
	{
		name = "Fake Shot",
		steps = {
			{vel = Vector3.new(0.6, 0.12, -0.8), power = 30, wait = 0.14, spin = 10},
			{vel = Vector3.new(-0.9, 0.08, -0.6), power = 58, wait = 0.12, spin = -10},
		},
	},
}

function SP.RunTrick(index)
	if trickRunning then return false end
	local trick = SP.tricks[index or Cfg.s.special.trickIndex]
	if not trick then return false end
	local hrp = Svc.HRP()
	if not hrp or not R.Ball() then
		Notify.Warn("trick", "need a character and a resolved ball")
		return false
	end

	trickRunning = true
	task.spawn(function()
		for _, step in ipairs(trick.steps) do
			local root = Svc.HRP()
			if not root then break end
			local world = root.CFrame:VectorToWorldSpace(step.vel)
			local vel = AM.SafeUnit(world) * step.power
			if AM.Finite(vel) then
				BE.TouchPulse()
				BE.Launch(vel, step.power)
				if step.spin ~= 0 then
					BE.SetSpin(AM.CurveSpin(vel, step.spin / 20, 20))
				end
			end
			task.wait(step.wait)
		end
		trickRunning = false
	end)
	Notify.Info("trick", trick.name)
	return true
end

function SP.StepTricks(dt, now)
	if not Cfg.s.special.trickOms then return end
	if trickRunning then return end
	local ball = R.Ball()
	local hrp = Svc.HRP()
	if not ball or not hrp then return end
	if (ball.Position - hrp.Position).Magnitude > Cfg.s.reach.radius then return end
	SP.RunTrick(Cfg.s.special.trickIndex)
end

function SP.Step(dt, now)
	SP.StepPhase()
	SP.StepFrame()
	SP.StepBallTime(dt)
	SP.StepDunk(dt, now)
	SP.StepGoalFarm(dt, now)
	SP.StepSaveFarm(dt, now)
	SP.StepTricks(dt, now)
end

function SP.Destroy()
	SP.RestorePhase()
	maid:Clean()
	frameGui, frameBox, frameLabel = nil, nil, nil
end

return SP
end

-- ===== visuals  (src/21_visuals.lua) =====
__src["visuals"] = function(_R)
-- @module visuals
-- Everything cosmetic. All of it is local: nothing here is replicated and
-- nothing here changes what the server sees.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local AM     = _R("amath")
local R      = _R("resolve")
local Theme  = _R("theme")
local Notify = _R("notify")
local Env    = _R("env")

local V = {}

local maid = Util.Maid.new()
local gui, tracer, distLabel
local highlight = nil
local ballTrail, ballA0, ballA1 = nil, nil, nil
local bootTrails = {}
local rgbOriginal = {}
local hue = 0
local spoofPanel, spoofLines
local statsHookInstalled = false

local function ensureGui()
	if gui and gui.Parent then return end
	gui = Instance.new("ScreenGui")
	gui.Name = "LC_Visuals"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 940
	gui.Parent = _R("notify").GuiParent()
	maid:Give(gui)

	tracer = Instance.new("Frame")
	tracer.BackgroundColor3 = Theme.col.gold
	tracer.BorderSizePixel = 0
	tracer.AnchorPoint = Vector2.new(0, 0.5)
	tracer.Size = UDim2.fromOffset(0, 2)
	tracer.Visible = false
	tracer.Parent = gui

	distLabel = Instance.new("TextLabel")
	distLabel.BackgroundTransparency = 1
	distLabel.Font = Theme.font.mono
	distLabel.TextSize = 13
	distLabel.TextColor3 = Theme.col.goldHi
	distLabel.TextStrokeTransparency = 0.4
	distLabel.Size = UDim2.fromOffset(120, 16)
	distLabel.AnchorPoint = Vector2.new(0.5, 1)
	distLabel.Visible = false
	distLabel.Text = ""
	distLabel.Parent = gui
end

-- ── Ball ESP ─────────────────────────────────────────────────────────
local function clearBallEsp()
	if highlight then pcall(function() highlight:Destroy() end) highlight = nil end
	if tracer then tracer.Visible = false end
	if distLabel then distLabel.Visible = false end
end

function V.StepBallEsp()
	local s = Cfg.s.visuals
	if not s.ballEsp then
		clearBallEsp()
		return
	end
	ensureGui()
	local ball = R.Ball()
	if not ball then
		clearBallEsp()
		return
	end

	if s.ballEspBox then
		if not highlight or highlight.Adornee ~= ball or not highlight.Parent then
			if highlight then pcall(function() highlight:Destroy() end) end
			highlight = Instance.new("Highlight")
			highlight.FillColor = Theme.col.gold
			highlight.FillTransparency = 0.6
			highlight.OutlineColor = Theme.col.goldHi
			highlight.OutlineTransparency = 0
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Adornee = ball
			highlight.Parent = gui
		end
	elseif highlight then
		pcall(function() highlight:Destroy() end)
		highlight = nil
	end

	local cam = Svc.Camera()
	if not cam then return end
	local screen, visible = AM.WorldToScreen(cam, ball.Position)

	if s.ballEspTracer and visible then
		local vp = cam.ViewportSize
		local origin = Vector2.new(vp.X * 0.5, vp.Y)
		local delta = screen - origin
		tracer.Visible = true
		tracer.Position = UDim2.fromOffset(origin.X, origin.Y)
		tracer.Size = UDim2.fromOffset(delta.Magnitude, 2)
		tracer.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	else
		tracer.Visible = false
	end

	if s.ballEspDist and visible then
		local hrp = Svc.HRP()
		local d = hrp and (ball.Position - hrp.Position).Magnitude or 0
		distLabel.Visible = true
		distLabel.Position = UDim2.fromOffset(screen.X, screen.Y - 14)
		distLabel.Text = string.format("BALL  %dm", math.floor(d))
	else
		distLabel.Visible = false
	end
end

-- ── Ball trail ───────────────────────────────────────────────────────
local function clearBallTrail()
	for _, inst in ipairs({ballTrail, ballA0, ballA1}) do
		if inst then pcall(function() inst:Destroy() end) end
	end
	ballTrail, ballA0, ballA1 = nil, nil, nil
end

function V.StepBallTrail()
	local s = Cfg.s.visuals
	local ball = R.Ball()
	if not s.ballTrail or not ball then
		if ballTrail then clearBallTrail() end
		return
	end
	if ballTrail and ballTrail.Parent == ball then return end
	clearBallTrail()

	ballA0 = Instance.new("Attachment")
	ballA0.Position = Vector3.new(0, R.BallRadius(), 0)
	ballA0.Parent = ball
	ballA1 = Instance.new("Attachment")
	ballA1.Position = Vector3.new(0, -R.BallRadius(), 0)
	ballA1.Parent = ball

	ballTrail = Instance.new("Trail")
	ballTrail.Attachment0 = ballA0
	ballTrail.Attachment1 = ballA1
	ballTrail.Lifetime = 0.55
	ballTrail.MinLength = 0.1
	ballTrail.LightEmission = 1
	ballTrail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	ballTrail.Color = ColorSequence.new(Theme.col.goldHi, Theme.col.crimson)
	ballTrail.Parent = ball
end

-- ── RGB character ────────────────────────────────────────────────────
local function restoreRgb()
	for part, data in pairs(rgbOriginal) do
		if part and part.Parent then
			pcall(function()
				part.Color = data.color
				part.Material = data.material
			end)
		end
	end
	rgbOriginal = {}
end

function V.StepRgb(dt)
	local s = Cfg.s.visuals
	if not s.rgbChar then
		if next(rgbOriginal) ~= nil then restoreRgb() end
		return
	end
	hue = (hue + dt * 0.12 * math.max(s.rgbSpeed, 0.05)) % 1
	local colour = Color3.fromHSV(hue, 1, 1)
	for _, part in ipairs(Svc.Parts()) do
		if rgbOriginal[part] == nil then
			rgbOriginal[part] = {color = part.Color, material = part.Material}
		end
		pcall(function()
			part.Color = colour
			if s.rgbNeon then part.Material = Enum.Material.Neon end
		end)
	end
end

-- ── Boot trail ───────────────────────────────────────────────────────
local function clearBootTrails()
	for _, set in pairs(bootTrails) do
		for _, inst in ipairs(set) do
			if inst then pcall(function() inst:Destroy() end) end
		end
	end
	bootTrails = {}
end

function V.StepBootTrail(dt)
	local s = Cfg.s.visuals
	if not s.bootTrail then
		if next(bootTrails) ~= nil then clearBootTrails() end
		return
	end
	local char = Svc.Char()
	if not char then return end

	local footNames = {"RightFoot", "LeftFoot", "Right Leg", "Left Leg"}
	for _, name in ipairs(footNames) do
		local part = char:FindFirstChild(name)
		if part and part:IsA("BasePart") and not bootTrails[part] then
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, part.Size.Y * 0.4, 0)
			a0.Parent = part
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -part.Size.Y * 0.4, 0)
			a1.Parent = part
			local tr = Instance.new("Trail")
			tr.Attachment0 = a0
			tr.Attachment1 = a1
			tr.Lifetime = 0.5
			tr.LightEmission = 1
			tr.MinLength = 0.05
			tr.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(1, 1),
			})
			tr.Parent = part
			bootTrails[part] = {a0, a1, tr}
		end
	end

	local c1 = Color3.fromHSV(hue, 1, 1)
	local c2 = Color3.fromHSV((hue + 0.25) % 1, 1, 1)
	for part, set in pairs(bootTrails) do
		if part and part.Parent and set[3] then
			pcall(function() set[3].Color = ColorSequence.new(c1, c2) end)
		else
			bootTrails[part] = nil
		end
	end
end

-- ── Time of day ──────────────────────────────────────────────────────
local savedClock = nil
function V.StepClock()
	local s = Cfg.s.visuals
	if s.timeOfDay then
		if savedClock == nil then savedClock = Svc.Lighting.ClockTime end
		if math.abs(Svc.Lighting.ClockTime - s.clockTime) > 0.01 then
			pcall(function() Svc.Lighting.ClockTime = s.clockTime end)
		end
	elseif savedClock ~= nil then
		pcall(function() Svc.Lighting.ClockTime = savedClock end)
		savedClock = nil
	end
end

-- ── Spoof marker ─────────────────────────────────────────────────────
-- Two parts. The overlay always works. The hook into the engine stats
-- readout only exists where the executor has hookfunction.
local function ensureSpoofPanel()
	if spoofPanel and spoofPanel.Parent then return end
	ensureGui()
	spoofPanel = Instance.new("Frame")
	spoofPanel.BackgroundColor3 = Theme.col.bg0
	spoofPanel.BackgroundTransparency = 0.25
	spoofPanel.BorderSizePixel = 0
	spoofPanel.Position = UDim2.fromOffset(10, 10)
	spoofPanel.Size = UDim2.fromOffset(150, 58)
	spoofPanel.Parent = gui
	Theme.Corner(spoofPanel, 5)
	Theme.Stroke(spoofPanel, Theme.col.goldLo, 1)

	spoofLines = {}
	for i = 1, 3 do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Theme.font.mono
		l.TextSize = 13
		l.TextColor3 = Theme.col.goldHi
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Position = UDim2.fromOffset(8, 4 + (i - 1) * 17)
		l.Size = UDim2.new(1, -16, 0, 16)
		l.Text = ""
		l.Parent = spoofPanel
		spoofLines[i] = l
	end
end

local function installStatsHook()
	if statsHookInstalled or not Env.hookfunction then return end
	local ok = pcall(function()
		local item = Svc.Stats.Network.ServerStatsItem["Data Ping"]
		local original
		original = Env.hookfunction(item.GetValue, function(self)
			if Cfg.s.visuals.spoofMarker and self == item then
				return Cfg.s.visuals.spoofPing
			end
			return original(self)
		end)
	end)
	statsHookInstalled = ok
end

function V.StepSpoof()
	local s = Cfg.s.visuals
	if not s.spoofMarker then
		if spoofPanel then spoofPanel.Visible = false end
		return
	end
	ensureSpoofPanel()
	installStatsHook()
	spoofPanel.Visible = true
	spoofLines[1].Text = string.format("PING  %d ms", s.spoofPing)
	spoofLines[2].Text = string.format("CPU   %d %%", s.spoofCpu)
	spoofLines[3].Text = string.format("SENT  %d kb/s", s.spoofSent)
end

-- ── driver ───────────────────────────────────────────────────────────
function V.Step(dt)
	V.StepBallEsp()
	V.StepBallTrail()
	V.StepRgb(dt)
	V.StepBootTrail(dt)
	V.StepClock()
	V.StepSpoof()
end

function V.Destroy()
	clearBallEsp()
	clearBallTrail()
	clearBootTrails()
	restoreRgb()
	if savedClock ~= nil then
		pcall(function() Svc.Lighting.ClockTime = savedClock end)
		savedClock = nil
	end
	maid:Clean()
	gui, tracer, distLabel, spoofPanel, spoofLines = nil, nil, nil, nil, nil
end

return V
end

-- ===== charmod  (src/22_charmod.lua) =====
__src["charmod"] = function(_R)
-- @module charmod
-- Local rig and appearance work. The server keeps whatever character it
-- gave you; everything here changes what your client draws.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local AM     = _R("amath")
local Env    = _R("env")
local Notify = _R("notify")

local CM = {}

local rig = nil
local rigJoints = {}
local rigWeld = nil
local hiddenParts = {}
local swingClock = 0
local addedAccessories = {}
local maid = Util.Maid.new()

-- R6 part sizes are engine constants, not anything read from this game.
local R6_SIZES = {
	HumanoidRootPart = Vector3.new(2, 2, 1),
	Torso            = Vector3.new(2, 2, 1),
	Head             = Vector3.new(2, 1, 1),
	["Left Arm"]     = Vector3.new(1, 2, 1),
	["Right Arm"]    = Vector3.new(1, 2, 1),
	["Left Leg"]     = Vector3.new(1, 2, 1),
	["Right Leg"]    = Vector3.new(1, 2, 1),
}

local function skinColour(char, want)
	-- pull the nearest matching colour off the real rig so the clone is you
	local map = {
		Head = {"Head"},
		Torso = {"UpperTorso", "Torso", "LowerTorso"},
		["Left Arm"] = {"LeftUpperArm", "Left Arm", "LeftLowerArm"},
		["Right Arm"] = {"RightUpperArm", "Right Arm", "RightLowerArm"},
		["Left Leg"] = {"LeftUpperLeg", "Left Leg", "LeftLowerLeg"},
		["Right Leg"] = {"RightUpperLeg", "Right Leg", "RightLowerLeg"},
	}
	local names = map[want]
	if names and char then
		for _, n in ipairs(names) do
			local p = char:FindFirstChild(n)
			if p and p:IsA("BasePart") then return p.Color end
		end
	end
	return Color3.fromRGB(205, 165, 125)
end

local function makePart(name, size, colour, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.Parent = parent
	return p
end

local function joint(name, part0, part1, c0, c1)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.Parent = part0
	return m
end

function CM.BuildR6()
	CM.DestroyR6()
	local char = Svc.Char()
	local hrp = Svc.HRP()
	if not char or not hrp then return false, "no character" end

	rig = Instance.new("Model")
	rig.Name = "LC_R6"
	rig.Parent = Svc.Workspace.CurrentCamera or Svc.Workspace

	local root = makePart("HumanoidRootPart", R6_SIZES.HumanoidRootPart, Color3.new(1, 1, 1), rig)
	root.Transparency = 1
	rig.PrimaryPart = root

	local torso = makePart("Torso", R6_SIZES.Torso, skinColour(char, "Torso"), rig)
	local head  = makePart("Head", R6_SIZES.Head, skinColour(char, "Head"), rig)

	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = head

	local la = makePart("Left Arm",  R6_SIZES["Left Arm"],  skinColour(char, "Left Arm"), rig)
	local ra = makePart("Right Arm", R6_SIZES["Right Arm"], skinColour(char, "Right Arm"), rig)
	local ll = makePart("Left Leg",  R6_SIZES["Left Leg"],  skinColour(char, "Left Leg"), rig)
	local rl = makePart("Right Leg", R6_SIZES["Right Leg"], skinColour(char, "Right Leg"), rig)

	joint("RootJoint", root, torso, CFrame.new(0, 0, 0) * CFrame.Angles(-math.pi / 2, 0, math.pi), CFrame.new(0, 0, 0) * CFrame.Angles(-math.pi / 2, 0, math.pi))
	rigJoints.neck = joint("Neck", torso, head, CFrame.new(0, 1, 0) * CFrame.Angles(-math.pi / 2, 0, math.pi), CFrame.new(0, -0.5, 0) * CFrame.Angles(-math.pi / 2, 0, math.pi))
	rigJoints.rs = joint("Right Shoulder", torso, ra, CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0), CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0))
	rigJoints.ls = joint("Left Shoulder",  torso, la, CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0), CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0))
	rigJoints.rh = joint("Right Hip", torso, rl, CFrame.new(1, -1, 0) * CFrame.Angles(0, math.pi / 2, 0), CFrame.new(0.5, 1, 0) * CFrame.Angles(0, math.pi / 2, 0))
	rigJoints.lh = joint("Left Hip",  torso, ll, CFrame.new(-1, -1, 0) * CFrame.Angles(0, -math.pi / 2, 0), CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, -math.pi / 2, 0))

	rigWeld = Instance.new("Weld")
	rigWeld.Part0 = hrp
	rigWeld.Part1 = root
	rigWeld.C0 = CFrame.new(0, 0, 0)
	rigWeld.Parent = hrp

	return true
end

-- The real rig keeps moving underneath; we just stop drawing it.
local function hideReal(state)
	local char = Svc.Char()
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			if state then
				hiddenParts[d] = true
				pcall(function() d.LocalTransparencyModifier = 1 end)
			else
				pcall(function() d.LocalTransparencyModifier = 0 end)
			end
		elseif d:IsA("Decal") then
			pcall(function() d.Transparency = state and 1 or 0 end)
		end
	end
	if not state then hiddenParts = {} end
end

-- Procedural walk. No animation asset ids are used anywhere, because none
-- for this build were ever handed over and inventing one is not on.
function CM.StepR6(dt)
	if not Cfg.s.character.r6 then
		if rig then CM.DestroyR6() end
		return
	end

	local char = Svc.Char()
	local hrp = Svc.HRP()
	local hum = Svc.Hum()
	if not char or not hrp or not hum then return end

	if not rig or not rig.Parent or not rigWeld or rigWeld.Part0 ~= hrp then
		local ok = CM.BuildR6()
		if not ok then return end
	end

	hideReal(true)

	local planar = AM.Flat(hrp.AssemblyLinearVelocity).Magnitude
	local moving = planar > 1.5
	local airborne = hum:GetState() == Enum.HumanoidStateType.Freefall
		or hum:GetState() == Enum.HumanoidStateType.Jumping

	swingClock = swingClock + dt * (moving and math.max(planar * 0.5, 4) or 2)

	local amp = moving and math.min(planar / 16, 1) * 0.9 or 0.0
	local swing = math.sin(swingClock) * amp
	local counter = -swing

	if airborne then
		swing = 1.4
		counter = 1.4
	end

	local function setJoint(j, base, angle)
		if not j then return end
		j.Transform = CFrame.Angles(angle, 0, 0)
	end

	setJoint(rigJoints.rs, nil, swing)
	setJoint(rigJoints.ls, nil, counter)
	setJoint(rigJoints.rh, nil, counter * 0.9)
	setJoint(rigJoints.lh, nil, swing * 0.9)
	if rigJoints.neck then
		rigJoints.neck.Transform = CFrame.Angles(0, 0, 0)
	end
end

function CM.DestroyR6()
	if rigWeld then pcall(function() rigWeld:Destroy() end) rigWeld = nil end
	if rig then pcall(function() rig:Destroy() end) rig = nil end
	rigJoints = {}
	hideReal(false)
end

-- ── Appearance ───────────────────────────────────────────────────────
function CM.StripAccessories()
	local char = Svc.Char()
	if not char then return 0 end
	local removed = 0
	for _, d in ipairs(char:GetChildren()) do
		if d:IsA("Accessory") or d:IsA("Hat") then
			pcall(function() d:Destroy() end)
			removed = removed + 1
		end
	end
	Notify.Info("accessories", removed .. " removed locally")
	return removed
end

function CM.ApplyOwnAvatar()
	local char = Svc.Char()
	local lp = Svc.LP
	if not char or not lp then return false end
	local ok, model = pcall(function()
		return Svc.Players:GetCharacterAppearanceAsync(lp.UserId)
	end)
	if not ok or not model then
		Notify.Warn("own avatar", "the client could not fetch your appearance here")
		return false
	end
	local count = 0
	for _, item in ipairs(model:GetChildren()) do
		if item:IsA("Accessory") then
			local clone = item:Clone()
			clone.Parent = char
			addedAccessories[#addedAccessories + 1] = clone
			count = count + 1
		elseif item:IsA("BodyColors") then
			local existing = char:FindFirstChildOfClass("BodyColors")
			if existing then pcall(function() existing:Destroy() end) end
			local clone = item:Clone()
			clone.Parent = char
		elseif item:IsA("ShirtGraphic") or item:IsA("Shirt") or item:IsA("Pants") then
			local clone = item:Clone()
			clone.Parent = char
			addedAccessories[#addedAccessories + 1] = clone
		end
	end
	pcall(function() model:Destroy() end)
	Notify.Good("own avatar", count .. " items applied locally")
	return true
end

-- Load one asset id and attach whatever accessory it contains.
function CM.WearAsset(assetId, label)
	if assetId == nil or assetId <= 0 then return false end
	local char = Svc.Char()
	if not char then return false end
	if not Env.canAssets then
		Notify.Once("asset_gate", label or "asset",
			"this executor exposes no getobjects, so an asset id cannot be loaded client side.", "warn")
		return false
	end

	local ok, objects = pcall(function()
		return Env.getobjects("rbxassetid://" .. tostring(math.floor(assetId)))
	end)
	if not ok or type(objects) ~= "table" or #objects == 0 then
		Notify.Warn(label or "asset", "asset " .. tostring(assetId) .. " did not load")
		return false
	end

	local worn = 0
	for _, obj in ipairs(objects) do
		if obj:IsA("Accessory") or obj:IsA("Hat") then
			obj.Parent = char
			addedAccessories[#addedAccessories + 1] = obj
			worn = worn + 1
		else
			for _, sub in ipairs(obj:GetDescendants()) do
				if sub:IsA("Accessory") then
					sub.Parent = char
					addedAccessories[#addedAccessories + 1] = sub
					worn = worn + 1
				end
			end
		end
	end

	if worn == 0 then
		Notify.Warn(label or "asset", "no accessory inside asset " .. tostring(assetId))
		return false
	end
	Notify.Good(label or "asset", worn .. " attached locally")
	return true
end

function CM.ClearAdded()
	for _, inst in ipairs(addedAccessories) do
		if inst and inst.Parent then pcall(function() inst:Destroy() end) end
	end
	addedAccessories = {}
end

function CM.Step(dt)
	CM.StepR6(dt)
	if Cfg.s.character.stripAccs then
		local char = Svc.Char()
		if char then
			for _, d in ipairs(char:GetChildren()) do
				if d:IsA("Accessory") or d:IsA("Hat") then
					pcall(function() d:Destroy() end)
				end
			end
		end
	end
end

function CM.Destroy()
	CM.DestroyR6()
	CM.ClearAdded()
	maid:Clean()
end

return CM
end

-- ===== settings  (src/23_settings.lua) =====
__src["settings"] = function(_R)
-- @module settings
-- Session plumbing: idle defeat, server selection, staff watch, rejoin,
-- quest firing, respawn, panic.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local Env    = _R("env")
local R      = _R("resolve")
local Notify = _R("notify")

local ST = {}

local maid = Util.Maid.new()
local afkConn = nil
local lastQuest = 0
local lastStaffCheck = 0
ST.PanicHook = nil          -- set by main; called on Panic Eject
ST.hopping = false
ST.lastServerList = {}

-- ── Anti-AFK ─────────────────────────────────────────────────────────
function ST.ApplyAntiAfk()
	if afkConn then
		afkConn:Disconnect()
		afkConn = nil
	end
	if not Cfg.s.settings.antiAfk then return end
	local lp = Svc.LP
	if not lp then return end
	local ok, vu = pcall(function() return game:GetService("VirtualUser") end)
	if not ok or not vu then
		Notify.Once("afk_novu", "anti-afk", "VirtualUser is not reachable from this client.", "warn")
		return
	end
	afkConn = lp.Idled:Connect(function()
		pcall(function()
			vu:CaptureController()
			vu:ClickButton2(Vector2.new(0, 0))
		end)
	end)
	maid:Give(afkConn)
end

-- ── Server list ──────────────────────────────────────────────────────
local function httpGetJson(url)
	local body = nil
	if Env.httpGet then
		body = Env.httpGet(url)
	elseif Env.request then
		local ok, res = pcall(function() return Env.request({Url = url, Method = "GET"}) end)
		if ok and type(res) == "table" then body = res.Body end
	end
	if type(body) ~= "string" then return nil end
	local ok, decoded = pcall(function() return Svc.HttpService:JSONDecode(body) end)
	if not ok then return nil end
	return decoded
end

function ST.PlaceId()
	if Cfg.target.placeId ~= 0 then return Cfg.target.placeId end
	return game.PlaceId
end

-- Returns an array of {id, playing, maxPlayers, ping, fps}, best first.
function ST.FetchServers(pages)
	if not Env.canHttp then
		Notify.Once("hop_nohttp", "servers", "this executor exposes no http client, so the server list cannot be read.", "warn")
		return {}
	end
	local placeId = ST.PlaceId()
	local collected = {}
	local cursor = ""
	for _ = 1, math.max(pages or 2, 1) do
		local url = "https://games.roblox.com/v1/games/" .. tostring(placeId)
			.. "/servers/Public?sortOrder=Asc&limit=100"
		if cursor ~= "" then url = url .. "&cursor=" .. cursor end
		local data = httpGetJson(url)
		if not data or type(data.data) ~= "table" then break end
		for _, srv in ipairs(data.data) do
			if type(srv.id) == "string" then
				collected[#collected + 1] = {
					id = srv.id,
					playing = tonumber(srv.playing) or 0,
					maxPlayers = tonumber(srv.maxPlayers) or 0,
					ping = tonumber(srv.ping) or 9999,
					fps = tonumber(srv.fps) or 0,
				}
			end
		end
		cursor = type(data.nextPageCursor) == "string" and data.nextPageCursor or ""
		if cursor == "" then break end
	end

	local here = game.JobId
	local filtered = {}
	for _, srv in ipairs(collected) do
		local free = srv.maxPlayers - srv.playing
		if srv.id ~= here and free >= Cfg.s.settings.hopMinSlots then
			filtered[#filtered + 1] = srv
		end
	end
	table.sort(filtered, function(a, b)
		if a.ping == b.ping then return a.fps > b.fps end
		return a.ping < b.ping
	end)
	ST.lastServerList = filtered
	return filtered
end

function ST.HopLowPing()
	if ST.hopping then return false end
	ST.hopping = true
	task.spawn(function()
		local list = ST.FetchServers(2)
		if #list == 0 then
			Notify.Warn("hop", "no other server came back from the list")
			ST.hopping = false
			return
		end
		local pick = nil
		for _, srv in ipairs(list) do
			if srv.ping <= Cfg.s.settings.hopMaxPing then pick = srv break end
		end
		if not pick then pick = list[1] end
		Notify.Info("hop", string.format("%d ms, %d/%d", pick.ping, pick.playing, pick.maxPlayers))
		ST.QueueReexec()
		local ok = pcall(function()
			Svc.TeleportService:TeleportToPlaceInstance(ST.PlaceId(), pick.id, Svc.LP)
		end)
		if not ok then
			Notify.Bad("hop", "teleport refused")
			ST.hopping = false
		end
	end)
	return true
end

function ST.AutoBestServer()
	if not Cfg.s.settings.autoBestServer then return end
	ST.HopLowPing()
end

-- ── Rejoin ───────────────────────────────────────────────────────────
-- Re-execute after a teleport. Uses the loader url when the one-liner set
-- one, otherwise the raw source if the loader stashed it.
function ST.QueueReexec()
	if not Env.queueteleport then return false end
	local g = Util.Genv()
	local src = nil
	if type(g.LC_URL) == "string" and g.LC_URL ~= "" then
		src = 'loadstring(game:HttpGet("' .. g.LC_URL .. '"))()'
	elseif type(g.LC_SOURCE) == "string" and g.LC_SOURCE ~= "" then
		src = g.LC_SOURCE
	end
	if not src then return false end
	local ok = pcall(function() Env.queueteleport(src) end)
	return ok
end

function ST.Rejoin()
	Notify.Info("rejoin", "teleporting back into this place")
	ST.QueueReexec()
	local ok = pcall(function()
		Svc.TeleportService:Teleport(ST.PlaceId(), Svc.LP)
	end)
	if not ok then Notify.Bad("rejoin", "teleport refused") end
	return ok
end

-- ── Panic Staff ──────────────────────────────────────────────────────
local function isStaff(plr)
	local groupId = Cfg.target.staffGroupId
	if groupId ~= 0 then
		local ok, rank = pcall(function() return plr:GetRankInGroup(groupId) end)
		if ok and type(rank) == "number" and rank >= Cfg.target.staffMinRank then
			return true
		end
	end
	for _, name in ipairs(Cfg.List(Cfg.target.staffNames)) do
		if string.lower(name) == string.lower(plr.Name) then return true end
		if string.lower(name) == string.lower(plr.DisplayName) then return true end
	end
	return false
end

function ST.StepStaff(now)
	if not Cfg.s.settings.panicStaff then return end
	if now - lastStaffCheck < 2 then return end
	lastStaffCheck = now
	if Cfg.target.staffGroupId == 0 and Cfg.target.staffNames == "" then
		Notify.Once("staff_unset", "panic staff",
			"no staff group id and no staff name list set, so there is nothing to match. CONFIG tab.", "warn")
		return
	end
	for _, p in ipairs(Svc.Others()) do
		if isStaff(p) then
			Notify.Bad("panic staff", p.Name .. " matched. leaving.")
			if ST.PanicHook then pcall(ST.PanicHook) end
			task.delay(0.15, function() ST.HopLowPing() end)
			return
		end
	end
end

-- ── Quests ───────────────────────────────────────────────────────────
function ST.StepQuests(now)
	if not Cfg.s.settings.autoQuest then return end
	if now - lastQuest < 3 then return end
	lastQuest = now
	if Cfg.target.questRemote == "" then
		Notify.Once("quest_unset", "auto quest",
			"quest remote is unset. CONFIG tab: arm the remote spy, hand in one quest, copy the name it logs.", "warn")
		return
	end
	local rem = R.FindRemote(Cfg.target.questRemote)
	if not rem then
		Notify.Once("quest_missing", "auto quest",
			"remote '" .. Cfg.target.questRemote .. "' is not in this place.", "warn")
		return
	end
	pcall(function()
		if rem:IsA("RemoteFunction") then
			rem:InvokeServer()
		else
			rem:FireServer()
		end
	end)
end

-- ── Respawn / panic ──────────────────────────────────────────────────
function ST.ForceRespawn()
	local hum = Svc.Hum()
	if hum then
		pcall(function() hum.Health = 0 end)
		return true
	end
	local char = Svc.Char()
	if char then
		pcall(function() char:BreakJoints() end)
		return true
	end
	return false
end

function ST.PanicEject()
	if ST.PanicHook then
		pcall(ST.PanicHook)
		return true
	end
	return false
end

function ST.Step(dt, now)
	ST.StepStaff(now)
	ST.StepQuests(now)
end

function ST.Destroy()
	maid:Clean()
	if afkConn then afkConn:Disconnect() afkConn = nil end
end

return ST
end

-- ===== menu  (src/24_menu.lua) =====
__src["menu"] = function(_R)
-- @module menu
-- Every tab, every control, wired straight at the settings table.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local Theme  = _R("theme")
local UI     = _R("ui")
local Notify = _R("notify")
local Env    = _R("env")
local R      = _R("resolve")
local BE     = _R("backend")
local Calib  = _R("calib")
local Learn  = _R("learn")
local Reach  = _R("reach")
local Skills = _R("skills")
local Aim    = _R("aimbot")
local Pass   = _R("aimpass")
local GK     = _R("keeper")
local SP     = _R("special")
local Vis    = _R("visuals")
local CM     = _R("charmod")
local ST     = _R("settings")
local TB     = _R("touchui")

local M = {}

M.window = nil
local readouts = {}
local spyLabels = {}

local function get(tbl, key)
	return function() return tbl[key] end
end

local function set(tbl, key, after)
	return function(v)
		tbl[key] = v
		if after then after(v) end
	end
end

local function num(tbl, key, after)
	return function(v)
		tbl[key] = tonumber(v) or 0
		if after then after(tbl[key]) end
	end
end

local function str(tbl, key, after)
	return function(v)
		tbl[key] = tostring(v)
		if after then after(tbl[key]) end
	end
end

-- ── REACH ────────────────────────────────────────────────────────────
local function tabReach(w)
	local t = w:Tab("REACH")
	local s = Cfg.s.reach

	local a = t:Section("Reach")
	a:Toggle{text = "Reach", get = get(s, "enabled"), set = set(s, "enabled", function() TB.Repaint() end)}
	a:Toggle{text = "Pro Reach (natural)", get = get(s, "proNatural"), set = set(s, "proNatural")}
	a:Toggle{text = "Control Reach (easier)", get = get(s, "controlEasier"), set = set(s, "controlEasier")}
	a:Slider{text = "Radius", min = 4, max = 60, step = 1, suffix = " st", get = get(s, "radius"), set = set(s, "radius")}
	a:Slider{text = "Trigger range", min = 3, max = 40, step = 1, suffix = " st", get = get(s, "triggerRange"), set = set(s, "triggerRange")}
	a:Slider{text = "Pulse rate", min = 4, max = 60, step = 1, suffix = "/s", get = get(s, "pulseRate"), set = set(s, "pulseRate")}
	a:Dropdown{text = "Reach priority", options = {"Nearest", "Ball to goal", "Teammate safe"}, byIndex = true,
		get = get(s, "priority"), set = set(s, "priority")}

	local b = t:Section("Ball Hold")
	b:Toggle{text = "Ball Hold", get = get(s, "ballHold"), set = set(s, "ballHold")}
	b:Slider{text = "Hold distance", min = 2, max = 14, step = 0.5, get = get(s, "holdDistance"), set = set(s, "holdDistance")}
	b:Slider{text = "Hold height", min = 0, max = 10, step = 0.5, get = get(s, "holdHeight"), set = set(s, "holdHeight")}

	local c = t:Section("Adapt High MS")
	c:Toggle{text = "Adapt High MS", get = get(s, "adaptHighMs"), set = set(s, "adaptHighMs")}
	c:Slider{text = "Studs per ms", min = 0, max = 0.3, step = 0.005, get = get(s, "adaptPerMs"), set = set(s, "adaptPerMs")}
	c:Slider{text = "Adapt cap", min = 0, max = 40, step = 1, suffix = " st", get = get(s, "adaptCap"), set = set(s, "adaptCap")}
	readouts.ping = c:Readout{text = "Ping / effective radius"}
end

-- ── SKILLS ───────────────────────────────────────────────────────────
local function tabSkills(w)
	local t = w:Tab("SKILLS")
	local s = Cfg.s.skills

	local a = t:Section("Sneaky")
	a:Toggle{text = "Sneaky", get = get(s, "sneaky"), set = set(s, "sneaky", function() TB.Repaint() end)}
	a:Toggle{text = "Air only", get = get(s, "sneakyAirOnly"), set = set(s, "sneakyAirOnly")}
	a:Toggle{text = "Auto adapt power", get = get(s, "sneakyAuto"), set = set(s, "sneakyAuto")}
	a:Slider{text = "Sneaky power", min = 10, max = 140, step = 1, get = get(s, "sneakyPower"), set = set(s, "sneakyPower")}
	a:Slider{text = "Sneaky lift", min = 0, max = 1, step = 0.05, get = get(s, "sneakyLift"), set = set(s, "sneakyLift")}
	a:Button{text = "Flick now", callback = function() Skills.Sneaky(true) end}

	local b = t:Section("Pokers")
	b:Toggle{text = "Pokers", get = get(s, "pokers"), set = set(s, "pokers", function() TB.Repaint() end)}
	b:Slider{text = "Poke speed", min = 2, max = 30, step = 1, suffix = "/s", get = get(s, "pokerSpeed"), set = set(s, "pokerSpeed")}
	b:Slider{text = "Poke power", min = 2, max = 60, step = 1, get = get(s, "pokerPower"), set = set(s, "pokerPower")}

	local c = t:Section("Auto Juggle")
	c:Toggle{text = "Auto Juggle", get = get(s, "juggle"), set = set(s, "juggle", function() TB.Repaint() end)}
	c:Slider{text = "Juggle reach", min = 3, max = 30, step = 1, suffix = " st", get = get(s, "juggleReach"), set = set(s, "juggleReach")}
	c:Slider{text = "Juggle height", min = 4, max = 40, step = 1, suffix = " st", get = get(s, "juggleHeight"), set = set(s, "juggleHeight")}
	c:Slider{text = "Sticky", min = 0, max = 2, step = 0.05, get = get(s, "juggleSticky"), set = set(s, "juggleSticky")}

	local d = t:Section("Ground Shots")
	d:Toggle{text = "Ground Shots", get = get(s, "groundShots"), set = set(s, "groundShots")}
	d:Slider{text = "Ground lift", min = 0, max = 0.5, step = 0.01, get = get(s, "groundLift"), set = set(s, "groundLift")}
end

-- ── AIMBOT ───────────────────────────────────────────────────────────
local function tabAim(w)
	local t = w:Tab("AIMBOT")
	local s = Cfg.s.aim

	local a = t:Section("Aim")
	a:Toggle{text = "Aimbot", get = get(s, "aimbot"), set = set(s, "aimbot", function() TB.Repaint() end)}
	a:Toggle{text = "Aimlock (camera to ball)", get = get(s, "aimlock"), set = set(s, "aimlock")}
	a:Slider{text = "Aimlock speed", min = 0.05, max = 1, step = 0.05, get = get(s, "aimlockSpeed"), set = set(s, "aimlockSpeed")}
	a:Slider{text = "FOV (0 = off)", min = 0, max = 180, step = 5, suffix = " deg", get = get(s, "fovDeg"), set = set(s, "fovDeg")}
	a:Slider{text = "Fire rate", min = 0.5, max = 12, step = 0.5, suffix = "/s", get = get(s, "fireRate"), set = set(s, "fireRate")}
	a:Button{text = "Shoot now", callback = function() Aim.Shoot(nil) end}
	readouts.aim = a:Readout{text = "Last shot"}

	local b = t:Section("Power")
	b:Slider{text = "Power", min = 5, max = 200, step = 1, get = get(s, "power"), set = set(s, "power")}
	b:Slider{text = "Speed", min = 10, max = 400, step = 5, suffix = " st/s", get = get(s, "speed"), set = set(s, "speed")}
	b:Slider{text = "Gravity scale", min = 0.1, max = 2, step = 0.05, get = get(s, "gravityScale"), set = set(s, "gravityScale")}
	b:Slider{text = "Miss chance", min = 0, max = 100, step = 1, suffix = " %", get = get(s, "missChance"), set = set(s, "missChance")}

	local c = t:Section("Curve")
	c:Toggle{text = "Curve Aimbot", get = get(s, "curve"), set = set(s, "curve")}
	c:Toggle{text = "Auto adapt curve", get = get(s, "curveAuto"), set = set(s, "curveAuto")}
	c:Toggle{text = "Random curve", get = get(s, "curveRandom"), set = set(s, "curveRandom")}
	c:Slider{text = "Curve amount", min = 0, max = 1, step = 0.05, get = get(s, "curveAmount"), set = set(s, "curveAmount")}

	local d = t:Section("Target")
	d:Toggle{text = "Top Corner Mode", get = get(s, "topCorner"), set = set(s, "topCorner")}
	d:Slider{text = "Corner inset", min = 0, max = 8, step = 0.2, suffix = " st", get = get(s, "cornerInset"), set = set(s, "cornerInset")}
	d:Toggle{text = "Auto Detect Goal", get = get(s, "autoDetectGoal"), set = set(s, "autoDetectGoal")}
	readouts.goal = d:Readout{text = "Attacking goal"}

	local e = t:Section("Nero and Header")
	e:Toggle{text = "Auto Nero", get = get(s, "autoNero"), set = set(s, "autoNero")}
	e:Button{text = "Manual Nero", callback = function() Aim.Nero() end}
	e:Slider{text = "Nero power", min = 20, max = 220, step = 1, get = get(s, "neroPower"), set = set(s, "neroPower")}
	e:Slider{text = "Nero lift", min = 0, max = 1, step = 0.02, get = get(s, "neroLift"), set = set(s, "neroLift")}
	e:Slider{text = "Nero spin", min = 0, max = 2, step = 0.05, get = get(s, "neroSpin"), set = set(s, "neroSpin")}
	e:Toggle{text = "Auto Header", get = get(s, "autoHeader"), set = set(s, "autoHeader")}
	e:Slider{text = "Header range", min = 2, max = 25, step = 1, suffix = " st", get = get(s, "headerRange"), set = set(s, "headerRange")}
	e:Slider{text = "Header power", min = 10, max = 150, step = 1, get = get(s, "headerPower"), set = set(s, "headerPower")}
end

-- ── AIMPASS ──────────────────────────────────────────────────────────
local function tabPass(w)
	local t = w:Tab("AIMPASS")
	local s = Cfg.s.pass

	local a = t:Section("AimPass")
	a:Toggle{text = "AimPass", get = get(s, "enabled"), set = set(s, "enabled", function() TB.Repaint() end)}
	a:Toggle{text = "Teammates only", get = get(s, "teammatesOnly"), set = set(s, "teammatesOnly")}
	a:Toggle{text = "Smart receiver scoring", get = get(s, "smartScore"), set = set(s, "smartScore")}
	a:Slider{text = "Pass range", min = 20, max = 400, step = 5, suffix = " st", get = get(s, "range"), set = set(s, "range")}
	a:Button{text = "Pass now", callback = function() Pass.Fire() end}
	readouts.pass = a:Readout{text = "Last pass"}

	local b = t:Section("Through Balls")
	b:Toggle{text = "Through Balls", get = get(s, "throughBalls"), set = set(s, "throughBalls")}
	b:Slider{text = "Lead factor", min = 0, max = 3, step = 0.05, get = get(s, "throughLead"), set = set(s, "throughLead")}

	local c = t:Section("Power and Shape")
	c:Slider{text = "Min pass power", min = 5, max = 150, step = 1, get = get(s, "minPower"), set = set(s, "minPower")}
	c:Slider{text = "Max pass power", min = 10, max = 250, step = 1, get = get(s, "maxPower"), set = set(s, "maxPower")}
	c:Slider{text = "Max lob height", min = 2, max = 80, step = 1, suffix = " st", get = get(s, "maxLobHeight"), set = set(s, "maxLobHeight")}
	c:Toggle{text = "Curve AimPass", get = get(s, "curve"), set = set(s, "curve")}
	c:Slider{text = "Pass curve amount", min = 0, max = 1, step = 0.05, get = get(s, "curveAmount"), set = set(s, "curveAmount")}
	readouts.teams = c:Readout{text = "Teams visible to client"}
end

-- ── KEEPER ───────────────────────────────────────────────────────────
local function tabKeeper(w)
	local t = w:Tab("KEEPER")
	local s = Cfg.s.keeper

	local a = t:Section("Goalkeeper")
	a:Toggle{text = "Auto GK (air saves)", get = get(s, "autoGK"), set = set(s, "autoGK", function() TB.Repaint() end)}
	a:Toggle{text = "Auto GS (ground saves)", get = get(s, "autoGS"), set = set(s, "autoGS")}
	a:Slider{text = "Dive speed", min = 10, max = 250, step = 5, suffix = " st/s", get = get(s, "diveSpeed"), set = set(s, "diveSpeed")}
	a:Slider{text = "GK touch reach", min = 3, max = 40, step = 1, suffix = " st", get = get(s, "touchReach"), set = set(s, "touchReach")}
	a:Slider{text = "Predict window", min = 0.2, max = 4, step = 0.1, suffix = " s", get = get(s, "predictTime"), set = set(s, "predictTime")}
	readouts.gk = a:Readout{text = "Keeper state"}

	local b = t:Section("Panic")
	b:Toggle{text = "Panic Reach", get = get(s, "panicReach"), set = set(s, "panicReach")}
	b:Slider{text = "Panic radius", min = 5, max = 80, step = 1, suffix = " st", get = get(s, "panicRadius"), set = set(s, "panicRadius")}

	local c = t:Section("Block Kick Deny Events")
	c:Toggle{text = "Block deny events", get = get(s, "blockDeny"), set = set(s, "blockDeny", function(v)
		if v and not R.HookInstalled() then
			if not R.InstallHook() then
				Notify.Warn("block deny", "this executor cannot hook namecall, so nothing can be swallowed.")
			end
		end
	end)}
	c:Label("Names to swallow are set on the CONFIG tab. Arm the remote spy, take a deny, copy the name it logs.", "dim")
	readouts.deny = c:Readout{text = "Hook"}
end

-- ── SPECIAL ──────────────────────────────────────────────────────────
local function tabSpecial(w)
	local t = w:Tab("SPECIAL")
	local s = Cfg.s.special

	local a = t:Section("Phase")
	a:Toggle{text = "Phase Enemy", get = get(s, "phase"), set = set(s, "phase", function(v)
		if not v then SP.RestorePhase() end
		TB.Repaint()
	end)}
	a:Dropdown{text = "Phase mode", options = {"Look at", "Selected"}, byIndex = true, get = get(s, "phaseMode"), set = set(s, "phaseMode")}
	a:Toggle{text = "Anti-Phase", get = get(s, "antiPhase"), set = set(s, "antiPhase")}

	local b = t:Section("Frame Player")
	b:Toggle{text = "Frame Player", get = get(s, "framePlayer"), set = set(s, "framePlayer")}
	b:Button{text = "Select under crosshair", callback = function() SP.SelectUnderCrosshair() end}
	readouts.frame = b:Readout{text = "Framed"}

	local c = t:Section("Ball")
	c:Button{text = "Bring Ball", callback = function() SP.BringBall() end}
	c:Slider{text = "Bring distance", min = 2, max = 20, step = 0.5, suffix = " st", get = get(s, "bringDistance"), set = set(s, "bringDistance")}
	c:Button{text = "Freeze / Unfreeze Ball", callback = function() SP.ToggleFreeze() end}
	c:Button{text = "Delete Ball (local)", tone = "bad", callback = function() SP.DeleteBall() end}
	c:Toggle{text = "Ball Time", get = get(s, "ballTime"), set = set(s, "ballTime")}
	c:Slider{text = "Ball time scale", min = 0.2, max = 4, step = 0.05, get = get(s, "ballTimeScale"), set = set(s, "ballTimeScale")}

	local d = t:Section("Scoring")
	d:Toggle{text = "Dunk (auto score near goal)", get = get(s, "dunk"), set = set(s, "dunk")}
	d:Slider{text = "Dunk range", min = 5, max = 70, step = 1, suffix = " st", get = get(s, "dunkRange"), set = set(s, "dunkRange")}
	d:Toggle{text = "Goal Farm", get = get(s, "goalFarm"), set = set(s, "goalFarm")}
	d:Slider{text = "Goal farm delay", min = 0.3, max = 8, step = 0.1, suffix = " s", get = get(s, "goalFarmDelay"), set = set(s, "goalFarmDelay")}
	d:Toggle{text = "Save Farm", get = get(s, "saveFarm"), set = set(s, "saveFarm")}
	d:Slider{text = "Save farm delay", min = 0.3, max = 8, step = 0.1, suffix = " s", get = get(s, "saveFarmDelay"), set = set(s, "saveFarmDelay")}

	local e = t:Section("Trick Oms")
	e:Toggle{text = "Trick Oms (auto)", get = get(s, "trickOms"), set = set(s, "trickOms")}
	local names = {}
	for i, tr in ipairs(SP.tricks) do names[i] = tr.name end
	e:Dropdown{text = "Trick", options = names, byIndex = true, get = get(s, "trickIndex"), set = set(s, "trickIndex")}
	e:Button{text = "Run trick now", callback = function() SP.RunTrick(Cfg.s.special.trickIndex) end}
end

-- ── VISUALS ──────────────────────────────────────────────────────────
local function tabVisuals(w)
	local t = w:Tab("VISUALS")
	local s = Cfg.s.visuals

	local a = t:Section("Ball ESP")
	a:Toggle{text = "Ball ESP", get = get(s, "ballEsp"), set = set(s, "ballEsp")}
	a:Toggle{text = "Outline", get = get(s, "ballEspBox"), set = set(s, "ballEspBox")}
	a:Toggle{text = "Tracer", get = get(s, "ballEspTracer"), set = set(s, "ballEspTracer")}
	a:Toggle{text = "Distance", get = get(s, "ballEspDist"), set = set(s, "ballEspDist")}
	a:Toggle{text = "Ball Trail", get = get(s, "ballTrail"), set = set(s, "ballTrail")}

	local b = t:Section("Character paint")
	b:Toggle{text = "RGB Character (neon)", get = get(s, "rgbChar"), set = set(s, "rgbChar")}
	b:Toggle{text = "Neon material", get = get(s, "rgbNeon"), set = set(s, "rgbNeon")}
	b:Slider{text = "RGB speed", min = 0.1, max = 5, step = 0.1, get = get(s, "rgbSpeed"), set = set(s, "rgbSpeed")}
	b:Toggle{text = "Rainbow Boot Trail", get = get(s, "bootTrail"), set = set(s, "bootTrail")}

	local c = t:Section("World")
	c:Toggle{text = "Time of Day", get = get(s, "timeOfDay"), set = set(s, "timeOfDay")}
	c:Slider{text = "Clock", min = 0, max = 24, step = 0.5, suffix = " h", get = get(s, "clockTime"), set = set(s, "clockTime")}

	local d = t:Section("Spoof Marker")
	d:Toggle{text = "Spoof Marker", get = get(s, "spoofMarker"), set = set(s, "spoofMarker")}
	d:Slider{text = "Ping", min = 1, max = 400, step = 1, suffix = " ms", get = get(s, "spoofPing"), set = set(s, "spoofPing")}
	d:Slider{text = "CPU", min = 1, max = 100, step = 1, suffix = " %", get = get(s, "spoofCpu"), set = set(s, "spoofCpu")}
	d:Slider{text = "Sent", min = 1, max = 200, step = 1, suffix = " kb/s", get = get(s, "spoofSent"), set = set(s, "spoofSent")}
	d:Label("The overlay always works. Rewriting the engine readout needs hookfunction; without it the real panel keeps showing real numbers.", "dim")
end

-- ── CHARACTER ────────────────────────────────────────────────────────
local function tabCharacter(w)
	local t = w:Tab("CHARACTER")
	local s = Cfg.s.character

	local a = t:Section("Rig")
	a:Toggle{text = "R6 Character (local)", get = get(s, "r6"), set = set(s, "r6", function(v)
		if not v then CM.DestroyR6() end
	end)}
	a:Label("Local rig only. The server keeps the character it gave you, so hitboxes and animations server side do not change.", "dim")

	local b = t:Section("Appearance")
	b:Toggle{text = "Strip all accessories", get = get(s, "stripAccs"), set = set(s, "stripAccs")}
	b:Button{text = "Use Own Avatar", callback = function() CM.ApplyOwnAvatar() end}
	b:TextBox{text = "Hat asset id", placeholder = "0", get = get(s, "hatId"), set = num(s, "hatId")}
	b:Button{text = "Wear hat", callback = function() CM.WearAsset(Cfg.s.character.hatId, "hat") end}
	b:TextBox{text = "Hair asset id", placeholder = "0", get = get(s, "hairId"), set = num(s, "hairId")}
	b:Button{text = "Wear hair", callback = function() CM.WearAsset(Cfg.s.character.hairId, "hair") end}
	b:Button{text = "Clear items added here", tone = "bad", callback = function() CM.ClearAdded() end}
	readouts.assets = b:Readout{text = "Asset loading"}
end

-- ── BINDS ────────────────────────────────────────────────────────────
local function tabBinds(w)
	local t = w:Tab("BINDS")
	local labels = {
		reach = "Reach", sneaky = "Sneaky", aimbot = "Aimbot", aimpass = "AimPass",
		autogk = "Auto GK", phase = "Phase", juggle = "Auto Juggle", pokers = "Pokers",
		nero = "Manual Nero", bring = "Bring Ball", freeze = "Freeze Ball", panic = "Panic Eject",
	}
	local order = {"reach", "sneaky", "aimbot", "aimpass", "autogk", "phase", "juggle", "pokers", "nero", "bring", "freeze", "panic"}

	local a = t:Section("Keyboard and controller")
	a:Label("Left box takes a key press. Right box cycles controller buttons.", "dim")
	for _, id in ipairs(order) do
		local bind = Cfg.s.binds[id]
		a:Keybind{
			text = labels[id],
			get = function() return bind.key, bind.pad end,
			set = function(key, pad)
				if key ~= nil then bind.key = key end
				if pad ~= nil then bind.pad = pad end
			end,
		}
	end

	local b = t:Section("Menu")
	b:TextBox{text = "Menu key", placeholder = "Insert", get = get(Cfg.s.settings, "menuKey"), set = str(Cfg.s.settings, "menuKey")}
end

-- ── SETTINGS ─────────────────────────────────────────────────────────
local function tabSettings(w)
	local t = w:Tab("SETTINGS")
	local s = Cfg.s.settings

	local a = t:Section("Session")
	a:Toggle{text = "Anti-AFK", get = get(s, "antiAfk"), set = set(s, "antiAfk", function() ST.ApplyAntiAfk() end)}
	a:Toggle{text = "Notifications", get = get(s, "notifications"), set = set(s, "notifications")}
	a:Toggle{text = "Auto Complete Quest", get = get(s, "autoQuest"), set = set(s, "autoQuest")}
	a:Button{text = "Force Respawn", callback = function() ST.ForceRespawn() end}
	a:Button{text = "Rejoin", callback = function() ST.Rejoin() end}
	a:Button{text = "Panic Eject", tone = "bad", callback = function() ST.PanicEject() end}

	local b = t:Section("Servers")
	b:Toggle{text = "Auto Best Server on load", get = get(s, "autoBestServer"), set = set(s, "autoBestServer")}
	b:Slider{text = "Max ping to accept", min = 20, max = 400, step = 5, suffix = " ms", get = get(s, "hopMaxPing"), set = set(s, "hopMaxPing")}
	b:Slider{text = "Minimum free slots", min = 1, max = 20, step = 1, get = get(s, "hopMinSlots"), set = set(s, "hopMinSlots")}
	b:Button{text = "Hop Server (low ping)", callback = function() ST.HopLowPing() end}
	readouts.servers = b:Readout{text = "Server list"}

	local c = t:Section("Panic Staff")
	c:Toggle{text = "Panic Staff (auto-leave)", get = get(s, "panicStaff"), set = set(s, "panicStaff")}
	c:TextBox{text = "Staff group id", placeholder = "0", get = get(Cfg.target, "staffGroupId"), set = num(Cfg.target, "staffGroupId")}
	c:TextBox{text = "Minimum rank", placeholder = "100", get = get(Cfg.target, "staffMinRank"), set = num(Cfg.target, "staffMinRank")}
	c:TextBox{text = "Staff names", placeholder = "name1,name2", get = get(Cfg.target, "staffNames"), set = str(Cfg.target, "staffNames")}

	local d = t:Section("On-screen buttons")
	d:Toggle{text = "Touch buttons", get = get(s, "touchButtons"), set = set(s, "touchButtons", function() TB.Rebuild() end)}
	d:Slider{text = "Button size", min = 34, max = 110, step = 2, suffix = " px", get = get(s, "touchSize"), set = set(s, "touchSize", function() TB.Rebuild() end)}
	d:Dropdown{text = "Button shape", options = {"Shield", "Circle", "Square"}, byIndex = true,
		get = get(s, "touchShape"), set = set(s, "touchShape", function() TB.Rebuild() end)}
	d:Slider{text = "Button transparency", min = 0, max = 0.9, step = 0.05, get = get(s, "touchAlpha"), set = set(s, "touchAlpha", function() TB.Rebuild() end)}
	d:Button{text = "Reset button positions", callback = function()
		Cfg.s.settings.touchPos = {}
		TB.Rebuild()
	end}
end

-- ── CONFIG ───────────────────────────────────────────────────────────
local function tabConfig(w)
	local t = w:Tab("CONFIG")

	local a = t:Section("What the resolver found")
	readouts.ball    = a:Readout{text = "Ball"}
	readouts.goals   = a:Readout{text = "Goals"}
	readouts.backend = a:Readout{text = "Backend"}
	readouts.calib   = a:Readout{text = "Calibration"}
	a:Button{text = "Rescan ball and goals", callback = function()
		R.ScanBall(true)
		R.ScanGoals(true)
		Notify.Info("resolver", "rescanned")
	end}
	a:Button{text = "Pin ball under crosshair", callback = function()
		local cam = Svc.Camera()
		if not cam then return end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {Svc.Char()}
		local hit = Svc.Workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 800, params)
		if hit and hit.Instance and R.PinBall(hit.Instance) then
			Notify.Good("ball", "pinned " .. hit.Instance.Name)
		else
			Notify.Warn("ball", "nothing hit under the crosshair")
		end
	end}

	local b = t:Section("Goals")
	b:Label("Stand in the mouth of a goal, face the pitch, then press the matching button. A captured goal outranks anything the scanner guessed.", "dim")
	b:Button{text = "Capture Own Goal", callback = function()
		local ok, why = R.CaptureGoal("own")
		if ok then Notify.Good("goal", "own goal captured") else Notify.Warn("goal", why) end
	end}
	b:Button{text = "Capture Enemy Goal", callback = function()
		local ok, why = R.CaptureGoal("enemy")
		if ok then Notify.Good("goal", "enemy goal captured") else Notify.Warn("goal", why) end
	end}
	b:Button{text = "Swap own / enemy", callback = function()
		R.SwapGoals()
		Notify.Info("goal", "swapped")
	end}

	local c = t:Section("Calibration")
	c:Label("Measures live gravity, the velocity decay this build applies, and studs per power unit. Run it on an empty pitch with the ball nearby.", "dim")
	c:Button{text = "Run calibration", callback = function() Calib.Run() end}
	c:Button{text = "Reset calibration", tone = "bad", callback = function()
		Calib.Reset()
		Notify.Info("calibration", "cleared")
	end}

	local kr = t:Section("Kick remote")
	kr:Label("Watch is the one that produces a real value: arm it, then kick the ball yourself. It matches the remote send against the velocity jump and reads the argument shape off the call the game actually made.", "dim")
	kr:Button{text = "Watch: arm, then kick the ball", callback = function() Learn.Arm() end}
	kr:Button{text = "Cancel watch", callback = function()
		R.spyOn = false
		Learn.Disarm("cancelled")
	end}
	kr:Label("Probe fires candidates at the server and keeps one only if the ball actually moves. It sweeps every remote named like kick, shoot or ball.", "dim")
	kr:Button{text = "Probe candidates", callback = function() Learn.Probe() end}
	kr:Button{text = "Verify current remote", callback = function() Learn.Verify() end}
	kr:TextBox{text = "Candidate names", placeholder = "KickBall,GoalEvent",
		get = get(Cfg.target, "kickCandidates"), set = str(Cfg.target, "kickCandidates")}
	readouts.learn    = kr:Readout{text = "Learner"}
	readouts.verified = kr:Readout{text = "Verified"}
	readouts.ksource  = kr:Readout{text = "Source"}

	local dg = t:Section("Why a feature does nothing")
	dg:Button{text = "Test physics writes (ball must be still)", callback = function() Learn.OwnershipProbe() end}
	readouts.diag = {}
	local diagLabels = {"ball", "touch backend (reach)", "physics writes (sneaky, juggle)", "kick remote", "remote verified"}
	for i = 1, 5 do
		readouts.diag[i] = dg:Readout{text = diagLabels[i]}
	end
	readouts.verdict = dg:Label("", "dim")

	local d = t:Section("Remote spy")
	d:Toggle{text = "Arm spy", get = function() return R.spyOn end, set = function(v)
		R.spyOn = v
		if v and not R.InstallHook() then
			R.spyOn = false
			Notify.Warn("spy", "this executor cannot hook namecall")
		end
	end}
	d:Button{text = "Clear log", callback = function() R.ClearSpy() end}
	for i = 1, 6 do
		spyLabels[i] = d:Label("", "dim")
	end

	local e = t:Section("Target values")
	e:Label("Nothing here ships with a value. Fill from the spy log above; a feature with an empty box stays off and says so once.", "dim")
	e:TextBox{text = "Kick remote", placeholder = "unset", get = get(Cfg.target, "kickRemote"), set = str(Cfg.target, "kickRemote")}
	e:Dropdown{text = "Kick arg shape", options = {"", "dir_power", "vector", "cframe", "bare"},
		get = get(Cfg.target, "kickArgShape"), set = set(Cfg.target, "kickArgShape")}
	e:TextBox{text = "Quest remote", placeholder = "unset", get = get(Cfg.target, "questRemote"), set = str(Cfg.target, "questRemote")}
	e:TextBox{text = "Deny remotes", placeholder = "nameA,nameB", get = get(Cfg.target, "denyRemotes"), set = str(Cfg.target, "denyRemotes")}
	e:TextBox{text = "Ball name hints", placeholder = "Ball,MatchBall", get = get(Cfg.target, "ballNames"), set = str(Cfg.target, "ballNames")}
	e:TextBox{text = "Goal name hints", placeholder = "Goal,Net", get = get(Cfg.target, "goalNames"), set = str(Cfg.target, "goalNames")}

	local f = t:Section("Config files")
	f:TextBox{text = "Config name", placeholder = "default", get = get(Cfg.s.settings, "configName"), set = str(Cfg.s.settings, "configName")}
	f:Button{text = "Save", callback = function()
		local payload = {settings = Cfg.s, target = Cfg.target, calib = Cfg.calib}
		local ok, why = Util.SaveJson(Cfg.s.settings.configName, payload)
		if ok then Notify.Good("config", "saved " .. Cfg.s.settings.configName)
		else Notify.Bad("config", why) end
	end}
	f:Button{text = "Load", callback = function()
		local data, why = Util.LoadJson(Cfg.s.settings.configName)
		if not data then Notify.Bad("config", why) return end
		if type(data.settings) == "table" then Util.DeepMerge(Cfg.s, data.settings) end
		if type(data.target) == "table" then Util.DeepMerge(Cfg.target, data.target) end
		if type(data.calib) == "table" then Util.DeepMerge(Cfg.calib, data.calib) end
		M.window:Refresh()
		TB.Rebuild()
		Notify.Good("config", "loaded " .. Cfg.s.settings.configName)
	end}
	f:Button{text = "Reset to defaults", tone = "bad", callback = function()
		Util.DeepMerge(Cfg.s, Util.DeepCopy(Cfg.defaults))
		M.window:Refresh()
		TB.Rebuild()
		Notify.Info("config", "defaults restored")
	end}
	readouts.configs = f:Readout{text = "Saved configs"}

	local g = t:Section("Executor")
	for _, row in ipairs(Env.Summary()) do
		local ro = g:Readout{text = row[1]}
		ro:Set(row[2], row[2] == "yes" and "good" or (row[2] == "no" and "bad" or "gold"))
	end
end

-- ── build ────────────────────────────────────────────────────────────
function M.Build()
	local w = UI.Window{
		title = "olliE",
		subtitle = "LORD'S COURT  .  Touch Football  .  v" .. Cfg.VERSION,
	}
	M.window = w

	tabReach(w)
	tabSkills(w)
	tabAim(w)
	tabPass(w)
	tabKeeper(w)
	tabSpecial(w)
	tabVisuals(w)
	tabCharacter(w)
	tabBinds(w)
	tabSettings(w)
	tabConfig(w)

	w:Select("REACH")
	return w
end

-- ── live readouts, ticked once a second from main ────────────────────
function M.Tick()
	if not M.window then return end

	local ping = Svc.Ping()
	if readouts.ping then
		readouts.ping:Set(string.format("%d ms  ->  %.1f st", math.floor(ping), Reach.Radius()), "gold")
	end
	if readouts.aim then
		readouts.aim:Set(Aim.lastResult, Aim.lastResult == "idle" and "dim" or "gold")
	end
	if readouts.pass then
		readouts.pass:Set(Pass.lastResult, Pass.lastResult == "idle" and "dim" or "gold")
	end
	if readouts.teams then
		readouts.teams:Set(R.HasTeams() and "yes" or "no", R.HasTeams() and "good" or "bad")
	end
	if readouts.gk then
		local line, tone = GK.StatusLine()
		readouts.gk:Set(line, tone)
	end
	if readouts.deny then
		readouts.deny:Set(R.HookInstalled() and "installed" or "not installed",
			R.HookInstalled() and "good" or "bad")
	end
	if readouts.frame then
		local target = SP.CurrentTarget()
		readouts.frame:Set(target and target.Name or "nobody", target and "gold" or "dim")
	end
	if readouts.goal then
		local goal = Aim.AttackGoal()
		readouts.goal:Set(goal and (goal.tier .. " goal") or "none resolved", goal and "good" or "bad")
	end
	if readouts.ball then
		local st = R.Status()
		readouts.ball:Set(st.ball, R.Ball() and "good" or "bad")
	end
	if readouts.goals then
		local st = R.Status()
		readouts.goals:Set(string.format("%d found | own %s | enemy %s", st.goals, st.ownGoal, st.enemyGoal),
			st.goals > 0 and "good" or "bad")
	end
	if readouts.backend then
		local parts = {}
		for _, row in ipairs(BE.Report()) do
			parts[#parts + 1] = row[1] .. (row[2] and " ok" or " -")
		end
		readouts.backend:Set(table.concat(parts, " | "), "gold")
	end
	if readouts.calib then
		local line, tone = Calib.Line()
		readouts.calib:Set(line, tone)
	end
	if readouts.servers then
		readouts.servers:Set(#ST.lastServerList .. " cached", #ST.lastServerList > 0 and "good" or "dim")
	end
	if readouts.assets then
		readouts.assets:Set(Env.canAssets and "getobjects available" or "no getobjects",
			Env.canAssets and "good" or "bad")
	end
	if readouts.configs then
		local list = Util.ListConfigs()
		readouts.configs:Set(#list > 0 and table.concat(list, ", ") or "none", "dim")
	end

	if readouts.learn then
		local line, tone = Learn.Status()
		readouts.learn:Set(line, tone)
	end
	if readouts.verified then
		readouts.verified:Set(Learn.verified,
			string.find(Learn.verified, "moved", 1, true) and "good" or "dim")
	end
	if readouts.ksource then
		readouts.ksource:Set(Cfg.target.kickSource ~= "" and Cfg.target.kickSource or "unset",
			Cfg.target.kickSource ~= "" and "gold" or "dim")
	end
	if readouts.diag then
		local rows, verdict = Learn.Diagnose()
		for i = 1, 5 do
			local ro = readouts.diag[i]
			local row = rows[i]
			if ro and row then
				ro:Set(row[2], row[3] and "good" or "bad")
			end
		end
		if readouts.verdict then readouts.verdict:Set(verdict) end
	end

	local lines = R.SpyLines(6)
	for i = 1, 6 do
		if spyLabels[i] then
			spyLabels[i]:Set(lines[i] or "")
		end
	end

	M.window:SetStatus(string.format("ping %d ms  |  fps %d  |  %s",
		math.floor(ping), math.floor(Svc.Fps()), Env.name))
end

return M
end

-- ===== main  (src/25_main.lua) =====
__src["main"] = function(_R)
-- @module main
-- Boot, one driver per clock, binds, and a single teardown path shared by
-- Panic Eject and a normal unload.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local Env    = _R("env")
local Notify = _R("notify")
local R      = _R("resolve")
local BE     = _R("backend")
local Reach  = _R("reach")
local Skills = _R("skills")
local Aim    = _R("aimbot")
local Pass   = _R("aimpass")
local GK     = _R("keeper")
local SP     = _R("special")
local Vis    = _R("visuals")
local CM     = _R("charmod")
local ST     = _R("settings")
local Learn  = _R("learn")
local Binds  = _R("binds")
local TB     = _R("touchui")
local Menu   = _R("menu")

local Main = {}

local maid = Util.Maid.new()
local tickAccum = 0
local scanAccum = 0
local running = false

-- ── binds ────────────────────────────────────────────────────────────
local function registerBinds()
	Binds.Register("reach", "Reach", function()
		Cfg.s.reach.enabled = not Cfg.s.reach.enabled
		TB.Repaint()
		Notify.Info("reach", Cfg.s.reach.enabled and "on" or "off")
	end)
	Binds.Register("sneaky", "Sneaky", function()
		Cfg.s.skills.sneaky = not Cfg.s.skills.sneaky
		TB.Repaint()
		Notify.Info("sneaky", Cfg.s.skills.sneaky and "on" or "off")
	end)
	Binds.Register("aimbot", "Aimbot", function()
		Aim.Toggle()
		TB.Repaint()
	end)
	Binds.Register("aimpass", "AimPass", function()
		Pass.Toggle()
		TB.Repaint()
	end)
	Binds.Register("autogk", "Auto GK", function()
		GK.Toggle()
		TB.Repaint()
	end)
	Binds.Register("phase", "Phase", function()
		SP.TogglePhase()
		TB.Repaint()
	end)
	Binds.Register("juggle", "Auto Juggle", function()
		Cfg.s.skills.juggle = not Cfg.s.skills.juggle
		TB.Repaint()
		Notify.Info("juggle", Cfg.s.skills.juggle and "on" or "off")
	end)
	Binds.Register("pokers", "Pokers", function()
		Cfg.s.skills.pokers = not Cfg.s.skills.pokers
		TB.Repaint()
		Notify.Info("pokers", Cfg.s.skills.pokers and "on" or "off")
	end)
	Binds.Register("nero", "Manual Nero", function() Aim.Nero() end)
	Binds.Register("bring", "Bring Ball", function() SP.BringBall() end)
	Binds.Register("freeze", "Freeze Ball", function()
		SP.ToggleFreeze()
		TB.Repaint()
	end)
	Binds.Register("panic", "Panic Eject", function() Main.Unload() end)
	Binds.Register("menu", "Menu", function()
		if Menu.window then Menu.window:ToggleVisible() end
	end)
end

-- ── drivers ──────────────────────────────────────────────────────────
local function heartbeat(dt)
	if not running then return end
	local now = Util.Now()

	local ok, err = pcall(function()
		Reach.Step(dt, now)
		Reach.StepHold(dt)
		Skills.Step(dt, now)
		Aim.Step(dt, now)
		Pass.Step(dt, now)
		GK.Step(dt, now)
		SP.Step(dt, now)
		CM.Step(dt)
		ST.Step(dt, now)
		Learn.Step(dt, now)
		BE.StepCurve(dt)
	end)
	if not ok then
		warn("[olliE] heartbeat: " .. tostring(err))
	end

	tickAccum = tickAccum + dt
	if tickAccum >= 1 then
		tickAccum = 0
		pcall(Menu.Tick)
		pcall(TB.Repaint)
	end

	scanAccum = scanAccum + dt
	if scanAccum >= 3 then
		scanAccum = 0
		pcall(function()
			R.ScanBall(false)
			R.ScanGoals(false)
		end)
	end
end

local function renderStep(dt)
	if not running then return end
	local ok, err = pcall(function()
		Aim.StepCamera(dt)
		Vis.Step(dt)
	end)
	if not ok then
		warn("[olliE] render: " .. tostring(err))
	end
end

-- ── teardown ─────────────────────────────────────────────────────────
function Main.Unload()
	if not running then return end
	running = false

	pcall(function() BE.ClearShots() end)
	pcall(function() BE.Freeze(false) end)
	pcall(SP.Destroy)
	pcall(Vis.Destroy)
	pcall(CM.Destroy)
	pcall(ST.Destroy)
	pcall(Binds.Destroy)
	pcall(TB.Destroy)
	if Menu.window then pcall(function() Menu.window:Destroy() end) end
	pcall(Notify.Destroy)
	maid:Clean()

	local g = Util.Genv()
	g.LC_LOADED = nil
	g.LC_UNLOAD = nil
	warn("[olliE] unloaded")
end

-- ── boot ─────────────────────────────────────────────────────────────
function Main.Start()
	local g = Util.Genv()
	if g.LC_LOADED and type(g.LC_UNLOAD) == "function" then
		pcall(g.LC_UNLOAD)
	end
	g.LC_LOADED = true
	g.LC_UNLOAD = Main.Unload

	if not Svc.LP then
		Svc.LP = Svc.Players.LocalPlayer
	end
	if not Svc.LP then
		warn("[olliE] no LocalPlayer; this has to run as a client script")
		return
	end

	running = true

	R.IndexRemotes()
	R.ScanBall(true)
	R.ScanGoals(true)
	BE.ClaimOwnership()

	registerBinds()
	Binds.Init()

	Menu.Build()
	TB.Rebuild()
	ST.PanicHook = Main.Unload
	ST.ApplyAntiAfk()

	maid:Give(Svc.RunService.Heartbeat:Connect(heartbeat))
	maid:Give(Svc.RunService.RenderStepped:Connect(renderStep))

	maid:Give(Svc.Players.LocalPlayer.CharacterAdded:Connect(function()
		task.wait(0.6)
		SP.phased = {}
		pcall(function() R.ScanBall(true) end)
	end))

	local backends = {}
	for _, row in ipairs(BE.Report()) do
		if row[2] then backends[#backends + 1] = row[1] end
	end

	Notify.Good("olliE", "court is open. " ..
		(#backends > 0 and ("backends: " .. table.concat(backends, ", ")) or "no ball backend yet"))

	if R.Ball() == nil then
		Notify.Warn("resolver", "no ball found yet. CONFIG tab: look at it and press Pin ball under crosshair.")
	end
	if not R.enemyGoal then
		Notify.Warn("resolver", "no goal found. CONFIG tab: stand in each goal and capture it.")
	end

	if Cfg.s.settings.autoBestServer then
		task.delay(2, function() ST.AutoBestServer() end)
	end

	Menu.Tick()
end

return Main
end


if rawget(_G, "LC_TEST") then _G.LC_R = _R end

local ok, err = pcall(function()
	_R("main").Start()
end)
if not ok then
	warn("[olliE] boot failed: " .. tostring(err))
	local notified = pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "olliE", Text = tostring(err), Duration = 8,
		})
	end)
	if not notified then print("[olliE] boot failed: " .. tostring(err)) end
end
