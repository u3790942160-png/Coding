--!nocheck
--[==[
	Veltrex Hub
	===========
	Generated file — do not edit directly.
	Sources: src/core.lua (logic) and src/ui.lua (interface).
	Rebuild with: python3 build.py

	The original release mixed its interface into the logic; this build keeps
	the two apart. core.lua creates no GUI at all, ui.lua contains no gameplay
	behaviour, and they talk through Core's event bus.
]==]

if _G.Veltrex and _G.Veltrex.unload then
	pcall(_G.Veltrex.unload)
	task.wait(0.1)
end

--==============================================================================
-- VeltrexCore (from src/core.lua)
--==============================================================================

local VeltrexCore = (function(...)
--!nocheck
--[==[
	Veltrex — Core
	--------------
	Every gameplay behaviour of the original script, with all interface code
	removed. This module never creates a ScreenGui, a BillboardGui or a button:
	it exposes state, features and actions, and announces changes on a small
	event bus so any front-end can drive it.

	Front-end contract
	  Core.on(event, fn)            subscribe          -> disconnect function
	  Core.setFeature(id, on)       toggle a feature   (handles conflicts)
	  Core.toggleFeature(id)
	  Core.runAction(id)            fire a one-shot action
	  Core.setValue(key, number)    tune a numeric setting
	  Core.setMode(key, value)      "stealMode" / "dropMode"
	  Core.setSpeedProfile(name)    "normal" | "carry" | "lagger" | "laggerCarry"
	  Core.setKeybind(id, keyCode, isGamepad)
	  Core.captureInput(bool)       suspend keybinds while the UI records a key

	Events
	  feature   (id, on)        speedProfile (name)     value  (key, number)
	  mode      (key, value)    keybind      (id)       progress (0..1)
	  notify    (text, kind)    unload       ()
]==]

local Core = {}

--==============================================================================
-- Services / player
--==============================================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UIS              = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local Stats            = game:GetService("Stats")

local LP        = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

Core.Players    = Players
Core.RunService = RunService
Core.UIS        = UIS
Core.Stats      = Stats
Core.LP         = LP
Core.PlayerGui  = PlayerGui

--==============================================================================
-- Event bus
--==============================================================================

local listeners = {}

function Core.on(event, fn)
	local bucket = listeners[event]
	if not bucket then
		bucket = {}
		listeners[event] = bucket
	end
	table.insert(bucket, fn)
	return function()
		for i, f in ipairs(bucket) do
			if f == fn then
				table.remove(bucket, i)
				break
			end
		end
	end
end

function Core.emit(event, ...)
	local bucket = listeners[event]
	if not bucket then return end
	for _, fn in ipairs(bucket) do
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[Veltrex] listener error on '" .. tostring(event) .. "': " .. tostring(err))
		end
	end
end

function Core.notify(text, kind)
	Core.emit("notify", text, kind or "info")
end

--==============================================================================
-- Connection bookkeeping (so the whole hub can be unloaded cleanly)
--==============================================================================

local coreConns = {}

local function bind(signal, fn)
	local conn = signal:Connect(fn)
	table.insert(coreConns, conn)
	return conn
end

local function drop(conn)
	if conn then
		pcall(function() conn:Disconnect() end)
	end
	return nil
end

--==============================================================================
-- Filesystem helpers (executors expose these; fall back to no-ops)
--==============================================================================

-- Executor globals: undefined ones simply resolve to nil, which every call site
-- below guards against.
local fs = {
	isfile    = isfile,
	readfile  = readfile,
	writefile = writefile,
}

local exec = {
	getconnections    = getconnections,
	hookfunction      = hookfunction,
	newcclosure       = newcclosure,
	sethiddenproperty = sethiddenproperty,
}
Core.exec = exec

local function readJSON(name)
	if not (fs.isfile and fs.readfile) then return nil end
	local ok, exists = pcall(fs.isfile, name)
	if not ok or not exists then return nil end
	local okRead, raw = pcall(fs.readfile, name)
	if not okRead or type(raw) ~= "string" then return nil end
	local okDecode, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if okDecode and type(data) == "table" then return data end
	return nil
end

local function writeJSON(name, tbl)
	if not fs.writefile then return end
	pcall(function() fs.writefile(name, HttpService:JSONEncode(tbl)) end)
end

--==============================================================================
-- Configuration
--==============================================================================

local CONFIG_FILE = "VeltrexHub.json"
local LEGACY_FILE = "VeltrexHubConfig.json"

Core.cfg = {
	-- movement speeds
	normalSpeed      = 60,
	carrySpeed       = 30,
	laggerSpeed      = 15,
	laggerCarrySpeed = 24.5,

	-- steal tuning
	grabRadius      = 60,   -- normal mode pickup radius
	primeStealRange = 80,   -- semi mode: distance at which the hold starts
	semiStealRadius = 9,    -- semi mode: distance at which the trigger fires
	stealHold       = 1.3,  -- normal mode hold time

	-- movement utilities
	tpY = -7,               -- Y level used by TP Down / Auto TP

	-- combat tuning
	aimbotSpeed     = 58,   -- studs/sec chase speed
	aimbotHeight    = 3.7,  -- how far above the target to hover
	aimbotTurn      = 42,   -- angular velocity multiplier
	batHitDistance  = 8,    -- distance at which Bat V2 swings
	swingCooldown   = 0.35,

	-- modes
	stealMode    = "normal",   -- "normal" | "semi"
	dropMode     = "stand",    -- "stand"  | "jump"
	speedProfile = "normal",   -- "normal" | "carry" | "lagger" | "laggerCarry"

	features = {},   -- id -> bool
	keybinds = {},   -- id -> { kb = "Q", gp = "ButtonY" }
	ui       = {},   -- owned by the front-end, persisted here
}

local cfg = Core.cfg

local saveQueued = false

function Core.save()
	if saveQueued then return end
	saveQueued = true
	task.delay(0.6, function()
		saveQueued = false
		writeJSON(CONFIG_FILE, cfg)
	end)
end

-- Pull the handful of settings the original script stored, so existing users
-- keep their speeds and keys on first launch of this build.
local function migrateLegacy()
	local old = readJSON(LEGACY_FILE)
	if not old then return end

	local numbers = {
		normalSpeed      = "normalSpeed",
		carrySpeed       = "carrySpeed",
		laggerSpeed      = "laggerSpeed",
		laggerCarrySpeed = "laggerCarrySpeed",
		grabRadius       = "grabRadius",
		primeStealRange  = "primeStealRange",
		semiStealRadius  = "semiStealRadius",
	}
	for newKey, oldKey in pairs(numbers) do
		if type(old[oldKey]) == "number" then cfg[newKey] = old[oldKey] end
	end

	if old.stealMode == "normal" or old.stealMode == "semi" then cfg.stealMode = old.stealMode end
	if old.dropMode  == "stand"  or old.dropMode  == "jump" then cfg.dropMode  = old.dropMode  end

	if old.laggerMode then
		cfg.speedProfile = old.laggerCarryMode and "laggerCarry" or "lagger"
	elseif old.carryMode then
		cfg.speedProfile = "carry"
	end

	local flags = {
		antiRagdoll     = "antiRagdoll",
		infiniteJump    = "infiniteJump",
		medusaCounter   = "medusaCounter",
		batCounter      = "batCounter",
		autoStealEnabled = "autoSteal",
		autoBat         = "autoBat",
		autoSwing       = "autoSwing",
		batV2Enabled    = "batV2",
		unwalkEnabled   = "unwalk",
		autoTPEnabled   = "autoTP",
		antiDesync      = "antiDesync",
		autoSwitchSpeed = "autoSwitchSpeed",
	}
	for oldKey, featureId in pairs(flags) do
		if type(old[oldKey]) == "boolean" then cfg.features[featureId] = old[oldKey] end
	end

	local keys = {
		dropBrainrotKey = "drop",
		autoLeftKey     = "autoLeft",
		autoRightKey    = "autoRight",
		autoBatKey      = "autoBat",
		batV2Key        = "batV2",
		laggerToggleKey = "laggerToggle",
		tpFloorKey      = "tpFloor",
		instaResetKey   = "instaReset",
		guiHideKey      = "toggleUI",
		speedToggleKey  = "speedToggle",
	}
	for oldKey, bindId in pairs(keys) do
		local entry = old[oldKey]
		if type(entry) == "table" and (entry.kb or entry.gp) then
			cfg.keybinds[bindId] = { kb = entry.kb, gp = entry.gp }
		end
	end
end

local function loadConfig()
	local data = readJSON(CONFIG_FILE)
	if not data then
		migrateLegacy()
		return
	end
	for key, value in pairs(data) do
		if type(cfg[key]) == "table" and type(value) == "table" then
			for k, v in pairs(value) do cfg[key][k] = v end
		elseif cfg[key] ~= nil or key == "ui" then
			cfg[key] = value
		end
	end
end

loadConfig()

--==============================================================================
-- Runtime state
--==============================================================================

Core.state = {
	speed       = 0,      -- current horizontal speed, for the HUD
	aimTarget   = nil,    -- player name the aimbot is chasing
	stealing    = false,
	stealLabel  = "",
	inputLocked = false,  -- true while the UI records a keybind
}

local state = Core.state
local flags = {}          -- feature id -> bool

function Core.isOn(id)
	return flags[id] == true
end

--==============================================================================
-- Character helpers
--==============================================================================

local function char()      return LP.Character end
local function humanoid()  local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function root()      local c = LP.Character; return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso")) end

local function isRagdolled(hum)
	if not hum then return true end
	local st = hum:GetState()
	return hum.PlatformStand
		or st == Enum.HumanoidStateType.Physics
		or st == Enum.HumanoidStateType.Ragdoll
		or st == Enum.HumanoidStateType.FallingDown
end

local BAT_NAMES = {
	"Bat", "Slap", "Iron Slap", "Gold Slap", "Diamond Slap", "Emerald Slap",
	"Ruby Slap", "Dark Matter Slap", "Flame Slap", "Nuclear Slap",
	"Galaxy Slap", "Glitched Slap",
}

-- Finds a bat/slap tool, optionally equipping it out of the backpack.
local function findBat(autoEquip)
	local c = char()
	if not c then return nil end

	for _, name in ipairs(BAT_NAMES) do
		local tool = c:FindFirstChild(name)
		if tool and tool:IsA("Tool") then return tool end
	end

	local backpack = LP:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, name in ipairs(BAT_NAMES) do
			local tool = backpack:FindFirstChild(name)
			if tool and tool:IsA("Tool") then
				if autoEquip then
					local hum = c:FindFirstChildOfClass("Humanoid")
					if hum then pcall(function() hum:EquipTool(tool) end) end
				end
				return tool
			end
		end
	end

	for _, obj in ipairs(c:GetChildren()) do
		if obj:IsA("Tool") then
			local n = obj.Name:lower()
			if n:find("bat") or n:find("slap") then return obj end
		end
	end
	return nil
end
Core.findBat = findBat

local function findMedusa()
	local c = char()
	if not c then return nil end
	local function scan(container)
		if not container then return nil end
		for _, tool in ipairs(container:GetChildren()) do
			if tool:IsA("Tool") then
				local n = tool.Name:lower()
				if n:find("medusa") or n:find("head") or n:find("stone") then return tool end
			end
		end
		return nil
	end
	return scan(c) or scan(LP:FindFirstChildOfClass("Backpack"))
end

-- Nearest living player root part, plus the distance to it.
local function closestPlayer()
	local myRoot = root()
	if not myRoot then return nil, math.huge, nil end

	local best, bestDist, bestPlayer = nil, math.huge, nil
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP and plr.Character then
			local targetRoot = plr.Character:FindFirstChild("HumanoidRootPart")
			local hum = plr.Character:FindFirstChildOfClass("Humanoid")
			if targetRoot and hum and hum.Health > 0 then
				local dist = (targetRoot.Position - myRoot.Position).Magnitude
				if dist < bestDist then
					best, bestDist, bestPlayer = targetRoot, dist, plr
				end
			end
		end
	end
	return best, bestDist, bestPlayer
end
Core.closestPlayer = closestPlayer

local function forceReset()
	local c = char()
	local hum = humanoid()
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not c or not hum or not hrp or hum.Health <= 0 then return end

	pcall(function()
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		hrp.Velocity                = Vector3.zero
		hrp.RotVelocity             = Vector3.zero
		hrp.AssemblyLinearVelocity  = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero

		for _, obj in ipairs(c:GetDescendants()) do
			if obj:IsA("Motor6D") or obj:IsA("Constraint") then obj.Enabled = true end
		end

		workspace.CurrentCamera.CameraSubject = hum

		local playerModule = LP:FindFirstChild("PlayerScripts") and LP.PlayerScripts:FindFirstChild("PlayerModule")
		if playerModule then
			local controlModule = require(playerModule:FindFirstChild("ControlModule"))
			if controlModule then controlModule:Enable() end
		end

		hum.AutoRotate     = true
		hum.PlatformStand  = false
		hum.Sit            = false
	end)
end

--==============================================================================
-- Speed engine
--==============================================================================

local speedLV, speedAttachment
local lastMoveDir = Vector3.zero
local autoSwitchWasCarrying = false

local MOVE_KEYS = {
	[Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true,
	[Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true, [Enum.KeyCode.Down] = true,
	[Enum.KeyCode.Left] = true, [Enum.KeyCode.Right] = true,
}

local function profileSpeed()
	local p = cfg.speedProfile
	if p == "lagger"      then return cfg.laggerSpeed end
	if p == "laggerCarry" then return cfg.laggerCarrySpeed end
	if p == "carry"       then return cfg.carrySpeed end
	return cfg.normalSpeed
end

local function autoSwitchSpeed(isCarrying)
	local lagging = cfg.speedProfile == "lagger" or cfg.speedProfile == "laggerCarry"
	if lagging then
		return isCarrying and cfg.laggerCarrySpeed or cfg.laggerSpeed
	end
	return isCarrying and cfg.carrySpeed or cfg.normalSpeed
end

local function pathSpeed()
	local lagging = cfg.speedProfile == "lagger" or cfg.speedProfile == "laggerCarry"
	return lagging and cfg.laggerSpeed or cfg.normalSpeed
end

local function buildSpeedMover(c)
	if speedLV then pcall(function() speedLV:Destroy() end) end
	if speedAttachment then pcall(function() speedAttachment:Destroy() end) end
	speedLV, speedAttachment = nil, nil

	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	speedAttachment = Instance.new("Attachment")
	speedAttachment.Name = "VeltrexSpeedAttachment"
	speedAttachment.Parent = hrp

	speedLV = Instance.new("LinearVelocity")
	speedLV.Name           = "VeltrexSpeedVelocity"
	speedLV.Attachment0    = speedAttachment
	speedLV.RelativeTo     = Enum.ActuatorRelativeTo.World
	speedLV.VectorVelocity = Vector3.zero
	speedLV.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	speedLV.MaxAxesForce   = Vector3.new(100000, 0, 100000)
	speedLV.Enabled        = false
	speedLV.Parent         = hrp
end

local function stopSpeedMover()
	if speedLV then
		speedLV.VectorVelocity = Vector3.zero
		speedLV.Enabled = false
	end
end

-- The mover is suppressed while any pathing/aimbot feature owns the character.
local function speedSuppressed()
	return flags.autoBat or flags.batV2 or flags.autoLeft or flags.autoRight or flags.antiDesync
end

bind(RunService.RenderStepped, function()
	local c = char()
	if not c then return end
	local hum = c:FindFirstChildOfClass("Humanoid")
	local hrp = c:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return end

	if not speedLV or not speedLV.Parent then buildSpeedMover(c) end
	if not speedLV then return end

	state.speed = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude

	if isRagdolled(hum) then
		lastMoveDir = Vector3.zero
		stopSpeedMover()
		return
	end

	if speedSuppressed() then
		stopSpeedMover()
		return
	end

	local speed
	if flags.autoSwitchSpeed then
		speed = autoSwitchSpeed(hum.WalkSpeed < 25)
	else
		speed = profileSpeed()
	end

	local moveDir = hum.MoveDirection
	if moveDir.Magnitude > 0.05 then
		lastMoveDir = moveDir
		speedLV.VectorVelocity = Vector3.new(moveDir.X, 0, moveDir.Z).Unit * speed
		speedLV.Enabled = true
		return
	end

	-- With anti-ragdoll on, keep gliding while a movement key is still held —
	-- MoveDirection drops to zero for a frame whenever the humanoid is reset.
	local held = false
	if flags.antiRagdoll and lastMoveDir.Magnitude > 0.05 then
		for key in pairs(MOVE_KEYS) do
			if UIS:IsKeyDown(key) then held = true break end
		end
	end

	if held then
		speedLV.VectorVelocity = Vector3.new(lastMoveDir.X, 0, lastMoveDir.Z).Unit * speed
		speedLV.Enabled = true
	else
		stopSpeedMover()
	end
end)

-- Auto-switch nudges the current velocity the moment the carry state flips.
task.spawn(function()
	while not Core.unloaded do
		task.wait(0.1)
		pcall(function()
			if not flags.autoSwitchSpeed then return end
			local hum = humanoid()
			local hrp = root()
			if not hum or not hrp then return end

			local carrying = hum.WalkSpeed < 25
			if carrying == autoSwitchWasCarrying then return end
			autoSwitchWasCarrying = carrying

			local moveDir = hum.MoveDirection
			if moveDir.Magnitude > 0 then
				local speed = autoSwitchSpeed(carrying)
				hrp.Velocity = Vector3.new(moveDir.X * speed, hrp.Velocity.Y, moveDir.Z * speed)
			end
		end)
	end
end)

function Core.setSpeedProfile(name)
	if name ~= "normal" and name ~= "carry" and name ~= "lagger" and name ~= "laggerCarry" then
		name = "normal"
	end
	cfg.speedProfile = name
	Core.emit("speedProfile", name)
	Core.save()
end

function Core.toggleSpeedProfile(name)
	Core.setSpeedProfile(cfg.speedProfile == name and "normal" or name)
end

function Core.speedProfileLabel()
	if flags.autoSwitchSpeed then return "Auto Switch" end
	local p = cfg.speedProfile
	if p == "lagger"      then return "Lagger" end
	if p == "laggerCarry" then return "Lagger Carry" end
	if p == "carry"       then return "Carry" end
	return "Normal"
end

--==============================================================================
-- Feature: Infinite Jump
--==============================================================================

local infJumpConn

local function startInfJump()
	infJumpConn = drop(infJumpConn)
	infJumpConn = RunService.Heartbeat:Connect(function()
		local c = char()
		if not c then return end
		local hrp = c:FindFirstChild("HumanoidRootPart")
		local hum = c:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end

		local jumping = UIS:IsKeyDown(Enum.KeyCode.Space) or hum.Jump == true
		if jumping and hrp.Velocity.Y < 35 then
			hrp.Velocity = Vector3.new(hrp.Velocity.X, 55, hrp.Velocity.Z)
		end
		if hrp.Velocity.Y < -120 then
			hrp.Velocity = Vector3.new(hrp.Velocity.X, -120, hrp.Velocity.Z)
		end
	end)
end

local function stopInfJump()
	infJumpConn = drop(infJumpConn)
end

--==============================================================================
-- Feature: Anti Ragdoll
--==============================================================================

local antiRagConn
local lastAntiRagReset = 0

local function startAntiRagdoll()
	antiRagConn = drop(antiRagConn)
	antiRagConn = RunService.Heartbeat:Connect(function()
		local hum = humanoid()
		if not hum or hum.Health <= 0 then return end

		local st = hum:GetState()
		local ragdolled = st == Enum.HumanoidStateType.Physics
			or st == Enum.HumanoidStateType.Ragdoll
			or st == Enum.HumanoidStateType.FallingDown

		if ragdolled then
			local now = tick()
			if now - lastAntiRagReset > 0.15 then
				lastAntiRagReset = now
				forceReset()
			end
		end
	end)
end

local function stopAntiRagdoll()
	antiRagConn = drop(antiRagConn)
end

--==============================================================================
-- Feature: No Collide (walk through other players)
--==============================================================================

-- Loop features use a generation token so a quick off/on never leaves two
-- copies of the same loop running.
local noCollideToken = 0

local function refreshNoCollide()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP and plr.Character then
			for _, part in ipairs(plr.Character:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = false end
			end
		end
	end
end

local function startNoCollide()
	noCollideToken = noCollideToken + 1
	local token = noCollideToken
	task.spawn(function()
		while flags.noCollide and token == noCollideToken do
			pcall(refreshNoCollide)
			task.wait(0.2)
		end
	end)
end

local function stopNoCollide()
	noCollideToken = noCollideToken + 1
end

--==============================================================================
-- Feature: Unwalk (strip the animation script)
--==============================================================================

local savedAnimate

local function startUnwalk()
	local c = char()
	if not c then return end

	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum then
		for _, track in ipairs(hum:GetPlayingAnimationTracks()) do track:Stop() end
	end

	local animate = c:FindFirstChild("Animate")
	if animate then
		savedAnimate = animate:Clone()
		animate:Destroy()
	end
end

local function stopUnwalk()
	local c = char()
	if c and savedAnimate then
		savedAnimate:Clone().Parent = c
		savedAnimate = nil
	end
end

--==============================================================================
-- Feature: Medusa Counter
--==============================================================================

local MEDUSA_COOLDOWN = 25
local medusaConns, medusaBusy, medusaLastUsed = {}, false, 0

local function useMedusa()
	if medusaBusy then return end
	if tick() - medusaLastUsed < MEDUSA_COOLDOWN then return end

	local c = char()
	if not c then return end

	medusaBusy = true
	local medusa = findMedusa()
	if not medusa then
		medusaBusy = false
		return
	end

	if medusa.Parent ~= c then
		local hum = c:FindFirstChildOfClass("Humanoid")
		if hum then hum:EquipTool(medusa) end
	end
	pcall(function() medusa:Activate() end)

	medusaLastUsed = tick()
	medusaBusy = false
end

-- A part going anchored + invisible is how the grab lands on you.
local function watchPart(part)
	return part:GetPropertyChangedSignal("Anchored"):Connect(function()
		if part.Anchored and part.Transparency == 1 then useMedusa() end
	end)
end

local function startMedusaCounter()
	for _, conn in ipairs(medusaConns) do drop(conn) end
	medusaConns = {}

	local c = char()
	if not c then return end

	for _, part in ipairs(c:GetDescendants()) do
		if part:IsA("BasePart") then table.insert(medusaConns, watchPart(part)) end
	end
	table.insert(medusaConns, c.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then table.insert(medusaConns, watchPart(part)) end
	end))
end

local function stopMedusaCounter()
	for _, conn in ipairs(medusaConns) do drop(conn) end
	medusaConns = {}
end

--==============================================================================
-- Feature: Bat Counter (swing back the instant you get ragdolled)
--==============================================================================

local batCounterConn, batCounterBusy = nil, false

local function swingBat(bat, c)
	local hum = c:FindFirstChildOfClass("Humanoid")
	if bat.Parent ~= c then
		if hum then pcall(function() hum:EquipTool(bat) end) end
		task.wait(0.05)
	end

	local remote = bat:FindFirstChildOfClass("RemoteEvent")
	if remote then
		pcall(function() remote:FireServer() end)
		task.wait(0.15)
		pcall(function() remote:FireServer() end)
	else
		pcall(function() bat:Activate() end)
		task.wait(0.15)
		pcall(function() bat:Activate() end)
	end
end

local function startBatCounter()
	batCounterConn = drop(batCounterConn)
	batCounterConn = RunService.Heartbeat:Connect(function()
		if batCounterBusy then return end
		local c = char()
		local hum = humanoid()
		if not c or not hum then return end

		local st = hum:GetState()
		if st == Enum.HumanoidStateType.Physics
			or st == Enum.HumanoidStateType.Ragdoll
			or st == Enum.HumanoidStateType.FallingDown then
			batCounterBusy = true
			task.spawn(function()
				local bat = findBat(false)
				if bat then swingBat(bat, c) end
				task.wait(0.5)
				batCounterBusy = false
			end)
		end
	end)
end

local function stopBatCounter()
	batCounterConn = drop(batCounterConn)
	batCounterBusy = false
end

--==============================================================================
-- Actions: Drop / TP Down / Instant Reset
--==============================================================================

local dropActive = false
local dropConns = {}

local function runStandDrop()
	if dropActive then return end

	Core.setFeature("autoBat", false)
	Core.setFeature("batV2", false)
	dropActive = true

	local colConn = RunService.Stepped:Connect(function()
		if not dropActive then return end
		refreshNoCollide()
	end)
	table.insert(dropConns, colConn)

	local thread = coroutine.create(function()
		while dropActive do
			RunService.Heartbeat:Wait()
			local c = char()
			local hrp = c and c:FindFirstChild("HumanoidRootPart")
			if not hrp then break end

			local vel = hrp.Velocity
			hrp.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)
			RunService.RenderStepped:Wait()
			if hrp.Parent then hrp.Velocity = vel end
			RunService.Stepped:Wait()
			if hrp.Parent then hrp.Velocity = vel + Vector3.new(0, 0.1, 0) end
		end
	end)
	table.insert(dropConns, thread)
	coroutine.resume(thread)

	task.delay(0.1, function()
		dropActive = false
		for _, item in ipairs(dropConns) do
			if typeof(item) == "RBXScriptConnection" then
				item:Disconnect()
			elseif type(item) == "thread" then
				pcall(coroutine.close, item)
			end
		end
		dropConns = {}
	end)
end

local DROP_ASCEND_DURATION = 0.2
local DROP_ASCEND_SPEED    = 150

local function runJumpDrop()
	if dropActive then return end
	local c = char()
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	dropActive = true
	local started = tick()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if not r then
			drop(conn)
			dropActive = false
			return
		end

		if tick() - started >= DROP_ASCEND_DURATION then
			drop(conn)
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = { c }
			params.FilterType = Enum.RaycastFilterType.Exclude

			local hit = workspace:Raycast(r.Position, Vector3.new(0, -2000, 0), params)
			if hit then
				local hum = c:FindFirstChildOfClass("Humanoid")
				local offset = (hum and hum.HipHeight or 2) + (r.Size.Y / 2)
				r.CFrame = CFrame.new(r.Position.X, hit.Position.Y + offset, r.Position.Z)
				r.AssemblyLinearVelocity = Vector3.zero
			end
			dropActive = false
			return
		end

		r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, DROP_ASCEND_SPEED, r.AssemblyLinearVelocity.Z)
	end)
end

local function doDrop()
	if cfg.dropMode == "jump" then runJumpDrop() else runStandDrop() end
end

local tpBusy = false

local function tpDown()
	if tpBusy then return end
	tpBusy = true
	task.spawn(function()
		local c = char()
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if hrp then
			local _, yaw = hrp.CFrame:ToEulerAnglesYXZ()
			hrp.CFrame = CFrame.new(hrp.Position.X, cfg.tpY, hrp.Position.Z) * CFrame.Angles(0, yaw, 0)
			hrp.AssemblyLinearVelocity  = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
			pcall(function() hrp.Velocity = Vector3.zero end)
			if hum then
				hum:ChangeState(Enum.HumanoidStateType.Running)
				hum.PlatformStand = false
			end
		end
		task.wait(0.1)
		tpBusy = false
	end)
end

local autoTPToken = 0

local function startAutoTP()
	autoTPToken = autoTPToken + 1
	local token = autoTPToken
	task.spawn(function()
		while flags.autoTP and token == autoTPToken do
			task.wait(0.1)
			pcall(tpDown)
		end
	end)
end

local function stopAutoTP()
	autoTPToken = autoTPToken + 1
end

-- Instant reset: the game exposes a "RE/..." remote that accepts a reset GUID.
local RESET_GUID = "f888ee6e-c86d-46e1-93d7-0639d6635d42"
local resetRemote = nil

local function findResetRemote()
	if resetRemote and resetRemote.Parent then return resetRemote end
	for _, desc in ipairs(game:GetDescendants()) do
		if desc:IsA("RemoteEvent") and desc.Name:sub(1, 3) == "RE/" then
			resetRemote = desc
			return desc
		end
	end
	return nil
end

local function hookResetRemote()
	if not (exec.hookfunction and exec.newcclosure) then return end

	pcall(function()
		local original
		original = exec.hookfunction(Instance.new("RemoteEvent").FireServer, exec.newcclosure(function(self, ...)
			if not resetRemote and typeof(self) == "Instance" and self:IsA("RemoteEvent")
				and self.Name:sub(1, 3) == "RE/" then
				resetRemote = self
			end
			return original(self, ...)
		end))
	end)
end

local function instantReset()
	local remote = findResetRemote()
	if not remote then
		Core.notify("No reset remote found", "warn")
		return
	end

	local c = char()
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then
		pcall(function() remote:FireServer(RESET_GUID, LP, "balloon") end)
		return
	end

	local resetSeen = false
	local conns = {}

	if hum then
		table.insert(conns, hum.Died:Connect(function() resetSeen = true end))
		table.insert(conns, hum:GetPropertyChangedSignal("Health"):Connect(function()
			if hum.Health <= 0 then resetSeen = true end
		end))
	end
	if c then
		table.insert(conns, c.AncestryChanged:Connect(function(_, parent)
			if not parent then resetSeen = true end
		end))
	end

	task.spawn(function()
		for _ = 1, 50 do
			if resetSeen then break end
			pcall(function() remote:FireServer(RESET_GUID, LP, "balloon") end)
			task.wait()
		end
		for _, conn in ipairs(conns) do drop(conn) end
	end)
end

--==============================================================================
-- Feature: Auto Left / Auto Right (fixed two-leg paths)
--==============================================================================

local PATH = {
	autoLeft  = { Vector3.new(-476.47, -6.28, 92.73), Vector3.new(-483.12, -4.95, 94.81) },
	autoRight = { Vector3.new(-476.16, -6.52, 25.62), Vector3.new(-483.06, -5.03, 25.48) },
}

local pathConns = {}

local function stopPath(id)
	pathConns[id] = drop(pathConns[id])
	local hum = humanoid()
	if hum then hum:Move(Vector3.zero, false) end
end

local function startPath(id)
	pathConns[id] = drop(pathConns[id])

	local waypoints = PATH[id]
	local leg = 1

	pathConns[id] = RunService.Heartbeat:Connect(function()
		if not flags[id] then return end

		local c = char()
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end

		if isRagdolled(hum) then
			hum:Move(Vector3.zero, false)
			return
		end

		local speed  = pathSpeed()
		local target = waypoints[leg]
		local flat   = Vector3.new(target.X, hrp.Position.Y, target.Z)

		if (flat - hrp.Position).Magnitude < 1 then
			if leg == 1 then
				leg = 2
				target = waypoints[2]
			else
				-- Path complete: park and switch the feature off.
				hum:Move(Vector3.zero, false)
				hrp.AssemblyLinearVelocity = Vector3.zero
				Core.setFeature(id, false)
				return
			end
		end

		local delta = target - hrp.Position
		local move  = Vector3.new(delta.X, 0, delta.Z).Unit
		hum:Move(move, false)
		hrp.AssemblyLinearVelocity = Vector3.new(move.X * speed, hrp.AssemblyLinearVelocity.Y, move.Z * speed)
	end)
end

--==============================================================================
-- Combat: Auto Bat aimbot and Bat V2 aimbot
--==============================================================================

-- Shared chase step: fly at the target, face it, return the distance.
local function chaseTarget(hrp, hum, targetPos, predictPos)
	local myPos     = hrp.Position
	local direction = predictPos - myPos
	local flat      = Vector3.new(direction.X, 0, direction.Z)
	flat = flat.Magnitude > 0 and flat.Unit or Vector3.zero

	local desiredHeight = targetPos.Y + cfg.aimbotHeight
	local yVel = (desiredHeight - myPos.Y) * 19.5
	if hum.FloorMaterial ~= Enum.Material.Air then yVel = math.max(yVel, 13) end
	yVel = math.clamp(yVel, -70, 110)

	local desired = Vector3.new(flat.X * cfg.aimbotSpeed, yVel, flat.Z * cfg.aimbotSpeed)
	hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity:Lerp(desired, 0.8)

	local toTarget = predictPos - myPos
	if toTarget.Magnitude > 0.1 then
		hum.AutoRotate = false
		local goal = CFrame.lookAt(myPos, predictPos)
		local diff = hrp.CFrame:Inverse() * goal
		local rx, ry, rz = diff:ToEulerAnglesXYZ()
		rx = math.clamp(rx, -2.5, 2.5)
		ry = math.clamp(ry, -2.5, 2.5)
		rz = math.clamp(rz, -2.5, 2.5)
		hrp.AssemblyAngularVelocity = hrp.CFrame:VectorToWorldSpace(
			Vector3.new(rx * cfg.aimbotTurn, ry * cfg.aimbotTurn, rz * cfg.aimbotTurn)
		)
	end
end

local function releaseCharacter(restoreRotate)
	local c = char()
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if hrp then
		hrp.AssemblyLinearVelocity  = hrp.AssemblyLinearVelocity * 0.3
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
	if hum then
		hum.AutoRotate    = restoreRotate ~= false
		hum.PlatformStand = false
		pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
	end
	state.aimTarget = nil
end

-- Auto Bat ------------------------------------------------------------------

local autoBatConn

local function startAutoBat()
	autoBatConn = drop(autoBatConn)
	autoBatConn = RunService.Heartbeat:Connect(function()
		local c = char()
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end

		if not c:FindFirstChildOfClass("Tool") then
			local bat = findBat(true)
			if bat then pcall(function() hum:EquipTool(bat) end) end
		end

		local target, _, targetPlayer = closestPlayer()
		if not target then
			state.aimTarget = nil
			hum.AutoRotate = true
			hrp.AssemblyAngularVelocity = Vector3.zero
			return
		end
		state.aimTarget = targetPlayer and targetPlayer.Name or nil

		local targetVel = target.AssemblyLinearVelocity
		local lead      = math.clamp(targetVel.Magnitude / 150, 0.05, 0.2)
		local predict   = target.Position + targetVel * lead + target.CFrame.LookVector * 0.3

		chaseTarget(hrp, hum, target.Position, predict)

		if flags.autoSwing then
			local bat = c:FindFirstChildOfClass("Tool")
			if bat then pcall(function() bat:Activate() end) end
		end
	end)
end

local function stopAutoBat()
	autoBatConn = drop(autoBatConn)
	releaseCharacter(true)
end

-- Bat V2 --------------------------------------------------------------------

local batV2Conn, batV2PrevRotate, batV2Cooldown = nil, nil, false

local function swingV2()
	if batV2Cooldown then return end
	batV2Cooldown = true

	pcall(function()
		local c = char()
		if not c then return end
		local bat = findBat(true)
		if not bat then return end
		if bat.Parent ~= c then
			local hum = c:FindFirstChildOfClass("Humanoid")
			if hum then pcall(function() hum:EquipTool(bat) end) end
		end
		pcall(function() bat:Activate() end)
	end)

	task.delay(cfg.swingCooldown, function() batV2Cooldown = false end)
end

local function startBatV2()
	batV2Conn = drop(batV2Conn)

	local hum = humanoid()
	if hum then
		batV2PrevRotate = hum.AutoRotate
		hum.AutoRotate = false
	end

	batV2Conn = RunService.RenderStepped:Connect(function()
		local c = char()
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if not hrp or not h then return end

		if not c:FindFirstChildOfClass("Tool") then
			local bat = findBat(true)
			if bat then pcall(function() h:EquipTool(bat) end) end
		end

		local target, dist, targetPlayer = closestPlayer()
		if not target then
			state.aimTarget = nil
			return
		end
		state.aimTarget = targetPlayer and targetPlayer.Name or nil

		chaseTarget(hrp, h, target.Position, target.Position)

		if dist <= cfg.batHitDistance then swingV2() end
	end)
end

local function stopBatV2()
	batV2Conn = drop(batV2Conn)
	local hum = humanoid()
	if hum then hum.AutoRotate = (batV2PrevRotate == nil) and true or batV2PrevRotate end
	batV2PrevRotate = nil
	batV2Cooldown = false
	releaseCharacter(true)
end

--==============================================================================
-- Feature: Anti-Desync (aimbot + damage negation + reposition)
--==============================================================================

local antiDie = {
	healthThreshold    = 25,
	invincibilityFrames = 0.5,
	loop  = nil,
	health = nil,
	until_ = 0,
}

local function superHeal(hum)
	if not hum then return end
	local maxHealth = hum.MaxHealth or 100
	if hum.Health >= maxHealth and hum.Health > 0 then return end

	hum.Health = maxHealth
	antiDie.until_ = tick() + antiDie.invincibilityFrames

	pcall(function()
		local c = hum.Parent
		if not c then return end
		for _, child in ipairs(c:GetChildren()) do
			if child:IsA("NumberValue") then
				local name = child.Name:lower()
				if name:find("health") or name:find("hp") or name:find("life") then child.Value = 100 end
			elseif child:IsA("BoolValue") and child.Name:lower():find("dead") then
				child.Value = false
			end
		end
	end)
end

local function preventDamage(hrp, hum)
	if not hum then return end

	if tick() < antiDie.until_ and hum.Health < hum.MaxHealth then
		hum.Health = hum.MaxHealth or 100
	end

	if hrp and hrp.Velocity.Y < -25 then
		hrp.Velocity = Vector3.new(hrp.Velocity.X, -3, hrp.Velocity.Z)
		if hum.Health < hum.MaxHealth then superHeal(hum) end
	end

	local st = hum:GetState()
	if st == Enum.HumanoidStateType.Physics
		or st == Enum.HumanoidStateType.Ragdoll
		or st == Enum.HumanoidStateType.FallingDown then
		hum:ChangeState(Enum.HumanoidStateType.Running)
		superHeal(hum)
		if hrp then
			hrp.AssemblyLinearVelocity  = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
	end

	if hum.Health <= 0 then
		superHeal(hum)
		hum:ChangeState(Enum.HumanoidStateType.Running)
		if hrp then
			hrp.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 2, 0))
			hrp.Velocity = Vector3.zero
		end
	end
end

local function startAntiDie()
	antiDie.loop = drop(antiDie.loop)
	antiDie.loop = RunService.Heartbeat:Connect(function()
		if not flags.antiDesync then return end
		local hum = humanoid()
		local hrp = root()
		if not hum then return end

		if hum.Health <= antiDie.healthThreshold then superHeal(hum) end
		preventDamage(hrp, hum)
	end)

	antiDie.health = drop(antiDie.health)
	local hum = humanoid()
	if hum then
		antiDie.health = hum:GetPropertyChangedSignal("Health"):Connect(function()
			if not flags.antiDesync then return end
			if hum.Health <= 0 then
				superHeal(hum)
				hum:ChangeState(Enum.HumanoidStateType.Running)
				local hrp = root()
				if hrp then
					hrp.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 3, 0))
					hrp.Velocity = Vector3.zero
				end
			end
		end)
	end
end

local function stopAntiDie()
	antiDie.loop   = drop(antiDie.loop)
	antiDie.health = drop(antiDie.health)
end

local desync = { conn = nil, chase = nil, cooldown = false, prevRotate = nil }

local function desyncSwing()
	if desync.cooldown then return end
	desync.cooldown = true
	pcall(function()
		local bat = findBat(true)
		if not bat then return end
		bat:Activate()
		local remote = bat:FindFirstChildWhichIsA("RemoteEvent")
		if remote then remote:FireServer() end
	end)
	task.delay(0.08, function() desync.cooldown = false end)
end

local function startAntiDesync()
	stopAntiDie()
	startAntiDie()

	local hum = humanoid()
	if hum then
		if desync.prevRotate == nil then desync.prevRotate = hum.AutoRotate end
		hum.AutoRotate = false
		superHeal(hum)
	end

	-- Chase leg: identical to the bat aimbot, kept separate so the two can run
	-- with different tuning without stepping on each other.
	desync.chase = drop(desync.chase)
	desync.chase = RunService.RenderStepped:Connect(function()
		if not flags.antiDesync then return end
		local c = char()
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if not hrp or not h then return end

		if not c:FindFirstChildOfClass("Tool") then
			local bat = findBat(true)
			if bat then pcall(function() h:EquipTool(bat) end) end
		end

		local target, dist, targetPlayer = closestPlayer()
		if not target then
			state.aimTarget = nil
			return
		end
		state.aimTarget = targetPlayer and targetPlayer.Name or nil

		chaseTarget(hrp, h, target.Position, target.Position)
		if dist <= cfg.batHitDistance then desyncSwing() end
	end)

	-- Desync leg: pin our replicated root to the target and swing on top of it.
	desync.conn = drop(desync.conn)
	desync.conn = RunService.Heartbeat:Connect(function()
		if not flags.antiDesync then return end
		local hrp = root()
		if not hrp then return end

		local target = select(1, closestPlayer())
		if not target then return end

		if exec.sethiddenproperty then
			pcall(function() exec.sethiddenproperty(hrp, "PhysicsRepRootPart", target) end)
		end

		local targetPos = target.Position + Vector3.new(0, 0.9, 0)
		if (hrp.Position - targetPos).Magnitude > 8 then
			hrp.CFrame = CFrame.new(targetPos)
		end

		local cam = workspace.CurrentCamera
		if cam then cam.CFrame = CFrame.new(cam.CFrame.Position, target.Position) end

		desyncSwing()
	end)
end

local function stopAntiDesync()
	desync.conn  = drop(desync.conn)
	desync.chase = drop(desync.chase)
	desync.cooldown = false
	stopAntiDie()

	local hum = humanoid()
	if hum then hum.AutoRotate = (desync.prevRotate == nil) and true or desync.prevRotate end
	desync.prevRotate = nil
	releaseCharacter(true)
end

--==============================================================================
-- Steal engine
--==============================================================================

local Steal = {
	progress = 0,
	animals  = {},        -- shared podium cache
	prompts  = {},        -- uid   -> ProximityPrompt
	handlers = {},        -- prompt -> { hold = {}, trigger = {}, ready = bool }
	scanner  = nil,
	conn     = nil,
	busy     = false,
	lastSteal = 0,
}
Core.Steal = Steal

local function setProgress(p)
	Steal.progress = math.clamp(tonumber(p) or 0, 0, 1)
	Core.emit("progress", Steal.progress)
end

local function isOwnPlot(plotName)
	local plots = workspace:FindFirstChild("Plots")
	local plot  = plots and plots:FindFirstChild(plotName)
	if not plot then return false end

	local sign = plot:FindFirstChild("PlotSign")
	local yourBase = sign and sign:FindFirstChild("YourBase")
	if yourBase and yourBase:IsA("BillboardGui") and yourBase.Enabled then return true end

	local surface = sign and sign:FindFirstChild("SurfaceGui")
	local frame   = surface and surface:FindFirstChild("Frame")
	local label   = frame and frame:FindFirstChild("TextLabel")
	if label and label.Text ~= "Empty Base" then
		local owner = label.Text:gsub("'s [Bb]ase$", ""):gsub("%s+$", "")
		return owner == LP.DisplayName or owner == LP.Name
	end
	return false
end

local function podiumOf(animal)
	local plots   = workspace:FindFirstChild("Plots")
	local plot    = plots and plots:FindFirstChild(animal.plot)
	local podiums = plot and plot:FindFirstChild("AnimalPodiums")
	return podiums and podiums:FindFirstChild(animal.slot) or nil
end

local function animalPosition(animal)
	local podium = podiumOf(animal)
	if not podium then return animal.worldPosition end
	local ok, pivot = pcall(function() return podium:GetPivot().Position end)
	return ok and pivot or animal.worldPosition
end

local function distanceTo(animal)
	local myRoot = root()
	local pos = animalPosition(animal)
	if not myRoot or not pos then return math.huge end
	return (myRoot.Position - pos).Magnitude
end

local function scanPlots()
	local found = {}
	local plots = workspace:FindFirstChild("Plots")
	if not plots then return end

	for _, plot in ipairs(plots:GetChildren()) do
		if plot:IsA("Model") and not isOwnPlot(plot.Name) then
			local podiums = plot:FindFirstChild("AnimalPodiums")
			if podiums then
				for _, podium in ipairs(podiums:GetChildren()) do
					if podium:IsA("Model") then
						local base  = podium:FindFirstChild("Base")
						local spawn = base and base:FindFirstChild("Spawn")
						table.insert(found, {
							name          = podium.Name,
							plot          = plot.Name,
							slot          = podium.Name,
							uid           = plot.Name .. "_" .. podium.Name,
							worldPosition = spawn and spawn.Position or nil,
						})
					end
				end
			end
		end
	end
	Steal.animals = found
end

local scanToken = 0

local function ensureScanner()
	scanToken = scanToken + 1
	local token = scanToken
	task.spawn(function()
		while flags.autoSteal and token == scanToken do
			pcall(scanPlots)
			task.wait(3)
		end
	end)
end

local function promptFor(animal)
	local cached = Steal.prompts[animal.uid]
	if cached and cached.Parent then return cached end

	local podium = podiumOf(animal)
	local base   = podium and podium:FindFirstChild("Base")
	local spawn  = base and base:FindFirstChild("Spawn")
	local attach = spawn and spawn:FindFirstChild("PromptAttachment")
	if not attach then return nil end

	for _, prompt in ipairs(attach:GetChildren()) do
		if prompt:IsA("ProximityPrompt") then
			Steal.prompts[animal.uid] = prompt
			return prompt
		end
	end
	return nil
end

-- The prompt's own client callbacks are what actually perform the steal, so we
-- copy them out once and call them directly instead of holding the key down.
local function handlersFor(prompt)
	local existing = Steal.handlers[prompt]
	if existing then return existing end

	if not exec.getconnections then
		if not Steal.warnedNoGetconnections then
			Steal.warnedNoGetconnections = true
			Core.notify("Your executor has no getconnections — auto steal cannot run", "warn")
		end
		return nil
	end

	local data = { hold = {}, trigger = {}, ready = true }

	local okHold, holds = pcall(exec.getconnections, prompt.PromptButtonHoldBegan)
	if okHold and type(holds) == "table" then
		for _, conn in ipairs(holds) do
			if type(conn.Function) == "function" then table.insert(data.hold, conn.Function) end
		end
	end

	local okTrigger, triggers = pcall(exec.getconnections, prompt.Triggered)
	if okTrigger and type(triggers) == "table" then
		for _, conn in ipairs(triggers) do
			if type(conn.Function) == "function" then table.insert(data.trigger, conn.Function) end
		end
	end

	if #data.hold > 0 or #data.trigger > 0 then
		Steal.handlers[prompt] = data
		return data
	end
	return nil
end

local function fireAll(list)
	for _, fn in ipairs(list) do
		task.spawn(function() pcall(fn) end)
	end
end

-- Normal mode: hold for the fixed duration, then trigger.
local function stealNormal(prompt, animal)
	if not prompt or not prompt.Parent or Steal.busy then return end
	if tick() - Steal.lastSteal < 0.08 then return end

	local data = handlersFor(prompt)
	if not data or not data.ready then return end

	data.ready     = false
	Steal.busy     = true
	Steal.lastSteal = tick()
	state.stealing  = true
	state.stealLabel = animal and animal.name or ""

	task.spawn(function()
		fireAll(data.hold)

		local started  = tick()
		local duration = cfg.stealHold
		while flags.autoSteal and cfg.stealMode == "normal" and tick() - started < duration do
			setProgress((tick() - started) / duration)
			task.wait(0.02)
		end

		if flags.autoSteal and cfg.stealMode == "normal" then
			setProgress(1)
			fireAll(data.trigger)
			task.wait(0.12)
		end

		data.ready  = true
		Steal.busy  = false
		state.stealing = false
		setProgress(0)
	end)
end

-- Semi mode: start the hold from far away, fire the moment you are in range.
local SEMI_HOLD_MIN, SEMI_HOLD_MAX, SEMI_ENTRY_DELAY = 1.3, 2.6, 0.3

local function stealSemi(prompt, animal)
	if not prompt or not prompt.Parent or Steal.busy then return end

	local data = handlersFor(prompt)
	if not data or not data.ready then return end

	data.ready = false
	Steal.busy = true
	state.stealing  = true
	state.stealLabel = animal.name or "Animal"

	task.spawn(function()
		local started = tick()
		fireAll(data.hold)

		while flags.autoSteal and cfg.stealMode == "semi" and tick() - started < SEMI_HOLD_MIN do
			setProgress((tick() - started) / SEMI_HOLD_MAX)
			task.wait()
		end

		local alreadyInRange = distanceTo(animal) <= cfg.semiStealRadius
		local fired = false

		while flags.autoSteal and cfg.stealMode == "semi" and prompt.Parent do
			local elapsed = tick() - started
			if elapsed > SEMI_HOLD_MAX then break end
			setProgress(elapsed / SEMI_HOLD_MAX)

			if distanceTo(animal) <= cfg.semiStealRadius then
				if not alreadyInRange then task.wait(SEMI_ENTRY_DELAY) end
				if flags.autoSteal and cfg.stealMode == "semi" then
					fireAll(data.trigger)
					fired = true
				end
				break
			end
			task.wait()
		end

		if fired then
			setProgress(1)
			Core.notify("Stole " .. tostring(state.stealLabel), "good")
		end

		task.wait(0.05)
		data.ready = true
		Steal.busy = false
		state.stealing = false
		setProgress(0)
	end)
end

local function nearestAnimal(maxRange)
	local myRoot = root()
	if not myRoot then return nil end

	local best, bestDist = nil, math.huge
	for _, animal in ipairs(Steal.animals) do
		local pos = animalPosition(animal)
		if pos and not isOwnPlot(animal.plot) then
			local dist = (myRoot.Position - pos).Magnitude
			if dist < bestDist then best, bestDist = animal, dist end
		end
	end

	if best and bestDist <= maxRange then return best end
	return nil
end

local function startSteal()
	Steal.conn = drop(Steal.conn)
	ensureScanner()
	pcall(scanPlots)

	Steal.conn = RunService.Heartbeat:Connect(function()
		if not flags.autoSteal or Steal.busy then return end

		local semi   = cfg.stealMode == "semi"
		local range  = semi and cfg.primeStealRange or cfg.grabRadius
		local animal = nearestAnimal(range)
		if not animal then return end

		local prompt = promptFor(animal)
		if not prompt then return end

		if semi then stealSemi(prompt, animal) else stealNormal(prompt, animal) end
	end)
end

local function stopSteal()
	Steal.conn = drop(Steal.conn)
	Steal.busy = false
	state.stealing = false
	setProgress(0)
end

--==============================================================================
-- Feature registry
--==============================================================================

local FEATURES = {
	-- id, label, group, hint, conflicts, start, stop
	{ id = "infiniteJump",    label = "Infinite Jump",    hint = "Hold space to keep rising",           start = startInfJump,      stop = stopInfJump },
	{ id = "antiRagdoll",     label = "Anti Ragdoll",     hint = "Force yourself upright instantly",    start = startAntiRagdoll,  stop = stopAntiRagdoll },
	{ id = "noCollide",       label = "No Collide",       hint = "Walk through other players",          start = startNoCollide,    stop = stopNoCollide },
	{ id = "unwalk",          label = "Unwalk",           hint = "Removes the walk animation",          start = startUnwalk,       stop = stopUnwalk },
	{ id = "medusaCounter",   label = "Medusa Counter",   hint = "Auto-medusa when you get grabbed",    start = startMedusaCounter, stop = stopMedusaCounter },
	{ id = "batCounter",      label = "Bat Counter",      hint = "Swing back when ragdolled",           start = startBatCounter,   stop = stopBatCounter },
	{ id = "autoSteal",       label = "Auto Steal",       hint = "Steal from every plot in range",      start = startSteal,        stop = stopSteal },
	{ id = "autoLeft",        label = "Auto Left",        hint = "Walk the left steal path",            conflicts = { "autoRight", "autoBat", "batV2" }, start = function() startPath("autoLeft") end,  stop = function() stopPath("autoLeft") end },
	{ id = "autoRight",       label = "Auto Right",       hint = "Walk the right steal path",           conflicts = { "autoLeft", "autoBat", "batV2" },  start = function() startPath("autoRight") end, stop = function() stopPath("autoRight") end },
	{ id = "autoTP",          label = "Auto TP Down",     hint = "Continuously drop to the floor",      start = startAutoTP,       stop = stopAutoTP },
	{ id = "autoBat",         label = "Auto Bat",         hint = "Chase and hit the nearest player",    conflicts = { "batV2", "antiDesync", "autoLeft", "autoRight" }, start = startAutoBat, stop = stopAutoBat },
	{ id = "autoSwing",       label = "Auto Swing",       hint = "Swing while Auto Bat is chasing" },
	{ id = "batV2",           label = "Bat Aimbot V2",    hint = "Tighter chase, swings on range",      conflicts = { "autoBat", "antiDesync", "autoLeft", "autoRight" }, start = startBatV2, stop = stopBatV2 },
	{ id = "antiDesync",      label = "Anti-Desync",      hint = "Pin to target, negate damage",        conflicts = { "autoBat", "batV2" }, start = startAntiDesync, stop = stopAntiDesync },
	{ id = "autoSwitchSpeed", label = "Auto Switch Speed", hint = "Pick carry/normal speed for you" },
}

local featureById = {}
for _, def in ipairs(FEATURES) do featureById[def.id] = def end

Core.features   = FEATURES
Core.featureById = featureById

local DEFAULT_FEATURES = {
	infiniteJump = true,
	noCollide    = true,
	autoSwing    = true,
}

function Core.setFeature(id, on, silent)
	local def = featureById[id]
	if not def then return end

	on = on and true or false
	if flags[id] == on then return end

	if on and def.conflicts then
		for _, other in ipairs(def.conflicts) do
			if flags[other] then Core.setFeature(other, false) end
		end
	end

	flags[id] = on
	cfg.features[id] = on

	if on then
		if def.start then
			local ok, err = pcall(def.start)
			if not ok then warn("[Veltrex] " .. id .. " failed to start: " .. tostring(err)) end
		end
	else
		if def.stop then pcall(def.stop) end
	end

	if not silent then
		Core.emit("feature", id, on)
		Core.save()
	end
end

function Core.toggleFeature(id)
	Core.setFeature(id, not flags[id])
end

--==============================================================================
-- Actions
--==============================================================================

local ACTIONS = {}

function Core.registerAction(id, label, fn)
	ACTIONS[id] = { id = id, label = label, fn = fn }
end

function Core.runAction(id)
	local action = ACTIONS[id]
	if not action then return end
	local ok, err = pcall(action.fn)
	if not ok then warn("[Veltrex] action '" .. id .. "' failed: " .. tostring(err)) end
end

Core.actions = ACTIONS

Core.registerAction("drop",         "Drop Brainrot", doDrop)
Core.registerAction("tpFloor",      "TP Down",       tpDown)
Core.registerAction("instaReset",   "Instant Reset", instantReset)
Core.registerAction("toggleCarry",  "Carry Speed",   function() Core.toggleSpeedProfile("carry") end)
Core.registerAction("toggleLagger", "Lagger",        function() Core.toggleSpeedProfile("laggerCarry") end)
Core.registerAction("rescan",       "Rescan Plots",  function()
	Steal.prompts  = {}
	Steal.handlers = {}
	pcall(scanPlots)
	Core.notify("Rescanned " .. #Steal.animals .. " podiums", "info")
end)

--==============================================================================
-- Numeric settings and modes
--==============================================================================

local LIMITS = {
	normalSpeed      = { 1, 500 },
	carrySpeed       = { 1, 500 },
	laggerSpeed      = { 1, 500 },
	laggerCarrySpeed = { 1, 500 },
	grabRadius       = { 1, 500 },
	primeStealRange  = { 1, 500 },
	semiStealRadius  = { 1, 200 },
	stealHold        = { 0.1, 10 },
	tpY              = { -500, 500 },
	aimbotSpeed      = { 10, 200 },
	aimbotHeight     = { -10, 30 },
	aimbotTurn       = { 5, 150 },
	batHitDistance   = { 1, 60 },
	swingCooldown    = { 0.05, 2 },
}
Core.limits = LIMITS

function Core.setValue(key, value)
	local limit = LIMITS[key]
	value = tonumber(value)
	if not limit or not value then return cfg[key] end

	value = math.clamp(value, limit[1], limit[2])
	cfg[key] = value
	Core.emit("value", key, value)
	Core.save()
	return value
end

function Core.setMode(key, value)
	if key == "stealMode" and (value == "normal" or value == "semi") then
		cfg.stealMode = value
		if flags.autoSteal then
			stopSteal()
			startSteal()
		end
	elseif key == "dropMode" and (value == "stand" or value == "jump") then
		cfg.dropMode = value
	else
		return
	end
	Core.emit("mode", key, value)
	Core.save()
end

--==============================================================================
-- Keybinds
--==============================================================================

local BINDS = {
	{ id = "toggleUI",     label = "Toggle Menu",   key = Enum.KeyCode.LeftControl, kind = "action",  target = "toggleUI" },
	{ id = "speedToggle",  label = "Carry Speed",   key = Enum.KeyCode.Q,           kind = "action",  target = "toggleCarry" },
	{ id = "laggerToggle", label = "Lagger",        key = Enum.KeyCode.R,           kind = "action",  target = "toggleLagger" },
	{ id = "drop",         label = "Drop Brainrot", key = Enum.KeyCode.X,           kind = "action",  target = "drop" },
	{ id = "tpFloor",      label = "TP Down",       key = Enum.KeyCode.F,           kind = "action",  target = "tpFloor" },
	{ id = "instaReset",   label = "Instant Reset", key = Enum.KeyCode.T,           kind = "action",  target = "instaReset" },
	{ id = "autoLeft",     label = "Auto Left",     key = Enum.KeyCode.Z,           kind = "feature", target = "autoLeft" },
	{ id = "autoRight",    label = "Auto Right",    key = Enum.KeyCode.C,           kind = "feature", target = "autoRight" },
	{ id = "autoBat",      label = "Auto Bat",      key = Enum.KeyCode.E,           kind = "feature", target = "autoBat" },
	{ id = "batV2",        label = "Bat V2",        key = Enum.KeyCode.V,           kind = "feature", target = "batV2" },
	{ id = "antiDesync",   label = "Anti-Desync",   key = Enum.KeyCode.B,           kind = "feature", target = "antiDesync" },
}

local bindById = {}
for _, entry in ipairs(BINDS) do
	bindById[entry.id] = entry
	entry.default = entry.key

	local saved = cfg.keybinds[entry.id]
	if type(saved) == "table" then
		if saved.kb and Enum.KeyCode[saved.kb] then
			entry.key = Enum.KeyCode[saved.kb]
			entry.gamepad = nil
		end
		if saved.gp and Enum.KeyCode[saved.gp] then
			entry.gamepad = Enum.KeyCode[saved.gp]
			entry.key = nil
		end
	end
end

Core.binds    = BINDS
Core.bindById = bindById

function Core.bindLabel(id)
	local entry = bindById[id]
	if not entry then return "None" end
	local code = entry.gamepad or entry.key
	return code and code.Name or "None"
end

function Core.setKeybind(id, keyCode, isGamepad)
	local entry = bindById[id]
	if not entry then return end

	if isGamepad then
		entry.gamepad, entry.key = keyCode, nil
		cfg.keybinds[id] = { gp = keyCode and keyCode.Name or nil }
	else
		entry.key, entry.gamepad = keyCode, nil
		cfg.keybinds[id] = { kb = keyCode and keyCode.Name or nil }
	end

	Core.emit("keybind", id)
	Core.save()
end

function Core.captureInput(on)
	state.inputLocked = on and true or false
end

bind(UIS.InputBegan, function(input, processed)
	if state.inputLocked then return end

	local isGamepad = input.UserInputType.Name:match("^Gamepad") ~= nil
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if processed or UIS:GetFocusedTextBox() then return end
	elseif not isGamepad then
		return
	end

	for _, entry in ipairs(BINDS) do
		local code = isGamepad and entry.gamepad or entry.key
		if code and code == input.KeyCode then
			if entry.kind == "feature" then
				Core.toggleFeature(entry.target)
			else
				Core.runAction(entry.target)
			end
			return
		end
	end
end)

--==============================================================================
-- Character lifecycle
--==============================================================================

bind(LP.CharacterAdded, function(c)
	task.wait(0.5)
	buildSpeedMover(c)

	if flags.medusaCounter then startMedusaCounter() end
	if flags.batCounter    then startBatCounter() end
	if flags.unwalk        then task.wait(0.5) startUnwalk() end

	if flags.batV2 then
		task.wait(0.4)
		stopBatV2()
		startBatV2()
	end
	if flags.antiDesync then
		task.wait(0.2)
		startAntiDie()
	end
end)

--==============================================================================
-- Live telemetry (FPS / ping), polled by the HUD
--==============================================================================

Core.fps  = 60
Core.ping = 0

task.spawn(function()
	local frames, last = 0, tick()
	local conn = RunService.RenderStepped:Connect(function() frames = frames + 1 end)
	table.insert(coreConns, conn)

	while not Core.unloaded do
		task.wait(1)
		local now = tick()
		Core.fps = math.floor(frames / math.max(now - last, 0.001) + 0.5)
		frames, last = 0, now

		local ok = pcall(function()
			Core.ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
		end)
		if not ok then
			pcall(function() Core.ping = math.floor(Stats.Network:GetStatValue("Server Ping") or 0) end)
		end
	end
end)

--==============================================================================
-- Boot
--==============================================================================

function Core.start()
	hookResetRemote()
	task.spawn(function()
		task.wait(2)
		if not resetRemote then findResetRemote() end
	end)

	if LP.Character then buildSpeedMover(LP.Character) end

	-- Restore saved feature states (defaults apply on a fresh install).
	for _, def in ipairs(FEATURES) do
		local saved = cfg.features[def.id]
		if saved == nil then saved = DEFAULT_FEATURES[def.id] end
		if saved then Core.setFeature(def.id, true, true) end
	end

	-- Features were restored quietly above; one sync tells the front-end to
	-- re-read the whole state instead of firing an event per feature.
	Core.emit("sync")
	Core.emit("speedProfile", cfg.speedProfile)
	Core.emit("mode", "stealMode", cfg.stealMode)
	Core.emit("mode", "dropMode", cfg.dropMode)
end

function Core.unload()
	Core.unloaded = true

	for _, def in ipairs(FEATURES) do
		if flags[def.id] and def.stop then pcall(def.stop) end
		flags[def.id] = nil
	end

	for _, conn in ipairs(coreConns) do drop(conn) end
	coreConns = {}

	stopSpeedMover()
	if speedLV then pcall(function() speedLV:Destroy() end) end
	if speedAttachment then pcall(function() speedAttachment:Destroy() end) end

	writeJSON(CONFIG_FILE, cfg)
	Core.emit("unload")
	listeners = {}
end

return Core
end)()

--==============================================================================
-- VeltrexUI (from src/ui.lua)
--==============================================================================

local VeltrexUI = (function(...)
--!nocheck
--[==[
	Veltrex — Interface
	-------------------
	A console, not a settings panel. Nothing in here knows how any feature
	works: it renders state that lives in Core and calls Core's public API.

	Visual language
	  no rounded corners anywhere, no filled cards
	  monospace throughout (Enum.Font.Code)
	  tabs run across the top; content gets the full width
	  toggles are ON/OFF cells with a channel LED in the gutter
	  numbers are segmented meters, not sliders with knobs
	  sections are a label and a rule to the right edge
	  notifications are log lines in the corner, not floating cards

	Pieces
	  Window   top tab strip, command-line filter, dense rows
	  HUD      one 420x26 strip: status, meter, percentage, telemetry
	  Pad      3x4 key grid for touch
	  Log      terminal-style notifications
]==]

local Core = ...

local TS  = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local LP  = Core.LP
local cfg = Core.cfg

local UI = {}

--==============================================================================
-- Persisted interface preferences
--==============================================================================

local prefs = cfg.ui
if type(prefs) ~= "table" then
	prefs = {}
	cfg.ui = prefs
end

local function default(key, value)
	if prefs[key] == nil then prefs[key] = value end
end

default("accent",    { 255, 176, 32 })
default("menuScale", 1)
default("hudScale",  1)
default("padScale",  0.8)
default("locked",    false)
default("showHud",   true)
default("showPad",   UIS.TouchEnabled)
default("windowPos", { xs = 0, xo = 36, ys = 0.5, yo = -186 })
default("hudPos",    { xs = 0.5, xo = -210, ys = 0, yo = 18 })
default("padPos",    { xs = 1, xo = -206, ys = 0.5, yo = -126 })

local function savePrefs()
	Core.save()
end

--==============================================================================
-- Palette
--==============================================================================

local Theme = {
	shell   = Color3.fromRGB(12, 11, 9),    -- window ground, warm black
	inset   = Color3.fromRGB(21, 19, 15),   -- inputs and cells
	wash    = Color3.fromRGB(30, 27, 21),   -- hover
	rule    = Color3.fromRGB(43, 38, 32),   -- hairlines
	ink     = Color3.fromRGB(237, 228, 210),
	sub     = Color3.fromRGB(154, 144, 120),
	dim     = Color3.fromRGB(94, 87, 74),
	danger  = Color3.fromRGB(229, 72, 77),
	accent  = Color3.fromRGB(prefs.accent[1], prefs.accent[2], prefs.accent[3]),
}

-- Console phosphors rather than product hues.
local ACCENTS = {
	{ name = "Amber",    color = Color3.fromRGB(255, 176, 32) },
	{ name = "Phosphor", color = Color3.fromRGB(111, 224, 122) },
	{ name = "Ice",      color = Color3.fromRGB(88, 198, 255) },
	{ name = "Signal",   color = Color3.fromRGB(255, 77, 77) },
	{ name = "Violet",   color = Color3.fromRGB(176, 124, 255) },
	{ name = "Bone",     color = Color3.fromRGB(232, 228, 220) },
}

local accentTargets = {}

local function accented(inst, prop)
	table.insert(accentTargets, { inst = inst, prop = prop })
	inst[prop] = Theme.accent
	return inst
end

local function setAccent(color)
	Theme.accent = color
	prefs.accent = { math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255) }
	for _, target in ipairs(accentTargets) do
		if target.inst and target.inst.Parent then
			pcall(function() target.inst[target.prop] = color end)
		end
	end
	savePrefs()
end

local FONT = Enum.Font.Code

--==============================================================================
-- Instance helpers
--==============================================================================

local function new(class, props, children)
	local inst = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	for key, value in pairs(props) do
		inst[key] = value
	end
	if children then
		for _, child in ipairs(children) do child.Parent = inst end
	end
	if parent then inst.Parent = parent end
	return inst
end

local function stroke(inst, color, transparency)
	return new("UIStroke", {
		Color           = color or Theme.rule,
		Thickness       = 1,
		Transparency    = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent          = inst,
	})
end

local function pad(inst, left, right, top, bottom)
	return new("UIPadding", {
		PaddingLeft   = UDim.new(0, left or 0),
		PaddingRight  = UDim.new(0, right or left or 0),
		PaddingTop    = UDim.new(0, top or 0),
		PaddingBottom = UDim.new(0, bottom or top or 0),
		Parent        = inst,
	})
end

local function list(inst, spacing, direction)
	return new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder     = Enum.SortOrder.LayoutOrder,
		Padding       = UDim.new(0, spacing or 0),
		Parent        = inst,
	})
end

local function text(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font           = props.Font or FONT
	props.TextColor3     = props.TextColor3 or Theme.ink
	props.TextSize       = props.TextSize or 12
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return new("TextLabel", props)
end

-- A one pixel hairline. Everything in this interface is separated by these
-- rather than by card edges.
local function rule(parent, y, transparency, inset)
	inset = inset or 0
	return new("Frame", {
		Size                   = UDim2.new(1, -inset * 2, 0, 1),
		Position               = UDim2.new(0, inset, 0, y or 0),
		BackgroundColor3       = Theme.rule,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel        = 0,
		Parent                 = parent,
	})
end

local function tween(inst, time, goal, style)
	local t = TS:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function udim2From(t, fallback)
	if type(t) ~= "table" then return fallback end
	return UDim2.new(tonumber(t.xs) or 0, tonumber(t.xo) or 0, tonumber(t.ys) or 0, tonumber(t.yo) or 0)
end

local function udim2To(u)
	return { xs = u.X.Scale, xo = u.X.Offset, ys = u.Y.Scale, yo = u.Y.Offset }
end

local function spaced(word)
	return (word:gsub("(.)", "%1 "):gsub(" $", ""))
end

--==============================================================================
-- GUI root
--==============================================================================

local OLD_GUIS = {
	"VeltrexUI", "VeltrexHUD", "VeltrexPad",
	"VeltrexHub", "VeltrexMobileButtons", "StealBarGui",
}

local function guiParent()
	local ok, hidden = pcall(function() return gethui() end)
	if ok and typeof(hidden) == "Instance" then return hidden end
	return LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")
end

local root = guiParent()

for _, container in ipairs({ root, LP:FindFirstChildOfClass("PlayerGui") }) do
	if container then
		for _, name in ipairs(OLD_GUIS) do
			local old = container:FindFirstChild(name)
			while old do
				old:Destroy()
				old = container:FindFirstChild(name)
			end
		end
	end
end

local function screen(name, order)
	return new("ScreenGui", {
		Name           = name,
		ResetOnSpawn   = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder   = order or 100,
		Parent         = root,
	})
end

local screenMain = screen("VeltrexUI", 1000)
local screenHud  = screen("VeltrexHUD", 990)
local screenPad  = screen("VeltrexPad", 995)

local hud, hudScaleObj
local padFrame, padScaleObj

--==============================================================================
-- Dragging
--==============================================================================

local uiConns = {}

local function track(conn)
	table.insert(uiConns, conn)
	return conn
end

local function draggable(frame, handle, onFinished)
	handle = handle or frame
	local dragging, origin, startPos = false, nil, nil

	track(handle.InputBegan:Connect(function(input)
		if prefs.locked then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then return end

		dragging = true
		origin   = input.Position
		startPos = frame.Position

		local ended
		ended = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				ended:Disconnect()
				if onFinished then onFinished(frame.Position) end
			end
		end)
	end))

	track(UIS.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then return end

		local delta = input.Position - origin
		frame.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end))
end

--==============================================================================
-- Log lines (notifications)
--==============================================================================

local logHolder = new("Frame", {
	Name                   = "Log",
	AnchorPoint            = Vector2.new(0, 1),
	Position               = UDim2.new(0, 16, 1, -16),
	Size                   = UDim2.new(0, 320, 0, 120),
	BackgroundTransparency = 1,
	Parent                 = screenMain,
})
new("UIListLayout", {
	SortOrder         = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	Padding           = UDim.new(0, 2),
	Parent            = logHolder,
})

function UI.toast(message, kind)
	local color = Theme.accent
	if kind == "warn" then color = Color3.fromRGB(246, 190, 80) end
	if kind == "bad"  then color = Theme.danger end

	local line = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, 18),
		BackgroundColor3       = Theme.shell,
		BackgroundTransparency = 0.15,
		BorderSizePixel        = 0,
		Parent                 = logHolder,
	})

	new("Frame", {
		Size             = UDim2.new(0, 2, 1, 0),
		BackgroundColor3 = color,
		BorderSizePixel  = 0,
		Parent           = line,
	})

	local label = text({
		Text     = "> " .. string.upper(message),
		TextSize = 10,
		TextColor3 = Theme.sub,
		Position = UDim2.new(0, 8, 0, 0),
		Size     = UDim2.new(1, -10, 1, 0),
		Parent   = line,
	})

	task.delay(3, function()
		if not line.Parent then return end
		tween(line, 0.25, { BackgroundTransparency = 1 })
		tween(label, 0.25, { TextTransparency = 1 })
		task.delay(0.3, function() line:Destroy() end)
	end)
end

--==============================================================================
-- State fan-out
--==============================================================================

local featureWatchers, valueWatchers, modeWatchers, profileWatchers = {}, {}, {}, {}

local function watchFeature(id, fn)
	featureWatchers[id] = featureWatchers[id] or {}
	table.insert(featureWatchers[id], fn)
	fn(Core.isOn(id))
end

local function watchValue(key, fn)
	valueWatchers[key] = valueWatchers[key] or {}
	table.insert(valueWatchers[key], fn)
	fn(cfg[key])
end

local function watchMode(key, fn)
	modeWatchers[key] = modeWatchers[key] or {}
	table.insert(modeWatchers[key], fn)
	fn(cfg[key])
end

local function watchProfile(fn)
	table.insert(profileWatchers, fn)
	fn(cfg.speedProfile)
end

local function refreshAll()
	for id, watchers in pairs(featureWatchers) do
		for _, fn in ipairs(watchers) do pcall(fn, Core.isOn(id)) end
	end
	for key, watchers in pairs(valueWatchers) do
		for _, fn in ipairs(watchers) do pcall(fn, cfg[key]) end
	end
	for key, watchers in pairs(modeWatchers) do
		for _, fn in ipairs(watchers) do pcall(fn, cfg[key]) end
	end
	for _, fn in ipairs(profileWatchers) do pcall(fn, cfg.speedProfile) end
end

Core.on("sync", refreshAll)
Core.on("feature", function(id, on)
	for _, fn in ipairs(featureWatchers[id] or {}) do pcall(fn, on) end
end)
Core.on("value", function(key, value)
	for _, fn in ipairs(valueWatchers[key] or {}) do pcall(fn, value) end
end)
Core.on("mode", function(key, value)
	for _, fn in ipairs(modeWatchers[key] or {}) do pcall(fn, value) end
end)
Core.on("speedProfile", function(name)
	for _, fn in ipairs(profileWatchers) do pcall(fn, name) end
end)
Core.on("notify", function(message, kind) UI.toast(message, kind) end)

--==============================================================================
-- Window shell
--==============================================================================

local WINDOW_W, WINDOW_H = 640, 372
local HEADER_H, TABS_H, FOOTER_H = 34, 28, 24

local window = new("Frame", {
	Name             = "Console",
	Size             = UDim2.new(0, WINDOW_W, 0, WINDOW_H),
	Position         = udim2From(prefs.windowPos, UDim2.new(0, 36, 0.5, -WINDOW_H / 2)),
	BackgroundColor3 = Theme.shell,
	BorderSizePixel  = 0,
	Active           = true,
	Parent           = screenMain,
})
stroke(window, Theme.rule, 0)

local windowScale = new("UIScale", { Scale = prefs.menuScale, Parent = window })

-- Corner brackets: the console's only ornament. Each corner is an L drawn
-- from two 9x1 bars, inset five pixels from the edge.
for _, corner in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
	local sx, sy = corner[1], corner[2]
	local nearX = sx == 0 and 5 or -14   -- start of a horizontal bar
	local nearY = sy == 0 and 5 or -6    -- the edge the bar sits on

	accented(new("Frame", {
		Size             = UDim2.new(0, 9, 0, 1),
		Position         = UDim2.new(sx, nearX, sy, nearY),
		BackgroundColor3 = Theme.accent,
		BorderSizePixel  = 0,
		Parent           = window,
	}), "BackgroundColor3")

	accented(new("Frame", {
		Size             = UDim2.new(0, 1, 0, 9),
		Position         = UDim2.new(sx, sx == 0 and 5 or -6, sy, sy == 0 and 5 or -14),
		BackgroundColor3 = Theme.accent,
		BorderSizePixel  = 0,
		Parent           = window,
	}), "BackgroundColor3")
end

-- Header ---------------------------------------------------------------------

local header = new("Frame", {
	Name                   = "Header",
	Size                   = UDim2.new(1, 0, 0, HEADER_H),
	BackgroundTransparency = 1,
	Parent                 = window,
})

accented(text({
	Text     = spaced("VELTREX"),
	TextSize = 13,
	Position = UDim2.new(0, 16, 0, 0),
	Size     = UDim2.new(0, 120, 1, 0),
	Parent   = header,
}), "TextColor3")

new("Frame", {
	Size             = UDim2.new(0, 1, 0, 12),
	Position         = UDim2.new(0, 118, 0, 11),
	BackgroundColor3 = Theme.rule,
	BorderSizePixel  = 0,
	Parent           = header,
})

text({
	Text       = "STEAL A BRAINROT",
	TextSize   = 10,
	TextColor3 = Theme.dim,
	Position   = UDim2.new(0, 128, 0, 0),
	Size       = UDim2.new(0, 160, 1, 0),
	Parent     = header,
})

local headerStats = text({
	Text           = "",
	TextSize       = 10,
	TextColor3     = Theme.sub,
	TextXAlignment = Enum.TextXAlignment.Right,
	Position       = UDim2.new(1, -230, 0, 0),
	Size           = UDim2.new(0, 180, 1, 0),
	Parent         = header,
})

local function headerButton(glyph, offset, onClick)
	local button = new("TextButton", {
		Size                   = UDim2.new(0, 18, 0, 18),
		Position               = UDim2.new(1, offset, 0, 8),
		BackgroundColor3       = Theme.inset,
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		AutoButtonColor        = false,
		Text                   = glyph,
		TextColor3             = Theme.dim,
		Font                   = FONT,
		TextSize               = 11,
		Parent                 = header,
	})
	stroke(button, Theme.rule, 0.35)

	track(button.MouseEnter:Connect(function()
		tween(button, 0.1, { BackgroundTransparency = 0, TextColor3 = Theme.ink })
	end))
	track(button.MouseLeave:Connect(function()
		tween(button, 0.1, { BackgroundTransparency = 1, TextColor3 = Theme.dim })
	end))
	track(button.MouseButton1Click:Connect(onClick))
	return button
end

rule(header, HEADER_H - 1)

draggable(window, header, function(position)
	prefs.windowPos = udim2To(position)
	savePrefs()
end)

-- Tab strip ------------------------------------------------------------------

local tabStrip = new("Frame", {
	Name                   = "Tabs",
	Position               = UDim2.new(0, 0, 0, HEADER_H),
	Size                   = UDim2.new(1, 0, 0, TABS_H),
	BackgroundTransparency = 1,
	Parent                 = window,
})
pad(tabStrip, 12, 12, 0, 0)
list(tabStrip, 2, Enum.FillDirection.Horizontal)

rule(window, HEADER_H + TABS_H - 1)

-- Content --------------------------------------------------------------------

local CONTENT_Y = HEADER_H + TABS_H + 8
local CONTENT_H = WINDOW_H - CONTENT_Y - FOOTER_H - 4

local contentArea = new("Frame", {
	Name                   = "Content",
	Position               = UDim2.new(0, 14, 0, CONTENT_Y),
	Size                   = UDim2.new(1, -28, 0, CONTENT_H),
	BackgroundTransparency = 1,
	Parent                 = window,
})

accented(text({
	Text     = ">",
	TextSize = 12,
	Size     = UDim2.new(0, 10, 0, 20),
	Parent   = contentArea,
}), "TextColor3")

local searchBox = new("TextBox", {
	Position               = UDim2.new(0, 16, 0, 0),
	Size                   = UDim2.new(1, -16, 0, 20),
	BackgroundTransparency = 1,
	Text                   = "",
	PlaceholderText        = "filter",
	PlaceholderColor3      = Theme.dim,
	TextColor3             = Theme.ink,
	Font                   = FONT,
	TextSize               = 12,
	TextXAlignment         = Enum.TextXAlignment.Left,
	ClearTextOnFocus       = false,
	Parent                 = contentArea,
})

rule(contentArea, 22, 0.4)

local pageHolder = new("Frame", {
	Position               = UDim2.new(0, 0, 0, 30),
	Size                   = UDim2.new(1, 0, 1, -30),
	BackgroundTransparency = 1,
	Parent                 = contentArea,
})

-- Footer ---------------------------------------------------------------------

rule(window, WINDOW_H - FOOTER_H)

local footerLeft = text({
	Text       = "",
	TextSize   = 10,
	TextColor3 = Theme.dim,
	Position   = UDim2.new(0, 16, 1, -FOOTER_H),
	Size       = UDim2.new(0.5, 0, 0, FOOTER_H),
	Parent     = window,
})

local footerRight = text({
	Text           = "",
	TextSize       = 10,
	TextColor3     = Theme.dim,
	TextXAlignment = Enum.TextXAlignment.Right,
	Position       = UDim2.new(0.5, -16, 1, -FOOTER_H),
	Size           = UDim2.new(0.5, 0, 0, FOOTER_H),
	Parent         = window,
})

--==============================================================================
-- Tabs, sections, rows
--==============================================================================

local tabs, activeTab = {}, nil

local function selectTab(tab)
	if activeTab == tab then return end
	for _, other in ipairs(tabs) do
		other.page.Visible = other == tab
		other.underline.BackgroundTransparency = other == tab and 0 or 1
		other.label.TextColor3 = other == tab and Theme.ink or Theme.dim
	end
	activeTab = tab
end

local function addTab(name)
	local index = #tabs + 1
	local width = #name * 7 + 18

	local button = new("TextButton", {
		Size                   = UDim2.new(0, width, 1, 0),
		BackgroundColor3       = Theme.wash,
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		AutoButtonColor        = false,
		Text                   = "",
		LayoutOrder            = index,
		Parent                 = tabStrip,
	})

	local caption = text({
		Text           = name,
		TextSize       = 11,
		TextColor3     = Theme.dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size           = UDim2.new(1, 0, 1, 0),
		Parent         = button,
	})

	local underline = new("Frame", {
		Size                   = UDim2.new(1, -8, 0, 2),
		Position               = UDim2.new(0, 4, 1, -3),
		BackgroundColor3       = Theme.accent,
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		Parent                 = button,
	})
	accented(underline, "BackgroundColor3")

	local page = new("ScrollingFrame", {
		Size                   = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		Visible                = false,
		CanvasSize             = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize    = Enum.AutomaticSize.Y,
		ScrollBarThickness     = 2,
		ScrollBarImageColor3   = Theme.rule,
		ScrollingDirection     = Enum.ScrollingDirection.Y,
		Parent                 = pageHolder,
	})
	list(page, 10)
	pad(page, 0, 10, 0, 14)

	local tab = {
		name = name, index = index, button = button, label = caption,
		underline = underline, page = page, sections = {},
	}
	tabs[index] = tab

	track(button.MouseButton1Click:Connect(function() selectTab(tab) end))
	track(button.MouseEnter:Connect(function()
		if activeTab ~= tab then caption.TextColor3 = Theme.sub end
	end))
	track(button.MouseLeave:Connect(function()
		if activeTab ~= tab then caption.TextColor3 = Theme.dim end
	end))

	return tab
end

-- Section header: a label, then a rule out to the right edge.
local function addSection(tab, title)
	local section = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, 0),
		AutomaticSize          = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder            = #tab.sections + 1,
		Parent                 = tab.page,
	})
	list(section, 0)

	local head = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		LayoutOrder            = 0,
		Parent                 = section,
	})

	accented(text({
		Text     = string.upper(title),
		TextSize = 10,
		Size     = UDim2.new(0, 120, 1, 0),
		Parent   = head,
	}), "TextColor3")

	new("Frame", {
		Size                   = UDim2.new(1, -126, 0, 1),
		Position               = UDim2.new(0, 126, 0.5, 0),
		BackgroundColor3       = Theme.rule,
		BackgroundTransparency = 0.25,
		BorderSizePixel        = 0,
		Parent                 = head,
	})

	local entry = { frame = section, rows = {}, tab = tab }
	table.insert(tab.sections, entry)
	return entry
end

-- Rows are flush lines: a gutter LED, a label, a control, a hairline below.
local function addRow(section, label, hint, height)
	height = height or (hint and 40 or 30)

	local row = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, height),
		BackgroundColor3       = Theme.wash,
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		LayoutOrder            = #section.rows + 1,
		Parent                 = section.frame,
	})

	local led = new("Frame", {
		Size                   = UDim2.new(0, 5, 0, 5),
		Position               = UDim2.new(0, 2, 0, hint and 12 or 13),
		BackgroundColor3       = Theme.rule,
		BorderSizePixel        = 0,
		Visible                = false,
		Parent                 = row,
	})

	text({
		Text     = label,
		TextSize = 12,
		Position = UDim2.new(0, 16, 0, hint and 6 or 0),
		Size     = UDim2.new(1, -200, 0, hint and 14 or height),
		Parent   = row,
	})

	if hint then
		text({
			Text       = hint,
			TextSize   = 10,
			TextColor3 = Theme.dim,
			Position   = UDim2.new(0, 16, 0, 21),
			Size       = UDim2.new(1, -200, 0, 12),
			Parent     = row,
		})
	end

	rule(row, height - 1, 0.55)

	track(row.MouseEnter:Connect(function() tween(row, 0.1, { BackgroundTransparency = 0.5 }) end))
	track(row.MouseLeave:Connect(function() tween(row, 0.1, { BackgroundTransparency = 1 }) end))

	table.insert(section.rows, { frame = row, text = (label .. " " .. (hint or "")):lower() })
	return row, led
end

--==============================================================================
-- Controls
--==============================================================================

-- ON / OFF cell plus the channel LED in the gutter.
local function makeToggle(section, opts)
	local row, led = addRow(section, opts.label, opts.hint)
	led.Visible = true

	local cell = new("TextButton", {
		Size                   = UDim2.new(0, 46, 0, 18),
		Position               = UDim2.new(1, -46, 0.5, -9),
		BackgroundColor3       = Theme.accent,
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		AutoButtonColor        = false,
		Text                   = "OFF",
		TextColor3             = Theme.dim,
		Font                   = FONT,
		TextSize               = 10,
		Parent                 = row,
	})
	local cellStroke = stroke(cell, Theme.rule, 0)
	accented(cell, "BackgroundColor3")

	local hit = new("TextButton", {
		Size                   = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text                   = "",
		Parent                 = row,
	})

	local function render(on)
		cell.Text = on and "ON" or "OFF"
		tween(cell, 0.12, {
			BackgroundTransparency = on and 0 or 1,
			TextColor3             = on and Theme.shell or Theme.dim,
		})
		tween(cellStroke, 0.12, { Color = on and Theme.accent or Theme.rule })
		tween(led, 0.12, { BackgroundColor3 = on and Theme.accent or Theme.rule })
	end

	local function flip()
		if opts.feature then
			Core.toggleFeature(opts.feature)
		elseif opts.get and opts.set then
			opts.set(not opts.get())
			render(opts.get())
		end
	end

	track(cell.MouseButton1Click:Connect(flip))
	track(hit.MouseButton1Click:Connect(flip))

	if opts.feature then
		watchFeature(opts.feature, render)
	else
		render(opts.get and opts.get() or false)
	end

	return row
end

local function makeButton(section, opts)
	local row = addRow(section, opts.label, opts.hint)
	local width = opts.width or 74
	local color = opts.danger and Theme.danger or Theme.accent

	local button = new("TextButton", {
		Size                   = UDim2.new(0, width, 0, 18),
		Position               = UDim2.new(1, -width, 0.5, -9),
		BackgroundColor3       = color,
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		AutoButtonColor        = false,
		Text                   = string.upper(opts.button or "RUN"),
		TextColor3             = color,
		Font                   = FONT,
		TextSize               = 10,
		Parent                 = row,
	})
	local buttonStroke = stroke(button, color, 0.3)
	if not opts.danger then
		accented(button, "BackgroundColor3")
		accented(button, "TextColor3")
		accented(buttonStroke, "Color")
	end

	track(button.MouseEnter:Connect(function()
		tween(button, 0.1, { BackgroundTransparency = 0.85 })
	end))
	track(button.MouseLeave:Connect(function()
		tween(button, 0.1, { BackgroundTransparency = 1 })
	end))
	track(button.MouseButton1Click:Connect(function()
		button.BackgroundTransparency = 0
		button.TextColor3 = Theme.shell
		task.delay(0.12, function()
			button.BackgroundTransparency = 1
			button.TextColor3 = opts.danger and Theme.danger or Theme.accent
		end)
		if opts.action then Core.runAction(opts.action) end
		if opts.onClick then opts.onClick() end
	end))

	return row
end

local function makeSegmented(section, opts)
	local row = addRow(section, opts.label, opts.hint)

	local count = #opts.options
	local width = opts.width or 58
	local total = count * width + (count - 1) * 2

	local holder = new("Frame", {
		Size                   = UDim2.new(0, total, 0, 18),
		Position               = UDim2.new(1, -total, 0.5, -9),
		BackgroundTransparency = 1,
		Parent                 = row,
	})

	local cells = {}
	for index, option in ipairs(opts.options) do
		local cell = new("TextButton", {
			Size                   = UDim2.new(0, width, 1, 0),
			Position               = UDim2.new(0, (index - 1) * (width + 2), 0, 0),
			BackgroundColor3       = Theme.accent,
			BackgroundTransparency = 1,
			BorderSizePixel        = 0,
			AutoButtonColor        = false,
			Text                   = string.upper(option.label),
			TextColor3             = Theme.dim,
			Font                   = FONT,
			TextSize               = 10,
			Parent                 = holder,
		})
		local cellStroke = stroke(cell, Theme.rule, 0)
		accented(cell, "BackgroundColor3")
		cells[index] = { cell = cell, stroke = cellStroke }

		track(cell.MouseButton1Click:Connect(function() opts.onSelect(option.value) end))
	end

	local function render(value)
		for index, option in ipairs(opts.options) do
			local on = option.value == value
			tween(cells[index].cell, 0.12, {
				BackgroundTransparency = on and 0 or 1,
				TextColor3             = on and Theme.shell or Theme.dim,
			})
			cells[index].stroke.Color = on and Theme.accent or Theme.rule
		end
	end

	return row, render
end

-- Numbers are segmented meters. Twenty cells, click or drag anywhere on them.
local METER_CELLS = 20
local CELL_W, CELL_GAP = 5, 1

local function makeMeter(section, opts)
	local limits   = (opts.key and Core.limits[opts.key]) or { opts.min or 0, opts.max or 100 }
	local minimum  = opts.min or limits[1]
	local maximum  = opts.max or limits[2]
	local step     = opts.step or 1
	local decimals = opts.decimals or (step < 1 and 2 or 0)

	local row = addRow(section, opts.label, opts.hint)

	local readout = new("TextBox", {
		Size                   = UDim2.new(0, 46, 0, 18),
		Position               = UDim2.new(1, -46, 0.5, -9),
		BackgroundTransparency = 1,
		Text                   = "0",
		TextColor3             = Theme.ink,
		Font                   = FONT,
		TextSize               = 11,
		TextXAlignment         = Enum.TextXAlignment.Right,
		ClearTextOnFocus       = false,
		Parent                 = row,
	})

	local meterW = METER_CELLS * CELL_W + (METER_CELLS - 1) * CELL_GAP
	local meter = new("Frame", {
		Size                   = UDim2.new(0, meterW, 0, 10),
		Position               = UDim2.new(1, -(meterW + 56), 0.5, -5),
		BackgroundTransparency = 1,
		Parent                 = row,
	})

	local cells = {}
	for index = 1, METER_CELLS do
		cells[index] = new("Frame", {
			Size             = UDim2.new(0, CELL_W, 1, 0),
			Position         = UDim2.new(0, (index - 1) * (CELL_W + CELL_GAP), 0, 0),
			BackgroundColor3 = Theme.rule,
			BorderSizePixel  = 0,
			Parent           = meter,
		})
	end

	local hit = new("TextButton", {
		Size                   = UDim2.new(1, 0, 0, 22),
		Position               = UDim2.new(0, 0, 0.5, -11),
		BackgroundTransparency = 1,
		Text                   = "",
		Parent                 = meter,
	})

	local function format(value)
		if decimals > 0 then return string.format("%." .. decimals .. "f", value) end
		return tostring(math.floor(value + 0.5))
	end

	local function render(value)
		local alpha = math.clamp((value - minimum) / math.max(maximum - minimum, 0.0001), 0, 1)
		local lit = math.floor(alpha * METER_CELLS + 0.5)
		for index = 1, METER_CELLS do
			cells[index].BackgroundColor3 = index <= lit and Theme.accent or Theme.rule
		end
		if not readout:IsFocused() then readout.Text = format(value) end
	end

	local function commit(value)
		value = math.clamp(value, minimum, maximum)
		value = math.floor(value / step + 0.5) * step
		if opts.key then
			value = Core.setValue(opts.key, value) or value
		elseif opts.set then
			opts.set(value)
		end
		render(value)
	end

	local dragging = false

	local function fromInput(input)
		local alpha = (input.Position.X - meter.AbsolutePosition.X) / math.max(meter.AbsoluteSize.X, 1)
		commit(minimum + math.clamp(alpha, 0, 1) * (maximum - minimum))
	end

	track(hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromInput(input)
		end
	end))
	track(UIS.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			fromInput(input)
		end
	end))
	track(UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	local function current()
		if opts.key then return cfg[opts.key] end
		return opts.get and opts.get() or minimum
	end

	track(readout.FocusLost:Connect(function()
		local typed = tonumber(readout.Text)
		if typed then commit(typed) else render(current()) end
	end))

	if opts.key then watchValue(opts.key, render) else render(current()) end
	return row
end

local function makeKeybind(section, bind)
	local row = addRow(section, bind.label)

	local button = new("TextButton", {
		Size                   = UDim2.new(0, 96, 0, 18),
		Position               = UDim2.new(1, -96, 0.5, -9),
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		AutoButtonColor        = false,
		Text                   = "[ " .. string.upper(Core.bindLabel(bind.id)) .. " ]",
		TextColor3             = Theme.sub,
		Font                   = FONT,
		TextSize               = 10,
		Parent                 = row,
	})

	local listening, listener, blink = false, nil, nil

	local function stopListening()
		listening = false
		blink = nil
		Core.captureInput(false)
		if listener then
			listener:Disconnect()
			listener = nil
		end
		button.Text = "[ " .. string.upper(Core.bindLabel(bind.id)) .. " ]"
		button.TextColor3 = Theme.sub
	end

	track(button.MouseButton1Click:Connect(function()
		if listening then
			stopListening()
			return
		end

		listening = true
		Core.captureInput(true)
		button.TextColor3 = Theme.accent

		blink = task.spawn(function()
			local shown = true
			while listening do
				button.Text = shown and "[ ... ]" or "[     ]"
				shown = not shown
				task.wait(0.4)
			end
		end)

		listener = UIS.InputBegan:Connect(function(input)
			local isGamepad = input.UserInputType.Name:match("^Gamepad") ~= nil
			if input.UserInputType ~= Enum.UserInputType.Keyboard and not isGamepad then return end

			if input.KeyCode == Enum.KeyCode.Escape then
				stopListening()
				return
			end
			if input.KeyCode == Enum.KeyCode.Unknown then return end

			Core.setKeybind(bind.id, input.KeyCode, isGamepad)
			stopListening()
		end)
	end))

	Core.on("keybind", function(id)
		if id == bind.id and not listening then
			button.Text = "[ " .. string.upper(Core.bindLabel(bind.id)) .. " ]"
		end
	end)

	return row
end

--==============================================================================
-- Pages
--==============================================================================

local tabDashboard = addTab("STATUS")
local tabSpeed     = addTab("SPEED")
local tabCombat    = addTab("COMBAT")
local tabSteal     = addTab("STEAL")
local tabMovement  = addTab("MOVE")
local tabKeybinds  = addTab("KEYS")
local tabSettings  = addTab("CONFIG")

-- Status ---------------------------------------------------------------------

local statCells = {}

do
	local section = addSection(tabDashboard, "Telemetry")

	local block = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		LayoutOrder            = 1,
		Parent                 = section.frame,
	})
	stroke(block, Theme.rule, 0.35)
	table.insert(section.rows, { frame = block, text = "fps ping speed profile telemetry" })

	local names = { "FPS", "PING", "SPEED", "PROFILE" }
	for index, name in ipairs(names) do
		local column = new("Frame", {
			Size                   = UDim2.new(0.25, 0, 1, 0),
			Position               = UDim2.new(0.25 * (index - 1), 0, 0, 0),
			BackgroundTransparency = 1,
			Parent                 = block,
		})

		if index > 1 then
			new("Frame", {
				Size                   = UDim2.new(0, 1, 1, -16),
				Position               = UDim2.new(0, 0, 0, 8),
				BackgroundColor3       = Theme.rule,
				BackgroundTransparency = 0.35,
				BorderSizePixel        = 0,
				Parent                 = column,
			})
		end

		text({
			Text       = name,
			TextSize   = 9,
			TextColor3 = Theme.dim,
			Position   = UDim2.new(0, 12, 0, 8),
			Size       = UDim2.new(1, -14, 0, 12),
			Parent     = column,
		})

		statCells[name] = text({
			Text     = "--",
			TextSize = 14,
			Position = UDim2.new(0, 12, 0, 22),
			Size     = UDim2.new(1, -14, 0, 16),
			Parent   = column,
		})
	end
end

do
	local section = addSection(tabDashboard, "Commands")

	local row = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		LayoutOrder            = 1,
		Parent                 = section.frame,
	})
	table.insert(section.rows, { frame = row, text = "drop tp down instant reset rescan podiums" })

	local commands = {
		{ text = "DROP",   action = "drop" },
		{ text = "TP DOWN", action = "tpFloor" },
		{ text = "RESET",  action = "instaReset" },
		{ text = "RESCAN", action = "rescan" },
	}

	for index, item in ipairs(commands) do
		local button = new("TextButton", {
			Size                   = UDim2.new(0.25, -6, 1, 0),
			Position               = UDim2.new(0.25 * (index - 1), index > 1 and 6 or 0, 0, 0),
			BackgroundColor3       = Theme.accent,
			BackgroundTransparency = 1,
			BorderSizePixel        = 0,
			AutoButtonColor        = false,
			Text                   = item.text,
			TextColor3             = Theme.sub,
			Font                   = FONT,
			TextSize               = 10,
			Parent                 = row,
		})
		local buttonStroke = stroke(button, Theme.rule, 0)
		accented(button, "BackgroundColor3")

		track(button.MouseEnter:Connect(function()
			buttonStroke.Color = Theme.accent
			button.TextColor3 = Theme.ink
		end))
		track(button.MouseLeave:Connect(function()
			buttonStroke.Color = Theme.rule
			button.TextColor3 = Theme.sub
		end))
		track(button.MouseButton1Click:Connect(function()
			button.BackgroundTransparency = 0.8
			task.delay(0.12, function() button.BackgroundTransparency = 1 end)
			Core.runAction(item.action)
		end))
	end
end

do
	local section = addSection(tabDashboard, "Channels")
	makeToggle(section, { label = "Auto Steal",    feature = "autoSteal" })
	makeToggle(section, { label = "Auto Bat",      feature = "autoBat" })
	makeToggle(section, { label = "Anti-Desync",   feature = "antiDesync" })
	makeToggle(section, { label = "Anti Ragdoll",  feature = "antiRagdoll" })
	makeToggle(section, { label = "Infinite Jump", feature = "infiniteJump" })
end

-- Speed ----------------------------------------------------------------------

do
	local section = addSection(tabSpeed, "Profile")

	local _, renderProfile = makeSegmented(section, {
		label   = "Active Profile",
		hint    = "Which speed the mover applies",
		width   = 56,
		options = {
			{ label = "Norm",  value = "normal" },
			{ label = "Carry", value = "carry" },
			{ label = "Lag",   value = "lagger" },
			{ label = "LagC",  value = "laggerCarry" },
		},
		onSelect = function(value) Core.setSpeedProfile(value) end,
	})
	watchProfile(renderProfile)

	makeToggle(section, {
		label   = "Auto Switch",
		hint    = "Detect carrying and pick the speed for you",
		feature = "autoSwitchSpeed",
	})
end

do
	local section = addSection(tabSpeed, "Rates")
	makeMeter(section, { label = "Normal",       key = "normalSpeed" })
	makeMeter(section, { label = "Carry",        key = "carrySpeed" })
	makeMeter(section, { label = "Lagger",       key = "laggerSpeed" })
	makeMeter(section, { label = "Lagger Carry", key = "laggerCarrySpeed", step = 0.5, decimals = 1 })
end

-- Combat ---------------------------------------------------------------------

do
	local section = addSection(tabCombat, "Aimbots")
	makeToggle(section, { label = "Auto Bat",    feature = "autoBat",    hint = "Chase, face and swing at the closest player" })
	makeToggle(section, { label = "Auto Swing",  feature = "autoSwing",  hint = "Keep swinging while Auto Bat chases" })
	makeToggle(section, { label = "Bat V2",      feature = "batV2",      hint = "Swings only once inside hit range" })
	makeToggle(section, { label = "Anti-Desync", feature = "antiDesync", hint = "Root pinning, damage negation, auto revive" })
end

do
	local section = addSection(tabCombat, "Counters")
	makeToggle(section, { label = "Bat Counter",    feature = "batCounter",    hint = "Swing back the moment you get ragdolled" })
	makeToggle(section, { label = "Medusa Counter", feature = "medusaCounter", hint = "Activate medusa when a grab lands" })
end

do
	local section = addSection(tabCombat, "Tuning")
	makeMeter(section, { label = "Chase Speed",  key = "aimbotSpeed" })
	makeMeter(section, { label = "Hover Height", key = "aimbotHeight", step = 0.1, decimals = 1 })
	makeMeter(section, { label = "Turn Rate",    key = "aimbotTurn" })
	makeMeter(section, { label = "Hit Range",    key = "batHitDistance" })
	makeMeter(section, { label = "Swing Delay",  key = "swingCooldown", step = 0.05, decimals = 2 })
end

-- Steal ----------------------------------------------------------------------

local podiumReadout

do
	local section = addSection(tabSteal, "Engine")
	makeToggle(section, { label = "Auto Steal", feature = "autoSteal", hint = "Fires the podium prompt for you" })

	local _, renderStealMode = makeSegmented(section, {
		label   = "Mode",
		hint    = "Normal holds in range, semi primes from far away",
		width   = 66,
		options = {
			{ label = "Normal", value = "normal" },
			{ label = "Semi",   value = "semi" },
		},
		onSelect = function(value) Core.setMode("stealMode", value) end,
	})
	watchMode("stealMode", renderStealMode)

	makeButton(section, { label = "Rescan Podiums", button = "Rescan", action = "rescan" })

	local row = addRow(section, "Cached Podiums", "Refreshed every 3 seconds while the engine runs")
	podiumReadout = text({
		Text           = "0",
		TextSize       = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position       = UDim2.new(1, -46, 0.5, -9),
		Size           = UDim2.new(0, 46, 0, 18),
		Parent         = row,
	})
end

do
	local section = addSection(tabSteal, "Ranges")
	makeMeter(section, { label = "Grab Radius",  key = "grabRadius",      hint = "Normal mode" })
	makeMeter(section, { label = "Hold Time",    key = "stealHold",       hint = "Normal mode", step = 0.05, decimals = 2 })
	makeMeter(section, { label = "Prime Range",  key = "primeStealRange", hint = "Semi mode: distance that starts the hold" })
	makeMeter(section, { label = "Steal Range",  key = "semiStealRadius", hint = "Semi mode: distance that fires the trigger" })
end

-- Movement -------------------------------------------------------------------

do
	local section = addSection(tabMovement, "Paths")
	makeToggle(section, { label = "Auto Left",  feature = "autoLeft",  hint = "Walk the left steal path, then stop" })
	makeToggle(section, { label = "Auto Right", feature = "autoRight", hint = "Walk the right steal path, then stop" })
end

do
	local section = addSection(tabMovement, "Drop and teleport")
	makeButton(section, { label = "Drop Brainrot", button = "Drop", action = "drop" })

	local _, renderDropMode = makeSegmented(section, {
		label   = "Drop Mode",
		width   = 66,
		options = {
			{ label = "Stand", value = "stand" },
			{ label = "Jump",  value = "jump" },
		},
		onSelect = function(value) Core.setMode("dropMode", value) end,
	})
	watchMode("dropMode", renderDropMode)

	makeButton(section, { label = "TP Down", button = "TP", action = "tpFloor" })
	makeToggle(section, { label = "Auto TP", feature = "autoTP", hint = "Repeat TP Down ten times a second" })
	makeMeter(section, { label = "TP Y Level", key = "tpY", step = 0.5, decimals = 1 })
end

do
	local section = addSection(tabMovement, "Character")
	makeToggle(section, { label = "Infinite Jump", feature = "infiniteJump" })
	makeToggle(section, { label = "Anti Ragdoll",  feature = "antiRagdoll" })
	makeToggle(section, { label = "No Collide",    feature = "noCollide", hint = "Walk through other players" })
	makeToggle(section, { label = "Unwalk",        feature = "unwalk",    hint = "Strips the Animate script" })
	makeButton(section, { label = "Instant Reset", button = "Reset", action = "instaReset" })
end

-- Keys -----------------------------------------------------------------------

do
	local section = addSection(tabKeybinds, "Bindings")
	for _, bind in ipairs(Core.binds) do
		makeKeybind(section, bind)
	end
end

-- Config ---------------------------------------------------------------------

do
	local section = addSection(tabSettings, "Phosphor")

	local row = addRow(section, "Colour", "Applies to every surface at once")
	local holder = new("Frame", {
		Size                   = UDim2.new(0, #ACCENTS * 22, 0, 14),
		Position               = UDim2.new(1, -(#ACCENTS * 22), 0.5, -7),
		BackgroundTransparency = 1,
		Parent                 = row,
	})

	local swatches = {}
	for index, entry in ipairs(ACCENTS) do
		local swatch = new("TextButton", {
			Size             = UDim2.new(0, 18, 0, 14),
			Position         = UDim2.new(0, (index - 1) * 22, 0, 0),
			BackgroundColor3 = entry.color,
			BorderSizePixel  = 0,
			AutoButtonColor  = false,
			Text             = "",
			Parent           = holder,
		})
		local swatchStroke = stroke(swatch, Theme.shell, 0)
		swatches[index] = swatchStroke

		if entry.color == Theme.accent then swatchStroke.Color = Theme.ink end

		track(swatch.MouseButton1Click:Connect(function()
			setAccent(entry.color)
			for _, other in ipairs(swatches) do other.Color = Theme.shell end
			swatchStroke.Color = Theme.ink
			UI.toast(entry.name .. " palette")
		end))
	end

	makeMeter(section, {
		label = "Console Scale", min = 0.6, max = 1.4, step = 0.05, decimals = 2,
		get = function() return prefs.menuScale end,
		set = function(value)
			prefs.menuScale = value
			windowScale.Scale = value
			savePrefs()
		end,
	})
	makeMeter(section, {
		label = "Strip Scale", min = 0.6, max = 1.6, step = 0.05, decimals = 2,
		get = function() return prefs.hudScale end,
		set = function(value)
			prefs.hudScale = value
			if hudScaleObj then hudScaleObj.Scale = value end
			savePrefs()
		end,
	})
	makeMeter(section, {
		label = "Keypad Scale", min = 0.5, max = 1.4, step = 0.05, decimals = 2,
		get = function() return prefs.padScale end,
		set = function(value)
			prefs.padScale = value
			if padScaleObj then padScaleObj.Scale = value end
			savePrefs()
		end,
	})
end

do
	local section = addSection(tabSettings, "Surfaces")

	makeToggle(section, {
		label = "Lock Positions",
		hint  = "Stops the console, strip and keypad from being dragged",
		get   = function() return prefs.locked end,
		set   = function(on) prefs.locked = on savePrefs() end,
	})
	makeToggle(section, {
		label = "Status Strip",
		get   = function() return prefs.showHud end,
		set   = function(on)
			prefs.showHud = on
			screenHud.Enabled = on
			savePrefs()
		end,
	})
	makeToggle(section, {
		label = "Touch Keypad",
		get   = function() return prefs.showPad end,
		set   = function(on)
			prefs.showPad = on
			screenPad.Enabled = on
			savePrefs()
		end,
	})
	makeButton(section, { label = "Reset Layout", button = "Reset", onClick = function() UI.resetLayout() end })
	makeButton(section, { label = "Unload", button = "Unload", danger = true, onClick = function() UI.unload() end })
end

--==============================================================================
-- Status strip
--==============================================================================

local HUD_W, HUD_H = 420, 26
local HUD_CELLS = 16

hud = new("Frame", {
	Name                   = "Strip",
	Size                   = UDim2.new(0, HUD_W, 0, HUD_H),
	Position               = udim2From(prefs.hudPos, UDim2.new(0.5, -HUD_W / 2, 0, 18)),
	BackgroundColor3       = Theme.shell,
	BackgroundTransparency = 0.08,
	BorderSizePixel        = 0,
	Active                 = true,
	Parent                 = screenHud,
})
stroke(hud, Theme.rule, 0)
hudScaleObj = new("UIScale", { Scale = prefs.hudScale, Parent = hud })
screenHud.Enabled = prefs.showHud

draggable(hud, hud, function(position)
	prefs.hudPos = udim2To(position)
	savePrefs()
end)

accented(new("Frame", {
	Size             = UDim2.new(0, 3, 1, 0),
	BackgroundColor3 = Theme.accent,
	BorderSizePixel  = 0,
	Parent           = hud,
}), "BackgroundColor3")

local hudStatus = text({
	Text     = "IDLE",
	TextSize = 11,
	Position = UDim2.new(0, 12, 0, 0),
	Size     = UDim2.new(0, 140, 1, 0),
	Parent   = hud,
})

local hudMeterW = HUD_CELLS * CELL_W + (HUD_CELLS - 1) * CELL_GAP
local hudMeter = new("Frame", {
	Size                   = UDim2.new(0, hudMeterW, 0, 8),
	Position               = UDim2.new(0, 160, 0.5, -4),
	BackgroundTransparency = 1,
	Parent                 = hud,
})

local hudCells = {}
for index = 1, HUD_CELLS do
	hudCells[index] = new("Frame", {
		Size             = UDim2.new(0, CELL_W, 1, 0),
		Position         = UDim2.new(0, (index - 1) * (CELL_W + CELL_GAP), 0, 0),
		BackgroundColor3 = Theme.rule,
		BorderSizePixel  = 0,
		Parent           = hudMeter,
	})
end

local hudPercent = text({
	Text           = "0%",
	TextSize       = 11,
	TextColor3     = Theme.sub,
	TextXAlignment = Enum.TextXAlignment.Right,
	Position       = UDim2.new(0, 262, 0, 0),
	Size           = UDim2.new(0, 40, 1, 0),
	Parent         = hud,
})

local hudTelemetry = text({
	Text           = "",
	TextSize       = 10,
	TextColor3     = Theme.dim,
	TextXAlignment = Enum.TextXAlignment.Right,
	Position       = UDim2.new(1, -104, 0, 0),
	Size           = UDim2.new(0, 96, 1, 0),
	Parent         = hud,
})

Core.on("progress", function(progress)
	local lit = math.floor(progress * HUD_CELLS + 0.5)
	for index = 1, HUD_CELLS do
		hudCells[index].BackgroundColor3 = index <= lit and Theme.accent or Theme.rule
	end
	hudPercent.Text = string.format("%d%%", math.floor(progress * 100 + 0.5))
end)

--==============================================================================
-- Touch keypad
--==============================================================================

local PAD_ITEMS = {
	{ kind = "feature", id = "autoLeft",    label = "AUTO\nLEFT" },
	{ kind = "feature", id = "autoRight",   label = "AUTO\nRGHT" },
	{ kind = "feature", id = "autoBat",     label = "BAT\nAIM" },
	{ kind = "feature", id = "batV2",       label = "BAT\nV2" },
	{ kind = "feature", id = "antiDesync",  label = "ANTI\nDSYN" },
	{ kind = "feature", id = "autoSteal",   label = "AUTO\nSTEAL" },
	{ kind = "profile", id = "lagger",      label = "LAG" },
	{ kind = "profile", id = "laggerCarry", label = "LAG\nCRY" },
	{ kind = "profile", id = "carry",       label = "CARRY" },
	{ kind = "action",  id = "drop",        label = "DROP" },
	{ kind = "action",  id = "tpFloor",     label = "TP\nDOWN" },
	{ kind = "action",  id = "instaReset",  label = "RSET" },
}

local PAD_COLS, PAD_KEY, PAD_GAP = 3, 52, 5
local padRows = math.ceil(#PAD_ITEMS / PAD_COLS)

padFrame = new("Frame", {
	Name                   = "Keypad",
	Size                   = UDim2.new(
		0, PAD_COLS * PAD_KEY + (PAD_COLS - 1) * PAD_GAP + 16,
		0, padRows * PAD_KEY + (padRows - 1) * PAD_GAP + 30),
	Position               = udim2From(prefs.padPos, UDim2.new(1, -206, 0.5, -126)),
	BackgroundColor3       = Theme.shell,
	BackgroundTransparency = 0.12,
	BorderSizePixel        = 0,
	Active                 = true,
	Parent                 = screenPad,
})
stroke(padFrame, Theme.rule, 0)
padScaleObj = new("UIScale", { Scale = prefs.padScale, Parent = padFrame })
screenPad.Enabled = prefs.showPad

local padHandle = new("Frame", {
	Size                   = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	Parent                 = padFrame,
})

accented(text({
	Text     = spaced("VELTREX"),
	TextSize = 9,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size     = UDim2.new(1, 0, 1, 0),
	Parent   = padHandle,
}), "TextColor3")

rule(padFrame, 22, 0.5, 8)

draggable(padFrame, padHandle, function(position)
	prefs.padPos = udim2To(position)
	savePrefs()
end)

local function padKey(item, index)
	local column   = (index - 1) % PAD_COLS
	local rowIndex = math.floor((index - 1) / PAD_COLS)

	local key = new("TextButton", {
		Size                   = UDim2.new(0, PAD_KEY, 0, PAD_KEY),
		Position               = UDim2.new(0, 8 + column * (PAD_KEY + PAD_GAP), 0, 30 + rowIndex * (PAD_KEY + PAD_GAP)),
		BackgroundColor3       = Theme.accent,
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		AutoButtonColor        = false,
		Text                   = item.label,
		TextColor3             = Theme.sub,
		Font                   = FONT,
		TextSize               = 10,
		LineHeight             = 1.15,
		Parent                 = padFrame,
	})
	local keyStroke = stroke(key, Theme.rule, 0)
	accented(key, "BackgroundColor3")

	-- Status bar across the top of the key, lit while the channel is active.
	local lamp = new("Frame", {
		Size                   = UDim2.new(1, -12, 0, 2),
		Position               = UDim2.new(0, 6, 0, 6),
		BackgroundColor3       = Theme.rule,
		BorderSizePixel        = 0,
		Parent                 = key,
	})

	local function render(on)
		tween(key, 0.12, {
			BackgroundTransparency = on and 0.88 or 1,
			TextColor3             = on and Theme.ink or Theme.sub,
		})
		keyStroke.Color = on and Theme.accent or Theme.rule
		lamp.BackgroundColor3 = on and Theme.accent or Theme.rule
	end

	track(key.MouseButton1Click:Connect(function()
		if item.kind == "feature" then
			Core.toggleFeature(item.id)
		elseif item.kind == "profile" then
			Core.toggleSpeedProfile(item.id)
		else
			Core.runAction(item.id)
			render(true)
			task.delay(0.15, function() render(false) end)
		end
	end))

	if item.kind == "feature" then
		watchFeature(item.id, render)
	elseif item.kind == "profile" then
		watchProfile(function(profile) render(profile == item.id) end)
	end
end

for index, item in ipairs(PAD_ITEMS) do
	padKey(item, index)
end

--==============================================================================
-- Collapsed tab
--==============================================================================

local stub = new("TextButton", {
	Name                   = "Stub",
	Size                   = UDim2.new(0, 108, 0, 22),
	Position               = udim2From(prefs.windowPos, UDim2.new(0, 36, 0.5, -11)),
	BackgroundColor3       = Theme.shell,
	BackgroundTransparency = 0.08,
	BorderSizePixel        = 0,
	AutoButtonColor        = false,
	Text                   = "",
	Visible                = false,
	Active                 = true,
	Parent                 = screenMain,
})
stroke(stub, Theme.rule, 0)

accented(new("Frame", {
	Size             = UDim2.new(0, 2, 1, 0),
	BackgroundColor3 = Theme.accent,
	BorderSizePixel  = 0,
	Parent           = stub,
}), "BackgroundColor3")

accented(text({
	Text     = spaced("VELTREX"),
	TextSize = 10,
	Position = UDim2.new(0, 10, 0, 0),
	Size     = UDim2.new(1, -12, 1, 0),
	Parent   = stub,
}), "TextColor3")

draggable(stub, stub)

local windowVisible = true

local function setWindowVisible(visible)
	windowVisible = visible
	window.Visible = visible
	if visible then
		stub.Visible = false
	else
		stub.Position = window.Position
		stub.Visible = true
	end
end

headerButton("_", -32, function() setWindowVisible(false) end)

local closeArmed = false
headerButton("X", -54, function()
	if closeArmed then
		UI.unload()
		return
	end
	closeArmed = true
	UI.toast("confirm unload", "warn")
	task.delay(3, function() closeArmed = false end)
end)

track(stub.MouseButton1Click:Connect(function() setWindowVisible(true) end))

Core.registerAction("toggleUI", "Toggle Menu", function()
	setWindowVisible(not windowVisible)
end)

--==============================================================================
-- Filter
--==============================================================================

local function applyFilter(query)
	query = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

	for _, tab in ipairs(tabs) do
		local matches = 0
		for _, section in ipairs(tab.sections) do
			local visible = 0
			for _, row in ipairs(section.rows) do
				local hit = query == "" or row.text:find(query, 1, true) ~= nil
				row.frame.Visible = hit
				if hit then visible = visible + 1 end
			end
			section.frame.Visible = visible > 0
			matches = matches + visible
		end

		tab.matches = matches
		tab.label.TextTransparency = (query ~= "" and matches == 0) and 0.6 or 0
	end

	if query ~= "" and activeTab and activeTab.matches == 0 then
		for _, tab in ipairs(tabs) do
			if tab.matches > 0 then
				selectTab(tab)
				break
			end
		end
	end
end

track(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	applyFilter(searchBox.Text)
end))

--==============================================================================
-- Layout reset / unload
--==============================================================================

function UI.resetLayout()
	prefs.windowPos = { xs = 0, xo = 36, ys = 0.5, yo = -WINDOW_H / 2 }
	prefs.hudPos    = { xs = 0.5, xo = -HUD_W / 2, ys = 0, yo = 18 }
	prefs.padPos    = { xs = 1, xo = -206, ys = 0.5, yo = -126 }

	window.Position   = udim2From(prefs.windowPos)
	stub.Position     = udim2From(prefs.windowPos)
	hud.Position      = udim2From(prefs.hudPos)
	padFrame.Position = udim2From(prefs.padPos)

	savePrefs()
	UI.toast("layout reset")
end

function UI.unload()
	for _, conn in ipairs(uiConns) do
		pcall(function() conn:Disconnect() end)
	end
	uiConns = {}

	screenMain:Destroy()
	screenHud:Destroy()
	screenPad:Destroy()

	Core.unload()
end

--==============================================================================
-- Live refresh
--==============================================================================

task.spawn(function()
	while not Core.unloaded do
		local state = Core.state
		local profile = Core.speedProfileLabel()

		if statCells.FPS then
			statCells.FPS.Text     = tostring(Core.fps)
			statCells.PING.Text    = tostring(Core.ping) .. "ms"
			statCells.SPEED.Text   = string.format("%.0f", state.speed)
			statCells.PROFILE.Text = string.upper(profile)
		end

		if podiumReadout then
			podiumReadout.Text = tostring(#(Core.Steal.animals or {}))
		end

		hudStatus.Text = string.upper(
			state.stealing and ("STEALING " .. tostring(state.stealLabel))
			or (state.aimTarget and ("TARGET " .. state.aimTarget))
			or profile
		)
		hudTelemetry.Text = string.format("%dF %dMS %.0fSPD", Core.fps, Core.ping, state.speed)

		local active = 0
		for _, def in ipairs(Core.features) do
			if Core.isOn(def.id) then active = active + 1 end
		end

		headerStats.Text = string.format("%d FPS   %d MS   %d ACTIVE", Core.fps, Core.ping, active)
		footerLeft.Text  = string.format("CH %02d ACTIVE", active)
		footerRight.Text = string.upper(profile) .. "   " .. string.format("%.0f SPD", state.speed)

		task.wait(0.25)
	end
end)

--==============================================================================
-- Boot
--==============================================================================

selectTab(tabs[1])
applyFilter("")

Core.on("feature", function(id, on)
	local def = Core.featureById[id]
	if def then
		UI.toast(def.label .. (on and " on" or " off"))
	end
end)

UI.window = window
UI.hud    = hud
UI.pad    = padFrame
UI.Theme  = Theme

return UI
end)(VeltrexCore)

--==============================================================================
-- Entry point
--==============================================================================

_G.Veltrex = {
	Core   = VeltrexCore,
	UI     = VeltrexUI,
	unload = function() VeltrexUI.unload() end,
}

-- Interface first, so it is subscribed before Core restores saved features.
VeltrexCore.start()
