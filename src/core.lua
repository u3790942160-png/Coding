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
local TS               = game:GetService("TweenService")

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
	-- movement
	speedMethod      = "Velocity",  -- see Core.speedMethods
	hyperMult        = 4,           -- multiplier for the Hyper CFrame method
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

-- Movement methods, ported from the Vynx build. Games and executors disagree
-- about which of these actually shifts the character, so the method is a
-- setting rather than a decision baked into the engine.
local SPEED_METHODS = {
	"Velocity", "AssemblyLinearVelocity", "Velocity Lerp", "AssemblyLinearVelocity Lerp",
	"CFrame", "CFrame Lerp", "Hyper CFrame", "Anchored CFrame", "PivotTo",
	"Model PivotTo", "Tween CFrame",
	"WalkSpeed", "Humanoid Move", "Humanoid MoveTo",
	"BodyVelocity", "BodyPosition", "BodyForce", "BodyThrust",
	"LinearVelocity", "VectorForce", "AlignPosition",
	"ApplyImpulse", "RocketPropulsion",
}
Core.speedMethods = SPEED_METHODS

local methodIndex = {}
for index, name in ipairs(SPEED_METHODS) do methodIndex[name] = index end

-- A config naming a method this build does not have must not wedge the engine.
if not methodIndex[cfg.speedMethod] then cfg.speedMethod = "Velocity" end

-- Everything a method may have created. Cleared whenever movement stops, the
-- method changes, the character is ragdolled or the hub unloads.
local mover = {}
local lastMethod = nil

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

local function clearMover()
	if mover.anchored then
		pcall(function() mover.anchored.Anchored = false end)
		mover.anchored = nil
	end
	if mover.tween then
		pcall(function() mover.tween:Cancel() end)
		mover.tween = nil
	end

	for key, object in pairs(mover) do
		if typeof(object) == "Instance" then
			pcall(function() object:Destroy() end)
			mover[key] = nil
		end
	end
end

local function ensureAttachment(hrp, key, name)
	local attachment = mover[key]
	if not attachment or attachment.Parent ~= hrp then
		if attachment then pcall(function() attachment:Destroy() end) end
		attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.Parent = hrp
		mover[key] = attachment
	end
	return attachment
end

-- Cancel out the current horizontal velocity and impulse in the one we want.
local function massImpulse(hrp, direction, speed)
	local mass    = hrp.AssemblyMass or 1
	local current = hrp.AssemblyLinearVelocity
	local desired = Vector3.new(direction.X * speed, current.Y, direction.Z * speed)
	local delta   = desired - current
	pcall(function() hrp:ApplyImpulse(Vector3.new(delta.X, 0, delta.Z) * mass) end)
end

local function lerpImpulse(hrp, direction, speed)
	local current = hrp.AssemblyLinearVelocity
	local desired = Vector3.new(direction.X * speed, current.Y, direction.Z * speed)
	local blended = current:Lerp(desired, 0.6)
	local mass    = hrp.AssemblyMass or 1
	pcall(function()
		hrp:ApplyImpulse(Vector3.new(blended.X - current.X, 0, blended.Z - current.Z) * mass)
	end)
end

local function applyMethod(hrp, hum, direction, speed, dt)
	local step   = dt or 1 / 60
	local method = cfg.speedMethod
	local c      = hrp.Parent

	-- Switching method leaves the previous one's instances behind, so tear
	-- them down and hand WalkSpeed back to the game.
	if lastMethod ~= method then
		clearMover()
		if method ~= "WalkSpeed" and hum.WalkSpeed ~= 16 then hum.WalkSpeed = 16 end
		lastMethod = method
	end

	local target = hrp.Position + (direction * speed * step)

	if method == "Velocity" or method == "AssemblyLinearVelocity" or method == "ApplyImpulse" then
		massImpulse(hrp, direction, speed)

	elseif method == "Velocity Lerp" or method == "AssemblyLinearVelocity Lerp" then
		lerpImpulse(hrp, direction, speed)

	elseif method == "CFrame" then
		hrp.CFrame = hrp.CFrame + (direction * speed * step)

	elseif method == "CFrame Lerp" then
		hrp.CFrame = hrp.CFrame:Lerp(hrp.CFrame + (direction * speed * step), 0.5)

	elseif method == "Hyper CFrame" then
		hrp.CFrame = hrp.CFrame + (direction * speed * cfg.hyperMult * step)

	elseif method == "Anchored CFrame" then
		if not hrp.Anchored then
			hrp.Anchored = true
			mover.anchored = hrp
		end
		hrp.CFrame = hrp.CFrame + (direction * speed * step)

	elseif method == "PivotTo" then
		hrp:PivotTo(hrp.CFrame + (direction * speed * step))

	elseif method == "Model PivotTo" then
		if c and c:IsA("Model") then
			c:PivotTo(c:GetPivot() + (direction * speed * step))
		else
			hrp:PivotTo(hrp.CFrame + (direction * speed * step))
		end

	elseif method == "Tween CFrame" then
		if mover.tween then pcall(function() mover.tween:Cancel() end) end
		mover.tween = TS:Create(hrp, TweenInfo.new(step, Enum.EasingStyle.Linear), {
			CFrame = hrp.CFrame + (direction * speed * step),
		})
		mover.tween:Play()

	elseif method == "WalkSpeed" then
		hum.WalkSpeed = speed

	elseif method == "Humanoid Move" then
		hum.WalkSpeed = speed
		hum:Move(direction)

	elseif method == "Humanoid MoveTo" then
		hum:MoveTo(target, hrp)

	elseif method == "BodyVelocity" then
		if not mover.bodyVelocity or mover.bodyVelocity.Parent ~= hrp then
			if mover.bodyVelocity then pcall(function() mover.bodyVelocity:Destroy() end) end
			local body = Instance.new("BodyVelocity")
			body.Name     = "VeltrexBodyVelocity"
			body.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			body.Parent   = hrp
			mover.bodyVelocity = body
		end
		mover.bodyVelocity.Velocity =
			Vector3.new(direction.X * speed, mover.bodyVelocity.Velocity.Y, direction.Z * speed)

	elseif method == "BodyPosition" then
		if not mover.bodyPosition or mover.bodyPosition.Parent ~= hrp then
			if mover.bodyPosition then pcall(function() mover.bodyPosition:Destroy() end) end
			local body = Instance.new("BodyPosition")
			body.Name     = "VeltrexBodyPosition"
			body.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			body.P        = 500
			body.D        = 50
			body.Parent   = hrp
			mover.bodyPosition = body
		end
		mover.bodyPosition.Position = target

	elseif method == "BodyForce" then
		if not mover.bodyForce or mover.bodyForce.Parent ~= hrp then
			if mover.bodyForce then pcall(function() mover.bodyForce:Destroy() end) end
			local body = Instance.new("BodyForce")
			body.Name   = "VeltrexBodyForce"
			body.Parent = hrp
			mover.bodyForce = body
		end
		mover.bodyForce.Force = Vector3.new(direction.X * speed, 0, direction.Z * speed) * 100

	elseif method == "BodyThrust" then
		if not mover.bodyThrust or mover.bodyThrust.Parent ~= hrp then
			if mover.bodyThrust then pcall(function() mover.bodyThrust:Destroy() end) end
			local body = Instance.new("BodyThrust")
			body.Name   = "VeltrexBodyThrust"
			body.Force  = Vector3.new(math.huge, math.huge, math.huge)
			body.Parent = hrp
			mover.bodyThrust = body
		end
		mover.bodyThrust.Force = Vector3.new(direction.X * speed, 0, direction.Z * speed) * 100

	elseif method == "LinearVelocity" then
		if not mover.linearVelocity or mover.linearVelocity.Parent ~= hrp then
			if mover.linearVelocity then pcall(function() mover.linearVelocity:Destroy() end) end
			local attachment = ensureAttachment(hrp, "attLinear", "VeltrexLinearAtt")
			local velocity = Instance.new("LinearVelocity")
			velocity.Name        = "VeltrexLinearVelocity"
			velocity.Attachment0 = attachment
			velocity.MaxForce    = 1e8
			velocity.RelativeTo  = Enum.ActuatorRelativeTo.World
			velocity.Parent      = hrp
			mover.linearVelocity = velocity
		end
		mover.linearVelocity.VectorVelocity =
			Vector3.new(direction.X * speed, mover.linearVelocity.VectorVelocity.Y, direction.Z * speed)

	elseif method == "VectorForce" then
		if not mover.vectorForce or mover.vectorForce.Parent ~= hrp then
			if mover.vectorForce then pcall(function() mover.vectorForce:Destroy() end) end
			local attachment = ensureAttachment(hrp, "attVector", "VeltrexVectorAtt")
			local force = Instance.new("VectorForce")
			force.Name        = "VeltrexVectorForce"
			force.Attachment0 = attachment
			force.RelativeTo  = Enum.ActuatorRelativeTo.World
			force.Parent      = hrp
			mover.vectorForce = force
		end
		mover.vectorForce.Force = Vector3.new(direction.X * speed, 0, direction.Z * speed) * 100

	elseif method == "AlignPosition" then
		if not mover.alignPosition or mover.alignPosition.Parent ~= hrp then
			if mover.alignPosition then pcall(function() mover.alignPosition:Destroy() end) end
			local attachment = ensureAttachment(hrp, "attAlign", "VeltrexAlignAtt")
			local align = Instance.new("AlignPosition")
			align.Name           = "VeltrexAlignPosition"
			align.Attachment0    = attachment
			align.Mode           = Enum.PositionAlignmentMode.OneAttachment
			align.MaxForce       = math.huge
			align.Responsiveness = 15
			align.RigidityEnabled = false
			align.Parent         = hrp
			mover.alignPosition = align
		end
		mover.alignPosition.Position = target

	elseif method == "RocketPropulsion" then
		if not mover.rocket or mover.rocket.Parent ~= hrp or not mover.rocketTarget then
			if mover.rocket then pcall(function() mover.rocket:Destroy() end) end
			if mover.rocketTarget then pcall(function() mover.rocketTarget:Destroy() end) end

			local anchor = Instance.new("Part")
			anchor.Name        = "VeltrexRocketTarget"
			anchor.Anchored    = true
			anchor.CanCollide  = false
			anchor.Transparency = 1
			anchor.Size        = Vector3.new(1, 1, 1)
			anchor.Parent      = workspace
			mover.rocketTarget = anchor

			local rocket = Instance.new("RocketPropulsion")
			rocket.Name      = "VeltrexRocket"
			rocket.MaxThrust = 3000
			rocket.MaxTorque = 1000
			rocket.ThrustP   = 100
			rocket.ThrustD   = 20
			rocket.TurnP     = 100
			rocket.TurnD     = 10
			rocket.Target    = anchor
			rocket.Parent    = hrp
			mover.rocket = rocket
		end
		mover.rocketTarget.Position = target
		pcall(function() mover.rocket:Fire() end)
	end
end

-- The mover is suppressed while any pathing/aimbot feature owns the character.
local function speedSuppressed()
	return flags.autoBat or flags.batV2 or flags.autoLeft or flags.autoRight or flags.antiDesync
end

bind(RunService.RenderStepped, function(dt)
	local c = char()
	if not c then return end
	local hum = c:FindFirstChildOfClass("Humanoid")
	local hrp = c:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return end

	state.speed = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude

	if isRagdolled(hum) then
		lastMoveDir = Vector3.zero
		clearMover()
		return
	end

	if speedSuppressed() then
		clearMover()
		return
	end

	local speed
	if flags.autoSwitchSpeed then
		speed = autoSwitchSpeed(hum.WalkSpeed < 25)
	else
		speed = profileSpeed()
	end

	local direction = Vector3.zero
	local moveDir   = hum.MoveDirection

	if moveDir.Magnitude > 0.05 then
		lastMoveDir = moveDir
		direction = moveDir
	elseif flags.antiRagdoll and lastMoveDir.Magnitude > 0.05 then
		-- MoveDirection drops to zero for a frame whenever the humanoid is
		-- reset, so keep gliding while a movement key is still held.
		for key in pairs(MOVE_KEYS) do
			if UIS:IsKeyDown(key) then
				direction = lastMoveDir
				break
			end
		end
	end

	if direction.Magnitude > 0 then
		applyMethod(hrp, hum, Vector3.new(direction.X, 0, direction.Z).Unit, speed, dt)
	else
		clearMover()
	end
end)

function Core.setSpeedMethod(name)
	if not methodIndex[name] then return end
	cfg.speedMethod = name
	clearMover()
	lastMethod = nil

	local hum = humanoid()
	if hum and name ~= "WalkSpeed" and hum.WalkSpeed ~= 16 then hum.WalkSpeed = 16 end

	Core.emit("speedMethod", name)
	Core.save()
end

function Core.cycleSpeedMethod(step)
	local index = (methodIndex[cfg.speedMethod] or 1) + (step or 1)
	index = ((index - 1) % #SPEED_METHODS) + 1
	Core.setSpeedMethod(SPEED_METHODS[index])
end

function Core.speedMethodIndex()
	return methodIndex[cfg.speedMethod] or 1, #SPEED_METHODS
end

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
	hyperMult        = { 1, 20 },
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
	clearMover()
	lastMethod = nil

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
	Core.emit("speedMethod", cfg.speedMethod)
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

	clearMover()

	writeJSON(CONFIG_FILE, cfg)
	Core.emit("unload")
	listeners = {}
end

return Core
