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
