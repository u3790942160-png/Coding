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
