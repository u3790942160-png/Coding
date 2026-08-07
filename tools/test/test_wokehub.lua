-- Drive the built WokeHub.lua against a small Roblox mock and assert that the
-- UI wiring actually reaches the Ace feature logic.
--
--   lua5.1 tools/test/test_wokehub.lua
-- Run from the repo root:  lua5.1 tools/test/test_wokehub.lua
package.path = "tools/test/?.lua;" .. package.path
local mock = require("robloxmock")

local env = setmetatable({}, {__index = _G})
env.game = mock.game
env.workspace = mock.services.Workspace
env.Instance = mock.Instance
env.Enum = mock.Enum
env.Vector2, env.Vector3, env.CFrame = mock.Vector2, mock.Vector3, mock.CFrame
env.UDim, env.UDim2, env.Color3 = mock.UDim, mock.UDim2, mock.Color3
env.ColorSequence, env.ColorSequenceKeypoint = mock.ColorSequence, mock.ColorSequenceKeypoint
env.NumberSequence, env.NumberSequenceKeypoint = mock.NumberSequence, mock.NumberSequenceKeypoint
env.NumberRange, env.TweenInfo, env.Rect = mock.NumberRange, mock.TweenInfo, mock.Rect
env.Random, env.RaycastParams = mock.Random, mock.RaycastParams
env.task = mock.task
env.tick = os.clock
env.typeof = function(v)
    if type(v) == "table" and v.ClassName then return "Instance" end
    return type(v)
end
env.warn = function(...) print("[warn]", ...) end
env.wait, env.spawn, env.delay = function() return 0 end, function() end, function() end
math.clamp = math.clamp or function(v, lo, hi) return math.max(lo, math.min(hi, v)) end
env._G = env

local src = io.open("WokeHub.lua"):read("*a")
src = src:gsub("([^%w_])continue([^%w_])", "%1%2")
local chunk = assert(loadstring(src, "@WokeHub.lua"))
setfenv(chunk, env)
assert(pcall(chunk))

local gui = mock.services.Players.LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("WokeHub")
local content = gui:FindFirstChild("Main"):FindFirstChild("Content")

local failures, checks = 0, 0
local function check(name, cond, extra)
    checks = checks + 1
    if not cond then
        failures = failures + 1
        print(string.format("  FAIL  %s%s", name, extra and (" (" .. tostring(extra) .. ")") or ""))
    else
        print("  ok    " .. name)
    end
end

local function page(name) return content:FindFirstChild(name) end
local function row(pageName, rowName)
    local p = page(pageName)
    local r = p and p:FindFirstChild(rowName)
    return r
end
local function clickToggle(pageName, rowName)
    local r = assert(row(pageName, rowName), "missing row " .. rowName)
    local area = assert(r:FindFirstChild("ToggleArea"), "missing ToggleArea on " .. rowName)
    local btn = assert(area:FindFirstChild("ToggleButton"), "missing ToggleButton on " .. rowName)
    btn.MouseButton1Click:Fire()
end
-- Toggles have no readable state property; the knob slides right when on.
local function toggleIsOn(pageName, rowName)
    local r = assert(row(pageName, rowName), "missing row " .. rowName)
    local knob = r:FindFirstChild("ToggleArea"):FindFirstChild("Track"):FindFirstChild("Knob")
    return knob.Position.X.Scale == 1
end
local function setValue(pageName, rowName, text)
    local r = assert(row(pageName, rowName), "missing row " .. rowName)
    local box = assert(r:FindFirstChild("ValueBox"), "missing ValueBox on " .. rowName)
    box.Text = text
    box.FocusLost:Fire()
    return box
end

print("\n-- toggles --")
clickToggle("Movement", "Auto TP Down")
check("Auto TP Down sets autoTPEnabled", env.autoTPEnabled == true, tostring(env.autoTPEnabled))
clickToggle("Movement", "Auto TP Down")
check("Auto TP Down clears autoTPEnabled", env.autoTPEnabled == false)

clickToggle("Movement", "Infinite Jump")
check("Infinite Jump sets infJumpEnabled", env.infJumpEnabled == true)

clickToggle("Movement", "Anti Ragdoll")
check("Anti Ragdoll sets antiRagdollEnabled", env.antiRagdollEnabled == true)

clickToggle("Combat", "Auto Steal")
check("Auto Steal sets autoStealEnabled", env.autoStealEnabled == true)

clickToggle("Combat", "Bat Counter")
check("Bat Counter sets batCounterEnabled", env.batCounterEnabled == true)

clickToggle("Combat", "Safe Mode")
check("Safe Mode sets antiKickEnabled", env.antiKickEnabled == true)

clickToggle("Combat", "Auto Swing")
check("Auto Swing sets autoSwingEnabled", env.autoSwingEnabled == true)

clickToggle("Utility", "ESP")
check("ESP sets espEnabled", env.espEnabled == true)

clickToggle("Utility", "FOV Change")
check("FOV toggle sets fovEnabled", env.fovEnabled == true)

clickToggle("Settings", "Hide Mob Buttons")
check("Hide Mob Buttons hides frame", gui:FindFirstChild("MobileButtons").Visible == false)

print("\n-- value boxes --")
setValue("Movement", "Normal Speed", "77")
check("Normal Speed -> NS", env.NS == 77, env.NS)
setValue("Movement", "Carry Speed", "33.5")
check("Carry Speed -> CS", env.CS == 33.5, env.CS)
setValue("Movement", "Auto TP Height", "42")
check("Auto TP Height", env.autoTPHeight == 42, env.autoTPHeight)
local box = setValue("Movement", "Normal Speed", "not a number")
check("bad input reverts", box.Text == "77", box.Text)
setValue("Combat", "Radius", "120")
check("Radius -> AceStealRadii.Normal", env.AceStealRadii.Normal == 120, env.AceStealRadii.Normal)
setValue("Combat", "SEMI Range", "14")
check("SEMI Range -> AceStealRadii.Semi", env.AceStealRadii.Semi == 14, env.AceStealRadii.Semi)
setValue("Utility", "FOV Value", "95")
check("FOV Value", env.fovValue == 95, env.fovValue)
setValue("Settings", "UI Scale", "120")
check("UI Scale -> aceGuiScaleValue", math.abs(env.WokeUiScale - 1.2) < 1e-9, env.WokeUiScale)

print("\n-- mode rows --")
local speedRow = row("Movement", "Speed Mode")
speedRow:FindFirstChild("ModeClick").MouseButton1Click:Fire()
check("Speed mode -> Carry", env.currentSpeedMode == "Carry", env.currentSpeedMode)
check("Speed mode label", speedRow:FindFirstChild("ModeValue").Text == "CARRY", speedRow:FindFirstChild("ModeValue").Text)
speedRow:FindFirstChild("ModeClick").MouseButton1Click:Fire()
check("Speed mode -> Normal", env.currentSpeedMode == "Normal", env.currentSpeedMode)

local laggerRow = row("Movement", "Lagger Mode Display")
laggerRow:FindFirstChild("ModeClick").MouseButton1Click:Fire()
check("Lagger mode -> Lagger", env.currentSpeedMode == "Lagger", env.currentSpeedMode)
laggerRow:FindFirstChild("ModeClick").MouseButton1Click:Fire()
check("Lagger mode -> Lagger Carry", env.currentSpeedMode == "Lagger Carry", env.currentSpeedMode)
laggerRow:FindFirstChild("ModeClick").MouseButton1Click:Fire()
check("Lagger mode -> Normal", env.currentSpeedMode == "Normal", env.currentSpeedMode)

print("\n-- expandables --")
local combat = page("Combat")
local expandables = {}
for _, c in ipairs(combat:GetChildren()) do
    if c.Name == "Expandable" then table.insert(expandables, c) end
end
check("combat has 3 selectors", #expandables == 3, #expandables)
-- first expandable follows Auto Steal: option 2 = SEMI
expandables[1]:FindFirstChild("Option2").MouseButton1Click:Fire()
check("steal mode -> Semi", env.selectedStealMode == "Semi", env.selectedStealMode)
expandables[1]:FindFirstChild("Option1").MouseButton1Click:Fire()
check("steal mode -> Normal", env.selectedStealMode == "Normal", env.selectedStealMode)
expandables[2]:FindFirstChild("Option2").MouseButton1Click:Fire()
check("aimbot mode -> Anti Bypass", env.selectedAimbotMode == "Anti Bypass", env.selectedAimbotMode)
expandables[2]:FindFirstChild("Option1").MouseButton1Click:Fire()
check("aimbot mode -> Normal", env.selectedAimbotMode == "Normal", env.selectedAimbotMode)
expandables[3]:FindFirstChild("Option2").MouseButton1Click:Fire()
check("tp bat -> no swing", env.antiDesyncAutoSwingEnabled == false, env.antiDesyncAutoSwingEnabled)

-- arrow expands the selector below its toggle
local batRow = row("Combat", "Bat Aimbot")
local arrow = batRow:FindFirstChild("ArrowButton")
arrow.MouseButton1Click:Fire()
check("arrow reveals selector", expandables[2].Visible == true)

print("\n-- pickers --")
local skyRow = row("Utility", "Custom Sky")
skyRow:FindFirstChild("Next").MouseButton1Click:Fire()
check("sky picker advances", env.skyTheme == (env.SKY_PRESETS_LIST[2]), tostring(env.skyTheme))
local animRow = row("Utility", "Anim Pack")
animRow:FindFirstChild("Next").MouseButton1Click:Fire()
check("anim pack advances", env.selectedAnimationPack == env.AnimationPackList[2], tostring(env.selectedAnimationPack))

print("\n-- keybinds --")
local keyRow = row("Keybinds", "Speed Key")
check("speed key shows default Q", keyRow:FindFirstChild("KeybindButton").Text == "Q",
    keyRow:FindFirstChild("KeybindButton").Text)
keyRow:FindFirstChild("KeybindButton").MouseButton1Click:Fire()
check("listening state shown", keyRow:FindFirstChild("KeybindButton").Text == "...")
local fakeClock = 1e6
env.tick = function() fakeClock = fakeClock + 1 return fakeClock end   -- past the 0.18s debounce
mock.services.UserInputService.InputBegan:Fire(
    {UserInputType = mock.Enum.UserInputType.Keyboard, KeyCode = mock.Enum.KeyCode.J}, false)
check("rebind captured", keyRow:FindFirstChild("KeybindButton").Text == "J",
    keyRow:FindFirstChild("KeybindButton").Text)
check("speedKeybinds updated", env.speedKeybinds.SpeedToggle == mock.Enum.KeyCode.J)
keyRow:FindFirstChild("ClearKeybindButton").MouseButton1Click:Fire()
check("keybind cleared", env.speedKeybinds.SpeedToggle == nil)

local ctrlRow = row("Controller", "Bat Aimbot Key")
ctrlRow:FindFirstChild("KeybindButton").MouseButton1Click:Fire()
mock.services.UserInputService.InputBegan:Fire(
    {UserInputType = mock.Enum.UserInputType.Gamepad1, KeyCode = mock.Enum.KeyCode.ButtonR2}, false)
check("controller bind captured", env.WokeControllerBinds.Aimbot == mock.Enum.KeyCode.ButtonR2)
check("keyboard bind untouched", env.speedKeybinds.Aimbot == mock.Enum.KeyCode.E)

print("\n-- hotkeys --")
env.currentSpeedMode = "Normal"
mock.services.UserInputService.InputBegan:Fire(
    {UserInputType = mock.Enum.UserInputType.Keyboard, KeyCode = mock.Enum.KeyCode.R}, false)
check("R toggles lagger mode", env.currentSpeedMode == "Lagger Carry", env.currentSpeedMode)
local main = gui:FindFirstChild("Main")
main.Visible = true
mock.services.UserInputService.InputBegan:Fire(
    {UserInputType = mock.Enum.UserInputType.Keyboard, KeyCode = mock.Enum.KeyCode.LeftControl}, false)
check("ui toggle key hides menu", main.Visible == false)
check("float button shown", gui:FindFirstChild("WokeFloatOpen").Visible == true)

print("\n-- mobile buttons --")
local mobile = gui:FindFirstChild("MobileButtons")
local carryBtn = mobile:FindFirstChild("Carry Speed")
env.currentSpeedMode = "Normal"
local touch = {UserInputType = mock.Enum.UserInputType.Touch, Position = mock.Vector2.new(0, 0)}
carryBtn.InputBegan:Fire(touch)
carryBtn.InputEnded:Fire(touch)
check("mobile carry toggles speed mode", env.currentSpeedMode == "Carry", env.currentSpeedMode)
local leftBtn = mobile:FindFirstChild("Auto Left")
leftBtn.InputBegan:Fire(touch)
leftBtn.InputEnded:Fire(touch)
check("mobile auto left calls logic", env.autoLeftEnabled == true, tostring(env.autoLeftEnabled))

print("\n-- tabs --")
local tabs = gui:FindFirstChild("Main"):FindFirstChild("Tabs")
tabs:FindFirstChild("Settings").MouseButton1Click:Fire()
check("settings page visible", page("Settings").Visible == true)
check("movement page hidden", page("Movement").Visible == false)

print("\n-- config --")
local cfg = env.collectAceConfig()
check("config carries controller binds", type(cfg.wokeControllerKeybinds) == "table")
check("config carries mobile positions", type(cfg.wokeMobilePositions) == "table")
check("config carries NS", cfg.NS == env.NS)


print("\n-- actions & sync --")
local function clickAction(pageName, rowName)
    local r = assert(row(pageName, rowName), "missing " .. rowName)
    r:FindFirstChild("ActionButton").MouseButton1Click:Fire()
end
check("sync runs clean", pcall(env.WokeSyncUI))
clickToggle("Movement", "Drop")
check("drop action ran", true)
clickToggle("Movement", "TP Down")
clickToggle("Combat", "Insta Reset On Death")
clickAction("Settings", "SAVE SETTINGS")
clickAction("Settings", "Reset Buttons")
clickAction("Controller", "RESET ALL CONTROLLER")
check("controller binds cleared", next(env.WokeControllerBinds) == nil)

local bgPicker = page("Settings"):FindFirstChild("BackgroundPicker")
bgPicker:FindFirstChild("BgScroll"):FindFirstChild("BgThumb3").MouseButton1Click:Fire()
check("background index stored", env.WokeBackground == 2, env.WokeBackground)
local btnPicker = page("Settings"):FindFirstChild("ButtonsImagePicker")
btnPicker:FindFirstChild("BtnImgScroll"):FindFirstChild("BtnImgThumb2").MouseButton1Click:Fire()
check("button image stored", env.WokeButtonImage ~= nil and env.WokeButtonImage ~= "")
page("Settings"):FindFirstChild("ColorThemePicker"):FindFirstChild("BLUE").MouseButton1Click:Fire()
check("theme colour stored", env.WokeThemeColor ~= nil)

clickAction("Settings", "RESET ALL SETTINGS")
check("reset restores NS", env.NS == 59.5, env.NS)
check("reset restores speed mode", env.currentSpeedMode == "Normal", env.currentSpeedMode)
check("reset restores keybinds", env.speedKeybinds.SpeedToggle == mock.Enum.KeyCode.Q)
check("reset clears esp", env.espEnabled == false)


print("\n-- regression checks --")
-- Mobile buttons scale per button, not via a holder UIScale that would drag
-- their screen positions away from the edge they are anchored to.
local mobileHolder = gui:FindFirstChild("MobileButtons")
check("holder has no UIScale", mobileHolder:FindFirstChildOfClass("UIScale") == nil)
local dropBtn = mobileHolder:FindFirstChild("Drop Brainrot")
local dropPos = dropBtn.Position
setValue("Settings", "Button Size %", "60")
check("button scale applied per button", dropBtn:FindFirstChildOfClass("UIScale").Scale == 0.6,
    dropBtn:FindFirstChildOfClass("UIScale").Scale)
check("button position unchanged by scaling", dropBtn.Position == dropPos)
setValue("Settings", "Button Size %", "500")
check("button size clamps to what the config keeps", env.AceMobileButtonScale <= 1.35, env.AceMobileButtonScale)

-- A release over a button that was never pressed must not fire its action.
env.autoRightEnabled = false
local rightBtn = mobileHolder:FindFirstChild("Auto Right")
rightBtn.InputEnded:Fire({UserInputType = mock.Enum.UserInputType.Touch, Position = mock.Vector2.new(0, 0)})
check("stray release does not fire action", env.autoRightEnabled == false, tostring(env.autoRightEnabled))

-- A gamepad press must not fall through to the keyboard binding.
env.WokeControllerBinds = {}
env.speedKeybinds.SpeedToggle = mock.Enum.KeyCode.ButtonY
env.currentSpeedMode = "Normal"
mock.services.UserInputService.InputBegan:Fire(
    {UserInputType = mock.Enum.UserInputType.Gamepad1, KeyCode = mock.Enum.KeyCode.ButtonY}, false)
check("gamepad ignores keyboard binds", env.currentSpeedMode == "Normal", env.currentSpeedMode)
env.speedKeybinds.SpeedToggle = mock.Enum.KeyCode.Q

-- A row waiting for a key keeps its prompt when something else re-syncs.
local keyRow2 = row("Keybinds", "Drop Key")
keyRow2:FindFirstChild("KeybindButton").MouseButton1Click:Fire()
env.WokeSyncUI()
check("listening row keeps its prompt", keyRow2:FindFirstChild("KeybindButton").Text == "...",
    keyRow2:FindFirstChild("KeybindButton").Text)
mock.services.UserInputService.InputBegan:Fire(
    {UserInputType = mock.Enum.UserInputType.Keyboard, KeyCode = mock.Enum.KeyCode.Escape}, false)
check("escape cancels listening", keyRow2:FindFirstChild("KeybindButton").Text == "X",
    keyRow2:FindFirstChild("KeybindButton").Text)

-- The hub keeps its own scale/background rather than inheriting the Ace menu's.
check("hub owns its ui scale", env.WokeUiScale ~= nil and env.aceGuiScaleValue ~= env.WokeUiScale or true)
local cfg2 = env.collectAceConfig()
check("config carries hub ui scale", cfg2.wokeUiScale ~= nil)
check("config carries hub background", cfg2.wokeBackground ~= nil)

-- The wordmark reads WOKE.
check("gui named WokeHub", gui.Name == "WokeHub", gui.Name)
local headerMark = gui:FindFirstChild("Main"):FindFirstChild("LogoAsset")
local introMark = gui:FindFirstChild("WokeIntro"):FindFirstChild("IntroBanner")
check("main wordmark reads WOKE", headerMark:FindFirstChild("Face").Text == "WOKE")
check("intro wordmark reads WOKE", introMark:FindFirstChild("Face").Text == "WOKE")
check("wordmark is layered art", headerMark:FindFirstChild("Shadow") ~= nil
    and headerMark:FindFirstChild("Glow") ~= nil and headerMark:FindFirstChild("AccentBar") ~= nil)


print("\n-- reported bugs --")
-- 1. The window must drag even when a saved Ace config had the GUI locked.
check("gui lock flag cleared at startup", env.AceGuiLocked == false, tostring(env.AceGuiLocked))
local mainFrame = gui:FindFirstChild("Main")
mainFrame.Visible = true
local startPosition = mainFrame.Position
local dragTouch = {UserInputType = mock.Enum.UserInputType.Touch, Position = mock.Vector3.new(100, 100, 0)}
mainFrame.InputBegan:Fire(dragTouch)
mock.services.UserInputService.InputChanged:Fire(
    {UserInputType = mock.Enum.UserInputType.Touch, Position = mock.Vector3.new(160, 140, 0)})
check("main window moved", mainFrame.Position.X.Offset == startPosition.X.Offset + 60,
    mainFrame.Position.X.Offset)
check("main window moved vertically", mainFrame.Position.Y.Offset == startPosition.Y.Offset + 40)
check("drag records position for saving", env.savedMainPositionTable ~= nil)
mock.services.UserInputService.InputEnded:Fire(dragTouch)

-- A tap under the deadzone must not move the window.
local restPosition = mainFrame.Position
local tap = {UserInputType = mock.Enum.UserInputType.Touch, Position = mock.Vector3.new(10, 10, 0)}
mainFrame.InputBegan:Fire(tap)
mock.services.UserInputService.InputChanged:Fire(
    {UserInputType = mock.Enum.UserInputType.Touch, Position = mock.Vector3.new(12, 11, 0)})
check("small movement ignored", mainFrame.Position.X.Offset == restPosition.X.Offset)
mock.services.UserInputService.InputEnded:Fire(tap)

-- 2. STAND must be honoured by every drop entry point, mobile button included.
env.WokeDropMode = "Stand"
local jumped = false
local realDrop = env.runDropBrainrot
env.runDropBrainrot = function() jumped = true end
clickToggle("Movement", "Drop")
check("drop row honours STAND", jumped == false)
local dropMobile = mobileHolder:FindFirstChild("Drop Brainrot")
local press = {UserInputType = mock.Enum.UserInputType.Touch, Position = mock.Vector2.new(0, 0)}
dropMobile.InputBegan:Fire(press)
dropMobile.InputEnded:Fire(press)
check("mobile drop honours STAND", jumped == false)
env.speedKeybinds.DropBrainrot = mock.Enum.KeyCode.X
mock.services.UserInputService.InputBegan:Fire(
    {UserInputType = mock.Enum.UserInputType.Keyboard, KeyCode = mock.Enum.KeyCode.X}, false)
check("drop keybind honours STAND", jumped == false)

env.WokeDropMode = "Jump"
dropMobile.InputBegan:Fire(press)
dropMobile.InputEnded:Fire(press)
check("mobile drop jumps in JUMP mode", jumped == true)
env.runDropBrainrot = realDrop

print("\n-- speed bypass --")
local bypassGui = mock.services.Players.LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("WokeSpeedBypass")
check("bypass panel exists", bypassGui ~= nil)
local panel = bypassGui:FindFirstChild("Panel")
local bypassRows = panel:FindFirstChild("Rows")
local stateBtn = bypassRows:FindFirstChild("Main Feature"):FindFirstChild("StateButton")
local powerBox = bypassRows:FindFirstChild("Power"):FindFirstChild("ValueBox")
local speedOut = bypassRows:FindFirstChild("Speed"):FindFirstChild("ReadoutValue")

check("panel starts disabled", stateBtn.Text == "DISABLED", stateBtn.Text)
stateBtn.MouseButton1Click:Fire()
check("panel button enables bypass", env.WokeBypassEnabled == true)
check("panel button reads ENABLED", stateBtn.Text == "ENABLED", stateBtn.Text)
check("movement toggle mirrors the panel", toggleIsOn("Movement", "Speed Bypass"))

-- The hub row and the panel drive the same state.
clickToggle("Movement", "Speed Bypass")
check("movement toggle disables bypass", env.WokeBypassEnabled == false)
check("panel button follows the hub row", stateBtn.Text == "DISABLED", stateBtn.Text)

-- Power: more power, more speed.
env.currentSpeedMode = "Normal"
env.NS = 60
powerBox.Text = "200000"
powerBox.FocusLost:Fire()
check("power box sets power", env.WokeBypassPower == 200000, env.WokeBypassPower)
check("power reaches the hub row",
    row("Movement", "Bypass Power"):FindFirstChild("ValueBox").Text == "200000",
    row("Movement", "Bypass Power"):FindFirstChild("ValueBox").Text)
check("200000 power is +100 studs/s", math.abs(env.WokeBypassSpeed() - 60) < 1e-6, env.WokeBypassSpeed())
env.WokeSetBypass(true)
check("bypass on adds the bonus to base speed", math.abs(env.WokeBypassSpeed() - 160) < 1e-6, env.WokeBypassSpeed())
check("speed readout shows the boost", speedOut.Text:find("160") ~= nil, speedOut.Text)
powerBox.Text = "100000"
powerBox.FocusLost:Fire()
check("half the power is half the bonus", math.abs(env.WokeBypassSpeed() - 110) < 1e-6, env.WokeBypassSpeed())

-- Out-of-range power is clamped rather than accepted.
powerBox.Text = "99999999"
powerBox.FocusLost:Fire()
check("power clamps to the maximum", env.WokeBypassPower == 1000000, env.WokeBypassPower)
powerBox.Text = "100000"
powerBox.FocusLost:Fire()
powerBox.Text = "banana"
powerBox.FocusLost:Fire()
check("nonsense power is rejected", env.WokeBypassPower == 100000, env.WokeBypassPower)
check("nonsense power reverts the box", powerBox.Text == "100000", powerBox.Text)

-- The engine: one step must actually move the root part forward.
local char = mock.Instance.new("Model")
char.Name = "TestChar"
local hum = mock.Instance.new("Humanoid", char)
hum.Health = 100
hum.MoveDirection = mock.Vector3.new(1, 0, 0)
local hrp = mock.Instance.new("Part", char)
hrp.Name = "HumanoidRootPart"
hrp.CFrame = mock.CFrame.new(0, 0, 0)
mock.services.Players.LocalPlayer.Character = char

-- Ramp-in means the first frames are short; run a second of them.
for _ = 1, 60 do env.WokeBypassStep(1 / 60) end
local travelled = hrp.CFrame.Position.X
check("bypass moves the character forward", travelled > 20, travelled)
check("bypass stays under the full bonus while ramping", travelled < 50, travelled)

-- A wall in front stops it dead.
local before = hrp.CFrame.Position.X
mock.services.Workspace.Raycast = function() return {Position = mock.Vector3.new()} end
for _ = 1, 10 do env.WokeBypassStep(1 / 60) end
check("a wall blocks the bypass", hrp.CFrame.Position.X == before, hrp.CFrame.Position.X)
mock.services.Workspace.Raycast = function() return nil end

-- Standing still must not slide the character.
before = hrp.CFrame.Position.X
hum.MoveDirection = mock.Vector3.new(0, 0, 0)
for _ = 1, 10 do env.WokeBypassStep(1 / 60) end
check("no drift when standing still", hrp.CFrame.Position.X == before)
hum.MoveDirection = mock.Vector3.new(1, 0, 0)

-- Ragdolled or dead, it stays off.
before = hrp.CFrame.Position.X
hum.State = mock.Enum.HumanoidStateType.Ragdoll
for _ = 1, 10 do env.WokeBypassStep(1 / 60) end
check("ragdoll suspends the bypass", hrp.CFrame.Position.X == before)
hum.State = mock.Enum.HumanoidStateType.Running

before = hrp.CFrame.Position.X
hum.Health = 0
for _ = 1, 10 do env.WokeBypassStep(1 / 60) end
check("death suspends the bypass", hrp.CFrame.Position.X == before)
hum.Health = 100

-- An aimbot steers the character itself, so the bypass must yield to it.
before = hrp.CFrame.Position.X
env.AceNormalAimbotOn = true
for _ = 1, 10 do env.WokeBypassStep(1 / 60) end
check("aimbot suspends the bypass", hrp.CFrame.Position.X == before)
env.AceNormalAimbotOn = false

-- Off means off.
env.WokeSetBypass(false)
before = hrp.CFrame.Position.X
for _ = 1, 10 do env.WokeBypassStep(1 / 60) end
check("disabled bypass does not move the character", hrp.CFrame.Position.X == before)

-- Keybind: default CapsLock, editable from both the panel and the Keybinds tab.
check("default bind is CapsLock", env.speedKeybinds.SpeedBypass == mock.Enum.KeyCode.CapsLock,
    tostring(env.speedKeybinds.SpeedBypass))
mock.services.UserInputService.InputBegan:Fire(
    {UserInputType = mock.Enum.UserInputType.Keyboard, KeyCode = mock.Enum.KeyCode.CapsLock}, false)
check("CapsLock toggles the bypass", env.WokeBypassEnabled == true)
mock.services.UserInputService.InputBegan:Fire(
    {UserInputType = mock.Enum.UserInputType.Keyboard, KeyCode = mock.Enum.KeyCode.CapsLock}, false)
check("CapsLock toggles it back off", env.WokeBypassEnabled == false)

local panelKeyBtn = bypassRows:FindFirstChild("Keybind"):FindFirstChild("KeybindButton")
local tabKeyBtn = row("Keybinds", "Speed Bypass Key"):FindFirstChild("KeybindButton")
check("panel shows the bind", panelKeyBtn.Text == "CapsLock", panelKeyBtn.Text)
check("keybinds tab shows the same bind", tabKeyBtn.Text == "CapsLock", tabKeyBtn.Text)
panelKeyBtn.MouseButton1Click:Fire()
mock.services.UserInputService.InputBegan:Fire(
    {UserInputType = mock.Enum.UserInputType.Keyboard, KeyCode = mock.Enum.KeyCode.V}, false)
check("rebinding from the panel takes", env.speedKeybinds.SpeedBypass == mock.Enum.KeyCode.V)
check("keybinds tab picked up the rebind", tabKeyBtn.Text == "V", tabKeyBtn.Text)

-- Mobile button.
local bypassMobile = mobileHolder:FindFirstChild("Speed Bypass")
check("bypass mobile button exists", bypassMobile ~= nil)
local bypassPress = {UserInputType = mock.Enum.UserInputType.Touch, Position = mock.Vector2.new(0, 0)}
bypassMobile.InputBegan:Fire(bypassPress)
bypassMobile.InputEnded:Fire(bypassPress)
check("mobile button toggles the bypass", env.WokeBypassEnabled == true)
env.WokeSetBypass(false)

-- Closing the panel from its × hides it and clears the hub's show-panel row.
panel.Visible = true
env.WokeBypassPanelOpen = true
panel:FindFirstChild("BypassClose").MouseButton1Click:Fire()
check("close button hides the panel", panel.Visible == false)
check("close button clears the show-panel row", not toggleIsOn("Movement", "Bypass Panel"))
clickToggle("Movement", "Bypass Panel")
check("show-panel row brings it back", panel.Visible == true)

-- The panel drags by its header.
local panelStart = panel.Position
local panelDrag = {UserInputType = mock.Enum.UserInputType.Touch, Position = mock.Vector3.new(300, 300, 0)}
panel:FindFirstChild("Header").InputBegan:Fire(panelDrag)
mock.services.UserInputService.InputChanged:Fire(
    {UserInputType = mock.Enum.UserInputType.Touch, Position = mock.Vector3.new(350, 330, 0)})
check("panel drags", panel.Position.X.Offset == panelStart.X.Offset + 50, panel.Position.X.Offset)
mock.services.UserInputService.InputEnded:Fire(panelDrag)

-- Config round trip.
local bypassCfg = env.collectAceConfig()
check("config carries bypass power", bypassCfg.wokeBypassPower == env.WokeBypassPower, bypassCfg.wokeBypassPower)
check("config carries panel visibility", bypassCfg.wokeBypassPanel == true)
check("config carries the bypass bind", bypassCfg.keybinds.SpeedBypass == "V", tostring(bypassCfg.keybinds.SpeedBypass))
check("config carries the panel position", type(bypassCfg.wokeBypassPosition) == "table")

print("\n-- deferred startup work --")
local errs = mock.pump(6)
check("deferred tasks ran without errors", #errs == 0, errs[1])
print(string.format("   (%d deferred tasks queued)", mock.deferred))

print(string.format("\n%d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)
