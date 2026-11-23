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
