-- Headless rig: a fake Mirage dealer with a seven slot shop GUI, a buy
-- remote and a stock RemoteFunction. Boots the real bundle against it.
local H = {}
local v3 = Vector3.new
local results = {}
local function check(name, ok, detail)
	results[#results + 1] = {name = name, ok = ok and true or false, detail = detail or ""}
end
H.results = results

local function sig() return _MOCK.newSignal("s") end

-- ── services ─────────────────────────────────────────────────────────
local Workspace = Instance.new("Model")
Workspace.Name = "Workspace"
Workspace.Gravity = 196.2
function Workspace:GetRealPhysicsFPS() return 60 end
function Workspace:Raycast() return nil end

local Camera = Instance.new("Part")
Camera.ClassName = "Camera"
Camera.Name = "Camera"
Camera.CFrame = CFrame.new(v3(0, 10, 30))
Camera.ViewportSize = Vector2.new(1280, 720)
Camera.FieldOfView = 70
function Camera:WorldToViewportPoint(pos) return v3(640, 360, 10), true end
Workspace.CurrentCamera = Camera

-- the dealer
local dealer = Instance.new("Model", Workspace)
dealer.Name = "Advanced Fruit Dealer"
local dealerHum = Instance.new("Humanoid", dealer)
local dealerRoot = Instance.new("Part", dealer)
dealerRoot.Name = "HumanoidRootPart"
dealerRoot.Position = v3(120, 5, -340)
dealer.PrimaryPart = dealerRoot
local prompt = Instance.new("ProximityPrompt", dealerRoot)
prompt.ActionText = "Shop"
prompt.ObjectText = "Advanced Fruit Dealer"

-- a decoy NPC that must not win
local decoy = Instance.new("Model", Workspace)
decoy.Name = "Bandit"
Instance.new("Humanoid", decoy)
local decoyRoot = Instance.new("Part", decoy)
decoyRoot.Name = "HumanoidRootPart"
decoyRoot.Position = v3(10, 5, 10)

local island = Instance.new("Model", Workspace)
island.Name = "MirageIsland"
island.CFrame = CFrame.new(v3(120, 0, -340))
island.Size = v3(400, 40, 400)

-- local player
local function makeChar(name, pos)
	local char = Instance.new("Model", Workspace)
	char.Name = name
	Instance.new("Humanoid", char)
	local hrp = Instance.new("Part", char)
	hrp.Name = "HumanoidRootPart"
	hrp.CFrame = CFrame.new(pos)
	local head = Instance.new("Part", char)
	head.Name = "Head"
	head.Position = pos + v3(0, 1.5, 0)
	return char
end

local lp = Instance.new("Model")
lp.ClassName = "Player"
lp.Name = "Olivia"
lp.DisplayName = "Olivia"
lp.UserId = 42
lp.Character = makeChar("Olivia", v3(0, 5, 0))

local playerGui = Instance.new("Model", lp)
playerGui.ClassName = "PlayerGui"
playerGui.Name = "PlayerGui"

local leaderstats = Instance.new("Model", lp)
leaderstats.ClassName = "Folder"
leaderstats.Name = "leaderstats"
local beli = Instance.new("IntValue", leaderstats)
beli.Name = "Beli"
beli.Value = 30000000
local level = Instance.new("IntValue", leaderstats)
level.Name = "Level"
level.Value = 2550

-- ── the shop GUI ─────────────────────────────────────────────────────
local shopGui = Instance.new("ScreenGui", playerGui)
shopGui.Name = "DealerUI"
local shopFrame = Instance.new("Frame", shopGui)
shopFrame.Name = "MirageShopList"

local STOCK_A = {
	{"Leopard",  "$5,000,000",  "R$ 3,000"},
	{"Kitsune",  "$8,000,000",  "R$ 4,000"},
	{"Dough",    "$2,800,000",  "R$ 2,400"},
	{"Spirit",   "3.4M",        "R$ 2,550"},
	{"Control",  "$3,200,000",  "R$ 2,500"},
	{"Venom",    "$3,000,000",  "R$ 2,450"},
	{"Shadow",   "$2,900,000",  "R$ 2,425"},
}
local STOCK_B = {
	{"Buddha",   "$1,200,000",  "R$ 1,650"},
	{"Rumble",   "$2,100,000",  "R$ 2,100"},
	{"Portal",   "$2,500,000",  "R$ 2,375"},
	{"Blizzard", "$2,400,000",  "R$ 2,350"},
	{"Gravity",  "$2,500,000",  "R$ 2,375"},
	{"Pain",     "$2,300,000",  "R$ 2,300"},
	{"Phoenix",  "$1,800,000",  "R$ 2,000"},
}

H.buyCalls = {}
local rowObjects = {}

local function buildRows(stock)
	for _, r in ipairs(rowObjects) do r:Destroy() end
	rowObjects = {}
	for i, entry in ipairs(stock) do
		local row = Instance.new("Frame", shopFrame)
		row.Name = "Slot" .. i
		row.LayoutOrder = i
		row.AbsolutePosition = Vector2.new(0, i * 40)

		local nameLabel = Instance.new("TextLabel", row)
		nameLabel.Name = "FruitName"
		nameLabel.Text = entry[1]

		local priceLabel = Instance.new("TextLabel", row)
		priceLabel.Name = "Price"
		priceLabel.Text = entry[2]

		local robuxLabel = Instance.new("TextLabel", row)
		robuxLabel.Name = "RobuxPrice"
		robuxLabel.Text = entry[3]

		local btn = Instance.new("TextButton", row)
		btn.Name = "Buy"
		btn.Text = "Buy"
		local fruit = entry[1]
		btn.MouseButton1Click:Connect(function()
			table.insert(H.buyCalls, {how = "button", name = fruit})
			beli.Value = beli.Value - 1000000
		end)
		rowObjects[#rowObjects + 1] = row
	end
end
buildRows(STOCK_A)
H.buildRows = buildRows
H.STOCK_A, H.STOCK_B = STOCK_A, STOCK_B

-- ── replicated storage ───────────────────────────────────────────────
local ReplicatedStorage = Instance.new("Model")
ReplicatedStorage.ClassName = "ReplicatedStorage"
ReplicatedStorage.Name = "ReplicatedStorage"

local buyRemote = Instance.new("RemoteEvent", ReplicatedStorage)
buyRemote.Name = "BuyFruitFromDealer"
buyRemote.FireServer = function(_, ...)
	local args = table.pack(...)
	table.insert(H.buyCalls, {how = "remote", name = args[1], cur = args[2]})
	beli.Value = beli.Value - 1000000
end

local stockRemote = Instance.new("RemoteFunction", ReplicatedStorage)
stockRemote.Name = "GetFruitStock"
stockRemote.InvokeServer = function()
	local out = {}
	for i, entry in ipairs(STOCK_A) do
		out[i] = {Name = entry[1], Price = (i + 1) * 1000000, Robux = 2000 + i}
	end
	return out
end

local noiseRemote = Instance.new("RemoteFunction", ReplicatedStorage)
noiseRemote.Name = "GetPlayerData"
noiseRemote.InvokeServer = function() return {Level = 2550} end

-- ── remaining services ───────────────────────────────────────────────
local Players = Instance.new("Model")
Players.ClassName = "Players"
Players.LocalPlayer = lp
function Players:GetPlayers() return {lp} end

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

local StarterGui = Instance.new("Model")
StarterGui.ClassName = "StarterGui"
function StarterGui:SetCore() end

local CoreGui = Instance.new("Model")
CoreGui.ClassName = "CoreGui"
CoreGui.Name = "CoreGui"

local Stats = Instance.new("Model")
Stats.ClassName = "Stats"
Stats.Network = {ServerStatsItem = {["Data Ping"] = {GetValue = function() return 55 end}}}

local TeleportService = Instance.new("Model")
TeleportService.ClassName = "TeleportService"
function TeleportService:Teleport() end
function TeleportService:TeleportToPlaceInstance() end

local VirtualUser = Instance.new("Model")
VirtualUser.ClassName = "VirtualUser"
function VirtualUser:CaptureController() end
function VirtualUser:ClickButton2() end

local services = {
	Players = Players, RunService = RunService, UserInputService = UIS,
	ContextActionService = Instance.new("Model"), TweenService = TweenService,
	HttpService = HttpService, Lighting = Lighting,
	ReplicatedStorage = ReplicatedStorage, TeleportService = TeleportService,
	StarterGui = StarterGui, Stats = Stats, GuiService = Instance.new("Model"),
	CoreGui = CoreGui, VirtualUser = VirtualUser, Workspace = Workspace,
}

game = setmetatable({
	PlaceId = 2753915549,
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
	FindFirstChildOfClass = function() return nil end,
	FindFirstChild = function(_, name) return services[name] end,
}, {})
workspace = Workspace

H.env = {
	dealer = dealer, shopFrame = shopFrame, shopGui = shopGui, beli = beli,
	buyRemote = buyRemote, stockRemote = stockRemote, RunService = RunService,
	lp = lp, UIS = UIS, island = island,
}

-- ── run ──────────────────────────────────────────────────────────────
function H.Run(bundleSource)
	_G.LC_TEST = true
	local chunk, loadErr = load(bundleSource, "mirage_stock")
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

	local Cfg     = _R("cfg")
	local Res     = _R("resolve")
	local S       = _R("stock")
	local Catalog = _R("catalog")
	local Learn   = _R("learn")
	local Buy     = _R("buy")
	local Island  = _R("island")
	local Menu    = _R("menu")

	-- price parsing
	do
		local a, ac = S.ParsePrice("$5,000,000")
		local b, bc = S.ParsePrice("R$ 3,000")
		local c = S.ParsePrice("3.4M")
		local d = S.ParsePrice("12.5k")
		local e = S.ParsePrice("Buy")
		check("parses a comma price", a == 5000000 and ac == "beli", tostring(a) .. " " .. tostring(ac))
		check("parses a robux price", b == 3000 and bc == "robux", tostring(b) .. " " .. tostring(bc))
		check("parses an M suffix", c == 3400000, tostring(c))
		check("parses a k suffix", d == 12500, tostring(d))
		check("refuses a non price", e == nil, tostring(e))
	end

	-- resolver
	check("finds the dealer npc", Res.ScanDealer(true) == dealer,
		Res.dealer and Res.dealer.Name or "nil")
	check("ignores the decoy npc", Res.dealer ~= decoy)
	check("finds the shop frame", Res.ScanShop(true) == shopFrame,
		Res.shopRoot and Res.shopRoot.Name or "nil")

	-- auto open: the tool opens the dealer menu where you stand
	do
		_MOCK.onPrompt = function() shopGui.Enabled = true end
		_MOCK.prompts = 0
		shopGui.Enabled = false
		Res.ScanShop(true)
		check("shop reads as shut", not Res.ShopOpen())

		prompt.MaxActivationDistance = 8
		Cfg.s.stock.autoOpen = true
		Cfg.s.stock.boostPrompt = true
		Cfg.s.stock.reopenDelay = 0.25

		Res.StepAutoOpen(1 / 60, 1000)
		check("opener fired the prompt", (_MOCK.prompts or 0) >= 1, tostring(_MOCK.prompts))
		check("prompt reach raised locally", prompt.MaxActivationDistance >= 500,
			tostring(prompt.MaxActivationDistance))

		Res.ScanShop(true)
		check("menu is open after one attempt", Res.ShopOpen())

		local firedBefore = _MOCK.prompts
		for i = 1, 20 do Res.StepAutoOpen(1 / 60, 1000 + i) end
		check("stops firing once the menu is open", _MOCK.prompts == firedBefore,
			tostring(_MOCK.prompts - firedBefore) .. " extra")
		check("opener reports open", select(1, Res.OpenStatus()) == "menu open", Res.openState)

		-- backs off rather than hammering when there is nothing to open
		_MOCK.onPrompt = nil
		shopGui.Enabled = false
		Res.ScanShop(true)
		_MOCK.prompts = 0
		Res.openTries = 0
		for i = 1, 30 do Res.StepAutoOpen(1 / 60, 2000 + i * 0.05) end
		check("retries are rate limited", (_MOCK.prompts or 0) <= 8, tostring(_MOCK.prompts))

		_MOCK.onPrompt = function() shopGui.Enabled = true end
		Res.openTries = 0
		Res.StepAutoOpen(1 / 60, 3000)
		Res.ScanShop(true)
		check("recovers and opens again", Res.ShopOpen())
	end

	-- stock read from the GUI
	Cfg.target.stockRemote = ""
	local readOk, source = S.Read(true)
	check("reads stock from the gui", readOk and source == "gui", tostring(source))
	check("reads all seven slots", #S.entries == 7, tostring(#S.entries))
	check("row one is slot one", S.entries[1] and S.entries[1].slot == 1 and S.entries[1].name == "Leopard",
		S.entries[1] and S.entries[1].name or "nil")
	check("beli price parsed off the row", S.entries[1] and S.entries[1].beli == 5000000,
		S.entries[1] and tostring(S.entries[1].beli) or "nil")
	check("robux price parsed off the row", S.entries[1] and S.entries[1].robux == 3000,
		S.entries[1] and tostring(S.entries[1].robux) or "nil")
	check("classifies the mirage dealer", S.dealerKind == "mirage", S.dealerKind)

	check("finds a fruit by exact name", S.Find("Kitsune") ~= nil)
	check("find is case insensitive", S.Find("kitsune") ~= nil)
	check("find takes a partial", S.Find("Bliz") == nil and S.Find("Leop") ~= nil)

	Catalog.Harvest(S.entries)
	check("catalogue learned the names", Catalog.Count() == 7, tostring(Catalog.Count()))
	check("catalogue ships empty of guesses", Catalog.Has("Leopard") and not Catalog.Has("Mochi"))

	-- picking
	Cfg.Watch("Kitsune")
	check("watchlist takes a pick", Cfg.Watching("kitsune"))
	Cfg.ToggleWatch("Kitsune")
	check("watchlist toggles off", not Cfg.Watching("Kitsune"))
	Cfg.Watch("Kitsune")

	-- buy through the shop button, no remote known
	do
		H.buyCalls = {}
		Cfg.target.buyRemote = ""
		Cfg.target.buyArgShape = ""
		local path, why = Learn.BuyPath()
		check("button path available with no remote", path == "button", tostring(path) .. " " .. tostring(why))
		local before = beli.Value
		local bought = Buy.NowByName("Kitsune")
		check("buys through the shop button", bought and #H.buyCalls == 1 and H.buyCalls[1].how == "button",
			#H.buyCalls > 0 and H.buyCalls[1].how or "no call")
		check("the right row was clicked", #H.buyCalls > 0 and H.buyCalls[1].name == "Kitsune",
			#H.buyCalls > 0 and tostring(H.buyCalls[1].name) or "nil")
		check("currency moved", beli.Value < before, tostring(before - beli.Value))
	end

	-- learner: watch a purchase made by the game
	do
		check("hook installs", Res.InstallHook())
		local armed = Learn.ArmBuy()
		check("buy watch arms", armed, Learn.result)

		_MOCK.FireFromGame(buyRemote, "Dough", "Beli")
		check("spy recorded the purchase send", #Res.spyEvents >= 1, tostring(#Res.spyEvents))

		beli.Value = beli.Value - 2800000      -- the price of Dough on this board
		RunService.Heartbeat:Fire(1 / 60)

		check("watch adopted the buy remote", Cfg.target.buyRemote == "BuyFruitFromDealer", Cfg.target.buyRemote)
		check("watch read the arg shape", Cfg.target.buyArgShape == "name_cur", Cfg.target.buyArgShape)
		check("watch captured the beli token", Cfg.target.buyBeliToken == "Beli", Cfg.target.buyBeliToken)
		check("watch disarms itself", Learn.state == "idle", Learn.state)
	end

	-- buy through the learned remote
	do
		H.buyCalls = {}
		local path = Learn.BuyPath()
		check("remote path now preferred", path == "remote", tostring(path))
		local bought = Buy.NowByName("Spirit")
		check("buys through the learned remote", bought and #H.buyCalls == 1 and H.buyCalls[1].how == "remote",
			#H.buyCalls > 0 and H.buyCalls[1].how or "no call")
		check("remote got the fruit name", #H.buyCalls > 0 and H.buyCalls[1].name == "Spirit",
			#H.buyCalls > 0 and tostring(H.buyCalls[1].name) or "nil")
		check("remote got the learned token", #H.buyCalls > 0 and H.buyCalls[1].cur == "Beli",
			#H.buyCalls > 0 and tostring(H.buyCalls[1].cur) or "nil")
	end

	-- beli only: there is no robux path to take
	do
		check("no robux currency setting exists", Cfg.s.auto.currency == nil)
		check("no robux token field exists", Cfg.target.buyRobuxToken == nil)
	end

	-- affordability
	do
		H.buyCalls = {}
		local saved = beli.Value
		beli.Value = 10
        local row = S.Find("Leopard")
		local can, reason = Buy.Affordable(row)
		check("refuses what you cannot afford", can == false, tostring(reason))
		beli.Value = saved
	end

	-- stock remote probe
	do
		Cfg.target.stockRemote = ""
		local found = Learn.ProbeStock()
		check("probe finds the stock remote", found and Cfg.target.stockRemote == "GetFruitStock",
			Cfg.target.stockRemote)
		local okR, srcR = S.Read(true)
		check("reads stock through the remote", okR and srcR == "remote", tostring(srcR))
		check("remote read normalised seven rows", #S.entries == 7, tostring(#S.entries))
		Cfg.target.stockRemote = ""
		S.Read(true)
	end

	-- the headline: pick a fruit, it lands, it is bought on that read
	do
		Cfg.s.auto.watchlist = {}
		Cfg.Watch("Kitsune")
		Cfg.s.auto.enabled = true
		Cfg.s.auto.instant = true
		Cfg.s.auto.maxPerRestock = 1
		Cfg.s.auto.budget = 0
		beli.Value = 30000000
		Buy.bought = {}
		Buy.boughtThisRestock = 0

		-- a board without it: nothing may be bought
		H.buyCalls = {}
		buildRows(H.STOCK_B)
		S.Read(true)
		check("waits while the pick is not in stock", #H.buyCalls == 0,
			#H.buyCalls > 0 and tostring(H.buyCalls[1].name) or "nothing bought")
		check("restock counter reset on the new board", Buy.boughtThisRestock == 0,
			tostring(Buy.boughtThisRestock))

		-- it lands: the buy must go out inside this very read
		H.buyCalls = {}
		buildRows(H.STOCK_A)
		local changesBefore = S.changes
		S.Read(true)
		check("restock detected", S.changes > changesBefore, tostring(S.changes))
		local boughtIt = false
		for _, c in ipairs(H.buyCalls) do
			if c.name == "Kitsune" then boughtIt = true end
		end
		check("buys the pick on the read that sees it", boughtIt,
			#H.buyCalls > 0 and tostring(H.buyCalls[1].name) or "nothing bought")
		check("no heartbeat was needed", boughtIt and #H.buyCalls == 1, tostring(#H.buyCalls))

		-- and it does not buy it twice off the next read
		H.buyCalls = {}
		S.Read(true)
		check("does not re-buy the same landing", #H.buyCalls == 0, tostring(#H.buyCalls))
		check("respects max per restock", Buy.boughtThisRestock <= 1, tostring(Buy.boughtThisRestock))

		-- poll tightens while armed
		check("poll tightens while armed", S.Rate() <= 0.2, string.format("%.2fs", S.Rate()))
		Cfg.s.auto.enabled = false
		check("poll relaxes when off", S.Rate() >= 0.25, string.format("%.2fs", S.Rate()))
	end

	-- island
	check("island reads as present", Island.Check(true), Island.tier)

	-- menu
	check("menu window built", Menu.window ~= nil)
	if Menu.window then
		check("five tabs present", #Menu.window.tabs == 5, tostring(#Menu.window.tabs))
		check("menu refresh runs", pcall(function() Menu.window:Refresh() end))
		check("menu tick runs", pcall(Menu.Tick))
		check("stock list rebuilt in place", pcall(function() Menu.RebuildLists(true) end))
	end

	-- drive
	do
		local hrp = lp.Character:FindFirstChild("HumanoidRootPart")
		local startedAt = hrp.CFrame.Position
		local before = #(_MOCK.warnings or {})
		Cfg.s.stock.autoRefresh = true
		Cfg.s.island.autoFind = true
		Cfg.s.auto.enabled = true
		for i = 1, 240 do
			RunService.Heartbeat:Fire(1 / 60)
		end
		local errs = 0
		for i = before + 1, #(_MOCK.warnings or {}) do
			if string.find(_MOCK.warnings[i], "heartbeat", 1, true) then errs = errs + 1 end
		end
		check("240 frames with everything on", errs == 0, tostring(errs) .. " driver errors")
		check("the tool never moved the character",
			(hrp.CFrame.Position - startedAt).Magnitude < 0.001,
			string.format("%.3f studs", (hrp.CFrame.Position - startedAt).Magnitude))
	end

	-- shop closes: the reader must not throw or blank wrongly
	do
		shopGui.Enabled = false
		local before = #(_MOCK.warnings or {})
		for i = 1, 60 do RunService.Heartbeat:Fire(1 / 60) end
		local errs = 0
		for i = before + 1, #(_MOCK.warnings or {}) do
			if string.find(_MOCK.warnings[i], "heartbeat", 1, true) then errs = errs + 1 end
		end
		check("survives the shop closing", errs == 0, tostring(errs) .. " driver errors")
		check("keeps the last good read", #S.entries == 7, tostring(#S.entries))
		shopGui.Enabled = true
	end

	check("unload runs clean", pcall(function() _G.MS_UNLOAD() end))
	return results
end

function H.RunMobile(bundleSource)
	UIS.TouchEnabled = true
	UIS.KeyboardEnabled = false
	UIS.GamepadEnabled = true

	local chunk = load(bundleSource, "mirage_mobile")
	local ok, err = pcall(chunk)
	check("mobile boot executes", ok, ok and "" or tostring(err))
	if not ok then return results end

	local _R = _G.LC_R
	local TB = _R("touchui")
	local Theme = _R("theme")
	local Menu = _R("menu")

	check("touch buttons built", TB.Count() == 6, tostring(TB.Count()))
	check("rows grow for fingers", Theme.RowHeight() >= 42, tostring(Theme.RowHeight()))
	check("window fits the viewport",
		Menu.window ~= nil and Menu.window.Root.Size.X.Offset <= 1280 * 0.95,
		Menu.window and tostring(Menu.window.Root.Size.X.Offset) or "no window")

	local before = #(_MOCK.warnings or {})
	for i = 1, 120 do RunService.Heartbeat:Fire(1 / 60) end
	local errs = 0
	for i = before + 1, #(_MOCK.warnings or {}) do
		if string.find(_MOCK.warnings[i], "heartbeat", 1, true) then errs = errs + 1 end
	end
	check("120 mobile frames clean", errs == 0, tostring(errs) .. " driver errors")
	check("mobile unload runs clean", pcall(function() _G.MS_UNLOAD() end))
	return results
end

return H
