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
