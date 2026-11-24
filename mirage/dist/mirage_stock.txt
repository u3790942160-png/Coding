--[[
	mirage stock  --  Blox Fruits Mirage dealer toolkit
	Built from src/ by tools/build.py. Edit the modules, not this file.

	Ground truth note: this build ships with NO Blox Fruits offsets,
	remote names, instance paths or fruit prices. Mirage stock rotates and
	the game updates, so a baked table would be wrong within the week.
	Everything game specific is unset in the cfg module and is either read
	live by the resolver, learned from a purchase you make yourself, or
	left unset with the feature that needs it saying so once.
]]

local __src, __cache = {}, {}
local __LOADING = newproxy and newproxy(false) or {}

local function _R(name)
	local hit = __cache[name]
	if hit ~= nil then
		if hit == __LOADING then
			error("[mirage] dependency cycle at module: " .. tostring(name), 2)
		end
		return hit
	end
	local factory = __src[name]
	if factory == nil then
		error("[mirage] missing module: " .. tostring(name), 2)
	end
	__cache[name] = __LOADING
	local value = factory(_R)
	if value == nil then
		error("[mirage] module returned nil: " .. tostring(name), 2)
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
-- Settings store plus the single place every build-dependent value lives.

local Cfg = {}

Cfg.VERSION = "1.0.0"
Cfg.NAME    = "mirage stock"
Cfg.SHORT   = "mirage"
Cfg.FOLDER  = "mirage_stock"
Cfg.CFG_EXT = ".json"

-- =====================================================================
-- TARGET DATA -- build dependent, ALL UNSET.
--
-- No Blox Fruits dump was handed over, so nothing below was read from
-- one. Mirage stock rotates roughly every two hours and the game ships
-- updates, so a baked fruit table or price list would be wrong inside a
-- week and would read as real while being wrong. The resolver reads the
-- live shop instead, the learner captures the purchase remote off a buy
-- you make yourself, and anything still unset gates its own feature.
--
-- provenance tag format on every line:
--   [kind | build | source | state]
-- =====================================================================

Cfg.target = {
	-- [remote-name | build unset | source unset | unset]
	-- Fired when you buy from the dealer. CONFIG tab -> Watch a purchase,
	-- then buy one fruit by hand; the learner fills this and the shape.
	buyRemote = "",

	-- [arg-shape | build unset | source unset | unset]
	-- How buyRemote takes its arguments. One of:
	--   "name"        FireServer(string fruitName)
	--   "name_cur"    FireServer(string fruitName, string currency)
	--   "slot"        FireServer(number slotIndex)
	--   "slot_cur"    FireServer(number slotIndex, string currency)
	--   "bare"        FireServer()   -- the server reads a selection it already holds
	--   ""            unset -> buying is disabled and says so
	buyArgShape = "",

	-- [string | build unset | source resolver | unset]
	-- How buyRemote was obtained: watch / probe / manual.
	buySource = "",

	-- [string | build unset | source watch | unset]
	-- The currency token this build passes for a Beli purchase, captured
	-- from a buy you made yourself.
	buyBeliToken = "",

	-- [remote-name | build unset | source watch | unset]
	-- Fired by the game when the dealer's menu opens. Learned by arming
	-- the open watch and opening the shop once by hand.
	openRemote = "",
	openArgShape = "",

	-- [remote-name | build unset | source unset | unset]
	-- A RemoteFunction that returns the current stock, if this build has
	-- one. With it the stock can be polled without opening the shop.
	stockRemote = "",

	-- [remote-name | build unset | source third-party | UNVERIFIED]
	-- Names the prober will try before sweeping the place structurally.
	-- These are candidates, not values: each is checked for existence and,
	-- for buying, only kept once a purchase actually lands.
	buyCandidates = "",

	-- [instance-path | build unset | source unset | unset]
	-- Extra name hints, comma separated. The resolver already scores
	-- structurally; these just pin a name when it guesses wrong.
	dealerNames  = "",
	shopGuiNames = "",
	islandNames  = "",

	-- [string | build unset | source resolver | derived]
	-- leaderstats entry the budget is checked against. Blank means the
	-- resolver picks the largest numeric leaderstat it can find.
	currencyStat = "",
}

-- =====================================================================
-- SETTINGS -- ours, not the game's. Safe to ship with values.
-- =====================================================================

Cfg.s = {
	stock = {
		-- The tool never moves your character. It opens the dealer's menu
		-- where you stand and reads it.
		autoOpen      = true,
		reopenDelay   = 1.5,     -- seconds between attempts while shut
		keepOpen      = true,    -- reopen if the game closes it
		boostPrompt   = true,    -- raise the prompt's reach locally first
		revealHidden  = true,    -- unhide the shop frame already in PlayerGui
		useTouch      = true,    -- fire the dealer's touch parts as a fallback
		autoRefresh   = true,
		refreshRate   = 2.0,     -- seconds between stock reads
		showNormal    = true,    -- also list the normal dealer when readable
		notifyRestock = true,
		notifyWatched = true,
	},

	auto = {
		enabled       = false,
		-- Beli only. Robux is real money and the shop button does not say
		-- which currency it spends, so this tool never spends Robux.
		instant       = true,    -- buy on the same read the fruit appears in
		pollFast      = 0.15,    -- seconds between reads while armed
		budget        = 0,       -- 0 = no cap
		maxPerRestock = 1,
		retries       = 3,
		retryDelay    = 0.6,
		buyOnDetect   = true,
		stopAfterBuy  = false,
		watchlist     = {},      -- array of fruit names, exact as the shop prints them
	},

	-- Buying with no menu, no NPC and no stock read: the purchase is a
	-- remote call, and the dealer GUI is only ever a middleman.
	direct = {
		enabled       = false,
		target        = "Kitsune",
		attemptDelay  = 1.5,     -- seconds between fires once the remote is known
		sweepDelay    = 30,      -- seconds between full sweeps while unknown
		maxSweeps     = 0,       -- 0 = keep sweeping
		stopOnBuy     = true,
		useStockGate  = true,    -- only fire when a stock source says it is there
	},

	island = {
		autoFind      = true,    -- detection only; nothing is moved
		hopUntilFound = false,
		hopDelay      = 4,
		hopMaxPing    = 200,
		scanRadius    = 6000,
	},

	settings = {
		antiAfk       = true,
		notifications = true,
		touchButtons  = true,
		touchSize     = 54,
		touchShape    = 1,
		touchAlpha    = 0.15,
		menuKey       = "Insert",
		configName    = "default",
		touchPos      = {},
	},

	binds = {
		menu    = {key = "Insert", pad = "ButtonStart"},
		refresh = {key = "R",      pad = "ButtonY"},
		buytop  = {key = "B",      pad = "ButtonA"},
		auto    = {key = "O",      pad = "ButtonX"},
		open    = {key = "M",      pad = "ButtonB"},
		direct  = {key = "K",      pad = "DPadUp"},
		hop     = {key = "H",      pad = "DPadRight"},
		panic   = {key = "End",    pad = ""},
	},
}

Cfg.defaults = nil  -- filled by util at boot

-- The fruit catalogue is learned, never shipped. It grows from every
-- stock read and from anything typed into the picker, and persists with
-- the config file.
Cfg.catalog = {}

function Cfg.List(str)
	local out = {}
	if type(str) ~= "string" then return out end
	for piece in string.gmatch(str, "([^,]+)") do
		local t = string.match(piece, "^%s*(.-)%s*$")
		if t ~= "" then out[#out + 1] = t end
	end
	return out
end

function Cfg.Has(path)
	local v = Cfg.target[path]
	if type(v) == "string" then return v ~= "" end
	if type(v) == "number" then return v ~= 0 end
	return v ~= nil
end

-- watchlist helpers, used by the picker and the auto engine
function Cfg.Watching(name)
	for _, n in ipairs(Cfg.s.auto.watchlist) do
		if string.lower(n) == string.lower(name) then return true end
	end
	return false
end

function Cfg.Watch(name)
	if name == nil or name == "" then return false end
	if Cfg.Watching(name) then return false end
	table.insert(Cfg.s.auto.watchlist, name)
	return true
end

function Cfg.Unwatch(name)
	for i, n in ipairs(Cfg.s.auto.watchlist) do
		if string.lower(n) == string.lower(name) then
			table.remove(Cfg.s.auto.watchlist, i)
			return true
		end
	end
	return false
end

function Cfg.ToggleWatch(name)
	if Cfg.Watching(name) then
		Cfg.Unwatch(name)
		return false
	end
	Cfg.Watch(name)
	return true
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

function Svc.PlayerGui()
	local lp = Svc.LP
	if not lp then return nil end
	return lp:FindFirstChildOfClass("PlayerGui")
end

-- Every visible TextLabel / TextButton under the player's own GUI.
function Svc.VisibleTexts()
	local out = {}
	local pg = Svc.PlayerGui()
	if not pg then return out end
	for _, d in ipairs(pg:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local ok, visible = pcall(function()
				return d.Visible and d.Text ~= nil and d.Text ~= ""
			end)
			if ok and visible then out[#out + 1] = d end
		end
	end
	return out
end

-- Every TextLabel / TextButton under the player's GUI, shown or not.
-- A shop that has never been opened is still sitting there, hidden.
function Svc.AllTexts()
	local out = {}
	local pg = Svc.PlayerGui()
	if not pg then return out end
	for _, d in ipairs(pg:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local ok, text = pcall(function() return d.Text end)
			if ok and type(text) == "string" and text ~= "" then out[#out + 1] = d end
		end
	end
	return out
end

-- Models whose name carries one of these hints, Humanoid or not. Blox
-- Fruits style NPCs are not all rigs.
function Svc.NamedModels(hints, cap)
	local out = {}
	for _, d in ipairs(Svc.Workspace:GetDescendants()) do
		if d:IsA("Model") then
			local lower = string.lower(d.Name)
			for _, h in ipairs(hints) do
				if string.find(lower, h, 1, true) then
					out[#out + 1] = d
					break
				end
			end
			if cap and #out >= cap then return out end
		end
	end
	return out
end

-- Walk up from a GuiObject until a ScreenGui, reporting whether the whole
-- chain is visible. A label inside a hidden frame is not on screen.
function Svc.ChainVisible(gui)
	local node = gui
	local hops = 0
	while node and hops < 24 do
		if node:IsA("ScreenGui") then return node.Enabled end
		if node:IsA("GuiObject") and not node.Visible then return false end
		node = node.Parent
		hops = hops + 1
	end
	return false
end

function Svc.Leaderstats()
	local lp = Svc.LP
	if not lp then return nil end
	return lp:FindFirstChild("leaderstats")
end

-- Models in the workspace that carry a Humanoid but no Player: NPCs.
function Svc.Npcs()
	local out = {}
	local taken = {}
	for _, p in ipairs(Svc.Players:GetPlayers()) do
		if p.Character then taken[p.Character] = true end
	end
	for _, d in ipairs(Svc.Workspace:GetDescendants()) do
		if d:IsA("Model") and not taken[d] and d:FindFirstChildOfClass("Humanoid") then
			out[#out + 1] = d
		end
	end
	return out
end

function Svc.ModelPos(model)
	if not model then return nil end
	local ok, cf = pcall(function()
		if model.PrimaryPart then return model.PrimaryPart.CFrame end
		local c = model:GetBoundingBox()
		return c
	end)
	if ok and cf then return cf.Position end
	local part = model:FindFirstChildWhichIsA("BasePart")
	if part then return part.Position end
	return nil
end

function Svc.Teleport(position)
	local hrp = Svc.HRP()
	if not hrp or not position then return false end
	local ok = pcall(function()
		hrp.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
	end)
	return ok
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

-- ===== theme  (src/05_theme.lua) =====
__src["theme"] = function(_R)
-- @module theme
-- Mirage palette: night indigo, sand, and the teal of the island showing
-- through the fog. Ornaments are frames, not glyphs, so nothing depends on
-- a font carrying the codepoint.
local Svc = _R("svc")

local T = {}

local function c3(r, g, b) return Color3.fromRGB(r, g, b) end

T.col = {
	bg0      = c3(9, 11, 19),
	bg1      = c3(17, 21, 33),
	bg2      = c3(25, 31, 47),
	bg3      = c3(35, 44, 64),
	stroke   = c3(58, 92, 104),
	strokeLo = c3(33, 47, 61),
	accent   = c3(222, 190, 132),
	accentHi = c3(249, 228, 178),
	accentLo = c3(138, 114, 70),
	teal     = c3(86, 196, 190),
	tealHi   = c3(152, 232, 224),
	text     = c3(231, 234, 241),
	textDim  = c3(138, 149, 166),
	good     = c3(104, 196, 140),
	bad      = c3(206, 86, 86),
	warn     = c3(228, 172, 80),
}

T.font = {
	title = Enum.Font.GothamMedium,
	body  = Enum.Font.Gotham,
	mono  = Enum.Font.Code,
}

T.metric = {
	corner     = 6,
	pad        = 10,
	rowH       = 34,
	rowHMobile = 42,
	sliderH    = 46,
	sliderHMob = 56,
	tabH       = 34,
	headerH    = 46,
	stroke     = 1,
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
	if kind == "title" then return mob and 20 or 18 end
	if kind == "small" then return mob and 14 or 13 end
	if kind == "tab"   then return mob and 15 or 14 end
	return mob and 16 or 15
end

function T.WindowSize()
	local vp = Svc.ViewportSize()
	if Svc.IsMobile() then
		local w = math.min(vp.X * 0.94, 600)
		local h = math.min(vp.Y * 0.82, 540)
		return UDim2.fromOffset(math.floor(w), math.floor(h))
	end
	return UDim2.fromOffset(640, 450)
end

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

function T.AccentGradient(parent, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, T.col.accentLo),
		ColorSequenceKeypoint.new(0.42, T.col.accentHi),
		ColorSequenceKeypoint.new(0.72, T.col.teal),
		ColorSequenceKeypoint.new(1.0, T.col.accentLo),
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

function T.Lozenge(parent, size, color)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color or T.col.accent
	f.BorderSizePixel = 0
	f.Size = UDim2.fromOffset(size, size)
	f.Rotation = 45
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Parent = parent
	return f
end

-- A low sun over a dune: disc, three rays, and a bar for the horizon.
function T.Sigil(parent, h, color)
	local holder = Instance.new("Frame")
	holder.Name = "Sigil"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(h * 1.5, h)
	holder.Parent = parent

	local col = color or T.col.accent
	local disc = Instance.new("Frame")
	disc.BackgroundColor3 = col
	disc.BorderSizePixel = 0
	disc.AnchorPoint = Vector2.new(0.5, 1)
	disc.Position = UDim2.new(0.5, 0, 1, -math.floor(h * 0.22))
	local d = math.max(6, math.floor(h * 0.56))
	disc.Size = UDim2.fromOffset(d, d)
	disc.Parent = holder
	T.Corner(disc, math.floor(d / 2))

	for i = -1, 1 do
		local ray = Instance.new("Frame")
		ray.BackgroundColor3 = T.col.accentHi
		ray.BorderSizePixel = 0
		ray.AnchorPoint = Vector2.new(0.5, 1)
		ray.Position = UDim2.new(0.5 + i * 0.33, 0, 1, -math.floor(h * 0.62))
		ray.Size = UDim2.fromOffset(2, math.floor(h * 0.26))
		ray.Rotation = i * 22
		ray.Parent = holder
		T.Corner(ray, 1)
	end

	local horizon = Instance.new("Frame")
	horizon.BackgroundColor3 = T.col.teal
	horizon.BorderSizePixel = 0
	horizon.AnchorPoint = Vector2.new(0.5, 1)
	horizon.Position = UDim2.new(0.5, 0, 1, 0)
	horizon.Size = UDim2.new(1, 0, 0, 2)
	horizon.Parent = holder
	T.Corner(horizon, 1)
	return holder
end

function T.Divider(parent, width)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 10)
	holder.Parent = parent

	local line = Instance.new("Frame")
	line.BackgroundColor3 = T.col.accentLo
	line.BorderSizePixel = 0
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale(0.5, 0.5)
	line.Size = UDim2.new(width or 1, 0, 0, 1)
	line.Parent = holder
	T.AccentGradient(line, 0)

	local dot = T.Lozenge(holder, 6, T.col.teal)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Parent = holder
	return holder
end

return T
end

-- ===== notify  (src/06_notify.lua) =====
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
	return Theme.col.accent
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

-- ===== ui  (src/07_ui.lua) =====
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

	local crown = Theme.Sigil(header, 18)
	crown.Position = UDim2.new(0, 12, 0.5, -9)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Theme.font.title
	title.TextSize = Theme.TextSize("title")
	title.TextColor3 = Theme.col.accentHi
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = opts.title or "olliE"
	title.Position = UDim2.new(0, 48, 0, 4)
	title.Size = UDim2.new(1, -140, 0, 24)
	title.Parent = header
	Theme.AccentGradient(title, 90)

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
	strip.ScrollBarImageColor3 = Theme.col.accentLo
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
	page.ScrollBarImageColor3 = Theme.col.accentLo
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
		t.button.TextColor3 = on and Theme.col.accentHi or Theme.col.textDim
		t.button.BackgroundColor3 = on and Theme.col.bg3 or Theme.col.bg2
		t.stroke.Color = on and Theme.col.accent or Theme.col.strokeLo
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
	head.TextColor3 = Theme.col.accent
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.Text = title
	head.Size = UDim2.new(1, 0, 0, 20)
	head.LayoutOrder = 0
	head.Parent = inner

	local rule = Instance.new("Frame")
	rule.BackgroundColor3 = Theme.col.accentLo
	rule.BorderSizePixel = 0
	rule.Size = UDim2.new(1, 0, 0, 1)
	rule.LayoutOrder = 1
	rule.Parent = inner
	Theme.AccentGradient(rule, 0)

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
			BackgroundColor3 = state and Theme.col.accentHi or Theme.col.textDim,
		}):Play()
		tstroke.Color = state and Theme.col.accent or Theme.col.strokeLo
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
	value.TextColor3 = Theme.col.accentHi
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
	fill.BackgroundColor3 = Theme.col.accent
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	Theme.Corner(fill, 3)
	Theme.AccentGradient(fill, 0)

	local knob = Instance.new("Frame")
	knob.BackgroundColor3 = Theme.col.accentHi
	knob.BorderSizePixel = 0
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0, 0.5)
	knob.Size = UDim2.fromOffset(Svc.IsMobile() and 20 or 14, Svc.IsMobile() and 20 or 14)
	knob.ZIndex = 3
	knob.Parent = track
	Theme.Corner(knob, 10)
	Theme.Stroke(knob, Theme.col.accentLo, 1)

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
	btn.TextColor3 = Theme.col.accentHi
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
			b.TextColor3 = on and Theme.col.accentHi or Theme.col.textDim
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
	b.TextColor3 = o.tone == "bad" and Theme.col.bad or Theme.col.accentHi
	b.Text = o.text
	b.Size = UDim2.new(1, 0, 0, Theme.RowHeight())
	b.LayoutOrder = self:next()
	b.Parent = self.frame
	Theme.Corner(b, 5)
	Theme.Stroke(b, o.tone == "bad" and Theme.col.bad or Theme.col.accentLo, 1)
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
		b.TextColor3 = Theme.col.accentHi
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

-- ── Dynamic sections ─────────────────────────────────────────────────
-- Drops every widget added after the heading and rule, so a list can be
-- rebuilt in place without rebuilding the window.
function Section:Clear()
	for _, child in ipairs(self.frame:GetChildren()) do
		if child:IsA("GuiObject") and child.LayoutOrder >= 2 then
			child:Destroy()
		end
	end
	self.order = 2
end

-- A row carrying a label, a right aligned value, and one action button.
-- This is what a stock line is.
function Section:ActionRow(o)
	local row = baseRow(self, nil)

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Font = Theme.font.body
	name.TextSize = Theme.TextSize("body")
	name.TextColor3 = o.tone == "watched" and Theme.col.accentHi or Theme.col.text
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = o.text
	name.Position = UDim2.new(0, 10, 0, 0)
	name.Size = UDim2.new(1, -190, 1, 0)
	name.Parent = row

	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Font = Theme.font.mono
	value.TextSize = Theme.TextSize("small")
	value.TextColor3 = Theme.col.textDim
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextTruncate = Enum.TextTruncate.AtEnd
	value.Text = o.value or ""
	value.AnchorPoint = Vector2.new(1, 0.5)
	value.Position = UDim2.new(1, -96, 0.5, 0)
	value.Size = UDim2.fromOffset(150, Theme.RowHeight() - 10)
	value.Parent = row

	local btn = Instance.new("TextButton")
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = Theme.col.bg3
	btn.BorderSizePixel = 0
	btn.Font = Theme.font.body
	btn.TextSize = Theme.TextSize("small")
	btn.TextColor3 = Theme.col.accentHi
	btn.Text = o.button or "BUY"
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, -8, 0.5, 0)
	btn.Size = UDim2.fromOffset(82, Theme.RowHeight() - 10)
	btn.Parent = row
	Theme.Corner(btn, 4)
	Theme.Stroke(btn, Theme.col.accentLo, 1)
	hoverTint(btn, Theme.col.bg3, Theme.col.bg2)
	btn.MouseButton1Click:Connect(function()
		local ok, err = pcall(o.callback)
		if not ok then Notify.Bad("fault", tostring(err)) end
	end)

	-- a second, optional button on the left of the first
	local alt = nil
	if o.altButton then
		alt = Instance.new("TextButton")
		alt.AutoButtonColor = false
		alt.BackgroundColor3 = Theme.col.bg2
		alt.BorderSizePixel = 0
		alt.Font = Theme.font.body
		alt.TextSize = Theme.TextSize("small")
		alt.TextColor3 = o.altOn and Theme.col.accentHi or Theme.col.textDim
		alt.Text = o.altButton
		alt.AnchorPoint = Vector2.new(1, 0.5)
		alt.Position = UDim2.new(1, -94, 0.5, 0)
		alt.Size = UDim2.fromOffset(36, Theme.RowHeight() - 10)
		alt.Parent = row
		Theme.Corner(alt, 4)
		Theme.Stroke(alt, o.altOn and Theme.col.accent or Theme.col.strokeLo, 1)
		alt.MouseButton1Click:Connect(function()
			local ok, err = pcall(o.altCallback)
			if not ok then Notify.Bad("fault", tostring(err)) end
		end)
		value.Position = UDim2.new(1, -134, 0.5, 0)
		value.Size = UDim2.fromOffset(120, Theme.RowHeight() - 10)
		name.Size = UDim2.new(1, -266, 1, 0)
	end

	return {
		row = row,
		SetValue = function(_, text) value.Text = text end,
		SetTone = function(_, c) name.TextColor3 = c end,
	}
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
			elseif tone == "accent" then v.TextColor3 = Theme.col.accentHi
			else v.TextColor3 = Theme.col.textDim end
		end,
	}
end

UI.Section = Section
UI.Tab = Tab
UI.WindowClass = Window

return UI
end

-- ===== binds  (src/08_binds.lua) =====
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

-- ===== touchui  (src/09_touchui.lua) =====
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
	{id = "direct",  caption = "DIR", lit = function() return Cfg.s.direct.enabled end},
	{id = "refresh", caption = "RD",  lit = function() return Cfg.s.stock.autoRefresh end},
	{id = "buytop",  caption = "BUY", lit = function() return false end},
	{id = "auto",    caption = "AUT", lit = function() return Cfg.s.auto.enabled end},
	{id = "open",    caption = "OPN", lit = function() return Cfg.s.stock.autoOpen end},
	{id = "hop",     caption = "HOP", lit = function() return Cfg.s.island.hopUntilFound end},
	{id = "menu",    caption = "MS",  lit = function() return true end},
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

	local stroke = Theme.Stroke(frame, Theme.col.accentLo, 1)
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
		entry.stroke.Color = on and Theme.col.accentHi or Theme.col.accentLo
		entry.label.TextColor3 = on and Theme.col.accentHi or Theme.col.textDim
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

-- ===== resolve  (src/10_resolve.lua) =====
__src["resolve"] = function(_R)
-- @module resolve
-- Runtime discovery. Nothing here hardcodes a Blox Fruits path, a fruit
-- name or a price. Every result carries a tier:
--   "confirmed"  pinned by the operator this session
--   "derived"    scored from engine-visible structure
--   "unknown"    not found; the caller gates its feature
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local Env    = _R("env")
local Notify = _R("notify")

local R = {}

R.dealer       = nil     -- the NPC model
R.dealerTier   = "unknown"
R.shopRoot     = nil     -- the GuiObject the stock rows live under
R.shopTier     = "unknown"
R.remoteIndex  = {}

local lastDealerScan = 0
local lastShopScan = 0
local DEALER_RESCAN = 4.0
local SHOP_RESCAN = 0.75

-- ── dealer NPC ───────────────────────────────────────────────────────
local DEALER_HINTS = {"dealer", "merchant", "vendor", "shop", "fruit", "advanced", "mirage"}
local PROMPT_HINTS = {"shop", "buy", "fruit", "purchase", "trade", "deal"}

local function hintScore(text, hints, weight)
	local score = 0
	local lower = string.lower(text or "")
	for _, h in ipairs(hints) do
		if string.find(lower, h, 1, true) then score = score + weight end
	end
	return score
end

local function promptScore(model)
	local score = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			score = score + 25
			score = score + hintScore(d.ActionText, PROMPT_HINTS, 20)
			score = score + hintScore(d.ObjectText, DEALER_HINTS, 20)
		elseif d:IsA("ClickDetector") then
			score = score + 15
		end
	end
	return score
end

function R.DealerParts(model)
	local prompts, clicks, touch = 0, 0, 0
	if not model then return prompts, clicks, touch end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ProximityPrompt") then prompts = prompts + 1
		elseif d:IsA("ClickDetector") then clicks = clicks + 1
		elseif d:IsA("BasePart") then
			if d.CanTouch ~= false then touch = touch + 1 end
		end
	end
	return prompts, clicks, touch
end

function R.ScanDealer(force)
	local now = Util.Now()
	if not force and R.dealer and R.dealer.Parent and (now - lastDealerScan) < DEALER_RESCAN then
		return R.dealer
	end
	lastDealerScan = now

	local pinned = Cfg.List(Cfg.target.dealerNames)

	-- rigs, plus anything named like a dealer whether or not it has one
	local candidates = Svc.Npcs()
	local seen = {}
	for _, m in ipairs(candidates) do seen[m] = true end
	for _, m in ipairs(Svc.NamedModels(DEALER_HINTS, 400)) do
		if not seen[m] then
			seen[m] = true
			candidates[#candidates + 1] = m
		end
	end

	local best, bestScore = nil, 25
	for _, npc in ipairs(candidates) do
		local score = hintScore(npc.Name, DEALER_HINTS, 30)
		for _, pin in ipairs(pinned) do
			if string.lower(npc.Name) == string.lower(pin) then score = score + 300 end
		end
		local ok, ps = pcall(promptScore, npc)
		if ok then score = score + ps end
		-- a dealer you can actually open beats one you cannot
		local prompts, clicks = R.DealerParts(npc)
		if prompts > 0 or clicks > 0 then score = score + 45 end
		if score > bestScore then best, bestScore = npc, score end
	end

	if best then
		R.dealer = best
		R.dealerTier = bestScore >= 250 and "confirmed" or "derived"
	elseif R.dealer and not R.dealer.Parent then
		R.dealer = nil
		R.dealerTier = "unknown"
	end
	return R.dealer
end

function R.DealerPos()
	local d = R.ScanDealer(false)
	if not d then return nil end
	return Svc.ModelPos(d)
end

function R.PinDealer(model)
	if model and model:IsA("Model") then
		R.dealer = model
		R.dealerTier = "confirmed"
		Cfg.target.dealerNames = model.Name
		return true
	end
	return false
end

-- Local writes that make a prompt reachable from where you are standing.
-- The server still decides whether the trigger counts, so this helps a
-- build that checks the prompt and does nothing for one that checks the
-- player's position.
function R.BoostPrompts(model)
	local touched = 0
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("ProximityPrompt") then
			pcall(function()
				if p.MaxActivationDistance < 500 then p.MaxActivationDistance = 500 end
				p.RequiresLineOfSight = false
				p.HoldDuration = 0
			end)
			touched = touched + 1
		end
	end
	return touched
end

-- Fire whatever the NPC exposes.
function R.OpenDealer()
	local d = R.ScanDealer(false)
	if not d then return false, "no dealer found" end

	if Cfg.s.stock.boostPrompt then pcall(R.BoostPrompts, d) end

	local fired = 0
	if Env.fireproximity then
		for _, p in ipairs(d:GetDescendants()) do
			if p:IsA("ProximityPrompt") then
				pcall(function() Env.fireproximity(p, 0) end)
				fired = fired + 1
			end
		end
	end
	if Env.fireclickdetector then
		for _, c in ipairs(d:GetDescendants()) do
			if c:IsA("ClickDetector") then
				pcall(function() Env.fireclickdetector(c) end)
				fired = fired + 1
			end
		end
	end

	if fired == 0 then
		if not Env.fireproximity and not Env.fireclickdetector then
			return false, "executor has no fireproximityprompt or fireclickdetector"
		end
		return false, "the dealer model carries no prompt and no click detector"
	end
	return true, fired .. " trigger(s) fired"
end

-- Walk into the dealer without walking: fire the touch on its parts.
function R.TouchDealer()
	if not Env.canTouch then return false, "executor has no firetouchinterest" end
	local d = R.ScanDealer(false)
	if not d then return false, "no dealer found" end
	local hrp = Svc.HRP()
	if not hrp then return false, "no character" end
	local fired = 0
	for _, part in ipairs(d:GetDescendants()) do
		if part:IsA("BasePart") and fired < 12 then
			pcall(function()
				Env.firetouchinterest(hrp, part, 0)
				Env.firetouchinterest(hrp, part, 1)
			end)
			fired = fired + 1
		end
	end
	if fired == 0 then return false, "dealer has no parts to touch" end
	return true, fired .. " part(s) touched"
end

-- A button in your own GUI that opens the shop.
function R.ClickShopButton()
	if not Env.getconnections then return false, "no getconnections" end
	local hints = {"shop", "dealer", "fruit", "stock", "buy"}
	for _, gui in ipairs(Svc.AllTexts()) do
		if gui:IsA("TextButton") then
			local lower = string.lower(gui.Name .. " " .. tostring(gui.Text))
			for _, h in ipairs(hints) do
				if string.find(lower, h, 1, true) then
					local fired = 0
					pcall(function()
						for _, conn in ipairs(Env.getconnections(gui.MouseButton1Click)) do
							if conn.Fire then conn:Fire() fired = fired + 1 end
						end
					end)
					if fired > 0 then return true, gui.Name end
				end
			end
		end
	end
	return false, "no shop-ish button with a live handler"
end

-- The remote the game fires when the menu opens, if the watch caught it.
function R.FireOpenRemote()
	local name = Util.Trim(Cfg.target.openRemote)
	if name == "" then return false, "no open remote learned" end
	local rem = R.FindRemote(name)
	if not rem then return false, "open remote not in this place" end
	local shape = Util.Trim(Cfg.target.openArgShape)
	local ok = pcall(function()
		if rem:IsA("RemoteFunction") then
			rem:InvokeServer()
		elseif shape == "dealer" and R.dealer then
			rem:FireServer(R.dealer.Name)
		else
			rem:FireServer()
		end
	end)
	if not ok then return false, "open remote errored" end
	return true, name
end

-- Every way in, cheapest and least invasive first. Returns ok, how.
function R.OpenAny()
	if R.ShopOpen() then return true, "already open" end

	if Cfg.s.stock.revealHidden then
		local hidden = R.FindHiddenShops()
		if #hidden > 0 then
			local ok, why = R.RevealShop(hidden[1].frame)
			if ok then
				R.ScanShop(true)
				if R.ShopOpen() then return true, "revealed " .. why end
			end
		end
	end

	local ok, why = R.FireOpenRemote()
	if ok then
		R.ScanShop(true)
		if R.ShopOpen() then return true, "open remote " .. why end
	end

	ok, why = R.OpenDealer()
	local lastWhy = why
	if ok then
		R.ScanShop(true)
		if R.ShopOpen() then return true, why end
	end

	if Cfg.s.stock.useTouch then
		ok, why = R.TouchDealer()
		if ok then
			R.ScanShop(true)
			if R.ShopOpen() then return true, "touch: " .. why end
		end
	end

	ok, why = R.ClickShopButton()
	if ok then
		R.ScanShop(true)
		if R.ShopOpen() then return true, "ui button " .. why end
	end

	return false, lastWhy or why or "nothing worked"
end

-- ── auto open ────────────────────────────────────────────────────────
-- Opens the dealer's menu where you stand. Nothing here moves you.
R.openState = "idle"
R.openTries = 0
local lastOpenTry = -1e9

function R.StepAutoOpen(dt, now)
	if not Cfg.s.stock.autoOpen then
		R.openState = "off"
		return
	end

	if R.ShopOpen() then
		if R.openTries > 0 then
			Notify.Good("dealer", "menu open after " .. R.openTries .. " attempt(s)")
		end
		R.openTries = 0
		R.openState = "open"
		return
	end

	-- it was open and the game shut it
	if R.openState == "open" and not Cfg.s.stock.keepOpen then
		R.openState = "closed, not reopening"
		return
	end

	-- a hidden shop frame needs no dealer at all, so only bail when both
	-- the NPC and a hidden frame are missing
	local dealer = R.ScanDealer(false)
	if not dealer and #R.FindHiddenShops() == 0 then
		R.openState = "no dealer and no hidden shop frame"
		return
	end

	-- back off rather than hammering a prompt the server is refusing
	local delay = math.max(Cfg.s.stock.reopenDelay, 0.25)
	if R.openTries >= 8 then delay = delay * 4 end
	if now - lastOpenTry < delay then return end
	lastOpenTry = now
	R.openTries = R.openTries + 1

	local ok, why = R.OpenAny()
	if ok then
		R.openState = "open"
		Notify.Good("dealer", "menu opened: " .. why)
		R.openTries = 0
		return
	end

	R.openState = why .. " (" .. R.openTries .. ")"
	if R.openTries == 8 then
		Notify.Once("open_slow", "dealer",
			"eight tries, menu still shut. CONFIG tab: Scan and report shows what is actually there, and Watch the open captures what the game fires when you open it by hand.", "warn")
	end
end

function R.OpenStatus()
	if R.openState == "open" then return "menu open", "good" end
	if R.openState == "off" then return "auto open off", "dim" end
	return R.openState, "bad"
end

-- ── shop GUI ─────────────────────────────────────────────────────────
-- A stock row is a container holding a name-ish label and a price-ish
-- label. Find the container that holds the most such pairs: that is the
-- stock list, whatever the game calls it.

local UI_NOISE = {
	"close", "back", "exit", "cancel", "confirm", "ok", "yes", "no",
	"shop", "stock", "buy", "sell", "price", "beli", "money", "robux",
	"inventory", "level", "settings", "menu", "title", "amount", "total",
}

function R.LooksLikePrice(text)
	if type(text) ~= "string" then return false end
	if not string.find(text, "%d") then return false end
	local stripped = string.gsub(text, "[%s,%.]", "")
	-- a price is mostly digits with at most a short unit around it
	local digits = select(2, string.gsub(stripped, "%d", ""))
	return digits >= 2 and digits >= (#stripped - 8)
end

function R.LooksLikeName(text)
	if type(text) ~= "string" then return false end
	local trimmed = Util.Trim(text)
	local n = #trimmed
	if n < 3 or n > 28 then return false end
	if string.find(trimmed, "%d") then return false end
	if not string.find(trimmed, "%a") then return false end
	local lower = string.lower(trimmed)
	for _, noise in ipairs(UI_NOISE) do
		if lower == noise then return false end
	end
	return true
end

local function containerOf(gui, hops)
	local node = gui.Parent
	local n = 0
	while node and n < (hops or 2) do
		if node:IsA("GuiObject") then return node end
		node = node.Parent
		n = n + 1
	end
	return nil
end

-- Group name+price label pairs by the frame that holds them, and roll
-- those row frames up to the list that holds the most of them.
local function bestList(texts, requireVisible)
	local tally = {}
	for _, label in ipairs(texts) do
		if (not requireVisible) or Svc.ChainVisible(label) then
			local box = containerOf(label, 2)
			if box then
				tally[box] = tally[box] or {names = 0, prices = 0}
				if R.LooksLikePrice(label.Text) then
					tally[box].prices = tally[box].prices + 1
				elseif R.LooksLikeName(label.Text) then
					tally[box].names = tally[box].names + 1
				end
			end
		end
	end

	local listTally = {}
	for box, counts in pairs(tally) do
		if counts.names >= 1 and counts.prices >= 1 then
			local list = box.Parent
			if list and list:IsA("GuiObject") then
				listTally[list] = (listTally[list] or 0) + 1
			end
		end
	end

	local ranked = {}
	local pinned = Cfg.List(Cfg.target.shopGuiNames)
	for list, rows in pairs(listTally) do
		local score = rows
		local path = string.lower(list.Name)
		local parent = list.Parent
		if parent then path = path .. " " .. string.lower(parent.Name) end
		for _, hint in ipairs({"shop", "dealer", "fruit", "stock", "mirage", "buy"}) do
			if string.find(path, hint, 1, true) then score = score + 2 end
		end
		for _, pin in ipairs(pinned) do
			if string.find(path, string.lower(pin), 1, true) then score = score + 100 end
		end
		ranked[#ranked + 1] = {frame = list, rows = rows, score = score}
	end
	table.sort(ranked, function(a, b) return a.score > b.score end)
	return ranked
end

function R.ScanShop(force)
	local now = Util.Now()
	if not force and R.shopRoot and R.shopRoot.Parent and (now - lastShopScan) < SHOP_RESCAN then
		return R.shopRoot
	end
	lastShopScan = now

	local ranked = bestList(Svc.VisibleTexts(), true)
	local top = ranked[1]
	if top and top.rows >= 2 then
		R.shopRoot = top.frame
		R.shopTier = top.score >= 100 and "confirmed" or "derived"
	else
		R.shopRoot = nil
		R.shopTier = "unknown"
	end
	return R.shopRoot
end

-- Shop frames that exist but are switched off. This is the one that
-- matters: a menu you have never opened is still in PlayerGui, hidden.
function R.FindHiddenShops()
	local ranked = bestList(Svc.AllTexts(), false)
	local out = {}
	for _, entry in ipairs(ranked) do
		if entry.rows >= 2 and not Svc.ChainVisible(entry.frame) then
			out[#out + 1] = entry
		end
	end
	return out
end

-- Everything we switched on, so unload puts it back.
R.revealed = {}

local function remember(inst, key, value)
	R.revealed[#R.revealed + 1] = {inst = inst, key = key, old = value}
end

function R.RevealShop(frame)
	if not frame then return false, "nothing to reveal" end
	local node = frame
	local hops = 0
	while node and hops < 24 do
		if node:IsA("ScreenGui") then
			if node.Enabled ~= true then
				remember(node, "Enabled", node.Enabled)
				pcall(function() node.Enabled = true end)
			end
			break
		end
		if node:IsA("GuiObject") and node.Visible ~= true then
			remember(node, "Visible", node.Visible)
			pcall(function() node.Visible = true end)
		end
		node = node.Parent
		hops = hops + 1
	end
	if frame:IsA("GuiObject") and frame.Visible ~= true then
		remember(frame, "Visible", frame.Visible)
		pcall(function() frame.Visible = true end)
	end
	R.shopRoot = frame
	R.shopTier = "revealed"
	lastShopScan = 0
	return true, frame.Name
end

function R.RestoreReveals()
	for i = #R.revealed, 1, -1 do
		local entry = R.revealed[i]
		if entry.inst and entry.inst.Parent then
			pcall(function() entry.inst[entry.key] = entry.old end)
		end
	end
	R.revealed = {}
end

function R.ShopOpen()
	local root = R.ScanShop(false)
	return root ~= nil and Svc.ChainVisible(root)
end

function R.PinShop(gui)
	if gui and gui:IsA("GuiObject") then
		R.shopRoot = gui
		R.shopTier = "confirmed"
		Cfg.target.shopGuiNames = gui.Name
		return true
	end
	return false
end

-- ── currency ─────────────────────────────────────────────────────────
function R.CurrencyValue()
	local stats = Svc.Leaderstats()
	if not stats then return nil, "no leaderstats" end
	local wanted = Util.Trim(Cfg.target.currencyStat)
	if wanted ~= "" then
		local v = stats:FindFirstChild(wanted)
		if v and type(v.Value) == "number" then return v.Value, wanted end
		return nil, "no leaderstat named " .. wanted
	end
	local best, bestName = nil, nil
	for _, child in ipairs(stats:GetChildren()) do
		local ok, value = pcall(function() return child.Value end)
		if ok and type(value) == "number" then
			if best == nil or value > best then best, bestName = value, child.Name end
		end
	end
	if best == nil then return nil, "no numeric leaderstat" end
	return best, bestName
end

-- ── remotes ──────────────────────────────────────────────────────────
function R.IndexRemotes()
	local out = {}
	local roots = {Svc.ReplicatedStorage, Svc.Workspace}
	local rf = game:FindFirstChild("ReplicatedFirst")
	if rf then roots[#roots + 1] = rf end
	for _, root in ipairs(roots) do
		local ok, desc = pcall(function() return root:GetDescendants() end)
		if ok then
			for _, d in ipairs(desc) do
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
	R.IndexRemotes()
	for _, rem in ipairs(R.remoteIndex) do
		if rem.Name == name then return rem end
	end
	return nil
end

-- ── namecall spy, the learner's input ────────────────────────────────
R.spyOn = false
R.spyLog = {}
R.spyEvents = {}
R.SPY_MAX = 60
R.SPY_EVENTS_MAX = 120
local hookInstalled = false
local oldNamecall = nil

local function summarise(value)
	local t = typeof(value)
	if t == "Instance" then return value.ClassName .. "(" .. value.Name .. ")" end
	if t == "Vector3" then return string.format("V3(%.1f,%.1f,%.1f)", value.X, value.Y, value.Z) end
	if t == "number" then return string.format("%.3f", value) end
	if t == "boolean" then return tostring(value) end
	if t == "string" then
		if #value > 28 then return '"' .. string.sub(value, 1, 28) .. '..."' end
		return '"' .. value .. '"'
	end
	if t == "table" then return "table" end
	return t
end

local function record(name, method, args)
	local parts, types = {}, {}
	local firstString, firstNumber = nil, nil
	for i = 1, args.n or #args do
		local v = args[i]
		parts[#parts + 1] = summarise(v)
		local t = typeof(v)
		types[#types + 1] = t
		if t == "string" and firstString == nil then firstString = v end
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
		str = firstString,
		num = firstNumber,
		text = line,
	})
	while #R.spyEvents > R.SPY_EVENTS_MAX do table.remove(R.spyEvents) end
end

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
				if R.spyOn and R.IsRemoteCall(self, method) and not R.SelfCall() then
					local args = table.pack(...)
					pcall(record, self.Name, method, args)
				end
				return oldNamecall(self, ...)
			end)
		else
			local mt = Env.getrawmetatable(game)
			Env.setreadonly(mt, false)
			oldNamecall = mt.__namecall
			mt.__namecall = function(self, ...)
				local method = Env.getnamecallmethod and Env.getnamecallmethod() or ""
				if R.spyOn and R.IsRemoteCall(self, method) and not R.SelfCall() then
					local args = table.pack(...)
					pcall(record, self.Name, method, args)
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

function R.RecentSends(seconds)
	local cutoff = Util.Now() - (seconds or 0.6)
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

-- What is actually there, in lines. Turns "it does not work" into data.
function R.ScanReport()
	local lines = {}
	local d = R.ScanDealer(true)
	if d then
		local prompts, clicks, touch = R.DealerParts(d)
		lines[#lines + 1] = string.format("dealer: %s  prompts %d  clicks %d  parts %d",
			d.Name, prompts, clicks, touch)
	else
		lines[#lines + 1] = "dealer: none scored above the floor"
	end

	local visible = R.ScanShop(true)
	lines[#lines + 1] = "visible shop frame: " .. (visible and visible.Name or "none")

	local hidden = R.FindHiddenShops()
	if #hidden == 0 then
		lines[#lines + 1] = "hidden shop frames: none"
	else
		for i = 1, math.min(#hidden, 3) do
			lines[#lines + 1] = string.format("hidden #%d: %s  (%d rows)",
				i, hidden[i].frame.Name, hidden[i].rows)
		end
	end

	lines[#lines + 1] = string.format("executor: prompt %s  click %s  touch %s  conns %s",
		Env.fireproximity and "y" or "n",
		Env.fireclickdetector and "y" or "n",
		Env.canTouch and "y" or "n",
		Env.getconnections and "y" or "n")
	return lines
end

function R.Status()
	local money, statName = R.CurrencyValue()
	return {
		dealer   = R.dealer and (R.dealer.Name .. " [" .. R.dealerTier .. "]") or "not found",
		shop     = R.shopRoot and (R.shopRoot.Name .. " [" .. R.shopTier .. "]") or "not open",
		remotes  = #R.remoteIndex,
		hook     = hookInstalled and "installed" or "none",
		currency = money and (statName .. " " .. tostring(math.floor(money))) or (statName or "unknown"),
	}
end

return R
end

-- ===== stock  (src/11_stock.lua) =====
__src["stock"] = function(_R)
-- @module stock
-- Reads what the dealer is selling right now and tells you when it
-- changes. Two readers, tried in order: the stock RemoteFunction when one
-- has been learned, otherwise the open shop GUI. Prices are parsed, never
-- assumed.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local R      = _R("resolve")
local Notify = _R("notify")

local S = {}

S.entries   = {}         -- {name, beli, robux, qty, slot, button, container}
S.source    = "none"     -- remote | gui | none
S.dealerKind= "unknown"  -- mirage | normal | unknown
S.lastRead  = 0
S.hash      = ""
S.lastChange= 0
S.changes   = 0
S.onRestock = nil        -- set by the buy engine
S.onRead    = nil        -- fired after every good read, restock or not

local accum = 0

-- ── price parsing ────────────────────────────────────────────────────
-- "$1,200,000"  "1.2M"  "3,400,000 Beli"  "R$ 2,200"  "12.5k"
function S.ParsePrice(text)
	if type(text) ~= "string" then return nil, nil end
	local lower = string.lower(text)
	local currency = "beli"
	if string.find(lower, "r%$") or string.find(lower, "robux", 1, true) then
		currency = "robux"
	end

	local body = string.gsub(lower, "r%$", " ")
	body = string.gsub(body, "robux", " ")
	body = string.gsub(body, "beli", " ")
	body = string.gsub(body, "[%$,%s]", "")

	local number, suffix = string.match(body, "([%d%.]+)([kmb]?)")
	if not number then return nil, nil end
	local value = tonumber(number)
	if value == nil then return nil, nil end

	if suffix == "k" then value = value * 1e3
	elseif suffix == "m" then value = value * 1e6
	elseif suffix == "b" then value = value * 1e9 end

	return value, currency
end

function S.Format(value)
	if type(value) ~= "number" or value <= 0 then return "-" end
	if value >= 1e9 then return string.format("%.2fB", value / 1e9) end
	if value >= 1e6 then return string.format("%.2fM", value / 1e6) end
	if value >= 1e3 then return string.format("%.1fK", value / 1e3) end
	return string.format("%d", math.floor(value))
end

-- ── GUI reader ───────────────────────────────────────────────────────
local function buttonIn(container)
	if container:IsA("TextButton") or container:IsA("ImageButton") then return container end
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("TextButton") or d:IsA("ImageButton") then
			local ok, visible = pcall(function() return d.Visible end)
			if ok and visible then return d end
		end
	end
	local parent = container.Parent
	if parent and (parent:IsA("TextButton") or parent:IsA("ImageButton")) then return parent end
	return nil
end

function S.ReadFromGui()
	local root = R.ScanShop(false)
	if not root or not Svc.ChainVisible(root) then return nil, "shop not open" end

	local rows = {}
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible then
			local name, beli, robux, qty = nil, nil, nil, nil
			for _, d in ipairs(child:GetDescendants()) do
				if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible then
					local text = Util.Trim(d.Text)
					if R.LooksLikePrice(text) then
						local value, currency = S.ParsePrice(text)
						if value then
							if currency == "robux" then
								if robux == nil or value > robux then robux = value end
							else
								if beli == nil or value > beli then beli = value end
							end
						end
						local stockNum = string.match(string.lower(text), "x%s*(%d+)")
						if stockNum then qty = tonumber(stockNum) end
					elseif name == nil and R.LooksLikeName(text) then
						name = text
					end
				end
			end
			if name and (beli or robux) then
				rows[#rows + 1] = {
					name = name,
					beli = beli or 0,
					robux = robux or 0,
					qty = qty or 1,
					container = child,
					button = buttonIn(child),
					y = child.AbsolutePosition.Y,
					order = child.LayoutOrder or 0,
				}
			end
		end
	end

	table.sort(rows, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		return a.y < b.y
	end)
	for i, row in ipairs(rows) do row.slot = i end

	if #rows == 0 then return nil, "shop open but no priced rows read" end
	return rows, "gui"
end

-- ── remote reader ────────────────────────────────────────────────────
local NAME_KEYS  = {"Name", "name", "Fruit", "fruit", "Item", "item", "Type", "type", "Id", "id"}
local BELI_KEYS  = {"Price", "price", "Cost", "cost", "Beli", "beli", "Money", "money", "Value", "value"}
local ROBUX_KEYS = {"Robux", "robux", "RobuxPrice", "robuxPrice", "Premium", "premium"}
local QTY_KEYS   = {"Stock", "stock", "Amount", "amount", "Count", "count", "Quantity", "quantity"}

local function pick(record, keys, kind)
	for _, k in ipairs(keys) do
		local v = record[k]
		if v ~= nil and type(v) == kind then return v end
	end
	return nil
end

-- Walk whatever the remote returned and keep anything shaped like a
-- stock line. Works on an array of records and on a name -> price map.
function S.NormaliseRemote(payload)
	local rows = {}
	if type(payload) ~= "table" then return rows end

	for key, value in pairs(payload) do
		if type(value) == "table" then
			local name = pick(value, NAME_KEYS, "string")
			if name == nil and type(key) == "string" then name = key end
			local beli = pick(value, BELI_KEYS, "number")
			local robux = pick(value, ROBUX_KEYS, "number")
			local qty = pick(value, QTY_KEYS, "number")
			if name and (beli or robux) then
				rows[#rows + 1] = {
					name = name, beli = beli or 0, robux = robux or 0,
					qty = qty or 1, container = nil, button = nil, order = 0,
				}
			end
		elseif type(value) == "number" and type(key) == "string" then
			rows[#rows + 1] = {
				name = key, beli = value, robux = 0, qty = 1,
				container = nil, button = nil, order = 0,
			}
		elseif type(value) == "string" and type(key) == "number" then
			rows[#rows + 1] = {
				name = value, beli = 0, robux = 0, qty = 1,
				container = nil, button = nil, order = 0,
			}
		end
	end

	table.sort(rows, function(a, b) return a.name < b.name end)
	for i, row in ipairs(rows) do row.slot = i end
	return rows
end

function S.ReadFromRemote()
	local name = Util.Trim(Cfg.target.stockRemote)
	if name == "" then return nil, "no stock remote set" end
	local rem = R.FindRemote(name)
	if not rem then return nil, "remote '" .. name .. "' not in this place" end

	local ok, payload = pcall(function()
		if rem:IsA("RemoteFunction") then return rem:InvokeServer() end
		return nil
	end)
	if not ok or payload == nil then return nil, "remote returned nothing" end

	local rows = S.NormaliseRemote(payload)
	if #rows == 0 then return nil, "remote payload had no priced rows" end
	return rows, "remote"
end

-- ── classify ─────────────────────────────────────────────────────────
-- Public guides say the Mirage dealer carries seven fruits and the normal
-- dealer three. That is a third-party claim, not something read from this
-- build, so it is only used when the names give nothing.
function S.Classify(rows)
	local hintSource = ""
	if R.shopRoot then hintSource = hintSource .. " " .. R.shopRoot.Name end
	if R.dealer then hintSource = hintSource .. " " .. R.dealer.Name end
	local lower = string.lower(hintSource)
	if string.find(lower, "mirage", 1, true) or string.find(lower, "advanc", 1, true) then
		return "mirage"
	end
	if string.find(lower, "normal", 1, true) or string.find(lower, "regular", 1, true) then
		return "normal"
	end
	if #rows >= 5 then return "mirage" end
	if #rows > 0 and #rows <= 4 then return "normal" end
	return "unknown"
end

-- ── read + diff ──────────────────────────────────────────────────────
local function hashOf(rows)
	local names = {}
	for _, row in ipairs(rows) do names[#names + 1] = string.lower(row.name) end
	table.sort(names)
	return table.concat(names, "|")
end

function S.Read(force)
	local rows, source = S.ReadFromRemote()
	if not rows then
		rows, source = S.ReadFromGui()
	end
	if not rows then
		-- keep the last good read rather than blanking the list while the
		-- shop is shut; say so through source
		S.source = "none"
		return false, source
	end

	S.entries = rows
	S.source = source
	S.dealerKind = S.Classify(rows)
	S.lastRead = Util.Now()

	local newHash = hashOf(rows)
	if newHash ~= S.hash then
		local first = (S.hash == "")
		S.hash = newHash
		S.lastChange = S.lastRead
		S.changes = S.changes + 1
		if not first then
			if Cfg.s.stock.notifyRestock then
				Notify.Info("restock", #rows .. " in stock: " .. S.NameLine())
			end
		end
		if S.onRestock then pcall(S.onRestock, rows, first) end
	end

	-- every read, not just a changed one: a watched fruit can be sitting
	-- there already when the tool is armed
	if S.onRead then pcall(S.onRead, rows) end
	return true, source
end

function S.Rate()
	-- armed means the gap between the fruit landing and the buy going out
	-- is what matters, so the poll tightens on its own
	if Cfg.s.auto.enabled then
		return math.max(Cfg.s.auto.pollFast, 0.05)
	end
	return math.max(Cfg.s.stock.refreshRate, 0.25)
end

function S.Step(dt, now)
	if not Cfg.s.stock.autoRefresh then return end
	accum = accum + dt
	if accum < S.Rate() then return end
	accum = 0
	S.Read(false)
end

function S.Find(name)
	if type(name) ~= "string" then return nil end
	local wanted = string.lower(Util.Trim(name))
	for _, row in ipairs(S.entries) do
		if string.lower(row.name) == wanted then return row end
	end
	for _, row in ipairs(S.entries) do
		if string.find(string.lower(row.name), wanted, 1, true) then return row end
	end
	return nil
end

function S.NameLine()
	local names = {}
	for _, row in ipairs(S.entries) do names[#names + 1] = row.name end
	if #names == 0 then return "nothing read" end
	return table.concat(names, ", ")
end

function S.Age()
	if S.lastRead == 0 then return -1 end
	return Util.Now() - S.lastRead
end

function S.StatusLine()
	if #S.entries == 0 then
		return "no stock read yet", "bad"
	end
	return string.format("%d items | %s dealer | via %s | %.0fs ago",
		#S.entries, S.dealerKind, S.source, S.Age()), "good"
end

return S
end

-- ===== catalog  (src/12_catalog.lua) =====
__src["catalog"] = function(_R)
-- @module catalog
-- The fruit list is learned, never shipped. Names come from stock reads
-- and from anything you type into the picker, and they persist with the
-- config file. No ModuleScript in the place is required: requiring an
-- unknown module runs its code, and that is not worth a name list.
local Cfg    = _R("cfg")
local Util   = _R("util")
local Notify = _R("notify")

local C = {}

function C.Has(name)
	local wanted = string.lower(Util.Trim(name or ""))
	if wanted == "" then return false end
	for _, n in ipairs(Cfg.catalog) do
		if string.lower(n) == wanted then return true end
	end
	return false
end

function C.Add(name)
	local clean = Util.Trim(name or "")
	if clean == "" then return false end
	if C.Has(clean) then return false end
	table.insert(Cfg.catalog, clean)
	table.sort(Cfg.catalog, function(a, b) return string.lower(a) < string.lower(b) end)
	return true
end

function C.Remove(name)
	local wanted = string.lower(Util.Trim(name or ""))
	for i, n in ipairs(Cfg.catalog) do
		if string.lower(n) == wanted then
			table.remove(Cfg.catalog, i)
			return true
		end
	end
	return false
end

-- Harvest every name out of a stock read.
function C.Harvest(rows)
	local added = 0
	for _, row in ipairs(rows or {}) do
		if C.Add(row.name) then added = added + 1 end
	end
	return added
end

function C.Count() return #Cfg.catalog end

-- Names matching a filter, watched ones first so the picker reads well.
function C.Filtered(query)
	local q = string.lower(Util.Trim(query or ""))
	local watched, rest = {}, {}
	for _, n in ipairs(Cfg.catalog) do
		if q == "" or string.find(string.lower(n), q, 1, true) then
			if Cfg.Watching(n) then watched[#watched + 1] = n else rest[#rest + 1] = n end
		end
	end
	local out = {}
	for _, n in ipairs(watched) do out[#out + 1] = n end
	for _, n in ipairs(rest) do out[#out + 1] = n end
	return out
end

function C.Clear()
	Cfg.catalog = {}
	Notify.Info("catalog", "cleared")
end

return C
end

-- ===== learn  (src/13_learn.lua) =====
__src["learn"] = function(_R)
-- @module learn
-- Finds the purchase remote instead of being told it, and names which
-- part of the chain is dead when nothing buys.
--
-- Buying is Watch-only on purpose. Probing an unknown RemoteEvent to see
-- whether it buys something would spend your Beli or your Robux to find
-- out, so the prober only touches RemoteFunctions that read stock.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local Env    = _R("env")
local R      = _R("resolve")
local S      = _R("stock")
local Notify = _R("notify")

local L = {}

L.state     = "idle"       -- idle | watching | probing
L.result    = "not run"
L.signature = ""
L.stockResult = "not run"

L.WATCH_LIMIT  = 60        -- seconds before the watch gives up
L.MATCH_WINDOW = 1.2       -- seconds of spy log to look back through
L.MIN_DROP     = 1         -- currency units that count as a purchase

local watchStart = 0
local lastMoney = nil
local lastShopOpen = false
local stepOpen           -- defined below, declared here so L.Step binds it

-- ── shape inference ──────────────────────────────────────────────────
function L.ShapeOf(ev)
	local t = ev.types or {}
	local first, second = t[1], t[2]
	if first == "string" then
		if second == "string" then return "name_cur", "string + string" end
		return "name", "string"
	end
	if first == "number" then
		if second == "string" then return "slot_cur", "number + string" end
		return "slot", "number"
	end
	if ev.argc == 0 then return "bare", "no arguments" end
	for i = 1, #t do
		if t[i] == "string" then return "", "string at arg " .. i .. ", map it by hand" end
		if t[i] == "number" then return "", "number at arg " .. i .. ", map it by hand" end
	end
	return "", table.concat(t, ", ")
end

local function scoreEvent(ev, boughtName)
	local score = 0
	local lower = string.lower(ev.name)
	for _, hint in ipairs({"buy", "purchase", "shop", "dealer", "fruit", "stock", "trade"}) do
		if string.find(lower, hint, 1, true) then score = score + 30 end
	end
	if ev.str ~= nil then score = score + 20 end
	if ev.num ~= nil then score = score + 10 end
	-- the strongest signal: an argument that is the fruit we just bought
	if boughtName and ev.str and string.lower(ev.str) == string.lower(boughtName) then
		score = score + 200
	end
	return score
end

-- ── watch ────────────────────────────────────────────────────────────
function L.ArmBuy()
	if L.state ~= "idle" then
		Notify.Warn("learn", "already running")
		return false
	end
	if not R.InstallHook() then
		L.result = "executor cannot hook namecall"
		Notify.Bad("learn", "this executor cannot hook namecall, so the purchase cannot be seen. Type the remote name in by hand.")
		return false
	end
	local money = R.CurrencyValue()
	if money == nil then
		L.result = "no readable currency"
		Notify.Warn("learn", "no numeric leaderstat to watch. Set the currency stat on this tab.")
		return false
	end

	R.spyOn = true
	R.ClearSpy()
	lastMoney = money
	watchStart = Util.Now()
	L.state = "watching"
	L.result = "watching, buy one fruit by hand"
	Notify.Info("learn", "armed. buy one fruit from the dealer yourself.")
	return true
end

function L.Disarm(reason)
	L.state = "idle"
	R.spyOn = false
	if reason then L.result = reason end
end

-- Which stock line costs about what was just spent.
local function fruitForDrop(drop)
	local best, bestDelta = nil, math.huge
	for _, row in ipairs(S.entries) do
		if row.beli > 0 then
			local delta = math.abs(row.beli - drop)
			if delta < bestDelta then best, bestDelta = row, delta end
		end
	end
	if best and bestDelta <= math.max(drop * 0.02, 1) then return best end
	return nil
end

local function adopt(ev, boughtRow)
	local shape, signature = L.ShapeOf(ev)
	Cfg.target.buyRemote = ev.name
	Cfg.target.buySource = "watch"
	L.signature = signature

	if shape ~= "" then
		Cfg.target.buyArgShape = shape
		-- the second argument of a *_cur shape is the token this build
		-- uses for the currency that was actually spent
		if (shape == "name_cur" or shape == "slot_cur") and ev.types[2] == "string" then
			local token = nil
			local args = ev.text
			token = string.match(args, '",%s*"([^"]+)"%)')
			if token then Cfg.target.buyBeliToken = token end
		end
		L.result = ev.name .. "  [" .. shape .. "]"
		local extra = boughtRow and ("  bought " .. boughtRow.name) or ""
		Notify.Good("learn", ev.name .. " taking " .. signature .. extra)
	else
		Cfg.target.buyArgShape = ""
		L.result = ev.name .. "  shape unclear: " .. signature
		Notify.Warn("learn", ev.name .. " found, but its arguments are " .. signature)
	end
end

function L.Step(dt, now)
	if L.state == "opening" then
		stepOpen(now)
		return
	end
	if L.state ~= "watching" then return end

	if now - watchStart > L.WATCH_LIMIT then
		L.Disarm("nothing seen in " .. L.WATCH_LIMIT .. "s")
		Notify.Warn("learn", "no purchase seen. Arm it again and buy one fruit while it runs.")
		return
	end

	local money = R.CurrencyValue()
	if money == nil then return end
	if lastMoney == nil then lastMoney = money return end

	local drop = lastMoney - money
	lastMoney = money
	if drop < L.MIN_DROP then return end

	local row = fruitForDrop(drop)
	local sends = R.RecentSends(L.MATCH_WINDOW)
	if #sends == 0 then
		L.Disarm("spend seen with no remote send behind it")
		Notify.Warn("learn",
			"you spent " .. S.Format(drop) .. " with no remote send in the window. The buy button path is the one to use.")
		return
	end

	local best, bestScore = nil, -1
	for _, ev in ipairs(sends) do
		local sc = scoreEvent(ev, row and row.name or nil)
		if sc > bestScore then best, bestScore = ev, sc end
	end
	adopt(best, row)
	L.Disarm()
end

-- ── watch the open ───────────────────────────────────────────────────
-- Some builds open the dealer menu off a remote rather than a prompt.
-- Arm this, open the shop by hand once, and the call that did it is kept
-- so the opener can replay it.
function L.ArmOpen()
	if L.state ~= "idle" then
		Notify.Warn("learn", "already running")
		return false
	end
	if not R.InstallHook() then
		L.result = "executor cannot hook namecall"
		Notify.Bad("learn", "this executor cannot hook namecall, so the open cannot be seen.")
		return false
	end
	R.spyOn = true
	R.ClearSpy()
	lastShopOpen = R.ShopOpen()
	watchStart = Util.Now()
	L.state = "opening"
	L.result = "watching, open the dealer menu by hand"
	Notify.Info("learn", "armed. open the dealer's menu yourself.")
	return true
end

local function adoptOpen(ev)
	Cfg.target.openRemote = ev.name
	local shape = "bare"
	local dealer = R.dealer
	if ev.str and dealer and string.lower(ev.str) == string.lower(dealer.Name) then
		shape = "dealer"
	end
	Cfg.target.openArgShape = shape
	L.result = "open: " .. ev.name .. " [" .. shape .. "]"
	Notify.Good("learn", "the menu opens off " .. ev.name)
end

stepOpen = function(now)
	if now - watchStart > L.WATCH_LIMIT then
		L.Disarm("no open seen in " .. L.WATCH_LIMIT .. "s")
		Notify.Warn("learn", "no open seen. If the menu never came up, nothing was there to capture.")
		return
	end

	local open = R.ShopOpen()
	if open and not lastShopOpen then
		local sends = R.RecentSends(L.MATCH_WINDOW)
		if #sends == 0 then
			L.Disarm("menu opened with no remote behind it")
			Notify.Info("learn",
				"the menu opened with no remote send behind it, so it is pure client side. Reveal is the path, and it is already on.")
			return
		end
		local best, bestScore = nil, -1
		for _, ev in ipairs(sends) do
			local sc = 0
			local lower = string.lower(ev.name)
			for _, hint in ipairs({"shop", "dealer", "open", "ui", "menu", "fruit", "stock"}) do
				if string.find(lower, hint, 1, true) then sc = sc + 25 end
			end
			if ev.str ~= nil then sc = sc + 10 end
			if sc > bestScore then best, bestScore = ev, sc end
		end
		adoptOpen(best)
		L.Disarm()
		return
	end
	lastShopOpen = open
end

-- ── stock remote prober ──────────────────────────────────────────────
-- RemoteFunctions only, and only ones named like a read. Invoking a read
-- is cheap; firing an unknown event is not, so this never does that.
function L.ProbeStock()
	if L.state ~= "idle" then return false end
	R.IndexRemotes()

	local tried, found = 0, nil
	for _, rem in ipairs(R.remoteIndex) do
		if rem:IsA("RemoteFunction") then
			local lower = string.lower(rem.Name)
			local looksRead = string.find(lower, "stock", 1, true)
				or string.find(lower, "shop", 1, true)
				or string.find(lower, "get", 1, true)
				or string.find(lower, "dealer", 1, true)
				or string.find(lower, "fruit", 1, true)
			if looksRead and tried < 14 then
				tried = tried + 1
				local ok, payload = pcall(function() return rem:InvokeServer() end)
				if ok and type(payload) == "table" then
					local rows = S.NormaliseRemote(payload)
					if #rows >= 2 then
						found = rem.Name
						break
					end
				end
			end
		end
	end

	if found then
		Cfg.target.stockRemote = found
		L.stockResult = found .. " returns parseable stock"
		Notify.Good("probe", L.stockResult)
		return true
	end
	L.stockResult = "no read remote returned stock (" .. tried .. " tried)"
	Notify.Warn("probe", L.stockResult .. ". The GUI reader still works with the shop open.")
	return false
end

-- ── diagnosis ────────────────────────────────────────────────────────
function L.Diagnose()
	local rows = {}
	local dealer = R.ScanDealer(false)
	rows[#rows + 1] = {"dealer npc", dealer and (dealer.Name .. " [" .. R.dealerTier .. "]") or "not found", dealer ~= nil}

	local shopOpen = R.ShopOpen()
	rows[#rows + 1] = {"shop gui", shopOpen and (R.shopRoot.Name .. " open") or "not open", shopOpen}

	rows[#rows + 1] = {"stock read", #S.entries > 0 and (#S.entries .. " via " .. S.source) or "nothing read", #S.entries > 0}

	local buyPath, why = L.BuyPath()
	rows[#rows + 1] = {"buy path", buyPath or why, buyPath ~= nil}

	local money, statName = R.CurrencyValue()
	rows[#rows + 1] = {"currency", money and (statName .. " " .. S.Format(money)) or (statName or "unreadable"), money ~= nil}

	local verdict
	if not dealer and #S.entries == 0 then
		verdict = "no dealer and no stock. Get to Mirage Island, open the dealer, then press Read stock."
	elseif #S.entries == 0 then
		verdict = "dealer found but nothing read. Open its shop, then Read stock, or probe for a stock remote."
	elseif buyPath == nil then
		verdict = "stock reads fine, buying has no path: " .. why
	else
		verdict = "stock reads and buying goes through the " .. buyPath .. " path."
	end
	return rows, verdict
end

-- Which way a purchase can actually go right now.
function L.BuyPath()
	if Util.Trim(Cfg.target.buyRemote) ~= "" and Util.Trim(Cfg.target.buyArgShape) ~= "" then
		if R.FindRemote(Cfg.target.buyRemote) then return "remote", "" end
		return nil, "remote '" .. Cfg.target.buyRemote .. "' not in this place"
	end
	if Env.getconnections then
		for _, row in ipairs(S.entries) do
			if row.button then return "button", "" end
		end
		return nil, "no buy remote learned and no clickable row in the read"
	end
	return nil, "no buy remote learned and this executor has no getconnections"
end

function L.Status()
	if L.state == "watching" then return "watching for a purchase", "accent" end
	if L.state == "opening" then return "watching for the menu to open", "accent" end
	local good = Util.Trim(Cfg.target.buyRemote) ~= ""
	return L.result, good and "good" or "dim"
end

return L
end

-- ===== buy  (src/14_buy.lua) =====
__src["buy"] = function(_R)
-- @module buy
-- Beli only. Pick a fruit, and the instant the dealer is holding it the
-- purchase goes out on the same read that saw it.
--
-- Robux is deliberately not here. The shop button does not say which
-- currency it spends, so a tool that guessed would be spending real money
-- on a guess.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local Env    = _R("env")
local R      = _R("resolve")
local S      = _R("stock")
local L      = _R("learn")
local Notify = _R("notify")

local B = {}

B.log = {}
B.LOG_MAX = 40
B.lastResult = "idle"
B.boughtThisRestock = 0
B.lastAttempt = 0
B.lastAutoAttempt = -1e9
B.bought = {}            -- name -> clock, so one landing is not bought twice

local pending = nil      -- {name, tries, nextAt}
local REBUY_GUARD = 2.5  -- seconds before the same name may be bought again

local function logLine(name, price, how, ok)
	table.insert(B.log, 1, {t = Util.Stamp(), name = name, price = price, how = how, ok = ok})
	while #B.log > B.LOG_MAX do table.remove(B.log) end
end

function B.LogLines(count)
	local out = {}
	for i = 1, math.min(count or 6, #B.log) do
		local e = B.log[i]
		out[#out + 1] = string.format("%s %s  %s  via %s",
			e.ok and "ok " or "no ", e.name, S.Format(e.price), e.how)
	end
	return out
end

-- ── checks ───────────────────────────────────────────────────────────
function B.Affordable(row)
	local money = R.CurrencyValue()
	local price = row.beli or 0
	if price <= 0 then return true, "no beli price read on this row" end
	if money == nil then return true, "currency not readable, not blocking" end
	if money < price then return false, "short by " .. S.Format(price - money) end
	local budget = Cfg.s.auto.budget
	if budget > 0 and price > budget then return false, "over the budget cap" end
	return true, ""
end

-- ── execution paths ──────────────────────────────────────────────────
local function buyViaRemote(row)
	local name = Util.Trim(Cfg.target.buyRemote)
	local shape = Util.Trim(Cfg.target.buyArgShape)
	local rem = R.FindRemote(name)
	if not rem then return false, "remote missing" end

	local token = Util.Trim(Cfg.target.buyBeliToken)
	if (shape == "name_cur" or shape == "slot_cur") and token == "" then
		return false, "no beli token learned for this shape"
	end

	local ok, err = pcall(function()
		if shape == "name" then
			rem:FireServer(row.name)
		elseif shape == "name_cur" then
			rem:FireServer(row.name, token)
		elseif shape == "slot" then
			rem:FireServer(row.slot)
		elseif shape == "slot_cur" then
			rem:FireServer(row.slot, token)
		elseif shape == "bare" then
			rem:FireServer()
		else
			error("unsupported buyArgShape '" .. tostring(shape) .. "'")
		end
	end)
	if not ok then return false, tostring(err) end
	return true, "remote"
end

local function buyViaButton(row)
	if not row.button then return false, "row has no button" end
	if not Env.getconnections then return false, "no getconnections" end
	local fired = 0
	local ok = pcall(function()
		for _, conn in ipairs(Env.getconnections(row.button.MouseButton1Click)) do
			if conn.Fire then
				conn:Fire()
				fired = fired + 1
			elseif conn.Function then
				conn.Function()
				fired = fired + 1
			end
		end
	end)
	if not ok or fired == 0 then return false, "button had no live handler" end
	return true, "button"
end

-- ── the one call ─────────────────────────────────────────────────────
function B.Now(row)
	if row == nil then
		B.lastResult = "no such row in stock"
		return false, B.lastResult
	end

	local can, reason = B.Affordable(row)
	if not can then
		B.lastResult = row.name .. ": " .. reason
		Notify.Warn("buy", B.lastResult)
		logLine(row.name, row.beli or 0, "blocked", false)
		return false, reason
	end

	local before = R.CurrencyValue()
	local path, pathWhy = L.BuyPath()
	local ok, how = false, pathWhy

	if path == "remote" then
		ok, how = buyViaRemote(row)
		if not ok then
			local okB, howB = buyViaButton(row)
			if okB then ok, how = okB, howB end
		end
	elseif path == "button" then
		ok, how = buyViaButton(row)
	end

	B.lastAttempt = Util.Now()
	if not ok then
		B.lastResult = row.name .. ": " .. tostring(how)
		Notify.Bad("buy", B.lastResult)
		logLine(row.name, row.beli or 0, tostring(how), false)
		return false, how
	end

	B.bought[string.lower(row.name)] = Util.Now()
	logLine(row.name, row.beli or 0, how, true)
	B.lastResult = row.name .. " sent via " .. how
	Notify.Good("buy", B.lastResult)

	if before ~= nil then
		task.delay(1.0, function()
			local after = R.CurrencyValue()
			if after ~= nil and after < before then
				Notify.Good("buy", row.name .. " confirmed, " .. S.Format(before - after) .. " spent")
			end
		end)
	end
	return true, how
end

function B.NowByName(name)
	S.Read(false)
	local row = S.Find(name)
	if not row then
		B.lastResult = tostring(name) .. " is not in the stock right now"
		Notify.Warn("buy", B.lastResult)
		return false, B.lastResult
	end
	return B.Now(row)
end

-- ── instant path ─────────────────────────────────────────────────────
-- Called from the stock reader on every read, so the gap between the
-- fruit appearing and the purchase going out is one read, not one tick of
-- some slower loop.
local function recentlyBought(name)
	local when = B.bought[string.lower(name)]
	if when == nil then return false end
	return (Util.Now() - when) < REBUY_GUARD
end

function B.TryInstant(rows)
	local a = Cfg.s.auto
	if not a.enabled or not a.instant then return false end
	if #a.watchlist == 0 then return false end
	if a.maxPerRestock > 0 and B.boughtThisRestock >= a.maxPerRestock then return false end

	for _, name in ipairs(a.watchlist) do
		local row = S.Find(name)
		if row and not recentlyBought(row.name) then
			local can = B.Affordable(row)
			if can then
				local ok = B.Now(row)
				if ok then
					B.boughtThisRestock = B.boughtThisRestock + 1
					if a.stopAfterBuy then
						a.enabled = false
						Notify.Info("auto", "disarmed after the buy, as set")
					end
					return true
				end
				-- failed: hand it to the retry loop rather than hammering
				pending = {name = row.name, tries = 1, nextAt = Util.Now() + a.retryDelay}
				return false
			end
		end
	end
	return false
end

-- ── restock + retries ────────────────────────────────────────────────
function B.OnRestock(rows, first)
	B.boughtThisRestock = 0
	B.bought = {}
	if first then return end
	if not Cfg.s.stock.notifyWatched then return end
	for _, row in ipairs(rows) do
		if Cfg.Watching(row.name) then
			Notify.Good("watched", row.name .. " is in stock for " .. S.Format(row.beli))
		end
	end
end

function B.Step(dt, now)
	local a = Cfg.s.auto
	if not a.enabled then
		pending = nil
		return
	end
	if #a.watchlist == 0 then return end

	if pending then
		if now < pending.nextAt then return end
		local row = S.Find(pending.name)
		if not row then
			pending = nil
			return
		end
		if B.Now(row) then
			B.boughtThisRestock = B.boughtThisRestock + 1
			pending = nil
			if a.stopAfterBuy then
				a.enabled = false
				Notify.Info("auto", "disarmed after the buy, as set")
			end
		else
			pending.tries = pending.tries + 1
			if pending.tries >= a.retries then
				pending = nil
			else
				pending.nextAt = now + a.retryDelay
			end
		end
		return
	end

	-- the instant path covers the normal case; this is the backstop for
	-- when the reader is off and the list was filled some other way
	if a.instant then return end
	if a.maxPerRestock > 0 and B.boughtThisRestock >= a.maxPerRestock then return end
	if now - B.lastAutoAttempt < 0.4 then return end

	for _, name in ipairs(a.watchlist) do
		local row = S.Find(name)
		if row and not recentlyBought(row.name) then
			if B.Affordable(row) then
				B.lastAutoAttempt = now
				pending = {name = row.name, tries = 0, nextAt = now}
				return
			end
		end
	end
end

function B.ToggleAuto()
	Cfg.s.auto.enabled = not Cfg.s.auto.enabled
	local a = Cfg.s.auto
	if a.enabled and #a.watchlist == 0 then
		Notify.Warn("instant buy", "armed, but nothing is picked. PICK tab.")
	else
		Notify.Info("instant buy", a.enabled
			and ("armed on " .. table.concat(a.watchlist, ", "))
			or "off")
	end
	return a.enabled
end

function B.StatusLine()
	local a = Cfg.s.auto
	if not a.enabled then return "off", "dim" end
	if #a.watchlist == 0 then return "armed with nothing picked", "bad" end
	return string.format("armed on %s | poll %.2fs | %d bought this restock",
		table.concat(a.watchlist, ", "), S.Rate(), B.boughtThisRestock), "good"
end

return B
end

-- ===== headless  (src/15_headless.lua) =====
__src["headless"] = function(_R)
-- @module headless
-- Buying with no dealer menu, no NPC and no stock read.
--
-- The purchase is a remote call. The shop GUI is a middleman that makes
-- that call on your behalf, so when the menu will not open, the call
-- still can. This finds which remote does it by firing name-shaped
-- purchase calls and watching your Beli, then keeps firing that one.
--
-- Only the fruit NAME is ever passed, never a slot index. A wrong guess
-- can fail; it cannot buy a different fruit.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local Env    = _R("env")
local R      = _R("resolve")
local S      = _R("stock")
local Notify = _R("notify")

local D = {}

D.state      = "idle"      -- idle | sweeping | locked | bought | exhausted
D.found      = nil         -- {name = remote name, shape = string}
D.attempts   = 0
D.sweeps     = 0
D.lastLine   = "not run"
D.lastSpend  = 0
D.tried      = {}          -- name|shape -> true, so a sweep does not repeat itself

local lastAttempt = -1e9
local lastSweep = -1e9
local sweeping = false

local BUY_HINTS = {"buy", "purchase", "shop", "dealer", "fruit", "stock", "order"}
local CANDIDATE_CAP = 16
local SETTLE = 0.12        -- seconds to wait for the balance to move

-- Name-only shapes. No slot index, ever.
local SHAPES = {"name", "name_false", "name_one"}

local function fireShape(rem, shape, fruit, token)
	local ok = pcall(function()
		if shape == "name" then
			if rem:IsA("RemoteFunction") then rem:InvokeServer(fruit) else rem:FireServer(fruit) end
		elseif shape == "name_token" then
			if rem:IsA("RemoteFunction") then rem:InvokeServer(fruit, token) else rem:FireServer(fruit, token) end
		elseif shape == "name_false" then
			if rem:IsA("RemoteFunction") then rem:InvokeServer(fruit, false) else rem:FireServer(fruit, false) end
		elseif shape == "name_one" then
			if rem:IsA("RemoteFunction") then rem:InvokeServer(fruit, 1) else rem:FireServer(fruit, 1) end
		else
			error("unknown shape")
		end
	end)
	return ok
end

-- Candidate remotes, best guess first: anything already learned, then
-- anything named like a purchase.
function D.Candidates()
	local out, seen = {}, {}

	local learned = Util.Trim(Cfg.target.buyRemote)
	if learned ~= "" then
		local rem = R.FindRemote(learned)
		if rem then
			out[#out + 1] = rem
			seen[learned] = true
		end
	end

	R.IndexRemotes()
	local scored = {}
	for _, rem in ipairs(R.remoteIndex) do
		if not seen[rem.Name] then
			local lower = string.lower(rem.Name)
			local score = 0
			for _, h in ipairs(BUY_HINTS) do
				if string.find(lower, h, 1, true) then score = score + 10 end
			end
			if string.find(lower, "buy", 1, true) then score = score + 25 end
			if string.find(lower, "purchase", 1, true) then score = score + 25 end
			if score > 0 then
				scored[#scored + 1] = {rem = rem, score = score}
			end
		end
	end
	table.sort(scored, function(a, b) return a.score > b.score end)
	for _, entry in ipairs(scored) do
		if #out >= CANDIDATE_CAP then break end
		out[#out + 1] = entry.rem
	end
	return out
end

-- Did the balance move? That is the only honest confirmation we have.
local function balance()
	local v = R.CurrencyValue()
	return v
end

function D.Target()
	local name = Util.Trim(Cfg.s.direct.target)
	if name ~= "" then return name end
	local list = Cfg.s.auto.watchlist
	if #list > 0 then return list[1] end
	return ""
end

-- One fire of one known remote and shape. Returns bought, spent.
local function tryOnce(rem, shape, fruit, token)
	local before = balance()
	if not fireShape(rem, shape, fruit, token) then return false, 0 end
	task.wait(SETTLE)
	local after = balance()
	if before == nil or after == nil then return false, 0 end
	local spent = before - after
	if spent > 0 then return true, spent end
	return false, 0
end

local function lock(remName, shape, spent)
	D.found = {name = remName, shape = shape}
	D.state = "locked"
	Cfg.target.buyRemote = remName
	Cfg.target.buySource = "direct sweep"
	if shape == "name" then
		Cfg.target.buyArgShape = "name"
	elseif shape == "name_token" then
		Cfg.target.buyArgShape = "name_cur"
	end
	D.lastLine = string.format("%s [%s] spent %s", remName, shape, S.Format(spent))
	Notify.Good("direct", D.lastLine)
end

-- ── a full sweep ─────────────────────────────────────────────────────
function D.Sweep()
	if sweeping then return false end
	local fruit = D.Target()
	if fruit == "" then
		D.lastLine = "no target fruit set"
		Notify.Warn("direct", D.lastLine)
		return false
	end
	if balance() == nil then
		D.lastLine = "no readable balance, so a purchase cannot be confirmed"
		Notify.Bad("direct", D.lastLine)
		return false
	end

	sweeping = true
	D.state = "sweeping"
	D.sweeps = D.sweeps + 1

	task.spawn(function()
		local token = Util.Trim(Cfg.target.buyBeliToken)
		local candidates = D.Candidates()
		local fired = 0

		for _, rem in ipairs(candidates) do
			local shapes = {}
			if token ~= "" then shapes[#shapes + 1] = "name_token" end
			for _, sh in ipairs(SHAPES) do shapes[#shapes + 1] = sh end

			for _, shape in ipairs(shapes) do
				local key = rem.Name .. "|" .. shape
				if not D.tried[key] then
					D.tried[key] = true
					fired = fired + 1
					local bought, spent = tryOnce(rem, shape, fruit, token)
					D.attempts = D.attempts + 1
					if bought then
						D.lastSpend = spent
						lock(rem.Name, shape, spent)
						sweeping = false
						if Cfg.s.direct.stopOnBuy then
							Cfg.s.direct.enabled = false
							D.state = "bought"
							Notify.Good("direct", fruit .. " bought for " .. S.Format(spent))
						end
						return
					end
				end
			end
		end

		sweeping = false
		if fired == 0 then
			D.state = "exhausted"
			D.lastLine = "every candidate and shape already tried; reset to sweep again"
		else
			D.state = "idle"
			D.lastLine = string.format("sweep %d: %d calls, nothing was charged", D.sweeps, fired)
		end
		Notify.Info("direct", D.lastLine)
	end)
	return true
end

-- ── one attempt on the remote we already know ────────────────────────
function D.Attempt()
	local fruit = D.Target()
	if fruit == "" then return false end
	if not D.found then return D.Sweep() end

	local rem = R.FindRemote(D.found.name)
	if not rem then
		D.found = nil
		D.state = "idle"
		D.lastLine = "the locked remote left the place"
		return false
	end

	task.spawn(function()
		local token = Util.Trim(Cfg.target.buyBeliToken)
		local bought, spent = tryOnce(rem, D.found.shape, fruit, token)
		D.attempts = D.attempts + 1
		if bought then
			D.lastSpend = spent
			D.lastLine = fruit .. " bought for " .. S.Format(spent)
			Notify.Good("direct", D.lastLine)
			if Cfg.s.direct.stopOnBuy then
				Cfg.s.direct.enabled = false
				D.state = "bought"
			end
		else
			D.lastLine = string.format("fired %s, nothing charged (attempt %d)", D.found.name, D.attempts)
		end
	end)
	return true
end

-- ── the loop ─────────────────────────────────────────────────────────
-- When a stock source exists it gates the fires, so nothing is sent until
-- the fruit is actually there. With no stock source it fires on a timer,
-- which is the whole point: no menu is needed either way.
function D.Gated()
	if not Cfg.s.direct.useStockGate then return false, "gate off" end
	if #S.entries == 0 then return false, "no stock source" end
	local fruit = D.Target()
	if S.Find(fruit) then return false, "in stock" end
	return true, "not in the read"
end

function D.Step(dt, now)
	local d = Cfg.s.direct
	if not d.enabled then return end
	if sweeping then return end
	if D.state == "bought" then return end

	local gated, why = D.Gated()
	if gated then
		D.lastLine = "waiting: " .. tostring(D.Target()) .. " " .. why
		return
	end

	if D.found then
		if now - lastAttempt < math.max(d.attemptDelay, 0.25) then return end
		lastAttempt = now
		D.Attempt()
		return
	end

	if d.maxSweeps > 0 and D.sweeps >= d.maxSweeps then
		D.state = "exhausted"
		return
	end
	if now - lastSweep < math.max(d.sweepDelay, 5) then return end
	lastSweep = now
	D.Sweep()
end

function D.Reset()
	D.tried = {}
	D.found = nil
	D.state = "idle"
	D.attempts = 0
	D.sweeps = 0
	D.lastLine = "reset"
	lastSweep = -1e9
	lastAttempt = -1e9
end

function D.Arm(name)
	if name and name ~= "" then Cfg.s.direct.target = name end
	Cfg.s.direct.enabled = true
	if D.state == "bought" then D.state = "idle" end
	Notify.Info("direct", "armed on " .. D.Target())
	return true
end

function D.StatusLine()
	local d = Cfg.s.direct
	if not d.enabled then return "off", "dim" end
	if D.state == "bought" then return D.Target() .. " bought", "good" end
	if D.found then
		return string.format("locked on %s [%s], %d attempts", D.found.name, D.found.shape, D.attempts), "good"
	end
	return string.format("hunting the buy remote, sweep %d, %d calls", D.sweeps, D.attempts), "accent"
end

function D.Report()
	local lines = {}
	lines[#lines + 1] = "target: " .. (D.Target() ~= "" and D.Target() or "none set")
	lines[#lines + 1] = "state: " .. D.state .. "  attempts " .. D.attempts .. "  sweeps " .. D.sweeps
	lines[#lines + 1] = D.found and ("locked: " .. D.found.name .. " [" .. D.found.shape .. "]") or "locked: nothing yet"
	lines[#lines + 1] = "candidates: " .. #D.Candidates() .. " remotes named like a purchase"
	local money = R.CurrencyValue()
	lines[#lines + 1] = "balance: " .. (money and S.Format(money) or "unreadable, cannot confirm a buy")
	lines[#lines + 1] = D.lastLine
	return lines
end

return D
end

-- ===== island  (src/16_island.lua) =====
__src["island"] = function(_R)
-- @module island
-- Mirage Island is the thing worth hopping for. The stock itself is the
-- same on every server, so hopping never changes what is for sale: it
-- only finds a server where the island, and therefore the dealer, exists.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local R      = _R("resolve")
local Notify = _R("notify")

local I = {}

I.lastCheck = 0
I.present = false
I.model = nil
I.tier = "unknown"
I.hopAttempts = 0
I.Hopper = nil          -- set by session so island can ask for a hop

local accum = 0

local ISLAND_HINTS = {"mirage", "illusion", "mystic"}

-- The dealer's own presence is the strongest signal the island is here,
-- so the model scan is a bonus rather than the test.
function I.ScanModel()
	local pinned = Cfg.List(Cfg.target.islandNames)
	local radius = math.max(Cfg.s.island.scanRadius, 100)
	local hrp = Svc.HRP()
	local origin = hrp and hrp.Position or Vector3.new(0, 0, 0)

	for _, d in ipairs(Svc.Workspace:GetChildren()) do
		local lower = string.lower(d.Name)
		local hit = false
		for _, h in ipairs(ISLAND_HINTS) do
			if string.find(lower, h, 1, true) then hit = true end
		end
		for _, pin in ipairs(pinned) do
			if string.find(lower, string.lower(pin), 1, true) then hit = true end
		end
		if hit then
			local pos = d:IsA("Model") and Svc.ModelPos(d) or (d:IsA("BasePart") and d.Position or nil)
			if pos and (pos - origin).Magnitude <= radius * 4 then
				return d, pos
			end
		end
	end
	return nil, nil
end

function I.Check(force)
	local now = Util.Now()
	if not force and (now - I.lastCheck) < 2 then return I.present end
	I.lastCheck = now

	local dealer = R.ScanDealer(force)
	local model, pos = I.ScanModel()

	I.model = model
	if dealer then
		I.present = true
		I.tier = "dealer found"
	elseif model then
		I.present = true
		I.tier = "island model found"
	else
		I.present = false
		I.tier = "nothing found"
	end
	return I.present
end

function I.Step(dt, now)
	local s = Cfg.s.island
	if not s.autoFind and not s.hopUntilFound then return end

	accum = accum + dt
	if accum < 2 then return end
	accum = 0

	local here = I.Check(false)

	if here then
		I.hopAttempts = 0
		return
	end

	if s.hopUntilFound and I.Hopper then
		if now - (I.lastHop or 0) < s.hopDelay then return end
		I.lastHop = now
		I.hopAttempts = I.hopAttempts + 1
		Notify.Info("island", "not here, hopping (" .. I.hopAttempts .. ")")
		pcall(I.Hopper)
	end
end

function I.StatusLine()
	if I.present then
		return I.tier, "good"
	end
	return "not in this server", "bad"
end

return I
end

-- ===== session  (src/17_session.lua) =====
__src["session"] = function(_R)
-- @module session
-- Idle defeat, server selection, rejoin, panic.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local Env    = _R("env")
local Notify = _R("notify")

local ST = {}

local maid = Util.Maid.new()
local afkConn = nil
ST.PanicHook = nil
ST.hopping = false
ST.lastServerList = {}

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

function ST.FetchServers(pages)
	if not Env.canHttp then
		Notify.Once("hop_nohttp", "servers",
			"this executor exposes no http client, so the server list cannot be read.", "warn")
		return {}
	end
	local placeId = game.PlaceId
	local collected, cursor = {}, ""
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
		if srv.id ~= here and (srv.maxPlayers - srv.playing) >= 1 then
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

function ST.QueueReexec()
	if not Env.queueteleport then return false end
	local g = Util.Genv()
	local src = nil
	if type(g.MS_URL) == "string" and g.MS_URL ~= "" then
		src = 'loadstring(game:HttpGet("' .. g.MS_URL .. '"))()'
	elseif type(g.MS_SOURCE) == "string" and g.MS_SOURCE ~= "" then
		src = g.MS_SOURCE
	end
	if not src then return false end
	return (pcall(function() Env.queueteleport(src) end))
end

function ST.Hop()
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
			if srv.ping <= Cfg.s.island.hopMaxPing then pick = srv break end
		end
		if not pick then pick = list[1] end
		ST.QueueReexec()
		local ok = pcall(function()
			Svc.TeleportService:TeleportToPlaceInstance(game.PlaceId, pick.id, Svc.LP)
		end)
		if not ok then
			Notify.Bad("hop", "teleport refused")
			ST.hopping = false
		end
	end)
	return true
end

function ST.Rejoin()
	Notify.Info("rejoin", "teleporting back into this place")
	ST.QueueReexec()
	local ok = pcall(function() Svc.TeleportService:Teleport(game.PlaceId, Svc.LP) end)
	if not ok then Notify.Bad("rejoin", "teleport refused") end
	return ok
end

function ST.Panic()
	if ST.PanicHook then
		pcall(ST.PanicHook)
		return true
	end
	return false
end

function ST.Destroy()
	maid:Clean()
	if afkConn then afkConn:Disconnect() afkConn = nil end
end

return ST
end

-- ===== menu  (src/18_menu.lua) =====
__src["menu"] = function(_R)
-- @module menu
-- Five tabs. STOCK is the one that answers the question: what is on the
-- dealer right now, and one tap buys it.
local Svc     = _R("svc")
local Cfg     = _R("cfg")
local Util    = _R("util")
local Theme   = _R("theme")
local UI      = _R("ui")
local Notify  = _R("notify")
local Env     = _R("env")
local R       = _R("resolve")
local S       = _R("stock")
local Catalog = _R("catalog")
local Learn   = _R("learn")
local Buy     = _R("buy")
local Island  = _R("island")
local Direct  = _R("headless")
local Session = _R("session")
local TB      = _R("touchui")

local M = {}

M.window = nil
local readouts = {}
local spyLabels = {}
local logLabels = {}
local stockSection, pickSection = nil, nil
local builtStockHash, builtPickKey = nil, nil
local pickQuery = ""

local function get(tbl, key) return function() return tbl[key] end end
local function set(tbl, key, after)
	return function(v)
		tbl[key] = v
		if after then after(v) end
	end
end
local function num(tbl, key)
	return function(v) tbl[key] = tonumber(v) or 0 end
end
local function str(tbl, key)
	return function(v) tbl[key] = tostring(v) end
end

-- ── STOCK ────────────────────────────────────────────────────────────
local function rebuildStock(force)
	if not stockSection then return end
	local key = S.hash .. "|" .. tostring(#Cfg.s.auto.watchlist)
	if not force and key == builtStockHash then return end
	builtStockHash = key

	stockSection:Clear()

	if #S.entries == 0 then
		stockSection:Label("Nothing read yet. Open the dealer's shop and press Read stock, or probe for a stock remote on the CONFIG tab.", "dim")
		return
	end

	for _, row in ipairs(S.entries) do
		local watched = Cfg.Watching(row.name)
		local price = S.Format(row.beli)
		local captured = row.name
		stockSection:ActionRow{
			text = string.format("%d. %s", row.slot or 0, captured),
			value = price,
			tone = watched and "watched" or nil,
			button = "BUY",
			callback = function() Buy.NowByName(captured) end,
			altButton = watched and "ON" or "+",
			altOn = watched,
			altCallback = function()
				Cfg.ToggleWatch(captured)
				Catalog.Add(captured)
				rebuildStock(true)
			end,
		}
	end
end

local function tabStock(w)
	local t = w:Tab("STOCK")

	local a = t:Section("Dealer")
	readouts.stock  = a:Readout{text = "Stock"}
	readouts.dealer = a:Readout{text = "Dealer"}
	readouts.money  = a:Readout{text = "Currency"}
	a:Button{text = "Read stock now", callback = function()
		local ok, why = S.Read(true)
		Catalog.Harvest(S.entries)
		rebuildStock(true)
		if ok then
			Notify.Good("stock", #S.entries .. " read: " .. S.NameLine())
		else
			Notify.Warn("stock", why)
		end
	end}
	readouts.opener = a:Readout{text = "Menu"}
	a:Toggle{text = "Open the dealer menu automatically", get = get(Cfg.s.stock, "autoOpen"),
		set = set(Cfg.s.stock, "autoOpen", function() TB.Repaint() end)}
	a:Toggle{text = "Reopen it if the game closes it", get = get(Cfg.s.stock, "keepOpen"),
		set = set(Cfg.s.stock, "keepOpen")}
	a:Toggle{text = "Unhide the shop frame already in your GUI", get = get(Cfg.s.stock, "revealHidden"),
		set = set(Cfg.s.stock, "revealHidden")}
	a:Toggle{text = "Raise the prompt reach locally first", get = get(Cfg.s.stock, "boostPrompt"),
		set = set(Cfg.s.stock, "boostPrompt")}
	a:Toggle{text = "Fire the dealer's touch parts too", get = get(Cfg.s.stock, "useTouch"),
		set = set(Cfg.s.stock, "useTouch")}
	a:Slider{text = "Retry every", min = 0.25, max = 10, step = 0.25, suffix = " s",
		get = get(Cfg.s.stock, "reopenDelay"), set = set(Cfg.s.stock, "reopenDelay")}
	a:Button{text = "Open it now", callback = function()
		local ok, why = R.OpenAny()
		if ok then Notify.Good("dealer", why) else Notify.Warn("dealer", why) end
	end}
	a:Button{text = "Unhide the shop frame", callback = function()
		local hidden = R.FindHiddenShops()
		if #hidden == 0 then
			Notify.Warn("dealer", "no hidden shop frame in your GUI right now")
			return
		end
		local ok, why = R.RevealShop(hidden[1].frame)
		R.ScanShop(true)
		if ok then Notify.Good("dealer", "revealed " .. why) else Notify.Warn("dealer", why) end
	end}
	a:Toggle{text = "Auto refresh", get = get(Cfg.s.stock, "autoRefresh"),
		set = set(Cfg.s.stock, "autoRefresh", function() TB.Repaint() end)}
	a:Slider{text = "Refresh every", min = 0.5, max = 15, step = 0.5, suffix = " s",
		get = get(Cfg.s.stock, "refreshRate"), set = set(Cfg.s.stock, "refreshRate")}

	local z = t:Section("Instant buy")
	z:Label("Pick a fruit on the PICK tab, arm this, and it buys with Beli on the same read that sees it land.", "dim")
	z:Toggle{text = "Armed", get = get(Cfg.s.auto, "enabled"),
		set = set(Cfg.s.auto, "enabled", function() TB.Repaint() end)}
	readouts.armed = z:Readout{text = "Waiting for"}
	readouts.autoTop = z:Readout{text = "Engine"}

	stockSection = t:Section("In stock right now")
	stockSection:Label("Loading.", "dim")
end

-- ── DIRECT ───────────────────────────────────────────────────────────
local directReport = {}

local function tabDirect(w)
	local t = w:Tab("DIRECT")
	local d = Cfg.s.direct

	local a = t:Section("Buy without the menu")
	a:Label("No dealer menu, no NPC, no stock read. The purchase is a remote call and this makes it directly. Only the fruit name is ever sent, never a slot number, so a wrong guess can fail but cannot buy something else.", "dim")
	a:TextBox{text = "Fruit", placeholder = "Kitsune", get = get(d, "target"), set = str(d, "target")}
	a:Toggle{text = "Armed", get = get(d, "enabled"), set = set(d, "enabled", function() TB.Repaint() end)}
	a:Toggle{text = "Stop once it is bought", get = get(d, "stopOnBuy"), set = set(d, "stopOnBuy")}
	readouts.direct = a:Readout{text = "State"}
	readouts.directLock = a:Readout{text = "Locked on"}

	local b = t:Section("How hard it tries")
	b:Label("While the buy remote is unknown it sweeps every remote named like a purchase, watching your Beli to see which one charged you. Once one charges, it fires only that one.", "dim")
	b:Slider{text = "Fire every (once locked)", min = 0.25, max = 10, step = 0.25, suffix = " s",
		get = get(d, "attemptDelay"), set = set(d, "attemptDelay")}
	b:Slider{text = "Sweep every (while unknown)", min = 5, max = 300, step = 5, suffix = " s",
		get = get(d, "sweepDelay"), set = set(d, "sweepDelay")}
	b:Slider{text = "Sweep limit (0 = no limit)", min = 0, max = 20, step = 1,
		get = get(d, "maxSweeps"), set = set(d, "maxSweeps")}
	b:Toggle{text = "Only fire when a stock source has it", get = get(d, "useStockGate"), set = set(d, "useStockGate")}
	b:Label("With no stock source the gate has nothing to check, so it fires on the timer instead. That is the point: no menu is needed either way.", "dim")

	local c = t:Section("Run it")
	c:Button{text = "Sweep now", callback = function() Direct.Sweep() end}
	c:Button{text = "Attempt now", callback = function() Direct.Attempt() end}
	c:Button{text = "Reset what has been tried", tone = "bad", callback = function()
		Direct.Reset()
		Notify.Info("direct", "cleared")
	end}
	for i = 1, 6 do
		directReport[i] = c:Label("", "dim")
	end
	c:Button{text = "Report", callback = function()
		local lines = Direct.Report()
		for i = 1, 6 do directReport[i]:Set(lines[i] or "") end
	end}
end

-- ── PICK ─────────────────────────────────────────────────────────────
local function rebuildPick(force)
	if not pickSection then return end
	local names = Catalog.Filtered(pickQuery)
	local key = pickQuery .. "|" .. tostring(#names) .. "|" .. tostring(#Cfg.s.auto.watchlist)
	if not force and key == builtPickKey then return end
	builtPickKey = key

	pickSection:Clear()
	if #names == 0 then
		pickSection:Label("No names yet. Read the stock once, or type a fruit above and press Add.", "dim")
		return
	end

	local shown = 0
	for _, name in ipairs(names) do
		if shown >= 40 then break end
		shown = shown + 1
		local captured = name
		local watched = Cfg.Watching(captured)
		local inStock = S.Find(captured) ~= nil
		pickSection:ActionRow{
			text = captured,
			value = inStock and "in stock" or "",
			tone = watched and "watched" or nil,
			button = watched and "WATCHED" or "WATCH",
			callback = function()
				Cfg.ToggleWatch(captured)
				rebuildPick(true)
				rebuildStock(true)
			end,
			altButton = "x",
			altCallback = function()
				Cfg.Unwatch(captured)
				Catalog.Remove(captured)
				rebuildPick(true)
				rebuildStock(true)
			end,
		}
	end
	if #names > shown then
		pickSection:Label("... " .. (#names - shown) .. " more, narrow the search", "dim")
	end
end

local function tabPick(w)
	local t = w:Tab("PICK")

	local a = t:Section("Choose your fruit")
	a:Label("The list is learned, not shipped: it fills from every stock read, and anything you type is remembered. Watched fruit are bought the moment they appear if Auto is armed.", "dim")
	a:TextBox{text = "Search", placeholder = "type to filter",
		get = function() return pickQuery end,
		set = function(v)
			pickQuery = tostring(v)
			rebuildPick(true)
		end}
	a:TextBox{text = "Add by name", placeholder = "exact name as the shop prints it",
		get = function() return "" end,
		set = function(v)
			local clean = Util.Trim(tostring(v))
			if clean == "" then return end
			Catalog.Add(clean)
			Cfg.Watch(clean)
			rebuildPick(true)
			rebuildStock(true)
			Notify.Good("picker", clean .. " added and watched")
		end}
	readouts.watchlist = a:Readout{text = "Watching"}
	a:Button{text = "Clear watchlist", tone = "bad", callback = function()
		Cfg.s.auto.watchlist = {}
		rebuildPick(true)
		rebuildStock(true)
	end}
	a:Button{text = "Forget the learned list", tone = "bad", callback = function()
		Catalog.Clear()
		rebuildPick(true)
	end}

	pickSection = t:Section("Known fruit")
	pickSection:Label("Loading.", "dim")
end

-- ── AUTO ─────────────────────────────────────────────────────────────
local function tabAuto(w)
	local t = w:Tab("AUTO")
	local a = Cfg.s.auto

	local one = t:Section("Auto buy")
	one:Toggle{text = "Armed", get = get(a, "enabled"), set = set(a, "enabled", function() TB.Repaint() end)}
	one:Toggle{text = "Buy on the same read it lands", get = get(a, "instant"), set = set(a, "instant")}
	one:Slider{text = "Poll while armed", min = 0.05, max = 2, step = 0.05, suffix = " s",
		get = get(a, "pollFast"), set = set(a, "pollFast")}
	one:Toggle{text = "Disarm after one buy", get = get(a, "stopAfterBuy"), set = set(a, "stopAfterBuy")}
	one:Slider{text = "Max buys per restock", min = 1, max = 7, step = 1,
		get = get(a, "maxPerRestock"), set = set(a, "maxPerRestock")}
	one:Slider{text = "Retries", min = 1, max = 10, step = 1, get = get(a, "retries"), set = set(a, "retries")}
	one:Slider{text = "Retry delay", min = 0.2, max = 4, step = 0.1, suffix = " s",
		get = get(a, "retryDelay"), set = set(a, "retryDelay")}
	readouts.auto = one:Readout{text = "Engine"}

	local two = t:Section("Spending")
	two:Label("Beli only. The shop button does not say which currency it spends, so this tool never touches Robux.", "dim")
	two:Slider{text = "Per-fruit budget cap (0 = none)", min = 0, max = 50000000, step = 100000,
		get = get(a, "budget"), set = set(a, "budget")}
	readouts.budget = two:Readout{text = "Balance"}

	local three = t:Section("Alerts")
	three:Toggle{text = "Notify on restock", get = get(Cfg.s.stock, "notifyRestock"), set = set(Cfg.s.stock, "notifyRestock")}
	three:Toggle{text = "Notify when a watched fruit lands", get = get(Cfg.s.stock, "notifyWatched"), set = set(Cfg.s.stock, "notifyWatched")}

	local four = t:Section("Purchase log")
	for i = 1, 6 do
		logLabels[i] = four:Label("", "dim")
	end
	four:Button{text = "Clear log", callback = function()
		Buy.log = {}
	end}
end

-- ── ISLAND ───────────────────────────────────────────────────────────
local function tabIsland(w)
	local t = w:Tab("ISLAND")
	local s = Cfg.s.island

	local a = t:Section("Mirage Island")
	a:Label("Detection only: nothing here moves your character. The stock is the same on every server, so a hop never changes what is for sale. It only finds a server where the island, and the dealer on it, exist.", "dim")
	readouts.island = a:Readout{text = "Island"}
	a:Button{text = "Check this server", callback = function()
		local here = Island.Check(true)
		if here then Notify.Good("island", Island.tier) else Notify.Warn("island", "not in this server") end
	end}
	a:Toggle{text = "Keep checking", get = get(s, "autoFind"), set = set(s, "autoFind", function() TB.Repaint() end)}

	local b = t:Section("Hopping")
	b:Toggle{text = "Hop until the island is found", get = get(s, "hopUntilFound"),
		set = set(s, "hopUntilFound", function() TB.Repaint() end)}
	b:Slider{text = "Delay between hops", min = 2, max = 30, step = 1, suffix = " s",
		get = get(s, "hopDelay"), set = set(s, "hopDelay")}
	b:Slider{text = "Max ping to accept", min = 40, max = 400, step = 10, suffix = " ms",
		get = get(s, "hopMaxPing"), set = set(s, "hopMaxPing")}
	b:Button{text = "Hop now", callback = function() Session.Hop() end}
	readouts.servers = b:Readout{text = "Server list"}
	readouts.hops = b:Readout{text = "Hops this run"}

	local c = t:Section("Session")
	c:Toggle{text = "Anti-AFK", get = get(Cfg.s.settings, "antiAfk"),
		set = set(Cfg.s.settings, "antiAfk", function() Session.ApplyAntiAfk() end)}
	c:Toggle{text = "Notifications", get = get(Cfg.s.settings, "notifications"), set = set(Cfg.s.settings, "notifications")}
	c:Button{text = "Rejoin", callback = function() Session.Rejoin() end}
	c:Button{text = "Panic eject", tone = "bad", callback = function() Session.Panic() end}
end

-- ── CONFIG ───────────────────────────────────────────────────────────
local function tabConfig(w)
	local t = w:Tab("CONFIG")

	local rep = t:Section("Scan and report")
	rep:Label("What is actually in this server and in your GUI. Read this before changing anything else.", "dim")
	local reportLabels = {}
	for i = 1, 7 do
		reportLabels[i] = rep:Label("", "dim")
	end
	rep:Button{text = "Scan and report", callback = function()
		local lines = R.ScanReport()
		for i = 1, 7 do
			reportLabels[i]:Set(lines[i] or "")
		end
		Notify.Info("scan", (lines[1] or "done"))
	end}

	local op = t:Section("Learn the open")
	op:Label("Only needed when the menu will not come up on its own. Arm it, open the dealer by hand once, and whatever the game fired is replayed next time.", "dim")
	op:Button{text = "Watch: arm, then open the menu", callback = function() Learn.ArmOpen() end}
	op:TextBox{text = "Open remote", placeholder = "unset", get = get(Cfg.target, "openRemote"), set = str(Cfg.target, "openRemote")}
	op:Dropdown{text = "Open arg shape", options = {"", "bare", "dealer"},
		get = get(Cfg.target, "openArgShape"), set = set(Cfg.target, "openArgShape")}

	local a = t:Section("Learn the purchase")
	a:Label("Arm this, then buy one fruit from the dealer by hand. It watches your balance drop, matches the drop to a stock line, and reads the remote and its argument shape off the call the game actually made.", "dim")
	a:Button{text = "Watch: arm, then buy one fruit", callback = function() Learn.ArmBuy() end}
	a:Button{text = "Cancel watch", callback = function() Learn.Disarm("cancelled") end}
	a:Button{text = "Probe for a stock remote (reads only)", callback = function() Learn.ProbeStock() end}
	readouts.learn = a:Readout{text = "Buy remote"}
	readouts.stockRemote = a:Readout{text = "Stock remote"}

	local b = t:Section("Why nothing buys")
	readouts.diag = {}
	local diagLabels = {"dealer npc", "shop gui", "stock read", "buy path", "currency"}
	for i = 1, 5 do
		readouts.diag[i] = b:Readout{text = diagLabels[i]}
	end
	readouts.verdict = b:Label("", "dim")

	local c = t:Section("Pin what the scanner got wrong")
	c:Button{text = "Pin the NPC I am looking at", callback = function()
		local cam = Svc.Camera()
		if not cam then return end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {Svc.Char()}
		local hit = Svc.Workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 300, params)
		local model = hit and hit.Instance and hit.Instance:FindFirstAncestorOfClass("Model") or nil
		if model and R.PinDealer(model) then
			Notify.Good("dealer", "pinned " .. model.Name)
		else
			Notify.Warn("dealer", "no model under the crosshair")
		end
	end}
	c:Button{text = "Pin the open shop frame", callback = function()
		local root = R.ScanShop(true)
		if root and R.PinShop(root) then
			Notify.Good("shop", "pinned " .. root.Name)
		else
			Notify.Warn("shop", "no shop frame is open to pin")
		end
	end}
	c:TextBox{text = "Dealer name hints", placeholder = "unset", get = get(Cfg.target, "dealerNames"), set = str(Cfg.target, "dealerNames")}
	c:TextBox{text = "Shop frame hints", placeholder = "unset", get = get(Cfg.target, "shopGuiNames"), set = str(Cfg.target, "shopGuiNames")}
	c:TextBox{text = "Island name hints", placeholder = "unset", get = get(Cfg.target, "islandNames"), set = str(Cfg.target, "islandNames")}
	c:TextBox{text = "Currency leaderstat", placeholder = "largest numeric one", get = get(Cfg.target, "currencyStat"), set = str(Cfg.target, "currencyStat")}

	local d = t:Section("Target values")
	d:Label("Nothing here ships with a value. A feature whose box is empty stays off and says so once.", "dim")
	d:TextBox{text = "Buy remote", placeholder = "unset", get = get(Cfg.target, "buyRemote"), set = str(Cfg.target, "buyRemote")}
	d:Dropdown{text = "Buy arg shape", options = {"", "name", "name_cur", "slot", "slot_cur", "bare"},
		get = get(Cfg.target, "buyArgShape"), set = set(Cfg.target, "buyArgShape")}
	d:TextBox{text = "Beli token", placeholder = "unset", get = get(Cfg.target, "buyBeliToken"), set = str(Cfg.target, "buyBeliToken")}
	d:TextBox{text = "Stock remote", placeholder = "unset", get = get(Cfg.target, "stockRemote"), set = str(Cfg.target, "stockRemote")}

	local e = t:Section("Remote spy")
	e:Toggle{text = "Arm spy", get = function() return R.spyOn end, set = function(v)
		R.spyOn = v
		if v and not R.InstallHook() then
			R.spyOn = false
			Notify.Warn("spy", "this executor cannot hook namecall")
		end
	end}
	e:Button{text = "Clear log", callback = function() R.ClearSpy() end}
	for i = 1, 6 do
		spyLabels[i] = e:Label("", "dim")
	end

	local f = t:Section("Config files")
	f:TextBox{text = "Config name", placeholder = "default",
		get = get(Cfg.s.settings, "configName"), set = str(Cfg.s.settings, "configName")}
	f:Button{text = "Save", callback = function()
		local payload = {settings = Cfg.s, target = Cfg.target, catalog = Cfg.catalog}
		local ok, why = Util.SaveJson(Cfg.s.settings.configName, payload)
		if ok then Notify.Good("config", "saved " .. Cfg.s.settings.configName)
		else Notify.Bad("config", why) end
	end}
	f:Button{text = "Load", callback = function()
		local data, why = Util.LoadJson(Cfg.s.settings.configName)
		if not data then Notify.Bad("config", why) return end
		if type(data.settings) == "table" then Util.DeepMerge(Cfg.s, data.settings) end
		if type(data.target) == "table" then Util.DeepMerge(Cfg.target, data.target) end
		if type(data.catalog) == "table" then Cfg.catalog = data.catalog end
		M.window:Refresh()
		TB.Rebuild()
		rebuildPick(true)
		rebuildStock(true)
		Notify.Good("config", "loaded " .. Cfg.s.settings.configName)
	end}
	f:Button{text = "Reset to defaults", tone = "bad", callback = function()
		Util.DeepMerge(Cfg.s, Util.DeepCopy(Cfg.defaults))
		M.window:Refresh()
		TB.Rebuild()
		rebuildPick(true)
		rebuildStock(true)
	end}
	readouts.configs = f:Readout{text = "Saved configs"}

	local g = t:Section("Buttons and executor")
	g:Toggle{text = "Touch buttons", get = get(Cfg.s.settings, "touchButtons"),
		set = set(Cfg.s.settings, "touchButtons", function() TB.Rebuild() end)}
	g:Slider{text = "Button size", min = 34, max = 110, step = 2, suffix = " px",
		get = get(Cfg.s.settings, "touchSize"), set = set(Cfg.s.settings, "touchSize", function() TB.Rebuild() end)}
	g:Dropdown{text = "Button shape", options = {"Shield", "Circle", "Square"}, byIndex = true,
		get = get(Cfg.s.settings, "touchShape"), set = set(Cfg.s.settings, "touchShape", function() TB.Rebuild() end)}
	for _, row in ipairs(Env.Summary()) do
		local ro = g:Readout{text = row[1]}
		ro:Set(row[2], row[2] == "yes" and "good" or (row[2] == "no" and "bad" or "accent"))
	end
end

-- ── build ────────────────────────────────────────────────────────────
function M.Build()
	local w = UI.Window{
		title = "mirage stock",
		subtitle = "Blox Fruits  .  dealer watch and auto buy  .  v" .. Cfg.VERSION,
	}
	M.window = w

	tabDirect(w)
	tabStock(w)
	tabPick(w)
	tabAuto(w)
	tabIsland(w)
	tabConfig(w)

	w:Select("DIRECT")
	rebuildStock(true)
	rebuildPick(true)
	return w
end

function M.RebuildLists(force)
	rebuildStock(force)
	rebuildPick(force)
end

-- ── live readouts ────────────────────────────────────────────────────
function M.Tick()
	if not M.window then return end

	rebuildStock(false)
	rebuildPick(false)

	if readouts.stock then
		local line, tone = S.StatusLine()
		readouts.stock:Set(line, tone)
	end
	if readouts.dealer then
		local st = R.Status()
		readouts.dealer:Set(st.dealer, R.dealer and "good" or "bad")
	end
	if readouts.money then
		local money, statName = R.CurrencyValue()
		readouts.money:Set(money and (statName .. "  " .. S.Format(money)) or (statName or "unreadable"),
			money and "accent" or "bad")
	end
	if readouts.watchlist then
		local list = Cfg.s.auto.watchlist
		readouts.watchlist:Set(#list > 0 and table.concat(list, ", ") or "nothing",
			#list > 0 and "accent" or "dim")
	end
	if readouts.auto then
		local line, tone = Buy.StatusLine()
		readouts.auto:Set(line, tone)
	end
	if readouts.autoTop then
		local line, tone = Buy.StatusLine()
		readouts.autoTop:Set(line, tone)
	end
	if readouts.direct then
		local line, tone = Direct.StatusLine()
		readouts.direct:Set(line, tone)
	end
	if readouts.directLock then
		readouts.directLock:Set(Direct.found
			and (Direct.found.name .. " [" .. Direct.found.shape .. "]")
			or "nothing yet", Direct.found and "good" or "dim")
	end
	if readouts.opener then
		local line, tone = R.OpenStatus()
		readouts.opener:Set(line, tone)
	end
	if readouts.armed then
		local list = Cfg.s.auto.watchlist
		local waiting = {}
		for _, n in ipairs(list) do
			waiting[#waiting + 1] = n .. (S.Find(n) and " (IN STOCK)" or "")
		end
		readouts.armed:Set(#waiting > 0 and table.concat(waiting, ", ") or "nothing picked",
			#waiting > 0 and "accent" or "bad")
	end
	if readouts.budget then
		local money = R.CurrencyValue()
		readouts.budget:Set(money and S.Format(money) or "unreadable", money and "accent" or "bad")
	end
	if readouts.island then
		local line, tone = Island.StatusLine()
		readouts.island:Set(line, tone)
	end
	if readouts.hops then
		readouts.hops:Set(tostring(Island.hopAttempts), Island.hopAttempts > 0 and "accent" or "dim")
	end
	if readouts.servers then
		readouts.servers:Set(#Session.lastServerList .. " cached",
			#Session.lastServerList > 0 and "good" or "dim")
	end
	if readouts.learn then
		local line, tone = Learn.Status()
		readouts.learn:Set(line, tone)
	end
	if readouts.stockRemote then
		local name = Util.Trim(Cfg.target.stockRemote)
		readouts.stockRemote:Set(name ~= "" and name or Learn.stockResult, name ~= "" and "good" or "dim")
	end
	if readouts.diag then
		local rows, verdict = Learn.Diagnose()
		for i = 1, 5 do
			local ro, row = readouts.diag[i], rows[i]
			if ro and row then ro:Set(row[2], row[3] and "good" or "bad") end
		end
		if readouts.verdict then readouts.verdict:Set(verdict) end
	end
	if readouts.configs then
		local list = Util.ListConfigs()
		readouts.configs:Set(#list > 0 and table.concat(list, ", ") or "none", "dim")
	end

	local lines = R.SpyLines(6)
	for i = 1, 6 do
		if spyLabels[i] then spyLabels[i]:Set(lines[i] or "") end
	end
	local logs = Buy.LogLines(6)
	for i = 1, 6 do
		if logLabels[i] then logLabels[i]:Set(logs[i] or "") end
	end

	M.window:SetStatus(string.format("%d in stock  |  %s  |  ping %d ms",
		#S.entries, S.dealerKind, math.floor(Svc.Ping())))
end

return M
end

-- ===== main  (src/19_main.lua) =====
__src["main"] = function(_R)
-- @module main
-- Boot, one driver, binds, and a single teardown path.
local Svc     = _R("svc")
local Cfg     = _R("cfg")
local Util    = _R("util")
local Env     = _R("env")
local Notify  = _R("notify")
local R       = _R("resolve")
local S       = _R("stock")
local Catalog = _R("catalog")
local Learn   = _R("learn")
local Buy     = _R("buy")
local Island  = _R("island")
local Direct  = _R("headless")
local Session = _R("session")
local Binds   = _R("binds")
local TB      = _R("touchui")
local Menu    = _R("menu")

local Main = {}

local maid = Util.Maid.new()
local tickAccum = 0
local running = false

local function registerBinds()
	Binds.Register("refresh", "Read stock", function()
		local ok, why = S.Read(true)
		Catalog.Harvest(S.entries)
		Menu.RebuildLists(true)
		if ok then
			Notify.Good("stock", #S.entries .. " read: " .. S.NameLine())
		else
			Notify.Warn("stock", why)
		end
	end)
	Binds.Register("buytop", "Buy the first watched fruit in stock", function()
		for _, name in ipairs(Cfg.s.auto.watchlist) do
			if S.Find(name) then
				Buy.NowByName(name)
				return
			end
		end
		if #S.entries > 0 then
			Buy.Now(S.entries[1])
		else
			Notify.Warn("buy", "nothing in the read to buy")
		end
	end)
	Binds.Register("auto", "Auto buy", function()
		Buy.ToggleAuto()
		TB.Repaint()
	end)
	Binds.Register("open", "Auto open the dealer menu", function()
		Cfg.s.stock.autoOpen = not Cfg.s.stock.autoOpen
		TB.Repaint()
		if Cfg.s.stock.autoOpen then
			R.openTries = 0
			local ok, why = R.OpenDealer()
			Notify.Info("dealer", ok and why or why)
		else
			Notify.Info("dealer", "auto open off")
		end
	end)
	Binds.Register("direct", "Direct buy", function()
		if Cfg.s.direct.enabled then
			Cfg.s.direct.enabled = false
			Notify.Info("direct", "off")
		else
			Direct.Arm(nil)
		end
		TB.Repaint()
	end)
	Binds.Register("hop", "Hop", function() Session.Hop() end)
	Binds.Register("panic", "Panic eject", function() Main.Unload() end)
	Binds.Register("menu", "Menu", function()
		if Menu.window then Menu.window:ToggleVisible() end
	end)
end

local function heartbeat(dt)
	if not running then return end
	local now = Util.Now()

	local ok, err = pcall(function()
		R.StepAutoOpen(dt, now)
		S.Step(dt, now)
		Learn.Step(dt, now)
		Buy.Step(dt, now)
		Island.Step(dt, now)
		Direct.Step(dt, now)
	end)
	if not ok then
		warn("[mirage] heartbeat: " .. tostring(err))
	end

	tickAccum = tickAccum + dt
	if tickAccum >= 1 then
		tickAccum = 0
		pcall(Menu.Tick)
		pcall(TB.Repaint)
	end
end

function Main.Unload()
	if not running then return end
	running = false

	pcall(R.RestoreReveals)
	pcall(Session.Destroy)
	pcall(Binds.Destroy)
	pcall(TB.Destroy)
	if Menu.window then pcall(function() Menu.window:Destroy() end) end
	pcall(Notify.Destroy)
	maid:Clean()

	local g = Util.Genv()
	g.MS_LOADED = nil
	g.MS_UNLOAD = nil
	warn("[mirage] unloaded")
end

function Main.Start()
	local g = Util.Genv()
	if g.MS_LOADED and type(g.MS_UNLOAD) == "function" then
		pcall(g.MS_UNLOAD)
	end
	g.MS_LOADED = true
	g.MS_UNLOAD = Main.Unload

	if not Svc.LP then
		Svc.LP = Svc.Players.LocalPlayer
	end
	if not Svc.LP then
		warn("[mirage] no LocalPlayer; this has to run as a client script")
		return
	end

	running = true

	R.IndexRemotes()
	R.ScanDealer(true)
	Island.Check(true)
	S.Read(true)
	Catalog.Harvest(S.entries)

	S.onRead = function(rows)
		Buy.TryInstant(rows)
	end
	S.onRestock = function(rows, first)
		Catalog.Harvest(rows)
		Buy.OnRestock(rows, first)
		Menu.RebuildLists(true)
	end
	Island.Hopper = Session.Hop

	registerBinds()
	Binds.Init()

	Menu.Build()
	TB.Rebuild()
	Session.PanicHook = Main.Unload
	Session.ApplyAntiAfk()

	maid:Give(Svc.RunService.Heartbeat:Connect(heartbeat))

	Notify.Good("mirage stock", Island.present
		and ("dealer found: " .. Island.tier .. ". opening its menu.")
		or "the dealer is not in this server. ISLAND tab can hop until one has it.")

	if #S.entries == 0 then
		Notify.Warn("stock", "nothing read yet. Open the dealer's shop, then press Read stock.")
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
	warn("[mirage] boot failed: " .. tostring(err))
	local notified = pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "mirage stock", Text = tostring(err), Duration = 8,
		})
	end)
	if not notified then print("[mirage] boot failed: " .. tostring(err)) end
end
