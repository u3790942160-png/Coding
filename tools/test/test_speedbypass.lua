-- Drive the standalone SpeedBypass.lua against the Roblox mock: build the
-- panel, click it, and step the engine to check it actually moves the player.
--
-- Run from the repo root:  lua5.1 tools/test/test_speedbypass.lua
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
env.warn = function(...) print("[warn]", ...) end
math.clamp = math.clamp or function(v, lo, hi) return math.max(lo, math.min(hi, v)) end
env._G = env

-- Executor file IO, backed by a table so the config round trip is testable.
local files = {}
env.writefile = function(name, body) files[name] = body end
env.readfile = function(name) return files[name] end
env.isfile = function(name) return files[name] ~= nil end

local chunk = assert(loadstring(io.open("SpeedBypass.lua"):read("*a"), "@SpeedBypass.lua"))
setfenv(chunk, env)
assert(pcall(chunk))

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

local gui = mock.services.Players.LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("SpeedBypassGui")
local panel = gui and gui:FindFirstChild("Panel")
local rows = panel and panel:FindFirstChild("Rows")

print("\n-- panel --")
check("panel built", panel ~= nil)
check("panel is small", panel.Size.X.Offset == 268 and panel.Size.Y.Offset == 232,
    panel.Size.X.Offset .. "x" .. panel.Size.Y.Offset)
check("panel starts open", panel.Visible == true)
check("float pill hidden while open", gui:FindFirstChild("FloatOpen").Visible == false)

local stateBtn = rows:FindFirstChild("Main Feature"):FindFirstChild("StateButton")
local powerBox = rows:FindFirstChild("Power"):FindFirstChild("ValueBox")
local keyBtn   = rows:FindFirstChild("Keybind"):FindFirstChild("KeybindButton")
local clearBtn = rows:FindFirstChild("Keybind"):FindFirstChild("ClearKeybindButton")
local speedOut = rows:FindFirstChild("Speed"):FindFirstChild("ReadoutValue")
check("all four rows present", stateBtn and powerBox and keyBtn and speedOut and true)

print("\n-- toggling --")
check("starts disabled", stateBtn.Text == "DISABLED", stateBtn.Text)
check("no WOKE dependency", env.NS == nil and env.currentSpeedMode == nil)
stateBtn.MouseButton1Click:Fire()
check("pill enables the bypass", env.SpeedBypassEnabled() == true)
check("pill reads ENABLED", stateBtn.Text == "ENABLED", stateBtn.Text)
stateBtn.MouseButton1Click:Fire()
check("pill disables it again", env.SpeedBypassEnabled() == false)
check("pill reads DISABLED", stateBtn.Text == "DISABLED", stateBtn.Text)

print("\n-- power --")
check("default power is 100000", powerBox.Text == "100000", powerBox.Text)
check("100000 power is +50 studs/s", math.abs(env.SpeedBypassBonus() - 50) < 1e-9, env.SpeedBypassBonus())
powerBox.Text = "200000"
powerBox.FocusLost:Fire()
check("double power is double the bonus", math.abs(env.SpeedBypassBonus() - 100) < 1e-9, env.SpeedBypassBonus())
powerBox.Text = "50"
powerBox.FocusLost:Fire()
check("power clamps to the minimum", math.abs(env.SpeedBypassBonus() - 0.5) < 1e-9, env.SpeedBypassBonus())
powerBox.Text = "99999999"
powerBox.FocusLost:Fire()
check("power clamps to the maximum", math.abs(env.SpeedBypassBonus() - 500) < 1e-9, env.SpeedBypassBonus())
powerBox.Text = "banana"
powerBox.FocusLost:Fire()
check("nonsense power is rejected", math.abs(env.SpeedBypassBonus() - 500) < 1e-9, env.SpeedBypassBonus())
check("nonsense power reverts the box", powerBox.Text == "1000000", powerBox.Text)
powerBox.Text = "100000"
powerBox.FocusLost:Fire()

print("\n-- engine --")
local char = mock.Instance.new("Model")
char.Name = "TestChar"
local hum = mock.Instance.new("Humanoid", char)
hum.Health = 100
hum.MoveDirection = mock.Vector3.new(1, 0, 0)
local hrp = mock.Instance.new("Part", char)
hrp.Name = "HumanoidRootPart"
hrp.CFrame = mock.CFrame.new(0, 0, 0)
hrp.AssemblyLinearVelocity = mock.Vector3.new(59.5, 0, 0)
mock.services.Players.LocalPlayer.Character = char

local before = hrp.CFrame.Position.X
for _ = 1, 30 do env.SpeedBypassStep(1 / 60) end
check("disabled engine does not move the character", hrp.CFrame.Position.X == before)

env.SpeedBypassSetEnabled(true)
-- Ramp-in means the first frames are short, so run a full second of them.
for _ = 1, 60 do env.SpeedBypassStep(1 / 60) end
local travelled = hrp.CFrame.Position.X
check("bypass moves the character forward", travelled > 20, travelled)
check("bypass stays under the full bonus while ramping", travelled < 50, travelled)

before = hrp.CFrame.Position.X
mock.services.Workspace.Raycast = function() return {Position = mock.Vector3.new()} end
for _ = 1, 10 do env.SpeedBypassStep(1 / 60) end
check("a wall blocks the bypass", hrp.CFrame.Position.X == before, hrp.CFrame.Position.X)
mock.services.Workspace.Raycast = function() return nil end

before = hrp.CFrame.Position.X
hum.MoveDirection = mock.Vector3.new(0, 0, 0)
for _ = 1, 10 do env.SpeedBypassStep(1 / 60) end
check("no drift when standing still", hrp.CFrame.Position.X == before)
hum.MoveDirection = mock.Vector3.new(1, 0, 0)

before = hrp.CFrame.Position.X
hum.State = mock.Enum.HumanoidStateType.Ragdoll
for _ = 1, 10 do env.SpeedBypassStep(1 / 60) end
check("ragdoll suspends the bypass", hrp.CFrame.Position.X == before)
hum.State = mock.Enum.HumanoidStateType.Running

before = hrp.CFrame.Position.X
hum.Health = 0
for _ = 1, 10 do env.SpeedBypassStep(1 / 60) end
check("death suspends the bypass", hrp.CFrame.Position.X == before)
hum.Health = 100

before = hrp.CFrame.Position.X
hum.PlatformStand = true
for _ = 1, 10 do env.SpeedBypassStep(1 / 60) end
check("platform stand suspends the bypass", hrp.CFrame.Position.X == before)
hum.PlatformStand = false

-- A large dt must not turn into a huge single jump.
before = hrp.CFrame.Position.X
env.SpeedBypassStep(2)
check("a frame hitch is capped", hrp.CFrame.Position.X - before < 3, hrp.CFrame.Position.X - before)

-- WOKE's globals pause it when both scripts are running; standalone they are
-- nil and cost nothing.
before = hrp.CFrame.Position.X
env.AceNormalAimbotOn = true
for _ = 1, 10 do env.SpeedBypassStep(1 / 60) end
check("a WOKE aimbot suspends the bypass", hrp.CFrame.Position.X == before)
env.AceNormalAimbotOn = false

before = hrp.CFrame.Position.X
env.SpeedBypassSuspend = true
for _ = 1, 10 do env.SpeedBypassStep(1 / 60) end
check("the suspend hook pauses the bypass", hrp.CFrame.Position.X == before)
env.SpeedBypassSuspend = false

-- Suspension must not be sticky.
for _ = 1, 30 do env.SpeedBypassStep(1 / 60) end
check("it resumes once nothing is suspending it", hrp.CFrame.Position.X > before)

print("\n-- speed readout --")
for _ = 1, 5 do env.SpeedBypassStep(1 / 60) end
stateBtn.MouseButton1Click:Fire()   -- refreshes the readout
stateBtn.MouseButton1Click:Fire()
check("readout shows the measured speed", speedOut.Text:find("59.5") ~= nil, speedOut.Text)
check("readout shows the bonus when on", speedOut.Text:find("%+50%.0") ~= nil, speedOut.Text)

print("\n-- keybind --")
check("default bind is CapsLock", keyBtn.Text == "CapsLock", keyBtn.Text)
env.SpeedBypassSetEnabled(false)
mock.services.UserInputService.InputBegan:Fire(
    {UserInputType = mock.Enum.UserInputType.Keyboard, KeyCode = mock.Enum.KeyCode.CapsLock}, false)
check("CapsLock enables the bypass", env.SpeedBypassEnabled() == true)
mock.services.UserInputService.InputBegan:Fire(
    {UserInputType = mock.Enum.UserInputType.Keyboard, KeyCode = mock.Enum.KeyCode.CapsLock}, false)
check("CapsLock disables it again", env.SpeedBypassEnabled() == false)

keyBtn.MouseButton1Click:Fire()
check("listening state shown", keyBtn.Text == "...", keyBtn.Text)
local fakeClock = 1e6
env.tick = function() fakeClock = fakeClock + 1 return fakeClock end   -- past the debounce
mock.services.UserInputService.InputBegan:Fire(
    {UserInputType = mock.Enum.UserInputType.Keyboard, KeyCode = mock.Enum.KeyCode.V}, false)
check("rebind captured", keyBtn.Text == "V", keyBtn.Text)
mock.services.UserInputService.InputBegan:Fire(
    {UserInputType = mock.Enum.UserInputType.Keyboard, KeyCode = mock.Enum.KeyCode.V}, false)
check("the new bind works", env.SpeedBypassEnabled() == true)
mock.services.UserInputService.InputBegan:Fire(
    {UserInputType = mock.Enum.UserInputType.Keyboard, KeyCode = mock.Enum.KeyCode.CapsLock}, false)
check("the old bind no longer fires", env.SpeedBypassEnabled() == true)
env.SpeedBypassSetEnabled(false)

-- Escape cancels a rebind rather than binding Escape.
keyBtn.MouseButton1Click:Fire()
mock.services.UserInputService.InputBegan:Fire(
    {UserInputType = mock.Enum.UserInputType.Keyboard, KeyCode = mock.Enum.KeyCode.Escape}, false)
check("Escape cancels the rebind", keyBtn.Text == "V", keyBtn.Text)

clearBtn.MouseButton1Click:Fire()
check("clear button empties the bind", keyBtn.Text == "None", keyBtn.Text)
mock.services.UserInputService.InputBegan:Fire(
    {UserInputType = mock.Enum.UserInputType.Keyboard, KeyCode = mock.Enum.KeyCode.V}, false)
check("a cleared bind fires nothing", env.SpeedBypassEnabled() == false)

print("\n-- open / close / drag --")
panel:FindFirstChild("CloseButton").MouseButton1Click:Fire()
check("close hides the panel", panel.Visible == false)
local float = gui:FindFirstChild("FloatOpen")
check("close reveals the float pill", float.Visible == true)
float.MouseButton1Click:Fire()
check("the pill reopens the panel", panel.Visible == true)
check("the pill hides itself", float.Visible == false)

local startPos = panel.Position
local drag = {UserInputType = mock.Enum.UserInputType.Touch, Position = mock.Vector3.new(200, 200, 0)}
panel:FindFirstChild("Header").InputBegan:Fire(drag)
mock.services.UserInputService.InputChanged:Fire(
    {UserInputType = mock.Enum.UserInputType.Touch, Position = mock.Vector3.new(260, 240, 0)})
check("header drags the panel", panel.Position.X.Offset == startPos.X.Offset + 60, panel.Position.X.Offset)
check("and vertically too", panel.Position.Y.Offset == startPos.Y.Offset + 40)
mock.services.UserInputService.InputEnded:Fire(drag)

-- A tap under the deadzone must not move it.
local restPos = panel.Position
local tap = {UserInputType = mock.Enum.UserInputType.Touch, Position = mock.Vector3.new(10, 10, 0)}
panel:FindFirstChild("Header").InputBegan:Fire(tap)
mock.services.UserInputService.InputChanged:Fire(
    {UserInputType = mock.Enum.UserInputType.Touch, Position = mock.Vector3.new(12, 11, 0)})
check("a tap does not move the panel", panel.Position.X.Offset == restPos.X.Offset)
mock.services.UserInputService.InputEnded:Fire(tap)

print("\n-- config --")
mock.pump(4)   -- let the queued save run
local saved = files["SpeedBypass.json"]
check("config was written", saved ~= nil)
check("config stores the power", saved:find("100000") ~= nil)
check("config stores the cleared bind", saved:find("None") ~= nil, saved)

-- Re-running the script must pick those settings back up rather than reset to
-- defaults, and must not leave two panels stacked on screen.
env.SpeedBypassSetEnabled(true)
mock.pump(4)
local movedTo = panel.Position.X.Offset
local reloaded = assert(loadstring(io.open("SpeedBypass.lua"):read("*a"), "@SpeedBypass.lua"))
setfenv(reloaded, env)
assert(pcall(reloaded))

local guis = 0
for _, c in ipairs(mock.services.Players.LocalPlayer:FindFirstChild("PlayerGui"):GetChildren()) do
    if c.Name == "SpeedBypassGui" then guis = guis + 1 end
end
check("re-running replaces the panel instead of stacking", guis == 1, guis)

local gui2 = mock.services.Players.LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("SpeedBypassGui")
local rows2 = gui2:FindFirstChild("Panel"):FindFirstChild("Rows")
check("reload restores the power", rows2:FindFirstChild("Power"):FindFirstChild("ValueBox").Text == "100000",
    rows2:FindFirstChild("Power"):FindFirstChild("ValueBox").Text)
check("reload restores the cleared bind",
    rows2:FindFirstChild("Keybind"):FindFirstChild("KeybindButton").Text == "None",
    rows2:FindFirstChild("Keybind"):FindFirstChild("KeybindButton").Text)
check("reload restores the enabled state",
    rows2:FindFirstChild("Main Feature"):FindFirstChild("StateButton").Text == "ENABLED",
    rows2:FindFirstChild("Main Feature"):FindFirstChild("StateButton").Text)
check("reload restores the panel position",
    gui2:FindFirstChild("Panel").Position.X.Offset == movedTo,
    gui2:FindFirstChild("Panel").Position.X.Offset)

print("\n-- deferred startup work --")
local errs = mock.pump(6)
check("deferred tasks ran without errors", #errs == 0, errs[1])

print(string.format("\n%d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)
